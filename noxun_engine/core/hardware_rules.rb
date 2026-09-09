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
      # KOV-E1b: std 3 = pravidlo smie mat kind `lift_class` (vyklopy AVENTOS)
      # a `applies_to` smie niest filter `flap_dir`. Starsi plugin (std 2) kind
      # NEPOZNA — `evaluate` ho preskoci s info warningom, takze vyklop ostane
      # BEZ polozky (vedome riziko do D-48: kniznice su per PC, updater D-52).
      # Filter smeru starsi plugin IGNORUJE, takze by `zavesy-sklop` uplatnil
      # na KAZDE celo `flap` (aj na vyklop) — a prave preto sa dokument so
      # std 3 do starsieho pluginu uz NEZAPISUJE (dopredna brana nizsie).
      STD          = 3 # verzia formatu suboru pravidiel (doc: std/seed_version/rules)
      SEED_VERSION = 5 # v2 (D1): +zavesenie hornej skrinky, +podperky policove,
                       # seria vysuvov zladena s realnym radom Atira (GH #125 P2)
                       # v3 (D-90): +uchytkovy profil na dvierkach a zasuvkovych celach
                       # v4 (KOV-F1): NOXUN tabulka zavesov + door guardy
                       # v5 (KOV-E1b, delta audit Sol FIX 5): +vyklopy AVENTOS
                       # (`vyklopy-aventos`) a +zavesy sklopu (`zavesy-sklop`).
                       # BEZ tohto bumpu by `merge_seed` migraciu preskocil
                       # (`from_version >= SEED_VERSION`) a existujuca kniznica
                       # by nove seed pravidla nedala ani NOVYM projektom.
      # KOV-F1 (Codex #329 kolo 3 P1): verzia formatu, OD KTOREJ seed pravidlo
      # zavesov nesie door guardy (Noxun tabulka). Snapshot POD tymto cislom =
      # pravidla este spred tabulky, takze skrinka so zavesmi nesie stare pocty
      # aj PO prestavbe (snapshot sa nikdy nemerguje sam — naprava je vedoma
      # akcia „Doplniť nové predvoľby" alebo ulozenie Pravidiel). PEVNE CISLO,
      # nie `STD`: buduci bump formatu na tabulke zavesov nic nezmeni.
      HINGE_TABLE_STD = 2

      # KOV-E1b (Codex #333 kolo 1 P1): verzia SEEDU, OD KTOREJ pravidla vedia
      # vydat kovanie vyklopu a sklopu. Snapshot POD tymto cislom je „pred
      # E1b" — a kedze `ensure_project_rules!` existujuci snapshot ZAMERNE
      # ponechava (reprodukovatelnost stavby z .skp), prestavba pod nim vyda
      # celu `flap` NULA poloziek, hoci do configu zapise aktualnu schemu.
      # Preto stavba svoju seed verziu ULOZI (`config.rules_seed_version`)
      # a `Bom.flap_stale_issue` sa pyta OBOCH provenienci. PEVNE CISLO ako
      # `HINGE_TABLE_STD`: buduci bump seedu na tomto nic nemeni.
      LIFT_SEED_VERSION = 5

      FILE         = 'hardware_rules.json'
      MODEL_KEY    = 'hardware_rules' # kluc snapshotu v NOXUN dict na modeli

      KINDS = %w[fixed bands fit_series part_flag_length lift_class].freeze

      # === KOV-E1b: VYKLOPY (kind `lift_class`) ===============================
      #
      # `lift_class` je STVRTY vzor: z rozmerov KORPUSU a hmotnosti CELA urci
      # TRIEDU mechanizmu (a pri HL top aj triedu ramien a pocet stabilizacnych
      # tyci). Trieda ide do `params`, kod z nej robi az set (`code_by_param`,
      # E1a) — pravidlo ziadny kod nepozna.
      #
      # Prečo VLASTNY kind a nie `bands`: vystupom nie je POCET, ale KLASIFIKACIA
      # (dva parametre naraz) a vstupom su DVE veliciny (KH a hmotnost) plus
      # eligibility. Cena je znama a vedoma: starsi plugin kind preskoci
      # a vyklop ostane bez polozky (`std` 3 chrani zapis, nie citanie).
      LIFT_KIND    = 'lift_class'
      LIFT_OUTPUT  = 'lift'
      # SEED pravidla, ktore E1b prinasa. `LIFT_RULE_ID` je zaroven JEDINA
      # autorita otazky „ktore polozky su plny automat" (ochrana pred rucnym
      # zasahom — Astra FIX 11, zuzene Codex #331 kolo 2 P1 LEN na seed).
      LIFT_RULE_ID  = 'vyklopy-aventos'
      FALL_RULE_ID  = 'zavesy-sklop'
      # Rola CELA vyklopu aj sklopu (`Fronts.panels_for`) a hodnoty smeru
      # vyklapania (`Fronts` ich odvodzuje z typu riadku).
      FLAP_ROLE     = 'flap'
      FLAP_UP       = 'up'
      FLAP_DOWN     = 'down'
      LIFT_HK       = 'hk_top'
      LIFT_HL       = 'hl_top'
      # Klasifikacia polozky vyklopu — `use_type` je DRUHA polovica triedneho
      # kluca setu (`class:lift|<otvaranie>|<system>`), presne ako `door` pri
      # zavesoch. Slovnik hodnot drzi `HardwareSets::LIFT_SYSTEMS`.
      LIFT_USE_TYPE = 'lift'
      # Kody KONFLIKTOV vyklopu (ULOZENY nosic `hardware_conflicts`, register
      # `BuildPlan::HW_CONFLICT_CODES`). Retazce su autoritou tohto modulu.
      LIFT_CLASS_MISSING        = 'lift_class_missing'
      LIFT_DIMENSION_UNSUPPORTED = 'lift_dimension_unsupported'
      LIFT_MULTIROW_UNSUPPORTED  = 'lift_multirow_unsupported'
      LIFT_COMBO_UNSUPPORTED     = 'lift_combo_unsupported'

      # D-90: kluc dlzky rezu v params polozky. JEDINA autorita nazvu — cita ho
      # `flag_length_params` (zapis), `params_label` (text) aj brana dlzkoveho
      # kovania v HardwareSets (R-06). Ziadna vrstva si string nesmie opisat.
      LENGTH_PARAM = 'cut_length_mm'

      # Kontextove kluce povolene ako input/params_from_context (dokumentacia tvaru ctx).
      # KOV-E1b: `kh` (vyska korpusu BEZ sokla) a `kb` (sirka korpusu) su Blum
      # rozmery vyklopu; `front_rows` je pocet riadkov ciel skrinky (V1 pusta
      # vyklop len ako jediny riadok).
      CONTEXT_KEYS = %w[width height depth floor_height available_depth
                        available_height available_width kh kb front_rows].freeze

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
          'output' => 'handle', 'kind' => 'part_flag_length', 'quantity' => 1 },
        # === KOV-E1b: VYKLOPY AVENTOS (HK top / HL top) ======================
        #
        # Data: SYSTEM/zdroje/demos/SEED_AVENTOS_v2_2026-09-09.md (Demos + Blum
        # katalog 2024/25 str. 40). Hodnoty su Float a INKLUZIVNE, ak nie je
        # povedane inak; `max_exclusive` znaci HORNU hranicu, ktora do pasma
        # UZ NEPATRI (Blum pasma ramien 300–339 / 340–389 su spojite, medzi
        # nimi nesmie vzniknut diera pre KH 339,5).
        #
        # `handle_allowance_kg` sa pripocita k hmotnosti cela pri OBOCH
        # systemoch (Astra BLOCKER 3): LF aj HL tabulka rataju s uchytkou.
        { 'rule_id' => LIFT_RULE_ID, 'enabled' => true,
          'applies_to' => { 'role' => FLAP_ROLE, 'flap_dir' => FLAP_UP },
          'output' => LIFT_OUTPUT, 'kind' => LIFT_KIND,
          'handle_allowance_kg' => 0.5,
          # HK top: LF = KH x hmotnost; v prekryve tried vyhrava NAJSLABSIA,
          # ktora LF pokryva (poradie v poli = poradie sily).
          'classes' => [
            { 'code' => '22K2300', 'min' => 420.0,  'max' => 1610.0 },
            { 'code' => '22K2500', 'min' => 930.0,  'max' => 2800.0 },
            { 'code' => '22K2700', 'min' => 1730.0, 'max' => 5200.0 },
            { 'code' => '22K2900', 'min' => 3200.0, 'max' => 9000.0 }
          ],
          # HL top: mechanizmus podla KH (spojite max-pasma).
          'mechanisms' => [
            { 'code' => '22L2200', 'max' => 390.0, 'max_exclusive' => true },
            { 'code' => '22L2500', 'max' => 580.0 }
          ],
          # HL top: ramena podla KH A hmotnosti; v prekryve KH (480–540)
          # vyhrava NAJSLABSI par, ktory hmotnost pokryva.
          'arms' => [
            { 'code' => '22L3200', 'kh_min' => 300.0, 'kh_max' => 340.0, 'max_exclusive' => true,
              'kg_min' => 1.5,  'kg_max' => 9.0 },
            { 'code' => '22L3500', 'kh_min' => 340.0, 'kh_max' => 390.0, 'max_exclusive' => true,
              'kg_min' => 1.75, 'kg_max' => 10.0 },
            { 'code' => '22L3800', 'kh_min' => 390.0, 'kh_max' => 540.0,
              'kg_min' => 2.0,  'kg_max' => 12.25 },
            { 'code' => '22L3900', 'kh_min' => 480.0, 'kh_max' => 580.0,
              'kg_min' => 2.5,  'kg_max' => 14.0 }
          ],
          # Sirka korpusu, od ktorej ide DRUHA stabilizacna tyc + predlzovaci
          # diel (Michalov prah, prisnejsi nez Blum LW 1190).
          'rod_double_from_kb_mm' => 1100.0,
          # Rozmerova sposobilost per system (Blum; Michal potvrdil 9.9.2026).
          # `depth_min` je VNUTORNA hlbka (`ctx['available_depth']`).
          'eligibility' => {
            LIFT_HK => { 'kh_min' => 205.0, 'kh_max' => 600.0, 'kb_max' => 1800.0 },
            LIFT_HL => { 'kh_min' => 300.0, 'kh_max' => 580.0, 'kb_max' => 1800.0,
                         'depth_min' => 264.0 }
          } },
        # KOV-E1b: SKLOP (`flap_dir down`) dostane ZAVESY ako dvierka — tabulka
        # aj door guardy su tie iste ako pri `zavesy-podla-vysky`, lisi sa LEN
        # rola a smer. Vzpery (`use_type: 'fall'`) su mimo V1, preto polozka
        # nesie `use_type: 'door'` a set si hlada triednym klucom `class:hinge|…`.
        { 'rule_id' => FALL_RULE_ID, 'enabled' => true,
          'applies_to' => { 'role' => FLAP_ROLE, 'flap_dir' => FLAP_DOWN },
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
          'weight_bands' => [
            { 'max' => 7.7,  'quantity' => 2 },
            { 'max' => 13.7, 'quantity' => 3 },
            { 'max' => 17.1, 'quantity' => 4 },
            { 'max' => 22.0, 'quantity' => 5 }
          ] }
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
      # MINUS tie, ktorych vystup uz na tej istej role A SMERE obsluhuje INE
      # ZAPNUTE pravidlo (`OVERLAP_OUTPUTS`): pouzivatel si zavesy premenoval
      # alebo nahradil vlastnym pravidlom a doplnenie seedu by mu vyrobilo
      # DVOJITY nakup. `evaluate` taky prekryv priznava ORANGE-om, doplnat ho
      # nebudeme.
      #
      # KOV-E1b (Codex #331 kolo 3 P1 + delta audit Sol BLOCKER 2): kluc je
      # TROJICA (vystup, rola, smer vyklapania) a POROVNAVA sa TU aj v `evaluate`
      # tou istou funkciou — vlastne pravidlo len pre `down` (vzpery) nesmie
      # potlacit seed vyklopov pre `up`.
      def seed_additions(existing, have)
        taken = Array(existing).filter_map do |r|
          next nil unless r.is_a?(Hash) && r['enabled'] != false
          next nil unless OVERLAP_OUTPUTS.include?(r['output'].to_s)

          overlap_key(r)
        end
        SEED_RULES.reject do |r|
          have[r['rule_id']] ||
            (OVERLAP_OUTPUTS.include?(r['output'].to_s) &&
             taken.any? { |k| overlap_conflict?(k, overlap_key(r)) })
        end
      end

      # KOV-E1b: IDENTITA prekryvu pravidla — [vystup, rola, smer vyklapania].
      # Prazdny smer = WILDCARD (pravidlo bez filtra plati na oba smery).
      def overlap_key(rule)
        at = rule.is_a?(Hash) && rule['applies_to'].is_a?(Hash) ? rule['applies_to'] : {}
        [rule.is_a?(Hash) ? rule['output'].to_s : '', at['role'].to_s, at['flap_dir'].to_s]
      end

      # Prekryvaju sa dva kluce? Rovnaky vystup a rola, a smery, ktore sa
      # PRETINAJU (wildcard sa pretina s oboma smermi).
      def overlap_conflict?(a, b)
        return false unless a[0] == b[0] && a[1] == b[1]

        a[2].empty? || b[2].empty? || a[2] == b[2]
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

      # === KOV-E1b (Codex #333 kolo 1 P1): SEED VERZIA UCINNYCH PRAVIDIEL ====
      #
      # „S akym seedom sa TERAZ stavia?" — jedina autorita otazky. Odpoved je
      # PROVENIENCIA, ktoru si stavba ULOZI do configu skrinky, takze brana
      # `flap_stale` uz nemusia zaujimat pravidla samotne (delta audit Sol
      # FIX 4: vedome vypnute vlastne pravidlo NIE JE zaostalost).
      #
      # Poradie je to iste ako pri `pre_hinge_table_rules?`: rozhoduje
      # PROJEKTOVY snapshot; ked ho projekt nema, dedi globalnu kniznicu —
      # a tu prave `ensure_project_rules!` o chvilu zmrazi. Chybajuci kluc
      # `seed_version` = najstarsi seed (0), teda urcite pred vyklopmi.
      def effective_seed_version(model)
        doc = project_doc(model)
        return doc['seed_version'].to_i if doc.is_a?(Hash) && doc['rules'].is_a?(Array)

        library_seed_version
      end

      # Seed verzia, s ktorou by sa stavalo z GLOBALNEJ kniznice. Citanie
      # kniznicu MIGRUJE (`merge_seed` doplni chybajuce seed pravidla a bumpne
      # verziu), takze ucinna hodnota je aspon nasa `SEED_VERSION` — jedina
      # vynimka je kniznica z NOVSIEHO pluginu, ktoru `read_rules` zamerne
      # NEMERGUJE (dopredna brana `std`), takze plati jej vlastna verzia.
      # Neprecitatelna kniznica = fallback `SEED_RULES`, teda nas seed.
      def library_seed_version
        doc = JsonFileStore.read(path, copy: false)
        return SEED_VERSION unless doc.is_a?(Hash) && doc['rules'].is_a?(Array)

        v = doc['seed_version'].to_i
        doc_std_unsupported?(doc) ? v : [v, SEED_VERSION].max
      rescue StandardError
        SEED_VERSION
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
      # v poradi a druhe sa PRIZNA (ORANGE). Uzko zamerne: dve uchytkove
      # pravidla (`handle`) na jednej role su legitimny stav.
      #
      # KOV-E1b (delta audit Sol BLOCKER 2): zoznam je od E1b DVOJPRVKOVY —
      # `lift` sa v runtime prekryve nekontroloval vobec, takze dve rozne
      # pomenovane vyklopove pravidla by na jedno celo poslali DVA mechanizmy.
      # A prekryv sa porovnava podla (vystup, rola, SMER) — kluc pocita
      # `overlap_key` a rozhoduje `overlap_conflict?`, tie iste, akymi sa riadi
      # `seed_additions`. Bez smeru by skorsie pravidlo `hinge/flap/up`
      # potlacilo `zavesy-sklop` aj na skrinke, kde je LEN sklop (nula zavesov).
      OVERLAP_OUTPUTS = %w[hinge lift].freeze

      def evaluate(cfg, parts, ctx, rules:, suppress_slide_owners: {}, manual_flap_owners: {})
        items = []
        warnings = []
        conflicts = [] # KOV-E1b: tvrde dovody vyklopu (ULOZENY nosic)
        seen_ids = {}
        seen_overlap = []
        suppress = suppress_slide_owners.is_a?(Hash) ? suppress_slide_owners : {}
        suppressed = [] # kluce ciel, na ktorych legacy pravidlo vysuvu nebezalo
        manual_flap = manual_flap_owners.is_a?(Hash) ? manual_flap_owners : {}
        manual_hits = [] # [owner, output, pd] — cela s RUCNYM kovanim toho druhu
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
          if OVERLAP_OUTPUTS.include?(rule['output'].to_s)
            key = overlap_key(rule)
            hit = seen_overlap.find { |(k, _rid)| overlap_conflict?(k, key) }
            if hit
              warnings << BuildPlan.warning(
                'hardware_rule_overlap',
                "Pravidlo kovania '#{rid}' je druhé pravidlo #{overlap_noun(rule['output'])} pre tú " \
                "istú rolu — použije sa prvé („#{hit[1]}“). Vypni jedno z nich v Pravidlách kovania.",
                data: { 'rule_id' => rid, 'used_rule_id' => hit[1], 'role' => key[1],
                        'flap_dir' => key[2] }
              )
              next
            end
            seen_overlap << [key, rid]
          end
          apply_rule(rule, cfg || {}, parts, ctx, items, warnings, suppress, suppressed, conflicts,
                     manual_flap, manual_hits)
        end
        warnings.concat(profile_rule_warnings(parts, rules))
        warnings.concat(manual_flap_warnings(manual_hits))
        unless suppressed.empty?
          warnings << BuildPlan.warning(
            'legacy_slide_suppressed',
            "Zásuvky s receptom (#{suppressed.length} ks) dostali výsuv z receptu — pôvodné pravidlo " \
            'výsuvov sa na ne nepoužilo (jeden výsuv na zásuvku).',
            severity: 'info', data: { 'owners' => suppressed }
          )
        end
        final = apply_overrides(items, cfg[:hardware_overrides], warnings)
        # KOV-F1: door guardy bezia AZ NAD VYSLEDNYMI polozkami — hmotnostna
        # kontrola sa pyta na pocet PO rucnom zamku (Sol audit kolo 2) a
        # konflikt „mimo tabulky" musi rucny zamok ZHASNUT. Zamok sa hlada
        # v RUCNYCH ZASAHOCH, nie na polozke (Codex #329 kolo 2 P2).
        guards = door_guards(final, parts, rules, cfg[:hardware_overrides])
        warnings.concat(guards[:warnings])
        { items: final, warnings: warnings,
          conflicts: guards[:conflicts] + live_lift_conflicts(conflicts, final) }
      end

      # KOV-E1b: dovod vyklopu prezije LEN dovtedy, kym existuje polozka, ku
      # ktorej patri. Polozky SEED pravidla sa vypnut nedaju (plny automat), ale
      # VLASTNE `lift_class` pravidlo pouzivatela sa `disabled` zasahom vyradit
      # da — a osirely RED by sa uz nedal zhasnut nicim.
      def live_lift_conflicts(conflicts, final)
        return [] if conflicts.empty?

        owners = {}
        Array(final).each do |it|
          next unless it.is_a?(Hash) && it['generic_type'].to_s == LIFT_OUTPUT

          owners[it['owner_part_key'].to_s] = true
        end
        conflicts.select { |c| owners[c['owner_part_key'].to_s] }
      end

      # Podstatne meno pre vetu o prekryve — „druhé pravidlo závesov" vs.
      # „druhé pravidlo výklopov". Vlastny slovnik (nie `label_for`): ten dava
      # NAZOV pravidla („Závesy"), tu treba druhy pad mnozneho cisla.
      def overlap_noun(output)
        output.to_s == LIFT_OUTPUT ? 'výklopov' : 'závesov'
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
        # KOV-E1b: „nemá to byť výklop?" sa na SKLOP (rola `flap`) NEUPLATNI —
        # sirsie nez vyssie je pri sklope NORMA, nie podozrenie.
        if w && h && w > h && pd[:role].to_s != FLAP_ROLE
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
        # Codex #329 kolo 3 P2: KONECNA tabulka BEZ ciselneho pasma (pouzivatel
        # ich v editore zmazal — catch-all sa zmazat neda). `top` je vtedy nil
        # a povodna vetva konflikt POTLACILA, takze kazde celo ticho dostalo
        # catch-all pocet (spravidla 1 zaves) a nikde ziadny RED. Fail-closed:
        # mimo tabulky je vtedy KAZDE celo.
        return no_table_conflict(it, pd) if top.nil?

        h = part_dim(pd, :length)
        return nil if h.nil? || h <= top

        { 'owner_part_key' => it['owner_part_key'].to_s, 'code' => DOOR_OUT_OF_TABLE,
          'message' => "#{door_label(pd)}: výška #{fmt_mm(h)} mm je nad tabuľkou závesov " \
                       "(posledné pásmo #{fmt_mm(top)} mm) — počet #{it['quantity'].to_i} je len " \
                       'posledné pásmo. Zamkni počet ručne v Kovaní alebo rozdeľ čelo.' }
      end

      # Konecna tabulka, v ktorej ostalo LEN pasmo „vsetko nad". Ziadna vyska
      # sa neda porovnat, takze sa neuvadza — hovori sa, co s tym.
      def no_table_conflict(it, pd)
        { 'owner_part_key' => it['owner_part_key'].to_s, 'code' => DOOR_OUT_OF_TABLE,
          'message' => "#{door_label(pd)}: tabuľka závesov nemá ani jedno číselné pásmo — " \
                       "počet #{it['quantity'].to_i} je len pásmo „všetko nad“. Doplň pásma " \
                       'v Pravidlách kovania alebo zamkni počet ručne v Kovaní.' }
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

      # KOV-E1b: SKLOP dostava zavesy tym istym vzorom `bands`, takze tou istou
      # cestou chodia aj jeho varovania — ale volat ho „Dvierka" by pri hladani
      # v modeli poslalo cloveka na iny dielec.
      def door_label(pd)
        name = pd.is_a?(Hash) ? pd[:name].to_s.strip : ''
        base = pd.is_a?(Hash) && pd[:role].to_s == FLAP_ROLE ? 'Sklop' : 'Dvierka'
        name.empty? ? base : "#{base} „#{name}“"
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
      def apply_rule(rule, cfg, parts, ctx, items, warnings, suppress = {}, suppressed = [],
                     conflicts = [], manual_flap = {}, manual_hits = [])
        role = (rule['applies_to'] || {})['role'].to_s
        if role == 'cabinet'
          supports = Array((rule['applies_to'] || {})['support']).map(&:to_s)
          return if supports.any? && !supports.include?(ctx['support'].to_s)
          # D1 (GH #125 P2): predikat typu korpusu — support 'none' nerozlisuje
          # hornu skrinku od spodnej bez noh (Bystrica ide LEN na horne).
          kinds = Array((rule['applies_to'] || {})['cabinet_type']).map(&:to_s)
          return if kinds.any? && !kinds.include?(ctx['cabinet_type'].to_s)
          emit(rule, nil, ctx, nil, items, warnings, cfg, conflicts)
        else
          slide = rule['output'].to_s == SLIDE_OUTPUT
          # KOV-E1b: filter SMERU vyklapania. Pravidlo s `applies_to.flap_dir`
          # plati LEN na cela s tym smerom (vyklop `up` vs. sklop `down`);
          # pravidlo BEZ filtra plati na vsetky cela svojej roly — presne ako
          # doteraz. Deskriptor bez smeru (legacy plan, cudzi volajuci) filtru
          # NEVYHOVIE: hadat smer by znamenalo poslat vyklopovy mechanizmus
          # na sklop.
          want_dir = (rule['applies_to'] || {})['flap_dir'].to_s
          parts.each do |pd|
            next unless pd[:role].to_s == role
            next if !want_dir.empty? && pd[:flap_dir].to_s != want_dir

            owner = PartKeys.for_descriptor(pd)
            # KOV-C2b R2: celo s receptovym vysuvom legacy `slide` pravidlo
            # NEDOSTANE (ani ked recept skoncil konfliktom — fail-closed).
            if slide && suppress[owner]
              suppressed << owner unless suppressed.include?(owner)
              next
            end
            # KOV-E1b (Codex #333 kolo 1 P1): celo `flap` s RUCNE pridanym
            # kovanim TOHO ISTEHO druhu automat NEDOSTANE — inak by ho nakup
            # zratal DVAKRAT (`HardwareSets.add_adhoc_row` scitava rovnake
            # kody). Nikdy ticho: dovod ide do ORANGE.
            if manual_flap_hit?(rule, pd, owner, manual_flap)
              manual_hits << [owner, rule['output'].to_s, pd]
              next
            end
            emit(rule, owner, ctx, pd, items, warnings, cfg, conflicts)
          end
        end
      end

      # === KOV-E1b (Codex #333 kolo 1 P1): RUCNE KOVANIE NA VYKLOPE/SKLOPE ===
      #
      # `manual_flap` = { owner_part_key => { 'lift' => true, 'hinge' => true } },
      # pripravene v `CabinetBuilder` (klasifikacia potrebuje KATALOG, evaluacia
      # ostava CISTA). Znamena: na tom cele UZ VISI rucna (ad-hoc) polozka toho
      # druhu kovania.
      #
      # PRECO SA AUTOMAT VYNECHA A NESCITA: ad-hoc katalogova polozka sa
      # v nakupe ZLIEVA so setovou podla kodu (`add_adhoc_row`), takze skrinka
      # so schemou 10, ktora mala vyklop pridany rucne, by po vynutenej
      # prestavbe objednala mechanizmus DVAKRAT. Fail-closed smerom k cloveku:
      # plati RUCNY zaznam (ten je vedomy) a automat sa PRIZNA ORANGE-om.
      #
      # UZKO ZAMERNE: len rola `flap`. Rucny zaves na DVIERKACH sa spravanim
      # F1 nedotkne (tam sa automat vydava dalej ako doteraz).
      def manual_flap_hit?(rule, pd, owner, manual_flap)
        return false unless manual_flap.is_a?(Hash) && !manual_flap.empty?
        return false unless pd.is_a?(Hash) && pd[:role].to_s == FLAP_ROLE

        by_owner = manual_flap[owner.to_s]
        return false unless by_owner.is_a?(Hash)

        by_owner[rule['output'].to_s] == true
      end

      # JEDEN ORANGE na CELO (nie na pravidlo): pri dvoch pravidlach rovnakeho
      # vystupu by sa veta inak zopakovala. Nesie `part_key`, takze Kontroly
      # ukazu, o ktore celo ide.
      def manual_flap_warnings(hits)
        seen = {}
        Array(hits).filter_map do |(owner, output, pd)|
          key = "#{owner}|#{output}"
          next nil if seen[key]

          seen[key] = true
          what = output.to_s == LIFT_OUTPUT ? 'mechanizmus výklopu' : 'závesy sklopu'
          BuildPlan.warning(
            'flap_manual_hardware',
            "#{flap_label(pd)}: kovanie je pridané RUČNE — automatický #{what} sa nevydal " \
            '(inak by bol v nákupe dvakrát). Odstráň ručnú položku, ak chceš automat.',
            part_key: owner.to_s,
            data: { 'owner_part_key' => owner.to_s, 'generic_type' => output.to_s }
          )
        end
      end

      # Vyklop hovori „Výklop", sklop „Sklop" — dve rozne veci s jednou rolou.
      def flap_label(pd)
        dir = pd.is_a?(Hash) ? pd[:flap_dir].to_s : ''
        dir == FLAP_DOWN ? door_label(pd) : lift_label(pd)
      end

      # Vypocita pocet + params a prida polozku (string kluce — JSON round-trip
      # cez config korpusu bez konverzii, ako warnings).
      def emit(rule, owner, ctx, pd, items, warnings, cfg = {}, conflicts = [])
        qty, params = compute(rule, ctx, pd, owner, warnings, cfg, conflicts)
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
      def compute(rule, ctx, pd, owner, warnings, cfg = {}, conflicts = [])
        case rule['kind'].to_s
        when LIFT_KIND
          lift_compute(rule, ctx, pd, owner, warnings, conflicts)
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

      # === KOV-E1b: VYPOCET VYKLOPU (kind `lift_class`) =======================
      #
      # JEDNA polozka na celo, VZDY (aj ked je nieco zle): riadok v Kovani musi
      # existovat, inak sa uzivatel o probleme dozvie len z Kontroly a nema kde
      # vidiet, co sa objednava. Dovody idu do `conflicts` (ULOZENY nosic
      # `hardware_conflicts` -> RED Kontroly + zastavene 3 exporty), varovania
      # do `warnings` (ORANGE).
      #
      # Vstupy su VYHRADNE deskriptor (`weight_kg`, `flap_dir`, `lift_system`,
      # `opening_mode`) a kontext korpusu (`kh`, `kb`, `available_depth`,
      # `front_rows`) — resolved cela pravidlo necita.
      def lift_compute(rule, ctx, pd, owner, warnings, conflicts)
        # Korpusova uroven (pd nil) vyklop nema — nie je celo, ktore by sa
        # vyklapalo, ani hmotnost, z ktorej by sa dala urcit trieda.
        return [nil, {}] unless pd.is_a?(Hash)

        system = lift_system_of(pd)
        mode   = opening_mode_of(pd)
        kh = ctx_num(ctx, 'kh')
        kb = ctx_num(ctx, 'kb')
        rods = lift_rod_count(rule, kb)
        who = lift_label(pd)
        params = { 'use_type' => LIFT_USE_TYPE, 'lift_system' => system,
                   'opening_mode' => mode,
                   'rod_count' => rods, 'rod_extension' => (rods > 1 ? 1 : 0) }
        lift_multirow_conflict(ctx, owner, who, conflicts)
        lift_combo_conflict(system, mode, owner, who, conflicts)
        lift_dimension_conflict(rule, ctx, system, kh, kb, owner, who, conflicts)
        [1, params.merge(lift_class_params(rule, system, kh, pd, owner, who, warnings, conflicts))]
      end

      # Pocet stabilizacnych tyci z KB. Chybajuci/neplatny prah = pravidlo
      # zdvojenie NEPOZNA (jedna tyc) — nikdy sa nehada.
      def lift_rod_count(rule, kb)
        from = rule['rod_double_from_kb_mm']
        return 1 unless from.is_a?(Numeric) && from.to_f.finite? && from.to_f.positive?
        return 1 if kb.nil?

        kb >= from.to_f ? 2 : 1
      end

      # System vyklopu Z DESKRIPTORA (anotacia planu). Chybajuca hodnota =
      # legacy celo -> HK top, rovnaky vyklad ako `Fronts.lift_system_of`.
      def lift_system_of(pd)
        v = pd[:lift_system].to_s.strip
        v == LIFT_HL ? LIFT_HL : LIFT_HK
      end

      # Sposob otvarania Z DESKRIPTORA (vzor `hinge_params`).
      def opening_mode_of(pd)
        om = pd[:opening_mode].to_s.strip
        om.empty? ? DEFAULT_OPENING_MODE : om
      end

      def lift_label(pd)
        name = pd.is_a?(Hash) ? pd[:name].to_s.strip : ''
        name.empty? ? 'Výklop' : "Výklop „#{name}“"
      end

      def ctx_num(ctx, key)
        v = ctx.is_a?(Hash) ? ctx[key] : nil
        v.is_a?(Numeric) && v.to_f.finite? ? v.to_f : nil
      end

      def lift_conflict(conflicts, owner, code, message)
        conflicts << { 'owner_part_key' => owner.to_s, 'code' => code, 'message' => message }
      end

      # V1: vyklop smie byt LEN jediny riadok ciel skrinky (Michal 9.9.2026) —
      # dva riadky nad sebou by si mechanizmom prekazali a Blum na to ma iny
      # program. Pocet riadkov je v kontexte (`front_rows`).
      def lift_multirow_conflict(ctx, owner, who, conflicts)
        rows = ctx_num(ctx, 'front_rows')
        return if rows.nil? || rows <= 1

        lift_conflict(conflicts, owner, LIFT_MULTIROW_UNSUPPORTED,
                      "#{who}: skrinka má #{rows.to_i} riadky čiel — výklop vie systém spočítať len " \
                      'ako JEDINÝ riadok skrinky. Rozdeľ ho na samostatnú skrinku.')
      end

      # HL top v Tip-On prevedeni NEEXISTUJE (Michal 9.9.2026, Demos ho nema).
      def lift_combo_conflict(system, mode, owner, who, conflicts)
        return unless system == LIFT_HL && mode == 'tipon'

        lift_conflict(conflicts, owner, LIFT_COMBO_UNSUPPORTED,
                      "#{who}: HL top sa v prevedení Tip-On nevyrába — vyber HK top alebo " \
                      'prepni čelo na klasické otváranie.')
      end

      # Rozmerova sposobilost systemu (Blum): KH, sirka korpusu a pri HL aj
      # VNUTORNA hlbka (`available_depth` — uz zohladnuje chrbat aj drazku;
      # delta audit Sol BLOCKER 1: `depth - chrbat` by drazku prehliadol).
      def lift_dimension_conflict(rule, ctx, system, kh, kb, owner, who, conflicts)
        el = rule['eligibility']
        el = el.is_a?(Hash) ? el[system] : nil
        return unless el.is_a?(Hash)

        depth = ctx_num(ctx, 'available_depth')
        bad = []
        bad << "výška korpusu bez sokla #{fmt_mm(kh)} mm je pod #{fmt_mm(el['kh_min'])} mm" if
          kh && el['kh_min'].is_a?(Numeric) && kh < el['kh_min'].to_f
        bad << "výška korpusu bez sokla #{fmt_mm(kh)} mm je nad #{fmt_mm(el['kh_max'])} mm" if
          kh && el['kh_max'].is_a?(Numeric) && kh > el['kh_max'].to_f
        bad << "šírka korpusu #{fmt_mm(kb)} mm je nad #{fmt_mm(el['kb_max'])} mm" if
          kb && el['kb_max'].is_a?(Numeric) && kb > el['kb_max'].to_f
        bad << "vnútorná hĺbka #{fmt_mm(depth)} mm je pod #{fmt_mm(el['depth_min'])} mm" if
          depth && el['depth_min'].is_a?(Numeric) && depth < el['depth_min'].to_f
        return if bad.empty?

        lift_conflict(conflicts, owner, LIFT_DIMENSION_UNSUPPORTED,
                      "#{who}: #{lift_system_label(system)} sa do tejto skrinky nedá použiť — " \
                      "#{bad.join(', ')}. Zmeň rozmer skrinky alebo systém výklopu.")
      end

      def lift_system_label(system)
        system == LIFT_HL ? 'HL top' : 'HK top'
      end

      # TRIEDA mechanizmu (a pri HL aj ramien). Vracia params — prazdny hash
      # znamena „trieda sa nedala urcit" a JE k nemu RED `lift_class_missing`.
      def lift_class_params(rule, system, kh, pd, owner, who, warnings, conflicts)
        kg = pd[:weight_kg]
        unless kg.is_a?(Numeric) && kg.to_f.finite? && kg.to_f.positive?
          lift_conflict(conflicts, owner, LIFT_CLASS_MISSING,
                        "#{who}: hmotnosť čela nie je známa, takže sa nedá určiť trieda výklopu — " \
                        'doplň materiálom hustotu (Materiály) a prestav skrinku.')
          return {}
        end

        w = kg.to_f + lift_allowance(rule)
        system == LIFT_HL ? hl_class_params(rule, kh, w, owner, who, warnings, conflicts)
                          : hk_class_params(rule, kh, w, owner, who, warnings, conflicts)
      end

      # Rezerva na uchytku (kg) — pripocitava sa pri OBOCH systemoch (Blum LF
      # aj HL tabulka rataju s uchytkou; Astra BLOCKER 3).
      def lift_allowance(rule)
        v = rule['handle_allowance_kg']
        v.is_a?(Numeric) && v.to_f.finite? && !v.to_f.negative? ? v.to_f : 0.0
      end

      # HK top: LF = KH x hmotnost; v prekryve vyhrava NAJSLABSIA trieda,
      # ktora LF pokryva (poradie v poli).
      def hk_class_params(rule, kh, w, owner, who, warnings, conflicts)
        classes = Array(rule['classes']).select { |c| c.is_a?(Hash) && !c['code'].to_s.empty? }
        if kh.nil? || classes.empty?
          lift_conflict(conflicts, owner, LIFT_CLASS_MISSING,
                        "#{who}: tabuľka tried výklopu HK top chýba alebo je neúplná — " \
                        'doplň ju v Pravidlách kovania.')
          return {}
        end

        lf = kh * w
        hit = classes.find { |c| lf >= c['min'].to_f && lf <= c['max'].to_f }
        return { 'lift_class' => hit['code'].to_s } if hit

        floor = classes.map { |c| c['min'].to_f }.min
        if lf < floor
          warnings << lift_light_warning(who, owner, "LF #{fmt_mm(lf)}", "#{fmt_mm(floor)}",
                                         classes.first['code'].to_s)
          return { 'lift_class' => classes.first['code'].to_s }
        end

        top = classes.map { |c| c['max'].to_f }.max
        lift_conflict(conflicts, owner, LIFT_CLASS_MISSING,
                      "#{who}: LF #{fmt_mm(lf)} (výška korpusu #{fmt_mm(kh)} mm × #{fmt_mm(w)} kg " \
                      "aj s úchytkou) je nad tabuľkou HK top (maximum #{fmt_mm(top)}) — " \
                      'rozdeľ čelo, odľahči ho alebo vyber iný systém.')
        {}
      end

      # HL top: mechanizmus podla KH, ramena podla KH A hmotnosti. Ked sa
      # nedaju urcit ramena, polozka NEDOSTANE ani triedu mechanizmu — set by
      # inak objednal mechanizmus bez ramien.
      def hl_class_params(rule, kh, w, owner, who, warnings, conflicts)
        arms = Array(rule['arms']).select { |a| a.is_a?(Hash) && !a['code'].to_s.empty? }
        mech = kh.nil? ? nil : Array(rule['mechanisms']).find { |m| max_band_covers?(m, kh) }
        cands = kh.nil? ? [] : arms.select { |a| arm_kh_covers?(a, kh) }
        if mech.nil? || cands.empty?
          lift_conflict(conflicts, owner, LIFT_CLASS_MISSING,
                        "#{who}: výška korpusu bez sokla #{kh ? fmt_mm(kh) : '?'} mm nie je " \
                        'v tabuľke HL top — ' \
                        'zmeň výšku skrinky alebo vyber HK top.')
          return {}
        end

        hit = cands.find { |a| w >= a['kg_min'].to_f && w <= a['kg_max'].to_f }
        if hit
          return { 'lift_class' => mech['code'].to_s, 'arm_class' => hit['code'].to_s }
        end

        floor = cands.map { |a| a['kg_min'].to_f }.min
        if w < floor
          warnings << lift_light_warning(who, owner, "hmotnosť #{fmt_mm(w)} kg",
                                         "#{fmt_mm(floor)} kg", cands.first['code'].to_s)
          return { 'lift_class' => mech['code'].to_s, 'arm_class' => cands.first['code'].to_s }
        end

        top = cands.map { |a| a['kg_max'].to_f }.max
        lift_conflict(conflicts, owner, LIFT_CLASS_MISSING,
                      "#{who}: hmotnosť #{fmt_mm(w)} kg (aj s úchytkou) je nad maximom " \
                      "#{fmt_mm(top)} kg pre ramená HL top pri výške #{fmt_mm(kh)} mm — " \
                      'odľahči čelo alebo zmeň výšku skrinky.')
        {}
      end

      # ORANGE „prilis lahke celo": mechanizmus sa da doladit pruzinou, preto
      # to NIE JE stopka (Michal 9.9.2026) — polozka dostane NAJSLABSIU triedu.
      def lift_light_warning(who, owner, what, floor, code)
        BuildPlan.warning(
          'lift_light_front',
          "#{who}: #{what} je pod spodnou hranicou tabuľky (#{floor}) — použije sa najslabšia " \
          "trieda #{code}, skontroluj dotiahnutie pružiny.",
          part_key: owner, data: { 'lift_class' => code }
        )
      end

      # Pasmo „do max" (mechanizmy HL). `max_exclusive` = horna hranica do
      # pasma UZ NEPATRI.
      def max_band_covers?(band, v)
        return false unless band.is_a?(Hash) && band['max'].is_a?(Numeric)

        band['max_exclusive'] == true ? v < band['max'].to_f : v <= band['max'].to_f
      end

      # Pasmo ramien podla KH: `kh_min` je VZDY inkluzivne, `kh_max` podla
      # `max_exclusive` (Blum 300–339 / 340–389 su spojite, 390–540 a 480–580
      # su inkluzivne).
      def arm_kh_covers?(arm, kh)
        return false unless arm['kh_min'].is_a?(Numeric) && arm['kh_max'].is_a?(Numeric)
        return false if kh < arm['kh_min'].to_f

        arm['max_exclusive'] == true ? kh < arm['kh_max'].to_f : kh <= arm['kh_max'].to_f
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
      def apply_overrides(items, overrides, warnings = nil)
        list = Array(overrides).select { |ov| ov.is_a?(Hash) }
        return items if list.empty?
        items.filter_map do |it|
          ov = list.select { |o| override_match?(o, it) }.last
          next it unless ov
          # KOV-E1b (Astra FIX 11, zuzene Codex #331 kolo 2 P1): polozky SEED
          # pravidla vyklopov su PLNY AUTOMAT — vypnutie ani rucny pocet na nich
          # neplati (vyklop je zostava, polovicna objednavka nie je volba).
          # Normalizacia configu taky zaznam uz cisti; toto je druha obrana pre
          # zakazky ulozene starsim pluginom. VLASTNE `lift` pravidla
          # pouzivatela a ich overridy ostavaju UCINNE.
          if protected_lift_item?(it)
            warnings << lift_override_ignored_warning(it) if warnings.is_a?(Array)
            next it
          end
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

      # KOV-E1b: je polozka z chraneneho SEED pravidla vyklopov? JEDINA autorita
      # otazky — pyta sa jej evaluacia aj normalizacia configu (cez
      # `LIFT_RULE_ID`).
      def protected_lift_item?(item)
        (item['rule_id'] || item[:rule_id]).to_s == LIFT_RULE_ID
      end

      def lift_override_ignored_warning(item)
        BuildPlan.warning(
          'lift_override_ignored',
          'Ručný zásah na výklope sa neuplatní — výklop je zostava a plugin ju počíta celú ' \
          '(zmeň systém výklopu na čele alebo vyber iný set).',
          part_key: (item['owner_part_key'] || item[:owner_part_key]),
          data: { 'rule_id' => LIFT_RULE_ID }
        )
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
          # Codex #330 kolo 1 (P2): normalizuje sa kazdy tvar, nie len pole.
          # Hash/retazec/cislo v tomto kluci (pokazeny alebo cudzi snapshot) sa
          # uz NEZACHOVAVA — `normalize_bands` z neho spravi PRAZDNE pole, takze
          # editor v paneli dostane vzdy tabulku a nie tvar, nad ktorym padne.
          # Data sa tym nestracaju: pouzitelne pasmo nezanikne (pasma su Hash
          # v poli) a prazdnu tabulku ULOZENIE dalej ODMIETA
          # (`weight_bands_problem`), takze ticho v modeli neostane.
          r['weight_bands'] = normalize_bands(r['weight_bands']) if r.key?('weight_bands')
          normalize_width_plus!(r)
          if r.key?('width_warn_over')
            v = r['width_warn_over'].to_f
            v.finite? && v.positive? ? r['width_warn_over'] = v : r.delete('width_warn_over')
          end
          if r['series'].is_a?(Array)
            r['series'] = r['series'].map(&:to_f).select(&:positive?).uniq.sort
          end
          r['clearance'] = r['clearance'].to_f if r.key?('clearance')
          normalize_lift_rule!(r)
          r
        end
      end

      # KOV-E1b: typova ocista tabuliek vyklopu. Riadok bez kodu alebo bez
      # pouzitelnych cisel sa ZAHODI (radsej ziadne pasmo nez hadanie) a pasma
      # sa ZORADIA — poradie je vyznamove (v prekryve vyhrava PRVE, teda
      # najslabsie), takze sa nesmie spoliehat na poradie v subore. Kluce sa
      # cistia PODLA PRITOMNOSTI, nie podla `kind`: pravidlo smie niest zvysky
      # po zmene typu a validovat/pouzit sa ma len to, co sa naozaj pocita.
      def normalize_lift_rule!(rule)
        LIFT_SCALARS.each_key { |key| normalize_lift_scalar!(rule, key) }
        rule['classes'] = normalize_lift_classes(rule['classes']) if rule.key?('classes')
        rule['mechanisms'] = normalize_lift_mechanisms(rule['mechanisms']) if rule.key?('mechanisms')
        rule['arms'] = normalize_lift_arms(rule['arms']) if rule.key?('arms')
        rule['eligibility'] = normalize_lift_eligibility(rule['eligibility']) if
          rule.key?('eligibility')
        rule
      end

      # Skalary vyklopoveho pravidla + ich LUDSKY nazov do hlasky.
      LIFT_SCALARS = { 'handle_allowance_kg' => 'rezerva na úchytku',
                       'rod_double_from_kb_mm' => 'šírka pre druhú stabilizačnú tyč' }.freeze

      # Codex #333 kolo 2 P2: `to_f` na Hash/Array/true VYHODI vynimku, takze
      # jediny pokazeny skalar zhodil normalizaciu CELEHO dokumentu —
      # `project_rules` ju odchytil, vratil nil a `ensure_project_rules!` potom
      # projektove pravidla TICHO nahradil globalnou kniznicou.
      #
      # Typova kontrola je rovnaka ako pri bunkach tabuliek (`lift_row?`):
      # neciselna hodnota sa NEHADA a NEZAHADZUJE sa cely kluc — ostava
      # PRITOMNY s hodnotou `nil`. To je vzor `weight_bands` (KOV-F2):
      # normalizacia necha tvar, ktory brana odmietne, takze `lift_problem`
      # o probleme POVIE a ulozenie takeho pravidla neprejde (vypnute pravidlo
      # sa nekontroluje — cesta von existuje). Citatelia (`lift_allowance`,
      # `lift_rod_count`) su uz typovo bezpecni: nil = ziadna rezerva / jedna
      # tyc, nikdy hadanie.
      def normalize_lift_scalar!(rule, key)
        return rule unless rule.key?(key)

        v = rule[key]
        rule[key] = v.is_a?(Numeric) && v.to_f.finite? ? v.to_f : nil
        rule
      end

      def normalize_lift_classes(raw)
        rows = Array(raw).filter_map do |c|
          next nil unless lift_row?(c, %w[min max])

          { 'code' => c['code'].to_s.strip, 'min' => c['min'].to_f, 'max' => c['max'].to_f }
        end
        rows.sort_by { |c| [c['min'], c['max']] }
      end

      def normalize_lift_mechanisms(raw)
        rows = Array(raw).filter_map do |m|
          next nil unless lift_row?(m, %w[max])

          out = { 'code' => m['code'].to_s.strip, 'max' => m['max'].to_f }
          out['max_exclusive'] = true if m['max_exclusive'] == true
          out
        end
        rows.sort_by { |m| m['max'] }
      end

      def normalize_lift_arms(raw)
        rows = Array(raw).filter_map do |a|
          next nil unless lift_row?(a, %w[kh_min kh_max kg_min kg_max])

          out = { 'code' => a['code'].to_s.strip, 'kh_min' => a['kh_min'].to_f,
                  'kh_max' => a['kh_max'].to_f, 'kg_min' => a['kg_min'].to_f,
                  'kg_max' => a['kg_max'].to_f }
          out['max_exclusive'] = true if a['max_exclusive'] == true
          out
        end
        rows.sort_by { |a| [a['kh_min'], a['kg_max']] }
      end

      # Riadok tabulky = neprazdny kod + vsetky menovane hodnoty ako KONECNE
      # cisla. Cokolvek ine je nepouzitelny riadok.
      def lift_row?(row, keys)
        return false unless row.is_a?(Hash) && !row['code'].to_s.strip.empty?

        keys.all? { |k| row[k].is_a?(Numeric) && row[k].to_f.finite? }
      end

      # Sposobilost per SYSTEM — cudzie kluce (a systemy, ktore nepozname)
      # vypadnu; prazdny vysledok = pravidlo eligibility nema.
      ELIGIBILITY_KEYS = %w[kh_min kh_max kb_max depth_min].freeze

      def normalize_lift_eligibility(raw)
        return {} unless raw.is_a?(Hash)

        out = {}
        [LIFT_HK, LIFT_HL].each do |sys|
          rec = raw[sys]
          next unless rec.is_a?(Hash)

          vals = {}
          ELIGIBILITY_KEYS.each do |k|
            v = rec[k]
            vals[k] = v.to_f if v.is_a?(Numeric) && v.to_f.finite? && v.to_f.positive?
          end
          out[sys] = vals unless vals.empty?
        end
        out
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
      #   * `kind == 'bands'` s `finite` a BEZ jedineho ciselneho pasma — catch-all
      #     by dal svoj pocet kazdemu celu a kazde celo by bolo „mimo tabulky"
      #     (RED). Odmietnut taky tvar RAZ pri ulozeni je lacnejsie nez RED na
      #     kazdych dvierkach zakazky (Codex #329 kolo 3 P2).
      #   * KOV-F2: `weight_bands`, ked su v pravidle — prazdna tabulka, pasmo
      #     bez kilogramov a dve pasma s rovnakou hmotnostou. Su to jedine tri
      #     tvary guardu, ktore `normalize_rules` NECHA TAK (zvysok typovo
      #     ocisti alebo zahodi), takze len ich vie brana este vidiet.
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
        when 'bands' then bands_problem(rule)
        when LIFT_KIND then lift_problem(rule)
        when 'fit_series'
          series = rule['series'].is_a?(Array) ? rule['series'] : []
          return nil unless series.empty?

          "#{rule_address(rule)} potrebuje aspoň jednu dĺžku v rade."
        end
      end

      # KOV-E1b: co sa na vyklopovom pravidle NESMIE ulozit. Kriteria su nad
      # tvarom PO `normalize_rules` (neplatne riadky uz vypadli), takze sa
      # kontroluje LEN to, co normalizacia necha tak: uplne prazdna tabulka,
      # obratene pasmo a DIERA medzi pasmami ramien (KH v diere by nedostalo
      # ziadne ramena a kazde take celo by bolo RED).
      def lift_problem(rule)
        addr = rule_address(rule)
        classes = rule['classes'].is_a?(Array) ? rule['classes'] : []
        arms    = rule['arms'].is_a?(Array) ? rule['arms'] : []
        mechs   = rule['mechanisms'].is_a?(Array) ? rule['mechanisms'] : []
        return "#{addr}: tabuľka tried HK top je prázdna — doplň aspoň jednu triedu." if classes.empty?
        return "#{addr}: tabuľka mechanizmov HL top je prázdna — doplň aspoň jeden." if mechs.empty?
        return "#{addr}: tabuľka ramien HL top je prázdna — doplň aspoň jedny." if arms.empty?

        bad = classes.find { |c| c['min'].to_f > c['max'].to_f }
        return "#{addr}: trieda #{bad['code']} má LF od väčšie než do." if bad

        bad = arms.find { |a| a['kh_min'].to_f > a['kh_max'].to_f || a['kg_min'].to_f > a['kg_max'].to_f }
        return "#{addr}: ramená #{bad['code']} majú od väčšie než do." if bad

        # Codex #333 kolo 2 P2: NECISELNY skalar (Hash/Array/true z pokazeneho
        # alebo cudzieho snapshotu). `normalize_lift_scalar!` ho zmenil na nil,
        # aby normalizacia dokumentu neskoncila vynimkou — a TU sa o nom povie.
        # Bez tejto vety by rezerva ticho spadla na 0 kg (slabsi mechanizmus)
        # a prah druhej tyce by zmizol (jedna tyc nad 1100 mm).
        bad_key = LIFT_SCALARS.keys.find { |k| rule.key?(k) && !rule[k].is_a?(Numeric) }
        return "#{addr}: #{LIFT_SCALARS[bad_key]} musí byť číslo." if bad_key

        # Codex #333 kolo 1 P2: ZAPORNA rezerva na uchytku by hmotnost cela
        # ZNIZILA, takze automat by vybral SLABSI mechanizmus — presne opak
        # toho, na co rezerva je. `normalize_lift_rule!` ju len pretypuje
        # (`to_f`), takze bez tejto vety by taka hodnota ticho presla.
        if rule.key?('handle_allowance_kg') && rule['handle_allowance_kg'].to_f.negative?
          return "#{addr}: rezerva na úchytku nesmie byť záporná."
        end

        # KOV-E2: ZAPORNY prah druhej tyce. `lift_rod_count` ho zahodi (ziada
        # kladne cislo), takze by pravidlo TICHO tvrdilo „druha tyc nikdy" —
        # a stabilizacna tyc je pri HL top nakupna polozka, nie kozmetika.
        if rule.key?('rod_double_from_kb_mm') && rule['rod_double_from_kb_mm'].to_f.negative?
          return "#{addr}: šírka pre druhú stabilizačnú tyč nesmie byť záporná."
        end

        # KOV-E2: ZAPORNA hodnota v tabulke. `lift_row?` prepusti kazde konecne
        # cislo, takze riadok „LF od −500" by pravidlo prijalo a trieda by
        # pokryvala aj nezmyselne LF. Rozmery, sily ani hmotnosti zaporne nie su.
        neg = lift_negative_row(classes, %w[min max]) ||
              lift_negative_row(mechs, %w[max]) ||
              lift_negative_row(arms, %w[kh_min kh_max kg_min kg_max])
        return "#{addr}: riadok #{neg} má zápornú hodnotu — rozmery aj hmotnosti sú kladné." if neg

        elig = lift_eligibility_problem(addr, rule['eligibility'])
        return elig if elig

        arms_gap_problem(addr, arms)
      end

      # Prvy riadok tabulky so ZAPORNOU hodnotou (kod riadku) alebo nil.
      def lift_negative_row(rows, keys)
        bad = Array(rows).find do |r|
          r.is_a?(Hash) && keys.any? { |k| r[k].is_a?(Numeric) && r[k].to_f.negative? }
        end
        bad && bad['code'].to_s
      end

      # KOV-E2: SPOSOBILOST s obratenym rozsahom. `normalize_lift_eligibility`
      # necha kazde KLADNE cislo, takze `kh_min 600` a `kh_max 205` prezije —
      # a taky system by nebol pouzitelny NIKDY (kazde celo RED
      # `lift_dimension_unsupported`), bez jedineho slova o tom, preco.
      def lift_eligibility_problem(addr, raw)
        return nil unless raw.is_a?(Hash)

        [LIFT_HK, LIFT_HL].each do |sys|
          rec = raw[sys]
          next unless rec.is_a?(Hash)
          next unless rec['kh_min'].is_a?(Numeric) && rec['kh_max'].is_a?(Numeric)
          next unless rec['kh_min'].to_f > rec['kh_max'].to_f

          return "#{addr}: spôsobilosť #{lift_system_label(sys)} má výšku od väčšiu než do."
        end
        nil
      end

      # DIERA medzi pasmami ramien: dalsie pasmo sa musi zacinat NAJNESKOR tam,
      # kde predosle konci (pri `max_exclusive` presne tam, inak hned zaň —
      # inkluzivne pasma sa smu prekryvat, medzera medzi nimi ale nie).
      def arms_gap_problem(addr, arms)
        sorted = arms.sort_by { |a| a['kh_min'].to_f }
        reach = nil
        sorted.each do |a|
          if reach && a['kh_min'].to_f > reach
            return "#{addr}: medzi pásmami ramien je medzera pri výške #{fmt_mm(reach)} mm — " \
                   'výklop tej výšky by nedostal žiadne ramená.'
          end

          top = a['kh_max'].to_f
          reach = top if reach.nil? || top > reach
        end
        nil
      end

      def bands_problem(rule)
        bands = rule['bands'].is_a?(Array) ? rule['bands'] : []
        if bands.empty? || bands.none? { |b| b.is_a?(Hash) && b['max'].nil? }
          return "#{rule_address(rule)} potrebuje aspoň pásmo „všetko nad“."
        end
        # Codex #329 kolo 3 P2: KONECNA tabulka bez jedineho CISELNEHO pasma
        # nie je tabulka — catch-all by dal svoj pocet kazdemu celu a kazde
        # by zaroven bolo „mimo tabulky". Take pravidlo sa NEULOZI.
        if rule['finite'] == true && bands.none? { |b| b.is_a?(Hash) && !b['max'].nil? }
          return "#{rule_address(rule)}: konečná tabuľka potrebuje aspoň jedno číselné pásmo."
        end

        weight_bands_problem(rule)
      end

      # KOV-F2: hmotnostne pasma su VOLITELNY guard — kluc, ktory CHYBA, sa
      # nevaliduje (pravidlo bez guardov ostava bez guardov). Ked ale kluc JE,
      # musi to byt POUZITELNA tabulka; inak by sa varovania zavesov ticho
      # posunuli (pasmo bez kilogramov chyti kazdu hmotnost, dve rovnake
      # hodnoty urobia z jedneho riadku mrtvy riadok).
      #
      # KRITERIA su definovane nad tvarom PO `normalize_rules` (brana bezi az
      # za nou) a su NEZAVISLE OD PORADIA — normalizacia pasma zoradi podla
      # `max`, takze „neusporiadane" nie je chyba pouzivatela, ale vec, ktoru
      # server opravi sam. Rozist sa teda moze len to, co normalizacia NECHA
      # TAK: prazdna tabulka, pasmo bez kilogramov a dve pasma s rovnakou
      # hmotnostou. Klientska `rdValidate` ma tie iste tri kriteria (parita
      # cez `tests/fixtures/rules_validation_parity.json`).
      #
      # POCET v pasme sa TU nevaliduje ZAMERNE: `normalize_bands` riadok
      # s neplatnym poctom ZAHODI, takze do brany sa taky riadok nikdy
      # nedostane — kontrolovat ho by znamenalo mrtvu vetvu na serveri a
      # rozchod s klientom (ten pocet clampuje na >= 1 ako pri vyskovych
      # pasmach). Ked vypadnu VSETKY riadky, chyti to vetva „prazdne".
      def weight_bands_problem(rule)
        return nil unless rule.key?('weight_bands')

        bands = rule['weight_bands']
        unless bands.is_a?(Array) && !bands.empty?
          return "#{rule_address(rule)}: hmotnostné pásma sú prázdne — vyplň kg aj počet, alebo tabuľku zmaž."
        end

        maxes = []
        bands.each do |b|
          max = b.is_a?(Hash) ? b['max'] : nil
          unless max.is_a?(Numeric) && max.to_f.finite? && max.to_f.positive?
            return "#{rule_address(rule)}: pásmo hmotnosti potrebuje kilogramy — číslo väčšie ako 0."
          end

          maxes << max.to_f
        end
        return nil if maxes.uniq.length == maxes.length

        "#{rule_address(rule)}: dve hmotnostné pásma majú rovnakú hmotnosť — každé musí mať inú."
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
