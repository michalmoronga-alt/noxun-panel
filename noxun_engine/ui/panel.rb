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

        # UI-02: toolbar tlacidlo loga je PREPINAC — druhy klik panel zavrie.
        # Zatvorenie ide cez `set_on_closed` (detach observera + @dialog = nil),
        # takze stav panela ostava konzistentny s beznym zavretim krizikom.
        def hide
          return false unless @dialog

          @dialog.close
          true
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hide')
          false
        end

        # UI-02: toolbar tlacidlo „Vlozit" — panel BEZ vyberu ukazuje vkladaciu
        # kartu, takze staci otvorit panel a zhodit vyber. Ziadna operacia a
        # ziadny zapis do modelu (lekcia D-103: prazdny vyber sa vycisti pod
        # suspend guardom, aby observer nespustil vlastny refresh, a refresh
        # panela ide s `dedup: false` — dedup MENI model).
        def show_insert
          model = Sketchup.active_model
          suspend_selection_sync { model.selection.clear } if model
          dlg = show
          push_selected(model, dedup: false) if model && dialog_alive?
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'Panel.show_insert')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            # D-77 / D-51 (UI-B1, audit A7): JEDNA PRAVDA sirky Inspectora je
            # OBSAHOVY viewport 470 px (rail 44 + karta). Rozmery tu su VONKAJSIE
            # (ramik + titulok okna), preto 470 + ~16 px ramika = 486; vyska
            # 810 obsahu + ~40 px titulku = 850. Platia LEN pri PRVOM otvoreni —
            # zapamatane male okno dorovna nx_fit podla NX_FIT_MIN v panel.html
            # (tam su OBSAHOVE hodnoty; tabulka je v docs/UI_DIZAJN.md).
            width: 486,
            height: 850,
            min_width: 486,
            min_height: 600,
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
          Engine.register_dialog_fit(dlg, 'panel') # D-77: zapamatane male okno sa dorovna
          cb(dlg, 'ready')          { |_p| push_init }
          cb(dlg, 'insert_cabinet') { |p| handle_insert(p) }
          cb(dlg, 'insert_copy')    { |p| handle_insert_copy(p) } # B3: presna serverova kopia oznacenej skrinky
          cb(dlg, 'set_insert_locks') { |p| handle_set_insert_locks(p) } # D-39: zamky vkladacej karty (Ruby pamat)
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
          cb(dlg, 'set_hardware_set')      { |p| handle_set_hardware_set(p) } # V0.6 D1b: set na skrinke
          cb(dlg, 'open_rules')            { |_p| RulesDialog.show }
          # D-91: Katalog kovania priamo z hlavicky panela (docasne miesto "za
          # Vyrobou" — finalny domov rozhodne UI 2.0). Len otvorenie satelitu.
          cb(dlg, 'open_hardware_catalog') { |_p| HardwareCatalogDialog.show }
          # V0.4.5 D1: omrvinka karty dielca — spat na korpus (oznaci ho v modeli).
          # UI-B1: tou istou cestou ide aj krizik docasnej polozky raily (dielec).
          cb(dlg, 'select_cabinet')        { |p| handle_select_cabinet(p) }
          # UI-B1: krizik docasnej polozky raily pri DOSKE — vycistenie vyberu.
          # Ziadna operacia, ziadny zapis do modelu (vzor Panel.show_insert).
          cb(dlg, 'clear_selection')       { |_p| handle_clear_selection }
          # UI-B1 (audit A2): ABS kontrola hran z raily Inspectora. Vola TU ISTU
          # zdielanu logiku ako toolbar aj okno Vyroba (Engine.toggle_edge_check)
          # — ziadny duplikat a ziadny zapis do modelu (lekcia D-103).
          cb(dlg, 'nx_edge_toggle')        { |_p| handle_edge_toggle }
          # D-100: premenovanie skrinky (inline edit nazvu v hlavicke panela)
          cb(dlg, 'rename_cabinet')        { |p| handle_rename_cabinet(p) }
          # V0.4.5 D2: satelitne okna (projektove predvolby a sprava sablon mimo panela)
          cb(dlg, 'open_project_materials') { |_p| MaterialsDialog.show }
          cb(dlg, 'open_templates')         { |_p| TemplatesDialog.show }
          cb(dlg, 'save_template_as')       { |p| handle_save_template_as(p) } # D-14 modal
          cb(dlg, 'open_production')        { |_p| ProductionDialog.show }      # V0.5 B
          # V0.5 B relay (Codex B1): panel JS uz flushol edity — vyber vykona Vyroba
          cb(dlg, 'production_do_select')   { |p| ProductionDialog.do_select(p) }
          # V0.5 C relay: export VEPO az PO flushi editov panela (stale data = zla objednavka)
          cb(dlg, 'production_do_export')   { |p| ProductionDialog.do_export(p) }
          # V0.6 D1b relay (GH #127 P1): CSV kovania — rovnaky flush handshake
          cb(dlg, 'production_do_hw_csv')   { |p| ProductionDialog.do_hw_csv(p) }
          # V0.6 E-b relay: XLSX rozpoctu — rovnaky flush handshake ako VEPO/CSV
          cb(dlg, 'production_do_budget')   { |p| ProductionDialog.do_budget_xlsx(p) }
          # V0.6 E-b2 relay: zakaznicka cenova ponuka (cenova tabulka + specifikacia)
          cb(dlg, 'production_do_cp')       { |p| ProductionDialog.do_cp_xlsx(p) }
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
          # D-85 (Codex #167 P2): combobox si pri OTVORENI vypyta cerstvy zoznam
          # materialov a pasok pouzitych v zakazke (sekcia „Použité v projekte").
          # PULL, nie push: zoznam sa meni pri kazdom zapise materialu, ale cita
          # sa len pri otvoreni ponuky — plny scan modelu preto nepatri do
          # push_selected (bezi pri kazdom kliku vo vybere). CISTE CITANIE.
          cb(dlg, 'nx_used_ids')        { |_p| push_used_ids }
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
