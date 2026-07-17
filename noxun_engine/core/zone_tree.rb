# frozen_string_literal: true
require 'securerandom'
# Noxun Engine — strom zon (standard sekcia 1 + 5). Cisto vypoctovy modul (mm Float).
#
# Zona = adresovatelny vnutorny priestor korpusu. Strom: koren Z1 = cele vnutro;
# priecka (divider_v/divider_h) ROZDELI zonu na deti -> vzniknu nove zony (rekurzivne).
# Police ostavaju MODUL v zone (zonu NEdelia) — rovnomerne v ramci listovej zony.
#
# V0.2c — DELENIE SO ZAMKAMI ROZMEROV (split lock):
#   split = { 'axis'=>'v'|'h', 'count'=>N, 'cuts'=>[ {'size'=>Float|nil,'locked'=>Bool}*N ] }
#   Kazdy prvok `cuts` je JEDNO POLE (stlpec pre 'v', riadok pre 'h'), odspodu/zlava:
#     - size   = pozadovana svetla sirka/vyska pola v mm (nil => auto, dopocita sa)
#     - locked = pri resize korpusu drzi svoj rozmer; nezamknute sa prepocitaju proporcne
#   Priecky (count-1) su dielce korpusu; ich pozicie sa odvodia z rozlozenia poli.
#
# Struktura uzla (string-keyed, round-tripuje cez JSON v configu korpusu):
#   { 'id' => stabilne interne ID, 'generation' => revizia topologie,
#     'split' => nil | {axis,count,cuts}, 'shelves' => 0..4, 'children' => [uzol,...] }
#
# Ghost ID zon ostava <cabinet_id>-Z<cesta> pre UI. Vyrobne dielce pouzivaju interne ID uzla,
# preto zmena cesty alebo susednej zony nepresunie material/ABS override na iny dielec.
module Noxun
  module Engine
    module ZoneTree
      SHELF_FRONT_INSET = 20.0 # police odsadene od cela (mm)
      MIN_FIELD         = 20.0 # najmensia svetla sirka/vyska pola (mm)

      module_function

      # --- konstrukcia / uprava stromu (string-keyed) -------------------------

      def default_node(shelves = 0, node_id = nil, generation = 0)
        { 'id' => node_id, 'generation' => [generation.to_i, 0].max,
          'split' => nil, 'shelves' => Shelves.clamp(shelves.to_i), 'children' => [] }
      end

      def default_tree(shelves = 0)
        default_node(shelves, 'Z1')
      end

      # Ocisti a znormalizuje lubovolny (aj symbolovy/poskodeny/legacy) strom na kanonicku formu.
      # Legacy uzly dostanu deterministicke ID podla povodnej cesty. Po ulozeni sa ID uz nemeni.
      def sanitize(node)
        sanitize_node(node, [1], { used: {} })
      end

      def sanitize_node(node, path, state)
        node = {} unless node.is_a?(Hash)
        node_id = canonical_node_id(node['id'] || node[:id], path, state)
        generation = [((node['generation'] || node[:generation]) || 0).to_i, 0].max
        split = node['split'] || node[:split]
        if split.is_a?(Hash)
          axis = (split['axis'] || split[:axis]).to_s
          axis = 'v' unless %w[v h].include?(axis)
          count = (split['count'] || split[:count] || 2).to_i
          count = 2 if count < 2
          count = 4 if count > 4
          cuts = sanitize_cuts(split['cuts'] || split[:cuts], count)
          raw_kids = Array(node['children'] || node[:children])
          kids = count.times.map do |i|
            sanitize_node(raw_kids[i], path + [i + 1], state)
          end
          { 'id' => node_id, 'generation' => generation,
            'split' => { 'axis' => axis, 'count' => count, 'cuts' => cuts },
            'shelves' => 0, 'children' => kids }
        else
          default_node((node['shelves'] || node[:shelves] || 0).to_i, node_id, generation)
        end
      end

      def canonical_node_id(raw, path, state)
        base = raw.to_s.strip
        base = "Z#{path.join('_')}" if base.empty?
        base = PartKeys.segment(base)
        candidate = base
        n = 2
        while state[:used][candidate]
          candidate = "#{base}-#{n}"
          n += 1
        end
        state[:used][candidate] = true
        candidate
      end

      # Ocisti pole poli (cuts) na presne `count` prvkov {size, locked}. Legacy (bez cuts) => same auto.
      def sanitize_cuts(cuts, count)
        arr = Array(cuts).map do |c|
          c = {} unless c.is_a?(Hash)
          sz = c['size'] || c[:size] || c['at_mm'] || c[:at_mm]
          { 'size' => (sz.nil? || sz.to_s.strip.empty? ? nil : sz.to_f),
            'locked' => truthy(c['locked'] || c[:locked]) }
        end
        arr = arr[0, count]
        arr += Array.new(count - arr.size) { { 'size' => nil, 'locked' => false } } if arr.size < count
        arr
      end

      def navigate(tree, path)
        node = tree
        Array(path)[1..-1].to_a.each do |k|
          ch = node['children']
          return nil unless ch.is_a?(Array) && ch[k - 1]
          node = ch[k - 1]
        end
        node
      end

      # Rozdel uzol na 'count' casti pozdlz osi. Prepise pripadny existujuci podstrom.
      # cuts sa zalozia ako auto (rovnomerne) — konkretne rozmery/zamky nastavi set_field!.
      def set_split!(tree, path, axis, count)
        node = navigate(tree, path)
        return false unless node
        count = 2 if count < 2
        count = 4 if count > 4
        axis = 'h' if axis.to_s == 'h'
        axis = 'v' unless axis == 'h'
        generation = node['generation'].to_i + 1
        node['generation'] = generation
        node['split'] = { 'axis' => axis, 'count' => count, 'cuts' => sanitize_cuts(nil, count) }
        node['shelves'] = 0
        node['children'] = Array.new(count) do |_i|
          default_node(0, "Z#{SecureRandom.hex(6)}")
        end
        true
      end

      # Nastav svetlu sirku/vysku konkretneho pola (index 0..count-1) + zamok.
      # Susedne NEzamknute pole(ia) sa dopocitaju pri compute z volneho zvysku.
      def set_field!(tree, path, index, size_mm, locked)
        node = navigate(tree, path)
        return false unless node && node['split'].is_a?(Hash)
        cuts = node['split']['cuts']
        return false unless cuts.is_a?(Array) && cuts[index]
        sz = size_mm.nil? || size_mm.to_s.strip.empty? ? nil : [size_mm.to_f, MIN_FIELD].max
        cuts[index] = { 'size' => sz, 'locked' => truthy(locked) && !sz.nil? }
        true
      end

      # V0.2c (fix #5): nahrad CELE pole `cuts` delenej zony naraz (perzistuj kompletny layout).
      # Pouzity pri edite rozmeru pola / drag priecky: UI dopocita rozmery vsetkych poli a
      # ulozi ich ako explicitne sizes, aby zadany rozmer NEzmizol pri dalsom resolve.
      # Proporcny prepocet nezamknutych sa potom deje LEN pri zmene rozmeru rodica (resize korpusu).
      def set_field_cuts!(tree, path, cuts)
        node = navigate(tree, path)
        return false unless node && node['split'].is_a?(Hash)
        count = node['split']['count'].to_i
        node['split']['cuts'] = sanitize_cuts(cuts, count)
        true
      end

      def set_shelves!(tree, path, n)
        node = navigate(tree, path)
        return false unless node
        node['split'] = nil
        node['children'] = []
        node['shelves'] = Shelves.clamp(n.to_i)
        true
      end

      def clear_zone!(tree, path)
        node = navigate(tree, path)
        return false unless node
        node['split'] = nil
        node['children'] = []
        node['shelves'] = 0
        true
      end

      # --- vypocet geometrie ---------------------------------------------------

      # tree: strukturny strom; box: { x0,x1,y0,y1,z0,z1 } vnutro korpusu (mm); t: hrubka; cabinet_id.
      # Vrati: { zones:[ploche objekty s geometriou], dividers:[deskriptory], shelves:[deskriptory] }.
      def compute(tree, box, t, cabinet_id)
        acc = { zones: [], dividers: [], shelves: [] }
        walk(sanitize(tree), [1], box, t, cabinet_id, acc, 'Celé vnútro')
        acc
      end

      def walk(node, path, box, t, cid, acc, label)
        zid = "#{cid}-Z#{path.join('.')}"
        parent_id = path.size > 1 ? "#{cid}-Z#{path[0..-2].join('.')}" : nil
        split = node['split']
        leaf = split.nil?
        suffix_path = path.join('_')
        node_id = node['id']

        zobj = {
          id: zid, stable_id: node_id, parent: parent_id, label: label,
          position: [r2(box[:x0]), r2(box[:y0]), r2(box[:z0])],
          width: r2(box[:x1] - box[:x0]), height: r2(box[:z1] - box[:z0]), depth: r2(box[:y1] - box[:y0]),
          split: nil, shelves: (leaf ? node['shelves'].to_i : 0), leaf: leaf
        }

        if leaf
          validate_shelves!(node['shelves'].to_i, box, t, zid)
          acc[:zones] << zobj
          add_shelves(node['shelves'].to_i, box, t, suffix_path, node_id, acc) if node['shelves'].to_i.positive?
        else
          validate_split!(split, box, t, zid)
          child_boxes, divs, fields = split_boxes(split, box, t, suffix_path, node_id)
          zobj[:split] = { axis: split['axis'], count: split['count'], fields: fields }
          acc[:zones] << zobj
          acc[:dividers].concat(divs)
          child_boxes.each_with_index do |cb, i|
            walk(node['children'][i], path + [i + 1], cb, t, cid, acc, child_label(split['axis'], i))
          end
        end
      end

      # Citatelny nazov detskej zony podla osi delenia rodica (V0.2c UX).
      def child_label(axis, index)
        axis == 'h' ? "Riadok #{index + 1}" : "Stĺpec #{index + 1}"
      end

      # Rozdelenie boxu podla poli (split['cuts']) s (count-1) prieckami hrubky t.
      # Vrati [child_boxes, divider_deskriptory, fields_info(pre nahlad)].
      def split_boxes(split, box, t, suffix_path, node_id)
        axis = split['axis']; count = split['count']
        span = axis == 'v' ? (box[:x1] - box[:x0]) : (box[:z1] - box[:z0])
        sizes = resolve_fields(split['cuts'], count, span, t)
        boxes = []; divs = []; fields = []
        if axis == 'v'
          x = box[:x0]
          count.times do |c|
            w = sizes[c]
            boxes << box.merge(x0: x, x1: x + w)
            fields << field_info(split['cuts'][c], w)
            x += w
            if c < count - 1
              divs << divider_desc('v', x, box, t, suffix_path, node_id, c + 1)
              x += t
            end
          end
        else
          z = box[:z0]
          count.times do |r|
            hh = sizes[r]
            boxes << box.merge(z0: z, z1: z + hh)
            fields << field_info(split['cuts'][r], hh)
            z += hh
            if r < count - 1
              divs << divider_desc('h', z, box, t, suffix_path, node_id, r + 1)
              z += t
            end
          end
        end
        [boxes, divs, fields]
      end

      # Rozlozi svetly priestor (span - (count-1)*t) medzi `count` poli:
      #   locked pole -> drzi svoju size; ak sa vsetky zamknute NEzmestia (kumulativne, aj po
      #     rezervovani MIN_FIELD na kazde nezamknute), proporcne ich zmensime (zachova pomer);
      #   nezamknute -> rozdelia zvysok PROPORCNE podla svojich size (nil size = rovnomerny podiel).
      #
      # V0.2c fix #1: kumulativny clamp zamknutych. Predtym sa kazde zamknute clampovalo NEzavisle
      # na cely `clear`, takze 2x lock 500 v 600 spane vratilo [582,582] a priecky/zony vznikali
      # MIMO rodica. Teraz Sigma(locked) nikdy nepresiahne dostupny priestor -> geometria drzi v bboxe.
      def resolve_fields(cuts, count, span, t)
        clear = span - (count - 1) * t
        clear = 0.0 if clear.negative?
        cuts = sanitize_cuts(cuts, count)

        locked_idx   = cuts.each_index.select { |i| cuts[i]['locked'] && cuts[i]['size'] }
        unlocked_idx = cuts.each_index.reject { |i| cuts[i]['locked'] && cuts[i]['size'] }

        # Zamknute polia ziadaju svoj rozmer (min MIN_FIELD). Kumulativna kontrola proti spanu:
        # necham MIN_FIELD na kazde nezamknute pole; ak sa zamknute do zvysku nezmestia, zmensim ich.
        locked_want = locked_idx.map { |i| [cuts[i]['size'].to_f, MIN_FIELD].max }
        locked_sum  = locked_want.reduce(0.0, :+)
        avail_locked = clear - MIN_FIELD * unlocked_idx.size
        avail_locked = 0.0 if avail_locked.negative?
        if locked_sum > avail_locked && locked_sum.positive?
          factor = avail_locked / locked_sum
          if defined?(Engine)
            Engine.log("zone_tree: zamknute polia (#{locked_sum.round} mm) presahuju dostupny priestor " \
                       "(#{avail_locked.round} mm) — proporcne zmensene x#{factor.round(3)}")
          end
          locked_want = locked_want.map { |s| s * factor }
          locked_sum  = locked_want.reduce(0.0, :+)
        end

        free = clear - locked_sum
        free = 0.0 if free.negative?

        # Nezamknute: proporcny prepocet podla svojich size (nil = priemer). Toto je zachovane z
        # povodnej logiky a je nositelom fix #5 — pri nezmenenom spane (Sigma sizes == clear) je to
        # identita (rozmery drzia), pri zmene spanu (resize korpusu) sa nezamknute prepocitaju.
        known = unlocked_idx.map { |i| cuts[i]['size'] }.compact
        avg = known.empty? ? (free / [unlocked_idx.size, 1].max) : (known.reduce(0.0, :+) / known.size)
        weight_sum = unlocked_idx.reduce(0.0) { |s, i| s + (cuts[i]['size'] || avg) }
        weight_sum = 1.0 if weight_sum <= 0

        sizes = Array.new(count, 0.0)
        locked_idx.each_with_index { |i, k| sizes[i] = locked_want[k] }
        unlocked_idx.each do |i|
          w = cuts[i]['size'] || avg
          sizes[i] = free * (w / weight_sum)
        end
        sizes
      end

      # Rozdelenie nesmie vytvorit nulove ani zaporne polia. Zamknute rozmery
      # musia ostat pravdive; ak sa nezmestia, rebuild sa odmietne namiesto
      # ticheho zmensovania alebo dielcov mimo rodicovskej zony.
      def validate_split!(split, box, t, zone_id)
        count = split['count'].to_i
        span = split['axis'] == 'v' ? (box[:x1] - box[:x0]) : (box[:z1] - box[:z0])
        clear = span - (count - 1) * t
        minimum = count * MIN_FIELD
        if clear + 0.01 < minimum
          raise "Zona #{zone_id} je prilis mala na #{count} poli. Potrebuje aspon #{minimum.round(1)} mm svetleho priestoru."
        end

        cuts = sanitize_cuts(split['cuts'], count)
        locked = cuts.select { |c| c['locked'] && c['size'] }
        unlocked_count = count - locked.size
        locked_sum = locked.reduce(0.0) { |sum, c| sum + [c['size'].to_f, MIN_FIELD].max }
        if unlocked_count.zero?
          return if (locked_sum - clear).abs <= 0.01
          if locked_sum > clear
            raise "Zona #{zone_id}: zamknute polia sa nezmestia. Uvolni zamok alebo zvacsi rodicovsku zonu."
          end
          raise "Zona #{zone_id}: vsetky polia su zamknute, ale nevyplnia celu zonu. Uvolni aspon jeden zamok."
        end

        max_locked = clear - unlocked_count * MIN_FIELD
        return if locked_sum <= max_locked + 0.01

        raise "Zona #{zone_id}: zamknute polia sa nezmestia. Uvolni zamok alebo zvacsi rodicovsku zonu."
      end

      def validate_shelves!(count, box, t, zone_id)
        n = Shelves.clamp(count)
        return if n.zero?

        clear_h = box[:z1] - box[:z0]
        minimum = n * t + (n + 1) * MIN_FIELD
        return if clear_h + 0.01 >= minimum

        raise "Zona #{zone_id} je prilis nizka na #{n} polic. Potrebuje aspon #{minimum.round(1)} mm."
      end

      def field_info(cut, resolved)
        { size: r2(resolved), locked: !!(cut && cut['locked']), set: !(cut && cut['size'].nil?) }
      end

      # Priecka = dielec korpusu (manufactured, sheet). Plna hlbka/vyska zony.
      def divider_desc(axis, pos, box, t, suffix_path, node_id, idx)
        if axis == 'v'
          depth = box[:y1] - box[:y0]
          height = box[:z1] - box[:z0]
          {
            suffix: "DIVV-#{suffix_path}-#{idx}", part_key: PartKeys.zone(node_id, 'divider_v', idx),
            role: 'divider_v', name: 'Priecka zvisla',
            material: :korpus, box: [t, depth, height], origin: [pos, box[:y0], box[:z0]],
            prod: { length: r2(height), width: r2(depth), thickness: r2(t) }
          }
        else
          width = box[:x1] - box[:x0]
          depth = box[:y1] - box[:y0]
          {
            suffix: "DIVH-#{suffix_path}-#{idx}", part_key: PartKeys.zone(node_id, 'divider_h', idx),
            role: 'divider_h', name: 'Priecka vodorovna',
            material: :korpus, box: [width, depth, t], origin: [box[:x0], box[:y0], pos],
            prod: { length: r2(width), width: r2(depth), thickness: r2(t) }
          }
        end
      end

      # Police v listovej zone — rovnomerne v z-rozsahu zony, odsadene od cela.
      def add_shelves(count, box, t, suffix_path, node_id, acc)
        layout = Shelves.layout(box[:z0], box[:z1], t, count)
        w = box[:x1] - box[:x0]
        sd = (box[:y1] - box[:y0]) - SHELF_FRONT_INSET
        return if sd <= 0
        layout[:shelves].each_with_index do |sh, i|
          acc[:shelves] << {
            suffix: "SHELF-#{suffix_path}-#{i + 1}", part_key: PartKeys.zone(node_id, 'shelf', i + 1),
            role: 'shelf', name: "Polica #{i + 1}",
            material: :korpus, box: [w, sd, t], origin: [box[:x0], box[:y0] + SHELF_FRONT_INSET, sh[:z]],
            prod: { length: r2(w), width: r2(sd), thickness: r2(t) }
          }
        end
      end

      def truthy(v)
        %w[true 1 yes].include?(v.to_s.downcase)
      end

      def r2(v)
        v.to_f.round(2)
      end
    end
  end
end
