# frozen_string_literal: true
# Testy 2B-2: zastena — obojstranny dekor (rub) + format v identite cez
# register flag format_in_identity (audit F10-F12):
#   - identity: rub + format su sucast variant identity ZASTENA
#   - validate: back polia LEN pre ZASTENA, struktura rubu len s cislom rubu
#   - first-fill: prazdne identity polia legacy zasteny sa smu doplnit RAZ
#   - LAZY schema 4 pri zapise rubu; write/assess brany
require_relative '../helper' unless defined?(NxTest)

NxTest.test('2b2 setup: legacy SCHEMA 1 katalog (sandbox)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_legacy_catalog!, 'legacy katalog sa nenainstaloval')
end

ZMAT = Noxun::Engine::Materials
ZSTORE = Noxun::Engine::JsonFileStore

def zs_sheet(over = {})
  { 'material_id' => 'K551_ZASTENA_10', 'manufacturer' => 'Kronospan', 'decor' => 'K551',
    'structure' => 'RT', 'type' => 'ZASTENA', 'thickness' => 10.0, 'grain' => 'length',
    'sheet_size' => [4100.0, 640.0], 'color' => [10, 20, 30],
    'production_class' => 'sheet', 'group_id' => 'GRP-K551' }.merge(over)
end

def zs_with_catalog(sheets, schema: 2)
  path = ZMAT.path
  ZMAT.catalog
  before = File.binread(path)
  ZSTORE.write(path, { 'std' => ZMAT::STD, 'schema' => schema,
                       'sheets' => sheets, 'edges' => [] })
  ZMAT.reset_catalog_state! if ZMAT.respond_to?(:reset_catalog_state!)
  yield
ensure
  if before
    File.binwrite(path, before)
    ZSTORE.invalidate(path)
    ZMAT.reset_catalog_state! if ZMAT.respond_to?(:reset_catalog_state!)
  end
end

NxTest.test('2b2: format_in_identity? / double_sided_type? — register flag (F10)') do
  NxTest.assert(ZMAT.format_in_identity?('PD'), 'PD format v identite')
  NxTest.assert(ZMAT.format_in_identity?('zastena'), 'ZASTENA case-insensitive')
  NxTest.refute(ZMAT.format_in_identity?('DTDL'), 'DTDL nie')
  NxTest.refute(ZMAT.format_in_identity?('vlastny'), 'iny typ nie')
  NxTest.assert(ZMAT.double_sided_type?('Zastena'), 'zastena je obojstranna')
  NxTest.refute(ZMAT.double_sided_type?('PD'), 'PD nie je obojstranna')
end

NxTest.test('2b2: identita ZASTENA — rub aj format rozlisuju varianty') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  zs_with_catalog([]) do
    a = zs_sheet('back_decor' => 'K552', 'back_structure' => 'RT')
    b = zs_sheet('back_decor' => 'K553', 'back_structure' => 'RT')
    NxTest.refute(ZMAT.identity_keys_tolerant?(ZMAT.sheet_identity_key(a, 2), ZMAT.sheet_identity_key(b, 2)),
                  'iny rub = ina identita')
    c = zs_sheet('back_decor' => 'k552', 'back_structure' => 'rt')
    NxTest.assert(ZMAT.identity_keys_tolerant?(ZMAT.sheet_identity_key(a, 2), ZMAT.sheet_identity_key(c, 2)),
                  'rub case-insensitive')
    d = zs_sheet('sheet_size' => [4200.0, 640.0], 'back_decor' => 'K552', 'back_structure' => 'RT')
    NxTest.refute(ZMAT.identity_keys_tolerant?(ZMAT.sheet_identity_key(a, 2), ZMAT.sheet_identity_key(d, 2)),
                  '4100 vs 4200 = dve zasteny (format v identite)')
    e = zs_sheet('material_id' => 'X', 'back_decor' => 'K552')
    f = zs_sheet('material_id' => 'Y', 'back_decor' => 'K552', 'back_structure' => 'ST9')
    NxTest.refute(ZMAT.identity_keys_tolerant?(ZMAT.sheet_identity_key(e, 2), ZMAT.sheet_identity_key(f, 2)),
                  'ina struktura rubu = ina identita')
  end
end

NxTest.test('2b2: validate_sheet_attrs — back polia len ZASTENA, struktura len s rubom (F12)') do
  ok, = ZMAT.validate_sheet_attrs(zs_sheet('back_decor' => 'K552'))
  NxTest.assert(ok, 'zastena s rubom prejde')
  ok2, err2 = ZMAT.validate_sheet_attrs(zs_sheet('type' => 'DTDL', 'back_decor' => 'K552'))
  NxTest.refute(ok2, 'DTDL s rubom sa odmietne')
  NxTest.assert(err2.to_s.include?('zástena'), err2.inspect)
  ok3, err3 = ZMAT.validate_sheet_attrs(zs_sheet('back_decor' => '', 'back_structure' => 'RT'))
  NxTest.refute(ok3, 'struktura rubu bez cisla sa odmietne')
  NxTest.assert(err3.to_s.include?('číslo rub'), err3.inspect)
end

NxTest.test('2b2: normalize_sheet — struktura rubu bez cisla sa zahodi (merge-safe par)') do
  full = ZMAT.normalize_sheet(zs_sheet('back_decor' => 'K552', 'back_structure' => 'RT'))
  NxTest.assert_equal('K552', full['back_decor'])
  NxTest.assert_equal('RT', full['back_structure'])
  orphan = ZMAT.normalize_sheet(zs_sheet('back_structure' => 'RT'))
  NxTest.refute(orphan.key?('back_structure'), 'osamotena struktura rubu sa neulozi')
end

NxTest.test('2b2: identity_edit_error — vyplneny rub/format nemenny, prazdny first-fill (F11)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  zs_with_catalog([zs_sheet('back_decor' => 'K552')]) do
    existing = ZMAT.sheet('K551_ZASTENA_10')
    err = ZMAT.identity_edit_error({ 'back_decor' => 'K553' }, existing)
    NxTest.assert(err.to_s.include?('Rubový dekor'), 'zmena vyplneneho rubu sa odmietne')
    err2 = ZMAT.identity_edit_error({ 'back_decor' => '' }, existing)
    NxTest.assert(err2.to_s.include?('Rubový dekor'), 'clear vyplneneho rubu sa odmietne')
    NxTest.assert_equal(nil, ZMAT.identity_edit_error({ 'back_decor' => 'K552', 'back_structure' => 'RT' }, existing),
                        'doplnenie PRAZDNEJ struktury rubu = first-fill OK')
    err3 = ZMAT.identity_edit_error(
      { 'sheet_size' => [4200.0, 640.0] }, existing
    )
    NxTest.assert(err3.to_s.include?('Formát'), 'zmena formatu zasteny sa odmietne (identita)')
  end
  zs_with_catalog([zs_sheet.reject { |k, _| k == 'sheet_size' }]) do
    existing = ZMAT.sheet('K551_ZASTENA_10')
    NxTest.assert_equal(nil, ZMAT.identity_edit_error({ 'sheet_size' => [4100.0, 640.0] }, existing),
                        'doplnenie formatu na zazname BEZ formatu = first-fill OK')
    NxTest.assert_equal(nil, ZMAT.identity_edit_error({ 'back_decor' => 'K552' }, existing),
                        'doplnenie rubu na zazname bez rubu = first-fill OK')
  end
end

NxTest.test('2b2: find_sheet_variant s rubom + generate_sheet_id rub token') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  zs_with_catalog([zs_sheet('back_decor' => 'K552')]) do
    hit = ZMAT.find_sheet_variant('K551', 'ZASTENA', 10.0, 'RT', [4100.0, 640.0],
                                  group_id: 'GRP-K551', back_decor: 'K552')
    NxTest.assert_equal('K551_ZASTENA_10', hit && hit['material_id'], 'rovnaky rub matchne')
    miss = ZMAT.find_sheet_variant('K551', 'ZASTENA', 10.0, 'RT', [4100.0, 640.0],
                                   group_id: 'GRP-K551', back_decor: 'K553')
    NxTest.assert_equal(nil, miss, 'iny rub nematchne — druhy variant je legalny')
    id = ZMAT.generate_sheet_id('K551', 'ZASTENA', 10.0, structure: 'RT',
                                sheet_size: [4100.0, 640.0], back_decor: 'K552', schema: 2)
    NxTest.assert(id.include?('RK552'), "ID nesie rub token (#{id})")
    NxTest.assert(id.include?('4100X640'), "ID nesie format (#{id})")
  end
end

NxTest.test('2b2: LAZY schema 4 — zapis rubu zdvihne marker; starsi obsah ho nedvihne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  zs_with_catalog([zs_sheet]) do
    NxTest.assert_equal(2, ZMAT.catalog_schema, 'zastena bez rubu marker nedviha')
    NxTest.assert(ZMAT.upsert_sheet(zs_sheet('back_decor' => 'K552')), 'zapis rubu prejde')
    NxTest.assert_equal(4, ZMAT.catalog_schema, 'rub zdvihol marker na 4 (lazy)')
    state, reason = ZMAT.assess_catalog!
    NxTest.assert_equal(:ok, state, "marker 4 s group_id vsade = :ok (#{reason})")
  end
ensure
  ZMAT.assess_catalog!
end

NxTest.test('2b2: required_schema_for — obsah urcuje minimalnu schemu') do
  NxTest.assert_equal(0, ZMAT.required_schema_for([zs_sheet]))
  NxTest.assert_equal(3, ZMAT.required_schema_for([zs_sheet('source_material_id' => 'X', 'source_multiplier' => 2)]))
  NxTest.assert_equal(4, ZMAT.required_schema_for([zs_sheet('back_decor' => 'K552')]))
  NxTest.assert_equal(4, ZMAT.required_schema_for(
    [zs_sheet('source_material_id' => 'X', 'source_multiplier' => 2), zs_sheet('back_decor' => 'K552')]
  ))
end

# --- GH #95 review fixy ------------------------------------------------------

NxTest.test('2b2 gh95: duplak sa NEvyraba z PD ani zasteny (format-identity typy)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  zs_with_catalog([zs_sheet,
                   zs_sheet('material_id' => 'F800_PD_38', 'type' => 'PD', 'thickness' => 38.0,
                            'sheet_size' => [4100.0, 600.0], 'group_id' => 'GRP-F800', 'decor' => 'F800')]) do
    state, msg = ZMAT.create_duplak_sheet('K551_ZASTENA_10', 2)
    NxTest.assert_equal(:invalid, state, 'zastena nie je zdroj duplaku')
    NxTest.assert(msg.to_s.include?('nelepia'), msg.inspect)
    state2, = ZMAT.create_duplak_sheet('F800_PD_38', 2)
    NxTest.assert_equal(:invalid, state2, 'PD nie je zdroj duplaku')
  end
end

NxTest.test('2b2 gh95: sheet_label_suffix — format (PD/zastena) a rub rozlisia varianty v selecte') do
  a = ZMAT.sheet_label_suffix(zs_sheet('back_decor' => 'K552', 'back_structure' => 'RT'))
  b = ZMAT.sheet_label_suffix(zs_sheet('back_decor' => 'K553'))
  NxTest.refute(a == b, 'rozny rub = rozna pripona labelu (P1)')
  NxTest.assert(a.include?('/K552 RT'), "pripona nesie rub (#{a})")
  NxTest.assert(a.include?('4100×640'), "pripona nesie format (#{a})")
  pd = ZMAT.sheet_label_suffix('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0])
  NxTest.assert_equal(' 4100×600', pd, 'PD pripona = format')
  dtdl = ZMAT.sheet_label_suffix('type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0])
  NxTest.assert_equal('', dtdl, 'DTDL priponu nema (format nie je identita)')
end

NxTest.test('2b2: batch parse — ZASTENA variant bez formatu = chyba davky (F10)') do
  ok, err = ZMAT.send(:parse_sheet_entries_v3, { 'sheet_variants' => [
    { 'type' => 'ZASTENA', 'thickness' => 10 }
  ] }, 'DTDL')
  NxTest.refute(ok, 'zastena bez formatu neprejde')
  NxTest.assert(err.to_s.include?('formát'), err.inspect)
  ok2, entries = ZMAT.send(:parse_sheet_entries_v3, { 'sheet_variants' => [
    { 'type' => 'ZASTENA', 'thickness' => 10, 'sheet_size' => [4100, 640] }
  ] }, 'DTDL')
  NxTest.assert(ok2, entries.inspect)
end
