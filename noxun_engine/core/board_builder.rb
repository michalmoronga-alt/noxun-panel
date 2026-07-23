# frozen_string_literal: true
# Noxun Engine — samostatna vyrobna doska (kind 'board', V0.4.7). CISTA cast:
# normalizacia + validacia + vyrobny deskriptor + config tvar. Ziadne SketchUp API
# v tomto subore vo faze V0.4.7a — geometria (build/rebuild/dedup) pride v V0.4.7b.
#
# Doska = JEDEN vyrobny dielec bez korpusu (krycia doska, blenda, vypln...).
# Identita: id BRD-001 (Ids.next_board_id) + konstantny part_key 'board/main' —
# vazba na dosku je dvojica id + part_key (owner-scope, standard 2.3). Kopia dosky
# dostane nove id (dedup v V0.4.7b, vzor korpusov).
#
# Config na instancii dosky (JSON string v NOXUN dict) je AUTORITATIVNY VYROBNY
# ZAZNAM (standard 8.2/11.1) a je SUPERSETOM configu dielca korpusu: rovnake
# vyrobne polia (length/width/thickness/quantity/material_id/grain_direction/edges)
# + navyse engine_version/name/role (round-trip editacie; vystupy citaju ploche
# NOXUN kluce name/role, nie config). Kusovnik V0.5 zbiera entity manufactured:true
# jednotne (kind part aj board) a agreguje VYHRADNE podla vyrobnych poli
# (material_id + rozmery + edges + grain), quantity scituje.
#
# Materialova politika dosky (Michal 18.7.2026): material je SNAPSHOT — vzdy
# konkretny katalogovy zaznam (predvyplna sa z projektoveho defaultu pri vlozeni,
# ziadne zive dedenie) a hrubka dosky sa RIADI materialom (nie je volny rozmer).
# Preto validate_config! vyzaduje existujuci katalogovy material (ziadny legacy
# prenos "neznamy material smie prejst" z korpusov na novy typ).
module Noxun
  module Engine
    module BoardBuilder
      PART_KEY = 'board/main'
      SUFFIX   = 'BOARD'
      ROLE     = 'free_panel'

      # Slovnik roli dosky vo V1. Buduce roly (cover_side/cover_top/filler/worktop/
      # plinth_board) pribudnu az s implementaciou ich spravania — neznama rola je
      # CHYBA (fail-fast), nie ticha degradacia na free_panel (novsi config nesmie
      # stratit vyznam v starsom plugine).
      ROLES = [ROLE].freeze

      DEFAULTS = { length: 800.0, width: 600.0, thickness: 18.0, quantity: 1 }.freeze
      LIMITS   = { length: [10.0, 5000.0], width: [10.0, 3000.0], thickness: [1.0, 60.0] }.freeze
      MAX_QUANTITY = 999
      GRAINS = %w[length width none].freeze
      EDGE_KEYS = %w[L1 L2 W1 W2].freeze

      class << self
        # --- normalizacia ---------------------------------------------------
        # params (string alebo symbol kluce; typicky UI payload alebo ulozeny config)
        # -> cfg so symbolovymi klucmi, mm Float. NEvaliduje material (viz
        # validate_config!) — builder moze default doplnit medzi normalize a build.
        def normalize(params)
          p = params || {}
          role = norm_role(p)
          mat = present(raw(p, :material_id))
          sheet = catalog_sheet(mat)
          {
            role: role,
            name: norm_name(p),
            length: clampf(fetchf(p, :length, DEFAULTS[:length]), *LIMITS[:length]),
            width:  clampf(fetchf(p, :width,  DEFAULTS[:width]),  *LIMITS[:width]),
            # Hrubka sa riadi katalogovym materialom; bez materialu (docasny stav
            # pred doplnenim defaultu builderom) plati clampnuty vstup.
            thickness: sheet ? sheet['thickness'].to_f : clampf(fetchf(p, :thickness, DEFAULTS[:thickness]), *LIMITS[:thickness]),
            material_id: mat,
            grain_direction: norm_grain(p, sheet),
            edges: norm_edges(p, sheet),
            quantity: norm_quantity(p)
          }
        end

        # Obsahova validacia cfg (po normalize). Prisna materialova politika dosky:
        # material musi byt konkretny A existovat v katalogu (hrubku uz dosadil
        # normalize, takze nesulad hrubky nemoze nastat).
        def validate_config!(cfg)
          raise 'Doska nemá materiál (material_id).' if cfg[:material_id].to_s.strip.empty?
          if defined?(Materials) && catalog_sheet(cfg[:material_id]).nil?
            raise "Materiál #{cfg[:material_id]} nie je v katalógu — doska vyžaduje katalógový materiál."
          end
          raise "Neznáma rola dosky '#{cfg[:role]}'." unless ROLES.include?(cfg[:role].to_s)
          cfg
        end

        # --- vyrobny deskriptor ---------------------------------------------
        # cfg -> deskriptor dielca v TVARE BuildPlan kontraktu, zvalidovany TYM ISTYM
        # validatorom ako dielce korpusu. seen mapa je IZOLOVANA per doska — part_key
        # 'board/main' je konstantny, unikatnost drzi id dosky, nie kluc (preto sa
        # dosky NIKDY nevaliduju v spolocnom plane so zdielanym seen).
        # material: :concrete = material je uz konkretny v configu (ziadne dedenie,
        # deskriptor NEJDE cez CabinetBuilder.resolve_part).
        def descriptor(cfg)
          validate_config!(cfg)
          l = cfg[:length].to_f
          w = cfg[:width].to_f
          t = cfg[:thickness].to_f
          pd = {
            part_key: PART_KEY, suffix: SUFFIX, role: cfg[:role].to_s,
            name: cfg[:name].to_s, material: :concrete,
            box: [l, w, t], origin: [0.0, 0.0, 0.0],
            prod: { length: l, width: w, thickness: t },
            production_class: 'sheet', manufactured: true,
            quantity: cfg[:quantity].to_i
          }
          BuildPlan.validate_part!(pd, {})
          pd
        end

        # --- config na Store (JSON round-trip tvar) --------------------------
        def board_config(cfg)
          {
            engine_version: Engine::VERSION,
            name: cfg[:name].to_s,
            role: cfg[:role].to_s,
            quantity: cfg[:quantity].to_i,
            length: cfg[:length].to_f.round(2),
            width: cfg[:width].to_f.round(2),
            thickness: cfg[:thickness].to_f.round(2),
            material_id: cfg[:material_id],
            grain_direction: cfg[:grain_direction],
            edges: cfg[:edges]
          }
        end

        # Ulozeny config (string kluce) -> params pre normalize. Tenka vrstva —
        # doska V1 nema legacy migracie; buduce migracie sa zavesia na
        # config['engine_version'] (vzor CabinetBuilder.version_at_least?).
        def config_to_params(stored)
          stored.is_a?(Hash) ? stored.dup : {}
        end

        # ====================================================================
        # SketchUp cast (V0.4.7b) — build/rebuild/dedup. Vzor CabinetBuilder:
        # guarded operacie (observer ignoruje vlastne zmeny), 1 akcia = 1 Undo,
        # recyklacia definicie, root kontext. PORADIE v build/rebuild je zamerne:
        # normalize + validacia CISTO PRED ensure_root! — chybny vstup nesmie mat
        # ziadny vedlajsi ucinok (ani zatvorenie editovaneho komponentu).
        # ====================================================================

        FALLBACK_RGB = [216, 196, 160].freeze
        BOARD_TAG = 'Noxun/Dosky'
        # DC scaletool maska = uchopy na SKRYTIE (D-06): 120 skryje roviny+rohy,
        # ostavaju ciste osi X/Y/Z. Rovnaka hodnota ako CabinetBuilder.
        SCALE_TOOL_MASK = 120

        # Vlozi novu dosku nalezato na Z=0 vedla najpravejsieho NOXUN objektu.
        # Bez material_id v params sa doplni projektovy default (snapshot!).
        # Vrati instanciu.
        def build(model, params)
          p = stringify(params)
          if present(p['material_id']).nil? && defined?(Materials)
            p['material_id'] = Materials.project_defaults(model)['default_material_id']
          end
          cfg = normalize(p)
          validate_config!(cfg)
          ensure_root!(model)
          bid = Ids.next_board_id(model)
          x = Placement.next_x(model)
          inst = nil
          guarded do
            model.start_operation('NOXUN: Vloz dosku', true)
            begin
              bdef = model.definitions.add(definition_name(bid))
              bdef.entities.clear!
              draw_board(bdef.entities, cfg)
              inst = model.entities.add_instance(bdef, Geom::Transformation.translation(Units.point(x, 0, 0)))
              write_board_attrs(model, inst, bid, cfg)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
            # D-40: scale zamok az PO commite vlozenia, v transparentnom follow-upe
            # (viz apply_scale_lock_op; rovnaky vzor ako CabinetBuilder).
            apply_scale_lock_op(model, inst)
          end
          # V0.4.7d: per-instancny observer — scale absorpcia dosky (vzor korpus).
          ScaleWatch.attach_one(inst) if inst && defined?(ScaleWatch)
          inst
        end

        # Prestavia existujucu dosku. params sa MERGUJU do ulozeneho configu
        # (chybajuce polia drzi snapshot). transform: volitelna cista transformacia
        # (scale absorpcia V0.4.7d). transparent: pripoji operaciu k predchadzajucej.
        def rebuild(model, inst, params, transform: nil, op_name: 'NOXUN: Uprav dosku', transparent: false)
          bid = board_id!(inst)
          merged = config_to_params(Store.config(inst) || {}).merge(stringify(params))
          cfg = normalize(merged)
          validate_config!(cfg)
          ensure_root!(model)
          guarded do
            model.start_operation(op_name, true, false, transparent)
            begin
              rebuild_in_operation(model, inst, bid, cfg, transform: transform)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
          end
          inst
        end

        # Vnutro rebuildu; volajuci drzi operaciu aj guard.
        def rebuild_in_operation(model, inst, bid, cfg, transform: nil)
          inst.make_unique if inst.definition.instances.size > 1
          bdef = inst.definition
          bdef.name = definition_name(bid) unless bdef.name == definition_name(bid)
          bdef.entities.clear!
          draw_board(bdef.entities, cfg)
          inst.transformation = transform if transform
          write_board_attrs(model, inst, bid, cfg)
          apply_scale_lock(inst)
          inst
        end

        # Kopia dosky (zdielane id) -> nova identita BEZ prekreslenia: make_unique
        # + nove id + premenovanie definicie. Geometria a config kopie sa NEmenia
        # (ziaden normalize round-trip — zmena katalogu nesmie pri kopirovani
        # menit geometriu a chybajuci material nesmie dedup zablokovat).
        # fresh_ids: entityID mnozina PRAVE pridanych entit (observer tick). Ak je
        # dana, spracuju sa IBA tieto duplikaty (transparentne k paste kroku); stare
        # duplicity necha na follow-up tick observera (samostatne undo kroky) —
        # rovnaky kontrakt ako CabinetBuilder.dedup_copies (Codex GH review P2).
        def dedup_copies(model, transparent: false, fresh_ids: nil)
          return [] unless model
          dups = Ids.duplicate_boards(model)
          dups = dups.select { |i| i && i.valid? && fresh_ids.include?(i.entityID) } if fresh_ids
          return [] if dups.empty?
          done = []
          dups.each do |inst|
            next unless inst && inst.valid?
            new_id = Ids.next_board_id(model)
            trans = fresh_ids ? true : transparent
            guarded do
              model.start_operation('NOXUN: Kopia dosky — nove ID', true, false, trans)
              begin
                inst.make_unique if inst.definition.instances.size > 1
                inst.definition.name = definition_name(new_id)
                Store.write(inst, { std: Store::STD, kind: 'board', id: new_id, part_id: new_id })
                inst.name = "Doska #{new_id}"
                model.commit_operation
              rescue StandardError => e
                abort_safely(model)
                raise e
              end
            end
            done << inst
            Engine.log("dedup: kopia dosky dostala nove ID #{new_id}") if defined?(Engine)
          end
          done
        rescue StandardError => e
          Engine.log_error(e, 'BoardBuilder.dedup_copies') if defined?(Engine)
          []
        end

        # --- SketchUp pomocne -----------------------------------------------

        def definition_name(bid)
          "NOXUN Doska #{bid}"
        end

        # Guard identity pre rebuild: kind board + platne BRD id (poskodena doska
        # bez identity sa nesmie prestavat).
        def board_id!(inst)
          raise 'Vybrana instancia nie je NOXUN doska.' unless Store.kind(inst) == 'board'
          bid = Store.get(inst, 'id').to_s
          raise "Doska ma neplatnu identitu '#{bid}'." unless bid.match?(/\ABRD-\d+\z/)
          bid
        end

        # Zavrie edit kontexty a OVERI, ze sme naozaj v roote (close_active moze
        # ticho zlyhat — nesmie sa zacat operacia nad zlym ramcom).
        def ensure_root!(model)
          CabinetBuilder.ensure_root_context(model) if defined?(CabinetBuilder)
          ap = model.active_path
          raise 'Zatvor editaciu komponentu a skus znova.' if ap && !ap.empty?
        end

        # Box dosky: length = X, width = Y, thickness = Z (lokalne osi = vyrobna
        # pravda, standard 3.3). Lokalny helper — ziadna vazba na CabinetBuilder.
        def draw_board(ents, cfg)
          l = cfg[:length]; w = cfg[:width]
          pts = [
            Units.point(0, 0, 0), Units.point(l, 0, 0),
            Units.point(l, w, 0), Units.point(0, w, 0)
          ]
          f = ents.add_face(pts)
          f.reverse! if f.normal.z < 0
          f.pushpull(Units.mm(cfg[:thickness]))
          f
        end

        def write_board_attrs(model, inst, bid, cfg)
          Store.write(inst, {
            std: Store::STD, kind: 'board', id: bid, part_id: bid,
            part_key: PART_KEY, part_key_schema: PartKeys::SCHEMA,
            role: cfg[:role], name: cfg[:name],
            manufactured: true, production_class: 'sheet',
            config: board_config(cfg)
          })
          inst.name = "Doska #{bid}"
          inst.material = Materials.ensure_su_material(model, cfg[:material_id], FALLBACK_RGB) if defined?(Materials)
          inst.layer = board_tag(model)
          inst
        end

        def board_tag(model)
          model.layers[BOARD_TAG] || model.layers.add(BOARD_TAG)
        end

        # Zapis na instanciu AJ definiciu — scale tool cita atribut z definicie (D-06).
        # D-40 (Codex audit F3): definicia PRVA (autorita) a kazdy zapis s vlastnym
        # rescue — zlyhanie jedneho nesmie zhodit druhy.
        def apply_scale_lock(inst)
          return unless inst && inst.valid?
          d = inst.respond_to?(:definition) ? inst.definition : nil
          begin
            d.set_attribute('dynamic_attributes', 'scaletool', SCALE_TOOL_MASK.to_s) if d && d.valid?
          rescue StandardError => e
            Engine.log_error(e, 'BoardBuilder.apply_scale_lock def') if defined?(Engine)
          end
          inst.set_attribute('dynamic_attributes', 'scaletool', SCALE_TOOL_MASK.to_s)
        rescue StandardError => e
          Engine.log_error(e, 'BoardBuilder.apply_scale_lock') if defined?(Engine)
          nil
        end

        # D-40: zamok v SAMOSTATNEJ TRANSPARENTNEJ operacii hned za vlozenim — DC
        # atribut nesmie vzniknut v operacii, ktora entity vytvara (DC observer by
        # pri commite vypol selection eventy celeho modelu). Transparent NIKDY
        # neabortovat (Codex audit B1) — pri chybe commit aj ciastocneho zapisu;
        # zamok dopise najblizsi rebuild. Vzor zhodny s CabinetBuilder.
        def apply_scale_lock_op(model, inst)
          return unless inst && inst.valid?
          return unless model.start_operation('NOXUN: Zamok scale', true, false, true)

          begin
            apply_scale_lock(inst)
          ensure
            model.commit_operation
          end
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

        def stringify(h)
          return {} unless h.is_a?(Hash)
          h.each_with_object({}) { |(k, v), o| o[k.to_s] = v }
        end

        # --- pomocne --------------------------------------------------------

        def norm_role(p)
          v = raw(p, :role)
          return ROLE if v.nil? || v.to_s.strip.empty?
          role = v.to_s
          raise "Neznáma rola dosky '#{role}'." unless ROLES.include?(role)
          role
        end

        def norm_name(p)
          v = raw(p, :name)
          s = v.to_s.strip
          return s unless s.empty?
          l = fetchf(p, :length, DEFAULTS[:length]).round
          w = fetchf(p, :width, DEFAULTS[:width]).round
          "Doska #{l}×#{w}"
        end

        def norm_grain(p, sheet)
          v = raw(p, :grain_direction).to_s
          return v if GRAINS.include?(v)
          g = sheet && sheet['grain'].to_s
          GRAINS.include?(g) ? g : 'none'
        end

        # Hrany: ak edges vo vstupe CHYBA -> plny pravidlovy default roly
        # (AbsRules.resolve_edges podla dekoru materialu). Ak je edges Hash ->
        # pouzivatel prevzal kontrolu: kluc PRITOMNY (string aj symbol; aj s nil =
        # explicitne "bez ABS") sa zachova, kluc CHYBAJUCI = nil (bez ABS) — NIE
        # pravidlovy default (key?-preserve, ziadne `||`, standard 7.5).
        # Neplatne abs_id sa zahodi na nil (Materials.normalized_abs_id — rovnake
        # spravanie ako korpusove part_overrides). Vzdy vracia CERSTVU kompletnu mapu.
        def norm_edges(p, sheet)
          input = raw(p, :edges)
          unless input.is_a?(Hash)
            decor = sheet && sheet['decor']
            # D-41: hrubka dosky je VZDY z materialu — picker sirky dostava tu istu.
            return defined?(AbsRules) ? AbsRules.resolve_edges(ROLE, decor, sheet && sheet['thickness']) : empty_edges
          end
          out = {}
          EDGE_KEYS.each do |k|
            sym = k.to_sym
            if input.key?(k) || input.key?(sym)
              v = present(input.key?(k) ? input[k] : input[sym])
              v = Materials.normalized_abs_id(v) if v && defined?(Materials)
              out[k] = v
            else
              out[k] = nil
            end
          end
          out
        end

        def norm_quantity(p)
          v = raw(p, :quantity)
          n = v.to_s.strip.empty? ? DEFAULTS[:quantity] : v.to_i
          n = 1 if n < 1
          [n, MAX_QUANTITY].min
        end

        def empty_edges
          { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
        end

        def catalog_sheet(material_id)
          return nil unless material_id && defined?(Materials)
          Materials.sheet(material_id)
        end

        def raw(p, key)
          v = p[key.to_s]
          v.nil? ? p[key] : v
        end

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
      end
    end
  end
end
