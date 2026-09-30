# frozen_string_literal: true
# CENY-M2 [C12] — material bez formatu podla SKUTOCNEJ plochy dielcov.
# Package: SYSTEM/zdroje/bloky/CENY/PACKAGE_CENY_M2.md (§6.1, §7 bod 1).
#
# Co sa tu dokazuje:
#   R1  „podla plochy" ide LEN material bez platneho formatu, ktoreho TYP nie je
#       v registri typov (sklo); bezna doska bez formatu (DTDL…), UNI, duplak,
#       chybajuci zaznam a akykolvek kladny format (aj 300 × 200) ostavaju na
#       dnesnom odhade platni. Typ sa normalizuje registrom (`dtdl`, " DTDL ").
#   R2  mnozstvo = nezaokruhlena plocha na 2 desatinne (bez dvojiteho
#       zaokruhlenia), vratane duplakov x nasobok, min. 0,01 m².
#   R3  cena za MJ = `Materials.display_m2`, sucet = mnozstvo x cena na cent.
#   R4  tvar riadku a poznamka; ziadne NP-3/NP-4 polia.
#   R5  porez a montaz PRESNE dnesne (aj pri zapnutych cenach podla planu).
#   R6  `plan_export_note` area riadok nevymenuje.
#   R7  karta Narezoveho planu: `budget_src 'area'`, `budget_qty` = m².
#   R8  XLSX riadok (MJ/POCET/CENA/SPOLU), cenova ponuka (suma, preklopenie cez
#       prah, rucne zaradenie), chybajuca cena = `price_missing` + Kontrola.
require_relative '../helper' unless defined?(NxTest)
require_relative 'test_np4_golden'
require_relative '../fixtures/ceny_m2_golden/fixture'
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
end

module CenyM2Area
  E  = Noxun::Engine
  B  = E::Budget
  M  = E::Materials
  SL = E::SheetLayout
  NOW = Time.utc(2026, 9, 30, 12)

  SHEETS = {
    'H18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1180',
               'price_per_m2' => 24.9 },
    'SK4' => { 'type' => 'SKLO', 'thickness' => 4.0, 'decor' => 'Číre', 'price_per_m2' => 41.5,
               'cp_nazov' => 'Sklo číre 4 mm' },
    'NOF' => { 'type' => 'DTDL', 'thickness' => 18.0, 'decor' => 'K001', 'price_per_m2' => 31.2 },
    'NOP' => { 'type' => 'SKLO', 'thickness' => 4.0, 'decor' => 'Zrkadlo' },
    'UNI' => { 'type' => 'DTDL', 'thickness' => 18.0, 'decor' => 'UNI', 'uni' => true },
    'DUP' => { 'type' => 'SKLO', 'thickness' => 8.0, 'decor' => 'Číre dup', 'source_material_id' => 'SK4',
               'source_multiplier' => 2, 'price_per_m2' => 83.0 },
    'SMA' => { 'type' => 'SKLO', 'thickness' => 4.0, 'decor' => 'Malé', 'sheet_size' => [300.0, 200.0],
               'price_per_m2' => 41.5 }
  }.freeze

  module_function

  def r(mid, len, wid, qty, extra = {})
    NxNp4Golden.row({ 'names' => ['Diel'], 'material_id' => mid, 'length' => len, 'width' => wid,
                      'quantity' => qty, 'thickness' => (SHEETS.dig(mid, 'thickness') || 18.0),
                      'grain_direction' => 'none' }.merge(extra))
  end

  def rows
    [r('H18', 2000.0, 560.0, 8), r('SK4', 600.0, 500.0, 3), r('NOF', 700.0, 500.0, 3),
     r('NOP', 400.0, 300.0, 1), r('UNI', 700.0, 500.0, 2)]
  end

  def estimate(rws, sheets = SHEETS)
    E::SheetEstimate.estimate(rws, sheet_sizes: sheets.transform_values { |s| s['sheet_size'] },
                                   uni_ids: sheets.select { |_k, s| s['uni'] == true }.transform_values { true })
  end

  def plan(rws, sheets = SHEETS)
    res = SL.compute(rws, sheets: sheets, edge_thicknesses: {}, params: {}, blocked: nil)
    res['params_source'] = 'file'
    res
  end

  def pay(rws = rows, state = {}, sheets: SHEETS, layout: true)
    B.compute({ rows: rws, edging: [] }, state, E::SupplierSettings.seed_supplier,
              sheets: sheets, edges: {}, sheet_estimate: estimate(rws, sheets), now: NOW,
              sheet_layout: (layout ? plan(rws, sheets) : nil))
  end

  def mat(p, mid)
    p['sections'].find { |s| s['key'] == 'materials' }['rows'].find { |x| x['material_id'] == mid }
  end

  def svc(p, key)
    p['sections'].find { |s| s['key'] == 'services' }['rows'].find { |x| x['key'] == "service:#{key}" }
  end

  def group(rws, mid, sheets = SHEETS)
    estimate(rws, sheets).find { |g| g['material_id'] == mid }
  end
