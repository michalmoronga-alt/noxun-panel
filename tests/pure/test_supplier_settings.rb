# frozen_string_literal: true
# V0.6 E-a: nastavenia dodavatela (core/supplier_settings.rb) — seed, merge bez
# prepisu pouzivatelskych hodnot, rezimove sadzby, zapisova cesta (patch).
# Testy zapisuju do APPDATA sandboxu -> VYHRADNE headless (v SketchUpe by siahli
# na zivy katalog nastaveni).
require_relative '../helper' unless defined?(NxTest)

module NxSS
  module_function

  def ss
    Noxun::Engine::SupplierSettings
  end

  def store
    Noxun::Engine::JsonFileStore
  end

  # Cisty stav: ziadny subor, ziadna zaloha, ziadna cache.
  def reset!
    FileUtils.rm_f(ss.path)
    FileUtils.rm_f("#{ss.path}.bak")
    store.invalidate(ss.path)
    true
  end

  def install(doc)
    FileUtils.mkdir_p(ss.dir)
    store.write(ss.path, doc)
    store.invalidate(ss.path)
    true
  end

  def supplier(doc = nil)
    d = doc || ss.load
    d['suppliers'].first
  end

  def row(sup, key)
    sup['standard_rows'].find { |r| r['key'] == key }
  end
end

NxTest.test('supplier_settings: seed — sadzby, skalare, 8 standardnych riadkov v poradi') do
  NxTest.skip!('zapisuje do APPDATA') unless NxTest.headless?
  NxSS.reset!
  doc = NxSS.ss.load
  NxTest.assert_equal('default', doc['active'])
  sup = NxSS.supplier(doc)
  NxTest.assert_close(0.90, sup['rates']['olep'], 0.001)
  NxTest.assert_close(17.0, sup['rates']['porez'], 0.001)
  NxTest.assert_close(50.0, sup['rates']['duplaky'], 0.001)
  NxTest.assert_close(100.0, sup['rates']['pd_opracovanie'], 0.001)
  NxTest.assert_close(15.0, sup['rates']['montaz'], 0.001)
  NxTest.assert_equal(30, sup['stale_days'])
  NxTest.assert_close(1.0, sup['rounding_step'], 0.001, 'Michal: zaokruhlovat na cele EUR')
  NxTest.assert_close(10.0, sup['abs_reserve_pct'], 0.001)
  NxTest.assert_close(5.8, sup['montaz_m2_per_plate'], 0.001)
  keys = sup['standard_rows'].map { |r| r['key'] }
  NxTest.assert_equal(%w[doprava_zakaznik doprava_vseobecna balne ostatne material_montaz
                         vizualizacia odvody zameranie], keys)
  NxTest.assert_equal('per_m2', NxSS.row(sup, 'vizualizacia')['kind'])
  NxTest.assert_close(60.0, NxSS.row(sup, 'doprava_zakaznik')['rate'], 0.001)
  NxTest.assert_close(100.0, NxSS.row(sup, 'zameranie')['rate'], 0.001)
end

NxTest.test('supplier_settings: MONTAZ nie je standardny riadok (audit BLOCKER 1)') do
  keys = NxSS.ss::SEED_STANDARD_ROWS.map { |r| r['key'] }
  NxTest.refute(keys.any? { |k| k.include?('montaz') && k != 'material_montaz' },
                'montaz je AUTO sluzba — druhy zdroj by ju uctoval dvakrat')
  NxTest.assert(NxSS.ss::RATE_KEYS.include?('montaz'), 'montaz zije medzi sadzbami sluzieb')
end

NxTest.test('supplier_settings: kluce sadzieb a standardnych riadkov su disjunktne (namespace rezimov)') do
  overlap = NxSS.ss::RATE_KEYS & NxSS.ss::STANDARD_ROW_KEYS
  NxTest.assert(overlap.empty?, "kolizia klucov mode_values: #{overlap.inspect}")
end

