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

        # EngineAppObserver: prepnutie/otvorenie modelu = nove data + nova generacia
        # (stary DOM klik sa odmietne genom aj keby ID sedeli — dva Untitled apod.)
        def on_model_changed(_model)
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
          bom = fresh_bom(model)
          merge = data['merge'] != false
          result = VepoExport.build(
            bom[:rows],
            project: data['project'].to_s,
            materials: vepo_materials,
            edge_thicknesses: vepo_edge_thicknesses,
            warnings: bom[:warnings],
            version: Engine::VERSION,
            generated_at: Time.now.strftime('%Y-%m-%d %H:%M'),
            merge_18_36: merge
          )
          if result['groups'].empty?
            msg = if result['errors'].empty?
                    'Niet čo exportovať — model nemá výrobné dielce.'
                  else
                    "Export nevytvoril žiadny súbor — #{result['errors'].length} chybných riadkov (viď panel Upozornenia)."
                  end
            return set_status(msg, true)
          end

          target = VepoExport.write(result, dir)
          save_vepo_settings('last_dir' => dir, 'merge_18_36' => merge)
          err  = result['errors'].empty? ? '' : " · #{result['errors'].length} chýb (viď LOG)"
          warn = Array(bom[:warnings]).empty? ? '' : " · #{Array(bom[:warnings]).length} upozornení stavby (v LOGu)"
          set_status("VEPO export hotový: #{result['groups'].length} súborov, #{result['total_rows']} riadkov " \
                     "(#{result['total_pieces']} ks) → #{target}#{err}#{warn}", !result['errors'].empty?)
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
          bom = fresh_bom(model)
          pids = refs_for(bom, data)
          targets = pids.filter_map do |pid|
            ent = model.find_entity_by_persistent_id(pid.to_i)
            ent if ent && ent.valid? && ent.respond_to?(:definition)
          end
          if targets.empty?
            # riadok medzitym zanikol (flush editov zmenil rozmery/model) —
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

        private

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Výroba',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 560,
            height: 520,
            min_width: 420,
            min_height: 340,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'production.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          cb(dlg, 'ready')       { |_p| push_state }
          cb(dlg, 'refresh_bom') { |_p| push_state }
          cb(dlg, 'select_row')  { |p| handle_select(p) }
          cb(dlg, 'vepo_export') { |p| handle_export(p) } # V0.5 C
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
        def vepo_materials
          Materials.sheets.each_with_object({}) do |s, out|
            label = "#{s['decor']} #{s['type']}".strip
            label = s['family'].to_s.strip if label.empty?
            label = s['material_id'].to_s if label.empty?
            out[s['material_id']] = { 'label' => label }
          end
        end

        def vepo_edge_thicknesses
          Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a['thickness'].to_f }
        end

        # Default nazvu projektu z ULOZENEHO suboru (audit F10 — nie z titulku).
        def default_project_name(model)
          p = model.path.to_s
          p.empty? ? 'projekt' : File.basename(p, '.*')
        end

        # Cerstvy zber s dedup tickom (Codex GH #48 P2: cerstve kopie mozu
        # zdielat ID — rovnaky sync tick ako push_selected, inak BOM zlieva
        # vlastnikov a klik-select je nejednoznacny).
        def fresh_bom(model)
          CabinetBuilder.dedup_copies(model) if defined?(CabinetBuilder)
          BoardBuilder.dedup_copies(model) if defined?(BoardBuilder)
          Bom.compute(Bom.collect(model))
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
          bom = fresh_bom(model)
          data = {
            version: Engine::VERSION,
            gen: @generation,
            model_title: (model.title.to_s.empty? ? 'Bez názvu' : model.title.to_s),
            rows: bom[:rows], sheets: bom[:sheets], edging: bom[:edging],
            hardware: bom[:hardware], warnings: bom[:warnings], summary: bom[:summary],
            # V0.5 C: default projektu + zapamatany merge (JS input lifecycle F10)
            vepo: { default_project: default_project_name(model),
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
