# frozen_string_literal: true
# Noxun Engine - Panel: Ruby->JS (push_init, push_selected, push_templates, set_status, js).
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- Ruby -> JS ------------------------------------------------------
        def push_init
          model = Sketchup.active_model
          cab = find_cabinet(model)
          data = {
            version: Engine::VERSION, # UI zobrazuje verziu odtialto — ziadny hardcode v HTML
            defaults: {
              lower: CabinetBuilder::LOWER_DEFAULTS,
              upper: CabinetBuilder::UPPER_DEFAULTS
            },
            zones_visible: Zones.visible?(model),
            templates: template_list,
            materials: materials_payload,            # V0.3 katalog (dosky + ABS) pre selecty
            project_materials: project_materials(model), # V0.3 projektove defaulty (koren dedenia)
            selected: cab ? cabinet_payload(cab) : nil
          }
          js("NX.init(#{data.to_json})")
        end

        def push_selected(model)
          # fix #6: "sync tick" resolvera — ak vznikla kopia korpusu (zdielane cabinet_id),
          # pridelí sa jej nove ID + vlastne ghosty este pred nacitanim vyberu do panela.
          CabinetBuilder.dedup_copies(model) if defined?(CabinetBuilder)
          zone = find_selected_zone(model)
          cab = find_cabinet(model)
          if cab.nil?
            @active_zone_id = nil
            return js('NX.clearSelected()')
          end
          az = if zone && zone['cabinet_id'] == Store.get(cab, 'cabinet_id')
                 zone['zone_id']
               elsif belongs?(@active_zone_id, cab)
                 @active_zone_id
               end
          @active_zone_id = az
          payload = cabinet_payload(cab)
          payload['active_zone'] = az
          # V0.3: ak je vo vybere DIELEC (kind=part), priloz kartu dielca (ABS/materialovy editor).
          part = find_selected_part(model)
          payload['part_card'] = part ? part_card_payload(model, cab, part) : nil
          js("NX.loadSelected(#{payload.to_json})")
        end

        def push_templates
          js("NX.setTemplates(#{template_list.to_json})")
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?

          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.js')
        end

      end
    end
  end
end
