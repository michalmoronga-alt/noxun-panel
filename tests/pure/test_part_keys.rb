# frozen_string_literal: true
# Testy identity dielcov: core/part_keys.rb + core/store.rb + core/ids.rb.
# Cisto pure moduly — ziadny SketchUp API, ziadne katalogy v APPDATA.
require_relative '../helper' unless defined?(NxTest)

# ---------------------------------------------------------------------------
# PartKeys — formaty klucov
# ---------------------------------------------------------------------------

NxTest.test('part_keys: cabinet format s variantom aj bez') do
  pk = Noxun::Engine::PartKeys
  NxTest.assert_equal('cabinet/bok', pk.cabinet('bok'))
  NxTest.assert_equal('cabinet/bok:L', pk.cabinet('bok', 'L'))
end

NxTest.test('part_keys: zone format prevadza index cez to_i') do
  pk = Noxun::Engine::PartKeys
  NxTest.assert_equal('zone:z1/shelf:2', pk.zone('z1', 'shelf', 2))
  NxTest.assert_equal('zone:z1/shelf:3', pk.zone('z1', 'shelf', '3'))
  # nil.to_i == 0 — sucasne spravanie fixujeme
  NxTest.assert_equal('zone:z1/shelf:0', pk.zone('z1', 'shelf', nil))
end

NxTest.test('part_keys: front format s variantom aj bez') do
  pk = Noxun::Engine::PartKeys
  NxTest.assert_equal('front:f1/door', pk.front('f1', 'door'))
  NxTest.assert_equal('front:f1/door:L', pk.front('f1', 'door', 'L'))
end

NxTest.test('part_keys: segment sanitizuje nepovolene znaky a prazdne hodnoty') do
  pk = Noxun::Engine::PartKeys
  NxTest.assert_equal('unknown', pk.segment(''))
  NxTest.assert_equal('unknown', pk.segment(nil))
  NxTest.assert_equal('unknown', pk.segment('   '))
  # run nepovolenych znakov -> jeden podtrznik
  NxTest.assert_equal('a_b', pk.segment('a b'))
  NxTest.assert_equal('a_b_c', pk.segment('a/b?c'))
  # bodka, pomlcka a podtrznik su povolene
  NxTest.assert_equal('ok_1.5-X', pk.segment('ok_1.5-X'))
  # sanitizacia sa uplatnuje aj cez verejne formaty
  NxTest.assert_equal('cabinet/unknown', pk.cabinet(''))
  NxTest.assert_equal('front:unknown/horna_skrinka', pk.front('', 'horna skrinka'))
end

NxTest.test('part_keys: SCHEMA konstanta je 1') do
  NxTest.assert_equal(1, Noxun::Engine::PartKeys::SCHEMA)
end

NxTest.test('part_keys: for_descriptor vracia part_key a raise bez neho') do
  pk = Noxun::Engine::PartKeys
  NxTest.assert_equal('cabinet/bok:L', pk.for_descriptor(part_key: 'cabinet/bok:L', suffix: 'BOK-L'))
  NxTest.assert_raise('chyba part_key') { pk.for_descriptor(suffix: 'BOK-L') }
  NxTest.assert_raise('chyba part_key') { pk.for_descriptor(part_key: '', suffix: 'BOK-L') }
  NxTest.assert_raise('chyba part_key') { pk.for_descriptor(nil) }
end

# ---------------------------------------------------------------------------
# PartKeys — migrate_overrides
# ---------------------------------------------------------------------------

NxTest.test('part_keys: migrate_overrides preklada legacy suffix na part_key') do
  pk = Noxun::Engine::PartKeys
  descriptors = [
    { part_key: 'cabinet/bok:L', suffix: 'BOK-L' },
    { part_key: 'cabinet/bok:R', suffix: 'BOK-R' }
  ]
  raw = { 'BOK-L' => { 'material' => 'DTD18' } }
  out = pk.migrate_overrides(raw, descriptors)
  NxTest.assert_equal({ 'cabinet/bok:L' => { 'material' => 'DTD18' } }, out)
end

NxTest.test('part_keys: migrate_overrides raise pri duplicitnom part_key v plane') do
  pk = Noxun::Engine::PartKeys
  descriptors = [
    { part_key: 'cabinet/bok:L', suffix: 'BOK-L' },
    { part_key: 'cabinet/bok:L', suffix: 'BOK-X' }
  ]
  NxTest.assert_raise('Duplicitny part_key') { pk.migrate_overrides({}, descriptors) }
end

