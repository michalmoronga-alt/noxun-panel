# frozen_string_literal: true
# Testy V0.6 H1a: sety kovania — parser foriem mapovania, pasma clena
# (param_bands), selector mapovania, front_height, precedencia snapshotu,
# migracia globalneho defaultu noh a merge helper.
#
# Audit kontrakty: BLOCKER 1 (zmrazenie VSETKYCH referencovanych setov),
# BLOCKER 2 (jeden parser foriem), BLOCKER 3 (migracia defaultu len na
# nedotknutom seede), BLOCKER 4 (snapshot vyhrava nad globalom),
# FIX 5 (front_height), FIX 7 (owner override), FIX 8 (pasma),
# FIX 9 (ORANGE dovody), FIX 10 (merge helper).
require_relative '../helper' unless defined?(NxTest)

module NxH1a
  HWS = Noxun::Engine::HardwareSets
  HR  = Noxun::Engine::HardwareRules
  BP  = Noxun::Engine::BuildPlan

  module_function

  # --- fixtures ---------------------------------------------------------------

  def leg_item(height, over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => nil, 'generic_type' => 'leg',
      'quantity' => 4, 'rule_id' => 'nohy-zakladne',
      'params' => height.nil? ? {} : { 'height' => height },
      'source' => 'rule' }.merge(over)
  end

  def slide_item(front_height, over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'vysuvy-nl-podla-hlbky',
      'params' => front_height.nil? ? {} : { 'front_height' => front_height },
      'source' => 'rule' }.merge(over)
  end

  def set_def(sid, gt, code)
    { 'set_id' => sid, 'name' => sid, 'generic_type' => gt,
      'members' => [{ 'code' => code, 'per' => 'unit', 'qty' => 1 }] }
  end

  # PRESNA seed definicia (migracia cielovy set porovnava bajt na bajt).
  def seed_set(sid)
    HWS.normalize_sets(HWS::SEED_SETS).find { |s| s['set_id'] == sid }
  end

  # Stav so setmi 'a'/'b' (slide) a seed nohami.
  def state(mapping = {})
    sets = HWS.normalize_sets(HWS::SEED_SETS +
                              [set_def('bocnica-h70', 'slide', 'S70'),
                               set_def('bocnica-h144', 'slide', 'S144')])
    by_id = {}
    sets.each { |s| by_id[s['set_id']] = s }
    { 'mapping' => HWS::SEED_MAPPING.merge(mapping), 'sets' => by_id }
  end

  def selector(param, bands)
    { 'param' => param, 'bands' => bands }
  end

  def wipe_library!
    [HWS.path, "#{HWS.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
    Noxun::Engine::JsonFileStore.invalidate(HWS.path)
  end

  class Model
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
end

# --- 1) JEDEN parser foriem (audit BLOCKER 2) ---------------------------------

NxTest.test('H1a parser: kluc mapovania — plain, composite, neplatne tvary') do
  bp = NxH1a::BP
  NxTest.assert_equal(['slide', nil], bp.parse_hardware_set_key('slide'), 'plain typ')
  NxTest.assert_equal(%w[slide front:F1/panel],
                      bp.parse_hardware_set_key('slide@front:F1/panel'), 'composite kluc')
  NxTest.assert_equal(['leg', nil], bp.parse_hardware_set_key('  leg  '), 'trim')
  NxTest.assert_equal(nil, bp.parse_hardware_set_key('vymysleny'), 'neznamy typ')
  NxTest.assert_equal(nil, bp.parse_hardware_set_key('slide@'), 'prazdny owner')
  NxTest.assert_equal(nil, bp.parse_hardware_set_key('slide@nezmysel'),
                      'owner musi byt platny part_key')
  NxTest.assert_equal(nil, bp.parse_hardware_set_key(''), 'prazdny kluc')
  # Typova cast sa da precitat aj z kluca, ktory tato verzia nepozna (guard).
  NxTest.assert_equal('magnet_push', bp.hardware_set_key_type('magnet_push@front:F1/panel'))
end

NxTest.test('H1a parser: hodnota mapovania — set_id, selector, odpad') do
  hws = NxH1a::HWS
  status, norm, refs = hws.parse_mapping_value(' zaves-p2o ')
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal('zaves-p2o', norm, 'trim set_id')
  NxTest.assert_equal(['zaves-p2o'], refs)
  sel = NxH1a.selector('front_height',
                       [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'a' },
                        { 'min' => 120.01, 'max' => 400.0, 'set_id' => 'b' }])
  status, norm, refs = hws.parse_mapping_value(sel)
  NxTest.assert_equal(:ok, status, 'selector je platna forma')
  NxTest.assert_equal('front_height', norm['param'])
  NxTest.assert_equal(%w[a b], refs, 'referencovane sety zo vsetkych pasiem')
  NxTest.assert_equal(:invalid, hws.parse_mapping_value('')[0], 'prazdne set_id')
  NxTest.assert_equal(:invalid, hws.parse_mapping_value(nil)[0], 'nil')
  NxTest.assert_equal(:invalid, hws.parse_mapping_value(42)[0], 'cislo nie je forma')
  NxTest.assert_equal(:invalid, hws.parse_mapping_value('bands' => [])[0], 'prazdne pasma')
end

NxTest.test('H1a parser: composite kluc LEN v cabinet override; zapis odmieta, citanie preskoci') do
  hws = NxH1a::HWS
  raw = { 'slide@front:F1/panel' => 'bocnica-h70', 'hinge' => 'zaves-klasik' }
  out, errors = hws.parse_mapping(raw, allow_owner: true)
  NxTest.assert_equal([], errors, 'cabinet override composite prijme')
  NxTest.assert_equal(2, out.length)
  out2, errors2 = hws.parse_mapping(raw)
  NxTest.assert_equal(1, errors2.length, 'projektovy/globalny mapping composite ODMIETA')
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik' }, out2)
  bad = { 'vymysleny' => 'x', 'hinge' => 42, 'leg' => 'nohy-klzak-17' }
  out3, errors3 = hws.parse_mapping(bad)
  NxTest.assert_equal(2, errors3.length, 'zly kluc aj zla hodnota su CHYBY (zapis odmietne)')
  NxTest.assert_equal({ 'leg' => 'nohy-klzak-17' }, out3, 'citacia cesta preskoci a bezi dalej')
  # referencna cistota je TOLERANTNA (delete_set! ocisti mapovanie)
  out4, errors4 = hws.parse_mapping({ 'hinge' => 'zmazany-set' }, set_ids: ['iny'])
  NxTest.assert_equal([], errors4, 'mrtvy odkaz nie je chyba TVARU')
  NxTest.assert_equal({}, out4, 'ale do zapisu nejde — typ ostane nemapovany')
