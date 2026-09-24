# frozen_string_literal: true
# Noxun Engine — S1-F: VERDIKT NIKY A DELENIA CIEL (cisty vypoctovy modul).
#
# PRECO EXISTUJE: o tom, ci sa chladnicka do skrinky zmesti a kde smie byt hrana
# medzi celami, hovoria DVE miesta — Kontrola (`Validation`, ORANGE nalezy) a
# riadok Spotrebic v Inspectore (`Panel.appliance_rows`). Keby si kazde pocitalo
# svoje, semafor a karta by mohli tvrdit ine cislo nad tou istou skrinkou.
# Tu su teda VSETKY vzorce aj VSETKY vety — volajuci uz len kresli.
#
# Ziadne IO, ziadny SketchUp objekt, ziadny zapis: vstupom je ZAZNAM zberu
# (`Bom.collect[:appliances]`), ktory uz nesie kompletny vypoctovy kontext
# (`interior`, `z_lo`, `gap`, `single_zone`, `fronts_pair`, `bands`,
# `furniture_doors`). Inspector si ten isty zaznam sklada z ulozeneho configu
# cez `context(cfg)` — funkcia je ta ista, takze druha pravda nevznikne.
#
# ZDROJ PRAVIDIEL: debata 20.9.2026 §4 (chladnicka) + listy vyrobcov.
#   nika        — per os `min <= vnutro <= max` (jednostranne, kde list max
#                 nedava); vyska chladnicky LEN pri jednej zone,
#   delenie ciel — hrana medzi dolnym a hornym celom musi lezat v pasme
#                 `[D + 10, D + G - s - 10]`, kde D = spodok + dolne dvere
#                 SPOTREBICA, G = medzera medzi dverami spotrebica, s = skara
#                 nabytkovych ciel. 10 mm je PRESAH nabytkovych dveri cez hranu
#                 dveri spotrebica na OBOCH stranach (Michal 19.9.) — bez neho
#                 by hrana chladnicky bola pri celnej hrane na tesno.
module Noxun
  module Engine
    module ApplianceChecks
      module_function

      # Tolerancia porovnani DELENIA CIEL (mm). `Fronts` vracia NEZAOKRUHLENE
      # hranice, takze 727,000000001 nesmie byt „mimo pasma".
      EPS = 0.01
      # Tolerancia porovnani OSI NIKY (mm). Codex #384 kolo 1 (P2): ponuka
      # modelov merala na 0,5 mm a verdikt na 0,01 — model ponuknuty ako
      # „zmestí sa" tak po vazbe dostal ORANGE. Cislo je jedno a porovnanie
      # tiez (`axis_state` nizsie): pol milimetra je hranica, pod ktorou je
      # rozdiel vec zaokruhlenia listu, nie montaze.
      AXIS_TOL = 0.5
      # Presah nabytkovych dveri cez hranu dveri spotrebica (mm) na KAZDEJ
      # strane medzery. Konstanta enginu, nie pole katalogu.
      OVERLAP_MIN = 10.0

      # OSI, ktore sa pre danu kategoriu kontroluju. Kategoria, ktora tu nie je,
      # niku nekontroluje vobec (umyvacka ma vlastne kontroly slotu, doska,
      # drez a digestor niku nemaju). Rura a mikrovlnka maju SIRKU a HLBKU —
      # ich vyska je vec zon, nie skrinky (rozhodnutie 7, debata §4.2).
      AXES = { 'fridge' => %w[width height depth],
               'oven' => %w[width depth],
               'microwave' => %w[width depth] }.freeze
      AXIS_LABEL = { 'width' => 'šírka', 'height' => 'výška', 'depth' => 'hĺbka' }.freeze
      # Os, ktora ma zmysel LEN nad jednou zonou: v delenej skrinke neexistuje
      # jedno „vnutro", proti ktoremu by sa vyska dala merat.
      ZONE_AXES = %w[height].freeze
      NICHE_FIELDS = %w[width_min width_max height_min height_max depth_min depth_max].freeze
      # Kategorie, ktorych delenie ciel ma zmysel (pasma dveri dava len list
      # chladnicky).
      SPLIT_CATEGORIES = %w[fridge].freeze
      # Vlastnici, u ktorych ma zmysel pytat sa na niku (doska niku nema).
      NICHE_OWNERS = %w[cabinet slot].freeze

      # Poradie zavaznosti: co je HORSIE, to urcuje celkovy verdikt.
      RANK = { 'clash' => 5, 'unsatisfiable' => 4, 'unknown' => 3, 'skip' => 2,
               'na' => 1, 'ok' => 0 }.freeze

      FRONT_TYPE_LABEL = { 'drawer_front' => 'zásuvka', 'lift' => 'výklop',
                           'fall' => 'sklop', 'blind' => 'blenda',
                           'none' => 'riadok bez čela' }.freeze

      # === VYPOCTOVY KONTEXT SKRINKY ==========================================
      #
      # Vsetko, co verdikt potrebuje z ULOZENEHO configu skrinky. Cita sa RAZ
      # (zber aj Inspector) — ziadny sken modelu, ziadny zapis.
      # -> { 'interior', 'z_lo', 'gap', 'single_zone', 'fronts_pair' } alebo {}
      def context(cfg)
        return {} unless cfg.is_a?(Hash) && defined?(Construction)
        # Slot umyvacky vnutro NEMA (a doska je dielec) — kontext by tvrdil
        # rozmery, ktore neexistuju.
        return {} if cfg['type'].to_s == 'dishwasher'

        sym = cfg.transform_keys(&:to_sym)
        dims = Construction.interior_dims(sym)
        return {} unless dims.is_a?(Hash)

        t = cfg['thickness'].to_f
        fronts = fronts_context(sym)
        { 'interior' => { 'width' => (cfg['width'].to_f - (2 * t)).round(2),
                          'height' => dims[:avail_h].to_f.round(2),
                          'depth' => dims[:back_front_y].to_f.round(2) },
          'z_lo' => dims[:z_lo].to_f,
          'gap' => fronts['gap'],
          'single_zone' => single_zone?(cfg),
          'fronts_pair' => fronts['pair'] }
      rescue StandardError
        {}
      end

      # JE VNUTRO JEDNA ZONA? Autoritou je KOREN stromu zon (delenie = `split`);
      # ploche `zones` su az jeho projekcia. Legacy skrinka bez stromu sa posudi
      # podla nich.
      def single_zone?(cfg)
        return true unless cfg.is_a?(Hash)

        tree = cfg['zone_tree'] || cfg[:zone_tree]
        if tree.is_a?(Hash)
          split = tree['split'] || tree[:split]
          return !split.is_a?(Hash)
        end
        zones = cfg['zones'] || cfg[:zones]
        Array(zones).length <= 1
      end

      # Skara ciel a DVOJICA ciel z JEDNEHO vypoctu `Fronts` — druhy vypocet by
      # mohol dat iny default skary (Codex #376 kolo 2 P2).
      def fronts_context(sym_cfg)
        r = Fronts.resolve_layout(sym_cfg[:fronts], sym_cfg[:width].to_f, sym_cfg[:height].to_f,
                                  sym_cfg[:floor_height].to_f,
                                  opening: Construction.front_opening(sym_cfg))
        gap = r[:gap].is_a?(Numeric) ? r[:gap].to_f : Fronts::GAP_DEFAULT
        { 'gap' => gap, 'pair' => fronts_pair(r[:items], r[:bounds]) }
      rescue StandardError
        { 'gap' => Fronts::GAP_DEFAULT,
          'pair' => { 'applicable' => false, 'reason' => 'čelá sa nedajú prepočítať' } }
      end

      # DVOJICA CIEL, ktorej sa delenie tyka (Astra S1-F FIX F6): PRAVE DVE
      # dvierka nad sebou cez celu sirku. Zasuvka, vyklop, blenda ani riadok bez
      # cela panel dveri netvoria, takze delenie nema co lícovat.
      # -> { 'applicable', 'reason', 'lower_z0', 'lower_z1', 'upper_z0' }
      def fronts_pair(items, bounds)
        rows = Array(items)
        return { 'applicable' => false, 'reason' => 'delenie sa netýka: skrinka nemá čelá' } if rows.empty?

        unless rows.length == 2
          return { 'applicable' => false,
                   'reason' => "delenie sa netýka: #{rows.length} #{rows.length < 5 ? 'čelá' : 'čiel'}" }
        end

        other = rows.find { |it| it['type'].to_s != 'door' }
        if other
          label = FRONT_TYPE_LABEL[other['type'].to_s] || other['type'].to_s
          return { 'applicable' => false, 'reason' => "delenie sa netýka: #{label}" }
        end

        lo = bounds.is_a?(Hash) ? bounds[rows[0]['id']] : nil
        hi = bounds.is_a?(Hash) ? bounds[rows[1]['id']] : nil
        unless lo.is_a?(Hash) && hi.is_a?(Hash)
          return { 'applicable' => false, 'reason' => 'delenie sa netýka: čelá nemajú hranice' }
        end

        { 'applicable' => true, 'reason' => nil,
          'lower_z0' => lo[:z0].to_f, 'lower_z1' => lo[:z1].to_f, 'upper_z0' => hi[:z0].to_f }
      end

      # === VERDIKT NIKY =======================================================
      #
      # -> { 'state', 'axes' => { os => stav }, 'axis_texts' => { os => veta },
      #      'specs_missing', 'text', 'reason' }
      # Stav osi: ok | clash | unknown | skip (`skip` LEN vyska pri viac zonach).
      # Celkovy stav navyse `na` = tejto kategorie/vlastnika sa nika netyka.
      def niche_verdict(rec)
        rec = {} unless rec.is_a?(Hash)
        cat = rec['category'].to_s
        kind = owner_kind(rec)
        niche = niche_of(rec)
        missing = specs_missing?(niche)
        axes = Array(AXES[cat])
        if axes.empty? || !NICHE_OWNERS.include?(kind)
          return { 'state' => 'na', 'axes' => {}, 'axis_texts' => {},
                   'specs_missing' => missing, 'reason' => 'kontrola niky sa tejto kategórie netýka',
                   'text' => 'kontrola niky sa nerobí' }
        end
        if missing
          # D-140 (Codex #389 kolo 2, P2): osadenie, ktore zje CELE vnutro, je
          # konflikt aj bez udajov niky — je to fakt skrinky, nie listu.
          over = exhausted_height_text(rec)
          if over
            states = { 'height' => 'clash' }
            texts = { 'height' => over }
            return { 'state' => 'clash', 'axes' => states, 'axis_texts' => texts, 'specs_missing' => true,
                     'reason' => 'model nemá v katalógu rozmery niky',
                     'text' => niche_text('clash', states, texts) }
          end

          return { 'state' => 'unknown', 'axes' => {}, 'axis_texts' => {}, 'specs_missing' => true,
                   'reason' => 'model nemá v katalógu rozmery niky',
                   'text' => 'chýbajú údaje niky — kontrola sa nedá urobiť' }
        end

        interior = rec['interior'].is_a?(Hash) ? rec['interior'] : nil
        unless interior
          return { 'state' => 'unknown', 'axes' => {}, 'axis_texts' => {}, 'specs_missing' => false,
                   'reason' => 'vnútro skrinky sa nedá zistiť',
                   'text' => 'vnútro skrinky sa nedá zistiť — kontrola sa nerobí' }
        end

        states = {}
        texts = {}
        axes.each do |axis|
          # D-140: vyska sa meria od DNA NIKY (vnutro − osadenie).
          have = axis == 'height' ? effective_height(rec) : interior[axis]
          st, txt = axis_verdict(axis, niche, have, rec)
          states[axis] = st
          texts[axis] = txt
        end
        state = worst(states.values)
        { 'state' => state, 'axes' => states, 'axis_texts' => texts, 'specs_missing' => false,
          'reason' => nil, 'text' => niche_text(state, states, texts) }
      end

      # JEDNA os. -> [stav, veta]
      def axis_verdict(axis, niche, have, rec)
        label = AXIS_LABEL[axis] || axis
        return height_verdict(niche, have, rec) if axis == 'height' && mount_offset(rec).positive?
        if ZONE_AXES.include?(axis) && rec['single_zone'] == false
          return ['skip', "#{label} nekontrolovaná — skrinka má viac zón"]
        end

        axis_check(axis, niche, have)
      end

      # D-140: VYSKA S OSADENIM. Dno niky je `z_lo + osadenie`, dostupna vyska
      # `vnutro − osadenie`. Astra C FIX 6: vycerpany priestor (≤ 0) je ZNAMY
      # konflikt, nie „nevieme", a pri VIACERYCH zonach, kde sa vyska inak
      # nekontroluje, sa aspon overi, ze box nepresahuje CELE vnutro.
      def height_verdict(niche, have, rec)
        m = mount_offset(rec)
        full = num(Hash(rec['interior'])['height'])
        lo = num(Hash(niche)['height_min'])
        tail = full ? " (vnútro #{mm(full)} − osadenie #{mm(m)})" : ''
        over = exhausted_height_text(rec)
        return ['clash', over] if over
        if rec['single_zone'] == false
          if full && lo && (m + lo) > full + AXIS_TOL
            return ['clash', "výška: osadenie #{mm(m)} + nika #{mm(lo)} > vnútro #{mm(full)}"]
          end

          return ['skip', 'výška nekontrolovaná — skrinka má viac zón']
        end

        st, txt = axis_check('height', niche, have)
        [st, st == 'unknown' ? txt : "#{txt}#{tail}"]
      end

      # D-140: vyska osadenia z ZAZNAMU (ten isty citac ako builder).
      def mount_offset(rec)
        Construction.appliance_mount_offset(rec)
      end

      # Dostupna vyska niky = vnutro − osadenie (nil = vnutro nepozname).
      def effective_height(rec)
        full = num(Hash(rec['interior'])['height'])
        full.nil? ? nil : (full - mount_offset(rec)).round(2)
      end

      # VYCERPANA vyska: osadenie >= cele vnutro -> veta konfliktu, inak nil.
      # JEDNO miesto pre verdikt s udajmi niky (`height_verdict`) aj bez nich
      # (`niche_verdict` pri `specs_missing`) — obe cesty hovoria tu istu vetu.
      def exhausted_height_text(rec)
        m = mount_offset(rec)
        return nil unless m.positive?

        have = effective_height(rec)
        return nil if have.nil? || have.positive?

        "výška: osadenie #{mm(m)} ≥ vnútro #{mm(num(Hash(rec['interior'])['height']))}"
      end

      # === JEDINE POROVNANIE OSI V CELOM ENGINE ================================
      #
      # Pouziva ho VERDIKT (`axis_verdict`) aj FILTER PONUKY modelov
      # (`Panel.appliance_axis_reason`). Dve porovnania s roznou toleranciou
      # znamenali, ze ponuka model odporucila a Kontrola ho vzapati zhodila
      # (Codex #384 kolo 1, P2).
      # -> :ok | :below | :above | :unknown
      def axis_state(value, min, max)
        lo = num(min)
        hi = num(max)
        return :unknown if lo.nil? && hi.nil?

        v = num(value)
        # Nula ani zaporny rozmer nie je vnutro — je to „nevieme".
        return :unknown if v.nil? || !v.positive?
        return :below if lo && (v + AXIS_TOL) < lo
        return :above if hi && (v - AXIS_TOL) > hi

        :ok
      end

      # Zmesti sa? „Nevieme" NIE JE „nesedí" — model bez rozmerov niky sa
      # v ponuke nikdy neoznaci ako nesediaci.
      def axis_fits?(value, min, max)
        %i[ok unknown].include?(axis_state(value, min, max))
      end

      # [stav, veta] pre jednu os. Vety su TU (a nie u volajucich), aby ponuka
      # aj Kontrola menovali to iste cislo rovnako.
      def axis_check(axis, niche, have)
        label = AXIS_LABEL[axis] || axis
        n = niche.is_a?(Hash) ? niche : {}
        lo = num(n["#{axis}_min"])
        hi = num(n["#{axis}_max"])
        case axis_state(have, lo, hi)
        when :below then ['clash', "#{label} #{mm(have)} < #{mm(lo)}"]
        when :above then ['clash', "#{label} #{mm(have)} > #{mm(hi)}"]
        when :ok    then ['ok', "#{label} #{mm(have)} #{requirement(lo, hi)}"]
        else
          lo.nil? && hi.nil? ? ['unknown', "#{label} — list rozmer nedáva"]
                             : ['unknown', "#{label} — vnútro skrinky sa nedá zistiť"]
        end
      end

      # PRVY dovod, preco sa model na danej osi nezmesti (nil = zmesti sa alebo
      # sa to nedá povedať). Toto vola filter ponuky.
      def axis_reason(axis, niche, have)
        state, text = axis_check(axis, niche, have)
        state == 'clash' ? text : nil
      end

      def requirement(lo, hi)
        return "(#{mm(lo)}–#{mm(hi)})" if lo && hi
        return "(≥ #{mm(lo)})" if lo

        "(≤ #{mm(hi)})"
      end

      # Veta verdiktu niky — MENUJE overene osi (Astra FIX F7) a nikdy netvrdi
      # „montáž priechodná": overena je OBALKA, nie police ani vybavenie (F13).
      def niche_text(state, states, texts)
        bad = states.select { |_a, s| s == 'clash' }.keys
        return "nezmestí sa: #{bad.map { |a| texts[a] }.join(' · ')}" if bad.any?

        skipped = states.select { |_a, s| s == 'skip' }.keys
        unknown = states.select { |_a, s| s == 'unknown' }.keys
        checked = states.select { |_a, s| s == 'ok' }.keys.map { |a| AXIS_LABEL[a] }
        parts = []
        parts << "#{join_sk(checked)} ✓" unless checked.empty?
        skipped.each { |a| parts << texts[a] }
        unknown.each { |a| parts << texts[a] }
        return 'nika sa nedá skontrolovať' if parts.empty?

        prefix = state == 'ok' ? 'nika ✓ — ' : ''
        "#{prefix}#{parts.join(' · ')}"
      end

      # === VERDIKT DELENIA CIEL ===============================================
      #
      # -> { 'state', 'edge', 'range' => [lo, hi], 'recommended', 'source',
      #      'reason', 'text', 'gap' }
      # Stav: ok | clash | na | unknown | unsatisfiable.
      def door_split_verdict(rec)
        rec = {} unless rec.is_a?(Hash)
        return split_na('delenie sa netýka: iná kategória') unless
          SPLIT_CATEGORIES.include?(rec['category'].to_s)
        return split_na('delenie sa netýka: vlastník nie je skrinka') unless
          owner_kind(rec) == 'cabinet'

        pair = rec['fronts_pair'].is_a?(Hash) ? rec['fronts_pair'] : nil
        return split_na('delenie sa netýka: čelá sa nedajú prepočítať') if pair.nil?
        return split_na(pair['reason'].to_s) unless pair['applicable'] == true

        z_lo = num(rec['z_lo'])
        return split_unknown('dno niky sa nedá zistiť') if z_lo.nil?

        s = num(rec['gap']) || Fronts::GAP_DEFAULT
        # Pasmo je v suradniciach NIKY (0 = dno niky). Pasma z praxe su vztiahnute
        # k spotrebicu, takze s osadenim idu same; VYKRES VYROBCU je kotveny
        # k STANDARDNEJ montazi (chladnicka na dne) — preto sa prevadza cez
        # `z_lo`, nie cez zdvihnute dno (Astra C BLOCKER 3: odcitanie noveho dna
        # od hrany AJ pasma by posun algebraicky zrusilo).
        range, source, note = split_range(rec, pair, z_lo, s)
        return split_unknown('list nedáva rozmery dverí spotrebiča') if range.nil?

        m = mount_offset(rec)
        if source == 'drawing' && m.positive?
          note = [note, "výkres výrobcu je pre chladničku na dne — pri osadení #{mm(m)} sa dolné dvere zväčšujú o #{mm(m)}"]
                 .compact.join(' · ')
        end

        lo, hi = range
        if lo && hi && hi < lo - EPS
          return split_unsatisfiable(rec, s, note)
        end

        # D-140: hrana sa meria od DNA NIKY (horna plocha dna + osadenie).
        edge = (num(pair['lower_z1']).to_f - (z_lo + m)).round(2)
        state = within?(edge, lo, hi) ? 'ok' : 'clash'
        rec_mid = (lo && hi) ? ((lo + hi) / 2.0).round(1) : nil
        { 'state' => state, 'edge' => edge, 'range' => [lo, hi], 'recommended' => rec_mid,
          'source' => source, 'reason' => nil, 'gap' => s, 'note' => note,
          'text' => split_text(state, edge, lo, hi, rec_mid, source, s, note) }
      end

      # PASMO PRIPUSTNEJ HRANY v suradniciach niky (0 = horna plocha dna).
      # -> [[lo, hi], source, note] alebo nil
      #
      # PREDNOST ma VYKRES VYROBCU (`furniture_doors`): `lower_min`/`lower_max`
      # su VYSKY dolnych NABYTKOVYCH dveri (rozmer dielca), takze sa do niky
      # prevadzaju cez SPODNU HRANU dolneho cela — ta moze zacinat POD nikou
      # (sokel 100 + dno 18 + medzera 2 = 16 mm pod dnom niky).
      def split_range(rec, pair, z_lo, gap)
        fd = rec['furniture_doors'].is_a?(Hash) ? rec['furniture_doors'] : nil
        if fd
          lo_h = num(fd['lower_min'])
          hi_h = num(fd['lower_max'])
          if lo_h || hi_h
            z0 = num(pair['lower_z0']).to_f
            note = drawing_note(num(fd['gap_ref']), gap)
            return [[lo_h ? (z0 + lo_h - z_lo).round(2) : nil,
                     hi_h ? (z0 + hi_h - z_lo).round(2) : nil], 'drawing', note]
          end
        end
        bands = rec['bands'].is_a?(Hash) ? rec['bands'] : nil
        return nil unless bands

        lower = num(bands['door_lower'])
        band_gap = num(bands['door_gap'])
        return nil if lower.nil? || band_gap.nil?

        # Chybajuci `door_bottom_offset` = dvere zacinaju na dne niky (0).
        d = (num(bands['door_bottom_offset']) || 0.0) + lower
        [[(d + OVERLAP_MIN).round(2), (d + band_gap - gap - OVERLAP_MIN).round(2)], 'practice', nil]
      end

      def drawing_note(gap_ref, gap)
        return nil if gap_ref.nil? || (gap_ref - gap).abs <= EPS

        "výrobca počíta so škárou #{mm(gap_ref)}"
      end

      def within?(edge, lo, hi)
        return false if edge.nil?
        return false if lo && edge < lo - EPS
        return false if hi && edge > hi + EPS

        true
      end

      def split_na(reason)
        { 'state' => 'na', 'edge' => nil, 'range' => nil, 'recommended' => nil,
          'source' => nil, 'reason' => reason, 'gap' => nil, 'note' => nil, 'text' => reason }
      end

      def split_unknown(reason)
        { 'state' => 'unknown', 'edge' => nil, 'range' => nil, 'recommended' => nil,
          'source' => nil, 'reason' => reason, 'gap' => nil, 'note' => nil,
          'text' => "delenie čiel sa nedá odporučiť — #{reason}" }
      end

      # Astra FIX F8: `G < s + 20` znamena, ze presah 10 mm na OBOCH stranach sa
      # do medzery dveri spotrebica nezmesti. Nie je to chyba skrinky ani chyba
      # uzivatela — je to fakt listu, a povedat sa musi (ziadne pasmo, ziadny
      # odporucany stred).
      def split_unsatisfiable(rec, gap, note)
        bands = rec['bands'].is_a?(Hash) ? rec['bands'] : {}
        g = num(bands['door_gap'])
        msg = "rozstup dverí spotrebiča #{g ? mm(g) : '—'} nedovolí presah " \
              "#{mm(OVERLAP_MIN)} mm na oboch stranách pri škáre #{mm(gap)}"
        { 'state' => 'unsatisfiable', 'edge' => nil, 'range' => nil, 'recommended' => nil,
          'source' => 'practice', 'reason' => msg, 'gap' => gap, 'note' => note,
          'text' => msg }
      end

      def split_text(state, edge, lo, hi, mid, source, gap, note)
        src = source == 'drawing' ? 'podľa výkresu výrobcu' : "podľa praxe (presah ≥ #{mm(OVERLAP_MIN)}, škára #{mm(gap)})"
        band = range_text(lo, hi)
        tail = note ? " · #{note}" : ''
        return "hrana čiel #{mm(edge)} v #{band} ✓ (#{src})#{tail}" if state == 'ok'

        rc = mid ? ", odporúčané #{mm(mid)}" : ''
        "hrana čiel #{mm(edge)} mimo #{band}#{rc} — odporúčané delenie #{src}#{tail}"
      end

      def range_text(lo, hi)
        return "#{mm(lo)}–#{mm(hi)}" if lo && hi
        return "≥ #{mm(lo)}" if lo

        "≤ #{mm(hi)}"
      end

      # === CELKOVY VERDIKT ====================================================
      #
      # -> { 'state', 'niche', 'door_split', 'text' }
      # `state` = najhorsi z oboch (clash > unsatisfiable > unknown > skip > ok).
      def verdict(rec)
        niche = niche_verdict(rec)
        split = door_split_verdict(rec)
        { 'state' => worst([niche['state'], split['state']]),
          'niche' => niche, 'door_split' => split,
          'text' => verdict_text(niche, split) }
      end

      # Codex #384 kolo 1 (P2): `unknown` delenia SA ZOBRAZUJE. Verdikt vie
      # povedat, PRECO sa delenie neda odporucit („list nedáva rozmery dverí
      # spotrebiča"), a to je presne ten druh informacie, ktora podla F7/F9
      # patri do riadku Spotrebic — nie do Kontroly. Zahadzovat ju znamenalo,
      # ze riadok o deleni ticho mlcal a pouzivatel nevedel, ci sa nekontroluje,
      # alebo je v poriadku. Ton riadku sa tym NEMENI (warn je len `clash`
      # a `unsatisfiable`). `na` sa nezobrazuje: „delenie sa netýka" je stav
      # skrinky, nie modelu, a riadok je o modeli.
      def verdict_text(niche, split)
        parts = []
        parts << niche['text'].to_s unless niche['state'] == 'na'
        parts << split['text'].to_s unless split['state'] == 'na'
        parts.reject { |p| p.to_s.strip.empty? }.join(' · ')
      end

      # Kontrola vyraba nalez LEN pre `clash` a `unsatisfiable` (Astra FIX F7 +
      # F9: ziadna nova zavaznost INFO — `unknown`, `skip` a `na` ziju v riadku
      # Spotrebic, nie v zozname Kontroly).
      # -> [{ 'code', 'axis', 'message' }]
      # `computed` = uz spocitany `verdict(rec)` (Kontrola ho potrebuje aj tak) —
      # bez neho sa dopocita, takze volajuci nemusi nic vediet.
      def findings(rec, computed = nil)
        name = display_name(rec)
        out = []
        full = computed.is_a?(Hash) ? computed : verdict(rec)
        v = full['niche'].is_a?(Hash) ? full['niche'] : niche_verdict(rec)
        Hash(v['axes']).each do |axis, st|
          next unless st == 'clash'

          out << { 'code' => 'niche_clash', 'axis' => axis,
                   'message' => niche_message(name, axis, rec, v) }
        end
        s = full['door_split'].is_a?(Hash) ? full['door_split'] : door_split_verdict(rec)
        if s['state'] == 'clash'
          out << { 'code' => 'door_split', 'axis' => nil,
                   'message' => "Skrinka so spotrebičom „#{name}“: #{s['text']}." }
        elsif s['state'] == 'unsatisfiable'
          out << { 'code' => 'door_split', 'axis' => nil,
                   'message' => "Spotrebič „#{name}“: #{s['reason']} — delenie čiel sa nedá odporučiť." }
        end
        out
      end

      def niche_message(name, axis, rec, verdict_niche)
        label = AXIS_LABEL[axis] || axis
        niche = niche_of(rec)
        interior = rec['interior'].is_a?(Hash) ? rec['interior'] : {}
        # Astra C FIX 7: TA ISTA dostupna vyska ako verdikt (vnutro − osadenie)
        # — inak by Kontrola radila opacnu opravu nez Inspector.
        m = axis == 'height' ? mount_offset(rec) : 0.0
        have = axis == 'height' ? effective_height(rec) : num(interior[axis])
        if m.positive? && (!have || !have.positive? || rec['single_zone'] == false)
          return "Spotrebič „#{name}“ — #{verdict_niche['axis_texts'][axis]}."
        end

        tail = m.positive? ? " (vnútro #{mm(num(interior[axis]))} − osadenie #{mm(m)})" : ''
        lo = num(niche["#{axis}_min"])
        hi = num(niche["#{axis}_max"])
        if lo && have && have < lo - EPS
          return "Spotrebič „#{name}“ potrebuje niku #{label} min #{mm(lo)}, skrinka má #{mm(have)}#{tail}."
        end
        if hi && have && have > hi + EPS
          return "Spotrebič „#{name}“ potrebuje niku #{label} najviac #{mm(hi)}, skrinka má #{mm(have)}#{tail}."
        end

        "Spotrebič „#{name}“ — #{verdict_niche['axis_texts'][axis]}."
      end

      # === pomocne ============================================================

      def owner_kind(rec)
        owner = rec['owner'].is_a?(Hash) ? rec['owner'] : {}
        owner['kind'].to_s
      end

      # Rozmery niky zo SNAPSHOTU polozky. Snapshot aj `appliance_refs[]` pisal
      # ten isty transakcny vstup (`ApplianceBinding.apply!`) z toho isteho
      # katalogoveho zaznamu, takze sa nemozu rozist — a snapshot je uz v zazname
      # zberu, takze netreba druhy zdroj.
      def niche_of(rec)
        snap = rec['snapshot'].is_a?(Hash) ? rec['snapshot'] : {}
        snap['niche'].is_a?(Hash) ? snap['niche'] : {}
      end

      # Astra FIX F3: „chybaju udaje niky" plati, ked NIKTORA os nema pouzitelnu
      # hodnotu — neuplny zaznam (napr. bez `depth_min`) sa da skontrolovat na
      # zvysnych osiach a hlasit ho ako uplne nepouzitelny by bol falosny poplach.
      def specs_missing?(niche)
        return true unless niche.is_a?(Hash)

        NICHE_FIELDS.none? { |f| num(niche[f]) }
      end

      def display_name(rec)
        n = rec['name'].to_s.strip
        n.empty? ? 'bez názvu' : n
      end

      def worst(states)
        list = Array(states).map(&:to_s).reject(&:empty?)
        return 'ok' if list.empty?

        list.max_by { |s| RANK[s] || 0 }
      end

      # Kladne aj zaporne konecne cislo; nil = „nevieme" (nikdy 0).
      def num(v)
        return nil unless v.is_a?(Numeric)

        f = v.to_f
        f.finite? ? f : nil
      end

      # Cele mm bez desatin, inak jedno desatinne miesto so slovenskou ciarkou —
      # ten isty tvar, aky pouzivaju hlasky ciel aj Kontroly.
      def mm(v)
        f = v.to_f
        (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f).tr('.', ',')
      end

      def join_sk(list)
        items = Array(list).map(&:to_s).reject(&:empty?)
        return '' if items.empty?
        return items.first if items.length == 1

        "#{items[0..-2].join(', ')} a #{items[-1]}"
      end
    end
  end
end
