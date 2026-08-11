# frozen_string_literal: true
# D-93 — rucny override nominalnej dlzky vysuvu (zamok).
#
# Zamok = existencia platneho pola 'nominal_length' v zazname hardware_overrides
# (nie existencia zaznamu). Polia zaznamu su nezavisle: zmena NL nesmie zmazat
# rucny pocet a naopak. fit_series musi emitovat polozku AJ pri hlbke pod
# minimom radu, pokial zamok existuje (inak by pri zmensenej hlbke ticho zmizol).
require_relative '../helper' unless defined?(NxTest)

module NxD93
  module_function

  def e
    Noxun::Engine
  end

  def hw
    e::HardwareRules
  end

  def rules
    hw.normalize_rules(hw::SEED_RULES)
  end

  def drawer(key = 'front:F1/panel')
    { role: 'drawer_front', part_key: key, suffix: 'DRW-1',
      prod: { length: 140.0, width: 500.0, thickness: 18.0 } }
  end

  def ctx(depth)
    { 'width' => 600.0, 'height' => 720.0, 'depth' => depth + 30.0, 'floor_height' => 100.0,
      'available_width' => 564.0, 'available_height' => 584.0, 'available_depth' => depth,
      'support' => 'legs' }
  end

  # cfg s jednym override zaznamom na zasuvkovom cele.
  def cfg(fields, key = 'front:F1/panel')
    { hardware_overrides: [{ 'owner_part_key' => key, 'generic_type' => 'slide',
                             'rule_id' => 'vysuvy-nl-podla-hlbky' }.merge(fields)] }
  end

  def raises?
    yield
    false
  rescue StandardError
    true
  end

  def slides(depth, over_cfg = {})
    res = hw.evaluate(over_cfg, [drawer], ctx(depth), rules: rules)
    [res[:items].select { |it| it['generic_type'] == 'slide' }, res[:warnings]]
  end
end

# --- apply_overrides: NL, kombinacie a nezavislost poli ----------------------

NxTest.test('D-93: NL override prepise params a nesie rule_nominal_length automatu') do
  items, = NxD93.slides(510.0)                       # automat: 470
  NxTest.assert_equal(470.0, items.first['params']['nominal_length'], 'automat pred zamkom')
  NxTest.assert_equal('rule', items.first['source'])
  NxTest.assert(!items.first.key?('rule_nominal_length'), 'bez zamku kluc neexistuje')

  locked, = NxD93.slides(510.0, NxD93.cfg('nominal_length' => 420.0))
  NxTest.assert_equal(420.0, locked.first['params']['nominal_length'], 'rucna NL vitazi')
  NxTest.assert_equal('manual', locked.first['source'])
  NxTest.assert_equal(470.0, locked.first['rule_nominal_length'], 'automat ostava pre UI')
  NxTest.assert_equal(1, locked.first['quantity'], 'pocet sa NL zamkom nemeni')
  NxTest.assert_equal(1, locked.first['rule_quantity'])
end

NxTest.test('D-93: zamok drzi pri zmene hlbky skrinky (automat by dal ine hodnoty)') do
  { 660.0 => 620.0, 510.0 => 470.0, 430.0 => 420.0 }.each do |depth, auto|
    items, = NxD93.slides(depth, NxD93.cfg('nominal_length' => 420.0))
    NxTest.assert_equal(420.0, items.first['params']['nominal_length'], "hlbka #{depth}: NL drzi")
    NxTest.assert_equal(auto, items.first['rule_nominal_length'], "hlbka #{depth}: automat #{auto}")
  end
end

NxTest.test('D-93: NL + quantity v jednom zazname; disabled vitazi nad oboma') do
  items, = NxD93.slides(510.0, NxD93.cfg('nominal_length' => 420.0, 'quantity' => 3))
  NxTest.assert_equal(420.0, items.first['params']['nominal_length'])
  NxTest.assert_equal(3, items.first['quantity'])
  NxTest.assert_equal(1, items.first['rule_quantity'], 'pocet z pravidla ostava')

  off, = NxD93.slides(510.0, NxD93.cfg('nominal_length' => 420.0, 'quantity' => 3,
                                       'disabled' => true))
  NxTest.assert_equal(0, off.length, 'disabled vyradi polozku aj so zamkom')
end

NxTest.test('D-93: NL override na cudzom cele/pravidle nezasiahne polozku') do
  items, = NxD93.slides(510.0, NxD93.cfg({ 'nominal_length' => 420.0 }, 'front:F2/panel'))
  NxTest.assert_equal(470.0, items.first['params']['nominal_length'], 'cudzi owner sa ignoruje')
  NxTest.assert_equal('rule', items.first['source'])

  other = { hardware_overrides: [{ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
                                   'rule_id' => 'ine-pravidlo', 'nominal_length' => 420.0 }] }
  items2, = NxD93.slides(510.0, other)
  NxTest.assert_equal(470.0, items2.first['params']['nominal_length'], 'cudzi rule_id sa ignoruje')
end

