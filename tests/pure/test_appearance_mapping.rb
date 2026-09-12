# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)

# Kontrakt geometrickeho preflightu a volani API na malom topologickom double.
# Skutocne UVQ, reverse, builder geometriu a Undo dokazuje samostatna SU sada.
# Doubles su lokalne len v mapperi; zivy SketchUp sa nikdy neprepisuje.
module NxAppearanceMapping
  E = Noxun::Engine
  Point = Struct.new(:x, :y, :z) do
    def initialize(*values)
      super(*(values.first.is_a?(Array) ? values.first : values))
    end
  end
  Vertex = Struct.new(:position)
  Loop = Struct.new(:vertices, :edges)
  Texture = Struct.new(:width, :height)
  NativeLength = Struct.new(:value) do
    def to_f = value.to_f
    def mm = raise('Nativna dlzka sa nesmie druhykrat previest z mm')
  end

  class Entity
    attr_accessor :alive, :parent
    def initialize = @alive = true
    def valid? = alive
    def inspect = "#<#{self.class.name}:#{object_id}>"
  end

  class Edge < Entity
    attr_reader :vertices, :faces
    def initialize(vertices)
      super()
      @vertices, @faces = vertices, []
    end
    def start = vertices.first
    def end = vertices.last
  end

  class Face < Entity
    attr_reader :vertices, :edges, :loops, :writes, :positions
    attr_accessor :fail_on_call
    def initialize(vertices, edges)
      super()
      @vertices, @edges = vertices, edges
      @loops = [Loop.new(vertices, edges)]
      @writes, @positions = [], []
      @material = @back_material = nil
    end
    def outer_loop = loops.first
    def material = @material
    def back_material = @back_material
    def material=(material)
      @writes << [:front, material]
      @material = material
    end
    def back_material=(material)
      @writes << [:back, material]
      @back_material = material
    end
    def position_material(material, points, front)
      @positions << [material, points, front]
      failure = fail_on_call && fail_on_call[@positions.length]
      raise 'injected second-side native error' if failure == :raise
      failure == :false ? false : true
    end
  end

  class Material < Entity
    attr_accessor :model, :texture
    def initialize(model, texture = nil)
      super()
      @model, @texture = model, texture
      model.materials << self
    end
    def alpha = 1.0
    def get_attribute(_dict, _key, default = nil) = default
  end

  class Model < Entity
    attr_reader :materials
    def initialize
      super()
      @materials = []
    end
    def start_operation(*) = raise('Mapper nevlastni operaciu')
  end

  class Definition < Entity
    attr_reader :entities
    def initialize(entities)
      super()
      @entities = entities
      entities.each { |entity| entity.parent = self }
    end
  end

  class Instance < Entity
    attr_accessor :definition, :model, :material
    def initialize(model, definition)
      super()
      @model, @definition = model, definition
      @material = :untouched_parent
    end
  end

  module_function

  def mapper = E::AppearanceMapping

  def descriptor(box = [300.0, 180.0, 18.0], axes = { length: 0, width: 1, thickness: 2 }, role = 'free_panel')
    { box: box, axes: axes, role: role,
      prod: { length: box[axes[:length]], width: box[axes[:width]], thickness: box[axes[:thickness]] } }
  end

  def fixture(pd = descriptor)
    x, y, z = pd[:box].map { |size| size / 25.4 }
    vertices = [[0, 0, 0], [x, 0, 0], [x, y, 0], [0, y, 0],
                [0, 0, z], [x, 0, z], [x, y, z], [0, y, z]].map { |p| Vertex.new(Point.new(*p)) }
    edge_table = {}
    # Pevne steny Xmin/Xmax/Ymin/Ymax/Zmin/Zmax. Oracle nepouziva PartFaces.
    faces = [[0, 3, 7, 4], [1, 2, 6, 5], [0, 1, 5, 4],
             [3, 2, 6, 7], [0, 1, 2, 3], [4, 5, 6, 7]].map do |indices|
      edges = indices.each_with_index.map do |a, i|
        key = [a, indices[(i + 1) % 4]].sort
        edge_table[key] ||= Edge.new(key.map { |index| vertices[index] })
      end
      face = Face.new(indices.map { |index| vertices[index] }, edges)
      edges.each { |edge| edge.faces << face }
      face
    end
    model = Model.new
    instance = Instance.new(model, Definition.new(faces + edge_table.values))
    { model: model, instance: instance, faces: faces, edges: edge_table.values, vertices: vertices, pd: pd }
  end

  def isolated(pd = descriptor)
    NxTest.skip!('Topologicke doubles patria iba do headless sady') unless NxTest.headless?
    su = Module.new
    { Face: Face, Edge: Edge, ComponentInstance: Instance, Group: Instance }.each { |name, klass| su.const_set(name, klass) }
    geom = Module.new
    geom.const_set(:Point3d, Point)
    replacements = { Sketchup: su, Geom: geom }
    replacements.each do |name, value|
      raise "Kolizia lokalneho double #{name}" if mapper.const_defined?(name, false)
      mapper.const_set(name, value)
    end
    s = fixture(pd)
    su.define_singleton_method(:active_model) { s[:model] }
    yield s
  ensure
    replacements&.each_key { |name| mapper.send(:remove_const, name) }
  end

  def inspect_map(s)
    result = mapper.inspect_part(s[:instance], descriptor: s[:pd])
    NxTest.assert_equal(:ok, result[:status], result[:reason].to_s)
    result[:map]
  end

  def native(s, width = 100.0 / 25.4, height = 50.0 / 25.4)
    Material.new(s[:model], Texture.new(NativeLength.new(width), NativeLength.new(height)))
  end

  def state(s)
    [s[:instance].material, s[:instance].definition, s[:instance].definition.entities.dup, s[:model].materials.dup,
     s[:vertices].map { |v| v.position.to_a.dup },
     s[:edges].map { |edge| [edge.valid?, edge.vertices.map(&:object_id), edge.faces.map(&:object_id)] },
     s[:faces].map do |f|
       [f.valid?, f.vertices.map(&:object_id), f.edges.map(&:object_id), f.loops.map(&:object_id),
        f.material, f.back_material, f.writes.dup, f.positions.dup]
     end]
  end

  def rejects_without_writes(s)
    before = state(s)
    error = NxTest.assert_raise { yield }
    NxTest.assert(error.is_a?(mapper::MappingError), "Ocakavana MappingError, prisla #{error.class}: #{error.message}")
    NxTest.assert_equal(before, state(s), 'Neplatny plan sa musi odmietnut pred prvym material/UV zapisom')
  end

  def point_close(expected, actual)
    expected.zip(actual.to_a).each { |want, got| NxTest.assert_close(want, got.to_f, 1.0e-9) }
  end

  def assert_frame(face, origin, u, v)
    NxTest.assert_equal([true, false], face.positions.map(&:last), 'Kazda strana ma vlastne volanie')
    face.positions.each do |_material, pairs, _front|
      NxTest.assert_equal(6, pairs.length)
      [origin, [0, 0, 0], u, [1, 0, 0], v, [0, 1, 0]].zip(pairs).each do |want, got|
        point_close(want, got)
      end
    end
  end
