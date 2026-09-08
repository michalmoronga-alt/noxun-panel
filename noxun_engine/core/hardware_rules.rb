# frozen_string_literal: true
# Noxun Engine — pravidla kovania (V0.4 faza 1, standard sekcia 6.2 two-phase).
# CISTO Ruby (ziadne SketchUp API v evaluacii) — headless testovatelne.
#
# ============================ ARCHITEKTURA ============================
# Faza 1 = GENERICKE FLAGY: pravidla urcia TYP (leg/hinge/slide...) a POCET.
# Konkretny produkt/kod (variant_id) mapuje az faza 2 (V0.6 katalog).
#
# Ziadny univerzalny vypoctovy jazyk v JSON. Maly katalog Ruby VZOROV (kind),
# parametrizovanych JSON pravidlami:
#   fixed      — pevny pocet (nohy: 4)
#   bands      — pasma podla 1 vstupu, max je VRATANE (vyska cela <= 900 -> 2 panty)
#   fit_series — najvacsia hodnota radu <= (vstup - clearance); vysledok ide do
#                params['nominal_length'] (vysuv NL podla svetlej hlbky)
#   part_flag_length (D-90) — polozka vznikne LEN pre dielec s PRIZNAKOM
#                (uchytkovy profil na cele); dlzka rezu ide do
#                params['cut_length_mm'] (= sirka dielca), typ profilu do
#                params['profile']. Dielec bez profilu polozku nedostane.
# Nova kategoria kovania = spravidla len novy JSON zaznam; novy kind az pri novej logike.
# VEDOME OBMEDZENIE fazy 1: vystup je vzdy production_class 'counted' (pocitane kusy).
# Dlzkove kovanie (gola profily = 'linear' s vyrobnou dlzkou) a polozky viazane na
# DVOJICU dielcov pridu s vlastnym kind — obalka polozky (params) ich unesie.
#
# ====================== ZDROJE PRAVIDIEL A UNDO =======================
# 1) GLOBALNA kniznica: %APPDATA%\NOXUN\Engine\hardware_rules.json (+.bak, seed pri
#    prvom spusteni) — je LEN default pre nove projekty.
# 2) PROJEKTOVY SNAPSHOT: NOXUN dict na MODELI, kluc 'hardware_rules' (vzor
#    Materials.project_defaults). Rebuild cita VYHRADNE snapshot — vysledok stavby
#    je reprodukovatelny z .skp suboru (iny pocitac, zmena globalu, kopie skriniek).
#    ensure_project_rules! zapisuje snapshot VNUTRI prebiehajucej operacie buildera,
#    takze undo vrati model aj pravidla konzistentne (Codex audit K2/K3).
#
# ============================ TVAR PRAVIDLA ===========================
# { "rule_id": "zavesy-podla-vysky", "enabled": true,
#   "applies_to": { "role": "front_door" },            # 'cabinet' alebo rola dielca
#   "output": "hinge",                                  # BuildPlan::GENERIC_TYPES
#   "kind": "bands", "input": "height",
#   "bands": [ {"max": 900, "quantity": 2}, ... {"max": null, "quantity": 5} ] }
# applies_to.role == 'cabinet' moze mat "support": ["legs","plinth"] — filter podla
# typu podopretia (Construction.support_type). Volitelne "params_from_context":
# {"height": "floor_height"} — deklarativne doplnenie params z kontextu korpusu.
#
# Vstup (input) pri role dielca: 'height'/'width' = prod rozmery dielca (vyska cela),
# KOV-W 'weight' = hmotnost dielca v kg (`weight_kg` z planu — cela pre zavesy a
# vyklopy); ostatne kluce sa beru z kontextu korpusu (width/height/depth/
# floor_height/available_depth/available_height/available_width).
#
# ============================== OVERRIDE ==============================
# cfg[:hardware_overrides] (pole v configu korpusu, prezije rebuild ako part_overrides):
#   { "owner_part_key": null|"front:F1/wing:left", "generic_type": "hinge",
#     "rule_id": "zavesy-podla-vysky", "quantity": 6 }   alebo   "disabled": true
#   alebo (D-93)   "nominal_length": 420.0
# Identita override = TROJICA (owner_part_key, generic_type, rule_id) — dve pravidla
# s rovnakym outputom na tom istom ownerovi su adresovatelne samostatne (audit K1).
# disabled vitazi nad quantity; posledny duplicitny match vyhrava (normalize deduplikuje).
# Polozka po override nesie source='manual' + rule_quantity (povodny pocet z pravidla).
#
# D-93 RUCNY NL VYSUVU (audit B1/B2):
#   Polia zaznamu su NEZAVISLE — jeden zaznam moze niest quantity aj nominal_length
#   (a disabled). Zapisove cesty pracuju PO POLIACH: zmena NL nikdy nezmaze rucny
#   pocet a naopak; zaznam zanikne az ked je prazdny.
#   ZAMOK = existencia platneho pola 'nominal_length' (ziadny extra priznak).
#   Polozka po NL override nesie params['nominal_length'] = rucna hodnota,
#   source='manual' a 'rule_nominal_length' = hodnota, ktoru by dal automat
#   (nil = automat nevie — do svetlej hlbky sa nezmesti ziadna dlzka radu).
#   fit_series emituje polozku AJ ked automat nevyberie nic, pokial ma dielec
#   platny NL override (inak by zamok pri zmensenej hlbke ticho zmizol).
require 'json'
require 'fileutils'
require 'digest' # ŠT-3b-2c2: odtlacok pravidiel (vzor HardwareCatalog.record_rev)

