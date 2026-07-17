# frozen_string_literal: true
# Testy pravidiel kovania (core/hardware_rules.rb) — V0.4 faza 1.
# Evaluacia je cista funkcia -> unit testy volaju HardwareRules.evaluate s explicitnymi
# rules (ziadne IO, deterministicke aj v SketchUpe). Testy zavisle od build_plan
# defaultu (globalna kniznica) su skip mimo headless (vzor helper.rb).
require_relative '../helper' unless defined?(NxTest)

module NxHW
  module_function

  def e
    Noxun::Engine
  end

  def rules
    e::HardwareRules.normalize_rules(e::HardwareRules::SEED_RULES)
  end

  # Minimalne deskriptory dielcov pre evaluaciu (rovnake pole ako v plane).
  def door(height, key = 'front:F1/wing:single')
    { role: 'front_door', part_key: key, suffix: 'DOOR-1',
      prod: { length: height.to_f, width: 400.0, thickness: 18.0 } }
  end

  def drawer(key = 'front:F1/panel')
    { role: 'drawer_front', part_key: key, suffix: 'DRW-1',
      prod: { length: 140.0, width: 500.0, thickness: 18.0 } }
  end

  def ctx(over = {})
    { 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'floor_height' => 100.0,
      'available_width' => 564.0, 'available_height' => 584.0, 'available_depth' => 510.0,
      'support' => 'legs' }.merge(over)
  end

  def evaluate(parts, ctx_over = {}, cfg = {}, rules_over = nil)
    e::HardwareRules.evaluate(cfg, parts, ctx(ctx_over), rules: rules_over || rules)
  end

  def items_of(res, type)
    res[:items].select { |it| it['generic_type'] == type }
  end
end

NxTest.test('hardware_rules: seed sa normalizuje (bands zoradene, series bez nekladnych)') do
  r = NxHW.rules
  NxTest.assert_equal(3, r.length, 'seed ma 3 pravidla')
  bands = r.find { |x| x['rule_id'] == 'zavesy-podla-vysky' }['bands']
  NxTest.assert_equal([900.0, 1400.0, 1900.0, nil], bands.map { |b| b['max'] }, 'bands sort, null posledne')
  messy = Noxun::Engine::HardwareRules.normalize_rules([
    { 'rule_id' => 'x', 'output' => 'slide', 'kind' => 'fit_series',
      'series' => [500, -10, 0, 500, 270], 'clearance' => '10',
      'bands' => [{ 'max' => nil, 'quantity' => 5 }, { 'max' => 900, 'quantity' => 2 }] }
  ])
  NxTest.assert_equal([270.0, 500.0], messy[0]['series'], 'series sort+uniq, nekladne von')
  NxTest.assert_equal([900.0, nil], messy[0]['bands'].map { |b| b['max'] }, 'null pasmo ide na koniec')
  NxTest.assert_equal(10.0, messy[0]['clearance'])
end

NxTest.test('hardware_rules: nohy fixed 4 na korpuse s nohami, params height zo sokla') do
  res = NxHW.evaluate([])
  legs = NxHW.items_of(res, 'leg')
  NxTest.assert_equal(1, legs.length)
  it = legs.first
  NxTest.assert_equal(nil, it['owner_part_key'], 'nohy patria korpusu (owner nil)')
  NxTest.assert_equal(4, it['quantity'])
  NxTest.assert_equal(4, it['rule_quantity'])
  NxTest.assert_equal('rule', it['source'])
  NxTest.assert_equal('nohy-zakladne', it['rule_id'])
  NxTest.assert_equal('counted', it['production_class'])
  NxTest.assert_equal(true, it['manufactured'])
  NxTest.assert_close(100.0, it['params']['height'], 0.01, 'vyska nohy z floor_height')
end

NxTest.test('hardware_rules: sokel nema vplyv na nohy; horna/na zemi bez noh') do
  NxTest.assert_equal(1, NxHW.items_of(NxHW.evaluate([], 'support' => 'plinth'), 'leg').length,
                      'predny sokel -> nohy ostavaju (Michal: sokel nema vplyv)')
  NxTest.assert_equal(0, NxHW.items_of(NxHW.evaluate([], 'support' => 'none'), 'leg').length,
                      'bez podopretia (horna / floor 0) -> ziadne nohy')
end

NxTest.test('hardware_rules: bands hranice zavesov (900/1400/1900 vratane)') do
  { 300.0 => 2, 900.0 => 2, 900.01 => 3, 1400.0 => 3, 1400.01 => 4,
    1900.0 => 4, 1901.0 => 5, 2500.0 => 5 }.each do |h, want|
    res = NxHW.evaluate([NxHW.door(h)])
    hinges = NxHW.items_of(res, 'hinge')
    NxTest.assert_equal(1, hinges.length, "vyska #{h}: 1 polozka")
    NxTest.assert_equal(want, hinges.first['quantity'], "vyska #{h} -> #{want} zavesy")
  end
