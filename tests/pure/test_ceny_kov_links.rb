# frozen_string_literal: true
# CENY-KOV-A: odkazy su citacie; zapis URL nesmie menit ceny ani orezať cudzie data.
require_relative '../helper' unless defined?(NxTest)
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog') if NxTest.headless?

module CkaLinks
  H = Noxun::Engine::HardwareCatalog
  S = Noxun::Engine::JsonFileStore
  D = Noxun::Engine::HardwareCatalogDialog
  module_function

  def item(code = 'A', extra = {})
    { 'item_code' => code, 'name_sk' => "Položka #{code}", 'category' => 'OSTATNE',
      'unit' => 'ks', 'price_eur_vat' => 12.5 }.merge(extra)
  end

  def write(items, schema: H.schema_for(items), seed: H::SEED_SET_VERSION)
    FileUtils.mkdir_p(H.dir)
    File.binwrite(H.path, JSON.generate('std' => H::STD, 'schema' => schema,
                                       'seed_version' => seed, 'items' => items))
    FileUtils.rm_f("#{H.path}.bak")
    S.invalidate(H.path)
    H.reset_state!
  end

  def call(action, payload)
    out = []
    D.dispatch(action, JSON.generate(payload), ->(s) { out << s })
    out
  end

  def replace_method(target, name, impl)
    old = target.method(name) if target.respond_to?(name)
    target.define_singleton_method(name, &impl)
    yield
  ensure
    if old
      target.define_singleton_method(name, old)
    else
      target.singleton_class.send(:remove_method, name)
    end
  end
end

NxTest.test('CENY-KOV-A: URL CRUD roundtrip, prazdne sparse, lazy schema a ziadny cenovy zapis') do
  c = CkaLinks
  h = c::H
  c.write([])
  st, rec = h.create_item(c.item('A', 'product_url' => ' https://shop.example/p?a=1&b=2 '))
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal('https://shop.example/p?a=1&b=2', rec['product_url'])
  NxTest.assert_equal(3, JSON.parse(File.binread(h.path))['schema'])
  h.reset_state!
  NxTest.assert_equal(rec, h.find('a'), 'reload nesmie zahodit URL')
  NxTest.refute(rec.key?('demos_url'), 'Demos host ani vseobecny URL nevytvaraju vazbu')
  NxTest.refute(rec.key?('price_checked_at'), 'ulozenie URL nie je overenie ceny')
  st, changed = h.patch_item('A', { 'product_url' => 'https://www.demos-trade.sk/product/' }, row_rev: h.record_rev(rec))
  NxTest.assert_equal(:ok, st)
  NxTest.refute(changed.key?('demos_url'), 'Demos host v product_url ostava rucny')
  NxTest.assert_equal(12.5, changed['price_eur_vat'])
  st, cleared = h.patch_item('A', { 'product_url' => ' ' }, row_rev: h.record_rev(changed))
  NxTest.assert_equal(:ok, st)
  NxTest.refute(cleared.key?('product_url'), 'prazdny URL sa neuklada')
  NxTest.assert_equal(1, JSON.parse(File.binread(h.path))['schema'], 'marker sleduje obsah')
  NxTest.assert_equal(2, h.schema_for([c.item('A', 'manufacturer' => 'Blum')]))
  NxTest.assert_equal(:ok, h.delete_item('A', row_rev: h.record_rev(cleared))[0])
end

