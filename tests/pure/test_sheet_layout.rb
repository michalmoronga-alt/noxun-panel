# frozen_string_literal: true
# NP-1 (blok 2 · Nárezový plán): testy jadra výpočtu `SheetLayout`.
# Package: SYSTEM/zdroje/bloky/NAREZ/PACKAGE_NP1_JADRO.md (§4).
#
# Oddelené skupiny (audit F8):
#   * `fits_rect?` — desatinné vstupy a tolerancia 0,1 mm, otáčanie,
#   * `compute` — vstup po zaokrúhlení na celé mm (tak ho dostane aj VEPO):
#     presné očakávané rozloženia (golden), vlastnosti, neúplnosť, výkon.
require_relative '../helper' unless defined?(NxTest)
# Fixtúra charakterizačných VEPO testov (test zhody prepare_row s build).
require_relative 'test_np1_vepo_charakterizacia' unless defined?(NxNp1Char)

module NxSL
  module_function

  def sl
    Noxun::Engine::SheetLayout
  end

  EDGES = { 'ABS1' => 1.0 }.freeze
  SHEETS = {
    'DTD18'  => { 'material_id' => 'DTD18', 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0] },
    'DTD36'  => { 'material_id' => 'DTD36', 'type' => 'DTDL', 'thickness' => 36.0, 'sheet_size' => [2800.0, 2070.0],
                  'source_material_id' => 'DTD18', 'source_multiplier' => 2 },
    'MDF19'  => { 'material_id' => 'MDF19', 'type' => 'MDF', 'thickness' => 19.0, 'sheet_size' => [2800.0, 2070.0] },
    'HDF3'   => { 'material_id' => 'HDF3', 'type' => 'HDF', 'thickness' => 3.0, 'sheet_size' => [2800.0, 2070.0] },
    'PD38'   => { 'material_id' => 'PD38', 'type' => 'pd', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0] },
    'KOMP12' => { 'material_id' => 'KOMP12', 'type' => 'Kompakt', 'thickness' => 12.0, 'sheet_size' => [4100.0, 920.0] },
    'ZAST10' => { 'material_id' => 'ZAST10', 'type' => 'ZASTENA', 'thickness' => 10.0, 'sheet_size' => [4100.0, 640.0] },
    'INY18'  => { 'material_id' => 'INY18', 'type' => 'Preglejka', 'thickness' => 18.0, 'sheet_size' => [2500.0, 1250.0] },
    'UNI18'  => { 'material_id' => 'UNI18', 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0],
                  'uni' => true },
    'NOFMT'  => { 'material_id' => 'NOFMT', 'type' => 'DTDL', 'thickness' => 18.0 },
    'NOTHK'  => { 'material_id' => 'NOTHK', 'type' => 'DTDL', 'sheet_size' => [2800.0, 2070.0] }
  }.freeze

  # Riadok v tvare Bom.compute[:rows] vrátane `key` (Bom.row_key).
  def row(over = {})
    r = { 'names' => ['Bok'], 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0, 'quantity' => 1,
          'material_id' => 'DTD18', 'grain_direction' => 'length',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }.merge(over)
    r['key'] = Noxun::Engine::Bom.row_key(r) if r['edges'].is_a?(Hash) && !over.key?('key')
    r
  end

  def compute(rows, **kw)
    sl.compute(rows, sheets: SHEETS, edge_thicknesses: EDGES, **kw)
  end

  def mat(res, id)
    res['materials'].find { |m| m['material_id'] == id }
  end

  # NP-3 (audit B2, B3): záznamy `rejected`/`conflicts` nesú navyše natívny
  # `key` a `row_material_id` — pôvodné očakávania NP-1 porovnávajú jadro.
  def core(list)
    Array(list).map { |e| e.slice('reason', 'detail', 'names') }
  end

  # Umiestnenia materiálu ako [číslo platne od 1, l, w, x, y] v poradí platní.
  def placed(m)
    out = []
    m['layouts'].each_with_index do |s, si|
      s['placements'].each do |idx, _n, x, y|
        r = m['rows'][idx]
        out << [si + 1, r['l'], r['w'], x, y]
      end
    end
    out
  end

  # Geometrické invarianty jedného materiálu: v použiteľnej ploche s toleranciou,
  # bez prekryvu a s medzerou >= prerez medzi každými dvoma dielcami platne.
  def assert_geometry(m, kerf)
    tol = Noxun::Engine::Validation::DIM_TOL
    lu, wu = m['usable']
    placed(m).group_by(&:first).each_value do |items|
      items.each do |_s, l, w, x, y|
        NxTest.assert(x >= -tol && y >= -tol, "dielec mimo plochy (#{x}, #{y})")
        NxTest.assert(x + l <= lu + tol && y + w <= wu + tol, "dielec #{l}x#{w} na (#{x}, #{y}) presahuje #{lu}x#{wu}")
      end
      items.combination(2).each do |(_a, l1, w1, x1, y1), (_b, l2, w2, x2, y2)|
        apart = x1 + l1 + kerf <= x2 + tol || x2 + l2 + kerf <= x1 + tol ||
                y1 + w1 + kerf <= y2 + tol || y2 + w2 + kerf <= y1 + tol
        NxTest.assert(apart, "dielce #{l1}x#{w1}@(#{x1},#{y1}) a #{l2}x#{w2}@(#{x2},#{y2}) sa prekryvaju alebo chyba prerez")
      end
    end
  end

  # Deterministická zmes riadkov pre vlastnosti (bez náhody — pevné rozmery).
  def mix
    [
      row('names' => ['A'], 'length' => 720.0, 'width' => 560.0, 'quantity' => 7),
      row('names' => ['B'], 'length' => 560.0, 'width' => 720.0, 'quantity' => 3),
      row('names' => ['C'], 'length' => 1200.0, 'width' => 560.0, 'quantity' => 4),
      row('names' => ['D'], 'length' => 300.0, 'width' => 280.0, 'quantity' => 11),
      row('names' => ['E'], 'length' => 2000.0, 'width' => 600.0, 'quantity' => 2, 'grain_direction' => 'none'),
      row('names' => ['F'], 'length' => 450.0, 'width' => 900.0, 'quantity' => 5, 'grain_direction' => 'width'),
      row('names' => ['G'], 'length' => 1200.0, 'width' => 560.0, 'quantity' => 2,
          'edges' => { 'L1' => 'ABS1', 'L2' => nil, 'W1' => nil, 'W2' => nil }),
      row('names' => ['H'], 'length' => 600.0, 'width' => 400.0, 'quantity' => 3, 'material_id' => 'DTD36',
          'thickness' => 36.0, 'material_source' => { 'material_id' => 'DTD18', 'multiplier' => 2 }),
      row('names' => ['P'], 'length' => 2400.0, 'width' => 600.0, 'quantity' => 2, 'material_id' => 'PD38',
          'thickness' => 38.0)
    ]
  end