end

NxTest.test('H1a parser: builder round-trip nesie composite kluc aj selector') do
  cb = Noxun::Engine::CabinetBuilder
  sel = NxH1a.selector('front_height', [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'a' }])
  stored = { 'type' => 'lower', 'part_overrides' => {},
             'hardware_sets' => { 'slide@front:F1/panel' => 'bocnica-h70',
                                  'slide' => sel,
                                  'vymysleny' => 'x',
                                  'slide@nezmysel' => 'y' } }
  params = cb.send(:config_to_params, stored)
  cfg = cb.normalize(params)
  map = cfg[:hardware_sets]
  NxTest.assert_equal('bocnica-h70', map['slide@front:F1/panel'], 'owner override prezil')
  NxTest.assert_equal('front_height', map['slide']['param'], 'selector prezil')
  NxTest.assert_equal(2, map.length, 'neznamy typ a neplatny owner von (citacia cesta)')
end

NxTest.test('H1a guard: composite kluc neznameho typu odmieta prestavbu, neplatny owner NIE') do
  bp = NxH1a::BP
  NxTest.assert_equal(['magnet_push'],
                      bp.unknown_generic_types([], ['magnet_push@front:F1/panel']),
                      'novsi typ v composite kluci zastavi rebuild')
  NxTest.assert_equal([], bp.unknown_generic_types([], ['slide@nezmysel']),
                      'neplatny owner rebuild NEblokuje (zahodi ho normalizacia)')
  NxTest.assert_equal([], bp.unknown_generic_types([], ['slide@front:F1/panel']))
end

# --- 2) param_bands (audit FIX 8) ---------------------------------------------

NxTest.test('H1a pasma: platny clen s param_bands (hranice uzavrete, poradie zoradene)') do
  hws = NxH1a::HWS
  norm, errors = hws.validate_set(
    'set_id' => 'nohy-test', 'generic_type' => 'leg',
    'members' => [{ 'per' => 'unit', 'qty' => 1,
                    'param_bands' => { 'param' => 'height',
                                       'bands' => [{ 'min' => 140.0, 'max' => 160.0, 'code' => 'B' },
                                                   { 'min' => 17.0, 'max' => 21.0, 'code' => 'A' }] } }]
  )
  NxTest.assert_equal([], errors)
  bands = norm['members'][0]['param_bands']['bands']
  NxTest.assert_equal([17.0, 140.0], bands.map { |b| b['min'] }, 'pasma zoradene podla min')
  NxTest.assert_equal('A', bands[0]['code'])
end

NxTest.test('H1a pasma: prekryv, DOTYK hranic, min>max a nekonecne hodnoty su chyby') do
  hws = NxH1a::HWS
  mk = lambda do |bands|
    hws.validate_set('set_id' => 's', 'generic_type' => 'leg',
                     'members' => [{ 'param_bands' => { 'param' => 'height', 'bands' => bands } }])
  end
  norm, err = mk.call([{ 'min' => 0.0, 'max' => 30.0, 'code' => 'A' },
                       { 'min' => 20.0, 'max' => 40.0, 'code' => 'B' }])
  NxTest.assert_equal(nil, norm, 'prekryv = odmietnutie')
  NxTest.assert(err.first.include?('prekr'), 'zrozumitelny dovod')
  norm, = mk.call([{ 'min' => 0.0, 'max' => 30.0, 'code' => 'A' },
                   { 'min' => 30.0, 'max' => 40.0, 'code' => 'B' }])
  NxTest.assert_equal(nil, norm, 'DOTYK hranic je pri uzavretych hraniciach uz prekryv')
  norm, = mk.call([{ 'min' => 0.0, 'max' => 30.0, 'code' => 'A' },
                   { 'min' => 30.01, 'max' => 40.0, 'code' => 'B' }])
  NxTest.assert(!norm.nil?, 'medzera/tesny sused je legalny')
  norm, = mk.call([{ 'min' => 50.0, 'max' => 10.0, 'code' => 'A' }])
  NxTest.assert_equal(nil, norm, 'min > max')
  norm, = mk.call([{ 'min' => 0.0, 'max' => nil, 'code' => 'A' }])
  NxTest.assert_equal(nil, norm, 'max musi byt konecny (ziadne otvorene pasmo)')
  norm, = mk.call([{ 'min' => 0.0, 'max' => 10.0, 'code' => '' }])
  NxTest.assert_equal(nil, norm, 'pasmo bez kodu')
end

NxTest.test('H1a pasma: clen ma PRAVE JEDNO z code/code_by_nl/param_bands, set je all-or-nothing') do
  hws = NxH1a::HWS
  bands = { 'param' => 'height', 'bands' => [{ 'min' => 1.0, 'max' => 2.0, 'code' => 'A' }] }
  norm, = hws.validate_set('set_id' => 's', 'generic_type' => 'leg',
                           'members' => [{ 'code' => 'X', 'param_bands' => bands }])
  NxTest.assert_equal(nil, norm, 'kod + pasma naraz = chyba')
  norm, = hws.validate_set('set_id' => 's', 'generic_type' => 'leg',
                           'members' => [{ 'per' => 'owner', 'param_bands' => bands }])
  NxTest.assert_equal(nil, norm, 'pasma su per jednotka, nie per vlastnika')
  norm, errors = hws.validate_set('set_id' => 's', 'generic_type' => 'leg',
                                  'members' => [{ 'code' => 'A', 'qty' => 1 },
                                                { 'code' => '', 'qty' => 1 }])
  NxTest.assert_equal(nil, norm, 'ALL-OR-NOTHING — jeden chybny clen zhodi cely set')
  NxTest.assert(!errors.empty?)
  # zapisova cesta kniznice zapis ODMIETNE (ziadny tichy drop)
  NxH1a.wipe_library!
  status, msg = hws.save_set!({ 'set_id' => 'zly', 'name' => 'Zlý', 'generic_type' => 'leg',
                                'members' => [{ 'code' => 'A' }, { 'code' => '' }] })
  NxTest.assert_equal(:invalid, status, 'save_set! odmietne set s chybnym clenom')
  NxTest.assert(!msg.to_s.empty?, 'dovod pre pouzivatela')
  NxTest.assert_equal(nil, hws.load['sets'].find { |s| s['set_id'] == 'zly' })
