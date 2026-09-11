# frozen_string_literal: true
require_relative 'test_mr1b2_copy_source'
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine/core/materials_build_appearance')
end

# Testuje rozhodovanie nad capture kontraktom, NIE fyzicke ziskanie ploch.
# Capture kvadra, inherited face/back a izolacia definicii sa dokazuju v SU.
module NxMRB2
  E = Noxun::Engine
  M = E::Materials
  N = E::NativeAppearance
  SCOPE = ['GRP-MRB2', 'ST9'].freeze
  R1 = '41d81f89-240a-4e89-93bf-081745497301'
  R2 = '41d81f89-240a-4e89-93bf-081745497302'
  Color = Struct.new(:red, :green, :blue)
  Face = Struct.new(:material, :back_material)

  class Material < NxTest::FakeEntity
    attr_accessor :name, :texture, :alpha, :alive
    attr_reader :model, :color, :color_writes
    def initialize(model, name)
      super()
      @model, @name = model, name
      @alpha = 1.0
      @alive = true
      @color = Color.new(25, 35, 45)
      @color_writes = 0
    end
    def valid? = alive
    def get_attribute(dict, key, default = nil)
      dicts.fetch(dict, {}).fetch(key, default)
    end
    def color=(value)
      @color_writes += 1
      @color = value
    end
  end

  class WorkflowMaterial < Material
    WORKFLOW_CLASSIC = 71 # Zamerne nie 0: runtime porovnava pomenovanu konstantu.
    attr_accessor :workflow
    def initialize(*)
      super
      @workflow = WORKFLOW_CLASSIC
    end
  end

  class Collection < Array
    attr_reader :model, :load_calls
    attr_accessor :load_error
    def initialize(model)
      super()
      @model = model
      @load_calls = 0
    end
    def [](key)
      key.is_a?(String) ? find { |material| material.name == key } : super
    end
    def add(name)
      base = name
      number = 1
      name = "#{base}##{number += 1}" while self[name]
      material = Material.new(model, name)
      self << material
      material
    end
    def load(_path)
      @load_calls += 1
      raise(load_error || 'Nativny load nie je predmetom pure testu')
    end
  end

  class Model < NxMRB2Copy::Model
    attr_reader :materials
    def initialize
      super
      @materials = Collection.new(self)
    end
  end

  module_function
  def b = E::BuildAppearance
  def descriptor(id = R1, mode = 'native')
    { 'version' => 1, 'id' => id, 'mode' => mode, 'saved_at' => '2026-09-11T08:00:00Z' }
  end
  def row(id, kind = :sheet, appearance = nil, scope = SCOPE)
    out = { (kind == :sheet ? 'material_id' : 'abs_id') => id, 'group_id' => scope[0],
            'structure' => scope[1], 'color' => [210, 190, 170], 'uni' => false }
    out['appearance'] = appearance if appearance
    out
  end
  def native(model, revision = R1, scope = SCOPE)
    material = model.materials.add('Pouzivatelom premenovany material')
    material.set_attribute('NOXUN', 'appearance_scope', JSON.generate(scope))
    material.set_attribute('NOXUN', 'appearance_id', revision)
    material
  end
  def channel(material, state: b.classify(material), inherited: nil)
    { state: state, material: material, inherited_sheet_id: inherited, error: nil }
  end
  def previous(model, material, kind: :sheet, id: 'S18', inherited: nil)
    channel(material, inherited: inherited).merge(model: model, kind: kind, id: id)
  end
  def record(material, id: 'S18', role: 'side', edges: {})
    { role: role, material_id: id, sheet: channel(material), edges: edges }
  end
  def context(owner, records, target: nil, unaddressable: [])
    id = E::Store.get(owner, 'cabinet_id')
    { model: owner.model, owner: owner, owner_id: id, target_id: target || id,
      parts: { 'cabinet/side:left' => records }, unaddressable: unaddressable }
  end
  def part(ctx, **changes)
    b.for_part(ctx, **{ model: ctx[:model], owner: ctx[:owner], part_key: 'cabinet/side:left',
                       role: 'side', material_id: 'S18', edges: {} }.merge(changes))
  end
  def error(klass = b::CaptureError)
    caught = NxTest.assert_raise { yield }
    NxTest.assert(caught.is_a?(klass), "ocakavana #{klass}, prisla #{caught.class}: #{caught.message}")
    caught
  end
  def ensure_material(s, id = 'S18', kind: :sheet, previous: nil)
    method = kind == :sheet ? :ensure_su_material : :ensure_su_edge_material
    M.public_send(method, s[:model], id, [7, 8, 9], previous: previous)
  end
  def snapshot(material)
    [material.name, material.texture, material.alpha, material.color.to_a,
     JSON.generate(material.dicts), material.color_writes]
  end
  def with_painter
    cb = E::CabinetBuilder
    su = Module.new
    su.const_set(:Face, Face)
    NxMRB2Copy.with_constants(cb, Sketchup: su) do
      NxMRB2Copy.stub(E::PartFaces, :verified_axes, ->(*) { { length: 0, width: 1, thickness: 2 } }) do
        NxMRB2Copy.stub(E::PartFaces, :edge_code_for_center, ->(*) { 'L1' }) do
          NxMRB2Copy.stub(cb, :face_center_mm, ->(*) { [0, 0, 0] }) { yield cb }
        end
      end
    end
  end
  def isolated
    NxTest.skip!('Material doubles nikdy nepatria do ziveho SketchUpu') unless NxTest.headless?
    model = Model.new
    state = { model: model, sheets: { 'S18' => row('S18') }, edges: { 'E23' => row('E23', :edge) }, logs: [] }
    su = Module.new
    su.const_set(:Color, Color)
    su.const_set(:Material, WorkflowMaterial)
    su.define_singleton_method(:active_model) { model }
    original_dir = M.test_dir_override
    Dir.mktmpdir('noxun-mrb2-') do |dir|
      M.test_dir_override = dir
      NxMRB2Copy.with_constants(b, Sketchup: su) do
        NxMRB2Copy.with_constants(M, Sketchup: su) do
          NxMRB2Copy.stub(M, :sheet, ->(id) { state[:sheets][id.to_s] }) do
            NxMRB2Copy.stub(M, :edge, ->(id) { state[:edges][id.to_s] }) do
              NxMRB2Copy.stub(E, :log, ->(message) { state[:logs] << message }) { yield state }
            end
          end
        end
      end
    end
  ensure
    M.test_dir_override = original_dir if NxTest.headless?
  end