end

NxTest.test('MR3A inspect: platny kvader sa iba cita a zachyti presne steny') do
  NxAppearanceMapping.isolated do |s|
    before = NxAppearanceMapping.state(s)
    map = NxAppearanceMapping.inspect_map(s)
    NxTest.assert_equal(before, NxAppearanceMapping.state(s))
    NxTest.assert_equal({ min: s[:faces][4], max: s[:faces][5] }, map[:sheet])
    NxTest.assert_equal({ 'L1' => s[:faces][2], 'L2' => s[:faces][3],
                          'W1' => s[:faces][0], 'W2' => s[:faces][1] }, map[:edges])
  end
end

NxTest.test('MR3A inspect: neplatne rozmery a osi nemozu prejst cez NaN toleranciu') do
  NxAppearanceMapping.isolated do |s|
    bad = [0, -1, Float::INFINITY, Float::NAN, '300'].flat_map do |value|
      [s[:pd].merge(box: [value, 180.0, 18.0]),
       s[:pd].merge(prod: s[:pd][:prod].merge(length: value))]
    end
    bad << s[:pd].merge(axes: { length: 0, width: 0, thickness: 2 })
    bad << s[:pd].merge(prod: s[:pd][:prod].merge(length: 301.0))
    before = NxAppearanceMapping.state(s)
    bad.each do |pd|
      result = NxAppearanceMapping.mapper.inspect_part(s[:instance], descriptor: pd)
      NxTest.assert_equal(:unsupported, result[:status], "Neplatny descriptor: #{pd.inspect}")
    end
    NxTest.assert_equal(before, NxAppearanceMapping.state(s))
  end
