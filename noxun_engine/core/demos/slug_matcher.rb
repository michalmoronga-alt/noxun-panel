# frozen_string_literal: true
# Noxun Engine — V0.6-B: match katalogoveho zaznamu na produktovu URL Demosu.
#
# CISTY modul (ziadna siet) — vstup je zaznam katalogu + zoznam URL zo sitemap
# cache. Slug Demosu koduje identitu: typ-dekor-struktura-nazov-format-hrubka
# (napr. pracovna-doska-h3303-st10-dub-hamilton-prirodny-4100-600-38,
# dtdl-h3303-st10-...-2800-2070-18, absb-h3303-st10-...-43-2,
# zastena-h3303-st10-f620-st87-4100-640-9-2); DK kod v slugu NIE JE.
#
# Audit B5: match je LEN KANDIDAT — dokaz identity robi az parser stiahnutej
# stranky (identity_match?). Preto: jednoznacny najlepsi = :match, viac
# rovnocennych = :ambiguous (vyber pouzivatela), nic = :miss (refresh cache /
# paste URL). Nikdy sa "najlepsi odhad" nepouzije bez overenia.

module Noxun
  module Engine
    module DemosSlugMatcher
      # Prefix slugu podla kanonickeho typu zaznamu (registry typov) — zuzuje
      # kandidatov a chrani pred zamenou DTDL vs PD vs zastena toho isteho
      # dekoru. D-65 (analyza sitemap 48k, 1.8.): jeden typ ma na Demose viac
      # slug tvarov — dtd-laminovana (Kronospan DTDL), mdfl/mdfs (lakovana/
      # surova MDF — mdfd dyhovana VEDOME mimo, Michal 1.8.), kd-in/kd-ex
      # (realne kompakty; stary "kompakt" prefix kryl len 2 produkty),
      # pracovni-deska (CZ mutacia). Prefix plati LEN s pomlckou za nim
      # (prefix_match?) — vsetky tri konzumenty (family, name_search, score)
      # klasifikuju CEZ TENTO modul, ziadne volne start_with.
      TYPE_PREFIXES = {
        'DTDL' => ['dtdl', 'dtd-laminovana'],
        'MDF' => ['mdf', 'mdfl', 'mdfs'],
        'HDF' => ['hdf'],
        'PD' => ['pracovna-doska', 'pracovni-deska'],
        'ZASTENA' => ['zastena'],
        'KOMPAKT' => ['kompaktna-doska', 'kompakt', 'kd-in', 'kd-ex']
      }.freeze

      # ABS pasky: rad absb + kratke rady absl/abs- (bezsvove hotair/laser).
      EDGE_PREFIXES = %w[absb absl abs].freeze

      module_function

      # Prefix plati len ako CELY prvy usek slugu (mdf-... ano, mdfl-... nie
      # pre prefix 'mdf') — jedina prefixova semantika celeho modulu.
      def prefix_match?(slug, prefix)
        slug == prefix || slug.start_with?("#{prefix}-")
      end

      # Kanonicky sheet typ zo slugu (nil = nie je znamy doskovy typ).
      def sheet_type_of(slug)
        TYPE_PREFIXES.each do |type, prefixes|
          return type if prefixes.any? { |p| prefix_match?(slug, p) }
        end
        nil
      end

      # Slug je ABS paska?
      def edge_slug?(slug)
        EDGE_PREFIXES.any? { |p| prefix_match?(slug, p) }
      end

      # --- rozmery a dekor ABS slugu (D-64; jedno miesto pravdy) --------------
      # ABS slug konci sirka-hrubka (absb-...-23-1, ...-43-2) alebo pri
      # desatinnej hrubke sirka-cele-desatina (...-23-0-8 = 23x0,8;
      # ...-43-1-5 = 43x1,5). Vrati [width, thickness] alebo [nil, nil].
      def edge_dims_from_slug(slug)
        w, th, = edge_dims_scan(slug)
        [w, th]
      end

      # Kolko koncovych tokenov slugu tvori sirka×hrubka (vratane pripadneho
      # dedup sufixu) — presne zrkadlo edge_dims_from_slug. GH #106 P2: ciselny
      # dekor tesne pred rozmermi (absb-5981-23-1) NESMIE byt odseknuty s nimi.
      def edge_dims_token_count(slug)
        nums = trailing_numbers(slug)
        return nums.length if nums.length < 2
        edge_dims_scan(slug)[2]
      end

      # D-74c (Michalov smoke F206): JEDNA autorita rozmerov ABS zo slugu —
      # Demos dedup sufix (…-43-2-2 = 43/2 duplikat; …-23-0-8-2 = 23/0,8)
      # posuval sirku na hrubku a zakladanie padalo na guarde sirky.
      # Zbieraju sa VSETKY platne interpretacie (obchodna hrubka: desatinna
      # z SUPPORTED_V2 / cela 1 alebo 2; sirka 10–200 ako zapisovy guard):
      # DESATINNY vyklad ma prednost (GH #124 P1: …-23-1-2 je realna 23/1,2 —
      # 1,2 je podporovana a v sortimente; dedup „-2" na celej 1-ke rozhodne
      # prefer_thickness), potom vyklady so zahodenym sufixom, nakoniec cele.
      # prefer_thickness (hrubka zo STRANKY pri zakladani / zo ZAZNAMU pri
      # lookupe) vyhra nad poradim — ambiguity riesia data, nie heuristika.
      # Ked nic nesedi, plati POVODNY fallback (exoticke slugy bez zmeny).
      # Vrati [sirka, hrubka, pocet spotrebovanych tokenov].
      EDGE_INT_THS = [1.0, 2.0].freeze
      def edge_dims_scan(slug, prefer_thickness: nil)
        nums = trailing_numbers(slug)
        return [nil, nil, 0] if nums.length < 2
        cands = [[nums, 0]]
        cands << [nums[0...-1], 1] if nums.length >= 3 && nums.last.to_i.between?(2, 9)
        opts = []
        # 1. kolo: desatinne vyklady (plny pred sufixovym), 2. kolo: cele.
        cands.each do |c, suf|
          next if c.length < 3
          dec = "#{c[-2]}.#{c[-1]}".to_f
          w = c[-3].to_f
          opts << [w, dec, 3 + suf] if decimal_edge_thickness?(dec) && w.between?(10.0, 200.0)
        end
        cands.each do |c, suf|
          next if c.length < 2
          th = c[-1].to_f
          w = c[-2].to_f
          opts << [w, th, 2 + suf] if EDGE_INT_THS.include?(th) && w.between?(10.0, 200.0)
        end
        if prefer_thickness.is_a?(Numeric)
          hit = opts.find { |_w, th, _c| (th - prefer_thickness.to_f).abs <= 0.011 }
          return hit if hit
        end
        return opts.first if opts.first
        if nums.length >= 3
          dec = "#{nums[-2]}.#{nums[-1]}".to_f
          return [nums[-3].to_f, dec, 3] if decimal_edge_thickness?(dec)
        end
        [nums[-2].to_f, nums[-1].to_f, 2]
      end

      # D-64: dekor rodiny ako suvisla sekvencia tokenov slugu PRED koncovymi
      # rozmermi (absb-79098-ohne-lpe05-cashmere-5981-bs-...-23-0-8 ma dekor
      # 5981 v tele; koncove 23-0-8 su sirka×hrubka a do dokazu nepatria —
      # dekor '23' nesmie matchnut sirku 23).
      def edge_slug_decor?(slug, decor)
        seq = norm_token(decor)
        return false if seq.nil? || seq.empty?
        parts = slug.split('-')
        tail = edge_dims_token_count(slug)
        body = tail.positive? ? parts[0...-tail] : parts
        contains_seq?(body, seq)
      end

      # Neprerusene ciselne tokeny z KONCA slugu.
      def trailing_numbers(slug)
        out = []
        slug.split('-').reverse_each do |t|
          break unless t.match?(/\A\d+\z/)
          out.unshift(t)
        end
        out
      end

      def decimal_edge_thickness?(value)
        Materials::SUPPORTED_EDGE_THICKNESSES_V2.include?(value) && value != value.round
      end

      # rec: katalogovy zaznam (sheet alebo edge — edge s 'abs_id').
      # urls: pole produktovych URL zo sitemap cache.
      # -> {status: :match|:ambiguous|:miss, url:, candidates: []}
      def match(rec, urls)
        toks = record_tokens(rec)
        return { 'status' => 'miss', 'candidates' => [] } if toks['decor'].nil?
        scored = []
        Array(urls).each do |url|
          slug = slug_of(url)
          next if slug.empty?
          s = score(slug, toks)
          scored << [s, url] if s
        end
        return { 'status' => 'miss', 'candidates' => [] } if scored.empty?
        best = scored.map(&:first).max
        top = scored.select { |s, _| s == best }.map(&:last).sort
        if top.length == 1
          { 'status' => 'match', 'url' => top.first, 'candidates' => top }
        else
          { 'status' => 'ambiguous', 'candidates' => top.first(8) }
        end
      end

      # Tokeny identity zaznamu v slug normalizacii.
      def record_tokens(rec)
        edge = !rec['abs_id'].to_s.empty?
        type = edge ? nil : rec['type'].to_s
        {
          'decor' => norm_token(rec['decor']),
          # D-98: alias dekoru u dodavatela (len doska) — v slugu MUSI byt
          # spolu s cislom skupiny (score nizsie), inak by alias dokaz identity
          # oslaboval namiesto toho, aby ho spresnil.
          'supplier_decor' => (norm_token(rec['supplier_decor']) unless edge),
          'structure' => norm_token(rec['structure']),
          'thickness' => num_seq(rec['thickness']),
          'width' => (num_seq(rec['width']) if edge),
          'format' => (rec['sheet_size'].is_a?(Array) ? rec['sheet_size'].map { |v| num_seq(v) } : nil),
          'back_decor' => norm_token(rec['back_decor']),
          'back_structure' => norm_token(rec['back_structure']),
          'edge' => edge,
          'prefixes' => (edge ? EDGE_PREFIXES : TYPE_PREFIXES[Materials.identity_norm(type)])
        }
      end

      # Skore slugu proti tokenom; nil = diskvalifikacia. Audit B5: KAZDY
      # identity udaj, ktory zaznam MA, musi v slugu sediet — ziadne "najlepsi
      # odhad" (kandidat s inou hrubkou/strukturou/formatom nie je kandidat).
      # Skore sluzi len na tie-break rovnocennych slugov (Demos -N dedup
      # sufixy); viac rovnakych = :ambiguous a vybera pouzivatel.
      def score(slug, toks)
        parts = slug.split('-')
        return nil unless contains_seq?(parts, toks['decor'])
        # D-98 (audit B1): zaznam s aliasom vyzaduje v slugu OBA tokeny — cislo
        # skupiny AJ dodavatelov alias (kd-in-f8001-st9-f800-... ma f800 aj
        # f8001 -> prejde; cudzi produkt F900 bez f800 -> neprejde). ZIADNE
        # "alebo": OR by z aliasu spravil zadne dvierka do inej skupiny.
        if toks['supplier_decor'] && !contains_seq?(parts, toks['supplier_decor'])
          return nil
        end
        # D-65: prefix filter cez prefix_match? (cely prvy usek) — DTDL zaznam
        # tak matchne aj dtd-laminovana URL, a 'mdf' uz nechyta 'mdfl-…' omylom.
        if toks['prefixes']
          return nil unless toks['prefixes'].any? { |p| prefix_match?(slug, p) }
        elsif toks['edge']
          return nil unless edge_slug?(slug)
        end
        return nil if toks['structure'] && !contains_seq?(parts, toks['structure'])
        if toks['edge']
          # ABS slug konci sirka-hrubka (absb-...-43-2). B-2a audit BLOCKER 3:
          # paska BEZ sirky sa NIKDY neparuje automaticky (sirka je identita
          # variantu; bez nej by sa nekontrolovala ani hrubka) — legacy/
          # univerzalne pasky vyzaduju doplnenie sirky, nie tichy match.
          return nil unless toks['width'] && toks['thickness']
          return nil unless contains_seq?(parts, toks['width'] + toks['thickness'])
        elsif toks['thickness']
          return nil unless tail_has?(parts, toks['thickness'])
        end
        if toks['format']
          return nil unless contains_pair?(parts, toks['format'][0], toks['format'][1])
        end
        if toks['back_decor']
          # Zastena: slug nesie oba dekory (zastena-h3303-st10-f620-st87-...).
          # B-2a audit BLOCKER 3: PORADIE je sucast identity — licovy dekor je
          # v slugu PRED rubovym (zamena stran K552/H3303 vs H3303/K552 obsahuje
          # tie iste tokeny, contains_seq? by ju pustil).
          front_i = seq_index(parts, toks['decor'])
          back_i = seq_index(parts, toks['back_decor'], front_i.to_i + toks['decor'].length)
          return nil unless back_i
          return nil if toks['back_structure'] && !contains_seq?(parts, toks['back_structure'])
        end
        # GH #96 P2: dlzka slugu NIE JE dokaz ekvivalencie (iny nazvovy usek /
        # dedup sufix moze byt INY produkt) — vsetci identity-satisfying su
        # ROVNOCENNI kandidati; 2+ = ambiguous a vybera pouzivatel.
        1
      end

      # --- normalizacia -------------------------------------------------------

      def slug_of(url)
        path = url.to_s.split('?').first.to_s
        path = path.sub(%r{\Ahttps?://[^/]+}, '')
        path.split('/').reject(&:empty?).last.to_s.downcase
      end

      # Hodnota -> pole slug tokenov (H3303 -> ['h3303']; "K009 PW" -> ['k009','pw']).
      def norm_token(value)
        v = value.to_s.strip
        return nil if v.empty?
        Materials.slug(v).downcase.split('_')
      end

      # Cislo -> sekvencia slug tokenov: 18 -> ['18'], 9.2 -> ['9','2'] (slug
      # pouziva pomlcku ako oddelovac desatin: ...-9-2), 0.8 -> ['0','8'].
      def num_seq(value)
        return nil if value.nil? || value.to_s.strip.empty?
        f = value.to_f
        return nil unless f.positive?
        return [f.round.to_s] if f == f.round
        format('%g', f.round(2)).split('.')
      end

      # Sekvencia tokenov sa nachadza v parts ako SUVISLY usek.
      def contains_seq?(parts, seq)
        !seq_index(parts, seq).nil?
      end

      # Index PRVEHO vyskytu suvislej sekvencie od pozicie `from` (nil = nie je).
      # B-2a: poradie dekorov zasteny (lice pred rubom) sa overuje indexmi.
      def seq_index(parts, seq, from = 0)
        return nil if seq.nil? || seq.empty?
        limit = parts.length - seq.length
        return nil if limit.negative?
        (from..limit).each { |i| return i if parts[i, seq.length] == seq }
        nil
      end

      # Format dlzka x sirka — sekvencie hned za sebou (…-4100-600-…).
      def contains_pair?(parts, a_seq, b_seq)
        return false unless a_seq && b_seq
        contains_seq?(parts, a_seq + b_seq)
      end

      # Hrubka byva na KONCI slugu (pripadne pred ciselnym dedup sufixom Demosu
      # ako ...-9-2-2). Staci zhoda sekvencie v poslednych (len+1) tokenoch.
      def tail_has?(parts, seq)
        return false if seq.nil? || seq.empty?
        contains_seq?(parts.last(seq.length + 1), seq)
      end
    end
  end
end
