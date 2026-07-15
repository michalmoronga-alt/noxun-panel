# frozen_string_literal: true
# Noxun Engine — generator SPODNEHO korpusu. Regenerate pattern (standard sekcia 9):
# build (novy) a rebuild (clear definicie + build_into) — vzdy 1 Undo operacia.
# mm Float v datach; .mm sa deje LEN tu cez Units (hranica kreslenia).
require 'json'

module Noxun
  module Engine
    module CabinetBuilder
      DEFAULTS = {
        width: 600.0, height: 720.0, depth: 510.0, thickness: 18.0,
        floor_height: 100.0, shelves: 0, fronts: 'none'
      }.freeze

      BACK_THICKNESS    = 3.0    # chrbat
      PLINTH_INSET      = 50.0   # sokel zapusteny od cela
      SHELF_FRONT_INSET = 20.0   # police odsadene od cela
      GAP_BETWEEN_CABS  = 50.0   # medzera medzi korpusmi pri vkladani vedla seba

      MAT_KORPUS = 'NOXUN_korpus'
      MAT_FRONT  = 'NOXUN_front'

      class << self
        # --- verejne API ----------------------------------------------------

        # Vlozi novy korpus vedla existujucich. Vrati instanciu.
        def build(model, params)
          cfg = normalize(params)
          cid = Ids.next_cabinet_id(model)
          x = next_x(model)
          inst = nil
          model.start_operation('NOXUN: Vloz korpus', true)
          begin
            cdef = model.definitions.add("NOXUN Korpus #{cid}")
            cdef.entities.clear!
            final = build_into(model, cdef, cfg, cid)
            tr = Geom::Transformation.translation(Units.point(x, 0, 0))
            inst = model.active_entities.add_instance(cdef, tr)
            write_cabinet_attrs(inst, cid, final)
            model.commit_operation
          rescue StandardError => e
            abort_safely(model)
            raise e
          end
          inst
        end

        # Prestavia existujuci korpus podla novych parametrov (rebuild).
        def rebuild(model, inst, params)
          cid = Store.get(inst, 'cabinet_id')
          raise 'Vybrana instancia nie je NOXUN korpus.' if cid.nil?

          cfg = normalize(params)
          model.start_operation('NOXUN: Aplikuj zmeny', true)
          begin
            cdef = inst.definition
            cdef.entities.clear!
            final = build_into(model, cdef, cfg, cid)
            write_cabinet_attrs(inst, cid, final)
            model.commit_operation
          rescue StandardError => e
            abort_safely(model)
            raise e
          end
          inst
        end

        # --- jadro stavby ---------------------------------------------------

        # Postavi vsetky dielce + ghost zony do cdef. Vrati doplneny config (Hash).
        def build_into(model, cdef, cfg, cid)
          w = cfg[:width]; h = cfg[:height]; d = cfg[:depth]
          t = cfg[:thickness]; s = cfg[:floor_height]
          validate!(w, h, d, t, s)

          ents = cdef.entities
          mk = ensure_material(model, MAT_KORPUS, [216, 196, 160])
          ensure_material(model, MAT_FRONT, [245, 245, 245])

          # Boky — pln vyska (side_left / side_right)
          add_part(model, ents, [t, d, h], [0, 0, 0], mk, cid, 'SIDE-L', 'side_left',
                   'Bok lavy', { length: h, width: d, thickness: t }, MAT_KORPUS)
          add_part(model, ents, [t, d, h], [w - t, 0, 0], mk, cid, 'SIDE-R', 'side_right',
                   'Bok pravy', { length: h, width: d, thickness: t }, MAT_KORPUS)

          # Dno — medzi bokmi, na sokli
          add_part(model, ents, [w - 2 * t, d, t], [t, 0, s], mk, cid, 'BOTTOM', 'bottom',
                   'Dno', { length: w - 2 * t, width: d, thickness: t }, MAT_KORPUS)

          # Vrch — pln, medzi bokmi
          add_part(model, ents, [w - 2 * t, d, t], [t, 0, h - t], mk, cid, 'TOP', 'top',
                   'Vrch', { length: w - 2 * t, width: d, thickness: t }, MAT_KORPUS)

          # Chrbat — nalozeny zozadu (Y = d .. d+3)
          add_part(model, ents, [w, BACK_THICKNESS, h - s], [0, d, s], mk, cid, 'BACK', 'back',
                   'Chrbat', { length: w, width: h - s, thickness: BACK_THICKNESS }, MAT_KORPUS)

          # Sokel — zapusteny 50 od cela
          add_part(model, ents, [w - 2 * t, t, s], [t, PLINTH_INSET, 0], mk, cid, 'PLINTH', 'plinth',
                   'Sokel', { length: w - 2 * t, width: s, thickness: t }, MAT_KORPUS)

          # Police — rovnomerne
          clear_z0 = s + t
          clear_z1 = h - t
          sh = Shelves.layout(clear_z0, clear_z1, t, cfg[:shelves])
          shelf_depth = d - SHELF_FRONT_INSET
          sh[:shelves].each do |shelf|
            n = shelf[:index] + 1
            add_part(model, ents, [w - 2 * t, shelf_depth, t], [t, SHELF_FRONT_INSET, shelf[:z]],
                     mk, cid, "SHELF-#{n}", 'shelf', "Polica #{n}",
                     { length: w - 2 * t, width: shelf_depth, thickness: t }, MAT_KORPUS)
          end

          # Dvierka — pred korpusom (Y zaporne)
          mf = model.materials[MAT_FRONT]
          fr = Fronts.layout(cfg[:fronts], w, h, s, t)
          fr[:parts].each do |dr|
            nm = case dr[:suffix]
                 when 'DOOR-L' then 'Dvierka lave'
                 when 'DOOR-R' then 'Dvierka prave'
                 else 'Dvierka'
                 end
            add_part(model, ents, [dr[:width], t, dr[:height]], [dr[:x], -t, dr[:z]],
                     mf, cid, dr[:suffix], dr[:role], nm,
                     { length: dr[:height], width: dr[:width], thickness: t }, MAT_FRONT)
          end

          # Zony (ghost) — medzi policami, po chrbat
          box = { x0: t, x1: w - t, y0: 0.0, y1: d - BACK_THICKNESS }
          zone_ids = Zones.build_into(model, ents, sh[:zones], box, cid)

          cfg.merge(
            available_width: (w - 2 * t).round(2),
            available_height: (clear_z1 - clear_z0).round(2),
            available_depth: (d - BACK_THICKNESS).round(2),
            front_plane: 0.0,
            wings: fr[:wings],
            zones: zone_ids
          )
        end

        # --- pomocne --------------------------------------------------------

        # Jeden dielec = vlastny komponent s NOXUN dict. box/origin/prod v mm.
        def add_part(model, parent_ents, box, origin, material, cid, suffix, role, name, prod, material_id)
          # Recyklacia definicie podla mena (mena su per-korpus unikatne: obsahuju cid),
          # aby rebuild neprodukoval osirotene definicie. NIE purge_unused (undo-safe).
          dname = "NOXUN #{cid} #{suffix}"
          pdef = model.definitions[dname] || model.definitions.add(dname)
          pdef.entities.clear! # cerstva geometria pri kazdom rebuilde
          draw_box(pdef.entities, box[0], box[1], box[2])
          tr = Geom::Transformation.translation(Units.point(origin[0], origin[1], origin[2]))
          inst = parent_ents.add_instance(pdef, tr)
          inst.material = material
          pid = Ids.part_id(cid, suffix)
          Store.write(inst, {
            std: Store::STD, kind: 'part', id: pid, part_id: pid, cabinet_id: cid,
            template_id: 'base-lower-18', role: role, name: name,
            manufactured: true, production_class: 'sheet',
            config: {
              length: prod[:length].round(2), width: prod[:width].round(2),
              thickness: prod[:thickness].round(2), quantity: 1,
              material_id: material_id, grain_direction: 'none',
              edges: { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
            }
          })
          inst
        end

        # Box od (0,0,0) rozmerov sx,sy,sz (mm). Kontrola normaly pred pushpull.
        def draw_box(ents, sx, sy, sz)
          pts = [
            Units.point(0, 0, 0), Units.point(sx, 0, 0),
            Units.point(sx, sy, 0), Units.point(0, sy, 0)
          ]
          f = ents.add_face(pts)
          f.reverse! if f.normal.z < 0
          f.pushpull(Units.mm(sz))
          f
        end

        # Config korpusu podla standardu sekcia 2.5.
        def write_cabinet_attrs(inst, cid, cfg)
          Store.write(inst, {
            std: Store::STD, kind: 'cabinet', id: cid, cabinet_id: cid,
            template_id: 'base-lower-18', role: 'cabinet',
            manufactured: false, production_class: 'reference',
            config: cabinet_config(cfg)
          })
          inst.name = "Korpus #{cid}"
          inst
        end

        def cabinet_config(cfg)
          {
            type: 'lower',
            name: cfg[:name] || "Spodna skrinka #{cfg[:width].round}",
            construction_preset: 'noxun-lower-18',
            mode: 'parametric',
            width: cfg[:width], height: cfg[:height], depth: cfg[:depth],
            thickness: cfg[:thickness], floor_height: cfg[:floor_height],
            shelves: cfg[:shelves], fronts: cfg[:fronts].to_s,
            material_id: 'K009_PW_DTDL_18', back_material_id: 'HDF_WHITE_3',
            sides:   { thickness: cfg[:thickness], construction: 'sides_wrap' },
            bottom:  { mode: 'between_sides', thickness: cfg[:thickness] },
            top:     { mode: 'full_panel', thickness: cfg[:thickness] },
            back:    { mode: 'overlay', thickness: BACK_THICKNESS },
            support: { type: 'plinth', height: cfg[:floor_height] },
            available_width: cfg[:available_width],
            available_height: cfg[:available_height],
            available_depth: cfg[:available_depth],
            front_plane: cfg[:front_plane],
            wings: cfg[:wings],
            zones: cfg[:zones]
          }
        end

        # Nova pozicia X = prava hrana najpravejsieho korpusu + medzera (mm).
        def next_x(model)
          max_right = nil
          Ids.each_cabinet(model) do |inst|
            r = Units.to_mm(inst.bounds.max.x)
            max_right = r if max_right.nil? || r > max_right
          end
          max_right.nil? ? 0.0 : max_right + GAP_BETWEEN_CABS
        end

        def normalize(params)
          p = params || {}
          {
            width:        clampf(fetch(p, :width, DEFAULTS[:width]), 100.0, 3000.0),
            height:       clampf(fetch(p, :height, DEFAULTS[:height]), 100.0, 3000.0),
            depth:        clampf(fetch(p, :depth, DEFAULTS[:depth]), 100.0, 2000.0),
            thickness:    clampf(fetch(p, :thickness, DEFAULTS[:thickness]), 6.0, 50.0),
            floor_height: clampf(fetch(p, :floor_height, DEFAULTS[:floor_height]), 0.0, 500.0),
            shelves:      Shelves.clamp(fetch(p, :shelves, DEFAULTS[:shelves]).to_i),
            fronts:       front_mode(p),
            name:         (p['name'] || p[:name])
          }
        end

        def front_mode(p)
          v = (p['fronts'] || p[:fronts] || DEFAULTS[:fronts]).to_s
          %w[none 1 2 auto].include?(v) ? v : 'none'
        end

        def validate!(w, h, d, t, s)
          raise 'Sirka je prilis mala vzhladom na hrubku materialu.' if w <= 2 * t + 10
          raise 'Vyska je prilis mala (sokel + 2x hrubka + priestor).' if h <= s + 2 * t + 10
          raise 'Hlbka je prilis mala.' if d <= BACK_THICKNESS + 10
          raise 'Sokel nesmie byt vyssi nez korpus.' if s >= h
        end

        def ensure_material(model, name, rgb)
          mt = model.materials[name] || model.materials.add(name)
          mt.color = Sketchup::Color.new(*rgb)
          mt
        end

        def fetch(p, key, default)
          v = p[key.to_s]
          v = p[key] if v.nil?
          return default if v.nil? || v.to_s.strip.empty?
          v.to_f
        end

        def clampf(v, lo, hi)
          v = v.to_f
          return lo if v < lo
          return hi if v > hi
          v
        end

        def abort_safely(model)
          model.abort_operation
        rescue StandardError
          nil
        end
      end
    end
  end
end
