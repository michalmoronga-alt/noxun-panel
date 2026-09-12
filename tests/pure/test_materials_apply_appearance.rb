# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)

# Riadenie Apply a domenove rozhodnutia nad realnymi Ruby seamami.
# Tato sada nepredstiera nativny clone, fyzicke UV ani skutocne Undo.
module NxApplyAppearance
  E = Noxun::Engine
  SCOPE = ['GRP-MR3B', 'SM'].freeze
  OTHER = ['GRP-MR3B-OTHER', 'SM'].freeze
  REVISION = '719bd2d0-240a-4e89-93bf-081745497301'
  Dict = Struct.new(:name, :data) { def to_h = data.dup }
  Point = Struct.new(:x, :y, :z)
  Bounds = Struct.new(:min, :max)
  Transform = Struct.new(:values) { def to_a = values.dup }
  Texture = Struct.new(:width, :height)
  Layer = Struct.new(:name, :visible, :folder) { def visible? = visible }
  Behavior = Struct.new(:unused) do
    def always_face_camera? = false
    def cuts_opening? = false
    def is2d? = false
    def no_scale_mask? = 0
    def snapto = 0
    def shadows_face_sun? = false
  end

  class Record < NxTest::FakeEntity
    attr_accessor :alive
    def initialize
      super()
      @alive = true
    end
    def valid? = alive
    def get_attribute(dict, key, default = nil) = dicts.fetch(dict, {}).fetch(key, default)
    def attribute_dictionaries = dicts.map { |name, values| Dict.new(name, values) }
    def inspect = "#<#{self.class.name}:#{object_id}>"
  end

  class Material < Record
    attr_accessor :model, :name, :texture, :alpha
    def initialize(model)
      super()
      @model, @name, @alpha = model, 'Rovnaka farba a nazov', 1.0
      model.materials << self
    end
    # Len kolekcia a jednoduche fake properties; geometriu/Undo tento model nema.
    def test_snapshot = [name.dup, texture&.dup, alpha, JSON.parse(JSON.generate(dicts))]
    def test_restore(state)
      @name, @texture, @alpha, @dicts = state
      @alive = true
    end
  end

  class Model < Record
    attr_accessor :active_path, :on_start, :on_abort, :start_result, :commit_result
    attr_reader :materials, :entities, :starts, :commits, :aborts, :test_layer
    def initialize
      super()
      @materials, @entities, @starts = [], [], []
      @commits = @aborts = 0
      @start_result = true
      @commit_result = true
      @operation_open = false
      @test_layer = Layer.new('Untagged', true, nil)
    end
    def start_operation(*args)
      @starts << args
      @material_snapshot = materials.to_h { |material| [material, material.test_snapshot] }
      @operation_open = true if start_result
      on_start.call if on_start
      start_result
    end
    def operation_open? = @operation_open
    def commit_operation
      @commits += 1
      @operation_open = false if commit_result
      commit_result
    end
    def abort_operation
      @aborts += 1
      on_abort.call if on_abort
      (materials - @material_snapshot.keys).each { |material| material.alive = false }
      materials.replace(@material_snapshot.keys)
      @material_snapshot.each { |material, state| material.test_restore(state) }
      @operation_open = false
      true
    end
  end

  class Definition < Record
    attr_reader :entities, :instances
    attr_accessor :bounds
    def initialize
      super()
      @entities, @instances = [], []
      @bounds = Bounds.new(Point.new(0, 0, 0), Point.new(300.0 / 25.4, 180.0 / 25.4, 18.0 / 25.4))
    end
    def group? = false
    def image? = false
    def behavior = Behavior.new
  end

  class Instance < Record
    attr_accessor :model, :parent, :definition, :material, :transformation, :name, :locked, :hidden, :layer
    def initialize(model, definition = Definition.new)
      super()
      @model = @parent = model
      @definition = definition
      definition.instances << self
      @transformation = NxApplyAppearance.transform
      @locked = @hidden = false
      @name = 'MR3B fixture'
      @layer = model.test_layer
    end
    def locked? = locked
    def hidden? = hidden
    def casts_shadows? = true
    def receives_shadows? = true
  end

  class Group < Instance; end
  class Edge < Record; end
  class Face
    attr_accessor :material, :back_material
    def to_a = [material, back_material]
  end

  module_function

  def app = E::ApplyAppearance
  def transform(x = 1.0, y = 1.0, z = 1.0)
    Transform.new([x, 0.0, 0.0, 0.0, 0.0, y, 0.0, 0.0, 0.0, 0.0, z, 0.0, 0.0, 0.0, 0.0, 1.0])
  end

  def stub(mod, name, implementation)
    original = mod.method(name)
    private_method = mod.private_methods.include?(name)
    mod.define_singleton_method(name, implementation)
    yield
  ensure
    mod.define_singleton_method(name, original) if original
    mod.singleton_class.send(:private, name) if private_method
  end

  def stubs(list, &block)
    return block.call if list.empty?
    mod, name, replacement = list.first
    stub(mod, name, replacement) { stubs(list.drop(1), &block) }
  end

  def constants(mod, values)
    before = values.to_h { |name, _value| [name, mod.const_defined?(name, false) ? mod.const_get(name, false) : nil] }
    values.each do |name, value|
      mod.send(:remove_const, name) if mod.const_defined?(name, false)
      mod.const_set(name, value)
    end
    yield
  ensure
    values.each_key do |name|
      mod.send(:remove_const, name) if mod.const_defined?(name, false)
      mod.const_set(name, before[name]) if before[name]
    end
  end

  def row(id, scope = SCOPE, kind = 'sheet')
    { (kind == 'sheet' ? 'material_id' : 'abs_id') => id, 'group_id' => scope[0],
      'structure' => scope[1], 'color' => [110, 120, 130], 'thickness' => 18.0 }
  end

  def native(model, scope = SCOPE, revision = REVISION)
    material = Material.new(model)
    material.set_attribute('NOXUN', 'appearance_scope', JSON.generate(scope))
    material.set_attribute('NOXUN', 'appearance_id', revision)
    material
  end

  def board(model, material_id = 'A18', edges = {})
    instance = Instance.new(model)
    E::Store.write(instance, kind: 'board', id: 'BRD-001', part_id: 'BRD-001',
      part_key: 'board/main', part_key_schema: E::PartKeys::SCHEMA, role: 'free_panel',
      manufactured: true, production_class: 'sheet', config: {
        config_schema: E::BoardBuilder::BOARD_CONFIG_SCHEMA, role: 'free_panel',
        length: 300.0, width: 180.0, thickness: 18.0, grain_direction: 'length',
        material_id: material_id, edges: %w[L1 L2 W1 W2].to_h { |slot| [slot, edges[slot]] },
        quantity: 1, orientation: 'leziaca'
      })
    model.entities << instance
    instance
  end

  def isolated
    NxTest.skip!('Apply doubles sa nesmu nacitat namiesto ziveho SketchUpu') unless NxTest.headless?
    model = Model.new
    state = { model: model, active: model, busy: false, flushes: 0, flush_result: true, reads: 0, locks: 0,
              catalog: { 'sheets' => [row('A18'), row('B18', OTHER)],
                         'edges' => [row('A23', SCOPE, 'edge'), row('B23', OTHER, 'edge')] } }
    state[:material] = Material.new(model)
    su = Module.new
    su.define_singleton_method(:active_model) { state[:active] }
    { ComponentInstance: Instance, Group: Group, Face: Face, Edge: Edge }.each { |name, value| su.const_set(name, value) }
    watch = Module.new
    watch.define_singleton_method(:rebuilding?) { state[:busy] }
    watch.define_singleton_method(:flush_pending!) do |actual|
      NxTest.assert_equal(model, actual)
      state[:flushes] += 1
      state[:on_flush]&.call
      state[:flush_result]
    end
    watch.define_singleton_method(:guard) do |&block|
      previous = state[:busy]
      begin
        state[:busy] = true
        block.call
      ensure
        state[:busy] = previous
      end
    end
    constants(app, Sketchup: su, ScaleWatch: watch) do
      stubs([
        [E::Materials, :with_catalog_lock, ->(&block) { state[:locks] += 1; block.call }],
        [E::Materials, :appearance_fresh_catalog!, ->(**) { state[:reads] += 1; state[:catalog] }]
      ]) { yield state }
    end
  end

  def apply(s, scope: SCOPE, material: s[:material])
    app.apply(s[:model], scope: scope, material: material)
  end

  def error
    caught = NxTest.assert_raise { yield }
    NxTest.assert(caught.is_a?(E::Materials::AppearanceError), "Prisla #{caught.class}: #{caught.message}")
    caught
  end

  def skipped(reason)
    caught = NxTest.assert_raise { yield }
    NxTest.assert(caught.is_a?(app::SkipError), "Prisla #{caught.class}: #{caught.message}")
    NxTest.assert_equal(reason, caught.reason)
  end

  def change_config(instance, changes)
    E::Store.write_config(instance, E::Store.config(instance).merge(changes))
  end

  # Fyzicky inspect/UV patri MR3A. Tu je jeho uz overeny maly navratovy kontrakt.
  def with_parts(s)
    maps = {}
    inspected = lambda do |instance, descriptor:|
      NxTest.assert_equal([300.0, 180.0, 18.0], descriptor[:box])
      maps[instance] ||= begin
        faces = Array.new(6) { Face.new }
        { sheet: { min: faces[4], max: faces[5] },
          edges: { 'L1' => faces[2], 'L2' => faces[3], 'W1' => faces[0], 'W2' => faces[1] } }
      end
      { status: :ok, map: maps.fetch(instance) }
    end
    captured = lambda do |instance, **_options|
      faces = maps[instance] && (maps[instance][:sheet].values + maps[instance][:edges].values)
      [NxApplyAppearance.app.send(:attributes, instance), instance.material, faces&.map(&:to_a)]
    end
    stubs([[E::AppearanceMapping, :inspect_part, inspected], [app, :content, captured]]) { yield maps }
  end

  def plan(s, instance, path: [instance], owner: instance)
    app.send(:plan_part, instance, path: path, owner: owner,
      membership: app.send(:membership, s[:catalog]), scope: SCOPE, material: s[:material])
  end

  # Skutocny Ruby non-local odchod; RuntimeError by ensure kontrakt neoveril.
  def leave_preparation(s, kind, &prepare)
    case kind
    when :break
      app.apply(s[:model], scope: SCOPE) { prepare.call; break :left }
    when :return
      app.apply(s[:model], scope: SCOPE) { prepare.call; return :left }
    when :throw
      catch(:preparation_exit) do
        app.apply(s[:model], scope: SCOPE) { prepare.call; throw :preparation_exit, :left }
      end
    end
  end
