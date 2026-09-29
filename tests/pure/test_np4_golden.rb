# frozen_string_literal: true
# NP-4 — GOLDEN CHARAKTERIZACIA ROZPOCTU PRI VYPNUTOM PREPINACI „ceny podla planu".
#
# PRECO: NP-4 meni cenu materialu, porezu a (zamerne nie) montaze podla
# narezoveho planu — ale LEN po vedomom zapnuti prepinaca v zakazke. Zavazok
# davky (package §4 bod 1, „zlaty test") je, ze VYPNUTY prepinac (aj chybajuci
# kluc) dava PRESNE dnesne cisla, riadky aj oba XLSX. Golden subory su odtlacok
# stavu z MAINU PRED NP-4 (v0.15.3, NP-3 = plan len v poznamke); test porovnava
# CERSTVY vypocet s nimi.
#
# CO SA ODTLACA: cely payload `Budget.compute` (sekcie, sumy, poznamky,
# Kontrola rozpoctu, nahlad cenovej ponuky), harok XLSX rozpoctu
# (`BudgetXlsx.sheet`) a harok cien XLSX ponuky (`CpXlsx.price_sheet`).
# Jediny DOVOLENY rozdiel je NOVY kluc payloadu `plan_prices` (ozvena stavu
# prepinaca, NP-4) — porovnanie ho pred porovnanim vynecha a zvlast overi,
# ze je `false`.
#
# SPUSTA SA RUCNE (test generator NEVOLA — inak by charakterizacia „dokazovala"
# samu seba):  C:/Ruby32-x64/bin/ruby.exe tests/fixtures/np4_golden/generate.rb
require_relative '../helper' unless defined?(NxTest)

require 'json'

module NxNp4Golden
  E  = Noxun::Engine
  SL = E::SheetLayout

  FIXTURES = File.join(NxTest::ROOT, 'tests', 'fixtures', 'np4_golden')
  NOW = Time.utc(2026, 9, 29, 12)

  # Zmiesana zakazka: spolahlivy DTD (H18 + viazany duplak H36), neuplny W18
  # (bok, ktory sa po oreze nezmesti) s neviazanym duplakom W36, material bez
  # formatu (NOF), UNI a pracovna doska (bez orezu).
  SHEETS = {
    'H18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1181',
               'grain' => 'length', 'price_per_m2' => 36.5 },
    'H36' => { 'type' => 'DTDL', 'thickness' => 36.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1181 duplák',
               'source_material_id' => 'H18', 'source_multiplier' => 2, 'price_per_m2' => 73.0 },
    'W18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'W1000',
               'grain' => 'none', 'price_per_m2' => 26.9 },
    'W36' => { 'type' => 'DTDL', 'thickness' => 36.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'W1000 duplák',
               'source_material_id' => 'W18', 'source_multiplier' => 2, 'price_per_m2' => 53.8 },
    'UNI' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'UNI', 'uni' => true },
    'NOF' => { 'type' => 'DTDL', 'thickness' => 18.0, 'decor' => 'K001', 'price_per_m2' => 31.2 },
    'PD'  => { 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0], 'decor' => 'Dub', 'price_per_m2' => 62.0 }
  }.freeze

  module_function

  def row(over = {})
    r = { 'names' => ['Bok'], 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0, 'quantity' => 1,
          'material_id' => 'H18', 'grain_direction' => 'length',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
          'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 1 }] }.merge(over)
    r['key'] = E::Bom.row_key(r) unless over.key?('key')
    r
  end

  def mixed_rows
    [
      row('names' => ['Bok vysoký'], 'length' => 2000.0, 'width' => 560.0, 'quantity' => 8),
      row('names' => ['Polica'], 'length' => 800.0, 'width' => 540.0, 'quantity' => 10),
      row('names' => ['Doska dupl.'], 'material_id' => 'H36', 'thickness' => 36.0, 'length' => 1200.0,
          'width' => 600.0, 'material_source' => { 'material_id' => 'H18', 'multiplier' => 2 }),
      row('names' => ['Bok 2795'], 'material_id' => 'W18', 'length' => 2795.0, 'width' => 600.0, 'grain_direction' => 'length'),
      row('names' => ['Dno'], 'material_id' => 'W18', 'length' => 700.0, 'width' => 500.0, 'quantity' => 4,
          'grain_direction' => 'none'),
      row('names' => ['Čelo dupl.'], 'material_id' => 'W36', 'thickness' => 36.0, 'length' => 600.0, 'width' => 400.0),
      row('names' => ['Dvierka'], 'material_id' => 'NOF', 'length' => 700.0, 'width' => 500.0, 'quantity' => 3),
      row('names' => ['Korpus'], 'material_id' => 'UNI', 'length' => 700.0, 'width' => 500.0, 'quantity' => 2),
      row('names' => ['Pracovná doska'], 'material_id' => 'PD', 'thickness' => 38.0, 'length' => 3000.0, 'width' => 600.0)
    ]
  end

  def plan(rows, blocked: nil, source: 'file')
    res = SL.compute(rows, sheets: SHEETS, edge_thicknesses: {}, params: {}, blocked: blocked)
    res['params_source'] = source
    res
  end

  def estimate(rows)
    E::SheetEstimate.estimate(rows, sheet_sizes: SHEETS.transform_values { |s| s['sheet_size'] },
                                    uni_ids: { 'UNI' => true })
  end

  # Stav zakazky: nic (legacy/cista zakazka) alebo vypnuty prepinac. NP-4 ich
  # musi vyhodnotit ROVNAKO (chybajuci kluc = vypnute).
  CASES = {
    'mix_file' => { blocked: nil, source: 'file' },
    'mix_blocked' => { blocked: { 'all' => 'VEPO export by sa zastavil: test' }, source: 'file' },
    'mix_seed_fallback' => { blocked: nil, source: 'seed_fallback' }
  }.freeze

  def payload(kase, state = {})
    rows = mixed_rows
    E::Budget.compute({ rows: rows, edging: [] }, state, E::SupplierSettings.seed_supplier,
                      sheets: SHEETS, edges: {}, sheet_estimate: estimate(rows),
                      sheet_layout: plan(rows, blocked: kase[:blocked], source: kase[:source]), now: NOW)
  end

  def snapshot(kase, state = {})
    p = payload(kase, state)
    { 'payload' => p,
      'budget_xlsx' => E::BudgetXlsx.sheet(p, project: 'Golden', now: NOW),
      'cp_price_sheet' => E::CpXlsx.price_sheet(p['cp_preview'], project: 'Golden', now: NOW) }
  end

  # JSON okruh (golden je JSON) — Float/Integer a kluce presne ako v subore.
  def roundtrip(obj)
    JSON.parse(JSON.generate(obj))
  end

  def load(name)
    JSON.parse(File.read(File.join(FIXTURES, "#{name}.json"), encoding: 'UTF-8'))
  end
end

NxNp4Golden::CASES.each do |name, kase|
  NxTest.test("NP-4 golden: #{name} — vypnuty prepinac (aj chybajuci kluc) = cisla, riadky aj oba XLSX ako pred NP-4") do
    gold = NxNp4Golden.load(name)
    [{}, { 'plan_prices' => false }].each do |state|
      fresh = NxNp4Golden.roundtrip(NxNp4Golden.snapshot(kase, state))
      echo = fresh['payload'].delete('plan_prices')
      NxTest.assert(echo.nil? || echo == false, "stav #{state.inspect}: ozvena prepinaca je false (#{echo.inspect})")
      NxTest.assert_equal(gold, fresh, "stav #{state.inspect}: odtlacok sa zhoduje s mainom pred NP-4")
    end
  end
end
