# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)

NxTest.test('CELA-B: zmena lift-fall odstrani iba neaplikovatelny seed zasah profilu') do
  cb = Noxun::Engine::CabinetBuilder
  [['lift', 'fall', 'uchytkovy-profil-vyklop'], ['fall', 'lift', 'uchytkovy-profil-sklop']].each do |from, to, rid|
    [{ 'disabled' => true }, { 'quantity' => 4 }].each do |edit|
      original = { 'rule_id' => rid, 'generic_type' => 'handle', 'owner_part_key' => 'front:F1/flap' }.merge(edit)
      custom = original.merge('rule_id' => 'moj-profil')
      hinge = original.merge('rule_id' => 'zavesy-sklop', 'generic_type' => 'hinge')
      params = { 'hardware_overrides' => [original, custom, hinge],
        'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => from, 'profile' => 'ukw7', 'profile_edge' => 'left' }] } }
      same = cb.normalize(params)
      NxTest.assert_equal([original, custom, hinge], same[:hardware_overrides])
      params['fronts']['items'][0]['type'] = to
      changed = cb.normalize(params)
      NxTest.assert_equal([custom, hinge], changed[:hardware_overrides])
      params['hardware_overrides'] = changed[:hardware_overrides]
      params['fronts']['items'][0]['type'] = from
      NxTest.assert_equal([custom, hinge], cb.normalize(params)[:hardware_overrides])
    end
  end
end

NxTest.test('CELA-B: seed zasah neozije po zmene roly ani so zlym ownerom') do
  cb = Noxun::Engine::CabinetBuilder
  cases = [['door', 'uchytkovy-profil', 'wing:single'], ['drawer_front', 'uchytkovy-profil-zasuvky', 'panel'],
           ['lift', 'uchytkovy-profil-vyklop', 'flap'], ['fall', 'uchytkovy-profil-sklop', 'flap'],
           ['blind', 'uchytkovy-profil-blenda', 'blind']]
  cases.each do |from, rid, part|
    cases.each do |to, _other_rid, _other_part|
      next if from == to
      ov = { 'rule_id' => rid, 'generic_type' => 'handle', 'owner_part_key' => "front:F1/#{part}", 'disabled' => true }
      p = { 'hardware_overrides' => [ov], 'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => to, 'profile' => 'ukw7' }] } }
      cfg = cb.normalize(p)
      NxTest.assert_equal([], cfg[:hardware_overrides], "#{from}->#{to}")
      p['hardware_overrides'] = cfg[:hardware_overrides]; p['fronts']['items'][0]['type'] = from
      NxTest.assert_equal([], cb.normalize(p)[:hardware_overrides], "navrat #{from}")
    end
    bad = { 'rule_id' => rid, 'generic_type' => 'handle', 'owner_part_key' => 'front:F1/obsolete', 'quantity' => 3 }
    cfg = cb.normalize('hardware_overrides' => [bad], 'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => from, 'profile' => 'ukw7' }] })
    NxTest.assert_equal([], cfg[:hardware_overrides], "#{from} zly owner")
  end
end



module NxCelaB
  E = Noxun::Engine
  F = E::Fronts
  P = E::FrontProfiles
  H = E::HardwareRules
  def self.config(type = 'door', edge = 'free', extra = {})
    { 'gap_left' => -18.0, 'gap_right' => 2.0,
      'items' => [{ 'id' => 'F1', 'type' => type, 'wings' => '2', 'profile' => 'ukw7',
                   'profile_edge' => edge, 'mode' => 'auto' }.merge(extra)] }
  end
  def self.layout(cfg)
    F.layout(cfg, 600.0, 720.0, 0.0, 18.0)
  end
end

NxTest.test('CELA-B: rozhodujuci dvojkridlove dvierka, profily v strede a zhodne rezy') do
  c = NxCelaB
  out = c.layout(c.config)
  NxTest.assert_equal(%w[right left], out[:parts].map { |p| p[:profile_edge] })
  NxTest.assert_equal([-18.0, 327.5], out[:parts].map { |p| p[:origin][0] })
  out[:parts].each do |p|
    NxTest.assert_equal([270.5, 18.0, 716.0], p[:box])
    NxTest.assert_equal(716.0, c::H.flag_length_params(p)['cut_length_mm'])
    NxTest.assert_equal(716.0, c::E::CabinetBuilder.profile_placement(p)[:length])
    NxTest.assert_equal(c::E::PartFaces::AXES_FRONT, p[:axes])
  end
  NxTest.assert_equal(716.0, out[:bounds]['F1'][:height], 'slot zasuvky sa profilom neskracuje')
  top = c.layout(c.config('door', 'top'))
  NxTest.assert_equal([306.5, 18.0, 680.0], top[:parts][0][:box])
  NxTest.assert_equal(306.5, c::H.flag_length_params(top[:parts][0])['cut_length_mm'])
end

NxTest.test('CELA-B: vsetky styri hrany neddvierkovych typov zachovaju obrys a prednu os') do
  c = NxCelaB
  %w[drawer_front lift fall blind].each do |type|
    %w[top bottom left right].each do |edge|
      p = c.layout(c.config(type, edge))[:parts].first
      g = c::P.panel_geometry(p)
      NxTest.assert_equal([-18.0, 2.0, 616.0, 716.0], g.values_at(:x, :z, :w, :h))
      vertical = %w[left right].include?(edge)
      NxTest.assert_equal(vertical ? [580.0, 18.0, 716.0] : [616.0, 18.0, 680.0], p[:box])
      NxTest.assert_equal(vertical ? 716.0 : 616.0, c::P.cut_length(p))
      pl = c::P.placement(p)
      NxTest.assert_equal(0.0, pl[:anchor][1], 'rotacia okolo Y neposuva nos za celo')
    end
  end
  NxTest.assert_equal([], c.layout(c.config('none'))[:parts])
end

NxTest.test('CELA-B: smery 1/2/3/4 a auto, preflight pyta presne chybajuce sloty') do
  c = NxCelaB
  [['1', { 'direction' => 'left' }, %w[right]],
   ['1', { 'direction' => 'right' }, %w[left]],
   ['2', {}, %w[right left]], ['auto', {}, %w[right left]],
   ['3', { 'wing_directions' => { 'p2' => 'right' } }, %w[right left left]],
   ['4', { 'wing_directions' => { 'p2' => 'left', 'p3' => 'right' } }, %w[right right left left]]].each do |w, extra, edges|
    cfg = c.config('door', 'free', extra.merge('wings' => w))
    NxTest.assert_equal(edges, c.layout(cfg)[:parts].map { |p| p[:profile_edge] })
  end
  %w[1 3 4].each do |w|
    cfg = c.config('door', 'free', 'wings' => w)
    pf = c::F.preflight(cfg, 600.0, 720.0, 0.0)
    NxTest.refute(pf['valid'])
    slots = c::F.direction_slots(pf['items'].first)
    NxTest.assert_equal(w == '4' ? %w[p2 p3] : [w == '1' ? 'single' : 'p2'], slots.map { |s| s[:wing] })
    NxTest.assert_raise(/smer pántov/) { c.layout(cfg) }
  end
  narrow = c::F.preflight(c.config('door', 'free', 'wings' => 'auto'), 500.0, 720.0, 0.0)
  NxTest.refute(narrow['valid'], 'auto prechod na jedno kridlo si vypyta smer')
end

NxTest.test('CELA-B: odmietnutie pred emission panela, nezname a neaplikovatelne hrany') do
  c = NxCelaB
  cfg = c.config('door', 'free', 'wings' => '4', 'wing_directions' => { 'p2' => 'left', 'p3' => 'right' })
  cfg.merge!('gap_left' => 25, 'gap_right' => 25)
  NxTest.assert_raise(/panel nezostane nič/) { c::F.layout(cfg, 200.0, 720.0, 0.0, 18.0) }
  [nil, '', 'diagonal', false, 5, 'left'].each do |edge|
    NxTest.assert_raise(/hran/) { c.layout(c.config('door', edge)) }
  end
  NxTest.assert_raise(/hran/) { c.layout(c.config('blind', 'free')) }
  NxTest.assert_equal(0, c.layout(c.config('door', 'free', 'profile' => 'none', 'wings' => '1'))[:warnings].length)
end

NxTest.test('CELA-B: legacy top identicke vyrobne udaje a profile_band; roundtrip edge bez fallbacku') do
  c = NxCelaB
  cfg = c.config('door', 'top'); cfg['items'][0].delete('profile_edge')
  p = c.layout(cfg)[:parts][0]
  NxTest.assert_equal({ length: 680.0, width: 306.5, thickness: 18.0 }, p[:prod])
  NxTest.assert_equal({ z: 682.0, h: 36.0 }, p[:profile_band])
  fresh = c.config
  normalized = c::F.normalize_config(fresh)
  NxTest.assert_equal(normalized, c::F.normalize_config(JSON.parse(JSON.generate(normalized))))
  invalid = c::F.normalize_config(c.config('door', nil))
  NxTest.assert(invalid['items'][0].key?('profile_edge'))
  NxTest.assert_equal(nil, invalid['items'][0]['profile_edge'])
  NxTest.assert_equal(13, c::E::CabinetBuilder::CONFIG_SCHEMA)
  NxTest.assert_equal(5, c::E::BuildPlan::SCHEMA)
end

NxTest.test('CELA-B: nakup nikdy nehada dlzku pri neplatnej explicitnej anotacii') do
  c = NxCelaB
  legacy = { profile: 'ukw7', prod: { width: 321.0, length: 654.0 } }
  NxTest.assert_equal(321.0, c::P.cut_length(legacy))
  NxTest.assert_equal(654.0, c::P.cut_length(legacy.merge(profile_edge: 'left')))
  [nil, '', 'free', 'diagonal'].each do |edge|
    NxTest.assert_equal({}, c::H.flag_length_params(legacy.merge(profile_edge: edge)))
  end
end

NxTest.test('CELA-B: seed doplni tri role/smery, vlastne smerove pokrytie a vypnute pravidla') do
  c = NxCelaB
  ids = %w[uchytkovy-profil-vyklop uchytkovy-profil-sklop uchytkovy-profil-blenda]
  old = c::H.normalize_rules(c::H::SEED_RULES.reject { |r| ids.include?(r['rule_id']) })
  copy = JSON.generate(old)
  fresh, added, = c::H.project_seed_plan(old)
  NxTest.assert_equal(ids.sort, added.sort)
  NxTest.assert_equal(copy, JSON.generate(old), 'cisty plan nemenil snapshot')
  down = { 'rule_id' => 'custom-down', 'enabled' => true, 'kind' => c::H::KIND_PROFILE,
           'output' => 'handle', 'quantity' => 1, 'applies_to' => { 'role' => 'flap', 'flap_dir' => 'down' } }
  _, added, = c::H.project_seed_plan(old + [down])
  NxTest.assert_equal(%w[uchytkovy-profil-blenda uchytkovy-profil-vyklop], added.sort)
  generic = down.merge('applies_to' => { 'role' => 'flap' })
  _, added, = c::H.project_seed_plan(old + [generic])
  NxTest.assert_equal(['uchytkovy-profil-blenda'], added)
  _, added, = c::H.project_seed_plan(old + [down.merge('enabled' => false)])
  NxTest.assert_equal(ids.sort, added.sort)
  disabled = fresh.map { |r| r['rule_id'] == ids[0] ? r.merge('enabled' => false) : r }
  NxTest.assert_equal([], c::H.project_seed_plan(disabled)[1])
end

NxTest.test('CELA-B: warning aj evaluate respektuju ten isty smer profiloveho pravidla') do
  c = NxCelaB
  up = c.layout(c.config('lift', 'left'))[:parts].first.merge(flap_dir: 'up')
  down = c::H::SEED_RULES.find { |r| r['rule_id'] == 'uchytkovy-profil-sklop' }
  NxTest.refute(c::H.part_rule_applies?(down, up))
  NxTest.assert_equal(1, c::H.profile_rule_warnings([up], [down]).length)
  generic = down.merge('applies_to' => { 'role' => 'flap' })
  NxTest.assert(c::H.part_rule_applies?(generic, up))
  NxTest.assert_equal([], c::H.profile_rule_warnings([up], [generic]))
  NxTest.assert_equal([], c::H.profile_rule_warnings([up], [generic.merge('enabled' => false)]))
end

