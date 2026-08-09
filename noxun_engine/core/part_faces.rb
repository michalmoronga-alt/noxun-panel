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

      AXIS_KEYS = %i[length width thickness].freeze

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

      # Kod hrany pre STRED plochy (mm suradnice v lokalnych osiach dielca) alebo nil
      # (velka dekorova plocha / plocha mimo obalu). `box` je [sx, sy, sz] v mm.
      def edge_code_for_center(center_mm, box, ax)
        return nil unless center_mm.is_a?(Array) && center_mm.length == 3 && ax
        axis, side = axis_side(center_mm, box)
        return nil if axis.nil? || axis == ax[:thickness]
        return side == :min ? 'L1' : 'L2' if axis == ax[:width]
        return side == :min ? 'W1' : 'W2' if axis == ax[:length]
        nil
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
