# frozen_string_literal: true
# NP-4 (blok 2 · Narezovy plan): CENY PODLA PLANU.
# Package: SYSTEM/archiv/bloky/NAREZ/PACKAGE_NP4_CENY.md (+ nalezy auditu
# B1–B3, F4, F5, N6 — maju prednost).
#
# Co sa tu dokazuje:
#   1. BudgetStore: prepinac `budget_plan_prices` (default vypnuty), jedna
#      mutacia = jeden krok Spat, marker `BUDGET_STD` 3 v tej istej operacii,
#      novsi marker odmietne zapis PRED operaciou.
#   2. `SheetLayout.price_basis` — JEDINA autorita cenovej sposobilosti:
#      kazdy dovod zvlast, poradie vo vete, fail-closed pri neznamom zdroji.
#   3. Budget: zapnuty prepinac = mnozstvo z planu len pri sposobilom
#      materiali; porez = suma Materiálu, montaz = suma ODHADU (dva sucty);
#      XLSX nesie pocet aj vetu; ponuka meni len sumy (prah 150 €).
#   4. Nastavenia (audit B2, B3): novsia zaloha a opraveny skalar su
#      nesposobile nezavisle od zdroja; Kontrola ORANGE; seed-merge nezmaze dokaz.
#   5. Export (audit F4): status vymenuje materialy na odhade, okno sa obnovi.
# Zlaty test „vypnuty = dnesne cisla" je v test_np4_golden.rb.
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'fileutils'
require 'tmpdir'
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless? && !defined?(Noxun::Engine::ProductionCore)
if NxTest.headless? && !defined?(Noxun::Engine::SupplierSettingsDialog)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog')
end
require_relative 'test_np4_golden' unless defined?(NxNp4Golden)

module NxNp4
  E  = Noxun::Engine
  BS = E::BudgetStore
  BD = E::Budget
  SL = E::SheetLayout
  SS = E::SupplierSettings
  PC = E::ProductionCore
  SC = PC.singleton_class
  G  = NxNp4Golden
  DICT = E::Store::DICT

  class FakeModel < NxTest::FakeEntity
    attr_reader :ops, :committed, :aborted

    def initialize
      super
      @ops = []
      @committed = 0
      @aborted = 0
    end

    def path
      ''
    end

    def start_operation(name, _disable_ui = false)
      @ops << name
      true
    end

    def commit_operation
      @committed += 1
      true
    end

    def abort_operation
      @aborted += 1
      true
    end
  end

  module_function

  def model(marker = :none)
    m = FakeModel.new
    m.set_attribute(DICT, BS::KEY_STD, marker) unless marker == :none
    m
  end

  # Plan v tvare `ProductionCore.layout_for` (zdroj, verzia, opravene skalare).
  def plan(rows, source: 'file', version_ok: true, repaired: [], blocked: nil)
    res = G.plan(rows, blocked: blocked, source: source)
    res['params_version_ok'] = version_ok
    res['params_repaired'] = repaired
    res
  end

  def compute(rows, layout, on: true, sheets: G::SHEETS)
    BD.compute({ rows: rows, edging: [] }, { 'plan_prices' => on }, SS.seed_supplier,
               sheets: sheets, edges: {}, sheet_estimate: estimate(rows, sheets), sheet_layout: layout,
               now: G::NOW)
  end

  def estimate(rows, sheets)
    E::SheetEstimate.estimate(rows, sheet_sizes: sheets.transform_values { |s| s['sheet_size'] },
                                    uni_ids: sheets.select { |_k, s| s['uni'] == true }.transform_values { true })
  end

  def row_of(payload, section, key)
    sec = payload['sections'].find { |s| s['key'] == section }
    sec['rows'].find { |r| r['key'] == key }
  end

  def mat_row(payload, mid)
    row_of(payload, 'materials', "material:#{mid}")
  end

  def basis(rows, mid, **kw)
    SL.price_basis(plan(rows, **kw), mid, G::SHEETS)
  end

  # --- sandbox nastaveni (vzor NP-2/NP-3) ---------------------------------
  def with_sandbox
    prev = E::Materials.test_dir_override
    dir = Dir.mktmpdir('nx-np4-')
    E::Materials.test_dir_override = dir
    E::JsonFileStore.invalidate
    yield dir
  ensure
    E::Materials.test_dir_override = prev
    E::JsonFileStore.invalidate
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  def write_json(path, doc)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, JSON.pretty_generate(doc))
  end

  def v2_doc(extra_sup = {}, std: 2)
    sup = { 'id' => 'default', 'name' => 'Noxun', 'rates' => { 'olep' => 0.9 },
            'stale_days' => 30, 'rounding_step' => 1.0, 'abs_reserve_pct' => 10.0,
            'montaz_m2_per_plate' => 5.8, 'cp_highlight_threshold' => 150.0,
            'kerf_mm' => 5.0, 'trim_mm' => 10.0, 'dup_allowance_mm' => 10.0 }.merge(extra_sup)
    { 'std' => std, 'seed_version' => 1, 'active' => 'default', 'suppliers' => [sup] }
  end

  # --- stubbing exportov (vzor test_r14_budget_std.rb) ---------------------
  # H7a: nastavenia exportu (refresh, last_dir, save_last_dir, project_name,
  # merge_18_36) ziju v `ExportSettings` — stub ide na modul, ktory metodu ma.
  def stub_sc(name)
    (PC.respond_to?(name) ? PC : Noxun::Engine::ExportSettings).singleton_class
  end

  def with_stubs(overrides)
    names = overrides.keys
    # cielovy modul sa urci RAZ (po `remove_method` by ho `respond_to?` nenasiel)
    scs = names.to_h { |name| [name, stub_sc(name)] }
    names.each do |name|
      scs[name].send(:alias_method, :"np4_orig_#{name}", name)
      scs[name].send(:define_method, name, &overrides[name])
    end
    yield
  ensure
    names.each do |name|
      scs[name].send(:remove_method, name)
      scs[name].send(:alias_method, name, :"np4_orig_#{name}")
      scs[name].send(:remove_method, :"np4_orig_#{name}")
    end
  end

  def with_ui(target)
    ui = Module.new
    ui.define_singleton_method(:savepanel) { |_t, _d, _n| target }
    Object.const_set(:UI, ui)
    yield
  ensure
    Object.send(:remove_const, :UI) if Object.const_defined?(:UI, false)
  end

  def export_stubs(bud)
    col = { records: [], hardware: [], hardware_overrides: [], cabinet_sets: {},
            cabinet_set_conflicts: {}, placements: [], warnings: [], identities: [] }
    { refresh: ->(*_a) {}, last_dir: ->(*_a) { nil },
      save_last_dir: ->(*_a) { [:ok, ''] }, project_name: ->(*_a) { 'NP4' },
      fresh_collect: ->(*_a) { col }, sheets_map: ->(*_a) { G::SHEETS },
      hardware_expansion: ->(*_a) { { 'rows' => [], 'unmapped' => [] } },
      budget_payload: ->(*_a) { bud } }
  end

  def run_export(method, bud, dir)
    msg = nil
    pushes = 0
    events = []
    with_stubs(export_stubs(bud)) do
      with_ui(File.join(dir, 'np4.xlsx')) do
        PC.send(method, :model, { 'gen' => 1, 'confirm_unpriced' => PC.unpriced_count(bud),
                                  'expect' => NxTest.export_expect(:model) }, generation: 1,
                                                status: lambda { |m, _e = false|
                                                  msg = m
                                                  events << :status
                                                },
                                                repush: lambda {
                                                  pushes += 1
                                                  events << :repush
                                                })
      end
    end
    [msg, pushes, events]
  end
