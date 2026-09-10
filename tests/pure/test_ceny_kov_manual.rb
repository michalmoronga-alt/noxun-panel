# frozen_string_literal: true
require_relative 'test_ceny_kov_links'

module CkbManual
  H = CkaLinks::H
  module_function
  def item(extra = {})
    CkaLinks.item('A', { 'product_url' => 'https://shop.example/a', 'supplier' => 'Obchod' }.merge(extra))
  end
  def checked(extra = {})
    item('price_check_method' => 'manual', 'price_checked_at' => '2026-08-01T08:00:00Z').merge(extra)
  end
  def confirm(rec, price = '12,5')
    CkaLinks.write([rec])
    H.confirm_manual_price!('A', price: price, row_rev: H.record_rev(rec))
  end
end

NxTest.test('CENY-KOV-B: potvrdenie nezmenenej/zmenenej/nulovej ceny je atomicke a serverove') do
  h = CkbManual::H
  [12.5, 20.0, 0.0].each do |amount|
    before_time = Time.now.utc - 1
    status, rec = CkbManual.confirm(CkbManual.item, amount)
    NxTest.assert_equal(:ok, status)
    NxTest.assert_equal(amount, rec['price_eur_vat'])
    NxTest.assert_equal('manual', rec['price_check_method'])
    NxTest.assert(Time.iso8601(rec['price_checked_at']) >= before_time)
    NxTest.assert(Time.iso8601(rec['price_checked_at']) <= Time.now.utc)
    NxTest.assert_equal(4, JSON.parse(File.binread(h.path))['schema'])
    h.reset_state!
    NxTest.assert_equal(rec, h.find('A'), 'reload zachova celu potvrdenu trojicu')
  end
  [nil, '', ' ', 'abc', '-1', '1e999', Float::INFINITY, Float::NAN, false, {}].each do |bad|
    rec = CkbManual.item
    CkaLinks.write([rec])
    before = File.binread(h.path)
    NxTest.assert_equal(:invalid, h.confirm_manual_price!('A', price: bad, row_rev: h.record_rev(rec))[0], bad.inspect)
    NxTest.assert_equal(before, File.binread(h.path), 'neplatna cena nevytvori datum ani marker')
  end
end

NxTest.test('CENY-KOV-B: manual zapis odmieta stale rev, vymazanie, Demos, chyba URL/MJ a readonly') do
  h = CkbManual::H
  rec = CkbManual.item
  CkaLinks.write([rec])
  before = File.binread(h.path)
  NxTest.assert_equal(:conflict, h.confirm_manual_price!('A', price: 1, row_rev: 'stale')[0])
  NxTest.assert_equal(:not_found, h.confirm_manual_price!('B', price: 1, row_rev: h.record_rev(rec))[0])
  NxTest.assert_equal(before, File.binread(h.path))
  [{ 'demos_url' => 'https://www.demos-trade.sk/p/' }, { 'product_url' => '' },
   { 'product_url' => 'javascript:bad' }, { 'unit' => 'bad' }].each do |extra|
    row = rec.merge(extra)
    CkaLinks.write([row])
    before = File.binread(h.path)
    NxTest.assert_equal(:invalid, h.confirm_manual_price!('A', price: 1, row_rev: h.record_rev(row))[0])
    NxTest.assert_equal(before, File.binread(h.path))
  end
  CkaLinks.write([rec], schema: 99)
  before = File.binread(h.path)
  NxTest.assert_equal(:read_only, h.confirm_manual_price!('A', price: 1, row_rev: h.record_rev(rec))[0])
  NxTest.assert_equal(before, File.binread(h.path))
end