end

NxTest.test('MR-B2 classify: nil, stare RGB a podporovany classic workflow su plain') do
  NxMRB2.isolated do |s|
    material = s[:model].materials.add('S18')
    NxTest.assert_equal(:plain, NxMRB2.b.classify(nil))
    NxTest.assert_equal(:plain, NxMRB2.b.classify(material))
    material.color = NxMRB2::Color.new(1, 2, 3)
    NxTest.assert_equal(:plain, NxMRB2.b.classify(material), 'odlisna RGB sama nie je ochrana')
    NxTest.assert_equal(:plain, NxMRB2.b.classify(NxMRB2::WorkflowMaterial.new(s[:model], 'classic')))
  end
end

NxTest.test('MR-B2 classify: textura, alpha, PBR aj native bez albeda su protected') do
  NxMRB2.isolated do |s|
    material = s[:model].materials.add('S18')
    material.texture = Object.new
    NxTest.assert_equal(:protected, NxMRB2.b.classify(material))
    material.texture = nil
    material.alpha = 0.7
    NxTest.assert_equal(:protected, NxMRB2.b.classify(material))
    pbr = NxMRB2::WorkflowMaterial.new(s[:model], 'PBR')
    pbr.workflow = 72
    NxTest.assert_equal(:protected, NxMRB2.b.classify(pbr))
    NxTest.assert_equal(:protected, NxMRB2.b.classify(NxMRB2.native(s[:model])))
  end
end

