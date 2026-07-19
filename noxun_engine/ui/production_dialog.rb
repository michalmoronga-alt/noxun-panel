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

        # Vstup pre relay z panela (B1): panel uz flushol edity, mozeme vyberat.
        def do_select(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          unless data['gen'].to_i == @generation.to_i # B4: stale klik (iny model/stary DOM)
            push_state if @dialog && @dialog.visible? # re-push len zivemu oknu
            return
          end

          model = Sketchup.active_model
          pids = Array(data['pids']).map(&:to_i).uniq
          targets = pids.filter_map do |pid|
            ent = model.find_entity_by_persistent_id(pid)
            ent if ent && ent.valid? && ent.respond_to?(:definition)
          end
          if targets.empty?
            return set_status('Dielce sa v modeli nenašli — Obnov zoznam.', true)
          end

          Panel.suspend_selection_sync do
            sel = model.selection
            sel.clear
            targets.each { |t| sel.add(t) }
          end
          Panel.push_selected(model, dedup: false) # B2: ziadna mutacia pri selecte
          set_status("Vybraných #{targets.length} z #{pids.length} položiek v modeli.")
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

        def push_state
          @generation = @generation.to_i + 1
          model = Sketchup.active_model
          bom = Bom.compute(Bom.collect(model))
          data = {
            version: Engine::VERSION,
            gen: @generation,
            model_title: (model.title.to_s.empty? ? 'Bez názvu' : model.title.to_s),
            rows: bom[:rows], sheets: bom[:sheets], edging: bom[:edging],
            hardware: bom[:hardware], warnings: bom[:warnings], summary: bom[:summary]
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