NxTest.test('CENY-KOV-B: bezne CRUD neprevezme stampy a rusi ich iba zmena cenoveho kontextu') do
  h = CkbManual::H
  CkaLinks.write([])
  st, made = h.create_item(CkbManual.checked('price_checked_at' => '2999-01-01T00:00:00Z'))
  NxTest.assert_equal(:ok, st)
  NxTest.refute(made.key?('price_check_method'))
  NxTest.refute(made.key?('price_checked_at'))
  NxTest.assert_equal(:exists, h.create_item(CkbManual.checked)[0], 'duplicate nevytvori overenie')
  { 'price_eur_vat' => '17', 'unit' => 'set', 'product_url' => 'https://shop.example/b',
    'supplier' => 'Iný', 'demos_url' => '' }.each do |key, value|
    row = CkbManual.checked
    CkaLinks.write([row])
    st, out = h.patch_item('A', { key => value }, row_rev: h.record_rev(row))
    NxTest.assert_equal(:ok, st)
    NxTest.refute(out.key?('price_check_method'), "#{key} rusi metodu")
    NxTest.refute(out.key?('price_checked_at'), "#{key} rusi datum")
  end
  [{ 'notes' => 'Nová poznámka' }, { 'name_sk' => 'Nový názov' }, { 'category' => 'NOHY' },
   { 'active' => false }, { 'price_eur_vat' => '12,500' }, { 'unit' => 'ks' },
   { 'product_url' => ' https://shop.example/a ' }, { 'supplier' => ' Obchod ' },
   { 'notes' => 'Názov', 'price_check_method' => 'evil', 'price_checked_at' => '2999-01-01T00:00:00Z' }].each do |patch|
    row = CkbManual.checked
    CkaLinks.write([row])
    st, out = h.patch_item('A', patch, row_rev: h.record_rev(row))
    NxTest.assert_equal(:ok, st)
    NxTest.assert_equal('manual', out['price_check_method'], patch.inspect)
    NxTest.assert_equal(row['price_checked_at'], out['price_checked_at'], patch.inspect)
  end
end

NxTest.test('CENY-KOV-B: Demos unchanged preberie zdroj bez manual markeru, conflict nic neprepise') do
  h = CkbManual::H
  rec = CkbManual.checked
  CkaLinks.write([rec])
  h.price_proposals['A'] = { 'pid' => 'p', 'base_row_rev' => h.record_rev(rec),
                            'final_url' => 'https://www.demos-trade.sk/p/', 'unchanged' => true }
  st, out = h.apply_price_proposal!('A', pid: 'p')
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal(12.5, out['price_eur_vat'])
  NxTest.refute(out.key?('price_check_method'))
  NxTest.refute(out.key?('product_url'))
  NxTest.assert(out.key?('demos_url'))
  CkaLinks.write([rec])
  h.price_proposals['A'] = { 'pid' => 'p', 'base_row_rev' => 'old', 'final_url' => 'https://www.demos-trade.sk/p/' }
  before = File.binread(h.path)
  NxTest.assert_equal(:conflict, h.apply_price_proposal!('A', pid: 'p')[0])
  NxTest.assert_equal(before, File.binread(h.path))
end

NxTest.test('CENY-KOV-B: marker typ, lazy downgrade a cudzie pokazene B zastavia cely zapis A') do
  h = CkbManual::H
  ['future', '', nil, 1, {}, []].each do |bad|
    row = CkaLinks.item('B', 'price_check_method' => bad)
    NxTest.refute(h.valid_stored_item?(row))
    CkaLinks.write([CkbManual.item])
    h.assess!
    doc = JSON.parse(File.binread(h.path))
    doc['items'] << row
    raw = JSON.generate(doc).b
    File.binwrite(h.path, raw)
    NxTest.assert_equal(:write_failed, h.confirm_manual_price!('A', price: 1, row_rev: h.record_rev(CkbManual.item))[0])
    NxTest.assert_equal(raw, File.binread(h.path))
  end
  CkaLinks.write([CkbManual.checked])
  old = h::SCHEMA_CURRENT
  h.send(:remove_const, :SCHEMA_CURRENT)
  h.const_set(:SCHEMA_CURRENT, h::SCHEMA_PRODUCT_URL)
  before = File.binread(h.path)
  NxTest.assert_equal(:read_only, h.assess!)
  NxTest.assert_equal(before, File.binread(h.path))
ensure
  if old
    h.send(:remove_const, :SCHEMA_CURRENT)
    h.const_set(:SCHEMA_CURRENT, old)
  end
  h.reset_state!
end

NxTest.test('CENY-KOV-B: historicky seed nezmeni rucne potvrdeny zdroj ani neozivi neplatny datum') do
  h = CkbManual::H
  legacy = h::SEED_ITEMS_V2.first.merge('product_url' => 'https://user.example/p',
                                      'price_check_method' => 'manual', 'price_checked_at' => '2026-08-01T00:00:00Z')
  rows = [legacy.dup]
  h.apply_seed_patch_v3(rows, h::SEED_ITEMS)
  NxTest.assert_equal(legacy, rows.find { |i| i['item_code'] == legacy['item_code'] })
  code = h::SEED_PRODUCT_CODES.first
  broken = h::SEED_ITEMS.find { |i| i['item_code'] == code }.reject { |k, _| k == 'product_url' }
  broken = broken.merge('price_check_method' => 'manual', 'price_checked_at' => '2026-08-01T00:00:00Z')
  CkaLinks.write([broken], seed: 5)
  h.assess!
  fixed = h.find(code)
  NxTest.assert(fixed.key?('product_url'))
  NxTest.refute(fixed.key?('price_check_method'), 'doplneny zdroj nesmie ozivit stary neplatny stamp')
  NxTest.refute(fixed.key?('price_checked_at'))
