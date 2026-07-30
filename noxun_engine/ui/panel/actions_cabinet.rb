# frozen_string_literal: true
# Noxun Engine - Panel: akcie korpusu (insert, apply, apply_fronts, apply_all).
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      # JEDINY whitelist konstrukcnych klucov z panela (JS zrkadlo: CONSTRUCTION_FIELDS v core.js).
      # Nove pole (napr. kovanie) = pridat TU + do CONSTRUCTION_FIELDS + <input> v HTML.
      # POZN. D-33/F6: materialy (material_id/front_material_id/back_material_id) tu VEDOME
      # nie su — PARAM_KEYS je zaroven apply whitelist a materialy maju vlastny kanal
      # set_cabinet_material; insert ich nesie explicitne v payloade (build/normalize ich pozna).
      PARAM_KEYS = %w[type width height depth thickness floor_height bottom_mode top_mode back_mode
                      back_thickness plinth_mode plinth_recess rail_depth rails_orientation
                      rails_top_offset name].freeze

      # D-39: polia vkladacej karty, ktore mozu niest zamok (JS zrkadlo: NXInsert.LOCK_FIELDS).
      INSERT_LOCK_FIELDS = %w[width height depth thickness floor_height].freeze
      INSERT_LOCK_LABELS = { 'width' => 'šírka', 'height' => 'výška', 'depth' => 'hĺbka',
                             'thickness' => 'hrúbka', 'floor_height' => 'výška sokla' }.freeze

      class << self
        # D-39 (audit B5): zamky vkladacej karty ziju v PAMATI Panel modulu — preziju
        # zatvorenie panela, zomru s restartom SketchUpu. Ziadny zapis do modelu ani
        # na disk (zamok je pracovna pomôcka navrhu, nie vyrobny zaznam). Sanitizacia:
        # whitelist poli + konecne cisla; ostatne sa zahodi.
        def handle_set_insert_locks(payload)
          raw = parse(payload)['locks']
          raw = {} unless raw.is_a?(Hash)
          clean = {}
          INSERT_LOCK_FIELDS.each do |k|
            v = raw[k]
            next if v.nil?
            f = begin
              Float(v)
            rescue ArgumentError, TypeError
              nil # neplatny vstup = ziadny zamok (validacia, nie tichy rescue logiky)
            end
            clean[k] = f if f && f.finite?
          end
          @insert_locks = clean
        end

        def insert_locks
          @insert_locks.is_a?(Hash) ? @insert_locks : {}
        end

        # F8: pri odmietnutom vklade status VYMENUJE aktivne zamky — konflikt
        # sablona x zamok (vyska x pevne cela, hrubka x material) je hned citatelny.
        def insert_locks_hint
          return '' if insert_locks.empty?
          list = insert_locks.map { |k, v| "#{INSERT_LOCK_LABELS[k] || k} #{fmt_mm(v)}" }.join(', ')
          " · aktívne zámky (zamknuté hodnoty): #{list}"
        end

        # D-38: zmena hrubky chrbta potrebuje materal tej hrubky — bez preflightu
        # rebuild spadol na hrubkovej kontrole (3 != 18), poslal cervenu hlasku a UI
        # ostalo rozsynchronizovane (select 18, model 3). Preflight material vybera
        # automaticky a NAHLAS: 1) korpusovy material rovnakej hrubky, 2) material
        # rovnakeho dekoru ako doterajsi chrbat, 3) jediny kandidat hrubky; inak
        # zmenu odmietne s jasnou hlaskou (ziadne tiche prepisanie). Pri back_mode
        # 'none' sa material/hrubka nekontroluje vobec (D-31).
        def back_preflight(params, model)
          return nil if params['back_mode'] == 'none'
          want = params['back_thickness'].to_f
          return nil unless want.positive?
          return nil unless defined?(Materials)
          # D-45: efektivne materialy citame PO body_preflighte (audit F7) — picker
          # chrbta tak vidi uz dobrany material tela, nie ten povodny.
          eff = CabinetBuilder.effective_materials(model, params)
          sheet = Materials.sheet(eff['back'])
          return nil if sheet.nil? # legacy material mimo katalogu — stary rezim
          return nil if (sheet['thickness'].to_f - want).abs <= 0.01

          body_sheet = Materials.sheet(eff['body'])
          schema = Materials.catalog_schema
          if schema >= Materials::SCHEMA_GROUPS
            # 2A-3 (audit F10): kandidat MUSI drzat skupinu + NEPRAZDNU strukturu
            # STAREHO chrbta (pick_body_sheet v2 guard) — plati aj pre skusany
            # material tela; bez zhody sa zmena ODMIETNE (ziadny tichy skok).
            pick = nil
            if body_sheet && (body_sheet['thickness'].to_f - want).abs <= 0.01
              pick = CabinetBuilder.pick_body_sheet(want, sheet, [body_sheet], schema: schema)[:pick]
            end
            pick ||= CabinetBuilder.pick_body_sheet(want, sheet, Materials.sheets, schema: schema)[:pick]
            if pick.nil?
              return { error: "Chrbát #{fmt_mm(want)} mm: v katalógu nie je materiál tejto hrúbky " \
                              'v rovnakej skupine a štruktúre — vyber materiál chrbta ručne ' \
                              '(sekcia Materiály), potom zmeň hrúbku.' }
            end
          else
            pick = body_sheet if body_sheet && (body_sheet['thickness'].to_f - want).abs <= 0.01
            unless pick
              cands = Materials.sheets.select { |s| (s['thickness'].to_f - want).abs <= 0.01 }
              same_decor = cands.select { |s| s['decor'] == sheet['decor'] }
              pick = same_decor.first || (cands.length == 1 ? cands.first : nil)
            end
            if pick.nil?
              return { error: "Chrbát #{fmt_mm(want)} mm: v katalógu nie je jednoznačný materiál tejto hrúbky — " \
                              'vyber materiál chrbta ručne (sekcia Materiály), potom zmeň hrúbku.' }
            end
          end
          params['back_material_id'] = pick['material_id']
          { note: " · chrbát: #{mat_name(pick)} #{fmt_mm(want)} mm (auto)" }
        end

        # --- D-45: hrubka <-> material tela ---------------------------------
        # Bloker z testovania: katalogovy material 18,6 mm sa nedal pouzit —
        # hrubku blokoval material a material blokovala hrubka. Deadlock rozbijaju
        # DVA smery, oba PRED rebuildom a oba NAHLAS (ziadna ticha uprava):
        #   1) zmena materialu tela  -> hrubka korpusu sa prevezme z katalogu
        #      (filozofia dosky; adopt_body_thickness!)
        #   2) zmena hrubky korpusu  -> doberie sa material tej hrubky
        #      (body_preflight, deterministicky vyber CabinetBuilder.pick_body_sheet)

        # Kratky nazov materialu do hlasok (dekor + typ; hrubka sa pise zvlast).
        def mat_name(sheet)
          return '' unless sheet.is_a?(Hash)
          [sheet['decor'], sheet['type']].map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
        end

        # Hrubka korpusu sa RIADI katalogovym materialom (vzor BoardBuilder).
        # Vrati nil (nic sa nemeni), { error: } alebo { note: } a v params
        # prepise 'thickness'. Guardy PRED zapisom (audit B1 rozsah, F8 dielce).
        # D-46: rozhodovanie zije v CabinetBuilder.adopt_thickness (JEDNA
        # implementacia s davkou projektovej predvolby) — tu ostavaju HLASKY.
        def adopt_body_thickness!(params, sheet)
          have = sheet['thickness'].to_f
          state, blocked = CabinetBuilder.adopt_thickness(params, sheet)
          case state
          when :adopted
            { note: " Hrúbka korpusu prevzatá z materiálu: #{fmt_mm(have)} mm." }
          when :range
            { error: "Materiál #{mat_name(sheet)} má #{fmt_mm(have)} mm — mimo rozsahu hrúbky korpusu " \
                     "(#{fmt_mm(CabinetBuilder::THICKNESS_RANGE[0])}–#{fmt_mm(CabinetBuilder::THICKNESS_RANGE[1])} mm). " \
                     'Materiál sa nezmenil.' }
          when :blocked
            { error: blocked_parts_msg(have, blocked) }
          end
        end

        def blocked_parts_msg(want, blocked)
          list = blocked.first(3).join(', ')
          list += " a ďalšie (#{blocked.length - 3})" if blocked.length > 3
          "Hrúbku #{fmt_mm(want)} mm blokujú dielce s vlastným materiálom inej hrúbky: #{list}. " \
            'Vráť im materiál na dedený (alebo im vyber materiál tejto hrúbky) a skús znova.'
        end

        # D-45 (audit B6): zmena hrubky tela potrebuje material tej hrubky.
        # Efektivny material (korpus > projekt) mimo katalogu = stary rezim, nic
        # sa nekontroluje (rovnako ako back_preflight). Vyber je deterministicky:
        # rovnaky dekor+typ -> jediny kandidat rovnakeho typu -> inak ODMIETNUTIE
        # s vymenovanim kandidatov (nikdy nahodny material).
        def body_preflight(params, model)
          want = params['thickness'].to_f
          return nil unless want.positive?
          return nil unless defined?(Materials)
          sheet = Materials.sheet(CabinetBuilder.effective_materials(model, params)['body'])
          return nil if sheet.nil? # legacy material mimo katalogu — stary rezim
          return nil if CabinetBuilder.thickness_eq?(sheet['thickness'], want)

          blocked = CabinetBuilder.parts_blocking_thickness(params) # audit F8
          return { error: blocked_parts_msg(want, blocked) } unless blocked.empty?

          # 2A-3 (audit F10): schema ako parameter — pri SCHEMA 2 kandidat drzi
          # skupinu + strukturu; prazdna struktura = ziadny auto vyber.
          res = CabinetBuilder.pick_body_sheet(want, sheet, Materials.sheets,
                                               schema: Materials.catalog_schema)
          pick = res[:pick]
          return { error: no_body_pick_msg(want, res[:candidates]) } if pick.nil?
          params['material_id'] = pick['material_id']
          { note: " · korpus: #{mat_name(pick)} #{fmt_mm(want)} mm (auto)" }
        end

        def no_body_pick_msg(want, candidates)
          if candidates.empty?
            return "Hrúbka korpusu #{fmt_mm(want)} mm: v katalógu nie je doska tejto hrúbky — " \
                   'pridaj ju v Materiáloch projektu, potom zmeň hrúbku.'
          end
          list = candidates.first(3).map { |s| mat_name(s) }.join(', ')
          list += ' …' if candidates.length > 3
          "Hrúbka korpusu #{fmt_mm(want)} mm: materiál sa nedá vybrať jednoznačne — " \
            "vyber materiál ručne (Materiály skrinky). Kandidáti: #{list}."
        end

        # D-45: JEDEN vstupny bod materialovych preflightov pred rebuildom.
        # Poradie (audit F7): TELO PRVE (picker chrbta kontroluje vysledny material
        # tela), potom chrbat; nakoniec JEDEN remap rucnych ABS overridov na nove
        # efektivne materialy — vsetko pred JEDINYM rebuildom (1 undo krok).
        # Vrati nil / { error: } / { note: }.
        # old_eff: volitelny snapshot efektivnych materialov PRED zmenou — sablonovy
        # flow ho dodava z CIELOVEJ skrinky (merged params uz nesu novy material,
        # takze default by remapu ukazal "ziadnu zmenu" — GH P1).
        def material_preflight(params, model, old_eff: nil)
          old_eff ||= CabinetBuilder.effective_materials(model, params)
          note = ''
          # POSTUPNE, nie naraz: pri odmietnutom tele sa chrbat uz neriesi (jeho
          # picker cita material tela — musi vidiet finalny stav, nie polovicny).
          body = body_preflight(params, model)
          return body if body && body[:error]
          note += body[:note].to_s if body
          back = back_preflight(params, model)
          return back if back && back[:error]
          note += back[:note].to_s if back
          new_eff = CabinetBuilder.effective_materials(model, params)
          # ziadna zmena materialu = ziadny remap (auto-apply bezi na kazdu zmenu
          # pola — plan by sa staval zbytocne)
          note += remap_note(CabinetBuilder.remap_part_edge_overrides!(params, old_eff, new_eff)) if old_eff != new_eff
          note.empty? ? nil : { note: note }
        end

        def str_or_nil(v)
          s = v.to_s.strip
          s.empty? ? nil : s
        end

        # D-45 (audit F10): mm s desatinnou CIARKOU do UI hlasok; cele cisla bez
        # desatin ("18 mm", "18,6 mm"). Vzdy String — nikdy Float do interpolacie.
        # Implementacia je JEDNA (Materials.fmt_mm) — tu len meno, ktore pozna panel.
        def fmt_mm(v)
          Materials.fmt_mm(v)
        end

        # D-45 (audit B3): vklad sa prisposobi materialu tela. Efektivny material
        # = sablona/draft karty > projektova predvolba > fallback.
        #   hrubka NIE JE zamknuta -> prevezme sa katalogova hrubka materialu
        #   hrubka JE zamknuta a nesedi:
        #     material EXPLICITNY zo sablony -> ODMIETNUTIE (D-39 kontrakt: konflikt
        #       so sablonou sa NIKDY ticho neupravuje — ani material, ani zamok)
        #     material len DEDENY z predvolby -> rieši ho body_preflight (auto-pick
        #       materialu k zamknutej hrubke, inak odmietnutie)
        # Vrati nil / { error: } / { note: }.
        def insert_thickness_preflight(params, model)
          return nil unless defined?(Materials)
          explicit = str_or_nil(params['material_id'])
          sheet = Materials.sheet(CabinetBuilder.effective_materials(model, params)['body'])
          return nil if sheet.nil? # legacy material mimo katalogu — stary rezim
          have = sheet['thickness'].to_f
          return nil if CabinetBuilder.thickness_eq?(params['thickness'], have)

          unless insert_locks.key?('thickness')
            unless CabinetBuilder.thickness_in_range?(have)
              return { error: "Materiál #{mat_name(sheet)} má #{fmt_mm(have)} mm — mimo rozsahu hrúbky korpusu " \
                              "(#{fmt_mm(CabinetBuilder::THICKNESS_RANGE[0])}–#{fmt_mm(CabinetBuilder::THICKNESS_RANGE[1])} mm). " \
                              'Vyber iný materiál korpusu.' }
            end
            params['thickness'] = have
            return { note: " · hrúbka #{fmt_mm(have)} mm prevzatá z materiálu #{mat_name(sheet)}" }
          end
          return nil unless explicit # dedeny default rieši body_preflight

          { error: "Zamknutá hrúbka #{fmt_mm(params['thickness'])} mm nesedí s materiálom šablóny " \
                   "#{mat_name(sheet)} (#{fmt_mm(have)} mm) — odomkni hrúbku alebo zmeň materiál. Nič sa neupravilo." }
        end

        def handle_insert(payload)
          model = Sketchup.active_model
          params = parse(payload)
          tf = insert_thickness_preflight(params, model) # D-45
          return set_status("#{tf[:error]}#{insert_locks_hint}", true) if tf && tf[:error]
          pf = material_preflight(params, model)
          return set_status("#{pf[:error]}#{insert_locks_hint}", true) if pf && pf[:error]
          pf = { note: "#{tf ? tf[:note] : ''}#{pf ? pf[:note] : ''}" }
          begin
            inst = CabinetBuilder.build(model, params)
          rescue StandardError => e
            # F8: konflikt sablona x zamok NIC ticho neupravuje — vklad odmietnu
            # existujuce guardy stavby (Fronts.validate_layout!, hrubkova kontrola
            # materialu, interior validacie) a status vymenuje aktivne zamky.
            Engine.log_error(e, 'Panel.handle_insert')
            return set_status("Chyba: #{e.message}#{insert_locks_hint}", true)
          end
          select_only(model, inst)
          cid = Store.get(inst, 'cabinet_id')
          status_with_warnings(inst, "Vlozeny #{cid} — #{part_count(inst)} dielcov.#{pf ? pf[:note] : ''}")
          push_selected(model)
        end

        # B3 „Vlozit kopiu": PRESNA serverova kopia — config sa cita z MODELU
        # (Store.config -> config_to_params), nie z DOM formulara. Kopia nesie
        # materialy, part_overrides, hardware_overrides, cela, zony aj nazov;
        # build jej prideli nove CAB id. Zamky vkladacej karty sa VEDOME
        # neaplikuju (kopia = verny duplikat oznacenej skrinky).
        def handle_insert_copy(payload)
          model = Sketchup.active_model
          cid = parse(payload)['cabinet_id'].to_s
          cab = cid.empty? ? find_cabinet(model) : find_cabinet_by_id(model, cid)
          return set_status('Skrinka na kopírovanie sa nenašla.', true) if cab.nil?

          params = CabinetBuilder.config_to_params(Store.config(cab) || {})
          inst = CabinetBuilder.build(model, params)
          select_only(model, inst)
          status_with_warnings(inst, "Vložená kópia #{Store.get(cab, 'cabinet_id')} → " \
                                     "#{Store.get(inst, 'cabinet_id')} — #{part_count(inst)} dielcov.")
          push_selected(model)
        end

        # Konstrukcne/rozmerove zmeny na oznaceny korpus. Zachova strom zon + cela.
        def handle_apply(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus v modeli.', true) if cab.nil?

          data = parse(payload)
          params = existing_params(cab)
          PARAM_KEYS.each do |k|
            params[k] = data[k] if data.key?(k)
          end
          pf = material_preflight(params, model) # D-45: telo + chrbat + ABS remap
          if pf && pf[:error]
            set_status(pf[:error], true)
            push_selected(model) # UI resync — select hrubky sa vrati na ulozeny stav
            return
          end
          CabinetBuilder.rebuild(model, cab, params)
          finish_cab(model, cab, "Aktualizovany #{Store.get(cab, 'cabinet_id')} — #{part_count(cab)} dielcov.#{pf ? pf[:note] : ''}")
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
        # V0.4.7e (Codex expr audit, blocker): payload nesie snapshot cabinet_id z casu
        # naplanovania debounce — oneskoreny zapis po prekliknuti na INY korpus sa ticho
        # zahodi namiesto zasiahnutia nespravneho objektu (rovnaky guard ako doska).
        def handle_apply_all(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return if cab.nil? # auto-apply bez vyberu = ticho (ziadny modal)

          data = parse(payload)
          echo = data['cabinet_id'].to_s
          if !echo.empty? && echo != Store.get(cab, 'cabinet_id').to_s
            Engine.log("apply_all zahodeny — echo #{echo} nesedi s vyberom #{Store.get(cab, 'cabinet_id')}")
            return
          end
          params = existing_params(cab)
          PARAM_KEYS.each do |k|
            params[k] = data[k] if data.key?(k)
          end
          params['fronts'] = data['fronts'] if data.key?('fronts')
          pf = material_preflight(params, model) # D-45: telo + chrbat + ABS remap
          if pf && pf[:error]
            set_status(pf[:error], true)
            push_selected(model) # UI resync (auto-apply nesmie nechat select 18 nad modelom 3)
            return
          end
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params)
            reselect(model, cab)
          end
          status_with_warnings(cab, "Prestavané — #{Store.get(cab, 'cabinet_id')} (#{part_count(cab)} dielcov).#{pf ? pf[:note] : ''}")
          push_selected(model)
        end

      end
    end
  end
end
