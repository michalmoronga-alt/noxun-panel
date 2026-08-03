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

        # V0.6 D1b: vyber setu kovania NA SKRINKE (override projektovej
        # predvolby). set_id prazdne = spat na predvolbu projektu. Zapis
        # overridu + definicia setu do snapshotu (audit B2) + rebuild =
        # JEDNA operacia (rebuild_many yield).
        def handle_set_hardware_set(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus.', true) if cab.nil?

          data = parse(payload)
          gt = data['generic_type'].to_s
          return set_status('Neznámy typ kovania.', true) unless BuildPlan::GENERIC_TYPES.include?(gt)

          # GH #127 P2: payload nesie identitu RENDROVANEJ skrinky — zmena
          # vyberu pred obsluhou callbacku nesmie prepisat inu skrinku.
          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return set_status('Výber sa medzitým zmenil — panel sa obnovil, skús znova.', true)
          end

          status, = HardwareSets.project_state_status(model)
          if status == :invalid
            return set_status('Sety projektu sú poškodené — obnov ich v Katalógu kovania (Predvoľby projektu).', true)
          end

          sid = present_str(data['set_id'])
          set_def = nil
          if sid
            # H1a (audit BLOCKER 4): definiciu vybera resolver — pre set_id,
            # ktore projekt uz pouziva, vyhrava SNAPSHOT (podla neho sa
            # nakupuje), global je len fallback pre nereferencovane.
            cand = HardwareSets.resolve_set_def(model, sid)
            set_def = cand if cand && cand['generic_type'] == gt
            return set_status('Set sa nenašiel — otvor Katalóg kovania a skús znova.', true) if set_def.nil?
          end

          params = existing_params(cab)
          map = params['hardware_sets'].is_a?(Hash) ? params['hardware_sets'] : {}
          sid ? map[gt] = sid : map.delete(gt)
          params['hardware_sets'] = map
          suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, [[cab, params]], op_name: 'NOXUN: set kovania') do
              HardwareSets.add_project_set!(model, set_def) if set_def
            end
            reselect(model, cab)
          end
          label = HardwareRules.label_for(gt)
          status_with_warnings(cab, sid ? "#{label}: set „#{set_def['name']}“ pre túto skrinku." : "#{label}: platí predvoľba projektu.")
          push_selected(model)
        end
      end
    end
  end
end
