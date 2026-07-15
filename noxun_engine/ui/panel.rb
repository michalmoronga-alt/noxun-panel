# frozen_string_literal: true
# Noxun Engine — panel (HtmlDialog controller + SelectionObserver).
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
            width: 380,
            height: 560,
            min_width: 340,
            min_height: 460,
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
          dlg.add_action_callback('ready') do |_ctx|
            begin
              push_init
            rescue StandardError => e
              Engine.log_error(e, 'cb ready')
            end
            next
          end

          dlg.add_action_callback('insert_cabinet') do |_ctx, payload|
            begin
              handle_insert(payload)
            rescue StandardError => e
              Engine.log_error(e, 'cb insert_cabinet')
              set_status("Chyba: #{e.message}", true)
            end
            next
          end

          dlg.add_action_callback('apply_changes') do |_ctx, payload|
            begin
              handle_apply(payload)
            rescue StandardError => e
              Engine.log_error(e, 'cb apply_changes')
              set_status("Chyba: #{e.message}", true)
            end
            next
          end

          dlg.add_action_callback('toggle_zones') do |_ctx, val|
            begin
              handle_toggle_zones(val)
            rescue StandardError => e
              Engine.log_error(e, 'cb toggle_zones')
            end
            next
          end
        end

        # --- akcie -----------------------------------------------------------
        def handle_insert(payload)
          model = Sketchup.active_model
          params = parse(payload)
          inst = CabinetBuilder.build(model, params)
          select_only(model, inst)
          cid = Store.get(inst, 'cabinet_id')
          set_status("Vlozeny #{cid} — #{part_count(inst)} dielcov.")
          push_selected(model)
        end

        def handle_apply(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          if cab.nil?
            set_status('Najprv oznac NOXUN korpus v modeli.', true)
            return
          end
          params = parse(payload)
          CabinetBuilder.rebuild(model, cab, params)
          cid = Store.get(cab, 'cabinet_id')
          set_status("Aktualizovany #{cid} — #{part_count(cab)} dielcov.")
          push_selected(model)
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
          data = {
            defaults: CabinetBuilder::DEFAULTS,
            zones_visible: Zones.visible?(model),
            selected: selected_payload(model)
          }
          js("NX.init(#{data.to_json})")
        end

        def push_selected(model)
          payload = selected_payload(model)
          if payload
            js("NX.loadSelected(#{payload.to_json})")
          else
            js("NX.clearSelected()")
          end
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

        # --- resolver korpusu -----------------------------------------------
        # Najde NOXUN korpus vo vybere: priamo (kind=cabinet), alebo z vybraneho
        # dielca/zony cez cabinet_id (nezavisle od active_path).
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

        def selected_payload(model)
          cab = find_cabinet(model)
          return nil unless cab

          cfg = Store.config(cab) || {}
          {
            cabinet_id: Store.get(cab, 'cabinet_id'),
            name: cfg['name'],
            width: cfg['width'], height: cfg['height'], depth: cfg['depth'],
            thickness: cfg['thickness'], floor_height: cfg['floor_height'],
            shelves: cfg['shelves'], fronts: cfg['fronts']
          }
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
          model = Sketchup.active_model
          push_selected(model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.on_selection_changed')
        end

        # --- pomocne ---------------------------------------------------------
        def parse(payload)
          return {} if payload.nil? || payload.to_s.strip.empty?

          JSON.parse(payload)
        rescue JSON::ParserError => e
          Engine.log_error(e, 'Panel.parse')
          {}
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
