# frozen_string_literal: true
# Noxun Engine — V0.6 C-2: okno "Katalog kovania" (sprava HardwareCatalog).
#
# Vzor materials_dialog: satelitne okno, callbacky PRED show, server je
# autorita (search VYHRADNE Ruby — audit C F12; JS len renderuje), zapisy
# s row_rev/revision guardmi, hlasky cez set_status + echo push_items.
# Cenove overenie = serverovy proposal flow HardwareCatalog (BLOCKER 1) —
# JS posiela len kod + accept, hodnoty nikdy.
#
# Request generation (F9): kazdy check_price nesie gen; vysledok so starym
# gen alebo pre zavrete okno sa zahodi (bump: novy check, close).
require 'json'

module Noxun
  module Engine
    module HardwareCatalogDialog
      DLG_KEY = 'noxun_engine_hw_catalog_v1'

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
          Engine.log_error(e, 'HardwareCatalogDialog.show')
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Katalóg kovania',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 680,
            height: 560,
            min_width: 520,
            min_height: 400,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'hardware_catalog.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed do
            bump_gen # F9: zavrete okno zneplatni bezace cenove overenia
            @dialog = nil
          end
          @dialog
        end

        def register_callbacks(dlg)
          cb(dlg, 'ready')          { |_p| push_state }
          cb(dlg, 'hw_search')      { |p| handle_search(p) }
          cb(dlg, 'hw_create')      { |p| handle_create(p) }
          cb(dlg, 'hw_patch')       { |p| handle_patch(p) }
          cb(dlg, 'hw_delete')      { |p| handle_delete(p) }
          cb(dlg, 'hw_check_price') { |p| handle_check_price(p) }
          cb(dlg, 'hw_apply_price') { |p| handle_apply_price(p) }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(hw_catalog): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'hw_catalog js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "hw_catalog cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # --- Ruby -> JS ------------------------------------------------------

        def push_state
          js("MDH.init(#{state_payload.to_json})")
        end

        def push_items
          js("MDH.setItems(#{items_payload.to_json})")
        end

        def state_payload
          items_payload.merge(
            'version' => Engine::VERSION,
            'categories' => HardwareCatalog::CATEGORIES,
            'units' => HardwareCatalog::UNITS
          )
        end

        def items_payload
          {
            'items' => HardwareCatalog.items.map { |i|
              i.merge('row_rev' => HardwareCatalog.record_rev(i))
            },
            'revision' => HardwareCatalog.catalog_revision,
            'state' => HardwareCatalog.state.to_s,
            'state_reason' => HardwareCatalog.state_reason
          }
        end

        def set_status(msg, error = false)
          js("MDH.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?
          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'HardwareCatalogDialog.js')
        end

        # --- generation (F9) -------------------------------------------------

        def bump_gen
          @gen = @gen.to_i + 1
        end

        # --- handlery --------------------------------------------------------

        # Search je VYHRADNE serverovy (F12) — JS posiela query/kategoriu/flag
        # neaktivnych a len renderuje vratene poradie.
        def handle_search(payload)
          data = JSON.parse(payload.to_s)
          results = HardwareCatalog.search(
            HardwareCatalog.items, data['query'].to_s,
            category: data['category'].to_s,
            include_inactive: data['include_inactive'] == true,
            top: 50
          )
          js("MDH.results(#{{ 'codes' => results.map { |i| i['item_code'] },
                              'query' => data['query'].to_s }.to_json})")
        end

        def handle_create(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareCatalog.create_item(data['fields'].is_a?(Hash) ? data['fields'] : {})
          case status
          when :ok
            push_items
            set_status("Položka #{info['item_code']} pridaná.")
            js('MDH.created()')
          when :exists
            set_status("Kód #{info} už v katalógu je — kódy sú jedinečné.", true)
          when :invalid
            set_status("Nedá sa uložiť — #{info}.", true)
          when :read_only
            set_status("Katalóg je len na čítanie: #{info}", true)
          else
            set_status('Uloženie zlyhalo.', true)
            push_items
          end
        end

        def handle_patch(payload)
          data = JSON.parse(payload.to_s)
          status, info = HardwareCatalog.patch_item(
            data['code'].to_s, data['patch'].is_a?(Hash) ? data['patch'] : {},
            row_rev: data['row_rev'].to_s
          )
          case status
          when :ok
            push_items
            set_status('Uložené.')
          when :conflict
            set_status('Položka sa medzitým zmenila — hodnoty sa obnovili, uprav znova.', true)
            push_items
          when :not_found
            set_status('Položka sa nenašla — katalóg sa obnovil.', true)
            push_items
          when :invalid
            set_status(info.to_s.empty? ? 'Neplatná hodnota.' : info.to_s, true)
            push_items
          when :read_only
            set_status("Katalóg je len na čítanie: #{info}", true)
            push_items
          else
            set_status('Uloženie zlyhalo.', true)
            push_items
          end
        end

        def handle_delete(payload)
          data = JSON.parse(payload.to_s)
          status, = HardwareCatalog.delete_item(data['code'].to_s, row_rev: data['row_rev'].to_s)
          case status
          when :ok
            push_items
            set_status("Položka #{data['code']} zmazaná.")
          when :conflict
            set_status('Položka sa medzitým zmenila — skontroluj a skús znova.', true)
            push_items
          when :not_found
            push_items
          when :read_only
            set_status(HardwareCatalog.state_reason, true)
          else
            set_status('Zmazanie zlyhalo.', true)
            push_items
          end
        end

        # Zivy check ceny — vysledok pride async; gen + code echo strazi, aby
        # stary vysledok neprepisal detail inej polozky (F9).
        def handle_check_price(payload)
          data = JSON.parse(payload.to_s)
          code = data['code'].to_s
          gen = bump_gen
          dlg = @dialog
          HardwareCatalog.check_price!(code, url: data['url'].to_s) do |res|
            next unless @gen.to_i == gen && @dialog && @dialog.equal?(dlg) && @dialog.visible?
            js("MDH.priceResult(#{res.merge('code' => code, 'gen' => gen).to_json})")
          end
        end

        def handle_apply_price(payload)
          data = JSON.parse(payload.to_s)
          status, rec = HardwareCatalog.apply_price_proposal!(data['code'].to_s)
          case status
          when :ok
            push_items
            set_status("Cena #{rec['item_code']} zapísaná (overená dnes).")
            js("MDH.priceApplied(#{{ 'code' => rec['item_code'] }.to_json})")
          when :no_proposal
            set_status('Návrh ceny už nie je platný — spusti Overiť znova.', true)
          when :conflict
            set_status('Položka sa od overenia zmenila — spusti Overiť znova.', true)
            push_items
          when :read_only
            set_status(HardwareCatalog.state_reason, true)
          else
            set_status('Zápis ceny zlyhal.', true)
            push_items
          end
        end
      end
    end
  end
end