end

NxTest.test('MR3B apply: otvoreny edit context a guard odmietne pred flush') do
  NxApplyAppearance.isolated do |s|
    frame = [Object.new]
    s[:model].active_path = frame
    NxApplyAppearance.error { NxApplyAppearance.apply(s) }
    NxTest.assert_equal(frame, s[:model].active_path)
    s[:model].active_path = nil
    s[:busy] = true
    NxApplyAppearance.error { NxApplyAppearance.apply(s) }
    NxTest.assert_equal(0, s[:flushes])
    NxTest.assert_equal([], s[:model].starts)
    NxTest.assert_equal(0, s[:reads])
  end
end

NxTest.test('MR3B apply: nativny duplicitny tuple je chyba pred flush, bez opravy zdrojov') do
  NxApplyAppearance.isolated do |s|
    a = NxApplyAppearance.native(s[:model])
    b = NxApplyAppearance.native(s[:model])
    before = [a, b].map { |mat| [mat.name, JSON.generate(mat.dicts)] }
    NxApplyAppearance.error { NxApplyAppearance.apply(s, material: a) }
    NxTest.assert_equal(before, [a, b].map { |mat| [mat.name, JSON.generate(mat.dicts)] })
    NxTest.assert_equal(0, s[:flushes])
    NxTest.assert_equal([], s[:model].starts)
  end
