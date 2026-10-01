# frozen_string_literal: true
# H9 / R-37 — SUBOR NASTAVENI ZLEHO TVARU sa nesmie ticho nahradit seedom ani
# znicit poslednu dobru zalohu (nastavenia dodavatela, pravidla ABS hran,
# globalne pravidla kovania).
#
# T0 — CHARAKTERIZACIA (commit PRED zasahom, zelena na maine aj po nom):
#   T0a dodavatel: zdravy vlastny subor -> hodnoty, parametre planu, stav,
#       revizia; po nacitani bajty primaru aj `.bak` bez zmeny. Legacy format 1
#       (tvar E-a) sa doplni a zapise ako dnes.
#   T0b narezovy plan a ceny podla planu s parametrami ZO SUBORU (nie seed,
#       nie `params: {}`): zhoda so vstupom z tych istych hodnot v pamati
#       + pripnute cisla z mainu (`tests/fixtures/h9_golden/plan_budget.json`).
#   T0c ABS a kovanie — nacitanie zdravych vlastnych suborov (aj legitimne
#       prazdnych so `seed_version`), bajty bez zmeny.
#   T0d ABS a kovanie — vyrobne vystupy end-to-end nad VLASTNYMI zdravymi
#       subormi: nakupne CSV kovania a VEPO CSV s hranami. Odtlacok z mainu
#       (`tests/fixtures/h9_golden/<pripad>.json`, generator rucne). Predpoklad:
#       vystup s vlastnymi subormi sa LISI od seedu (inak by test nic nedokazoval).
#
# Generator fixtur:  C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h9_golden/generate.rb
# (test ho NEVOLA — charakterizacia by inak „dokazovala" samu seba).
#
# T1–T16 — OCHRANA (package H9 §7): dodavatel podla matice R7 (zly tvar +
# dobra zaloha = zaloha a zapisy vypnute; bez nej predvolene s priznanim,
# nacitanie nezapise, ulozenie opravi; novsi std; obnova zmazanim primaru),
# primitiva JsonFileStore (predikat, `read_valid`, `fallback: false`,
# pozicny tvar `write` — pasca Ruby 3, ochrana zalohy), fail-closed predikatu
# (`ShapeCheckError`), NP-4 brana na vsetky skalare (R6), strukturalne guardy,
# ABS a kovanie podla matice R14, log raz za zmenu stavu, „aj ako globálnu
# predvoľbu" nad degradovanym kovanim (projekt ulozeny, globalny subor nie)
# a parita zapisovej brany kovania `HardwareRules.write_gate` (R15).
# Mutacie M1–M21 (package §7) zabija tato sada spolu s test_r11_degradovana_zaloha.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'
require_relative 'test_np4_golden' unless defined?(NxNp4Golden)
require_relative 'test_kova_golden' unless defined?(NxKovaGolden)

