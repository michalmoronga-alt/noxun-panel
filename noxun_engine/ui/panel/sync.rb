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
            selected_kind: cab ? 'cabinet' : (board ? 'board' : 'none'),
            # D-39 (audit B5): zamky vkladacej karty z Ruby pamate — preziju
            # zatvorenie panela; JS ich obnovi pri kazdom otvoreni (push_init).
            insert_locks: insert_locks,
            # D-90: ponuka uchytkovych profilov (id/nazov/skratenie) — JEDINY
            # zdroj je registry FrontProfiles, JS si ziadny zoznam nedrzi.
            front_profiles: FrontProfiles.options
          }
          js("NX.init(#{data.to_json})")
        end

        # dedup: false = refresh po programovom selecte z okna Vyroba (V0.5 B,
        # Codex B2) — vyber NESMIE mutovat model (dedup meni ID a stavia).
        #
        # D-103 (9.8.2026, ziva reprodukcia): sync vyberu uz dedup NEVYKONAVA, len si
        # ho VYZIADA u observera. Doteraz tu bezala vlastna netransparentna operacia
        # PRIAMO v selection evente — teda hned po pouzivatelovej kopirovacej operacii
        # (Move+Ctrl s otvorenym Inspectorom). Stala sa vrcholom undo stacku a ked
        # pouzivatel dopisal `*4`, Move nastroj svoju operaciu PREPISAL (interne undo
        # + nove kopie) — undo vsak trafilo NASU operaciu, povodna kopia prezila a
        # nasobenie polozilo dalsiu na to iste miesto: dve dosky na jednom mieste =
        # dva dielce v kusovniku, VEPO aj rozpocte. Observer to spravi o 0,2 s neskor
        # TRANSPARENTNE (splynie s krokom pouzivatela), co je overene bezpecne.
        # Kartu s novym ID doplni observer sam (refresh_panel po dedupe).
        def push_selected(model, dedup: true)
          ScaleWatch.request_dedup(model) if dedup && defined?(ScaleWatch)
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

        # D-85 (Codex #167 P2): SAMOTNY odvodeny zoznam „Použité v projekte" pre
        # otvoreny combobox — bez katalogu, bez prekreslenia karty (rozpisany
        # formular sa nesmie dotknut, vzor push_materials/setHardwareSets).
        # Vola sa na VYZIADANIE z panela (callback nx_used_ids pri otvoreni
        # ponuky), nie z push_selected: scan modelu je prilis draha vec na to,
        # aby bezala pri kazdom kliku vo vybere. Cita sa iba (Materials.used_*)
        # — ziadna operacia, ziadny zapis, ziadny undo krok (lekcia D-103).
        def push_used_ids
          return unless dialog_alive?

          js("NX.setUsedIds(#{used_ids_payload.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_used_ids')
        end

        # D-75 (H1b): zivy refresh PONUKY setov kovania po zmene v okne Katalog
        # kovania. Obnovi LEN moznosti selectov (NX.setHardwareSets) — ziadny
        # push_selected: ten resetuje rozpracovany formular a navyse dedup-uje
        # kopie, cize by zmena v satelitnom okne siahla na MODEL.
        # Cita sa iba (find_cabinet + config) — bez operacie, bez zapisu.
        #
        # D-92 (audit BLOCKER 2): payload nesie AJ nakupny rozpis poloziek
        # (set -> kody -> nazvy). Bez neho by sekcia Kovanie po zmene setu,
        # kodu ci nazvu polozky ukazovala stary nakup az do prekliku vyberu.
        # Riadky sa NEPREKRESLUJU — JS meni len sekundarne riadky (rozpisany
        # pocet aj vyber setu ostavaju). 'items' nesie identitu polozky
        # (owner_part_key + generic_type + rule_id), aby ich JS spároval.
        def push_hardware_sets
          return unless dialog_alive?

          model = Sketchup.active_model
          cab = model ? find_cabinet(model) : nil
          data =
            if cab.nil?
              { 'cabinet_id' => nil, 'options' => [], 'items' => [] }
            else
              cfg = Store.config(cab) || {}
              items = hardware_items_payload(cfg)
              { 'cabinet_id' => Store.get(cab, 'cabinet_id'),
                'options' => hardware_set_options(cfg, items),
                'items' => items.map { |h| hardware_purchase_row(h) }.compact }
            end
          js("NX.setHardwareSets(#{data.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_hardware_sets')
        end

        # D-92: minimalny tvar pre zivy refresh — identita riadku + to, co sa
        # v nom meni. Nic viac (payload chodi po kazdej zmene katalogu).
        def hardware_purchase_row(item)
          return nil unless item.is_a?(Hash)

          { 'owner_part_key' => item['owner_part_key'], 'generic_type' => item['generic_type'],
            'rule_id' => item['rule_id'], 'owner_label' => item['owner_label'],
            'purchase' => item['purchase'] }
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        # Status doplneny o pocet BuildPlan upozorneni z posledneho planu korpusu.
        # Nefatalne stavy (orezane vystuhy, preskocene police...) tak uz nie su neviditelne.
        def status_with_warnings(cab, msg)
          warns = cab && cab.valid? ? ((Store.config(cab) || {})['warnings'] || []) : []
          msg = "#{msg} · #{warns.size} #{warn_word(warns.size)}" unless warns.empty?
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

        # V0.5 B: relay handshake okna Vyroba potrebuje vediet, ci panel zije.
        def dialog_alive?
          !!(@dialog && @dialog.visible?)
        end

      end
    end
  end
end
