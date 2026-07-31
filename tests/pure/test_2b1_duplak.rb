# frozen_string_literal: true
# Testy 2B-1 (D-43): duplak — variant "zdvojeny zo zdroja".
#   - katalog: create_duplak_sheet (derivacia zo zdroja, guardy pod zamkom),
#     delete guard zdroja, patch/edit zamok, propagacia zdielanych poli,
#     LAZY schema marker 3 + write/assess brany
#   - normalize_sheet: source polia sa nesu LEN cele (zdroj + nasobic)
require_relative '../helper' unless defined?(NxTest)

NxTest.test('2b1 setup: legacy SCHEMA 1 katalog (sandbox)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_legacy_catalog!, 'legacy katalog sa nenainstaloval')
  NxTest.assert_equal(1, Noxun::Engine::Materials.catalog_schema, 'sandbox ma byt SCHEMA 1')
end

DPMAT = Noxun::Engine::Materials
DPSTORE = Noxun::Engine::JsonFileStore

# SCHEMA 2 katalog s dvoma doskami tej istej skupiny (18 + hotova 36) a jednou
# cudzou skupinou; po bloku vrati bajt-presny povodny stav (vzor b3_with_catalog).
def dp_sheet(over = {})
  { 'material_id' => 'TK_PW_DTDL_18', 'manufacturer' => 'Kronospan', 'decor' => 'TK',
    'decor_name' => 'Test dekor', 'structure' => 'PW', 'type' => 'DTDL',
    'thickness' => 18.0, 'grain' => 'length', 'price_per_m2' => 10.0,
    'sheet_size' => [2800.0, 2070.0], 'color' => [10, 20, 30],
    'production_class' => 'sheet', 'group_id' => 'GRP-TESTK',
    'code' => 'DK123', 'supplier' => 'Demos' }.merge(over)
end

def dp_with_catalog(sheets, schema: 2)
  path = DPMAT.path
  DPMAT.catalog # seed, aby subor existoval
  before = File.binread(path)
  DPSTORE.write(path, { 'std' => DPMAT::STD, 'schema' => schema,
                        'sheets' => sheets, 'edges' => [] })
  DPMAT.reset_catalog_state! if DPMAT.respond_to?(:reset_catalog_state!)
  yield
ensure
  if before
    File.binwrite(path, before)
    DPSTORE.invalidate(path)
    DPMAT.reset_catalog_state! if DPMAT.respond_to?(:reset_catalog_state!)
  end
end

NxTest.test('2b1: create_duplak_sheet — derivacia zo zdroja, bez nakupnych poli, marker 3') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dp_with_catalog([dp_sheet]) do
    state, rec = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    NxTest.assert_equal(:ok, state, "create ma prejst (#{rec.inspect})")
    NxTest.assert_equal('TK_PW_DTDL_18', rec['source_material_id'])
    NxTest.assert_equal(2, rec['source_multiplier'])
    NxTest.assert_close(36.0, rec['thickness'], 0.001, 'hrubka = 2x zdroj')
    NxTest.assert_equal('DTDL', rec['type'])
    NxTest.assert_equal('PW', rec['structure'])
    NxTest.assert_equal('length', rec['grain'])
    NxTest.assert_equal('GRP-TESTK', rec['group_id'])
    saved = DPMAT.sheet(rec['material_id'])
    NxTest.assert(saved, 'duplak je v katalogu')
    NxTest.assert_equal([2800.0, 2070.0], saved['sheet_size'], 'format kopiruje zdroj')
    NxTest.refute(saved.key?('code'), 'duplak nema nakupny kod')
    NxTest.refute(saved.key?('supplier'), 'duplak nema dodavatela')
    NxTest.refute(saved.key?('price_per_m2'), 'duplak nema vlastnu cenu')
    NxTest.assert(DPMAT.duplak?(saved))
    NxTest.assert_equal(3, DPMAT.catalog_schema, 'prvy duplak zdvihol marker na 3 (lazy)')
  end
end

NxTest.test('2b1: create guardy — zly zdroj, retazenie, nasobic, duplicita, legacy katalog') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dp_with_catalog([dp_sheet]) do
    state, = DPMAT.create_duplak_sheet('NEEXISTUJE', 2)
    NxTest.assert_equal(:invalid, state, 'neznamy zdroj')
    state, = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 4)
    NxTest.assert_equal(:invalid, state, 'nasobic mimo 2..3')
    state, rec = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    NxTest.assert_equal(:ok, state)
    state, = DPMAT.create_duplak_sheet(rec['material_id'], 2)
    NxTest.assert_equal(:invalid, state, 'zdroj nesmie byt sam duplak (retaz)')
    state, dup_id = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    NxTest.assert_equal(:duplicate, state, 'rovnaka identita = duplicita')
    NxTest.assert_equal(rec['material_id'], dup_id)
  end
  dp_with_catalog([dp_sheet], schema: 1) do
    state, msg = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    NxTest.assert_equal(:invalid, state, 'legacy katalog duplak nepodporuje')
    NxTest.assert(msg.to_s.include?('skupinovej'), 'hlaska vysvetli schemu')
  end
end

