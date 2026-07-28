# frozen_string_literal: true
# Noxun Engine — materialovy katalog: ABS podla dekoru (deterministicky picker
# abs_for_decor, kandidati/vyber varianty, remap pri zmene dekoru). Cast modulu
# Materials (mechanicky split materials.rb, V0.5.1) — pozri materials.rb pre prehlad.

module Noxun
  module Engine
    module Materials
      module_function

      # --- ABS podla dekoru (pravidlove defaulty, standard 7.5) ----------------

      # Najde ABS variant daneho dekoru a hrubky ABS (mm), volitelne pre cielovu
      # hrubku dielca (vyber sirky pasky). Vrati abs_id alebo nil.
      # D-41: deterministicky picker (audit BLOCKER 2 — NIKDY uzsia paska):
      #   s hrubkou dielca: najmensia sirka >= hrubka+WIDTH_MARGIN -> legacy bez
      #     sirky (univerzalna) -> nil (ziadna vyhovujuca; volajuci ohlasi).
      #   bez hrubky (defenzivny fallback): legacy bez sirky -> najsirsia
      #     (siroku mozno orezat, uzka nepokryje).
      # Tie-break vzdy abs_id vzostupne (audit FIX 11 — stabilne poradie nezavisle
      # od poradia zaznamov v subore).
      def abs_for_decor(decor, thickness, part_thickness = nil)
        rec = pick_edge_variant(edge_candidates(decor, thickness), part_thickness)
        rec && rec['abs_id']
      end

      # Kandidati: pasky presne zhodneho dekoru a hrubky ABS, zoradene abs_id.
      def edge_candidates(decor, thickness)
        return [] if decor.nil?
        th = thickness.to_f
        edges.select { |a| a['decor'] == decor && (a['thickness'].to_f - th).abs < 0.01 }
             .sort_by { |a| a['abs_id'].to_s }
      end

      # Cisty vyber varianty z kandidatov (testovatelne bez katalogu).
      def pick_edge_variant(cands, part_thickness = nil)
        return nil if cands.empty?
        widthless = cands.select { |a| edge_width(a).nil? }
        widthed   = cands.reject { |a| edge_width(a).nil? }
        if part_thickness
          need = part_thickness.to_f + WIDTH_MARGIN
          fit = widthed.select { |a| edge_width(a) >= need - 0.001 }
                       .min_by { |a| [edge_width(a), a['abs_id'].to_s] }
          fit || widthless.first
        else
          widthless.first || widthed.max_by { |a| [edge_width(a), a['abs_id'].to_s] }
        end
      end

      # D-41 PR C (audit FIX 5): JEDNO jadro preladenia mapy hran {code=>abs_id|nil}
      # zo stareho dekoru na novy — pouzivaju ho doska AJ dielcove overridy.
      # Meni LEN pasky presne zhodne so starym dekorom; cudzi dekor = vedoma
      # kontrastna volba a nil = vedome "bez ABS" — tie sa NIKDY nedotknu.
      # target_thickness = cielova hrubka dielca (vyber sirky novej pasky).
      # Vrati [nova_mapa alebo nil (nic na prevod), pole hran bez nahrady].
      def remap_edges(edges_hash, old_decor, new_decor, target_thickness = nil)
        return [nil, []] unless edges_hash.is_a?(Hash) && old_decor && new_decor && old_decor != new_decor
        out = edges_hash.dup
        changed = false
        lost = []
        out.each_key do |code|
          aid = out[code]
          next if aid.nil?
          rec = edge(aid)
          next unless rec && rec['decor'] == old_decor
          new_aid = abs_for_decor(new_decor, rec['thickness'], target_thickness)
          lost << code if new_aid.nil?
          out[code] = new_aid
          changed = true
        end
        [changed ? out : nil, lost]
      end

      # Dekor doskoveho materialu (pre napojenie ABS na rovnaky dekor). nil ak material nie je v katalogu.
      def decor_of(material_id)
        s = sheet(material_id)
        s && s['decor']
      end
    end
  end
end
