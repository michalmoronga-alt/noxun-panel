# frozen_string_literal: true
# Testy davky 2 (D-05): sprava katalogu materialov — validacia, generovanie ID
# (transliteracia, kolizie, desatinny token), chranene predvolby, scan pouzitia
# (model cez Fake objekty + globalne sablony).
require_relative '../helper' unless defined?(NxTest)

MAT = Noxun::Engine::Materials

# ---------------------------------------------------------------------------
# slug / thickness_token / generate ids
# ---------------------------------------------------------------------------

NxTest.test('mat-crud: slug transliteruje diakritiku a cisti znaky') do
  NxTest.assert_equal('DUB_HALIFAX_PRIRODNY', MAT.slug('Dub Halifax prírodný'))
  NxTest.assert_equal('EGGER_H1180', MAT.slug('Egger H1180'))
  NxTest.assert_equal('LTD_SLONOVA_KOST', MAT.slug('  LTD — slonová kosť!  '))
end

NxTest.test('mat-crud: thickness_token cele vs desatinne mm') do
  NxTest.assert_equal('18', MAT.thickness_token(18.0))
  NxTest.assert_equal('38', MAT.thickness_token('38'))
  NxTest.assert_equal('18P5', MAT.thickness_token(18.5))
  NxTest.assert_equal('12P7', MAT.thickness_token('12,7'))
end

NxTest.test('mat-crud: generate_sheet_id + case-insensitive kolizie -2/-3') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  id1 = MAT.generate_sheet_id('Test Kolizia', 'DTDL', 18.0)
  NxTest.assert_equal('TEST_KOLIZIA_DTDL_18', id1)
  MAT.upsert_sheet('material_id' => id1, 'decor' => 'Test Kolizia', 'type' => 'DTDL', 'thickness' => 18.0)
  id2 = MAT.generate_sheet_id('test KOLÍZIA', 'dtdl', 18)
  NxTest.assert_equal('TEST_KOLIZIA_DTDL_18-2', id2)
  MAT.upsert_sheet('material_id' => id2, 'decor' => 'test KOLÍZIA', 'type' => 'dtdl', 'thickness' => 18.0)
  NxTest.assert_equal('TEST_KOLIZIA_DTDL_18-3', MAT.generate_sheet_id('Test Kolizia', 'DTDL', 18.0))
  MAT.delete_sheet(id1)
  MAT.delete_sheet(id2)
end

NxTest.test('mat-crud: generate_edge_id (hrubka x10, ABS prefix)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_equal('ABS_UPLNE_NOVY_DEKOR_20', MAT.generate_edge_id('Úplne nový dekor', 2.0))
end

# ---------------------------------------------------------------------------
# validacia formularovych atributov
# ---------------------------------------------------------------------------

NxTest.test('mat-crud: validate_sheet_attrs odmieta neplatne vstupy') do
  ok, = MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 38.0)
  NxTest.assert(ok)
  NxTest.refute(MAT.validate_sheet_attrs('decor' => '', 'type' => 'DTDL', 'thickness' => 18)[0], 'prazdny dekor')
  NxTest.refute(MAT.validate_sheet_attrs('decor' => 'X', 'type' => '', 'thickness' => 18)[0], 'prazdny typ')
  NxTest.refute(MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 0)[0], 'nulova hrubka')
  NxTest.refute(MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 'abc')[0], 'neciselna hrubka')
  NxTest.refute(MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 18, 'grain' => 'diagonal')[0], 'neznamy grain')
  NxTest.refute(MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 18, 'price_per_m2' => -1)[0], 'zaporna cena')
  NxTest.refute(MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 18, 'color' => [300, 0, 0])[0], 'RGB mimo rozsahu')
  ok2, = MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => '18,5', 'price_per_m2' => 0)
  NxTest.assert(ok2, 'ciarkova hrubka + cena 0 su platne')
end

NxTest.test('mat-crud: validate_edge_attrs vyzaduje 1/2 mm a nezapornu cenu') do
  NxTest.assert(MAT.validate_edge_attrs('decor' => 'X', 'thickness' => '2,0')[0])
  NxTest.refute(MAT.validate_edge_attrs('decor' => 'X', 'thickness' => 0.8)[0], 'nepodporovana hrubka')
  NxTest.refute(MAT.validate_edge_attrs('decor' => '', 'thickness' => 1.0)[0], 'prazdny dekor')
  NxTest.refute(MAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0, 'price_per_bm' => -0.5)[0], 'zaporna cena')
end

