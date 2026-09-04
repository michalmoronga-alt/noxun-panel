# frozen_string_literal: true
# Noxun Engine — NASTROJE-1: CISTE jadro nastroja Snaper (prisunutie na doraz).
#
# AABB sweep v LOKALNOM rame ciela: prekazky sa odovzdaju uz prepocitane, takze
# tu nie je ziadne `Sketchup::*` ani `UI::*` a sada bezi headless.
# Vsetko v mm Float (standard §1).
#
# Vstupny tvar:
#   box  = { min: [x, y, z], max: [x, y, z] }            (mm, lokalny ram ciela)
#   node = { box: box, container: true/false,
#            children: [node, …] alebo Proc -> [node, …] }
# `children` ako Proc drzi traverzu LENIVOU — do kontajnera sa zostupuje az
# vtedy, ked jeho obalka naozaj presahuje veduci okraj ciela.
module Noxun
  module Engine
    module Tools
      module SnapCalc
        MAX_DEPTH = 8          # hlbka zanorenia kontajnerov (importovane izby)
        EPS_MM = 0.5           # tolerancia „lezi uz za veducim okrajom"
        OVERLAP_EPS_MM = 0.01  # DOTYK nie je prekryv (podlaha nesmie blokovat)
        TOUCH_MM = 0.2         # blizsie = uz na doraz, nehybeme
        WARN_MM  = 10_000.0    # dalej = presun ano, ale s varovanim
        BLOCK_MM = 20_000.0    # dalej (alebo nic v smere) = odmietnutie

        module_function

        # Volna vzdialenost (mm) od veduceho okraja ciela k najblizsej prekazke
        # v smere `dir` (:left = -X, :right = +X), alebo `nil` ked v smere nic nie je.
        def nearest_gap(target_box, nodes, dir)
          t = norm_box(target_box)
          return nil if t.nil?

          best = [nil]
          walk(nodes, t, dir.to_sym, 0, best)
          best[0]
        end

        # Prechod jednej urovne. Prekazka sa pocita LEN ked sa jej rozsah kryje
        # s cielom v hlbke (Y) aj vo vyske (Z) — obycajny dotyk nie je prekryv,
        # takze podlaha ani uz prisunuty sused bocny posun neblokuju.
        def walk(nodes, target, dir, depth, best)
          Array(nodes).each do |node|
            next if node.nil?

            box = norm_box(fetch(node, :box))
            next if box.nil?
            next unless overlap_1d(box[:min][1], box[:max][1], target[:min][1], target[:max][1])
            next unless overlap_1d(box[:min][2], box[:max][2], target[:min][2], target[:max][2])

            gap = leading_gap(box, target, dir)
            if gap >= -EPS_MM
              gap = 0.0 if gap.negative?
              best[0] = gap if best[0].nil? || gap < best[0]
              next
            end

            # Obalka kontajnera cielom PRECHADZA (importovana izba obklopuje
            # skrinku) — pouzitelnu medzeru vedia dat az jeho vnutorne steny.
            next unless truthy(fetch(node, :container)) && depth < MAX_DEPTH
            next unless ahead?(box, target, dir)

            walk(children_of(node), target, dir, depth + 1, best)
          end
          best[0]
        end

        # Vzdialenost od veduceho okraja ciela k najblizsiemu okraju prekazky.
        # Zaporna hodnota = prekazka veduci okraj presahuje (prekryva sa v X).
        def leading_gap(box, target, dir)
          dir.to_sym == :right ? box[:min][0] - target[:max][0] : target[:min][0] - box[:max][0]
        end

        # Lezi aspon cast obalky ZA veducim okrajom ciela? (podmienka zostupu)
        def ahead?(box, target, dir)
          if dir.to_sym == :right
            box[:max][0] > target[:max][0] + EPS_MM
          else
            box[:min][0] < target[:min][0] - EPS_MM
          end
        end

        def overlap_1d(a1, a2, b1, b2, eps = OVERLAP_EPS_MM)
          amin, amax = [a1.to_f, a2.to_f].minmax
          bmin, bmax = [b1.to_f, b2.to_f].minmax
          (amax - bmin) > eps && (bmax - amin) > eps
        end

        # Verdikt pre pouzivatela. `gap_mm` je vysledok sweepu, `dist_mm` skutocna
        # SVETOVA vzdialenost posunu (pri skalovanej cudzej instancii sa lisia).
        #   :none     — v smere nie je ziadna prekazka (presun sa zablokuje)
        #   :touching — uz na doraz, nehybeme
        #   :too_far  — dalej nez BLOCK_MM (presun sa zablokuje)
        #   :far      — dalej nez WARN_MM (presun ano, s varovanim)
        #   :ok       — bezny presun
        def verdict(gap_mm, dist_mm = nil)
          return :none if gap_mm.nil?

          d = (dist_mm || gap_mm).to_f.abs
          return :touching if d <= TOUCH_MM
          return :too_far if d > BLOCK_MM
          return :far if d > WARN_MM

          :ok
        end

        # --- pomocne (tvar vstupu) -------------------------------------------

        def fetch(hash, key)
          return nil unless hash.is_a?(Hash)

          hash.key?(key) ? hash[key] : hash[key.to_s]
        end

        def children_of(node)
          kids = fetch(node, :children)
          kids = kids.call if kids.respond_to?(:call)
          Array(kids)
        end

        def truthy(value)
          !value.nil? && value != false
        end

        def norm_box(box)
          lo = fetch(box, :min)
          hi = fetch(box, :max)
          return nil unless lo.is_a?(Array) && hi.is_a?(Array) && lo.length >= 3 && hi.length >= 3

          { min: lo.first(3).map(&:to_f), max: hi.first(3).map(&:to_f) }
        end
      end
    end
  end
end
