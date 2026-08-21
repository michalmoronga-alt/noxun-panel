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
          # Codex #168 P2 (3. kolo): pociatocny payload musi byt ZRKADLOM
          # push_selected — inak sa panel pri otvoreni sprava inak nez pri
          # kazdom dalsom pushi:
          #   * bez model_guid by mala prva identita prazdny dokument a PRVE
          #     bezne echo by vyzeralo ako novy vyber (kontext by skocil na Korpus),
          #   * bez part_card by panel nad uz oznacenym DIELCOM otvoril rezim
          #     skrinky — bez docasnej polozky raily a bez karty dielca.
          initial = if cab
                      p = cabinet_payload(cab)
                      p['model_guid'] = model_guid(model)
                      part = find_selected_part(model)
                      p['part_card'] = part ? part_card_payload(model, cab, part) : nil
                      p
                    elsif board
                      p = board_payload(board)
                      p['model_guid'] = model_guid(model)
                      p
                    end
          data = {
            version: Engine::VERSION, # UI zobrazuje verziu odtialto — ziadny hardcode v HTML
            defaults: {
              lower: CabinetBuilder::LOWER_DEFAULTS,
              upper: CabinetBuilder::UPPER_DEFAULTS
            },
            zones_visible: Zones.visible?(model),
            # UI-D2 (Codex #181 P1): aj PRVY payload nesie `preview_rev` — inak by
            # panel po otvoreni povazoval vsetky sablony za bezobrazkove, o nahlad
            # by si nepovedal a fotky by naskocili az po nesuvisiacom push_templates.
            templates: template_list(previews: true),
            materials: materials_payload, # V0.3 katalog (dosky + ABS) pre selecty
            # (projektove predvolby zobrazuje okno MaterialsDialog — D2)
            selected: initial,
            selected_kind: cab ? 'cabinet' : (board ? 'board' : 'none'),
            # D-39 (audit B5): zamky vkladacej karty z Ruby pamate — preziju
            # zatvorenie panela; JS ich obnovi pri kazdom otvoreni (push_init).
            insert_locks: insert_locks,
            # D-90: ponuka uchytkovych profilov (id/nazov/skratenie) — JEDINY
            # zdroj je registry FrontProfiles, JS si ziadny zoznam nedrzi.
            front_profiles: FrontProfiles.options,
            # UI-B1 (audit A2): stav ABS kontroly hran pre ikonu v raile. PULL
            # pri otvoreni panela; dalsie zmeny chodia pushom (push_edge_check)
            # z panela, z toolbaru aj z okna Vyroba. CISTE CITANIE.
            edge_check: edge_check_state,
            # K2/D-87: stav kontroly smeru kresby pre druhu funkcnu ikonu raily.
            # Ten isty vzor ako `edge_check` — PULL pri otvoreni panela, dalsie
            # zmeny pushom (z raily aj z okna Vyroba). CISTE CITANIE.
            grain_check: grain_check_state,
            # UI-B3 (koliesko): nastavenia POCITACA — rozmerove rady (N6) pre
            # ponuky pri rozmeroch a meno aktualnej temy pre prepinac vzhladu.
            # Nie su to data zakazky (ziju v %APPDATA%, nikdy v .skp).
            ui_settings: ui_settings_payload,
            # Identita dokumentu pre stavovy stroj panela aj pre identity guardy
            # asynchronnych callbackov (Codex #168 P2).
            model_guid: model_guid(model)
          }
          js("NX.init(#{data.to_json})")
        end

        # UI-B1: stav zvyraznenia olepu pre rail. Nedostupny/nenacitany EdgeCheck
        # (SketchUp bez Overlay API) = ikona zosedne, panel sa tym nezhodi.
        def edge_check_state
          return { 'available' => false, 'active' => false } unless defined?(EdgeCheck)

          EdgeCheck.ui_state(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.edge_check_state')
          { 'available' => false, 'active' => false }
        end

        # Maly echo push stavu hran (bez prepoctu panela) — vzor
        # ProductionDialog#push_edge_check. Vola ho Engine.broadcast_edge_check
        # (klik z panela, z toolbaru aj z okna Vyroba) a EdgeCheck po prepocte.
        def push_edge_check(state = nil)
          return unless dialog_alive?

          st = state || edge_check_state
          js("if (window.NX && NX.setEdgeCheck) NX.setEdgeCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_edge_check')
        end

        # v0.7.28: zatvorenie rohoveho 3-stavoveho nastavenia v raile. Vola ho
        # Engine.close_edge_menu, ked pouzivatel otvoril TO ISTE nastavenie
        # v okne Vyroba — dve kopie tych istych prepinacov na obrazovke naraz
        # by len mylili. Cisto zobrazovacie: ziadny stav, ziadny zapis.
        def close_edge_menu
          return unless dialog_alive?

          js('if (window.NX && NX.closeEdgeMenu) NX.closeEdgeMenu();')
        rescue StandardError => e
          Engine.log_error(e, 'Panel.close_edge_menu')
        end

        # K2/D-87: stav kontroly smeru kresby pre rail. Nedostupny/nenacitany
        # GrainCheck (SketchUp bez Overlay API) = ikona zosedne, panel sa tym
        # nezhodi. Cisla sklada VYHRADNE server (`GrainCheck.ui_state`).
        def grain_check_state
          return { 'available' => false, 'active' => false } unless defined?(GrainCheck)

          GrainCheck.ui_state(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.grain_check_state')
          { 'available' => false, 'active' => false }
        end

        # Protajsok ProductionDialog#push_grain_check. Vola ho
        # Engine.broadcast_grain_check (klik z raily aj z okna Vyroba) a
        # GrainCheck po prepocte cache (prestavba pri zapnutej kresbe).
        def push_grain_check(state = nil)
          return unless dialog_alive?

          st = state || grain_check_state
          js("if (window.NX && NX.setGrainCheck) NX.setGrainCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_grain_check')
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
            if board
              bp = board_payload(board)
              bp['model_guid'] = model_guid(model)
              return js("NX.loadBoard(#{bp.to_json})")
            end
            # Codex #168 P2 (3. kolo): AJ prazdny vyber nesie identitu dokumentu.
            # Prepnutie do dokumentu bez vyberu inak nechalo panel na guide
            # STAREHO modelu a ABS prepinac by kazdy klik odmietal ako nezhodu.
            return js("NX.clearSelected(#{model_guid(model).to_json})")
          end
          az = if zone && zone['cabinet_id'] == Store.get(cab, 'cabinet_id')
                 zone['zone_id']
               elsif belongs?(@active_zone_id, cab)
                 @active_zone_id
               end
          @active_zone_id = az
          payload = cabinet_payload(cab)
          payload['active_zone'] = az
          payload['model_guid'] = model_guid(model)
          # V0.3: ak je vo vybere DIELEC (kind=part), priloz kartu dielca (ABS/materialovy editor).
          part = find_selected_part(model)
          payload['part_card'] = part ? part_card_payload(model, cab, part) : nil
          js("NX.loadSelected(#{payload.to_json})")
        end

        # UI-B1 (Codex #168 P2, 2. kolo): IDENTITA DOKUMENTU. ID objektov su
        # jedinecne LEN v ramci modelu (Ids.next_board_id pocita od zaciatku
        # v kazdom dokumente), takze dva otvorene dokumenty bezne obsahuju
        # BRD-001 aj CAB-001. Bez guidu by:
        #   * prepnutie dokumentu vyzeralo pre panel ako ECHO push tej istej
        #     identity (kontext by ostal na starom mieste namiesto resetu),
        #   * oneskoreny callback (krizik dosky, ABS prepinac) trafil CUDZI
        #     dokument. Zrkadlo ProductionDialog#model_guid.
        def model_guid(model = nil)
          m = model || Sketchup.active_model
          m && m.respond_to?(:guid) ? m.guid.to_s : ''
        rescue StandardError
          ''
        end

        # UI-D2: zoznam nesie aj `preview_rev` — dlaydica podla neho vie, ci
        # ma o PNG vobec ziadat (a JS podla neho cachuje). Samotny obrazok ide
        # samostatnym kanalom nizsie.
        def push_templates
          js("NX.setTemplates(#{template_list(previews: true).to_json})")
        end

        # UI-D2: PULL kanal nahladu. Panel si vypyta PNG pre (kind, name, rev)
        # RAZ — data URI je radovo vacsie nez zvysok zoznamu a poslat ho pri
        # kazdom `push_templates` by z kazdeho refreshu spravilo stovky kB.
        # Vzor `nx_used_ids` (D-85): ciste citanie na VYZIADANIE, ziadny render
        # karty, ziadny dotyk modelu. `rev` sa vracia SPAT nezmenene, aby si
        # JS odpoved priradil k spravnej verzii (medzitym mohol prist novy
        # nahlad); `png: nil` = bez nahladu — dlazdica ostane na scheme a JS
        # si to zacachuje, takze sa nepyta dokola.
        def push_template_preview(payload)
          return unless dialog_alive?

          data = JSON.parse(payload.to_s)
          kind = data['kind'].to_s
          name = data['name'].to_s
          return if name.empty?

          out = { 'kind' => kind, 'name' => name, 'rev' => data['rev'].to_s,
                  'png' => TemplatePreviews.data_uri(kind, name) }
          js("NX.setTemplatePreview(#{out.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_template_preview')
        end

        # D-05: zivy refresh katalogu materialov v paneli po CRUD v satelitnom okne
        # (BEZ push_init — nesmie resetovat rozpisany formular).
        def push_materials
          js("NX.setMaterials(#{materials_payload.to_json})")
          push_part_card
        end

        # K1 (Codex #185 kolo 2, P2): CERSTVY payload karty dielca po zmene
        # KATALOGU. `NX.setMaterials` kartu prekresluje z CACHOVANEHO payloadu,
        # takze vsetko, co sklada SERVER, by ostalo stare az do dalsieho prekliku
        # vyberu — segment „Smer dekoru" by ostal ZAMKNUTY na materiali, ktoremu
        # prave pribudol smer (alebo naopak ponukal otacanie tam, kde uz nie je
        # co otacat), a rovnako by zamrzli texty hran D-102.
        #
        # Je to CISTE CITANIE (vzor `push_used_ids`): ziadna operacia, ziadny
        # dedup, ziadny zapis do modelu (lekcia D-103). Ked vo vybere dielec nie
        # je, NEPOSIELA sa nic — `renderPartCard(null)` by kartu schoval a
        # zmena katalogu nesmie prepnut rezim panela.
        # `dialog_alive?` sa tu NEKONTROLUJE zamerne (na rozdiel od
        # `push_used_ids`, ktory nim obchadza drahy scan modelu): payload jednej
        # karty je citanie configu jedneho dielca — lacnejsie nez katalog, ktory
        # `push_materials` postavil o riadok vyssie — a samotne odoslanie uz
        # strazi `js`. Guard navyse robil metodu nepozorovatelnou pre testy.
        def push_part_card
          model = Sketchup.active_model
          return if model.nil?

          cab = find_cabinet(model)
          part = cab ? find_selected_part(model) : nil
          return if part.nil?

          payload = part_card_payload(model, cab, part)
          return if payload.nil?

          # Identitu dokumentu nesie obalka push_selected; tento push je
          # samostatny, takze si ju musi doniest sam (JS ju cita pri zapise).
          payload['model_guid'] = model_guid(model)
          js("NX.setPartCard(#{payload.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_part_card')
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
