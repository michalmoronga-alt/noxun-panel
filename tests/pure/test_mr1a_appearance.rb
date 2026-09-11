# frozen_string_literal: true
# MR-1A: skutocne katalogove transakcie v oddelenom tempfile priecinku.
require_relative '../helper' unless defined?(NxTest)

module NxMR1A
  M = Noxun::Engine::Materials
  J = Noxun::Engine::JsonFileStore
  module_function

  def sheet(id, structure = 'ST9', thickness = 18)
    { 'material_id' => id, 'group_id' => 'GRP-MR', 'manufacturer' => 'Egger',
      'decor' => 'H1180', 'type' => 'DTDL', 'thickness' => thickness.to_f,
      'structure' => structure, 'grain' => 'length', 'color' => [110, 120, 130] }
  end

  def edge(id = 'E', structure = 'ST9')
    { 'abs_id' => id, 'group_id' => 'GRP-MR', 'decor' => 'H1180', 'structure' => structure,
      'thickness' => 1.0, 'width' => 23.0, 'color' => [110, 120, 130] }
  end

  def descriptor(mode = 'native')
    { 'version' => 1, 'id' => SecureRandom.uuid, 'mode' => mode, 'saved_at' => '2026-09-11T08:00:00Z' }
  end

  def raw_write(data)
    File.binwrite(M.path, JSON.generate(data))
    J.invalidate(M.path)
  end

  def raw
    JSON.parse(File.binread(M.path))
  end

  def isolated
    NxTest.skip!('Len headless, nikdy zivy katalog') unless NxTest.headless?
    old_dir = M.test_dir_override
    old_state = M.instance_variable_get(:@catalog_state)
    old_reason = M.instance_variable_get(:@catalog_state_reason)
    Dir.mktmpdir('noxun-mr1a-') do |temp|
      M.test_dir_override = temp
      M.reset_catalog_state!
      raw_write('schema' => 9, 'sheets' => [sheet('S18'), sheet('S16', ' st9 ', 16),
                                         sheet('MATTE', 'ST 9'), sheet('EMPTY', '')],
                'edges' => [edge, edge('EEMPTY', '')])
      yield
    ensure
      J.invalidate(M.path)
      M.test_dir_override = old_dir
      M.instance_variable_set(:@catalog_state, old_state)
      M.instance_variable_set(:@catalog_state_reason, old_reason)
    end
  end

  def scope(kind = 'sheet', id = 'S18')
    status, result = M.appearance_scope(kind, id)
    NxTest.assert_equal(:ok, status, result.inspect)
    result
  end

  def publish(mode = 'native', kind = 'sheet', id = 'S18', &block)
    M.publish_appearance(kind, id, baseline: scope(kind, id)['baseline'], mode: mode,
                         &(block || proc { |file, _descriptor, _scope| File.binwrite(file, 'native exporter fixture'); true }))
  end

  def all_main
    (raw['sheets'] + raw['edges']).select { |rec| M.appearance_scope_key(rec) == ['GRP-MR', 'ST9'] }
  end
end

NxTest.test('mr1a: schema9 a povodne farby sa otvorenim nemenia') do
  NxMR1A.isolated do
    before = File.binread(NxMR1A::M.path)
    state = NxMR1A.scope
    NxTest.assert_equal(3, state['members'].length)
    NxTest.assert_equal(nil, state['appearance'])
    NxMR1A::M.load
    NxTest.assert_equal(before, File.binread(NxMR1A::M.path))
    NxTest.refute(Dir.exist?(File.join(NxMR1A::M.dir, 'appearances')))
  end
end

