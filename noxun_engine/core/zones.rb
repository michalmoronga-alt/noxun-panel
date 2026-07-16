# frozen_string_literal: true
# Noxun Engine — zony (ghost geometria). Standard sekcia 5.1.
#
# V0.2c (fix #6+#7): kazda listova zona = SAMOSTATNA TOP-LEVEL skupina `NOXUN_ZONA <zone_id>`
# priamo v model.entities (uz ZIADNY wrapper). Dovod: klik na zonu = JEDEN klik a rovno vyberie
# entitu s NOXUN dict kind:zone (top-level group sa vybera 1 klikom; wrapper by vyzadoval dvojklik).
# Kazda skupina nesie transformaciu korpusu (clean_transform) a box zony kresli v lokalnom rame.
# Skupiny sa hladaju cez NOXUN dict (kind+cabinet_id), NIE podla mena. Sync/move/prune/remove
# pracuju s MNOZINOU skupin per cabinet_id.
# Sync: pri rebuilde sa pregeneruju (sync_ghost); pri move/rotate korpusu sa len presunu
# (move_ghost, debounced z observera); pri zmazani korpusu sa zmazu (remove_ghost/prune_orphans).
# manufactured:false, nikdy v kusovniku. Tag `Noxun/Zóny` (migracia zo stareho NOXUN_SLOTY).
module Noxun
  module Engine
    module Zones
      TAG          = 'Noxun/Zóny'
      OLD_TAG      = 'NOXUN_SLOTY'      # V0.2b tag — migrujeme nan
      GROUP_PREFIX = 'NOXUN_ZONA '      # + zone_id (jedna skupina = jedna listova zona)
      OLD_WRAP_KIND = 'zones_group'     # V0.2c-early wrapper — upratat pri sync/prune
      INSET        = 1.0  # mm — ghost je o kusok mensi nez svetly priestor
      ALPHA        = 0.35
      PALETTE = [
        [70, 190, 255], [110, 255, 150], [255, 175, 80],
        [220, 120, 255], [255, 235, 90]
      ].freeze

      module_function

      # --- verejne API: sync ghost skupiny ------------------------------------

      # Pregeneruje ghost skupiny korpusu zo zon v jeho configu. Volane z build/rebuild
      # (uz vnutri otvorenej operacie). Zmaze stare skupiny a postavi nove na mieste korpusu.
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
        tr = clean_transform(inst.transformation)
        leaves.each_with_index do |z, i|
          grp = model.entities.add_group
          grp.name = "#{GROUP_PREFIX}#{z['id']}"
          draw_ghost(grp.entities, sym_pos(z), num(z['width']), num(z['height']), num(z['depth']))
          grp.material = mats[i % mats.length]
          grp.layer = tag
          Store.write(grp, {
            std: Store::STD, kind: 'zone', id: z['id'], cabinet_id: cid,
            role: 'zone', manufactured: false, production_class: 'none',
            config: zone_config_from_flat(z)
          })
          grp.transformation = tr
        end
        true
      rescue StandardError => e
        Engine.log_error(e, 'Zones.sync_ghost') if defined?(Engine)
        nil
      end

      # Len presun existujucich ghost skupin korpusu na aktualnu poziciu (move/rotate, bez zmeny
      # obsahu). Ak ziadna skupina neexistuje, spadne na plny sync_ghost.
      def move_ghost(model, inst)
        return unless inst && inst.valid?
        cid = Store.get(inst, 'cabinet_id')
        return unless cid
        grps = find_ghost_groups(model, cid)
        return sync_ghost(model, inst) if grps.empty?
        tr = clean_transform(inst.transformation)
        grps.each { |g| g.transformation = tr if g.valid? }
        true
      rescue StandardError => e
        Engine.log_error(e, 'Zones.move_ghost') if defined?(Engine)
        nil
      end

      # Zmaze vsetky ghost skupiny korpusu (pri zmazani korpusu / pred pregeneraciou).
      # Uprace aj pripadny stary wrapper (kind zones_group) z ranej V0.2c verzie.
      def remove_ghost(model, cid)
        (find_ghost_groups(model, cid) + old_wrappers(model, cid)).each do |g|
          g.erase! if g && g.valid?
        end
        true
      rescue StandardError => e
        Engine.log_error(e, 'Zones.remove_ghost') if defined?(Engine)
        false
      end

      # Vsetky top-level ghost skupiny (listove zony) korpusu — podla NOXUN markera (nie mena).
      def find_ghost_groups(model, cid)
        model.entities.grep(Sketchup::Group).select do |g|
          g.valid? && Store.get(g, 'kind') == 'zone' && Store.get(g, 'cabinet_id') == cid
        end
      end

      # Stare wrapper skupiny (kind zones_group) — migracia z ranej V0.2c schemy.
      def old_wrappers(model, cid = nil)
        model.entities.grep(Sketchup::Group).select do |g|
          g.valid? && Store.get(g, 'kind') == OLD_WRAP_KIND &&
            (cid.nil? || Store.get(g, 'cabinet_id') == cid)
        end
      end

      # Zmaze ghost skupiny vsetkych korpusov, ktore uz v modeli neexistuju (upratanie po delete).
      # Osirotene = cabinet_id, ku ktoremu uz nema ziadna korpus instancia (kind zone aj stary wrapper).
      def prune_orphans(model)
        live = {}
        Ids.each_cabinet(model) { |i| live[Store.get(i, 'cabinet_id')] = true }
        model.entities.grep(Sketchup::Group).to_a.each do |g|
          next unless g.valid?
          k = Store.get(g, 'kind')
          next unless k == 'zone' || k == OLD_WRAP_KIND
          g.erase! unless live[Store.get(g, 'cabinet_id')]
        end
      rescue StandardError => e
        Engine.log_error(e, 'Zones.prune_orphans') if defined?(Engine)
        nil
      end

      # Vyberie top-level ghost skupinu zony podla zone_id (obojsmerna sync z panela -> zvyraznenie).
      def find_zone_group(model, cid, zone_id)
        find_ghost_groups(model, cid).find { |g| Store.get(g, 'id') == zone_id }
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
