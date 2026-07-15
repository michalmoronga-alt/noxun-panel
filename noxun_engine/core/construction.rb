# frozen_string_literal: true
# Noxun Engine — construction planner. cfg (mm Float) -> zoznam dielcov (deskriptorov).
# CISTO vypoctovy modul: ziadna SketchUp geometria, ziadne .mm. Testovatelny bez modelu.
# Kazdy dielec = { suffix, role, name, box:[sx,sy,sz], origin:[x,y,z], material:, prod:{} }.
#
# Konstrukcne varianty (standard sekcia 4.4 + domenova korekcia Michal 2026-07):
#   dno:    under_sides (default dolna — dno pln sirka, boky stoja na dne, korpus levituje o floor_height)
#           between_sides (default horna / variant dolna — boky po zem, dno medzi bokmi)
#   vrch:   full / two_rails / none
#   chrbat: overlay / inset / groove
#   sokel:  none (default — priestor pod dnom pre nohy) / front (predny zapusteny panel)
module Noxun
  module Engine
    module Construction
      BACK_THICKNESS    = 3.0    # chrbat
      SHELF_FRONT_INSET = 20.0   # police odsadene od cela
      RAIL_DEPTH        = 100.0  # hlbka priecok pri two_rails
      GROOVE_OFFSET     = 10.0   # odsadenie chrbta v drazke od zadnej hrany

      module_function

      # Hlavny vstup: cfg (symbolove kluce, mm Float) -> plan.
      # Vrati: { parts:[deskriptory], zones:[layout], zone_box:{}, available:{}, wings:, interior:{} }.
      # Validuje interne (raise so slovenskou hlaskou pri nezmyselnych rozmeroch).
      def build_plan(cfg)
        w = cfg[:width]; h = cfg[:height]; t = cfg[:thickness]

        interior = interior_dims(cfg)
        validate!(cfg, interior)

        parts = []
        parts.concat(side_parts(cfg))
        parts << bottom_part(cfg)
        parts.concat(top_parts(cfg))
        bk = back_part(cfg, interior)
        parts << bk if bk
        parts.concat(plinth_parts(cfg))

        # Police — rovnomerne vo vnutornom priestore [z_lo, z_hi].
        sh = Shelves.layout(interior[:z_lo], interior[:z_hi], t, cfg[:shelves])
        shelf_depth = interior[:back_front_y] - SHELF_FRONT_INSET
        sh[:shelves].each do |shelf|
          n = shelf[:index] + 1
          parts << {
            suffix: "SHELF-#{n}", role: 'shelf', name: "Polica #{n}", material: :korpus,
            box: [w - 2 * t, shelf_depth, t], origin: [t, SHELF_FRONT_INSET, shelf[:z]],
            prod: { length: w - 2 * t, width: shelf_depth, thickness: t }
          }
        end

        # Dvierka (cela) — pred korpusom (Y zaporne).
        fr = Fronts.layout(cfg[:fronts], w, h, cfg[:floor_height], t)
        fr[:parts].each do |dr|
          parts << {
            suffix: dr[:suffix], role: dr[:role], name: door_name(dr[:suffix]), material: :front,
            box: [dr[:width], t, dr[:height]], origin: [dr[:x], -t, dr[:z]],
            prod: { length: dr[:height], width: dr[:width], thickness: t }
          }
        end

        {
          parts: parts,
          zones: sh[:zones],
          zone_box: { x0: t, x1: w - t, y0: 0.0, y1: interior[:back_front_y] },
          available: {
            width:  (w - 2 * t),
            height: interior[:avail_h],
            depth:  interior[:back_front_y]
          },
          wings: fr[:wings],
          interior: interior
        }
      end

      # Vnutorne rozmery (svetle) a poloha celnej hrany chrbta.
      # z_lo = vrch dna (= floor_height + hrubka; rovnake pre oba varianty dna),
      # z_hi = spodok vrchu (h-t pre full/two_rails, h pre none).
      def interior_dims(cfg)
        h = cfg[:height]; d = cfg[:depth]
        t = cfg[:thickness]; s = cfg[:floor_height]
        z_lo = s + t
        z_hi = cfg[:top_mode] == 'none' ? h : h - t
        bt = BACK_THICKNESS
        back_front_y =
          case cfg[:back_mode]
          when 'inset'  then d - bt
          when 'groove' then d - GROOVE_OFFSET - bt
          else d # overlay — chrbat je za korpusom, vnutro po zadnu stenu
          end
        { z_lo: z_lo, z_hi: z_hi, avail_h: (z_hi - z_lo), back_front_y: back_front_y, back_thickness: bt }
      end

      # Boky — plna hlbka. Z-start podla variantu dna:
      #   under_sides  -> boky stoja NA dne (z0 = floor_height + hrubka dna), skratene.
      #   between_sides-> boky po zem (z0 = 0), plna vyska.
      def side_parts(cfg)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; s = cfg[:floor_height]; h = cfg[:height]
        z0 = cfg[:bottom_mode] == 'under_sides' ? (s + t) : 0.0
        sh = h - z0
        [
          { suffix: 'SIDE-L', role: 'side_left', name: 'Bok lavy', material: :korpus,
            box: [t, d, sh], origin: [0, 0, z0], prod: { length: sh, width: d, thickness: t } },
          { suffix: 'SIDE-R', role: 'side_right', name: 'Bok pravy', material: :korpus,
            box: [t, d, sh], origin: [w - t, 0, z0], prod: { length: sh, width: d, thickness: t } }
        ]
      end

      # Dno — vzdy na urovni Z = floor_height (priestor pod nim = nohy / sokel).
      #   under_sides  -> pln sirka [0..w].
      #   between_sides-> medzi bokmi [t..w-t].
      def bottom_part(cfg)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; s = cfg[:floor_height]
        if cfg[:bottom_mode] == 'under_sides'
          { suffix: 'BOTTOM', role: 'bottom', name: 'Dno', material: :korpus,
            box: [w, d, t], origin: [0, 0, s], prod: { length: w, width: d, thickness: t } }
        else
          { suffix: 'BOTTOM', role: 'bottom', name: 'Dno', material: :korpus,
            box: [w - 2 * t, d, t], origin: [t, 0, s], prod: { length: w - 2 * t, width: d, thickness: t } }
        end
      end

      # Vrch — medzi bokmi na Z = h-t.
      #   full      -> jeden pln panel (hlbka d).
      #   two_rails -> predna + zadna vystuha (rail_depth), typicke pre dolne skrinky pod dosku.
      #   none      -> ziadny vrch.
      def top_parts(cfg)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; h = cfg[:height]
        case cfg[:top_mode]
        when 'none'
          []
        when 'two_rails'
          rail_parts(cfg)
        else # full
          [{ suffix: 'TOP', role: 'top', name: 'Vrch', material: :korpus,
             box: [w - 2 * t, d, t], origin: [t, 0, h - t], prod: { length: w - 2 * t, width: d, thickness: t } }]
        end
      end

      # Dve horne vystuhy (rail_front / rail_back). Reálne prípady dolných skriniek:
      #   rails_orientation flat    -> pás naplocho (hrúbka t zvisle, hĺbka rail_depth v Y). Default.
      #   rails_orientation upright -> pás na hranu (hrúbka t v Y, výška rail_depth zvisle) — drezová skrinka.
      #   rails_top_offset          -> odsadenie od hornej hrany nadol (varná doska ~20 mm).
      # Výrobný dielec je v oboch prípadoch rovnaký rez (dĺžka w-2t, šírka rail_depth, hrúbka t).
      def rail_parts(cfg)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; h = cfg[:height]; s = cfg[:floor_height]
        off = cfg[:rails_top_offset].to_f
        z_top = h - off # horna hrana vystuhy
        if cfg[:rails_orientation] == 'upright'
          rdp = [cfg[:rail_depth], (h - s - t - 10.0)].min # vyska pasu, ochrana proti podlezeniu dna
          rdp = 20.0 if rdp < 20.0
          z0 = z_top - rdp
          prod = { length: w - 2 * t, width: rdp, thickness: t }
          [
            { suffix: 'TOP-RAIL-F', role: 'rail_front', name: 'Vystuha predna', material: :korpus,
              box: [w - 2 * t, t, rdp], origin: [t, 0, z0], prod: prod },
            { suffix: 'TOP-RAIL-B', role: 'rail_back', name: 'Vystuha zadna', material: :korpus,
              box: [w - 2 * t, t, rdp], origin: [t, d - t, z0], prod: prod }
          ]
        else # flat
          rd = [cfg[:rail_depth], (d / 2.0 - 10.0)].min # ochrana proti prekrytiu prednej a zadnej
          rd = 20.0 if rd < 20.0
          z0 = z_top - t
          prod = { length: w - 2 * t, width: rd, thickness: t }
          [
            { suffix: 'TOP-RAIL-F', role: 'rail_front', name: 'Vystuha predna', material: :korpus,
              box: [w - 2 * t, rd, t], origin: [t, 0, z0], prod: prod },
            { suffix: 'TOP-RAIL-B', role: 'rail_back', name: 'Vystuha zadna', material: :korpus,
              box: [w - 2 * t, rd, t], origin: [t, d - rd, z0], prod: prod }
          ]
        end
      end

      # Chrbat.
      #   overlay -> nalozeny zozadu, pln sirka, Y = d..d+bt.
      #   inset   -> vlozeny medzi boky, na zadnej hrane (Y = d-bt..d).
      #   groove  -> ako inset, ale odsadeny GROOVE_OFFSET od zadnej hrany (drazka sa NEfrezuje, len poloha).
      def back_part(cfg, interior)
        w = cfg[:width]; d = cfg[:depth]; h = cfg[:height]; t = cfg[:thickness]; s = cfg[:floor_height]
        bt = interior[:back_thickness]
        case cfg[:back_mode]
        when 'inset'
          z0 = interior[:z_lo]; bh = interior[:z_hi] - z0
          { suffix: 'BACK', role: 'back', name: 'Chrbat', material: :korpus,
            box: [w - 2 * t, bt, bh], origin: [t, d - bt, z0], prod: { length: w - 2 * t, width: bh, thickness: bt } }
        when 'groove'
          z0 = interior[:z_lo]; bh = interior[:z_hi] - z0
          y0 = d - GROOVE_OFFSET - bt
          { suffix: 'BACK', role: 'back', name: 'Chrbat', material: :korpus,
            box: [w - 2 * t, bt, bh], origin: [t, y0, z0], prod: { length: w - 2 * t, width: bh, thickness: bt } }
        else # overlay
          { suffix: 'BACK', role: 'back', name: 'Chrbat', material: :korpus,
            box: [w, bt, h - s], origin: [0, d, s], prod: { length: w, width: h - s, thickness: bt } }
        end
      end

      # Sokel — len variant 'front' (predny zapusteny panel). Default 'none' = priestor pre nohy.
      def plinth_parts(cfg)
        return [] unless cfg[:plinth_mode] == 'front'
        s = cfg[:floor_height]
        return [] if s <= 0
        w = cfg[:width]; t = cfg[:thickness]; recess = cfg[:plinth_recess]
        [{ suffix: 'PLINTH', role: 'plinth', name: 'Sokel predny', material: :korpus,
           box: [w - 2 * t, t, s], origin: [t, recess, 0], prod: { length: w - 2 * t, width: s, thickness: t } }]
      end

      def door_name(suffix)
        case suffix
        when 'DOOR-L' then 'Dvierka lave'
        when 'DOOR-R' then 'Dvierka prave'
        else 'Dvierka'
        end
      end

      def validate!(cfg, interior)
        w = cfg[:width]; h = cfg[:height]; t = cfg[:thickness]; s = cfg[:floor_height]
        raise 'Sirka je prilis mala vzhladom na hrubku materialu.' if w <= 2 * t + 10
        raise 'Hlbka je prilis mala.' if interior[:back_front_y] <= 10
        raise 'Podstavec/sokel nesmie byt vyssi nez korpus.' if s >= h
        raise 'Vnutorna vyska je nulova alebo zaporna (skontroluj vysku, podstavec a hrubky).' if interior[:avail_h] <= 10
      end
    end
  end
end
