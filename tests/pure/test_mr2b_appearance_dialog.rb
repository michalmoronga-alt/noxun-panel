# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  %w[production_core studio_dialog materials_dialog materials_appearance_dialog].each do |file|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', file)
  end
end

NxTest.test('mr2b Prepare color/sheet/edge is read-only and both anchors share fresh RGB') do
  NxMR2B.isolated do |c|
    model = c[:model]
    snapshot = [model.materials.dup, model.starts, model.materials.current_reads, model.materials.current_writes, File.binread(NxMR2B::M.path)]
    sheet = NxMR2B.prepare(c)
    edge = NxMR2B.prepare(c, NxMR2B.request(c, kind: 'edge'))
    NxTest.assert(sheet && sheet['ok'] && edge && edge['ok'])
    NxTest.assert_equal('color', sheet.dig('state', 'mode'))
    NxTest.assert_equal([100, 120, 140], edge.dig('state', 'color'))
    NxTest.refute(sheet.dig('state', 'can_save'))
    NxTest.refute(sheet['session_token'] == edge['session_token'])
    NxTest.assert_equal(snapshot, [model.materials.dup, model.starts, model.materials.current_reads, model.materials.current_writes, File.binread(NxMR2B::M.path)])
    NxTest.assert(c[:loads].empty? && c[:applied].empty? && c[:created].empty? && c[:exports].empty?)
  end
end

NxTest.test('mr2b Save captures exact live library source and ignores materials.current') do
  NxMR2B.isolated do |c|
    source = NxMR2B.tagged(c, SecureRandom.uuid, 'source visual')
    library = NxMR2B.publish(c, source)
    live = NxMR2B.tagged(c, library['id'], 'locally edited R2')
    other = NxMR2B.tagged(c, SecureRandom.uuid, 'unrelated current')
    c[:model].materials.current = other
    c[:exports].clear
    NxTest.assert(NxMR2B.prepare(c)['ok'])
    NxTest.assert(c[:loads].empty?, 'Prepare must not load the archive')
    result, payload = NxMR2B.action(c, 'save')
    NxTest.assert(result && result['ok'], result.inspect)
    NxTest.assert_equal(payload['action_token'], result['action_token'])
    NxTest.assert_equal(live, c[:exports].last[0])
    NxTest.assert_equal('locally edited R2', c[:exports].last[1])
    NxTest.refute(c[:exports].any? { |entry| entry[0] == other })
  end
end

NxTest.test('mr2b each explicit Pick rotates W while old source and catalog remain intact') do
  NxMR2B.isolated do |c|
    NxMR2B.prepare(c)
    catalog = File.binread(NxMR2B::M.path)
    first, = NxMR2B.action(c, 'pick')
    old = c[:applied].last
    NxTest.assert(first && first['ok'], first.inspect)
    old_visual = old.visual.dup
    File.write(c[:image], 'different second image')
    second, = NxMR2B.action(c, 'pick')
    fresh = c[:applied].last
    NxTest.assert(second && second['ok'], second.inspect)
    NxTest.refute(fresh == old)
    NxTest.assert_equal(old_visual, old.visual)
    NxTest.assert_equal('different second image', fresh.visual)
    NxTest.assert_equal(old, c[:exports].last[0])
    NxTest.assert_equal(catalog, File.binread(NxMR2B::M.path))
  end
end

NxTest.test('mr2b published-but-Apply-failed retry uses exact published revision once') do
  NxMR2B.isolated do |c|
    NxMR2B.prepare(c)
    NxMR2B.action(c, 'pick')
    old = c[:applied].last
    c[:apply_error] = true
    failed, = NxMR2B.action(c, 'save')
    NxTest.assert(failed && !failed['ok'] && failed.dig('state', 'can_apply'), failed.inspect)
    published = NxMR2B::M.sheet(c[:sid]).fetch('appearance')
    catalog = File.binread(NxMR2B::M.path)
    exports = c[:exports].length
    old.visual = 'changed OLD W after publication'
    c[:apply_error] = false
    retried, = NxMR2B.action(c, 'apply')
    NxTest.assert(retried && retried['ok'], retried.inspect)
    NxTest.assert_equal(published['id'], c[:loads].last)
    NxTest.refute(c[:applied].last == old)
    NxTest.assert_equal('new image fixture', c[:applied].last.visual)
    NxTest.assert_equal(exports, c[:exports].length)
    NxTest.assert_equal(catalog, File.binread(NxMR2B::M.path))
  end