end

# ============================================================================
# 1. BUDGET STORE — prepinac, jeden krok Spat, BUDGET_STD 3
# ============================================================================

NxTest.test('NP-4 store: BUDGET_STD je 3 a kluc prepinaca je `budget_plan_prices`') do
  NxTest.assert_equal(3, NxNp4::BS::BUDGET_STD)
  NxTest.assert_equal('budget_plan_prices', NxNp4::BS::KEY_PLAN_PRICES)
end

NxTest.test('NP-4 store: default VYPNUTY — chybajuci kluc aj cokolvek ine nez natívne true') do
  m = NxNp4.model
  NxTest.assert_equal(false, NxNp4::BS.plan_prices?(m))
  NxTest.assert_equal(false, NxNp4::BS.state(m)['plan_prices'])
  ['true', 1, 'ano', nil, {}].each do |v|
    m.set_attribute(NxNp4::DICT, NxNp4::BS::KEY_PLAN_PRICES, v)
    NxTest.assert_equal(false, NxNp4::BS.plan_prices?(m), "#{v.inspect} nie je zapnute")
  end
  m.set_attribute(NxNp4::DICT, NxNp4::BS::KEY_PLAN_PRICES, true)
  NxTest.assert_equal(true, NxNp4::BS.state(m)['plan_prices'])
  NxTest.assert_equal(0, m.ops.length, 'citanie neotvara operaciu')
end

