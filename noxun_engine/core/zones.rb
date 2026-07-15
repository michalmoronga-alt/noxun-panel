# frozen_string_literal: true
# Noxun Engine — zony (sloty). Ghost boxy medzi policami na tagu NOXUN_SLOTY.
# manufactured:false, polopriehladne materialy (standard sekcia 5.1). Nikdy v kusovniku.
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

      # Postavi ghost zony do parent_ents (definicia korpusu). Vrati pole zone id.
      # zones_data: pole {index, z0, z1, height} zo Shelves.layout
      # box: { x0, x1, y0, y1 } — vnutorny priestor v mm (medzi bokmi, po chrbat)
      def self.build_into(model, parent_ents, zones_data, box, cabinet_id)
        tag = model.layers.add(TAG)
        mats = ensure_materials(model)
        ids = []
        zones_data.each_with_index do |z, i|
          zid = "#{cabinet_id}-Z#{i + 1}"
          grp = parent_ents.add_group
          grp.name = "zona_#{i + 1}"
          draw_ghost(grp.entities, box, z[:z0], z[:z1])
          grp.material = mats[i % mats.length]
          grp.layer = tag
          Store.write(grp, {
            std: Store::STD, kind: 'zone', id: zid, cabinet_id: cabinet_id,
            role: 'zone', manufactured: false, production_class: 'none',
            config: {
              parent_zone: nil,
              position: [box[:x0].round(2), box[:y0].round(2), z[:z0].round(2)],
              width:  (box[:x1] - box[:x0]).round(2),
              height: z[:height].round(2),
              depth:  (box[:y1] - box[:y0]).round(2),
              state: 'free',
              allowed_modules: %w[shelf divider_h drawer_block front_door],
              modules: []
            }
          })
          ids << zid
        end
        ids
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

      def self.draw_ghost(ents, box, z0, z1)
        x0 = box[:x0] + INSET
        x1 = box[:x1] - INSET
        y0 = box[:y0] + INSET
        y1 = box[:y1] - INSET
        zz0 = z0 + INSET
        h = (z1 - z0) - 2 * INSET
        return if x1 <= x0 || y1 <= y0 || h <= 0
        pts = [
          Units.point(x0, y0, zz0), Units.point(x1, y0, zz0),
          Units.point(x1, y1, zz0), Units.point(x0, y1, zz0)
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
