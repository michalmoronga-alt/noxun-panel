# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)
require 'tmpdir'

module CkbBudget
  B = Noxun::Engine::Budget
  P = Noxun::Engine::PriceRefresh
  NOW = Time.utc(2026, 9, 10, 12)
  module_function

  def item(over = {})
    { 'item_code' => 'M', 'name_sk' => 'Ručná položka', 'category' => 'OSTATNE',
      'unit' => 'bal', 'price_eur_vat' => 12.5, 'supplier' => 'Test',
      'product_url' => 'https://supplier.example/product',
      'price_check_method' => 'manual', 'price_checked_at' => (NOW - 29 * 86_400).iso8601 }.merge(over)
  end

  def fresh(rec, days = 30)
    B.freshness_item('hardware', rec['item_code'], rec['name_sk'], rec, days, NOW)
  end

  def budget(items, used = ['M'], now: NOW)
    rows = items.select { |i| used.include?(i['item_code']) }.map do |i|
      { 'code' => i['item_code'], 'name_sk' => i['name_sk'], 'unit' => i['unit'],
        'quantity' => 3, 'price_eur_vat' => i['price_eur_vat'] }
    end
    B.compute({ rows: [], edging: [] }, {}, Noxun::Engine::SupplierSettings.seed_supplier,
      hardware_expansion: { 'rows' => rows }, hardware_catalog: items, now: now)
  end
end

NxTest.test('CENY-KOV-B integracia: skutocne katalogove potvrdenie prepocita cenu aj upozornenie') do
  NxTest.skip!('izolovana katalogova integracia') unless NxTest.headless?
  c = CkbBudget
  h = Noxun::Engine::HardwareCatalog
  mat = Noxun::Engine::Materials
  previous_dir = mat.test_dir_override
  Dir.mktmpdir('ceny-kov-budget-') do |dir|
    mat.test_dir_override = dir
    h.reset_state!
    rec = c.item.reject { |k, _| %w[price_check_method price_checked_at].include?(k) }
    File.binwrite(h.path, JSON.generate('std' => h::STD, 'schema' => h.schema_for([rec]),
      'seed_version' => h::SEED_SET_VERSION, 'items' => [rec]))
    Noxun::Engine::JsonFileStore.invalidate(h.path)
    before = c.budget(h.items)
    NxTest.assert_equal(1, before['stale']['counts']['attention'])
    status, confirmed = h.confirm_manual_price!('M', price: '14,00', row_rev: h.record_rev(h.find('M')))
    NxTest.assert_equal(:ok, status)
    checked_now = Time.iso8601(confirmed['price_checked_at']) + 1
    after = c.budget(h.items, now: checked_now)
    NxTest.assert_equal(0, after['stale']['counts']['attention'])
    NxTest.assert_close(42.0, after['sections'].find { |s| s['key'] == 'hardware' }['subtotal'], 0.001)
    NxTest.assert_equal([], c::P.manual_from_budget(after))
    status, = h.patch_item('M', { 'product_url' => 'https://supplier.example/another' }, row_rev: h.record_rev(confirmed))
    NxTest.assert_equal(:ok, status)
    changed = c.budget(h.items, now: checked_now)
    NxTest.assert_equal(1, changed['stale']['counts']['attention'], 'zmena zdroja vrati kontrolu bez zmeny ceny')
    NxTest.assert_close(42.0, changed['sections'].find { |s| s['key'] == 'hardware' }['subtotal'], 0.001)
  end
ensure
  mat.test_dir_override = previous_dir if mat
  h.reset_state! if h
end

NxTest.test('CENY-KOV-B budget: manualny den 29/30 a nastavitelny prah su rovnake ako Demos') do
  c = CkbBudget
  NxTest.assert_equal('fresh', c.fresh(c.item)['state'])
  day30 = c.item('price_checked_at' => (c::NOW - 30 * 86_400).iso8601)
  NxTest.assert_equal('stale', c.fresh(day30)['state'])
  NxTest.assert_equal(30, c.fresh(day30)['age_days'])
  NxTest.assert_equal('fresh', c.fresh(day30, 45)['state'])
  day45 = c.item('price_checked_at' => (c::NOW - 45 * 86_400).iso8601)
  NxTest.assert_equal('stale', c.fresh(day45, 45)['state'])
  NxTest.assert_equal('fresh', c.fresh(c.item('price_eur_vat' => 0))['state'], 'nula je platna cena')
  NxTest.assert_equal('manual', c.fresh(day30)['price_check_method'], 'povod nezanika zostarnutim')
end

