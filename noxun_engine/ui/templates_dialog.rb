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
#
# H2 (D-76): sablona nesie AJ kovanie — mapovanie setov + ZMRAZENE definicie
# (ulozenie: Panel.template_config_from s modelom; aplikacia: merge_hardware_sets
# + zmrazenie do projektoveho snapshotu v operacii prestavby). Sablona je datovy
# subor MIMO modelu, preto sa jej kovanie cita BEZSTRATOVO alebo vobec
# (HardwareSets.read_template_mapping — GH #133 P2).
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

        # D-14 (Codex F3): refresh zoznamu zvonka (ulozenie sablony z panela),
        # aby otvorene okno Sablony hned ukazalo novu polozku.
        def refresh_if_open
          return unless @dialog && @dialog.visible?
          push_state
        rescue StandardError => e
          Engine.log_error(e, 'TemplatesDialog.refresh_if_open')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Šablóny',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            # D-77: riadok sablony nesie nazov + akcie vpravo.
            # Rozmery platia LEN pri prvom otvoreni — zapamatane male okno dorovna nx_fit.
            width: 460,
            height: 540,
            min_width: 380,
            min_height: 360,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'templates.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          Engine.register_dialog_fit(dlg, 'templates') # D-77: zapamatane male okno sa dorovna
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
            # UI-C1a: okno spravuje VYHRADNE korpusove sablony — doskove sa v nom
            # ani neukazu (payload je filtrovany a serverove akcie maju vlastny
            # guard na kind, HTML nie je ochrana).
            templates: Panel.template_list(kind: 'cabinet'),
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

          # H2 (D-76): model = zdroj ZMRAZENYCH definicii setov kovania.
          cab_cfg = Store.config(cab) || {}
          config = Panel.template_config_from(cab_cfg, model: model)
          hw_note = Panel.template_save_hardware_note(cab_cfg, config, model) # GH #133 P2
          res = UI.inputbox(['Nazov sablony:'], [Panel.suggest_template_name(cab, {})], 'Ulozit sablonu')
          return if res == false # zrusene

          name = res[0].to_s.strip
          return set_status('Prázdny názov — zrušené.', true) if name.empty?

          if TemplateStore.find('cabinet', name) &&
             UI.messagebox("Sablona \"#{name}\" existuje. Prepisat?", MB_YESNO) != IDYES
            return set_status('Zrušené — šablóna nezmenená.')
          end
          TemplateStore.upsert('cabinet', name, config)
          after_change("Šablóna \"#{name}\" uložená.#{hw_note}")
        end

        def handle_delete(payload)
          name = JSON.parse(payload.to_s)['template'].to_s
          return set_status('Vyber šablónu na vymazanie.', true) if name.empty?
          return unless UI.messagebox("Vymazat sablonu \"#{name}\"?", MB_YESNO) == IDYES

          # Guard kind: okno vidi len korpusove, takze aj mazat smie len tie —
          # rovnomenna doskova sablona sa odtialto nikdy nezmaze.
          TemplateStore.delete('cabinet', name)
          after_change("Šablóna \"#{name}\" vymazaná.")
        end

        # Pouzije sablonu na oznaceny korpus. MERGE, nie nahradenie: konstrukcne
        # kluce zo sablony; part_overrides + hardware_overrides CIELA zostavaju
        # (sablona ich nenesie — viazane na konkretne dielce zdroja).
        # H2 (D-76): SETY KOVANIA sablona nesie (mapovanie + zmrazene definicie) —
        # merge_hardware_sets, zmrazenie v operacii prestavby.
        def handle_apply(payload)
          name = JSON.parse(payload.to_s)['template'].to_s
          # Guard kind (UI-C1a): doskovu sablonu na korpus aplikovat nemozno —
          # hladame VYHRADNE medzi korpusovymi.
          tpl = TemplateStore.find('cabinet', name)
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

          # GH #133 P2: kovanie sablony sa cita BEZSTRATOVO alebo vobec. Sablona
          # z novsej verzie (neznamy typ kovania) ci rucne upravena by ocesanou
          # mapou ticho ZMAZALA platny vyber setov cielovej skrinky.
          hw_status, hw_lost = HardwareSets.read_template_mapping((tpl['config'] || {})['hardware_sets'])
          if hw_status == :lossy
            return set_status("Šablóna nesie kovanie, ktoré sa nedá prečítať (#{Array(hw_lost).join(', ')}) — " \
                              'je z novšej verzie Noxun alebo ručne upravená. Nepoužitá, nič sa nezmenilo.', true)
          end

          target = Panel.existing_params(cab)
          merged = merge_template(target, tpl['config'])
          # D-45 (audit B4): sablona nesie hrubku aj (nepovinne) material — dvojica
          # sa musi zladit PRED rebuildom, inak by stavba spadla surovou hrubkovou
          # hlaskou. Explicitny material sablony vyhrava (hrubka sa prevezme z neho),
          # inak material dobera body_preflight; nejednoznacnost = odmietnutie.
          pf = template_material_preflight(merged, tpl['config'], target, model)
          return set_status(pf[:error], true) if pf && pf[:error]
          # H2 (D-76): definicie setov zo sablony sa zmrazia do projektoveho
          # snapshotu v TEJ ISTEJ operacii ako prestavba (rebuild_many blok) —
          # jedno undo a ziadna skrinka s nezmrazenym setom (zlyhanie zmrazenia
          # vyhodi vynimku a operacia sa cela zrusi).
          hw_note = ''
          Panel.suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, [[cab, merged]], op_name: 'NOXUN: Aplikuj sablonu') do
              hw_note = freeze_sets_from_template!(model, merged, tpl['config'])
            end
            Panel.reselect(model, cab)
          end
          set_status("Šablóna \"#{name}\" použitá na #{Store.get(cab, 'cabinet_id')}." \
                     "#{pf ? pf[:note] : ''}#{hw_note}")
          Panel.push_selected(model)
        end

        # H2 (D-76): zmrazenie definicii setov zo sablony do projektu. Legacy
        # sablona (bez kluca 'hardware_sets') nema co mrazit — mapovanie ciela
        # ostava tak, ako ho projekt uz ma zmrazene.
        def freeze_sets_from_template!(model, merged, tpl_config)
          return '' unless tpl_config.is_a?(Hash) && tpl_config.key?('hardware_sets')

          Panel.freeze_template_hardware!(model, merged['hardware_sets'],
                                          tpl_config['hardware_set_defs'])
        end

        # D-45: zladenie hrubka<->material pre MERGED params sablony.
        # Vrati nil / { error: } / { note: } (rovnaky kontrakt ako Panel preflighty).
        # GH P1: hrubku smie prevzat LEN material, ktory dodala SAMOTNA SABLONA —
        # merge_template kopiruje do merged aj material CIELA, takze test musi ist
        # na tpl_config (inak by sablona bez materialu zdedila staru hrubku ciela).
        # GH P1 (remap): old_eff sa cita z CIELA pred merge — merged uz nesie novy
        # material a remap rucnych ABS by inak ziadnu zmenu nevidel.
        def template_material_preflight(merged, tpl_config, target, model)
          note = ''
          if defined?(Materials) && Panel.present_str((tpl_config || {})['material_id'])
            sheet = Materials.sheet(CabinetBuilder.effective_materials(model, merged)['body'])
            if sheet
              adopt = Panel.adopt_body_thickness!(merged, sheet)
              return adopt if adopt && adopt[:error]
              note += adopt[:note].to_s if adopt
            end
          end
          pf = Panel.material_preflight(merged, model,
                                        old_eff: CabinetBuilder.effective_materials(model, target))
          return pf if pf && pf[:error]
          note += pf[:note].to_s if pf
          note.empty? ? nil : { note: note }
        end

        def merge_template(target_params, tpl_config)
          merged = tpl_config.dup
          merged['part_overrides'] = target_params['part_overrides'] || {}
          merged['hardware_overrides'] = target_params['hardware_overrides'] || []
          merged['hardware_sets'] = merge_hardware_sets(target_params, tpl_config)
          # D-13 (Codex F3): legacy sablona BEZ plinth_recess nesmie cielovy korpus
          # ticho stiahnut na novy default — chybajuci kluc = zachovaj hodnotu ciela.
          merged['plinth_recess'] = target_params['plinth_recess'] unless tpl_config.key?('plinth_recess')
          # D-100 (GH #149 P2): sablona nazov skrinky NENESIE (template_config_from
          # ho neuklada) — bez tohto by merge zacal od sablony a rucny nazov ciela
          # („Chladnickova") by po pouziti sablony ticho zmizol. Rovnaky vzor ako
          # plinth_recess: chybajuci kluc = zachovaj hodnotu CIELA.
          merged['name'] = target_params['name'] unless tpl_config.key?('name')
          %w[material_id front_material_id back_material_id].each do |k|
            tv = Panel.present_str(tpl_config[k])
            merged[k] = tv || target_params[k]
          end
          merged
        end

        # H2 (D-76): sety kovania pri aplikacii sablony.
        #   sablona kluc NEMA (legacy/seed)  -> zachova sa CELE mapovanie CIELA
        #     (vzor plinth_recess D-13; do H2 sa override setov ticho ZMAZAL)
        #   sablona kluc MA                  -> genericke kluce zo SABLONY;
        #     composite kluce „typ@owner_part_key" CIELA sa pridaju spat —
        #     su viazane na konkretne dielce ciela, sablona o nich nic nevie
        #     a nikdy ich nemaze ani neprepisuje.
        # Mapa zo sablony sa VZDY normalizuje s allow_owner: false — rucne
        # upraveny JSON s composite klucom sa cez sablonu do skrinky nedostane.
        def merge_hardware_sets(target_params, tpl_config)
          target = target_params['hardware_sets'].is_a?(Hash) ? target_params['hardware_sets'] : {}
          target = HardwareSets.normalize_mapping(target, nil, allow_owner: true)
          return target unless tpl_config.is_a?(Hash) && tpl_config.key?('hardware_sets')

          out = HardwareSets.normalize_mapping(tpl_config['hardware_sets'], nil, allow_owner: false)
          target.each do |key, value|
            parsed = BuildPlan.parse_hardware_set_key(key)
            out[key] = value if parsed && parsed[1] # composite = override na dielci
          end
          out
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
