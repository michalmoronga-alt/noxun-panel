# frozen_string_literal: true
# Noxun Engine — V0.6 C-2: okno "Katalog kovania" (sprava HardwareCatalog).
#
# Vzor materials_dialog: satelitne okno, callbacky PRED show, server je
# autorita (search VYHRADNE Ruby — audit C F12; JS len renderuje), zapisy
# s row_rev/revision guardmi, hlasky cez set_status + echo push_items.
# Cenove overenie = serverovy proposal flow HardwareCatalog (BLOCKER 1) —
# JS posiela len kod + accept, hodnoty nikdy.
#
# Request generation (F9): kazdy check_price nesie gen; vysledok so starym
# gen alebo pre zavrete okno sa zahodi (bump: novy check, close).
require 'json'

module Noxun
  module Engine
    module HardwareCatalogDialog
      DLG_KEY = 'noxun_engine_hw_catalog_v1'

      class << self
        def show
          dlg = ensure_dialog
          if dlg.visible?
            dlg.bring_to_front
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.show')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Katalóg kovania',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 680,
            height: 560,
            min_width: 520,
            min_height: 400,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'hardware_catalog.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed do
            bump_gen       # F9: zavrete okno zneplatni bezace cenove overenia
            bump_demos_gen # GH #128 P2: aj bezaci nahlad z Demosu
            @dialog = nil
          end
          @dialog
        end

        def register_callbacks(dlg)
          cb(dlg, 'ready')          { |_p| push_state; push_sets }
          cb(dlg, 'hw_search')      { |p| handle_search(p) }
          cb(dlg, 'hw_create')      { |p| handle_create(p) }
          cb(dlg, 'hw_patch')       { |p| handle_patch(p) }
          cb(dlg, 'hw_delete')      { |p| handle_delete(p) }
          cb(dlg, 'hw_check_price') { |p| handle_check_price(p) }
          cb(dlg, 'hw_apply_price') { |p| handle_apply_price(p) }
          # V0.6 D2: "Pridat z Demosu" — zhody zo sitemap, nahlad, zapis
          cb(dlg, 'hw_demos_search')  { |p| handle_demos_search(p) }
          cb(dlg, 'hw_demos_preview') { |p| handle_demos_preview(p) }
          cb(dlg, 'hw_demos_cancel')  { |p| handle_demos_cancel(p) }
          cb(dlg, 'hw_demos_create')  { |p| handle_demos_create(p) }
          # V0.6 D1b: sety kovania (tab Sety + Predvolby projektu)
          cb(dlg, 'hws_save_set')      { |p| handle_set_save(p) }
          cb(dlg, 'hws_delete_set')    { |p| handle_set_delete(p) }
          cb(dlg, 'hws_map_project')   { |p| handle_map_project(p) }
          cb(dlg, 'hws_map_global')    { |p| handle_map_global(p) }
          cb(dlg, 'hws_reset_project') { |p| handle_reset_project(p) }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(hw_catalog): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'hw_catalog js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "hw_catalog cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # --- Ruby -> JS ------------------------------------------------------

        def push_state
          js("MDH.init(#{state_payload.to_json})")
        end

        def push_items
          js("MDH.setItems(#{items_payload.to_json})")
        end

        def state_payload
          items_payload.merge(
            'version' => Engine::VERSION,
            'categories' => HardwareCatalog::CATEGORIES,
            'units' => HardwareCatalog::UNITS
          )
        end

        def items_payload
          {
            'items' => HardwareCatalog.items.map { |i|
              i.merge('row_rev' => HardwareCatalog.record_rev(i))
            },
            'revision' => HardwareCatalog.catalog_revision,
            'state' => HardwareCatalog.state.to_s,
            'state_reason' => HardwareCatalog.state_reason
          }
        end

        def set_status(msg, error = false)
          js("MDH.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        # --- V0.6 D2: Pridat z Demosu ------------------------------------------

        # Zive zhody kovania zo sitemap cache (offline; server = autorita
        # poradia, JS len renderuje — vzor F12). GH #128 P2: na cerstvej
        # instalacii cache este nie je — spustime zdielany jednorazovy refresh
        # (single-flight DemosLookup.start_refresh, vzor MaterialsDialog) a po
        # dobehnuti si JS dotaz zopakuje.
        def handle_demos_search(payload)
          data = JSON.parse(payload.to_s)
          query = data['query'].to_s
          if DemosSitemapCache.load.nil?
            dlg = @dialog
            js("MDH.demosResults(#{{ 'query' => query, 'results' => [],
                                     'refreshing' => true }.to_json})")
            DemosLookup.start_refresh do |ok, err|
              next unless @dialog && @dialog.equal?(dlg) && @dialog.visible?
              if ok
                js("MDH.demosRefreshDone()")
              else
                set_status("Zoznam produktov sa nepodarilo stiahnuť: #{err}", true)
              end
            end
            return
          end
          results = DemosNameSearch.search_hardware_cached(query, top: 10)
          js("MDH.demosResults(#{{ 'query' => query, 'results' => results }.to_json})")
        end

        # GH #128 P2: nahlad ma VLASTNY generation counter — spolocny @gen s
        # cenovym overenim by si dva subezne behy navzajom zabijali (formular
        # novej polozky moze byt otvoreny popri rozbalenej polozke katalogu).
        def bump_demos_gen
          @demos_gen = @demos_gen.to_i + 1
        end

        # Async nahlad produktu — gen guard (stary vysledok nesmie prepisat
        # novsi nahlad, zrusenie pouzivatelom ani zavrete okno).
        def handle_demos_preview(payload)
          data = JSON.parse(payload.to_s)
          gen = bump_demos_gen
          dlg = @dialog
          HardwareCatalog.demos_preview!(data['url'].to_s) do |res|
            next unless @demos_gen.to_i == gen && @dialog && @dialog.equal?(dlg) && @dialog.visible?
            js("MDH.demosPreview(#{res.merge('gen' => gen).to_json})")
          end
        end

        # GH #128 P2: „Zrušiť náhľad" pri bežiacom fetchi — bump generacie
        # zahodi dobiehajúci vysledok (inak by sa zruseny nahlad znovu otvoril).
        def handle_demos_cancel(_payload)
          bump_demos_gen
        end

        def handle_demos_create(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareCatalog.create_from_demos!(
            data['pid'].to_s, category: data['category'].to_s, notes: data['notes'].to_s
          )
          case status
          when :ok
            push_items
            js('MDH.demosCreated()')
            set_status("Položka #{info['item_code']} pridaná z Demosu#{info['price_eur_vat'] ? ' (cena s DPH overená dnes)' : ''}.")
          when :exists
            set_status("Kód #{info} už v katalógu je — cenu obnovíš cez Overiť na existujúcej položke.", true)
          when :no_proposal
            set_status('Náhľad už nie je platný — načítaj stránku znova.', true)
          when :invalid
            set_status("Nedá sa uložiť — #{info}.", true)
          when :read_only
            set_status("Katalóg je len na čítanie: #{HardwareCatalog.state_reason}", true)
          else
            set_status('Uloženie zlyhalo.', true)
          end
        end

        # --- V0.6 D1b: sety kovania -------------------------------------------

        # Prepnutie modelu (EngineAppObserver) — tab Predvolby projektu cita
        # NOVY aktivny model; polozky katalogu su globalne (netreba refresh).
        def on_model_changed(_model)
          return unless @dialog && @dialog.visible?
          push_sets
        end

        def push_sets
          js("HWSETS.init(#{sets_payload.to_json})")
        end

        def sets_payload
          lib = HardwareSets.load
          model = Sketchup.active_model
          status, state = HardwareSets.project_state_status(model)
          {
            'sets' => lib['sets'],
            'global_mapping' => lib['mapping'],
            'revision' => HardwareSets.revision,
            'project' => { 'status' => status.to_s,
                           'mapping' => (state ? state['mapping'] : {}),
                           # GH #127 P2: zmrazene KOPIE projektu — mapovany set
                           # mohol byt v globale zmeneny/zmazany; predvolby
                           # musia ukazat pravdu projektu, nie globalu.
                           'sets' => (state ? state['sets'].values : []) },
            # handle/connector v ponuke NEskryvame — pravidla ich sice
            # negeneruju (uchytky mimo D — Michal 2.8.), ale set sa da
            # pripravit dopredu; expanzia bez poloziek aj tak nic nespravi.
            'generic_types' => BuildPlan::GENERIC_TYPES.map { |gt|
              { 'key' => gt, 'label' => HardwareRules.label_for(gt) }
            },
            'model_guid' => model ? model.guid.to_s : '',
            'model_title' => model && !model.title.to_s.empty? ? model.title.to_s : 'Bez názvu'
          }
        end

        def handle_set_save(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareSets.save_set!(data['set'].is_a?(Hash) ? data['set'] : {},
                                                revision: data['revision'].to_s,
                                                create: data['create'] == true)
          case status
          when :ok
            push_sets
            js('HWSETS.saved()') # GH #127 P2: editor sa zavrie az pri USPECHU
            set_status("Set „#{info['name']}“ uložený.")
          when :exists
            # GH #127 P2: slug z nazvu trafil existujucu identitu — novy set
            # nesmie ticho prepisat globalnu definiciu.
            set_status("Set s identitou „#{info}“ už existuje — zmeň názov (alebo uprav existujúci set).", true)
          when :conflict
            push_sets
            set_status('Knižnica setov sa medzitým zmenila — obnovené, uprav znova.', true)
          when :invalid
            set_status(info.to_s.empty? ? 'Set sa nedá uložiť.' : info.to_s, true)
          else
            push_sets
            set_status('Uloženie setu zlyhalo.', true)
          end
        end

        def handle_set_delete(payload)
          data = JSON.parse(payload.to_s)
          status, = HardwareSets.delete_set!(data['set_id'].to_s, revision: data['revision'].to_s)
          case status
          when :ok
            push_sets
            set_status("Set zmazaný. Projekty, ktoré ho používajú, držia vlastnú kópiu — ich súpisy sa nemenia.")
          when :conflict
            push_sets
            set_status('Knižnica setov sa medzitým zmenila — obnovené, skús znova.', true)
          when :not_found
            push_sets
          else
            set_status('Zmazanie setu zlyhalo.', true)
          end
        end

        def handle_map_project(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return set_status('Žiadny aktívny model.', true) if model.nil?
          if data['model_guid'].to_s != model.guid.to_s
            push_sets
            return set_status('Model sa medzitým prepol — predvoľby sa obnovili, vyber znova.', true)
          end
          gt = data['generic_type'].to_s
          sid = data['set_id'].to_s.strip
          sid = nil if sid.empty?
          set_def = nil
          if sid
            lib = HardwareSets.load
            set_def = lib['sets'].find { |s| s['set_id'] == sid }
            if set_def.nil?
              push_sets
              return set_status('Set sa v knižnici nenašiel — obnovené.', true)
            end
          end
          # Zapis = 1 undo krok; snapshot dostane mapping AJ definiciu (B2).
          model.start_operation('NOXUN: Predvoľba setu kovania', true)
          ok = HardwareSets.set_project_mapping!(model, gt, sid, set_def)
          if ok
            model.commit_operation
            push_sets
            ProductionDialog.on_model_changed(model) if defined?(ProductionDialog)
            set_status(sid ? "#{HardwareRules.label_for(gt)} → #{set_def['name']}." : "#{HardwareRules.label_for(gt)} — bez setu.")
          else
            model.abort_operation
            push_sets
            set_status('Predvoľba sa nedá uložiť — sety projektu sú poškodené (tlačidlo Obnoviť).', true)
          end
        end

        def handle_map_global(payload)
          data = JSON.parse(payload.to_s)
          ok = HardwareSets.set_global_mapping!(data['generic_type'].to_s, data['set_id'])
          push_sets
          set_status(ok ? 'Globálna predvoľba uložená (platí pre nové projekty).' : 'Globálna predvoľba sa nedá uložiť.', !ok)
        end

        # F9: VEDOMA obnova poskodenych/chybajucich predvolieb projektu z
        # globalnych — jedina cesta, ktora invalid snapshot prepise.
        def handle_reset_project(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return set_status('Žiadny aktívny model.', true) if model.nil?
          if data['model_guid'].to_s != model.guid.to_s
            push_sets
            return set_status('Model sa medzitým prepol — obnovené.', true)
          end
          lib = HardwareSets.load
          by_id = {}
          lib['sets'].each { |s| by_id[s['set_id']] = s }
          mapping = {}
          sets = {}
          lib['mapping'].each do |gt, sid|
            next unless by_id[sid]
            mapping[gt] = sid
            sets[sid] = by_id[sid]
          end
          model.start_operation('NOXUN: Obnova predvolieb setov', true)
          ok = HardwareSets.write_project_state(model, 'mapping' => mapping, 'sets' => sets)
          ok ? model.commit_operation : model.abort_operation
          push_sets
          ProductionDialog.on_model_changed(model) if defined?(ProductionDialog) && ok
          set_status(ok ? 'Predvoľby projektu obnovené z globálnych.' : 'Obnova zlyhala.', !ok)
        end

        def js(script)
          return unless @dialog && @dialog.visible?
          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.js')
        end

        # --- generation (F9) -------------------------------------------------

        def bump_gen
          @gen = @gen.to_i + 1
        end

        # --- handlery --------------------------------------------------------

        # Search je VYHRADNE serverovy (F12) — JS posiela query/kategoriu/flag
        # neaktivnych a len renderuje vratene poradie.
        def handle_search(payload)
          data = JSON.parse(payload.to_s)
          results = HardwareCatalog.search(
            HardwareCatalog.items, data['query'].to_s,
            category: data['category'].to_s,
            include_inactive: data['include_inactive'] == true,
            top: 50
          )
          js("MDH.results(#{{ 'codes' => results.map { |i| i['item_code'] },
                              'query' => data['query'].to_s }.to_json})")
        end

        def handle_create(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareCatalog.create_item(data['fields'].is_a?(Hash) ? data['fields'] : {})
          case status
          when :ok
            push_items
            set_status("Položka #{info['item_code']} pridaná.")
            js('MDH.created()')
          when :exists
            set_status("Kód #{info} už v katalógu je — kódy sú jedinečné.", true)
          when :invalid
            set_status("Nedá sa uložiť — #{info}.", true)
          when :read_only
            set_status("Katalóg je len na čítanie: #{info}", true)
          else
            set_status('Uloženie zlyhalo.', true)
            push_items
          end
        end

        def handle_patch(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareCatalog.patch_item(
            data['code'].to_s, data['patch'].is_a?(Hash) ? data['patch'] : {},
            row_rev: data['row_rev'].to_s
          )
          case status
          when :ok
            push_items
            set_status('Uložené.')
          when :conflict
            set_status('Položka sa medzitým zmenila — hodnoty sa obnovili, uprav znova.', true)
            push_items
          when :not_found
            set_status('Položka sa nenašla — katalóg sa obnovil.', true)
            push_items
          when :invalid
            set_status(info.to_s.empty? ? 'Neplatná hodnota.' : info.to_s, true)
            push_items
          when :read_only
            set_status("Katalóg je len na čítanie: #{info}", true)
            push_items
          else
            set_status('Uloženie zlyhalo.', true)
            push_items
          end
        end

        def handle_delete(payload)
          data = JSON.parse(payload.to_s)
          status, = HardwareCatalog.delete_item(data['code'].to_s, row_rev: data['row_rev'].to_s)
          case status
          when :ok
            push_items
            set_status("Položka #{data['code']} zmazaná.")
          when :conflict
            set_status('Položka sa medzitým zmenila — skontroluj a skús znova.', true)
            push_items
          when :not_found
            push_items
          when :read_only
            set_status(HardwareCatalog.state_reason, true)
          else
            set_status('Zmazanie zlyhalo.', true)
            push_items
          end
        end

        # Zivy check ceny — vysledok pride async; gen + code echo strazi, aby
        # stary vysledok neprepisal detail inej polozky (F9).
        def handle_check_price(payload)
          data = JSON.parse(payload.to_s)
          code = data['code'].to_s
          gen = bump_gen
          dlg = @dialog
          HardwareCatalog.check_price!(code, url: data['url'].to_s) do |res|
            next unless @gen.to_i == gen && @dialog && @dialog.equal?(dlg) && @dialog.visible?
            js("MDH.priceResult(#{res.merge('code' => code, 'gen' => gen).to_json})")
          end
        end

        def handle_apply_price(payload)
          data = JSON.parse(payload.to_s)
          # GH #99 P2: pid viaze zapis na navrh, ktory pouzivatel VIDEL —
          # prekryvajuce sa checky nemozu potajme zapisat inu cenu.
          status, rec = HardwareCatalog.apply_price_proposal!(data['code'].to_s,
                                                             pid: data['pid'].to_s)
          case status
          when :ok
            push_items
            set_status("Cena #{rec['item_code']} zapísaná (overená dnes).")
            js("MDH.priceApplied(#{{ 'code' => rec['item_code'] }.to_json})")
          when :no_proposal
            set_status('Návrh ceny už nie je platný — spusti Overiť znova.', true)
          when :conflict
            set_status('Položka sa od overenia zmenila — spusti Overiť znova.', true)
            push_items
          when :read_only
            set_status(HardwareCatalog.state_reason, true)
          else
            set_status('Zápis ceny zlyhal.', true)
            push_items
          end
        end
      end
    end
  end
end
