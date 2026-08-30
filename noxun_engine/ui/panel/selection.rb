# frozen_string_literal: true
# Noxun Engine - Panel: observer lifecycle (vyber + transakcie) + suspend guard
# + reselect + triedy SelObserver / PanelModelObserver.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- observery vyberu a transakcii ----------------------------------
        # Panel pocuva DVE veci naraz:
        #   SelObserver        — zmena vyberu (klik pouzivatela)
        #   PanelModelObserver — undo/redo/abort transakcie (D-101)
        # ATOMICKY lifecycle (Codex audit D-101, BLOCKER): kazdy observer ma
        # vlastny chraneny remove; ked attach druheho zlyhá, prvy sa vrati spat
        # (rollback) — nikdy nesmie ostat „polovicny" stav, kde panel pocuva
        # vyber, ale nie transakcie (alebo naopak).
        def attach_observer
          model = Sketchup.active_model
          @observer ||= SelObserver.new
          @model_observer ||= PanelModelObserver.new
          sel_attached = false
          begin
            observer_quiet { model.selection.remove_observer(@observer) } # anti-double
            model.selection.add_observer(@observer)
            sel_attached = true
            observer_quiet { model.remove_observer(@model_observer) } # anti-double
            model.add_observer(@model_observer)
          rescue StandardError
            # rollback uz pripojenej polovice — polovicny attach je horsi nez ziadny
            observer_quiet { model.selection.remove_observer(@observer) } if sel_attached
            raise
          end
          @observer_model = model
          ensure_app_observer
        rescue StandardError => e
          Engine.log_error(e, 'Panel.attach_observer')
        end

        # V0.3.4 fix: po File > New / Open panel zil dalej, ale SelectionObserver visel na
        # STAROM modeli — panel sa prestal syncovat s vyberom az do zavretia dialogu.
        # AppObserver (vzor ScaleWatch) pri zmene aktivneho modelu observer prepne a resyncne.
        def ensure_app_observer
          return if @app_observer

          @app_observer = PanelAppObserver.new
          Sketchup.add_observer(@app_observer)
        end

        def on_model_switched(model)
          # GHOST (V1-04) PRVE a BEZ OHLADU na panel: session patri JEDNEMU
          # dokumentu — cross-document vklad nikdy. Identita je OBJEKT modelu
          # (nie guid, ten sa meni pri kazdom ulozeni), takze Ctrl+S ghost
          # nezrusi. Cancel = 0 mutacii modelu, 0 krokov Spat.
          GhostTool.on_model_switched(model) if defined?(GhostTool)
          return unless @dialog # panel zavrety — observer prepne az dalsie otvorenie

          detach_observer
          attach_observer
          # D-89a: zvyraznena hrana patrila STAREMU dokumentu — pri prepnuti sa
          # overlay odpoji (rovnaka zasada ako EdgeCheck.on_model_changed).
          HoverEdge.release if defined?(HoverEdge)
          push_selected(model || Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.on_model_switched')
        end

        # KAZDY observer ma VLASTNY chraneny detach (Codex audit D-101, BLOCKER):
        # zlyhanie prveho remove nesmie preskocit druhy ani predcasne vynulovat
        # @observer_model — inak by na modeli ostal visiaci observer.
        def detach_observer
          model = @observer_model
          return unless model

          detach_one('vyber') { model.selection.remove_observer(@observer) if @observer }
          detach_one('transakcie') { model.remove_observer(@model_observer) if @model_observer }
        ensure
          @observer_model = nil
        end

        def detach_one(label)
          yield
        rescue StandardError => e
          Engine.log_error(e, "Panel.detach_observer (#{label})")
          nil
        end

        # Anti-double remove pred add (vzor edge_check.rb / scale_observer.rb):
        # pri nepripojenom observeri SketchUp nic nespravi, pripadna vynimka je
        # bezvyznamova — preto sa NEloguje (nie je to chyba, je to poistka).
        def observer_quiet
          yield
        rescue StandardError
          nil
        end

        def on_selection_changed
          return if @suspend_selection_sync # nase vlastne reselecty resyncnu panel explicitne

          # Codex #170 P1: pouzivatel klikol v modeli = nova situacia; priznak
          # odmietnuteho apply uz nepatri k tomu, co robi teraz.
          @last_apply_error = nil
          push_selected(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.on_selection_changed')
        end

        # --- D-101: Spat / Znova (Ctrl+Z, Ctrl+Y) ---------------------------
        # Undo/redo meni model, ale ziadny selection event nepride — Inspector
        # visel na predoslom stave az do prekliku vyberu (premenovanie skrinky,
        # vratene rozmery). Callback je TENKY: v observer kontexte sa NIC necita
        # ani nemeni, len sa oznaci pending a naplanuje refresh na timer
        # (vzor EdgeCheck.request_redraw / EdgeModelWatch).
        # Multi-model guard (Codex audit FIX B): udalost z ineho dokumentu nesmie
        # prepisat Inspector aktivneho — a overuje sa ZNOVA v timeri.
        def on_model_txn(model)
          return unless @dialog
          return unless txn_model_ok?(model)

          request_txn_refresh(model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.on_model_txn')
        end

        # Coalescing (Codex audit FIX C): viac rychlych undo/redo za sebou =
        # JEDEN push najnovsieho stavu — dalsia udalost pocas pending uz dalsi
        # timer nepridava.
        def request_txn_refresh(model, delay = 0)
          return if @txn_refresh_pending

          @txn_refresh_pending = true
          UI.start_timer(delay, false) do
            begin
              @txn_refresh_pending = false
              flush_txn_refresh(model)
            rescue StandardError => e
              Engine.log_error(e, 'Panel.request_txn_refresh')
            end
          end
        end

        # Re-check TESNE pred pushom (vzor ScaleWatch.refresh_panel): oneskoreny
        # callback zo stareho dokumentu ani po zatvoreni panela nesmie nic prepisat.
        # KRITICKE `dedup: false` — dedup pyta ScaleWatch.request_dedup (zasah do
        # modelu) a z observer cesty je zakazany (lekcia D-103).
        def flush_txn_refresh(model)
          return unless @dialog
          return unless txn_model_ok?(model)

          # Suspend guard sa testuje AZ TU a udalost sa NEZAHADZUJE (Codex audit
          # NOTE F): pocas naseho vlastneho reselectu sa refresh len odlozi.
          return request_txn_refresh(model, 0.1) if @suspend_selection_sync

          push_selected(model, dedup: false)
        end

        def txn_model_ok?(model)
          !model.nil? && model == @observer_model && model == Sketchup.active_model
        end

        # Programmaticka reselect (nas clear+add po rebuilde) NESMIE rozhodit panel.
        # SketchUp fire pri single `selection.add` callback `onSelectionAdded` (NIE onSelectionBulkChange)
        # a pri `selection.clear` `onSelectionCleared`. Bez potlacenia by preto medzikrok `clear`
        # poslal NX.clearSelected() a vynuloval selectedCabId — a NASLEDNY add uz panel neobnovil
        # (loadSelected nedosiel) -> po prvom drag-u priecky prestal fungovat kazdy dalsi (pouzivatel
        # musel znovu kliknut na korpus). Preto pocas nasej selekcie observer potlacime a panel
        # resyncneme PRESNE raz (push_selected) az po dokonceni. Re-entrantne bezpecne.
        def suspend_selection_sync
          prev = @suspend_selection_sync
          @suspend_selection_sync = true
          yield
        ensure
          @suspend_selection_sync = prev
        end

        # --- pomocne ---------------------------------------------------------
        def finish_cab(model, cab, msg)
          reselect(model, cab)
          status_with_warnings(cab, msg) # BuildPlan upozornenia priamo v statuse
          push_selected(model)
        end

        # Vystup z pripadneho editu komponentu + cisty vyber korpusu (po rebuilde).
        # Cele potlacene pre observer — zavretie editu aj clear/add su NASA zmena; panel
        # resyncne az volajuci cez push_selected (viz suspend_selection_sync).
        def reselect(model, inst)
          suspend_selection_sync do
            begin
              model.active_path = nil
            rescue StandardError
              nil
            ensure
              select_only(model, inst) if inst && inst.valid?
            end
          end
        end

        # V0.4.5 D1: omrvinka karty dielca ("‹ CAB-003") — oznaci korpus v modeli
        # (vyjde z editu komponentu) a panel sa prepne na kontext skrinky.
        # IDENTITY GUARD (Codex #168 P2, 4. kolo): callback HtmlDialogu je
        # asynchronny. ID skriniek sa naprie dokumentmi OPAKUJU, takze oneskoreny
        # klik z dokumentu A by inak oznacil rovnomennu skrinku v dokumente B —
        # a aj v jednom dokumente by prepisal novsi vyber. Preto sa reselect
        # vykona LEN vtedy, ked je stale oznaceny TEN ISTY dielec, z ktoreho
        # sa odchadza. Chybajuce udaje (starsi klient) = spravanie ako doteraz.
        def handle_select_cabinet(payload)
          model = Sketchup.active_model
          data = parse(payload)
          cid = data['cabinet_id'].to_s
          return refresh_after_stale(model) unless select_cabinet_fresh?(model, data)

          cab = find_cabinet_by_id(model, cid)
          return set_status('Skrinka sa nenasla.', true) if cab.nil?
          reselect(model, cab)
          push_selected(model)
        end

        # Je klik stale platny? Dokument sa nesmel prepnut a vo vybere musi byt
        # TEN ISTY dielec (podla kanonickeho role_key), z ktoreho sa odchadza.
        def select_cabinet_fresh?(model, data)
          return false if DocKey.foreign?(data['model_guid'], model, tolerate_blank_client: true)

          want = data['role_key'].to_s
          return true if want.empty? # starsi klient identitu dielca neposielal

          part = find_selected_part(model)
          cab = find_cabinet(model)
          return false if part.nil? || cab.nil?
          return false if Store.get(cab, 'cabinet_id').to_s != data['cabinet_id'].to_s

          params = CabinetBuilder.config_to_params(Store.config(cab) || {})
          canonical_part_key(params, part_identity(cab, part)).to_s == want
        rescue StandardError => e
          Engine.log_error(e, 'Panel.select_cabinet_fresh?')
          false
        end

        # Vyber sa medzitym zmenil — nic sa nepresuva, panel sa len zosuladi.
        def refresh_after_stale(model)
          push_selected(model, dedup: false)
        end

        # UI-B1: krizik docasnej polozky raily pri oznacenej DOSKE — doska nema
        # rodica, na ktoreho by sa dalo vratit, takze sa vyber jednoducho zhodi
        # a panel sa prepne do vkladacieho rezimu. Presne vzor Panel.show_insert
        # (toolbar „Vložiť"): vycistenie pod SUSPEND guardom (inak by observer
        # spustil vlastny druhy refresh) a refresh `dedup: false` — dedup MENI
        # model a z UI akcie sa do modelu nikdy nezapisuje (lekcia D-103).
        #
        # IDENTITY GUARD (Codex #168 P2): callback z HtmlDialogu je asynchronny —
        # kym dobehne, mohol pouzivatel oznacit nieco ine alebo prepnut dokument.
        # Cisti sa preto LEN vtedy, ked je stale vybrata TA ISTA doska, ktoru
        # panel zobrazoval; inak sa vyber nedotkne a panel sa len obnovi.
        # Prazdny/chybajuci board_id = stary klient -> spravanie ako doteraz.
        def handle_clear_selection(payload = nil)
          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          # Codex #168 P2 (2. kolo): ID dosky je jedinecne LEN v ramci modelu
          # (Ids.next_board_id pocita v kazdom dokumente od zaciatku), takze dva
          # otvorene dokumenty bezne obsahuju BRD-001 — bez guidu by oneskoreny
          # callback zhodil vyber v CUDZOM dokumente.
          # PRISNE porovnanie (Codex #168 P2, 5. kolo): `clear_selection` je tiez
          # novy callback — prazdny guid nie je starsi klient, ale okno bez
          # dobehnuteho NX.init, a to nesmie cistit vyber v cudzom dokumente.
          return push_selected(model, dedup: false) if DocKey.foreign?(data['model_guid'], model)

          want = data['board_id'].to_s
          board = find_board(model)
          have = board ? Store.get(board, 'id').to_s : ''
          return push_selected(model, dedup: false) if !want.empty? && want != have

          suspend_selection_sync { model.selection.clear }
          push_selected(model, dedup: false)
        end

        # UI-B3 (N13): klik na „Dielcov" v informacnom stlpci Zakladnych —
        # oznaci VYROBNE dielce tejto skrinky v modeli.
        #
        # CISTE CITANIE MODELU + zmena VYBERU: ziadny `start_operation`, ziadny
        # zapis do dictionary, ziadny krok Spat (lekcia D-103). Vyber sa meni
        # pod `suspend_selection_sync` a panel sa obnovi PRESNE raz — je to ta
        # ista cesta, akou uz oznacuje dielce okno Studio
        # (ProductionCore.do_select), takze sa spravanie nemoze rozist:
        # panel po nej ukaze kartu prveho oznaceneho dielca (rail dostane
        # docasnu polozku) a status povie, kolko ich je oznacenych.
        #
        # IDENTITY GUARD (vzor handle_camera_focus): callback HtmlDialogu je
        # asynchronny — overuje sa DOKUMENT (prisne, ID skriniek sa naprie
        # dokumentmi opakuju) aj to, ze ide stale o TU ISTU skrinku.
        def handle_select_parts(payload = nil)
          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          return set_status('Dielce sa neoznačili — panel patrí inému dokumentu.', true) if
            DocKey.foreign?(data['model_guid'], model)

          # Codex #170 P1: klient pred touto akciou flushol rozpisany edit, ALE
          # server ho mohol odmietnut (material_preflight). Vtedy uz bezal UI
          # resync s POVODNYMI hodnotami — a keby sme teraz oznacili dielce a
          # ohlasili uspech, prekryli by sme jedinu spravu, ktora hovori PRAVDU
          # o tom, preco sa uprava neulozila. Odmietnutie sa preto zopakuje a
          # priznak sa spotrebuje (dalsi klik uz prejde).
          if @last_apply_error
            msg = @last_apply_error
            @last_apply_error = nil
            return set_status("Dielce sa neoznačili — najprv oprav úpravu: #{msg}", true)
          end

          cab = find_cabinet(model)
          return refresh_after_stale(model) if cab.nil? ||
                                               Store.get(cab, 'cabinet_id').to_s != data['cabinet_id'].to_s

          parts = manufactured_parts(cab)
          return set_status('Skrinka nemá výrobné dielce — nie je čo označiť.', true) if parts.empty?

          suspend_selection_sync do
            sel = model.selection
            sel.clear
            parts.each { |p| sel.add(p) }
          end
          push_selected(model, dedup: false)
          set_status("Označených #{parts.size} dielcov skrinky #{Store.get(cab, 'cabinet_id')} v modeli.")
        end

        # UI-D3: `handle_select_hw_owner` nizsie pouziva aj OKO v riadku
        # warnpanelu (⚠ chip v hlavicke) — nalez stavby ukazuje na dielec presne
        # tak ako polozka kovania na svojho vlastnika, takze duplikovat cely blok
        # guardov by znamenalo dve miesta, ktore sa casom rozidu. Lisi sa LEN
        # podstatne meno v statusoch (payload nesie `origin`), aby hlaska
        # nehovorila o „vlastníkovi" a o Kovani tam, kde pouzivatel klikal na
        # upozornenie. Neznamy/chybajuci povod = kovanie (spatna kompatibilita).
        SELECT_OWNER_NOUNS = {
          'warn' => { subject: 'Nález', stay: 'panel ostáva pri skrinke' },
          'hardware' => { subject: 'Vlastník', stay: 'panel ostáva v Kovaní' }
        }.freeze

        def select_owner_nouns(raw)
          SELECT_OWNER_NOUNS[raw.to_s] || SELECT_OWNER_NOUNS['hardware']
        end

        # UI-C4: klik na HLAVICKU BOXU VLASTNIKA v sekcii Kovanie (a na znacku
        # kovania v nahlade) — oznaci v modeli to, comu polozka patri: celu
        # skrinku (prazdne `part_keys`) alebo konkretne dielce podla part_key
        # (obe kridla cela, zasuvkove celo, police).
        #
        # CISTE CITANIE MODELU + zmena VYBERU: ziadny `start_operation`, ziadny
        # zapis do dictionary, ziadny krok Spat (lekcia D-103) — presne ako
        # `handle_select_parts` a `ProductionCore.do_select`.
        #
        # VEDOMA ODCHYLKA (a jadro tejto davky): po vybere sa NEVOLA
        # `push_selected`. Identita vyberu je autoritou rezimu panela, takze
        # oznaceny DIELEC by panel prepol na kartu Dielec — a box, z ktoreho
        # pouzivatel prave klikol, by mu zmizol pod rukami. Panel uz zobrazuje
        # TU ISTU skrinku (dielec je jej sucast), takze sa nic nerozchadza vo
        # veci, len rail nedostane docasnu polozku. Vzor je `EdgeSelectionWatch`,
        # ktory na zmenu vyberu tiez zamerne nepusha. Najblizsi bezny push
        # (undo, zmena katalogu, dalsi klik v modeli) panel zosuladi.
        #
        # IDENTITY GUARD (vzor handle_select_parts): PRISNE sa overuje dokument
        # aj to, ze ide stale o TU ISTU skrinku — callback HtmlDialogu je
        # asynchronny a ID skriniek sa naprie dokumentmi opakuju.
        def handle_select_hw_owner(payload = nil)
          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          noun = select_owner_nouns(data['origin'])
          return set_status("#{noun[:subject]} sa neoznačil — panel patrí inému dokumentu.", true) if
            DocKey.foreign?(data['model_guid'], model)

          # Codex #179 P2 (kolo 3): rovnaky guard ako `handle_select_parts`.
          # Rozpisany edit mohol server odmietnut (material_preflight) — vtedy uz
          # bezal UI resync s POVODNYMI hodnotami a `@last_apply_error` je JEDINA
          # sprava, ktora hovori PRAVDU o tom, preco sa uprava nezapisala. Hlasit
          # nad nou uspech oznacenia by ju prekrylo; a nespotrebovany priznak by
          # sa neskor ozval pri kliku „Dielcov" k uprave, ktora uz nie je vidiet.
          if @last_apply_error
            msg = @last_apply_error
            @last_apply_error = nil
            return set_status("#{noun[:subject]} sa neoznačil — najprv oprav úpravu: #{msg}", true)
          end

          cab = find_cabinet(model)
          return refresh_after_stale(model) if cab.nil? ||
                                               Store.get(cab, 'cabinet_id').to_s != data['cabinet_id'].to_s

          keys = Array(data['part_keys']).map(&:to_s).reject(&:empty?)
          cid = Store.get(cab, 'cabinet_id').to_s
          if keys.empty?
            reselect(model, cab) # sam si drzi suspend guard
            return set_status("Označená skrinka #{cid} v modeli.")
          end

          parts = parts_by_keys(cab, keys)
          if parts.empty?
            return set_status('Dielec sa v modeli nenašiel — skrinka sa možno medzitým prestavala.', true)
          end

          suspend_selection_sync do
            sel = model.selection
            sel.clear
            parts.each { |p| sel.add(p) }
          end
          # Codex #179 P2: box moze niest VIAC klucov (obe kridla dvierok, vsetky
          # police vo „Vnútre"). Ked sa cast z nich nenajde, vyber sa NEODMIETA —
          # ukazat dve kridla z troch je stale to, co pouzivatel chcel — ale
          # status sa musi pytat oznacenych dielcov, nie ziadanych klucov, a
          # chybajuce POMENOVAT. Inak by hlasil uspech pre nieco, co v modeli nie
          # je (zasada „nikdy netvrdit zhodu, ktora neplati").
          found = parts.map { |p| Store.get(p, 'part_key').to_s }.uniq
          missing = keys - found
          msg = "Označené v modeli: #{hw_owner_status_label(cab, found)} " \
                "(skrinka #{cid}) — #{noun[:stay]}."
          unless missing.empty?
            msg += " Nenašlo sa: #{hw_owner_status_label(cab, missing)} " \
                   '— skrinka sa možno medzitým prestavala.'
          end
          set_status(msg, !missing.empty?)
        end

        # Popis oznaceneho vlastnika do statusu. Autorita nazvu je TA ISTA ako
        # v payloade kovania (PartKeys.human_label nad resolved celami) — panel
        # ani status si nic nevymyslaju.
        def hw_owner_status_label(cab, keys)
          fronts = payload_fronts(Store.config(cab) || {})
          names = keys.map { |k| PartKeys.human_label(k, fronts: fronts) }.compact.uniq
          names.empty? ? keys.join(' + ') : names.join(' + ')
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hw_owner_status_label')
          keys.join(' + ')
        end

        # Vyrobne dielce skrinky s danymi part_key. Rovnaky rozsah ako
        # `manufactured_parts` (vnorene AJ odpojene dielce na najvyssej urovni),
        # len s filtrom kluca — kovanie sa viaze na part_key, nie na entitu.
        def parts_by_keys(cab, keys)
          want = {}
          keys.each { |k| want[k.to_s] = true }
          manufactured_parts(cab).select do |p|
            want[Store.get(p, 'part_key').to_s]
          end
        rescue StandardError => e
          Engine.log_error(e, 'Panel.parts_by_keys')
          []
        end

        # UI-B2 (N7): „Pohlad na skrinku" zo spodneho pasu nahladu. Zarovna
        # kameru na celny pohlad a doramuje ju na oznacenu skrinku.
        #
        # CISTE CITANIE MODELU: kamera nie su data modelu — nemeni sa geometria
        # ani dictionary, takze sa NESMIE otvarat operacia (`start_operation` by
        # spravil prazdny krok Spat, ktory by pouzivatelovi zjedol jeden Ctrl+Z
        # — lekcia D-103). Ziadny vyber sa tiez nemeni: pohlad je pohlad.
        #
        # IDENTITY GUARD (Codex #169 P2): callback HtmlDialogu je asynchronny,
        # takze sa overuje OBOJE — dokument aj VYBER. ID skriniek sa naprie
        # dokumentmi opakuju (prisny guid guard, vzor `handle_clear_selection`)
        # a kym callback dobehne, mohol pouzivatel oznacit inu skrinku; vtedy by
        # pohlad odskocil na tu, ktoru uz needituje. Pri nezhode sa pohlad
        # nedotkne a panel sa len zosuladi (vzor `handle_select_cabinet`).
        def handle_camera_focus(payload = nil)
          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          return set_status('Pohľad sa nezarovnal — panel patrí inému dokumentu.', true) if
            DocKey.foreign?(data['model_guid'], model)

          want = data['cabinet_id'].to_s
          # Vybraty moze byt aj DIELEC skrinky (rail drzi docasnu polozku) —
          # find_cabinet vrati jeho rodica, takze kamera funguje aj z karty dielca.
          cab = find_cabinet(model)
          return refresh_after_stale(model) if cab.nil? || Store.get(cab, 'cabinet_id').to_s != want

          focus_camera_on(model, cab)
          set_status('Pohľad zarovnaný na skrinku (čelný pohľad).', false)
        end

        # Celny pohlad na skrinku: oko PRED jej celom, ciel je stred obalky.
        #
        # Codex #169 P2: smer sa berie z TRANSFORMACIE skrinky, nie z globalnych
        # osi. Otocena skrinka je podporovany stav (rotaciu zamerne zachovava
        # ScaleWatch.clean_transform), takze pevne -Y by pri nej ukazalo bok
        # alebo chrbat. Lokalne: hlbka rastie v +Y (celo je pri y=0), vyska v +Z
        # — celny pohlad teda stoji v smere lokalneho -Y a hore je lokalne +Z.
        # Vzdialenost z uhlopriecky obalky, aby oko nezacinalo vnutri skrinky;
        # ramec potom dotiahne `view.zoom(entity)`.
        def focus_camera_on(model, ent)
          view = model.active_view
          bb = ent.bounds
          center = bb.center
          diag = bb.diagonal.to_f
          diag = 40.0 if diag <= 0 # ~1 m v palcoch (degenerovana obalka)
          fwd = camera_axis(ent.transformation.yaxis, Geom::Vector3d.new(0, 1, 0))
          up = camera_axis(ent.transformation.zaxis, Geom::Vector3d.new(0, 0, 1))
          eye = center.offset(fwd.reverse, diag * 1.5)
          view.camera.set(eye, center, up)
          view.zoom(ent)
          view.invalidate
          true
        end

        # Os transformacie ako JEDNOTKOVY vektor. Zoskalovana (alebo degenerovana)
        # os by kameru rozhodila, preto sa normalizuje a pri nulovej dlzke sa
        # pouzije globalna nahrada.
        def camera_axis(vec, fallback)
          return fallback if vec.nil? || vec.length.to_f <= 0

          vec.normalize
        rescue StandardError
          fallback
        end

      end

      # Observer musi zit ako objekt s referenciou (Panel modul ju drzi v @observer).
      class SelObserver < Sketchup::SelectionObserver
        def onSelectionBulkChange(_selection)
          Panel.on_selection_changed
        end

        def onSelectionCleared(_selection)
          Panel.on_selection_changed
        end

        # SketchUp fire pri pridani/odobrati JEDNEJ entity `onSelectionAdded`/`onSelectionRemoved`
        # (NIE onSelectionBulkChange). Bez nich by sa panel po jednotlivom uzivatelskom pridani do
        # vyberu neobnovil. on_selection_changed respektuje suspend guard (nase reselecty su potlacene).
        def onSelectionAdded(_selection, _element)
          Panel.on_selection_changed
        end

        def onSelectionRemoved(_selection, _element)
          Panel.on_selection_changed
        end
      end

      # D-101: undo/redo/abort transakcie — drzany v @model_observer.
      # Vsetky tri cesty koncia v TOM ISTOM odlozenom refreshi (abort je zadarmo
      # — vzor EdgeModelWatch): v callbacku sa NIC neceka, necita ani nemeni.
      class PanelModelObserver < Sketchup::ModelObserver
        def onTransactionUndo(model)
          Panel.on_model_txn(model)
        end

        def onTransactionRedo(model)
          Panel.on_model_txn(model)
        end

        def onTransactionAbort(model)
          Panel.on_model_txn(model)
        end
      end

      # Prepnutie observera pri zmene aktivneho modelu — drzany v @app_observer.
      # Tri cesty (vzor ScaleWatch::EngineAppObserver): New/Open + onActivateModel
      # pre prepinanie medzi UZ otvorenymi dokumentmi (Codex review PR #18).
      class PanelAppObserver < Sketchup::AppObserver
        # GHOST (V1-04, review #268 P2-2): New/Open = dokument pod ghostom uz
        # NIE JE ten, v ktorom vklad zacal — session sa rusi BEZPODMIENECNE,
        # este pred prepnutim observerov. Windows drzi jeden dokument na proces
        # a smie recyklovat ten isty `Model` objekt, takze porovnanie identity
        # (`on_model_switched`) by tu mohlo session omylom nechat zit.
        # Ghost moze existovat len s otvorenym Inspectorom, a ten tento
        # observer vzdy pripaja (`attach_observer` -> `ensure_app_observer`).
        #
        # 1d/R-02b (review #267 P1-1 + delta P2-GLM): z TOHO ISTEHO dovodu —
        # Windows smie `Model` objekt RECYKLOVAT — sa tu upratuju aj VSETKY
        # pamate viazane na objekt modelu (identita DocKey + most nazvu
        # zakazky SESSION_KEY_BRIDGE). Jeden zoznam je v
        # `Engine.on_document_replaced`.
        # MUSI bezat PRED `Panel.on_model_switched`: ten pushne `model_guid`
        # do panela, a keby sa rotovalo az po nom, klient by dostal STARY
        # token, `nxSetModelGuid` by zmenu nezbadal a oneskoreny zapis by
        # pristal v novootvorenej cudzej zakazke.
        # `onActivateModel` uprataval NESMIE (macOS: prepnutie medzi uz
        # otvorenymi dokumentmi — kazdy si svoju identitu aj nazov drzi).
        def onNewModel(model)
          Engine.on_document_replaced(model)
          GhostTool.on_document_replaced('nový dokument') if defined?(GhostTool)
          Panel.on_model_switched(model)
        end

        def onOpenModel(model)
          Engine.on_document_replaced(model)
          GhostTool.on_document_replaced('otvorený iný dokument') if defined?(GhostTool)
          Panel.on_model_switched(model)
        end

        def onActivateModel(model)
          Panel.on_model_switched(model)
        end
      end
    end
  end
end