NxTest.test('mat-crud: PROTECTED_SHEET_IDS = fallback predvolby novych projektov') do
  NxTest.assert_equal(MAT::PROJECT_FALLBACK.values.sort, MAT::PROTECTED_SHEET_IDS.sort)
end

# ---------------------------------------------------------------------------
# scan pouzitia (Fake model + sablony)
# ---------------------------------------------------------------------------

# FakeModel helperu nema get_attribute (projektove defaulty na modeli) — lokalne rozsirenie.
class MatCrudFakeModel < NxTest::FakeModel
  def initialize(definitions, defaults = {})
    super(definitions)
    @defaults = defaults
  end

  def get_attribute(_dict, key, default = nil)
    @defaults.fetch(key.to_s, default)
  end
end

NxTest.test('mat-crud: used_material_ids vidi defaulty, korpusy, overrides, dielce, dosky aj sablony') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  st = Noxun::Engine::Store
  cab = NxTest::FakeInstance.new(1)
  st.write(cab, { kind: 'cabinet', cabinet_id: 'CAB-001',
                  config: { 'material_id' => 'MAT_A', 'front_material_id' => nil,
                            'part_overrides' => { 'cabinet/side:left' => { 'material_id' => 'MAT_OVR' } } } })
  part = NxTest::FakeInstance.new(2)
  st.write(part, { kind: 'part', id: 'CAB-001-SIDE-L', config: { 'material_id' => 'MAT_PART', 'edges' => { 'L1' => 'ABS_X_10', 'L2' => nil } } })
  board = NxTest::FakeInstance.new(3)
  st.write(board, { kind: 'board', id: 'BRD-001', config: { 'material_id' => 'MAT_BOARD', 'edges' => { 'W1' => 'ABS_Y_20' } } })
  model = MatCrudFakeModel.new([NxTest::FakeDefinition.new([cab, part, board])],
                               'default_material_id' => 'MAT_DEFAULT')
  Noxun::Engine::TemplateStore.upsert('mat-crud-test-tpl', 'material_id' => 'MAT_TPL')

  used = MAT.used_material_ids(model)
  NxTest.assert(used['MAT_A'].any? { |w| w == 'CAB-001' }, 'korpusovy material')
  NxTest.assert(used['MAT_OVR'].any?, 'part_override material')
  NxTest.assert(used['MAT_PART'].any?, 'material instancie dielca')
  NxTest.assert(used['MAT_BOARD'].any? { |w| w == 'BRD-001' }, 'material dosky')
  NxTest.assert(used['MAT_DEFAULT'].any? { |w| w.include?('predvoľba') }, 'projektovy default')
  NxTest.assert(used['MAT_TPL'].any? { |w| w.include?('šablóna') }, 'globalna sablona')
  NxTest.assert_equal([], used['MAT_NEPOUZITY'], 'nepouzity material je volny')

  abs = MAT.used_abs_ids(model)
  NxTest.assert(abs['ABS_X_10'].any?, 'ABS na dielci')
  NxTest.assert(abs['ABS_Y_20'].any? { |w| w == 'BRD-001' }, 'ABS na doske')
  NxTest.assert_equal([], abs['ABS_VOLNA'])

  Noxun::Engine::TemplateStore.delete('mat-crud-test-tpl')
end

NxTest.test('mat-crud: upsert_sheet round-trip vsetkych poli + cache refresh') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  rec = { 'material_id' => 'RT_TEST_38', 'family' => 'Rodina X', 'manufacturer' => 'Vyrobca Y',
          'decor' => 'RT Dekor', 'type' => 'KOMPAKT', 'thickness' => 38.0, 'grain' => 'width',
          'price_per_m2' => 55.5, 'sheet_size' => [4100.0, 1300.0], 'color' => [10, 20, 30] }
  NxTest.assert(MAT.upsert_sheet(rec))
  back = MAT.sheet('RT_TEST_38')
  NxTest.assert(!back.nil?, 'zaznam sa cita HNED po zapise (cache invalidacia)')
  %w[family manufacturer decor type grain].each { |k| NxTest.assert_equal(rec[k], back[k]) }
  NxTest.assert_close(38.0, back['thickness'])
  NxTest.assert_close(55.5, back['price_per_m2'])
  NxTest.assert_equal([4100.0, 1300.0], back['sheet_size'])
  NxTest.assert_equal([10, 20, 30], back['color'])
  MAT.delete_sheet('RT_TEST_38')
  NxTest.assert(MAT.sheet('RT_TEST_38').nil?, 'delete sa prejavi hned')
end
