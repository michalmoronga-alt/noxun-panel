# frozen_string_literal: true
# H15 (blok 9 HARDENING, C-03) — GOLDEN CHARAKTERIZACIA SEED DAT KOVANIA PRED
# presunom dat do `core/*_seed.rb` (package H15, R0, §15 A1).
#
# PRECO: H15 presuva predvolene kovanie (sety, mapovania, stare tvary, katalog,
# taxonomia) z logickych suborov do dátových. Zavazok bloku 9 je BEZ ZMENY
# vyrobnych a cenovych cisel. Fixtury v `tests/fixtures/h15_golden/` vznikli
# z NEZMENENEHO mainu (prvy commit H15a, generator
# `tests/fixtures/h15_golden/generate.rb` sa spusta RUCNE) a tento test
# porovnava CERSTVY vypocet s nimi. V H15a ani H15b sa NEREGENERUJU —
# rozdiel je NALEZ (DoD H15: „golden fixtury nedotknute").
#
# CO SA ODTLACA (kazdy scenar vo VLASTNOM sandboxe %APPDATA%):
#   G1 seed konstanty troch modulov — trieda, velkost, zmrazenie obalu aj
#      prveho vnutorneho prvku, pocet NEzmrazenych retazcov v hlbke, poradie
#      identit a SHA-256 `Marshal` (typy, poradie klucov, Float vs Integer,
#      kodovanie retazcov) a JSON;
#   G2 cerstva instalacia — PLNY text troch suborov + `seed_library`
#      a `global_default_state`;
#   G3 upgrade kniznice setov (v1, v4, v7 nohy nedotknute/premenovane,
#      migracia `leg`, kolizia `prichyt-sokla-axilo`, vlastna triedna hodnota,
#      konflikt taxonomie, aktualna v8);
#   G4 upgrade katalogu (v1, v2 s pouzivatelskymi upravami, v4, v5)
#      a taxonomie (v2, cudzi vlastnik AXILO);
#   G5 projekt — „Doplniť nové predvoľby" nad snapshotom v4 + ponuka Pravidiel
#      (`class_set_options`) pre kazdy triedny kluc;
#   G6 behove citanie seedu (`flap_set_codes(nil)`);
#   G7 nakup a rozpocet END-TO-END nad cerstvou instalaciou: 5 KOVA pripadov
#      + zasuvka z receptu Atira + vyklop HK a HL top, vsetko s EXPLICITNYMI
#      materialmi (§15 A1 — bez nich sa hmotnost cela nedopocita a vyklop
#      vyda len prislusenstvo). Surovy CSV, JSON `expand`, sekcia `hardware`
#      rozpoctu.
#
# §15 A1: golden NESMIE pripnut neuplny nakup. `NxH15Golden.purchase_problems`
# overi (generator PRED zapisom, test potom stale): v riadkoch je mechanizmus
# alebo kit (zasuvka = K-sada, HK = mechanizmus, HL = mechanizmus + ramena +
# tyce v pocte `rod_count`), ziadny blokujuci konflikt ani nemapovana polozka
# a ziadny riadok mimo katalogu. Nesplnena podmienka = generator golden
# NEZAPISE a test padne.
#
# POROVNANIE: text po normalizacii CRLF -> LF (git na Windows checkoutuje
# CRLF); hlaska menuje fixturu a CESTU prvého rozdielu (scenar, konstanta,
# set, kod). Bezi len headless — sandbox %APPDATA% v SketchUpe nie je.
require_relative '../helper' unless defined?(NxTest)

require 'json'
require 'digest'
require 'fileutils'
require 'tmpdir'
# KOVA pripady G7 (jeden zdroj konfiguracii) — nacitat PRED registraciou testov.
require_relative 'test_kova_golden' unless defined?(NxKovaGolden)

