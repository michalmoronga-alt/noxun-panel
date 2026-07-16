# frozen_string_literal: true
# Noxun Engine — zony (ghost geometria). Standard sekcia 5.1.
#
# V0.2c: ghost boxy zon uz NEstoja v definicii korpusu, ale ako JEDNA top-level skupina
# `NOXUN_ZONY <cabinet_id>` priamo v model.entities. Dovod: klik na zonu = JEDEN klik
# (bez dvojkliku do komponentu korpusu). Skupina nesie transformaciu korpusu; pod-skupiny
# su jednotlive listove zony (NOXUN dict kind:zone + cabinet_id + config) — klikatelne entity.
# Sync: pri rebuilde sa pregeneruju (sync_ghost); pri move/rotate korpusu sa len presunie
# cela skupina (move_ghost, debounced z observera); pri zmazani korpusu sa zmazu (remove_ghost).
# manufactured:false, nikdy v kusovniku. Tag `Noxun/Zóny` (migracia zo stareho NOXUN_SLOTY).
module Noxun
  module Engine
    module Zones
      TAG          = 'Noxun/Zóny'
      OLD_TAG      = 'NOXUN_SLOTY'      # V0.2b tag — migrujeme nan
      GROUP_PREFIX = 'NOXUN_ZONY '      # + cabinet_id
      INSET        = 1.0  # mm — ghost je o kusok mensi nez svetly priestor
      ALPHA        = 0.35
      PALETTE = [
        [70, 190, 255], [110, 255, 150], [255, 175, 80],
        [220, 120, 255], [255, 235, 90]
      ].freeze

      module_function

      # --- verejne API: sync ghost skupiny ------------------------------------

      # Pregeneruje ghost skupinu korpusu zo zon v jeho configu. Volane z build/rebuild
      # (uz vnutri otvorenej operacie). Zmaze staru skupinu a postavi novu na mieste korpusu.
      def sync_ghost(model, inst)
        return unless inst && inst.valid?
        cid = Store.get(inst, 'cabinet_id')
        return unless cid
        migrate_tag(model)
        remove_ghost(model, cid)
        cfg = Store.config(inst) || {}
        zones = cfg['zones'] || []
        leaves = zones.select { |z| leaf?(z) }
        return if leaves.empty?

        tag = model.layers[TAG] || model.layers.add(TAG)
        mats = ensure_materials(model)
        grp = model.entities.add_group
        grp.name = "#{GROUP_PREFIX}#{cid}"
        grp.layer = tag
        Store.write(grp, { std: Store::STD, kind: 'zones_group', id: "#{cid}-ZONY",
                           cabinet_id: cid, role: 'zones_group',
                           manufactured: false, production_class: 'none' })
        leaves.each_with_index do |z, i|
          sub = grp.entities.add_group
          sub.name = "zona_#{z['id']}"
          draw_ghost(sub.entities, sym_pos(z), num(z['width']), num(z['height']), num(z['depth']))
          sub.material = mats[i % mats.length]
          sub.layer = tag
          Store.write(sub, {
            std: Store::STD, kind: 'zone', id: z['id'], cabinet_id: cid,
            role: 'zone', manufactured: false, production_class: 'none',
            config: zone_config_from_flat(z)
          })
        end
        grp.transformation = clean_transform(inst.transformation)
        grp
      rescue StandardError => e
        Engine.log_error(e, 'Zones.sync_ghost') if defined?(Engine)
        nil
      end

      # Len presun existujucej ghost skupiny na aktualnu poziciu korpusu (move/rotate,
      # bez zmeny obsahu). Ak skupina chyba, spadne na plny sync_ghost.
      def move_ghost(model, inst)
        return unless inst && inst.valid?
        cid = Store.get(inst, 'cabinet_id')
        return unless cid
        grp = find_ghost_group(model, cid)
        return sync_ghost(model, inst) unless grp
        grp.transformation = clean_transform(inst.transformation)
        grp
      rescue StandardError => e
        Engine.log_error(e, 'Zones.move_ghost') if defined?(Engine)
        nil
      end

      # Zmaze ghost skupinu korpusu (pri zmazani korpusu / pred pregeneraciou).
      def remove_ghost(model, cid)
        grp = find_ghost_group(model, cid)
        grp.erase! if grp && grp.valid?
        true
      rescue StandardError => e
        Engine.log_error(e, 'Zones.remove_ghost') if defined?(Engine)
        false
      end

      # Najde top-level ghost skupinu korpusu podla NOXUN markera (nie podla mena — meno je len UX).
      def find_ghost_group(model, cid)
        model.entities.grep(Sketchup::Group).find do |g|
          g.valid? && Store.get(g, 'kind') == 'zones_group' && Store.get(g, 'cabinet_id') == cid
        end
      end

      # Zmaze ghost skupiny vsetkych korpusov, ktore uz v modeli neexistuju (upratanie po delete).
      def prune_orphans(model)
        live = {}
        Ids.each_cabinet(model) { |i| live[Store.get(i, 'cabinet_id')] = true }
        model.entities.grep(Sketchup::Group).to_a.each do |g|
          next unless g.valid? && Store.get(g, 'kind') == 'zones_group'
          cid = Store.get(g, 'cabinet_id')
          g.erase! unless live[cid]
        end
      rescue StandardError => e
        Engine.log_error(e, 'Zones.prune_orphans') if defined?(Engine)
        nil
      end

      # Vyberie pod-skupinu zony podla zone_id (obojsmerna sync z panela -> zvyraznenie v modeli).
      def find_zone_group(model, cid, zone_id)
        grp = find_ghost_group(model, cid)
        return nil unless grp
        grp.entities.grep(Sketchup::Group).find do |g|
          g.valid? && Store.get(g, 'id') == zone_id
        end
      end

      # --- viditelnost tagu ---------------------------------------------------

      def set_visible(model, visible)
        migrate_tag(model)
        tag = model.layers[TAG] || model.layers.add(TAG)
        tag.visible = visible ? true : false
        tag.visible?
      end

      def visible?(model)
        tag = model.layers[TAG] || model.layers[OLD_TAG]
        tag ? tag.visible? : true
      end

      # Migracia: stary tag NOXUN_SLOTY -> Noxun/Zóny. Ak novy neexistuje, premenuje stary
      # (zachova viditelnost aj pripadne stare ghosty). Ak oba existuju, stary nechame tak.
      def migrate_tag(model)
        old = model.layers[OLD_TAG]
        return unless old
        return if model.layers[TAG]
        old.name = TAG
      rescue StandardError => e
        Engine.log_error(e, 'Zones.migrate_tag') if defined?(Engine)
        nil
      end

      # --- kreslenie ----------------------------------------------------------

      # Ghost box z pozicie (min roh) a rozmerov (mm), zmenseny o INSET.
      def draw_ghost(ents, position, w, hh, d)
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

      def ensure_materials(model)
        PALETTE.each_with_index.map do |rgb, i|
          name = "NOXUN_slot_#{i}"
          mt = model.materials[name] || model.materials.add(name)
          mt.color = Sketchup::Color.new(*rgb)
          mt.alpha = ALPHA
          mt
        end
      end

      # --- config zony --------------------------------------------------------

      # Config ghostu z plocheho zone objektu (string kluce z ulozeneho configu korpusu).
      def zone_config_from_flat(z)
        shelves = (z['shelves'] || 0).to_i
        {
          parent_zone: z['parent'],
          position: sym_pos(z),
          width: num(z['width']), height: num(z['height']), depth: num(z['depth']),
          state: (shelves.positive? ? 'occupied' : 'free'),
          shelves: shelves,
          allowed_modules: %w[shelf divider_v divider_h drawer_block front_door],
          modules: []
        }
      end

      # --- pomocne ------------------------------------------------------------

      def leaf?(z)
        v = z['leaf']
        v.nil? ? (z['split'].nil?) : v
      end

      def sym_pos(z)
        p = z['position'] || [0, 0, 0]
        [num(p[0]), num(p[1]), num(p[2])]
      end

      def num(v)
        v.to_f
      end

      # Cista transformacia korpusu bez scale (normalizovane osi) — ghosty nikdy deformovane.
      def clean_transform(tr)
        Geom::Transformation.axes(tr.origin, tr.xaxis.normalize, tr.yaxis.normalize, tr.zaxis.normalize)
      rescue StandardError
        tr
      end
    end
  end
end