NxTest.test('MR-B2 classify: mrtvy handle, poskodeny tuple a chyba citania nikdy nie su plain') do
  NxMRB2.isolated do |s|
    material = s[:model].materials.add('S18')
    material.alive = false
    NxTest.assert_equal(:unknown, NxMRB2.b.classify(material))
    material.alive = true
    material.set_attribute('NOXUN', 'appearance_id', NxMRB2::R1)
    NxTest.assert_equal(:unknown, NxMRB2.b.classify(material))
    material.set_attribute('NOXUN', 'appearance_scope', 'broken-json')
    NxTest.assert_equal(:unknown, NxMRB2.b.classify(material))
    unreadable = s[:model].materials.add('unknown')
    unreadable.define_singleton_method(:texture) { raise 'material read failed' }
    NxTest.assert_equal(:unknown, NxMRB2.b.classify(unreadable))
  end
end

NxTest.test('MR-B2 previous: vyber ma presny model, owner, part, rolu a ABS slot') do
  NxMRB2.isolated do |s|
    owner = NxMRB2Copy::Cabinet.new(s[:model])
    material = NxMRB2.native(s[:model])
    edge = { abs_id: 'E23', channel: NxMRB2.channel(material, inherited: 'S18') }
    ctx = NxMRB2.context(owner, [NxMRB2.record(material, edges: { 'L1' => edge })])
    out = NxMRB2.part(ctx, edges: { 'L1' => 'E23', 'L2' => 'E23' })
    NxTest.assert_equal(material, out[:sheet][:material])
    NxTest.assert_equal(s[:model], out[:sheet][:model])
    NxTest.assert_equal(:sheet, out[:sheet][:kind])
    NxTest.assert_equal('S18', out[:sheet][:id])
    NxTest.assert_equal(material, out[:edges]['L1'][:material])
    NxTest.assert_equal(:edge, out[:edges]['L1'][:kind])
    NxTest.assert_equal('S18', out[:edges]['L1'][:inherited_sheet_id])
    NxTest.assert_equal(nil, out[:edges]['L2'], 'zhodne ABS ID na inom slote nie je dokaz povodu')
  end
end

NxTest.test('MR-B2 previous: zmenene vyrobne ID alebo rola a novy part nededia stary sheet') do
  NxMRB2.isolated do |s|
    owner = NxMRB2Copy::Cabinet.new(s[:model])
    material = NxMRB2.native(s[:model])
    edge = { abs_id: 'E23', channel: NxMRB2.channel(material) }
    ctx = NxMRB2.context(owner, [NxMRB2.record(material, edges: { 'L1' => edge })])
    out = NxMRB2.part(ctx, material_id: 'S16', edges: { 'L1' => 'E23' })
    NxTest.assert_equal(nil, out[:sheet], 'aj ina hrubka rovnakeho scope je nove vyrobne ID')
    NxTest.assert_equal(material, out[:edges]['L1'][:material], 'nezmeneny ABS slot sa zachovava samostatne')
    NxTest.assert_equal(nil, NxMRB2.part(ctx, role: 'shelf')[:sheet])
    NxTest.assert_equal(nil, NxMRB2.part(ctx, part_key: 'cabinet/side:right')[:sheet])
    NxTest.assert_equal(nil, NxMRB2.part(ctx, edges: { 'L1' => 'E42' })[:edges]['L1'])
  end
end

NxTest.test('MR-B2 previous: cudzi model, iny owner, mrtvy owner a prepis ID sa odmietnu') do
  NxMRB2.isolated do |s|
    owner = NxMRB2Copy::Cabinet.new(s[:model])
    ctx = NxMRB2.context(owner, [NxMRB2.record(nil)])
    NxMRB2.error { NxMRB2.part(ctx, model: NxMRB2::Model.new) }
    NxMRB2.error { NxMRB2.part(ctx, owner: NxMRB2Copy::Cabinet.new(s[:model])) }
    owner.alive = false
    NxMRB2.error { NxMRB2.part(ctx) }
    owner.alive = true
    NxMRB2::E::Store.write(owner, cabinet_id: 'CAB-OTHER')
    NxMRB2.error { NxMRB2.part(ctx) }
  end
end