module NxR37
  E     = Noxun::Engine
  STORE = E::JsonFileStore
  MAT   = E::Materials
  SS    = E::SupplierSettings
  ABS   = E::AbsRules
  HR    = E::HardwareRules
  HWS   = E::HardwareSets

  FIXTURES = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h9_golden')
  T0D_CASES = %w[door_2wings drawer_fixed_locked none_row_in_stack].freeze
  SHEET_ID = 'K009_PW_DTDL_18'
  DECOR = 'K009 PW'

  module_function

  # --- sandbox (vzor R-11: jeden override presmeruje data aj zamok) --------
  def with_sandbox
    prev = MAT.test_dir_override
    dir = Dir.mktmpdir('nx-r37-')
    MAT.test_dir_override = dir
    reset_states
    yield dir
  ensure
    MAT.test_dir_override = prev
    reset_states
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  # Modulove stavy katalogov (verdikt kniznice, katalog kovania) patria
  # k priecinku — medzi sandboxmi sa musia zhodit.
  def reset_states
    STORE.invalidate
    HWS.reset_library_state!
    E::HardwareCatalog.reset_state!
    MAT.reset_catalog_state!
  end

  def write_json(path, doc)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, doc.is_a?(String) ? doc : JSON.pretty_generate(doc))
    STORE.invalidate
  end

  def bytes(path)
    File.exist?(path) ? File.binread(path) : nil
  end

  def json(obj)
    JSON.parse(JSON.generate(obj))
  end

  # --- dodavatel -------------------------------------------------------------

  # Zdravy VLASTNY subor: vsetkych 5 sadzieb, 8 skalarov (prerez 4, orez 15,
  # pridavok 8), zmeneny riadok a rezim — nic z toho nie je seed.
  def own_supplier
    sup = SS.seed_supplier
    sup['rates'] = { 'olep' => 1.1, 'porez' => 21.0, 'duplaky' => 44.0, 'pd_opracovanie' => 120.0, 'montaz' => 18.0 }
    sup.merge!('stale_days' => 45, 'rounding_step' => 5.0, 'abs_reserve_pct' => 12.0,
               'montaz_m2_per_plate' => 6.2, 'cp_highlight_threshold' => 200.0,
               'kerf_mm' => 4.0, 'trim_mm' => 15.0, 'dup_allowance_mm' => 8.0)
    sup['standard_rows'][0]['rate'] = 75.0
    sup['mode_values']['doprava_zakaznik']['standard'] = 70.0
    sup
  end

  def own_supplier_doc
    { 'std' => SS::STD, 'seed_version' => SS::SEED_VERSION, 'active' => SS::DEFAULT_ID,
      'suppliers' => [own_supplier] }
  end

  # Zdravy primar + zdrava (starsia) zaloha s rozpoznatelnou sadzbou.
  def write_healthy_supplier
    write_json(SS.path, own_supplier_doc)
    old = own_supplier_doc
    old['suppliers'][0]['rates']['porez'] = 19.0
    write_json("#{SS.path}.bak", old)
  end

  # --- T0b: plan + rozpocet ---------------------------------------------------

  # Plan presne ako `ProductionCore.layout_for` (parametre, zdroj, verzia, opravy).
  def plan_from(lp, rows)
    plan = E::SheetLayout.compute(rows, sheets: NxNp4Golden::SHEETS, edge_thicknesses: {},
                                        params: lp[:params], blocked: nil)
    plan['params_source'] = lp[:source].to_s
    plan['params_version_ok'] = lp[:version_ok] == true
    plan['params_repaired'] = Array(lp[:repaired])
    plan['blocked_all'] = nil
    plan
  end

  def budget(supplier, plan, rows, plan_prices)
    E::Budget.compute({ rows: rows, edging: [] }, { 'plan_prices' => plan_prices }, supplier,
                      sheets: NxNp4Golden::SHEETS, edges: {}, sheet_estimate: NxNp4Golden.estimate(rows),
                      sheet_layout: plan, now: NxNp4Golden::NOW)
  end

  # Pripnute cisla: platne na material, porez, zdroj mnozstva Materialu, SPOLU.
  def pinned(plan, pay)
    mats = pay['sections'].find { |s| s['key'] == 'materials' }['rows']
    porez = pay['sections'].find { |s| s['key'] == 'services' }['rows'].find { |r| r['key'] == 'service:porez' }
    { 'plan_sheets' => plan['materials'].map { |m| [m['material_id'], Array(m['sheets']).length] },
      'materials' => mats.map { |r| [r['material_id'], r['mnozstvo'], r['qty_source'], r['spolu']] },
      'porez' => [porez['mnozstvo'], porez['spolu']], 'total' => pay['totals']['total'] }
  end

  # Cesta CEZ SUBOR: zdravy vlastny subor -> `layout_params` + `active`.
  def plan_budget_from_file
    write_healthy_supplier
    rows = NxNp4Golden.mixed_rows
    plan = plan_from(SS.layout_params, rows)
    [false, true].each_with_object({}) do |pp, out|
      out[pp.to_s] = json(pinned(plan, budget(SS.active, plan, rows, pp)))
    end
  end

  # --- T0c / T0d: vlastne pravidla ABS a kovania -----------------------------

  # Boky so vsetkymi hranami 2,0 (seed: bez ABS / 1,0) — v katalogu je ABS 2,0
  # pre dekor K009 PW, takze sa to v hranach naozaj prejavi.
  def own_abs_doc
    rules = json(ABS::SEED_RULES)
    rules['side_left'] = { 'L1' => 2.0, 'L2' => 2.0, 'W1' => 2.0, 'W2' => 2.0 }
    rules['side_right'] = { 'L1' => 2.0, 'L2' => 2.0, 'W1' => 2.0, 'W2' => 2.0 }
    { 'std' => ABS::STD, 'seed_version' => ABS::SEED_VERSION, 'rules' => rules }
  end

  # Vypnute zavesy a prichyt sokla (seed: zapnute) — meni nakup vo vsetkych
  # troch pripadoch T0d.
  OFF_RULES = %w[zavesy-podla-vysky prichyt-sokla].freeze

  def own_hw_doc
    rules = json(HR::SEED_RULES).map do |r|
      OFF_RULES.include?(r['rule_id']) ? r.merge('enabled' => false) : r
    end
    { 'std' => HR::STD, 'seed_version' => HR::SEED_VERSION, 'rules' => rules }
  end

  def write_own_rules
    write_json(ABS.path, own_abs_doc)
    write_json(HR.path, own_hw_doc)
  end

  # Nakupne CSV kovania + VEPO CSV jednej konfiguracie z pravidiel ZO SUBOROV.
  def outputs(name)
    cfg = E::CabinetBuilder.normalize(NxKovaGolden::CASES[name])
    plan = E::Construction.build_plan(cfg)
    lib = HWS.load
    by_id = lib['sets'].each_with_object({}) { |s, h| h[s['set_id']] = s }
    exp = HWS.expand(plan[:hardware], { 'mapping' => lib['mapping'], 'sets' => by_id },
                     catalog: E::HardwareCatalog.items)
    { 'purchase_csv' => HWS.purchase_csv(exp, project: 'H9', generated_at: '2026-10-01'),
      'vepo' => vepo(plan) }
  end

  def vepo(plan)
    cat = MAT.load
    sheet = cat['sheets'].find { |s| s['material_id'] == SHEET_ID }
    rows = plan[:parts].filter_map do |pd|
      prod = pd[:prod]
      next nil unless prod && prod[:thickness].to_f >= 10.0

      { 'names' => [pd[:name]], 'length' => prod[:length], 'width' => prod[:width],
        'thickness' => prod[:thickness], 'quantity' => 1, 'material_id' => SHEET_ID,
        'grain_direction' => 'length', 'role' => pd[:role],
        'edges' => ABS.resolve_edges(pd[:role], DECOR, prod[:thickness], sheet: sheet),
        'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 1 }] }
    end
    et = cat['edges'].each_with_object({}) { |e, h| h[e['abs_id']] = e['thickness'] }
    out = E::VepoExport.build(rows, project: 'H9', materials: { SHEET_ID => { 'label' => 'K009' } },
                                    edge_thicknesses: et, version: '9.9.9', generated_at: 'TEST',
                                    merge_18_36: true)
    { 'groups' => out['groups'].map { |g| [g['filename'], g['csv']] },
      'edges' => rows.map { |r| [r['role'], r['edges']] }, 'errors' => out['errors'] }
  end

  # Sandbox s legacy katalogom (ABS 1,0 aj 2,0 pre K009 PW); `own` = vlastne
  # zdrave subory pravidiel, inak seed.
  def t0d_snapshot(own)
    with_sandbox do
      NxTest.install_legacy_catalog!
      write_own_rules if own
      T0D_CASES.each_with_object({}) { |n, out| out[n] = outputs(n) }
    end
  end

  def golden(name)
    JSON.parse(File.read(File.join(FIXTURES, "#{name}.json"), encoding: 'UTF-8'))
  end
end

# ==========================================================================
# T0a — dodavatel: zdravy subor sa cita a NIKDY neprepise
# ==========================================================================

NxTest.test('R-37 T0a: zdravy vlastny subor dodavatela — hodnoty, plan, stav, revizia; bajty bez zmeny') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_healthy_supplier
    prim = r.bytes(r::SS.path)
    bak = r.bytes("#{r::SS.path}.bak")
    act = r::SS.active
    want = r::SS.normalize(r.own_supplier_doc)['suppliers'][0]
    NxTest.assert_equal(want, act, 'aktivny dodavatel = subor')
    NxTest.assert_equal(21.0, act['rates']['porez'], 'porez zo suboru (nie seed 17, nie zaloha 19)')
    lp = r::SS.layout_params
    NxTest.assert_equal({ params: { 'kerf' => 4.0, 'trim' => 15.0, 'dup_allowance' => 8.0 }, source: :file,
                          version_ok: true, repaired: [] }, lp)
    NxTest.assert_equal({ 'state' => 'ok', 'reason' => '' }, r::SS.settings_state(r::SS.active_with_source[1]))
    NxTest.assert_equal(r::SS.revision(want), r::SS.revision(act))
    NxTest.assert_equal(70.0, r::SS.mode_value(act, 'doprava_zakaznik', 'standard'))
    NxTest.assert_equal(prim, r.bytes(r::SS.path), 'primar bajtovo nedotknuty')
    NxTest.assert_equal(bak, r.bytes("#{r::SS.path}.bak"), 'zaloha bajtovo nedotknuta')
  end
end

NxTest.test('R-37 T0a: legacy format 1 (tvar E-a) sa doplni 5/10/10 a zapise ako dnes') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    sup = { 'id' => 'default', 'name' => 'Noxun', 'rates' => { 'olep' => 0.9, 'porez' => 23.0 },
            'stale_days' => 30, 'rounding_step' => 1.0, 'abs_reserve_pct' => 10.0,
            'montaz_m2_per_plate' => 5.8, 'cp_highlight_threshold' => 150.0 }
    r.write_json(r::SS.path, 'std' => 1, 'seed_version' => 1, 'active' => 'default', 'suppliers' => [sup])
    lp = r::SS.layout_params
    NxTest.assert_equal({ 'kerf' => 5.0, 'trim' => 10.0, 'dup_allowance' => 10.0 }, lp[:params])
    NxTest.assert_equal(:file, lp[:source])
    NxTest.assert_equal(23.0, r::SS.active['rates']['porez'])
    disk = JSON.parse(File.binread(r::SS.path))
    NxTest.assert_equal(r::SS::STD, disk['std'], 'seed-merge sa zapisal (peciatka std)')
    NxTest.assert_equal(10.0, disk['suppliers'][0]['trim_mm'], 'doplneny orez je na disku')
    NxTest.assert(File.exist?("#{r::SS.path}.bak"), 'povodny zdravy primar je v zalohe')
  end
end

# ==========================================================================
# T0b — narezovy plan a ceny podla planu s parametrami ZO SUBORU
# ==========================================================================

NxTest.test('R-37 T0b: plan + rozpocet zo suboru = vstup z tych istych hodnot v pamati') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_healthy_supplier
    rows = NxNp4Golden.mixed_rows
    file_plan = r.plan_from(r::SS.layout_params, rows)
    mem_lp = { params: { 'kerf' => 4.0, 'trim' => 15.0, 'dup_allowance' => 8.0 }, source: :file,
               version_ok: true, repaired: [] }
    mem_plan = r.plan_from(mem_lp, rows)
    NxTest.assert_equal(r.json(mem_plan), r.json(file_plan), 'plan zo suboru = plan z pamati')
    [false, true].each do |pp|
      a = r.json(r.budget(r::SS.active, file_plan, rows, pp))
      b = r.json(r.budget(r.own_supplier, mem_plan, rows, pp))
      NxTest.assert_equal(b, a, "rozpocet zo suboru = z pamati (plan_prices #{pp})")
    end
  end
end

NxTest.test('R-37 T0b: pripnute cisla planu a rozpoctu (odtlacok z mainu)') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  fresh = r.with_sandbox { r.plan_budget_from_file }
  NxTest.assert_equal(r.golden('plan_budget'), fresh)
end

# ==========================================================================
# T0c — ABS a kovanie: zdrave vlastne subory sa citaju a neprepisu
# ==========================================================================

NxTest.test('R-37 T0c: zdrave vlastne pravidla ABS a kovania — hodnoty zo suboru, bajty bez zmeny') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_own_rules
    abs_b = r.bytes(r::ABS.path)
    hr_b = r.bytes(r::HR.path)
    NxTest.assert_equal({ 'L1' => 2.0, 'L2' => 2.0, 'W1' => 2.0, 'W2' => 2.0 }, r::ABS.load['side_left'])
    rules, blocked = r::HR.load_state
    NxTest.assert_equal(false, blocked)
    off = rules.select { |x| r::OFF_RULES.include?(x['rule_id']) }.map { |x| x['enabled'] }
    NxTest.assert_equal([false, false], off, 'vypnute pravidla ostali vypnute')
    NxTest.assert_equal(r::HR.normalize_rules(r.own_hw_doc['rules']), rules)
    NxTest.assert_equal(abs_b, r.bytes(r::ABS.path), 'abs_rules.json bajtovo nedotknuty')
    NxTest.assert_equal(hr_b, r.bytes(r::HR.path), 'hardware_rules.json bajtovo nedotknuty')
  end
end

NxTest.test('R-37 T0c: legitimne prazdne pravidla so seed_version su zdrave (nic sa nedoplni)') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_json(r::ABS.path, 'std' => r::ABS::STD, 'seed_version' => r::ABS::SEED_VERSION, 'rules' => {})
    r.write_json(r::HR.path, 'std' => r::HR::STD, 'seed_version' => r::HR::SEED_VERSION, 'rules' => [])
    abs_b = r.bytes(r::ABS.path)
    hr_b = r.bytes(r::HR.path)
    NxTest.assert_equal({}, r::ABS.load, 'vedome prazdne ABS pravidla')
    NxTest.assert_equal([[], false], r::HR.load_state, 'vedome prazdne pravidla kovania')
    NxTest.assert_equal(abs_b, r.bytes(r::ABS.path))
    NxTest.assert_equal(hr_b, r.bytes(r::HR.path))
  end
end

# ==========================================================================
# T0d — vyrobne vystupy end-to-end nad vlastnymi zdravymi subormi
# ==========================================================================

NxTest.test('R-37 T0d: vlastne pravidla menia nakup aj hrany oproti seedu (predpoklad testu)') do
  NxTest.skip!('katalogove testy bezia headless') unless NxTest.headless?
  r = NxR37
  seed = r.t0d_snapshot(false)
  own = r.t0d_snapshot(true)
  r::T0D_CASES.each do |n|
    NxTest.refute(seed[n]['purchase_csv'] == own[n]['purchase_csv'], "#{n}: nakup kovania sa lisi od seedu")
    NxTest.refute(seed[n]['vepo'] == own[n]['vepo'], "#{n}: hrany vo VEPO sa lisia od seedu")
  end
end

NxR37::T0D_CASES.each do |name|
  NxTest.test("R-37 T0d: #{name} — nakup kovania a VEPO s hranami = odtlacok z mainu") do
    NxTest.skip!('katalogove testy bezia headless') unless NxTest.headless?
    r = NxR37
    @nx_r37_own ||= r.json(r.t0d_snapshot(true))
    have = @nx_r37_own[name]
    NxTest.assert_equal(r.golden(name), have)
  end
end

# ==========================================================================
# T1–T16 — ochrana po H9 (zly tvar = poskodeny subor)
# ==========================================================================

# Okno Pravidla je UI vrstva — headless sa nacita rucne (vzor test_st3b_rules).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxR37
  module_function

  # R2: parsovatelne dokumenty, ktore NEMAJU tvar nastaveni dodavatela.
  def bad_supplier_docs
    ok = { 'id' => 'default', 'rates' => { 'olep' => 1.0 } }
    [[], {}, nil, '"text"', 42, { 'foo' => 1 },
     { 'seed_version' => 1, 'suppliers' => [] }, { 'suppliers' => [] },
     { 'suppliers' => 'x' }, { 'suppliers' => [1, 2] }, { 'suppliers' => [{}] },
     { 'suppliers' => [{ 'rates' => 'x' }] }, { 'suppliers' => [{ 'rates' => {} }] },
     { 'suppliers' => [{ 'id' => 'default' }] },
     { 'suppliers' => [ok.merge('standard_rows' => {})] },
     { 'suppliers' => [ok.merge('mode_values' => [])] },
     { 'std' => 2, 'suppliers' => [ok, 'x'] }, { 'std' => 1, 'suppliers' => [{ 'rates' => [1] }] }]
  end

  # R12/R13: zle tvary suborov pravidiel (ABS aj kovanie).
  BAD_RULE_DOCS = ['{"rules":{}}', '{"rules":[]}', '[]', '{}', '{"std":1,"rules":"x"}'].freeze

  CORRUPT = "{ toto uz nie je JSON\n"

  def raw(doc)
    doc.is_a?(String) ? doc : JSON.generate(doc)
  end

  # Zly primar + dobra zaloha (own_supplier_doc, porez 21).
  def degraded_supplier(bad)
    write_json("#{SS.path}.bak", own_supplier_doc)
    write_json(SS.path, raw(bad))
  end

  # Docasna nahrada predikatu modulu (fail-closed testy, T9).
  def with_predicate(mod, impl)
    orig = mod.method(:doc_shape_ok?)
    mod.define_singleton_method(:doc_shape_ok?, &impl)
    yield
  ensure
    mod.define_singleton_method(:doc_shape_ok?, orig)
  end

  # Zachyt logu Engine (headless stub `log` je no-op).
  def capture_log
    logs = []
    orig = E.method(:log)
    orig_err = E.method(:log_error)
    E.define_singleton_method(:log) { |msg| logs << msg.to_s }
    E.define_singleton_method(:log_error) { |e, ctx = nil| logs << "#{ctx}: #{e.message}" }
    yield logs
  ensure
    E.define_singleton_method(:log, orig)
    E.define_singleton_method(:log_error, orig_err)
  end

  def files(path)
    [bytes(path), bytes("#{path}.bak")]
  end

  # Vlastne pravidla ako ZALOHA (rozpoznatelne od seedu).
  def abs_backup_doc
    { 'std' => ABS::STD, 'seed_version' => ABS::SEED_VERSION, 'rules' => { 'shelf' => { 'L1' => 2.0 } } }
  end

  def hr_backup_doc
    { 'std' => HR::STD, 'seed_version' => HR::SEED_VERSION, 'rules' => [json(HR::SEED_RULES.first)] }
  end

  def rule_specs
    [{ name: 'abs_rules', mod: ABS, backup: abs_backup_doc,
       read: -> { ABS.load }, from_backup: ->(v) { v == { 'shelf' => { 'L1' => 2.0 } } },
       seed: ->(v) { v == json(ABS::SEED_RULES) },
       write: -> { ABS.write('shelf' => { 'L1' => 1.0 }) } },
     { name: 'hardware_rules', mod: HR, backup: hr_backup_doc,
       read: -> { HR.load.map { |r| r['rule_id'] } },
       from_backup: ->(v) { v == [HR::SEED_RULES.first['rule_id']] },
       seed: ->(v) { v == HR::SEED_RULES.map { |r| r['rule_id'] } },
       write: -> { HR.write(HR::SEED_RULES.first(2)) } }]
  end

  def body(rel, name, indent = 6)
    src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', rel)).force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
    src[/^#{' ' * indent}def #{Regexp.escape(name)}(?![\w!?]).*?\n#{' ' * indent}end\n/m].to_s
  end
end

# --------------------------------------------------------------------------
# T1–T5 — dodavatel (matica R7)
# --------------------------------------------------------------------------

NxTest.test('R-37 T1: dodavatel — zly tvar + dobra zaloha = zaloha, degraded, subory nedotknute') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  NxTest.assert(r.bad_supplier_docs.length >= 16, 'aspon 16 vstupov z R2')
  r.bad_supplier_docs.each do |bad|
    r.with_sandbox do
      r.degraded_supplier(bad)
      before = r.files(r::SS.path)
      sup, src = r::SS.active_with_source
      NxTest.assert_equal(21.0, sup['rates']['porez'], "#{bad.inspect}: porez zo zalohy, nie seed 17")
      NxTest.assert_equal(:backup, src, "#{bad.inspect}: zdroj :backup")
      NxTest.assert_equal('degraded', r::SS.settings_state(src)['state'])
      lp = r::SS.layout_params
      NxTest.assert_equal([15.0, :backup], [lp[:params]['trim'], lp[:source]], "#{bad.inspect}: orez zo zalohy")
      res = r::SS.patch_active!('rates' => { 'porez' => 30.0 })
      NxTest.assert_equal([false, [r::SS.degraded_reason], :write_failed], res, "#{bad.inspect}: ulozenie vypnute")
      NxTest.assert_equal(before, r.files(r::SS.path), "#{bad.inspect}: primar aj .bak bajtovo nedotknute")
    end
  end
end

NxTest.test('R-37 T2: dodavatel — zly tvar bez dobrej zalohy = predvolene priznane, load nezapise, ulozenie opravi') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  [nil, [], r::CORRUPT].each do |bak|
    r.with_sandbox do
      r.write_json("#{r::SS.path}.bak", r.raw(bak)) unless bak.nil?
      r.write_json(r::SS.path, '[]')
      before = r.files(r::SS.path)
      sup, src = r::SS.active_with_source
      NxTest.assert_equal([:seed_fallback, 17.0], [src, sup['rates']['porez']], "bak #{bak.inspect}: predvolene")
      NxTest.assert_equal('fallback', r::SS.settings_state(src)['state'])
      NxTest.assert_equal(:seed_fallback, r::SS.layout_params[:source], 'Kontrola ORANGE + plan „orientačne"')
      NxTest.assert_equal(before, r.files(r::SS.path), "bak #{bak.inspect}: nacitanie nic nezapise")
      NxTest.assert_equal([true, [], :ok], r::SS.patch_active!('rates' => { 'porez' => 30.0 }), 'vedome ulozenie')
      sup, src = r::SS.active_with_source
      NxTest.assert_equal([:file, 30.0], [src, sup['rates']['porez']], 'subor je opraveny')
    end
  end
end

NxTest.test('R-37 T3: dodavatel — chybajuci primar + zaloha zleho tvaru = predvolene, ensure_seeded nezapise') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_json("#{r::SS.path}.bak", '{"suppliers":[]}')
    NxTest.assert_equal(:seed_fallback, r::SS.active_with_source[1])
    NxTest.assert_equal(false, File.exist?(r::SS.path), 'seed sa nezapisal')
    NxTest.assert_equal('{"suppliers":[]}', r.bytes("#{r::SS.path}.bak"))
  end
end

NxTest.test('R-37 T4: dodavatel — obnova zmazanim zleho primaru (cita sa zaloha, zapisy povolene)') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.degraded_supplier([])
    NxTest.assert_equal(:backup, r::SS.active_with_source[1])
    File.delete(r::SS.path)
    r::STORE.invalidate
    sup, src = r::SS.active_with_source
    NxTest.assert_equal([:file, 21.0], [src, sup['rates']['porez']])
    NxTest.assert_equal(true, r::SS.patch_active!('rates' => { 'porez' => 22.0 })[0], 'ulozenie po obnove')
  end
end

NxTest.test('R-37 T5: dodavatel — novsi std bez suppliers (aj s dobrou zalohou) = :newer_file') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  [false, true].each do |with_bak|
    r.with_sandbox do
      r.write_json("#{r::SS.path}.bak", r.own_supplier_doc) if with_bak
      r.write_json(r::SS.path, 'std' => r::SS::STD + 1, 'future' => true)
      before = r.files(r::SS.path)
      NxTest.assert_equal(:newer_file, r::SS.active_with_source[1], "bak #{with_bak}: novsi format posudzuje NP-2")
      NxTest.assert_equal(false, r::SS.patch_active!('rates' => { 'porez' => 30.0 })[0])
      NxTest.assert_equal(before, r.files(r::SS.path))
    end
  end
end

# --------------------------------------------------------------------------
# T7–T9 — JsonFileStore
# --------------------------------------------------------------------------

NxTest.test('R-37 T7: json_state/degraded? s tvarom aj bez neho') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  shape = ->(d) { d.is_a?(Hash) && d.key?('ok') }
  r.with_sandbox do |dir|
    p = File.join(dir, 'x.json')
    r.write_json(p, '[]')
    NxTest.assert_equal([:ok, :corrupt], [r::STORE.json_state(p), r::STORE.json_state(p, shape: shape)])
    NxTest.assert_equal(:missing, r::STORE.json_state("#{p}.bak", shape: shape))
    r.write_json("#{p}.bak", 'ok' => 1)
    NxTest.assert_equal([false, true], [r::STORE.degraded?(p), r::STORE.degraded?(p, shape: shape)])
    r.write_json("#{p}.bak", '[]')
    NxTest.assert_equal(false, r::STORE.degraded?(p, shape: shape), 'zaloha zleho tvaru = nie degraded')
    r.write_json(p, r::CORRUPT)
    r.write_json("#{p}.bak", 'ok' => 1)
    NxTest.assert_equal([true, true], [r::STORE.degraded?(p), r::STORE.degraded?(p, shape: shape)])
  end
end

NxTest.test('R-37 T7: read_valid — primar · zaloha · InvalidShape (je ParserError) · read bez fallbacku') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  shape = ->(d) { d.is_a?(Hash) && d.key?('ok') }
  r.with_sandbox do |dir|
    p = File.join(dir, 'x.json')
    r.write_json(p, 'ok' => 'primar')
    r.write_json("#{p}.bak", 'ok' => 'zaloha')
    NxTest.assert_equal({ 'ok' => 'primar' }, r::STORE.read_valid(p, shape: shape))
    r.write_json(p, '[]')
    NxTest.assert_equal({ 'ok' => 'zaloha' }, r::STORE.read_valid(p, shape: shape))
    r.write_json("#{p}.bak", '{}')
    e = NxTest.assert_raise('neocakavany tvar') { r::STORE.read_valid(p, shape: shape) }
    NxTest.assert(e.is_a?(r::STORE::InvalidShape) && e.is_a?(JSON::ParserError), 'InvalidShape < ParserError')
    NxTest.assert(!r::STORE::ShapeCheckError.ancestors.include?(JSON::ParserError), 'ShapeCheckError nie je ParserError')
    NxTest.assert(!r::STORE::ShapeCheckError.ancestors.include?(SystemCallError), 'ani SystemCallError')
    # `fallback: false` necita dalsiu zalohu
    r.write_json(p, r::CORRUPT)
    r.write_json("#{p}.bak", 'ok' => 'zaloha')
    NxTest.assert_equal({ 'ok' => 'zaloha' }, r::STORE.read(p))
    NxTest.assert_raise { r::STORE.read(p, fallback: false) }
  end
end

NxTest.test('R-37 T7 (FIX 1): primar [] + necitatelna .bak + zdrava .bak.bak -> .bak.bak sa NIKDY nepouzije') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_json(r::SS.path, '[]')
    r.write_json("#{r::SS.path}.bak", r::CORRUPT)
    old = r.own_supplier_doc
    old['suppliers'][0]['rates']['porez'] = 99.0
    r.write_json("#{r::SS.path}.bak.bak", old)
    NxTest.assert_raise('neocakavany tvar') { r::STORE.read_valid(r::SS.path, shape: r::SS.shape_check) }
    sup, src = r::SS.active_with_source
    NxTest.assert_equal([:seed_fallback, 17.0], [src, sup['rates']['porez']], 'nie porez 99 z .bak.bak')
  end
end

NxTest.test('R-37 T7: write s predikatom chrani dobru zalohu; bez nej zalohuje; bez predikatu ako dnes; cache .bak neplatna') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  shape = ->(d) { d.is_a?(Hash) && d.key?('ok') }
  r.with_sandbox do |dir|
    p = File.join(dir, 'x.json')
    r.write_json(p, '[]')
    r.write_json("#{p}.bak", 'ok' => 'dobra')
    r::STORE.write(p, { 'ok' => 'nove' }, shape)
    NxTest.assert_equal({ 'ok' => 'dobra' }, JSON.parse(r.bytes("#{p}.bak")), 'dobra zaloha ostala')
    r.write_json(p, '[]')
    r.write_json("#{p}.bak", '{}')
    r::STORE.write(p, { 'ok' => 'nove' }, shape)
    NxTest.assert_equal('[]', r.bytes("#{p}.bak"), 'bez dobrej zalohy sa primar zalohuje ako dnes')
    r.write_json(p, '[]')
    r.write_json("#{p}.bak", 'ok' => 'dobra')
    r::STORE.write(p, 'ok' => 'nove')
    NxTest.assert_equal('[]', r.bytes("#{p}.bak"), 'bez predikatu bajtovo ako dnes')
    # cache zalohy: precitana pred zapisom, po zapise cerstva
    r.write_json(p, 'ok' => 'a')
    r::STORE.read("#{p}.bak", fallback: false)
    r::STORE.write(p, { 'ok' => 'b' }, shape)
    NxTest.assert_equal({ 'ok' => 'a' }, r::STORE.read("#{p}.bak", fallback: false), 'cache .bak zhodena zapisom')
  end
end

NxTest.test('R-37 T8: pasca Ruby 3 — write ma POZICNY tvar, bezzatvorkovy hash ide do payloadu') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  sig = r::STORE.method(:write).parameters
  NxTest.assert_equal([[:req, :path], [:req, :payload], [:opt, :shape]], sig, 'ziadne klucove parametre')
  r.with_sandbox do |dir|
    p = File.join(dir, 'x.json')
    NxTest.assert_equal(true, r::STORE.write(p, 'std' => 1, 'series' => {}))
    NxTest.assert_equal({ 'std' => 1, 'series' => {} }, JSON.parse(r.bytes(p)))
    NxTest.assert(r::E::DimSeries.set('sirka' => [400]), 'DimSeries.set (bezzatvorkovy hash) zapise')
  end
end

[RuntimeError, JSON::ParserError, Errno::ENOENT, Errno::EACCES, NoMethodError].each do |exc|
  NxTest.test("R-37 T9 (FIX 2): predikat vyhodi #{exc} -> fail-closed, subory nedotknute") do
    NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
    r = NxR37
    boom = ->(_d) { raise exc, 'test' }
    r.with_sandbox do
      r.degraded_supplier([])
      before = r.files(r::SS.path)
      r.with_predicate(r::SS, boom) do
        NxTest.assert_equal(:unreadable, r::SS.active_with_source[1], 'dodavatel :unreadable (Ulozit vypnute)')
        NxTest.assert_equal(false, r::SS.patch_active!('rates' => { 'porez' => 30.0 })[0])
        NxTest.assert_raise('predikat tvaru zlyhal') { r::STORE.write(r::SS.path, { 'x' => 1 }, r::SS.shape_check) }
        e = NxTest.assert_raise { r::STORE.json_state(r::SS.path, shape: r::SS.shape_check) }
        NxTest.assert(e.is_a?(r::STORE::ShapeCheckError), "json_state -> ShapeCheckError (#{e.class})")
        e = NxTest.assert_raise { r::STORE.degraded?(r::SS.path, shape: r::SS.shape_check) }
        NxTest.assert(e.is_a?(r::STORE::ShapeCheckError), "degraded? -> ShapeCheckError (#{e.class})")
      end
      NxTest.assert_equal(before, r.files(r::SS.path), 'dodavatel: primar aj .bak nedotknute')
      [[r::ABS, -> { r::ABS.write('shelf' => {}) }], [r::HR, -> { r::HR.write(r::HR::SEED_RULES) }]].each do |mod, wr|
        r.write_json(mod.path, '[]')
        r.write_json("#{mod.path}.bak", mod == r::ABS ? r.abs_backup_doc : r.hr_backup_doc)
        b = r.files(mod.path)
        r.with_predicate(mod, boom) { NxTest.assert_equal(false, wr.call, "#{mod}: write false") }
        NxTest.assert_equal(b, r.files(mod.path), "#{mod}: subory nedotknute")
      end
    end
  end
end

# --------------------------------------------------------------------------
# T10 — R6: NP-4 brana auto-zapisu na vsetky opravene skalare
# --------------------------------------------------------------------------

NxTest.test('R-37 T10: rounding_step "abc" + chybajuci olep -> load nezapise, payload priznava, ulozenie opravi') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    doc = r.own_supplier_doc
    doc['suppliers'][0]['rounding_step'] = 'abc'
    doc['suppliers'][0]['rates'].delete('olep')
    r.write_json(r::SS.path, doc)
    before = r.files(r::SS.path)
    sup = r::SS.active
    NxTest.assert_equal(['rounding_step'], sup['repaired_scalars'])
    NxTest.assert_equal(before, r.files(r::SS.path), 'seed-merge sa nezapisal')
    NxTest.assert_equal(true, r::SS.patch_active!('rounding_step' => 2.0)[0])
    NxTest.assert_equal(nil, r::SS.active['repaired_scalars'], 'vedome ulozenie opravilo')
  end
end

# --------------------------------------------------------------------------
# T11 — strukturalne guardy
# --------------------------------------------------------------------------

NxTest.test('R-37 T11: citania idu cez read_valid, brany a zapisy nesu predikat, surove citania ostali') do
  r = NxR37
  NxTest.assert(r.body('core/supplier_settings.rb', 'read_doc').include?('JsonFileStore.read_valid(path, shape: shape_check'))
  NxTest.assert(r.body('core/abs_rules.rb', 'read_rules').include?('JsonFileStore.read_valid(path, shape: shape_check'))
  NxTest.assert(r.body('core/hardware_rules.rb', 'read_rules').include?('library_doc'))
  NxTest.assert(r.body('core/hardware_rules.rb', 'library_doc').include?('JsonFileStore.read_valid(path, shape: shape_check'))
  %w[library_std_unsupported? library_doc_std library_seed_version].each do |m|
    NxTest.assert(r.body('core/hardware_rules.rb', m).include?('library_doc'), "#{m} cita tym istym pomocnikom")
  end
  [['core/supplier_settings.rb', 'degraded_write_blocked?'], ['core/supplier_settings.rb', 'degraded_now?'],
   ['core/abs_rules.rb', 'degraded_write_blocked?'], ['core/hardware_rules.rb', 'write_gate']].each do |rel, m|
    NxTest.assert(r.body(rel, m).include?('degraded?(path, shape: shape_check)'), "#{rel} #{m}: brana s predikatom")
  end
  %w[core/supplier_settings.rb core/abs_rules.rb core/hardware_rules.rb].each do |rel|
    NxTest.assert(r.body(rel, 'write')[/JsonFileStore\.write\(.*shape_check\)/m], "#{rel}: write odovzda predikat")
  end
  NxTest.refute(r.body('core/supplier_settings.rb', 'disk_std').include?('read_valid'), 'disk_std cita surovy primar')
  NxTest.refute(r.body('core/supplier_settings.rb', 'newer_write_blocked?').include?('read_valid'))
  NxTest.refute(r.body('core/hardware_rules.rb', 'write_gate').include?('read_valid'), 'novsi std zo suroveho primaru')
  src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'json_file_store.rb'))
  NxTest.assert_equal(1, src.scan('.call(').length, 'predikat sa vola len cez shape_ok?')
  NxTest.assert(r.body('core/json_file_store.rb', 'shape_ok?').include?('.call('))
