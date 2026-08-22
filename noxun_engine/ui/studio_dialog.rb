# frozen_string_literal: true
# Noxun Engine — ST-1a: okno STUDIO (skelet + sekcia Kusovnik).
#
# Studio je cielove JEDNO okno zakazky (kontrakt UI 2.0, sekcia ŠTÚDIO KONCEPT):
# navigacia vlavo, obsah sekcie vpravo. V davke ST-1a zije PRVA sekcia —
# KUSOVNIK (Š1–Š6) s pohladmi Dielce · Platne · ABS; ostatne polozky navigacie
# su PREMOSTENIA do dnesnych okien (audit #2), aby sa nikde neobjavilo mrtve
# tlacidlo bez vysvetlenia.
#
# Okno Vyroba, z ktoreho sa obsah stahoval, ZANIKLO v ŠT-1c PR B3 — Studio je
# odvtedy JEDINE okno vystupov zakazky. Co z toho vztahu ostalo:
#   - CISLA pocita zdielane jadro `ProductionCore` (jeden vypocet pre okno,
#     rail Inspectora aj exporty; druha kopia by sa casom rozisla a rozdiel by
#     sa ukazal az na vyrobnom vystupe),
#   - KANAL je vlastny (audit #3) — vlastny `@generation`, vlastny relay cez
#     panel (`NX.studioRelay*` -> `studio_do_select` / `studio_do_export`),
#     takze cudzi push nezhodi guard tohto okna,
#   - Studio do modelu ZAPISUJE JEDINE cez sekciu Rozpocet (1 mutacia = 1 krok
#     Spat); klik iba vybera entity (pod `Panel.suspend_selection_sync`,
#     refresh panela s `dedup: false`) a nazov projektu je nastavenie POCITACA
#     v %APPDATA%, nie zakazky.
#
# ST-1a: zdielane ciste jadro nacitava loader (main.rb) EST PRED tymto suborom;
# headless pure testy si vsak `ui/studio_dialog.rb` requiruju samostatne —
# preto poistka nizsie.
require File.expand_path('production_core', __dir__) unless defined?(Noxun::Engine::ProductionCore)

