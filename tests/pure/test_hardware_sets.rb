# frozen_string_literal: true
# Testy V0.6 D1: sety kovania (core/hardware_sets.rb) + napojenia.
# Expand je cista funkcia — testy krmia raw hardware (tvar Bom.collect),
# snapshot state a katalog priamo. Audit kontrakty: B2 (snapshot nesie
# definicie), B3 (per-owner dedup), F9 (missing != invalid), F10 (prisny
# validator, NL presny kluc, nikdy sused), N11 (cena nil != 0).
require_relative '../helper' unless defined?(NxTest)

HWS = Noxun::Engine::HardwareSets
HWCAT = Noxun::Engine::HardwareCatalog

# Cisty stav katalogu BEZ suboru (seed/patch testy) — vlastny helper, aby
# subor nezavisel od test_hardware_catalog.rb (run_all zdiela proces, ale
# samostatny beh suboru musi tiez fungovat).
def hws_catalog_wipe!
  [HWCAT.path, "#{HWCAT.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  Noxun::Engine::JsonFileStore.invalidate(HWCAT.path)
  HWCAT.reset_state!
end

module NxSets
  module_function

  def hinge_item(over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/wing:single',
      'generic_type' => 'hinge', 'quantity' => 2, 'rule_id' => 'zavesy-podla-vysky',
      'variant_id' => nil, 'production_class' => 'counted', 'manufactured' => true,
      'params' => {}, 'source' => 'rule', 'rule_quantity' => 2 }.merge(over)
  end

  def slide_item(nl, over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'vysuvy-nl-podla-hlbky',
      'params' => nl.nil? ? {} : { 'nominal_length' => nl },
      'source' => 'rule' }.merge(over)
  end

  def state
    sets = HWS.normalize_sets(HWS::SEED_SETS)
    by_id = {}
    sets.each { |s| by_id[s['set_id']] = s }
    { 'mapping' => HWS::SEED_MAPPING.dup, 'sets' => by_id }
  end

  def catalog(over = {})
    base = {
      '104717' => { 'item_code' => '104717', 'name_sk' => 'Záves Sensys', 'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 4.18 },
      '106412' => { 'item_code' => '106412', 'name_sk' => 'Podložka 8099', 'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 0.97 },
      '105408' => { 'item_code' => '105408', 'name_sk' => 'Krytka misky', 'category' => 'ZAVESY', 'unit' => 'ks' },
      '105425' => { 'item_code' => '105425', 'name_sk' => 'Krytka ramienka', 'category' => 'ZAVESY', 'unit' => 'ks' },
      '245723' => { 'item_code' => '245723', 'name_sk' => 'Záves P2O', 'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 4.0 },
      '250831' => { 'item_code' => '250831', 'name_sk' => 'TipOn biely', 'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 6.0 },
      '82744'  => { 'item_code' => '82744', 'name_sk' => 'Klzák 17', 'category' => 'NOHY', 'unit' => 'ks', 'price_eur_vat' => 0.48 },
      '357695' => { 'item_code' => '357695', 'name_sk' => 'Atira 420/70', 'category' => 'VYSUVY', 'unit' => 'set', 'price_eur_vat' => 25.0 },
      '357696' => { 'item_code' => '357696', 'name_sk' => 'Atira 470/70', 'category' => 'VYSUVY', 'unit' => 'set', 'price_eur_vat' => 27.5 }
    }
    base.merge(over).values
  end

  def row(res, code)
    res['rows'].find { |r| r['code'] == code }
  end
end

# --- normalizacia a validacia (F10) ------------------------------------------

NxTest.test('hw sety: seed sety su validne a mapping ukazuje len na existujuce') do
  sets = HWS.normalize_sets(HWS::SEED_SETS)
  NxTest.assert_equal(HWS::SEED_SETS.length, sets.length, 'ziadny seed set nevypadol')
  mapping = HWS.normalize_mapping(HWS::SEED_MAPPING, sets)
  NxTest.assert_equal(HWS::SEED_MAPPING.length, mapping.length, 'cely default mapping platny')
  ids = sets.map { |s| s['set_id'] }
  mapping.each_value { |sid| NxTest.assert(ids.include?(sid), "mapovany set #{sid} existuje") }
end

NxTest.test('hw sety: normalize — kody VZDY string, qty kladne cele, per enum') do
  sets = HWS.normalize_sets([
    { 'set_id' => 's1', 'generic_type' => 'hinge',
      'members' => [{ 'code' => 104_717, 'per' => 'unit', 'qty' => '2' }] }
  ])
  m = sets[0]['members'][0]
  NxTest.assert_equal('104717', m['code'], 'ciselny kod z JSON sa stane stringom')
  NxTest.assert_equal(2, m['qty'])
  NxTest.assert_equal('unit', m['per'])
  bad = HWS.normalize_sets([
    { 'set_id' => 's2', 'generic_type' => 'hinge',
      'members' => [{ 'code' => 'x', 'per' => 'krabica', 'qty' => 1 }] },
    { 'set_id' => 's3', 'generic_type' => 'hinge',
      'members' => [{ 'code' => 'x', 'qty' => 0 }] },
    { 'set_id' => 's4', 'generic_type' => 'vymysleny',
      'members' => [{ 'code' => 'x', 'qty' => 1 }] },
    { 'set_id' => 's5', 'generic_type' => 'hinge', 'members' => [] }
  ])
  NxTest.assert_equal([], bad, 'zly per / qty 0 / neznamy typ / bez clenov = set von')
end

NxTest.test('hw sety: normalize — code XOR code_by_nl, owner bez NL mapy, zle NL kluce von') do
  sets = HWS.normalize_sets([
    { 'set_id' => 'oba', 'generic_type' => 'slide',
      'members' => [{ 'code' => 'a', 'code_by_nl' => { '420' => 'b' }, 'qty' => 1 }] },
    { 'set_id' => 'ziadny', 'generic_type' => 'slide', 'members' => [{ 'qty' => 1 }] },
    { 'set_id' => 'owner-rad', 'generic_type' => 'slide',
      'members' => [{ 'per' => 'owner', 'code_by_nl' => { '420' => 'b' }, 'qty' => 1 }] }
  ])
  NxTest.assert_equal([], sets, 'code XOR mapa; owner nesmie mat rad')
  ok = HWS.normalize_sets([
    { 'set_id' => 'rad', 'generic_type' => 'slide',
      'members' => [{ 'code_by_nl' => { '420' => 357_695, 'abc' => 'x', '' => 'y', '470' => ' 357696 ' },
                      'qty' => 1 }] }
  ])
  map = ok[0]['members'][0]['code_by_nl']
  NxTest.assert_equal({ '420' => '357695', '470' => '357696' }, map,
                      'nevalidne NL kluce von, kody trim + string')
  dup = HWS.normalize_sets([HWS::SEED_SETS[0], HWS::SEED_SETS[0]])
  NxTest.assert_equal(1, dup.length, 'duplicitny set_id — druhy von')
end

# --- expanzia -----------------------------------------------------------------

NxTest.test('hw sety: expand — per unit nasobi quantity Z PRAVIDLA (2 zavesy -> 4 kody a 2)') do
  res = HWS.expand([NxSets.hinge_item], NxSets.state, catalog: NxSets.catalog)
  %w[104717 106412 105408 105425].each do |code|
    r = NxSets.row(res, code)
    NxTest.assert_equal(2, r['quantity'], "#{code}: 2 ks (qty pravidla x 1)")
  end
  NxTest.assert_equal('Záves Sensys', NxSets.row(res, '104717')['name_sk'], 'join katalogu')
  NxTest.assert_close(8.36, NxSets.row(res, '104717')['subtotal_eur_vat'], 0.001)
  NxTest.assert_equal([], res['unmapped'])
end

NxTest.test('hw sety: expand — vysoke dvierka (bands 5 zavesov) = 5x kazdy kod setu') do
  res = HWS.expand([NxSets.hinge_item('quantity' => 5)], NxSets.state, catalog: NxSets.catalog)
  NxTest.assert_equal(5, NxSets.row(res, '104717')['quantity'], 'GH #125 P2 — quantity z pravidla, nie konstanta 2')
end

NxTest.test('hw sety: expand — per owner TipOn 1x na dvierka, dedup cez dve pravidla (B3)') do
  st = NxSets.state
  st['mapping']['hinge'] = 'zaves-p2o'
  items = [
    NxSets.hinge_item('quantity' => 3),
    NxSets.hinge_item('quantity' => 1, 'rule_id' => 'ine-pravidlo-tiez-hinge')
  ]
  res = HWS.expand(items, st, catalog: NxSets.catalog)
  NxTest.assert_equal(1, NxSets.row(res, '250831')['quantity'],
                      'TipOn na vlastnika RAZ aj pri dvoch pravidlach (audit B3)')
  NxTest.assert_equal(4, NxSets.row(res, '245723')['quantity'], 'per unit clen 3+1')
  two = [NxSets.hinge_item, NxSets.hinge_item('owner_part_key' => 'front:F2/wing:single')]
  res2 = HWS.expand(two, st, catalog: NxSets.catalog)
  NxTest.assert_equal(2, NxSets.row(res2, '250831')['quantity'], 'ine dvierka = druhy TipOn')
end

# review #252 P2: brana exportov musi vediet ROZLISIT, ci duplicitne ID skrinky
# naozaj podpocita objednavku — a to sposobi VYHRADNE dedup clena `per: 'owner'`.
# Bez tohto priznaku by sa blokoval aj export zakazky, ktora ma len `per: 'unit'`
# cleny a spocita sa spravne aj pri zdielanom ID.
NxTest.test('hw sety: zdroj riadku PRIZNAVA, ci clen bol uctovany NA VLASTNIKA (`per_owner`)') do
  st = NxSets.state
  st['mapping']['hinge'] = 'zaves-p2o'
  res = HWS.expand([NxSets.hinge_item('quantity' => 3)], st, catalog: NxSets.catalog)
  owner = NxSets.row(res, '250831')['sources'].first
  unit  = NxSets.row(res, '245723')['sources'].first
  NxTest.assert_equal(true, owner['per_owner'], 'TipOn (per: owner) je oznaceny')
  NxTest.assert_equal(nil, unit['per_owner'], 'per: unit clen priznak NEMA (kluc je aditivny)')
  NxTest.assert_equal(owner['cabinet_id'], unit['cabinet_id'], 'obe z tej istej skrinky')
end

NxTest.test('hw sety: expand — rad podla NL, presny kluc, sused NIKDY (F10)') do
  res = HWS.expand([NxSets.slide_item(470.0)], NxSets.state, catalog: NxSets.catalog)
  NxTest.assert_equal(1, NxSets.row(res, '357696')['quantity'], 'NL 470 -> 357696')
  NxTest.assert_equal(nil, NxSets.row(res, '357695'), 'NL 420 kod nevznikol')
  miss = HWS.expand([NxSets.slide_item(450.0)], NxSets.state, catalog: NxSets.catalog)
  NxTest.assert_equal([], miss['rows'], 'NL 450 mimo mapy = ziadny kod (nikdy sused)')
  NxTest.assert_equal('nl_missing', miss['unmapped'][0]['reason'])
  NxTest.assert_equal(450.0, miss['unmapped'][0]['nominal_length'])
  bez = HWS.expand([NxSets.slide_item(nil)], NxSets.state, catalog: NxSets.catalog)
  NxTest.assert_equal('nl_missing', bez['unmapped'][0]['reason'], 'chybajuce params.nominal_length')
  frak = HWS.expand([NxSets.slide_item(419.6)], NxSets.state, catalog: NxSets.catalog)
  NxTest.assert_equal([], frak['rows'], 'frakcna NL 419,6 sa NEzaokruhli na 420 (GH #126 P2)')
  NxTest.assert_equal('nl_missing', frak['unmapped'][0]['reason'])
  celo = HWS.expand([NxSets.slide_item(420.0)], NxSets.state, catalog: NxSets.catalog)
  NxTest.assert_equal(1, NxSets.row(celo, '357695')['quantity'], 'presna 420.0 mapuje')
end

NxTest.test('hw sety: expand — agregacia kodov je case-insensitive (GH #126 P2)') do
  sets = HWS.normalize_sets([
    { 'set_id' => 'case-test', 'generic_type' => 'hinge',
      'members' => [{ 'code' => 'ABC9', 'per' => 'unit', 'qty' => 1 },
                    { 'code' => 'abc9', 'per' => 'unit', 'qty' => 1 }] }
  ])
  st = { 'mapping' => { 'hinge' => 'case-test' }, 'sets' => { 'case-test' => sets[0] } }
  cat = [{ 'item_code' => 'ABC9', 'name_sk' => 'Case položka', 'category' => 'ZAVESY', 'unit' => 'ks' }]
  res = HWS.expand([NxSets.hinge_item], st, catalog: cat)
  NxTest.assert_equal(1, res['rows'].length, 'ABC9 + abc9 = JEDEN nakupny riadok')
  NxTest.assert_equal(4, res['rows'][0]['quantity'], '2 clenovia x qty 2 z pravidla')
  NxTest.assert_equal(false, res['rows'][0]['missing'], 'katalogovy join case-insensitive')
end

NxTest.test('hw sety: expand — nemapovany typ a mrtvy odkaz na set (F9 vetva)') do
  it = NxSets.hinge_item('generic_type' => 'connector', 'rule_id' => 'spojky-x')
  res = HWS.expand([it], NxSets.state, catalog: NxSets.catalog)
  NxTest.assert_equal('no_set', res['unmapped'][0]['reason'], 'connector nema default set')
  st = NxSets.state
  st['mapping']['hinge'] = 'set-ktory-neexistuje'
  res2 = HWS.expand([NxSets.hinge_item], st, catalog: NxSets.catalog)
  NxTest.assert_equal('set_missing', res2['unmapped'][0]['reason'])
  NxTest.assert_equal('set-ktory-neexistuje', res2['unmapped'][0]['set_id'])
  nil_state = HWS.expand([NxSets.hinge_item], nil, catalog: NxSets.catalog)
  NxTest.assert_equal('no_set', nil_state['unmapped'][0]['reason'], 'nil state = nic nemapuje')
end

NxTest.test('hw sety: expand — cabinet override vitazi nad projektovym mapovanim (B1)') do
  res = HWS.expand([NxSets.hinge_item], NxSets.state,
                   cabinet_overrides: { 'CAB-1' => { 'hinge' => 'zaves-p2o' } },
                   catalog: NxSets.catalog)
  NxTest.assert_equal(2, NxSets.row(res, '245723')['quantity'], 'override na P2O')
  NxTest.assert_equal(nil, NxSets.row(res, '104717'), 'KLASIK zaves nevznikol')
  cudzia = HWS.expand([NxSets.hinge_item], NxSets.state,
                      cabinet_overrides: { 'CAB-9' => { 'hinge' => 'zaves-p2o' } },
                      catalog: NxSets.catalog)
  NxTest.assert_equal(2, NxSets.row(cudzia, '104717')['quantity'], 'override inej skrinky sa netyka')
end

NxTest.test('hw sety: expand — kod mimo katalogu = viditelny riadok, cena nil != 0 (N11)') do
  cat = NxSets.catalog
  cat = cat.reject { |i| %w[105408 105425].include?(i['item_code']) }
  res = HWS.expand([NxSets.hinge_item], NxSets.state, catalog: cat)
  r = NxSets.row(res, '105408')
  NxTest.assert_equal(true, r['missing'], 'chybajuci kod oznaceny')
  NxTest.assert_equal(nil, r['name_sk'])
  NxTest.assert_equal(nil, r['subtotal_eur_vat'], 'subtotal nil, NIKDY 0')
  NxTest.assert_equal(2, r['quantity'], 'pocet sa pocita aj bez katalogu')
  krytky = NxSets.row(res, '105425')
  NxTest.assert_equal(nil, krytky['subtotal_eur_vat'], 'cena bez zaznamu = nezadana')
  NxTest.assert_equal(2, res['summary']['unknown_prices'], 'oba chybajuce kody = nezname ceny')
end

NxTest.test('hw sety: expand — summary total len zo znamych cien, deterministicke poradie') do
  items = [NxSets.hinge_item, NxSets.slide_item(470.0),
           { 'owner_id' => 'CAB-2', 'owner_part_key' => nil, 'generic_type' => 'leg',
             'quantity' => 4, 'rule_id' => 'nohy-zakladne', 'params' => { 'height' => 100.0 } }]
  res = HWS.expand(items, NxSets.state, catalog: NxSets.catalog)
  codes = res['rows'].map { |r| r['code'] }
  zavesy = %w[104717 105408 105425 106412]
  NxTest.assert_equal(zavesy, codes.first(4).sort, 'kategoria ZAVESY pred VYSUVY/NOHY (poradie CATEGORIES)')
  known = res['rows'].sum { |r| r['subtotal_eur_vat'].to_f }
  NxTest.assert_close(known, res['summary']['total_eur_vat'], 0.001, 'total = sucet znamych subtotalov')
  NxTest.assert_equal(2, res['summary']['unknown_prices'], 'krytky bez ceny (2 riadky)')
end

# --- projektovy snapshot (F9/B2) ----------------------------------------------

class NxFakeModel
  def initialize(raw = nil)
    @attrs = {}
    @attrs[Noxun::Engine::Store::DICT] = { HWS::MODEL_KEY => raw } unless raw.nil?
  end

  def get_attribute(dict, key)
    (@attrs[dict] || {})[key]
  end

  def set_attribute(dict, key, val)
    (@attrs[dict] ||= {})[key] = val
  end
end

NxTest.test('hw sety: snapshot — missing != invalid (F9), zapis+citanie round-trip') do
  status, = HWS.project_state_status(NxFakeModel.new)
  NxTest.assert_equal(:missing, status, 'bez atributu = missing')
  status, = HWS.project_state_status(NxFakeModel.new('{zlomeny json'))
  NxTest.assert_equal(:invalid, status, 'poskodeny JSON = invalid, NIE fallback na global')
  status, = HWS.project_state_status(NxFakeModel.new('{"mapping": {}}'))
  NxTest.assert_equal(:invalid, status, 'chyba sets = invalid')
  # GH #126 P2: normalizacia musi byt BEZSTRATOVA, inak :invalid — zapis by
  # zahodene data zvecnil.
  lossy_set = { 'std' => 1, 'mapping' => {},
                'sets' => { 'zly' => { 'set_id' => 'zly', 'generic_type' => 'hinge', 'members' => [] } } }
  status, = HWS.project_state_status(NxFakeModel.new(lossy_set.to_json))
  NxTest.assert_equal(:invalid, status, 'poskodeny set (bez clenov) = invalid, nie ticha strata')
  lossy_map = { 'std' => 1, 'mapping' => { 'hinge' => 'neexistuje' }, 'sets' => {} }
  status, = HWS.project_state_status(NxFakeModel.new(lossy_map.to_json))
  NxTest.assert_equal(:invalid, status, 'mapping na chybajuci set = invalid')
  future_map = { 'std' => 1, 'mapping' => { 'magnet_push' => 'x' },
                 'sets' => { 'x' => { 'set_id' => 'x', 'generic_type' => 'hinge',
                                      'members' => [{ 'code' => 'a', 'qty' => 1 }] } } }
  status, = HWS.project_state_status(NxFakeModel.new(future_map.to_json))
  NxTest.assert_equal(:invalid, status, 'mapping neznameho (novsieho) typu = invalid')
  cudzi = { 'std' => 99, 'mapping' => {}, 'sets' => {} }
  status, = HWS.project_state_status(NxFakeModel.new(cudzi.to_json))
  NxTest.assert_equal(:invalid, status, 'cudzi std = invalid')
  m = NxFakeModel.new
  ok = HWS.write_project_state(m, NxSets.state)
  NxTest.assert_equal(true, ok)
  status, st = HWS.project_state_status(m)
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal('zaves-klasik', st['mapping']['hinge'])
  NxTest.assert_equal('hinge', st['sets']['zaves-klasik']['generic_type'])
end

NxTest.test('hw sety: set_project_mapping! vklada definiciu do snapshotu (B2)') do
  m = NxFakeModel.new
  HWS.write_project_state(m, { 'mapping' => {}, 'sets' => {} })
  p2o = HWS.normalize_sets(HWS::SEED_SETS).find { |s| s['set_id'] == 'zaves-p2o' }
  ok = HWS.set_project_mapping!(m, 'hinge', 'zaves-p2o', p2o)
  NxTest.assert_equal(true, ok)
  _, st = HWS.project_state_status(m)
  NxTest.assert_equal('zaves-p2o', st['mapping']['hinge'])
  NxTest.assert(st['sets'].key?('zaves-p2o'), 'definicia setu je v snapshote (B2)')
  NxTest.assert_equal(false, HWS.set_project_mapping!(m, 'hinge', 'iny-set', p2o),
                      'set_id sa musi zhodovat s definiciou')
  NxTest.assert_equal(false, HWS.set_project_mapping!(m, 'slide', 'zaves-p2o', p2o),
                      'generic_type sa musi zhodovat s definiciou')
  ok = HWS.set_project_mapping!(m, 'hinge', nil)
  NxTest.assert_equal(true, ok)
  _, st = HWS.project_state_status(m)
  NxTest.assert_equal(nil, st['mapping']['hinge'], 'nil = odmapovanie')
  NxTest.assert(st['sets'].key?('zaves-p2o'), 'definicia ostava (historia overridov)')
  broken = NxFakeModel.new('{zlomeny')
  NxTest.assert_equal(false, HWS.set_project_mapping!(broken, 'hinge', 'zaves-p2o', p2o),
                      'invalid snapshot sa TICHO neprepisuje (F9)')
end

NxTest.test('hw sety GH#127 P1: prva zmena v projekte BEZ snapshotu zmrazi VSETKY globalne predvolby') do
  [HWS.path, "#{HWS.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  Noxun::Engine::JsonFileStore.invalidate(HWS.path)
  m = NxFakeModel.new # ziadny snapshot (missing)
  p2o = HWS.normalize_sets(HWS::SEED_SETS).find { |s| s['set_id'] == 'zaves-p2o' }
  NxTest.assert_equal(true, HWS.set_project_mapping!(m, 'hinge', 'zaves-p2o', p2o))
  _, st = HWS.project_state_status(m)
  NxTest.assert_equal('zaves-p2o', st['mapping']['hinge'], 'zmeneny typ plati')
  NxTest.assert_equal('nohy-podla-sokla', st['mapping']['leg'],
                      'OSTATNE typy ostali zmrazene z globalu (nie odmapovane)')
  NxTest.assert_equal(HWS::SEED_MAPPING.length, st['mapping'].length, 'cely default zmrazeny')
  NxTest.assert(st['sets'].key?('nohy-podla-sokla') && st['sets'].key?('zaves-p2o'),
                'definicie zmrazene tiez (B2)')
ensure
  [HWS.path, "#{HWS.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  Noxun::Engine::JsonFileStore.invalidate(HWS.path)
end

# --- validation napojenie (F7) --------------------------------------------------

NxTest.test('semafor: hardware_expansion — unmapped a chybajuci kod = ORANGE s plnou identitou') do
  st = NxSets.state
  cat = NxSets.catalog.reject { |i| i['item_code'] == '105408' }
  exp = HWS.expand(
    [NxSets.hinge_item,
     NxSets.hinge_item('owner_id' => 'CAB-2', 'owner_part_key' => 'front:F1/wing:single'),
     NxSets.slide_item(450.0)],
    st, catalog: cat
  )
  res = Noxun::Engine::Validation.run({}, hardware_expansion: exp)
  items = res['items']
  unmapped = items.select { |i| i['category'] == 'hardware_unmapped' }
  NxTest.assert_equal(1, unmapped.length, 'NL 450 mimo radu = 1 polozka')
  NxTest.assert(unmapped[0]['message_sk'].include?('450'), 'sprava nesie NL')
  NxTest.assert_equal('orange', unmapped[0]['severity'])
  codes = items.select { |i| i['category'] == 'hardware_code' }
  NxTest.assert_equal(2, codes.length, 'kod 105408 chyba na DVOCH skrinkach = 2 klik-selecty (F7)')
  NxTest.assert_equal(%w[CAB-1 CAB-2], codes.map { |c| c['owner_id'] }.sort)
  NxTest.assert(codes[0]['stable_key'].include?('105408'), 'stable_key nesie kod')
  NxTest.assert_equal(res['counts']['orange'], items.length, 'vsetko ORANGE, RED nic')
  legacy = Noxun::Engine::Validation.run({})
  NxTest.assert_equal(0, legacy['counts']['total'], 'bez hardware_expansion sa nic nedeje (legacy)')
end

# --- hardware_rules v2 (seed merge + nove pravidla) -----------------------------

NxTest.test('hw pravidla v2: merge_seed doplni nove pravidla a obnovi NEZMENENU seriu vysuvov') do
  hr = Noxun::Engine::HardwareRules
  legacy_vysuvy = hr::LEGACY_SEED_SHAPES['vysuvy-nl-podla-hlbky'][0]
  user_rules = hr.normalize_rules([hr::SEED_RULES[0], hr::SEED_RULES[1], legacy_vysuvy])
  merged, changed = hr.merge_seed(user_rules, 1)
  NxTest.assert_equal(true, changed)
  ids = merged.map { |r| r['rule_id'] }
  NxTest.assert(ids.include?('zavesenie-hornej-skrinky'), 'nove pravidlo Bystrica doplnene')
  NxTest.assert(ids.include?('podperky-policove'), 'nove pravidlo podperky doplnene')
  vysuvy = merged.find { |r| r['rule_id'] == 'vysuvy-nl-podla-hlbky' }
  NxTest.assert_equal([260.0, 300.0, 350.0, 420.0, 470.0, 520.0, 560.0, 620.0],
                      vysuvy['series'], 'nezmeneny v1 seed sa obnovil na Atira rad (GH #125 P2)')
  upravene = hr.normalize_rules([legacy_vysuvy.merge('series' => [270.0, 999.0])])
  merged2, = hr.merge_seed(upravene, 1)
  vysuvy2 = merged2.find { |r| r['rule_id'] == 'vysuvy-nl-podla-hlbky' }
  NxTest.assert_equal([270.0, 999.0], vysuvy2['series'],
                      'pouzivatelska uprava serie sa NIKDY neprepisuje (F8 vzor)')
  same, changed3 = hr.merge_seed(user_rules, hr::SEED_VERSION)
  NxTest.assert_equal(false, changed3, 'aktualna verzia = ziadna zmena')
  NxTest.assert_equal(user_rules, same)
end

NxTest.test('hw pravidla v2: zavesenie hornej skrinky LEN na upper (cabinet_type, nie support)') do
  hr = Noxun::Engine::HardwareRules
  rules = hr.normalize_rules(hr::SEED_RULES)
  ctx_upper = { 'width' => 600.0, 'height' => 720.0, 'depth' => 320.0,
                'floor_height' => 0.0, 'support' => 'none', 'cabinet_type' => 'upper' }
  res = hr.evaluate({}, [], ctx_upper, rules: rules)
  wh = res[:items].select { |i| i['generic_type'] == 'wall_hanger' }
  NxTest.assert_equal(1, wh.length)
  NxTest.assert_equal(2, wh[0]['quantity'], '2 ks Bystrica na hornu skrinku')
  # spodna skrinka BEZ noh ma tiez support none — Bystricu dostat NESMIE (GH #125 P2)
  ctx_lower = ctx_upper.merge('cabinet_type' => 'lower')
  res2 = hr.evaluate({}, [], ctx_lower, rules: rules)
  NxTest.assert_equal([], res2[:items].select { |i| i['generic_type'] == 'wall_hanger' },
                      'spodna na zemi (support none) bez Bystrice')
end

NxTest.test('hw pravidla v2: podperky 4x na KAZDU policu (owner = polica)') do
  hr = Noxun::Engine::HardwareRules
  rules = hr.normalize_rules(hr::SEED_RULES)
  shelves = [
    { role: 'shelf', part_key: 'zone:Z1/shelf:1', suffix: 'SH-1',
      prod: { length: 564.0, width: 500.0, thickness: 18.0 } },
    { role: 'shelf', part_key: 'zone:Z1/shelf:2', suffix: 'SH-2',
      prod: { length: 564.0, width: 500.0, thickness: 18.0 } }
  ]
  ctx = { 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'floor_height' => 100.0,
          'support' => 'legs', 'cabinet_type' => 'lower' }
  res = hr.evaluate({}, shelves, ctx, rules: rules)
  pins = res[:items].select { |i| i['generic_type'] == 'shelf_pin' }
  NxTest.assert_equal(2, pins.length, 'kazda polica vlastna polozka')
  NxTest.assert_equal([4, 4], pins.map { |p| p['quantity'] })
  NxTest.assert_equal(%w[zone:Z1/shelf:1 zone:Z1/shelf:2].sort,
                      pins.map { |p| p['owner_part_key'] }.sort, 'owner = konkretna polica')
end

# --- build_plan forward guard (B5) ----------------------------------------------

NxTest.test('build_plan: unknown_generic_types — wall_hanger je znamy, buduci typ nie') do
  bp = Noxun::Engine::BuildPlan
  NxTest.assert_equal([], bp.unknown_generic_types([{ 'generic_type' => 'wall_hanger' },
                                                    { 'generic_type' => 'hinge' }]))
  NxTest.assert_equal(['magnet_push'],
                      bp.unknown_generic_types([{ 'generic_type' => 'magnet_push' },
                                                { 'generic_type' => 'magnet_push' },
                                                'nie hash', nil]),
                      'neznamy typ raz, ne-hash polozky sa ignoruju')
  # GH #126 P2: neznamy typ v klucoch hardware_sets chyta guard aj bez polozky
  NxTest.assert_equal(['magnet_push'],
                      bp.unknown_generic_types([], %w[hinge magnet_push]),
                      'kluce override mapy sa kontroluju tiez')
end

NxTest.test('builder round-trip: hardware_sets prezije config_to_params aj normalize (GH #126 P1)') do
  cb = Noxun::Engine::CabinetBuilder
  stored = { 'type' => 'lower', 'part_overrides' => {},
             'hardware_sets' => { 'hinge' => 'zaves-p2o' } }
  params = cb.send(:config_to_params, stored)
  NxTest.assert_equal({ 'hinge' => 'zaves-p2o' }, params['hardware_sets'],
                      'config_to_params kopiruje override setov')
  cfg = cb.normalize(params)
  NxTest.assert_equal({ 'hinge' => 'zaves-p2o' }, cfg[:hardware_sets],
                      'normalize ho zachova')
  messy = cb.normalize('hardware_sets' => { 'hinge' => ' zaves-p2o ', 'vymysleny' => 'x',
                                            'slide' => '', 'leg' => nil })
  NxTest.assert_equal({ 'hinge' => 'zaves-p2o' }, messy[:hardware_sets],
                      'neznamy typ / prazdne set_id von, trim')
end

# --- katalog: seed patch F8 ------------------------------------------------------

NxTest.test('hw katalog F8: cerstvy seed je v aktualnej sade (krytky + Bystrica preradena)') do
  hws_catalog_wipe!
  HWCAT.assess!
  NxTest.assert_equal(:ok, HWCAT.state)
  doc = Noxun::Engine::JsonFileStore.read(HWCAT.path)
  NxTest.assert_equal(HWCAT::SEED_SET_VERSION, doc['seed_version'], 'seed nesie aktualnu verziu sady')
  NxTest.assert(HWCAT.find('105408'), 'krytka misky v seede')
  NxTest.assert(HWCAT.find('105425'), 'krytka ramienka v seede')
  NxTest.assert_equal('SPOJOVACI_MATERIAL', HWCAT.find('93240')['category'], 'Bystrica NIE je noha')
end

NxTest.test('hw katalog F8: upgrade v1 katalogu — backfill krytiek + preradenie NEZMENENEJ Bystrice') do
  hws_catalog_wipe!
  legacy_bystrica = { 'item_code' => '93240',
                      'name_sk' => 'Závesné kovanie Bystrica (rektifikát hornej skrinky)',
                      'category' => 'NOHY', 'unit' => 'ks', 'supplier' => 'Demos',
                      'notes' => '2 ks na hornú skrinku' }
  user_item = { 'item_code' => '999001', 'name_sk' => 'Vlastná položka', 'category' => 'OSTATNE', 'unit' => 'ks' }
  FileUtils.mkdir_p(HWCAT.dir)
  Noxun::Engine::JsonFileStore.write(HWCAT.path,
                                     'std' => HWCAT::STD, 'schema' => HWCAT::SCHEMA_CURRENT,
                                     'items' => [HWCAT.normalize_item(legacy_bystrica)[0],
                                                 HWCAT.normalize_item(user_item)[0]])
  Noxun::Engine::JsonFileStore.invalidate(HWCAT.path)
  HWCAT.reset_state!
  HWCAT.assess!
  NxTest.assert_equal(:ok, HWCAT.state)
  doc = Noxun::Engine::JsonFileStore.read(HWCAT.path)
  NxTest.assert_equal(HWCAT::SEED_SET_VERSION, doc['seed_version'], 'verzia sady bumpnuta')
  NxTest.assert(HWCAT.find('105408') && HWCAT.find('105425'), 'krytky doplnene (upgrade path)')
  NxTest.assert_equal('SPOJOVACI_MATERIAL', HWCAT.find('93240')['category'],
                      'nezmeneny v1 seed riadok preradeny')
  NxTest.assert(HWCAT.find('999001'), 'pouzivatelska polozka nedotknuta')
  NxTest.assert_equal(nil, HWCAT.find('104717'), 'plny seed sa do existujuceho katalogu NEleje')
end

NxTest.test('hw katalog F8: pouzivatelom upraveny/previazany riadok 93240 sa NEprepisuje') do
  hws_catalog_wipe!
  edited = { 'item_code' => '93240', 'name_sk' => 'Bystrica — môj názov',
             'category' => 'NOHY', 'unit' => 'ks', 'supplier' => 'Demos',
             'notes' => '2 ks na hornú skrinku' }
  FileUtils.mkdir_p(HWCAT.dir)
  Noxun::Engine::JsonFileStore.write(HWCAT.path,
                                     'std' => HWCAT::STD, 'schema' => HWCAT::SCHEMA_CURRENT,
                                     'items' => [HWCAT.normalize_item(edited)[0]])
  Noxun::Engine::JsonFileStore.invalidate(HWCAT.path)
  HWCAT.reset_state!
  HWCAT.assess!
  rec = HWCAT.find('93240')
  NxTest.assert_equal('NOHY', rec['category'], 'upraveny riadok patch NECHAVA')
  NxTest.assert_equal('Bystrica — môj názov', rec['name_sk'])
  doc = Noxun::Engine::JsonFileStore.read(HWCAT.path)
  NxTest.assert_equal(HWCAT::SEED_SET_VERSION, doc['seed_version'],
                      'verzia sa bumpne aj tak — patch sa uz neskusa')
  NxTest.assert(HWCAT.find('105408'), 'backfill krytiek bezi nezavisle')
end

# --- D1b: nakupny CSV + CRUD kniznice setov + projektovy merge pravidiel ------

NxTest.test('hw sety D1b: purchase_csv — SK ciarka, nezadana cena prazdna (nie 0), nemapovana sekcia') do
  exp = HWS.expand([NxSets.hinge_item, NxSets.slide_item(450.0)], NxSets.state,
                   catalog: NxSets.catalog)
  csv = HWS.purchase_csv(exp, project: 'Test kuchyňa', generated_at: '2026-08-02 20:00')
  NxTest.assert(csv.include?('"104717"'), 'kod v CSV')
  NxTest.assert(csv.include?('"4,18"'), 'cena s DPH so SK ciarkou')
  NxTest.assert(csv.include?('"8,36"'), 'medzisucet 2 x 4,18')
  NxTest.assert(csv.include?('NEMAPOVANÉ'), 'sekcia nemapovanych (NL 450 bez kodu)')
  NxTest.assert(csv.include?('"SPOLU'), 'suctovy riadok')
  line = csv.lines.find { |l| l.include?('"105408"') }
  NxTest.assert(!line.nil? && line.include?(';"";""'), 'nezadana cena = prazdne bunky, NIKDY 0')
end

NxTest.test('hw sety D1b: save_set!/delete_set! — revision guard, typ nemenny, mapping sa cisti') do
  [HWS.path, "#{HWS.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  Noxun::Engine::JsonFileStore.invalidate(HWS.path)
  rev = HWS.revision
  status, rec = HWS.save_set!({ 'set_id' => 'moj-set', 'name' => 'Môj set',
                                'generic_type' => 'hinge',
                                'members' => [{ 'code' => '111', 'qty' => 1 }] }, revision: rev)
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal('moj-set', rec['set_id'])
  status, = HWS.save_set!({ 'set_id' => 'x', 'name' => 'X', 'generic_type' => 'hinge',
                            'members' => [{ 'code' => '1', 'qty' => 1 }] }, revision: rev)
  NxTest.assert_equal(:conflict, status, 'stara revizia kniznice = conflict')
  status, info = HWS.save_set!({ 'set_id' => 'moj-set', 'name' => 'Iný typ',
                                 'generic_type' => 'slide',
                                 'members' => [{ 'code' => '1', 'qty' => 1 }] },
                               revision: HWS.revision)
  NxTest.assert_equal(:invalid, status, 'generic_type existujuceho setu sa NEMENI')
  NxTest.assert(info.to_s.include?('typ'), 'zrozumitelny dovod')
  status, info = HWS.save_set!({ 'set_id' => 'moj-set', 'name' => 'Kolízia', 'generic_type' => 'hinge',
                                 'members' => [{ 'code' => '9', 'qty' => 1 }] },
                               revision: HWS.revision, create: true)
  NxTest.assert_equal(:exists, status, 'create NIKDY neprepise existujucu identitu (GH#127 P2)')
  NxTest.assert_equal('moj-set', info)
  NxTest.assert_equal(true, HWS.set_global_mapping!('hinge', 'moj-set'))
  NxTest.assert_equal('moj-set', HWS.load['mapping']['hinge'])
  NxTest.assert_equal(false, HWS.set_global_mapping!('hinge', 'set-co-nie-je'),
                      'mapovanie len na existujuci set spravneho typu')
  status, = HWS.delete_set!('moj-set', revision: HWS.revision)
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal(nil, HWS.load['mapping']['hinge'],
                      'mapovanie na zmazany set sa vycisti (ORANGE to ukaze)')
  status, = HWS.delete_set!('moj-set', revision: HWS.revision)
  NxTest.assert_equal(:not_found, status)
ensure
  # uprac: cisty seed pre nasledne testy (kniznica je globalny sandbox subor)
  [HWS.path, "#{HWS.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  Noxun::Engine::JsonFileStore.invalidate(HWS.path)
end

NxTest.test('hw pravidla D1b: merge_project_seed! doplni nove + obnovi nezmenene, potom :none') do
  hr = Noxun::Engine::HardwareRules
  m = NxFakeModel.new
  NxTest.assert_equal([:none, [], []], hr.merge_project_seed!(m),
                      'bez snapshotu sa nic nerobi (projekt berie global sam)')
  legacy = hr::LEGACY_SEED_SHAPES['vysuvy-nl-podla-hlbky'][0]
  hr.set_project_rules(m, hr.normalize_rules([hr::SEED_RULES[0], legacy]))
  status, added, refreshed = hr.merge_project_seed!(m)
  NxTest.assert_equal(:updated, status)
  # D-90: seed v3 doplna aj obe pravidla uchytkoveho profilu
  NxTest.assert_equal(%w[podperky-policove uchytkovy-profil uchytkovy-profil-zasuvky
                         zavesenie-hornej-skrinky zavesy-podla-vysky],
                      added.sort, 'chybajuce seed pravidla doplnene')
  NxTest.assert_equal(['vysuvy-nl-podla-hlbky'], refreshed, 'nezmeneny v1 seed obnoveny')
  rules = hr.project_rules(m)
  NxTest.assert_equal(hr::SEED_RULES.length, rules.length)
  vys = rules.find { |r| r['rule_id'] == 'vysuvy-nl-podla-hlbky' }
  NxTest.assert(vys['series'].include?(420.0), 'seria po obnove = Atira rad')
  status2, = hr.merge_project_seed!(m)
  NxTest.assert_equal(:none, status2, 'druhy beh nic nemeni (idempotentne)')
  custom = hr.normalize_rules([legacy.merge('series' => [111.0])])
  hr.set_project_rules(m, custom)
  _, _, refreshed3 = hr.merge_project_seed!(m)
  NxTest.assert_equal([], refreshed3, 'pouzivatelska seria sa NIKDY neobnovuje')
  vys3 = hr.project_rules(m).find { |r| r['rule_id'] == 'vysuvy-nl-podla-hlbky' }
  NxTest.assert_equal([111.0], vys3['series'], 'uprava prezila merge')
end

NxTest.test('hw katalog F8: bezna mutacia zachovava seed_version (write round-trip)') do
  hws_catalog_wipe!
  HWCAT.assess!
  status, = HWCAT.create_item('item_code' => '777001', 'name_sk' => 'Nová položka',
                              'category' => 'ZAVESY', 'unit' => 'ks')
  NxTest.assert_equal(:ok, status)
  doc = Noxun::Engine::JsonFileStore.read(HWCAT.path)
  NxTest.assert_equal(HWCAT::SEED_SET_VERSION, doc['seed_version'],
                      'create_item nezhodil seed_version (F8 round-trip)')
end
