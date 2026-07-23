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
        # D-41 PR C: pred rebuildom sa preladia RUCNE ABS overridy dielcov, ktore boli
        # zladene so starym efektivnym dekorom (centralny remap — audit FIX 5).
        def handle_set_cabinet_material(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus.', true) if cab.nil?
          data = parse(payload)
          key = { 'body' => 'material_id', 'front' => 'front_material_id', 'back' => 'back_material_id' }[data['which'].to_s]
          return set_status('Neznamy material korpusu.', true) unless key
          value = present_str(data['value'])
          params = existing_params(cab)
          old_eff = effective_materials(model, params)
          params[key] = value
          new_eff = effective_materials(model, params)
          remap = CabinetBuilder.remap_part_edge_overrides!(params, old_eff, new_eff)
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: material korpusu')
            reselect(model, cab)
          end
          set_status("Materiál korpusu #{value ? 'nastavený' : 'dedí z projektu'}.#{remap_note(remap)}")
          push_selected(model)
        end

        # Efektivne materialy korpusu po dedeni projekt->korpus (vstup pre remap).
        def effective_materials(model, params)
          defaults = Materials.project_defaults(model)
          {
            'body'  => present_str(params['material_id'])       || defaults['default_material_id'],
            'front' => present_str(params['front_material_id']) || defaults['default_front_material_id'],
            'back'  => present_str(params['back_material_id'])  || defaults['default_back_material_id']
          }
        end

        # Kratke slovenske hlasenie o preladeni ABS (prazdne ak sa nic nemenilo).
        def remap_note(remap)
          return '' unless remap.is_a?(Hash) && remap['changed'].to_i.positive?
          note = " ABS hrany prevedené na nový dekor (#{remap['changed']}× dielec)."
          note += " Bez náhrady: #{remap['lost'].join(', ')}." unless remap['lost'].empty?
          note
        end

      end
    end
  end
end
