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
module Noxun
  module Engine
    module ProductionDialog
      DLG_KEY = 'NoxunEngineProduction'

      class << self
        def show
          dlg = ensure_dialog
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

        # V0.5 C: export VEPO — vstup po relay z panela (edity flushnute) alebo
        # priamo (panel nezije). Poradie: gen check -> flush guard -> vyber
        # priecinka -> CERSTVY BOM -> build -> atomicky zapis -> ulozit settings.
        def do_export(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return set_status('Dáta okna sa medzitým zmenili — skús export znova.', true)
          end
          if data['flush_blocked']
            return set_status('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
          end

          settings = vepo_settings
          last = settings['last_dir']
          start_dir = last.is_a?(String) && File.directory?(last) ? last : nil
          dir = UI.select_directory(title: 'Priečinok pre VEPO export', directory: start_dir)
          return set_status('Export zrušený.') if dir.nil? || dir.to_s.empty?

          model = Sketchup.active_model
          # Nalez 5: JEDEN cerstvy RAW zber -> nad nim compute AJ Validation.run;
          # validaciu EXPLICITNE odovzdame do build (prefix statusu + sekcia KONTROLA
          # v LOGu z TOHO ISTEHO vysledku). Vysledok z DOM je po flushi zastaraly.
          collected = fresh_collect(model)
          bom = Bom.compute(collected)
          control = Validation.run(collected, sheets: sheets_map, edges: edges_map,
                                   hardware_expansion: hardware_expansion(model, collected),
                                   placements: collected[:placements])
          merge = data['merge'] != false
          result = VepoExport.build(
            bom[:rows],
            project: data['project'].to_s,
            materials: vepo_materials,
            edge_thicknesses: vepo_edge_thicknesses,
            validation: control,
            version: Engine::VERSION,
            generated_at: Time.now.strftime('%Y-%m-%d %H:%M'),
            merge_18_36: merge
          )
          if result['groups'].empty? && result['errors'].empty?
            return set_status('Niet čo exportovať — model nemá výrobné dielce.', true)
          end
          # GH P2: aj ked su VSETKY riadky chybne, LOG s dovodmi sa MUSI zapisat
          # (inak by diagnostika chybala presne pri uplne zlyhanom exporte).
          target = VepoExport.write(result, dir)
          # Nalez 6: KONTROLA nikdy neblokuje export; jej suhrn ide do statusu.
          ctrl = control_suffix(control)
          if result['groups'].empty?
            save_vepo_settings('last_dir' => dir, 'merge_18_36' => merge)
            return set_status("Export nevytvoril žiadny CSV — #{result['errors'].length} chybných riadkov. Dôvody v LOGu: #{target}#{ctrl}", true)
          end
          save_vepo_settings('last_dir' => dir, 'merge_18_36' => merge)
          err = result['errors'].empty? ? '' : " · #{result['errors'].length} vyradených riadkov (viď LOG)"
          set_status("VEPO export hotový: #{result['groups'].length} súborov, #{result['total_rows']} riadkov " \
                     "(#{result['total_pieces']} ks) → #{target}#{err}#{ctrl}", !result['errors'].empty?)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.do_export')
          set_status("Chyba exportu: #{e.message}", true)
        end

        # Vstup pre relay z panela (B1): panel uz flushol edity, mozeme vyberat.
        # Klik nesie KLUC riadku, nie pids (Codex GH #48 P2: flush mohol korpus
        # rebuildnut a stare pids zomreli) — refs sa hladaju v CERSTVOM zbere.
        def do_select(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          unless data['gen'].to_i == @generation.to_i # B4: stale klik (iny model/stary DOM)
            push_state if @dialog && @dialog.visible? # re-push len zivemu oknu
            return
          end

          model = Sketchup.active_model
          collected = fresh_collect(model)
          # Nalez 4: semafor klik nesie STABILNY kluc problemu; validacia sa po
          # flushi editov PREPOCITA NANOVO a entity sa dohladaju podla identity
          # (owner_id + part_key), nie podla PID (rebuild ho meni).
          if data['problem_key']
            # GH #127 P2: klik-resolve MUSI ratat s rovnakym vstupom ako
            # push_state — bez hardware_expansion by sa stable kluce novych
            # ORANGE (hardware_unmapped/hardware_code) nikdy nenasli.
            item = Validation.run(collected, sheets: sheets_map, edges: edges_map,
                                  hardware_expansion: hardware_expansion(model, collected),
                                  placements: collected[:placements])['items']
                             .find { |it| it['stable_key'] == data['problem_key'] }
            if item.nil?
              push_state
              return set_status('Kontrola sa medzitým zmenila — obnovené, klikni znova.', true)
            end
            pids = pids_for_problem(model, item)
          else
            pids = refs_for(Bom.compute(collected), data)
          end
          targets = pids.filter_map do |pid|
            ent = model.find_entity_by_persistent_id(pid.to_i)
            ent if ent && ent.valid? && ent.respond_to?(:definition)
          end
          if targets.empty?
            # riadok/polozka medzitym zanikol (flush editov zmenil rozmery/model) —
            # obnov data, nech pouzivatel klikne na aktualny riadok
            push_state
            return set_status('Zoznam sa medzitým zmenil — obnovené, klikni znova.', true)
          end

          Panel.suspend_selection_sync do
            sel = model.selection
            sel.clear
            targets.each { |t| sel.add(t) }
          end
          Panel.push_selected(model, dedup: false) # B2: ziadna mutacia pri selecte
          set_status("Vybraných #{targets.length} položiek v modeli.")
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.do_select')
          set_status("Chyba výberu: #{e.message}", true)
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
          project = data['project'].to_s.strip
          project = default_project_name(model) if project.empty?
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

          project = data['project'].to_s.strip
          project = default_project_name(model) if project.empty?
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

          project = data['project'].to_s.strip
          project = default_project_name(model) if project.empty?
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
        def do_edge_check(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return unless edge_check_guard(data, model)

          # UI-B1 (audit A2): prepnutie ide cez ZDIELANU Engine.toggle_edge_check —
          # tá zavola EdgeCheck.toggle a novy stav rozposle VSETKYM oknam (aj
          # railu Inspectora). Vlastny push tu uz netreba, status je lokalny.
          state = Engine.toggle_edge_check(model)
          set_status(edge_check_status(state))
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.do_edge_check')
          set_status("Chyba zvýraznenia hrán: #{e.message}", true)
        end

        # D-105: prepinace stavov (chyba / mimo pravidla / olepene + „len vybrané").
        # Zapisuju sa do %APPDATA% (nastavenie pocitaca), NIKDY do modelu — preto
        # ziadny flush handshake ani undo krok. Codex audit FIX 4: kluc musi byt
        # z whitelistu a hodnota VYSLOVNE true/false (retazec "false" je v Ruby
        # pravdivy) — inak sa NEZAPISE nic.
        def do_edge_check_option(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return unless edge_check_guard(data, model)

          key = data['key'].to_s
          value = data['value']
          unless EdgeCheck::OPTION_KEYS.include?(key) && (value == true || value == false)
            push_edge_check
            return set_status('Neznáme nastavenie zvýraznenia — nič sa nezmenilo.', true)
          end
          EdgeCheck.set_option(key, value)
          push_edge_check
          set_status(edge_check_option_status(key, value))
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.do_edge_check_option')
          set_status("Chyba nastavenia zvýraznenia: #{e.message}", true)
        end

        # Spolocne serverove guardy oboch akcii zvyraznenia. false = akcia sa
        # NEVYKONA (volajuci uz poslal status aj cerstvy payload).
        # Codex audit FIX 4: guid sa porovnava STRIKTNE — prazdny udaj z klienta
        # uz guard NEOBIDE (obe strany citaju to iste `model_guid`).
        def edge_check_guard(data, model)
          unless defined?(EdgeCheck) && EdgeCheck.available?(model)
            push_edge_check
            set_status('Zvýraznenie hrán vyžaduje SketchUp 2023 alebo novší.', true)
            return false
          end
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            set_status('Okno sa medzitým prepočítalo — obnovené, klikni znova.', true)
            return false
          end
          unless data['model_guid'].to_s == model_guid(model)
            push_state
            set_status('Model sa medzitým prepol — obnovené, klikni znova.', true)
            return false
          end
          true
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

        def edge_check_status(state)
          st = state.is_a?(Hash) ? state : {}
          return 'Zvýraznenie hrán vypnuté — v modeli nič neostalo.' unless st['active']

          opts = st['options'].is_a?(Hash) ? st['options'] : {}
          counts = st['counts'].is_a?(Hash) ? st['counts'] : {}
          parts = []
          parts << "#{counts['missing'].to_i} chýba podľa pravidla" if opts['show_missing']
          parts << "#{counts['extra'].to_i} neolepených mimo pravidla" if opts['show_extra']
          parts << "#{counts['taped'].to_i} olepených" if opts['show_taped']
          return 'Zvýraznenie zapnuté — žiadny stav nie je zapnutý (otvor nastavenie ▾).' if parts.empty?

          extra = st['unresolved'].to_i.positive? ? " · #{st['unresolved'].to_i} sa nedá zvýrazniť" : ''
          "Zvýraznenie zapnuté — #{parts.join(' · ')}#{extra}."
        end

        # D-105: kratke potvrdenie prepnutia (nazvy su TIE ISTE ako v rozbalovacom
        # okne — server je jediny zdroj textov).
        EDGE_OPTION_LABELS = {
          'show_missing' => 'Chýba podľa pravidla', 'show_extra' => 'Neolepené mimo pravidla',
          'show_taped' => 'Olepené', 'taped_selected_only' => 'Olepené — len vybrané'
        }.freeze

        def edge_check_option_status(key, value)
          "#{EDGE_OPTION_LABELS[key] || key}: #{value ? 'zapnuté' : 'vypnuté'}."
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
        def budget_payload(model, bom, collected, estimate = nil, hw_exp = nil, smap = nil)
          smap ||= sheets_map
          est = estimate || SheetEstimate.estimate(
            bom[:rows],
            sheet_sizes: smap.each_with_object({}) { |(id, s), out| out[id] = s['sheet_size'] },
            uni_ids: smap.each_with_object({}) { |(id, s), out| out[id] = true if Materials.uni?(s) }
          )
          exp = hw_exp || hardware_expansion(model, collected)
          Budget.payload_for(model, bom, sheets: smap, edges: (edges_map || {}),
                             hardware_expansion: exp, hardware_catalog: hardware_catalog_items,
                             sheet_estimate: est)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.budget_payload')
          nil
        end

        # Katalog kovania pre scan veku cien; chyba katalogu = scan sa preskoci
        # (vzor edges_map), rozpocet sa nezhodi.
        def hardware_catalog_items
          return nil unless defined?(HardwareCatalog)

          HardwareCatalog.items
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.hardware_catalog_items')
          nil
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
          # D-104: zvyraznenie hran je nastroj TOHTO okna — zatvorenie ho vypne,
          # aby v modeli neostalo nic, co sa neda vypnut (kontrakt „vypneš a nič
          # v modeli neostane").
          @dialog.set_on_closed do
            @dialog = nil
            begin
              EdgeCheck.disable! if defined?(EdgeCheck)
            rescue StandardError => e
              Engine.log_error(e, 'ProductionDialog.on_closed edge_check')
            end
          end
          @dialog
        end

        def register_callbacks(dlg)
          Engine.register_dialog_fit(dlg, 'production') # D-77: zapamatane male okno sa dorovna
          cb(dlg, 'ready')       { |_p| push_state }
          cb(dlg, 'refresh_bom') { |_p| push_state }
          cb(dlg, 'select_row')  { |p| handle_select(p) }
          cb(dlg, 'vepo_export') { |p| handle_export(p) } # V0.5 C
          cb(dlg, 'hw_csv_export') { |p| handle_hw_csv(p) } # V0.6 D1b
          # D-83: skratka z riadku KONTROLY do „Nahradiť UNI…" (okno Materiály).
          cb(dlg, 'replace_uni') { |p| handle_replace_uni(p) }
          # D-104: prepínač zvýraznenia hrán (tab KONTROLA). Žiadny flush
          # handshake — model sa nemení, len sa nad ním kreslí.
          cb(dlg, 'edge_check_toggle') { |p| do_edge_check(p) }
          # D-105: prepínače stavov v rozbaľovacom okne (zapisujú sa do %APPDATA%).
          cb(dlg, 'edge_check_option') { |p| do_edge_check_option(p) }
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

        VEPO_SETTINGS_FILE = 'vepo_settings.json'

        # Fallback na defaulty pri poskodenom subore (audit F9) — export nikdy
        # nesmie zablokovat okno Vyroba kvoli nastaveniam.
        def vepo_settings
          path = File.join(Materials.dir, VEPO_SETTINGS_FILE)
          return {} unless JsonFileStore.available?(path)
          data = JsonFileStore.read(path)
          data.is_a?(Hash) ? data : {}
        rescue StandardError
          {}
        end

        def save_vepo_settings(attrs)
          path = File.join(Materials.dir, VEPO_SETTINGS_FILE)
          JsonFileStore.write(path, vepo_settings.merge(attrs))
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.save_vepo_settings')
        end

        # VEPO stlpec material: dekor + typ (hrubka je vlastny stlpec); fallback
        # family, fallback material_id. Tvar mapy definuje audit F7.
        #
        # 2A-4b (audit F8 + GH #93 P1): 'label' je EXPORTNY label — grouping +
        # nazov suboru + CSV stlpec. INVARIANT nie je "decor+typ", ale STABILNY
        # TEXT pre te iste realne data: migracia rozdelila "K009 PW" na cislo
        # "K009" + strukturu "PW", takze exportny label MUSI byt zlozeny
        # decor+structure+typ — zmigrovany zaznam da presne povodny text
        # ("K009 PW DTDL") a dve struktury toho isteho cisla sa NEZLEJU do
        # jedneho VEPO bucketu. Legacy zaznam (bez struktury) = dnesny tvar.
        # Strazi zlaty test (legacy fixture == zmigrovana fixture, bajtovo).
        # decor_name ide VYHRADNE do 'display' (zobrazovaci/LOG label).
        # GH #93 P1 (2. kolo): label sklada AJ decor_name — legacy "W1000 ST9
        # Biela" sa migruje na cislo+strukturu+NAZOV, takze bez nazvu by sa
        # export zmenil ("W1000 ST9 DTDL" != "W1000 ST9 Biela DTDL"). Kolizia
        # labelu MEDZI roznymi skupinami (rovnake cislo+struktura+typ dvoch
        # vyrobcov — len SCHEMA 2 stav bez legacy precedensu) dostava prefix
        # vyrobcu, aby sa buckety nezliali.
        def vepo_materials
          labeled = Materials.sheets.map { |s| [s, vepo_base_label(s)] }
          # 1. kolo: kolizia medzi skupinami -> prefix vyrobcu.
          labeled = vepo_disambiguate(labeled) do |s, l|
            [s['manufacturer'].to_s.strip, l].reject(&:empty?).join(' ')
          end
          # GH #93 P2 (3. kolo): aj PO prefixe mozu dve skupiny TOHO ISTEHO
          # vyrobcu zlozit rovnaky text ("K009 PW"+"" vs "K009"+"PW") — druhe
          # kolo pridava stabilny skupinovy sufix, aby sa VEPO buckety nezliali.
          labeled = vepo_disambiguate(labeled) do |s, l|
            "#{l} [#{vepo_group_key(s)}]"
          end
          # GH #93 P1 (4. kolo): kolizia VNUTRI skupiny — dva PD varianty s inym
          # formatom (4100×600 vs 4100×920) maju rovnaky label aj group_key;
          # format je sucast identity PD variantu, do labelu ide pri kolizii.
          labeled = vepo_disambiguate_variants(labeled)
          # Finalna poistka (GH #93 5. kolo): ak by po vsetkych kolach ostala
          # kolizia, rozhodne material_id — bucket sa NIKDY nesmie zliat.
          labeled = vepo_disambiguate(labeled) { |s, l| "#{l} [#{s['material_id']}]" }
          labeled.each_with_object({}) do |(s, l), out|
            entry = { 'label' => l }
            # GH #93 P2 (9. kolo): ked label nesie technicke disambiguatory
            # (vyrobca/skupina/format/ID), LOG ukazuje LUDSKY zaklad cez
            # 'display' — inak by display_labels cesta VepoExportu nikdy nezila.
            human = vepo_base_label(s)
            entry['display'] = human unless human.empty? || human == l
            out[s['material_id']] = entry
          end
        end

        # Ludsky zaklad labelu (cislo struktura nazov typ; fallback family/id) —
        # zdiela ho kompozicia exportneho labelu aj 'display' pre LOG.
        def vepo_base_label(s)
          # 2B-2: rub zasteny patri do labelu VZDY (obchodna identita produktu
          # — Demos vzor "Zastena K551/K552"; bez neho by sa dva ruby zliali).
          back = s['back_decor'].to_s.strip
          back = "/#{[back, s['back_structure'].to_s.strip].reject(&:empty?).join(' ')}" unless back.empty?
          label = [s['decor'], s['structure'], s['decor_name'], s['type'], back]
                  .map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
          label = s['family'].to_s.strip if label.empty?
          label = s['material_id'].to_s if label.empty?
          label
        end

        # Kolizia labelu medzi VARIANTMI (rovnaka skupina): zaznamu s formatom
        # v identite (PD + ZASTENA — 2B-2 flag F10) sa prida "D×S" (cele mm) —
        # identita zakazuje uplne duplicity, takze vysledok je unikatny.
        def vepo_disambiguate_variants(labeled)
          by_label = labeled.group_by { |(_s, l)| l }
          labeled.map do |(s, l)|
            next [s, l] unless by_label[l].length > 1 && Materials.format_in_identity?(s['type'])
            fmt = Materials.size_key(s['sheet_size'])
            # GH #93 P1 (5. kolo): format su mm Floaty — .round by zlial 4100.1
            # a 4100.2; %g drzi normalizovanu presnost size_key (round(2)) a
            # rozne kluce daju VZDY rozny text.
            fmt ? [s, "#{l} #{fmt.map { |x| format('%g', x) }.join('×')}"] : [s, l]
          end
        end

        # Jedno kolo rozlisenia labelov: label zdielany VIACERYMI skupinami sa
        # prepise blokom (zaznamy tej istej skupiny dostanu rovnaky vysledok),
        # unikatne labely sa nemenia.
        def vepo_disambiguate(labeled)
          groups_per = labeled.group_by { |(_s, l)| l }.transform_values do |same|
            same.map { |(r, _l)| vepo_group_key(r) }.uniq
          end
          labeled.map do |(s, l)|
            groups_per[l].length > 1 ? [s, yield(s, l)] : [s, l]
          end
        end

        # Kluc skupiny pre koliznu kontrolu labelu (group_id, fallback vyrobca).
        def vepo_group_key(s)
          gid = s['group_id'].to_s.strip
          gid.empty? ? "man:#{s['manufacturer'].to_s.strip}" : gid
        end

        def vepo_edge_thicknesses
          Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a['thickness'].to_f }
        end

        # Default nazvu projektu z ULOZENEHO suboru (audit F10 — nie z titulku).
        def default_project_name(model)
          p = model.path.to_s
          p.empty? ? 'projekt' : File.basename(p, '.*')
        end

        # Cerstvy RAW zber s dedup tickom (Codex GH #48 P2: cerstve kopie mozu
        # zdielat ID — rovnaky sync tick ako push_selected, inak BOM zlieva
        # vlastnikov a klik-select je nejednoznacny). JEDEN collect pre kusovnik,
        # semafor aj VEPO (nalez 5) — compute/Validation citaju TEN ISTY zber.
        def fresh_collect(model)
          CabinetBuilder.dedup_copies(model) if defined?(CabinetBuilder)
          BoardBuilder.dedup_copies(model) if defined?(BoardBuilder)
          Bom.collect(model)
        end

        # V0.6 D1b: nakupny zoznam kovania. Stav snapshotu setov (audit F9):
        # :ok = snapshot projektu · :missing = projekt este sety nezmrazil ->
        # global default LEN NA CITANIE (okno Vyroba je read-only; zmrazi ho az
        # prva stavba/zmena predvolby) · :invalid = NIC sa nemapuje (vsetko
        # unmapped ORANGE) + banner, NIKDY tichy fallback na dnesny global.
        def hardware_expansion(model, collected)
          status, state = HardwareSets.project_state_status(model)
          if status == :missing
            lib = HardwareSets.load
            by_id = {}
            lib['sets'].each { |s| by_id[s['set_id']] = s }
            state = { 'mapping' => lib['mapping'], 'sets' => by_id }
          end
          exp = HardwareSets.expand(
            Array(collected[:hardware]), state,
            cabinet_overrides: collected[:cabinet_sets].is_a?(Hash) ? collected[:cabinet_sets] : {},
            catalog: HardwareCatalog.items
          )
          # H1b (audit FIX 9 UI): dovod dostane SK text uz na SERVERI — tab
          # Kovanie aj CSV citaju to iste 'reason_sk' (JS ziadny vlastny
          # preklad enumu nema).
          exp['unmapped'] = Array(exp['unmapped']).map do |u|
            u.is_a?(Hash) ? u.merge('reason_sk' => HardwareSets.unmapped_reason_sk(u)) : u
          end
          exp.merge('state_status' => status.to_s)
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.hardware_expansion')
          nil
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
        def handle_replace_uni(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return set_status('Kontrola sa medzitým zmenila — obnovené, klikni znova.', true)
          end
          guid = data['model_guid'].to_s
          if !guid.empty? && guid != model_guid(model)
            push_state
            return set_status('Model sa medzitým prepol — obnovené, klikni znova.', true)
          end
          uni_id = data['uni_id'].to_s
          sheet = defined?(Materials) ? Materials.sheet(uni_id) : nil
          unless sheet && Materials.uni?(sheet)
            push_state
            return set_status('Materiál už nie je UNI (medzitým sa zmenil) — kontrola obnovená.', true)
          end
          unless defined?(MaterialsDialog) && MaterialsDialog.request_replace_uni(uni_id, model)
            return set_status('Okno Materiály sa nepodarilo otvoriť.', true)
          end
          set_status("Otváram „Nahradiť UNI…“ pre #{uni_id}.")
        end

        # Stabilna identita modelu — zrkadlo MaterialsDialog.model_guid (oneskoreny
        # klik po prepnuti dokumentu nesmie otvorit modal nad inym projektom).
        def model_guid(model)
          model && model.respond_to?(:guid) ? model.guid.to_s : ''
        rescue StandardError
          ''
        end

        # Katalog dosiek ako mapa pre Validation.run ({ material_id => sheet }).
        def sheets_map
          return {} unless defined?(Materials)

          Materials.sheets.each_with_object({}) { |s, out| out[s['material_id']] = s }
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.sheets_map')
          {}
        end

        # Katalog ABS pasok ako mapa pre Validation.run ({ abs_id => zaznam }) —
        # 2A-2 (F6): kontrola abs_missing (hrana s paskou mimo katalogu). Pri
        # chybe vraciame nil (= kontrola sa preskoci), NIE prazdnu mapu — tá by
        # falosne oznacila vsetky olepene hrany.
        def edges_map
          return nil unless defined?(Materials)

          Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a }
        rescue StandardError => e
          Engine.log_error(e, 'ProductionDialog.edges_map')
          nil
        end

        # Suhrn KONTROLY do statusu okna/exportu (nalez 6: RED neblokuje export).
        def control_suffix(control)
          c = control.is_a?(Hash) ? (control['counts'] || {}) : {}
          return '' if c['total'].to_i.zero?

          " · KONTROLA: #{c['red'].to_i}× RED, #{c['orange'].to_i}× ORANGE (v LOGu)"
        end

        # Nalez 4: PID cielov semaforovej polozky sa hladaju v CERSTVOM modeli podla
        # STABILNEJ identity (owner_id + part_key). Bez part_key = korpus/doska ako
        # celok (vypnute kovanie, korpusove build warning). Vnorene dielce sa vyberaju
        # cez persistent_id (rovnaka cesta ako refs_for).
        def pids_for_problem(model, item)
          # D-103 (Codex audit FIX 4): nalez „dva kusy na jednom mieste" ma VLASTNU
          # adresu — presne tie top-level objekty daneho druhu. Vseobecna vetva nizsie
          # by pri korpuse pribalila aj odpojene dielce s tym istym cabinet_id.
          return pids_for_duplicate(model, item) if item['category'].to_s == Validation::CAT_DUPLICATE

          oid = item['owner_id'].to_s
          pkey = item['part_key'].to_s
          out = []
          model.entities.grep(Sketchup::ComponentInstance).each do |inst|
            case Store.kind(inst)
            when 'cabinet'
              next unless Store.get(inst, 'cabinet_id').to_s == oid

              if pkey.empty?
                out << inst.persistent_id
              else
                found = []
                inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
                  next unless Store.kind(pi) == 'part'
                  found << pi.persistent_id if Store.get(pi, 'part_key').to_s == pkey
                end
                # Codex GH #65 P2: build warning moze mierit na dielec, ktory NEBOL
                # postaveny (part_skipped_degenerate, shelf_skipped_shallow_zone) —
                # ziadna entita s tym klucom neexistuje. Fallback: oznac vlastnika
                # (cely korpus), nie prazdny vyber s hlaskou o zmene zoznamu.
                out.concat(found.empty? ? [inst.persistent_id] : found)
              end
            when 'board'
              # Doska JE vlastnik — part_key sa nefiltruje (warning na dosku
              # oznaci dosku aj pri kluci nepostaveneho detailu).
              out << inst.persistent_id if Store.get(inst, 'id').to_s == oid
            when 'part'
              if Store.get(inst, 'cabinet_id').to_s == oid && (pkey.empty? || Store.get(inst, 'part_key').to_s == pkey)
                out << inst.persistent_id
              end
            end
          end
          out.compact.uniq
        end

        # D-103: klik na nalez o zhodnom umiestneni oznaci CELU skupinu (obe/vsetky
        # zhodne umiestnene skrinky ci dosky), aby pouzivatel videl, co presne mazat.
        # Identita je (dup_kind + dup_owner_ids) — zbierana zo SERVERA, klient ju
        # neposiela; hlada sa VYHRADNE medzi top-level objektmi daneho druhu.
        def pids_for_duplicate(model, item)
          kind = item['dup_kind'].to_s
          ids = Array(item['dup_owner_ids']).map(&:to_s).reject(&:empty?)
          return [] if kind.empty? || ids.empty?

          id_key = kind == 'cabinet' ? 'cabinet_id' : 'id'
          out = []
          model.entities.grep(Sketchup::ComponentInstance).each do |inst|
            next unless Store.kind(inst).to_s == kind
            out << inst.persistent_id if ids.include?(Store.get(inst, id_key).to_s)
          end
          out.compact.uniq
        end

        # Refs podla kluca z CERSTVEHO bomu; fallback pids (SU testy/kompat).
        def refs_for(bom, data)
          if data['parts_key']
            row = bom[:rows].find { |r| r['key'] == data['parts_key'] }
            row ? row['refs'].map { |x| x['pid'] } : []
          elsif data['hw_key']
            g = bom[:hardware].find { |x| x['key'] == data['hw_key'] }
            g ? g['breakdown'].map { |b| b['owner_pid'] } : []
          else
            Array(data['pids'])
          end.compact.uniq
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
          control = Validation.run(collected, sheets: smap, edges: edges_map,
                                   hardware_expansion: hw_exp,
                                   placements: collected[:placements])
          # E-b: upozornenia rozpočtu sú kategória „budget" v TOM ISTOM zozname —
          # counts (badge, tab, status) tak ostávajú jedno číslo zo servera.
          control = Validation.with_budget(control, budget['budget_check']) if budget
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
            # V0.5 C: default projektu + zapamatany merge (JS input lifecycle F10);
            # model_key = epocha prepnuti + cesta (GH P2: rovnake tituly nestacia)
            vepo: { default_project: default_project_name(model),
                    model_key: "#{@model_epoch.to_i}:#{model.path}",
                    merge_18_36: vepo_settings['merge_18_36'] != false }
          }
          js("NX.setBom(#{data.to_json})")
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
