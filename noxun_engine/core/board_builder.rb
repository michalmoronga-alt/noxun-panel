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
            return defined?(AbsRules) ? AbsRules.resolve_edges(ROLE, decor) : empty_edges
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
