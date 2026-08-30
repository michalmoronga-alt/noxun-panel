# frozen_string_literal: true
# Noxun Engine — V0.6 M-B2: „Nahradiť UNI…" — hromadná zámena UNI materiálu
# za reálny katalógový dekor v CELOM modeli (skrinky, dielcové overridy,
# samostatné dosky, projektové predvoľby) s rozpisom dopadu PRED potvrdením.
#
# Architektúra (Codex audit M-B2, F5): ADAPTER nad modelom (replace_uni_scan —
# jediné miesto so SketchUp API) je oddelený od ČISTEJ klasifikácie
# (replace_uni_classify — data-in/data-out, headless testy). Tá istá dvojica
# stavia ponuku (preview) AJ finálnu dávku (apply) — ponuka nemôže sľúbiť nič
# iné, než apply spraví (vzor D-46, audit F3).
#
# Pending kontrakt (audit BLOCKER 1): potvrdenie sa viaže na KANONICKÝ ODTLAČOK
# plánu (SHA256 zo surových config stringov entít + zapisovaných predvolieb +
# cieľa), nie iba na množiny ID — zmena configu skrinky/dosky či katalógu medzi
# ponukou a potvrdením = stale, nová ponuka, žiadny zápis.
#
# All-or-nothing: jediná blokovaná skrinka (hrúbka mimo rozsahu dielca/roly)
# zastaví celú akciu s vymenovaním — žiadne čiastočné nahradenie.

require 'digest'