end

NxTest.test('CENY-KOV-B: callback prepare/open su read-only, confirm odpovie aj pri chybe/cudzom modeli') do
  NxTest.skip!('headless UI stub') unless NxTest.headless?
  c = CkaLinks
  h = CkbManual::H
  made_su = !Object.const_defined?(:Sketchup)
  made_ui = !Object.const_defined?(:UI)
  Object.const_set(:Sketchup, Module.new) if made_su
  Object.const_set(:UI, Module.new) if made_ui
  model = Struct.new(:path).new('')
  opened = []
  pushed = []
  parse = ->(scripts, fn) { s = scripts.find { |v| v.start_with?("#{fn}(") }; JSON.parse(s[(fn.length + 1)...-1]) }
  c.replace_method(Sketchup, :active_model, -> { model }) do
    c.replace_method(UI, :openURL, ->(url) { opened << url }) do
      c.replace_method(c::D, :push_items, ->(**_kw) { pushed << true }) do
        row = CkbManual.item
        c.write([row])
        req = { 'code' => 'A', 'token' => 'p', 'section' => 'budget',
                'model_guid' => Noxun::Engine::DocKey.key(model), 'row_rev' => h.record_rev(row) }
        before = File.binread(h.path)
        ready = parse.call(c.call('hw_manual_prepare', req), 'MDH.manualReady')
        NxTest.assert_equal(row, ready['item'])
        NxTest.assert_equal([], opened)
        open_ack = parse.call(c.call('hw_manual_open', req.merge('url' => 'https://wrong.example/p')), 'MDH.manualResult')
        NxTest.assert_equal('open', open_ack['phase'])
        NxTest.assert_equal(true, open_ack['ok'])
        NxTest.assert_equal('p', open_ack['token'])
        NxTest.assert_equal(['https://shop.example/a'], opened)
        NxTest.assert_equal(before, File.binread(h.path))
        result = parse.call(c.call('hw_manual_confirm', req.merge('price' => '0', 'price_checked_at' => '2999-01-01T00:00:00Z')), 'MDH.manualResult')
        NxTest.assert_equal(true, result['ok'])
        NxTest.assert_equal('p', result['token'])
        NxTest.assert_equal(0.0, h.find('A')['price_eur_vat'])
        NxTest.refute(h.find('A')['price_checked_at'].start_with?('2999'))
        NxTest.assert_equal(1, pushed.length)
        before = File.binread(h.path)
        stale = parse.call(c.call('hw_manual_confirm', req.merge('price' => '88')), 'MDH.manualResult')
        NxTest.assert_equal('conflict', stale['status'])
        NxTest.assert_equal(0.0, stale['item']['price_eur_vat'], 'conflict vracia aktualnu cenu')
        foreign = parse.call(c.call('hw_manual_confirm', req.merge('price' => '88', 'model_guid' => 'foreign')), 'MDH.manualResult')
        NxTest.assert_equal('stale_model', foreign['status'])
        NxTest.assert_equal(before, File.binread(h.path))
        c.replace_method(h, :confirm_manual_price!, ->(*_args, **_kw) { raise IOError, 'disk' }) do
          failed = parse.call(c.call('hw_manual_confirm', req.merge('price' => '12')), 'MDH.manualResult')
          NxTest.assert_equal(false, failed['ok'])
          NxTest.assert_equal('p', failed['token'], 'vynimka vrati token a odomkne povodny modal')
          NxTest.assert_equal('error', failed['status'])
        end
        late_open = parse.call(c.call('hw_manual_open', req), 'MDH.manualResult')
        NxTest.assert_equal('open', late_open['phase'])
        NxTest.assert_equal(1, opened.length, 'rev guard neotvori zmeneny zdroj vedla stareho formulára')
        c.replace_method(UI, :openURL, ->(_url) { false }) do
          failed_open = parse.call(c.call('hw_manual_open', req.merge('row_rev' => h.record_rev(h.find('A')))), 'MDH.manualResult')
          NxTest.assert_equal('open', failed_open['phase'])
          NxTest.assert_equal(false, failed_open['ok'], 'explicitne false otvarania nie je tichy uspech')
          NxTest.assert_equal('error', failed_open['status'])
        end
      end
    end
  end
ensure
  Object.send(:remove_const, :Sketchup) if made_su
  Object.send(:remove_const, :UI) if made_ui
end
