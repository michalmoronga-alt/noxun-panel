# frozen_string_literal: true
# Noxun Engine — V0.6 E-a: NASTAVENIA DODAVATELA pre rozpocet (sadzby sluzieb,
# cenove rezimy, standardne koncove riadky). Globalny store
# %APPDATA%\NOXUN\Engine\supplier_settings.json (+ .bak cez JsonFileStore).
# CISTY Ruby modul — ziadne SketchUp API, headless testovatelny.
#
# ====================== PRECO GLOBAL A NIE MODEL =======================
# Sadzby sa do zakazky NEMRAZIA (rozhodnutie Michal 31.7.): rozpocet je
# POHYBLIVY obraz cien, nie vyrobny snapshot. V modeli ziju LEN veci per
# zakazka (rezim, overridy, nasobky, vlastne polozky) — tie drzi BudgetStore.
#
# ============================== STRUKTURA ==============================
# { "std": 2, "seed_version": 1, "active": "default",
#   "suppliers": [ { "id": "default", "name": "Noxun",
#                    "rates": { olep|porez|duplaky|pd_opracovanie|montaz },
#                    "stale_days": 30, "rounding_step": 1.0,
#                    "abs_reserve_pct": 10.0, "montaz_m2_per_plate": 5.8,
#                    "cp_highlight_threshold": 150.0,
#                    "kerf_mm": 5.0, "trim_mm": 10.0, "dup_allowance_mm": 10.0,
#                    "standard_rows": [ {key,name,kind,rate,default_multiplier} ],
#                    "mode_values": { row_key => {nizky,standard,vysoky} } } ] }
# Architektura je na VIAC dodavatelov, V1 pouziva jedneho (active).
#
# ============================== SEED+MERGE =============================
# Prvy beh vytvori seed. Kazdy dalsi beh LEN DOPLNI chybajuce kluce, riadky
# a rezimove hodnoty (vzor HardwareRules.merge_seed) — Michalom upravena
# hodnota sa NIKDY neprepise. `std` je verzia formatu pre buduce migracie.
#
# =================== NP-2: VERZIA 2 A DOPREDNA BRANA ===================
# STD 2 prinieslo tri skalare narezoveho planu (kerf_mm, trim_mm,
# dup_allowance_mm). Normalizacia je WHITELIST — plugin, ktory pole nepozna,
# ho pri prvom zapise ZAHODI. Preto (vzor HardwareRules KOV-F1):
#   * KAZDY zapis peciatkuje `std = STD` (inak by subor ostal navzdy 1 a
#     buduca brana by nemala co porovnat),
#   * subor z NOVSIEHO pluginu (`std > STD`) sa CITA (zakazka sa musi dat
#     dokoncit), ale NIKDY sa don nezapisuje — ani seed-merge; brana
#     `newer_write_blocked?` stoji v `write` pod zamkom hned za degradovanym
#     suborom (R-11) a verziu cita CERSTVO z disku (audit NP-2 F4).
# PRIZNANY LIMIT: verzie pred NP-2 (v0.15.1 a starsie) branu nemaju — ked na
# tom istom %APPDATA% ulozia nastavenia, nove kluce zahodia a `std` 2 nechaju;
# novsi plugin potom doplni predvolene 5/10/10 bez varovania.
#
# ======================= SADZBY vs STANDARDNE RIADKY ===================
# SLUZBY (rates) su AUTOMATICKE — mnozstvo pocita engine z BOM/odhadu platni:
#   olep (EUR/bm) · porez (EUR/platna) · duplaky (EUR/ks zlepeny kus) ·
#   pd_opracovanie (EUR fix) · montaz (EUR/m2; m2 = platne x montaz_m2_per_plate).
# MONTAZ JE SLUZBA, NIE standardny riadok — v realnych rozpoctoch je to jediny
# riadok pocitany zo vzorca (audit BLOCKER 1: dva zdroje montaze = dvojite
# uctovanie). Standardne riadky su FIXNE koncove polozky s NASOBKOM (skala
# zakazky 0/0,2/0,5/1/2/4 — v realnych rozpoctoch stlpec "POCET KS").
require 'json'
require 'fileutils'
require 'tmpdir'
require 'digest'

