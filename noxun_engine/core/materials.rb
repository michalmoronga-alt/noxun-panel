# frozen_string_literal: true
# Noxun Engine — materialovy katalog (standard sekcia 7). Perzistencia JSON v
# %APPDATA%\NOXUN\Engine\materials.json + .bak zaloha pri zapise (pattern z templates.rb).
#
# Dve triedy zaznamov v jednom katalogu:
#   sheets — doskove materialy (variant = dekor + typ + hrubka; standard 7.1). production_class sheet.
#   edges  — ABS pasky (variant = dekor + hrubka ABS; standard 7.5).
#
# Materialovy katalog NIE je SketchUp textura. Je to katalogovy zaznam. SketchUp material
# vytvarame LEN na vizual (ensure_su_material) — nazov = material_id, farba z pola color.
# Vyrobny material dielca je ulozeny v jeho NOXUN/config['material_id'] (standard 7.3).
#
# Projektove defaulty (dedenie, standard 7.2) ziju v NOXUN dict na MODELI (project_defaults).
#
# Modul Materials je od V0.5.1 rozdeleny (mechanicky split) do 5 suborov — vsetky
# otvaraju ten isty `module Noxun::Engine::Materials` s module_function, takze
# volania Materials.xyz ostavaju rovnake bez ohladu na fyzicky subor:
#   materials.rb          — TENTO subor: cesty/perzistencia, citanie katalogu,
#                            SketchUp vizualny material, normalizacia zaznamov
#                            a zdielane helpery pouzivane vo viacerych ostatnych suboroch.
#   materials_catalog.rb  — CRUD, validacia + generovanie ID, scan pouzitia, D-42 patch protokol, seed.
#   materials_decor.rb    — D-41 dekor = kluc skupiny, dovytvorenie ABS pasky, batch "Novy dekor".
#   materials_abs.rb      — ABS podla dekoru (picker, pravidlove defaulty, remap).
#   materials_project.rb  — projektove defaulty na modeli + pouzitie dekorov v projekte.
require 'json'
require 'fileutils'
require 'digest'

