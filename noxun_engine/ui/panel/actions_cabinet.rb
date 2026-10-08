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
      # S1-E: polia SLOTU su bezne konstrukcne polia panela (menia sa v
      # Zakladnych a idu tou istou apply cestou) — preto patria do whitelistu.
      # ROH-A1: + polia rohovej (server ich prijme, ked pridu); `handle_apply`
      # kopiruje len PRITOMNE kluce. ROH-B1: JS posiela dverovu cast a CR
      # (`CONSTRUCTION_FIELDS`) LEN pri rohovej — pri inom type ani kluc
      # (krizovy audit C6). STRANU apply nemeni nikdy (`corner_change_refusal`):
      # meni ju VYHRADNE prepinac strany (`handle_corner_side`).
      PARAM_KEYS = %w[type width height depth thickness floor_height bottom_mode top_mode back_mode
                      back_thickness plinth_mode plinth_recess rail_depth rails_orientation
                      rails_top_offset back_setback top_front_setback back_rail_height name
                      dw_class dw_body_height dw_front_bottom
                      corner_side corner_door_w corner_cr1 corner_cr2].freeze

      # S1-E: SK nazov typu skrinky v 1. pade (hlasky Studia aj panela). Jedna
      # tabulka — tri opisane ternary by sa casom rozisli a slot by v jednej
      # hlaske ostal „dolna". H12b: ODVODENA z registra (`word`, poradie `IDS`);
      # novy typ ju dostane s riadkom registra.
      TEMPLATE_TYPE_WORDS = CabinetTypes::IDS.to_h { |id| [id, CabinetTypes.get(id)[:word]] }.freeze

      # ROH-A1: vety ochran rohovej. Typ sa nemeni ziadnou cestou; STRANU meni
      # od ROH-B1 len prepinac v riadku rohovej (apply, sablona na existujucu
      # rohovu a hromadny zapis ju dalej odmietaju touto vetou).
      CORNER_TYPE_MSG = 'Typ rohovej skrinky sa nedá zmeniť.'
      CORNER_SIDE_MSG = 'Stranu dverí zmeň prepínačom v riadku rohovej.'
      # ROH-B1: nazov operacie prepinaca strany (jeden krok Spat) a vety akcie.
      CORNER_SIDE_OP = 'NOXUN: Strana dverí rohovej'
      CORNER_SIDE_WORDS = { 'left' => 'vľavo', 'right' => 'vpravo' }.freeze
      CORNER_SIDE_BUSY_MSG = 'Model ešte dokončuje predchádzajúcu zmenu — strana dverí sa nezmenila, skús to znova.'

      # D-39: polia vkladacej karty, ktore mozu niest zamok (JS zrkadlo: NXInsert.LOCK_FIELDS).
      INSERT_LOCK_FIELDS = %w[width height depth thickness floor_height].freeze
      INSERT_LOCK_LABELS = { 'width' => 'šírka', 'height' => 'výška', 'depth' => 'hĺbka',
                             'thickness' => 'hrúbka', 'floor_height' => 'výška sokla' }.freeze

      class << self
        # D-120: cisty vypocet nad aktualnym formularom; ZIADNY builder,
        # snapshot, inicializacia katalogov ani Undo. Identita sa iba vracia.
        # ROH-A1 (audit A1 NOTE 5): `stored` = ULOZENY config OZNACENEJ skrinky
        # (nil pri vkladani). Otvor sa pocita pre KAZDY typ cez
        # `Construction.front_opening`; pri rohovej so stranou a dverovou
        # castou z ulozeneho configu (server je autorita, JS ich neposiela)
        # a so ZIVOU sirkou z formulara — pri dverach vpravo posuva `x0 = W − D`.
        def front_preflight_result(data, stored = nil)
          out = data.slice('model_guid', 'cabinet_id', 'insert_session', 'revision')
          # S1-E (Astra FIX E8): preflight sa pyta na TEN ISTY virtualny otvor,
          # z ktoreho stavia `Construction.build_plan`. Bez toho by slot
          # umyvacky overoval celo proti VYSKE LINKY a legitimny presah cela
          # nad linku by zahlasil ako chybu, ktora chybou nie je.
          # H12b: „slot" = typ BEZ KORPUSU (`builder`), rozsahy = vlastne
          # `limits` typu z registra (inak korpusove `CabinetBuilder::MIN` –
          # 3000). SIRKA 50: spodne hranice sa uz NEOPISUJU — do 7.10.2026 tu
          # stalo 200 pre sirku AJ vysku, takze preflight odmietal korpus
          # na dorovnanie (vyska 80-199, S1-E0) aj uzku skrinku.
          slot = !CabinetTypes.carcass?(data['type'])
          limits = CabinetTypes.prop(data['type'], :limits)
          dims = %w[width height floor_height].map do |key|
            v = data[key]
            unless v.is_a?(Numeric) && v.to_f.finite?
              raise "Rozmer #{key} musí byť konečné číslo."
            end
            v.to_f
          end
          dims[2] = 0.0 if slot # slot sokel v zmysle korpusu NEMA
          wr = limits ? limits[:width] : [CabinetBuilder::MIN[:width], 3000.0]
          hr = limits ? limits[:height] : [CabinetBuilder::MIN[:height], 3000.0]
          unless (wr[0]..wr[1]).cover?(dims[0]) && (hr[0]..hr[1]).cover?(dims[1]) &&
                 (0.0..500.0).cover?(dims[2])
            raise 'Rozmery skrinky sú mimo povoleného rozsahu.'
          end
          corner = corner_preflight_src(data, stored)
          opening = if slot
                      slot_preflight_opening(data, dims[0], dims[1])
                    else
                      Construction.front_opening(preflight_opening_cfg(data, corner, dims))
                    end
          # ROH-A2: otvor ide aj do ODPOVEDE (kazdy typ) — nahlad rohovej z neho
          # kresli dvere v dverovej casti. Zapisuje sa do `out` HNED, takze ho
          # nesie aj odmietnutie nizsie (napr. medzera pri rohu mimo rozsahu):
          # nahlad sa nesmie vratit na dvere cez celu sirku len preto, ze celo
          # neprislo cez kontrolu.
          out['opening'] = opening_json(opening)
          cfg = data['fronts']
          raise 'Neplatný návrh čiel.' unless cfg.is_a?(Hash) && cfg['items'].is_a?(Array)
          # D-139: riadok slotu sa pred preflightom KANONIZUJE tym istym
          # `slot_fronts!` ako pri stavbe — vyska cela je odvodena a stara
          # hodnota z formulara (echo este neprislo) nesmie dat falosne
          # „nezmestí sa". Validacia rozsahu ide tou istou `dw_front_eval`.
          cfg = slot_preflight_fronts(data, cfg, dims[1]) if slot
          %w[gap gap_top gap_bottom gap_left gap_right].each do |key|
            v = cfg[key]
            raise "Neplatná medzera čiel: #{key}." unless v.is_a?(Numeric) && v.to_f.finite?
          end
          cfg['items'].each do |it|
            raise 'Neplatný riadok čela.' unless it.is_a?(Hash)
            next unless it['mode'] == 'fixed'
            v = it['height']
            raise 'Pevná výška čela musí byť číslo.' unless v.is_a?(Numeric) && v.to_f.finite?
          end
          # ROH-A1: medzera pri rohu 1–20 mm — ta ista veta ako stavba.
          raise Construction::CORNER_GAP_MSG if corner && !corner_gap_ok?(cfg, corner['corner_side'])

          result = Fronts.preflight(cfg, *dims, opening: opening)
          out.merge(result).merge('slots' => front_slots_payload(result['items']))
        rescue RuntimeError => e
          out.merge('valid' => false, 'items' => [], 'slots' => {},
                    'errors' => [{ 'message' => e.message }])
        end

        # ROH-A2: otvor `{x0, w, z0, h}` (mm od laveho boku a od podlahy) ako
        # JSON pre panel. Jedina serializacia — preflight aj payload skrinky.
        def opening_json(opening)
          return nil unless opening.is_a?(Hash)

          %i[x0 w z0 h].to_h { |k| [k.to_s, opening[k].to_f.round(2)] }
        end

        # Zdroj poli rohovej pre preflight, alebo nil (nie je rohova). Oznacena
        # skrinka = jej ULOZENY config; vkladanie = payload (A2 posiela stranu
        # a dverovu cast z predvolieb alebo zo sablony — v DOM nie su).
        # H12b: „rohova" = typ s rohovou zostavou (`CabinetTypes.corner?`).
        def corner_preflight_src(data, stored)
          if stored.is_a?(Hash)
            return CabinetTypes.corner?(stored['type']) ? stored : nil
          end

          CabinetTypes.corner?(data['type']) ? data : nil
        end

        # cfg pre `Construction.front_opening` z rozmerov preflightu (dims =
        # [sirka, vyska, sokel] uz prekontrolovane).
        # ROH-B1: STRANA ide vzdy zo zdroja (`corner` — ulozeny config
        # oznacenej, payload vkladania); DVEROVA CAST je ZIVA z formulara,
        # ked je to konecne cislo v rozsahu (`CORNER_RANGES`) — pole mimo
        # rozsahu je v paneli cervene a otvor drzi posledny platny zdroj.
        def preflight_opening_cfg(data, corner, dims)
          cfg = { type: data['type'].to_s, width: dims[0], height: dims[1], floor_height: dims[2] }
          return cfg unless corner

          cfg.merge(type: corner['type'].to_s, corner_side: corner['corner_side'],
                    corner_door_w: preflight_door_w(data, corner))
        end

        def preflight_door_w(data, corner)
          preflight_corner_mm(data, corner, :corner_door_w)
        end

        # ROH-B2: to iste pravidlo pre KAZDE pole rohovej (dverova cast, CR 1,
        # CR 2) — zive pole v rozsahu, inak ZDROJ: ulozena hodnota oznacenej
        # skrinky, pri vkladani (zdrojom je sam payload) hodnota OREZANA do
        # rozsahu tym istym `norm_corner_mm` ako stavba (predrecenzia P3-1: surova
        # 900 by otvor posunula inam nez kresbu zostavy, ktoru oreze `normalize`).
        # Otvor dveri aj kresba zostavy tak stoja VZDY na tom istom cisle.
        def preflight_corner_mm(data, corner, key)
          v = data[key.to_s]
          range = CabinetBuilder::CORNER_RANGES[key]
          return v.to_f if v.is_a?(Numeric) && v.to_f.finite? && v.to_f >= range[0] && v.to_f <= range[1]

          CabinetBuilder.norm_corner_mm(corner[key.to_s], CabinetBuilder::CORNER_DEFAULTS[key], range)
        end

        # ROH-B2: ZIVE polia navrhu, ktore menia kresbu zostavy (vyska vnutra pri
        # strope z vystuh) — ostatne konstrukcne polia celny pohlad nemenia.
        CORNER_PREVIEW_LIVE_KEYS = %w[top_mode rail_depth rails_orientation rails_top_offset].freeze

        # ROH-B2: vstup kresby zostavy pre AKTUALNU reviziu preflightu (cista).
        # Oznacena rohova = ULOZENY config (strana, materialy, rucne overridy)
        # + zive rozmery a polia; vkladanie = payload karty. Hrubka korpusu je
        # ta ista ucinna, z ktorej panel pocita minimum sirky (`ctx['t']`).
        def corner_preview_params(data, stored, corner, ctx)
          base = stored.is_a?(Hash) ? CabinetBuilder.config_to_params(stored) : {}
          p = base.merge('type' => corner['type'].to_s, 'width' => data['width'],
                         'height' => data['height'], 'floor_height' => data['floor_height'],
                         'thickness' => ctx['t'], 'corner_side' => corner['corner_side'],
                         'fronts' => data['fronts'])
          CabinetBuilder::CORNER_RANGES.each_key { |k| p[k.to_s] = preflight_corner_mm(data, corner, k) }
          CORNER_PREVIEW_LIVE_KEYS.each do |k|
            v = data[k]
            p[k] = v unless v.nil? || v.to_s.strip.empty?
          end
          unless stored.is_a?(Hash)
            %w[material_id front_material_id].each do |k|
              p[k] = data[k] if data[k].is_a?(String) && !data[k].strip.empty?
            end
          end
          p
        end

        # ROH-B2: kresba zostavy do odpovede preflightu, alebo nil (nie je rohova).
        def corner_preflight_preview(data, stored, model, ctx)
          corner = corner_preflight_src(data, stored)
          return nil unless corner && ctx

          params = corner_preview_params(data, stored, corner, ctx)
          corner_preview_json(params, CabinetBuilder.aux_part_thicknesses(params, model))
        rescue StandardError => e
          Engine.log_error(e, 'Panel.corner_preflight_preview')
          nil
        end

        # Medzera PRI ROHU v navrhu ciel v rozsahu 1–20 mm? Nevalidny tvar
        # riesi dalej `Fronts.preflight` vlastnou vetou.
        def corner_gap_ok?(fronts, side)
          key = side.to_s == 'right' ? 'gap_left' : 'gap_right'
          v = fronts.is_a?(Hash) ? fronts[key] : nil
          return true unless v.is_a?(Numeric)

          lo, hi = Construction::CORNER_GAP_RANGE
          v.to_f >= lo - 0.005 && v.to_f <= hi + 0.005
        end

        # S1-E: virtualny otvor slotu z PAYLOADU preflightu. Autoritou tvaru je
        # `Construction.front_opening` — tu sa len poskladá cfg, ktory ocakava
        # (preflight bezi BEZ modelu, nad rozpisanym formularom). D-139: otvor
        # ide od soklu po vysku linky; vyska cela sa odvodzuje.
        def slot_preflight_opening(data, width, height)
          z0 = data['dw_front_bottom']
          raise 'Sokel slotu musí byť konečné číslo.' unless z0.is_a?(Numeric) && z0.to_f.finite?

          r = CabinetBuilder::DW_RANGES[:dw_front_bottom]
          raise 'Sokel slotu je mimo povoleného rozsahu.' unless (r[0]..r[1]).cover?(z0.to_f)

          # H12b: typ je ten z payloadu (volajuci ho uz rozpoznal ako slot).
          Construction.front_opening({ type: data['type'].to_s, width: width, height: height,
                                       dw_front_bottom: z0.to_f })
        end

        # D-139: kanonicky riadok slotu pre preflight — ta ista `dw_front_eval`
        # (vzorec + rozsah + veta) a ten isty `slot_fronts!` ako pri stavbe.
        def slot_preflight_fronts(data, fronts, height)
          norm = Fronts.normalize_config(fronts)
          ev = CabinetBuilder.dw_front_eval(height, data['dw_front_bottom'].to_f, norm['gap_top'])
          raise ev[:error] if ev[:error]

          CabinetBuilder.slot_fronts!(norm, { dw_front_height: ev[:value] })
        end

        def handle_front_preflight(payload)
          data = parse(payload)
          model = Sketchup.active_model
          return if DocKey.foreign?(data['model_guid'], model)
          return unless data['revision'].is_a?(Integer) && data['revision'].positive?
          cid = data['cabinet_id']
          stored = nil
          if cid.is_a?(String) && !cid.empty?
            cab = find_cabinet(model)
            return unless cab && Store.get(cab, 'cabinet_id').to_s == cid
            stored = Store.config(cab) # ROH-A1: polia rohovej su autoritou servera
          else
            return unless data['insert_session'].is_a?(Integer) && data['insert_session'].positive?
          end
          res = front_preflight_result(data, stored)
          # ROH-B1 (audit B1 FIX 4): UCINNE hrubky pre minimum sirky rohovej.
          ctx = corner_preflight_ctx(data, stored, model)
          res['corner_ctx'] = ctx if ctx
          # ROH-B2: kresba rohovej zostavy pre ZIVE polia tejto revizie — len
          # ked preflight rozmery prijal (inak ani otvor nie je znamy).
          cp = res['opening'] ? corner_preflight_preview(data, stored, model, ctx) : nil
          res['corner_preview'] = cp if cp
          js("NX.frontPreflight(#{res.to_json})")
        end

        # ROH-B1 (audit B1 FIX 4): `{ 'th2', 't' }` = UCINNA hrubka CR 2 a korpusu,
        # z ktorych panel pocita najmensiu sirku rohovej (`D + c1 + th2 + 2t`),
        # alebo nil (nie je rohova). Citacie, bez zapisu a bez Undo.
        #   * OZNACENA rohova: th2 z ULOZENEHO configu (override CR 2 -> celovy
        #     kanal -> 18; zmena materialu pride novym pushom a novym dotazom),
        #     t zo ZIVEHO formulara (prazdne = ulozene).
        #   * VKLADANIE: materialy navrhu (sablona, inak projekt) a hrubka tak,
        #     ako ju upravi SAM VKLAD (`insert_thickness_preflight` — prevzatie
        #     z materialu tela, zamok hrubky); th2 z celoveho materialu navrhu.
        def corner_preflight_ctx(data, stored, model)
          return nil unless corner_preflight_src(data, stored)

          live = data['thickness']
          live = nil unless live.is_a?(Numeric) && live.to_f.finite? && live.to_f.positive?
          if stored.is_a?(Hash)
            params = CabinetBuilder.config_to_params(stored)
            t = live ? live.to_f : params['thickness'].to_f
          else
            params = { 'type' => data['type'].to_s, 'thickness' => live } # rohova (guard vyssie)
            %w[material_id front_material_id].each do |k|
              v = data[k]
              params[k] = v if v.is_a?(String) && !v.strip.empty?
            end
            insert_thickness_preflight(params, model)
            t = params['thickness'].to_f
          end
          t = CabinetBuilder::LOWER_DEFAULTS[:thickness].to_f unless t.finite? && t.positive?
          { 'th2' => corner_th2_payload(model, params), 't' => t.round(2) }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.corner_preflight_ctx')
          nil
        end

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
        # 'none' sa material/hrubka nekontroluje vobec (D-31); KON-B · K2: rovnako
        # pri chrbte z list (listy su z korpusu, material chrbta sa nepouzije).
        def back_preflight(params, model)
          return nil unless Construction.back_material_used?(params['back_mode'])
          want = params['back_thickness'].to_f
          return nil unless want.positive?
          return nil unless defined?(Materials)
          # D-45: efektivne materialy citame PO body_preflighte (audit F7) — picker
          # chrbta tak vidi uz dobrany material tela, nie ten povodny.
          eff = CabinetBuilder.effective_materials(model, params)
          sheet = Materials.sheet(eff['back'])
          return nil if sheet.nil? # legacy material mimo katalogu — stary rezim
          # V0.6 M-B1: UNI chrbat prijme lubovolnu hrubku — ziadna vymena.
          return nil if Materials.uni?(sheet)
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

          # V0.6 M-B1: UNI telo prijme lubovolnu hrubku (6-50) — material sa
          # NEvymiena, hrubku drzi config (real dielce s override strazi
          # blocked check vyssie).
          return nil if Materials.uni?(sheet)

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
        # PR #381 (Codex kolo 1, P2): SLOT UMYVACKY nema TELO ani CHRBAT, takze
        # obe brany sa ho netykaju — bezali by nad ZDEDENYM projektovym
        # materialom korpusu a vlozenie slotu by odmietli chybou o hrubke
        # korpusu, ktoru pouzivatel v SKRYTOM poli nevie opravit. Materialovy
        # remap ABS overridov ostava: slot MA celo a jeho material sa meni.
        # Hrubku cela validuje dalej ta ista brana ako pri kazdom inom cele
        # (`CabinetBuilder.validate_material_thickness!` v `resolve_part`).
        # H12b: typ BEZ KORPUSU (`builder`) — telo ani chrbat nema.
        def slot_params?(params)
          params.is_a?(Hash) && !CabinetTypes.carcass?(params['type'])
        end

        def material_preflight(params, model, old_eff: nil)
          old_eff ||= CabinetBuilder.effective_materials(model, params)
          note = ''
          slot = slot_params?(params)
          # POSTUPNE, nie naraz: pri odmietnutom tele sa chrbat uz neriesi (jeho
          # picker cita material tela — musi vidiet finalny stav, nie polovicny).
          body = slot ? nil : body_preflight(params, model)
          return body if body && body[:error]
          note += body[:note].to_s if body
          back = slot ? nil : back_preflight(params, model)
          return back if back && back[:error]
          note += back[:note].to_s if back
          new_eff = CabinetBuilder.effective_materials(model, params)
          # ziadna zmena materialu = ziadny remap (auto-apply bezi na kazdu zmenu
          # pola — plan by sa staval zbytocne)
          note += remap_note(CabinetBuilder.remap_part_edge_overrides!(params, old_eff, new_eff)) if old_eff != new_eff
          note.empty? ? nil : { note: note }
        end

        # KOV-H1 (audit #15 BLOCKER 4): STRIKTNA kontrola ad-hoc poloziek na
        # ZAPISOVEJ ceste z panela. Vlastnik musi existovat v AKTUALNOM plane
        # (plan sa stavia z params UZ so zmenami, ktore prave prisli — inak by
        # sa nedalo v jednom kroku zmensit skrinku a pripnut polozku na dielec,
        # ktory po zmene vznikne) a katalogovy kod musi byt v katalogu.
        # Odmietnutie je CELE (`ManualRejected`) — ZIADNY tichy drop polozky.
        # Nepritomny kluc = panel o ad-hoc polozkach nic nehovori: `params` si
        # necha to, co je v ulozenom configu.
        # -> nil (v poriadku) | { error: SK hlaska }
        def manual_preflight(params, data)
          return nil unless data.key?('hardware_manual')

          raw = data['hardware_manual']
          # Review #283 P2-A: panel posiela CELY zoznam (echo, nie diff), takze
          # prisne sa smu kontrolovat LEN nove a realne zmenene zaznamy. Inak by
          # po zmiznuti kodu z katalogu neprešla ziadna dalsia editacia skrinky
          # a zmazanie cela-vlastnika by sa odmietlo namiesto toho, aby polozka
          # prezila ako `owner_missing`. Porovnava sa proti ULOZENEMU zoznamu,
          # ktory je v `params` este PRED prepisom.
          strict_ids = CabinetBuilder.manual_strict_subset(params['hardware_manual'], raw)
          params['hardware_manual'] = raw
          keys = CabinetBuilder.plan_parts_by_key(params).keys
          CabinetBuilder.norm_hardware_manual(raw, strict_owners: true, strict_ids: strict_ids,
                                                   plan_keys: keys)
          nil
        rescue CabinetBuilder::ManualRejected => e
          { error: "Kovanie sa neuložilo — #{e.message}." }
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
          # PR #381 (P2): slot hrubku KORPUSU nema — `thickness` je mu len
          # placeholder cela, ktory `materialized_part` aj tak prepise
          # katalogovou hrubkou celoveho materialu. Zamok hrubky z predoslej
          # skrinky by inak vlozenie slotu odmietol.
          return nil if slot_params?(params)
          explicit = str_or_nil(params['material_id'])
          sheet = Materials.sheet(CabinetBuilder.effective_materials(model, params)['body'])
          return nil if sheet.nil? # legacy material mimo katalogu — stary rezim
          # V0.6 M-B1: UNI telo — hrubka vkladu/sablony plati bez adopcie.
          return nil if Materials.uni?(sheet)
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

        # H2 (D-76): vklad zo sablony nesie KOVANIE — mapovanie setov + zmrazene
        # definicie. JS je len prenasac (autorita je server): mapovanie sa TU
        # normalizuje s allow_owner: false — composite kluce „typ@dielec" patria
        # ku konkretnym dielcom zdrojovej skrinky a do noveho korpusu nepatria.
        # GH #133 P2: kovanie sablony sa cita BEZSTRATOVO alebo vobec — sablona
        # z novsej verzie (neznamy typ kovania) ci rucne upravena sa NEVKLADA
        # ocesana, vklad sa odmietne.
        # -> [:ok, { 'mapping', 'defs' } | nil] | [:lossy, [zahodene kluce]]
        # -> [:ok, hw|nil] | [:lossy, [zahodene kluce mapovania]]
        #  | [:lossy_defs, [neprecitatelne definicie setov]]
        def take_insert_hardware!(params)
          defs = params.delete('hardware_set_defs')
          status, res = HardwareSets.read_template_mapping(params['hardware_sets'])
          return [:lossy, res] unless status == :ok

          # KOV-B1 (audit #17 BLOCKER 1): definicie setov zo sablony sa citaju
          # BEZSTRATOVO ALEBO VOBEC — presne ako mapovanie nad nimi. Doteraz
          # sli len cez tolerantny `normalize_sets`, takze sablona z novsej
          # verzie by sa do .skp zmrazila UZ OREZANA. Kontrola bezi TU, teda
          # PRED `prepare_insert` aj pred vznikom ghost session — odmietnutie
          # znamena, ze sa v modeli nestalo NIC.
          dstatus, dres = HardwareSets.assess_set_defs(defs)
          return [:lossy_defs, dres] unless dstatus == :ok

          if res.empty?
            params.delete('hardware_sets')
            return [:ok, nil]
          end
          params['hardware_sets'] = res
          [:ok, { 'mapping' => res, 'defs' => defs }]
        end

        # GHOST VKLADANIE (V1-04): „Vlozit" UZ NEVKLADA — pripravi ZMRAZENY plan
        # (R-03 `prepare_insert`) a zavesi ghost na kurzor; skrinka vznikne az
        # KLIKOM v modeli (`GhostTool` -> `commit_insert`).
        #
        # PORADIE JE SUCASTOU KONTRAKTU: doc guard -> sablonovy ref -> kovanie
        # zo sablony -> D-45/D-76 preflighty -> material -> `prepare_insert` ->
        # zrusenie pripadnej STAREJ session -> nova session + `push_tool`.
        # Preflighty bezia PRAVE RAZ a Tool ich NEOPAKUJE (Tool riesi polohu,
        # nie vyrobne pravidla). Snapshot je zmrazeny: zmeny vo vkladacej karte
        # sa do beziacej session NEPREMIETAJU — status to prizna.
        #
        # VEDOMY POSUN OPROTI STAVU PRED GHOSTOM: guardy STAVBY
        # (`Fronts.validate_layout!`, interior validacie) bezia az v commite,
        # takze konflikt „zamok x sablona" (F8) sa ohlasi pri KLIKU, nie pri
        # stlaceni „Vlozit" — hlaska je ta ista (`ghost_insert_failed`).
        # `Construction.build_plan` sa do `prepare_insert` zamerne nepresuva
        # (vedoma hranica R-03).
        # ROH-B2: `keep_point:` = prevesenie ghostu klavesou strany dveri
        # (`handle_ghost_corner_side`) — nova session prevezme polohu starej.
        def handle_insert(payload, keep_point: false)
          model = Sketchup.active_model
          params = parse(payload)
          # R-02: identita DOKUMENTU pred cimkolvek inym — vklad je najkritickejsia
          # zapisova cesta (nova geometria + nove ID v cudzej zakazke sa nedaju
          # „prehliadnut", pouzivatel ich najde az pri objednavke).
          return if foreign_document?(params, model, 'Skrinka sa nevložila')
          # UI-C1a: metadata sablony sa z payloadu vyberu HNED — do buildera
          # sa nikdy nedostanu; peciatka pouzitia ide az po uspesnom vlozeni.
          tpl_ref = take_template_ref!(params, 'cabinet')
          # S1-C (Astra C11): payload DEKLARUJE sablonu, ktora uz v kniznici
          # nie je (zmazana alebo premenovana z druhej instancie SketchUpu).
          # Odkedy zo ZAZNAMU pochadzaju `dw_*` aj `appliance_expects[]`, tichy
          # vklad „bez sablony" by postavil INU skrinku, nez si pouzivatel
          # vybral — a nikto by mu to nepovedal. VEDOMY vklad BEZ sablony
          # (payload ref nenesie) ide dalej ako doteraz.
          if tpl_ref && TemplateStore.find(*tpl_ref).nil?
            return set_status("Šablóna \"#{tpl_ref[1]}\" už v knižnici nie je — " \
                              'vyber ju znova. Nič sa nevložilo.', true)
          end
          # R-12 [B1]: guard nad CIELOVOU instanciou pred novsou SABLONOU
          # nechrani — pri vklade ziadny cielovy korpus este neexistuje.
          # Autorita je ULOZENY ZAZNAM sablony, nie payload z CEF (JS prenasa
          # len zname polia, takze marker by v nom uz nemusel byt).
          if (tpl_msg = newer_template_refusal(tpl_ref, 'vloženie by nastavenia stratilo'))
            return set_status("#{tpl_msg} Nič sa nevložilo.", true)
          end
          # S1-E (Astra FIX E7): AUTORITA je ULOZENY ZAZNAM sablony, nie CEF.
          # Klient prenasa len polia, ktore pozna jeho formular — `dw_*` aj
          # `appliance_expects[]` by z neho vypadli a zo slotovej sablony by
          # vznikol slot s generickymi rozmermi a bez ocakavania.
          apply_template_slot_fields!(params, tpl_ref)
          # ROH-A1 (R6): rohova sablona s porusenym invariantom ciel sa ODMIETNE
          # (nie ticho oreze v `normalize`). Autorita = ULOZENY ZAZNAM.
          if (tpl_msg = corner_template_refusal(tpl_ref))
            return set_status("#{tpl_msg} Nič sa nevložilo.", true)
          end
          hw_status, hw = take_insert_hardware!(params) # H2 (D-76)
          if hw_status == :lossy
            return set_status("Šablóna nesie kovanie, ktoré sa nedá prečítať (#{Array(hw).join(', ')}) — " \
                              'je z novšej verzie Noxun alebo ručne upravená. Nič sa nevložilo.', true)
          end
          # KOV-B1: definicie setov zo sablony (`hardware_set_defs`) maju vlastnu
          # hlasku — pouzivatel ma vediet, ci je problem vo VYBERE setu, alebo
          # v jeho DEFINICII.
          if hw_status == :lossy_defs
            return set_status("Šablóna nesie sety kovania, ktoré sa nedajú prečítať (#{Array(hw).join(', ')}) — " \
                              'je z novšej verzie Noxun alebo ručne upravená. Nič sa nevložilo.', true)
          end
          tf = insert_thickness_preflight(params, model) # D-45
          return set_status("#{tf[:error]}#{insert_locks_hint}", true) if tf && tf[:error]
          pf = material_preflight(params, model)
          return set_status("#{pf[:error]}#{insert_locks_hint}", true) if pf && pf[:error]
          # KOV-C2b (Codex #304 kolo 4 P1): material zasuviek proti systemom
          # v ZLOZENEJ konfiguracii ciel — este PRED ghostom. Bez neho by vklad
          # „uspel", skrinka by visela na kurzore a az po kliku by z nej boli
          # RED zasuvky bez dielcov. Odmietnutie je hlaska, nie tichy uspech.
          if (df = MaterialsDialog.drawer_material_issue(params, model))
            return set_status("#{df}#{insert_locks_hint}", true)
          end
          note = "#{tf ? tf[:note] : ''}#{pf ? pf[:note] : ''}"
          begin
            plan = CabinetBuilder.prepare_insert(model, params)
          rescue StandardError => e
            Engine.log_error(e, 'Panel.handle_insert')
            return set_status("Chyba: #{e.message}#{insert_locks_hint}", true)
          end
          # Stara session konci PRED vznikom novej (druhe „Vlozit" = novy
          # snapshot); `GhostTool.start` to robi ako prvy krok.
          s = GhostTool.start(model, plan, hardware: hw, template_ref: tpl_ref, note: note, keep_point: keep_point)
          return set_status('Vkladanie sa nepodarilo spustiť — skús to znova.', true) if s.nil?

          # Poznamku preflightov (D-45 prevzata hrubka, materialove noty)
          # vypisuje AZ `ghost_after_commit` — pri stlaceni „Vlozit" sa este
          # nic nestalo, takze hlasit „hrubka prevzata" by bolo predcasne
          # a po kliku by sa to zopakovalo druhy raz (review #268 P3-7).
          # ROH-B2 (O12): rohova ma navyse klavesu strany dveri a jej stav.
          if s.corner?
            return set_status("Rohová (#{GhostTool::CORNER_SIDE_LABELS[s.corner_side]}) visí na kurzore — klikni, " \
                              'kam ju položiť. D prepne stranu dverí, šípky ←/→ otáčajú, Alt prepína kotvu, Esc zruší.')
          end

          set_status('Skrinka visí na kurzore — klikni, kam ju položiť. ' \
                     'Šípky ←/→ otáčajú, Alt prepína kotvu, ↓ drží domácu výšku, ↑ pustí voľnú výšku, Esc zruší.')
        end

        # ROH-B2 (O12): PREVESENIE GHOSTU ROHOVEJ po klavese strany dveri. Karta
        # uz stranu prepla (`onCornerSide` — register + zrkadlo navrhu ciel)
        # a posiela TEN ISTY payload ako „Vložiť"; tu ide TOU ISTOU cestou
        # (`handle_insert` — vsetky preflighty, zmrazeny plan) s prevzatou
        # polohou. Ked sa novy ghost nezalozi, STARY sa zrusi — karta uz
        # ukazuje novu stranu a ghost so starou by po kliku vlozil inu skrinku,
        # nez akú karta ukazuje. Nic sa nezapisuje (0 krokov Spat).
        def handle_ghost_corner_side(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Strana dverí sa neprepla')

          old = GhostTool.session
          unless old && old.active? && old.corner? && old.plan.for_model?(model)
            return set_status('Rohová už nevisí na kurzore — stranu dverí zmeň prepínačom v riadku rohovej.', true)
          end

          handle_insert(payload, keep_point: true)
          now = GhostTool.session
          return if now && !now.equal?(old) && now.active?

          GhostTool.cancel_session('strana dverí sa neprepla', deferred: false)
          set_status('Strana dverí sa neprepla (skontroluj kartu) — vkladanie sa zrušilo, vlož rohovú znova.', true)
        end

        # S1-E (FIX E7): doplni do vkladacieho payloadu to, co vie LEN ULOZENY
        # ZAZNAM sablony — typ slotu, jeho `dw_*` polia a `appliance_expects[]`.
        # Payload z panela ma PREDNOST (pouzivatel mohol rozmery doladit vo
        # vkladacej karte); doplna sa VYHRADNE chybajuce.
        # `appliance_expects[]` sa preberá VZDY zo zaznamu — vo vkladacej karte
        # sa neda menit, takze klientska hodnota by bola len echo (alebo podvrh).
        def apply_template_slot_fields!(params, tpl_ref)
          return params if tpl_ref.nil?

          tpl = TemplateStore.find(*tpl_ref)
          cfg = tpl && tpl['config']
          return params unless cfg.is_a?(Hash)

          # H12b: typ BEZ KORPUSU si typ zo sablony berie vzdy (slot sa zo
          # sablony nevlozi ako korpus); polia slotu ako doteraz pri kazdom type.
          params['type'] = cfg['type'] unless CabinetTypes.carcass?(cfg['type'])
          CabinetBuilder::DW_KEYS.each do |k|
            key = k.to_s
            next unless cfg.key?(key)

            v = params[key]
            params[key] = cfg[key] if v.nil? || v.to_s.strip.empty?
          end
          # ROH-A1 (audit A1 FIX 3): TA ISTA cesta pre polia ROHOVEJ — formular
          # ich neposiela, takze bez tohto by sablona „vpravo / 600 / 120 / 90"
          # skoncila na predvolbach „vlavo / 450 / 80 / 80". Rozsahy a strana
          # sa zvaliduju v `normalize` (`norm_corner`) ako pri kazdom vstupe.
          if CabinetTypes.corner?(cfg['type'])
            params['type'] = cfg['type']
            CabinetBuilder::CORNER_KEYS.each do |k|
              key = k.to_s
              next unless cfg.key?(key)

              v = params[key]
              params[key] = cfg[key] if v.nil? || v.to_s.strip.empty?
            end
          end
          if cfg['appliance_expects'].is_a?(Array)
            params['appliance_expects'] = cfg['appliance_expects']
          else
            params.delete('appliance_expects')
          end
          # Vklad NIKDY nenesie vazbu na konkretny spotrebic — sablona ju ani
          # niest nemoze (`template_config_from` ju nezapisuje).
          CabinetBuilder.strip_appliance_refs!(params)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.apply_template_slot_fields!')
          params
        end

        # ROH-A1: veta, ked ULOZENY zaznam rohovej sablony porusuje invariant
        # ciel (jeden riadok dvierok, jedno kridlo, medzera pri rohu 1–20),
        # inak nil. Sablona bez kluca `fronts` (predvolene cela) je v poriadku.
        def corner_template_refusal(tpl_ref)
          return nil if tpl_ref.nil?

          tpl = TemplateStore.find(*tpl_ref)
          cfg = tpl && tpl['config']
          return nil unless cfg.is_a?(Hash) && CabinetTypes.corner?(cfg['type'])

          corner_template_fronts_error(cfg)
        end

        # Cista kontrola ciel ULOZENEHO rohoveho zaznamu (vklad aj pouzitie
        # sablony na skrinku) — ta ista pravda ako `corner_fronts_refusal`.
        def corner_template_fronts_error(cfg)
          return nil unless cfg.key?('fronts')

          fr = Fronts.normalize_config(cfg['fronts'])
          return "Šablóna rohovej: #{Construction::CORNER_FRONTS_MSG}" unless CabinetBuilder.corner_fronts_ok?(fr)
          return "Šablóna rohovej: #{Construction::CORNER_GAP_MSG}" unless corner_gap_ok?(fr, cfg['corner_side'])

          nil
        rescue StandardError => e
          Engine.log_error(e, 'Panel.corner_template_fronts_error')
          "Šablóna rohovej má poškodené čelá — #{e.message}"
        end

        # GHOST-FB4: rucne prestavenie LOCKNUTEJ vysky z Ghost pasika.
        # Do MODELU nezapisuje — meni stav BEZIACEJ session — ale guard
        # identity dokumentu ma rovnaky ako zapisove handlery (R-02): panel
        # patriaci inej zakazke nesmie hybat ghostom v tejto (cudzi = ignoruj
        # + status). Neplatna hodnota NIC nemeni: stara vyska drzi a pasik sa
        # prekresli spat na nu.
        def handle_ghost_lock_z(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Výška vkladanej skrinky sa nezmenila')

          s = GhostTool.session
          return GhostTool.push_state(nil) unless s && s.active?

          # GHOST-D1: zamok vysky je KABINETOVY ovladac. Kontroluje sa SUBJEKT
          # session, nie len „je nejaka aktivna" — HTML `disabled` ani skryty
          # pasik nie su ochrana (oneskoreny callback, iny klient).
          unless s.cabinet?
            GhostTool.push_state(s)
            return set_status('Zámok výšky platí len pre skrinku — doska sa prichytáva ' \
                              'v celom priestore (↑/↓ menia umiestnenie).', true)
          end

          v = GhostTool::Calc.lock_z_value(data['lock_z'])
          if v.nil?
            GhostTool.push_state(s)
            return set_status('Výška zámku musí byť číslo v mm od ' \
                              "#{GhostTool::LOCK_Z_MIN_MM.round} do #{GhostTool::LOCK_Z_MAX_MM.round} — " \
                              'ponechaná pôvodná hodnota.', true)
          end
          s.set_lock_z!(v)
          # Zmena plati OKAMZITE: ghost na kurzore aj klik, ktory pride po nej.
          GhostTool.invalidate_view(model)
          GhostTool.push_state(s)
          begin
            Sketchup.status_text = GhostTool.status_text(s)
          rescue StandardError
            nil
          end
          set_status("Zámok výšky #{GhostTool.fmt_mm(s.lock_plane_z)} mm — vkladaná skrinka sadne na túto výšku.")
        end

        # GHOST: sprievodny zapis kovania zo sablony (H2/D-76). Bezi VNUTRI
        # operacie vlozenia — vynimka zrusi CELU operaciu (ziadna skrinka
        # s nezmrazenym setom, rovnaky kontrakt ako pri aplikacii sablony).
        def ghost_freeze_hardware(model, hw)
          return '' unless hw

          freeze_template_hardware!(model, hw['mapping'], hw['defs'])
        end

        # GHOST: vklad zlyhal az v commite (guardy stavby). V modeli sa NIC
        # nezmenilo — hlaska je ta ista ako pred ghostom, vratane vymenovania
        # aktivnych zamkov vkladacej karty.
        # GHOST-D1: zoznam aktivnych zamkov VKLADACEJ KARTY je kabinetovy
        # (D-39 zamky rozmerov korpusu) — pri doske by len matiel.
        def ghost_insert_failed(err, session = nil)
          board = session.respond_to?(:board?) && session.board?
          set_status("Chyba: #{err.message}#{board ? '' : insert_locks_hint}", true)
        end

        # GHOST: po USPESNOM commite — vyber, status, refresh panela a peciatka
        # sablony. Bezi MIMO operacie vlozenia; zlyhanie ktorehokolvek kroku
        # nesmie zabranit zatvoreniu session (skrinka uz stoji).
        # Peciatka ide cez `stamp_once!` — dvojklik ju uz nezopakuje.
        # ZIADNY rucny `StudioModelWatch` notify: stale signalizaciu rieši
        # `onTransactionCommit` sam.
        def ghost_after_commit(model, inst, session)
          return unless inst
          # GHOST-D1: doska ma vlastny post-commit (iny status, ziadne dielce
          # ani zony) — dispatch podla SUBJEKTU session.
          return ghost_after_commit_board(model, inst, session) if session.respond_to?(:board?) && session.board?

          select_only(model, inst)
          cid = Store.get(inst, 'cabinet_id')
          status_with_warnings(inst, "Vlozeny #{cid} — #{part_count(inst)} dielcov." \
                                     "#{session.note}#{session.hardware_note}" \
                                     "#{zone_depth_note((Store.config(inst) || {})['zone_tree'])}")
          push_selected(model)
          session.stamp_once! { stamp_template_used(session.template_ref) } # UI-C1a: az PO vlozeni, mimo operacie
        end

        # B3 „Vlozit kopiu": PRESNA serverova kopia — config sa cita z MODELU
        # (Store.config -> config_to_params), nie z DOM formulara. Kopia nesie
        # materialy, part_overrides, hardware_overrides, cela, zony aj nazov;
        # build jej prideli nove CAB id. Zamky vkladacej karty sa VEDOME
        # neaplikuju (kopia = verny duplikat oznacenej skrinky).
        def handle_insert_copy(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Kópia sa nevložila') # R-02

          # GHOST (V1-04): iny sposob vkladania = koniec zivotneho cyklu
          # beziacej session. Kopia sa kladie SYNCHRONNE (`next_x`), takze
          # ghost visiaci na kurzore by uz nemal co dokoncit.
          GhostTool.cancel_session('vloženie kópie') if defined?(GhostTool)

          cid = data['cabinet_id'].to_s
          cab = cid.empty? ? find_cabinet(model) : find_cabinet_by_id(model, cid)
          return set_status('Skrinka na kopírovanie sa nenašla.', true) if cab.nil?

          src_cfg = Store.config(cab) || {}
          # R-12 [B2]: kopia NEJDE cez rebuild — `config_to_params` je uzavrety
          # whitelist a novy korpus by vznikol s TICHO orezanym configom (a este
          # by sa tvaril ako platny zaznam tejto verzie). Odvodeny objekt sa
          # z novsieho configu nevytvara vobec.
          if CabinetBuilder.newer_config?(src_cfg)
            return set_status(
              "#{CabinetBuilder.newer_config_message('Korpus', 'kópia by nastavenia stratila')} " \
              'Kópia sa nevložila.', true
            )
          end

          params = CabinetBuilder.config_to_params(src_cfg)
          # KOV-H1 (audit FIX 10): kopia je NOVA skrinka — jej ad-hoc polozky
          # kovania dostanu vlastnu identitu. Obsah (kod, nazov, cena, pocet,
          # vlastnik) sa NEMENI, meni sa LEN `id`.
          CabinetBuilder.rekey_hardware_manual(params)
          # S1-E (FIX E4): treti kopirovaci vstup — vazba na KONKRETNY
          # spotrebic zanika, ocakavanie ostava.
          CabinetBuilder.strip_appliance_refs!(params)
          inst = CabinetBuilder.build(model, params, appearance_source: cab)
          select_only(model, inst)
          status_with_warnings(inst, "Vložená kópia #{Store.get(cab, 'cabinet_id')} → " \
                                     "#{Store.get(inst, 'cabinet_id')} — #{part_count(inst)} dielcov.")
          push_selected(model)
        end

        # D-100: premenovanie skrinky z hlavicky panela (inline edit v idbare).
        # Nazov nema ziadny geometricky dosah, takze sa zapisuje PRIAMO do configu
        # (ziadna prestavba) — ale vzdy vo vlastnej operacii = 1 undo krok.
        #
        # Codex audit BLOCKER 1: `Store.write_config` meni atribut instancie a
        # CabinetEntityObserver by z toho spravil "zmenu korpusu" (po debounce
        # presun ghost zon vo VLASTNEJ transparentnej operacii) — zapis preto
        # bezi pod ScaleWatch guardom (CabinetBuilder.guarded).
        # BLOCKER 2: refresh panela s `dedup: false` — predvoleny push_selected
        # spusta dedup_copies, ktory by pri premenovani mohol prestavat CUDZIU
        # duplicitnu skrinku (geometria a undo mimo vybraneho objektu).
        # FIX 6: prazdne alebo nezhodne cabinet_id = ziadny zapis (prisnejsie ako
        # auto-apply — premenovanie je vedomy akt nad KONKRETNOU skrinkou).
        def handle_rename_cabinet(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Názov sa nezmenil') # R-02

          echo = data['cabinet_id'].to_s
          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus.', true) if cab.nil?

          cid = Store.get(cab, 'cabinet_id').to_s
          if echo.empty? || echo != cid
            Engine.log("rename_cabinet zahodeny — echo #{echo.empty? ? '(prazdne)' : echo} nesedi s vyberom #{cid}")
            return
          end

          cfg = Store.config(cab) || {}
          name = CabinetBuilder.sanitize_name(data['name'], cfg['type'])
          if name == CabinetBuilder.manual_name(cfg)
            push_selected(model, dedup: false) # UI resync (input -> text), model netreba menit
            return
          end

          begin
            CabinetBuilder.guarded do
              model.start_operation('NOXUN: Premenovanie skrinky', true)
              cfg['name'] = name
              Store.write_config(cab, cfg)
              model.commit_operation
            end
          rescue StandardError => e
            CabinetBuilder.abort_safely(model)
            Engine.log_error(e, 'Panel.handle_rename_cabinet')
            push_selected(model, dedup: false)
            return set_status('Názov sa nepodarilo uložiť — skús znova.', true)
          end

          set_status(name ? "#{cid} premenovaná na „#{name}“." \
                          : "#{cid} — vlastný názov zrušený, platí #{CabinetBuilder.display_name(cfg)}.")
          push_selected(model, dedup: false)
        end

        # Konstrukcne/rozmerove zmeny na oznaceny korpus. Zachova strom zon + cela.
        def handle_apply(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Zmena sa neuložila') # R-02

          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus v modeli.', true) if cab.nil?

          params = existing_params(cab)
          # ROH-A1: typ z/na rohovu a strana rohovej sa nemenia (0 krokov Spat).
          if (msg = corner_change_refusal(params, data))
            set_status(msg, true)
            push_selected(model) # UI resync na ulozeny stav
            return
          end
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
        # D-90 (audit F6): payload nesie snapshot cabinet_id z casu odoslania —
        # ak sa medzitym vyber presunul na INY korpus, zapis sa TICHO zahodi
        # (rovnaky guard ako handle_apply_all nizsie). HTML disabled nie je
        # ochrana; volajuci moze byt akykolvek (callback je verejny kanal).
        def handle_apply_fronts(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Čelá sa nezmenili') # R-02

          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus v modeli.', true) if cab.nil?

          echo = data['cabinet_id'].to_s
          if !echo.empty? && echo != Store.get(cab, 'cabinet_id').to_s
            Engine.log("apply_fronts zahodeny — echo #{echo} nesedi s vyberom #{Store.get(cab, 'cabinet_id')}")
            return
          end
          params = existing_params(cab)
          # S1-E (Astra FIX E9): slot ma JEDNO PEVNE CELO ako SERVEROVY
          # invariant — payload s dvoma celami, inym typom ci rezimom sa
          # ODMIETNE a config sa NEDOTKNE (vysku odvodi `normalize`, D-139).
          if (msg = slot_fronts_refusal(params, data['fronts']))
            return set_status(msg, true)
          end
          # ROH-A1: invariant ciel rohovej (R6) a medzera pri rohu (C3).
          if (msg = corner_fronts_refusal(params, data['fronts']))
            set_status(msg, true)
            push_selected(model)
            return
          end
          # KOV-C2b: `drawer.system` a `drawer.recipe_refs` su SERVEROVE.
          # Payload panela nahradza cela VCELKU, takze stale alebo podvrhnute
          # pole by pripnutu verziu receptu prepisalo — a s nou GEOMETRIU uz
          # postavenej zakazky. Klientske hodnoty sa preto zahadzuju a ULOZENE
          # sa pripajaju spat podla ID cela (Codex #301 kolo 3 P1).
          params['fronts'] = Fronts.reattach_server_drawer_fields(
            data['fronts'] || Fronts.empty_config, params['fronts']
          )
          CabinetBuilder.rebuild(model, cab, params)
          finish_cab(model, cab, "Cela aktualizovane — #{Store.get(cab, 'cabinet_id')}.")
        end

        # S1-E: JEDINA veta o tom, ze slot ma jedno pevne celo (a z coho sa
        # jeho vyska berie — D-139: je odvodena, ziadne pole ju nemeni).
        SLOT_FRONTS_MSG = 'Slot umývačky má jedno pevné čelo — jeho výška sa dopočíta z výšky linky, soklu a medzery hore.'

        # H12b: pravidlo ciel typu z registra (`fronts`), nie meno typu.
        def slot_fronts_refusal(params, incoming)
          return nil unless CabinetTypes.prop(params['type'], :fronts) == 'slot_fixed'
          return nil if incoming.nil?

          cfg = Fronts.normalize_config(incoming)
          return nil if CabinetBuilder.slot_fronts_ok?(cfg)

          SLOT_FRONTS_MSG
        rescue StandardError => e
          Engine.log_error(e, 'Panel.slot_fronts_refusal')
          nil
        end

        # ROH-A1 (R6 + krizovy audit C3/G3): cela ROHOVEJ — jeden riadok
        # dvierok, `auto`, jedno kridlo, medzera pri rohu 1–20 mm. Zmena poctu
        # riadkov, typu, kridiel alebo rezimu sa ODMIETNE (config sa nedotkne);
        # smer, profil, medzery v rozsahu, material a kovanie povolene ostavaju.
        # `params` = ULOZENY stav skrinky (typ a strana su z neho).
        def corner_fronts_refusal(params, incoming)
          return nil unless CabinetTypes.prop(params['type'], :fronts) == 'corner_one_door'
          return nil if incoming.nil?

          cfg = Fronts.normalize_config(incoming)
          return Construction::CORNER_FRONTS_MSG unless CabinetBuilder.corner_fronts_ok?(cfg)
          return Construction::CORNER_GAP_MSG unless corner_gap_ok?(cfg, params['corner_side'])

          nil
        rescue StandardError => e
          Engine.log_error(e, 'Panel.corner_fronts_refusal')
          nil
        end

        # ROH-A1 (krizovy audit G1 + C5): zmena TYPU z/na rohovu a zmena STRANY
        # existujucej rohovej sa v A1 odmietaju — poistka servera (panel typ
        # po oprave registrov posiela spravne, stranu neposiela vobec). Strana
        # sa porovnava NORMALIZOVANA (neznama hodnota = `left`, vzor normalize).
        # H12b (R2.4): IDENTITA typu ostava surova (`want` ≠ `have`), zamok je
        # vlastnost registra `type_locked` aspon jedneho z nich; stranu ma typ
        # s rohovou zostavou (`corner?`).
        def corner_change_refusal(params, data)
          have = params['type'].to_s
          if data.key?('type')
            want = data['type'].to_s
            locked = CabinetTypes.prop(want, :type_locked) || CabinetTypes.prop(have, :type_locked)
            return CORNER_TYPE_MSG if want != have && locked
          end
          return nil unless CabinetTypes.corner?(have) && data.key?('corner_side')

          side = data['corner_side'].to_s
          side = 'left' unless CabinetBuilder::CORNER_SIDES.include?(side)
          side == Construction.corner_side(params) ? nil : CORNER_SIDE_MSG
        end

        # ROH-B1 (O5): PREPINAC STRANY DVERI rohovej — samostatna akcia (jedina
        # cesta, ktora stranu meni). Guardy v poradi R-02: identita dokumentu
        # PRVA, potom oznacena skrinka a POVINNE echo `cabinet_id` (klik patri
        # skrinke, nad ktorou bol riadok vykresleny). Audit B1 FIX 3: BARIERA
        # OBSERVERA (`ScaleWatch.flush_pending!`) PRED citanim vychodiskoveho
        # configu — oneskorena absorpcia Scale sa inak prilepi k tejto operacii
        # a poskodi jej Redo; pri neuspechu odmietnutie, po bariere sa dokument
        # aj cielova skrinka overia ZNOVA. Potom typ rohova a platna strana.
        # Rovnaka strana = nic (ziadny prazdny krok Spat). Zmena = JEDNA
        # operacia prestavby nad `CabinetBuilder.corner_mirror_params`
        # (zrkadlo ciel a rucnych hran podla osi) = jeden krok Spat; pri chybe
        # ju `rebuild` zrusi bez stopy a panel sa vrati na ulozeny stav.
        # Audit B1 FIX 1: klient caka na KORELOVANU odpoved (`switch_token` ->
        # `NX.cornerSideResult`) — posiela sa v KAZDEJ vetve (aj pri tichom
        # zahodeni a vynimke), AZ PO pushi stavu; dovtedy panel auto-apply odklada.
        def handle_corner_side(payload)
          model = Sketchup.active_model
          data = parse(payload)
          ok = false
          return if foreign_document?(data, model, 'Strana dverí sa nezmenila') # R-02

          target = corner_side_target(model, data)
          return unless target
          unless ScaleWatch.flush_pending!(model) == true
            set_status(CORNER_SIDE_BUSY_MSG, true)
            return push_selected(model)
          end
          # Po bariere ZNOVA: observer mohol medzitym prestavat skrinku alebo
          # zmenit vyber (dokument sa pocas synchronneho volania nemeni, ale
          # guard je lacny a drzi poradie R-02).
          return if foreign_document?(data, model, 'Strana dverí sa nezmenila')

          cab = corner_side_target(model, data)
          return unless cab

          cid = Store.get(cab, 'cabinet_id').to_s
          params = existing_params(cab)
          unless CabinetTypes.corner?(params['type'])
            set_status('Stranu dverí má len rohová skrinka.', true)
            return push_selected(model)
          end
          want = data['corner_side'].to_s
          unless CabinetBuilder::CORNER_SIDES.include?(want)
            set_status('Neznáma strana dverí — nič sa nezmenilo.', true)
            return push_selected(model)
          end
          if want == Construction.corner_side(params)
            ok = true
            return push_selected(model, dedup: false)
          end

          mirrored = CabinetBuilder.corner_mirror_params(params, want)
          begin
            suspend_selection_sync do
              CabinetBuilder.rebuild(model, cab, mirrored, op_name: CORNER_SIDE_OP)
              reselect(model, cab)
            end
          rescue StandardError
            push_selected(model, dedup: false) # prepinac sa vrati na ULOZENU stranu
            raise
          end
          status_with_warnings(cab, "Dvere #{CORNER_SIDE_WORDS[want]} — #{cid} zrkadlená "                                     "(#{part_count(cab)} dielcov). Späť vráti stranu jedným krokom.")
          push_selected(model)
          ok = true
        ensure
          if data.is_a?(Hash) && data['switch_token'].is_a?(String)
            ack = data.slice('model_guid', 'cabinet_id', 'switch_token')
            ack['ok'] = ok == true
            js("NX.cornerSideResult(#{ack.to_json})")
          end
        end

        # Oznacena skrinka, ktorej patri klik (povinne echo `cabinet_id`), inak
        # nil + status a resync panela.
        def corner_side_target(model, data)
          cab = find_cabinet(model)
          if cab.nil?
            set_status('Najprv označ rohovú skrinku v modeli.', true)
            return nil
          end
          cid = Store.get(cab, 'cabinet_id').to_s
          echo = data['cabinet_id'].to_s
          return cab if !echo.empty? && echo == cid

          Engine.log("corner_side zahodeny — echo #{echo.inspect} nesedi s vyberom #{cid}")
          set_status('Výber sa medzitým zmenil — strana dverí sa nezmenila.', true)
          push_selected(model)
          nil
        end

        # V0.2c AUTO-APPLY: jedna zmena poľa (konstrukcia AJ cela) -> 1 rebuild, 1 undo krok.
        # Zachova strom zon (delenie/police/locky). Ticho ignoruje ak nie je oznaceny korpus.
        # V0.4.7e (Codex expr audit, blocker): payload nesie snapshot cabinet_id z casu
        # naplanovania debounce — oneskoreny zapis po prekliknuti na INY korpus sa ticho
        # zahodi namiesto zasiahnutia nespravneho objektu (rovnaky guard ako doska).
        def handle_apply_all(payload)
          model = Sketchup.active_model
          data = parse(payload)
          front_apply_ok = false
          # KOV-H2: ked apply prisiel z modalu rucnej polozky, ceka na VYSLEDOK.
          # `nil` = bezna zmena pola, ziadny modal neceka a nic sa neposiela.
          op = manual_op(data)
          # R-02: prepnutie dokumentu sa hlasi NAHLAS aj v auto-apply. Echo
          # `cabinet_id` sa ticho zahadzuje preto, ze presun vyberu je bezny;
          # prepnuty dokument bezny NIE JE a pouzivatel musi vediet, ze zmena,
          # ktoru prave napisal, sa NEULOZILA (inak ju najde az v objednavke).
          if foreign_document?(data, model, 'Zmena sa neuložila')
            # Modal by inak ostal ZAMKNUTY navzdy (zamok odomyka VYHRADNE
            # volajuci) — aj tichy zahod musi mat odpoved.
            return push_manual_result(op, false, 'Zmena sa neuložila — prepol sa dokument.')
          end

          cab = find_cabinet(model)
          if cab.nil? # auto-apply bez vyberu = ticho (ziadny modal)
            return push_manual_result(op, false, 'Skrinka už nie je označená — položka sa neuložila.')
          end

          echo = data['cabinet_id'].to_s
          if !echo.empty? && echo != Store.get(cab, 'cabinet_id').to_s
            Engine.log("apply_all zahodeny — echo #{echo} nesedi s vyberom #{Store.get(cab, 'cabinet_id')}")
            return push_manual_result(op, false, 'Výber sa medzitým zmenil — skús to znova.')
          end
          params = existing_params(cab)
          # S1-E: invariant jedneho pevneho cela (pocet, typ, rezim). D-139:
          # vyska sa neposudzuje — riadok z klienta nesie staru, `normalize`
          # ju odvodi z vysky linky, soklu a medzery hore tej istej davky.
          # ROH-A1: to iste pre rohovu — cela (R6, C3), typ a strana (G1, C5).
          if (msg = slot_fronts_refusal(params, data['fronts']) ||
                    corner_fronts_refusal(params, data['fronts']) ||
                    corner_change_refusal(params, data))
            set_status(msg, true)
            push_selected(model)
            return push_manual_result(op, false, msg)
          end
          PARAM_KEYS.each do |k|
            params[k] = data[k] if data.key?(k)
          end
          # KOV-C2b: to iste ako v `handle_apply_fronts` — serverove polia
          # klasifikacie zasuvky sa z payloadu zahadzuju a pripajaju spat.
          if data.key?('fronts')
            params['fronts'] = Fronts.reattach_server_drawer_fields(data['fronts'], params['fronts'])
          end
          # KOV-H1: ad-hoc kovanie ide TOU ISTOU cestou ako cela (audit #15
          # BLOCKER 1: ziadny novy zapisovy kanal — `collectAll` -> `apply_all`
          # -> `normalize` -> rebuild = 1 krok Spat, guardy, R-12).
          # Nazov mazanej polozky sa cita PRED preflightom — ten uz `params`
          # prepise ODOSLANYM zoznamom a zaznam by v nom nebol. Status musi
          # povedat, CO sa odstranilo (mazanie ide bez potvrdzovacieho okna).
          removed = manual_removed_label(params, op)
          hm = manual_preflight(params, data)
          if hm && hm[:error]
            @last_apply_error = hm[:error]
            set_status(hm[:error], true)
            push_selected(model) # UI resync — panel sa vrati na ULOZENY stav
            # AZ PO pushi: modal ostava otvoreny s rozpisanymi hodnotami, ale
            # `hwManual` uz drzi ULOZENY zoznam (neuspesna zmena sa nesmie
            # drzat). Poradie je preto kontrakt, nie nahoda.
            return push_manual_result(op, false, hm[:error])
          end
          pf = material_preflight(params, model) # D-45: telo + chrbat + ABS remap
          if pf && pf[:error]
            # Codex #170 P1: ODMIETNUTY apply si zapamatame. Klient si ho totiz
            # vyziada aj v handshaku pred inou akciou (napr. „Dielcov" v
            # informacnom stlpci) — a ta akcia by svojim statusom prekryla
            # PRAVU pricinu a tvarila sa, ze je vsetko v poriadku.
            @last_apply_error = pf[:error]
            set_status(pf[:error], true)
            push_selected(model) # UI resync (auto-apply nesmie nechat select 18 nad modelom 3)
            return push_manual_result(op, false, pf[:error])
          end
          @last_apply_error = nil # uspesny apply pripadny stary odmietnutok maze
          begin
            suspend_selection_sync do
              CabinetBuilder.rebuild(model, cab, params)
              reselect(model, cab)
            end
          rescue StandardError => e
            # Vynimka prestavby konci v `cb` wrapperi (log + status). Bez tejto
            # vetvy by ale modal ostal zamknuty a pouzivatel by nemal ako von.
            #
            # Codex #285 P2-B: PRED odpovedou musi ist RESYNC. Klient si totiz
            # `hwManual` prepisal OPTIMISTICKY uz pred odoslanim, kym operacia
            # sa zrusila a ULOZENA skrinka ostala nezmenena — bez pushu by si
            # panel drzal ODMIETNUTY zoznam a najblizsia nesuvisiaca zmena
            # skrinky by ho poslala znova (duplicitne pridanie, alebo dodatocne
            # uplatnene „neuspesne" mazanie). Rovnako to robia obe preflight
            # vetvy vyssie.
            push_selected(model)
            push_manual_result(op, false, "Kovanie sa neuložilo — #{e.message}.")
            raise
          end
          status_with_warnings(cab, "Prestavané — #{Store.get(cab, 'cabinet_id')} (#{part_count(cab)} dielcov).#{pf ? pf[:note] : ''}")
          push_selected(model)
          # P2-H: hlaska vysledku PREPISE status prestavby (klient ju posiela do
          # `NX.setStatus`), takze musi niest aj jej varovania — inak by
          # upozornenia z TEJ ISTEJ prestavby zmizli bez stopy.
          push_manual_result(op, true, manual_ok_msg(op, removed, cab))
          front_apply_ok = true
          # NASTROJE-1: tento apply prisiel ako FLUSH pred kopiou nastrojom.
          # Kopia bezi AZ TU — v tom istom callbacku, nad UZ ZAPISANYM configom
          # a AZ PO vsetkych pushoch (jej vlastny status ma ostat posledny).
          # Odmietnute vetvy vyssie sa sem nedostanu: kopirovat zo stareho
          # configu by bolo presne to, comu handshake predchadza — server takú
          # kópiu necha dobehnut do timeoutu a odmietne s hlaskou.
          resolve_native_op(data)
        ensure
          # Odpoved AJ pri tichom zahodeni ci zlyhani. Ziadna dalsia akcia
          # klienta nesmie brat odoslany apply ako potvrdeny zapis.
          if data.is_a?(Hash) && data['front_apply_token'].is_a?(String)
            ack = data.slice('model_guid', 'cabinet_id', 'front_apply_token')
            ack['ok'] = front_apply_ok == true
            js("NX.frontApplyResult(#{ack.to_json})")
          end
        end

        # --- NASTROJE-1: handshake pred kopiou nastrojom ---------------------
        # Uzavrety whitelist (vzor `manual_op`): server prijme LEN znamy druh
        # operacie a token si ocisti. Smer kopie sa TU NECITA — autorita je
        # cakajuci zaznam servera, klient posiela iba korelacny kluc.
        NATIVE_OPS = %w[copy].freeze

        def resolve_native_op(data)
          raw = data['native_op']
          return nil unless raw.is_a?(Hash)
          return nil unless NATIVE_OPS.include?(raw['kind'].to_s)
          return nil unless defined?(Tools::Mower)

          Tools::Mower.resolve_flush(manual_token(raw['token']), 'flushed')
        rescue StandardError => e
          Engine.log_error(e, 'Panel.resolve_native_op')
          nil
        end

        # Odpoved panela, ked NEBOLO co flushnut (`nothing`) alebo su v karte
        # cervene polia / rozpisany vyraz (`invalid`). Bez nej by server cakal
        # do timeoutu a kopiu odmietol — odpoved je preto POVINNA v kazdej vetve.
        def handle_native_flush_done(payload)
          data = parse(payload)
          return nil unless defined?(Tools::Mower)

          Tools::Mower.resolve_flush(manual_token(data['token']), data['result'].to_s)
        end

        # --- KOV-H2: signal vysledku pre modal rucnej polozky ----------------
        #
        # Modal D-15 sa pri odoslani ZAMKNE a odomyka ho VYHRADNE volajuci
        # (kontrakt kostry) — server mu preto musi odpovedat v KAZDEJ vetve
        # `handle_apply_all`, aj v tej, ktora zapis ticho zahadzuje.
        MANUAL_OPS = %w[add edit delete].freeze
        # Codex #285 P2-A: `token` je KORELACNY kluc jedneho odoslania. Server
        # ho NEVYRABA ani neinterpretuje — len ho vracia v echu, aby klient
        # spoznal, ci odpoved patri PRAVE tomu modalu, ktory zapis poslal.
        # Preto uzavrety tvar: len String/Integer a orezana dlzka (payload je
        # verejny kanal, do `execute_script` sa nesmie dostat lubovolny objekt).
        MANUAL_TOKEN_MAX = 40

        # -> nil (apply prisiel z formulara) | { 'kind' =>, 'id' =>, 'token' => }
        def manual_op(data)
          raw = data['manual_op']
          return nil unless raw.is_a?(Hash)

          kind = raw['kind'].to_s
          return nil unless MANUAL_OPS.include?(kind)

          { 'kind' => kind, 'id' => raw['id'].to_s, 'token' => manual_token(raw['token']) }
        end

        # Token z klienta: LEN retazec alebo cele cislo, orezany na dlzku.
        # Cokolvek ine (hash, pole, nil) = prazdny token — odpoved sa potom
        # ziadnemu modalu nepriradi, co je bezpecnejsie nez priradit ju zle.
        def manual_token(raw)
          return '' unless raw.is_a?(String) || raw.is_a?(Integer)

          raw.to_s[0, MANUAL_TOKEN_MAX]
        end

        def push_manual_result(op, ok, msg)
          return nil if op.nil?

          js("NX.hwManualResult(#{ok ? 'true' : 'false'}, #{msg.to_s.to_json}, #{op.to_json})")
          nil
        end

        MANUAL_OK_MSGS = { 'add' => 'Položka pridaná.', 'edit' => 'Položka upravená.',
                           'delete' => 'Položka odstránená.' }.freeze

        # POZOR: vola sa AJ pri beznom apply z formulara, ked `op` je nil —
        # argumenty sa v Ruby vyhodnocuju EAGERNE, takze skory navrat
        # `push_manual_result` sem NEDOSIAHNE. Bez tohto guardu spadol KAZDY
        # apply bez `manual_op` (nasla to in-SketchUp sada, headless nie —
        # handler potrebuje zivy model).
        def manual_ok_msg(op, removed = nil, cab = nil)
          return '' unless op.is_a?(Hash)

          base = removed ? "Odstránená ručná položka „#{removed}“." : MANUAL_OK_MSGS[op['kind'].to_s].to_s
          # Pripona je ZDIELANA so `status_with_warnings` — jeden zdroj textu,
          # ziadne skladanie na klientovi.
          "#{base}#{warn_suffix(cab)}"
        end

        # Nazov mazanej polozky z ULOZENEHO zoznamu (CISTA funkcia). Volna
        # polozka ma nazov, katalogova moze mat len kod — a ked nie je ani ten,
        # vrati sa nil a plati vseobecna hlaska (nikdy sa nic nevymysla).
        def manual_removed_label(params, op)
          return nil unless op.is_a?(Hash) && op['kind'] == 'delete'

          rec = Array(params['hardware_manual']).find do |r|
            r.is_a?(Hash) && r['id'].to_s == op['id'].to_s
          end
          return nil unless rec.is_a?(Hash)

          name = rec['name'].to_s.strip
          name = rec['code'].to_s.strip if name.empty?
          name.empty? ? nil : name
        end

        # --- D-143 (KON-0): „Prestaviť zastarané skrinky" z Kontroly ----------
        #
        # ZAPIS do modelu (preto zije v Paneli, nie v citacom jadre — brana
        # 1b-3). Klik prisiel zo Studia cez flush handshake panela (rozpisana
        # zmena Inspectora sa najprv aplikuje). Guardy bezia na SERVERI:
        #   gen           — klik zo stareho DOM,
        #   flush_blocked — cervene pole v Inspectore,
        #   model_guid    — medzitym prepnuty dokument (PRISNE — zapis),
        #   observer      — `ScaleWatch.flush_pending!`: vyber zastaranych
        #                   skriniek sa robi az PO ustaleni observera (kopia,
        #                   absorpcia Scale), inak by odlozeny tik dobehol po
        #                   nasej operacii.
        # Vyber je CERSTVY zber (`ProductionCore.back_stale_scan`), nie DOM.
        # Vsetko v JEDNEJ operacii (`rebuild_many`) = jeden krok Späť; skrinky
        # s odpojenym dielcom alebo neznamym kovanim sa preskocia a VYMENUJU.
        # KAZDA vetva konci `repush` — plny push odomkne tlacidlo v Kontrole.
        def back_rebuild_stale(model, data, generation:, status:, repush:)
          pc = ProductionCore
          if model.nil?
            repush.call
            return status.call('Žiadny aktívny model.', true)
          end
          unless data['gen'].to_i == generation.to_i
            repush.call
            return status.call('Kontrola sa medzitým zmenila — obnovené, klikni znova.', true)
          end
          if data['flush_blocked']
            repush.call
            return status.call('Najprv sa dokončí rozpísaná zmena v Inspectore — klikni znova.', true)
          end
          if DocKey.foreign?(data['model_guid'], model)
            repush.call
            return status.call('Model sa medzitým prepol — obnovené, klikni znova.', true)
          end
          if defined?(ScaleWatch) && ScaleWatch.respond_to?(:flush_pending!) && ScaleWatch.flush_pending!(model) != true
            repush.call
            return status.call('Model ešte dokončuje predchádzajúcu zmenu — klikni znova.', true)
          end

          plan = pc.back_stale_plan(pc.back_stale_scan(model))
          if plan['jobs'].empty?
            repush.call
            return status.call(pc.back_stale_empty_msg(plan), !plan['stale'].to_i.zero?)
          end

          jobs = plan['jobs'].map { |ent| [ent['ref'], existing_params(ent['ref'])] }
          # Vyber sa obnovuje LEN pri naozaj prestavanej skrinke; ked bol
          # oznaceny DIELEC (napr. chrbat s otvorenou kartou), vracia sa DIELEC
          # cez `part_key` — prestavba stare entity zahodi (vzor D-131
          # `MaterialsDialog.fronts_grain_apply`, Codex #365 kolo 2 P2).
          selected = find_cabinet(model)
          rebuilt_selected = selected && plan['jobs'].any? { |ent| ent['ref'] == selected }
          part = rebuilt_selected ? find_selected_part(model) : nil
          part_key = part ? canonical_part_key(existing_params(selected), part_identity(selected, part)) : nil
          suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: Prestaviť zastarané skrinky')
            if rebuilt_selected && selected.valid?
              if part_key
                focus_part(model, selected, part_key)
              else
                reselect(model, selected)
              end
            end
          end
          status.call(pc.back_stale_done_msg(plan), !plan['skipped'].empty?)
          push_selected(model)
          repush.call
        rescue StandardError => e
          Engine.log_error(e, 'Panel.back_rebuild_stale')
          # `rebuild_many` operaciu pri vynimke ABORTUJE sama (nic ostane rozrobene).
          repush.call
          status.call("Prestavba sa nevykonala: #{e.message}", true)
        end

      end
    end
  end
end