NxTest.test('NP-4 store: set_plan_prices! = JEDNA operacia (udaj + marker 3), zap/vyp') do
  m = NxNp4.model
  ok, errs = NxNp4::BS.set_plan_prices!(m, true)
  NxTest.assert(ok, errs.inspect)
  NxTest.assert_equal(true, m.get_attribute(NxNp4::DICT, NxNp4::BS::KEY_PLAN_PRICES), 'natívny bool')
  NxTest.assert_equal(3, m.get_attribute(NxNp4::DICT, NxNp4::BS::KEY_STD), 'legacy -> marker 3')
  NxTest.assert_equal(['Rozpočet — ceny podľa plánu'], m.ops, 'jeden krok Spat s citatelnym menom')
  NxTest.assert_equal([1, 0], [m.committed, m.aborted])
  NxNp4::BS.set_plan_prices!(m, false)
  NxTest.assert_equal(false, m.get_attribute(NxNp4::DICT, NxNp4::BS::KEY_PLAN_PRICES))
  NxTest.assert_equal(2, m.ops.length, 'druha zmena = druhy krok Spat')
  NxNp4::BS.set_plan_prices!(m, 'true')
  NxTest.assert_equal(true, NxNp4::BS.plan_prices?(m), 'retazec z JSON sa prijme ako zapnutie')
end

NxTest.test('NP-4 store: marker 2 (zakazka z v0.15.3) -> prva mutacia AKEHOKOLVEK druhu zapise 3') do
  [->(m) { NxNp4::BS.set_mode!(m, 'vysoky') }, ->(m) { NxNp4::BS.set_plan_prices!(m, true) },
   ->(m) { NxNp4::BS.set_viz_m2!(m, 5.0) }].each do |mut|
    m = NxNp4.model(2)
    ok, = mut.call(m)
    NxTest.assert(ok)
    NxTest.assert_equal(3, m.get_attribute(NxNp4::DICT, NxNp4::BS::KEY_STD))
    NxTest.assert_equal(1, m.ops.length)
  end
end

NxTest.test('NP-4 store: novsi marker (4) odmietne prepinac PRED operaciou a nic nezapise') do
  m = NxNp4.model(4)
  ok, errs = NxNp4::BS.set_plan_prices!(m, true)
  NxTest.refute(ok)
  NxTest.assert_equal([NxNp4::BS.std_block_reason(:newer)], errs)
  NxTest.assert_equal([], m.ops, 'ziadna operacia')
  NxTest.assert_equal(:none, m.get_attribute(NxNp4::DICT, NxNp4::BS::KEY_PLAN_PRICES, :none))
  NxTest.assert_equal(4, m.get_attribute(NxNp4::DICT, NxNp4::BS::KEY_STD), 'marker nezmeneny')
end

NxTest.test('NP-4 jadro: op `plan_prices` ide do set_plan_prices!, status podla smeru') do
  m = NxNp4.model
  ok, = NxNp4::PC.apply_budget_op(m, 'op' => 'plan_prices', 'enabled' => true)
  NxTest.assert(ok)
  NxTest.assert_equal(true, NxNp4::BS.plan_prices?(m))
  NxTest.assert_equal('Ceny podľa plánu zapnuté.', NxNp4::PC.budget_op_status('op' => 'plan_prices', 'enabled' => true))
  NxTest.assert_equal('Ceny podľa plánu vypnuté.', NxNp4::PC.budget_op_status('op' => 'plan_prices', 'enabled' => false))
  NxNp4::PC.apply_budget_op(m, 'op' => 'plan_prices', 'enabled' => false)
  NxTest.assert_equal(false, NxNp4::BS.plan_prices?(m))
end

# ============================================================================
# 2. CENOVA SPOSOBILOST — SheetLayout.price_basis
# ============================================================================

NxTest.test('NP-4 sposobilost: uplny plan + zdroj file/backup + verzia ok = pocet z planu') do
  rows = NxNp4::G.mixed_rows
  b = NxNp4.basis(rows, 'H18')
  NxTest.assert_equal([true, 5, []], b.values_at('eligible', 'sheets', 'reasons'))
  NxTest.assert_equal('cena podľa plánu', b['note'])
  NxTest.assert_equal(true, NxNp4.basis(rows, 'PD')['eligible'], 'pracovna doska (bez orezu) tiez')
  NxTest.assert_equal(true, NxNp4.basis(rows, 'H18', source: 'backup')['eligible'], 'zaloha s platnou verziou = spolahliva')
end

