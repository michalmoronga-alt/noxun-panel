# frozen_string_literal: true
# Noxun Engine — BuildPlan kontrakt (V0.3.4, plan stabilizacie). CISTO Ruby, ziadne SketchUp API.
#
# JEDINY zavazny tvar planu stavby: geometria (cabinet_builder), buduci kusovnik (V0.5)
# aj VEPO export (SYSTEM/03) citaju TEN ISTY plan — ziadne samostatne pravdy.
# Plan, ktory nepreide validate!, sa NIKDY nedostane do buildera ani do vystupov.
#
# PLAN (vystup Construction.build_plan):
#   schema      Integer  — verzia tvaru planu (SCHEMA). Bump pravidlo: aditivne volitelne
#                          pole = bez bumpu; zmena vyznamu/povinneho pola = bump + migracia.
#                          Verzuje sa NEZAVISLE od PartKeys::SCHEMA (format identity).
#   parts       [dielec] — deskriptory REALNE POSTAVITELNYCH dielcov. Degenerovane dielce
#                          (nekladny rozmer boxu, napr. z extremne uzkych zon) sa do parts
#                          NEdostanu — plan ich vyradi s warningom part_skipped_degenerate,
#                          aby kusovnik nikdy neobsahoval dielec, ktory v modeli nestoji.
#   hardware    [hw]     — kovanie. Tvar zavazny uz teraz (V0.4 rules engine ho zacne plnit);
#                          do V0.4 vzdy [].
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
# HARDWARE polozka: owner_part_key (String|nil — nil = korpus ako celok; NIKDY neskladat
# cez PartKeys.segment — zmrzacil by '/' a ':'), generic_type (hinge/slide/leg/handle/
# shelf_pin/connector), quantity (Integer > 0), rule_id (String), variant_id (nil vo faze 1 —
# two-phase mapovanie, standard 6.2), production_class 'counted', manufactured true.
# Identita kovania = trojica (owner_part_key, generic_type, index).
#
# WARNING polozka: { 'code', 'severity' ('warn'|'info'), 'message' (slovensky),
# 'part_key' (nil = korpusova uroven), 'data' (Hash) } — string kluce (JSON round-trip
# v configu korpusu cez merge_final).
module Noxun
  module Engine
    module BuildPlan
      SCHEMA = 1

      # Slovnik roli dielcov (standard 2.4) — validator odmietne nezname roly.
      ROLES = %w[
        side_left side_right bottom top back shelf divider_v divider_h
        front_door drawer_front flap cover_panel false_front rail_front rail_back
        plinth gola_profile
      ].freeze

      PRODUCTION_CLASSES = %w[sheet linear counted reference none].freeze

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
        plan[:hardware].each { |hw| validate_hardware!(hw) }
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
        unless %i[korpus front].include?(pd[:material])
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

      def validate_hardware!(hw)
        raise 'BuildPlan: hardware polozka musi byt Hash.' unless hw.is_a?(Hash)
        owner = hw[:owner_part_key]
        unless owner.nil? || PartKeys.valid?(owner.to_s)
          raise "BuildPlan: hardware ma neplatny owner_part_key '#{owner}'."
        end
        raise 'BuildPlan: hardware ma prazdny generic_type.' if hw[:generic_type].to_s.strip.empty?
        qty = hw[:quantity]
        raise "BuildPlan: hardware #{hw[:generic_type]} ma neplatnu quantity (#{qty.inspect})." unless qty.is_a?(Integer) && qty.positive?
        hw
      end

      def validate_triplet!(key, label, v, positive:)
        ok = v.is_a?(Array) && v.size == 3 && v.all? { |x| x.is_a?(Numeric) } &&
             (!positive || v.all? { |x| x.to_f > 0 })
        raise "BuildPlan: dielec #{key} ma neplatny #{label} (#{v.inspect})." unless ok
      end
    end
  end
end
