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
          return unless @dialog # panel zavrety — observer prepne az dalsie otvorenie

          detach_observer
          attach_observer
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
          guid = data['model_guid'].to_s
          return false if !guid.empty? && guid != model_guid(model)

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
          return push_selected(model, dedup: false) if data['model_guid'].to_s != model_guid(model)

          want = data['board_id'].to_s
          board = find_board(model)
          have = board ? Store.get(board, 'id').to_s : ''
          return push_selected(model, dedup: false) if !want.empty? && want != have

          suspend_selection_sync { model.selection.clear }
          push_selected(model, dedup: false)
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
        def onNewModel(model)
          Panel.on_model_switched(model)
        end

        def onOpenModel(model)
          Panel.on_model_switched(model)
        end

        def onActivateModel(model)
          Panel.on_model_switched(model)
        end
      end
    end
  end
end
