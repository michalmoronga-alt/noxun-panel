# frozen_string_literal: true
# Noxun Engine — modul cela (fronts) s LOCKMI. Standard sekcia 5.3.
# Cela stoja PRED korpusom (zaporne Y), delene na vysku, poradie ODSPODU nahor (F1 dole).
# Rezim polozky: 'fixed' (pevna vyska) alebo 'auto' (rovnomerne si rozdelia zvysok).
# 'locked' = fixed, ktore sa nemeni pri auto prepocte (priznak pre UI a buduci auto-fit).
# Cisto vypoctovy modul (mm Float) — vrati hotove deskriptory dielcov (box/origin/material).
module Noxun
  module Engine
    module Fronts
      FRONT_THICKNESS = 19.0  # hrubka cela (standard: cela 19 mm pred korpusom)
      GAP_DEFAULT     = 3.0   # skara medzi celami (zvislo) aj medzi kridlami dvierok
      GAP_EDGE        = 2.0   # skara hore/dole/po stranach
      AUTO_TWO_ABOVE  = 600.0 # nad touto sirkou celneho otvoru auto dvierka = 2 kridla
      MIN_AUTO        = 10.0  # ochrana: auto celo nikdy < 10 mm

      module_function

      # fronts_cfg: canonical hash (viz normalize_config) alebo legacy string ('none'/'1'/'2'/'auto') alebo nil.
      # width/height/floor_height/thickness = rozmery korpusu (mm).
      # Vrati: { parts:[deskriptory], items:[resolved s reÁlnymi vyskami], wings:Integer }.
      def layout(fronts_cfg, width, height, floor_height, _thickness)
        cfg = normalize_config(fronts_cfg)
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
        auto_h = auto_count.zero? ? 0.0 : [remaining / auto_count, MIN_AUTO].max

        parts = []
        resolved = []
        total_wings = 0
        z = floor_height + gb
        items.each_with_index do |it, i|
          idx = i + 1
          h = it['mode'] == 'fixed' ? it['height'].to_f : auto_h
          panels = panels_for(it, idx, gs, opening_w, z, h)
          total_wings += panels.size if it['type'] == 'door'
          parts.concat(panels)
          resolved << {
            'id' => it['id'] || "F#{idx}", 'type' => it['type'], 'mode' => it['mode'],
            'height' => h.round(2), 'locked' => !!it['locked'], 'wings' => it['wings'],
            'z' => z.round(2)
          }
          z += h + gap
        end
        { parts: parts, items: resolved, wings: total_wings }
      end

      # Panely jedneho cela. drawer_front = 1 panel; door = 1/2 kridla podla wings.
      def panels_for(item, idx, gs, opening_w, z, h)
        if item['type'] == 'drawer_front'
          [box_desc("DRW-#{idx}", 'drawer_front', "Zasuvkove celo #{idx}", gs, opening_w, z, h)]
        else
          wings = resolve_wings(item['wings'], opening_w)
          if wings == 2
            dw = (opening_w - GAP_DEFAULT) / 2.0
            [
              box_desc("DOOR-#{idx}-L", 'front_door', "Dvierka #{idx} lave", gs, dw, z, h),
              box_desc("DOOR-#{idx}-R", 'front_door', "Dvierka #{idx} prave", gs + dw + GAP_DEFAULT, dw, z, h)
            ]
          else
            [box_desc("DOOR-#{idx}", 'front_door', "Dvierka #{idx}", gs, opening_w, z, h)]
          end
        end
      end

      # Deskriptor dielca cela — box [sirka, hrubka, vyska], origin pred korpusom (Y = -hrubka).
      def box_desc(suffix, role, name, x, wdt, z, h)
        ft = FRONT_THICKNESS
        {
          suffix: suffix, role: role, name: name, material: :front,
          box: [wdt, ft, h], origin: [x, -ft, z],
          prod: { length: h.round(2), width: wdt.round(2), thickness: ft }
        }
      end

      def resolve_wings(wings, opening_w)
        case wings.to_s
        when '1' then 1
        when '2' then 2
        else opening_w > AUTO_TWO_ABOVE ? 2 : 1
        end
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
          'items'      => normalize_items(h['items'] || h[:items] || [])
        }
      end

      def normalize_items(items)
        Array(items).each_with_index.map do |it, i|
          type = (it['type'] || it[:type]).to_s
          type = 'door' unless %w[door drawer_front].include?(type)
          hraw = it['height'] || it[:height]
          has_h = !(hraw.nil? || hraw.to_s.strip.empty?)
          mode = (it['mode'] || it[:mode]).to_s
          mode = has_h ? 'fixed' : 'auto' unless %w[fixed auto].include?(mode)
          mode = 'auto' if mode == 'fixed' && !has_h # fixed bez vysky nema zmysel -> auto
          wings = (it['wings'] || it[:wings] || 'auto').to_s
          wings = 'auto' unless %w[1 2 auto].include?(wings)
          {
            'id' => (it['id'] || it[:id] || "F#{i + 1}").to_s,
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
          'gap_bottom' => GAP_EDGE, 'gap_sides' => GAP_EDGE, 'items' => [] }
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
