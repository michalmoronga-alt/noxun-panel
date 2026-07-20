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
      # (PROJECT_MATERIAL_TARGETS sa V0.4.5 D2 presunuli do MaterialsDialog::TARGETS)

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
          cb(dlg, 'toggle_zones')   { |p| handle_toggle_zones(p) }
          # V0.3 materialy + ABS (materialy TEJTO skrinky; projektove = MaterialsDialog)
          cb(dlg, 'set_cabinet_material') { |p| handle_set_cabinet_material(p) } # korpusovy override
          cb(dlg, 'set_part_material')    { |p| handle_set_part_material(p) }    # per-dielec override
          cb(dlg, 'set_part_edge')        { |p| handle_set_part_edge(p) }        # ABS hrana dielca
          cb(dlg, 'set_part_edges_all')   { |p| handle_set_part_edges_all(p) }   # D-35 olep vsetky 4 hrany (1 undo)
          # V0.4 kovanie: rucny pocet / vypnutie / reset polozky + editor pravidiel
          cb(dlg, 'set_hardware_override') { |p| handle_set_hardware_override(p) }
          cb(dlg, 'open_rules')            { |_p| RulesDialog.show }
          # V0.4.5 D1: omrvinka karty dielca — spat na korpus (oznaci ho v modeli)
          cb(dlg, 'select_cabinet')        { |p| handle_select_cabinet(p) }
          # V0.4.5 D2: satelitne okna (projektove predvolby a sprava sablon mimo panela)
          cb(dlg, 'open_project_materials') { |_p| MaterialsDialog.show }
          cb(dlg, 'open_templates')         { |_p| TemplatesDialog.show }
          cb(dlg, 'save_template_as')       { |p| handle_save_template_as(p) } # D-14 modal
          cb(dlg, 'open_production')        { |_p| ProductionDialog.show }      # V0.5 B
          # V0.5 B relay (Codex B1): panel JS uz flushol edity — vyber vykona Vyroba
          cb(dlg, 'production_do_select')   { |p| ProductionDialog.do_select(p) }
          # V0.5 C relay: export VEPO az PO flushi editov panela (stale data = zla objednavka)
          cb(dlg, 'production_do_export')   { |p| ProductionDialog.do_export(p) }
          # V0.4.7c: samostatna doska — vlozenie + karta (fields/material/ABS hrana)
          cb(dlg, 'insert_board')       { |p| handle_insert_board(p) }
          cb(dlg, 'set_board_fields')   { |p| handle_set_board_fields(p) }
          cb(dlg, 'set_board_material') { |p| handle_set_board_material(p) }
          cb(dlg, 'set_board_edge')     { |p| handle_set_board_edge(p) }
          cb(dlg, 'set_board_edges_all') { |p| handle_set_board_edges_all(p) } # D-35 olep vsetky 4 hrany (1 undo)
          # D-25: merac pouzivania panela — lokalne pocitadla interakcii (len
          # identifikatory prvkov a pocty). Handler chyby NIKDY nepusti von
          # (vlastny rescue bez set_status) — merac musi ostat neviditelny.
          cb(dlg, 'usage_flush')        { |p| handle_usage_flush(p) }
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
Sketchup.require 'noxun_engine/ui/panel/actions_board' # V0.4.7c samostatna doska
Sketchup.require 'noxun_engine/ui/panel/actions_usage' # D-25 merac pouzivania panela
Sketchup.require 'noxun_engine/ui/panel/sync'
Sketchup.require 'noxun_engine/ui/panel/resolvers'
Sketchup.require 'noxun_engine/ui/panel/payloads'
Sketchup.require 'noxun_engine/ui/panel/selection'
