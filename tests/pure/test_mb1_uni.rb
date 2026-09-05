# frozen_string_literal: true
# Testy V0.6 M-B1: UNI pracovne materialy — SCHEMA 7 polia, fresh seed UNI
# sada, jednorazove doplnenie do existujuceho katalogu (ensure_uni_records!),
# builder vetvy (hrubku pri UNI urcuje dielec), ABS stopky, semafor ORANGE
# "material neurceny" s potlacenim ABS hluku, orientacny odhad platni.
require_relative '../helper' unless defined?(NxTest)

MB1 = Noxun::Engine::Materials
CBU = Noxun::Engine::CabinetBuilder
BBU = Noxun::Engine::BoardBuilder
VAL = Noxun::Engine::Validation

def mb1_uni_sheet(over = {})
  { 'material_id' => 'UNI_TEST_18', 'decor' => 'Korpus UNI', 'manufacturer' => '',
    'group_id' => 'GRP-UNITEST', 'type' => 'DTDL', 'thickness' => 18.0,
    'uni' => true, 'uni_role' => 'body', 'structure' => '' }.merge(over)
end

# --- SCHEMA 7 + polia ---------------------------------------------------------

NxTest.test('mb1 schema: uni pole dviha marker na 7; put_uni_fields strazi enum') do
  NxTest.assert_equal(7, MB1.required_schema_for([{ 'uni' => true }], []))
  NxTest.assert_equal(0, MB1.required_schema_for([{ 'material_id' => 'x' }], []))
  rec = MB1.normalize_sheet('material_id' => 'X', 'decor' => 'D', 'type' => 'DTDL',
                            'thickness' => 18.0, 'uni' => true, 'uni_role' => 'body')
  NxTest.assert_equal([true, 'body'], [rec['uni'], rec['uni_role']])
  bad = MB1.normalize_sheet('material_id' => 'X', 'decor' => 'D', 'type' => 'DTDL',
                            'thickness' => 18.0, 'uni' => true, 'uni_role' => 'kuchyna')
  NxTest.assert_equal(nil, bad['uni_role'], 'neznama rola sa zahodi')
  off = MB1.normalize_sheet('material_id' => 'X', 'decor' => 'D', 'type' => 'DTDL',
                            'thickness' => 18.0, 'uni' => false, 'uni_role' => 'body')
  NxTest.refute(off.key?('uni'), 'false sa neuklada')
  NxTest.refute(off.key?('uni_role'), 'rola bez priznaku sa neuklada')
  NxTest.assert_equal(true, MB1.uni?(mb1_uni_sheet))
  NxTest.assert_equal(false, MB1.uni?('uni' => 'true'))
end

NxTest.test('mb1 patch: UNI zaznam odmieta nakupne polia, nenakupne prejdu') do
  NxTest.assert_equal(nil, MB1.uni_edit_error({ 'uni' => false }, { 'code' => 'x' }))
  err = MB1.uni_edit_error(mb1_uni_sheet, { 'code' => '123' })
  NxTest.assert(err && err.include?('UNI'), err.inspect)
  NxTest.assert(MB1.uni_edit_error(mb1_uni_sheet, { 'price_per_m2' => 5 }))
  NxTest.assert_equal(nil, MB1.uni_edit_error(mb1_uni_sheet, {}), 'bez nakupnych poli OK')
  # GH #103 P2: formularovy edit posiela kluce VZDY — prazdne hodnoty nie su zasah
  NxTest.assert_equal(nil, MB1.uni_edit_error(mb1_uni_sheet, { 'code' => '', 'supplier' => ' ', 'price_per_m2' => '' }),
                      'prazdne nakupne kluce z formu prejdu')
end

