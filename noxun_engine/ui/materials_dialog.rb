# frozen_string_literal: true
# Noxun Engine — dialog "Materialy projektu" (V0.4.5 D2). Satelitne okno (vzor
# RulesDialog): projektove predvolby materialov sa nastavuju raz za projekt,
# nie popri kresleni — preto neziju v Inspector paneli (SYSTEM/07: sprava
# katalogov mimo hlavneho panela). V paneli ostavaju len materialy oznacenej
# skrinky; logika projektoveho defaultu sa PRESUNULA sem z Panel
# (handle_set_project_material) — panel ju uz nevola.
#
# Data su per MODEL (NOXUN dict, Materials.project_defaults) — pri prepnuti
# dokumentu formular obnovi EngineAppObserver (on_model_changed, vzor PR #26).
require 'json'

module Noxun
  module Engine
    module MaterialsDialog
      DLG_KEY = 'noxun_engine_materials'

      # key -> [config kluc korpusu, rola pre hrubkovu kontrolu, pole hrubky]
      # (presunute z Panel::PROJECT_MATERIAL_TARGETS — jediny pouzivatel je tento dialog)
      TARGETS = {
        'default_material_id'       => ['material_id', 'side_left', 'thickness'],
        'default_front_material_id' => ['front_material_id', 'front_door', nil],
        'default_back_material_id'  => ['back_material_id', 'back', 'back_thickness']
      }.freeze

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
          Engine.log_error(e, 'MaterialsDialog.show')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Materiály projektu',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 420,
            height: 360,
            min_width: 360,
            min_height: 280,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'proj_materials.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          cb(dlg, 'ready')                { |_p| push_state }
          cb(dlg, 'set_project_material') { |p| handle_set_project_material(p) }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(materials): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'materials js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "materials cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # --- Ruby -> JS -----------------------------------------------------

        def push_state
          model = Sketchup.active_model
          data = {
            version: Engine::VERSION,
            materials: Panel.materials_payload,               # katalog dosiek pre selecty
            project: Materials.project_defaults(model),       # aktualne predvolby modelu
            cabinets: Panel.all_cabinets(model).size
          }
          js("MD.init(#{data.to_json})")
        end

        def set_status(msg, error = false)
          js("MD.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?
          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.js')
        end

        # Volane z EngineAppObserver: predvolby su per model — otvoreny formular
        # sa pri File > New/Open/Activate naplni z prave aktivneho modelu.
        def on_model_changed(_model)
          return unless @dialog && @dialog.visible?
          push_state
          set_status('Aktívny model sa zmenil — predvoľby načítané z tohto modelu.')
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.on_model_changed')
        end

        # --- akcia ----------------------------------------------------------

        # Projektovy default materialu (koren dedenia, standard 7.2). Vsetky korpusy,
        # ktore dany material DEDIA (nemaju vlastny override), sa prepocitaju atomicky
        # v jednej Undo operacii. Presunute z Panel (V0.4.5 D2) — povodna logika
        # vratane hrubkovej kontroly nekompatibilnych skriniek.
        def handle_set_project_material(payload)
          model = Sketchup.active_model
          data = JSON.parse(payload.to_s)
          key = data['key'].to_s
          value = Panel.present_str(data['value'])
          target = TARGETS[key]
          return set_status('Neznámy projektový materiál.', true) unless target && value

          sheet = Materials.sheet(value)
          return set_status('Vybraný materiál sa nenašiel v katalógu.', true) unless sheet

          cfg_key, role, thickness_key = target

          # Predvolba musi sediet aj s hrubkami NOVEJ skrinky (Codex PR #29): kontrola
          # nizsie prejde len existujuce dediace skrinky — v novom modeli (alebo ked
          # vsetky maju override) by presiel nekompatibilny default (napr. HDF 3 ako
          # korpus) a najblizsi vklad by spadol pri stavbe. Ine hrubky = material na
          # konkretnej skrinke (override), nie projektova predvolba.
          have = sheet['thickness'].to_f
          new_ok =
            case key
            when 'default_material_id'
              CabinetBuilder.thickness_ok_for?(role, CabinetBuilder::LOWER_DEFAULTS[:thickness].to_f, have)
            when 'default_back_material_id'
              # chrbat ma v UI dve podporovane hrubky (HDF 3 / pevny 18) — obe legalne
              [3.0, 18.0].any? { |t| CabinetBuilder.thickness_ok_for?(role, t, have) }
            else
              CabinetBuilder.thickness_ok_for?(role, Fronts::FRONT_THICKNESS.to_f, have)
            end
          unless new_ok
            return set_status("Materiál #{value} (#{have.round(1)} mm) nesedí s hrúbkou novej skrinky — najbližší vklad by sa nepostavil. Pre iné hrúbky nastav materiál konkrétnej skrinke.", true)
          end
          selected = Panel.find_cabinet(model)
          affected = Panel.all_cabinets(model).select do |cabinet|
            Panel.present_str(Panel.existing_params(cabinet)[cfg_key]).nil?
          end

          incompatible = affected.select do |cabinet|
            params = Panel.existing_params(cabinet)
            want = thickness_key ? params[thickness_key].to_f : Fronts::FRONT_THICKNESS
            !CabinetBuilder.thickness_ok_for?(role, want, sheet['thickness'].to_f)
          end
          unless incompatible.empty?
            ids = incompatible.map { |cabinet| Store.get(cabinet, 'cabinet_id') }.join(', ')
            return set_status("Materiál #{value} má nekompatibilnú hrúbku pre: #{ids}.", true)
          end

          jobs = affected.map { |cabinet| [cabinet, Panel.existing_params(cabinet)] }
          Panel.suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: projektovy material') do
              raise 'Projektový materiál sa nepodarilo uložiť.' unless Materials.set_project_default(model, key, value)
            end
            Panel.reselect(model, selected) if selected && selected.valid?
          end
          set_status("Predvoľba uložená — prepočítaných #{affected.size} skriniek.")
          push_state
          Panel.push_selected(model) # refresh Inspectora (korpusove selecty, karta dielca)
        end
      end
    end
  end
end
