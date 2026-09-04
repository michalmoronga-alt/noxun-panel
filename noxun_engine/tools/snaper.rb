# frozen_string_literal: true
# Noxun Engine — NASTROJE-1: SketchUp vrstva nastroja Snaper.
# Prisunie oznaceny objekt po jeho VLASTNEJ osi X na doraz k najblizsej prekazke.
#
# Vypocet (AABB sweep, verdikty, prahy) je v cistom jadre `snap_calc.rb`; tu sa
# len zbiera geometria a rozhoduje VIDITELNOST.
#
# VIDITELNOST (outside-in packet): primarne `Model#drawing_element_visible?`
# (od SU 2020.0; pozna aj skryte tagy, tag priecinky a nastavenia modelu).
# PRED SU 2026.0 vsak metoda HADZE VYNIMKU, ked je poslednym prvkom cesty
# skupina/komponent — a Snaper prechadza prave kontajnery. Fallback (`hidden?`
# + `layer.visible?` + skryty tag priecinok po CELEJ ceste) je tam teda BEZNA
# cesta, nie okrajova vetva.
module Noxun
  module Engine
    module Tools
      module Snaper
        MSG_NO_OBSTACLE = 'Snaper: v smere nie je žiadna prekážka — presun zablokovaný.'
        MSG_TOUCHING    = 'Snaper: skrinka už je na doraz.'

        class << self
          def snap(dir)
            model = Tools.active_model
            return nil unless model

            target = Tools.pick_target(model)
            return nil unless target

            route = Tools.route(model, target)
            return nil if Tools.refused_context?(route)

            noxun = Tools.noxun_route?(route)
            return nil if noxun && !Tools.settle!(model, target)

            gap_mm = nearest_gap(model, target, dir)
            vec = world_vector(target, gap_mm, dir)
            dist_mm = vec ? Units.to_mm(vec.length) : nil

            case SnapCalc.verdict(gap_mm, dist_mm)
            when :none then return Tools.warn(MSG_NO_OBSTACLE)
            when :touching then return Tools.info(MSG_TOUCHING)
            when :too_far
              return Tools.warn(format('Snaper: najbližšia prekážka je %.1f m ďaleko — presun zablokovaný.',
                                       dist_mm / 1000.0))
            end

            label = dir.to_sym == :left ? 'Noxun: Prisunúť vľavo' : 'Noxun: Prisunúť vpravo'
            moved = Tools.mutate(model, target, label, noxun) do
              target.transform!(Geom::Transformation.translation(vec))
            end
            return nil unless moved

            if dist_mm > SnapCalc::WARN_MM
              Tools.warn(format('Snaper: prisunuté o %.1f m — skontroluj, či to bol zámer.', dist_mm / 1000.0))
            else
              Tools.info(format('Snaper: prisunuté o %d mm.', dist_mm.round))
            end
          rescue StandardError => e
            Engine.log_error(e, 'Tools::Snaper.snap')
            Tools.warn('Snaper: chyba pri presune — detail v Ruby konzole.')
            nil
          end

          private

          # Volny priestor (mm) po lokalnej osi X ciela; `nil` = v smere nic nie je.
          def nearest_gap(model, target, dir)
            inv = target.transformation.inverse
            t_box = target_box(model, target)
            nodes = obstacle_nodes(model, model.entities, inv, [], target, t_box, dir.to_sym, 0)
            SnapCalc.nearest_gap(t_box, nodes, dir)
          end

          # Vektor posunu vo SVETE. Transformacia ciela pridava jeho rotaciu (a pri
          # cudzej skalovanej instancii aj mierku), takze svetova vzdialenost sedi.
          def world_vector(target, gap_mm, dir)
            return nil if gap_mm.nil?

            Units.vector(MowerCalc.sign(dir) * gap_mm, 0, 0).transform(target.transformation)
          end

          # --- prekazky ----------------------------------------------------------
          # Obalka KONTAJNERA sa odvodzuje REKURZIVNE z jeho VIDITELNYCH listov
          # (kolo 3 P2). Surove `definition.bounds` by nieslo aj SKRYTU geometriu
          # — skryty vnuk vo viditelnej skupine by potom zastavil prisunutie skor,
          # nez treba. Listy su PLOCHY: hrany su ich sucastou a kvader nimi
          # vymedzeny nie je.
          #
          # LACNY PREDVYBER: `definition.bounds` je NADMNOZINA viditelnej obalky,
          # takze kontajner, ktory sa nou nekryje s cielom v hlbke/vyske alebo lezi
          # cely ZA veducim okrajom, sa nemusi prechadzat vobec.
          def obstacle_nodes(model, entities, to_local, path, target, t_box, dir, depth)
            out = []
            entities.each do |ent|
              next if target && ent.equal?(target)
              next unless visible?(model, path + [ent])

              node =
                if container?(ent)
                  container_node(model, ent, to_local, path, t_box, dir, depth)
                elsif ent.is_a?(Sketchup::Face)
                  { box: box_mm(transform_bounds(ent.bounds, to_local)), container: false }
                end
              out << node if node
            end
            out
          rescue StandardError => e
            Engine.log_error(e, 'Tools::Snaper.obstacle_nodes')
            out || []
          end

          def container_node(model, ent, to_local, path, t_box, dir, depth)
            child_tr = to_local * ent.transformation
            outer = box_mm(transform_bounds(ent.definition.bounds, child_tr))
            return nil unless relevant?(outer, t_box, dir)
            # Na strope hlbky sa uz nezanorujeme — plati vonkajsia obalka.
            return { box: outer, container: false } if depth >= SnapCalc::MAX_DEPTH

            kids = obstacle_nodes(model, ent.definition.entities, child_tr, path + [ent],
                                  nil, t_box, dir, depth + 1)
            return nil if kids.empty?

            { box: union_box(kids), container: true, children: kids }
          end

          # Moze tento uzol vobec nieco ovplyvnit? Testuje sa nad NADMNOZINOU
          # (vonkajsou obalkou), takze zamietnutie je vzdy bezpecne.
          def relevant?(box, t_box, dir)
            return false unless SnapCalc.overlap_1d(box[:min][1], box[:max][1], t_box[:min][1], t_box[:max][1])
            return false unless SnapCalc.overlap_1d(box[:min][2], box[:max][2], t_box[:min][2], t_box[:max][2])

            if dir == :right
              box[:max][0] > t_box[:max][0] - SnapCalc::EPS_MM
            else
              box[:min][0] < t_box[:min][0] + SnapCalc::EPS_MM
            end
          end

          def union_box(nodes)
            lo = nodes.map { |n| n[:box][:min] }
            hi = nodes.map { |n| n[:box][:max] }
            { min: (0..2).map { |i| lo.map { |v| v[i] }.min },
              max: (0..2).map { |i| hi.map { |v| v[i] }.max } }
          end

          # --- obalka CIELA -------------------------------------------------------
          # TOU ISTOU visibility-aware traverzou ako prekazky (audit 2 FIX 6):
          # legacy bral surove `definition.bounds`, takze SKRYTY presahujuci
          # potomok (napr. proxy kovania na vypnutom tagu) posuval doraz.
          def target_box(model, target)
            bb = Geom::BoundingBox.new
            collect_bounds(model, target.definition.entities, IDENTITY, [target], bb, 0)
            box_mm(bb.empty? ? target.definition.bounds : bb)
          rescue StandardError => e
            Engine.log_error(e, 'Tools::Snaper.target_box')
            box_mm(target.definition.bounds)
          end

          def collect_bounds(model, entities, to_local, path, bb, depth)
            entities.each do |ent|
              next unless visible?(model, path + [ent])

              if container?(ent)
                child_tr = to_local * ent.transformation
                if depth < SnapCalc::MAX_DEPTH
                  collect_bounds(model, ent.definition.entities, child_tr, path + [ent], bb, depth + 1)
                else
                  add_bounds(bb, ent.definition.bounds, child_tr)
                end
              elsif ent.is_a?(Sketchup::Face)
                add_bounds(bb, ent.bounds, to_local)
              end
            end
          end

          # --- viditelnost ---------------------------------------------------------
          # `@native_visibility` je JEDNOSMERNY zamok: ked metoda raz hodi
          # (SketchUp < 2026 s kontajnerom na konci cesty), uz sa nevola — inak by
          # kazda prekazka platila cenu vynimky.
          def visible?(model, path)
            return fallback_visible?(path) if @native_visibility == false

            begin
              model.drawing_element_visible?(path)
            rescue StandardError
              @native_visibility = false
              fallback_visible?(path)
            end
          end

          def fallback_visible?(path)
            path.all? do |ent|
              next false if ent.respond_to?(:hidden?) && ent.hidden?

              lay = ent.respond_to?(:layer) ? ent.layer : nil
              next true if lay.nil?
              next false unless lay.visible?
              # Tag pod SKRYTYM priecinkom ostava `visible?` — priecinok treba
              # overit zvlast (existujuca `Tags.folder_hidden?`).
              !(defined?(Tags) && Tags.folder_hidden?(lay))
            end
          rescue StandardError
            true
          end

          # --- geometricke pomocky --------------------------------------------------

          def container?(ent)
            (ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)) &&
              ent.respond_to?(:definition) && !ent.definition.nil?
          rescue StandardError
            false
          end

          def transform_bounds(bounds, tr)
            out = Geom::BoundingBox.new
            8.times { |i| out.add(bounds.corner(i).transform(tr)) }
            out
          end

          def add_bounds(bb, bounds, tr)
            8.times { |i| bb.add(bounds.corner(i).transform(tr)) }
          end

          def box_mm(bounds)
            { min: [Units.to_mm(bounds.min.x), Units.to_mm(bounds.min.y), Units.to_mm(bounds.min.z)],
              max: [Units.to_mm(bounds.max.x), Units.to_mm(bounds.max.y), Units.to_mm(bounds.max.z)] }
          end
        end
      end
    end
  end
end
