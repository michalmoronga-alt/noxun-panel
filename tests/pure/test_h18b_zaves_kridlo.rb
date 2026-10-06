# frozen_string_literal: true
require_relative '../fixtures/h18b_golden/cases'

module NxH18bChecks
  module_function
  def json(x) = JSON.parse(JSON.generate(x))
  # Ocekavanie je transformacia PRED vystupu, nikdy volanie noveho writera.
  def expected(c, old)
    result = NxH18b.copy(old)
    return result unless c['owner'] && %w[tipon classic fall].include?(c['kind']) && old[0] == 'ok'
    klass = c['kind'] == 'tipon' ? 'class:hinge|tipon' : 'class:hinge|classic'
    raw = result[1].delete("#{klass}@#{c['owner']}")
    result[1]["hinge@#{c['owner']}"] = raw unless raw.nil?
    result
  end
end

NxTest.test('H18b T0: 2816 kombinacii, povolena len transformacia owner zavesu') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  old = NxH18b.baseline
  changes = 0
  NxH18b.cases.each_with_index do |c, i|
    actual = NxH18bChecks.json(NxH18b.apply(c))
    expected = NxH18bChecks.expected(c, old[i])
    changes += 1 if expected != old[i]
    NxTest.assert_equal(expected, actual, c['id'])
  end
  NxTest.assert(changes > 0, 'transformacia musi odlisit stary kod')
  NxTest.assert_equal(2816, NxH18b.cases.length)
end
NxTest.test('H18b T1: nakup a mapa realnych skriniek R1-R8 proti PRED') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  old = NxH18b.fixture('nakup_pred')
  NxH18b.scenarios.each do |c|
    expected = NxH18b.copy(old.fetch(c['id']))
    if %w[R1 R2 R4 R5 R7].include?(c['id'])
      map = NxH18b::HS.normalize_mapping(c['cfg']['hardware_sets'], nil, allow_owner: true)
      map["hinge@#{c['owner']}"] = c['value']
      expected['result'][1] = map
      expected['normalized'] = map
      expected['after'] = NxH18bChecks.json(NxH18b.expansion(c['cfg'], map))
    end
    NxTest.assert_equal(expected, NxH18bChecks.json(NxH18b.scenario(c)), c['id'])
  end
  r4 = NxH18b.scenario(NxH18b.scenarios.find { |c| c['id'] == 'R4' })['after']['rows']
  NxTest.assert_equal(4, r4.find { |r| r['code'] == '104717' }['quantity'])
  %w[106412 105408 105425].each do |code|
    NxTest.assert_equal(4, r4.find { |r| r['code'] == code }['quantity'], 'KLASIK nakup obsahuje aj komplet prislusenstva')
  end
  NxTest.assert_equal(4, r4.find { |r| r['code'] == 'X1' }['quantity'])
end

