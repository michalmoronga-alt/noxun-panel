# frozen_string_literal: true
# Noxun Engine — V0.6 D1: sety kovania (mapovanie genericky typ -> zoznam Demos kodov).
#
# ============================ ARCHITEKTURA ============================
# Faza 2 kovania (standard 6.2): pravidla (hardware_rules) daju GENERIKU
# (hinge x6 s ownerom, slide s params.nominal_length...), set ju prelozi na
# KODY katalogu (hardware_catalog) s pomermi. Set NIE JE polozka katalogu —
# je to mapovacie pravidlo (zamknute rozhodnutie, debata 2.8.2026,
# SYSTEM/09_POJMY.md "Kovanie — sety").
#
# TVAR SETU:
#   { "set_id": "zaves-klasik",            # slug identita, NEMENNA
#     "name": "Záves KLASIK (Sensys 110°)",
#     "generic_type": "hinge",             # BuildPlan::GENERIC_TYPES
#     "members": [
#       { "code": "104717", "per": "unit",  "qty": 1, "label": "záves" },
#       { "code": "250831", "per": "owner", "qty": 1, "label": "TipOn" },
#       { "per": "unit", "qty": 1, "code_by_nl": { "420": "357695" } } ] }
#
# Clen setu (audit F10 — prisnejsie nez BuildPlan params kontrakt):
#   per  'unit'  -> celkovy pocet = quantity polozky * qty (zaves: 4 kody 1:1:1:1)
#   per  'owner' -> qty NA VLASTNIKA polozky bez ohladu na quantity (TipOn 1x
#                   na dvierka aj pri 2-5 zavesoch); dedup (cabinet, owner,
#                   set, code) — dve pravidla na jednom vlastnikovi nesmu
#                   zdvojit clena (audit B3)
#   code XOR code_by_nl XOR param_bands — PRAVE JEDEN z trojice.
#   code_by_nl = rad podla params['nominal_length'] (vysuvy; fit_series NL uz
#   pocita). Kluc mapy = cele mm ako string ("420"); NL mimo mapy = nemapovane
#   (ORANGE), NIKDY sa neberie susedny kod (audit F10).
#   param_bands (H1a, audit FIX 8) = kod podla ciselneho parametra polozky:
#     { "param": "height",
#       "bands": [ { "min": 17.0, "max": 21.0, "code": "82744" }, ... ] }
#   Priklad: „Nohy podla vysky sokla" — klzak 17-21 mm, AXILO pri 140-160 mm.
#
# ======================= PASMA (jedna konvencia) ======================
# Pasma param_bands aj selector bands (nizsie) maju TU ISTU semantiku:
#   * min/max su konecne Floaty, min <= max
#   * hranice su UZAVRETE:  min <= v <= max
#   * preto DOTYK dvoch pasiem (predchadzajuci max == nasledujuci min) je
#     PREKRYV = chyba zapisu; medzery su legalne
#   * hodnota mimo vsetkych pasiem = NEMAPOVANE (ORANGE), NIKDY najblizsie
#     pasmo (rovnaka filozofia ako "presny NL kluc, nikdy sused")
#
# ================== MAPOVANIE: JEDEN PARSER FORIEM ====================
# (H1a, audit BLOCKER 2) Kluc mapovania:
#   "generic_type"                     — bezny vyber setu
#   "generic_type@owner_part_key"      — override na UROVNI VLASTNIKA;
#     povoleny LEN v cabinet override mape (config['hardware_sets']).
#     Projektovy/globalny mapping composite kluce NEMA — owner_part_key nie je
#     jednoznacny naprieg skrinkami (front:F1/panel existuje v kazdej).
# Hodnota mapovania:
#   "set_id"  (String)                 — pevny set
#   selector  (Hash)                   — set podla ciselneho parametra polozky:
#     { "param": "front_height",
#       "bands": [ { "min": 0.0, "max": 120.0, "set_id": "atira-h70" }, ... ] }
# Parser (parse_mapping / parse_mapping_value) je JEDINA autorita tvaru a
# pouzivaju ho vsetky cesty: globalny zapis, snapshot, cabinet override
# (CabinetBuilder.norm_hardware_sets), expanzia aj forward-compat guard.
# ZAPISOVA cesta neplatny tvar ODMIETNE (chyba); CITACIA (legacy/cudzi config)
# nevalidnu polozku preskoci s logom — citanie nesmie zhodit prestavbu.
#
# ====================== ZDROJE A REPRODUKOVATELNOST ===================
# 1) GLOBALNA kniznica %APPDATA%\NOXUN\Engine\hardware_sets.json (+.bak, seed) =
#    default pre NOVE projekty: { std, seed_version, sets: [], mapping: {} }.
# 2) PROJEKTOVY SNAPSHOT: NOXUN dict na MODELI, kluc 'hardware_sets' —
#    { std, mapping: {generic_type => set_id}, sets: {set_id => definicia} }.
#    Snapshot drzi mapping ∪ VSETKY overridnute sety (audit B2 — zapis
#    cabinet override vklada definiciu setu do snapshotu v TEJ ISTEJ
#    operacii). Zmena globalnych setov NIKDY ticho nemeni stary projekt.
#    Stavy citania (audit F9): chybajuci snapshot = :missing (legitimne len
#    novy projekt -> ensure zapise global default), poskodeny = :invalid
#    (ORANGE, bez mapovania — NIKDY tichy fallback na dnesny global).
# 3) Cabinet override: config kluc 'hardware_sets' = {generic_type => set_id}
#    (round-trip cez normalize/cabinet_config — audit B1).
#
# Expand je CISTA funkcia (ziadne IO/SketchUp) — headless testovatelna;
# vstup = raw hardware z Bom.collect (s owner_id), NIE agregovany BOM
# (audit F6 — per-owner clen potrebuje vlastnika).
require 'json'
require 'csv'
require 'digest'

