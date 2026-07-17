# frozen_string_literal: true
# Testy BuildPlan kontraktu (core/build_plan.rb) + napojenia v construction/zone_tree/builder.
require_relative '../helper' unless defined?(NxTest)

module NxBP
  module_function

  def engine
    Noxun::Engine
  end

  def valid_part(over = {})
    {
      suffix: 'SIDE-L', part_key: 'cabinet/side:left', role: 'side_left', name: 'Bok lavy',
      material: :korpus, box: [18.0, 510.0, 602.0], origin: [0.0, 0.0, 118.0],
      prod: { length: 602.0, width: 510.0, thickness: 18.0 }
    }.merge(over)
  end

  def valid_plan(parts = [valid_part])
    { schema: engine::BuildPlan::SCHEMA, parts: parts, hardware: [], warnings: [],
      zones: [], zone_tree: {}, front_items: [], available: {}, wings: 0, interior: {} }
  end
end

NxTest.test('build_plan: PartKeys.valid? akceptuje len stabilne formaty') do
  pk = Noxun::Engine::PartKeys
  NxTest.assert(pk.valid?('cabinet/side:left'), 'cabinet/ kluc ma prejst')
  NxTest.assert(pk.valid?('zone:Zabc/shelf:1'), 'zone: kluc ma prejst')
  NxTest.assert(pk.valid?('front:F2/wing:left'), 'front: kluc ma prejst')
  NxTest.refute(pk.valid?(''), 'prazdny kluc nesmie prejst')
  NxTest.refute(pk.valid?('SIDE-L'), 'renderovaci suffix nie je identita')
  NxTest.refute(pk.valid?('cabinet/'), 'prefix bez zvysku nesmie prejst')
  NxTest.refute(pk.valid?('cabinet/a b'), 'medzera v kluci nesmie prejst')
end

NxTest.test('build_plan: warning() ma jednotny string-keyed tvar (JSON round-trip)') do
  w = Noxun::Engine::BuildPlan.warning('x_code', 'sprava', part_key: 'cabinet/top', data: { 'a' => 1 })
  NxTest.assert_equal('x_code', w['code'])
  NxTest.assert_equal('warn', w['severity'])
  NxTest.assert_equal('sprava', w['message'])
  NxTest.assert_equal('cabinet/top', w['part_key'])
  NxTest.assert_equal({ 'a' => 1 }, w['data'])
  round = JSON.parse(w.to_json)
  NxTest.assert_equal(w, round, 'warning musi prezit JSON round-trip bez zmeny')
end

NxTest.test('build_plan: validate! prejde na rucne zostavenom validnom plane') do
  plan = NxBP.valid_plan
  NxTest.assert_equal(plan, Noxun::Engine::BuildPlan.validate!(plan))
end

NxTest.test('build_plan: validate! odmieta zly tvar planu') do
  bp = Noxun::Engine::BuildPlan
  NxTest.assert_raise('musi byt Hash') { bp.validate!(nil) }
  NxTest.assert_raise('neznama schema') { bp.validate!(NxBP.valid_plan.merge(schema: 99)) }
  NxTest.assert_raise('parts musi byt pole') { bp.validate!(NxBP.valid_plan.merge(parts: nil)) }
  NxTest.assert_raise('warnings musi byt pole') { bp.validate!(NxBP.valid_plan.merge(warnings: nil)) }
  NxTest.assert_raise('hardware musi byt pole') { bp.validate!(NxBP.valid_plan.merge(hardware: nil)) }
end

NxTest.test('build_plan: validate_part! odmieta chybne dielce') do
  bp = Noxun::Engine::BuildPlan
  NxTest.assert_raise('neplatny part_key') { bp.validate_part!(NxBP.valid_part(part_key: 'SIDE-L')) }
  NxTest.assert_raise('nema suffix') { bp.validate_part!(NxBP.valid_part(suffix: '')) }
  NxTest.assert_raise('neznamu rolu') { bp.validate_part!(NxBP.valid_part(role: 'ufo')) }
  NxTest.assert_raise('nema nazov') { bp.validate_part!(NxBP.valid_part(name: ' ')) }
  NxTest.assert_raise('neplatny material') { bp.validate_part!(NxBP.valid_part(material: 'korpus')) }
  NxTest.assert_raise('neplatny box') { bp.validate_part!(NxBP.valid_part(box: [18.0, 0.0, 602.0])) }
  NxTest.assert_raise('neplatny origin') { bp.validate_part!(NxBP.valid_part(origin: [0.0, 'x', 0.0])) }
  NxTest.assert_raise('nema prod') { bp.validate_part!(NxBP.valid_part(prod: nil)) }
  NxTest.assert_raise('neplatny prod thickness') { bp.validate_part!(NxBP.valid_part(prod: { length: 1.0, width: 1.0, thickness: 0.0 })) }
  NxTest.assert_raise('neznamu production_class') { bp.validate_part!(NxBP.valid_part(production_class: 'doska')) }
  NxTest.assert_raise('neplatnu quantity') { bp.validate_part!(NxBP.valid_part(quantity: 0)) }