NxTest.test('NP-4 sposobilost: kazdy dovod zvlast a jeho veta') do
  f = NxNp4
  rows = f::G.mixed_rows
  cases = {
    ['W18', {}] => [%w[incomplete], 'plán neúplný — cena z odhadu'],
    ['NOF', {}] => [%w[no_format], 'formát chýba — cena z odhadu'],
    ['UNI', {}] => [%w[uni], 'materiál neurčený — cena z odhadu'],
    ['W36', {}] => [%w[duplak_unlinked], 'duplák bez väzby — cena z odhadu'],
    ['H18', { source: 'seed_fallback' }] => [%w[settings_unreadable], 'nastavenia sa nepodarilo načítať — cena z odhadu'],
    ['H18', { source: 'unreadable' }] => [%w[settings_unreadable], nil],
    ['H18', { source: 'newer_file' }] => [%w[settings_newer], 'nastavenia uložil novší plugin — cena z odhadu'],
    ['H18', { source: 'backup', version_ok: false }] => [%w[settings_newer], nil],
    ['H18', { source: 'file', version_ok: nil }] => [%w[settings_unreadable], nil],
    ['H18', { source: '' }] => [%w[settings_unreadable], nil],
    ['H18', { repaired: ['trim_mm'] }] => [%w[settings_repaired], 'nastavenia prerezu a orezu sú poškodené — cena z odhadu'],
    ['H18', { blocked: { 'all' => 'VEPO export by sa zastavil: x' } }] => [%w[incomplete], nil]
  }
  cases.each do |(mid, kw), (reasons, note)|
    b = f.basis(rows, mid, **kw)
    NxTest.assert_equal(false, b['eligible'], "#{mid} #{kw.inspect}")
    NxTest.assert_equal(reasons, b['reasons'], "#{mid} #{kw.inspect}")
    NxTest.assert_equal(note, b['note'], "#{mid} #{kw.inspect}") if note
    NxTest.assert(b['tip'].end_with?('Množstvo a cena ostávajú z odhadu z m².'), b['tip'])
    NxTest.assert_equal(nil, b['sheets'])
  end
end

NxTest.test('NP-4 sposobilost: kombinacie v poradi mockupu, plan nil/chyba = nedostupny') do
  f = NxNp4
  rows = f::G.mixed_rows + [f::G.row('names' => ['Obr'], 'material_id' => 'NOF', 'length' => 2900.0, 'width' => 600.0)]
  b = f.basis(rows, 'NOF')
  NxTest.assert_equal(%w[no_format incomplete], b['reasons'])
  NxTest.assert_equal('formát chýba, plán neúplný — cena z odhadu', b['note'])
  b = f.basis(f::G.mixed_rows, 'UNI', source: 'seed_fallback', repaired: ['kerf_mm'])
  NxTest.assert_equal(%w[settings_unreadable settings_repaired uni], b['reasons'])
  [nil, { 'error' => 'plán nedostupný' }, 'x'].each do |pl|
    b = f::SL.price_basis(pl, 'H18', f::G::SHEETS)
    NxTest.assert_equal([false, ['unavailable']], b.values_at('eligible', 'reasons'), pl.inspect)
    NxTest.assert_equal('plán nedostupný — cena z odhadu', b['note'])
  end
  # material, ktory v plane nie je a NIE JE duplak
  NxTest.assert_equal(['unavailable'], f::SL.price_basis(f.plan(f::G.mixed_rows), 'NIC', f::G::SHEETS)['reasons'])
end

NxTest.test('NP-4 sposobilost (audit N6): stavia na upper_bound — neuplny plan bez znameho dovodu je nesposobily') do
  f = NxNp4
  pl = f.plan(f::G.mixed_rows)
  mat = pl['materials'].find { |m| m['material_id'] == 'H18' }
  mat['upper_bound'] = false # ziaden priznak neuplnosti, ale plan nie je horna hranica
  b = f::SL.price_basis(pl, 'H18', f::G::SHEETS)
  NxTest.assert_equal([false, ['incomplete']], b.values_at('eligible', 'reasons'))
end

# ============================================================================
# 3. ROZPOCET — mnozstvo, porez, montaz, XLSX, ponuka
# ============================================================================

NxTest.test('NP-4 rozpocet: zapnuty prepinac nad zmiesanou zakazkou — mnozstvo, zdroj, dovody') do
  f = NxNp4
  rows = f::G.mixed_rows
  on = f.compute(rows, f.plan(rows))
  off = f.compute(rows, f.plan(rows), on: false)
  NxTest.assert_equal(true, on['plan_prices'])
  NxTest.assert_equal(false, off['plan_prices'])
  h18 = f.mat_row(on, 'H18')
  NxTest.assert_equal([5, 'plan', 4], h18.values_at('mnozstvo', 'qty_source', 'estimate_qty'))
  NxTest.assert(h18['poznamka'].end_with?('plán: 5 platní (horná hranica) · cena podľa plánu'), h18['poznamka'])
  NxTest.assert_close(5 * h18['cena_mj'], h18['spolu'], 0.005, 'suma = platne z planu x cena za platnu')
  NxTest.assert_equal('plan', f.mat_row(on, 'PD')['qty_source'])
  # CENY-M2 (R1a, C14): NOF (DTDL bez formatu) je riadok podla plochy — na plan sa nepyta.
  nof = f.mat_row(on, 'NOF')
  NxTest.assert_equal(['area', 'M2', nil], nof.values_at('qty_basis', 'mj', 'qty_source'), 'NOF podla plochy, bez NP-4')
  NxTest.refute(nof['poznamka'].include?('cena z odhadu'), nof['poznamka'])
  NxTest.assert_equal(f.mat_row(off, 'NOF')['spolu'], nof['spolu'], 'NOF: prepinac cenu nemeni')
  { 'W18' => 'plán neúplný — cena z odhadu',
    'UNI' => 'materiál neurčený — cena z odhadu', 'W36' => 'duplák bez väzby — cena z odhadu' }.each do |mid, note|
    r = f.mat_row(on, mid)
    o = f.mat_row(off, mid)
    NxTest.assert_equal(['estimate', o['mnozstvo'], o['mnozstvo']], r.values_at('qty_source', 'mnozstvo', 'estimate_qty'), mid)
    NxTest.assert(r['poznamka'].end_with?(note), "#{mid}: #{r['poznamka']}")
    NxTest.assert_equal(o['spolu'], r['spolu'], "#{mid}: cena z odhadu = dnesna")
  end
  # vypnuty: riadok BEZ novych poli (zlaty test to drzi aj bajtovo)
  f.mat_row(off, 'H18').each_key { |k| NxTest.refute(%w[qty_source estimate_qty qty_tip].include?(k), k) }