ensure
  NxH1a.wipe_library!
end

NxTest.test('H1a pasma: expand — noha podla vysky sokla, mimo pasiem ORANGE (nikdy najblizsie)') do
  hws = NxH1a::HWS
  st = NxH1a.state
  cat = [{ 'item_code' => '82744', 'name_sk' => 'Klzák 17', 'category' => 'NOHY', 'unit' => 'ks', 'price_eur_vat' => 0.48 },
         { 'item_code' => '367823', 'name_sk' => 'AXILO 150', 'category' => 'NOHY', 'unit' => 'ks', 'price_eur_vat' => 3.2 }]
  low = hws.expand([NxH1a.leg_item(19.0)], st, catalog: cat)
  NxTest.assert_equal(4, low['rows'][0]['quantity'])
  NxTest.assert_equal('82744', low['rows'][0]['code'], 'sokel 19 -> klzak 17')
  high = hws.expand([NxH1a.leg_item(150.0)], st, catalog: cat)
  NxTest.assert_equal('367823', high['rows'][0]['code'], 'sokel 150 -> AXILO (D-79)')
  NxTest.assert_equal('82744', hws.expand([NxH1a.leg_item(17.0)], st, catalog: cat)['rows'][0]['code'],
                      'dolna hranica patri do pasma')
  NxTest.assert_equal('82744', hws.expand([NxH1a.leg_item(21.0)], st, catalog: cat)['rows'][0]['code'],
                      'horna hranica patri do pasma')
  gap = hws.expand([NxH1a.leg_item(100.0)], st, catalog: cat)
  NxTest.assert_equal([], gap['rows'], 'sokel 100 v medzere = ZIADNY kod (nikdy najblizsie pasmo)')
  u = gap['unmapped'][0]
  NxTest.assert_equal('param_band_missing', u['reason'])
  NxTest.assert_equal('height', u['param'])
  NxTest.assert_equal(100.0, u['value'])
  NxTest.assert_equal(0, u['member_index'], 'identita CLENA setu (FIX 9)')
  none = hws.expand([NxH1a.leg_item(nil)], st, catalog: cat)
  NxTest.assert_equal('param_band_missing', none['unmapped'][0]['reason'], 'chybajuci parameter')
  NxTest.assert_equal(nil, none['unmapped'][0]['value'])
end

# --- 3) selector expand + poradie overridov (D-81) ----------------------------

NxTest.test('H1a selector: poradie owner override > cabinet override > projekt') do
  hws = NxH1a::HWS
  cat = [{ 'item_code' => 'S70', 'name_sk' => 'Bočnica H70', 'category' => 'VYSUVY', 'unit' => 'ks' },
         { 'item_code' => 'S144', 'name_sk' => 'Bočnica H144', 'category' => 'VYSUVY', 'unit' => 'ks' }]
  sel = NxH1a.selector('front_height',
                       [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'bocnica-h70' },
                        { 'min' => 120.01, 'max' => 400.0, 'set_id' => 'bocnica-h144' }])
  st = NxH1a.state('slide' => sel)
  low = hws.expand([NxH1a.slide_item(96.0)], st, catalog: cat)
  NxTest.assert_equal('S70', low['rows'][0]['code'], 'nizke celo -> H70')
  high = hws.expand([NxH1a.slide_item(283.0)], st, catalog: cat)
  NxTest.assert_equal('S144', high['rows'][0]['code'], 'vysoke celo -> H144 (D-81)')
  # cabinet override prebije projektovy selector
  cab = hws.expand([NxH1a.slide_item(96.0)], st,
                   cabinet_overrides: { 'CAB-1' => { 'slide' => 'bocnica-h144' } }, catalog: cat)
  NxTest.assert_equal('S144', cab['rows'][0]['code'], 'cabinet override vitazi nad projektom')
  # owner override prebije aj cabinet override
  own = hws.expand([NxH1a.slide_item(96.0),
                    NxH1a.slide_item(96.0, 'owner_part_key' => 'front:F2/panel')],
                   st,
                   cabinet_overrides: { 'CAB-1' => { 'slide' => 'bocnica-h144',
                                                     'slide@front:F1/panel' => 'bocnica-h70' } },
                   catalog: cat)
  NxTest.assert_equal(1, own['rows'].find { |r| r['code'] == 'S70' }['quantity'], 'F1 ma vlastny set')
  NxTest.assert_equal(1, own['rows'].find { |r| r['code'] == 'S144' }['quantity'], 'F2 berie cabinet override')
end

NxTest.test('H1a selector: chybajuca hodnota / mimo pasiem = ORANGE selector_unresolved') do
  hws = NxH1a::HWS
  sel = NxH1a.selector('front_height', [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'bocnica-h70' }])
  st = NxH1a.state('slide' => sel)
  bez = hws.expand([NxH1a.slide_item(nil)], st, catalog: [])
  NxTest.assert_equal([], bez['rows'])
  NxTest.assert_equal('selector_unresolved', bez['unmapped'][0]['reason'])
  NxTest.assert_equal('front_height', bez['unmapped'][0]['param'])
  NxTest.assert_equal(nil, bez['unmapped'][0]['value'])
  mimo = hws.expand([NxH1a.slide_item(500.0)], st, catalog: [])
  NxTest.assert_equal('selector_unresolved', mimo['unmapped'][0]['reason'], 'mimo pasiem = NIKDY hadanie')
  NxTest.assert_equal(500.0, mimo['unmapped'][0]['value'])
  # selector ukazujuci na set, ktory v snapshote nie je
  sel2 = NxH1a.selector('front_height', [{ 'min' => 0.0, 'max' => 999.0, 'set_id' => 'nie-je' }])
  chyba = hws.expand([NxH1a.slide_item(96.0)], NxH1a.state('slide' => sel2), catalog: [])
  NxTest.assert_equal('set_missing', chyba['unmapped'][0]['reason'])
