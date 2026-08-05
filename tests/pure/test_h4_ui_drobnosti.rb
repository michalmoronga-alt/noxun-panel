# frozen_string_literal: true
# Testy H4 (UI drobnosti):
#   D-82 farba per DEKOROVA SKUPINA — set_decor_color (atomicky cela skupina,
#        UNI chranene, revizia katalogu), serverove vynutenie farby pri vzniku
#        variantu (formular, batch, Demos, duplak, dovytvorena ABS paska) a
#        ignorovanie farby v payloade pri EDITE variantu.
#   D-83 payload semaforu — riadok "materiál neurčený" nesie uni_id (skratka do
#        „Nahradiť UNI…"), stable_key sa NEmeni.
require_relative '../helper' unless defined?(NxTest)

H4M = Noxun::Engine::Materials
H4V = Noxun::Engine::Validation

H4_RED = [200, 30, 40].freeze

def h4_group_colors(group_id)
  cat = H4M.load
  (cat['sheets'] + cat['edges'])
    .select { |r| r['group_id'].to_s == group_id.to_s }
    .map { |r| r['color'] }
end

# Zalozi testovaciu skupinu (doska + paska) cez Demos cestu a po teste ju zmaze.
def h4_with_group(decor = 'H4TEST')
  sheet = { 'kind' => 'sheet', 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST9',
            'sheet_size' => [2800.0, 2070.0], 'code' => "H4S#{decor}", 'price' => 12.0,
            'demos_url' => '', 'image_url' => '' }
  edge = { 'kind' => 'edge', 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9',
           'code' => "H4E#{decor}", 'price' => 0.4, 'demos_url' => '' }
  status, info = H4M.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => decor, 'decor_name' => 'H4 test',
    'sheet_items' => [sheet], 'edge_items' => [edge]
  )
  raise "priprava skupiny zlyhala: #{status} #{info.inspect}" unless status == :ok

  yield info
ensure
  Array(info && info['sheets']).each { |id| H4M.delete_sheet(id) }
  Array(info && info['edges']).each { |id| H4M.delete_edge(id) }
end

NxTest.test('h4 setup: cerstvy SCHEMA 2 seed katalog') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
end

# --- D-82: parse farby --------------------------------------------------------

NxTest.test('d82 parse_rgb: hex aj pole, cokolvek ine nil') do
  NxTest.assert_equal([216, 196, 160], H4M.parse_rgb('#d8c4a0'))
  NxTest.assert_equal([216, 196, 160], H4M.parse_rgb('D8C4A0'), 'bez mriezky a velkymi')
  NxTest.assert_equal([1, 2, 3], H4M.parse_rgb([1, 2, 3]))
  NxTest.assert_equal([1, 2, 3], H4M.parse_rgb(%w[1 2 3]), 'ciselne stringy z JSON')
  NxTest.assert_equal(nil, H4M.parse_rgb('#fff'), 'skrateny hex nie je platny zapis')
  NxTest.assert_equal(nil, H4M.parse_rgb([1, 2]), 'neuplne pole')
  NxTest.assert_equal(nil, H4M.parse_rgb([1, 2, 300]), 'mimo rozsahu 0-255')
  NxTest.assert_equal(nil, H4M.parse_rgb(nil))
  NxTest.assert_equal(nil, H4M.parse_rgb('cervena'))
end

# --- D-82: skupinova zmena farby ---------------------------------------------