end

NxTest.test('NP-4 sluzby (O6): porez = suma Materiálu (z planu), montaz = suma ODHADU') do
  f = NxNp4
  rows = f::G.mixed_rows
  on = f.compute(rows, f.plan(rows))
  off = f.compute(rows, f.plan(rows), on: false)
  mats_on = on['sections'].find { |s| s['key'] == 'materials' }['rows']
  porez = f.row_of(on, 'services', 'service:porez')
  montaz = f.row_of(on, 'services', 'service:montaz')
  # CENY-M2 (R5): riadok podla plochy (NOF) prispieva do porezu odhadom platni.
  NxTest.assert_equal(mats_on.sum { |r| (r['qty_basis'] == 'area' ? r['estimate_qty'] : r['mnozstvo']).to_i },
                      porez['mnozstvo'], 'porez ide za Materiálom')
  NxTest.assert_equal(f.row_of(off, 'services', 'service:porez')['mnozstvo'] + 1, porez['mnozstvo'], 'H18 +1 platna')
  NxTest.assert_equal(f.row_of(off, 'services', 'service:montaz')['mnozstvo'], montaz['mnozstvo'], 'montaz sa NEMENI')
  NxTest.assert_equal('platne z Materiálu (2 podľa plánu, 4 z odhadu)', porez['poznamka'])
  NxTest.assert_equal('9 platní × 5,8 m² · z odhadu', montaz['poznamka'])
  NxTest.assert_equal(nil, f.row_of(off, 'services', 'service:porez')['poznamka'], 'vypnuty: porez bez poznamky ako dnes')
  NxTest.assert_equal('9 platní × 5,8 m²', f.row_of(off, 'services', 'service:montaz')['poznamka'])
  NxTest.assert_equal([], on['budget_check'].select { |c| c['message'].to_s.include?('plán') },
                      'O11: nesposobily material NIE JE nalez Kontroly rozpoctu')
end

NxTest.test('NP-4 XLSX rozpoctu: POCET z planu a veta o cene v bunke MATERIÁL') do
  f = NxNp4
  rows = f::G.mixed_rows
  on = f.compute(rows, f.plan(rows))
  sheet = Noxun::Engine::BudgetXlsx.sheet(on, project: 'NP4', now: f::G::NOW)
  cells = sheet['rows'].map { |r| r.compact }
  h18 = cells.find { |c| c.first.is_a?(Hash) && c.first.values.join.include?('H1181 DTDL 18 mm ·') }
  NxTest.refute(h18.nil?, 'riadok H18 je v harku')
  NxTest.assert(h18.first.values.join.include?('cena podľa plánu'), h18.first.inspect)
  NxTest.assert(h18[3].values.include?(5), "POCET = 5 z planu: #{h18[3].inspect}")
  w18 = cells.find { |c| c.first.is_a?(Hash) && c.first.values.join.include?('W1000 DTDL 18 mm ·') }
  NxTest.assert(w18.first.values.join.include?('plán neúplný — cena z odhadu'), w18.first.inspect)
end

