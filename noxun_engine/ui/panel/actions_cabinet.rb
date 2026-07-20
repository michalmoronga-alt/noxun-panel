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
          " · aktívne zámky 🔒: #{list}"
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
          defaults = Materials.project_defaults(model)
          back_id = str_or_nil(params['back_material_id']) || defaults['default_back_material_id']
          sheet = back_id && Materials.sheet(back_id)
          return nil if sheet.nil? # legacy material mimo katalogu — stary rezim
          return nil if (sheet['thickness'].to_f - want).abs <= 0.01

          body_id = str_or_nil(params['material_id']) || defaults['default_material_id']
          body_sheet = body_id && Materials.sheet(body_id)
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
          params['back_material_id'] = pick['material_id']
          { note: " · chrbát: #{pick['decor']} #{pick['type']} #{fmt_mm(want)} mm (auto)" }
        end

        def str_or_nil(v)
          s = v.to_s.strip
          s.empty? ? nil : s
        end

        def fmt_mm(v)
          (v % 1).zero? ? v.to_i : v.round(1)
        end

        def handle_insert(payload)
          model = Sketchup.active_model
          params = parse(payload)
          pf = back_preflight(params, model)
          return set_status("#{pf[:error]}#{insert_locks_hint}", true) if pf && pf[:error]
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
          pf = back_preflight(params, model)
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
          pf = back_preflight(params, model)
          if pf && pf[:error]
            set_status(pf[:error], true)
            push_selected(model) # UI resync (auto-apply nesmie nechat select 18 nad modelom 3)
            return
          end
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params)
            reselect(model, cab)
          end
          status_with_warnings(cab, "Prestavané ✓ — #{Store.get(cab, 'cabinet_id')} (#{part_count(cab)} dielcov).#{pf ? pf[:note] : ''}")
          push_selected(model)
        end

      end
    end
  end
end