NxTest.test('MR-B2 previous: dedup cielove ID povoli iba povodnu konkretnu instanciu') do
  NxMRB2.isolated do |s|
    owner = NxMRB2Copy::Cabinet.new(s[:model])
    material = NxMRB2.native(s[:model])
    ctx = NxMRB2.context(owner, [NxMRB2.record(material)], target: 'CAB-002')
    NxMRB2.error { NxMRB2.part(ctx) }
    NxMRB2::E::Store.write(owner, cabinet_id: 'CAB-002')
    NxTest.assert_equal(material, NxMRB2.part(ctx)[:sheet][:material])
    impostor = NxMRB2Copy::Cabinet.new(s[:model], 'CAB-002')
    NxMRB2.error { NxMRB2.part(ctx, owner: impostor) }
  end
end

NxTest.test('MR-B2 previous: duplicitny plain capture neblokuje legacy, protected nevyberie prvy') do
  NxMRB2.isolated do |s|
    owner = NxMRB2Copy::Cabinet.new(s[:model])
    plain = s[:model].materials.add('S18')
    records = [NxMRB2.record(plain), NxMRB2.record(nil)]
    ctx = NxMRB2.context(owner, records)
    NxTest.assert_equal(nil, NxMRB2.part(ctx)[:sheet])
    records[1] = NxMRB2.record(NxMRB2.native(s[:model]))
    NxMRB2.error { NxMRB2.part(ctx) }
    NxTest.assert_equal(nil, NxMRB2.part(ctx, material_id: 'EXPLICIT-NEW')[:sheet])
  end
end

NxTest.test('MR-B2 previous: neadresovatelny plain sa pusti, protected/unknown sa prizna aj pri prazdnom plane') do
  NxMRB2.isolated do |s|
    owner = NxMRB2Copy::Cabinet.new(s[:model])
    unknown = NxMRB2.record(nil)
    ctx = NxMRB2.context(owner, [], unaddressable: [unknown])
    NxMRB2.b.validate_context!(ctx, model: s[:model], owner: owner)
    unknown[:sheet] = NxMRB2.channel(NxMRB2.native(s[:model]))
    NxMRB2.error { NxMRB2.b.validate_context!(ctx, model: s[:model], owner: owner) }
    unknown[:sheet] = NxMRB2.channel(nil, state: :unknown)
    NxMRB2.error { NxMRB2.b.validate_context!(ctx, model: s[:model], owner: owner) }
  end
end

NxTest.test('MR-B2 ensure: vlastna native R1 prezije katalogovu R2 aj color tombstone bez RGB zapisu') do
  NxMRB2.isolated do |s|
    original = NxMRB2.native(s[:model])
    before = NxMRB2.snapshot(original)
    %w[native color].each do |mode|
      s[:sheets]['S18']['appearance'] = NxMRB2.descriptor(NxMRB2::R2, mode)
      s[:edges]['E23']['appearance'] = NxMRB2.descriptor(NxMRB2::R2, mode)
      NxTest.assert_equal(original, NxMRB2.ensure_material(s, previous: NxMRB2.previous(s[:model], original)))
      prev = NxMRB2.previous(s[:model], original, kind: :edge, id: 'E23')
      NxTest.assert_equal(original, NxMRB2.ensure_material(s, 'E23', kind: :edge, previous: prev))
    end
    NxTest.assert_equal(before, NxMRB2.snapshot(original))
    NxTest.assert_equal(0, s[:model].materials.load_calls)
  end
end

NxTest.test('MR-B2 ensure: nove dosky roznych hrubok a ABS pouziju presnu spolocnu aktualnu reviziu') do
  NxMRB2.isolated do |s|
    old = NxMRB2.native(s[:model])
    current = NxMRB2.native(s[:model], NxMRB2::R2)
    s[:sheets]['S16'] = NxMRB2.row('S16')
    s[:sheets]['S36'] = NxMRB2.row('S36')
    s[:sheets].each_value { |r| r['appearance'] = NxMRB2.descriptor(NxMRB2::R2) }
    s[:edges]['E23']['appearance'] = NxMRB2.descriptor(NxMRB2::R2)
    %w[S16 S18 S36].each { |id| NxTest.assert_equal(current, NxMRB2.ensure_material(s, id)) }
    NxTest.assert_equal(current, NxMRB2.ensure_material(s, 'E23', kind: :edge))
    NxTest.assert_equal(0, old.color_writes)
    NxTest.assert_equal(0, current.color_writes)
    NxTest.assert_equal(0, s[:model].materials.load_calls, 'presny native reuse nema citat subor')
  end
