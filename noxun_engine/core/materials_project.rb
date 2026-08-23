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

      # D-46: kontrakt POTVRDENIA projektovej predvolby. Prvy pokus vrati ponuku
      # s presnym rozpisom (co sa stane), klient posiela SPAT cely pending objekt
      # a server ho porovna s CERSTVE prepocitanym stavom. Nesulad v comkolvek
      # (iny model, iny material, medzitym zmeneny default, ina mnozina skriniek)
      # = suhlas patri INEMU stavu -> nova ponuka, ziadny zapis (audit B2/F5).
      # pending/fresh su ploche hashe so string klucmi; poradie ID nerozhoduje.
      PENDING_KEYS = %w[model_guid key value old_default].freeze
      PENDING_ID_KEYS = %w[adopting_ids recompute_ids].freeze

      def pending_default_ok?(pending, fresh)
        return false unless pending.is_a?(Hash) && fresh.is_a?(Hash)
        PENDING_KEYS.all? { |k| pending[k].to_s == fresh[k].to_s } &&
          PENDING_ID_KEYS.all? { |k| pending_ids(pending[k]) == pending_ids(fresh[k]) }
      end

      def pending_ids(list)
        Array(list).map { |v| v.to_s }.sort
      end

      # D-42 PR B (audit FIX 12): dekory POUZITE v aktivnom modeli — jeden
      # read-only scan vyrobnych part/board snapshotov (resolved material_id
      # na entite, standard 8.3). VEDOME bez sablon (globalna kniznica nie je
      # "pouzitie v projekte") a bez projektovych predvolieb. Nikdy nezapisuje.
      # Vrati mapu {kluc skupiny => pocet kusov} pre pas "Pouzite v projekte".
      #
      # ŠT-2a (audit #15): mapa `material_id => kluc dekorovej skupiny`. Bola
      # vnutrom `model_decor_usage`; sekcia Materialy v Studiu ju potrebuje
      # SAMOSTATNE — pocty „Použité v projekte" si totiz odvodzuje z UZ
      # zozbieraneho kusovnika (`Bom.collect`), aby okno neskenovalo model
      # DRUHYKRAT pri kazdom prepocte. Kluc je zrkadlo `mdGroupKeyOf` v JS.
      def decor_key_by_material_id
        schema2 = catalog_schema >= SCHEMA_GROUPS
        out = {}
        sheets.each do |s|
          gid = schema2 ? s['group_id'].to_s.strip : ''
          out[s['material_id']] = gid.empty? ? s['decor'].to_s : gid
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'Materials.decor_key_by_material_id') if defined?(Engine)
        {}
      end

      # ŠT-2d: to iste pre ABS pasky ({ abs_id => kluc dekorovej skupiny }).
      # „Kde sa používa" v detaile dekoru ukazuje aj pasky — a paska patri do
      # skupiny presne tak ako doska (SCHEMA 2 = group_id, inak text dekoru),
      # takze kluc MUSI vzniknut tym istym pravidlom. Vlastne odvodenie by
      # znamenalo, ze pas „Použité v projekte" a zoznam „Kde sa používa" by
      # mohli ukazovat na dve rozne skupiny.
      def decor_key_by_abs_id
        schema2 = catalog_schema >= SCHEMA_GROUPS
        out = {}
        edges.each do |a|
          gid = schema2 ? a['group_id'].to_s.strip : ''
          out[a['abs_id']] = gid.empty? ? a['decor'].to_s : gid
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'Materials.decor_key_by_abs_id') if defined?(Engine)
        {}
      end

      # 2A-4a (audit B3): kluc mapy je SCHEMA-AWARE — SCHEMA 1 = text dekoru
      # (dnesne UI), SCHEMA 2 = group_id (rovnake cislo dekoru dvoch vyrobcov
      # su DVE skupiny a ich pocty sa nesmu zliat; klienta karty skupiny doda
      # 2A-4b). Zaznam bez group_id (hybridny medzistav) padne na text dekoru.
      def model_decor_usage(model)
        usage = Hash.new(0)
        return {} unless model && defined?(Ids)
        key_by_id = decor_key_by_material_id
        %w[part board].each do |kind|
          Ids.each_of_kind(model, kind) do |inst|
            cfg = Store.config(inst) || {}
            d = key_by_id[cfg['material_id']]
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
