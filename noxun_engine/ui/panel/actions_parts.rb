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
            ok_abs, abs_note = ensure_missing_abs(mat)
            return set_status(abs_note, true) unless ok_abs
          end
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          if mat then rec['material_id'] = mat else rec.delete('material_id') end
          store_override(ov, rk, rec)
          eff = effective_materials(model, params) # base sa nemeni — rozdiel robi override
          remap = CabinetBuilder.remap_part_edge_overrides!(params, eff, eff, old_overrides: old_overrides)
          rebuild_focus_part(model, cab, rk, params,
                             "Materiál dielca #{mat ? 'nastavený' : 'zdedený'}.#{remap_note(remap)}#{abs_note}")
        end

        # D-45: nekompatibilna hrubka per-dielec materialu — vrati hlasku alebo nil.
        # Dielec korpusu hrubku NEMA vlastnu (dedi ju po korpuse), takze hlaska
        # posiela pouzivatela tam, kde sa hrubka realne meni: material celej
        # skrinky (prevezme hrubku) alebo pole Hrúbka v Zakladnych udajoch.
        def part_material_conflict(params, rk, mat)
          return nil unless mat && defined?(Materials)
          sheet = Materials.sheet(mat)
          return nil unless sheet # legacy material mimo katalogu — stary rezim
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
        def ensure_missing_abs(material_id)
          status, abs_id = Materials.ensure_edge_for_sheet(material_id)
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
            ok_abs, abs_note = ensure_missing_abs(cfgp['material_id'])
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

        # Zapis/vycisti zaznam part_override pod klucom rk (prazdny zaznam sa odstrani).
        def store_override(ov, rk, rec)
          if rec.nil? || rec.empty? then ov.delete(rk) else ov[rk] = rec end
        end

      end
    end
  end
end
