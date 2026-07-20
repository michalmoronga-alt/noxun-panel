# frozen_string_literal: true
# Noxun Engine — modul cela (fronts) s LOCKMI. Standard sekcia 5.3.
# Cela stoja PRED korpusom (zaporne Y), delene na vysku, poradie ODSPODU nahor (F1 dole).
# Rezim polozky: 'fixed' (pevna vyska) alebo 'auto' (rovnomerne si rozdelia zvysok).
# 'locked' = fixed, ktore sa nemeni pri auto prepocte (priznak pre UI a buduci auto-fit).
# Typy riadkov: 'door' / 'drawer_front' / 'none' (D-18 „Bez cela" — riadok drzi vysku
# v rade ako celo, ale panel sa NEgeneruje = otvorena nika; POZOR: structured
# items[].type 'none' != legacy STRING config fronts='none', ktory znamena ziadne cela).
# Cisto vypoctovy modul (mm Float) — vrati hotove deskriptory dielcov (box/origin/material).
module Noxun
  module Engine
    module Fronts
      # Zakladna hrubka pre cisty vypocet. Builder ju pri znamom katalogovom
      # materiali nahradi skutocnou hrubkou variantu (18 alebo 19 mm).
      FRONT_THICKNESS = 18.0
      GAP_DEFAULT     = 3.0   # skara medzi celami (zvislo) aj medzi kridlami dvierok
      GAP_EDGE        = 2.0   # skara hore/dole/po stranach
      GAP_MAX         = 50.0  # D-07: medzera medzi celami 0..GAP_MAX
      EDGE_LIMIT      = 100.0 # D-07: okraje v -EDGE_LIMIT..+EDGE_LIMIT (zaporne = presah cez obrys)
      # D-22: odomknuty limit okrajov (edge_limit_off=true) — velke presahy pre
      # obklady/pilastre. Medzera medzi celami (0..GAP_MAX) sa NEODOMYKA.
      EDGE_LIMIT_UNLOCKED = 2000.0
      AUTO_TWO_ABOVE  = 600.0 # nad touto sirkou celneho otvoru auto dvierka = 2 kridla
      MIN_AUTO        = 10.0  # ochrana: auto celo nikdy < 10 mm

      module_function

      # fronts_cfg: canonical hash (viz normalize_config) alebo legacy string ('none'/'1'/'2'/'auto') alebo nil.
      # width/height/floor_height/thickness = rozmery korpusu (mm).
      # Vrati: { parts:[deskriptory], items:[resolved s reÁlnymi vyskami], wings:Integer }.
      def layout(fronts_cfg, width, height, floor_height, _thickness)
        cfg = normalize_config(fronts_cfg)
        # D-07: rozsahy medzier platia VZDY (aj bez ciel) — neplatne hodnoty sa
        # nesmu ulozit cez externy callback a vybuchnut az po pridani cela.
        validate_gap_ranges!(cfg)
        items = cfg['items']
        return { parts: [], items: [], wings: 0 } if items.nil? || items.empty?

        gap = cfg['gap']; gt = cfg['gap_top']; gb = cfg['gap_bottom']; gs = cfg['gap_sides']
        n = items.size
        opening_w = width - 2 * gs
        total_v = height - floor_height # celny otvor po vyske (od spodnej hrany tela po vrch)

        fixed_sum = items.select { |it| it['mode'] == 'fixed' }
                         .map { |it| it['height'].to_f }.reduce(0.0, :+)
        auto_count = items.count { |it| it['mode'] == 'auto' }
        remaining = total_v - gt - gb - (n - 1) * gap - fixed_sum
        validate_layout!(cfg, opening_w, total_v, fixed_sum, auto_count)
        auto_h = auto_count.zero? ? 0.0 : remaining / auto_count

        parts = []
        resolved = []
        total_wings = 0
        z = floor_height + gb
        items.each_with_index do |it, i|
          idx = i + 1
          h = it['mode'] == 'fixed' ? it['height'].to_f : auto_h
          panels = panels_for(it, idx, gs, opening_w, z, h, gap)
          total_wings += panels.size if it['type'] == 'door'
          parts.concat(panels)
          resolved << {
            'id' => it['id'] || "F#{idx}", 'type' => it['type'], 'mode' => it['mode'],
            'height' => h.round(2), 'locked' => !!it['locked'], 'wings' => it['wings'],
            'wings_n' => (it['type'] == 'door' ? panels.size : 1), # D-07: efektivny pocet kridiel pre nahlad
            'z' => z.round(2)
          }
          z += h + gap
        end
        { parts: parts, items: resolved, wings: total_wings }
      end

      # Panely jedneho cela. drawer_front = 1 panel; door = 1..4 kridla podla wings (D-24).
      # D-07: medzera medzi kridlami = cfg gap (predtym natvrdo GAP_DEFAULT).
      # D-24 IDENTITA (audit blocker): suffix recykluje SketchUp definiciu a tvori
      # part_id (cabinet_builder add_part); part_key nesie overridy a kovanie.
      # Stare tvary MUSIA ostat byte-identicke: 1 kridlo DOOR-N + wing:single,
      # 2 kridla DOOR-N-L/R + wing:left/right ("lave/prave"). NOVE 3/4 kridla maju
      # vlastny rad DOOR-N-P1..P4 + wing:p1..p4 (unikatne suffixy aj kluce).
      # D-18 'none' (Bez cela) = ZIADNE panely: riadok drzi vysku v rade presne ako
      # skutocne celo (rovnaka matematika fixed/auto/lock, z-postup pokracuje), ale
      # dielec nevznikne — otvorena nika v rade ciel. VEDOME ROZHODNUTIE: medzery
      # voci susedom ostavaju ako pri cele (ziadna specialna vetva), takze realny
      # otvor je opticky vacsi o susedne skary. Bez dielcov nevznikne ani kovanie
      # (HardwareRules iteruje dielce planu podla roly) ani polozky kusovnika/VEPO.
      def panels_for(item, idx, gs, opening_w, z, h, gap = GAP_DEFAULT)
        return [] if item['type'] == 'none'
        front_id = item['id'].to_s
        front_id = "F#{idx}" if front_id.empty?
        if item['type'] == 'drawer_front'
          [box_desc("DRW-#{idx}", PartKeys.front(front_id, 'panel'),
                    'drawer_front', "Zasuvkove celo #{idx}", gs, opening_w, z, h)]
        else
          wings = resolve_wings(item['wings'], opening_w)
          case wings
          when 2
            dw = (opening_w - gap) / 2.0
            [
              box_desc("DOOR-#{idx}-L", PartKeys.front(front_id, 'wing', 'left'),
                       'front_door', "Dvierka #{idx} lave", gs, dw, z, h),
              box_desc("DOOR-#{idx}-R", PartKeys.front(front_id, 'wing', 'right'),
                       'front_door', "Dvierka #{idx} prave", gs + dw + gap, dw, z, h)
            ]
          when 3, 4
            # sirka kridla = (otvor - medzery medzi kridlami) / n; x postupuje o (dw + gap)
            dw = (opening_w - (wings - 1) * gap) / wings
            (1..wings).map do |i|
              box_desc("DOOR-#{idx}-P#{i}", PartKeys.front(front_id, 'wing', "p#{i}"),
                       'front_door', "Dvierka #{idx} kridlo #{i}/#{wings}",
                       gs + (i - 1) * (dw + gap), dw, z, h)
            end
          else
            [box_desc("DOOR-#{idx}", PartKeys.front(front_id, 'wing', 'single'),
                      'front_door', "Dvierka #{idx}", gs, opening_w, z, h)]
          end
        end
      end

      # Deskriptor dielca cela — box [sirka, hrubka, vyska], origin pred korpusom (Y = -hrubka).
      def box_desc(suffix, part_key, role, name, x, wdt, z, h)
        ft = FRONT_THICKNESS
        {
          suffix: suffix, part_key: part_key, role: role, name: name, material: :front,
          box: [wdt, ft, h], origin: [x, -ft, z],
          prod: { length: h.round(2), width: wdt.round(2), thickness: ft }
        }
      end

      # D-24: '3'/'4' su vyhradne RUCNA volba — auto ostava 1/2 podla AUTO_TWO_ABOVE
      # (automatika nikdy nevyrobi 3/4 kridla, stare skrinky sa nemenia).
      def resolve_wings(wings, opening_w)
        case wings.to_s
        when '1' then 1
        when '2' then 2
        when '3' then 3
        when '4' then 4
        else opening_w > AUTO_TWO_ABOVE ? 2 : 1
        end
      end

      # D-07: rozsahy medzier — medzera medzi celami 0..GAP_MAX; okraje
      # +-EDGE_LIMIT (zaporne = presah cez obrys korpusu). POZN. semantika
      # okraja hore: cela sa kladu ODSPODU (z = floor + gap_bottom); gap_top
      # posuva geometriu len cez AUTO cela (dopocitavaju zvysok) a pri
      # fixed-only zostave funguje ako rezerva/limit vo fit validacii.
      # D-22: edge_limit_off=true odomkne okraje na +-EDGE_LIMIT_UNLOCKED
      # (obklady/pilastre). Backend je AUTORITA — UI limity su len pohodlie;
      # medzera medzi celami ostava 0..GAP_MAX bez ohladu na zamok.
      def validate_gap_ranges!(cfg)
        gap = cfg['gap'].to_f
        if gap.negative? || gap > GAP_MAX
          raise "Medzera medzi celami musi byt 0 az #{GAP_MAX.to_i} mm."
        end
        limit = truthy(cfg['edge_limit_off']) ? EDGE_LIMIT_UNLOCKED : EDGE_LIMIT
        [['hore', cfg['gap_top'].to_f], ['dole', cfg['gap_bottom'].to_f],
         ['po stranach', cfg['gap_sides'].to_f]].each do |label, v|
          next if v.abs <= limit
          raise "Okraj cel #{label} musi byt v rozsahu -#{limit.to_i} az +#{limit.to_i} mm."
        end
      end

      # Backendova ochrana pred geometriou mimo korpusu. UI ma vlastne kontroly,
      # ale ulozeny/legacy config alebo externy callback ich moze obist.
      def validate_layout!(cfg, opening_w, total_v, fixed_sum, auto_count)
        gap = cfg['gap'].to_f
        gt = cfg['gap_top'].to_f
        gb = cfg['gap_bottom'].to_f
        gs = cfg['gap_sides'].to_f
        items = cfg['items'] || []

        # D-18 (Codex audit F2): sirkovy limit plati len pre riadky, ktore realne
        # generuju panely — none-only zostava zaberie iba vysku (nika), extremne
        # bocne okraje ju nesmu zhodit.
        has_panels = items.any? { |it| it['type'] != 'none' }
        raise 'Cela sa nezmestia na sirku korpusu.' if has_panels && opening_w < MIN_AUTO
        # D-07 (Codex GH P2) + D-24: viackridlove dvierka — kridlo nesmie klesnut
        # pod MIN_AUTO (velka medzera/okraje by inak dali zaporne kridlo, ktore by
        # construction ticho vyradil a korpus by sa ulozil bez dvierok).
        # Sirka kridla pre resolved n: (opening_w - (n-1)*gap) / n; n=1 pokryva
        # uz sirkovy limit vyssie (kridlo = cely otvor).
        items.each_with_index do |it, i|
          next unless it['type'] == 'door'
          n = resolve_wings(it['wings'], opening_w)
          next if n < 2
          next if (opening_w - (n - 1) * gap) / n >= MIN_AUTO
          raise "Kridla dvierok #{i + 1} sa nezmestia — zmensi medzeru medzi celami alebo bocne okraje."
        end

        items.each_with_index do |it, i|
          next unless it['mode'] == 'fixed'
          next if it['height'].to_f >= MIN_AUTO
          raise "Pevna vyska cela #{i + 1} musi byt aspon #{MIN_AUTO.to_i} mm."
        end

        required = gt + gb + ([items.size - 1, 0].max * gap) + fixed_sum + (auto_count * MIN_AUTO)
        return if required <= total_v + 0.01

        raise "Cela sa nezmestia do vysky korpusu. Potrebuju aspon #{required.round(1)} mm, dostupnych je #{total_v.round(1)} mm."
      end

      # --- normalizacia configu ------------------------------------------------
      # Prijme nil / legacy String / Hash. Vrati kanonicky string-keyed hash pre ulozenie.
      def normalize_config(raw)
        return empty_config if raw.nil?
        return legacy_string(raw) if raw.is_a?(String)

        h = raw
        {
          'split_axis' => 'height',
          'gap'        => num(h['gap'] || h[:gap], GAP_DEFAULT),
          'gap_top'    => num(h['gap_top'] || h[:gap_top], GAP_EDGE),
          'gap_bottom' => num(h['gap_bottom'] || h[:gap_bottom], GAP_EDGE),
          'gap_sides'  => num(h['gap_sides'] || h[:gap_sides], GAP_EDGE),
          # D-22: stav zamku okrajov je sucast kanonickeho configu (round-trip cez
          # ulozeny korpus AJ sablony); default false = zamknute +-EDGE_LIMIT.
          'edge_limit_off' => truthy(h['edge_limit_off'] || h[:edge_limit_off]),
          'items'      => normalize_items(h['items'] || h[:items] || [])
        }
      end

      # Jednorazova kompatibilita pre V0.1/V0.2 korpusy. Stare konfiguracie
      # mohli obsahovat fyzicky nepouzitelne pevne celo mensie ako MIN_AUTO.
      # V0.3 konfiguracie tymto neprechadzaju a neplatna nova hodnota sa odmietne.
      def migrate_legacy_config(raw)
        cfg = normalize_config(raw)
        cfg['items'].each do |item|
          next unless item['mode'] == 'fixed' && item['height'].to_f < MIN_AUTO
          item.merge!('mode' => 'auto', 'height' => nil, 'locked' => false)
        end
        cfg
      end

      def normalize_items(items)
        used_ids = {}
        next_id = 1
        Array(items).each_with_index.map do |it, _i|
          requested_id = (it['id'] || it[:id]).to_s.strip
          front_id = requested_id.empty? ? nil : PartKeys.segment(requested_id)
          if front_id.nil? || used_ids[front_id]
            next_id += 1 while used_ids["F#{next_id}"]
            front_id = "F#{next_id}"
            next_id += 1
          end
          used_ids[front_id] = true

          type = (it['type'] || it[:type]).to_s
          type = 'door' unless %w[door drawer_front none].include?(type) # D-18: + none
          hraw = it['height'] || it[:height]
          has_h = !(hraw.nil? || hraw.to_s.strip.empty?)
          mode = (it['mode'] || it[:mode]).to_s
          mode = has_h ? 'fixed' : 'auto' unless %w[fixed auto].include?(mode)
          mode = 'auto' if mode == 'fixed' && !has_h # fixed bez vysky nema zmysel -> auto
          wings = (it['wings'] || it[:wings] || 'auto').to_s
          wings = 'auto' unless %w[1 2 3 4 auto].include?(wings) # D-24: + 3/4 (rucna volba)
          {
            'id' => front_id,
            'type' => type,
            'mode' => mode,
            'height' => has_h ? hraw.to_f : nil,
            'locked' => truthy(it['locked'] || it[:locked]) && mode == 'fixed',
            'wings' => (type == 'door' ? wings : 1)
          }
        end
      end

      # Legacy V0.1/V0.2a: door_mode none/1/2/auto -> 1 door celo auto vyska (alebo ziadne).
      def legacy_string(s)
        v = s.to_s
        return empty_config if v.strip.empty? || %w[none 0].include?(v)
        wings = %w[1 2].include?(v) ? v : 'auto'
        empty_config.merge('items' => [
          { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'height' => nil, 'locked' => false, 'wings' => wings }
        ])
      end

      def empty_config
        { 'split_axis' => 'height', 'gap' => GAP_DEFAULT, 'gap_top' => GAP_EDGE,
          'gap_bottom' => GAP_EDGE, 'gap_sides' => GAP_EDGE,
          'edge_limit_off' => false, 'items' => [] }
      end

      def num(v, dflt)
        v.nil? || v.to_s.strip.empty? ? dflt : v.to_f
      end

      def truthy(v)
        %w[true 1 yes].include?(v.to_s.downcase)
      end
    end
  end
end