module Noxun
  module Engine
    module HardwareSets
      STD          = 1
      # v2 (H1a): +set „Nohy podla vysky sokla" (param_bands) a migracia
      # globalneho defaultu leg z 'nohy-klzak-17' na neho. STD sa NEBUMPA —
      # tvar suboru/snapshotu ostava rovnaky, pribudli len nove tvary clena a
      # hodnoty mapovania (starsi plugin ich precita ako :invalid = ORANGE,
      # NIKDY ticho nemapuje inak).
      SEED_VERSION = 2
      FILE         = 'hardware_sets.json'
      MODEL_KEY    = 'hardware_sets' # kluc snapshotu v NOXUN dict na modeli

      PER_KINDS = %w[unit owner].freeze

      # Dovody nemapovanej polozky (ORANGE) — jediny kanonicky zoznam; texty
      # semaforu mapuje Validation.check_hardware_expansion.
      UNMAPPED_REASONS = %w[no_set set_missing nl_missing
                            param_band_missing selector_unresolved].freeze

      # Seed sety = zavery debaty 2.8.2026 (09_POJMY "Kovanie — sety");
      # kody = SYSTEM/zdroje/SEED_KATALOG_2026-07.md §2. Atira rad nesie LEN
      # dolozene kody (420/470) — ostatne NL = ORANGE, kody doplni Michal/D2.
      SEED_SETS = [
        { 'set_id' => 'zaves-klasik', 'name' => 'Záves KLASIK (Sensys 110° SiSy)',
          'generic_type' => 'hinge',
          'members' => [
            { 'code' => '104717', 'per' => 'unit', 'qty' => 1, 'label' => 'záves' },
            { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
            { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
            { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' }
          ] },
        { 'set_id' => 'zaves-p2o', 'name' => 'Záves P2O + TipOn (bez tlmenia)',
          'generic_type' => 'hinge',
          'members' => [
            { 'code' => '245723', 'per' => 'unit', 'qty' => 1, 'label' => 'záves P2O' },
            { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
            { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
            { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' },
            { 'code' => '250831', 'per' => 'owner', 'qty' => 1, 'label' => 'TipOn na dvierka' }
          ] },
        # H1a (smoke test D-79): noha sa vybera podla VYSKY SOKLA — polozka
        # 'leg' nesie params['height'] = floor_height (pravidlo nohy-zakladne).
        # Skrinka so soklom 150 uz nedostane klzak 17. Vyska mimo pasiem =
        # ORANGE „doplnit pasmo", NIKDY najblizsie pasmo.
        { 'set_id' => 'nohy-podla-sokla', 'name' => 'Nohy podľa výšky sokla',
          'generic_type' => 'leg',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'noha',
              'param_bands' => { 'param' => 'height',
                                 'bands' => [
                                   { 'min' => 17.0, 'max' => 21.0, 'code' => '82744' },
                                   { 'min' => 140.0, 'max' => 160.0, 'code' => '367823' }
                                 ] } }
          ] },
        # Jednokodove sety nôh OSTAVAJU — pouzivatelia ich mozu mat namapovane
        # (a migracia defaultu nizsie ich vedome respektuje).
        { 'set_id' => 'nohy-klzak-17', 'name' => 'Klzák s rektifikáciou 17 mm',
          'generic_type' => 'leg',
          'members' => [{ 'code' => '82744', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'nohy-axilo-150', 'name' => 'Noha AXILO 150 mm',
          'generic_type' => 'leg',
          'members' => [{ 'code' => '367823', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'vysuv-atira-biela-h70', 'name' => 'Atira biela H70 (rad podľa NL)',
          'generic_type' => 'slide',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '420' => '357695', '470' => '357696' } }
          ] },
        { 'set_id' => 'zavesenie-bystrica', 'name' => 'Zavesenie na stenu „Bystrica"',
          'generic_type' => 'wall_hanger',
          'members' => [{ 'code' => '93240', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'podperky-police', 'name' => 'Podperka policová 7/5',
          'generic_type' => 'shelf_pin',
          'members' => [{ 'code' => '306125', 'per' => 'unit', 'qty' => 1 }] }
      ].freeze

      # Default mapovanie novych projektov: handle/connector vedome BEZ setu
      # (uchytky sa v D neriesia — Michal 2.8.; connector pravidlo neexistuje).
      SEED_MAPPING = {
        'hinge'       => 'zaves-klasik',
        'leg'         => 'nohy-podla-sokla', # H1a: default riadi vyska sokla
        'slide'       => 'vysuv-atira-biela-h70',
        'wall_hanger' => 'zavesenie-bystrica',
        'shelf_pin'   => 'podperky-police'
      }.freeze

      # --- migracia globalneho defaultu nôh (H1a, audit BLOCKER 3) ------------
      # Povodne (v1) seed tvary setov, ktorych migracia sa TYKA. Vzor
      # HardwareRules::LEGACY_SEED_SHAPES: dotkne sa LEN preukazatelne
      # NEZMENENEHO seed riadku; akykolvek pouzivatelsky zasah = ruky prec.
      LEGACY_SEED_SHAPES = {
        'nohy-klzak-17' => [
          { 'set_id' => 'nohy-klzak-17', 'name' => 'Klzák s rektifikáciou 17 mm',
            'generic_type' => 'leg',
            'members' => [{ 'code' => '82744', 'per' => 'unit', 'qty' => 1 }] }
        ]
      }.freeze

      # Migracie mapovania GLOBALNEJ kniznice: { generic_type => [from_set_id,
      # to_set_id] }. Prepis nastane LEN ked (a) mapovanie je dnes presne
      # from_set_id A (b) set from_set_id je v kniznici nezmeneny seed tvar.
      # Jednorazovost strazi seed_version (merge_seed bezi len pri starsom
      # subore) — ked si user leg neskor prehodi spat, uz sa nic neprepise.
      # PROJEKTOVE SNAPSHOTY sa NEMENIA NIKDY samy.
      MAPPING_MIGRATIONS = {
        'leg' => %w[nohy-klzak-17 nohy-podla-sokla]
      }.freeze

      module_function

      # --- globalna kniznica (%APPDATA%) --------------------------------------

      def dir
        Materials.dir # zdielany %APPDATA%/NOXUN/Engine (+ test_dir_override)
      end

      def path
        File.join(dir, FILE)
      end

      # Nacita globalnu kniznicu { 'sets' => [], 'mapping' => {} }. Poskodeny/
      # chybajuci subor -> seed (fallback nikdy nevrati nil). Seed-merge ako
      # HardwareRules: novsi SEED_VERSION doplni CHYBAJUCE set_id (bez prepisu
      # pouzivatelskych uprav) — plati LEN pre global; projektovy snapshot sa
      # NIKDY nemeni sam.
      def load
        ensure_seeded
        doc = JsonFileStore.read(path, copy: false)
        sets = doc.is_a?(Hash) ? normalize_sets(doc['sets']) : []
        mapping = doc.is_a?(Hash) ? normalize_mapping(doc['mapping'], sets) : {}
        return { 'sets' => deep_copy(SEED_SETS), 'mapping' => SEED_MAPPING.dup } if sets.empty?
        merged, merged_map, changed = merge_seed(sets, mapping, doc['seed_version'].to_i)
        if changed && write(merged, merged_map)
          Engine.log('hardware sets: globalna kniznica doplnena o nove default sety') if defined?(Engine)
        end
        { 'sets' => merged, 'mapping' => merged_map }
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.load') if defined?(Engine)
        { 'sets' => deep_copy(SEED_SETS), 'mapping' => SEED_MAPPING.dup }
      end

      # Seed-merge globalnej kniznice: doplni CHYBAJUCE seed sety (podla
      # set_id, bez prepisu pouzivatelskych uprav) a spusti MAPPING_MIGRATIONS
      # (H1a BLOCKER 3). Vrati [sets, mapping, changed].
      def merge_seed(sets, mapping, from_version)
        map = mapping.is_a?(Hash) ? mapping.dup : {}
        return [sets, map, false] if from_version >= SEED_VERSION
        have = {}
        sets.each { |s| have[s['set_id']] = true }
        missing = SEED_SETS.reject { |s| have[s['set_id']] }
        merged = sets + normalize_sets(missing)
        [merged, migrate_mapping(merged, map), true]
      end

      # Prepis defaultu LEN pri nedotknutom seed stave (vzor F8/LEGACY_SEED_SHAPES):
      # mapovanie musi byt presne stara hodnota A stary set musi byt v kniznici
      # v nezmenenom seed tvare. Cielovy set musi po merge existovat.
      def migrate_mapping(sets, mapping)
        by_id = {}
        sets.each { |s| by_id[s['set_id']] = s }
        out = mapping.dup
        MAPPING_MIGRATIONS.each do |gt, (from_id, to_id)|
          next unless out[gt] == from_id
          next unless by_id[to_id]
          old = by_id[from_id]
          next unless old && legacy_seed_shape?(old)
          out[gt] = to_id
          Engine.log("hardware sets: default '#{gt}' migrovany #{from_id} -> #{to_id}") if defined?(Engine)
        end
        out
      end

      # Set je NEZMENENY stary seed tvar? (porovnanie normalizovanych tvarov)
      def legacy_seed_shape?(set)
        shapes = LEGACY_SEED_SHAPES[set.is_a?(Hash) ? set['set_id'].to_s : '']
        return false unless shapes
        norm = normalize_sets([set]).first
        return false if norm.nil?
        shapes.any? { |s| normalize_sets([s]).first == norm }
      end

      def ensure_seeded
        return if JsonFileStore.available?(path)
        write(deep_copy(SEED_SETS), SEED_MAPPING.dup)
      end

      # ZAPISOVA cesta (H1a): tvar setov aj mapovania sa validuje PRISNE —
      # chybny clen/forma = odmietnutie CELEHO zapisu (all-or-nothing), nikdy
      # tichy drop. Referencna cistota ostava tolerantna: mapovanie na set,
      # ktory v kniznici uz nie je (delete_set!), sa vyhodi ticho — typ zostane
      # nemapovany a ORANGE to ukaze.
      def write(sets, mapping)
        norm, set_errors = validate_sets(sets)
        unless set_errors.empty?
          Engine.log("hardware sets: zapis kniznice odmietnuty — #{set_errors.first}") if defined?(Engine)
          return false
        end
        map, map_errors = parse_mapping(mapping, set_ids: norm.map { |s| s['set_id'] })
        unless map_errors.empty?
          Engine.log("hardware sets: zapis mapovania odmietnuty — #{map_errors.first}") if defined?(Engine)
          return false
        end
        JsonFileStore.write(path, { 'std' => STD, 'seed_version' => SEED_VERSION,
                                    'sets' => norm, 'mapping' => map })
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.write') if defined?(Engine)
        false
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # Baseline guard okna (vzor catalog_revision): odtlacok suboru kniznice.
      def revision
        ensure_seeded
        raw = begin
          File.binread(path)
        rescue StandardError
          ''
        end
        Digest::SHA1.hexdigest(raw)[0, 12]
      end

      # Ulozi/nahradi JEDEN set v globalnej kniznici (D1b editor). Identita =
      # set_id; revision = baseline z casu nacitania okna (cudzia zmena
      # medzitym = :conflict, okno sa obnovi). generic_type existujuceho setu
      # sa NEMENI (mapovania by ticho zmenili vyznam). create: true = NOVY set
      # nesmie trafit existujucu identitu (GH #127 P2 — slug z nazvu moze
      # kolidovat a "Novy set" by ticho prepisal globalnu definiciu).
      def save_set!(set_def, revision: nil, create: false)
        norm, errors = validate_set(set_def)
        if norm.nil?
          return [:invalid, errors.first || 'set sa nedá uložiť — skontroluj kódy a členov']
        end
        return [:conflict, nil] if revision && revision != self.revision
        lib = load
        sets = lib['sets']
        idx = sets.index { |s| s['set_id'] == norm['set_id'] }
        return [:exists, norm['set_id']] if create && idx
        if idx
          if sets[idx]['generic_type'] != norm['generic_type']
            return [:invalid, 'typ kovania existujúceho setu sa nemení — vytvor nový set']
          end
          sets[idx] = norm
        else
          sets << norm
        end
        return [:write_failed, nil] unless write(sets, lib['mapping'])
        [:ok, norm]
      end

      # Zmaze set z globalnej kniznice; mapovanie globalu sa ocisti (write ho
      # filtruje cez ids). Projektove snapshoty drzia vlastne kopie — historia
      # zakaziek sa mazanim kniznice NEMENI (rovnaka filozofia ako katalog).
      def delete_set!(set_id, revision: nil)
        sid = set_id.to_s.strip
        return [:not_found, nil] if sid.empty?
        return [:conflict, nil] if revision && revision != self.revision
        lib = load
        sets = lib['sets'].reject { |s| s['set_id'] == sid }
        return [:not_found, nil] if sets.length == lib['sets'].length
        return [:write_failed, nil] unless write(sets, lib['mapping'])
        [:ok, sid]
      end

      # Nastavi mapovanie GLOBALNEJ kniznice (default novych projektov).
      # value = set_id String | selector Hash | nil/'' (odmapovanie).
      def set_global_mapping!(generic_type, value)
        gt = generic_type.to_s.strip
        return false unless BuildPlan::GENERIC_TYPES.include?(gt)
        lib = load
        mapping = lib['mapping']
        if value.nil? || (value.is_a?(String) && value.strip.empty?)
          mapping.delete(gt)
        else
          status, norm, refs = parse_mapping_value(value)
          return false unless status == :ok
          return false unless refs.all? do |sid|
            lib['sets'].any? { |s| s['set_id'] == sid && s['generic_type'] == gt }
          end
          mapping[gt] = norm
        end
        write(lib['sets'], mapping)
      end

      # --- nakupny CSV (D1b, audit N11) ----------------------------------------

      CSV_CRLF = "\r\n"

      # CSV nakupneho zoznamu z expand vysledku — CISTA funkcia (testy).
      # Format ako VEPO (';' + force_quotes + CRLF, UTF-8); cena nil =
      # "nezadana" (prazdna bunka, NIKDY 0). Nemapovane polozky = vlastna
      # sekcia na konci (viditelnost — zoznam NIE JE kompletny).
      def purchase_csv(exp, project: '', generated_at: '')
        rows = exp.is_a?(Hash) ? Array(exp['rows']) : []
        unmapped = exp.is_a?(Hash) ? Array(exp['unmapped']) : []
        summary = exp.is_a?(Hash) && exp['summary'].is_a?(Hash) ? exp['summary'] : {}
        CSV.generate(col_sep: ';', force_quotes: true, row_sep: CSV_CRLF) do |out|
          out << ['NOXUN kovanie — nákupný zoznam', project.to_s, generated_at.to_s]
          out << ['kategória', 'kód', 'názov', 'počet', 'MJ', 'cena € s DPH', 'medzisúčet € s DPH']
          rows.each do |r|
            out << [
              r['missing'] ? 'MIMO KATALÓGU' : r['category'].to_s,
              r['code'].to_s,
              r['name_sk'].to_s,
              r['quantity'].to_i,
              r['unit'].to_s,
              price_cell(r['price_eur_vat']),
              price_cell(r['subtotal_eur_vat'])
            ]
          end
          out << ['SPOLU (len známe ceny)', '', '', summary['quantity'].to_i, '',
                  '', price_cell(summary['total_eur_vat'])]
          unless unmapped.empty?
            out << []
            out << ['NEMAPOVANÉ (bez kódov — nenacenené)', '', '', '', '', '', '']
            unmapped.each do |u|
              out << [u['generic_type'].to_s, '', "#{u['cabinet_id']} #{u['owner_part_key']}".strip,
                      u['quantity'].to_i, '', '', '']
            end
          end
        end
      end

      # SK desatinna ciarka (Excel); nil = prazdna bunka (nezadana != 0).
      def price_cell(v)
        return '' unless v.is_a?(Numeric)
        format('%.2f', v.to_f).tr('.', ',')
      end

      # --- projektovy snapshot (NOXUN dict na modeli) --------------------------

      # Stav snapshotu (audit F9): [:ok, state] | [:missing, nil] | [:invalid, nil].
      # :invalid NIKDY nesmie viest na globalnu kniznicu — volajuci mapuje na
      # ORANGE "sety projektu su poskodene" a expanzia bezi bez mapovania.
      def project_state_status(model)
        return [:missing, nil] unless model
        raw = model.get_attribute(Store::DICT, MODEL_KEY)
        return [:missing, nil] if raw.nil? || raw.to_s.strip.empty?
        doc = JSON.parse(raw.to_s)
        return [:invalid, nil] unless doc.is_a?(Hash)
        # GH #126 P2: snapshot sa cita BEZSTRATOVO alebo vobec. Normalizacia,
        # ktora by nieco zahodila (cudzi std, poskodeny set, mapping na
        # chybajuci set ci neznamy generic_type novsej verzie), NESMIE vratit
        # :ok — nasledny zapis (set_project_mapping!) by stratu zvecnil.
        return [:invalid, nil] if doc.key?('std') && doc['std'].to_i != STD
        sets_map = doc['sets'].is_a?(Hash) ? doc['sets'] : nil
        mapping  = doc['mapping'].is_a?(Hash) ? doc['mapping'] : nil
        return [:invalid, nil] if sets_map.nil? || mapping.nil?
        sets = normalize_sets(sets_map.values)
        return [:invalid, nil] if sets.length != sets_map.length
        by_id = {}
        sets.each { |s| by_id[s['set_id']] = s }
        norm_map = normalize_mapping(mapping, sets)
        return [:invalid, nil] if norm_map.length != mapping.length
        [:ok, { 'mapping' => norm_map, 'sets' => by_id }]
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.project_state_status') if defined?(Engine)
        [:invalid, nil]
      end

      # Snapshot projektu alebo nil (missing AJ invalid — na rozlisenie sluzi
      # project_state_status; citacie cesty bez modelu nemaju co mapovat).
      def project_state(model)
        status, state = project_state_status(model)
        status == :ok ? state : nil
      end

      # Globalne predvolby ako projektovy stav (mapping + kopie namapovanych
      # setov) — default noveho snapshotu (ensure, prva zmena, vedoma obnova).
      def global_default_state
        lib = load
        by_id = {}
        lib['sets'].each { |s| by_id[s['set_id']] = s }
        mapping = {}
        sets = {}
        lib['mapping'].each do |gt, value|
          # H1a: hodnota moze byt selector — zmrazit treba VSETKY sety, na
          # ktore ukazuje (audit BLOCKER 1); ak niektory chyba, typ sa
          # nezmrazi vobec (ciastocny selector by mlcky menil vyber).
          refs = value_set_ids(value)
          next if refs.empty? || refs.any? { |sid| by_id[sid].nil? }
          mapping[gt] = deep_copy(value)
          refs.each { |sid| sets[sid] = by_id[sid] }
        end
        { 'mapping' => mapping, 'sets' => sets }
      end

      # Vrati snapshot; ak chyba, zapise global default (mapping + namapovane
      # sety). VOLAT LEN vnutri otvorenej operacie (vzor ensure_project_rules!).
      # :invalid sa NEOPRAVUJE ticho — vrati nil, UI ponukne vedomu obnovu.
      def ensure_project_state!(model)
        status, state = project_state_status(model)
        return state if status == :ok
        return nil if status == :invalid
        state = global_default_state
        write_project_state(model, state) if model
        state
      end

      # Zapise snapshot (volajuci drzi operaciu — undo vrati model aj sety).
      # H1a: ZAPISOVA cesta — tvar setov aj mapovania sa validuje prisne a
      # kazdy referencovany set MUSI byt v snapshote (audit BLOCKER 1). Bez
      # toho by sa zapisal stav, ktory sa vzapati precita ako :invalid.
      def write_project_state(model, state)
        return false unless model
        raw_sets = state.is_a?(Hash) && state['sets'].is_a?(Hash) ? state['sets'] : {}
        norm_sets, set_errors = validate_sets(raw_sets.values)
        unless set_errors.empty?
          Engine.log("hardware sets: snapshot odmietnuty — #{set_errors.first}") if defined?(Engine)
          return false
        end
        by_id = {}
        norm_sets.each { |s| by_id[s['set_id']] = s }
        mapping, map_errors = parse_mapping(state.is_a?(Hash) ? state['mapping'] : nil)
        unless map_errors.empty?
          Engine.log("hardware sets: snapshot odmietnuty — #{map_errors.first}") if defined?(Engine)
          return false
        end
        missing = referenced_set_ids(mapping).reject { |sid| by_id.key?(sid) }
        unless missing.empty?
          Engine.log("hardware sets: snapshot odmietnuty — chyba definicia setu #{missing.first}") if defined?(Engine)
          return false
        end
        doc = { 'std' => STD, 'mapping' => mapping, 'sets' => by_id }
        model.set_attribute(Store::DICT, MODEL_KEY, doc.to_json)
        true
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.write_project_state') if defined?(Engine)
        false
      end

      # Zmeni projektove mapovanie JEDNEHO generickeho typu. set_def = plna
      # definicia (z globalu/editora) — vlozi sa do snapshotu v tom istom
      # zapise (audit B2: snapshot drzi kazdy referencovany set). set_id nil =
      # typ sa odmapuje (definicia v snapshote ostava pre historiu overridov).
      # Volajuci drzi operaciu.
      # value = set_id String | selector Hash | nil (odmapovanie).
      # set_defs = definicie VSETKYCH setov, na ktore hodnota ukazuje (jedna
      # definicia, pole alebo mapa set_id=>definicia). H1a BLOCKER 1: zapis
      # mapovania a zmrazenie definicii je JEDEN zapis v JEDNEJ operacii —
      # inak by projekt ukazoval na set, ktory v .skp nie je.
      def set_project_mapping!(model, generic_type, value, set_defs = nil)
        status, state = project_state_status(model)
        return false unless status == :ok || status == :missing
        # GH #127 P1: prva zmena v projekte BEZ snapshotu najprv zmrazi VSETKY
        # globalne predvolby (UI ich prave ukazovalo ako platne) a az nad nimi
        # meni jeden typ — start z prazdna by ostatne typy ticho odmapoval.
        state ||= global_default_state
        gt = generic_type.to_s
        return false unless BuildPlan::GENERIC_TYPES.include?(gt)
        if value.nil? || (value.is_a?(String) && value.strip.empty?)
          state['mapping'].delete(gt)
          return write_project_state(model, state)
        end
        vstatus, norm_value, refs = parse_mapping_value(value)
        return false unless vstatus == :ok
        defs = collect_set_defs(set_defs)
        return false unless refs.all? do |sid|
          d = defs[sid]
          d && d['generic_type'] == gt
        end
        state['mapping'][gt] = norm_value
        refs.each { |sid| state['sets'][sid] = defs[sid] }
        write_project_state(model, state)
      end

      # Vlozi/aktualizuje definicie setov v snapshote BEZ zmeny mapovania
      # (cabinet override na nenamapovany set — audit B2). Volajuci drzi operaciu.
      def add_project_sets!(model, set_defs)
        status, state = project_state_status(model)
        return false unless status == :ok || status == :missing
        state ||= global_default_state # GH #127 P1 — prvy zapis mrazi vsetko
        defs = collect_set_defs(set_defs)
        return false if defs.empty?
        defs.each { |sid, d| state['sets'][sid] = d }
        write_project_state(model, state)
      end

      def add_project_set!(model, set_def)
        add_project_sets!(model, set_def)
      end

      # Definicie setov -> mapa set_id => normalizovana definicia. Prijme jednu
      # definiciu, pole aj mapu; nevalidna definicia sa vyhodi (volajuci potom
      # neprejde referencnou kontrolou vyssie).
      def collect_set_defs(set_defs)
        list =
          case set_defs
          when nil then []
          when Array then set_defs
          when Hash then set_defs.key?('members') || set_defs.key?(:members) ? [set_defs] : set_defs.values
          else [set_defs]
          end
        out = {}
        normalize_sets(list).each { |d| out[d['set_id']] = d }
        out
      end

      # --- precedencia definicii (H1a, audit BLOCKER 4) ------------------------

      # Definicia setu pre zobrazenie/zapis. Pre set_id, ktore je AKTUALNE
      # namapovane alebo overridnute, vyhrava definicia zo SNAPSHOTU projektu
      # (to je to, podla coho sa zakazka naozaj nakupuje); global je len
      # fallback pre sety, na ktore projekt neukazuje. cabinet_overrides =
      # { cabinet_id => override mapa } (Bom.collect); bez nich sa referencie
      # rataju len z projektoveho mapovania.
      def resolve_set_def(model, set_id, cabinet_overrides: {})
        sid = set_id.to_s.strip
        return nil if sid.empty?
        state = project_state(model)
        if state
          refs = referenced_set_ids(state['mapping'], cabinet_overrides)
          snap = state['sets'][sid]
          return snap if snap && refs.include?(sid)
        end
        global = load['sets'].find { |s| s['set_id'] == sid }
        return global if global
        state ? state['sets'][sid] : nil
      end

      # Ponuka setov jedneho generickeho typu pre UI select. Rovnaka
      # precedencia ako resolve_set_def: referencovane set_id sa beru zo
      # snapshotu, zvysok z globalu. Poradie deterministicke (nazov, set_id).
      def set_options(generic_type, globals, snapshot_sets, referenced_ids)
        gt = generic_type.to_s
        refs = Array(referenced_ids).map(&:to_s)
        snap = snapshot_sets.is_a?(Hash) ? snapshot_sets : {}
        by_id = {}
        Array(globals).each do |s|
          next unless s.is_a?(Hash) && s['generic_type'] == gt
          by_id[s['set_id']] = s
        end
        snap.each do |sid, s|
          next unless s.is_a?(Hash) && s['generic_type'] == gt
          by_id[sid] = s if refs.include?(sid.to_s) || !by_id.key?(sid)
        end
        by_id.values.sort_by { |s| [s['name'].to_s, s['set_id'].to_s] }
      end

      # --- cabinet override (H1a, audit FIX 7) --------------------------------

      # Zapisova cesta overridu setu NA SKRINKE (aj na urovni vlastnika).
      # cfg = ULOZENY config korpusu (string kluce; potrebuje 'hardware' a
      # 'hardware_sets'). owner_part_key nil = override celej skrinky.
      # value = set_id String | selector Hash | nil (zrusenie).
      # Identita = (owner_part_key, generic_type) — override prebija VSETKY
      # polozky daneho typu na vlastnikovi bez ohladu na rule_id.
      # known_sets = definicie, proti ktorym sa overi, ze VSETKY referencovane
      # sety existuju a su spravneho typu (volajuci ich vytiahne cez
      # resolve_set_def — snapshot pred globalom). Bez nich sa kontroluje LEN
      # tvar; volajuci potom typ musi overit sam.
      # -> [:ok, new_map, referenced_set_ids] | [:invalid, message, nil]
      def apply_cabinet_override(cfg, generic_type, owner_part_key, value, known_sets: nil)
        gt = generic_type.to_s.strip
        unless BuildPlan::GENERIC_TYPES.include?(gt)
          return [:invalid, 'neznámy typ kovania', nil]
        end
        hardware = cfg.is_a?(Hash) ? Array(cfg['hardware']) : []
        owner = owner_part_key.nil? ? nil : owner_part_key.to_s.strip
        owner = nil if owner == ''
        if owner
          return [:invalid, 'neplatný dielec', nil] unless PartKeys.valid?(owner)
          match = hardware.any? do |h|
            h.is_a?(Hash) && h['generic_type'].to_s == gt &&
              h['owner_part_key'].to_s == owner
          end
          unless match
            return [:invalid, 'tento dielec nemá v skrinke také kovanie', nil]
          end
        end
        base = cfg.is_a?(Hash) && cfg['hardware_sets'].is_a?(Hash) ? cfg['hardware_sets'] : {}
        map = normalize_mapping(base, nil, allow_owner: true)
        key = owner ? "#{gt}@#{owner}" : gt
        if value.nil? || (value.is_a?(String) && value.strip.empty?)
          map.delete(key)
          return [:ok, map, []]
        end
        status, norm, refs = parse_mapping_value(value)
        return [:invalid, norm, nil] unless status == :ok
        unless known_sets.nil?
          defs = collect_set_defs(known_sets)
          bad = refs.find { |sid| defs[sid].nil? || defs[sid]['generic_type'] != gt }
          return [:invalid, "set „#{bad}“ sa nenašiel alebo je iného typu", nil] if bad
        end
        map[key] = norm
        [:ok, map, refs]
      end

      # --- vedomy merge globalnych predvolieb do projektu (H1a, audit FIX 10) --

      # Vzor HardwareRules.merge_project_seed!: doplni do snapshotu CHYBAJUCE
      # globalne mapovania (+ definicie setov, na ktore ukazuju). EXISTUJUCE
      # mapovania sa NEPREPISUJU a ziadna snapshot definicia sa NEODSTRANUJE
      # (mohol by na nu ukazovat cabinet override). Volat VNUTRI operacie.
      # -> [:none|:updated, added_set_ids, added_mapping_keys]
      def merge_project_sets_seed!(model)
        status, state = project_state_status(model)
        return [:none, [], []] unless status == :ok # bez snapshotu berie projekt global sam
        lib = load
        by_id = {}
        lib['sets'].each { |s| by_id[s['set_id']] = s }
        added_sets = []
        added_map = []
        lib['mapping'].each do |gt, value|
          next if state['mapping'].key?(gt)
          refs = value_set_ids(value)
          next if refs.empty? || refs.any? { |sid| by_id[sid].nil? }
          state['mapping'][gt] = deep_copy(value)
          added_map << gt
          refs.each do |sid|
            next if state['sets'].key?(sid)
            state['sets'][sid] = by_id[sid]
            added_sets << sid
          end
        end
        return [:none, [], []] if added_map.empty?
        return [:none, [], []] unless write_project_state(model, state)
        [:updated, added_sets.uniq, added_map]
      end

      # --- expanzia (cista funkcia, audit F6) ----------------------------------

      # hardware_items: RAW polozky z Bom.collect — string kluce + 'owner_id'
      #   (cabinet id); owner_part_key/generic_type/quantity/rule_id/params.
      # state: projektovy snapshot {'mapping','sets'} alebo nil (= nic nemapuje).
      # cabinet_overrides: { cabinet_id => override mapa } z configov korpusov —
      #   kluc 'generic_type' alebo 'generic_type@owner_part_key', hodnota
      #   set_id alebo selector (H1a).
      # catalog: pole poloziek HardwareCatalog.items alebo mapa code=>item.
      # Vrati { 'rows' => [...], 'unmapped' => [...], 'summary' => {...} } —
      # deterministicke poradie (kategoria podla HardwareCatalog::CATEGORIES,
      # potom kod); ceny s DPH; nil cena = nezadana, subtotal nil, NIKDY 0.
      def expand(hardware_items, state, cabinet_overrides: {}, catalog: nil)
        mapping = state.is_a?(Hash) && state['mapping'].is_a?(Hash) ? state['mapping'] : {}
        sets    = state.is_a?(Hash) && state['sets'].is_a?(Hash) ? state['sets'] : {}
        # Cabinet override mapy prechadzaju TYM ISTYM parserom (citacia cesta —
        # neplatna polozka vypadne s logom, expanzia nikdy nespadne).
        overrides = normalize_cabinet_overrides(cabinet_overrides)
        lookup  = catalog_lookup(catalog)
        rows = {}
        unmapped = []
        owner_seen = {}
        Array(hardware_items).each do |it|
          next unless it.is_a?(Hash)
          gt  = it['generic_type'].to_s
          qty = it['quantity'].to_i
          next if gt.empty? || qty < 1
          sid, reason, info = resolve_set_id(gt, it, overrides, mapping)
          if sid.nil?
            unmapped << unmapped_entry(it, nil, reason, info)
            next
          end
          set = sets[sid]
          if set.nil?
            unmapped << unmapped_entry(it, sid, 'set_missing')
            next
          end
          expand_members(it, set, qty, rows, unmapped, owner_seen, lookup)
        end
        finalize(rows, unmapped)
      end

      def normalize_cabinet_overrides(cabinet_overrides)
        return {} unless cabinet_overrides.is_a?(Hash)
        out = {}
        cabinet_overrides.each do |cid, map|
          next unless map.is_a?(Hash)
          out[cid.to_s] = normalize_mapping(map, nil, allow_owner: true)
        end
        out
      end

      # Set pre polozku. Poradie (H1a D-81): override na urovni VLASTNIKA
      # ("slide@front:F1/panel") -> cabinet override ("slide") -> projektove
      # mapovanie. Ked je vyhrana hodnota selector, set urci pasmo parametra;
      # chybajuca hodnota / mimo pasiem = ORANGE, NIKDY hadanie.
      # -> [set_id|nil, reason|nil, info Hash]
      def resolve_set_id(generic_type, it, cabinet_overrides, mapping)
        value = resolve_mapping_value(generic_type, it, cabinet_overrides, mapping)
        return [nil, 'no_set', {}] if value.nil?
        return [value, nil, {}] if value.is_a?(String)
        param = value['param'].to_s
        v = numeric_param(it, param)
        info = { 'param' => param, 'value' => v }
        return [nil, 'selector_unresolved', info] if v.nil?
        band = Array(value['bands']).find { |b| v >= b['min'].to_f && v <= b['max'].to_f }
        return [nil, 'selector_unresolved', info] if band.nil?
        [band['set_id'].to_s, nil, {}]
      end

      def resolve_mapping_value(generic_type, it, cabinet_overrides, mapping)
        ov = cabinet_overrides[it['owner_id'].to_s]
        if ov.is_a?(Hash)
          opk = it['owner_part_key'].to_s
          unless opk.empty?
            v = ov["#{generic_type}@#{opk}"]
            return v if present_mapping_value?(v)
          end
          v = ov[generic_type]
          return v if present_mapping_value?(v)
        end
        v = mapping[generic_type]
        present_mapping_value?(v) ? v : nil
      end

      def present_mapping_value?(v)
        (v.is_a?(String) && !v.strip.empty?) || (v.is_a?(Hash) && v['bands'].is_a?(Array))
      end

      def numeric_param(it, param)
        params = it['params'].is_a?(Hash) ? it['params'] : {}
        v = params[param]
        return nil unless v.is_a?(Numeric) && v.to_f.finite?
        v.to_f
      end

      def expand_members(it, set, qty, rows, unmapped, owner_seen, lookup)
        sid = set['set_id']
        Array(set['members']).each_with_index do |m, idx|
          code, miss = member_code(m, it)
          if miss
            unmapped << unmapped_entry(it, sid, miss['reason'], miss.merge(
                                                                  'member_index' => idx,
                                                                  'member_label' => m['label']
                                                                ))
            next
          end
          next if code.nil?
          m_qty = m['qty'].to_i
          total =
            if m['per'] == 'owner'
              # audit B3: 1x na (korpus, vlastnik, set, kod) — druhe pravidlo
              # s rovnakym vlastnikom TipOn nezdvoji.
              key = [it['owner_id'].to_s, it['owner_part_key'].to_s, sid, code].join('|')
              next if owner_seen[key]
              owner_seen[key] = true
              m_qty
            else
              qty * m_qty
            end
          add_row(rows, code, total, it, sid, lookup)
        end
      end

      # Kod clena: pevny 'code', rad 'code_by_nl' podla params.nominal_length
      # alebo 'param_bands' podla lubovolneho ciselneho parametra.
      # -> [code|nil, nil] (nil code = clen sa preskoci) | [nil, miss Hash]
      def member_code(member, it)
        if member['code_by_nl'].is_a?(Hash)
          nl = numeric_param(it, 'nominal_length')
          miss = { 'reason' => 'nl_missing', 'param' => 'nominal_length', 'value' => nl }
          return [nil, miss] if nl.nil?
          # GH #126 P2: frakcna NL z vlastnej serie (419,6) sa NEZAOKRUHLUJE
          # na susedny kluc — presna celociselna zhoda alebo nic (F10).
          i = nl.round
          return [nil, miss] unless (nl - i).abs < 1e-9
          code = member['code_by_nl'][i.to_s]
          return [nil, miss] if code.nil? || code.to_s.strip.empty?
          [code.to_s.strip, nil]
        elsif member['param_bands'].is_a?(Hash)
          param = member['param_bands']['param'].to_s
          v = numeric_param(it, param)
          miss = { 'reason' => 'param_band_missing', 'param' => param, 'value' => v }
          return [nil, miss] if v.nil?
          band = Array(member['param_bands']['bands']).find do |b|
            v >= b['min'].to_f && v <= b['max'].to_f
          end
          return [nil, miss] if band.nil? || band['code'].to_s.strip.empty?
          [band['code'].to_s.strip, nil]
        else
          c = member['code'].to_s.strip
          [c.empty? ? nil : c, nil]
        end
      end

      def add_row(rows, code, quantity, it, sid, lookup)
        # GH #126 P2: identita kodu je case-insensitive (kontrakt katalogu) —
        # agregacny kluc kanonicky, zobrazuje sa prvy videny zapis.
        row = rows[code.downcase] ||= { 'code' => code, 'quantity' => 0, 'sources' => [] }
        row['quantity'] += quantity
        row['sources'] << {
          'cabinet_id' => it['owner_id'].to_s,
          'owner_part_key' => (it['owner_part_key'].nil? ? nil : it['owner_part_key'].to_s),
          'generic_type' => it['generic_type'].to_s,
          'rule_id' => it['rule_id'].to_s,
          'set_id' => sid,
          'quantity' => quantity
        }
        row_join(row, lookup)
      end

      def row_join(row, lookup)
        item = lookup[row['code'].downcase]
        if item.nil?
          row['missing'] = true
          row['name_sk'] = nil
          row['category'] = nil
          row['unit'] = nil
          row['price_eur_vat'] = nil
        else
          row['missing'] = false
          row['name_sk'] = item['name_sk']
          row['category'] = item['category']
          row['unit'] = item['unit']
          row['price_eur_vat'] = item['price_eur_vat']
        end
        row
      end

      # H1a (audit FIX 9): dovod nesie AJ parameter, jeho hodnotu a — pri
      # pasmach clena — identifikaciu CLENA (index + label). Bez toho by dva
      # chybajuce pasma v jednom sete splynuli do jedneho ORANGE riadku a
      # klik-select by neukazal, ktory clen doplnit.
      def unmapped_entry(it, sid, reason, extra = {})
        params = it['params'].is_a?(Hash) ? it['params'] : {}
        out = {
          'cabinet_id' => it['owner_id'].to_s,
          'owner_part_key' => (it['owner_part_key'].nil? ? nil : it['owner_part_key'].to_s),
          'generic_type' => it['generic_type'].to_s,
          'rule_id' => it['rule_id'].to_s,
          'quantity' => it['quantity'].to_i,
          'set_id' => sid,
          'reason' => reason,
          'nominal_length' => (params['nominal_length'].is_a?(Numeric) ? params['nominal_length'].to_f : nil)
        }
        ex = extra.is_a?(Hash) ? extra : {}
        %w[param value member_index member_label].each do |k|
          out[k] = ex[k] if ex.key?(k)
        end
        out
      end

      # Zoradenie + medzisucty. Cena nil = "nezadana" (subtotal nil, nikdy 0 —
      # audit N11); summary total scitava LEN zname ceny a nesie pocet neznamych.
      def finalize(rows, unmapped)
        cat_rank = {}
        if defined?(HardwareCatalog)
          HardwareCatalog::CATEGORIES.each_with_index { |c, i| cat_rank[c] = i }
        end
        list = rows.values.sort_by do |r|
          [r['missing'] ? 1 : 0, cat_rank.fetch(r['category'], 98) || 98, r['code']]
        end
        total = 0.0
        unknown = 0
        list.each do |r|
          price = r['price_eur_vat']
          if price.is_a?(Numeric) && r['missing'] == false
            r['subtotal_eur_vat'] = (price.to_f * r['quantity']).round(2)
            total += r['subtotal_eur_vat']
          else
            r['subtotal_eur_vat'] = nil
            unknown += 1
          end
        end
        {
          'rows' => list,
          'unmapped' => unmapped,
          'summary' => { 'rows' => list.length,
                         'quantity' => list.sum { |r| r['quantity'] },
                         'total_eur_vat' => total.round(2),
                         'unknown_prices' => unknown,
                         'unmapped' => unmapped.length }
        }
      end

      def catalog_lookup(catalog)
        out = {}
        if catalog.is_a?(Hash)
          catalog.each { |k, v| out[k.to_s.strip.downcase] = v if v.is_a?(Hash) }
        else
          Array(catalog).each do |item|
            next unless item.is_a?(Hash)
            code = item['item_code'].to_s.strip.downcase
            out[code] = item unless code.empty?
          end
        end
        out
      end

      # --- normalizacia a validacia (audit F10 + H1a) --------------------------

      # PRISNA validacia JEDNEHO setu (zapisova cesta). ALL-OR-NOTHING:
      # jediny chybny clen zhodi cely set — ziadny tichy drop clenov.
      # -> [norm|nil, errors]
      def validate_set(set)
        return [nil, ['set musí byť objekt']] unless set.is_a?(Hash)
        s = deep_copy(stringify(set))
        sid = s['set_id'].to_s.strip
        return [nil, ['set nemá set_id']] if sid.empty?
        gt = s['generic_type'].to_s.strip
        unless BuildPlan::GENERIC_TYPES.include?(gt)
          return [nil, ["set „#{sid}“ má neznámy typ kovania „#{gt}“"]]
        end
        raw_members = s['members']
        unless raw_members.is_a?(Array) && !raw_members.empty?
          return [nil, ["set „#{sid}“ nemá členov"]]
        end
        errors = []
        members = raw_members.each_with_index.map do |m, i|
          norm, errs = validate_member(m, i, strict: true)
          errors.concat(errs.map { |e| "set „#{sid}“: #{e}" })
          norm
        end
        return [nil, errors] unless errors.empty?
        [{ 'set_id' => sid,
           'name' => (s['name'].to_s.strip.empty? ? sid : s['name'].to_s.strip),
           'generic_type' => gt,
           'members' => members }, []]
      end

      # PRISNA validacia pola setov. Duplicitne set_id = chyba (v citacej ceste
      # sa druhy ticho zahodi, v zapisovej je to nejednoznacnost). -> [norm, errors]
      def validate_sets(sets)
        return [[], ['sety musia byť pole']] unless sets.is_a?(Array)
        errors = []
        seen = {}
        out = sets.map do |set|
          norm, errs = validate_set(set)
          errors.concat(errs)
          next nil if norm.nil?
          if seen[norm['set_id']]
            errors << "set „#{norm['set_id']}“ je v knižnici viackrát"
            next nil
          end
          seen[norm['set_id']] = true
          norm
        end
        errors.empty? ? [out, []] : [[], errors]
      end

      # Clen setu: per enum, qty kladny Integer, PRAVE JEDEN z
      # code / code_by_nl / param_bands. -> [norm|nil, errors]
      # strict: true = zapisova cesta (chybny kluc radu = chyba). false =
      # citacia cesta legacy suborov, kde sa nepouzitelny kluc radu ticho
      # zahodi (historicke spravanie; pasma tuto tolerancia NEMAJU — pokazene
      # pasmo by ticho menilo, ktory kod sa vyberie).
      def validate_member(member, index = 0, strict: false)
        pos = "člen #{index + 1}"
        return [nil, ["#{pos} musí byť objekt"]] unless member.is_a?(Hash)
        mm = stringify(member)
        per = mm['per'].to_s.strip
        per = 'unit' if per.empty?
        return [nil, ["#{pos} má neznáme „per“ (#{per})"]] unless PER_KINDS.include?(per)
        qty = mm['qty'].nil? ? 1 : mm['qty'].to_i
        return [nil, ["#{pos} má neplatný počet"]] if qty < 1
        qty = [qty, BuildPlan::MAX_HW_QUANTITY].min

        has_code  = !mm['code'].to_s.strip.empty?
        has_nl    = mm['code_by_nl'].is_a?(Hash) && !mm['code_by_nl'].empty?
        has_bands = mm['param_bands'].is_a?(Hash)
        kinds = [has_code, has_nl, has_bands].count(true)
        if kinds != 1
          return [nil, ["#{pos} musí mať práve jedno z: kód, rad podľa dĺžky, pásma parametra"]]
        end
        if per == 'owner' && (has_nl || has_bands)
          return [nil, ["#{pos}: rad/pásma sú per jednotka, nie per vlastníka"]]
        end

        out = { 'per' => per, 'qty' => qty }
        label = mm['label'].to_s.strip
        out['label'] = label unless label.empty?
        if has_code
          out['code'] = mm['code'].to_s.strip
        elsif has_nl
          map, errs = validate_code_by_nl(mm['code_by_nl'], pos, strict: strict)
          return [nil, errs] unless errs.empty?
          out['code_by_nl'] = map
        else
          bands, errs = validate_param_bands(mm['param_bands'], 'code', pos)
          return [nil, errs] unless errs.empty?
          out['param_bands'] = bands
        end
        [out, []]
      end

      def validate_code_by_nl(raw, pos, strict: false)
        map = {}
        errors = []
        raw.each do |k, v|
          nl = begin
            Integer(k.to_s.strip, 10)
          rescue ArgumentError, TypeError
            nil
          end
          code = v.to_s.strip
          if nl.nil? || nl < 1
            errors << "#{pos}: „#{k}“ nie je platná dĺžka radu" if strict
          elsif code.empty?
            errors << "#{pos}: dĺžka #{nl} nemá kód" if strict
          else
            map[nl.to_s] = code
          end
        end
        errors << "#{pos}: rad je prázdny" if map.empty? && errors.empty?
        [map, errors]
      end

      # Pasma (H1a FIX 8) — value_key 'code' (clen setu) alebo 'set_id'
      # (selector mapovania). Konvencia hranic a prekryvov je v hlavicke suboru.
      # -> [norm|nil, errors]; norm = { 'param' => .., 'bands' => [...] } zoradene.
      def validate_param_bands(raw, value_key, pos)
        return [nil, ["#{pos}: pásma musia byť objekt"]] unless raw.is_a?(Hash)
        h = stringify(raw)
        param = h['param'].to_s.strip
        return [nil, ["#{pos}: pásma nemajú názov parametra"]] if param.empty?
        list = h['bands']
        return [nil, ["#{pos}: pásma sú prázdne"]] unless list.is_a?(Array) && !list.empty?
        errors = []
        bands = list.each_with_index.map do |b, i|
          unless b.is_a?(Hash)
            errors << "#{pos}: pásmo #{i + 1} musí byť objekt"
            next nil
          end
          bb = stringify(b)
          min = num(bb['min'])
          max = num(bb['max'])
          val = bb[value_key].to_s.strip
          if min.nil? || max.nil?
            errors << "#{pos}: pásmo #{i + 1} nemá konečné min/max"
            next nil
          end
          if min > max
            errors << "#{pos}: pásmo #{i + 1} má min väčšie ako max"
            next nil
          end
          if val.empty?
            errors << "#{pos}: pásmo #{i + 1} (#{min.round(1)}–#{max.round(1)}) nemá hodnotu"
            next nil
          end
          { 'min' => min, 'max' => max, value_key => val }
        end
        return [nil, errors] unless errors.empty?
        bands = bands.sort_by { |b| [b['min'], b['max']] }
        bands.each_cons(2) do |a, b|
          # UZAVRETE hranice -> dotyk (a.max == b.min) je uz prekryv
          next if a['max'] < b['min']
          errors << "#{pos}: pásma #{a['min'].round(1)}–#{a['max'].round(1)} a " \
                    "#{b['min'].round(1)}–#{b['max'].round(1)} sa prekrývajú"
        end
        return [nil, errors] unless errors.empty?
        [{ 'param' => param, 'bands' => bands }, []]
      end

      def num(v)
        return nil unless v.is_a?(Numeric) || (v.is_a?(String) && !v.strip.empty?)
        f = Float(v)
        f.finite? ? f : nil
      rescue ArgumentError, TypeError
        nil
      end

      # CITACIA cesta (legacy/cudzi subor): TOLERANTNA — nevalidny clen vypadne,
      # set bez pouzitelnych clenov vypadne cely; obe s logom. Citanie nesmie
      # zhodit prestavbu ANI zahodit cely set kvoli jednemu starsiemu clenu.
      # Zapisova cesta ide cez validate_sets (prisne, all-or-nothing).
      def normalize_sets(sets)
        seen = {}
        Array(sets).filter_map do |set|
          next nil unless set.is_a?(Hash)
          s = deep_copy(stringify(set))
          sid = s['set_id'].to_s.strip
          next nil if sid.empty? || seen[sid]
          gt = s['generic_type'].to_s.strip
          next nil unless BuildPlan::GENERIC_TYPES.include?(gt)
          members = normalize_members(s['members'])
          if members.empty?
            log_skip("set „#{sid}“ preskoceny — ziadny pouzitelny clen")
            next nil
          end
          seen[sid] = true
          { 'set_id' => sid,
            'name' => (s['name'].to_s.strip.empty? ? sid : s['name'].to_s.strip),
            'generic_type' => gt,
            'members' => members }
        end
      end

      def normalize_members(members)
        Array(members).each_with_index.filter_map do |m, i|
          norm, errors = validate_member(m, i)
          log_skip(errors.first) if norm.nil? && !errors.empty?
          norm
        end
      end

      # JEDINY parser mapovania (audit BLOCKER 2). Vrati [norm, errors]:
      #   errors — chyby TVARU (zapisova cesta ich odmieta, citacia loguje)
      #   set_ids — ak su dane, polozka ukazujuca na NEEXISTUJUCI set sa vyhodi
      #             TICHO (delete_set! ocisti mapovanie; typ ostane nemapovany)
      #   allow_owner — composite kluce "gt@owner_part_key"; true LEN pre
      #             cabinet override mapu (config['hardware_sets'])
      def parse_mapping(mapping, set_ids: nil, allow_owner: false)
        return [{}, []] if mapping.nil? # chybajuce mapovanie = legitimne prazdne
        return [{}, ['mapovanie musí byť objekt']] unless mapping.is_a?(Hash)
        ids = set_ids.nil? ? nil : Array(set_ids).map(&:to_s)
        out = {}
        errors = []
        mapping.each do |key, value|
          parsed = BuildPlan.parse_hardware_set_key(key)
          if parsed.nil?
            errors << "mapovanie „#{key}“ má neplatný kľúč"
            next
          end
          gt, owner = parsed
          if owner && !allow_owner
            errors << "mapovanie „#{key}“: výber na úrovni dielca je len na skrinke"
            next
          end
          status, norm, refs = parse_mapping_value(value)
          if status != :ok
            errors << "mapovanie „#{key}“: #{norm}"
            next
          end
          next if ids && refs.any? { |sid| !ids.include?(sid) }
          out[owner ? "#{gt}@#{owner}" : gt] = norm
        end
        [out, errors]
      end

      # Hodnota mapovania: set_id String ALEBO selector Hash.
      # -> [:ok, norm, referenced_set_ids] | [:invalid, message, nil]
      def parse_mapping_value(value)
        if value.is_a?(String) || value.is_a?(Symbol)
          sid = value.to_s.strip
          return [:invalid, 'prázdne set_id', nil] if sid.empty?
          return [:ok, sid, [sid]]
        end
        unless value.is_a?(Hash)
          return [:invalid, 'hodnota musí byť set_id alebo výber podľa parametra', nil]
        end
        norm, errors = validate_param_bands(value, 'set_id', 'výber')
        return [:invalid, errors.first, nil] if norm.nil?
        [:ok, norm, norm['bands'].map { |b| b['set_id'] }.uniq]
      end

      # Vsetky set_id, na ktore hodnota mapovania ukazuje (priamo alebo cez
      # pasma selectora) — pouziva ich zmrazovanie snapshotu (audit BLOCKER 1).
      def value_set_ids(value)
        status, _norm, refs = parse_mapping_value(value)
        status == :ok ? refs : []
      end

      # Mnozina set_id referencovanych mapovanim projektu + cabinet overridmi.
      def referenced_set_ids(mapping, cabinet_overrides = {})
        out = []
        (mapping.is_a?(Hash) ? mapping : {}).each_value { |v| out.concat(value_set_ids(v)) }
        (cabinet_overrides.is_a?(Hash) ? cabinet_overrides : {}).each_value do |map|
          next unless map.is_a?(Hash)
          map.each_value { |v| out.concat(value_set_ids(v)) }
        end
        out.uniq
      end

      # CITACIA normalizacia mapovania (spatna kompatibilita signatury:
      # sets = pole definicii setov). Chyby tvaru sa loguju a polozka vypadne.
      def normalize_mapping(mapping, sets = nil, allow_owner: false)
        ids = sets.nil? ? nil : sets.map { |s| s['set_id'] }
        out, errors = parse_mapping(mapping, set_ids: ids, allow_owner: allow_owner)
        errors.each { |e| log_skip(e) }
        out
      end

      def log_skip(msg)
        Engine.log("hardware sets: #{msg}") if defined?(Engine) && Engine.respond_to?(:log)
      end

      def stringify(h)
        h.each_with_object({}) do |(k, v), out|
          out[k.to_s] = v.is_a?(Hash) ? stringify(v) : v
        end
      end

      def deep_copy(obj)
        JsonFileStore.deep_copy(obj)
      end
    end
  end
end
