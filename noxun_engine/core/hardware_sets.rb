# frozen_string_literal: true
# Noxun Engine — V0.6 D1: sety kovania (mapovanie genericky typ -> zoznam Demos kodov).
#
# ============================ ARCHITEKTURA ============================
# Faza 2 kovania (standard 6.2): pravidla (hardware_rules) daju GENERIKU
# (hinge x6 s ownerom, slide s params.nominal_length...), set ju prelozi na
# KODY katalogu (hardware_catalog) s pomermi. Set NIE JE polozka katalogu —
# je to mapovacie pravidlo (zamknute rozhodnutie, debata 2.8.2026,
# SYSTEM/POJMY.md "Kovanie — sety").
#
# TVAR SETU:
#   { "set_id": "zaves-klasik",            # slug identita, NEMENNA
#     "name": "Záves KLASIK (Sensys 110°)",
#     "generic_type": "hinge",             # BuildPlan::GENERIC_TYPES
#     # --- KLASIFIKACIA (KOV-B1) — VOLITELNY BLOK, all-or-nothing ---
#     "use_type": "door",                  # USE_TYPES; urcuje generic_type
#     "opening_mode": "classic",           # OPENING_MODES ('other' = neuplatnuje sa)
#     "drawer_construction": "metal",      # LEN pri use_type 'drawer'
#     "manufacturer": "Hettich",           # kanonicky nazov z HardwareTaxonomy
#     "series": "Sensys",                  # VOLITELNA rada (kluc chyba = bez rady)
#     "active": false,                     # sparse — uklada sa LEN false
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
#   "class:<generic_type>|<opening_mode>[|<drawer_construction>]"  — KOV-B1,
#     TRIEDNY kluc pripraveny pre KOV-D („vysuvy TipOn maju iny set nez
#     klasicke"). Tvar je uzavrety (tretí segment LEN pri `slide`, ziadny
#     `@owner` sufix, segmenty trim+downcase) a od tejto davky ho pozna
#     parser, whitelist brany aj std detekcia — takze KOV-D uz NEBUDE
#     potrebovat dalsi bump. ZATIAL HO NIC NECITA: `resolve_set_id`, `expand`
#     ani `explain` sa nan nepytaju a zapisove cesty ho nepisu. Ucel tejto
#     davky je vyhradne BEZSTRATOVY ROUND-TRIP (kto ho ma v subore, o neho
#     nepride) a spravny marker std.
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
      STD = 1 # baseline: len legacy tvary (code / code_by_nl, mapovanie = set_id)

      # GH #131 P2: marker novych tvarov, LAZY podla OBSAHU (vzor materials
      # SCHEMA_CURRENT). Starsi plugin (0.5.39) by zo setu s param_bands ticho
      # zahodil LEN ten clen a set by nechal — jeho project_state_status
      # porovnava iba POCET setov, takze by vratil :ok a nakupil NEUPLNY set.
      # Snapshot, ktory nesie pasma clena alebo selector v mapovani, preto
      # dostane std 2 — starsia verzia ho odmietne ako :invalid (ORANGE,
      # NIKDY ticho iny nakup). Snapshoty bez novych tvarov ostavaju std 1,
      # takze starsie verzie ich citaju dalej bez zmeny.
      STD_PARAM_FORMS = 2

      # KOV-B1: set nesie KLASIFIKACIU (typ pouzitia · sposob otvarania ·
      # konstrukcia zasuvky · vyrobca · rada · aktivny) alebo mapovanie nesie
      # TRIEDNY kluc `class:…`. Starsi plugin oboje ticho OREZE (whitelist
      # klucov) a prvym zapisom stratu zvecni, preto taky obsah dostane std 3
      # a starsia verzia ho odmietne ako read-only / `:invalid`. Marker je
      # LAZY podla OBSAHU (`snapshot_std`): cisto legacy kniznica a snapshot
      # ostavaju na 1/2, takze spatna citatelnost sa zbytocne neblokuje.
      STD_CLASSIFIED  = 3
      STD_SUPPORTED   = [STD, STD_PARAM_FORMS, STD_CLASSIFIED].freeze

      # v2 (H1a): +set „Nohy podla vysky sokla" (param_bands) a migracia
      # globalneho defaultu leg z 'nohy-klzak-17' na neho.
      SEED_VERSION = 2
      FILE         = 'hardware_sets.json'
      MODEL_KEY    = 'hardware_sets' # kluc snapshotu v NOXUN dict na modeli

      # Uctovanie clena setu. Obe hodnoty su KUSOVE — expand vie iba nasobit
      # kusy. Dlzkove uctovanie (suma mm, MJ „m") tu ZATIAL NIE JE; kym
      # nepride (R-05/R-06 v bloku KOVANIE), drzi hranicu brana
      # `length_unsupported?` nizsie.
      PER_KINDS = %w[unit owner].freeze

      # Dovody nemapovanej polozky (ORANGE) — jediny kanonicky zoznam; texty
      # semaforu mapuje Validation.check_hardware_expansion.
      UNMAPPED_REASONS = %w[no_set set_missing set_type_mismatch nl_missing
                            param_band_missing selector_unresolved
                            length_unsupported library_incompatible].freeze

      # --- 1d/R-07: whitelist ZNAMYCH klucov (detektor straty) ----------------
      # Normalizacia je TOLERANTNA (citanie nesmie zhodit prestavbu), takze
      # kluc, ktory tato verzia NEPOZNA, ticho zmizne — a prvy zapis stratu
      # ZVECNI. Zoznamy su preto UZAVRETE: cokolvek mimo nich = obsah novsej
      # (alebo cudzej) verzie a kniznica/snapshot sa smie uz len CITAT.
      # POZOR: whitelisty su KONTRAKT — kazde nove pole clena/pasma sa musi
      # doplnit SEM, inak vlastny zapis vyrobi read-only stav.
      # LEGACY_SET_KEYS = tvar setu pred KOV-B1. Sluzi na LAZY detekciu std:
      # set, ktory ma ktorykolvek kluc MIMO tohto zoznamu, uz nie je citatelny
      # starsim pluginom (`snapshot_std` -> 3).
      LEGACY_SET_KEYS  = %w[set_id name generic_type members].freeze
      MEMBER_KEYS      = %w[per qty label code code_by_nl param_bands].freeze
      PARAM_BANDS_KEYS = %w[param bands].freeze
      BAND_KEYS        = %w[min max].freeze # + hodnota (code / set_id)

      # === KOV-B1: KLASIFIKACIA SETU ==========================================
      #
      # Set uz nie je len „mapovanie generickeho typu na kody" — nesie AJ to,
      # NA CO sa pouziva. Slovniky su UZAVRETE (neznama hodnota = obsah novsej
      # verzie, nie nova kategoria).
      #
      #   use_type            na co je set (dvierka / zasuvka / vyklop / sklop /
      #                       ine — nohy, podperky, zavesenie)
      #   opening_mode        sposob otvarania; `other` = „neuplatnuje sa"
      #   drawer_construction konstrukcia zasuvky — LEN pri `use_type: 'drawer'`
      #   manufacturer        kanonicky nazov z HardwareTaxonomy (povinny)
      #   series              kanonicky nazov rady — VOLITELNY (podperky, klzaky
      #                       ani „Bystrica" ziadnu radu nemaju; vynutena rada by
      #                       taxonomiu znecistila vymyslenymi menami)
      #   active              sparse priznak — uklada sa LEN `false`
      USE_TYPES           = %w[door drawer lift fall other].freeze
      OPENING_MODES       = %w[classic tipon other].freeze
      DRAWER_CONSTRUCTIONS = %w[metal wood other].freeze

      # KANONICKA MAPA typu pouzitia na typ kovania (audit #17 BLOCKER 2).
      # JEDINA autorita vztahu: `generic_type` je pri klasifikovanom sete
      # ODVODENY, nie nezavisly udaj — inak by sa dali ulozit dva protirecive
      # zapisy o tom istom sete. `other` mapu nema (typ sa uvedie explicitne).
      USE_TYPE_GENERIC = { 'door' => 'hinge', 'drawer' => 'slide',
                           'lift' => 'lift', 'fall' => 'lift' }.freeze

      # Klasifikacne kluce su ALL-OR-NOTHING (audit #17 FIX 6): pri zapise su
      # bud VSETKY (kontextovo platne), alebo ZIADNY = legacy „nezaradeny" set.
      # Ciastocny tvar sa odmieta — polovicna klasifikacia by v B3 vyzerala ako
      # hotove zaradenie a filtre KOV-D by nan nesadli.
      CLASS_KEYS = %w[use_type opening_mode drawer_construction manufacturer series].freeze

      # POZOR: whitelist je KONTRAKT (viz odsek vyssie) — kazde nove pole setu
      # sa musi doplnit SEM, inak vlastny zapis vyrobi read-only stav.
      SET_KEYS = (LEGACY_SET_KEYS + CLASS_KEYS + %w[active]).freeze

      # Poradie klucov normalizovaneho setu (stabilny tvar = stabilny odtlacok
      # kniznice aj snapshotu). Klasifikacne kluce su pritomne LEN pri
      # klasifikovanom sete, `series` a `active` len ked maju hodnotu.
      SET_KEY_ORDER = %w[set_id name generic_type use_type opening_mode
                         drawer_construction manufacturer series active members].freeze

      # H1b: parametre, podla ktorych sa daju stavat pasma clena (param_bands)
      # a selector mapovania. JEDINA autorita ponuky pre UI — okno Katalog
      # kovania ich dostane v payloade, JS ziadny vlastny zoznam nema.
      #   label = 1. pad (popisok selectu), by = „podla ..." (2. pad).
      # (Validation::HW_PARAM_LABELS drzi 4. pad pre vety semafora — iny pad,
      # ina vrstva; sem patri to, co vidi pouzivatel v EDITORE.)
      PARAM_OPTIONS = [
        { 'key' => 'height',       'label' => 'výška sokla', 'by' => 'podľa výšky sokla' },
        { 'key' => 'front_height', 'label' => 'výška čela',  'by' => 'podľa výšky čela' }
      ].freeze

      # Seed sety = zavery debaty 2.8.2026 (POJMY "Kovanie — sety");
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

      # --- slovnik parametrov (H1b) --------------------------------------------

      def param_label(key)
        opt = PARAM_OPTIONS.find { |o| o['key'] == key.to_s }
        opt ? opt['label'] : (key.to_s.empty? ? 'parameter' : "parameter „#{key}“")
      end

      def param_by(key)
        opt = PARAM_OPTIONS.find { |o| o['key'] == key.to_s }
        opt ? opt['by'] : "podľa: #{param_label(key)}"
      end

      # --- globalna kniznica (%APPDATA%) --------------------------------------

      def dir
        Materials.dir # zdielany %APPDATA%/NOXUN/Engine (+ test_dir_override)
      end

      def path
        File.join(dir, FILE)
      end

      # --- 1d/R-08: medziprocesovy zamok globalnych katalogov -----------------
      #
      # JEDEN sidecar zamok (`materials.lock`) pre VSETKY katalogy v
      # %APPDATA%\NOXUN\Engine — vzor 1b-6c. Vlastny `.lock` per subor by
      # vyrobil PORADIE zamkov a s nim riziko zaseknutia; zdielany zamok
      # ziadne poradie nema. Je REENTRANTNY, takze vnoreny `write` pod uz
      # drzanym zamkom len zvysi hlbku. `flock`, ktory sa nepodari vziat,
      # vyhodi IOError — kazda zapisova cesta ho rescue-uje do svojho
      # NEUSPESNEHO vysledku, nikdy do ticheho uspechu.
      #
      # CITANIE bez zapisu sa NEZAMYKA (hot cesty expand/explain/payloadov).
      def with_catalog_lock(&blk)
        Materials.with_catalog_lock(&blk)
      end

      # --- 1d/R-07: kompatibilitna BRANA globalnej kniznice -------------------
      #
      # Kniznica setov je GLOBALNA (%APPDATA%), takze ju zdielaju vsetky verzie
      # pluginu na tom istom profile. Starsia verzia novsi subor precitala,
      # neznamy obsah TICHO orezala a prvym zapisom stratu ZVECNILA. Od tejto
      # davky ma kniznica STAV (vzor `HardwareCatalog.assess!`):
      #   :ok        — subor je tejto verzii cely zrozumitelny,
      #   :degraded  — 1d/R-11, viz nizsie: obsah sa SMIE citat aj pouzit,
      #                ale do globalneho SUBORU sa nesmie zapisat,
      #   :read_only — nesmie sa ANI zapisat, ANI POUZIT (`load` z nej nic
      #                nevyda — viz jeho odsek).
      #
      # Dovod je SK veta pre pouzivatela (`library_state_reason`) a KOD
      # (`library_state_code`) pre kod. Kody su `:newer` · `:foreign` ·
      # `:unknown_shape` · `:duplicate` · `:unreadable` · `:unexpected_shape`
      # (posledny = fail-closed vetva, moze ho sposobit aj chyba pluginu nad
      # zdravym suborom, preto jeho hlaska NENAVADZA subor mazat) · `:degraded`.
      #
      # 1d/R-11 — DEGRADOVANY SUBOR (poskodeny primar + platna `.bak`).
      # R-07 tu nechala miesto s poznamkou „novy dovod patri do tej istej
      # matice". Matica ostava JEDNA (jeden stav, jeden kod, jeden dovod), ale
      # kontrola NEMOHLA prist dovnutra `assess_library_doc`: tá je CISTA
      # funkcia nad DOKUMENTOM (ziadne IO) a degraded je vlastnost SUBOROV na
      # disku — dokument sa v tom pripade parsuje uplne v poriadku, lebo
      # pochadza zo ZALOHY. Kontrola preto sedi vo vrstve NAD nou
      # (`assess_library`), ktora vysledok dokumentovej matice len DOPLNI,
      # a `apply_library_state` aj tak zapisuje jediny vysledok — dva dovody
      # sa nemozu prebijat a `:read_only` nikdy nespadne na nizsi stupen
      # (degraded sa zvazuje LEN vtedy, ked dokument dopadol `:ok`).
      #
      # PRECO NIE `:read_only`: zaloha je POUZITELNY obsah (na rozdiel od
      # kniznice z novsej verzie, kde je obsah orezany o to, comu nerozumieme).
      # Zakazka sa musi dat dokoncit: sety sa daju CITAT, zmrazit do projektu
      # a projektove predvolby menit — to su zapisy do MODELU, nie do
      # poskodeneho suboru. Zakazane su VYHRADNE zapisy do globalneho suboru
      # (`save_set!` · `delete_set!` · `set_global_mapping!` · seed-merge ·
      # `ensure_seeded`), lebo prave ony by primar prepisali obsahom odvodenym
      # od STARSEJ zalohy.
      #
      # STAV SA NECACHUJE (review P1-1). Zapamatane `:ok` je presne ta pasca,
      # ktoru brana riesi: subor mohol medzitym nahradit iny proces, takze
      # volajuci by sa rozhodol podla STARSIEHO verdiktu nad NOVSIM obsahom.
      # `@lib_*` su len VYSLEDOK poslednej kontroly (dovod pre volajuceho, ktory
      # sa uz spytal). Citanie suboru pod tym drzi sekundovu cache
      # `JsonFileStore`, takze verdikt aj obsah pochadzaju z TOHO ISTEHO
      # dokumentu — to je invariant, na ktorom cela brana stoji.
      def library_state
        library_assess!
      end

      def library_state_reason
        @lib_state_reason.to_s
      end

      def library_state_code
        @lib_state_code
      end

      def library_read_only?
        library_state == :read_only
      end

      # 1d/R-11: smie sa zapisat do GLOBALNEHO SUBORU kniznice? `:read_only`
      # zakazuje vsetko, `:degraded` LEN zapisy do suboru. Volajuci, ktori
      # rozhoduju o POUZITI obsahu (projektovy snapshot, expanzia, sablony),
      # sa dalej pytaju `library_read_only?` — degradovana kniznica sa pouzit
      # SMIE (obsah zalohy je platny).
      def library_write_blocked?
        [:read_only, :degraded].include?(library_state)
      end

      # Test-only reset (stav je modulova cache nad globalnym suborom).
      def reset_library_state!
        @lib_state = nil
        @lib_state_code = nil
        @lib_state_reason = ''
        true
      end

      # Vyhodnoti stav nad AKTUALNYM obsahom suboru. Bez zamku — je to hot
      # cesta (payloady, expanzia). Pred ZAPISOM sa brana vyhodnocuje ZNOVA
      # a pod zamkom (`write`) nad suborom po `reload!`.
      def library_assess!
        apply_library_state(*assess_library(read_library_doc))
      end

      # JEDNA matica stavu: dokument (`assess_library_doc`, ciste) + stav
      # SUBOROV na disku (R-11 degraded). Poradie je zamerne — pri
      # nezrozumitelnom dokumente sa degraded uz neriesi (`:read_only` je
      # prisnejsi a jeho dovod je pre pouzivatela dolezitejsi).
      def assess_library(doc)
        state, code, reason = assess_library_doc(doc)
        return [state, code, reason] unless state == :ok
        return [:degraded, :degraded, degraded_sk] if library_degraded_file?

        [:ok, nil, '']
      end

      # R-11: poskodeny primar + platna `.bak`. Cita sa PRIAMO z disku (bez
      # sekundovej cache) — detail a dovody su v `JsonFileStore.degraded?`.
      # I/O chyba sa TU rescue-uje na `false` VEDOME NIE JE: fail-closed
      # spravanie zabezpecuje `library_assess!` az cez svojich volajucich —
      # vynimka vyleti do ich rescue vetiev ako neuspech, nie ako povolenie.
      def library_degraded_file?
        JsonFileStore.degraded?(path)
      end

      def degraded_sk
        'Knižnica setov kovania je poškodená — číta sa záloha, globálne zápisy sú vypnuté ' \
          "(oprav alebo zmaž súbor #{path})"
      end

      # Dokument kniznice na posudenie. Chybajuci subor = CISTY stav (nil).
      #
      # P2-5 (review): poskodeny primar BEZ zalohy je tiez cisty stav —
      # nie je z coho co stratit a `main` sa tak spraval odjakziva (`load`
      # spadne do seedu a prvy zapis subor SAMOOPRAVI). Keby sme ho zavreli do
      # read-only, pouzivatel by skoncil v slepej ulicke: zapis odmietnuty,
      # seed nedostupny, a nic mu nepovie, ze staci zmazat jeden subor.
      # Ked zaloha EXISTUJE, citanie sa jej drzi (`JsonFileStore` recovery) —
      # a ked sa neda precitat ani ona, ostava `:read_only` s dovodom, ktory
      # menuje CESTU. Rozhranie s R-11 (poskodeny primar s PLATNOU zalohou) je
      # tym ostre: ten pripad sem vobec nepadne (citanie zo zalohy uspeje).
      def read_library_doc
        return nil unless JsonFileStore.available?(path)
        JsonFileStore.read(path, copy: false)
      rescue StandardError
        File.exist?("#{path}.bak") ? :unreadable : nil
      end

      def apply_library_state(state, code, reason)
        changed = @lib_state != state || @lib_state_code != code
        @lib_state = state
        @lib_state_code = code
        @lib_state_reason = reason.to_s
        # Log LEN pri zmene — stav sa vyhodnocuje pri kazdom pouziti, takze
        # bezpodmienecny zapis by pri read-only kniznici zaplavil konzolu.
        if changed && state != :ok && defined?(Engine) && Engine.respond_to?(:log)
          Engine.log("hardware sets: kniznica #{state == :degraded ? 'DEGRADOVANA' : 'READ-ONLY'} — #{reason}")
        end
        state
      end

      # CISTA matica stavu nad dokumentom kniznice (ziadne IO).
      # doc = nil (subor este neexistuje = cisty stav, seed) | Hash | cokolvek.
      # -> [:ok, nil, ''] | [:read_only, kod, SK dovod]
      def assess_library_doc(doc)
        return [:ok, nil, ''] if doc.nil?
        unless doc.is_a?(Hash)
          return [:read_only, :unreadable, unreadable_sk]
        end
        std = doc['std'].to_i
        if doc.key?('std') && !STD_SUPPORTED.include?(std)
          # Marker je LAZY podla obsahu (GH #131 P2): vyssi std = tvary, ktore
          # tato verzia nepozna; nizsi/nezmyselny = cudzi subor.
          return [:read_only, :newer,
                  'Knižnica setov kovania je z novšej verzie Noxun — aktualizuj plugin'] if std > STD_SUPPORTED.max

          return [:read_only, :foreign,
                  'Knižnica setov kovania patrí inému systému (marker std)']
        end
        sets = doc['sets']
        mapping = doc['mapping']
        unless (sets.nil? || sets.is_a?(Array)) && (mapping.nil? || mapping.is_a?(Hash))
          return [:read_only, :unreadable, unreadable_sk]
        end
        raw_sets = Array(sets)
        # (0) DUPLICITNA IDENTITA (vzor katalogu, GH #99 P2): normalizacia druhy
        #     zaznam ticho zahodi, ale „aktualizuj plugin" by tu nepomohlo —
        #     s verziou to nesuvisi a spravit sa s tym da nieco ine.
        ids = raw_sets.filter_map { |s| s['set_id'].to_s.strip if s.is_a?(Hash) }
        if ids.length != ids.uniq.length
          return [:read_only, :duplicate,
                  'Knižnica setov kovania má duplicitné set_id — oprav súbor']
        end
        # (1) WHITELIST klucov — chyti NOVE POLE (novsia verzia pridala kluc,
        #     ktoremu nerozumieme a normalizacia by ho zahodila).
        if raw_sets.any? { |s| incompatible_set?(s) }
          return [:read_only, :unknown_shape, unknown_set_sk]
        end
        # (2) ROUND-TRIP (review P1-2): whitelist NESTACI. Novsia verzia pridava
        #     najprv NOVU HODNOTU existujuceho kluca (`per: 'length'`, necislny
        #     kluc radu) — kluc je znamy, whitelist ju prepusti, a normalizacia
        #     clena ticho zahodi. Porovnavame preto, ci citacia normalizacia
        #     nic NESTRATILA: pocet setov, pocet clenov a pocet poloziek radu.
        #     Je to TEN ISTY detektor, aky pouziva `project_state_status`.
        # KOV-B1: 4. vrstva — KLASIFIKACIA. `use_type: 'sliding'` z novsej
        # verzie je ZNAMY kluc so SKALARNOU hodnotou (whitelist ho pusti) a
        # tolerantne citanie by cely blok ticho zahodilo; prvy zapis by stratu
        # zvecnil. Rovnako `active` z novsieho tvaru.
        norm_sets = without_skip_log { normalize_sets(raw_sets) }
        if norm_sets.length != raw_sets.length || members_lost?(raw_sets, norm_sets) ||
           classification_lost?(raw_sets, norm_sets)
          return [:read_only, :unknown_shape, unknown_set_sk]
        end
        if mapping.is_a?(Hash)
          if mapping.any? { |k, v| incompatible_mapping_entry?(k, v) }
            return [:read_only, :unknown_shape, unknown_mapping_sk]
          end
          # Tvar mapovania cez JEDINY parser. ZAMERNE BEZ `set_ids`: polozka
          # ukazujuca na zmazany set sa vyhadzuje LEGITIMNE (`delete_set!`
          # ocisti mapovanie), takze to strata nie je — chyby TVARU (prazdne
          # set_id, composite kluc, neplatna hodnota) ano.
          _norm_map, map_errors = parse_mapping(mapping)
          return [:read_only, :unknown_shape, unknown_mapping_sk] unless map_errors.empty?
        end
        [:ok, nil, '']
      rescue StandardError => e
        # BRANA MUSI ZLYHAT ZATVORENE (review P2). Druha vrstva detektora
        # pusta CUDZI obsah cez normalizacne a parsovacie cesty — hocijaka
        # nova hodnota v nich moze vyhodit vynimku (`qty: true` -> NoMethodError).
        # Keby vyletela odtialto, `load` by ju rescue-ol, zavolal
        # `library_read_only?` a ta by ju vyvolala ZNOVA: ziadny stav, ziadny
        # dovod a nakupny supis by skoncil ako nil — teda BEZ oranzoveho
        # priznania. Nezrozumitelny dokument je preto read-only, nie vynimka.
        #
        # VLASTNY KOD, nie `:unreadable` (Codex P3): sem padne aj PROGRAMATORSKA
        # chyba nad uplne zdravym suborom. Hlaska „oprav alebo zmaz subor" by
        # vtedy navadzala zmazat funkcnu kniznicu kvoli chybe v pluginu —
        # dovod preto hovori „nemaz, nahlas".
        Engine.log_error(e, 'HardwareSets.assess_library_doc') if defined?(Engine)
        [:read_only, :unexpected_shape, unexpected_sk]
      end

      # SK dovody — jedno znenie pre banner, status aj log.
      def unreadable_sk
        "Knižnica setov kovania sa nedá prečítať — oprav alebo zmaž súbor #{path}"
      end

      def unexpected_sk
        'Knižnica setov kovania má neočakávaný tvar alebo nastala interná chyba — ' \
          'nič sa nezapisuje. Súbor NEMAŽ, nahlás problém.'
      end

      def unknown_set_sk
        'Knižnica setov kovania obsahuje set s údajmi, ktoré táto verzia Noxun nepozná — aktualizuj plugin'
      end

      def unknown_mapping_sk
        'Knižnica setov kovania obsahuje predvoľbu, ktorú táto verzia Noxun nepozná — aktualizuj plugin'
      end

      # --- detektor STRATY (audit R-07 FIX 4) ---------------------------------
      # Nie POCTY, ale WHITELIST klucov: pocet setov sedi aj vtedy, ked sa
      # zahodil clen ci pole clena. Legacy KONVERZIE hodnot (dopĺňany `per`,
      # chybajuce `qty`, cislo namiesto stringu) su kompatibilne — tie tvar
      # nemenia, len ho normalizuju.
      # TYPY hodnôt známych kľúčov (review P1). Whitelist KĽÚČA nestačí: novšia
      # verzia dá známemu kľúču iný TVAR — `code_by_nl` ako pole (štruktúrovaný
      # rad popri fallback kóde), `qty` ako objekt — a čítacia normalizácia ho
      # buď ticho zahodí, alebo (horšie) pretypuje na nezmysel: `['future'].to_s`
      # by sa stalo „kódom", ktorý sa objedná. Skalár = String alebo Numeric
      # (číslo v JSONe je legitímna legacy podoba kódu aj počtu); `true`/`false`,
      # pole a objekt skalár NIE SÚ.
      def scalar_value?(value)
        value.is_a?(String) || value.is_a?(Numeric)
      end

      # nil = kľúč chýba (legitímne). Inak musí sedieť TYP.
      # KOV-B1: `:bool` je vlastny druh pre `active` — `true`/`false` a nic ine.
      # Skalar by tu nestacil: novsia verzia moze dat `active` napr. datum
      # („aktivny do…") a citacia normalizacia by ho ticho zahodila.
      def bad_type?(value, kind)
        return false if value.nil?
        case kind
        when :scalar then !scalar_value?(value)
        when :hash   then !value.is_a?(Hash)
        when :bool   then !(value == true || value == false)
        else true
        end
      end

      def incompatible_set?(set)
        return true unless set.is_a?(Hash)
        s = stringify(set)
        return true unless (s.keys - SET_KEYS).empty?
        return true if %w[set_id name generic_type].any? { |k| bad_type?(s[k], :scalar) }
        # KOV-B1: klasifikacne polia su SKALARE, `active` je BOOL. Novsi TVAR
        # znameho kluca (pole ci objekt v `use_type`) by citanie ticho zahodilo.
        return true if CLASS_KEYS.any? { |k| bad_type?(s[k], :scalar) }
        return true if bad_type?(s['active'], :bool)
        # Neznamy generic_type = typ kovania novsej verzie; `normalize_sets` by
        # cely set ticho zahodil.
        return true unless BuildPlan::GENERIC_TYPES.include?(s['generic_type'].to_s.strip)
        members = s['members']
        return true unless members.is_a?(Array) && !members.empty?
        members.any? { |m| incompatible_member?(m) }
      end

      def incompatible_member?(member)
        return true unless member.is_a?(Hash)
        m = stringify(member)
        return true unless (m.keys - MEMBER_KEYS).empty?
        return true if %w[per qty label code].any? { |k| bad_type?(m[k], :scalar) }
        # `code_by_nl` a `param_bands` su MAPY. Coko0lvek ine (pole, string,
        # cislo) je tvar novsej verzie — nie „nula poloziek", ale NEZNAMY OBSAH:
        # normalizacia by ho zahodila BEZ STOPY a najblizsi zapis by stratu
        # zvecnil (review P1 — `members_lost?` ho ako nulu prehliadol).
        return true if %w[code_by_nl param_bands].any? { |k| bad_type?(m[k], :hash) }
        nl = m['code_by_nl']
        return true if nl.is_a?(Hash) && nl.each_value.any? { |v| !scalar_value?(v) }
        pb = m['param_bands']
        return incompatible_bands?(pb, 'code') unless pb.nil?
        false
      end

      def incompatible_bands?(raw, value_key)
        return true unless raw.is_a?(Hash)
        h = stringify(raw)
        return true unless (h.keys - PARAM_BANDS_KEYS).empty?
        return true if bad_type?(h['param'], :scalar)
        list = h['bands']
        return true unless list.is_a?(Array)
        list.any? do |b|
          next true unless b.is_a?(Hash)
          bb = stringify(b)
          next true unless (bb.keys - BAND_KEYS - [value_key]).empty?
          (BAND_KEYS + [value_key]).any? { |k| bad_type?(bb[k], :scalar) }
        end
      end

      # Polozka GLOBALNEHO mapovania: kluc musi byt zname `generic_type` (bez
      # composite `gt@owner` — ten patri LEN cabinet override mape) ALEBO
      # kanonicky TRIEDNY kluc `class:…` (KOV-B1), a hodnota set_id alebo
      # selector zo znamych klucov.
      def incompatible_mapping_entry?(key, value)
        if class_mapping_key?(key)
          # Neplatny triedny tvar (neznamy typ, neznamy sposob otvarania,
          # tretí segment mimo vysuvu) = obsah, ktoremu tato verzia nerozumie —
          # rovnaka odpoved ako pri neznamom generickom type.
          return true if parse_class_key(key)[0].nil?
        else
          parsed = BuildPlan.parse_hardware_set_key(key)
          return true if parsed.nil? || parsed[1]
        end
        return false if value.is_a?(String) || value.is_a?(Symbol)
        incompatible_bands?(value, 'set_id')
      end

      # --- KOV-B1: TRIEDNY kluc mapovania (`class:…`) -------------------------
      #
      # Kanonicky tvar `class:<generic_type>|<opening_mode>[|<drawer_construction>]`
      # pripraveny pre KOV-D. Segmenty sa trimuju a downcasuju, tretí segment
      # ma LEN `slide` (konstrukcia zasuvky inde nedava zmysel) a `@owner` sufix
      # je zakazany (vyber na urovni dielca je iny pojem a patri do cabinet mapy).
      #
      # ZAPISOVA cesta neplatny tvar ODMIETNE, citacia ho LOGUJE a vyhodi —
      # presne ako pri ostatnych klucoch (`parse_mapping` je jediny parser).
      def class_mapping_key?(key)
        key.to_s.strip.downcase.start_with?(BuildPlan::HW_SET_CLASS_PREFIX)
      end

      # -> [kanonicky kluc, nil] | [nil, SK dovod]
      def parse_class_key(key)
        raw = key.to_s.strip
        return [nil, 'kľúč nie je triedny'] unless class_mapping_key?(raw)
        return [nil, 'triedny kľúč nemá výber na úrovni dielca'] if raw.include?('@')

        segs = raw.downcase[BuildPlan::HW_SET_CLASS_PREFIX.length..].to_s.split('|', -1).map(&:strip)
        unless [2, 3].include?(segs.length)
          return [nil, 'triedny kľúč musí mať typ kovania a spôsob otvárania']
        end

        gt, om, dc = segs
        return [nil, "neznámy typ kovania „#{gt}“"] unless BuildPlan::GENERIC_TYPES.include?(gt)
        return [nil, "neznámy spôsob otvárania „#{om}“"] unless OPENING_MODES.include?(om)

        if segs.length == 3
          return [nil, 'konštrukciu zásuvky má len výsuv'] unless gt == 'slide'
          return [nil, "neznáma konštrukcia zásuvky „#{dc}“"] unless DRAWER_CONSTRUCTIONS.include?(dc)
        end
        ["#{BuildPlan::HW_SET_CLASS_PREFIX}#{segs.join('|')}", nil]
      end

      # Typ kovania z LUBOVOLNEHO kluca mapovania (bezny, composite aj triedny)
      # alebo nil pri neplatnom tvare. Jedina cesta, ktorou sa typ z kluca cita.
      def mapping_key_type(key)
        if class_mapping_key?(key)
          canon, = parse_class_key(key)
          return nil if canon.nil?

          return canon[BuildPlan::HW_SET_CLASS_PREFIX.length..].to_s.split('|').first
        end
        parsed = BuildPlan.parse_hardware_set_key(key)
        parsed && parsed[0]
      end

      # Prazdna kniznica — jediny tvar, ktory sa vracia namiesto obsahu, ktory
      # sa NESMIE pouzit (audit BLOCKER 1).
      def blank_library
        { 'sets' => [], 'mapping' => {} }
      end

      # Nacita globalnu kniznicu { 'sets' => [], 'mapping' => {} }. Chybajuci
      # (alebo poskodeny bez zalohy) subor -> seed; NEKOMPATIBILNY subor ->
      # PRAZDNO (fallback nikdy nevrati nil). Seed-merge ako HardwareRules:
      # novsi SEED_VERSION doplni CHYBAJUCE set_id (bez prepisu pouzivatelskych
      # uprav) — plati LEN pre global; projektovy snapshot sa NIKDY nemeni sam.
      #
      # R-07 (review P1-1): `load` je BEZPECNY Z PRINCIPU — z nekompatibilnej
      # kniznice NIKDY nevydá obsah. Skorsi navrh mal na to samostatnu
      # `usable_library` a volajuci sa medzi nou a `load` museli rozhodovat
      # podla ZAPAMATANEHO stavu; stacilo raz siahnut na `load` a uz sa
      # pracovalo s orezanymi datami. Jedna cesta = jedna pravda.
      def load
        ensure_seeded
        lib, changed = read_library
        return lib unless changed
        persist_seed_merge!(lib)
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.load') if defined?(Engine)
        # Aj zlyhanie musi respektovat branu: seed nad NEKOMPATIBILNYM suborom
        # by ukazal cudzie defaulty (a prvy zapis by ich zvecnil).
        library_read_only? ? blank_library : seed_library
      end

      def seed_library
        { 'sets' => deep_copy(SEED_SETS), 'mapping' => SEED_MAPPING.dup }
      end

      # CISTE citanie + seed-merge BEZ zapisu -> [kniznica, changed].
      #
      # R-07 (audit FIX 3): brana sa vyhodnocuje nad PRAVE precitanym
      # dokumentom (verdikt a obsah tak pochadzaju z JEDNEHO stavu suboru) a to
      # PRED seed-mergom. Nad nekompatibilnou kniznicou sa seed NEDOPLNA — do
      # novsieho suboru by sme primiesali svoje default sety a migracie
      # mapovania, teda presne tu tichu zmenu, pred ktorou brana chrani.
      #
      # Review P1-1: vracia sa PRAZDNO, nie „parsovatelny obsah". Orezany obsah
      # bol jedom celej davky — kazdy volajuci `load` by ho dostal a rozhodoval
      # by sa uz podla neho (`ensure_project_state!` by ho zmrazil do .skp,
      # expanzia nacenila BEZ oranzoveho dovodu). Prazdno tie cesty zastavi
      # samo; SEED sa tu nesmie objavit tiez (cudzie defaulty by prvy zapis
      # zvecnil — rovnaka lekcia ako zlyhany zamok v R-08).
      def read_library
        doc = JsonFileStore.read(path, copy: false)
        # R-11: cez TU ISTU maticu — degradovana kniznica sa CITA normalne
        # (dokument pochadza zo zalohy a je platny); prazdno je vyhradne pre
        # `:read_only`. Zapisy zastavi az brana v `write`.
        read_only = apply_library_state(*assess_library(doc)) == :read_only
        return [blank_library, false] if read_only
        sets = doc.is_a?(Hash) ? normalize_sets(doc['sets']) : []
        mapping = doc.is_a?(Hash) ? normalize_mapping(doc['mapping'], sets) : {}
        return [seed_library, false] if sets.empty?
        merged, merged_map, changed = merge_seed(sets, mapping, doc['seed_version'].to_i)
        [{ 'sets' => merged, 'mapping' => merged_map }, changed]
      end

      # R-08 (audit 1d #2/#10): seed-merge je READ-MODIFY-WRITE. Pod zamkom sa
      # subor cita NANOVO (cache JsonFileStore ma 1 s okno) a merge sa
      # PREPOCITA — inak by sa zapisal odtlacok spred zamku a zmena druhej
      # instancie by zanikla. Ked medzitym seed doplnila uz ona, `changed` je
      # false a nezapisuje sa ani nelogujeme uspech. Zlyhany zamok/citanie =
      # vratime predzamkovy kandidat (kniznica sa NIKDY nezmeni na seed).
      def persist_seed_merge!(fallback)
        with_catalog_lock do
          JsonFileStore.reload!(path)
          fresh, changed = read_library
          if changed && write(fresh['sets'], fresh['mapping']) && defined?(Engine)
            Engine.log('hardware sets: globalna kniznica doplnena o nove default sety')
          end
          fresh
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.persist_seed_merge!') if defined?(Engine)
        fallback
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
      #   1) mapovanie je presne stara hodnota,
      #   2) STARY set je v kniznici v nezmenenom seed tvare,
      #   3) CIELOVY set je presne nas seed (GH #131 P2 — ked si ID medzitym
      #      obsadil vlastny set pouzivatela, migracia sa NEVYKONA; inak by sa
      #      nohy premapovali na cudziu, hoci aj inotypovu definiciu).
      def migrate_mapping(sets, mapping)
        by_id = {}
        sets.each { |s| by_id[s['set_id']] = s }
        seed_by_id = {}
        normalize_sets(SEED_SETS).each { |s| seed_by_id[s['set_id']] = s }
        out = mapping.dup
        MAPPING_MIGRATIONS.each do |gt, (from_id, to_id)|
          next unless out[gt] == from_id
          target = by_id[to_id]
          seed = seed_by_id[to_id]
          next unless target && seed && target == seed && target['generic_type'] == gt
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

      # R-08 (audit 1d #1): CHECK-BEFORE-LOCK by sa dal predbehnut — instancia
      # B zisti „subor chyba", zastavi sa, instancia A medzitym seedne a ulozi
      # REALNU zmenu, a B ju potom naslepo prepise seedom. Rychly check ostava
      # (hot cesta), ale ZAPIS ide az po DRUHOM checku POD zamkom.
      def ensure_seeded
        return if JsonFileStore.available?(path)
        with_catalog_lock do
          next true if JsonFileStore.available?(path)
          write(deep_copy(SEED_SETS), SEED_MAPPING.dup)
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.ensure_seeded') if defined?(Engine)
        false
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
        # R-08: samotny zapis bezi pod medziprocesovym zamkom. Zamok, ktory sa
        # nepodari vziat, vyhodi IOError — rescue nizsie z neho spravi FALSE,
        # takze volajuci sa o neuspechu dozvie (nikdy tichy uspech).
        with_catalog_lock do
          # R-07 (audit BLOCKER 2): CACHOVANE `:ok` NIE JE DOKAZ. Kym sa brana
          # vyhodnocovala len pri citani, druha instancia (novsi plugin) stihla
          # medzitym subor nahradit — a nas zapis by ho zhodil na tvar, ktoremu
          # rozumieme my. Marker aj tvar sa preto citaju CERSTVO Z DISKU POD
          # ZAMKOM pred KAZDYM zapisom; tato jedna brana kryje vsetky zapisove
          # cesty (`save_set!` · `delete_set!` · `set_global_mapping!` ·
          # seed-merge · `ensure_seeded`), lebo vsetky koncia tu.
          #
          # R-11 pouziva TU ISTU branu: `:degraded` (poskodeny primar + platna
          # `.bak`) zapis do suboru odmietne rovnako ako `:read_only` — inak by
          # sme primar prepisali obsahom odvodenym od STARSEJ zalohy. Citanie
          # a pouzitie obsahu degradovana kniznica dovoluje (viz `read_library`).
          JsonFileStore.reload!(path)
          before = @lib_state
          if [:read_only, :degraded].include?(apply_library_state(*assess_library(read_library_doc)))
            # Log LEN pri ZMENE stavu (vzor `apply_library_state`): seed-merge
            # sa nad degradovanou kniznicou pokusi zapisat pri KAZDOM `load`,
            # takze bezpodmienecny zapis by zaplavil Ruby konzolu. Pouzivatel
            # o odmietnuti vie z UI hlasky, nie z logu.
            if before != @lib_state && defined?(Engine)
              Engine.log("hardware sets: zapis kniznice odmietnuty — #{library_state_reason}")
            end
            next false
          end
          # R-07 (bod 7): marker sa stampuje podla OBSAHU (`snapshot_std`), nie
          # konstantou. `std: 1` nad setmi s pasmami klamal — starsi plugin taky
          # subor pustil dnu a clena s pasmami ticho zahodil. Historicky subor
          # so std 1 a novym obsahom sa marker povysi PRIRODZENE prvym
          # legitimnym zapisom; bez mutacie sa subor nedotyka.
          JsonFileStore.write(path, { 'std' => snapshot_std(map, norm),
                                      'seed_version' => SEED_VERSION,
                                      'sets' => norm, 'mapping' => map })
        end
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

      # R-08 (audit 1d #4): KOHERENTNA dvojica pre payload okna. Kym sa
      # kniznica citala jednym volanim a revizia druhym, cudzi zapis medzi
      # nimi vyrobil payload so STARYMI setmi a NOVOU reviziou — formular
      # potom presiel guardom a prepisal cudziu zmenu, ktoru pouzivatel
      # nikdy nevidel. Oboje sa preto berie pod JEDNYM zamkom nad cerstvym
      # suborom. Zlyhany zamok = revizia sa berie PRED kniznicou: neskorsi
      # nesulad tak vyrobi nanajvys FALOSNY konflikt (formular sa nacita
      # nanovo), nikdy tichy prepis.
      def load_with_revision
        with_catalog_lock do
          JsonFileStore.reload!(path)
          lib = load
          [lib, revision]
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.load_with_revision') if defined?(Engine)
        rev = revision
        [load, rev]
      end

      # Ulozi/nahradi JEDEN set v globalnej kniznici (D1b editor). Identita =
      # set_id; revision = baseline z casu nacitania okna (cudzia zmena
      # medzitym = :conflict, okno sa obnovi). generic_type existujuceho setu
      # sa NEMENI (mapovania by ticho zmenili vyznam). create: true = NOVY set
      # nesmie trafit existujucu identitu (GH #127 P2 — slug z nazvu moze
      # kolidovat a "Novy set" by ticho prepisal globalnu definiciu).
      #
      # R-08: revizia sa porovnava a kniznica cita AZ POD ZAMKOM nad cerstvym
      # suborom. Kym check sedel MIMO zamku, druha instancia stihla medzi
      # kontrolou a zapisom ulozit svoju zmenu a nas zapis ju zmazal (guard
      # pritom hlasil uspech). Zlyhany zamok konci ako `:write_failed`.
      # KOV-B1: vysledok je TROJICA `[status, info, errors]` — treti prvok su
      # STRUKTUROVANE chyby (`{row, field, msg}`) pre editor setu (B3). Dnesne
      # dvojprvkove destruovanie u volajucich (`status, info = save_set!(…)`)
      # tym NIE JE dotknute — Ruby prebytocny prvok zahodi.
      #
      # KOV-B1: validacia bezi AZ POD ZAMKOM, lebo potrebuje ULOZENY set
      # (merge klasifikacie, viz `merge_class_keys`) a ten sa smie citat len
      # cerstvo pod zamkom (R-08).
      def save_set!(set_def, revision: nil, create: false)
        raw = set_def.is_a?(Hash) ? stringify(set_def) : nil
        return invalid_set([set_err(nil, 'set musí byť objekt')]) if raw.nil?

        with_catalog_lock do
          JsonFileStore.reload!(path)
          # R-07: brana PRED reviziou — nad nekompatibilnou kniznicou nie je
          # o com hovorit (a `load` z nej nic nevyda, takze bez tejto vetvy by
          # sa mutacia rozhodovala nad PRAZDNOM a hlasila nezmysly).
          # R-11: aj DEGRADOVANA kniznica (poskodeny primar + platna zaloha)
          # odmieta zapisy do suboru — dovod ide do hlasky rovnako ako pri R-07.
          next [:write_failed, library_state_reason] if library_write_blocked?
          next [:conflict, nil] if revision && revision != self.revision
          lib = load
          sets = lib['sets']
          sid = raw['set_id'].to_s.strip
          idx = sid.empty? ? nil : sets.index { |s| s['set_id'] == sid }
          merged = idx && !create ? merge_class_keys(raw, sets[idx]) : raw
          norm, errors = validate_set_detailed(merged)
          next invalid_set(errors) if norm.nil?

          refusal = taxonomy_refusal(norm)
          next refusal if refusal

          next [:exists, norm['set_id']] if create && idx
          if idx
            if sets[idx]['generic_type'] != norm['generic_type']
              msg = 'typ kovania existujúceho setu sa nemení — vytvor nový set'
              next [:invalid, msg, [set_err('generic_type', msg)]]
            end
            sets[idx] = norm
          else
            sets << norm
          end
          next [:write_failed, nil] unless write(sets, lib['mapping'])
          [:ok, norm]
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.save_set!') if defined?(Engine)
        [:write_failed, nil]
      end

      def invalid_set(errors)
        first = Array(errors).first
        [:invalid, (first ? first['msg'] : 'set sa nedá uložiť — skontroluj kódy a členov'),
         Array(errors)]
      end

      # KOV-B1 (R5) — MERGE KLASIFIKACIE pri uprave EXISTUJUCEHO setu.
      #
      # Editor setu posiela dnes LEN styri kluce (`set_id`, `name`,
      # `generic_type`, `members`). Bez tohto merge by KAZDA uprava clena TICHO
      # ZHODILA klasifikaciu ulozeneho setu — teda presne ta trieda tichej
      # straty, ktoru cela davka rieši (a je to jedna z mutacii sady).
      #   * kluc, ktory vo vstupe VOBEC NIE JE  -> preberie sa z ULOZENEHO setu,
      #   * kluc pritomny s `nil`/`''` (a `active: true`) -> VEDOME VYMAZANIE.
      # Az MERGED tvar ide do validacie, takze all-or-nothing pravidlo plati
      # nad tym, co sa naozaj ulozi.
      def merge_class_keys(raw, stored)
        out = raw.dup
        return out unless stored.is_a?(Hash)

        (CLASS_KEYS + ['active']).each do |k|
          next if out.key?(k)

          out[k] = stored[k] if stored.key?(k)
        end
        out
      end

      # Patri klasifikacia setu do TAXONOMIE? Kontrola bezi VYHRADNE tu (zapis
      # do GLOBALNEJ kniznice). `validate_set` ostava CISTA — pouziva ju aj
      # zapis projektoveho snapshotu a citanie sablon, ktore cestuju medzi PC
      # s INOU taxonomiou; vynutit ju tam by znamenalo, ze zakazku z ineho
      # pocitaca sa neda otvorit.
      # -> nil (v poriadku) | hotova odpoved pre volajuceho
      # POZOR: pri uspechu MENI `norm` — dosadi KANONICKE mena z taxonomie.
      # Kontrola je case-insensitive (aby „hettich" nasiel „Hettich"), takze bez
      # tohto prepisu by sa do kniznice ulozil zapis VOLAJUCEHO a vedla
      # kanonickeho „Hettich" by vyrastol „hettich" — invariant jedineho mena,
      # na ktorom stoji zoskupenie katalogu (B2) aj filtre (D), by padol.
      def taxonomy_refusal(norm)
        return nil unless classified?(norm)
        # FAIL-CLOSED: nad NEKOMPATIBILNOU taxonomiou sa klasifikovany set
        # ulozit NEDA — `load` z nej nic nevyda, takze kontrola by hlasila
        # „vyrobca nie je v zozname" namiesto skutocneho dovodu. Legacy set
        # prejde dalej (taxonomia sa ho netyka). Degradovana taxonomia sa
        # CITAT smie, takze kontrola nad nou bezi normalne.
        return [:write_failed, HardwareTaxonomy.state_reason] if HardwareTaxonomy.read_only?

        canon_man, canon_ser, errs =
          HardwareTaxonomy.resolve_classification(norm['manufacturer'], norm['series'])
        unless errs.empty?
          struct = errs.map { |e| set_err(e['field'], e['msg']) }
          return [:invalid, struct.first['msg'], struct]
        end
        # Kluce sa LEN prepisuju (nikdy nepridavaju): `series` je volitelna,
        # takze setu bez rady sa kluc doplnit nesmie. Poradie klucov sa
        # prepisom existujuceho kluca v Ruby nemeni (SET_KEY_ORDER drzi).
        norm['manufacturer'] = canon_man if canon_man
        norm['series'] = canon_ser if canon_ser && norm.key?('series')
        nil
      end

      # Zmaze set z globalnej kniznice; mapovanie globalu sa ocisti (write ho
      # filtruje cez ids). Projektove snapshoty drzia vlastne kopie — historia
      # zakaziek sa mazanim kniznice NEMENI (rovnaka filozofia ako katalog).
      def delete_set!(set_id, revision: nil)
        sid = set_id.to_s.strip
        return [:not_found, nil] if sid.empty?
        with_catalog_lock do
          JsonFileStore.reload!(path)
          next [:write_failed, library_state_reason] if library_write_blocked? # R-07 + R-11
          next [:conflict, nil] if revision && revision != self.revision
          lib = load
          sets = lib['sets'].reject { |s| s['set_id'] == sid }
          next [:not_found, nil] if sets.length == lib['sets'].length
          next [:write_failed, nil] unless write(sets, lib['mapping'])
          [:ok, sid]
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.delete_set!') if defined?(Engine)
        [:write_failed, nil]
      end

      # Nastavi mapovanie GLOBALNEJ kniznice (default novych projektov).
      # value = set_id String | selector Hash | nil/'' (odmapovanie).
      #
      # R-08 (audit 1d #5): cerstve citanie pod zamkom zachrani zmeny INYCH
      # klucov, ale dve otvorene okna menajuce TEN ISTY generic_type by si
      # ticho prepisali predvolbu. Okno preto posiela reviziu kniznice (tu
      # istu, ktoru uz pouzivaju save/delete) a nesulad konci `:conflict`.
      # Vrati :ok | :conflict | false (neplatny typ/hodnota, zlyhany zapis).
      def set_global_mapping!(generic_type, value, revision: nil)
        gt = generic_type.to_s.strip
        return false unless BuildPlan::GENERIC_TYPES.include?(gt)
        with_catalog_lock do
          JsonFileStore.reload!(path)
          next false if library_write_blocked? # R-07 + R-11
          next :conflict if revision && revision != self.revision
          lib = load
          mapping = lib['mapping']
          if value.nil? || (value.is_a?(String) && value.strip.empty?)
            mapping.delete(gt)
          else
            status, norm, refs = parse_mapping_value(value)
            next false unless status == :ok
            next false unless refs.all? do |sid|
              lib['sets'].any? { |s| s['set_id'] == sid && s['generic_type'] == gt }
            end
            mapping[gt] = norm
          end
          write(lib['sets'], mapping) ? :ok : false
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.set_global_mapping!') if defined?(Engine)
        false
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
            # H1b: sekcia nesie AJ dovod (stlpec „kód" je tu popis problemu —
            # hlavicka sekcie ho pomenuva). Bez neho sa z CSV nedalo zistit,
            # ktore pasmo/rad chyba a co doplnit.
            # D-90: stlpec „MJ" nesie v tejto sekcii ROZMER polozky (rez profilu) —
            # bez neho by sa z CSV nedala objednat dlzka tyce.
            out << ['NEMAPOVANÉ (bez kódov — nenacenené)', 'dôvod', 'kde', 'počet', 'rozmer', '', '']
            unmapped.each do |u|
              out << [u['generic_type'].to_s, unmapped_reason_sk(u),
                      "#{u['cabinet_id']} #{u['owner_part_key']}".strip,
                      u['quantity'].to_i, u['params_label'].to_s, '', '']
            end
          end
        end
      end

      # H1b (audit FIX 9 UI): KRATKY slovensky dovod nemapovanej polozky —
      # jedna autorita pre CSV aj pre tab Kovanie (payload nesie 'reason_sk',
      # JS uz ziadny vlastny preklad nema). Dlhsie vety s navodom „co doplnit"
      # ostavaju vrstvou semafora (Validation.check_hardware_expansion).
      def unmapped_reason_sk(u)
        return '' unless u.is_a?(Hash)
        sid = u['set_id'].to_s
        case u['reason'].to_s
        when 'nl_missing'
          # GH #132 P2: NL sa NEZAOKRUHLUJE — frakcna dlzka (419,6) je vedome
          # NEMAPOVANA (rad ma presne celociselne kluce); „NL 420" by poslalo
          # doplnit kod, ktory uz existuje, a skryla by sa skutocna pricina.
          nl = u['nominal_length']
          nl.is_a?(Numeric) ? "set „#{sid}“ nemá kód pre dĺžku NL #{fmt_mm(nl)}" \
                            : "dĺžka výsuvu nie je známa — set „#{sid}“ nemá čo vybrať"
        when 'param_band_missing'
          name = param_label(u['param'])
          v = u['value']
          who = member_txt(u)
          v.is_a?(Numeric) ? "#{name} #{fmt_mm(v)} mm je mimo pásiem setu „#{sid}“#{who}" \
                           : "#{name} nie je známa — set „#{sid}“ nemá čo vybrať#{who}"
        when 'selector_unresolved'
          name = param_label(u['param'])
          v = u['value']
          v.is_a?(Numeric) ? "#{name} #{fmt_mm(v)} mm nespadá do žiadneho pásma predvoľby" \
                           : "#{name} nie je známa — predvoľba ju potrebuje"
        when 'set_missing'
          "set „#{sid}“ v projekte chýba"
        when 'set_type_mismatch'
          "set „#{sid}“ v projekte je iného typu kovania"
        when 'length_unsupported'
          # R-06: ROZMER patri do textu — bez neho by z hlasky nebolo vidiet,
          # aku dlzku profilu treba objednat rucne. Zdroj rozmeru je jediny
          # (params_label = „rez 597 mm"), nikdy sa tu neformatuje nanovo.
          cut = u['params_label'].to_s.strip
          base = "set „#{sid}“ počíta kusy, ale položka sa reže na dĺžku"
          base += " (#{cut})" unless cut.empty?
          "#{base} — dĺžkové kovanie sa zatiaľ do setu mapovať nedá"
        when 'library_incompatible'
          # R-07: projekt este nema vlastne predvolby a globalna kniznica sa
          # POUZIT nesmie — radsej NIC nez nakup z orezanych dat.
          'knižnica setov kovania sa nedá bezpečne prečítať a projekt vlastné ' \
            'predvoľby ešte nemá — nemapuje sa nič'
        else
          'typ nemá priradený set'
        end
      end

      # „ (člen 2)" / „ (noha)" — identita clena setu (H1a nesie index aj label).
      def member_txt(u)
        label = u['member_label'].to_s.strip
        return " (#{label})" unless label.empty?
        return '' unless u.key?('member_index')
        " (člen #{u['member_index'].to_i + 1})"
      end

      # 150.0 -> „150", 17.5 -> „17,5" (SK desatinna ciarka).
      # GH #132 P2: hodnota sa NEZAOKRUHLUJE — text ma ukazat presne to, co
      # polozka nesie (419,6 nie je 420; 120,25 nie je 120,3), inak by hlaska
      # posielala doplnit pasmo/kod, ktory uz existuje.
      def fmt_mm(v)
        f = v.to_f
        return format('%d', f.round) if (f - f.round).abs < 1e-9
        f.to_s.tr('.', ',')
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
        # GH #131 P2: std je LAZY marker tvarov — 1 = len legacy, 2 = snapshot
        # nesie pasma/selector. Neznamy (novsi) std = :invalid, NIKDY ciastocne
        # citanie.
        return [:invalid, nil] if doc.key?('std') && !STD_SUPPORTED.include?(doc['std'].to_i)
        sets_map = doc['sets'].is_a?(Hash) ? doc['sets'] : nil
        mapping  = doc['mapping'].is_a?(Hash) ? doc['mapping'] : nil
        return [:invalid, nil] if sets_map.nil? || mapping.nil?
        # R-07 (audit FIX 4): pocty setov nestacia — set sa da precitat aj
        # vtedy, ked sa z neho stratil CLEN (pole clena, cely clen, nove pole
        # novsej verzie). Kontroluje sa preto (a) whitelist znamych klucov
        # a (b) POCET CLENOV per set. Detektor je TEN ISTY, ktory pouziva
        # brana globalnej kniznice — snapshot a kniznica sa nesmu rozist.
        return [:invalid, nil] if sets_map.each_value.any? { |s| incompatible_set?(s) }
        sets = normalize_sets(sets_map.values)
        return [:invalid, nil] if sets.length != sets_map.length
        return [:invalid, nil] if members_lost?(sets_map.values, sets)
        # KOV-B1: a (c) KLASIFIKACIA — snapshot z novsej verzie by inak prisiel
        # o `use_type`/`active` a `set_project_mapping!` by stratu zvecnil.
        return [:invalid, nil] if classification_lost?(sets_map.values, sets)
        by_id = {}
        sets.each { |s| by_id[s['set_id']] = s }
        norm_map = normalize_mapping(mapping, sets)
        return [:invalid, nil] if norm_map.length != mapping.length
        [:ok, { 'mapping' => norm_map, 'sets' => by_id }]
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.project_state_status') if defined?(Engine)
        [:invalid, nil]
      end

      # R-07: zahodila citacia normalizacia CAST setu? Porovnava RAW definicie
      # (pole hashov) s vysledkom `normalize_sets`. Pouziva ho kniznica aj
      # projektovy snapshot — obe cesty musia stratu vidiet rovnako.
      #
      # Co sa porovnava a preco prave to:
      #   * POCET CLENOV — clen s hodnotou, ktorej nerozumieme (`per: 'length'`
      #     novsej verzie, pokazene pasma), z citania ticho vypadne;
      #   * POCET POLOZIEK RADU `code_by_nl` — necislny kluc radu sa v citacej
      #     ceste zahadzuje po JEDNOM (member prezije s kratsim radom), takze
      #     samotny pocet clenov to nechyti (review P3-7).
      def members_lost?(raw_sets, normalized)
        raw = {}
        Array(raw_sets).each { |s| raw[s['set_id'].to_s] = s if s.is_a?(Hash) }
        normalized.any? do |norm|
          src = raw[norm['set_id'].to_s]
          next true if src.nil?
          rm = Array(src['members'])
          nm = Array(norm['members'])
          next true if rm.length != nm.length
          rm.each_with_index.any? { |m, i| nl_entries(m) != nl_entries(nm[i]) }
        end
      end

      # KOV-B1 — 4. VRSTVA DETEKTORA STRATY (klasifikacia a `active`).
      #
      # Prve tri vrstvy (whitelist klucov, pocet setov/clenov, pocet poloziek
      # radu) klasifikaciu nechytia: `use_type` je ZNAMY kluc so SKALARNOU
      # hodnotou, takze whitelist pusti aj hodnotu z novsej verzie
      # (`use_type: 'sliding'`) — a tolerantne citanie ju ticho zahodi. Prvy
      # zapis by stratu zvecnil, presne ako pri `per: 'length'` v R-07 P1-2.
      #
      # Porovnava sa RAW definicia s vysledkom `normalize_sets`:
      #   * raw ma neprazdny KTORYKOLVEK klasifikacny kluc, ale normalizovany
      #     set klasifikaciu NEMA -> STRATA;
      #   * raw ma `active: false`, ale normalizovany priznak nema -> STRATA.
      # Pouzivaju ju VSETKY TRI brany: `assess_library_doc` (globalna kniznica),
      # `project_state_status` (snapshot v .skp) a `assess_set_defs` (sablona) —
      # tri cesty k tym istym datam sa nesmu rozist.
      def classification_lost?(raw_sets, normalized)
        raw = {}
        Array(raw_sets).each { |s| raw[s['set_id'].to_s.strip] = s if s.is_a?(Hash) }
        Array(normalized).any? do |norm|
          src = raw[norm['set_id'].to_s]
          # Chybajuci zdroj riesi `members_lost?` — tu by to bola druha hlaska
          # o tej istej veci.
          next false if src.nil?
          next true if classified?(src) && CLASS_KEYS.none? { |k| norm.key?(k) }

          src['active'] == false && norm['active'] != false
        end
      end

      def nl_entries(member)
        return 0 unless member.is_a?(Hash)
        nl = member['code_by_nl']
        return 0 if nl.nil?
        # Rad, ktory NIE JE mapa, je NEZNAMY TVAR — nie „nula poloziek"
        # (review P1). Sentinel sa s normalizovanym clenom nikdy nezhoduje,
        # takze strata vyjde najavo aj tu, nielen vo whitelistoch.
        return -1 unless nl.is_a?(Hash)
        nl.length
      end

      # Snapshot projektu alebo nil (missing AJ invalid — na rozlisenie sluzi
      # project_state_status; citacie cesty bez modelu nemaju co mapovat).
      def project_state(model)
        status, state = project_state_status(model)
        status == :ok ? state : nil
      end

      # Globalne predvolby ako projektovy stav (mapping + kopie namapovanych
      # setov) — default noveho snapshotu (ensure, prva zmena, vedoma obnova).
      #
      # R-07 (audit BLOCKER 1): TOTO je hlavna cesta, ktorou sa globalne
      # definicie KOPIRUJU DO MODELU. Z nekompatibilnej kniznice sa nekopiruje
      # NIC — zmrazil by sa orezany stav a .skp by uz stratu niesol navzdy.
      # Vrati NIL a volajuci zapis odmietne (stavba bezi dalej, len bez
      # snapshotu: expanzia to prizna ORANGE).
      #
      # Review P1-1: poradie je zavazne — najprv `load` (ten branu vyhodnoti
      # nad cerstvym dokumentom), az POTOM rozhodnutie. Opacne poradie citalo
      # ZAPAMATANY verdikt a nad medzitym vymenenym suborom vratilo orezany
      # stav, ktory sa zmrazil do .skp.
      def global_default_state
        lib = load
        return nil if library_read_only?

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
        return nil if state.nil? # R-07: nekompatibilna kniznica sa nezmrazi
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
        doc = { 'std' => snapshot_std(mapping, norm_sets), 'mapping' => mapping, 'sets' => by_id }
        model.set_attribute(Store::DICT, MODEL_KEY, doc.to_json)
        true
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.write_project_state') if defined?(Engine)
        false
      end

      # GH #131 P2: marker tvarov podla OBSAHU snapshotu. std 2 dostane len
      # snapshot, ktory bez novych tvarov necita spravne — ostatne ostavaju
      # std 1 (spatna citatelnost starsimi verziami sa zbytocne neblokuje).
      # R-07: TU ISTU logiku pouziva aj zapis GLOBALNEJ kniznice (`write`) —
      # marker musi hovorit o obsahu rovnako v .skp aj v %APPDATA%, inak
      # jedna z dvoch ciest starsiemu pluginu klame.
      # KOV-B1: najvyssi marker vyhrava. std 3 dostane obsah, ktoremu by starsi
      # plugin nerozumel UZ NA UROVNI SETU alebo KLUCA MAPOVANIA — teda set
      # s KTORYMKOLVEK klucom mimo `LEGACY_SET_KEYS` (kazde klasifikacne pole aj
      # `active` samostatne) alebo mapovanie s TRIEDNYM klucom. Cisto legacy
      # obsah ostava na svojom povodnom std (1/2) — spatna citatelnost sa
      # zbytocne neblokuje.
      def snapshot_std(mapping, sets)
        classified =
          Array(sets).any? do |s|
            s.is_a?(Hash) && !(s.keys.map(&:to_s) - LEGACY_SET_KEYS).empty?
          end ||
          (mapping.is_a?(Hash) && mapping.each_key.any? { |k| class_mapping_key?(k) })
        return STD_CLASSIFIED if classified

        new_forms =
          Array(sets).any? do |s|
            Array(s['members']).any? { |m| m.is_a?(Hash) && m['param_bands'].is_a?(Hash) }
          end ||
          (mapping.is_a?(Hash) && mapping.each_value.any? { |v| v.is_a?(Hash) })
        new_forms ? STD_PARAM_FORMS : STD
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
        return false if state.nil? # R-07: bez snapshotu a s nekompatibilnou kniznicou niet z coho zmrazit
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
        return false if state.nil? # R-07: nekompatibilna kniznica sa nekopiruje do modelu
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
        out = {}
        normalize_sets(set_defs_list(set_defs)).each { |d| out[d['set_id']] = d }
        out
      end

      # Definicie setov v lubovolnom prijimanom tvare -> pole surovych definicii.
      # (Jedna definicia · pole · mapa set_id => definicia.)
      def set_defs_list(set_defs)
        case set_defs
        when nil then []
        when Array then set_defs
        when Hash then set_defs.key?('members') || set_defs.key?(:members) ? [set_defs] : set_defs.values
        else [set_defs]
        end
      end

      # === KOV-B1: BEZSTRATOVA BRANA DEFINICII SETOV V SABLONE ================
      # (audit #17 BLOCKER 1)
      #
      # `hardware_set_defs` v sablone islo doteraz LEN cez tolerantny
      # `normalize_sets` — teda cez cestu, ktora neznamy obsah TICHO ORezE. Kym
      # sety nemali co stratit, nevadilo to; od KOV-B1 by starsi plugin zmrazil
      # do .skp set BEZ klasifikacie (a novsi tvar by uz nikto neobnovil).
      # Sablona je datovy subor MIMO modelu — moze byt rucne upravena alebo
      # z novsej verzie — takze sa cita BEZSTRATOVO ALEBO VOBEC, rovnako ako
      # mapovanie v `read_template_mapping`.
      #
      # Vola sa PRED akoukolvek operaciou a PRED akymkolvek zapisom do modelu
      # (vklad `Panel.take_insert_hardware!`, pouzitie `TemplatesDialog.handle_apply`),
      # takze odmietnutie znamena „model sa nezmenil ani o krok Spat".
      # Detektor je TEN ISTY ako v kniznici a v snapshote (whitelist klucov +
      # round-trip + strata klenov + strata klasifikacie).
      #
      # CISTA funkcia (ziadne IO). Legacy sablona bez definicii prejde.
      # -> [:ok, { set_id => norm }] | [:lossy, [nazvy neprecitatelnych definicii]]
      def assess_set_defs(defs)
        return [:ok, {}] if defs.nil?
        return [:lossy, ['hardware_set_defs']] unless defs.is_a?(Array) || defs.is_a?(Hash)

        out = {}
        lost = []
        set_defs_list(defs).each_with_index do |raw, i|
          label = raw.is_a?(Hash) ? (raw['set_id'] || raw[:set_id]).to_s.strip : ''
          label = "definícia #{i + 1}" if label.empty?
          d = raw.is_a?(Hash) ? stringify(raw) : nil
          if d.nil? || incompatible_set?(d)
            lost << label
            next
          end
          norm = without_skip_log { normalize_sets([d]) }
          if norm.length != 1 || members_lost?([d], norm) || classification_lost?([d], norm)
            lost << label
            next
          end
          out[norm.first['set_id']] = norm.first
        end
        lost.empty? ? [:ok, out] : [:lossy, lost.uniq]
      rescue StandardError => e
        # Fail-closed ako `assess_library_doc`: nezrozumitelny obsah je
        # ODMIETNUTIE, nikdy vynimka, ktora by zhodila vkladanie skrinky.
        Engine.log_error(e, 'HardwareSets.assess_set_defs') if defined?(Engine)
        [:lossy, ['hardware_set_defs']]
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
        # R-07 (BLOCKER 1): fallback na GLOBAL je kopirovanie kniznicnej
        # definicie do modelu (volajuci ju vzapati zmrazi do snapshotu) —
        # z nekompatibilnej kniznice `load` nic nevyda, takze volajuci skonci
        # „set sa nenasiel" a hlasku doplni podla `library_read_only?`.
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
      # -> [:none|:updated|:blocked, added_set_ids, added_mapping_keys]
      def merge_project_sets_seed!(model)
        status, state = project_state_status(model)
        return [:none, [], []] unless status == :ok # bez snapshotu berie projekt global sam
        # R-07 (BLOCKER 1): doplnanie je kopirovanie globalnych definicii do
        # modelu — z nekompatibilnej kniznice sa NEROBI. Vlastny vysledok
        # (`:blocked`), aby okno vedelo povedat PRECO (nie „uz mas vsetko").
        # Poradie ako v `global_default_state` (P1-1): najprv citanie, potom
        # rozhodnutie nad stavom, ktory z neho vysiel.
        lib = load
        return [:blocked, [], []] if library_read_only?
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

      # --- sety v SABLONE korpusu (H2, D-76) -----------------------------------

      # Definicie setov na ULOZENIE do sablony: pre kazde set_id, na ktore
      # mapovanie sablony ukazuje (priamo AJ cez pasma selectora), vyberie
      # definiciu TOU ISTOU precedenciou, akou ju pouziva skrinka — projektovy
      # snapshot pred globalnou kniznicou (H1a BLOCKER 4). Mapovanie skrinky sa
      # resolveru odovzda ako cabinet override, takze sa zmrazi presne to, co
      # skrinka realne nakupuje (aj ked projekt ma namapovane iny set).
      # Set, ktory sa nedá rozlozit, sablona nenesie — pri aplikacii skonci
      # ORANGE (set_missing), NIKDY tichy iny hardver.
      # GH #133 P2: pri POSKODENOM snapshote (:invalid) vrati nil — resolver by
      # spadol na globalnu kniznicu a sablona by niesla kody, ktore zdrojovy
      # model NEPOUZIVA (expanzia pri :invalid vedome nemapuje nic). Volajuci
      # vtedy ulozi sablonu BEZ kovania a nahlasi to.
      # R-07 (review P2-4, zuzene v P2-1): nil vracia PRESNE V DVOCH stavoch,
      # kde sa definicie nedaju dobrat ZO SPRAVNEHO ZDROJA —
      #   * :invalid snapshot (GH #133 P2, viz vyssie),
      #   * NEKOMPATIBILNA globalna kniznica: `resolve_set_def` z nej nic
      #     nevyda, takze by sablona niesla MAPOVANIE BEZ DEFINICII a pri
      #     aplikacii by ticho prepisala vyber cieloveho korpusu.
      # CHYBAJUCA JEDNOTLIVA referencia nad ZDRAVYMI zdrojmi nil NIE JE (P2-1):
      # mapovanie skrinky moze ukazovat na set, ktory uz v projekte ani
      # v kniznici nie je (kopia z ineho modelu, medzitym zmazany set) — vtedy
      # sa ta jedna referencia vynecha, sablona ju nenesie a pri aplikacii
      # skonci ORANGE `set_missing`. Zahodit kvoli nej CELE kovanie sablony by
      # bola strata bez dovodu, a hlaska volajuceho by navyse klamala („sety
      # projektu su poskodene" nad zdravym projektom).
      def template_set_defs(model, mapping)
        map = mapping.is_a?(Hash) ? mapping : {}
        refs = referenced_set_ids(map)
        return {} if refs.empty?
        return nil if project_state_status(model)[0] == :invalid
        return nil if library_read_only?
        as_override = { 'template' => map }
        out = {}
        refs.each do |sid|
          d = resolve_set_def(model, sid, cabinet_overrides: as_override)
          out[sid] = deep_copy(d) if d
        end
        out
      end

      # CITANIE mapovania zo SABLONY (GH #133 P2). Sablona je datovy subor MIMO
      # modelu — moze byt rucne upravena alebo z novsej verzie pluginu. Ked
      # normalizacia cokolvek ZAHODI (neznamy generic_type novsej verzie,
      # composite kluc, neplatna hodnota), zvysok NESMIE platit za „vedomy vyber
      # pouzivatela": ocesana (aj prazdna) mapa by pri aplikacii ticho ZMAZALA
      # platny vyber setov cieloveho korpusu. Vzor guard_unknown_hardware!:
      # radsej jasne odmietnut nez ticho stratit kovanie.
      # -> [:ok, mapa] | [:lossy, [zahodene kluce]]
      def read_template_mapping(raw)
        return [:ok, {}] if raw.nil?
        return [:lossy, ['hardware_sets']] unless raw.is_a?(Hash)

        map = normalize_mapping(raw, nil, allow_owner: false)
        # Strata sa porovnava v KANONICKOM tvare kluca, nie v surovom zapise:
        # triedny kluc ` CLASS: Hinge | Classic ` je platny a parser z neho
        # spravi `class:hinge|classic`, takze hladanie SUROVEHO zapisu v mape by
        # ho oznacilo za stratu a sablonu by FALOSNE odmietlo (Codex #284 P2-B).
        lost = raw.keys.map(&:to_s).reject { |k| (c = canonical_mapping_key(k)) && map.key?(c) }
        lost.empty? ? [:ok, map] : [:lossy, lost]
      end

      # Kanonicky tvar LUBOVOLNEHO kluca mapovania (bezny, composite aj triedny)
      # alebo nil, ked kluc nema platny tvar. Jedina cesta, ktorou sa kluc
      # porovnava s vysledkom `parse_mapping`.
      def canonical_mapping_key(key)
        raw = key.to_s.strip
        return parse_class_key(raw)[0] if class_mapping_key?(raw)

        raw
      end

      # set_id => generic_type podla KLUCA mapovania (composite kluc nesie typ
      # rovnako). Ten isty set pod dvoma roznymi typmi = konflikt -> nil
      # (definicia sa nezmrazi, mapovanie skonci ORANGE).
      def mapping_types_by_set(mapping)
        out = {}
        (mapping.is_a?(Hash) ? mapping : {}).each do |key, value|
          # KOV-B1: typ nesie AJ triedny kluc (prvy segment) — inak by sa
          # definicia setu, na ktory ukazuje, do sablony nezmrazila.
          gt = mapping_key_type(key)
          next if gt.nil?
          value_set_ids(value).each do |sid|
            out[sid] = out.key?(sid) && out[sid] != gt ? nil : gt
          end
        end
        out
      end

      # Kanonicke porovnanie definicii setu (obe strany prejdu normalizaciou —
      # rozdiel v poradi klucov ci v legacy tvare NIE JE rozdiel v obsahu).
      def same_set_def?(a, b)
        na = normalize_sets([a]).first
        nb = normalize_sets([b]).first
        return false if na.nil? || nb.nil?
        na == nb
      end

      # Zmrazi definicie setov zo SABLONY do projektoveho snapshotu. VOLAT LEN
      # vnutri otvorenej operacie (rebuild_many blok / build blok) — zapis
      # definicii a stavba skrinky su JEDNO undo (audit BLOCKER 2).
      #   mapping = mapovanie, ktore skrinka nakoniec dostane
      #   defs    = { set_id => definicia } zo sablony (hardware_set_defs)
      # Kolizie (audit BLOCKER 1 + FIX 5):
      #   set v projekte NIE JE         -> zapise sa definicia zo sablony
      #   je s ROVNAKOU definiciou      -> nic
      #   je s INOU definiciou          -> PROJEKT VYHRAVA (prepis by zmenil uz
      #                                    postavene skrinky zakazky), volajuci
      #                                    to ohlasi v statuse
      #   generic_type nesedi s klucom  -> definicia sa NEZMRAZI; mapovanie sa
      #                                    aplikuje a expanzia skonci ORANGE
      # -> { 'status' => :ok | :invalid | :blocked | :failed, 'added' => [], 'kept' => [],
      #      'type_mismatch' => [], 'missing' => [] }
      def freeze_template_sets!(model, mapping, defs)
        res = { 'status' => :ok, 'added' => [], 'kept' => [], 'type_mismatch' => [], 'missing' => [] }
        wanted = mapping_types_by_set(mapping)
        return res if wanted.empty?
        status, state = project_state_status(model)
        return res.merge('status' => :invalid) if status == :invalid
        # Bez snapshotu zmrazi prvy zapis najprv globalne predvolby (GH #127 P1)
        # — porovnavame teda proti TOMU, co v projekte naozaj vznikne.
        state ||= global_default_state
        # R-07 (review P2-4): bez snapshotu a s nekompatibilnou kniznicou
        # nevieme povedat, co v projekte vznikne. Je to VLASTNY stav `:blocked`,
        # nie `:failed` — `:failed` znamena „zapis zlyhal" a volajuci ho meni na
        # VYNIMKU, ktora by zhodila cele vkladanie skrinky. To by odporovalo
        # kontraktu „stavba bezi dalej, len bez snapshotu" (cabinet_builder).
        return res.merge('status' => :blocked) if state.nil?
        have = state['sets'].is_a?(Hash) ? state['sets'] : {}
        pool = collect_set_defs(defs)
        to_add = {}
        wanted.each do |sid, gt|
          d = pool[sid]
          if d.nil?
            res['missing'] << sid unless have.key?(sid)
          elsif gt.nil? || d['generic_type'] != gt
            res['type_mismatch'] << sid
          elsif have[sid].nil?
            to_add[sid] = d
          elsif !same_set_def?(have[sid], d)
            res['kept'] << sid
          end
        end
        # Ked nie je co pridat, snapshot sa TU nezapisuje — projekt bez snapshotu
        # ho dostane pri stavbe (CabinetBuilder.build_into -> ensure_project_state!,
        # tá istá operácia), takze zmrazenie ostava jednym zapisom.
        return res if to_add.empty?
        return res.merge('status' => :failed) unless add_project_sets!(model, to_add.values)
        res['added'] = to_add.keys
        res
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
      # no_set_reason: ORANGE kod pre polozku, ktora nema ZIADNE mapovanie.
      #   Default `no_set` = „typ nema priradeny set". Volajuci ho zmeni, ked
      #   je pricina INA a konkretnejsia — R-07: `library_incompatible`, teda
      #   „projekt nema vlastne predvolby a globalna kniznica sa nesmie
      #   pouzit". Ostatne dovody (chybajuci set, pasma, dlzka) sa NEMENIA.
      # manual_items (KOV-H1): ad-hoc polozky kovania zo VSETKYCH skriniek
      #   (`Bom.collect` kluc `hardware_manual`). Je to VLASTNY KANAL PRED set
      #   rezoluciou — nikdy `resolve_set_id`, nikdy `note_manual` (to je D-93
      #   znamienko rucneho zasahu do POCTU setovej polozky, uplne iny pojem,
      #   audit #15 FIX 7). Katalogova ad-hoc polozka sa ZLIEVA s riadkom
      #   rovnakeho kodu zo setu (jedna cena, jedna objednavka); volna polozka
      #   ma vlastny riadok. `unmapped` sa ad-hoc netyka — polozka ma kod alebo
      #   nazov od pouzivatela, takze nemapovana byt nemoze.
      def expand(hardware_items, state, cabinet_overrides: {}, catalog: nil,
                 no_set_reason: 'no_set', manual_items: [])
        mapping = state.is_a?(Hash) && state['mapping'].is_a?(Hash) ? state['mapping'] : {}
        sets    = state.is_a?(Hash) && state['sets'].is_a?(Hash) ? state['sets'] : {}
        # Cabinet override mapy prechadzaju TYM ISTYM parserom (citacia cesta —
        # neplatna polozka vypadne s logom, expanzia nikdy nespadne).
        overrides = normalize_cabinet_overrides(cabinet_overrides)
        lookup  = catalog_lookup(catalog)
        rows = {}
        unmapped = []
        # kluc clena `per: 'owner'` => UZ VYDANY zdrojovy zaznam riadku (R-34:
        # dalsi zasah na ten isty kluc je realne zliatie a doznaci mu `per_owner`)
        owner_seen = {}
        # KOV-H1: ad-hoc kanal ide PRVY — riadok potom existuje uz vtedy, ked
        # k nemu pribudne setovy zdroj rovnakeho kodu (zliatie je tym pádom
        # bezne `add_row` a cena vyjde JEDNA).
        expand_manual(manual_items, rows, lookup)
        Array(hardware_items).each do |it|
          next unless it.is_a?(Hash)
          gt  = it['generic_type'].to_s
          qty = it['quantity'].to_i
          next if gt.empty? || qty < 1
          sid, reason, info = resolve_set_id(gt, it, overrides, mapping)
          if sid.nil?
            reason = no_set_reason if reason == 'no_set'
            unmapped << unmapped_entry(it, nil, reason, info)
            next
          end
          set = sets[sid]
          if set.nil?
            unmapped << unmapped_entry(it, sid, 'set_missing')
            next
          end
          # H2 (audit FIX 5): set INEHO typu = ORANGE, NIKDY tichy zly hardver.
          # Zapisove cesty typ strazia, ale mapovanie zo sablony moze ukazat na
          # set_id, ktoreho definiciu si projekt drzi vlastnu (a ta moze byt
          # ineho typu) — expanzia je posledna poistka.
          if set['generic_type'].to_s != gt
            unmapped << unmapped_entry(it, sid, 'set_type_mismatch')
            next
          end
          # R-06 (brana 1d): dlzkove kovanie (uchytkovy profil D-90 nesie rez
          # v params) sa cez KUSOVY set nacenit NESMIE — cena katalogu je za
          # meter a subtotal by ju vynasobil poctom KUSOV. Radsej NIC (ORANGE
          # s rozmerom, sekcia NEMAPOVANE) nez zle peniaze v nakupe a v ponuke.
          if length_unsupported?(it)
            unmapped << unmapped_entry(it, sid, 'length_unsupported')
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

      # R-06 (brana 1d): polozka sa REZE NA DLZKU — nesie kladnu dlzku rezu
      # v params['cut_length_mm'] (nazov kluca je autorita HardwareRules,
      # hardware_sets si ho neopisuje). Kazdy set vie dnes iba KUSY (PER_KINDS),
      # takze taka polozka sa cez set nacenit nesmie.
      # Polozka BEZ dlzky rezu (kusova uchytka, panty, nohy, vysuvy s NL) tu
      # NIKDY nespadne — predikat je jedina podmienka brany a je uzky.
      # POZOR pri plnom rezime (R-05/R-06): brana sa smie stlmit az v TEJ ISTEJ
      # davke, ktora prinesie dlzkovu materializaciu (Σ mm, MJ „m") — inak by
      # sa polozka vratila do kusoveho nasobenia, teda presne do tejto chyby.
      def length_unsupported?(it)
        cut = numeric_param(it, HardwareRules::LENGTH_PARAM)
        !cut.nil? && cut.positive?
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
          # audit B3: clen `per: 'owner'` ide 1x na (korpus, vlastnik, set, kod)
          # — druhe pravidlo s rovnakym vlastnikom TipOn nezdvoji.
          key = m['per'] == 'owner' ? [it['owner_id'].to_s, it['owner_part_key'].to_s,
                                       sid, code].join('|') : nil
          prev = key && owner_seen[key]
          if prev
            # R-34 (review #252 kolo 3): AZ TU sa mnozstvo naozaj ZLIEVA —
            # priznak preto nesie riadok, ktory duplikat POHLTIL, nie kazdy
            # vydany owner clen. Bez toho by brana zastavila aj dve instancie
            # so zdielanym `cabinet_id`, ale ROZNYM `owner_part_key`: tie sa
            # nezlievaju (kluc sa nezhoduje) a ich mnozstva su spravne.
            prev['per_owner'] = true
            next
          end
          src = add_row(rows, code, key ? m_qty : qty * m_qty, it, sid, lookup)
          owner_seen[key] = src if key
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

      # `per_owner` (review #252 P2, spresnene R-34): zdroj priznava, ze jeho
      # mnozstvo NAOZAJ POHLTILO duplikat clena UCTOVANEHO NA VLASTNIKA. Ma
      # presne jedneho citatela a bez neho by nemal ako vzniknut: brana exportov
      # (`ProductionCore.dup_partition`) potrebuje vediet, ci duplicitne ID
      # skrinky NAOZAJ podpocita objednavku. Dedup `per: 'owner'` je jediny
      # mechanizmus, ktory to sposobi — skrinka, ktorej sety maju len cleny
      # `per: 'unit'`, sa spocita spravne aj pri zdielanom ID, a blokovat jej
      # export by bolo zbytocne. Kluc je ADITIVNY (kto ho nepozna, nic
      # nestrati), zapisuje sa LEN ked je pravdivy a NASTAVUJE HO
      # `expand_members` az vo vetve realneho preskoku — `add_row` ho sam
      # nikdy nepise (vratena `src` je presne to miesto, kam sa doznaci).
      # -> `src` Hash, ktory prave pribudol do `row['sources']`.
      def add_row(rows, code, quantity, it, sid, lookup)
        # GH #126 P2: identita kodu je case-insensitive (kontrakt katalogu) —
        # agregacny kluc kanonicky, zobrazuje sa prvy videny zapis.
        row = rows[code.downcase] ||= { 'code' => code, 'quantity' => 0, 'sources' => [],
                                        'manual_quantity' => 0 }
        row['quantity'] += quantity
        note_manual(row, it, quantity)
        src = {
          'cabinet_id' => it['owner_id'].to_s,
          'owner_part_key' => (it['owner_part_key'].nil? ? nil : it['owner_part_key'].to_s),
          'generic_type' => it['generic_type'].to_s,
          'rule_id' => it['rule_id'].to_s,
          'set_id' => sid,
          'quantity' => quantity
        }
        row['sources'] << src
        row_join(row, lookup)
        src
      end

      # --- KOV-H1: ad-hoc kanal (polozky mimo setov) -------------------------
      #
      # Vstup su UZ OCISTENE zaznamy z configu (`CabinetBuilder.norm_hardware_manual`)
      # obohatene zberom o `owner_id`/`owner_pid`/`owner_missing`. Tu sa NIC
      # nevaliduje druhykrat — expanzia je citacia cesta a nepouzitelny zaznam
      # sa proste preskoci (rovnaky ton ako `expand`).
      def expand_manual(manual_items, rows, lookup)
        Array(manual_items).each do |it|
          next unless it.is_a?(Hash)

          qty = it['qty'].to_i
          next if qty < 1

          case it['source'].to_s
          when 'catalog' then add_adhoc_row(rows, it, qty, lookup)
          when 'free'    then add_free_row(rows, it, qty)
          end
        end
      end

      # Katalogova ad-hoc polozka = BEZNY nakupny riadok podla kodu. Zlieva sa
      # so setovymi zdrojmi rovnakeho kodu (agregacia je case-insensitive ako
      # v `add_row`), takze cena je JEDNA a ziva z katalogu (audit BLOCKER 2).
      # `adhoc_quantity` = kolko kusov riadku pochadza z ad-hoc poloziek; bez
      # neho by sa z riadku nedalo zistit, ze ho clovek doplnil rucne.
      def add_adhoc_row(rows, it, quantity, lookup)
        code = it['code'].to_s.strip
        return if code.empty?

        row = rows[code.downcase] ||= { 'code' => code, 'quantity' => 0, 'sources' => [],
                                        'manual_quantity' => 0 }
        row['quantity'] += quantity
        row['adhoc_quantity'] = row['adhoc_quantity'].to_i + quantity
        # SNAPSHOT nazvu/MJ z configu — pouzije sa LEN vtedy, ked kod v katalogu
        # NIE JE (`row_join`). Prvy zapis vyhrava: ked tu isty kod doplnia dve
        # skrinky, snapshoty su rovnake (server ich pri pridani bral z katalogu).
        row['adhoc_snapshot'] ||= { 'name' => it['name'].to_s, 'unit' => it['unit'].to_s }
        row['sources'] << adhoc_source(it, quantity)
        row_join(row, lookup)
        row
      end

      # Volna polozka = VLASTNY riadok (nema kod, s nicim sa zliat nemoze).
      # Kluc `free:<cabinet_id>:<id>` — dve skrinky s rovnakou volnou polozkou
      # su dva riadky, presne ako dva rozne nazvy. Cena a MJ su zo SNAPSHOTU
      # (zadal ich pouzivatel), takze riadok NIKDY nie je `missing`.
      def add_free_row(rows, it, quantity)
        id = it['id'].to_s
        return if id.empty?

        key = "free:#{it['owner_id']}:#{id}"
        price = it['price_eur_vat']
        row = rows[key] ||= { 'code' => '', 'quantity' => 0, 'sources' => [],
                              'manual_quantity' => 0, 'adhoc_quantity' => 0,
                              'free' => true, 'free_key' => key,
                              'missing' => false, 'name_sk' => it['name'].to_s,
                              'category' => nil, 'unit' => it['unit'].to_s,
                              'price_eur_vat' => (price.is_a?(Numeric) ? price.to_f : nil) }
        row['quantity'] += quantity
        row['adhoc_quantity'] = row['adhoc_quantity'].to_i + quantity
        row['sources'] << adhoc_source(it, quantity)
        row
      end

      # Zdroj ad-hoc riadku. `generic_type`/`rule_id`/`set_id` su nil — polozka
      # ZIADNY set ani pravidlo nema a predstierat opak by rozbilo rozklik
      # povodu v Nakupe. `origin: 'adhoc'` je jediny priznak, podla ktoreho sa
      # da ad-hoc zdroj rozoznat (NIKDY `source: 'manual'`, to je D-93).
      def adhoc_source(it, quantity)
        { 'cabinet_id' => it['owner_id'].to_s,
          'owner_part_key' => (it['owner_part_key'].nil? ? nil : it['owner_part_key'].to_s),
          'generic_type' => nil, 'rule_id' => nil, 'set_id' => nil,
          'quantity' => quantity, 'origin' => 'adhoc', 'manual_id' => it['id'].to_s }
      end

      # D-93 (audit B4): nakupny riadok nesie ZNAMIENKO rucneho zasahu — pocet
      # kusov z poloziek so source 'manual' + hodnoty, ktore by dal automat.
      # Nakupny CSV kontrakt sa TYM NEMENI (znamienko zije v sekcii Nakup Studia).
      def note_manual(row, it, quantity)
        return unless it.is_a?(Hash) && it['source'].to_s == 'manual'
        row['manual_quantity'] = row['manual_quantity'].to_i + quantity
        return unless it.key?('rule_nominal_length')
        rnl = it['rule_nominal_length']
        label = rnl.is_a?(Numeric) ? "#{fmt_mm(rnl)} mm" : 'nezmestí sa'
        list = (row['manual_auto'] ||= [])
        list << label unless list.include?(label)
      end

      # Hotovy slovensky text znamienka (tooltip v sekcii Nakup Studia). Text sklada
      # VYHRADNE server — JS ho len vypise vedla ikony.
      def manual_note(row)
        q = row['manual_quantity'].to_i
        return nil if q < 1
        auto = Array(row['manual_auto'])
        base = "ručne prepísané: #{q} ks"
        auto.empty? ? base : "#{base} (automat: #{auto.join(' / ')})"
      end

      def row_join(row, lookup)
        item = lookup[row['code'].downcase]
        if item.nil?
          # KOV-H1 (audit #15 FIX 6): ked riadok nesie ad-hoc SNAPSHOT, kod
          # z katalogu zmizol (alebo tam nikdy nebol) — ale nazov a MJ MAME.
          # Riadok preto NIE JE `missing` („bez nazvu a ceny"), je
          # `catalog_missing` („bez ceny"): v CSV a v ponuke ostava citatelny
          # a Kontrola ho prizna ORANGE. Bez tohto by ho CP ticho preskocil
          # a v nakupe by ostal holy kod.
          snap = row['adhoc_snapshot']
          if snap.is_a?(Hash)
            row['missing'] = false
            row['catalog_missing'] = true
            row['name_sk'] = snap['name']
            row['category'] = nil
            row['unit'] = snap['unit']
            row['price_eur_vat'] = nil
            return row
          end
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
          'nominal_length' => (params['nominal_length'].is_a?(Numeric) ? params['nominal_length'].to_f : nil),
          # D-90: serverovy popis dlzkovych params („rez 597 mm") — CSV aj tab
          # Kovanie ho len vypisu. nil pri polozkach bez dlzkoveho priznaku.
          'params_label' => HardwareRules.params_label(params)
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
        # KOV-H1: kluc riadku je POSLEDNY clen zoradenia. Pri setovych riadkoch
        # nemeni NIC (kluc = `code.downcase`, takze o poradi rozhodne uz `code`),
        # ale VOLNE riadky maju `code` prazdny a kategoriu nil — bez tohto
        # rozhodcu by ich `sort_by` (nestabilny) preusporadal medzi behmi.
        list = rows.sort_by do |key, r|
          [r['missing'] ? 1 : 0, cat_rank.fetch(r['category'], 98) || 98, r['code'], key]
        end.map { |_key, r| r }
        total = 0.0
        unknown = 0
        list.each do |r|
          # D-93: znamienko rucneho zasahu — hotovy text (nil = ziadny zasah).
          r['manual_note'] = manual_note(r)
          r.delete('manual_auto') # pomocna zbierka, do payloadu nepatri
          r.delete('adhoc_snapshot') # KOV-H1: to iste — snapshot uz je v riadku
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

      # --- rozpis nakupu JEDNEJ polozky (D-92, cista funkcia) ------------------

      # Synteticky vlastnik pre resolver: expand berie cabinet overridy podla
      # it['owner_id'], explain dostava override mapu UZ konkretnej skrinky.
      EXPLAIN_OWNER = '__explain__'

      # „Co sa realne kupi" pre JEDNU polozku config.hardware[] — podklad sekcie
      # Kovanie v karte skrinky (D-92). Doteraz sa v paneli nedalo zistit, ktory
      # set a ktore KODY z polozky vzniknu; supis to ukazal az v sekcii Nakup.
      #
      # Vsetky rozhodnutia robia TIE ISTE autority ako expand (jeden vyklad
      # nakupu — panel a supis sa nesmu rozist): resolve_set_id (override
      # vlastnika -> override skrinky -> mapovanie projektu, selector podla
      # parametra), member_code (code / code_by_nl / param_bands),
      # unmapped_entry + unmapped_reason_sk (slovenske dovody), catalog_lookup.
      # Rozdiel je LEN v tvare vystupu: expand agreguje kody cez cely projekt,
      # explain rozpisuje jednu polozku.
      #
      # state = projektovy snapshot {'mapping','sets'} alebo nil (nic nemapuje).
      # overrides = override mapa TEJ skrinky (config['hardware_sets']).
      # catalog = HardwareCatalog.items (nazvy kodov) alebo nil.
      # lookup  = UZ postavena mapa kod=>polozka (audit FIX D-92): volajuci,
      #   ktory explain vola v cykle cez vsetky polozky skrinky, si ju postavi
      #   RAZ — inak by sa katalog premapoval pri kazdej polozke.
      #
      # POZOR na per 'owner': expand deduplikuje clena na (korpus, vlastnik,
      # set, kod) cez VSETKY polozky, explain vidi len jednu — pri dvoch
      # pravidlach na tom istom vlastnikovi ho preto ukaze pri oboch, hoci sa
      # kupi raz. Je to POHLAD NA POLOZKU, nie nakupny zoznam (ten je v Studiu).
      #
      # Cista funkcia: ziadne IO, ziadny SketchUp, vstup sa NEMENI.
      # -> { 'set_id', 'set_name', 'members' => [...], 'problems' => [SK texty] }
      # no_set_reason: ako v `expand` — volajuci ho posiela, ked je pricina
      # „bez mapovania" INA a konkretnejsia (R-07: `library_incompatible`).
      # Panel a supis musia dat TEN ISTY dovod (review P2-3).
      def explain(item, state, overrides: {}, catalog: nil, lookup: nil,
                  no_set_reason: 'no_set')
        out = { 'set_id' => nil, 'set_name' => nil, 'members' => [], 'problems' => [] }
        return out unless item.is_a?(Hash)
        gt = item['generic_type'].to_s
        return out if gt.empty?

        mapping = state.is_a?(Hash) && state['mapping'].is_a?(Hash) ? state['mapping'] : {}
        sets    = state.is_a?(Hash) && state['sets'].is_a?(Hash) ? state['sets'] : {}
        it = item.merge('owner_id' => EXPLAIN_OWNER)
        ovr = { EXPLAIN_OWNER => normalize_mapping(overrides.is_a?(Hash) ? overrides : {},
                                                   nil, allow_owner: true) }

        sid, reason, info = resolve_set_id(gt, it, ovr, mapping)
        if sid.nil?
          reason = no_set_reason if reason == 'no_set'
          out['problems'] << unmapped_reason_sk(unmapped_entry(it, nil, reason, info))
          return out
        end
        out['set_id'] = sid
        set = sets[sid]
        if set.nil?
          out['problems'] << unmapped_reason_sk(unmapped_entry(it, sid, 'set_missing'))
          return out
        end
        out['set_name'] = set['name']
        if set['generic_type'].to_s != gt
          out['problems'] << unmapped_reason_sk(unmapped_entry(it, sid, 'set_type_mismatch'))
          return out
        end
        # R-06 (brana 1d): TA ISTA brana ako v expand — panel a supis sa nesmu
        # rozist. Bez nej by panel rozpisal kody s cenou za meter pri polozke,
        # ktora v nakupe vobec nevznikne.
        if length_unsupported?(it)
          out['problems'] << unmapped_reason_sk(unmapped_entry(it, sid, 'length_unsupported'))
          return out
        end
        explain_members(it, set, sid, (lookup || catalog_lookup(catalog)), out)
        out
      end

      def explain_members(it, set, sid, lookup, out)
        # Pocet polozky je v configu vzdy >= 1; obrana pre poskodeny zaznam.
        qty = [it['quantity'].to_i, 1].max
        Array(set['members']).each_with_index do |m, idx|
          code, miss = member_code(m, it)
          if miss
            out['problems'] << unmapped_reason_sk(
              unmapped_entry(it, sid, miss['reason'],
                             miss.merge('member_index' => idx, 'member_label' => m['label']))
            )
            next
          end
          next if code.nil? # clen bez kodu (legacy tvar) sa preskoci ako v expand
          item = lookup[code.downcase]
          per = m['per'].to_s
          out['members'] << {
            'code' => code,
            # nil nazov = kod NIE JE v katalogu kovania (UI to pomenuje);
            # nikdy sa nedosadzuje nahradny text uz na serveri.
            'name' => (item ? item['name_sk'] : nil),
            'missing' => item.nil?,
            'qty' => (per == 'owner' ? m['qty'].to_i : qty * m['qty'].to_i),
            'per' => per,
            'label' => m['label'],
            # Rad podla dlzky: hodnota, ktora kod vybrala (tooltip v Studiu aj
            # v paneli) — pri pevnom kode nil.
            'nominal_length' => (m['code_by_nl'].is_a?(Hash) ? numeric_param(it, 'nominal_length') : nil)
          }
        end
      end

      # --- normalizacia a validacia (audit F10 + H1a) --------------------------

      # PRISNA validacia JEDNEHO setu (zapisova cesta). ALL-OR-NOTHING:
      # jediny chybny clen zhodi cely set — ziadny tichy drop clenov.
      # Spatne kompatibilna signatura: chyby su SPRAVY (Stringy).
      # -> [norm|nil, [String]]
      def validate_set(set)
        norm, errors = validate_set_detailed(set)
        [norm, errors.map { |e| e['msg'] }]
      end

      # TA ISTA validacia so STRUKTUROVANYMI chybami (kontrakt pre B3, audit
      # #17 FIX 13): `{ 'row' => nil|index clena, 'field' => …, 'msg' => SK veta }`.
      # Editor setu tak vie chybu ukazat PRI POLI, nielen v jednom cervenom
      # riadku nad formularom. `row` je nil pri chybe CELEHO setu.
      #
      # CISTA FUNKCIA — ZIADNE IO. Pouziva ju aj zapis projektoveho snapshotu
      # a citanie sablon, ktore cestuju medzi PC s INOU taxonomiou; clenstvo
      # vyrobcu/rady v taxonomii sa preto overuje AZ v `save_set!` (globalna
      # kniznica), nikdy tu.
      # -> [norm|nil, [{row, field, msg}]]
      def validate_set_detailed(set)
        return [nil, [set_err(nil, 'set musí byť objekt')]] unless set.is_a?(Hash)
        s = deep_copy(stringify(set))
        sid = s['set_id'].to_s.strip
        return [nil, [set_err('set_id', 'set nemá set_id')]] if sid.empty?

        klass, gt, cerrors = classify(s, sid)
        return [nil, cerrors] unless cerrors.empty?
        unless BuildPlan::GENERIC_TYPES.include?(gt)
          return [nil, [set_err('generic_type', "set „#{sid}“ má neznámy typ kovania „#{gt}“")]]
        end

        raw_members = s['members']
        unless raw_members.is_a?(Array) && !raw_members.empty?
          return [nil, [set_err('members', "set „#{sid}“ nemá členov")]]
        end
        errors = []
        members = raw_members.each_with_index.map do |m, i|
          norm, errs = validate_member(m, i, strict: true)
          errs.each { |e| errors << set_err('members', "set „#{sid}“: #{e}", row: i) }
          norm
        end
        return [nil, errors] unless errors.empty?

        name = s['name'].to_s.strip.empty? ? sid : s['name'].to_s.strip
        [build_set(sid, name, gt, klass, read_active(s['active']), members), []]
      end

      def set_err(field, msg, row: nil)
        { 'row' => row, 'field' => field, 'msg' => msg }
      end

      # Normalizovany set v PEVNOM poradi klucov (SET_KEY_ORDER). Klasifikacne
      # kluce su pritomne LEN pri klasifikovanom sete, `series` len ked ma
      # hodnotu, `active` len ked je `false` (sparse).
      def build_set(sid, name, gt, klass, active, members)
        out = { 'set_id' => sid, 'name' => name, 'generic_type' => gt }
        CLASS_KEYS.each { |k| out[k] = klass[k] if klass.key?(k) }
        out['active'] = false if active == false
        out['members'] = members
        out
      end

      # `active` je SPARSE (audit #17 FIX 7): default je „aktivny", uklada sa
      # LEN `false`. Citanie zachova presne `false` (aj ako string z rucne
      # upraveneho suboru); cokolvek ine = kluc chyba.
      # -> false | nil
      def read_active(raw)
        return false if raw == false || raw.to_s.strip.downcase == 'false'

        nil
      end

      # Je set KLASIFIKOVANY? (aspon jeden klasifikacny kluc s hodnotou)
      def classified?(set)
        return false unless set.is_a?(Hash)

        CLASS_KEYS.any? { |k| !set[k].to_s.strip.empty? }
      end

      # === JEDNA AUTORITA PRAVIDIEL KLASIFIKACIE (zapis aj citanie) ===========
      #
      # Klasifikacia je ALL-OR-NOTHING: bud UPLNE CHYBA (legacy „nezaradeny"
      # set — sprava sa presne ako pred KOV-B1), alebo je UPLNA a kontextovo
      # platna. Ciastocny tvar je CHYBA, nie „rozrobene": polovicna
      # klasifikacia by v editore vyzerala ako hotove zaradenie.
      #
      # `generic_type` je pri klasifikovanom sete ODVODENY (`USE_TYPE_GENERIC`):
      # chybajuci sa DOPLNI, nesediaci je CHYBA. Pri `use_type: 'other'` mapa
      # neexistuje, takze typ musi prist explicitne.
      # -> [klasifikacia Hash, generic_type String, errors]
      def classify(s, sid)
        gt = s['generic_type'].to_s.strip
        return [{}, gt, []] unless classified?(s)

        errors = []
        out = {}
        ut = s['use_type'].to_s.strip
        unless USE_TYPES.include?(ut)
          errors << set_err('use_type', "set „#{sid}“ má neznámy typ použitia „#{ut}“")
        end
        om = s['opening_mode'].to_s.strip
        unless OPENING_MODES.include?(om)
          errors << set_err('opening_mode', "set „#{sid}“ má neznámy spôsob otvárania „#{om}“")
        end
        dc = s['drawer_construction'].to_s.strip
        if ut == 'drawer'
          if dc.empty?
            errors << set_err('drawer_construction', "set „#{sid}“: pri zásuvke treba uviesť konštrukciu")
          elsif !DRAWER_CONSTRUCTIONS.include?(dc)
            errors << set_err('drawer_construction', "set „#{sid}“ má neznámu konštrukciu zásuvky „#{dc}“")
          end
        elsif !dc.empty?
          errors << set_err('drawer_construction',
                            "set „#{sid}“: konštrukciu zásuvky má len set na zásuvky")
        end
        man = s['manufacturer']
        if !man.is_a?(String) || man.strip.empty?
          errors << set_err('manufacturer', "set „#{sid}“ nemá výrobcu")
        end
        ser = s['series']
        if !ser.nil? && !ser.is_a?(String)
          errors << set_err('series', "set „#{sid}“ má neplatnú produktovú radu")
        end

        gt, gerrors = classified_generic_type(sid, ut, gt)
        errors.concat(gerrors)
        return [{}, gt, errors] unless errors.empty?

        out['use_type'] = ut
        out['opening_mode'] = om
        out['drawer_construction'] = dc if ut == 'drawer'
        out['manufacturer'] = man.strip
        # VOLITELNA rada (vedoma odchylka od mockupu, ktory ju ukazuje ako
        # povinnu): podperky, klzaky ani „Bystrica" ziadnu radu nemaju a
        # vynutena rada by do taxonomie priniesla vymyslene mena. Prazdna
        # hodnota = kluc sa NEUKLADA (B3 ju ukaze ako „— bez rady —").
        st = ser.to_s.strip
        out['series'] = st unless st.empty?
        [out, gt, []]
      end

      # `generic_type` klasifikovaneho setu: odvodeny z `use_type` (mimo `other`).
      # -> [generic_type, errors]
      def classified_generic_type(sid, use_type, gt)
        derived = USE_TYPE_GENERIC[use_type]
        if derived.nil?
          # `use_type: 'other'` (alebo neznamy — ten uz ma vlastnu chybu):
          # typ kovania musi prist explicitne, mapa preň neexistuje.
          return [gt, []] unless use_type == 'other' && gt.empty?

          return [gt, [set_err('generic_type',
                               "set „#{sid}“: pri type použitia „iné“ treba vybrať typ kovania")]]
        end
        return [derived, []] if gt.empty? || gt == derived

        [gt, [set_err('generic_type',
                      "typ použitia „#{use_type_sk(use_type)}“ znamená typ kovania " \
                      "„#{derived}“ — set má „#{gt}“")]]
      end

      # SK nazvy typov pouzitia — LEN pre hlasky servera (UI si ich sklada B3).
      USE_TYPE_SK = { 'door' => 'dvierka', 'drawer' => 'zásuvka', 'lift' => 'výklop',
                      'fall' => 'sklop', 'other' => 'iné' }.freeze

      def use_type_sk(use_type)
        USE_TYPE_SK[use_type.to_s] || use_type.to_s
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
        # R-07 (review P2): TYPOVA OCHRANA. `to_i` na `true`, poli ci objekte
        # vyhodi NoMethodError — a tato metoda bezi aj v CITACEJ ceste
        # (`normalize_members` nad cudzim suborom aj nad snapshotom v .skp),
        # takze by taky zaznam zhodil prestavbu, nie ju odmietol. Cislo aj
        # cislo v stringu su legitimne (legacy tvary); cokolvek ine = neplatny
        # pocet, teda chyba clena, ktoru vyssie vrstvy uz vedia spracovat.
        raw_qty = mm['qty']
        unless raw_qty.nil? || raw_qty.is_a?(Numeric) || raw_qty.is_a?(String)
          return [nil, ["#{pos} má neplatný počet"]]
        end
        qty = raw_qty.nil? ? 1 : raw_qty.to_i
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
          build_set(sid,
                    (s['name'].to_s.strip.empty? ? sid : s['name'].to_s.strip),
                    gt, read_set_classification(s, sid), read_active(s['active']), members)
        end
      end

      # KOV-B1 — KLASIFIKACIA V CITACEJ CESTE (tolerantna).
      #
      # Cita sa CELA alebo VOBEC: neuplny blok, neznama hodnota enumu alebo
      # nesulad s kanonickou mapou zahodi CELU klasifikaciu a set sa cita ako
      # „nezaradeny". `generic_type` sa pritom NIKDY nemeni — EXPANZIA (a teda
      # nakup) je od klasifikacie uplne nezavisla, takze poskodeny klasifikacny
      # blok NESMIE zmenit ani jeden objednany kod.
      #
      # Tichy orez to NEROBI: stratu zachyti 4. vrstva detektora
      # (`classification_lost?`) a kniznica/snapshot/sablona skoncia ako
      # read-only / `:invalid` / odmietnute, nikdy ako „precitane v poriadku".
      def read_set_classification(s, sid)
        return {} unless classified?(s)

        klass, gt, errors = classify(s, sid)
        # Aj ked su pravidla splnene, ODVODENY typ sa musi zhodovat s ULOZENYM
        # — inak by set po zapise zmenil typ kovania (a s nim aj nakup).
        return klass if errors.empty? && gt == s['generic_type'].to_s.strip

        log_skip("set „#{sid}“: klasifikácia nečitateľná — číta sa ako nezaradený")
        {}
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
          # KOV-B1: TRIEDNY kluc sa rozpozna PRED `parse_hardware_set_key` —
          # ten by ho odmietol ako neplatny (`class:slide|tipon` nie je
          # generic_type). Prijimaju ho VSETKY mapy: globalna, projektovy
          # snapshot aj cabinet override (`allow_owner` sa ho netyka —
          # vyber na urovni dielca ma vlastny tvar a v triednom kluci je zakazany).
          if class_mapping_key?(key)
            canon, cerr = parse_class_key(key)
            if canon.nil?
              errors << "mapovanie „#{key}“: #{cerr}"
              next
            end
            status, norm, refs = parse_mapping_value(value)
            if status != :ok
              errors << "mapovanie „#{key}“: #{norm}"
              next
            end
            next if ids && refs.any? { |sid| !ids.include?(sid) }
            out[canon] = norm
            next
          end
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
        return if @skip_log_muted
        Engine.log("hardware sets: #{msg}") if defined?(Engine) && Engine.respond_to?(:log)
      end

      # R-07 (review P3-2): brana sa vyhodnocuje pri KAZDOM pouziti kniznice
      # a jej round-trip kontrola pusta obsah cez `normalize_sets` — ta pri
      # kazdom preskocenom clene loguje. Bez stlmenia by nekompatibilna
      # kniznica zaplavila konzolu tou istou vetou pri kazdom payloade.
      # Stlmuje sa VYHRADNE diagnosticky prechod brany; skutocne citanie
      # (`read_library`) loguje dalej — tam je to jednorazova informacia.
      def without_skip_log
        prev = @skip_log_muted
        @skip_log_muted = true
        yield
      ensure
        @skip_log_muted = prev
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