end

NxTest.test('mr2b Reset forgets W even when Apply fails, next Edit starts fresh color') do
  NxMR2B.isolated do |c|
    NxMR2B.prepare(c)
    NxMR2B.action(c, 'pick')
    old = c[:applied].last
    c[:apply_error] = true
    reset, = NxMR2B.action(c, 'reset')
    NxTest.assert(reset && !reset['ok'], reset.inspect)
    NxTest.assert_equal('color', NxMR2B::M.sheet(c[:sid]).dig('appearance', 'mode'))
    NxTest.assert_equal('color', reset.dig('state', 'mode'))
    c[:apply_error] = false
    exports = c[:exports].length
    edited, = NxMR2B.action(c, 'edit')
    NxTest.assert(edited && edited['ok'], edited.inspect)
    fresh = c[:applied].last
    NxTest.refute(fresh == old)
    NxTest.assert_equal('plain', fresh.visual)
    NxTest.assert_equal([100, 120, 140], fresh.color)
    NxTest.assert_equal(exports, c[:exports].length, 'Reset old W must not become an export source again')
  end
end

NxTest.test('mr2b missing R2 stays missing; explicit Pick repairs from RGB without choosing R1') do
  NxMR2B.isolated do |c|
    old = NxMR2B.tagged(c, SecureRandom.uuid, 'older R1')
    library = NxMR2B.publish(c, old)
    File.delete(NxMR2B::M.appearance_file(library['id']))
    c[:exports].clear
    ready = NxMR2B.prepare(c)
    NxTest.assert(ready && ready['ok'], ready.inspect)
    NxTest.assert_equal('missing', ready.dig('state', 'mode'))
    NxTest.refute(ready.dig('state', 'can_edit'))
    NxTest.refute(ready.dig('state', 'can_save'))
    picked, = NxMR2B.action(c, 'pick')
    NxTest.assert(picked && picked['ok'], picked.inspect)
    NxTest.assert(c[:exports].empty?, 'Missing R2 must not silently export the older R1')
    NxTest.refute(c[:applied].last == old)
    NxTest.assert_equal('older R1', old.visual)
  end
end

NxTest.test('mr2b modal picker revalidates model, DocKey, section and Studio ABA before writes') do
  %i[model doc_key section studio].each do |change|
    NxMR2B.isolated do |c|
      NxMR2B.prepare(c)
      c[:picker] = lambda do
        case change
        when :model then c[:active_model] = NxMR2B::Model.new
        when :doc_key then NxMR2B::E::DocKey.invalidate(c[:model])
        when :section then NxMR2B::MD.cancel_demos_on_leave
        when :studio then NxMR2B::SD.instance_variable_set(:@dialog, NxMR2B::Dialog.new)
        end
        c[:image]
      end
      result, = NxMR2B.action(c, 'pick')
      NxTest.assert(c[:applied].empty? && c[:created].empty? && c[:exports].empty?, change.to_s)
      NxTest.assert(result.nil? || result['ok'] == false, "Stale #{change} cannot succeed")
    end
  end
end

NxTest.test('mr2b closed/reopened identical target rejects old session and keeps new owner') do
  NxMR2B.isolated do |c|
    payload = NxMR2B.request(c)
    first = NxMR2B.prepare(c, payload)
    old = c[:envelope].dup
    NxMR2B.action(c, 'close')
    second = NxMR2B.prepare(c, payload)
    NxTest.refute(first['session_token'] == second['session_token'])
    current = c[:envelope].dup
    c[:envelope] = old
    rejected, = NxMR2B.action(c, 'edit')
    NxTest.assert(rejected.nil? || !rejected['ok'])
    NxTest.assert(c[:applied].empty?)
    c[:envelope] = current
    accepted, = NxMR2B.action(c, 'edit')
    NxTest.assert(accepted && accepted['ok'], accepted.inspect)
  end
end

