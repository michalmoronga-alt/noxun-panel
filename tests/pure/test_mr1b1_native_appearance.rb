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

  class Material < NxTest::FakeEntity
    attr_accessor :name, :save_result
    attr_reader :model
    def initialize(model)
      super()
      @model = model
      @name = 'Rucne premenovany zdroj'
      @save_result = true
    end
    def attribute_dictionaries
      dicts.map { |name, values| Dict.new(name, values) }
    end
    def save_as(path)
      File.write(path, JSON.generate('name' => name, 'dicts' => dicts))
      raise 'save exception' if save_result == :raise
      save_result
    end
    def restore(name, values)
      @name = name
      @dicts = Hash.new { |h, k| h[k] = {} }.merge(values)
    end
  end

  class Collection < Array
    attr_accessor :load_error, :load_nil, :returned, :loads
    def initialize(model)
      @model = model
      @loads = 0
      super()
    end
    def load(path)
      @loads += 1
      raise 'broken native archive' if load_error
      return nil if load_nil
      return returned if returned
      state = JSON.parse(File.read(path))
      mat = Material.new(@model)
      mat.restore(state['name'], state['dicts'])
      self << mat
      mat
    end
  end

  class Model
    attr_reader :materials, :starts, :aborts
    attr_accessor :abort_results, :damage_after_abort, :start_result
    def initialize
      @materials = Collection.new(self)
      @starts = @aborts = 0
      @abort_results = []
      @start_result = true
    end
    def start_operation(*)
      @starts += 1
      @snapshot = materials.map { |mat| [mat, mat.name, JSON.parse(JSON.generate(mat.dicts))] }
      start_result
    end
    def abort_operation
      @aborts += 1
      materials.replace(@snapshot.map(&:first))
      @snapshot.each { |mat, name, dicts| mat.restore(name, dicts) }
      materials.first.name = 'abort did not restore source' if damage_after_abort == @aborts
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
  def isolated
    NxTest.skip!('Double guardu nikdy nenahradza zivy SketchUp') unless NxTest.headless?
    model = Model.new
    source = Material.new(model)
    source.set_attribute('NOXUN', 'unrelated', 'zachovat')
    model.materials << source
    active = Module.new
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
