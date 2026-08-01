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

      # Typ tag zo slug prefixu: sheet typy z DemosSlugMatcher::TYPE_PREFIXES,
      # ABS pasky maju prefix absb. Neznamy prefix = nil (URL sa nehlada —
      # prislusenstvo/listy/vzorky nie su materialove polozky).
      def type_of(slug)
        return 'ABS' if slug.start_with?('absb')
        DemosSlugMatcher::TYPE_PREFIXES.each do |type, prefixes|
          return type if prefixes.any? { |p| slug.start_with?(p) }
        end
        nil
      end

      # Dotaz -> slug tokeny (diakritika/case cez Materials.slug — jedina
      # translit autorita; 'Dub Halifax tabakový' -> ['dub','halifax','tabakovy']).
      def query_tokens(query)
        Materials.slug(query).downcase.split('_').reject(&:empty?)
      end

      # Predpocitany index: [[slug, type, url], ...] len pre zname typy.
      def build_index(urls)
        out = []
        Array(urls).each do |url|
          slug = DemosSlugMatcher.slug_of(url)
          next if slug.empty?
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

      # Test-only: zahodenie memoizovaneho indexu (module premenne preziju
      # medzi testami s roznym test_dir_override).
      def index_reset!
        @index = nil
        @index_key = nil
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

      # Citatelny label do naseptavaca: slug bez typoveho prefixu, pomlcky
      # ako medzery (dtdl-h1193-st12-dub-halifax-2800-2070-18 ->
      # "h1193 st12 dub halifax 2800 2070 18").
      def label_of(slug, type)
        prefixes = type == 'ABS' ? ['absb'] : Array(DemosSlugMatcher::TYPE_PREFIXES[type])
        body = slug
        prefixes.each do |p|
          next unless body.start_with?("#{p}-")
          body = body[(p.length + 1)..]
          break
        end
        body.tr('-', ' ')
      end
    end
  end
end
