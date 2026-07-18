# frozen_string_literal: true
# Noxun Engine - Panel: materialy OZNACENEJ skrinky (korpusovy override dedenia).
# Projektove predvolby sa V0.4.5 D2 PRESUNULI do okna MaterialsDialog
# (ui/materials_dialog.rb) — panel uz projektove selecty nema.
# Cast modulu Panel (reopen) - zdiela ivary cez class << self.
module Noxun
  module Engine
    module Panel
      class << self
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
