# frozen_string_literal: true
# Noxun Engine — V0.5 B: satelitne okno VYROBA (kusovnik + supisy + klik-select).
#
# Data: Bom.collect + Bom.compute (snapshoty na entitach, davka A). Okno NIKDY
# nemuti model — klik-select iba vybera (Codex B2: cely vyber pod
# Panel.suspend_selection_sync a nasledny refresh panela BEZ dedup ticku).
#
# Guardy z auditu B:
#  - generacny token (B4): kazdy push nesie gen; klik so starou gen sa odmietne
#    a data sa re-pushnu (prepnuty model / stale DOM nikdy nevyberie zle entity)
#  - flush handshake (B1): ak je panel otvoreny, select ide RELAY cez panel JS
#    (flushCabinetEditsNow -> production_do_select) — rozpisana uprava v paneli
#    sa najprv aplikuje, az potom sa meni selection
#  - adresa entity = persistent_id (B3/F5): jednoznacna aj pri docasne
#    zdielanych ID pred dedup tickom; pred add sa overuje valid? + dedupe
#
# ST-1a PR A: ciste pomocniky (VEPO rodina, mapy katalogov, vyberove resolvery)
# zdiela s oknom Studio modul `ProductionCore`. V SketchUpe ho nacita loader
# (main.rb) EST PRED tymto suborom; headless pure testy si vsak
# `ui/production_dialog.rb` requiruju samostatne — preto poistka nizsie.
require File.expand_path('production_core', __dir__) unless defined?(Noxun::Engine::ProductionCore)

