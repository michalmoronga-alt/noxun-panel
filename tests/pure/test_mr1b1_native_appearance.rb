# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)

# Failure injection iba do lokalnych doubles; nativny roundtrip zije v su_runner.
module NxMR1B1
  N = Noxun::Engine::NativeAppearance
  M = Noxun::Engine::Materials
  SCOPE = ['GRP-MR1B1', 'ST9'].freeze
  R1 = 'c1d81f89-240a-4e89-93bf-081745497301'
  R2 = 'c1d81f89-240a-4e89-93bf-081745497302'
  Dict = Struct.new(:name, :values) { def to_h = values.dup }
  Color = Struct.new(:red, :green, :blue)

  class Material < NxTest::FakeEntity
    attr_accessor :name, :save_result, :alive, :color
    attr_reader :model
    def initialize(model)
      super()
      @model = model
      @name = 'Rucne premenovany zdroj'
      @save_result = true
      @alive = true
      @color = [80, 100, 120]
    end
    def valid? = alive
    def color=(value)
      @color = value.to_a
    end
    def get_attribute(dict, key, default = nil) = dicts.fetch(dict, {}).fetch(key, default)
    def attribute_dictionaries
      dicts.map { |name, values| Dict.new(name, values) }
    end
    def save_as(path)
      File.write(path, JSON.generate('name' => name, 'dicts' => dicts, 'color' => color))
      raise 'save exception' if save_result == :raise
      save_result
    end
    def restore(name, values, color = @color)
      @name = name
      @dicts = Hash.new { |h, k| h[k] = {} }.merge(values)
      @color = color
    end
  end

  class Collection < Array
    attr_accessor :load_error, :load_nil, :returned, :loads, :on_load
    attr_reader :loaded, :paths, :adds
    def initialize(model)
      @model = model
      @loads = 0
      @loaded, @paths, @adds = [], [], 0
      super()
    end
    def add(name)
      @adds += 1
      mat = Material.new(@model)
      mat.name = name
      self << mat
      mat
    end
    def load(path)
      @loads += 1
      @paths << path
      on_load.call(path, @loads) if on_load
      raise 'broken native archive' if load_error
      return nil if load_nil
      return returned if returned
      state = JSON.parse(File.read(path))
      mat = Material.new(@model)
      mat.restore(state['name'], state['dicts'], state['color'])
      self << mat
      @loaded << mat
      mat
    end
  end

  class Model
    attr_reader :materials, :starts, :aborts
    attr_accessor :abort_results, :damage_after_abort, :start_result, :after_abort
    def initialize
      @materials = Collection.new(self)
      @starts = @aborts = 0
      @abort_results = []
      @start_result = true
    end
    def start_operation(*)
      @starts += 1
      @snapshot = materials.map { |mat| [mat, mat.name.dup, JSON.parse(JSON.generate(mat.dicts)), mat.color.dup] }
      start_result
    end
    def abort_operation
      @aborts += 1
      (materials - @snapshot.map(&:first)).each { |mat| mat.alive = false }
      materials.replace(@snapshot.map(&:first))
      @snapshot.each { |mat, name, dicts, color| mat.alive = true; mat.restore(name, dicts, color) }
      materials.first.name = 'abort did not restore source' if damage_after_abort == @aborts
      after_abort.call(@aborts) if after_abort
      result = abort_results.empty? ? true : abort_results.shift
      raise 'abort exception' if result == :raise
      result
    end
  end

  module_function
  def descriptor(revision = R1)
    { 'version' => 1, 'id' => revision, 'mode' => 'native', 'saved_at' => '2026-09-11T08:00:00Z' }
  end
  def tag(material, revision = R1, scope = SCOPE)
    material.set_attribute('NOXUN', 'appearance_scope', JSON.generate(scope))
    material.set_attribute('NOXUN', 'appearance_id', revision)
    material
  end
  # Testovaci JSON archiv pre Collection.load; skutocne SKM/PBR overuje SU.
  def archive(path, revision = R2, scope = SCOPE)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.generate('name' => 'Archivny zdroj', 'color' => [40, 80, 120],
      'dicts' => { 'NOXUN' => { 'appearance_scope' => JSON.generate(scope), 'appearance_id' => revision },
                   'foreign' => { 'keep' => 'archivny atribut' } }))
    path
  end

  def material_state(material) = [material.name.dup, JSON.generate(material.dicts), material.color.dup]
  def isolated
    NxTest.skip!('Double guardu nikdy nenahradza zivy SketchUp') unless NxTest.headless?
    model = Model.new
    source = Material.new(model)
    source.set_attribute('NOXUN', 'unrelated', 'zachovat')
    model.materials << source
    active = Module.new
    active.const_set(:Color, Color)
    active.define_singleton_method(:active_model) { model }
    guard = Module.new
    guard.define_singleton_method(:rebuilding?) { @busy == true }
    guard.define_singleton_method(:guard) do |&block|
      before = @busy
      @busy = true
      begin
        block.call
      ensure
        @busy = before
      end
    end
    N.const_set(:Sketchup, active)
    N.const_set(:ScaleWatch, guard)
    old_dir = M.test_dir_override
    Dir.mktmpdir('noxun-mr1b1-') do |temp|
      M.test_dir_override = temp
      yield model, source, temp, guard
    end
  ensure
    if NxTest.headless?
      M.test_dir_override = old_dir
      N.send(:remove_const, :Sketchup) if N.const_defined?(:Sketchup, false)
      N.send(:remove_const, :ScaleWatch) if N.const_defined?(:ScaleWatch, false)
    end
  end
  def error(klass)
    raised = nil
    begin
      yield
    rescue StandardError => ex
      raised = ex
    end
    NxTest.assert(raised.is_a?(klass), "Ocakavana #{klass}, dostali sme #{raised.inspect}")
  end
