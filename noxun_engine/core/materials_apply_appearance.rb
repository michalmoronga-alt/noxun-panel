# frozen_string_literal: true
# MR-3B: jeden synchronny Apply na fyzicke vyskyty. Bez zapisov vyrobnych dat.
require 'json'

module Noxun
  module Engine
    module ApplyAppearance
      class ApplyError < Materials::AppearanceError; end
      class SkipError < StandardError
        attr_reader :reason
        def initialize(reason)
          @reason = reason
          super(reason.to_s)
        end
      end
      SLOTS = AppearanceMapping::SLOTS
      BEHAVIOR = %i[always_face_camera? cuts_opening? is2d? no_scale_mask? snapto shadows_face_sun?].freeze
      module_function

      # Pripravny blok bezi raz v tej istej operacii; nesmie otvorit dalsiu
      # operaciu, dialog ani export. Caller prebera material az po commite.
      def apply(model, scope:, material: nil)
        preparing = block_given?
        raise ApplyError, 'Zadaj materiál alebo prípravu vzhľadu, nie oboje.' if preparing && !material.nil?
        preparing ? context!(model, scope) : input!(model, scope, material)
        raise ApplyError, 'Model ešte dokončuje predchádzajúcu zmenu.' unless ScaleWatch.flush_pending!(model) == true
        preparing ? context!(model, scope) : input!(model, scope, material)
        members = Materials.with_catalog_lock { membership(Materials.appearance_fresh_catalog!) }
        if preparing
          raise ApplyError, 'Skupina vzhľadu už nie je v katalógu alebo je UNI.' unless members.value?(scope)
        else
          initial = scan(model, members, scope, material)
          return result([], initial[:skips]) if initial[:parts].empty?

          roots = initial[:parts].map { |part| part[:path].first }.uniq
          before = roots.to_h { |root| [root, [root.definition, content(root, strict: false)]] }
          input!(model, scope, material)
          initial[:parts].each { |part| verify_plan!(part) }
          verify_roots!(model, before, identities: true)
        end
        ScaleWatch.guard do
          started = false
          begin
            # Nested make_unique kopiruje aj DC atributy. disable_ui=true pri
            # tomto clone vypina selection eventy (D-40); guard ostava aktivny.
            raise ApplyError, 'Operácia vzhľadu sa nedá otvoriť.' unless model.start_operation('Použiť vzhľad', false) == true
            started = true
            if preparing
              context!(model, scope, guarded: true)
              material = yield
              input!(model, scope, material, guarded: true)
              initial = scan(model, members, scope, material)
              roots = initial[:parts].map { |part| part[:path].first }.uniq
              before = roots.to_h { |root| [root, [root.definition, content(root, strict: false)]] }
            end
            input!(model, scope, material, guarded: true)
            initial[:parts].each { |part| verify_plan!(part) }
            verify_roots!(model, before, identities: true)
            roots.each do |root|
              plans = initial[:parts].select { |part| part[:path].first == root }
              isolate!(root, [root], plans, members, scope, material)
            end
            # Ziadny paint pred obsahovym dokazom VSETKYCH oddelenych vetiev.
            verify_roots!(model, before, identities: false)
            final = scan(model, members, scope, material, roots: roots)
            unless target_content(final[:parts]) == target_content(initial[:parts])
              raise ApplyError, 'Po oddelení komponentov sa zmenili cieľové dielce.'
            end
            final[:parts].each do |part|
              input!(model, scope, material, guarded: true)
              verify_plan!(part)
              part[:pins].each { |face, front, handle| front ? face.material = handle : face.back_material = handle }
              part[:instance].material = material if part[:sheet]
              bindings = { edges: part[:edges].to_h { |slot| [slot, { material: material, inherit: false }] } }
              bindings[:sheet] = material if part[:sheet]
              AppearanceMapping.paint_part!(part[:instance], part[:map], grain: part[:snapshot]['grain_direction'], bindings: bindings)
            end
            raise ApplyError, 'Operácia vzhľadu sa nepotvrdila.' unless model.commit_operation == true
            started = false
            out = result(final[:parts], initial[:skips])
            out[:material] = material if preparing
            out
          ensure
            # Aj break/return/throw z pripravy musi vratit cely pokus pod guardom.
            if started
              raise ApplyError, 'Obnova modelu po chybe vzhľadu zlyhala.' unless model.abort_operation == true
            end
          end
        end
      rescue ApplyError
        raise
      rescue StandardError => e
        raise ApplyError, "Vzhľad sa nepoužil: #{e.message}"
      end

      def input!(model, scope, material, guarded: false)
        context!(model, scope, guarded: guarded)
        own_material!(model, material)
        # Existujuci dokaz presneho scope, tuple a lookup == dodany handle.
        # Nevybera reviziu, nenacitava material ani nevyzaduje rebuild kontext.
        NativeAppearance.preferred(model, scope, material) unless BuildAppearance.classify(material) == :plain
        texture = material.texture
        if texture && ![texture.width.to_f, texture.height.to_f].all? { |value| value.finite? && value.positive? }
          raise ApplyError, 'Textúra nemá konečnú kladnú fyzickú mierku.'
        end
      end

      def context!(model, scope, guarded: false)
        raise ApplyError, 'Model už nie je aktívny.' unless model && Sketchup.active_model == model
        raise ApplyError, 'Zatvor editáciu komponentu a skús znova.' unless model.active_path.nil? || model.active_path.empty?
        raise ApplyError, 'Prebieha zmena modelu.' if !guarded && ScaleWatch.rebuilding?
        unless scope.is_a?(Array) && scope.length == 2 && scope.all? { |s| s.is_a?(String) && Materials.identity_norm(s) == s } && !scope.first.empty?
          raise ApplyError, 'Skupina vzhľadu nie je platná.'
        end
      end

      def own_material!(model, material)
        unless material && material.valid? && material.model == model && model.materials.to_a.include?(material)
          raise ApplyError, 'Materiál už nie je platný alebo patrí inému modelu.'
        end
      end

      def membership(catalog)
        Materials.appearance_rows(catalog).to_h { |kind, id, rec| [[kind, id], Materials.appearance_scope_key(rec)] }
      end

      def scan(model, members, scope, material, roots: nil)
        out = { parts: [], skips: [] }
        (roots || children(model.entities)).each { |root| walk(root, [root], members, scope, material, out) }
        out[:parts] = out[:parts].select do |part|
          first_shared = part[:path].index { |node| shared?(node) }
          begin
            if first_shared
              inherited = inherited_material(part[:path][0...first_shared])
              content(part[:path][first_shared], inherited: inherited)
            end
            true
          rescue SkipError
            out[:skips] << skip_record(part[:instance], part[:owner], :unsupported_clone_content)
            false
          end
        end
        out
      end

      def walk(instance, path, members, scope, material, out)
        case Store.kind(instance)
        when nil, ''
          children(instance.definition.entities).each { |child| walk(child, path + [child], members, scope, material, out) }
        when 'cabinet'
          parts = children(instance.definition.entities).select { |child| Store.kind(child) == 'part' }
          return unless parts.any? { |part| relevant?(part, members, scope) }
          cfg = config!(instance)
          schema!(cfg['config_schema'], CabinetBuilder::CONFIG_SCHEMA)
          schema!(cfg['part_key_schema'], PartKeys::SCHEMA)
          schema!(Store.get(instance, 'part_key_schema'), PartKeys::SCHEMA)
          raise SkipError, :detached unless cfg['mode'] == 'parametric'
          cid = Store.get(instance, 'cabinet_id')
          raise SkipError, :invalid_owner unless text?(cid) && Store.get(instance, 'id') == cid
          keys = parts.map { |part| Store.get(part, 'part_key') }.tally
          parts.each do |part|
            next unless relevant?(part, members, scope)
            begin
              raise SkipError, :duplicate_part_key unless keys[Store.get(part, 'part_key')] == 1
              plan = plan_part(part, path: path + [part], owner: instance, membership: members, scope: scope, material: material)
              out[:parts] << plan if plan
            rescue SkipError => e
              out[:skips] << skip_record(part, instance, e.reason)
            end
          end
        when 'board'
          return unless relevant?(instance, members, scope)
          plan = plan_part(instance, path: path, owner: instance, membership: members, scope: scope, material: material)
          out[:parts] << plan if plan
        when 'part'
          out[:skips] << skip_record(instance, nil, :missing_owner) if relevant?(instance, members, scope)
        when 'hardware', 'proxy', 'reference'
          # Cudzia vyrobna vetva je paint bariera, nie zdroj cielov.
        else
          out[:skips] << skip_record(instance, instance, :unsupported_kind) if relevant?(instance, members, scope)
        end
      rescue SkipError => e
        out[:skips] << skip_record(instance, instance, e.reason)
      end

      def relevant?(instance, members, scope)
        cfg = config!(instance)
        members[['sheet', cfg['material_id']]] == scope ||
          (cfg['edges'].is_a?(Hash) && cfg['edges'].values.any? { |id| id && members[['edge', id]] == scope })
      rescue SkipError
        # Poskodeny NOXUN snapshot sa prizna ako neoveritelny, nie ako iny scope.
        %w[board part].include?(Store.kind(instance))
      end

      def plan_part(instance, path:, owner:, membership:, scope:, material:)
        cfg = config!(instance)
        board = Store.kind(instance) == 'board'
        schema!(Store.get(instance, 'part_key_schema'), PartKeys::SCHEMA)
        raise SkipError, :invalid_snapshot unless %w[length width thickness].all? { |key| positive?(cfg[key]) } &&
          %w[length width none].include?(cfg['grain_direction']) && text?(cfg['material_id']) &&
          cfg['edges'].is_a?(Hash) && cfg['edges'].keys.sort == SLOTS.sort &&
          cfg['edges'].values.all? { |id| id.nil? || text?(id) }
        id = Store.get(instance, 'id')
        role = Store.get(instance, 'role')
        key = Store.get(instance, 'part_key')
        raise SkipError, :invalid_identity unless instance.is_a?(Sketchup::ComponentInstance) && text?(id) &&
          Store.get(instance, 'part_id') == id && text?(key) && Store.get(instance, 'manufactured') == true &&
          Store.get(instance, 'production_class') == 'sheet' && BuildPlan::ROLES.include?(role) &&
          (!cfg.key?('role') || cfg['role'] == role)
        if board
          schema!(cfg['config_schema'], BoardBuilder::BOARD_CONFIG_SCHEMA)
          raise SkipError, :invalid_identity unless owner == instance && key == BoardBuilder::PART_KEY &&
            BoardBuilder::ROLES.include?(role) && cfg['role'] == role
        else
          raise SkipError, :invalid_owner unless path[-2] == owner && instance.parent == owner.definition &&
            Store.get(instance, 'cabinet_id') == Store.get(owner, 'cabinet_id')
        end
        raise SkipError, :missing_material unless membership.key?(['sheet', cfg['material_id']])
        sheet = membership[['sheet', cfg['material_id']]] == scope
        edges = SLOTS.select { |slot| cfg['edges'][slot] && membership[['edge', cfg['edges'][slot]]] == scope }
        return nil unless sheet || !edges.empty?
        path_state = path_state!(path)
        bounds = instance.definition.bounds
        box = [bounds.max.x - bounds.min.x, bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z].map { |n| Units.to_mm(n) }
        axes = board ? PartFaces::AXES_LYING : PartFaces.axes_for_snapshot(role, box, cfg)
        inspected = AppearanceMapping.inspect_part(instance, descriptor: { role: role, axes: axes, box: box, prod: cfg })
        raise SkipError, :unsupported_geometry unless inspected[:status] == :ok
        map = inspected[:map]
        inherited = inherited_material(path)
        bindings = (map[:sheet].values + map[:edges].values).to_h do |face|
          explicit = [face.material, face.back_material]
          effective = explicit.map { |handle| handle || inherited }
          effective.compact.each { |handle| own_material!(instance.model, handle) }
          [face, [explicit, effective]]
        end
        pins = preservation!(instance, cfg, map, bindings, sheet, edges, material)
        { instance: instance, path: path, owner: owner, snapshot: cfg, map: map, sheet: sheet, edges: edges, pins: pins,
          state: [path_state, content(instance, inherited: inherited_material(path[0...-1]))] }
      rescue JSON::ParserError, TypeError, ArgumentError
        raise SkipError, :invalid_snapshot
      end

      def preservation!(instance, cfg, map, bindings, sheet, edges, material)
        return [] unless sheet
        old_sheet = map[:sheet].values.flat_map { |face| bindings.fetch(face)[1] }.uniq
        pins = []
        map[:edges].each do |slot, face|
          explicit, effective = bindings.fetch(face)
          if cfg['edges'][slot].nil?
            if explicit.compact.any? { |handle| BuildAppearance.classify(handle) != :plain && old_sheet == [handle] && handle != material }
              raise SkipError, :unpreservable_raw_appearance
            end
          elsif !edges.include?(slot) && instance.material != material
            [true, false].each_with_index do |front, index|
              next if explicit[index]
              handle = effective[index]
              raise SkipError, :unpreservable_inheritance if handle.nil? || handle.texture
              pins << [face, front, handle]
            end
          end
        end
        pins
      end

      def config!(instance)
        raw = Store.get(instance, 'config')
        raise SkipError, :invalid_snapshot unless raw.is_a?(String)
        cfg = JSON.parse(raw)
        raise SkipError, :invalid_snapshot unless cfg.is_a?(Hash)
        cfg
      rescue JSON::ParserError
        raise SkipError, :invalid_snapshot
      end

      def schema!(value, current)
        return if value.nil?
        raise SkipError, :invalid_schema unless value.is_a?(Integer) && value >= 0
        raise SkipError, :newer_config if value > current
      end

      def path_state!(path)
        path.each_with_index.map do |node, index|
          parent = index.zero? ? node.model : path[index - 1].definition
          raise SkipError, :stale_path unless node.valid? && node.definition.valid? && node.parent == parent &&
            (index.zero? ? node.model.entities : parent.entities).to_a.include?(node)
          raise SkipError, :locked if node.locked?
          raise SkipError, :nonrigid_transform unless rigid?(node.transformation.to_a)
          [node, node.definition, parent, instance_fields(node, inherited_material(path[0...index]))]
        end
      rescue SkipError
        raise
      rescue StandardError
        raise SkipError, :unsupported_clone_content
      end

      def rigid?(values)
        return false unless values.is_a?(Array) && values.length == 16 && values.all? { |v| v.is_a?(Numeric) && v.to_f.finite? }
        tol = CabinetBuilder::RIGID_TOL
        return false unless (values[15] - 1).abs <= tol && [3, 7, 11].all? { |i| values[i].abs <= tol }
        x, y, z = [0, 4, 8].map { |i| values[i, 3] }
        dot = ->(a, b) { a.zip(b).sum { |u, v| u * v } }
        return false unless [x, y, z].all? { |v| (dot.call(v, v) - 1).abs <= tol } &&
          [[x, y], [x, z], [y, z]].all? { |a, b| dot.call(a, b).abs <= tol }
        cross = [y[1] * z[2] - y[2] * z[1], y[2] * z[0] - y[0] * z[2], y[0] * z[1] - y[1] * z[0]]
        (dot.call(x, cross).abs - 1).abs <= tol
      end

      def verify_plan!(part)
        current = [path_state!(part[:path]), content(part[:instance], inherited: inherited_material(part[:path][0...-1]))]
        raise ApplyError, 'Dielec sa od overenia vzhľadu zmenil.' unless current == part[:state]
      end

      def verify_roots!(model, before, identities:)
        before.each do |root, (definition, state)|
          unless root.valid? && root.model == model && root.parent == model && model.entities.to_a.include?(root) &&
                 (!identities || root.definition == definition) && content(root, strict: false) == state
            raise ApplyError, 'Obsah cieľovej vetvy sa od overenia zmenil.'
          end
        end
      end

      def isolate!(instance, path, plans, members, scope, material)
        if shared?(instance)
          input!(instance.model, scope, material, guarded: true)
          inherited = inherited_material(path[0...-1])
          before = content(instance, inherited: inherited)
          instance.make_unique
          unless !shared?(instance) && content(instance, inherited: inherited) == before
            raise ApplyError, 'Oddelenie komponentu nezachovalo pôvodný obsah.'
          end
          # Stare potomky sa nepáruju: cerstvy traversal cez novu definiciu.
          plans = scan(instance.model, members, scope, material, roots: [path.first])[:parts]
        end
        children(instance.definition.entities).each do |child|
          branch = plans.select { |plan| plan[:path][0, path.length] == path && plan[:path][path.length] == child }
          isolate!(child, path + [child], branch, members, scope, material) unless branch.empty?
        end
      end

      def shared?(instance)
        instance.definition.instances.count(&:valid?) > 1
      end

      def children(entities)
        entities.to_a.select { |entity| entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group) }
      end

      def inherited_material(path)
        path.reverse_each { |node| return node.material if node.material }
        nil
      end

      def counts(parts)
        [parts.length, parts.count { |part| part[:sheet] }, parts.sum { |part| part[:edges].length }]
      end

      def target_content(parts)
        parts.map do |part|
          [part[:state][0].map(&:last), part[:state][1], part[:sheet], part[:edges]]
        end.tally
      end

      def result(parts, skips)
        total, sheets, edges = counts(parts)
        { status: total.zero? ? :nothing_to_apply : :applied, updated_parts: total, updated_sheets: sheets,
          updated_edges: edges, skipped_parts: skips.length, skips: skips }
      end

      def skip_record(instance, owner, reason)
        { owner_id: owner && (Store.get(owner, 'cabinet_id') || Store.get(owner, 'id')),
          part_key: Store.get(instance, 'part_key'), name: Store.get(instance, 'name') || instance.name, reason: reason }
      end

      def text?(value)
        value.is_a?(String) && !value.strip.empty?
      end

      def positive?(value)
        value.is_a?(Numeric) && value.to_f.finite? && value.positive?
      end

      # Hodnotovy dokaz clone, nie serializer modelu. Bez PID a poradia deti.
      # Neznamy obsah smie ostat opaque IBA mimo nevyhnutnej clone vetvy.
      def content(instance, inherited: nil, strict: true)
        definition = instance.definition
        effective = instance.material || inherited
        entities = definition.entities.to_a
        edges = entities.grep(Sketchup::Edge)
        geometry = entities.map do |entity|
          raise SkipError, :unsupported_clone_content unless entity.valid? && entity.parent == definition
          case entity
          when Sketchup::ComponentInstance, Sketchup::Group
            content(entity, inherited: effective, strict: strict)
          when Sketchup::Face
            [:face, drawing_fields(entity), face_geometry(entity), entity.back_material,
             entity.material || effective, entity.back_material || effective, face_uv(entity, true), face_uv(entity, false)]
          when Sketchup::Edge
            [:edge, drawing_fields(entity), edge_geometry(entity), entity.soft?, entity.smooth?,
             entity.faces.map { |face| face_geometry(face) }.tally, curve_content(entity.curve)]
          else
            raise SkipError, :unsupported_clone_content if strict
            [:opaque, entity]
          end
        rescue StandardError
          raise SkipError, :unsupported_clone_content if strict
          # Tento objekt sa neklonuje. Jeho ziva identita musi zostat rovnaka.
          [:opaque, entity]
        end
        topology = topology_content(edges, strict)
        freeze_content([instance.is_a?(Sketchup::Group) ? :group : :component, instance_fields(instance, inherited),
         attributes(definition), definition.group?, definition.image?,
         BEHAVIOR.map { |method| definition.behavior.public_send(method) }, geometry.tally, topology])
      rescue SkipError
        raise
      rescue StandardError
        raise SkipError, :unsupported_clone_content
      end

      def topology_content(edges, strict)
        vertices = edges.flat_map(&:vertices).uniq
        positions = vertices.map { |vertex| point(vertex.position) }
        raise SkipError, :unsupported_clone_content unless positions.uniq.length == vertices.length
        vertices.map do |vertex|
          [point(vertex.position), attributes(vertex), vertex.edges.map { |edge| edge_geometry(edge) }.tally,
           vertex.faces.map { |face| face_geometry(face) }.tally]
        end.tally
      rescue StandardError
        raise SkipError, :unsupported_clone_content if strict
        [:opaque_topology, edges.tally]
      end

      def freeze_content(value)
        case value
        when Array then value.each { |item| freeze_content(item) }.freeze
        when Hash then value.each { |key, item| freeze_content(key); freeze_content(item) }.freeze
        when String then value.freeze
        end
        value
      end

      def instance_fields(instance, inherited)
        # Odkaz na lepiacu plochu nie je obsahova identita cez clone.
        raise SkipError, :unsupported_clone_content if instance.respond_to?(:glued_to) && instance.glued_to
        [drawing_fields(instance), instance.name.dup, numbers(instance.transformation.to_a), instance.locked?, instance.material || inherited]
      end

      def drawing_fields(entity)
        layer = entity.layer
        folders = []
        folder = layer.folder
        while folder
          folders << [folder, folder.name.dup, folder.visible?]
          folder = folder.folder
        end
        [attributes(entity), entity.material, entity.hidden?, [layer, layer.name.dup, layer.visible?, folders],
         entity.casts_shadows?, entity.receives_shadows?]
      end

      def attributes(entity)
        (entity.attribute_dictionaries || []).to_h do |dictionary|
          [dictionary.name.dup.freeze, dictionary.to_h.transform_values { |value| attribute_value(value) }.freeze]
        end.freeze
      end

      def attribute_value(value)
        case value
        when NilClass, TrueClass, FalseClass, Integer then value
        when Float then numbers([value]).first
        when String, Time then value.dup.freeze
        when Array then value.map { |item| attribute_value(item) }.freeze
        when Geom::Point3d then [:point, point(value)].freeze
        when Geom::Vector3d then [:vector, point(value)].freeze
        else
          return [:length, numbers([value.to_f]).first].freeze if defined?(Length) && value.is_a?(Length)
          raise SkipError, :unsupported_clone_content
        end
      end

      def numbers(values)
        raise SkipError, :unsupported_clone_content unless values.all? do |value|
          (value.is_a?(Numeric) || (defined?(Length) && value.is_a?(Length))) && value.to_f.finite?
        end
        values.map(&:to_f).freeze
      end

      def point(value)
        numbers([value.x, value.y, value.z])
      end

      def face_geometry(face)
        loops = face.loops.map do |loop|
          points = loop.vertices.map { |vertex| point(vertex.position) }
          cycle = points.each_index.map { |index| points.rotate(index) }.min
          [loop == face.outer_loop, cycle]
        end.tally
        # Rovina je urcena presnymi vrcholmi a normalou. Native clone moze
        # nanovo normalizovat redundantne face.plane koeficienty o 1 ULP.
        [point(face.normal), loops]
      end

      def edge_geometry(edge)
        edge.vertices.map { |vertex| point(vertex.position) }.sort
      end

      def curve_content(curve)
        return nil unless curve
        base = [attributes(curve), curve.edges.map { |edge| edge_geometry(edge) }.tally, curve.is_polygon?]
        if curve.is_a?(Sketchup::ArcCurve)
          [:arc, base, point(curve.center), point(curve.normal), point(curve.xaxis), point(curve.yaxis),
           numbers([curve.radius, curve.start_angle, curve.end_angle]), curve.circular?]
        elsif curve.instance_of?(Sketchup::Curve)
          [:curve, base]
        else
          raise SkipError, :unsupported_clone_content
        end
      end

      def face_uv(face, front)
        positioned = face.texture_positioned?(front)
        projected = face.texture_projected?(front)
        projection = face.get_texture_projection(front)
        material = front ? face.material : face.back_material
        samples = nil
        if (material && material.texture) || positioned || projected
          points = face.vertices.map { |vertex| point(vertex.position) }.sort
          center = (0..2).map { |axis| points.sum { |p| p[axis] } / points.length }
          helper = face.get_UVHelper(front, !front)
          samples = (points + [center]).map do |position|
            at = Geom::Point3d.new(position)
            uvq = point(front ? helper.get_front_UVQ(at) : helper.get_back_UVQ(at))
            raise SkipError, :unsupported_clone_content if uvq[2].zero?
            [position, uvq]
          end
        end
        [positioned, projected, projection && point(projection), samples]
      end

      private_class_method(*(singleton_methods(false) - [:apply]))
    end
  end
end