NxTest.test('mr1a: normalize native/color oboch druhov; absent nie je nil descriptor') do
  %w[native color].each do |mode|
    desc = NxMR1A.descriptor(mode)
    NxTest.assert_equal(desc, NxMR1A::M.normalize_sheet(NxMR1A.sheet('S').merge('appearance' => desc))['appearance'])
    NxTest.assert_equal(desc, NxMR1A::M.normalize_edge(NxMR1A.edge.merge('appearance' => desc))['appearance'])
  end
  NxTest.refute(NxMR1A::M.normalize_sheet(NxMR1A.sheet('S')).key?('appearance'))
  [nil, {}, NxMR1A.descriptor.merge('version' => 2), NxMR1A.descriptor.merge('id' => '../bad'),
   NxMR1A.descriptor.merge('saved_at' => '2026-02-31T08:00:00Z'),
   NxMR1A.descriptor.merge('path' => 'C:/anything')].each do |desc|
    NxTest.assert_raise { NxMR1A::M.normalize_sheet(NxMR1A.sheet('S').merge('appearance' => desc)) }
  end
  NxTest.assert_equal(10, NxMR1A::M.required_schema_for([], [NxMR1A.edge.merge('appearance' => NxMR1A.descriptor)]))
end

NxTest.test('mr1a: jedno ulozenie prepise dosky aj ABS v scope, prazdny a iny povrch ostava') do
  NxMR1A.isolated do
    status, result = NxMR1A.publish
    NxTest.assert_equal(:ok, status, result.inspect)
    desc = result['appearance']
    NxTest.assert_equal(10, NxMR1A.raw['schema'])
    NxTest.assert(NxMR1A.all_main.all? { |rec| rec['appearance'] == desc })
    NxTest.assert_equal('native exporter fixture', File.binread(NxMR1A::M.appearance_file(desc['id'])))
    NxTest.refute(NxMR1A.raw['sheets'].find { |s| s['material_id'] == 'MATTE' }.key?('appearance'))
    NxTest.refute(NxMR1A.scope('sheet', 'EMPTY')['appearance'])
    status, = NxMR1A.publish('color', 'edge', 'E')
    NxTest.assert_equal(:ok, status)
    NxTest.assert(NxMR1A.all_main.all? { |rec| rec['appearance']['mode'] == 'color' && rec['color'] == [110, 120, 130] })
    NxTest.assert(File.exist?(NxMR1A::M.appearance_file(desc['id'])), 'stara revizia sa nemaze')
  end
end

NxTest.test('mr1a: prazdny povrch ma vlastny spolocny rozsah doska/ABS') do
  NxMR1A.isolated do
    status, = NxMR1A.publish('color', 'edge', 'EEMPTY')
    NxTest.assert_equal(:ok, status)
    NxTest.assert_equal('color', NxMR1A.scope('sheet', 'EMPTY')['appearance']['mode'])
    NxTest.assert_equal(nil, NxMR1A.scope['appearance'])
  end
end

NxTest.test('mr1a: stale baseline odmietne cudziu reviziu aj zmenu clenstva') do
  NxMR1A.isolated do
    old = NxMR1A.scope['baseline']
    NxMR1A.publish('color')
    before = File.binread(NxMR1A::M.path)
    status, = NxMR1A::M.publish_appearance('sheet', 'S18', baseline: old, mode: 'color')
    NxTest.assert_equal(:stale, status)
    NxTest.assert_equal(before, File.binread(NxMR1A::M.path))
    old = NxMR1A.scope['baseline']
    NxTest.assert(NxMR1A::M.upsert_sheet(NxMR1A.sheet('S25', 'ST9', 25)))
    status, = NxMR1A::M.publish_appearance('sheet', 'S18', baseline: old, mode: 'color')
    NxTest.assert_equal(:stale, status)
  end
end

NxTest.test('mr1a: konflikt vratane absent dovoli cenu, odmietne dedenie, explicitny replace ho opravi') do
  NxMR1A.isolated do
    data = NxMR1A.raw
    data['sheets'][0]['appearance'] = NxMR1A.descriptor
    data['schema'] = 10
    NxMR1A.raw_write(data)
    NxTest.assert(NxMR1A.scope['conflict'])
    NxTest.assert_equal(:ok, NxMR1A::M.patch_record('sheet', 'S18', { 'price_per_m2' => 20 })[0])
    NxTest.refute(NxMR1A::M.upsert_sheet(NxMR1A.sheet('S25', 'ST9', 25)))
    NxTest.assert_equal(:ok, NxMR1A.publish('color')[0])
    NxTest.refute(NxMR1A.scope['conflict'])
    NxTest.assert(NxMR1A::M.upsert_sheet(NxMR1A.sheet('S25', 'ST9', 25)))
    NxTest.assert_equal('color', NxMR1A::M.sheet('S25')['appearance']['mode'])
  end
