# frozen_string_literal: true
# Testy D-41 PR B: batch "Novy dekor" (Materials.add_decor_batch) — parse-all-
# validate-all (jediny chybny token = ziadny zapis), skip existujucich variantov,
# dedup v ramci davky, kumulativne ID, guardy (near-match dekor, vyrobca,
# desatinna ciarka). Vsetko headless (APPDATA sandbox).
require_relative '../helper' unless defined?(NxTest)

BMAT = Noxun::Engine::Materials

def bt_cleanup(result)
  return unless result.is_a?(Hash)
  (result['sheets'] || []).each { |id| BMAT.delete_sheet(id) }
  (result['edges'] || []).each { |id| BMAT.delete_edge(id) }
end

NxTest.test('decor-batch: happy path — dosky + ABS jednym zapisom, sirky ulozene') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = BMAT.add_decor_batch(
    'decor' => 'U702 ST9 Kasmirovo seda', 'manufacturer' => 'Egger', 'type' => 'DTDL',
    'grain' => 'length', 'color' => [120, 120, 118],
    'thicknesses' => '18, 36', 'abs_tokens' => '22/1, 43/1, 43/2'
  )
  NxTest.assert(ok, "batch mal prejst: #{res.inspect}")
  NxTest.assert_equal(2, res['sheets'].size)
  NxTest.assert_equal(3, res['edges'].size)
  NxTest.assert_equal([], res['skipped'])
  s18 = BMAT.sheet(res['sheets'][0])
  NxTest.assert_equal('U702 ST9 Kasmirovo seda', s18['decor'])
  NxTest.assert_equal('Egger U702 ST9 Kasmirovo seda', s18['family'])
  e22 = BMAT.edge(res['edges'][0])
  NxTest.assert_equal(22.0, e22['width'])
  NxTest.assert_equal('ABS_U702_ST9_KASMIROVO_SEDA_22X10', e22['abs_id'])
  # picker hned funguje: 18 mm dielec -> 22-ka, 36 mm -> 43-ka
  NxTest.assert_equal('ABS_U702_ST9_KASMIROVO_SEDA_22X10', BMAT.abs_for_decor('U702 ST9 Kasmirovo seda', 1.0, 18.0))
  NxTest.assert_equal('ABS_U702_ST9_KASMIROVO_SEDA_43X10', BMAT.abs_for_decor('U702 ST9 Kasmirovo seda', 1.0, 36.0))
  bt_cleanup(res)
end