end

# --- 4) front_height emisia (audit FIX 5) -------------------------------------

NxTest.test('H1a front_height: vysuv nesie vysku KONKRETNEHO cela') do
  hr = NxH1a::HR
  rules = hr.normalize_rules(hr::SEED_RULES)
  ctx = { 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'floor_height' => 100.0,
          'available_depth' => 480.0, 'support' => 'legs', 'cabinet_type' => 'lower' }
  parts = [
    { role: 'drawer_front', part_key: 'front:F1/panel', suffix: 'FR-1',
      prod: { length: 96.0, width: 596.0, thickness: 18.0 } },
    { role: 'drawer_front', part_key: 'front:F2/panel', suffix: 'FR-2',
      prod: { length: 283.0, width: 596.0, thickness: 18.0 } }
  ]
  items = hr.evaluate({}, parts, ctx, rules: rules)[:items]
  slides = items.select { |i| i['generic_type'] == 'slide' }
  NxTest.assert_equal(2, slides.length)
  by_owner = {}
  slides.each { |s| by_owner[s['owner_part_key']] = s['params']['front_height'] }
  NxTest.assert_equal(96.0, by_owner['front:F1/panel'], 'kazde celo vlastna vyska')
  NxTest.assert_equal(283.0, by_owner['front:F2/panel'])
  NxTest.assert(slides[0]['params'].key?('nominal_length'), 'NL ostava (fit_series)')
  # nie-vysuvove pravidlo kluc nedostane
  hinges = items.select { |i| i['generic_type'] == 'hinge' }
  NxTest.assert(hinges.all? { |h| !h['params'].key?('front_height') }, 'zavesy front_height nemaju')
  legs = items.select { |i| i['generic_type'] == 'leg' }
  NxTest.assert_equal(100.0, legs[0]['params']['height'], 'noha nesie vysku sokla (bez zmeny)')
end

NxTest.test('H1a front_height: bez pouzitelnej vysky kluc NEVZNIKNE (selector spadne do ORANGE)') do
  hr = NxH1a::HR
  rule = { 'rule_id' => 'v', 'enabled' => true, 'applies_to' => { 'role' => 'drawer_front' },
           'output' => 'slide', 'kind' => 'fixed', 'quantity' => 1 }
  ctx = { 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'floor_height' => 0.0,
          'support' => 'none', 'cabinet_type' => 'lower' }
  bez_prod = [{ role: 'drawer_front', part_key: 'front:F1/panel', suffix: 'FR-1', prod: nil }]
  items = hr.evaluate({}, bez_prod, ctx, rules: hr.normalize_rules([rule]))[:items]
  NxTest.assert_equal(false, items[0]['params'].key?('front_height'), 'bez prod rozmerov ziadny kluc')
  # rovnake pravidlo na police (nie celo) kluc tiez nedostane
  shelf = [{ role: 'shelf', part_key: 'zone:Z1/shelf:1', suffix: 'SH-1',
             prod: { length: 564.0, width: 500.0, thickness: 18.0 } }]
  r2 = hr.normalize_rules([rule.merge('applies_to' => { 'role' => 'shelf' })])
  items2 = hr.evaluate({}, shelf, ctx, rules: r2)[:items]
  NxTest.assert_equal(false, items2[0]['params'].key?('front_height'), 'polica nie je celo')
end

# --- 5) snapshot: zmrazenie referencii + precedencia (BLOCKER 1 + 4) ----------

NxTest.test('H1a snapshot: selector zmrazi definicie VSETKYCH referencovanych setov (BLOCKER 1)') do
  hws = NxH1a::HWS
  m = NxH1a::Model.new
  hws.write_project_state(m, 'mapping' => {}, 'sets' => {})
  a = hws.normalize_sets([NxH1a.set_def('bocnica-h70', 'slide', 'S70')]).first
  b = hws.normalize_sets([NxH1a.set_def('bocnica-h144', 'slide', 'S144')]).first
  sel = NxH1a.selector('front_height',
                       [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'bocnica-h70' },
                        { 'min' => 120.01, 'max' => 400.0, 'set_id' => 'bocnica-h144' }])
  NxTest.assert_equal(false, hws.set_project_mapping!(m, 'slide', sel, [a]),
                      'chybajuca definicia DRUHEHO pasma zapis ODMIETNE')
  NxTest.assert_equal(true, hws.set_project_mapping!(m, 'slide', sel, [a, b]))
  _, st = hws.project_state_status(m)
  NxTest.assert(st['sets'].key?('bocnica-h70') && st['sets'].key?('bocnica-h144'),
                'obe definicie su v snapshote (jeden zapis, jedno undo)')
  NxTest.assert_equal('front_height', st['mapping']['slide']['param'])
  NxTest.assert_equal(false, hws.set_project_mapping!(m, 'hinge', sel, [a, b]),
                      'typ setov sa musi zhodovat s mapovanym typom')
end