NxTest.test('mr2b color action ends in correlated result on refusal, exception and success') do
  NxMR2B.isolated do |c|
    NxMR2B.prepare(c)
    row = NxMR2B::M.sheet(c[:sid])
    %i[guard refusal exception success].each do |mode|
      context = c[:envelope].merge('action_token' => SecureRandom.uuid)
      payload = { 'decor' => row['decor'], 'group_id' => row['group_id'], 'color' => [11, 22, 33],
                  'catalog_schema' => NxMR2B::M::SCHEMA_CURRENT, 'appearance_context' => context }
      c[:sent].clear
      call = -> { NxMR2B::MD.dispatch('set_decor_color', payload.to_json, c[:sink]) }
      case mode
      when :guard then NxMR2B.stub(NxMR2B::MD, :catalog_write_ok?, ->(_data) { false }, &call)
      when :refusal then NxMR2B.stub(NxMR2B::M, :set_decor_color, ->(*) { [false, 'Denied fixture'] }, &call)
      when :exception then NxMR2B.stub(NxMR2B::M, :set_decor_color, ->(*) { raise 'Color write fixture error' }, &call)
      else call.call
      end
      result = NxMR2B.reply(c, 'appearanceResult')
      NxTest.assert(result, "Final result missing for #{mode}")
      NxTest.assert_equal('color', result['action'])
      NxTest.assert_equal(context['action_token'], result['action_token'])
      NxTest.assert_equal(mode == :success, result['ok'])
    end
    NxTest.assert_equal([11, 22, 33], NxMR2B::M.sheet(c[:sid])['color'])
    NxTest.assert(c[:exports].empty? && c[:applied].empty?)
  end
end

NxTest.test('mr2b deferred Save uses exact archive and a leave during export cannot publish') do
  NxMR2B.isolated do |c|
    source = NxMR2B.tagged(c, SecureRandom.uuid, 'exact archived source')
    published = NxMR2B.publish(c, source)
    c[:exports].clear
    ready = NxMR2B.prepare(c)
    NxTest.assert(ready && ready['ok'] && c[:loads].empty?)
    saved, = NxMR2B.action(c, 'save')
    NxTest.assert(saved && saved['ok'], saved.inspect)
    NxTest.assert_equal(published['id'], c[:loads].first)
    NxTest.assert_equal('exact archived source', c[:exports].last[1])
    catalog = File.binread(NxMR2B::M.path)
    applied = c[:applied].length
    c[:after_export] = -> { NxMR2B::MD.cancel_demos_on_leave }
    stale, = NxMR2B.action(c, 'save')
    NxTest.assert(stale.nil?)
    NxTest.assert_equal(catalog, File.binread(NxMR2B::M.path))
    NxTest.assert_equal(applied, c[:applied].length)
  end
end

NxTest.test('mr2b busy survives replacement Prepare while original picker is open') do
  NxMR2B.isolated do |c|
    NxMR2B.prepare(c)
    replacement = nil
    c[:picker] = -> {
      ready = NxMR2B.prepare(c)
      NxTest.assert(ready && ready['ok'])
      replacement, = NxMR2B.action(c, 'edit')
      c[:image]
    }
    NxMR2B.action(c, 'pick')
    NxTest.assert(replacement && !replacement['ok'])
    NxTest.assert(c[:applied].empty? && c[:created].empty? && c[:exports].empty?)
    c[:picker] = nil
    next_action, = NxMR2B.action(c, 'edit')
    NxTest.assert(next_action && next_action['ok'], next_action.inspect)
    NxTest.assert_equal(1, c[:created].length)
  end
end

NxTest.test('mr2b duplicate live exact tuple is a Prepare error and never RGB fallback') do
  NxMR2B.isolated do |c|
    published = NxMR2B.publish(c, NxMR2B.tagged(c))
    2.times { NxMR2B.tagged(c, published['id']) }
    c[:exports].clear
    result = NxMR2B.prepare(c)
    NxTest.assert(result && !result['ok'], result.inspect)
    NxTest.assert(c[:loads].empty? && c[:created].empty? && c[:applied].empty? && c[:exports].empty?)
  end
end