end

NxTest.test('mr1a: stale legacy upserty pod zamkom zachovaju native aj color a odmietnu klientsky descriptor') do
  NxMR1A.isolated do
    old_sheet = NxMR1A::M.sheet('S18')
    old_edge = NxMR1A::M.edge('E')
    %w[native color].each do |mode|
      NxMR1A.publish(mode)
      current = NxMR1A.scope['appearance']
      forged = old_sheet.merge('price_per_m2' => 99, 'appearance' => { 'path' => 'forged' })
      NxTest.assert(NxMR1A::M.upsert_sheet(forged))
      NxTest.assert(NxMR1A::M.upsert_sheet_with_duplak_sync(old_sheet.merge('price_per_m2' => 98)))
      NxTest.assert(NxMR1A::M.upsert_edge(old_edge.merge('price_per_bm' => 3)))
      NxTest.assert(NxMR1A.all_main.all? { |rec| rec['appearance'] == current })
    end
    fresh = NxMR1A.raw
    (fresh['sheets'] + fresh['edges']).each { |rec| rec.delete('appearance') }
    NxMR1A.raw_write(fresh)
    NxTest.assert(NxMR1A::M.upsert_sheet(old_sheet.merge('appearance' => NxMR1A.descriptor)))
    NxTest.refute(NxMR1A::M.sheet('S18').key?('appearance'))
  end
end

NxTest.test('mr1a: upsert presun rodiny dedi ciel alebo odmietne konflikt') do
  NxMR1A.isolated do
    NxMR1A.publish
    moved = NxMR1A::M.sheet('S18').merge('group_id' => 'GRP-OTHER')
    NxTest.assert(NxMR1A::M.upsert_sheet(moved))
    NxTest.refute(NxMR1A::M.sheet('S18').key?('appearance'), 'nesmie preniest descriptor povodnej rodiny')
    NxTest.assert(NxMR1A::M.upsert_sheet(NxMR1A::M.sheet('S18').merge('group_id' => 'GRP-MR')))
    NxTest.assert_equal(NxMR1A::M.edge('E')['appearance'], NxMR1A::M.sheet('S18')['appearance'])
  end
end

NxTest.test('mr1a: source duplak dedi a nasleduje explicitny navrat k farbe') do
  NxMR1A.isolated do
    NxMR1A.publish
    status, dup = NxMR1A::M.create_duplak_sheet('S18', 2)
    NxTest.assert_equal(:ok, status, dup.inspect)
    NxTest.assert_equal(NxMR1A::M.sheet('S18')['appearance'], NxMR1A::M.sheet(dup['material_id'])['appearance'])
    before = File.binread(NxMR1A::M.path)
    NxTest.refute(NxMR1A::M.upsert_sheet_with_duplak_sync(NxMR1A::M.sheet('S18').merge('group_id' => 'OTHER')))
    NxTest.assert_equal(before, File.binread(NxMR1A::M.path), 'reparent zdroja nesmie preniest jeho vzhlad do cudzieho scope')
    NxMR1A.publish('color')
    NxTest.assert_equal('color', NxMR1A::M.sheet(dup['material_id'])['appearance']['mode'])
    data = NxMR1A.raw
    data['sheets'].find { |s| s['material_id'] == 'S18' }.delete('appearance')
    NxMR1A.raw_write(data)
    NxTest.assert(NxMR1A::M.upsert_sheet_with_duplak_sync(NxMR1A::M.sheet('S18')))
    NxTest.refute(NxMR1A::M.sheet(dup['material_id']).key?('appearance'))
  end
end

