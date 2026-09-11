# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)

# Skutocne Mower/Panel callbacky, izolovane moduly a doubles hranice buildera.
# Nedokazuje geometriu, nativne materialy ani Undo; to patri su_runneru.
module NxMRB2Copy
  E = Noxun::Engine
  CB = E::CabinetBuilder

  class Selection < Array
    def add(value) = self << value
  end

  class Model < NxTest::FakeEntity
    attr_reader :entities, :selection
    def initialize
      super
      @entities = []
      @selection = Selection.new
    end
    def cabinets = entities
    def valid? = true
    def active_path = nil
    def active_entities = entities
  end

  class Transform
    def *(other) = [self, other]
    def self.translation(vector) = vector
  end

  class Cabinet < NxTest::FakeEntity
    attr_accessor :model, :parent, :alive
    attr_reader :transformation
    def initialize(model, id = 'CAB-001')
      super()
      @model = @parent = model
      @alive = true
      @transformation = Transform.new
      E::Store.write(self, kind: 'cabinet', cabinet_id: id,
        config: { 'type' => 'lower', 'mode' => 'parametric', 'width' => 600.0,
                  'height' => 720.0, 'depth' => 560.0, 'material_id' => 'MAT-A' })
      model.entities << self
    end
    def valid? = alive
  end

  module_function

  def with_constants(mod, replacements)
    saved = {}
    replacements.each do |name, value|
      saved[name] = [mod.const_defined?(name, false), mod.const_get(name, false)] if mod.const_defined?(name, false)
      mod.send(:remove_const, name) if mod.const_defined?(name, false)
      mod.const_set(name, value)
    end
    yield
  ensure
    replacements.each_key do |name|
      mod.send(:remove_const, name) if mod.const_defined?(name, false)
      mod.const_set(name, saved[name][1]) if saved.key?(name)
    end
  end

  def stub(mod, name, implementation)
    original = mod.method(name)
    mod.define_singleton_method(name, implementation)
    yield
  ensure
    mod.define_singleton_method(name, original) if original
  end

  def isolated
    NxTest.skip!('Callback doubles nesmu nahradit moduly ziveho SketchUpu') unless NxTest.headless?
    a = Model.new
    source = Cabinet.new(a)
    state = { active: a, source: source, calls: [], warnings: [], errors: [], flushes: [], clock: 1000.0 }
    tools = Module.new
    tools.const_set(:MowerCalc, E::Tools::MowerCalc)
    panel = Module.new
    ghost = Module.new
    ghost.define_singleton_method(:cancel_session) { |*| nil }
    su = Module.new
    su.define_singleton_method(:active_model) { state[:active] }
    panel.const_set(:Sketchup, su)
    tools.const_set(:Sketchup, su)
    geom = Module.new
    geom.const_set(:Transformation, Transform)
    tools.const_set(:Geom, geom)
    units = Module.new
    units.define_singleton_method(:vector) { |*values| values }
    tools.const_set(:Units, units)
    tools.define_singleton_method(:active_model) { state[:active] }
    tools.define_singleton_method(:pick_target) { |_model| state[:source] }
    tools.define_singleton_method(:route) { |_model, inst| E::Store.kind(inst) == 'cabinet' ? :cabinet : :legacy }
    tools.define_singleton_method(:refused_context?) { |route| %i[edit_context nested].include?(route) }
    tools.define_singleton_method(:settle!) { |_model, _inst| true }
    tools.define_singleton_method(:info) { |*| nil }
    tools.define_singleton_method(:warn) { |message| state[:warnings] << message; nil }
    panel.define_singleton_method(:dialog_alive?) { true }
    panel.define_singleton_method(:request_native_flush) { |*args| state[:flushes] << args }
    panel.define_singleton_method(:push_selected) { |*args, **kwargs| nil }
    panel.define_singleton_method(:parse) { |payload| JSON.parse(payload) }
    panel.define_singleton_method(:foreign_document?) { |*| false }
    panel.define_singleton_method(:find_cabinet_by_id) { |model, id| model.cabinets.find { |cab| E::Store.get(cab, 'cabinet_id') == id } }
    panel.define_singleton_method(:find_cabinet) { |model| model.cabinets.first }
    panel.define_singleton_method(:select_only) { |*| nil }
    panel.define_singleton_method(:status_with_warnings) { |*| nil }
    panel.define_singleton_method(:part_count) { |*| 1 }
    panel.define_singleton_method(:set_status) { |*args| state[:warnings] << args }
    build = lambda do |model, params, **options|
      state[:calls] << { model: model, params: params, options: options }
      Cabinet.new(model, 'CAB-COPY')
    end
    with_constants(E, Tools: tools, Panel: panel, GhostTool: ghost) do
      load File.join(NxTest::ROOT, 'noxun_engine/tools/mower.rb')
      load File.join(NxTest::ROOT, 'noxun_engine/ui/panel/actions_cabinet.rb')
      mower = tools.const_get(:Mower)
      mower.define_singleton_method(:now) { state[:clock] }
      mower.define_singleton_method(:arm_flush_timeout) { |*| nil }
      stub(CB, :build, build) do
        stub(E::Ids, :each_cabinet, ->(model, &block) { model.cabinets.each(&block) }) do
          stub(E, :log_error, ->(*error) { state[:errors] << error }) do
            yield state, mower, panel
            NxTest.assert_equal([], state[:errors], 'Test nesmie prejst iba vdaka zachytenej chybe double API')
          end
        end
      end
    end
  end

  def pending(mower)
    mower.copy(:right)
    NxTest.assert(mower.pending_copy, 'otvoreny Inspector vytvori cakajucu kopiu')
    mower.pending_copy['token']
  end

  def assert_source(call, model, source)
    NxTest.assert_equal(model, call[:model])
    NxTest.assert(call[:options][:appearance_source].equal?(source), 'builder musi dostat presny zivy source handle')
    NxTest.refute(call[:params].key?(:appearance_source) || call[:params].key?('appearance_source'),
                  'source je samostatny keyword, nikdy config/InsertPlan data')
  end
