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

      # UI-C2 (N22): strom ma NAJVIAC 3 urovne — Z1 · Z1.x · Z1.x.y. Guard je
      # v `set_split!` (server), zrkadlo v `ui/js/actions.js` (draft aj online).
      # DOLEZITE: `sanitize` hlbku NEOREZAVA — legacy strom alebo sablona z inej
      # verzie sa musi dat otvorit aj precitat (orezanie by ticho zmazalo dielce
      # zakazky). Strom sa len uz nedelí a panel hlbsie urovne oznaci varovanim.
      MAX_LEVELS = 3

      # Zlomkove presety pola „Prva zona" (viditelne v paneli) a magnetove body
      # tahania priecky (N20/N21). Parser prijme aj dalsie zlomky — toto su
      # ponuky, nie whitelist.
      FIELD_FRACTIONS = [Rational(1, 4), Rational(1, 3), Rational(1, 2)].freeze
      SNAP_FRACTIONS  = [Rational(1, 4), Rational(1, 2), Rational(3, 4)].freeze

      # Presnost rozmerov poli (mm). STANDARD zna mm Float — zaokruhlovanie na
      # cele mm by pri delení na 3 polia „zjedlo" az 2 mm z korpusu.
      FIELD_EPS = 0.01

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

      # Je uzol LIST (bez delenia)? UI-C2: delit a davat police smie VYHRADNE list;
      # delena zona sa najprv vycisti („Vycistit zonu" je jedina destruktivna cesta).
      def leaf?(node)
        node.is_a?(Hash) && !(node['split'] || node[:split]).is_a?(Hash)
      end

      # Kolko UROVNI ma strom (koren = 1). Cita sa zo SUROVEHO stromu — pouziva sa
      # na varovanie pri legacy sablone (B4), preto nesmie nic orezavat.
      def depth(node, level = 1)
        node = {} unless node.is_a?(Hash)
        kids = node['children'] || node[:children]
        split = node['split'] || node[:split]
        return level unless split.is_a?(Hash) && kids.is_a?(Array) && !kids.empty?

        kids.map { |k| depth(k, level + 1) }.max || level
      end

      # Rozdel uzol na 'count' casti pozdlz osi. Zaklada NOVY podstrom, preto smie
      # bezat LEN na liste a LEN do MAX_LEVELS urovni (UI-C2 guardy — server, nie
      # len HTML `disabled`: callback HtmlDialogu vie prist aj zo zastaraneho panela).
      # cuts sa zalozia ako auto (rovnomerne) — konkretne rozmery/zamky nastavi set_field!.
      def set_split!(tree, path, axis, count)
        node = navigate(tree, path)
        return false unless node
        return false unless leaf?(node)               # delena zona: najprv Vycistit zonu
        return false if Array(path).length >= MAX_LEVELS # N22: max 3 urovne
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

      # Police patria LISTOVEJ zone (UI-C2). Na delenej by tichy zapis zmazal cely
      # podstrom aj s dielcami — to smie iba `clear_zone!`.
      def set_shelves!(tree, path, n)
        node = navigate(tree, path)
        return false unless node
        return false unless leaf?(node)
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
      # Vrati: { zones:[ploche objekty s geometriou], dividers:[deskriptory], shelves:[deskriptory],
      #          warnings:[BuildPlan.warning], raw_bounds:{ zone_id => box } } — nefatalne stavy
      #          (napr. preskocene police).
      #
      # KOV-C1: `raw_bounds` je ADITIVNY kanal NEZAOKRUHLENYCH hraníc zón
      # (`zones` naďalej nesú `r2` hodnoty a IDENTICKY sa ukladajú do configu).
      # Recepty zásuviek porovnávajú svetlé rozmery INKLUZÍVNE a bez EPS —
      # zaokrúhlená 104.995 -> 105.0 by ticho povolila zásuvku, ktorá sa nezmestí.
      def compute(tree, box, t, cabinet_id)
        acc = { zones: [], dividers: [], shelves: [], warnings: [], raw_bounds: {} }
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
        # KOV-C1: surove hranice zony BOKOM (do `zones` nevstupujú — ukladany
        # config sa nemeni ani o jedno pole).
        (acc[:raw_bounds] ||= {})[zid] = { x0: box[:x0].to_f, x1: box[:x1].to_f,
                                           y0: box[:y0].to_f, y1: box[:y1].to_f,
                                           z0: box[:z0].to_f, z1: box[:z1].to_f }

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

      # --- UI-C2: JEDNA geometria pre zlomky aj magnet tahania -----------------
      #
      # Zona ma rozpatie `span`, `count` poli a (count-1) priecok hrubky `t`.
      # SVETLY priestor (co ostane poliam) je `span - (count-1)*t`.
      #
      # Zlomok (1/2 zony) aj magnet tahania hovoria o TOM ISTOM: kde ma sediet
      # STRED priecky. Preto je to JEDNA funkcia — pole „Prva zona" ju vola pre
      # priecku 0, drag pre priecku `i`:
      #
      #   stred priecky i  =  frac * span
      #   svetly sucet poli 0..i  =  frac * span - i*t - t/2
      #
      # Pri count=2 a frac=1/2 z toho vyjde presne polovica SVETLEHO priestoru
      # (nie polovica rozpatia) — to je ten rozdiel, ktory mockup pocital nahrubo
      # (864/2 = 432 namiesto (864-18)/2 = 423) a stolarovi by ho vyrobil bok
      # posunuty o 9 mm.
      def clear_space(span, count, t)
        c = span.to_f - ([count.to_i, 1].max - 1) * t.to_f
        c.negative? ? 0.0 : c
      end

      # Svetly sucet poli 0..index pri zlomku `frac` (Rational alebo Float).
      def cum_for_fraction(span, count, t, index, frac)
        (frac.to_f * span.to_f) - index.to_i * t.to_f - t.to_f / 2.0
      end

      # Ktore zlomky su pre priecku `index` vobec dosiahnutelne (ostatne polia
      # musia dostat aspon MIN_FIELD). Vrati [{ frac:, cum:, size_hint: }].
      def fraction_options(span, count, t, index, fracs = FIELD_FRACTIONS)
        clear = clear_space(span, count, t)
        lo = (index.to_i + 1) * MIN_FIELD
        hi = clear - (count.to_i - index.to_i - 1) * MIN_FIELD
        fracs.map { |f| [f, cum_for_fraction(span, count, t, index, f)] }
             .select { |(_f, cum)| cum >= lo - FIELD_EPS && cum <= hi + FIELD_EPS }
             .map { |(f, cum)| { 'label' => "#{f.numerator}/#{f.denominator}",
                                 'frac' => f.to_f, 'cum' => r2(cum) } }
      end

      # Magnet: prilep svetly sucet `cum` na najblizsi zlomok, ak je bliz nez
      # `tol_mm`. `tol_mm <= 0` (Alt) = magnet vypnuty — vrati vstup nedotknuty.
      def snap_cum(span, count, t, index, cum, tol_mm, fracs = SNAP_FRACTIONS)
        return cum.to_f if tol_mm.to_f <= 0

        best = nil
        fracs.each do |f|
          target = cum_for_fraction(span, count, t, index, f)
          d = (target - cum.to_f).abs
          best = [d, target] if d <= tol_mm.to_f && (best.nil? || d < best[0])
        end
        best ? best[1] : cum.to_f
      end

      # --- UI-C2: PRISNA validacia poli prichadzajucich z panela ---------------
      #
      # `sanitize_cuts` je OPRAVNA vrstva (legacy strom sa musi dat precitat), a
      # preto je zamerne tolerantna — `'abc'.to_f` je 0.0. Vstup z panela vsak
      # tolerantny byt NESMIE: „650-36" by sa ticho stalo 650 a stolar by vyrobil
      # iny nabytok, nez pouzivatel zadal. Preto ma zapisova cesta vlastnu,
      # PRISNU kontrolu — a odmietnutie je cele (ziadny ciastocny zapis).
      #
      # Vrati nil (OK) alebo hlasku pre pouzivatela.
      #   clear: svetly priestor zony, ak ho volajuci pozna (sucet sa kontroluje
      #          s toleranciou FIELD_EPS); nil = kontrola suctu sa preskoci.
      def validate_cuts(cuts, count, clear: nil)
        count = count.to_i
        return 'Rozdelenie zóny je poškodené — obnov panel.' unless cuts.is_a?(Array) && cuts.length == count

        sizes = []
        cuts.each_with_index do |c, i|
          return 'Rozmery polí sú poškodené — obnov panel.' unless c.is_a?(Hash)

          sz = strict_mm(c['size'].nil? ? c[:size] : c['size'])
          return "Pole #{i + 1}: rozmer nie je platné číslo." if sz == :invalid
          next if sz.nil? # auto pole je platne — dopocita ho resolve_fields

          return "Pole #{i + 1}: #{fmt(sz)} mm je menej než najmenšie pole (#{fmt(MIN_FIELD)} mm)." if
            sz < MIN_FIELD - FIELD_EPS

          sizes << sz
        end
        return nil if clear.nil? || sizes.length != count

        # Codex #177 P2: tolerancia RASTIE S POCTOM POLI. Kazda hodnota prichadza
        # z panela zaokruhlena na 0,01 mm, takze pri styroch poliach sa moze sucet
        # od skutocneho svetleho priestoru lisit az o 4 × pol jednotky. Prisnejsia
        # tolerancia by odmietala rozdelenia, ktore su geometricky v poriadku;
        # 0,04 mm je v nabytkarstve stale pod hranicou merania.
        total = sizes.reduce(0.0, :+)
        tol = FIELD_EPS * [count, 1].max
        return nil if (total - clear.to_f).abs <= tol

        if total > clear.to_f
          "Polia sa do zóny nezmestia: #{fmt(total)} mm proti #{fmt(clear.to_f)} mm svetlého priestoru."
        else
          "Polia nevyplnia celú zónu: #{fmt(total)} mm proti #{fmt(clear.to_f)} mm svetlého priestoru."
        end
      end

      # Prisny prevod na mm: nil/prazdne = nil (auto), cislo = Float,
      # cokolvek ine (text, NaN, Infinity) = :invalid. ZIADNY `to_f` fallback.
      def strict_mm(raw)
        return nil if raw.nil?
        return nil if raw.is_a?(String) && raw.strip.empty?

        v = if raw.is_a?(Numeric)
              raw.to_f
            elsif raw.is_a?(String)
              Float(raw.strip.tr(',', '.')) rescue nil
            end
        return :invalid if v.nil?
        return :invalid unless v.finite?

        v
      end

      def fmt(v)
        r = v.to_f.round(2)
        (r - r.round).abs < 0.001 ? r.round.to_s : r.to_s.tr('.', ',')
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
            prod: { length: r2(height), width: r2(depth), thickness: r2(t) },
            axes: PartFaces::AXES_UPRIGHT
          }
        else
          width = box[:x1] - box[:x0]
          depth = box[:y1] - box[:y0]
          {
            suffix: "DIVH-#{suffix_path}-#{idx}", part_key: PartKeys.zone(node_id, 'divider_h', idx),
            role: 'divider_h', name: 'Priecka vodorovna',
            material: :korpus, box: [width, depth, t], origin: [box[:x0], box[:y0], pos],
            prod: { length: r2(width), width: r2(depth), thickness: r2(t) },
            axes: PartFaces::AXES_LYING
          }
        end
      end

      # Police v listovej zone — rovnomerne v z-rozsahu zony, odsadene od cela.
      # Prilis plytka zona (hlbka <= inset) uz police nepreskakuje ticho — hlasi warning.
      def add_shelves(count, box, t, suffix_path, node_id, acc)
        layout = Shelves.layout(box[:z0], box[:z1], t, count)
        w = box[:x1] - box[:x0]
        sd = (box[:y1] - box[:y0]) - SHELF_FRONT_INSET
        if sd <= 0
          (acc[:warnings] ||= []) << BuildPlan.warning('shelf_skipped_shallow_zone',
                                                       "Zona #{node_id}: prilis plytka na police (#{count} ks preskocenych).",
                                                       part_key: PartKeys.zone(node_id, 'shelf', 1),
                                                       data: { 'count' => count, 'depth' => r2(box[:y1] - box[:y0]) })
          return
        end
        layout[:shelves].each_with_index do |sh, i|
          acc[:shelves] << {
            suffix: "SHELF-#{suffix_path}-#{i + 1}", part_key: PartKeys.zone(node_id, 'shelf', i + 1),
            role: 'shelf', name: "Polica #{i + 1}",
            material: :korpus, box: [w, sd, t], origin: [box[:x0], box[:y0] + SHELF_FRONT_INSET, sh[:z]],
            prod: { length: r2(w), width: r2(sd), thickness: r2(t) },
            axes: PartFaces::AXES_LYING
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