NxTest.test('mr1a: Demos create a batch novych hrubok/ABS preberu spolocny vzhlad') do
  NxMR1A.isolated do
    NxMR1A.publish
    desc = NxMR1A.scope['appearance']
    status, result = NxMR1A::M.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'H1180',
      'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 25, 'structure' => 'ST9', 'code' => 'MR25' }],
      'edge_items' => [{ 'width' => 43, 'thickness' => 1, 'structure' => 'ST9', 'code' => 'MRABS43' }])
    NxTest.assert_equal(:ok, status, result.inspect)
    NxTest.assert_equal(desc, NxMR1A::M.sheet(result['sheets'][0])['appearance'])
    NxTest.assert_equal(desc, NxMR1A::M.edge(result['edges'][0])['appearance'])
    ok, result = NxMR1A::M.add_decor_batch_v3(
      'manufacturer' => 'Egger', 'decor' => 'H1180', 'type' => 'DTDL',
      'sheet_variants' => [{ 'thickness' => 28, 'structure' => 'ST9' }],
      'edge_variants' => [{ 'width' => 43, 'thickness' => 2, 'structure' => 'ST9' }])
    NxTest.assert(ok, result.inspect)
    NxTest.assert_equal(desc, NxMR1A::M.sheet(result['sheets'][0])['appearance'])
    NxTest.assert_equal(desc, NxMR1A::M.edge(result['edges'][0])['appearance'])
  end
end

NxTest.test('mr1a: autoABS a save_decor zachovaju vzhľad') do
  NxMR1A.isolated do
    NxMR1A.publish('color')
    desc = NxMR1A.scope['appearance']
    NxTest.assert(NxMR1A::M.delete_edge('E'))
    status, id = NxMR1A::M.ensure_edge_for_sheet('S18', client_schema: 10)
    NxTest.assert_equal(:created, status)
    NxTest.assert_equal(desc, NxMR1A::M.edge(id)['appearance'])
    row = NxMR1A::M.sheet('S18')
    status, result = NxMR1A::M.save_decor(
      'mode' => 'edit', 'group_id' => 'GRP-MR', 'catalog_schema' => 10,
      'base_rev' => NxMR1A::M.catalog_revision,
      'sheets' => [{ 'material_id' => 'S18', 'row_rev' => NxMR1A::M.record_rev(row), 'price_per_m2' => 41,
                     'appearance' => NxMR1A.descriptor }])
    NxTest.assert_equal(:ok, status, result.inspect)
    NxTest.assert_equal(desc, NxMR1A::M.sheet('S18')['appearance'])
    NxTest.assert_equal(41.0, NxMR1A::M.sheet('S18')['price_per_m2'])
    # Aj riadok bez ID v tom istom editore musi dediť zo servera.
    status, result = NxMR1A::M.save_decor(
      'mode' => 'edit', 'group_id' => 'GRP-MR', 'catalog_schema' => 10,
      'base_rev' => NxMR1A::M.catalog_revision,
      'sheets' => [{ 'type' => 'DTDL', 'thickness' => 25, 'structure' => 'ST9' }],
      'edges' => [{ 'width' => 43, 'thickness' => 1, 'structure' => 'ST9' }])
    NxTest.assert_equal(:ok, status, result.inspect)
    NxTest.assert_equal(2, result['created'].length)
    NxTest.assert(NxMR1A.all_main.all? { |rec| rec['appearance'] == desc })
  end
end

NxTest.test('mr1a: poskodeny alebo novsi descriptor a novsia schema neprepise ani cena zo stareho procesu') do
  NxMR1A.isolated do
    [nil, NxMR1A.descriptor.merge('version' => 2), NxMR1A.descriptor.merge('path' => '/etc')].each do |bad|
      data = NxMR1A.raw
      data['sheets'][0]['appearance'] = bad
      data['schema'] = 10
      NxMR1A.raw_write(data)
      before = File.binread(NxMR1A::M.path)
      NxTest.assert_equal(:read_only, NxMR1A::M.assess_catalog_schema(data)[0])
      NxTest.refute(NxMR1A::M.write(data.merge('sheets' => data['sheets'].map { |s| s.reject { |key, _v| key == 'appearance' } })))
      NxTest.assert_equal(before, File.binread(NxMR1A::M.path))
      NxTest.refute(NxMR1A::M.appearance_scope('sheet', 'S18')[0] == :ok)
    end
    data = NxMR1A.raw
    data['sheets'][0].delete('appearance')
    data['schema'] = 11
    NxMR1A.raw_write(data)
    NxTest.refute(NxMR1A::M.write(data.merge('schema' => 9)))
  end
end

