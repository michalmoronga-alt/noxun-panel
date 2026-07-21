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
        plinth_mode: 'none', plinth_recess: 40.0,
        rail_depth: 100.0, rails_orientation: 'flat', rails_top_offset: 0.0
      }.freeze

      # Horna skrinka: bez sokla (floor_height 0), dno aj vrch medzi bokmi (boky plna vyska),
      # chrbat default v drazke.
      UPPER_DEFAULTS = {
        type: 'upper', width: 600.0, height: 720.0, depth: 320.0, thickness: 18.0,
        floor_height: 0.0, shelves: 0, fronts: 'none',
        bottom_mode: 'between_sides', top_mode: 'full', back_mode: 'groove', back_thickness: 3.0,
        plinth_mode: 'none', plinth_recess: 40.0,
        rail_depth: 100.0, rails_orientation: 'flat', rails_top_offset: 0.0
      }.freeze

      GAP_BETWEEN_CABS = 50.0    # medzera medzi korpusmi pri vkladani vedla seba
      UPPER_HANG_Z     = 1400.0  # vyska zavesenia hornej skrinky (Z pri vlozeni)

      MIN = { width: 200.0, height: 200.0, depth: 150.0 }.freeze

      # Fallback farby SketchUp materialu, ak material_id nie je v katalogu (Materials preberie color).
      FALLBACK_RGB_KORPUS = [216, 196, 160].freeze
      FALLBACK_RGB_FRONT  = [245, 245, 245].freeze

      # DC scaletool bitova maska = uchopy na SKRYTIE (dogfood D-06, potvrdene 19.7.):
      # 120 = 8+16+32+64 (roviny XY/XZ/YZ + rohy) -> ostavaju CISTE osi X/Y/Z (1+2+4).
      # Povodna hodnota 7 z V0.2c skryvala presne opacne (osi prec, rohy ostali).
      SCALE_TOOL_MASK = 120
      FRONT_VALIDATION_VERSION = '0.3.1'

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
      HARDWARE_TAG     = 'Noxun/Kovanie'

      # Vizual noh (V0.4): generic valec — priemer/segmenty/odsadenie od hran korpusu.
      LEG_DIAMETER   = 50.0
      LEG_SEGMENTS   = 12
      LEG_INSET      = 60.0
      # Vizualny strop kreslenych noh — quantity v DATACH plati vzdy (supis), geometria
      # je proxy a nesmie polozit SketchUp pri poskodenom/extremnom pocte (audit D7).
      LEG_RENDER_MAX = 16

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
              Zones.sync_ghost(model, inst) if defined?(Zones)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
            # D-40: scale zamok az PO commite vlozenia, v transparentnom follow-upe.
            # DC atribut v operacii, ktora entity VYTVARA, by pri commite cez DC
            # extension observer vypol dorucovanie selection eventov celemu modelu
            # (Inspector by visel na starom vybere az do zmeny edit kontextu).
            apply_scale_lock_op(model, inst)
          end
          ScaleWatch.attach_one(inst) if inst && defined?(ScaleWatch)
          inst
        end

        # Prestavia existujuci korpus. transform: volitelne nova cista transformacia (scale absorpcia).
        # op_name: nazov Undo operacie. Cele obalene guardom, aby scale-observer ignoroval vlastnu zmenu.
        # transparent: true = operacia sa pripoji k PREDCHADZAJUCEJ na undo stacku (observer reakcie
        # na pouzivatelov krok — scale absorpcia; 1x undo potom vrati oboje naraz).
        def rebuild(model, inst, params, transform: nil, op_name: 'NOXUN: Aplikuj zmeny', transparent: false)
          cid = Store.get(inst, 'cabinet_id')
          raise 'Vybrana instancia nie je NOXUN korpus.' if cid.nil?

          # KRITICKE (V0.2c bugfix): rebuild musi bezat v ABSOLUTNOM (root) rame.
          # Ak je uzivatel dvojklikom vnoreny v komponente, inst.transformation je
          # interpretovana v edit rame (relativna) a commit by korpus teleportoval
          # na origin. Zavretim edit kontextu citame/zapisujeme transformaciu spravne.
          ensure_root_context(model)

          cfg = normalize(params)
          guarded do
            model.start_operation(op_name, true, false, transparent)
            begin
              # Ak je definicia zdielana (kopia korpusu), osamostatni ju — inak by clear!/build
              # prepisal aj original. Standard 9.3: kopia sa da upravit nezavisle od originalu.
              rebuild_in_operation(model, inst, cfg, transform: transform)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
          end
          inst
        end

        # Prestavi viac korpusov v JEDNEJ SketchUp operacii. Volitelny blok sa
        # vykona v tej istej operacii pred rebuildami (napr. zapis projektoveho
        # defaultu), takze chyba vrati naspat aj data aj geometriu.
        def rebuild_many(model, items, op_name: 'NOXUN: Hromadny prepocet')
          prepared = Array(items).map do |entry|
            inst, params = entry
            cid = Store.get(inst, 'cabinet_id')
            raise 'Jedna z instancii nie je NOXUN korpus.' if cid.nil?
            [inst, normalize(params)]
          end

          ensure_root_context(model)
          guarded do
            model.start_operation(op_name, true)
            begin
              yield if block_given?
              prepared.each { |inst, cfg| rebuild_in_operation(model, inst, cfg) }
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
          end
          prepared.map(&:first)
        end

        # Vnutorna cast rebuildu; volajuci uz musi mat otvorenu operaciu a guard.
        def rebuild_in_operation(model, inst, cfg, transform: nil)
          cid = Store.get(inst, 'cabinet_id')
          raise 'Vybrana instancia nie je NOXUN korpus.' if cid.nil?

          inst.make_unique if inst.definition.instances.size > 1
          cdef = inst.definition
          cdef.entities.clear!
          final = build_into(model, cdef, cfg, cid)
          inst.transformation = transform if transform
          write_cabinet_attrs(inst, cid, final)
          apply_scale_lock(inst)
          Zones.sync_ghost(model, inst) if defined?(Zones)
          inst
        end

        # V0.2c fix #6: detekuje kopie korpusu (viac instancii so zdielanym cabinet_id) a kazdej
        # NOVSEJ pridelí nove cabinet_id + prestaví ju. rebuild spraví make_unique (osamostatni
        # zdielanu definiciu) a prepocita part_id, zony aj ghosty pod novym cid. Original zostane
        # netknuty. Vola sa z panel resolvera a scale observera ("sync tick"). Vrati prestavane inst.
        # Standard 2.3/9.3: "Kopia skrinky dostane nove cabinet_id."
        # transparent: true LEN ked volajuci VIE, ze predchadzajuca operacia je vlozenie kopie
        # (observer tick s cerstvym onElementAdded) — vtedy 1x undo vrati kopiu CELU.
        # Z panel sync cesty (push_selected) a inych kontextov = false: samostatny undo krok,
        # aby sa dedup neprilepil na nesuvisiacu poslednu akciu (Codex review PR #21).
        # fresh_ids (V0.4.7b, Codex audit + GH review P2): entityID mnozina PRAVE
        # pridanych entit. Ak je dana, spracuju sa IBA tieto duplikaty (transparentne
        # k pouzivatelovmu paste kroku); STARE duplicity sa v tomto ticku NEDOTKNU —
        # observer si na ne naplanuje follow-up tick (samostatne undo kroky). Inak by
        # miesana davka stale+fresh rozbila vazbu transparentneho undo na paste.
        def dedup_copies(model, transparent: false, fresh_ids: nil)
          return [] unless model
          dups = Ids.duplicate_cabinets(model)
          dups = dups.select { |i| i && i.valid? && fresh_ids.include?(i.entityID) } if fresh_ids
          return [] if dups.empty?
          # Root kontext ako v rebuild (Codex review PR #21): dedup moze bezat aj pocas
          # editacie komponentu — bez zatvorenia edit ramca by sa transformacia kopie
          # citala relativne a ghost zony by vznikli na zlom mieste.
          ensure_root_context(model)
          done = []
          dups.each do |inst|
            next unless inst && inst.valid?
            new_cid = Ids.next_cabinet_id(model)
            trans = fresh_ids ? true : transparent
            # V0.3.4 undo fix (runner S2): prepis identity (standard 2.2: autorita = instancia)
            # + rebuild bezia v JEDNEJ operacii (transparentnej len pri cerstvej kopii, viz vyssie).
            # Predtym sa nove cid zapisovalo MIMO operacie a po undo ostaval nekonzistentny medzistav.
            guarded do
              model.start_operation('NOXUN: Kopia korpusu — nove ID', true, false, trans)
              begin
                Store.write(inst, { std: Store::STD, kind: 'cabinet', id: new_cid, cabinet_id: new_cid })
                params = config_to_params(Store.config(inst) || {})
                rebuild_in_operation(model, inst, normalize(params))
                model.commit_operation
              rescue StandardError => e
                abort_safely(model)
                raise e
              end
            end
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
        #
        # V0.3 materialy + ABS: kazdemu dielcu sa vyriesi VYSLEDNY material_id a ABS hrany cez retaz
        # (standard 7.2): pravidlove defaulty roly -> dedenie projekt->korpus -> part_override (viťazi).
        # Vysledok sa zapise do configu dielca (dielec vzdy nesie KONKRETNY material = "zaradeny" stav).
        def build_into(model, cdef, cfg, cid)
          # Pravidla kovania = PROJEKTOVY snapshot (reprodukovatelnost z .skp — audit K2).
          # Prvy build ho zapise z globalnej kniznice; sme VNUTRI operacie volajuceho,
          # takze undo vrati model aj snapshot naraz.
          rules = defined?(HardwareRules) ? HardwareRules.ensure_project_rules!(model) : nil
          plan = Construction.build_plan(cfg, cid, hardware_rules: rules) # validuje interne
          ents = cdef.entities
          tid = template_id_for(cfg[:type])

          # Efektivne korpusove materialy = korpus config, inak dedenie z projektovych defaultov (model).
          defaults = defined?(Materials) ? Materials.project_defaults(model) : {}
          eff_body  = present(cfg[:material_id])       || defaults['default_material_id']
          eff_front = present(cfg[:front_material_id]) || defaults['default_front_material_id']
          eff_back  = present(cfg[:back_material_id])  || defaults['default_back_material_id']
          overrides = PartKeys.migrate_overrides(cfg[:part_overrides], plan[:parts])
          cfg = cfg.merge(part_overrides: overrides, part_key_schema: PartKeys::SCHEMA)

          plan[:parts].each do |pd|
            next unless positive_box?(pd[:box]) # ochrana proti degenerovanym dielcom (uzke zony)
            resolved = resolve_part(pd, eff_body, eff_front, eff_back, overrides)
            add_part(model, ents, pd, resolved, cid, tid)
          end

          render_hardware(model, ents, plan[:hardware], cfg, cid)

          # V0.2c: ghost zony uz NEstoja v definicii korpusu, ale ako top-level skupina
          # (Zones.sync_ghost, volane z build/rebuild) — klik na zonu = 1 klik bez dvojkliku.
          merge_final(cfg, plan)
        end

        # Vyriesi material + ABS hrany jedneho dielca cez stabilny part_key.
        # Renderovaci suffix a part_id ostavaju nezmenene; uz nie su datovym klucom override.
        # part_key je stabilny pri presune cela aj pri zmenach susednych zon;
        # role_key zostava iba kompatibilny nazov pola v sucasnom UI protokole.
        def resolve_part(pd, eff_body, eff_front, eff_back, overrides)
          part_key = PartKeys.for_descriptor(pd)
          ov = overrides[part_key].is_a?(Hash) ? overrides[part_key] : {}
          base_mat = base_material_for(pd[:role], pd[:material], eff_body, eff_front, eff_back)
          mat_id = present(ov['material_id']) || base_mat
          # Jeden lookup doskoveho materialu — pouzity na dekor (ABS) aj hrubkovu kontrolu (V0.3 FIX 2).
          sheet = (defined?(Materials) && mat_id) ? Materials.sheet(mat_id) : nil
          validate_material_thickness!(mat_id, sheet, pd)
          decor = sheet && sheet['decor']
          base_edges = defined?(AbsRules) ? AbsRules.resolve_edges(pd[:role], decor) : empty_edges
          edges = base_edges.merge(known_edges(ov['edges']))
          grain = sheet && sheet['grain'].to_s
          grain = 'none' unless %w[length width none].include?(grain)
          { part_key: part_key, role_key: part_key, material_id: mat_id, edges: edges,
            grain_direction: grain, sheet_thickness: (sheet && sheet['thickness']) }
        end

        # Katalogovy material s nespravnou hrubkou nesmie vytvorit rozpor medzi
        # geometriou a vyrobnymi datami. Legacy material mimo katalogu ponechavame.
        # Cela su specialny pripad: povolene varianty 18/19 mm upravia aj geometriu.
        def validate_material_thickness!(mat_id, sheet, pd)
          return unless mat_id && sheet
          want = pd[:prod][:thickness].to_f
          have = sheet['thickness'].to_f
          return if thickness_ok_for?(pd[:role], want, have)
          raise "Material #{mat_id} ma #{have.round(2)} mm, ale dielec #{pd[:suffix]} potrebuje #{want.round(2)} mm."
        end

        # Cela beru katalogove varianty 18 aj 19 mm; ich geometria sa prisposobi.
        # Ostatne dielce vyzaduju presnu zhodu s konstrukcnou hrubkou.
        def thickness_ok_for?(role, want, have)
          case role.to_s
          when 'front_door', 'drawer_front'
            (have - 18.0).abs < 0.05 || (have - 19.0).abs < 0.05 || (have - want).abs < 0.05
          else
            (have - want).abs < 0.05
          end
        end

        # Base material dielca podla roly: cela -> front, chrbat -> back, ostatne -> body (korpus).
        # pd[:material] (:front/:korpus) z Construction je sekundarny signal (cela maju :front).
        def base_material_for(role, mat_sym, eff_body, eff_front, eff_back)
          case role.to_s
          when 'front_door', 'drawer_front' then eff_front
          when 'back' then eff_back
          else mat_sym == :front ? eff_front : eff_body
          end
        end

        # V0.2c + D-06 fix: obmedzenie Scale uchopov na osove (X/Y/Z) cez DC "scaletool".
        # Zapisuje sa na instanciu AJ definiciu — SketchUp scale tool cita atribut
        # z DEFINICIE (dogfood pozorovanie: prvy Scale bez masky, druhy s nou).
        # Atribut NEovplyvnuje scale absorpciu (tá cita transformaciu, nie tento kluc).
        # D-40 (Codex audit F3): definicia PRVA (autorita pre Scale tool) a kazdy zapis
        # s vlastnym rescue — zlyhanie jedneho nesmie zhodit druhy.
        def apply_scale_lock(inst)
          return unless inst && inst.valid?
          d = inst.respond_to?(:definition) ? inst.definition : nil
          begin
            d.set_attribute('dynamic_attributes', 'scaletool', SCALE_TOOL_MASK.to_s) if d && d.valid?
          rescue StandardError => e
            Engine.log_error(e, 'apply_scale_lock def') if defined?(Engine)
          end
          inst.set_attribute('dynamic_attributes', 'scaletool', SCALE_TOOL_MASK.to_s)
        rescue StandardError => e
          Engine.log_error(e, 'apply_scale_lock') if defined?(Engine)
          nil
        end

        # D-40: zamok v SAMOSTATNEJ TRANSPARENTNEJ operacii hned za vlozenim (prilepi
        # sa k nemu na undo stacku — 1x undo aj redo vrati oboje naraz). Overene
        # meranim (MCP bisekcia 21.7.2026): zapis dynamic_attributes v tej istej
        # operacii ako vznik definicie/instancie = mrtve selection eventy; zapis
        # v transparentnom follow-upe aj kopie/rebuildy existujucich entit = bezpecne.
        # POZOR (Codex audit B1): transparentnu operaciu NIKDY neabortovat — abort by
        # zrusil aj prilepene vlozenie (SketchUp API). Pri chybe sa commitne aj
        # ciastocny zapis; zamok dopise najblizsi rebuild (apply_scale_lock je
        # sucastou rebuild_in_operation).
        def apply_scale_lock_op(model, inst)
          return unless inst && inst.valid?
          return unless model.start_operation('NOXUN: Zamok scale', true, false, true)

          begin
            apply_scale_lock(inst)
          ensure
            model.commit_operation
          end
        end

        # --- pomocne stavbove ----------------------------------------------

        # Jeden dielec = vlastny komponent s NOXUN dict. Recyklacia definicie podla mena
        # (mena su per-korpus unikatne — obsahuju cid), aby rebuild neprodukoval osirotene definicie.
        # resolved: material, ABS, smer dekoru a katalogova hrubka (viz resolve_part).
        def add_part(model, parent_ents, pd, resolved, cid, tid)
          pd = materialized_part(pd, resolved)
          dname = "NOXUN #{cid} #{pd[:suffix]}"
          pdef = model.definitions[dname] || model.definitions.add(dname)
          pdef.entities.clear!
          sx, sy, sz = pd[:box]
          draw_box(pdef.entities, sx, sy, sz)
          ox, oy, oz = pd[:origin]
          inst = parent_ents.add_instance(pdef, Geom::Transformation.translation(Units.point(ox, oy, oz)))
          # SketchUp material z katalogu (nazov = material_id, farba z color) — vizual, nie vyrobna pravda.
          fallback = pd[:material] == :front ? FALLBACK_RGB_FRONT : FALLBACK_RGB_KORPUS
          inst.material = su_material(model, resolved[:material_id], fallback)
          inst.layer = part_tag(model, pd[:role]) # tag dielca (Korpus/Chrbát/Čelá/Vnútro)
          pid = Ids.part_id(cid, pd[:suffix])
          # BuildPlan kontrakt: vyrobne zaradenie riadi DESKRIPTOR (default sheet/true/1) —
          # builder uz nic nenatvrdzuje; buduce 'counted'/'linear' dielce neprejdu ako doska.
          Store.write(inst, {
            std: Store::STD, kind: 'part', id: pid, part_id: pid, cabinet_id: cid,
            template_id: tid, role: pd[:role], name: pd[:name],
            part_key_schema: PartKeys::SCHEMA, part_key: resolved[:part_key],
            role_key: resolved[:role_key], # kompatibilny alias pre sucasny panel
            manufactured: pd.fetch(:manufactured, true),
            production_class: pd.fetch(:production_class, 'sheet').to_s,
            config: {
              length: pd[:prod][:length].round(2), width: pd[:prod][:width].round(2),
              thickness: pd[:prod][:thickness].round(2), quantity: pd.fetch(:quantity, 1),
              material_id: resolved[:material_id], grain_direction: resolved[:grain_direction] || 'none',
              edges: resolved[:edges]
            }
          })
          inst
        end

        # --- vizual kovania (V0.4: zatial len nohy) --------------------------

        # Nakresli genericky vizual kategorii kovania s geometriou. PROXY kontrakt
        # (standard 6.3 + audit D6): zdroj pravdy supisu je config.hardware[] korpusu;
        # entita je len vizual — production_class 'none', manufactured false, aby ju
        # buduci kusovnik iterujuci entity NIKDY nezapocital (zavesy/vysuvy geometriu
        # nemaju vobec, cisla musia mat jeden domov).
        def render_hardware(model, parent_ents, hardware, cfg, cid)
          legs = Array(hardware).select { |h| h['generic_type'] == 'leg' }
          qty = legs.sum { |h| h['quantity'].to_i }
          return if qty < 1 || cfg[:floor_height].to_f <= 0

          dname = "NOXUN #{cid} LEGS"
          ldef = model.definitions[dname] || model.definitions.add(dname)
          ldef.entities.clear!
          draw_legs(ldef.entities, cfg, qty)
          inst = parent_ents.add_instance(ldef, Geom::Transformation.new)
          inst.layer = hardware_tag(model)
          Store.write(inst, {
            std: Store::STD, kind: 'hardware', id: "#{cid}-HW-LEG", part_id: "#{cid}-HW-LEG",
            cabinet_id: cid, role: 'leg',
            manufactured: false, production_class: 'none',
            config: { generic_type: 'leg', proxy: true, quantity: qty,
                      params: (legs.first ? legs.first['params'] : {}),
                      rule_id: (legs.first ? legs.first['rule_id'] : nil) }
          })
          inst
        rescue StandardError => e
          # Vizual nesmie zhodit rebuild — data (config.hardware) su uz ulozene.
          Engine.log_error(e, 'render_hardware') if defined?(Engine)
          nil
        end

        # Rozmiestnenie valcov pod dnom: 2 rady (predny/zadny) s odsadenim LEG_INSET;
        # plytky korpus / 1 ks -> 1 rad v strede hlbky. Predny rad berie prebytok
        # (ceil), rovnomerne po sirke. Kresli sa najviac LEG_RENDER_MAX valcov.
        def draw_legs(ents, cfg, qty)
          # D-37: nohy patria pod NOSNE dno (konstrukcna hlbka) — zadny rad nesmie
          # trcat pod nalozenym chrbtom (pri hrubke az 50 mm by visel vo vzduchu).
          w = cfg[:width]; d = Construction.carcass_depth(cfg); h = cfg[:floor_height]
          r = LEG_DIAMETER / 2.0
          count = [qty, LEG_RENDER_MAX].min
          # D-13/D-17 (Codex F4): pri prednom sokli predny rad noh posunut ZA dosku
          # sokla (recess + hrubka + polomer + vola) — proxy sa nesmie pretinat.
          front_y = LEG_INSET
          if cfg[:plinth_mode] == 'front'
            front_y = [front_y, cfg[:plinth_recess].to_f + cfg[:thickness].to_f + r + 5.0].max
          end
          two_rows = count > 1 && d > front_y + LEG_INSET + 2 * r
          rows =
            if two_rows
              front = (count / 2.0).ceil
              [[front_y, front], [d - LEG_INSET, count - front]].reject { |_, n| n < 1 }
            else
              [[d / 2.0, count]]
            end
          rows.each do |y, n|
            xs = leg_xs(w, n)
            xs.each { |x| draw_leg_cylinder(ents, x, y, r, h) }
          end
        end

        # X pozicie n noh v rade: 1 ks stred; inak rovnomerne od insetu po sirku-inset.
        def leg_xs(width, n)
          return [width / 2.0] if n == 1
          inset = [LEG_INSET, width / 2.0].min
          span = width - 2 * inset
          (0...n).map { |i| inset + span * i / (n - 1.0) }
        end

        def draw_leg_cylinder(ents, x, y, radius, height)
          edges = ents.add_circle(Units.point(x, y, 0), Geom::Vector3d.new(0, 0, 1),
                                  Units.mm(radius), LEG_SEGMENTS)
          face = ents.add_face(edges)
          return unless face
          face.reverse! if face.normal.z < 0
          face.pushpull(Units.mm(height))
        end

        def hardware_tag(model)
          model.layers[HARDWARE_TAG] || model.layers.add(HARDWARE_TAG)
        end

        # Cela maju hrubku v osi Y. Ak katalog hovori 18/19 mm, upravime box,
        # polohu pred korpusom aj vyrobny udaj naraz.
        def materialized_part(pd, resolved)
          return pd unless %w[front_door drawer_front].include?(pd[:role].to_s)
          th = resolved[:sheet_thickness].to_f
          return pd unless th.positive?

          out = pd.dup
          out[:box] = pd[:box].dup
          out[:origin] = pd[:origin].dup
          out[:prod] = pd[:prod].dup
          out[:box][1] = th
          out[:origin][1] = -th
          out[:prod][:thickness] = th
          out
        end

        # SketchUp vizualny material z katalogu (Materials). Fallback ak katalog nedostupny.
        def su_material(model, material_id, fallback_rgb)
          return Materials.ensure_su_material(model, material_id, fallback_rgb) if defined?(Materials)
          ensure_material(model, "NOXUN_#{material_id}", fallback_rgb)
        end

        def empty_edges
          { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
        end

        # Z override edges vezme len zname kluce (L1/L2/W1/W2); ZACHOVA aj nil (nil = "bez ABS"
        # explicitny override). Kluc chybajuci v override -> dedi z pravidla (base_edges).
        def known_edges(ov)
          out = {}
          return out unless ov.is_a?(Hash)
          %w[L1 L2 W1 W2].each { |k| out[k] = ov[k] if ov.key?(k) }
          out
        end

        # Belt-and-braces guard — degenerovane dielce filtruje uz plan (rovnaky prah
        # BuildPlan::MIN_DIM), sem sa dostat nemaju.
        def positive_box?(box)
          box && box.all? { |v| v.to_f > BuildPlan::MIN_DIM }
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
            template_id: template_id_for(cfg[:type]), role: 'cabinet', part_key_schema: PartKeys::SCHEMA,
            manufactured: false, production_class: 'reference',
            config: cabinet_config(cfg)
          })
          inst.name = "Korpus #{cid}"
          inst
        end

        def cabinet_config(cfg)
          {
            engine_version: Engine::VERSION,
            part_key_schema: PartKeys::SCHEMA,
            plan_schema: cfg[:plan_schema] || BuildPlan::SCHEMA,
            warnings: cfg[:warnings].is_a?(Array) ? cfg[:warnings] : [],
            hardware: cfg[:hardware].is_a?(Array) ? cfg[:hardware] : [],
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
            # vnorene standardne objekty (odvodene)
            sides:   { thickness: cfg[:thickness], construction: 'sides_wrap' },
            bottom:  { mode: cfg[:bottom_mode], thickness: cfg[:thickness] },
            top:     { mode: cfg[:top_mode], thickness: cfg[:thickness],
                       rail_depth: cfg[:rail_depth], orientation: cfg[:rails_orientation],
                       top_offset: cfg[:rails_top_offset] },
            back:    { mode: cfg[:back_mode], thickness: cfg[:back_thickness] },
            support: support_descriptor(cfg),
            # V0.3 materialy — korpusove (nil = dedi z projektoveho defaultu, standard 7.2)
            # + part_overrides (per-dielec material/hrany, kluc = part_key, prezije rebuild).
            material_id: cfg[:material_id],
            front_material_id: cfg[:front_material_id],
            back_material_id: cfg[:back_material_id],
            part_overrides: cfg[:part_overrides].is_a?(Hash) ? cfg[:part_overrides] : {},
            hardware_overrides: cfg[:hardware_overrides].is_a?(Array) ? cfg[:hardware_overrides] : [],
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

        # Typ podopretia urcuje Construction.support_type (1 zdroj pravdy — citaju ho
        # aj pravidla kovania); tu sa len oblieka do config deskriptora.
        def support_descriptor(cfg)
          case Construction.support_type(cfg)
          when 'none'   then { type: 'none', height: 0.0 }
          when 'plinth' then { type: 'plinth', height: cfg[:floor_height], recess: cfg[:plinth_recess] }
          else               { type: 'legs', height: cfg[:floor_height] }
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
            plan_schema: plan[:schema],     # verzia tvaru planu (nezavisla od part_key_schema)
            warnings: plan[:warnings],      # nefatalne upozornenia — panel/vystupy ich zobrazia
            hardware: plan[:hardware],      # kovanie (V0.4+); tvar uz zavazny
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
          fronts_cfg = Fronts.normalize_config(raw(p, :fronts))
          {
            type: type,
            width:  clampf(fetchf(p, :width,  d[:width]),  MIN[:width],  3000.0),
            height: clampf(fetchf(p, :height, d[:height]), MIN[:height], 3000.0),
            depth:  clampf(fetchf(p, :depth,  d[:depth]),  MIN[:depth],  2000.0),
            thickness: clampf(fetchf(p, :thickness, d[:thickness]), 6.0, 50.0),
            floor_height: type == 'upper' ? 0.0 : clampf(fetchf(p, :floor_height, d[:floor_height]), 0.0, 500.0),
            bottom_mode: enum_val(p, :bottom_mode, %w[between_sides under_sides], d[:bottom_mode]),
            top_mode:    enum_val(p, :top_mode,    %w[full two_rails none],       d[:top_mode]),
            back_mode:   enum_val(p, :back_mode,   %w[overlay inset groove none], d[:back_mode]), # D-31: + none
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
            fronts: fronts_cfg,
            # V0.3: korpusove materialy (nil = dedi z projektu) + part_overrides (per-dielec)
            material_id: present(raw(p, :material_id)),
            front_material_id: present(raw(p, :front_material_id)),
            back_material_id: present(raw(p, :back_material_id)),
            part_overrides: norm_overrides(raw(p, :part_overrides)),
            # V0.4 kovanie: rucne zasahy do poctov (pravidlo = default, override vitazi)
            hardware_overrides: prune_none_front_overrides(
              norm_hardware_overrides(raw(p, :hardware_overrides)), fronts_cfg),
            part_key_schema: raw(p, :part_key_schema).to_i,
            name: (p['name'] || p[:name])
          }
        end

        # Ocisti part_overrides na { part_key => { 'material_id'=>..|nil, 'edges'=>{L1..W2} } }.
        # Zahodi prazdne / neplatne zaznamy. Zachova nil hrany (explicitne "bez ABS").
        def norm_overrides(raw_ov)
          return {} unless raw_ov.is_a?(Hash)
          out = {}
          raw_ov.each do |key, ov|
            next unless ov.is_a?(Hash)
            rec = {}
            mat = present(ov['material_id'] || ov[:material_id])
            rec['material_id'] = mat if mat
            edges = ov['edges'] || ov[:edges]
            if edges.is_a?(Hash)
              e = {}
              %w[L1 L2 W1 W2].each do |k|
                next unless edges.key?(k) || edges.key?(k.to_sym)
                v = edges.key?(k) ? edges[k] : edges[k.to_sym]
                v = present(v)
                v = Materials.normalized_abs_id(v) if v && defined?(Materials)
                e[k] = v # nil (bez ABS) alebo podporovane abs_id
              end
              rec['edges'] = e unless e.empty?
            end
            out[key.to_s] = rec unless rec.empty?
          end
          out
        end

        # Ocisti hardware_overrides na pole { owner_part_key(nil|String), generic_type,
        # rule_id, quantity(1..MAX)? | disabled(true)? }. Identita = (owner, type, rule_id);
        # duplicitny zaznam -> POSLEDNY vyhrava (deduplikovane uz tu, config je cisty).
        # Zaznam bez quantity aj bez disabled je bezobsazny -> zahodi sa.
        def norm_hardware_overrides(raw_ov)
          return [] unless raw_ov.is_a?(Array)
          out = {}
          raw_ov.each do |ov|
            next unless ov.is_a?(Hash)
            owner = present(ov['owner_part_key'] || ov[:owner_part_key])
            next if owner && !PartKeys.valid?(owner)
            gt = (ov['generic_type'] || ov[:generic_type]).to_s.strip
            next unless BuildPlan::GENERIC_TYPES.include?(gt)
            rid = (ov['rule_id'] || ov[:rule_id]).to_s.strip
            next if rid.empty?

            rec = { 'owner_part_key' => owner, 'generic_type' => gt, 'rule_id' => rid }
            if truthy_flag(ov['disabled'] || ov[:disabled])
              rec['disabled'] = true
            else
              q = (ov['quantity'] || ov[:quantity])
              qi = q.to_s.strip.empty? ? nil : q.to_i
              next if qi.nil? || qi < 1
              rec['quantity'] = [qi, BuildPlan::MAX_HW_QUANTITY].min
            end
            out[[owner, gt, rid]] = rec
          end
          out.values
        end

        # D-18 (Codex audit F1): celo typu 'none' nema dielce — rucne zasahy kovania
        # viazane na jeho front id su mrtve zaznamy (UI by ukazovalo „vypnute" polozky
        # bez existujuceho dielca a pri neskorsom navrate na dvierka by zasah necakane
        # ozil). Pri normalizacii sa odstrania; zasahy ostatnych riadkov a korpusove
        # (owner nil) ostavaju nedotknute. Prune sa persistne prejavi cez merge_final.
        def prune_none_front_overrides(overrides, fronts_cfg)
          none_ids = (fronts_cfg['items'] || [])
                     .select { |it| it['type'] == 'none' }
                     .map { |it| it['id'].to_s }
          return overrides if none_ids.empty?
          overrides.reject do |ov|
            m = ov['owner_part_key'].to_s.match(%r{\Afront:([^/]+)/})
            m && none_ids.include?(m[1])
          end
        end

        def truthy_flag(v)
          v == true || %w[true 1 yes].include?(v.to_s.downcase)
        end

        # zone_tree z params; ak chyba, ale je legacy 'shelves' -> koren so shelves; inak prazdny koren.
        def norm_zone_tree(p)
          zt = raw(p, :zone_tree)
          return ZoneTree.sanitize(zt) if zt.is_a?(Hash)
          sh = raw(p, :shelves)
          ZoneTree.default_tree(sh.nil? || sh.to_s.strip.empty? ? 0 : sh.to_i)
        end

        # Config (stored, string kluce) -> params pre normalize. Doplna spatnu kompatibilitu:
        # stare configy (bez zone_tree, fronts ako string, shelves top-level).
        def config_to_params(cfg)
          params = {
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
            'fronts' => cfg.key?('fronts') ? fronts_from_config(cfg) : nil,
            # V0.3 materialy. Marker V0.3 configu = pritomnost 'part_overrides'. Legacy korpusy (V0.2)
            # mali material_id/back_material_id ulozene NATVRDO (K009/HDF) — tie NEberieme ako korpusovy
            # override (nechame nil = dedi z projektu), aby projektovy default fungoval aj na starych.
            'material_id'       => v03?(cfg) ? cfg['material_id'] : nil,
            'front_material_id' => v03?(cfg) ? cfg['front_material_id'] : nil,
            'back_material_id'  => v03?(cfg) ? cfg['back_material_id'] : nil,
            'part_key_schema'   => cfg['part_key_schema'].to_i,
            'part_overrides'    => cfg['part_overrides'].is_a?(Hash) ? cfg['part_overrides'] : {},
            # V0.4 kovanie (pole neexistovalo pred V0.4 -> stare configy dostanu []).
            # POZN. buduci part_key schema bump: owner_part_key tychto zaznamov musi
            # prejst TOU ISTOU legacy->current mapou ako part_overrides (audit D5).
            'hardware_overrides' => cfg['hardware_overrides'].is_a?(Array) ? cfg['hardware_overrides'] : [],
            'name' => cfg['name']
          }
          migrate_legacy_part_keys(params, cfg)
        end

        # Migracia sa robi podla POVODNEJ ulozenej konfiguracie este pred pouzivatelskou
        # zmenou. Tak sa spravne prenesie aj override cela, ktore sa nasledne presunie
        # alebo zostane po zmazani susedneho riadku.
        def migrate_legacy_part_keys(params, stored_cfg)
          return params if stored_cfg['part_key_schema'].to_i >= PartKeys::SCHEMA

          normalized = normalize(params)
          plan = Construction.build_plan(normalized)
          params['part_overrides'] = PartKeys.migrate_overrides(params['part_overrides'], plan[:parts])
          params['part_key_schema'] = PartKeys::SCHEMA
          params
        rescue StandardError => e
          Engine.log_error(e, 'migrate_legacy_part_keys') if defined?(Engine)
          params
        end

        # Marker V0.3 materialov. V0.2 korpusy part_overrides nemali.
        def v03?(cfg)
          cfg.key?('part_overrides')
        end

        # Pred V0.3.1 panel dovolil pevne cela nizsie ako Fronts::MIN_AUTO.
        # part_overrides nie je dostatocna hranica migracie, pretoze ho uz mala V0.3.0.
        def fronts_from_config(cfg)
          raw_fronts = cfg['fronts']
          return raw_fronts if version_at_least?(cfg['engine_version'], FRONT_VALIDATION_VERSION)
          Fronts.migrate_legacy_config(raw_fronts)
        end

        def version_at_least?(value, minimum)
          actual = value.to_s.split('.').first(3).map(&:to_i)
          target = minimum.to_s.split('.').first(3).map(&:to_i)
          actual.fill(0, actual.length...3)
          target.fill(0, target.length...3)
          (actual <=> target) >= 0
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

        # V0.4.7b: pravy okraj pocita Placement (top-level cabinet + board, nikdy
        # ghost zony) — novy korpus sa vlozi aj vedla dosky, nie cez nu.
        def next_x(model)
          Placement.next_x(model, gap: GAP_BETWEEN_CABS)
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

        # String hodnota alebo nil (prazdny/whitespace string -> nil). Pouzite pri material_id
        # dedeni (nil = "dedi z nadradenej urovne", standard 7.2).
        def present(v)
          return nil if v.nil?
          s = v.to_s.strip
          s.empty? ? nil : s
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
