# frozen_string_literal: true
require_relative '../fixtures/h18b_golden/cases'

NxTest.test('H18b R0: zapis pred zasahom, 11 druhov x oba rozsahy') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  NxTest.assert_equal(NxH18b.fixture('zapis_pred'), JSON.parse(JSON.generate(NxH18b.packed)))
  NxTest.assert_equal(2816, NxH18b.cases.length)
end
NxTest.test('H18b R0: nakup realnych skriniek R1-R8 pred zasahom') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  NxTest.assert_equal(NxH18b.fixture('nakup_pred'), JSON.parse(JSON.generate(NxH18b.purchases)))
  NxTest.assert_equal(NxH18b.fixture('guarded_pred'), NxH18b.hashes)
end