NxTest.test('D-93: neplatna hodnota NL (String/0/nil) nie je zamok') do
  ['420', 0, -5, nil, Float::INFINITY].each do |bad|
    items, = NxD93.slides(510.0, NxD93.cfg('nominal_length' => bad))
    NxTest.assert_equal(470.0, items.first['params']['nominal_length'],
                        "hodnota #{bad.inspect} sa nesmie brat ako zamok")
    NxTest.assert_equal('rule', items.first['source'], "hodnota #{bad.inspect}: ostava pravidlo")
  end
  NxTest.assert_equal(nil, Noxun::Engine::HardwareRules.override_nl('420'), 'strict: String nie')
  NxTest.assert_equal(419.6, Noxun::Engine::HardwareRules.override_nl(419.601), 'zaokruhlenie na 2 des.')
end

# --- B1: zamok prezije hlbku POD minimom radu --------------------------------

NxTest.test('D-93 (B1): pod minimom radu vznikne polozka LEN so zamkom + hardware_manual_no_fit') do
  items, warns = NxD93.slides(250.0)                 # bez zamku: povodne spravanie
  NxTest.assert_equal(0, items.length, 'bez zamku polozka nevznikne')
  NxTest.assert(warns.any? { |w| w['code'] == 'hardware_no_fit' }, 'bez zamku hardware_no_fit')

  locked, lw = NxD93.slides(250.0, NxD93.cfg('nominal_length' => 420.0))
  NxTest.assert_equal(1, locked.length, 'so zamkom polozka VZNIKNE')
  NxTest.assert_equal(420.0, locked.first['params']['nominal_length'])
  NxTest.assert_equal('manual', locked.first['source'])
  NxTest.assert(locked.first.key?('rule_nominal_length'), 'kluc existuje')
  NxTest.assert_equal(nil, locked.first['rule_nominal_length'], 'automat nevie = nil')
  NxTest.assert(lw.none? { |w| w['code'] == 'hardware_no_fit' }, 'hardware_no_fit sa uz nevydava')
  w = lw.find { |x| x['code'] == 'hardware_manual_no_fit' }
  NxTest.assert(!w.nil?, "cakal som hardware_manual_no_fit, mam: #{lw.inspect}")
  NxTest.assert_equal('front:F1/panel', w['part_key'], 'warning ukazuje na zasuvkove celo')
  NxTest.assert_equal('warn', w['severity'], 'ORANGE (build warning), nie info')
  NxTest.assert_equal(420.0, w['data']['nominal_length'])
end

NxTest.test('D-93: rucna NL vacsia nez svetla hlbka = hardware_manual_no_fit (polozka ostava)') do
  items, warns = NxD93.slides(510.0, NxD93.cfg('nominal_length' => 620.0))
  NxTest.assert_equal(1, items.length, 'RED/ORANGE nikdy neblokuje — polozka je')
  NxTest.assert_equal(620.0, items.first['params']['nominal_length'])
  NxTest.assert(warns.any? { |w| w['code'] == 'hardware_manual_no_fit' })

  ok_items, ok_warns = NxD93.slides(510.0, NxD93.cfg('nominal_length' => 420.0))
  NxTest.assert_equal(1, ok_items.length)
  NxTest.assert(ok_warns.none? { |w| w['code'] == 'hardware_manual_no_fit' },
                'kratsia NL sa zmesti — ziadne upozornenie')
end

# --- plan: polozka so zamkom prejde kontraktom BuildPlan ---------------------

NxTest.test('D-93: BuildPlan validuje rule_nominal_length (nil aj Float; len pri manual)') do
  bp = Noxun::Engine::BuildPlan
  base = { 'owner_part_key' => nil, 'generic_type' => 'slide', 'quantity' => 1,
           'rule_id' => 'r', 'variant_id' => nil, 'production_class' => 'counted',
           'manufactured' => true, 'params' => { 'nominal_length' => 420.0 },
           'source' => 'manual', 'rule_quantity' => 1 }
  bp.validate_hardware!(base.merge('rule_nominal_length' => 470.0))
  bp.validate_hardware!(base.merge('rule_nominal_length' => nil))
  NxTest.assert(NxD93.raises? { bp.validate_hardware!(base.merge('rule_nominal_length' => -1.0)) },
                'zaporna hodnota musi padnut')
  NxTest.assert(NxD93.raises? { bp.validate_hardware!(base.merge('rule_nominal_length' => '470')) },
                'String musi padnut')
  NxTest.assert(NxD93.raises? do
                  bp.validate_hardware!(base.merge('source' => 'rule', 'rule_nominal_length' => 470.0))
                end, 'rule_nominal_length bez source manual musi padnut')
end

# --- normalizacia configu (audit B2: disabled nezahadzuje ostatne polia) -----

NxTest.test('D-93 (B2): norm_hardware_overrides drzi vsetky tri polia naraz') do
  cb = Noxun::Engine::CabinetBuilder
  out = cb.norm_hardware_overrides([
    { 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
      'rule_id' => 'r', 'quantity' => 2, 'nominal_length' => 420.0, 'disabled' => true }
  ])
  NxTest.assert_equal(1, out.length)
  NxTest.assert_equal(2, out[0]['quantity'], 'disabled uz nezahadzuje pocet')
  NxTest.assert_equal(420.0, out[0]['nominal_length'], 'disabled uz nezahadzuje NL')
  NxTest.assert_equal(true, out[0]['disabled'])