NxTest.test('NP-4 ponuka: meni len sumy (bez poctov a viet planu) a material moze preklopit cez prah 150 €') do
  f = NxNp4
  sheets = f::G::SHEETS.merge('C18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0],
                                          'decor' => 'Lacný', 'grain' => 'length', 'price_per_m2' => 20.0 })
  # dve siroke dosky: m² vyjdu na 1 platnu, plan potrebuje 2 (1100 + 5 + 1100 > 2050)
  rows = [f::G.row('names' => ['Doska'], 'material_id' => 'C18', 'length' => 2000.0, 'width' => 1100.0, 'quantity' => 2)]
  pl = Noxun::Engine::SheetLayout.compute(rows, sheets: sheets, edge_thicknesses: {}, params: {})
  pl.merge!('params_source' => 'file', 'params_version_ok' => true, 'params_repaired' => [])
  off = f.compute(rows, pl, on: false, sheets: sheets)
  on = f.compute(rows, pl, sheets: sheets)
  NxTest.assert_equal([1, 2], [f.mat_row(off, 'C18')['mnozstvo'], f.mat_row(on, 'C18')['mnozstvo']])
  c_off = off['cp_preview']['candidates'].find { |c| c['source_key'] == 'material:C18' }
  c_on = on['cp_preview']['candidates'].find { |c| c['source_key'] == 'material:C18' }
  NxTest.assert(c_off['amount'] < 150 && c_on['amount'] >= 150, [c_off['amount'], c_on['amount']].inspect)
  NxTest.assert_equal(%w[zostava samostatne], [c_off['state'], c_on['state']], 'navrh ponuky sa preklopi')
  NxTest.assert_equal(on['totals']['total'], on['cp_preview']['total'], 'ponuka = rozpocet na cent')
  txt = JSON.generate(Noxun::Engine::CpXlsx.price_sheet(on['cp_preview'], project: 'NP4', now: f::G::NOW))
  %w[plán odhad platní PLATŇA].each { |w| NxTest.refute(txt.include?(w), "ponuka nesmie niest „#{w}“") }
end

NxTest.test('NP-4 rozpocet: chyba vyhodnotenia sposobilosti = odhad, nikdy plan (fail-soft)') do
  f = NxNp4
  rows = f::G.mixed_rows
  saved = f::SL.method(:price_basis)
  f::SL.define_singleton_method(:price_basis) { |*_a| raise 'padol' }
  begin
    on = f.compute(rows, f.plan(rows))
  ensure
    f::SL.define_singleton_method(:price_basis, saved)
  end
  r = f.mat_row(on, 'H18')
  NxTest.assert_equal(['estimate', 4], r.values_at('qty_source', 'mnozstvo'))
  NxTest.assert(r['poznamka'].end_with?('plán nedostupný — cena z odhadu'), r['poznamka'])
end

# ============================================================================
# 4. NASTAVENIA — audit B2 (novsia zaloha), B3 (opraveny skalar)
# ============================================================================

NxTest.test('NP-4 B2: poskodeny primar + NOVSIA zaloha -> zdroj backup, ale version_ok false -> nesposobile') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  f = NxNp4
  f.with_sandbox do
    f.write_json("#{f::SS.path}.bak", f.v2_doc({}, std: 3))
    File.binwrite(f::SS.path, "{ toto nie je JSON\n")
    Noxun::Engine::JsonFileStore.invalidate
    lp = f::SS.layout_params
    NxTest.assert_equal(:backup, lp[:source], 'zdroj sam novsiu zalohu neprezradi')
    NxTest.assert_equal(false, lp[:version_ok])
    rows = f::G.mixed_rows
    pl = f::PC.layout_for({ records: [], hardware: [], hardware_issues: [], cut_issues: [], newer_configs: [] },
                          { rows: rows }, f::G::SHEETS, { 'rows' => [], 'unmapped' => [] })
    NxTest.assert_equal(['backup', false], pl.values_at('params_source', 'params_version_ok'))
    NxTest.assert_equal(['settings_newer'], f::SL.price_basis(pl, 'H18', f::G::SHEETS)['reasons'])
    # zaloha vo verzii 2 = spolahliva
    f.write_json("#{f::SS.path}.bak", f.v2_doc({}, std: 2))
    Noxun::Engine::JsonFileStore.invalidate
    lp = f::SS.layout_params
    NxTest.assert_equal([:backup, true], [lp[:source], lp[:version_ok]])
  end
end

