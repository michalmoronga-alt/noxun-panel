# frozen_string_literal: true
# Noxun Engine - Panel: materialy (projektovy default, korpusovy override).
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- akcie: materialy + ABS (V0.3) ----------------------------------

        # Projektovy default materialu (koren dedenia, standard 7.2). Vsetky korpusy,
        # ktore dany material dedia, sa prepocitaju atomicky v jednej Undo operacii.
        def handle_set_project_material(payload)
          model = Sketchup.active_model
          data = parse(payload)
          key = data['key'].to_s
          value = present_str(data['value'])
          target = PROJECT_MATERIAL_TARGETS[key]
          return set_status('Neznámy projektový materiál.', true) unless target && value

          sheet = Materials.sheet(value)
          return set_status('Vybraný materiál sa nenašiel v katalógu.', true) unless sheet

          cfg_key, role, thickness_key = target
          selected = find_cabinet(model)
          affected = all_cabinets(model).select do |cabinet|
            present_str(existing_params(cabinet)[cfg_key]).nil?
          end

          incompatible = affected.select do |cabinet|
            params = existing_params(cabinet)
            want = thickness_key ? params[thickness_key].to_f : Fronts::FRONT_THICKNESS
            !CabinetBuilder.thickness_ok_for?(role, want, sheet['thickness'].to_f)
          end
          unless incompatible.empty?
            ids = incompatible.map { |cabinet| Store.get(cabinet, 'cabinet_id') }.join(', ')
            return set_status("Materiál #{value} má nekompatibilnú hrúbku pre: #{ids}.", true)
          end

          jobs = affected.map { |cabinet| [cabinet, existing_params(cabinet)] }
          suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: projektovy material') do
              raise 'Projektový materiál sa nepodarilo uložiť.' unless Materials.set_project_default(model, key, value)
            end
            reselect(model, selected) if selected && selected.valid?
          end
          set_status("Projektový materiál nastavený — prepočítaných #{affected.size} skriniek.")
          push_selected(model)
        end

        # Korpusovy material (override projektu). which: body/front/back; prazdna hodnota = dedi.
        def handle_set_cabinet_material(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus.', true) if cab.nil?
          data = parse(payload)
          key = { 'body' => 'material_id', 'front' => 'front_material_id', 'back' => 'back_material_id' }[data['which'].to_s]
          return set_status('Neznamy material korpusu.', true) unless key
          value = present_str(data['value'])
          params = existing_params(cab)
          params[key] = value
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: material korpusu')
            reselect(model, cab)
          end
          set_status("Materiál korpusu #{value ? 'nastavený' : 'dedí z projektu'}.")
          push_selected(model)
        end

      end
    end
  end
end