module Noxun
  module Engine
    module Materials
      STD  = 1
      FILE = 'materials.json'
      # 2A-1: SCHEMA katalogu. 1 = legacy (skupina = presny text dekoru, variant
      # = dekor+typ+hrubka). 2 = skupinova identita (group_id, struktura povrchu,
      # pri PD aj format v identite; standard 7.1/7.5). Cely aparat SCHEMA 2 je
      # pripraveny uz teraz, ale AKTIVUJE ho az migracia (2A-2) prepnutim markera
      # v subore — do vtedy sa spravanie nemeni ani o vlas (dual-mode).
      SCHEMA_LEGACY = 1
      SCHEMA_GROUPS = 2
      # Nemenna PREDMIGRACNA zaloha (standard 7.1) — mimo bezneho .bak, ktory sa
      # pri kazdom zapise prepisuje. Vznikne raz a NIKDY sa neprepise.
      PRE_SCHEMA2_FILE = 'materials.pre-schema-2.json'
      SUPPORTED_EDGE_THICKNESSES = [1.0, 2.0].freeze
      # D-41: sirka ABS pasky (mm). Volitelne pole 'width' na edge zazname —
      # legacy pasky bez sirky su "univerzalne" (pouzitelne pre kazdu hrubku).
      # Picker vyzaduje presah sirky nad hrubku dielca (olep + orez).
      EDGE_WIDTH_RANGE = (10.0..200.0)
      WIDTH_MARGIN = 2.0
      # Standardne sirky pre automaticke dovytvorenie pasky (PR C create-missing):
      # najmensia >= hrubka+MARGIN; mimo standardov sa auto-tvorba odmietne.
      AUTO_WIDTHS = [22.0, 43.0].freeze

      # D-44 (audit F6): povoleny rozsah rozmeru platne (mm) — JEDINA autorita
      # pouzivana formularom (validate_sheet_attrs) AJ batchom "Novy dekor".
      # Dva rozne rozsahy = dva rozne pravdy, preto konstanta.
      SHEET_SIZE_RANGE = (500.0..5000.0)

      # --- 2A-1: register kanonickych typov dosiek (standard 7.1) --------------
      # Typ je DVOJVRSTVOVY: kanonicke typy ziju tu s parametrami, cokolvek mimo
      # registra je "iny" typ = volny string s generickym spravanim (ziadny navrh
      # formatu, ziadne navrhy hrubok). Identita typu je case-insensitive.
      # Kompaktna doska je VLASTNY kanonicky typ (nikdy "PD s podtypom kompakt").
      #   format_hint           — navrh formatu platne (nil = vedome zadanie)
      #   thickness_suggestions — bezne hrubky do naseptavaca (NIE enum)
      #   pd_edge_subtypes      — len PD: hranova uprava (postforming | ABS rovna hrana)
      #   body_candidate        — typ, z ktoreho sa realne stava telo korpusu
      TYPE_REGISTRY = {
        'DTDL' => { 'label' => 'DTD laminovaná', 'format_hint' => [2800.0, 2070.0].freeze,
                    'thickness_suggestions' => [18.0, 19.0, 36.0].freeze, 'body_candidate' => true },
        'MDF' => { 'label' => 'MDF', 'format_hint' => [2800.0, 2070.0].freeze,
                   'thickness_suggestions' => [18.0, 19.0].freeze, 'body_candidate' => true },
        'HDF' => { 'label' => 'HDF', 'format_hint' => [2800.0, 2070.0].freeze,
                   'thickness_suggestions' => [3.0].freeze, 'body_candidate' => false },
        'PD' => { 'label' => 'Pracovná doska', 'format_hint' => nil,
                  'thickness_suggestions' => [38.0, 20.0].freeze,
                  'pd_edge_subtypes' => %w[postforming abs].freeze, 'body_candidate' => false },
        'ZASTENA' => { 'label' => 'Zástena', 'format_hint' => [4100.0, 640.0].freeze,
                       'thickness_suggestions' => [9.2, 10.0].freeze, 'body_candidate' => false },
        'KOMPAKT' => { 'label' => 'Kompaktná doska', 'format_hint' => nil,
                       'thickness_suggestions' => [12.0].freeze, 'body_candidate' => false }
      }.freeze

      # D-44 (audit B2): NAVRH formatu platne podla typu dosky pre nove varianty
      # v batchi. DTDL/MDF/HDF maju de facto standard 2800x2070; PD (pracovna
      # doska) ma sirok vela a lisia sa per vyrobca -> ziadny navrh = vedome
      # zadanie. Neznamy typ = nil. Navrh je len PREDVYPLNENIE viditelneho pola
      # (viditelne = potvrdene odoslanim) — server neuklada neovereny default.
      # 2A-1: derivat TYPE_REGISTRY (hodnoty existujucich typov nezmenene).
      TYPE_FORMAT_HINTS = TYPE_REGISTRY.each_with_object({}) { |(k, v), h| h[k] = v['format_hint'] }.freeze
      # D-44: typy ponukane v naseptavaci aj ked ich katalog este neobsahuje
      # (typ ostava volny string — toto NIE JE enum, len navrhy).
      # 2A-1: navrhy = kanonicke typy z registra.
      SEED_TYPES = TYPE_REGISTRY.keys.freeze

      # Projektove default kluce v NOXUN dict na modeli (koren dedenia projekt->korpus->dielec).
      PROJECT_KEYS = %w[default_material_id default_front_material_id default_back_material_id].freeze
      PROJECT_FALLBACK = {
        'default_material_id'       => 'K009_PW_DTDL_18', # korpus (doska 18)
        'default_front_material_id' => 'W1000_DTDL_18',   # cela (biela celova 18)
        'default_back_material_id'  => 'HDF_WHITE_3'       # chrbat (HDF 3)
      }.freeze
      # Davka 2 (Codex audit, blocker 1): fallback ID su NEDELETOVATELNE — novy model
      # ich pouzije aj bez ulozenych atributov; zmazanie by rozbilo prvy vklad.
      PROTECTED_SHEET_IDS = PROJECT_FALLBACK.values.freeze
      GRAINS = %w[length width none].freeze

      module_function

      # --- cesty / perzistencia ------------------------------------------------

      def dir
        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # Nacita cely katalog { 'sheets' => [...], 'edges' => [...] }. Pri prvom spusteni seedne.
      def load
        JsonFileStore.deep_copy(catalog)
      end

      # Interny read-only pohlad pre lookupy pocas rebuildu. JsonFileStore ho drzi
      # v pamati a subor kontroluje nanajvys raz za CHECK_INTERVAL.
      def catalog
        ensure_seeded
        data = JsonFileStore.read(path, copy: false)
        sheet_records = data['sheets'].is_a?(Array) ? data['sheets'] : seed_sheets
        raw_edges = data['edges'].is_a?(Array) ? data['edges'] : seed_edges
        edge_records = raw_edges.select do |item|
          item.is_a?(Hash) && supported_edge_thickness?(item['thickness'])
        end

        if edge_records != raw_edges
          if write({ 'sheets' => sheet_records, 'edges' => edge_records }) && defined?(Engine)
            Engine.log('materialy: ABS katalog bol obmedzeny na hrubky 1/2 mm')
          end
        end

        {
          'sheets' => sheet_records,
          'edges'  => edge_records
        }
      rescue StandardError => e
        Engine.log_error(e, 'Materials.load') if defined?(Engine)
        { 'sheets' => seed_sheets, 'edges' => seed_edges }
      end

      def sheets
        catalog['sheets']
      end

      def edges
        catalog['edges']
      end

      # Doskovy material podla material_id (alebo nil).
      def sheet(id)
        return nil if id.nil?
        sheets.find { |m| m['material_id'] == id }
      end

      # ABS paska podla abs_id (alebo nil).
      def edge(id)
        return nil if id.nil?
        edges.find { |a| a['abs_id'] == id }
      end

      # Zapis so zalohou: existujuci subor -> .bak, novy cez .tmp + atomicky rename (ako templates.rb).
      # 2A-1: kazdy zapis nesie SCHEMA marker. Bez explicitnej hodnoty sa preberie
      # schema zo suboru (chybajuca = 1), takze bezne mutacie ju nikdy nestratia;
      # explicitne ju posiela LEN migracia (2A-2).
      def write(data)
        payload = { 'std' => STD, 'schema' => target_schema(data['schema']),
                    'sheets' => data['sheets'], 'edges' => data['edges'] }
        JsonFileStore.write(path, payload)
      rescue StandardError => e
        Engine.log_error(e, 'Materials.write') if defined?(Engine)
        false
      end

      # SCHEMA katalogu v subore. Chybajuci/poskodeny marker = 1 (legacy).
      # NESEEDUJE (volane aj z write cez target_schema — seed by sa zacyklil).
      def catalog_schema
        return SCHEMA_LEGACY unless JsonFileStore.available?(path)
        data = JsonFileStore.read(path, copy: false)
        raw = data.is_a?(Hash) ? data['schema'] : nil
        n = raw.to_i
        n >= SCHEMA_LEGACY ? n : SCHEMA_LEGACY
      rescue StandardError
        SCHEMA_LEGACY
      end

      # Schema pre zapis: bez zelania (a pri neplatnej/nizsej hodnote) sa drzi
      # schema suboru. DOWNGRADE je zakazany — oneskoreny payload zo stareho
      # okna nesmie katalog prepnut spat a vyrobit hybridny stav (standard 7.1).
      def target_schema(wanted)
        current = catalog_schema
        n = wanted.to_i
        return current if n <= current
        n
      end

      # --- 2A-1: nemenna predmigracna zaloha (standard 7.1) --------------------

      def pre_schema2_backup_path
        File.join(dir, PRE_SCHEMA2_FILE)
      end

      # Odlozi BAJT-PRESNU kopiu aktualneho katalogu pred migraciou na SCHEMA 2.
      # Existujucu zalohu NIKDY neprepise (druhy beh migracie by inak zahodil
      # posledny predmigracny stav). Vrati cestu k zalohe, alebo false
      # (uz existuje / nie je co zalohovat / zapis zlyhal).
      def write_pre_schema2_backup!
        target = pre_schema2_backup_path
        return false if File.exist?(target)
        return false unless File.exist?(path)
        content = File.binread(path)
        JSON.parse(content) # poskodeny subor sa ako zaloha nezapise
        FileUtils.mkdir_p(dir)
        tmp = "#{target}.tmp-#{Process.pid}"
        File.binwrite(tmp, content)
        File.rename(tmp, target)
        target
      rescue StandardError => e
        Engine.log_error(e, 'Materials.write_pre_schema2_backup!') if defined?(Engine)
        begin
          File.delete(tmp) if tmp && File.exist?(tmp)
        rescue StandardError
          nil
        end
        false
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- SketchUp vizualny material z katalogu -------------------------------

      # Vytvori/najde SketchUp material s nazvom = material_id a farbou z katalogu (pole color [r,g,b]).
      # Nahrada za natvrdo NOXUN_korpus/NOXUN_front. Fallback farba ak material nie je v katalogu.
      def ensure_su_material(model, material_id, fallback_rgb = [216, 196, 160])
        name = (material_id && !material_id.to_s.empty?) ? material_id.to_s : 'NOXUN_material'
        rgb = color_of(material_id) || fallback_rgb
        mt = model.materials[name] || model.materials.add(name)
        mt.color = Sketchup::Color.new(*rgb)
        mt
      rescue StandardError => e
        Engine.log_error(e, 'Materials.ensure_su_material') if defined?(Engine)
        model.materials[material_id.to_s] || model.materials.add('NOXUN_material')
      end

      # Farba doskoveho materialu ([r,g,b]) z katalogu, alebo nil (potom fallback).
      def color_of(material_id)
        s = sheet(material_id)
        return nil unless s && s['color'].is_a?(Array) && s['color'].size == 3
        s['color'].map(&:to_i)
      end

      # --- normalizacia zaznamov ----------------------------------------------

      # D-41 (audit BLOCKER 1): 'decor' je kluc vazby material<->ABS — pri KAZDOM
      # zapise sa trimuje, aby Ruby presna zhoda sedela s JS zhodou (normDecor trim).
      def normalize_sheet(a)
        id = (a['material_id'] || a[:material_id]).to_s
        return nil if id.strip.empty?
        out = {
          'material_id' => id,
          'family'      => (a['family'] || a[:family]).to_s.strip,
          'manufacturer' => (a['manufacturer'] || a[:manufacturer]).to_s.strip,
          'decor'       => (a['decor'] || a[:decor]).to_s.strip,
          'type'        => (a['type'] || a[:type]).to_s.strip,
          'thickness'   => (a['thickness'] || a[:thickness]).to_f,
          'grain'       => (a['grain'] || a[:grain] || 'none').to_s,
          'price_per_m2' => normalize_price(a['price_per_m2'] || a[:price_per_m2]),
          'sheet_size'  => normalize_pair(a['sheet_size'] || a[:sheet_size]),
          'color'       => normalize_rgb(a['color'] || a[:color], [216, 196, 160]),
          'production_class' => 'sheet'
        }
        # D-42: cena ako nil-alebo-Float — kluc sa uklada LEN ked je cena ZADANA
        # (rozlisenie "nezadana" vs "0", audit FIX 11). Nil sa do JSON neuklada.
        out.delete('price_per_m2') if out['price_per_m2'].nil?
        # D-44 (audit B2): format platne je rovnako VOLITELNY — server nikdy
        # neuklada neovereny default 2800x2070 ako DATA. Chybajuci format =
        # odhad platni pouzije fallback A OZNACI ho, semafor "nezmesti sa" o nom
        # mlci (namiesto merania proti vymyslenemu formatu).
        out.delete('sheet_size') if out['sheet_size'].nil?
        put_opt(out, 'code', a['code'] || a[:code])
        put_opt(out, 'supplier', a['supplier'] || a[:supplier])
        put_schema2_fields(out, a)
        out
      end

      # 2A-1 (SCHEMA 2 polia): kotva skupiny + zobrazovaci nazov dekoru +
      # struktura povrchu. V SCHEMA 1 sa NIKDE nevyhodnocuju — len sa NESU
      # (merge-safe ako code/supplier: trim, prazdna hodnota kluc odstrani),
      # aby ich vedeli zapisat migracia (2A-2) aj buduce UI (2A-4).
      def put_schema2_fields(out, a)
        put_opt(out, 'group_id', a['group_id'] || a[:group_id])
        put_opt(out, 'decor_name', a['decor_name'] || a[:decor_name])
        put_opt(out, 'structure', a['structure'] || a[:structure])
      end

      def normalize_edge(a)
        id = (a['abs_id'] || a[:abs_id]).to_s
        return nil if id.strip.empty?
        thickness = (a['thickness'] || a[:thickness]).to_f
        return nil unless supported_edge_thickness?(thickness)
        out = {
          'abs_id'       => id,
          'decor'        => (a['decor'] || a[:decor]).to_s.strip,
          'thickness'    => thickness,
          'price_per_bm' => normalize_price(a['price_per_bm'] || a[:price_per_bm]),
          'color'        => normalize_rgb(a['color'] || a[:color], [216, 196, 160])
        }
        out.delete('price_per_bm') if out['price_per_bm'].nil?
        # D-41: 'width' kluc sa uklada LEN ked ma hodnotu — legacy zaznam bez
        # kluca = univerzalna paska (ziadne nil kluce v JSON).
        w_raw = a['width'] || a[:width]
        unless w_raw.nil? || w_raw.to_s.strip.empty?
          w = begin
            Float(w_raw.to_s.tr(',', '.'))
          rescue StandardError
            nil
          end
          out['width'] = w if w && w.finite? && w.positive?
        end
        put_opt(out, 'code', a['code'] || a[:code])       # D-42 dodavatelsky/katalogovy kod
        put_opt(out, 'supplier', a['supplier'] || a[:supplier]) # D-42 preferovany dodavatel
        put_schema2_fields(out, a)
        # 2A-1: 'universal' = VEDOMY priznak "paska pasuje na vsetku strukturu"
        # (standard 7.5 — jedina cesta pre pasky bez struktury; prazdna struktura
        # sa NIKDY nepocita ako zhoda). Uklada sa LEN ked je true; false/prazdne
        # kluc ODSTRANI (merge-safe, ziadne nil kluce v JSON).
        out['universal'] = true if flag_true?(a['universal'] || a[:universal])
        out
      end

      # Priznak z payloadu: true len pri skutocnom true / "true" / "1".
      # Vsetko ostatne (nil, false, "", "0", "nie") = vypnute.
      def flag_true?(raw)
        return true if raw == true
        %w[true 1].include?(raw.to_s.strip.downcase)
      end

      # D-42: volitelne string pole (code/supplier) — ulozi sa LEN ked ma hodnotu
      # (trim). Prazdne/nil sa NEpridava do hashu — legacy zaznam bez kluca ostava
      # cisty a "vymazane" pole (prazdny string z UI) sa realne odstrani.
      def put_opt(out, key, raw)
        v = raw.to_s.strip
        out[key] = v unless v.empty?
      end

      # D-42 (audit FIX 11): cena rozlisuje "nezadana" (nil) od "0". Nil/prazdny
      # vstup -> nil (kluc sa neulozi). Necislo -> nil (NIE ticha 0 z "abc".to_f).
      # Cislo (aj 0) -> Float. Zaporne prejde tvarom, odmietne ho validator.
      def normalize_price(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?
        Float(raw.to_s.tr(',', '.'))
      rescue StandardError
        nil
      end

      # D-19 (Codex F4): to_f by z "abc" spravilo 0.0 a odhad platni by delil
      # nulou — nekladny/neciselny prvok znamena, ze format NIE JE zadany.
      # D-44: vracia nil (nie default) — kluc sa potom vobec neulozi (audit B2).
      def normalize_pair(v)
        return nil unless v.is_a?(Array) && v.size == 2
        l = pair_num(v[0])
        w = pair_num(v[1])
        l && w ? [l, w] : nil
      end

      def pair_num(v)
        f = begin
          Float(v)
        rescue StandardError, TypeError
          nil
        end
        f && f.positive? && f.finite? ? f : nil
      end

      def supported_edge_thickness?(value)
        SUPPORTED_EDGE_THICKNESSES.include?(value.to_f)
      end

      # Povoli iba ABS, ktore realne existuje v aktivnom katalogu 1/2 mm.
      def normalized_abs_id(id)
        value = id.to_s.strip
        return nil if value.empty?
        edge(value) ? value : nil
      end

      def normalize_rgb(v, dflt)
        return dflt unless v.is_a?(Array) && v.size == 3
        v.map(&:to_i)
      end

      # --- zdielane helpery (pouzivane vo viacerych materials_*.rb suboroch) ---
      # Davka split V0.5.1: tieto nizkourovnove helpery vola CRUD/validacia AJ
      # dekorova/batch logika (v roznych suboroch) — ostavaju spolocne v jadre.

      # Sirka pasky ako Float alebo nil (legacy univerzalna).
      def edge_width(rec)
        v = rec && rec['width']
        v.nil? ? nil : v.to_f
      end

      # --- 2A-1: kanonicke identity helpery (standard 7.1 — JEDINA normalizacia) --
      # Vsetky porovnania identity (create, edit, batch, rename, migracia) idu
      # VYHRADNE cez tieto helpery — ziadne lokalne porovnavanie s vlastnou
      # toleranciou. Kluce su OPAQUE: porovnavaju sa, nikdy sa z nich necita.
      #
      # Schema-aware:
      #   SCHEMA 1 = presne dnesne porovnania (skupina = trimnuty text dekoru;
      #              doska dekor+typ+hrubka, ABS dekor+sirka+hrubka),
      #   SCHEMA 2 = skupina cez group_id (fallback vyrobca+dekor) + STRUKTURA,
      #              pri type PD navyse FORMAT ako usporiadana dvojica.

      # Normalizacia textovej casti identity: trim, viacnasobne medzery na jednu,
      # case-insensitive. POZOR: medzery sa NEODSTRANUJU — 'ST9' a 'ST 9' su dva
      # ROZNE zapisy (preklepy chyta near-match guard decor_conflict, ktory je
      # zamerne prisnejsi a medzery ignoruje uplne).
      def identity_norm(value)
        value.to_s.strip.gsub(/\s+/, ' ').upcase
      end

      # Obchodna identita dekorovej skupiny: vyrobca + cislo dekoru (standard 7.1
      # — rovnake cislo dvoch vyrobcov su DVE skupiny). Pouziva migracia 2A-2 aj
      # zaznamy bez group_id.
      def group_identity_key(manufacturer, decor)
        [identity_norm(manufacturer), identity_norm(decor)]
      end

      # Skupinova cast kluca zaznamu. Symbolove znacky drzia tvary oddelene
      # (Symbol sa nikdy nerovna Stringu), takze sa kluce roznych rezimov
      # nemozu nahodou stretnut.
      def record_group_key(rec, schema = catalog_schema)
        return [:decor, rec['decor'].to_s.strip] if schema < SCHEMA_GROUPS
        gid = rec['group_id'].to_s.strip
        return [:group_id, identity_norm(gid)] unless gid.empty?
        group_identity_key(rec['manufacturer'], rec['decor'])
      end

      # Hrubka do kluca: mm zaokruhlene na 2 desatiny (standard 7.1). Nahradza
      # doterajsie porovnanie s toleranciou 0.01 — pre kazdu realne zadatelnu
      # hodnotu je vysledok rovnaky (18 vs 18.004 ostava jeden variant).
      def thickness_key(value)
        value.to_f.round(2)
      end

      # Sirka pasky do kluca: nil (univerzalna bez sirky) alebo mm na 2 desatiny.
      # Desatinna ciarka je povolena (formular ju posiela ako text).
      def width_key(value)
        return nil if value.nil? || value.to_s.strip.empty?
        value.to_s.tr(',', '.').to_f.round(2)
      end

      # Format platne do kluca ako USPORIADANA dvojica (dlzka >= sirka), takze
      # 4100x600 a 600x4100 su ten isty format. Nezadany/poskodeny = nil.
      def size_key(value)
        pair = normalize_pair(value)
        return nil unless pair
        pair.map { |x| x.round(2) }.sort.reverse
      end

      # Typ PD (pracovna doska) — pri nom je format sucastou identity variantu.
      def pd_type?(type)
        identity_norm(type) == 'PD'
      end

      # Identita variantu DOSKY. rec = katalogovy zaznam alebo hash atributov.
      def sheet_identity_key(rec, schema = catalog_schema)
        key = [record_group_key(rec, schema), identity_norm(rec['type']), thickness_key(rec['thickness'])]
        return key if schema < SCHEMA_GROUPS
        key << identity_norm(rec['structure'])
        key << size_key(rec['sheet_size']) if pd_type?(rec['type'])
        key
      end

      # Identita variantu ABS PASKY (sirka je sucast identity; 'universal' NIE
      # JE identita — je to vlastnost vyberu, standard 7.5).
      def edge_identity_key(rec, schema = catalog_schema)
        key = [record_group_key(rec, schema), width_key(rec['width']), thickness_key(rec['thickness'])]
        return key if schema < SCHEMA_GROUPS
        key << identity_norm(rec['structure'])
        key
      end

      # --- 2A-1: register typov — dotazy (typ mimo registra = "iny") -----------

      # Zaznam registra pre napisany typ (case-insensitive, trim) alebo nil.
      def type_registry_entry(type)
        TYPE_REGISTRY[identity_norm(type)]
      end

      # Kanonicky zapis typu (kluc registra), alebo trimnuty text tak, ako ho
      # pouzivatel napisal ("iny" typ ostava volny string — NIE JE to enum).
      def canonical_type(type)
        key = identity_norm(type)
        TYPE_REGISTRY.key?(key) ? key : type.to_s.strip
      end

      # Bezne hrubky typu do naseptavaca ([] pre typ mimo registra).
      def type_thickness_suggestions(type)
        entry = type_registry_entry(type)
        entry ? entry['thickness_suggestions'] : []
      end

      # Hranove podtypy PD (postforming | ABS rovna hrana). Iny typ = [] —
      # Kompakt je VLASTNY kanonicky typ, nie podtyp PD (standard 7.1).
      def pd_edge_subtypes(type)
        entry = type_registry_entry(type)
        (entry && entry['pd_edge_subtypes']) || []
      end

      # Typ, z ktoreho realne vznika telo korpusu (DTDL/MDF).
      def body_candidate_type?(type)
        entry = type_registry_entry(type)
        entry ? !!entry['body_candidate'] : false
      end

      # Slug pre technicke ID: transliteracia diakritiky (NFD + odstranenie znamienok),
      # upcase, [A-Z0-9] bloky spojene '_'. 'Dub Halifax prírodný' -> 'DUB_HALIFAX_PRIRODNY'.
      def slug(value)
        s = value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')
        s.upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
      end

      # Token hrubky do ID: cele mm ako '18'; desatinne '18P5' (18.5 nesmie vyzerat ako 19).
      def thickness_token(th)
        f = th.to_s.tr(',', '.').to_f
        (f % 1).zero? ? f.to_i.to_s : format('%gP%d', f.floor, ((f % 1) * 10).round).sub('P0', '')
      end

      # Vygeneruje volne material_id: SLUG(decor)_SLUG(type)_TOKEN(th); kolizie
      # (case-insensitive) dostanu -2/-3... ID sa NIKDY negeneruje pri edite.
      #
      # 2A-1 (standard 7.1): ID je OPAQUE a navzdy NEMENNE — nikdy sa neparsuje
      # a existujuce ID sa nikdy neprepocitavaju. Skupina a struktura su v nom
      # LEN pre citatelnost:
      #   struktura sa vklada za dekor (K009 + PW + DTDL + 18 = K009_PW_DTDL_18),
      #   pri type PD sa v SCHEMA 2 pridava token formatu (..._4100X600), lebo
      #   format je vtedy sucastou identity variantu.
      # Prazdna struktura (= cely stav SCHEMA 1) da PRESNE dnesne ID.
      # `taken` = vlastny zoznam obsadenych ID (batch ich zbiera kumulativne,
      # aby si polozky jednej davky ID neprepisali); nil = zoznam z katalogu.
      def generate_sheet_id(decor, type, thickness, structure: nil, sheet_size: nil,
                            taken: nil, schema: catalog_schema)
        parts = [slug(decor)]
        st = slug(structure)
        parts << st unless st.empty?
        parts << slug(type)
        parts << thickness_token(thickness)
        fmt = schema >= SCHEMA_GROUPS && pd_type?(type) ? size_key(sheet_size) : nil
        parts << "#{thickness_token(fmt[0])}X#{thickness_token(fmt[1])}" if fmt
        unique_id(parts.join('_'), taken || sheets.map { |s| s['material_id'].to_s.upcase })
      end

      # D-41: paska so sirkou dostane ID s tokenom sirky PRED hrubkou
      # (ABS_U702_ST9_22X10 = sirka 22, hrubka 1,0). Bez sirky stary format
      # (ABS_U702_ST9_10). Existujuce ID sa NIKDY negeneruju znova.
      # 2A-1: struktura ide (ak je zadana) hned za dekor — rovnaky vzor ako doska.
      def generate_edge_id(decor, thickness, width = nil, structure: nil, taken: nil)
        th_token = (thickness.to_s.tr(',', '.').to_f * 10).round.to_s
        parts = ["ABS_#{slug(decor)}"]
        st = slug(structure)
        parts << st unless st.empty?
        parts << if width.nil? || width.to_s.strip.empty?
                   th_token
                 else
                   "#{thickness_token(width)}X#{th_token}"
                 end
        unique_id(parts.join('_'), taken || edges.map { |a| a['abs_id'].to_s.upcase })
      end

      # --- D-44: navrhy do naseptavacov (datalist) -----------------------------
      # Zoznam stavia SERVER a posiela ho v payloade (push_state/push_catalog) —
      # JS ho len renderuje (jedna autorita, ziadne zbieranie z DOM).

      # Trim, prazdne von, dedup CASE-INSENSITIVE (prvy vyskyt urcuje tvar —
      # do katalogu sa zapisuje AS-TYPED, navrh len ponuka existujuci zapis),
      # stabilne zoradene abecedne case-insensitive (tie-break presnym tvarom,
      # aby poradie neviselo na poradi zaznamov v subore).
      def string_suggestions(values)
        seen = {}
        values.each do |raw|
          v = raw.to_s.strip
          next if v.empty?
          k = v.downcase
          seen[k] = v unless seen.key?(k)
        end
        seen.values.sort_by { |v| [v.downcase, v] }
      end

      # Vyrobcovia pouzivani v katalogu (vyrobca je vlastnost dekoru = dosky).
      def manufacturer_suggestions
        string_suggestions(sheets.map { |s| s['manufacturer'] })
      end

      # Typy dosiek z katalogu + seed typy (katalog ide prvy, takze si drzi
      # vlastny zapis tvaru pri kolizii velkosti pismen).
      def type_suggestions
        string_suggestions(sheets.map { |s| s['type'] } + SEED_TYPES)
      end

      # Hranice formatu platne do hlasky — z JEDNEJ konstanty (formular aj batch).
      def sheet_size_range_label
        "#{fmt_mm(SHEET_SIZE_RANGE.first)}–#{fmt_mm(SHEET_SIZE_RANGE.last)}"
      end

      def unique_id(base, taken_upcased)
        return base unless taken_upcased.include?(base.upcase)
        n = 2
        n += 1 while taken_upcased.include?("#{base.upcase}-#{n}")
        "#{base}-#{n}"
      end
    end
  end
end