end

NxTest.test('hardware_rules: kazde kridlo ma vlastne zavesy (owner = part_key kridla)') do
  parts = [NxHW.door(700.0, 'front:F1/wing:left'), NxHW.door(700.0, 'front:F1/wing:right')]
  hinges = NxHW.items_of(NxHW.evaluate(parts), 'hinge')
  NxTest.assert_equal(2, hinges.length)
  NxTest.assert_equal(%w[front:F1/wing:left front:F1/wing:right],
                      hinges.map { |i| i['owner_part_key'] }.sort)
  NxTest.assert(hinges.all? { |i| i['quantity'] == 2 }, 'kazde kridlo 2 zavesy pri 700 mm')
end

NxTest.test('hardware_rules: fit_series vyberie najvacsiu NL <= svetla hlbka - 10') do
  { 510.0 => 500.0, 509.99 => 470.0, 660.0 => 650.0, 280.0 => 270.0 }.each do |avail, want|
    slides = NxHW.items_of(NxHW.evaluate([NxHW.drawer], 'available_depth' => avail), 'slide')
    NxTest.assert_equal(1, slides.length, "hlbka #{avail}: 1 polozka")
    NxTest.assert_close(want, slides.first['params']['nominal_length'], 0.01,
                        "hlbka #{avail} -> NL #{want}")
    NxTest.assert_equal(1, slides.first['quantity'], '1 sada na zasuvkove celo')
  end
end

NxTest.test('hardware_rules: fit_series bez vyhovujucej NL = warning hardware_no_fit, bez polozky') do
  res = NxHW.evaluate([NxHW.drawer], 'available_depth' => 250.0)
  NxTest.assert_equal(0, NxHW.items_of(res, 'slide').length)
  w = res[:warnings].find { |x| x['code'] == 'hardware_no_fit' }
  NxTest.assert(!w.nil?, "cakal som hardware_no_fit, warnings: #{res[:warnings].inspect}")
  NxTest.assert_equal('front:F1/panel', w['part_key'], 'warning ukazuje na zasuvkove celo')
end

NxTest.test('hardware_rules: override quantity -> manual + rule_quantity; disabled -> polozka von') do
  cfg = { hardware_overrides: [
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'nohy-zakladne', 'quantity' => 6 }
  ] }
  legs = NxHW.items_of(NxHW.evaluate([], {}, cfg), 'leg')
  NxTest.assert_equal(6, legs.first['quantity'])
  NxTest.assert_equal('manual', legs.first['source'])
  NxTest.assert_equal(4, legs.first['rule_quantity'], 'povodny pocet z pravidla ostava')

  cfg_off = { hardware_overrides: [
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'nohy-zakladne', 'disabled' => true }
  ] }
  NxTest.assert_equal(0, NxHW.items_of(NxHW.evaluate([], {}, cfg_off), 'leg').length)
end

NxTest.test('hardware_rules: override zhodny s pravidlom ostava manual (reset viditelny)') do
  # Codex review PR #24: 4 -> 5 -> 4 zapise override quantity 4; kym existuje,
  # polozka je 'manual' — inak by UI skrylo reset a stale zaznam by ozil neskor.
  cfg = { hardware_overrides: [
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'nohy-zakladne', 'quantity' => 4 }
  ] }
  legs = NxHW.items_of(NxHW.evaluate([], {}, cfg), 'leg')
  NxTest.assert_equal(4, legs.first['quantity'])
  NxTest.assert_equal('manual', legs.first['source'], 'aj zhodny override = manual')
  NxTest.assert_equal(4, legs.first['rule_quantity'])
end

NxTest.test('hardware_rules: override je viazany na rule_id — cudzi rule_id nezasiahne') do
  cfg = { hardware_overrides: [
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'ine-pravidlo', 'quantity' => 9 }
  ] }
  legs = NxHW.items_of(NxHW.evaluate([], {}, cfg), 'leg')
  NxTest.assert_equal(4, legs.first['quantity'], 'override s nesedacim rule_id sa ignoruje')
  NxTest.assert_equal('rule', legs.first['source'])
end

NxTest.test('hardware_rules: duplicitny rule_id -> prve pravidlo plati + info warning') do
  dup = NxHW.rules + [NxHW.rules.first.merge('quantity' => 99)]
  res = NxHW.evaluate([], {}, {}, Noxun::Engine::HardwareRules.normalize_rules(dup))
  legs = NxHW.items_of(res, 'leg')
  NxTest.assert_equal(1, legs.length)
  NxTest.assert_equal(4, legs.first['quantity'], 'plati prve pravidlo')
  NxTest.assert(res[:warnings].any? { |w| w['code'] == 'hardware_rule_duplicate' })
end