end

# --------------------------------------------------------------------------
# T13 — ABS a kovanie (matica R14)
# --------------------------------------------------------------------------

NxR37.rule_specs.each do |spec|
  NxTest.test("R-37 T13: #{spec[:name]} — zly tvar + dobra zaloha = zaloha, nic sa nezapise, zapis odmietnuty") do
    NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
    r = NxR37
    r::BAD_RULE_DOCS.each do |bad|
      r.with_sandbox do
        r.write_json("#{spec[:mod].path}.bak", spec[:backup])
        r.write_json(spec[:mod].path, bad)
        before = r.files(spec[:mod].path)
        NxTest.assert(spec[:from_backup].call(spec[:read].call), "#{bad}: hodnoty zo zalohy")
        NxTest.assert_equal(before, r.files(spec[:mod].path), "#{bad}: nacitanie nic nezapise")
        NxTest.assert_equal(false, spec[:write].call, "#{bad}: zapis odmietnuty")
        NxTest.assert(spec[:mod].write_block_reason.include?('poškoden'), "#{bad}: dovod odmietnutia")
        NxTest.assert_equal(before, r.files(spec[:mod].path), "#{bad}: primar aj .bak bajtovo nedotknute")
      end
    end
  end

  NxTest.test("R-37 T13: #{spec[:name]} — zly tvar bez zalohy = seed bez zapisu, vedome ulozenie opravi") do
    NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
    r = NxR37
    r::BAD_RULE_DOCS.each do |bad|
      r.with_sandbox do
        r.write_json(spec[:mod].path, bad)
        NxTest.assert(spec[:seed].call(spec[:read].call), "#{bad}: seed v pamati")
        NxTest.assert_equal([bad, nil], r.files(spec[:mod].path), "#{bad}: pri nacitani ziadny zapis")
        NxTest.assert_equal(true, spec[:write].call, "#{bad}: vedome ulozenie prejde")
        NxTest.assert_equal(bad, r.bytes("#{spec[:mod].path}.bak"), "#{bad}: zly primar ide do zalohy ako dnes")
        NxTest.refute(spec[:seed].call(spec[:read].call), "#{bad}: subor je opraveny")
      end
    end
  end