NxTest.test('supplier_settings: merge doplni chybajuce, pouzivatelske hodnoty NEPREPISE') do
  NxTest.skip!('zapisuje do APPDATA') unless NxTest.headless?
  NxSS.reset!
  NxSS.install(
    'std' => 1, 'seed_version' => 0, 'active' => 'default',
    'suppliers' => [{
      'id' => 'default', 'name' => 'Moja firma',
      'rates' => { 'olep' => 1.5 }, # ostatne sadzby chybaju
      'stale_days' => 14,           # ostatne skalare chybaju
      'standard_rows' => [{ 'key' => 'balne', 'name' => 'Balné XL', 'kind' => 'fixed',
                            'rate' => 250.0, 'default_multiplier' => 2.0 }],
      'mode_values' => { 'doprava_zakaznik' => { 'vysoky' => 999.0 } }
    }]
  )
  sup = NxSS.supplier
  NxTest.assert_equal('Moja firma', sup['name'], 'nazov dodavatela sa neprepisuje')
  NxTest.assert_close(1.5, sup['rates']['olep'], 0.001, 'upravena sadzba prezije merge')
  NxTest.assert_close(17.0, sup['rates']['porez'], 0.001, 'chybajuca sadzba sa doplni zo seedu')
  NxTest.assert_equal(14, sup['stale_days'], 'upraveny skalar prezije')
  NxTest.assert_close(1.0, sup['rounding_step'], 0.001, 'chybajuci skalar sa doplni')
  NxTest.assert_equal(8, sup['standard_rows'].length, 'chybajuce standardne riadky sa doplnia')
  balne = NxSS.row(sup, 'balne')
  NxTest.assert_equal('Balné XL', balne['name'])
  NxTest.assert_close(250.0, balne['rate'], 0.001)
  NxTest.assert_close(2.0, balne['default_multiplier'], 0.001)
  NxTest.assert_equal('balne', sup['standard_rows'][2]['key'], 'poradie sa zrovna na kanonicke')
  mv = sup['mode_values']['doprava_zakaznik']
  NxTest.assert_close(999.0, mv['vysoky'], 0.001, 'rezimova hodnota pouzivatela prezije')
  NxTest.assert_close(60.0, mv['nizky'], 0.001, 'chybajuci rezim sa doplni zo seedu')
  # merge sa musel ZAPISAT — druhy beh uz nemeni nic
  again = NxSS.ss.reload!
  NxTest.assert_equal(1, again['seed_version'], 'seed_version sa bumpne po merge')
  NxTest.assert_close(1.5, NxSS.supplier(again)['rates']['olep'], 0.001)
end

NxTest.test('supplier_settings: rezim vyberá sadzbu, chybajuci rezim padne na zakladnu') do
  sup = NxSS.ss.seed_supplier
  ssm = NxSS.ss
  NxTest.assert_close(100.0, ssm.rate(sup, 'pd_opracovanie', 'standard'), 0.001)
  NxTest.assert_close(50.0, ssm.rate(sup, 'pd_opracovanie', 'nizky'), 0.001)
  NxTest.assert_close(0.90, ssm.rate(sup, 'olep', 'vysoky'), 0.001, 'bez rezimovej hodnoty = zakladna sadzba')
  NxTest.assert_close(100.0, ssm.rate(sup, 'pd_opracovanie', 'nezmysel'), 0.001, 'neznamy rezim = standard')
  dopr = sup['standard_rows'].find { |r| r['key'] == 'doprava_zakaznik' }
  NxTest.assert_close(60.0, ssm.row_rate(sup, dopr, 'standard'), 0.001)
  NxTest.assert_close(80.0, ssm.row_rate(sup, dopr, 'vysoky'), 0.001)
  zam = sup['standard_rows'].find { |r| r['key'] == 'zameranie' }
  NxTest.assert_close(100.0, ssm.row_rate(sup, zam, 'vysoky'), 0.001, 'riadok bez rezimu = zakladna sadzba')
end