NxTest.test('H1a snapshot: resolve_set_def — snapshot vyhrava nad globalom pre referencovane (BLOCKER 4)') do
  hws = NxH1a::HWS
  NxH1a.wipe_library!
  hws.save_set!(NxH1a.set_def('spolocny', 'hinge', 'GLOBAL'), revision: hws.revision)
  snap_def = hws.normalize_sets([{ 'set_id' => 'spolocny', 'name' => 'Snapshot',
                                   'generic_type' => 'hinge',
                                   'members' => [{ 'code' => 'SNAP', 'qty' => 1 }] }]).first
  m = NxH1a::Model.new
  hws.write_project_state(m, 'mapping' => { 'hinge' => 'spolocny' },
                             'sets' => { 'spolocny' => snap_def })
  res = hws.resolve_set_def(m, 'spolocny')
  NxTest.assert_equal('SNAP', res['members'][0]['code'],
                      'namapovany set sa cita zo SNAPSHOTU, nie z dnesneho globalu')
  # nereferencovany set = fallback na global
  hws.save_set!(NxH1a.set_def('iny', 'hinge', 'GLOB2'), revision: hws.revision)
  res2 = hws.resolve_set_def(m, 'iny')
  NxTest.assert_equal('GLOB2', res2['members'][0]['code'], 'nereferencovany berie global')
  NxTest.assert_equal(nil, hws.resolve_set_def(m, 'neexistuje'))
  # override na skrinke robi zo setu referencovany aj bez mapovania
  m2 = NxH1a::Model.new
  hws.write_project_state(m2, 'mapping' => {}, 'sets' => { 'spolocny' => snap_def })
  ov = { 'CAB-1' => { 'hinge' => 'spolocny' } }
  NxTest.assert_equal('SNAP', hws.resolve_set_def(m2, 'spolocny', cabinet_overrides: ov)['members'][0]['code'])
  NxTest.assert_equal('GLOBAL', hws.resolve_set_def(m2, 'spolocny')['members'][0]['code'],
                      'bez overridu nie je referencovany -> global')
  # ponuka pre UI select ma tu istu precedenciu
  opts = hws.set_options('hinge', hws.load['sets'], { 'spolocny' => snap_def }, ['spolocny'])
  NxTest.assert_equal('Snapshot', opts.find { |s| s['set_id'] == 'spolocny' }['name'])
ensure
  NxH1a.wipe_library!
end

NxTest.test('H1a snapshot GH#131 P2: std marker podla OBSAHU — nove tvary starsia verzia odmietne') do
  hws = NxH1a::HWS
  dict = Noxun::Engine::Store::DICT
  std_of = lambda do |model|
    JSON.parse(model.get_attribute(dict, hws::MODEL_KEY).to_s)['std']
  end
  seed = hws.normalize_sets(hws::SEED_SETS)
  klzak = seed.find { |s| s['set_id'] == 'nohy-klzak-17' }
  nohy = seed.find { |s| s['set_id'] == 'nohy-podla-sokla' }
  # legacy obsah -> std 1 (starsie verzie ho citaju dalej bez zmeny)
  m1 = NxH1a::Model.new
  hws.write_project_state(m1, 'mapping' => { 'leg' => 'nohy-klzak-17' },
                              'sets' => { 'nohy-klzak-17' => klzak })
  NxTest.assert_equal(hws::STD, std_of.call(m1), 'len legacy tvary = std 1')
  # clen s pasmami -> std 2
  m2 = NxH1a::Model.new
  hws.write_project_state(m2, 'mapping' => { 'leg' => 'nohy-podla-sokla' },
                              'sets' => { 'nohy-podla-sokla' => nohy })
  NxTest.assert_equal(hws::STD_PARAM_FORMS, std_of.call(m2), 'param_bands = std 2')
  # MIESANY set (legacy clen + pasma) — presne pripad z GH #131 P2
  miesany = hws.normalize_sets([
    { 'set_id' => 'miesany', 'name' => 'Miešaný', 'generic_type' => 'leg',
      'members' => [{ 'code' => 'A', 'per' => 'unit', 'qty' => 1 },
                    { 'per' => 'unit', 'qty' => 1,
                      'param_bands' => { 'param' => 'height',
                                         'bands' => [{ 'min' => 1.0, 'max' => 2.0, 'code' => 'B' }] } }] }
  ]).first
  m3 = NxH1a::Model.new
  hws.write_project_state(m3, 'mapping' => { 'leg' => 'miesany' }, 'sets' => { 'miesany' => miesany })
  NxTest.assert_equal(hws::STD_PARAM_FORMS, std_of.call(m3),
                      'miesany set MUSI byt std 2 — starsia verzia by ticho nakupila neuplny set')
  # selector v mapovani -> std 2 aj bez pasiem v sete
  a = hws.normalize_sets([NxH1a.set_def('bocnica-h70', 'slide', 'S70')]).first
  m4 = NxH1a::Model.new
  hws.write_project_state(m4,
                          'mapping' => { 'slide' => NxH1a.selector('front_height',
                                                                   [{ 'min' => 0.0, 'max' => 120.0,
                                                                      'set_id' => 'bocnica-h70' }]) },
                          'sets' => { 'bocnica-h70' => a })
  NxTest.assert_equal(hws::STD_PARAM_FORMS, std_of.call(m4), 'selector = std 2')
  # citanie: oba markery su platne, novsi nie
  [m1, m2, m3, m4].each { |m| NxTest.assert_equal(:ok, hws.project_state_status(m)[0]) }
  cudzi = { 'std' => 99, 'mapping' => {}, 'sets' => {} }
  NxTest.assert_equal(:invalid, hws.project_state_status(NxH1a::Model.new(cudzi.to_json))[0],
                      'novsi std = :invalid (ORANGE), NIKDY ciastocne citanie')
end

NxTest.test('H1a snapshot: referenced_set_ids berie priame aj selector referencie') do
  hws = NxH1a::HWS
  sel = NxH1a.selector('front_height',
                       [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'a' },
                        { 'min' => 120.01, 'max' => 400.0, 'set_id' => 'b' }])
  refs = hws.referenced_set_ids({ 'hinge' => 'z', 'slide' => sel },
                                'CAB-1' => { 'slide@front:F1/panel' => 'c' })
  NxTest.assert_equal(%w[a b c z], refs.sort)
end

# --- 6) owner override — server validacia (audit FIX 7) -----------------------

