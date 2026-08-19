# frozen_string_literal: true
# Noxun Engine - Panel: dielec (material, ABS hrana) + rebuild_focus_part + store_override.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # Per-dielec material. Payload este vola pole role_key, ale hodnota je stabilny part_key.
        # D-41 PR C: identity guard (audit FIX 6 — vzor bulk) + preladenie RUCNYCH ABS
        # overridov dielca zo stareho efektivneho dekoru na novy (audit FIX 5/7:
        # stary stav = override PRED zmenou || base, nikdy nie len rec hodnota).
        def handle_set_part_material(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
          return if stale_cabinet_echo?(cab, data, 'material dielca')
          rk = data['role_key'].to_s
          return set_status('Chyba identifikacie dielca.', true) if rk.empty?
          mat = present_str(data['material_id'])
          params = existing_params(cab)
          old_overrides = JsonFileStore.deep_copy(params['part_overrides'] || {})
          rk = canonical_part_key(params, rk)
          # D-49 (audit F4 + GH #116 P2): virtualny duplak — hrubkovy guard
          # najprv PROBE hodnotou BEZ zapisu (odmietnuty dielec nesmie nechat
          # nepouzity globalny zaznam), resolver az po guarde; dalsie kroky
          # (konflikt, ABS tvorba) pracuju s realnym zaznamom.
          duplak_note = ''
          if mat && (probe = virtual_duplak_probe(mat))
            return set_status(probe['error'], true) if probe['error']
            pd = CabinetBuilder.plan_parts_by_key(params)[rk]
            if pd && !CabinetBuilder.thickness_ok_for?(pd[:role], pd[:prod][:thickness].to_f, probe['thickness'])
              return set_status("Duplák #{fmt_mm(probe['thickness'])} mm nesedí dielcu #{pd[:name] || rk} (#{fmt_mm(pd[:prod][:thickness])} mm) — dielec hrúbku dedí po korpuse. Katalóg sa nezmenil.", true)
            end
          end
          if mat
            mat, dnote = resolve_virtual_material(mat)
            unless mat
              set_status(dnote, true)
              return push_selected(model)
            end
            duplak_note = dnote.to_s
          end
          # D-45: hrubkovy guard PRED akymkolvek zapisom (aj pred pripadnou tvorbou
          # ABS — audit FIX 8 kontrakt ostava). Predtym padol az rebuild surovou
          # hlaskou; teraz hlaska NAVIGUJE, kde sa hrubka realne meni.
          conflict = part_material_conflict(params, rk, mat)
          return set_status(conflict, true) if conflict
          # D-41 C2: modal "Vytvorit a pokracovat" — VSETKY kontroly PRED katalogovym
          # zapisom (audit FIX 8): hrubkova kompatibilita materialu s dielcom by
          # zhodila rebuild AZ PO vytvoreni pasky; tu sa overi vopred a nic sa nemeni.
          abs_note = ''
          if data['create_missing_abs'] && mat
            ok_abs, abs_note = ensure_missing_abs(mat, client_schema: data['catalog_schema'])
            return set_status(abs_note, true) unless ok_abs
          end
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          if mat then rec['material_id'] = mat else rec.delete('material_id') end
          store_override(ov, rk, rec)
          eff = effective_materials(model, params) # base sa nemeni — rozdiel robi override
          remap = CabinetBuilder.remap_part_edge_overrides!(params, eff, eff, old_overrides: old_overrides)
          rebuild_focus_part(model, cab, rk, params,
                             "Materiál dielca #{mat ? 'nastavený' : 'zdedený'}.#{remap_note(remap)}#{abs_note}#{duplak_note}")
        end

        # D-45: nekompatibilna hrubka per-dielec materialu — vrati hlasku alebo nil.
        # Dielec korpusu hrubku NEMA vlastnu (dedi ju po korpuse), takze hlaska
        # posiela pouzivatela tam, kde sa hrubka realne meni: material celej
        # skrinky (prevezme hrubku) alebo pole Hrúbka v Zakladnych udajoch.
        def part_material_conflict(params, rk, mat)
          return nil unless mat && defined?(Materials)
          sheet = Materials.sheet(mat)
          return nil unless sheet # legacy material mimo katalogu — stary rezim
          # V0.6 M-B1: UNI dielec — hrubku dedi po korpuse, ziadny konflikt.
          return nil if Materials.uni?(sheet)
          pd = CabinetBuilder.plan_parts_by_key(params)[rk]
          return nil unless pd
          want = pd[:prod][:thickness].to_f
          have = sheet['thickness'].to_f
          return nil if CabinetBuilder.thickness_ok_for?(pd[:role], want, have)
          "Materiál #{mat_name(sheet)} má #{fmt_mm(have)} mm, dielec #{pd[:name] || rk} potrebuje #{fmt_mm(want)} mm " \
            '— dielec hrúbku dedí po korpuse. Zmeň materiál celej skrinky (prevezme hrúbku) alebo hrúbku korpusu (Základné).'
        end

        # D-41 C2: serverova autorita modalu — dovytvori 1,0 mm pasku k dekoru
        # sheetu (Materials.ensure_edge_for_sheet). Katalogovy zapis je MIMO model
        # undo — pouzivatel bol upozorneny v modale (NOTE 9); hlaska to zopakuje.
        # Vrati [true, note] alebo [false, chyba].
        # GH #91 P2: client_schema z payloadu (JS posiela NX.catalogSchemaNow)
        # — bez neho by ensure v SCHEMA 2 katalogu drzal legacy default a modal
        # "Vytvorit a pokracovat" by NIKDY nevytvoril pasku (:schema_read_only).
        # Server schemu overuje sam (ensure_edge_for_sheet guard) — JS sa neveri.
        def ensure_missing_abs(material_id, client_schema: nil)
          status, abs_id = Materials.ensure_edge_for_sheet(
            material_id, client_schema: client_schema.to_i
          )
          case status
          when :exists
            [true, '']
          when :created
            push_materials
            MaterialsDialog.push_state if defined?(MaterialsDialog)
            rec = Materials.edge(abs_id)
            # 2A-3 (audit F15): hlaska cita SKUTOCNY zaznam (sirka aj hrubka) —
            # ziadne natvrdo "/1"; cena je "nezadana" (D-42), nie 0.
            w = rec && rec['width'] ? fmt_mm(rec['width']) : '?'
            t = rec ? fmt_mm(rec['thickness']) : '1'
            [true, " Vytvorená ABS #{rec && rec['decor']} #{w}/#{t} mm (globálny katalóg, cena nezadaná — Späť ju neodstráni)."]
          when :schema_read_only
            # 2A-2 (audit BLOCKER 2): katalog uz bezi na novsej scheme, nez pozna
            # toto okno (CEF cache) — legacy zapis by stratil identitne polia.
            [false, 'Katalóg má novší formát — obnov okno (nová verzia).']
          when :no_sheet
            [false, 'Materiál sa nenašiel v katalógu — páska sa nevytvorila.']
          when :no_standard_width
            widths = Materials::AUTO_WIDTHS.map { |w| fmt_mm(w) }.join('/')
            [false, "Hrúbka je mimo štandardných šírok pások (#{widths} mm) — pridaj pásku ručne v Materiáloch projektu."]
          when :uni_material
            # V0.6 M-B1 (audit B3): UNI pasky nema — tvorba je zablokovana.
            [false, 'UNI je pracovný materiál bez ABS pások — olep sa rieši až s reálnym dekorom.']
          when :abs_suppressed
            # M-C (GH #118 P2): kompakt/PD-postforming sa nelepia.
            [false, 'Tento materiál sa neolepuje (kompakt / postforming) — páska sa nevytvára.']
          else
            [false, 'Vytvorenie ABS pásky zlyhalo.']
          end
        end

        # D-41 (audit FIX 6): oneskoreny callback po prekliknuti nesmie zasiahnut
        # iny korpus — echo s cudzim cabinet_id sa TICHO zahodi (len log, vzor
        # bulk/board; chybova hlaska by matla — pouzivatel uz robi nieco ine).
        # Stary CEF klient bez cabinet_id prechadza (spatna kompatibilita).
        def stale_cabinet_echo?(cab, data, ctx)
          return false unless data.key?('cabinet_id')
          return false if data['cabinet_id'].to_s == Store.get(cab, 'cabinet_id').to_s
          Engine.log("#{ctx}: echo #{data['cabinet_id']} nesedi s vyberom #{Store.get(cab, 'cabinet_id')} — zahodene")
          true
        end

        # ABS hrana dielca (part_override.edges[code]). abs_id: konkretne / '' (bez ABS) / '__inherit__' (dedi).
        def handle_set_part_edge(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
          return if stale_cabinet_echo?(cab, data, 'hrana dielca') # D-41 audit FIX 6
          rk = data['role_key'].to_s
          code = data['edge'].to_s
          return set_status('Chyba identifikacie dielca/hrany.', true) if rk.empty? || !%w[L1 L2 W1 W2].include?(code)
          raw = data['abs_id']
          params = existing_params(cab)
          rk = canonical_part_key(params, rk)
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          edges = rec['edges'] || {}
          if raw.to_s == '__inherit__'
            edges.delete(code)          # spat na pravidlovy default
          else
            edges[code] = present_str(raw) # nil (bez ABS) alebo abs_id — explicitny override
          end
          if edges.empty? then rec.delete('edges') else rec['edges'] = edges end
          store_override(ov, rk, rec)
          label = raw.to_s == '__inherit__' ? 'podľa pravidla' : (present_str(raw) ? 'nastavená' : 'bez ABS')
          rebuild_focus_part(model, cab, rk, params, "Hrana #{code} — #{label}.")
        end

        # D-35: olepenie VSETKYCH 4 hran dielca jednym klikom — ABS 1.0 mm dekoru
        # materialu dielca, JEDEN rebuild = JEDEN undo krok (audit FIX 7: nikdy
        # slucka 4x set_edge). Identity guard (audit BLOCKER 3): payload nesie
        # cabinet_id AJ role_key a OBOJE sa overuje proti aktualne oznacenemu
        # dielcu — preklik medzi klikom a callbackom nesmie zasiahnut iny korpus.
        # Stale echo sa TICHO zahodi (len log, vzor board guardu) — pouzivatel uz
        # medzitym robi nieco ine, chybova hlaska by matla.
        def handle_set_part_edges_all(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
          rk = data['role_key'].to_s
          return set_status('Chyba identifikacie dielca.', true) if rk.empty?
          unless data['cabinet_id'].to_s == Store.get(cab, 'cabinet_id').to_s
            Engine.log("bulk hrany zahodene — echo #{data['cabinet_id']} nesedi s vyberom #{Store.get(cab, 'cabinet_id')}")
            return
          end
          part = find_selected_part(model)
          if part.nil?
            Engine.log('bulk hrany zahodene — vo vybere nie je dielec')
            return
          end
          params = existing_params(cab)
          rk = canonical_part_key(params, rk)
          unless canonical_part_key(params, part_identity(cab, part)) == rk
            Engine.log("bulk hrany zahodene — echo kluca #{rk} nesedi s oznacenym dielcom")
            return
          end
          cfgp = Store.config(part) || {}
          abs_note = ''
          # D-41 C2: modal "Vytvorit a pokracovat" pri bulk olepe — dovytvorenie
          # pred vyberom pasky (server overi vsetko znova, JS checku sa neveri).
          if data['create_missing_abs'] && cfgp['material_id']
            ok_abs, abs_note = ensure_missing_abs(cfgp['material_id'], client_schema: data['catalog_schema'])
            return set_status(abs_note, true) unless ok_abs
          end
          abs_id, decor = bulk_abs_for(cfgp)
          return set_status(missing_bulk_abs_msg(decor), true) if abs_id.nil? # atomicky no-op (audit FIX 5)
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          rec['edges'] = AbsRules.uniform_edges(abs_id)
          store_override(ov, rk, rec)
          rebuild_focus_part(model, cab, rk, params, "#{bulk_done_msg(abs_id, decor)}#{abs_note}")
        end

        # Jednotkova ABS k dekoru materialu dielca/dosky. Vrati [abs_id alebo nil, dekor].
        # Zdroj materialu = config na entite (resolved snapshot, standard 8.3) — to iste,
        # co zobrazuje karta. Nenajdena paska => volajuci NESMIE nic menit (ziadna mapa
        # 4x nil — zmazala by existujuce hrany), len status s navodom.
        # D-41 (Codex GH #70): hrubka dielca z configu ide do vyberu SIRKY pasky —
        # 18 mm dielec dostane uzku pasku, nie najsirsiu.
        # 2A-3 (audit F6): pri katalogu SCHEMA 2 ide vyber cez abs_for_sheet
        # (skupina + struktura + resolver triedy :jednotka); SCHEMA 1 = dnesna
        # cesta abs_for_decor 1,0 BEZ ZMENY.
        def bulk_abs_for(cfg)
          mat = cfg['material_id']
          return [nil, mat] unless defined?(Materials)
          decor = Materials.decor_of(mat)
          return [nil, decor || mat] if decor.nil?
          part_th = cfg['thickness'].to_f
          th = part_th.positive? ? part_th : nil
          if Materials.catalog_schema >= Materials::SCHEMA_GROUPS
            abs_id, = Materials.abs_for_sheet(Materials.sheet(mat), :jednotka, th)
            [abs_id, decor]
          else
            [Materials.abs_for_decor(decor, 1.0, th), decor]
          end
        end

        # 2A-3 (audit F15): hlaska bulku cita SKUTOCNU vybranu pasku (hrubka moze
        # byt 0,8/1/1,2 podla skupiny) — ziadne natvrdo "1,0 mm".
        def bulk_done_msg(abs_id, decor)
          rec = defined?(Materials) ? Materials.edge(abs_id) : nil
          th = rec ? fmt_mm(rec['thickness']) : '1'
          "Všetky 4 hrany — ABS #{decor} #{th} mm."
        end

        def missing_bulk_abs_msg(decor)
          who = decor || 'materiálu dielca'
          if defined?(Materials) && Materials.catalog_schema >= Materials::SCHEMA_GROUPS
            "Ku dekóru #{who} nie je v katalógu použiteľná jednotková ABS " \
              '(rovnaká štruktúra alebo univerzálna) — pridaj ju v Materiáloch projektu.'
          else
            "Ku dekóru #{who} nie je v katalógu 1,0 mm ABS — pridaj ju v Materiáloch projektu."
          end
        end

        # Rebuild korpusu s pripravenymi params + fokus na dielec (part_key) + resync panela.
        def rebuild_focus_part(model, cab, rk, params, msg)
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: uprava dielca')
            focus_part(model, cab, rk)
          end
          set_status(msg)
          push_selected(model) # posle korpus + part_card (dielec je po fokuse vo vybere) -> karta ostane
        end

        # Po rebuilde: najdi "ten isty" dielec podla part_key a oznac ho (karta ostane na tom dielci).
        def focus_part(model, cab, rk)
          part = find_part_by_role_key(cab, rk)
          reselect(model, part || cab)
        end

        # ---- D-89 (a): HRANA POD KURZOROM -----------------------------------
        # Hover nad hranou v karte dielca (zoznam hran aj 2D nahlad) rozsvieti
        # tu istu hranu priamo v MODELI. Je to POHLAD: ziadna operacia, ziadny
        # zapis, ziadny krok Spat (lekcia D-103) — kresli sa Overlay-om NAD
        # modelom a po odchode kurzora v modeli nic neostane.
        #
        # `code` prazdny/neznamy = zhasnutie (mouseleave, prekreslenie karty).
        # Status sa NEPISE: hover je pohyb mysou, nie akcia — hlaska pri kazdom
        # prejdeni riadku by prebila to, co panel prave hovori.
        #
        # IDENTITY GUARD DOKUMENTU: callback HtmlDialogu je asynchronny; bez
        # guardu by hover z panela patriaceho inemu dokumentu kreslil v prave
        # aktivnom modeli (rovnaky tvar ako `nx_edge_toggle` a `nx_camera_focus`).
        def handle_hover_edge(payload = nil)
          return unless defined?(HoverEdge)

          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          return HoverEdge.hide(model) if data['model_guid'].to_s != model_guid(model)

          HoverEdge.show(model, data['code'].to_s)
        end

        # ---- UI-D1: „OZNACIT V MODELI" --------------------------------------
        # Klik v karte dielca oznaci TENTO dielec v modeli. CISTE CITANIE +
        # zmena VYBERU: ziadny `start_operation`, ziadny zapis do dictionary,
        # ziadny krok Spat (lekcia D-103) — presne ako `handle_select_parts`
        # a `handle_select_hw_owner`.
        #
        # IDENTITY GUARD: callback HtmlDialogu je asynchronny, preto sa PRISNE
        # overuje dokument (ID skriniek sa naprie dokumentmi opakuju) aj to, ze
        # ide stale o TU ISTU skrinku. Dielec sa hlada podla `part_key`, nie
        # podla entity — skrinka sa medzi klikom a callbackom mohla prestavat.
        def handle_select_part(payload = nil)
          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          return set_status('Dielec sa neoznačil — panel patrí inému dokumentu.', true) if
            data['model_guid'].to_s != model_guid(model)

          cab = find_cabinet(model)
          return refresh_after_stale(model) if cab.nil? ||
                                               Store.get(cab, 'cabinet_id').to_s != data['cabinet_id'].to_s

          params = existing_params(cab)
          rk = canonical_part_key(params, data['role_key'].to_s)
          part = rk.empty? ? nil : find_part_by_role_key(cab, rk)
          if part.nil?
            return set_status('Dielec sa v modeli nenašiel — skrinka sa možno medzitým prestavala.', true)
          end

          suspend_selection_sync do
            sel = model.selection
            sel.clear
            sel.add(part)
          end
          push_selected(model, dedup: false)
          name = present_str(Store.get(part, 'name')) || rk
          set_status("Dielec #{name} označený v modeli (skrinka #{Store.get(cab, 'cabinet_id')}).")
        end

        # ---- UI-D1: „POUZIT NA PODOBNE…" ------------------------------------
        # Prepise OLEP HRAN (part_override 'edges') zdrojoveho dielca na vsetky
        # PODOBNE dielce vo zvolenom rozsahu. Definicia „podobny" je zavazna a
        # zije LEN tu (SYSTEM/zdroje/ui20/UI20_KONTRAKT.md, sekcia Dielec):
        #
        #   ROVNAKA ROLA (`role`) + ROVNAKY VYSLEDNY MATERIAL (`material_id`
        #   zo snapshotu dielca) v zvolenom rozsahu, okrem zdroja samotneho.
        #
        # Rovnaka rola je podmienka, nie kozmetika: kody hran L1/L2/W1/W2
        # znamenaju pri kazdej role INU fyzicku hranu (AbsRules::EDGE_LABELS),
        # takze prenos medzi rolami by olep otocil. Rovnaky material zase drzi
        # dekor pasky — ABS ineho dekoru by na cudzom dielci bola chyba.
        # Samostatne DOSKY (kind=board) do vyberu nepatria: nemaju vrstvu
        # overridov ani rolu korpusoveho dielca.
        SIMILAR_SCOPES = %w[cabinet project].freeze

        def normalize_similar_scope(raw)
          s = raw.to_s
          SIMILAR_SCOPES.include?(s) ? s : 'cabinet'
        end

        def similar_scope_label(scope)
          scope == 'project' ? 'celý projekt' : 'táto skrinka'
        end

        # JEDINA autorita vyberu podobnych dielcov — pocet aj zapis idu TOU
        # ISTOU cestou (inak by modal ukazoval iny pocet, nez sa naozaj zapise).
        # Vracia { cabinet_id => [cab_instance, [part_key, ...]] }.
        def similar_parts_map(model, cab, part, scope)
          role = Store.get(part, 'role').to_s
          return {} if role.empty?

          mat = (Store.config(part) || {})['material_id'].to_s
          src_key = Store.get(part, 'part_key').to_s
          src_cid = Store.get(cab, 'cabinet_id').to_s
          cabs = scope == 'project' ? all_cabinets(model) : [cab]
          out = {}
          cabs.each do |c|
            next unless c && c.valid?

            cid = Store.get(c, 'cabinet_id').to_s
            next if cid.empty? || out.key?(cid)

            keys = manufactured_parts(c).select do |p|
              Store.get(p, 'role').to_s == role &&
                (Store.config(p) || {})['material_id'].to_s == mat
            end.map { |p| Store.get(p, 'part_key').to_s }.reject(&:empty?).uniq
            keys.delete(src_key) if cid == src_cid
            out[cid] = [c, keys] unless keys.empty?
          end
          out
        rescue StandardError => e
          Engine.log_error(e, 'Panel.similar_parts_map')
          {}
        end

        def similar_parts_count(map)
          map.values.map { |(_c, keys)| keys.size }.inject(0) { |a, b| a + b }
        end

        # Spolocne guardy oboch ciest (pocet aj zapis). Vrati [cab, part, scope]
        # alebo [nil, nil, nil] + hlasku.
        def similar_context(model, data)
          cab = find_cabinet(model)
          return [nil, nil, nil, 'Skrinka sa nenašla — označ dielec znova.'] if
            cab.nil? || Store.get(cab, 'cabinet_id').to_s != data['cabinet_id'].to_s

          part = find_selected_part(model)
          return [nil, nil, nil, 'Vo výbere nie je dielec — označ ho v modeli znova.'] if part.nil?

          params = existing_params(cab)
          want = canonical_part_key(params, data['role_key'].to_s)
          have = canonical_part_key(params, part_identity(cab, part))
          return [nil, nil, nil, 'Karta patrí inému dielcu — označ ho v modeli znova.'] if
            want.empty? || want != have

          [cab, part, normalize_similar_scope(data['scope']), nil]
        end

        # ZIVY POCET pre otvoreny modal. Ciste citanie modelu — ziadna operacia,
        # ziadny zapis, ziadny krok Spat. Odpoved chodi do JS ako `NX.setSimilarCount`;
        # chyba nesie hlasku, aby modal nikdy neukazoval cislo, ktore neplati.
        def handle_similar_parts_count(payload = nil)
          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          scope = normalize_similar_scope(data['scope'])
          return push_similar_count(scope, nil, 'Panel patrí inému dokumentu.') if
            data['model_guid'].to_s != model_guid(model)

          cab, part, scope2, err = similar_context(model, data)
          return push_similar_count(scope, nil, err) if err

          push_similar_count(scope2, similar_parts_count(similar_parts_map(model, cab, part, scope2)), nil)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.handle_similar_parts_count')
          push_similar_count(normalize_similar_scope(nil), nil, 'Počet sa nepodarilo zistiť.')
        end

        def push_similar_count(scope, count, error)
          js("NX.setSimilarCount(#{{ 'scope' => scope, 'count' => count, 'error' => error }.to_json})")
        end

        # ZAPIS. Vsetky dotknute korpusy sa prestavaju v JEDNEJ operacii
        # (`CabinetBuilder.rebuild_many`) = JEDEN krok Spat — inak by pouzivatel
        # musel Ctrl+Z toľkokrát, kolko skriniek sa zmenilo, a medzistavy by boli
        # nekonzistentne (vzor D-35: nikdy slucka jednotlivych rebuildov).
        #
        # Prenasa sa ZAZNAM overridu, nie vysledok: prazdny/chybajuci override
        # zdroja znamena „vsetko podľa pravidla" a ciele sa na pravidlo VRATIA.
        # Je to to iste rozhodnutie, len prenesene — nie „nerob nic".
        def handle_apply_edges_similar(payload = nil)
          model = Sketchup.active_model
          return if model.nil?

          data = payload ? parse(payload) : {}
          return set_status('ABS sa nepoužilo — panel patrí inému dokumentu.', true) if
            data['model_guid'].to_s != model_guid(model)

          cab, part, scope, err = similar_context(model, data)
          return set_status("ABS sa nepoužilo — #{err}", true) if err

          map = similar_parts_map(model, cab, part, scope)
          if map.empty?
            return set_status('Podobný dielec sa nenašiel — rovnakú rolu a materiál nemá žiadny iný dielec ' \
                              "(#{similar_scope_label(scope)}).", true)
          end

          src_params = existing_params(cab)
          src_rk = canonical_part_key(src_params, part_identity(cab, part))
          src_edges = ((src_params['part_overrides'] || {})[src_rk] || {})['edges']
          src_cid = Store.get(cab, 'cabinet_id').to_s

          items = []
          total = 0
          map.each do |cid, (target_cab, keys)|
            params = cid == src_cid ? src_params : existing_params(target_cab)
            ov = (params['part_overrides'] ||= {})
            keys.each do |k|
              key = canonical_part_key(params, k)
              rec = ov[key] || {}
              # Sticky remap dovody patria STARYM hranam — s prepisom olepu
              # strácajú platnost (inak by karta ukazovala varovanie k paske,
              # ktora tam uz nie je).
              rec.delete('edge_warnings')
              if src_edges.is_a?(Hash) && !src_edges.empty?
                rec['edges'] = JsonFileStore.deep_copy(src_edges)
              else
                rec.delete('edges')
              end
              store_override(ov, key, rec)
              total += 1
            end
            items << [target_cab, params]
          end

          suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, items, op_name: 'NOXUN: ABS na podobne dielce')
            focus_part(model, cab, src_rk)
          end
          set_status("Olep hrán použitý na #{total} #{similar_word(total)} " \
                     "(#{similar_scope_label(scope)}, #{map.size} #{cabinet_word(map.size)}) — jeden krok Späť to vráti.")
          push_selected(model)
        end

        # Slovenske tvary poctu (rovnaka zasada ako `warn_word`).
        def similar_word(n)
          return 'podobný dielec' if n == 1

          n < 5 ? 'podobné dielce' : 'podobných dielcov'
        end

        def cabinet_word(n)
          return 'skrinka' if n == 1

          n < 5 ? 'skrinky' : 'skriniek'
        end

        # Zapis/vycisti zaznam part_override pod klucom rk (prazdny zaznam sa odstrani).
        def store_override(ov, rk, rec)
          if rec.nil? || rec.empty? then ov.delete(rk) else ov[rk] = rec end
        end

      end
    end
  end
end
