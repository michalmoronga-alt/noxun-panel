# frozen_string_literal: true
# Noxun Engine — KOV-A2b: SMER OTVARANIA V MODELI. Zapnuty prepinac nakresli na
# PREDNU plochu kazdeho cela symbol toho, ako sa celo otvara: prerusovana sipka
# na volnu hranu (smer = STRANA PANTOV), `∧` vyklop, `∨` sklop, plne X blenda.
# Jeden pohlad na celu zakazku — „ktore dvierka su lave" sa uz nemusi lustit
# z kariet po jednom.
#
# Je to PRESNE ZRKADLO `grain_check.rb` (K2/D-87): ten isty lifecycle overlayu,
# ta ista pamat prepinaca, ten isty broadcast do oboch okien. Vlastny modul
# (nie dalsi stav K2) je to preto, ze hovori o INEJ veci — K2 je o smere kresby
# DEKORU, toto je o smere OTVARANIA.
#
# ============================ ZDROJ SMERU (jedina autorita) ===================
# Kresli sa VYHRADNE z ULOZENEHO CONFIGU skrinky (`front_items`) cez
# `Fronts.direction_slots` (KOV-A1) — z GEOMETRIE sa NEODVODZUJE NIC a katalog
# sa tu necita. Trojstav A1 plati bez vynimky (R-39: ziadny default, ziadna
# heuristika — ani v overlayi):
#   'left'/'right' — vyriesene   -> sipka na volnu hranu
#   'unset'        — vedome neurcene -> prerusovany kruh + „?" (jantar)
#   kluc CHYBA     — LEGACY      -> NEKRESLI SA NIC (a nikdy sa nic nedoplna)
# KRAJNE kridla 2/3/4-kridlovych dvierok su ODVODENE (A1 variant a: p1 = panty
# vlavo, posledne = panty vpravo) — su geometricky iste, takze sa kreslia vzdy.
# Vyber symbolu je CISTE ZRKADLO `frontWingSymbols`/`frontTypeSymbol` v
# `ui/js/core.js` (2D nahlad karty cela) — stráži to headless test nad
# spolocnymi fixturami: co vidno v nahlade, to musi byt aj v modeli.
#
# ============================ GEOMETRIA =======================================
# Symbol lezi na PREDNEJ ploche panelu (rovina MIN osi hrubky, teda ta, na ktoru
# sa pouzivatel pozera) posunutej o `OUT_MM` von z telesa — mensie nez
# `HoverEdge::OUT_MM`, takze zvyraznena hrana ostava navrchu. Ktora os je
# dlzka/sirka/hrubka NIE JE hadanie z rozmerov: berie sa zo zdielaneho kontraktu
# `PartFaces.axes_for_snapshot` (celo ma `AXES_FRONT` — dlzka Z, sirka X,
# hrubka Y). Neoveritelne osi = dielec sa NEKRESLI (zasada D-88).
# Dielec sa hlada podla `part_key` medzi vnorenymi `kind: part` — rovnaka cesta
# ako `ProductionCore.pids_in_cabinet`. Kresli sa PER INSTANCIA: dve skrinky so
# zdielanym `cabinet_id` maju kazda svoj config a kazda svoju kresbu.
#
# ============================ FARBY (rozhodnutie A2b) =========================
# COLOR = #880e4f (tmava malinova) pre VYRIESENE symboly (sipky, ∧, ∨, X):
#   - NIE cervena/oranzova/zelena: to su tri stavy olepu (`EdgeCheck::COLORS`),
#   - NIE #37474f: to je smer kresby (`GrainCheck::COLOR`) — oba prekrytia
#     mozu byt zapnute naraz nad TYM ISTYM celom,
#   - NIE teal: `--nx-select` aj stav „olepene" su ta ista rodina (HoverEdge),
#   - NIE fialova/modra: v modeli splyva s modrym zvyraznenim vyberu a s osami
#     (lekcia D-105, Michal 11.8.).
#   Najblizsi sused je smer kresby (vzdialenost 99 v RGB) — viac nez uz prijata
#   dvojica kresba/hover (81). VEDOMA SLABINA (ta ista ako pri K2): na velmi
#   tmavom dekore kontrast klesa a symbol je citatelny skor TVAROM.
# COLOR_UNSET = #e65100 (token `--nx-warn-fg`) pre „?" a jeho kruh — je to TEN
#   ISTY jantar, akym svieti badge „smer?" v Inspectorovi, takze panel a model
#   hovoria jednou farbou. Priznana blizkost k oranzovej `EdgeCheck::EXTRA`
#   (#ff8c00, vzdialenost 64) je VEDOMA: rozhodujuce je, aby sa „neurcene"
#   odlisilo od VYRIESENEHO smeru (vzdialenost 140), a stavy olepu su tenke
#   plosky NA HRANACH, kdezto „?" je glyf v STREDE cela.
#
# ============================ CO SA NEDEJE ====================================
# ZIADNA mutacia modelu: kresli sa cez `Sketchup::Overlay` (SU 2023+) NAD
# modelom — ziadna operacia, ziadny undo krok, nic sa neuklada do .skp. Sken je
# READ-ONLY a bezi LEN pri zapnuti a po `ModelObserver` dirty; `draw` je lazy
# nad hotovou cache.
module Noxun
  module Engine
    module DirectionCheck
      # Symboly, ktore vie overlay nakreslit. Mena su ZHODNE s JS nahladom
      # (`frontDirSymbol`/`frontTypeSymbol` v ui/js/core.js) — to nie je nahoda,
      # ale kontrakt: obe strany kreslia to iste.
      SYM_LEFT = 'left'
      SYM_RIGHT = 'right'
      SYM_UNKNOWN = 'unknown'
      SYM_UP = 'up'
      SYM_DOWN = 'down'
      SYM_CROSS = 'cross'
      SYMBOLS = [SYM_LEFT, SYM_RIGHT, SYM_UNKNOWN, SYM_UP, SYM_DOWN, SYM_CROSS].freeze
      # Symboly kridiel dvierok (do poctu „kridel" v liste sa ratau len tieto).
      WING_SYMBOLS = [SYM_LEFT, SYM_RIGHT, SYM_UNKNOWN].freeze

      # Posun symbolu VON z telesa (mm) — bez neho by bojoval o hlbku s prednou
      # plochou cela (z-fighting). Mensie nez HoverEdge::OUT_MM (0,9), takze
      # zvyraznena hrana ostava nad kresbou; vacsie nez EdgeCheck::OUT_MM (0,5),
      # aby symbol nezmizol pod ploskou olepu na tej istej ploche.
      OUT_MM = 0.7
      COLOR = [136, 14, 79].freeze        # #880e4f — vyriesene symboly
      COLOR_UNSET = [230, 81, 0].freeze   # #e65100 = token --nx-warn-fg
      LINE_WIDTH = 3
      TEXT_SIZE = 14
      TEXT_UNKNOWN = '?'

      # --- proporcie symbolov (podiely rozmerov panelu) ------------------------
      ARROW_TAIL = 0.16   # zaciatok drieku od hrany pri pantoch
      ARROW_TIP  = 0.86   # HROT pri VOLNEJ hrane
      HEAD_FRAC  = 0.16   # velkost hrotu sipky
      CHEVRON_FRAC = 0.22 # velkost ∧ / ∨
      GLYPH_MIN  = 6.0    # mm — pod tym uz symbol nie je symbol
      GLYPH_MAX  = 45.0   # mm — nad tym by na velkom cele „krical"
      EDGE_FRAC  = 0.16   # odsadenie ∧/∨ od hornej/dolnej hrany
      CROSS_INSET = 0.12  # odsadenie X od hran (blenda)
      RING_FRAC  = 0.22   # polomer kruhu „neurcene"
      RING_MIN   = 8.0
      RING_MAX   = 60.0
      RING_SEGS  = 24     # polygon namiesto kruznice (GL_LINES)

      OVERLAY_ID = 'noxun.engine.direction_check'
      OVERLAY_NAME = 'Noxun — smer otvárania'

      # Prepinac je vec POCITACA, nie zakazky — zije v %APPDATA%, NIKDY v .skp
      # (vzor EdgeCheck D-105 / GrainCheck K2). VSTUPNE BODY su DVA: tlacidlo
      # „Smer otvárania" v raile Inspectora a prepinac v liste sekcie Kontrola
      # okna STUDIO. Oba idu cez `Engine.toggle_direction_check` a citaju ten
      # isty `ui_state` — ZIADNY druhy kanal a ziadna vlastna kopia stavu.
      SETTINGS_FILE = 'direction_check.json'
      SETTINGS_STD = 1
      ACTIVE_KEY = 'active'

      module_function

      # ================= CISTE ROZHODNUTIA (headless testovatelne) =============

      # Stav slotu -> symbol. Zrkadlo `frontDirSymbol` (ui/js/core.js).
      # Neznamy stav aj CHYBAJUCI kluc (legacy) = nil, teda NEKRESLI SA NIC —
      # ziadny fallback na stranu (R-39).
      def dir_symbol(state)
        case state.to_s
        when 'left' then SYM_LEFT
        when 'right' then SYM_RIGHT
        when 'unset' then SYM_UNKNOWN
        end
      end

      # Symbol NEDVIEROKOVEHO typu. Zrkadlo `frontTypeSymbol` — zasuvka je
      # VEDOME bez symbolu (∧ by splyval s vyklopom).
      def type_symbol(type)
        case type.to_s
        when 'lift' then SYM_UP
        when 'fall' then SYM_DOWN
        when 'blind' then SYM_CROSS
        end
      end

      # Symboly VSETKYCH kridiel dvierok. Zrkadlo `frontWingSymbols`: krajne
      # kridla su ODVODENE (A1 variant a), stredne sa beru zo SLOTOV servera,
      # jedno kridlo nema co odvodzovat.
      def wing_symbols(wings_n, slots)
        n = wings_n.to_i
        return [] if n < 1

        by = {}
        Array(slots).each do |s|
          next unless s.is_a?(Hash)

          w = (s[:wing] || s['wing']).to_s
          by[w] = s.key?(:state) ? s[:state] : s['state']
        end
        return [dir_symbol(by['single'])] if n == 1

        (1..n).map do |i|
          next SYM_LEFT if i == 1
          next SYM_RIGHT if i == n

          dir_symbol(by["p#{i}"])
        end
      end

      # part_key VSETKYCH kridiel dvierok — presne tie, ktorymi ich pomenoval
      # `Fronts.panels_for` (1 kridlo `single`, 2 `left`/`right`, 3-4 `p1..pN`).
      def wing_keys(front_id, wings_n)
        n = wings_n.to_i
        case n
        when 1 then [PartKeys.front(front_id, 'wing', 'single')]
        when 2 then [PartKeys.front(front_id, 'wing', 'left'),
                     PartKeys.front(front_id, 'wing', 'right')]
        when 3, 4 then (1..n).map { |i| PartKeys.front(front_id, 'wing', "p#{i}") }
        else []
        end
      end

      # part_key nedvierkoveho cela (KOV-A1 kanonicke kluce).
      def type_key(front_id, type)
        case type.to_s
        when 'lift', 'fall' then PartKeys.front(front_id, 'flap')
        when 'blind' then PartKeys.front(front_id, 'blind')
        end
      end

      # Co sa ma pri JEDNEJ resolved polozke `front_items` nakreslit:
      #   [{ key: part_key, symbol: 'left'|… }]
      # Prazdne pole = nic (legacy dvierka, zasuvka, „Bez cela").
      # CISTA funkcia — ziadne IO, ziadny SketchUp.
      def marks(item)
        return [] unless item.is_a?(Hash)

        fid = item['id'].to_s
        return [] if fid.empty?

        if item['type'].to_s == 'door'
          n = item['wings_n'].to_i
          keys = wing_keys(fid, n)
          syms = wing_symbols(n, Fronts.direction_slots(item))
          keys.each_with_index.filter_map do |k, i|
            syms[i] ? { key: k, symbol: syms[i] } : nil
          end
        else
          sym = type_symbol(item['type'])
          key = sym ? type_key(fid, item['type']) : nil
          key ? [{ key: key, symbol: sym }] : []
        end
      end

      # Kolko kridiel tohto cela je LEGACY (kluc smeru v configu vobec nie je).
      # Cislo do listy — nekresli sa za ne nic, ale mlcat o nich by znamenalo
      # tvarit sa, ze zakazka je hotova.
      def legacy_count(item)
        return 0 unless item.is_a?(Hash) && item['type'].to_s == 'door'

        Fronts.direction_slots(item).count { |s| s[:state].nil? }
      end

      # --- geometria symbolu ---------------------------------------------------

      # Usecky symbolu v LOKALNYCH mm + kotva textu:
      #   { 'lines' => [[[x,y,z],[x,y,z]], …], 'text' => [x,y,z] | nil }
      # lo/hi = protilahle rohy kvadra dielca (obal definicie), `ax` = osi
      # deskriptora, `out` = posun VON z telesa. Prazdne pole = nekresli sa nic
      # (neznamy symbol, chybajuce osi, degenerovany kvader).
      def symbol_mm(lo, hi, ax, symbol, out = OUT_MM)
        sym = symbol.to_s
        empty = { 'lines' => [], 'text' => nil }
        return empty unless SYMBOLS.include?(sym)
        return empty unless lo.is_a?(Array) && hi.is_a?(Array) && lo.length == 3 && hi.length == 3
        return empty unless ax.is_a?(Hash)

        li = ax[:length]
        wi = ax[:width]
        ti = ax[:thickness]
        return empty if li.nil? || wi.nil? || ti.nil? || [li, wi, ti].uniq.length != 3

        w0 = lo[wi].to_f
        l0 = lo[li].to_f
        span_w = hi[wi].to_f - w0
        span_l = hi[li].to_f - l0
        return empty unless span_w > 0.0 && span_l > 0.0

        # PREDNA plocha = MIN osi hrubky (celo stoji pred korpusom), posunuta VON.
        depth = lo[ti].to_f - out
        flat = plan_2d(sym, w0, span_w, l0, span_l)
        { 'lines' => flat['lines'].map { |a, b| [point_at(ti, depth, wi, a[0], li, a[1]),
                                                point_at(ti, depth, wi, b[0], li, b[1])] },
          'text' => (flat['text'] ? point_at(ti, depth, wi, flat['text'][0], li, flat['text'][1]) : nil) }
      end

      # Symbol v rovine cela ako dvojice [sirka, dlzka] — cely tvar zije TU,
      # aby sa dal testovat bez osi aj bez SketchUpu.
      def plan_2d(sym, w0, span_w, l0, span_l)
        case sym
        when SYM_LEFT, SYM_RIGHT
          { 'lines' => arrow_2d(sym, w0, span_w, l0, span_l), 'text' => nil }
        when SYM_UP, SYM_DOWN
          { 'lines' => chevron_2d(sym == SYM_UP, w0, span_w, l0, span_l), 'text' => nil }
        when SYM_CROSS
          { 'lines' => cross_2d(w0, span_w, l0, span_l), 'text' => nil }
        else
          c = [w0 + span_w / 2.0, l0 + span_l / 2.0]
          { 'lines' => ring_2d(c[0], c[1], ring_radius(span_w, span_l)), 'text' => c }
        end
      end

      # Sipka: driek po sirke cela v polovici vysky, HROT pri VOLNEJ hrane
      # ('left' = panty vlavo -> hrot vpravo, teda v smere rastucej sirky).
      def arrow_2d(sym, w0, span_w, l0, span_l)
        mid = l0 + span_l / 2.0
        if sym == SYM_LEFT
          tail = w0 + span_w * ARROW_TAIL
          tip  = w0 + span_w * ARROW_TIP
        else
          tail = w0 + span_w * (1.0 - ARROW_TAIL)
          tip  = w0 + span_w * (1.0 - ARROW_TIP)
        end
        hs = glyph_size(span_w, span_l, HEAD_FRAC, (tip - tail).abs)
        back = tip + (tip > tail ? -hs : hs)
        [[[tail, mid], [tip, mid]],
         [[tip, mid], [back, mid + hs]],
         [[tip, mid], [back, mid - hs]]]
      end

      # ∧ (vyklop) pri HORNEJ hrane, ∨ (sklop) pri DOLNEJ — hrot ukazuje tam,
      # kam sa celo pohne.
      def chevron_2d(up, w0, span_w, l0, span_l)
        mid = w0 + span_w / 2.0
        hs = glyph_size(span_w, span_l, CHEVRON_FRAC, span_l * (1.0 - 2.0 * EDGE_FRAC))
        apex = up ? l0 + span_l * (1.0 - EDGE_FRAC) : l0 + span_l * EDGE_FRAC
        arm = up ? apex - hs : apex + hs
        [[[mid, apex], [mid - hs, arm]],
         [[mid, apex], [mid + hs, arm]]]
      end

      # Blenda sa NEHYBE — plne X cez cely panel (jediny PLNY symbol).
      def cross_2d(w0, span_w, l0, span_l)
        iw = span_w * CROSS_INSET
        il = span_l * CROSS_INSET
        a = w0 + iw
        b = w0 + span_w - iw
        c = l0 + il
        d = l0 + span_l - il
        [[[a, c], [b, d]], [[a, d], [b, c]]]
      end

      # „Neurcene" = prerusovany kruh (polygon) okolo otaznika. Je to STAV,
      # nie strana — preto zamerne ziadna sipka.
      def ring_2d(cx, cy, r)
        return [] unless r.positive?

        step = 2.0 * Math::PI / RING_SEGS
        (0...RING_SEGS).map do |i|
          a0 = step * i
          a1 = step * (i + 1)
          [[cx + r * Math.cos(a0), cy + r * Math.sin(a0)],
           [cx + r * Math.cos(a1), cy + r * Math.sin(a1)]]
        end
      end

      def ring_radius(span_w, span_l)
        glyph_size(span_w, span_l, RING_FRAC, [span_w, span_l].min, RING_MIN, RING_MAX)
      end

      # Velkost glyfu: podiel MENSIEHO rozmeru panelu, orezany do rozumnych mm
      # a nikdy vacsi nez polovica dostupneho miesta (`limit`).
      def glyph_size(span_w, span_l, frac, limit, lo_mm = GLYPH_MIN, hi_mm = GLYPH_MAX)
        v = [span_w, span_l].min * frac
        v = lo_mm if v < lo_mm
        v = hi_mm if v > hi_mm
        cap = limit.abs / 2.0
        v > cap ? cap : v
      end

      def point_at(ai, av, bi, bv, ci, cv)
        p = [0.0, 0.0, 0.0]
        p[ai] = av
        p[bi] = bv
        p[ci] = cv
        p
      end

      def entity_id(ent)
        ent.respond_to?(:entityID) ? ent.entityID : nil
      rescue StandardError
        nil
      end

      # ================= PREPINAC: perzistencia (%APPDATA%) ====================

      def settings_dir
        return Materials.dir if defined?(Materials)

        File.join(ENV['APPDATA'].to_s, 'NOXUN', 'Engine')
      end

      def settings_path
        File.join(settings_dir, SETTINGS_FILE)
      end

      # Zapamatany stav prepinaca. Poskodeny subor / cudzi typ = false (nikdy
      # vynimka a nikdy „nahodne" zapnuta kresba nad cudzou zakazkou).
      def remembered?
        raw = JsonFileStore.available?(settings_path) ? JsonFileStore.read(settings_path) : nil
        raw.is_a?(Hash) && raw[ACTIVE_KEY] == true
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.remembered?')
        false
      end

      def remember!(value)
        JsonFileStore.write(settings_path, { ACTIVE_KEY => value == true, 'std' => SETTINGS_STD })
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.remember!')
        false
      end

      # ================= SKEN MODELU (SketchUp) ================================
      # Vysledok:
      #   { 'occurrences' => [ { 'part' =>, 'symbol' =>, 'lines' => [Point3d…],
      #                          'text' => Point3d|nil } ],
      #     'legacy' => pocet kridiel bez ulozeneho smeru }
      # Body su UZ v SVETOVYCH suradniciach — `draw` uz nepocita nic.
      def scan(model)
        out = { 'occurrences' => [], 'legacy' => 0 }
        return out unless model

        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          next unless Store.kind(inst) == 'cabinet'
          next unless drawable?(inst)

          scan_cabinet(out, inst)
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.scan')
        out
      end

      # Kresli sa len to, co v modeli VIDNO (skryty tag `Noxun/Čelá` je bezny
      # pohyb z panela) — branka je ZDIELANA s kontrolou hran a kresby.
      def drawable?(ent)
        return true unless defined?(EdgeCheck)

        EdgeCheck.drawable?(ent)
      rescue StandardError
        true
      end

      def scan_cabinet(out, inst)
        cfg = Store.config(inst) || {}
        items = cfg['front_items']
        return unless items.is_a?(Array) && !items.empty?

        parts = nil
        base = inst.transformation
        items.each do |item|
          out['legacy'] += legacy_count(item)
          mk = marks(item)
          next if mk.empty?

          parts ||= parts_by_key(inst)
          mk.each do |m|
            part = parts[m[:key]]
            next if part.nil? || !drawable?(part)

            add_occurrence(out, part, base * part.transformation, m[:symbol])
          end
        end
      end

      # Vnorene VYROBNE dielce podla `part_key` — rovnaka cesta ako
      # `ProductionCore.pids_in_cabinet`. Prvy vyskyt vyhrava (dva dielce s tym
      # istym klucom v jednej skrinke su chyba identity, nie dovod kreslit dva
      # razy).
      def parts_by_key(inst)
        out = {}
        inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
          next unless Store.kind(pi) == 'part'

          key = Store.get(pi, 'part_key').to_s
          next if key.empty? || out.key?(key)

          out[key] = pi
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.parts_by_key')
        {}
      end

      def add_occurrence(out, ent, tr, symbol)
        cfg = Store.config(ent) || {}
        role = (Store.get(ent, 'role') || cfg['role']).to_s
        b = ent.definition.bounds
        lo = [Units.to_mm(b.min.x), Units.to_mm(b.min.y), Units.to_mm(b.min.z)]
        hi = [Units.to_mm(b.max.x), Units.to_mm(b.max.y), Units.to_mm(b.max.z)]
        box = [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]]
        prod = { 'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'] }
        ax = PartFaces.axes_for_snapshot(role, box, prod)
        return if ax.nil? # neoveritelne osi = radsej nic (D-88)

        shape = symbol_mm(lo, hi, ax, symbol, OUT_MM)
        return if shape['lines'].empty?

        occ = { 'part' => entity_id(ent), 'symbol' => symbol, 'lines' => [], 'text' => nil }
        shape['lines'].each do |a, z|
          occ['lines'] << Units.point(a[0], a[1], a[2]).transform(tr)
          occ['lines'] << Units.point(z[0], z[1], z[2]).transform(tr)
        end
        t = shape['text']
        occ['text'] = Units.point(t[0], t[1], t[2]).transform(tr) if t
        out['occurrences'] << occ
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.add_occurrence')
      end

      # ================= PAYLOAD PRE KRESLENIE + CISLA =========================
      # Z hotovej scan cache spravi TRI ploche polia bodov (GL_LINES) a
      # deterministicke pocty. Bezi pri zmene cache, NIKDY per frame.
      #   'move'  — prerusovane, COLOR: sipky a ∧/∨ (co sa hybe)
      #   'fixed' — plne, COLOR: X blendy (co sa NEhybe)
      #   'ask'   — prerusovane, COLOR_UNSET: kruhy „neurcene"
      def view_payload
        return @payload if @payload

        cache = @cache
        return nil if cache.nil?

        pts = { 'move' => [], 'fixed' => [], 'ask' => [] }
        texts = []
        wings = 0
        unknown = 0
        Array(cache['occurrences']).each do |occ|
          sym = occ['symbol'].to_s
          bucket = sym == SYM_CROSS ? 'fixed' : (sym == SYM_UNKNOWN ? 'ask' : 'move')
          pts[bucket].concat(Array(occ['lines']))
          texts << occ['text'] if occ['text']
          wings += 1 if WING_SYMBOLS.include?(sym)
          unknown += 1 if sym == SYM_UNKNOWN
        end
        @payload = { 'move' => pts['move'], 'fixed' => pts['fixed'], 'ask' => pts['ask'],
                     'texts' => texts, 'wings' => wings, 'unknown' => unknown,
                     'marks' => Array(cache['occurrences']).length,
                     'legacy' => cache['legacy'].to_i }
      end

      # ================= ZIVOTNY CYKLUS OVERLAYU ===============================

      # Overlay API zije od SU 2023; starsi SketchUp funkciu jednoducho nema.
      def available?(model = nil)
        return false unless defined?(DirectionOverlay)

        m = model || active_model
        !m.nil? && m.respond_to?(:overlays)
      rescue StandardError
        false
      end

      # ZAPNUTE = mame overlay, patri TOMUTO modelu, je v nom zaregistrovany a
      # nie je NATIVNE vypnuty v paneli Overlays (Utilities).
      def active?(model = nil)
        m = model || active_model
        return false if @overlay.nil?
        return false unless same_model?(@model, m)

        overlay_live?(m)
      end

      def overlay_live?(model)
        return false if @overlay.nil?
        return false unless registered?(model)

        !@overlay.respond_to?(:enabled?) || @overlay.enabled? == true
      rescue StandardError
        false
      end

      def registered?(model)
        return true unless model.respond_to?(:overlays)

        model.overlays.to_a.include?(@overlay)
      rescue StandardError
        true
      end

      # Identita dokumentu pre overlay lifecycle — TVAR AJ DOVODY su spolocne
      # s `EdgeCheck.same_model?` / `GrainCheck.same_model?` (tam je plne
      # zdovodnenie): `equal?` ma prednost, zaloha vyzaduje ZHODNY guid A
      # ZHODNU cestu (dve otvorene KOPIE tej istej zakazky maju rovnaky guid).
      def same_model?(a, b)
        return false if a.nil? || b.nil?
        return true if a.equal?(b)

        ga = a.respond_to?(:guid) ? a.guid.to_s : ''
        gb = b.respond_to?(:guid) ? b.guid.to_s : ''
        return false if ga.empty? || ga != gb

        pa = a.respond_to?(:path) ? a.path.to_s : ''
        pb = b.respond_to?(:path) ? b.path.to_s : ''
        pa == pb
      rescue StandardError
        false
      end

      # Prepnutie + ZAPAMATANIE. Zapisuje sa VYSLEDNY stav (ked zapnutie zlyha,
      # nezapamata sa „zapnute").
      def toggle(model)
        active?(model) ? disable! : enable!(model)
        st = ui_state(model)
        remember!(st['active'] == true)
        st
      end

      # ZAPNUTIE. Odstraneny Sketchup::Overlay je navzdy neplatny a NESMIE sa
      # pridat druhykrat (lekcia D-104) — pri kazdom zapnuti sa tvori NOVA
      # instancia a stara sa zahadzuje.
      def enable!(model)
        return ui_state(model) unless available?(model)

        disable! if @overlay
        drop_registered(model)
        ov = DirectionOverlay.new
        unless model.overlays.add(ov)
          Engine.log('KOV-A2b: overlay smeru otvarania sa nepodarilo zaregistrovat (uz je pridany?)')
          return ui_state(model)
        end
        @overlay = ov
        @model = model
        begin
          ov.enabled = true if ov.respond_to?(:enabled=)
        rescue StandardError => e
          Engine.log_error(e, 'DirectionCheck.enable! overlay.enabled=')
        end
        attach_observer(model)
        refresh!(model)
        ui_state(model)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.enable!')
        ui_state(model)
      end

      def disable!
        m = @model
        ov = @overlay
        @overlay = nil
        @model = nil
        @cache = nil
        @payload = nil
        @dirty = false
        detach_observer(m)
        remove_overlay(m, ov)
        invalidate(m)
        ui_state(m)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.disable!')
        ui_state(nil)
      end

      # Obnovenie zapamataneho stavu pri otvoreni Studia. Prepinac je vec
      # POCITACA — zakazka o nom nevie. Zapamatany stav sa NEPREPISUJE (nie je
      # to pouzivatelov klik), takze zlyhanie obnovy nastavenie nezrusi.
      def restore!(model)
        return ui_state(model) unless remembered?
        return ui_state(model) if active?(model) || !available?(model)

        enable!(model)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.restore!')
        ui_state(model)
      end

      # Prepnutie/otvorenie ineho dokumentu: overlay patril STAREMU modelu,
      # takze sa vypina — ale zapamatany prepinac ostava (patri pocitacu).
      def on_model_changed(model)
        return if @overlay.nil?
        return if !model.nil? && same_model?(@model, model)

        disable!
        notify_state_changed
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.on_model_changed')
      end

      # Stav dostanu VSETKY okna, ktore prepinac zobrazuju — Studio aj rail
      # Inspectora (jeden zdroj stavu, dva vstupne body).
      def notify_state_changed
        Engine.broadcast_direction_check(ui_state(active_model))
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.notify_state_changed')
      end

      def remove_overlay(model, overlay)
        return unless overlay && model && model.respond_to?(:overlays)

        model.overlays.remove(overlay)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.remove_overlay')
      end

      # Poistka po reloade pluginu: overlay s NASIM id uz moze byt v modeli
      # zaregistrovany (stara instancia z predosleho behu) — `add` by zlyhal.
      def drop_registered(model)
        return unless model.respond_to?(:overlays)

        model.overlays.to_a.each do |o|
          next unless o.respond_to?(:overlay_id) && o.overlay_id.to_s == OVERLAY_ID

          model.overlays.remove(o)
        end
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.drop_registered')
      end

      # ================= CACHE + INVALIDACIA ===================================

      def refresh!(model = nil)
        m = model || @model
        return if m.nil?

        @cache = scan(m)
        @payload = nil
        @dirty = false
        @cache
      end

      # Volane z ModelObservera (commit/undo/redo/abort) — PRESTAVBA skrinky
      # zmeni smer aj geometriu ciel. V observeri sa NIC neskenuje ani nemeni;
      # len sa oznaci cache za staru a poziada sa o prekreslenie, samotny
      # prepocet bezi az v `draw`.
      def mark_dirty(model)
        return unless @overlay && same_model?(@model, model)

        @dirty = true
        @payload = nil
        request_redraw(model)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.mark_dirty')
      end

      # Samotny „dirty" flag prekreslenie NEZARUCUJE (nehybny pohlad draw
      # nevola) — vyziada sa explicitne, ale az PO observer callbacku (timer 0).
      def request_redraw(model)
        return if @redraw_pending

        @redraw_pending = true
        UI.start_timer(0, false) do
          begin
            @redraw_pending = false
            invalidate(model) if @overlay && same_model?(@model, model)
          rescue StandardError => e
            Engine.log_error(e, 'DirectionCheck.request_redraw')
          end
        end
      end

      def invalidate(model)
        return unless model && model.respond_to?(:active_view) && model.active_view

        model.active_view.invalidate
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.invalidate')
      end

      def attach_observer(model)
        return unless defined?(DirectionModelWatch)

        @observer ||= DirectionModelWatch.new
        begin
          model.remove_observer(@observer)
        rescue StandardError
          nil
        end
        model.add_observer(@observer)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.attach_observer')
      end

      def detach_observer(model)
        return unless model && @observer

        model.remove_observer(@observer)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.detach_observer')
      end

      # ================= KRESLENIE =============================================

      # Vola ju Overlay#draw. Prepocet je LAZY (len ked je cache stara) — nikdy
      # per frame; body su hotove vo `view_payload`.
      def draw(view)
        model = view.respond_to?(:model) ? view.model : nil
        if @cache.nil? || @dirty
          refresh!(model || @model)
          notify_count_changed
        end
        payload = view_payload
        return if payload.nil?

        view.line_width = LINE_WIDTH
        draw_group(view, payload['move'], COLOR, '-')
        draw_group(view, payload['fixed'], COLOR, '')
        draw_group(view, payload['ask'], COLOR_UNSET, '-')
        draw_texts(view, payload['texts'])
        reset_pen(view)
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.draw')
        nil
      end

      def draw_group(view, pts, color, stipple)
        return if pts.nil? || pts.empty?

        view.line_stipple = stipple
        view.drawing_color = Sketchup::Color.new(*color)
        view.draw(GL_LINES, pts)
      end

      # Otaznik v strede „neurceneho" cela. `draw_text` chce SCREEN suradnice —
      # bod za kamerou sa preskoci (screen_coords by dal nezmysel).
      def draw_texts(view, pts)
        return if pts.nil? || pts.empty?

        opts = { size: TEXT_SIZE, bold: true, align: TextAlignCenter,
                 color: Sketchup::Color.new(*COLOR_UNSET) }
        pts.each do |p|
          sp = view.screen_coords(p)
          next if sp.nil?

          view.draw_text(sp, TEXT_UNKNOWN, opts)
        end
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.draw_texts')
      end

      # Pero sa vracia do vychodzieho stavu — prerusovanie je stav VIEW a bez
      # tohto by prerusovane kreslili aj prekrytia za nami (kontrola hran).
      def reset_pen(view)
        view.line_stipple = ''
        view.line_width = 1
      rescue StandardError
        nil
      end

      # Obal kresby — bez neho SketchUp kresbu mimo obalu modelu oreze (symboly
      # su posunute 0,7 mm von). Vzor D-104 BLOCKER 4.
      def extents(model = nil)
        bb = Geom::BoundingBox.new
        m = model || @model
        bb.add(m.bounds) if m && m.respond_to?(:bounds)
        Array(@cache ? @cache['occurrences'] : []).each do |occ|
          Array(occ['lines']).each { |p| bb.add(p) }
        end
        bb
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.extents')
        Geom::BoundingBox.new
      end

      # ================= STAV PRE OKNO =========================================

      # Tvar pre listu sekcie Kontrola v Studiu a pre rail Inspectora. Cisla su
      # VYHRADNE zo servera (JS si nic neprepocitava) a nesmu byt stare — pri
      # oznacenej cache sa prepocitaju TU.
      def ui_state(model = nil)
        m = model || active_model
        on = active?(m)
        refresh!(m) if on && (@cache.nil? || @dirty)
        p = on ? view_payload : nil
        { 'available' => available?(m), 'active' => on,
          'wings' => p ? p['wings'] : nil,
          'unknown' => p ? p['unknown'] : nil,
          'legacy' => p ? p['legacy'] : nil,
          'marks' => p ? p['marks'] : nil }
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.ui_state')
        { 'available' => false, 'active' => false }
      end

      # Po prepocte (draw po prestavbe): obe okna dostanu cerstve cisla.
      # Burst eventov sa zluci do JEDNEHO pushu (timer + pending guard).
      def notify_count_changed
        return if @notify_pending

        @notify_pending = true
        UI.start_timer(0, false) do
          begin
            @notify_pending = false
            Engine.broadcast_direction_check
          rescue StandardError => e
            Engine.log_error(e, 'DirectionCheck.notify_count_changed')
          end
        end
      rescue StandardError => e
        Engine.log_error(e, 'DirectionCheck.notify_count_changed')
      end

      def active_model
        defined?(Sketchup) ? Sketchup.active_model : nil
      rescue StandardError
        nil
      end
    end
  end
end