end

NxTest.test('mr1b1: lookup je strict, meno nerozhoduje; preferred je iba rovnaky scope') do
  NxMR1B1.isolated do |model, source|
    NxMR1B1.tag(source)
    NxTest.assert_equal(source, NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R1))
    NxTest.assert_equal(source, NxMR1B1::N.load(model, NxMR1B1::SCOPE, NxMR1B1.descriptor))
    NxTest.assert_equal(0, model.materials.loads)
    NxTest.assert_equal(0, model.starts)
    NxTest.assert_equal(nil, NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R2))
    NxTest.assert_equal(source, NxMR1B1::N.preferred(model, NxMR1B1::SCOPE, source))
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.preferred(NxMR1B1::Model.new, NxMR1B1::SCOPE, source) }
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.preferred(model, ['OTHER', 'ST9'], source) }
    copy = NxMR1B1.tag(NxMR1B1::Material.new(model))
    model.materials << copy
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R1) }
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.preferred(model, NxMR1B1::SCOPE, source) }
  end
end

NxTest.test('mr1b1: malformed scope/revision a cudzia revizia nie su absent') do
  NxMR1B1.isolated do |model, source|
    NxMR1B1.tag(source, NxMR1B1::R1, ['OTHER', 'ST9'])
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R1) }
    source.set_attribute('NOXUN', 'appearance_scope', 'invalid JSON')
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R1) }
    NxMR1B1.tag(source, 'bad UUID')
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R1) }
    NxMR1B1.error(NxMR1B1::N::IdentityError) { NxMR1B1::N.lookup(model, ['grp', ' st9 '], NxMR1B1::R1) }
  end
end

