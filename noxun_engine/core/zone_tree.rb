# frozen_string_literal: true
# Noxun Engine — strom zon (standard sekcia 1 + 5). Cisto vypoctovy modul (mm Float).
#
# Zona = adresovatelny vnutorny priestor korpusu. Strom: koren Z1 = cele vnutro;
# priecka (divider_v/divider_h) ROZDELI zonu na deti -> vzniknu nove zony (rekurzivne).
# Police ostavaju MODUL v zone (zonu NEdelia) — rovnomerne v ramci listovej zony.
#
# Struktura uzla (string-keyed, round-tripuje cez JSON v configu korpusu):
#   { 'split' => nil | { 'axis' => 'v'|'h', 'count' => 2..4 },
#     'shelves' => 0..4,           # len listova zona (split == nil)
#     'children' => [uzol, ...] }  # len rozdelena zona (velkost == count)
#
# ID zon: <cabinet_id>-Z<cesta> kde cesta = "1", "1.2", "1.2.1" ... (koren = 1).
# Deti .1 = min suradnica (vlavo pre 'v', dole pre 'h').
module Noxun
  module Engine
    module ZoneTree
      SHELF_FRONT_INSET = 20.0 # police odsadene od cela (mm)

      module_function

      # --- konstrukcia / uprava stromu (string-keyed) -------------------------

      def default_node(shelves = 0)
        { 'split' => nil, 'shelves' => Shelves.clamp(shelves.to_i), 'children' => [] }
      end

      def default_tree(shelves = 0)
        default_node(shelves)
      end

      # Ocisti a znormalizuje lubovolny (aj symbolovy/poskodeny) strom na kanonicku formu.
      def sanitize(node)
        return default_node(0) unless node.is_a?(Hash)
        split = node['split'] || node[:split]
        if split.is_a?(Hash)
          axis = (split['axis'] || split[:axis]).to_s
          axis = 'v' unless %w[v h].include?(axis)
          count = (split['count'] || split[:count] || 2).to_i
          count = 2 if count < 2
          count = 4 if count > 4
          kids = Array(node['children'] || node[:children]).map { |c| sanitize(c) }
          kids += Array.new(count - kids.size) { default_node(0) } if kids.size < count
          kids = kids[0, count] if kids.size > count
          { 'split' => { 'axis' => axis, 'count' => count }, 'shelves' => 0, 'children' => kids }
        else
          default_node((node['shelves'] || node[:shelves] || 0).to_i)
        end
      end

      # Navigacia na uzol podla cesty [1, k2, k3, ...] (1 = koren). Vrati uzol alebo nil.
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
      def set_split!(tree, path, axis, count)
        node = navigate(tree, path)
        return false unless node
        count = 2 if count < 2
        count = 4 if count > 4
        axis = 'h' if axis.to_s == 'h'
        axis = 'v' unless axis == 'h'
        node['split'] = { 'axis' => axis, 'count' => count }
        node['shelves'] = 0
        node['children'] = Array.new(count) { default_node(0) }
        true
      end

      # Nastav pocet polic v zone (0..4). Ak bola rozdelena, delenie sa zrusi (police = list).
      def set_shelves!(tree, path, n)
        node = navigate(tree, path)
        return false unless node
        node['split'] = nil
        node['children'] = []
        node['shelves'] = Shelves.clamp(n.to_i)
        true
      end

      # Vycisti zonu: zrusi delenie aj moduly celeho podstromu -> prazdny list.
      def clear_zone!(tree, path)
        node = navigate(tree, path)
        return false unless node
        node['split'] = nil
        node['children'] = []
        node['shelves'] = 0
        true
      end

      # --- vypocet geometrie ---------------------------------------------------

      # tree: struktÚrny strom; box: { x0,x1,y0,y1,z0,z1 } vnutro korpusu (mm); t: hrubka; cabinet_id.
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
          child_boxes, divs, ats = split_boxes(split['axis'], split['count'], box, t, suffix_path)
          zobj[:split] = { axis: split['axis'], count: split['count'], at: ats }
          acc[:zones] << zobj
          acc[:dividers].concat(divs)
          child_boxes.each_with_index do |cb, i|
            walk(node['children'][i], path + [i + 1], cb, t, cid, acc)
          end
        end
      end

      # Rozdelenie boxu na 'count' stlpcov ('v') / riadkov ('h') s (count-1) prieckami hrubky t.
      # Vrati [child_boxes, divider_deskriptory, at_pozicie].
      def split_boxes(axis, count, box, t, suffix_path)
        boxes = []
        divs = []
        ats = []
        if axis == 'v'
          col_w = (box[:x1] - box[:x0] - (count - 1) * t) / count.to_f
          x = box[:x0]
          count.times do |c|
            boxes << box.merge(x0: x, x1: x + col_w)
            x += col_w
            if c < count - 1
              divs << divider_desc('v', x, box, t, suffix_path, c + 1)
              ats << r2(x)
              x += t
            end
          end
        else
          row_h = (box[:z1] - box[:z0] - (count - 1) * t) / count.to_f
          z = box[:z0]
          count.times do |r|
            boxes << box.merge(z0: z, z1: z + row_h)
            z += row_h
            if r < count - 1
              divs << divider_desc('h', z, box, t, suffix_path, r + 1)
              ats << r2(z)
              z += t
            end
          end
        end
        [boxes, divs, ats]
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

      def r2(v)
        v.to_f.round(2)
      end
    end
  end
end