NxTest.test('H1a owner override: owner musi mat v skrinke dane kovanie; identita bez rule_id') do
  hws = NxH1a::HWS
  cfg = { 'hardware' => [
            { 'generic_type' => 'slide', 'owner_part_key' => 'front:F1/panel', 'rule_id' => 'r1' },
            { 'generic_type' => 'slide', 'owner_part_key' => 'front:F1/panel', 'rule_id' => 'r2' },
            { 'generic_type' => 'hinge', 'owner_part_key' => 'front:F9/wing:single', 'rule_id' => 'z' }
          ],
          'hardware_sets' => {} }
  status, map, refs = hws.apply_cabinet_override(cfg, 'slide', 'front:F1/panel', 'bocnica-h70')
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal({ 'slide@front:F1/panel' => 'bocnica-h70' }, map,
                      'JEDEN kluc prebija OBE pravidla toho isteho vlastnika (bez rule_id)')
  NxTest.assert_equal(['bocnica-h70'], refs)
  status, msg = hws.apply_cabinet_override(cfg, 'slide', 'front:F9/wing:single', 'bocnica-h70')
  NxTest.assert_equal(:invalid, status, 'vlastnik bez vysuvu = odmietnutie')
  NxTest.assert(!msg.to_s.empty?)
  NxTest.assert_equal(:invalid, hws.apply_cabinet_override(cfg, 'slide', 'nezmysel', 'x')[0],
                      'neplatny part_key')
  NxTest.assert_equal(:invalid, hws.apply_cabinet_override(cfg, 'vymysleny', nil, 'x')[0],
                      'neznamy typ kovania')
  status, map2 = hws.apply_cabinet_override(cfg, 'slide', nil, 'bocnica-h144')
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal({ 'slide' => 'bocnica-h144' }, map2, 'override celej skrinky bez ownera')
  # zrusenie
  cfg2 = cfg.merge('hardware_sets' => { 'slide@front:F1/panel' => 'bocnica-h70',
                                        'hinge' => 'zaves-klasik' })
  status, map3, refs3 = hws.apply_cabinet_override(cfg2, 'slide', 'front:F1/panel', nil)
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik' }, map3, 'zrusenie nechá ostatne kluce')
  NxTest.assert_equal([], refs3)
end

NxTest.test('H1a owner override: known_sets overi existenciu aj TYP referencovanych setov') do
  hws = NxH1a::HWS
  cfg = { 'hardware' => [{ 'generic_type' => 'slide', 'owner_part_key' => 'front:F1/panel',
                           'rule_id' => 'r1' }],
          'hardware_sets' => {} }
  known = [NxH1a.set_def('bocnica-h70', 'slide', 'S70'),
           NxH1a.set_def('zaves-klasik', 'hinge', '104717')]
  status, = hws.apply_cabinet_override(cfg, 'slide', 'front:F1/panel', 'bocnica-h70',
                                       known_sets: known)
  NxTest.assert_equal(:ok, status)
  status, msg = hws.apply_cabinet_override(cfg, 'slide', 'front:F1/panel', 'zaves-klasik',
                                           known_sets: known)
  NxTest.assert_equal(:invalid, status, 'set ineho typu sa na vysuv nedá dat')
  NxTest.assert(msg.to_s.include?('zaves-klasik'))
  status, = hws.apply_cabinet_override(cfg, 'slide', 'front:F1/panel', 'neexistuje',
                                       known_sets: known)
  NxTest.assert_equal(:invalid, status, 'neznamy set')
  sel = NxH1a.selector('front_height',
                       [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'bocnica-h70' },
                        { 'min' => 120.01, 'max' => 400.0, 'set_id' => 'chyba' }])
  status, = hws.apply_cabinet_override(cfg, 'slide', nil, sel, known_sets: known)
  NxTest.assert_equal(:invalid, status, 'selector s neznamym setom v pasme = odmietnutie')
end

# --- 7) migracia globalneho defaultu noh (audit BLOCKER 3) --------------------

NxTest.test('H1a migracia: cisty seed v1 prepne leg na nohy-podla-sokla') do
  hws = NxH1a::HWS
  sets = hws.normalize_sets([hws::LEGACY_SEED_SHAPES['nohy-klzak-17'][0]]) +
         [NxH1a.seed_set('nohy-podla-sokla')]
  _, map, changed = hws.merge_seed(sets, { 'leg' => 'nohy-klzak-17' }, 1)
  NxTest.assert_equal(true, changed)
  NxTest.assert_equal('nohy-podla-sokla', map['leg'], 'default sa migroval')
end

NxTest.test('H1a migracia: uzivatelska volba (ine mapovanie / upraveny set) sa NEDOTKNE') do
  hws = NxH1a::HWS
  sets = hws.normalize_sets([hws::LEGACY_SEED_SHAPES['nohy-klzak-17'][0],
                             NxH1a.set_def('nohy-axilo-150', 'leg', '367823')]) +
         [NxH1a.seed_set('nohy-podla-sokla')]
  _, map, = hws.merge_seed(sets, { 'leg' => 'nohy-axilo-150' }, 1)
  NxTest.assert_equal('nohy-axilo-150', map['leg'], 'ine mapovanie = ruky prec')
  upraveny = hws.normalize_sets([{ 'set_id' => 'nohy-klzak-17', 'name' => 'Klzák s rektifikáciou 17 mm',
                                   'generic_type' => 'leg',
                                   'members' => [{ 'code' => 'MOJ-KOD', 'per' => 'unit', 'qty' => 1 }] }]) +
             [NxH1a.seed_set('nohy-podla-sokla')]
  _, map2, = hws.merge_seed(upraveny, { 'leg' => 'nohy-klzak-17' }, 1)
  NxTest.assert_equal('nohy-klzak-17', map2['leg'],
                      'upraveny set = mapovanie sa neprepisuje (vzor F8)')
end

NxTest.test('H1a migracia GH#131 P2: obsadene ID cieloveho setu migraciu ZASTAVI') do
  hws = NxH1a::HWS
  legacy = hws::LEGACY_SEED_SHAPES['nohy-klzak-17'][0]
  # (a) ID si obsadil vlastny set INEHO typu — nohy by expandovali na zavesy
  kolizia = hws.normalize_sets([legacy,
                                { 'set_id' => 'nohy-podla-sokla', 'name' => 'Môj záves',
                                  'generic_type' => 'hinge',
                                  'members' => [{ 'code' => 'ZAVES', 'qty' => 1 }] }])
  _, map, = hws.merge_seed(kolizia, { 'leg' => 'nohy-klzak-17' }, 1)
  NxTest.assert_equal('nohy-klzak-17', map['leg'], 'kolizia ID ineho typu = ziadna migracia')
  # (b) ID je spravneho typu, ale definiciu si pouzivatel upravil
  upraveny_ciel = hws.normalize_sets(
    [legacy,
     { 'set_id' => 'nohy-podla-sokla', 'name' => 'Nohy podľa výšky sokla',
       'generic_type' => 'leg',
       'members' => [{ 'per' => 'unit', 'qty' => 1,
                       'param_bands' => { 'param' => 'height',
                                          'bands' => [{ 'min' => 1.0, 'max' => 2.0,
                                                        'code' => 'MOJ' }] } }] }]
  )
  _, map2, = hws.merge_seed(upraveny_ciel, { 'leg' => 'nohy-klzak-17' }, 1)
  NxTest.assert_equal('nohy-klzak-17', map2['leg'],
                      'upraveny cielovy set = migracia sa nevykona (nie je to nas seed)')
