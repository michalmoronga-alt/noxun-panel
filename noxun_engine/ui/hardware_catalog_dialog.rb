# frozen_string_literal: true
# Noxun Engine — SERVEROVA AUTORITA KATALOGU KOVANIA.
#
# ŠT-3a-2: satelitne okno „Katalóg kovania" ZANIKLO (HtmlDialog, `DLG_KEY`,
# `hardware_catalog.html`, polozka menu aj panelove tlacidlo). Jedine UI
# katalogu je odteraz SEKCIA `hw` v okne ŠTÚDIO. Modul sa pritom ZAMERNE
# NEPREMENUVA (vzor audit #21 zo ŠT-2a): zaniklo OKNO, nie serverova
# autorita — telo kazdej akcie, vsetky guardy (`row_rev`, `revision`,
# `model_guid`), Demos konektor aj cenovy proposal flow ziju dalej TU.
#
# Server je autorita: search VYHRADNE Ruby (audit C F12; JS len renderuje
# vratene poradie), cenove overenie je serverovy proposal (BLOCKER 1) — JS
# posiela len kod a `pid`, hodnoty nikdy.
#
# ADRESAT odpovede:
#   * pocas synchronneho volania sekcie ho drzi `with_client(sink)`,
#   * mimo neho (asynchronne emity, refresh cesty zvonku) ide vsetko do
#     Studia cez `StudioDialog.hw_js` — druhe UI uz neexistuje.
#
# Request generation (F9): kazdy check_price/nahlad nesie gen; vysledok so
# starym gen sa zahodi. ZIVOTNOST behu drzi SESSION TOKEN sekcie
# (`@section_session`) — zhasina ho zatvorenie Studia, prepnutie dokumentu
# a odchod zo sekcie `hw`; identitu behu drzi `run_id` (dve nezavisle
# generacie nad jednym priznakom by si inak siahali na cudzie).
require 'json'