end

NxTest.test('D-93: norm_hardware_overrides — strict NL, bezobsazny zaznam von') do
  cb = Noxun::Engine::CabinetBuilder
  out = cb.norm_hardware_overrides([
    { 'owner_part_key' => nil, 'generic_type' => 'slide', 'rule_id' => 'r1',
      'nominal_length' => 420.0 },                                  # samotna NL staci
    { 'owner_part_key' => nil, 'generic_type' => 'slide', 'rule_id' => 'r2',
      'nominal_length' => '420' },                                  # String -> von
    { 'owner_part_key' => nil, 'generic_type' => 'slide', 'rule_id' => 'r3',
      'nominal_length' => 0 }                                       # 0 -> von
  ])
  NxTest.assert_equal(['r1'], out.map { |o| o['rule_id'] }, "mam: #{out.inspect}")
  NxTest.assert_equal(420.0, out[0]['nominal_length'])
end

NxTest.test('D-93: NL override prezije round-trip configu (config_to_params -> normalize)') do
  cb = Noxun::Engine::CabinetBuilder
  ov = [{ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
          'rule_id' => 'vysuvy-nl-podla-hlbky', 'quantity' => 2, 'nominal_length' => 420.0 }]
  cfg = cb.normalize('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawers', 'count' => '1' }] },
                     'hardware_overrides' => ov)
  NxTest.assert_equal(ov, cfg[:hardware_overrides])
  stored = JSON.parse(JSON.generate(cb.cabinet_config(cfg)))
  params = cb.config_to_params(stored.merge('part_key_schema' => Noxun::Engine::PartKeys::SCHEMA))
  NxTest.assert_equal(ov, params['hardware_overrides'], 'citanie z configu bez zmeny')
  NxTest.assert_equal(ov, cb.normalize(params)[:hardware_overrides], 'druhy normalize identicky')
end

# --- nakupny pohlad: znamienko rucneho zasahu (audit B4) ---------------------

NxTest.test('D-93 (B4): Bom.hardware_totals nesie rule_nominal_length + text pre tooltip') do
  bom = Noxun::Engine::Bom
  items = [{ 'generic_type' => 'slide', 'variant_id' => nil, 'quantity' => 1,
             'rule_id' => 'r', 'owner_id' => 'CAB-1', 'owner_pid' => 1,
             'owner_part_key' => 'front:F1/panel', 'source' => 'manual',
             'params' => { 'nominal_length' => 420.0 }, 'rule_nominal_length' => 470.0 },
           { 'generic_type' => 'slide', 'variant_id' => nil, 'quantity' => 1,
             'rule_id' => 'r', 'owner_id' => 'CAB-2', 'owner_pid' => 2,
             'owner_part_key' => 'front:F1/panel', 'source' => 'manual',
             'params' => { 'nominal_length' => 420.0 }, 'rule_nominal_length' => nil }]
  groups = bom.hardware_totals(items)
  NxTest.assert_equal(1, groups.length, 'rovnaka NL = jeden nakupny riadok')
  b = groups.first['breakdown']
  NxTest.assert_equal(470.0, b[0]['rule_nominal_length'])
  NxTest.assert_equal('ručne prepísaná dĺžka (automat: 470 mm)', b[0]['manual_note'])
  NxTest.assert_equal('ručne prepísaná dĺžka (automat: nezmestí sa)', b[1]['manual_note'])
end

NxTest.test('D-93 (B4): expanzia setov nesie manual_quantity + hotovy text znamienka') do
  hs = Noxun::Engine::HardwareSets
  state = { 'mapping' => { 'slide' => 'set-a' },
            'sets' => { 'set-a' => { 'set_id' => 'set-a', 'name' => 'Atira', 'generic_type' => 'slide',
                                     'members' => [{ 'label' => 'bocnice', 'qty' => 1,
                                                     'code_by_nl' => { '420' => 'K420' } }] } } }
  base = { 'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'r', 'owner_id' => 'CAB-1',
           'owner_part_key' => 'front:F1/panel', 'params' => { 'nominal_length' => 420.0 } }
  out = hs.expand([base.merge('source' => 'rule')], state)
  NxTest.assert_equal(0, out['rows'].first['manual_quantity'], 'bez zasahu 0')
  NxTest.assert_equal(nil, out['rows'].first['manual_note'], 'bez zasahu ziadny text')

  manual = base.merge('source' => 'manual', 'rule_nominal_length' => 470.0,
                      'owner_part_key' => 'front:F2/panel')
  out2 = hs.expand([base.merge('source' => 'rule'), manual], state)
  row = out2['rows'].first
  NxTest.assert_equal(2, row['quantity'], 'oba kusy v jednom riadku')
  NxTest.assert_equal(1, row['manual_quantity'], 'rucny je jeden')
  NxTest.assert_equal('ručne prepísané: 1 ks (automat: 470 mm)', row['manual_note'])
  NxTest.assert(!row.key?('manual_auto'), 'pomocna zbierka do payloadu nepatri')
end
