# frozen_string_literal: true
# Noxun Engine — panel (HtmlDialog controller + SelectionObserver). V0.2b.
# Referencia dialogu v modulovej premennej (GC); callbacky pred show;
# Ruby->JS len cez to_json; v callbackoch 'next' (nie 'return'); begin/rescue s logom.
require 'json'

module Noxun
  module Engine
    module Panel
      DLG_KEY = 'noxun_engine_panel'

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
          CabinetBuilder.rebuild(model, cab, params)
          reselect(model, cab)
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
        def handle_set_zone_field(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac delenu zonu.', true) if zid.empty?
          index = data['index'].to_i
          size = data['size']
          locked = truthy?(data['locked'])
          apply_zone_mod(zid) { |tree, path| ZoneTree.set_field!(tree, path, index, size, locked) }
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
            model.selection.clear
            model.selection.add(sub)
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
          CabinetBuilder.rebuild(model, cab, params)
          @active_zone_id = zone_id
          reselect(model, cab) # klik-nuty ghost je po rebuilde zmazany -> vyber korpus nanovo
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

          # Prepis konstrukcne kluce (+ zony/cela zo sablony), zachova id + poziciu.
          CabinetBuilder.rebuild(model, cab, tpl['config'].dup)
          finish_cab(model, cab, "Sablona \"#{name}\" pouzita na #{Store.get(cab, 'cabinet_id')}.")
        end

        def handle_toggle_zones(val)
          model = Sketchup.active_model
          visible = truthy?(val)
          Zones.set_visible(model, visible)
          model.active_view.invalidate if model.active_view
          set_status(visible ? 'Ghost zony zapnute.' : 'Ghost zony vypnute.')
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
            selected: cab ? cabinet_payload(cab) : nil
          }
          js("NX.init(#{data.to_json})")
        end

        def push_selected(model)
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
          {
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
          push_selected(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.on_selection_changed')
        end

        # --- pomocne ---------------------------------------------------------
        def finish_cab(model, cab, msg)
          reselect(model, cab)
          set_status(msg)
          push_selected(model)
        end

        # Vystup z pripadneho editu komponentu + cisty vyber korpusu (po rebuilde).
        def reselect(model, inst)
          model.active_path = nil
        rescue StandardError
          nil
        ensure
          select_only(model, inst) if inst && inst.valid?
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
          model.selection.clear
          model.selection.add(inst)
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
      end

      # Observer musi zit ako objekt s referenciou (Panel modul ju drzi v @observer).
      class SelObserver < Sketchup::SelectionObserver
        def onSelectionBulkChange(_selection)
          Panel.on_selection_changed
        end

        def onSelectionCleared(_selection)
          Panel.on_selection_changed
        end
      end
    end
  end
end