end

# --- R1: kto ide podla plochy -------------------------------------------------------

NxTest.test('CENY-M2 (R1): sklo bez formatu = area; DTDL bez formatu, UNI, duplak, chybajuci zaznam a kazdy format = dnesny odhad') do
  c = CenyM2Area
  p = c.pay
  sk = c.mat(p, 'SK4')
  NxTest.assert_equal(['M2', 'area'], sk.values_at('mj', 'qty_basis'), 'sklo bez formatu ide podla plochy')
  nof = c.mat(p, 'NOF')
  g = c.group(c.rows, 'NOF')
  NxTest.assert_equal(['PLATŇA', c::B.plates_of(g), (31.2 * 5.796).round(2), true, nil],
                      nof.values_at('mj', 'mnozstvo', 'cena_mj', 'estimated', 'qty_basis'),
                      'DTDL bez formatu ostava platnou (R1, Q2 otvorena)')
  NxTest.assert(nof['poznamka'].include?('formát platne nie je v katalógu — odhad podľa 2800×2070'), 'dnesna poznamka')
  NxTest.assert(nof['poznamka'].include?('plán: orientačne 1 platňa'), 'DTDL bez formatu ma vetu planu NP-3 ako dnes')
  on = c.mat(c.pay(c.rows, { 'plan_prices' => true }), 'NOF')
  NxTest.assert_equal(['PLATŇA', 'estimate'], on.values_at('mj', 'qty_source'), 'zapnuty prepinac: dnesny odhad')
  NxTest.assert(on['poznamka'].include?('formát chýba — cena z odhadu'), 'dnesna veta NP-4')
  uni = c.mat(p, 'UNI')
  NxTest.assert_equal(['PLATŇA', nil], uni.values_at('mj', 'qty_basis'), 'UNI bez formatu ostava odhadom')
  # Neviazany duplakovy zaznam (vlastna skupina odhadu) bez formatu.
  dup_rows = [c.r('DUP', 600.0, 500.0, 1)]
  dup_sheets = c::SHEETS.merge('DUP' => c::SHEETS['DUP'].reject { |k, _| k == 'sheet_size' })
  NxTest.assert_equal('PLATŇA', c.mat(c.pay(dup_rows, sheets: dup_sheets, layout: false), 'DUP')['mj'], 'duplak ostava odhadom')
  # Chybajuci zaznam v katalogu.
  miss = c.pay([c.r('ZZZ', 600.0, 500.0, 1)], layout: false)
  NxTest.assert_equal('PLATŇA', c.mat(miss, 'ZZZ')['mj'], 'chybajuci zaznam ostava odhadom')
  # Akykolvek kladny format (aj 300 × 200) = platna (jedina pravda `sheet_size_for`).
  sma = c.pay([c.r('SMA', 250.0, 150.0, 1)], layout: false)
  NxTest.assert_equal(['PLATŇA', nil], c.mat(sma, 'SMA').values_at('mj', 'qty_basis'), '300 × 200 je format')
  NxTest.assert_equal('PLATŇA', c.mat(p, 'H18')['mj'], 'platny format ostava platnou')
end

