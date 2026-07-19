# frozen_string_literal: true
# Testy D-19 odhadu platni (core/sheet_estimate.rb) — rozsah 10-25 %, robustny
# ceil na desatinu, fallback formatu, kontrakt "kazdy BOM material prave raz".
require_relative '../helper' unless defined?(NxTest)

module NxSE
  module_function

  def se
    Noxun::Engine::SheetEstimate
  end

  def row(over = {})
    { 'material_id' => 'MAT', 'length' => 1000.0, 'width' => 500.0, 'quantity' => 2 }.merge(over)
  end
end

NxTest.test('sheet_estimate: m2 a rozsah platni z riadkov (nie suctov)') do
  # 2x (1.0 x 0.5) = 1.0 m2; platna 2.8x2.07 = 5.796 m2
  out = NxSE.se.estimate([NxSE.row], sheet_sizes: { 'MAT' => [2800, 2070] })
  NxTest.assert_equal(1, out.length)
  g = out.first
  NxTest.assert_close(1.0, g['m2'], 0.001)
  NxTest.assert_equal(2, g['quantity'])
  NxTest.assert_equal([2800.0, 2070.0], g['sheet_size'])
  NxTest.assert_equal(false, g['fallback'])
  # 1.0*1.10/5.796 = 0.1897 -> 0.2 ; 1.0*1.25/5.796 = 0.2157 -> 0.3
  NxTest.assert_close(0.2, g['count_min'], 0.001)
  NxTest.assert_close(0.3, g['count_max'], 0.001)
end

NxTest.test('sheet_estimate: ceil_tenth — presna hranica nepreskoci, tesne nad ide hore (F6)') do
  v = NxSE.se
  NxTest.assert_close(4.5, v.ceil_tenth(4.5), 0.0001, 'presne 4.5 ostava 4.5')
  NxTest.assert_close(4.5, v.ceil_tenth(4.500000000000001), 0.0001, 'float drift sa nesmie prejavit')
  NxTest.assert_close(4.6, v.ceil_tenth(4.51), 0.0001)
  NxTest.assert_close(4.6, v.ceil_tenth(4.5001), 0.0001, 'realne nad hranicou ide hore')
  NxTest.assert_close(0.1, v.ceil_tenth(0.001), 0.0001, 'aj malicka plocha = aspon 0.1')
  NxTest.assert_close(0.0, v.ceil_tenth(0.0), 0.0001)
end

NxTest.test('sheet_estimate: chybajuci/poskodeny format = fallback 2800x2070 + priznak (F4)') do
  rows = [NxSE.row('material_id' => 'BEZ_FORMATU'),
          NxSE.row('material_id' => 'ZLY_FORMAT'),
          NxSE.row('material_id' => 'NULOVY')]
  sizes = { 'ZLY_FORMAT' => ['abc', 2070], 'NULOVY' => [0, 2070] }
  out = NxSE.se.estimate(rows, sheet_sizes: sizes)
  NxTest.assert_equal(3, out.length)
  out.each do |g|
    NxTest.assert_equal(true, g['fallback'], "#{g['material_id']} ma mat fallback")
    NxTest.assert_equal([2800.0, 2070.0], g['sheet_size'])
    NxTest.assert(g['count_min'].positive?, 'fallback nikdy nedeli nulou')
  end
end

NxTest.test('sheet_estimate: kontrakt — kazdy material prave raz, poradie vstupu nehra rolu (N10)') do
  rows_a = [NxSE.row('material_id' => 'B'), NxSE.row('material_id' => 'A'),
            NxSE.row('material_id' => 'B', 'length' => 400.0)]
  rows_b = rows_a.reverse
  out_a = NxSE.se.estimate(rows_a)
  out_b = NxSE.se.estimate(rows_b)
  NxTest.assert_equal(out_a, out_b, 'vysledok nezavisi od poradia vstupu')
  NxTest.assert_equal(%w[A B], out_a.map { |g| g['material_id'] })
  b = out_a.find { |g| g['material_id'] == 'B' }
  NxTest.assert_close(1.0 + 0.4, b['m2'], 0.001, 'riadky toho isteho materialu sa scitaju')
end

NxTest.test('sheet_estimate: neplatne koeficienty a prazdny vstup') do
  out = NxSE.se.estimate([NxSE.row], k_min: 5.0, k_max: 1.0) # obrateny rozsah -> defaulty
  g = out.first
  NxTest.assert(g['count_min'] <= g['count_max'], 'rozsah nesmie byt obrateny')
  out2 = NxSE.se.estimate([NxSE.row], k_min: 'abc', k_max: nil)
  NxTest.assert(out2.first['count_min'].positive?)
  NxTest.assert_equal([], NxSE.se.estimate([]))
  NxTest.assert_equal([], NxSE.se.estimate([NxSE.row('quantity' => 0)]), 'nulove kusy = nic')
  NxTest.assert_equal([], NxSE.se.estimate([NxSE.row('material_id' => '')]), 'bez materialu = nic')
end