end

NxTest.test('MR3B apply: cudzia native identita a material mimo kolekcie sa nesmu pouzit') do
  NxApplyAppearance.isolated do |s|
    wrong_scope = NxApplyAppearance.native(s[:model], NxApplyAppearance::OTHER)
    foreign = NxApplyAppearance::Material.new(NxApplyAppearance::Model.new)
    removed = NxApplyAppearance::Material.new(s[:model])
    s[:model].materials.delete(removed)
    dead = NxApplyAppearance::Material.new(s[:model])
    dead.alive = false
    [wrong_scope, foreign, removed, dead].each do |material|
      NxApplyAppearance.error { NxApplyAppearance.apply(s, material: material) }
    end
    NxTest.assert_equal(0, s[:flushes])
    NxTest.assert_equal([], s[:model].starts)
  end
end

NxTest.test('MR3B apply: textura ci alpha bez native identity nie je plain farebny vstup') do
  NxApplyAppearance.isolated do |s|
    texture = NxApplyAppearance::Material.new(s[:model])
    texture.texture = NxApplyAppearance::Texture.new(4.0, 2.0)
    alpha = NxApplyAppearance::Material.new(s[:model])
    alpha.alpha = 0.5
    [texture, alpha].each do |material|
      NxApplyAppearance.error { NxApplyAppearance.apply(s, material: material) }
    end
    NxTest.assert_equal(0, s[:flushes])
    NxTest.assert_equal([], s[:model].starts)
  end
end

NxTest.test('MR3B apply: neaktivny model alebo nenormalizovany scope nic neflushne') do
  NxApplyAppearance.isolated do |s|
    s[:active] = NxApplyAppearance::Model.new
    NxApplyAppearance.error { NxApplyAppearance.apply(s) }
    s[:active] = s[:model]
    [nil, [], ['GRP-MR3B'], ['grp-mr3b', ' sm '], ['', 'SM']].each do |scope|
      NxApplyAppearance.error { NxApplyAppearance.apply(s, scope: scope) }
    end
    NxTest.assert_equal(0, s[:flushes])
    NxTest.assert_equal([], s[:model].starts)
  end
end

NxTest.test('MR3B apply: plain bez textury je platny vstup, prazdna scena nema Undo krok') do
  NxApplyAppearance.isolated do |s|
    result = NxApplyAppearance.apply(s)
    NxTest.assert_equal(:nothing_to_apply, result[:status])
    NxTest.assert_equal([0, 0, 0], result.values_at(:updated_parts, :updated_sheets, :updated_edges))
    NxTest.assert_equal(1, s[:flushes])
    NxTest.assert_equal([1, 1], [s[:locks], s[:reads]])
    NxTest.assert_equal([], s[:model].starts)
  end
end

NxTest.test('MR3B apply: chybu flush neobide a potom znovu overi model, context aj handle') do
  changes = [->(s) { s[:flush_result] = false }, ->(s) { s[:active] = NxApplyAppearance::Model.new },
             ->(s) { s[:model].active_path = [Object.new] }, ->(s) { s[:busy] = true },
             ->(s) { s[:model].materials.delete(s[:material]) }]
  changes.each do |change|
    NxApplyAppearance.isolated do |s|
      s[:on_flush] = -> { change.call(s) }
      NxApplyAppearance.error { NxApplyAppearance.apply(s) }
      NxTest.assert_equal(1, s[:flushes])
      NxTest.assert_equal([], s[:model].starts)
      NxTest.assert_equal(0, s[:reads])
    end
  end
end

NxTest.test('MR3B apply: duplicita native tuple vzniknuta pocas flush sa znova odmietne') do
  NxApplyAppearance.isolated do |s|
    s[:material] = NxApplyAppearance.native(s[:model])
    s[:on_flush] = -> { NxApplyAppearance.native(s[:model]) }
    NxApplyAppearance.error { NxApplyAppearance.apply(s) }
    NxTest.assert_equal(1, s[:flushes])
    NxTest.assert_equal([], s[:model].starts)
    NxTest.assert_equal(0, s[:reads])
  end
end

NxTest.test('MR3B membership: druh a vyrobne ID urcuju scope, zhodna RGB ani meno nie') do
  NxApplyAppearance.isolated do |s|
    s[:catalog]['sheets'] << NxApplyAppearance.row('A36')
    s[:catalog]['sheets'] << NxApplyAppearance.row('A-ST9', [NxApplyAppearance::SCOPE[0], ' st9 '])
    s[:catalog]['sheets'] << NxApplyAppearance.row('UNI').merge('uni' => true)
    s[:catalog]['edges'] << NxApplyAppearance.row('A18', NxApplyAppearance::OTHER, 'edge')
    member = NxApplyAppearance.app.send(:membership, s[:catalog])
    NxTest.assert_equal(NxApplyAppearance::SCOPE, member[['sheet', 'A18']])
    NxTest.assert_equal(NxApplyAppearance::SCOPE, member[['sheet', 'A36']])
    NxTest.assert_equal(NxApplyAppearance::SCOPE, member[['edge', 'A23']])
    NxTest.assert_equal(NxApplyAppearance::OTHER, member[['sheet', 'B18']])
    NxTest.assert_equal(NxApplyAppearance::OTHER, member[['edge', 'A18']])
    NxTest.assert_equal([NxApplyAppearance::SCOPE[0], 'ST9'], member[['sheet', 'A-ST9']])
    NxTest.assert_equal(nil, member[['sheet', 'UNI']])
    NxTest.assert_equal(nil, member[['sheet', 'Rovnaka farba a nazov']])
  end
end

