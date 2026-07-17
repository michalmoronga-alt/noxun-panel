# frozen_string_literal: true
# Noxun Engine — dialog "Pravidla kovania" (V0.4 faza 1, standard 6.2: pravidla su
# JSON editovatelne panelom, nie rucne v subore). Samostatny HtmlDialog (zarodok
# buduceho velkeho okna KOVANIE zo SYSTEM/07) — sprava pravidiel sa nerobi popri
# kresleni, preto nezije v Inspector paneli.
#
# ZDROJE A ZIVOTNY CYKLUS (audit K2/K3):
#   - Edituju sa PROJEKTOVE pravidla (snapshot v NOXUN dict na modeli). Ulozenie =
#     zapis snapshotu + prestavba VSETKYCH korpusov v JEDNEJ operacii (rebuild_many
#     s blokom) -> 1x undo vrati pravidla aj geometriu naraz.
#   - "Ulozit aj ako globalnu predvolbu" navyse zapise %APPDATA% kniznicu (default
#     pre NOVE projekty). Globalny zapis nie je sucast undo (je to preferencia).
#   - "Nacitat globalne predvolby" len naplni formular — plati az po Ulozit.
require 'json'

module Noxun
  module Engine
    module RulesDialog
      DLG_KEY = 'noxun_engine_rules'

      class << self
        def show
          dlg = ensure_dialog
          if dlg.visible?
            dlg.bring_to_front
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'RulesDialog.show')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Pravidlá kovania',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 460,
            height: 560,
            min_width: 380,
            min_height: 420,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'rules.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          cb(dlg, 'ready')       { |_p| push_state }
          cb(dlg, 'save_rules')  { |p| handle_save(p) }
          cb(dlg, 'load_global') { |_p| push_global }
          # Diagnostika JS chyb (vzor panel.rb): priamo, NIE cez cb — chyba v logovani
          # nesmie spustit set_status a slucku.
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(rules): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'rules js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "rules cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # --- Ruby -> JS -----------------------------------------------------

        # Stav pre formular: projektove pravidla (ak su), inak globalne.
        def push_state
          model = Sketchup.active_model
          project = HardwareRules.project_rules(model)
          data = {
            version: Engine::VERSION,
            rules: project || HardwareRules.load,
            source: project ? 'project' : 'global',
            cabinets: cabinets(model).size
          }
          js("RD.init(#{data.to_json})")
        end

        def push_global
          js("RD.setRules(#{HardwareRules.load.to_json}, 'global')")
          set_status('Načítané globálne predvoľby — platia až po Uložiť.')
        end

        def set_status(msg, error = false)
          js("RD.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?
          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'RulesDialog.js')
        end

        # --- akcie ----------------------------------------------------------

        # Ulozi pravidla do projektu + prestavia vsetky korpusy (1 undo krok).
        def handle_save(payload)
          model = Sketchup.active_model
          data = JSON.parse(payload.to_s)
          rules = HardwareRules.normalize_rules(data['rules'])
          return set_status('Žiadne platné pravidlá — nič sa neuložilo.', true) if rules.empty?

          jobs = cabinets(model).map { |c| [c, CabinetBuilder.config_to_params(Store.config(c) || {})] }
          CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: pravidla kovania') do
            raise 'Pravidlá sa nepodarilo uložiť do projektu.' unless HardwareRules.set_project_rules(model, rules)
          end

          global_note = ''
          if data['also_global']
            global_note = HardwareRules.write(rules) ? ' + globálna predvoľba' : ' (globálny zápis zlyhal!)'
          end
          set_status("Pravidlá uložené do projektu#{global_note} — prestavaných #{jobs.size} skriniek.")
          push_state
          Panel.push_selected(model) if defined?(Panel) # refresh sekcie Kovanie v paneli
        end

        def cabinets(model)
          out = []
          Ids.each_cabinet(model) { |i| out << i }
          out
        end
      end
    end
  end
end