end

NxTest.test('H1a migracia: idempotencia — aktualna seed_version uz nic nemeni') do
  hws = NxH1a::HWS
  sets = hws.normalize_sets([hws::LEGACY_SEED_SHAPES['nohy-klzak-17'][0]]) +
         [NxH1a.seed_set('nohy-podla-sokla')]
  merged, map, changed = hws.merge_seed(sets, { 'leg' => 'nohy-klzak-17' }, hws::SEED_VERSION)
  NxTest.assert_equal(false, changed)
  NxTest.assert_equal('nohy-klzak-17', map['leg'],
                      'po prvej migracii sa uzivatelov navrat na klzak uz neprepisuje')
  NxTest.assert_equal(sets, merged)
end

NxTest.test('H1a migracia: ostry beh nad legacy suborom kniznice (load prepise a zapise)') do
  hws = NxH1a::HWS
  NxH1a.wipe_library!
  legacy_sets = hws.normalize_sets([hws::LEGACY_SEED_SHAPES['nohy-klzak-17'][0],
                                    NxH1a.set_def('zaves-klasik', 'hinge', '104717')])
  Noxun::Engine::JsonFileStore.write(hws.path,
                                     'std' => hws::STD, 'seed_version' => 1,
                                     'sets' => legacy_sets,
                                     'mapping' => { 'leg' => 'nohy-klzak-17',
                                                    'hinge' => 'zaves-klasik' })
  Noxun::Engine::JsonFileStore.invalidate(hws.path)
  lib = hws.load
  NxTest.assert_equal('nohy-podla-sokla', lib['mapping']['leg'], 'default migrovany')
  NxTest.assert_equal('zaves-klasik', lib['mapping']['hinge'], 'ostatne mapovania nedotknute')
  NxTest.assert(lib['sets'].any? { |s| s['set_id'] == 'nohy-podla-sokla' }, 'novy set doplneny')
  NxTest.assert(lib['sets'].any? { |s| s['set_id'] == 'nohy-klzak-17' }, 'stary set OSTAVA')
  doc = Noxun::Engine::JsonFileStore.read(hws.path)
  NxTest.assert_equal(hws::SEED_VERSION, doc['seed_version'], 'verzia bumpnuta = uz sa nespusti znova')
  # uzivatel sa vrati ku klzaku — druhy load uz nic nemigruje
  hws.set_global_mapping!('leg', 'nohy-klzak-17')
  Noxun::Engine::JsonFileStore.invalidate(hws.path)
  NxTest.assert_equal('nohy-klzak-17', hws.load['mapping']['leg'], 'jednorazovost')
ensure
  NxH1a.wipe_library!
end

NxTest.test('H1a seed: novy default set je validny a projektove snapshoty sa NEMENIA samy') do
  hws = NxH1a::HWS
  sets = hws.normalize_sets(hws::SEED_SETS)
  nohy = sets.find { |s| s['set_id'] == 'nohy-podla-sokla' }
  NxTest.assert(!nohy.nil?, 'seed set existuje')
  NxTest.assert_equal('height', nohy['members'][0]['param_bands']['param'])
  NxTest.assert_equal(hws::SEED_SETS.length, sets.length, 'ziadny seed set nevypadol')
  mapping = hws.normalize_mapping(hws::SEED_MAPPING, sets)
  NxTest.assert_equal('nohy-podla-sokla', mapping['leg'])
  # stary projekt so zmrazenym klzakom ostava klzakom
  stary = { 'std' => hws::STD, 'mapping' => { 'leg' => 'nohy-klzak-17' },
            'sets' => { 'nohy-klzak-17' => sets.find { |s| s['set_id'] == 'nohy-klzak-17' } } }
  m = NxH1a::Model.new(stary.to_json)
  status, st = hws.project_state_status(m)
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal('nohy-klzak-17', st['mapping']['leg'], 'snapshot zakazky sa NIKDY nemigruje sam')
end

# --- 8) merge helper pre existujuce projekty (audit FIX 10) -------------------

NxTest.test('H1a merge: doplni CHYBAJUCE globalne mapovania bez prepisu existujucich') do
  hws = NxH1a::HWS
  NxH1a.wipe_library!
  m = NxH1a::Model.new
  NxTest.assert_equal([:none, [], []], hws.merge_project_sets_seed!(m),
                      'bez snapshotu sa nic nerobi (projekt berie global sam)')
  klzak = hws.normalize_sets(hws::SEED_SETS).find { |s| s['set_id'] == 'nohy-klzak-17' }
  hws.write_project_state(m, 'mapping' => { 'leg' => 'nohy-klzak-17' },
                             'sets' => { 'nohy-klzak-17' => klzak })
  status, added_sets, added_map = hws.merge_project_sets_seed!(m)
  NxTest.assert_equal(:updated, status)
  NxTest.assert_equal(%w[hinge shelf_pin slide wall_hanger], added_map.sort,
                      'doplnene len CHYBAJUCE typy')
  NxTest.assert(added_sets.include?('zaves-klasik'))
  _, st = hws.project_state_status(m)
  NxTest.assert_equal('nohy-klzak-17', st['mapping']['leg'],
                      'existujuce mapovanie sa NEPREPISUJE (ziadna migracia snapshotu)')
  NxTest.assert(st['sets'].key?('nohy-klzak-17'), 'stara definicia ostava')
  status2, = hws.merge_project_sets_seed!(m)
  NxTest.assert_equal(:none, status2, 'druhy beh nic nemeni (idempotentne)')
ensure
  NxH1a.wipe_library!
end