NxTest.test('MR3B plan: sheet A a ABS B so zhodnou RGB pripne presny povodny efektivny handle') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model], 'A18', 'L1' => 'A23', 'L2' => 'B23')
    old = board.material = NxApplyAppearance::Material.new(s[:model])
    before = JSON.generate(board.dicts)
    NxApplyAppearance.with_parts(s) do |maps|
      plan = NxApplyAppearance.plan(s, board)
      NxTest.assert_equal(true, plan[:sheet])
      NxTest.assert_equal(['L1'], plan[:edges])
      l2 = maps[board][:edges]['L2']
      NxTest.assert_equal([[l2, true, old], [l2, false, old]], plan[:pins])
      NxTest.assert_equal([nil, nil], l2.to_a, 'Plan este nic nepripina')
      NxTest.assert_equal(old, board.material)
      NxTest.assert_equal(before, JSON.generate(board.dicts))
    end
  end
end

NxTest.test('MR3B plan: edge-only nemenil parent ani nespojil odlisne front/back vzhlady') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model], 'B18', 'L1' => 'A23', 'L2' => 'B23')
    old = board.material = NxApplyAppearance::Material.new(s[:model])
    NxApplyAppearance.with_parts(s) do |maps|
      NxApplyAppearance.plan(s, board)
      face = maps[board][:sheet][:min]
      front = face.material = NxApplyAppearance.native(s[:model])
      back = face.back_material = NxApplyAppearance::Material.new(s[:model])
      plan = NxApplyAppearance.plan(s, board)
      NxTest.assert_equal(false, plan[:sheet])
      NxTest.assert_equal(['L1'], plan[:edges])
      NxTest.assert_equal([], plan[:pins])
      NxTest.assert_equal([front, back], face.to_a)
      NxTest.assert_equal(old, board.material)
    end
  end
end

NxTest.test('MR3B plan: explicitne necielene strany a ABS mimo katalogu sa nestratia') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model], 'A18', 'L2' => 'CHYBAJUCA-B')
    old = board.material = NxApplyAppearance::Material.new(s[:model])
    NxApplyAppearance.with_parts(s) do |maps|
      initial = NxApplyAppearance.plan(s, board)
      NxTest.assert_equal(2, initial[:pins].length, 'Neznamy ABS zaznam stale chrani svoj povodny vizual')
      face = maps[board][:edges]['L2']
      front = face.material = NxApplyAppearance.native(s[:model])
      face.back_material = old
      plan = NxApplyAppearance.plan(s, board)
      NxTest.assert_equal([], plan[:pins])
      NxTest.assert_equal([front, old], face.to_a)
    end
  end
end

NxTest.test('MR3B plan: nil alebo texturovane dedenie necielenej ABS preskoci cely diel') do
  [nil, :texture].each do |appearance|
    NxApplyAppearance.isolated do |s|
      board = NxApplyAppearance.board(s[:model], 'A18', 'L2' => 'B23')
      if appearance
        board.material = NxApplyAppearance.native(s[:model])
        board.material.texture = NxApplyAppearance::Texture.new(4.0, 2.0)
      end
      before = [JSON.generate(board.dicts), board.material]
      NxApplyAppearance.with_parts(s) do |maps|
        NxApplyAppearance.skipped(:unpreservable_inheritance) { NxApplyAppearance.plan(s, board) }
        NxTest.assert_equal(before, [JSON.generate(board.dicts), board.material])
        NxTest.assert((maps[board][:sheet].values + maps[board][:edges].values).all? { |face| face.to_a == [nil, nil] })
      end
    end
  end
end

NxTest.test('MR3B plan: protected raw R1 blokuje zmenu na iny handle, ten isty R1 nie') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model])
    old = board.material = NxApplyAppearance.native(s[:model])
    NxApplyAppearance.with_parts(s) do |maps|
      NxApplyAppearance.plan(s, board)
      raw = maps[board][:edges]['W1']
      raw.material = old
      NxApplyAppearance.skipped(:unpreservable_raw_appearance) { NxApplyAppearance.plan(s, board) }
      s[:material] = old
      plan = NxApplyAppearance.plan(s, board)
      NxTest.assert(plan[:sheet])
      NxTest.assert_equal([], plan[:edges])
      NxTest.assert_equal(old, raw.material)
    end
  end
end

NxTest.test('MR3B plan: platny snapshot musi mat rozmery, vsetky sloty a znamy grain') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model])
    raw = NxApplyAppearance::E::Store.get(board, 'config')
    changes = [{ 'length' => 0 }, { 'width' => -1 }, { 'thickness' => '18' },
               { 'grain_direction' => 'auto' }, { 'edges' => {} }, { 'material_id' => '' }]
    changes.each do |change|
      NxApplyAppearance::E::Store.write_config(board, raw)
      NxApplyAppearance.change_config(board, change)
      NxApplyAppearance.skipped(:invalid_snapshot) { NxApplyAppearance.plan(s, board) }
    end
    NxApplyAppearance::E::Store.write_config(board, '{"length":NaN}')
    NxApplyAppearance.skipped(:invalid_snapshot) { NxApplyAppearance.plan(s, board) }
  end
end

NxTest.test('MR3B plan: novsi schema marker a rozpor identity sa neopravuju normalizaciou') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model])
    NxApplyAppearance.change_config(board, 'config_schema' => NxApplyAppearance::E::BoardBuilder::BOARD_CONFIG_SCHEMA + 1)
    before = JSON.generate(board.dicts)
    NxApplyAppearance.skipped(:newer_config) { NxApplyAppearance.plan(s, board) }
    NxTest.assert_equal(before, JSON.generate(board.dicts))
    NxApplyAppearance.change_config(board, 'config_schema' => NxApplyAppearance::E::BoardBuilder::BOARD_CONFIG_SCHEMA)
    NxApplyAppearance::E::Store.write(board, part_id: 'INE-ID')
    NxApplyAppearance.skipped(:invalid_identity) { NxApplyAppearance.plan(s, board) }
    NxApplyAppearance::E::Store.write(board, part_id: 'BRD-001')
    NxApplyAppearance.change_config(board, 'role' => 'side')
    NxApplyAppearance.skipped(:invalid_identity) { NxApplyAppearance.plan(s, board) }
  end
end

