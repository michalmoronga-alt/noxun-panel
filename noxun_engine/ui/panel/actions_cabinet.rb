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
        def handle_insert(payload)
          model = Sketchup.active_model
          params = parse(payload)
          # R-02: identita DOKUMENTU pred cimkolvek inym — vklad je najkritickejsia
          # zapisova cesta (nova geometria + nove ID v cudzej zakazke sa nedaju
          # „prehliadnut", pouzivatel ich najde az pri objednavke).
          return if foreign_document?(params, model, 'Skrinka sa nevložila')
          # UI-C1a: metadata sablony sa z payloadu vyberu HNED — do buildera
          # sa nikdy nedostanu; peciatka pouzitia ide az po uspesnom vlozeni.
          tpl_ref = take_template_ref!(params, 'cabinet')
          # R-12 [B1]: guard nad CIELOVOU instanciou pred novsou SABLONOU
          # nechrani — pri vklade ziadny cielovy korpus este neexistuje.
          # Autorita je ULOZENY ZAZNAM sablony, nie payload z CEF (JS prenasa
          # len zname polia, takze marker by v nom uz nemusel byt).
          if (tpl_msg = newer_template_refusal(tpl_ref, 'vloženie by nastavenia stratilo'))
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
          if GhostTool.start(model, plan, hardware: hw, template_ref: tpl_ref, note: note).nil?
            return set_status('Ghost vkladanie sa nepodarilo spustiť — skús to znova.', true)
          end
          # Poznamku preflightov (D-45 prevzata hrubka, materialove noty)
          # vypisuje AZ `ghost_after_commit` — pri stlaceni „Vlozit" sa este
          # nic nestalo, takze hlasit „hrubka prevzata" by bolo predcasne
          # a po kliku by sa to zopakovalo druhy raz (review #268 P3-7).
          set_status('Skrinka visí na kurzore — klikni, kam ju položiť. ' \
                     'Šípky ←/→ otáčajú, Alt prepína kotvu, ↓ drží domácu výšku, ↑ pustí voľnú výšku, Esc zruší.')
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
          return if foreign_document?(data, model, 'Výška ghostu sa nezmenila')

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
          set_status("Zámok výšky #{GhostTool.fmt_mm(s.lock_plane_z)} mm — ghost sadne na túto výšku.")
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
          inst = CabinetBuilder.build(model, params)
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
          name = CabinetBuilder.sanitize_name(data['name'])
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

        # V0.2c AUTO-APPLY: jedna zmena poľa (konstrukcia AJ cela) -> 1 rebuild, 1 undo krok.
        # Zachova strom zon (delenie/police/locky). Ticho ignoruje ak nie je oznaceny korpus.
        # V0.4.7e (Codex expr audit, blocker): payload nesie snapshot cabinet_id z casu
        # naplanovania debounce — oneskoreny zapis po prekliknuti na INY korpus sa ticho
        # zahodi namiesto zasiahnutia nespravneho objektu (rovnaky guard ako doska).
        def handle_apply_all(payload)
          model = Sketchup.active_model
          data = parse(payload)
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
          # NASTROJE-1: tento apply prisiel ako FLUSH pred kopiou nastrojom.
          # Kopia bezi AZ TU — v tom istom callbacku, nad UZ ZAPISANYM configom
          # a AZ PO vsetkych pushoch (jej vlastny status ma ostat posledny).
          # Odmietnute vetvy vyssie sa sem nedostanu: kopirovat zo stareho
          # configu by bolo presne to, comu handshake predchadza — server takú
          # kópiu necha dobehnut do timeoutu a odmietne s hlaskou.
          resolve_native_op(data)
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

      end
    end
  end
end