end

# --- fits_rect? (desatinné vstupy, tolerancia, otáčanie) ---------------------

NxTest.test('NP-1 fits_rect?: tolerancia 0,1 mm na oboch osiach') do
  sl = NxSL.sl
  u = [2780.0, 2050.0]
  NxTest.assert(sl.fits_rect?({ 'l' => 2780.0, 'w' => 2050.0, 'usable' => u }), 'presne na plochu')
  NxTest.assert(sl.fits_rect?({ 'l' => 2780.05, 'w' => 2050.05, 'usable' => u }), 'v tolerancii na oboch osiach')
  NxTest.refute(sl.fits_rect?({ 'l' => 2780.2, 'w' => 100.0, 'usable' => u }), 'dlzka nad toleranciou')
  NxTest.refute(sl.fits_rect?({ 'l' => 100.0, 'w' => 2050.2, 'usable' => u }), 'sirka nad toleranciou')
end

NxTest.test('NP-1 fits_rect?: allow_rotation skusa vymenu l<->w, bez neho nie') do
  sl = NxSL.sl
  u = [2780.0, 2050.0]
  tall = { 'l' => 2000.0, 'w' => 2500.0, 'usable' => u }
  NxTest.refute(sl.fits_rect?(tall, allow_rotation: false), 'bez otocenia sa nezmesti')
  NxTest.assert(sl.fits_rect?(tall, allow_rotation: true), 'otoceny sa zmesti')
  huge = { 'l' => 2900.0, 'w' => 2100.0, 'usable' => u }
  NxTest.refute(sl.fits_rect?(huge, allow_rotation: false), 'nadrozmer bez otocenia')
  NxTest.refute(sl.fits_rect?(huge, allow_rotation: true), 'nadrozmer ani otoceny')
end

NxTest.test('NP-1 fits_rect?: nepouzitelna plocha a chybny rect = false, nikdy vynimka') do
  sl = NxSL.sl
  NxTest.refute(sl.fits_rect?({ 'l' => 1.0, 'w' => 1.0, 'usable' => [600.0, -130.0] }), 'zaporna plocha')
  NxTest.refute(sl.fits_rect?({ 'l' => 1.0, 'w' => 1.0, 'usable' => [0.05, 100.0] }), 'plocha v tolerancii nuly')
  NxTest.refute(sl.fits_rect?(nil), 'nil')
  NxTest.refute(sl.fits_rect?({ 'l' => Float::NAN, 'w' => 1.0, 'usable' => [10.0, 10.0] }), 'NaN')
  NxTest.refute(sl.fits_rect?({ 'l' => 1.0, 'w' => 1.0, 'usable' => nil }), 'bez plochy')
end

NxTest.test('NP-1 purchase_rect + fits_rect?: dielec bez smeru 2000x2500 — plan needs_rotation, Kontrola ho otoci') do
  rows = [NxSL.row('length' => 2000.0, 'width' => 2500.0, 'grain_direction' => 'none')]
  m = NxSL.mat(NxSL.compute(rows), 'DTD18')
  NxTest.assert_equal([[0, 1, 'needs_rotation']], m['unplaced'])
  NxTest.assert_equal(0, m['sheets'])
  NxTest.assert_equal(false, m['upper_bound'])
  rect = NxSL.sl.purchase_rect(rows[0], sheets: NxSL::SHEETS, edge_thicknesses: NxSL::EDGES)
  NxTest.assert(rect['ok'], 'priprava ok')
  NxTest.assert_equal('none', rect['grain'])
  NxTest.refute(NxSL.sl.fits_rect?(rect, allow_rotation: false), 'plan neotaca')
  NxTest.assert(NxSL.sl.fits_rect?(rect, allow_rotation: NxSL.sl.rotation_allowed?(rect['grain'])),
                'Kontrola otoci dielec bez smeru')
end

NxTest.test('NP-1 rotation_allowed?: Kontrola otaca vsetko okrem length/width (ako fits_on_sheet?)') do
  sl = NxSL.sl
  NxTest.assert_equal([false, false, true, true, true, true],
                      ['length', 'width', 'none', '', nil, 'diagonal'].map { |g| sl.rotation_allowed?(g) })
  # prázdny smer: plán dielec neotočí, ale Kontrola by ho otočila -> needs_rotation, nie oversize
  m = NxSL.mat(NxSL.compute([NxSL.row('length' => 2000.0, 'width' => 2500.0, 'grain_direction' => '')]), 'DTD18')
  NxTest.assert_equal([[0, 1, 'needs_rotation']], m['unplaced'])
end

