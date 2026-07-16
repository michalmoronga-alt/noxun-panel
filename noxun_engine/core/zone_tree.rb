# frozen_string_literal: true
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
#   { 'split' => nil | {axis,count,cuts}, 'shelves' => 0..4, 'children' => [uzol,...] }
#
# ID zon: <cabinet_id>-Z<cesta> kde cesta = "1","1.2","1.2.1" ... (koren = 1). Deti .1 = min suradnica.
module Noxun
  module Engine
    module ZoneTree
      SHELF_FRONT_INSET = 20.0 # police odsadene od cela (mm)
      MIN_FIELD         = 20.0 # najmensia svetla sirka/vyska pola (mm)

      module_function

      # --- konstrukcia / uprava stromu (string-keyed) -------------------------

      def default_node(shelves = 0)
        { 'split' => nil, 'shelves' => Shelves.clamp(shelves.to_i), 'children' => [] }
      end

      def default_tree(shelves = 0)
        default_node(shelves)
      end

      # Ocisti a znormalizuje lubovolny (aj symbolovy/poskodeny/legacy) strom na kanonicku formu.
      def sanitize(node)
        return default_node(0) unless node.is_a?(Hash)
        split = node['split'] || node[:split]
        if split.is_a?(Hash)
          axis = (split['axis'] || split[:axis]).to_s
          axis = 'v' unless %w[v h].include?(axis)
          count = (split['count'] || split[:count] || 2).to_i
          count = 2 if count < 2
          count = 4 if count > 4
          cuts = sanitize_cuts(split['cuts'] || split[:cuts], count)
          kids = Array(node['children'] || node[:children]).map { |c| sanitize(c) }
          kids += Array.new(count - kids.size) { default_node(0) } if kids.size < count
          kids = kids[0, count] if kids.size > count
          { 'split' => { 'axis' => axis, 'count' => count, 'cuts' => cuts },
            'shelves' => 0, 'children' => kids }
        else
          default_node((node['shelves'] || node[:shelves] || 0).to_i)
        end
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
        node['split'] = { 'axis' => axis, 'count' => count, 'cuts' => sanitize_cuts(nil, count) }
        node['shelves'] = 0
        node['children'] = Array.new(count) { default_node(0) }
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
        walk(sanitize(tree), [1], box, t, cabinet_id, acc)
        acc
      end

      def walk(node, path, box, t, cid, acc)
        zid = "#{cid}-Z#{path.join('.')}"
        parent_id = path.size > 1 ? "#{cid}-Z#{path[0..-2].join('.')}" : nil
        split = node['split']
        leaf = split.nil?
        suffix_path = path.join('_')

        zobj = {
          id: zid, parent: parent_id,
          position: [r2(box[:x0]), r2(box[:y0]), r2(box[:z0])],
          width: r2(box[:x1] - box[:x0]), height: r2(box[:z1] - box[:z0]), depth: r2(box[:y1] - box[:y0]),
          split: nil, shelves: (leaf ? node['shelves'].to_i : 0), leaf: leaf
        }

        if leaf
          acc[:zones] << zobj
          add_shelves(node['shelves'].to_i, box, t, suffix_path, acc) if node['shelves'].to_i.positive?
        else
          child_boxes, divs, fields = split_boxes(split, box, t, suffix_path)
          zobj[:split] = { axis: split['axis'], count: split['count'], fields: fields }
          acc[:zones] << zobj
          acc[:dividers].concat(divs)
          child_boxes.each_with_index do |cb, i|
            walk(node['children'][i], path + [i + 1], cb, t, cid, acc)
          end
        end
      end

      # Rozdelenie boxu podla poli (split['cuts']) s (count-1) prieckami hrubky t.
      # Vrati [child_boxes, divider_deskriptory, fields_info(pre nahlad)].
      def split_boxes(split, box, t, suffix_path)
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
              divs << divider_desc('v', x, box, t, suffix_path, c + 1)
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
              divs << divider_desc('h', z, box, t, suffix_path, r + 1)
              z += t
            end
          end
        end
        [boxes, divs, fields]
      end

      # Rozlozi svetly priestor (span - (count-1)*t) medzi `count` poli:
      #   locked pole -> drzi svoju size (clamp na dostupne);
      #   nezamknute -> rozdelia zvysok PROPORCNE podla svojich size (nil size = rovnomerny podiel).
      def resolve_fields(cuts, count, span, t)
        clear = span - (count - 1) * t
        clear = 0.0 if clear.negative?
        cuts = sanitize_cuts(cuts, count)

        locked_sum = 0.0
        cuts.each { |c| locked_sum += clamp_field(c['size'], clear) if c['locked'] && c['size'] }
        free = clear - locked_sum
        free = 0.0 if free.negative?

        unlocked = cuts.each_index.reject { |i| cuts[i]['locked'] && cuts[i]['size'] }
        known = unlocked.map { |i| cuts[i]['size'] }.compact
        avg = known.empty? ? (free / [unlocked.size, 1].max) : (known.reduce(0.0, :+) / known.size)
        weight_sum = unlocked.reduce(0.0) { |s, i| s + (cuts[i]['size'] || avg) }
        weight_sum = 1.0 if weight_sum <= 0

        sizes = Array.new(count, 0.0)
        cuts.each_index do |i|
          if cuts[i]['locked'] && cuts[i]['size']
            sizes[i] = clamp_field(cuts[i]['size'], clear)
          else
            w = cuts[i]['size'] || avg
            sizes[i] = free * (w / weight_sum)
          end
        end
        sizes
      end

      def clamp_field(size, clear)
        s = size.to_f
        s = MIN_FIELD if s < MIN_FIELD
        s = clear if s > clear && clear.positive?
        s
      end

      def field_info(cut, resolved)
        { size: r2(resolved), locked: !!(cut && cut['locked']), set: !(cut && cut['size'].nil?) }
      end

      # Priecka = dielec korpusu (manufactured, sheet). Plna hlbka/vyska zony.
      def divider_desc(axis, pos, box, t, suffix_path, idx)
        if axis == 'v'
          depth = box[:y1] - box[:y0]
          height = box[:z1] - box[:z0]
          {
            suffix: "DIVV-#{suffix_path}-#{idx}", role: 'divider_v', name: 'Priecka zvisla',
            material: :korpus, box: [t, depth, height], origin: [pos, box[:y0], box[:z0]],
            prod: { length: r2(height), width: r2(depth), thickness: r2(t) }
          }
        else
          width = box[:x1] - box[:x0]
          depth = box[:y1] - box[:y0]
          {
            suffix: "DIVH-#{suffix_path}-#{idx}", role: 'divider_h', name: 'Priecka vodorovna',
            material: :korpus, box: [width, depth, t], origin: [box[:x0], box[:y0], pos],
            prod: { length: r2(width), width: r2(depth), thickness: r2(t) }
          }
        end
      end

      # Police v listovej zone — rovnomerne v z-rozsahu zony, odsadene od cela.
      def add_shelves(count, box, t, suffix_path, acc)
        layout = Shelves.layout(box[:z0], box[:z1], t, count)
        w = box[:x1] - box[:x0]
        sd = (box[:y1] - box[:y0]) - SHELF_FRONT_INSET
        return if sd <= 0
        layout[:shelves].each_with_index do |sh, i|
          acc[:shelves] << {
            suffix: "SHELF-#{suffix_path}-#{i + 1}", role: 'shelf', name: "Polica #{i + 1}",
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
