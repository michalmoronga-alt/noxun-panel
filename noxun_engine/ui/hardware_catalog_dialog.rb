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
            # D-77: zoznam poloziek a editor setov maju siroke riadky s akciami
            # vpravo. Rozmery platia LEN pri prvom otvoreni — zapamatane male okno
            # dorovna nx_fit.
            width: 760,
            height: 620,
            min_width: 560,
            min_height: 420,
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
          Engine.register_dialog_fit(dlg, 'hw_catalog') # D-77: zapamatane male okno sa dorovna
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
          cb(dlg, 'hws_merge_seed')    { |p| handle_merge_seed(p) } # H1b (FIX 10)
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
          # D-92 (audit BLOCKER 2): sekcia Kovanie v paneli ukazuje KODY a NAZVY
          # kupovanych poloziek — po kazdej zmene katalogu ich treba obnovit,
          # inak by drzala stary nazov (alebo „mimo katalógu") az do prekliku
          # vyberu. ZIVY push (NIKDY push_selected — ten siaha na model).
          Panel.push_hardware_sets if defined?(Panel) && Panel.dialog_alive?
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.push_items')
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
            # H1b (audit BLOCKER 1): ponuku per typ sklada SERVER cez
            # HardwareSets.set_options — pre set_id, ktore projekt uz pouziva,
            # vyhrava definicia zo SNAPSHOTU (podla nej sa nakupuje), takze
            # select ukazuje nazov PROJEKTU, nie neskor premenovany global.
            'type_options' => project_type_options(lib, state),
            # Parametre pasiem/selectora — jediny slovnik je v core.
            'params' => HardwareSets::PARAM_OPTIONS,
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

        # { generic_type => [{set_id, name, project_copy}] } — poradie a vyber
        # definicie robi server (snapshot > global). project_copy = set, ktory
        # v kniznici uz NIE JE (projekt drzi vlastnu kopiu).
        def project_type_options(lib, state)
          snap_sets = state ? state['sets'] : {}
          refs = HardwareSets.referenced_set_ids(state ? state['mapping'] : {})
          out = {}
          BuildPlan::GENERIC_TYPES.each do |gt|
            out[gt] = HardwareSets.set_options(gt, lib['sets'], snap_sets, refs).map do |s|
              { 'set_id' => s['set_id'], 'name' => s['name'],
                'project_copy' => lib['sets'].none? { |g| g['set_id'] == s['set_id'] } }
            end
          end
          out
        end

        # D-75: po KAZDEJ uspesnej zmene setov/predvolieb — obnova okna +
        # ZIVY push ponuky do panela (NX.setHardwareSets). NIKDY push_selected:
        # ten resetuje rozpracovany formular panela a dedup-uje kopie
        # (= zmena v satelitnom okne by siahla na model).
        def after_sets_change(model = nil)
          push_sets
          Panel.push_hardware_sets if defined?(Panel) && Panel.dialog_alive?
          # ŠT-1c PR B3: vetva okna Vyroba tu zanikla spolu s oknom.
          StudioDialog.on_model_changed(model) if model && defined?(StudioDialog) # ST-1a
        end

        # Hodnota mapovania z okna: 'value' = set_id String ALEBO selector Hash
        # (H1b vyber podla parametra); stary kluc 'set_id' ostava kompatibilny.
        # Prazdne = odmapovanie (nil). Tvar validuje VYHRADNE core parser.
        def mapping_value(data)
          raw = data.key?('value') ? data['value'] : data['set_id']
          return nil if raw.nil?
          return raw if raw.is_a?(Hash)

          s = raw.to_s.strip
          s.empty? ? nil : s
        end

        def handle_set_save(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareSets.save_set!(data['set'].is_a?(Hash) ? data['set'] : {},
                                                revision: data['revision'].to_s,
                                                create: data['create'] == true)
          case status
          when :ok
            after_sets_change # D-75: nový/upravený set je HNEĎ aj v selectoch panela
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
            after_sets_change
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
          value = mapping_value(data)
          set_defs = nil
          if value
            # H1b: hodnota moze byt selector — tvar overi PARSER (jedina
            # autorita) a do snapshotu sa musia zmrazit VSETKY sety, na ktore
            # ukazuje (audit BLOCKER 1). Definicie berie resolver: pre set_id,
            # ktore projekt uz pouziva, vyhrava snapshot (BLOCKER 4).
            vstatus, norm, refs = HardwareSets.parse_mapping_value(value)
            return set_status("Výber sa nedá uložiť — #{norm}.", true) unless vstatus == :ok

            set_defs = refs.map { |sid| HardwareSets.resolve_set_def(model, sid) }
            if set_defs.any?(&:nil?)
              push_sets
              return set_status('Set sa v knižnici nenašiel — obnovené.', true)
            end
            bad = set_defs.find { |d| d['generic_type'] != gt }
            return set_status("Set „#{bad['name']}“ je iného typu kovania.", true) if bad
          end
          # Zapis = 1 undo krok; snapshot dostane mapping AJ definicie (B2).
          model.start_operation('NOXUN: Predvoľba setu kovania', true)
          ok = HardwareSets.set_project_mapping!(model, gt, value, set_defs)
          if ok
            model.commit_operation
            after_sets_change(model)
            # Editor pasiem sa zatvara AZ po uspesnom zapise (echo kluca) —
            # pri chybe ostane rozpisany na doopravenie (vzor HWSETS.saved).
            js("HWSETS.mapSaved(#{data['ui_key'].to_s.to_json})")
            set_status(mapping_status_txt(gt, value, set_defs))
          else
            model.abort_operation
            push_sets
            set_status('Predvoľba sa nedá uložiť — sety projektu sú poškodené (tlačidlo Obnoviť).', true)
          end
        end

        # „Výsuv → Atira biela H70." / „Výsuv → podľa výšky čela (2 pásma)."
        def mapping_status_txt(gt, value, set_defs)
          label = HardwareRules.label_for(gt)
          return "#{label} — bez setu." if value.nil?
          if value.is_a?(Hash)
            n = Array(value['bands']).length
            return "#{label} → #{HardwareSets.param_by(value['param'])} (#{n} #{n == 1 ? 'pásmo' : 'pásma'})."
          end
          "#{label} → #{(set_defs || []).first&.fetch('name', value) || value}."
        end

        def handle_map_global(payload)
          data = JSON.parse(payload.to_s)
          ok = HardwareSets.set_global_mapping!(data['generic_type'].to_s, mapping_value(data))
          after_sets_change
          js("HWSETS.mapSaved(#{data['ui_key'].to_s.to_json})") if ok
          set_status(ok ? 'Globálna predvoľba uložená (platí pre nové projekty).' : 'Globálna predvoľba sa nedá uložiť — skontroluj pásma a sety.', !ok)
        end

        # H1b (audit FIX 10): vedome DOPLNENIE chybajucich globalnych predvolieb
        # do projektu — vzor „Doplniť nové predvolené" v okne Pravidlá.
        # Existujuce mapovania sa NEPREPISUJU (to robi len Obnoviť) a ziadna
        # definicia zo snapshotu sa neodstranuje. 1 undo krok.
        def handle_merge_seed(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return set_status('Žiadny aktívny model.', true) if model.nil?
          if data['model_guid'].to_s != model.guid.to_s
            push_sets
            return set_status('Model sa medzitým prepol — obnovené.', true)
          end
          status, = HardwareSets.project_state_status(model)
          if status == :missing
            return set_status('Projekt zatiaľ preberá globálne predvoľby celé — nie je čo dopĺňať.')
          end
          if status == :invalid
            return set_status('Predvoľby projektu sú poškodené — použi „Obnoviť z globálnych predvolieb".', true)
          end

          model.start_operation('NOXUN: Doplnenie predvolieb setov', true)
          res, added_sets, added_map = HardwareSets.merge_project_sets_seed!(model)
          res == :updated ? model.commit_operation : model.abort_operation
          after_sets_change(model)
          if res == :updated
            labels = added_map.map { |gt| HardwareRules.label_for(gt) }
            set_status("Doplnené predvoľby: #{labels.join(', ')} (#{added_sets.length} " \
                       "#{added_sets.length == 1 ? 'nový set' : 'nových setov'}). Existujúce zostali.")
          else
            set_status('Projekt už má všetky globálne predvoľby — nič sa nedopĺňalo.')
          end
        rescue StandardError => e
          model.abort_operation if model
          raise e
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
          # H1a: skladanie globalneho defaultu je JEDNA autorita v core
          # (global_default_state) — zvlada aj vyber setu podla parametra.
          state = HardwareSets.global_default_state
          model.start_operation('NOXUN: Obnova predvolieb setov', true)
          ok = HardwareSets.write_project_state(model, state)
          ok ? model.commit_operation : model.abort_operation
          after_sets_change(ok ? model : nil) # D-75: aj panel dostane novú ponuku
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