NxTest.test('CENY-M2 (R1): typ sa pyta registra s normalizaciou — dtdl/" DTDL "/Dtdl\\t = platna, SKLO/sklo/Zrkadlo/prazdny = area') do
  b = CenyM2Area::B
  %W[DTDL dtdl #{' DTDL '} Dtdl\t MDF hdf PD ZASTENA KOMPAKT].each do |t|
    NxTest.refute(b.area_priced_type?('type' => t), "#{t.inspect} je v registri (ostava platnou)")
  end
  ['SKLO', 'sklo', 'Zrkadlo', '', nil].each do |t|
    NxTest.assert(b.area_priced_type?('type' => t), "#{t.inspect} je mimo registra (podla plochy)")
  end
  NxTest.assert(b.area_priced_type?({}), 'chybajuci typ = mimo registra')
  # Vedomy stav (§9, F6): `identity_norm` diakritiku nezlucuje.
  NxTest.assert(b.area_priced_type?('type' => 'Zástena'), 'Zástena s diakritikou je mimo registra (F6)')
  # Poistka: normalizovany typ dosky bez formatu ostava platnou aj v Rozpocte.
  sheets = CenyM2Area::SHEETS.merge('NOF' => CenyM2Area::SHEETS['NOF'].merge('type' => ' dtdl '))
  p = CenyM2Area.pay([CenyM2Area.r('NOF', 700.0, 500.0, 3)], sheets: sheets, layout: false)
  NxTest.assert_equal('PLATŇA', CenyM2Area.mat(p, 'NOF')['mj'], '" dtdl " bez formatu ostava platnou')
end

# --- R2 / R3: mnozstvo a cena ----------------------------------------------------------

NxTest.test('CENY-M2 (R2): mnozstvo = nezaokruhlena plocha na 2 desatinne (duplak x nasobok, 1869 × 500 = 0,93, min 0,01)') do
  c = CenyM2Area
  NxTest.assert_equal(0.9, c.mat(c.pay, 'SK4')['mnozstvo'], '3 × 600 × 500 = 0,90 m²')
  with_dup = [c.r('SK4', 600.0, 500.0, 3),
              c.r('DUP', 400.0, 300.0, 1, 'material_source' => { 'material_id' => 'SK4', 'multiplier' => 2 })]
  row = c.mat(c.pay(with_dup, layout: false), 'SK4')
  NxTest.assert_equal((0.9 + (0.12 * 2)).round(2), row['mnozstvo'], 'plocha vratane duplaku x nasobok')
  NxTest.assert(row['poznamka'].include?('vrátane 1 ks duplákov (0,24 m²)'), 'veta duplakov ostava')
  edge = [c.r('SK4', 1869.0, 500.0, 1)]
  NxTest.assert_equal(0.935, c.group(edge, 'SK4')['m2'], 'prezentacny odhad je 0,935')
  NxTest.assert_equal(0.93, c.mat(c.pay(edge, layout: false), 'SK4')['mnozstvo'], 'bez dvojiteho zaokruhlenia (nie 0,94)')
  tiny = [c.r('SK4', 50.0, 50.0, 1)]
  NxTest.assert_equal(0.01, c.mat(c.pay(tiny, layout: false), 'SK4')['mnozstvo'], 'drobny dielec sa neoceni nulou')
  NxTest.assert_equal(0.0, c.group(edge, 'SK4')['m2_exact'] - 0.9345, 'estimate nesie m2_exact nezaokruhlene')
end

NxTest.test('CENY-M2 (R3): cena za MJ = Materials.display_m2, sucet = mnozstvo × cena na cent (hranice pol centa)') do
  c = CenyM2Area
  [1.005, 2.675, 31.005, 31.0386, 41.5].each do |price|
    sheets = c::SHEETS.merge('SK4' => c::SHEETS['SK4'].merge('price_per_m2' => price))
    row = c.mat(c.pay([c.r('SK4', 1869.0, 500.0, 1)], sheets: sheets, layout: false), 'SK4')
    NxTest.assert_equal(c::M.display_m2(price), row['cena_mj'], "cena_mj pre #{price}")
    NxTest.assert_equal((row['mnozstvo'] * row['cena_mj']).round(2), row['spolu'], "spolu pre #{price}")
    NxTest.assert_equal(price, row['price_per_m2'], 'price_per_m2 = surova hodnota katalogu')
  end
  NxTest.assert_equal([1.01, 2.68, 31.01], [1.005, 2.675, 31.005].map { |v| c::M.display_m2(v) }, 'half-up na centy')
end

# --- R4: tvar riadku ---------------------------------------------------------------------

NxTest.test('CENY-M2 (R4): tvar area riadku — M2, area, estimate_qty vzdy, poznamka presne, bez NP-3/NP-4 poli') do
  c = CenyM2Area
  g = c.group(c.rows, 'SK4')
  [{}, { 'plan_prices' => true }].each do |state|
    row = c.mat(c.pay(c.rows, state), 'SK4')
    NxTest.assert_equal(['material:SK4', 'M2', 0.9, 41.5, 37.35, 'area', c::B.plates_of(g), false, 0.9, 41.5, 'SK4',
                         'Sklo číre 4 mm'],
                        row.values_at('key', 'mj', 'mnozstvo', 'cena_mj', 'spolu', 'qty_basis', 'estimate_qty', 'estimated',
                                      'm2', 'price_per_m2', 'material_id', 'cp_nazov'), "stav #{state.inspect}")
    NxTest.assert_equal('formát platne nie je v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)', row['poznamka'],
                        'poznamka bez vety X m², planu aj ceny podla planu')
    NxTest.refute(row.key?('qty_source') || row.key?('qty_tip'), 'ziadne NP-4 polia')
  end
end

# --- R5: sluzby sa nemenia --------------------------------------------------------------

NxTest.test('CENY-M2 (R5): porez a montaz dnesne cisla aj poznamky (vypnuty aj zapnuty prepinac)') do
  c = CenyM2Area
  # Referencia = TA ISTA geometria, sklo ako doska z registra (dnesna vetva platni).
  as_board = c::SHEETS.merge('SK4' => c::SHEETS['SK4'].merge('type' => 'DTDL'))
  [{}, { 'plan_prices' => true }].each do |state|
    now = c.pay(c.rows, state)
    ref = c.pay(c.rows, state, sheets: as_board)
    NxTest.assert_equal('area', c.mat(now, 'SK4')['qty_basis'])
    NxTest.assert_equal('PLATŇA', c.mat(ref, 'SK4')['mj'])
    %w[porez montaz].each do |k|
      NxTest.assert_equal(c.svc(ref, k).values_at('mnozstvo', 'poznamka', 'spolu'),
                          c.svc(now, k).values_at('mnozstvo', 'poznamka', 'spolu'), "#{k} #{state.inspect}")
    end
  end
end

# --- R6 / R7: plan -----------------------------------------------------------------------

NxTest.test('CENY-M2 (R6/R7): plan_export_note area riadok nevymenuje; karta planu budget_src area a m²') do
  c = CenyM2Area
  pc = Noxun::Engine::ProductionCore
  on = c.pay(c.rows, { 'plan_prices' => true })
  note = pc.plan_export_note(on)
  NxTest.refute(note.include?('Číre'), 'sklo nie je v zozname „z odhadu"')
  NxTest.assert(note.include?('K001'), 'DTDL bez formatu ostava v zozname „z odhadu"')
  rws = c.rows
  [{}, { 'plan_prices' => true }].each do |state|
    p = c.pay(rws, state)
    sl = pc.sheet_layout_payload(c.plan(rws), { rows: rws }, c::SHEETS, c.estimate(rws), p)
    sk = sl['materials'].find { |m| m['id'] == 'SK4' }
    NxTest.assert_equal([0.9, 'area'], sk.values_at('budget_qty', 'budget_src'), "karta skla #{state.inspect}")
    nof = sl['materials'].find { |m| m['id'] == 'NOF' }
    NxTest.refute(nof['budget_src'] == 'area', 'DTDL bez formatu nie je area')
  end
end

# --- R8: XLSX, ponuka, chybajuca cena ---------------------------------------------------

NxTest.test('CENY-M2 (R8): XLSX riadok skla MJ M2 / 0,90 / cena za m² / sucet; chybajuca cena = price_missing + Kontrola') do
  c = CenyM2Area
  p = c.pay
  xl = Noxun::Engine::BudgetXlsx.sheet(p, project: 'M2', now: c::NOW)
  cells = xl['rows'].map { |cs| cs.compact.map { |x| x.is_a?(Hash) ? x['v'] : x } }
  sk = cells.find { |cs| cs.first.to_s.start_with?('Číre SKLO') }
  NxTest.assert(sk, 'riadok skla je v XLSX')
  NxTest.assert(sk.first.include?('počíta sa skutočná plocha dielcov'), 'nazov nesie poznamku R4')
  NxTest.assert_equal(['M2', 0.9, 41.5, 37.35], sk[2..5], 'MJ / POCET / CENA / SPOLU')
  nop = c.mat(p, 'NOP')
  NxTest.assert_equal(['M2', true, nil], nop.values_at('mj', 'price_missing', 'spolu'), 'sklo bez ceny nikdy nula')
  msgs = p['budget_check'].map { |w| w['message'] }
  NxTest.assert(msgs.any? { |m| m.start_with?('Materiál: 2 riadky bez ceny') }, "Kontrola: #{msgs.inspect}")
end

NxTest.test('CENY-M2 (R8): ponuka — sklo 240,53 → 37,35 € vypadne zo samostatnych riadkov, rucne zaradenie plati') do
  g = NxCenyM2Golden
  pre = g.load_pre['payload']['cp_preview']['candidates'].find { |x| x['source_key'] == 'material:SK4' }
  NxTest.assert_equal([240.53, 'samostatne'], pre.values_at('amount', 'state'), 'pred M2: fiktivna platna nad prahom')
  cp = g.payload['cp_preview']
  sk = cp['candidates'].find { |x| x['source_key'] == 'material:SK4' }
  NxTest.assert_equal([37.35, 'zostava', 1, 'set'], sk.values_at('amount', 'state', 'mnozstvo', 'mj'),
                      'po M2: suma podla plochy, pod prahom 150 € ide do zostavy, stale 1 set')
  NxTest.refute(cp['rows'].any? { |x| x['source_key'] == 'material:SK4' }, 'samostatny riadok skla zanikol')
  forced = g.payload('cp_overrides' => { 'material:SK4' => 'samostatne' })['cp_preview']
  sk2 = forced['candidates'].find { |x| x['source_key'] == 'material:SK4' }
  NxTest.assert_equal(['samostatne', true], sk2.values_at('state', 'overridden'), 'rucne zaradenie „samostatne" plati')
  NxTest.assert(forced['rows'].any? { |x| x['source_key'] == 'material:SK4' && x['cena'] == 37.35 }, 'riadok ostal')
end