end

NxTest.test('R-37 T13: kovanie — library_std_unsupported? pri zlom primari + novsej zalohe = true (zhodne s load_state)') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_json("#{r::HR.path}.bak", 'std' => r::HR::STD + 1, 'seed_version' => 1, 'rules' => r.hr_backup_doc['rules'])
    r.write_json(r::HR.path, '{"rules":[]}')
    NxTest.assert_equal(true, r::HR.library_std_unsupported?)
    NxTest.assert_equal(true, r::HR.load_state[1], 'load_state hlasi blocked z tej istej zalohy')
    NxTest.assert_equal(r::HR::STD + 1, r::HR.library_doc_std)
  end
end

# --------------------------------------------------------------------------
# T14 — log raz za zmenu stavu
# --------------------------------------------------------------------------

NxTest.test('R-37 T14: 100x nacitanie nad zlym tvarom bez zalohy -> PRAVE jeden riadok logu za subor') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  r.with_sandbox do
    r.write_json(r::ABS.path, '[]')
    r.write_json(r::HR.path, '[]')
    r.write_json(r::SS.path, '[]')
    r.capture_log do |logs|
      100.times { r::ABS.rules }
      NxTest.assert_equal(1, logs.length, "ABS loguje prave raz (#{logs.inspect})")
      100.times { r::HR.load }
      NxTest.assert_equal(2, logs.length, "aj kovanie prave raz (#{logs.inspect})")
      100.times { r::SS.active }
      NxTest.assert_equal(3, logs.length, "aj dodavatel prave raz (#{logs.inspect})")
      NxTest.assert(logs.all? { |l| l.include?('neocakavany tvar') }, logs.inspect)
      # zdravy subor stav zhodi — nove poskodenie sa zaloguje znova
      r.write_json(r::SS.path, r.own_supplier_doc)
      r::SS.active
      r.write_json(r::SS.path, '[]')
      r::SS.active
      NxTest.assert_equal(4, logs.length, "po oprave a novom poskodeni znova (#{logs.inspect})")
    end
  end