NxTest.test('H18b T2: zapis sa precita, vynimka len D-151') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  NxH18b.kinds.each do |name, item|
    gt = item['generic_type']
    [nil, item['owner_part_key']].each do |owner|
      c = { 'item' => item, 'owner' => owner, 'value' => 'NX-MARKER', 'map' => {}, 'known' => false }
      result = NxH18b.apply(c)
      NxTest.assert_equal(:ok, result[0], name)
      type = case name
             when 'fall' then 'fall'
             when 'hk', 'no_system', 'legacy_lift' then 'lift'
             when 'quadro', 'atira', 'legacy_slide' then 'drawer_front'
             else 'door'
             end
      fronts = NxH18b::E::CabinetBuilder.normalize('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => type, 'wings' => '2' }] })['fronts']
      [nil, fronts].each do |fc|
        map = NxH18b::E::CabinetBuilder.norm_hardware_sets(result[1], fc)
        read = NxH18b::HS.resolve_mapping_value(gt, item, { 'CAB-1' => map }, {})
        NxTest.assert_equal('NX-MARKER', read, "#{name}/#{owner}/#{fc.nil?}")
        if name == 'no_system'
          # D-151: raw resolver cita hodnotu; skutocny spotrebitel resolve_set_id
          # sa zastavi lift_system_missing PRED citanim mapy (bez opravy v H18b).
          NxTest.assert_equal([nil, 'lift_system_missing', {}], NxH18b::HS.resolve_set_id(gt, item, { 'CAB-1' => map }, {}))
        end
      end
    end
  end
end

NxTest.test('H18b T3: klasifikacia, typ, inactive F10 a zmiesana skrinka') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  c = NxH18b.scenarios.first
  hs = NxH18b::HS
  NxTest.assert_equal(:invalid, hs.apply_cabinet_override(c['cfg'], 'hinge', c['owner'], 'vysuv-quadro-v6-sisy', known_sets: NxH18b.definitions)[0])
  bad = hs.apply_cabinet_override(c['cfg'], 'hinge', c['owner'], 'zaves-klasik', known_sets: NxH18b.definitions)
  NxTest.assert_equal(:invalid, bad[0])
  NxTest.assert(bad[1].include?('nesedí klasifikácii čela (iný spôsob otvárania)'))
  defs = NxH18b.definitions
  defs['blum-tipon']['active'] = false
  NxTest.assert_equal(:invalid, hs.apply_cabinet_override(c['cfg'], 'hinge', c['owner'], 'blum-tipon', known_sets: defs)[0])
  saved = c['cfg'].merge('hardware_sets' => { "hinge@#{c['owner']}" => 'blum-tipon' })
  NxTest.assert_equal(:ok, hs.apply_cabinet_override(saved, 'hinge', c['owner'], 'blum-tipon', known_sets: defs)[0], 'F10 ulozeny vyber ostava')
  NxTest.assert_equal(:invalid, NxH18b.scenario(NxH18b.scenarios.last)['result'][0], 'zmiesana skrinka')
end

NxTest.test('H18b T4: sablona neulozi owner a zachova owner ciela') do
  owner = 'hinge@front:F1/wing:left'
  map = { owner => 'zaves-klasik' }
  NxTest.assert(NxH18b::HS.owner_scoped_key?(owner))
  NxTest.refute(NxH18b::P.template_config_from(NxH18b.cabinet('CLS2').merge('hardware_sets' => map))['hardware_sets'].to_h.key?(owner))
  NxTest.assert_equal('zaves-klasik', NxH18b::E::TemplatesDialog.merge_hardware_sets({ 'hardware_sets' => map }, { 'hardware_sets' => {} })[owner])
end

NxTest.test('H18b T5: payload po zapise, dedenie zo stareho oracle a skutocny nakup') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  actual = NxH18b.payloads
  NxTest.assert_equal(NxH18b.fixture('payload_po'), NxH18bChecks.json(actual), 'cerstvost payloadu')
  NxH18b.scenarios.select { |c| actual.key?(c['id']) }.each do |c|
    entry = actual[c['id']]['payload'].find { |e| e['generic_type'] == 'hinge' }
    scope = entry['compat']['owners'].fetch(c['owner'])
    NxTest.assert_equal('set:' + c['value'], scope['current'], c['id'])
    NxTest.assert(entry['own_count'] >= 1, c['id'])
    item = c['cfg']['hardware'].find { |it| it['generic_type'] == 'hinge' && it['owner_part_key'] == c['owner'] }
    oracle = NxH18.oracle(item, c['cfg']['hardware_sets'].reject { |key, _| key == "hinge@#{c['owner']}" }, NxH18b.state['mapping'])
    NxTest.assert_equal(NxH18.source_label(oracle, { 'state' => NxH18b.state }), scope['none_label'], c['id'])
    result = NxH18b.scenario(c)
    selected = NxH18b.definitions[c['value']]
    NxTest.assert(result['status'].include?(selected['name']))
    selected['members'].select { |m| m['code'] }.each do |m|
      NxTest.assert(result['after']['rows'].any? { |row| row['code'] == m['code'] }, 'nakup nesie vybrany set ' + c['id'])
    end
  end
end

NxTest.test('H18b T6: resolver parser normalizacia klasifikacia a handler bez zmeny') do
  NxTest.assert_equal(NxH18b.fixture('guarded_pred'), NxH18b.hashes)
end
