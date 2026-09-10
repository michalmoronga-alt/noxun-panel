# frozen_string_literal: true
require 'digest' # KOV-D3b: odtlacok potvrdeneho nahladu upgradu
# Noxun Engine - Panel: kovanie (V0.4 faza 1) — rucne zasahy do poctov.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # Jeden zasah do kovania oznacenej skrinky. Identita = (owner_part_key,
        # generic_type, rule_id).
        #
        # D-93 (audit B2): zapis ide PO POLIACH — payload nesie 'field'
        # ('quantity' | 'disabled' | 'nominal_length') a 'value' (null = zrus
        # LEN toto pole). Zaznam identity sa MERGUJE (zmena NL nikdy nezmaze
        # rucny pocet a naopak) a zanikne az vtedy, ked ostane prazdny.
        # Stary tvar payloadu ostava funkcny: quantity N / disabled true /
        # reset true (= zahodi CELY zaznam).
        # Zapis + rebuild v jednej operacii (override zije v configu korpusu).
        # KOV-D2a: pribudla DRUHA os zamku `height_variant` (vyskovy variant
        # zasuvky). Zoznam MUSI sediet s `CabinetBuilder::OVERRIDE_CONTENT_KEYS`
        # (guard test) — inak by panel ulozil pole, ktore normalizacia zahodi.
        OVERRIDE_FIELDS = %w[quantity disabled nominal_length height_variant].freeze
        # KOV-C2b: identita receptovej polozky vysuvu (`Construction`
        # `drawer_hardware_item`). Pocet ani vypnutie sa na nej menit nedaju.
        RECIPE_RULE_PREFIX = 'recipe:'

        # Meni payload POCET alebo VYPNUTIE? Pozna OBA tvary (`field` + hodnota
        # aj stary `quantity`/`disabled`); `reset` (zahodenie CELEHO zaznamu)
        # sa nezakazuje — ten polozku vracia do stavu z receptu.
        def recipe_count_mutation?(data)
          return %w[quantity disabled].include?(data['field'].to_s) if data.key?('field')
          return false if truthy?(data['reset'])

          truthy?(data['disabled']) || !data['quantity'].nil?
        end

        # KOV-D2b: KORELACNY TOKEN jedneho odoslania z modalu nahrady (kostra
        # D-15). Server ho NEVYRABA ani neinterpretuje — len ho vracia v echu,
        # aby klient spoznal, ci odpoved patri PRAVE tomu oknu, ktore zapis
        # poslalo (vzor `manual_token`, Codex #285 P2-A). Uzavrety tvar: len
        # String/Integer a orezana dlzka — payload je verejny kanal a do
        # `execute_script` sa nesmie dostat lubovolny objekt.
        AXIS_TOKEN_MAX = 40

        def axis_token(raw)
          return nil unless raw.is_a?(String) || raw.is_a?(Integer)

          t = raw.to_s[0, AXIS_TOKEN_MAX]
          t.empty? ? nil : t
        end

        # Odpoved cakajucemu modalu. BEZ tokenu (klik na chip — ziadne okno
        # neceka) sa neposiela nic: `NX.hwAxResult` by nemal komu patrit.
        def push_axis_result(token, ok, msg)
          return nil if token.nil?

          js("NX.hwAxResult(#{ok ? 'true' : 'false'}, #{msg.to_s.to_json}, #{token.to_json})")
          nil
        end

        # Odmietnutie: hlaska do statusu (ak ju uz nenastavil volajuci) A do
        # cakajuceho modalu. Modal sa ODOMKNE a rozhodnutie zostane na
        # obrazovke — kontrakt D-15 „zapis okno nezatvara".
        def axis_fail(token, msg, status: true)
          set_status(msg, true) if status
          push_axis_result(token, false, msg)
          nil
        end

        def handle_set_hardware_override(payload)
          model = Sketchup.active_model
          data = parse(payload)
          # KOV-D2b: token cakajuceho modalu nahrady sa cita PRED prvym
          # navratom — inak by odmietnutie nechalo okno zamknute navzdy.
          tok = axis_token(data['ax_token'])
          # R-02: identita DOKUMENTU pred identitou skrinky — `cabinet_id` nizsie
          # prepnutie dokumentu nezachyti (CAB-001 je v kazdej zakazke).
          if foreign_document?(data, model, 'Kovanie sa nezmenilo')
            return axis_fail(tok, 'Kovanie sa nezmenilo — panel patrí inému dokumentu.',
                             status: false)
          end

          cab = find_cabinet(model)
          return axis_fail(tok, 'Najprv označ NOXUN korpus.') if cab.nil?

          gt = data['generic_type'].to_s
          rid = data['rule_id'].to_s
          return axis_fail(tok, 'Neznáma položka kovania.') if gt.empty? || rid.empty?

          # F6: payload nesie identitu RENDROVANEJ skrinky — zmena vyberu pred
          # obsluhou callbacku nesmie prepisat inu skrinku (vzor callbacku setov).
          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return axis_fail(tok, 'Výber sa medzitým zmenil — panel sa obnovil, skús znova.')
          end

          owner = present_str(data['owner_part_key'])
          # KOV-C2b: polozka vysuvu Z RECEPTU (`rule_id` „recipe:…") sa poctom
          # ani vypnutim menit NEDA — recept vydava PRAVE JEDEN vysuv ku
          # KONKRETNYM dielcom. Rucny zasah by rozbil dvojicu „dielce + kit"
          # (a fail-closed brana by zakazku aj tak zastavila).
          if rid.start_with?(RECIPE_RULE_PREFIX) && recipe_count_mutation?(data)
            return axis_fail(tok, 'Výsuv zásuvky vydáva recept — počet ani vypnutie sa meniť nedá. ' \
                                  'Zmeň klasifikáciu čela alebo jeho rozmery.')
          end
          field, value, err = override_change(data, model, cab, owner, gt, rid)
          return axis_fail(tok, err) if err

          params = existing_params(cab)
          all = params['hardware_overrides'].is_a?(Array) ? params['hardware_overrides'] : []
          all = consolidate_legacy_lock(all, owner, gt, rid)
          list = merge_override(all, owner, gt, rid, field, value)

          params['hardware_overrides'] = list
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: kovanie ručne')
            reselect(model, cab)
          end
          status_with_warnings(cab, override_status_msg(cab, field, value))
          push_selected(model)
          # AZ TU: zapis prebehol a panel je prekresleny — modal sa smie zavriet.
          push_axis_result(tok, true, '')
        rescue StandardError => e
          # KOV-D3b (Codex #315 kolo 1 P2): odkedy je modal nahrady zamknuty aj
          # proti ZATVORENIU (`busyLock`), musi odpoved prist AJ z vetvy vynimky
          # — inak by ho zdielany `cb` wrapper nechal viset zamknuty navzdy.
          Engine.log_error(e, 'Panel.handle_set_hardware_override')
          axis_fail(tok, 'Kovanie sa nezmenilo — zásah sa nepodarilo uložiť.')
        end

        # Zisti, ktore POLE sa meni a na aku hodnotu. -> [field, value, error]
        #   field == :all  -> zahodit cely zaznam (stare 'reset')
        #   value == nil   -> zrusit len dane pole
        def override_change(data, model, cab, owner, gt, rid)
          if data.key?('field')
            f = data['field'].to_s
            return [nil, nil, 'Neznáme pole ručného zásahu.'] unless OVERRIDE_FIELDS.include?(f)
            # `value: null` = ODOMKNUTIE JEDNEJ OSI (KOV-D2a R5): maze sa LEN
            # toto pole, druhy zamok tej istej identity zostava. Prazdny zaznam
            # zanikne az v `merge_override`.
            return [f, nil, nil] if data['value'].nil?
            return override_value(f, data['value'], model, cab, owner, gt, rid)
          end
          return [:all, nil, nil] if truthy?(data['reset'])
          return ['disabled', true, nil] if truthy?(data['disabled'])
          return override_value('quantity', data['quantity'], model, cab, owner, gt, rid) if data['quantity']

          [:all, nil, nil]
        end

        # Serverova validacia hodnoty pola (HTML disabled nie je ochrana).
        def override_value(field, raw, model, cab, owner, gt, rid)
          case field
          when 'disabled'
            [field, true, nil]
          when 'quantity'
            q = raw.to_i
            return [nil, nil, 'Počet musí byť aspoň 1 (alebo položku vypni).'] if q < 1
            [field, [q, BuildPlan::MAX_HW_QUANTITY].min, nil]
          when 'nominal_length'
            nl = HardwareRules.override_nl(raw.is_a?(String) ? Float(raw, exception: false) : raw)
            return [nil, nil, 'Neplatná dĺžka výsuvu.'] if nl.nil?
            return recipe_nl_value(cab, owner, gt, rid, nl) if recipe_rule?(rid)
            return [nil, nil, 'Táto dĺžka nie je v rade pravidla — otvor Pravidlá kovania.'] \
              unless series_value?(model, rid, gt, nl)
            [field, nl, nil]
          when 'height_variant'
            recipe_height_value(cab, owner, gt, rid, raw)
          else
            [nil, nil, 'Neznáme pole ručného zásahu.']
          end
        end

        def recipe_rule?(rid)
          rid.to_s.start_with?(RECIPE_RULE_PREFIX)
        end

        # Obe osi zamku patria VYHRADNE k polozke vysuvu (`generic_type slide`)
        # — presne to cita resolver. Zaznam ineho typu by ostal v configu ako
        # mrtvy zamok, ktory nikto necita (Codex #312 kolo 3 P2).
        def lock_item?(gt)
          gt.to_s == Recipes::LOCK_GENERIC_TYPE
        end

        LOCK_WRONG_TYPE = 'Zámok osi patrí len k položke výsuvu zásuvky.'

        # --- KOV-D2a (Astra #20 F5): RECEPTOVA zapisovacia cesta zamkov -------
        #
        # D-93 `series_value?` hlada VYHRADNE projektove pravidlo `fit_series`;
        # receptova polozka (`rule_id recipe:<id>`) takym pravidlom NIE JE, takze
        # zamok NL zasuvky sa dovtedy z panela ulozit NEDAL. Retaz je vzdy tato:
        #
        #   vlastnik (celo) -> jeho PRIPNUTY recept -> VYSLEDNA vyska -> rad TEJ
        #   vysky
        #
        # Kazdy clanok sa cita z CERSTVEHO SERVEROVEHO STAVU (ulozeny config
        # skrinky), NIKDY z payloadu: chip na obrazovke moze byt o generaciu
        # starsi nez model a zamok by potom drzal cislo z iného radu.
        # Projektove `fit_series` pravidla ostavaju pre NE-receptove polozky.
        #
        # -> [{ recipe:, ctx:, height:, height_reason: }, chyba|nil]
        def recipe_lock_context(cab, owner, rid)
          cfg = (cab && Store.config(cab)) || {}
          fid = PartKeys.front_id(owner.to_s)
          return [nil, 'Zámok sa dá uložiť len na zásuvkovom čele.'] if fid.nil?

          item = Array(cfg['front_items']).find { |f| f.is_a?(Hash) && f['id'].to_s == fid }
          kind, key = Recipes.recipe_key_for(item)
          return [nil, 'Toto čelo nie je klasifikovaná zásuvka — zámok sa uložiť nedá.'] unless kind == :ok

          drawer = item['drawer'].is_a?(Hash) ? item['drawer'] : {}
          state, ref = Recipes.active_ref(drawer['recipe_refs'], key[:system], key[:opening])
          ref = Recipes.pick_ref(drawer['recipe_refs'], key[:system], key[:opening]) if state == :missing
          return [nil, 'Zásuvka má pripnutú verziu receptu, ktorú plugin nepozná.'] if state == :unknown || ref.nil?
          # Identita zamku MUSI sediet s PRIPNUTYM receptom. Nesulad = panel
          # posiela zaznam k inej verzii, nez ktora teraz plati (stary payload).
          return [nil, 'Položka výsuvu sa medzitým zmenila — panel sa obnoví, skús znova.'] \
            unless rid.to_s == "#{RECIPE_RULE_PREFIX}#{ref}"

          recipe = Recipes.load(ref)
          # Svetle rozmery sa citaju RAZ a pouzivaju ich OBE osi (vyska aj NL) —
          # jeden vypocet, ziadne dva zdroje cisel.
          ctx = Recipes.atira?(recipe) ? drawer_axis_ctx(cfg, owner) : nil
          height, why = recipe_result_height(cfg, owner, recipe, ctx)
          [{ recipe: recipe, ctx: ctx, height: height, height_reason: why }, nil]
        rescue StandardError => e
          Engine.log_error(e, 'Panel.recipe_lock_context')
          [nil, 'Zámok sa nepodarilo overiť proti receptu.']
        end

        # VYSLEDNA vyska zasuvky z CERSTVEHO serveroveho stavu. Quadro vysku
        # nema -> [nil, nil] (os neexistuje, rad NL je jediny).
        # -> [vyska|nil, dovod_ked_nil|nil]
        def recipe_result_height(cfg, owner, recipe, ctx)
          return [nil, nil] unless Recipes.atira?(recipe)

          # (1) ZAMKNUTA vyska je najsilnejsia pravda: rad NL sa berie z vysky,
          #     ktora naozaj plati. Zamok v KONFLIKTE ale vyslednou vyskou NIE
          #     JE — rad sa z neho odvodit neda, takze nahrada NL ostava
          #     odmietnuta a opravit treba najprv VYSKU (poradie osi plati aj
          #     na zapisovej ceste).
          locked = Recipes.height_lock_value(recipe, ctx || { owner_part_key: owner.to_s },
                                             Array(cfg['hardware_overrides']))
          if locked
            return [locked, nil] if ctx.nil? ||
                                    Recipes.height_lock_problem(recipe, locked,
                                                                ctx[:clear_height].to_f).nil?

            return [nil, 'Zámok výšky zásuvky neplatí — oprav najprv výšku, ' \
                         'bez nej sa rad dĺžok určiť nedá.']
          end

          # (2) EMITOVANA polozka je odpoved SAMOTNEHO resolvera.
          item = Array(cfg['hardware']).find do |h|
            h.is_a?(Hash) && h['owner_part_key'].to_s == owner.to_s &&
              h['source'].to_s == BuildPlan::HW_SOURCE_RECIPE
          end
          params = item.is_a?(Hash) && item['params'].is_a?(Hash) ? item['params'] : {}
          emitted = Recipes.height_value(params['height_variant'])
          return [emitted, nil] if emitted

          # (3) FAIL-CLOSED zasuvka polozku NEVYDALA (napr. NL zamok mimo radu
          #     po zmensenej hlbke) — AUTOMATICKA vyska je pritom stale
          #     urcitelna. Bez tejto vetvy server odmietal vlastny navrh
          #     nahrady NL vetou „najprv zamkni vysku" (Codex #312 kolo 1 P2).
          return [nil, 'Rozmery zásuvky sa nepodarilo prečítať — dĺžka sa uložiť nedá.'] if ctx.nil?

          v = Recipes.pick_height_variant(recipe, ctx[:clear_height].to_f)
          return [v[:height], nil] if v

          [nil, 'Do zásuvky sa nezmestí ani najnižší variant — dĺžka sa uložiť nedá.']
        end

        # Svetle rozmery TOHTO cela — TA ISTA cesta, akou ich pocita payload osi
        # (`drawer_axes_map`). Druhy vypocet inde by sa casom rozisiel a ponuka
        # by slubovala hodnotu, ktoru zapis odmietne.
        def drawer_axis_ctx(cfg, owner)
          fid = PartKeys.front_id(owner.to_s)
          return nil if fid.nil?

          CabinetBuilder.drawer_axis_contexts(CabinetBuilder.config_to_params(cfg))[fid]
        end

        # NL zamok receptovej polozky: hodnota MUSI byt presne v rade VYSLEDNEJ
        # vysky. Ci sa zmesti do hlbky, rozhoduje az resolver (RED
        # `nl_lock_invalid`) — presne ako pri projektovom rade.
        def recipe_nl_value(cab, owner, gt, rid, nl)
          return [nil, nil, LOCK_WRONG_TYPE] unless lock_item?(gt)

          info, err = recipe_lock_context(cab, owner, rid)
          return [nil, nil, err] if err

          recipe = info[:recipe]
          height = info[:height]
          if Recipes.atira?(recipe) && height.nil?
            return [nil, nil, info[:height_reason] ||
                              'Výšku zásuvky sa nepodarilo určiť — dĺžka sa uložiť nedá.']
          end

          series = Recipes.series_for(recipe, height)
          unless series.any? { |v| (v.to_f - nl).abs < 0.001 }
            return [nil, nil, "Táto dĺžka nie je v rade #{Recipes.series_label(height)} pripnutého receptu."]
          end

          ['nominal_length', nl, nil]
        end

        # Vyskovy zamok: LEN Atira, hodnota MUSI byt vyskou pripnuteho receptu.
        def recipe_height_value(cab, owner, gt, rid, raw)
          return [nil, nil, LOCK_WRONG_TYPE] unless lock_item?(gt)
          return [nil, nil, 'Výškový zámok sa dá uložiť len na receptovej položke výsuvu.'] unless recipe_rule?(rid)

          hv = Recipes.height_value(raw.is_a?(String) ? Float(raw, exception: false) : raw)
          return [nil, nil, 'Neplatná výška zásuvky.'] if hv.nil?

          # Vyskovy zamok sa ZAPISUJE aj vtedy, ked vysledna vyska urcitelna
          # NIE JE — je to prave cesta, ktorou sa neplatny zamok opravuje.
          info, err = recipe_lock_context(cab, owner, rid)
          return [nil, nil, err] if err

          recipe = info[:recipe]
          unless Recipes.atira?(recipe)
            return [nil, nil, 'Tento systém zásuviek výškové varianty nemá — výška plynie z rozmeru čela.']
          end

          variants = recipe[:height_variants] || {}
          known = variants.keys.map(&:to_i)
          unless known.include?(hv)
            return [nil, nil, "Recept pozná len výšky #{known.sort.map { |h| "H#{h}" }.join(' · ')}."]
          end

          # KOV-D2a (Codex #312 kolo 2 P2): kandidat sa overuje proti CERSTVEJ
          # svetlej vyske, nie len proti receptu. Payload chipu moze byt starsi
          # nez model (celo sa medzitym znizilo) a bez tejto brany by akcia
          # „uspela", prestavba vzapati vydala `height_lock_invalid` a dielce
          # zmizli — fail-closed az PO zmene modelu.
          ctx = info[:ctx]
          need = (variants[Recipes.key_num(hv)] || {})[:min_clear_height].to_f
          if ctx && need > ctx[:clear_height].to_f
            return [nil, nil, "Výška H#{hv} sa už do svetlej výšky " \
                              "#{Recipes.fmt(ctx[:clear_height])} mm nezmestí " \
                              "(potrebuje #{Recipes.fmt(need)} mm)."]
          end

          ['height_variant', hv, nil]
        end

        # F5/F7: SET smie ulozit LEN hodnotu z aktualneho radu pravidla (presna
        # zhoda). Uz ULOZENA hodnota mimo radu sa nikdy nemaze — len sa zobrazi
        # a da sa odomknut (to je cesta 'value' => nil, ktora sem nechodi).
        def series_value?(model, rid, gt, nl)
          rule = Array(panel_hardware_rules(model)).find do |r|
            r.is_a?(Hash) && r['rule_id'].to_s == rid && r['output'].to_s == gt
          end
          return false unless rule && rule['kind'].to_s == 'fit_series'
          Array(rule['series']).any? { |s| (s.to_f - nl).abs < 0.001 }
        end

        # KOV-D2a (Codex #312 kolo 2 P1): LEGACY zamok NL (`rule_id`
        # `vysuvy-nl-podla-hlbky`) a receptovy zaznam su DVE identity, takze
        # `merge_override` sa legacy zaznamu nedotkne. Po zapise druhej osi by
        # tak na jednom vlastnikovi zili DVA zaznamy — a `apply_drawer_writes`
        # by pri prestavbe legacy premenoval na TU ISTU receptovu identitu.
        # `norm_hardware_overrides` z nich necha POSLEDNY, takze `nominal_length`
        # by ticho zmizol a zasuvka by zmenila dlzku AJ kit.
        #
        # Preto sa pri zapise na receptovu identitu legacy zaznam TOHO ISTEHO
        # vlastnika najprv ZLUCI: legacy polia su zaklad, receptove ich
        # prebijaju (nikdy ticha strata) a legacy zaznam zanikne.
        def consolidate_legacy_lock(all, owner, gt, rid)
          return all unless recipe_rule?(rid) && gt.to_s == Recipes::LOCK_GENERIC_TYPE

          legacy = Array(all).select { |ov| ov_match?(ov, owner, gt, Recipes::LOCK_LEGACY_RULE_ID) }
          return all if legacy.empty?

          rest = Array(all).reject { |ov| ov_match?(ov, owner, gt, Recipes::LOCK_LEGACY_RULE_ID) }
          rec = rest.select { |ov| ov_match?(ov, owner, gt, rid) }.last
          merged = { 'owner_part_key' => owner, 'generic_type' => gt, 'rule_id' => rid }
          [legacy.last, rec].each do |src|
            next unless src.is_a?(Hash)

            OVERRIDE_FIELDS.each { |k| merged[k] = src[k] if src.key?(k) && !src[k].nil? }
          end
          rest.reject { |ov| ov_match?(ov, owner, gt, rid) } + [merged]
        end

        # Merge do zaznamu identity: prazdny zaznam zanikne, ostatne polia ostanu.
        def merge_override(all, owner, gt, rid, field, value)
          rec = Array(all).select { |ov| ov_match?(ov, owner, gt, rid) }.last
          rest = Array(all).reject { |ov| ov_match?(ov, owner, gt, rid) }
          return rest if field == :all

          out = { 'owner_part_key' => owner, 'generic_type' => gt, 'rule_id' => rid }
          if rec.is_a?(Hash)
            OVERRIDE_FIELDS.each { |k| out[k] = rec[k] if rec.key?(k) && !rec[k].nil? }
          end
          if value.nil?
            out.delete(field)
          else
            out[field] = value
          end
          return rest unless OVERRIDE_FIELDS.any? { |k| out.key?(k) }

          rest + [out]
        end

        def override_status_msg(cab, field, value)
          cid = Store.get(cab, 'cabinet_id')
          if field == 'nominal_length'
            return "Dĺžka výsuvu odomknutá (platí automat) — #{cid}." if value.nil?

            return "Dĺžka výsuvu zamknutá na #{HardwareRules.fmt_mm(value)} mm — #{cid}."
          end
          # KOV-D2a: druha os. Hlaska menuje OS, nie „kovanie" — pouzivatel
          # musi z nej vediet, ktory zamok prave pustil.
          if field == 'height_variant'
            return "Výška zásuvky odomknutá (platí automat) — #{cid}." if value.nil?

            return "Výška zásuvky zamknutá na H#{value.to_i} — #{cid}."
          end
          "Kovanie upravené — #{cid}."
        end

        def ov_match?(ov, owner, gt, rid)
          return false unless ov.is_a?(Hash)
          ov_owner = present_str(ov['owner_part_key'])
          ov_owner == owner && ov['generic_type'].to_s == gt && ov['rule_id'].to_s == rid
        end

        # === KOV-D3a: UPGRADE RECEPTU — JEDNO CELO, JEDNA OPERACIA ===========
        #
        # Meni PRESNE JEDEN zaznam mapy `recipe_refs` PRESNE JEDNEHO cela
        # (Astra #20 F12/F13). Ostatne zaznamy mapy (druhy system, druhe
        # otvaranie) aj dormantne zamky INYCH receptov ostavaju nedotknute.
        #
        # PRECO PREFLIGHT, A NIE ROLLBACK (Astra #20 B3): konflikt receptu NIE
        # JE vynimka — `Construction.build_plan` ho vrati ako DATA
        # (`plan[:drawer_conflicts]`), `merge_final` ho ulozi do configu
        # a `rebuild` operaciu normalne COMMITNE. Zapis by teda „uspel"
        # a zasuvka by ostala bez dielcov na novej verzii. Preto sa cielovy
        # stav najprv postavi NASUCHO (bez zapisu do modelu) TYMI ISTYMI
        # funkciami ako stavba — a ked nesedi, NEZAPISE SA NIC: v modeli
        # ostava v1 aj povodne zamky.
        #
        # Payload: { cabinet_id, front_id, from: <stary ref>, to: <cielovy id> }.
        # Mapu `recipe_refs` klient NIKDY neposiela (`SERVER_DRAWER_KEYS`) —
        # posiela len OCAKAVANY stary ref, aby sa dala odhalit medzicasna zmena.
        UPGRADE_OP_NAME = 'NOXUN: nová verzia receptu zásuvky'
        UPGRADE_STALE = 'Stav zásuvky sa medzitým zmenil — panel sa obnoví, skús znova.'

        # KOV-D3b: odpoved CAKAJUCEMU modalu prechodu (kostra D-15). Vlastny
        # kanal, NIE `NX.hwAxResult`: ten obsluhuje stav modalu NAHRADY osi
        # (`HW_AX_MODAL`) a dva rozne modaly nesmu citat jeden stav — token by
        # sedel, ale zavrelo by sa cudzie okno. Bez tokenu (ziadne okno neceka)
        # sa neposiela nic — vzor `push_axis_result`.
        def push_upgrade_result(token, ok, msg)
          return nil if token.nil?

          js("NX.hwUpgradeResult(#{ok ? 'true' : 'false'}, #{msg.to_s.to_json}, #{token.to_json})")
          nil
        end

        # Odmietnutie: hlaska do statusu (ak ju uz nenastavil volajuci) A do
        # cakajuceho modalu — inak by okno ostalo zamknute navzdy.
        def upgrade_fail(token, msg, status: true)
          set_status(msg, true) if status
          push_upgrade_result(token, false, msg)
          nil
        end

        def handle_upgrade_drawer_recipe(payload)
          model = Sketchup.active_model
          data = parse(payload)
          # KOV-D3b: token cakajuceho modalu sa cita PRED prvym navratom
          # (sanitizer je zdielany s D2b — token je len echo, uzavrety tvar).
          tok = axis_token(data['up_token'])
          if foreign_document?(data, model, 'Verzia receptu sa nezmenila') # R-02
            return upgrade_fail(tok, 'Verzia receptu sa nezmenila — panel patrí inému dokumentu.',
                                status: false)
          end

          cab = find_cabinet(model)
          return upgrade_fail(tok, 'Najprv označ NOXUN korpus.') if cab.nil?

          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return upgrade_fail(tok, 'Výber sa medzitým zmenil — panel sa obnovil, skús znova.')
          end

          # ZAPISAT SA SMIE LEN TO, CO POUZIVATEL NAOZAJ VIDEL. Ked payload nesie
          # odtlacok, potvrdzoval KONKRETNY nahlad — a vtedy je jedno, ci zmenu
          # stavu odhalilo POROVNANIE ODTLACKU, alebo az preflight nad NOVYM
          # stavom padol: odpoved musi byt JEDNA a ta ista veta (Codex #315
          # kolo 1 P1, in-SU beh nad `615a92f`). Holy text preflightu by hovoril
          # o stave, ktory pouzivatel nikdy nevidel — a znel by ako chyba jeho
          # zasuvky, nie ako „medzitym sa nieco zmenilo".
          # Panel sa pri odmietnuti PREKRESLI, takze ponuka aj karta ukazuju
          # cerstvy stav a druhy pokus uz ide nad novym nahladom.
          prep, err = drawer_upgrade_prepare(model, cab, data)
          from_preview = !present_str(data['fingerprint']).nil?
          if err
            return upgrade_fail(tok, err) unless from_preview

            push_selected(model)
            return upgrade_fail(tok, upgrade_stale_reason(err))
          end

          err = drawer_upgrade_preview_problem(model, cab, prep, data)
          if err
            push_selected(model)
            return upgrade_fail(tok, err)
          end

          # JEDNA operacia: novy ref v mape + preadresovane zamky + prestavba.
          # Spat vrati vsetko naraz, Redo to isto obnovi (vzor D2a).
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, prep[:params], op_name: UPGRADE_OP_NAME)
            reselect(model, cab)
          end
          status_with_warnings(cab, "Zásuvka prešla na #{Recipes.label(prep[:recipe])} — " \
                                    "#{Store.get(cab, 'cabinet_id')}.")
          push_selected(model)
          # AZ TU: zapis prebehol a panel je prekresleny — modal sa smie zavriet.
          push_upgrade_result(tok, true, '')
        rescue StandardError => e
          # Zdielany `cb` wrapper vynimku zachyti a napise status — lenze modal
          # odomyka VYHRADNE volajuci (kontrakt D-15), takze bez odpovede by
          # ostal zamknuty navzdy. Preto sa odpoveda aj z tejto vetvy.
          Engine.log_error(e, 'Panel.handle_upgrade_drawer_recipe')
          upgrade_fail(tok, 'Prechod na novú verziu sa nepodaril — nezmenilo sa nič.')
        end

        # === KOV-D3b: DOPAD PRECHODU NA TOTO CELO (CITACI CALLBACK) ==========
        #
        # Astra #20 F13: pouzivatel nesmie potvrdzovat „prejsť na v2" naslepo
        # ani podla textoveho diffu konstant — verzia moze zmenit prahy, rad NL,
        # hrubky aj ABS BEZ zmeny `constants`. Ukazuje sa preto CO SA STANE
        # S TYMTO CELOM: vyska, NL, rozmery dielcov, zamky, kit.
        #
        # CISLA SKLADA SERVER, JS len kresli. A skladá ich z TOHO ISTEHO
        # NASUCHO POSTAVENEHO STAVU, ktory by sa aj zapisal (`drawer_upgrade_prepare`
        # -> `plan`), takze sa ponuka a zapis nemozu rozist. Ziadna operacia,
        # ziadny zapis do modelu, ziadny krok Spat.
        #
        # KEDY sa pocita: LENIVO, az na klik na ponuku. Payload karty nesie iba
        # LACNU otazku „existuje vydana vyssia verzia?" (`upgrade` blok, ktory
        # v produkcii vobec nevznikne), takze preflight — cely `build_plan`
        # + expanzia setov — sa pri pushi karty NIKDY nespusti.
        def handle_drawer_upgrade_impact(payload)
          model = Sketchup.active_model
          data = parse(payload)
          tok = axis_token(data['up_token'])
          if foreign_document?(data, model, 'Dopad novej verzie sa nezistil') # R-02
            return push_upgrade_impact(tok, false, 'Panel patrí inému dokumentu.')
          end

          cab = find_cabinet(model)
          return push_upgrade_impact(tok, false, 'Najprv označ NOXUN korpus.') if cab.nil?

          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return push_upgrade_impact(tok, false, 'Výber sa medzitým zmenil — panel sa obnovil.')
          end

          prep, err = drawer_upgrade_prepare(model, cab, data)
          return push_upgrade_impact(tok, false, err) if err

          impact = drawer_upgrade_impact(model, cab, prep)
          # Odtlacok ide S dopadom: klient ho pri „Prejsť" LEN vrati spat.
          impact['fingerprint'] = drawer_upgrade_fingerprint(cab, prep, impact)
          push_upgrade_impact(tok, true, nil, impact)
        rescue StandardError => e
          # Bez odpovede by klient cakal navzdy a tlacidlo ponuky by ostalo
          # mrtve (stav otazky cisti az odpoved). Fail-closed: `ok: false`.
          Engine.log_error(e, 'Panel.handle_drawer_upgrade_impact')
          push_upgrade_impact(tok, false, 'Dopad novej verzie sa nepodarilo zistiť.')
        end

        # Odpoved citacieho callbacku. `ok: false` = potvrdenie sa NEPONUKNE,
        # pouzivatel dostane len vetu preco.
        def push_upgrade_impact(token, ok, reason, impact = nil)
          return nil if token.nil?

          # `ok` sa nastavuje AZ NAKONIEC: obsah dopadu je serverovy, ale kluc
          # rozhodnutia nesmie prepisat ani omylom.
          res = ok == true && impact.is_a?(Hash) ? impact.dup : {}
          res['reason'] = reason.to_s unless ok == true
          res['ok'] = ok == true
          js("NX.hwUpgradeImpact(#{res.to_json}, #{token.to_json})")
          nil
        end

        # KOV-D3b: os zamku -> pole zaznamu overridu. ZRKADLO pomenovania osi
        # v payloade (`drawer_axes` — kluce `height` / `nl`) a v paneli
        # (`HW_AX`); guard test strazi, ze hodnoty su podmnozinou
        # `OVERRIDE_FIELDS` a kluce sedia s osami payloadu.
        UPGRADE_LOCK_AXES = { 'height' => 'height_variant', 'nl' => 'nominal_length' }.freeze

        # DOPAD = rozdiel medzi TERAJSIM a CIELOVYM stavom TOHTO cela.
        # Obe strany idu TOU ISTOU cestou (`Construction.build_plan` ->
        # `Recipes.resolve` + `HardwareSets.expand`): cielovu postavil PREFLIGHT
        # (ten isty stav, ktory by sa aj zapisal), terajsiu postavi ten isty
        # helper nad NEZMENENYMI parametrami skrinky. Ziadna vlastna formula,
        # ziadne citanie geometrie z modelu, ziadny textovy diff konstant.
        def drawer_upgrade_impact(model, cab, prep)
          now = drawer_upgrade_side(model, cab, existing_params(cab), prep[:fid], prep[:owner])
          to = prep[:side]
          out = { 'height' => drawer_upgrade_height(now[:params], to[:params]),
                  'nl' => upgrade_pair(now[:params]['nominal_length'],
                                       to[:params]['nominal_length']),
                  'parts' => drawer_upgrade_parts(now[:parts], to[:parts]),
                  'locks' => drawer_upgrade_locks(prep[:lock]),
                  'kit' => upgrade_pair(now[:codes], to[:codes]),
                  'from' => prep[:from], 'to' => prep[:to],
                  # `to_title` = PLNY nazov receptu do hlavicky okna („Atira
                  # SiSy v2"). Ponuka v karte nesie krátke `to_label` („v2") —
                  # su to dva rozne texty, preto dva rozne kluce.
                  'to_title' => Recipes.label(prep[:recipe]) }
          note = prep[:recipe][:release_note]
          out['release_note'] = note.to_s unless note.to_s.strip.empty?
          out
        end

        # ODTLACOK POTVRDENEHO NAHLADU (Codex #315 kolo 1 P1).
        #
        # Payload zapisu nesie len refy a identitu, takze medzi „ukáž dopad"
        # a „Prejsť" sa skrinka moze zmenit (rozmery, materialy, mapovanie
        # kovania, Spat/Redo) — `drawer_upgrade_prepare` by potom bezal nad NOVYM
        # stavom a zapisal INY dopad, nez ktory pouzivatel videl a potvrdil.
        # `from` to nechyti: ten strazi len to, ze sa medzitym nezmenil PRIPNUTY
        # RECEPT.
        #
        # Odtlacok sa berie z CELEHO dopadu (obe strany porovnania + identita),
        # nie z vybranych vstupov: co sa v dopade neprejavi, na potvrdeni
        # nezalezi — a co sa prejavi, odtlacok zmeni. Klient ho LEN VRACIA
        # (nic neskladá) a server ho pred zapisom prepocita TOU ISTOU funkciou.
        def drawer_upgrade_fingerprint(cab, prep, impact)
          raw = { 'cab' => Store.get(cab, 'cabinet_id').to_s, 'fid' => prep[:fid].to_s,
                  'impact' => impact }
          Digest::SHA256.hexdigest(JSON.generate(raw))[0, 32]
        end

        # Sedi odtlacok, ktory klient poslal, s TERAJSIM stavom? -> hlaska | nil
        # Chybajuci odtlacok je odmietnutie rovnako ako nesediaci: zapis smie
        # prist VYHRADNE z potvrdeneho nahladu (fail-closed).
        UPGRADE_STALE_PREVIEW = 'Stav skrinky sa medzitým zmenil — otvor náhľad znova.'

        # TA ISTA veta aj vtedy, ked zmenu odhalil az preflight nad novym stavom
        # — dovod sa PRIPOJI (pouzivatel ma vediet, co na novom stave nesadlo),
        # ale hlavna sprava ostava „stav sa zmenil", nie „tvoja zasuvka je zla".
        def upgrade_stale_reason(reason)
          r = reason.to_s.strip
          r.empty? ? UPGRADE_STALE_PREVIEW : "#{UPGRADE_STALE_PREVIEW.chomp('.')} — #{r}"
        end

        def drawer_upgrade_preview_problem(model, cab, prep, data)
          sent = present_str(data['fingerprint'])
          return UPGRADE_STALE_PREVIEW if sent.nil?

          now = drawer_upgrade_fingerprint(cab, prep, drawer_upgrade_impact(model, cab, prep))
          sent == now ? nil : UPGRADE_STALE_PREVIEW
        end

        def upgrade_pair(from, to)
          { 'from' => from, 'to' => to }
        end

        # VYSKA zasuvky. Atira nesie VYSKOVY VARIANT (`height_variant`, „H144"),
        # QUADRO ho NEMA VOBEC a vysku boxu nesie v `box_height` (mm) — presne
        # ako riadok zhrnutia karty (`drawer_row_text`). Ktore pole plati,
        # rozhoduje SERVER podla toho, co polozka vysuvu naozaj nesie; JS len
        # podla `kind` zvoli popisok a jednotku. Bez toho by Quadro ukazalo
        # „Výška — → —" a zmenu vysky boxu by ZAMLCALO (Codex #315 kolo 1 P2).
        def drawer_upgrade_height(now, to)
          if now['height_variant'].is_a?(Numeric) || to['height_variant'].is_a?(Numeric)
            upgrade_pair(now['height_variant'], to['height_variant']).merge('kind' => 'variant')
          else
            upgrade_pair(now['box_height'], to['box_height']).merge('kind' => 'box')
          end
        end

        # Dielce TOHTO cela: rola -> vyrobne rozmery [dlzka, sirka, hrubka].
        # Zoznam sa riadi CIELOM (co sa naozaj postavi) a k nemu sa doparuje
        # terajsi dielec; rola, ktora pribudne alebo zanikne, ma druhu stranu
        # `nil` — priznat sa musi aj to.
        def drawer_upgrade_parts(now, target)
          (target.keys + now.keys).uniq.map do |k|
            a = target[k] || now[k]
            { 'role' => a[:role], 'label' => drawer_part_label(a[:role], a[:side]),
              'from' => now[k] && now[k][:dims], 'to' => target[k] && target[k][:dims] }
          end
        end

        # Popisok riadku tabulky. QUADRO vydava DVA boky boxu (`box_side` vlavo
        # a vpravo) — bez rozlisenia by tabulka mala dva rovnako pomenovane
        # riadky a pouzivatel by nevedel, ktory je ktory.
        DRAWER_SIDE_SK = { 'left' => 'ľavý', 'right' => 'pravý' }.freeze

        def drawer_part_label(role, side)
          base = Recipes.role_label(role)
          s = side.to_s
          return base if s.empty?

          "#{base} — #{DRAWER_SIDE_SK[s] || s}"
        end

        # Zamky, ktore prechod PRENESIE. Hodnoty sa nemenia (kolizna brana D3a
        # uz odmietla vsetko ostatne), preto `kept: true` bez vynimky.
        # `lock` je PREADRESOVANY zaznam z prepare — nie druhe citanie configu.
        def drawer_upgrade_locks(lock)
          rec = lock.is_a?(Hash) ? lock : {}
          UPGRADE_LOCK_AXES.each_with_object([]) do |(axis, field), out|
            v = rec[field]
            out << { 'axis' => axis, 'value' => v, 'kept' => true } unless v.nil?
          end
        end

        # JEDNA STRANA porovnania: nasucho postaveny plan -> polozka vysuvu,
        # dielce cela a objednavacie kody. Ked sa strana postavit neda (napr.
        # terajsi stav je v konflikte), vracia PRAZDNE hodnoty — dopad sa tym
        # nerozbije, len sa ta strana neuvedie.
        def drawer_upgrade_side(model, cab, params, fid, owner)
          norm, plan = drawer_dry_plan(model, cab, params)
          item = drawer_plan_item(plan, owner)
          _err, codes = item ? drawer_upgrade_kit_problem(model, cab, norm, item) : [nil, []]
          { params: item.is_a?(Hash) && item['params'].is_a?(Hash) ? item['params'] : {},
            parts: drawer_plan_parts(plan, fid), codes: codes || [] }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.drawer_upgrade_side')
          { params: {}, parts: {}, codes: [] }
        end

        # Polozka vysuvu Z RECEPTU pre daneho vlastnika (ta ista identita, aku
        # cita nakup aj karta cela).
        def drawer_plan_item(plan, owner)
          Array(plan[:hardware]).find do |h|
            h.is_a?(Hash) && h['source'].to_s == BuildPlan::HW_SOURCE_RECIPE &&
              h['owner_part_key'].to_s == owner.to_s
          end
        end

        # VYRABANE dielce TOHTO cela z planu: `part_key` -> { rola, strana,
        # rozmery [dlzka, sirka, hrubka] }.
        #
        # KLUC JE `part_key`, NIE ROLA (Codex #315 kolo 1 P2): QUADRO vydava
        # `box_side` DVAKRAT (vlavo a vpravo) s rovnakou rolou — mapa klucovana
        # rolou by prvy dielec prepisala a tabulka by mala 4 riadky namiesto 5.
        # `part_key` je zaroven STABILNA identita naprie verziami receptu, takze
        # sa obe strany porovnania paruju spravne. Cielove celo sa pozna cez
        # `PartKeys.front_id` — jediny parser tvaru kluca.
        def drawer_plan_parts(plan, fid)
          Array(plan[:parts]).each_with_object({}) do |pd, out|
            next unless pd.is_a?(Hash) && pd[:material] == :drawer
            next unless PartKeys.front_id(pd[:part_key]).to_s == fid.to_s

            pr = pd[:prod] || {}
            out[pd[:part_key].to_s] =
              { role: pd[:role].to_s, side: drawer_part_side(pd[:part_key]),
                dims: [pr[:length].to_f.round(2), pr[:width].to_f.round(2),
                       pr[:thickness].to_f.round(2)] }
          end
        end

        # Variant kluca dielca (`front:F1/box_side:left` -> „left"), inak „".
        # Tvar kluca sklada `PartKeys.front(front_id, kind, variant)`.
        def drawer_part_side(part_key)
          seg = part_key.to_s.split('/').last.to_s
          i = seg.index(':')
          i ? seg[(i + 1)..].to_s : ''
        end

        # Overenie + cielovy config BEZ zapisu do modelu.
        # -> [{ params:, recipe:, fid:, owner:, from:, to:, lock:, side: }, nil]
        #    | [nil, hlaska]
        #
        # KOV-D3b (aditivne, CITACIA cast): navrat nesie aj to, co uz preflight
        # NASUCHO postavil — cielovu polozku vysuvu, dielce cela, objednavacie
        # kody (`side`) a PREADRESOVANY zamok (`lock`). Vdaka tomu vie citaci
        # callback dopadu ukazat CISLA Z TOHO ISTEHO STAVU, ktory by sa aj
        # zapisal; druhy vypocet by sa mohol s zapisom rozist. Zapisova cesta
        # (`handle_upgrade_drawer_recipe`) cita nadalej LEN `params` a `recipe`.
        def drawer_upgrade_prepare(model, cab, data)
          cfg = Store.config(cab) || {}
          fid = present_str(data['front_id'])
          return [nil, 'Chýba čelo, ktorého recept sa má zmeniť.'] if fid.nil?

          item = Array(cfg['front_items']).find { |f| f.is_a?(Hash) && f['id'].to_s == fid }
          kind, key = Recipes.recipe_key_for(item)
          return [nil, 'Toto čelo nie je klasifikovaná zásuvka — verzia receptu sa naň nevzťahuje.'] unless kind == :ok

          from = data['from'].to_s
          to = data['to'].to_s
          err = drawer_upgrade_target_problem(item, key, from, to)
          return [nil, err] if err

          owner = PartKeys.front(fid, 'panel')
          params = existing_params(cab)
          overrides, err = readdress_recipe_locks(Array(params['hardware_overrides']), owner, from, to)
          return [nil, err] if err

          fronts = Fronts.normalize_config(params['fronts'])
          unless Fronts.set_recipe_ref!(fronts, fid, "#{key[:system]}|#{key[:opening]}", to, expect: from)
            return [nil, UPGRADE_STALE]
          end

          next_params = params.merge('fronts' => fronts, 'hardware_overrides' => overrides)
          err, side = drawer_upgrade_preflight(model, cab, next_params, fid, owner)
          return [nil, err] if err

          [{ params: next_params, recipe: Recipes.load(to), fid: fid, owner: owner,
             from: from, to: to, side: side,
             # PREADRESOVANY zaznam zamku (uz s cielovym `rule_id`) — dopad ho
             # len vypise, necita config druhykrat.
             lock: Array(overrides).select { |ov| ov_match?(ov, owner, Recipes::LOCK_GENERIC_TYPE,
                                                            "#{RECIPE_RULE_PREFIX}#{to}") }.last },
           nil]
        rescue StandardError => e
          Engine.log_error(e, 'Panel.drawer_upgrade_prepare')
          [nil, 'Novú verziu receptu sa nepodarilo overiť — nezmenilo sa nič.']
        end

        # Smie sa TENTO zaznam mapy prepnut z `from` na `to`? (hlaska | nil)
        def drawer_upgrade_target_problem(item, key, from, to)
          drawer = item['drawer'].is_a?(Hash) ? item['drawer'] : {}
          state, ref = Recipes.active_ref(drawer['recipe_refs'], key[:system], key[:opening])
          # FAIL-CLOSED: upgrade ma zmysel LEN nad PLATNYM pripnutym receptom.
          # `:missing` (zaznam este nie je) ani `:unknown` (pin je poskodeny)
          # sa neopravuju upgradom — chybajuci doplni stavba, poskodeny je RED
          # `drawer_recipe_unknown` s vlastnou cestou napravy.
          return UPGRADE_STALE unless state == :known && !from.empty? && ref.to_s == from
          return 'Cieľová verzia receptu nie je vydaná — aktualizuj plugin.' unless released_recipe?(to)

          # `upgrade?` drzi OBE pravidla naraz: rovnaky system aj otvaranie
          # a VYSSIA verzia (rovnaka alebo nizsia = ziadny downgrade).
          return nil if Recipes.upgrade?(from, to)

          'Prejsť sa dá len na novšiu verziu toho istého systému a spôsobu otvárania.'
        end

        def released_recipe?(id)
          !id.to_s.empty? && Recipes.released.key?(id.to_s)
        rescue Recipes::RecipeError
          false
        end

        # PREADRESOVANIE ZAMKOV `recipe:<v1>` -> `recipe:<v2>` (hodnoty sa
        # zachovavaju, meni sa LEN to, ku ktorej polozke patria — vzor
        # `drawer_override_migration`).
        #
        # KOLIZNA BRANA: ked na CIELOVOM `rule_id` uz zaznam TOHO ISTEHO
        # vlastnika lezi (dormantny zamok z davnejsieho upgradu) a jeho obsah
        # NIE JE totozny s preadresovanym, upgrade sa ODMIETNE. Zlucenie by
        # ticho aktivovalo cudziu hodnotu (napr. davno zamknutu vysku), a to je
        # presne ta tichá zmena, ktorej cely package brani.
        # -> [nove pole overridov, nil] | [nil, hlaska]
        def readdress_recipe_locks(all, owner, from, to)
          gt = Recipes::LOCK_GENERIC_TYPE
          from_rid = "#{RECIPE_RULE_PREFIX}#{from}"
          to_rid = "#{RECIPE_RULE_PREFIX}#{to}"
          # `.last` = ta ista volba ako `norm_hardware_overrides` (z duplicitnej
          # identity plati POSLEDNY zaznam) — brana nesmie merat iny zaznam,
          # nez ktory nakoniec plati.
          src = Array(all).select { |ov| ov_match?(ov, owner, gt, from_rid) }.last
          dst = Array(all).select { |ov| ov_match?(ov, owner, gt, to_rid) }.last
          if dst && lock_content(dst) != lock_content(src)
            return [nil, 'Na novej verzii receptu už leží iný ručný zásah do výsuvu — ' \
                         'najprv ho zruš v Kovaní, potom prejdi na novú verziu.']
          end

          rest = Array(all).reject do |ov|
            ov_match?(ov, owner, gt, from_rid) || ov_match?(ov, owner, gt, to_rid)
          end
          [src ? rest + [src.merge('rule_id' => to_rid)] : rest, nil]
        end

        # Obsah zamku BEZ identity — porovnava sa nim kolizia na cielovom
        # `rule_id`. Chybajuce aj `nil` pole = pole nie je (rovnaky kontrakt
        # ako `merge_override`).
        def lock_content(rec)
          return {} unless rec.is_a?(Hash)

          OVERRIDE_FIELDS.each_with_object({}) do |k, out|
            out[k] = rec[k] if rec.key?(k) && !rec[k].nil?
          end
        end

        # NASUCHO POSTAVENY STAV: tie iste funkcie ako stavba (`normalize` ->
        # `drawer_thicknesses` -> `build_plan` -> `Recipes.resolve`). Ziadny
        # zapis do modelu, ziadna operacia. -> [norm, plan]
        #
        # KOV-D3b: TEN ISTY helper stavia OBE strany dopadu (cielovu aj
        # terajsiu) — dve rozne cesty by ukazali rozdiel, ktory v skutocnosti
        # sposobil len iny sposob vypoctu.
        def drawer_dry_plan(model, cab, params)
          cid = Store.get(cab, 'cabinet_id').to_s
          norm = CabinetBuilder.normalize(params)
          eff = CabinetBuilder.effective_materials(model, norm)
          # Pravidla kovania sa citaju LEN NA CITANIE (`panel_hardware_rules`):
          # stavba pouziva `ensure_project_rules!`, ktory pri prvom builde
          # snapshot ZAPISE — preflight nesmie do modelu zapisat nic.
          [norm, Construction.build_plan(norm, cid,
                                         hardware_rules: panel_hardware_rules(model),
                                         part_thicknesses: CabinetBuilder.drawer_thicknesses(norm, eff))]
        end

        # CIELOVY STAV NASUCHO + ten isty nakup (`HardwareSets.expand`).
        # Ziadny druhy vypocet, ziadny zapis do modelu, ziadna operacia.
        # -> [nil, { params:, parts:, codes: }] | [hlaska, nil]
        def drawer_upgrade_preflight(model, cab, params, fid, owner)
          norm, plan = drawer_dry_plan(model, cab, params)
          bad = Array(plan[:drawer_conflicts]).find do |c|
            c.is_a?(Hash) && c['front_id'].to_s == fid.to_s
          end
          return ["Nová verzia receptu na túto zásuvku nesadne: #{bad['message']}", nil] if bad

          item = drawer_plan_item(plan, owner)
          return ['Nová verzia receptu nevydala výsuv zásuvky — nezmenilo sa nič.', nil] if item.nil?

          err, codes = drawer_upgrade_kit_problem(model, cab, norm, item)
          return [err, nil] if err

          [nil, { params: item['params'].is_a?(Hash) ? item['params'] : {},
                  parts: drawer_plan_parts(plan, fid), codes: codes }]
        end

        # Najde NAKUP kit vysuvu pre vyslednu vysku a NL? Ide TOU ISTOU cestou
        # ako nakupny zoznam (`ProductionCore.hardware_expansion`), takze sa
        # nemozu rozist. KOV-D3b: vracia AJ objednavacie kody — dopad ich len
        # vypise, nespusta kvoli nim druhu expanziu.
        # -> [nil, [kody]] | [hlaska, nil]
        def drawer_upgrade_kit_problem(model, cab, norm, item)
          cid = Store.get(cab, 'cabinet_id').to_s
          state, err = drawer_upgrade_sets_state(model)
          return [err, nil] if err

          sets = norm[:hardware_sets].is_a?(Hash) ? norm[:hardware_sets] : {}
          exp = HardwareSets.expand([item.merge('owner_id' => cid)], state,
                                    cabinet_overrides: (sets.empty? ? {} : { cid => sets }),
                                    catalog: HardwareCatalog.items)
          u = Array(exp['unmapped']).first
          return [nil, drawer_kit_codes(exp)] if u.nil?

          ["Na novú verziu receptu nákup nenašiel kit výsuvu: #{HardwareSets.unmapped_reason_sk(u)}.", nil]
        end

        # Objednavacie kody expanzie (bez cien a nazvov — v tabulke dopadu ide
        # o jedinu otazku „meni sa to, co objednam?").
        def drawer_kit_codes(exp)
          Array(exp['rows']).map { |r| r.is_a?(Hash) ? r['code'].to_s : '' }
                            .reject(&:empty?).uniq.sort
        end

        # Snapshot setov projektu, inak globalna kniznica LEN NA CITANIE
        # (vzor `ProductionCore.hardware_expansion`). -> [state, nil] | [nil, hlaska]
        def drawer_upgrade_sets_state(model)
          status, state = HardwareSets.project_state_status(model)
          return [nil, 'Sety projektu sú poškodené — obnov ich v Katalógu kovania (Predvoľby projektu).'] \
            if status == :invalid
          return [state, nil] unless status == :missing

          lib = HardwareSets.load
          return [nil, "#{HardwareSets.library_state_reason} — kit výsuvu sa overiť nedá."] \
            if HardwareSets.library_read_only?

          by_id = {}
          Array(lib['sets']).each { |s| by_id[s['set_id']] = s if s.is_a?(Hash) }
          [{ 'mapping' => lib['mapping'], 'sets' => by_id }, nil]
        end

        # V0.6 D1b: vyber setu kovania NA SKRINKE (override projektovej
        # predvolby). set_id prazdne = spat na predvolbu projektu. Zapis
        # overridu + definicia setu do snapshotu (audit B2) + rebuild =
        # JEDNA operacia (rebuild_many yield).
        # H1b (D-81): payload moze niest owner_part_key — potom je override LEN
        # na tom dielci (kluc "generic_type@owner_part_key"). Tvar kluca aj
        # kontrolu, ci dielec take kovanie vobec ma, robi VYHRADNE server
        # (HardwareSets.apply_cabinet_override) — jedna zapisova cesta pre oba
        # pripady, ziadne skladanie klucov v paneli.
        def handle_set_hardware_set(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Set kovania sa nezmenil') # R-02

          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus.', true) if cab.nil?

          gt = data['generic_type'].to_s
          return set_status('Neznámy typ kovania.', true) unless BuildPlan::GENERIC_TYPES.include?(gt)

          # GH #127 P2: payload nesie identitu RENDROVANEJ skrinky — zmena
          # vyberu pred obsluhou callbacku nesmie prepisat inu skrinku.
          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return set_status('Výber sa medzitým zmenil — panel sa obnovil, skús znova.', true)
          end

          status, = HardwareSets.project_state_status(model)
          if status == :invalid
            return set_status('Sety projektu sú poškodené — obnov ich v Katalógu kovania (Predvoľby projektu).', true)
          end

          owner = present_str(data['owner_part_key'])
          # KOV-D1a (Codex #307 P1): hodnotou uz smie byt aj VYBER PODLA
          # PARAMETRA (Atira: pasma podla `height_variant`) — zasuvka s vyskovym
          # variantom sa pevnym set_id vybrat NEDA. Tvar overuje jediny parser,
          # obsah (klasifikacia kazdeho pasma, neaktivne sety) sa overuje PRED
          # zapisom v `apply_cabinet_override`.
          value = hw_set_value(data)
          set_defs = []
          unless value.nil?
            vstatus, vmsg, refs = HardwareSets.parse_mapping_value(value)
            return set_status("Výber setu sa nedá uložiť — #{vmsg}.", true) unless vstatus == :ok

            # H1a (audit BLOCKER 4): definiciu vybera resolver — pre set_id,
            # ktore projekt uz pouziva, vyhrava SNAPSHOT (podla neho sa
            # nakupuje), global je len fallback pre nereferencovane.
            # Do snapshotu sa zmrazi KAZDY referencovany set (Astra #20 F9).
            refs.each do |rid|
              cand = HardwareSets.resolve_set_def(model, rid)
              cand = nil unless cand && cand['generic_type'] == gt
              if cand.nil?
                # R-07 (review P3-6): pri nekompatibilnej kniznici resolver
                # zamerne nic nevyda — „otvor Katalóg kovania a skús znova"
                # by pouzivatela poslalo tam, kde sa to opravit NEDA.
                return set_status(HardwareSets.library_read_only? ?
                                    "#{HardwareSets.library_state_reason} — set sa nedá vybrať." :
                                    'Set sa nenašiel — otvor Katalóg kovania a skús znova.', true)
              end
              set_defs << cand
            end
          end

          cfg = Store.config(cab) || {}
          st, map, = HardwareSets.apply_cabinet_override(cfg, gt, owner, value,
                                                         known_sets: (value.nil? ? nil : set_defs))
          return set_status("Výber setu sa nedá uložiť — #{map}.", true) unless st == :ok

          params = existing_params(cab)
          params['hardware_sets'] = map
          suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, [[cab, params]], op_name: 'NOXUN: set kovania') do
              HardwareSets.add_project_sets!(model, set_defs) unless set_defs.empty?
            end
            reselect(model, cab)
          end
          status_with_warnings(cab, hw_set_status_msg(gt, owner, value, set_defs))
          push_selected(model)
        end

        # Hodnota vyberu z payloadu: `value` (selector Hash) ma prednost pred
        # `set_id` (retazec). Prazdne oboje = zrusenie overridu (nil).
        # ZIADNE skladanie klucov ani hodnot v paneli — tvar rozhoduje server.
        def hw_set_value(data)
          # PRITOMNE `value` sa NIKDY nepresvieti na `set_id` (vlastny prechod
          # diffu po Codex #308 kolo 2 — ten isty vzor „pritomne neplatne sa
          # tvari ako nepritomne"): ked klient posle vyber, rozhoduje ON.
          # Nepouzitelny tvar potom odmietne server s hlaskou, nie ticho.
          return data['value'] if data.key?('value') && !data['value'].nil?

          present_str(data['set_id'])
        end

        # --- KOV-H2: hladanie v katalogu pre modal rucnej polozky ------------
        #
        # CITACIA cesta: ziadna operacia, ziadny zapis do modelu, ziadny krok
        # Spat. Preto tu NIE JE guard dokumentu — nic sa nemeni a odpoved
        # obsahuje len to, co je v katalogu (ten je globalny, nie per zakazka).
        #
        # PORADIE SKLADA SERVER (`HardwareCatalog.search_with_total`) — panel
        # ho len kresli, presne ako v Studiu (kontrakt GH #100 P2). `gen` je
        # generacia dotazu: odpovede chodia asynchronne a bez nej by pomalsie
        # kolo prepisalo cerstvejsie vysledky.
        #
        # Vracia sa NAJVIAC `MANUAL_SEARCH_TOP` poloziek + `total`, aby panel
        # vedel priznat orezanie (zasada „no silent caps"). Neaktivne polozky
        # sa neponukaju (default `search`) — do zakazky sa nema dostat kod,
        # ktory uz nikto neobjednava.
        MANUAL_SEARCH_TOP = 20

        def handle_hw_manual_search(payload)
          data = parse(payload)
          js("NX.hwManualSearchResult(#{hw_manual_search_result(data['q'], data['gen']).to_json})")
        end

        # CISTA funkcia (ziadny SketchUp objekt, ziadny dialog) — headless
        # testovatelna. Klientovi ide LEN to, co potrebuje ponuka: kod, nazov,
        # MJ, kategoria a ZIVA cena; nic z toho sa nikdy neuklada do configu.
        def hw_manual_search_result(query, gen)
          items, total = HardwareCatalog.search_with_total(HardwareCatalog.items, query.to_s,
                                                           top: MANUAL_SEARCH_TOP)
          items, total = drop_inactive(items, total)
          { 'gen' => gen.to_i, 'total' => total.to_i,
            'items' => Array(items).map { |i| manual_search_item(i) } }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hw_manual_search_result')
          { 'gen' => gen.to_i, 'total' => 0, 'items' => [] }
        end

        # Codex #285 kolo 2 (P2-I): `search_with_total` vracia NEAKTIVNU polozku
        # pri PRESNEJ zhode kodu aj bez `include_inactive` — je to vedomy
        # kontrakt katalogu (kto kod pozna, ma pravo ho v katalogu najst).
        # V naseptavaci je to ale pasca: vykreslila by sa ako bezny vyber
        # a pouzivatel, ktory pozna stary kod, by si do zakazky pridal polozku,
        # ktoru katalog vedie ako UZ NEOBJEDNAVANU.
        #
        # ZAPISOVA cesta (`norm_hardware_manual` / `HardwareCatalog.find`) sa
        # VEDOME NEMENI: polozka, ktora v configu uz je (legacy zakazka,
        # sablona), musi prestavbu prezit — zahodit ju by znamenalo ticho
        # odobrat kus z objednavky.
        #
        # `total` sa znizuje o to, co filter zahodil — inak by ponuka slubovala
        # viac, nez sa da vybrat (zasada „no silent caps" plati aj naopak).
        def drop_inactive(items, total)
          list = Array(items)
          kept = list.reject { |i| i.is_a?(Hash) && i['active'] == false }
          [kept, [total.to_i - (list.length - kept.length), kept.length].max]
        end

        def manual_search_item(item)
          { 'code' => item['item_code'].to_s, 'name_sk' => item['name_sk'].to_s,
            'unit' => item['unit'].to_s, 'category' => item['category'],
            'price_eur_vat' => (item['price_eur_vat'].is_a?(Numeric) ? item['price_eur_vat'].to_f : nil) }
        end

        # === KOV-G2 (D-111): NAHLAD NOH PRE VKLADACIU KARTU A GHOST PASIK ====
        #
        # CITACIA cesta ako `hw_manual_search`: ziadna operacia, ziadny zapis do
        # modelu, ziadny krok Spat — a preto ani guard dokumentu (nic sa nemeni
        # a odpoved je len text). `gen` je generacia dotazu: odpovede chodia
        # asynchronne a bez nej by pomalsie kolo prepisalo cerstvejsie cislo.
        #
        # Z payloadu sa berie UZAVRETY zoznam poli (`INSERT_LEGS_KEYS`) —
        # nahlad je pohlad na ROZMERY, nie druha vkladacia cesta; cudzi kluc
        # (materialy, zony, sablona) by sa cez `normalize` dostal do configu,
        # z ktoreho by pravidla mohli vydat nieco ine, nez co sa naozaj vlozi.
        # Nic sa NEUKLADA: `cfg` zije len v tomto volani.
        INSERT_LEGS_KEYS = %w[type width floor_height plinth_mode].freeze
        # KOV-G2 (Codex #339 kolo 1 N1): SABLONA nesie aj KOVANIE — mapovanie
        # setov a ich zmrazene definicie. Vlozena skrinka ich naozaj dostane
        # (`handle_insert` -> `take_insert_hardware!` -> `ghost_freeze_hardware`),
        # takze nahlad, ktory by ich prehliadol, by ukazoval PROJEKTOVU predvolbu
        # a slubil by ine nohy, nez skrinka dostane. Kluce maju VLASTNU cestu
        # (nie `INSERT_LEGS_KEYS`): citaju sa TOU ISTOU branou ako pri vklade,
        # nie tolerantnym `normalize`.
        INSERT_LEGS_HW_KEYS = %w[hardware_sets hardware_set_defs].freeze

        def handle_insert_legs_preview(payload)
          data = parse(payload)
          js("NX.insertLegsPreview(#{insert_legs_preview_result(data).to_json})")
        end

        def insert_legs_preview_result(data)
          d = data.is_a?(Hash) ? data : {}
          fields = d.select { |k, _| INSERT_LEGS_KEYS.include?(k.to_s) }
          mapping, defs = insert_legs_template_hw(d)
          # Mapovanie ide do configu TOU ISTOU cestou ako pri vklade
          # (`params['hardware_sets']` -> `normalize`), takze `cabinet_set_overrides`
          # nizsie vidi presne to, co uvidi postavena skrinka.
          fields['hardware_sets'] = mapping unless mapping.empty?
          cfg = CabinetBuilder.normalize(fields)
          legs_preview_summary(Sketchup.active_model, cfg,
                               set_defs: defs).merge('gen' => d['gen'].to_i)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.insert_legs_preview_result')
          { 'gen' => (data.is_a?(Hash) ? data['gen'].to_i : 0),
            'text' => '', 'short' => '', 'tone' => 'none', 'set_id' => nil, 'set_name' => nil }
        end

        # Kovanie SABLONY z payloadu nahladu — TA ISTA brana ako pri vklade
        # (`take_insert_hardware!`): mapovanie cez `read_template_mapping`
        # (allow_owner: false — composite kluce patria dielcom ZDROJOVEJ skrinky),
        # definicie cez `assess_set_defs` (bezstratovo alebo vobec). Necitatelne
        # kovanie vklad ODMIETNE hlaskou, takze nahlad ho ticho ignoruje a ukaze
        # projektovu predvolbu — poskladat z neho polovicu by znamenalo slubit
        # nieco, co sa nikdy nevlozi.
        # -> [mapovanie, definicie|nil]
        def insert_legs_template_hw(data)
          hw = data.select { |k, _| INSERT_LEGS_HW_KEYS.include?(k.to_s) }
          status, mapping = HardwareSets.read_template_mapping(hw['hardware_sets'])
          return [{}, nil] unless status == :ok && mapping.is_a?(Hash) && !mapping.empty?

          dstatus, = HardwareSets.assess_set_defs(hw['hardware_set_defs'])
          [mapping, dstatus == :ok ? hw['hardware_set_defs'] : nil]
        end

        # JEDINA cesta k suhrnu noh PRED vlozenim (vkladacia karta aj ghost
        # pasik). Kontext korpusu stavia `Construction.cabinet_hw_ctx` — TEN
        # ISTY slovnik, aky pouzije stavba; pravidla sa citaju
        # `panel_hardware_rules` (projektovy snapshot, inak globalna kniznica),
        # teda presne tie, s akymi sa skrinka postavi. Dielce sa nepodavaju
        # (`parts = []`), takze sa vyhodnotia LEN korpusove pravidla — nohy
        # a prichyt sokla. Rozpis kazdej polozky robi `item_purchase`, ta ista
        # funkcia ako v karte oznacenej skrinky (jeden vyklad nakupu).
        #
        # KOV-G2 (Codex #339 kolo 1 N1): vyber setu sa cita z CONFIGU
        # (`cabinet_set_overrides`) — pri vklade zo SABLONY tam uz stoji jej
        # mapovanie a v ghost session ho nesie zmrazeny plan. `set_defs` su
        # definicie zo sablony, ktore v projekte este nie su: nahlad sa pyta
        # PROSPEKTIVNEHO stavu (`state_with_template_sets`), teda toho, ktory
        # bude platit po vlozeni — inak by tvrdil „typ nema priradeny set",
        # hoci set pride so sablonou.
        def legs_preview_summary(model, cfg, set_defs: nil)
          hw = HardwareRules.evaluate(cfg, [], Construction.cabinet_hw_ctx(cfg),
                                      rules: panel_hardware_rules(model))
          items = HardwareSets.legs_items(hw[:items])
          # Horna skrinka / bez podstavca: ziadne IO, hned „bez nôh".
          return HardwareSets.legs_summary_from_purchase([]) if items.empty?

          status, state = hardware_read_state
          # R-07: nekompatibilna kniznica a projekt bez snapshotu — override sa
          # NEUPLATNI (rovnako ako v `decorate_hardware_purchase`) a definicie
          # zo sablony sa nemaju k comu pridat (vklad ich tiez nezmrazi).
          blocked = status == :missing && HardwareSets.library_read_only?
          overrides = blocked ? {} : cabinet_set_overrides(cfg)
          state = HardwareSets.state_with_template_sets(state, overrides, set_defs) unless blocked
          lookup = HardwareSets.catalog_lookup(HardwareCatalog.items)
          HardwareSets.legs_summary_from_purchase(items.map do |h|
            h.merge('purchase' => item_purchase(h, status, state, overrides, lookup,
                                                blocked: blocked))
          end)
        end

        # Hlaska po zmene setu — rozlisi skrinku a konkretny dielec (D-81).
        # KOV-D1a: hodnotou moze byt aj vyber podla parametra (viac setov).
        def hw_set_status_msg(gt, owner, value, set_defs)
          who = "#{HardwareRules.label_for(gt)}#{owner ? " pre dielec #{owner}" : ''}"
          return "#{who}: platí #{owner ? 'výber skrinky/projektu' : 'predvoľba projektu'}." if value.nil?
          if value.is_a?(Hash)
            n = Array(value['bands']).length
            return "#{who}: #{HardwareSets.param_by(value['param'])} (#{n} #{n == 1 ? 'pásmo' : 'pásma'})."
          end

          "#{who}: set „#{Array(set_defs).first&.fetch('name', value) || value}“."
        end
      end
    end
  end
end