NxTest.test('NP-4 B3: `trim_mm: "broken"` -> zdroj file, repaired [trim_mm], Kontrola ORANGE, cena z odhadu') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  f = NxNp4
  f.with_sandbox do
    f.write_json(f::SS.path, f.v2_doc({ 'trim_mm' => 'broken' }))
    Noxun::Engine::JsonFileStore.invalidate
    lp = f::SS.layout_params
    NxTest.assert_equal([:file, true, ['trim_mm']], [lp[:source], lp[:version_ok], lp[:repaired]])
    NxTest.assert_close(10.0, lp[:params]['trim'], 1e-9, 'plan pocita s predvolenym orezom')
    lay = f::PC.control_layout({})
    NxTest.assert_equal(['trim_mm'], lay[:repaired])
    out = Noxun::Engine::Validation.run({ records: [] }, sheets: {}, layout: lay)
    it = out['items'].select { |i| i['stable_key'] == 'layout_settings|repaired' }
    NxTest.assert_equal(1, it.length, 'jeden ORANGE nalez')
    NxTest.assert_equal('orange', it.first['severity'])
    NxTest.assert(it.first['message_sk'].include?('Orez okraja platne'), it.first['message_sk'])
    NxTest.assert(it.first['message_sk'].include?('ceny podľa plánu ostávajú z odhadu'), it.first['message_sk'])
    rows = f::G.mixed_rows
    pl = f::PC.layout_for({ records: [], hardware: [], hardware_issues: [], cut_issues: [], newer_configs: [] },
                          { rows: rows }, f::G::SHEETS, { 'rows' => [], 'unmapped' => [] })
    b = f::SL.price_basis(pl, 'H18', f::G::SHEETS)
    NxTest.assert_equal(['settings_repaired'], b['reasons'])
    # mimo rozsahu tiez; chybajuci kluc (legacy) aj null NIE
    f.write_json(f::SS.path, f.v2_doc({ 'kerf_mm' => 60.0 }))
    Noxun::Engine::JsonFileStore.invalidate
    NxTest.assert_equal(['kerf_mm'], f::SS.layout_params[:repaired])
    legacy = f.v2_doc
    legacy['suppliers'].first.delete('dup_allowance_mm')
    legacy['suppliers'].first['kerf_mm'] = nil
    f.write_json(f::SS.path, legacy)
    Noxun::Engine::JsonFileStore.invalidate
    NxTest.assert_equal([], f::SS.layout_params[:repaired], 'doplnenie chybajuceho pola je dovolene')
    NxTest.assert_equal([], Noxun::Engine::Validation.run({ records: [] }, sheets: {}, layout: f::PC.control_layout({}))['items']
                          .select { |i| i['stable_key'] == 'layout_settings|repaired' })
  end
end

NxTest.test('NP-4 B3: seed-merge poskodeny subor NEPREPISE (dokaz neprepadne) — ulozenie v Nastaveniach ho opravi') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  f = NxNp4
  f.with_sandbox do
    doc = f.v2_doc({ 'trim_mm' => 'broken' })
    doc['suppliers'].first['standard_rows'] = [] # seed-merge by chcel riadky doplnit a zapisat
    f.write_json(f::SS.path, doc)
    before = File.binread(f::SS.path)
    Noxun::Engine::JsonFileStore.invalidate
    f::SS.load
    NxTest.assert_equal(before, File.binread(f::SS.path), 'seed-merge nezapisal')
    NxTest.assert_equal(['trim_mm'], f::SS.layout_params[:repaired])
    NxTest.assert(f::SS.revision(f::SS.active).length == 12, 'revizia sa da spocitat')
    # Predrecenzia P3-3: sekcia Nastavenia dostane zoznam poskodenych klucov (zvyrazni
    # pole) a „Uložiť" bez upravy posle zobrazenu predvolenu hodnotu — to subor opravi.
    pay = Noxun::Engine::SupplierSettingsDialog.settings_payload
    NxTest.assert_equal(['trim_mm'], pay['supplier']['repaired_scalars'], 'payload sekcie nesie poskodene kluce')
    ok, errs = f::SS.patch_active!('trim_mm' => 10.0)
    NxTest.assert(ok, errs.inspect)
    Noxun::Engine::JsonFileStore.invalidate
    NxTest.assert_equal([], f::SS.layout_params[:repaired], 'ulozenie predvolenej hodnoty bez zmeny opravi subor')
    f.write_json(f::SS.path, doc)
    Noxun::Engine::JsonFileStore.invalidate
    ok, errs = f::SS.patch_active!('kerf_mm' => 4.0)
    NxTest.assert(ok, errs.inspect)
    Noxun::Engine::JsonFileStore.invalidate
    NxTest.assert_equal([], f::SS.layout_params[:repaired], 'vedome ulozenie subor opravi')
    NxTest.refute(File.binread(f::SS.path).include?('repaired_scalars'), 'odvodeny priznak sa do suboru NEZAPISUJE')
  end
end

# ============================================================================
# 5. EXPORT (audit F4) — status vymenuje materialy na odhade, okno sa obnovi
# ============================================================================

NxTest.test('NP-4 F4: plan pri exporte zlyhal -> subor ma odhad, status to povie a okno sa obnovi (oba XLSX)') do
  NxTest.skip!('headless stub exportu') unless NxTest.headless?
  f = NxNp4
  rows = f::G.mixed_rows
  good = f.compute(rows, f.plan(rows))
  NxTest.assert_equal('plan', f.mat_row(good, 'H18')['qty_source'], 'okno ukazovalo plan')
  failed = f.compute(rows, { 'error' => 'plán nedostupný' })
  NxTest.assert_equal('estimate', f.mat_row(failed, 'H18')['qty_source'], 'export ide na odhad')
  NxTest.assert(f.mat_row(failed, 'H18')['poznamka'].end_with?('plán nedostupný — cena z odhadu'), 'dovod v subore')
  Dir.mktmpdir('nx-np4-x-') do |dir|
    %i[do_budget_xlsx do_cp_xlsx].each do |method|
      msg, pushes, events = f.run_export(method, failed, dir)
      NxTest.assert(msg.to_s.include?('uložen'), "#{method}: export prebehol: #{msg}")
      # CENY-M2 (R1a): NOF (K001, bez formatu) ide podla plochy — v zozname „z odhadu" uz nie je.
      NxTest.assert(msg.include?(' · z odhadu (nie podľa plánu): H1181 DTDL 18 mm, Dub PD 38 mm, UNI DTDL 18 mm a 2 ďalšie'),
                    "#{method}: #{msg}")
      NxTest.assert_equal(1, pushes, "#{method}: okno sa obnovi")
      NxTest.assert_equal(%i[repush status], events.last(2), "#{method}: push PRED statusom")
    end
    # vypnuty prepinac: ziadna veta, ziadny push navyse (dnesne spravanie)
    off = f.compute(rows, { 'error' => 'plán nedostupný' }, on: false)
    msg, pushes, = f.run_export(:do_budget_xlsx, off, dir)
    NxTest.refute(msg.include?('z odhadu'), msg)
    NxTest.assert_equal(0, pushes)
  end