NxTest.test('CENY-KOV-B budget: neplatne alebo buduce potvrdenie nemoze skryt potrebnu kontrolu') do
  c = CkbBudget
  invalid = [
    { 'price_check_method' => nil }, { 'price_check_method' => 'future' },
    { 'price_checked_at' => '' }, { 'price_checked_at' => 'vcera' },
    { 'price_checked_at' => '2026-09-10' }, { 'price_checked_at' => (c::NOW + 1).iso8601 },
    { 'price_eur_vat' => nil }, { 'price_eur_vat' => -1 }, { 'price_eur_vat' => Float::NAN },
    { 'price_eur_vat' => Float::INFINITY }, { 'price_eur_vat' => '12.5' },
    { 'price_eur_vat' => Complex(1, 2) }, { 'unit' => 'unknown' },
    { 'product_url' => nil }, { 'product_url' => 'javascript:alert(1)' }
  ]
  invalid.each do |over|
    f = c.fresh(c.item(over))
    NxTest.assert_equal('manual', f['state'], over.inspect)
    NxTest.assert_equal(nil, f['checked_at'], 'neplatny datum sa netvari ako potvrdeny')
  end
end

NxTest.test('CENY-KOV-B budget: iba pouzite manualne ceny upozornuju a po potvrdeni zmiznu') do
  c = CkbBudget
  rec = c.item('price_check_method' => nil)
  unused = c.item('item_code' => 'UNUSED', 'price_check_method' => nil)
  before = Marshal.dump([rec, unused])
  p = c.budget([rec, unused])
  NxTest.assert_equal(1, p['stale']['counts']['manual_hardware'])
  NxTest.assert_equal(1, p['stale']['counts']['attention'])
  NxTest.assert_equal(['M'], p['stale']['items'].map { |i| i['id'] })
  hw = p['sections'].find { |s| s['key'] == 'hardware' }
  NxTest.assert_close(37.5, hw['subtotal'], 0.001)
  NxTest.assert_equal('manual', hw['rows'][0]['price_check']['state'])
  NxTest.assert_equal(before, Marshal.dump([rec, unused]), 'scan nezapisuje do vstupu')
  confirmed = c.item('price_eur_vat' => 14.0, 'price_checked_at' => c::NOW.iso8601)
  fresh = c.budget([confirmed, unused])
  NxTest.assert_equal(0, fresh['stale']['counts']['manual_hardware'])
  NxTest.assert_equal(0, fresh['stale']['counts']['attention'])
  NxTest.assert_equal([], fresh['stale']['items'])
  NxTest.assert_equal([], c::P.manual_from_budget(fresh))
  hw = fresh['sections'].find { |s| s['key'] == 'hardware' }
  NxTest.assert_close(42.0, hw['subtotal'], 0.001)
  NxTest.assert_equal('fresh', hw['rows'][0]['price_check']['state'])
  missing = c.budget([c.item('price_eur_vat' => nil)])
  NxTest.assert(missing['sections'].find { |s| s['key'] == 'hardware' }['rows'][0]['price_missing'])
  NxTest.assert_equal(1, missing['stale']['counts']['attention'])
end

NxTest.test('CENY-KOV-B budget: Demos a materialy ABS si zachovaju autoritu a manualny URL sa nefetchuje') do
  c = CkbBudget
  bound = c.item('demos_url' => 'https://www.demos-trade.sk/p/', 'price_check_method' => nil)
  NxTest.assert_equal('fresh', c.fresh(bound)['state'])
  NxTest.refute(c.fresh(bound).key?('manual_check'))
  %w[sheet edge].each do |kind|
    f = c::B.freshness_item(kind, 'X', 'Materiál', c.item, 30, c::NOW)
    NxTest.assert_equal('manual', f['state'], 'manual overenie kovania sa neprenasa na materialy/ABS')
  end
  old = c.item('price_checked_at' => (c::NOW - 40 * 86_400).iso8601,
               'product_url' => 'https://www.demos-trade.sk/manual-looking-url/')
  p = c.budget([old])
  NxTest.assert_equal(1, p['stale']['counts']['stale'])
  NxTest.assert_equal(1, p['stale']['counts']['manual_hardware'])
  NxTest.assert_equal(1, p['stale']['counts']['attention'], 'stara rucna cena sa nepocita dvakrat')
  NxTest.assert_equal([], c::P.targets_from_budget(p), 'ani Demos host v product_url nie je vazba')
  NxTest.assert_equal(['M'], c::P.manual_from_budget(p).map { |i| i['id'] })
  NxTest.assert_equal([], c::P.manual_from_budget('stale' => { 'items' => [c.fresh(c.item)] }))
end
