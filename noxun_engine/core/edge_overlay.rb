# frozen_string_literal: true
# Noxun Engine — D-104: SketchUp objekty kontroly hran (Overlay + ModelObserver).
# Logika a stav ziju v core/edge_check.rb; tu su LEN tenke SketchUp obaly.
#
# Cely subor je pod guardom `defined?(Sketchup::Overlay)` — Overlay API prislo v
# SketchUp 2023. Na starsom SketchUpe (a v headless testoch) trieda vobec
# nevznikne a EdgeCheck.available? vrati false; okno Vyroba to povie vetou,
# zvysok pluginu bezi nezmeneny.
module Noxun
  module Engine
    if defined?(Sketchup::Overlay)
      # Kresli NAD modelom — ziadna geometria, ziadna operacia, ziadny undo krok
      # a nic sa neuklada do .skp. Registruje/odstranuje ju EdgeCheck.
      class EdgeOverlay < Sketchup::Overlay
        def initialize
          super(EdgeCheck::OVERLAY_ID, EdgeCheck::OVERLAY_NAME,
                description: 'Cervene plosky na hranach, ktore maju byt olepene a nie su (D-104).')
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
    end
  end
end