end

# --------------------------------------------------------------------------
# T15 — „aj ako globálnu predvoľbu" nad degradovanym kovanim (S24, R14)
# --------------------------------------------------------------------------

module NxR37Save
  module_function

  def model(ops)
    m = NxTest::FakeEntity.new
    m.define_singleton_method(:active_path) { nil }
    m.define_singleton_method(:start_operation) { |name, *_r| ops << [:start, name] }
    m.define_singleton_method(:commit_operation) { ops << [:commit] }
    m.define_singleton_method(:abort_operation) { ops << [:abort] }
    m
  end

  # Docasne stuby: Sketchup.active_model, okenne guardy, zakazka bez skriniek.
  def with_dialog(model)
    rd = Noxun::Engine::RulesDialog
    panel = Noxun::Engine::Panel
    dk = Noxun::Engine::DocKey
    status = []
    stubs = [[rd, :baseline_state, ->(_m) { :ok }], [rd, :set_status, ->(msg, _e = false) { status << msg }],
             [rd, :after_model_write, ->(_m) {}], [dk, :foreign?, ->(*_a, **_k) { false }],
             [panel, :job_cabinets_split, ->(_m) { [[], []] }], [panel, :detached_skipped_tail, ->(_s) { '' }]]
    orig = stubs.map do |obj, name, _|
      [obj, name, begin
        obj.method(name)
      rescue NameError
        nil
      end]
    end
    stubs.each { |obj, name, impl| obj.define_singleton_method(name, &impl) }
    rev = rd.instance_variable_get(:@baseline_rev)
    rd.instance_variable_set(:@baseline_rev, nil)
    su = Module.new
    su.define_singleton_method(:active_model) { model }
    had = Object.const_defined?(:Sketchup)
    Object.const_set(:Sketchup, su) unless had
    yield rd, status
  ensure
    Object.send(:remove_const, :Sketchup) if !had && Object.const_defined?(:Sketchup)
    rd.instance_variable_set(:@baseline_rev, rev)
    Array(orig).each do |obj, name, m|
      m ? obj.define_singleton_method(name, m) : obj.singleton_class.send(:remove_method, name)
    end
  end