end

NxTest.test('MR-B2 copy: Mower pending v A po prepnuti B s rovnakym CAB ID nic nevlozi') do
  NxMRB2Copy.isolated do |s, mower, _panel|
    original_model = s[:active]
    token = NxMRB2Copy.pending(mower)
    b = NxMRB2Copy::Model.new
    NxMRB2Copy::Cabinet.new(b)
    s[:active] = b
    mower.resolve_flush(token, 'flushed')
    NxTest.assert_equal([], s[:calls], 'ziadna kopia v A ani nahradny source v B')
    NxTest.assert_equal(1, original_model.cabinets.length)
    NxTest.assert_equal(1, b.cabinets.length)
    NxTest.assert_equal(nil, mower.pending_copy)
    NxTest.assert(!s[:warnings].empty?, 'odmietnutie musi byt viditelne')
  end
end

NxTest.test('MR-B2 copy: zmazany source nenahradi nova skrinka s rovnakym CAB ID') do
  NxMRB2Copy.isolated do |s, mower, _panel|
    token = NxMRB2Copy.pending(mower)
    s[:source].alive = false
    s[:active].entities.delete(s[:source])
    NxMRB2Copy::Cabinet.new(s[:active])
    mower.resolve_flush(token, 'nothing')
    NxTest.assert_equal([], s[:calls])
    NxTest.assert_equal(nil, mower.pending_copy)
  end
end

NxTest.test('MR-B2 copy: zmenene ID zdroja odmietne aj ked rovnake stare ID dostal iny cabinet') do
  NxMRB2Copy.isolated do |s, mower, _panel|
    token = NxMRB2Copy.pending(mower)
    NxMRB2Copy::E::Store.write(s[:source], cabinet_id: 'CAB-RENAMED-ID')
    NxMRB2Copy::Cabinet.new(s[:active])
    mower.resolve_flush(token, 'nothing')
    NxTest.assert_equal([], s[:calls])
  end
end