module Noxun
  module Engine
    module HardwareRules
      # KOV-F1: std 2 = pravidlo `bands` smie niest VOLITELNE door guardy
      # (`finite`, `width_plus`, `width_warn_over`, `weight_bands`). Starsi
      # plugin (std 1) ich `normalize_rules` ZACHOVA a `compute` IGNORUJE —
      # rata podla tabulky bez +1 a bez varovani, NIKDY nulu (preto ostava aj
      # catch-all pasmo). Marker chrani opacny smer: dokument z NOVSIEHO
      # pluginu (std > STD) sa uz len CITA a zapisy sa odmietnu s hlaskou —
      # inak by nase `normalize_rules` ticho zahodilo pole, ktoremu nerozumie,
      # a prvy zapis by stratu zvecnil (vzor `HardwareSets` STD_SUPPORTED).
      STD          = 2 # verzia formatu suboru pravidiel (doc: std/seed_version/rules)
      SEED_VERSION = 4 # v2 (D1): +zavesenie hornej skrinky, +podperky policove,
                       # seria vysuvov zladena s realnym radom Atira (GH #125 P2)
                       # v3 (D-90): +uchytkovy profil na dvierkach a zasuvkovych celach
                       # v4 (KOV-F1): NOXUN tabulka zavesov + door guardy
      # KOV-F1 (Codex #329 kolo 3 P1): verzia formatu, OD KTOREJ seed pravidlo
      # zavesov nesie door guardy (Noxun tabulka). Snapshot POD tymto cislom =
      # pravidla este spred tabulky, takze skrinka so zavesmi nesie stare pocty
      # aj PO prestavbe (snapshot sa nikdy nemerguje sam — naprava je vedoma
      # akcia „Doplniť nové predvoľby" alebo ulozenie Pravidiel). PEVNE CISLO,
      # nie `STD`: buduci bump formatu na tabulke zavesov nic nezmeni.
      HINGE_TABLE_STD = 2

      FILE         = 'hardware_rules.json'
      MODEL_KEY    = 'hardware_rules' # kluc snapshotu v NOXUN dict na modeli

      KINDS = %w[fixed bands fit_series part_flag_length].freeze

      # D-90: kluc dlzky rezu v params polozky. JEDINA autorita nazvu — cita ho
      # `flag_length_params` (zapis), `params_label` (text) aj brana dlzkoveho
      # kovania v HardwareSets (R-06). Ziadna vrstva si string nesmie opisat.
      LENGTH_PARAM = 'cut_length_mm'

      # Kontextove kluce povolene ako input/params_from_context (dokumentacia tvaru ctx).
      CONTEXT_KEYS = %w[width height depth floor_height available_depth
                        available_height available_width].freeze

      # KOV-W: vstup „hmotnost dielca" (kg). JEDINA autorita nazvu — pravidla
      # zavesov (F) a vyklopov (E) ho pisu do `input`, `input_value` ho cita z
      # anotacie planu (`weight_kg`). Nie je to kontextovy kluc: hodnota patri
      # DIELCU, nie korpusu.
      INPUT_WEIGHT = 'weight'

      # === KOV-F1: VOLITELNE DOOR GUARDY PRAVIDLA `bands` =====================
      #
      # ZIADNY novy kind (Sol audit kolo 2 BLOCKER 1): starsi plugin by neznamy
      # kind PRESKOCIL a dvierka by dostali NULA zavesov — a to aj pri NOVOM
      # vlozeni skrinky, lebo citace pravidiel `std` ignoruju. Tabulka preto
      # ostava `bands` a guardy su VOLITELNE kluce, ktore `normalize_rules`
      # zachova a stary `compute` nevidi.
      #
      #   finite           true = catch-all pasmo znamena „MIMO tabulky":
      #                    polozka SA VYDA s jeho poctom (riadok v Kovani musi
      #                    existovat, inak nema kde vzniknut rucny zamok) a
      #                    pribudne KONFLIKT `door_height_out_of_table` (RED).
      #                    Bez `finite` je catch-all obycajne pasmo (dnesok).
      #   width_plus       { 'over' => mm, 'add' => ks } — sirsie kridlo nez
      #                    `over` dostane +`add` zavesov (bez podmienky vysky).
      #   width_warn_over  mm — sirsie kridlo = ORANGE `door_wide` (pocet NEMENI)
      #   weight_bands     Hettich hmotnostne pasma (kg -> ks). Vo V1 LEN VARUJU
      #                    (Michal 8.9.2026): ked pasmo chce viac nez VYSLEDNY
      #                    pocet, pribudne ORANGE — pocet sa nemeni.
      DOOR_GUARD_KEYS = %w[finite width_plus width_warn_over weight_bands].freeze

      # KOV-F1: kod KONFLIKTU „dvierka su nad tabulkou". Retazec je autorita
      # tohto modulu; register brany (`BuildPlan::HW_BLOCKERS`) aj hlaska
      # Kontroly ho len citaju.
      DOOR_OUT_OF_TABLE = 'door_height_out_of_table'

      SEED_RULES = [
        { 'rule_id' => 'nohy-zakladne', 'enabled' => true,
          'applies_to' => { 'role' => 'cabinet', 'support' => %w[legs plinth] },
          'output' => 'leg', 'kind' => 'fixed', 'quantity' => 4,
          'params_from_context' => { 'height' => 'floor_height' } },
        # KOV-F1: NOXUN tabulka poctu zavesov (Michal 8.9.2026) — plati pre
        # vsetkych vyrobcov, set rozhoduje LEN o produkte. Vysky su Hettich
        # pasma so SPRISNENYM prvym (od 850 uz 3: dvere tej vysky sa na dvoch
        # zavesoch zle nastavuju). Catch-all `nil -> 7` OSTAVA kvoli STARYM
        # citacom (dvere nad 2800 dostanu 7, nikdy nic); pre novy citac ho
        # `finite` meni na „mimo tabulky" (polozka + RED).
        { 'rule_id' => 'zavesy-podla-vysky', 'enabled' => true,
          'applies_to' => { 'role' => 'front_door' },
          'output' => 'hinge', 'kind' => 'bands', 'input' => 'height',
          'bands' => [
            { 'max' => 849.0,  'quantity' => 2 },
            { 'max' => 1700.0, 'quantity' => 3 },
            { 'max' => 2200.0, 'quantity' => 4 },
            { 'max' => 2400.0, 'quantity' => 5 },
            { 'max' => 2600.0, 'quantity' => 6 },
            { 'max' => 2800.0, 'quantity' => 7 },
            { 'max' => nil,    'quantity' => 7 }
          ],
          'finite' => true,
          'width_plus' => { 'over' => 600.0, 'add' => 1 },
          'width_warn_over' => 800.0,
          # Hettich (kod oficialnej kalkulacky hta.hettich.com, precitane
          # 8.9.2026): <= 7,70 -> 2 · <= 13,70 -> 3 · <= 17,10 -> 4 ·
          # <= 22,00 -> 5 · nad 22 kg „prekrocena maximalna hmotnost".
          'weight_bands' => [
            { 'max' => 7.7,  'quantity' => 2 },
            { 'max' => 13.7, 'quantity' => 3 },
            { 'max' => 17.1, 'quantity' => 4 },
            { 'max' => 22.0, 'quantity' => 5 }
          ] },
        # Seria v2 = realny rad Hettich InnoTech Atira (GH #125 P2 — povodna
        # genericka seria mala 400/450 a NL 420 nikdy nevznikla, takze kluc
        # mapy setu bol nedosiahnutelny). NL mimo mapy setu = ORANGE (D1).
        { 'rule_id' => 'vysuvy-nl-podla-hlbky', 'enabled' => true,
          'applies_to' => { 'role' => 'drawer_front' },
          'output' => 'slide', 'kind' => 'fit_series', 'input' => 'available_depth',
          'series' => [260.0, 300.0, 350.0, 420.0, 470.0, 520.0, 560.0, 620.0],
          'clearance' => 10.0, 'quantity' => 1 },
        # D1 (debata 2.8.): "Bystrica" = rektifikacny uholnik na zavesenie
        # skrinky na stenu — 2 ks na HORNU skrinku. Filter cabinet_type, NIE
        # support (GH #125 P2: support 'none' ma aj spodna skrinka bez noh).
        { 'rule_id' => 'zavesenie-hornej-skrinky', 'enabled' => true,
          'applies_to' => { 'role' => 'cabinet', 'cabinet_type' => %w[upper] },
          'output' => 'wall_hanger', 'kind' => 'fixed', 'quantity' => 2 },
        # D1 (debata 2.8.): 4 podperky na kazdu policu.
        { 'rule_id' => 'podperky-policove', 'enabled' => true,
          'applies_to' => { 'role' => 'shelf' },
          'output' => 'shelf_pin', 'kind' => 'fixed', 'quantity' => 4 },
        # D-90: uchytkovy profil (UKW-7). Polozka vznikne LEN na cele, ktore ma
        # profil zapnuty (deskriptor nesie :profile) — applies_to je 1 rola ako
        # u ostatnych pravidiel, preto DVE pravidla: dvierka a zasuvkove cela.
        { 'rule_id' => 'uchytkovy-profil', 'enabled' => true,
          'applies_to' => { 'role' => 'front_door' },
          'output' => 'handle', 'kind' => 'part_flag_length', 'quantity' => 1 },
        { 'rule_id' => 'uchytkovy-profil-zasuvky', 'enabled' => true,
          'applies_to' => { 'role' => 'drawer_front' },
          'output' => 'handle', 'kind' => 'part_flag_length', 'quantity' => 1 }
      ].freeze

      # D-90: kind pravidla, ktore reaguje na PRIZNAK PROFILU dielca. Zdielaju ho
      # emisia polozky aj kontrola profile_rule_missing (jeden nazov, jedno miesto).
      KIND_PROFILE = 'part_flag_length'

      # Povodne v1 tvary seed pravidiel, ktore v2 MENI (nie len doplna).
      # merge_seed pravidlo bajtovo zhodne s v1 tvarom NAHRADI novym seedom
      # (vzor F8 katalogu: aktualizuje sa LEN preukazatelne nezmeneny riadok;
      # pouzivatelska uprava sa NIKDY neprepisuje). Porovnanie po normalize.
      LEGACY_SEED_SHAPES = {
        # KOV-F1: v1..v3 tvar tabulky zavesov (900/1400/1900 -> 2/3/4/5).
        'zavesy-podla-vysky' => [
          { 'rule_id' => 'zavesy-podla-vysky', 'enabled' => true,
            'applies_to' => { 'role' => 'front_door' },
            'output' => 'hinge', 'kind' => 'bands', 'input' => 'height',
            'bands' => [
              { 'max' => 900.0,  'quantity' => 2 },
              { 'max' => 1400.0, 'quantity' => 3 },
              { 'max' => 1900.0, 'quantity' => 4 },
              { 'max' => nil,    'quantity' => 5 }
            ] }
        ],
        'vysuvy-nl-podla-hlbky' => [
          { 'rule_id' => 'vysuvy-nl-podla-hlbky', 'enabled' => true,
            'applies_to' => { 'role' => 'drawer_front' },
            'output' => 'slide', 'kind' => 'fit_series', 'input' => 'available_depth',
            'series' => [270.0, 300.0, 350.0, 400.0, 450.0, 470.0, 500.0,
                         520.0, 550.0, 580.0, 620.0, 650.0],
            'clearance' => 10.0, 'quantity' => 1 }
        ]
      }.freeze

      module_function

      # --- globalna kniznica (%APPDATA%) — default pre nove projekty ----------

      # R-08 (audit 1d #1): zdielany %APPDATA%/NOXUN/Engine — TA ISTA cesta,
      # akou ju pocita Materials (+ test_dir_override). Kym si ju modul ratal
      # sam, `test_dir_override` presmeroval zamok do sandboxu, ale zapis
      # ostal v ZIVOM %APPDATA% — izolovany in-SU test tak upravoval realne
      # pravidla pouzivatela a zamok nechranil nic. V produkcii je vysledok
      # bajt na bajt rovnaky.
      def dir
        return Materials.dir if defined?(Materials) && Materials.respond_to?(:dir)

        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # R-08: jeden sidecar zamok (`materials.lock`) pre VSETKY katalogy v tom
      # istom priecinku — vzor 1b-6c. Reentrantny; `flock`, ktory sa nepodari
      # vziat, vyhodi IOError a kazda zapisova cesta ho rescue-uje do svojho
      # NEUSPESNEHO vysledku. Citanie bez zapisu sa nezamyka.
      def with_catalog_lock(&blk)
        Materials.with_catalog_lock(&blk)
      end

      # Nacita globalnu kniznicu ako normalizovane pole pravidiel. Poskodeny/chybajuci
      # subor -> seed (vzor AbsRules: fallback nikdy nevrati nil). Seed-merge: ak subor
      # vznikol pod starsim SEED_VERSION, doplnia sa NOVE default pravidla (podla
      # rule_id) bez prepisu pouzivatelskych uprav — plati LEN pre globalnu kniznicu;
      # projektovy snapshot sa NIKDY nemeni sam (reprodukovatelnost stavby z .skp).
      def load
        load_state.first
      end

      # KOV-F1 (Codex #329 kolo 2 P1): `load` + PRIZNAK nekompatibilnej
      # kniznice -> [pravidla, blocked]. Sam `load` priznak zahadzuje, takze
      # volajuci, ktory na zaklade pravidiel nieco ZVECNUJE (dnes jediny:
      # `ensure_project_rules!`), by nedokazal rozlisit „precitane z kniznice,
      # ktorej rozumieme" od „orezany odtlacok kniznice z novsieho pluginu".
      def load_state
        ensure_seeded
        merged, changed, blocked = read_rules
        return [merged, blocked] unless changed

        # Codex #329 kolo 3 P2: priznak sa berie z DRUHEHO citania (pod zamkom),
        # nie z predzamkoveho — medzi nimi mohol kniznicu nahradit novsi plugin.
        persist_seed_merge!(merged)
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.load_state') if defined?(Engine)
        [deep_copy(SEED_RULES), false]
      end

      # CISTE citanie + seed-merge BEZ zapisu -> [pravidla, changed, blocked].
      #
      # KOV-F1 (dopredna brana `std`): dokument z NOVSIEHO pluginu sa CITA
      # (zakazka sa musi dat dokoncit), ale NIKDY sa doň nezapisuje ani sa
      # nemerguje seed — `normalize_rules` je tolerantna a pole, ktoremu
      # nerozumieme, by ticho zahodila; prvy zapis by stratu zvecnil.
      # TRETI PRVOK (`blocked`) je prave ten stav: obsah sa POUZIT smie, ale
      # ZVECNIT nie (Codex #329 kolo 2 P1).
      def read_rules
        doc = JsonFileStore.read(path, copy: false)
        rules = doc.is_a?(Hash) ? doc['rules'] : nil
        return [deep_copy(SEED_RULES), false, false] unless rules.is_a?(Array)
        return [normalize_rules(rules), false, true] if doc_std_unsupported?(doc)

        merged, changed = merge_seed(normalize_rules(rules), doc['seed_version'].to_i)
        [merged, changed, false]
      end

      # KOV-F1 (Codex #329 kolo 2 P1): je GLOBALNA kniznica z novsieho pluginu?
      # Rovnaka otazka ako v `read_rules`, len bez nacitania pravidiel — pytaju
      # sa jej builder (ORANGE do stavby) a `ensure_project_rules!`.
      def library_std_unsupported?
        doc_std_unsupported?(JsonFileStore.read(path, copy: false))
      rescue StandardError
        false
      end

      # KOV-F1: je dokument (kniznica alebo projektovy snapshot) z NOVSEJ
      # verzie formatu? JEDINA autorita otazky — pytaju sa jej obe citacie
      # cesty aj obe zapisove. Chybajuci `std` = najstarsi format (1).
      def doc_std_unsupported?(doc)
        return false unless doc.is_a?(Hash)

        doc.key?('std') && doc['std'].to_i > STD
      end

      # Hlaska pre zablokovany zapis (kniznica aj snapshot) — jedno znenie.
      def std_block_reason(where)
        "#{where} pravidiel kovania je z novšej verzie pluginu — číta sa len na " \
          'čítanie, zápisy sú vypnuté (aktualizuj plugin)'
      end

      # R-08 (audit 1d #2/#10): seed-merge je READ-MODIFY-WRITE. Pod zamkom sa
      # subor cita NANOVO (cache JsonFileStore ma 1 s okno) a merge sa
      # PREPOCITA — inak by sa zapisal odtlacok spred zamku a zmena druhej
      # instancie by zanikla. Ked seed doplnila medzitym uz ona, `changed` je
      # false a nezapisuje sa. Zlyhany zamok/citanie vrati predzamkovy
      # kandidat (nikdy holy seed).
      #
      # Codex #329 kolo 3 P2: vracia TU ISTU DVOJICU ako `load_state`
      # (`[pravidla, blocked]`). Kym sa tretia hodnota druheho citania zahadzovala
      # a `blocked` sa natvrdo hlasilo ako `false`, stacilo, aby kniznicu medzi
      # prvym citanim a zamkom nahradil NOVSI plugin — `ensure_project_rules!`
      # by potom orezane pravidla ZMRAZIL do .skp a brana by sa uz nikdy
      # nespustila (presne ta strata, ktorej ma `std` branit).
      def persist_seed_merge!(fallback)
        with_catalog_lock do
          JsonFileStore.reload!(path)
          fresh, changed, blocked = read_rules
          if changed && write(fresh) && defined?(Engine)
            Engine.log('hardware rules: globalna kniznica doplnena o nove default pravidla')
          end
          [fresh, blocked]
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.persist_seed_merge!') if defined?(Engine)
        [fallback, false]
      end

      # Doplni seed pravidla, ktore v kniznici chybaju (podla rule_id), a
      # OBNOVI pravidla bajtovo zhodne s niektorym STARSIM seed tvarom
      # (LEGACY_SEED_SHAPES — vzor F8: aktualizuje sa len preukazatelne
      # nezmenene pravidlo, pouzivatelska uprava sa nikdy neprepisuje). Vrati
      # [rules, changed] — changed aj pri samotnom bumpe seed_version.
      def merge_seed(rules, from_version)
        return [rules, false] if from_version >= SEED_VERSION
        seed_by_id = {}
        SEED_RULES.each { |r| seed_by_id[r['rule_id']] = r }
        refreshed = rules.map do |r|
          rid = r['rule_id']
          next r unless seed_by_id[rid] && legacy_seed_shape?(r)
          normalize_rules([seed_by_id[rid]]).first
        end
        have = {}
        refreshed.each { |r| have[r['rule_id']] = true }
        missing = seed_additions(refreshed, have)
        [refreshed + normalize_rules(missing), true]
      end

      # KOV-F1: ktore seed pravidla sa smu DOPLNIT. Chybajuce podla `rule_id`
      # MINUS tie, ktorych vystup uz na tej istej role obsluhuje INE ZAPNUTE
      # pravidlo (`OVERLAP_OUTPUT`): pouzivatel si zavesy premenoval alebo
      # nahradil vlastnym pravidlom a doplnenie seedu by mu vyrobilo DVOJITY
      # nakup. `evaluate` taky prekryv priznava ORANGE-om, doplnat ho nebudeme.
      def seed_additions(existing, have)
        taken = {}
        Array(existing).each do |r|
          next unless r.is_a?(Hash) && r['enabled'] != false
          next unless r['output'].to_s == OVERLAP_OUTPUT

          taken[(r['applies_to'] || {})['role'].to_s] = true
        end
        SEED_RULES.reject do |r|
          have[r['rule_id']] ||
            (r['output'].to_s == OVERLAP_OUTPUT && taken[(r['applies_to'] || {})['role'].to_s])
        end
      end

      # Pravidlo je nezmeneny STARY seed? (porovnanie normalizovanych tvarov)
      def legacy_seed_shape?(rule)
        shapes = LEGACY_SEED_SHAPES[rule['rule_id']]
        return false unless shapes
        norm = normalize_rules([rule]).first
        shapes.any? { |s| normalize_rules([s]).first == norm }
      end

      # R-08 (audit 1d #1): rychly check ostava (hot cesta), ale ZAPIS seedu ide
      # az po DRUHOM checku POD zamkom — inak by oneskoreny seeder prepisal
      # realnu zmenu, ktoru medzitym ulozila druha instancia.
      def ensure_seeded
        return if JsonFileStore.available?(path)
        with_catalog_lock do
          next true if JsonFileStore.available?(path)
          write(deep_copy(SEED_RULES))
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.ensure_seeded') if defined?(Engine)
        false
      end

      # POZOR (R-08, priznany zvysok): toto je UPLNA NAHRADA obsahu suboru —
      # okno Pravidla posiela CELE pole. Zamok zapisy SERIALIZUJE (a chrani
      # ich pred prepletenim so seed-merge cestou), ale dve okna, ktore si
      # pravidla nacitali sucasne, sa stale prebijaju „posledny vyhrava";
      # globalna kniznica pravidiel nema reviziu. Register to vedie ako
      # samostatnu polozku (R-35) — doriesi ju davka, ktora prinesie reviziu
      # do payloadu sekcie a konfliktovu vetvu okna.
      #
      # 1d/R-11: pred zapisom bezi este brana DEGRADOVANEHO suboru (poskodeny
      # primar + platna `.bak`).
      def write(rules)
        with_catalog_lock do
          next false if degraded_write_blocked?
          next false if newer_write_blocked?

          JsonFileStore.write(path, { 'std' => STD, 'seed_version' => SEED_VERSION,
                                      'rules' => normalize_rules(rules) })
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.write') if defined?(Engine)
        false
      end

      # 1d/R-11: dovod odmietnutia POSLEDNEHO zapisu (prazdny = nic sa
      # neodmietlo). Okno Pravidla ho pri zlyhani globalneho zapisu ukaze
      # namiesto vseobecneho „globalny zapis zlyhal". Navratovy tvar `write`
      # sa NEMENI — `[false, dovod]` je v Ruby pravdive a ternarky volajucich
      # by odmietnutie hlasili ako uspech.
      def write_block_reason
        @write_block_reason.to_s
      end

      # Brana sa vyhodnocuje POD ZAMKOM nad cerstvym stavom suboru (lekcia
      # R-07 B2). I/O chyba z `degraded?` sa NEchyta — vyleti do rescue vetvy
      # `write` a skonci ako neuspesny zapis.
      def degraded_write_blocked?
        prev = @write_block_reason
        @write_block_reason = ''
        return false unless JsonFileStore.degraded?(path)

        @write_block_reason = 'Globálne pravidlá kovania sú poškodené — číta sa záloha, zápisy sú ' \
                              "vypnuté (oprav alebo zmaž súbor #{path})"
        # Log LEN pri ZMENE stavu — seed-merge sa o zapis pokusa pri kazdom
        # nacitani, takze bezpodmienecny zapis by zaplavil Ruby konzolu.
        if prev.to_s != @write_block_reason && defined?(Engine)
          Engine.log("hardware rules: zapis odmietnuty — #{@write_block_reason}")
        end
        true
      end

      # KOV-F1: DRUHA zapisova brana — kniznica z NOVSIEHO pluginu. Vyhodnocuje
      # sa POD ZAMKOM nad cerstvym stavom suboru (rovnako ako degradovany
      # subor) a `@write_block_reason` LEN doplna: ked uz blokovala degradacia,
      # sem sa vobec nedojde.
      def newer_write_blocked?
        # POSKODENY subor sem NEPATRI: `JsonFileStore.read` nad nim vyhodi
        # ParserError a jeho vlastnu branu drzi `degraded_write_blocked?`
        # (a bez zalohy sa dnes prvym zapisom SAMOOPRAVI — R-11). Neprecitatelny
        # dokument teda NIE JE „z novsej verzie".
        doc = begin
          JsonFileStore.read(path, copy: false)
        rescue StandardError
          nil
        end
        return false unless doc_std_unsupported?(doc)

        prev = @write_block_reason
        @write_block_reason = std_block_reason('Globálna knižnica')
        if prev.to_s != @write_block_reason && defined?(Engine)
          Engine.log("hardware rules: zapis odmietnuty — #{@write_block_reason}")
        end
        true
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- projektovy snapshot (NOXUN dict na modeli) -------------------------

      # Pravidla projektu alebo nil, ak model snapshot nema (poskodeny JSON = nil + log).
      def project_rules(model)
        return nil unless model
        raw = model.get_attribute(Store::DICT, MODEL_KEY)
        return nil if raw.nil? || raw.to_s.strip.empty?
        doc = JSON.parse(raw.to_s)
        rules = doc.is_a?(Hash) ? doc['rules'] : nil
        rules.is_a?(Array) ? normalize_rules(rules) : nil
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.project_rules') if defined?(Engine)
        nil
      end

      # Vrati pravidla projektu; ak snapshot chyba, zapise don globalnu kniznicu.
      # VOLAT LEN vnutri otvorenej operacie (build/rebuild) — zapis je sucastou
      # undo kroku, ktory snapshot prvykrat potreboval.
      #
      # KOV-F1 (Codex #329 kolo 2 P1): z NEKOMPATIBILNEJ kniznice (std vyssi nez
      # nas) sa snapshot NEZMRAZI — vzor R-07 `HardwareSets.ensure_project_state!`.
      # Zmrazenie by totiz zapisalo NAS `std` nad obsahom, ktory uz presiel
      # nasou `normalize_rules` (a tá z pásiem drží len `max`/`quantity`), takze
      # buduce polia by ticho zmizli A brana by sa uz nikdy nespustila — zakazka
      # by na starsom pluginu vyzerala zdravo. Stavba bezi DALEJ nad precitanym
      # obsahom (tabulka `bands` je forward-citatelna zamerne, nikdy nevrati
      # nulu), ale prizna sa ORANGE `hardware_rules_library_incompatible`
      # (`CabinetBuilder.attach_rules_state_warning!`) + zapis do logu.
      def ensure_project_rules!(model)
        existing = project_rules(model)
        return existing if existing

        rules, blocked = load_state
        if blocked
          if defined?(Engine)
            Engine.log('hardware rules: snapshot projektu sa NEZMRAZIL — ' \
                       "#{std_block_reason('Globálna knižnica')}")
          end
          return rules
        end
        set_project_rules(model, rules) if model
        rules
      end

      # KOV-F1 (Codex #329 kolo 2 P1): stav „projekt este nema vlastne pravidla
      # a globalna kniznica sa neda bezpecne zmrazit". JEDINA autorita otazky —
      # pyta sa jej builder (ORANGE) aj testy; poradie podmienok je dolezite
      # (model so snapshotom je zdravy bez ohladu na kniznicu).
      def library_incompatible_without_snapshot?(model)
        return false if project_rules(model)

        library_std_unsupported?
      end

      # D1b (audit F4): VEDOMA akcia "Doplnit nove predvolene pravidla" —
      # jedina cesta, ktorou sa novy seed dostane do EXISTUJUCEHO projektu
      # (snapshot sa NIKDY nemerguje sam). Doplni chybajuce rule_id + obnovi
      # pravidla bajtovo zhodne so starym seed tvarom (LEGACY_SEED_SHAPES —
      # napr. seria vysuvov v1 -> Atira rad); pouzivatelske upravy nedotknute.
      # Volat VNUTRI operacie. -> [:none|:updated, added_ids, refreshed_ids]
      def merge_project_seed!(model)
        existing = project_rules(model)
        return [:none, [], []] if existing.nil? # bez snapshotu berie projekt globál sám
        rules, added_ids, refreshed_ids = project_seed_plan(existing)
        return [:none, [], []] if added_ids.empty? && refreshed_ids.empty?
        set_project_rules(model, rules)
        [:updated, added_ids, refreshed_ids]
      end

      # CISTA funkcia (ziadny zapis): co by seed-merge urobil so snapshotom.
      # -> [vysledne pravidla, added_ids, refreshed_ids].
      # D-90 (Codex #144 P1): volajuci (RulesDialog) potrebuje vediet DOPREDU,
      # ci sa nieco zmeni — zapis snapshotu totiz musi prebehnut V TEJ ISTEJ
      # operacii ako PRESTAVBA skriniek (inak by nove pravidlo nedostalo
      # ulozene config.hardware[] a nakup by o nom nevedel).
      def project_seed_plan(existing)
        return [[], [], []] unless existing.is_a?(Array)
        seed_by_id = {}
        SEED_RULES.each { |r| seed_by_id[r['rule_id']] = r }
        refreshed_ids = []
        refreshed = existing.map do |r|
          rid = r['rule_id']
          next r unless seed_by_id[rid] && legacy_seed_shape?(r)
          refreshed_ids << rid
          normalize_rules([seed_by_id[rid]]).first
        end
        have = {}
        refreshed.each { |r| have[r['rule_id']] = true }
        missing = seed_additions(refreshed, have)
        [refreshed + normalize_rules(missing), missing.map { |r| r['rule_id'] }, refreshed_ids]
      end

      # D-90: rule_id pravidiel, ktore reaguju na priznak profilu (SEED sada).
      # Pouziva ich CabinetBuilder na upratanie mrtvych overridov po vypnuti
      # profilu; vlastne (premenovane) pravidlo si pouzivatel spravuje sam —
      # mazat cudzie zaznamy by bolo horsie nez ich nechat.
      def profile_rule_ids
        SEED_RULES.select { |r| r['kind'] == KIND_PROFILE }.map { |r| r['rule_id'] }
      end

      # KOV-F1: je PROJEKTOVY snapshot z novsej verzie formatu? Citanie
      # (`project_rules`) ho pusta dalej — stavba musi bezat — ale zapis sa
      # odmietne, aby sa nezvecnila strata poli, ktorym nerozumieme.
      def project_std_unsupported?(model)
        doc_std_unsupported?(project_doc(model))
      end

      # SUROVY projektovy dokument pravidiel (Hash) alebo nil. JEDINE miesto,
      # ktore modelovy atribut parsuje kvoli otazkam o VERZII formatu — dva
      # samostatne citace by sa casom rozisli.
      def project_doc(model)
        return nil unless model

        raw = model.get_attribute(Store::DICT, MODEL_KEY)
        return nil if raw.nil? || raw.to_s.strip.empty?

        doc = JSON.parse(raw.to_s)
        doc.is_a?(Hash) ? doc : nil
      rescue StandardError
        nil
      end

      # `std` dokumentu s pravidlami, alebo nil (dokument ziadne pravidla
      # nenesie / sa neda precitat). Chybajuci kluc = najstarsi format (1) —
      # rovnaky vyklad ako `doc_std_unsupported?`.
      def doc_std(doc)
        return nil unless doc.is_a?(Hash) && doc['rules'].is_a?(Array)

        doc.key?('std') ? doc['std'].to_i : 1
      end

      # KOV-F1 (Codex #329 kolo 3 P1): su UCINNE pravidla projektu este SPRED
      # Noxun tabulky zavesov? Rozhoduje PROJEKTOVY snapshot; ked ho projekt
      # nema, dedi globalnu kniznicu, takze rozhoduje ona. Neznamy/poskodeny
      # stav = false (fallback su `SEED_RULES`, tie tabulku uz nesu).
      #
      # PRECO `std` A NIE OBSAH PRAVIDLA: vedomy pouzivatelsky rule bez guardov
      # ULOZENY PO F1 je rozhodnutie, nie zaostalost — a kazdy zapis snapshotu
      # (Ulozit v Pravidlach aj „Doplniť nové predvoľby") pecati aktualny `std`.
      def pre_hinge_table_rules?(model)
        std = doc_std(project_doc(model))
        std = library_doc_std if std.nil?
        return false if std.nil?

        std < HINGE_TABLE_STD
      end

      def library_doc_std
        doc_std(JsonFileStore.read(path, copy: false))
      rescue StandardError
        nil
      end

      # Zapise projektovy snapshot (editor pravidiel / ensure). Volajuci drzi operaciu.
      def set_project_rules(model, rules)
        return false unless model
        if project_std_unsupported?(model)
          Engine.log("hardware rules: #{std_block_reason('Snapshot projektu')}") if defined?(Engine)
          return false
        end
        doc = { 'std' => STD, 'seed_version' => SEED_VERSION, 'rules' => normalize_rules(rules) }
        model.set_attribute(Store::DICT, MODEL_KEY, doc.to_json)
        true
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.set_project_rules') if defined?(Engine)
        false
      end

      # --- evaluacia ----------------------------------------------------------

      # Vyhodnoti pravidla nad planom korpusu. CISTA funkcia (ziadne IO):
      #   cfg   — normalizovana konfiguracia korpusu (kvoli hardware_overrides)
      #   parts — ZIVE dielce planu (PO vyradeni degenerovanych — na mrtve celo
      #           nesmie vzniknut kovanie)
      #   ctx   — string-keyed kontext korpusu (CONTEXT_KEYS + 'support')
      #   rules — normalizovane pole pravidiel (projektovy snapshot / test injection)
      # Vrati { items: [hw string-keyed], warnings: [] }. Poradie deterministicke:
      # pravidla v poradi kniznice, dielce v poradi planu.
      # KOV-C2b (R2 exkluzivita): `suppress_slide_owners` = { owner_part_key => true }
      # pre cela, ktore uz maju polozku vysuvu Z RECEPTU. Pravidla typu `slide`
      # sa na nich NEVYHODNOCUJU — inak by zasuvka mala dva vysuvy (jeden
      # z receptu s kitom, jeden legacy bez dielcov). Potlacenie sa prizna
      # JEDNYM info warningom na stavbu (nie na kazde celo).
      SLIDE_OUTPUT = 'slide'

      # KOV-F1: typ kovania, pri ktorom je PREKRYV dvoch zapnutych pravidiel na
      # tej istej role chyba, nie moznost. Dvoje zavesov na tych istych
      # dvierkach = dvojity nakup a nikto by to nezbadal, preto sa uplatni PRVE
      # v poradi a druhe sa PRIZNA (ORANGE). Uzko na `hinge` zamerne: dve
      # uchytkove pravidla (`handle`) na jednej role su legitimny stav.
      OVERLAP_OUTPUT = 'hinge'

      def evaluate(cfg, parts, ctx, rules:, suppress_slide_owners: {})
        items = []
        warnings = []
        seen_ids = {}
        seen_overlap = {}
        suppress = suppress_slide_owners.is_a?(Hash) ? suppress_slide_owners : {}
        suppressed = [] # kluce ciel, na ktorych legacy pravidlo vysuvu nebezalo
        Array(rules).each do |rule|
          next unless rule.is_a?(Hash)
          rid = rule['rule_id'].to_s
          next if rid.empty?
          if seen_ids[rid]
            warnings << BuildPlan.warning('hardware_rule_duplicate',
                                          "Pravidlo kovania '#{rid}' je v knižnici viackrát — použité je prvé.",
                                          severity: 'info', data: { 'rule_id' => rid })
            next
          end
          seen_ids[rid] = true
          next if rule['enabled'] == false
          unless KINDS.include?(rule['kind'].to_s) && BuildPlan::GENERIC_TYPES.include?(rule['output'].to_s)
            warnings << BuildPlan.warning('hardware_rule_skipped',
                                          "Pravidlo kovania '#{rid}' má neznámy kind/output — preskočené (novšia verzia pravidiel?).",
                                          severity: 'info',
                                          data: { 'rule_id' => rid, 'kind' => rule['kind'].to_s,
                                                  'output' => rule['output'].to_s })
            next
          end
          if rule['output'].to_s == OVERLAP_OUTPUT
            role = (rule['applies_to'] || {})['role'].to_s
            if seen_overlap[role]
              warnings << BuildPlan.warning(
                'hardware_rule_overlap',
                "Pravidlo kovania '#{rid}' je druhé pravidlo závesov pre tú istú rolu — " \
                "použije sa prvé („#{seen_overlap[role]}“). Vypni jedno z nich v Pravidlách kovania.",
                data: { 'rule_id' => rid, 'used_rule_id' => seen_overlap[role], 'role' => role }
              )
              next
            end
            seen_overlap[role] = rid
          end
          apply_rule(rule, cfg || {}, parts, ctx, items, warnings, suppress, suppressed)
        end
        warnings.concat(profile_rule_warnings(parts, rules))
        unless suppressed.empty?
          warnings << BuildPlan.warning(
            'legacy_slide_suppressed',
            "Zásuvky s receptom (#{suppressed.length} ks) dostali výsuv z receptu — pôvodné pravidlo " \
            'výsuvov sa na ne nepoužilo (jeden výsuv na zásuvku).',
            severity: 'info', data: { 'owners' => suppressed }
          )
        end
        final = apply_overrides(items, cfg[:hardware_overrides])
        # KOV-F1: door guardy bezia AZ NAD VYSLEDNYMI polozkami — hmotnostna
        # kontrola sa pyta na pocet PO rucnom zamku (Sol audit kolo 2) a
        # konflikt „mimo tabulky" musi rucny zamok ZHASNUT. Zamok sa hlada
        # v RUCNYCH ZASAHOCH, nie na polozke (Codex #329 kolo 2 P2).
        guards = door_guards(final, parts, rules, cfg[:hardware_overrides])
        warnings.concat(guards[:warnings])
        { items: final, warnings: warnings, conflicts: guards[:conflicts] }
      end

      # === KOV-F1: KONTROLY DVIEROK NAD VYSLEDNYMI POLOZKAMI ==================
      #
      # CISTA funkcia (ziadne IO). Vracia { warnings: [], conflicts: [] }:
      #   * ORANGE varovania, ktore POCET NEMENIA (`door_wide`,
      #     `door_wider_than_high`, `hinge_weight_more`, `hinge_weight_max`) —
      #     a INFO `hinge_weight_unknown`, ked plan hmotnost nepozna,
      #   * KONFLIKT `door_height_out_of_table` pre dvierka nad poslednym
      #     pasmom pravidla s `finite`.
      #
      # PRECO AZ TU a nie v `compute`: `compute` bezi PRED `apply_overrides`,
      # takze by hmotnostne pasmo porovnavalo s poctom z pravidla (nie s tym,
      # co si pouzivatel zamkol) a konflikt by sa nedal zhasnut zamkom.
      def door_guards(items, parts, rules, overrides = nil)
        by_rule = {}
        # Codex #329 kolo 1 P2: pri DUPLICITNOM `rule_id` pouziva `evaluate`
        # PRVE pravidlo (druhe prizna ORANGE `hardware_rule_duplicate`
        # a preskoci). Zapis „posledny vyhrava" by sem priniesol guardy
        # z INEHO pravidla, nez ktore polozku vydalo — teda falosnu RED
        # nadvysku alebo naopak potlacene varovania. FIRST-ENTRY-WINS.
        Array(rules).each do |r|
          next unless r.is_a?(Hash)

          rid = r['rule_id'].to_s
          by_rule[rid] = r unless by_rule.key?(rid)
        end
        by_owner = {}
        Array(parts).each do |pd|
          next unless pd.is_a?(Hash)

          by_owner[PartKeys.for_descriptor(pd)] = pd
        end
        warnings = []
        conflicts = []
        Array(items).each do |it|
          rule = by_rule[it['rule_id'].to_s]
          next unless rule.is_a?(Hash) && rule['kind'].to_s == 'bands'
          next unless DOOR_GUARD_KEYS.any? { |k| rule.key?(k) }

          pd = by_owner[it['owner_part_key'].to_s]
          next if pd.nil?

          door_guard_warnings(rule, it, pd, warnings)
          c = out_of_table_conflict(rule, it, pd, overrides)
          conflicts << c if c
        end
        { warnings: warnings, conflicts: conflicts }
      end

      def door_guard_warnings(rule, it, pd, warnings)
        owner = it['owner_part_key'].to_s
        who = door_label(pd)
        w = part_dim(pd, :width)
        h = part_dim(pd, :length)
        limit = rule['width_warn_over']
        if limit.is_a?(Numeric) && w && w > limit.to_f
          warnings << BuildPlan.warning(
            'door_wide', "#{who}: šírka #{fmt_mm(w)} mm je nad odporúčaných #{fmt_mm(limit)} mm — " \
                         'skontroluj závesy a uchytenie.',
            part_key: owner, data: { 'width' => w, 'limit' => limit.to_f }
          )
        end
        if w && h && w > h
          warnings << BuildPlan.warning(
            'door_wider_than_high',
            "#{who}: šírka #{fmt_mm(w)} mm je väčšia než výška #{fmt_mm(h)} mm — nemá to byť výklop?",
            part_key: owner, data: { 'width' => w, 'height' => h }
          )
        end
        weight_guard_warnings(rule, it, pd, who, owner, warnings)
      end

      # Hmotnostne pasma Hettich. VO V1 LEN VARUJU (Michal 8.9.2026): pocet
      # riadi tabulka vysok, hmotnost hovori „skontroluj". Prepnutie na
      # automaticke +1 neskor nepotrebuje zmenu dat, len tejto vetvy.
      def weight_guard_warnings(rule, it, pd, who, owner, warnings)
        bands = rule['weight_bands']
        return unless bands.is_a?(Array) && !bands.empty?

        kg = pd[:weight_kg]
        unless kg.is_a?(Numeric) && kg.to_f.finite?
          warnings << BuildPlan.warning(
            'hinge_weight_unknown', "#{who}: hmotnosť dvierok nie je známa — počet závesov je len podľa výšky.",
            part_key: owner, severity: 'info', data: { 'rule_id' => rule['rule_id'].to_s }
          )
          return
        end

        kg = kg.to_f
        band = bands.find { |b| b['max'].nil? || kg <= b['max'].to_f }
        top = bands.reject { |b| b['max'].nil? }.map { |b| b['max'].to_f }.max
        if band.nil?
          warnings << BuildPlan.warning(
            'hinge_weight_max',
            "#{who}: hmotnosť #{fmt_mm(kg)} kg je nad maximom #{fmt_mm(top)} kg pre tento typ závesu — " \
            'rozdeľ čelo alebo vyber iný záves.',
            part_key: owner, data: { 'weight_kg' => kg, 'max_kg' => top }
          )
          return
        end
        want = clamp_qty(band['quantity']).to_i
        return if want <= it['quantity'].to_i

        warnings << BuildPlan.warning(
          'hinge_weight_more',
          "#{who}: pri hmotnosti #{fmt_mm(kg)} kg odporúča výrobca #{want} závesov, " \
          "vyšlo #{it['quantity'].to_i} — skontroluj.",
          part_key: owner, data: { 'weight_kg' => kg, 'want' => want, 'quantity' => it['quantity'].to_i }
        )
      end

      # Dvierka NAD tabulkou: polozka uz existuje (s poctom catch-all pasma),
      # takze v Kovani je riadok, na ktorom sa da pocet rucne zamknut — a prave
      # ten zamok konflikt zhasina.
      #
      # Codex #329 kolo 2 P2: zhasina LEN SKUTOCNY ZAMOK POCTU, nie hocijaky
      # rucny zasah. `source: 'manual'` nesie polozka aj po overridee, ktory
      # menil IBA `nominal_length` (importovany/legacy zaznam) — a taky zaznam
      # o pocte nepovedal NIC, takze catch-all pocet by presiel branami bez
      # slova. Otazka preto ide do RUCNYCH ZASAHOV: existuje pre tuto polozku
      # zaznam s PLATNYM polom `quantity`? (Zhoda a poradie „posledny vyhrava"
      # su TIE ISTE ako v `apply_overrides` — inak by sa vyklad rozisiel.)
      def out_of_table_conflict(rule, it, pd, overrides = nil)
        return nil unless rule['finite'] == true
        return nil if quantity_locked?(overrides, it)

        bands = Array(rule['bands'])
        top = bands.reject { |b| b['max'].nil? }.map { |b| b['max'].to_f }.max
        return nil if top.nil?

        h = part_dim(pd, :length)
        return nil if h.nil? || h <= top

        { 'owner_part_key' => it['owner_part_key'].to_s, 'code' => DOOR_OUT_OF_TABLE,
          'message' => "#{door_label(pd)}: výška #{fmt_mm(h)} mm je nad tabuľkou závesov " \
                       "(posledné pásmo #{fmt_mm(top)} mm) — počet #{it['quantity'].to_i} je len " \
                       'posledné pásmo. Zamkni počet ručne v Kovaní alebo rozdeľ čelo.' }
      end

      # Codex #329 kolo 2 P2: ma polozka ZAMKNUTY POCET rucnym zasahom?
      # JEDINA autorita otazky (nie `source == 'manual'` — to je siroky priznak
      # „nieco tu clovek zmenil"). Vyklad hodnoty je `clamp_qty`, teda presne
      # ten, ktory pocet aj prepisuje; `disabled` zaznam zamok nie je (polozka
      # by vobec nevznikla).
      def quantity_locked?(overrides, item)
        ov = Array(overrides).select { |o| o.is_a?(Hash) && override_match?(o, item) }.last
        return false if ov.nil? || ov['disabled'] == true

        !clamp_qty(ov['quantity']).nil?
      end

      def door_label(pd)
        name = pd.is_a?(Hash) ? pd[:name].to_s.strip : ''
        name.empty? ? 'Dvierka' : "Dvierka „#{name}“"
      end

      # D-90 ORANGE `profile_rule_missing`: dielec MA uchytkovy profil, ale
      # PROJEKTOVY snapshot pravidiel pre jeho rolu ziadne pravidlo typu
      # part_flag_length nepozna — profil by ticho vypadol zo supisu aj z nakupu.
      # Snapshot sa nikdy nemerguje sam (reprodukovatelnost stavby z .skp),
      # naprava je vedoma akcia „Doplniť nové predvolené" v Pravidlach kovania.
      #
      # VEDOME: pravidlo, ktore v snapshote JE, ale je VYPNUTE (enabled false)
      # alebo vyradene overridom, warning NESPUSTA — vypnute kovanie kryje
      # vlastny existujuci ORANGE (semafor, kategoria hardware).
      def profile_rule_warnings(parts, rules)
        roles = {}
        Array(rules).each do |r|
          next unless r.is_a?(Hash) && r['kind'].to_s == KIND_PROFILE
          role = (r['applies_to'] || {})['role'].to_s
          roles[role] = true unless role.empty?
        end
        Array(parts).filter_map do |pd|
          next nil unless pd.is_a?(Hash)
          prof = FrontProfiles.of(pd)
          next nil if prof.nil?
          next nil if roles[pd[:role].to_s]
          name = pd[:name].to_s.strip
          who = name.empty? ? 'Dielec' : "Dielec „#{name}“"
          BuildPlan.warning('profile_rule_missing',
                            "#{who} má úchytkový profil (#{FrontProfiles.name(prof)}), ale projekt " \
                            'nemá pravidlo kovania pre profil — profil sa nedostane do súpisu ani ' \
                            'do nákupu. Otvor Pravidlá kovania a klikni „Doplniť nové predvolené".',
                            part_key: PartKeys.for_descriptor(pd),
                            data: { 'profile' => prof, 'role' => pd[:role].to_s })
        end
      end

      # Aplikuje jedno pravidlo: korpusova uroven (owner nil) alebo per dielec roly.
      # cfg putuje az do compute — fit_series musi vediet o rucnom NL zamku (D-93).
      def apply_rule(rule, cfg, parts, ctx, items, warnings, suppress = {}, suppressed = [])
        role = (rule['applies_to'] || {})['role'].to_s
        if role == 'cabinet'
          supports = Array((rule['applies_to'] || {})['support']).map(&:to_s)
          return if supports.any? && !supports.include?(ctx['support'].to_s)
          # D1 (GH #125 P2): predikat typu korpusu — support 'none' nerozlisuje
          # hornu skrinku od spodnej bez noh (Bystrica ide LEN na horne).
          kinds = Array((rule['applies_to'] || {})['cabinet_type']).map(&:to_s)
          return if kinds.any? && !kinds.include?(ctx['cabinet_type'].to_s)
          emit(rule, nil, ctx, nil, items, warnings, cfg)
        else
          slide = rule['output'].to_s == SLIDE_OUTPUT
          parts.each do |pd|
            next unless pd[:role].to_s == role
            owner = PartKeys.for_descriptor(pd)
            # KOV-C2b R2: celo s receptovym vysuvom legacy `slide` pravidlo
            # NEDOSTANE (ani ked recept skoncil konfliktom — fail-closed).
            if slide && suppress[owner]
              suppressed << owner unless suppressed.include?(owner)
              next
            end
            emit(rule, owner, ctx, pd, items, warnings, cfg)
          end
        end
      end

      # Vypocita pocet + params a prida polozku (string kluce — JSON round-trip
      # cez config korpusu bez konverzii, ako warnings).
      def emit(rule, owner, ctx, pd, items, warnings, cfg = {})
        qty, params = compute(rule, ctx, pd, owner, warnings, cfg)
        return if qty.nil?
        # Poradie merge: kontextove params (deklarativne z pravidla) a AZ POTOM
        # odvodene params dielca — tie su autoritativne (front_height je vyska
        # KONKRETNEHO cela, ziadna korpusova hodnota ju nesmie prebit).
        params = params.merge(context_params(rule, ctx)).merge(part_params(rule, pd))
        items << {
          'owner_part_key'   => owner,
          'generic_type'     => rule['output'].to_s,
          'quantity'         => qty,
          'rule_id'          => rule['rule_id'].to_s,
          'variant_id'       => nil,
          'production_class' => 'counted',
          'manufactured'     => true,
          'params'           => params,
          'source'           => 'rule',
          'rule_quantity'    => qty
        }
      end

      # Vzory vypoctu. Vrati [quantity, params] alebo [nil, _] = polozka nevznikne.
      def compute(rule, ctx, pd, owner, warnings, cfg = {})
        case rule['kind'].to_s
        when 'fixed'
          [clamp_qty(rule['quantity']), {}]
        when 'bands'
          v = input_value(rule, ctx, pd, owner, warnings)
          return [nil, {}] if v.nil?
          band = Array(rule['bands']).find { |b| b['max'].nil? || v <= b['max'].to_f }
          if band.nil?
            warnings << BuildPlan.warning('hardware_rule_skipped',
                                          "Pravidlo '#{rule['rule_id']}' nemá pásmo pre hodnotu #{v.round(1)} — položka nevznikla.",
                                          part_key: owner, severity: 'info',
                                          data: { 'rule_id' => rule['rule_id'].to_s, 'value' => v })
            return [nil, {}]
          end
          # KOV-F1: sirsie kridlo dostane +1 (guard z praxe, BEZ podmienky
          # vysky — plati aj pre siroke nizke dvere). Bez kluca sa nic nemeni,
          # takze stary tvar pravidla rata presne ako doteraz.
          [clamp_qty(band['quantity'].to_i + width_plus_for(rule, pd)), {}]
        when 'fit_series'
          v = input_value(rule, ctx, pd, owner, warnings)
          return [nil, {}] if v.nil?
          budget = v - rule['clearance'].to_f
          nl = Array(rule['series']).map(&:to_f).select { |s| s <= budget }.max
          # D-93: rucny zamok NL (existencia platneho pola v override zazname).
          manual = override_nominal_length(cfg, owner, rule)
          if manual && manual > budget
            # ORANGE „skontroluj" — NEBLOKUJE (Michal moze vedome, napr. ina montaz).
            warnings << BuildPlan.warning('hardware_manual_no_fit',
                                          "#{label_for(rule['output'])}: ručne zamknutá dĺžka #{fmt_mm(manual)} mm sa do svetlej hĺbky #{fmt_mm(v)} mm nezmestí (rezerva #{fmt_mm(rule['clearance'].to_f)} mm) — skontroluj.",
                                          part_key: owner,
                                          data: { 'rule_id' => rule['rule_id'].to_s, 'available' => v,
                                                  'clearance' => rule['clearance'].to_f,
                                                  'nominal_length' => manual })
          end
          if nl.nil?
            # B1: so zamkom polozka VZNIKNE aj tak — NL doplni apply_overrides,
            # rule_nominal_length ostane nil („automat nevie"). Bez zamku plati
            # povodne spravanie (polozka nevznikne + hardware_no_fit).
            return [clamp_qty(rule.fetch('quantity', 1)), {}] if manual
            warnings << BuildPlan.warning('hardware_no_fit',
                                          "#{label_for(rule['output'])}: do svetlej hĺbky #{v.round(1)} mm sa nezmestí žiadna dĺžka z radu (rezerva #{rule['clearance'].to_f.round(1)} mm).",
                                          part_key: owner,
                                          data: { 'rule_id' => rule['rule_id'].to_s, 'available' => v,
                                                  'clearance' => rule['clearance'].to_f })
            return [nil, {}]
          end
          [clamp_qty(rule.fetch('quantity', 1)), { 'nominal_length' => nl }]
        when KIND_PROFILE
          # D-90: bez priznaku profilu polozka NEVZNIKNE (ziadny warning — je to
          # bezny stav, cela bez profilu su vacsina).
          flag_params = flag_length_params(pd)
          return [nil, {}] if flag_params.empty?
          [clamp_qty(rule.fetch('quantity', 1)), flag_params]
        end
      end

      # KOV-F1: pripocitanie za SIRKU dielca (0 = pravidlo guard nema alebo
      # dielec nie je dost siroky). Sirka = `pd[:prod][:width]`, teda pri
      # dvierkach sirka KRIDLA (deskriptor `Fronts.box_desc`).
      def width_plus_for(rule, pd)
        wp = rule['width_plus']
        return 0 unless wp.is_a?(Hash)

        w = part_dim(pd, :width)
        return 0 if w.nil? || w <= wp['over'].to_f

        wp['add'].to_i
      end

      # Vyrobny rozmer dielca (Float) alebo nil. Jedno miesto — door guardy sa
      # nesmu rozist s tym, co ratala `compute`.
      def part_dim(pd, key)
        prod = pd.is_a?(Hash) && pd[:prod].is_a?(Hash) ? pd[:prod] : nil
        v = prod && prod[key]
        v.is_a?(Numeric) && v.to_f.finite? ? v.to_f : nil
      end

      # Hodnota vstupu: prod rozmery dielca (height/width cela) pred kontextom korpusu.
      # KOV-W: 'weight' = hmotnost dielca (kg) z anotacie planu. Ked plan bezal
      # BEZ hustot (stari volajuci), kluc na deskriptore nie je — vtedy plati
      # existujuca cesta „neznamy vstup": polozka NEVZNIKNE + info warning.
      def input_value(rule, ctx, pd, owner, warnings)
        input = rule['input'].to_s
        v =
          if pd && input == 'height'
            pd[:prod] && pd[:prod][:length]
          elsif pd && input == 'width'
            pd[:prod] && pd[:prod][:width]
          elsif pd && input == INPUT_WEIGHT
            pd[:weight_kg]
          else
            ctx[input]
          end
        return v.to_f if v.is_a?(Numeric)
        warnings << BuildPlan.warning('hardware_rule_skipped',
                                      "Pravidlo '#{rule['rule_id']}' má neznámy vstup '#{input}' — preskočené.",
                                      part_key: owner, severity: 'info',
                                      data: { 'rule_id' => rule['rule_id'].to_s, 'input' => input })
        nil
      end

      # H1a (audit FIX 5): params odvodene z DIELCA-vlastnika. Zatial jedine
      # 'front_height' pre vysuvy — vyska konkretneho cela v okamihu evaluacie.
      # Set potom vie vybrat bocnicu per celo (D-81); params_from_context by to
      # neuniesol, ten cita LEN korpusovy kontext (jedna hodnota na skrinku).
      # Ked vyska nie je k dispozicii, kluc NEVZNIKNE — selector potom korektne
      # spadne do ORANGE namiesto hadania pasma.
      FRONT_ROLES = %w[front_door drawer_front flap cover_panel false_front].freeze

      # KOV-F1: KLASIFIKACIA POLOZKY ZAVESU. Set sa vybera podla SPOSOBU
      # OTVARANIA cela (Tip-On dvierka chcu P2O set s piestom), takze polozka
      # musi otvaranie NIEST — expanzia si ho z modelu uz nema odkial vziat.
      # Hodnota pochadza z anotacie planu (`Construction.annotate_front_modes!`,
      # vzor KOV-W `weight_kg`); dielec bez nej je LEGACY celo a plati
      # `classic` (rovnaky vyklad ako `Fronts`: chybajuci kluc = klasicke).
      # `use_type` je DRUHA polovica klasifikacie — expanzia ju porovnava so
      # setom (`door` set na dvierka), aby sa nikdy neobjednal zasuvkovy kit.
      HINGE_OUTPUT   = 'hinge'
      DOOR_USE_TYPE  = 'door'
      DEFAULT_OPENING_MODE = 'classic'

      def part_params(rule, pd)
        # D-90: params dlzkoveho priznaku su odvodene z DIELCA — musia byt
        # autoritativne (params_from_context ich nikdy neprebije), preto sa
        # re-asertuju TU, v poslednom merge kroku. Jeden vypocet (flag_length_params).
        return flag_length_params(pd) if rule['kind'].to_s == KIND_PROFILE
        return hinge_params(pd) if rule['output'].to_s == HINGE_OUTPUT
        return {} unless rule['output'].to_s == 'slide'
        return {} unless pd.is_a?(Hash) && FRONT_ROLES.include?(pd[:role].to_s)
        v = pd[:prod].is_a?(Hash) ? pd[:prod][:length] : nil
        return {} unless v.is_a?(Numeric) && v.to_f.finite? && v.to_f.positive?
        { 'front_height' => v.to_f.round(2) }
      end

      # Klasifikacia polozky zavesu. KORPUSOVA uroven (pd nil) ju nedostane —
      # zaves bez dielca nema otvaranie, na ktore by sa dal vybrat set.
      def hinge_params(pd)
        return {} unless pd.is_a?(Hash)

        om = pd[:opening_mode].to_s.strip
        { 'use_type' => DOOR_USE_TYPE,
          'opening_mode' => (om.empty? ? DEFAULT_OPENING_MODE : om) }
      end

      # D-90: params polozky dlzkoveho priznaku (uchytkovy profil).
      # cut_length_mm = SIRKA dielca (prod width) — rez profilu je sirka kridla/cela.
      # Prazdny hash = dielec priznak nema (alebo nema pouzitelnu sirku) -> polozka nevznikne.
      def flag_length_params(pd)
        return {} unless pd.is_a?(Hash)
        prof = FrontProfiles.of(pd)
        return {} if prof.nil?
        v = pd[:prod].is_a?(Hash) ? pd[:prod][:width] : nil
        return {} unless v.is_a?(Numeric) && v.to_f.finite? && v.to_f.positive?
        { LENGTH_PARAM => v.to_f.round(2), 'profile' => prof }
      end

      # D-90 (audit F5): SERVEROVY format params pre zobrazenie — „rez 597 mm".
      # JEDINA autorita textu (sekcia Nakup kovania v Studiu aj CSV kovania ho
      # len vypisu; JS si nic neformatuje). nil = polozka nema co zobrazit
      # navyse.
      def params_label(params)
        return nil unless params.is_a?(Hash)
        v = params[LENGTH_PARAM] || params[LENGTH_PARAM.to_sym]
        return nil unless v.is_a?(Numeric) && v.to_f.finite? && v.to_f.positive?
        "rez #{fmt_mm(v)} mm"
      end

      # Cele mm bez desatin, inak 1 desatinne miesto (slovenska ciarka).
      def fmt_mm(v)
        f = v.to_f
        (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f).tr('.', ',')
      end

      # Deklarativne params z kontextu: {"height": "floor_height"} -> params['height']=ctx['floor_height'].
      def context_params(rule, ctx)
        map = rule['params_from_context']
        return {} unless map.is_a?(Hash)
        map.each_with_object({}) do |(target, source), out|
          v = ctx[source.to_s]
          out[target.to_s] = v.to_f if v.is_a?(Numeric)
        end
      end

      # Rucne zasahy z configu korpusu. Match = (owner, generic_type, rule_id);
      # disabled -> polozka von; quantity -> prepis poctu; nominal_length (D-93) ->
      # prepis params. Polia su NEZAVISLE, jeden zaznam ich moze niest viac.
      def apply_overrides(items, overrides)
        list = Array(overrides).select { |ov| ov.is_a?(Hash) }
        return items if list.empty?
        items.filter_map do |it|
          ov = list.select { |o| override_match?(o, it) }.last
          next it unless ov
          next nil if ov['disabled'] == true
          out = it
          # D-93: rucna NL. rule_nominal_length = hodnota automatu (nil = automat
          # nevie; polozka vznikla LEN vdaka zamku — B1).
          nl = override_nl(ov['nominal_length'].nil? ? ov[:nominal_length] : ov['nominal_length'])
          if nl
            params = (out['params'].is_a?(Hash) ? out['params'] : {})
            rule_nl = params['nominal_length']
            out = out.merge('params' => params.merge('nominal_length' => nl),
                            'source' => 'manual',
                            'rule_nominal_length' => (rule_nl.is_a?(Numeric) ? rule_nl.to_f : nil))
          end
          q = clamp_qty(ov['quantity'])
          # ZAMERNE aj pri q == rule_quantity: kym zaznam existuje v configu, polozka
          # MUSI byt oznacena source 'manual' (UI ukaze reset). Inak by override splynul
          # s pravidlom, reset by zmizol a stale zaznam by necakane ozil pri buducej
          # zmene pravidla ci rozmerov (Codex review PR #24).
          out = out.merge('quantity' => q, 'source' => 'manual') if q
          out
        end
      end

      # D-93: JEDINA autorita hodnoty NL overridu (strict). Konecny kladny Float,
      # zaokruhleny na 2 desatinne miesta (mm Float, standard §2); cokolvek ine
      # (String, nil, nula, NaN) = nie je override. Citaciu aj zapisovu cestu
      # (builder normalize, evaluacia, panel callback) obsluhuje TATO funkcia.
      def override_nl(v)
        return nil unless v.is_a?(Numeric)
        f = v.to_f
        return nil unless f.finite? && f.positive?
        f.round(2)
      end

      # Platny NL override pre (owner, output, rule_id) z configu korpusu.
      # disabled zaznam zamok nenesie (polozka aj tak nevznikne).
      def override_nominal_length(cfg, owner, rule)
        list = cfg.is_a?(Hash) ? (cfg[:hardware_overrides] || cfg['hardware_overrides']) : nil
        probe = { 'owner_part_key' => owner, 'generic_type' => rule['output'].to_s,
                  'rule_id' => rule['rule_id'].to_s }
        ov = Array(list).select { |o| o.is_a?(Hash) && override_match?(o, probe) }.last
        return nil if ov.nil? || ov['disabled'] == true
        override_nl(ov.key?('nominal_length') ? ov['nominal_length'] : ov[:nominal_length])
      end

      # --- KOV-C2b: OSIROTENY rucny zasah (Codex #304 P1) ---------------------
      #
      # Panel stavia editovatelne riadky Kovania z EMITOVANYCH poloziek, takze
      # zaznam `hardware_overrides`, ku ktoremu ziadna polozka nevznikla, by
      # nemal kde byt — a pouzivatel by ho nevedel zrusit. Tato cista funkcia
      # povie, ci a PRECO zaznam osirel; panel z nej robi riadok s akciou.
      #
      #   nil        — zaznam ma svoju polozku (kresli sa PRI nej)
      #   'disabled' — vypnuta kategoria (D-92): naprava je „obnoviť"
      #   'invalid'  — vlastnik je v ULOZENOM konflikte zasuvky, takze polozka
      #                fail-closed NEVZNIKLA (rucny pocet != 1, vypnutie alebo
      #                zamok NL mimo radu): naprava je ZRUSIT cely zaznam
      #
      # `items` = `config.hardware` (emitovane polozky), `conflict_owners` =
      # `owner_part_key` ciel z `config.drawer_conflicts`.
      def override_orphan_kind(ov, items, conflict_owners)
        return nil unless ov.is_a?(Hash)

        key = override_identity(ov)
        return nil if Array(items).any? { |it| it.is_a?(Hash) && override_identity(it) == key }
        return 'disabled' if ov['disabled'] == true || ov[:disabled] == true
        return 'invalid' if Array(conflict_owners).map(&:to_s).include?(key[0])

        nil
      end

      # Trojica (vlastnik, typ, pravidlo) — identita rucneho zasahu aj polozky.
      def override_identity(rec)
        [(rec['owner_part_key'] || rec[:owner_part_key]).to_s,
         (rec['generic_type'] || rec[:generic_type]).to_s,
         (rec['rule_id'] || rec[:rule_id]).to_s]
      end

      def override_match?(ov, item)
        owner = ov.key?('owner_part_key') ? ov['owner_part_key'] : ov[:owner_part_key]
        owner = nil if owner.to_s.empty?
        owner == item['owner_part_key'] &&
          ov['generic_type'].to_s == item['generic_type'] &&
          ov['rule_id'].to_s == item['rule_id']
      end

      # --- normalizacia -------------------------------------------------------

      # Ocisti pole pravidiel: string kluce, cisla ako Float/Integer, bands sort
      # (null=∞ posledne), series sort+uniq bez nekladnych. Nezname kluce zachova
      # (forward-compat s buducimi verziami formatu).
      def normalize_rules(rules)
        Array(rules).filter_map do |rule|
          next nil unless rule.is_a?(Hash)
          r = deep_copy(stringify(rule))
          next nil if r['rule_id'].to_s.strip.empty?
          r['rule_id'] = r['rule_id'].to_s.strip
          r['enabled'] = r['enabled'] != false
          r['output'] = r['output'].to_s.strip
          r['kind'] = r['kind'].to_s.strip
          r['applies_to'] = r['applies_to'].is_a?(Hash) ? r['applies_to'] : {}
          r['quantity'] = clamp_qty(r['quantity']) || 1 if r.key?('quantity')
          r['bands'] = normalize_bands(r['bands']) if r['bands'].is_a?(Array)
          # KOV-F1: volitelne door guardy. Typovo sa OCISTIA (Float/Integer,
          # pasma zoradene) a neplatny tvar sa ZAHODI — nikdy sa nehada.
          # Starsi plugin ich `normalize_rules` NEPOZNA, ale ZACHOVA (vetva
          # „nezname kluce" nizsie), takze prezuju aj jeho zapis.
          r['finite'] = (r['finite'] == true) if r.key?('finite')
          r['weight_bands'] = normalize_bands(r['weight_bands']) if r['weight_bands'].is_a?(Array)
          normalize_width_plus!(r)
          if r.key?('width_warn_over')
            v = r['width_warn_over'].to_f
            v.finite? && v.positive? ? r['width_warn_over'] = v : r.delete('width_warn_over')
          end
          if r['series'].is_a?(Array)
            r['series'] = r['series'].map(&:to_f).select(&:positive?).uniq.sort
          end
          r['clearance'] = r['clearance'].to_f if r.key?('clearance')
          r
        end
      end

      # Pasma (vyskove aj hmotnostne) v jednom tvare: neplatny pocet = pasmo
      # von, `max` nil = „vsetko nad" a ide POSLEDNE.
      def normalize_bands(raw)
        bands = Array(raw).select { |b| b.is_a?(Hash) && !clamp_qty(b['quantity']).nil? }
                          .map do |b|
                            { 'max' => (b['max'].nil? ? nil : b['max'].to_f),
                              'quantity' => clamp_qty(b['quantity']) }
                          end
        bands.sort_by { |b| b['max'].nil? ? Float::INFINITY : b['max'] }
      end

      # KOV-F1: `width_plus` je DVOJICA (od akej sirky, o kolko kusov) — polovicny
      # ani nekladny tvar sa NEPOUZIJE (radsej ziadny guard nez hadanie).
      def normalize_width_plus!(rule)
        return rule unless rule.key?('width_plus')

        wp = rule['width_plus']
        over = wp.is_a?(Hash) ? wp['over'].to_f : 0.0
        add  = wp.is_a?(Hash) ? clamp_qty(wp['add']) : nil
        if add.nil? || !over.finite? || !over.positive?
          rule.delete('width_plus')
        else
          rule['width_plus'] = { 'over' => over, 'add' => add }
        end
        rule
      end

      # --- odtlacok pravidiel (ŠT-3b-2c2) -------------------------------------
      #
      # Vzor `HardwareCatalog.record_rev`: kratky hash NORMALIZOVANEHO tvaru,
      # ktory server posle klientovi a ten mu ho pri zapise vrati. Sluzi na
      # rozpoznanie „formular bol naplneny z INEJ verzie pravidiel".
      #
      # PRECO NIE JE DOST porovnanie obsahu (`@baseline_rules`): to je hashove
      # porovnanie, teda NECITLIVE na poradie a na kluce, ktore normalizacia
      # zjednoti. Rev je citlivy na PRESNY serializovany tvar — su to DVE
      # vrstvy, nie nahrada (audit C2). Pocita sa VYHRADNE na serveri: klient
      # by ten isty JSON nikdy nezostavil bajtovo rovnako (Ruby `900.0` vs
      # JS `900`), takze klientsky vypocet by NIKDY nesedel.
      # KANONICKY tvar (kluce zoradene) — poradie klucov v hashi je nahodny
      # dosledok toho, odkial zaznam prisiel (JSON zo snapshotu vs. seed
      # v kode), takze bez zoradenia by ten isty stav pravidiel dal ROZNY
      # odtlacok a pouzivatel by dostal „pravidlá sa medzitým zmenili" za nic.
      # Citlivost na to, na com zalezi (hodnoty, poradie PRAVIDIEL, pasma),
      # zoradenie klucov nijako neznizuje.
      def rules_rev(rules)
        Digest::SHA1.hexdigest(JSON.generate(canonical_rules(rules)))[0, 12]
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.rules_rev') if defined?(Engine)
        ''
      end

      # Rekurzivne zoradenie klucov (polia si poradie DRZIA — je vyznamove).
      #
      # Review #224 (Codex P2): hodnota sa berie podla PRITOMNOSTI kluca, nie
      # cez `||`. Pri `false` by totiz `value[k] || value[k.to_sym]` prepadlo na
      # symbolovy kluc (spravidla `nil`), takze `false` a `null` by dali TEN ISTY
      # odtlacok — a suberzna zmena takeho pola (kluce novsej verzie
      # `normalize_rules` ZACHOVAVA) by prekĺzla cez guard.
      def canonical_rules(value)
        case value
        when Hash
          value.keys.map(&:to_s).sort.each_with_object({}) do |k, out|
            raw = value.key?(k) ? value[k] : value[k.to_sym]
            out[k] = canonical_rules(raw)
          end
        when Array then value.map { |v| canonical_rules(v) }
        else value
        end
      end

      # --- validacia pred ULOZENIM (ŠT-3b-2c1) --------------------------------
      #
      # CISTA funkcia (ziadne IO, ziadny zapis): co je na pravidlach take zle,
      # ze sa to NESMIE ulozit? Vracia pole { rule_id, output, message } —
      # prazdne pole = mozno ulozit.
      #
      # PRECO SAMOSTATNA FUNKCIA A NIE `normalize_rules`:
      #   `normalize_rules` ma DVANAST volajucich a vacsina z nich CITA (load,
      #   project_rules, evaluate, seed-merge, migracie). Keby vynucovala tieto
      #   pravidla, LEGACY snapshot z .skp by sa pri citani ticho orezal — teda
      #   presne ta tichá strata dat, ktorej ma validacia zabranit. Zapisova
      #   brana preto stoji SAMOSTATNE a vola ju LEN `RulesDialog.handle_save`,
      #   az PO normalizacii (validuje sa PRESNE to, co sa zapise).
      #
      # CO SA VYNUCUJE (a preco prave to):
      #   * `kind == 'bands'` bez pasma „všetko nad" — rozmer nad poslednym
      #     pasmom nespadne DO ZIADNEHO a polozka pre taku skrinku nevznikne.
      #     Nie je to tiche (kusovnik hlasi `hardware_rule_skipped` a KONTROLA
      #     to ukaze ako ORANGE), ale odmietnut deravy tvar RAZ pri ulozeni je
      #     lacnejsie nez ORANGE na kazdej skrinke zakazky.
      #   * `kind == 'fit_series'` s prazdnym radom — automat nema z coho vybrat.
      #     VEDOMY DOSLEDOK: uzatvara sa tym D-93 vetva „rucny NL zamok pri
      #     prazdnom rade" (zamok mimo radu sa aj tak uz nedal zapisat).
      #
      # KRITERIUM je viazane na `kind`, NIE na pritomnost kluca `bands` — a to
      # preto, ze `kind` je JEDINA autorita toho, ktora vetva vyhodnotenia sa
      # spusti (`evaluate` vetvi podla neho; `normalize_rules` NEZNAME kluce
      # ZACHOVAVA kvoli forward-compat). Zaznam teda smie niest `bands` aj
      # `series` naraz — z novsej verzie formatu, z cudzieho/legacy snapshotu
      # alebo ako zvysok po zmene `kind` vo formulari — a validovat mu treba
      # LEN to, co sa naozaj pouzije. Podla kluca by sa pravidlo odmietlo za
      # pasma, ktore nikdy nepocita.
      #
      # VYPNUTE pravidlo (`enabled == false`) sa NEKONTROLUJE — negeneruje nic,
      # takze deravy tvar nikoho nezasiahne (zhodne s klientskou `rdValidate`).
      def rules_problems(rules)
        Array(rules).filter_map do |rule|
          next nil unless rule.is_a?(Hash)
          next nil if rule['enabled'] == false

          msg = rule_problem_message(rule)
          next nil if msg.nil?

          { 'rule_id' => rule['rule_id'].to_s, 'output' => rule['output'].to_s, 'message' => msg }
        end
      end

      # Hlaska ADRESUJE pravidlo menom, ktore pouzivatel vidi vo formulari —
      # inak by pri desiatich pravidlach nevedel, ktore opravit.
      #
      # Review #223 (Codex P2): samotny `label_for(output)` NESTACI — dve pravidla
      # smu mat rovnaky vystup (napr. dve rozne uchytkove pravidla `handle`)
      # a hlaska by ukazovala na obe naraz. Identitou je `rule_id`, takze ide
      # do zatvorky za nazov.
      def rule_problem_message(rule)
        case rule['kind'].to_s
        when 'bands'
          bands = rule['bands'].is_a?(Array) ? rule['bands'] : []
          return nil if !bands.empty? && bands.any? { |b| b.is_a?(Hash) && b['max'].nil? }

          "#{rule_address(rule)} potrebuje aspoň pásmo „všetko nad“."
        when 'fit_series'
          series = rule['series'].is_a?(Array) ? rule['series'] : []
          return nil unless series.empty?

          "#{rule_address(rule)} potrebuje aspoň jednu dĺžku v rade."
        end
      end

      # „Pravidlo „Výsuvy" (vysuvy-nl-podla-hlbky)" — nazov PRE CLOVEKA
      # a za nim JEDNOZNACNA identita zaznamu.
      def rule_address(rule)
        rid = rule['rule_id'].to_s.strip
        base = "Pravidlo „#{label_for(rule['output'])}“"
        rid.empty? ? base : "#{base} (#{rid})"
      end

      # Pocet vzdy Integer v <1, MAX_HW_QUANTITY>; nil pri nevalidnom vstupe.
      def clamp_qty(v)
        return nil if v.nil? || v.to_s.strip.empty?
        q = v.to_i
        return nil if q < 1
        [q, BuildPlan::MAX_HW_QUANTITY].min
      end

      def label_for(generic_type)
        { 'leg' => 'Nohy', 'hinge' => 'Závesy', 'slide' => 'Výsuv',
          'handle' => 'Úchytky', 'shelf_pin' => 'Podperky', 'connector' => 'Spojky',
          'wall_hanger' => 'Zavesenie na stenu',
          # KOV-B1: typ existuje v slovniku BuildPlan (set sa da ulozit), ale
          # PRAVIDLO nan zatial ziadne nie je — to prinesie KOV-E.
          'lift' => 'Výklop / sklop' }[generic_type.to_s] || generic_type.to_s
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