NxTest.test('MR3B plan: chybajuce sheet ID sa nehada a iny scope nie je ciel') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model], 'NEEXISTUJE')
    NxApplyAppearance.skipped(:missing_material) { NxApplyAppearance.plan(s, board) }
    NxApplyAppearance.change_config(board, 'material_id' => 'B18')
    NxTest.assert_equal(nil, NxApplyAppearance.plan(s, board))
  end
end

NxTest.test('MR3B path: mirror a hidden su povolene, scale sa nesmie vykracat cez predka') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model])
    parent = NxApplyAppearance::Instance.new(s[:model])
    s[:model].entities.replace([parent])
    parent.definition.entities << board
    board.parent = parent.definition
    parent.hidden = true
    parent.transformation = NxApplyAppearance.transform(-1, 1, 1)
    NxApplyAppearance.with_parts(s) do
      NxTest.assert(NxApplyAppearance.plan(s, board, path: [parent, board]))
      parent.transformation = NxApplyAppearance.transform(2, 1, 1)
      board.transformation = NxApplyAppearance.transform(0.5, 1, 1)
      NxApplyAppearance.skipped(:nonrigid_transform) { NxApplyAppearance.plan(s, board, path: [parent, board]) }
      parent.transformation = board.transformation = NxApplyAppearance.transform
      parent.locked = true
      NxApplyAppearance.skipped(:locked) { NxApplyAppearance.plan(s, board, path: [parent, board]) }
      parent.locked = false
      parent.definition.entities.clear
      NxApplyAppearance.skipped(:stale_path) { NxApplyAppearance.plan(s, board, path: [parent, board]) }
    end
  end
end

NxTest.test('MR3B rigid: shear, projektivna matica a nekonecne hodnoty su odmietnute') do
  NxApplyAppearance.isolated do
    values = NxApplyAppearance.transform.values
    [values.dup.tap { |m| m[4] = 0.2 }, values.dup.tap { |m| m[3] = 1.0 },
     values.dup.tap { |m| m[15] = 0 }, values.dup.tap { |m| m[12] = Float::NAN }].each do |matrix|
      NxTest.refute(NxApplyAppearance.app.send(:rigid?, matrix))
    end
    rotation = [0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 7.0, 11.0, 13.0, 1.0]
    NxTest.assert(NxApplyAppearance.app.send(:rigid?, rotation))
  end
end

NxTest.test('MR3B input: native texture musi mat konecnu kladnu fyzicku mierku') do
  [[0, 1], [1, -1], [Float::NAN, 1], [1, Float::INFINITY]].each do |dimensions|
    NxApplyAppearance.isolated do |s|
      mat = NxApplyAppearance.native(s[:model])
      mat.texture = NxApplyAppearance::Texture.new(*dimensions)
      NxApplyAppearance.error { NxApplyAppearance.apply(s, material: mat) }
      NxTest.assert_equal(0, s[:flushes])
      NxTest.assert_equal([], s[:model].starts)
    end
  end
end

NxTest.test('MR3B content: poradie deti nie je identita, pocet a surovy obsah ano') do
  NxApplyAppearance.isolated do |s|
    root = NxApplyAppearance::Instance.new(s[:model])
    children = Array.new(2) { NxApplyAppearance::Instance.new(s[:model]) }
    children.each do |child|
      child.parent = root.definition
      root.definition.entities << child
      child.set_attribute('foreign', 'payload', 'original'.dup)
    end
    before = NxApplyAppearance.app.send(:content, root)
    root.definition.entities.reverse!
    NxTest.assert_equal(before, NxApplyAppearance.app.send(:content, root))
    root.definition.entities.pop
    NxTest.refute(before == NxApplyAppearance.app.send(:content, root), 'Dve rovnake deti sa nesmu zliat na jednu')
    root.definition.entities.replace(children)
    children.first.dicts['foreign']['payload'].replace('changed')
    NxTest.refute(before == NxApplyAppearance.app.send(:content, root), 'Cudzi atribut je sucast obsahu')
    children.first.set_attribute('foreign', 'payload', 'original')
    NxTest.assert_equal(before, NxApplyAppearance.app.send(:content, root), 'Povodny snapshot je hlboka hodnota')
    changes = [-> { children.first.locked = true }, -> { children.first.hidden = true },
               -> { children.first.transformation.values[12] = 4.0 }]
    changes.each do |change|
      change.call
      NxTest.refute(before == NxApplyAppearance.app.send(:content, root))
      children.first.locked = children.first.hidden = false
      children.first.transformation = NxApplyAppearance.transform
    end
  end
end

NxTest.test('MR3B content: neznamy obsah sa smie len chranit mimo clone vetvy') do
  NxApplyAppearance.isolated do |s|
    root = NxApplyAppearance::Instance.new(s[:model])
    unknown = NxApplyAppearance::Record.new
    unknown.define_singleton_method(:parent) { root.definition }
    root.definition.entities << unknown
    NxApplyAppearance.skipped(:unsupported_clone_content) { NxApplyAppearance.app.send(:content, root) }
    before = NxApplyAppearance.app.send(:content, root, strict: false)
    NxTest.assert_equal(before, NxApplyAppearance.app.send(:content, root, strict: false))
    root.definition.entities.replace([NxApplyAppearance::Record.new])
    NxTest.refute(before == NxApplyAppearance.app.send(:content, root, strict: false))
  end
end

NxTest.test('MR3B scan: pokazeny sused sa prizna, proxy je bariera a iny scope sa vynecha') do
  NxApplyAppearance.isolated do |s|
    good = NxApplyAppearance.board(s[:model])
    broken = NxApplyAppearance.board(s[:model])
    NxApplyAppearance::E::Store.write_config(broken, '{broken')
    other = NxApplyAppearance.board(s[:model], 'B18')
    other.locked = true
    proxy = NxApplyAppearance::Instance.new(s[:model])
    NxApplyAppearance::E::Store.write(proxy, kind: 'proxy')
    nested = NxApplyAppearance.board(s[:model])
    nested.parent = proxy.definition
    proxy.definition.entities << nested
    s[:model].entities.delete(nested)
    s[:model].entities << proxy
    NxApplyAppearance.with_parts(s) do
      members = NxApplyAppearance.app.send(:membership, s[:catalog])
      result = NxApplyAppearance.app.send(:scan, s[:model], members, NxApplyAppearance::SCOPE, s[:material])
      NxTest.assert_equal([good], result[:parts].map { |part| part[:instance] })
      NxTest.assert_equal([:invalid_snapshot], result[:skips].map { |skip| skip[:reason] })
      NxTest.assert_equal('BRD-001', result[:skips].first[:owner_id])
    end
  end