NxTest.test('mr1a: chybejuci/poskodeny primar sa pri publikacii neopravuje zo starej bak') do
  NxMR1A.isolated do
    old = NxMR1A.scope['baseline']
    File.binwrite("#{NxMR1A::M.path}.bak", File.binread(NxMR1A::M.path))
    File.binwrite(NxMR1A::M.path, '{broken')
    status, = NxMR1A::M.publish_appearance('sheet', 'S18', baseline: old, mode: 'color')
    NxTest.assert_equal(:invalid, status)
    NxTest.assert_equal('{broken', File.binread(NxMR1A::M.path))
  end
end

NxTest.test('mr1a: UNI a legacy bez group_id nemaju vzhľad ani cez ABS anchor') do
  NxMR1A.isolated do
    data = NxMR1A.raw
    data['sheets'][0]['uni'] = true
    NxMR1A.raw_write(data)
    NxTest.assert_equal(:invalid, NxMR1A::M.appearance_scope('sheet', 'S18')[0])
    NxTest.assert_equal(:ok, NxMR1A.publish('color', 'edge', 'E')[0])
    NxTest.refute(NxMR1A::M.sheet('S18').key?('appearance'))
    NxTest.assert_raise { NxMR1A::M.normalize_sheet(NxMR1A.sheet('U').merge('uni' => true, 'appearance' => NxMR1A.descriptor('color'))) }
    data = NxMR1A.raw
    (data['sheets'] + data['edges']).each { |r| r.delete('group_id'); r.delete('appearance') }
    data['schema'] = 1
    NxMR1A.raw_write(data)
    NxTest.assert_equal(:invalid, NxMR1A::M.appearance_scope('sheet', 'S16')[0])
  end
end

NxTest.test('mr1a: exporter failure a subezna publikacia ponechaju stare data; staging sa uprace') do
  NxMR1A.isolated do
    before = File.binread(NxMR1A::M.path)
    status, = NxMR1A.publish { |file, _desc, _scope| File.binwrite(file, 'partial'); false }
    NxTest.assert_equal(:invalid, status)
    NxTest.assert_equal(before, File.binread(NxMR1A::M.path))
    status, = NxMR1A.publish do |file, _desc, _scope|
      File.binwrite(file, 'saved but stale')
      NxTest.assert_equal(:ok, NxMR1A.publish('color')[0])
      true
    end
    NxTest.assert_equal(:stale, status)
    NxTest.assert_equal('color', NxMR1A.scope['appearance']['mode'])
    NxTest.assert_equal([], Dir[File.join(NxMR1A::M.dir, 'appearances', '*')])
  end
end

NxTest.test('mr1a: JSON failure ponecha stary descriptor/subor a nanajvys novy orphan') do
  NxMR1A.isolated do
    NxMR1A.publish
    previous = NxMR1A.scope['appearance']
    before = File.binread(NxMR1A::M.path)
    writer = NxMR1A::J.method(:write)
    NxMR1A::J.define_singleton_method(:write) { |_path, _data, **_kwargs| false }
    begin
      status, = NxMR1A.publish
      NxTest.assert_equal(:write_failed, status)
      NxTest.assert_equal(before, File.binread(NxMR1A::M.path))
      NxTest.assert(File.exist?(NxMR1A::M.appearance_file(previous['id'])))
      NxTest.assert_equal(2, Dir[File.join(NxMR1A::M.dir, 'appearances', '*.skm')].length)
    ensure
      NxMR1A::J.define_singleton_method(:write, writer)
    end
  end
end

NxTest.test('mr1a: read-only latch zastavi exporter a vynimka exportera nepublikuje partial') do
  NxMR1A.isolated do
    NxMR1A::M.instance_variable_set(:@catalog_state, :read_only)
    called = false
    status, = NxMR1A.publish { called = true; true }
    NxTest.assert_equal(:catalog_read_only, status)
    NxTest.refute(called)
    NxMR1A::M.reset_catalog_state!
    before = File.binread(NxMR1A::M.path)
    status, = NxMR1A.publish do |file, _desc, _scope|
      File.binwrite(file, 'partial')
      raise 'native export failed'
    end
    NxTest.assert_equal(:invalid, status)
    NxTest.assert_equal(before, File.binread(NxMR1A::M.path))
    NxTest.assert_equal([], Dir[File.join(NxMR1A::M.dir, 'appearances', '*')])
  end
end
