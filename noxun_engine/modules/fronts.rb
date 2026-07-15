# frozen_string_literal: true
# Noxun Engine — modul dvierka (cela). Rezim none/1/2/auto.
# auto: 2 kridla ak sirka > 600 mm. Skary 2 mm. Cisto vypoctovy modul (mm Float).
module Noxun
  module Engine
    module Fronts
      GAP                = 2.0   # skara okolo cela (mm)
      GAP_BETWEEN        = 2.0   # skara medzi kridlami (mm)
      AUTO_TWO_ABOVE     = 600.0 # nad touto sirkou auto = 2 kridla

      # mode: 'none' / '1' / '2' / 'auto'
      # Vstup mm: width (sirka korpusu), height (vyska), floor_height (sokel), thickness.
      # Vrati: { wings: 0/1/2, parts: [{suffix:, role:, x:, width:, z:, height:}] }
      # Dvierka su naslozene (full overlay) pred korpusom; x/z v mm v ramci korpusu.
      def self.layout(mode, width, height, floor_height, thickness)
        wings = resolve_wings(mode, width)
        return { wings: 0, parts: [] } if wings.zero?

        z0 = floor_height + GAP
        door_h = (height - floor_height) - 2 * GAP
        parts =
          if wings == 1
            dw = width - 2 * GAP
            [{ suffix: 'DOOR', role: 'front_door', x: GAP, width: dw, z: z0, height: door_h }]
          else
            dw = (width - 2 * GAP - GAP_BETWEEN) / 2.0
            [
              { suffix: 'DOOR-L', role: 'front_door', x: GAP,                  width: dw, z: z0, height: door_h },
              { suffix: 'DOOR-R', role: 'front_door', x: width - GAP - dw,     width: dw, z: z0, height: door_h }
            ]
          end
        { wings: wings, parts: parts }
      end

      def self.resolve_wings(mode, width)
        case mode.to_s
        when 'none', '0', '' then 0
        when '1'             then 1
        when '2'             then 2
        when 'auto'          then width > AUTO_TWO_ABOVE ? 2 : 1
        else 0
        end
      end
    end
  end
end
