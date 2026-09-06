# frozen_string_literal: true
# Noxun Engine — D-88: mapovanie ABS hrany (L1/L2/W1/W2) na BOCNU PLOCHU kvadra dielca.
#
# ============ KONTRAKT „HRANA -> PLOCHA KVADRA" (jedine miesto pravdy) ============
# Kluce hran ziju na VYROBNYCH rozmeroch (viz hlavicka core/abs_rules.rb):
#   L1/L2 = pozdlzne hrany — bezia v smere prod[:length]
#   W1/W2 = priecne  hrany — bezia v smere prod[:width]
# Geometria dielca je ale kvader `box: [sx, sy, sz]` v LOKALNYCH osiach a priradenie
# „ktora os je dlzka" sa lisi podla ROLY (celo: dlzka = VYSKA, bok: dlzka = vyska,
# polica: dlzka = sirka korpusu, vystuha upright vs flat sa lisia navzajom).
#
# Toto priradenie sa preto NEODVODZUJE z hodnot rozmerov (dva rovnake rozmery =
# nejednoznacne, napr. stvorcove celo) — je to EXPLICITNY udaj deskriptora:
#   `axes: { length: <index osi>, width: <index osi>, thickness: <index osi> }`
# kde index 0 = X, 1 = Y, 2 = Z v ramci `box`. Zapisuje ho ten, kto box stava
# (core/construction.rb, core/zone_tree.rb, modules/fronts.rb, core/board_builder.rb)
# — pouzitim pomenovanych konstant nizsie. PartFaces ich uz len CITA a overuje.
#
# Z osi vyplyva plocha jednoznacne (overene proti AbsRules::EDGE_LABELS pre kazdu rolu):
#   L1 = plocha na MINIME osi SIRKY      L2 = plocha na MAXIME osi SIRKY
#   W1 = plocha na MINIME osi DLZKY      W2 = plocha na MAXIME osi DLZKY
#   dve plochy kolme na os HRUBKY = velke dekorove plochy (ABS sa ich netyka)
# Kontrola (priklady): bok  axes L=Z,W=Y,T=X -> L1 na Y=0 = Predna, W1 na Z=0 = Dolna
#                      polica axes L=X,W=Y,T=Z -> L1 na Y=0 = Predna, W1 na X=0 = Lava
#                      celo  axes L=Z,W=X,T=Y -> L1 na X=0 = Lava,    W1 na Z=0 = Dolna
#                      chrbat axes L=X,W=Z,T=Y -> L1 na Z=0 = Dolna,  W1 na X=0 = Lava
#
# VYNIMKA — STOJACE DIELCE ZASUVKY (KOV-D5, Astra #20 F15): u rol
# `drawer_back`/`box_side`/`drawer_inner_front` je L1 podla ABS pravidla aj podla
# `AbsRules::EDGE_LABELS` HORNA dlha hrana (tam ide olep), kym default vyssie by
# ju polozil na MINIMUM osi sirky = spodok. Pre tieto roly (`STANDING_ROLES`)
# preto plati OTOCENA dvojica L1/L2 (`STANDING_EDGE_FACES`) — os sirky je u nich
# VYSKA dielca, takze L1 = jej maximum = horna plocha, L2 = dolna; W1/W2 ostavaju
# min/max osi dlzky. Recept ani ABS pravidla sa tym NEMENIA (L1 = 1,0 mm ostava)
# a mapa je JEDINA pre farbenie plosok (CabinetBuilder.paint_edge_faces) aj pre
# zvyraznenie Kontroly/hoveru (EdgeCheck, HoverEdge) — dve mapy by znamenali, ze
# sa zvyrazni ina hrana, nez sa zafarbi.
#
# BEZPECNOSTNY VENTIL: ked deskriptor osi nenesie, alebo ked osi NESEDIA s rozmermi
# (box[os] != prod[rozmer] nad toleranciu), mapovanie sa NEHADA — vrati sa nil a
# hrany sa jednoducho nezafarbia. Radsej ziadna farba nez farba na zlej hrane.
# =================================================================================
module Noxun
  module Engine
    module PartFaces
      TOL = 0.05 # mm — tolerancia zhody box <-> prod (prod je miestami round(2))

      # Pomenovane osi pre deskriptory. Index = poradie v `box` (0=X, 1=Y, 2=Z).
      # Zvisly panel: bok, zvisla priecka — dlzka je VYSKA (Z), sirka je HLBKA (Y).
      AXES_UPRIGHT = { length: 2, width: 1, thickness: 0 }.freeze
      # Lezaci panel: dno, vrch, polica, vodorovna priecka, vystuha naplocho, doska.
      AXES_LYING   = { length: 0, width: 1, thickness: 2 }.freeze
      # Celo pred korpusom — dlzka je VYSKA (Z), sirka je sirka kridla (X), hrubka Y.
      AXES_FRONT   = { length: 2, width: 0, thickness: 1 }.freeze
      # Zvisla stena v rovine XZ: chrbat, sokel, vystuha na hranu — sirka je VYSKA (Z).
      AXES_WALL    = { length: 0, width: 2, thickness: 1 }.freeze
      # KOV-D5: zvisla stena v rovine YZ — bok boxu zasuvky. Dlzka bezi po HLBKE
      # (Y = NL), sirka je VYSKA boxu (Z), hrubka X. Je to AXES_WALL otocena o 90
      # stupnov okolo Z; vlastna konstanta je nutna, lebo osi sa NIKDY nehadaju.
      AXES_WALL_DEPTH = { length: 1, width: 2, thickness: 0 }.freeze

      AXIS_KEYS = %i[length width thickness].freeze

      # ============ KOD HRANY -> [OS DESKRIPTORA, STRANA KVADRA] ==============
      # JEDINE miesto, kde sa rozhoduje, na ktorej stene kvadra hrana lezi.
      # Cita ho farbenie plosok (CabinetBuilder.paint_edge_faces) aj zvyraznenie
      # Kontroly a hoveru (EdgeCheck, HoverEdge) — cez `edge_code_for_center`
      # a `rect_axis_side`, nikdy vlastnou kopiou mapy.
      EDGE_FACES = { 'L1' => [:width, :min], 'L2' => [:width, :max],
                     'W1' => [:length, :min], 'W2' => [:length, :max] }.freeze
      # STOJACE dielce zasuvky: L1 je HORNA hrana (viz hlavicka) — otocena len
      # dvojica L1/L2, priecne hrany ostavaju.
      STANDING_EDGE_FACES = { 'L1' => [:width, :max], 'L2' => [:width, :min],
                              'W1' => [:length, :min], 'W2' => [:length, :max] }.freeze
      # Roly s otocenou dvojicou. JEDINY literalny zoznam v celom pluginu —
      # `AbsRules::STANDING_ROLES` (2D karta dielca) je jeho ALIAS, aby sa
      # zvyraznena a zafarbena hrana nemohli casom rozist.
      STANDING_ROLES = %w[drawer_back box_side drawer_inner_front].freeze

      module_function

      # Osi deskriptora ako {length:, width:, thickness:} s indexmi 0..2, alebo nil.
      # Prijima aj string kluce (deskriptor po JSON round-tripe).
      def axes(pd)
        raw = pd.is_a?(Hash) ? (pd[:axes] || pd['axes']) : nil
        return nil unless raw.is_a?(Hash)
        out = {}
        AXIS_KEYS.each do |k|
          v = raw[k].nil? ? raw[k.to_s] : raw[k]
          return nil unless v.is_a?(Integer) && v >= 0 && v <= 2
          out[k] = v
        end
        out.values.uniq.length == 3 ? out : nil
      end

      # Osi PLUS kontrola, ze sedia s rozmermi deskriptora (box vs prod). Nesedia =
      # deskriptor sa zmenil bez opravy osi -> nil (ziadne farbenie, ziadne hadanie).
      def verified_axes(pd)
        ax = axes(pd)
        return nil unless ax
        box = pd[:box] || pd['box']
        prod = pd[:prod] || pd['prod']
        return nil unless box.is_a?(Array) && box.length == 3 && prod.is_a?(Hash)
        AXIS_KEYS.each do |k|
          want = prod[k].nil? ? prod[k.to_s] : prod[k]
          return nil unless want.is_a?(Numeric)
          return nil if (box[ax[k]].to_f - want.to_f).abs > TOL
        end
        ax
      end

      # Mapa „kod hrany -> [os, strana]" pre rolu dielca. Rola smie chybat
      # (nil/''): vtedy plati default — stojace roly su vymenovane a chybajuca
      # rola nikdy nema byt jednou z nich.
      def edge_faces(role)
        STANDING_ROLES.include?(role.to_s) ? STANDING_EDGE_FACES : EDGE_FACES
      end

      # Kod hrany pre STRED plochy (mm suradnice v lokalnych osiach dielca) alebo nil
      # (velka dekorova plocha / plocha mimo obalu). `box` je [sx, sy, sz] v mm.
      # `role` rozhoduje o orientacii dvojice L1/L2 (stojace dielce zasuvky).
      def edge_code_for_center(center_mm, box, ax, role = nil)
        return nil unless center_mm.is_a?(Array) && center_mm.length == 3 && ax
        axis, side = axis_side(center_mm, box)
        return nil if axis.nil? || axis == ax[:thickness]
        edge_faces(role).each do |code, (key, want)|
          return code if axis == ax[key] && side == want
        end
        nil
      end

      # ================= D-104: OSI ZO SNAPSHOTU (vedoma legacy vynimka) =============
      # Kontrola olepov (D-104) bezi nad UZ POSTAVENOU zakazkou. Deskriptor s `axes:`
      # zije LEN v plane — na entite dielca ulozeny NIE JE (standard 8.3 sneha vyrobne
      # udaje, nie geometricke osi) a prestavat 254 dielcov len kvoli doplneniu osi je
      # neprijatelne. Preto sa osi pri CITANI odvodia z ROLY a OVERIA proti skutocnemu
      # kvadru.
      #
      # NIE JE to hadanie z rozmerov zakazane v hlavicke tohto suboru:
      #   1) kandidati su obmedzeni ROLOU (stvorcove celo ma jedineho kandidata),
      #   2) akceptuje sa VYHRADNE jednoznacna zhoda — nula alebo dve zhody vratia nil
      #      a dielec sa jednoducho nezvyrazni (rovnaka zasada „radsej ziadna farba").
      # Jediny realny dvojkandidat su vystuhy (flat = lezaci panel, upright = stena);
      # rozlisi ich kvader, a ked ma vystuha hlbku ROVNU hrubke, zhody su dve -> nil.
      ROLE_AXES = {
        'side_left' => [AXES_UPRIGHT], 'side_right' => [AXES_UPRIGHT], 'divider_v' => [AXES_UPRIGHT],
        'bottom' => [AXES_LYING], 'top' => [AXES_LYING], 'shelf' => [AXES_LYING],
        'divider_h' => [AXES_LYING], 'free_panel' => [AXES_LYING],
        # KOV-A1: flap (vyklop/sklop) a false_front (blenda) stoja v rovine ciel
        # s rovnakou matematikou ako zasuvkove celo -> ROVNAKE osi.
        'front_door' => [AXES_FRONT], 'drawer_front' => [AXES_FRONT],
        'flap' => [AXES_FRONT], 'false_front' => [AXES_FRONT],
        'back' => [AXES_WALL], 'plinth' => [AXES_WALL],
        'rail_front' => [AXES_LYING, AXES_WALL], 'rail_back' => [AXES_LYING, AXES_WALL],
        # KOV-D5: dielce zasuviek (recept ich stava v `Construction.drawer_part_descriptor`).
        # Kazda rola ma PRAVE JEDNEHO kandidata — dno lezi, chrbat a vnutorne celo
        # stoja v rovine XZ, bok boxu v rovine YZ (dlzka = NL po hlbke).
        'drawer_bottom' => [AXES_LYING], 'drawer_back' => [AXES_WALL],
        'drawer_inner_front' => [AXES_WALL], 'box_side' => [AXES_WALL_DEPTH]
      }.freeze

      # Osi dielca z jeho ROLY + rozmerov kvadra (mm) a vyrobnych udajov snapshotu.
      # box = [sx, sy, sz]; prod = {length:, width:, thickness:} (aj string kluce).
      def axes_for_snapshot(role, box, prod)
        cands = ROLE_AXES[role.to_s]
        return nil unless cands.is_a?(Array) && !cands.empty?
        return nil unless box.is_a?(Array) && box.length == 3 && prod.is_a?(Hash)
        hits = cands.select { |ax| axes_match?(ax, box, prod) }
        hits.length == 1 ? hits.first : nil
      end

      # Sedia osi s kvadrom? (rovnaka tolerancia ako verified_axes)
      def axes_match?(ax, box, prod)
        AXIS_KEYS.all? do |k|
          want = prod[k].nil? ? prod[k.to_s] : prod[k]
          next false unless want.is_a?(Numeric)
          (box[ax[k]].to_f - want.to_f).abs <= TOL
        end
      end

      # 4 rohy PLOSKY hrany v lokalnych mm (po obvode). lo/hi = protilahle rohy
      # kvadra dielca (obal definicie), `out` = posun VON z telesa proti
      # z-fightingu. Posuva sa v LOKALNYCH osiach — zrkadlena ci otocena
      # instancia si smer „von" zachova aj po transformacii (winding quadu sa na
      # to pouzit NEDA).
      def face_rect_mm(code, lo, hi, ax, out = 0.0, role = nil)
        axis, side = rect_axis_side(code, ax, role)
        return nil if axis.nil?
        return nil unless lo.is_a?(Array) && hi.is_a?(Array) && lo.length == 3 && hi.length == 3
        a, b = [0, 1, 2] - [axis]
        v = side == :min ? lo[axis].to_f - out : hi[axis].to_f + out
        [[lo[a], lo[b]], [hi[a], lo[b]], [hi[a], hi[b]], [lo[a], hi[b]]].map do |ca, cb|
          p = [0.0, 0.0, 0.0]
          p[axis] = v
          p[a] = ca.to_f
          p[b] = cb.to_f
          p
        end
      end

      # Kod hrany -> [index osi, :min|:max]. Zrkadlo edge_code_for_center (opacny
      # smer) — TA ISTA mapa, takze zvyraznena ploska sedi so zafarbenou.
      def rect_axis_side(code, ax, role = nil)
        return [nil, nil] unless ax.is_a?(Hash)
        key, side = edge_faces(role)[code.to_s]
        return [nil, nil] if key.nil?
        [ax[key], side]
      end

      # Na ktorej stene kvadra plocha lezi: [index osi, :min | :max] alebo nil.
      # Rozhoduje POLOHA stredu plochy, nie normala — plocha smie byt otocena.
      def axis_side(center_mm, box)
        (0..2).each do |i|
          c = center_mm[i].to_f
          size = box[i].to_f
          return [i, :min] if c.abs <= TOL
          return [i, :max] if (c - size).abs <= TOL
        end
        nil
      end
    end
  end
end
