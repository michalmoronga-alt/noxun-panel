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

      # Variant identity lookupy (dup guard pri create; audit FIX 16).
      # 2A-1 (audit F8): porovnanie bezi VYHRADNE cez kanonicke identity kluce
      # (Materials.sheet_identity_key / edge_identity_key) — v SCHEMA 1 su to
      # presne dnesne pravidla (doska dekor+typ+hrubka, ABS dekor+sirka+hrubka),
      # v SCHEMA 2 pribuda struktura (a pri PD format). Volitelne argumenty
      # SCHEMA 2 su v SCHEMA 1 ignorovane, takze volajuci ich smie posielat vzdy.
      #
      # SCHEMA 2 kontrakt volajuceho: kotvou skupiny je `group_id` (migracia 2A-2
      # ho zapise KAZDEMU zaznamu, UI ho pri praci s dekorom drzi). Bez neho sa
      # dotaz opiera o obchodnu identitu skupiny (vyrobca + dekor).
      def find_sheet_variant(decor, type, thickness, structure = nil, sheet_size = nil,
                             group_id: nil, manufacturer: nil)
        schema = catalog_schema
        want = sheet_identity_key({ 'decor' => decor, 'type' => type, 'thickness' => thickness,
                                    'structure' => structure, 'sheet_size' => sheet_size,
                                    'group_id' => group_id, 'manufacturer' => manufacturer }, schema)
        # GH P2: tolerancne porovnanie klucov — hranicne hrubky drzia legacy spravanie.
        sheets.find { |s| identity_keys_tolerant?(sheet_identity_key(s, schema), want) }
      end

      def find_edge_variant(decor, width, thickness, structure = nil, group_id: nil, manufacturer: nil)
        schema = catalog_schema
        want = edge_identity_key({ 'decor' => decor, 'width' => width, 'thickness' => thickness,
                                   'structure' => structure, 'group_id' => group_id,
                                   'manufacturer' => manufacturer }, schema)
        # GH P2: tolerancne porovnanie klucov — hranicne hrubky/sirky drzia legacy spravanie.
        edges.find { |a| identity_keys_tolerant?(edge_identity_key(a, schema), want) }
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
      # 2A-1: zoskupenie ide cez kanonicke identity kluce (kluc je OPAQUE, popis
      # sa preto sklada z PRVEHO kolidujuceho zaznamu, nie z kluca).
      def dup_variant_in(data)
        schema = catalog_schema
        # GH P2: group_by by hranicne dvojice (18.004 vs 18.006) nespojil —
        # duplicitny sken porovnava kluce tolerancne (male n, O(n^2) je ok).
        s = tolerant_dup(data['sheets']) { |r| sheet_identity_key(r, schema) }
        return sheet_variant_label(s) if s
        e = tolerant_dup(data['edges']) { |r| edge_identity_key(r, schema) }
        e && edge_variant_label(e)
      end

      def tolerant_dup(rows)
        keyed = Array(rows).map { |r| [r, yield(r)] }
        keyed.each_with_index do |(rec, key), i|
          keyed[(i + 1)..].each do |(_, other)|
            return rec if identity_keys_tolerant?(key, other)
          end
        end
        nil
      end

      def sheet_variant_label(rec)
        parts = [rec['decor'].to_s, rec['structure'].to_s, rec['type'].to_s].reject(&:empty?)
        "#{parts.join(' ')} #{fmt_mm(rec['thickness'])} mm"
      end

      def edge_variant_label(rec)
        parts = [rec['decor'].to_s, rec['structure'].to_s].reject(&:empty?)
        w = edge_width(rec)
        "ABS #{parts.join(' ')} #{w ? "#{fmt_mm(w)}/" : ''}#{fmt_mm(rec['thickness'])} mm"
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

      # Zabezpeci jednotkovu pasku dekoru daneho sheetu pouzitelnu pre jeho hrubku.
      # SERVEROVA autorita modalu (JS checku sa neveri — audit BLOCKER 3): stav sa
      # overi znova a zapis bezi az po vsetkych kontrolach (audit FIX 8). Katalogovy
      # zapis je MIMO model undo — volajuci to hlasi pouzivatelovi (NOTE 9).
      # 2A-2 (audit BLOCKER 2): client_schema = schema KLIENTA (panel z CEF cache
      # ju zatial neposiela => default legacy). Po migracii katalogu na SCHEMA 2
      # stary klient pasku NEVYTVORI — dostal by legacy zapis bez identitnych
      # poli (rovnaky kontrakt ako schema_write_allowed?). Pri katalogu SCHEMA 1
      # sa spravanie NEMENI ani o chlp (dormantnost davky 2A-2).
      # 2A-3 (audit F14): SCHEMA 2 vetva — najprv pouzitelna EXISTUJUCA paska cez
      # abs_for_sheet (vetva A aj B); ak treba TVORIT: hrubka = preferovana
      # jednotkova hrubka UZ POUZIVANA skupinou (0,8 -> 1 -> 1,2 podla toho, co
      # skupina ma; bez jednotkovej pasky -> kanonicka 1,0; NIKDY 0,4),
      # structure = struktura dosky, sirka z AUTO_WIDTHS, group_id z dosky.
      # GH #90 P2 (3. kolo, O-ensure): doska BEZ struktury dava dovytvorenej
      # paske universal:true — v skupine bez struktur je to jedina cesta k jej
      # pouzitelnosti (prazdna != zhoda) a "vedomost" priznaku nesie modal
      # potvrdeny pouzivatelom; doska SO strukturou universal NENASTAVUJE
      # (dedi strukturu). SCHEMA 1 vetva = dnesne spravanie + nove AUTO_WIDTHS.
      # Vrati [:exists|:created, abs_id] alebo
      # [:schema_read_only|:no_sheet|:no_standard_width|:write_failed, nil].
      def ensure_edge_for_sheet(material_id, client_schema: SCHEMA_LEGACY)
        server = catalog_schema
        if server >= SCHEMA_GROUPS && client_schema.to_i < server
          return [:schema_read_only, nil]
        end
        s = sheet(material_id)
        return [:no_sheet, nil] unless s
        th = s['thickness'].to_f
        part_th = th.positive? ? th : nil
        # Sheet-aware cesta LEN pre migrovany zaznam (nesie group_id). Zaznam
        # bez group_id v marker-2 katalogu je hybridny medzistav (realne len
        # testove/rucne ohnute subory — write guard kompletnost vynucuje):
        # strukturne pravidla sa nan neaplikuju, plati legacy vztah dekoru.
        schema2 = server >= SCHEMA_GROUPS && !s['group_id'].to_s.strip.empty?
        existing = if schema2
                     abs_for_sheet(s, :jednotka, part_th).first
                   else
                     abs_for_decor(s['decor'], 1.0, part_th)
                   end
        return [:exists, existing] if existing
        width = auto_width_for(th)
        return [:no_standard_width, nil] unless width
        create_th = schema2 ? ensure_edge_thickness_for_group(s) : 1.0
        # D-42: cena sa NEuvadza (nezadana) — dovytvorena paska caka na doplnenie
        # ceny (rozlisenie nezadana vs 0), nie ticha 0.
        rec = {
          'abs_id' => generate_edge_id(s['decor'], create_th, width,
                                       structure: (schema2 ? s['structure'] : nil)),
          'decor' => s['decor'],
          'thickness' => create_th, 'width' => width, 'color' => s['color']
        }
        # Codex GH P2 (3. kolo): v SCHEMA 2 katalogu MUSI nova paska niest
        # identitu skupiny dosky (group_id + struktura, prazdne sa vynechavaju)
        # — inak by ju write_unlocked completeness guard odmietol a ensure by
        # vzdy koncil :write_failed.
        if schema2
          gid = s['group_id'].to_s.strip
          rec['group_id'] = gid unless gid.empty?
          st = s['structure'].to_s.strip
          if st.empty?
            # GH #90 P2 (3. kolo): bezstrukturna doska — universal je jedina
            # cesta, ktorou picker novu pasku vobec najde (prazdna != zhoda);
            # bez neho by kazdy retry zakladal dalsie nepouzitelne zaznamy.
            rec['universal'] = true
          else
            rec['structure'] = st
          end
        end
        return [:write_failed, nil] unless upsert_edge(rec)
        [:created, rec['abs_id']]
      end

      # 2A-3 (audit F14 / O2): hrubka dovytvaranej pasky = prva preferencia
      # jednotky, ktoru skupina UZ POUZIVA (leskle MG maju len 1,0 — nova paska
      # nesmie zaviest 0,8, ktoru dekor realne nema); skupina bez jednotkovej
      # pasky -> kanonicka 1,0. NIKDY 0,4.
      def ensure_edge_thickness_for_group(s)
        group_edges = edges_of_group(s)
        EDGE_CLASS_PREFERENCE[:jednotka].find do |t|
          group_edges.any? { |a| (a['thickness'].to_f - t).abs < 0.01 }
        end || 1.0
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
      #
      # 2A-3b (audit B5): kompatibilna matica davky — rozhoduje SERVER podla
      # schemy CIELA (marker katalogu), klientovi sa neveri. Katalog SCHEMA 1
      # prijima len batch 1/2 (dnesne spravanie, nizsie); SCHEMA 2 prijima LEN
      # plne validny batch 3 (add_decor_batch_v3). Klientovu schemu okna strazi
      # nad tym existujuci catalog_schema guard (schema_write_allowed? v dialogu)
      # — obe osi su kontrolovane.
      def add_decor_batch(attrs)
        batch_schema = (attrs['batch_schema'] || attrs[:batch_schema]).to_i
        if catalog_schema >= SCHEMA_GROUPS
          unless batch_schema >= 3
            return [false, 'Katalóg je v novom formáte — obnov okno „Materiály“ a skús znova.']
          end
          return add_decor_batch_v3(attrs)
        end
        if batch_schema >= 3
          return [false, 'Katalóg ešte nie je prepnutý na nový formát — dávka v novom formáte sa nedá uložiť.']
        end
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
          if find_sheet_variant(decor, vt, th, nil, size, manufacturer: manufacturer)
            skipped << "#{vt} #{fmt_mm(th)}"
            next
          end
          # 2A-1 (audit F12): ID sklada VYHRADNE spolocny generator — davka mu
          # len podava vlastny kumulativny zoznam obsadenych ID (polozky jednej
          # davky si tak ID neprepisu).
          id = generate_sheet_id(decor, vt, th, sheet_size: size, taken: taken)
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

        # 2A-1: dedup v ramci davky ide cez rovnaky kluc ako identita variantu
        # (sirka+hrubka na 2 desatiny) — 22 a 22.004 ostavaju jedna paska.
        seen_abs = []
        abs_list.each do |(w, th)|
          pair_key = [width_key(w), thickness_key(th)]
          next if seen_abs.include?(pair_key)
          seen_abs << pair_key
          # ABS zaznam vyrobcu NENESIE (vyrobca je vlastnost dekorovej skupiny
          # cez dosky, standard 7.5) — dotaz ho preto tiez neposiela.
          if find_edge_variant(decor, w, th)
            skipped << "ABS #{fmt_mm(w)}/#{fmt_mm(th)}"
            next
          end
          id = generate_edge_id(decor, th, w, taken: taken)
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

      # --- 2A-3b: batch schema 3 (audit B4 + B5 + F13) -------------------------
      # Davka pre katalog SCHEMA 2: 'decor' = CISLO dekoru (K009), 'decor_name'
      # = volitelny zobrazovaci nazov skupiny, 'structure' per variant (doska aj
      # ABS), 'universal' per ABS variant (vedomy priznak, default false).
      # Stringove polia (thicknesses/abs_tokens) su VYHRADNE batch 1/2 — tu sa
      # odmietnu (strukturu nenesu, ticha interpretacia by zalozila zle varianty).
      # Identity porovnania idu VYHRADNE cez kanonicke helpery so schemou CIELA
      # (sheet/edge_identity_key(rec, 2) + identity_keys_tolerant?).
      def add_decor_batch_v3(attrs)
        decor = (attrs['decor'] || attrs[:decor]).to_s.strip
        return [false, 'Číslo dekoru je povinné.'] if decor.empty?
        unless (attrs['thicknesses'] || attrs[:thicknesses]).to_s.strip.empty? &&
               (attrs['abs_tokens'] || attrs[:abs_tokens]).to_s.strip.empty?
          return [false, 'Nový formát dávky zadáva varianty štruktúrovane — textové polia hrúbok/ABS už neplatia.']
        end
        manufacturer = (attrs['manufacturer'] || attrs[:manufacturer]).to_s.strip
        decor_name = (attrs['decor_name'] || attrs[:decor_name]).to_s.strip
        type = (attrs['type'] || attrs[:type]).to_s.strip
        type = 'DTDL' if type.empty?
        grain = (attrs['grain'] || attrs[:grain] || 'length').to_s
        return [false, 'Smer dekoru musí byť length/width/none.'] unless GRAINS.include?(grain)
        color = normalize_rgb(attrs['color'] || attrs[:color], [216, 196, 160])

        ok_s, sheet_entries = parse_sheet_entries_v3(attrs, type)
        return [false, sheet_entries] unless ok_s
        ok_e, edge_entries = parse_edge_entries_v3(attrs)
        return [false, edge_entries] unless ok_e
        ok_ds, sheet_items = dedup_sheet_entries_v3(sheet_entries)
        return [false, sheet_items] unless ok_ds
        ok_de, edge_items = dedup_edge_entries_v3(edge_entries)
        return [false, edge_items] unless ok_de
        if sheet_items.empty? && edge_items.empty?
          return [false, 'Zadaj aspoň jeden variant dosky alebo ABS pásku.']
        end

        # GH #91 P1: CELE read-modify-write pod JEDNYM medziprocesovym zamkom
        # (reentrantny with_catalog_lock z 2A-2) + cerstvy load (invalidate —
        # cache by mohla drzat ~1 s stary obsah spred cudzieho zapisu). Dva
        # sucasne batche z dvoch SketchUpov sa serializuju; neskorsi vidi
        # zapisy skorsieho (dup checky aj resolve skupiny bezia nad cerstvym).
        with_catalog_lock do
        JsonFileStore.invalidate(path)
        ok_g, group = resolve_batch_group(manufacturer, decor, decor_name)
        return [false, group] unless ok_g
        # GH #91 P2: NOVA znackova skupina bez jedinej dosky sa zaklada NESMIE —
        # vyrobcu nesie doska (standard 7.5), edge-only zapis by identitu
        # skupiny stratil a group_id by ostal navzdy zablokovany koliziou.
        # Pridavanie pasok do EXISTUJUCEJ znackovej skupiny funguje normalne.
        if group['new'] && !manufacturer.empty? && sheet_items.empty?
          return [false, 'Značková skupina potrebuje pri založení aspoň jednu dosku (výrobcu nesie doska) — pridaj dosku alebo výrobcu vynechaj.']
        end

        gid = group['group_id']
        gname = group['decor_name']
        data = load
        taken = (data['sheets'].map { |s| s['material_id'].to_s.upcase } +
                 data['edges'].map { |a| a['abs_id'].to_s.upcase })
        created_sheets = []
        created_edges = []
        skipped = []

        sheet_items.each do |it|
          if find_sheet_variant(decor, it['type'], it['thickness'], it['structure'],
                                it['sheet_size'], group_id: gid, manufacturer: manufacturer)
            skipped << v3_sheet_label(it)
            next
          end
          id = generate_sheet_id(decor, it['type'], it['thickness'], structure: it['structure'],
                                 sheet_size: it['sheet_size'], taken: taken, schema: SCHEMA_GROUPS)
          taken << id.upcase
          # B4: group_id (+ decor_name skupiny) nesie KAZDY zaznam davky — dosky
          # aj pasky sa stretnu v jednej skupine bez textovej zhody.
          data['sheets'] << normalize_sheet(
            'material_id' => id, 'family' => "#{manufacturer} #{decor}".strip,
            'manufacturer' => manufacturer, 'decor' => decor, 'type' => it['type'],
            'thickness' => it['thickness'], 'grain' => grain, 'color' => color,
            'sheet_size' => it['sheet_size'], 'group_id' => gid,
            'decor_name' => gname, 'structure' => it['structure']
          )
          created_sheets << id
        end

        edge_items.each do |it|
          if find_edge_variant(decor, it['width'], it['thickness'], it['structure'], group_id: gid)
            skipped << "ABS #{v3_edge_label(it)}"
            next
          end
          id = generate_edge_id(decor, it['thickness'], it['width'],
                                structure: it['structure'], taken: taken)
          taken << id.upcase
          data['edges'] << normalize_edge(
            'abs_id' => id, 'decor' => decor, 'thickness' => it['thickness'],
            'width' => it['width'], 'color' => color, 'group_id' => gid,
            'decor_name' => gname, 'structure' => it['structure'],
            'universal' => it['universal']
          )
          created_edges << id
        end

        if created_sheets.empty? && created_edges.empty?
          return [false, "Všetky zadané varianty už v katalógu sú (#{skipped.join(', ')})."]
        end
        # write_unlocked — zamok uz drzime (with_catalog_lock je reentrantny,
        # ale priama cesta je bez zbytocneho druheho handle).
        return [false, 'Zápis katalógu zlyhal.'] unless write_unlocked(data)
        [true, { 'sheets' => created_sheets, 'edges' => created_edges, 'skipped' => skipped }]
        end
      end

      # 2A-3b (audit B4): skupina davky. NAJPRV presna obchodna identita
      # (vyrobca + cislo, presne texty) -> existujuci group_id sa PREVEZME;
      # near-match (vzor decor_conflict — rozdiel len pismom/medzerami) = chyba
      # s presnym tvarom; inak NOVY deterministicky group_id_for (rovnaka
      # autorita ako migracia 2A-2) s koliznou kontrolou proti obsadenym gid.
      # decor_name je vlastnost skupiny: existujucej sa davkou NEMENI (iny
      # neprazdny nazov = chyba, prazdny = zdedi sa). Vrati [true, hash]/[false, chyba].
      def resolve_batch_group(manufacturer, decor, decor_name)
        reg = v3_groups_registry
        exact = reg.values.find { |g| g['manufacturer'] == manufacturer && g['decor'] == decor }
        if exact
          if !decor_name.empty? && decor_name != exact['decor_name']
            return [false, "Skupina #{decor} už má názov „#{exact['decor_name']}“ — názov sa mení v katalógu, nie dávkou."] unless exact['decor_name'].empty?
            return [false, "Skupina #{decor} zatiaľ nemá názov — názov sa dopĺňa v katalógu, nie dávkou."]
          end
          return [true, { 'group_id' => exact['group_id'], 'decor_name' => exact['decor_name'] }]
        end
        near = reg.values.find do |g|
          decor_norm_key(g['manufacturer']) == decor_norm_key(manufacturer) &&
            decor_norm_key(g['decor']) == decor_norm_key(decor)
        end
        if near
          label = [near['manufacturer'], near['decor']].reject(&:empty?).join(' ')
          return [false, "Skupina sa líši od existujúcej „#{label}“ len zápisom — použi presný tvar."]
        end
        gid = group_id_for(manufacturer, decor)
        if reg.key?(gid)
          return [false, "Kolízia identifikátora skupiny (#{gid}) s inou skupinou — nahlás tento stav."]
        end
        # 'new' => true: skupina davkou VZNIKA (GH #91 P2 — znackova nova
        # skupina vyzaduje aspon jednu dosku, vid guard v add_decor_batch_v3).
        [true, { 'group_id' => gid, 'decor_name' => decor_name, 'new' => true }]
      end

      # Existujuce skupiny katalogu: group_id => {manufacturer, decor, decor_name}.
      # Vyrobcu nesie DOSKA (standard 7.5) — zaznam skupiny sa preto klucuje
      # z prvej dosky; skupina len s paskami ma vyrobcu prazdny. decor_name =
      # prvy neprazdny v skupine (konzistentny katalog ich ma zhodne vsade).
      def v3_groups_registry
        reg = {}
        entry = lambda do |gid|
          reg[gid] ||= { 'group_id' => gid, 'manufacturer' => '', 'decor' => '',
                         'decor_name' => '', 'has_sheet' => false }
        end
        sheets.each do |s|
          gid = s['group_id'].to_s.strip
          next if gid.empty?
          e = entry.call(gid)
          next if e['has_sheet']
          e['manufacturer'] = s['manufacturer'].to_s.strip
          e['decor'] = s['decor'].to_s.strip
          e['has_sheet'] = true
          name = s['decor_name'].to_s.strip
          e['decor_name'] = name unless name.empty?
        end
        edges.each do |a|
          gid = a['group_id'].to_s.strip
          next if gid.empty?
          e = entry.call(gid)
          e['decor'] = a['decor'].to_s.strip if e['decor'].empty?
          name = a['decor_name'].to_s.strip
          e['decor_name'] = name if e['decor_name'].empty? && !name.empty?
        end
        reg
      end

      # Polozky dosiek batch 3 — VYHRADNE strukturovane varianty
      # [{type?, thickness, structure?, sheet_size?}]; striktny parse (jedna
      # pokazena polozka = chyba celej davky). PD variant MUSI niest format —
      # v SCHEMA 2 je format sucast identity (vzor migracie O8: PD bez formatu
      # je nerozhodnutelny variant). Vrati [ok, polozky|chyba].
      def parse_sheet_entries_v3(attrs, default_type)
        entries = []
        Array(attrs['sheet_variants'] || attrs[:sheet_variants]).each do |v|
          return [false, 'Poškodená položka variantov dosky — obnov okno a skús znova.'] unless v.is_a?(Hash)
          vt = (v['type'] || v[:type]).to_s.strip
          vt = default_type if vt.empty?
          th = strict_num(v['thickness'] || v[:thickness])
          return [false, "Hrúbka variantu #{vt} musí byť kladné číslo."] unless th && th.positive?
          ok_size, size = parse_variant_size(v['sheet_size'] || v[:sheet_size], vt, th)
          return [false, size] unless ok_size
          if pd_type?(vt) && size.nil?
            return [false, "Variant #{vt} #{fmt_mm(th)} potrebuje formát platne (pri PD je súčasťou identity)."]
          end
          entries << { 'type' => vt, 'thickness' => th, 'sheet_size' => size,
                       'structure' => (v['structure'] || v[:structure]).to_s.strip }
        end
        [true, entries]
      end

      # ABS varianty batch 3: sirka povinna, hrubka zo whitelistu CIELA
      # (SCHEMA 2 = obchodne hodnoty vratane 0,4 — zalozenie zaznamu je vedome,
      # picker ju len nikdy nevyberie sam), struktura volitelna, universal bool.
      def parse_edge_entries_v3(attrs)
        entries = []
        Array(attrs['edge_variants'] || attrs[:edge_variants]).each do |v|
          return [false, 'Poškodená položka variantov ABS — obnov okno a skús znova.'] unless v.is_a?(Hash)
          w = strict_num(v['width'] || v[:width])
          return [false, "Šírka ABS „#{v['width'] || v[:width]}“ musí byť 10–200 mm."] unless w && EDGE_WIDTH_RANGE.cover?(w)
          th = strict_num(v['thickness'] || v[:thickness])
          unless th && supported_edge_thickness?(th, SCHEMA_GROUPS)
            return [false, "Hrúbka ABS „#{v['thickness'] || v[:thickness]}“ musí byť #{edge_thickness_options_label(SCHEMA_GROUPS)} mm."]
          end
          entries << { 'width' => w, 'thickness' => th,
                       'structure' => (v['structure'] || v[:structure]).to_s.strip,
                       'universal' => flag_true?(v['universal'] || v[:universal]) }
        end
        [true, entries]
      end

      # Dedup dosiek batch 3 cez kanonicky kluc CIELA (typ+hrubka+struktura,
      # pri PD aj format). Vsetky polozky su strukturovane cipy — rovnaka
      # identita dvakrat je CHYBA davky (ziadny tichy prvy-vyhrava).
      def dedup_sheet_entries_v3(entries)
        seen = []
        out = []
        entries.each do |it|
          key = [identity_norm(it['type']), thickness_key(it['thickness']),
                 identity_norm(it['structure']),
                 pd_type?(it['type']) ? size_key(it['sheet_size']) : nil]
          if seen.any? { |p| identity_keys_tolerant?(p, key) }
            return [false, "Variant #{v3_sheet_label(it)} je v dávke dvakrát — nechaj len jeden."]
          end
          seen << key
          out << it
        end
        [true, out]
      end

      # 2A-3b (audit F13): dedup ABS batch 3 — rovnaka identita variantu
      # (sirka+hrubka+struktura) s ROVNAKYM universal = tichy dedup (ako
      # doteraz); s ROZNYM universal = chyba CELEJ davky (validate-all —
      # priznak vyberu nesmie rozhodnut tichy prvy-vyhrava).
      def dedup_edge_entries_v3(entries)
        seen = []
        out = []
        entries.each do |it|
          key = [width_key(it['width']), thickness_key(it['thickness']), identity_norm(it['structure'])]
          prev = seen.find { |p| identity_keys_tolerant?(p[0], key) }
          if prev
            if prev[1] != it['universal']
              return [false, "ABS #{v3_edge_label(it)} je v dávke raz ako univerzálna a raz nie — rozhodni jedno."]
            end
            next
          end
          seen << [key, it['universal']]
          out << it
        end
        [true, out]
      end

      def v3_sheet_label(it)
        parts = [it['type'], it['structure']].map(&:to_s).reject(&:empty?)
        "#{parts.join(' ')} #{fmt_mm(it['thickness'])}"
      end

      def v3_edge_label(it)
        st = it['structure'].to_s
        "#{fmt_mm(it['width'])}/#{fmt_mm(it['thickness'])}#{st.empty? ? '' : " #{st}"}"
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
          unless th && supported_edge_thickness?(th)
            return [false, "Hrúbka ABS „#{v['thickness'] || v[:thickness]}“ musí byť #{edge_thickness_options_label} mm."]
          end
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
        pd_formats = catalog_schema >= SCHEMA_GROUPS
        entries.each do |(vt, th, size, src)|
          # 2A-1: ten isty kluc identity ako pri variantoch (typ case-insensitive,
          # hrubka na 2 desatiny, tolerancne — GH P2). V SCHEMA 2 je pri PD
          # sucastou kluca aj FORMAT (GH P2: PD 38 4100x600 + 4100x920 v jednej
          # davke su dva legalne varianty, nie duplicita).
          skey = (pd_formats && pd_type?(vt)) ? size_key(size) : nil
          prev = seen.find do |p|
            p[0] == identity_norm(vt) &&
              (p[1] - thickness_key(th)).abs < 0.011 &&
              p[3] == skey
          end
          if prev
            if strict && !(prev[2] == :text && src == :text)
              return [false, "Variant #{vt} #{fmt_mm(th)} mm je v dávke dvakrát — nechaj len jeden " \
                             '(inak by bolo nejasné, ktorý formát platne platí).']
            end
            next
          end
          seen << [identity_norm(vt), thickness_key(th), src, skey]
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

      # "23/1, 43/1, 43/2" -> [[23.0, 1.0], [43.0, 1.0], [43.0, 2.0]].
      # Sirka povinna (nove pasky su sirkove; univerzalne = legacy zaznamy),
      # hrubka ABS zo schema-aware whitelistu, desatiny bodkou. Ziadny predbezny ciarkovy guard
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
          return [false, "ABS „#{t}“ zapíš ako šírka/hrúbka (napr. 23/1, desatiny bodkou)."] unless m
          w = m[1].to_f
          th = m[2].to_f
          return [false, "Šírka ABS „#{t}“ musí byť 10–200 mm."] unless EDGE_WIDTH_RANGE.cover?(w)
          unless supported_edge_thickness?(th)
            return [false, "Hrúbka ABS „#{t}“ musí byť #{edge_thickness_options_label} mm."]
          end
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
