# frozen_string_literal: true
# Noxun Engine — NASTROJE-1: SketchUp vrstva nastroja Mower.
#   rotacie -90 / +90 / 180 (svetova os Z, pivot = stred obalky)
#   Z = 0 a Z posun na hodnotu (dialog nizsie)
#   kopia vlavo / vpravo o SIRKU KORPUSU po jeho VLASTNEJ osi X
#
# Vypocty su v cistom jadre `mower_calc.rb`; tu je len praca s modelom.
# Kazda mutacia NOXUN objektu ide cez `Tools.settle!` (bariera observera +
# kontrola rigidity) a `Tools.mutate` (guard, jedna operacia, ghost zony,
# zapamatanie polohy).
module Noxun
  module Engine
    module Tools
      module Mower
        # NOTE 11 (SCOPE OUT): `BoardBuilder.build` polohu neprijima — sev pribudne
        # s vkladanim dosiek na klik (GHOST-D1), dovtedy kopia dosky nie je.
        MSG_BOARD_COPY = 'Noxun Nástroje: kópiu dosky zatiaľ nevieme — vlož ju z panela.'
        # Handshake s Inspectorom (Codex #293 kolo 1, P2).
        MSG_FLUSH_WAIT    = 'Noxun Nástroje: čakám, kým Inspector dopíše rozpísanú zmenu…'
        MSG_FLUSH_INVALID = 'Noxun Nástroje: v Inspectore sú červené polia — oprav ich a skús znova ' \
                            '(kópia by inak vznikla zo starých hodnôt).'
        MSG_FLUSH_TIMEOUT = 'Noxun Nástroje: Inspector neodpovedal — skús znova.'
        MSG_FLUSH_LOST    = 'Noxun Nástroje: skrinka sa medzitým stratila — kópia sa nevložila.'

        class << self
          # --- rotacie a vyska -----------------------------------------------

          def rotate(degrees)
            with_target("Noxun: Otočiť #{degrees}°") do |model, inst, noxun|
              pivot = inst.bounds.center
              tr = Geom::Transformation.rotation(pivot, Z_AXIS, degrees.degrees)
              Tools.mutate(model, inst, "Noxun: Otočiť #{degrees}°", noxun) do
                model.active_entities.transform_entities(tr, inst)
              end
            end
          end

          def set_z_zero
            move_z(0.0, 'Noxun: Z = 0')
          end

          def set_z(z_mm)
            move_z(z_mm.to_f, "Noxun: Z = #{z_mm.to_f.round} mm")
          end

          # --- kopia -----------------------------------------------------------

          def copy(dir)
            model = Tools.active_model
            return nil unless model

            inst = Tools.pick_target(model)
            return nil unless inst

            route = Tools.route(model, inst)
            return nil if Tools.refused_context?(route)
            return Tools.warn(MSG_BOARD_COPY) if route == :board

            # GHOST (V1-04, Codex #293 P2): iny sposob vkladania = koniec
            # zivotneho cyklu beziacej session. Ghost visiaci na kurzore by inak
            # dalsim klikom commitol STARY plan — vzor `Panel.handle_insert_copy`.
            GhostTool.cancel_session('kópia nástrojom') if defined?(GhostTool)

            return copy_legacy(model, inst, dir) unless route == :cabinet

            start_cabinet_copy(model, inst, dir)
          end

          # --- handshake s Inspectorom (Codex #293 kolo 1, P2) -----------------
          # Odpoved panela na `NX.flushForNative`. Prichadza DVOMA cestami:
          #   * `native_flush_done` — panel nemal co flushnut (`nothing`) alebo
          #     hlasi cervene polia (`invalid`);
          #   * `apply_all` s `native_op` — panel rozpisanu zmenu DOPISAL, takze
          #     kopia bezi az v tom callbacku (`flushed`), teda nad CERSTVYM
          #     configom.
          # Smer kopie sa berie VYHRADNE z cakajuceho zaznamu servera — echo
          # klienta je len korelacny token, nie autorita.
          def resolve_flush(token, result)
            pending = @pending
            case MowerCalc.pending_decision(pending, token, result, now)
            when :copy
              @pending = nil
              finish_pending_copy(pending)
            when :invalid
              @pending = nil
              Tools.warn(MSG_FLUSH_INVALID)
            when :expired
              @pending = nil
              Tools.warn(MSG_FLUSH_TIMEOUT)
            end
            nil
          rescue StandardError => e
            @pending = nil
            Engine.log_error(e, 'Tools::Mower.resolve_flush')
            nil
          end

          # LEN pre testy a diagnostiku — nikto na nu nespolieha v produkcii.
          def pending_copy
            @pending
          end

          def reset_pending!
            @pending = nil
          end

          private

          # Bez otvoreneho Inspectora niet co flushovat — kopia ide hned.
          def start_cabinet_copy(model, src, dir)
            cid = Store.get(src, 'cabinet_id').to_s
            return copy_cabinet(model, src, dir) if cid.empty? || !inspector_live?

            @flush_seq = (@flush_seq || 0) + 1
            token = MowerCalc.flush_token(@flush_seq, now)
            @pending = { 'token' => token, 'dir' => dir.to_sym, 'cabinet_id' => cid,
                         'deadline' => now + MowerCalc::FLUSH_TIMEOUT_S }
            Tools.info(MSG_FLUSH_WAIT)
            Panel.request_native_flush(token, 'copy', dir)
            arm_flush_timeout(token)
            nil
          end

          def finish_pending_copy(pending)
            model = Tools.active_model
            return Tools.warn(MSG_FLUSH_LOST) unless model

            src = cabinet_by_id(model, pending['cabinet_id'])
            return Tools.warn(MSG_FLUSH_LOST) unless src && src.valid?
            return nil if Tools.refused_context?(Tools.route(model, src))

            copy_cabinet(model, src, pending['dir'])
          end

          # Nikdy ticha kopia zo stareho configu: ked panel neodpovie, prikaz padne.
          def arm_flush_timeout(token)
            return unless defined?(UI) && UI.respond_to?(:start_timer)

            UI.start_timer(MowerCalc::FLUSH_TIMEOUT_S + 0.2, false) do
              begin
                p = @pending
                if p.is_a?(Hash) && p['token'].to_s == token.to_s
                  @pending = nil
                  Tools.warn(MSG_FLUSH_TIMEOUT)
                end
              rescue StandardError => e
                Engine.log_error(e, 'Tools::Mower flush timeout')
              end
            end
          end

          def inspector_live?
            defined?(Panel) && Panel.respond_to?(:dialog_alive?) && Panel.dialog_alive?
          rescue StandardError
            false
          end

          def cabinet_by_id(model, cid)
            found = nil
            Ids.each_cabinet(model) do |inst|
              found = inst if found.nil? && Store.get(inst, 'cabinet_id').to_s == cid.to_s
            end
            found
          rescue StandardError => e
            Engine.log_error(e, 'Tools::Mower.cabinet_by_id')
            nil
          end

          def now
            Time.now.to_f
          end

          # Spolocna kostra prikazov, ktore len POSUVAJU/OTACAJU objekt.
          def with_target(op_name)
            model = Tools.active_model
            return nil unless model

            inst = Tools.pick_target(model)
            return nil unless inst

            route = Tools.route(model, inst)
            return nil if Tools.refused_context?(route)

            noxun = Tools.noxun_route?(route)
            return nil if noxun && !Tools.settle!(model, inst)

            yield(model, inst, noxun)
          rescue StandardError => e
            Engine.log_error(e, "Tools::Mower #{op_name}")
            Tools.warn("Noxun Nástroje: #{op_name} — zmena sa nepodarila (#{e.message}).")
            nil
          end

          # Legacy logika ostava: posun sa pocita z ORIGINU instancie (nie zo
          # spodku obalky) — presne ako doteraz, aby si Michal nemusel prevykat ruku.
          def move_z(target_z_mm, op_name)
            with_target(op_name) do |model, inst, noxun|
              current_mm = Units.to_mm(inst.transformation.origin.z)
              dz_mm = MowerCalc.z_delta_mm(current_mm, target_z_mm)
              tr = Geom::Transformation.translation(Units.vector(0, 0, dz_mm))
              Tools.mutate(model, inst, op_name, noxun) do
                model.active_entities.transform_entities(tr, inst)
              end
            end
          end

          # --- kopia NOXUN korpusu cez SEV ENGINU --------------------------------
          # Legacy `add_instance(ent.definition, tr)` vyrobil kopiu BEZ identity:
          # Inspector ju nevidel, v kusovniku nebola a pri prestavbe originalu sa
          # menila s nim. Kopia preto ide TOU ISTOU cestou ako „Vlozit kopiu"
          # v paneli — vlastna definicia, nove CAB cislo, 1 operacia = 1 Spat.
          def copy_cabinet(model, src, dir)
            return nil unless Tools.settle!(model, src)

            cfg = Store.config(src) || {}
            # R-12: `config_to_params` je uzavrety whitelist — z NOVSIEHO configu
            # by kopia vznikla s ticho orezanymi nastaveniami.
            if CabinetBuilder.newer_config?(cfg)
              return Tools.warn("#{CabinetBuilder.newer_config_message('Korpus', 'kópia by nastavenia stratila')} " \
                                'Kópia sa nevložila.')
            end

            width = cfg['width'].to_f
            return Tools.warn('Noxun Nástroje: skrinka nemá platnú šírku — kópia sa nevložila.') if width <= 0.0

            params = CabinetBuilder.config_to_params(cfg)
            # KOV-H1 (audit FIX 10): kopia je NOVA skrinka — ad-hoc polozky
            # kovania dostanu vlastnu identitu (obsah sa nemeni, len `id`).
            CabinetBuilder.rekey_hardware_manual(params)
            name = MowerCalc.copy_name(CabinetBuilder.manual_name(cfg), manual_names(model))
            params['name'] = name if name

            # Krok = SIRKA KORPUSU po VLASTNEJ osi X zdroja: pri akejkolvek rotacii
            # sedi susednost obalok korpusov (celo so zapornym `gap_sides` alebo
            # uchytka smie sirku presahovat, preto sa neriadime bbox instancie).
            offset = MowerCalc.copy_offset_mm(width, dir)
            tr = src.transformation * Geom::Transformation.translation(Units.vector(offset, 0, 0))
            inst = CabinetBuilder.build(model, params, transform: tr)
            return nil unless inst

            select_only(model, inst)
            # D-103 / audit 2 FIX 3: `dedup: false` — kopia uz ma VLASTNE CAB id,
            # takze predvoleny `dedup: true` by observerovi zalozil zbytocnu
            # poziadavku (a s nou dalsi zasah do modelu).
            Panel.push_selected(model, dedup: false) if defined?(Panel)
            Tools.info("Noxun: kópia #{Store.get(src, 'cabinet_id')} → #{Store.get(inst, 'cabinet_id')}" \
                       "#{name ? " („#{name}“)" : ''}.")
            inst
          rescue StandardError => e
            Engine.log_error(e, 'Tools::Mower.copy_cabinet')
            Tools.warn("Noxun Nástroje: kópiu sa nepodarilo vložiť (#{e.message}).")
            nil
          end

          # Rucne nazvy VSETKYCH korpusov dokumentu — z nich sa hlada najblizsia
          # volna pripona (aby dve kopie nedostali ten isty nazov).
          def manual_names(model)
            out = []
            Ids.each_cabinet(model) do |inst|
              n = CabinetBuilder.manual_name(Store.config(inst) || {})
              out << n if n
            end
            out
          rescue StandardError => e
            Engine.log_error(e, 'Tools::Mower.manual_names')
            []
          end

          # --- kopia CUDZIEHO objektu (stare DC komponenty) ---------------------
          # Dnesna (legacy) cesta bez zmeny: krok z DC `lenx` alebo z obalky
          # definicie, os a znamienko podla RotZ, `add_instance` bez identity.
          # Tieto komponenty NOXUN data nemaju, takze ani mat nemozu.
          def copy_legacy(model, inst, dir)
            step = dc_lenx(inst)
            step = local_width(inst) if step.nil? || step.zero?
            rz = rotz_deg(inst)
            axis = axis_for_copy(inst, rz)
            offset = MowerCalc.sign(dir) * legacy_flip(inst, axis, rz) * step
            unit = axis.normalize
            vec = Geom::Vector3d.new(unit.x * offset, unit.y * offset, unit.z * offset)

            copy = nil
            Tools.mutate(model, inst, 'Noxun: Kópia komponentu', false) do
              copy =
                if inst.is_a?(Sketchup::ComponentInstance)
                  inst.parent.entities.add_instance(inst.definition,
                                                    inst.transformation * Geom::Transformation.translation(vec))
                else
                  c = inst.copy
                  c.transform!(Geom::Transformation.translation(vec))
                  c
                end
            end
            select_only(model, copy) if copy && copy.valid?
            Tools.info('Noxun: kópia komponentu vložená.')
            copy
          end

          def dc_lenx(ent)
            dict = ent.attribute_dictionary('dynamic_attributes', false)
            return nil unless dict

            raw = dict['lenx'] || dict['LenX'] || dict['_lenx_formula']
            raw ? raw.to_f : nil
          rescue StandardError
            nil
          end

          def dc_rotz(ent)
            dict = ent.attribute_dictionary('dynamic_attributes', false)
            return nil unless dict

            raw = dict['rotz'] || dict['RotZ'] || dict['_rotz_formula']
            raw ? raw.to_f : nil
          rescue StandardError
            nil
          end

          def local_width(ent)
            return ent.definition.bounds.width if ent.respond_to?(:definition) && ent.definition

            ent.bounds.width
          end

          def rotz_deg(ent)
            rz = dc_rotz(ent)
            return rz unless rz.nil?

            lx = ent.transformation.xaxis
            Math.atan2(lx.y, lx.x) * 180.0 / Math::PI
          end

          # Legacy odhad osi: pri natoceni okolo +-90 stupnov sa kopiruje po Y.
          def axis_for_copy(ent, rz_deg)
            r = ((rz_deg + 180.0) % 180.0) - 90.0
            r.abs < 45.0 ? ent.transformation.yaxis : ent.transformation.xaxis
          end

          def legacy_flip(ent, axis, rz_deg)
            ang = rz_deg * Math::PI / 180.0
            if axis.parallel?(ent.transformation.xaxis)
              Math.cos(ang) >= 0.0 ? 1.0 : -1.0
            else
              Math.sin(ang) > 0.0 ? -1.0 : 1.0
            end
          end

          def select_only(model, inst)
            model.selection.clear
            model.selection.add(inst)
          rescue StandardError => e
            Engine.log_error(e, 'Tools::Mower.select_only')
          end
        end
      end

      # --- Z POSUN: maly HtmlDialog -------------------------------------------
      # Vzhlad ostava taky, aky bol v legacy Mowerovi (Michal: „nechat im svoj
      # svet"), ale lifecycle je uz enginovy: callbacky PRED `show`, unikatny
      # `preferences_key`, `set_on_closed` -> referencia `nil` a UCAST V BARIERE
      # aktualizacie (`close_plugin_dialogs`, `dialogs_closed?`, `close_all_dialogs`).
      module ZDialog
        DLG_KEY = 'noxun_engine_tools_zmove'

        class << self
          def show
            return nil if Engine.update_restart_pending?
            return nil if Engine.update_in_progress?

            dlg = ensure_dialog
            return nil unless dlg

            dlg.visible? ? dlg.bring_to_front : dlg.show
            dlg
          rescue StandardError => e
            Engine.log_error(e, 'Tools::ZDialog.show')
            nil
          end

          def hide
            return false unless @dialog

            @dialog.close
            true
          rescue StandardError => e
            Engine.log_error(e, 'Tools::ZDialog.hide')
            false
          end

          # `true` az ked dobehol `set_on_closed` — bariera pred swapom caka na
          # ZANIK okna, nie na jeho neviditelnost (CEF moze este drzat subory).
          def dialog_closed?
            @dialog.nil?
          end

          def dialog_alive?
            !@dialog.nil? && @dialog.visible?
          rescue StandardError
            false
          end

          def last_z_mm
            @last_z_mm ||= 0.0
          end

          private

          def ensure_dialog
            return @dialog if @dialog

            @dialog = UI::HtmlDialog.new(
              dialog_title: 'Noxun — Z posun',
              preferences_key: DLG_KEY,
              scrollable: false,
              resizable: false,
              width: 280,
              height: 110,
              style: UI::HtmlDialog::STYLE_UTILITY
            )
            @dialog.set_html(html)
            register_callbacks(@dialog) # PRED show!
            @dialog.set_on_closed { @dialog = nil }
            @dialog
          end

          def register_callbacks(dlg)
            dlg.add_action_callback('applyZ') do |_ctx, value|
              # D-52a: callback UZ OTVORENEHO okna nesmie po aktualizacii siahnut
              # do modelu starym kodom (API vyzaduje `tag` — jedna hlaska za okno).
              next if Engine.update_locked?(:tools_z)

              @last_z_mm = value.to_f
              Mower.set_z(@last_z_mm)
            end
          end

          def html
            <<~HTML
              <!DOCTYPE html>
              <html><head><meta charset="utf-8"><style>
              body{font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:12px}
              .row{display:flex;gap:8px;align-items:center}
              input{width:120px;padding:6px 8px;font-size:13px;border:1px solid #c8ccd0;border-radius:8px}
              button{padding:6px 10px;border-radius:8px;border:1px solid #c8ccd0;background:#f7f8fa;cursor:pointer}
              small{color:#59636e}
              </style></head><body>
              <div class="row">
                <button id="apply">Z posun</button>
                <input id="zval" type="number" step="1" value="#{last_z_mm.round}"/>
                <small>mm</small>
              </div>
              <script>
              document.getElementById('apply').addEventListener('click', function () {
                var v = parseFloat(document.getElementById('zval').value || '0');
                if (window.sketchup && window.sketchup.applyZ) { window.sketchup.applyZ(v); }
              });
              </script>
              </body></html>
            HTML
          end
        end
      end
    end
  end
end