NxTest.test('d82 set_decor_color: prefarbi CELU skupinu (dosky aj pasky) naraz + zmeni reviziu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  h4_with_group do |info|
    gid = H4M.sheet(info['sheets'][0])['group_id']
    rev_before = H4M.catalog_revision
    NxTest.assert_equal(1, h4_group_colors(gid).uniq.size, 'zalozena skupina ma JEDNU farbu')

    ok, n = H4M.set_decor_color('H4TEST', '#c81e28', group_id: gid)
    NxTest.assert(ok, n.inspect)
    NxTest.assert_equal(2, n, 'prefarbila sa doska AJ paska')
    NxTest.assert_equal([H4_RED], h4_group_colors(gid).uniq, 'cela skupina ma novu farbu')
    NxTest.refute(rev_before == H4M.catalog_revision, 'revizia katalogu sa posunula')

    # Pole [r,g,b] je rovnocenny vstup (tak ho posiela okno Materialy).
    ok2, = H4M.set_decor_color('H4TEST', [10, 20, 30], group_id: gid)
    NxTest.assert(ok2)
    NxTest.assert_equal([[10, 20, 30]], h4_group_colors(gid).uniq)
  end
end

NxTest.test('d82 set_decor_color: neplatna farba a nezname skupiny sa ODMIETNU (ziadny zapis)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  h4_with_group do |info|
    gid = H4M.sheet(info['sheets'][0])['group_id']
    before = h4_group_colors(gid)
    ok, msg = H4M.set_decor_color('H4TEST', 'zelena', group_id: gid)
    NxTest.refute(ok)
    NxTest.assert(msg.to_s.include?('Neplatná farba'), msg.inspect)
    ok2, msg2 = H4M.set_decor_color('NIETAKY', '#112233', group_id: 'GRP-NEEXISTUJE')
    NxTest.refute(ok2)
    NxTest.assert(msg2.to_s.include?('nenašla'), msg2.inspect)
    NxTest.assert_equal(before, h4_group_colors(gid), 'odmietnutie nic nezapisalo')
  end
end

NxTest.test('d82 set_decor_color: UNI skupina je CHRANENA (farba rozlisuje rolu)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  uni = H4M.sheets.find { |s| H4M.uni?(s) }
  NxTest.assert(uni, 'seed ma UNI sadu')
  before = uni['color']
  ok, msg = H4M.set_decor_color(uni['decor'], '#000000', group_id: uni['group_id'])
  NxTest.refute(ok, 'UNI sa neprefarbuje')
  NxTest.assert(msg.to_s.include?('UNI'), msg.inspect)
  NxTest.assert_equal(before, H4M.sheet(uni['material_id'])['color'], 'farba UNI ostala')
end

# --- D-82: farba pri VZNIKU a EDITE variantu ---------------------------------

NxTest.test('d82 edit variantu: farba v payloade sa IGNORUJE (server, nie HTML)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  h4_with_group do |info|
    id = info['sheets'][0]
    rec = H4M.sheet(id)
    before = rec['color']
    NxTest.assert(H4M.upsert_sheet(rec.merge('color' => [1, 1, 1], 'price_per_m2' => 15.0)))
    after = H4M.sheet(id)
    NxTest.assert_equal(before, after['color'], 'edit variantu farbu NEMENI')
    NxTest.assert_close(15.0, after['price_per_m2'], 0.001, 'ostatne polia sa ulozili')

    # To iste pre ABS pasku.
    aid = info['edges'][0]
    arec = H4M.edge(aid)
    NxTest.assert(H4M.upsert_edge(arec.merge('color' => [2, 2, 2])))
    NxTest.assert_equal(arec['color'], H4M.edge(aid)['color'], 'edit pasky farbu NEMENI')
  end
end

NxTest.test('d82 novy variant do EXISTUJUCEJ skupiny: server vnuti skupinovu farbu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  h4_with_group do |info|
    src = H4M.sheet(info['sheets'][0])
    gid = src['group_id']
    NxTest.assert(H4M.set_decor_color('H4TEST', '#c81e28', group_id: gid)[0])

    new_id = 'H4TEST_ST9_DTDL_25'
    begin
      NxTest.assert(H4M.upsert_sheet(src.merge('material_id' => new_id, 'thickness' => 25.0,
                                               'color' => [9, 9, 9], 'code' => 'H4NEW')))
      NxTest.assert_equal(H4_RED, H4M.sheet(new_id)['color'], 'novy variant dedi farbu skupiny')
    ensure
      H4M.delete_sheet(new_id)
    end

    # ABS pasku dovytvorenu automaticky (modal "Vytvoriť a pokračovať") tiez —
    # existujucu 23/1,0 najprv odstranime, aby ju ensure musel naozaj zalozit.
    created = nil
    begin
      NxTest.assert(H4M.delete_edge(info['edges'][0]), 'priprava: skupina bez pouzitelnej pasky')
      state, abs_id = H4M.ensure_edge_for_sheet(src['material_id'], client_schema: H4M::SCHEMA_GROUPS)
      NxTest.assert_equal(:created, state, abs_id.inspect)
      created = abs_id
      NxTest.assert_equal(H4_RED, H4M.edge(created)['color'], 'dovytvorena paska dedi farbu skupiny')
    ensure
      H4M.delete_edge(created) if created
    end
  end
end

NxTest.test('d82 batch "+ variant": farba z formulara sa do existujucej skupiny nedostane') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  h4_with_group do |info|
    gid = H4M.sheet(info['sheets'][0])['group_id']
    NxTest.assert(H4M.set_decor_color('H4TEST', '#c81e28', group_id: gid)[0])
    ok, res = H4M.add_decor_batch(
      'batch_schema' => 3, 'decor' => 'H4TEST', 'manufacturer' => 'Egger',
      'type' => 'DTDL', 'grain' => 'length', 'color' => [9, 9, 9],
      'sheet_variants' => [{ 'type' => 'DTDL', 'thickness' => 16.0, 'structure' => 'ST9' }],
      'edge_variants' => [{ 'width' => 43.0, 'thickness' => 1.0, 'structure' => 'ST9' }]
    )
    NxTest.assert(ok, res.inspect)
    begin
      NxTest.assert_equal([H4_RED], h4_group_colors(gid).uniq,
                          'davka do existujucej skupiny skupinu NEROZDVOJI na dve farby')
    ensure
      Array(res['sheets']).each { |id| H4M.delete_sheet(id) }
      Array(res['edges']).each { |id| H4M.delete_edge(id) }
    end
  end
end

NxTest.test('d82 duplak: dedi farbu skupiny a skupinova zmena zasiahne aj jeho') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  h4_with_group do |info|
    src_id = info['sheets'][0]
    gid = H4M.sheet(src_id)['group_id']
    state, rec = H4M.ensure_duplak_for(src_id, 2)
    NxTest.assert_equal(:ok, state, rec.inspect)
    dup_id = rec['material_id']
    begin
      NxTest.assert_equal(H4M.sheet(src_id)['color'], H4M.sheet(dup_id)['color'],
                          'duplak vznikol s farbou skupiny')
      NxTest.assert(H4M.set_decor_color('H4TEST', '#c81e28', group_id: gid)[0])
      NxTest.assert_equal(H4_RED, H4M.sheet(dup_id)['color'], 'skupinova zmena zasiahla aj duplak')
    ensure
      H4M.delete_sheet(dup_id)
    end
  end
end

NxTest.test('d82 Demos create: NOVA skupina ma JEDNU farbu, doplnenie do existujucej ju dedi') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  h4_with_group('H4DEMOS') do |info|
    gid = H4M.sheet(info['sheets'][0])['group_id']
    # Zalozenie: doska aj paska dostali TU ISTU farbu (nie kazda svoj default).
    NxTest.assert_equal(1, h4_group_colors(gid).uniq.size, 'nova skupina = jedna farba')
    NxTest.assert_equal([H4M::DEFAULT_DECOR_RGB], h4_group_colors(gid).uniq)

    NxTest.assert(H4M.set_decor_color('H4DEMOS', '#c81e28', group_id: gid)[0])
    extra = { 'kind' => 'sheet', 'type' => 'DTDL', 'thickness' => 36.0, 'structure' => 'ST9',
              'sheet_size' => [2800.0, 2070.0], 'code' => 'H4DEMOS36', 'price' => 20.0,
              'demos_url' => '', 'image_url' => '' }
    status, info2 = H4M.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'H4DEMOS', 'decor_name' => 'H4 test',
      'sheet_items' => [extra], 'edge_items' => []
    )
    NxTest.assert_equal(:ok, status, info2.inspect)
    begin
      NxTest.assert_equal([H4_RED], h4_group_colors(gid).uniq,
                          'Demos doplnenie prevzalo ulozenu farbu skupiny')
    ensure
      Array(info2['sheets']).each { |id| H4M.delete_sheet(id) }
    end
  end
end

# --- D-83: payload semaforu ---------------------------------------------------

def h4_uni_record(over = {})
  { 'name' => 'Bok ľavý', 'part_key' => 'side_left', 'owner_id' => 'CAB-001',
    'role' => 'side_left', 'material_id' => 'UNI_KORPUS_18',
    'length' => 700.0, 'width' => 500.0, 'thickness' => 18.0, 'edges' => {} }.merge(over)
end

NxTest.test('d83 semafor: riadok "materiál neurčený" nesie uni_id zo SERVERA') do
  sheets = { 'UNI_KORPUS_18' => { 'material_id' => 'UNI_KORPUS_18', 'decor' => 'Korpus',
                                  'type' => 'DTDL', 'thickness' => 18.0, 'uni' => true,
                                  'uni_role' => 'body' } }
  res = H4V.run({ records: [h4_uni_record] }, sheets: sheets)
  item = res['items'].find { |i| i['category'] == 'uni_material' }
  NxTest.assert(item, res['items'].inspect)
  NxTest.assert_equal('UNI_KORPUS_18', item['uni_id'], 'uni_id z katalogoveho zaznamu')
  NxTest.assert_equal('uni_material|CAB-001|side_left', item['stable_key'],
                      'stable_key sa doplnkovym polom NEMENI (klik-select + dedup)')
  NxTest.assert_equal('orange', item['severity'])
end

NxTest.test('d83 semafor: ostatne kategorie uni_id nemaju (ziadna falosna skratka)') do
  sheets = { 'REAL_18' => { 'material_id' => 'REAL_18', 'decor' => 'K009', 'type' => 'DTDL',
                            'thickness' => 18.0 } }
  # hrubkovy drift = RED riadok bez uni_id
  res = H4V.run({ records: [h4_uni_record('material_id' => 'REAL_18', 'thickness' => 25.0)] },
                sheets: sheets)
  item = res['items'].find { |i| i['category'] == 'thickness' }
  NxTest.assert(item, res['items'].inspect)
  NxTest.refute(item.key?('uni_id'), 'bezny riadok skratku nedostane')
end
