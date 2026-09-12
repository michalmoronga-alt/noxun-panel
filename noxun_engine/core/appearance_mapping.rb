# frozen_string_literal: true
# MR-3A: lokalny ramec textury. Bez katalogu, vyberu revizie a vlastnej operacie.
module Noxun
  module Engine
    module AppearanceMapping
      class MappingError < Materials::AppearanceError; end
      SLOTS = %w[L1 L2 W1 W2].freeze
      module_function

      def inspect_part(instance, descriptor:)
        unless instance && instance.valid? && instance.definition.valid?
          raise MappingError, 'Dielec už nemá platnú definíciu.'
        end
        pd = normalized_descriptor(descriptor)
        definition = instance.definition
        entities = definition.entities.to_a
        faces = entities.grep(Sketchup::Face)
        edges = entities.grep(Sketchup::Edge)
        unless faces.length == 6 && edges.length == 12 && entities.length == 18 &&
               entities.all? { |entity| entity.valid? && entity.parent == definition }
          raise MappingError, 'Vzhľad podporuje iba čistý kváder so šiestimi plochami.'
        end
        vertices = edges.flat_map(&:vertices).uniq
        raise MappingError, 'Kváder nemá presne osem rohov.' unless vertices.length == 8
        positions = vertices.to_h do |vertex|
          p = vertex.position
          [vertex, [p.x.to_f, p.y.to_f, p.z.to_f].freeze]
        end
        PartFaces::AXIS_KEYS.each do |key|
          axis = pd[:axes][key]
          coordinates = positions.values.map { |point| Units.to_mm(point[axis]) }
          span = coordinates.max - coordinates.min
          unless span.finite? && (span - pd[:box][axis]).abs <= PartFaces::TOL &&
                 (span - pd[:prod][key]).abs <= PartFaces::TOL
            raise MappingError, 'Skutočné rozmery dielca nesedia s deskriptorom.'
          end
        end
        corners = positions.transform_values { |point| corner_code(point, pd[:box]) }
        raise MappingError, 'Rohy dielca nesedia s jeho rozmermi.' unless corners.values.uniq.length == 8
        sides = {}
        faces.each do |face|
          loop = face.outer_loop
          fv = face.vertices
          unless face.loops == [loop] && fv.length == 4 && fv.uniq.length == 4 &&
                 loop.vertices.length == 4 && loop.vertices.uniq.length == 4 &&
                 (loop.vertices - fv).empty? && face.edges.length == 4
            raise MappingError, 'Plocha dielca nie je jeden obdĺžnik bez dier.'
          end
          codes = fv.map { |vertex| corners.fetch(vertex) }
          axis = (0..2).find { |i| codes.map { |code| code[i] }.uniq.length == 1 }
          raise MappingError, 'Plocha neleží na stene kvádra.' unless axis
          side = [axis, codes.first[axis].zero? ? :min : :max]
          raise MappingError, 'Viac plôch patrí tej istej stene kvádra.' if sides.key?(side)
          sides[side] = face
        end
        edges.each do |edge|
          ev = edge.vertices
          adjacent = edge.faces
          unless ev.length == 2 && (0..2).count { |i| corners.fetch(ev[0])[i] != corners.fetch(ev[1])[i] } == 1 &&
                 adjacent.length == 2 && adjacent.uniq.length == 2 && (adjacent - faces).empty? &&
                 adjacent.all? { |face| face.edges.include?(edge) && (ev - face.vertices).empty? }
            raise MappingError, 'Hrany netvoria uzavretý obdĺžnikový kváder.'
          end
        end
        ax = pd[:axes]
        sheet = %i[min max].to_h { |side| [side, sides.fetch([ax[:thickness], side])] }.freeze
        abs = SLOTS.to_h { |slot| [slot, sides.fetch(PartFaces.rect_axis_side(slot, ax, pd[:role]))] }.freeze
        map = { model: instance.model, instance: instance, definition: definition, descriptor: pd,
                axes: ax, box: pd[:box], role: pd[:role], sheet: sheet, edges: abs,
                positions: positions.freeze }.freeze
        { status: :ok, map: map }
      rescue StandardError => e
        { status: :unsupported, reason: e.message }
      end

      def paint_part!(instance, map, grain:, bindings:)
        validate_map!(instance, map)
        unless %w[length width none].include?(grain.to_s)
          raise MappingError, 'Smer vzhľadu dielca nie je platný.'
        end
        unless bindings.is_a?(Hash) && (bindings.keys - %i[sheet edges]).empty?
          raise MappingError, 'Priradenia vzhľadu nemajú platný tvar.'
        end
        edge_bindings = bindings.fetch(:edges, {})
        unless edge_bindings.is_a?(Hash) && (edge_bindings.keys - SLOTS).empty?
          raise MappingError, 'Priradenia ABS nemajú platné hrany.'
        end
        plans = []
        ax = map[:axes]
        if bindings.key?(:sheet)
          u, v = grain.to_s == 'width' ? [ax[:width], ax[:length]] : [ax[:length], ax[:width]]
          map[:sheet].each_value { |face| plans << binding_plan(map, face, bindings[:sheet], false, u, v) }
        end
        edge_bindings.each do |slot, binding|
          unless binding.is_a?(Hash) && (binding.keys - %i[material inherit]).empty? &&
                 [true, false].include?(binding[:inherit])
            raise MappingError, 'Priradenie ABS nemá platný materiál alebo dedenie.'
          end
          u = slot.start_with?('L') ? ax[:length] : ax[:width]
          plans << binding_plan(map, map[:edges].fetch(slot), binding[:material], binding[:inherit], u, ax[:thickness])
        end
        # Vsetky handles, mierky aj body sa overia PRED prvym zapisom.
        plans.each do |plan|
          face, material, points = plan
          face.material = material
          face.back_material = material
          next unless points
          unless face.position_material(material, points, true)
            raise MappingError, 'Predná strana neprijala mapovanie textúry.'
          end
          unless face.position_material(material, points, false)
            raise MappingError, 'Zadná strana neprijala mapovanie textúry.'
          end
        end
        true
      rescue Materials::AppearanceError
        raise
      rescue StandardError => e
        raise MappingError, "Vzhľad dielca sa nepodarilo namapovať: #{e.message}"
      end

      def normalized_descriptor(descriptor)
        raise MappingError, 'Dielec nemá deskriptor.' unless descriptor.is_a?(Hash)
        box = descriptor[:box] || descriptor['box']
        prod = descriptor[:prod] || descriptor['prod']
        unless box.is_a?(Array) && box.length == 3 && box.all? { |v| positive_number?(v) } && prod.is_a?(Hash)
          raise MappingError, 'Rozmery dielca nie sú konečné kladné čísla.'
        end
        production = PartFaces::AXIS_KEYS.to_h do |key|
          value = prod.key?(key) ? prod[key] : prod[key.to_s]
          raise MappingError, 'Výrobné rozmery dielca nie sú platné.' unless positive_number?(value)
          [key, value.to_f]
        end
        ax = PartFaces.verified_axes(descriptor)
        raise MappingError, 'Osi dielca nesedia s výrobnými rozmermi.' unless ax
        { box: box.map(&:to_f).freeze, prod: production.freeze, axes: ax.freeze,
          role: (descriptor[:role] || descriptor['role']).to_s.dup.freeze }.freeze
      end

      def positive_number?(number)
        number.is_a?(Numeric) && number.to_f.finite? && number.to_f.positive?
      end

      def corner_code(point, box)
        point.each_with_index.map do |coordinate, axis|
          mm = Units.to_mm(coordinate)
          raise MappingError, 'Roh dielca nemá konečnú polohu.' unless mm.finite?
          distances = [mm.abs, (mm - box[axis]).abs]
          side = distances[0] <= distances[1] ? 0 : 1
          raise MappingError, 'Roh dielca neleží pri počiatku alebo rozmere kvádra.' if distances[side] > PartFaces::TOL
          side
        end.freeze
      end

      def validate_map!(instance, map)
        unless map.is_a?(Hash) && instance && instance.valid? && map[:instance] == instance &&
               map[:model] == instance.model && Sketchup.active_model == map[:model] &&
               map[:definition] == instance.definition
          raise MappingError, 'Mapa vzhľadu už nepatrí tomuto dielcu v aktuálnom dokumente.'
        end
        current = inspect_part(instance, descriptor: map[:descriptor])
        keys = %i[model instance definition axes box role sheet edges positions]
        unless current[:status] == :ok && keys.all? { |key| current[:map][key] == map[key] }
          raise MappingError, 'Geometria dielca sa od overenia vzhľadu zmenila.'
        end
      end

      def binding_plan(map, face, material, inherit, u, v)
        unless material && material.valid? && material.model == map[:model] &&
               map[:model].materials.to_a.include?(material)
          raise MappingError, 'Materiál vzhľadu nepatrí aktuálnemu dokumentu.'
        end
        if inherit
          unless material == map[:instance].material && BuildAppearance.classify(material) == :plain
            raise MappingError, 'ABS nemôže zdediť tento materiál dosky.'
          end
          return [face, nil, nil]
        end
        texture = material.texture
        return [face, material, nil] unless texture
        width, height = texture.width.to_f, texture.height.to_f
        unless width.finite? && height.finite? && width.positive? && height.positive?
          raise MappingError, 'Textúra nemá konečnú kladnú fyzickú mierku.'
        end
        # Body aj velkost textury su NATIVNE PALCE; ziadny druhy prevod mm.
        p0 = face.vertices.map { |vertex| map[:positions].fetch(vertex) }.min_by { |point| [point[u], point[v]] }.dup
        pu = p0.dup; pu[u] += width
        pv = p0.dup; pv[v] += height
        points = [Geom::Point3d.new(p0), Geom::Point3d.new(0, 0, 0),
                  Geom::Point3d.new(pu), Geom::Point3d.new(1, 0, 0),
                  Geom::Point3d.new(pv), Geom::Point3d.new(0, 1, 0)]
        [face, material, points]
      end

      private_class_method :normalized_descriptor, :positive_number?, :corner_code, :validate_map!, :binding_plan
    end
  end
end