NxTest.test('MR-B2 copy: zivy source preneseny do ineho modelu uz nepatri pending kopii') do
  NxMRB2Copy.isolated do |s, mower, _panel|
    token = NxMRB2Copy.pending(mower)
    other = NxMRB2Copy::Model.new
    s[:source].model = s[:source].parent = other
    mower.resolve_flush(token, 'nothing')
    NxTest.assert_equal([], s[:calls])
  end
end

NxTest.test('MR-B2 copy: source handle ma prednost pred inou zhodnou identitou v tom istom modeli') do
  NxMRB2Copy.isolated do |s, mower, _panel|
    token = NxMRB2Copy.pending(mower)
    duplicate = NxMRB2Copy::Cabinet.new(s[:active])
    s[:active].entities.delete(duplicate)
    s[:active].entities.unshift(duplicate)
    mower.resolve_flush(token, 'nothing')
    NxTest.assert_equal(1, s[:calls].length)
    NxMRB2Copy.assert_source(s[:calls].first, s[:active], s[:source])
  end
end

NxTest.test('MR-B2 copy: uspesny flush cita cerstvy config a prenasa captured source mimo params') do
  NxMRB2Copy.isolated do |s, mower, _panel|
    token = NxMRB2Copy.pending(mower)
    cfg = NxMRB2Copy::E::Store.config(s[:source]).merge('width' => 810.0)
    NxMRB2Copy::E::Store.write_config(s[:source], cfg)
    mower.resolve_flush(token, 'flushed')
    NxTest.assert_equal(1, s[:calls].length)
    call = s[:calls].first
    NxMRB2Copy.assert_source(call, s[:active], s[:source])
    NxTest.assert_equal(810.0, call[:params]['width'] || call[:params][:width])
    NxTest.assert(call[:options].key?(:transform), 'toolbar kopia musi stale odovzdat svoju polohu')
    NxTest.assert_equal(cfg, NxMRB2Copy::E::Store.config(s[:source]), 'source config je nezmeneny')
    mower.resolve_flush(token, 'flushed')
    NxTest.assert_equal(1, s[:calls].length, 'duplikovana odpoved nevlozi druhu kopiu')
  end
end

NxTest.test('MR-B2 copy: starsi token nesmie odomknut alebo vykonat novsiu pending kopiu') do
  NxMRB2Copy.isolated do |s, mower, _panel|
    old = NxMRB2Copy.pending(mower)
    fresh = NxMRB2Copy.pending(mower)
    mower.resolve_flush(old, 'nothing')
    NxTest.assert_equal([], s[:calls])
    NxTest.assert_equal(fresh, mower.pending_copy['token'])
    mower.resolve_flush(fresh, 'nothing')
    NxTest.assert_equal(1, s[:calls].length)
    NxMRB2Copy.assert_source(s[:calls].first, s[:active], s[:source])
  end
end

NxTest.test('MR-B2 copy: toolbar bez otvoreneho Inspectora tiez prenasa presny source') do
  NxMRB2Copy.isolated do |s, mower, panel|
    panel.define_singleton_method(:dialog_alive?) { false }
    mower.copy(:left)
    NxTest.assert_equal(nil, mower.pending_copy)
    NxTest.assert_equal(1, s[:calls].length)
    NxMRB2Copy.assert_source(s[:calls].first, s[:active], s[:source])
  end
end

NxTest.test('MR-B2 copy: panel prenasa serverovy source a ignoruje klientsky appearance_source') do
  NxMRB2Copy.isolated do |s, _mower, panel|
    before = NxMRB2Copy::E::Store.config(s[:source])
    panel.handle_insert_copy(JSON.generate('cabinet_id' => 'CAB-001', 'appearance_source' => 'FORGED'))
    NxTest.assert_equal(1, s[:calls].length)
    NxMRB2Copy.assert_source(s[:calls].first, s[:active], s[:source])
    NxTest.assert_equal(before, NxMRB2Copy::E::Store.config(s[:source]))
    NxTest.refute(s[:calls].first[:options].key?(:transform), 'panel ponecha polohu existujucemu builderu')
  end
end
