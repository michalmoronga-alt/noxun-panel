# frozen_string_literal: true
# Testy 2A-3a: vyberove cesty ABS so strukturou (Ruby jadro, dual-mode).
#
# KONTRAKT DAVKY: zivy katalog je stale SCHEMA 1 a spravanie sa pri nom NEMENI
# — nove pravidla (schema-aware hrubky, nominalne triedy, picker abs_for_sheet,
# remap so zaznamami, pick_body_sheet structure guard, warnings plumbing) ziju
# VYHRADNE vo vetve SCHEMA 2. Jedina vedoma vynimka: AUTO_WIDTHS 22 -> 23
# GLOBALNE (audit N16 — oprava obchodneho udaju; testovane v test_abs_remap).
# Vsetko headless (APPDATA sandbox helpera).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

A3MAT = Noxun::Engine::Materials
A3STORE = Noxun::Engine::JsonFileStore

# Docasne nainstaluje CELY katalog (sheets + edges + schema marker) a po bloku
# vrati bajt-presny povodny stav. Zapis ide priamo cez JsonFileStore (obchadza
# Materials.write guardy — testy potrebuju aj stavy, ktore by write odmietol).
def a3_with_catalog(sheets, edges, schema: 2)
  path = A3MAT.path
  A3MAT.catalog # seed, aby subor existoval
  before = File.binread(path)
  A3STORE.write(path, { 'std' => A3MAT::STD, 'schema' => schema,
                        'sheets' => sheets, 'edges' => edges })
  yield
ensure
  if before
    File.binwrite(path, before)
    A3STORE.invalidate(path)
  end
end

# Doska SCHEMA 2 (group_id + struktura).
def a3_sheet(id, group, structure, extra = {})
  { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => group,
    'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length',
    'color' => [200, 200, 200], 'production_class' => 'sheet',
    'group_id' => "GRP-#{group.upcase}", 'structure' => structure.to_s }
    .reject { |_k, v| v.is_a?(String) && v.empty? }.merge(extra)
end

# Paska SCHEMA 2 (group_id + struktura + volitelne universal/width).
def a3_edge(id, group, structure, thickness, width = nil, extra = {})
  rec = { 'abs_id' => id, 'decor' => group, 'thickness' => thickness,
          'color' => [200, 200, 200], 'group_id' => "GRP-#{group.upcase}" }
  rec['structure'] = structure.to_s unless structure.to_s.empty?
  rec['width'] = width if width
  rec.merge(extra)
end

# ---------------------------------------------------------------------------
# B1: schema-aware povolene hrubky ABS
# ---------------------------------------------------------------------------

NxTest.test('2a3: supported_edge_thickness? — schema 1 presne {1;2}, schema 2 obchodne hodnoty') do
  NxTest.assert(A3MAT.supported_edge_thickness?(1.0, 1))
  NxTest.assert(A3MAT.supported_edge_thickness?(2.0, 1))
  [0.4, 0.8, 1.2, 1.5].each do |th|
    NxTest.refute(A3MAT.supported_edge_thickness?(th, 1), "schema 1 NESMIE pustit #{th}")
  end
  [0.4, 0.8, 1.0, 1.2, 1.5, 2.0].each do |th|
    NxTest.assert(A3MAT.supported_edge_thickness?(th, 2), "schema 2 musi pustit #{th}")
  end
  NxTest.refute(A3MAT.supported_edge_thickness?(3.0, 2), 'mimo whitelistu ani schema 2')
  NxTest.refute(A3MAT.supported_edge_thickness?(0.5, 2))
end

NxTest.test('2a3: edge_thickness_options_label vymenuje hodnoty podla schemy') do
  NxTest.assert_equal('1/2', A3MAT.edge_thickness_options_label(1))
  NxTest.assert_equal('0,4/0,8/1/1,2/1,5/2', A3MAT.edge_thickness_options_label(2))
end