end

NxTest.test('R-37 T15: „aj ako globálnu" nad degradovanym kovanim — projekt ulozeny, globalny subor odmietnuty a nedotknuty') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxR37
  rules = r::HR.normalize_rules(r::HR::SEED_RULES).map { |x| x['rule_id'] == 'prichyt-sokla' ? x.merge('enabled' => false) : x }
  ['[]', '{"rules":[]}', nil].each do |bad|
    r.with_sandbox do
      if bad
        r.write_json("#{r::HR.path}.bak", r.hr_backup_doc)
        r.write_json(r::HR.path, bad)
      else
        r.write_json(r::HR.path, r.own_hw_doc)
      end
      before = r.files(r::HR.path)
      ops = []
      model = NxR37Save.model(ops)
      NxR37Save.with_dialog(model) do |rd, status|
        # H10a/R-35: novy DOM posiela VZDY reviziu globalu, ktory videl.
        rd.handle_save('rules' => rules, 'also_global' => true, 'global_rev' => r::HR.library_revision)
        snap = JSON.parse(model.get_attribute(r::E::Store::DICT, r::HR::MODEL_KEY).to_s)
        NxTest.assert_equal(rules, snap['rules'], "#{bad.inspect}: snapshot projektu = nove pravidla")
        NxTest.assert_equal([[:start, 'NOXUN: pravidla kovania'], [:commit]], ops, 'jedna operacia')
        msg = status.last.to_s
        NxTest.assert(msg.include?('Pravidlá uložené do projektu'), msg)
        if bad
          NxTest.assert(msg.include?('Globálne pravidlá kovania sú poškodené'), "#{bad}: veta degradacie (#{msg})")
          NxTest.refute(msg.include?('+ globálna predvoľba'), msg)
          NxTest.assert_equal(before, r.files(r::HR.path), "#{bad}: globalny primar aj .bak nedotknute")
        else
          NxTest.assert(msg.include?('+ globálna predvoľba'), "zdravy subor: globalny zapis (#{msg})")
          NxTest.assert_equal(rules, JSON.parse(r.bytes(r::HR.path))['rules'], 'globalna kniznica zapisana')
        end
      end
    end
  end