NxTest.test('mr1b1: missing, poskodeny subor a konflikt identity su rozlisene') do
  NxMR1B1.isolated do |model, source|
    n = NxMR1B1::N
    NxTest.assert_equal(nil, n.load(model, NxMR1B1::SCOPE, NxMR1B1.descriptor))
    path = NxMR1B1::M.appearance_file(NxMR1B1::R1)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, 'broken')
    NxMR1B1.error(n::LoadError) { n.load(model, NxMR1B1::SCOPE, NxMR1B1.descriptor) }
    model.materials.load_nil = true
    NxMR1B1.error(n::LoadError) { n.load(model, NxMR1B1::SCOPE, NxMR1B1.descriptor) }
    model.materials.load_nil = false
    NxMR1B1.tag(source, NxMR1B1::R2, ['OTHER', 'ST9'])
    model.materials.returned = source
    before = JSON.generate(source.dicts)
    NxMR1B1.error(n::IdentityError) { n.load(model, NxMR1B1::SCOPE, NxMR1B1.descriptor) }
    NxTest.assert_equal(before, JSON.generate(source.dicts))
    NxMR1B1.error(Noxun::Engine::Materials::AppearanceError) { n.load(model, NxMR1B1::SCOPE, NxMR1B1.descriptor.merge('version' => 2)) }
    NxMR1B1.error(n::IdentityError) { n.load(model, NxMR1B1::SCOPE, NxMR1B1.descriptor.merge('mode' => 'color')) }
  end
end

NxTest.test('mr1b1: export vyzaduje oba true aborty, source aj guard obnovene') do
  [[], [false], [:raise], [true, false], [true, :raise]].each do |aborts|
    NxMR1B1.isolated do |model, source, temp, guard|
      NxMR1B1.tag(source, NxMR1B1::R2)
      before = [source.name, JSON.generate(source.dicts)]
      model.abort_results = aborts.dup
      call = proc { NxMR1B1::N.export(model, source, File.join(temp, 'appearance.skm.staging'), NxMR1B1.descriptor, NxMR1B1::SCOPE) }
      if aborts.empty?
        NxTest.assert_equal(true, call.call)
        NxTest.assert_equal(2, model.aborts)
        NxTest.assert_equal(1, model.materials.loads)
      else
        NxMR1B1.error(NxMR1B1::N::OperationError, &call)
      end
      NxTest.assert_equal(before, [source.name, JSON.generate(source.dicts)])
      NxTest.assert_equal([source], model.materials)
      NxTest.refute(guard.rebuilding?)
    end
  end
end

NxTest.test('mr1b1: obnova source sa kontroluje aj po druhom true aborte') do
  [1, 2].each do |abort_index|
    NxMR1B1.isolated do |model, source, temp, guard|
      model.damage_after_abort = abort_index
      NxMR1B1.error(NxMR1B1::N::OperationError) do
        NxMR1B1::N.export(model, source, File.join(temp, 'bad.skm.staging'), NxMR1B1.descriptor, NxMR1B1::SCOPE)
      end
      NxTest.refute(guard.rebuilding?)
    end
  end
end

NxTest.test('mr1b1: save/load vynimka a save false vzdy obnovia source a guard') do
  [:save_false, :save_error, :load_error, :wrong_tuple].each do |mode|
    NxMR1B1.isolated do |model, source, temp, guard|
      source.save_result = false if mode == :save_false
      source.save_result = :raise if mode == :save_error
      model.materials.load_error = true if mode == :load_error
      model.materials.returned = source if mode == :wrong_tuple
      before = [source.name, JSON.generate(source.dicts)]
      NxMR1B1.error(StandardError) do
        NxMR1B1::N.export(model, source, File.join(temp, 'fail.skm.staging'), NxMR1B1.descriptor, NxMR1B1::SCOPE)
      end
      NxTest.assert_equal(before, [source.name, JSON.generate(source.dicts)])
      NxTest.assert_equal([source], model.materials)
      NxTest.refute(guard.rebuilding?)
    end
  end
end

NxTest.test('mr1b1: refusal pred nested operaciou a start false nic nemutuju') do
  NxMR1B1.isolated do |model, source, temp, guard|
    guard.guard do
      NxMR1B1.error(NxMR1B1::N::OperationError) do
        NxMR1B1::N.export(model, source, File.join(temp, 'guard.skm.staging'), NxMR1B1.descriptor, NxMR1B1::SCOPE)
      end
      NxTest.assert_equal(0, model.starts)
      NxTest.assert(guard.rebuilding?)
    end
    model.start_result = false
    NxMR1B1.error(NxMR1B1::N::OperationError) do
      NxMR1B1::N.export(model, source, File.join(temp, 'start.skm.staging'), NxMR1B1.descriptor, NxMR1B1::SCOPE)
    end
    NxTest.assert_equal(0, model.aborts)
    NxTest.refute(guard.rebuilding?)
  end
