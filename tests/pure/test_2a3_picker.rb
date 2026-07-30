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