NxTest.test('CENY-KOV-A: URL sanitizacia a typ guard odmietnu ne-web zdroje') do
  h = CkaLinks::H
  ['javascript:alert(1)', 'file:///C:/x', 'data:text/html,x', '//example.com/p',
   'https:///missing', "https://x.test/a\nb", 'https://x.test/"x', 'https://x.test/\\x',
   nil, 3, {}, []].each do |bad|
    NxTest.assert_equal(nil, h.sanitize_product_url(bad), bad.inspect)
    NxTest.assert_equal(nil, h.normalize_item(CkaLinks.item('A', 'product_url' => bad))[0], bad.inspect)
  end
  NxTest.assert_equal('http://shop.example/p', h.sanitize_product_url('http://shop.example/p'))
  NxTest.assert_equal('https://demos.example/p', h.product_link(
                        'demos_url' => 'https://demos.example/p', 'product_url' => 'https://other.example/p'))
  NxTest.assert_equal(nil, h.product_link('demos_url' => 'javascript:x', 'product_url' => 'https://other.example/p'),
                      'poskodena Demos vazba nesmie otvorit iny zdroj')
  CkaLinks.write([CkaLinks.item('A', 'product_url' => {})])
  before = File.binread(h.path)
  NxTest.assert_equal(:read_only, h.assess!)
  NxTest.assert_equal(before, File.binread(h.path))
end

NxTest.test('CENY-KOV-A: cached ok + poskodene cudzie B sa pri uprave A nikdy neodfiltruje do zapisu') do
  c = CkaLinks
  h = c::H
  [nil, c.item('B', 'product_url' => {}), c.item('B', 'manufacturer' => []), c.item('a')].each do |bad|
    a = c.item
    c.write([a])
    NxTest.assert_equal(:ok, h.assess!)
    rev = h.record_rev(h.find('A'))
    doc = JSON.parse(File.binread(h.path))
    doc['items'] << bad
    File.binwrite(h.path, JSON.generate(doc)) # cudzi zapis bez resetu cached :ok
    before = File.binread(h.path)
    NxTest.assert_equal(:write_failed, h.patch_item('A', { 'notes' => 'edit A' }, row_rev: rev)[0])
    NxTest.assert_equal(before, File.binread(h.path), 'cely cerstvy dokument ostal bajtovo rovnaky')
    NxTest.assert_equal(:read_only, h.state)
  end
  ['{broken', JSON.generate('std' => h::STD, 'schema' => 3, 'items' => {})].each do |bad|
    c.write([c.item])
    h.assess!
    File.binwrite(h.path, bad)
    NxTest.refute(h.with_lock { h.write_unlocked('items' => [c.item]) })
    NxTest.assert_equal(bad, File.binread(h.path))
  end
end

NxTest.test('CENY-KOV-A: seed v6 meni len URL 8 znamych kodov s presnou povodnou poznamkou') do
  c = CkaLinks
  h = c::H
  rows = h::SEED_PRODUCT_CODES.map do |code|
    h::SEED_ITEMS.find { |i| i['item_code'] == code }.reject { |k, _| k == 'product_url' }
  end
  rows[0] = rows[0].merge('name_sk' => 'Moje meno', 'price_eur_vat' => 99.0, 'active' => false,
                        'price_checked_at' => '2020-01-01T00:00:00Z', 'use_count' => 7)
  rows[1] = rows[1].merge('notes' => 'moja poznamka')
  rows[2] = rows[2].merge('product_url' => 'https://my.example/p')
  rows[3] = rows[3].merge('demos_url' => 'https://www.demos-trade.sk/my/')
  rows << c.item('USER', 'notes' => rows[4]['notes'])
  before = Marshal.load(Marshal.dump(rows))
  c.write(rows, seed: 5)
  NxTest.assert_equal(:ok, h.assess!)
  after = h.items
  NxTest.assert_equal(before.length, after.length, 'ziadne dalsie seed riadky sa nevzkriesia')
  before.each_with_index do |rec, idx|
    expected = rec.dup
    expected['product_url'] = h::SEED_PRODUCT_LINKS[rec['item_code']]['product_url'] if [0, 4, 5, 6, 7].include?(idx)
    NxTest.assert_equal(expected, after[idx], "presny rozdiel pre #{rec['item_code']}")
  end
  NxTest.assert_equal(6, JSON.parse(File.binread(h.path))['seed_version'])
  NxTest.assert_equal(3, JSON.parse(File.binread(h.path))['schema'])
  raw = File.binread(h.path)
  h.reset_state!
  h.assess!
  NxTest.assert_equal(raw, File.binread(h.path), 'druhy start nic neprepisuje')
