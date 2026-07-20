# frozen_string_literal: true
# Testy samostatnej dosky (V0.4.7a): BoardBuilder cista cast (normalize/validacia/
# deskriptor/config round-trip), PartKeys board prefix, BuildPlan free_panel,
# AbsRules seed-merge + free_panel default, Ids generalizacia (BRD sekvencia, dedup).
require_relative '../helper' unless defined?(NxTest)

BB = Noxun::Engine::BoardBuilder

# ---------------------------------------------------------------------------
# PartKeys — board prefix
# ---------------------------------------------------------------------------

NxTest.test('board: PartKeys.board vracia konstantny kluc a valid? ho prijme') do
  NxTest.assert_equal('board/main', Noxun::Engine::PartKeys.board)
  NxTest.assert(Noxun::Engine::PartKeys.valid?('board/main'), 'board/main ma byt platny')
  NxTest.assert(Noxun::Engine::PartKeys.valid?('cabinet/side:left'), 'stare kluce ostavaju platne')
  NxTest.assert(Noxun::Engine::PartKeys.valid?('zone:Z1/shelf:1'), 'zone kluce ostavaju platne')
  NxTest.assert(Noxun::Engine::PartKeys.valid?('front:F1/wing:left'), 'front kluce ostavaju platne')
end

NxTest.test('board: valid? odmieta prazdny board prefix a cudzie tvary') do
  NxTest.refute(Noxun::Engine::PartKeys.valid?('board/'), 'samotny prefix nie je kluc')
  NxTest.refute(Noxun::Engine::PartKeys.valid?('boardmain'), 'chyba lomka')
  NxTest.refute(Noxun::Engine::PartKeys.valid?('deck/main'), 'neznamy prefix')
end

# ---------------------------------------------------------------------------
# BuildPlan — rola free_panel + material :concrete
# ---------------------------------------------------------------------------

NxTest.test('board: BuildPlan::ROLES obsahuje free_panel') do
  NxTest.assert(Noxun::Engine::BuildPlan::ROLES.include?('free_panel'))
end

NxTest.test('board: validate_part! prijme material :concrete a odmietne cudzi symbol') do
  pd = {
    part_key: 'board/main', suffix: 'BOARD', role: 'free_panel', name: 'Doska',
    material: :concrete, box: [800.0, 600.0, 18.0], origin: [0.0, 0.0, 0.0],
    prod: { length: 800.0, width: 600.0, thickness: 18.0 }
  }
  Noxun::Engine::BuildPlan.validate_part!(pd, {})
  bad = pd.merge(material: :nahodny)
  NxTest.assert_raise(/neplatny material/) { Noxun::Engine::BuildPlan.validate_part!(bad, {}) }
end

# ---------------------------------------------------------------------------
# BoardBuilder.normalize
# ---------------------------------------------------------------------------

NxTest.test('board: normalize defaults bez vstupu (bez materialu)') do
  cfg = BB.normalize({})
  NxTest.assert_equal('free_panel', cfg[:role])
  NxTest.assert_close(800.0, cfg[:length])
  NxTest.assert_close(600.0, cfg[:width])
  NxTest.assert_close(18.0, cfg[:thickness])
  NxTest.assert_equal(1, cfg[:quantity])
  NxTest.assert_equal('Doska 800×600', cfg[:name])
  NxTest.assert_equal(nil, cfg[:material_id])
  NxTest.assert_equal('none', cfg[:grain_direction])
  # bez materialu nema dekor -> pravidlovy default nevie najst ABS variant
  NxTest.assert_equal({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }, cfg[:edges])
end

NxTest.test('board: normalize s katalogovym materialom dosadi hrubku, grain a ABS default') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cfg = BB.normalize('material_id' => 'K009_PW_DTDL_18', 'thickness' => 25.0,
                     'length' => 720.0, 'width' => 580.0)
  NxTest.assert_close(18.0, cfg[:thickness], 0.01, 'hrubka sa riadi katalogom, nie vstupom')
  NxTest.assert_equal('length', cfg[:grain_direction], 'grain default z materialu')
  NxTest.assert_equal('ABS_K009_10', cfg[:edges]['L1'], 'seed free_panel: 1 pozdlzna 1.0')
  NxTest.assert_equal(nil, cfg[:edges]['L2'])
  NxTest.assert_equal(nil, cfg[:edges]['W1'])
  NxTest.assert_equal(nil, cfg[:edges]['W2'])