end

NxTest.test('build_plan: duplicitny part_key zhodi validate! (nie az migrate_overrides)') do
  plan = NxBP.valid_plan([NxBP.valid_part, NxBP.valid_part(suffix: 'SIDE-X')])
  NxTest.assert_raise('duplicitny part_key') { Noxun::Engine::BuildPlan.validate!(plan) }
end

NxTest.test('build_plan: volitelne polia s defaultmi prejdu (counted hardware dielec buducnosti)') do
  pd = NxBP.valid_part(production_class: 'counted', manufactured: false, quantity: 4)
  NxTest.assert_equal(pd, Noxun::Engine::BuildPlan.validate_part!(pd))
end

NxTest.test('build_plan: validate_hardware! kontrakt kovania') do
  bp = Noxun::Engine::BuildPlan
  ok = { owner_part_key: 'front:F1/wing:left', generic_type: 'hinge', quantity: 2, rule_id: 'r1', variant_id: nil }
  NxTest.assert_equal(ok, bp.validate_hardware!(ok))
  NxTest.assert_equal(nil, bp.validate_hardware!(ok.merge(owner_part_key: nil))[:owner_part_key], 'nil owner = korpus ako celok')
  NxTest.assert_raise('neplatny owner_part_key') { bp.validate_hardware!(ok.merge(owner_part_key: 'HINGE-1')) }
  NxTest.assert_raise('prazdny generic_type') { bp.validate_hardware!(ok.merge(generic_type: '')) }
  NxTest.assert_raise('neplatnu quantity') { bp.validate_hardware!(ok.merge(quantity: 0)) }
end

NxTest.test('build_plan: realny plan z normalize({}) nesie schema + hardware[] + warnings[]') do
  cfg = Noxun::Engine::CabinetBuilder.normalize({})
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  NxTest.assert_equal(Noxun::Engine::BuildPlan::SCHEMA, plan[:schema])
  NxTest.assert_equal([], plan[:hardware])
  NxTest.assert(plan[:warnings].is_a?(Array), 'warnings musi byt pole')
  NxTest.assert_equal([], plan[:warnings], 'default dolna skrinka nema ziadne upozornenia')
end

NxTest.test('build_plan: orezana vystuha hlasi rail_depth_clamped warning') do
  cfg = Noxun::Engine::CabinetBuilder.normalize(
    'type' => 'lower', 'depth' => 150.0, 'top_mode' => 'two_rails', 'rail_depth' => 400.0
  )
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  w = plan[:warnings].find { |x| x['code'] == 'rail_depth_clamped' }
  NxTest.assert(!w.nil?, "cakal som rail_depth_clamped, warnings: #{plan[:warnings].inspect}")
  NxTest.assert_close(400.0, w['data']['wanted'])
  NxTest.assert_close(65.0, w['data']['used'], 0.01, 'depth 150 -> d/2-10 = 65 mm')
  rail = plan[:parts].find { |pd| pd[:role] == 'rail_front' }
  NxTest.assert_close(65.0, rail[:prod][:width], 0.01, 'plan aj warning musia hovorit to iste')
end

NxTest.test('build_plan: nechcene orezanie sa nehlasi (rail_depth v limite)') do
  cfg = Noxun::Engine::CabinetBuilder.normalize(
    'type' => 'lower', 'depth' => 510.0, 'top_mode' => 'two_rails', 'rail_depth' => 100.0
  )
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  NxTest.assert_equal([], plan[:warnings].select { |x| x['code'] == 'rail_depth_clamped' })
end