end

# --------------------------------------------------------------------------
# T16 — parita brany kovania (R15)
# --------------------------------------------------------------------------

NxTest.test('R-37 T16: write_gate <-> HardwareRules.write a write_block_reason v 6 stavoch suboru') do
  NxTest.skip!('sandbox testy bezia headless') unless NxTest.headless?
  r = NxR37
  cases = {
    'zdravy' => [r.own_hw_doc, nil, :ok],
    'zly tvar + .bak' => ['{"rules":[]}', r.hr_backup_doc, :degraded],
    'necitatelny + .bak' => [r::CORRUPT, r.hr_backup_doc, :degraded],
    'novsi std' => [{ 'std' => r::HR::STD + 1, 'rules' => [] }, nil, :newer],
    'zly tvar bez .bak' => ['[]', nil, :ok],
    'chybajuci' => [nil, nil, :ok]
  }
  cases.each do |name, (prim, bak, want)|
    r.with_sandbox do
      r.write_json(r::HR.path, r.raw(prim)) unless prim.nil?
      r.write_json("#{r::HR.path}.bak", bak) if bak
      state, reason = r::HR.write_gate
      NxTest.assert_equal(want, state, name)
      NxTest.assert_equal(want == :ok, reason.empty?, "#{name}: veta")
      ok = r::HR.write(r::HR::SEED_RULES.first(1))
      NxTest.assert_equal(want == :ok, ok, "#{name}: zapis prejde PRAVE pri :ok")
      NxTest.assert_equal(want == :ok ? '' : reason, r::HR.write_block_reason, "#{name}: dovod = veta brany")
    end
  end
  r.with_sandbox do
    r.write_json(r::HR.path, '[]')
    r.with_predicate(r::HR, ->(_d) { raise 'boom' }) do
      NxTest.assert_raise('predikat tvaru zlyhal') { r::HR.write_gate }
      NxTest.assert_equal(false, r::HR.write(r::HR::SEED_RULES), 'write fail-closed')
    end
  end