end

{
  'diera v ploche' => ->(s) { s[:faces][0].loops << NxAppearanceMapping::Loop.new([], []) },
  'trojuholnik namiesto steny' => ->(s) { s[:faces][0].vertices.pop },
  'volna hrana' => ->(s) { s[:instance].definition.entities << NxAppearanceMapping::Edge.new(s[:vertices].first(2)) },
  'cudzia vnorena entita' => ->(s) { s[:instance].definition.entities << Object.new },
  'hrana bez susednej plochy' => ->(s) { s[:edges][0].faces.pop },
  'posunuty origin' => ->(s) { s[:vertices].each { |v| v.position.x += 1.0 } },
  'rozmer mimo tolerancie aj ked kazdy roh este lezi pri stene' => lambda do |s|
    s[:vertices].each { |v| v.position.x += (v.position.x.zero? ? 0.04 : -0.04) / 25.4 }
  end,
  'deformovany roh pri rovnakom bbox' => ->(s) { s[:vertices][0].position.x = 1.0 },
  'neplatna plocha' => ->(s) { s[:faces][0].alive = false }
}.each do |name, damage|
  NxTest.test("MR3A inspect: odmietne #{name} bez zmeny") do
    NxAppearanceMapping.isolated do |s|
      damage.call(s)
      before = NxAppearanceMapping.state(s)
      result = NxAppearanceMapping.mapper.inspect_part(s[:instance], descriptor: s[:pd])
      NxTest.assert_equal(:unsupported, result[:status])
      NxTest.assert_equal(before, NxAppearanceMapping.state(s))
    end
  end
end

NxTest.test('MR3A paint: stara mapa so zivymi handles po posune geometrie nic nezapise') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    s[:vertices].each { |v| v.position.x += 1.0 }
    NxTest.assert(s[:faces].all?(&:valid?))
    NxAppearanceMapping.rejects_without_writes(s) do
      NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: { sheet: material })
    end
  end
end

NxTest.test('MR3A paint: aj posun v tolerancii zneplatni mapu, hoci novy inspect kvader prijme') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    s[:vertices].each { |v| v.position.x += 0.01 / 25.4 }
    NxAppearanceMapping.inspect_map(s)
    NxAppearanceMapping.rejects_without_writes(s) do
      NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: { sheet: material })
    end
  end
end

NxTest.test('MR3A paint: zmena definicie alebo instancia zdielajucej definicie nevlastni mapu') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    other = NxAppearanceMapping::Instance.new(s[:model], s[:instance].definition)
    NxAppearanceMapping.rejects_without_writes(s) do
      NxAppearanceMapping.mapper.paint_part!(other, map, grain: 'length', bindings: { sheet: material })
    end
    s[:instance].definition = NxAppearanceMapping::Definition.new(s[:instance].definition.entities.dup)
    NxAppearanceMapping.rejects_without_writes(s) do
      NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: { sheet: material })
    end
  end
end

