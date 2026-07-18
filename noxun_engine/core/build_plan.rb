# frozen_string_literal: true
# Noxun Engine — BuildPlan kontrakt (V0.3.4, plan stabilizacie). CISTO Ruby, ziadne SketchUp API.
#
# JEDINY zavazny tvar PLANU STAVBY KORPUSU: builder z neho kresli geometriu a NA ENTITY
# zapisuje vyrobny snapshot dielca (config s finalnym materialom/ABS po resolve_part).
# AUTORITATIVNY VYROBNY ZAZNAM pre vystupy V0.5 (kusovnik, VEPO) je SNAPSHOT NA ENTITE
# (standard 8.2/11.1) — plan je medzikrok stavby korpusu, nie zdroj exportu: finalny
# material/ABS vznikaju az resolve_part a samostatne dosky (kind board) v plane korpusu
# vobec nie su. Per-dielec kontrakt (validate_part!) je spolocny pre dielce korpusu AJ
# dosky — jeden tvar vyrobnych dat, jeden validator.
# Plan, ktory nepreide validate!, sa NIKDY nedostane do buildera ani do vystupov.
#
# PLAN (vystup Construction.build_plan):
#   schema      Integer  — verzia tvaru planu (SCHEMA). Bump pravidlo: aditivne volitelne
#                          pole = bez bumpu; zmena vyznamu/povinneho pola = bump + migracia.
#                          Verzuje sa NEZAVISLE od PartKeys::SCHEMA (format identity).
#                          Historia: 1 = V0.3.4 (hardware vzdy []); 2 = V0.4 (hardware plni
#                          rules engine, polozky string-keyed so sprisnenym kontraktom —
#                          ziadna datova migracia, lebo schema 1 hardware nikdy nenieslo).
#   parts       [dielec] — deskriptory REALNE POSTAVITELNYCH dielcov. Degenerovane dielce
#                          (nekladny rozmer boxu, napr. z extremne uzkych zon) sa do parts
#                          NEdostanu — plan ich vyradi s warningom part_skipped_degenerate,
#                          aby kusovnik nikdy neobsahoval dielec, ktory v modeli nestoji.
#   hardware    [hw]     — kovanie z pravidiel (core/hardware_rules.rb) + hardware_overrides.
#   warnings    [w]      — nefatalne upozornenia: plan JE postaveny, ale inak nez zadanie
#                          (orezane vystuhy, preskocene police...). Fatalne stavy ostavaju raise.
#   zones / zone_tree / front_items / available / wings / interior — odvodene data pre UI a config.
#
# DIELEC (parts[i]):
#   POVINNE:  part_key  String  — stabilna identita (PartKeys.valid?: cabinet/|zone:|front:)
#             suffix    String  — renderovaci suffix (stabilny, ale NIE identita)
#             role      String  — zo slovnika ROLES (standard 2.4)
#             name      String  — ludsky nazov (kusovnik/VEPO citaju ploche NOXUN/name)
#             material  Symbol  — :korpus | :front (signal pre dedenie materialov)
#             box       [3xFloat > 0] — rozmery telesa v korpuse (mm)
#             origin    [3xFloat]     — poloha v korpuse (mm; cela zaporne Y)
#             prod      {length, width, thickness — Float > 0} — vyrobne rozmery
#   VOLITELNE (default): production_class 'sheet' | manufactured true | quantity 1 |
#             grain_lock false (zakaz rotacie dekoru pri nestingu/VEPO)
#
# SEMANTIKA prod (zavazna pre vystupy): prod = HOTOVY rozmer dielca (s nalepenym ABS).
# Cisty prirez sa DOPOCITA pri exporte odpoctom hrubok ABS z edges (1.0/2.0 mm per strana);
# obchodna hrubka (18/36) a suhrnne kody hran (—/=) tiez az pri exporte (SYSTEM/03).
# Konvencia hran: L1/L2 lezia na prod[:length], W1/W2 na prod[:width];
# pri celach prod[:length] = VYSKA cela, prod[:width] = sirka (fronts.rb box_desc).
#
# HARDWARE polozka (schema 2): STRING kluce (JSON round-trip cez config korpusu bez
# konverzii — presne ako WARNING). Povinne polia:
#   owner_part_key   String|nil — nil = korpus ako celok; ak String, MUSI existovat v parts
#                    planu (referencna integrita); NIKDY neskladat cez PartKeys.segment
#                    (zmrzacil by '/' a ':')
#   generic_type     String zo slovnika GENERIC_TYPES
#   quantity         Integer 1..MAX_HW_QUANTITY
#   rule_id          String neprazdny (povod polozky; sucast identity override)
#   variant_id       nil vo faze 1 (two-phase mapovanie, standard 6.2), inak String
#   production_class 'counted' (faza 1; dlzkove kovanie pride s vlastnym kind)
#   manufactured     true
#   params           Hash (String kluce -> String/Numeric skalary), napr. height nohy,
#                    nominal_length vysuvu
#   source           'rule' | 'manual' (manual = quantity z hardware_overrides)
#   rule_quantity    Integer — povodny pocet z pravidla (UI: "rucne (pravidlo: 4)")
# Identita polozky = trojica (owner_part_key, generic_type, rule_id).
#
# WARNING polozka: { 'code', 'severity' ('warn'|'info'), 'message' (slovensky),
# 'part_key' (nil = korpusova uroven), 'data' (Hash) } — string kluce (JSON round-trip
# v configu korpusu cez merge_final).
module Noxun
  module Engine
    module BuildPlan
      SCHEMA = 2

      # Najmensi vyrobitelny rozmer (mm). JEDINY prah degenerovanosti v systeme:
      # plan (partition v Construction.build_plan) aj builder (positive_box?) ho zdielaju —
      # rozne epsilony by vytvorili pasmo, kde plan dielec deklaruje a builder ho preskoci.
      MIN_DIM = 0.01

      # Slovnik roli dielcov (standard 2.4) — validator odmietne nezname roly.
      # free_panel = samostatna doska (V0.4.7, kind board); buduce roly dosiek
      # (cover_side/cover_top/filler/worktop/plinth_board) pribudnu pri implementacii.
      ROLES = %w[
        side_left side_right bottom top back shelf divider_v divider_h
        front_door drawer_front flap cover_panel false_front rail_front rail_back
        plinth gola_profile free_panel
      ].freeze

      PRODUCTION_CLASSES = %w[sheet linear counted reference none].freeze

      # Slovnik generickych typov kovania (faza 1 pouziva leg/hinge/slide; zvysok
      # rezervovany standardom 2.4). Neznamy typ = chyba kontraktu, nie nova kategoria.
      GENERIC_TYPES = %w[leg hinge slide handle shelf_pin connector].freeze

      # Horna hranica poctu jednej polozky — poistka proti poskodenym pravidlam/override
      # (quantity priamo riadi pocet kreslenych noh; 100000 valcov nesmie byt mozne).
      MAX_HW_QUANTITY = 999

      HW_SOURCES = %w[rule manual].freeze

      module_function

      # Jednotny tvar warningu (string kluce — round-tripuje cez JSON v configu korpusu).
      def warning(code, message, part_key: nil, severity: 'warn', data: {})
        { 'code' => code.to_s, 'severity' => severity.to_s, 'message' => message.to_s,
          'part_key' => part_key, 'data' => data }
      end

      # Zvaliduje CELY plan (tvar + unikatnost part_key). Vola sa na konci
      # Construction.build_plan — chybny plan nikdy neopusti planovac.
      def validate!(plan)
        raise 'BuildPlan: plan musi byt Hash.' unless plan.is_a?(Hash)
        raise "BuildPlan: neznama schema #{plan[:schema].inspect} (cakam #{SCHEMA})." unless plan[:schema] == SCHEMA
        raise 'BuildPlan: parts musi byt pole.' unless plan[:parts].is_a?(Array)
        raise 'BuildPlan: warnings musi byt pole.' unless plan[:warnings].is_a?(Array)
        raise 'BuildPlan: hardware musi byt pole.' unless plan[:hardware].is_a?(Array)

        seen = {}
        plan[:parts].each { |pd| validate_part!(pd, seen) }
        plan[:hardware].each { |hw| validate_hardware!(hw, seen) }
        plan
      end

      # Zvaliduje jeden deskriptor dielca; `seen` strazi unikatnost part_key napriec planom.
      def validate_part!(pd, seen = {})
        raise 'BuildPlan: dielec musi byt Hash.' unless pd.is_a?(Hash)
        key = pd[:part_key].to_s
        raise "BuildPlan: dielec #{pd[:suffix]} ma neplatny part_key '#{key}'." unless PartKeys.valid?(key)
        raise "BuildPlan: duplicitny part_key #{key} v plane." if seen[key]
        seen[key] = true

        raise "BuildPlan: dielec #{key} nema suffix." if pd[:suffix].to_s.strip.empty?
        role = pd[:role].to_s
        raise "BuildPlan: dielec #{key} ma neznamu rolu '#{role}'." unless ROLES.include?(role)
        raise "BuildPlan: dielec #{key} nema nazov." if pd[:name].to_s.strip.empty?
        # :korpus/:front = signal dedenia materialu v korpuse (resolve_part);
        # :concrete (V0.4.7) = material je uz KONKRETNY v configu (samostatne dosky,
        # snapshot bez dedenia) — descriptor s :concrete NIKDY nejde cez resolve_part.
        unless %i[korpus front concrete].include?(pd[:material])
          raise "BuildPlan: dielec #{key} ma neplatny material #{pd[:material].inspect}."
        end
        validate_triplet!(key, 'box', pd[:box], positive: true)
        validate_triplet!(key, 'origin', pd[:origin], positive: false)

        prod = pd[:prod]
        raise "BuildPlan: dielec #{key} nema prod rozmery." unless prod.is_a?(Hash)
        %i[length width thickness].each do |f|
          v = prod[f]
          raise "BuildPlan: dielec #{key} ma neplatny prod #{f} (#{v.inspect})." unless v.is_a?(Numeric) && v.positive?
        end

        pc = pd.fetch(:production_class, 'sheet').to_s
        raise "BuildPlan: dielec #{key} ma neznamu production_class '#{pc}'." unless PRODUCTION_CLASSES.include?(pc)
        qty = pd.fetch(:quantity, 1)
        raise "BuildPlan: dielec #{key} ma neplatnu quantity (#{qty.inspect})." unless qty.is_a?(Integer) && qty.positive?
        pd
      end

      # Zvaliduje jednu hardware polozku (STRING kluce — kontrakt v hlavicke).
      # part_keys: hash existujucich part_key planu (referencna integrita ownera);
      # nil = kontrola vlastnika sa preskoci (izolovane unit testy poloziek).
      def validate_hardware!(hw, part_keys = nil)
        raise 'BuildPlan: hardware polozka musi byt Hash.' unless hw.is_a?(Hash)
        gt = hw['generic_type'].to_s
        raise "BuildPlan: hardware ma neznamy generic_type '#{gt}'." unless GENERIC_TYPES.include?(gt)

        owner = hw['owner_part_key']
        unless owner.nil? || PartKeys.valid?(owner.to_s)
          raise "BuildPlan: hardware ma neplatny owner_part_key '#{owner}'."
        end
        if owner && part_keys && !part_keys[owner.to_s]
          raise "BuildPlan: hardware #{gt} ukazuje na neexistujuci dielec '#{owner}'."
        end

        qty = hw['quantity']
        unless qty.is_a?(Integer) && qty >= 1 && qty <= MAX_HW_QUANTITY
          raise "BuildPlan: hardware #{gt} ma neplatnu quantity (#{qty.inspect})."
        end
        raise "BuildPlan: hardware #{gt} nema rule_id." if hw['rule_id'].to_s.strip.empty?
        unless hw['variant_id'].nil? || hw['variant_id'].is_a?(String)
          raise "BuildPlan: hardware #{gt} ma neplatny variant_id (#{hw['variant_id'].inspect})."
        end
        unless hw['production_class'] == 'counted'
          raise "BuildPlan: hardware #{gt} musi byt production_class 'counted' (faza 1)."
        end
        raise "BuildPlan: hardware #{gt} musi byt manufactured true." unless hw['manufactured'] == true
        validate_hw_params!(gt, hw['params'])
        unless HW_SOURCES.include?(hw['source'].to_s)
          raise "BuildPlan: hardware #{gt} ma neplatny source (#{hw['source'].inspect})."
        end
        rq = hw['rule_quantity']
        unless rq.is_a?(Integer) && rq >= 1 && rq <= MAX_HW_QUANTITY
          raise "BuildPlan: hardware #{gt} ma neplatnu rule_quantity (#{rq.inspect})."
        end
        hw
      end

      # params: plochy Hash so String klucmi a skalarnymi hodnotami (JSON round-trip).
      def validate_hw_params!(gt, params)
        raise "BuildPlan: hardware #{gt} nema params Hash." unless params.is_a?(Hash)
        params.each do |k, v|
          raise "BuildPlan: hardware #{gt} ma ne-String kluc params (#{k.inspect})." unless k.is_a?(String)
          next if v.is_a?(String) || v.is_a?(Numeric)
          raise "BuildPlan: hardware #{gt} ma neskalarny params['#{k}'] (#{v.inspect})."
        end
      end

      def validate_triplet!(key, label, v, positive:)
        ok = v.is_a?(Array) && v.size == 3 && v.all? { |x| x.is_a?(Numeric) } &&
             (!positive || v.all? { |x| x.to_f > 0 })
        raise "BuildPlan: dielec #{key} ma neplatny #{label} (#{v.inspect})." unless ok
      end
    end
  end
end