module Noxun
  module Engine
    module StudioDialog
      DLG_KEY = 'noxun_engine_studio'

      # ZAVAZNY whitelist sekcii Studia. ŠT-1a priniesla Kusovnik, ŠT-1b
      # KONTROLU (`ctrl`), ŠT-1c PR A NAKUP KOVANIA (`buy`), ŠT-1c PR B1
      # ROZPOCET (`budget`) a PR B2 CENOVU PONUKU (`offer`). JS zrkadla
      # (`studio.js`, `NXShell.STUDIO_SECTIONS`) su pohodlie, nie ochrana
      # (zhodu strazi guard test): autoritou je VZDY Ruby.
      SECTIONS = %w[bom ctrl buy budget offer].freeze

      # ŠT-1c PR B3: `PRODUCTION_BRIDGES` (premostenia do TABOV okna Vyroba)
      # ZANIKLI spolu s oknom — kusovnik, kontrola, nakup kovania, rozpocet aj
      # cenova ponuka su SEKCIAMI tohto okna, takze niet kam premostovat.

      # Premostenia do satelitnych okien (KATALOGY + NASTAVENIA). Hodnota je
      # meno modulu — volat sa smie LEN to, co je TU (klient posiela iba kluc).
      WINDOW_BRIDGES = {
        'mat' => 'MaterialsDialog', 'hw' => 'HardwareCatalogDialog',
        'rules' => 'RulesDialog', 'tpl' => 'TemplatesDialog',
        'sup' => 'SupplierSettingsDialog', 'bset' => 'SupplierSettingsDialog'
      }.freeze

      # Slovenske hlasky premosteni — texty sklada SERVER (jedna autorita).
      BRIDGE_STATUS = {
        'mat' => 'Otváram okno Materiály (presun do Štúdia príde v dávke ŠT-2).',
        'hw' => 'Otváram okno Katalóg kovania (presun do Štúdia príde v dávke ŠT-3).',
        'rules' => 'Otváram okno Pravidlá kovania (presun do Štúdia príde v dávke ŠT-3).',
        'tpl' => 'Otváram okno Šablóny (presun do Štúdia príde v dávke ŠT-3).',
        # Poctivo: „Dodávateľ / Demos" nema DNES vlastne okno. Sadzby dodavatela
        # ziju v okne Nastavenia rozpoctu, vazba na Demos v okne Materialy —
        # spoja sa az v Studiu (Š19). Status to musi povedat, inak sa otvori
        # okno s inym nadpisom a pouzivatel si mysli, ze klikol zle.
        'sup' => 'Otváram okno Nastavenia rozpočtu — väzba na Demos je zatiaľ v okne Materiály (presun v ŠT-2).',
        # ŠT-1c PR B1 (#20): to iste okno otvara aj ⚙ v liste sekcie Rozpocet —
        # kontextova skratka k sadzbam, ktore rozpocet POCITAJU. Text to musi
        # povedat, inak vyzeraju ako dve rozne nastavenia.
        'bset' => 'Otváram Nastavenia rozpočtu — sadzby, režimy a prahy platia pre celý ' \
                  'rozpočet (presun do Štúdia príde v dávke ŠT-4).',
        'about' => 'O plugine nájdeš v koliesku Inspectora — otváram Inspector.'
      }.freeze

      class << self
        # `open_section` = deep-link (rail Štúdio, toolbar, N13 „Materiál").
        # `anchor` predvyplni hladanie sekcie (N13 posiela ID skrinky, audit #12).
        #
        # Sekcia sa NEPOSIELA hned — okno po `show` este nemusi mat nacitany
        # HTML, takze `execute_script` by prisiel do prazdna. Odklada sa a
        # spotrebuje ju NAJBLIZSI `push_state` (pri novom okne ho vyvola
        # `ready`, pri uz otvorenom ho volame priamo tu).
        def show(open_section: nil, anchor: nil)
          @pending_section = SECTIONS.include?(open_section.to_s) ? open_section.to_s : nil
          @pending_anchor = @pending_section ? anchor.to_s.strip : nil
          @pending_anchor = nil if @pending_anchor.to_s.empty?
          dlg = ensure_dialog
          # K2/D-87 (audit #14): zapamataný prepínač „Smer kresby" (%APPDATA%,
          # nastavenie počítača) sa obnoví PRED prvým push_state — inak by lišta
          # sekcie hlásila vypnuté a v modeli by sa kreslilo. Do ŠT-1b to robilo
          # okno Výroba; odkedy je prepínač tu, musí to robiť aj toto okno.
          restore_grain_check
          if dlg.visible?
            dlg.bring_to_front
            push_state
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.show')
        end

        def dialog_alive?
          !@dialog.nil? && @dialog.visible?
        rescue StandardError
          false
        end

        # K2/D-87: obnova zapamataneho prepinaca kresby smeru. Chranene vlastnym
        # blokom — zlyhanie NESMIE zabranit otvoreniu okna.
        def restore_grain_check
          return unless defined?(GrainCheck)

          GrainCheck.restore!(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.restore_grain_check')
        end

        # Bezpecny refresh — volaju ho editor materialov, nastavenia, katalog
        # kovania aj prepocet cien (audit #10: Studio musi byt vo VSETKYCH
        # refresh cestach, inak by drzalo stare cisla).
        def refresh_if_open
          return unless @dialog && @dialog.visible?

          push_state
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.refresh_if_open')
        end

        # EngineAppObserver: prepnutie/otvorenie modelu = nove data + NOVA
        # generacia (stary DOM klik sa odmietne genom, aj keby ID sedeli).
        def on_model_changed(_model)
          return unless @dialog && @dialog.visible?

          push_state
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.on_model_changed')
        end

        # --- relay z panela (audit #3) ---------------------------------------
        # Panel uz flushol rozpisane edity — az potom sa vybera/exportuje.
        # Telo je v ZDIELANOM jadre (`ProductionCore`), okno odovzdava LEN svoj
        # generacny token, svoj status a svoj refresh.

        def do_select(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_select(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end

        def do_export(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_export(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end

        # ŠT-1c PR A (Š7): CSV nakupneho zoznamu kovania z listy sekcie Nakup.
        # Telo je v `ProductionCore` (to iste, ake volal zaniknuty tab Kovanie)
        # — okno odovzdava LEN svoj generacny token, status a refresh.
        def do_hw_csv(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_hw_csv(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end

        # --- ŠT-1c PR B1: sekcia ROZPOCET -----------------------------------
        #
        # JEDINA sekcia, ktora ZAPISUJE do modelu (1 mutacia = 1 krok Spat).
        # Vsetky tela su v `ProductionCore` — okno odovzdava LEN svoj generacny
        # token, svoj status, svoje echo a SVOJ REFRESH.
        #
        # GENERACNY KONTRAKT (audit #1): budget-iniciovany push ide s
        # `bump: false` — payload je PLNY (Kontrola dostane cerstve rozpoctove
        # ORANGE), ale generacia okna sa NEDVIHA. Mutacia rozpoctu nemeni
        # `rows`/`refs`, takze rozkliknuty riadok Kusovnika ani rozrobeny export
        # inej sekcie nesmie zastarat len preto, ze niekto prepisal sumu.
        # Ochranu proti zastaranemu ZAPISU drzi to, ze KAZDA ina zmena (model,
        # katalog, prepnutie dokumentu) generaciu bumpne ako doteraz — a mutacia
        # so starym `gen` sa odmietne.
        def do_budget(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_budget(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc,
                                                                repush: budget_repush_proc,
                                                                result: budget_result_proc)
        end

        # XLSX rozpoctu — flush handshake (rozpisany edit panela meni kusovnik,
        # teda aj platne, olep a montaz v rozpocte).
        def do_budget_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_budget_xlsx(Sketchup.active_model, data, generation: @generation,
                                                                     status: status_proc,
                                                                     repush: repush_proc)
        end

        # Zakaznicka cenova ponuka (XLSX) — od ŠT-1c PR B2 export SEKCIE
        # `offer` (vlastna sekcia Studia); telo je v jadre ako ostatne exporty.
        def do_cp_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_cp_xlsx(Sketchup.active_model, data, generation: @generation,
                                                                 status: status_proc,
                                                                 repush: repush_proc)
        end

        # --- ŠT-1b: sekcia KONTROLA -----------------------------------------
        # Vsetky telá su v `ProductionCore` (audit #5, #13) — okno odovzdava LEN
        # svoj generacny token, svoj status, svoj refresh a svoje echo. Model sa
        # NEMENI: overlaye kreslia NAD nim, nastavenie zije v %APPDATA%.

        # D-83 (Š9): „Nahradiť UNI…" pri naleze „materiál neurčený".
        def do_replace_uni(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.replace_uni(Sketchup.active_model, data, generation: @generation,
                                                                  status: status_proc,
                                                                  repush: repush_proc)
        end

        # Š10: „Zvýrazniť hrany" (telo tlacidla).
        def do_edge_check(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_edge_check(Sketchup.active_model, data, generation: @generation,
                                                                    status: status_proc,
                                                                    repush: repush_proc,
                                                                    echo: edge_echo_proc)
        end

        # Š10: 3-stavove nastavenie (rohovy trojuholnik) — TEN ISTY zdielany
        # komponent a ta ista serverova cesta ako rail Inspectora.
        def do_edge_check_option(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_edge_check_option(Sketchup.active_model, data, generation: @generation,
                                                                           status: status_proc,
                                                                           repush: repush_proc,
                                                                           echo: edge_echo_proc)
        end

        # Š10: „Smer kresby" (K2/D-87).
        def do_grain_check(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_grain_check(Sketchup.active_model, data, generation: @generation,
                                                                     status: status_proc,
                                                                     repush: repush_proc,
                                                                     grain_echo: grain_echo_proc)
        end

        # Maly echo push stavu prepinaca (bez prepoctu celej sekcie) — vola ho
        # `Engine.broadcast_edge_check` po prepnuti Z HOCIJAKEHO vstupneho bodu
        # (rail Inspectora aj lista tejto sekcie) aj EdgeCheck po prepocte cache.
        def push_edge_check(state = nil)
          return unless defined?(EdgeCheck)

          st = state || EdgeCheck.ui_state(Sketchup.active_model)
          js("if (window.NX && NX.setEdgeCheck) NX.setEdgeCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_edge_check')
        end

        def push_grain_check(state = nil)
          return unless defined?(GrainCheck)

          st = state || GrainCheck.ui_state(Sketchup.active_model)
          js("if (window.NX && NX.setGrainCheck) NX.setGrainCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_grain_check')
        end

        # To iste nastavenie ma DVA vstupne body (rail Inspectora · lista tejto
        # sekcie); tretim bolo okno Vyroba, ktore zaniklo v ŠT-1c PR B3.
        # Otvorenie na jednom zavrie druhy — na obrazovke nikdy nestoja dve
        # kopie tych istych prepinacov. Cisto zobrazovacie.
        def close_edge_menu
          js('if (window.NX && NX.closeEdgeMenu) NX.closeEdgeMenu();')
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.close_edge_menu')
        end

        # --- rucny prepocet okna („Obnoviť" v liste KAZDEJ sekcie) -----------
        # SMOKE 22.8.: klient si pred volanim nastavi hlasku „Prepočítavam…"
        # a NIKTO ju nezhodil — po dobehnutom prepocte v okne visela dalej
        # a vyzeralo to, ze sa okno zaseklo. Hlasku preto zhadzuje SERVER: on
        # jediny vie, ci prepocet dobehol. Plati pre VSETKY sekcie (jeden push
        # nesie kusovnik, kontrolu, nakup, rozpocet aj ponuku naraz).
        #
        # Rescue tu je ZAMERNE aj napriek spolocnemu rescue v `cb`: hlaska
        # „Prepočítavam…" nesmie ostat visiet ANI pri vynimke, a chybu treba mat
        # v logu s menom TEJTO cesty.
        def do_refresh_bom
          push_state
          set_status('Prepočítané.')
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.do_refresh_bom')
          set_status("Prepočet zlyhal: #{e.message}", true)
        end

        # --- lista Kusovnika: nazov projektu + merge 18+36 (audit #1) --------
        # Obe hodnoty su nastavenim POCITACA (%APPDATA%), nie zakazky: ziadny
        # zapis do modelu a ziadny krok Spat.
        #
        # Zapis NEROBI plny `push_state` (review PR #193 P2): ten zdviha
        # `@generation`, takze prvy klik ci export hned po editacii nazvu (change
        # tesne pred clickom) by zarucene spadol na „Dáta okna sa medzitým
        # zmenili". Kusovnik sa pritom nezmenil — zmenila sa LISTA. Ide preto
        # cielene echo (vzor `push_edge_check`), ktore prepise len jej obsah
        # a generaciu NECHA TAK.
        def do_set_vepo_opts(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return set_status('Okno sa medzitým prepočítalo — obnovené, skús znova.', true)
          end
          guid = data['model_guid'].to_s
          # Tolerantne ako `ProductionCore.do_budget`: prazdny udaj z klienta
          # (starsi cachovany DOM) guard neblokuje, nezhodne ID ano.
          if !guid.empty? && guid != ProductionCore.model_guid(model)
            push_state
            return set_status('Model sa medzitým prepol — obnovené, skús znova.', true)
          end

          msg = []
          if data.key?('project')
            name = ProductionCore.save_project_name(model, data['project'])
            msg << "Názov projektu: #{name}"
          end
          if data.key?('merge')
            merge = ProductionCore.save_merge_18_36(data['merge'] == true)
            msg << "18+36 spolu: #{merge ? 'zapnuté' : 'vypnuté'}"
          end
          return set_status('Nič sa nezmenilo.', true) if msg.empty?

          push_vepo_bar(model)
          set_status("#{msg.join(' · ')}. Platí pre všetky exporty.")
        end

        # Maly echo push LISTY sekcie (nazov projektu + merge). Nezdviha
        # generaciu a neprepocitava kusovnik — je to zobrazovacia synchronizacia
        # toho, co uz je zapisane.
        def push_vepo_bar(model = nil)
          m = model || Sketchup.active_model
          st = { 'project' => ProductionCore.project_name(m),
                 'default_project' => ProductionCore.default_project_name(m),
                 'merge_18_36' => ProductionCore.merge_18_36 }
          js("if (window.NX && NX.setVepoBar) NX.setVepoBar(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_vepo_bar')
        end

        # --- premostenia navigacie (audit #2) --------------------------------
        # Klient posiela LEN meno polozky; ci sa smie otvorit a CO sa otvori,
        # rozhoduje whitelist TU (HTML nie je ochrana).
        def do_bridge(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          key = data['section'].to_s
          if WINDOW_BRIDGES.key?(key)
            mod = bridge_window(WINDOW_BRIDGES[key])
            return set_status('Okno sa nepodarilo otvoriť (nie je načítané).', true) if mod.nil?

            mod.show
            return set_status(BRIDGE_STATUS[key])
          end
          if key == 'about'
            Panel.show if defined?(Panel)
            return set_status(BRIDGE_STATUS[key])
          end
          set_status('Táto sekcia zatiaľ neexistuje.', true)
        end

        # Meno modulu -> modul. Zoznam mien je uzavrety (`WINDOW_BRIDGES`),
        # takze sa sem nikdy nedostane nic, co klient vymyslel.
        def bridge_window(name)
          return nil unless Engine.const_defined?(name)

          Engine.const_get(name)
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.bridge_window')
          nil
        end

        private

        # Callbacky, ktorymi sa okno prihlasi do zdielaneho jadra.
        def status_proc
          ->(msg, error = false) { set_status(msg, error) }
        end

        def repush_proc
          -> { refresh_if_open }
        end

        # ŠT-1c PR B1 (audit #1): refresh po mutacii ROZPOCTU. Plny payload,
        # ale BEZ zdvihu generacie — inak by kazdy prepis sumy zneplatnil
        # rozkliknuty riadok Kusovnika a rozrobeny export inej sekcie.
        #
        # Review #3: JEDINA refresh cesta okna, ktora si nesmie dovolit vynimku.
        # `ProductionCore.do_budget` vola `repush` aj vo svojej rescue vetve —
        # keby prvy pokus vybuchol, druhy by uz bezal MIMO rescue, vyletel by
        # z callbacku a klient by nedostal payload; jeho fronta zapisov by
        # potom visela az do 6 s poistky (`BUD_BUSY_MS`).
        def budget_repush_proc
          lambda do
            push_state(bump: false) if @dialog && @dialog.visible?
          rescue StandardError => e
            Engine.log_error(e, 'StudioDialog.budget_repush')
          end
        end

        # Vysledok mutacie ide do okna PRED cerstvym payloadom — rozpisany
        # draft sa smie zavriet LEN pri uspechu (GH #138 P2).
        def budget_result_proc
          lambda do |op, ok|
            js("if (window.NX && NX.budgetResult) NX.budgetResult(#{op.to_s.to_json}, #{ok ? 'true' : 'false'});")
          end
        end

        # E-c „Prepočítať ceny": fazove okno riadi SERVER, toto je len echo do
        # TOHTO okna.
        def price_refresh_emit_proc
          ->(event) { js("if (window.NX && NX.priceRefresh) NX.priceRefresh(#{event.to_json});") }
        end

        # Zivotnost behu = TA ISTA instancia okna, z ktorej sa spustil (vzor
        # MaterialsDialog.demos_alive_proc): zavretie okna pocas fetchu a jeho
        # znovuotvorenie NESMIE opusteny beh „ozivit". Prepnutie MODELU beh
        # nezastavi — ceny idu do katalogu, ktory je globalny.
        def price_refresh_alive_proc(dlg)
          -> { !dlg.nil? && !@dialog.nil? && @dialog.equal?(dlg) && dlg.visible? }
        end

        # Po dobehnuti prepoctu: ceny sa zmenili GLOBALNE, takze cerstve cisla
        # potrebuje aj katalog materialov, panel a katalog kovania. Tento push
        # generaciu ZDVIHA (nie je to mutacia rozpoctu — zmenil sa katalog).
        #
        # ŠT-1c PR B3: okno Vyroba zo zoznamu vypadlo — zaniklo. Kontrakt
        # „KAZDE okno s cislami zakazky je vo VSETKYCH refresh cestach" plati
        # dalej: prepocet cien meni cisla GLOBALNE, takze cerstve data dostane
        # toto okno, katalog materialov, panel aj katalog kovania.
        def price_refresh_after_proc
          lambda do
            push_state
            MaterialsDialog.push_catalog if defined?(MaterialsDialog)
            Panel.push_materials if defined?(Panel)
            HardwareCatalogDialog.push_items if defined?(HardwareCatalogDialog)
          end
        end

        # Echo prepinacov (ŠT-1b): odmietnuta akcia musi vratit listu sekcie na
        # PRAVDIVY stav — bez prepoctu celej sekcie.
        def edge_echo_proc
          -> { push_edge_check }
        end

        def grain_echo_proc
          -> { push_grain_check }
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Štúdio',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            # D-51/D-77: JEDNA PRAVDA je OBSAHOVY viewport 1060 × 640
            # (`NX_FIT_MIN` v studio.html) — navigacia 208 px + tabulka
            # kusovnika so 7 stlpcami a stlpcom akcii. Rozmery tu su
            # VONKAJSIE (obsah + ramik okna ≈ 16 × 40 px). Platia LEN pri
            # PRVOM otvoreni — zapamatane male okno dorovna `nx_fit`.
            width: 1076,
            height: 680,
            min_width: 1076,
            min_height: 520,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'studio.html'))
          register_callbacks(@dialog) # pred show!
          # Bez vynulovania by dalsie otvorenie ozivilo referenciu na mrtve
          # okno a kazdy push by tichol na vynimke (audit #14).
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          Engine.register_dialog_fit(dlg, 'studio') # D-77 + UI-01 tema
          cb(dlg, 'ready')        { |_p| push_state }
          # SMOKE 22.8.: NIE `push_state` priamo — po prepocte musi prist aj
          # hlaska, inak v okne navzdy visi klientske „Prepočítavam…".
          cb(dlg, 'refresh_bom')  { |_p| do_refresh_bom }
          # Š3: klik na riadok / oko = oznac v modeli, ceruzka = oznac + zdvihni
          # Inspector (`focus_inspector`). Obe cesty su ten isty handler.
          cb(dlg, 'nx_select')    { |p| handle_select(p) }
          cb(dlg, 'vepo_export')  { |p| handle_export(p) }
          # ŠT-1c PR A: CSV nakupneho zoznamu (lista sekcie Nakup kovania) —
          # ten isty flush handshake ako VEPO, len vlastnym kanalom Studia.
          cb(dlg, 'hw_csv_export') { |p| handle_hw_csv(p) }
          cb(dlg, 'studio_set_vepo_opts') { |p| do_set_vepo_opts(p) }
          cb(dlg, 'studio_bridge')        { |p| do_bridge(p) }
          # ŠT-1b, sekcia KONTROLA. Klik na riadok ide uz existujucou cestou
          # `nx_select` (nesie `problem_key`); tieto callbacky su akcie riadku
          # a lista sekcie. Ziadny flush handshake — nic z toho model nemeni.
          cb(dlg, 'replace_uni')          { |p| do_replace_uni(p) }
          cb(dlg, 'edge_check_toggle')    { |p| do_edge_check(p) }
          cb(dlg, 'edge_check_option')    { |p| do_edge_check_option(p) }
          # Otvorenie 3-stavoveho nastavenia zavrie jeho kopiu v raile
          # (nikdy dve naraz).
          cb(dlg, 'edge_menu_open')       { |_p| Engine.close_edge_menu(:studio) }
          cb(dlg, 'grain_check_toggle')   { |p| do_grain_check(p) }
          # ŠT-1c PR B1, sekcia ROZPOCET. Mutacia (`budget_mutate`) ide PRIAMO —
          # nie je to export a flush handshake by pri kazdom prepise sumy
          # zbytocne prehnal rozpisane edity panela. Oba XLSX exporty naopak
          # flush handshake MAJU (cisla harku musia sediet s modelom po flushi).
          cb(dlg, 'budget_mutate')   { |p| do_budget(p) }
          cb(dlg, 'budget_xlsx')     { |p| handle_budget_xlsx(p) }
          cb(dlg, 'cp_xlsx')         { |p| handle_cp_xlsx(p) }
          cb(dlg, 'budget_open_url') { |p| handle_budget_url(p) }
          cb(dlg, 'budget_settings') { |_p| ProductionCore.open_budget_settings(status: status_proc) }
          # E-c: „Prepočítať ceny" — hromadne obnovenie cien z Demosu.
          cb(dlg, 'price_refresh')        { |p| handle_price_refresh(p) }
          cb(dlg, 'price_refresh_cancel') { |_p| ProductionCore.price_refresh_cancel(status: status_proc) }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(studio): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'studio js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "studio cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # Klik z okna: cez panel (flush handshake) alebo priamo, ak panel nezije.
        # Relay ma VLASTNE meno (`studioRelay`), aby odpoved prisla do TOHTO
        # okna — kazdy klient ma vlastny `gen` a cudzi push by klik odmietol.
        def handle_select(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelay(#{data.to_json})")
          else
            do_select(data)
          end
        end

        def handle_export(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayExport(#{data.to_json})")
          else
            do_export(data)
          end
        end

        # ŠT-1c PR A: CSV kovania ide TYM ISTYM flush handshakom ako VEPO —
        # rozpisany edit panela meni pocty kovania, takze by sa objednavalo zo
        # starych cisel. Vlastny relay (`studioRelayHwCsv`), aby odpoved prisla
        # do TOHTO okna (kazde okno ma vlastny `gen`).
        def handle_hw_csv(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayHwCsv(#{data.to_json})")
          else
            do_hw_csv(data)
          end
        end

        # ŠT-1c PR B1: XLSX rozpoctu a zakaznicka cenova ponuka — TEN ISTY flush
        # handshake ako VEPO/CSV, vlastnym kanalom Studia (odpoved musi prist do
        # TOHTO okna; cudzi push by mu klik odmietol).
        #
        # Review PR #198 #7: payload sa berie TOLERANTNE (`Hash` alebo JSON
        # retazec) ako vsade inde v tomto subore. Ked panel nezije, vetva
        # `else` odovzdava uz ROZPARSOVANY Hash — a `JSON.parse(hash.to_s)` by
        # na nom spadol; rovnaka pastka by cakala na kazde volanie z testu ci
        # z ineho Ruby miesta.
        def handle_budget_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayBudget(#{data.to_json})")
          else
            do_budget_xlsx(data)
          end
        end

        def handle_cp_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayCp(#{data.to_json})")
          else
            do_cp_xlsx(data)
          end
        end

        # ↗ v riadku rozpoctu — adresa sa dohladava v modeli podla ID polozky a
        # este raz sanitizuje (z klienta nechodi).
        def handle_budget_url(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.budget_open_url(Sketchup.active_model, data, status: status_proc)
        end

        # E-c: beh riadi SERVER (`core/price_refresh.rb`) — okno odovzdava svoje
        # echo, svoju zivotnost a svoje refresh cesty.
        def handle_price_refresh(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_price_refresh(Sketchup.active_model, data,
                                          generation: @generation, status: status_proc,
                                          repush: repush_proc, emit: price_refresh_emit_proc,
                                          alive: price_refresh_alive_proc(@dialog),
                                          after: price_refresh_after_proc)
        end

        # Payload OKNA (sekcie Kusovnik + Kontrola). Cisla su TIE ISTE, ktore
        # nesie zdielane jadro (`ProductionCore`) — Studio nema vlastny vypocet a JS
        # si NIC neprepocitava (ani sumy, ani medzisucty skupin, ani counts).
        # JEDEN push nesie obe sekcie zamerne: prepnutie sekcie je cisto
        # zobrazovacie, takze nesmie chodit na server po data.
        # `bump: false` = ROZPOCTOVY push (audit #1). Payload je plny, ale
        # generacia okna sa NEDVIHA: mutacia rozpoctu nemeni `rows`/`refs`,
        # takze pending klik ci export inej sekcie ostava platny. Prvy push
        # generaciu zdvihne VZDY (gen 0 by sa rovnal „ziadne data").
        def push_state(bump: true)
          @generation = @generation.to_i + 1 if bump || @generation.to_i.zero?
          model = Sketchup.active_model
          collected = ProductionCore.fresh_collect(model)
          bom = Bom.compute(collected)
          smap = ProductionCore.sheets_map
          sheet_sizes = smap.each_with_object({}) { |(id, s), out| out[id] = s['sheet_size'] }
          # D-19: odhad platni per material — JEDEN vypocet pre kusovnik aj rozpocet.
          estimate = SheetEstimate.estimate(
            bom[:rows], sheet_sizes: sheet_sizes,
            uni_ids: smap.each_with_object({}) { |(id, s), out| out[id] = true if Materials.uni?(s) }
          )
          # ŠT-1b (audit #2): KONTROLA z TOHO ISTEHO cerstveho zberu a z TOHO
          # ISTEHO jadra (`ProductionCore`) — vratane upozorneni ROZPOCTU. Semafor
          # sekcie, badge navigacie aj suhrn exportu tak ukazuju JEDNO cislo.
          # (⚠ chip Inspectora je nieco ine — build warnings oznacenej skrinky;
          # do tejto sekcie len VEDIE deep-linkom.)
          # ŠT-1c PR B1: rozpocet uz nie je len zdroj ORANGE nalezov — je to
          # payload SEKCIE `budget` tohto okna. Pocita sa RAZ a slúzi obom
          # (Kontrola z neho berie svoje upozornenia), z uz hotoveho odhadu
          # platni — ziadny druhy vypocet.
          hw_exp = ProductionCore.hardware_expansion(model, collected)
          budget = ProductionCore.budget_payload(model, bom, collected, estimate, hw_exp, smap)
          control = ProductionCore.control_payload(collected, hardware_expansion: hw_exp,
                                                              budget: budget, sheets: smap)
          data = {
            version: Engine::VERSION,
            gen: @generation,
            model_title: (model.title.to_s.empty? ? 'Bez názvu' : model.title.to_s),
            model_guid: ProductionCore.model_guid(model),
            # Š2: riadky obohatene o `role_label` (server sklada aj tento text).
            rows: ProductionCore.rows_with_roles(bom[:rows], collected),
            sheets: bom[:sheets], edging: bom[:edging],
            # ŠT-1c PR A (Š7), sekcia NAKUP KOVANIA — presun tabu Kovanie 1:1.
            # `hardware_sets` = nakupny zoznam zo setov (rows/unmapped/summary
            # + stav snapshotu setov projektu: invalid = banner, missing =
            # global default); `hardware` = generika podla pravidiel, obohatena
            # o SERVEROVE texty `label` a `params_label` (audit #3 — obohatenie
            # zije v jadre, nie v okne). Zoznam sa POCITA UZ VYSSIE (`hw_exp`)
            # kvoli ORANGE nalezom Kontroly — ziadny druhy vypocet.
            hardware: ProductionCore.hardware_labeled(bom),
            hardware_sets: hw_exp,
            summary: bom[:summary],
            sheet_estimate: estimate,
            # Š1 sucty: KAZDE cislo suctoveho riadku pocita SERVER — JS si
            # neprepocitava ani m², ani odhad platni (vzor rozpoctu: klient
            # z payloadu LEN cita).
            totals: totals_payload(bom, estimate),
            # audit #4: popisky, farby a hrubky materialov/pasok zo SERVERA —
            # klient nema druhu pravdu o tom, ako sa material vola.
            materials_meta: ProductionCore.materials_meta(bom),
            edges_meta: ProductionCore.edges_meta(bom),
            # audit #1 + #16: nazov projektu aj merge chodia v KAZDOM pushi,
            # takze sa lista nikdy nerozide s tym, co plati pre exporty.
            vepo: { project: ProductionCore.project_name(model),
                    default_project: ProductionCore.default_project_name(model),
                    merge_18_36: ProductionCore.merge_18_36 },
            # ŠT-1b, sekcia KONTROLA (Š8–Š11). `counts` nesie aj ZELENE cislo
            # („skriniek bez nálezu") — JS si zo zoznamu NIC neprepocitava, ani
            # badge navigacie. Filter chipov je cisto zobrazovacia vec klienta.
            control: control['items'], counts: control['counts'],
            # ŠT-1c PR B1, sekcia ROZPOCET (Š12–Š13): cely rozpocet zakazky
            # (sekcie, sumy, vek cien, upozornenia, nahlad cenovej ponuky).
            # JS z neho LEN cita — ZIADNA suma sa v prehliadaci nepocita.
            budget: budget,
            # Š10: stav oboch prepinacov listy. Vypnuty prepinac nic neskenuje.
            edge_check: (defined?(EdgeCheck) ? EdgeCheck.ui_state(model) : nil),
            grain_check: (defined?(GrainCheck) ? GrainCheck.ui_state(model) : nil),
            # Deep-link: sekcia sa posiela PRAVE RAZ (inak by kazdy refresh
            # vratil pouzivatela tam, odkial medzitym odisiel).
            open_section: consume_pending_section,
            anchor: consume_pending_anchor
          }
          js("NX.setStudio(#{data.to_json})")
        end

        # Sucty suctoveho riadku (Š1) a hlavicky pohladov Platne/ABS.
        # Odhad platni je ROZSAH (10–25 % prerez) — posiela sa oboma koncami,
        # aby klient nemusel nic zaokruhlovat ani scitavat.
        def totals_payload(bom, estimate)
          s = bom[:summary] || {}
          est = Array(estimate)
          { 'parts' => s['quantity'].to_i, 'rows' => s['rows'].to_i,
            'm2' => s['m2_total'].to_f, 'bm' => s['bm_total'].to_f,
            'materials' => Array(bom[:sheets]).length,
            'edges' => Array(bom[:edging]).length,
            'plates_min' => est.sum { |e| e['count_min'].to_f }.round(1),
            'plates_max' => est.sum { |e| e['count_max'].to_f }.round(1) }
        end

        # Jednorazove prevzatie deep-link sekcie (viz `show`).
        def consume_pending_section
          s = @pending_section
          @pending_section = nil
          SECTIONS.include?(s.to_s) ? s.to_s : nil
        end

        # Kotva sa spotrebuje spolu so sekciou — bez sekcie by nemala kam sadnut.
        def consume_pending_anchor
          a = @pending_anchor
          @pending_anchor = nil
          a.to_s.empty? ? nil : a.to_s
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?

          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.js')
        end
      end
    end
  end
end
