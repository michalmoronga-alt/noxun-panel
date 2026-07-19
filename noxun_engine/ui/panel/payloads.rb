# frozen_string_literal: true
# Noxun Engine - Panel: payloady pre JS (korpus, sablony, materialy, karta dielca) + part_key identity.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- payload korpusu -------------------------------------------------
        # Slovenske labely roli dosky (jediny zdroj — JS ich NEduplikuje, Codex audit c).
        BOARD_ROLE_LABELS = { 'free_panel' => 'Voľná doska' }.freeze

        # Karta samostatnej dosky (V0.4.7c). Zdroj = ploche atributy + config na
        # instancii (autoritativny vyrobny zaznam, standard 8.3). edge_labels/sides
        # z AbsRules — jeden zdroj pravdy ako pri karte dielca.
        def board_payload(inst)
          cfg = Store.config(inst) || {}
          role = (Store.get(inst, 'role') || cfg['role']).to_s
          {
            'board_id' => Store.get(inst, 'id'),
            'name' => cfg['name'] || Store.get(inst, 'name'),
            'role' => role,
            'role_label' => BOARD_ROLE_LABELS[role] || role,
            'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'],
            'material_id' => cfg['material_id'],
            'grain_direction' => cfg['grain_direction'] || 'none',
            'edges' => cfg['edges'].is_a?(Hash) ? cfg['edges'] : {},
            'edge_labels' => AbsRules.edge_labels(role),
            'edge_sides' => AbsRules.edge_sides(role),
            'quantity' => cfg['quantity'] || 1
          }
        end

        def cabinet_payload(cab)
          cfg = Store.config(cab) || {}
          params = CabinetBuilder.config_to_params(cfg)
          params['cabinet_id'] = Store.get(cab, 'cabinet_id')
          params['fronts'] = Fronts.normalize_config(cfg['fronts']) # kanonicke pre riadky cela
          params['zones'] = cfg['zones'] || []                      # ploche zony pre strom + nahlad
          params['front_items'] = cfg['front_items'] || []          # rozlozene cela pre nahlad
          # svetle (available) rozmery — view-only kontrola pre pouzivatela
          params['available_width'] = cfg['available_width']
          params['available_height'] = cfg['available_height']
          params['available_depth'] = cfg['available_depth']
          params['warnings'] = cfg['warnings'] || [] # BuildPlan upozornenia (pre buduce UI)
          params['template_name_suggestion'] = suggest_template_name(cab, nil) # D-14 modal (Codex F4)
          # V0.4 kovanie: vypocitane polozky (vystup planu) + rucne zasahy (identita
          # owner+type+rule_id). hardware_overrides su aj v params (config_to_params),
          # tu explicitne — UI paruje disabled zaznamy na vypnute kategorie.
          params['hardware'] = cfg['hardware'].is_a?(Array) ? cfg['hardware'] : []
          params
        end

        # existujuce params korpusu (na zachovanie casti pri ciastocnej zmene)
        def existing_params(cab)
          CabinetBuilder.config_to_params(Store.config(cab) || {})
        end

        def template_config_from(cfg)
          tc = {
            'type' => cfg['type'], 'width' => cfg['width'], 'height' => cfg['height'], 'depth' => cfg['depth'],
            'thickness' => cfg['thickness'], 'floor_height' => cfg['floor_height'],
            'bottom_mode' => cfg['bottom_mode'], 'top_mode' => cfg['top_mode'], 'back_mode' => cfg['back_mode'],
            'back_thickness' => cfg['back_thickness'] || 3.0,
            'plinth_mode' => cfg['plinth_mode'], 'plinth_recess' => cfg['plinth_recess'],
            'rail_depth' => cfg['rail_depth'], 'rails_orientation' => cfg['rails_orientation'],
            'rails_top_offset' => cfg['rails_top_offset'],
            'zone_tree' => cfg['zone_tree'] || ZoneTree.default_tree((cfg['shelves'] || 0).to_i),
            'fronts' => Fronts.normalize_config(cfg['fronts'])
          }
          # V0.3 FIX 1: korpusove materialy do sablony LEN ak su na zdroji nastavene (non-nil).
          # part_overrides do sablony NEUKLADAME — su viazane na konkretne dielce/zony zdroja
          # (pri aplikacii sablony sa zachovaju z cieloveho korpusu).
          %w[material_id front_material_id back_material_id].each do |k|
            v = present_str(cfg[k])
            tc[k] = v if v
          end
          tc
        end

        def template_config_from_fields(data)
          tc = template_config_from(data)
          tc['zone_tree'] = data['zone_tree'] || ZoneTree.default_tree(0)
          tc['fronts'] = Fronts.normalize_config(data['fronts'])
          tc
        end

        def template_list
          TemplateStore.load
        rescue StandardError => e
          Engine.log_error(e, 'template_list')
          []
        end

        def suggest_template_name(cab, _data)
          cab ? "Kopia #{Store.get(cab, 'cabinet_id')}" : 'Nova sablona'
        end

        # --- V0.3 materialy + ABS: payloady a resolvery ---------------------

        # Katalog pre selecty: dosky (id + label) + ABS pasky (id + label + farba pre nahlad hrany).
        def materials_payload
          {
            'sheets' => Materials.sheets.map { |s|
              # grain (V0.4.7c, Codex GH #33): vkladacia karta dosky predvyplna smer
              # dekoru z katalogu — bez grain by formular posielal nespravny default.
              { 'id' => s['material_id'], 'label' => sheet_label(s), 'decor' => s['decor'],
                'thickness' => s['thickness'], 'color' => s['color'], 'grain' => s['grain'] }
            },
            'edges' => Materials.edges.map { |a|
              { 'id' => a['abs_id'], 'label' => abs_label(a), 'decor' => a['decor'],
                'thickness' => a['thickness'], 'color' => a['color'] }
            }
          }
        rescue StandardError => e
          Engine.log_error(e, 'materials_payload')
          { 'sheets' => [], 'edges' => [] }
        end

        def sheet_label(s)
          th = s['thickness'].to_f
          thl = (th == th.round ? th.round : th)
          "#{s['decor']} · #{s['type']} #{thl} mm"
        end

        def abs_label(a)
          "#{a['decor']} #{a['thickness']} mm"
        end

        # (project_materials payload sa V0.4.5 D2 presunul do MaterialsDialog.push_state)

        # Dielec vo vybere (kind=part) — po dvojkliku do korpusu a kliknuti na dielec.
        def find_selected_part(model)
          model.selection.to_a.find { |e| Store.kind(e) == 'part' }
        end

        # Karta dielca pre UI (ABS/materialovy editor): rola, rozmery, VYSLEDNY material + ABS hrany,
        # labely hran per rola, priznaky overridov.
        def part_card_payload(_model, cab, part)
          cfg = Store.config(part) || {}
          role = Store.get(part, 'role').to_s
          cabcfg = Store.config(cab) || {}
          params = CabinetBuilder.config_to_params(cabcfg)
          rk = canonical_part_key(params, part_identity(cab, part))
          ov = ((params['part_overrides'] || {})[rk] || {})
          {
            'role_key' => rk, 'role' => role, 'name' => Store.get(part, 'name'),
            'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'],
            'material_id' => cfg['material_id'],
            'edges' => cfg['edges'] || AbsRules.empty_edges,
            'edge_labels' => AbsRules.edge_labels(role),
            'edge_sides' => AbsRules.edge_sides(role), # V0.3 FIX 3: mapa hrana->strana pre SVG (1 zdroj pravdy)
            'edge_overrides' => (ov['edges'] || {}), # ktore hrany maju rucny override (UI odlisi "dedi")
            'has_material_override' => !ov['material_id'].nil?,
            'cabinet_id' => Store.get(cab, 'cabinet_id')
          }
        rescue StandardError => e
          Engine.log_error(e, 'part_card_payload')
          nil
        end

        # part_key z plocheho atributu; fallback cez legacy role_key a nakoniec part_id.
        def part_identity(cab, part)
          present_str(Store.get(part, 'part_key')) ||
            present_str(Store.get(part, 'role_key')) ||
            fallback_role_key(cab, part)
        end

        # Prelozi legacy renderovaci suffix na part_key podla povodnej konfiguracie.
        # Nove kluce vracia bez dalsieho vypoctu.
        def canonical_part_key(params, key)
          value = key.to_s
          return value if value.start_with?('cabinet/', 'zone:', 'front:')

          cfg = CabinetBuilder.normalize(params)
          pd = Construction.build_plan(cfg)[:parts].find { |part| part[:suffix].to_s == value }
          pd ? PartKeys.for_descriptor(pd) : value
        rescue StandardError
          value
        end
        def fallback_role_key(cab, part)

          pid = Store.get(part, 'part_id').to_s
          cid = Store.get(cab, 'cabinet_id').to_s
          (!cid.empty? && pid.start_with?("#{cid}-")) ? pid[(cid.length + 1)..-1] : pid
        end

        def find_part_by_role_key(cab, rk)
          return nil unless cab && cab.respond_to?(:definition) && cab.valid?
          params = existing_params(cab)
          cab.definition.entities.grep(Sketchup::ComponentInstance).find do |e|
            Store.kind(e) == 'part' && canonical_part_key(params, part_identity(cab, e)) == rk
          end
        end

        def all_cabinets(model)
          out = []
          Ids.each_cabinet(model) { |i| out << i }
          out
        end

        # String alebo nil (prazdny -> nil). Pre material dedenie + override cistenie.
        def present_str(v)
          return nil if v.nil?
          s = v.to_s.strip
          s.empty? ? nil : s
        end
      end
    end
  end
end
