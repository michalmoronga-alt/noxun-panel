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
            'edges' => cfg['edges'].is_a?(Hash) ? cfg['edges'] : {},
            'edge_labels' => AbsRules.edge_labels(role),
            'edge_sides' => AbsRules.edge_sides(role),
            'quantity' => cfg['quantity'] || 1
          }
        end

        def cabinet_payload(cab)
          cfg = Store.config(cab) || {}
          params = CabinetBuilder.config_to_params(cfg)
          params['cabinet_id'] = Store.get(cab, 'cabinet_id')
          params['fronts'] = Fronts.normalize_config(cfg['fronts']) # kanonicke pre riadky cela
          params['zones'] = cfg['zones'] || []                      # ploche zony pre strom + nahlad
          params['front_items'] = cfg['front_items'] || []          # rozlozene cela pre nahlad
          # svetle (available) rozmery — view-only kontrola pre pouzivatela
          params['available_width'] = cfg['available_width']
          params['available_height'] = cfg['available_height']
          params['available_depth'] = cfg['available_depth']
          params['warnings'] = cfg['warnings'] || [] # BuildPlan upozornenia (pre buduce UI)
          params['template_name_suggestion'] = suggest_template_name(cab, nil) # D-14 modal (Codex F4)
          # V0.4 kovanie: vypocitane polozky (vystup planu) + rucne zasahy (identita
          # owner+type+rule_id). hardware_overrides su aj v params (config_to_params),
          # tu explicitne — UI paruje disabled zaznamy na vypnute kategorie.
          # V0.6 C-2 (audit F11): slovensky label TRANZIENTNE v payloade —
          # jedina autorita HardwareRules.label_for (JS mapy su len fallback);
          # do configu/snapshotu sa label NIKDY neuklada.
          params['hardware'] = (cfg['hardware'].is_a?(Array) ? cfg['hardware'] : []).map do |h|
            h.is_a?(Hash) ? h.merge('label' => HardwareRules.label_for(h['generic_type'])) : h
          end
          params
        end

        # existujuce params korpusu (na zachovanie casti pri ciastocnej zmene)
        def existing_params(cab)
          CabinetBuilder.config_to_params(Store.config(cab) || {})
        end

        def template_config_from(cfg)
          tc = {
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
          # V0.3 FIX 1: korpusove materialy do sablony LEN ak su na zdroji nastavene (non-nil).
          # part_overrides do sablony NEUKLADAME — su viazane na konkretne dielce/zony zdroja
          # (pri aplikacii sablony sa zachovaju z cieloveho korpusu).
          %w[material_id front_material_id back_material_id].each do |k|
            v = present_str(cfg[k])
            tc[k] = v if v
          end
          tc
        end

        def template_config_from_fields(data)
          tc = template_config_from(data)
          tc['zone_tree'] = data['zone_tree'] || ZoneTree.default_tree(0)
          tc['fronts'] = Fronts.normalize_config(data['fronts'])
          tc
        end

        def template_list
          TemplateStore.load
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
          {
            'catalog_schema' => Materials.catalog_schema,
            'sheets' => Materials.sheets.map { |s|
              # grain (V0.4.7c, Codex GH #33): vkladacia karta dosky predvyplna smer
              # dekoru z katalogu — bez grain by formular posielal nespravny default.
              # V0.6 M-B1: 'uni' => true LEN pri UNI (JS filtre/badge/board karta).
              base = { 'id' => s['material_id'], 'label' => sheet_label(s, ctx), 'decor' => s['decor'],
                       'thickness' => s['thickness'], 'color' => s['color'], 'grain' => s['grain'] }
              base['uni'] = true if Materials.uni?(s)
              base.merge(schema2_mirror_fields(s))
            },
            'edges' => Materials.edges.map { |a|
              { 'id' => a['abs_id'], 'label' => abs_label(a, ctx), 'decor' => a['decor'],
                'thickness' => a['thickness'], 'width' => a['width'], 'color' => a['color'] }
                .merge(schema2_mirror_fields(a, universal: true))
            }
          }
        rescue StandardError => e
          Engine.log_error(e, 'materials_payload')
          { 'sheets' => [], 'edges' => [] }
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
            'material_id' => cfg['material_id'],
            'edges' => cfg['edges'] || AbsRules.empty_edges,
            'edge_labels' => AbsRules.edge_labels(role),
            'edge_sides' => AbsRules.edge_sides(role), # V0.3 FIX 3: mapa hrana->strana pre SVG (1 zdroj pravdy)
            'edge_overrides' => (ov['edges'] || {}), # ktore hrany maju rucny override (UI odlisi "dedi")
            'has_material_override' => !ov['material_id'].nil?,
            'cabinet_id' => Store.get(cab, 'cabinet_id')
          }
        rescue StandardError => e
          Engine.log_error(e, 'part_card_payload')
          nil
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

        def all_cabinets(model)
          out = []
          Ids.each_cabinet(model) { |i| out << i }
          out
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
