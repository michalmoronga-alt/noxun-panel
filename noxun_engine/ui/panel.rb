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
        # D-52a (B2): restart latch. Po aktualizacii lezia na disku NOVE
        # `ui/*.html` a `ui/js/*.js`, ale v pamati bezi STARY Ruby — okno by sa
        # otvorilo s nezhodnymi callbackmi. Preto sa az do restartu neotvara.
        def show
          return nil if Engine.update_restart_pending?
          # D-52b2 (#278 kolo 3, P1): pocas BEZIACEJ aktualizacie tiez nie —
          # CEF by drzal subory z `ui/` a commit by zlyhal.
          return nil if Engine.update_in_progress?

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

        # ST-1a (Š3 ceruzka): „uprav dielec v Inspectore" — po vybere v modeli
        # sa panel zdvihne dopredu, aby sa dal dielec hned upravit. Panel sa TU
        # NEOTVARA (o tom rozhoduje volajuci cez `dialog_alive?`) a do modelu sa
        # nezapisuje nic.
        def bring_to_front
          return false unless @dialog && @dialog.visible?

          @dialog.bring_to_front
          true
        rescue StandardError => e
          Engine.log_error(e, 'Panel.bring_to_front')
          false
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

        # D-52b (bariéra pred swapom): `true` AZ VTEDY, ked dobehol
        # `set_on_closed` — teda ked uz okno neexistuje. `dialog_alive?`
        # na to NESTACI: hovori o VIDITELNOSTI, kym CEF moze este drzat
        # otvorene subory z `ui/` a rename priecinka by na Windows zlyhal.
        def dialog_closed?
          @dialog.nil?
        end

        # UI-02: toolbar tlacidlo „Vlozit" — panel BEZ vyberu ukazuje vkladaciu
        # kartu, takze staci otvorit panel a zhodit vyber. Ziadna operacia a
        # ziadny zapis do modelu (lekcia D-103: prazdny vyber sa vycisti pod
        # suspend guardom, aby observer nespustil vlastny refresh, a refresh
        # panela ide s `dedup: false` — dedup MENI model).
        # D-52a (B2): guard je TU, nie az v `show` — vkladanie by inak najprv
        # zhodilo vyber v modeli a az potom narazilo na zavrety panel.
        def show_insert
          return nil if Engine.update_restart_pending?
          return nil if Engine.update_in_progress?

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
            # D-89a: zvyraznenie hrany zije len s otvorenou kartou — po zatvoreni
            # panela sa overlay odpoji, aby v modeli neostala visiet ploska.
            HoverEdge.release if defined?(HoverEdge)
            # GHOST (V1-04): ghost visiaci na kurzore patri vkladacej karte —
            # so zatvorenym Inspectorom nema kto vklad dokoncit ani zrusit.
            # Cancel = 0 mutacii modelu, 0 krokov Spat.
            GhostTool.cancel_session('zatvorený Inspector') if defined?(GhostTool)
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
          # D-27: viditelnost NOXUN tagov v modeli — okno tagov v raile AJ
          # checkbox „Zobraziť zóny (ghost)" (kluc `zony`). Callback `toggle_zones`
          # tym ZANIKOL: posielal len holy retazec bez identity dokumentu, takze
          # oneskoreny klik vedel prepnut tag v cudzom modeli.
          cb(dlg, 'nx_tag_visible') { |p| handle_tag_visible(p) }
          # V0.3 materialy + ABS (materialy TEJTO skrinky; projektove = MaterialsDialog)
          cb(dlg, 'set_cabinet_material') { |p| handle_set_cabinet_material(p) } # korpusovy override
          cb(dlg, 'set_part_material')    { |p| handle_set_part_material(p) }    # per-dielec override
          cb(dlg, 'set_part_edge')        { |p| handle_set_part_edge(p) }        # ABS hrana dielca
          cb(dlg, 'set_part_edges_all')   { |p| handle_set_part_edges_all(p) }   # D-35 olep vsetky 4 hrany (1 undo)
          cb(dlg, 'set_part_grain')       { |p| handle_set_part_grain(p) }       # K1/D-108 smer dekoru dielca (1 undo)
          # V0.4 kovanie: rucny pocet / vypnutie / reset polozky + editor pravidiel
          cb(dlg, 'set_hardware_override') { |p| handle_set_hardware_override(p) }
          cb(dlg, 'set_hardware_set')      { |p| handle_set_hardware_set(p) } # V0.6 D1b: set na skrinke
          # ŠT-3b-1: `open_rules` ZANIKOL spolu s oknom — tlacidlo panela ide
          # deep-linkom `openStudio('rules')` (vzor „Materiály projektu" zo ŠT-2b).
          # ŠT-3a-2: `open_hardware_catalog` ZANIKOL spolu s oknom — tlacidlo
          # panela ide deep-linkom `openStudio('hw')` (vzor „Materiály
          # projektu" zo ŠT-2b).
          # V0.4.5 D1: omrvinka karty dielca — spat na korpus (oznaci ho v modeli).
          # UI-B1: tou istou cestou ide aj krizik docasnej polozky raily (dielec).
          cb(dlg, 'select_cabinet')        { |p| handle_select_cabinet(p) }
          # UI-B1: krizik docasnej polozky raily pri DOSKE — vycistenie vyberu.
          # Ziadna operacia, ziadny zapis do modelu (vzor Panel.show_insert).
          cb(dlg, 'clear_selection')       { |p| handle_clear_selection(p) }
          # UI-B1 (audit A2): ABS kontrola hran z raily Inspectora. Vola TU ISTU
          # zdielanu logiku ako toolbar aj lista sekcie Kontrola v Studiu (Engine.toggle_edge_check)
          # — ziadny duplikat a ziadny zapis do modelu (lekcia D-103).
          cb(dlg, 'nx_edge_toggle')        { |p| handle_edge_toggle(p) }
          # v0.7.28: 3-stavove nastavenie kontroly hran z ROHU ABS tlacidla.
          # To iste nastavenie, ktore ma lista sekcie Kontrola v Studiu — ide
          # ZDIELANOU cestou Engine.set_edge_check_option (jeden zapis do
          # %APPDATA%, jeden broadcast do oboch okien). Do modelu sa nezapisuje
          # nic a nevznika krok Spat.
          cb(dlg, 'nx_edge_option')        { |p| handle_edge_option(p) }
          # Otvorenie rohoveho nastavenia zavrie to iste okno v Studiu (a
          # naopak) — na obrazovke nikdy nestoja dve kopie tych istych
          # prepinacov. Cisto zobrazovacie: ziadny stav, ziadny zapis.
          cb(dlg, 'nx_edge_menu_open')     { |_p| Engine.close_edge_menu(:panel) }
          # K2/D-87: KONTROLA KRESBY z raily Inspectora. Vola TU ISTU zdielanu
          # logiku ako lista sekcie Kontrola v Studiu (Engine.toggle_grain_check) — jeden zdroj
          # stavu, dva vstupne body; ziadny zapis do modelu.
          cb(dlg, 'nx_grain_toggle')       { |p| handle_grain_toggle(p) }
          # KOV-A2b: SMER OTVARANIA z raily Inspectora. Ten isty vzor —
          # zdielana Engine.toggle_direction_check, jeden zdroj stavu, dva
          # vstupne body; ziadny zapis do modelu.
          cb(dlg, 'nx_direction_toggle')   { |p| handle_direction_toggle(p) }
          # D-89a: hover nad hranou v karte dielca rozsvieti tu istu hranu v
          # MODELI. Overlay NAD modelom — ziadna operacia, ziadny krok Spat.
          cb(dlg, 'nx_hover_edge')         { |p| handle_hover_edge(p) }
          # UI-B2 (N7): kamera v spodnom pase nahladu — zarovna POHLAD na
          # oznacenu skrinku. Kamera nie su data modelu, takze ziadna operacia,
          # ziadny zapis a ziadny krok Spat (lekcia D-103).
          cb(dlg, 'nx_camera_focus')       { |p| handle_camera_focus(p) }
          # UI-B3 (N13): klik na „Dielcov" v informacnom stlpci — oznaci vyrobne
          # dielce TEJTO skrinky v modeli. CISTE CITANIE + zmena vyberu pod
          # suspend guardom (vzor ProductionCore.do_select) — ziadna operacia,
          # ziadny zapis, ziadny krok Spat.
          cb(dlg, 'nx_select_parts')       { |p| handle_select_parts(p) }
          # UI-C4: klik na hlavicku boxu vlastnika v sekcii Kovanie (a na znacku
          # kovania v nahlade) — oznaci vlastnika polozky v modeli. CISTE
          # CITANIE + zmena vyberu; panel po nej ZAMERNE ostava v Kovani.
          cb(dlg, 'nx_select_hw_owner')    { |p| handle_select_hw_owner(p) }
          # UI-D1: karta dielca — „Označiť v modeli" (ciste citanie + zmena
          # vyberu, ziadny undo krok) a „Použiť na podobné…" (zivy pocet +
          # zapis olepu do viacerych dielcov v JEDNEJ operacii = 1 krok Spat).
          cb(dlg, 'nx_select_part')         { |p| handle_select_part(p) }
          cb(dlg, 'nx_similar_parts_count') { |p| handle_similar_parts_count(p) }
          cb(dlg, 'nx_apply_edges_similar') { |p| handle_apply_edges_similar(p) }
          # D-100: premenovanie skrinky (inline edit nazvu v hlavicke panela)
          cb(dlg, 'rename_cabinet')        { |p| handle_rename_cabinet(p) }
          # UI-B3 (koliesko = Nastavenia Inspectora): tema UI a rozmerove rady.
          # Obe su nastavenie POCITACA (%APPDATA%), nie zakazky — do modelu sa
          # nezapisuje nic.
          cb(dlg, 'nx_set_ui_theme')       { |p| handle_set_ui_theme(p) }
          cb(dlg, 'nx_set_dim_series')     { |p| handle_set_dim_series(p) }
          # V0.4.5 D2: satelitne okna (sprava sablon mimo panela). ŠT-2b:
          # `open_project_materials` ZANIKLO spolu s oknom Materialy — tlacidlo
          # panela ide odteraz bezným deep-linkom `openStudio('mat')`, teda
          # cestou `open_studio` nizsie (jeden whitelist sekcii, jedna cesta).
          cb(dlg, 'save_template_as')       { |p| handle_save_template_as(p) } # D-14 modal
          # ŠT-1c PR B3: pat relayov okna Vyroba (`open_production`,
          # `production_do_select/_export/_hw_csv/_budget/_cp`) tu ZANIKLO
          # spolu s oknom. Ten isty flush handshake robia relaye Studia nizsie
          # — kazde okno ma vlastny kanal aj vlastny generacny token.
          # ST-1a: okno STUDIO. Deep-link nesie meno sekcie (+ volitelnu kotvu
          # hladania — N13 posiela ID skrinky); whitelist je v
          # StudioDialog::SECTIONS, panel posiela iba meno.
          cb(dlg, 'open_studio')            { |p| open_studio(p) }
          # ST-1a relay (audit #3): Studio ma VLASTNY kanal — inak by odpoved
          # prisla do ineho okna a jeho `gen` by klik odmietol.
          cb(dlg, 'studio_do_select')       { |p| StudioDialog.do_select(p) }
          cb(dlg, 'studio_do_export')       { |p| StudioDialog.do_export(p) }
          # ŠT-1c PR A: CSV nakupneho zoznamu kovania zo sekcie Nakup — rovnaky
          # flush handshake ako VEPO, vlastnym kanalom Studia.
          cb(dlg, 'studio_do_hw_csv')       { |p| StudioDialog.do_hw_csv(p) }
          # ŠT-1c PR B1: XLSX rozpoctu a zakaznicka cenova ponuka zo sekcie
          # Rozpocet — ten isty flush handshake, vlastnym kanalom Studia.
          cb(dlg, 'studio_do_budget_xlsx')  { |p| StudioDialog.do_budget_xlsx(p) }
          cb(dlg, 'studio_do_cp_xlsx')      { |p| StudioDialog.do_cp_xlsx(p) }
          # GHOST-FB4: pole locknutej vysky v Ghost pasiku (mm). Meni stav
          # BEZIACEJ session, nie model — guard identity dokumentu je preto
          # rovnaky ako pri zapisovych handleroch (R-02).
          cb(dlg, 'ghost_lock_z')       { |p| handle_ghost_lock_z(p) }
          # V0.4.7c: samostatna doska — vlozenie + karta (fields/material/ABS hrana)
          cb(dlg, 'insert_board')       { |p| handle_insert_board(p) }
          cb(dlg, 'set_board_fields')   { |p| handle_set_board_fields(p) }
          cb(dlg, 'set_board_material') { |p| handle_set_board_material(p) }
          cb(dlg, 'set_board_orientation') { |p| handle_set_board_orientation(p) } # UI-C1c orientacia dosky
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
          # UI-D2: PULL nahladu sablony (kind, name, rev) -> data URI. Ziada sa
          # RAZ na revíziu — data URI nemoze cestovat v kazdom push_templates.
          cb(dlg, 'nx_template_preview') { |p| push_template_preview(p) }
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

        # ST-1a: otvorenie okna Studio z panela (rail „Štúdio", N13 „Materiál",
        # warnpanel). Payload nesie meno sekcie a volitelnu kotvu hladania —
        # o platnosti rozhoduje `StudioDialog::SECTIONS`, nie panel.
        def open_studio(payload)
          data = studio_link_of(payload)
          StudioDialog.show(open_section: data[:section], anchor: data[:anchor])
        end

        # Wrapper: begin/rescue + slovensky status pri chybe; nikdy 'return' v bloku (pouzi next).
        # D-52a (Codex #277 kolo 4, P1): latch strazi aj UZ OTVORENE okno.
        # Guard v `show` chrani len OTVARANIE — okno, ktore bezalo v case
        # commitu, by inak starymi handlermi mutovalo model nad NOVYM balikom
        # (a reload stranky by sparoval nove HTML so starymi callbackmi).
        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            next if Engine.update_locked?(:panel)

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
Sketchup.require 'noxun_engine/ui/panel/actions_settings' # UI-B3 koliesko: tema UI + rozmerove rady
Sketchup.require 'noxun_engine/ui/panel/sync'
Sketchup.require 'noxun_engine/ui/panel/resolvers'
Sketchup.require 'noxun_engine/ui/panel/payloads'
Sketchup.require 'noxun_engine/ui/panel/selection'