NxTest.test('build_plan: prilis plytka zona hlasi shelf_skipped_shallow_zone (police preskocene)') do
  zt = Noxun::Engine::ZoneTree
  tree = zt.default_tree(2)
  box = { x0: 18.0, x1: 582.0, y0: 0.0, y1: 15.0, z0: 118.0, z1: 702.0 }
  res = zt.compute(tree, box, 18.0, 'CAB-001')
  NxTest.assert_equal([], res[:shelves], 'police sa nepostavia')
  w = res[:warnings].find { |x| x['code'] == 'shelf_skipped_shallow_zone' }
  NxTest.assert(!w.nil?, "cakal som shelf_skipped_shallow_zone, warnings: #{res[:warnings].inspect}")
  NxTest.assert_equal(2, w['data']['count'])
end

NxTest.test('build_plan: merge_final prenasa plan_schema + warnings + hardware do configu') do
  cfg = Noxun::Engine::CabinetBuilder.normalize({})
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  merged = Noxun::Engine::CabinetBuilder.merge_final(cfg, plan)
  NxTest.assert_equal(Noxun::Engine::BuildPlan::SCHEMA, merged[:plan_schema])
  NxTest.assert_equal([], merged[:warnings])
  NxTest.assert_equal([], merged[:hardware])
  persisted = Noxun::Engine::CabinetBuilder.cabinet_config(merged)
  NxTest.assert_equal(Noxun::Engine::BuildPlan::SCHEMA, persisted[:plan_schema])
  NxTest.assert_equal([], persisted[:warnings])
  NxTest.assert_equal([], persisted[:hardware])
end

NxTest.test('build_plan: degenerovany dielec (rozmer <= MIN_DIM) vypadne z planu s warningom, bez raise') do
  # Scenar z adversarialnej revizie: nezamknute polia s extremnym pomerom sizes —
  # resolve_fields prideli polu ~0.002 mm, polica v nom by mala nekladny vyrobny rozmer.
  # Kontrakt: dielec sa vyradi UZ v plane (part_skipped_degenerate), validator nepadne
  # a prah je zhodny s builderom (BuildPlan::MIN_DIM) — ziadne pasmo tichych preskoceni.
  tree = {
    'id' => 'Z1', 'generation' => 1,
    'split' => { 'axis' => 'v', 'count' => 2,
                 'cuts' => [{ 'size' => 0.002, 'locked' => false }, { 'size' => 600.0, 'locked' => false }] },
    'shelves' => 0,
    'children' => [
      { 'id' => 'Ztiny', 'generation' => 0, 'split' => nil, 'shelves' => 1, 'children' => [] },
      { 'id' => 'Zbig', 'generation' => 0, 'split' => nil, 'shelves' => 0, 'children' => [] }
    ]
  }
  cfg = Noxun::Engine::CabinetBuilder.normalize('zone_tree' => tree)
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  NxTest.assert_equal(Noxun::Engine::BuildPlan::SCHEMA, plan[:schema], 'plan musi prejst validatorom bez raise')
  w = plan[:warnings].find { |x| x['code'] == 'part_skipped_degenerate' }
  NxTest.assert(!w.nil?, "cakal som part_skipped_degenerate, warnings: #{plan[:warnings].inspect}")
  tiny_shelf = plan[:parts].find { |pd| pd[:part_key] == 'zone:Ztiny/shelf:1' }
  NxTest.assert(tiny_shelf.nil?, 'degenerovana polica nesmie byt v parts (kusovnik = geometria)')
  NxTest.assert(plan[:parts].all? { |pd| pd[:box].all? { |v| v > Noxun::Engine::BuildPlan::MIN_DIM } },
                'vsetky dielce v plane su nad prahom MIN_DIM')
end

NxTest.test('build_plan: kazdy plan z matrixu variantov prejde validatorom') do
  %w[under_sides between_sides].each do |bm|
    %w[full two_rails none].each do |tm|
      %w[overlay inset groove].each do |bkm|
        cfg = Noxun::Engine::CabinetBuilder.normalize(
          'bottom_mode' => bm, 'top_mode' => tm, 'back_mode' => bkm
        )
        plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
        NxTest.assert_equal(Noxun::Engine::BuildPlan::SCHEMA, plan[:schema], "#{bm}/#{tm}/#{bkm}")
      end
    end
  end
end