NxTest.test('mb1 #103: ensure_edge guard porovnava so SCHEMA_GROUPS, nie markerom (panel client 2)') do
  NxTest.install_fresh_seed_catalog! # marker 7 (UNI seed)
  data = MB1.load
  data['sheets'] << MB1.normalize_sheet('material_id' => 'REAL_ST', 'decor' => 'R1',
                                        'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
                                        'group_id' => MB1.group_id_for('', 'R1'))
  NxTest.assert(MB1.write(data))
  status, abs_id = MB1.ensure_edge_for_sheet('REAL_ST', client_schema: 2)
  NxTest.assert_equal(:created, status, "panel (client 2) nesmie dostat :schema_read_only pri markeri 7 (#{status})")
  NxTest.assert(abs_id)
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('mb1 #103: ABS do UNI skupiny sa nezalozi ani davkou (+ variant)') do
  NxTest.install_fresh_seed_catalog!
  ok, err = MB1.add_decor_batch('batch_schema' => 3, 'decor' => 'Korpus UNI',
                                'manufacturer' => '', 'sheet_variants' => [],
                                'edge_variants' => [{ 'width' => 23, 'thickness' => 1.0 }])
  NxTest.assert_equal(false, ok)
  NxTest.assert(err.include?('UNI'), err.inspect)
  NxTest.assert_equal(true, MB1.uni_group?(nil, 'Korpus UNI'))
  NxTest.assert_equal(false, MB1.uni_group?(nil, 'Realny dekor'))
ensure
  NxTest.install_fresh_seed_catalog!
end

# --- seedy ----------------------------------------------------------------------

NxTest.test('mb1 seed: fresh install = 6 UNI zaznamov, fallback ID recyklovane, bez ABS') do
  NxTest.install_fresh_seed_catalog!
  cat = MB1.load
  # KOV-C2a: 6. zaznam = UNI 16 mm pre dielce zasuviek (4. materialovy kanal).
  NxTest.assert_equal(6, cat['sheets'].length)
  NxTest.assert_equal(0, cat['edges'].length, 'seed ABS pasky zanikli')
  NxTest.assert(cat['sheets'].all? { |s| MB1.uni?(s) })
  korpus = MB1.sheet('K009_PW_DTDL_18')
  NxTest.assert_equal(%w[Korpus\ UNI body], [korpus['decor'], korpus['uni_role']])
  NxTest.assert_close(18.0, korpus['thickness'], 0.01)
  NxTest.assert_equal('Čelo UNI', MB1.sheet('W1000_DTDL_18')['decor'])
  NxTest.assert_equal('HDF UNI', MB1.sheet('HDF_WHITE_3')['decor'])
  NxTest.assert_close(3.0, MB1.sheet('HDF_WHITE_3')['thickness'], 0.01)
  NxTest.assert(MB1.sheet('UNI_DOSKA_18'))
  NxTest.assert(MB1.sheet('UNI_DEKOR2_18'))
  zas = MB1.sheet('UNI_ZASUVKA_16')
  NxTest.assert_equal(['Zásuvka UNI', 'drawer'], [zas['decor'], zas['uni_role']])
  NxTest.assert_close(16.0, zas['thickness'], 0.01)
  # PROJECT_FALLBACK id existuju v katalogu (fresh projekt startuje na UNI)
  MB1::PROJECT_FALLBACK.each_value do |id|
    NxTest.assert(MB1.sheet(id), "fallback #{id} v katalogu")
  end
  raw = JSON.parse(File.read(MB1.path))
  NxTest.assert_equal(7, raw['schema'], 'seed s uni polami = marker 7')
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('mb1 ensure_uni_records!: dopln nove do SCHEMA2 katalogu, idempotent, kolizia dekoru skip') do
  NxTest.install_fresh_seed_catalog!
  # simulacia ZIVEHO katalogu: realne materialy bez UNI + jeden kolizny dekor
  data = MB1.load
  data['sheets'] = [
    MB1.normalize_sheet('material_id' => 'K009_PW_DTDL_18', 'manufacturer' => 'Kronospan',
                        'decor' => 'K009', 'structure' => 'PW', 'type' => 'DTDL',
                        'thickness' => 18.0, 'group_id' => MB1.group_id_for('Kronospan', 'K009'),
                        'code' => '111', 'price_per_m2' => 12.5),
    MB1.normalize_sheet('material_id' => 'VLASTNY_HDF_UNI', 'manufacturer' => '',
                        'decor' => 'HDF UNI', 'type' => 'HDF', 'thickness' => 3.0,
                        'group_id' => MB1.group_id_for('', 'HDF UNI'))
  ]
  data['edges'] = []
  NxTest.assert(MB1.write(data))
  FileUtils.rm_f(MB1.uni_marker_path)
  NxTest.assert_equal(:added, MB1.ensure_uni_records!)
  cat = MB1.load
  NxTest.assert(MB1.sheet('UNI_KORPUS_18'), 'nove UNI id pribudlo')
  NxTest.assert_equal(true, MB1.uni?(MB1.sheet('UNI_KORPUS_18')))
  NxTest.assert_equal(nil, MB1.sheet('UNI_HDF_3'), 'kolizny dekor HDF UNI sa preskocil')
  k = MB1.sheet('K009_PW_DTDL_18')
  NxTest.assert_equal(false, MB1.uni?(k), 'realny zaznam NEDOTKNUTY')
  NxTest.assert_equal('111', k['code'])
  # KOV-C2a: 5 novych (korpus, celo, dekor2, doska, ZASUVKA) — HDF kolizia skip.
  NxTest.assert_equal(7, cat['sheets'].length, '2 povodne + 5 novych UNI (HDF kolizia skip)')
  NxTest.assert(MB1.sheet('UNI_ZASUVKA_16'), 'UNI zasuvka pribudla aj tadeto')
  NxTest.assert(File.exist?(MB1.uni_marker_path))
  before = File.read(MB1.path)
  NxTest.assert_equal(:done, MB1.ensure_uni_records!, 'marker = druhy beh no-op')
  NxTest.assert_equal(before, File.read(MB1.path))