end

NxTest.test('CENY-KOV-A: prepare/open citaju cerstvy URL, nepisu, readonly moze otvorit, cudzi model nie') do
  NxTest.skip!('headless UI stub') unless NxTest.headless?
  c = CkaLinks
  h = c::H
  made_su = !Object.const_defined?(:Sketchup)
  made_ui = !Object.const_defined?(:UI)
  Object.const_set(:Sketchup, Module.new) if made_su
  Object.const_set(:UI, Module.new) if made_ui
  model = Struct.new(:path).new('')
  opened = []
  c.replace_method(Sketchup, :active_model, -> { model }) do
    c.replace_method(UI, :openURL, ->(url) { opened << url; true }) do
      guid = Noxun::Engine::DocKey.key(model)
      c.write([c.item('A', 'product_url' => 'https://shop.example/old')], schema: 99)
      req = { 'code' => 'A', 'token' => 'r1', 'section' => 'budget', 'model_guid' => guid }
      before = File.binread(h.path)
      js = c.call('hw_product_prepare', req).find { |s| s.start_with?('MDH.productReady(') }
      reply = JSON.parse(js.sub('MDH.productReady(', '').sub(/\)\z/, ''))
      NxTest.assert_equal(true, reply['has_url'])
      NxTest.assert_equal(true, reply['read_only'])
      NxTest.assert_equal('r1', reply['token'])
      NxTest.assert_equal([], opened, 'prepare sam neotvara browser')
      NxTest.assert_equal(before, File.binread(h.path))
      c.write([c.item('A', 'product_url' => 'https://shop.example/new')], schema: 99)
      before = File.binread(h.path)
      c.call('hw_product_open', req.merge('url' => 'javascript:evil'))
      NxTest.assert_equal(['https://shop.example/new'], opened, 'server nepouzije echo ani stary URL')
      c.call('hw_product_open', req.merge('model_guid' => 'foreign'))
      NxTest.assert_equal(1, opened.length)
      NxTest.assert_equal(before, File.binread(h.path), 'ani newer readonly katalog sa nemigruje')
      backup = JSON.generate('std' => h::STD, 'schema' => 3,
                             'seed_version' => h::SEED_SET_VERSION,
                             'items' => [c.item('A', 'product_url' => 'https://backup.example/p')])
      ['{broken', nil].each do |primary|
        File.binwrite("#{h.path}.bak", backup)
        primary ? File.binwrite(h.path, primary) : FileUtils.rm_f(h.path)
        c.call('hw_product_open', req)
        NxTest.assert_equal('https://backup.example/p', opened.last, 'citatelna readonly zaloha ma funkcny odkaz')
        NxTest.assert_equal(primary, File.exist?(h.path) ? File.binread(h.path) : nil)
        NxTest.assert_equal(backup, File.binread("#{h.path}.bak"))
        NxTest.assert(h.product_edit_reason, 'zaloha nepripusta edit')
      end
      c.write([c.item])
      reply_js = c.call('hw_product_prepare', req).find { |s| s.start_with?('MDH.productReady(') }
      missing = JSON.parse(reply_js.sub('MDH.productReady(', '').sub(/\)\z/, ''))
      NxTest.assert_equal(false, missing['has_url'])
      NxTest.assert_equal('A', missing['item']['item_code'])
      NxTest.assert_equal(h.record_rev(c.item), missing['row_rev'])
      NxTest.assert(missing['context']['units'].include?('ks'), 'editor ma enumy aj mimo stromu')
    end
  end
ensure
  Object.send(:remove_const, :Sketchup) if made_su
  Object.send(:remove_const, :UI) if made_ui
end