end

NxTest.test('MR3B apply: sheet a edge-only sused dostanu iba cielove kanaly v jednej operacii') do
  NxApplyAppearance.isolated do |s|
    sheet = NxApplyAppearance.board(s[:model], 'A18', 'L1' => 'A23', 'L2' => 'B23')
    edge_only = NxApplyAppearance.board(s[:model], 'B18', 'W2' => 'A23')
    NxApplyAppearance::E::Store.write(edge_only, id: 'BRD-002', part_id: 'BRD-002')
    old_sheet = sheet.material = NxApplyAppearance::Material.new(s[:model])
    old_other = edge_only.material = NxApplyAppearance::Material.new(s[:model])
    raw = [sheet, edge_only].map { |part| JSON.generate(part.dicts) }
    calls = []
    NxApplyAppearance.with_parts(s) do |maps|
      painter = lambda do |part, map, grain:, bindings:|
        calls << part
        NxTest.assert_equal('length', grain)
        NxTest.assert_equal(maps.fetch(part), map)
        if part == sheet
          NxTest.assert_equal(s[:material], bindings[:sheet])
          NxTest.assert_equal(['L1'], bindings[:edges].keys)
          NxTest.assert_equal([old_sheet, old_sheet], map[:edges]['L2'].to_a)
          NxTest.assert_equal(s[:material], part.material)
        else
          NxTest.refute(bindings.key?(:sheet))
          NxTest.assert_equal(['W2'], bindings[:edges].keys)
          NxTest.assert_equal(old_other, part.material)
          NxTest.assert_equal([nil, nil], map[:sheet][:min].to_a)
        end
        bindings[:edges].each_value do |binding|
          NxTest.assert_equal({ material: s[:material], inherit: false }, binding)
        end
        true
      end
      NxApplyAppearance.stub(NxApplyAppearance::E::AppearanceMapping, :paint_part!, painter) do
        result = NxApplyAppearance.apply(s)
        NxTest.assert_equal({ status: :applied, updated_parts: 2, updated_sheets: 1, updated_edges: 2,
                              skipped_parts: 0, skips: [] }, result)
      end
    end
    NxTest.assert_equal([sheet, edge_only], calls)
    NxTest.assert_equal(raw, [sheet, edge_only].map { |part| JSON.generate(part.dicts) })
    NxTest.assert_equal(1, s[:model].starts.length)
    NxTest.assert_equal(1, s[:model].commits)
    NxTest.assert_equal(0, s[:model].aborts)
    NxTest.assert_equal([1, 1, 1, false], [s[:flushes], s[:reads], s[:locks], s[:busy]])
  end
end

NxTest.test('MR3B apply: chyba druheho paint abortne cely batch bez commitu') do
  NxApplyAppearance.isolated do |s|
    boards = Array.new(2) { NxApplyAppearance.board(s[:model]) }
    NxApplyAppearance::E::Store.write(boards.last, id: 'BRD-002', part_id: 'BRD-002')
    calls = []
    NxApplyAppearance.with_parts(s) do
      painter = lambda do |part, *_args, **_keywords|
        calls << part
        raise 'injected second face positioning failure' if calls.length == 2
        true
      end
      NxApplyAppearance.stub(NxApplyAppearance::E::AppearanceMapping, :paint_part!, painter) do
        error = NxApplyAppearance.error { NxApplyAppearance.apply(s) }
        NxTest.assert(error.message.include?('second face positioning failure'))
      end
    end
    NxTest.assert_equal(boards, calls)
    NxTest.assert_equal([1, 0, 1, false], [s[:model].starts.length, s[:model].commits, s[:model].aborts, s[:busy]])
  end
end

NxTest.test('MR3B apply: zmena snapshotu po preflight abortne pred prvym zapisom') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model])
    s[:model].on_start = -> { NxApplyAppearance.change_config(board, 'grain_direction' => 'width') }
    NxApplyAppearance.with_parts(s) do
      NxApplyAppearance.stub(NxApplyAppearance::E::AppearanceMapping, :paint_part!, ->(*) { raise 'paint must not run' }) do
        error = NxApplyAppearance.error { NxApplyAppearance.apply(s) }
        NxTest.refute(error.message.include?('paint must not run'))
      end
    end
    NxTest.assert_equal(nil, board.material)
    NxTest.assert_equal([1, 0, 1, false], [s[:model].starts.length, s[:model].commits, s[:model].aborts, s[:busy]])
  end
end

NxTest.test('MR3B apply: clone ktory meni obsah abortne pred prvym paint') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model])
    foreign = NxApplyAppearance::Instance.new(s[:model], board.definition)
    old_definition = foreign.definition
    clones = 0
    board.define_singleton_method(:make_unique) do
      clones += 1
      definition.instances.delete(self)
      self.definition = NxApplyAppearance::Definition.new
      definition.instances << self
      NxApplyAppearance.change_config(self, 'grain_direction' => 'width')
      self
    end
    NxApplyAppearance.with_parts(s) do
      NxApplyAppearance.stub(NxApplyAppearance::E::AppearanceMapping, :paint_part!, ->(*) { raise 'paint must not run' }) do
        error = NxApplyAppearance.error { NxApplyAppearance.apply(s) }
        NxTest.refute(error.message.include?('paint must not run'))
      end
    end
    NxTest.assert_equal(1, clones)
    NxTest.assert_equal(old_definition, foreign.definition)
    NxTest.assert_equal(nil, board.material)
    NxTest.assert_equal([1, 0, 1, false], [s[:model].starts.length, s[:model].commits, s[:model].aborts, s[:busy]])
  end