NxTest.test('hardware_rules: neznamy kind/vypnute pravidlo sa preskoci (forward-compat)') do
  weird = Noxun::Engine::HardwareRules.normalize_rules([
    { 'rule_id' => 'buducnost', 'output' => 'leg', 'kind' => 'per_quantity', 'quantity' => 2,
      'applies_to' => { 'role' => 'cabinet' } },
    { 'rule_id' => 'vypnute', 'enabled' => false, 'output' => 'leg', 'kind' => 'fixed',
      'quantity' => 8, 'applies_to' => { 'role' => 'cabinet' } }
  ])
  res = NxHW.evaluate([], {}, {}, weird)
  NxTest.assert_equal(0, res[:items].length)
  w = res[:warnings].select { |x| x['code'] == 'hardware_rule_skipped' }
  NxTest.assert_equal(1, w.length, 'neznamy kind hlasi skip; vypnute pravidlo ticho')
end

NxTest.test('hardware_rules: polozka prezije JSON round-trip bez zmeny (string kluce)') do
  it = NxHW.items_of(NxHW.evaluate([NxHW.door(700.0)]), 'hinge').first
  round = JSON.parse(it.to_json)
  NxTest.assert_equal(it, round, 'hardware polozka musi byt string-keyed uz v plane')
end

NxTest.test('hardware_rules: build_plan naplni hardware (nohy + zavesy + vysuvy naraz)') do
  NxTest.skip!('build_plan default cita globalnu kniznicu — headless only') unless NxTest.headless?
  cfg = Noxun::Engine::CabinetBuilder.normalize(
    'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
    'floor_height' => 100.0,
    'fronts' => { 'items' => [
      { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 140.0 },
      { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }
    ] }
  )
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  types = plan[:hardware].map { |h| h['generic_type'] }.sort
  NxTest.assert_equal(%w[hinge leg slide], types, "cakal som 3 kategorie, mam: #{types.inspect}")
  hinge = plan[:hardware].find { |h| h['generic_type'] == 'hinge' }
  NxTest.assert_equal('front:F2/wing:single', hinge['owner_part_key'])
  slide = plan[:hardware].find { |h| h['generic_type'] == 'slide' }
  # svetla hlbka pri overlay chrbte = 510 -> budget 500 -> NL 500
  NxTest.assert_close(500.0, slide['params']['nominal_length'], 0.01)
  leg = plan[:hardware].find { |h| h['generic_type'] == 'leg' }
  NxTest.assert_close(100.0, leg['params']['height'], 0.01)
end

NxTest.test('hardware_rules: degenerovane celo nedostane kovanie') do
  NxTest.skip!('build_plan default cita globalnu kniznicu — headless only') unless NxTest.headless?
  # Extremne uzka zona vyradi policu; kovanie sa pocita az PO vyradeni degenerovanych.
  # Celo s vyskou pod MIN_AUTO neprejde normalizaciou, preto degenerovanost overujeme
  # nepriamo: hardware nikdy neukazuje na part_key mimo parts (validate! by spadol).
  cfg = Noxun::Engine::CabinetBuilder.normalize(
    'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '2' }] }
  )
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  keys = plan[:parts].map { |pd| pd[:part_key].to_s }
  plan[:hardware].each do |hw|
    next if hw['owner_part_key'].nil?
    NxTest.assert(keys.include?(hw['owner_part_key']),
                  "hardware owner #{hw['owner_part_key']} musi existovat v parts")
  end
end

NxTest.test('hardware_rules: upper skrinka nema nohy, dvierka zavesy maju') do
  NxTest.skip!('build_plan default cita globalnu kniznicu — headless only') unless NxTest.headless?
  cfg = Noxun::Engine::CabinetBuilder.normalize(
    'type' => 'upper',
    'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }
  )
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  types = plan[:hardware].map { |h| h['generic_type'] }
  NxTest.refute(types.include?('leg'), 'horna skrinka bez noh')
  NxTest.assert(types.include?('hinge'), 'dvierka hornej maju zavesy')
end

NxTest.test('hardware_rules: projektovy snapshot round-trip (FakeEntity ako model)') do
  hr = Noxun::Engine::HardwareRules
  fake_model = NxTest::FakeEntity.new
  NxTest.assert_equal(nil, hr.project_rules(fake_model), 'bez snapshotu nil')
  NxTest.assert(hr.set_project_rules(fake_model, NxHW.rules), 'zapis snapshotu')
  back = hr.project_rules(fake_model)
  NxTest.assert_equal(NxHW.rules, back, 'snapshot sa vrati identicky (JSON round-trip)')
  # ensure na modeli SO snapshotom NEZAPISUJE znova (vrati existujuci)
  fake_model.set_attribute('NOXUN', 'hardware_rules',
                           { 'std' => 1, 'seed_version' => 1,
                             'rules' => [NxHW.rules.first] }.to_json)
  NxTest.assert_equal(1, hr.ensure_project_rules!(fake_model).length,
                      'ensure respektuje existujuci snapshot projektu')
end