ensure
  FileUtils.rm_f(MB1.uni_marker_path)
  NxTest.install_fresh_seed_catalog!
end

# --- buildery --------------------------------------------------------------------

NxTest.test('mb1 builder: UNI preskakuje hrubkovy raise, adopciu aj auto-pick') do
  uni = mb1_uni_sheet
  pd = { role: 'side_left', prod: { thickness: 25.0 }, suffix: 'S', material: :korpus }
  # validate: real 18 vs dielec 25 raisne, UNI nie
  NxTest.assert_raise('potrebuje') do
    CBU.send(:validate_material_thickness!, 'R', { 'thickness' => 18.0 }, pd)
  end
  NxTest.assert_equal(nil, CBU.send(:validate_material_thickness!, 'U', uni, pd))
  # adopt: UNI nikdy nevnucuje hrubku
  params = { 'thickness' => 25.0 }
  NxTest.assert_equal([:same, nil], CBU.adopt_thickness(params, uni))
  NxTest.assert_close(25.0, params['thickness'], 0.01)
  # pick: UNI current ostava; UNI v poole nie je kandidat
  res = CBU.pick_body_sheet(20.0, uni, [mb1_uni_sheet('material_id' => 'INA_UNI')])
  NxTest.assert_equal('UNI_TEST_18', res[:pick]['material_id'])
  real = { 'material_id' => 'R18', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18.0 }
  res2 = CBU.pick_body_sheet(18.0, real, [real, mb1_uni_sheet], schema: 1)
  NxTest.assert_equal('R18', res2[:pick]['material_id'])
  NxTest.assert_equal(1, res2[:candidates].length, 'UNI nie je kandidat auto-picku')
end