NxTest.test('part_keys: migrate_overrides zachova nezname kluce') do
  pk = Noxun::Engine::PartKeys
  descriptors = [{ part_key: 'cabinet/bok:L', suffix: 'BOK-L' }]
  raw = { 'CUDZI-KLUC' => 42, 'BOK-L' => 'x' }
  out = pk.migrate_overrides(raw, descriptors)
  NxTest.assert_equal(42, out['CUDZI-KLUC'])
  NxTest.assert_equal('x', out['cabinet/bok:L'])
end

NxTest.test('part_keys: explicitny novy kluc vyhrava nad migrovanym legacy') do
  pk = Noxun::Engine::PartKeys
  descriptors = [{ part_key: 'cabinet/bok:L', suffix: 'BOK-L' }]
  raw = { 'cabinet/bok:L' => 'novy', 'BOK-L' => 'stary' }
  out = pk.migrate_overrides(raw, descriptors)
  NxTest.assert_equal({ 'cabinet/bok:L' => 'novy' }, out)
  NxTest.assert_equal(1, out.size)
end

NxTest.test('part_keys: migrate_overrides s ne-Hash vstupom vracia prazdny hash') do
  pk = Noxun::Engine::PartKeys
  descriptors = [{ part_key: 'cabinet/bok:L', suffix: 'BOK-L' }]
  NxTest.assert_equal({}, pk.migrate_overrides(nil, descriptors))
  NxTest.assert_equal({}, pk.migrate_overrides('retazec', descriptors))
  NxTest.assert_equal({}, pk.migrate_overrides([], []))
end

# ---------------------------------------------------------------------------
# Store — NOXUN dictionary na FakeEntity
# ---------------------------------------------------------------------------

NxTest.test('store: write preskoci nil hodnoty a zapise ploche kluce') do
  st = Noxun::Engine::Store
  e = NxTest::FakeEntity.new
  ret = st.write(e, { kind: 'cabinet', role: nil, cabinet_id: 'CAB-001' })
  NxTest.assert_equal(e, ret, 'write ma vratit entitu')
  NxTest.assert_equal('cabinet', e.dicts[st::DICT]['kind'])
  NxTest.assert_equal('CAB-001', st.get(e, 'cabinet_id'))
  NxTest.refute(e.dicts[st::DICT].key?('role'), 'nil hodnota sa nesmie zapisat')
end

NxTest.test('store: config Hash sa serializuje na JSON string pod klucom config') do
  st = Noxun::Engine::Store
  e = NxTest::FakeEntity.new
  st.write(e, { kind: 'cabinet', config: { 'width' => 600.0 } })
  raw = e.dicts[st::DICT]['config']
  NxTest.assert(raw.is_a?(String), 'config musi byt ulozeny ako JSON string')
  parsed = JSON.parse(raw)
  NxTest.assert_equal(['width'], parsed.keys)
  NxTest.assert_close(600.0, parsed['width'])
  # round-trip cez Store.config
  cfg = st.config(e)
  NxTest.assert(cfg.is_a?(Hash))
  NxTest.assert_close(600.0, cfg['width'])
end

NxTest.test('store: write_config so Stringom ulozi string bez zmeny') do
  st = Noxun::Engine::Store
  e = NxTest::FakeEntity.new
  st.write_config(e, '{"a":1}')
  NxTest.assert_equal('{"a":1}', e.dicts[st::DICT]['config'])
  # aj cez write s config ako String
  e2 = NxTest::FakeEntity.new
  st.write(e2, { kind: 'panel', config: '{"b":2}' })
  NxTest.assert_equal('{"b":2}', e2.dicts[st::DICT]['config'])
end

NxTest.test('store: get na objekte bez get_attribute vracia nil') do
  NxTest.assert_equal(nil, Noxun::Engine::Store.get(Object.new, 'kind'))
end

NxTest.test('store: kind a noxun? rozlisia oznacenu a cistu entitu') do
  st = Noxun::Engine::Store
  prazdna = NxTest::FakeEntity.new
  NxTest.assert_equal(nil, st.kind(prazdna))
  NxTest.refute(st.noxun?(prazdna))
  oznacena = NxTest::FakeEntity.new
  st.write(oznacena, { kind: 'cabinet' })
  NxTest.assert_equal('cabinet', st.kind(oznacena))
  NxTest.assert(st.noxun?(oznacena))
end

NxTest.test('store: config vracia nil ked chyba') do
  e = NxTest::FakeEntity.new
  NxTest.assert_equal(nil, Noxun::Engine::Store.config(e))