end

NxTest.test('MR-B2 ensure: nedostupna R2 neukradne staru R1 z inej skrinky a loguje RGB fallback') do
  NxMRB2.isolated do |s|
    old = NxMRB2.native(s[:model])
    before = NxMRB2.snapshot(old)
    s[:sheets]['S18']['appearance'] = NxMRB2.descriptor(NxMRB2::R2)
    color = NxMRB2.ensure_material(s)
    NxTest.refute(color.equal?(old))
    NxTest.assert_equal(:plain, NxMRB2.b.classify(color))
    NxTest.assert_equal([210, 190, 170], color.color.to_a)
    NxTest.assert_equal(before, NxMRB2.snapshot(old))
    NxTest.assert(!s[:logs].empty?, 'nedostupny subor ma priznany fallback')
  end
end

NxTest.test('MR-B2 ensure: chybanie katalogoveho zaznamu neznici dokazany native previous') do
  NxMRB2.isolated do |s|
    original = NxMRB2.native(s[:model])
    s[:sheets].clear
    NxTest.assert_equal(original, NxMRB2.ensure_material(s, previous: NxMRB2.previous(s[:model], original)))
    NxTest.assert_equal(0, original.color_writes)
  end
end

NxTest.test('MR-B2 ensure: stara zdedena textura sheetu je platna ABS len s dokazom slotu a rovnakeho scope') do
  NxMRB2.isolated do |s|
    sheet = s[:model].materials.add('S18')
    sheet.texture = Object.new
    prev = NxMRB2.previous(s[:model], sheet, kind: :edge, id: 'E23', inherited: 'S18')
    NxTest.assert_equal(sheet, NxMRB2.ensure_material(s, 'E23', kind: :edge, previous: prev))
    NxMRB2.error { NxMRB2.ensure_material(s, 'E23', kind: :edge, previous: prev.merge(inherited_sheet_id: nil)) }
    s[:edges]['E23']['structure'] = 'ST10'
    NxMRB2.error { NxMRB2.ensure_material(s, 'E23', kind: :edge, previous: prev) }
    NxTest.assert_equal(0, sheet.color_writes)
  end
end

NxTest.test('MR-B2 ensure: vlastny legacy sheet a ABS drzia handle, cudzie meno sa nepreoznaci') do
  NxMRB2.isolated do |s|
    [[:sheet, 'S18', 'S18'], [:edge, 'E23', NxMRB2::M.su_edge_material_name('E23')]].each do |kind, id, name|
      material = s[:model].materials.add(name)
      material.texture = Object.new
      prev = NxMRB2.previous(s[:model], material, kind: kind, id: id)
      NxTest.assert_equal(material, NxMRB2.ensure_material(s, id, kind: kind, previous: prev))
      material.name = 'Cudzi material'
      NxMRB2.error { NxMRB2.ensure_material(s, id, kind: kind, previous: prev) }
      NxTest.assert_equal('Cudzi material', material.name)
      NxTest.assert_equal(0, material.color_writes)
    end
  end
end

NxTest.test('MR-B2 ensure: color nevypere texturu pod starym menom a dalsi rebuild opakovane pouzije cisty handle') do
  NxMRB2.isolated do |s|
    styled = s[:model].materials.add('S18')
    styled.texture = Object.new
    before = NxMRB2.snapshot(styled)
    s[:sheets]['S18']['appearance'] = NxMRB2.descriptor(NxMRB2::R2, 'color')
    clean = NxMRB2.ensure_material(s)
    NxTest.refute(clean.equal?(styled))
    NxTest.assert_equal(:plain, NxMRB2.b.classify(clean))
    s[:sheets]['S18']['color'] = [40, 50, 60]
    prev = NxMRB2.previous(s[:model], clean)
    NxTest.assert_equal(clean, NxMRB2.ensure_material(s, previous: prev))
    NxTest.assert_equal([40, 50, 60], clean.color.to_a)
    NxTest.assert_equal(clean, NxMRB2.ensure_material(s))
    NxTest.assert_equal(2, s[:model].materials.length)
    NxTest.assert_equal(before, NxMRB2.snapshot(styled))
    NxTest.assert_equal(nil, clean.get_attribute('NOXUN', 'appearance_id'))
  end