end

NxTest.test('MR2A create: novy izolovany RGB handle bez reuse a vlastnej operacie') do
  NxMR1B1.isolated do |model, source|
    old = NxMR1B1.material_state(source)
    created = NxMR1B1::N.create_working(model, scope: NxMR1B1::SCOPE, color: [0, 128, 255], revision: NxMR1B1::R1)
    NxTest.refute(created.equal?(source))
    NxTest.assert_equal([source, created], model.materials)
    NxTest.assert_equal([0, 128, 255], created.color)
    NxTest.assert_equal(created, NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R1))
    NxTest.assert_equal(old, NxMR1B1.material_state(source))
    NxTest.assert_equal([1, 0, 0], [model.materials.adds, model.starts, model.aborts])
  end
end

NxTest.test('MR2A create: RGB, UUID a obsadena revizia sa overia pred add') do
  colors = [nil, [], [1, 2], [1, 2, 3, 4], [0.0, 2, 3], ['1', 2, 3], [-1, 2, 3], [1, 2, 256]]
  NxMR1B1.isolated do |model, source|
    colors.each do |color|
      NxMR1B1.error(NxMR1B1::N::IdentityError) do
        NxMR1B1::N.create_working(model, scope: NxMR1B1::SCOPE, color: color, revision: NxMR1B1::R1)
      end
    end
    NxMR1B1.error(NxMR1B1::N::IdentityError) do
      NxMR1B1::N.create_working(model, scope: NxMR1B1::SCOPE, color: [1, 2, 3], revision: 'bad UUID')
    end
    [NxMR1B1::SCOPE, ['OTHER', 'ST9']].each do |scope|
      NxMR1B1.tag(source, NxMR1B1::R1, scope)
      before = NxMR1B1.material_state(source)
      NxMR1B1.error(NxMR1B1::N::IdentityError) do
        NxMR1B1::N.create_working(model, scope: NxMR1B1::SCOPE, color: [1, 2, 3], revision: NxMR1B1::R1)
      end
      NxTest.assert_equal(before, NxMR1B1.material_state(source))
    end
    NxTest.assert_equal([source], model.materials)
    NxTest.assert_equal([0, 0], [model.materials.adds, model.starts])
  end
end

NxTest.test('MR2A import: novy archivny handle s presnou identitou, bez vlastnej operacie') do
  NxMR1B1.isolated do |model, source, temp|
    path = NxMR1B1.archive(File.join(temp, 'working.skm'))
    old = NxMR1B1.material_state(source)
    imported = NxMR1B1::N.import_working(model, path, scope: NxMR1B1::SCOPE, revision: NxMR1B1::R2)
    NxTest.assert_equal([source, imported], model.materials)
    NxTest.assert_equal(imported, NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R2))
    NxTest.assert_equal(old, NxMR1B1.material_state(source))
    NxTest.assert_equal([1, 0, 0], [model.materials.loads, model.starts, model.aborts])
  end
end

NxTest.test('MR2A import: ani jeden spravny existujuci tuple nesmie obist novy pracovny handle') do
  NxMR1B1.isolated do |model, source, temp|
    path = NxMR1B1.archive(File.join(temp, 'working.skm'))
    [NxMR1B1::SCOPE, ['OTHER', 'ST9']].each do |scope|
      NxMR1B1.tag(source, NxMR1B1::R2, scope)
      old = NxMR1B1.material_state(source)
      NxMR1B1.error(NxMR1B1::N::IdentityError) do
        NxMR1B1::N.import_working(model, path, scope: NxMR1B1::SCOPE, revision: NxMR1B1::R2)
      end
      NxTest.assert_equal(old, NxMR1B1.material_state(source))
    end
    NxTest.assert_equal([0, 0], [model.materials.loads, model.starts])
    NxTest.assert_equal([source], model.materials)
  end
