# frozen_string_literal: true
# Noxun Engine — materialovy katalog: D-41 dekor = kluc skupiny (premenovanie,
# near-match guardy, vyrobca dekoru, revizia katalogu), dovytvorenie chybajucej
# ABS pasky a batch "Novy dekor". Cast modulu Materials (mechanicky split
# materials.rb, V0.5.1) — pozri materials.rb pre prehlad.

module Noxun
  module Engine
    module Materials
      module_function

      # --- D-41: dekor = kluc skupiny (audit BLOCKER 1) -------------------------
      # Vazba material<->ABS bezi cez PRESNY string 'decor' (trim pri zapise robi
      # normalize_*). Preklepy chytame near-match guardom: novy dekor, ktory sa od
      # existujuceho lisi len velkostou pismen/medzerami, sa odmietne s presnym tvarom.

      # Normalizovany kluc na porovnanie "skoro rovnakych" dekorov. Medzery sa
      # odstranuju UPLNE (Codex GH #70: "U702ST9" vs "U702 ST9" je ten isty
      # preklep ako dvojita medzera — kolaps na jednu by ho prepustil).
      def decor_norm_key(d)
        d.to_s.gsub(/\s+/, '').downcase
      end

      # Existujuci dekor, ktory sa s danym zhoduje na norm kluci, ale NIE presne
      # (preklep/iny zapis). Vrati existujuci string alebo nil.
      def decor_conflict(decor)
        want = decor.to_s.strip
        key = decor_norm_key(want)
        return nil if key.empty?
        all_decors.find { |d| d != want && decor_norm_key(d) == key }
      end

      def all_decors
        (sheets.map { |s| s['decor'].to_s } + edges.map { |a| a['decor'].to_s }).uniq
      end

      # Variant identity lookupy (dup guard pri create; audit FIX 16):
      # sheet = dekor + typ (case-insensitive) + hrubka; edge = dekor + sirka + hrubka.
      def find_sheet_variant(decor, type, thickness)
        d = decor.to_s.strip
        t = type.to_s.strip.upcase
        th = thickness.to_f
        sheets.find do |s|
          s['decor'].to_s == d && s['type'].to_s.strip.upcase == t &&
            (s['thickness'].to_f - th).abs < 0.01
        end
      end

      def find_edge_variant(decor, width, thickness)
        d = decor.to_s.strip
        th = thickness.to_f
        w = width.nil? || width.to_s.strip.empty? ? nil : width.to_s.tr(',', '.').to_f
        edges.find do |a|
          next false unless a['decor'].to_s == d && (a['thickness'].to_f - th).abs < 0.01
          aw = edge_width(a)
          w.nil? ? aw.nil? : (aw && (aw - w).abs < 0.01)
        end
      end

      # Atomicke premenovanie dekoru CELEJ skupiny (sheets + edges, 1 zapis).
      # ID zaznamov sa NIKDY nemenia (modely drzia vazbu cez id) — meni sa len text.
      # Merge do existujucej skupiny je povoleny, len ak nevzniknu duplicitne
      # varianty. Vrati [true, pocet] alebo [false, chyba].
      def rename_decor(old_decor, new_decor)
        from = old_decor.to_s.strip
        to = new_decor.to_s.strip
        return [false, 'Dekor je povinný.'] if from.empty? || to.empty?
        return [false, 'Nový názov je rovnaký.'] if from == to
        conflict = decor_conflict(to)
        if conflict && conflict != from
          return [false, "Názov sa líši od existujúceho „#{conflict}“ len zápisom — použi presný tvar."]
        end
        data = load
        changed = 0
        %w[sheets edges].each do |k|
          data[k].each do |r|
            next unless r['decor'].to_s == from
            r['decor'] = to
            changed += 1
          end
        end
        return [false, 'Dekor sa nenašiel.'] if changed.zero?
        dup = dup_variant_in(data)
        return [false, "Premenovaním by vznikli duplicitné varianty (#{dup}) — zlúčenie nie je možné."] if dup
        return [false, 'Zápis katalógu zlyhal.'] unless write(data)
        [true, changed]
      end

      # Prva duplicitna variant identity v datach (popis) alebo nil.
      def dup_variant_in(data)
        s = data['sheets'].group_by { |r| [r['decor'].to_s, r['type'].to_s.strip.upcase, r['thickness'].to_f.round(2)] }
                          .find { |_, v| v.size > 1 }
        return "#{s[0][0]} #{s[0][1]} #{s[0][2]} mm" if s
        e = data['edges'].group_by { |r| [r['decor'].to_s, edge_width(r)&.round(2), r['thickness'].to_f.round(2)] }
                         .find { |_, v| v.size > 1 }
        e && "ABS #{e[0][0]} #{e[0][1] ? "#{e[0][1]}/" : ''}#{e[0][2]} mm"
      end

      # Kratky odtlacok obsahu katalogu — baseline guard okna (audit FIX 15):
      # formular ulozeny nad starsim stavom sa odmietne, klient si vypyta refresh.
      def catalog_revision
        Digest::SHA1.hexdigest(JSON.generate(catalog))[0, 12]
      end

      # D-42 (audit FIX 7): vyrobca je vlastnost DEKORU (skupiny), nie variantu —
      # meni sa atomicky pre celu skupinu (dosky; ABS vyrobcu nema). Update
      # jednotliveho sheetu vyrobcu NEMENI (guard v handle_save_sheet). Vrati
      # [true, pocet] alebo [false, chyba].
      def set_decor_manufacturer(decor, manufacturer, clear: false)
        d = decor.to_s.strip
        return [false, 'Dekor je povinný.'] if d.empty?
        man = manufacturer.to_s.strip
        # D-44 (audit F9): prazdna hodnota by ticho vymazala vyrobcu CELEJ skupine
        # — pri naseptavaci je omyl (vymazanie textu) lahky. Vymazanie musi byt
        # VEDOMY krok s vlastnym tlacidlom, ktore posle clear_manufacturer.
        if man.empty? && !clear
          return [false, 'Prázdny výrobca — na vymazanie použi tlačidlo „Zmazať výrobcu“.']
        end
        data = load
        changed = 0
        data['sheets'].each do |s|
          next unless s['decor'].to_s == d
          s['manufacturer'] = man
          s['family'] = "#{man} #{d}".strip
          changed += 1
        end
        return [false, 'Dekor nemá dosky (výrobcu nesie doska).'] if changed.zero?
        return [false, 'Zápis katalógu zlyhal.'] unless write(data)
        [true, changed]
      end

      # --- D-41 PR C2: dovytvorenie chybajucej pasky (modal "Vytvorit a pokracovat") --

      # Standardna sirka pasky pre hrubku dielca: najmensia z AUTO_WIDTHS s presahom
      # >= WIDTH_MARGIN; mimo standardov nil (audit BLOCKER 4 — ziadne porusenie
      # presahu, auto-tvorba sa radsej odmietne).
      def auto_width_for(thickness)
        th = thickness.to_f
        AUTO_WIDTHS.find { |w| w >= th + WIDTH_MARGIN - 0.001 }
      end

      # Zabezpeci 1,0 mm pasku dekoru daneho sheetu pouzitelnu pre jeho hrubku.
      # SERVEROVA autorita modalu (JS checku sa neveri — audit BLOCKER 3): stav sa
      # overi znova a zapis bezi az po vsetkych kontrolach (audit FIX 8). Katalogovy
      # zapis je MIMO model undo — volajuci to hlasi pouzivatelovi (NOTE 9).
      # Vrati [:exists|:created, abs_id] alebo [:no_sheet|:no_standard_width|:write_failed, nil].
      def ensure_edge_for_sheet(material_id)
        s = sheet(material_id)
        return [:no_sheet, nil] unless s
        th = s['thickness'].to_f
        existing = abs_for_decor(s['decor'], 1.0, th.positive? ? th : nil)
        return [:exists, existing] if existing
        width = auto_width_for(th)
        return [:no_standard_width, nil] unless width
        # D-42: cena sa NEuvadza (nezadana) — dovytvorena paska caka na doplnenie
        # ceny (rozlisenie nezadana vs 0), nie ticha 0.
        rec = {
          'abs_id' => generate_edge_id(s['decor'], 1.0, width), 'decor' => s['decor'],
          'thickness' => 1.0, 'width' => width, 'color' => s['color']
        }
        return [:write_failed, nil] unless upsert_edge(rec)
        [:created, rec['abs_id']]
      end

      # --- D-41 PR B: batch "Novy dekor" (audit FIX 14) -------------------------
      # Cely vstup sa NAJPRV parsuje a validuje do pamate; JEDINY chybny token
      # zrusi celu davku BEZ zapisu. Existujuce IDENTICKE varianty sa preskocia
      # (report), vsetko nove sa zapise JEDNYM Materials.write. ID sa generuju
      # proti kumulativnemu taken zoznamu (katalog + uz pripravene polozky davky).
      #
      # attrs: decor, manufacturer, type, grain, color([r,g,b]),
      #        thicknesses (string "18, 36"), abs_tokens (string "22/1, 43/1, 43/2"),
      #        D-42 PR C (audit BLOCKER 5) navyse STRUKTUROVANE varianty z preset
      #        cipov: sheet_variants [{type?, thickness}] (typ per variant — "PD 38"
      #        vedla DTDL 18 v JEDNEJ validate-all davke) a edge_variants
      #        [{width, thickness}]. Stringove polia ostavaju (vlastne hodnoty);
      #        vsetko sa zluci a deduplikuje TOLERANCNE podla variant identity.
      #        D-44: batch_schema=2 zapina format platne na variante
      #        (sheet_variants[i].sheet_size = [dlzka, sirka] mm, volitelny) +
      #        striktny parse (poskodena polozka/format = chyba celej davky) a
      #        konflikt rovnakeho typ+hrubka. Identita variantu sa NEMENI —
      #        ostava dekor+typ+hrubka, takze dva "PD 38" s roznym formatom NIE
      #        SU dva zaznamy, ale chyba davky (viac sirok = V0.6).
      # Vrati [true, {sheets:[id...], edges:[id...], skipped:[popis...]}] alebo [false, chyba].
      def add_decor_batch(attrs)
        decor = (attrs['decor'] || attrs[:decor]).to_s.strip
        return [false, 'Dekor je povinný.'] if decor.empty?
        # Preklep guard: near-match s INYM presnym tvarom = stop. Presna zhoda =
        # legitimne doplnanie variantov do existujucej skupiny ("+ variant").
        if (near = decor_conflict(decor))
          return [false, "Dekor sa líši od existujúceho „#{near}“ len zápisom — použi presný tvar."]
        end
        manufacturer = (attrs['manufacturer'] || attrs[:manufacturer]).to_s.strip
        existing_man = sheets.find { |s| s['decor'] == decor && !s['manufacturer'].to_s.strip.empty? }
        if existing_man && !manufacturer.empty? && existing_man['manufacturer'].to_s.strip != manufacturer
          return [false, "Skupina #{decor} už má výrobcu #{existing_man['manufacturer']} — dva výrobcovia v jednej skupine nie sú dovolené."]
        end
        type = (attrs['type'] || attrs[:type]).to_s.strip
        type = 'DTDL' if type.empty?
        grain = (attrs['grain'] || attrs[:grain] || 'length').to_s
        return [false, 'Smer dekoru musí byť length/width/none.'] unless GRAINS.include?(grain)
        color = normalize_rgb(attrs['color'] || attrs[:color], [216, 196, 160])

        ok_th, ths = parse_number_list(attrs['thicknesses'] || attrs[:thicknesses])
        return [false, ths] unless ok_th
        ok_abs, abs_list = parse_abs_tokens(attrs['abs_tokens'] || attrs[:abs_tokens])
        return [false, abs_list] unless ok_abs

        # BLOCKER 5: strukturovane varianty — dosky ako [typ, hrubka] pary (typ
        # per variant, default = spolocny typ formulara), ABS ako [sirka, hrubka].
        # Codex GH #76: STRIKTNE Float parsovanie ("18abc" NIE JE 18) — jedna
        # pokazena strukturovana hodnota rusi CELU davku bez zapisu (validate-all).
        #
        # D-44 (audit F7): schema payloadu. 2 = klient pozna format platne pri
        # variantoch a znasa STRIKTNY parse; chybajuca/ina schema = LEGACY vetva
        # (stary klient z CEF cache ani ulozena sada nesmie dostat chybu).
        strict = (attrs['batch_schema'] || attrs[:batch_schema]).to_i >= 2

        ok_sheets, sheet_entries = parse_sheet_entries(attrs, type, ths, strict)
        return [false, sheet_entries] unless ok_sheets
        ok_edges, abs_list = parse_edge_entries(attrs, abs_list, strict)
        return [false, abs_list] unless ok_edges
        ok_dedup, sheet_pairs = dedup_sheet_entries(sheet_entries, strict)
        return [false, sheet_pairs] unless ok_dedup
        return [false, 'Zadaj aspoň jednu hrúbku dosky alebo ABS pásku.'] if sheet_pairs.empty? && abs_list.empty?

        data = load
        taken = (data['sheets'].map { |s| s['material_id'].to_s.upcase } +
                 data['edges'].map { |a| a['abs_id'].to_s.upcase })
        created_sheets = []
        created_edges = []
        skipped = []

        # Dedup a konflikt riesi dedup_sheet_entries (identita dosky = TYP +
        # hrubka; BLOCKER 5: PD 38 a DTDL 38 su dva varianty).
        sheet_pairs.each do |(vt, th, size)|
          if find_sheet_variant(decor, vt, th)
            skipped << "#{vt} #{fmt_mm(th)}"
            next
          end
          base = "#{slug(decor)}_#{slug(vt)}_#{thickness_token(th)}"
          id = unique_id(base, taken)
          taken << id.upcase
          # D-42: batch NEuklada cenu (nezadana) — doplni sa v tabulke variantov.
          # D-44 (audit B2): format ide do zaznamu LEN ked ho pouzivatel zadal —
          # bez neho normalize_sheet kluc vobec neulozi (ziadny neovereny default).
          data['sheets'] << normalize_sheet(
            'material_id' => id, 'family' => "#{manufacturer} #{decor}".strip,
            'manufacturer' => manufacturer, 'decor' => decor, 'type' => vt,
            'thickness' => th, 'grain' => grain, 'color' => color, 'sheet_size' => size
          )
          created_sheets << id
        end

        seen_abs = []
        abs_list.each do |(w, th)|
          next if seen_abs.any? { |(pw, pt)| (pw - w).abs < 0.01 && (pt - th).abs < 0.01 }
          seen_abs << [w, th]
          if find_edge_variant(decor, w, th)
            skipped << "ABS #{fmt_mm(w)}/#{fmt_mm(th)}"
            next
          end
          base = "ABS_#{slug(decor)}_#{thickness_token(w)}X#{(th * 10).round}"
          id = unique_id(base, taken)
          taken << id.upcase
          data['edges'] << normalize_edge(
            'abs_id' => id, 'decor' => decor, 'thickness' => th,
            'width' => w, 'color' => color
          )
          created_edges << id
        end

        if created_sheets.empty? && created_edges.empty?
          return [false, "Všetky zadané varianty už v katalógu sú (#{skipped.join(', ')})."]
        end
        return [false, 'Zápis katalógu zlyhal.'] unless write(data)
        [true, { 'sheets' => created_sheets, 'edges' => created_edges, 'skipped' => skipped }]
      end

      # --- D-44: polozky davky (zdroj, format platne, konflikty) ---------------

      # Polozky dosiek davky ako [typ, hrubka, format|nil, zdroj]. ZDROJ (:text
      # z pola "Dalsie hrubky" / :chip zo strukturovaneho variantu) rozlisuje
      # ticha duplicita vs konflikt (audit F4). Vrati [ok, polozky|chyba].
      def parse_sheet_entries(attrs, type, ths, strict)
        entries = ths.map { |th| [type, th, nil, :text] }
        Array(attrs['sheet_variants'] || attrs[:sheet_variants]).each do |v|
          unless v.is_a?(Hash)
            # D-44 (audit B3): v schema 2 je poskodena polozka CHYBA celej davky
            # — ticho ju preskocit znamena zapisat menej, nez pouzivatel videl.
            return [false, 'Poškodená položka variantov dosky — obnov okno a skús znova.'] if strict
            next
          end
          vt = (v['type'] || v[:type]).to_s.strip
          vt = type if vt.empty?
          th = strict_num(v['thickness'] || v[:thickness])
          return [false, "Hrúbka variantu #{vt} musí byť kladné číslo."] unless th && th.positive?
          size = nil
          if strict
            ok_size, size = parse_variant_size(v['sheet_size'] || v[:sheet_size], vt, th)
            return [false, size] unless ok_size
          end
          entries << [vt, th, size, :chip]
        end
        [true, entries]
      end

      # Volitelny format platne variantu. Chybajuci/prazdny = nil (zaznam vznikne
      # BEZ formatu, audit B2). Ak je zadany, musi to byt DVOJICA kladnych cisel
      # v SHEET_SIZE_RANGE — ziadny tichy normalize fallback (audit B3/F6).
      # Vrati [true, par|nil] alebo [false, chyba].
      def parse_variant_size(raw, vt, th)
        return [true, nil] if raw.nil?
        return [true, nil] if raw.is_a?(Array) && raw.empty?
        return [true, nil] if raw.is_a?(String) && raw.strip.empty?
        bad = "Formát platne pre #{vt} #{fmt_mm(th)}: zadaj dve čísla #{sheet_size_range_label} mm (alebo nechaj prázdne)."
        return [false, bad] unless raw.is_a?(Array) && raw.size == 2
        pair = raw.map { |x| strict_num(x) }
        return [false, bad] unless pair.all? { |n| n && n.positive? && SHEET_SIZE_RANGE.cover?(n) }
        [true, pair]
      end

      # ABS varianty z cipov — v schema 2 je nehashova polozka CHYBA (audit B3).
      # Vrati [ok, zoznam|chyba]; zoznam je ten isty (mutovany) ako z textoveho pola.
      def parse_edge_entries(attrs, abs_list, strict)
        Array(attrs['edge_variants'] || attrs[:edge_variants]).each do |v|
          unless v.is_a?(Hash)
            return [false, 'Poškodená položka variantov ABS — obnov okno a skús znova.'] if strict
            next
          end
          w = strict_num(v['width'] || v[:width])
          th = strict_num(v['thickness'] || v[:thickness])
          return [false, "Šírka ABS „#{v['width'] || v[:width]}“ musí byť 10–200 mm."] unless w && EDGE_WIDTH_RANGE.cover?(w)
          return [false, "Hrúbka ABS „#{v['thickness'] || v[:thickness]}“ musí byť 1 alebo 2 mm."] unless th && supported_edge_thickness?(th)
          abs_list << [w, th]
        end
        [true, abs_list]
      end

      # Dedup s TOLERANCIOU 0.01 mm (Codex GH #71: 18 a 18.004 su ten isty
      # variant). D-44 (audit F4): v schema 2 je ten isty typ+hrubka DVAKRAT
      # CHYBA davky — formaty by boli nejednoznacne a "vyhral by prvy" ticho.
      # Dva zapisy z TEXTOVEHO pola ("18, 18") ostavaju tichym dedupom (format
      # nenesu, historicke spravanie). Vrati [ok, [[typ, hrubka, format]]|chyba].
      def dedup_sheet_entries(entries, strict)
        seen = []
        out = []
        entries.each do |(vt, th, size, src)|
          prev = seen.find { |p| p[0] == vt.upcase && (p[1] - th).abs < 0.01 }
          if prev
            if strict && !(prev[2] == :text && src == :text)
              return [false, "Variant #{vt} #{fmt_mm(th)} mm je v dávke dvakrát — nechaj len jeden " \
                             '(inak by bolo nejasné, ktorý formát platne platí).']
            end
            next
          end
          seen << [vt.upcase, th, src]
          out << [vt, th, size]
        end
        [true, out]
      end

      # "18, 36" -> [18.0, 36.0]. Desatiny LEN bodkou — ciarka je oddelovac poloziek.
      # NEJEDNOZNACNY je iba vzor cislo,JEDNA cifra bez medzery a bez pokracovania
      # (18,5) — to je takmer iste desatinna ciarka a vrati JASNU chybu (ziadna
      # ticha interpretacia — vzor D-19). Kompaktne zoznamy 18,36 aj 18.5,36 su
      # legalne (Codex GH #71: oddelovac bez medzery nesmie zhodit davku).
      def parse_number_list(raw)
        s = raw.to_s.strip
        return [true, []] if s.empty?
        if (amb = s[/\d+,\d(?![\d.])/])
          return [false, "Nejednoznačný zápis „#{amb}“ — desatiny píš bodkou (18.5), položky oddeľuj čiarkou."]
        end
        out = []
        s.split(',').each do |tok|
          t = tok.strip
          next if t.empty?
          f = begin
            Float(t)
          rescue StandardError
            nil
          end
          return [false, "Hrúbka „#{t}“ nie je kladné číslo."] unless f && f.finite? && f.positive?
          out << f
        end
        [true, out]
      end

      # "22/1, 43/1, 43/2" -> [[22.0, 1.0], [43.0, 1.0], [43.0, 2.0]].
      # Sirka povinna (nove pasky su sirkove; univerzalne = legacy zaznamy),
      # hrubka ABS len 1/2 mm, desatiny bodkou. Ziadny predbezny ciarkovy guard
      # (Codex GH #71: 22/1,43/1 je legalny kompakt) — desatinnu ciarku chyti
      # formatova kontrola tokenu (22,5/1 -> tokeny "22" a "5/1", oba bez zmyslu).
      def parse_abs_tokens(raw)
        s = raw.to_s.strip
        return [true, []] if s.empty?
        out = []
        s.split(',').each do |tok|
          t = tok.strip
          next if t.empty?
          m = t.match(%r{\A(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)\z})
          return [false, "ABS „#{t}“ zapíš ako šírka/hrúbka (napr. 22/1, desatiny bodkou)."] unless m
          w = m[1].to_f
          th = m[2].to_f
          return [false, "Šírka ABS „#{t}“ musí byť 10–200 mm."] unless EDGE_WIDTH_RANGE.cover?(w)
          return [false, "Hrúbka ABS „#{t}“ musí byť 1 alebo 2 mm."] unless supported_edge_thickness?(th)
          out << [w, th]
        end
        [true, out]
      end

      # Codex GH #76: striktne cislo z lubovolneho vstupu — Float() namiesto to_f
      # ("18abc" -> nil, NIE 18.0). Ciarka ako desatina povolena. nil pri chybe.
      def strict_num(raw)
        f = Float(raw.to_s.tr(',', '.'))
        f.finite? ? f : nil
      rescue StandardError
        nil
      end

      # D-45 (audit F10): JEDINY formatovac mm pre TEXTY (labely, reporty, hlasky
      # panela — Panel.fmt_mm deleguje sem). Cele cislo bez desatin, inak
      # desatinna CIARKA: 18.0 -> "18", 18.6 -> "18,6", 1.0 -> "1".
      def fmt_mm(v)
        f = v.to_f.round(2)
        return f.round.to_s if f == f.round
        f.to_s.tr('.', ',')
      end
    end
  end
end
