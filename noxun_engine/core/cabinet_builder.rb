# frozen_string_literal: true
# Noxun Engine — generator korpusu (dolna + horna). Regenerate pattern (standard sekcia 9):
# build (novy) a rebuild (clear definicie + build_into) — vzdy 1 Undo operacia.
# Geometriu (deskriptory dielcov) pocita CISTO Construction; tu sa len kresli (mm -> Length cez Units).
# Kazdy rebuild je obaleny ScaleWatch.guard, aby scale-observer neignoroval vlastne zmeny.
require 'json'

module Noxun
  module Engine
    module CabinetBuilder
      # Predvolby pre novy vklad. Dolna skrinka: dno POD bokmi (boky stoja na dne),
      # bez sokloveho panela (priestor pre nohy), korpus levituje o floor_height.
      LOWER_DEFAULTS = {
        type: 'lower', width: 600.0, height: 720.0, depth: 510.0, thickness: 18.0,
        floor_height: 100.0, shelves: 0, fronts: 'none',
        bottom_mode: 'under_sides', top_mode: 'full', back_mode: 'overlay', back_thickness: 3.0,
        plinth_mode: 'none', plinth_recess: 50.0,
        rail_depth: 100.0, rails_orientation: 'flat', rails_top_offset: 0.0
      }.freeze

      # Horna skrinka: bez sokla (floor_height 0), dno aj vrch medzi bokmi (boky plna vyska),
      # chrbat default v drazke.
      UPPER_DEFAULTS = {
        type: 'upper', width: 600.0, height: 720.0, depth: 320.0, thickness: 18.0,
        floor_height: 0.0, shelves: 0, fronts: 'none',
        bottom_mode: 'between_sides', top_mode: 'full', back_mode: 'groove', back_thickness: 3.0,
        plinth_mode: 'none', plinth_recess: 50.0,
        rail_depth: 100.0, rails_orientation: 'flat', rails_top_offset: 0.0
      }.freeze

      DEFAULTS = LOWER_DEFAULTS # spatna kompatibilita starych referencii

      GAP_BETWEEN_CABS = 50.0    # medzera medzi korpusmi pri vkladani vedla seba
      UPPER_HANG_Z     = 1400.0  # vyska zavesenia hornej skrinky (Z pri vlozeni)

      MIN = { width: 200.0, height: 200.0, depth: 150.0 }.freeze

      MAT_KORPUS = 'NOXUN_korpus'
      MAT_FRONT  = 'NOXUN_front'

      # DC scaletool bitova maska pre osove scale uchopy (X/Y/Z). Michal potvrdi vizualne;
      # ak by mala byt opacna semantika (skryt plosne+rohove), alternativa je 120.
      SCALE_TOOL_MASK = 7

      # Tagy dielov (V0.2c) — hromadne hide cez nativny Tags panel. Default = Noxun/Korpus.
      PART_TAGS = {
        'back'         => 'Noxun/Chrbát',
        'front_door'   => 'Noxun/Čelá',
        'drawer_front' => 'Noxun/Čelá',
        'shelf'        => 'Noxun/Vnútro',
        'divider_v'    => 'Noxun/Vnútro',
        'divider_h'    => 'Noxun/Vnútro'
      }.freeze
      PART_TAG_DEFAULT = 'Noxun/Korpus'

      class << self
        # --- verejne API ----------------------------------------------------

        # Vlozi novy korpus. Dolna na Z=0 vedla existujucich; horna na Z=UPPER_HANG_Z. Vrati instanciu.
        # Korpus je VZDY top-level (model.entities) — nikdy do aktivneho edit kontextu (inak
        # by sa korpus vlozil do cudzieho komponentu). Preto najprv zavrieme edit kontext.
        def build(model, params)
          ensure_root_context(model)
          cfg = normalize(params)
          cid = Ids.next_cabinet_id(model)
          x = next_x(model)
          z = cfg[:type] == 'upper' ? UPPER_HANG_Z : 0.0
          inst = nil
          # guarded: vlozenie je vlastna zmena pluginu. EntitiesObserver.onElementAdded (davkovany
          # na commit) tak vidi @rebuilding=true a novy korpus nepovazuje za kopiu (ziadny extra tick).
          guarded do
            model.start_operation('NOXUN: Vloz korpus', true)
            begin
              cdef = model.definitions.add("NOXUN Korpus #{cid}")
              cdef.entities.clear!
              final = build_into(model, cdef, cfg, cid)
              tr = Geom::Transformation.translation(Units.point(x, 0, z))
              inst = model.entities.add_instance(cdef, tr)
              write_cabinet_attrs(inst, cid, final)
              apply_scale_lock(inst)
              Zones.sync_ghost(model, inst) if defined?(Zones)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
          end
          ScaleWatch.attach_one(inst) if inst && defined?(ScaleWatch)
          inst
        end

        # Prestavia existujuci korpus. transform: volitelne nova cista transformacia (scale absorpcia).
        # op_name: nazov Undo operacie. Cele obalene guardom, aby scale-observer ignoroval vlastnu zmenu.
        def rebuild(model, inst, params, transform: nil, op_name: 'NOXUN: Aplikuj zmeny')
          cid = Store.get(inst, 'cabinet_id')
          raise 'Vybrana instancia nie je NOXUN korpus.' if cid.nil?

          # KRITICKE (V0.2c bugfix): rebuild musi bezat v ABSOLUTNOM (root) rame.
          # Ak je uzivatel dvojklikom vnoreny v komponente, inst.transformation je
          # interpretovana v edit rame (relativna) a commit by korpus teleportoval
          # na origin. Zavretim edit kontextu citame/zapisujeme transformaciu spravne.
          ensure_root_context(model)

          cfg = normalize(params)
          guarded do
            model.start_operation(op_name, true)
            begin
              # Ak je definicia zdielana (kopia korpusu), osamostatni ju — inak by clear!/build
              # prepisal aj original. Standard 9.3: kopia sa da upravit nezavisle od originalu.
              inst.make_unique if inst.definition.instances.size > 1
              cdef = inst.definition
              cdef.entities.clear!
              final = build_into(model, cdef, cfg, cid)
              inst.transformation = transform if transform
              write_cabinet_attrs(inst, cid, final)
              apply_scale_lock(inst)
              Zones.sync_ghost(model, inst) if defined?(Zones)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
          end
          inst
        end

        # V0.2c fix #6: detekuje kopie korpusu (viac instancii so zdielanym cabinet_id) a kazdej
        # NOVSEJ pridelí nove cabinet_id + prestaví ju. rebuild spraví make_unique (osamostatni
        # zdielanu definiciu) a prepocita part_id, zony aj ghosty pod novym cid. Original zostane
        # netknuty. Vola sa z panel resolvera a scale observera ("sync tick"). Vrati prestavane inst.
        # Standard 2.3/9.3: "Kopia skrinky dostane nove cabinet_id."
        def dedup_copies(model)
          return [] unless model
          dups = Ids.duplicate_cabinets(model)
          return [] if dups.empty?
          done = []
          dups.each do |inst|
            next unless inst && inst.valid?
            new_cid = Ids.next_cabinet_id(model)
            # Prepis identitu na INSTANCII (standard 2.2: autorita = instancia). Config a dielce
            # prepise nasledny rebuild (uz nad vlastnou definiciou z make_unique).
            Store.write(inst, { std: Store::STD, kind: 'cabinet', id: new_cid, cabinet_id: new_cid })
            params = config_to_params(Store.config(inst) || {})
            rebuild(model, inst, params, op_name: 'NOXUN: Kopia korpusu — nove ID')
            done << inst
            Engine.log("dedup: kopia korpusu dostala nove ID #{new_cid}") if defined?(Engine)
          end
          done
        rescue StandardError => e
          Engine.log_error(e, 'CabinetBuilder.dedup_copies') if defined?(Engine)
          []
        end

        # Zavrie vsetky otvorene edit konteksty tak, aby model.active_entities == model.entities.
        # Volane pred build/rebuild — pozri bugfix poznamku v rebuild. Bezpecne aj ked sme uz v roote.
        def ensure_root_context(model)
          guard = 0
          while model.active_path && model.active_path.length.positive? && guard < 20
            model.close_active
            guard += 1
          end
        rescue StandardError => e
          Engine.log_error(e, 'ensure_root_context') if defined?(Engine)
          nil
        end

        # --- jadro stavby ---------------------------------------------------

        # Postavi vsetky dielce + ghost zony do cdef podla planu z Construction. Vrati doplneny config.
        def build_into(model, cdef, cfg, cid)
          plan = Construction.build_plan(cfg, cid) # validuje interne (raise slovensky)
          ents = cdef.entities
          mk = ensure_material(model, MAT_KORPUS, [216, 196, 160])
          mf = ensure_material(model, MAT_FRONT, [245, 245, 245])
          tid = template_id_for(cfg[:type])

          plan[:parts].each do |pd|
            next unless positive_box?(pd[:box]) # ochrana proti degenerovanym dielcom (uzke zony)
            front = pd[:material] == :front
            add_part(model, ents, pd, (front ? mf : mk), (front ? MAT_FRONT : MAT_KORPUS), cid, tid)
          end

          # V0.2c: ghost zony uz NEstoja v definicii korpusu, ale ako top-level skupina
          # (Zones.sync_ghost, volane z build/rebuild) — klik na zonu = 1 klik bez dvojkliku.
          merge_final(cfg, plan)
        end

        # V0.2c: obmedzenie Scale uchopov na osove (X/Y/Z) cez DC "scaletool" atribut.
        # DC plugin (nacitany v modeli) tuto masku respektuje. Hodnota je bitova maska;
        # SCALE_TOOL_MASK = 7 (1+2+4) podla zadania — Michal vizualne potvrdi smer masky.
        # Atribut NEovplyvnuje scale absorpciu (tá cita transformaciu, nie tento kluc).
        def apply_scale_lock(inst)
          return unless inst && inst.valid?
          inst.set_attribute('dynamic_attributes', 'scaletool', SCALE_TOOL_MASK.to_s)
        rescue StandardError => e
          Engine.log_error(e, 'apply_scale_lock') if defined?(Engine)
          nil
        end

        # --- pomocne stavbove ----------------------------------------------

        # Jeden dielec = vlastny komponent s NOXUN dict. Recyklacia definicie podla mena
        # (mena su per-korpus unikatne — obsahuju cid), aby rebuild neprodukoval osirotene definicie.
        def add_part(model, parent_ents, pd, material, material_id, cid, tid)
          dname = "NOXUN #{cid} #{pd[:suffix]}"
          pdef = model.definitions[dname] || model.definitions.add(dname)
          pdef.entities.clear!
          sx, sy, sz = pd[:box]
          draw_box(pdef.entities, sx, sy, sz)
          ox, oy, oz = pd[:origin]
          inst = parent_ents.add_instance(pdef, Geom::Transformation.translation(Units.point(ox, oy, oz)))
          inst.material = material
          inst.layer = part_tag(model, pd[:role]) # tag dielca (Korpus/Chrbát/Čelá/Vnútro)
          pid = Ids.part_id(cid, pd[:suffix])
          Store.write(inst, {
            std: Store::STD, kind: 'part', id: pid, part_id: pid, cabinet_id: cid,
            template_id: tid, role: pd[:role], name: pd[:name],
            manufactured: true, production_class: 'sheet',
            config: {
              length: pd[:prod][:length].round(2), width: pd[:prod][:width].round(2),
              thickness: pd[:prod][:thickness].round(2), quantity: 1,
              material_id: material_id, grain_direction: 'none',
              edges: { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
            }
          })
          inst
        end

        def positive_box?(box)
          box && box.all? { |v| v.to_f > 0.01 }
        end

        # Tag (layer) dielca podla roly — zabezpeci jeho existenciu. Hromadne hide v Tags paneli.
        def part_tag(model, role)
          name = PART_TAGS[role.to_s] || PART_TAG_DEFAULT
          model.layers[name] || model.layers.add(name)
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

        # --- config korpusu (standard sekcia 2.5) --------------------------

        def write_cabinet_attrs(inst, cid, cfg)
          Store.write(inst, {
            std: Store::STD, kind: 'cabinet', id: cid, cabinet_id: cid,
            template_id: template_id_for(cfg[:type]), role: 'cabinet',
            manufactured: false, production_class: 'reference',
            config: cabinet_config(cfg)
          })
          inst.name = "Korpus #{cid}"
          inst
        end

        def cabinet_config(cfg)
          {
            type: cfg[:type],
            name: cfg[:name] || default_name(cfg),
            construction_preset: cfg[:type] == 'upper' ? 'noxun-upper-18' : 'noxun-lower-18',
            mode: 'parametric',
            width: cfg[:width], height: cfg[:height], depth: cfg[:depth],
            thickness: cfg[:thickness], floor_height: cfg[:floor_height],
            # ploche variant kluce = zdroj pravdy pre round-trip panela
            bottom_mode: cfg[:bottom_mode], top_mode: cfg[:top_mode], back_mode: cfg[:back_mode],
            back_thickness: cfg[:back_thickness],
            plinth_mode: cfg[:plinth_mode], plinth_recess: cfg[:plinth_recess],
            rail_depth: cfg[:rail_depth], rails_orientation: cfg[:rails_orientation],
            rails_top_offset: cfg[:rails_top_offset],
            material_id: 'K009_PW_DTDL_18', back_material_id: 'HDF_WHITE_3',
            # vnorene standardne objekty (odvodene)
            sides:   { thickness: cfg[:thickness], construction: 'sides_wrap' },
            bottom:  { mode: cfg[:bottom_mode], thickness: cfg[:thickness] },
            top:     { mode: cfg[:top_mode], thickness: cfg[:thickness],
                       rail_depth: cfg[:rail_depth], orientation: cfg[:rails_orientation],
                       top_offset: cfg[:rails_top_offset] },
            back:    { mode: cfg[:back_mode], thickness: cfg[:back_thickness] },
            support: support_descriptor(cfg),
            available_width: cfg[:available_width],
            available_height: cfg[:available_height],
            available_depth: cfg[:available_depth],
            front_plane: cfg[:front_plane] || 0.0,
            wings: cfg[:wings],
            # V0.2b: strom zon (strukturny zdroj pravdy) + ploche zony (cache) + cela
            zone_tree: cfg[:zone_tree],
            zones: cfg[:zones],
            fronts: cfg[:fronts],
            front_items: cfg[:front_items]
          }
        end

        def support_descriptor(cfg)
          if cfg[:type] == 'upper' || cfg[:floor_height].to_f <= 0
            { type: 'none', height: 0.0 }
          elsif cfg[:plinth_mode] == 'front'
            { type: 'plinth', height: cfg[:floor_height], recess: cfg[:plinth_recess] }
          else
            { type: 'legs', height: cfg[:floor_height] } # nohy (geometria az neskor)
          end
        end

        def default_name(cfg)
          cfg[:type] == 'upper' ? "Horna skrinka #{cfg[:width].round}" : "Spodna skrinka #{cfg[:width].round}"
        end

        def template_id_for(type)
          type == 'upper' ? 'base-upper-18' : 'base-lower-18'
        end

        def merge_final(cfg, plan)
          cfg.merge(
            available_width: plan[:available][:width].round(2),
            available_height: plan[:available][:height].round(2),
            available_depth: plan[:available][:depth].round(2),
            front_plane: 0.0,
            wings: plan[:wings],
            zones: plan[:zones],
            zone_tree: plan[:zone_tree],
            front_items: plan[:front_items]
          )
        end

        # --- normalizacia parametrov ---------------------------------------

        def defaults_for(type)
          type == 'upper' ? UPPER_DEFAULTS : LOWER_DEFAULTS
        end

        def normalize(params)
          p = params || {}
          type = norm_type(p)
          d = defaults_for(type)
          {
            type: type,
            width:  clampf(fetchf(p, :width,  d[:width]),  MIN[:width],  3000.0),
            height: clampf(fetchf(p, :height, d[:height]), MIN[:height], 3000.0),
            depth:  clampf(fetchf(p, :depth,  d[:depth]),  MIN[:depth],  2000.0),
            thickness: clampf(fetchf(p, :thickness, d[:thickness]), 6.0, 50.0),
            floor_height: type == 'upper' ? 0.0 : clampf(fetchf(p, :floor_height, d[:floor_height]), 0.0, 500.0),
            bottom_mode: enum_val(p, :bottom_mode, %w[between_sides under_sides], d[:bottom_mode]),
            top_mode:    enum_val(p, :top_mode,    %w[full two_rails none],       d[:top_mode]),
            back_mode:   enum_val(p, :back_mode,   %w[overlay inset groove],      d[:back_mode]),
            # hrubka chrbta ako Float mm (3 HDF / 18 pevny / ine); clamp 1..50
            back_thickness: clampf(fetchf(p, :back_thickness, d[:back_thickness]), 1.0, 50.0),
            plinth_mode: type == 'upper' ? 'none' : enum_val(p, :plinth_mode, %w[none front], d[:plinth_mode]),
            plinth_recess: clampf(fetchf(p, :plinth_recess, d[:plinth_recess]), 0.0, 300.0),
            # two_rails parametre (uplatnia sa len pri top_mode == 'two_rails')
            rail_depth: clampf(fetchf(p, :rail_depth, d[:rail_depth]), 20.0, 400.0),
            rails_orientation: enum_val(p, :rails_orientation, %w[flat upright], d[:rails_orientation]),
            rails_top_offset: clampf(fetchf(p, :rails_top_offset, d[:rails_top_offset]), 0.0, 500.0),
            # V0.2b: strom zon (police su per-zona) + cela (fixed/auto s lockmi)
            zone_tree: norm_zone_tree(p),
            fronts: Fronts.normalize_config(raw(p, :fronts)),
            name: (p['name'] || p[:name])
          }
        end

        # zone_tree z params; ak chyba, ale je legacy 'shelves' -> koren so shelves; inak prazdny koren.
        def norm_zone_tree(p)
          zt = raw(p, :zone_tree)
          return ZoneTree.sanitize(zt) if zt.is_a?(Hash)
          sh = raw(p, :shelves)
          ZoneTree.default_tree(sh.nil? || sh.to_s.strip.empty? ? 0 : sh.to_i)
        end

        # Config (stored, string kluce) -> params pre normalize. Doplna spatnu kompatibilitu:
        # stare V0.1/V0.2a configy (bez zone_tree, fronts ako string, shelves top-level).
        def config_to_params(cfg)
          {
            'type' => cfg['type'] || 'lower',
            'width' => cfg['width'], 'height' => cfg['height'], 'depth' => cfg['depth'],
            'thickness' => cfg['thickness'], 'floor_height' => cfg['floor_height'],
            'bottom_mode' => cfg['bottom_mode'] || legacy_bottom(cfg),
            'top_mode'    => cfg['top_mode']    || legacy_top(cfg),
            'back_mode'   => cfg['back_mode']   || legacy_back(cfg),
            'back_thickness' => cfg['back_thickness'] || legacy_back_thickness(cfg),
            'plinth_mode' => cfg['plinth_mode'] || legacy_plinth(cfg),
            'plinth_recess' => cfg['plinth_recess'] || 50.0,
            'rail_depth' => cfg['rail_depth'] || 100.0,
            'rails_orientation' => cfg['rails_orientation'] || 'flat',
            'rails_top_offset' => cfg['rails_top_offset'] || 0.0,
            # strom zon: novy config ho ma; stary korpus -> koren so starymi policami
            'zone_tree' => cfg['zone_tree'] || ZoneTree.default_tree((cfg['shelves'] || 0).to_i),
            # cela: novy config = hash; stary = string ('none'/'1'/'2'/'auto') -> Fronts.normalize
            'fronts' => cfg.key?('fronts') ? cfg['fronts'] : nil,
            'name' => cfg['name']
          }
        end

        def legacy_back_thickness(cfg)
          (cfg['back'] && cfg['back']['thickness']) || Construction::BACK_THICKNESS_DEFAULT
        end

        def legacy_bottom(cfg)
          (cfg['bottom'] && cfg['bottom']['mode']) || 'between_sides'
        end

        def legacy_top(cfg)
          m = cfg['top'] && cfg['top']['mode']
          (m.nil? || m == 'full_panel') ? 'full' : m
        end

        def legacy_back(cfg)
          (cfg['back'] && cfg['back']['mode']) || 'overlay'
        end

        # Stary V0.1 korpus mal vzdy predny sokel (support.type='plinth'); horny ziadny.
        def legacy_plinth(cfg)
          return 'none' if (cfg['type'] || 'lower') == 'upper'
          sup = cfg['support']
          sup && sup['type'] == 'plinth' ? 'front' : (cfg['floor_height'].to_f > 0 ? 'front' : 'none')
        end

        # --- pomocne --------------------------------------------------------

        def next_x(model)
          max_right = nil
          Ids.each_cabinet(model) do |inst|
            r = Units.to_mm(inst.bounds.max.x)
            max_right = r if max_right.nil? || r > max_right
          end
          max_right.nil? ? 0.0 : max_right + GAP_BETWEEN_CABS
        end

        def norm_type(p)
          (raw(p, :type)).to_s == 'upper' ? 'upper' : 'lower'
        end

        def enum_val(p, key, allowed, default)
          v = raw(p, key)
          allowed.include?(v.to_s) ? v.to_s : default
        end

        def ensure_material(model, name, rgb)
          mt = model.materials[name] || model.materials.add(name)
          mt.color = Sketchup::Color.new(*rgb)
          mt
        end

        def raw(p, key)
          v = p[key.to_s]
          v.nil? ? p[key] : v
        end

        def fetchf(p, key, default)
          v = raw(p, key)
          return default if v.nil? || v.to_s.strip.empty?
          v.to_f
        end

        def clampf(v, lo, hi)
          v = v.to_f
          return lo if v < lo
          return hi if v > hi
          v
        end

        def guarded
          if defined?(ScaleWatch)
            ScaleWatch.guard { yield }
          else
            yield
          end
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