module Noxun
  module Engine
    module ProductionDialog
      DLG_KEY = 'NoxunEngineProduction'

      # UI-D3: taby okna. ZAVAZNY whitelist deep-linku — panel posiela len meno
      # tabu a server je jedina autorita, ktora rozhodne, ci je platne (JS mirror
      # `NXShell.STUDIO_TABS` je pohodlie, nie ochrana).
      #
      # ST-1a: taby `rows`/`sheets`/`edging` ZANIKLI — kusovnik a supisy platni
      # a ABS su od tejto davky sekciou Kusovnik v okne Studio (pohlady Dielce ·
      # Platne · ABS). Whitelist ich preto uz NEPOZNA; deep-link na ne ide cez
      # `StudioDialog::SECTIONS`.
      # ŠT-1b: to iste sa stalo tabu `control` — KONTROLA je od tejto davky
      # sekcia `ctrl` okna Studio (semafor-filter, prepinace hran a kresby,
      # zive badge navigacie); deep-link na nu ide cez `StudioDialog::SECTIONS`.
      TABS = %w[hardware budget].freeze

      # D-105: nazvy stavov zvyraznenia. Autoritou je od ŠT-1b `ProductionCore`
      # (texty potrebuje aj Studio); tato konstanta ostava, lebo pod tymto menom
      # ju pozna rail Inspectora aj zdielany js/edge_menu.js.
      EDGE_OPTION_LABELS = ProductionCore::EDGE_OPTION_LABELS

      class << self
        # `open_tab` = deep-link z Inspectora (⚠ warnpanel -> KONTROLA, „Materiál"
        # -> Kusovník). Bez neho sa tab NEPREPINA: pouzivatel, ktory si okno otvoril
        # sam, ostava tam, kde naposledy skoncil.
        #
        # Tab sa NEPOSIELA hned — okno po `show` este nemusi mat nacitany HTML,
        # takze `execute_script` by prisiel do prazdna. Odklada sa a spotrebuje ho
        # NAJBLIZSI `push_state` (pri novom okne ho vyvola `ready`, pri uz otvorenom
        # ho volame priamo tu). Vzor je stav ABS kontroly hran, ktory chodi tou
        # istou cestou.
        def show(open_tab: nil)
          @pending_tab = TABS.include?(open_tab.to_s) ? open_tab.to_s : nil
          dlg = ensure_dialog
          # K2/D-87: zapamataný prepínač „Smer kresby" (%APPDATA%, nastavenie
          # počítača) sa obnoví PRED prvým push_state — inak by okno hlásilo
          # vypnuté a v modeli by sa kreslilo. Vypnutý prepínač nerobí nič.
          restore_grain_check
          if dlg.visible?
            dlg.bring_to_front
            push_state
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.show')
        end

        # K2/D-87: obnova zapamataneho prepinaca kresby smeru. Chranene vlastnym
        # blokom — zlyhanie NESMIE zabranit otvoreniu okna Vyroba.
        def restore_grain_check
          return unless defined?(GrainCheck)
          GrainCheck.restore!(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.restore_grain_check')
        end

        # D-19 (Codex F3): verejny bezpecny refresh — vola ho editor materialov
        # po zmene katalogu (format platne meni odhad v otvorenom okne).
        def refresh_if_open
          return unless @dialog && @dialog.visible?
          push_state
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.refresh_if_open')
        end

        # EngineAppObserver: prepnutie/otvorenie modelu = nove data + nova generacia
        # (stary DOM klik sa odmietne genom aj keby ID sedeli — dva Untitled apod.)
        # @model_epoch: stabilna identita "ineho modelu" pre JS lifecycle nazvu
        # projektu (GH P2: dva modely s rovnakym titulom/nazvom suboru).
        def on_model_changed(_model)
          @model_epoch = @model_epoch.to_i + 1
          return unless @dialog && @dialog.visible?
          push_state
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.on_model_changed')
        end

        # V0.5 C: export VEPO. ST-1a PR B: telo zije v `ProductionCore` — to iste
        # robi aj okno Studio a dva takmer rovnake exporty by sa casom rozisli
        # (a rozdiel by sa ukazal az na vyrobnom vystupe). Okno odovzdava svoj
        # generacny token, svoj status a svoj refresh.
        def do_export(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_export(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end

        # Vstup pre relay z panela (B1): panel uz flushol edity, mozeme vyberat.
        # Telo je v `ProductionCore` (zdielane so Studiom).
        def do_select(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_select(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end


        # CSV nakupneho zoznamu — server-side z CERSTVEHO modelu (audit N11;
        # flush/generation vzor VEPO: data z DOM su po editoch zastarale).
        # Vstup po relay z panela (edity flushnute) alebo priamo bez panela.
        def do_hw_csv(payload)
          data = JSON.parse(payload.to_s)
          if data['flush_blocked']
            return set_status('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
          end
          model = Sketchup.active_model
          exp = hardware_expansion(model, fresh_collect(model))
          return set_status('Nákupný zoznam sa nedá zostaviť (pozri Ruby konzolu).', true) if exp.nil?
          if Array(exp['rows']).empty? && Array(exp['unmapped']).empty?
            return set_status('Model nemá žiadne kovanie — niet čo exportovať.', true)
          end
          # audit #1: nazov projektu je SERVEROVA autorita (jeden nazov pre
          # VSETKY styri exporty) — z DOM uz nechodi.
          project = project_name(model)
          fname = "kovanie_#{VepoExport.project_slug(project)}.csv"
          target = UI.savepanel('Uložiť nákupný zoznam kovania', vepo_settings['last_dir'], fname)
          return set_status('Export zrušený.') if target.nil? || target.to_s.empty?
          csv = HardwareSets.purchase_csv(exp, project: project,
                                          generated_at: Time.now.strftime('%Y-%m-%d %H:%M'))
          File.open(target, 'wb') { |f| f.write("\xEF\xBB\xBF" + csv) } # BOM pre Excel
          save_vepo_settings('last_dir' => File.dirname(target))
          n = Array(exp['rows']).length
          un = Array(exp['unmapped']).length
          set_status("Nákupný zoznam: #{n} položiek#{un.positive? ? " + #{un} nemapovaných (v CSV aj KONTROLE)" : ''} → #{target}", un.positive?)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.handle_hw_csv')
          set_status("Export zlyhal: #{e.message}", true)
        end

        # V0.6 E-b: XLSX rozpocet v "Luciinom formate". Rovnaky flush/generation
        # handshake ako VEPO — cisla harku musia sediet s modelom PO flushi
        # rozpisaneho editu panela, nie s tym, co drzi DOM okna.
        def do_budget_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return set_status('Dáta okna sa medzitým zmenili — skús export znova.', true)
          end
          if data['flush_blocked']
            return set_status('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
          end

          model = Sketchup.active_model
          collected = fresh_collect(model)
          bom = Bom.compute(collected)
          budget = budget_payload(model, bom, collected)
          return set_status('Rozpočet sa nepodarilo zostaviť (pozri Ruby konzolu).', true) if budget.nil?

          project = project_name(model) # audit #1: server je autorita nazvu
          now = Time.now
          fname = BudgetXlsx.file_name(project, now)
          target = UI.savepanel('Uložiť rozpočet (XLSX)', vepo_settings['last_dir'], fname)
          return set_status('Export zrušený.') if target.nil? || target.to_s.empty?

          # Bez pripony by Excel subor neotvoril dvojklikom — savepanel ju
          # nedoplna, ked ju pouzivatel v nazve prepise.
          target = "#{target}.xlsx" unless File.extname(target.to_s).downcase == '.xlsx'
          XlsxWriter.write(target, BudgetXlsx.sheet(budget, project: project, now: now), now: now)
          save_vepo_settings('last_dir' => File.dirname(target))
          totals = budget['totals'] || {}
          miss = totals['unknown_count_in_total'].to_i
          set_status("Rozpočet uložený: #{fmt_eur(totals['total'])} → #{target}" \
                     "#{miss.positive? ? " · #{miss} riadkov bez ceny sa nezapočítalo" : ''}", miss.positive?)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.do_budget_xlsx')
          set_status("Export rozpočtu zlyhal: #{e.message}", true)
        end

        # V0.6 E-b2: ZAKAZNICKA CENOVA PONUKA (XLSX, 2 harky). Rovnaky
        # flush/generation handshake ako rozpocet — CP je VIEW nad TYM ISTYM
        # payloadom, takze cisla musia sediet s modelom PO flushi editov panela.
        #
        # FIREWALL: pred zapisom sa cely vysledny harok prejde blocklistom
        # (CpExport.firewall_hits). Nalez export NEBLOKUJE (rovnaky kontrakt ako
        # KONTROLA pri VEPO), ale ide do statusu aj do logu — Michal musi
        # vediet, ze do zakaznickeho dokumentu presiel interny pojem.
        #
        # GH #139 P1/P2: status hlasi AJ neuplnost cisel — riadok bez ceny
        # (suma ponuky je podhodnotena, hoci polozka v specifikacii je) a
        # zapornu "Nábytkovú zostavu". Zakaznicky dokument sa nesmie tvarit
        # ako v poriadku, ked cislo v nom nie je cele.
        def do_cp_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return set_status('Dáta okna sa medzitým zmenili — skús export znova.', true)
          end
          if data['flush_blocked']
            return set_status('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
          end

          model = Sketchup.active_model
          collected = fresh_collect(model)
          bom = Bom.compute(collected)
          smap = sheets_map
          hw_exp = hardware_expansion(model, collected)
          budget = budget_payload(model, bom, collected, nil, hw_exp, smap)
          return set_status('Rozpočet sa nepodarilo zostaviť (pozri Ruby konzolu).', true) if budget.nil?

          cp = budget['cp_preview']
          cp ||= CpExport.preview(budget, BudgetStore.cp_overrides(model), SupplierSettings.active)
          spec = CpExport.specification(collected[:records], sheets: smap,
                                                             hardware_expansion: hw_exp, budget: budget)

          project = project_name(model) # audit #1: server je autorita nazvu
          now = Time.now
          target = UI.savepanel('Uložiť cenovú ponuku (XLSX)', vepo_settings['last_dir'],
                                CpXlsx.file_name(project, now))
          return set_status('Export zrušený.') if target.nil? || target.to_s.empty?

          target = "#{target}.xlsx" unless File.extname(target.to_s).downcase == '.xlsx'
          sheets = CpXlsx.sheets(cp, spec, project: project, now: now)
          hits = CpExport.firewall_hits(CpXlsx.text_cells(sheets))
          XlsxWriter.write_book(target, sheets, now: now)
          save_vepo_settings('last_dir' => File.dirname(target))
          warnings = cp_warnings(cp, budget, hits)
          set_status(cp_status(cp, spec, target, warnings), !warnings.empty?)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.do_cp_xlsx')
          set_status("Export cenovej ponuky zlyhal: #{e.message}", true)
        end

        # D-104/D-105: prepinac zvyraznenia hran (tab KONTROLA). Model sa NEMENI
        # — overlay kresli NAD nim (ziadna operacia, ziadny undo krok).
        # Guardy bezia na SERVERI (HTML disabled nie je ochrana):
        #   gen        — klik zo stareho DOM (medzitym prepocitane okno),
        #   model_guid — medzitym prepnuty dokument (zaplo by sa v cudzej zakazke),
        #   available  — SketchUp bez Overlay API (SU 2022 a starsi).
        # ŠT-1b (audit #5): telo zije v `ProductionCore` — to iste robi sekcia
        # Kontrola okna Studio a dva takmer rovnake guardy by sa casom rozisli.
        # Okno odovzdava LEN svoju generaciu, svoj status, svoj refresh a svoje
        # echo. Viditelne UI tychto prepinacov okno Vyroba uz nema (presunulo sa
        # do Studia); cesty tu OSTAVAJU, kym okno v ŠT-1c nezanikne.
        def do_edge_check(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_edge_check(Sketchup.active_model, data, generation: @generation,
                                                                    status: status_proc,
                                                                    repush: repush_proc,
                                                                    echo: edge_echo_proc)
        end

        # D-105: prepinace stavov (chyba / mimo pravidla / olepene + „len vybrané").
        # Zapisuju sa do %APPDATA% (nastavenie pocitaca), NIKDY do modelu — preto
        # ziadny flush handshake ani undo krok. Codex audit FIX 4: kluc musi byt
        # z whitelistu a hodnota VYSLOVNE true/false (retazec "false" je v Ruby
        # pravdivy) — inak sa NEZAPISE nic.
        def do_edge_check_option(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_edge_check_option(Sketchup.active_model, data, generation: @generation,
                                                                           status: status_proc,
                                                                           repush: repush_proc,
                                                                           echo: edge_echo_proc)
        end

        # Spolocne serverove guardy oboch akcii zvyraznenia (telo v ProductionCore).
        # Codex audit FIX 4: guid sa porovnava STRIKTNE — prazdny udaj z klienta
        # uz guard NEOBIDE (obe strany citaju to iste `model_guid`).
        def edge_check_guard(data, model)
          ProductionCore.edge_check_guard(data, model, generation: @generation, status: status_proc,
                                                       repush: repush_proc, echo: edge_echo_proc)
        end

        # Echo prepinacov: maly push stavu do TOHTO okna (bez prepoctu celeho
        # okna). Zdielane jadro ho vola pri odmietnuti akcie, aby okno ukazalo
        # PRAVDIVY stav.
        def edge_echo_proc
          -> { push_edge_check }
        end

        def grain_echo_proc
          -> { push_grain_check }
        end

        # Maly echo push (bez prepoctu celeho okna) — vola ho aj EdgeCheck po
        # prepocte cache (rebuild pri zapnutom zvyrazneni).
        def push_edge_check(state = nil)
          return unless defined?(EdgeCheck)
          st = state || EdgeCheck.ui_state(Sketchup.active_model)
          js("if (window.NX && NX.setEdgeCheck) NX.setEdgeCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.push_edge_check')
        end

        # v0.7.28: zatvorenie rozbalovacieho okna prepinacov. Vola ho
        # Engine.close_edge_menu, ked pouzivatel otvoril TO ISTE nastavenie
        # z rohu ABS ikony v raile Inspectora. Cisto zobrazovacie.
        def close_edge_menu
          js('if (window.NX && NX.closeEdgeMenu) NX.closeEdgeMenu();')
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.close_edge_menu')
        end

        def edge_check_status(state)
          ProductionCore.edge_check_status(state)
        end

        # D-105: kratke potvrdenie prepnutia. Metoda je ZAMERNE public — rail
        # Inspectora (`actions_materials.rb`) ju vola zvonku, aby mali obe
        # miesta ten isty slovensky text. Nazvy stavov ziju v ProductionCore
        # (a zrkadli ich js/edge_menu.js).
        def edge_check_option_status(key, value)
          ProductionCore.edge_check_option_status(key, value)
        end

        # ================= K2 / D-87: SMER KRESBY ================================
        # Prepinac vedla „Zvýrazniť hrany" (tab KONTROLA). Model sa NEMENI —
        # ciary sa kreslia NAD nim (ziadna operacia, ziadny undo krok). Guardy
        # su TIE ISTE ako pri zvyrazneni hran (gen + model_guid + Overlay API),
        # preto ide o zdielanu `edge_check_guard` — dva takmer rovnake guardy by
        # sa casom rozisli.
        def do_grain_check(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_grain_check(Sketchup.active_model, data, generation: @generation,
                                                                     status: status_proc,
                                                                     repush: repush_proc,
                                                                     echo: edge_echo_proc,
                                                                     grain_echo: grain_echo_proc)
        end

        # Maly echo push (prepnutie / prepocet po prestavbe) — prekresli sa LEN
        # lista, zoznam kontroly sa nedotkne.
        def push_grain_check(state = nil)
          return unless defined?(GrainCheck)
          st = state || GrainCheck.ui_state(Sketchup.active_model)
          js("if (window.NX && NX.setGrainCheck) NX.setGrainCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.push_grain_check')
        end

        def grain_check_status(state)
          ProductionCore.grain_check_status(state)
        end

        # 1 dielec / 2–4 dielce / 5+ dielcov
        def grain_part_plural(n)
          ProductionCore.grain_part_plural(n)
        end

        # V0.6 E-b: mutacie rozpoctu (rezim, prepis sumy, nasobok, m2, spotrebice
        # v sucte, vlastne polozky). Guardy bezia na SERVERI — HTML disabled ani
        # klientske echo nie su ochrana:
        #   gen        — zapis zo stareho DOM (medzitym prepocitane okno),
        #   model_guid — medzitym prepnuty dokument (zapis by sadol do cudzej zakazky).
        # Po KAZDOM zapise ide cerstvy payload (push_state) — klient si sumy
        # NIKDY neprepocitava.
        def do_budget(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return set_status('Rozpočet sa medzitým prepočítal — obnovené, skús znova.', true)
          end
          guid = data['model_guid'].to_s
          if !guid.empty? && guid != model_guid(model)
            push_state
            return set_status('Model sa medzitým prepol — obnovené, skús znova.', true)
          end
          ok, errors = apply_budget_op(model, data)
          # GH #138 P2: vysledok ide do okna PRED cerstvym payloadom — rozpisany
          # novy riadok sa smie zavriet LEN pri uspechu (inak by pouzivatel po
          # odmietnutom zapise prisiel o vsetky vyplnene hodnoty).
          js("if (window.NX && NX.budgetResult) NX.budgetResult(#{data['op'].to_s.to_json}, #{ok ? 'true' : 'false'});")
          push_state
          return set_status("Nezapísané: #{Array(errors).join(' · ')}", true) unless ok
          set_status(budget_op_status(data))
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.do_budget')
          # Aj po vynimke musi prist payload — inak by okno ostalo v stave
          # „cakam na odpoved" a fronta zapisov by sa neuvolnila.
          push_state
          set_status("Chyba rozpočtu: #{e.message}", true)
        end

        private

        # ST-1a PR B: callbacky, ktorymi sa okno prihlasi do zdielaneho jadra
        # (`ProductionCore.do_export` / `do_select`). `repush` je zamerne
        # „obnov, ak zijes" — zavretemu oknu netreba pocitat cely BOM.
        def status_proc
          ->(msg, error = false) { set_status(msg, error) }
        end

        def repush_proc
          -> { refresh_if_open }
        end

        # Jedna mutacia = jedna metoda BudgetStore = jeden undo krok. Validacia
        # aj rozsahy su v BudgetStore (server), tu sa len smeruje.
        # -> [ok, errors]
        def apply_budget_op(model, data)
          attrs = data['attrs'].is_a?(Hash) ? data['attrs'] : {}
          id = data['id'].to_s
          case data['op'].to_s
          when 'mode'            then BudgetStore.set_mode!(model, data['mode'])
          when 'override'        then BudgetStore.set_override!(model, data['row_key'], data['amount'])
          when 'multiplier'      then BudgetStore.set_std_multiplier!(model, data['row_key'], data['multiplier'])
          when 'viz_m2'          then BudgetStore.set_viz_m2!(model, data['value'])
          when 'appl_included'   then BudgetStore.set_appliances_included!(model, data['included'])
          when 'custom_add'      then ok_pair(BudgetStore.add_custom_item!(model, attrs))
          when 'custom_update'   then ok_pair(BudgetStore.update_custom_item!(model, id, attrs))
          when 'custom_remove'   then BudgetStore.remove_custom_item!(model, id)
          when 'appliance_add'   then ok_pair(BudgetStore.add_appliance!(model, attrs))
          when 'appliance_update' then ok_pair(BudgetStore.update_appliance!(model, id, attrs))
          when 'appliance_remove' then BudgetStore.remove_appliance!(model, id)
          when 'cp_group'        then BudgetStore.set_cp_group!(model, data['source_key'], data['group'])
          else [false, ['neznáma operácia rozpočtu']]
          end
        end

        # GH #139 P1/P2: JEDEN zoznam dovodov, preco zakaznicky dokument NIE JE
        # v poriadku — rozhoduje aj o farbe statusu, aby sa zelene "uložené"
        # nikdy neobjavilo nad podhodnotenou alebo zápornou sumou.
        def cp_warnings(cp, budget, hits)
          c = cp.is_a?(Hash) ? cp : {}
          totals = budget.is_a?(Hash) && budget['totals'].is_a?(Hash) ? budget['totals'] : {}
          out = []
          miss = totals['unknown_count_in_total'].to_i
          if miss.positive?
            out << "#{miss} riadkov rozpočtu nemá cenu — suma ponuky je PODHODNOTENÁ " \
                   '(položky v špecifikácii sú, v cene nie)'
          end
          if c['assembly_negative']
            out << "„Nábytková zostava“ vyšla záporná (#{fmt_eur(c['assembly'])}) — " \
                   'samostatné riadky prevyšujú rozpočet'
          end
          out << "CP nesedí s rozpočtom o #{fmt_eur(c['diff'])}" if c['consistent'] == false
          unless Array(hits).empty?
            terms = hits.map { |h| h['term'] }.uniq.first(5).join(', ')
            out << "v dokumente ostali interné pojmy (#{terms}) — oprav názvy a exportuj znova"
          end
          out
        end

        def cp_status(cp, spec, target, warnings)
          c = cp.is_a?(Hash) ? cp : {}
          items = spec.is_a?(Hash) ? spec['item_count'].to_i : 0
          msg = "Cenová ponuka uložená: #{fmt_eur(c['total'])} · #{c['rows'].to_a.length} riadkov · " \
                "špecifikácia #{items} položiek → #{target}"
          return msg if Array(warnings).empty?

          "#{msg} · POZOR: #{warnings.join(' · ')}"
        end

        # add_/update_ vracaju [polozka|nil, chyby] — zjednotenie na [ok, chyby].
        def ok_pair(result)
          item, errors = result
          [!item.nil? && Array(errors).empty?, errors]
        end

        BUDGET_OP_STATUS = {
          'mode' => 'Cenový režim zmenený.', 'override' => 'Suma riadku prepísaná.',
          'multiplier' => 'Násobok riadku uložený.', 'viz_m2' => 'm² vizualizácie uložené.',
          'appl_included' => 'Spotrebiče v súčte — prepnuté.',
          'custom_add' => 'Položka pridaná.', 'custom_update' => 'Položka upravená.',
          'custom_remove' => 'Položka zmazaná.', 'appliance_add' => 'Spotrebič pridaný.',
          'appliance_update' => 'Spotrebič upravený.', 'appliance_remove' => 'Spotrebič zmazaný.',
          'cp_group' => 'Zaradenie v cenovej ponuke zmenené.'
        }.freeze

        def budget_op_status(data)
          BUDGET_OP_STATUS[data['op'].to_s] || 'Rozpočet uložený.'
        end

        # ↗ v riadku: URL sa NEBERIE z klienta — dohladava sa v modeli podla ID
        # polozky a este raz sanitizuje (BudgetStore.sanitize_url povoluje LEN
        # http/https). Klient tak nema ako podstrcit javascript:/file: adresu.
        def handle_budget_url(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          id = data['id'].to_s
          list = data['kind'].to_s == 'appliance' ? BudgetStore.appliances(model) : BudgetStore.custom_items(model)
          item = list.find { |it| it['id'] == id }
          return set_status('Položka sa nenašla — obnov okno.', true) if item.nil?
          url = BudgetStore.sanitize_url(item['url'])
          return set_status('Položka nemá platnú adresu (http:// alebo https://).', true) if url.nil?
          UI.openURL(url)
          set_status("Otváram #{url}")
        end

        def fmt_eur(value)
          f = value.to_f
          format('%.2f €', f).tr('.', ',')
        end

        # V0.6 E-b: payload rozpoctu z TYCH ISTYCH dat ako kusovnik/semafor
        # (jedna autorita cisel). Zlyhanie NIKDY nezhodi okno — tab Rozpocet
        # ukaze hlasku, zvysok okna zije dalej.
        # ŠT-1b (audit #2): telo v `ProductionCore` — rozpoctove upozornenia su
        # sucastou KONTROLY, ktoru od tejto davky pocita aj okno Studio.
        def budget_payload(model, bom, collected, estimate = nil, hw_exp = nil, smap = nil)
          ProductionCore.budget_payload(model, bom, collected, estimate, hw_exp, smap)
        end

        # Katalog kovania pre scan veku cien; chyba katalogu = scan sa preskoci
        # (vzor edges_map), rozpocet sa nezhodi.
        def hardware_catalog_items
          ProductionCore.hardware_catalog_items
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Výroba',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            # D-77: kusovnik aj rozpocet su tabulky s editovatelnymi bunkami a
            # stlpcom akcii vpravo — v 560 px okne konci prava cast riadku mimo.
            # Rozmery platia LEN pri prvom otvoreni; zapamatane male okno dorovna nx_fit.
            width: 760,
            height: 640,
            min_width: 560,
            min_height: 440,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'production.html'))
          register_callbacks(@dialog) # pred show!
          # ŠT-1b (audit #1) — VEDOMA ZMENA ZIVOTNEHO CYKLU: zatvorenie okna
          # Vyroba uz zvyraznenie hran ani kresbu smeru NEVYPINA. Dovod: oba
          # prepinace sa presunuli do sekcie Kontrola okna Studio a ich TRVALY
          # vstupny bod je rail Inspectora — vypinat ich pri zatvoreni okna,
          # ktore ich uz ani nezobrazuje, by pouzivatelovi zhaslo zvyraznenie
          # zapnute uplne inde. Kontrakt „vypneš a nič v modeli neostane" drzi
          # dalej: stav zije v %APPDATA%, v .skp neostava NIKDY nic a vypnut sa
          # da z railu aj zo Studia. (Detail v docs/ARCHITEKTURA.md.)
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          Engine.register_dialog_fit(dlg, 'production') # D-77: zapamatane male okno sa dorovna
          cb(dlg, 'ready')       { |_p| push_state }
          cb(dlg, 'refresh_bom') { |_p| push_state }
          cb(dlg, 'select_row')  { |p| handle_select(p) }
          cb(dlg, 'vepo_export') { |p| handle_export(p) } # V0.5 C
          cb(dlg, 'hw_csv_export') { |p| handle_hw_csv(p) } # V0.6 D1b
          # ŠT-1b: ⚠ chip v hlavičke — jediná cesta z okna Výroba k zoznamu
          # nálezov. Tab Kontrola zanikol, obsah je v Štúdiu (sekcia `ctrl`).
          cb(dlg, 'open_studio') { |_p| open_studio_control }
          # D-83: skratka z riadku KONTROLY do „Nahradiť UNI…" (okno Materiály).
          # ŠT-1b: riadky kontroly sa presunuli do Štúdia — cesta tu ostáva pre
          # kompatibilitu, kým okno v ŠT-1c nezanikne.
          cb(dlg, 'replace_uni') { |p| handle_replace_uni(p) }
          # D-104/D-105/K2: prepínače zvýraznenia hrán a smeru kresby. Viditeľné
          # UI sa presunulo do lišty sekcie Kontrola v Štúdiu; tieto cesty ostávajú
          # (sú to aj prijímače broadcastu) a zaniknú s oknom v ŠT-1c.
          cb(dlg, 'edge_check_toggle') { |p| do_edge_check(p) }
          cb(dlg, 'edge_check_option') { |p| do_edge_check_option(p) }
          cb(dlg, 'edge_menu_open')    { |_p| Engine.close_edge_menu(:production) }
          cb(dlg, 'grain_check_toggle') { |p| do_grain_check(p) }
          # V0.6 E-b: tab Rozpočet — mutácie, XLSX export, ⚙ Nastavenia, ↗ URL.
          cb(dlg, 'budget_mutate')   { |p| do_budget(p) }
          cb(dlg, 'budget_xlsx')     { |p| handle_budget_xlsx(p) }
          # V0.6 E-b2: zákaznícka cenová ponuka (XLSX — cenová tabuľka + špecifikácia)
          cb(dlg, 'cp_xlsx')         { |p| handle_cp_xlsx(p) }
          cb(dlg, 'budget_open_url') { |p| handle_budget_url(p) }
          cb(dlg, 'budget_settings') { |_p| open_budget_settings }
          # V0.6 E-c: „Prepočítať ceny" — hromadné obnovenie cien z Demosu.
          cb(dlg, 'price_refresh')        { |p| handle_price_refresh(p) }
          cb(dlg, 'price_refresh_cancel') { |_p| handle_price_refresh_cancel }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(production): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'production js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "production cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # Klik z okna: cez panel (flush handshake, B1) alebo priamo, ak panel nezije.
        def handle_select(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.productionRelay(#{data.to_json})")
          else
            do_select(data)
          end
        end

        # Export: rovnaky flush handshake ako select (V0.5 C).
        def handle_export(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.productionRelayExport(#{data.to_json})")
          else
            do_export(data)
          end
        end

        # V0.6 E-b: XLSX rozpočtu — rovnaký flush handshake ako VEPO/CSV.
        def handle_budget_xlsx(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.productionRelayBudget(#{data.to_json})")
          else
            do_budget_xlsx(data)
          end
        end

        # V0.6 E-b2: cenová ponuka — rovnaký flush handshake ako XLSX rozpočtu.
        def handle_cp_xlsx(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.productionRelayCp(#{data.to_json})")
          else
            do_cp_xlsx(data)
          end
        end

        # --- V0.6 E-c: Prepočítať ceny --------------------------------------
        # Jedno tlačidlo obnoví ceny VŠETKÝCH položiek zákazky, ktoré majú väzbu
        # na Demos (dosky, ABS, kovanie). Guardy ako pri každej inej akcii tabu
        # (gen + model_guid — klik zo starého DOM sa odmietne). Zoznam cieľov
        # skladá SERVER z čerstvého rozpočtu: klient posiela len „spusti"
        # (prípadne kind+id JEDNÉHO riadku zo zoznamu starých cien), nikdy nie
        # adresu ani cenu.
        def handle_price_refresh(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return price_refresh_reject('Rozpočet sa medzitým prepočítal — obnovené, skús znova.')
          end
          guid = data['model_guid'].to_s
          if !guid.empty? && guid != model_guid(model)
            push_state
            return price_refresh_reject('Model sa medzitým prepol — obnovené, skús znova.')
          end
          return price_refresh_reject('Prepočet cien už beží.') if PriceRefresh.running?

          targets = price_refresh_targets(model, data)
          if targets.empty?
            push_state
            return price_refresh_reject('Nie je čo obnoviť — položka už nie je v rozpočte alebo nemá väzbu na Demos.')
          end
          pid = PriceRefresh.run(targets, alive: price_refresh_alive(@dialog), emit: price_refresh_emit)
          return price_refresh_reject('Prepočet cien sa nepodarilo spustiť.') if pid.nil?
          # GH #140 P2: beh mohol dobehnúť UŽ TERAZ (synchrónne — napr. bez
          # sieťového transportu alebo samé chybné väzby). Vtedy status už nesie
          # VÝSLEDOK a „Sťahujem…" by ho prepísalo klamlivým priebehom.
          return if PriceRefresh.running_pid != pid

          set_status("Sťahujem ceny z Demosu (#{targets.length}) — medzi položkami je 3 s pauza (pravidlo Demosu).")
        end

        # GH #140 P2: okno prepne modal do „beží" HNEĎ po kliku (odpoveď servera
        # je asynchrónna). Každé odmietnutie štartu preto musí poslať TERMINÁLNY
        # event — inak by progres aj tlačidlo ostali zamknuté a Zrušiť by nemalo
        # čo zrušiť (žiadny beh na serveri neexistuje).
        def price_refresh_reject(msg)
          js("if (window.NX && NX.priceRefresh) NX.priceRefresh(#{{ 'type' => 'rejected', 'error' => msg }.to_json});")
          set_status(msg, true)
        end

        # Zrušenie: ďalšie položky sa už nestiahnu, rozbehnutá dobehne a zapíše
        # sa (jej cena je reálne overená — zahodiť ju by bolo horšie).
        def handle_price_refresh_cancel
          if PriceRefresh.cancel!
            set_status('Prepočet cien sa ukončí po dobehnutí prebiehajúcej položky.')
          else
            set_status('Žiadny prepočet cien nebeží.')
          end
        end

        # Ciele = viazané položky POUŽITÉ v ČERSTVOM rozpočte. kind+id (jeden
        # riadok zo zoznamu starých cien) sa použije len ako FILTER nad týmto
        # serverovým zoznamom — položka mimo rozpočtu sa nefetchuje.
        def price_refresh_targets(model, data)
          collected = fresh_collect(model)
          bom = Bom.compute(collected)
          budget = budget_payload(model, bom, collected)
          return [] unless budget

          all = PriceRefresh.targets_from_budget(budget)
          kind = data['kind'].to_s
          id = data['id'].to_s
          return all if kind.empty? || id.empty?

          all.select { |t| t['kind'] == kind && t['id'] == id }
        end

        # Životnosť behu = TÁ ISTÁ inštancia okna Výroba, z ktorej sa spustil
        # (vzor MaterialsDialog.demos_alive_proc). GH #140 P2: samotné `@dialog`
        # nestačí — zavretie okna počas fetchu a jeho znovuotvorenie by opustený
        # beh „oživilo" (dofetchoval by zvyšok fronty a posielal eventy do NOVÉHO
        # okna). Prepnutie MODELU beh nezastaví: ceny idú do katalógu, ktorý je
        # globálny a na zákazke nezávislý.
        def price_refresh_alive(dlg)
          -> { !dlg.nil? && !@dialog.nil? && @dialog.equal?(dlg) && dlg.visible? }
        end

        def price_refresh_emit
          lambda do |event|
            js("if (window.NX && NX.priceRefresh) NX.priceRefresh(#{event.to_json});")
            next unless event['type'] == 'complete'

            after_price_refresh(event['report'])
          end
        end

        # Po dobehnutí: čerstvý rozpočet (sumy AJ pás cenovej čerstvosti) + refresh
        # ostatných okien nad katalógom — ceny sa práve zmenili globálne.
        def after_price_refresh(report)
          push_state
          begin
            MaterialsDialog.push_catalog if defined?(MaterialsDialog)
            Panel.push_materials if defined?(Panel)
            # ST-1a: ceny sa prave zmenili GLOBALNE — otvorene Studio by inak
            # drzalo stare cisla (audit #10: obe okna v tych istych 5 cestach).
            StudioDialog.refresh_if_open if defined?(StudioDialog)
            # GH #140 P2: prepočet mení AJ ceny kovania — otvorené okno Katalóg
            # kovania by inak držalo starú cenu a starý row_rev (jeho ďalšia
            # úprava by skončila ako konflikt).
            HardwareCatalogDialog.push_items if defined?(HardwareCatalogDialog)
          rescue StandardError => e
            Engine.log_error(e, 'ProductionDialog.after_price_refresh refresh')
          end
          set_status(price_refresh_status(report), price_refresh_report_error?(report))
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.after_price_refresh')
        end

        def price_refresh_report_error?(report)
          report.is_a?(Hash) && report['errors'].to_i.positive?
        end

        def price_refresh_status(report)
          # Vetné tvary bez skloňovania počtu (status je jednoriadkový; plné
          # sklonované zhrnutie ukazuje report v okne).
          r = report.is_a?(Hash) ? report : {}
          parts = ["zmenené #{r['changed'].to_i}", "bez zmeny #{r['unchanged'].to_i}"]
          parts << "chyby #{r['errors'].to_i}" if r['errors'].to_i.positive?
          parts << "zrušené (preskočené #{r['skipped'].to_i})" if r['cancelled']
          "Prepočet cien hotový — #{parts.join(' · ')}."
        end

        # ⚙ z tabu Rozpočet — satelit Nastavenia (sadzby sú GLOBÁLNE, nie per model).
        def open_budget_settings
          return set_status('Okno Nastavenia nie je k dispozícii.', true) unless defined?(SupplierSettingsDialog)

          SupplierSettingsDialog.show
          set_status('Otváram Nastavenia rozpočtu.')
        end

        # --- VEPO pomocnici (V0.5 C) ---------------------------------------
        #
        # ST-1a PR A: telo tychto pomocnikov zije v `ui/production_core.rb` —
        # to iste cita AJ okno Studio (dve kopie by sa casom rozisli a rozdiel
        # by sa ukazal az na vyrobnom vystupe). Tu ostavaju TENKE OBALY
        # s povodnymi menami, signaturami aj privatnostou: panel, pure testy
        # (`send(:vepo_materials)`) aj in-SU runner (`send(:pids_for_problem)`)
        # ich volaju presne takto.

        def vepo_settings
          ProductionCore.vepo_settings
        end

        def save_vepo_settings(attrs)
          ProductionCore.save_vepo_settings(attrs)
        end

        def vepo_materials
          ProductionCore.vepo_materials
        end

        def vepo_base_label(sheet)
          ProductionCore.vepo_base_label(sheet)
        end

        def vepo_disambiguate_variants(labeled)
          ProductionCore.vepo_disambiguate_variants(labeled)
        end

        def vepo_disambiguate(labeled, &block)
          ProductionCore.vepo_disambiguate(labeled, &block)
        end

        def vepo_group_key(sheet)
          ProductionCore.vepo_group_key(sheet)
        end

        def vepo_edge_thicknesses
          ProductionCore.vepo_edge_thicknesses
        end

        def default_project_name(model)
          ProductionCore.default_project_name(model)
        end

        # ST-1a (audit #1): nazov projektu drzi SERVER (mapa `project_names`
        # v %APPDATA%, kluc = model_guid) — vsetky styri exporty citaju TENTO
        # nazov, aby sa dva vystupy tej istej zakazky nemohli volat rozne.
        def project_name(model)
          ProductionCore.project_name(model)
        end

        # Cerstvy RAW zber s dedup tickom (telo v ProductionCore — to iste
        # potrebuje aj okno Studio).
        def fresh_collect(model)
          ProductionCore.fresh_collect(model)
        end

        # V0.6 D1b: nakupny zoznam kovania (telo v ProductionCore).
        def hardware_expansion(model, collected)
          ProductionCore.hardware_expansion(model, collected)
        end

        # CSV kovania: vstup z okna — rovnaky flush handshake ako VEPO export
        # (GH #127 P1: rozpisany edit panela by inak exportoval stare pocty).
        def handle_hw_csv(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.productionRelayHwCsv(#{data.to_json})")
          else
            do_hw_csv(payload)
          end
        end

        # D-83: „Nahradiť UNI…" z riadku KONTROLY. Model sa TU nemeni — len sa
        # otvara okno Materiály s predvyplnenym modalom; samotnu zamenu robi
        # MaterialsDialog s vlastnymi guardmi (scan, odtlacok planu, 1 undo),
        # preto tu netreba flush handshake ako pri selecte/exporte.
        # Vsetky tri guardy bezia na SERVERI (klientovi sa neveri):
        #   gen        — riadok zo stareho DOM (medzitym prepocitany kusovnik),
        #   model_guid — medzitym prepnuty dokument,
        #   uni_id     — material medzitym zmazany/nahradeny/uz nie je UNI.
        # ŠT-1b (audit #10): ⚠ chip hlavicky. Tab Kontrola zanikol, tak chip
        # otvara Studio rovno na sekcii Kontrola — ziadne mrtve tlacidlo a
        # ziadny druhy zoznam nalezov.
        def open_studio_control
          return set_status('Okno Štúdio nie je k dispozícii.', true) unless defined?(StudioDialog)

          StudioDialog.show(open_section: 'ctrl')
          set_status('Otváram Štúdio → Kontrola.')
        end

        # ŠT-1b (audit #13): telo v `ProductionCore` — tu istu skratku ponuka
        # riadok KONTROLY v sekcii `ctrl` okna Studio.
        def handle_replace_uni(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.replace_uni(Sketchup.active_model, data, generation: @generation,
                                                                  status: status_proc,
                                                                  repush: repush_proc)
        end

        # ST-1a PR A: obaly nad ProductionCore (telo tam, mena a privatnost tu).
        # Stabilna identita modelu — zrkadlo MaterialsDialog.model_guid (oneskoreny
        # klik po prepnuti dokumentu nesmie otvorit modal nad inym projektom).
        def model_guid(model)
          ProductionCore.model_guid(model)
        end

        # Katalog dosiek ako mapa pre Validation.run ({ material_id => sheet }).
        def sheets_map
          ProductionCore.sheets_map
        end

        # Katalog ABS pasok ako mapa pre Validation.run ({ abs_id => zaznam }).
        def edges_map
          ProductionCore.edges_map
        end

        # Suhrn KONTROLY do statusu okna/exportu (nalez 6: RED neblokuje export).
        def control_suffix(control)
          ProductionCore.control_suffix(control)
        end

        # ST-1a PR A: vyberove resolvery ziju v ProductionCore (to iste hladanie
        # potrebuje aj okno Studio). Obaly drzia povodne mena AJ privatnost —
        # in-SU runner vola `ProductionDialog.send(:pids_for_problem, ...)`.

        # Nalez 4: PID cielov semaforovej polozky sa hladaju v CERSTVOM modeli podla
        # STABILNEJ identity (owner_id + part_key).
        def pids_for_problem(model, item)
          ProductionCore.pids_for_problem(model, item)
        end

        # D-103: klik na nalez o zhodnom umiestneni oznaci CELU skupinu.
        def pids_for_duplicate(model, item)
          ProductionCore.pids_for_duplicate(model, item)
        end

        # Refs podla kluca z CERSTVEHO bomu; fallback pids (SU testy/kompat).
        def refs_for(bom, data)
          ProductionCore.refs_for(bom, data)
        end

        def push_state
          @generation = @generation.to_i + 1
          model = Sketchup.active_model
          collected = fresh_collect(model)
          bom = Bom.compute(collected)
          # D-19: JEDEN snapshot katalogu (Codex F3 — ziadne opakovane lookupy). smap
          # sluzi semaforu (formaty + hrubky), sheet_sizes odhadu platni.
          smap = sheets_map
          sheet_sizes = smap.each_with_object({}) { |(id, s), out| out[id] = s['sheet_size'] }
          # V0.6 D1b: nakupny zoznam kovania z TOHO ISTEHO zberu (audit F6) +
          # jeho ORANGE do KONTROLY (hardware_unmapped / hardware_code).
          hw_exp = hardware_expansion(model, collected)
          # D-19: odhad platni per material — JEDEN vypocet pre tab Materiály AJ
          # rozpočet (dve cesty by dali dve rôzne čísla platní).
          # M-B1 (F7): UNI počty platní sú len orientačné — flag pre UI.
          estimate = SheetEstimate.estimate(
            bom[:rows], sheet_sizes: sheet_sizes,
            uni_ids: smap.each_with_object({}) { |(id, s), out| out[id] = true if Materials.uni?(s) }
          )
          # V0.6 E-b: rozpočet z TÝCH ISTÝCH dát (BOM + odhad + katalógy + stav zákazky).
          budget = budget_payload(model, bom, collected, estimate, hw_exp, smap)
          # V0.5 D: KONTROLA z TOHO ISTEHO cerstveho zberu (nalez 5).
          # ŠT-1b (audit #2): vypocet vratane zlucenia s upozorneniami ROZPOCTU
          # zije v `ProductionCore` — sekcia Kontrola okna Studio cita PRESNE
          # to iste cislo (semafor, badge navigacie aj ⚠ chip Inspectora).
          control = ProductionCore.control_payload(collected, hardware_expansion: hw_exp,
                                                              budget: budget, sheets: smap)
          data = {
            version: Engine::VERSION,
            gen: @generation,
            model_title: (model.title.to_s.empty? ? 'Bez názvu' : model.title.to_s),
            # D-83: identita modelu pre skratku „Nahradiť UNI…" — klik zo
            # stareho okna po prepnuti dokumentu sa na serveri odmietne.
            model_guid: model_guid(model),
            rows: bom[:rows], sheets: bom[:sheets], edging: bom[:edging],
            # V0.6 C-2 (audit F11): slovensky label kovania TRANZIENTNE —
            # autorita HardwareRules.label_for; do BOM/snapshotu sa neuklada.
            # D-90: to iste pre 'params_label' („rez 597 mm") — format je
            # SERVEROVY (JS ho len vypise), aby tab Výroba a CSV hovorili rovnako.
            hardware: (bom[:hardware] || []).map { |g|
              next g unless g.is_a?(Hash)
              g.merge('label' => HardwareRules.label_for(g['generic_type'] || g[:generic_type]),
                      'params_label' => HardwareRules.params_label(g['params'] || g[:params]))
            },
            # V0.6 D1b: nakupny zoznam setov (rows/unmapped/summary + stav
            # snapshotu setov projektu — invalid = banner, missing = global default).
            hardware_sets: hw_exp,
            summary: bom[:summary],
            # V0.5 D: KONTROLA nahradza povodny warnings tab (nalez 9) — build warnings
            # su v control.items ako kategoria "stavba". counts zo servera (nalez 11) —
            # JS ich NIKDY neprepocitava (header badge, status aj LOG rovnake cisla).
            control: control['items'], counts: control['counts'],
            # D-19: odhad platni per material (rozsah 10-25 %; JS paruje mapou
            # podla material_id — nie indexom, Codex F7)
            sheet_estimate: estimate,
            # V0.6 E-b: celý rozpočet zákazky (sekcie, sumy, vek cien, kontrola).
            # JS z neho LEN číta — žiadne sumy sa v prehliadači nepočítajú.
            budget: budget,
            # D-104: stav zvyraznenia hran bez olepu (tab KONTROLA). Ked je
            # vypnute, NIC sa neskenuje — okno platí nulu navyše.
            edge_check: (defined?(EdgeCheck) ? EdgeCheck.ui_state(model) : nil),
            # K2/D-87: stav kresby smeru dekoru (tab KONTROLA, vedla zvyraznenia
            # hran). Vypnuta = ziadny sken.
            grain_check: (defined?(GrainCheck) ? GrainCheck.ui_state(model) : nil),
            # ST-1a (audit #1): nazov projektu je SERVEROVY UDAJ a okno Vyroba
            # ho uz needituje — ukazuje ho ako TEXT v hlavicke (vystup sa nesmie
            # tvarit ako vstup). Editovatelny input zije v liste Kusovnika
            # v okne Studio; obe okna citaju tuto istu hodnotu.
            # model_key = epocha prepnuti + cesta (GH P2: rovnake tituly nestacia)
            vepo: { project: project_name(model),
                    model_key: "#{@model_epoch.to_i}:#{model.path}",
                    merge_18_36: ProductionCore.merge_18_36 },
            # UI-D3: deep-link z Inspectora. Posiela sa PRAVE RAZ (hodnota sa tu
            # spotrebuje) — inak by kazdy dalsi refresh okna vratil pouzivatela
            # na tab, z ktoreho medzitym odisiel. nil = tab sa neprepina.
            open_tab: consume_pending_tab
          }
          js("NX.setBom(#{data.to_json})")
        end

        # Jednorazove prevzatie deep-link tabu (viz `show`).
        def consume_pending_tab
          t = @pending_tab
          @pending_tab = nil
          TABS.include?(t.to_s) ? t.to_s : nil
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?

          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.js')
        end
      end
    end
  end
end