NxTest.test('mb1 board: UNI doska drzi hrubku z configu (12 mm sa da vymodelovat)') do
  NxTest.install_fresh_seed_catalog!
  cfg = BBU.normalize('material_id' => 'UNI_DOSKA_18', 'thickness' => 12.0,
                      'length' => 800, 'width' => 300)
  NxTest.assert_close(12.0, cfg[:thickness], 0.01, 'UNI: config vyhrava')
  # realny material by hrubku prepisal — over kontrast na ne-uni zazname
  data = MB1.load
  data['sheets'] << MB1.normalize_sheet('material_id' => 'REAL_19', 'decor' => 'R',
                                        'type' => 'DTDL', 'thickness' => 19.0,
                                        'group_id' => MB1.group_id_for('', 'R'))
  NxTest.assert(MB1.write(data))
  cfg2 = BBU.normalize('material_id' => 'REAL_19', 'thickness' => 12.0,
                       'length' => 800, 'width' => 300)
  NxTest.assert_close(19.0, cfg2[:thickness], 0.01, 'realny material vyhrava (D-45)')
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('e03 vklad: hrubku z formulara prijme LEN UNI material (server guard)') do
  NxTest.install_fresh_seed_catalog!
  data = MB1.load
  data['sheets'] << MB1.normalize_sheet('material_id' => 'REAL_19', 'decor' => 'R',
                                        'type' => 'DTDL', 'thickness' => 19.0,
                                        'group_id' => MB1.group_id_for('', 'R'))
  NxTest.assert(MB1.write(data))
  # UNI: hodnota z vkladacieho formulara prejde (Number aj string, aj s ciarkou)
  NxTest.assert_close(12.0, BBU.insert_thickness_for('UNI_DOSKA_18', 12.0), 0.01)
  NxTest.assert_close(12.0, BBU.insert_thickness_for('UNI_DOSKA_18', '12'), 0.01)
  NxTest.assert_close(12.5, BBU.insert_thickness_for('UNI_DOSKA_18', '12,5'), 0.01, 'desatinna ciarka')
  # UNI bez hodnoty / so smetim = default roly zo zaznamu, NIKDY chyba
  NxTest.assert_close(18.0, BBU.insert_thickness_for('UNI_DOSKA_18', nil), 0.01)
  NxTest.assert_close(18.0, BBU.insert_thickness_for('UNI_DOSKA_18', '   '), 0.01)
  NxTest.assert_close(18.0, BBU.insert_thickness_for('UNI_DOSKA_18', '650-36'), 0.01,
                      'surovy vyraz sa NESMIE dostat na to_f (bolo by 650)')
  # clamp na LIMITS dosky
  NxTest.assert_close(60.0, BBU.insert_thickness_for('UNI_DOSKA_18', 999), 0.01)
  NxTest.assert_close(1.0, BBU.insert_thickness_for('UNI_DOSKA_18', 0.2), 0.01)
  # realny material: payload sa IGNORUJE (HTML readonly nie je ochrana, D-45)
  NxTest.assert_equal(nil, BBU.insert_thickness_for('REAL_19', 12.0), 'realny material hrubku diktuje')
  NxTest.assert_equal(nil, BBU.insert_thickness_for('', 12.0), 'bez materialu')
  NxTest.assert_equal(nil, BBU.insert_thickness_for('NEZNAMY_ID', 12.0), 'neznamy zaznam')
  # round-trip presne ako build: helper -> normalize
  cfg = BBU.normalize('material_id' => 'UNI_DOSKA_18', 'length' => 800, 'width' => 300,
                      'thickness' => BBU.insert_thickness_for('UNI_DOSKA_18', '12'))
  NxTest.assert_close(12.0, cfg[:thickness], 0.01, 'UNI doska sa vlozi ako 12 mm')
  cfg2 = BBU.normalize('material_id' => 'REAL_19', 'length' => 800, 'width' => 300)
  NxTest.assert_close(19.0, cfg2[:thickness], 0.01, 'realna doska drzi katalogovu hrubku')
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('mb1 abs: UNI nema pasky — picker reason + serverova stopka dotvarania') do
  NxTest.install_fresh_seed_catalog!
  abs_id, reason = MB1.abs_for_sheet(mb1_uni_sheet, :jednotka, 18.0)
  NxTest.assert_equal([nil, 'abs_uni_material'], [abs_id, reason])
  status, = MB1.ensure_edge_for_sheet('UNI_DOSKA_18', client_schema: MB1::SCHEMA_CURRENT)
  NxTest.assert_equal(:uni_material, status)
