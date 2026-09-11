# frozen_string_literal: true
# MR-1B2: kratkozivy dokaz povodneho vzhladu. Nikdy nejde do configu ani katalogu.
require 'json'

module Noxun
  module Engine
    module BuildAppearance
      class CaptureError < Materials::AppearanceError; end
      SLOTS = %w[L1 L2 W1 W2].freeze
      module_function

      def classify(material)
        return :plain unless material
        return :unknown unless material.valid?
        if marked?(material)
          scope = JSON.parse(material.get_attribute('NOXUN', 'appearance_scope').to_s)
          revision = material.get_attribute('NOXUN', 'appearance_id')
          valid = scope.is_a?(Array) && scope.length == 2 && scope.all? { |s| s.is_a?(String) } &&
                  !scope.first.empty? && scope.all? { |s| Materials.identity_norm(s) == s } &&
                  revision.is_a?(String) && Materials::APPEARANCE_UUID.match?(revision)
          return valid ? :protected : :unknown
        end
        return :protected if material.texture || material.alpha.to_f != 1.0
        if material.respond_to?(:workflow)
          return :unknown unless defined?(Sketchup::Material::WORKFLOW_CLASSIC)
          return :protected unless material.workflow == Sketchup::Material::WORKFLOW_CLASSIC
        end
        :plain
      rescue StandardError
        :unknown # Neuspesne citanie nie je dokaz obycajnej farby.
      end

      def capture_cabinet(model, owner, target_id: nil)
        validate_owner!(model, owner, 'cabinet')
        cid = owner_id(owner)
        context = { model: model, owner: owner, owner_id: cid, target_id: target_id || cid,
                    parts: {}, unaddressable: [] }
        owner.definition.entities.grep(Sketchup::ComponentInstance).each do |part|
          next unless Store.kind(part) == 'part'
          next if Store.get(part, 'manufactured') == false || Store.get(part, 'production_class') == 'none'
          record = capture_part(part, owner.material)
          key = Store.get(part, 'part_key').to_s
          if key.empty? || record[:material_id].empty? || record[:role].empty? ||
             part.parent != owner.definition || Store.get(part, 'cabinet_id').to_s != cid
            context[:unaddressable] << record
          else
            (context[:parts][key] ||= []) << record
          end
        end
        context
      end

      def capture_board(model, owner)
        validate_owner!(model, owner, 'board')
        id = owner_id(owner)
        record = capture_part(owner)
        unaddressable = record[:material_id].empty? || record[:role].empty? ? [record] : []
        { model: model, owner: owner, owner_id: id, target_id: id,
          parts: { BoardBuilder::PART_KEY => [record] }, unaddressable: unaddressable }
      end

      # Volat aj pri prazdnom novom plane: neadresovatelny protected zdroj sa
      # nesmie stratit len preto, ze sa ziadny novy dielec nedopytal na preferenciu.
      def validate_context!(context, model:, owner:)
        return unless context
        unless context[:model] == model && context[:owner] == owner && owner && owner.valid? &&
               owner.model == model && owner_id(owner) == context[:target_id]
          raise CaptureError, 'Pôvodný vzhľad patrí inému objektu alebo dokumentu.'
        end
        if Array(context[:unaddressable]).any? { |record| protected_record?(record) }
          raise CaptureError, 'Pôvodný dielec s vlastným vzhľadom nemá jednoznačnú identitu.'
        end
        true
      end

      def for_part(context, model:, owner:, part_key:, role:, material_id:, edges:)
        out = { sheet: nil, edges: {} }
        return out unless context
        validate_context!(context, model: model, owner: owner)
        records = Array(context[:parts][part_key.to_s]).select { |r| r[:role] == role.to_s }
        sheets = records.select { |r| r[:material_id] == material_id.to_s }.map { |r| r[:sheet] }
        out[:sheet] = previous_channel(sheets, model, :sheet, material_id)
        SLOTS.each do |slot|
          id = edges.is_a?(Hash) ? edges[slot] : nil
          next if id.to_s.empty?
          candidates = records.filter_map do |r|
            edge = r[:edges][slot]
            edge[:channel] if edge && edge[:abs_id] == id.to_s
          end
          out[:edges][slot] = previous_channel(candidates, model, :edge, id)
        end
        out
      end

      # Mutujuci caller vlastni operaciu/guard. LoadError sa nesmie zmenit na
      # uspesny RGB rebuild: native load uz mohol kolekciu ciastocne zmenit.
      def resolve(model, kind, id, fallback_rgb, previous: nil)
        raise ArgumentError, 'Neznámy materiálový kanál.' unless %i[sheet edge].include?(kind)
        id = id.to_s
        rec = kind == :sheet ? Materials.sheet(id) : Materials.edge(id)
        previous = nil if Materials.uni?(rec)
        if previous
          unless previous[:model] == model && previous[:kind] == kind && previous[:id] == id
            raise CaptureError, 'Pôvodný vzhľad nemá zhodné výrobné ID.'
          end
          raise CaptureError, previous[:error] || 'Pôvodný vzhľad sa nedá jednoznačne zachovať.' if previous[:state] == :unknown
          material = previous[:material]
          own_material!(model, material) if material
          state = classify(material)
          raise CaptureError, 'Pôvodný materiál sa nedá bezpečne prečítať.' if state == :unknown
          return preserve!(model, kind, id, rec, previous) if state == :protected
        end
        if rec && !Materials.uni?(rec) && rec.key?('appearance')
          descriptor = Materials.normalize_appearance(rec['appearance'])
          if descriptor['mode'] == 'native'
            material = NativeAppearance.load(model, Materials.appearance_scope_key(rec), descriptor)
            return material if material
            Engine.log("Vzhľad #{id}: miestny súbor nie je dostupný, používa sa farba.")
          end
        end
        rgb = (kind == :sheet ? Materials.color_of(id) : Materials.edge_color_of(id)) || fallback_rgb
        plain_material(model, kind, id, rgb, previous && previous[:material])
      end

      def validate_owner!(model, owner, kind)
        unless Sketchup.active_model == model && owner && owner.valid? && owner.model == model && owner.parent == model &&
               Store.kind(owner) == kind && !owner_id(owner).empty?
          raise CaptureError, 'Zdroj vzhľadu už nie je platný objekt v tomto dokumente.'
        end
        owner
      end

      def owner_id(owner)
        Store.get(owner, Store.kind(owner) == 'cabinet' ? 'cabinet_id' : 'id').to_s
      end

      def marked?(material)
        !material.get_attribute('NOXUN', 'appearance_scope').nil? ||
          !material.get_attribute('NOXUN', 'appearance_id').nil?
      end

      def own_material!(model, material)
        unless material && material.valid? && material.model == model && model.materials.to_a.include?(material)
          raise CaptureError, 'Pôvodný materiál už nie je v tomto dokumente.'
        end
      end

      def preserve!(model, kind, id, rec, previous)
        material = previous[:material]
        if marked?(material)
          scope = rec ? Materials.appearance_scope_key(rec) : JSON.parse(material.get_attribute('NOXUN', 'appearance_scope'))
          return NativeAppearance.preferred(model, scope, material)
        end
        return material if owned_name?(material, kind, id)
        # Stara ABS mohla dedit texturu dosky: dokaz slotu poskytol capture,
        # samotna zhoda mena/farby alebo scope na cudzom diele nestaci.
        inherited = previous[:inherited_sheet_id]
        sheet = inherited && Materials.sheet(inherited)
        scope = Materials.appearance_scope_key(rec)
        if kind == :edge && inherited && owned_name?(material, :sheet, inherited) && scope &&
           Materials.appearance_scope_key(sheet) == scope
          return material
        end
        raise CaptureError, 'Pôvodný vzhľad nemá preukázanú väzbu na materiál dielca alebo ABS.'
      end

      def plain_material(model, kind, id, rgb, previous)
        name, alternative = material_names(kind, id)
        material = previous if previous && owned_name?(previous, kind, id) && classify(previous) == :plain
        material ||= [model.materials[name], model.materials[alternative]].compact.find { |m| classify(m) == :plain }
        material ||= model.materials.add(model.materials[name] ? alternative : name)
        color = material.color
        material.color = Sketchup::Color.new(*rgb) unless color && [color.red, color.green, color.blue] == rgb
        material
      end

      def material_names(kind, id)
        [kind == :sheet ? (id.empty? ? 'NOXUN_material' : id) : Materials.su_edge_material_name(id),
         "NOXUN_COLOR_#{kind}_#{id}"]
      end

      # Meno samo osebe nie je dokaz vlastnictva. Tento helper sa pri ochrane
      # pouziva LEN spolu s capture povodneho dielca/slotu a nezmeneneho ID.
      def owned_name?(material, kind, id)
        name, alternative = material_names(kind, id)
        material.name == name || /\A#{Regexp.escape(alternative)}(?:#\d+)?\z/.match?(material.name)
      end

      def previous_channel(channels, model, kind, id)
        return nil if channels.empty?
        if channels.length > 1
          raise CaptureError, 'Viac pôvodných dielcov má tú istú identitu vzhľadu.' if channels.any? { |c| c[:state] != :plain }
          return nil
        end
        channel = channels.first
        raise CaptureError, channel[:error] || 'Pôvodný vzhľad nie je jednoznačný.' if channel[:state] == :unknown
        channel.merge(model: model, kind: kind, id: id.to_s)
      end

      def protected_record?(record)
        record[:sheet][:state] != :plain || record[:edges].values.any? { |e| e[:channel][:state] != :plain }
      end

      def channel(materials, ambiguous: false)
        materials = materials.compact.uniq
        states = materials.map { |m| classify(m) }
        protected = materials.zip(states).select { |_m, state| state == :protected }.map(&:first)
        unknown = states.include?(:unknown) || protected.length > 1 || (ambiguous && !protected.empty?)
        { state: unknown ? :unknown : (protected.empty? ? :plain : :protected),
          material: protected.first || materials.first, inherited_sheet_id: nil,
          error: unknown ? 'Geometria alebo materiály pôvodného dielca nemajú jednoznačný vzhľad.' : nil }
      end

      def capture_part(part, inherited = nil)
        cfg = Store.config(part)
        cfg = {} unless cfg.is_a?(Hash)
        role = Store.get(part, 'role').to_s
        record = { role: role, material_id: cfg['material_id'].to_s, edges: {} }
        parent_material = part.material || inherited
        faces = part.definition.entities.grep(Sketchup::Face)
        all = [parent_material] + faces.flat_map { |f| [f.material, f.back_material] }
        bounds = part.definition.bounds
        lo = [bounds.min.x, bounds.min.y, bounds.min.z].map { |v| Units.to_mm(v) }
        hi = [bounds.max.x, bounds.max.y, bounds.max.z].map { |v| Units.to_mm(v) }
        box = hi.zip(lo).map { |high, low| high - low }
        ax = PartFaces.axes_for_snapshot(role, box, cfg)
        return ambiguous_record(record, cfg, all) if ax.nil?
        sides = faces.group_by { |f| face_side(f, lo, box) }
        decor = %i[min max].flat_map { |side| sides.fetch([ax[:thickness], side], []) }
        complete = %i[min max].all? { |side| sides.fetch([ax[:thickness], side], []).length == 1 }
        record[:sheet] = channel(complete ? effective_materials(decor, parent_material) : all, ambiguous: !complete)
        SLOTS.each do |slot|
          id = cfg['edges'][slot] if cfg['edges'].is_a?(Hash)
          edge_faces = sides.fetch(PartFaces.rect_axis_side(slot, ax, role), [])
          if id.to_s.empty?
            # Neolepena bocna plocha bude po rebuild dedit sheet. Vlastny
            # protected vzhlad na nej sa preto nesmie pri clear! stratit.
            lost = effective_materials(edge_faces, parent_material).compact.any? do |material|
              state = classify(material)
              state == :unknown || (state == :protected && material != record[:sheet][:material])
            end
            if lost
              record[:sheet] = record[:sheet].merge(state: :unknown,
                error: 'Neolepená plocha má vlastný vzhľad, ktorý sa pri prestavbe nedá zachovať.')
            end
            next
          end
          candidate = channel(edge_faces.length == 1 ? effective_materials(edge_faces, parent_material) : all,
                              ambiguous: edge_faces.length != 1)
          # Po prvom rebuild je povodne zdedeny sheet handle na ABS explicitny.
          # Dokaz preto drzi skutocny zhodny handle OBOCH stran a sheet kanala,
          # nie iba nil na ploche. Scope + mena este preveri preserve!.
          if edge_faces.length == 1 &&
             effective_materials(edge_faces, parent_material).uniq == [record[:sheet][:material]]
            candidate[:inherited_sheet_id] = record[:material_id]
          end
          record[:edges][slot] = { abs_id: id.to_s, channel: candidate }
        end
        # Plocha mimo kvadra sa pri rebuild maze tiez. Protected farbu na nej
        # nevieme priradit kanalu, preto ju nepustime cez uspesny RGB fallback.
        if sides.key?(nil) && channel(effective_materials(sides[nil], parent_material))[:state] != :plain
          record[:sheet] = channel(all, ambiguous: true)
        end
        record
      rescue StandardError => e
        # Nejasna geometria nie je dovod odmietnut stary jednofarebny model.
        # `all` existuje az PO uspesnom citani kazdeho materialoveho kanala.
        if all
          Engine.log("Zachytenie vzhľadu: nejasná geometria (#{e.message}).")
          return ambiguous_record(record, cfg, all)
        end
        raise CaptureError, "Pôvodný vzhľad sa nedá zachytiť: #{e.message}"
      end

      def ambiguous_record(record, cfg, materials)
        record[:sheet] = channel(materials, ambiguous: true)
        SLOTS.each do |slot|
          id = cfg['edges'][slot] if cfg['edges'].is_a?(Hash)
          record[:edges][slot] = { abs_id: id.to_s, channel: channel(materials, ambiguous: true) } unless id.to_s.empty?
        end
        record
      end

      def effective_materials(faces, parent_material)
        faces.flat_map { |f| [f.material || parent_material, f.back_material || parent_material] }
      end

      def face_side(face, lo, box)
        points = face.vertices.map { |v| [v.position.x, v.position.y, v.position.z].map { |p| Units.to_mm(p) } }
        (0..2).each do |axis|
          return [axis, :min] if points.all? { |p| (p[axis] - lo[axis]).abs <= PartFaces::TOL }
          return [axis, :max] if points.all? { |p| (p[axis] - lo[axis] - box[axis]).abs <= PartFaces::TOL }
        end
        nil
      end

      private_class_method :owner_id, :marked?, :own_material!, :preserve!, :plain_material,
                           :material_names, :owned_name?,
                           :previous_channel, :protected_record?, :channel, :capture_part,
                           :effective_materials, :face_side, :ambiguous_record
    end
  end
end