# Controller contracts use real catalog/publish/identity, doubles only for native
# material operations and the host UI. Actual SKM, geometry and Undo are in SU.
module NxMR2B
  E = Noxun::Engine
  M = E::Materials
  N = E::NativeAppearance
  MD = E::MaterialsDialog
  SD = E::StudioDialog
  Dict = Struct.new(:name, :values) { def to_h = values.dup }
  Texture = Struct.new(:filename, :width, :height) do
    def size=(values)
      self.width, self.height = values
    end
  end
  class Material < NxTest::FakeEntity
    attr_accessor :name, :visual, :color, :alpha
    attr_reader :model, :texture
    def initialize(model, name)
      super()
      @model, @name, @visual, @color, @alpha = model, name, 'plain', [100, 120, 140], 1.0
    end
    def attribute_dictionaries = dicts.map { |name, values| Dict.new(name, values) }
    def texture=(path)
      path, width, height = path if path.is_a?(Array)
      @texture = path && Texture.new(path, width || 100.0, height || 50.0)
      @visual = path ? File.binread(path) : 'plain'
    end
    def get_attribute(dict, key, default = nil) = dicts.fetch(dict, {}).fetch(key, default)
  end
  class Collection < Array
    attr_reader :current_reads, :current_writes
    def initialize(model)
      @model, @current_reads, @current_writes = model, 0, 0
      super()
    end
    def add(name)
      material = Material.new(@model, name)
      self << material
      material
    end
    def current
      @current_reads += 1
      @current
    end
    def current=(value)
      @current_writes += 1
      @current = value
    end
  end
  class Model
    attr_accessor :active_path
    attr_reader :materials, :starts
    def initialize
      @materials, @starts = Collection.new(self), 0
    end
    def valid? = true
    def path = ''
    def start_operation(*) = (@starts += 1)
  end
  class Dialog
    attr_reader :scripts
    def initialize = (@scripts = [])
    def visible? = true
    def execute_script(script) = scripts << script
  end

  module_function
  def stub(mod, name, replacement)
    original = mod.method(name)
    private_method = mod.singleton_class.private_method_defined?(name)
    mod.define_singleton_method(name, &replacement)
    yield
  ensure
    if original
      mod.define_singleton_method(name, original)
      mod.singleton_class.send(:private, name) if private_method
    end
  end
  def stubs(items, &block)
    return block.call if items.empty?
    mod, name, replacement = items.first
    stub(mod, name, replacement) { stubs(items.drop(1), &block) }
  end
  def descriptor(id = SecureRandom.uuid)
    { 'version' => 1, 'id' => id, 'mode' => 'native', 'saved_at' => '2026-09-12T14:00:00Z' }
  end
  def tagged(ctx, revision = SecureRandom.uuid, visual = 'captured')
    material = ctx[:model].materials.add("W #{revision}")
    material.set_attribute('NOXUN', 'appearance_scope', JSON.generate(ctx[:scope]))
    material.set_attribute('NOXUN', 'appearance_id', revision)
    material.visual = visual
    material
  end
  def publish(ctx, source)
    _, state = M.appearance_scope('sheet', ctx[:sid])
    status, output = M.publish_appearance('sheet', ctx[:sid], baseline: state['baseline'], mode: 'native') do |path, desc, scope|
      N.export(ctx[:model], source, path, desc, scope)
    end
    raise "Fixture publication failed: #{output.inspect}" unless status == :ok
    output.fetch('appearance')
  end
  def from_archive(ctx, revision, path)
    data = JSON.parse(File.read(path))
    material = tagged(ctx, revision, data.fetch('visual'))
    material.instance_variable_set(:@texture, Texture.new(*data['texture'])) if data['texture']
    material
  end
  def reply(ctx, method)
    script = ctx[:sent].reverse.find { |s| s.start_with?("MD.#{method}(") }
    script && JSON.parse(script.sub(/\AMD\.[^(]+\(/, '').sub(/\);?\z/, ''))
  end
  def request(ctx, request_token = SecureRandom.uuid, kind: 'sheet', anchor: nil)
    { 'request_token' => request_token, 'model_guid' => E::DocKey.key(ctx[:model]), 'section' => 'mat',
      'kind' => kind, 'anchor_id' => anchor || (kind == 'sheet' ? ctx[:sid] : ctx[:aid]), 'catalog_schema' => M::SCHEMA_CURRENT }
  end
  def prepare(ctx, payload = request(ctx))
    ctx[:sent].clear
    MD.dispatch('appearance_prepare', payload.to_json, ctx[:sink])
    ready = reply(ctx, 'appearanceReady')
    ctx[:envelope] = payload.merge('session_token' => ready['session_token']) if ready && ready['ok']
    ready
  end
  def action(ctx, action, extra = {})
    payload = ctx.fetch(:envelope).merge('action_token' => SecureRandom.uuid).merge(extra)
    ctx[:sent].clear
    MD.dispatch("appearance_#{action}", payload.to_json, ctx[:sink])
    [reply(ctx, 'appearanceResult'), payload]
  end

  def isolated
    NxTest.skip!('Controller doubles are headless only') unless NxTest.headless?
    old_dir = M.test_dir_override
    old_dialog, old_ready = SD.instance_variable_get(:@dialog), SD.instance_variable_get(:@ready)
    had_scale_watch = MD.const_defined?(:ScaleWatch, false)
    old_scale_watch = MD.const_get(:ScaleWatch, false) if had_scale_watch
    MD.send(:remove_const, :ScaleWatch) if had_scale_watch
    MD.const_set(:ScaleWatch, Module.new { def self.rebuilding? = false })
    old_sketchup = Object.const_get(:Sketchup) if Object.const_defined?(:Sketchup)
    Object.send(:remove_const, :Sketchup) if old_sketchup
    sketchup = Module.new
    ctx = { model: Model.new, sent: [], loads: [], exports: [], applied: [], created: [], picker_calls: 0, editors: [], echoes: 0 }
    ctx[:active_model] = ctx[:model]
    sketchup.define_singleton_method(:active_model) { ctx[:active_model] }
    Object.const_set(:Sketchup, sketchup)
    ctx[:sink] = ->(script) { ctx[:sent] << script.to_s; true }
    SD.instance_variable_set(:@dialog, Dialog.new)
    SD.instance_variable_set(:@ready, true)
    Dir.mktmpdir('noxun-mr2b-controller-') do |temp|
      ctx[:temp] = temp
      M.test_dir_override = temp
      M.reload!
      M.load
      status, rows = M.add_decor_batch('batch_schema' => 3, 'decor' => 'MR2B test', 'type' => 'DTDL',
        'color' => [100, 120, 140], 'grain' => 'length',
        'sheet_variants' => [{ 'thickness' => 18.0, 'structure' => 'SM' }],
        'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'SM' }])
      raise rows.inspect unless status
      ctx[:sid], ctx[:aid] = rows['sheets'].first, rows['edges'].first
      ctx[:scope] = M.appearance_scope_key(M.sheet(ctx[:sid]))
      ctx[:image] = File.join(temp, 'chosen.png')
      File.write(ctx[:image], 'new image fixture')
      native_load = ->(model, scope, desc) do
        ctx[:loads] << desc['id']
        found = N.lookup(model, scope, desc['id'])
        next found if found
        path = M.appearance_file(desc['id'])
        next nil unless File.file?(path)
        NxMR2B.from_archive(ctx, desc['id'], path)
      end
      overrides = [
        [MD, :appearance_pick_image, -> { ctx[:picker_calls] += 1; ctx[:picker] ? ctx[:picker].call : ctx[:image] }],
        [MD, :appearance_open_editor, ->(model, material) { ctx[:editors] << material; model.materials.current = material; true }],
        [MD, :after_catalog_change, -> { ctx[:echoes] += 1 }],
        [N, :load, native_load],
        [N, :export, ->(model, source, path, desc, scope, source_descriptor: nil) {
          source ||= native_load.call(model, scope, source_descriptor)
          raise N::LoadError, 'Missing fake archive' unless source
          ctx[:exports] << [source, source.visual.dup, desc['id']]
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, JSON.generate('visual' => source.visual, 'texture' => source.texture&.to_a))
          ctx[:after_export]&.call
          true
        }],
        [N, :import_working, ->(_model, path, scope:, revision:) { NxMR2B.from_archive(ctx, revision, path) }],
        [N, :create_working, ->(_model, scope:, color:, revision:) {
          material = NxMR2B.tagged(ctx, revision, 'plain')
          material.color = color
          ctx[:created] << material
          material
        }],
        [E::ApplyAppearance, :apply, ->(_model, scope:, material: nil, &block) {
          raise E::ApplyAppearance::ApplyError, 'Injected Apply failure' if ctx[:apply_error]
          material = block.call if block
          ctx[:applied] << material
          { status: :applied, material: material, updated_parts: 0, updated_sheets: 0, updated_edges: 0, skipped_parts: 0, skips: [] }
        }]
      ]
      stubs(overrides) { yield ctx }
    ensure
      MD.send(:appearance_invalidate!)
    end
  ensure
    if NxTest.headless?
      M.test_dir_override = old_dir
      M.reload!
      SD.instance_variable_set(:@dialog, old_dialog)
      SD.instance_variable_set(:@ready, old_ready)
      MD.send(:remove_const, :ScaleWatch) if MD.const_defined?(:ScaleWatch, false)
      MD.const_set(:ScaleWatch, old_scale_watch) if had_scale_watch
      Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
      Object.const_set(:Sketchup, old_sketchup) if old_sketchup
    end
  end
end
