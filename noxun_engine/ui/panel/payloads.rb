# frozen_string_literal: true
# Noxun Engine - Panel: payloady pre JS (korpus, sablony, materialy, karta dielca) + part_key identity.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- payload korpusu -------------------------------------------------
        # Slovenske labely roli dosky (jediny zdroj — JS ich NEduplikuje, Codex audit c).
        BOARD_ROLE_LABELS = { 'free_panel' => 'Voľná doska' }.freeze

        # Karta samostatnej dosky (V0.4.7c). Zdroj = ploche atributy + config na
        # instancii (autoritativny vyrobny zaznam, standard 8.3). edge_labels/sides
        # z AbsRules — jeden zdroj pravdy ako pri karte dielca.
        def board_payload(inst)
          cfg = Store.config(inst) || {}
          role = (Store.get(inst, 'role') || cfg['role']).to_s
          {
            'board_id' => Store.get(inst, 'id'),
            'name' => cfg['name'] || Store.get(inst, 'name'),
            'role' => role,
            'role_label' => BOARD_ROLE_LABELS[role] || role,
            'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'],
            'material_id' => cfg['material_id'],
            # V0.6 M-B1: UNI doska ma hrubku editovatelnu v karte (JS odomkne pole).
            'uni' => (defined?(Materials) && Materials.uni?(Materials.sheet(cfg['material_id'])) ? true : false),
            'grain_direction' => cfg['grain_direction'] || 'none',
            # UI-C1c: umiestnenie dosky pre trojsegment karty. Chybajuce =
            # 'leziaca' (dosky vlozene pred UI-C1c); NEZNAMU hodnotu payload
            # NEPREKLASIFIKUJE — karta ziadny segment nerozsvieti a zapis
            # odmietne serverovy guard (handle_set_board_orientation).
            'orientation' => BoardBuilder.stored_orientation(cfg),
            'orientation_label' => BoardBuilder::ORIENTATION_LABELS[BoardBuilder.stored_orientation(cfg)].to_s,
            'edges' => cfg['edges'].is_a?(Hash) ? cfg['edges'] : {},
            'edge_labels' => AbsRules.edge_labels(role),
            'edge_sides' => AbsRules.edge_sides(role),
            'quantity' => cfg['quantity'] || 1,
            # S1-B2 (R4): TEN ISTY riadok „Spotrebič" ako pri skrinke — doska je
            # plnohodnotny vlastnik (varna doska, drez) a moze ich niest viac
            # naraz. Niku nema, takze sa ponuka nefiltruje a vazba geometriu
            # dosky nemeni (zapis configu bez prestavby, B1).
            'appliance_rows' => appliance_rows('board', cfg, appliance_items(entity_model(inst)),
                                               nil, owner_id: Store.get(inst, 'id').to_s),
            # S1-C: IDENTITA KUSU pre zapis ocakavani. `persistent_id` je
            # jedina vec, ktora prezije recyklaciu vyrobneho ID, takze ho
            # server pri zapise porovnava (payload nesie to, nad cim bol
            # riadok VYKRESLENY).
            'board_pid' => entity_pid(inst)
          }.merge(board_edge_texts(role, cfg)).merge(board_newer_flag(cfg))
        end

        # GHOST-D1 (Codex #298 P2): doska z NOVSEJ verzie pluginu sa v karte
        # zobrazuje READ-ONLY s vysvetlenim (STANDARD 8.3 bod 3). Server je
        # jedina autorita — karta si to z niceho neodvodzuje. Aditivne polia:
        # starsi klient ich ignoruje, novy podla nich zamkne vsetky ovladace.
        # Zapisove cesty su chranene NEZAVISLE (`guarded_board`), takze toto je
        # cisto UX vrstva: pouzivatel ma vidiet PRECO nemoze nic menit.
        def board_newer_flag(cfg)
          return {} unless BoardBuilder.newer_config?(cfg)

          { 'newer_config' => true,
            'newer_config_note' => 'Doska je z novšej verzie Noxun — tento plugin jej nastavenia ' \
                                   'nepozná celé, preto sa nedá upraviť. Aktualizuj plugin.' }
        end

        def cabinet_payload(cab)
          cfg = Store.config(cab) || {}
          params = CabinetBuilder.config_to_params(cfg)
          # D-100: zobrazovany nazov = JEDINY server-side helper (rucny nazov,
          # inak zivy default zo SUCASNYCH parametrov). config_to_params vedome
          # nesie SUROVY ulozeny nazov — je to vstup prestavby, nie popisok;
          # dopocitany default sa nikdy nesmie vratit do configu.
          params['name'] = CabinetBuilder.display_name(cfg)
          params['cabinet_id'] = Store.get(cab, 'cabinet_id')
          params['fronts'] = Fronts.normalize_config(cfg['fronts']) # kanonicke pre riadky cela
          params['zones'] = cfg['zones'] || []                      # ploche zony pre strom + nahlad
          params['front_items'] = cfg['front_items'] || []          # rozlozene cela pre nahlad
          # KOV-A2a: KDE sa smer pyta — SERVER je autorita. Panel z `wings`
          # ani `wings_n` NIKDY neodvodzuje, ci sa ma riadok smeru zobrazit;
          # kresli VYHRADNE to, co je tu. Cista projekcia nad ulozenym
          # `front_items` (ziadny zapis, ziadny prepocet planu).
          params['front_slots'] = front_slots_payload(cfg['front_items'])
          # KOV-D2a: STAV KAZDEJ OSI zamku (vyska, vyska boxu, NL) — server
          # pocita, JS len kresli (chipy su D2b). Mapa sa stavia RAZ a vesia sa
          # na TRI miesta: emitovanu polozku vysuvu, osiroteny riadok zasahu
          # (pri konflikte ziadna polozka nevznikne, ale odomknut sa musi dat)
          # a kartu cela.
          # D-128: index sa pocita UZ TU, lebo riadok karty ho potrebuje —
          # veta detailu nesmie pri aktivnom zamku tvrdit vzorec a veta „ručne
          # zamknuté" musi menovat OSI. Stale je to JEDEN vypocet.
          axis_index = drawer_axes_index(cfg, params)
          axis_by_owner = axis_index['by_owner']
          # KOV-C2c: RIADOK ZASUVKY karty cela (system · vyska · NL · nosnost ·
          # otvaranie · recept, alebo RED dovod / ORANGE sync). Vlastny kluc —
          # `front_slots` odpoveda VYHRADNE na otazku „kde sa pyta smer".
          params['front_drawer'] = front_drawer_payload(cfg, axis_by_owner)
          # KOV-E2: RIADOK VYKLOPU karty cela (system · trieda · tyc, alebo RED
          # dovod / ORANGE upozornenie). Vlastny kluc — `front_drawer` odpoveda
          # VYHRADNE na otazku o zasuvke.
          params['front_lift'] = front_lift_payload(cfg)
          # svetle (available) rozmery — view-only kontrola pre pouzivatela
          params['available_width'] = cfg['available_width']
          params['available_height'] = cfg['available_height']
          params['available_depth'] = cfg['available_depth']
          params['warnings'] = cfg['warnings'] || [] # BuildPlan upozornenia (pre buduce UI)
          # UI-B3: odvodene udaje informacneho stlpca (pocet dielcov + plocha
          # dosky). TRANZIENTNE a CITACIE — ziadna zmena schemy, ziadny zapis;
          # zdroj su snapshoty na dielcoch, rovnaky filter ako ma Bom.collect.
          params.merge!(cabinet_stats(cab))
          params['template_name_suggestion'] = suggest_template_name(cab, nil) # D-14 modal (Codex F4)
          # V0.4 kovanie: vypocitane polozky (vystup planu) + rucne zasahy (identita
          # owner+type+rule_id). hardware_overrides su aj v params (config_to_params),
          # tu explicitne — UI paruje disabled zaznamy na vypnute kategorie.
          # V0.6 C-2 (audit F11): slovensky label TRANZIENTNE v payloade —
          # jedina autorita HardwareRules.label_for (JS mapy su len fallback);
          # do configu/snapshotu sa label NIKDY neuklada.
          # D-93: k polozkam pribuda stav rucnych zasahov po POLIACH (rucny
          # pocet vs. zamok dlzky) + rad NL pre vysuvy.
          params['hardware'] = hardware_override_payload(hardware_items_payload(cfg), cfg, cab)
          # D-92: aj VYPNUTE kategorie (disabled overridy) pomenuva server —
          # inak by jedine ony ostali v sekcii Kovanie so surovym part_key.
          # D-132: klasifikator dostava aj INDEX OSI — z neho vidi, ktory recept
          # je pripnuty a ktore cela vobec existuju, takze rozozna DORMANTNY
          # zamok (zaznam ineho receptu, ktory dnes nikto necita). Je to ten
          # isty index, z ktoreho nizsie vznikaju chipy — ziadny druhy prechod.
          params['hardware_overrides'] = hardware_overrides_payload(cfg, params['hardware_overrides'],
                                                                    axis_index)
          # Aditivne: existujuce `locked` aj `nl` bloky ostavaju nedotknute.
          # Index sa NEPOCITA znova — je to ten isty, z ktoreho uz vyssie
          # vznikol riadok karty (`front_drawer`).
          index = axis_index
          axes = axis_by_owner
          unless axes.empty?
            params['hardware'] = attach_drawer_axes(params['hardware'], axes)
            # KOV-D4: osiroteny zasah dostane chipy LEN ked patri PRIPNUTEMU
            # receptu — preto sa posiela cely `index` (s `idents`), nie len mapa.
            params['hardware_overrides'] = attach_override_axes(params['hardware_overrides'], index)
            params['front_drawer'] = attach_front_drawer_axes(params['front_drawer'], index,
                                                              params['cabinet_id'])
          end
          # KOV-D3b: ponuka novej verzie receptu. Ide MIMO bloku osi — os
          # zasuvka mat nemusi (QUADRO, konflikt), ale ponuka je otazka o mape
          # `recipe_refs`, nie o zamkoch.
          params['front_drawer'] = attach_front_drawer_upgrade(params['front_drawer'], cfg,
                                                               params['cabinet_id'])
          # V0.6 D1b: vyber setu per typ NA SKRINKE (override projektovej
          # predvolby) — ponuka + efektivny stav; server je autorita.
          params['hardware_set_options'] = hardware_set_options(cfg, params['hardware'])
          # KOV-G2 (D-111): riadok „Nohy" v Zakladnych. Text sa sklada z UZ
          # ROZPISANYCH poloziek (`purchase` vyssie), takze riadok a rozklik
          # polozky v Kovani nemozu ukazat ine kody — a katalog sa necita
          # druhy raz. Select setu si riadok berie z `hardware_set_options`.
          params['legs_summary'] = HardwareSets.legs_summary_from_purchase(params['hardware'])
          # KOV-H2: ad-hoc polozky pre UI. `hardware_manual` v `params` uz je —
          # to je SUROVE echo, ktore panel posiela SPAT (pass-through KOV-H1).
          # Tieto dva kluce su NAVIAC a VYHRADNE NA CITANIE: popisky vlastnika,
          # ZIVE ceny katalogu a ponuka dielcov, na ktore sa da polozka pripnut.
          # Panel ich NIKDY neposiela spat (`collectAll` ich nepozna) — inak by
          # sa cena z obrazovky mohla dostat do configu (audit #15 BLOCKER 2).
          #
          # Plan sa stavia RAZ pre oba kluce (`plan_parts_by_key` je cely
          # `build_plan`) — dva samostatne volania by ho postavili dvakrat.
          plan = manual_plan_keys(params)
          params['hardware_manual_view'] = hardware_manual_view(cfg, plan, params['cabinet_id'])
          params['hardware_manual_owners'] = hardware_manual_owners(cfg, plan)
          # S1-B2: RIADOK „Spotrebič" v Zakladnych (viazane modely + nesplnene
          # ocakavania). Polozky zakazky sa citaju RAZ a sluzia obom klucom —
          # riadku aj vystupom slotu (telo z priradeneho modelu).
          appl_items = appliance_items(entity_model(cab))
          slot = cfg['type'].to_s == 'dishwasher'
          params['appliance_rows'] = appliance_rows(slot ? 'slot' : 'cabinet', cfg, appl_items,
                                                    (slot ? nil : appliance_interior(cfg)),
                                                    owner_id: params['cabinet_id'].to_s)
          # S1-C: identita kusu pre zapis ocakavani (viď `board_pid`).
          params['cabinet_pid'] = entity_pid(cab)
          # S1-F: NAHLAD. Server pocita box niky, pasma dveri aj pasmo pripustnej
          # hrany; JS z toho len kresli a odcita popisky (ziadny vypocet v JS).
          params['preview'] = { 'appliances' => appliance_preview(cfg, params['appliance_rows']) }
          # S1-E: VYSTUPY SLOTU (telo, celo hore, vyplň hore, pod doskou,
          # trieda). Pocita ich SERVER — panel z nich nic neodvodzuje, len ich
          # zapisuje do informacneho stlpca. Kluc chyba pri kazdom inom type.
          params['slot'] = slot_payload(cfg, appl_items)
          params
        end

        # === S1-B2: RIADOK „SPOTREBIC" (Zakladne + karta dosky) ==============
        #
        # JEDEN riadok per VIAZANY spotrebic (`appliance_refs[]`) a JEDEN per
        # NESPLNENE OCAKAVANIE (`appliance_expects[]`, slot bez modelu). Riadky
        # sklada SERVER — panel z configu neodvodzuje NIC, ani ponuku modelov.
        #
        # PONUKA je FILTROVANA podla niky vs vnutro skrinky, ale LEN po osiach,
        # ktore dana kategoria naozaj kontroluje (rura a mikrovlnka Š + H — ich
        # vyska je vec zon; chladnicka Š/V/H). Filter NIE JE BRANA: model, ktory
        # nesedi, v ponuke OSTAVA a nesie dovod (mockup R11 — „prepínač všetky
        # ich odkryje aj tak").
        # Codex #384 kolo 1 (P2): OSI aj ich porovnanie ziju v `ApplianceChecks`
        # (S1-F) — druha tabulka tu by znamenala, ze ponuka filtruje podla inych
        # osi, nez ktore vzapati skontroluje Kontrola.
        APPL_PICK_LABEL = 'vyber model…'
        # Vlastnici, u ktorych ma zmysel pytat sa na rozmery niky — TA ISTA
        # mnozina ako `Validation::APPL_NICHE_OWNERS` (doska niku nema).
        APPL_NICHE_KINDS = %w[cabinet slot].freeze

        # Polozky zakazky pre riadok. Cita sa RAZ za payload — je to jeden
        # atribut modelu, nie sken.
        def appliance_items(model)
          return [] unless model && defined?(BudgetStore)

          BudgetStore.appliances(model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.appliance_items')
          []
        end

        # Dokument, do ktoreho entita patri. Autoritou je SAMA ENTITA
        # (`inst.model`) — panel moze kreslit kartu aj v okamihu, ked sa aktivny
        # dokument prepina, a polozky zakazky musia prist z TOHO dokumentu,
        # kde kus stoji. Headless fixtura `model` nema, takze vracia `nil`
        # a riadok sa sklada nad prazdnym zoznamom.
        def entity_model(inst)
          return inst.model if inst.respond_to?(:model)

          nil
        rescue StandardError
          nil
        end

        # S1-C: `persistent_id` kusu. Headless fixtura ho nema, takze payload
        # nesie `nil` a serverovy guard zapis odmietne — presne tak, ako ma
        # (bez identity sa zapisovat neda).
        def entity_pid(inst)
          return nil unless inst.respond_to?(:persistent_id)

          inst.persistent_id
        rescue StandardError
          nil
        end

        # `kind` = 'cabinet' | 'slot' | 'board' (druh VLASTNIKA, nie Store.kind).
        # `owner_id` = vyrobne ID kusu (S1-C: dokaz vazby potrebuje ID, ktore
        # v configu nie je — zije ako atribut instancie).
        def appliance_rows(kind, cfg, items, interior = nil, owner_id: '')
          return [] unless cfg.is_a?(Hash)

          refs = cfg['appliance_refs'].is_a?(Array) ? cfg['appliance_refs'].select { |r| r.is_a?(Hash) } : []
          by_id = {}
          Array(items).each { |it| by_id[it['id'].to_s] = it if it.is_a?(Hash) }
          # S1-F: VYPOCTOVY KONTEXT skrinky sa cita RAZ na payload a sluzi VSETKYM
          # riadkom (dva spotrebice = jeden prepocet ciel).
          ctx = appliance_context(kind, cfg)
          # Codex #385 kolo 1 (P2): mnozinu SPLNENYCH kategorii pocita TA ISTA
          # funkcia ako v zbere (`ApplianceBinding.bound_categories` cez
          # obojsmerny dokaz) — cita ju aj riadok „očakáva", aj popisky volby.
          bound = appliance_expects_bound(kind, refs, items, owner_id)
          rows = refs.filter_map { |ref| appliance_bound_row(kind, cfg, ref, by_id[ref['item_id'].to_s], ctx) }
          rows += appliance_expected_rows(kind, cfg, bound, items, interior, ctx)
          picker = appliance_expects_row(kind, cfg, bound)
          picker ? rows + [picker] : rows
        rescue StandardError => e
          Engine.log_error(e, 'Panel.appliance_rows')
          []
        end

        # === S1-C: RIADOK VOLBY „OCAKAVA" ====================================
        #
        # POSLEDNY riadok bloku Spotrebic — jediny sposob, ako povedat „sem
        # patri rura" BEZ sablony (mockup R10 „Bez spotrebiča riadok ukáže len
        # voľbu očakáva: —"). Kresli sa aj vtedy, ked kus nic neocakava ani
        # nema — inak by sa ocakavanie nedalo zapnut.
        #
        # SLOT ho NEMA: ocakava umyvacku VZDY a menit sa to neda (server to
        # vynucuje aj pri podvrhnutom payloade), takze volba by bola klamstvo.
        # To iste plati o kuse, ktory podla matice nemoze ocakavat NIC.
        #
        # Astra C13: riadok nesie UPLNY aktualny zoznam (`expects`), nie len
        # nesplnene kategorie z riadkov „očakáva" — klient z neho sklada NOVY
        # UPLNY zoznam (pridanie = unia, odstranenie = zoznam bez kategorie)
        # a posiela ho cely. Bez toho by pridanie mikrovlnky ticho zmazalo
        # ocakavanie rury, ktore uz je splnene.
        def appliance_expects_row(kind, cfg, locked)
          return nil unless defined?(ApplianceBinding)
          return nil if kind == ApplianceBinding::KIND_SLOT

          allowed = ApplianceBinding.expectable_categories(kind)
          return nil if allowed.empty?

          have = Array(cfg['appliance_expects']).filter_map { |c| BudgetStore.canon_appliance_type(c) }
          have = allowed.select { |c| have.include?(c) }
          { 'state' => 'expects', 'item_id' => nil, 'category' => nil, 'category_label' => '',
            'text' => appliance_expects_text(have), 'sub' => '', 'tone' => '', 'link' => false,
            'expects' => have, 'placeholder' => appliance_expects_summary_label(have),
            'options' => allowed.map { |cat| appliance_expects_option(cat, have, locked) } }
        end

        def appliance_expects_text(have)
          return 'bez spotrebiča — nastav „očakáva", ak sem spotrebič patrí' if have.empty?

          "očakáva #{have.map { |c| ApplianceCatalog.category_label_acc(c) }.join(', ')}"
        end

        def appliance_expects_summary_label(have)
          return 'očakáva: —' if have.empty?

          "očakáva: #{have.map { |c| ApplianceCatalog.category_label(c).downcase }.join(', ')}"
        end

        # Jedna volba ponuky. `op` je PRIKAZ, nie stav: klient z neho a z
        # `expects` poskladá novy UPLNY zoznam.
        def appliance_expects_option(cat, have, locked)
          on = have.include?(cat)
          label = ApplianceCatalog.category_label(cat).downcase
          if on
            { 'value' => "del:#{cat}", 'code' => cat, 'op' => 'del',
              'text' => (locked.include?(cat) ? "− #{label} (priradená — najprv odpoj)" : "− #{label}"),
              'disabled' => locked.include?(cat) }
          else
            { 'value' => "add:#{cat}", 'code' => cat, 'op' => 'add',
              'text' => "+ #{label}", 'disabled' => false }
          end
        end

        # Kategorie, ktore su na kuse NAOZAJ SPLNENE — obojsmerny dokaz,
        # TA ISTA funkcia, akou ich pocita zber (`ApplianceBinding
        # .bound_categories`). Riadia DVE veci: ktora kategoria uz riadok
        # „očakáva" nepotrebuje a ktoru volbu nemozno odstranit („najprv
        # odpoj"). Branou zapisu ostava server (`appliance_expects_locked`).
        def appliance_expects_bound(kind, refs, items, owner_id)
          entry = { 'kind' => kind, 'id' => owner_id.to_s, 'refs' => refs }
          ApplianceBinding.bound_categories(entry, items)
        rescue StandardError
          []
        end

        # Kontext pre verdikt. Doska ani slot niku nemaju, takze im ostava {}.
        def appliance_context(kind, cfg)
          return {} unless kind == 'cabinet' && defined?(ApplianceChecks)

          ApplianceChecks.context(cfg)
        rescue StandardError
          {}
        end

        def appliance_bound_row(kind, cfg, ref, item, ctx = {})
          cat = BudgetStore.canon_appliance_type(ref['category']).to_s
          return nil if cat.empty?

          id = ref['item_id'].to_s
          check = appliance_check(kind, cat, id, item, ctx)
          tone, sub = appliance_row_tone(kind, cfg, cat, item, check)
          row = { 'state' => 'bound', 'item_id' => id, 'category' => cat,
                  'category_label' => ApplianceCatalog.category_label(cat),
                  # Polozka, ktoru medzitym zmazalo druhe okno, riadok NESKRYVA:
                  # `appliance_refs[]` na entite stale visia a pouzivatel ich musi
                  # vidiet, aby ich vedel odpojit.
                  'text' => (item ? Bom.appliance_label(item) : 'položka už v rozpočte nie je'),
                  'sub' => sub, 'tone' => tone, 'link' => true }
          row['check'] = check if check
          row
        end

        # S1-F: VERDIKT NIKY A DELENIA CIEL pre riadok. Pocita ho `ApplianceChecks`
        # nad zaznamom v TOM ISTOM tvare, aky ma zber (`Bom.collect[:appliances]`)
        # — Kontrola aj Inspector tak hovoria to iste cislo o tej istej skrinke.
        # nil = niet co pocitat (polozka zmizla, doska, slot).
        def appliance_check(kind, category, item_id, item, ctx)
          return nil unless item.is_a?(Hash) && defined?(ApplianceChecks)
          return nil if ctx.nil? || ctx.empty?

          ApplianceChecks.verdict(appliance_check_record(kind, category, item_id, item, ctx))
        rescue StandardError => e
          Engine.log_error(e, 'Panel.appliance_check')
          nil
        end

        def appliance_check_record(kind, category, item_id, item, ctx)
          snap = item['snapshot'].is_a?(Hash) ? item['snapshot'] : {}
          { 'item_id' => item_id, 'name' => Bom.appliance_label(item), 'category' => category,
            'owner' => { 'kind' => kind }, 'state' => 'bound',
            'snapshot' => Bom.appliance_snapshot_dims(snap) }
            .merge(Bom.appliance_front_dims(snap))
            .merge('interior' => ctx['interior'], 'z_lo' => ctx['z_lo'], 'gap' => ctx['gap'],
                   'single_zone' => ctx['single_zone'], 'fronts_pair' => ctx['fronts_pair'])
        end

        # TON riadku. AUTORITA nalezov je `Validation.check_appliance_bound`;
        # panel ju NEVOLA (potrebovala by cely zber modelu), ale pyta sa na
        # PRESNE TIE ISTE VSTUPY — chybajuce rozmery niky, triedu umyvacky vs
        # triedu slotu a (S1-F) verdikt `ApplianceChecks`. Test
        # `test_s1b2_pohlad.rb` a `test_s1f_chladnicka.rb` porovnavaju oba smery
        # nad jednou fixturou, takze sa nemozu rozist ticho.
        def appliance_row_tone(kind, cfg, category, item, check = nil)
          label = ApplianceCatalog.category_label(category).to_s
          return ['warn', 'položka už v rozpočte nie je — odpoj ju'] if item.nil?

          snap = item['snapshot'].is_a?(Hash) ? item['snapshot'] : {}
          dims = snap['dims'].is_a?(Hash) ? snap['dims'] : {}
          if APPL_NICHE_KINDS.include?(kind) && !dims['niche'].is_a?(Hash)
            return ['warn', "#{label} · chýbajú údaje niky — kontrola sa nedá urobiť"]
          end

          mis = appliance_class_mismatch(kind, cfg, dims)
          return ['warn', "#{label} · #{mis}"] if mis

          verdict = check.is_a?(Hash) ? check : nil
          return ['ok', label] if verdict.nil? || verdict['text'].to_s.strip.empty?

          # ORANGE ma riadok LEN pri `clash` / `unsatisfiable` — presne tam, kde
          # nalez vyrobi aj Kontrola (FIX F7). „Nevieme" a „nekontrolované" su
          # informacia, nie varovanie.
          warn = %w[clash unsatisfiable].include?(verdict['state'].to_s)
          [(warn ? 'warn' : 'ok'), "#{label} · #{verdict['text']}"]
        end

        # Trieda modelu vs trieda slotu. Neznama trieda je „nevieme", nie
        # „nesedi" (rovnaka zasada ako vo `Validation`).
        def appliance_class_mismatch(kind, cfg, dims)
          return nil unless kind == 'slot'

          install = dims['install'].is_a?(Hash) ? dims['install'] : {}
          model_cls = install['dishwasher_class'].to_s
          slot_cls = cfg['dw_class'].to_i
          return nil if model_cls.empty? || !slot_cls.positive?
          return nil if model_cls == slot_cls.to_s

          "trieda #{model_cls} ≠ slot #{slot_cls}"
        end

        # `bound` = kategorie, ktore su NAOZAJ splnene (obojsmerny dokaz).
        #
        # Codex #385 kolo 1 (P2): doteraz sa tu bralo samotne `ref['category']`,
        # takze OSIROTENY zaznam (polozka zmizla) alebo ref po RECYKLOVANOM ID
        # riadok „očakáva" POTLACIL — a s nim aj vyber modelu. Kontrola pritom
        # (spravne) hlasila `appliance_missing` a pouzivatel nemal kde ho
        # vybavit. Panel a Kontrola preto citaju jednu a tu istu mnozinu.
        def appliance_expected_rows(kind, cfg, bound, items, interior, ctx = {})
          cats = Array(cfg['appliance_expects']).filter_map { |c| BudgetStore.canon_appliance_type(c) }
          # Slot BEZ modelu ocakava umyvacku vzdy — je to jeho jediny zmysel
          # (to iste hovori `Bom.appliance_expected_records`).
          cats << 'dishwasher' if kind == 'slot'
          have = Array(bound).map(&:to_s)
          single = ctx.is_a?(Hash) && ctx.key?('single_zone') ? ctx['single_zone'] != false : true
          cats.uniq.reject { |c| have.include?(c) }.map do |cat|
            appliance_expected_row(cat, items, interior, single)
          end
        end

        def appliance_expected_row(category, items, interior, single_zone)
          label = ApplianceCatalog.category_label(category).to_s
          ambiguous = appliance_niche_ambiguous?(category, single_zone)
          opts = appliance_options(category, items, ambiguous ? nil : interior)
          off = opts.count { |o| o['fits'] == false }
          { 'state' => 'expected', 'item_id' => nil, 'category' => category,
            'category_label' => label,
            'text' => "očakáva: #{label.downcase}",
            'sub' => appliance_expected_sub(opts, ambiguous),
            'tone' => 'warn', 'link' => true,
            'placeholder' => APPL_PICK_LABEL,
            'options' => opts,
            # „— zobraziť všetky (N)" je PRIZNANIE, ze filter nie je brana:
            # modely, ktore nesedia, su v ponuke tiez (mockup R11).
            'all' => off.positive?, 'all_note' => (off.positive? ? "— zobraziť všetky (#{off})" : '') }
        end

        def appliance_expected_sub(opts, ambiguous)
          return 'nika je nejednoznačná (viac zón) — ponuka sa nefiltruje' if ambiguous
          return 'zákazka zatiaľ taký spotrebič nemá — pridaj ho v Štúdiu' if opts.empty?

          fit = opts.count { |o| o['fits'] != false }
          "#{fit} z #{opts.length} sa zmestí do niky"
        end

        # Nika je NEJEDNOZNACNA, ked kategoria kontroluje VYSKU a skrinka ma
        # viac zon: vtedy neexistuje jedno „vnutro", proti ktoremu by sa dala
        # vyska merat. Sirka a hlbka su jednoznacne vzdy, takze rura ani
        # mikrovlnka filter nestracaju.
        #
        # S1-F: „jedna zona" ma JEDEN predikat pre filter ponuky aj pre verdikt
        # (`ApplianceChecks.single_zone?`) — inak by ponuka filtrovala podla
        # vysky, ktoru verdikt vzapati oznaci za nekontrolovatelnu.
        def appliance_niche_ambiguous?(category, single_zone)
          return false unless appliance_axes(category).include?('height')

          single_zone == false
        end

        def appliance_options(category, items, interior)
          list = Array(items).select do |it|
            next false unless it.is_a?(Hash)
            next false unless BudgetStore.canon_appliance_type(it['typ']).to_s == category

            BudgetStore.owner_field(it['owner'])['kind'].to_s == ApplianceBinding::KIND_JOB
          end
          rows = list.map { |it| appliance_option(it, category, interior) }
          # PORADIE je kontrakt: najprv to, co sa zmesti (kliknutim nahodne
          # vybrana prva volba tak nikdy nie je model, o ktorom vieme, ze
          # nesedi), potom zvysok. V ramci skupiny podla nazvu.
          rows.sort_by.with_index { |o, i| [o['fits'] == false ? 1 : 0, o['text'].to_s.downcase, i] }
        end

        def appliance_option(item, category, interior)
          reason = appliance_fit_reason(item, category, interior)
          text = Bom.appliance_label(item)
          { 'item_id' => item['id'].to_s, 'fits' => reason.nil?,
            'text' => (reason.nil? ? text : "#{text} (nesedí: #{reason})"),
            'hint' => reason.to_s }
        end

        # OSI, ktore dana kategoria kontroluje. Autoritou je `ApplianceChecks`
        # (jedna tabulka pre ponuku aj pre verdikt).
        def appliance_axes(category)
          return [] unless defined?(ApplianceChecks)

          Array(ApplianceChecks::AXES[category.to_s])
        end

        # PRVY dovod, preco sa model do niky nezmesti (nil = zmesti sa alebo
        # sa to neda povedat). Kontroluju sa LEN osi danej kategorie a LEN tie,
        # ktore list naozaj kotuje.
        def appliance_fit_reason(item, category, interior)
          return nil unless interior.is_a?(Hash)

          axes = appliance_axes(category)
          return nil if axes.empty?

          snap = item['snapshot'].is_a?(Hash) ? item['snapshot'] : {}
          dims = snap['dims'].is_a?(Hash) ? snap['dims'] : {}
          niche = dims['niche'].is_a?(Hash) ? dims['niche'] : nil
          return nil if niche.nil?

          axes.each do |axis|
            r = appliance_axis_reason(axis, niche, interior[axis])
            return r if r
          end
          nil
        end

        # Codex #384 kolo 1 (P2): porovnanie osi ma JEDNO miesto —
        # `ApplianceChecks.axis_reason`. Kym tu zilo vlastne (tolerancia 0,5 mm)
        # a vo verdikte druhe (0,01 mm), ponuka model odporucila ako sediaci
        # a Kontrola ho vzapati zhodila ORANGE.
        def appliance_axis_reason(axis, niche, have)
          return nil unless defined?(ApplianceChecks)

          ApplianceChecks.axis_reason(axis, niche, have)
        end

        # === S1-F: NAHLAD KONTROLNEJ GEOMETRIE (kontext Korpus) ==============
        #
        # KOLEKCIA (FIX F10) adresovana `item_id` — skrinka moze niest viac
        # chladniciek a kazda ma vlastny box, vlastne pasma a vlastne pasmo
        # hrany. Geometriu dava TA ISTA funkcia, z ktorej kresli builder
        # (`Construction.appliance_niche_references`), takze nahlad a model sa
        # nemozu rozist; pasma a hrana su v suradniciach KORPUSU (z od podlahy),
        # aby JS nemuselo nic scitavat.
        def appliance_preview(cfg, rows)
          return [] unless cfg.is_a?(Hash) && defined?(Construction)
          return [] unless cfg['appliance_refs'].is_a?(Array)

          checks = {}
          Array(rows).each { |r| checks[r['item_id'].to_s] = r['check'] if r.is_a?(Hash) }
          refs = Construction.appliance_niche_references(cfg.transform_keys(&:to_sym))
          refs.map { |rd| appliance_preview_item(rd, checks[rd[:item_id].to_s]) }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.appliance_preview')
          []
        end

        def appliance_preview_item(rd, check)
          w, _d, h = rd[:box].map(&:to_f)
          ox, _oy, oz = rd[:origin].map(&:to_f)
          split = check.is_a?(Hash) ? check['door_split'] : nil
          { 'item_id' => rd[:item_id].to_s, 'label' => rd[:label].to_s,
            'box' => { 'x' => ox.round(2), 'z' => oz.round(2),
                       'w' => w.round(2), 'h' => h.round(2) },
            'bands' => appliance_preview_bands(rd, oz, h),
            'split' => appliance_preview_split(split, oz),
            'state' => (check.is_a?(Hash) ? check['state'].to_s : 'unknown') }
        end

        # Pasma dveri SPOTREBICA: hrany v suradniciach korpusu + vyska pasma
        # (popis „669", „71", zvysok). Pasmo, ktore by presiahlo box, sa oreze —
        # box sa kvoli listu nikdy nezvacsuje.
        #
        # Codex #384 kolo 1 (P2): zaznam BEZ pouzitelnych pasiem = PRAZDNY
        # ZOZNAM, nie jedno vymyslene pasmo cez cely box. Renderer modelu
        # (`draw_reference_niche`) vtedy nekresli ziadnu ciaru a nahlad musi
        # hovorit to iste — inak by pri modeli bez udajov o dverach ukazoval
        # popisok „1940", ktory v modeli nikde nie je.
        def appliance_preview_bands(rd, z0, h)
          levels = CabinetBuilder.niche_band_levels(rd[:bands].is_a?(Hash) ? rd[:bands] : {})
          return [] if levels.empty?

          edges = ([0.0] + levels + [h]).map(&:to_f).select { |v| v >= -0.01 && v <= h + 0.01 }
          edges = edges.uniq.sort
          out = []
          edges.each_cons(2) do |a, b|
            next unless (b - a) > 0.01

            out << { 'z0' => (z0 + a).round(2), 'z1' => (z0 + b).round(2),
                     'size' => (b - a).round(1) }
          end
          out
        end

        def appliance_preview_split(split, z0)
          return nil unless split.is_a?(Hash)
          return nil unless %w[ok clash].include?(split['state'].to_s)

          lo, hi = Array(split['range'])
          { 'state' => split['state'].to_s,
            'lo' => (lo.is_a?(Numeric) ? (z0 + lo).round(2) : nil),
            'hi' => (hi.is_a?(Numeric) ? (z0 + hi).round(2) : nil),
            'edge' => (split['edge'].is_a?(Numeric) ? (z0 + split['edge']).round(2) : nil),
            'recommended' => (split['recommended'].is_a?(Numeric) ? (z0 + split['recommended']).round(2) : nil),
            'lo_mm' => (lo.is_a?(Numeric) ? lo.round(1) : nil),
            'hi_mm' => (hi.is_a?(Numeric) ? hi.round(1) : nil),
            'edge_mm' => (split['edge'].is_a?(Numeric) ? split['edge'].round(1) : nil) }
        end

        # Vnutro skrinky pre filter. JEDINA autorita rozmerov vnutra je
        # `Construction.interior_dims` — vlastny vypocet by bol druha pravda
        # o tom, kam sa spotrebic zmesti (rovnaky vzor ako `Bom.interior_of`).
        def appliance_interior(cfg)
          return nil unless cfg.is_a?(Hash) && defined?(Construction)

          dims = Construction.interior_dims(cfg.transform_keys(&:to_sym))
          return nil unless dims.is_a?(Hash)

          t = cfg['thickness'].to_f
          { 'width' => (cfg['width'].to_f - (2 * t)).round(2),
            'height' => dims[:avail_h].to_f.round(2),
            'depth' => dims[:back_front_y].to_f.round(2) }
        rescue StandardError
          nil
        end

        # --- S1-E: informacny stlpec slotu umyvacky --------------------------
        #
        # CISTA projekcia nad ULOZENYM configom (ziadny plan, ziadny zapis).
        # „Pod doskou" pouziva TEN ISTY predikat ako Kontrola `dw_height_fit`
        # (nastavena vyska tela vs vyska linky) — Inspector a semafor nesmu
        # tvrdit dve rozne veci (Astra S1-E FIX E11).
        def slot_payload(cfg, items = nil)
          return nil unless cfg.is_a?(Hash) && cfg['type'].to_s == 'dishwasher'

          # S1-B2: telo je z PRIRADENEHO modelu, ak nejaky je — a rozhoduje
          # o tom JEDNA funkcia pre model aj pre cisla (`Construction.dw_body_dims`).
          body = Construction.dw_body_dims(cfg)
          item = slot_appliance_item(cfg, items)
          bh = cfg['dw_body_height'].to_f
          line = cfg['height'].to_f
          top = cfg['dw_front_bottom'].to_f + cfg['dw_front_height'].to_f
          over = top - bh
          fill = line - top
          under = bh <= line + 0.01
          { 'body' => "#{fmt_mm(body[:w])} × #{fmt_mm(bh)} × #{fmt_mm(body[:d])}",
            'body_note' => slot_body_note(body, item),
            'body_source' => body[:source],
            'body_range' => slot_body_range(item),
            'front_top' => fmt_mm(top),
            'front_over' => over,
            'front_over_text' => "#{over.negative? ? '' : '+'}#{fmt_mm(over)} nad telom",
            'fill' => fmt_mm(fill),
            'under_ok' => under,
            'under_text' => "#{fmt_mm(line)} #{under ? '≥' : '<'} #{fmt_mm(bh)}",
            'class_state' => slot_class_state(cfg, item),
            'class_text' => slot_class_text(cfg, body, item) }
        end

        # Odkial su rozmery tela. Vazba BEZ polozky (druhe okno ju medzitym
        # zmazalo) sa NEVYDAVA za generiku — telo je stale z katalogu, len sa
        # uz nema ako volat.
        def slot_body_note(body, item)
          name = item ? Bom.appliance_label(item).to_s : ''
          return name unless name.empty?
          return 'z katalógu (položka už v rozpočte nie je)' if body[:source] == 'catalog'

          "generické #{body[:label]}"
        end

        # Polozka zakazky, ktora v TOMTO slote stoji (vazba je v configu).
        def slot_appliance_item(cfg, items)
          ref = Construction.dw_appliance_ref(cfg)
          return nil unless ref.is_a?(Hash)

          id = ref['item_id'].to_s
          Array(items).find { |it| it.is_a?(Hash) && it['id'].to_s == id }
        end

        # Rozsah vysky tela z LISTU vyrobcu (nastavitelne nohy). Je to HINT
        # k polu „Telo V", nie kontrola — vstup ohranicuje pouzivatel.
        def slot_body_range(item)
          return '' unless item.is_a?(Hash)

          snap = item['snapshot'].is_a?(Hash) ? item['snapshot'] : {}
          dims = snap['dims'].is_a?(Hash) ? snap['dims'] : {}
          inst = dims['install'].is_a?(Hash) ? dims['install'] : {}
          lo = inst['body_height_min']
          hi = inst['body_height_max']
          return '' unless lo.is_a?(Numeric) || hi.is_a?(Numeric)
          return "list #{fmt_mm(lo)}–#{fmt_mm(hi)}" if lo.is_a?(Numeric) && hi.is_a?(Numeric)
          return "list od #{fmt_mm(lo)}" if lo.is_a?(Numeric)

          "list do #{fmt_mm(hi)}"
        end

        # Trieda slotu vs trieda modelu — TRI STAVY, nie dva (Codex #383 kolo 1
        # P2): bez modelu a pri modeli, ktorého list triedu NEKÓTUJE, sa
        # netvrdí nič (`unknown`). Binárne „ok" by Inspector zafarbil nazeleno
        # nad vetou „trieda neuvedená" — teda by tvrdil overenie, ktoré sa
        # nestalo. „Nevieme" nie je „nesedí" ani „sedí" (zhoda s `Validation`,
        # ktorá pri neznámej triede nález nevydá).
        # -> 'ok' | 'mismatch' | 'unknown'
        def slot_class_state(cfg, item)
          return 'unknown' if item.nil?
          return 'unknown' if slot_class_code(item).empty?

          appliance_class_mismatch('slot', cfg, slot_item_dims(item)).nil? ? 'ok' : 'mismatch'
        end

        def slot_class_code(item)
          install = slot_item_dims(item)['install']
          install.is_a?(Hash) ? install['dishwasher_class'].to_s : ''
        end

        def slot_class_text(cfg, body, item)
          return "#{body[:label]} · bez modelu" if item.nil?

          name = Bom.appliance_label(item)
          state = slot_class_state(cfg, item)
          return "#{body[:label]} · #{name} (trieda neuvedená)" if state == 'unknown'

          "#{body[:label]} · #{name} #{state == 'ok' ? '✓' : '✗'}"
        end

        def slot_item_dims(item)
          snap = item.is_a?(Hash) && item['snapshot'].is_a?(Hash) ? item['snapshot'] : {}
          snap['dims'].is_a?(Hash) ? snap['dims'] : {}
        end

        # --- KOV-H2: ad-hoc polozky pre UI Inspectora ------------------------
        #
        # `celá skrinka` = polozka BEZ vlastnika. Text je SERVEROVY (JS ho
        # neskladá) a je to ten isty retazec v ponuke aj v riadku.
        MANUAL_CAB_LABEL = 'celá skrinka'
        # Ponukaju sa LEN cela a zonove dielce. Korpusove dielce (boky, dno,
        # strop, chrbat, sokel) sa NEponukaju vedome: „uholnik patri k lavemu
        # boku" nie je informacia, ktoru by vyroba alebo nakup vedeli pouzit —
        # a zoznam by narastol o osem poloziek, v ktorych sa to podstatne straca.
        MANUAL_OWNER_PREFIXES = %w[front: zone:].freeze

        # Mapa part_key -> deskriptor AKTUALNEHO planu skrinky (alebo prazdna).
        def manual_plan_keys(params)
          CabinetBuilder.plan_parts_by_key(params)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.manual_plan_keys')
          {}
        end

        # Riadky ad-hoc poloziek TAK, AKO SA KRESLIA: popis vlastnika, ZIVY
        # nazov a cena z katalogu, priznaky „dielec uz neexistuje" a „kod uz
        # nie je v katalogu". Cena katalogovej polozky sa v configu NEUKLADA
        # (KOV-H1 BLOCKER 2), takze ju MUSI dodat tento payload — inak by
        # riadok v paneli nemal co ukazat.
        def hardware_manual_view(cfg, plan, cab_id)
          items = cfg['hardware_manual'].is_a?(Array) ? cfg['hardware_manual'] : []
          return [] if items.empty?

          fronts = payload_fronts(cfg)
          # `owner_missing` pocita JEDINA existujuca cista funkcia (Bom) —
          # druha kopia tej istej podmienky by sa casom rozisla s Kontrolou.
          Bom.manual_items_for(cab_id, nil, items, plan).map do |it|
            manual_view_row(it, fronts)
          end
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hardware_manual_view')
          []
        end

        def manual_view_row(it, fronts)
          src = it['source'].to_s
          code = it['code'].to_s
          item = (src == 'catalog' && !code.empty? && defined?(HardwareCatalog)) ? HardwareCatalog.find(code) : nil
          missing = src == 'catalog' && item.nil?
          { 'id' => it['id'].to_s,
            'owner_part_key' => it['owner_part_key'],
            'owner_label' => PartKeys.human_label(it['owner_part_key'], fronts: fronts),
            'owner_missing' => it['owner_missing'] == true,
            'source' => src,
            'code' => code,
            # Pri katalogovej polozke je autoritou ZIVY katalog; snapshot
            # z configu sa pouzije az vtedy, ked kod z katalogu zmizol.
            'name' => (item.is_a?(Hash) ? item['name_sk'].to_s : it['name'].to_s),
            'unit' => (item.is_a?(Hash) ? item['unit'].to_s : it['unit'].to_s),
            'price_eur_vat' => manual_view_price(it, item, src),
            'qty' => it['qty'].to_i,
            'note' => it['note'].to_s,
            'catalog_missing' => missing }
        end

        # Cena: volna polozka ma vlastnu (zadal ju clovek), katalogova ZIVU
        # z katalogu. Chybajuci kod = nil („bez ceny"), NIKDY 0 (standard §11.3).
        def manual_view_price(it, item, src)
          if src == 'free'
            return it['price_eur_vat'].is_a?(Numeric) ? it['price_eur_vat'].to_f : nil
          end
          return nil unless item.is_a?(Hash)

          item['price_eur_vat'].is_a?(Numeric) ? item['price_eur_vat'].to_f : nil
        end

        # Ponuka „Patrí k" pre modal: celá skrinka + KAZDY dielec planu, ktoreho
        # popis vie server naozaj zlozit. Surovy kluc sa NEPONUKA — v ponuke by
        # vyzeral ako nazov a pritom by nepovedal nic (rovnaka zasada ako
        # `hwGroupTitle` v paneli).
        def hardware_manual_owners(cfg, plan)
          fronts = payload_fronts(cfg)
          out = [{ 'key' => nil, 'label' => MANUAL_CAB_LABEL }]
          plan.keys.each do |raw|
            key = raw.to_s
            next unless MANUAL_OWNER_PREFIXES.any? { |p| key.start_with?(p) }

            label = PartKeys.human_label(key, fronts: fronts).to_s
            next if label.empty? || label == key

            out << { 'key' => key, 'label' => label }
          end
          disambiguate_owner_labels!(out)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hardware_manual_owners')
          [{ 'key' => nil, 'label' => MANUAL_CAB_LABEL }]
        end

        # Codex #285 P2-C: `zone:ZA/shelf:1` aj `zone:ZB/shelf:1` daju „Polica 1"
        # — v ponuke „Patrí k" by tak stali DVE identicke volby a pouzivatel by
        # nevedel, ktory dielec pripina.
        #
        # Rozlisenie sa dopĺňa LEN tam, kde je popis naozaj DVOJZNACNY (a LEN
        # v tejto ponuke — `PartKeys.human_label` sa nemeni, ma inych citatelov:
        # riadky kovania, Kontrolu, povod v Nakupe). Jednoznacne popisy ostavaju
        # holé; zdrojom prívesku je SEGMENT KLUCA (id zony), nikdy vymysleny text.
        # CISTA funkcia — vstup MENI a vracia ho.
        def disambiguate_owner_labels!(list)
          counts = Hash.new(0)
          list.each { |o| counts[o['label']] += 1 }
          list.each do |o|
            next if counts[o['label']] < 2

            zone = owner_zone_id(o['key'])
            next if zone.nil?

            o['label'] = "#{o['label']} · zóna #{zone}"
          end
          list
        end

        # Id zony z kluca dielca (`zone:Z2/shelf:1` -> „Z2"), inak nil.
        def owner_zone_id(key)
          m = key.to_s.match(%r{\Azone:([^/]+)/})
          m ? m[1] : nil
        end

        # KOV-A2a: mapa `front_id -> { 'wings_n' =>, 'slots' => [...] }` z JEDINEJ
        # definicie aplikovatelnosti smeru (`Fronts.direction_slots`, KOV-A1).
        #   `slots` neprazdne = presne tie kridla, na ktore sa smer PYTA
        #   `slots` prazdne   = tu sa smer nepyta (dvojkridlo, zasuvka, vyklop,
        #                       sklop, blenda, „Bez cela")
        #   `state` nil       = LEGACY (kluc v configu nie je) — segrow bez
        #                       aktivnej volby a BEZ nalezu; NIKDY sa nedopĺňa
        # Codex #281 P2-A: `wings_n` ide von SPOLU so slotmi, lebo prazdne pole
        # samo o sebe NEZNAMENA dvojkridlo — da ho aj velmi stary `front_items`
        # (pred D-07, bez `wings_n`), kde server o pocte kridiel nevie NIC.
        # Bez tohto rozlisenia by karta nad starym cache tvrdila „Dvojkrídlo…",
        # co je lož. `nil` = neznamy pocet -> panel mlci.
        # Kluce su STRINGY (JSON do panela); symbolove kluce slotu sa prekladaju
        # TU, aby si JS nemusel pamatat dva tvary.
        def front_slots_payload(front_items)
          out = {}
          Array(front_items).each do |it|
            next unless it.is_a?(Hash)

            fid = it['id'].to_s
            next if fid.empty?

            wn = it['wings_n'].to_i
            slots = Fronts.direction_slots(it).map do |s|
              { 'wing' => s[:wing].to_s, 'part_key' => s[:part_key].to_s, 'state' => s[:state] }
            end
            out[fid] = { 'wings_n' => (wn.positive? ? wn : nil), 'slots' => slots }
          end
          out
        end

        # --- KOV-C2c: RIADOK ZASUVKY v karte cela -----------------------------
        #
        # Mapa `front_id => zaznam` pre cela, ktore su KLASIFIKOVANE ako zasuvka
        # (`Recipes.classified?`). Karta z nej kresli JEDEN read-only riadok —
        # ziadny novy vertikalny blok (vertikalny priestor panela je vzacny).
        #
        # SERVER je jedina autorita: text riadku aj vety detailu sa skladaju TU,
        # panel ich len vypise (`esc`). Vsetko je CITACIE — ziadny zapis, ziadna
        # zmena schemy; zdroje su ULOZENY config (polozka vysuvu `source:
        # 'recipe'`, `drawer_conflicts`, `warnings`) a datovy pack receptov.
        #
        # Stavy zaznamu (`state`):
        #   'ok'       — zasuvka je vyriesena; `text` = zhrnutie, `detail` = vety
        #                receptu (rozbalitelne), `sync` = ORANGE odporucanie
        #   'conflict' — fail-closed dovod zo stavby; `message` = veta stavby
        #   'stale'    — skrinka je ulozena PRED aktivaciou receptov (schema < 5),
        #                takze polozka vysuvu v configu chyba; naprava = prestavba
        #   'pending'  — klasifikovane celo bez polozky aj bez dovodu (napr.
        #                konstrukcia, ktoru recepty neriesia) — karta mlci
        DRAWER_SYNC_CODE = 'drawer_sync_recommended'

        # D-128: `axes_by_owner` = stav osi zamku (`drawer_axes_index`), aby
        # riadok karty nemusel tvrdit vzorec pri AKTIVNOM zamku vysky boxu
        # a aby veta „ručne zamknuté" menovala PRAVE zamknute osi. Prazdna mapa
        # = spravanie spred D-128 (starsi volajuci, test).
        def front_drawer_payload(cfg, axes_by_owner = {})
          return {} unless defined?(Recipes)

          axes = axes_by_owner.is_a?(Hash) ? axes_by_owner : {}
          out = {}
          # KOV-D1b: „co je v balení" sa cita RAZ pre cely payload (stav setov +
          # mapa kod => polozka katalogu) — nie per celo. Cesta je CITACIA
          # (rovnaka ako D-92 riadok nakupu), takze karta a supis hovoria to iste.
          buy = nil
          Array(cfg['front_items']).each do |it|
            next unless it.is_a?(Hash) && Recipes.classified?(it)

            fid = it['id'].to_s
            next if fid.empty?

            buy = drawer_buy_ctx(cfg) if buy.nil?
            out[fid] = drawer_card_row(cfg, fid, buy, axes[PartKeys.front(fid, 'panel')])
          end
          out
        rescue StandardError => e
          Engine.log_error(e, 'Panel.front_drawer_payload')
          {}
        end

        # Kontext rozpisu nakupu pre karty zasuviek — postaveny RAZ.
        #
        # R-07 (Codex #310 kolo 1 P2-1): detail sa musi spravat PRESNE ako
        # nakupny riadok (`decorate_hardware_purchase`) a ako supis. Pri projekte
        # BEZ snapshotu a NEKOMPATIBILNEJ kniznici sa override skrinky
        # NEUPLATNUJE (ukazuje na set_id, ktoreho definicia by musela prist prave
        # z tej kniznice) a dovod je `library_incompatible`. Bez toho by rozklik
        # hlasil „chýba mapovanie" a navadzal na „Doplniť nové predvoľby" —
        # cestu, ktora sa v tomto stave otvorit neda — kym Nakup vedla hovori
        # pravdu (lekcia R-06a „panel a supis sa nesmu rozist").
        def drawer_buy_ctx(cfg)
          status, state = hardware_read_state
          blocked = status == :missing && HardwareSets.library_read_only?
          { 'status' => status, 'state' => state,
            'overrides' => (blocked ? {} : cabinet_set_overrides(cfg)),
            'blocked' => blocked,
            'lookup' => HardwareSets.catalog_lookup(HardwareCatalog.items) }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.drawer_buy_ctx')
          nil
        end

        def drawer_card_row(cfg, fid, buy = nil, axes = nil)
          conflict = drawer_conflict_for(cfg, fid)
          return { 'state' => 'conflict', 'message' => conflict['message'].to_s } if conflict

          hw = drawer_item_for(cfg, fid)
          if hw.nil?
            return { 'state' => 'stale' } if drawer_stale_cfg?(cfg)

            return { 'state' => 'pending' }
          end
          params = hw['params'].is_a?(Hash) ? hw['params'] : {}
          row = { 'state' => 'ok', 'text' => drawer_row_text(params),
                  'detail' => Recipes.explain_stored(params, axes: axes) + drawer_buy_lines(hw, buy) }
          note = locked_note(hw, axes)
          row['locked_note'] = note if note
          sync = drawer_sync_note(cfg, fid)
          row['sync'] = sync if sync
          row
        end

        # D-128: veta „ručne zamknuté" MENUJE OSI. Do D-128 tvrdila „Dĺžka
        # výsuvu je ručne zamknutá" pri KAZDOM `locked: true` — pri samotnom
        # zamku vysky boxu (alebo vyskoveho variantu) teda menovala INU os,
        # nez ktora je naozaj zamknuta.
        #
        # Zdroj je `axes` (ten isty stav, akym sa kreslia chipy), nie `locked`
        # boolean. Ked osi k dispozicii NIE SU (nenacitatelny recept, celo bez
        # kontextu), ostava PRIZNANIE bez menovania — tichy vypadok vety by
        # zamok skryl.
        LOCKED_AXIS_LABELS = { 'height' => 'výška zásuvky', 'box' => 'výška boxu',
                               'nl' => 'dĺžka výsuvu' }.freeze
        LOCKED_NOTE_TAIL = '(Inspector → Kovanie).'

        def locked_note(hw, axes)
          named = axes.is_a?(Hash) ? LOCKED_AXIS_LABELS.keys.select { |k| locked_axis?(axes[k]) } : []
          unless named.empty?
            return "Ručne zamknuté: #{named.map { |k| LOCKED_AXIS_LABELS[k] }.join(' · ')} #{LOCKED_NOTE_TAIL}"
          end
          return nil unless hw.is_a?(Hash) && hw['locked'] == true
          # Osi nepoznáme, ale polozka zamok priznava — radsej vseobecna veta
          # nez ziadna.
          return nil if axes.is_a?(Hash)

          "Ručne zamknuté #{LOCKED_NOTE_TAIL}"
        end

        def locked_axis?(ax)
          ax.is_a?(Hash) && %w[locked conflict].include?(ax['state'].to_s)
        end

        # KOV-D1b: „ČO JE V BALENÍ" — vety pod technickym detailom karty.
        # Zdroj je JEDINY existujuci rozpis (`HardwareSets.explain`), ten isty,
        # ktory kresli nakupny riadok D-92 a z ktoreho vznika supis — karta
        # NEPOCITA nic vlastne (Astra #20 N16: ziadny druhy explain, ziadny
        # novy snapshot). Bez kontextu (nedostupny stav setov) sa NEPRIDA NIC:
        # radsej ziadna veta nez veta, ktora sa moze rozist s Nakupom.
        #
        # NOSNOST tu NIE JE a byt nesmie — tu vydava VYHRADNE recept
        # (`explain_stored`, riadok „Nosnosť bunky"). Nakupna volba setu ju
        # NEZVYSUJE (Astra #20 F11).
        def drawer_buy_lines(hw, buy)
          buy_lines(item_expansion(hw, buy))
        end

        # KOV-E2 (Codex #334 kolo 2 P2): EXPANZIA POLOZKY sa pocita RAZ.
        # Karta vyklopu z nej potrebuje OBOJE — vety rozkliku aj to, ci
        # expanzia ZLYHALA (stav karty) — a dva behy tej istej expanzie by
        # boli nielen zbytocne, ale aj miesto, kde sa vety a stav mozu
        # rozist. `nil` = expanziu sa nepodarilo ziskat (chybajuci kontext
        # setov alebo chyba): vtedy sa NEPRIDA a NETVRDI nic.
        def item_expansion(hw, buy)
          return nil unless buy.is_a?(Hash) && hw.is_a?(Hash)

          item_purchase(hw, buy['status'], buy['state'], buy['overrides'], buy['lookup'],
                        blocked: buy['blocked'] == true)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.item_expansion')
          nil
        end

        def buy_lines(exp)
          return [] unless exp.is_a?(Hash)

          out = []
          out << "Balenie: #{exp['set_name'] || exp['set_id']}" if exp['set_name'] || exp['set_id']
          Array(exp['members']).each { |m| out << drawer_member_line(m) }
          Array(exp['problems']).each { |p| out << "Bez kódu: #{p}" }
          out
        rescue StandardError => e
          Engine.log_error(e, 'Panel.buy_lines')
          []
        end

        # „· K-sada 357696 — Súprava Atira … (1 ks)". Nazov chybajuci
        # v katalogu sa PRIZNA, nikdy sa nenahradi vymyslenym textom.
        def drawer_member_line(m)
          label = m['label'].to_s.strip
          name = m['missing'] ? 'mimo katalógu' : m['name'].to_s
          parts = ["· #{label.empty? ? 'položka' : label}", m['code'].to_s]
          parts << "— #{name}" unless name.empty?
          "#{parts.join(' ')} (#{m['qty']} ks)"
        end

        # Zhrnutie do JEDNEHO riadku: „Atira · H70 · NL 470 · 30 kg · SiSy ·
        # recept v1". Kazdy udaj pochadza z ULOZENYCH `params` polozky vysuvu —
        # nic sa nedopocitava a chybajuci udaj sa VYNECHA (nikdy sa nehada).
        def drawer_row_text(params)
          p = params.is_a?(Hash) ? params : {}
          parts = []
          sys = Recipes.system_label(p['system'])
          parts << sys unless sys.empty?
          parts << "H#{p['height_variant'].to_i}" if p['height_variant'].is_a?(Numeric)
          parts << "box #{Recipes.fmt(p['box_height'])} mm" if p['box_height'].is_a?(Numeric)
          parts << "NL #{Recipes.fmt(p['nominal_length'])}" if p['nominal_length'].is_a?(Numeric)
          parts << "#{Recipes.fmt(p['load'])} kg" if p['load'].is_a?(Numeric)
          parts << (p['opening'].to_s == 'p2o' ? 'Tip-On' : 'SiSy') unless p['opening'].to_s.empty?
          ver = Recipes.parse_id(p['recipe_id'].to_s)
          parts << "recept v#{ver[:version]}" if ver
          parts.join(' · ')
        end

        # Polozka vysuvu Z RECEPTU pre dane celo. Identita je `owner_part_key`
        # panela cela + `source: 'recipe'` — legacy `slide` polozka (stara
        # zakazka) sa VEDOME neberie, karta by o nej tvrdila cisla receptu.
        def drawer_item_for(cfg, fid)
          owner = PartKeys.front(fid, 'panel')
          Array(cfg['hardware']).find do |h|
            h.is_a?(Hash) && h['owner_part_key'].to_s == owner &&
              h['source'].to_s == BuildPlan::HW_SOURCE_RECIPE
          end
        end

        def drawer_conflict_for(cfg, fid)
          Array(cfg['drawer_conflicts']).find do |c|
            c.is_a?(Hash) && c['front_id'].to_s == fid && !c['message'].to_s.strip.empty?
          end
        end

        # ORANGE odporucanie synchronizacie (P2O nad prahom sirky). Warning je
        # v `cfg['warnings']` a nesie `data.front_id` — viaze sa teda na KONKRETNE
        # celo, nie na skrinku.
        def drawer_sync_note(cfg, fid)
          w = Array(cfg['warnings']).find do |x|
            next false unless x.is_a?(Hash) && x['code'].to_s == DRAWER_SYNC_CODE

            d = x['data'].is_a?(Hash) ? x['data'] : {}
            d['front_id'].to_s == fid
          end
          w && !w['message'].to_s.strip.empty? ? w['message'].to_s : nil
        end

        # Skrinka ulozena PRED aktivaciou receptov (`Bom.drawer_stale_issue` robi
        # z toho RED nalez) — karta ma povedat to iste, len kratsie.
        def drawer_stale_cfg?(cfg)
          defined?(CabinetBuilder) &&
            CabinetBuilder.config_schema_of(cfg) < CabinetBuilder::DRAWER_ACTIVATION_SCHEMA
        end

        # --- KOV-E2: RIADOK VYKLOPU v karte cela ------------------------------
        #
        # Mapa `front_id => zaznam` pre riadky ciel typu `lift`. Karta z nej
        # kresli JEDEN read-only riadok + rozbalitelny „Technický detail" —
        # ziadny novy vertikalny blok (vertikalny priestor panela je vzacny).
        #
        # SERVER je jedina autorita textu. Cerveny dovod je DOSLOVNE ten isty
        # ulozeny retazec, ktory vyda Kontrola v Studiu (`hardware_conflicts`
        # -> `Bom.collect` -> `HW_CONFLICT_CODES`), takze o jednej chybe
        # neexistuju dve vety. Vsetko je CITACIE — ziadny zapis, ziadna zmena
        # schemy; zdroje su ULOZENY config (polozka `lift`, `hardware_conflicts`,
        # `warnings`) a stav setov.
        #
        # Stavy zaznamu (`state`) su ZRKADLOM zaznamu zasuvky (C2c):
        #   'conflict' — RED dovod stavby; `message` = veta Kontroly
        #   'stale'    — skrinka postavena PRED pravidlami vyklopov
        #                (`Bom.flap_stale_front?`) — TA ISTA autorita, akou
        #                vznika RED `flap_stale`, nie druha podmienka vedla nej.
        #                Codex #334 kolo 1 P2: nestaci sa pytat proveniencie —
        #                nalez Kontroly ma este VYNIMKU pre uplnu rucnu zostavu
        #                (`HardwareSets.manual_flap_assemblies`), takze celo
        #                s rucne zlozenym mechanizmom by v karte bolo cervene,
        #                kym Kontrola mlci.
        #   'ok'       — `text` = zhrnutie, `detail` = vety, `warn` = ORANGE
        #   'incomplete' — polozka VZNIKLA, ale set ju nevie cely vydat
        #                (Codex #334 kolo 2 P2): `message` = TA ISTA veta, aku
        #                da Kontrola pri RED `lift_set_incomplete`; `text`
        #                a `detail` OSTAVAJU (co uz vieme, sa nezahadzuje)
        #   'pending'  — pravidlo vyklopov je vypnute / polozka nevznikla:
        #                karta mlci (a hovori za nu veta „vyberá automat")
        #
        # ORANGE kody, ktore sa VIAZU NA VLASTNIKA (`part_key`). `hardware_rule_overlap`
        # tu ZAMERNE NIE JE: je to varovanie o PRAVIDLACH (seed sa nedoplnil),
        # nie o tomto cele - vlastnika nenesie a v karte by nemalo kde pristat.
        LIFT_WARN_CODES = %w[lift_light_front lift_override_ignored].freeze

        def front_lift_payload(cfg)
          return {} unless defined?(HardwareRules)

          out = {}
          buy = nil
          Array(cfg['front_items']).each do |it|
            next unless it.is_a?(Hash) && it['type'].to_s == 'lift'

            fid = it['id'].to_s
            next if fid.empty?

            buy = drawer_buy_ctx(cfg) if buy.nil?
            out[fid] = lift_card_row(cfg, fid, buy)
          end
          out
        rescue StandardError => e
          Engine.log_error(e, 'Panel.front_lift_payload')
          {}
        end

        def lift_card_row(cfg, fid, buy = nil)
          owner = PartKeys.front(fid, 'flap')
          conflict = lift_conflict_for(cfg, owner)
          return { 'state' => 'conflict', 'message' => conflict['message'].to_s } if conflict

          hw = lift_item_for(cfg, owner)
          if hw.nil?
            return { 'state' => 'stale', 'message' => lift_stale_message } if
              defined?(Bom) && Bom.flap_stale_front?(cfg, fid)

            return { 'state' => 'pending' }
          end
          params = hw['params'].is_a?(Hash) ? hw['params'] : {}
          exp = item_expansion(hw, buy)
          row = { 'state' => 'ok', 'text' => lift_row_text(params, hw),
                  'detail' => lift_detail_lines(cfg, params) + buy_lines(exp) }
          # Codex #334 kolo 2 P2: ZLYHANIE EXPANZIE JE STAV KARTY, nie riadok
          # v rozkliku. Kym `state` ostavalo 'ok', karta neuplnu zostavu
          # priznala len vetou „Bez kódu: …" schovanou v „Technickom detaile" —
          # kym Kontrola vedla hlasila RED `lift_set_incomplete` a zastavovala
          # nakup, rozpocet aj cenovu ponuku. Karta a Kontrola sa rozist nesmu.
          bad = lift_incomplete_note(exp)
          if bad
            row['state'] = 'incomplete'
            row['message'] = bad
          end
          warn = lift_warn_note(cfg, owner)
          row['warn'] = warn if warn
          row
        end

        # Veta o NEUPLNEJ ZOSTAVE vyklopu, alebo nil. Zdroj je SUROVY zaznam
        # expanzie (`explain` -> `unmapped`) — z prelozeneho `problems` sa
        # zavaznost uz precitat neda, a prave zavaznost tu rozhoduje: pri
        # polozke `lift` sa KAZDY nevyrieseny clen povysuje na RED
        # `lift_set_incomplete` (`HardwareSets.unmapped_entry`).
        # ZNENIE vety sklada `Validation` — TA ISTA metoda, akou vznika nalez
        # Kontroly, len bez lokatora skrinky (karta v tej skrinke stoji).
        def lift_incomplete_note(exp)
          return nil unless exp.is_a?(Hash) && defined?(Validation)

          u = Array(exp['unmapped']).find do |x|
            x.is_a?(Hash) && x['reason'].to_s == HardwareSets::LIFT_SET_INCOMPLETE
          end
          u ? Validation.lift_incomplete_sentence(u) : nil
        rescue StandardError => e
          Engine.log_error(e, 'Panel.lift_incomplete_note')
          nil
        end

        # Veta stale stavu. Kratsia ako nalez Kontroly (ten menuje skrinku),
        # ale hovori TO ISTE a navadza na TU ISTU napravu.
        def lift_stale_message
          'Výklop je postavený ešte pred pravidlami výklopov — v Pravidlách kovania spusti ' \
            '„Doplniť nové predvoľby“ a skrinku prestav, inak jej v nákupe chýba celý mechanizmus.'
        end

        # Zhrnutie do JEDNEHO riadku: „AVENTOS HK top · 22K2300 · automat".
        # Kazdy udaj pochadza z ULOZENYCH `params` polozky vyklopu — nic sa
        # nedopocitava a chybajuci udaj sa VYNECHA (nikdy sa nehada).
        def lift_row_text(params, item = nil)
          p = params.is_a?(Hash) ? params : {}
          parts = ["AVENTOS #{HardwareRules.lift_system_label(p['lift_system'].to_s)}"]
          cls = p['lift_class'].to_s.strip
          arm = p['arm_class'].to_s.strip
          parts << cls unless cls.empty?
          parts << "ramená #{arm}" unless arm.empty?
          tag = lift_source_tag(item)
          parts << tag if tag
          parts.join(' · ')
        end

        # Codex #334 kolo 1 P2: STITOK ZDROJA polozky.
        #
        # `automat` nie je „vybral to plugin" — je to priznanie, ze polozku
        # riadi CELE pravidlo a rucny zasah sa na nej NEUPLATNI. To plati
        # VYHRADNE pre chranene seed pravidlo (`HardwareRules.protected_lift_item?`,
        # `LIFT_RULE_ID`); na polozke z VLASTNEHO vyklopoveho pravidla override
        # ucinny JE a `apply_overrides` ju oznaci `source: 'manual'`. Karta by
        # o rucne prepisanom pocte tvrdila „automat" — presny opak pravdy.
        # Vlastne pravidlo BEZ overridu stitok NEDOSTANE: mlcanie je presnejsie
        # nez ktorekolvek z dvoch slov.
        def lift_source_tag(item)
          return nil unless item.is_a?(Hash)
          return 'automat' if HardwareRules.protected_lift_item?(item)

          item['source'].to_s == 'manual' ? 'ručne' : nil
        end

        # Vety rozkliku. Su to VYHRADNE ULOZENE fakty polozky a rozmery korpusu
        # z configu — ziadny prepocet planu. Cislo LF (HK) ani hmotnost (HL) sa
        # na polozke NEUKLADAJU (kontrakt E1a/E1b), takze sa tu nedopocitavaju:
        # druhy vypocet tej istej veliciny by sa s automatom casom rozisiel.
        # Ked automat trafi problem, cisla su vo VETE KONFLIKTU — a tu vetu
        # karta ukaze doslovne.
        def lift_detail_lines(cfg, params)
          p = params.is_a?(Hash) ? params : {}
          out = []
          out << "Otváranie: #{HardwareSets.class_label('opening_mode', p['opening_mode'])}" unless
            p['opening_mode'].to_s.strip.empty?
          kh = lift_kh_mm(cfg)
          kb = num_or_nil(cfg['width'])
          dims = []
          dims << "výška korpusu bez sokla #{HardwareRules.fmt_mm(kh)} mm" if kh
          dims << "šírka korpusu #{HardwareRules.fmt_mm(kb)} mm" if kb
          out << "Rozmery pre výber: #{dims.join(' · ')}" unless dims.empty?
          out << lift_rod_line(p)
          out.compact
        end

        # KH = vyska korpusu BEZ SOKLA. TEN ISTY vzorec, akym ho pocita kontext
        # pravidiel (`Construction`: `height - floor_height`) — karta nesmie
        # ukazat iny rozmer, nez podla ktoreho automat vyberal.
        def lift_kh_mm(cfg)
          h = num_or_nil(cfg['height'])
          return nil if h.nil?

          (h - num_or_nil(cfg['floor_height']).to_f).round(2)
        end

        def num_or_nil(v)
          v.is_a?(Numeric) && v.to_f.finite? ? v.to_f : nil
        end

        # Stabilizacna tyc: pocet a predlzovaci diel su ULOZENE v `params`
        # (`rod_count` / `rod_extension`), takze riadok hovori presne to, co je
        # v nakupe. Polozka bez tychto klucov (HK top) riadok NEDOSTANE.
        def lift_rod_line(p)
          n = p['rod_count']
          return nil unless n.is_a?(Numeric) && n.to_i.positive?

          ext = p['rod_extension'].is_a?(Numeric) && p['rod_extension'].to_i.positive?
          "Stabilizačná tyč: #{n.to_i}×#{ext ? ' + predlžovací diel' : ''}"
        end

        # ULOZENY dovod stavby pre TOHTO vlastnika. Register kodov je JEDINY
        # (`BuildPlan::HW_CONFLICT_CODES`) — panel si zoznam neopisuje.
        def lift_conflict_for(cfg, owner)
          Array(cfg['hardware_conflicts']).find do |c|
            c.is_a?(Hash) && c['owner_part_key'].to_s == owner &&
              BuildPlan::HW_CONFLICT_CODES.include?(c['code'].to_s) &&
              !c['message'].to_s.strip.empty?
          end
        end

        # ORANGE veta pre TOHTO vlastnika (lahke celo, ignorovany rucny zasah).
        def lift_warn_note(cfg, owner)
          w = Array(cfg['warnings']).find do |x|
            x.is_a?(Hash) && LIFT_WARN_CODES.include?(x['code'].to_s) &&
              x['part_key'].to_s == owner && !x['message'].to_s.strip.empty?
          end
          w && w['message'].to_s
        end

        # Polozka VYKLOPU pre dane celo (`use_type: 'lift'` — jedina autorita
        # otazky „je to vyklop" je `HardwareSets.lift_item?`, nie `generic_type`:
        # rucna polozka typu `lift` triedu ani tyce nenesie).
        def lift_item_for(cfg, owner)
          Array(cfg['hardware']).find do |h|
            h.is_a?(Hash) && h['owner_part_key'].to_s == owner && HardwareSets.lift_item?(h)
          end
        end

        # V0.6 D-92: polozky kovania pre panel. Aditivne k ulozenemu configu:
        #   label       — slovensky nazov typu (jedina autorita HardwareRules)
        #   owner_label — LUDSKY nazov vlastnika namiesto suroveho part_key
        #                 (D-92; JS uz nic neskladá)
        #   purchase    — co sa realne kupi (set -> kody -> nazvy z katalogu)
        # Vsetko TRANZIENTNE — do configu/snapshotu sa NIKDY nic z toho neuklada.
        # Cesta je CITACIA: ziadna operacia, ziadny zapis do modelu.
        def hardware_items_payload(cfg)
          items = (cfg['hardware'].is_a?(Array) ? cfg['hardware'] : []).map do |h|
            h.is_a?(Hash) ? h.merge('label' => HardwareRules.label_for(h['generic_type'])) : h
          end
          decorate_hardware_purchase(cfg, items)
        end

        # D-93: stav rucnych zasahov po POLIACH + rad nominalnych dlzok pre
        # polozky pravidla kind 'fit_series' (dnes vysuvy). VSETKO TRANZIENTNE
        # (do configu sa neuklada nic) a CITACIE — pravidla sa citaju rovnakou
        # cestou ako pri zapise overridu (panel_hardware_rules), takze ponuka
        # selectu a serverova validacia SET nemozu ukazovat iny rad.
        #   quantity_manual — pocet je rucny (source 'manual' uz nestaci: manual
        #                     je polozka aj pri samotnom zamku dlzky)
        #   nl.series  — rad z pravidla (Float mm)
        #   nl.value   — co plati teraz (params['nominal_length'])
        #   nl.locked  — zamok = existencia platneho pola v override zazname
        #   nl.auto    — co by dal automat (auto_known false = nevie)
        def hardware_override_payload(items, cfg, cab)
          rules = panel_hardware_rules(cab.respond_to?(:model) ? cab.model : nil)
          by_id = {}
          # Duplicitny rule_id: evaluator berie PRVE pravidlo (a varuje) — payload
          # musi zrkadlit tu istu volbu, inak select ukaze rad z pravidla, ktore
          # polozku nevytvorilo (Codex GH #156 P2).
          Array(rules).each { |r| by_id[r['rule_id'].to_s] ||= r if r.is_a?(Hash) }
          list = cfg['hardware_overrides'].is_a?(Array) ? cfg['hardware_overrides'] : []
          Array(items).map do |h|
            next h unless h.is_a?(Hash)
            ov = Array(list).select { |o| o.is_a?(Hash) && HardwareRules.override_match?(o, h) }.last
            out = h.merge('quantity_manual' => (ov.is_a?(Hash) && !ov['quantity'].nil?))
            rule = by_id[h['rule_id'].to_s]
            next out unless rule.is_a?(Hash) && rule['kind'].to_s == 'fit_series'
            series = Array(rule['series']).map(&:to_f).select(&:positive?)
            next out if series.empty?
            params = h['params'].is_a?(Hash) ? h['params'] : {}
            value = params['nominal_length'].is_a?(Numeric) ? params['nominal_length'].to_f : nil
            locked = !HardwareRules.override_nl(ov.is_a?(Hash) ? ov['nominal_length'] : nil).nil?
            auto = if locked
                     h['rule_nominal_length'].is_a?(Numeric) ? h['rule_nominal_length'].to_f : nil
                   else
                     value
                   end
            out.merge('nl' => { 'series' => series, 'value' => value, 'locked' => locked,
                                'auto' => auto, 'auto_known' => !auto.nil? })
          end
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hardware_override_payload')
          items
        end

        # JEDINA citacia cesta k pravidlam kovania pre panel (payload aj zapis
        # overridu): projektovy snapshot, a kym ho projekt nema, globalna
        # kniznica (rovnaka, aku do snapshotu zapise najblizsia stavba).
        def panel_hardware_rules(model)
          HardwareRules.project_rules(model) || HardwareRules.load
        rescue StandardError => e
          Engine.log_error(e, 'Panel.panel_hardware_rules')
          []
        end

        # D-92: ludsky nazov vlastnika aj pri vypnutych kategoriach.
        # D-92 + KOV-C2b (Codex #304 P1): OSIROTENE rucne zasahy. Panel stavia
        # editovatelne riadky z EMITOVANYCH poloziek, takze zasah, ku ktoremu
        # ziadna polozka nevznikla, by nemal ako zmiznut — pouzivatel by ho
        # nevedel zrusit a exporty by ostali zablokovane.
        #
        # SERVER je autorita (JS uz nerozhoduje z `disabled`), lebo len tu je
        # vidno OBE strany: emitovane polozky aj ulozene `drawer_conflicts`.
        # Dva druhy:
        #   `disabled` — vypnuta kategoria (D-92, doterajsie spravanie)
        #   `invalid`  — celo so systemom skoncilo KONFLIKTOM, takze polozka
        #                NEVZNIKLA (rucny pocet != 1, vypnutie alebo zamok NL
        #                mimo radu na zasuvke z receptu). Riadok ponuka RESET
        #                (odstranenie celeho zaznamu) — po nom prestavba
        #                konflikt uz nevyda.
        # --- KOV-D2a: STAV OSI ZAMKU (server pocita, JS kresli) ---------------
        #
        # Receptova polozka OSTAVA `source: 'recipe'` a zamky sa citaju vyhradne
        # v `Recipes.resolve` — NIKDY cez `HardwareRules.apply_overrides` (ten
        # by pri NL prepol zdroj na `manual` a nakup by prestal povysovat
        # chybajuci kit na blocker; Astra #20 F7). Preto tento payload existuje:
        # je to JEDINY server-side stav, z ktoreho D2b nakresli chipy.
        #
        #   axes.height / axes.nl = { state: auto|locked|conflict, value,
        #                             options[], message?, proposal?, blocked_by? }
        #
        # `options` = hodnoty, ktore sa DAJU zamknut (vysky receptu, ktore sa
        # zmestia do svetlej vysky; NL z radu VYSLEDNEJ vysky, ktore sa zmestia
        # do hlbky). `proposal` = navrh nahrady pri konflikte — z RECEPTU
        # a GEOMETRIE, nikdy z dostupnych kodov, a meni LEN opravovanu os:
        # druhy zamok ostava a znovu sa overi (nil = pri nom platna nahrada
        # neexistuje, takze D2b potvrdenie neponukne).
        # QUADRO: kluc `axes.height` CHYBA (nie `state: auto`) — system vyskove
        # varianty nema a ponuknut sa nema co. Miesto neho ma D-128 kluc
        #   axes.box = { state, value, min, max, message?, proposal? }
        # (SPOJITY rozsah, teda ziadne `options`). ATIRA kluc `box` NEMA.
        def drawer_axes_map(cfg, params)
          drawer_axes_index(cfg, params)['by_owner']
        end

        # KOV-D2b: JEDEN prechod ciel dava OBOJE — stav osi per vlastnik
        # (`by_owner`, kontrakt D2a) a IDENTITU ZAPISU per celo (`idents`).
        # Recept sa nacitava RAZ (`Recipes.load` cita subor a overuje odtlacok),
        # takze druhy prechod kvoli identite by bol druhy diskovy pristup na
        # kazdy push panela.
        #
        # Identita je `owner_part_key` + `generic_type` + `rule_id` — presne to,
        # co ocakava `handle_set_hardware_override`. Karta cela ju NEODVODZUJE
        # (skladat `recipe:<id>` v JS by znamenalo druhu pravdu o tom, ku ktorej
        # polozke zamok patri); v kontexte Kovanie ju riadok uz ma v datasete.
        # D-132 (review P3): index nesie aj `trusted`. `false` znamena „stav osi
        # sa NEPODARILO precitat" — nie „ziadna zasuvka". Rozdiel je podstatny:
        # z prazdnej mapy `idents` by klasifikator usudil, ze celo pripnuty
        # recept nema, oznacil by ZIVY zamok za dormantny a ponukol ho zrusit.
        # Chipy ani karta cela sa nemenia (obe uz s prazdnym indexom pocitaju).
        def drawer_axes_index(cfg, params)
          empty = { 'by_owner' => {}, 'idents' => {} }
          ctxs = CabinetBuilder.drawer_axis_contexts(params)
          return empty.merge('trusted' => false) if ctxs.nil?
          return empty if ctxs.empty?

          overrides = Array(cfg['hardware_overrides'])
          Array(cfg['front_items']).each_with_object(empty) do |item, acc|
            next unless item.is_a?(Hash)

            fid = item['id'].to_s
            ctx = ctxs[fid]
            next if ctx.nil?

            recipe = drawer_axis_recipe(item)
            next if recipe.nil?

            owner = ctx[:owner_part_key].to_s
            acc['by_owner'][owner] = drawer_axes(recipe, ctx, overrides, drawer_conflict_for(cfg, fid))
            acc['idents'][fid] = drawer_lock_ident(owner, recipe)
          end
        rescue StandardError => e
          Engine.log_error(e, 'Panel.drawer_axes_map')
          { 'by_owner' => {}, 'idents' => {}, 'trusted' => false }
        end

        def drawer_lock_ident(owner, recipe)
          { 'owner_part_key' => owner,
            'generic_type' => Recipes::LOCK_GENERIC_TYPE,
            'rule_id' => "#{Recipes::LOCK_RECIPE_PREFIX}#{recipe[:recipe_id]}" }
        end

        # PRIPNUTY recept cela (rovnaka retaz ako stavba), alebo nil.
        # Nenacitatelny recept (chybajuci subor, zmeneny odtlacok) sa ZALOGUJE:
        # tichy `nil` by vonkajsi logger nikdy nevidel a riadok osiroteneho
        # zasahu by prisiel o stav osi bez stopy v diagnostike (Codex #312
        # kolo 3 P2). Neznamy PIN (`:unknown`) logovanie nepotrebuje — to nie
        # je chyba citania, ale stav, ktory uz hlasi RED `drawer_recipe_unknown`.
        def drawer_axis_recipe(item)
          kind, key = Recipes.recipe_key_for(item)
          return nil unless kind == :ok

          drawer = item['drawer'].is_a?(Hash) ? item['drawer'] : {}
          state, ref = Recipes.active_ref(drawer['recipe_refs'], key[:system], key[:opening])
          return nil if state == :unknown

          ref = Recipes.pick_ref(drawer['recipe_refs'], key[:system], key[:opening]) if state == :missing
          ref && Recipes.load(ref)
        rescue StandardError => e
          Engine.log_error(e, "Panel.drawer_axes_map #{item.is_a?(Hash) ? item['id'] : nil} recipe")
          nil
        end

        # Stav oboch osi JEDNEJ zasuvky. Poradie je to iste ako v resolveri:
        # vyska rozhoduje PRED radom NL (rad NL JE per vyska), takze pri
        # konflikte vysky sa NL uz nema z coho pocitat — jej ponuka je vtedy
        # prazdna a riadok priznava `blocked_by: 'height'`, nikdy nehada.
        def drawer_axes(recipe, ctx, overrides, conflict)
          clear_h = ctx[:clear_height].to_f
          clear_d = ctx[:clear_depth].to_f
          nl_lock = Recipes.lock_value(recipe, ctx, overrides)
          axes = {}
          height = nil
          height_conflict = false

          if Recipes.atira?(recipe)
            opts = Recipes.height_options(recipe, clear_h)
            h_lock = Recipes.height_lock_value(recipe, ctx, overrides)
            if h_lock
              valid = opts.include?(h_lock)
              height = valid ? h_lock : nil
              height_conflict = !valid
              axes['height'] = { 'state' => valid ? 'locked' : 'conflict',
                                 'value' => h_lock, 'options' => opts }
              unless valid
                # INVARIANT: os so `state: conflict` MA vzdy hlasku. Ulozeny
                # dovod plati LEN ked sedi kod — zasuvka moze mat SKORSIE
                # zlyhanie resolvera (prekazka, hrubka, KD), a vtedy
                # `drawer_conflicts` o zamku nevie vobec. Veta sa preto odvodi
                # z receptu a kontextu tou istou funkciou, akou ju sklada
                # resolver (Codex #312 kolo 3 P2).
                axes['height']['message'] = axis_message(conflict, 'height_lock_invalid') ||
                                            Recipes.height_lock_problem(recipe, h_lock, clear_h)
                axes['height']['proposal'] = height_proposal(recipe, opts, nl_lock, clear_d)
              end
            else
              v = Recipes.pick_height_variant(recipe, clear_h)
              height = v && v[:height]
              axes['height'] = { 'state' => 'auto', 'value' => height, 'options' => opts }
            end
          else
            # D-128: TRETIA os — RUCNA VYSKA DREVENEHO BOXU. Vlastny kluc `box`,
            # NIE `height`: Atira payload tak ostava bajtovo zhodny a pravidlo
            # „Quadro nema kluc `height`" plati dalej.
            axes['box'] = drawer_box_axis(recipe, ctx, overrides, conflict)
          end

          axes['nl'] = drawer_nl_axis(recipe, height, height_conflict, clear_d, nl_lock, conflict)
          axes
        end

        # Stav osi VYSKY BOXU (systemy bez vyskovych variantov). Na rozdiel od
        # vysky a NL je to SPOJITY ROZSAH, takze os nema `options` — nesie
        # `min`/`max` a JS z nich kresli male ciselne pole.
        #
        # `max` je AUTOMAT (nad automat sa nesmie), preto je aj navrhom nahrady
        # pri konflikte. Ked sa rozsah urcit NEDA alebo je PRAZDNY (`max < min`
        # pri velmi nizkej zone), `min`/`max`/`proposal` su `nil` — JS vtedy
        # nekresli ani pole, ani ponuku nahrady, a zapis by taku hodnotu aj tak
        # odmietol (obe brany, vzor NL osi s prazdnymi `options`).
        def drawer_box_axis(recipe, ctx, overrides, conflict)
          clear_h = ctx[:clear_height].to_f
          rng = Recipes.box_range(recipe, clear_h, ctx[:part_thicknesses])
          usable = rng && rng[:min] <= rng[:max]
          lock = Recipes.box_lock_value(recipe, ctx, overrides)
          out = { 'state' => 'auto', 'value' => nil,
                  'min' => usable ? rng[:min] : nil, 'max' => usable ? rng[:max] : nil }
          if lock.nil?
            out['value'] = usable ? rng[:max] : nil
            return out
          end

          problem = Recipes.box_lock_problem(recipe, lock, clear_h, ctx[:part_thicknesses])
          out['value'] = lock
          out['state'] = problem ? 'conflict' : 'locked'
          return out unless problem

          # INVARIANT (vzor oboch starsich osi): os so `state: conflict` MA vzdy
          # hlasku. Ulozeny dovod plati LEN ked sedi kod — zasuvka moze mat
          # SKORSIE zlyhanie resolvera (prekazka, hrubka, KD) a `drawer_conflicts`
          # o zamku vtedy nevie vobec.
          out['message'] = axis_message(conflict, 'box_lock_invalid') || problem
          out['proposal'] = usable ? rng[:max] : nil
          out
        end

        def drawer_nl_axis(recipe, height, height_conflict, clear_d, nl_lock, conflict)
          # Neurcena vyska (konflikt vyskoveho zamku alebo ziadny variant sa
          # nezmesti) = rad NL neexistuje. Zamok sa PRIZNA, ale ponuka je
          # prazdna — vymysleny rad by ponukol dlzku, ktoru recept odmietne.
          if Recipes.atira?(recipe) && height.nil?
            out = { 'state' => nl_lock ? 'locked' : 'auto', 'value' => nl_lock, 'options' => [] }
            out['blocked_by'] = 'height' if height_conflict
            return out
          end

          opts = Recipes.nl_options(recipe, height, clear_d)
          return { 'state' => 'auto', 'value' => opts.max, 'options' => opts } if nl_lock.nil?

          valid = opts.any? { |v| (v - nl_lock).abs < 1e-9 }
          out = { 'state' => valid ? 'locked' : 'conflict', 'value' => nl_lock, 'options' => opts }
          unless valid
            # Ten isty invariant ako pri vyske: hlaska sa odvodi nezavisle
            # (`Recipes.nl_lock_problem` je JEDINA veta o tomto dovode — cita
            # ju aj resolver), ulozeny dovod vyhrava len pri zhode kodu.
            out['message'] = axis_message(conflict, 'nl_lock_invalid') ||
                             Recipes.nl_lock_problem(recipe, nl_lock, height, clear_d)
            out['proposal'] = opts.max
          end
          out
        end

        # Navrh nahrady VYSKY: najvyssi variant, ktory sa zmesti A v ktorom
        # DRUHY zamok (NL) dalej plati. Ked taky neexistuje, `nil` — D2b vtedy
        # potvrdenie neponukne (nikdy sa neruší druhý zámok potichu).
        def height_proposal(recipe, options, nl_lock, clear_d)
          options.sort.reverse.find do |h|
            opts = Recipes.nl_options(recipe, h, clear_d)
            next false if opts.empty?

            nl_lock.nil? || opts.any? { |v| (v - nl_lock).abs < 1e-9 }
          end
        end

        # Hlaska osi = ULOZENY dovod konfliktu (`drawer_conflicts`), nikdy druhy
        # text — inak by sa karta rozisla s Kontrolou.
        def axis_message(conflict, code)
          return nil unless conflict.is_a?(Hash) && conflict['code'].to_s == code

          m = conflict['message'].to_s
          m.empty? ? nil : m
        end

        def attach_drawer_axes(items, axes)
          Array(items).map do |h|
            next h unless h.is_a?(Hash) && h['source'].to_s == BuildPlan::HW_SOURCE_RECIPE

            a = axes[h['owner_part_key'].to_s]
            a ? h.merge('axes' => a) : h
          end
        end

        # KOV-D2b: KARTA CELA kresli ten isty rad chipov ako kontext Kovanie.
        # Zaznam `front_drawer[fid]` preto dostava `axes` (TA ISTA mapa, ziadny
        # druhy vypocet) a `lock` = identitu zapisu doplnenu o `cabinet_id`
        # (guard F6 — klik z karty musi byt rovnako chraneny ako klik v riadku).
        # Zaznam BEZ osi (napr. `stale` celo alebo celo, ktoreho recept sa
        # nenacital) ostava presne taky, aky bol v C2c.
        # KOV-D3b: PONUKA NOVEJ VERZIE RECEPTU. Zaznam dostane kluc `upgrade`
        # LEN vtedy, ked pre jeho pripnuty recept naozaj existuje VYDANA vyssia
        # verzia. V produkcii ziadna v2 neexistuje, takze sa kluc NIKDY
        # nepridava a payload je zhodny s D3a (charakterizacny test).
        #
        # Otazka je LACNA (register + `parse_id`) — dopad na celo sa NEPOCITA:
        # ten stoji cely `build_plan` + expanziu setov a chodi az na klik,
        # samostatnym citacim callbackom `drawer_upgrade_impact`.
        #
        # Ponuka sa dava LEN vyriesenej zasuvke (`state == 'ok'`): tabulka
        # dopadu porovnava TERAJSI stav s cielovym a konfliktna zasuvka ziadny
        # terajsi stav nema — jej cesta von je dovod konfliktu, nie upgrade.
        #
        # `cabinet_id` a `front_id` su V BLOKU zamerne: identitu zapisu sklada
        # SERVER (rovnaka zasada ako `lock` v D2b), panel ju z niceho neodvodzuje.
        # NAKLAD (Codex #315 kolo 1 P2): register receptov sa cita RAZ na cely
        # prechod (`Recipes.with_register_cache`) a metadata CIELA sa zdielaju
        # medzi zasuvkami s rovnakou kombinaciou `system|opening` (`seen`).
        # Bez toho by kazda zasuvka spustila `active_ref` + `latest_for` (a s v2
        # aj `load` s odtlackom) samostatne — desat zasuviek = 20+ synchronnych
        # citani disku pri KAZDOM pushi, vratane echa po kazdom edite.
        # Ziadna trvala cache: mimo tohto bloku sa nekesuje nic.
        def attach_front_drawer_upgrade(map, cfg, cab_id)
          return map unless map.is_a?(Hash) && !map.empty?
          return map unless defined?(Recipes)

          seen = {}
          Recipes.with_register_cache do
            Array(cfg['front_items']).each do |it|
              next unless it.is_a?(Hash)

              row = map[it['id'].to_s]
              next unless row.is_a?(Hash) && row['state'].to_s == 'ok'

              up = drawer_upgrade_offer(it, cab_id, seen)
              row['upgrade'] = up if up
            end
          end
          map
        rescue StandardError => e
          Engine.log_error(e, 'Panel.attach_front_drawer_upgrade')
          map
        end

        # Existuje pre TENTO pripnuty recept vydana vyssia verzia?
        # -> hash ponuky | nil. Pravidla su TIE ISTE, ktore zapisovu cestu
        # nakoniec pustia (`active_ref` == `:known` · vydany ciel ·
        # `Recipes.upgrade?`) — ponuka sa preto nemoze objavit tam, kde by ju
        # server vzapati odmietol.
        #
        # `seen` = memo CIELA per `system|opening` (najnovsi vydany + jeho
        # popisok a poznamka vydania). Zavisi VYHRADNE od kombinacie, nie od
        # cela, takze sa smie zdielat; `from` sa cita per celo (kazde ma vlastnu
        # mapu `recipe_refs` a smie byt na inej verzii).
        def drawer_upgrade_offer(item, cab_id, seen = {})
          kind, key = Recipes.recipe_key_for(item)
          return nil unless kind == :ok

          drawer = item['drawer'].is_a?(Hash) ? item['drawer'] : {}
          state, from = Recipes.active_ref(drawer['recipe_refs'], key[:system], key[:opening])
          return nil unless state == :known

          tgt = drawer_upgrade_target(key, seen)
          return nil unless tgt && Recipes.upgrade?(from, tgt['to'])

          tgt.merge('available' => true, 'from' => from.to_s,
                    'cabinet_id' => cab_id.to_s, 'front_id' => item['id'].to_s)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.drawer_upgrade_offer')
          nil
        end

        # Najnovsi VYDANY recept kombinacie + jeho popisok a poznamka vydania.
        # `nil` = kombinacia ziadny vydany recept nema. Memo `seen` drzi aj
        # zaporny vysledok, aby sa nehladal opakovane.
        def drawer_upgrade_target(key, seen)
          k = "#{key[:system]}|#{key[:opening]}"
          return seen[k] if seen.key?(k)

          to = Recipes.latest_for(key[:system], key[:opening])
          ver = to && Recipes.parse_id(to)
          seen[k] = ver && { 'to' => to.to_s, 'to_label' => "v#{ver[:version]}",
                             'release_note' => Recipes.load(to)[:release_note].to_s }
        end

        def attach_front_drawer_axes(map, index, cab_id)
          return map unless map.is_a?(Hash)

          by_owner = index['by_owner'] || {}
          (index['idents'] || {}).each do |fid, ident|
            row = map[fid]
            next unless row.is_a?(Hash)

            ax = by_owner[ident['owner_part_key']]
            next if ax.nil?

            map[fid] = row.merge('axes' => ax, 'lock' => ident.merge('cabinet_id' => cab_id.to_s))
          end
          map
        rescue StandardError => e
          Engine.log_error(e, 'Panel.attach_front_drawer_axes')
          map
        end

        # Osiroteny riadok zasahu (polozka pri konflikte NEVZNIKLA) dostane ten
        # isty stav osi — inak by sa konfliktna zasuvka nedala odomknut.
        #
        # KOV-D4 (pravidlo pamate pri prechode na dvierka): stav osi patri
        # PRIPNUTEMU receptu, takze ho dostane LEN zaznam s JEHO `rule_id`.
        # DORMANTNY zamok ineho receptu (zostal po zmene otvarania alebo po
        # prechode zasuvka -> dvierka -> zasuvka s inym pinom) chipy NEDOSTANE:
        # `Recipes.lock_value` ho aj tak nepouzije, ale chipy by ukazovali stav
        # AKTUALNEHO receptu, kym zapis by isiel na CUDZI `rule_id` — teda presne
        # ta ticha zamena, ktorej cely package brani. Riadok osiroteneho zasahu
        # taky zaznam nadalej ukaze (aj s tlacidlom „zrušiť"), len bez chipov.
        def attach_override_axes(rows, index)
          axes = index.is_a?(Hash) ? (index['by_owner'] || {}) : {}
          active = active_lock_rules(index)
          Array(rows).map do |ov|
            next ov unless ov.is_a?(Hash) && ov['generic_type'].to_s == Recipes::LOCK_GENERIC_TYPE
            next ov unless ov['rule_id'].to_s.start_with?(Recipes::LOCK_RECIPE_PREFIX)

            owner = ov['owner_part_key'].to_s
            next ov unless active[owner] == ov['rule_id'].to_s

            a = axes[owner]
            a ? ov.merge('axes' => a) : ov
          end
        end

        # { owner_part_key => `rule_id` PRIPNUTEHO receptu } z `idents` — je to
        # ta ista identita, akou sa zamok zapisuje (`drawer_lock_ident`), takze
        # sa „co sa kresli" a „kam sa pise" nemozu rozist.
        def active_lock_rules(index)
          out = {}
          idents = index.is_a?(Hash) ? index['idents'] : nil
          (idents.is_a?(Hash) ? idents : {}).each_value do |ident|
            next unless ident.is_a?(Hash)

            out[ident['owner_part_key'].to_s] = ident['rule_id'].to_s
          end
          out
        end

        # D-132: `index` je TEN ISTY `drawer_axes_index`, z ktoreho uz vznikli
        # chipy — druhy prechod ciel by znamenal druhe citanie receptov na
        # kazdy push. Bez neho (starsi volajuci, test) sa dormantnost
        # NEVYHODNOCUJE a payload je zhodny s tym spred D-132.
        def hardware_overrides_payload(cfg, overrides, index = nil)
          fronts = payload_fronts(cfg)
          items = cfg['hardware'].is_a?(Array) ? cfg['hardware'] : []
          owners = drawer_conflict_owners(cfg)
          # D-132 (review P3): dormantnost sa vyhodnocuje LEN nad DOVERYHODNYM
          # indexom. Ked citanie stavu osi zlyhalo (`trusted => false`), panel
          # o pripnutych receptoch nevie nic — a „neviem" nesmie znamenat
          # „zamok je mrtvy, zrus ho".
          trusted = index.is_a?(Hash) && index['trusted'] != false
          active = trusted ? active_lock_rules(index) : nil
          front_owners = trusted ? front_owner_keys(fronts) : nil
          Array(overrides).map do |ov|
            next ov unless ov.is_a?(Hash)

            row = ov.merge('owner_label' => PartKeys.human_label(ov['owner_part_key'], fronts: fronts))
            kind = HardwareRules.override_orphan_kind(ov, items, owners, active, front_owners)
            next row unless kind

            row = row.merge('orphan' => true, 'orphan_kind' => kind)
            next row unless kind == 'dormant'

            why = HardwareRules.override_dormant_why(ov, active, front_owners)
            row = row.merge('orphan_label' => dormant_label(ov),
                            'orphan_note' => dormant_note(ov, why, active))
            why == 'no_front' ? row.merge(dormant_gone_owner) : row
          end + orphan_part_material_rows(cfg, fronts)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hardware_overrides_payload')
          overrides
        end

        # `owner_part_key` panelov VSETKYCH existujucich ciel — odpoved na
        # otazku „existuje este celo, ktoremu zamok patril?". Kluc sa sklada
        # TOU ISTOU cestou ako v stavbe (`PartKeys.front`), nie retazenim.
        def front_owner_keys(fronts)
          Array(fronts).filter_map do |it|
            next nil unless it.is_a?(Hash)

            fid = it['id'].to_s
            fid.empty? ? nil : PartKeys.front(fid, 'panel')
          end
        end

        # D-132: TEXTY riadku dormantneho zamku sklada SERVER (vzor D-102) —
        # JS by na zlozenie vety potreboval vlastnu pravdu o tom, ktory recept
        # je pripnuty a ako sa vola. Nadpis nesie LEN osi, ktore zaznam naozaj
        # drzi; poznamka hovori DOVOD a cestu von.
        #
        # „Dormantný zámok · NL 470 · H144 · box 300" — poradie osi je to iste
        # ako v resolveri (vyska rozhoduje pred radom NL), formatuje `Recipes.fmt`.
        def dormant_label(ov)
          f = HardwareRules.override_lock_fields(ov)
          parts = []
          parts << "H#{f[Recipes::LOCK_HEIGHT_FIELD].to_i}" if f[Recipes::LOCK_HEIGHT_FIELD]
          parts << "box #{Recipes.fmt(f[Recipes::LOCK_BOX_FIELD])}" if f[Recipes::LOCK_BOX_FIELD]
          parts << "NL #{Recipes.fmt(f['nominal_length'])}" if f['nominal_length']
          (['Dormantný zámok'] + parts).join(' · ')
        end

        DORMANT_HINT = 'Zrušiť ho môžeš tu.'

        # D-132 (review P3): vlastnik zaznamu UZ NEEXISTUJE, takze popis nesmie
        # tvrdit „F9 · zásuvkové čelo" (cislo `F#` je poradie v resolved celach —
        # pri zaniknutom cele by `human_label` vratil SUROVE id a hlavicka boxu
        # by menovala celo, ktore v zakazke nie je). Riadok preto dostane vlastny
        # popis a priznak `orphan_owner_gone`, z ktoreho panel vie, ze taky box
        # NESMIE ponuknut oko „označ v modeli" — oznacovat niet co.
        def dormant_gone_owner
          { 'owner_label' => '(už neexistuje) · pôvodné zásuvkové čelo',
            'orphan_owner_gone' => true }
        end

        def dormant_note(ov, why, active)
          owner = ov['owner_part_key'].to_s
          mine = Recipes.id_label(ov['rule_id'].to_s.sub(Recipes::LOCK_RECIPE_PREFIX, ''))
          from = mine ? "Zámok receptu #{mine}" : 'Zámok'
          case why
          when 'other_recipe'
            now = Recipes.id_label((active || {})[owner].to_s.sub(Recipes::LOCK_RECIPE_PREFIX, ''))
            "#{from} — teraz je pripnutý #{now || 'iný recept'}, takže neplatí a čaká. #{DORMANT_HINT}"
          when 'not_drawer'
            "#{from} — čelo už nie je zásuvka, zámok čaká na návrat. #{DORMANT_HINT}"
          else
            "#{from} — čelo, ktorému patril, už neexistuje. #{DORMANT_HINT}"
          end
        end

        # KOV-C2b (Codex #304 P1): OSIROTENY materialovy override dielca zasuvky.
        # Zly zaznam (napr. 16,03 mm z modelu ulozeneho pred touto verziou) drzi
        # zasuvku vo fail-closed konflikte, dielec teda NEEXISTUJE — a karta
        # dielca sa da otvorit len pre dielec VO VYBERE. Bez tohto riadku by
        # zaznam nemal cestu von a exporty by ostali blokovane aj po reopen.
        # Riadok zije v TOM ISTOM zozname ako osirotene rucne zasahy kovania:
        # sekcia Kovanie je miesto, kam pouzivatela posiela hlaska konfliktu.
        def orphan_part_material_rows(cfg, fronts)
          CabinetBuilder.orphan_drawer_part_overrides(cfg).map do |r|
            { 'orphan' => true, 'orphan_kind' => 'part_material', 'part_key' => r['part_key'],
              'owner_part_key' => r['owner_part_key'], 'generic_type' => '', 'rule_id' => '',
              'material_id' => r['material_id'],
              'orphan_label' => "Ručný materiál · #{Recipes.role_label(r['role'])}",
              'owner_label' => PartKeys.human_label(r['owner_part_key'], fronts: fronts) }
          end
        rescue StandardError => e
          Engine.log_error(e, 'Panel.orphan_part_material_rows')
          []
        end

        # `owner_part_key` ciel v konflikte — autorita je `CabinetBuilder`.
        def drawer_conflict_owners(cfg)
          CabinetBuilder.drawer_conflict_owners(cfg)
        end

        # Resolved cela poslednej stavby — zdroj cisla „F2" (D-92).
        def payload_fronts(cfg)
          cfg['front_items'].is_a?(Array) ? cfg['front_items'] : []
        end

        # D-92: doplni owner_label + purchase. Zlyhanie TU nesmie zhodit cely
        # payload skrinky (panel by ostal prazdny) — vrati sa aspon holy zoznam.
        def decorate_hardware_purchase(cfg, items)
          return items if items.empty?

          fronts = payload_fronts(cfg)
          status, state = hardware_read_state
          # R-07 (review P2-3): pri nekompatibilnej kniznici a projekte BEZ
          # snapshotu sa musi panel spravat PRESNE ako supis (ProductionCore.
          # hardware_expansion): override skrinky sa NEUPLATNI (ukazuje na
          # set_id, ktoreho definicia by musela prist prave z tej kniznice)
          # a dovod je `library_incompatible`. Inak by panel radil „priraď
          # set", hoci pricina je uplne ina a set uz priradeny je.
          blocked = status == :missing && HardwareSets.library_read_only?
          overrides = blocked ? {} : cabinet_set_overrides(cfg)
          # Katalog sa cita LEN ked skrinka nejake kovanie ma (guard vyssie) a
          # mapa kod=>polozka sa stavia RAZ pre cely payload (audit D-92 FIX 3).
          # HardwareCatalog.items pritom moze pri PRVOM citani v sedeni zaseedovat
          # globalnu kniznicu — je to VEDOMY kontrakt (rovnako ako HardwareSets.load
          # v tom istom payloade): bez seedu by panel pri cerstvej instalacii
          # tvrdil „mimo katalógu" pri kazdom kode, co je horsie nez zapis do
          # %APPDATA%. Model sa NIKDY nedotkne.
          lookup = HardwareSets.catalog_lookup(HardwareCatalog.items)
          items.map do |h|
            next h unless h.is_a?(Hash)

            h.merge('owner_label' => PartKeys.human_label(h['owner_part_key'], fronts: fronts),
                    'purchase' => item_purchase(h, status, state, overrides, lookup,
                                                blocked: blocked))
          end
        rescue StandardError => e
          Engine.log_error(e, 'Panel.decorate_hardware_purchase')
          items
        end

        # Poskodeny snapshot setov (:invalid) sa NIKDY nedopocitava z globalu —
        # expanzia pri nom vedome nemapuje nic, takze aj panel musi povedat
        # pravdu a poslat pouzivatela tam, kde sa to da opravit.
        INVALID_SETS_SK = 'sety projektu sú poškodené — obnov ich v Katalógu kovania (Predvoľby projektu)'

        def item_purchase(item, status, state, overrides, lookup, blocked: false)
          if status == :invalid
            return { 'set_id' => nil, 'set_name' => nil, 'members' => [],
                     'problems' => [INVALID_SETS_SK] }
          end
          HardwareSets.explain(item, state, overrides: overrides, lookup: lookup,
                                            no_set_reason: (blocked ? 'library_incompatible' : 'no_set'))
        end

        # Override mapa setov TEJTO skrinky (moze mat composite kluce gt@owner
        # a selector hodnoty — parser je jedina autorita tvaru).
        # KOV-G2 (Codex #339 kolo 1 N1): kluc sa cita v OBOCH tvaroch. Ulozeny
        # config (`Store.config`) ma kluce STRINGOVE, ale nahlad vkladania aj
        # zmrazeny plan ghostu pracuju s vysledkom `CabinetBuilder.normalize`,
        # teda so SYMBOLMI — a ten by inak vratil prazdnu mapu a nahlad by
        # prehliadol vyber setu zo sablony.
        def cabinet_set_overrides(cfg)
          raw = cfg.is_a?(Hash) ? (cfg['hardware_sets'] || cfg[:hardware_sets]) : nil
          HardwareSets.normalize_mapping(raw.is_a?(Hash) ? raw : {}, nil, allow_owner: true)
        end

        # Projektovy stav setov NA CITANIE (ziadny zapis do modelu):
        #   :ok      — snapshot projektu
        #   :missing — projekt snapshot este nema, plati globalna kniznica
        #              (zmrazi ju az stavba/zmena — citanie model nemeni)
        #   :invalid — poskodeny snapshot: ziadne mapovanie, ziadny fallback
        # -> [status, { 'mapping' =>, 'sets' => }]
        def hardware_read_state
          model = Sketchup.active_model
          status, state = HardwareSets.project_state_status(model)
          return [status, state] if status == :ok && state
          if status == :missing
            # R-07 (audit BLOCKER 1): nekompatibilna kniznica sa NEPOUZIVA ani
            # tu — `load` z nej nic nevyda, takze rozklik polozky v paneli
            # nerozpise kody, ktore v supise (ProductionCore) vzniknut nemozu.
            # Panel a supis sa rozist NESMU (lekcia R-06a).
            lib = HardwareSets.load
            sets = {}
            lib['sets'].each { |s| sets[s['set_id']] = s }
            return [status, { 'mapping' => lib['mapping'], 'sets' => sets }]
          end
          [status, { 'mapping' => {}, 'sets' => {} }]
        end

        # Ponuka setov pre typy kovania, ktore skrinka realne ma: projektove
        # mapovanie (snapshot; missing = global default NA CITANIE — zmrazi ho
        # az stavba/zmena), sety z GLOBALU + aktualne mapovany/overridnuty zo
        # SNAPSHOTU (v globale uz nemusi byt). invalid = prazdna ponuka + flag.
        def hardware_set_options(cfg, hardware)
          status, state = hardware_read_state
          snap_sets = state['sets']
          proj_map = state['mapping']
          # R-07: ponuka setov v paneli nesmie ponukat definicie z kniznice,
          # ktoru sa nesmie POUZIT (vyber by ju skopiroval do .skp) — `load`
          # z nej nic nevyda.
          globals = HardwareSets.load['sets']
          # H1a: override mapa moze mat composite kluce (gt@owner) a hodnota
          # moze byt selector — parser je jedina autorita tvaru; ponuku setov
          # sklada HardwareSets.set_options (definicia zo SNAPSHOTU vyhrava nad
          # globalom pre referencovane set_id — audit BLOCKER 4).
          overrides = cabinet_set_overrides(cfg)
          refs = HardwareSets.referenced_set_ids(proj_map, 'cab' => overrides)
          types = Array(hardware).filter_map { |h| h.is_a?(Hash) ? h['generic_type'].to_s : nil }
                                 .reject(&:empty?).uniq
          # KOV-D1a: typ z kluca cita JEDINA autorita (`mapping_key_type`) —
          # pozna aj triedny a owner triedny kluc, ktory `parse_hardware_set_key`
          # odmieta (a riadok kovania by pre override chybal).
          overrides.each_key do |k|
            t = HardwareSets.mapping_key_type(k)
            types |= [t] if t
          end
          types.map do |gt|
            opts = HardwareSets.set_options(gt, globals, snap_sets, refs)
            proj_val = proj_map[gt]
            ov_val = overrides[gt]
            proj_sid = proj_val.is_a?(String) ? proj_val : nil
            proj_name = proj_sid && (opts.find { |s| s['set_id'] == proj_sid } || {})['name']
            {
              'generic_type' => gt,
              'label' => HardwareRules.label_for(gt),
              'project_set_id' => proj_sid,
              'project_set_name' => proj_name,
              # H1b vykresli vyber podla parametra; H1a ho len verne prenasa.
              'project_selector' => (proj_val.is_a?(Hash) ? proj_val : nil),
              # H1b: hotovy text prvej volby selectu — SERVER je autorita
              # (JS ziadny vlastny preklad selectora nema).
              'project_label' => project_set_label(proj_val, proj_name),
              'override_set_id' => (ov_val.is_a?(String) ? ov_val : nil),
              'override_selector' => (ov_val.is_a?(Hash) ? ov_val : nil),
              'override_label' => (ov_val.is_a?(Hash) ? HardwareSets.param_by(ov_val['param']) : nil),
              # H1b (D-81): vybery na urovni VLASTNIKA (kluc "gt@owner_part_key")
              # — panel ich vykresli priamo v riadku kovania toho dielca.
              'owner_overrides' => owner_set_overrides(overrides, gt, hardware),
              'owner_default_label' => owner_default_label(ov_val, proj_val, opts, proj_name),
              # KOV-D1b: ponuka pre KLASIFIKOVANE polozky (zasuvky) — triedny
              # kluc, len kompatibilne moznosti. `nil` = typ klasifikovanu
              # polozku nema a karta kresli povodny plochy zoznam setov.
              'compat' => class_compat_payload(gt, hardware, overrides, proj_map,
                                               globals, snap_sets, refs),
              'status' => status.to_s,
              'options' => opts.map { |s| { 'set_id' => s['set_id'], 'name' => s['name'] } }
            }
          end
        end

        # === KOV-D1b: PREPNUTIE SETU NA KLASIFIKOVANEJ ZASUVKE ================
        #
        # Pri KLASIFIKOVANEJ polozke (celo nesie otvaranie + konstrukciu) cita
        # resolver TRIEDNY kluc — genericky `slide` uz nie (KOV-C2a). Plochy
        # zoznam setov typu je preto pre kartu zla ponuka hned dvakrat: obsahuje
        # sety inej triedy A pri Atire ponuka PEVNY set tam, kde sa smie ulozit
        # len vyber podla vyskoveho variantu (Astra #19 B1).
        #
        # Ponuku preto sklada SERVER (`HardwareSets.class_set_options`) a karta
        # ju len kresli: pre CELU SKRINKU (ked su vsetky klasifikovane polozky
        # typu z JEDNEJ triedy) aj pre KAZDE CELO zvlast. Hodnota, ktoru panel
        # posle spat, ide existujucou akciou `set_hardware_set` — kluc z nej
        # sklada `HardwareSets.apply_cabinet_override` (D1a), nie panel.
        # -> { 'cab' => scope, 'owners' => { owner => scope } } | nil
        def class_compat_payload(gt, hardware, overrides, proj_map, globals, snap_sets, refs)
          active = active_class_by_owner(hardware, gt)
          classes = active.values.uniq
          return nil if classes.compact.empty?

          defs = compat_defs(globals, snap_sets)
          out = { 'cab' => nil, 'owners' => {} }
          # Skrinkovy riadok len pri JEDNEJ triede — pri zmiesanych triedach by
          # jeden kluc platil len na cast poloziek (`override_class_key` taky
          # zapis odmietne, takze ho karta ani nesmie ponukat).
          # Codex #310 kolo 1 P2-2: ZMIESANA je aj skrinka, kde vedla
          # klasifikovanej zasuvky stoji LEGACY neklasifikovany vysuv — v `active`
          # je vtedy `nil`. `compact` by ho zahodil a karta by vykreslila
          # skrinkovy ovladac, ktoreho KAZDA volba by skoncila odmietnutim.
          if classes.length == 1 && !classes.first.nil?
            out['cab'] = compat_scope(classes.first, nil, overrides, proj_map,
                                      globals, snap_sets, refs, defs)
          end
          active.each do |owner, ck|
            next if ck.nil?

            out['owners'][owner] = compat_scope(ck, owner, overrides, proj_map,
                                                globals, snap_sets, refs, defs)
          end
          out
        end

        # Definicie na CITANIE ulozenej hodnoty: snapshot vyhrava nad globalom
        # (podla neho sa nakupuje — audit BLOCKER 4).
        def compat_defs(globals, snap_sets)
          out = {}
          Array(globals).each { |s| out[s['set_id'].to_s] = s if s.is_a?(Hash) }
          (snap_sets.is_a?(Hash) ? snap_sets : {}).each { |sid, s| out[sid.to_s] = s if s.is_a?(Hash) }
          out
        end

        # Jeden rozsah vyberu (skrinka alebo konkretne celo).
        #   none_label — co plati BEZ vlastneho vyberu („vrátiť na projekt")
        #   current    — ID volby z ponuky, ktora je ulozena
        #   stored     — ulozena hodnota, ktora v ponuke NIE JE (neaktivny set,
        #                set z novsej verzie): zobrazi sa, vybrat sa nedá (F10)
        def compat_scope(class_key, owner, overrides, proj_map, globals, snap_sets, refs, defs)
          key = owner ? "#{class_key}@#{owner}" : class_key
          value = overrides[key]
          inherited = owner ? (overrides[class_key] || proj_map[class_key]) : proj_map[class_key]
          opts = HardwareSets.class_set_options(class_key, globals, snap_sets, refs)
          cur = HardwareSets.mapping_option_id(value)
          known = !cur.nil? && opts.any? { |o| o['id'] == cur }
          { 'class_key' => class_key,
            'class_label' => HardwareSets.class_key_label(class_key),
            'scope_label' => (owner ? 'Set pre toto čelo' : 'Set pre túto skrinku'),
            'none_label' => compat_none_label(owner, overrides[class_key], inherited, defs),
            'options' => opts, 'current' => (known ? cur : nil),
            'stored' => (!value.nil? && !known),
            'value_text' => HardwareSets.mapping_value_text(value, defs) }
        end

        # „podľa projektu — Atira biela — klasické · podľa výšky zásuvky (…)".
        # Na urovni CELA sa prizna, ci hodnota prichadza zo skrinky alebo
        # z projektu — poradie ako v `HardwareSets.resolve_set_id`.
        def compat_none_label(owner, cab_value, inherited, defs)
          src = (owner && !cab_value.nil?) ? 'skrinky' : 'projektu'
          "podľa #{src} — #{HardwareSets.mapping_value_text(inherited, defs)}"
        end

        # Prva volba selectu setu na SKRINKE = co plati z projektu.
        def project_set_label(proj_val, proj_name)
          return "podľa projektu — #{HardwareSets.param_by(proj_val['param'])}" if proj_val.is_a?(Hash)
          return "podľa projektu — #{proj_name || proj_val}" if proj_val.is_a?(String)

          'podľa projektu — bez setu'
        end

        # Co plati na dielci, ked na nom vlastny vyber NIE JE (tooltip riadku):
        # vyber skrinky prebija projekt (poradie ako v HardwareSets.resolve_set_id).
        def owner_default_label(ov_val, proj_val, opts, proj_name)
          if ov_val.is_a?(Hash)
            "podľa skrinky — #{HardwareSets.param_by(ov_val['param'])}"
          elsif ov_val.is_a?(String)
            name = (opts.find { |s| s['set_id'] == ov_val } || {})['name'] || ov_val
            "podľa skrinky — #{name}"
          else
            project_set_label(proj_val, proj_name)
          end
        end

        # { owner_part_key => { 'set_id' | 'selector' } } pre jeden typ kovania.
        # KOV-D1a: vyber na urovni vlastnika ma DVA tvary — legacy composite
        # `typ@owner` a OWNER TRIEDNY `class:slide|classic|metal@front:F1/panel`.
        # Karta cela musi ukazat AKTUALNU volbu aj pri druhom (inak by select
        # vyzeral prazdny a prvy klik vedla by ulozeny vyber ticho prepisal).
        # KOV-D1a (Codex #308 kolo 2 P2): emituje sa LEN kľúč, ktorý resolver pre
        # dielec NAOZAJ číta — teda owner TRIEDNY kľúč zhodný s AKTÍVNOU triedou
        # položky, a legacy `typ@owner` len tam, kde položka klasifikáciu nemá.
        # Bez toho by po zmene otvárania/konštrukcie karta ukazovala DORMANTNÝ
        # výber starej triedy ako vybraný a mazanie by cielilo na iný kľúč.
        def owner_set_overrides(overrides, gt, hardware)
          active = active_class_by_owner(hardware, gt)
          out = {}
          overrides.each do |key, val|
            owner = HardwareSets.owner_scoped_key?(key) ? owner_of_set_key(key) : nil
            next unless owner && HardwareSets.mapping_key_type(key) == gt

            if HardwareSets.class_mapping_key?(key)
              canon, = HardwareSets.parse_class_key(key, allow_owner: true)
              next unless canon && HardwareSets.class_key_without_owner(canon) == active[owner]
            else
              next if active[owner] # klasifikovana polozka legacy kluc NECITA
            end

            out[owner] =
              if HardwareSets.invalid_mapping_value?(val)
                # Kluc JE v configu, ale hodnota je poskodena — karta to musi
                # priznat, nie ukazat prazdny select (a uz vobec nie hodnotu
                # z nizsej urovne).
                { 'invalid' => true }
              elsif val.is_a?(Hash)
                { 'selector' => true, 'label' => HardwareSets.param_by(val['param']) }
              else
                { 'set_id' => val.to_s }
              end
          end
          out
        end

        # `owner_part_key` => AKTIVNY triedny kľúč položky (nil = neklasifikovaná).
        def active_class_by_owner(hardware, gt)
          out = {}
          Array(hardware).each do |it|
            next unless it.is_a?(Hash) && it['generic_type'].to_s == gt

            owner = it['owner_part_key'].to_s
            next if owner.empty?

            out[owner] = HardwareSets.class_key_for(it, gt)
          end
          out
        end

        # `owner_part_key` z kluca mapovania (oba tvary) alebo nil.
        def owner_of_set_key(key)
          if HardwareSets.class_mapping_key?(key)
            canon, = HardwareSets.parse_class_key(key, allow_owner: true)
            return canon && HardwareSets.class_key_split(canon)[1]
          end
          parsed = BuildPlan.parse_hardware_set_key(key)
          parsed && parsed[1]
        end

        # existujuce params korpusu (na zachovanie casti pri ciastocnej zmene)
        def existing_params(cab)
          CabinetBuilder.config_to_params(Store.config(cab) || {})
        end

        # H2 (D-76): sablona nesie AJ kovanie — mapovanie setov + ZMRAZENE
        # definicie, aby sa dala pouzit v inom projekte aj na inom PC.
        # model = zdroj definicii (snapshot projektu pred globalnou kniznicou);
        # bez modelu (legacy volanie) sa sety do sablony neukladaju;
        # rucne polozky od modelu nezavisia.
        def template_config_from(cfg, model: nil, with_hardware: true)
          tc = {
            # R-12: aj sablona je uzavrety whitelist, takze nesie marker
            # kontraktu configu. Stampuje sa AKTUALNA hodnota (zaznam prave
            # vyrobil TENTO whitelist), nie hodnota zo zdrojovej skrinky —
            # zdroj z novsej verzie sa do sablony vobec nedostane
            # (`handle_save_template_as` ho odmietne). Vdaka markeru starsi
            # plugin sablonu z novsej verzie rozozna a nepouzije ju.
            'config_schema' => CabinetBuilder::CONFIG_SCHEMA,
            'type' => cfg['type'], 'width' => cfg['width'], 'height' => cfg['height'], 'depth' => cfg['depth'],
            'thickness' => cfg['thickness'], 'floor_height' => cfg['floor_height'],
            'bottom_mode' => cfg['bottom_mode'], 'top_mode' => cfg['top_mode'], 'back_mode' => cfg['back_mode'],
            'back_thickness' => cfg['back_thickness'] || 3.0,
            'plinth_mode' => cfg['plinth_mode'], 'plinth_recess' => cfg['plinth_recess'],
            'rail_depth' => cfg['rail_depth'], 'rails_orientation' => cfg['rails_orientation'],
            'rails_top_offset' => cfg['rails_top_offset'],
            'zone_tree' => cfg['zone_tree'] || ZoneTree.default_tree((cfg['shelves'] || 0).to_i),
            'fronts' => Fronts.normalize_config(cfg['fronts'])
          }
          # S1-E: polia SLOTU cestuju so sablonou — bez nich by z „Umývačky 60"
          # vznikol slot s generickymi rozmermi namiesto tych ulozenych.
          CabinetBuilder::DW_KEYS.each { |k| tc[k.to_s] = cfg[k.to_s] if cfg.key?(k.to_s) }
          # S1-E (R2c): sablona nesie OCAKAVANIE (`appliance_expects[]`), NIKDY
          # vazbu na konkretny spotrebic — ten je majetkom JEDNEJ skrinky
          # v JEDNEJ zakazke a v sablone by z neho bola sirota.
          tc['appliance_expects'] = cfg['appliance_expects'] if cfg['appliance_expects'].is_a?(Array)
          # V0.3 FIX 1: korpusove materialy do sablony LEN ak su na zdroji nastavene (non-nil).
          # part_overrides do sablony NEUKLADAME — su viazane na konkretne dielce/zony zdroja
          # (pri aplikacii sablony sa zachovaju z cieloveho korpusu).
          # KOV-C2b: `drawer_material_id` (4. kanal) cestuje so sablonou
          # rovnako ako ostatne korpusove materialy — LEN ked je nastaveny.
          %w[material_id front_material_id back_material_id drawer_material_id].each do |k|
            v = present_str(cfg[k])
            tc[k] = v if v
          end
          # KOV-I: vypnuta volba vynecha CELE kovanie aj jeho kontroly.
          # Materialove kanaly a recepty vo fronts ostavaju konstrukciou.
          return tc unless with_hardware

          # KOV-H1: pri zapnutej volbe ostava kluc aj prazdny. Jeho absencia
          # pri aplikacii sablony znamena zachovat rucne polozky ciela.
          tc['hardware_manual'] = CabinetBuilder.norm_hardware_manual(cfg['hardware_manual'])
          add_template_hardware(tc, cfg, model)
        end

        # H2 (D-76): kovanie do sablony. Composite kluce „typ@owner_part_key" sa
        # NEUKLADAJU (audit BLOCKER 1) — owner_part_key su per-skrinka generovane
        # ID (front:F1/panel je v kazdej skrinke INY dielec), takze prenosne nie
        # su; normalizacia s allow_owner: false ich zahodi. Sablona bez kovania
        # nedostane ziadny kluc — merge pri aplikacii tak rozozna, ze mapovanie
        # ciela sa ma zachovat (legacy/seed sablony).
        def add_template_hardware(tc, cfg, model)
          return tc unless model && defined?(HardwareSets)

          map = HardwareSets.normalize_mapping(cfg['hardware_sets'], nil, allow_owner: false)
          return tc if map.empty?

          # GH #133 P2: poskodeny snapshot projektu (:invalid) = definicie by sa
          # dobrali z GLOBALU a sablona by niesla kody, ktore zdrojovy model
          # nepouziva. Radsej sablona BEZ kovania (a hlaska pouzivatelovi).
          defs = HardwareSets.template_set_defs(model, map)
          if defs.nil?
            # KOV-I (Michal): poskodene sety = BEZ VSETKEHO kovania.
            tc.delete('hardware_manual')
            return tc
          end

          tc['hardware_sets'] = map
          tc['hardware_set_defs'] = defs unless defs.empty?
          tc
        rescue StandardError => e
          Engine.log_error(e, 'Panel.add_template_hardware')
          %w[hardware_sets hardware_set_defs hardware_manual].each { |k| tc.delete(k) }
          tc
        end

        # GH #133 P2: hlaska, ked skrinka kovanie MA, ale do sablony sa neulozilo
        # (poskodene sety projektu). Ticho by pouzivatel dostal „prazdnu" sablonu.
        def template_save_hardware_note(cfg, tc, model, with_hardware: true)
          return '' unless with_hardware
          return '' unless model && defined?(HardwareSets)
          return '' if tc.is_a?(Hash) && tc.key?('hardware_sets')
          return '' if HardwareSets.normalize_mapping(cfg['hardware_sets'], nil,
                                                      allow_owner: false).empty?

          # R-07 (review P2-4): dôvod môže byť aj nekompatibilná globálna
          # knižnica — vtedy sa definície setov nedajú rozložiť a šablóna by
          # niesla mapovanie BEZ definícií. Hláška musí poslať používateľa
          # tam, kde sa to naozaj opravuje.
          if HardwareSets.library_read_only?
            return " Šablóna uložená BEZ kovania — #{HardwareSets.library_state_reason}."
          end

          ' Šablóna uložená BEZ kovania — sety projektu sú poškodené ' \
            '(obnov ich v Katalógu kovania, Predvoľby projektu).'
        rescue StandardError => e
          Engine.log_error(e, 'Panel.template_save_hardware_note')
          ''
        end

        # H2 (D-76): SPOLOCNA zapisova cesta setov zo sablony — aplikacia
        # sablony (okno Sablony) aj vklad zo sablony (quick-pick v paneli).
        # VOLAT LEN vnutri operacie stavby (rebuild_many / build blok): zlyhanie
        # vyhodi vynimku a cela operacia sa zrusi — ziadna skrinka s
        # nezmrazenym setom. Vrati poznamku do statusu (SK, moze byt prazdna).
        def freeze_template_hardware!(model, mapping, defs)
          res = HardwareSets.freeze_template_sets!(model, mapping, defs)
          case res['status']
          when :invalid
            raise 'Sety kovania projektu sú poškodené — obnov ich v Katalógu kovania ' \
                  '(Predvoľby projektu), potom šablónu použi znova.'
          when :blocked
            # R-07 (review P2-4): nekompatibilna kniznica NESMIE zhodit vkladanie
            # skrinky — kontrakt davky znie „stavba bezi dalej, len bez
            # snapshotu" (cabinet_builder). Skrinka teda vznikne, kovanie sa
            # nezmrazi a hlaska povie SKUTOCNY dovod (nie „sety projektu su
            # poskodene", ktore by poslalo pouzivatela opravovat zdravy .skp).
            return " · kovanie zo šablóny sa nepriradilo: #{HardwareSets.library_state_reason}"
          when :failed
            raise 'Sety kovania zo šablóny sa nepodarilo zapísať do projektu — nič sa nezmenilo.'
          end
          template_hardware_note(res)
        end

        # Hlaska o setoch zo sablony. Kolizie sa NIKDY nezamlcia: projekt si drzi
        # vlastnu verziu setu a pouzivatel to musi vediet.
        def template_hardware_note(res)
          return '' unless res.is_a?(Hash)

          out = ''
          out += " · sety kovania zo šablóny doplnené (#{res['added'].join(', ')})" unless res['added'].empty?
          res['kept'].each { |sid| out += " · set „#{sid}“: projekt používa vlastnú verziu" }
          res['type_mismatch'].each { |sid| out += " · set „#{sid}“ je iného typu kovania — nepoužil sa" }
          res['missing'].each { |sid| out += " · set „#{sid}“ v projekte chýba — kovanie ostáva nepriradené" }
          out
        end

        def template_config_from_fields(data)
          tc = template_config_from(data)
          tc['zone_tree'] = data['zone_tree'] || ZoneTree.default_tree(0)
          tc['fronts'] = Fronts.normalize_config(data['fronts'])
          tc
        end

        # UI-C1a: zoznam nesie IDENTITU sablony (`kind` + `name`) a poradove
        # cislo posledneho pouzitia (`used_seq`, nil = nikdy nepouzita) — z neho
        # sklada vkladacia karta poradie „Naposledy pouzite". Cislo zije v inom
        # subore (TemplateUsage), takze subor sablon sa vlozenim NEMENI (N11).
        # kind: filter pouziva okno Sablony — spravuje VYHRADNE korpusove.
        # `previews:` (UI-D2) — pripoji TRANSIENTNE `preview_rev` (odtlacok PNG
        # suboru, nil = sablona nahlad nema). Pripaja sa cez `t.merge` (novy
        # hash, zaznam sa NEMUTUJE) presne ako `used_seq`, takze sa do
        # `templates.json` nikdy nezapise — nezname kluce zaznamu inak zapis
        # PREZIJU a schema by sa ticho rozsirila. Samotne PNG NEIDE tymto
        # kanalom: panel si ho vypyta zvlast (`nx_template_preview`).
        # Okno Sablony nahlady nekresli, preto ich ani nedostava (default false
        # setri `File.stat` pri kazdom refreshi).
        # `usage:` (1b-4, B3) — `used_seq` potrebuje LEN vkladacia karta panela
        # („Naposledy použité"). Sekcia `tpl` Studia poradie nekresli, a kedze
        # `TemplateUsage.map` je DALSIE citanie suboru z %APPDATA%, pyta si
        # zoznam s `usage: false`. Default ostava `true` — panelova cesta sa
        # nemeni ani o riadok.
        def template_list(kind: nil, previews: false, usage: true)
          seq = usage ? TemplateUsage.map : nil
          TemplateStore.load.each_with_object([]) do |t, out|
            next if kind && t['kind'] != kind

            # `dup` aj v druhej vetve: kontrakt „zaznam sa NEMUTUJE" plati pre
            # obe cesty rovnako (merge vracia novy hash, holy zaznam by bol
            # POVODNY objekt zo skladu).
            rec = seq ? t.merge('used_seq' => seq["#{t['kind']}:#{t['name']}"]) : t.dup
            rec['hardware'] = TemplateStore.hardware_tile_summary(t['config'])
            rec = rec.merge('preview_rev' => TemplatePreviews.rev_for(t['kind'], t['name'])) if previews
            out << rec
          end
        rescue StandardError => e
          Engine.log_error(e, 'template_list')
          []
        end

        def suggest_template_name(cab, _data)
          cab ? "Kopia #{Store.get(cab, 'cabinet_id')}" : 'Nova sablona'
        end

        # --- V0.3 materialy + ABS: payloady a resolvery ---------------------

        # Katalog pre selecty: dosky (id + label) + ABS pasky (id + label + farba pre nahlad hrany).
        # 2A-3b (audit F11): catalog_schema = rezim katalogu pre JS zrkadlo
        # (absUsableExists/Odporucane) — JS sa o SCHEMA 2 dozveda VYHRADNE
        # odtialto, nikdy z pritomnosti group_id. Zaznamy nesu group_id/
        # structure (+universal pri ABS) LEN ked existuju (prazdne kluce sa
        # neposielaju — zrkadlo katalogovej semantiky).
        def materials_payload
          ctx = label_ctx # 2A-4b: kolizie cisla dekoru raz pre cely payload
          fam = row_fam_ctx(ctx) # PICKER-2: kolizie DEKOROVYCH menoviek, tiez raz
          {
            'catalog_schema' => Materials.catalog_schema,
            'sheets' => Materials.sheets.map { |s|
              # grain (V0.4.7c, Codex GH #33): vkladacia karta dosky predvyplna smer
              # dekoru z katalogu — bez grain by formular posielal nespravny default.
              # V0.6 M-B1: 'uni' => true LEN pri UNI (JS filtre/badge/board karta).
              base = { 'id' => s['material_id'], 'label' => sheet_label(s, ctx), 'decor' => s['decor'],
                       'thickness' => s['thickness'], 'color' => s['color'], 'grain' => s['grain'],
                       # M-C (GH #118 P2): typ + hranova uprava PD — JS zrkadlo
                       # potlacenia ABS (absUsableForSheet) ich potrebuje, inak
                       # by kompakt/postforming otvaral modal "Vytvorit pasku".
                       'type' => s['type'],
                       # PICKER-2: dekorova menovka BEZ hrubky + identita
                       # variantovej rodiny. Vyhladavac z nich sklada jeden
                       # riadok na dekor s hrubkami na cipoch — hranicu urcuje
                       # KATALOG (vyrobca, struktura, format, rub), nie klient.
                       'row_label' => sheet_row_label(s, ctx, fam),
                       'row_key' => Materials.variant_family_key(s) }
              # DUPLAK z KATALOGU (review #231 P1): zdvojena doska ma bezne
              # `material_id` a pozna sa VYHRADNE podla `source_material_id` —
              # bez tohto priznaku by v ponuke vyzerala ako kupena hruba doska
              # a nedala by sa najst ani hladanim „duplak".
              base['duplak'] = true unless s['source_material_id'].to_s.strip.empty?
              base['pd_edge_subtype'] = s['pd_edge_subtype'] unless s['pd_edge_subtype'].to_s.empty?
              # UI-C1b: `uni_role` je ZRKADLO katalogoveho pola (rovnaky vzor ako
              # pd_edge_subtype) — vkladacia karta z neho vyberie UNI material
              # ROLY DOSKA, ked doskova sablona nesie material_id: nil (kontrakt
              # hrubky, viz core/templates.rb board_tpl). Bez roly by karta
              # dosadila ktorykolvek UNI zaznam (napr. Korpus UNI).
              if Materials.uni?(s)
                base['uni'] = true
                base['uni_role'] = s['uni_role'] unless s['uni_role'].to_s.empty?
              end
              base.merge(schema2_mirror_fields(s))
            },
            'edges' => Materials.edges.map { |a|
              { 'id' => a['abs_id'], 'label' => abs_label(a, ctx), 'decor' => a['decor'],
                'thickness' => a['thickness'], 'width' => a['width'], 'color' => a['color'] }
                .merge(schema2_mirror_fields(a, universal: true))
            },
            # D-49 (audit B3): virtualne polozky "(duplak x2)" — SAMOSTATNE pole
            # (NIE sheets: vkladanie dosky a projektove selecty ich nesmu vidiet).
            # Konzumuju ich VYHRADNE selecty tela korpusu, dielca a karty dosky;
            # vyber posle "duplak2:<id>" a server ho rozriesi ensure_duplak_for.
            'duplak_offers' => duplak_offers(ctx),
            # D-85 (UI-03): id POUZITE V TEJTO ZAKAZKE — zdroj sekcie „Použité
            # v projekte" v comboboxe. ODVODENY udaj (ziadna nova schema, ziadny
            # zapis do modelu), cisty read-only scan configov.
            'used_ids' => used_ids_payload
          }
        rescue StandardError => e
          Engine.log_error(e, 'materials_payload')
          { 'sheets' => [], 'edges' => [] }
        end

        # D-85: „Použité v projekte" = tato ZAKAZKA, nie globalna kniznica —
        # zdroje typu „šablóna X" sa preto vyhadzuju (sablony su spolocna kniznica
        # oboch pocitacov, nie obsah otvoreneho modelu). Projektove predvolby
        # zakazkou SU, takze ostavaju. Cita sa vyhradne (Materials.used_*_ids
        # su read-only scany) — payload nesie len ID, nic ine.
        def used_ids_payload
          model = Sketchup.active_model
          { 'sheets' => used_model_ids(Materials.used_material_ids(model)),
            'edges' => used_model_ids(Materials.used_abs_ids(model)) }
        rescue StandardError => e
          Engine.log_error(e, 'used_ids_payload')
          { 'sheets' => [], 'edges' => [] }
        end

        TEMPLATE_SOURCE_PREFIX = 'šablóna '

        # Z mapy {id => [zdroje]} nechaj id, ktore ma ASPON JEDEN zdroj mimo sablon.
        def used_model_ids(map)
          (map || {}).each_with_object([]) do |(id, sources), out|
            next if id.to_s.empty?
            next unless Array(sources).any? { |s| !s.to_s.start_with?(TEMPLATE_SOURCE_PREFIX) }

            out << id.to_s
          end
        end

        # D-49: ponuka virtualnych duplakov (zdroje bez existujuceho duplaku a
        # bez kupovanej dosky tej istej identity — autorita Materials).
        def duplak_offers(ctx = label_ctx)
          Materials.duplak_offer_sources(2).map do |s|
            th2 = (s['thickness'].to_f * 2).round(2)
            { 'id' => "duplak2:#{s['material_id']}",
              'label' => "#{sheet_label(s, ctx)} ×2 → #{fmt_mm(th2)} (duplák)",
              'thickness' => th2 }
          end
        rescue StandardError => e
          Engine.log_error(e, 'duplak_offers')
          []
        end

        # 2A-3b (F11): SCHEMA 2 polia zaznamu do payloadu — bez prazdnych klucov.
        def schema2_mirror_fields(rec, universal: false)
          out = {}
          gid = rec['group_id'].to_s.strip
          out['group_id'] = gid unless gid.empty?
          st = rec['structure'].to_s.strip
          out['structure'] = st unless st.empty?
          out['universal'] = true if universal && rec['universal'] == true
          out
        end

        # 2A-4b (audit F10): kontext labelov. V SCHEMA 2 sa rovnake cislo dekoru
        # moze LEGALNE opakovat u dvoch vyrobcov (dve skupiny) — label vtedy
        # MUSI niest vyrobcu, inak su selecty nejednoznacne. Vyrobca sa pridava
        # VYHRADNE pri kolizii (bezny katalog ostava kratky). V SCHEMA 1 je
        # ctx nil a labely su PRESNE dnesne (dual-mode). Hot loops si ctx
        # postavia RAZ a posielaju ho dalej (default je pre pohodlie volajucich
        # s jednym zaznamom).
        # GH #93 P2 (8. kolo): kolizie sa detegujú z PLNE ZLOZENEHO zakladu
        # (cislo+struktura+nazov), nie zo sameho cisla — "K009 PW"+"" a
        # "K009"+"PW" skladaju rovnaky text z ROZNYCH skupin. Dve urovne:
        # 'collisions' (zaklad zdielaju rozne skupiny -> pridaj vyrobcu),
        # 'hard' (aj s vyrobcom zhodny -> pridaj [group_id]).
        def label_ctx
          return nil unless Materials.catalog_schema >= Materials::SCHEMA_GROUPS
          reg = Materials.v3_groups_registry
          group_man = reg.transform_values { |g| g['manufacturer'] }
          num_groups = Hash.new { |h, k| h[k] = [] }
          base_groups = Hash.new { |h, k| h[k] = [] }
          man_groups = Hash.new { |h, k| h[k] = [] }
          (Materials.sheets + Materials.edges).each do |r|
            gid = r['group_id'].to_s.strip
            gkey = gid.empty? ? "man:#{r['manufacturer'].to_s.strip}" : gid
            nkey = Materials.identity_norm(r['decor'])
            num_groups[nkey] << gkey unless num_groups[nkey].include?(gkey)
            base = raw_label_base(r)
            bkey = Materials.identity_norm(base)
            base_groups[bkey] << gkey unless base_groups[bkey].include?(gkey)
            man = gid.empty? ? r['manufacturer'].to_s.strip : group_man[gid].to_s.strip
            mkey = Materials.identity_norm(man.empty? ? base : "#{man} #{base}")
            man_groups[mkey] << gkey unless man_groups[mkey].include?(gkey)
          end
          {
            # F10 povodna uroven: rovnake CISLO z viacerych skupin -> vyrobca.
            'num' => num_groups.select { |_, v| v.length > 1 },
            # 8. kolo: rovnaky ZLOZENY zaklad z viacerych skupin -> vyrobca.
            'base' => base_groups.select { |_, v| v.length > 1 },
            'hard' => man_groups.select { |_, v| v.length > 1 },
            'group_man' => group_man
          }
        end

        # Zlozeny zaklad BEZ kolizneho aparatu (zdiela ho ctx aj label_base).
        def raw_label_base(rec)
          [rec['decor'], rec['structure'], rec['decor_name']]
            .map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
        end

        # Zaklad labelu zaznamu: [vyrobca pri kolizii [+group_id pri tvrdej]]
        # cislo struktura nazov. V SCHEMA 1 (ctx nil) = presne dnesny text.
        def label_base(rec, manufacturer, ctx)
          base = raw_label_base(rec)
          return base unless ctx
          ambiguous = ctx['num'].key?(Materials.identity_norm(rec['decor'])) ||
                      ctx['base'].key?(Materials.identity_norm(base))
          return base unless ambiguous
          man = manufacturer.to_s.strip
          out = man.empty? ? base : "#{man} #{base}"
          if ctx['hard'].key?(Materials.identity_norm(out))
            gid = rec['group_id'].to_s.strip
            out = "#{out} [#{gid}]" unless gid.empty?
          end
          out
        end

        # PICKER-2: menovka DEKORU (bez typu a hrubky) — to iste, co nesie
        # `sheet_label` pred casťou „· TYP hrubka mm", vratane vyrobcu pri
        # kolizii a pripony formatu/rubu. Riadok vyhladavaca zastupuje vsetky
        # hrubky rodiny, takze menovka s hrubkou by v nom klamala; a bez
        # vyrobcu/formatu by dva RIADKY vyzerali rovnako.
        # Menovka RIADKU vyhladavaca: dekorovy zaklad (to iste, co nesie
        # `sheet_label` pred castou „· TYP hrubka mm") + rozlisenie, ked ten
        # isty dekor ma v katalogu viac typov. Rozhodnutie aj text skladania
        # rozlisenia zije v CORE (`Materials.row_label_disambiguated`) — je to
        # pravidlo nad katalogom, nie vlastnost okna, a takto sa da overit
        # headless.
        def sheet_row_label(s, ctx = label_ctx, fam = nil)
          return sheet_label(s, ctx) if Materials.uni?(s)

          Materials.row_label_disambiguated(raw_row_label(s, ctx), s, fam)
        end

        # Zaklad dekorovej menovky BEZ rozlisovania (zdiela ho ctx aj label).
        def raw_row_label(s, ctx = label_ctx)
          "#{label_base(s, s['manufacturer'], ctx)}#{Materials.sheet_label_suffix(s)}"
        end

        # Kontext riadkov na CELY payload (vzor `label_ctx`).
        # PICKER-3 (A): kontext musi vidiet aj VIRTUALNE duplakove ponuky —
        # v `Materials.sheets` nie su (su vlastnym polom payloadu), ale
        # vyhladavac ich lepi na riadok ZDROJA ako dalsi cip. Bez nich by
        # rodina s jednou kupenou hrubkou platila za jednovariantnu a menovka
        # riadku by tvrdila „… 18 mm" aj potom, co riadok dostane cip „36
        # duplák" (review #231 kolo 3).
        def row_fam_ctx(ctx = label_ctx)
          Materials.row_family_ctx(Materials.sheets, virtual: duplak_virtual_variants) do |s|
            raw_row_label(s, ctx)
          end
        end

        # Hrubky, ktore riadok zastupuje NAVYSE oproti katalogu: [zdroj, hrubka]
        # pre kazdu virtualnu ponuku „(duplák ×2)". Zdroj rozhoduje o rodine,
        # hrubka je zdvojena — presne to, co posiela `duplak_offers`.
        def duplak_virtual_variants
          Materials.duplak_offer_sources(2).map { |s| [s, (s['thickness'].to_f * 2).round(2)] }
        rescue StandardError => e
          Engine.log_error(e, 'duplak_virtual_variants')
          []
        end

        def sheet_label(s, ctx = label_ctx)
          # V0.6 M-B1: UNI label BEZ typu a hrubky ("Korpus UNI · UNI") —
          # katalogova hrubka je len pracovny default, v selecte by klamala.
          return "#{label_base(s, s['manufacturer'], ctx)} · UNI" if Materials.uni?(s)
          th = s['thickness'].to_f
          thl = (th == th.round ? th.round : th)
          # 2B-2 (GH #95 P1): varianty s formatom v identite (PD/zastena) sa mozu
          # lisit LEN formatom alebo rubom — selecty (Inspector, projektove
          # predvolby) musia rozdiel ukazat, inak sa da vybrat nespravny vyrobny
          # material. Pripona (format + rub) je core helper — VZDY, nie len pri
          # kolizii (deterministicke texty; testovatelne headless).
          "#{label_base(s, s['manufacturer'], ctx)} · #{s['type']} #{thl} mm#{Materials.sheet_label_suffix(s)}"
        end

        # D-41: paska so sirkou "dekor 22/1 mm" (sirka/hrubka — Michalov zapis),
        # legacy bez sirky ostava "dekor 1.0 mm". 2A-4b: struktura v labeli
        # ("K009 PW 23/1 mm"), vyrobca pri kolizii (cez skupinu — ABS zaznam
        # vyrobcu nenesie), "univ." priznak LEN v SCHEMA 2 (vlastnost vyberu).
        def abs_label(a, ctx = label_ctx)
          man = ctx ? ctx['group_man'][a['group_id'].to_s.strip].to_s : ''
          base = label_base(a, man, ctx)
          uni = ctx && a['universal'] == true ? ' · univ.' : ''
          w = a['width']
          return "#{base} #{a['thickness']} mm#{uni}" if w.nil?
          "#{base} #{fmt_num(w)}/#{fmt_num(a['thickness'])} mm#{uni}"
        end

        # --- D-102: „podľa pravidla" musi povedat, CO pravidlo vybralo ----------
        #
        # Karta dielca aj karta dosky dostavaju HOTOVE TEXTY zo servera — JS z nich
        # nic neskladá ani neprekladá (vzor D-92 riadku nakupu). Zdroj vysledku je
        # TA ISTA cesta ako v builderi: katalogovy zaznam dosky -> hrubka pre picker
        # (CabinetBuilder.abs_pick_thickness) -> AbsRules.resolve_edges. Preto sa
        # panel nemoze rozist s tym, co postavi rebuild.

        # Vysledok PRAVIDLA (bez overridov) ako text per hrana:
        #   paska  -> jej label ("500 SM Biela 23/1 mm")
        #   nic    -> "bez ABS"
        #   KOMPAKT / PD-postforming -> "nelepí sa" (M-C: ABS defaulty su potlacene)
        def edge_rule_results(role, material_id, thickness)
          sheet = Materials.sheet(material_id)
          th = CabinetBuilder.abs_pick_thickness(sheet, thickness)
          base = AbsRules.resolve_edges(role.to_s, sheet && sheet['decor'], th, sheet: sheet)
          suppressed = Materials.abs_default_suppression(sheet) == :all
          ctx = label_ctx
          AbsRules::EDGE_ORDER.each_with_object({}) do |code, out|
            out[code] = abs_result_text(base[code], suppressed, ctx)
          end
        rescue StandardError => e
          Engine.log_error(e, 'edge_rule_results')
          {}
        end

        # Text jednej vyriesenej hodnoty ABS (nil = bez pasky / potlacene).
        def abs_result_text(abs_id, suppressed, ctx = nil)
          return suppressed ? 'nelepí sa' : 'bez ABS' if abs_id.nil? || abs_id.to_s.strip.empty?
          rec = Materials.edge(abs_id)
          rec ? abs_label(rec, ctx) : abs_id.to_s
        end

        # Kratka skratka pasky do 2D nahladu ("23/1" resp. "1") — Michalov zapis
        # sirka/hrubka. Bez pasky prazdny retazec (pas ostava len farebny).
        def abs_short_text(abs_id)
          rec = abs_id ? Materials.edge(abs_id) : nil
          return '' unless rec
          w = rec['width']
          w.nil? ? fmt_num(rec['thickness']) : "#{fmt_num(w)}/#{fmt_num(rec['thickness'])}"
        rescue StandardError
          ''
        end

        # Popisky pasov 2D nahladu: title (plny text) + short (skratka do popisku).
        # `edges` = SKUTOCNE hrany dielca/dosky (vysledok po overidoch).
        def edge_view_hints(edges, labels, suppressed)
          ctx = label_ctx
          AbsRules::EDGE_ORDER.each_with_object({}) do |code, out|
            aid = edges.is_a?(Hash) ? edges[code] : nil
            name = (labels.is_a?(Hash) ? labels[code] : nil) || code
            out[code] = { 'title' => "#{name} — #{abs_result_text(aid, suppressed, ctx)}",
                          'short' => abs_short_text(aid) }
          end
        rescue StandardError => e
          Engine.log_error(e, 'edge_view_hints')
          {}
        end

        # Je material NELEPITELNY (KOMPAKT / PD postforming)? Autorita = Materials.
        def abs_suppressed_material?(material_id)
          Materials.abs_default_suppression(Materials.sheet(material_id)) == :all
        rescue StandardError
          false
        end

        # Cele cislo bez desatin (22.0 -> "22"), inak s nimi (22.5 -> "22.5").
        def fmt_num(v)
          f = v.to_f
          f == f.round ? f.round.to_s : f.to_s
        end

        # (project_materials payload sa V0.4.5 D2 presunul do MaterialsDialog.push_state)

        # Dielec vo vybere (kind=part) — po dvojkliku do korpusu a kliknuti na dielec.
        # D-34 (audit B4a): valid? filter — atributy zmazanej entity sa nesmu citat.
        def find_selected_part(model)
          model.selection.to_a.find { |e| e.valid? && Store.kind(e) == 'part' }
        end

        # Karta dielca pre UI (ABS/materialovy editor): rola, rozmery, VYSLEDNY material + ABS hrany,
        # labely hran per rola, priznaky overridov.
        def part_card_payload(_model, cab, part)
          cfg = Store.config(part) || {}
          role = Store.get(part, 'role').to_s
          cabcfg = Store.config(cab) || {}
          params = CabinetBuilder.config_to_params(cabcfg)
          rk = canonical_part_key(params, part_identity(cab, part))
          ov = ((params['part_overrides'] || {})[rk] || {})
          {
            'role_key' => rk, 'role' => role, 'name' => Store.get(part, 'name'),
            'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'],
            # K1 / D-108: smer dekoru je od v0.7.23 VSTUP. Tu je EFEKTIVNY smer
            # zo snapshotu dielca (standard 8.3) — ten isty udaj, z ktoreho pocita
            # VEPO aj kontrola narezu. Stavy segmentu doda `part_grain_payload`.
            'grain_direction' => cfg['grain_direction'] || 'none',
            'material_id' => cfg['material_id'],
            'edges' => cfg['edges'] || AbsRules.empty_edges,
            'edge_labels' => AbsRules.edge_labels(role),
            'edge_sides' => AbsRules.edge_sides(role), # V0.3 FIX 3: mapa hrana->strana pre SVG (1 zdroj pravdy)
            'edge_overrides' => (ov['edges'] || {}), # ktore hrany maju rucny override (UI odlisi "dedi")
            'has_material_override' => !ov['material_id'].nil?,
            'cabinet_id' => Store.get(cab, 'cabinet_id')
          }.merge(part_edge_texts(role, cfg)).merge(part_grain_payload(cfg, ov))
        rescue StandardError => e
          Engine.log_error(e, 'part_card_payload')
          nil
        end

        # K1 / D-108: stavy segmentu „Smer dekoru" v karte dielca. CELY TEXT
        # SKLADA SERVER (vzor D-102) — JS len maluje.
        #
        # Karta musi povedat TRI veci naraz (inak by pouzivatel nevedel, co vlastne
        # vidi): aky je VYSLEDOK, ci pochadza z materialu alebo z rucneho zasahu,
        # a AKY VYROBNY ROZMER z toho vyjde. Preto:
        #   * volba „Podľa materiálu" nesie v popise VYSLEDOK („— pozdĺžna"),
        #     nie prazdne slovo „dedí" — presne to bol slepy bod incidentu 19.8.;
        #   * KAZDA volba nesie v tooltipe vyrobny rozmer (2000×250 vs 250×2000),
        #     takze otocenie kresby je vidiet PRED objednavkou.
        #
        # Rozmery v snapshote su GEOMETRICKE; vyrobny tvar = ten isty swap, aky
        # robi `VepoExport.oriented` (grain 'width' => dlzka a sirka sa vymenia).
        # Zdvojene sa tu NIC nepocita — je to len zobrazenie toho isteho pravidla.
        #
        # AUTORITA ZOBRAZENEHO VYSLEDKU JE SNAPSHOT DIELCA (`cfg['grain_direction']`),
        # nikdy zivy katalog (Codex #185 P1). Katalog sa medzi prestavbami meni:
        # material sa da zmazat, jeho `grain` prepisat a .skp sa da otvorit na
        # stroji, ktory ten zaznam vobec nema. Keby karta pocitala vysledok z
        # katalogu, tvrdila by iny smer (a iny vyrobny rozmer), nez s akym dielec
        # naozaj ide do VEPO a do kontroly narezu — presne ten druh tichej
        # nezhody, kvoli ktoremu vznikol incident 19.8.
        # Katalog sa preto pouziva LEN na PROSPEKTIVNE udaje: co by z ktorej
        # volby vyslo pri NAJBLIZSEJ prestavbe. Ked sa prospektivny vysledok
        # rozide so snapshotom, karta to POVIE (`grain_hint`) — nezamlci to.
        GRAIN_WORD = { 'length' => 'pozdĺžna', 'width' => 'priečna', 'none' => 'bez smeru' }.freeze

        def part_grain_payload(cfg, ov)
          snapshot = norm_grain_value(cfg['grain_direction'])
          sheet = grain_sheet(cfg['material_id'])
          mat = norm_grain_value(sheet && sheet['grain'])
          override = ov['grain_direction'].to_s
          override = '' unless CabinetBuilder::GRAIN_OVERRIDES.include?(override)
          locked = (mat == 'none')
          # TA ISTA funkcia, akou pocita builder — ziadny druhy vypocet retaze.
          pending = defined?(CabinetBuilder) ? CabinetBuilder.effective_grain(sheet, override) : snapshot
          l = cfg['length'].to_f
          w = cfg['width'].to_f
          {
            'grain_value' => override.empty? ? 'inherit' : override,
            'grain_material' => mat,
            # S CIM DIELEC NAOZAJ IDE DO VYROBY (snapshot) — toto cita aj K2 overlay.
            'grain_effective' => snapshot,
            # Co by vyslo pri najblizsej prestavbe pri DNESNOM katalogu.
            'grain_pending' => pending,
            'grain_locked' => locked,
            'grain_options' => [
              grain_option('inherit', locked ? 'Podľa materiálu' : "Podľa materiálu — #{GRAIN_WORD[mat]}",
                           mat, l, w, locked),
              grain_option('length', 'Pozdĺžna', 'length', l, w, locked),
              grain_option('width', 'Priečna', 'width', l, w, locked)
            ],
            # Hint sa ukazuje LEN ked je co povedat (zamok alebo rozpor so
            # snapshotom) — inak by zabral riadok panela za nic (trvale
            # pravidlo „vertikalny priestor je vzacny").
            'grain_hint' => grain_hint(locked, override, snapshot, pending, l, w)
          }
        rescue StandardError => e
          Engine.log_error(e, 'part_grain_payload')
          {}
        end

        # 'length' / 'width' / 'none' — cokolvek ine (prazdne, nil, hodnota z
        # novsej verzie) znamena „o kresbe nevieme nic", teda 'none'.
        def norm_grain_value(v)
          s = v.to_s
          %w[length width].include?(s) ? s : 'none'
        end

        # Katalogovy zaznam dosky pre smer dekoru; material mimo katalogu = nil
        # (o kresbe nevieme nic, takze segment ostava zamknuty).
        def grain_sheet(material_id)
          return nil unless defined?(Materials) && material_id
          Materials.sheet(material_id)
        rescue StandardError
          nil
        end

        def grain_option(value, label, result, l, w, locked)
          title = if locked
                    'Materiál dielca nemá smer dekoru — voľba je zatiaľ neúčinná.'
                  else
                    "#{GRAIN_WORD[result].capitalize} — výrobne #{grain_dims_text(result, l, w)}"
                  end
          { 'value' => value, 'label' => label, 'title' => title }
        end

        # Vyrobny tvar rozmerov pre dany smer — TEN ISTY swap, aky robi
        # `VepoExport.oriented` (grain 'width' => dlzka a sirka sa vymenia).
        # Je to zobrazenie pravidla, nie druhy vypocet: rotacia sa v paneli
        # NIKDY nezapisuje, len sa ukazuje, co z nej vyjde.
        def grain_dims_text(direction, length, width)
          dims = (direction == 'width') ? [width, length] : [length, width]
          "#{fmt_mm(dims[0])}×#{fmt_mm(dims[1])} mm"
        end

        # Hint pod segmentom. Dva dovody, preco vobec je — a NIE SU navzajom
        # vylucne (Codex #185 kolo 3, P1):
        #   1) ROZPOR — dielec je POSTAVENY s inym smerom, nez aky by dnesny
        #      katalog dal (material sa medzitym zmenil/zmazal, .skp je z ineho
        #      stroja);
        #   2) ZAMOK — material uz smer nema, takze segment sa neda pouzit.
        #
        # PORADIE JE ZAVAZNE: prv sa povie VYROBNA REALITA (s cim dielec ide do
        # VEPO TERAZ), az potom vysvetlenie zamku. Povodna verzia sa pri zamku
        # vracala HNED a tvrdila „materiál nemá smer dekoru — otáčať sa nemá čo"
        # aj vtedy, ked snapshot dielca stale niesol `length`/`width` a VEPO ho
        # pouzivalo — karta si tak PROTIRECILA so svojim vlastnym
        # `grain_effective`. „Bez smeru" je pri zamku vzdy az PROSPEKTIVNY
        # vysledok (co nastane po najblizsej prestavbe), nikdy nie tvrdenie
        # o tom, co uz je postavene.
        # Ziadny dovod => nil = riadok sa vobec nezobrazi.
        def grain_hint(locked, override, snapshot, pending, length, width)
          out = []
          if pending != snapshot
            out << "Dielec je postavený so smerom „#{GRAIN_WORD[snapshot]}“ " \
                   "(výrobne #{grain_dims_text(snapshot, length, width)}) — po najbližšej " \
                   "prestavbe skrinky sa použije „#{GRAIN_WORD[pending]}“."
          end
          out << grain_locked_hint(override) if locked
          out.empty? ? nil : out.join(' ')
        end

        def grain_locked_hint(override)
          base = 'Materiál dielca nemá smer dekoru (jednofarebný alebo UNI) — otáčať sa nemá čo.'
          return base if override.empty?
          # Override sa pri zmene materialu NEMAZE (kontrakt K1): rozhodnutie
          # pouzivatela prezije aj docasny material bez kresby a ozije s dekorom.
          "#{base} Uložený smer „#{GRAIN_WORD[override]}“ ostáva zapamätaný, ale je neúčinný."
        end

        # D-102: serverove texty hran karty DIELCA — volba „(podľa pravidla — …)"
        # a popisky pasov nahladu. Cely text sklada server (JS len vklada).
        def part_edge_texts(role, cfg)
          labels = AbsRules.edge_labels(role)
          edges = cfg['edges'].is_a?(Hash) ? cfg['edges'] : {}
          suppressed = abs_suppressed_material?(cfg['material_id'])
          rule = edge_rule_results(role, cfg['material_id'], cfg['thickness'])
          {
            'edge_rule_options' => rule.each_with_object({}) { |(c, txt), o| o[c] = "(podľa pravidla — #{txt})" },
            'edge_hints' => edge_view_hints(edges, labels, suppressed)
          }
        rescue StandardError => e
          Engine.log_error(e, 'part_edge_texts')
          {}
        end

        # D-102: to iste pre kartu DOSKY. Doska nema override vrstvu (ziadne
        # „podľa pravidla"), ale nelepitelny material to musi POVEDAT — inak
        # „Bez ABS" vyzera ako vedome rozhodnutie pouzivatela.
        def board_edge_texts(role, cfg)
          labels = AbsRules.edge_labels(role)
          edges = cfg['edges'].is_a?(Hash) ? cfg['edges'] : {}
          suppressed = abs_suppressed_material?(cfg['material_id'])
          { 'edge_none_option' => suppressed ? 'Bez ABS (nelepí sa)' : 'Bez ABS',
            'edge_hints' => edge_view_hints(edges, labels, suppressed) }
        rescue StandardError => e
          Engine.log_error(e, 'board_edge_texts')
          {}
        end

        # part_key z plocheho atributu; fallback cez legacy role_key a nakoniec part_id.
        def part_identity(cab, part)
          present_str(Store.get(part, 'part_key')) ||
            present_str(Store.get(part, 'role_key')) ||
            fallback_role_key(cab, part)
        end

        # Prelozi legacy renderovaci suffix na part_key podla povodnej konfiguracie.
        # Nove kluce vracia bez dalsieho vypoctu.
        def canonical_part_key(params, key)
          value = key.to_s
          return value if value.start_with?('cabinet/', 'zone:', 'front:')

          cfg = CabinetBuilder.normalize(params)
          pd = Construction.build_plan(cfg)[:parts].find { |part| part[:suffix].to_s == value }
          pd ? PartKeys.for_descriptor(pd) : value
        rescue StandardError
          value
        end
        def fallback_role_key(cab, part)

          pid = Store.get(part, 'part_id').to_s
          cid = Store.get(cab, 'cabinet_id').to_s
          (!cid.empty? && pid.start_with?("#{cid}-")) ? pid[(cid.length + 1)..-1] : pid
        end

        def find_part_by_role_key(cab, rk)
          return nil unless cab && cab.respond_to?(:definition) && cab.valid?
          params = existing_params(cab)
          cab.definition.entities.grep(Sketchup::ComponentInstance).find do |e|
            Store.kind(e) == 'part' && canonical_part_key(params, part_identity(cab, e)) == rk
          end
        end

        # D-134 (slepe review P3-2): `all_cabinets` (globalny zber cez
        # `model.definitions`) tu ZANIKLO — hromadne ZAPISOVE akcie zakazky
        # presli na `job_cabinets` nizsie a citacie cesty (katalogovy
        # usage/delete guard, observery, dedup, resolvery vyberu) volaju
        # `Ids.each_cabinet` priamo. Nechavat prazdny obal by len zvadzalo
        # vratit sa nim do zapisovej vetvy.

        # D-134: JEDEN zdroj skriniek pre HROMADNE ZAPISOVE akcie zakazky.
        # -> { 'cabinets' => [top-level inst…], 'detached' => { cabinet_id => n } }
        #
        # PRECO vlastny zdroj a nie `all_cabinets`: kusovnik, VEPO aj Studio
        # citaju TOP-LEVEL `model.entities` (`Bom.collect`) — to je „zákazka".
        # Globalny prechod by nasiel aj korpus vnoreny v cudzom komponente: ten
        # vo vystupoch nie je a hromadna prestavba by ho zmenila vo VSETKYCH
        # vyskytoch zdielanej definicie. Telo je zdielane s „Kresba čiel"
        # (D-131) a „Nahradiť UNI…" (D-133) cez `Ids.top_level_scan`.
        def job_cabinets(model)
          scan = Ids.top_level_scan(model)
          { 'cabinets' => scan['cabinets'], 'detached' => scan['detached'] }
        end

        # D-134: rozdeli skrinky zakazky na tie, ktore sa smu PRESTAVAT, a na ID
        # tych PRESKOCENYCH (maju odpojeny dielec). -> [[inst…], ['CAB-3', …]]
        #
        # `detached` je mapa zo `job_cabinets`. Volajuci si vstupny zoznam moze
        # najprv ZUZIT (projektova predvolba berie len DEDIACE skrinky) — inak by
        # status menoval preskocenu skrinku, ktorej sa akcia vobec netyka.
        #
        # PRECO SKIP a nie blokada celej akcie (na rozdiel od „Nahradiť UNI…"):
        # tam je nahradenie dekoru all-or-nothing kvoli konzistencii vyroby
        # jedneho dekoru; tu ide o NASTAVENIE PROJEKTU, ktore musi byt zapisane
        # — zakazka nesmie ostat bez ulozenych pravidiel kvoli jednej vytiahnutej
        # doske. Preskocena skrinka sa dorovna pri svojej najblizsej prestavbe
        # (to iste sa deje dnes, ked pravidla zmeni iny PC).
        def job_split(cabinets, detached)
          jobs = []
          skipped = []
          Array(cabinets).each do |inst|
            cid = Store.get(inst, 'cabinet_id').to_s
            if detached.is_a?(Hash) && detached[cid].to_i.positive?
              skipped << cid
            else
              jobs << inst
            end
          end
          [jobs, skipped.uniq]
        end

        # Skratka pre cesty, ktore beru CELU zakazku (pravidla kovania).
        def job_cabinets_split(model)
          scan = job_cabinets(model)
          job_split(scan['cabinets'], scan['detached'])
        end

        # D-134: chvost statusu s preskocenymi skrinkami (vzor D-131
        # `fronts_grain_skipped_tail`). Prazdny zoznam = prazdny retazec, takze
        # bezna zakazka vidi PRESNE ten isty status ako doteraz.
        # Veta o naprave je zdielana konstanta `Ids::DETACHED_PART_REASON` —
        # dve kopie by sa casom rozisli a pouzivatel by pri tom istom probleme
        # cital raz jednu a raz druhu napravu.
        def detached_skipped_tail(ids)
          list = detached_skipped_list(ids)
          list.empty? ? '' : " · preskočené: #{list.join(', ')}"
        end

        # Polozky zoznamu („CAB-3 (má odpojený dielec — …)") pre volajucich,
        # ktori potrebuju INU vetu nez chvost statusu (modal podobnych dielcov).
        def detached_skipped_list(ids)
          Array(ids).reject { |id| id.to_s.empty? }
                    .map { |id| "#{id} (#{Ids::DETACHED_PART_REASON})" }
        end

        # String alebo nil (prazdny -> nil). Pre material dedenie + override cistenie.
        def present_str(v)
          return nil if v.nil?
          s = v.to_s.strip
          s.empty? ? nil : s
        end
      end
    end
  end
end