end

NxTest.test('MR2A import: native load reuse povodneho handle je chyba aj pri spravnom novom tuple') do
  NxMR1B1.isolated do |model, source, temp|
    path = NxMR1B1.archive(File.join(temp, 'working.skm'))
    model.materials.on_load = ->(*) { NxMR1B1.tag(source, NxMR1B1::R2) }
    model.materials.returned = source
    NxMR1B1.error(NxMR1B1::N::IdentityError) do
      NxMR1B1::N.import_working(model, path, scope: NxMR1B1::SCOPE, revision: NxMR1B1::R2)
    end
    NxTest.assert_equal(source, NxMR1B1::N.lookup(model, NxMR1B1::SCOPE, NxMR1B1::R2), 'Samotna tuple verifikacia by reuse pustila')
    NxTest.assert_equal([1, 0], [model.materials.loads, model.starts])
  end
end

NxTest.test('MR2A import: absent subor, nil load a iny archivny tuple nie su RGB fallback') do
  %i[missing directory nil wrong_scope wrong_revision duplicate].each do |kind|
    NxMR1B1.isolated do |model, source, temp|
      path = File.join(temp, 'working.skm')
      scope = kind == :wrong_scope ? ['OTHER', 'ST9'] : NxMR1B1::SCOPE
      revision = kind == :wrong_revision ? NxMR1B1::R1 : NxMR1B1::R2
      NxMR1B1.archive(path, revision, scope) unless %i[missing directory].include?(kind)
      path = temp if kind == :directory
      model.materials.load_nil = true if kind == :nil
      model.materials.on_load = ->(*) { NxMR1B1.tag(source, NxMR1B1::R2) } if kind == :duplicate
      klass = %i[missing directory nil].include?(kind) ? NxMR1B1::N::LoadError : NxMR1B1::N::IdentityError
      NxMR1B1.error(klass) { NxMR1B1::N.import_working(model, path, scope: NxMR1B1::SCOPE, revision: NxMR1B1::R2) }
      NxTest.assert_equal(0, model.starts)
      NxTest.assert_equal(0, model.materials.loads) if %i[missing directory].include?(kind)
    end
  end
end

NxTest.test('MR2A export: prave jeden zdroj a chybajuci file source je pravdiva chyba') do
  NxMR1B1.isolated do |model, source, temp|
    path = File.join(temp, 'working.skm.staging')
    [[source, NxMR1B1.descriptor(NxMR1B1::R2)], [nil, nil]].each do |live, file|
      NxMR1B1.error(NxMR1B1::M::AppearanceError) do
        NxMR1B1::N.export(model, live, path, NxMR1B1.descriptor, NxMR1B1::SCOPE, source_descriptor: file)
      end
    end
    NxTest.assert_equal(0, model.starts)
    NxMR1B1.error(NxMR1B1::N::LoadError) do
      NxMR1B1::N.export(model, nil, path, NxMR1B1.descriptor, NxMR1B1::SCOPE, source_descriptor: NxMR1B1.descriptor(NxMR1B1::R2))
    end
    NxTest.assert_equal([source], model.materials)
    NxTest.assert_equal(model.starts, model.aborts)
  end
end

NxTest.test('MR2A export: file source sa nacita v operacii a po oboch abortoch ostanu povodne handles') do
  NxMR1B1.isolated do |model, source, temp, guard|
    source_path = NxMR1B1.archive(NxMR1B1::M.appearance_file(NxMR1B1::R2))
    staging = File.join(temp, 'working.skm.staging')
    before = NxMR1B1.material_state(source)
    model.materials.on_load = lambda do |_path, index|
      NxTest.assert(guard.rebuilding?)
      NxTest.assert_equal(index, model.starts)
      NxTest.assert_equal(index - 1, model.aborts)
    end
    after = []
    model.after_abort = ->(index) { after << [index, model.materials.dup, model.materials.loaded.map(&:valid?)] }
    result = NxMR1B1::N.export(model, nil, staging, NxMR1B1.descriptor, NxMR1B1::SCOPE,
      source_descriptor: NxMR1B1.descriptor(NxMR1B1::R2))
    NxTest.assert_equal(true, result)
    NxTest.assert_equal([source_path, staging], model.materials.paths)
    NxTest.assert_equal([[1, [source], [false]], [2, [source], [false, false]]], after)
    NxTest.assert_equal(before, NxMR1B1.material_state(source))
    NxTest.assert_equal([2, 2], [model.starts, model.aborts])
    NxTest.refute(guard.rebuilding?)
  end
