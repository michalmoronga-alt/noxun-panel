# frozen_string_literal: true
# Noxun Engine — zony (ghost geometria). Standard sekcia 5.1.
# Pre kazdu LISTOVU zonu stromu (ZoneTree) postavi polopriehladny ghost box na tagu
# NOXUN_SLOTY. Ghost nesie NOXUN dict (kind:zone, id, cabinet_id, config) — klikatelna entita.
# manufactured:false, nikdy v kusovniku.
module Noxun
  module Engine
    module Zones
      TAG     = 'NOXUN_SLOTY'
      INSET   = 1.0  # mm — ghost je o kusok mensi nez svetly priestor
      ALPHA   = 0.35
      PALETTE = [
        [70, 190, 255], [110, 255, 150], [255, 175, 80],
        [220, 120, 255], [255, 235, 90]
      ].freeze

      # Postavi ghosty listovych zon do parent_ents (definicia korpusu).
      # zones: ploche pole objektov zo ZoneTree.compute (symbolove kluce). Vrati pole id listov.
      def self.build_into(model, parent_ents, zones, cabinet_id)
        tag = model.layers.add(TAG)
        mats = ensure_materials(model)
        i = 0
        ids = []
        zones.each do |z|
          next unless z[:leaf]
          grp = parent_ents.add_group
          grp.name = "zona_#{z[:id]}"
          draw_ghost(grp.entities, z[:position], z[:width], z[:height], z[:depth])
          grp.material = mats[i % mats.length]
          grp.layer = tag
          Store.write(grp, {
            std: Store::STD, kind: 'zone', id: z[:id], cabinet_id: cabinet_id,
            role: 'zone', manufactured: false, production_class: 'none',
            config: zone_config(z)
          })
          ids << z[:id]
          i += 1
        end
        ids
      end

      def self.zone_config(z)
        {
          parent_zone: z[:parent],
          position: z[:position],
          width: z[:width], height: z[:height], depth: z[:depth],
          state: (z[:shelves].to_i.positive? ? 'occupied' : 'free'),
          shelves: z[:shelves].to_i,
          allowed_modules: %w[shelf divider_v divider_h drawer_block front_door],
          modules: []
        }
      end

      # Zabezpeci existenciu tagu a nastavi jeho viditelnost (checkbox v paneli).
      def self.set_visible(model, visible)
        tag = model.layers[TAG] || model.layers.add(TAG)
        tag.visible = visible ? true : false
        tag.visible?
      end

      def self.visible?(model)
        tag = model.layers[TAG]
        tag ? tag.visible? : true
      end

      # Ghost box z pozicie (min roh) a rozmerov (mm), zmenseny o INSET.
      def self.draw_ghost(ents, position, w, hh, d)
        x0 = position[0] + INSET
        y0 = position[1] + INSET
        z0 = position[2] + INSET
        ww = w - 2 * INSET
        dd = d - 2 * INSET
        h = hh - 2 * INSET
        return if ww <= 0 || dd <= 0 || h <= 0
        pts = [
          Units.point(x0, y0, z0), Units.point(x0 + ww, y0, z0),
          Units.point(x0 + ww, y0 + dd, z0), Units.point(x0, y0 + dd, z0)
        ]
        f = ents.add_face(pts)
        f.reverse! if f.normal.z < 0
        f.pushpull(Units.mm(h))
      end

      def self.ensure_materials(model)
        PALETTE.each_with_index.map do |rgb, i|
          name = "NOXUN_slot_#{i}"
          mt = model.materials[name] || model.materials.add(name)
          mt.color = Sketchup::Color.new(*rgb)
          mt.alpha = ALPHA
          mt
        end
      end
    end
  end
end