NxTest.test('2a3: load filter NEMAZE obchodne hrubky v SCHEMA 2 katalogu (audit B1)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S18', 'G1', 'ST9')]
  edges = [a3_edge('E08', 'G1', 'ST9', 0.8, 23.0),
           a3_edge('E15', 'G1', 'ST9', 1.5, 23.0),
           a3_edge('E04', 'G1', 'ST9', 0.4, 23.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    ids = A3MAT.edges.map { |a| a['abs_id'] }
    NxTest.assert_equal(%w[E08 E15 E04], ids, 'ziadna paska sa nesmie stratit')
    NxTest.assert(File.binread(A3MAT.path).include?('"E04"'), 'subor sa neprepisal filtrom')
  end
end

NxTest.test('2a3: load filter pri SCHEMA 1 reze presne ako dnes (dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S18', 'G1', 'ST9')]
  edges = [{ 'abs_id' => 'E10', 'decor' => 'G1', 'thickness' => 1.0, 'color' => [1, 2, 3] },
           { 'abs_id' => 'E08', 'decor' => 'G1', 'thickness' => 0.8, 'color' => [1, 2, 3] }]
  a3_with_catalog(sheets, edges, schema: 1) do
    ids = A3MAT.edges.map { |a| a['abs_id'] }
    NxTest.assert_equal(%w[E10], ids, '0.8 sa pri legacy katalogu odfiltruje (dnesok)')
  end
end

NxTest.test('2a3: normalize_edge berie hrubku podla schemy katalogu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  # SCHEMA 1 (seed stav): 0.8 sa odmietne uz pri normalize (dnesok).
  NxTest.assert_equal(nil, A3MAT.normalize_edge('abs_id' => 'X', 'decor' => 'D', 'thickness' => 0.8))
  a3_with_catalog([a3_sheet('S18', 'G1', 'ST9')], [], schema: 2) do
    rec = A3MAT.normalize_edge('abs_id' => 'X', 'decor' => 'G1', 'thickness' => 0.8,
                               'group_id' => 'GRP-G1', 'structure' => 'ST9')
    NxTest.refute(rec.nil?, 'schema 2 pusti 0.8')
    NxTest.assert_equal(0.8, rec['thickness'])
    NxTest.assert_equal(nil, A3MAT.normalize_edge('abs_id' => 'X', 'decor' => 'G1', 'thickness' => 0.5),
                        '0.5 nie je obchodna hodnota')
  end
end

NxTest.test('2a3: AUTO_WIDTHS = {23; 43} (N16 — jedina vedoma vynimka z dual-mode)') do
  NxTest.assert_equal([23.0, 43.0], A3MAT::AUTO_WIDTHS)
end

# ---------------------------------------------------------------------------
# B3/N17: nominalne triedy + resolver obchodnej hrubky (ciste funkcie)
# ---------------------------------------------------------------------------

NxTest.test('2a3: edge_thickness_class — nula4/jednotka/dvojka/nil') do
  NxTest.assert_equal(:nula4, A3MAT.edge_thickness_class(0.4))
  [0.8, 1.0, 1.2].each { |t| NxTest.assert_equal(:jednotka, A3MAT.edge_thickness_class(t), t.to_s) }
  [1.5, 2.0].each { |t| NxTest.assert_equal(:dvojka, A3MAT.edge_thickness_class(t), t.to_s) }
  NxTest.assert_equal(nil, A3MAT.edge_thickness_class(3.0))
  NxTest.assert_equal(nil, A3MAT.edge_thickness_class(0.5))
end

NxTest.test('2a3: resolver — jednotka preferuje 0,8 -> 1 -> 1,2') do
  cands = [a3_edge('E12', 'G', 'ST', 1.2, 23.0), a3_edge('E10', 'G', 'ST', 1.0, 23.0),
           a3_edge('E08', 'G', 'ST', 0.8, 23.0)]
  rec, reason = A3MAT.resolve_edge_thickness(cands, :jednotka, 18.0)
  NxTest.assert_equal('E08', rec['abs_id'])
  NxTest.assert_equal(nil, reason)
  rec2, = A3MAT.resolve_edge_thickness(cands.reject { |a| a['abs_id'] == 'E08' }, :jednotka, 18.0)
  NxTest.assert_equal('E10', rec2['abs_id'], 'bez 0,8 pada na 1,0')
end

NxTest.test('2a3: resolver — dvojka 2,0 -> 1,5 s reasonom abs_15_fallback') do
  full = [a3_edge('E20', 'G', 'ST', 2.0, 23.0), a3_edge('E15', 'G', 'ST', 1.5, 23.0)]
  rec, reason = A3MAT.resolve_edge_thickness(full, :dvojka, 18.0)
  NxTest.assert_equal('E20', rec['abs_id'])
  NxTest.assert_equal(nil, reason, '2,0 je plnohodnotna dvojka — bez warningu')
  rec2, reason2 = A3MAT.resolve_edge_thickness([a3_edge('E15', 'G', 'ST', 1.5, 23.0)], :dvojka, 18.0)
  NxTest.assert_equal('E15', rec2['abs_id'])
  NxTest.assert_equal('abs_15_fallback', reason2, 'vyber 1,5 = viditelne upozornenie')
end

NxTest.test('2a3: resolver — siroka prednostna hrubka nepada, uzka NEBLOKUJE dalsiu preferenciu') do
  cands = [a3_edge('E08', 'G', 'ST', 0.8, 23.0), a3_edge('E10', 'G', 'ST', 1.0, 43.0)]
  rec, reason = A3MAT.resolve_edge_thickness(cands, :jednotka, 38.0)
  NxTest.assert_equal('E10', rec['abs_id'], '38+2=40 > 23 -> preferovana 0,8 sirkovo nevyhovuje, berie sa 1,0/43')
  NxTest.assert_equal(nil, reason)
end

NxTest.test('2a3: resolver — reason rozlisuje chybajucu triedu od chybajucej sirky') do
  NxTest.assert_equal([nil, 'abs_nominal_missing'],
                      A3MAT.resolve_edge_thickness([a3_edge('E04', 'G', 'ST', 0.4, 23.0)], :jednotka, 18.0),
                      'skupina len 0,4 — jednotka sa NIKDY nerozriesi na 0,4')
  NxTest.assert_equal([nil, 'abs_nominal_missing'],
                      A3MAT.resolve_edge_thickness([a3_edge('E15', 'G', 'ST', 1.5, 23.0)], :jednotka, 18.0),
                      '1,5 je dvojka, nie jednotka')
  cands = [a3_edge('E10', 'G', 'ST', 1.0, 23.0)]
  NxTest.assert_equal([nil, 'abs_width_missing'], A3MAT.resolve_edge_thickness(cands, :jednotka, 38.0),
                      'trieda existuje, sirka nevyhovuje')
  NxTest.assert_equal([nil, 'abs_nominal_missing'], A3MAT.resolve_edge_thickness([], :jednotka, 18.0))
  NxTest.assert_equal([nil, 'abs_nominal_missing'], A3MAT.resolve_edge_thickness(cands, :nula4, 18.0),
                      'trieda :nula4 sa nikdy nevoli automaticky')
end

NxTest.test('2a3: resolver — tie-break abs_id v ramci hrubky') do
  cands = [a3_edge('B10', 'G', 'ST', 1.0, 23.0), a3_edge('A10', 'G', 'ST', 1.0, 23.0)]
  rec, = A3MAT.resolve_edge_thickness(cands.sort_by { |a| a['abs_id'] }, :jednotka, 18.0)
  NxTest.assert_equal('A10', rec['abs_id'])
end

# ---------------------------------------------------------------------------
# B3: abs_for_sheet — hierarchia skupina -> presna struktura -> universal -> nic
# ---------------------------------------------------------------------------

# Matica bezi nad sandbox katalogom SCHEMA 2 (abs_for_sheet cita Materials.edges).
def a3_pick(sheets, edges, sheet_id, nominal, part_th)
  a3_with_catalog(sheets, edges, schema: 2) do
    return A3MAT.abs_for_sheet(A3MAT.sheet(sheet_id), nominal, part_th)
  end
end

NxTest.test('2a3: picker — skupina bez ABS = abs_structure_missing') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  out = a3_pick([a3_sheet('S1', 'G1', 'ST9')], [], 'S1', :jednotka, 18.0)
  NxTest.assert_equal([nil, 'abs_structure_missing'], out)
end

NxTest.test('2a3: picker — cudzia struktura sa NIKDY nevybera, presna vyhrava aj s horsou preferenciou') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  edges = [a3_edge('EMG08', 'G1', 'MG', 0.8, 23.0),   # cudzia struktura, lepsia preferencia
           a3_edge('EST10', 'G1', 'ST9', 1.0, 23.0)]  # presna struktura, horsia preferencia
  out = a3_pick(sheets, edges, 'S1', :jednotka, 18.0)
  NxTest.assert_equal(['EST10', nil], out, 'struktura ma prednost pred preferenciou hrubky')
end

NxTest.test('2a3: picker — presna prilis uzka, pouzitelna hrubsia tej istej struktury') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9', 'thickness' => 38.0)]
  edges = [a3_edge('E08', 'G1', 'ST9', 0.8, 23.0), a3_edge('E10', 'G1', 'ST9', 1.0, 43.0)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 38.0)
  NxTest.assert_equal(['E10', nil], out)
end

NxTest.test('2a3: picker — exact vetva vyhrava nad universal (1,2 exact > 0,8 universal)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  edges = [a3_edge('EU08', 'G1', '', 0.8, 23.0, 'universal' => true),
           a3_edge('EX12', 'G1', 'ST9', 1.2, 23.0)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 18.0)
  NxTest.assert_equal(['EX12', nil], out, 'universal je az zachranna vetva')
end

NxTest.test('2a3: picker — dve prazdne struktury NIE su zhoda; universal je jedina cesta') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', '')] # doska BEZ struktury
  plain = [a3_edge('E10', 'G1', '', 1.0, 23.0)] # paska bez struktury, BEZ universal
  out = a3_pick(sheets, plain, 'S1', :jednotka, 18.0)
  NxTest.assert_equal([nil, 'abs_structure_missing'], out, 'prazdna=neznama, nie "rovnaka"')
  uni = [a3_edge('EU10', 'G1', '', 1.0, 23.0, 'universal' => true)]
  out2 = a3_pick(sheets, uni, 'S1', :jednotka, 18.0)
  NxTest.assert_equal(['EU10', nil], out2, 'universal:true je vedome "pasuje na vsetko"')
end

NxTest.test('2a3: picker — universal s malou sirkou = nic + abs_width_missing (sirka plati aj tu)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9', 'thickness' => 38.0)]
  edges = [a3_edge('EU10', 'G1', '', 1.0, 23.0, 'universal' => true)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 38.0)
  NxTest.assert_equal([nil, 'abs_width_missing'], out)
end

NxTest.test('2a3: picker — skupina len 0,4 = abs_nominal_missing; dvojka -> 1,5 s fallback reasonom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  only04 = [a3_edge('E04', 'G1', 'ST9', 0.4, 23.0)]
  NxTest.assert_equal([nil, 'abs_nominal_missing'], a3_pick(sheets, only04, 'S1', :jednotka, 18.0))
  only15 = [a3_edge('E15', 'G1', 'ST9', 1.5, 23.0)]
  NxTest.assert_equal(['E15', 'abs_15_fallback'], a3_pick(sheets, only15, 'S1', :dvojka, 18.0))
end

NxTest.test('2a3: picker — cudzia skupina nie je kandidat (ani presna struktura)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  edges = [a3_edge('ECUDZI', 'G2', 'ST9', 1.0, 23.0)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 18.0)
  NxTest.assert_equal([nil, 'abs_structure_missing'], out)
end

NxTest.test('2a3: picker — 5981 s dvoma 23/1 roznych struktur sa nikdy nemiesa') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('SMG', '5981', 'MG'), a3_sheet('SAF', '5981', 'AF')]
  edges = [a3_edge('EMG', '5981', 'MG', 1.0, 23.0), a3_edge('EAF', '5981', 'AF', 1.0, 23.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    NxTest.assert_equal(['EMG', nil], A3MAT.abs_for_sheet(A3MAT.sheet('SMG'), :jednotka, 18.0))
    NxTest.assert_equal(['EAF', nil], A3MAT.abs_for_sheet(A3MAT.sheet('SAF'), :jednotka, 18.0))
  end
end
