# frozen_string_literal: true
# Noxun Engine — modul police. Rovnomerne rozlozenie 0-4 polic + vypocet zon.
# Cisto vypoctovy modul (mm Float), ziadna geometria — tu kresli builder/zones.
module Noxun
  module Engine
    module Shelves
      MAX = 4

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
