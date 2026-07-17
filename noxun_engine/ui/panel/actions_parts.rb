# frozen_string_literal: true
# Noxun Engine - Panel: dielec (material, ABS hrana) + rebuild_focus_part + store_override.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # Per-dielec material. Payload este vola pole role_key, ale hodnota je stabilny part_key.
        def handle_set_part_material(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
          rk = data['role_key'].to_s
          return set_status('Chyba identifikacie dielca.', true) if rk.empty?
          mat = present_str(data['material_id'])
          params = existing_params(cab)
          rk = canonical_part_key(params, rk)
          ov = (params['part_overrides'] ||= {})
          rec = ov[rk] || {}
          if mat then rec['material_id'] = mat else rec.delete('material_id') end
          store_override(ov, rk, rec)
          rebuild_focus_part(model, cab, rk, params, "Materiál dielca #{mat ? 'nastavený' : 'zdedený'}.")
        end

        # ABS hrana dielca (part_override.edges[code]). abs_id: konkretne / '' (bez ABS) / '__inherit__' (dedi).
        def handle_set_part_edge(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac dielec v korpuse.', true) if cab.nil?
          data = parse(payload)
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