module Noxun
  module Engine
    module SupplierSettings
      STD          = 2 # verzia formatu suboru (NP-2: skalare narezoveho planu + dopredna brana)
      SEED_VERSION = 1 # verzia seedu (merge doplna nove kluce/riadky/rezimy)
      FILE         = 'supplier_settings.json'

      DEFAULT_ID   = 'default'
      DEFAULT_NAME = 'Noxun'

      # Cenove rezimy zakazky — pomenovana sada hodnot, NIE zamok (rucny
      # override riadku vzdy vitazi, vid Budget).
      MODES        = %w[nizky standard vysoky].freeze
      DEFAULT_MODE = 'standard'
      MODE_LABELS  = { 'nizky' => 'Nízky', 'standard' => 'Štandard', 'vysoky' => 'Vysoký' }.freeze

      # Sadzby automatickych sluzieb (seed = 10 realnych rozpoctov 2025-2026).
      RATE_KEYS = %w[olep porez duplaky pd_opracovanie montaz].freeze
      SEED_RATES = {
        'olep'           => 0.90,  # EUR/bm olepovania ABS
        'porez'          => 17.0,  # EUR/platna
        'duplaky'        => 50.0,  # EUR/ks zlepeneho duplaku
        'pd_opracovanie' => 100.0, # EUR fix (Michal 4.8.: 100, prepisatelne)
        'montaz'         => 15.0   # EUR/m2 (nemenne 20 mesiacov)
      }.freeze

      # Skalarne nastavenia dodavatela.
      #   stale_days          — prah veku ceny (dni) pre pas cenovej cerstvosti
      #   rounding_step       — krok zaokruhlenia KONECNEJ sumy (Michal: na cele EUR)
      #   abs_reserve_pct     — rezerva na olep/ABS v % (Michal: 10 %)
      #   montaz_m2_per_plate — m2 na 1 platnu vo vzorci montaze (10/10 rozpoctov 5,8)
      #   cp_highlight_threshold — E-b2: od akej sumy NAVRHNE cenova ponuka
      #     samostatny riadok (prieskum 22 CP: najlacnejsia samostatne uvedena
      #     polozka 27 €, najdrahsia zlucena ~700 € -> navrh 150 €). Je to LEN
      #     navrh — rozhodnutie per polozka zije v zakazke (cp_overrides).
      #   kerf_mm / trim_mm / dup_allowance_mm — NP-2 (N3, O7, O12): prerez
      #     pily, orez okraja platne a pridavok vrstvy duplaku na stranu (mm,
      #     desatinne povolene). Citaju ich narezovy plan (SheetLayout) a
      #     Kontrola „nezmesti sa" cez `layout_params` — JEDINY vstup.
      SCALAR_DEFAULTS = {
        'stale_days'          => 30,
        'rounding_step'       => 1.0,
        'abs_reserve_pct'     => 10.0,
        'montaz_m2_per_plate' => 5.8,
        'cp_highlight_threshold' => 150.0,
        'kerf_mm'             => 5.0,
        'trim_mm'             => 10.0,
        'dup_allowance_mm'    => 10.0
      }.freeze

      ROW_KINDS = %w[fixed per_m2].freeze

      # 8 FIXNYCH standardnych riadkov v poradi z realnych rozpoctov (10/10).
      # Montaz tu VEDOME NIE JE (je to automaticka sluzba — audit BLOCKER 1).
      SEED_STANDARD_ROWS = [
        { 'key' => 'doprava_zakaznik',  'name' => 'Doprava k zákazníkovi', 'kind' => 'fixed',
          'rate' => 60.0,  'default_multiplier' => 1.0 },
        { 'key' => 'doprava_vseobecna', 'name' => 'Doprava všeobecná', 'kind' => 'fixed',
          'rate' => 100.0, 'default_multiplier' => 1.0 },
        { 'key' => 'balne',             'name' => 'Balné', 'kind' => 'fixed',
          'rate' => 100.0, 'default_multiplier' => 1.0 },
        { 'key' => 'ostatne',           'name' => 'Ostatné náklady', 'kind' => 'fixed',
          'rate' => 100.0, 'default_multiplier' => 1.0 },
        { 'key' => 'material_montaz',   'name' => 'Materiál na montáž', 'kind' => 'fixed',
          'rate' => 100.0, 'default_multiplier' => 1.0 },
        { 'key' => 'vizualizacia',      'name' => 'Vizualizácia + návrh', 'kind' => 'per_m2',
          'rate' => 15.0,  'default_multiplier' => 1.0 },
        { 'key' => 'odvody',            'name' => 'Odvody', 'kind' => 'fixed',
          'rate' => 100.0, 'default_multiplier' => 1.0 },
        { 'key' => 'zameranie',         'name' => 'Zameranie', 'kind' => 'fixed',
          'rate' => 100.0, 'default_multiplier' => 1.0 }
      ].freeze

      STANDARD_ROW_KEYS = SEED_STANDARD_ROWS.map { |r| r['key'] }.freeze

      # Rezimove hodnoty: kluc = kluc standardneho riadku ALEBO kluc sadzby
      # sluzby (mnoziny su disjunktne — strazi guard test). Seedujeme LEN tam,
      # kde su v realnych rozpoctoch DOLOZENE dve rozne hodnoty; zvysok necha
      # rezim bez ucinku (padne na zakladnu sadzbu), kym si ho Michal nevyplni.
      SEED_MODE_VALUES = {
        # doprava k zakaznikovi: 60 EUR (6/10), 80 EUR (4/10)
        'doprava_zakaznik' => { 'nizky' => 60.0, 'standard' => 60.0, 'vysoky' => 80.0 },
        # opracovanie PD: 50 EUR (starsie), 100 EUR (najnovsie = standard)
        'pd_opracovanie'   => { 'nizky' => 50.0, 'standard' => 100.0, 'vysoky' => 100.0 }
      }.freeze

      # Rozsahy pre zapisovu cestu (patch z okna Nastavenia — E-b).
      RATE_RANGE       = (0.0..100_000.0)
      MULTIPLIER_RANGE = (0.0..1_000.0)
      STALE_DAYS_RANGE = (1..3_650)
      ROUNDING_RANGE   = (0.01..1_000.0)
      RESERVE_RANGE    = (0.0..100.0)
      M2_PER_PLATE_RANGE = (0.1..100.0)
      CP_THRESHOLD_RANGE = (0.0..1_000_000.0)
      KERF_RANGE          = (0.0..10.0) # NP-2: prerez 0–10 mm
      TRIM_RANGE          = (0.0..50.0) # NP-2: orez 0–50 mm
      DUP_ALLOWANCE_RANGE = (0.0..30.0) # NP-2: pridavok duplaku 0–30 mm

      # Skalare editovatelne patchom z okna Nastavenia + ich rozsahy (jedna
      # autorita pre validaciu aj chybovu hlasku).
      SCALAR_RANGES = {
        'rounding_step' => ROUNDING_RANGE, 'abs_reserve_pct' => RESERVE_RANGE,
        'montaz_m2_per_plate' => M2_PER_PLATE_RANGE, 'cp_highlight_threshold' => CP_THRESHOLD_RANGE,
        'kerf_mm' => KERF_RANGE, 'trim_mm' => TRIM_RANGE, 'dup_allowance_mm' => DUP_ALLOWANCE_RANGE
      }.freeze

      # NP-2: ludske mena a jednotky skalarov pre CHYBU ROZSAHU (predtym
      # surovy kluc „kerf_mm: hodnota mimo…").
      # Popis = PRESNE text riadku v sekcii (JS `SS_SCALARS`) — server aj klient
      # tak hovoria to iste („Prerez píly (hrúbka kotúča): …"); zhodu strazi test.
      SCALAR_LABELS = {
        'abs_reserve_pct' => ['ABS rezerva', '%'],
        'montaz_m2_per_plate' => ['m² na jednu platňu (montáž)', 'm²'],
        'kerf_mm' => ['Prerez píly (hrúbka kotúča)', 'mm'],
        'trim_mm' => ['Orez okraja platne', 'mm'],
        'dup_allowance_mm' => ['Prídavok dupláku na stranu', 'mm'],
        'rounding_step' => ['Zaokrúhlenie ponuky nahor na', '€'],
        'stale_days' => ['Upozorniť na cenu staršiu ako', 'dní'],
        'cp_highlight_threshold' => ['Samostatný riadok v cenovej ponuke od', '€']
      }.freeze

      # NP-2: kluce parametrov SheetLayout -> kluce skalarov dodavatela.
      LAYOUT_KEYS = { 'kerf' => 'kerf_mm', 'trim' => 'trim_mm', 'dup_allowance' => 'dup_allowance_mm' }.freeze

      FALLBACK_REASON = 'Súbor nastavení dodávateľa sa nepodarilo načítať — všetky sadzby a výpočtové ' \
                        'hodnoty sú predvolené a počíta s nimi rozpočet aj Kontrola. Uložením sa súbor ' \
                        'prepíše predvolenými hodnotami s tvojou zmenou.'

      module_function

      # --- ulozisko ------------------------------------------------------------

      # R-08 (audit 1d #1): zdielany %APPDATA%/NOXUN/Engine — TA ISTA cesta,
      # akou ju pocita Materials (+ test_dir_override), aby zamok a data vzdy
      # sedeli v jednom priecinku. Produkcia sa nemeni.
      def dir
        return Materials.dir if defined?(Materials) && Materials.respond_to?(:dir)

        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # R-08: jeden sidecar zamok (`materials.lock`) pre vsetky katalogy
      # priecinka — vzor 1b-6c, reentrantny, zlyhanie = IOError.
      def with_catalog_lock(&blk)
        Materials.with_catalog_lock(&blk)
      end

      # Cely dokument (normalizovany, po seed-merge). Poskodeny/chybajuci subor
      # = seed (vzor HardwareRules.load — fallback NIKDY nevrati nil).
      def load
        load_with_origin.first
      end

      # NP-2 (audit B2): TO ISTE citanie, ale s POVODOM dat -> [dokument, povod]:
      #   :file          — subor sa precital (ci z primaru alebo zo zalohy,
      #                    rozlisi az `active_with_source` — `degraded?` cita
      #                    disk a `load` bezi pri kazdom vypocte rozpoctu),
      #   :newer_file    — subor z NOVSIEHO pluginu (cita sa, nezapisuje sa),
      #   :seed_fallback — citanie ZLYHALO a vracia sa seed. Kto z nastaveni
      #                    pocita vyrobny verdikt (Kontrola), to MUSI priznat —
      #                    ulozeny orez 50 nahradeny predvolenym 10 by inak
      #                    potichu zmenil vysledok. Len chybajuci/poskodeny
      #                    subor bez zalohy — prvy zapis ho opravi,
      #   :unreadable    — citanie ZLYHALO na pravach/zdielani/disku: seed ako
      #                    pri fallbacku, ale zapisy su vypnute (`read_failure_origin`).
      # Povod sa urcuje TU, nie rescue-om vo volajucom: `load` chybu pohlti
      # a vrati seed, takze neskor sa fallback od suboru rozlisit neda.
      def load_with_origin
        ensure_seeded
        merged, changed = read_doc
        merged = persist_seed_merge!(merged) if changed
        # Codex #419 P2: povod AZ z dokumentu PO seed-merge — `persist_seed_merge!`
        # cita subor nanovo pod zamkom a medzitym ho mohol prepisat novsi plugin;
        # povod zo stareho citania by povedal `ok` nad novsim suborom.
        origin = doc_std_unsupported?(merged) ? :newer_file : :file
        [merged, origin]
      rescue StandardError => e
        Engine.log_error(e, 'SupplierSettings.load') if defined?(Engine)
        [seed_doc, read_failure_origin(e)]
      end

      # Codex #419 kolo 2 (P2): ZAPISOVATELNY fallback je len chybajuci subor
      # a poskodeny obsah bez pouzitelnej zalohy (`JSON::ParserError`,
      # `Errno::ENOENT`) — tam prvy zapis subor opravi. Ostatne chyby citania
      # (prava, zdielanie, disk) o subore NEHOVORIA NIC a zapis ich zamerne
      # nepreskoci (`JsonFileStore.degraded?` ich propaguje) — sekcia teda
      # nesmie slubovat, ze ulozenie pomoze: `:unreadable` = zapisy vypnute.
      def read_failure_origin(err)
        err.is_a?(JSON::ParserError) || err.is_a?(Errno::ENOENT) ? :seed_fallback : :unreadable
      end

      # CISTE citanie + seed-merge BEZ zapisu -> [dokument, changed].
      # NP-2: dokument z NOVSIEHO pluginu sa v pamati normalizuje a doplni
      # (rozpocet aj Kontrola ho potrebuju cely), ale `changed` je vzdy false —
      # seed-merge sa don NEZAPISUJE (brana v `write` by ho aj tak odmietla;
      # takto sa o zapis ani nepokusa pri kazdom nacitani).
      # NP-4 (audit B3): ani subor s POSKODENYM skalarom narezoveho planu sa
      # seed-merge nezapisuje — zapis by neplatnu hodnotu nahradil predvolenou
      # a dokaz „nastavenia su poskodene" (Kontrola, cena podla planu) by
      # potichu zmizol. Opravi ho az vedome ulozenie v sekcii Nastavenia.
      # H9 (R6): plati pre KAZDY opraveny skalar ktorehokolvek dodavatela.
      # H9/R-37: cita sa s OCAKAVANYM TVAROM (`read_valid`) — subor zleho tvaru
      # ide na dobru zalohu, inak `InvalidShape` (= `:seed_fallback`, nic sa
      # pri nacitani nezapise).
      def read_doc
        raw = JsonFileStore.read_valid(path, shape: shape_check, copy: true)
        doc, changed = merge_seed(normalize(raw))
        repaired = Array(doc['suppliers']).any? { |s| !Array(s[REPAIRED_KEY]).empty? }
        [doc, changed && !doc_std_unsupported?(raw) && !repaired]
      end

      # H9/R-37 (R2): ocakavany tvar suboru — LEN kontajnery, ktore zapisuje
      # kazda verzia (cisla posudzuje normalizacia/NP-4). Novsi format posudzuje
      # NP-2, nie tento predikat. `standard_rows: []` je legitimny (seed-merge).
      def doc_shape_ok?(doc)
        return false unless doc.is_a?(Hash)
        return true if doc_std_unsupported?(doc)

        sups = doc['suppliers']
        sups.is_a?(Array) && !sups.empty? && sups.all? do |s|
          s.is_a?(Hash) && s['rates'].is_a?(Hash) && !s['rates'].empty? &&
            (!s.key?('standard_rows') || s['standard_rows'].is_a?(Array)) &&
            (!s.key?('mode_values') || s['mode_values'].is_a?(Hash))
        end
      end

      def shape_check
        method(:doc_shape_ok?)
      end

      # R-08 (audit 1d #2/#10): seed-merge je READ-MODIFY-WRITE. Pod zamkom sa
      # cita NANOVO a merge sa PREPOCITA; ked ho medzitym urobila druha
      # instancia, `changed` je false a nezapisuje sa. Zlyhany zamok/citanie
      # vrati predzamkovy kandidat.
      def persist_seed_merge!(fallback)
        with_catalog_lock do
          JsonFileStore.reload!(path)
          fresh, changed = read_doc
          write(fresh) if changed
          fresh
        end
      rescue StandardError => e
        Engine.log_error(e, 'SupplierSettings.persist_seed_merge!') if defined?(Engine)
        fallback
      end

      # Nastavenia AKTIVNEHO dodavatela — jediny vstup pre Budget.
      # (Bez zistovania zdroja — `degraded?` cita disk a `active` vola rozpocet
      # pri kazdom vypocte; zdroj si pyta len ten, kto ho potrebuje.)
      def active
        supplier_of(load)
      end

      def supplier_of(doc)
        supplier_by_id(doc, doc['active']) || doc['suppliers'].first || seed_supplier
      end

      # NP-2: aktivny dodavatel + ZDROJ dat -> [supplier, source], source je
      # :file | :backup | :newer_file | :seed_fallback | :unreadable. `:backup` = poskodeny
      # primar s platnou zalohou (R-11); ma prednost pred `:newer_file` (to
      # iste poradie ako brany v `write`).
      def active_with_source
        doc, origin = load_with_origin
        [supplier_of(doc), refine_origin(origin)]
      end

      def refine_origin(origin)
        return origin if origin == :seed_fallback || origin == :unreadable
        return :backup if degraded_now?

        origin
      end

      # Chyba pri zisteni degradacie = „nevieme" -> povod ostava (zapisova
      # brana si ho aj tak overi sama pod zamkom a fail-closed).
      def degraded_now?
        JsonFileStore.degraded?(path, shape: shape_check)
      rescue StandardError
        false
      end

      # NP-2: parametre narezoveho planu pre volajucich (Kontrola; NP-3 plan).
      # -> { params: {'kerf', 'trim', 'dup_allowance'} (Float mm), source:,
      #      version_ok:, repaired: }
      # Pri `:seed_fallback` aj `:unreadable` su hodnoty PREDVOLENE a volajuci
      # to musi priznat (Kontrola ORANGE nalezom, plan vetou „orientačne").
      # NP-4 (audit B2, B3) — dve priznania NEZAVISLE od `source`:
      #   version_ok — dokument NIE JE z novsej verzie formatu. `refine_origin`
      #     prepise `:newer_file` na `:backup`, ked je primar poskodeny, takze
      #     zdroj sam novsiu zalohu neprezradi; cena podla planu ju nesmie brat.
      #   repaired   — kluce prerezu/orezu/pridavku, ktore v subore BOLI
      #     neplatne a normalizacia ich nahradila predvolenymi (zdroj ostal `:file`).
      def layout_params
        doc, origin = load_with_origin
        sup = supplier_of(doc)
        params = LAYOUT_KEYS.each_with_object({}) { |(k, sk), out| out[k] = scalar(sup, sk).to_f }
        { params: params, source: refine_origin(origin), version_ok: origin != :newer_file,
          repaired: layout_repaired(sup) }
      end

      # NP-2: stav suboru pre sekciu Nastavenia rozpoctu (banner + vypnute
      # „Uložiť" pri `degraded`, `newer` a `unreadable`).
      # -> { 'state' => ok|degraded|newer|fallback|unreadable, 'reason' => veta }
      def settings_state(source)
        case source
        when :backup then { 'state' => 'degraded', 'reason' => degraded_reason }
        when :newer_file then { 'state' => 'newer', 'reason' => std_block_reason(disk_std) }
        when :seed_fallback then { 'state' => 'fallback', 'reason' => FALLBACK_REASON }
        when :unreadable then { 'state' => 'unreadable', 'reason' => unreadable_reason }
        else { 'state' => 'ok', 'reason' => '' }
        end
      end

      def unreadable_reason
        'Súbor nastavení dodávateľa sa nedá čítať (prístup odmietnutý, súbor drží iný program alebo chyba ' \
          'disku) — zobrazujú sa predvolené hodnoty a počíta s nimi rozpočet aj Kontrola; zápisy sú vypnuté. ' \
          "Skontroluj súbor #{path} a klikni na Obnoviť v lište sekcie Nastavenia rozpočtu."
      end

      # Verzia suboru na disku (pre vetu brany); chyba citania = „novsia".
      def disk_std
        doc = JsonFileStore.read(path, copy: false)
        doc.is_a?(Hash) ? doc['std'].to_i : STD + 1
      rescue StandardError
        STD + 1
      end

      # NP-2: je dokument z NOVSEJ verzie formatu? JEDINA autorita otazky
      # (citanie, seed-merge aj zapisova brana). Chybajuci `std` = format 1.
      def doc_std_unsupported?(doc)
        doc.is_a?(Hash) && doc.key?('std') && doc['std'].to_i > STD
      end

      # Veta zablokovaneho zapisu pre subor z novsieho pluginu — jedno znenie
      # pre patch, banner aj log.
      def std_block_reason(std)
        "Nastavenia dodávateľa uložil novší plugin (verzia súboru #{std}, tento plugin pozná #{STD}) — " \
          'dajú sa len čítať, zápisy sú vypnuté (aktualizuj plugin).'
      end

      def supplier_by_id(doc, id)
        Array(doc['suppliers']).find { |s| s['id'].to_s == id.to_s }
      end

      # R-08 (audit 1d #1): rychly check ostava, ZAPIS seedu az po DRUHOM
      # checku POD zamkom — oneskoreny seeder inak prepise realnu zmenu druhej
      # instancie.
      def ensure_seeded
        return if JsonFileStore.available?(path)
        with_catalog_lock do
          next true if JsonFileStore.available?(path)
          write(seed_doc)
        end
      rescue StandardError => e
        Engine.log_error(e, 'SupplierSettings.ensure_seeded') if defined?(Engine)
        false
      end

      # R-08 (audit 1d #7): vracia sa PRESNY vysledok zapisu, nie bezpodmienecne
      # `true`. Dnesny `JsonFileStore.write` bud vrati true, alebo vyhodi — ale
      # R-11 ma pridat write guard, ktory zapis ODMIETNE bez vynimky; s
      # bezpodmienecnym `true` by sa odmietnutie hlasilo ako ulozene.
      #
      # 1d/R-11: presne ten predpovedany guard. Poskodeny primar s platnou
      # `.bak` sa cita zo ZALOHY — zapis by nastavenia prepisal STARSIM
      # obsahom, takze sa ODMIETNE (bez vynimky) a `write` vrati `false`.
      #
      # NP-2: za degradovanym suborom stoji DRUHA brana — subor z NOVSIEHO
      # pluginu (`newer_write_blocked?`) — a kazdy zapis PECIATKUJE `std = STD`.
      def write(doc)
        with_catalog_lock do
          next false if degraded_write_blocked?
          next false if newer_write_blocked?

          JsonFileStore.write(path, normalize(doc).merge('std' => STD), shape_check)
        end
      rescue StandardError => e
        Engine.log_error(e, 'SupplierSettings.write') if defined?(Engine)
        false
      end

      # Dovod odmietnutia POSLEDNEHO zapisu (prazdny = nic sa neodmietlo).
      # `patch_active!` uz ma kanal chyb, takze si ho vyzdvihne rovno do
      # `errors` — okno Nastavenia tak ukaze KONKRETNU vetu namiesto
      # vseobecneho „nastavenia sa nepodarilo ulozit".
      def write_block_reason
        @write_block_reason.to_s
      end

      # Brana bezi POD ZAMKOM nad cerstvym stavom suboru (lekcia R-07 B2).
      # I/O chyba z `degraded?` sa NEchyta — vyleti do rescue vetvy `write`.
      def degraded_write_blocked?
        prev = @write_block_reason
        @write_block_reason = ''
        return false unless JsonFileStore.degraded?(path, shape: shape_check)

        @write_block_reason = degraded_reason
        # Log LEN pri ZMENE stavu — seed-merge sa o zapis pokusa pri kazdom
        # nacitani, takze bezpodmienecny zapis by zaplavil Ruby konzolu.
        if prev.to_s != @write_block_reason && defined?(Engine)
          Engine.log("supplier settings: zapis odmietnuty — #{@write_block_reason}")
        end
        true
      end

      def degraded_reason
        'Nastavenia dodávateľa sú poškodené — číta sa záloha, zápisy sú ' \
          "vypnuté (oprav alebo zmaž súbor #{path})"
      end

      # NP-2: DRUHA zapisova brana — subor z NOVSIEHO pluginu. Bezi POD ZAMKOM
      # (vola ju len `write`) a verziu cita CERSTVO z disku: sekundova cache
      # `JsonFileStore.read` by nahriatu starsiu verziu vratila aj vtedy, ked
      # medzitym novsi plugin subor prepisal (audit NP-2 F4 — `write` je
      # verejny a nie kazdy volajuci pred nim robi `reload!`).
      # Neprecitatelny subor sem NEPATRI (jeho branu drzi R-11) — nil = nie novsi.
      # `@write_block_reason` LEN doplna: pri degradacii sa sem nedojde.
      def newer_write_blocked?
        doc = begin
          JsonFileStore.reload!(path)
          JsonFileStore.read(path, copy: false)
        rescue StandardError
          nil
        end
        return false unless doc_std_unsupported?(doc)

        prev = @write_block_reason
        @write_block_reason = std_block_reason(doc['std'].to_i)
        if prev.to_s != @write_block_reason && defined?(Engine)
          Engine.log("supplier settings: zapis odmietnuty — #{@write_block_reason}")
        end
        true
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- seed ----------------------------------------------------------------

      def seed_doc
        { 'std' => STD, 'seed_version' => SEED_VERSION, 'active' => DEFAULT_ID,
          'suppliers' => [seed_supplier] }
      end

      def seed_supplier(id = DEFAULT_ID, name = DEFAULT_NAME)
        { 'id' => id, 'name' => name,
          'rates' => deep_copy(SEED_RATES),
          'standard_rows' => deep_copy(SEED_STANDARD_ROWS),
          'mode_values' => deep_copy(SEED_MODE_VALUES) }.merge(deep_copy(SCALAR_DEFAULTS))
      end

      # Doplni LEN to, co chyba (kluce sadzieb, skalare, standardne riadky,
      # rezimove hodnoty) — pouzivatelska hodnota sa nikdy neprepise.
      # 8 standardnych riadkov je FIXNA mnozina: zmazany riadok merge vrati
      # (riadok sa "vypina" nasobkom 0, ktory ostava viditelny v rozpocte).
      # Ocakava NORMALIZOVANY dokument (load ho tak vola); guardy nizsie kryju
      # aj priame volanie nad surovym tvarom.
      # -> [doc, changed]
      def merge_seed(doc)
        changed = false
        from_version = doc['seed_version'].to_i
        doc['suppliers'] = [seed_supplier] if Array(doc['suppliers']).empty?
        doc['suppliers'].each do |sup|
          sup['rates'] = {} unless sup['rates'].is_a?(Hash)
          sup['standard_rows'] = [] unless sup['standard_rows'].is_a?(Array)
          sup['mode_values'] = {} unless sup['mode_values'].is_a?(Hash)
          SEED_RATES.each do |k, v|
            next if sup['rates'].key?(k)
            sup['rates'][k] = v
            changed = true
          end
          SCALAR_DEFAULTS.each do |k, v|
            next if sup.key?(k) && !sup[k].nil?
            sup[k] = v
            changed = true
          end
          have = {}
          sup['standard_rows'].each { |r| have[r['key']] = true }
          SEED_STANDARD_ROWS.each do |row|
            next if have[row['key']]
            sup['standard_rows'] << deep_copy(row)
            changed = true
          end
          # poradie = kanonicke seed poradie, neznáme (buduce/vlastne) kluce na koniec
          ordered = STANDARD_ROW_KEYS.map { |k| sup['standard_rows'].find { |r| r['key'] == k } }.compact
          rest = sup['standard_rows'].reject { |r| STANDARD_ROW_KEYS.include?(r['key']) }
          reordered = ordered + rest
          if reordered.map { |r| r['key'] } != sup['standard_rows'].map { |r| r['key'] }
            sup['standard_rows'] = reordered
            changed = true
          end
          # GH #137 P2: rezimove hodnoty sa seeduju LEN RAZ per SEED_VERSION.
          # Su to JEDINE polia, ktore smie pouzivatel VEDOME zmazat (patch
          # null = "pouzi zakladnu sadzbu") — unconditional merge by mu ich
          # pri najblizsom nacitani ticho vratil. Nove rezimove hodnoty
          # buduceho seedu pridu s bumpom SEED_VERSION.
          if from_version < SEED_VERSION
            SEED_MODE_VALUES.each do |key, modes|
              cur = sup['mode_values'][key]
              unless cur.is_a?(Hash)
                sup['mode_values'][key] = deep_copy(modes)
                changed = true
                next
              end
              modes.each do |mode, value|
                next if cur.key?(mode)
                cur[mode] = value
                changed = true
              end
            end
          end
        end
        unless supplier_by_id(doc, doc['active'])
          doc['active'] = doc['suppliers'].first['id']
          changed = true
        end
        if doc['seed_version'].to_i < SEED_VERSION
          doc['seed_version'] = SEED_VERSION
          changed = true
        end
        [doc, changed]
      end

      # --- normalizacia --------------------------------------------------------

      # Defenzivna normalizacia CELEHO dokumentu (rucne upraveny JSON, starsi
      # zapis, poskodene typy). Nikdy nevyhodi vynimku, nikdy nevrati nil.
      # Tvar je WHITELIST — cokolvek mimo znamych poli sa zahodi (subor su
      # nastavenia, nie pouzivatelske data; verziu formatu nesie `std` a
      # buducu migraciu urobi kod, ktory nove pole zavedie).
      def normalize(raw)
        doc = raw.is_a?(Hash) ? deep_copy(stringify(raw)) : {}
        suppliers = Array(doc['suppliers']).map { |s| normalize_supplier(s) }.compact
        suppliers = [seed_supplier] if suppliers.empty?
        active = doc['active'].to_s
        active = suppliers.first['id'] unless suppliers.any? { |s| s['id'] == active }
        { 'std' => (doc['std'].to_i.positive? ? doc['std'].to_i : STD),
          'seed_version' => doc['seed_version'].to_i,
          'active' => active,
          'suppliers' => suppliers }
      end

      def normalize_supplier(raw)
        return nil unless raw.is_a?(Hash)
        id = raw['id'].to_s.strip
        id = DEFAULT_ID if id.empty?
        name = raw['name'].to_s.strip
        name = DEFAULT_NAME if name.empty?
        rates = {}
        src_rates = raw['rates'].is_a?(Hash) ? raw['rates'] : {}
        src_rates.each do |k, v|
          f = num(v)
          rates[k.to_s] = f unless f.nil? || f.negative?
        end
        out = { 'id' => id, 'name' => name, 'rates' => rates,
                'standard_rows' => normalize_rows(raw['standard_rows']),
                'mode_values' => normalize_mode_values(raw['mode_values']) }
        out['stale_days'] = int_in(raw['stale_days'], STALE_DAYS_RANGE, SCALAR_DEFAULTS['stale_days'])
        out['rounding_step'] = num_in(raw['rounding_step'], ROUNDING_RANGE, SCALAR_DEFAULTS['rounding_step'])
        out['abs_reserve_pct'] = num_in(raw['abs_reserve_pct'], RESERVE_RANGE, SCALAR_DEFAULTS['abs_reserve_pct'])
        out['montaz_m2_per_plate'] = num_in(raw['montaz_m2_per_plate'], M2_PER_PLATE_RANGE,
                                            SCALAR_DEFAULTS['montaz_m2_per_plate'])
        out['cp_highlight_threshold'] = num_in(raw['cp_highlight_threshold'], CP_THRESHOLD_RANGE,
                                               SCALAR_DEFAULTS['cp_highlight_threshold'])
        # NP-2: skalare narezoveho planu (chybajuce/mimo rozsahu = predvolene).
        out['kerf_mm'] = num_in(raw['kerf_mm'], KERF_RANGE, SCALAR_DEFAULTS['kerf_mm'])
        out['trim_mm'] = num_in(raw['trim_mm'], TRIM_RANGE, SCALAR_DEFAULTS['trim_mm'])
        out['dup_allowance_mm'] = num_in(raw['dup_allowance_mm'], DUP_ALLOWANCE_RANGE,
                                         SCALAR_DEFAULTS['dup_allowance_mm'])
        repaired = repaired_scalars(raw)
        out[REPAIRED_KEY] = repaired unless repaired.empty?
        out
      end

      # NP-4 (audit B3): skalare, ktore v subore BOLI, ale mali neplatnu
      # hodnotu (necislo, mimo rozsahu) — normalizacia ich potichu nahradila
      # predvolenymi a povod suboru ostal `:file`. CHYBAJUCI kluc (legacy subor
      # bez novych poli, aj `null`) sem NEPATRI — jeho doplnenie je dovolene.
      # Odvodeny udaj LEN v pamati: zapis ho zahodi (whitelist `normalize`),
      # `revision` ho z platnych hodnot nikdy nezlozi.
      REPAIRED_KEY = 'repaired_scalars'
      SCALAR_CHECKS = {
        'stale_days' => STALE_DAYS_RANGE, 'rounding_step' => ROUNDING_RANGE,
        'abs_reserve_pct' => RESERVE_RANGE, 'montaz_m2_per_plate' => M2_PER_PLATE_RANGE,
        'cp_highlight_threshold' => CP_THRESHOLD_RANGE, 'kerf_mm' => KERF_RANGE,
        'trim_mm' => TRIM_RANGE, 'dup_allowance_mm' => DUP_ALLOWANCE_RANGE
      }.freeze

      def repaired_scalars(raw)
        SCALAR_CHECKS.each_with_object([]) do |(key, range), out|
          next unless raw.key?(key) && !raw[key].nil?

          v = key == 'stale_days' ? int_or_nil(raw[key]) : num(raw[key])
          out << key if v.nil? || !range.cover?(v)
        end
      end

      # NP-4: opravene skalare NAREZOVEHO PLANU aktivneho dodavatela (kluce
      # skalarov, napr. ['trim_mm']).
      def layout_repaired(supplier)
        list = supplier.is_a?(Hash) ? Array(supplier[REPAIRED_KEY]) : []
        LAYOUT_KEYS.values & list
      end

      def normalize_rows(raw)
        seed_by_key = {}
        SEED_STANDARD_ROWS.each { |r| seed_by_key[r['key']] = r }
        seen = {}
        Array(raw).map do |r|
          next nil unless r.is_a?(Hash)
          key = r['key'].to_s.strip
          next nil if key.empty? || seen[key]
          seen[key] = true
          seed = seed_by_key[key]
          kind = r['kind'].to_s.strip
          kind = (seed ? seed['kind'] : 'fixed') unless ROW_KINDS.include?(kind)
          name = r['name'].to_s.strip
          name = (seed ? seed['name'] : key) if name.empty?
          { 'key' => key, 'name' => name, 'kind' => kind,
            'rate' => num_in(r['rate'], RATE_RANGE, seed ? seed['rate'] : 0.0),
            'default_multiplier' => num_in(r['default_multiplier'], MULTIPLIER_RANGE,
                                           seed ? seed['default_multiplier'] : 1.0) }
        end.compact
      end

      def normalize_mode_values(raw)
        out = {}
        return out unless raw.is_a?(Hash)
        raw.each do |key, modes|
          next unless modes.is_a?(Hash)
          k = key.to_s.strip
          next if k.empty?
          vals = {}
          MODES.each do |mode|
            f = num(modes[mode])
            vals[mode] = f unless f.nil? || f.negative?
          end
          out[k] = vals unless vals.empty?
        end
        out
      end

      # --- citanie hodnot (JEDNA autorita rezimoveho rozhodnutia) --------------

      # Sadzba sluzby s ohladom na rezim: rezimova hodnota vyhrava, inak zakladna
      # sadzba. Neznamy rezim = DEFAULT_MODE (rezim nikdy nezhodi vypocet).
      def rate(supplier, key, mode = DEFAULT_MODE)
        base = num(supplier.is_a?(Hash) && supplier['rates'].is_a?(Hash) ? supplier['rates'][key.to_s] : nil)
        base = num(SEED_RATES[key.to_s]) if base.nil?
        mode_value(supplier, key, mode) || base || 0.0
      end

      # Sadzba standardneho riadku s ohladom na rezim.
      def row_rate(supplier, row, mode = DEFAULT_MODE)
        base = num(row.is_a?(Hash) ? row['rate'] : nil) || 0.0
        mode_value(supplier, row.is_a?(Hash) ? row['key'] : nil, mode) || base
      end

      def mode_value(supplier, key, mode)
        return nil unless supplier.is_a?(Hash) && supplier['mode_values'].is_a?(Hash)
        m = MODES.include?(mode.to_s) ? mode.to_s : DEFAULT_MODE
        vals = supplier['mode_values'][key.to_s]
        return nil unless vals.is_a?(Hash)
        num(vals[m])
      end

      # V0.6 E-b: odtlacok stavu AKTIVNEHO dodavatela — baseline guard okna
      # Nastavenia (vzor `catalog_revision` v Materials). Okno si revziu zapamata
      # pri otvoreni a posle ju spat pri ulozeni; ak sa medzitym zmenila (iny
      # dialog, rucna uprava suboru, seed-merge), zapis sa ODMIETNE a formular
      # sa nacita nanovo — inak by tichy prepis zahodil cudziu zmenu.
      def revision(supplier)
        Digest::SHA1.hexdigest(JSON.generate(normalize_supplier(supplier) || {}))[0, 12]
      rescue StandardError
        ''
      end

      def standard_rows(supplier)
        rows = supplier.is_a?(Hash) ? supplier['standard_rows'] : nil
        rows.is_a?(Array) && !rows.empty? ? rows : deep_copy(SEED_STANDARD_ROWS)
      end

      def scalar(supplier, key)
        v = supplier.is_a?(Hash) ? supplier[key.to_s] : nil
        f = key.to_s == 'stale_days' ? int_or_nil(v) : num(v)
        f.nil? ? SCALAR_DEFAULTS[key.to_s] : f
      end

      # --- zapisova cesta (okno Nastavenia, E-b) ------------------------------

      # Bezpecny patch AKTIVNEHO dodavatela — whitelist poli, VALIDATE-ALL pred
      # zapisom (all-or-nothing; ziadny ciastocny zapis). Identita (id, kluce
      # riadkov, kind) sa patchom NIKDY nemeni.
      # patch: { 'name', 'stale_days', 'rounding_step', 'abs_reserve_pct',
      #          'montaz_m2_per_plate', 'rates' => {key=>val},
      #          'standard_rows' => {key=>{'name','rate','default_multiplier'}},
      #          'mode_values' => {key=>{mode=>val|null}} }
      #
      # R-08 (audit 1d #9): cele citanie, kontrola REVIZIE aj zapis beziu pod
      # JEDNYM medziprocesovym zamkom nad CERSTVYM suborom. Kym revizia sedela
      # len v okne (`supplier_settings_dialog.handle_save`), medzi jej
      # kontrolou a nasim zapisom stihla druha instancia ulozit svoje sadzby
      # a nas `load -> mutuj -> write` ich zmazal — pricom okno hlasilo
      # „Nastavenia uložené".
      #
      # -> [ok, [chyby], status] kde status = :ok | :invalid | :conflict |
      # :write_failed. Tretí prvok je ADITIVNY — dnesne `ok, errors = ...`
      # destructuring ostava funkcny.
      #
      # `revision` je POZICNY (nie kluc): metoda sa bezne vola s BEZZATVORKOVYM
      # hashom (`patch_active!('rates' => {...})`) a Ruby 3 by taky hash pri
      # existencii kwargs poslal DO NICH — z volania by zmizol povinny `patch`.
      def patch_active!(patch, revision = nil)
        return [false, ['nastavenia musia byť objekt'], :invalid] unless patch.is_a?(Hash)
        with_catalog_lock do
          JsonFileStore.reload!(path)
          patch_active_locked!(patch, revision)
        end
      rescue StandardError => e
        Engine.log_error(e, 'SupplierSettings.patch_active!') if defined?(Engine)
        [false, ['nastavenia sa nepodarilo uložiť'], :write_failed]
      end

      # Telo patchu BEZ zamku — volat VYHRADNE zvnutra `patch_active!`
      # (vzor `Materials.write_unlocked`).
      def patch_active_locked!(patch, revision = nil)
        doc = load
        sup = supplier_by_id(doc, doc['active'])
        return [false, ['aktívny dodávateľ sa nenašiel'], :invalid] unless sup
        if revision && revision.to_s != self.revision(sup)
          return [false, ['nastavenia sa medzitým zmenili'], :conflict]
        end
        errors = []
        p = stringify(patch)

        name = p['name']
        if !name.nil?
          v = name.to_s.strip
          errors << 'názov dodávateľa nesmie byť prázdny' if v.empty?
        end

        SCALAR_RANGES.each do |key, range|
          next unless p.key?(key)
          f = num(p[key])
          errors << range_error(key, range) if f.nil? || !range.cover?(f)
        end
        if p.key?('stale_days')
          i = int_or_nil(p['stale_days'])
          errors << range_error('stale_days', STALE_DAYS_RANGE) if i.nil? || !STALE_DAYS_RANGE.cover?(i)
        end
        if p.key?('rates')
          rates = p['rates']
          if rates.is_a?(Hash)
            rates.each do |k, v|
              unless RATE_KEYS.include?(k.to_s)
                errors << "neznáma sadzba „#{k}“"
                next
              end
              f = num(v)
              errors << "sadzba „#{k}“: hodnota mimo rozsahu" if f.nil? || !RATE_RANGE.cover?(f)
            end
          else
            errors << 'rates musí byť objekt'
          end
        end
        if p.key?('standard_rows')
          rows = p['standard_rows']
          if rows.is_a?(Hash)
            existing = {}
            standard_rows(sup).each { |r| existing[r['key']] = r }
            rows.each do |k, attrs|
              unless existing[k.to_s]
                errors << "neznámy štandardný riadok „#{k}“"
                next
              end
              unless attrs.is_a?(Hash)
                errors << "riadok „#{k}“ musí byť objekt"
                next
              end
              if attrs.key?('rate')
                f = num(attrs['rate'])
                errors << "riadok „#{k}“: sadzba mimo rozsahu" if f.nil? || !RATE_RANGE.cover?(f)
              end
              if attrs.key?('default_multiplier')
                f = num(attrs['default_multiplier'])
                errors << "riadok „#{k}“: násobok mimo rozsahu" if f.nil? || !MULTIPLIER_RANGE.cover?(f)
              end
              errors << "riadok „#{k}“: názov nesmie byť prázdny" if attrs.key?('name') && attrs['name'].to_s.strip.empty?
            end
          else
            errors << 'standard_rows musí byť objekt'
          end
        end
        if p.key?('mode_values')
          mv = p['mode_values']
          if mv.is_a?(Hash)
            known = STANDARD_ROW_KEYS + RATE_KEYS
            mv.each do |k, modes|
              errors << "režimové hodnoty: neznámy kľúč „#{k}“" unless known.include?(k.to_s)
              unless modes.is_a?(Hash)
                errors << "režimové hodnoty „#{k}“ musia byť objekt"
                next
              end
              modes.each do |mode, value|
                errors << "režim „#{mode}“ neexistuje" unless MODES.include?(mode.to_s)
                next if value.nil? # null = zmazanie rezimovej hodnoty
                f = num(value)
                errors << "režim „#{mode}“ (#{k}): hodnota mimo rozsahu" if f.nil? || !RATE_RANGE.cover?(f)
              end
            end
          else
            errors << 'mode_values musí byť objekt'
          end
        end
        return [false, errors.uniq, :invalid] unless errors.empty?

        sup['name'] = p['name'].to_s.strip unless p['name'].nil?
        SCALAR_RANGES.each_key do |key|
          sup[key] = num(p[key]) if p.key?(key)
        end
        sup['stale_days'] = int_or_nil(p['stale_days']) if p.key?('stale_days')
        if p['rates'].is_a?(Hash)
          p['rates'].each { |k, v| sup['rates'][k.to_s] = num(v) }
        end
        if p['standard_rows'].is_a?(Hash)
          rows = standard_rows(sup)
          p['standard_rows'].each do |k, attrs|
            row = rows.find { |r| r['key'] == k.to_s }
            next unless row
            row['name'] = attrs['name'].to_s.strip if attrs.key?('name')
            row['rate'] = num(attrs['rate']) if attrs.key?('rate')
            row['default_multiplier'] = num(attrs['default_multiplier']) if attrs.key?('default_multiplier')
          end
          sup['standard_rows'] = rows
        end
        if p['mode_values'].is_a?(Hash)
          sup['mode_values'] ||= {}
          p['mode_values'].each do |k, modes|
            cur = sup['mode_values'][k.to_s] ||= {}
            modes.each do |mode, value|
              if value.nil?
                cur.delete(mode.to_s)
              else
                cur[mode.to_s] = num(value)
              end
            end
            sup['mode_values'].delete(k.to_s) if cur.empty?
          end
        end
        # R-11: ked zapis odmietla brana degradovaneho suboru, chyba MUSI
        # povedat preco — „nepodarilo sa uložiť" by pouzivatela poslalo hladat
        # problem s pravami, hoci naprava je oprava/zmazanie JEDNEHO suboru.
        unless write(doc)
          reason = write_block_reason
          return [false, [reason.empty? ? 'nastavenia sa nepodarilo uložiť' : reason], :write_failed]
        end
        [true, [], :ok]
      end

      # NP-2: chyba rozsahu LUDSKY — „Prerez píly (hrúbka kotúča): hodnota mimo rozsahu 0–10 mm"
      # (nie surovy kluc; desatinna ciarka ako v celom UI).
      def range_error(key, range)
        label, unit = SCALAR_LABELS[key.to_s] || [key.to_s, '']
        unit_txt = unit.to_s.empty? ? '' : " #{unit}"
        "#{label}: hodnota mimo rozsahu #{range_num(range.first)}–#{range_num(range.last)}#{unit_txt}"
      end

      def range_num(v)
        f = v.to_f
        return f.round.to_s if (f - f.round).abs < 1e-9

        f.to_s.tr('.', ',')
      end

      # --- pomocne -------------------------------------------------------------

      def num(v)
        return nil if v.nil?
        return nil if v.is_a?(String) && v.strip.empty?
        f = Float(v.to_s.tr(',', '.'))
        f.finite? ? f : nil
      rescue StandardError
        nil
      end

      def num_in(v, range, dflt)
        f = num(v)
        f.nil? || !range.cover?(f) ? dflt : f
      end

      def int_or_nil(v)
        f = num(v)
        f.nil? ? nil : f.round
      end

      def int_in(v, range, dflt)
        i = int_or_nil(v)
        i.nil? || !range.cover?(i) ? dflt : i
      end

      def stringify(value)
        case value
        when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_s] = stringify(v) }
        when Array then value.map { |v| stringify(v) }
        else value
        end
      end

      def deep_copy(value)
        case value
        when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_s] = deep_copy(v) }
        when Array then value.map { |v| deep_copy(v) }
        else value
        end
      end
    end
  end
end