end

NxTest.test('MR-B2 ensure: model/kind/ID previous a zanik materialu su tvrde guardy') do
  NxMRB2.isolated do |s|
    material = NxMRB2.native(s[:model])
    prev = NxMRB2.previous(s[:model], material)
    [{ model: NxMRB2::Model.new }, { kind: :edge }, { id: 'S16' }, { state: :unknown }].each do |change|
      NxMRB2.error { NxMRB2.ensure_material(s, previous: prev.merge(change)) }
    end
    s[:model].materials.delete(material)
    NxMRB2.error { NxMRB2.ensure_material(s, previous: prev) }
    NxTest.assert_equal(0, material.color_writes)
  end
end

NxTest.test('MR-B2 ensure: native tuple konflikt a load failure prechadzaju cez oba ensure rescue') do
  NxMRB2.isolated do |s|
    NxMRB2.native(s[:model])
    NxMRB2.native(s[:model])
    s[:sheets]['S18']['appearance'] = NxMRB2.descriptor
    s[:edges]['E23']['appearance'] = NxMRB2.descriptor
    NxMRB2.error(NxMRB2::N::IdentityError) { NxMRB2.ensure_material(s) }
    NxMRB2.error(NxMRB2::N::IdentityError) { NxMRB2.ensure_material(s, 'E23', kind: :edge) }
    s[:model].materials.clear
    path = NxMRB2::M.appearance_file(NxMRB2::R1)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, 'fixture: load must fail')
    s[:model].materials.load_error = 'broken skm'
    NxMRB2.error(NxMRB2::N::LoadError) { NxMRB2.ensure_material(s) }
    NxMRB2.error(NxMRB2::N::LoadError) { NxMRB2.ensure_material(s, 'E23', kind: :edge) }
    NxTest.assert_equal(2, s[:model].materials.load_calls)
  end
end

NxTest.test('MR-B2 ensure: UNI zostava cista farba bez native reuse alebo zapisov do protected zdroja') do
  NxMRB2.isolated do |s|
    source = NxMRB2.native(s[:model])
    s[:sheets]['S18']['uni'] = true
    s[:sheets]['S18']['appearance'] = NxMRB2.descriptor
    out = NxMRB2.ensure_material(s, previous: NxMRB2.previous(s[:model], source))
    NxTest.refute(out.equal?(source))
    NxTest.assert_equal(:plain, NxMRB2.b.classify(out))
    NxTest.assert_equal(nil, out.get_attribute('NOXUN', 'appearance_id'))
    NxTest.assert_equal(0, source.color_writes)
    NxTest.assert_equal(0, s[:model].materials.load_calls)
  end
end

NxTest.test('MR-B2 build seam: explicitny source putuje ako keyword mimo zmrazeneho InsertPlanu') do
  NxMRB2.isolated do |s|
    cb = NxMRB2::E::CabinetBuilder
    owner = NxMRB2Copy::Cabinet.new(s[:model])
    params = { width: 650.0, height: 720.0, depth: 560.0 }
    calls = []
    commit = ->(model, plan, **options) { calls << [model, plan, options]; :created }
    NxMRB2Copy.stub(cb, :commit_insert, commit) do
      NxTest.assert_equal(:created, cb.build(s[:model], params, appearance_source: owner))
      NxTest.assert_equal(:created, cb.build(s[:model], width: 800.0, height: 720.0, appearance_source: owner))
      NxTest.assert_equal(:created, cb.build(s[:model], params))
      calls.first(2).each do |model, plan, options|
        NxTest.assert_equal(s[:model], model)
        NxTest.assert(options[:appearance_source].equal?(owner))
        NxTest.assert(plan.config.frozen?)
        NxTest.refute(plan.config.key?(:appearance_source) || plan.config.key?('appearance_source'))
      end
      NxTest.assert_equal(nil, calls.last[2][:appearance_source], 'bezny vklad nema implicitny zdroj')
      NxTest.refute(params.frozen?, 'parametre volajuceho sa nezmrazia')
      NxMRB2.error { cb.build(NxMRB2::Model.new, params, appearance_source: owner) }
      NxTest.assert_equal(3, calls.length, 'cudzi source sa odmietne pred commitom')
    end
  end