end

NxTest.test('MR2A export: source_descriptor s uz zivym R2 obnovi jeho povodny stav') do
  [nil, 1, 2].each do |damage|
    NxMR1B1.isolated do |model, source, temp|
      NxMR1B1.tag(source, NxMR1B1::R2)
      before = NxMR1B1.material_state(source)
      model.damage_after_abort = damage
      call = -> { NxMR1B1::N.export(model, nil, File.join(temp, 'working.skm.staging'), NxMR1B1.descriptor,
        NxMR1B1::SCOPE, source_descriptor: NxMR1B1.descriptor(NxMR1B1::R2)) }
      if damage
        NxMR1B1.error(NxMR1B1::N::OperationError, &call)
      else
        NxTest.assert_equal(true, call.call)
        NxTest.assert_equal(before, NxMR1B1.material_state(source))
        NxTest.assert_equal(1, model.materials.loads, 'R2 reuse nema osobitny load ani Undo')
      end
      NxTest.assert_equal([source], model.materials)
    end
  end
end

NxTest.test('MR2A export: chyba prveho alebo overovacieho file load nenecha docasny material') do
  [1, 2].each do |fail_at|
    NxMR1B1.isolated do |model, source, temp, guard|
      NxMR1B1.archive(NxMR1B1::M.appearance_file(NxMR1B1::R2))
      before = NxMR1B1.material_state(source)
      model.materials.on_load = ->(_path, index) { raise 'injected archive read failure' if index == fail_at }
      NxMR1B1.error(NxMR1B1::N::LoadError) do
        NxMR1B1::N.export(model, nil, File.join(temp, 'working.skm.staging'), NxMR1B1.descriptor,
          NxMR1B1::SCOPE, source_descriptor: NxMR1B1.descriptor(NxMR1B1::R2))
      end
      NxTest.assert_equal([source], model.materials)
      NxTest.assert_equal(before, NxMR1B1.material_state(source))
      NxTest.assert_equal([fail_at, fail_at], [model.starts, model.aborts])
      NxTest.assert(model.materials.loaded.none?(&:valid?))
      NxTest.refute(guard.rebuilding?)
    end
  end
end

NxTest.test('MR2A export: true abort s leak/drop/same-count replacement nie je presna obnova') do
  [[1, nil], [2, nil], [1, :save], [2, :load]].each do |abort_index, failure|
    %i[leak drop replacement].each do |damage|
      NxMR1B1.isolated do |model, source, temp|
        other = NxMR1B1::Material.new(model)
        model.materials << other
        rogue = NxMR1B1::Material.new(model)
        original = [source, other]
        source.save_result = false if failure == :save
        model.materials.load_error = true if failure == :load
        model.after_abort = lambda do |index|
          next unless index == abort_index
          case damage
          when :leak then model.materials << rogue
          when :drop then model.materials.delete(other)
          when :replacement then model.materials[1] = rogue
          end
        end
        NxMR1B1.error(NxMR1B1::N::OperationError) do
          NxMR1B1::N.export(model, source, File.join(temp, 'working.skm.staging'), NxMR1B1.descriptor, NxMR1B1::SCOPE)
        end
        NxTest.assert_equal(abort_index, model.aborts)
        NxTest.refute(original == model.materials)
        NxTest.assert_equal(original.length, model.materials.length) if damage == :replacement
        NxTest.assert_equal(source, model.materials.first, 'Source guard samotny nezisti chybu ineho handle')
      end
    end
  end
end
