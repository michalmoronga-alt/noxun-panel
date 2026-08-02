# frozen_string_literal: true
# Noxun Engine — V0.6 M-A: offline nazvove hladanie v sitemap cache Demosu.
#
# CISTY modul (ziadna siet) — vstup je zoznam produktovych URL zo sitemap
# cache (48k) a text dotazu. Robots zakazuje /vyhledavani, preto sa hlada
# VYHRADNE lokalne v slugoch URL. Vysledok je LEN navrh na klik (rodinu
# nasledne nacita a overi DemosFamily z produktovej stranky) — ziadna
# identita sa z neho nezapisuje.
#
# Audit M-A NOTE 11: Materials.slug (Unicode normalizacia) sa NIKDY nepusta
# na cely sitemap — normalizuje sa LEN dotaz. Slugy URL su uz ASCII;
# predpocitany index [slug, typ, url] sa memoizuje podla fetched_at cache
# (search_cached) a search bezi nad nim bez dalsich alokacii.

module Noxun
  module Engine
    module DemosNameSearch
      MIN_QUERY_CHARS = 3
      TOP_DEFAULT = 12

      module_function

      # Typ tag zo slug prefixu — D-65: jedna autorita (DemosSlugMatcher,
      # prefix plati len s pomlckou; koniec volneho start_with, ktore sa
      # spravalo inak nez family klasifikacia). Neznamy prefix = nil (URL sa
      # nehlada — prislusenstvo/listy/vzorky nie su materialove polozky).
      def type_of(slug)
        return 'ABS' if DemosSlugMatcher.edge_slug?(slug)
        DemosSlugMatcher.sheet_type_of(slug)
      end

      # Dotaz -> slug tokeny (diakritika/case cez Materials.slug — jedina
      # translit autorita; 'Dub Halifax tabakový' -> ['dub','halifax','tabakovy']).
      def query_tokens(query)
        Materials.slug(query).downcase.split('_').reject(&:empty?)
      end

      # Predpocitany index: [[slug, type, url], ...] len pre zname typy.
      # D-65/D-55: produktove slugy VZDY nesu rozmery — slug bez cislice je
      # clanok/kategoria (pracovna-doska-v-hlbokom-mate) a do navrhov nepatri
      # (klik na ne konci "stranka nema cislo dekoru").
      def build_index(urls)
        out = []
        Array(urls).each do |url|
          slug = DemosSlugMatcher.slug_of(url)
          next if slug.empty? || !slug.match?(/\d/)
          type = type_of(slug)
          next unless type
          out << [slug, type, url]
        end
        out
      end

      # Hladanie nad indexom. KAZDY token dotazu musi byt podretazcom slugu
      # (pomlcky slugu brania falosnym zhodam cez hranice slov). Deterministicke
      # poradie: skorsi vyskyt tokenov -> kratsi slug -> abecedne (ziadny
      # Random/mtime vstup — rovnaky dotaz da vzdy rovnaky zoznam).
      def search_index(index, query, top: TOP_DEFAULT)
        return [] if query.to_s.strip.length < MIN_QUERY_CHARS
        toks = query_tokens(query)
        return [] if toks.empty?
        scored = []
        index.each do |(slug, type, url)|
          pos = match_positions(slug, toks)
          scored << [pos, slug.length, slug, type, url] if pos
        end
        scored.sort.first(top.to_i.positive? ? top.to_i : TOP_DEFAULT)
              .map { |(_, _, slug, type, url)| entry(url, slug, type) }
      end

      # Pure vstup pre testy a male zoznamy — index sa stavia ad hoc.
      def search(urls, query, top: TOP_DEFAULT)
        search_index(build_index(urls), query, top: top)
      end

      # Produkcna cesta: index memoizovany podla fetched_at sitemap cache
      # (refresh cache = novy fetched_at = novy index; ziadna TTL magia).
      def search_cached(query, top: TOP_DEFAULT)
        data = DemosSitemapCache.load
        return [] unless data
        key = data['fetched_at'].to_f
        if @index_key != key
          @index = build_index(data['urls'])
          @index_key = key
        end
        search_index(@index, query, top: top)
      end

      # --- kovanie (V0.6 D2) --------------------------------------------------
      # Rovnaka mechanika nad OPACNYM vyberom sitemapy: slugy s cislicou, ktore
      # NIE SU materialove (type_of nil = kovanie/prislusenstvo/doplnky).
      # Vysledok je LEN navrh na klik — identitu overi fetch stranky (kod
      # sortimentu), nic sa zo slugu nezapisuje.

      def build_hardware_index(urls)
        out = []
        Array(urls).each do |url|
          slug = DemosSlugMatcher.slug_of(url)
          next if slug.empty? || !slug.match?(/\d/) # clanky/kategorie von (D-65)
          next if type_of(slug) # materialove polozky maju vlastne hladanie
          out << [slug, url]
        end
        out
      end

      def search_hardware_index(index, query, top: TOP_DEFAULT)
        return [] if query.to_s.strip.length < MIN_QUERY_CHARS
        toks = query_tokens(query)
        return [] if toks.empty?
        scored = []
        index.each do |(slug, url)|
          pos = match_positions(slug, toks)
          scored << [pos, slug.length, slug, url] if pos
        end
        scored.sort.first(top.to_i.positive? ? top.to_i : TOP_DEFAULT)
              .map { |(_, _, slug, url)| hardware_entry(url, slug) }
      end

      # Pure vstup pre testy a male zoznamy.
      def search_hardware(urls, query, top: TOP_DEFAULT)
        search_hardware_index(build_hardware_index(urls), query, top: top)
      end

      # Produkcna cesta s memoizaciou podla fetched_at (vzor search_cached).
      def search_hardware_cached(query, top: TOP_DEFAULT)
        data = DemosSitemapCache.load
        return [] unless data
        key = data['fetched_at'].to_f
        if @hw_index_key != key
          @hw_index = build_hardware_index(data['urls'])
          @hw_index_key = key
        end
        search_hardware_index(@hw_index, query, top: top)
      end

      # Label kovania: slova s velkym zaciatkom, tokeny s cislicou VELKYM
      # (sensys -> Sensys, 8645i -> 8645I nie — kody nechavame ako su, len
      # pismenkove slova kapitalizujeme; slug nenesie diakritiku).
      def hardware_label_of(slug)
        slug.split('-').map { |t| t.match?(/\d/) ? t : t.capitalize }.join(' ')
      end

      def hardware_entry(url, slug)
        { 'url' => url, 'slug' => slug, 'type' => 'KOVANIE',
          'label' => hardware_label_of(slug) }
      end

      # Test-only: zahodenie memoizovaneho indexu (module premenne preziju
      # medzi testami s roznym test_dir_override).
      def index_reset!
        @index = nil
        @index_key = nil
        @hw_index = nil
        @hw_index_key = nil
      end

      # Sucet pozicii prvych vyskytov tokenov, nil = aspon jeden token chyba.
      def match_positions(slug, toks)
        total = 0
        toks.each do |t|
          i = slug.index(t)
          return nil unless i
          total += i
        end
        total
      end

      def entry(url, slug, type)
        { 'url' => url, 'slug' => slug, 'type' => type, 'label' => label_of(slug, type) }
      end

      # Slug bez typoveho prefixu. D-65: odstrihava sa NAJDLHSI matchujuci
      # prefix (dtd-laminovana pred dtdl by inak ostal polovicny).
      def strip_prefix(slug, type)
        prefixes = type == 'ABS' ? DemosSlugMatcher::EDGE_PREFIXES : Array(DemosSlugMatcher::TYPE_PREFIXES[type])
        body = slug
        prefixes.sort_by { |p| -p.length }.each do |p|
          next unless body.start_with?("#{p}-")
          body = body[(p.length + 1)..]
          break
        end
        body
      end

      # D-74: CITATELNY label naseptavaca. Slug nenesie diakritiku (offline
      # zoznam adries — plne nazvy pridu az s fetchom rodiny), ale citatelnost
      # sa da zdvihnut: dekorove tokeny (s cislicou) VELKYM (f206 -> F206,
      # st9 -> ST9), nazvove slova s velkym zaciatkom, koncove rozmery
      # formatovane per typ — ABS "43/0,8", doska "2800×2070 · 8 mm"
      # (desatinnu hrubku 9-2 sklada ta ista heuristika ako family hint).
      def label_of(slug, type)
        toks = strip_prefix(slug, type).split('-')
        nums = trailing_numbers_of(toks)
        dims = ''
        consumed = 0
        if type == 'ABS'
          w, th, consumed = abs_dims_hint(slug)
          dims = " · #{fmt_num(w)}/#{fmt_num(th)}" if w && th
        else
          l, sw, th, consumed = sheet_dims_hint(nums)
          if th
            dims = l ? " · #{fmt_num(l)}×#{fmt_num(sw)} · #{fmt_num(th)} mm" : " · #{fmt_num(th)} mm"
          end
        end
        # GH #121 P2: dropuju sa LEN tokeny SPOTREBOVANE rozmermi — ciselny
        # dekor pred nimi (absb-5981-23-1, dtdl-1234-...) musi v labeli ostat.
        toks = toks[0...-consumed] if consumed.positive?
        # Dekorove kody (s cislicou) a kratke strukturne kody (pm/sm/cj...)
        # VELKYM; ostatne slova s velkym zaciatkom (diakritiku slug nema).
        words = toks.map { |t| t.match?(/\d/) || t.length <= 2 ? t.upcase : t.capitalize }
        "#{words.join(' ')}#{dims}"
      end

      # D-74/D-74c: rozmery ABS pre label — DELEGUJE na jedinu autoritu
      # DemosSlugMatcher.edge_dims_scan (dedup sufixy, enum hrubok, consumed).
      # Fallback vetva autority (exoticky slug) sa v LABELI nezobrazuje —
      # radsej bez rozmerov nez zavadzajuce cislo (zapisove cesty maju guardy).
      def abs_dims_hint(slug)
        w, th, consumed = DemosSlugMatcher.edge_dims_scan(slug)
        return [nil, nil, 0] unless w && th &&
                                    w.between?(10.0, 200.0) &&
                                    (DemosSlugMatcher::EDGE_INT_THS.include?(th) ||
                                     DemosSlugMatcher.decimal_edge_thickness?(th))
        [w, th, consumed]
      end

      # D-74 (GH #121 P2): LABEL hint dosky — [dlzka, sirka, hrubka, consumed].
      # Koncove cisla = [.. dekor?, DLZKA, SIRKA, hrubka(1-2 tokeny), sufix?]:
      # format su PRESNE DVE velke hodnoty (>=300 — SHEET_SIZE_RANGE zacina na
      # 500, hrubky koncia pod 100), za nimi male hrubkove tokeny. Dedup sufix
      # za desatinou (…-9-2-2) sa rozpozna, ciselny dekor PRED formatom sa
      # nespotrebuje (dtdl-1234-2800-2070-18).
      def sheet_dims_hint(nums)
        small = []
        small.unshift(nums.pop) while nums.any? && nums.last.to_f < 300
        return [nil, nil, nil, 0] if small.empty? || small.length > 3
        l = sw = nil
        big_used = 0
        if nums.length >= 2
          l = nums[-2].to_f
          sw = nums[-1].to_f
          big_used = 2
        end
        th, th_used =
          case small.length
          when 1 then [small[0].to_f, 1]
          when 2
            dec = "#{small[0]}.#{small[1]}".to_f
            small[1].length == 1 && small[0].length <= 2 && dec < 100 ? [dec, 2] : [small[0].to_f, 2]
          else # 3: desatinna + dedup sufix (9-2-2)
            dec = "#{small[0]}.#{small[1]}".to_f
            small[1].length == 1 && dec < 100 && small[2].to_i.between?(2, 9) ? [dec, 3] : [nil, 0]
          end
        return [nil, nil, nil, 0] unless th && th.positive? && th < 100
        [l, sw, th, th_used + big_used]
      end

      # Neprerusene ciselne tokeny z konca pola (kopia family vzoru — tu nad
      # uz odprefixovanym telom slugu).
      def trailing_numbers_of(toks)
        out = []
        toks.reverse_each do |t|
          break unless t.match?(/\A\d+\z/)
          out.unshift(t)
        end
        out
      end

      def drop_trailing_numbers(toks)
        n = trailing_numbers_of(toks).length
        n.zero? ? toks : toks[0...-n]
      end

      def numeric?(t)
        t.to_s.match?(/\A\d+\z/)
      end

      # 0.8 -> "0,8"; 43.0 -> "43" (slovenska desatinna ciarka).
      def fmt_num(v)
        f = v.to_f
        (f == f.round ? f.round.to_s : format('%g', f)).tr('.', ',')
      end
    end
  end
end
