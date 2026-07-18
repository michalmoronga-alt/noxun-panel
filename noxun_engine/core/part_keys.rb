# frozen_string_literal: true

module Noxun
  module Engine
    # Stabilna identita dielca v ramci korpusu. part_id a nazov definicie mozu
    # nadalej pouzivat renderovaci suffix; part_key je datovy kontrakt pre
    # override, kovanie a buduce vystupy.
    module PartKeys
      SCHEMA = 1

      module_function

      def cabinet(kind, variant = nil)
        key = "cabinet/#{segment(kind)}"
        variant ? "#{key}:#{segment(variant)}" : key
      end

      def zone(zone_id, kind, index)
        "zone:#{segment(zone_id)}/#{segment(kind)}:#{index.to_i}"
      end

      def front(front_id, kind, variant = nil)
        key = "front:#{segment(front_id)}/#{segment(kind)}"
        variant ? "#{key}:#{segment(variant)}" : key
      end

      # Samostatna doska (V0.4.7): kluc je v ramci dosky KONSTANTNY ('board/main') —
      # unikatnost dava id dosky (BRD-001), vazba = id + part_key (owner-scope,
      # standard 2.3). Parameter kind je rezerva pre buduce viacdielcove dosky.
      def board(kind = 'main')
        "board/#{segment(kind)}"
      end

      def for_descriptor(descriptor)
        key = descriptor && descriptor[:part_key].to_s
        raise "Dielcu #{descriptor && descriptor[:suffix]} chyba part_key." if key.nil? || key.empty?
        key
      end

      # Formalna kontrola formatu stabilnej identity — BuildPlan.validate! nou strazi
      # cudzie/poskodene kluce (napr. z rucne editovaneho configu).
      # 'board/' pridane V0.4.7 ADITIVNE (bez bumpu SCHEMA — stare kluce sa nemenia).
      # Toto je len SYNTAKTICKA validita; referencnu validitu ownera v konkretnom
      # plane strazi BuildPlan.validate_hardware! (kluc musi existovat v parts).
      def valid?(key)
        key.to_s.match?(%r{\A(cabinet/|zone:|front:|board/)\S+\z})
      end

      # Prevedie V0.3 override kluce (renderovaci suffix) na part_key podla
      # aktualneho planu. Nezname kluce zachova, aby sa pri migracii nestratili
      # data. Ak existuje novy aj stary kluc, explicitny novy kluc vyhrava.
      def migrate_overrides(raw, descriptors)
        source = raw.is_a?(Hash) ? raw : {}
        current = {}
        legacy_to_current = {}
        Array(descriptors).each do |descriptor|
          key = for_descriptor(descriptor)
          raise "Duplicitny part_key #{key} v plane." if current[key]
          current[key] = true
          suffix = descriptor[:suffix].to_s
          legacy_to_current[suffix] = key unless suffix.empty?
        end

        out = {}
        source.each { |key, value| out[key.to_s] = value if current[key.to_s] }
        source.each do |key, value|
          old = key.to_s
          target = legacy_to_current[old] || old
          out[target] = value unless out.key?(target)
        end
        out
      end

      def segment(value)
        cleaned = value.to_s.strip.gsub(/[^A-Za-z0-9_.-]+/, '_')
        cleaned.empty? ? 'unknown' : cleaned
      end
    end
  end
end