end

NxTest.test('R-37 T16: guard — v write rozhoduje len write_gate (cez dve pomenovane brany), reload! pred degraded?') do
  r = NxR37
  w = r.body('core/hardware_rules.rb', 'write')
  lock = w.index('with_catalog_lock')
  deg = w.index('degraded_write_blocked?')
  newer = w.index('newer_write_blocked?')
  wr = w.index('JsonFileStore.write')
  NxTest.assert(lock && deg && newer && wr && lock < deg && deg < newer && newer < wr, 'zamok -> brany -> zapis')
  NxTest.refute(w.include?('degraded?(') || w.include?('JsonFileStore.read'), 'write nema vlastne citanie')
  %w[degraded_write_blocked? newer_write_blocked?].each do |m|
    b = r.body('core/hardware_rules.rb', m)
    NxTest.assert(b.include?('gate_blocked?('), "#{m} sa pyta brany")
    NxTest.refute(b.include?('JsonFileStore'), "#{m} necita subor sama")
  end
  NxTest.assert(r.body('core/hardware_rules.rb', 'gate_blocked?').include?('write_gate'))
  g = r.body('core/hardware_rules.rb', 'write_gate')
  NxTest.assert(g.index('JsonFileStore.reload!(path)') < g.index('degraded?('), 'reload! pred degraded?')
end