module NxH15Golden
  E     = Noxun::Engine
  HS    = E::HardwareSets
  HC    = E::HardwareCatalog
  HT    = E::HardwareTaxonomy
  HR    = E::HardwareRules
  MATS  = E::Materials
  STORE = E::JsonFileStore

  DIR = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h15_golden')

  # Fixtury: JSON dokumenty (porovnanie cez prvu odlisnu cestu) a SUROVE subory
  # cerstvej instalacie (porovnanie po riadkoch).
  JSON_FIXTURES = %w[g1_konstanty g2_kniznica g3_upgrade_sety g4_upgrade_katalog
                     g5_projekt g6_flap g7_nakup].freeze
  RAW_FIXTURES = {
    'g2_hardware_sets.json' => :sets, 'g2_hardware_catalog.json' => :catalog,
    'g2_hardware_taxonomy.json' => :taxonomy
  }.freeze

  CONSTANTS = {
    'HardwareSets' => %w[SEED_VERSION SEED_SETS SEED_MAPPING LEGACY_SEED_SHAPES MAPPING_MIGRATIONS
                         MAPPING_ADDITIONS CLASS_MAPPING_KEYS SKIP_CODE],
    'HardwareCatalog' => %w[SEED_SET_VERSION SEED_ROWS SEED_ITEMS SEED_ROWS_V2 SEED_ITEMS_V2
                            SEED_PRODUCT_LINKS SEED_INACTIVE SEED_AVENTOS_V4 SEED_PRODUCT_CODES
                            SEED_PATCH_V2_ADD LEGACY_SEED_93240 SEED_PATCH_V3_ADD SEED_PATCH_V4_ADD
                            SEED_PATCH_V5_ADD SEED_PATCH_V5_CLASSIFY SEED_PRICE_CHECKED_AT
                            SEED_PRICE_CHECKED_AT_V4 SEED_MATCH_FIELDS],
    'HardwareTaxonomy' => %w[SEED_VERSION SEED_MANUFACTURERS SEED_SERIES AXILO_SERIES
                             AXILO_LEGACY_OWNER AXILO_OWNER]
  }.freeze

  # Materialy pre anotaciu hmotnosti (vzor `test_kove1b_pravidlo.rb`): celo
  # 18 mm / 750 kg/m3. §15 A1 — bez nich vyklop HK vyda len prislusenstvo.
  def self.mat(thickness, density)
    { 'thickness' => thickness, 'density' => density, 'uni' => false }
  end
  MATERIALS = { 'channels' => { 'body' => mat(18.0, 680.0), 'front' => mat(18.0, 750.0),
                                'back' => mat(3.0, 870.0), 'drawer' => mat(16.0, 680.0) },
                'parts' => {} }.freeze

  # Spodna skrinka s jednym cerstvym vyklopom (vzor `test_kove1b_pravidlo.rb`).
  def self.lift_case(system)
    { 'type' => 'lower', 'width' => 600.0, 'height' => 400.0, 'depth' => 500.0,
      'thickness' => 18.0, 'floor_height' => 0.0,
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'lift', 'mode' => 'auto',
                                  'lift' => { 'system' => system } }] } }
  end

  KOVA_CASES = %w[door_2wings drawer_fixed_locked upper_cabinet auto_w599 mix_fixed_auto].freeze

  # G7 konfiguracie navyse k KOVA pripadom. Zasuvka = vzor `cfg` v
  # `test_kovc2b_dielce.rb` (900 x 720 x 500, jedno zasuvkove celo 175, Atira).
  EXTRA_CASES = {
    'zasuvka_atira' => { 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                         'fronts' => { 'items' => [
                           { 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
                             'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }
                         ] } },
    'vyklop_hk' => lift_case('hk_top'),
    'vyklop_hl' => lift_case('hl_top')
  }.freeze

  # §15 A1: co MUSI byt v nakupe danej konfiguracie — { konfiguracia => [set
  # (regex), [povinne cleny podla stitku]] }. Stitky su NEZAVISLY zapis (nie
  # odvodene zo seedu): presne tieto cleny drzia zasuvku a vyklop.
  REQUIRED_MEMBERS = {
    'zasuvka_atira' => [/\Aatira-biela-h\d+-sisy\z/, ['K-sada']],
    'vyklop_hk' => [/\Avyklop-hk-klasik\z/, ['mechanizmus HK top']],
    'vyklop_hl' => [/\Avyklop-hl-klasik\z/, ['mechanizmus HL top', 'ramená HL top', 'stabilizačná tyč']]
  }.freeze

  # Minimalny model so slovnikom atributov (vzor `NxD118b::Model`).
  class Model
    def initialize
      @attrs = {}
    end

    def get_attribute(dict, key)
      (@attrs[dict] || {})[key]
    end

    def set_attribute(dict, key, val)
      (@attrs[dict] ||= {})[key] = val
    end
  end

  module_function

  def sha(str)
    Digest::SHA256.hexdigest(str)
  end

  def pretty(obj)
    "#{JSON.pretty_generate(obj)}\n"
  end

  def lf(text)
    text.to_s.gsub("\r\n", "\n")
  end

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end

  # --- sandbox ----------------------------------------------------------------

  def reset_modules!
    STORE.invalidate
    HS.reset_library_state!
    HC.reset_state!
    HT.reset_state!
  end

  def with_sandbox
    prev = MATS.test_dir_override
    dir = Dir.mktmpdir('nx-h15-')
    MATS.test_dir_override = dir
    reset_modules!
    yield dir
  ensure
    MATS.test_dir_override = prev
    reset_modules!
    begin
      FileUtils.remove_entry(dir) if dir
    rescue StandardError
      nil
    end
  end

  def write_json!(path, doc)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, JSON.pretty_generate(doc))
    FileUtils.rm_f("#{path}.bak")
    reset_modules!
  end

  def file_text(path)
    File.exist?(path) ? File.binread(path).force_encoding('UTF-8') : nil
  end

  # --- G1 konstanty -----------------------------------------------------------

  def unfrozen_strings(obj)
    case obj
    when Hash then obj.sum { |k, v| unfrozen_strings(k) + unfrozen_strings(v) }
    when Array then obj.sum { |x| unfrozen_strings(x) }
    when String then obj.frozen? ? 0 : 1
    else 0
    end
  end

  def identity_order(obj)
    case obj
    when Hash then obj.keys.map(&:to_s)
    when Array
      obj.map do |x|
        next x['set_id'] || x['item_code'] || x['name'] if x.is_a?(Hash)
        next x.first if x.is_a?(Array)

        x
      end
    end
  end

  def constant_report(obj)
    inner = case obj
            when Array then obj.first
            when Hash then obj.values.first
            end
    { 'class' => obj.class.name, 'size' => (obj.respond_to?(:size) && !obj.is_a?(String) ? obj.size : nil),
      'frozen' => obj.frozen?, 'inner_frozen' => (inner.nil? ? nil : inner.frozen?),
      'unfrozen_strings' => unfrozen_strings(obj), 'order' => identity_order(obj),
      'sha256_marshal' => sha(Marshal.dump(obj)), 'sha256_json' => sha(JSON.generate(obj)) }
  end

  def g1
    CONSTANTS.each_with_object({}) do |(mod, names), out|
      m = E.const_get(mod)
      names.each { |n| out["#{mod}::#{n}"] = constant_report(m.const_get(n)) }
    end
  end

  # --- G2 cerstva instalacia ----------------------------------------------------

  def fresh_install
    @fresh_install ||= with_sandbox do
      HS.load
      HC.items
      { 'files' => { sets: file_text(HS.path), catalog: file_text(HC.path), taxonomy: file_text(HT.path) },
        'doc' => { 'seed_library' => HS.seed_library, 'global_default_state' => HS.global_default_state } }
    end
  end

  def raw(kind)
    fresh_install['files'][kind]
  end

  def g2
    fresh_install['doc']
  end

  # Cerstvy seed (sety podla set_id, polozky katalogu podla kodu) — porovnavaci
  # zaklad G3/G4: fixtura nesie PLNE definicie len toho, co sa od neho lisi.
  def fresh_sets_by_id
    JSON.parse(raw(:sets))['sets'].to_h { |s| [s['set_id'], s] }
  end

  def fresh_items_by_code
    JSON.parse(raw(:catalog))['items'].to_h { |i| [i['item_code'], i] }
  end

  # --- G3 upgrade kniznice setov ------------------------------------------------

  def legacy(sid)
    deep_copy(HS::LEGACY_SEED_SHAPES.fetch(sid).first)
  end

  def seed_sets_without(*ids)
    deep_copy(HS::SEED_SETS.reject { |s| ids.include?(s['set_id']) })
  end

  def full_mapping
    HS::SEED_MAPPING.merge(HS::MAPPING_ADDITIONS)
  end

  def mapping_without(*keys)
    deep_copy(full_mapping.reject { |k, _| keys.include?(k) })
  end

  # Scenare: { meno => [seed_version, sety, mapovanie, taxonomia|nil] }.
  def set_upgrade_cases
    klzak = { 'hinge' => 'zaves-klasik', 'leg' => 'nohy-klzak-17', 'slide' => 'vysuv-atira-biela-h70' }
    nohy_premenovane = legacy('nohy-podla-sokla').merge('name' => 'Moje nohy')
    vlastny_prichyt = { 'set_id' => 'prichyt-sokla-axilo', 'name' => 'Môj záves',
                        'generic_type' => 'hinge',
                        'members' => [{ 'code' => '777001', 'per' => 'unit', 'qty' => 1 }] }
    {
      # v1: stare zavesy, klzak a legacy vysuv; mapovanie podla generickeho typu.
      'v1_stare_tvary' => [1, [legacy('zaves-klasik'), legacy('zaves-p2o'), legacy('nohy-klzak-17'),
                               legacy('vysuv-atira-biela-h70')], klzak, nil],
      # v4 (pred D-118b): antracit 348777, Tip-On bez PTOs, stary nazov vysuvu.
      'v4_pred_d118b' => [4, [legacy('atira-antracit-h70-sisy'), legacy('atira-biela-h70-p2o'),
                              legacy('vysuv-atira-biela-h70')], { 'slide' => 'vysuv-atira-biela-h70' }, nil],
      # v7: nedotknuty stary tvar noh -> nahradi sa; prichyt sokla chyba -> doplni sa.
      'v7_nohy_nedotknute' => [7, seed_sets_without('nohy-podla-sokla', 'prichyt-sokla-axilo') +
                                  [legacy('nohy-podla-sokla')], mapping_without('plinth_clip'), nil],
      # v7: pouzivatel nohy premenoval -> ruky prec.
      'v7_nohy_premenovane' => [7, seed_sets_without('nohy-podla-sokla', 'prichyt-sokla-axilo') +
                                   [nohy_premenovane], mapping_without('plinth_clip'), nil],
      # migracia predvolby `leg` nohy-klzak-17 -> nohy-podla-sokla (MAPPING_MIGRATIONS).
      'v7_migracia_leg' => [7, seed_sets_without, mapping_without.merge('leg' => 'nohy-klzak-17'), nil],
      # kolizia: vlastny set s id `prichyt-sokla-axilo` typu hinge ostava, plinth_clip sa nedoplni.
      'v7_kolizia_prichyt' => [7, seed_sets_without('prichyt-sokla-axilo') + [vlastny_prichyt],
                               mapping_without('plinth_clip'), nil],
      # vlastna hodnota triedneho kluca sa neprepise.
      'v7_vlastna_trieda' => [7, seed_sets_without,
                              mapping_without.merge('class:slide|classic|metal' => 'atira-antracit-h70-sisy'), nil],
      # konflikt taxonomie: AXILO patri vlastnemu vyrobcovi -> seed sety noh a prichytu nezaradene.
      'v7_konflikt_taxonomie' => [7, seed_sets_without('nohy-podla-sokla', 'prichyt-sokla-axilo'),
                                  mapping_without('plinth_clip', 'leg'), :axilo_foreign],
      # aktualna seed verzia 8: nic sa nezapise.
      'v8_aktualna' => [HS::SEED_VERSION, seed_sets_without, mapping_without, nil]
    }
  end

  # Taxonomia s AXILO pod VLASTNYM vyrobcom (aktualna seed verzia — bez migracie).
  def install_taxonomy_axilo_foreign!
    mans = HT::SEED_MANUFACTURERS.map { |n| { 'name' => n } } + [{ 'name' => 'Moja firma' }]
    sers = HT::SEED_SERIES.map do |(n, m)|
      { 'name' => n, 'manufacturer' => (n == HT::AXILO_SERIES ? 'Moja firma' : m) }
    end
    write_json!(HT.path, 'std' => HT::STD, 'schema' => HT::SCHEMA_CURRENT,
                         'seed_version' => HT::SEED_VERSION, 'manufacturers' => mans, 'series' => sers)
  end

  def library_doc(seed_version, sets, mapping)
    norm = HS.normalize_sets(sets)
    { 'std' => HS.snapshot_std(mapping, norm), 'seed_version' => seed_version,
      'sets' => norm, 'mapping' => mapping }
  end

  def g3
    fresh = fresh_sets_by_id
    set_upgrade_cases.each_with_object({}) do |(name, (ver, sets, mapping, tax)), out|
      out[name] = with_sandbox do
        install_taxonomy_axilo_foreign! if tax == :axilo_foreign
        write_json!(HS.path, library_doc(ver, sets, mapping))
        before = file_text(HS.path)
        lib = HS.load
        after = file_text(HS.path)
        doc = JSON.parse(after)
        { 'state' => HS.library_state.to_s, 'zapisane' => before != after,
          'seed_version' => doc['seed_version'], 'std' => doc['std'], 'file_sha256' => sha(after),
          'set_ids' => lib['sets'].map { |s| s['set_id'] }, 'mapping' => lib['mapping'],
          'odlisne_od_seedu' => lib['sets'].reject { |s| fresh[s['set_id']] == s }
                                           .to_h { |s| [s['set_id'], s] } }
      end
    end
  end

  # --- G4 upgrade katalogu a taxonomie ------------------------------------------

  def v2_items
    HC::SEED_ITEMS_V2.map { |i| HC.normalize_item(i)[0] }
  end

  def catalog_upgrade_cases
    v1 = v2_items.reject { |i| HC::SEED_PATCH_V2_ADD.include?(i['item_code']) }
                 .map { |i| i['item_code'] == '93240' ? HC.normalize_item(HC::LEGACY_SEED_93240)[0] : i }
    v2 = v2_items.reject { |i| i['item_code'] == '104802' }.map do |i|
      case i['item_code']
      when '104717' then i.merge('price_eur_vat' => 9.99)
      when '105408' then i.merge('demos_url' => 'https://www.demos.sk/vlastna-vazba')
      when '106412' then i.merge('active' => false)
      else i
      end
    end
    fresh = fresh_items_by_code.values
    v4 = fresh.reject { |i| HC::SEED_PATCH_V5_ADD.include?(i['item_code']) }.map do |i|
      next i unless i['item_code'] == HC::SEED_PATCH_V5_CLASSIFY

      i.reject { |k, _| %w[manufacturer series].include?(k) }
    end
    v5 = fresh.map do |i|
      next i unless i['item_code'] == HC::SEED_PATCH_V5_CLASSIFY

      i.reject { |k, _| %w[manufacturer series].include?(k) }
    end
    { 'katalog_v1' => [1, v1], 'katalog_v2_upravy' => [2, v2], 'katalog_v4_bez_noh' => [4, v4],
      'katalog_v5_bez_enrichmentu' => [5, v5] }
  end

  def taxonomy_upgrade_cases
    seed_mans = HT::SEED_MANUFACTURERS.map { |n| { 'name' => n } }
    v2_series = HT::SEED_SERIES.map do |(n, m)|
      { 'name' => n, 'manufacturer' => (n == HT::AXILO_SERIES ? HT::AXILO_LEGACY_OWNER : m) }
    end
    foreign = HT::SEED_SERIES.map do |(n, m)|
      { 'name' => n, 'manufacturer' => (n == HT::AXILO_SERIES ? 'Moja firma' : m) }
    end
    { 'taxonomia_v2_axilo_hettich' => [2, seed_mans, v2_series],
      'taxonomia_v2_axilo_cudzi' => [2, seed_mans + [{ 'name' => 'Moja firma' }], foreign] }
  end

  def g4
    fresh = fresh_items_by_code
    out = {}
    catalog_upgrade_cases.each do |name, (ver, items)|
      out[name] = with_sandbox do
        write_json!(HC.path, 'std' => HC::STD, 'schema' => HC::SCHEMA_CURRENT, 'seed_version' => ver,
                             'items' => items)
        cur = HC.items
        text = file_text(HC.path)
        doc = JSON.parse(text)
        { 'state' => HC.state.to_s, 'seed_version' => doc['seed_version'], 'schema' => doc['schema'],
          'file_sha256' => sha(text), 'codes' => cur.map { |i| i['item_code'] },
          'odlisne_od_seedu' => cur.reject { |i| fresh[i['item_code']] == i }
                                   .to_h { |i| [i['item_code'], i] } }
      end
    end
    taxonomy_upgrade_cases.each do |name, (ver, mans, sers)|
      out[name] = with_sandbox do
        write_json!(HT.path, 'std' => HT::STD, 'schema' => HT::SCHEMA_CURRENT, 'seed_version' => ver,
                             'manufacturers' => mans, 'series' => sers)
        HT.ensure_seeded
        text = file_text(HT.path)
        { 'state' => HT.state.to_s, 'file_sha256' => sha(text), 'doc' => JSON.parse(text),
          'axilo_owner' => HT.series_owner(HT::AXILO_SERIES) }
      end
    end
    out
  end

  # --- G5 projekt ---------------------------------------------------------------

  def g5
    with_sandbox do
      lib = HS.load
      stary = HS.normalize_sets([legacy('atira-biela-h70-p2o')]).first
      moj = legacy('atira-antracit-h70-sisy').merge('name' => 'Moja antracit')
      m = Model.new
      HS.write_project_state(m, 'mapping' => { 'class:slide|tipon|metal' => 'atira-biela-h70-p2o' },
                                'sets' => { 'atira-biela-h70-p2o' => stary,
                                            'atira-antracit-h70-sisy' => HS.normalize_sets([moj]).first })
      res = HS.merge_project_sets_seed!(m)
      status, state = HS.project_state_status(m)
      refs = HS.referenced_set_ids(lib['mapping'])
      options = HS::CLASS_MAPPING_KEYS.to_h do |key|
        [key, HS.class_set_options(key, lib['sets'], {}, refs)]
      end
      { 'merge_project_sets_seed' => { 'result' => res[0].to_s, 'added_sets' => res[1],
                                       'added_mapping' => res[2], 'refreshed' => res[3] },
        'project_status' => status.to_s, 'project_state' => state, 'class_set_options' => options }
    end
  end

  # --- G6 behove ----------------------------------------------------------------

  def g6
    { 'flap_set_codes_nil' => HS.flap_set_codes(nil) }
  end

  # --- G7 nakup a rozpocet --------------------------------------------------------

  def g7_cases
    KOVA_CASES.to_h { |n| [n, NxKovaGolden::CASES.fetch(n)] }.merge(EXTRA_CASES)
  end

  # -> { meno => { 'plan' => .., 'exp' => .., 'csv' => .., 'budget' => .., 'state' => .. } }
  def purchases
    @purchases ||= with_sandbox do
      lib = HS.load
      cat = HC.items
      state = { 'mapping' => lib['mapping'], 'sets' => lib['sets'].to_h { |s| [s['set_id'], s] } }
      rules = HR.normalize_rules(HR::SEED_RULES)
      g7_cases.to_h do |name, params|
        plan = E::Construction.build_plan(E::CabinetBuilder.normalize(params), 'CAB-1',
                                          hardware_rules: rules, materials: MATERIALS)
        exp = HS.expand(plan[:hardware], state, catalog: cat)
        csv = HS.purchase_csv(exp, project: 'H15', generated_at: '2026-10-01')
        bud = E::Budget.compute({ rows: [], edging: [] }, {}, E::SupplierSettings.seed_supplier,
                                hardware_expansion: exp, hardware_catalog: cat, now: Time.utc(2026, 10, 1))
        hw = Array(bud['sections']).find { |s| s['key'] == 'hardware' }
        [name, { 'plan' => plan, 'exp' => exp, 'csv' => csv, 'budget' => hw, 'state' => state, 'catalog' => cat }]
      end
    end
  end

  def g7
    purchases.transform_values do |p|
      { 'purchase_csv' => p['csv'], 'expand' => p['exp'], 'budget_hardware' => p['budget'] }
    end
  end

  # §15 A1: zoznam problemov nakupu (prazdny = golden sa smie zapisat).
  def purchase_problems
    purchases.flat_map do |name, p|
      probs = []
      plan = p['plan']
      exp = p['exp']
      bad = (Array(plan[:hardware_conflicts]) + Array(plan[:drawer_conflicts])).map { |c| c['code'].to_s }
      probs << "#{name}: blokujuci konflikt planu #{bad.inspect}" unless bad.empty?
      unless exp['unmapped'].empty?
        probs << "#{name}: nemapovane/neuplne #{exp['unmapped'].map { |u| u['reason'] }.inspect}"
      end
      missing = exp['rows'].select { |r| r['missing'] }.map { |r| r['code'] }
      probs << "#{name}: riadky mimo katalogu #{missing.inspect}" unless missing.empty?
      unknown = p['budget'] && p['budget']['unknown_count'].to_i
      probs << "#{name}: rozpocet ma #{unknown} poloziek bez ceny" if unknown.to_i.positive?
      probs.concat(required_member_problems(name, p))
      probs
    end
  end

  def required_member_problems(name, purchase)
    want = REQUIRED_MEMBERS[name]
    return [] unless want

    set_re, labels = want
    plan = purchase['plan']
    codes = purchase['exp']['rows'].to_h { |r| [r['code'], r['quantity']] }
    items = plan[:hardware].select { |h| %w[slide lift].include?(h['generic_type']) }
    return ["#{name}: plan nema polozku vysuvu/vyklopu"] if items.empty?

    items.flat_map do |item|
      ex = HS.explain(item, purchase['state'], catalog: purchase['catalog'])
      next ["#{name}: set #{ex['set_id'].inspect} nesedi s #{set_re.inspect}"] unless ex['set_id'].to_s.match?(set_re)
      next ["#{name}: supis hlasi #{ex['problems'].inspect}"] unless ex['problems'].empty?

      labels.filter_map do |label|
        mem = ex['members'].find { |x| x['label'] == label }
        next "#{name}: chyba clen „#{label}“" if mem.nil? || mem['code'].nil?
        next "#{name}: clen „#{label}“ (#{mem['code']}) nie je v nakupe" unless codes.key?(mem['code'])

        if label == 'stabilizačná tyč'
          rods = item['params']['rod_count'].to_i
          next "#{name}: tyce #{codes[mem['code']]} != rod_count #{rods}" unless rods >= 1 && codes[mem['code']] == rods
        end
        nil
      end
    end
  end

  # --- dokumenty a porovnanie -------------------------------------------------------

  def document(name)
    case name
    when 'g1_konstanty' then g1
    when 'g2_kniznica' then g2
    when 'g3_upgrade_sety' then g3
    when 'g4_upgrade_katalog' then g4
    when 'g5_projekt' then g5
    when 'g6_flap' then g6
    when 'g7_nakup' then g7
    else raise ArgumentError, "neznama fixtura #{name}"
    end
  end

  def fixture_path(file)
    File.join(DIR, file)
  end

  def golden_text(file)
    path = fixture_path(file)
    File.exist?(path) ? lf(File.binread(path).force_encoding('UTF-8')) : nil
  end

  # Prva odlisna cesta dvoch JSON hodnot („g3 › v1_stare_tvary › mapping › leg").
  def first_diff(want, have, path = [])
    if want.is_a?(Hash) && have.is_a?(Hash)
      return "#{(path + ['(poradie klucov)']).join(' › ')}: #{want.keys.inspect[0, 160]} vs #{have.keys.inspect[0, 160]}" if
        want.keys != have.keys && want.keys.sort == have.keys.sort

      (want.keys | have.keys).each do |k|
        d = first_diff(want[k], have[k], path + [k.to_s])
        return d if d
      end
      nil
    elsif want.is_a?(Array) && have.is_a?(Array)
      return "#{path.join(' › ')}: dlzka #{want.length} vs #{have.length}" if want.length != have.length

      want.each_index do |i|
        d = first_diff(want[i], have[i], path + ["[#{i}]"])
        return d if d
      end
      nil
    elsif want == have && want.class == have.class
      nil
    else
      "#{path.join(' › ')}: golden #{want.inspect[0, 160]} · teraz #{have.inspect[0, 160]}"
    end
  end

  def first_line_diff(want, have)
    w = want.to_s.lines
    h = have.to_s.lines
    idx = (0...[w.length, h.length].max).find { |i| w[i] != h[i] }
    return nil if idx.nil?

    "riadok #{idx + 1}: golden #{w[idx].to_s.strip[0, 160].inspect} · teraz #{h[idx].to_s.strip[0, 160].inspect}"
  end
