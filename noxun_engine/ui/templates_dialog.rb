# frozen_string_literal: true
# Noxun Engine — dialog "Sablony" (V0.4.5 D2). Satelitne okno (vzor RulesDialog):
# SPRAVA sablon (ulozit oznaceny korpus / pouzit na oznaceny / vymazat) zije tu;
# v Inspector paneli ostal len rychly vyber sablony vo vkladacej karte.
# Handlery su PRESUNUTE z Panel (actions_templates.rb) — panel ich uz nevola;
# merge_template logika (zachovanie part_overrides + hardware_overrides ciela)
# sa pri presune NEMENI.
#
# Sablony su GLOBALNE (%APPDATA%, TemplateStore) — nie su viazane na model,
# preto dialog nepotrebuje refresh pri prepnuti dokumentu; "oznaceny korpus"
# sa hlada cerstvo pri kazdej akcii.
require 'json'

module Noxun
  module Engine
    module TemplatesDialog
      DLG_KEY = 'noxun_engine_templates'

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
          Engine.log_error(e, 'TemplatesDialog.show')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Šablóny',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 420,
            height: 460,
            min_width: 360,
            min_height: 320,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'templates.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          cb(dlg, 'ready')      { |_p| push_state }
          cb(dlg, 'tpl_apply')  { |p| handle_apply(p) }
          cb(dlg, 'tpl_delete') { |p| handle_delete(p) }
          cb(dlg, 'tpl_save')   { |_p| handle_save }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(templates): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'templates js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "templates cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # --- Ruby -> JS -----------------------------------------------------

        def push_state
          model = Sketchup.active_model
          cab = Panel.find_cabinet(model)
          cab_type = cab ? ((Store.config(cab) || {})['type'] || 'lower') : nil
          data = {
            version: Engine::VERSION,
            templates: Panel.template_list,
            selected_cab: cab ? Store.get(cab, 'cabinet_id') : nil,
            selected_type: cab_type # guard: apply len na rovnaky typ (dolna/horna)
          }
          js("TD.init(#{data.to_json})")
        end

        def set_status(msg, error = false)
          js("TD.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?
          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'TemplatesDialog.js')
        end

        # --- akcie (presunute z Panel actions_templates.rb) -----------------

        # Ulozi OZNACENY korpus ako sablonu (nazov cez inputbox, prepis s potvrdenim).
        def handle_save
          model = Sketchup.active_model
          cab = Panel.find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus — šablóna sa ukladá z neho.', true) if cab.nil?

          config = Panel.template_config_from(Store.config(cab) || {})
          res = UI.inputbox(['Nazov sablony:'], [Panel.suggest_template_name(cab, {})], 'Ulozit sablonu')
          return if res == false # zrusene

          name = res[0].to_s.strip
          return set_status('Prázdny názov — zrušené.', true) if name.empty?

          if TemplateStore.find(name) &&
             UI.messagebox("Sablona \"#{name}\" existuje. Prepisat?", MB_YESNO) != IDYES
            return set_status('Zrušené — šablóna nezmenená.')
          end
          TemplateStore.upsert(name, config)
          after_change("Šablóna \"#{name}\" uložená.")
        end

        def handle_delete(payload)
          name = JSON.parse(payload.to_s)['template'].to_s
          return set_status('Vyber šablónu na vymazanie.', true) if name.empty?
          return unless UI.messagebox("Vymazat sablonu \"#{name}\"?", MB_YESNO) == IDYES

          TemplateStore.delete(name)
          after_change("Šablóna \"#{name}\" vymazaná.")
        end

        # Pouzije sablonu na oznaceny korpus. MERGE, nie nahradenie: konstrukcne
        # kluce zo sablony; materialy + part_overrides + hardware_overrides CIELA
        # zostavaju (sablona ich nenesie — viazane na konkretne dielce zdroja).
        def handle_apply(payload)
          name = JSON.parse(payload.to_s)['template'].to_s
          tpl = TemplateStore.find(name)
          return set_status('Šablóna sa nenašla.', true) if tpl.nil?
          model = Sketchup.active_model
          cab = Panel.find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus.', true) if cab.nil?

          # Typovy guard aj TU, nie len v HTML disabled (Codex PR #29): pri zavretom
          # paneli sa zmeny vyberu nesleduju a stale enabled riadok by prestavil
          # dolnu skrinku na hornu (ci naopak).
          cab_type = (Store.config(cab) || {})['type'] || 'lower'
          tpl_type = (tpl['config'] || {})['type'] || 'lower'
          if tpl_type != cab_type
            push_state # obnov disabled stav podla aktualneho vyberu
            return set_status("Šablóna je pre iný typ (#{tpl_type == 'upper' ? 'horná' : 'dolná'}) než označená skrinka — nepoužitá.", true)
          end

          merged = merge_template(Panel.existing_params(cab), tpl['config'])
          Panel.suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, merged)
            Panel.reselect(model, cab)
          end
          set_status("Šablóna \"#{name}\" použitá na #{Store.get(cab, 'cabinet_id')}.")
          Panel.push_selected(model)
        end

        def merge_template(target_params, tpl_config)
          merged = tpl_config.dup
          merged['part_overrides'] = target_params['part_overrides'] || {}
          merged['hardware_overrides'] = target_params['hardware_overrides'] || []
          # D-13 (Codex F3): legacy sablona BEZ plinth_recess nesmie cielovy korpus
          # ticho stiahnut na novy default — chybajuci kluc = zachovaj hodnotu ciela.
          merged['plinth_recess'] = target_params['plinth_recess'] unless tpl_config.key?('plinth_recess')
          %w[material_id front_material_id back_material_id].each do |k|
            tv = Panel.present_str(tpl_config[k])
            merged[k] = tv || target_params[k]
          end
          merged
        end

        # Po zmene kniznice: refresh dialogu + quick-pick selectu v paneli.
        def after_change(msg)
          set_status(msg)
          push_state
          Panel.push_templates
        end

        # Volane z Panel.push_selected pri kazdej zmene vyberu: disabled stav
        # "Pouzit na oznaceny" (+ typovy guard) musi sledovat aktualny vyber.
        def on_selection_changed
          return unless @dialog && @dialog.visible?
          push_state
        rescue StandardError => e
          Engine.log_error(e, 'TemplatesDialog.on_selection_changed')
        end
      end
    end
  end
end