end

NxTest.test('MR-B2 ABS vetvenie: rovnaka RGB preskoci iba plain/ plain, native a protected sa priradia') do
  NxMRB2.isolated do |s|
    NxMRB2.with_painter do |cb|
      # Mapovanie plochy je stub: tento test neriesi fyzicku orientaciu ABS.
      face = NxMRB2::Face.new
      sheet = s[:model].materials.add('S18')
      draw = ->(mat, previous = {}) do
        cb.paint_edge_faces(s[:model], [face], { box: [1, 1, 1], role: 'side' },
                            { 'L1' => 'E23' }, 'S18', sheet_material: mat, previous_edges: previous)
      end
      draw.call(sheet)
      NxTest.assert_equal(nil, face.material, 'doterajsia rovnaka plain RGB ostava dedicna')
      native = NxMRB2.native(s[:model])
      s[:edges]['E23']['appearance'] = NxMRB2.descriptor
      draw.call(sheet)
      NxTest.assert_equal(native, face.material, 'native ABS nevynecha zhoda RGB')
      NxTest.assert_equal(native, face.back_material)
      s[:edges]['E23'].delete('appearance')
      prev = NxMRB2.previous(s[:model], native, kind: :edge, id: 'E23')
      face.material = face.back_material = nil
      draw.call(sheet, 'L1' => prev)
      NxTest.assert_equal(native, face.material, 'protected previous ma prednost pred RGB skratkou')
      draw.call(native)
      NxTest.assert_equal(:plain, NxMRB2.b.classify(face.material), 'plain ABS nesmie zdedit native sheet')
      NxTest.refute(face.material.equal?(native))
      NxMRB2.error { draw.call(sheet, 'L1' => prev.merge(state: :unknown)) }
    end
  end
end

NxTest.test('MR-B2 board edge seam: prenasa rolu, sheet handle a ABS previous; appearance chybu neprehltne') do
  NxMRB2.isolated do |s|
    material = NxMRB2.native(s[:model])
    entities = Object.new
    definition = Struct.new(:entities).new(entities)
    board = Struct.new(:definition, :material).new(definition, material)
    cfg = { role: 'free_panel', length: 600.0, width: 450.0, thickness: 18.0,
            material_id: 'S18', edges: { 'L1' => 'E23' } }
    previous = { 'L1' => NxMRB2.previous(s[:model], material, kind: :edge, id: 'E23') }
    calls = []
    cb = NxMRB2::E::CabinetBuilder
    bb = NxMRB2::E::BoardBuilder
    NxMRB2Copy.stub(cb, :paint_edge_faces, ->(*args, **options) { calls << [args, options] }) do
      bb.send(:paint_edges, s[:model], board, cfg, previous_edges: previous)
    end
    NxTest.assert_equal(1, calls.length)
    args, options = calls.first
    NxTest.assert_equal([s[:model], entities], args.first(2))
    NxTest.assert_equal('free_panel', args[2][:role])
    NxTest.assert_equal(cfg[:edges], args[3])
    NxTest.assert_equal(material, options[:sheet_material])
    NxTest.assert_equal(previous, options[:previous_edges])
    NxMRB2Copy.stub(cb, :paint_edge_faces, ->(*) { raise NxMRB2::N::IdentityError, 'test identity conflict' }) do
      NxMRB2.error(NxMRB2::N::IdentityError) { bb.send(:paint_edges, s[:model], board, cfg, previous_edges: previous) }
    end
  end
end
