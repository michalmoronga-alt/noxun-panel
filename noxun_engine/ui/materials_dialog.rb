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
      # D-42 PR B: kluc bumpnuty (v2) — preferences_key drzi ulozenu geometriu
      # okna a stara 420x360 by mriezku dlazdic stlacila (audit FIX 14). Bump =
      # jednorazovo cerstvy default 640x560; layout ostava responzivny.
      DLG_KEY = 'noxun_engine_materials_v2'

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

          # D-42 PR B: sirsie okno pre mriezku dlazdic + detail (Michal: ~640 px);
          # vyssi default, aby pod predvolbami a top barom ostal priestor gridu.
          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Materiály projektu',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 640,
            height: 560,
            min_width: 500,
            min_height: 400,
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
          cb(dlg, 'set_decor_name')  { |p| handle_set_decor_name(p) }
          # D-42: vyrobca je vlastnost dekoru — zmena atomicky pre celu skupinu.
          cb(dlg, 'set_decor_manufacturer') { |p| handle_set_decor_manufacturer(p) }
          # D-42 PR C (audit BLOCKER 1): inline bunky detailu — patch protokol
          # (whitelist poli, merge s cerstvym zaznamom, baseline per RIADOK).
          cb(dlg, 'patch_sheet') { |p| handle_patch(p, 'sheet') }
          cb(dlg, 'patch_edge')  { |p| handle_patch(p, 'edge') }
          # 2A-4b (audit B2): rollback na predmigracnu zalohu z read-only banneru.
          cb(dlg, 'restore_pre_schema2') { |p| handle_restore_backup(p) }
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

        # PLNY stav: katalog + modelovy kontext (predvolby, pocty, pouzite dekory).
        # Vola sa pri ready a pri prepnuti modelu. Katalogove echa po zapisoch idu
        # cez push_catalog — model sa pri nich NEskenuje (audit FIX 13).
        def push_state
          model = Sketchup.active_model
          data = catalog_payload.merge(
            version: Engine::VERSION,
            project: Materials.project_defaults(model),       # aktualne predvolby modelu
            cabinets: Panel.all_cabinets(model).size,
            model_guid: model_guid(model),                    # D-42: identita modelu pre projektove predvolby
            used: Materials.model_decor_usage(model)          # D-42 PR B: pas "Pouzite v projekte"
          )
          js("MD.init(#{data.to_json})")
        end

        # LEN katalogova cast (po zapise do katalogu) — ziadny scan modelu,
        # modelovy kontext (predvolby/pouzite) v JS ostava (audit FIX 13).
        def push_catalog
          js("MD.setCatalog(#{catalog_payload.to_json})")
        end

        def catalog_payload
          {
            materials: Panel.materials_payload,               # katalog dosiek pre selecty
            catalog: full_catalog_payload,                    # D-05: plne zaznamy pre spravu
            protected_ids: Materials::PROTECTED_SHEET_IDS,
            catalog_rev: Materials.catalog_revision,          # D-41: baseline guard formularov
            # 2A-1 (audit F10): SCHEMA katalogu. Klient ju vracia v KAZDEJ mutacii
            # — po migracii na SCHEMA 2 server odmietne zapis zo stareho okna.
            catalog_schema: Materials.catalog_schema,
            # 2A-4b (audit B4/O1): nudzovy rezim katalogu — okno ukaze vyrazny
            # read-only banner s dovodom + tlacidlo obnovy predmigracnej zalohy.
            catalog_state: Materials.catalog_state.to_s,
            catalog_state_reason: Materials.catalog_state_reason.to_s,
            # 2A-4b (audit O2): pocet ABS pasok bez struktury a bez universal —
            # picker ich nevyberie. Pocita VYHRADNE server; banner sa ukazuje
            # pri KAZDOM otvoreni/refreshi, kym pocet nie je 0.
            unusable_edges: Materials.unusable_edges_count,
            # GH #93 P2 (4. kolo): dovod nevykonaneho cutoveru (poskodena
            # predmigracna zaloha / nerozhodnutelne polozky) — VIDITELNY banner,
            # nie len log; katalog pritom bezi dalej (nie read-only).
            cutover_issue: Materials.respond_to?(:cutover_issue) ? Materials.cutover_issue.to_s : '',
            # GH #93 P2 (10. kolo): rollback tlacidlo aj pri zdravom katalogu —
            # ukazuje sa len ked predmigracna zaloha realne existuje.
            pre_schema2_backup: File.exist?(Materials.pre_schema2_backup_path),
            # D-44: naseptavace (vyrobca/typ) a navrhy formatu platne stavia
            # SERVER — JS ich len renderuje. Ide s KAZDYM katalogovym echom,
            # takze novy vyrobca/typ je v navrhoch hned po zapise.
            suggest: { manufacturers: Materials.manufacturer_suggestions,
                       types: Materials.type_suggestions },
            format_hints: Materials::TYPE_FORMAT_HINTS
          }
        end

        # D-42 (audit BLOCKER 4): stabilna identita modelu (guid). Projektove
        # predvolby su per-MODEL; oneskoreny callback po prepnuti dokumentu nesmie
        # ulozit predvolbu vybranu v modeli A do prave aktivneho modelu B.
        def model_guid(model)
          model && model.respond_to?(:guid) ? model.guid.to_s : ''
        rescue StandardError
          ''
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

        # 2A-1 (audit F10): guard mutacii proti STAREMU oknu. Po migracii katalogu
        # na SCHEMA 2 (dekorove skupiny, struktura) nesmie zapisovat klient, ktory
        # o novych poliach nevie — jeho payload by identitu variantu zahodil.
        # V SCHEMA 1 sa nedeje NIC (spatna kompatibilita: prazdna hodnota prejde).
        # Rozhodnutie je na serveri (Materials.schema_write_allowed?) — tu ostava
        # len hlaska a refresh okna.
        def schema_ok?(data)
          return true if Materials.schema_write_allowed?(data['catalog_schema'])
          set_status('Katalóg je v novom formáte — zavri a znova otvor okno Materiály, potom ulož.', true)
          push_state
          false
        end

        # Spolocny vstupny guard katalogovych mutacii (schema pred baseline).
        def catalog_write_ok?(data)
          schema_ok?(data) && revision_ok?(data)
        end

        # Plne zaznamy katalogu (sprava potrebuje vsetky polia — panelovy
        # materials_payload je zamerne zuzeny). label = ten isty odvodeny text.
        # D-42 PR C: row_rev = odtlacok SUROVEHO zaznamu (bez labelu) — baseline
        # inline patchu per riadok. Pocita sa PRED merge labelu (server porovnava
        # proti zaznamu v katalogu, nie proti payloadovej ozdobe).
        def full_catalog_payload
          cat = Materials.load
          ctx = Panel.label_ctx # 2A-4b: kolizie cisla dekoru raz pre cely payload
          {
            'sheets' => cat['sheets'].map { |s|
              s.merge('label' => Panel.sheet_label(s, ctx), 'row_rev' => Materials.record_rev(s))
            },
            'edges' => cat['edges'].map { |a|
              a.merge('label' => Panel.abs_label(a, ctx), 'row_rev' => Materials.record_rev(a))
            }
          }
        end

        # D-42 PR C (audit BLOCKER 1): inline patch bunky. Konflikt riadku =
        # cerstve data + hlaska (rozpisana bunka sa NEuklada nad cudziu zmenu);
        # duplicitny kod = flag do JS, dalsi flush tej istej bunky posle
        # potvrdenie (zrkadlo formularoveho allow_duplicate_code).
        def handle_patch(payload, kind)
          data = JSON.parse(payload.to_s)
          # 2A-1: baseline riadku (row_rev) strazi cudziu zmenu ZAZNAMU, nie
          # prepnutie schemy katalogu — schema guard preto plati aj pre bunky.
          return unless schema_ok?(data)
          patch = data['patch'].is_a?(Hash) ? data['patch'] : {}
          status, extra = Materials.patch_record(
            kind, data['id'].to_s, patch,
            row_rev: data['row_rev'], allow_duplicate_code: !!data['allow_duplicate_code']
          )
          case status
          when :ok
            after_catalog_change
            set_status('Uložené.')
          when :conflict
            set_status('Riadok medzitým zmenil niekto iný — hodnoty sa obnovili, uprav znova.', true)
            push_catalog
          when :code_conflict
            set_status("Kód už používa #{extra.size}× (#{extra.first(3).join(', ')}…). Ulož znova pre potvrdenie duplicity.", true)
            js("MD.flagDuplicatePatch(#{kind.to_json}, #{data['id'].to_json})")
          when :not_found
            set_status('Záznam sa nenašiel — katalóg sa obnovil.', true)
            push_catalog
          when :invalid
            set_status(extra || 'Neplatná hodnota.', true)
            push_catalog
          when :catalog_read_only
            # 2A-4b (audit F7 UI): aj nudzovy rezim vrati UI podla SERVERA —
            # universal toggle/bunka sa nesmie tvarit, ze zapis presiel.
            set_status(Materials.catalog_read_only_message, true)
            push_catalog
          else
            # :write_failed — checkbox/bunka sa VRATI podla servera (F7).
            set_status('Uloženie zlyhalo.', true)
            push_catalog
          end
        end

        # --- 2A-4b (audit B2/B4): obnova predmigracnej zalohy -----------------
        # Tlacidlo v read-only banneri (potvrdenie robi modal v okne — NIE
        # UI.messagebox). Uspech = katalog je spat legacy + hold flag zabezpeci,
        # ze najblizsi start SketchUpu migraciu RAZ preskoci.
        def handle_restore_backup(_payload)
          ok, result = Materials.restore_pre_schema2!
          return set_status(result, true) unless ok
          # GH #93 P2 (4. kolo): rollback meni CELY katalog — refresh musia
          # dostat aj panel a otvorene okno Vyroba (rovnako ako bezna mutacia),
          # inak by drzali predrollbackovy SCHEMA 2 obsah.
          after_catalog_change
          push_state
          set_status('Katalóg obnovený z predmigračnej zálohy. Pri najbližšom štarte SketchUpu sa migrácia jednorazovo preskočí.')
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
          # D-42 (audit BLOCKER 4): predvolba patri modelu, z ktoreho ju pouzivatel
          # vybral. Ak sa medzitym prepol dokument, echo s cudzim guidom sa zahodi
          # (UI sa uz obnovilo cez on_model_changed) — nie ticho do zleho modelu.
          if data.key?('model_guid') && !data['model_guid'].to_s.empty? &&
             data['model_guid'].to_s != model_guid(model)
            Engine.log("projektova predvolba zahodena — echo modelu #{data['model_guid']} nesedi s aktivnym")
            return push_state
          end
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
              # D-45: korpusova predvolba sa uz NEPOROVNAVA s konstantou 18 —
              # vklad sa hrubke materialu prisposobi (insert_thickness_preflight).
              # Strazi sa uz len rozsah, v ktorom korpus vie stat (HDF 3 = stop).
              CabinetBuilder.thickness_in_range?(have)
            when 'default_back_material_id'
              # chrbat ma v UI dve podporovane hrubky (HDF 3 / pevny 18) — obe legalne
              [3.0, 18.0].any? { |t| CabinetBuilder.thickness_ok_for?(role, t, have) }
            else
              CabinetBuilder.thickness_ok_for?(role, Fronts::FRONT_THICKNESS.to_f, have)
            end
          unless new_ok
            return set_status(project_thickness_msg(key, value, have), true)
          end
          selected = Panel.find_cabinet(model)
          affected = Panel.all_cabinets(model).select do |cabinet|
            Panel.present_str(Panel.existing_params(cabinet)[cfg_key]).nil?
          end

          # D-41 PR C (audit FIX 5): projektova predvolba meni efektivny material
          # VSETKYCH dediacich skriniek — rucne ABS overridy zladene so starym
          # dekorom sa preladia (stary default este plati, novy je len v `value`).
          eff_key = { 'default_material_id' => 'body', 'default_front_material_id' => 'front',
                      'default_back_material_id' => 'back' }[key]
          # Snapshot PRED zapisom: baseline kontraktu potvrdenia aj hodnota, na
          # ktoru sa vrati select pri odmietnuti/ponuke.
          old_default = Materials.project_defaults(model)[key].to_s

          if key == 'default_material_id'
            # --- D-46: KORPUS. Dediacim skrinkam sa hrubka nemeni ticho, ale ani
            # sa uz neodmieta natvrdo — pouzivatel dostane presny rozpis a jedno
            # potvrdenie; vsetko potom prebehne v JEDNOM undo kroku.
            plan = body_change_plan(model, affected, sheet, value)
            unless plan['blocked'].empty?
              # Blokujuce dielce sa neprelozia ani potvrdenim — ziadna ponuka
              # (audit F3: nesluboval by sa krok, ktory sa neda vykonat).
              set_status(blocked_cabs_msg(have, plan['blocked']), true)
              return reset_project_select(key, old_default)
            end
            unless plan['adopting'].empty?
              fresh = { 'model_guid' => model_guid(model), 'key' => key, 'value' => value,
                        'old_default' => old_default,
                        'adopting_ids' => plan['adopting'], 'recompute_ids' => plan['recompute'] }
              unless Materials.pending_default_ok?(data['confirm'], fresh)
                return offer_body_change(fresh, have, stale: !data['confirm'].nil?)
              end
            end
            jobs = plan['jobs']
            remap_changed = plan['remap']['changed'].to_i
            remap_lost = plan['remap']['lost']
            adopted_n = plan['adopting'].size
            recomputed_n = plan['recompute'].size
          else
            incompatible = affected.select do |cabinet|
              params = Panel.existing_params(cabinet)
              # D-31 (GH P2): skrinka BEZ chrbta dielec back vobec nema — jej ulozena
              # hrubka (napr. HDF 3) nesmie blokovat zmenu projektoveho chrbta na 18.
              next false if key == 'default_back_material_id' && params['back_mode'] == 'none'
              want = thickness_key ? params[thickness_key].to_f : Fronts::FRONT_THICKNESS
              !CabinetBuilder.thickness_ok_for?(role, want, sheet['thickness'].to_f)
            end
            unless incompatible.empty?
              # D-45: hrubka existujucich DEDIACICH skriniek sa NESMIE zmenit ticho
              # (predvolba by prepisala hotovu vyrobu) — hlaska navedie, co s tym.
              ids = incompatible.map { |cabinet| Store.get(cabinet, 'cabinet_id') }.join(', ')
              return set_status("Materiál #{value} (#{Panel.fmt_mm(have)} mm) má nekompatibilnú hrúbku pre: #{ids}. " \
                                'Nastav ho priamo tým skrinkám (prevezmú hrúbku) alebo im najprv zmeň hrúbku korpusu.', true)
            end

            remap_changed = 0
            remap_lost = []
            adopted_n = 0
            recomputed_n = affected.size
            jobs = affected.map do |cabinet|
              p = Panel.existing_params(cabinet)
              old_eff = Panel.effective_materials(model, p)
              new_eff = old_eff.merge(eff_key => value)
              remap = CabinetBuilder.remap_part_edge_overrides!(p, old_eff, new_eff)
              remap_changed += remap['changed'].to_i
              remap_lost.concat(remap['lost'])
              [cabinet, p]
            end
          end

          Panel.suspend_selection_sync do
            # Zapis predvolby je VNUTRI operacie rebuildov (audit N8) — 1 undo
            # vrati geometriu skriniek AJ modelovy default naraz.
            CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: projektovy material') do
              raise 'Projektový materiál sa nepodarilo uložiť.' unless Materials.set_project_default(model, key, value)
            end
            Panel.reselect(model, selected) if selected && selected.valid?
          end
          msg = saved_msg(adopted_n, recomputed_n, have)
          msg += " ABS hrany prevedené na nový dekor (#{remap_changed}× dielec)." if remap_changed.positive?
          msg += " Bez náhrady: #{remap_lost.join(', ')}." unless remap_lost.empty?
          set_status(msg)
          push_state
          Panel.push_selected(model) # refresh Inspectora (korpusove selecty, karta dielca)
        end

        # --- D-46: predvolba korpusu s inou hrubkou ---------------------------

        # PLNY dry-run nad CERSTVYMI kopiami params vsetkych dediacich skriniek.
        # Ta ista funkcia stavia ponuku aj finalne params davky (CabinetBuilder
        # .classify_body_default_change) — pri ponuke sa vysledok len zahodi,
        # do modelu sa nezapisuje NIC.
        def body_change_plan(model, affected, sheet, value)
          entries = affected.map do |cab|
            params = Panel.existing_params(cab) # cerstva kopia z modelu
            [Store.get(cab, 'cabinet_id').to_s, params,
             Panel.effective_materials(model, params), cab]
          end
          CabinetBuilder.classify_body_default_change(entries, sheet, value)
        end

        # Ponuka na potvrdenie: select sa v UI VRATI na skutocny default a pod nim
        # sa zobrazi lista Potvrdiť/Zrušiť. Pending kontrakt (fresh) sa posiela
        # klientovi a pri potvrdeni pride CELY spat — server ho znovu overi.
        def offer_body_change(fresh, have, stale: false)
          msg = confirm_msg(fresh['adopting_ids'].size, fresh['recompute_ids'].size, have)
          msg = "Stav sa medzitým zmenil — #{msg}" if stale
          set_status(msg)
          js("MD.confirmDefault(#{{ 'key' => fresh['key'], 'current' => fresh['old_default'],
                                    'message' => msg, 'pending' => fresh }.to_json})")
        end

        # UI resync po odmietnuti: select nesmie zostat na materiali, ktory sa
        # neulozil (JS ho vrati na skutocny default a zahodi pending).
        def reset_project_select(key, current)
          js("MD.resetProject(#{{ 'key' => key, 'current' => current }.to_json})")
        end

        # Pocty skriniek v spravnom slovenskom tvare (1 / 2–4 / 5+).
        def cabs_phrase(count, tense)
          few = count >= 2 && count <= 4
          noun = count == 1 ? 'skrinka' : (few ? 'skrinky' : 'skriniek')
          verb = if tense == :future
                   few ? 'prevezmú' : 'prevezme'
                 else
                   count == 1 ? 'prevzala' : (few ? 'prevzali' : 'prevzalo')
                 end
          "#{count} #{noun} #{verb}"
        end

        def confirm_msg(adopting, recompute, have)
          msg = "#{cabs_phrase(adopting, :future)} hrúbku #{Panel.fmt_mm(have)} mm"
          msg += " (prepočítajú sa aj ďalšie: #{recompute})" if recompute.positive?
          "#{msg} — potvrď nižšie."
        end

        def saved_msg(adopted, recomputed, have)
          return "Predvoľba uložená — prepočítaných #{recomputed} skriniek." if adopted.zero?
          msg = "Predvoľba uložená — #{cabs_phrase(adopted, :past)} hrúbku #{Panel.fmt_mm(have)} mm"
          msg += ", prepočítaných #{recomputed}" if recomputed.positive?
          "#{msg}."
        end

        # Blokujuce skrinky: "CAB-001: Polica 1, Bok Ľ; CAB-003: Bok P"
        # (konzistentne s D-45 Panel.blocked_parts_msg).
        def blocked_cabs_msg(have, blocked)
          list = blocked.first(3).map do |cid, reason, parts|
            reason == :range ? "#{cid}: mimo rozsahu hrúbky korpusu" : "#{cid}: #{parts.first(4).join(', ')}"
          end.join('; ')
          list += " a ďalšie (#{blocked.length - 3})" if blocked.length > 3
          "Hrúbku #{Panel.fmt_mm(have)} mm blokujú dielce s vlastným materiálom inej hrúbky — #{list}. " \
            'Vráť im materiál na dedený (alebo im vyber materiál tejto hrúbky) a skús znova. ' \
            'Predvoľba sa nezmenila.'
        end

        # D-45: hlaska odmietnutej projektovej predvolby — per rolu (vysvetli PRECO).
        def project_thickness_msg(key, value, have)
          lo = Panel.fmt_mm(CabinetBuilder::THICKNESS_RANGE[0])
          hi = Panel.fmt_mm(CabinetBuilder::THICKNESS_RANGE[1])
          case key
          when 'default_material_id'
            "Materiál #{value} (#{Panel.fmt_mm(have)} mm) je mimo rozsahu hrúbky korpusu (#{lo}–#{hi} mm) — " \
              'ako predvoľbu korpusu ho nastaviť nejde. Tenké dosky sú materiál chrbta alebo konkrétneho dielca.'
          when 'default_back_material_id'
            "Materiál #{value} (#{Panel.fmt_mm(have)} mm) nesedí s podporovanými hrúbkami chrbta (3 alebo 18 mm)."
          else
            "Materiál #{value} (#{Panel.fmt_mm(have)} mm) je mimo rozsahu hrúbky čela (#{lo}–#{hi} mm)."
          end
        end

        # D-42: zmena vyrobcu CELEJ dekorovej skupiny (audit FIX 7 — vyrobca nie je
        # per-variant). Atomicky, ID zaznamov sa nemenia.
        def handle_set_decor_manufacturer(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          # D-44 (audit F9): prazdna hodnota vymaze vyrobcu LEN s explicitnym
          # flagom z tlacidla "Zmazať výrobcu" — omyl pri naseptavaci sa odmietne.
          clear = !!data['clear_manufacturer']
          # 2A-4b (audit B3): klient posiela group_id — v SCHEMA 2 sa skupina
          # identifikuje nim (text dekoru je len fallback pre stare okna).
          ok, result = Materials.set_decor_manufacturer(data['decor'], data['manufacturer'],
                                                        clear: clear, group_id: data['group_id'])
          return set_status(result, true) unless ok
          after_catalog_change
          decor = data['decor'].to_s.strip
          set_status(clear ? "Výrobca dekoru #{decor} zmazaný (#{result} dosiek)."
                           : "Výrobca dekoru #{decor} nastavený (#{result} dosiek).")
        end

        # --- D-05: sprava katalogu (Codex audit davky 2 zapracovany) ----------
        # Zapis je single-writer kompromis (atomicky rename + .bak; bez locku medzi
        # SketchUp procesmi — vedome akceptovane, katalog edituje jeden pouzivatel).

        def handle_save_sheet(payload, create:)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          ok, err = Materials.validate_sheet_attrs(data)
          return set_status(err, true) unless ok
          th = data['thickness'].to_s.tr(',', '.').to_f

          if create
            # D-41 (audit BLOCKER 1 + FIX 16): near-match dekor = preklep, dup
            # variant identity (dekor+typ+hrubka) = duplicitny zaznam. Oboje stop.
            if (near = Materials.decor_conflict(data['decor']))
              return set_status("Dekor sa líši od existujúceho „#{near}“ len zápisom — použi presný tvar.", true)
            end
            # 2A-1: struktura (a pri PD format) su v SCHEMA 2 sucastou identity
            # variantu — v SCHEMA 1 ich kluc ignoruje, takze ich posielame vzdy.
            if (dup = Materials.find_sheet_variant(data['decor'], data['type'], th, data['structure'],
                                                   data['sheet_size'], group_id: data['group_id'],
                                                   manufacturer: data['manufacturer']))
              return set_status("Variant už v katalógu je (#{dup['material_id']}).", true)
            end
            id = Materials.generate_sheet_id(data['decor'], data['type'], th,
                                             structure: data['structure'], sheet_size: data['sheet_size'])
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
            # D-42 (audit BLOCKER 3): typ je sucast variant identity — pri edite je
            # NEMENNY (zrkadlo hrubky/dekoru). Iny typ = novy variant. Duplicitna
            # kontrola uz NESTACI — zmena typu sa vobec nepripusti.
            if data.key?('type') && data['type'].to_s.strip.upcase != existing['type'].to_s.strip.upcase
              return set_status('Typ dosky definuje variant — pre iný typ pridaj nový materiál.', true)
            end
            # D-42 (audit FIX 7): vyrobca je vlastnost DEKORU (skupiny) — jednotlivy
            # variant ho nemeni; zmena celej skupiny je samostatna akcia.
            if data.key?('manufacturer') && data['manufacturer'].to_s.strip != existing['manufacturer'].to_s.strip
              return set_status('Výrobca je vlastnosť dekoru — zmeň ho pre celú skupinu, nie jeden záznam.', true)
            end
            # 2A-1 (standard 7.1): v SCHEMA 2 je identita variantu pri edite
            # NEMENNA aj v novych poliach — struktura, kotva skupiny a pri type
            # PD aj FORMAT platne. Iny format = novy variant (F800 PD 38 4100x600
            # a 4100x920 su dve rozne dosky), nie prepis existujuceho.
            if (err = Materials.identity_edit_error(data, existing))
              return set_status(err, true)
            end
          end

          # D-42 (audit FIX 8): duplicitny kod v ramci dosiek a rovnakeho dodavatela
          # sa nezapise potichu — vyzaduje potvrdenie (allow_duplicate_code).
          conflict = maybe_code_conflict(data, 'sheet', create ? nil : id)
          return conflict if conflict

          # D-19 (Codex F5): pri edite sa payload MERGUJE s existujucim zaznamom —
          # klient, ktory nove pole (napr. sheet_size) neposle, ho nesmie ticho
          # resetnut na default cez normalize_sheet.
          base = create ? {} : existing
          rec = base.merge(data).merge('material_id' => id, 'thickness' => th)
          # D-44 (GH P2): edit s prazdnymi polami formatu = vedome VYMAZANIE —
          # bez explicitneho flagu by merge stary sheet_size ticho podrzal a stav
          # "bez overeneho formatu" by sa pri existujucom zazname nedal dosiahnut.
          rec.delete('sheet_size') if !create && data['clear_sheet_size']
          rec.delete('clear_sheet_size')
          return set_status('Uloženie katalógu zlyhalo.', true) unless Materials.upsert_sheet(rec)
          after_catalog_change
          set_status(create ? "Materiál pridaný (#{id})." : "Materiál #{id} upravený.")
        end

        # D-42 (audit FIX 8): ak payload nesie kod a existuje kolizia (rovnaky kod
        # + dodavatel v tom istom druhu) a klient nepotvrdil allow_duplicate_code,
        # vrati status-hlasku (a NEuklada). Inak nil (pokracuj). JS warning sa da
        # obist, autorita je server.
        def maybe_code_conflict(data, kind, self_id)
          code = data['code'].to_s.strip
          return nil if code.empty? || data['allow_duplicate_code']
          hits = Materials.code_conflicts(code, data['supplier'], kind, self_id)
          return nil if hits.empty?
          set_status("Kód „#{code}“ už používa #{hits.size}× (#{hits.first(3).join(', ')}…). Ulož znova pre potvrdenie duplicity.", true)
          js("MD.flagDuplicateCode(#{kind.to_json})")
          'CONFLICT'
        end

        def handle_delete_sheet(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
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
          return unless catalog_write_ok?(data)
          ok, err = Materials.validate_edge_attrs(data)
          return set_status(err, true) unless ok
          th = data['thickness'].to_s.tr(',', '.').to_f
          if create
            # D-41: near-match dekor + dup variant (dekor+sirka+hrubka) guardy.
            if (near = Materials.decor_conflict(data['decor']))
              return set_status("Dekor sa líši od existujúceho „#{near}“ len zápisom — použi presný tvar.", true)
            end
            # 2A-1: struktura je v SCHEMA 2 sucastou identity pasky (5981 ma DVE
            # rozne 23/1 pasky — MG vs UM/AF); v SCHEMA 1 ju kluc ignoruje.
            if (dup = Materials.find_edge_variant(data['decor'], data['width'], th,
                                                  data['structure'], group_id: data['group_id']))
              return set_status("ABS variant už v katalógu je (#{dup['abs_id']}).", true)
            end
            id = Materials.generate_edge_id(data['decor'], th, data['width'], structure: data['structure'])
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
            # 2A-1: struktura/skupina su v SCHEMA 2 identita — pri edite nemenne.
            if (err = Materials.identity_edit_error(data, existing))
              return set_status(err, true)
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
          # D-42 (audit FIX 8): duplicitny kod ABS (rovnaky dodavatel) -> potvrdenie.
          conflict = maybe_code_conflict(data, 'edge', create ? nil : id)
          return conflict if conflict
          return set_status('Uloženie katalógu zlyhalo.', true) unless Materials.upsert_edge(rec)
          after_catalog_change
          set_status(create ? "ABS páska pridaná (#{id})." : "ABS #{id} upravená.")
        end

        def handle_delete_edge(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
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
          return unless catalog_write_ok?(data)
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
        # GH #93 P2: nazov skupiny (decor_name) — zobrazovacia vlastnost,
        # atomicky celej skupine cez group_id.
        def handle_set_decor_name(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          ok, result = Materials.set_decor_name(data['group_id'], data['name'])
          return set_status(result, true) unless ok
          after_catalog_change
          label = data['name'].to_s.strip
          set_status(label.empty? ? "Názov skupiny vymazaný (#{result} záznamov)." : "Názov skupiny: #{label} (#{result} záznamov).")
        end

        def handle_rename_decor(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          # 2A-4b (audit B3): group_id od klienta — SCHEMA 2 meni VYHRADNE
          # zaznamy danej skupiny (rovnake cislo u ineho vyrobcu sa nedotkne).
          ok, result = Materials.rename_decor(data['old_decor'], data['new_decor'],
                                              group_id: data['group_id'])
          return set_status(result, true) unless ok
          after_catalog_change
          set_status("Dekor premenovaný na #{data['new_decor'].to_s.strip} (#{result} záznamov).")
        end

        # Po kazdej zmene katalogu: refresh tohto okna + zivy katalog v paneli
        # (NX.setMaterials — BEZ resetu formulara panela).
        def after_catalog_change
          # D-42 (audit FIX 13): katalogovy zapis NEskenuje model — pouzite dekory
          # a predvolby sa zapisom do katalogu nemenia; plny push_state ostava pre
          # ready/on_model_changed/projektove predvolby.
          push_catalog
          Panel.push_materials if defined?(Panel)
          # D-19 (Codex F3): otvorene okno Vyroba by inak drzalo stary odhad
          # platni (format sa prave mohol zmenit)
          ProductionDialog.refresh_if_open if defined?(ProductionDialog)
        end
      end
    end
  end
end