NxTest.test('H1a merge: definicia, na ktoru ukazuje override, sa NEODSTRANI') do
  hws = NxH1a::HWS
  NxH1a.wipe_library!
  m = NxH1a::Model.new
  vlastny = hws.normalize_sets([NxH1a.set_def('moj-vysuv', 'slide', 'MOJ')]).first
  hws.write_project_state(m, 'mapping' => {}, 'sets' => { 'moj-vysuv' => vlastny })
  hws.merge_project_sets_seed!(m)
  _, st = hws.project_state_status(m)
  NxTest.assert(st['sets'].key?('moj-vysuv'), 'definicia pre cabinet override prezila merge')
  NxTest.assert_equal('nohy-podla-sokla', st['mapping']['leg'], 'globalne predvolby doplnene')
ensure
  NxH1a.wipe_library!
end

# --- 9) ORANGE dovody (audit FIX 9) ------------------------------------------

NxTest.test('H1a semafor: nove dovody maju SK text, parameter aj identitu clena') do
  hws = NxH1a::HWS
  st = NxH1a.state
  sel = NxH1a.selector('front_height', [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'bocnica-h70' }])
  st['mapping']['slide'] = sel
  exp = hws.expand([NxH1a.leg_item(100.0), NxH1a.slide_item(500.0)], st, catalog: [])
  res = Noxun::Engine::Validation.run({}, hardware_expansion: exp)
  items = res['items'].select { |i| i['category'] == 'hardware_unmapped' }
  NxTest.assert_equal(2, items.length)
  band = items.find { |i| i['stable_key'].include?('param_band_missing') }
  NxTest.assert(!band.nil?, 'pasmo clena setu ma vlastny dovod')
  # H1b: cisla su vsade v tom istom tvare (150 / 17,5) — fmt_mm.
  NxTest.assert(band['message_sk'].include?('výšku sokla 100 mm'), 'sprava nesie parameter aj hodnotu')
  NxTest.assert(band['stable_key'].end_with?('|0'), 'stable_key nesie index clena (F7)')
  selr = items.find { |i| i['stable_key'].include?('selector_unresolved') }
  NxTest.assert(!selr.nil?)
  # H1b: parameter je PODMET vety (1. pad) — „podľa + 4. pad" bola chyba
  NxTest.assert(selr['message_sk'].include?('výška čela 500 mm nespadá'), 'selector: 1. pad')
  NxTest.assert_equal(res['counts']['orange'], res['items'].length, 'vsetko ORANGE, RED nic')
end

NxTest.test('H1a semafor: dva chybajuce pasma toho isteho setu su DVA klik-selecty') do
  hws = NxH1a::HWS
  dvojclen = hws.normalize_sets([
    { 'set_id' => 'dvoj', 'name' => 'Dvojčlen', 'generic_type' => 'leg',
      'members' => [
        { 'per' => 'unit', 'qty' => 1, 'label' => 'noha',
          'param_bands' => { 'param' => 'height',
                             'bands' => [{ 'min' => 17.0, 'max' => 21.0, 'code' => 'A' }] } },
        { 'per' => 'unit', 'qty' => 1, 'label' => 'krytka',
          'param_bands' => { 'param' => 'height',
                             'bands' => [{ 'min' => 17.0, 'max' => 21.0, 'code' => 'B' }] } }
      ] }
  ]).first
  st = { 'mapping' => { 'leg' => 'dvoj' }, 'sets' => { 'dvoj' => dvojclen } }
  exp = hws.expand([NxH1a.leg_item(150.0)], st, catalog: [])
  NxTest.assert_equal(2, exp['unmapped'].length, 'kazdy clen vlastny zaznam')
  NxTest.assert_equal([0, 1], exp['unmapped'].map { |u| u['member_index'] })
  res = Noxun::Engine::Validation.run({}, hardware_expansion: exp)
  keys = res['items'].map { |i| i['stable_key'] }
  NxTest.assert_equal(2, keys.uniq.length, 'stabilne kluce sa lisia (dva riadky KONTROLY)')
  NxTest.assert(res['items'].any? { |i| i['message_sk'].include?('krytka') }, 'label clena v sprave')
end

# --- 10) end-to-end: skrinka so soklom 150 dostane AXILO (D-79) --------------

NxTest.test('H1a end-to-end: plan skrinky so soklom 150 -> AXILO, sokel 17 -> klzak') do
  cb = Noxun::Engine::CabinetBuilder
  hws = NxH1a::HWS
  cat = [{ 'item_code' => '82744', 'name_sk' => 'Klzák 17', 'category' => 'NOHY', 'unit' => 'ks' },
         { 'item_code' => '367823', 'name_sk' => 'AXILO 150', 'category' => 'NOHY', 'unit' => 'ks' }]
  legs_for = lambda do |floor_height, plinth|
    cfg = cb.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
                       'floor_height' => floor_height, 'plinth_mode' => plinth)
    plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-1')
    items = plan[:hardware].map { |h| h.merge('owner_id' => 'CAB-1') }
    hws.expand(items, NxH1a.state, catalog: cat)
  end
  sokel = legs_for.call(150.0, 'front')
  NxTest.assert_equal('367823', sokel['rows'][0]['code'], 'sokel 150 -> AXILO (D-79 opravene)')
  NxTest.assert_equal(4, sokel['rows'][0]['quantity'])
  nizke = legs_for.call(19.0, 'none')
  NxTest.assert_equal('82744', nizke['rows'][0]['code'], 'nizke nohy -> klzak 17')
  medzi = legs_for.call(100.0, 'none')
  NxTest.assert_equal([], medzi['rows'], 'sokel 100 nema pasmo — ORANGE, nie tichy klzak')
  NxTest.assert_equal('param_band_missing', medzi['unmapped'][0]['reason'])
end

# --- 11) CSV a expanzia bez regresie -----------------------------------------

NxTest.test('H1a: nakupne CSV nemapovanych funguje aj s novymi dovodmi') do
  hws = NxH1a::HWS
  exp = hws.expand([NxH1a.leg_item(100.0)], NxH1a.state, catalog: [])
  csv = hws.purchase_csv(exp, project: 'H1a', generated_at: '2026-08-03')
  NxTest.assert(csv.include?('NEMAPOVANÉ'), 'nemapovana sekcia')
  NxTest.assert(csv.include?('"leg"'), 'typ kovania v riadku')
end
