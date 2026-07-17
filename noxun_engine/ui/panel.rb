# frozen_string_literal: true
# Noxun Engine — panel (HtmlDialog controller + SelectionObserver). V0.2b.
# Referencia dialogu v modulovej premennej (GC); callbacky pred show;
# Ruby->JS len cez to_json; v callbackoch 'next' (nie 'return'); begin/rescue s logom.
require 'json'

module Noxun
  module Engine
    module Panel
      DLG_KEY = 'noxun_engine_panel'
      PROJECT_MATERIAL_TARGETS = {
        'default_material_id' => ['material_id', 'side_left', 'thickness'],
        'default_front_material_id' => ['front_material_id', 'front_door', nil],
        'default_back_material_id' => ['back_material_id', 'back', 'back_thickness']
      }.freeze

      class << self
        # --- otvorenie ------------------------------------------------------
        def show
          dlg = ensure_dialog
          if dlg.visible?
            dlg.bring_to_front
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'Panel.show')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 400,
            height: 640,
            min_width: 360,
            min_height: 480,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'panel.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed do
            detach_observer
            @dialog = nil
          end
          attach_observer
          @dialog
        end

        # --- callbacky (JS -> Ruby) -----------------------------------------
        def register_callbacks(dlg)
          cb(dlg, 'ready')          { |_p| push_init }
          cb(dlg, 'insert_cabinet') { |p| handle_insert(p) }
          cb(dlg, 'apply_all')      { |p| handle_apply_all(p) }   # V0.2c auto-apply (konstrukcia + cela)
          cb(dlg, 'apply_changes')  { |p| handle_apply(p) }       # spatna kompat
          cb(dlg, 'apply_fronts')   { |p| handle_apply_fronts(p) }
          cb(dlg, 'split_zone')     { |p| handle_split_zone(p) }
          cb(dlg, 'set_zone_shelves') { |p| handle_set_zone_shelves(p) }
          cb(dlg, 'set_zone_field') { |p| handle_set_zone_field(p) } # V0.2c split lock (rozmer pola)
          cb(dlg, 'select_zone')    { |p| handle_select_zone(p) }    # V0.2c obojsmerna sync nahladu
          cb(dlg, 'clean_zone')     { |p| handle_clean_zone(p) }
          cb(dlg, 'save_template')  { |p| handle_save_template(p) }
          cb(dlg, 'delete_template') { |p| handle_delete_template(p) }
          cb(dlg, 'apply_template') { |p| handle_apply_template(p) }
          cb(dlg, 'toggle_zones')   { |p| handle_toggle_zones(p) }
          # V0.3 materialy + ABS
          cb(dlg, 'set_project_material') { |p| handle_set_project_material(p) } # projektovy default
          cb(dlg, 'set_cabinet_material') { |p| handle_set_cabinet_material(p) } # korpusovy override
          cb(dlg, 'set_part_material')    { |p| handle_set_part_material(p) }    # per-dielec override
          cb(dlg, 'set_part_edge')        { |p| handle_set_part_edge(p) }        # ABS hrana dielca
          cb(dlg, 'apply_to_similar')     { |p| handle_apply_to_similar(p) }     # na podobne diely
          # Diagnostika: JS chyby z HtmlDialogu (window.onerror) -> Engine.log. Priamo, NIE cez cb —
          # aby pripadna chyba v logovani nespustila set_status (dalsi execute_script) a slucku.
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS: #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'js_error')
            end
            next
          end
        end

        # Wrapper: begin/rescue + slovensky status pri chybe; nikdy 'return' v bloku (pouzi next).
        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # --- akcie: korpus ---------------------------------------------------
        def handle_insert(payload)
          model = Sketchup.active_model
          params = parse(payload)
          inst = CabinetBuilder.build(model, params)
          select_only(model, inst)
          cid = Store.get(inst, 'cabinet_id')
          set_status("Vlozeny #{cid} — #{part_count(inst)} dielcov.")
          push_selected(model)
        end

        # Konstrukcne/rozmerove zmeny na oznaceny korpus. Zachova strom zon + cela.
        def handle_apply(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus v modeli.', true) if cab.nil?

          data = parse(payload)
          params = existing_params(cab)
          %w[type width height depth thickness floor_height bottom_mode top_mode back_mode
             back_thickness plinth_mode plinth_recess rail_depth rails_orientation
             rails_top_offset name].each do |k|
            params[k] = data[k] if data.key?(k)
          end
          CabinetBuilder.rebuild(model, cab, params)
          finish_cab(model, cab, "Aktualizovany #{Store.get(cab, 'cabinet_id')} — #{part_count(cab)} dielcov.")
        end

        # Cela na oznaceny korpus. Zachova konstrukciu + strom zon.
        def handle_apply_fronts(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus v modeli.', true) if cab.nil?

          data = parse(payload)
          params = existing_params(cab)
          params['fronts'] = data['fronts'] || Fronts.empty_config
          CabinetBuilder.rebuild(model, cab, params)
          finish_cab(model, cab, "Cela aktualizovane — #{Store.get(cab, 'cabinet_id')}.")
        end

        # V0.2c AUTO-APPLY: jedna zmena poľa (konstrukcia AJ cela) -> 1 rebuild, 1 undo krok.
        # Zachova strom zon (delenie/police/locky). Ticho ignoruje ak nie je oznaceny korpus.
        def handle_apply_all(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return if cab.nil? # auto-apply bez vyberu = ticho (ziadny modal)

          data = parse(payload)
          params = existing_params(cab)
          %w[type width height depth thickness floor_height bottom_mode top_mode back_mode
             back_thickness plinth_mode plinth_recess rail_depth rails_orientation
             rails_top_offset name].each do |k|
            params[k] = data[k] if data.key?(k)
          end
          params['fronts'] = data['fronts'] if data.key?('fronts')
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params)
            reselect(model, cab)
          end
          set_status("Prestavané ✓ — #{Store.get(cab, 'cabinet_id')} (#{part_count(cab)} dielcov).")
          push_selected(model)
        end

        # --- akcie: zony -----------------------------------------------------
        def handle_split_zone(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac zonu (klik na ghost alebo v strome).', true) if zid.empty?
          axis = data['axis']; count = data['count'].to_i
          apply_zone_mod(zid) { |tree, path| ZoneTree.set_split!(tree, path, axis, count) }
          set_status("Zona #{short_zone(zid)} rozdelena #{axis == 'h' ? 'vodorovne' : 'zvisle'} na #{count}.")
        end

        def handle_set_zone_shelves(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac zonu.', true) if zid.empty?
          n = data['count'].to_i
          apply_zone_mod(zid) { |tree, path| ZoneTree.set_shelves!(tree, path, n) }
          set_status("Zona #{short_zone(zid)}: #{n} polic.")
        end

        def handle_clean_zone(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac zonu.', true) if zid.empty?
          apply_zone_mod(zid) { |tree, path| ZoneTree.clear_zone!(tree, path) }
          set_status("Zona #{short_zone(zid)} vycistena.")
        end

        # V0.2c: nastav presny rozmer pola v delenej zone + zamok (split lock). zone_id = RODICOVSKA
        # (delena) zona; index = poradie pola (0..count-1); size mm (prazdne = auto), locked bool.
        # fix #5: ak UI posle kompletny 'cuts' layout (rozmery vsetkych poli), ulozime ho naraz —
        # zadany rozmer bez locku sa tak NEstrati (proporcny prepocet az pri resize korpusu).
        def handle_set_zone_field(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac delenu zonu.', true) if zid.empty?
          index = data['index'].to_i
          size = data['size']
          locked = truthy?(data['locked'])
          cuts = data['cuts']
          if cuts.is_a?(Array)
            apply_zone_mod(zid) { |tree, path| ZoneTree.set_field_cuts!(tree, path, cuts) }
          else
            apply_zone_mod(zid) { |tree, path| ZoneTree.set_field!(tree, path, index, size, locked) }
          end
          set_status("Pole #{index + 1}: #{size.to_s.strip.empty? ? 'auto' : "#{size.to_f.round} mm"}#{locked ? ' 🔒' : ''} — prestavané ✓.")
        end

        # V0.2c obojsmerna sync: klik na zonu v 2D nahlade -> zvyrazni jej ghost v modeli.
        def handle_select_zone(payload)
          model = Sketchup.active_model
          zid = parse(payload)['zone_id'].to_s
          @active_zone_id = zid.empty? ? nil : zid
          return if zid.empty?
          cid = cabinet_id_from_zone(zid)
          sub = Zones.find_zone_group(model, cid, zid)
          if sub && sub.valid?
            # Len zvyraznenie ghostu v modeli — panel uz o aktivnej zone vie (poslal ju), preto
            # potlacime observer, nech clear/add nevynuluje selectedCabId ani aktivnu zonu.
            suspend_selection_sync do
              model.selection.clear
              model.selection.add(sub)
            end
          end
        rescue StandardError => e
          Engine.log_error(e, 'handle_select_zone')
        end

        # Spolocny postup: nacitaj korpus zony, uprav strom, rebuild, oznac korpus, pushni.
        def apply_zone_mod(zone_id)
          model = Sketchup.active_model
          cid = cabinet_id_from_zone(zone_id)
          cab = find_cabinet_by_id(model, cid)
          raise 'Korpus zony sa nenasiel.' if cab.nil?

          params = existing_params(cab)
          tree = ZoneTree.sanitize(params['zone_tree'] || ZoneTree.default_tree(0))
          path = zone_path(zone_id)
          yield(tree, path)
          params['zone_tree'] = tree
          # Cela mutacia je NASA (rebuild + reselect). Observer potlacime, aby medzikroky
          # (clear/add korpusu, erase klik-nuteho ghostu) neposlali NX.clearSelected() a nevynulovali
          # selectedCabId v paneli. Aktivnu zonu drzime cez rebuild -> panel sa jej po resyncu drzi tiez.
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params)
            @active_zone_id = zone_id
            reselect(model, cab) # klik-nuty ghost je po rebuilde zmazany -> vyber korpus nanovo
          end
          push_selected(model) # PRESNE jeden resync panela (loadSelected s aktivnou zonou)
          cab
        end

        # --- akcie: sablony --------------------------------------------------
        def handle_save_template(payload)
          data = parse(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          config = cab ? template_config_from(Store.config(cab) || {}) : template_config_from_fields(data)

          res = UI.inputbox(['Nazov sablony:'], [suggest_template_name(cab, data)], 'Ulozit sablonu')
          return if res == false # zrusene

          name = res[0].to_s.strip
          return set_status('Prazdny nazov — zrusene.', true) if name.empty?

          if TemplateStore.find(name) &&
             UI.messagebox("Sablona \"#{name}\" existuje. Prepisat?", MB_YESNO) != IDYES
            return set_status('Zrusene — sablona nezmenena.')
          end
          TemplateStore.upsert(name, config)
          push_templates
          set_status("Sablona \"#{name}\" ulozena.")
        end

        def handle_delete_template(payload)
          name = parse(payload)['template'].to_s
          return set_status('Vyber sablonu na vymazanie.', true) if name.empty?
          return unless UI.messagebox("Vymazat sablonu \"#{name}\"?", MB_YESNO) == IDYES

          TemplateStore.delete(name)
          push_templates
          set_status("Sablona \"#{name}\" vymazana.")
        end

        def handle_apply_template(payload)
          name = parse(payload)['template'].to_s
          tpl = TemplateStore.find(name)
          return set_status('Sablona sa nenasla.', true) if tpl.nil?
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus.', true) if cab.nil?

          # V0.3 FIX 1: MERGE, nie nahradenie. Konstrukcne kluce (+ zony/cela) zo sablony; ale
          # material + part_overrides ciela ZACHOVAJ (sablona ich prepise len ak ich explicitne nesie).
          merged = merge_template(existing_params(cab), tpl['config'])
          CabinetBuilder.rebuild(model, cab, merged)
          finish_cab(model, cab, "Sablona \"#{name}\" pouzita na #{Store.get(cab, 'cabinet_id')}.")
        end

        # Apply sablony = MERGE cieloveho korpusu so sablonou. Konstrukcne kluce beru zo sablony
        # (tpl_config), ale material_id/front/back + part_overrides ZOSTAVAJU z ciela — aby sa
        # nezahodili uzivatelove ABS/materialove upravy. Materialove pole prepiseme LEN ak ho sablona
        # explicitne nesie (non-nil); part_overrides sa berie VZDY z ciela (sablona ich nenesie).
        def merge_template(target_params, tpl_config)
          merged = tpl_config.dup
          merged['part_overrides'] = target_params['part_overrides'] || {}
          %w[material_id front_material_id back_material_id].each do |k|
            tv = present_str(tpl_config[k])
            merged[k] = tv || target_params[k]
          end
          merged
        end

        def handle_toggle_zones(val)
          model = Sketchup.active_model
          visible = truthy?(val)
          Zones.set_visible(model, visible)
          model.active_view.invalidate if model.active_view
          set_status(visible ? 'Ghost zony zapnute.' : 'Ghost zony vypnute.')
        end

        # --- akcie: materialy + ABS (V0.3) ----------------------------------

        # Projektovy default materialu (koren dedenia, standard 7.2). Vsetky korpusy,
        # ktore dany material dedia, sa prepocitaju atomicky v jednej Undo operacii.
        def handle_set_project_material(payload)
          model = Sketchup.active_model
          data = parse(payload)
          key = data['key'].to_s
          value = present_str(data['value'])
          target = PROJECT_MATERIAL_TARGETS[key]
          return set_status('Neznámy projektový materiál.', true) unless target && value

          sheet = Materials.sheet(value)
          return set_status('Vybraný materiál sa nenašiel v katalógu.', true) unless sheet

          cfg_key, role, thickness_key = target
          selected = find_cabinet(model)
          affected = all_cabinets(model).select do |cabinet|
            present_str(existing_params(cabinet)[cfg_key]).nil?
          end

          incompatible = affected.select do |cabinet|
            params = existing_params(cabinet)
            want = thickness_key ? params[thickness_key].to_f : Fronts::FRONT_THICKNESS
            !CabinetBuilder.thickness_ok_for?(role, want, sheet['thickness'].to_f)
          end
          unless incompatible.empty?
            ids = incompatible.map { |cabinet| Store.get(cabinet, 'cabinet_id') }.join(', ')
            return set_status("Materiál #{value} má nekompatibilnú hrúbku pre: #{ids}.", true)
          end

          jobs = affected.map { |cabinet| [cabinet, existing_params(cabinet)] }
          suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: projektovy material') do
              raise 'Projektový materiál sa nepodarilo uložiť.' unless Materials.set_project_default(model, key, value)
            end
            reselect(model, selected) if selected && selected.valid?
          end
          set_status("Projektový materiál nastavený — prepočítaných #{affected.size} skriniek.")
          push_selected(model)
        end

        # Korpusovy material (override projektu). which: body/front/back; prazdna hodnota = dedi.
        def handle_set_cabinet_material(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus.', true) if cab.nil?
          data = parse(payload)
          key = { 'body' => 'material_id', 'front' => 'front_material_id', 'back' => 'back_material_id' }[data['which'].to_s]
          return set_status('Neznamy material korpusu.', true) unless key
          value = present_str(data['value'])
          params = existing_params(cab)
          params[key] = value
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: material korpusu')
            reselect(model, cab)
          end
          set_status("Materiál korpusu #{value ? 'nastavený' : 'dedí z projektu'}.")
          push_selected(model)
        end

        # Per-dielec material (part_override, viťazi nad dedenim). role_key identifikuje dielec.
        def handle_set_part_material(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
          rk = data['role_key'].to_s
          return set_status('Chyba identifikacie dielca.', true) if rk.empty?
          mat = present_str(data['material_id'])
          params = existing_params(cab)
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          if mat then rec['material_id'] = mat else rec.delete('material_id') end
          store_override(ov, rk, rec)
          rebuild_focus_part(model, cab, rk, params, "Materiál dielca #{mat ? 'nastavený' : 'zdedený'}.")
        end

        # ABS hrana dielca (part_override.edges[code]). abs_id: konkretne / '' (bez ABS) / '__inherit__' (dedi).
        def handle_set_part_edge(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
          rk = data['role_key'].to_s
          code = data['edge'].to_s
          return set_status('Chyba identifikacie dielca/hrany.', true) if rk.empty? || !%w[L1 L2 W1 W2].include?(code)
          raw = data['abs_id']
          params = existing_params(cab)
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          edges = rec['edges'] || {}
          if raw.to_s == '__inherit__'
            edges.delete(code)          # spat na pravidlovy default
          else
            edges[code] = present_str(raw) # nil (bez ABS) alebo abs_id — explicitny override
          end
          if edges.empty? then rec.delete('edges') else rec['edges'] = edges end
          store_override(ov, rk, rec)
          label = raw.to_s == '__inherit__' ? 'podľa pravidla' : (present_str(raw) ? 'nastavená' : 'bez ABS')
          rebuild_focus_part(model, cab, rk, params, "Hrana #{code} — #{label}.")
        end

        # "Pouzit na podobne diely" — skopiruje material + ABS zdrojoveho dielca na vsetky dielce
        # ROVNAKEJ ROLY. scope: 'cabinet' (ta ista skrinka) / 'model' (vsetky korpusy). Kluc = role_key.
        def handle_apply_to_similar(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
          rk = data['role_key'].to_s
          scope = data['scope'].to_s == 'model' ? 'model' : 'cabinet'
          src = find_part_by_role_key(cab, rk)
          return set_status('Zdrojovy dielec sa nenasiel.', true) if src.nil?
          role = Store.get(src, 'role')
          scfg = Store.config(src) || {}
          src_mat = scfg['material_id']
          src_edges = dup_edges(scfg['edges'] || {})
          cabs = scope == 'model' ? all_cabinets(model) : [cab]
          count = 0
          suspend_selection_sync do
            cabs.each do |c|
              keys = parts_of_role(c, role)
              next if keys.empty?
              params = existing_params(c)
              ov = (params['part_overrides'] ||= {})
              keys.each do |k|
                rec = ov[k] || {}
                rec['material_id'] = src_mat if src_mat
                rec['edges'] = dup_edges(src_edges)
                ov[k] = rec
                count += 1
              end
              CabinetBuilder.rebuild(model, c, params, op_name: 'NOXUN: material/ABS na podobne')
            end
            focus_part(model, cab, rk)
          end
          set_status("Použité na #{count} dielcov #{scope == 'model' ? 'v celom modeli' : 'v skrinke'} (rola #{role}).")
          push_selected(model)
        end

        # Rebuild korpusu s pripravenymi params + fokus na dielec (role_key) + resync panela.
        def rebuild_focus_part(model, cab, rk, params, msg)
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: uprava dielca')
            focus_part(model, cab, rk)
          end
          set_status(msg)
          push_selected(model) # posle korpus + part_card (dielec je po fokuse vo vybere) -> karta ostane
        end

        # Po rebuilde: najdi "ten isty" dielec podla role_key a oznac ho (karta ostane na tom dielci).
        def focus_part(model, cab, rk)
          part = find_part_by_role_key(cab, rk)
          reselect(model, part || cab)
        end

        # Zapis/vycisti zaznam part_override pod klucom rk (prazdny zaznam sa odstrani).
        def store_override(ov, rk, rec)
          if rec.nil? || rec.empty? then ov.delete(rk) else ov[rk] = rec end
        end

        # --- Ruby -> JS ------------------------------------------------------
        def push_init
          model = Sketchup.active_model
          cab = find_cabinet(model)
          data = {
            defaults: {
              lower: CabinetBuilder::LOWER_DEFAULTS,
              upper: CabinetBuilder::UPPER_DEFAULTS
            },
            zones_visible: Zones.visible?(model),
            templates: template_list,
            materials: materials_payload,            # V0.3 katalog (dosky + ABS) pre selecty
            project_materials: project_materials(model), # V0.3 projektove defaulty (koren dedenia)
            selected: cab ? cabinet_payload(cab) : nil
          }
          js("NX.init(#{data.to_json})")
        end

        def push_selected(model)
          # fix #6: "sync tick" resolvera — ak vznikla kopia korpusu (zdielane cabinet_id),
          # pridelí sa jej nove ID + vlastne ghosty este pred nacitanim vyberu do panela.
          CabinetBuilder.dedup_copies(model) if defined?(CabinetBuilder)
          zone = find_selected_zone(model)
          cab = find_cabinet(model)
          if cab.nil?
            @active_zone_id = nil
            return js('NX.clearSelected()')
          end
          az = if zone && zone['cabinet_id'] == Store.get(cab, 'cabinet_id')
                 zone['zone_id']
               elsif belongs?(@active_zone_id, cab)
                 @active_zone_id
               end
          @active_zone_id = az
          payload = cabinet_payload(cab)
          payload['active_zone'] = az
          # V0.3: ak je vo vybere DIELEC (kind=part), priloz kartu dielca (ABS/materialovy editor).
          part = find_selected_part(model)
          payload['part_card'] = part ? part_card_payload(model, cab, part) : nil
          js("NX.loadSelected(#{payload.to_json})")
        end

        def push_templates
          js("NX.setTemplates(#{template_list.to_json})")
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?

          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.js')
        end

        # --- resolvery -------------------------------------------------------
        # Najde NOXUN korpus vo vybere: priamo (kind=cabinet), alebo z dielca/zony cez cabinet_id.
        def find_cabinet(model)
          sel = model.selection.to_a
          return nil if sel.empty?

          direct = sel.find { |e| Store.kind(e) == 'cabinet' }
          return direct if direct

          part = sel.find { |e| Store.noxun?(e) && Store.get(e, 'cabinet_id') }
          return nil unless part

          find_cabinet_by_id(model, Store.get(part, 'cabinet_id'))
        end

        def find_cabinet_by_id(model, cid)
          return nil if cid.nil?

          Ids.each_cabinet(model) do |inst|
            return inst if Store.get(inst, 'cabinet_id') == cid
          end
          nil
        end

        # Zona vo vybere (klik na ghost). Testovatelne aj priamo cez find_zone_in([entita]).
        def find_selected_zone(model)
          find_zone_in(model.selection.to_a)
        end

        def find_zone_in(entities)
          z = entities.find { |e| Store.kind(e) == 'zone' }
          return nil unless z

          cfg = Store.config(z) || {}
          { 'zone_id' => Store.get(z, 'id'), 'cabinet_id' => Store.get(z, 'cabinet_id'),
            'width' => cfg['width'], 'height' => cfg['height'], 'depth' => cfg['depth'],
            'shelves' => cfg['shelves'] }
        end

        # --- payload korpusu -------------------------------------------------
        def cabinet_payload(cab)
          cfg = Store.config(cab) || {}
          params = CabinetBuilder.config_to_params(cfg)
          params['cabinet_id'] = Store.get(cab, 'cabinet_id')
          params['fronts'] = Fronts.normalize_config(cfg['fronts']) # kanonicke pre riadky cela
          params['zones'] = cfg['zones'] || []                      # ploche zony pre strom + nahlad
          params['front_items'] = cfg['front_items'] || []          # rozlozene cela pre nahlad
          # svetle (available) rozmery — view-only kontrola pre pouzivatela
          params['available_width'] = cfg['available_width']
          params['available_height'] = cfg['available_height']
          params['available_depth'] = cfg['available_depth']
          params
        end

        def selected_payload(model)
          cab = find_cabinet(model)
          cab ? cabinet_payload(cab) : nil
        end

        # existujuce params korpusu (na zachovanie casti pri ciastocnej zmene)
        def existing_params(cab)
          CabinetBuilder.config_to_params(Store.config(cab) || {})
        end

        def template_config_from(cfg)
          tc = {
            'type' => cfg['type'], 'width' => cfg['width'], 'height' => cfg['height'], 'depth' => cfg['depth'],
            'thickness' => cfg['thickness'], 'floor_height' => cfg['floor_height'],
            'bottom_mode' => cfg['bottom_mode'], 'top_mode' => cfg['top_mode'], 'back_mode' => cfg['back_mode'],
            'back_thickness' => cfg['back_thickness'] || 3.0,
            'plinth_mode' => cfg['plinth_mode'], 'plinth_recess' => cfg['plinth_recess'],
            'rail_depth' => cfg['rail_depth'], 'rails_orientation' => cfg['rails_orientation'],
            'rails_top_offset' => cfg['rails_top_offset'],
            'zone_tree' => cfg['zone_tree'] || ZoneTree.default_tree((cfg['shelves'] || 0).to_i),
            'fronts' => Fronts.normalize_config(cfg['fronts'])
          }
          # V0.3 FIX 1: korpusove materialy do sablony LEN ak su na zdroji nastavene (non-nil).
          # part_overrides do sablony NEUKLADAME — su viazane na konkretne dielce/zony zdroja
          # (pri aplikacii sablony sa zachovaju z cieloveho korpusu).
          %w[material_id front_material_id back_material_id].each do |k|
            v = present_str(cfg[k])
            tc[k] = v if v
          end
          tc
        end

        def template_config_from_fields(data)
          tc = template_config_from(data)
          tc['zone_tree'] = data['zone_tree'] || ZoneTree.default_tree(0)
          tc['fronts'] = Fronts.normalize_config(data['fronts'])
          tc
        end

        def template_list
          TemplateStore.load
        rescue StandardError => e
          Engine.log_error(e, 'template_list')
          []
        end

        def suggest_template_name(cab, _data)
          cab ? "Kopia #{Store.get(cab, 'cabinet_id')}" : 'Nova sablona'
        end

        # --- SelectionObserver ----------------------------------------------
        def attach_observer
          model = Sketchup.active_model
          @observer ||= SelObserver.new
          model.selection.add_observer(@observer)
          @observer_model = model
        rescue StandardError => e
          Engine.log_error(e, 'Panel.attach_observer')
        end

        def detach_observer
          return unless @observer && @observer_model

          @observer_model.selection.remove_observer(@observer)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.detach_observer')
        ensure
          @observer_model = nil
        end

        def on_selection_changed
          return if @suspend_selection_sync # nase vlastne reselecty resyncnu panel explicitne

          push_selected(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.on_selection_changed')
        end

        # Programmaticka reselect (nas clear+add po rebuilde) NESMIE rozhodit panel.
        # SketchUp fire pri single `selection.add` callback `onSelectionAdded` (NIE onSelectionBulkChange)
        # a pri `selection.clear` `onSelectionCleared`. Bez potlacenia by preto medzikrok `clear`
        # poslal NX.clearSelected() a vynuloval selectedCabId — a NASLEDNY add uz panel neobnovil
        # (loadSelected nedosiel) -> po prvom drag-u priecky prestal fungovat kazdy dalsi (pouzivatel
        # musel znovu kliknut na korpus). Preto pocas nasej selekcie observer potlacime a panel
        # resyncneme PRESNE raz (push_selected) az po dokonceni. Re-entrantne bezpecne.
        def suspend_selection_sync
          prev = @suspend_selection_sync
          @suspend_selection_sync = true
          yield
        ensure
          @suspend_selection_sync = prev
        end

        # --- pomocne ---------------------------------------------------------
        def finish_cab(model, cab, msg)
          reselect(model, cab)
          set_status(msg)
          push_selected(model)
        end

        # Vystup z pripadneho editu komponentu + cisty vyber korpusu (po rebuilde).
        # Cele potlacene pre observer — zavretie editu aj clear/add su NASA zmena; panel
        # resyncne az volajuci cez push_selected (viz suspend_selection_sync).
        def reselect(model, inst)
          suspend_selection_sync do
            begin
              model.active_path = nil
            rescue StandardError
              nil
            ensure
              select_only(model, inst) if inst && inst.valid?
            end
          end
        end

        def parse(payload)
          return {} if payload.nil? || payload.to_s.strip.empty?

          v = JSON.parse(payload)
          v.is_a?(Hash) ? v : { 'value' => v }
        rescue JSON::ParserError
          { 'value' => payload }
        end

        def zone_path(zid)
          m = zid.to_s.match(/-Z([\d.]+)$/)
          return [1] unless m

          m[1].split('.').map(&:to_i)
        end

        def cabinet_id_from_zone(zid)
          m = zid.to_s.match(/^(CAB-\d+)-Z/)
          m ? m[1] : nil
        end

        def short_zone(zid)
          m = zid.to_s.match(/-Z([\d.]+)$/)
          m ? "Z#{m[1]}" : zid
        end

        def belongs?(zid, cab)
          return false if zid.nil? || cab.nil?

          cabinet_id_from_zone(zid) == Store.get(cab, 'cabinet_id')
        end

        def select_only(model, inst)
          suspend_selection_sync do
            model.selection.clear
            model.selection.add(inst)
          end
        end

        def part_count(inst)
          return 0 unless inst && inst.respond_to?(:definition)

          inst.definition.entities.grep(Sketchup::ComponentInstance).count do |e|
            Store.kind(e) == 'part'
          end
        end

        def truthy?(val)
          %w[true 1 yes].include?(val.to_s.downcase)
        end

        # --- V0.3 materialy + ABS: payloady a resolvery ---------------------

        # Katalog pre selecty: dosky (id + label) + ABS pasky (id + label + farba pre nahlad hrany).
        def materials_payload
          {
            'sheets' => Materials.sheets.map { |s|
              { 'id' => s['material_id'], 'label' => sheet_label(s), 'decor' => s['decor'],
                'thickness' => s['thickness'], 'color' => s['color'] }
            },
            'edges' => Materials.edges.map { |a|
              { 'id' => a['abs_id'], 'label' => abs_label(a), 'decor' => a['decor'],
                'thickness' => a['thickness'], 'color' => a['color'] }
            }
          }
        rescue StandardError => e
          Engine.log_error(e, 'materials_payload')
          { 'sheets' => [], 'edges' => [] }
        end

        def sheet_label(s)
          th = s['thickness'].to_f
          thl = (th == th.round ? th.round : th)
          "#{s['decor']} · #{s['type']} #{thl} mm"
        end

        def abs_label(a)
          "#{a['decor']} #{a['thickness']} mm"
        end

        def project_materials(model)
          Materials.project_defaults(model)
        rescue StandardError => e
          Engine.log_error(e, 'project_materials')
          {}
        end

        # Dielec vo vybere (kind=part) — po dvojkliku do korpusu a kliknuti na dielec.
        def find_selected_part(model)
          model.selection.to_a.find { |e| Store.kind(e) == 'part' }
        end

        # Karta dielca pre UI (ABS/materialovy editor): rola, rozmery, VYSLEDNY material + ABS hrany,
        # labely hran per rola, priznaky overridov, pocet podobnych (rovnaka rola v skrinke).
        def part_card_payload(_model, cab, part)
          cfg = Store.config(part) || {}
          role = Store.get(part, 'role').to_s
          rk = present_str(Store.get(part, 'role_key')) || fallback_role_key(cab, part)
          cabcfg = Store.config(cab) || {}
          ov = ((cabcfg['part_overrides'] || {})[rk] || {})
          {
            'role_key' => rk, 'role' => role, 'name' => Store.get(part, 'name'),
            'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'],
            'material_id' => cfg['material_id'],
            'edges' => cfg['edges'] || AbsRules.empty_edges,
            'edge_labels' => AbsRules.edge_labels(role),
            'edge_sides' => AbsRules.edge_sides(role), # V0.3 FIX 3: mapa hrana->strana pre SVG (1 zdroj pravdy)
            'edge_overrides' => (ov['edges'] || {}), # ktore hrany maju rucny override (UI odlisi "dedi")
            'has_material_override' => !ov['material_id'].nil?,
            'similar_count' => count_role(cab, role),
            'cabinet_id' => Store.get(cab, 'cabinet_id')
          }
        rescue StandardError => e
          Engine.log_error(e, 'part_card_payload')
          nil
        end

        # role_key z plocheho atributu; fallback pre stare dielce = part_id bez cabinet_id prefixu.
        def fallback_role_key(cab, part)
          pid = Store.get(part, 'part_id').to_s
          cid = Store.get(cab, 'cabinet_id').to_s
          (!cid.empty? && pid.start_with?("#{cid}-")) ? pid[(cid.length + 1)..-1] : pid
        end

        def find_part_by_role_key(cab, rk)
          return nil unless cab && cab.respond_to?(:definition) && cab.valid?
          cab.definition.entities.grep(Sketchup::ComponentInstance).find do |e|
            Store.kind(e) == 'part' && present_str(Store.get(e, 'role_key')) == rk
          end
        end

        # role_key vsetkych dielcov danej roly v korpuse (pre "pouzit na podobne").
        def parts_of_role(cab, role)
          return [] unless cab && cab.respond_to?(:definition) && cab.valid?
          cab.definition.entities.grep(Sketchup::ComponentInstance).select do |e|
            Store.kind(e) == 'part' && Store.get(e, 'role') == role
          end.map { |e| present_str(Store.get(e, 'role_key')) }.compact
        end

        def count_role(cab, role)
          return 0 unless cab && cab.respond_to?(:definition) && cab.valid?
          cab.definition.entities.grep(Sketchup::ComponentInstance).count do |e|
            Store.kind(e) == 'part' && Store.get(e, 'role') == role
          end
        end

        def all_cabinets(model)
          out = []
          Ids.each_cabinet(model) { |i| out << i }
          out
        end

        # Plytka kopia edges mapy (len zname kluce L1/L2/W1/W2, zachova nil = bez ABS).
        def dup_edges(edges)
          out = {}
          return out unless edges.is_a?(Hash)
          %w[L1 L2 W1 W2].each { |k| out[k] = edges[k] if edges.key?(k) }
          out
        end

        # String alebo nil (prazdny -> nil). Pre material dedenie + override cistenie.
        def present_str(v)
          return nil if v.nil?
          s = v.to_s.strip
          s.empty? ? nil : s
        end
      end

      # Observer musi zit ako objekt s referenciou (Panel modul ju drzi v @observer).
      class SelObserver < Sketchup::SelectionObserver
        def onSelectionBulkChange(_selection)
          Panel.on_selection_changed
        end

        def onSelectionCleared(_selection)
          Panel.on_selection_changed
        end

        # SketchUp fire pri pridani/odobrati JEDNEJ entity `onSelectionAdded`/`onSelectionRemoved`
        # (NIE onSelectionBulkChange). Bez nich by sa panel po jednotlivom uzivatelskom pridani do
        # vyberu neobnovil. on_selection_changed respektuje suspend guard (nase reselecty su potlacene).
        def onSelectionAdded(_selection, _element)
          Panel.on_selection_changed
        end

        def onSelectionRemoved(_selection, _element)
          Panel.on_selection_changed
        end
      end
    end
  end
end