module Noxun
  module Engine
    module Materials
      module_function

      # Roly korpusového configu, v ktorých môže UNI materiál sedieť.
      RU_CAB_KEYS = {
        'material_id'       => 'body',
        'front_material_id' => 'front',
        'back_material_id'  => 'back'
      }.freeze

      # Čitateľné mená projektových predvolieb do rozpisu/statusu.
      RU_PROJECT_LABELS = {
        'default_material_id'       => 'Korpus',
        'default_front_material_id' => 'Čelá',
        'default_back_material_id'  => 'Chrbát'
      }.freeze

      RU_PENDING_KEYS = %w[model_guid uni_id target_id catalog_rev digest].freeze

      # --- ADAPTER (jediné miesto so SketchUp API) ---------------------------
      # Serializovaný scan použitia UNI materiálu v aktívnom modeli. Vráti
      # vstup pre replace_uni_classify:
      #   { 'cabs'  => [[cid, params, old_eff, raw, ref]],   # VŠETKY korpusy
      #     'boards'=> [[bid, stored_cfg, raw, ref]],        # dosky s uni_id
      #     'project' => { key => efektívne_id },            # po fallbackoch
      #     'model_guid' => guid }
      # params sú čerstvé kópie (config_to_params), raw = surový config JSON
      # string entity (vstup odtlačku plánu). ref = inštancia (len prenos do
      # jobs — klasifikácia sa ho nedotýka).
      def replace_uni_scan(model, uni_id)
        out = { 'cabs' => [], 'boards' => [], 'project' => {},
                # 1d/R-02b: identita dokumentu je token DocKey (Model#guid sa
                # meni pri kazdom ulozeni — save medzi scanom a potvrdenim by
                # ponuku zneplatnil).
                'model_guid' => (model ? DocKey.key(model) : '') }
        return out unless model && defined?(Ids)
        uid = uni_id.to_s
        Ids.each_of_kind(model, 'cabinet') do |inst|
          cid = (Store.get(inst, 'cabinet_id') || Store.get(inst, 'id')).to_s
          raw = Store.get(inst, 'config').to_s
          params = CabinetBuilder.config_to_params(Store.config(inst) || {})
          old_eff = CabinetBuilder.effective_materials(model, params)
          out['cabs'] << [cid, params, old_eff, raw, inst]
        end
        Ids.each_of_kind(model, 'board') do |inst|
          cfg = Store.config(inst) || {}
          next unless cfg['material_id'].to_s == uid
          bid = Store.get(inst, 'id').to_s
          out['boards'] << [bid, cfg, Store.get(inst, 'config').to_s, inst]
        end
        PROJECT_KEYS.each do |k|
          v = model_default(model, k)
          eff = (v.nil? || v.to_s.strip.empty?) ? PROJECT_FALLBACK[k].to_s : v.to_s
          out['project'][k] = eff
        end
        out
      end

      # --- ČISTÁ KLASIFIKÁCIA (žiadne SketchUp API) --------------------------
      # scan (viď vyššie), uni_sheet/target_sheet = katalógové záznamy.
      # Vráti:
      #   { 'jobs_cab' => [[ref, params]], 'jobs_board' => [[ref, merged_cfg]],
      #     'project_writes' => { key => target_id },
      #     'blocked' => [[id, dôvod_symbol, [mená dielcov]]],
      #     'adopting' => [cid], 'recompute' => [cid],
      #     'summary' => {...}, 'digest' => 'sha256...' }
      # Skrinky BEZ výskytu UNI (explicitného aj dedeného) sa do jobs nedostanú.
      def replace_uni_classify(scan, uni_sheet, target_sheet)
        uni_id = uni_sheet['material_id'].to_s
        target_id = target_sheet['material_id'].to_s
        target_th = target_sheet['thickness'].to_f
        out = { 'jobs_cab' => [], 'jobs_board' => [], 'project_writes' => {},
                'blocked' => [], 'adopting' => [], 'recompute' => [],
                'summary' => nil, 'digest' => nil }

        # Projektové predvoľby: efektívna hodnota (vrátane fallbacku — seed
        # fallbacky SÚ recyklované UNI id!) == uni_id -> predvoľba sa prepíše.
        # Kompatibilita cieľa s predvoľbou = D-46 pravidlá pre NOVÉ skrinky.
        project = scan['project'].is_a?(Hash) ? scan['project'] : {}
        project.each do |key, eff|
          next unless eff.to_s == uni_id
          reason = ru_project_target_issue(key, target_th)
          if reason
            out['blocked'] << ['projektová predvoľba', reason, [RU_PROJECT_LABELS[key].to_s]]
          else
            out['project_writes'][key] = target_id
          end
        end

        th_changes = Hash.new(0)   # "from->to" => počet skriniek
        explicit_cabs = []
        inherit_cabs = []
        overrides_n = 0
        remap_changed = 0
        remap_lost = []
        digest_cabs = []

        Array(scan['cabs']).each do |cid, params, old_eff, raw, ref|
          hit_keys = RU_CAB_KEYS.keys.select { |k| ru_present(params[k]) == uni_id }
          inherit_roles = RU_CAB_KEYS.select do |k, role|
            ru_present(params[k]).nil? && old_eff[role].to_s == uni_id &&
              out['project_writes'].key?(ru_project_key_for(role))
          end.values
          hit_ov_keys = ru_override_keys_with(params, uni_id)
          next if hit_keys.empty? && inherit_roles.empty? && hit_ov_keys.empty?

          # Snapshot overridov PRED prepisom (audit BLOCKER 2b) — remap musí
          # čítať STARÝ materiál dielca, nie už prepísaný.
          old_ov_snap = ru_deep_copy(params['part_overrides'])

          hit_keys.each { |k| params[k] = target_id }
          hit_ov_keys.each { |rk| params['part_overrides'][rk]['material_id'] = target_id }
          overrides_n += hit_ov_keys.size

          roles_now = (hit_keys.map { |k| RU_CAB_KEYS[k] } + inherit_roles).uniq
          old_th = params['thickness'].to_f

          blocked_reason = nil
          blocked_names = []
          if roles_now.include?('front') &&
             !CabinetBuilder.thickness_ok_for?('front_door', Fronts::FRONT_THICKNESS.to_f, target_th)
            blocked_reason = :front
          end
          if !blocked_reason && roles_now.include?('body')
            state, names = CabinetBuilder.adopt_thickness(params, target_sheet)
            case state
            when :range then blocked_reason = :range
            when :blocked
              blocked_reason = :parts
              blocked_names = Array(names)
            end
          end
          if !blocked_reason && roles_now.include?('back') && params['back_mode'].to_s != 'none'
            # Chrbát: vlastná cesta (audit BLOCKER 3) — cieľ je daný, jeho
            # hrúbka sa PREVEZME do back_thickness (žiadny auto-pick iného
            # materiálu). Mimo rozsahu builderu (1–50) = blokácia.
            if target_th >= 1.0 && target_th <= 50.0
              params['back_thickness'] = target_th
            else
              blocked_reason = :range
            end
          end
          if blocked_reason.nil?
            # GH #114 P1: finálny hrúbkový gate NAD VŠETKÝMI mutáciami — aj
            # override-only prípad (Dekor2 UNI na dielci) musí prejsť kontrolou
            # dielcov s vlastným materiálom; adopt_thickness ju volá len pri
            # zmene hrúbky TELA, prepis overridu by inak prešiel bez kontroly.
            names = CabinetBuilder.parts_blocking_thickness(params)
            unless names.empty?
              blocked_reason = :parts
              blocked_names = names
            end
          end
          if blocked_reason
            out['blocked'] << [cid, blocked_reason, blocked_names]
            next
          end

          new_eff = old_eff.dup
          roles_now.each { |role| new_eff[role] = target_id }
          remap = CabinetBuilder.remap_part_edge_overrides!(params, old_eff, new_eff,
                                                            old_overrides: old_ov_snap)
          remap_changed += remap['changed'].to_i
          remap_lost.concat(Array(remap['lost']))

          if roles_now.include?('body') && !CabinetBuilder.thickness_eq?(old_th, params['thickness'])
            th_changes["#{ru_fmt_mm(old_th)}→#{ru_fmt_mm(params['thickness'])}"] += 1
            out['adopting'] << cid
          else
            out['recompute'] << cid
          end
          (hit_keys.empty? && hit_ov_keys.empty? ? inherit_cabs : explicit_cabs) << cid
          digest_cabs << [cid, Digest::SHA256.hexdigest(raw.to_s)]
          out['jobs_cab'] << [ref, params]
        end

        boards = []
        digest_boards = []
        Array(scan['boards']).each do |bid, cfg, raw, ref|
          merged = ru_deep_copy(cfg)
          merged['material_id'] = target_id
          # Vzor BoardBuilder.rebuild: vedomá zmena materiálu ruší duplák väzbu.
          merged.delete('material_source')
          map, issues = ru_board_remap(cfg, uni_sheet, target_sheet, target_th)
          unless issues.nil?
            edges_final, warnings_final =
              BoardBuilder.material_change_outcome(cfg, map, issues, target_sheet)
            merged['edges'] = edges_final
            merged['warnings'] = warnings_final
            remap_changed += 1 if map && map != cfg['edges']
            remap_lost.concat(issues.reject { |n| n[:abs_id] }
                                    .map { |n| "#{bid} #{n[:code]}#{CabinetBuilder.lost_suffix(n[:reason])}" })
          end
          merged['grain_direction'] = 'none' if target_sheet['grain'].to_s == 'none'
          boards << { 'bid' => bid, 'from' => cfg['thickness'].to_f, 'to' => target_th }
          digest_boards << [bid, Digest::SHA256.hexdigest(raw.to_s)]
          out['jobs_board'] << [ref, merged]
        end

        digest_src = {
          'u' => uni_id, 't' => target_id, 'th' => ru_fmt_mm(target_th),
          'cabs' => digest_cabs.sort, 'boards' => digest_boards.sort,
          'proj' => out['project_writes'].sort,
          'blocked' => out['blocked'].map { |b| [b[0].to_s, b[1].to_s] }.sort
        }
        out['digest'] = Digest::SHA256.hexdigest(JSON.generate(digest_src))

        out['summary'] = {
          'uni_label' => uni_sheet['decor'].to_s,
          'target_label' => "#{target_sheet['decor']} #{target_sheet['decor_name']}".strip,
          'target_type' => target_sheet['type'].to_s,
          'target_th' => target_th,
          'project' => out['project_writes'].keys.map { |k| RU_PROJECT_LABELS[k].to_s },
          'cabs_explicit' => explicit_cabs, 'cabs_inherit' => inherit_cabs,
          'adopting_n' => out['adopting'].size, 'recompute_n' => out['recompute'].size,
          'th_changes' => th_changes.map { |k, n| { 'change' => k, 'n' => n } },
          'overrides_n' => overrides_n,
          'boards' => boards,
          'abs' => { 'changed' => remap_changed, 'lost' => remap_lost.uniq.first(8),
                     'lost_n' => remap_lost.size },
          'blocked' => out['blocked'].map { |id, why, names| ru_blocked_line(id, why, names) }
        }
        out
      end

      # Nič na nahradenie? (žiadne joby ani zápisy predvolieb ani blokácie)
      def replace_uni_empty?(plan)
        plan['jobs_cab'].empty? && plan['jobs_board'].empty? &&
          plan['project_writes'].empty? && plan['blocked'].empty?
      end

      # Pending kontrakt: potvrdenie patrí PRESNE tomu plánu, ktorý bol ponúknutý.
      def replace_uni_pending_ok?(pending, fresh)
        return false unless pending.is_a?(Hash) && fresh.is_a?(Hash)
        RU_PENDING_KEYS.all? { |k| pending[k].to_s == fresh[k].to_s }
      end

      # --- pomocné (čisté) ---------------------------------------------------

      def ru_present(v)
        s = v.to_s.strip
        s.empty? ? nil : s
      end

      def ru_deep_copy(obj)
        obj.nil? ? nil : JSON.parse(JSON.generate(obj))
      end

      def ru_override_keys_with(params, uni_id)
        ov = params['part_overrides']
        return [] unless ov.is_a?(Hash)
        ov.keys.select do |rk|
          rec = ov[rk]
          rec.is_a?(Hash) && rec['material_id'].to_s == uni_id
        end
      end

      def ru_project_key_for(role)
        { 'body' => 'default_material_id', 'front' => 'default_front_material_id',
          'back' => 'default_back_material_id' }[role]
      end

      # D-46 pravidlá vhodnosti cieľa ako projektovej predvolby (nové skrinky).
      def ru_project_target_issue(key, target_th)
        case key
        when 'default_material_id'
          CabinetBuilder.thickness_in_range?(target_th) ? nil : :range
        when 'default_back_material_id'
          [3.0, 18.0].any? { |t| CabinetBuilder.thickness_ok_for?('back', t, target_th) } ? nil : :range
        else
          CabinetBuilder.thickness_ok_for?('front_door', Fronts::FRONT_THICKNESS.to_f, target_th) ? nil : :front
        end
      end

      def ru_board_remap(cfg, old_sheet, new_sheet, target_th)
        edges = cfg['edges'].is_a?(Hash) ? cfg['edges'] : nil
        target = target_th.positive? ? target_th : nil
        if catalog_schema >= SCHEMA_GROUPS
          remap_edges_v2(edges, old_sheet, new_sheet, target)
        else
          map, _lost = remap_edges(edges, old_sheet && old_sheet['decor'],
                                   new_sheet && new_sheet['decor'], target)
          [map, nil]
        end
      end

      def ru_fmt_mm(v)
        f = v.to_f
        (f - f.round).abs < 0.005 ? f.round.to_s : format('%.2f', f).sub(/0\z/, '').tr('.', ',')
      end

      def ru_blocked_line(id, why, names)
        reason =
          case why.to_s.to_sym
          when :parts then "dielce s vlastným materiálom inej hrúbky: #{Array(names).join(', ')}"
          when :range then 'hrúbka cieľa mimo rozsahu'
          when :front then 'hrúbka cieľa nesedí pre čelá'
          else why.to_s
          end
        "#{id} — #{reason}"
      end
    end
  end
end
