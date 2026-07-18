# frozen_string_literal: true
# Noxun Engine — panel (HtmlDialog controller), V0.3.4 split: logika v ui/panel/*.
# Tento subor: konstanty, otvorenie dialogu, CENTRALNY zoznam callbackov, cb wrapper.
# Referencia dialogu v modulovej premennej (GC); callbacky pred show;
# Ruby->JS len cez to_json; v callbackoch 'next' (nie 'return'); begin/rescue s logom.
require 'json'

module Noxun
  module Engine
    module Panel
      DLG_KEY = 'noxun_engine_panel'
      PROJECT_MATERIAL_TARGETS = {
        'default_material_id' => ['material_id', 'side_left', 'thickness'],
        'default_front_material_id' => ['front_material_id', 'front_door', nil],
        'default_back_material_id' => ['back_material_id', 'back', 'back_thickness']
      }.freeze

      class << self
        # --- otvorenie ------------------------------------------------------
        def show
          dlg = ensure_dialog
          if dlg.visible?
            dlg.bring_to_front
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'Panel.show')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 400,
            height: 640,
            min_width: 360,
            min_height: 480,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'panel.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed do
            detach_observer
            @dialog = nil
          end
          attach_observer
          @dialog
        end

        # --- callbacky (JS -> Ruby) -----------------------------------------
        def register_callbacks(dlg)
          cb(dlg, 'ready')          { |_p| push_init }
          cb(dlg, 'insert_cabinet') { |p| handle_insert(p) }
          cb(dlg, 'apply_all')      { |p| handle_apply_all(p) }   # V0.2c auto-apply (konstrukcia + cela)
          cb(dlg, 'apply_changes')  { |p| handle_apply(p) }       # spatna kompat
          cb(dlg, 'apply_fronts')   { |p| handle_apply_fronts(p) }
          cb(dlg, 'split_zone')     { |p| handle_split_zone(p) }
          cb(dlg, 'set_zone_shelves') { |p| handle_set_zone_shelves(p) }
          cb(dlg, 'set_zone_field') { |p| handle_set_zone_field(p) } # V0.2c split lock (rozmer pola)
          cb(dlg, 'select_zone')    { |p| handle_select_zone(p) }    # V0.2c obojsmerna sync nahladu
          cb(dlg, 'clean_zone')     { |p| handle_clean_zone(p) }
          cb(dlg, 'save_template')  { |p| handle_save_template(p) }
          cb(dlg, 'delete_template') { |p| handle_delete_template(p) }
          cb(dlg, 'apply_template') { |p| handle_apply_template(p) }
          cb(dlg, 'toggle_zones')   { |p| handle_toggle_zones(p) }
          # V0.3 materialy + ABS
          cb(dlg, 'set_project_material') { |p| handle_set_project_material(p) } # projektovy default
          cb(dlg, 'set_cabinet_material') { |p| handle_set_cabinet_material(p) } # korpusovy override
          cb(dlg, 'set_part_material')    { |p| handle_set_part_material(p) }    # per-dielec override
          cb(dlg, 'set_part_edge')        { |p| handle_set_part_edge(p) }        # ABS hrana dielca
          # V0.4 kovanie: rucny pocet / vypnutie / reset polozky + editor pravidiel
          cb(dlg, 'set_hardware_override') { |p| handle_set_hardware_override(p) }
          cb(dlg, 'open_rules')            { |_p| RulesDialog.show }
          # Diagnostika: JS chyby z HtmlDialogu (window.onerror) -> Engine.log. Priamo, NIE cez cb —
          # aby pripadna chyba v logovani nespustila set_status (dalsi execute_script) a slucku.
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS: #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'js_error')
            end
            next
          end
        end

        # Wrapper: begin/rescue + slovensky status pri chybe; nikdy 'return' v bloku (pouzi next).
        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

      end
    end
  end
end

# Casti panela - reopenuju module Panel (poradie nie je vyznamove; handlery sa volaju az runtime).
Sketchup.require 'noxun_engine/ui/panel/actions_cabinet'
Sketchup.require 'noxun_engine/ui/panel/actions_zones'
Sketchup.require 'noxun_engine/ui/panel/actions_templates'
Sketchup.require 'noxun_engine/ui/panel/actions_materials'
Sketchup.require 'noxun_engine/ui/panel/actions_parts'
Sketchup.require 'noxun_engine/ui/panel/actions_hardware'
Sketchup.require 'noxun_engine/ui/panel/sync'
Sketchup.require 'noxun_engine/ui/panel/resolvers'
Sketchup.require 'noxun_engine/ui/panel/payloads'
Sketchup.require 'noxun_engine/ui/panel/selection'
