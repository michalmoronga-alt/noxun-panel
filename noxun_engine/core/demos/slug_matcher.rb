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
      # dekoru. ABS pasky maju vlastny prefix absb.
      TYPE_PREFIXES = {
        'DTDL' => ['dtdl'],
        'MDF' => ['mdf'],
        'HDF' => ['hdf'],
        'PD' => ['pracovna-doska'],
        'ZASTENA' => ['zastena'],
        'KOMPAKT' => ['kompaktna-doska', 'kompakt']
      }.freeze

      module_function

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
          'structure' => norm_token(rec['structure']),
          'thickness' => num_seq(rec['thickness']),
          'width' => (num_seq(rec['width']) if edge),
          'format' => (rec['sheet_size'].is_a?(Array) ? rec['sheet_size'].map { |v| num_seq(v) } : nil),
          'back_decor' => norm_token(rec['back_decor']),
          'back_structure' => norm_token(rec['back_structure']),
          'edge' => edge,
          'prefixes' => (edge ? ['absb'] : TYPE_PREFIXES[Materials.identity_norm(type)])
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
        if toks['prefixes']
          return nil unless toks['prefixes'].any? { |p| slug.start_with?(p) }
        elsif toks['edge']
          return nil unless slug.start_with?('absb')
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
