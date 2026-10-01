# frozen_string_literal: true
# Noxun Engine — store. Citanie/zapis jedneho NOXUN dictionary (standard sekcia 2.1).
# Plocke klucove skalary + config ako JSON string. Data ziju na INSTANCII (2.2).
require 'json'

module Noxun
  module Engine
    module Store
      DICT = 'NOXUN'
      STD  = 1 # verzia standardu

      # Zapise ploche kluce a config (Hash -> JSON) na entitu.
      # attrs: hash s klucmi std/kind/id/part_id/cabinet_id/template_id/role/
      #        manufactured/production_class a volitelne :config (Hash alebo String).
      def self.write(entity, attrs)
        h = attrs.dup
        cfg = h.delete(:config) || h.delete('config')
        h.each { |k, v| entity.set_attribute(DICT, k.to_s, v) unless v.nil? }
        write_config(entity, cfg) unless cfg.nil?
        entity
      end

      def self.write_config(entity, cfg)
        json = cfg.is_a?(String) ? cfg : cfg.to_json
        entity.set_attribute(DICT, 'config', json)
      end

      def self.get(entity, key)
        return nil unless entity.respond_to?(:get_attribute)
        entity.get_attribute(DICT, key.to_s)
      end

      # H8 (R-13): CITANIE znacky verzie standardu `std` (STANDARD 2.1, odsek
      # „Čítanie std"). Zapis ostava nezmeneny (9 miest, vzdy `STD`); tu sa
      # len rozlisi „kluc chyba" od ulozenej hodnoty — `get` to nevie (vracia
      # nil v oboch pripadoch). Sentinel ako `BudgetStore::STD_MISSING`.
      STD_MISSING = Object.new.freeze

      # -> [:missing | :present | :error, raw]. Bez vynimky: `Bom.collect`
      # nema rescue, takze divny atribut nesmie zhodit Kontrolu ani exporty.
      def self.read_std(entity)
        return [:missing, nil] unless entity.respond_to?(:get_attribute)

        raw = entity.get_attribute(DICT, 'std', STD_MISSING)
        raw.equal?(STD_MISSING) ? [:missing, nil] : [:present, raw]
      rescue StandardError => e
        Engine.log_error(e, 'Store.read_std')
        [:error, nil]
      end

      # CISTA klasifikacia znacky -> :current | :legacy | :older | :newer | :invalid.
      # Prisne (vzor R-14): platna je LEN `Integer >= 1` — ziadne `.to_i`,
      # „1" ani 1.0 nie su aktualna znacka. Chybajuci kluc = :legacy
      # („predštandardová" entita, STANDARD 0).
      def self.std_state_of(presence, raw, current: STD)
        return :legacy if presence == :missing
        return :invalid unless presence == :present && raw.is_a?(Integer) && raw >= 1
        return :current if raw == current

        raw > current ? :newer : :older
      end

      def self.std_state(entity, current: STD)
        std_state_of(*read_std(entity), current: current)
      end

      def self.kind(entity)
        get(entity, 'kind')
      end

      def self.noxun?(entity)
        !kind(entity).nil?
      end

      # Config ako Hash (JSON.parse), alebo nil / {} pri chybe.
      def self.config(entity)
        raw = get(entity, 'config')
        return nil if raw.nil?
        JSON.parse(raw)
      rescue JSON::ParserError => e
        Engine.log_error(e, 'Store.config')
        nil
      end
    end
  end
end