end

NxTest.test('store: config s neplatnym JSON vracia nil (log_error chyta stub)') do
  st = Noxun::Engine::Store
  e = NxTest::FakeEntity.new
  e.set_attribute(st::DICT, 'config', '{zly json')
  NxTest.assert_equal(nil, st.config(e))
end

# ---------------------------------------------------------------------------
# Ids — cabinet_id generator a duplikaty na FakeModel
# ---------------------------------------------------------------------------

NxTest.test('ids: next_cabinet_id berie max existujucich plus 1') do
  st = Noxun::Engine::Store
  i1 = NxTest::FakeInstance.new(1)
  st.write(i1, { kind: 'cabinet', cabinet_id: 'CAB-002' })
  i2 = NxTest::FakeInstance.new(2)
  st.write(i2, { kind: 'cabinet', cabinet_id: 'CAB-007' })
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([i1, i2])])
  NxTest.assert_equal('CAB-008', Noxun::Engine::Ids.next_cabinet_id(model))
end

NxTest.test('ids: next_cabinet_id fallback na kluc id') do
  st = Noxun::Engine::Store
  i = NxTest::FakeInstance.new(1)
  st.write(i, { kind: 'cabinet', id: 'CAB-004' })
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([i])])
  NxTest.assert_equal('CAB-005', Noxun::Engine::Ids.next_cabinet_id(model))
end

NxTest.test('ids: next_cabinet_id preskakuje image a group definicie') do
  st = Noxun::Engine::Store
  i_img = NxTest::FakeInstance.new(1)
  st.write(i_img, { kind: 'cabinet', cabinet_id: 'CAB-009' })
  i_grp = NxTest::FakeInstance.new(2)
  st.write(i_grp, { kind: 'cabinet', cabinet_id: 'CAB-003' })
  i_ok = NxTest::FakeInstance.new(3)
  st.write(i_ok, { kind: 'cabinet', cabinet_id: 'CAB-001' })
  model = NxTest::FakeModel.new([
    NxTest::FakeDefinition.new([i_img], image: true),
    NxTest::FakeDefinition.new([i_grp], group: true),
    NxTest::FakeDefinition.new([i_ok])
  ])
  NxTest.assert_equal('CAB-002', Noxun::Engine::Ids.next_cabinet_id(model))
end

NxTest.test('ids: prazdny model vracia CAB-001') do
  NxTest.assert_equal('CAB-001', Noxun::Engine::Ids.next_cabinet_id(NxTest::FakeModel.new([])))
  # instancia bez NOXUN kind sa ignoruje
  cudzia = NxTest::FakeInstance.new(1)
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([cudzia])])
  NxTest.assert_equal('CAB-001', Noxun::Engine::Ids.next_cabinet_id(model))
end

NxTest.test('ids: duplicate_cabinets vracia novsiu instanciu (original vlozeny prvy)') do
  st = Noxun::Engine::Store
  orig = NxTest::FakeInstance.new(10)
  st.write(orig, { kind: 'cabinet', cabinet_id: 'CAB-001' })
  kopia = NxTest::FakeInstance.new(20)
  st.write(kopia, { kind: 'cabinet', cabinet_id: 'CAB-001' })
  # bez cabinet_id — musi sa preskocit bez padu
  bez_cid = NxTest::FakeInstance.new(30)
  st.write(bez_cid, { kind: 'cabinet' })
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([orig, kopia, bez_cid])])
  NxTest.assert_equal([kopia], Noxun::Engine::Ids.duplicate_cabinets(model))
end

NxTest.test('ids: duplicate_cabinets vracia novsiu aj ked je vlozena prva') do
  st = Noxun::Engine::Store
  orig = NxTest::FakeInstance.new(10)
  st.write(orig, { kind: 'cabinet', cabinet_id: 'CAB-001' })
  kopia = NxTest::FakeInstance.new(20)
  st.write(kopia, { kind: 'cabinet', cabinet_id: 'CAB-001' })
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([kopia, orig])])
  NxTest.assert_equal([kopia], Noxun::Engine::Ids.duplicate_cabinets(model))
end

NxTest.test('ids: part_id spaja cabinet_id a role suffix') do
  NxTest.assert_equal('CAB-001-SIDE-L', Noxun::Engine::Ids.part_id('CAB-001', 'SIDE-L'))
  NxTest.assert_equal('CAB-003-SHELF-2', Noxun::Engine::Ids.part_id('CAB-003', 'SHELF-2'))
end
