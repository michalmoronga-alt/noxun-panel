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
                             group_id: nil, manufacturer: nil, back_decor: nil, back_structure: nil)
        schema = catalog_schema
        want = sheet_identity_key({ 'decor' => decor, 'type' => type, 'thickness' => thickness,
                                    'structure' => structure, 'sheet_size' => sheet_size,
                                    'group_id' => group_id, 'manufacturer' => manufacturer,
                                    'back_decor' => back_decor, 'back_structure' => back_structure }, schema)
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
      #
      # 2A-4a (audit B3): v SCHEMA 2 sa skupina identifikuje cez group_id
      # (kwarg ma prednost; text dekoru je len fallback pre legacy volania
      # s JEDNOZNACNYM mapovanim — klient 1 group_id zatial neposiela) a zapis
      # meni VYHRADNE zaznamy danej skupiny. group_id sa pri rename NIKDY
      # neprepocitava (navzdy zmrazeny hash). SCHEMA 1 = presne dnesne
      # spravanie (group_id sa ignoruje).
      def rename_decor(old_decor, new_decor, group_id: nil)
        return [false, catalog_read_only_message] if catalog_read_only?
        # GH #92 P1: CELA transakcia (resolve + load + validacie + zapis) pod
        # zamkom nad CERSTVYM obsahom — stale whole-catalog snapshot uz nemoze
        # prepisat subezny cudzi zapis (patch/ensure/batch z ineho procesu).
        with_catalog_lock do
        JsonFileStore.invalidate(path)
        return rename_decor_group(old_decor, new_decor, group_id) if catalog_schema >= SCHEMA_GROUPS
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
      end

      # 2A-4a (audit B3): cielova skupina operacie v SCHEMA 2 katalogu.
      # group_id ma prednost; textovy dekor je fallback LEN pri jednoznacnom
      # mapovani — text matchujuci viac skupin (rovnake cislo u dvoch vyrobcov)
      # sa odmietne s dovodom, ziadny tichy zasah do cudzej skupiny.
      # Vrati [true, zaznam registra] alebo [false, hlaska].
      def resolve_group_target(decor, group_id)
        reg = v3_groups_registry
        gid = group_id.to_s.strip
        unless gid.empty?
          entry = reg[gid] || reg.values.find { |g| identity_norm(g['group_id']) == identity_norm(gid) }
          return [false, 'Dekorová skupina sa nenašla.'] unless entry
          return [true, entry]
        end
        d = decor.to_s.strip
        return [false, 'Dekor je povinný.'] if d.empty?
        matches = reg.values.select { |g| g['decor'] == d }
        return [false, 'Dekor sa nenašiel.'] if matches.empty?
        if matches.length > 1
          mans = matches.map { |g| g['manufacturer'].empty? ? 'bez výrobcu' : g['manufacturer'] }.sort
          return [false, "Číslo dekoru „#{d}“ majú viaceré skupiny (#{mans.join(', ')}) — operácia potrebuje konkrétnu skupinu."]
        end
        [true, matches.first]
      end

      # SCHEMA 2 vetva rename_decor: meni text dekoru VYHRADNE zaznamom danej
      # group_id. Kolizne guardy su SKUPINOVE (standard 7.1): rovnaky vyrobca
      # nesmie mat dve skupiny s rovnakym (ani len zapisom odlisnym) cislom;
      # rovnake cislo u INEHO vyrobcu je legalne (dve skupiny). Zlucenie
      # skupin sa premenovanim nerobi — group_id ostava zmrazeny.
      def rename_decor_group(old_decor, new_decor, group_id)
        to = new_decor.to_s.strip
        return [false, 'Dekor je povinný.'] if to.empty?
        ok, entry = resolve_group_target(old_decor, group_id)
        return [false, entry] unless ok
        return [false, 'Nový názov je rovnaký.'] if entry['decor'] == to
        gid = entry['group_id']
        man_key = decor_norm_key(entry['manufacturer'])
        v3_groups_registry.each_value do |g|
          next if g['group_id'] == gid
          next unless decor_norm_key(g['manufacturer']) == man_key
          if g['decor'] == to
            return [false, "Výrobca už má skupinu „#{to}“ — zlúčenie skupín sa premenovaním nerobí."]
          end
          if decor_norm_key(g['decor']) == decor_norm_key(to)
            return [false, "Názov sa líši od existujúcej skupiny „#{g['decor']}“ len zápisom — použi presný tvar."]
          end
        end
        data = load
        changed = 0
        %w[sheets edges].each do |k|
          data[k].each do |r|
            next unless identity_norm(r['group_id']) == identity_norm(gid)
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
      # 2A-4a (audit B3): v SCHEMA 2 identifikacia skupiny cez group_id (text
      # len jednoznacny fallback) — rovnaky dispatch ako rename_decor.
      def set_decor_manufacturer(decor, manufacturer, clear: false, group_id: nil)
        return [false, catalog_read_only_message] if catalog_read_only?
        # GH #92 P1: rovnaka kriticka sekcia ako rename (viz komentar tam).
        with_catalog_lock do
        JsonFileStore.invalidate(path)
        if catalog_schema >= SCHEMA_GROUPS
          return set_decor_manufacturer_group(decor, manufacturer, clear: clear, group_id: group_id)
        end
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
        return [false, 'Zápis katalógu zlyhal.'] unless write_unlocked(data)
        [true, changed]
        end
      end

      # SCHEMA 2 vetva set_decor_manufacturer: meni vyrobcu VYHRADNE doskam
      # danej group_id. Vyrobca je sucast obchodnej identity skupiny (standard
      # 7.1) — zmena, ktora by zdvojila identitu s inou skupinou (rovnaky
      # vyrobca + cislo, aj len zapisom odlisne), sa odmietne.
      # GH #93 P2: NAZOV skupiny (decor_name) je zobrazovacia vlastnost (standard
      # 7.1 — oprava/preklad identitu nemeni), doteraz vsak nemal editacnu cestu.
      # Meni sa atomicky celej skupine cez group_id (SCHEMA 2 only); prazdny
      # nazov kluc odstrani. RMW pod zamkom nad cerstvym obsahom (vzor rename).
      def set_decor_name(group_id, name)
        return [false, catalog_read_only_message] if catalog_read_only?
        return [false, 'Katalóg ešte nie je v novom formáte.'] if catalog_schema < SCHEMA_GROUPS
        gid = group_id.to_s.strip
        return [false, 'Chýba identifikátor skupiny.'] if gid.empty?
        to = name.to_s.strip
        with_catalog_lock do
        JsonFileStore.invalidate(path)
        data = load
        changed = 0
        %w[sheets edges].each do |k|
          data[k].each do |r|
            next unless identity_norm(r['group_id']) == identity_norm(gid)
            if to.empty?
              r.delete('decor_name')
            else
              r['decor_name'] = to
            end
            changed += 1
          end
        end
        return [false, 'Dekorová skupina sa nenašla.'] if changed.zero?
        return [false, 'Zápis katalógu zlyhal.'] unless write(data)
        [true, changed]
        end
      end

      def set_decor_manufacturer_group(decor, manufacturer, clear:, group_id:)
        man = manufacturer.to_s.strip
        if man.empty? && !clear
          return [false, 'Prázdny výrobca — na vymazanie použi tlačidlo „Zmazať výrobcu“.']
        end
        ok, entry = resolve_group_target(decor, group_id)
        return [false, entry] unless ok
        gid = entry['group_id']
        clash = v3_groups_registry.values.find do |g|
          g['group_id'] != gid &&
            decor_norm_key(g['manufacturer']) == decor_norm_key(man) &&
            decor_norm_key(g['decor']) == decor_norm_key(entry['decor'])
        end
        if clash
          label = [man, entry['decor']].reject { |v| v.to_s.empty? }.join(' ')
          return [false, "Skupina „#{label}“ už existuje — dve skupiny nemôžu mať rovnakého výrobcu aj číslo dekoru."]
        end
        data = load
        changed = 0
        data['sheets'].each do |s|
          next unless identity_norm(s['group_id']) == identity_norm(gid)
          s['manufacturer'] = man
          s['family'] = "#{man} #{s['decor']}".strip
          changed += 1
        end
        return [false, 'Dekor nemá dosky (výrobcu nesie doska).'] if changed.zero?
        return [false, 'Zápis katalógu zlyhal.'] unless write(data)
        [true, changed]
      end

      # --- D-82: farba dekorovej skupiny --------------------------------------
      # Farba je vlastnost DEKORU (skupiny), nie variantu — presne ako vyrobca
      # (D-42 FIX 7). Doteraz ju niesol kazdy zaznam zvlast, menila sa len vo
      # variantovych formularoch a kazda cesta vzniku (batch, Demos, duplak) ju
      # stavala inak; vysledok bolo "hnede more" na katalogovej mriezke.
      # Teraz: JEDNA zmena prefarbi cely dekor — dosky AJ pasky — v JEDNOM
      # atomickom zapise (vzor set_decor_manufacturer 1:1, rovnaka kriticka
      # sekcia). Vrati [true, pocet zaznamov] alebo [false, hlaska].
      def set_decor_color(decor, color, group_id: nil)
        return [false, catalog_read_only_message] if catalog_read_only?
        rgb = parse_rgb(color)
        return [false, 'Neplatná farba — očakávam #RRGGBB alebo [r,g,b] 0–255.'] unless rgb
        # GH #92 P1: rovnaka kriticka sekcia ako rename/manufacturer.
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          if catalog_schema >= SCHEMA_GROUPS
            ok, entry = resolve_group_target(decor, group_id)
            return [false, entry] unless ok
            gid = entry['group_id']
            # UNI su CHRANENE: ich farby su pracovne rozlisovacie znaky roli
            # (Korpus/Celo/Dekor2/HDF/Doska). Prefarbenie na realny dekor by
            # opticky schovalo semafor ORANGE „materiál neurčený".
            return [false, uni_color_locked_message] if uni_group?(gid, entry['decor'])
            data = load
            changed = paint_records(data, rgb) { |r| identity_norm(r['group_id']) == identity_norm(gid) }
          else
            d = decor.to_s.strip
            return [false, 'Dekor je povinný.'] if d.empty?
            return [false, uni_color_locked_message] if uni_group?(nil, d)
            data = load
            changed = paint_records(data, rgb) { |r| r['decor'].to_s == d }
          end
          return [false, 'Dekorová skupina sa nenašla.'] if changed.zero?
          return [false, 'Zápis katalógu zlyhal.'] unless write_unlocked(data)
          [true, changed]
        end
      end

      def uni_color_locked_message
        'UNI je pracovný materiál — jeho farba rozlišuje rolu a nemení sa.'
      end

      # Prefarbi vsetky zaznamy (dosky aj pasky), ktore vyhovuju bloku.
      # Kazdy zaznam dostane VLASTNU kopiu pola (zdielana instancia by sa pri
      # neskorsom zapise do jedneho zaznamu prejavila na celej skupine).
      def paint_records(data, rgb, &match)
        n = 0
        %w[sheets edges].each do |k|
          data[k].each do |r|
            next unless match.call(r)
            r['color'] = rgb.dup
            n += 1
          end
        end
        n
      end

      # Farba ako [r,g,b] 0-255 z '#RRGGBB' AJ z pola (JS posiela pole, rucne
      # volanie a testy hex) — cokolvek ine je nil (volajuci odmietne zapis).
      def parse_rgb(value)
        if value.is_a?(Array) && value.size == 3 &&
           value.all? { |v| v.is_a?(Numeric) || v.to_s.strip.match?(/\A\d+\z/) }
          rgb = value.map { |v| v.to_i }
          return rgb if rgb.all? { |v| (0..255).cover?(v) }
          return nil
        end
        m = value.to_s.strip.match(/\A#?([0-9a-fA-F]{6})\z/)
        return nil unless m
        [m[1][0, 2], m[1][2, 2], m[1][4, 2]].map { |h| h.to_i(16) }
      end

      # ULOZENA farba skupiny z dat V RUKE (pod zamkom) — JEDINA autorita pri
      # vzniku noveho variantu. group_id ma prednost (SCHEMA 2), text dekoru je
      # legacy fallback. Prazdna skupina = nil (volajuci pouzije DEFAULT_DECOR_RGB).
      def group_color_in(data, group_id, decor)
        gid = group_id.to_s.strip
        dec = decor.to_s.strip
        rows = (data['sheets'] || []) + (data['edges'] || [])
        hit = rows.find do |r|
          next false unless r['color'].is_a?(Array) && r['color'].size == 3
          if !gid.empty?
            identity_norm(r['group_id']) == identity_norm(gid)
          else
            !dec.empty? && r['decor'].to_s.strip == dec
          end
        end
        hit ? hit['color'].map(&:to_i) : nil
      end

      # D-82 (audit B2): farbu zapisovaneho zaznamu urcuje SKUPINA, nie payload.
      # Odstraneny input vo formulari NIE JE ochrana (stary klient z CEF cache,
      # podvrhnuty payload) — TOTO je serverova autorita a bezi POD ZAMKOM nad
      # datami v ruke, tesne pred zapisom:
      #   existujuci zaznam  -> farba OSTAVA (edit variantu ju NIKDY nemeni),
      #   novy do skupiny    -> ulozena farba skupiny (payload nerozhoduje),
      #   novy do NOVEJ skupiny -> hodnota zo zaznamu (prva farba skupiny;
      #     normalize uz doplnil DEFAULT_DECOR_RGB, ked ju volajuci neuviedol).
      def enforce_group_color!(rec, data, kind)
        idk = kind == :edge ? 'abs_id' : 'material_id'
        listk = kind == :edge ? 'edges' : 'sheets'
        old = (data[listk] || []).find { |r| r[idk] == rec[idk] }
        forced = if old && old['color'].is_a?(Array) && old['color'].size == 3
                   old['color'].map(&:to_i)
                 else
                   group_color_in(data, rec['group_id'], rec['decor'])
                 end
        rec['color'] = forced if forced
        rec
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
      # Vrati [:exists|:created, abs_id] alebo [:schema_read_only|:no_sheet|
      # :no_standard_width|:write_failed|:catalog_read_only, nil]
      # (:catalog_read_only = nudzovy rezim 2A-4a, audit B4).
      def ensure_edge_for_sheet(material_id, client_schema: SCHEMA_LEGACY)
        return [:catalog_read_only, nil] if catalog_read_only?
        # GH #103 P1: klient musi rozumiet SKUPINAM (schema 2 tvar pasky) —
        # NIE aktualnemu markeru. Marker rastie aditivnymi poliami (3..7) a
        # ensure ich netvori; porovnanie s markerom by panel (client 2)
        # zamklo hned prvym duplak/demos/uni zaznamom v katalogu.
        server = catalog_schema
        if server >= SCHEMA_GROUPS && client_schema.to_i < SCHEMA_GROUPS
          return [:schema_read_only, nil]
        end
        # GH #91 P1 (2. kolo): CELE read-modify-write pod zamkom s cerstvym
        # loadom — ensure z ineho procesu uz nemoze prepisat cudzi cerstvy
        # zapis (napr. prave dobehnuty batch) svojim predzamkovym snapshotom.
        with_catalog_lock do
        JsonFileStore.invalidate(path)
        s = sheet(material_id)
        return [:no_sheet, nil] unless s
        # V0.6 M-B1 (audit M-B BLOCKER 3): pre UNI sa paska NIKDY nedotvara —
        # server stopka (JS modal je len UX; "Vytvorit a pokracovat" nesmie
        # zalozit globalnu pasku pracovneho materialu).
        return [:uni_material, nil] if uni?(s)
        # M-C (GH #118 P2): nelepitelny material (kompakt / PD postforming) —
        # paska sa NEdotvara; "Vytvorit a pokracovat" nesmie zalozit globalny
        # zaznam pre material, ktory olep zo zasady nema.
        return [:abs_suppressed, nil] if abs_default_suppression(s) == :all
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
        return [false, catalog_read_only_message] if catalog_read_only? # 2A-4a (audit B4)
        batch_schema = (attrs['batch_schema'] || attrs[:batch_schema]).to_i
        if catalog_schema >= SCHEMA_GROUPS
          # GH #91 P2 (3. kolo): PRESNE 3 — buducu schemu 4 nesmieme "ciastocne"
          # interpretovat ako v3 (nove polia by sa ticho ignorovali).
          if batch_schema < 3
            return [false, 'Katalóg je v novom formáte — obnov sekciu „Materiály“ (Obnoviť) a skús znova.']
          end
          if batch_schema > 3
            return [false, 'Dávka je v novšom formáte, než tento katalóg podporuje — obnov sekciu „Materiály“ (Obnoviť).']
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
        color = normalize_rgb(attrs['color'] || attrs[:color], DEFAULT_DECOR_RGB)

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
        # D-82: v legacy katalogu je skupina text dekoru — existujuca skupina
        # svoju ulozenu farbu vnucuje, nova si drzi farbu z formulara.
        color = group_color_in(data, nil, decor) || color
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
        color = normalize_rgb(attrs['color'] || attrs[:color], DEFAULT_DECOR_RGB)

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
        # GH #103 P2: UNI skupina nesmie dostat ABS pasky ani cez davku
        # (+ variant na UNI dlazdici) — rovnaka zasada ako ensure stopka.
        if !edge_items.empty? && uni_group?(nil, decor)
          return [false, 'UNI je pracovný materiál bez ABS pások — pásky dostane až reálny dekor.']
        end

        # GH #91 P1: CELE read-modify-write pod JEDNYM medziprocesovym zamkom
        # (reentrantny with_catalog_lock z 2A-2) + cerstvy load (invalidate —
        # cache by mohla drzat ~1 s stary obsah spred cudzieho zapisu). Dva
        # sucasne batche z dvoch SketchUpov sa serializuju; neskorsi vidi
        # zapisy skorsieho (dup checky aj resolve skupiny bezia nad cerstvym).
        with_catalog_lock do
        JsonFileStore.invalidate(path)
        # GH #93 P2 (10. kolo): rollback z ineho procesu mohol katalog POD nami
        # vratit na legacy — v3 zapis s group_id zaznamami by vyrobil hybridny
        # subor (marker 1 + schema2 polia). Marker sa preto overuje CERSTVO
        # az pod zamkom.
        if catalog_schema_on_disk < SCHEMA_GROUPS
          return [false, 'Katalóg sa medzitým vrátil na pôvodný formát — obnov sekciu „Materiály“ (Obnoviť) a skús znova.']
        end
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
        # D-82: farba je vlastnost SKUPINY. „+ variant" do EXISTUJUCEJ skupiny
        # farbu z formulara IGNORUJE (payload nerozhoduje — davka nesmie skupinu
        # rozdvojit na dve farby); NOVA skupina si ju urci RAZ tu a dostane ju
        # kazdy zaznam davky (dosky aj pasky).
        color = group_color_in(data, gid, decor) || color
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
          existing = find_edge_variant(decor, it['width'], it['thickness'], it['structure'], group_id: gid)
          if existing
            # GH #91 P2 (2. kolo): universal NIE JE identita — existujuci variant
            # s OPACNYM priznakom nie je "skip", ale konflikt (tichy skip by
            # pouzivatelovi klamal, ze universal paska existuje / neexistuje).
            if (existing['universal'] == true) != (it['universal'] == true)
              return [false, "ABS #{v3_edge_label(it)} už existuje s opačným príznakom „univerzálna“ — príznak sa mení v katalógu, nie dávkou."]
            end
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
      # V0.6 M-A: prefer_existing_name: true (Demos create) — nazov zo stranky
      # je len NAVRH: existujuca skupina si drzi svoj nazov bez chyby (Demos
      # texty sa casom menia a nesmu blokovat pridanie variantu do skupiny).
      def resolve_batch_group(manufacturer, decor, decor_name, prefer_existing_name: false)
        reg = v3_groups_registry
        exact = reg.values.find { |g| g['manufacturer'] == manufacturer && g['decor'] == decor }
        if exact
          if !prefer_existing_name && !decor_name.empty? && decor_name != exact['decor_name']
            return [false, "Skupina #{decor} už má názov „#{exact['decor_name']}“ — názov sa mení v katalógu, nie dávkou."] unless exact['decor_name'].empty?
            return [false, "Skupina #{decor} zatiaľ nemá názov — názov sa dopĺňa v katalógu, nie dávkou."]
          end
          # prefer_existing_name: neprazdny existujuci nazov vyhrava; prazdny
          # sa doplni navrhom zo stranky (jedina cesta, ako ho dávka smie dat).
          name = exact['decor_name']
          name = decor_name if prefer_existing_name && name.empty?
          return [true, { 'group_id' => exact['group_id'], 'decor_name' => name }]
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
          # 2B-2 (F10): povinnost formatu riadi register flag (PD + ZASTENA).
          if format_in_identity?(vt) && size.nil?
            return [false, "Variant #{vt} #{fmt_mm(th)} potrebuje formát platne (pri tomto type je súčasťou identity)."]
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
                 format_in_identity?(it['type']) ? size_key(it['sheet_size']) : nil]
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

      # === ŠT-2c PR 2c-2a: ATOMICKY ZAPIS DEKORU (D-69 jednotny editor) ========
      #
      # JEDNA zapisova cesta pre CELY formular editora: identita dekorovej
      # skupiny + riadky dosiek + riadky ABS. Vzor atomicity je
      # add_decor_batch_v3 (jeden zamok, validate-all, JEDEN write), rozsireny
      # o EDIT existujucich riadkov a o skupinove polia v TEJ ISTEJ transakcii.
      #
      # Preco vlastna cesta a nie N x upsert: katalog su CENY REALNYCH
      # OBJEDNAVOK. Formular ulozeny „spolovice" (tri riadky presli, stvrty
      # spadol na validacii) necha pouzivatela s katalogom, o ktorom nevie, co
      # v nom je. Bud vsetko, alebo nic.
      #
      # KONTRAKT (zapracovany slepy audit ŠT-2c — 10 bodov; cisla su
      # v komentaroch nizsie, aby sa dal kazdy bod najst aj o rok):
      #   1 allowlist vstupu — server-owned polia sa STRHAVAJU,
      #   2 riadok nesie material_id/abs_id + row_rev, alebo NIC (= novy),
      #   3 brany PRED zamkom: read-only katalog, schema klienta,
      #   4 POD zamkom: cerstvy marker, base_rev, row_rev KAZDEHO riadku,
      #   5 validate-all (ziadny fail-fast) — vsetky chyby NARAZ,
      #   6 validacie = zjednotenie dnesnych bran (formular + batch + patch),
      #   7 riadok s ID meni LEN neidentitne polia; ziadny zaznam sa NEMAZE,
      #   8 skupinove polia atomicky celej skupine v TEJ ISTEJ transakcii,
      #   9 zmena ceny bez zmeny vazby na dodavatela rusi price_checked_at,
      #  10 [:ok, {...}] | [:invalid|:stale|:conflict|:code_conflict|
      #     :catalog_read_only|:write_failed, {...}]; pri :ok JEDEN write.

      # (1) ALLOWLIST. Co v zozname NIE JE, sa strhne uz na vstupe — nie preto,
      # ze by klient podvadzal, ale preto, ze formular posiela CELY zaznam
      # a server-owned polia (price_checked_at, uni/uni_role, source_* duplaku,
      # group_id/color/family na RIADKU) urcuje VYHRADNE server. Bez allowlistu
      # by stacil jeden stary klient z CEF cache a datum overenia ceny alebo
      # duplakova vazba by sa ticho prepisali hodnotou z obrazovky.
      SAVE_DECOR_KEYS = %w[mode group_id decor decor_name manufacturer color grain
                           sheets edges base_rev catalog_schema allow_duplicate_code].freeze
      # Riadok dosky: identita variantu (typ/hrubka/format/struktura) + obchodne
      # polia. demos_url tu ZAMERNE NIE JE — vazbu na dodavatela ma vlastnu
      # autoritu (Demos modal / formular varianty, rozhodnutie auditu #4).
      SAVE_DECOR_SHEET_KEYS = %w[material_id row_rev type thickness sheet_size structure
                                 code supplier price_per_m2].freeze
      # Riadok ABS: 'universal' tu NIE JE — je to vlastnost VYBERU a ostava
      # patch-only (audit #8), inak by ho editor menil „mimochodom".
      SAVE_DECOR_EDGE_KEYS = %w[abs_id row_rev width thickness structure
                                code supplier price_per_bm].freeze

      # Vstupny hash zredukovany na allowlist (string aj symbolove kluce —
      # JSON z UI da stringy, testy a Ruby volania symboly).
      def sd_pick(raw, keys)
        out = {}
        return out unless raw.is_a?(Hash)
        keys.each do |k|
          if raw.key?(k)
            out[k] = raw[k]
          elsif raw.key?(k.to_sym)
            out[k] = raw[k.to_sym]
          end
        end
        out
      end

      # (5) Jedna chyba validate-all. `row` = nil pre skupinove pole, inak
      # "sheets:<index>" / "edges:<index>" (klient podla toho rozsvieti bunku
      # PRI RIADKU); `field` = kluc pola formulara.
      def sd_err(row, field, msg)
        { 'row' => row, 'field' => field, 'msg' => msg }
      end

      def sd_str(v)
        v.to_s.strip
      end

      def sd_rows(raw)
        raw.is_a?(Array) ? raw : []
      end

      # Struktury povrchu, ktore skupina UZ ma: normalizovany kluc => zapis tak,
      # ako je v katalogu. Novy riadok formulara strukturu NENESIE (nie je to
      # stlpec) — dedi ju po skupine; skupina s VIACERYMI strukturami je
      # nerozhodnutelna a povie to nahlas (variant sa pridava cez „+ variant").
      def sd_group_structures(data, gid)
        seen = {}
        %w[sheets edges].each do |k|
          Array(data[k]).each do |r|
            next unless identity_norm(r['group_id']) == identity_norm(gid)
            key = identity_norm(r['structure'])
            seen[key] = r['structure'].to_s.strip unless seen.key?(key)
          end
        end
        seen
      end

      # Zaznamy skupiny v datach V RUKE (pod zamkom).
      def sd_group_rows(data, listk, gid)
        Array(data[listk]).select { |r| identity_norm(r['group_id']) == identity_norm(gid) }
      end

      def save_decor(attrs)
        a = sd_pick(attrs, SAVE_DECOR_KEYS)
        mode = sd_str(a['mode'])
        mode = 'edit' if mode.empty?
        unless mode == 'edit'
          return [:invalid, { 'errors' => [sd_err(nil, 'mode',
                                                  'Editor upravuje existujúci dekor — nový sa zakladá vlastnou cestou.')] }]
        end
        # (3) BRANY PRED ZAMKOM. Read-only katalog aj stary klient sa odmietaju
        # skor, nez sa cokolvek nacita — zamok drzi len skutocna praca.
        return [:catalog_read_only, { 'message' => catalog_read_only_message }] if catalog_read_only?
        unless schema_write_allowed?(a['catalog_schema'])
          return [:stale, { 'message' => 'Katalóg je v novom formáte — obnov Štúdio (Obnoviť) a potom ulož.' }]
        end
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          # (4) Marker CERSTVO z disku: rollback z ineho procesu mohol katalog
          # pod nami vratit na legacy a zapis so skupinovymi polami by vyrobil
          # hybridny subor (vzor add_decor_batch_v3).
          if catalog_schema_on_disk < SCHEMA_GROUPS
            return [:stale, { 'message' => 'Katalóg sa medzitým vrátil na pôvodný formát — obnov sekciu „Materiály“ a skús znova.' }]
          end
          base = sd_str(a['base_rev'])
          if base.empty? || base != catalog_revision
            return [:stale, { 'message' => 'Katalóg sa medzitým zmenil — hodnoty v okne ostali, over ich a ulož znova.' }]
          end
          save_decor_locked(a)
        end
      rescue StandardError => e
        Engine.log_error(e, 'Materials.save_decor') if defined?(Engine)
        [:write_failed, { 'message' => 'Uloženie katalógu zlyhalo.' }]
      end

      # Telo transakcie — bezi VYHRADNE zvnutra save_decor (zamok drzi volajuci).
      def save_decor_locked(a)
        gid_in = sd_str(a['group_id'])
        if gid_in.empty?
          return [:invalid, { 'errors' => [sd_err(nil, 'group_id',
                                                  'Chýba identifikátor dekorovej skupiny — obnov sekciu „Materiály“ a skús znova.')] }]
        end
        ok, group = resolve_group_target(nil, gid_in)
        return [:invalid, { 'errors' => [sd_err(nil, 'group_id', group)] }] unless ok
        gid = group['group_id']
        data = load
        # NEZAVISLY snimok stavu, ktory klient videl. `load` vracia hlbku kopiu,
        # takze `orig` neziju tie iste hashe ako `data` — skupinova zmena
        # (premenovanie, farba) ich uz nesmie prepisat, inak by sa row_rev
        # porovnaval proti zaznamu, ktory sme sami zmenili.
        orig = {}
        base = load
        %w[sheets edges].each do |k|
          idk = k == 'edges' ? 'abs_id' : 'material_id'
          Array(base[k]).each { |r| orig[[k, r[idk].to_s]] = r }
        end

        sheet_rows = sd_rows(a['sheets'])
        edge_rows  = sd_rows(a['edges'])

        # (4) row_rev / existencia — TVRDE brany pred validate-all. Su to stavy
        # sveta (niekto iny pisal), nie chyby formulara: pisat ich k poliam by
        # bolo klamstvo, pouzivatel ma dostat cerstvy katalog.
        gate = save_decor_row_gate(orig, gid, sheet_rows, edge_rows)
        return gate if gate

        errors = []
        plan = save_decor_group_plan(a, group, data, errors)
        # (8) Skupinove polia sa do dat v ruke zapisuju PRED riadkami — inak by
        # zaznam prestavany z riadku formulara prepisal prave premenovany dekor
        # (a farba noveho variantu by prisla zo stareho stavu skupiny).
        # Zapis na disk to este nie je: pri chybe sa cela kopia zahodi.
        save_decor_apply_group!(data, gid, plan)
        sheets_out = save_decor_sheet_rows(data, group, plan, sheet_rows, errors)
        edges_out  = save_decor_edge_rows(data, group, plan, edge_rows, errors)
        # (5) Jediná chyba = ZIADNY zapis. Vsetky sa vracaju NARAZ — inak by
        # pouzivatel opravoval formular po jednom poli a kazdy pokus by bol
        # dalsi kruh cez server.
        return [:invalid, { 'errors' => errors }] unless errors.empty?

        created = { 'sheets' => [], 'edges' => [] }
        updated = []
        skipped = []
        [['sheets', sheets_out, 'material_id'], ['edges', edges_out, 'abs_id']].each do |(listk, rows, idk)|
          kind = listk == 'edges' ? :edge : :sheet
          rows.each do |item|
            case item['op']
            when 'skip' then skipped << item['label']
            when 'update'
              rec = enforce_group_color!(item['rec'], data, kind)
              idx = data[listk].index { |r| r[idk] == rec[idk] }
              next if idx.nil? || data[listk][idx] == rec # riadok sa nemeni
              data[listk][idx] = rec
              updated << rec[idk]
            when 'create'
              rec = enforce_group_color!(item['rec'], data, kind)
              data[listk] << rec
              created[listk] << rec[idk]
            end
          end
        end

        # (6) Duplicitny par kod+dodavatel v SIMULOVANOM FINALNOM stave — vzor
        # apply_demos_batch: dve polozky formulara s rovnakym novym kodom sa
        # uvidia navzajom, nedotknute pary sa nevycitaju.
        conflict = save_decor_code_conflict(data, orig, a['allow_duplicate_code'])
        return conflict if conflict

        if created['sheets'].empty? && created['edges'].empty? && updated.empty? && !plan['changed']
          # Ziadna zmena = ziadny zapis (a teda ani zbytocny bump revizie).
          return [:ok, { 'group_id' => gid, 'created' => [], 'updated' => [],
                         'skipped' => skipped, 'changed' => 0 }]
        end
        # (10) JEDEN write_unlocked na cely formular.
        return [:write_failed, { 'message' => 'Zápis katalógu zlyhal.' }] unless write_unlocked(data)
        [:ok, { 'group_id' => gid,
                'created' => created['sheets'] + created['edges'],
                'updated' => updated, 'skipped' => skipped,
                'changed' => created['sheets'].size + created['edges'].size + updated.size }]
      end

      # (4) Brana existencie a odtlacku riadkov. Vrati nil (vsetko sedi) alebo
      # hotovu odpoved [:conflict|:stale, {...}].
      def save_decor_row_gate(orig, gid, sheet_rows, edge_rows)
        [['sheets', sheet_rows, 'material_id'], ['edges', edge_rows, 'abs_id']].each do |(listk, rows, idk)|
          rows.each do |raw|
            next unless raw.is_a?(Hash)
            row = sd_pick(raw, listk == 'edges' ? SAVE_DECOR_EDGE_KEYS : SAVE_DECOR_SHEET_KEYS)
            id = sd_str(row[idk])
            next if id.empty? # (2) riadok bez ID = novy variant, niet co porovnavat
            existing = orig[[listk, id]]
            unless existing
              return [:conflict, { 'id' => id,
                                   'message' => 'Niektorý variant sa medzitým z katalógu stratil — hodnoty ostali, obnov sekciu a skús znova.' }]
            end
            unless identity_norm(existing['group_id']) == identity_norm(gid)
              return [:conflict, { 'id' => id,
                                   'message' => 'Variant patrí inej dekorovej skupine — obnov sekciu „Materiály“ a skús znova.' }]
            end
            rev = sd_str(row['row_rev'])
            if rev.empty? || rev != record_rev(existing)
              return [:stale, { 'id' => id,
                                'message' => 'Niektorý variant medzitým zmenil niekto iný — hodnoty v okne ostali, over ich a ulož znova.' }]
            end
          end
        end
        nil
      end

      # (8) SKUPINOVE POLIA — plan zmien + ich validacie. Zapisuju sa CELEJ
      # skupine (cislo dekoru, vyrobca, nazov, farba) a v TEJ ISTEJ transakcii
      # ako riadky: dva zapisy by znamenali stav, v ktorom je dekor uz
      # premenovany, ale ceny este nie.
      def save_decor_group_plan(a, group, data, errors)
        gid = group['group_id']
        plan = { 'gid' => gid, 'decor' => group['decor'], 'manufacturer' => group['manufacturer'],
                 'decor_name' => group['decor_name'], 'color' => nil, 'grain' => nil,
                 'rename' => false, 'reman' => false, 'rename_name' => false, 'changed' => false }
        # Cislo dekoru — povinne (je to identita skupiny a kluc vazby na ABS).
        if a.key?('decor')
          want = sd_str(a['decor'])
          if want.empty?
            errors << sd_err(nil, 'decor', 'Číslo dekoru je povinné.')
          elsif want != group['decor']
            plan['decor'] = want
            plan['rename'] = true
          end
        end
        # Vyrobca — vlastnost DEKORU. Prazdna hodnota na skupine, ktora vyrobcu
        # MA, je takmer vzdy omyl (D-44 F9) — vymazanie ma vlastne tlacidlo.
        if a.key?('manufacturer')
          want = sd_str(a['manufacturer'])
          if want.empty? && !sd_str(group['manufacturer']).empty?
            errors << sd_err(nil, 'manufacturer',
                             'Prázdny výrobca — na vymazanie použi tlačidlo „Zmazať výrobcu“.')
          elsif want != sd_str(group['manufacturer'])
            plan['manufacturer'] = want
            plan['reman'] = true
          end
        end
        if a.key?('decor_name')
          want = sd_str(a['decor_name'])
          if want != sd_str(group['decor_name'])
            plan['decor_name'] = want
            plan['rename_name'] = true
          end
        end
        # Kolizia obchodnej identity skupiny (standard 7.1): rovnaky vyrobca
        # nesmie mat dve skupiny s rovnakym (ani len zapisom odlisnym) cislom.
        # Porovnava sa proti VYSLEDNEMU stavu — vyrobca sa moze menit v tom
        # istom formulari ako cislo.
        if plan['rename'] || plan['reman']
          man_key = decor_norm_key(plan['manufacturer'])
          v3_groups_registry.each_value do |g|
            next if g['group_id'] == gid
            next unless decor_norm_key(g['manufacturer']) == man_key
            if g['decor'] == plan['decor']
              label = [plan['manufacturer'], plan['decor']].reject { |v| v.to_s.empty? }.join(' ')
              errors << sd_err(nil, plan['rename'] ? 'decor' : 'manufacturer',
                               "Skupina „#{label}“ už existuje — dve skupiny nemôžu mať rovnakého výrobcu aj číslo dekoru.")
              break
            end
            next unless decor_norm_key(g['decor']) == decor_norm_key(plan['decor'])
            errors << sd_err(nil, 'decor',
                             "Názov sa líši od existujúcej skupiny „#{g['decor']}“ len zápisom — použi presný tvar.")
            break
          end
        end
        # Vyrobcu NESIE DOSKA (standard 7.5) — skupina bez dosky ho nema kam
        # zapisat a tichy no-op by pouzivatelovi klamal.
        if plan['reman'] && sd_group_rows(data, 'sheets', gid).empty?
          errors << sd_err(nil, 'manufacturer', 'Dekor nemá dosky (výrobcu nesie doska).')
        end
        # Farba je vlastnost SKUPINY (D-82); UNI ju ma zamknutu — rozlisuje rolu.
        if a.key?('color') && !sd_str(a['color']).empty?
          rgb = parse_rgb(a['color'])
          if rgb.nil?
            errors << sd_err(nil, 'color', 'Neplatná farba — očakávam #RRGGBB alebo [r,g,b] 0–255.')
          elsif uni_group?(gid, group['decor'])
            errors << sd_err(nil, 'color', uni_color_locked_message)
          elsif rgb != group_color_in(data, gid, group['decor'])
            plan['color'] = rgb
          end
        end
        # Smer dekoru je default NOVYCH dosiek (vzor batchu) — existujucim
        # riadkom ho editor nemeni, to je vlastnost variantu vo formulari.
        if a.key?('grain')
          want = sd_str(a['grain'])
          unless want.empty?
            if GRAINS.include?(want)
              plan['grain'] = want
            else
              errors << sd_err(nil, 'grain', 'Smer dekoru musí byť length/width/none.')
            end
          end
        end
        plan['changed'] = plan['rename'] || plan['reman'] || plan['rename_name'] || !plan['color'].nil?
        plan
      end

      # Zapis skupinovych poli do dat V RUKE (ziadny vlastny write — vsetko ide
      # jednym write_unlocked na konci transakcie).
      def save_decor_apply_group!(data, gid, plan)
        return data unless plan['changed']
        %w[sheets edges].each do |k|
          Array(data[k]).each do |r|
            next unless identity_norm(r['group_id']) == identity_norm(gid)
            r['decor'] = plan['decor'] if plan['rename']
            if plan['rename_name']
              plan['decor_name'].to_s.empty? ? r.delete('decor_name') : r['decor_name'] = plan['decor_name']
            end
            r['color'] = plan['color'].dup if plan['color']
            next unless k == 'sheets'
            r['manufacturer'] = plan['manufacturer'] if plan['reman']
            r['family'] = "#{r['manufacturer']} #{r['decor']}".strip if plan['rename'] || plan['reman']
          end
        end
        data
      end

      # Format platne z JEDNEHO textoveho stlpca formulara ("2800x2070",
      # "2800 × 2070", "4100/650"). Vrati [:ok, [l, w]] | [:ok, nil] (prazdne =
      # bez overeneho formatu) | [:bad, hlaska]. Striktne — "2800" alebo
      # "2800x2070x18" je preklep, nie hodnota na uhadnutie.
      def sd_parse_size(raw)
        text = sd_str(raw)
        return [:ok, nil] if text.empty?
        parts = text.split(/[x×*\/,;]/).map { |p| p.strip }.reject(&:empty?)
        unless parts.length == 2
          return [:bad, "Formát platne zadaj ako dĺžka × šírka (napr. 2800×2070)."]
        end
        nums = parts.map { |p| strict_num(p) }
        unless nums.all? { |n| n && n.positive? && SHEET_SIZE_RANGE.cover?(n) }
          return [:bad, "Formát platne musí byť dve čísla #{sheet_size_range_label} mm."]
        end
        [:ok, nums]
      end

      # Struktura NOVEHO riadku: skupina ju urcuje sama (stlpec to nie je).
      # Vrati [true, hodnota] alebo [false, hlaska].
      def sd_new_structure(structures)
        return [true, ''] if structures.empty?
        return [true, structures.values.first] if structures.size == 1
        [false, 'Skupina má viac štruktúr povrchu — nový variant pridaj cez „+ variant“.']
      end

      # (5)(6)(7) RIADKY DOSIEK. Vrati pole poloziek {op, rec|label}; chyby
      # pribudaju do `errors` (ziadny fail-fast).
      def save_decor_sheet_rows(data, group, plan, rows, errors)
        gid = group['group_id']
        structures = sd_group_structures(data, gid)
        taken = Array(data['sheets']).map { |s| s['material_id'].to_s.upcase } +
                Array(data['edges']).map { |e| e['abs_id'].to_s.upcase }
        seen_new = []
        out = []
        rows.each_with_index do |raw, i|
          tag = "sheets:#{i}"
          unless raw.is_a?(Hash)
            errors << sd_err(tag, nil, 'Poškodený riadok dosky — obnov sekciu „Materiály“ a skús znova.')
            next
          end
          row = sd_pick(raw, SAVE_DECOR_SHEET_KEYS)
          item = if sd_str(row['material_id']).empty?
                   save_decor_new_sheet(row, tag, data, plan, structures, taken, seen_new, errors)
                 else
                   save_decor_edit_sheet(row, tag, data, errors)
                 end
          out << item if item
        end
        out
      end

      # (7) EDIT: riadok s ID meni LEN NEIDENTITNE polia. Zmena identitneho pola
      # nie je „oprava", ale INY produkt — a ten sa zaklada, nie prepisuje
      # (zatvorene zakazky by inak dostali pod rukami iny material).
      def save_decor_edit_sheet(row, tag, data, errors)
        id = sd_str(row['material_id'])
        existing = Array(data['sheets']).find { |r| r['material_id'] == id }
        return nil unless existing # gate uz overila; poistka pre priame volania
        patch = row.reject { |k, _| %w[material_id row_rev].include?(k) }
        # (6) duplak deriva vsetko zo zdroja, UNI nema nakupne polia.
        if (dup_err = duplak_edit_error(existing))
          errors << sd_err(tag, nil, dup_err)
          return nil
        end
        if (uni_err = uni_edit_error(existing, patch))
          errors << sd_err(tag, nil, uni_err)
          return nil
        end
        bad = false
        if patch.key?('type') && identity_norm(patch['type']) != identity_norm(existing['type'])
          errors << sd_err(tag, 'type', 'Typ dosky definuje variant — pre iný typ pridaj nový variant.')
          bad = true
        end
        if patch.key?('thickness')
          th = strict_num(patch['thickness'])
          if th.nil? || !th.positive?
            errors << sd_err(tag, 'thickness', 'Hrúbka musí byť kladné číslo.')
            bad = true
          elsif (th - existing['thickness'].to_f).abs > 0.01
            errors << sd_err(tag, 'thickness', 'Hrúbka definuje variant — pre inú hrúbku pridaj nový variant.')
            bad = true
          end
        end
        if patch.key?('structure') &&
           identity_norm(patch['structure']) != identity_norm(existing['structure'])
          errors << sd_err(tag, 'structure',
                           'Štruktúra povrchu definuje variant — pre inú štruktúru pridaj nový variant.')
          bad = true
        end
        size_given = patch.key?('sheet_size')
        if size_given
          st, val, = sd_parse_size(patch['sheet_size'])
          if st == :bad
            errors << sd_err(tag, 'sheet_size', val)
            bad = true
            size_given = false
            patch.delete('sheet_size')
          else
            patch['sheet_size'] = val
          end
        end
        # Format je identita LEN pri typoch s format_in_identity? (PD, ZASTENA,
        # KOMPAKT) — pri DTDL sa smie dopisat aj prepisat. Rozhodnutie patri
        # JEDNEJ autorite (identity_edit_error), `structure` sa jej neposiela,
        # lebo ju uz posudil riadok vyssie (inak by hlaska sadla na zle pole).
        id_attrs = patch.reject { |k, _| k == 'structure' }
        id_attrs['clear_sheet_size'] = true if size_given && patch['sheet_size'].nil?
        if (err = identity_edit_error(id_attrs, existing))
          errors << sd_err(tag, 'sheet_size', err)
          bad = true
        end
        merged = existing.merge(patch)
        merged.delete('sheet_size') if size_given && patch['sheet_size'].nil?
        ok, verr = validate_sheet_attrs(merged)
        unless ok
          errors << sd_err(tag, nil, verr)
          bad = true
        end
        return nil if bad
        # (9) Zmena ceny rusi datum overenia. Vazbu na dodavatela (demos_url)
        # editor nemeni — allowlist ju nenesie — takze KAZDA rucna zmena ceny
        # znamena „cena uz nie je overena voci stranke dodavatela".
        if patch.key?('price_per_m2') &&
           normalize_price(patch['price_per_m2']) != normalize_price(existing['price_per_m2'])
          merged.delete('price_checked_at')
        end
        rec = normalize_sheet(merged)
        if rec.nil?
          errors << sd_err(tag, nil, 'Záznam sa nedá uložiť.')
          return nil
        end
        { 'op' => 'update', 'rec' => rec }
      end

      # (7) NOVY riadok (bez ID) = novy variant s PLNYMI create guardmi.
      def save_decor_new_sheet(row, tag, data, plan, structures, taken, seen_new, errors)
        gid = plan['gid']
        # UNI je pracovny material — dalsie varianty sa don nepridavaju.
        if uni_group?(gid, plan['decor'])
          errors << sd_err(tag, nil, 'UNI je pracovný materiál — nové varianty dostane až reálny dekor.')
          return nil
        end
        type = sd_str(row['type'])
        bad = false
        if type.empty?
          errors << sd_err(tag, 'type', 'Typ dosky je povinný (DTDL/MDF/HDF…).')
          bad = true
        end
        th = strict_num(row['thickness'])
        if th.nil? || !th.positive?
          errors << sd_err(tag, 'thickness', 'Hrúbka musí byť kladné číslo.')
          bad = true
        end
        st, size, = sd_parse_size(row['sheet_size'])
        if st == :bad
          errors << sd_err(tag, 'sheet_size', size)
          bad = true
          size = nil
        end
        if !type.empty? && format_in_identity?(type) && size.nil?
          errors << sd_err(tag, 'sheet_size',
                           "Variant #{canonical_type(type)} potrebuje formát platne (pri tomto type je súčasťou identity).")
          bad = true
        end
        struct = sd_str(row['structure'])
        if struct.empty?
          ok_st, struct = sd_new_structure(structures)
          unless ok_st
            errors << sd_err(tag, 'structure', struct)
            bad = true
            struct = ''
          end
        end
        return nil if bad
        # Duplicita v ramci JEDNEHO formulara je chyba (ziadny tichy
        # prvy-vyhrava), duplicita s katalogom je „uz to tam je" = skip.
        key = [identity_norm(type), thickness_key(th), identity_norm(struct),
               format_in_identity?(type) ? size_key(size) : nil]
        if seen_new.any? { |p| identity_keys_tolerant?(p, key) }
          errors << sd_err(tag, nil, "Variant #{canonical_type(type)} #{fmt_mm(th)} je vo formulári dvakrát — nechaj len jeden.")
          return nil
        end
        seen_new << key
        if find_sheet_variant(plan['decor'], type, th, struct, size,
                              group_id: gid, manufacturer: plan['manufacturer'])
          return { 'op' => 'skip', 'label' => "#{canonical_type(type)} #{fmt_mm(th)} mm" }
        end
        attrs = { 'material_id' => generate_sheet_id(plan['decor'], type, th, structure: struct,
                                                     sheet_size: size, taken: taken,
                                                     schema: SCHEMA_GROUPS),
                  'family' => "#{plan['manufacturer']} #{plan['decor']}".strip,
                  'manufacturer' => plan['manufacturer'], 'decor' => plan['decor'],
                  'decor_name' => plan['decor_name'], 'group_id' => gid,
                  'type' => type, 'thickness' => th, 'structure' => struct,
                  'sheet_size' => size, 'grain' => plan['grain'] || sd_group_grain(data, gid),
                  'code' => row['code'], 'supplier' => row['supplier'],
                  'price_per_m2' => row['price_per_m2'] }
        ok, verr = validate_sheet_attrs(attrs)
        unless ok
          errors << sd_err(tag, nil, verr)
          return nil
        end
        rec = normalize_sheet(attrs)
        if rec.nil?
          errors << sd_err(tag, nil, 'Záznam sa nedá uložiť.')
          return nil
        end
        taken << rec['material_id'].to_s.upcase
        { 'op' => 'create', 'rec' => rec }
      end

      # Smer dekoru NOVEJ dosky: co uz skupina pouziva (prva doska), inak
      # 'length' ako batch. Existujucim riadkom ho editor nemeni.
      def sd_group_grain(data, gid)
        hit = Array(data['sheets']).find do |s|
          identity_norm(s['group_id']) == identity_norm(gid) && GRAINS.include?(s['grain'].to_s)
        end
        hit ? hit['grain'].to_s : 'length'
      end

      # (5)(6)(7) RIADKY ABS. Sirka aj hrubka su identita variantu.
      def save_decor_edge_rows(data, group, plan, rows, errors)
        gid = group['group_id']
        structures = sd_group_structures(data, gid)
        taken = Array(data['sheets']).map { |s| s['material_id'].to_s.upcase } +
                Array(data['edges']).map { |e| e['abs_id'].to_s.upcase }
        seen_new = []
        out = []
        rows.each_with_index do |raw, i|
          tag = "edges:#{i}"
          unless raw.is_a?(Hash)
            errors << sd_err(tag, nil, 'Poškodený riadok ABS — obnov sekciu „Materiály“ a skús znova.')
            next
          end
          row = sd_pick(raw, SAVE_DECOR_EDGE_KEYS)
          item = if sd_str(row['abs_id']).empty?
                   save_decor_new_edge(row, tag, plan, structures, taken, seen_new, errors)
                 else
                   save_decor_edit_edge(row, tag, data, errors)
                 end
          out << item if item
        end
        out
      end

      def save_decor_edit_edge(row, tag, data, errors)
        id = sd_str(row['abs_id'])
        existing = Array(data['edges']).find { |r| r['abs_id'] == id }
        return nil unless existing
        patch = row.reject { |k, _| %w[abs_id row_rev].include?(k) }
        bad = false
        # Hrubka aj sirka su v ID pasky a dielce ju drzia LEN cez ID — zmena by
        # ich potichu prepla na inu hranu a ID by klamalo.
        if patch.key?('thickness')
          th = strict_num(patch['thickness'])
          if th.nil? || (th - existing['thickness'].to_f).abs > 0.01
            errors << sd_err(tag, 'thickness', 'Hrúbka definuje ABS variant — pre inú hrúbku pridaj novú pásku.')
            bad = true
          end
        end
        if patch.key?('width')
          raw_w = sd_str(patch['width'])
          new_w = raw_w.empty? ? nil : strict_num(raw_w)
          old_w = edge_width(existing)
          differs = if old_w.nil?
                      !raw_w.empty?
                    elsif new_w.nil?
                      true
                    else
                      (new_w - old_w).abs > 0.01
                    end
          if differs
            errors << sd_err(tag, 'width', 'Šírka definuje ABS variant — pre inú šírku pridaj novú pásku.')
            bad = true
          end
        end
        if patch.key?('structure') &&
           identity_norm(patch['structure']) != identity_norm(existing['structure'])
          errors << sd_err(tag, 'structure',
                           'Štruktúra povrchu definuje variant — pre inú štruktúru pridaj novú pásku.')
          bad = true
        end
        if (err = identity_edit_error(patch.reject { |k, _| k == 'structure' }, existing))
          errors << sd_err(tag, nil, err)
          bad = true
        end
        # Sirka sa VZDY berie z existujuceho zaznamu (stary klient ju nemusi
        # poslat vobec a merge by ju ticho zmazal).
        merged = existing.merge(patch)
        if existing.key?('width')
          merged['width'] = existing['width']
        else
          merged.delete('width')
        end
        merged['thickness'] = existing['thickness']
        ok, verr = validate_edge_attrs(merged)
        unless ok
          errors << sd_err(tag, nil, verr)
          bad = true
        end
        return nil if bad
        # (9) rovnaky kontrakt ako pri doske
        if patch.key?('price_per_bm') &&
           normalize_price(patch['price_per_bm']) != normalize_price(existing['price_per_bm'])
          merged.delete('price_checked_at')
        end
        rec = normalize_edge(merged)
        if rec.nil?
          errors << sd_err(tag, nil, 'Pásku sa nepodarilo uložiť.')
          return nil
        end
        { 'op' => 'update', 'rec' => rec }
      end

      def save_decor_new_edge(row, tag, plan, structures, taken, seen_new, errors)
        gid = plan['gid']
        # UNI pasky nema — olep sa riesi az s realnym dekorom (GH #103 P2).
        if uni_group?(gid, plan['decor'])
          errors << sd_err(tag, nil, 'UNI je pracovný materiál bez ABS pások — pásky dostane až reálny dekor.')
          return nil
        end
        bad = false
        w = strict_num(row['width'])
        unless w && EDGE_WIDTH_RANGE.cover?(w)
          errors << sd_err(tag, 'width', 'Šírka ABS musí byť 10–200 mm.')
          bad = true
        end
        th = strict_num(row['thickness'])
        unless th && supported_edge_thickness?(th, SCHEMA_GROUPS)
          errors << sd_err(tag, 'thickness',
                           "Hrúbka ABS musí byť #{edge_thickness_options_label(SCHEMA_GROUPS)} mm.")
          bad = true
        end
        struct = sd_str(row['structure'])
        if struct.empty?
          ok_st, struct = sd_new_structure(structures)
          unless ok_st
            errors << sd_err(tag, 'structure', struct)
            bad = true
            struct = ''
          end
        end
        return nil if bad
        key = [width_key(w), thickness_key(th), identity_norm(struct)]
        if seen_new.any? { |p| identity_keys_tolerant?(p, key) }
          errors << sd_err(tag, nil, "ABS #{fmt_mm(w)}/#{fmt_mm(th)} je vo formulári dvakrát — nechaj len jednu.")
          return nil
        end
        seen_new << key
        if find_edge_variant(plan['decor'], w, th, struct, group_id: gid)
          return { 'op' => 'skip', 'label' => "ABS #{fmt_mm(w)}/#{fmt_mm(th)} mm" }
        end
        attrs = { 'abs_id' => generate_edge_id(plan['decor'], th, w, structure: struct, taken: taken),
                  'decor' => plan['decor'], 'decor_name' => plan['decor_name'], 'group_id' => gid,
                  'thickness' => th, 'width' => w, 'structure' => struct,
                  'code' => row['code'], 'supplier' => row['supplier'],
                  'price_per_bm' => row['price_per_bm'] }
        ok, verr = validate_edge_attrs(attrs)
        unless ok
          errors << sd_err(tag, nil, verr)
          return nil
        end
        rec = normalize_edge(attrs)
        if rec.nil?
          errors << sd_err(tag, nil, 'Pásku sa nepodarilo uložiť.')
          return nil
        end
        taken << rec['abs_id'].to_s.upcase
        { 'op' => 'create', 'rec' => rec }
      end

      # (6)(10) Duplicitny par kod+dodavatel v FINALNOM stave. Vycita sa LEN
      # zaznamom, ktorym sa par TOUTO davkou zmenil (vzor apply_demos_batch
      # GH #97 P2) — inak by uz existujuca, vedome povolena duplicita zamrzla
      # kazdy dalsi zapis toho dekoru.
      def save_decor_code_conflict(data, orig, allow)
        return nil if flag_true?(allow)
        pair = ->(r) { [r['code'].to_s.strip.downcase, r['supplier'].to_s.strip.downcase] }
        %w[sheets edges].each do |listk|
          idk = listk == 'edges' ? 'abs_id' : 'material_id'
          index = {}
          Array(data[listk]).each do |r|
            c = r['code'].to_s.strip.downcase
            next if c.empty?
            (index["#{c}|#{r['supplier'].to_s.strip.downcase}"] ||= []) << r[idk].to_s
          end
          Array(data[listk]).each do |r|
            c = r['code'].to_s.strip.downcase
            next if c.empty?
            before = orig[[listk, r[idk].to_s]]
            next if before && pair.call(before) == pair.call(r)
            hits = index["#{c}|#{r['supplier'].to_s.strip.downcase}"].reject { |x| x == r[idk].to_s }
            next if hits.empty?
            return [:code_conflict, { 'id' => r[idk].to_s, 'code' => r['code'].to_s, 'hits' => hits }]
          end
        end
        nil
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
          skey = (pd_formats && format_in_identity?(vt)) ? size_key(size) : nil
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