end

NxTest.test('board: normalize dosadi hrubku aj pri tenkom materiali (16)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cfg = BB.normalize('material_id' => 'K009_PW_DTDL_16', 'thickness' => 18.0)
  NxTest.assert_close(16.0, cfg[:thickness])
end

NxTest.test('board: normalize clampuje rozmery a quantity') do
  cfg = BB.normalize('length' => 5.0, 'width' => 9999.0, 'thickness' => 0.2, 'quantity' => 5000)
  NxTest.assert_close(10.0, cfg[:length])
  NxTest.assert_close(3000.0, cfg[:width])
  NxTest.assert_close(1.0, cfg[:thickness])
  NxTest.assert_equal(999, cfg[:quantity])
  NxTest.assert_equal(1, BB.normalize('quantity' => 0)[:quantity])
  NxTest.assert_equal(3, BB.normalize('quantity' => '3')[:quantity])
end

NxTest.test('board: normalize berie string aj symbol kluce') do
  a = BB.normalize('length' => 500.0, 'name' => 'Blenda')
  b = BB.normalize(length: 500.0, name: 'Blenda')
  NxTest.assert_equal(a, b)
end

NxTest.test('board: neznama rola je chyba (fail-fast, ziadna ticha degradacia)') do
  NxTest.assert_raise(/Nezn.*rola dosky/) { BB.normalize('role' => 'worktop') }
  NxTest.assert_equal('free_panel', BB.normalize('role' => '')[:role])
  NxTest.assert_equal('free_panel', BB.normalize('role' => 'free_panel')[:role])
end

# ---------------------------------------------------------------------------
# BoardBuilder edges — key?-preserve (standard 7.5)
# ---------------------------------------------------------------------------

NxTest.test('board: edges hash zachova explicitny nil a chybajuci kluc NEdopla defaultom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cfg = BB.normalize('material_id' => 'K009_PW_DTDL_18',
                     'edges' => { 'L1' => 'ABS_K009_20', 'L2' => nil })
  NxTest.assert_equal('ABS_K009_20', cfg[:edges]['L1'])
  NxTest.assert_equal(nil, cfg[:edges]['L2'], 'explicitne bez ABS')
  NxTest.assert_equal(nil, cfg[:edges]['W1'], 'chybajuci kluc = bez ABS, NIE pravidlovy default')
  NxTest.assert_equal(nil, cfg[:edges]['W2'])
end

NxTest.test('board: edges akceptuje symbolove kluce a zahodi neplatne abs_id') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cfg = BB.normalize('material_id' => 'K009_PW_DTDL_18',
                     'edges' => { L1: 'ABS_K009_10', W1: 'ABS_NEEXISTUJE_99' })
  NxTest.assert_equal('ABS_K009_10', cfg[:edges]['L1'])
  NxTest.assert_equal(nil, cfg[:edges]['W1'], 'neplatne abs_id -> nil (ako korpusove overrides)')
end

NxTest.test('board: normalize vracia cerstve mapy (mutacia vystupu nezmeni dalsi vysledok)') do
  cfg1 = BB.normalize({})
  cfg1[:edges]['L1'] = 'PODVRH'
  cfg2 = BB.normalize({})
  NxTest.assert_equal(nil, cfg2[:edges]['L1'])
end

# ---------------------------------------------------------------------------
# validate_config! + descriptor
# ---------------------------------------------------------------------------

NxTest.test('board: validate_config! vyzaduje material a jeho existenciu v katalogu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_raise(/nem.*materi/i) { BB.validate_config!(BB.normalize({})) }
  cudzi = BB.normalize('material_id' => 'MIMO_KATALOGU_18')
  NxTest.assert_raise(/nie je v katal/i) { BB.validate_config!(cudzi) }
  BB.validate_config!(BB.normalize('material_id' => 'K009_PW_DTDL_18'))
end

NxTest.test('board: descriptor — golden tvar + prejde BuildPlan.validate_part!') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cfg = BB.normalize('material_id' => 'K009_PW_DTDL_18', 'length' => 720.0,
                     'width' => 580.0, 'name' => 'Krycia doska')
  pd = BB.descriptor(cfg)
  NxTest.assert_equal('board/main', pd[:part_key])
  NxTest.assert_equal('BOARD', pd[:suffix])
  NxTest.assert_equal('free_panel', pd[:role])
  NxTest.assert_equal('Krycia doska', pd[:name])
  NxTest.assert_equal(:concrete, pd[:material])
  NxTest.assert_equal([720.0, 580.0, 18.0], pd[:box])
  NxTest.assert_equal([0.0, 0.0, 0.0], pd[:origin])
  NxTest.assert_close(720.0, pd[:prod][:length])
  NxTest.assert_close(580.0, pd[:prod][:width])
  NxTest.assert_close(18.0, pd[:prod][:thickness])
  NxTest.assert_equal('sheet', pd[:production_class])
  NxTest.assert_equal(true, pd[:manufactured])
  NxTest.assert_equal(1, pd[:quantity])
end

NxTest.test('board: dve dosky s konstantnym part_key sa validuju NEZAVISLE (izolovany seen)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cfg = BB.normalize('material_id' => 'K009_PW_DTDL_18')
  BB.descriptor(cfg)
  BB.descriptor(cfg) # druhy descriptor nesmie padnut na "duplicitny part_key"
  NxTest.assert(true)
end

# ---------------------------------------------------------------------------
# board_config + JSON round-trip (Store simulacia)
# ---------------------------------------------------------------------------

NxTest.test('board: config JSON round-trip zachova vyrobne polia aj explicitne nil hrany') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cfg = BB.normalize('material_id' => 'K009_PW_DTDL_18', 'length' => 720.4,
                     'width' => 580.0, 'name' => 'Bocna krycia', 'quantity' => 2,
                     'grain_direction' => 'width',
                     'edges' => { 'L1' => 'ABS_K009_10', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  stored = JSON.parse(BB.board_config(cfg).to_json) # ako Store.write_config + Store.config
  NxTest.assert_equal(NxTest::LOADER_VERSION, stored['engine_version'])
  cfg2 = BB.normalize(BB.config_to_params(stored))
  NxTest.assert_equal(cfg[:name], cfg2[:name])
  NxTest.assert_equal(cfg[:role], cfg2[:role])
  NxTest.assert_close(cfg[:length], cfg2[:length])
  NxTest.assert_close(cfg[:width], cfg2[:width])
  NxTest.assert_close(cfg[:thickness], cfg2[:thickness])
  NxTest.assert_equal(cfg[:material_id], cfg2[:material_id])
  NxTest.assert_equal('width', cfg2[:grain_direction], 'grain override prezije round-trip')
  NxTest.assert_equal(cfg[:edges], cfg2[:edges])
  NxTest.assert_equal(2, cfg2[:quantity])
end

# ---------------------------------------------------------------------------
# AbsRules — free_panel labely, seed a seed-merge na existujucich suboroch
# ---------------------------------------------------------------------------

NxTest.test('board: AbsRules pozna free_panel (labely, seed 1 pozdlzna 1.0, lying karta)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  labels = Noxun::Engine::AbsRules.edge_labels('free_panel')
  NxTest.assert_equal('Pozdĺžna 1', labels['L1'])
  NxTest.assert_equal('Priečna 2', labels['W2'])
  th = Noxun::Engine::AbsRules.thicknesses_for('free_panel')
  NxTest.assert_equal({ 'L1' => 1.0 }, th)
  NxTest.assert_equal('bottom', Noxun::Engine::AbsRules.edge_sides('free_panel')['L1'])
  edges = Noxun::Engine::AbsRules.resolve_edges('free_panel', 'K009 PW')
  NxTest.assert_equal('ABS_K009_10', edges['L1'])
  NxTest.assert_equal(nil, edges['L2'])
end

NxTest.test('board: seed-merge doplni free_panel do existujuceho suboru bez prepisu uprav') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ar = Noxun::Engine::AbsRules
  js = Noxun::Engine::JsonFileStore
  # existujuci subor zo starsej verzie: bez seed_version, bez free_panel, s upravou shelf
  js.write(ar.path, { 'std' => 1, 'rules' => { 'shelf' => { 'L1' => 2.0 } } })
  ar.reload!
  rules = ar.load
  NxTest.assert_equal({ 'L1' => 1.0 }, rules['free_panel'], 'nova rola sa doplni zo seedu')
  NxTest.assert_equal({ 'L1' => 1.0 }, rules['rail_front'], 'chybajuca rail rola sa doplni zo seedu (D-30)')
  NxTest.assert_equal({ 'L1' => 2.0 }, rules['shelf'], 'pouzivatelska uprava ostava')
  # subor s aktualnym seed_version: nic sa nedoplna
  js.write(ar.path, { 'std' => 1, 'seed_version' => ar::SEED_VERSION, 'rules' => { 'shelf' => { 'L1' => 2.0 } } })
  ar.reload!
  NxTest.refute(ar.load.key?('free_panel'), 'aktualny seed_version = ziadny dalsi merge')
  # Garancia (upravena pre D-30): NEPRAZDNE pravidlo sa neprepise NIKDY; prazdne
  # pravidlo sa neprepise TIEZ — jedina vynimka je jednorazova rail migracia pri
  # bumpe na SEED_VERSION 2 (PRESNE prazdne rail_front/rail_back — pokryva
  # test 'abs_rules: D-30 rail migracia'). free_panel nie je rail rola, takze
  # pouzivatelov prazdny free_panel ostava prazdny aj pri starom subore.
  js.write(ar.path, { 'std' => 1, 'rules' => { 'free_panel' => {}, 'shelf' => { 'L2' => 2.0 } } })
  ar.reload!
  NxTest.assert_equal({}, ar.load['free_panel'], 'vedome prazdne ne-rail pravidlo ostava')
  NxTest.assert_equal({ 'L2' => 2.0 }, ar.load['shelf'], 'neprazdne pravidlo sa neprepise nikdy')
  # cleanup: vrat plny seed pre dalsie testy v tomto procese
  js.write(ar.path, { 'std' => 1, 'seed_version' => ar::SEED_VERSION,
                      'rules' => js.deep_copy(ar::SEED_RULES) })
  ar.reload!
end

# ---------------------------------------------------------------------------
# Ids — BRD sekvencia + duplicity (generalizacia)
# ---------------------------------------------------------------------------

NxTest.test('board: next_board_id berie max zivych BRD plus 1, ukotveny prefix') do
  st = Noxun::Engine::Store
  i1 = NxTest::FakeInstance.new(1)
  st.write(i1, { kind: 'board', id: 'BRD-002' })
  i2 = NxTest::FakeInstance.new(2)
  st.write(i2, { kind: 'board', id: 'XBRD-009' }) # cudzi tvar sa ignoruje (ukotveny regex)
  i3 = NxTest::FakeInstance.new(3)
  st.write(i3, { kind: 'cabinet', cabinet_id: 'CAB-050' }) # iny kind sa neplete do BRD
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([i1, i2, i3])])
  NxTest.assert_equal('BRD-003', Noxun::Engine::Ids.next_board_id(model))
  NxTest.assert_equal('BRD-001', Noxun::Engine::Ids.next_board_id(NxTest::FakeModel.new([])))
end

NxTest.test('board: duplicate_boards vracia novsiu kopiu zdielaneho id') do
  st = Noxun::Engine::Store
  orig = NxTest::FakeInstance.new(10)
  st.write(orig, { kind: 'board', id: 'BRD-001' })
  kopia = NxTest::FakeInstance.new(20)
  st.write(kopia, { kind: 'board', id: 'BRD-001' })
  bez_id = NxTest::FakeInstance.new(30)
  st.write(bez_id, { kind: 'board' })
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([kopia, orig, bez_id])])
  NxTest.assert_equal([kopia], Noxun::Engine::Ids.duplicate_boards(model))
end

NxTest.test('board: each_of_kind filtruje podla kind') do
  st = Noxun::Engine::Store
  b = NxTest::FakeInstance.new(1)
  st.write(b, { kind: 'board', id: 'BRD-001' })
  c = NxTest::FakeInstance.new(2)
  st.write(c, { kind: 'cabinet', cabinet_id: 'CAB-001' })
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([b, c])])
  found = []
  Noxun::Engine::Ids.each_board(model) { |i| found << i }
  NxTest.assert_equal([b], found)
  found2 = []
  Noxun::Engine::Ids.each_cabinet(model) { |i| found2 << i }
  NxTest.assert_equal([c], found2)
end