NxTest.test('2b1: delete guard — zdroj s duplakom sa nezmaze, po zmazani duplaku ano') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dp_with_catalog([dp_sheet]) do
    _, rec = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    NxTest.assert_equal(['TK_PW_DTDL_18'], [rec['source_material_id']])
    NxTest.assert_equal([rec['material_id']], DPMAT.duplak_dependents('TK_PW_DTDL_18'))
    NxTest.refute(DPMAT.delete_sheet('TK_PW_DTDL_18'), 'zdroj s duplakom sa nesmie zmazat')
    NxTest.assert(DPMAT.sheet('TK_PW_DTDL_18'), 'zdroj ostal v katalogu')
    NxTest.assert(DPMAT.delete_sheet(rec['material_id']), 'duplak sa zmaze bezne')
    NxTest.assert(DPMAT.delete_sheet('TK_PW_DTDL_18'), 'bez duplaku sa zdroj zmaze')
  end
end

NxTest.test('2b1: patch_record na duplak = :invalid (nakupne polia patria zdroju)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dp_with_catalog([dp_sheet]) do
    _, rec = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    state, err = DPMAT.patch_record('sheet', rec['material_id'], { 'code' => 'X1' })
    NxTest.assert_equal(:invalid, state)
    NxTest.assert(err.to_s.include?('zdrojov'), 'hlaska naviguje na zdroj')
    NxTest.assert_equal(:ok, DPMAT.patch_record('sheet', 'TK_PW_DTDL_18', { 'code' => 'DK999' })[0],
                        'zdroj sa patchuje normalne')
  end
end

NxTest.test('2b1: upsert_sheet_with_duplak_sync — format/grain/farba sa propaguju na duplak') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dp_with_catalog([dp_sheet]) do
    _, rec = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    src = DPMAT.sheet('TK_PW_DTDL_18')
    edited = src.merge('sheet_size' => [2800.0, 2050.0], 'grain' => 'none', 'color' => [1, 2, 3])
    NxTest.assert(DPMAT.upsert_sheet_with_duplak_sync(edited), 'sync zapis presiel')
    dup = DPMAT.sheet(rec['material_id'])
    NxTest.assert_equal([2800.0, 2050.0], dup['sheet_size'], 'format nasleduje zdroj')
    NxTest.assert_equal('none', dup['grain'], 'grain nasleduje zdroj')
    NxTest.assert_equal([1, 2, 3], dup['color'], 'farba nasleduje zdroj')
    NxTest.assert_close(36.0, dup['thickness'], 0.001, 'hrubka duplaku sa NEmeni')
    # clear formatu zdroja zmaze format aj duplaku (odhad prejde na fallback)
    cleared = DPMAT.sheet('TK_PW_DTDL_18').reject { |k, _| k == 'sheet_size' }
    NxTest.assert(DPMAT.upsert_sheet_with_duplak_sync(cleared))
    NxTest.refute(DPMAT.sheet(rec['material_id']).key?('sheet_size'), 'clear formatu sa propaguje')
  end
end

NxTest.test('2b1: normalize_sheet nesie duplak polia LEN cele; nasobic mimo {2,3} zahodi') do
  full = DPMAT.normalize_sheet(dp_sheet('source_material_id' => 'SRC', 'source_multiplier' => 2))
  NxTest.assert_equal('SRC', full['source_material_id'])
  NxTest.assert_equal(2, full['source_multiplier'])
  half = DPMAT.normalize_sheet(dp_sheet('source_material_id' => 'SRC'))
  NxTest.refute(half.key?('source_material_id'), 'zdroj bez nasobica sa neulozi')
  bad = DPMAT.normalize_sheet(dp_sheet('source_material_id' => 'SRC', 'source_multiplier' => 7))
  NxTest.refute(bad.key?('source_material_id'), 'nasobic mimo povolenych = cela vazba prec')
  NxTest.refute(bad.key?('source_multiplier'))
  none = DPMAT.normalize_sheet(dp_sheet('source_multiplier' => 2))
  NxTest.refute(none.key?('source_multiplier'), 'nasobic bez zdroja sa neulozi')
end

NxTest.test('2b1: write_unlocked drzi marker 3; novsi marker (4) zapis odmietne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dp_with_catalog([dp_sheet]) do
    _, rec = DPMAT.create_duplak_sheet('TK_PW_DTDL_18', 2)
    NxTest.assert_equal(:ok, DPMAT.patch_record('sheet', 'TK_PW_DTDL_18', { 'code' => 'DKX' })[0])
    NxTest.assert_equal(3, DPMAT.catalog_schema, 'bezna mutacia marker 3 nezhodi')
    NxTest.assert(DPMAT.sheet(rec['material_id'])['source_material_id'], 'duplak vazba prezila mutaciu')
  end
  dp_with_catalog([dp_sheet], schema: 4) do
    NxTest.refute(DPMAT.upsert_sheet(dp_sheet('material_id' => 'NOVA', 'thickness' => 19.0)),
                  'zapis do novsej schemy (4) sa odmietne')
  end
end

NxTest.test('2b1: assess — marker 3 kompletny je :ok, marker 4 read-only') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dp_with_catalog([dp_sheet], schema: 3) do
    state, reason = DPMAT.assess_catalog!
    NxTest.assert_equal(:ok, state, "marker 3 s group_id vsade = :ok (#{reason})")
  end
  dp_with_catalog([dp_sheet], schema: 4) do
    state, reason = DPMAT.assess_catalog!
    NxTest.assert_equal(:read_only, state)
    NxTest.assert(reason.to_s.include?('novšej'), 'dovod = novsia schema')
  end
ensure
  DPMAT.assess_catalog! # stav modulu spat podla realneho sandbox suboru
end
