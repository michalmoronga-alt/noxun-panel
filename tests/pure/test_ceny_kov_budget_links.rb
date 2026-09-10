# frozen_string_literal: true
# CENY-KOV-A: odkaz je katalógový údaj, nemá meniť cenu ani vstup expanzie.
require_relative '../helper' unless defined?(NxTest)

NxTest.test('CENY-KOV-A budget: odkaz funguje nezavisle od ceny a Demos cerstvosti') do
  catalog = [
    { 'item_code' => 'D', 'demos_url' => 'https://www.demos-trade.sk/produkt/',
      'price_checked_at' => '2026-09-10T00:00:00Z' },
    { 'item_code' => 'M', 'product_url' => 'https://example.com/manual' },
    { 'item_code' => 'N' }
  ]
  expansion = { 'rows' => catalog.map.with_index { |item, i|
    { 'code' => item['item_code'], 'name_sk' => "Položka #{i}", 'unit' => 'ks',
      'quantity' => 2, 'price_eur_vat' => (i == 1 ? nil : 4.5) }
  } }
  before = Marshal.dump([expansion, catalog])
  result = Noxun::Engine::Budget.hardware_section(expansion, catalog)
  rows = result['rows']
  NxTest.assert_equal([true, true, false], rows.map { |r| r['product_link'] })
  NxTest.assert(rows[1]['price_missing'], 'odkaz nezamaskuje nezadanu cenu')
  NxTest.assert_close(9.0, rows[0]['spolu'], 0.001)
  NxTest.assert_close(18.0, result['subtotal'], 0.001)
  NxTest.assert_equal(before, Marshal.dump([expansion, catalog]), 'cisty vypocet nemeni vstupy')
end

NxTest.test('CENY-KOV-A budget: neplatna URL vyzaduje doplnenie, adresu klient nepouziva') do
  expansion = { 'rows' => [{ 'code' => 'Case', 'name_sk' => 'Test', 'unit' => 'ks', 'quantity' => 1,
                            'price_eur_vat' => 2.0 }] }
  ['javascript:alert(1)', 'file:///C:/test', 'https://'].each do |url|
    result = Noxun::Engine::Budget.hardware_section(expansion,
      [{ 'item_code' => 'CASE', 'product_url' => url }])
    NxTest.assert_equal(false, result['rows'][0]['product_link'], "neplatny odkaz #{url}")
    NxTest.refute(result['rows'][0].key?('product_url'), 'do rozpoctu ide iba stav, otvorenie riesi server')
  end
end

NxTest.test('CENY-KOV-A budget: volny a uz chybajuci katalogovy kod nema falosny editor') do
  result = Noxun::Engine::Budget.hardware_section({ 'rows' => [
    { 'code' => '', 'name_sk' => 'Voľná', 'unit' => 'ks', 'quantity' => 1,
      'price_eur_vat' => 2.0, 'free' => true, 'free_key' => 'free:cab:item' },
    { 'code' => 'DELETED', 'name_sk' => 'Zmazaná', 'unit' => 'ks', 'quantity' => 1,
      'price_eur_vat' => nil, 'missing' => true }
  ] }, [])
  NxTest.assert(result['rows'].none? { |r| r.key?('product_link') })
  NxTest.assert(result['rows'][1]['price_missing'])
end
