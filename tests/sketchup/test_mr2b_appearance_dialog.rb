# frozen_string_literal: true

# MR-2B controller regressions. The real dispatch, catalog, SKM and model run
# here; only the native picker/editor UI is replaced by a deterministic seam.
module NoxunSuRunner
  class MR2BDialog
    attr_reader :scripts
    def initialize = (@scripts = [])
    def visible? = true
    def execute_script(script) = @scripts << script
  end

  module_function

  def mr2b_stub(owner, name, replacement)
    original = owner.method(name)
    was_private = owner.singleton_class.private_method_defined?(name)
    owner.define_singleton_method(name, &replacement)
    yield
  ensure
    if original
      owner.define_singleton_method(name, original)
      owner.singleton_class.send(:private, name) if was_private
    end
  end

  def mr2b_reply(ctx, method)
    script = ctx[:sent].reverse.find { |s| s.start_with?("MD.#{method}(") }
    script && JSON.parse(script.sub(/\AMD\.[^(]+\(/, '').sub(/\);?\z/, ''))
  end

  def mr2b_prepare(model, ctx, kind = 'sheet')
    payload = { 'request_token' => SecureRandom.uuid, 'model_guid' => e::DocKey.key(model), 'section' => 'mat',
                'kind' => kind, 'anchor_id' => kind == 'sheet' ? ctx[:a] : ctx[:ae],
                'catalog_schema' => e::Materials::SCHEMA_CURRENT }
    ctx[:sent].clear
    e::MaterialsDialog.dispatch('appearance_prepare', payload.to_json, ctx[:sink])
    result = mr2b_reply(ctx, 'appearanceReady')
    raise "MR2B Prepare: #{result.inspect}" unless result && result['ok']
    ctx[:envelope] = payload.merge('session_token' => result['session_token'])
    result
  end

  def mr2b_action(ctx, action)
    payload = ctx.fetch(:envelope).merge('action_token' => SecureRandom.uuid)
    ctx[:sent].clear
    e::MaterialsDialog.dispatch("appearance_#{action}", payload.to_json, ctx[:sink])
    result = mr2b_reply(ctx, 'appearanceResult')
    if result
      ok("MR2B #{action}: konecna odpoved patri povodnej akcii", result['action'] == action &&
         payload.all? { |key, value| key == 'catalog_schema' || result[key] == value })
    end
    result
  end

  def mr2b_required(result, action)
    raise "MR2B #{action}: #{result.inspect}" unless result && result['ok']
    result
  end

  def mr2b_fail_apply
    calls = 0
    service = e::ApplyAppearance
    trace = TracePoint.new(:call) do |tp|
      next unless tp.self.equal?(service) && tp.method_id == :apply
      calls += 1
      raise service::ApplyError, 'MR2B injected model Apply failure'
    end
    trace.enable
    result = yield
    [result, calls]
  ensure
    trace.disable if trace
  end

  def mr2b_prepare_pick_case(model, ctx)
    board = mr3b_board(model, ctx, ctx[:a], { 'L1' => ctx[:ae] })
    library = board.material
    foreign = mr1b2_op(model) do
      copy = model.entities.add_instance(board.definition, Geom::Transformation.translation(mr3a_point([9000, 0, 0])))
      copy.material = library
      copy
    end
    raise 'MR2B pending fixture' unless e::ScaleWatch.flush_pending!(model)
    model.materials.current = ctx[:source]
    before = mr3b_scene(model)
    foreign_before = mr3b_tree(foreign, exact: true)
    data = mr3b_data(board)
    library_before = mr1b1_state(library)
    catalog = File.binread(e::Materials.path)
    calls = { operation: 0, load: 0, current: 0 }
    trace = TracePoint.new(:call, :c_call) do |tp|
      calls[:operation] += 1 if tp.self.equal?(model) && tp.method_id == :start_operation
      calls[:load] += 1 if tp.self.equal?(e::NativeAppearance) && %i[load ensure].include?(tp.method_id)
      calls[:load] += 1 if tp.self.equal?(model.materials) && tp.method_id == :load
      calls[:current] += 1 if tp.self.equal?(model.materials) && tp.method_id == :current=
    end
    trace.enable
    begin
      sheet = mr2b_prepare(model, ctx)
      edge = mr2b_prepare(model, ctx, 'edge')
    ensure
      trace.disable
    end
    ok('MR2B Prepare: sheet aj ABS maju zivy native stav a fresh RGB',
       sheet.dig('state', 'mode') == 'native' && edge.dig('state', 'mode') == 'native' &&
       sheet.dig('state', 'color') == [100, 120, 140] && edge.dig('state', 'can_save'))
    ok("MR2B Prepare: bez load/current/operation #{calls.inspect}", calls.values.all?(&:zero?) &&
       mr3b_scene(model) == before && model.materials.current == ctx[:source] && File.binread(e::Materials.path) == catalog)
    ctx[:pick] = -> { nil }
    cancelled = mr2b_action(ctx, 'pick')
    ok('MR2B picker cancel: finalny ACK bez modelovej alebo kniznicnej zmeny',
       cancelled && cancelled['ok'] && mr3b_scene(model) == before && File.binread(e::Materials.path) == catalog)

    ctx[:pick] = -> { ctx[:paths][1] }
    first = mr2a_selection(model, board, 'MR2B prvy Pick') { mr2b_action(ctx, 'pick') }
    mr2b_required(first, 'first Pick')
    working = board.material
    visual = mr1b1_visual(working)
    pbr = mr1b1_visual(library).keys - %i[texture color alpha colorize_type colorize_deltas]
    ok('MR2B prvy Pick: novy W s novymi pixelmi a povodnou mierkou bez nasledneho size=',
       working != library && e::NativeAppearance.preferred(model, ctx[:scope], working) == working &&
       visual[:texture][2, 4] == ctx[:pixels][1] && visual[:texture][0, 2] == [180.mm.to_f, 90.mm.to_f])
    ok('MR2B prvy Pick: plne PBR mapy/faktory a alpha presli skutocnym SKM',
       visual.slice(*pbr) == mr1b1_visual(library).slice(*pbr) && working.alpha == library.alpha)
    ok('MR2B prvy Pick: cudzia zdielana geometria, R2 a vyrobne snapshoty presne',
       mr3b_tree(foreign, exact: true) == foreign_before && mr1b1_state(library) == library_before &&
       mr3b_data(board) == data && File.binread(e::Materials.path) == catalog)
    mr3a_check_part(board, 'MR2B first Pick', l: 0, w: 1, t: 2, material: working,
                      edge: ['L1', 1, :min], scale: [180.0, 90.0])
    post = mr3b_scene(model)
    mr2a_selection(model, board, 'MR2B Pick Undo') { Sketchup.undo }
    ok('MR2B controller Pick jeden Undo: W aj clone a mapovanie prec', mr3b_scene(model) == before)
    mr2a_selection(model, board, 'MR2B Pick Redo') { Sketchup.redo }
    ok('MR2B controller Pick jeden Redo: presny cely model', mr3b_scene(model) == post)

    old_user = mr1b2_op(model) do
      copy = model.entities.add_instance(board.definition, Geom::Transformation.translation(mr3a_point([11_000, 0, 0])))
      copy.material = working
      copy
    end
    e::ScaleWatch.flush_pending!(model)
    old_user_before = mr3b_tree(old_user, exact: true)
    old_working = mr1b1_state(working)
    ctx[:pick] = -> { ctx[:paths][0] }
    second = mr2a_selection(model, board, 'MR2B druhy Pick') { mr2b_action(ctx, 'pick') }
    mr2b_required(second, 'second Pick')
    fresh = board.material
    ok('MR2B druhy Pick: dalsi W, zmenene pixely, zachovana mierka a PBR',
       fresh != working && mr1b1_visual(fresh)[:texture][2, 4] == ctx[:pixels][0] &&
       mr1b1_visual(fresh)[:texture][0, 2] == [180.mm.to_f, 90.mm.to_f] &&
       mr1b1_visual(fresh).slice(*pbr) == visual.slice(*pbr))
    ok('MR2B druhy Pick: stary W a obaja cudzi pouzivatelia ostali byte-exact',
       mr1b1_state(working) == old_working && mr3b_tree(old_user, exact: true) == old_user_before &&
       mr3b_tree(foreign, exact: true) == foreign_before && mr3b_data(board) == data)
    mr3a_check_part(board, 'MR2B second Pick', l: 0, w: 1, t: 2, material: fresh,
                      edge: ['L1', 1, :min], scale: [180.0, 90.0])
    ctx.merge!(board: board, working: fresh, foreign: foreign, foreign_before: foreign_before,
               old_user: old_user, old_user_before: old_user_before)
  ensure
    trace.disable if trace
  end

  def mr2b_publish_case(model, ctx)
    board = ctx[:board]
    working = ctx[:working]
    visual = mr1b1_visual(working)
    model.materials.current = ctx[:other]
    before = mr3b_scene(model)
    failed, calls = mr2b_fail_apply { mr2b_action(ctx, 'save') }
    ok('MR2B Save: publikacia uspela, zlyhanie Apply ma finalny ACK a retry',
       calls == 1 && failed && !failed['ok'] && failed.dig('state', 'can_apply') &&
       failed['message'].include?('MR2B injected model Apply failure') && mr3b_scene(model) == before)
    published = e::Materials.sheet(ctx[:a]).fetch('appearance')
    catalog = File.binread(e::Materials.path)
    archive = File.binread(e::Materials.appearance_file(published['id']))
    # Po publikacii stary W moze zit na cudzej geometrii a zmenit sa.
    mr1b2_op(model) { working.alpha = 0.41 }
    retry_result = mr2a_selection(model, board, 'MR2B retry Apply') { mr2b_action(ctx, 'apply') }
    mr2b_required(retry_result, 'retry Apply')
    loaded = board.material
    ok('MR2B Save/retry: ulozeny captured W, nie current ani neskor zmeneny stary W',
       loaded != working && loaded != ctx[:other] && mr1b1_visual(loaded) == visual &&
       e::NativeAppearance.lookup(model, ctx[:scope], published['id']) == loaded)
    ok('MR2B retry: ta ista publikovana revizia bez druheho zapisu katalogu/SKM',
       File.binread(e::Materials.path) == catalog && File.binread(e::Materials.appearance_file(published['id'])) == archive &&
       !retry_result.dig('state', 'can_apply'))
    ok('MR2B Save/retry: cudzi pouzivatelia oboch starsich materialov ostali presne',
       mr3b_tree(ctx[:foreign], exact: true) == ctx[:foreign_before] &&
       mr3b_tree(ctx[:old_user], exact: true) == ctx[:old_user_before])

    reset, calls = mr2b_fail_apply { mr2b_action(ctx, 'reset') }
    ok('MR2B Reset: aj pri chybe Apply okamzite color descriptor a zabudnuty stary W',
       calls == 1 && reset && !reset['ok'] && reset.dig('state', 'mode') == 'color' &&
       e::Materials.sheet(ctx[:a]).dig('appearance', 'mode') == 'color' && !reset.dig('state', 'can_save'))
    edited = mr2a_selection(model, board, 'MR2B Edit po Reset') { mr2b_action(ctx, 'edit') }
    mr2b_required(edited, 'Edit after Reset')
    plain = board.material
    ok('MR2B Edit po Reset: novy plain W z RGB bez ozivenia stareho native source',
       plain != loaded && plain != working && plain.texture.nil? && plain.color.to_a.first(3) == [100, 120, 140] &&
       ctx[:editors].last == plain && model.materials.current == plain && edited.dig('state', 'can_save'))
    saved = mr2a_selection(model, board, 'MR2B plain Save') { mr2b_action(ctx, 'save') }
    mr2b_required(saved, 'plain Save')
    ok('MR2B plain W sa da ulozit ako native aj bez textury',
       e::Materials.sheet(ctx[:a]).dig('appearance', 'mode') == 'native' && board.material.texture.nil? &&
       board.material.color.to_a.first(3) == [100, 120, 140])
  end

  def mr2b_stale_color_case(model, ctx)
    mr2b_prepare(model, ctx)
    before = mr3b_scene(model)
    catalog = File.binread(e::Materials.path)
    ctx[:pick] = -> { e::MaterialsDialog.cancel_demos_on_leave; ctx[:paths][1] }
    stale = mr2b_action(ctx, 'pick')
    ok('MR2B leave pocas pickeru: bez noveho W, Apply, zapisu a neskorej odpovede',
       stale.nil? && mr3b_scene(model) == before && File.binread(e::Materials.path) == catalog)
    mr2b_prepare(model, ctx)
    current = model.materials.current
    descriptor = e::Materials.sheet(ctx[:a])['appearance']
    %w[old fresh].each do |revision|
      context = ctx[:envelope].merge('action_token' => SecureRandom.uuid)
      payload = { 'decor' => e::Materials.sheet(ctx[:a])['decor'], 'group_id' => ctx[:scope][0],
                  'color' => [31, 57, 89], 'catalog_schema' => e::Materials::SCHEMA_CURRENT,
                  'catalog_rev' => revision == 'old' ? 'known-stale-revision' : e::Materials.catalog_revision,
                  'appearance_context' => context }
      ctx[:sent].clear
      e::MaterialsDialog.dispatch('set_decor_color', payload.to_json, ctx[:sink])
      result = mr2b_reply(ctx, 'appearanceResult')
      ok("MR2B color #{revision}: finalny korelovany ACK aj pri odmietnuti",
         result && result['action'] == 'color' && result['action_token'] == context['action_token'] &&
         result['ok'] == (revision == 'fresh'))
    end
    ok('MR2B farba bez Save: sheet aj ABS RGB, native descriptor/model/current bez zmeny',
       e::Materials.sheet(ctx[:a])['color'] == [31, 57, 89] && e::Materials.edge(ctx[:ae])['color'] == [31, 57, 89] &&
       e::Materials.sheet(ctx[:a])['appearance'] == descriptor && mr3b_scene(model) == before && model.materials.current == current)
  end

  def run_mr2b(model)
    return ok('MR2B: povoleny testmodel', false) unless guard_model?(model)
    cleanup(model)
    keep, originals = model.entities.to_a, model.materials.to_a
    old_dir = e::Materials.test_dir_override
    studio = e::StudioDialog
    old_dialog, old_ready = studio.instance_variable_get(:@dialog), studio.instance_variable_get(:@ready)
    old_current = model.materials.current
    studio.instance_variable_set(:@dialog, MR2BDialog.new)
    studio.instance_variable_set(:@ready, true)
    Dir.mktmpdir('noxun-mr2b-su-') do |temp|
      e::Materials.test_dir_override = temp
      e::Materials.reload!
      e::Materials.load
      status, rows = e::Materials.add_decor_batch('batch_schema' => 3, 'decor' => 'SU MR2B A',
        'type' => 'DTDL', 'grain' => 'length', 'color' => [100, 120, 140],
        'sheet_variants' => [{ 'thickness' => 18.0, 'structure' => 'SM' }],
        'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'SM' }])
      raise rows.inspect unless status
      paths = %w[source picked].map { |name| File.join(temp, "#{name}.png") }
      pixels = [[255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 230, 150, 80, 255],
                [25, 80, 230, 255, 240, 210, 20, 255, 150, 50, 70, 255, 10, 190, 90, 255]]
      signatures = paths.zip(pixels).map do |path, bytes|
        image = Sketchup::ImageRep.new
        image.set_data(2, 2, 32, 0, bytes.pack('C*'))
        image.save_file(path)
        raise 'MR2B PNG fixture' unless File.file?(path) && File.size(path).positive?
        image = Sketchup::ImageRep.new(path) # Opaque raw32 -> emitted PNG24.
        [image.width, image.height, image.bits_per_pixel, Digest::SHA256.hexdigest(image.data)]
      end
      source, other = mr1b2_op(model) do
        material = model.materials.add('SU MR2B source')
        material.texture = paths[0]
        material.texture.size = [180.mm, 90.mm]
        material.alpha = 0.7
        if material.respond_to?(:roughness_factor=)
          material.metallic_factor = 0.35
          material.roughness_factor = 0.65
          material.normal_scale = 0.7
          material.ao_strength = 0.8
          %i[metallic_texture roughness_texture normal_texture ao_texture].each { |key| material.public_send("#{key}=", paths[0]) }
          %i[metalness_enabled roughness_enabled normal_enabled ao_enabled].each { |key| material.public_send("#{key}=", true) }
        end
        path = File.join(temp, 'source_canonical.skm')
        raise 'MR2B canonical source' unless material.save_as(path)
        model.materials.remove(material)
        material = model.materials.load(path)
        unrelated = model.materials.add('SU MR2B iny current')
        unrelated.color = [4, 15, 26]
        [material, unrelated]
      end
      ctx = { a: rows['sheets'].first, ae: rows['edges'].first, source: source, other: other,
              temp: temp, paths: paths, pixels: signatures, sent: [], editors: [] }
      ctx[:scope] = e::Materials.appearance_scope_key(e::Materials.sheet(ctx[:a]))
      ctx[:sink] = ->(script) { ctx[:sent] << script.to_s; true }
      mr1b2_publish(model, ctx[:a], source)
      mr2b_stub(e::MaterialsDialog, :appearance_pick_image, -> { ctx[:pick].call }) do
        mr2b_stub(e::MaterialsDialog, :appearance_open_editor, ->(origin, material) {
          ctx[:editors] << material
          origin.materials.current = material
          true
        }) do
          mr2b_prepare_pick_case(model, ctx)
          mr2b_publish_case(model, ctx)
          mr2b_stale_color_case(model, ctx)
        end
      end
    ensure
      e::MaterialsDialog.appearance_invalidate!
      mr3b_clear(model, keep)
      e::Materials.test_dir_override = old_dir
      e::Materials.reload!
      model.materials.current = old_current if old_current.nil? || old_current.valid?
      mr1b2_op(model) { (model.materials.to_a - originals).each { |mat| model.materials.remove(mat) if mat.valid? } }
    end
  rescue StandardError => error
    ok("MR2B: vynimka #{error.class}: #{error.message} @ #{Array(error.backtrace).first}", false)
  ensure
    if studio
      studio.instance_variable_set(:@dialog, old_dialog)
      studio.instance_variable_set(:@ready, old_ready)
    end
  end
end