end

NxTest.test('NP-4 F4 (predrecenzia P3-2): „a N ďalší/ďalšie/ďalších" — tvar podla poctu materialov') do
  f = NxNp4
  bud = lambda do |n|
    rows = (1..n).map { |i| { 'nazov' => "M#{i}", 'qty_source' => 'estimate' } }
    { 'plan_prices' => true, 'sections' => [{ 'key' => 'materials', 'rows' => rows }] }
  end
  NxTest.assert_equal(' · z odhadu (nie podľa plánu): M1, M2, M3', f::PC.plan_export_note(bud.call(3)))
  NxTest.assert(f::PC.plan_export_note(bud.call(4)).end_with?('M1, M2, M3 a 1 ďalší'))
  NxTest.assert(f::PC.plan_export_note(bud.call(5)).end_with?('M3 a 2 ďalšie'))
  NxTest.assert(f::PC.plan_export_note(bud.call(7)).end_with?('M3 a 4 ďalšie'))
  NxTest.assert(f::PC.plan_export_note(bud.call(8)).end_with?('M3 a 5 ďalších'))
end

NxTest.test('NP-4 P2: karta Nárezového plánu povie „v rozpočte" cislo HOTOVEHO rozpoctu (jedna pravda)') do
  f = NxNp4
  rows = f::G.mixed_rows
  pl = f.plan(rows)
  est = f.estimate(rows, f::G::SHEETS)
  on = f.compute(rows, pl)
  pay = f::PC.sheet_layout_payload(pl, { rows: rows }, f::G::SHEETS, est, on)
  h18 = pay['materials'].find { |m| m['id'] == 'H18' }
  NxTest.assert_equal([f.mat_row(on, 'H18')['mnozstvo'], 'plan'], h18.values_at('budget_qty', 'budget_src'),
                      'karta = mnozstvo rozpoctu (5 z planu)')
  NxTest.assert_equal(4, h18['est_budget'], 'odhad z m² ostava odhadom (sucet v suhrne)')
  w18 = pay['materials'].find { |m| m['id'] == 'W18' }
  NxTest.assert_equal([f.mat_row(on, 'W18')['mnozstvo'], 'estimate'], w18.values_at('budget_qty', 'budget_src'))
  off = f.compute(rows, pl, on: false)
  h_off = f::PC.sheet_layout_payload(pl, { rows: rows }, f::G::SHEETS, est, off)['materials'].find { |m| m['id'] == 'H18' }
  NxTest.assert_equal([4, nil], h_off.values_at('budget_qty', 'budget_src'), 'vypnuty prepinac: odhad, bez zdroja')
  h_none = f::PC.sheet_layout_payload(pl, { rows: rows }, f::G::SHEETS, est)['materials'].find { |m| m['id'] == 'H18' }
  NxTest.assert_equal([4, nil], h_none.values_at('budget_qty', 'budget_src'), 'bez rozpoctu (legacy volanie): odhad')
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?('sheet_layout_payload(layout, bom, smap, estimate, budget)'),
                'push Studia odovzda sekcii TEN ISTY rozpocet')
end

NxTest.test('NP-4 F4: plan_export_note — bez vety pri zapnutom a vsetkom z planu') do
  f = NxNp4
  sheets = { 'PD' => f::G::SHEETS['PD'] }
  rows = [f::G.row('names' => ['PD'], 'material_id' => 'PD', 'thickness' => 38.0, 'length' => 3000.0, 'width' => 600.0)]
  pl = Noxun::Engine::SheetLayout.compute(rows, sheets: sheets, edge_thicknesses: {}, params: {})
  pl.merge!('params_source' => 'file', 'params_version_ok' => true, 'params_repaired' => [])
  NxTest.assert_equal('', f::PC.plan_export_note(f.compute(rows, pl, sheets: sheets)))
  NxTest.assert_equal('', f::PC.plan_export_note(nil))
end
