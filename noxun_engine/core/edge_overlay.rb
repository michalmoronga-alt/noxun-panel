# frozen_string_literal: true
# Noxun Engine — D-104/D-105: SketchUp objekty kontroly hran (Overlay +
# ModelObserver + SelectionObserver) + D-89a hover hrany + K2/D-87 smer kresby.
# Logika a stav ziju v core/edge_check.rb, core/hover_edge.rb a
# core/grain_check.rb; tu su LEN tenke SketchUp obaly.
#
# Cely subor je pod guardom `defined?(Sketchup::Overlay)` — Overlay API prislo v
# SketchUp 2023. Na starsom SketchUpe (a v headless testoch) trieda vobec
# nevznikne a EdgeCheck.available? vrati false; Studio to povie vetou,
# zvysok pluginu bezi nezmeneny.
module Noxun
  module Engine
    if defined?(Sketchup::Overlay)
      # Kresli NAD modelom — ziadna geometria, ziadna operacia, ziadny undo krok
      # a nic sa neuklada do .skp. Registruje/odstranuje ju EdgeCheck.
      class EdgeOverlay < Sketchup::Overlay
        def initialize
          super(EdgeCheck::OVERLAY_ID, EdgeCheck::OVERLAY_NAME,
                description: 'Farebne zvyraznenie stavu olepu hran: cervena chyba podla ' \
                             'pravidla, fialova neolepene mimo pravidla, zelena olepene (D-105).')
        end

        def draw(view)
          EdgeCheck.draw(view)
        rescue StandardError => e
          Engine.log_error(e, 'EdgeOverlay#draw')
          nil
        end

        # Bez extents SketchUp orezava kresbu mimo obalu modelu (plosky su
        # posunute 0,5 mm von) — Codex audit D-104, BLOCKER 4.
        def getExtents # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.extents(respond_to?(:model) ? model : nil)
        rescue StandardError => e
          Engine.log_error(e, 'EdgeOverlay#getExtents')
          Geom::BoundingBox.new
        end
      end

      # D-105: zmena VYBERU meni, co sa kresli pri „len vybrané" (zelena) —
      # NIE to, co je v modeli. KRITICKE (lekcia D-103, PR #151): z tejto cesty
      # sa NESMIE spustit ziadna operacia, dedup ani zapis — inak by sa stala
      # vrcholom undo stacku hned po pouzivatelovom kroku. EdgeCheck tu iba
      # zahodi filter, poziada o cerstve cisla a prekresli pohlad.
      class EdgeSelectionWatch < Sketchup::SelectionObserver
        def onSelectionBulkChange(selection) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.on_selection_changed(model_of(selection))
        end

        def onSelectionCleared(selection) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.on_selection_changed(model_of(selection))
        end

        # Jedna pridana/odobrata entita fire-uje VLASTNY callback (nie bulk) —
        # bez nich by sa Ctrl+klik po jednom neprejavil (vzor Panel::SelObserver).
        def onSelectionAdded(selection, _element) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.on_selection_changed(model_of(selection))
        end

        def onSelectionRemoved(selection, _element) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.on_selection_changed(model_of(selection))
        end

        # Model z kolekcie vyberu; pri chybe nil = EdgeCheck si vezme svoj vlastny
        # (a stale overi, ze ide o TEN ISTY dokument).
        def model_of(selection)
          selection.respond_to?(:model) ? selection.model : nil
        rescue StandardError
          nil
        end
      end

      # Zmena modelu = cache zvyraznenia je stara. V callbacku sa NIC neskenuje
      # ani nemeni (SketchUp to v observeroch zakazuje) — len sa oznaci dirty a
      # poziada o prekreslenie; prepocet bezi az v draw.
      class EdgeModelWatch < Sketchup::ModelObserver
        def onTransactionCommit(model) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.mark_dirty(model)
        end

        def onTransactionUndo(model) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.mark_dirty(model)
        end

        def onTransactionRedo(model) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.mark_dirty(model)
        end

        def onTransactionAbort(model) # rubocop:disable Naming/MethodName — SketchUp API
          EdgeCheck.mark_dirty(model)
        end
      end

      # K2 / D-87: SMER KRESBY. Vlastny overlay (nie dalsi stav D-104) — hovori
      # o INEJ veci: „takto bezie kresba dekoru", nie o stave olepu. Logika a
      # stav ziju v core/grain_check.rb.
      class GrainOverlay < Sketchup::Overlay
        def initialize
          super(GrainCheck::OVERLAY_ID, GrainCheck::OVERLAY_NAME,
                description: 'Ciary v smere kresby dekoru na vyrobnych dielcoch — ' \
                             'vizualna kontrola orientacie zakazky (K2/D-87).')
        end

        def draw(view)
          GrainCheck.draw(view)
        rescue StandardError => e
          Engine.log_error(e, 'GrainOverlay#draw')
          nil
        end

        def getExtents # rubocop:disable Naming/MethodName — SketchUp API
          GrainCheck.extents(respond_to?(:model) ? model : nil)
        rescue StandardError => e
          Engine.log_error(e, 'GrainOverlay#getExtents')
          Geom::BoundingBox.new
        end
      end

      # K2: prestavba skrinky (alebo Spat/Znova) meni smer aj geometriu dielcov
      # — cache kresby je vtedy stara. V callbacku sa NIC neskenuje ani nemeni
      # (SketchUp to v observeroch zakazuje): len dirty + ziadost o prekreslenie.
      class GrainModelWatch < Sketchup::ModelObserver
        def onTransactionCommit(model) # rubocop:disable Naming/MethodName — SketchUp API
          GrainCheck.mark_dirty(model)
        end

        def onTransactionUndo(model) # rubocop:disable Naming/MethodName — SketchUp API
          GrainCheck.mark_dirty(model)
        end

        def onTransactionRedo(model) # rubocop:disable Naming/MethodName — SketchUp API
          GrainCheck.mark_dirty(model)
        end

        def onTransactionAbort(model) # rubocop:disable Naming/MethodName — SketchUp API
          GrainCheck.mark_dirty(model)
        end
      end

      # D-89 (a): HRANA POD KURZOROM. Vlastny overlay (nie dalsi stav D-104) —
      # hovori o INEJ veci: „toto je hrana, nad ktorou stojis v paneli", nie
      # o stave olepu. Ziadny observer nepotrebuje: zvyraznenie zije len po dobu
      # hoveru a stav si drzi HoverEdge (jedna ploska, ziadny scan).
      class HoverEdgeOverlay < Sketchup::Overlay
        def initialize
          super(HoverEdge::OVERLAY_ID, HoverEdge::OVERLAY_NAME,
                description: 'Zvyraznenie hrany, nad ktorou stoji kurzor v karte dielca (D-89a).')
        end

        def draw(view)
          HoverEdge.draw(view)
        rescue StandardError => e
          Engine.log_error(e, 'HoverEdgeOverlay#draw')
          nil
        end

        def getExtents # rubocop:disable Naming/MethodName — SketchUp API
          HoverEdge.extents(respond_to?(:model) ? model : nil)
        rescue StandardError => e
          Engine.log_error(e, 'HoverEdgeOverlay#getExtents')
          Geom::BoundingBox.new
        end
      end
    end
  end
end
