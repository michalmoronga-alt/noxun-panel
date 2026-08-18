# frozen_string_literal: true
# Noxun Engine — modul police. Rovnomerne rozlozenie 0-6 polic + vypocet zon.
# Cisto vypoctovy modul (mm Float), ziadna geometria — tu kresli builder/zones.
module Noxun
  module Engine
    module Shelves
      # UI-C2 (kontrakt UI 2.0, sekcia Zony): pills 0–6. Strop je 6, NIE numericky
      # fallback — kto chce viac polic, deli zonu. Zrkadlo v `ui/js/zone_tree.js`
      # (sanitizeTree clamp) a v pilulkach `ui/js/actions.js`; zhodu strazi test.
      # Geometriu vysokych poctov chrani `ZoneTree.validate_shelves!` (zona musi
      # mat na n polic aspon n*t + (n+1)*MIN_FIELD svetlej vysky).
      MAX = 6

      # Rozlozi 'count' polic rovnomerne v svetlom priestore [clear_z0, clear_z1].
      # n polic => n+1 zon; gap = (svetla_vyska - n*hrubka) / (n+1).
      # Vrati: { gap:, shelves: [{index:, z:, thickness:}], zones: [{index:, z0:, z1:, height:}] }
      # z = spodna hrana police; z0/z1 = spodok/vrch zony (svetle).
      def self.layout(clear_z0, clear_z1, thickness, count)
        n = clamp(count)
        clear = clear_z1 - clear_z0
        gap = (clear - n * thickness) / (n + 1).to_f
        shelves = []
        zones = []
        z = clear_z0
        (n + 1).times do |i|
          z0 = z
          z1 = z + gap
          zones << { index: i, z0: z0, z1: z1, height: gap }
          z = z1
          if i < n
            shelves << { index: i, z: z, thickness: thickness }
            z += thickness
          end
        end
        { gap: gap, shelves: shelves, zones: zones }
      end

      def self.clamp(count)
        c = count.to_i
        return 0 if c < 0
        return MAX if c > MAX
        c
      end
    end
  end
end