NxTest.test('MR3A paint: vsetky materialy aj mierky overi pred prvou platnou sheet zmenou') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    sheet = NxAppearanceMapping.native(s)
    dead = NxAppearanceMapping.native(s)
    dead.alive = false
    removed = NxAppearanceMapping.native(s)
    s[:model].materials.delete(removed)
    foreign = NxAppearanceMapping::Material.new(NxAppearanceMapping::Model.new)
    invalid = [dead, removed, foreign]
    [0, -1, Float::INFINITY, Float::NAN].each do |size|
      invalid << NxAppearanceMapping.native(s, size, 2.0)
      invalid << NxAppearanceMapping.native(s, 4.0, size)
    end
    invalid.each do |material|
      NxAppearanceMapping.rejects_without_writes(s) do
        NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length',
          bindings: { sheet: sheet, edges: { 'L1' => { material: material, inherit: false } } })
      end
    end
  end
end

NxTest.test('MR3A paint: len ABS binding nezasiahne ostatne plochy ani rodica') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    untouched = s[:faces].reject { |f| f.equal?(s[:faces][2]) }
    untouched.each do |face|
      face.material = Object.new
      face.back_material = Object.new
      face.positions << [:original_uv, :original_phase, true]
    end
    before = untouched.map { |f| [f.material, f.back_material, f.writes.dup, f.positions.dup] }
    NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'width',
      bindings: { edges: { 'L1' => { material: material, inherit: false } } })
    NxTest.assert_equal(before, untouched.map { |f| [f.material, f.back_material, f.writes.dup, f.positions.dup] })
    NxTest.assert_equal(:untouched_parent, s[:instance].material)
    NxTest.assert_equal([material, material], [s[:faces][2].material, s[:faces][2].back_material])
    NxAppearanceMapping.assert_frame(s[:faces][2], [0, 0, 0], [100.0 / 25.4, 0, 0], [0, 0, 50.0 / 25.4])
  end
end

NxTest.test('MR3A paint: chybajuce bindingy su no-op, vadny tvar sa neinterpretuje ako vymazanie') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    before = NxAppearanceMapping.state(s)
    NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: {})
    NxTest.assert_equal(before, NxAppearanceMapping.state(s))
    [{ sheet: nil }, { sheet: material, typo: true }, { edges: nil },
     { sheet: material, edges: { 'X1' => { material: material, inherit: false } } },
     { sheet: material, edges: { 'L1' => { material: material } } }].each do |bindings|
      NxAppearanceMapping.rejects_without_writes(s) do
        NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: bindings)
      end
    end
  end
end

NxTest.test('MR3A paint: texturovane ABS nesmie pouzit plain inherit skratku') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    s[:instance].material = material
    NxAppearanceMapping.rejects_without_writes(s) do
      NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length',
        bindings: { sheet: material, edges: { 'L1' => { material: material, inherit: true } } })
    end
  end
end

%w[length none width].each do |grain|
  NxTest.test("MR3A UV: sheet #{grain} pouziva nativne palce a rovnaku phase oboch stran") do
    NxAppearanceMapping.isolated do |s|
      map = NxAppearanceMapping.inspect_map(s)
      material = NxAppearanceMapping.native(s)
      NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: grain, bindings: { sheet: material })
      [4, 5].each do |index|
        z = index == 4 ? 0.0 : 18.0 / 25.4
        u = grain == 'width' ? [0, 100.0 / 25.4, z] : [100.0 / 25.4, 0, z]
        v = grain == 'width' ? [50.0 / 25.4, 0, z] : [0, 50.0 / 25.4, z]
        NxAppearanceMapping.assert_frame(s[:faces][index], [0, 0, z], u, v)
      end
      NxTest.assert(s[:faces].first(4).all? { |face| face.writes.empty? && face.positions.empty? })
      NxTest.assert_equal(:untouched_parent, s[:instance].material)
    end
  end
end