NxTest.test('decor-batch: jediny chybny token zrusi CELU davku bez zapisu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  before = BMAT.catalog_revision
  ok, err = BMAT.add_decor_batch('decor' => 'Chybny Batch', 'thicknesses' => '18, abc', 'abs_tokens' => '22/1')
  NxTest.refute(ok)
  NxTest.assert(err.include?('abc'), "chyba menuje token: #{err}")
  NxTest.assert_equal(before, BMAT.catalog_revision, 'ziadny zapis pri chybe')
  NxTest.assert_equal(nil, BMAT.abs_for_decor('Chybny Batch', 1.0), 'ABS sa nevytvorila')
end

NxTest.test('decor-batch: desatinna ciarka = jasna chyba (ziadna ticha interpretacia)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, err = BMAT.add_decor_batch('decor' => 'Ciarka Test', 'thicknesses' => '18,5')
  NxTest.refute(ok)
  NxTest.assert(err.include?('bodkou'), "chyba radi bodku: #{err}")
  ok2, err2 = BMAT.add_decor_batch('decor' => 'Ciarka Test', 'abs_tokens' => '22,5/1')
  NxTest.refute(ok2)
  NxTest.assert(err2.include?('bodkou'), err2.to_s)
  ok3, res3 = BMAT.add_decor_batch('decor' => 'Ciarka Test', 'thicknesses' => '18.5')
  NxTest.assert(ok3, 'desatinna BODKA je legalna')
  bt_cleanup(res3)
end

NxTest.test('decor-batch: zly ABS format / sirka / hrubka = chyba') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.refute(BMAT.add_decor_batch('decor' => 'AbsFmt', 'abs_tokens' => '22')[0], 'bez lomky')
  NxTest.refute(BMAT.add_decor_batch('decor' => 'AbsFmt', 'abs_tokens' => '5/1')[0], 'sirka pod rozsahom')
  NxTest.refute(BMAT.add_decor_batch('decor' => 'AbsFmt', 'abs_tokens' => '22/3')[0], 'hrubka 3 mm')
  NxTest.refute(BMAT.add_decor_batch('decor' => 'AbsFmt')[0], 'prazdny batch')
end

NxTest.test('decor-batch: existujuce varianty sa preskocia, nove sa doplnia (+ variant flow)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok1, res1 = BMAT.add_decor_batch('decor' => 'Skip Test', 'thicknesses' => '18', 'abs_tokens' => '22/1')
  NxTest.assert(ok1)
  ok2, err2 = BMAT.add_decor_batch('decor' => 'Skip Test', 'thicknesses' => '18', 'abs_tokens' => '22/1')
  NxTest.refute(ok2, 'vsetko existuje = false')
  NxTest.assert(err2.include?('už v katalógu'), err2.to_s)
  ok3, res3 = BMAT.add_decor_batch('decor' => 'Skip Test', 'thicknesses' => '18, 36', 'abs_tokens' => '22/1, 43/1')
  NxTest.assert(ok3)
  NxTest.assert_equal(1, res3['sheets'].size, 'len nova 36')
  NxTest.assert_equal(1, res3['edges'].size, 'len nova 43/1')
  NxTest.assert_equal(2, res3['skipped'].size)
  bt_cleanup(res1)
  bt_cleanup(res3)
end

NxTest.test('decor-batch: dedup v ramci davky (18, 18 = jedna doska)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = BMAT.add_decor_batch('decor' => 'Dedup Test', 'thicknesses' => '18, 18', 'abs_tokens' => '22/1, 22/1')
  NxTest.assert(ok)
  NxTest.assert_equal(1, res['sheets'].size)
  NxTest.assert_equal(1, res['edges'].size)
  bt_cleanup(res)
end

NxTest.test('decor-batch: near-match dekor a konflikt vyrobcu sa odmietnu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, err = BMAT.add_decor_batch('decor' => 'k009 pw', 'thicknesses' => '18')
  NxTest.refute(ok, 'near-match so seed K009 PW')
  NxTest.assert(err.include?('K009 PW'), err.to_s)
  ok2, res2 = BMAT.add_decor_batch('decor' => 'Vyrobca Test', 'manufacturer' => 'Egger', 'thicknesses' => '18')
  NxTest.assert(ok2)
  ok3, err3 = BMAT.add_decor_batch('decor' => 'Vyrobca Test', 'manufacturer' => 'Kronospan', 'thicknesses' => '36')
  NxTest.refute(ok3, 'iny vyrobca v tej istej skupine')
  NxTest.assert(err3.include?('Egger'), err3.to_s)
  ok4, res4 = BMAT.add_decor_batch('decor' => 'Vyrobca Test', 'manufacturer' => 'Egger', 'thicknesses' => '36')
  NxTest.assert(ok4, 'rovnaky vyrobca doplna variant')
  bt_cleanup(res2)
  bt_cleanup(res4)
end

NxTest.test('decor-batch: ID kolizia rovnakeho slugu ineho dekoru dostane -2') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok1, res1 = BMAT.add_decor_batch('decor' => 'Slug-Test', 'thicknesses' => '18')
  NxTest.assert(ok1)
  # "Slug Test" ma iny norm key (pomlcka vs medzera) -> prejde near-match, ale
  # slug je rovnaky (SLUG_TEST) -> unique_id musi dat -2, nie prepis.
  ok2, res2 = BMAT.add_decor_batch('decor' => 'Slug Test', 'thicknesses' => '18')
  NxTest.assert(ok2, "kolizia slugu ma prejst s -2: #{res2.inspect}")
  NxTest.assert_equal("#{res1['sheets'][0]}-2", res2['sheets'][0])
  bt_cleanup(res1)
  bt_cleanup(res2)
end