ensure
  NxTest.install_fresh_seed_catalog!
end

# --- semafor ---------------------------------------------------------------------

NxTest.test('mb1 semafor: UNI dielec = 1x ORANGE uni_material, drift/oversize/ABS ticho') do
  rec = { 'name' => 'Bok', 'part_key' => 'side_left', 'owner_id' => 'CAB-1',
          'role' => 'side_left', 'length' => 9000.0, 'width' => 600.0,
          'thickness' => 25.0, 'material_id' => 'U1', 'grain_direction' => 'none',
          'edges' => {} }
  smap = { 'U1' => mb1_uni_sheet('material_id' => 'U1', 'sheet_size' => [2800.0, 2070.0]) }
  out = VAL.run({ records: [rec], hardware_overrides: [], warnings: [] },
                sheets: smap, edges: {})
  cats = out['items'].map { |i| i['category'] }
  NxTest.assert_equal(['uni_material'], cats, out['items'].inspect)
  NxTest.assert_equal(ORANGE_MB1, out['items'][0]['severity'])
  NxTest.assert_equal(1, out['counts']['orange'])
  NxTest.assert_equal(0, out['counts']['red'], 'drift 25 vs 18 ani oversize 9000 sa nehlasia')
end

ORANGE_MB1 = Noxun::Engine::Validation::ORANGE

NxTest.test('mb1 semafor: ulozeny abs_ build warning UNI dielca sa potlaci, cudzi ostava') do
  rec = { 'name' => 'Doska', 'part_key' => 'board/main', 'owner_id' => 'BRD-1',
          'role' => 'free_panel', 'length' => 800.0, 'width' => 300.0,
          'thickness' => 12.0, 'material_id' => 'U1', 'grain_direction' => 'none',
          'edges' => {} }
  warnings = [
    { 'code' => 'abs_structure_missing', 'message' => 'stary hluk', 'owner_id' => 'BRD-1', 'part_key' => 'board/main' },
    { 'code' => 'abs_structure_missing', 'message' => 'iny dielec', 'owner_id' => 'CAB-9', 'part_key' => 'side_left' },
    { 'code' => 'stavba', 'message' => 'nesuvisiace', 'owner_id' => 'BRD-1', 'part_key' => 'board/main' }
  ]
  smap = { 'U1' => mb1_uni_sheet('material_id' => 'U1') }
  out = VAL.run({ records: [rec], hardware_overrides: [], warnings: warnings },
                sheets: smap, edges: {})
  msgs = out['items'].map { |i| i['message_sk'] }
  NxTest.refute(msgs.any? { |m| m.include?('stary hluk') }, 'abs warning UNI dielca potlaceny')
  NxTest.assert(msgs.any? { |m| m.include?('iny dielec') }, 'cudzi abs warning ostava')
  NxTest.assert(msgs.any? { |m| m.include?('nesuvisiace') }, 'ne-abs warning UNI dielca ostava')
end

# --- odhad platni -----------------------------------------------------------------

NxTest.test('mb1 estimate: uni_ids oznaci riadok ako orientacny') do
  rows = [{ 'material_id' => 'U1', 'length' => 1000.0, 'width' => 500.0, 'quantity' => 2 }]
  est = Noxun::Engine::SheetEstimate.estimate(rows, sheet_sizes: { 'U1' => [2800.0, 2070.0] },
                                              uni_ids: { 'U1' => true })
  NxTest.assert_equal(true, est[0]['uni'])
  est2 = Noxun::Engine::SheetEstimate.estimate(rows, sheet_sizes: {})
  NxTest.refute(est2[0].key?('uni'))
end
