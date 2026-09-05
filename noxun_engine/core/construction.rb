# frozen_string_literal: true
# Noxun Engine — construction planner. cfg (mm Float) -> BuildPlan (zavazny kontrakt).
# CISTO vypoctovy modul: ziadna SketchUp geometria, ziadne .mm. Testovatelny bez modelu.
# Kazdy dielec = { suffix, part_key, role, name, material:, box:[sx,sy,sz], origin:[x,y,z],
#                  prod:{length,width,thickness} } — plny kontrakt viz core/build_plan.rb.
#
# V0.2b: vnutro riesi ZoneTree (strom zon + priecky + police per-zona),
#        cela riesi Fronts (fixed+auto s lockmi). Hrubka chrbta je konfigurovatelna.
#
# Konstrukcne varianty (standard sekcia 4.4 + domenova korekcia Michal 2026-07):
#   dno:    under_sides (default dolna) / between_sides (default horna)
#   vrch:   full / two_rails / none
#   chrbat: overlay / inset / groove   (hrubka = cfg[:back_thickness], napr. 3 HDF / 18 pevny)
#   sokel:  none (nohy) / front (predny zapusteny panel)
module Noxun
  module Engine
    module Construction
      BACK_THICKNESS_DEFAULT = 3.0    # default hrubka chrbta (HDF), ak cfg neuvedie
      GROOVE_OFFSET          = 10.0   # odsadenie chrbta v drazke od zadnej hrany

      # D-80: rezerva svetleho vnutra POD vystuhami (mm). JEDEN zdroj pravdy pre
      # clamp vysky upright vystuhy AJ pre clamp odsadenia (rails_top_offset):
      # spodna hrana vystuh nikdy neklesne pod z_lo + tuto rezervu.
      # Preco 20 a nie 10 (povodny limit vysky upright vystuhy): validate! odmieta
      # avail_h <= 10, takze pri rezerve 10 by extremne zadanie skoncilo TVRDYM
      # odmietnutim rebuildu. S 20 sa extrem OREZE a nahlasi warningom (a 20 mm je
      # zaroven ZoneTree::MIN_FIELD — najmensie zmysluplne svetle pole).
      MIN_INTERIOR_H = 20.0

      module_function

      # Vystup MUSI prejst BuildPlan.validate! — chybny plan nikdy neopusti planovac.
      # hardware_rules: normalizovane pole pravidiel kovania. Builder posiela PROJEKTOVY
      # snapshot (HardwareRules.ensure_project_rules!); nil = globalna kniznica (headless
      # testy a pomocne volania bez modelu — migracia identity, panel resolvery).
      # KOV-C2b: hrubka dielca zasuvky, ked ju volajuci NEDODA. Je to hodnota
      # UNI 16 fallbacku 4. materialoveho kanala (`Materials::UNI_ZASUVKA_16`),
      # teda to iste, co dostane cerstvy projekt bez vlastnej predvolby.
      # Autoritativne hrubky posiela BUILDER (`part_thicknesses:`) — vyriesene
      # PRED planom z kanala `:drawer` + `part_overrides`. Pomocne volania
      # `build_plan` (migracia identity, panelove resolvery) hrubky nepotrebuju:
      # part_key ani suffix od nich nezavisia.
      DRAWER_DEFAULT_THICKNESS = 16.0

      # Hlavny vstup: cfg (symbolove kluce, mm Float) + cabinet_id (pre ID zon) -> plan.
      # part_thicknesses: { part_key => mm } pre roly zasuviek (viz vyssie).
      def build_plan(cfg, cabinet_id = 'CAB-000', hardware_rules: nil, part_thicknesses: nil)
        w = cfg[:width]; h = cfg[:height]; t = cfg[:thickness]

        interior = interior_dims(cfg)
        validate!(cfg, interior)
        warnings = []

        parts = []
        parts.concat(side_parts(cfg))
        parts << bottom_part(cfg)
        parts.concat(top_parts(cfg, warnings))
        bk = back_part(cfg, interior)
        parts << bk if bk
        parts.concat(plinth_parts(cfg))

        # Vnutro = strom zon nad vnutornym boxom (3D). Priecky + police su dielce korpusu.
        zbox = { x0: t, x1: w - t, y0: 0.0, y1: interior[:back_front_y],
                 z0: interior[:z_lo], z1: interior[:z_hi] }
        zres = compute_zone_tree!(cfg, interior, zbox, t, cabinet_id)
        parts.concat(zres[:dividers])
        parts.concat(zres[:shelves])
        warnings.concat(zres[:warnings] || [])

        # Cela pred korpusom (fixed + auto s lockmi).
        fr = Fronts.layout(cfg[:fronts], w, h, cfg[:floor_height], t)
        parts.concat(fr[:parts])
        # D-90: nefatalne upozornenia matematiky ciel (nizky panel pod profilom).
        warnings.concat(fr[:warnings] || [])

        # Kontrakt: parts = realne postavitelne dielce. Degenerovane (rozmer <= MIN_DIM)
        # sa vyradia UZ TU s warningom — kusovnik/VEPO nikdy neuvidia dielec,
        # ktory builder nepostavi (predtym ich ticho preskakoval az positive_box?).
        # Prah MUSI byt zhodny s builderom (BuildPlan::MIN_DIM) — inak vznikne pasmo,
        # kde plan dielec deklaruje a builder ho preskoci.
        parts, degenerate = parts.partition { |pd| pd[:box].all? { |v| v.to_f > BuildPlan::MIN_DIM } }
        degenerate.each do |pd|
          warnings << BuildPlan.warning('part_skipped_degenerate',
                                        "Dielec #{pd[:name]} (#{pd[:suffix]}) ma nekladny rozmer — preskoceny.",
                                        part_key: pd[:part_key].to_s,
                                        data: { 'box' => pd[:box].map(&:to_f) })
        end

        # KOV-C2b: AKTIVACIA RECEPTOV ZASUVIEK. Bezi PRED pravidlami kovania,
        # lebo z nej vychadza aj mnozina ciel, na ktorych sa legacy `slide`
        # pravidlo POTLACI (R2 exkluzivita) — inak by zasuvka mala dve polozky
        # vysuvu. Kontext potrebuje UZ POSTAVENE zony, hranice a dielce, preto az
        # tu; a dielce zasuviek sa pripajaju AZ ZA touto partition, lebo ich
        # atomicitu strazi recept sam (jediny neplatny rozmer = `drawer_no_fit`
        # pre CELU zasuvku, nikdy per-dielec `part_skipped_degenerate`).
        drawer = drawer_pass(cfg, {
                               zone_bounds: zres[:raw_bounds] || {},
                               front_bounds: fr[:bounds] || {},
                               zones: zres[:zones], parts: parts,
                               front_items: fr[:items]
                             }, part_thicknesses)
        warnings.concat(drawer[:warnings])

        # Kovanie z pravidiel — az PO vyradeni degenerovanych dielcov (na dielec,
        # ktory v modeli nestoji, nesmie vzniknut polozka). Kontext string-keyed.
        hw_ctx = {
          'width' => w, 'height' => h, 'depth' => cfg[:depth],
          'floor_height' => cfg[:floor_height],
          'available_width' => (w - 2 * t),
          'available_height' => interior[:avail_h],
          'available_depth' => interior[:back_front_y],
          'support' => support_type(cfg),
          # D1: predikat pravidiel podla typu korpusu (upper/lower) — support
          # 'none' nerozlisuje hornu od spodnej bez noh (GH #125 P2).
          'cabinet_type' => cfg[:type].to_s
        }
        hw = HardwareRules.evaluate(cfg, parts, hw_ctx, rules: hardware_rules || HardwareRules.load,
                                                        suppress_slide_owners: drawer[:suppress])
        warnings.concat(hw[:warnings])

        plan = {
          schema: BuildPlan::SCHEMA,
          parts: parts + drawer[:parts],
          hardware: hw[:items] + drawer[:hardware],
          warnings: warnings,
          zones: zres[:zones],
          zone_tree: ZoneTree.sanitize(cfg[:zone_tree]),
          front_items: fr[:items],
          available: {
            width:  (w - 2 * t),
            height: interior[:avail_h],
            depth:  interior[:back_front_y]
          },
          wings: fr[:wings],
          interior: interior,
          # KOV-C1: ADITIVNE surove (NEZAOKRUHLENE) hranice pre `context_for`.
          # Do configu sa NEUKLADAJU — `CabinetBuilder.merge_final` kopiruje len
          # menovity zoznam klucov, takze model ani vystupy sa nemenia.
          zone_bounds: zres[:raw_bounds] || {},
          front_bounds: fr[:bounds] || {},
          # KOV-C2b: fail-closed dovody zasuviek (ULOZENY NOSIC — po fail-closed
          # stavbe nezostane polozka, z ktorej by sa dovod dal obnovit) a zapisy,
          # ktore ma builder vykonat v TEJ ISTEJ operacii ako geometriu.
          drawer_conflicts: drawer[:conflicts],
          drawer_writes: drawer[:writes],
          drawer_override_writes: drawer[:override_writes]
        }
        BuildPlan.validate!(plan)
      end

      # --- KOV-C2b: aktivacia receptov zasuviek --------------------------------
      #
      # CISTA funkcia (ziadne IO okrem citania datoveho packu receptov). Pre kazde
      # celo klasifikovane ako zasuvka SO SYSTEMOM vrati dielce, JEDNU polozku
      # vysuvu a pripadne konflikty. Legacy cela (`[:legacy, nil]`) sa jej vobec
      # netykaju — zakazka bez klasifikacie je CONTENT-IDENTICKA.
      #
      # ctx_plan = { zone_bounds:, front_bounds:, zones:, parts:, front_items: }
      # -> { parts:, hardware:, conflicts:, warnings:, suppress:, writes:,
      #      override_writes: }
      def drawer_pass(cfg, ctx_plan, part_thicknesses)
        out = { parts: [], hardware: [], conflicts: [], warnings: [],
                suppress: {}, writes: [], override_writes: [] }
        return out unless defined?(Recipes)

        Array(ctx_plan[:front_items]).each do |item|
          next unless item.is_a?(Hash)

          kind, a, b = Recipes.recipe_key_for(item)
          next if kind == :legacy

          front_id = item['id'].to_s
          # Klasifikovane celo NIKDY nedostane legacy `slide` pravidlo — ani ked
          # skonci konfliktom. Inak by fail-closed zasuvka ticho objednala vysuv
          # z pravidla, ku ktoremu neexistuju dielce.
          out[:suppress][PartKeys.front(front_id, 'panel')] = true
          if kind == :conflict
            out[:conflicts] << drawer_conflict(front_id, a, b)
            next
          end

          resolve_drawer_front(cfg, ctx_plan, item, a, part_thicknesses, out)
        end
        out
      end

      def drawer_conflict(front_id, code, message)
        { 'front_id' => front_id.to_s, 'code' => code.to_s, 'message' => message.to_s,
          'part_key' => PartKeys.front(front_id, 'panel') }
      end

      # Jedno klasifikovane celo: aktivny recept -> kontext -> resolve -> emisia.
      def resolve_drawer_front(cfg, ctx_plan, item, key, part_thicknesses, out)
        front_id = item['id'].to_s
        drawer_cfg = item['drawer'].is_a?(Hash) ? item['drawer'] : {}
        ref_key = "#{key[:system]}|#{key[:opening]}"

        state, ref = Recipes.active_ref(drawer_cfg['recipe_refs'], key[:system], key[:opening])
        if state == :unknown
          return out[:conflicts] << drawer_conflict(
            front_id, 'drawer_recipe_unknown',
            "Zásuvka používa recept „#{ref}\", ktorý tento plugin nepozná — aktualizuj plugin."
          )
        end
        if state == :missing
          ref = pick_recipe_ref(drawer_cfg['recipe_refs'], key)
          if ref.nil?
            return out[:conflicts] << drawer_conflict(
              front_id, 'drawer_recipe_unknown',
              "Pre zásuvku #{key[:system]} / #{key[:opening]} nemá plugin žiadny vydaný recept — aktualizuj plugin."
            )
          end
        end
        # Chybajuci `system` aj chybajuci zaznam mapy sa ZAPISU (migracia ciel
        # klasifikovanych pred v2) — v TEJ ISTEJ operacii ako geometria.
        out[:writes] << { 'front_id' => front_id, 'system' => key[:system],
                          'ref_key' => ref_key, 'recipe_id' => ref }

        recipe = Recipes.load(ref)
        ctx = context_for(item, ctx_plan, cfg)
        th = drawer_thickness_map(front_id, part_thicknesses)
        overrides = Array(cfg[:hardware_overrides])

        # Legacy NL override (D-93) sa premapuje na receptovu identitu; vypnuty
        # alebo mnozstvom prepisany zaznam je RED (fail-closed).
        bad = drawer_override_problem(front_id, ref, overrides)
        if bad
          return out[:conflicts] << drawer_conflict(front_id, 'drawer_override_invalid', bad)
        end
        migrate = drawer_override_migration(front_id, ref, overrides)
        out[:override_writes] << migrate if migrate

        res = Recipes.resolve(recipe, ctx, th, overrides)
        unless res[:conflicts].empty?
          c = res[:conflicts].first
          return out[:conflicts] << drawer_conflict(front_id, c[:code], c[:message])
        end

        out[:parts].concat(drawer_part_descriptors(front_id, res[:parts], ctx))
        out[:hardware] << drawer_hardware_item(front_id, item, recipe, res, ctx, overrides)
        if Recipes.sync_recommended?(recipe, ctx[:clear_width])
          out[:warnings] << BuildPlan.warning(
            'drawer_sync_recommended',
            "Zásuvka #{front_id} (šírka #{Recipes.fmt(ctx[:clear_width])} mm) vyžaduje synchronizáciu — " \
            'pridaj synchronizačný set cez ad-hoc kovanie.',
            part_key: ctx[:owner_part_key],
            data: { 'front_id' => front_id, 'clear_width' => ctx[:clear_width].to_f }
          )
        end
        out
      end

      # Recept pre NOVU kombinaciu system|otvaranie: SURODENEC rovnakej verzie
      # ako uz pripnute zaznamy (prepnutie klasifikacie nikdy ticho nepovysi
      # verziu), inak `latest_for`.
      def pick_recipe_ref(refs_map, key)
        if refs_map.is_a?(Hash)
          refs_map.each_value do |id|
            sib = Recipes.sibling(id, key[:system], key[:opening])
            return sib if sib
          end
        end
        Recipes.latest_for(key[:system], key[:opening])
      end

      # Hrubky VYRABANYCH dielcov jedneho cela (rola -> mm). `part_thicknesses`
      # je mapa part_key -> mm od buildera; chybajuci kluc = UNI 16 fallback.
      def drawer_thickness_map(front_id, part_thicknesses)
        src = part_thicknesses.is_a?(Hash) ? part_thicknesses : {}
        Recipes::PART_ROLES.each_with_object({}) do |role, acc|
          v = src[PartKeys.front(front_id, role)]
          acc[role] = (v.is_a?(Numeric) && v.to_f.positive? ? v.to_f : DRAWER_DEFAULT_THICKNESS)
        end
      end

      # Legacy / receptovy NL override, ktory zasuvku ZASTAVUJE: vypnuta polozka
      # alebo prepisane mnozstvo (recept vydava vzdy PRAVE JEDEN vysuv).
      def drawer_override_problem(front_id, recipe_id, overrides)
        owner = PartKeys.front(front_id, 'panel')
        rec = Array(overrides).reverse.find { |ov| drawer_override?(ov, owner, recipe_id) }
        return nil if rec.nil?

        if rec['disabled'] == true || rec[:disabled] == true
          return 'Zásuvka má vypnutú položku výsuvu — výsuv z receptu sa vypnúť nedá; ' \
                 'zruš ručný zásah v Kovaní.'
        end
        q = rec['quantity'].nil? ? rec[:quantity] : rec['quantity']
        return nil if q.nil?
        return nil if q.is_a?(Numeric) && q.to_i == 1

        "Zásuvka má ručne prepísaný počet výsuvov (#{q}) — recept vydáva vždy jeden; " \
        'zruš ručný zásah v Kovaní.'
      end

      def drawer_override?(ov, owner, recipe_id)
        return false unless ov.is_a?(Hash)
        gt = (ov['generic_type'] || ov[:generic_type]).to_s
        return false unless gt == Recipes::LOCK_GENERIC_TYPE
        rid = (ov['rule_id'] || ov[:rule_id]).to_s
        return false unless [Recipes::LOCK_LEGACY_RULE_ID, "recipe:#{recipe_id}"].include?(rid)
        (ov['owner_part_key'] || ov[:owner_part_key]).to_s == owner.to_s
      end

      # D-93 migracia: legacy `vysuvy-nl-podla-hlbky` zaznam na zasuvkovom cele
      # sa premenuje na receptovu identitu `recipe:<recipe_id>`. Zamok tym
      # NEMENI hodnotu — meni sa len to, ku ktorej polozke patri.
      def drawer_override_migration(front_id, recipe_id, overrides)
        owner = PartKeys.front(front_id, 'panel')
        legacy = Array(overrides).find do |ov|
          ov.is_a?(Hash) &&
            (ov['generic_type'] || ov[:generic_type]).to_s == Recipes::LOCK_GENERIC_TYPE &&
            (ov['rule_id'] || ov[:rule_id]).to_s == Recipes::LOCK_LEGACY_RULE_ID &&
            (ov['owner_part_key'] || ov[:owner_part_key]).to_s == owner.to_s
        end
        return nil if legacy.nil?

        { 'owner_part_key' => owner, 'generic_type' => Recipes::LOCK_GENERIC_TYPE,
          'from_rule_id' => Recipes::LOCK_LEGACY_RULE_ID, 'to_rule_id' => "recipe:#{recipe_id}" }
      end

      # --- KOV-C2b: dielce zasuvky do planu ------------------------------------
      #
      # Recept vracia CISTE rozmery ({ role, width, height, thickness, side }).
      # Tu z nich vznikaju PLNE deskriptory `BuildPlan` — vratane polohy v korpuse.
      #
      # KONVENCIA (rovnaka pre vsetky roly): `prod[:length]` = rozmer `width`
      # receptu (dlha, „cez skrinku" resp. pozdlzna hrana), `prod[:width]` =
      # rozmer `height`. Vdaka tomu ABS L1/L2 lezia na DLHEJ hrane presne tak,
      # ako to popisuje seed 4 (`drawer_back`/`box_side`/`drawer_inner_front`
      # maju L1 = horna dlha hrana).
      #
      # OSI (`axes:`) sa VEDOME NEUVADZAJU. `axes` sluzia VYHRADNE na farbenie
      # ABS plosiek (D-88) a PartFaces ma vlastnu zasadu „radsej ziadna farba nez
      # farba na zlej hrane": pri stojacom dielci by L1 vysla na SPODNU hranu,
      # kym paska ide na HORNU. Farbenie hran zasuviek preto pride az s vlastnou
      # osovou mapou (KOV-C2c / D); geometria, vyrobne rozmery ani ABS kody od
      # osi nezavisia.
      #
      # UMIESTNENIE: box je vycentrovany v svetlej sirke (`ctx[:x0]`..`x1`),
      # zaciatok hlbky je predna rovina vnutra (y = 0) a spodok riadku `ctx[:z0]`.
      # Je to VIZUAL zasuvky v korpuse — vyrobne cisla urcuje recept.
      def drawer_part_descriptors(front_id, parts, ctx)
        return [] if parts.empty?

        anchor = { cx: (ctx[:x0].to_f + ctx[:x1].to_f) / 2.0, z0: ctx[:z0].to_f,
                   outer: drawer_outer_width(parts), lift: drawer_bottom_lift(parts),
                   depth: drawer_box_depth(parts), bottom_th: drawer_bottom_thickness(parts) }
        parts.each_with_index.map { |p, i| drawer_part_descriptor(front_id, p, i, anchor) }
      end

      # Vonkajsia sirka boxu — pri Quadre dno lezi MEDZI bokmi, takze celkova
      # sirka je dno + 2 boky. Pri Atire (bez vyrabanych bokov) je to sirka dna.
      def drawer_outer_width(parts)
        bottom = parts.find { |p| p[:role] == Recipes::ROLE_BOTTOM }
        return 0.0 if bottom.nil?

        side = parts.find { |p| p[:role] == Recipes::ROLE_BOX_SIDE }
        bottom[:width].to_f + (side ? 2 * side[:thickness].to_f : 0.0)
      end

      # Zvisle odsadenie dna nad spodkom boxu (Quadro `bottom_offset` = 12 mm;
      # pri Atire dno lezi rovno na dne boxu). Odvodi sa z toho, ci recept
      # vyraba boky — druhy zdroj konstanty (12) by sa s receptom rozisiel.
      def drawer_bottom_lift(parts)
        side = parts.find { |p| p[:role] == Recipes::ROLE_BOX_SIDE }
        return 0.0 if side.nil?

        fb = parts.find { |p| p[:role] == Recipes::ROLE_INNER_FRONT }
        bottom = parts.find { |p| p[:role] == Recipes::ROLE_BOTTOM }
        return 0.0 if fb.nil? || bottom.nil?

        # box_height - (vyska predku) - (hrubka dna) = bottom_offset receptu
        [side[:height].to_f - fb[:height].to_f - bottom[:thickness].to_f, 0.0].max
      end

      # Hlbka boxu = dlzka dna (Atira BL = NL + 10, Quadro NL). Ziadna druha
      # konstanta — je to presne to cislo, na ktore sa dielec reze.
      def drawer_box_depth(parts)
        bottom = parts.find { |p| p[:role] == Recipes::ROLE_BOTTOM }
        bottom ? bottom[:height].to_f : 0.0
      end

      def drawer_bottom_thickness(parts)
        bottom = parts.find { |p| p[:role] == Recipes::ROLE_BOTTOM }
        bottom ? bottom[:thickness].to_f : 0.0
      end

      def drawer_part_descriptor(front_id, p, index, anchor)
        role = p[:role].to_s
        wd = p[:width].to_f
        ht = p[:height].to_f
        th = p[:thickness].to_f
        side = p[:side].to_s
        cx = anchor[:cx]
        z_lift = anchor[:z0] + anchor[:lift]
        prod = { length: wd, width: ht, thickness: th }

        case role
        when Recipes::ROLE_BOX_SIDE
          # Zvisly panel pozdlz hlbky: hrubka v X, dlzka (NL) v Y, vyska v Z.
          outer = anchor[:outer].positive? ? anchor[:outer] : (wd + 2 * th)
          x_out = cx - outer / 2.0
          box = [th, wd, ht]
          origin = [(side == 'right' ? (x_out + outer - th) : x_out), 0.0, anchor[:z0]]
          suffix = "DRWSIDE-#{side == 'right' ? 'R' : 'L'}"
          key = PartKeys.front(front_id, 'box_side', side)
          name = "Bok boxu #{side == 'right' ? 'pravy' : 'lavy'} #{front_id}"
        when Recipes::ROLE_BOTTOM
          box = [wd, ht, th]
          origin = [cx - wd / 2.0, 0.0, z_lift]
          suffix = 'DRWBOT'
          key = PartKeys.front(front_id, 'drawer_bottom')
          name = "Dno zasuvky #{front_id}"
        when Recipes::ROLE_INNER_FRONT
          # Predok aj chrbat stoja NA dne (recept ich vysku tak aj pocita:
          # box_height - hrubka dna - odsadenie dna).
          box = [wd, th, ht]
          origin = [cx - wd / 2.0, 0.0, z_lift + anchor[:bottom_th]]
          suffix = 'DRWIFR'
          key = PartKeys.front(front_id, 'drawer_inner_front')
          name = "Vnutorne celo zasuvky #{front_id}"
        else # ROLE_BACK
          box = [wd, th, ht]
          origin = [cx - wd / 2.0, [anchor[:depth] - th, 0.0].max, z_lift + anchor[:bottom_th]]
          suffix = 'DRWBACK'
          key = PartKeys.front(front_id, 'drawer_back')
          name = "Chrbat zasuvky #{front_id}"
        end
        { suffix: "#{suffix}-#{front_id}-#{index + 1}", part_key: key, role: role, name: name,
          material: :drawer, box: box, origin: origin, prod: prod }
      end

      # --- KOV-C2b: JEDNA polozka vysuvu ---------------------------------------
      #
      # `rule_id` = `recipe:<recipe_id>` (identita, ktorou si polozku najde aj
      # NL zamok), `source: 'recipe'` (nakup ju cita TRIEDNYM klucom a chybajuci
      # set je RED, nie ORANGE), `locked` LEN pri platnom zamku.
      def drawer_hardware_item(front_id, item, recipe, res, ctx, overrides)
        params = { 'recipe_id' => recipe[:recipe_id].to_s, 'system' => recipe[:system].to_s,
                   'nominal_length' => res[:nl].to_f, 'load' => res[:load].to_f,
                   'opening' => recipe[:opening].to_s,
                   'opening_mode' => item['opening_mode'].to_s,
                   'drawer_construction' => (item['drawer'] || {})['construction'].to_s }
        params['height_variant'] = res[:height_variant].to_i if res[:height_variant]
        params['box_height'] = res[:box_height].to_f if res[:box_height]

        out = { 'owner_part_key' => ctx[:owner_part_key], 'generic_type' => 'slide',
                'quantity' => 1, 'rule_id' => "recipe:#{recipe[:recipe_id]}",
                'variant_id' => nil, 'production_class' => 'counted', 'manufactured' => true,
                'params' => params, 'source' => BuildPlan::HW_SOURCE_RECIPE, 'rule_quantity' => 1 }
        out['locked'] = true if Recipes.lock_value(recipe, ctx, overrides)
        out
      end

      # --- KOV-C1: svetly priestor pre recept zasuvky --------------------------
      #
      # CISTA funkcia (ziadne IO, ziadny zapis): z NEZAOKRUHLENYCH hranic riadku
      # cela, interieru a listovej zony vrati kontext, ktory `Recipes.resolve`
      # potrebuje. `build_plan` ju v C1 NEVOLA — zapojenie je uloha rezu C2.
      #
      #   owner — resolved polozka cela (`plan[:front_items]`) alebo jej `id`
      #   plan  — vysledok `build_plan` (nesie `zone_bounds` a `front_bounds`)
      #   cfg   — config korpusu (symbolove kluce, mm Float)
      #
      # Vracia:
      #   clear_width     svetla sirka LISTOVEJ zony pretinajucej riadok (NIE w-2t)
      #   clear_height    prienik z-intervalu riadku s interierom A listovou zonou
      #   clear_depth     interior[:back_front_y] — vnutorna hlbka od prednej
      #                   hrany po PREDNU PLOCHU chrbta (per rezim chrbta)
      #   side_thickness  hrubka boku korpusu (KD)
      #   obstructions    police a priecky pretinajuce riadok (C2 z nich robi
      #                   conflict `drawer_obstruction`)
      #   owner_part_key  kluc panela cela (identita NL zamku v hardware_overrides)
      #   front_id        id riadku cela
      def context_for(owner, plan, cfg)
        front_id = owner.is_a?(Hash) ? owner['id'].to_s : owner.to_s
        fb = (plan[:front_bounds] || {})[front_id]
        raise "Construction.context_for: plan nema surove hranice cela #{front_id}." if fb.nil?

        interior = interior_dims(cfg)
        t = cfg[:thickness].to_f
        # Riadok cela orezany INTERIEROM (celo prekryva aj dno/vrch korpusu).
        row_lo = [fb[:z0].to_f, interior[:z_lo].to_f].max
        row_hi = [fb[:z1].to_f, interior[:z_hi].to_f].min

        zone = leaf_zone_for_row(plan, row_lo, row_hi)
        if zone
          clear_width = zone[:x1] - zone[:x0]
          lo = [row_lo, zone[:z0]].max
          hi = [row_hi, zone[:z1]].min
        else
          # Bez listovej zony (velmi stary plan bez `zone_bounds`) ostava svetla
          # sirka korpusu — vzdy sa PRIZNA, nikdy sa nehada uzsia hodnota.
          clear_width = cfg[:width].to_f - (2 * t)
          lo = row_lo
          hi = row_hi
        end

        # KOV-C2b: ADITIVNE kotvy pre UMIESTNENIE dielcov zasuvky v korpuse.
        # `x0`/`x1` je vodorovny rozsah svetleho priestoru (listova zona alebo
        # cely vnutorny box), `z0` spodok riadku. Su to TIE ISTE cisla, z ktorych
        # sa pocita `clear_width`/`clear_height` — druhy vypocet inde by sa
        # casom rozisiel a dielec by v modeli stal inde, nez ho plan vyratal.
        x0 = zone ? zone[:x0].to_f : t
        x1 = zone ? zone[:x1].to_f : (cfg[:width].to_f - t)
        { clear_width: [clear_width, 0.0].max,
          clear_height: [hi - lo, 0.0].max,
          clear_depth: interior[:back_front_y].to_f,
          side_thickness: t,
          obstructions: row_obstructions(plan, row_lo, row_hi),
          owner_part_key: PartKeys.front(front_id, 'panel'),
          front_id: front_id,
          x0: x0, x1: x1, z0: lo, z1: hi }
      end

      # Listova zona s NAJVACSIM zvislym prienikom s riadkom (pri zhode lavejsia).
      # Viac zon s kladnym prienikom = zvisla priecka cez riadok — tu sa vyberie
      # jedna, obstruction ju prizna samostatne.
      def leaf_zone_for_row(plan, row_lo, row_hi)
        bounds = plan[:zone_bounds] || {}
        best = nil
        best_overlap = 0.0
        Array(plan[:zones]).each do |z|
          next unless z[:leaf]

          b = bounds[z[:id]]
          next if b.nil?

          overlap = [row_hi, b[:z1]].min - [row_lo, b[:z0]].max
          next if overlap <= 0.0

          if overlap > best_overlap || (overlap == best_overlap && best && b[:x0] < best[:x0])
            best = b
            best_overlap = overlap
          end
        end
        best
      end

      # Police a priecky, ktorych zvisly rozsah pretina riadok (kladny prienik).
      OBSTRUCTION_ROLES = %w[shelf divider_h divider_v].freeze

      def row_obstructions(plan, row_lo, row_hi)
        Array(plan[:parts]).each_with_object([]) do |pd, acc|
          role = pd[:role].to_s
          next unless OBSTRUCTION_ROLES.include?(role)

          z0 = pd[:origin][2].to_f
          z1 = z0 + pd[:box][2].to_f
          next if ([row_hi, z1].min - [row_lo, z0].max) <= 0.0

          acc << { role: role, part_key: pd[:part_key].to_s, z0: z0, z1: z1 }
        end
      end

      # D-80 (F3): ked vystuhy znizia strop vnutra, stare clenenie (police, delenia,
      # zamknute vysky) sa uz nemusi zmestit. ZoneTree v takom pripade RAISNE —
      # rebuild sa odmietne (ziadne tiche mazanie polic a zamkov), ale pouzivatel
      # musi vidiet PRECO. Panel hlasku ukaze cez set_status.
      # ZAMERNE len RuntimeError: ZoneTree validacie hlasia `raise "text"`. Chyba
      # kodu (NoMethodError a spol.) sa NESMIE prezliect za pouzivatelsku hlasku —
      # bublina ide von nedotknuta. Povodny dovod zo ZoneTree ostava v texte.
      def compute_zone_tree!(cfg, interior, zbox, t, cabinet_id)
        ZoneTree.compute(cfg[:zone_tree], zbox, t, cabinet_id)
      rescue RuntimeError => e
        raise e unless rails_lower_interior?(cfg, interior)
        raise "Vnútorná výška sa znížila (výstuhy) — uprav zóny alebo odsadenie výstuh. #{e.message}"
      end

      # true = strop vnutra urcuju vystuhy a lezi NIZSIE, nez by lezal plny vrch.
      def rails_lower_interior?(cfg, interior)
        return false unless cfg[:top_mode] == 'two_rails'
        interior[:z_hi].to_f < (cfg[:height].to_f - cfg[:thickness].to_f - 0.01)
      end

      # Typ podopretia korpusu (JEDEN zdroj pravdy — builder support_descriptor aj
      # pravidla kovania citaju tuto funkciu): horna/na zemi = none, predny sokel =
      # plinth (nohy pod nim aj tak su — pravidlo noh berie legs AJ plinth), inak legs.
      def support_type(cfg)
        return 'none' if cfg[:type] == 'upper' || cfg[:floor_height].to_f <= 0
        cfg[:plinth_mode] == 'front' ? 'plinth' : 'legs'
      end

      # D-37 (zavazne, Michal 20.7.): cfg[:depth] = CELKOVA hlbka korpusu VRATANE
      # chrbta vo VSETKYCH rezimoch. Konstrukcna hlbka (boky/dno/vrch/vystuhy/nohy):
      #   overlay -> d - bt (chrbat NALOZENY zozadu zabera zadnych bt z celkovej d)
      #   inset / groove -> d (chrbat je VNUTRI obrysu — uz dnes splnaju celkovu d)
      #   none -> d (ziadny chrbat)
      # POZOR: inset/groove sa tymto helperom NESMU skratit (audit NOTE 9).
      def carcass_depth(cfg)
        cfg[:back_mode] == 'overlay' ? cfg[:depth] - back_thickness(cfg) : cfg[:depth]
      end

      # D-80: geometria hornych vystuh na JEDNOM mieste. rail_parts (dielce),
      # interior_dims (strop vnutra) aj back_z_hi (vyska chrbta) citaju TENTO
      # vysledok — ziadna druha kopia vzorca, ktora by sa mohla rozist.
      #
      # Vystuhy zaberaju od vrchu smerom dole: `offset` (rails_top_offset, napr.
      # znizenie pod varnu dosku) + `occupy` (flat = hrubka dosky; upright = vyska
      # vystuhy na hranu, az ~rail_depth). Spodna hrana `z_bottom` = strop vnutra.
      #
      # Clampy (obidva hlasene warningom, nikdy tiche):
      #   depth  — flat: hlbka <= d/2 - 10; upright: vyska <= dostupne miesto; min 20
      #   offset — 0 .. (dostupne miesto - occupy), aby vnutro drzalo MIN_INTERIOR_H
      # Hranicny pripad (Codex P2 na PR #134): ak je `head` mensi nez minimalna
      # vystuha (20 mm), vyhrava minimum vystuhy a vnutro by kleslo pod rezervu
      # (napr. 200/sokel 150/t 18 upright -> vnutro 12 mm). Vystuha tenka ako 12 mm
      # je nezmysel, preto sa TU nic neohyba — invariant "two_rails => vnutro aspon
      # MIN_INTERIOR_H" strazi validate! vlastnou zrozumitelnou hlaskou.
      # rail_geometry ostava CISTY kalkulator (ziadna vynimka) — presne to zrkadli JS.
      def rail_geometry(cfg)
        h = cfg[:height].to_f; t = cfg[:thickness].to_f; s = cfg[:floor_height].to_f
        d = carcass_depth(cfg)
        # kolko smie odsadenie + vystuha spolu zabrat z vysky korpusu
        head = [h - (s + t) - MIN_INTERIOR_H, 0.0].max
        want_depth = cfg[:rail_depth].to_f
        want_off   = cfg[:rails_top_offset].to_f
        upright = cfg[:rails_orientation] == 'upright'
        limit = upright ? head : (d / 2.0 - 10.0)
        dep = [want_depth, limit].min
        dep = 20.0 if dep < 20.0
        occupy = upright ? dep : t
        max_off = [head - occupy, 0.0].max
        off = [[want_off, 0.0].max, max_off].min
        { offset: off, wanted_offset: want_off, depth: dep, wanted_depth: want_depth,
          occupy: occupy, upright: upright, clamp_label: (upright ? 'vyska' : 'hlbka'),
          z_top: h - off, z_bottom: h - off - occupy }
      end

      # Vnutorne rozmery (svetle) + poloha celnej hrany chrbta. Hrubka chrbta z configu.
      def interior_dims(cfg)
        h = cfg[:height]; d = cfg[:depth]
        t = cfg[:thickness]; s = cfg[:floor_height]
        bt = back_thickness(cfg)
        z_lo = s + t
        # D-80: pri two_rails konci vnutro na SPODNEJ hrane vystuh (nie na h - t) —
        # inak by sa zony/police/priecky ratali do priestoru varnej dosky a pri
        # vystuhach 'upright' aj do celej vysky vystuhy.
        z_hi =
          case cfg[:top_mode]
          when 'none'      then h
          when 'two_rails' then rail_geometry(cfg)[:z_bottom]
          else                  h - t
          end
        back_front_y =
          case cfg[:back_mode]
          when 'none'   then d # D-31: ziadny chrbat — vnutro az po zadnu rovinu
          when 'inset'  then d - bt
          when 'groove' then d - GROOVE_OFFSET - bt
          else d - bt # D-37 overlay: chrbat zabera zadnych bt CELKOVEJ hlbky
          end
        { z_lo: z_lo, z_hi: z_hi, avail_h: (z_hi - z_lo), back_front_y: back_front_y, back_thickness: bt }
      end

      def back_thickness(cfg)
        v = cfg[:back_thickness].to_f
        v.positive? ? v : BACK_THICKNESS_DEFAULT
      end

      # Boky — KONSTRUKCNA hlbka (D-37). Z-start podla variantu dna.
      def side_parts(cfg)
        w = cfg[:width]; d = carcass_depth(cfg); t = cfg[:thickness]; s = cfg[:floor_height]; h = cfg[:height]
        z0 = cfg[:bottom_mode] == 'under_sides' ? (s + t) : 0.0
        sh = h - z0
        [
          { suffix: 'SIDE-L', part_key: PartKeys.cabinet('side', 'left'),
            role: 'side_left', name: 'Bok lavy', material: :korpus,
            box: [t, d, sh], origin: [0, 0, z0], prod: { length: sh, width: d, thickness: t },
            axes: PartFaces::AXES_UPRIGHT },
          { suffix: 'SIDE-R', part_key: PartKeys.cabinet('side', 'right'),
            role: 'side_right', name: 'Bok pravy', material: :korpus,
            box: [t, d, sh], origin: [w - t, 0, z0], prod: { length: sh, width: d, thickness: t },
            axes: PartFaces::AXES_UPRIGHT }
        ]
      end

      # Dno — vzdy na urovni Z = floor_height (priestor pod nim = nohy / sokel).
      def bottom_part(cfg)
        w = cfg[:width]; d = carcass_depth(cfg); t = cfg[:thickness]; s = cfg[:floor_height]
        if cfg[:bottom_mode] == 'under_sides'
          { suffix: 'BOTTOM', part_key: PartKeys.cabinet('bottom'), role: 'bottom', name: 'Dno', material: :korpus,
            box: [w, d, t], origin: [0, 0, s], prod: { length: w, width: d, thickness: t },
            axes: PartFaces::AXES_LYING }
        else
          { suffix: 'BOTTOM', part_key: PartKeys.cabinet('bottom'), role: 'bottom', name: 'Dno', material: :korpus,
            box: [w - 2 * t, d, t], origin: [t, 0, s], prod: { length: w - 2 * t, width: d, thickness: t },
            axes: PartFaces::AXES_LYING }
        end
      end

      # Vrch — full / two_rails / none. warnings: volitelny kolektor (BuildPlan kontrakt).
      def top_parts(cfg, warnings = nil)
        w = cfg[:width]; d = carcass_depth(cfg); t = cfg[:thickness]; h = cfg[:height]
        case cfg[:top_mode]
        when 'none'
          []
        when 'two_rails'
          rail_parts(cfg, warnings)
        else # full
          [{ suffix: 'TOP', part_key: PartKeys.cabinet('top'), role: 'top', name: 'Vrch', material: :korpus,
             box: [w - 2 * t, d, t], origin: [t, 0, h - t], prod: { length: w - 2 * t, width: d, thickness: t },
             axes: PartFaces::AXES_LYING }]
        end
      end

      # Dve horne vystuhy (rail_front / rail_back). flat = naplocho, upright = na hranu.
      # Orezanie hlbky/vysky vystuhy uz nie je tiche — hlasi sa do warnings (ak je kolektor).
      # D-37: zadna vystuha sedi na KONSTRUKCNEJ hlbke (pri overlay pred chrbtom).
      def rail_parts(cfg, warnings = nil)
        w = cfg[:width]; d = carcass_depth(cfg); t = cfg[:thickness]
        g = rail_geometry(cfg) # D-80: JEDINY zdroj clampov (zdielany s interior_dims)
        rail_clamp_warning(warnings, g[:wanted_depth], g[:depth], g[:clamp_label])
        rail_offset_warning(warnings, g[:wanted_offset], g[:offset])
        z0 = g[:z_bottom]
        rd = g[:depth]
        prod = { length: w - 2 * t, width: rd, thickness: t }
        if g[:upright]
          [
            { suffix: 'TOP-RAIL-F', part_key: PartKeys.cabinet('rail', 'front'),
              role: 'rail_front', name: 'Vystuha predna', material: :korpus,
              box: [w - 2 * t, t, rd], origin: [t, 0, z0], prod: prod, axes: PartFaces::AXES_WALL },
            { suffix: 'TOP-RAIL-B', part_key: PartKeys.cabinet('rail', 'back'),
              role: 'rail_back', name: 'Vystuha zadna', material: :korpus,
              box: [w - 2 * t, t, rd], origin: [t, d - t, z0], prod: prod, axes: PartFaces::AXES_WALL }
          ]
        else # flat
          [
            { suffix: 'TOP-RAIL-F', part_key: PartKeys.cabinet('rail', 'front'),
              role: 'rail_front', name: 'Vystuha predna', material: :korpus,
              box: [w - 2 * t, rd, t], origin: [t, 0, z0], prod: prod, axes: PartFaces::AXES_LYING },
            { suffix: 'TOP-RAIL-B', part_key: PartKeys.cabinet('rail', 'back'),
              role: 'rail_back', name: 'Vystuha zadna', material: :korpus,
              box: [w - 2 * t, rd, t], origin: [t, d - rd, z0], prod: prod, axes: PartFaces::AXES_LYING }
          ]
        end
      end

      # D-80 (F5): horna hrana chrbta v rezimoch inset/groove. KONZERVATIVNE —
      # chrbat bezi ZA vystuhami, preto sa skracuje LEN o odsadenie vystuh
      # (rails_top_offset), NIE o vysku upright vystuhy. Pri offsete 0 vrati presne
      # povodne h - t => bez odsadenia sa vyroba chrbta NEMENI.
      # POZN: finalny konstrukcny detail (napr. ci ma chrbat pri upright vystuhe
      # koncit este nizsie) potvrdi Michal pri teste — je to zmena na 1 riadku.
      def back_z_hi(cfg, interior)
        return interior[:z_hi] unless cfg[:top_mode] == 'two_rails'
        cfg[:height].to_f - rail_geometry(cfg)[:offset] - cfg[:thickness].to_f
      end

      # Chrbat — overlay / inset / groove / none (D-31: none = ziadny dielec).
      # D-37: VSETKY rezimy koncia najneskor na celkovej hlbke d — overlay chrbat
      # lezi v pasme [d-bt, d] ZA skratenym korpusom (uz nie za celkovou hlbkou).
      def back_part(cfg, interior)
        return nil if cfg[:back_mode] == 'none' # D-31: explicitne (else vetva by vyrobila overlay!)
        w = cfg[:width]; d = cfg[:depth]; h = cfg[:height]; t = cfg[:thickness]; s = cfg[:floor_height]
        bt = interior[:back_thickness]
        z_hi = back_z_hi(cfg, interior)
        case cfg[:back_mode]
        when 'inset'
          z0 = interior[:z_lo]; bh = z_hi - z0
          { suffix: 'BACK', part_key: PartKeys.cabinet('back'), role: 'back', name: 'Chrbat', material: :korpus,
            box: [w - 2 * t, bt, bh], origin: [t, d - bt, z0], prod: { length: w - 2 * t, width: bh, thickness: bt },
            axes: PartFaces::AXES_WALL }
        when 'groove'
          z0 = interior[:z_lo]; bh = z_hi - z0
          y0 = d - GROOVE_OFFSET - bt
          { suffix: 'BACK', part_key: PartKeys.cabinet('back'), role: 'back', name: 'Chrbat', material: :korpus,
            box: [w - 2 * t, bt, bh], origin: [t, y0, z0], prod: { length: w - 2 * t, width: bh, thickness: bt },
            axes: PartFaces::AXES_WALL }
        else # overlay
          { suffix: 'BACK', part_key: PartKeys.cabinet('back'), role: 'back', name: 'Chrbat', material: :korpus,
            box: [w, bt, h - s], origin: [0, d - bt, s], prod: { length: w, width: h - s, thickness: bt },
            axes: PartFaces::AXES_WALL }
        end
      end

      # Sokel — len variant 'front' (predny zapusteny panel).
      def plinth_parts(cfg)
        return [] unless cfg[:plinth_mode] == 'front'
        s = cfg[:floor_height]
        return [] if s <= 0
        w = cfg[:width]; t = cfg[:thickness]; recess = cfg[:plinth_recess]
        # D-17: sokel na PLNU sirku skrinky (vyrobny standard — licuje s bokmi).
        # Vynimka: dno medzi bokmi = boky siahaju na zem (side_parts z0=0),
        # plny sokel by sa s nimi objemovo pretal -> ostava medzi bokmi.
        between = cfg[:bottom_mode] == 'between_sides'
        px = between ? t : 0.0
        pw = between ? (w - 2 * t) : w
        [{ suffix: 'PLINTH', part_key: PartKeys.cabinet('plinth', 'front'),
           role: 'plinth', name: 'Sokel predny', material: :korpus,
           box: [pw, t, s], origin: [px, recess, 0], prod: { length: pw, width: s, thickness: t },
           axes: PartFaces::AXES_WALL }]
      end

      # Prida warning o orezani rozmeru vystuhy (ziadany != pouzity).
      def rail_clamp_warning(warnings, wanted, used, label)
        return if warnings.nil? || (wanted.to_f - used.to_f).abs < 0.01
        warnings << BuildPlan.warning('rail_depth_clamped',
                                      "Vystuha: #{label} orezana z #{wanted.to_f.round(1)} na #{used.to_f.round(1)} mm (limit korpusu).",
                                      data: { 'wanted' => wanted.to_f, 'used' => used.to_f })
      end

      # D-80: to iste pre ODSADENIE vystuh od vrchu (rovnaky vzor — nikdy tiche
      # orezanie). Extremne odsadenie sa oreze tak, aby vnutro drzalo
      # MIN_INTERIOR_H; rebuild sa NEodmietne.
      def rail_offset_warning(warnings, wanted, used)
        return if warnings.nil? || (wanted.to_f - used.to_f).abs < 0.01
        warnings << BuildPlan.warning('rail_offset_clamped',
                                      "Vystuha: odsadenie od vrchu orezane z #{wanted.to_f.round(1)} na " \
                                      "#{used.to_f.round(1)} mm (vnutro korpusu).",
                                      data: { 'wanted' => wanted.to_f, 'used' => used.to_f })
      end

      def validate!(cfg, interior)
        w = cfg[:width]; h = cfg[:height]; t = cfg[:thickness]; s = cfg[:floor_height]
        raise 'Sirka je prilis mala vzhladom na hrubku materialu.' if w <= 2 * t + 10
        raise 'Hlbka je prilis mala.' if interior[:back_front_y] <= 10
        raise 'Podstavec/sokel nesmie byt vyssi nez korpus.' if s >= h
        raise 'Vnutorna vyska je nulova alebo zaporna (skontroluj vysku, podstavec a hrubky).' if interior[:avail_h] <= 10
        # D-80 (Codex P2 na PR #134): pri vrchu "dve vystuhy" musi pod nimi ostat
        # aspon MIN_INTERIOR_H svetla — inak vznikne zona mensia nez ZoneTree::MIN_FIELD
        # (a pri upright dokonca vystuha tenka pod svoje vlastne minimum). Kombinacia
        # je fyzicky nemozna, nie orezatelna — hlasi sa zrozumitelne, nie ticho.
        return unless cfg[:top_mode] == 'two_rails'
        return if interior[:avail_h] >= MIN_INTERIOR_H - 0.01
        raise 'Vnútro je príliš nízke na výstuhy (ostáva ' \
              "#{interior[:avail_h].to_f.round(1)} mm) — zväčši výšku korpusu, zmenši podstavec " \
              'alebo prepni vrch na plný.'
      end
    end
  end
end
