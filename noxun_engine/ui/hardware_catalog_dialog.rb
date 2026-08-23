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
#
# ŠT-3a-1: katalog ma od tejto davky DVE UI — toto okno (zije dalej, zanikne
# v ŠT-3a-2) a SEKCIU `hw` okna ŠTÚDIO. Telo kazdej akcie ostava TU (vzor
# audit #21 ŠT-2a: modul sa NEPREMENUVA), zmenil sa jediny detail: ADRESAT
# odpovede.
#
#   * pocas synchronneho volania sekcie ho drzi `with_client(sink)`,
#   * mimo neho ide odpoved do OKNA (`win_js`),
#   * ASYNCHRONNY beh (overenie ceny, nahlad z Demosu) si pamata, KTO ho
#     spustil (`run_target`): pre okno plati povodny okno-guard
#     (`@dialog.equal?(dlg) && visible?`), pre sekciu SESSION TOKEN
#     (`@section_session`), ktory zhasina zatvorenie Studia, prepnutie
#     dokumentu a ODCHOD zo sekcie `hw`.
require 'json'

module Noxun
  module Engine
    module HardwareCatalogDialog
      DLG_KEY = 'noxun_engine_hw_catalog_v1'

      # ŠT-3a-1: UZAVRETY whitelist akcii, ktore smie poslat SEKCIA `hw`.
      # Klient (Studio) posiela iba MENO akcie — co sa smie zavolat, rozhoduje
      # SERVER (HTML ani JS nie su ochrana).
      #
      # Su tu LEN KATALOGOVE zapisy (globalny %APPDATA% katalog + kniznica
      # setov). Tri akcie, ktore menia MODEL — `hws_map_project`,
      # `hws_merge_seed`, `hws_reset_project` — v tejto davke ZAMERNE CHYBAJU:
      # ich presun (a s nim aj zanik tohto okna) je dávka ŠT-3a-2. Sekcia ich
      # preto nekresli ako ovladace, ale ako PREMOSTENIE do tohto okna
      # (`hw_open_window` v `studio_dialog.rb`) — vzor `MAT_BRIDGE_STATUS`
      # zo ŠT-2a.
      #
      # `ready` v zozname NIE JE (a byt nemoze): Studio registruje callbacky
      # pod TYMI ISTYMI menami, takze `ready` by prepisal jeho vlastny — okno
      # by prestalo dostavat prvy push. Prvotny stav sekcie preto nesie
      # `push_state` Studia pod klucom `hw` (zapadka `@hw_full_pending`,
      # presny vzor `mat` zo ŠT-2a).
      SECTION_ACTIONS = %w[
        hw_search hw_create hw_patch hw_delete
        hw_check_price hw_apply_price
        hw_demos_search hw_demos_preview hw_demos_cancel hw_demos_create
        hws_save_set hws_delete_set hws_map_global
      ].freeze

      class << self
        # --- ŠT-3a-1: vstup SEKCIE `hw` (vzor MaterialsDialog.dispatch) ------

        # Vykona akciu katalogu v mene SEKCIE. `sink` je proc, ktory dostane
        # hotovy JS retazec a posle ho tomu, KTO sa pytal. Volanie je
        # synchronne, takze sink zije presne jeden callback — asynchronne
        # pokracovanie (fetch z Demosu) uz ide cestou `run_target`.
        def dispatch(name, payload, sink)
          key = name.to_s
          unless SECTION_ACTIONS.include?(key)
            return sink.call(status_script('Neznáma akcia katalógu kovania.', true))
          end

          with_client(sink) { run_section_action(key, payload) }
        rescue StandardError => e
          Engine.log_error(e, "HardwareCatalogDialog.dispatch #{name}")
          sink.call(status_script("Chyba: #{e.message}", true))
        end

        def run_section_action(key, payload)
          case key
          when 'hw_search'         then handle_search(payload)
          when 'hw_create'         then handle_create(payload)
          when 'hw_patch'          then handle_patch(payload)
          when 'hw_delete'         then handle_delete(payload)
          when 'hw_check_price'    then handle_check_price(payload)
          when 'hw_apply_price'    then handle_apply_price(payload)
          when 'hw_demos_search'   then handle_demos_search(payload)
          when 'hw_demos_preview'  then handle_demos_preview(payload)
          when 'hw_demos_cancel'   then handle_demos_cancel(payload)
          when 'hw_demos_create'   then handle_demos_create(payload)
          when 'hws_save_set'      then handle_set_save(payload)
          when 'hws_delete_set'    then handle_set_delete(payload)
          when 'hws_map_global'    then handle_map_global(payload)
          end
        end

        # Presmerovanie odpovedi na cas JEDNEHO volania. `ensure` je povinne:
        # vynimka v handleri nesmie nechat sink viset, inak by ho zdedila
        # NASLEDUJUCA (aj asynchronna) odpoved a poslala ju do cudzieho kanala.
        def with_client(sink)
          prev = @client_sink
          @client_sink = sink
          yield
        ensure
          @client_sink = prev
        end

        # --- ŠT-3a-1: zivotnost dlhych behov SEKCIE --------------------------
        #
        # Okno ma svoj guard od V0.6 (instancia dialogu + `visible?`). Sekcia
        # ziadnu vlastnu instanciu nema, takze jej zivotnost drzi MONOTONNY
        # session token. Zhasina ho KAZDA udalost, po ktorej uz vysledok nema
        # komu prist:
        #   * zatvorenie Studia (`on_ui_closed` — ABA: nova instancia okna
        #     NESMIE dostat eventy behu, ktory patril starej),
        #   * prepnutie dokumentu (`on_model_changed`),
        #   * ODCHOD zo sekcie `hw` (`cancel_runs_on_leave`).
        def section_bump_session
          @section_session = @section_session.to_i + 1
        end

        # Zatvorene Studio = ziadna sekcia. Beziaci fetch sa zneplatni.
        def on_ui_closed
          section_bump_session
          @section_running = nil
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.on_ui_closed')
        end

        # VEDOME ROZHODNUTIE (vzor ŠT-2b): dlhy beh je viazany na SEKCIU, nie
        # len na okno. Odchod do Kusovnika pocas overovania ceny alebo pocas
        # nahladu z Demosu beh ZRUSI — a povie to nahlas. Nechat ho bezat na
        # pozadi by znamenalo, ze sa vysledok vykresli do sekcie, ktoru uz
        # nikto nepozera; pytat sa pri kazdom prepnuti by otravovalo.
        #
        # Hlaska ide LEN vtedy, ked naozaj nieco bezalo — inak by kazde
        # prepnutie sekcie prepisalo stavovy riadok zbytocnou vetou.
        def cancel_runs_on_leave
          run = @section_running
          section_bump_session
          @section_running = nil
          label = run.is_a?(Hash) ? run['label'].to_s : ''
          return if label.empty?

          studio_js(status_script("Zrušené: #{label} — opustil si sekciu Kovanie.", false))
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.cancel_runs_on_leave')
        end

        # Kto si vyziadal beh — vysledok musi prist JEMU (a len kym ma kam
        # prist). Vnutri `with_client` je to sekcia, inak okno.
        def run_target
          return { kind: :section, session: @section_session.to_i } if @client_sink

          { kind: :window, dlg: @dialog }
        end

        def target_alive?(target)
          if target[:kind] == :section
            @section_session.to_i == target[:session] &&
              defined?(StudioDialog) && StudioDialog.dialog_alive?
          else
            !@dialog.nil? && @dialog.equal?(target[:dlg]) && @dialog.visible?
          end
        end

        def emit(target, script)
          target[:kind] == :section ? studio_js(script) : win_js(script)
        end

        def emit_status(target, msg, error = false)
          emit(target, status_script(msg, error))
        end

        # Beziaci dlhy beh SEKCIE si pamatame kvoli hlaske pri odchode.
        #
        # Review kolo 2 (P2-1): priznak nesie IDENTITU BEHU, nie len popis.
        # `@gen` (cena) a `@demos_gen` (nahlad) su DVE nezavisle pocitadla, ale
        # priznak je JEDEN slot — bez identity unikal na obe strany:
        #   * DNU: zahodeny beh ceny dobehol, kym bezal nahlad z Demosu,
        #     a zhasol CUDZI zivy priznak (odchod potom o zruseni mlcal),
        #   * VON: beh sekcie zabity konkurencnou generaciou z okna sa nemal ako
        #     upratat, priznak visel a odchod vypisal falosne „Zrušené: …".
        # `mark_running` preto vracia ID behu a `clear_running` gasi LEN pri jeho
        # zhode. Volanie BEZ id (vyslovne zrusenie pouzivatelom) zhasina to,
        # co v sekcii prave bezi — to je jeho zmysel.
        def mark_running(target, label)
          return nil unless target[:kind] == :section

          id = (@section_run_id = @section_run_id.to_i + 1)
          @section_running = { 'label' => label.to_s, 'id' => id }
          id
        end

        def clear_running(target, id = nil)
          return unless target[:kind] == :section

          run = @section_running
          return unless run.is_a?(Hash)
          return if id && run['id'] != id

          @section_running = nil
        end

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

        # ŠT-3a-1: OBA ciele naraz. Katalogovy zapis nemeni model, takze sa
        # posiela BEZ ohladu na to, kto ho vyvolal — okno aj sekcia musia
        # ukazovat to iste (`js` so sinkom by obslúžil len volajuceho).
        #
        # `refresh_studio` = plny payload Studia s `bump: false` (vzor
        # `MaterialsDialog.after_catalog_change`): ceny kovania vstupuju do
        # ROZPOCTU, takze sa cislo v inej sekcii naozaj meni — ale identita
        # riadkov nie, takze rozkliknuty riadok Kusovnika ani rozrobeny export
        # po oprave ceny NESMU zastarat. Vypina ho jediny volajuci
        # (`price_refresh_after_proc`), ktory `push_state` robi sam — inak by
        # sa cely kusovnik prepocital dvakrat.
        def push_items(refresh_studio: true)
          payload = items_payload
          win_js("MDH.setItems(#{payload.to_json})")
          StudioDialog.push_hw_catalog(payload) if defined?(StudioDialog)
          # D-92 (audit BLOCKER 2): sekcia Kovanie v paneli ukazuje KODY a NAZVY
          # kupovanych poloziek — po kazdej zmene katalogu ich treba obnovit,
          # inak by drzala stary nazov (alebo „mimo katalógu") az do prekliku
          # vyberu. ZIVY push (NIKDY push_selected — ten siaha na model).
          Panel.push_hardware_sets if defined?(Panel) && Panel.dialog_alive?
          StudioDialog.refresh_if_open(bump: false) if refresh_studio && defined?(StudioDialog)
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

        # Stavovy riadok ma v OBOCH UI ten isty prijimac (`MDH.setStatus`) —
        # sekcia bezi na TOM ISTOM `js/hw_catalog.js` a `#status` je aj
        # v `studio.html`. Text sklada SERVER (jedna autorita).
        def status_script(msg, error = false)
          "MDH.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})"
        end

        def set_status(msg, error = false)
          js(status_script(msg, error))
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
            # ŠT-3a-1: beh patri TOMU, kto ho spustil — okno drzi povodny
            # okno-guard, sekcia session token.
            target = run_target
            run_id = mark_running(target, 'sťahovanie zoznamu produktov Demosu')
            js("MDH.demosResults(#{{ 'query' => query, 'results' => [],
                                     'refreshing' => true }.to_json})")
            DemosLookup.start_refresh do |ok, err|
              # Review kolo 2 (P2-1): gasi sa PRED guardom adresata (mrtve
              # Studio nie je dovod nechat priznak visiet) a VYHRADNE vlastny
              # beh — medzitym mohol v sekcii zacat iny.
              clear_running(target, run_id)
              next unless target_alive?(target)

              if ok
                emit(target, 'MDH.demosRefreshDone()')
              else
                emit_status(target, "Zoznam produktov sa nepodarilo stiahnuť: #{err}", true)
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
        #
        # ŠT-3a-1: `@demos_gen` ostava SPOLOCNY pre okno aj sekciu — vedome.
        # Nahlad si server odklada do JEDNEHO proposal storu, takze dva
        # subezne nahlady (jeden v okne, druhy v sekcii) by si aj tak siahali
        # na to iste; generacia teda spravne hovori „posledny vyhrava".
        def handle_demos_preview(payload)
          data = JSON.parse(payload.to_s)
          gen = bump_demos_gen
          target = run_target
          run_id = mark_running(target, 'náhľad položky z Demosu')
          HardwareCatalog.demos_preview!(data['url'].to_s) do |res|
            # Review kolo 2 (P2-1) — to iste ako pri overeni ceny: gasi sa
            # podla IDENTITY behu, nie podla generacie. `@gen` a `@demos_gen`
            # su dve pocitadla nad jednym priznakom, takze podmienka na
            # generaciu unikala na obe strany.
            clear_running(target, run_id)
            next unless @demos_gen.to_i == gen && target_alive?(target)

            emit(target, "MDH.demosPreview(#{res.merge('gen' => gen).to_json})")
          end
        end

        # GH #128 P2: „Zrušiť náhľad" pri bežiacom fetchi — bump generacie
        # zahodi dobiehajúci vysledok (inak by sa zruseny nahlad znovu otvoril).
        def handle_demos_cancel(_payload)
          bump_demos_gen
          # Priznak gasne len tomu, kto ho zapalil (z okna je to no-op).
          # ZAMERNE bez `run_id`: je to VYSLOVNE zrusenie pouzivatelom, takze
          # zhasina to, co v sekcii prave bezi — nie konkretny beh.
          clear_running(run_target)
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
          # ŠT-3a-1: beziaci beh SEKCIE patril PREDOSLEMU dokumentu.
          section_bump_session
          @section_running = nil
          # Sekcia dostane cerstve sety PLNYM pushom Studia — ten uz z toho
          # isteho broadcastu robi `StudioDialog.on_model_changed`.
          return unless @dialog && @dialog.visible?

          push_sets
        end

        # LEN okno. Po USPESNOM zapise sety sekcia NEDOSTAVA echom: menia aj
        # NAKUPNY zoznam (sekcia Nákup kovania), takze polovicny push by nechal
        # cisla vedla seba rozidene — chodia preto plnym `push_state` (viz
        # `after_sets_change`).
        def push_sets
          win_js("HWSETS.init(#{sets_payload.to_json})")
        end

        # ZOTAVOVACIA obnova po ODMIETNUTOM zapise (`:conflict`, `:not_found`,
        # neznáme zlyhanie). Musi ist do OBOCH UI — a to je iny pripad než
        # `push_sets`:
        #   * hlaska hovori „obnovené", takze klient MUSI dostat cerstvu
        #     `revision`. Kym ju sekcia nedostala, poslala by dalsi zapis so
        #     STARYM odtlackom a zacyklila by sa v konfliktoch;
        #   * `:not_found` (set uz niekto zmazal) by v sekcii neurobilo NIC —
        #     zoznam by dalej ukazoval zaznam, ktory neexistuje.
        # NIE JE to `after_sets_change`: nic sa NEZAPISALO, takze nakupny zoznam
        # ani panel sa nemenia a plny push Studia by bol zbytocny prepocet
        # kusovnika (a druhe vykreslenie setov navyse).
        def resync_sets
          payload = sets_payload
          win_js("HWSETS.init(#{payload.to_json})")
          StudioDialog.push_hw_sets(payload) if defined?(StudioDialog)
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.resync_sets')
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
        # ŠT-3a-1 (oprava nalezu auditu): tato cesta volala
        # `StudioDialog.on_model_changed(model)` — a to je vetva PREPNUTIA
        # DOKUMENTU: prevesila observer neaktualnosti a zdvihla zapadku
        # `@mat_full_pending`, teda po kazdom ulozeni setu preposlala CELY
        # katalog materialov a tvarila sa, ze sa vymenil dokument. Spravna
        # cesta je bezny refresh okna:
        #   * zmena KNIZNICE setov (`model == nil`) — mení sa nákupný zoznam,
        #     ale nie identita riadkov, takze `bump: false` (vzor
        #     `push_mat_catalog` / katalogovych zapisov: rozkliknuty riadok
        #     Kusovnika ani rozrobeny export nesmie zastarat),
        #   * zmena PREDVOLIEB PROJEKTU (`model` je podany) — to uz je zapis
        #     do MODELU, takze generacia sa zdvihnut MA.
        def after_sets_change(model = nil)
          push_sets
          Panel.push_hardware_sets if defined?(Panel) && Panel.dialog_alive?
          # ŠT-1c PR B3: vetva okna Vyroba tu zanikla spolu s oknom.
          StudioDialog.refresh_if_open(bump: !model.nil?) if defined?(StudioDialog) # ST-1a
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
            resync_sets # P1: „obnovené" musi platit AJ pre sekciu (inak slucka konfliktov)
            set_status('Knižnica setov sa medzitým zmenila — obnovené, uprav znova.', true)
          when :invalid
            set_status(info.to_s.empty? ? 'Set sa nedá uložiť.' : info.to_s, true)
          else
            resync_sets
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
            resync_sets
            set_status('Knižnica setov sa medzitým zmenila — obnovené, skús znova.', true)
          when :not_found
            resync_sets # set uz niekto zmazal — sekcia ho nesmie dalej ukazovat
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

        # ŠT-3a-1: odpoved ide TOMU, KTO sa pytal. Sink zije PRESNE jeden
        # synchronny callback sekcie (`with_client`); mimo neho je adresatom
        # OKNO — asynchronny beh si adresata pamata sam (`run_target`).
        def js(script)
          sink = @client_sink
          return sink.call(script) if sink

          win_js(script)
        end

        # Kanal OKNA (do ŠT-3a-1 sa volal `js`).
        def win_js(script)
          return false unless @dialog && @dialog.visible?

          @dialog.execute_script(script)
          true
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.js')
          false
        end

        # Kanal SEKCIE. `js` Studia je private (patri jeho kanalu), preto
        # tenky verejny most `hw_js` — vzor `StudioDialog.mat_js` zo ŠT-2b.
        def studio_js(script)
          return false unless defined?(StudioDialog)

          StudioDialog.hw_js(script)
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.studio_js')
          false
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
        #
        # ŠT-3a-1: `@gen` ostava SPOLOCNY pre okno aj sekciu — server drzi
        # JEDEN cenovy navrh per kod (`pid`), takze dve subezne overenia by
        # si aj tak siahali na to iste. Adresata vysledku urcuje `run_target`.
        def handle_check_price(payload)
          data = JSON.parse(payload.to_s)
          code = data['code'].to_s
          gen = bump_gen
          target = run_target
          run_id = mark_running(target, 'overenie ceny z Demosu')
          HardwareCatalog.check_price!(code, url: data['url'].to_s) do |res|
            # Review kolo 2 (P2-1): priznak sa gasi AJ ked vysledok nikam
            # nepojde (zavrete Studio, odchod zo sekcie, prekonanie cudzou
            # generaciou) — a gasi VYHRADNE vlastny beh (`run_id`), takze
            # nesiahne na nahlad z Demosu, ktory medzitym zacal.
            clear_running(target, run_id)
            next unless @gen.to_i == gen && target_alive?(target)

            emit(target, "MDH.priceResult(#{res.merge('code' => code, 'gen' => gen).to_json})")
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
