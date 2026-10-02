# frozen_string_literal: true
# H18 R0: prve asserty su zelene uz na STAROM kode. Plugin sa v prvom commite nemeni.
require_relative '../fixtures/h18_golden/cases'

NxTest.test('H18 T0 PRED: resolver, nakup a payload == golden pred zasahom') do
  NxTest.skip!('headless fixture context') unless NxTest.headless?
  expected = NxH18.fixture('resolver')
  payload = NxH18.fixture('payload_pred')
  NxH18.cases.each do |c|
    NxTest.assert_equal(expected.fetch(c['id']), NxH18.resolver(c), c['id'] + ' resolver')
    NxTest.assert_equal(payload.fetch(c['id']), NxH18.payload(c), c['id'] + ' payload')
  end
end

NxTest.test('H18 T0: klasifikovane zavesy expand + CSV + rozpocet + ponuka bajtovo') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  expected = File.read(File.join(NxH18::DIR, 'cena_zavesy.json'))
  NxTest.assert_equal(expected, NxH18.json(NxH18.prices))
end
