# frozen_string_literal: true
# Noxun Engine - Panel: SelectionObserver lifecycle + suspend guard + reselect + SelObserver trieda.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- SelectionObserver ----------------------------------------------
        def attach_observer
          model = Sketchup.active_model
          @observer ||= SelObserver.new
          model.selection.add_observer(@observer)
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

        def detach_observer
          return unless @observer && @observer_model

          @observer_model.selection.remove_observer(@observer)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.detach_observer')
        ensure
          @observer_model = nil
        end

        def on_selection_changed
          return if @suspend_selection_sync # nase vlastne reselecty resyncnu panel explicitne

          push_selected(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.on_selection_changed')
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
          set_status(msg)
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

      # Prepnutie observera pri zmene aktivneho modelu (File > New / Open) — drzany v @app_observer.
      class PanelAppObserver < Sketchup::AppObserver
        def onNewModel(model)
          Panel.on_model_switched(model)
        end

        def onOpenModel(model)
          Panel.on_model_switched(model)
        end
      end
    end
  end
end
