# frozen_string_literal: true
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

        def handle_set_hardware_override(payload)
          model = Sketchup.active_model
          data = parse(payload)
          # R-02: identita DOKUMENTU pred identitou skrinky — `cabinet_id` nizsie
          # prepnutie dokumentu nezachyti (CAB-001 je v kazdej zakazke).
          return if foreign_document?(data, model, 'Kovanie sa nezmenilo')

          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus.', true) if cab.nil?

          gt = data['generic_type'].to_s
          rid = data['rule_id'].to_s
          return set_status('Neznáma položka kovania.', true) if gt.empty? || rid.empty?

          # F6: payload nesie identitu RENDROVANEJ skrinky — zmena vyberu pred
          # obsluhou callbacku nesmie prepisat inu skrinku (vzor callbacku setov).
          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return set_status('Výber sa medzitým zmenil — panel sa obnovil, skús znova.', true)
          end

          owner = present_str(data['owner_part_key'])
          # KOV-C2b: polozka vysuvu Z RECEPTU (`rule_id` „recipe:…") sa poctom
          # ani vypnutim menit NEDA — recept vydava PRAVE JEDEN vysuv ku
          # KONKRETNYM dielcom. Rucny zasah by rozbil dvojicu „dielce + kit"
          # (a fail-closed brana by zakazku aj tak zastavila).
          if rid.start_with?(RECIPE_RULE_PREFIX) && recipe_count_mutation?(data)
            return set_status('Výsuv zásuvky vydáva recept — počet ani vypnutie sa meniť nedá. ' \
                              'Zmeň klasifikáciu čela alebo jeho rozmery.', true)
          end
          field, value, err = override_change(data, model, cab, owner, gt, rid)
          return set_status(err, true) if err

          params = existing_params(cab)
          all = params['hardware_overrides'].is_a?(Array) ? params['hardware_overrides'] : []
          list = merge_override(all, owner, gt, rid, field, value)

          params['hardware_overrides'] = list
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: kovanie ručne')
            reselect(model, cab)
          end
          status_with_warnings(cab, override_status_msg(cab, field, value))
          push_selected(model)
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
            return recipe_nl_value(cab, owner, rid, nl) if recipe_rule?(rid)
            return [nil, nil, 'Táto dĺžka nie je v rade pravidla — otvor Pravidlá kovania.'] \
              unless series_value?(model, rid, gt, nl)
            [field, nl, nil]
          when 'height_variant'
            recipe_height_value(cab, owner, rid, raw)
          else
            [nil, nil, 'Neznáme pole ručného zásahu.']
          end
        end

        def recipe_rule?(rid)
          rid.to_s.start_with?(RECIPE_RULE_PREFIX)
        end

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
        # -> [recipe, vysledna_vyska|nil, chyba|nil, dovod_chybajucej_vysky|nil]
        def recipe_lock_context(cab, owner, rid)
          cfg = (cab && Store.config(cab)) || {}
          fid = PartKeys.front_id(owner.to_s)
          return [nil, nil, 'Zámok sa dá uložiť len na zásuvkovom čele.'] if fid.nil?

          item = Array(cfg['front_items']).find { |f| f.is_a?(Hash) && f['id'].to_s == fid }
          kind, key = Recipes.recipe_key_for(item)
          return [nil, nil, 'Toto čelo nie je klasifikovaná zásuvka — zámok sa uložiť nedá.'] unless kind == :ok

          drawer = item['drawer'].is_a?(Hash) ? item['drawer'] : {}
          state, ref = Recipes.active_ref(drawer['recipe_refs'], key[:system], key[:opening])
          ref = Recipes.pick_ref(drawer['recipe_refs'], key[:system], key[:opening]) if state == :missing
          return [nil, nil, 'Zásuvka má pripnutú verziu receptu, ktorú plugin nepozná.'] if state == :unknown || ref.nil?
          # Identita zamku MUSI sediet s PRIPNUTYM receptom. Nesulad = panel
          # posiela zaznam k inej verzii, nez ktora teraz plati (stary payload).
          return [nil, nil, 'Položka výsuvu sa medzitým zmenila — panel sa obnoví, skús znova.'] \
            unless rid.to_s == "#{RECIPE_RULE_PREFIX}#{ref}"

          recipe = Recipes.load(ref)
          height, why = recipe_result_height(cfg, owner, recipe)
          [recipe, height, nil, why]
        rescue StandardError => e
          Engine.log_error(e, 'Panel.recipe_lock_context')
          [nil, nil, 'Zámok sa nepodarilo overiť proti receptu.', nil]
        end

        # VYSLEDNA vyska zasuvky z CERSTVEHO serveroveho stavu. Quadro vysku
        # nema -> [nil, nil] (os neexistuje, rad NL je jediny).
        # -> [vyska|nil, dovod_ked_nil|nil]
        def recipe_result_height(cfg, owner, recipe)
          return [nil, nil] unless Recipes.atira?(recipe)

          # Svetle rozmery sa citaju RAZ, TOU ISTOU cestou ako payload osi
          # (`drawer_axis_contexts`) — ponuka aj zapis tak stoja na JEDNOM
          # vypocte a nemozu si protirecit.
          ctx = drawer_axis_ctx(cfg, owner)

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
        def recipe_nl_value(cab, owner, rid, nl)
          recipe, height, err, why = recipe_lock_context(cab, owner, rid)
          return [nil, nil, err] if err

          if Recipes.atira?(recipe) && height.nil?
            return [nil, nil, why || 'Výšku zásuvky sa nepodarilo určiť — dĺžka sa uložiť nedá.']
          end

          series = Recipes.series_for(recipe, height)
          unless series.any? { |v| (v.to_f - nl).abs < 0.001 }
            return [nil, nil, "Táto dĺžka nie je v rade #{Recipes.series_label(height)} pripnutého receptu."]
          end

          ['nominal_length', nl, nil]
        end

        # Vyskovy zamok: LEN Atira, hodnota MUSI byt vyskou pripnuteho receptu.
        def recipe_height_value(cab, owner, rid, raw)
          return [nil, nil, 'Výškový zámok sa dá uložiť len na receptovej položke výsuvu.'] unless recipe_rule?(rid)

          hv = Recipes.height_value(raw.is_a?(String) ? Float(raw, exception: false) : raw)
          return [nil, nil, 'Neplatná výška zásuvky.'] if hv.nil?

          # Vyskovy zamok sa ZAPISUJE aj vtedy, ked vysledna vyska urcitelna
          # NIE JE — je to prave cesta, ktorou sa neplatny zamok opravuje.
          recipe, _height, err = recipe_lock_context(cab, owner, rid)
          return [nil, nil, err] if err
          unless Recipes.atira?(recipe)
            return [nil, nil, 'Tento systém zásuviek výškové varianty nemá — výška plynie z rozmeru čela.']
          end

          known = (recipe[:height_variants] || {}).keys.map(&:to_i)
          unless known.include?(hv)
            return [nil, nil, "Recept pozná len výšky #{known.sort.map { |h| "H#{h}" }.join(' · ')}."]
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
