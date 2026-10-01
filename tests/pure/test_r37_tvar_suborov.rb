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