NxTest.test('NP-1 purchase_rect: geometria aj pri odmietnuti, ktore nesuvisi s rozmermi (pre Kontrolu NP-2)') do
  sl = NxSL.sl
  prep = ->(over) { sl.purchase_rect(NxSL.row(over), sheets: NxSL::SHEETS, edge_thicknesses: NxSL::EDGES) }
  geo = %w[ok reason material_id plan_material_id l w usable trim grain]
  abs = prep.call('length' => 2900.0, 'width' => 2100.0, 'grain_direction' => 'none',
                  'edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal([false, 'vepo', 'DTD18', 'DTD18', 2900, 2100, [2780.0, 2050.0], 10.0, 'none'], abs.values_at(*geo))
  NxTest.assert_equal('neznáma ABS NEZNAMA', abs['detail'])
  NxTest.refute(sl.fits_rect?(abs, allow_rotation: true), 'Kontrola vyhodnoti nadrozmer aj pri chybe ABS')
  # orientacia width aj pri chybnej hrubke (VEPO) — ta ista jedina vymena
  thk = prep.call('length' => 400.4, 'width' => 900.5, 'thickness' => 0.0, 'grain_direction' => 'width')
  NxTest.assert_equal([false, 'vepo', 901, 400], thk.values_at('ok', 'reason', 'l', 'w'))
  conf = prep.call('length' => 1380.0, 'width' => 2050.0, 'thickness' => 36.0)
  NxTest.assert_equal([false, 'thickness_conflict', 'DTD18', 1380, 2050], conf.values_at('ok', 'reason', 'material_id', 'l', 'w'))
  NxTest.assert(sl.fits_rect?(conf), 'konfliktny dielec sa na platnu zmesti')
  # duplak bez vazby: vrstva BEZ pridavku na materiali riadku; plan ho pripise zdroju
  link = prep.call('length' => 1380.0, 'width' => 2030.0, 'material_id' => 'DTD36', 'thickness' => 36.0)
  NxTest.assert_equal([false, 'duplak_link_missing', 'DTD36', 'DTD18', 1380, 2030, [2780.0, 2050.0]],
                      link.values_at('ok', 'reason', 'material_id', 'plan_material_id', 'l', 'w', 'usable'))
  # duplak s vazbou a chybou ABS: geometria vrstvy S pridavkom na zdroji (ako pri ok)
  dup = prep.call('length' => 600.0, 'width' => 400.0, 'material_id' => 'DTD36', 'thickness' => 36.0,
                  'material_source' => { 'material_id' => 'DTD18', 'multiplier' => 2 },
                  'edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal([false, 'vepo', 'DTD18', 620.0, 420.0], dup.values_at('ok', 'reason', 'material_id', 'l', 'w'))
  NxTest.refute(dup.key?('count'), 'pocet obdlznikov len pri ok')
end

NxTest.test('NP-1 purchase_rect: bez geometrie pri invalid_row, zero_after_rounding, nekladnom rozmere a bez materialu') do
  sl = NxSL.sl
  prep = ->(r) { sl.purchase_rect(r, sheets: NxSL::SHEETS, edge_thicknesses: NxSL::EDGES) }
  cases = { 'invalid_row' => NxSL.row('length' => Float::NAN, 'key' => nil),
            'zero_after_rounding' => NxSL.row('length' => 0.2),
            'vepo nekladna' => NxSL.row('width' => -10.0),
            'vepo bez materialu' => NxSL.row('material_id' => '') }
  cases.each do |name, r|
    out = prep.call(r)
    NxTest.assert_equal(false, out['ok'], name)
    NxTest.refute(out.key?('l') || out.key?('usable'), "#{name}: geometria nema byt")
  end
  NxTest.assert_equal([nil, nil], prep.call(NxSL.row('material_id' => '')).values_at('material_id', 'plan_material_id'))
  NxTest.assert_equal('invalid_params',
                      sl.purchase_rect(NxSL.row, sheets: NxSL::SHEETS, edge_thicknesses: NxSL::EDGES,
                                                 params: { 'kerf' => -1 })['reason'])
end

NxTest.test('NP-1 unplaced: 2900x2100 je oversize aj bez smeru; 2000x2500 so smerom je oversize') do
  rows = [NxSL.row('names' => ['X'], 'length' => 2900.0, 'width' => 2100.0, 'grain_direction' => 'none'),
          NxSL.row('names' => ['Y'], 'length' => 2000.0, 'width' => 2500.0, 'grain_direction' => 'length')]
  m = NxSL.mat(NxSL.compute(rows), 'DTD18')
  reasons = m['unplaced'].map { |idx, _n, why| [m['rows'][idx]['names'], why] }.sort
  NxTest.assert_equal([[['X'], 'oversize'], [['Y'], 'oversize']], reasons)
end

# --- compute: presné očakávané rozloženia (golden) ---------------------------

NxTest.test('NP-1 golden (a): 9 x 720x560 na DTD 2800x2070, orez 10, prerez 5 = 1 platna, pasy po 3') do
  m = NxSL.mat(NxSL.compute([NxSL.row('quantity' => 9)]), 'DTD18')
  NxTest.assert_equal(1, m['sheets'])
  NxTest.assert_equal([2780.0, 2050.0], m['usable'])
  NxTest.assert_equal(10.0, m['trim'])
  want = [0.0, 565.0, 1130.0].flat_map { |y| [0.0, 725.0, 1450.0].map { |x| [1, 720.0, 560.0, x, y] } }
  NxTest.assert_equal(want, NxSL.placed(m))
  NxTest.assert_equal([[0.0, 560.0], [565.0, 560.0], [1130.0, 560.0]], m['layouts'][0]['strips'])
  NxTest.assert_equal(true, m['upper_bound'])
  NxTest.assert_equal(9, m['placed_count'])
  NxTest.assert_close(62.6, m['utilization'], 0.05)
  m10 = NxSL.mat(NxSL.compute([NxSL.row('quantity' => 10)]), 'DTD18')
  NxTest.assert_equal(2, m10['sheets'], '10. kus = druha platna')
  NxTest.assert_equal([2, 720.0, 560.0, 0.0, 0.0], NxSL.placed(m10).last)
end

NxTest.test('NP-1 golden (b): hranica po zaokruhleni — 2780x2050 sa zmesti, 2781 nie, 2780,4 -> 2780 ano') do
  ok = NxSL.mat(NxSL.compute([NxSL.row('length' => 2780.0, 'width' => 2050.0)]), 'DTD18')
  NxTest.assert_equal(1, ok['sheets'])
  NxTest.assert_equal(true, ok['upper_bound'])
  over = NxSL.mat(NxSL.compute([NxSL.row('length' => 2781.0, 'width' => 100.0)]), 'DTD18')
  NxTest.assert_equal([[0, 1, 'oversize']], over['unplaced'])
  NxTest.assert_equal(false, over['upper_bound'])
  # poradie: zaokrúhlenie (ako VEPO) -> kontrola; 2780,4 ide do VEPO ako 2780
  rnd = NxSL.mat(NxSL.compute([NxSL.row('length' => 2780.4, 'width' => 100.0)]), 'DTD18')
  NxTest.assert_equal(2780, rnd['rows'][0]['l'])
  NxTest.assert_equal(1, rnd['sheets'])
  NxTest.assert(rnd['unplaced'].empty?, '2780,4 sa po zaokruhleni zmesti')
end

NxTest.test('NP-1 golden (c): l1 + 5 + l2 = 2780 v jednom pase, o 1 mm viac = novy pas') do
  one = NxSL.mat(NxSL.compute([NxSL.row('names' => ['A'], 'length' => 1500.0, 'width' => 500.0),
                                NxSL.row('names' => ['B'], 'length' => 1275.0, 'width' => 500.0)]), 'DTD18')
  NxTest.assert_equal([[1, 1500, 500, 0.0, 0.0], [1, 1275, 500, 1505.0, 0.0]], NxSL.placed(one))
  two = NxSL.mat(NxSL.compute([NxSL.row('names' => ['A'], 'length' => 1500.0, 'width' => 500.0),
                                NxSL.row('names' => ['B'], 'length' => 1276.0, 'width' => 500.0)]), 'DTD18')
  NxTest.assert_equal([[1, 1500, 500, 0.0, 0.0], [1, 1276, 500, 0.0, 505.0]], NxSL.placed(two))
end

NxTest.test('NP-1 golden (d): duplak 600x400 x2, nasobok 2 = 4 obdlzniky 620x420 zdroja') do
  r = NxSL.compute([NxSL.row('length' => 600.0, 'width' => 400.0, 'quantity' => 2, 'material_id' => 'DTD36',
                             'thickness' => 36.0,
                             'material_source' => { 'material_id' => 'DTD18', 'multiplier' => 2 })])
  NxTest.assert_equal(['DTD18'], r['materials'].map { |m| m['material_id'] }, 'duplakovy material v plane nie je')
  m = NxSL.mat(r, 'DTD18')
  NxTest.assert_equal(4, m['doubled_pieces'])
  NxTest.assert_equal(1, m['rows'].length)
  NxTest.assert_equal([620.0, 420.0, 4, true], m['rows'][0].values_at('l', 'w', 'count', 'doubled'))
  NxTest.assert_equal([[1, 620.0, 420.0, 0.0, 0.0], [1, 620.0, 420.0, 625.0, 0.0],
                       [1, 620.0, 420.0, 1250.0, 0.0], [1, 620.0, 420.0, 1875.0, 0.0]], NxSL.placed(m))
  NxTest.assert_equal(true, m['upper_bound'])
end

NxTest.test('NP-1 golden (e): pracovna doska 4100x600 bez orezu — 2400x600 sa zmesti') do
  m = NxSL.mat(NxSL.compute([NxSL.row('length' => 2400.0, 'width' => 600.0, 'material_id' => 'PD38',
                                      'thickness' => 38.0)]), 'PD38')
  NxTest.assert_equal(0.0, m['trim'])
  NxTest.assert_equal([4100.0, 600.0], m['usable'])
  NxTest.assert_equal([[1, 2400, 600, 0.0, 0.0]], NxSL.placed(m))
  NxTest.assert_equal(true, m['upper_bound'])
end

NxTest.test('NP-1 golden (f): first-fit — pas aj novy pas na PRVEJ platni, kde je miesto') do
  rows = [NxSL.row('names' => ['A'], 'length' => 2000.0, 'width' => 1500.0),
          NxSL.row('names' => ['B'], 'length' => 2780.0, 'width' => 1000.0),
          NxSL.row('names' => ['D'], 'length' => 2780.0, 'width' => 500.0),
          NxSL.row('names' => ['C'], 'length' => 700.0, 'width' => 400.0)]
  m = NxSL.mat(NxSL.compute(rows), 'DTD18')
  NxTest.assert_equal(2, m['sheets'])
  got = NxSL.placed(m).sort
  want = [[1, 700, 400, 2005.0, 0.0], [1, 2000, 1500, 0.0, 0.0], [1, 2780, 500, 0.0, 1505.0],
          [2, 2780, 1000, 0.0, 0.0]]
  NxTest.assert_equal(want, got)
end

NxTest.test('NP-1 golden (g): najvacsi zvysok nad nizsim dielcom v pase — 2600 x 1895 (audit F9)') do
  rows = [NxSL.row('names' => ['V'], 'length' => 100.0, 'width' => 2000.0),
          NxSL.row('names' => ['N'], 'length' => 2600.0, 'width' => 100.0)]
  m = NxSL.mat(NxSL.compute(rows), 'DTD18')
  NxTest.assert_equal(1, m['sheets'])
  NxTest.assert_equal([[1, 100, 2000, 0.0, 0.0], [1, 2600, 100, 105.0, 0.0]], NxSL.placed(m))
  NxTest.assert_equal([105.0, 105.0, 2600.0, 1895.0], m['layouts'][0]['offcut'])
end

NxTest.test('NP-1 zvysok: spodok platne a koniec pasu su kandidati; plna platna = nil') do
  bottom = NxSL.mat(NxSL.compute([NxSL.row('length' => 2780.0, 'width' => 500.0)]), 'DTD18')
  NxTest.assert_equal([0.0, 505.0, 2780.0, 1545.0], bottom['layouts'][0]['offcut'])
  tail = NxSL.mat(NxSL.compute([NxSL.row('length' => 500.0, 'width' => 2050.0)]), 'DTD18')
  NxTest.assert_equal([505.0, 0.0, 2275.0, 2050.0], tail['layouts'][0]['offcut'])
  full = NxSL.mat(NxSL.compute([NxSL.row('length' => 2780.0, 'width' => 2050.0)]), 'DTD18')
  NxTest.assert_equal(nil, full['layouts'][0]['offcut'])
end

NxTest.test('NP-1 radenie: w zostupne, l zostupne, potom kanonicky text riadku a n') do
  e1 = { 'L1' => 'ABS1', 'L2' => nil, 'W1' => nil, 'W2' => nil }
  rows = [NxSL.row('names' => ['L300'], 'length' => 300.0, 'width' => 500.0),
          NxSL.row('names' => ['L1000'], 'length' => 1000.0, 'width' => 500.0),
          NxSL.row('names' => ['L700'], 'length' => 700.0, 'width' => 500.0),
          NxSL.row('names' => ['W600'], 'length' => 100.0, 'width' => 600.0),
          NxSL.row('names' => ['HRANA'], 'length' => 200.0, 'width' => 500.0, 'edges' => e1),
          NxSL.row('names' => ['HOLA'], 'length' => 200.0, 'width' => 500.0, 'quantity' => 2)]
  m = NxSL.mat(NxSL.compute(rows), 'DTD18')
  order = m['layouts'].flat_map { |s| s['placements'].map { |idx, n, _x, _y| [m['rows'][idx]['names'].first, n] } }
  # pri zhode l a w rozhoduje JSON.generate(key): hrany "" < "ABS1", teda HOLA pred HRANA
  NxTest.assert_equal([['W600', 1], ['L1000', 1], ['L700', 1], ['L300', 1], ['HOLA', 1], ['HOLA', 2],
                       ['HRANA', 1]], order)
end

# --- compute: vlastnosti ----------------------------------------------------

NxTest.test('NP-1 vlastnost: vysledok nezavisi od poradia vstupu (permutacie)') do
  base = JSON.generate(NxSL.compute(NxSL.mix))
  rng = Random.new(20_260_928)
  6.times do |i|
    shuffled = NxSL.mix.shuffle(random: rng)
    NxTest.assert_equal(base, JSON.generate(NxSL.compute(shuffled)), "permutacia #{i}")
  end
  NxTest.assert_equal(base, JSON.generate(NxSL.compute(NxSL.mix.reverse)), 'obratene poradie')
end

NxTest.test('NP-1 vlastnost: dolna hranica z plochy, sheets <= placed_count, geometria bez prekryvu') do
  tol = Noxun::Engine::Validation::DIM_TOL
  res = NxSL.compute(NxSL.mix)
  res['materials'].each do |m|
    lu, wu = m['usable']
    area = m['rows'].each_with_index.sum do |r, idx|
      m['layouts'].sum { |s| s['placements'].count { |p| p[0] == idx } } * r['l'] * r['w']
    end
    lower = (area / ((lu + tol) * (wu + tol))).ceil
    NxTest.assert(m['sheets'] >= lower, "#{m['material_id']}: #{m['sheets']} platni < dolna hranica #{lower}")
    NxTest.assert(m['sheets'] <= m['placed_count'], "#{m['material_id']}: viac platni nez dielcov")
    NxSL.assert_geometry(m, 5.0)
  end
end

NxTest.test('NP-1 vlastnost: geometria pri inom prereze a velkej zakazke (prerez 3,2)') do
  rows = NxSL.mix.map { |r| r.merge('quantity' => r['quantity'] * 4) }
  res = NxSL.compute(rows, params: { 'kerf' => 3.2 })
  res['materials'].each { |m| NxSL.assert_geometry(m, 3.2) }
  NxTest.assert_equal(3.2, res['params']['kerf'])
end

NxTest.test('NP-1 vlastnost: width sa prehodi raz (ako VEPO), none ani length sa neotacaju') do
  rows = [NxSL.row('names' => ['W'], 'length' => 400.0, 'width' => 900.0, 'grain_direction' => 'width'),
          NxSL.row('names' => ['N'], 'length' => 401.0, 'width' => 900.0, 'grain_direction' => 'none'),
          NxSL.row('names' => ['L'], 'length' => 402.0, 'width' => 900.0, 'grain_direction' => 'length')]
  m = NxSL.mat(NxSL.compute(rows), 'DTD18')
  dims = m['rows'].map { |r| [r['names'].first, r['l'], r['w']] }.sort
  NxTest.assert_equal([['L', 402, 900], ['N', 401, 900], ['W', 900, 400]], dims)
end

NxTest.test('NP-1 vlastnost: orez bez pouzitelnej plochy = no_usable_area, 0 platni, bez vyuzitia') do
  r = NxSL.compute([NxSL.row('quantity' => 2)], params: { 'trim' => 1100.0 })
  m = NxSL.mat(r, 'DTD18')
  NxTest.assert_equal([[0, 1, 'no_usable_area'], [0, 2, 'no_usable_area']], m['unplaced'])
  NxTest.assert_equal(0, m['sheets'])
  NxTest.refute(m.key?('utilization'), 'pri 0 platniach vyuzitie chyba')
  NxTest.assert_equal(false, m['upper_bound'])
end

NxTest.test('NP-1 vlastnost: neplatne parametre = invalid_params, ziadne rozlozenie, bez vynimky') do
  [{ 'kerf' => -1.0 }, { 'trim' => 'abc' }, { 'dup_allowance' => Float::NAN }, { kerf: Float::INFINITY },
   { 'kerf' => true }, 'nie hash'].each do |bad|
    r = NxSL.compute([NxSL.row('quantity' => 3)], params: bad)
    m = NxSL.mat(r, 'DTD18')
    NxTest.assert_equal(true, m['invalid_params'], "params #{bad.inspect}")
    NxTest.assert_equal(0, m['sheets'])
    NxTest.assert(m['layouts'].empty? && m['unplaced'].empty?, 'ziadne rozlozenie')
    NxTest.refute(m.key?('utilization'))
    NxTest.assert_equal(false, m['upper_bound'])
    NxTest.refute(r['invalid_params'].empty?, 'zoznam neplatnych parametrov')
  end
  ok = NxSL.compute([NxSL.row], params: { kerf: 0, 'trim' => 0.0, 'dup_allowance' => nil })
  NxTest.assert_equal({ 'kerf' => 0.0, 'trim' => 0.0, 'dup_allowance' => 10.0 }, ok['params'])
  NxTest.assert_equal([], ok['invalid_params'])
  NxTest.assert_equal(true, NxSL.mat(ok, 'DTD18')['upper_bound'])
end

NxTest.test('NP-1 vlastnost: UNI a fallback formatu = rozlozenie ano, horna hranica nie') do
  r = NxSL.compute([NxSL.row('material_id' => 'UNI18'), NxSL.row('material_id' => 'NOFMT'),
                    NxSL.row('material_id' => 'MISSING')])
  uni = NxSL.mat(r, 'UNI18')
  NxTest.assert_equal([true, false, 1, false], uni.values_at('uni', 'fallback', 'sheets', 'upper_bound'))
  fb = NxSL.mat(r, 'NOFMT')
  NxTest.assert_equal([false, true, [2800.0, 2070.0], 1, false],
                      fb.values_at('uni', 'fallback', 'sheet_size', 'sheets', 'upper_bound'))
  miss = NxSL.mat(r, 'MISSING')
  NxTest.assert_equal([true, 10.0, false], miss.values_at('fallback', 'trim', 'upper_bound'))
end

NxTest.test('NP-1 orez podla typu: PD/KOMPAKT/ZASTENA bez orezu, DTDL/MDF/HDF/iny/neznamy s orezom') do
  ids = %w[DTD18 MDF19 HDF3 PD38 KOMP12 ZAST10 INY18 MISSING]
  rows = ids.map do |id|
    NxSL.row('material_id' => id, 'length' => 300.0, 'width' => 200.0,
             'thickness' => (NxSL::SHEETS[id] || {})['thickness'] || 18.0)
  end
  r = NxSL.compute(rows)
  trims = ids.map { |id| [id, NxSL.mat(r, id)['trim']] }
  NxTest.assert_equal([['DTD18', 10.0], ['MDF19', 10.0], ['HDF3', 10.0], ['PD38', 0.0], ['KOMP12', 0.0],
                       ['ZAST10', 0.0], ['INY18', 10.0], ['MISSING', 10.0]], trims)
  NxTest.assert_equal(%w[HDF3 DTD18 INY18 KOMP12 MDF19 MISSING PD38 ZAST10].sort,
                      r['materials'].map { |m| m['material_id'] }, 'poradie materialov podla material_id')
end

# --- neúplnosť a ochrana vstupu -----------------------------------------------

NxTest.test('NP-1 neuplnost: vyradene riadky (neznama ABS, hrubka, bez materialu) ako vo VEPO') do
  rows = [NxSL.row('names' => ['OK']),
          NxSL.row('names' => ['ABS'], 'edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil }),
          NxSL.row('names' => ['HR'], 'thickness' => 0.0),
          NxSL.row('names' => ['BEZ'], 'material_id' => '')]
  r = NxSL.compute(rows)
  m = NxSL.mat(r, 'DTD18')
  NxTest.assert_equal(2, m['rejected_rows'])
  NxTest.assert_equal([{ 'reason' => 'vepo', 'detail' => 'chybná hrúbka 0.0', 'names' => ['HR'] },
                       { 'reason' => 'vepo', 'detail' => 'neznáma ABS NEZNAMA', 'names' => ['ABS'] }],
                      NxSL.core(m['rejected']))
  # NP-3 (B2): vyradený riadok nesie NATÍVNY kľúč (oko v červenom zozname)
  NxTest.assert_equal(rows[2]['key'], m['rejected'][0]['key'])
  NxTest.assert_equal('DTD18', m['rejected'][0]['row_material_id'])
  NxTest.assert_equal(1, r['rejected_without_material'])
  NxTest.assert_equal([{ 'reason' => 'vepo', 'detail' => 'chýba materiál', 'names' => ['BEZ'] }],
                      NxSL.core(r['rejected_without_material_rows']))
  NxTest.assert_equal(rows[3]['key'], r['rejected_without_material_rows'][0]['key'])
  NxTest.assert_equal(1, m['sheets'], 'zdravy riadok sa rozlozi')
  NxTest.assert_equal(false, m['upper_bound'])
end

NxTest.test('NP-1 neuplnost: zdravy riadok + chybny s poctom 0 = rejected_rows 1, bez hornej hranice (F6)') do
  m = NxSL.mat(NxSL.compute([NxSL.row('names' => ['OK']), NxSL.row('names' => ['NULA'], 'quantity' => 0),
                             NxSL.row('names' => ['ZAP'], 'quantity' => -3)]), 'DTD18')
  NxTest.assert_equal(2, m['rejected_rows'])
  NxTest.assert_equal(%w[chybný\ počet\ kusov chybný\ počet\ kusov], m['rejected'].map { |e| e['detail'] })
  NxTest.assert_equal(false, m['upper_bound'])
  m1 = NxSL.mat(NxSL.compute([NxSL.row('names' => ['OK']), NxSL.row('names' => ['NULA'], 'quantity' => 0)]), 'DTD18')
  NxTest.assert_equal(1, m1['rejected_rows'])
  NxTest.assert_equal(false, m1['upper_bound'])
end

NxTest.test('NP-1 ochrana vstupu: nie Hash, NaN/nekonecno, zle hrany = invalid_row; 0,1 mm = zero_after_rounding') do
  rows = ['retazec', nil, [1, 2], 42,
          NxSL.row('names' => ['NAN'], 'length' => Float::NAN, 'key' => nil),
          NxSL.row('names' => ['INF'], 'thickness' => Float::INFINITY, 'key' => nil),
          NxSL.row('names' => ['WINF'], 'width' => -Float::INFINITY, 'key' => nil),
          NxSL.row('names' => ['HRANY'], 'edges' => []),
          NxSL.row('names' => ['OBJ'], 'length' => [1], 'key' => nil),
          NxSL.row('names' => ['QNAN'], 'quantity' => Float::NAN, 'key' => nil),
          NxSL.row('names' => ['MALY'], 'length' => 0.1),
          NxSL.row('names' => ['OK'])]
  r = NxSL.compute(rows)
  NxTest.assert_equal(4, r['rejected_without_material'])
  NxTest.assert(r['rejected_without_material_rows'].all? { |e| e['reason'] == 'invalid_row' })
  m = NxSL.mat(r, 'DTD18')
  got = m['rejected'].map { |e| [e['names'].first, e['reason']] }.sort
  NxTest.assert_equal([%w[HRANY invalid_row], %w[INF invalid_row], %w[MALY zero_after_rounding],
                       %w[NAN invalid_row], %w[OBJ invalid_row], %w[QNAN invalid_row], %w[WINF invalid_row]], got)
  NxTest.assert_equal(7, m['rejected_rows'])
  NxTest.assert_equal(1, m['placed_count'])
  NxTest.assert_equal(false, m['upper_bound'])
  NxTest.assert_equal({ 'materials' => [] }, NxSL.compute(nil).slice('materials'))
end

NxTest.test('NP-1 ochrana vstupu: VEPO dlzku 0,1 dnes vyda ako 0 mm — plan ju vyradi, VEPO sa nemeni') do
  r = NxSL.row('length' => 0.1)
  prep = Noxun::Engine::VepoExport.prepare_row(r, NxSL::EDGES)
  NxTest.assert_equal([true, [0, 560]], [prep['ok'], prep['dims']])
  rect = NxSL.sl.purchase_rect(r, sheets: NxSL::SHEETS, edge_thicknesses: NxSL::EDGES)
  NxTest.assert_equal([false, 'zero_after_rounding', 'DTD18'], rect.values_at('ok', 'reason', 'material_id'))
end

NxTest.test('NP-1 hrubka vs. nakupny material: 18 a 36 mm pri jednom material_id = thickness_conflict (B1)') do
  rows = [NxSL.row('names' => ['T18'], 'length' => 1380.0, 'width' => 2050.0),
          NxSL.row('names' => ['T36'], 'length' => 1380.0, 'width' => 2050.0, 'thickness' => 36.0)]
  m = NxSL.mat(NxSL.compute(rows), 'DTD18')
  NxTest.assert_equal(true, m['thickness_conflict'])
  NxTest.assert_equal([{ 'reason' => 'thickness_conflict', 'detail' => nil, 'names' => ['T36'] }],
                      NxSL.core(m['conflicts']))
  NxTest.assert_equal([rows[1]['key'], 'DTD18'], m['conflicts'][0].values_at('key', 'row_material_id'))
  NxTest.assert_equal(1, m['placed_count'], 'konfliktny riadok sa nerozklada')
  NxTest.assert_equal(0, m['rejected_rows'])
  NxTest.assert_equal(false, m['upper_bound'])
  # pasma obchodnej hrubky: 19 mm na zazname 18 = ta ista platna; zaznam bez hrubky = bez kontroly
  ok = NxSL.mat(NxSL.compute([NxSL.row('thickness' => 19.0)]), 'DTD18')
  NxTest.assert_equal([false, true], ok.values_at('thickness_conflict', 'upper_bound'))
end

NxTest.test('NP-1 jednotna hrubka aj bez hrubky v katalogu: 18 a 36 pri jednom material_id = thickness_conflict') do
  rows = [NxSL.row('names' => ['T18'], 'material_id' => 'NOTHK'),
          NxSL.row('names' => ['T36'], 'material_id' => 'NOTHK', 'thickness' => 36.0)]
  m = NxSL.mat(NxSL.compute(rows), 'NOTHK')
  NxTest.assert_equal([true, false], m.values_at('thickness_conflict', 'upper_bound'))
  NxTest.assert_equal([{ 'reason' => 'thickness_conflict', 'detail' => 'rôzne obchodné hrúbky 18, 36', 'names' => [],
                         'key' => nil, 'row_material_id' => nil }],
                      m['conflicts'], 'konflikt materiálu nemá riadok — kľúč aj materiál riadku sú nil')
  NxTest.assert_equal(2, m['placed_count'], 'bez katalogu sa neda povedat, ktory je zly — rozlozia sa oba')
  # záznam s hrúbkou 0 = ako bez hrúbky; 18 a 19 sú to isté obchodné pásmo
  zero = NxSL.compute([NxSL.row('material_id' => 'NOTHK', 'thickness' => 18.0),
                       NxSL.row('names' => ['B'], 'material_id' => 'NOTHK', 'thickness' => 19.0)])
  NxTest.assert_equal(false, NxSL.mat(zero, 'NOTHK')['thickness_conflict'])
  sheets0 = NxSL::SHEETS.merge('NOTHK' => NxSL::SHEETS['NOTHK'].merge('thickness' => 0))
  z = NxSL.sl.compute(rows, sheets: sheets0, edge_thicknesses: NxSL::EDGES)
  NxTest.assert_equal(true, NxSL.mat(z, 'NOTHK')['thickness_conflict'])
  # vrstvy dupláku (hrúbka zdroja) sa do jednotnosti nerátajú
  dup = NxSL.compute([NxSL.row('material_id' => 'NOTHK'),
                      NxSL.row('names' => ['D'], 'material_id' => 'X36', 'thickness' => 36.0,
                               'material_source' => { 'material_id' => 'NOTHK', 'multiplier' => 2 })])
  NxTest.assert_equal([false, true], NxSL.mat(dup, 'NOTHK').values_at('thickness_conflict', 'upper_bound'))
end

NxTest.test('NP-1 bezny riadok ma rozmery v celych mm (Integer), duplak s pridavkom Float') do
  m = NxSL.mat(NxSL.compute([NxSL.row('length' => 720.4, 'width' => 559.5)]), 'DTD18')
  NxTest.assert_equal([Integer, Integer], [m['rows'][0]['l'].class, m['rows'][0]['w'].class])
  NxTest.assert_equal([720, 560], m['rows'][0].values_at('l', 'w'))
  rect = NxSL.sl.purchase_rect(NxSL.row('edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil }),
                               sheets: NxSL::SHEETS, edge_thicknesses: NxSL::EDGES)
  NxTest.assert_equal([Integer, Integer], [rect['l'].class, rect['w'].class], 'aj geometria odmietnutia')
  d = NxSL.mat(NxSL.compute([NxSL.row('material_id' => 'DTD36', 'thickness' => 36.0,
                                      'material_source' => { 'material_id' => 'DTD18', 'multiplier' => 2 })]), 'DTD18')
  NxTest.assert_equal([740.0, 580.0], d['rows'][0].values_at('l', 'w'))
end

NxTest.test('NP-1 ochrana vstupu: retazec na nekonecno a zachranna vetva ostavaju na znamom materiali') do
  inf = NxSL.row('names' => ['INFS'], 'length' => '1e400', 'key' => nil,
                 'edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  # kľúč s NaN: JSON.generate zlyhá až po prijatí riadka -> záchranná vetva
  nan_key = NxSL.row('names' => ['KEY'], 'key' => [Float::NAN])
  r = NxSL.compute([NxSL.row('names' => ['OK']), inf, nan_key])
  NxTest.assert_equal(0, r['rejected_without_material'])
  m = NxSL.mat(r, 'DTD18')
  NxTest.assert_equal([%w[INFS invalid_row], %w[KEY invalid_row]],
                      m['rejected'].map { |e| [e['names'].first, e['reason']] }.sort)
  NxTest.assert_equal([2, false], m.values_at('rejected_rows', 'upper_bound'))
end

NxTest.test('NP-1 duplak bez vazby v riadku: duplak_link_missing na zdroji, ziadne domyslenie (B2)') do
  r = NxSL.compute([NxSL.row('names' => ['DUP'], 'length' => 1380.0, 'width' => 2030.0, 'material_id' => 'DTD36',
                             'thickness' => 36.0)])
  NxTest.assert_equal(['DTD18'], r['materials'].map { |m| m['material_id'] })
  m = NxSL.mat(r, 'DTD18')
  NxTest.assert_equal(true, m['duplak_link_missing'])
  NxTest.assert_equal([0, 0, false], m.values_at('sheets', 'placed_count', 'upper_bound'))
  NxTest.assert_equal([{ 'reason' => 'duplak_link_missing', 'detail' => nil, 'names' => ['DUP'] }],
                      NxSL.core(m['conflicts']))
  # NP-3 (B3): konflikt nesie MATERIÁL RIADKU (duplák) — most k riadku rozpočtu
  NxTest.assert_equal('DTD36', m['conflicts'][0]['row_material_id'])
  NxTest.assert(m['conflicts'][0]['key'].is_a?(Array), 'natívny kľúč riadku (B2)')
  # s vazbou: 2 vrstvy 1400 x 2050 (s pridavkom) = 2 zdrojove platne
  linked = NxSL.mat(NxSL.compute([NxSL.row('length' => 1380.0, 'width' => 2030.0, 'material_id' => 'DTD36',
                                           'thickness' => 36.0,
                                           'material_source' => { 'material_id' => 'DTD18', 'multiplier' => 2 })]),
                    'DTD18')
  NxTest.assert_equal([2, 2, true], linked.values_at('sheets', 'doubled_pieces', 'upper_bound'))
end

NxTest.test('NP-1 blocked: all aj per material (aj cez duplakovy material riadku) -> bez hornej hranice (F5)') do
  rows = [NxSL.row, NxSL.row('material_id' => 'MDF19', 'thickness' => 19.0)]
  all = NxSL.compute(rows, blocked: { all: 'poškodený rozmer do nárezu' })
  all['materials'].each do |m|
    NxTest.assert_equal(['poškodený rozmer do nárezu', false, 1], m.values_at('blocked', 'upper_bound', 'sheets'))
  end
  one = NxSL.compute(rows, blocked: { 'MDF19' => 'x' })
  NxTest.assert_equal([nil, true], NxSL.mat(one, 'DTD18').values_at('blocked', 'upper_bound'))
  NxTest.assert_equal(['x', false], NxSL.mat(one, 'MDF19').values_at('blocked', 'upper_bound'))
  dup = NxSL.compute([NxSL.row('material_id' => 'DTD36', 'thickness' => 36.0,
                               'material_source' => { 'material_id' => 'DTD18', 'multiplier' => 2 })],
                     blocked: { 'DTD36' => 'duplak' })
  NxTest.assert_equal(['duplak', false], NxSL.mat(dup, 'DTD18').values_at('blocked', 'upper_bound'))
  empty = NxSL.compute(rows, blocked: { 'DTD18' => '' })
  NxTest.assert_equal('blocked', NxSL.mat(empty, 'DTD18')['blocked'])
  # kľúč „všetky" aj ako reťazec (z JSON)
  str = NxSL.compute(rows, blocked: { 'all' => 'z JSON' })
  NxTest.assert(str['materials'].all? { |m| m['blocked'] == 'z JSON' && !m['upper_bound'] }, "blocked 'all' ako retazec")
end

NxTest.test('NP-1 prepare_row: rovnake vyradenia a texty ako VepoExport.build (G3)') do
  rows = NxNp1Char.rows
  built = Noxun::Engine::VepoExport.build(rows, project: 'x', materials: {}, edge_thicknesses: NxNp1Char::EDGES)
  prep = rows.map { |r| Noxun::Engine::VepoExport.prepare_row(r, NxNp1Char::EDGES) }
  NxTest.assert_equal(built['errors'].map { |e| e['reason'] }, prep.reject { |p| p['ok'] }.map { |p| p['reason'] })
  NxTest.assert_equal(built['total_rows'], prep.count { |p| p['ok'] })
  # plán prevezme presne ten istý text dôvodu
  plan = Noxun::Engine::SheetLayout.compute(rows, sheets: {}, edge_thicknesses: NxNp1Char::EDGES)
  rejects = plan['materials'].flat_map { |m| m['rejected'] } + plan['rejected_without_material_rows']
  NxTest.assert_equal(built['errors'].map { |e| e['reason'] }.sort,
                      rejects.select { |e| e['reason'] == 'vepo' }.map { |e| e['detail'] }.sort)
  # navyše plán vyradí dĺžku 0,4 mm, ktorú VEPO vydá ako 0 mm (audit F4)
  NxTest.assert_equal([[['Polica 2'], 'zero_after_rounding']],
                      rejects.reject { |e| e['reason'] == 'vepo' }.map { |e| [e['names'], e['reason']] })
end

# --- výkon -------------------------------------------------------------------

NxTest.test('NP-1 vykon: ~2000 obdlznikov v 5 materialoch pod 1 s headless') do
  mats = %w[DTD18 MDF19 HDF3 INY18 KOMP12]
  thick = { 'DTD18' => 18.0, 'MDF19' => 19.0, 'HDF3' => 3.0, 'INY18' => 18.0, 'KOMP12' => 12.0 }
  rows = []
  mats.each_with_index do |mid, mi|
    80.times do |i|
      rows << NxSL.row('names' => ["P#{mi}-#{i}"], 'material_id' => mid, 'thickness' => thick[mid],
                       'length' => 150.0 + ((i * 37 + mi * 11) % 700), 'width' => 90.0 + ((i * 53 + mi * 7) % 420),
                       'quantity' => 5, 'grain_direction' => %w[length none width][i % 3])
    end
  end
  total = rows.sum { |r| r['quantity'] }
  NxTest.assert_equal(2000, total)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  res = NxSL.compute(rows)
  dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts format('    [NP-1 vykon] %<n>d obdlznikov, %<s>d platni, %<t>.3f s', n: total,
                                                                       s: res['materials'].sum { |m| m['sheets'] }, t: dt)
  NxTest.assert(dt < 1.0, "vypocet trval #{dt.round(3)} s (limit 1 s)")
  res['materials'].each { |m| NxSL.assert_geometry(m, 5.0) }
end

# --- načítanie ---------------------------------------------------------------

NxTest.test('NP-1: loader nacitava sheet_layout po vepo_export/sheet_estimate/validation a pred budget') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  at = ->(m) { src.index("Sketchup.require 'noxun_engine/core/#{m}'") }
  NxTest.assert(!at.call('sheet_layout').nil?, 'main.rb nenacitava core/sheet_layout')
  %w[materials vepo_export sheet_estimate validation].each do |dep|
    NxTest.assert(at.call(dep) < at.call('sheet_layout'), "#{dep} sa musi nacitat PRED sheet_layout")
  end
  NxTest.assert(at.call('sheet_layout') < at.call('budget'), 'sheet_layout sa musi nacitat PRED budget')
end
