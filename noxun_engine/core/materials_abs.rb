# frozen_string_literal: true
# Noxun Engine — materialovy katalog: ABS podla dekoru (deterministicky picker
# abs_for_decor, kandidati/vyber varianty, remap pri zmene dekoru). Cast modulu
# Materials (mechanicky split materials.rb, V0.5.1) — pozri materials.rb pre prehlad.
#
# 2A-3 (standard 7.5): pri katalogu SCHEMA 2 vyberaju VSETCI volajuci cez nove
# jadro abs_for_sheet (skupina -> presna NEPRAZDNA struktura -> universal ->
# nic + strojovy reason). Legacy abs_for_decor/edge_candidates/pick_edge_variant
# OSTAVAJU NEZMENENE a pouzivaju sa VYHRADNE pri SCHEMA 1 (dual-mode).

module Noxun
  module Engine
    module Materials
      # --- 2A-3 (audit N17): strojove reasons vyberu ABS -----------------------
      # Konstanty, nie volne texty — putuju ako warning['code'] cez config ->
      # Bom.collect -> Validation.run (ORANGE). Caller doplna part_key/rolu/hranu.
      REASON_ABS_STRUCTURE = 'abs_structure_missing' # skupina nema pasku struktury dosky ani universal
      REASON_ABS_NOMINAL   = 'abs_nominal_missing'   # kandidati su, ale ziadny v ziadanej triede hrubky
      REASON_ABS_WIDTH     = 'abs_width_missing'     # trieda je, ale ziadna paska nema pouzitelnu sirku
      REASON_ABS_15        = 'abs_15_fallback'       # dvojka rozriesena na 1,5 mm (viditelne upozornenie)
      # Remap kontrakt 0,4 (rozhodnute 30.7.): stara 0,4 sa NIKDY automaticky
      # nenahradza — hrana ide do lost s tymto reasonom, pouzivatel vybera vedome.
      REASON_ABS_04_MANUAL = 'abs_04_manual'

      # Nominalne triedy (standard 7.5): pravidla roli ziadaju TRIEDU, resolver
      # ju preklada na dostupne pasky skupiny v tomto poradi preferencie.
      EDGE_CLASS_PREFERENCE = {
        jednotka: [0.8, 1.0, 1.2].freeze,
        dvojka:   [2.0, 1.5].freeze
      }.freeze

      module_function

      # --- 2A-3: nominalne triedy + resolver obchodnej hrubky (standard 7.5) --

      # Trieda obchodnej hrubky: 0,4 -> :nula4; 0,8/1/1,2 -> :jednotka;
      # 1,5/2 -> :dvojka; ine -> nil. :nula4 sa NIKDY nevoli automaticky.
      def edge_thickness_class(th)
        v = th.to_f
        return :nula4 if (v - 0.4).abs < 0.01
        return :jednotka if [0.8, 1.0, 1.2].any? { |t| (t - v).abs < 0.01 }
        return :dvojka if [1.5, 2.0].any? { |t| (t - v).abs < 0.01 }
        nil
      end

      # Resolver obchodnej hrubky (standard 7.5): z kandidatov (UZ zuzenych na
      # skupinu + strukturnu vetvu — hierarchiu drzi abs_for_sheet) vyberie pasku
      # ziadanej NOMINALNEJ triedy. Poradie: najprv trieda hrubky (jednotka
      # 0,8 -> 1 -> 1,2; dvojka 2 -> 1,5), az potom sirka (pick_edge_variant —
      # najmensia >= hrubka+2 -> bez sirky -> nic; NIKDY uzsia). Hrubka, ktorej
      # ziadna paska sirkovo nevyhovuje, NEBLOKUJE dalsiu preferenciu.
      # Vrati [rec|nil, reason|nil]; reason moze sprevadzat aj USPECH
      # (REASON_ABS_15 pri dvojke rozriesenej na 1,5). 0,4 sa nevolia NIKDY
      # (trieda :nula4 nema preferencie — [nil, REASON_ABS_NOMINAL]).
      def resolve_edge_thickness(cands, nominal, part_thickness = nil)
        prefs = EDGE_CLASS_PREFERENCE[nominal.to_s.to_sym]
        return [nil, REASON_ABS_NOMINAL] if prefs.nil? || !cands.is_a?(Array)
        found_class = false
        prefs.each do |th|
          sub = cands.select { |a| (a['thickness'].to_f - th).abs < 0.01 }
          next if sub.empty?
          found_class = true
          rec = pick_edge_variant(sub, part_thickness)
          next if rec.nil?
          reason = nominal.to_s.to_sym == :dvojka && (th - 1.5).abs < 0.01 ? REASON_ABS_15 : nil
          return [rec, reason]
        end
        [nil, found_class ? REASON_ABS_WIDTH : REASON_ABS_NOMINAL]
      end

      # --- 2A-3 (audit B3): picker SCHEMA 2 — hierarchia NEMENNA ---------------
      # 1. kandidati = pasky s ROVNAKYM group_id ako sheet_rec,
      # 2. vetva A: presna zhoda NEPRAZDNEJ normalizovanej struktury (identity_norm;
      #    dve prazdne NIKDY nie su zhoda — prazdna = neznama, nie "rovnaka"),
      # 3. vnutri vetvy: resolver triedy + sirkovy vyber (poradie: trieda, sirka),
      # 4. vetva B: pasky s explicitnym universal:true (universalnost STRUKTURY,
      #    nie sirky — sirkova kontrola plati aj tu; rovnaky resolver),
      # 5. nic -> [nil, strojovy reason].
      # Vrati [abs_id|nil, reason|nil] — reason aj pri uspechu (abs_15_fallback).
      def abs_for_sheet(sheet_rec, nominal, part_thickness = nil)
        return [nil, REASON_ABS_STRUCTURE] unless sheet_rec.is_a?(Hash)
        cands = edges_of_group(sheet_rec)
        st = identity_norm(sheet_rec['structure'])
        exact = st.empty? ? [] : cands.select { |a| identity_norm(a['structure']) == st }
        rec, reason = resolve_edge_thickness(exact, nominal, part_thickness)
        return [rec['abs_id'], reason] if rec
        reason_a = exact.empty? ? nil : reason
        universal = cands.select { |a| a['universal'] == true }
        rec_b, reason_b = resolve_edge_thickness(universal, nominal, part_thickness)
        return [rec_b['abs_id'], reason_b] if rec_b
        return [nil, REASON_ABS_STRUCTURE] if exact.empty? && universal.empty?
        return [nil, REASON_ABS_WIDTH] if [reason_a, reason_b].include?(REASON_ABS_WIDTH)
        [nil, REASON_ABS_NOMINAL]
      end

      # Pasky rovnakej skupiny ako dany zaznam (SCHEMA 2 kluc: group_id, fallback
      # obchodna identita vyrobca+dekor), deterministicky zoradene abs_id.
      def edges_of_group(rec)
        want = record_group_key(rec, SCHEMA_GROUPS)
        edges.select { |a| record_group_key(a, SCHEMA_GROUPS) == want }
             .sort_by { |a| a['abs_id'].to_s }
      end

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