end

NxTest.test('MR3B face content: prepocitana rovina nemení plochu, vrchol a normala ano') do
  vertex_class = Struct.new(:position)
  loop_class = Struct.new(:vertices)
  face_class = Struct.new(:normal, :loops, :outer_loop, :plane)
  height = 18.0 / 25.4
  points = [[0.0, 0.0, height], [4.0, 0.0, height], [4.0, 3.0, height], [0.0, 3.0, height]]
  make_face = lambda do |coordinates, normal, plane|
    outer = loop_class.new(coordinates.map { |p| vertex_class.new(NxApplyAppearance::Point.new(*p)) })
    face_class.new(NxApplyAppearance::Point.new(*normal), [outer], outer, plane)
  end
  original = make_face.call(points, [0, 0, 1], [0, 0, 1, -height])
  # Native make_unique moze prepocitat D o 1 ULP pri presne zhodnych vrcholoch.
  clone = make_face.call(points.rotate(2), [0, 0, 1], [0, 0, 1, (-height).next_float])
  before = NxApplyAppearance.app.send(:face_geometry, original)
  NxTest.refute(original.plane == clone.plane, 'Fixture musi mat odlisne rovnicove koeficienty')
  NxTest.assert_equal(before, NxApplyAppearance.app.send(:face_geometry, clone))
  changed_points = points.map(&:dup)
  changed_points.first[0] = 0.125
  moved = make_face.call(changed_points, [0, 0, 1], original.plane)
  reversed = make_face.call(points, [0, 0, -1], original.plane)
  NxTest.refute(before == NxApplyAppearance.app.send(:face_geometry, moved), 'Zmena vrcholu zostava obsahova zmena')
  NxTest.refute(before == NxApplyAppearance.app.send(:face_geometry, reversed), 'Zmena orientacie zostava obsahova zmena')
end

NxTest.test('MR2A prepare: nulovy pocet dielcov commitne plain aj native handle v jednej operacii') do
  %i[plain native].each do |kind|
    NxApplyAppearance.isolated do |s|
      old = s[:material].test_snapshot
      calls = 0
      prepared = nil
      result = NxApplyAppearance.app.apply(s[:model], scope: NxApplyAppearance::SCOPE) do
        calls += 1
        NxTest.assert(s[:busy] && s[:model].operation_open?)
        NxTest.assert_equal([['Použiť vzhľad', false]], s[:model].starts)
        NxTest.assert_equal([1, 1, 1], [s[:flushes], s[:reads], s[:locks]])
        prepared = kind == :plain ? NxApplyAppearance::Material.new(s[:model]) : NxApplyAppearance.native(s[:model])
      end
      NxTest.assert_equal({ status: :nothing_to_apply, updated_parts: 0, updated_sheets: 0, updated_edges: 0,
                            skipped_parts: 0, skips: [], material: prepared }, result)
      NxTest.assert_equal([s[:material], prepared], s[:model].materials)
      NxTest.assert_equal(old, s[:material].test_snapshot)
      NxTest.assert_equal([1, 1, 0, false, false], [calls, s[:model].commits, s[:model].aborts, s[:busy], s[:model].operation_open?])
    end
  end
end

NxTest.test('MR2A prepare: material plus blok a chybejuci vstup sa odmietnu pred operaciou') do
  NxApplyAppearance.isolated do |s|
    calls = 0
    NxApplyAppearance.error do
      NxApplyAppearance.app.apply(s[:model], scope: NxApplyAppearance::SCOPE, material: s[:material]) { calls += 1 }
    end
    NxApplyAppearance.error { NxApplyAppearance.app.apply(s[:model], scope: NxApplyAppearance::SCOPE) }
    NxTest.assert_equal([0, 0, 0], [calls, s[:flushes], s[:model].starts.length])
  end
end

NxTest.test('MR2A prepare: odmietnuty model, context, flush a fresh scope nikdy nezavolaju blok') do
  %i[inactive edit busy flush inactive_after_flush edit_after_flush busy_after_flush
     inactive_after_start edit_after_start start_false absent uni catalog_error].each do |kind|
    NxApplyAppearance.isolated do |s|
      case kind
      when :inactive then s[:active] = NxApplyAppearance::Model.new
      when :edit then s[:model].active_path = [Object.new]
      when :busy then s[:busy] = true
      when :flush then s[:flush_result] = false
      when :inactive_after_flush then s[:on_flush] = -> { s[:active] = NxApplyAppearance::Model.new }
      when :edit_after_flush then s[:on_flush] = -> { s[:model].active_path = [Object.new] }
      when :busy_after_flush then s[:on_flush] = -> { s[:busy] = true }
      when :inactive_after_start then s[:model].on_start = -> { s[:active] = NxApplyAppearance::Model.new }
      when :edit_after_start then s[:model].on_start = -> { s[:model].active_path = [Object.new] }
      when :start_false then s[:model].start_result = false
      when :absent then s[:catalog] = { 'sheets' => [], 'edges' => [] }
      when :uni
        s[:catalog] = { 'sheets' => [NxApplyAppearance.row('UNI-18').merge('uni' => true)], 'edges' => [] }
      end
      before = s[:model].materials.dup
      calls = 0
      attempt = -> { NxApplyAppearance.error { NxApplyAppearance.app.apply(s[:model], scope: NxApplyAppearance::SCOPE) { calls += 1 } } }
      if kind == :catalog_error
        NxApplyAppearance.stub(NxApplyAppearance::E::Materials, :appearance_fresh_catalog!, ->(**) { raise 'catalog rejected' }, &attempt)
      else
        attempt.call
      end
      started = %i[inactive_after_start edit_after_start start_false].include?(kind)
      NxTest.assert_equal([0, started ? 1 : 0], [calls, s[:model].starts.length], kind.to_s)
      NxTest.assert_equal(started && kind != :start_false ? 1 : 0, s[:model].aborts)
      NxTest.refute(s[:model].operation_open?)
      NxTest.assert_equal(before, s[:model].materials)
    end
  end
