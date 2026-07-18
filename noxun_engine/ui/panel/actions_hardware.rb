# frozen_string_literal: true
# Noxun Engine - Panel: kovanie (V0.4 faza 1) — rucne zasahy do poctov.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # Jeden zasah do kovania oznacenej skrinky. Identita = (owner_part_key,
        # generic_type, rule_id); akcia podla payloadu:
        #   quantity N  -> rucny pocet (pravidlo ostava ako default v rule_quantity)
        #   disabled    -> kategoria sa vypne (polozka zmizne z planu aj supisu)
        #   reset       -> zasah sa odstrani, plati zas pravidlo
        # Zapis + rebuild v jednej operacii (override zije v configu korpusu).
        def handle_set_hardware_override(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus.', true) if cab.nil?

          data = parse(payload)
          gt = data['generic_type'].to_s
          rid = data['rule_id'].to_s
          return set_status('Neznama polozka kovania.', true) if gt.empty? || rid.empty?

          owner = present_str(data['owner_part_key'])
          params = existing_params(cab)
          list = (params['hardware_overrides'].is_a?(Array) ? params['hardware_overrides'] : [])
                 .reject { |ov| ov_match?(ov, owner, gt, rid) }
          if truthy?(data['disabled'])
            list << { 'owner_part_key' => owner, 'generic_type' => gt, 'rule_id' => rid,
                      'disabled' => true }
          elsif data['quantity']
            q = data['quantity'].to_i
            return set_status('Pocet musi byt aspon 1 (alebo polozku vypni).', true) if q < 1
            list << { 'owner_part_key' => owner, 'generic_type' => gt, 'rule_id' => rid,
                      'quantity' => [q, BuildPlan::MAX_HW_QUANTITY].min }
          end
          # reset = len odstranenie zaznamu (list uz je bez neho)

          params['hardware_overrides'] = list
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: kovanie rucne')
            reselect(model, cab)
          end
          status_with_warnings(cab, "Kovanie upravene — #{Store.get(cab, 'cabinet_id')}.")
          push_selected(model)
        end

        def ov_match?(ov, owner, gt, rid)
          return false unless ov.is_a?(Hash)
          ov_owner = present_str(ov['owner_part_key'])
          ov_owner == owner && ov['generic_type'].to_s == gt && ov['rule_id'].to_s == rid
        end
      end
    end
  end
end