NxTest.test('MR3A UV: stojaci chrbat zasuvky ma L1 hore, ABS U stale pozdlz dlzky') do
  pd = NxAppearanceMapping.descriptor([300.0, 18.0, 180.0], { length: 0, width: 2, thickness: 1 }, 'drawer_back')
  NxAppearanceMapping.isolated(pd) do |s|
    map = NxAppearanceMapping.inspect_map(s)
    NxTest.assert_equal(s[:faces][5], map[:edges]['L1'])
    material = NxAppearanceMapping.native(s)
    NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'width',
      bindings: { edges: { 'L1' => { material: material, inherit: false } } })
    z = 180.0 / 25.4
    NxAppearanceMapping.assert_frame(s[:faces][5], [0, 0, z], [100.0 / 25.4, 0, z], [0, 50.0 / 25.4, z])
  end
end

NxTest.test('MR3A UV: spolocny sheet a ABS handle ma samostatne ramce vsetkych styroch hran') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    edges = %w[L1 L2 W1 W2].to_h { |slot| [slot, { material: material, inherit: false }] }
    NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: { sheet: material, edges: edges })
    [[2, 0.0], [3, 180.0 / 25.4]].each do |index, y|
      NxAppearanceMapping.assert_frame(s[:faces][index], [0, y, 0], [100.0 / 25.4, y, 0], [0, y, 50.0 / 25.4])
    end
    [[0, 0.0], [1, 300.0 / 25.4]].each do |index, x|
      NxAppearanceMapping.assert_frame(s[:faces][index], [x, 0, 0], [x, 100.0 / 25.4, 0], [x, 0, 50.0 / 25.4])
    end
    NxTest.assert(s[:faces].all? { |face| face.material.equal?(material) && face.back_material.equal?(material) })
  end
end

NxTest.test('MR3A UV: stvorcove celo pouzije explicitnu dlzku Z a finalnu hrubku Y') do
  pd = NxAppearanceMapping.descriptor([300.0, 19.0, 300.0], { length: 2, width: 0, thickness: 1 }, 'front_door')
  NxAppearanceMapping.isolated(pd) do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping.native(s)
    NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: { sheet: material })
    [[2, 0.0], [3, 19.0 / 25.4]].each do |index, y|
      NxAppearanceMapping.assert_frame(s[:faces][index], [0, y, 0], [0, y, 100.0 / 25.4], [50.0 / 25.4, y, 0])
    end
  end
end

NxTest.test('MR3A paint: material bez albeda nevola UV a plain inherit ostava nil') do
  NxAppearanceMapping.isolated do |s|
    map = NxAppearanceMapping.inspect_map(s)
    material = NxAppearanceMapping::Material.new(s[:model])
    s[:instance].material = material
    NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'none',
      bindings: { sheet: material, edges: { 'L1' => { material: material, inherit: true } } })
    NxTest.assert(s[:faces].all? { |face| face.positions.empty? })
    NxTest.assert_equal([nil, nil], [s[:faces][2].material, s[:faces][2].back_material])
    NxTest.assert_equal([material, material], [s[:faces][4].material, s[:faces][4].back_material])
    NxTest.assert_equal(material, s[:instance].material)
  end
end

%i[false raise].each do |failure|
  NxTest.test("MR3A failure: #{failure} na druhej strane sa prepusti ako AppearanceError") do
    NxAppearanceMapping.isolated do |s|
      map = NxAppearanceMapping.inspect_map(s)
      material = NxAppearanceMapping.native(s)
      s[:faces][4].fail_on_call = { 2 => failure }
      error = NxTest.assert_raise do
        NxAppearanceMapping.mapper.paint_part!(s[:instance], map, grain: 'length', bindings: { sheet: material })
      end
      NxTest.assert(error.is_a?(NxAppearanceMapping.mapper::MappingError))
      NxTest.assert(error.is_a?(Noxun::Engine::Materials::AppearanceError), 'Existujuci builder abort musi chybu zachytit')
      NxTest.assert_equal([true, false], s[:faces][4].positions.map(&:last), 'Prva strana preukazatelne presla pred chybou')
      NxTest.assert_equal([], s[:faces][5].positions, 'Po chybe nesmie pokracovat na dalsiu plochu')
    end
  end
end