end

NxTest.test('MR2A prepare: neplatny vysledok, zmena modelu aj zly commit abortnu vytvoreny W') do
  %i[nil foreign removed wrong_scope duplicate inactive edit commit_false exception].each do |kind|
    NxApplyAppearance.isolated do |s|
      before = s[:model].materials.dup
      created = nil
      calls = 0
      NxApplyAppearance.error do
        NxApplyAppearance.app.apply(s[:model], scope: NxApplyAppearance::SCOPE) do
          calls += 1
          created = NxApplyAppearance.native(s[:model])
          case kind
          when :nil then nil
          when :foreign then NxApplyAppearance::Material.new(NxApplyAppearance::Model.new)
          when :removed then s[:model].materials.delete(created); created.alive = false; created
          when :wrong_scope
            created.set_attribute('NOXUN', 'appearance_scope', JSON.generate(NxApplyAppearance::OTHER))
            created
          when :duplicate then NxApplyAppearance.native(s[:model]); created
          when :inactive then s[:active] = NxApplyAppearance::Model.new; created
          when :edit then s[:model].active_path = [Object.new]; created
          when :commit_false then s[:model].commit_result = false; created
          when :exception then raise 'preparation failed after creating W'
          end
        end
      end
      NxTest.assert_equal(before, s[:model].materials)
      NxTest.refute(created.valid?)
      NxTest.assert_equal([1, 1, kind == :commit_false ? 1 : 0, 1, false, false],
        [calls, s[:model].starts.length, s[:model].commits, s[:model].aborts, s[:busy], s[:model].operation_open?])
    end
  end
end

NxTest.test('MR2A prepare: break return aj throw po zmene novej textury vzdy uzavru operaciu abortom') do
  %i[break return throw].product([0, 1]).each do |kind, target_count|
    NxApplyAppearance.isolated do |s|
      NxApplyAppearance.board(s[:model]) if target_count == 1
      s[:model].on_abort = -> { NxTest.assert(s[:busy], 'Aj abort musi prebehnut pod guardom') }
      before = s[:model].materials.dup
      s[:material].texture = NxApplyAppearance::Texture.new(13.0, 17.0)
      old = s[:material].test_snapshot
      created = nil
      calls = 0
      NxApplyAppearance.with_parts(s) do
        result = NxApplyAppearance.leave_preparation(s, kind) do
          calls += 1
          created = NxApplyAppearance.native(s[:model])
          created.texture = NxApplyAppearance::Texture.new(100.0, 50.0)
          created.texture.width = 25.0
          NxTest.assert(s[:busy] && s[:model].operation_open?)
          created
        end
        NxTest.assert_equal(:left, result)
      end
      NxTest.assert_equal(before, s[:model].materials)
      NxTest.assert_equal(old, s[:material].test_snapshot)
      NxTest.refute(created.valid?)
      NxTest.assert_equal([1, 1, 0, 1, false, false], [calls, s[:model].starts.length, s[:model].commits,
                                                   s[:model].aborts, s[:busy], s[:model].operation_open?])
    end
  end
end

NxTest.test('MR2A prepare: cerstvy plan a mapper dostanu pripraveny handle az po skonceni bloku') do
  NxApplyAppearance.isolated do |s|
    board = NxApplyAppearance.board(s[:model], 'A18', 'L1' => 'A23')
    calls = []
    created = nil
    NxApplyAppearance.with_parts(s) do
      painter = lambda do |part, _map, grain:, bindings:|
        calls << :paint
        NxTest.assert_equal([:prepare, :prepared, :paint], calls)
        NxTest.assert_equal(board, part)
        NxTest.assert_equal('length', grain)
        NxTest.assert_equal(created, bindings[:sheet])
        NxTest.assert_equal({ 'L1' => { material: created, inherit: false } }, bindings[:edges])
        true
      end
      NxApplyAppearance.stub(NxApplyAppearance::E::AppearanceMapping, :paint_part!, painter) do
        result = NxApplyAppearance.app.apply(s[:model], scope: NxApplyAppearance::SCOPE) do
          calls << :prepare
          created = NxApplyAppearance.native(s[:model])
          calls << :prepared
          created
        end
        NxTest.assert_equal([:applied, 1, 1, 1, created], result.values_at(:status, :updated_parts, :updated_sheets, :updated_edges, :material))
      end
    end
    NxTest.assert_equal([1, 1, 0], [s[:model].starts.length, s[:model].commits, s[:model].aborts])
  end
end

NxTest.test('MR2A prepare: chyba druheho mappera vrati aj kolekciu pripraveneho materialu') do
  NxApplyAppearance.isolated do |s|
    Array.new(2) { NxApplyAppearance.board(s[:model]) }
    before = s[:model].materials.dup
    old = s[:material].test_snapshot
    created = nil
    calls = 0
    NxApplyAppearance.with_parts(s) do
      painter = lambda do |*_args, **_keywords|
        calls += 1
        raise 'second mapper rejected' if calls == 2
        true
      end
      NxApplyAppearance.stub(NxApplyAppearance::E::AppearanceMapping, :paint_part!, painter) do
        error = NxApplyAppearance.error do
          NxApplyAppearance.app.apply(s[:model], scope: NxApplyAppearance::SCOPE) do
            created = NxApplyAppearance.native(s[:model])
            created.texture = NxApplyAppearance::Texture.new(25.0, 50.0)
            created
          end
        end
        NxTest.assert(error.message.include?('second mapper rejected'))
      end
    end
    NxTest.assert_equal(before, s[:model].materials)
    NxTest.assert_equal(old, s[:material].test_snapshot)
    NxTest.refute(created.valid?)
    NxTest.assert_equal([2, 1, 0, 1, false, false], [calls, s[:model].starts.length, s[:model].commits,
                                                 s[:model].aborts, s[:busy], s[:model].operation_open?])
  end
end
