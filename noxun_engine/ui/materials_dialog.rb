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
          # Davka 2 (D-05): sprava katalogu — create/edit ODDELENE (edit nikdy
          # nemeni ID a negeneruje ho; create ID generuje server, JS mu never).
          cb(dlg, 'add_sheet')    { |p| handle_save_sheet(p, create: true) }
          cb(dlg, 'update_sheet') { |p| handle_save_sheet(p, create: false) }
          cb(dlg, 'delete_sheet') { |p| handle_delete_sheet(p) }
          cb(dlg, 'add_edge')     { |p| handle_save_edge(p, create: true) }
          cb(dlg, 'update_edge')  { |p| handle_save_edge(p, create: false) }
          cb(dlg, 'delete_edge')  { |p| handle_delete_edge(p) }
          # D-41 PR B: dekorove karty — batch "Novy dekor" + atomicke premenovanie skupiny.
          cb(dlg, 'add_decor_batch') { |p| handle_add_decor_batch(p) }
          cb(dlg, 'rename_decor')    { |p| handle_rename_decor(p) }
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
            catalog: full_catalog_payload,                    # D-05: plne zaznamy pre spravu
            protected_ids: Materials::PROTECTED_SHEET_IDS,
            project: Materials.project_defaults(model),       # aktualne predvolby modelu
            cabinets: Panel.all_cabinets(model).size,
            catalog_rev: Materials.catalog_revision           # D-41: baseline guard formularov
          }
          js("MD.init(#{data.to_json})")
        end

        # D-41 (audit FIX 15): zapis nad starsim stavom katalogu sa odmietne —
        # klient posiela catalog_rev z posledneho init; nesulad = medzitym pisal
        # niekto iny (batch, druhe okno). Prazdny rev = stary klient (CEF cache),
        # guard sa preskoci (spatna kompatibilita, single-writer limit trva).
        def revision_ok?(data)
          rev = data['catalog_rev'].to_s
          return true if rev.empty? || rev == Materials.catalog_revision
          set_status('Katalóg sa medzitým zmenil — zoznamy sa obnovili, over a ulož znova.', true)
          push_state
          false
        end

        # Plne zaznamy katalogu (sprava potrebuje vsetky polia — panelovy
        # materials_payload je zamerne zuzeny). label = ten isty odvodeny text.
        def full_catalog_payload
          cat = Materials.load
          {
            'sheets' => cat['sheets'].map { |s| s.merge('label' => Panel.sheet_label(s)) },
            'edges'  => cat['edges'].map { |a| a.merge('label' => Panel.abs_label(a)) }
          }
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
            # D-31 (GH P2): skrinka BEZ chrbta dielec back vobec nema — jej ulozena
            # hrubka (napr. HDF 3) nesmie blokovat zmenu projektoveho chrbta na 18.
            next false if key == 'default_back_material_id' && params['back_mode'] == 'none'
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

        # --- D-05: sprava katalogu (Codex audit davky 2 zapracovany) ----------
        # Zapis je single-writer kompromis (atomicky rename + .bak; bez locku medzi
        # SketchUp procesmi — vedome akceptovane, katalog edituje jeden pouzivatel).

        def handle_save_sheet(payload, create:)
          data = JSON.parse(payload.to_s)
          return unless revision_ok?(data)
          ok, err = Materials.validate_sheet_attrs(data)
          return set_status(err, true) unless ok
          th = data['thickness'].to_s.tr(',', '.').to_f

          if create
            # D-41 (audit BLOCKER 1 + FIX 16): near-match dekor = preklep, dup
            # variant identity (dekor+typ+hrubka) = duplicitny zaznam. Oboje stop.
            if (near = Materials.decor_conflict(data['decor']))
              return set_status("Dekor sa líši od existujúceho „#{near}“ len zápisom — použi presný tvar.", true)
            end
            if (dup = Materials.find_sheet_variant(data['decor'], data['type'], th))
              return set_status("Variant už v katalógu je (#{dup['material_id']}).", true)
            end
            id = Materials.generate_sheet_id(data['decor'], data['type'], th)
          else
            id = data['material_id'].to_s
            existing = Materials.sheet(id)
            return set_status('Materiál sa nenašiel — obnov okno.', true) unless existing
            # Hrubka existujuceho variantu je NEMENNA (hrubka definuje variant;
            # zatvorene projekty sa neskontroluju — zmena by im rozbila rebuild).
            if (existing['thickness'].to_f - th).abs > 0.01
              return set_status('Hrúbka definuje variant — pre inú hrúbku pridaj nový materiál.', true)
            end
            # D-41 (audit FIX 12): dekor je identita skupiny a riadi vazbu na ABS —
            # pri edite je NEMENNY; premenovanie celej skupiny je samostatna akcia.
            if data.key?('decor') && data['decor'].to_s.strip != existing['decor'].to_s
              return set_status('Dekor je identita skupiny — premenuj celú skupinu (Premenovať dekor), nie jeden záznam.', true)
            end
            # D-41 (Codex GH #70): typ je tiez sucast variant identity — zmena typu
            # pri edite nesmie vytvorit duplicitny variant (dekor+typ+hrubka).
            new_type = data.key?('type') ? data['type'].to_s.strip : existing['type'].to_s
            if new_type.upcase != existing['type'].to_s.strip.upcase
              dup = Materials.find_sheet_variant(existing['decor'], new_type, th)
              if dup && dup['material_id'] != id
                return set_status("Variant #{existing['decor']} #{new_type} už existuje (#{dup['material_id']}).", true)
              end
            end
          end

          # D-19 (Codex F5): pri edite sa payload MERGUJE s existujucim zaznamom —
          # klient, ktory nove pole (napr. sheet_size) neposle, ho nesmie ticho
          # resetnut na default cez normalize_sheet.
          base = create ? {} : existing
          rec = base.merge(data).merge('material_id' => id, 'thickness' => th)
          return set_status('Uloženie katalógu zlyhalo.', true) unless Materials.upsert_sheet(rec)
          after_catalog_change
          set_status(create ? "Materiál pridaný (#{id})." : "Materiál #{id} upravený.")
        end

        def handle_delete_sheet(payload)
          data = JSON.parse(payload.to_s)
          return unless revision_ok?(data)
          id = data['material_id'].to_s
          if Materials::PROTECTED_SHEET_IDS.include?(id)
            return set_status('Tento materiál je systémová predvoľba nových projektov — nedá sa zmazať.', true)
          end
          used = Materials.used_material_ids(Sketchup.active_model)[id]
          if used && !used.empty?
            sample = used.uniq.first(3).join(', ')
            return set_status("Materiál #{id} sa používa (#{used.size}×: #{sample}…) — chráni výrobné dáta, nemažem. Pozor: zatvorené projekty sa nedajú skontrolovať.", true)
          end
          return set_status('Zmazanie zlyhalo.', true) unless Materials.delete_sheet(id)
          after_catalog_change
          set_status("Materiál #{id} zmazaný. (Zatvorené projekty sa nedajú skontrolovať — ak ho niektorý používal, dielec oň príde pri najbližšom prepočte.)")
        end

        def handle_save_edge(payload, create:)
          data = JSON.parse(payload.to_s)
          return unless revision_ok?(data)
          ok, err = Materials.validate_edge_attrs(data)
          return set_status(err, true) unless ok
          th = data['thickness'].to_s.tr(',', '.').to_f
          if create
            # D-41: near-match dekor + dup variant (dekor+sirka+hrubka) guardy.
            if (near = Materials.decor_conflict(data['decor']))
              return set_status("Dekor sa líši od existujúceho „#{near}“ len zápisom — použi presný tvar.", true)
            end
            if (dup = Materials.find_edge_variant(data['decor'], data['width'], th))
              return set_status("ABS variant už v katalógu je (#{dup['abs_id']}).", true)
            end
            id = Materials.generate_edge_id(data['decor'], th, data['width'])
            rec = data.merge('abs_id' => id, 'thickness' => th)
          else
            id = data['abs_id'].to_s
            existing = Materials.edge(id)
            return set_status('ABS páska sa nenašla — obnov okno.', true) unless existing
            # Hrubka ABS je pri edite NEMENNA (zrkadlo sheet guardu, Codex GH #39):
            # ID nesie hrubku (_10/_20) a dielce ju drzia len cez ID — zmena by ich
            # potichu prepla na inu hranu a ID by klamalo.
            if (existing['thickness'].to_f - th).abs > 0.01
              return set_status('Hrúbka definuje ABS variant — pre inú hrúbku pridaj novú pásku.', true)
            end
            # D-41 (audit FIX 12): dekor nemenny pri edite (identita skupiny).
            if data.key?('decor') && data['decor'].to_s.strip != existing['decor'].to_s
              return set_status('Dekor je identita skupiny — premenuj celú skupinu (Premenovať dekor), nie jeden záznam.', true)
            end
            # D-41 (audit FIX 12+13): sirka je sucast variant identity — pri edite
            # NEMENNA a payload ju nesmie ani ticho zmazat (stary CEF klient bez
            # pola width): MERGE s existujucim zaznamom (vzor sheet D-19) + sirka
            # sa VZDY berie z existujuceho zaznamu.
            rec = existing.merge(data).merge('abs_id' => id, 'thickness' => th)
            if existing.key?('width')
              rec['width'] = existing['width']
            else
              rec.delete('width')
            end
          end
          return set_status('Uloženie katalógu zlyhalo.', true) unless Materials.upsert_edge(rec)
          after_catalog_change
          set_status(create ? "ABS páska pridaná (#{id})." : "ABS #{id} upravená.")
        end

        def handle_delete_edge(payload)
          data = JSON.parse(payload.to_s)
          return unless revision_ok?(data)
          id = data['abs_id'].to_s
          used = Materials.used_abs_ids(Sketchup.active_model)[id]
          if used && !used.empty?
            sample = used.uniq.first(3).join(', ')
            return set_status("ABS #{id} sa používa (#{used.size}×: #{sample}…) — nemažem.", true)
          end
          return set_status('Zmazanie zlyhalo.', true) unless Materials.delete_edge(id)
          after_catalog_change
          set_status("ABS #{id} zmazaná.")
        end

        # D-41 PR B: batch "Novy dekor" — parse+validacia+zapis su CELE na serveri
        # (Materials.add_decor_batch, 1 atomicky write; audit FIX 14). JS len
        # posiela surove texty poli.
        def handle_add_decor_batch(payload)
          data = JSON.parse(payload.to_s)
          return unless revision_ok?(data)
          ok, result = Materials.add_decor_batch(data)
          return set_status(result, true) unless ok
          after_catalog_change
          parts = []
          parts << "#{result['sheets'].size}× doska" unless result['sheets'].empty?
          parts << "#{result['edges'].size}× ABS" unless result['edges'].empty?
          msg = "Dekor #{data['decor'].to_s.strip}: vytvorené #{parts.join(' + ')}."
          msg += " Preskočené (už existujú): #{result['skipped'].join(', ')}." unless result['skipped'].empty?
          msg += ' Ceny doplň úpravou jednotlivých položiek.'
          set_status(msg)
        end

        # D-41 PR B: premenovanie dekoru CELEJ skupiny (audit FIX 12 — edit
        # jednotlivca dekor nemeni; ID zaznamov sa nemenia, modely o nic neprídu).
        def handle_rename_decor(payload)
          data = JSON.parse(payload.to_s)
          return unless revision_ok?(data)
          ok, result = Materials.rename_decor(data['old_decor'], data['new_decor'])
          return set_status(result, true) unless ok
          after_catalog_change
          set_status("Dekor premenovaný na #{data['new_decor'].to_s.strip} (#{result} záznamov).")
        end

        # Po kazdej zmene katalogu: refresh tohto okna + zivy katalog v paneli
        # (NX.setMaterials — BEZ resetu formulara panela).
        def after_catalog_change
          push_state
          Panel.push_materials if defined?(Panel)
          # D-19 (Codex F3): otvorene okno Vyroba by inak drzalo stary odhad
          # platni (format sa prave mohol zmenit)
          ProductionDialog.refresh_if_open if defined?(ProductionDialog)
        end
      end
    end
  end
end
