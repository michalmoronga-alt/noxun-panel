# frozen_string_literal: true
# MR-2B: jedna session vzhladu v existujucej sekcii Materialy.
require 'json'
require 'tmpdir'
require 'base64'
require 'securerandom'
require 'time'

module Noxun
  module Engine
    module MaterialsDialog
      APPEARANCE_ENVELOPE = %w[request_token model_guid section kind anchor_id].freeze
      class AppearanceSessionError < Materials::AppearanceError; end

      class << self
        def handle_appearance_action(name, payload)
          data = JSON.parse(payload.to_s)
          raise AppearanceSessionError, 'Neplatná požiadavka vzhľadu.' unless data.is_a?(Hash)
          action = name.delete_prefix('appearance_')
          return appearance_prepare(data) if action == 'prepare'
          if action == 'close'
            appearance_invalidate! if appearance_owns?(@appearance_session, data)
            return
          end
          appearance_with_action(data, action) do |session|
            case action
            when 'pick', 'edit' then appearance_work(session, data, action)
            when 'save', 'reset' then appearance_publish(session, data, action)
            when 'apply'
              raise AppearanceSessionError, 'Nie je pripravený vzhľad na opakovanie.' unless session[:pending]
              result = appearance_apply_published(session, data)
              [true, appearance_applied_message(result)]
            else raise AppearanceSessionError, 'Neznáma akcia vzhľadu.'
            end
          end
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.appearance dispatch')
        end

        def appearance_invalidate!
          @appearance_session = nil
          # Subory su vzdy v lokalnom Dir.mktmpdir bloku s vlastnym ensure.
          # Busy beziacej akcie sa uvolni az pri jej skutocnom dokonceni.
        end

        def appearance_prepare(data)
          appearance_invalidate!
          session = { envelope: data.slice(*APPEARANCE_ENVELOPE), model: Sketchup.active_model,
                      doc_key: data['model_guid'], studio_token: StudioDialog.instance_token,
                      sink: @client_sink, token: SecureRandom.uuid, pending: false }
          @appearance_session = session
          appearance_context!(session, data)
          snapshot = appearance_snapshot(data['kind'], data['anchor_id'])
          session.merge!(scope: snapshot['scope'], baseline: snapshot['baseline'], descriptor: snapshot['appearance'])
          appearance_select_source(session, snapshot)
          appearance_emit(session, 'appearanceReady', session[:envelope].merge(
            'ok' => true, 'session_token' => session[:token], 'state' => appearance_state(session), 'message' => ''))
        rescue StandardError => e
          appearance_emit(session, 'appearanceReady', session[:envelope].merge('ok' => false, 'message' => e.message)) if session
          appearance_invalidate! if @appearance_session.equal?(session)
        end

        # Jeden busy gate aj pocas natívneho pickeru. Cudzia/zaniknuta session
        # nema pravo zapisovat ani uvolnit gate akcie, ktora este dobieha.
        def appearance_with_action(data, action)
          session = @appearance_session
          return unless appearance_owns?(session, data)
          unless data['action_token'].is_a?(String) && !data['action_token'].empty?
            return appearance_result(session, data, action, false, 'Chýba identita akcie vzhľadu.')
          end
          return appearance_result(session, data, action, false, 'Predchádzajúca akcia ešte prebieha.') if @appearance_busy

          ticket = Object.new
          @appearance_busy = ticket
          begin
            appearance_validate!(session, data)
            ok, message = yield session
            appearance_result(session, data, action, ok, message)
          rescue StandardError => e
            appearance_result(session, data, action, false, e.message)
          ensure
            @appearance_busy = nil if @appearance_busy.equal?(ticket)
          end
        end

        # Korelovana nadstavba EXISTUJUCEHO set_decor_color; echo nie je ACK.
        def appearance_color(data)
          context = data['appearance_context']
          return unless context.is_a?(Hash)
          appearance_with_action(context, 'color') do |session|
            unless Materials.identity_norm(data['group_id']) == session[:scope][0]
              raise AppearanceSessionError, 'Farba patrí inej dekorovej skupine.'
            end
            yield
          end
        end

        def appearance_context!(session, data, guarded: false)
          unless %w[sheet edge].include?(data['kind']) && data['section'] == 'mat' &&
                 %w[request_token anchor_id model_guid].all? { |key| data[key].is_a?(String) && !data[key].empty? }
            raise AppearanceSessionError, 'Neplatný kontext vzhľadu.'
          end
          raise AppearanceSessionError, 'Okno alebo dokument sa medzitým zmenil.' unless appearance_origin_alive?(session)
          model = session[:model]
          raise AppearanceSessionError, 'Zatvor editáciu komponentu a skús znova.' unless model.active_path.nil? || model.active_path.empty?
          raise AppearanceSessionError, 'Model práve dokončuje zmenu.' if !guarded && ScaleWatch.rebuilding?
          raise AppearanceSessionError, Materials.catalog_read_only_message if Materials.catalog_read_only?
          raise AppearanceSessionError, 'Katalóg je v novom formáte — obnov Štúdio.' unless Materials.schema_write_allowed?(data['catalog_schema'])
        end

        def appearance_validate!(session, data, guarded: false)
          raise AppearanceSessionError, 'Toto okno vzhľadu už nie je aktuálne.' unless appearance_owns?(session, data)
          appearance_context!(session, data, guarded: guarded)
          current = appearance_snapshot(data['kind'], data['anchor_id'])
          unless current['scope'] == session[:scope] && current['baseline'] == session[:baseline]
            raise AppearanceSessionError, 'Skupina vzhľadu sa medzitým zmenila — otvor Vzhľad znova.'
          end
          appearance_source_valid!(session)
          current
        end

        def appearance_snapshot(kind, anchor_id)
          Materials.with_catalog_lock do
            data = Materials.appearance_fresh_catalog!
            snapshot = Materials.appearance_scope_in(data, kind, anchor_id)
            anchor = Materials.appearance_rows(data).find { |k, id, _rec| k == kind && id == anchor_id }.last
            rgb = Materials.parse_rgb(anchor['color'] || Materials::DEFAULT_DECOR_RGB)
            raise AppearanceSessionError, 'Katalógová farba nie je platná.' unless rgb
            snapshot.merge('color' => rgb)
          end
        end

        def appearance_select_source(session, snapshot)
          session.merge!(source: nil, source_revision: nil, source_descriptor: nil, mode: 'color')
          if snapshot['conflict']
            session[:mode] = 'conflict'
          elsif snapshot['appearance'] && snapshot['appearance']['mode'] == 'native'
            descriptor = snapshot['appearance']
            material = NativeAppearance.lookup(session[:model], session[:scope], descriptor['id'])
            session.merge!(source: material, source_revision: material && descriptor['id'],
                           source_descriptor: material ? nil : descriptor, mode: 'native')
          end
        end

        def appearance_source_valid!(session)
          material = session[:source]
          return unless material
          unless material.valid? && material.model == session[:model] &&
                 NativeAppearance.lookup(session[:model], session[:scope], session[:source_revision]) == material
            raise AppearanceSessionError, 'Pracovný materiál sa zmenil alebo zanikol — otvor Vzhľad znova.'
          end
        end

        def appearance_source_available?(session)
          return true if session[:source]
          descriptor = session[:source_descriptor]
          return false unless descriptor
          path = Materials.appearance_file(descriptor['id'])
          File.file?(path) && File.readable?(path)
        end

        def appearance_work(session, data, action)
          image = appearance_pick_image if action == 'pick'
          return [true, 'Výber obrázka bol zrušený.'] if action == 'pick' && image.nil?
          appearance_validate!(session, data)
          available = appearance_source_available?(session)
          if action == 'edit' && !available && session[:mode] != 'color'
            raise AppearanceSessionError, 'Zdroj vzhľadu nie je dostupný. Môžeš priradiť nový obrázok alebo použiť farbu.'
          end
          descriptor = { 'version' => 1, 'id' => SecureRandom.uuid, 'mode' => 'native', 'saved_at' => Time.now.utc.iso8601 }
          result = Dir.mktmpdir('noxun-appearance-') do |temp|
            archive = File.join(temp, 'working.skm.staging')
            if available
              NativeAppearance.export(session[:model], session[:source], archive, descriptor, session[:scope],
                                      source_descriptor: session[:source_descriptor])
            end
            appearance_validate!(session, data)
            ApplyAppearance.apply(session[:model], scope: session[:scope]) do
              fresh = appearance_validate!(session, data, guarded: true)
              material = if available
                           NativeAppearance.import_working(session[:model], archive, scope: session[:scope], revision: descriptor['id'])
                         else
                           NativeAppearance.create_working(session[:model], scope: session[:scope], color: fresh['color'], revision: descriptor['id'])
                         end
              if image
                texture = material.texture
                material.texture = texture ? [image, texture.width, texture.height] : image
              end
              material
            end
          end
          session.merge!(source: result[:material], source_revision: descriptor['id'], source_descriptor: nil,
                         mode: 'working', pending: false)
          appearance_refresh_model(session[:model])
          if action == 'edit'
            appearance_validate!(session, data)
            begin
              appearance_open_editor(session[:model], session[:source])
            rescue StandardError => e
              return [false, "Vzhľad je pripravený a použitý; panel Materiály sa nepodarilo otvoriť: #{e.message}"]
            end
          end
          [true, appearance_applied_message(result) + (action == 'edit' ? ' V paneli Materiály prepni na Upraviť.' : ' Knižnica sa nemenila.')]
        end

        def appearance_publish(session, data, action)
          mode = action == 'reset' ? 'color' : 'native'
          if mode == 'native' && !appearance_source_available?(session)
            raise AppearanceSessionError, session[:mode] == 'color' ? 'Plošná farba je už uložená; nepotrebuje ukladať vzhľad.' : 'Zdroj vzhľadu nie je dostupný.'
          end
          status, published = Materials.publish_appearance(data['kind'], data['anchor_id'], baseline: session[:baseline], mode: mode) do |path, descriptor, scope|
            appearance_validate!(session, data)
            NativeAppearance.export(session[:model], session[:source], path, descriptor, scope,
                                    source_descriptor: session[:source_descriptor])
            appearance_validate!(session, data) # odchod pocas exportu nesmie publikovat
            true
          end
          raise AppearanceSessionError, published['message'] || 'Knižnica sa medzitým zmenila — otvor Vzhľad znova.' unless status == :ok
          # Publikacia uz prebehla. Stary W sa NESMIE vratit ani pri chybe Apply.
          session.merge!(baseline: published['baseline'], descriptor: published['appearance'], source: nil,
                         source_revision: nil, source_descriptor: mode == 'native' ? published['appearance'] : nil,
                         mode: mode, pending: true)
          begin
            result = appearance_apply_published(session, data)
            [true, 'Knižnica je uložená. ' + appearance_applied_message(result) + ' Späť vráti iba zmenu modelu.']
          rescue StandardError => e
            [false, "Knižnica je uložená, vzhľad v modeli sa nepoužil: #{e.message} Môžeš ho skúsiť použiť znova."]
          ensure
            appearance_refresh_catalog
          end
        end

        def appearance_apply_published(session, data)
          appearance_validate!(session, data)
          descriptor = session[:descriptor]
          raise AppearanceSessionError, 'Chýba publikovaná revízia vzhľadu.' unless descriptor
          result = ApplyAppearance.apply(session[:model], scope: session[:scope]) do
            fresh = appearance_validate!(session, data, guarded: true)
            if descriptor['mode'] == 'native'
              material = NativeAppearance.load(session[:model], session[:scope], descriptor)
              raise AppearanceSessionError, 'Uložený súbor vzhľadu nie je dostupný.' unless material
              material
            else
              BuildAppearance.resolve(session[:model], data['kind'].to_sym, data['anchor_id'], fresh['color'])
            end
          end
          if descriptor['mode'] == 'native'
            session.merge!(source: result[:material], source_revision: descriptor['id'], source_descriptor: nil, mode: 'native')
          end
          session[:pending] = false
          appearance_refresh_model(session[:model])
          result
        end

        def appearance_state(session)
          fresh = appearance_snapshot(session[:envelope]['kind'], session[:envelope]['anchor_id'])
          appearance_source_valid!(session)
          blocked = Materials.catalog_read_only? || fresh['baseline'] != session[:baseline] || fresh['scope'] != session[:scope]
          mode = session[:mode]
          mode = 'missing' if mode == 'native' && !appearance_source_available?(session)
          preview = appearance_thumbnail(session[:source]) if session[:source]
          message = case mode
                    when 'color' then 'Plošná farba funguje samostatne, bez ukladania vzhľadu.'
                    when 'missing' then 'Uložený vzhľad nie je na tomto počítači dostupný. Môžeš vybrať nový obrázok alebo použiť farbu.'
                    when 'conflict' then 'Varianty majú rozdielny uložený vzhľad. Novým obrázkom alebo farbou môžeš nastaviť spoločný vzhľad.'
                    else preview ? 'Mierku a vlastnosti povrchu upravíš v SketchUpe.' : 'Náhľad vzhľadu nie je dostupný.'
                    end
          state = { 'mode' => mode, 'color' => fresh['color'], 'preview_url' => preview, 'message' => message,
                    'can_pick' => !blocked, 'can_edit' => !blocked && !%w[missing conflict].include?(mode),
                    'can_save' => !blocked && %w[native working].include?(mode), 'can_reset' => !blocked,
                    'can_apply' => !blocked && session[:pending] == true }
          session[:last_state] = state
        end

        def appearance_thumbnail(material)
          Dir.mktmpdir('noxun-appearance-') do |temp|
            path = File.join(temp, 'preview.png')
            return nil unless material.write_thumbnail(path, 256) == true && File.file?(path)
            'data:image/png;base64,' + Base64.strict_encode64(File.binread(path))
          end
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.appearance thumbnail')
          nil
        end

        def appearance_pick_image
          UI.openpanel('Priradiť textúru', nil, 'Obrázky|*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff||')
        end

        def appearance_open_editor(model, material)
          model.materials.current = material
          raise AppearanceSessionError, 'Panel Materiály nie je dostupný.' if UI.show_inspector('Materials') == false
        end

        def appearance_origin_alive?(session)
          session && @appearance_session.equal?(session) && session[:sink] &&
            session[:studio_token] && StudioDialog.instance_token == session[:studio_token] && StudioDialog.dialog_alive? &&
            session[:model] && Sketchup.active_model == session[:model] && !DocKey.foreign?(session[:doc_key], session[:model])
        end

        def appearance_owns?(session, data)
          appearance_origin_alive?(session) && data.is_a?(Hash) && session[:token] == data['session_token'] &&
            APPEARANCE_ENVELOPE.all? { |key| session[:envelope][key] == data[key] }
        end

        def appearance_emit(session, method, payload)
          return false unless appearance_origin_alive?(session)
          session[:sink].call("MD.#{method}(#{JSON.generate(payload)})")
        end

        def appearance_result(session, data, action, ok, message)
          return unless appearance_origin_alive?(session)
          begin
            state = appearance_state(session)
          rescue StandardError => e
            state = (session[:last_state] || { 'mode' => session[:mode] || 'color', 'color' => Materials::DEFAULT_DECOR_RGB, 'preview_url' => nil }).merge(
              'message' => e.message, 'can_pick' => false, 'can_edit' => false, 'can_save' => false, 'can_reset' => false, 'can_apply' => false)
          end
          appearance_emit(session, 'appearanceResult', session[:envelope].merge(
            'session_token' => session[:token], 'action_token' => data['action_token'], 'action' => action,
            'ok' => ok == true, 'state' => state, 'message' => message))
        end

        def appearance_applied_message(result)
          text = "Vzhľad použitý: #{result[:updated_parts]} dielcov, #{result[:updated_edges]} ABS hrán."
          text += " Preskočené dielce: #{result[:skipped_parts]}." if result[:skipped_parts].to_i.positive?
          text
        end

        def appearance_refresh_model(model)
          Panel.push_selected(model, dedup: false) if defined?(Panel)
          refresh_studio_after_model_write
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.appearance model refresh')
        end

        def appearance_refresh_catalog
          after_catalog_change
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.appearance catalog refresh')
        end
      end
    end
  end
end
