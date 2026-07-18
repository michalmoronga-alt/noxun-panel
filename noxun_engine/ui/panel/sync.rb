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
          # V0.4.7c: aj uz oznacena DOSKA pri otvoreni panela (Codex audit c, blocker B) —
          # priorita korpus -> doska -> nic, rovnaka ako push_selected.
          board = cab.nil? ? find_board(model) : nil
          data = {
            version: Engine::VERSION, # UI zobrazuje verziu odtialto — ziadny hardcode v HTML
            defaults: {
              lower: CabinetBuilder::LOWER_DEFAULTS,
              upper: CabinetBuilder::UPPER_DEFAULTS
            },
            zones_visible: Zones.visible?(model),
            templates: template_list,
            materials: materials_payload, # V0.3 katalog (dosky + ABS) pre selecty
            # (projektove predvolby zobrazuje okno MaterialsDialog — D2)
            selected: cab ? cabinet_payload(cab) : (board ? board_payload(board) : nil),
            selected_kind: cab ? 'cabinet' : (board ? 'board' : 'none')
          }
          js("NX.init(#{data.to_json})")
        end

        def push_selected(model)
          # fix #6: "sync tick" resolvera — ak vznikla kopia korpusu/dosky (zdielane id),
          # pridelí sa jej nove ID (+ korpusu vlastne ghosty) este pred nacitanim vyberu.
          CabinetBuilder.dedup_copies(model) if defined?(CabinetBuilder)
          BoardBuilder.dedup_copies(model) if defined?(BoardBuilder)
          # V0.4.5 D2: dialog Sablony sleduje vyber (disabled stav "Pouzit na oznaceny")
          TemplatesDialog.on_selection_changed if defined?(TemplatesDialog)
          zone = find_selected_zone(model)
          cab = find_cabinet(model)
          if cab.nil?
            @active_zone_id = nil
            # V0.4.7c: doska ma vlastnu kartu; korpus ma v Inspectore prednost.
            board = find_board(model)
            return js("NX.loadBoard(#{board_payload(board).to_json})") if board
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

        # D-05: zivy refresh katalogu materialov v paneli po CRUD v satelitnom okne
        # (BEZ push_init — nesmie resetovat rozpisany formular).
        def push_materials
          js("NX.setMaterials(#{materials_payload.to_json})")
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        # Status doplneny o pocet BuildPlan upozorneni z posledneho planu korpusu.
        # Nefatalne stavy (orezane vystuhy, preskocene police...) tak uz nie su neviditelne.
        def status_with_warnings(cab, msg)
          warns = cab && cab.valid? ? ((Store.config(cab) || {})['warnings'] || []) : []
          msg = "#{msg} · ⚠ #{warns.size} #{warn_word(warns.size)}" unless warns.empty?
          set_status(msg)
        end

        def warn_word(n)
          return 'upozornenie' if n == 1
          n < 5 ? 'upozornenia' : 'upozorneni'
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
