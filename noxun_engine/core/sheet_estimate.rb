# frozen_string_literal: true
# Noxun Engine — D-19: orientacny prepocet poctu platni per material.
#
# NIE narezovy plan — hruby ROZSAH (koeficient prerezu 10-25 %, Michal 20.7.).
# Vstupom su VZDY jednotlive BOM riadky (rozmery, pocty, material) — nie sucty:
# stabilna hranica pre buducu fazu 2 (guillotine nesting s kerf/orezkami/dekorom)
# vymeni len vnutro vypoctu, kontrakt estimate() a UI ostanu (Codex audit D19 B1).
# Format platne per material zije v katalogu (sheet_size); chybajuci/poskodeny
# format = fallback 2800x2070 + priznak (estimator NIKDY nedeli nulou — F4).
module Noxun
  module Engine
    module SheetEstimate
      DEFAULT_SHEET = [2800.0, 2070.0].freeze
      K_MIN = 1.10 # prerez optimisticky (+10 %)
      K_MAX = 1.25 # prerez pesimisticky (+25 %)

      module_function

      # rows: Bom.compute[:rows] (staci length/width/quantity/material_id;
      # volitelne material_source = duplak vazba zo snapshotu, D-43).
      # sheet_sizes: {material_id => [dlzka, sirka] mm} zo snapshotu katalogu.
      # Vrati pole per NAKUPNY material (sorted podla material_id — poradie
      # vstupu nehra rolu, kontraktovy test N10): {material_id, m2, quantity,
      # sheet_size, sheet_m2, count_min, count_max, fallback} + pri duplak
      # prispevkoch doubled_m2/doubled_quantity.
      #
      # 2B-1 KONTRAKT duplaku (audit NOTE 13 — na tejto sematike stoji montazna
      # kalkulacia davky E): riadok s material_source sa NIKDY neobjavi ako
      # vlastna platna — jeho plocha x multiplier sa pripocita ZDROJOVEMU
      # material_id (kupuje sa zdroj). Na zdrojovom riadku:
      #   m2               = celkova KUPOVANA plocha (vlastne dielce + duplaky x mult)
      #   quantity         = pocet KUSOV len vlastnych dielcov (duplak kusy NIE)
      #   doubled_m2       = cast m2 pridana duplakmi (uz po x mult)
      #   doubled_quantity = pocet kusov duplak dielcov (informativny)
      # count_min/max sa pocitaju z celkoveho m2 (nakup zdrojovych platni).
      # V0.6 M-B1 (audit F7): uni_ids = mapa material_id => true pre UNI
      # zaznamy — ich pocet platni je len ORIENTACNY (format je pracovny
      # default) a vystup to nesie ('uni' => true), UI ho tak aj oznaci.
      def estimate(rows, sheet_sizes: {}, k_min: K_MIN, k_max: K_MAX, uni_ids: {})
        kmin, kmax = valid_coeffs(k_min, k_max)
        per = {}
        Array(rows).each do |r|
          mid = r['material_id'].to_s
          next if mid.empty?
          area = r['length'].to_f * r['width'].to_f * r['quantity'].to_i / 1_000_000.0
          next if area <= 0
          ms = r['material_source']
          if ms.is_a?(Hash) && !ms['material_id'].to_s.empty? && ms['multiplier'].to_i >= 2
            src = ms['material_id'].to_s
            g = per[src] ||= { 'm2' => 0.0, 'quantity' => 0, 'doubled_m2' => 0.0, 'doubled_quantity' => 0 }
            add = area * ms['multiplier'].to_i
            g['m2'] += add
            g['doubled_m2'] = g.fetch('doubled_m2', 0.0) + add
            g['doubled_quantity'] = g.fetch('doubled_quantity', 0) + r['quantity'].to_i
          else
            g = per[mid] ||= { 'm2' => 0.0, 'quantity' => 0 }
            g['m2'] += area
            g['quantity'] += r['quantity'].to_i
          end
        end
        per.map do |mid, g|
          size, fallback = sheet_size_for(sheet_sizes[mid])
          sheet_m2 = size[0] * size[1] / 1_000_000.0
          out = {
            'material_id' => mid, 'm2' => g['m2'].round(3), 'quantity' => g['quantity'],
            'sheet_size' => size, 'sheet_m2' => sheet_m2.round(3),
            'count_min' => ceil_tenth(g['m2'] * kmin / sheet_m2),
            'count_max' => ceil_tenth(g['m2'] * kmax / sheet_m2),
            'fallback' => fallback
          }
          if g['doubled_m2'].to_f.positive?
            out['doubled_m2'] = g['doubled_m2'].round(3)
            out['doubled_quantity'] = g['doubled_quantity'].to_i
          end
          out['uni'] = true if uni_ids.is_a?(Hash) && uni_ids[mid]
          out
        end.sort_by { |g| g['material_id'] }
      end

      # Ceil na desatinu BEZ float driftu (audit F6): matematicky presna hranica
      # 4.5 nesmie cez 4.500000000000001 preskocit na 4.6 — pred ceil sa hodnota
      # zrovna na 6 desatinnych miest (dostatocne pod zrnom vysledku 0.1).
      def ceil_tenth(v)
        ((v.to_f * 10).round(6).ceil / 10.0)
      end

      # [platny_par, fallback?] — kazdy prvok musi byt konecne kladne cislo.
      def sheet_size_for(pair)
        if pair.is_a?(Array) && pair.length == 2
          l = pos_f(pair[0])
          w = pos_f(pair[1])
          return [[l, w], false] if l && w
        end
        [DEFAULT_SHEET.dup, true]
      end

      def pos_f(v)
        f = begin
          Float(v)
        rescue StandardError, TypeError
          nil
        end
        f && f.positive? && f.finite? ? f : nil
      end

      # Vlastne koeficienty musia byt konecne kladne a min <= max, inak defaulty
      # (obrateny rozsah by dal zmatocny vystup — audit F6).
      def valid_coeffs(kmin, kmax)
        a = pos_f(kmin)
        b = pos_f(kmax)
        return [K_MIN, K_MAX] if a.nil? || b.nil? || a > b
        [a, b]
      end
    end
  end
end