end

# ============================================================================
# T0 — porovnanie s fixturami
# ============================================================================

NxH15Golden::JSON_FIXTURES.each do |name|
  NxTest.test("H15 T0 #{name}: cerstvy vypocet = golden z mainu pred presunom (bez regeneracie)") do
    NxTest.skip!('sandbox %APPDATA% len headless') unless NxTest.headless?
    g = NxH15Golden
    want = g.golden_text("#{name}.json")
    NxTest.assert(want, "chyba fixtura #{name}.json — generator sa spusta RUCNE len nad nezmenenym kodom")
    have = g.pretty(g.document(name))
    next if want == have

    diff = g.first_diff(JSON.parse(want), JSON.parse(have))
    NxTest.assert(false, "#{name}: #{diff || g.first_line_diff(want, have)}")
  end
end

NxH15Golden::RAW_FIXTURES.each do |file, kind|
  NxTest.test("H15 T0 #{file}: cerstva instalacia zapise bajtovo ten isty subor") do
    NxTest.skip!('sandbox %APPDATA% len headless') unless NxTest.headless?
    g = NxH15Golden
    want = g.golden_text(file)
    NxTest.assert(want, "chyba fixtura #{file}")
    have = g.lf(g.raw(kind))
    NxTest.assert(want == have, "#{file}: #{g.first_line_diff(want, have)}")
  end
end

NxTest.test('H15 T0 G7 (§15 A1): nakup je UPLNY — mechanizmus/kit, ramena, tyce; ziadny konflikt ani riadok mimo katalogu') do
  NxTest.skip!('sandbox %APPDATA% len headless') unless NxTest.headless?
  probs = NxH15Golden.purchase_problems
  NxTest.assert(probs.empty?, "golden nakupu by pripol neuplny nakup: #{probs.first(5).inspect}")
  NxTest.assert_equal(NxH15Golden.g7_cases.keys.sort, JSON.parse(NxH15Golden.golden_text('g7_nakup.json')).keys.sort,
                      'zoznam konfiguracii G7 = zoznam vo fixture')
end

NxTest.test('H15 T0: zoznam fixtur v priecinku = zoznam harnessu (ziadna navyse, ziadna chyba)') do
  files = Dir[File.join(NxH15Golden::DIR, '*.json')].map { |f| File.basename(f) }.sort
  want = (NxH15Golden::JSON_FIXTURES.map { |n| "#{n}.json" } + NxH15Golden::RAW_FIXTURES.keys).sort
  NxTest.assert_equal(want, files)
end
