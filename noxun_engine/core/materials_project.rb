# frozen_string_literal: true
# Noxun Engine — materialovy katalog: projektove defaulty (dedenie projekt-
# >korpus->dielec) v NOXUN dict na modeli + pouzitie dekorov v aktivnom
# projekte. Cast modulu Materials (mechanicky split materials.rb, V0.5.1) —
# pozri materials.rb pre prehlad.

module Noxun
  module Engine
    module Materials
      module_function

      # --- projektove defaulty (dedenie: koren; NOXUN dict na modeli) -----------

      # Vrati 3 projektove defaulty (default/front/back material_id). Chybajuce -> PROJECT_FALLBACK.
      def project_defaults(model)
        out = {}
        PROJECT_KEYS.each do |k|
          v = model_default(model, k)
          out[k] = (v.nil? || v.to_s.strip.empty?) ? PROJECT_FALLBACK[k] : v.to_s
        end
        out
      end

      def model_default(model, key)
        return nil unless model
        model.get_attribute(Store::DICT, key)
      rescue StandardError
        nil
      end

      # Nastavi jeden projektovy default na modeli (1 undo krok obali volajuci).
      def set_project_default(model, key, value)
        return false unless model && PROJECT_KEYS.include?(key.to_s)
        v = value.to_s.strip
        model.set_attribute(Store::DICT, key.to_s, v)
        true
      rescue StandardError => e
        Engine.log_error(e, 'Materials.set_project_default') if defined?(Engine)
        false
      end

      # D-42 PR B (audit FIX 12): dekory POUZITE v aktivnom modeli — jeden
      # read-only scan vyrobnych part/board snapshotov (resolved material_id
      # na entite, standard 8.3). VEDOME bez sablon (globalna kniznica nie je
      # "pouzitie v projekte") a bez projektovych predvolieb. Nikdy nezapisuje.
      # Vrati {decor => pocet dielcov} pre pas "Pouzite v projekte".
      def model_decor_usage(model)
        usage = Hash.new(0)
        return {} unless model && defined?(Ids)
        decor_by_id = {}
        sheets.each { |s| decor_by_id[s['material_id']] = s['decor'].to_s }
        %w[part board].each do |kind|
          Ids.each_of_kind(model, kind) do |inst|
            cfg = Store.config(inst) || {}
            d = decor_by_id[cfg['material_id']]
            next unless d && !d.empty?
            # Codex GH #75: doska nesie pocet kusov v configu (quantity) — pas
            # musi ratat KUSY ako BOM, nie entity (fallback 1 pre dielce/legacy).
            qty = cfg['quantity'].to_i
            usage[d] += qty.positive? ? qty : 1
          end
        end
        usage
      rescue StandardError => e
        Engine.log_error(e, 'Materials.model_decor_usage') if defined?(Engine)
        {}
      end
    end
  end
end
