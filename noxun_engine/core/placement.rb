# frozen_string_literal: true
# Noxun Engine — placement. Umiestnovanie novych objektov v modeli (V0.4.7b).
# SketchUp API (bounds/Units) — NIE je v headless load liste (ako zones).
#
# Pravy okraj pocitaju IBA top-level VLASTNICKE objekty (kind cabinet/board) —
# nikdy ghost zony (kind zone, pomocna geometria; su to top-level Groups) ani
# instancie vnorene v cudzich komponentoch (iteruje sa model.entities, nie
# model.definitions ako Ids.each_of_kind).
module Noxun
  module Engine
    module Placement
      OWNER_KINDS = %w[cabinet board].freeze

      module_function

      # X pravej hrany najpravejsieho NOXUN objektu + gap; 0.0 v prazdnom modeli.
      def next_x(model, gap: 50.0)
        max_right = nil
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          next unless OWNER_KINDS.include?(Store.kind(inst).to_s)
          r = Units.to_mm(inst.bounds.max.x)
          max_right = r if max_right.nil? || r > max_right
        end
        max_right.nil? ? 0.0 : max_right + gap
      end
    end
  end
end