module Noxun
  module Engine
    module HardwareCatalogDialog
      # ŠT-3a-1: UZAVRETY whitelist akcii, ktore smie poslat SEKCIA `hw`.
      # Klient (Studio) posiela iba MENO akcie — co sa smie zavolat, rozhoduje
      # SERVER (HTML ani JS nie su ochrana).
      #
      # ŠT-3a-2: pribudli tri MODELOVE zapisy — `hws_map_project`,
      # `hws_merge_seed`, `hws_reset_project` (predvolby setov PROJEKTU).
      # Kazdy z nich je `start_operation` … `commit_operation`, teda 1 zmena =
      # 1 krok Spat, a kazdy ma serverovy `model_guid` guard: zapis zo
      # zastaraneho UI sa odmietne a stav sa obnovi. S nimi zanikol read-only
      # rezim bloku „Predvoľby projektu" aj premostenie do okna — okno uz
      # neexistuje.
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
        hws_map_project hws_merge_seed hws_reset_project
      ].freeze

      # TEST-1: stropy serveroveho hladania. ZOZNAM (prazdny dotaz bez
      # kategorie) ma VYSSI strop nez hladanie — zaklad katalogu ma byt
      # vidiet cely, kym je to lacne; nad strop sa orezanie PRIZNA cislom.
      SEARCH_TOP = 50
      EMPTY_TOP = 200

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
          # ŠT-3a-2: MODELOVE zapisy (predvolby setov projektu). Kazdy z nich
          # otvara vlastnu operaciu (1 zmena = 1 krok Spat) a kazdy si overuje
          # `model_guid` z payloadu — zapis zo zastaraneho UI sa odmietne.
          when 'hws_map_project'   then handle_map_project(payload)
          when 'hws_merge_seed'    then handle_merge_seed(payload)
          when 'hws_reset_project' then handle_reset_project(payload)
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

        # ŠT-3a-2: adresat je uz LEN sekcia — okno zaniklo, takze `run_target`
        # nesie iba to, co sa NESMIE stratit: SESSION TOKEN zachyteny pri
        # STARTE behu. Bez neho by ABA (zatvorenie a znovuotvorenie Studia,
        # prepnutie dokumentu) prepustilo vysledok stareho behu do noveho
        # kontextu. Identitu behu drzi zvlast `run_id` (viz `mark_running`).
        def run_target
          { session: @section_session.to_i }
        end

        def target_alive?(target)
          @section_session.to_i == target[:session] &&
            defined?(StudioDialog) && StudioDialog.dialog_alive?
        end

        def emit_status(msg, error = false)
          studio_js(status_script(msg, error))
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
        #
        # ŠT-3a-2: rozlisenie `target` zaniklo spolu s oknom — bezat moze uz
        # len sekcia. Identita behu (`run_id`) ostava: `@gen` a `@demos_gen` su
        # dve nezavisle pocitadla nad JEDNYM priznakom.
        def mark_running(label)
          id = (@section_run_id = @section_run_id.to_i + 1)
          @section_running = { 'label' => label.to_s, 'id' => id }
          id
        end

        def clear_running(id = nil)
          run = @section_running
          return unless run.is_a?(Hash)
          return if id && run['id'] != id

          @section_running = nil
        end

        # --- Ruby -> JS ------------------------------------------------------
        #
        # ŠT-3a-2: `push_state` (`MDH.init` do okna) ZANIKLO spolu s nim —
        # prvotny stav sekcie nesie `push_state` Studia pod klucom `hw`
        # (`state_payload` nizsie je jeho zdrojom). Ostava JEDNA cesta:
        # katalogove echo.

        # ŠT-3a-1: katalogovy zapis sa posiela BEZ ohladu na to, kto ho vyvolal
        # (`js` so sinkom by obsluzil len volajuceho) — po ŠT-3a-2 uz ma jediny
        # ciel, sekciu.
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

        # Stavovy riadok sekcie: prijimac `MDH.setStatus` je v tom istom
        # `js/hw_catalog.js`, ktory sekcia nacitava, a `#status` je uzol
        # `studio.html`. Text sklada SERVER (jedna autorita).
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
            # Zivotnost behu drzi SESSION TOKEN sekcie zachyteny pri
            # STARTE (ABA); identitu behu `run_id` (viz `mark_running`).
            target = run_target
            run_id = mark_running('sťahovanie zoznamu produktov Demosu')
            js("MDH.demosResults(#{{ 'query' => query, 'results' => [],
                                     'refreshing' => true }.to_json})")
            DemosLookup.start_refresh do |ok, err|
              # Review kolo 2 (P2-1): gasi sa PRED guardom adresata (mrtve
              # Studio nie je dovod nechat priznak visiet) a VYHRADNE vlastny
              # beh — medzitym mohol v sekcii zacat iny.
              clear_running(run_id)
              next unless target_alive?(target)

              if ok
                studio_js('MDH.demosRefreshDone()')
              else
                emit_status("Zoznam produktov sa nepodarilo stiahnuť: #{err}", true)
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
        # novsi nahlad ani ozivit nahlad zruseny pouzivatelom).
        #
        # `@demos_gen` je generacia nahladu: server si odklada JEDEN proposal,
        # takze dva subezne nahlady by si aj tak siahali na to iste — generacia
        # spravne hovori „posledny vyhrava". (Do ŠT-3a-2 bola spolocna aj
        # s oknom Katalog kovania; to zaniklo, klient je uz len jeden.)
        def handle_demos_preview(payload)
          data = JSON.parse(payload.to_s)
          gen = bump_demos_gen
          target = run_target
          run_id = mark_running('náhľad položky z Demosu')
          HardwareCatalog.demos_preview!(data['url'].to_s) do |res|
            # Review kolo 2 (P2-1) — to iste ako pri overeni ceny: gasi sa
            # podla IDENTITY behu, nie podla generacie. `@gen` a `@demos_gen`
            # su dve pocitadla nad jednym priznakom, takze podmienka na
            # generaciu unikala na obe strany.
            clear_running(run_id)
            next unless @demos_gen.to_i == gen && target_alive?(target)

            studio_js("MDH.demosPreview(#{res.merge('gen' => gen).to_json})")
          end
        end

        # GH #128 P2: „Zrušiť náhľad" pri bežiacom fetchi — bump generacie
        # zahodi dobiehajúci vysledok (inak by sa zruseny nahlad znovu otvoril).
        def handle_demos_cancel(_payload)
          bump_demos_gen
          # ZAMERNE bez `run_id`: je to VYSLOVNE zrusenie pouzivatelom, takze
          # zhasina to, co v sekcii prave bezi — nie konkretny beh.
          clear_running
        end

        def handle_demos_create(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareCatalog.create_from_demos!(
            data['pid'].to_s, category: data['category'].to_s, notes: data['notes'].to_s
          )
          case status
          when :ok
            push_items
            js("MDH.demosCreated(#{info['item_code'].to_s.to_json})")
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
        # Prepnutie modelu (EngineAppObserver). ŠT-3a-2: modul uz ziadne UI
        # nevlastni — refresh sekcie robi Studio samo (`StudioDialog
        # .on_model_changed` z toho isteho broadcastu, plny push nesie sety
        # v `hw` payloade). Ostava tu VYHRADNE zivotny cyklus serverovych
        # behov: cudzi dokument nesmie dostat vysledok behu, ktory patril
        # predoslemu — a `@section_running` po nom nesmie zostat horiet, inak
        # by odchod zo sekcie hlasil zrusenie behu, ktory uz davno neexistuje.
        # (Vetva sa NERUSI: precedens `MaterialsDialog.on_model_changed`.)
        def on_model_changed(_model)
          section_bump_session
          @section_running = nil
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.on_model_changed')
        end

        # ZOTAVOVACIA obnova po ODMIETNUTOM zapise (`:conflict`, `:not_found`,
        # neznáme zlyhanie). Je to iny pripad nez USPESNY zapis:
        #   * hlaska hovori „obnovené", takze klient MUSI dostat cerstvu
        #     `revision`. Kym ju sekcia nedostala, poslala by dalsi zapis so
        #     STARYM odtlackom a zacyklila by sa v konfliktoch;
        #   * `:not_found` (set uz niekto zmazal) by v sekcii neurobilo NIC —
        #     zoznam by dalej ukazoval zaznam, ktory neexistuje.
        # NIE JE to `after_sets_change`: nic sa NEZAPISALO, takze nakupny zoznam
        # ani panel sa nemenia a plny push Studia by bol zbytocny prepocet
        # kusovnika (a druhe vykreslenie setov navyse).
        #
        # ŠT-3a-2: `push_sets` (win-only echo) ZANIKOL a VSETKYCH pat jeho
        # volani v zotavovacich vetvach modelovych handlerov prislo sem —
        # odmietnuty zapis musi obnovit UI, ktore o neho poziadalo, a to je
        # uz len sekcia.
        def resync_sets
          StudioDialog.push_hw_sets(sets_payload) if defined?(StudioDialog)
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.resync_sets')
        end

        # F4: model chodi ARGUMENTOM. `hw_payload` Studia podava SVOJ model —
        # pri prepnuti dokumentu by inak sekcia dostala predvolby STAREHO
        # dokumentu vedla kusovnika noveho (broadcast prepnutia moze prist
        # skor, nez sa `Sketchup.active_model` prepne).
        def sets_payload(model = Sketchup.active_model)
          lib = HardwareSets.load
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
            # R-06 (brana 1d): typ `handle` sa TU nezakazuje ani po nej —
            # kusova uchytka je legitimne mapovanie a zakaz typu by ju vzal
            # tiez. Nebezpecna je len polozka, ktora sa REZE NA DLZKU
            # (uchytkovy profil D-90), a tu zastavi SERVEROVA brana v
            # HardwareSets.expand — plati aj pre sety ulozene v starsom .skp,
            # kam by kontrola v editore nedosiahla.
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

        # D-75: po KAZDEJ uspesnej zmene setov/predvolieb — ZIVY push ponuky
        # do panela (NX.setHardwareSets) + obnova Studia. NIKDY push_selected:
        # ten resetuje rozpracovany formular panela a dedup-uje kopie
        # (a predvolba setu geometriu nemeni, takze dedup tik ani nehrozi).
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
        #
        # ŠT-3a-2: vetva okna (`push_sets`) zanikla; panel ZOSTAVA (zije dalej
        # a jeho selecty setov musia byt cerstve). Modelovy zapis ide
        # `bump: true` — a to STACI: predvolba setu nemeni GEOMETRIU, takze
        # `Panel.push_selected` (dedup kopii) sa vedome NEVOLA. Jantar
        # „Obnoviť" po vlastnom zapise NEZOZLTNE: `push_state` si uklada
        # `@pushed_epoch` az PO zbere, takze vlastnu transakciu pohlti.
        def after_sets_change(model = nil)
          Panel.push_hardware_sets if defined?(Panel) && Panel.dialog_alive?
          # ŠT-1c PR B3 tu zrusila vetvu okna Vyroba, ŠT-3a-2 vetvu okna
          # Katalog kovania (`push_sets`) — sekcia dostava sety plnym pushom.
          StudioDialog.refresh_if_open(bump: !model.nil?) if defined?(StudioDialog) # ST-1a
        end

        # ŠT-3a-3: JEDNA cesta zatvorenia operacie pre vsetky TRI modelove
        # zapisy. Vynimka medzi `start_operation` a `commit_operation` nechavala
        # operaciu OTVORENU — dalsi zapis do modelu by sa do nej pribalil a jeden
        # krok Spat by vratil OBA (kontrakt „1 zmena = 1 krok Späť" by padol).
        # Priznak je EXPLICITNY, nie dopyt na API: po `commit_operation` uz nie je
        # co abortovat a `abort_operation` by v najhorsom pripade siahol na cudziu
        # operaciu — preto sa rusi VYHRADNE operacia, ktoru tento handler otvoril
        # a este nezavrel.
        def abort_open_operation(model, state)
          return unless model && state.is_a?(Hash) && state[:open]

          state[:open] = false
          model.abort_operation
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.abort_open_operation')
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
            # ŠT-3a-2 (dlh z review #216): vetva bola NEMA — zoznam sa pod
            # rukami prekreslil a pouzivatel nevedel, ci sa nieco stalo.
            resync_sets # set uz niekto zmazal — sekcia ho nesmie dalej ukazovat
            set_status('Set už neexistoval — zoznam obnovený.')
          else
            set_status('Zmazanie setu zlyhalo.', true)
          end
        end

        def handle_map_project(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return set_status('Žiadny aktívny model.', true) if model.nil?
          if data['model_guid'].to_s != model.guid.to_s
            resync_sets
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
              resync_sets
              return set_status('Set sa v knižnici nenašiel — obnovené.', true)
            end
            bad = set_defs.find { |d| d['generic_type'] != gt }
            return set_status("Set „#{bad['name']}“ je iného typu kovania.", true) if bad
          end
          # Zapis = 1 undo krok; snapshot dostane mapping AJ definicie (B2).
          op = { open: false }
          model.start_operation('NOXUN: Predvoľba setu kovania', true)
          op[:open] = true
          ok = HardwareSets.set_project_mapping!(model, gt, value, set_defs)
          if ok
            model.commit_operation
            op[:open] = false
            after_sets_change(model)
            # Editor pasiem sa zatvara AZ po uspesnom zapise (echo kluca) —
            # pri chybe ostane rozpisany na doopravenie (vzor HWSETS.saved).
            js("HWSETS.mapSaved(#{data['ui_key'].to_s.to_json})")
            set_status(mapping_status_txt(gt, value, set_defs))
          else
            abort_open_operation(model, op)
            resync_sets
            set_status('Predvoľba sa nedá uložiť — sety projektu sú poškodené (tlačidlo Obnoviť).', true)
          end
        rescue StandardError => e
          abort_open_operation(model, op)
          raise e
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
            resync_sets
            return set_status('Model sa medzitým prepol — obnovené.', true)
          end
          status, = HardwareSets.project_state_status(model)
          if status == :missing
            return set_status('Projekt zatiaľ preberá globálne predvoľby celé — nie je čo dopĺňať.')
          end
          if status == :invalid
            return set_status('Predvoľby projektu sú poškodené — použi „Obnoviť z globálnych predvolieb".', true)
          end

          op = { open: false }
          model.start_operation('NOXUN: Doplnenie predvolieb setov', true)
          op[:open] = true
          res, added_sets, added_map = HardwareSets.merge_project_sets_seed!(model)
          if res == :updated
            model.commit_operation
            op[:open] = false
          else
            abort_open_operation(model, op)
          end
          # F8 (fix nalezu auditu): pri NO-OPE (`abort_operation` — projekt uz
          # ma vsetky globalne predvolby) sa NEVOLA `after_sets_change` VOBEC.
          # Nic sa nezmenilo, takze plny prepocet kusovnika by bol zbytocny
          # a zdvih generacie by navyse zneplatnil rozkliknuty riadok
          # Kusovnika a rozrobeny export inej sekcie — po akcii, ktora
          # NIC neurobila. Status staci.
          unless res == :updated
            return set_status('Projekt už má všetky globálne predvoľby — nič sa nedopĺňalo.')
          end

          after_sets_change(model)
          labels = added_map.map { |gt| HardwareRules.label_for(gt) }
          set_status("Doplnené predvoľby: #{labels.join(', ')} (#{added_sets.length} " \
                     "#{added_sets.length == 1 ? 'nový set' : 'nových setov'}). Existujúce zostali.")
        rescue StandardError => e
          # ŠT-3a-3: rusi sa LEN operacia, ktora je este otvorena. Doteraz
          # tu bolo bezpodmienecne `abort_operation` — vynimka v `set_status`
          # ci v `after_sets_change` (teda UZ PO commite) by tak zrusila
          # zapis, ktory sa pouzivatelovi prave potvrdil.
          abort_open_operation(model, op)
          raise e
        end

        # F9: VEDOMA obnova poskodenych/chybajucich predvolieb projektu z
        # globalnych — jedina cesta, ktora invalid snapshot prepise.
        def handle_reset_project(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return set_status('Žiadny aktívny model.', true) if model.nil?
          if data['model_guid'].to_s != model.guid.to_s
            resync_sets
            return set_status('Model sa medzitým prepol — obnovené.', true)
          end
          # H1a: skladanie globalneho defaultu je JEDNA autorita v core
          # (global_default_state) — zvlada aj vyber setu podla parametra.
          state = HardwareSets.global_default_state
          op = { open: false }
          model.start_operation('NOXUN: Obnova predvolieb setov', true)
          op[:open] = true
          ok = HardwareSets.write_project_state(model, state)
          if ok
            model.commit_operation
            op[:open] = false
            after_sets_change(model) # D-75: aj panel dostane novú ponuku
          else
            # ŠT-3a-3: NIC sa nezapisalo, takze ziadny plny push — stacilo by
            # to len zbytocny prepocet kusovnika. Sekcia vsak MUSI dostat
            # cerstvy stav: hlaska hovori o zlyhani a zoznam pred nou uz
            # nemusi platit (vzor ostatnych zotavovacich vetiev).
            abort_open_operation(model, op)
            resync_sets
          end
          set_status(ok ? 'Predvoľby projektu obnovené z globálnych.' : 'Obnova zlyhala.', !ok)
        rescue StandardError => e
          abort_open_operation(model, op)
          raise e
        end

        # Odpoved ide TOMU, KTO sa pytal. Sink zije PRESNE jeden synchronny
        # callback sekcie (`with_client`); mimo neho — refresh cesty zvonku
        # aj ASYNCHRONNE emity, ktore dobiehaju z casovaca uz po navrate
        # z `dispatch` — je adresat od ŠT-3a-2 JEDINY mozny: okno Studio.
        def js(script)
          sink = @client_sink
          return sink.call(script) if sink

          studio_js(script)
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
        # TEST-1: dve veci, ktore zhoreli pri prvom teste v0.8.0.
        #
        # 1) ZAKLADNY ZOZNAM je serverovy search s PRAZDNYM dotazom. Radi sa
        #    score -> -use_count -> kod, takze NOVA polozka (`use_count` 0)
        #    skoncila az za koncom orezania a z UI zmizla BEZ SLOVA. Prazdny
        #    dotaz ma preto vlastny, vyssi strop (`EMPTY_TOP`) a klient dostava
        #    `total` — hint o orezani sa vypise pri KAZDOM orezani, aj pri
        #    hladani (zasada „no silent caps"). Payload ostava lacny: posielaju
        #    sa LEN kody, polozky uz klient ma.
        #
        # 2) `pin` = kod prave vytvorenej polozky. Poradie NADALEJ sklada
        #    SERVER (kontrakt GH #100 P2 — JS ho nikdy nedoplna): klient len
        #    povie, ktoru polozku prave zalozil, a server ju da NAVRCH. Bez
        #    toho ju Michal po pridani musel hladat.
        def handle_search(payload)
          data = JSON.parse(payload.to_s)
          query = data['query'].to_s
          category = data['category'].to_s
          top = query.strip.empty? && category.strip.empty? ? EMPTY_TOP : SEARCH_TOP
          results, total = HardwareCatalog.search_with_total(
            HardwareCatalog.items, query,
            category: category,
            include_inactive: data['include_inactive'] == true,
            top: top
          )
          codes = results.map { |i| i['item_code'] }
          pin = pinned_code(data['pin'].to_s)
          codes = ([pin] + (codes - [pin])).first(top) if pin
          js("MDH.results(#{{ 'codes' => codes, 'query' => query,
                              'total' => total, 'shown' => codes.length,
                              'pin' => pin }.to_json})")
        end

        # Pin sa pusti LEN ked taka polozka v katalogu naozaj je — inak by
        # zmiznuta (alebo vymyslena) polozka posunula poradie o prazdny riadok.
        def pinned_code(code)
          return nil if code.strip.empty?

          HardwareCatalog.items.any? { |i| i['item_code'].to_s == code } ? code : nil
        end

        def handle_create(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareCatalog.create_item(data['fields'].is_a?(Hash) ? data['fields'] : {})
          case status
          when :ok
            push_items
            set_status("Položka #{info['item_code']} pridaná.")
            # TEST-1: kod ide klientovi, aby si ho vypytal NAVRCH zoznamu
            # (`pin`) a zvyraznil ho — inak nova polozka utopi v katalogu.
            js("MDH.created(#{info['item_code'].to_s.to_json})")
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
        # `@gen` je generacia cenoveho overenia: server drzi JEDEN navrh per
        # kod (`pid`), takze dve subezne overenia by si aj tak siahali na to
        # iste. Zivotnost vysledku strazi `run_target` (session token sekcie).
        # (Do ŠT-3a-2 bola generacia spolocna aj s oknom; to zaniklo.)
        def handle_check_price(payload)
          data = JSON.parse(payload.to_s)
          code = data['code'].to_s
          gen = bump_gen
          target = run_target
          run_id = mark_running('overenie ceny z Demosu')
          HardwareCatalog.check_price!(code, url: data['url'].to_s) do |res|
            # Review kolo 2 (P2-1): priznak sa gasi AJ ked vysledok nikam
            # nepojde (zavrete Studio, odchod zo sekcie, prekonanie cudzou
            # generaciou) — a gasi VYHRADNE vlastny beh (`run_id`), takze
            # nesiahne na nahlad z Demosu, ktory medzitym zacal.
            clear_running(run_id)
            next unless @gen.to_i == gen && target_alive?(target)

            studio_js("MDH.priceResult(#{res.merge('code' => code, 'gen' => gen).to_json})")
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
