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
