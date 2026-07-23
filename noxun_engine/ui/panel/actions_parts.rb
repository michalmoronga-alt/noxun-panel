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
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          if mat then rec['material_id'] = mat else rec.delete('material_id') end
          store_override(ov, rk, rec)
          eff = effective_materials(model, params) # base sa nemeni — rozdiel robi override
          remap = CabinetBuilder.remap_part_edge_overrides!(params, eff, eff, old_overrides: old_overrides)
          rebuild_focus_part(model, cab, rk, params,
                             "Materiál dielca #{mat ? 'nastavený' : 'zdedený'}.#{remap_note(remap)}")
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
          abs_id, decor = bulk_abs_for(Store.config(part) || {})
          return set_status(missing_bulk_abs_msg(decor), true) if abs_id.nil? # atomicky no-op (audit FIX 5)
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          rec['edges'] = AbsRules.uniform_edges(abs_id)
          store_override(ov, rk, rec)
          rebuild_focus_part(model, cab, rk, params, "Všetky 4 hrany — ABS #{decor} 1,0 mm.")
        end

        # ABS 1.0 mm k dekoru materialu dielca/dosky. Vrati [abs_id alebo nil, dekor].
        # Zdroj materialu = config na entite (resolved snapshot, standard 8.3) — to iste,
        # co zobrazuje karta. Nenajdena paska => volajuci NESMIE nic menit (ziadna mapa
        # 4x nil — zmazala by existujuce hrany), len status s navodom.
        # D-41 (Codex GH #70): hrubka dielca z configu ide do vyberu SIRKY pasky —
        # 18 mm dielec dostane 22-ku, nie najsirsiu.
        def bulk_abs_for(cfg)
          mat = cfg['material_id']
          decor = defined?(Materials) ? Materials.decor_of(mat) : nil
          return [nil, decor || mat] if decor.nil?
          part_th = cfg['thickness'].to_f
          [Materials.abs_for_decor(decor, 1.0, part_th.positive? ? part_th : nil), decor]
        end

        def missing_bulk_abs_msg(decor)
          "Ku dekóru #{decor || 'materiálu dielca'} nie je v katalógu 1,0 mm ABS — pridaj ju v Materiáloch projektu."
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