NxTest.test('supplier_settings: normalize prezije poskodeny/rucne upraveny subor') do
  doc = NxSS.ss.normalize('suppliers' => 'nezmysel', 'active' => 42)
  NxTest.assert_equal(1, doc['suppliers'].length)
  NxTest.assert_equal('default', doc['active'])
  bad = NxSS.ss.normalize(
    'suppliers' => [{ 'id' => 'x', 'rates' => { 'olep' => 'abc', 'porez' => -5 },
                      'stale_days' => 0, 'rounding_step' => 'nic',
                      'standard_rows' => [{ 'key' => 'balne', 'kind' => 'zly', 'rate' => 'x' }] }]
  )
  sup = bad['suppliers'].first
  NxTest.refute(sup['rates'].key?('olep'), 'necislo sa do sadzieb nedostane')
  NxTest.refute(sup['rates'].key?('porez'), 'zaporna sadzba sa zahodi')
  NxTest.assert_equal(30, sup['stale_days'], 'hodnota mimo rozsahu padne na default')
  NxTest.assert_close(1.0, sup['rounding_step'], 0.001)
  NxTest.assert_equal('fixed', sup['standard_rows'].first['kind'], 'neznamy kind padne na seed tvar')
  NxTest.assert_close(100.0, sup['standard_rows'].first['rate'], 0.001)
end

NxTest.test('supplier_settings: patch_active! — platny patch zapise, neplatny NEZAPISE nic') do
  NxTest.skip!('zapisuje do APPDATA') unless NxTest.headless?
  NxSS.reset!
  NxSS.ss.load
  ok, errs = NxSS.ss.patch_active!('rates' => { 'olep' => 1.2 }, 'rounding_step' => 10.0,
                                   'standard_rows' => { 'zameranie' => { 'rate' => 120.0 } })
  NxTest.assert(ok, "platny patch mal prejst: #{errs.inspect}")
  sup = NxSS.supplier(NxSS.ss.reload!)
  NxTest.assert_close(1.2, sup['rates']['olep'], 0.001)
  NxTest.assert_close(10.0, sup['rounding_step'], 0.001)
  NxTest.assert_close(120.0, NxSS.row(sup, 'zameranie')['rate'], 0.001)

  bad_ok, bad_errs = NxSS.ss.patch_active!('rates' => { 'olep' => 3.0, 'neznama' => 1.0 })
  NxTest.refute(bad_ok, 'neznamy kluc sadzby musi patch odmietnut')
  NxTest.assert(bad_errs.any?, 'patch vracia dovod')
  NxTest.assert_close(1.2, NxSS.supplier(NxSS.ss.reload!)['rates']['olep'], 0.001,
                      'all-or-nothing: ani platna cast sa nezapise')

  bad2, = NxSS.ss.patch_active!('stale_days' => 0)
  NxTest.refute(bad2, 'stale_days mimo rozsahu')
  bad3, = NxSS.ss.patch_active!('standard_rows' => { 'neexistuje' => { 'rate' => 1.0 } })
  NxTest.refute(bad3, 'neznamy standardny riadok')
  bad4, = NxSS.ss.patch_active!('mode_values' => { 'olep' => { 'ziadny' => 1.0 } })
  NxTest.refute(bad4, 'neznamy rezim')
end

NxTest.test('supplier_settings: patch rezimovych hodnot — null hodnotu ZMAZE') do
  NxTest.skip!('zapisuje do APPDATA') unless NxTest.headless?
  NxSS.reset!
  NxSS.ss.load
  ok, = NxSS.ss.patch_active!('mode_values' => { 'olep' => { 'vysoky' => 2.5 } })
  NxTest.assert(ok)
  sup = NxSS.supplier(NxSS.ss.reload!)
  NxTest.assert_close(2.5, NxSS.ss.rate(sup, 'olep', 'vysoky'), 0.001)
  ok2, = NxSS.ss.patch_active!('mode_values' => { 'olep' => { 'vysoky' => nil } })
  NxTest.assert(ok2)
  sup2 = NxSS.supplier(NxSS.ss.reload!)
  NxTest.assert_close(0.90, NxSS.ss.rate(sup2, 'olep', 'vysoky'), 0.001, 'po zmazani padne na zakladnu sadzbu')
end
