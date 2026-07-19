# frozen_string_literal: true
# Noxun Engine — D-25 merac pouzivania panela. Lokalne pocitadla interakcii
# s prvkami Inspectora (podklad pre buduci rezim Jednoduchy/Rozsireny).
# Uklada VYLUCNE identifikatory prvkov a pocty — ziadne hodnoty poli, ziadne
# nazvy projektov/suborov. Subor: %APPDATA%\NOXUN\Engine\usage_stats.json
# (zapis cez JsonFileStore — atomicky tmp+rename, .bak zaloha; testovaci
# sandbox funguje cez ENV['APPDATA'] presmerovane v tests/helper.rb, rovnaky
# vzor ako TemplateStore).
#
# Struktura suboru (SCHEMA 1):
#   { "schema": 1, "first_seen": "YYYY-MM-DD", "last_seen": "YYYY-MM-DD",
#     "counts": { "kluc_prvku": n, ... } }
# first_seen sa po vzniku NEMENI; counts sa pri flushi pricitavaju; neznane
# polia existujuceho JSON sa pri zapise zachovaju a subor s NOVSOU schemou sa
# NEPREPISUJE (forward kompatibilita — Codex audit D-25). Read-modify-write
# chráni flock na sidecar zámku — dve instancie SketchUpu si neprepisu davky.
require 'json'
require 'fileutils'
require 'tmpdir'

module Noxun
  module Engine
    module UsageStats
      SCHEMA = 1
      FILE = 'usage_stats.json'
      DATE_RE = /\A\d{4}-\d{2}-\d{2}\z/
      MANAGED_KEYS = %w[schema first_seen last_seen counts].freeze
      MAX_KEY_LENGTH = 160       # kluce su identifikatory prvkov — dlhsie = vadny payload
      MAX_COUNT = 1_000_000      # strop pocitadla (ochrana pred nezmyselnymi hodnotami)

      module_function

      def dir
        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      def lock_path
        "#{path}.lock"
      end

      # Pricita davku pocitadiel z panela do suboru. Vrati true/false; NIKDY
      # nevyhadzuje — merac nesmie rusit pracu (chyba sa len zaloguje).
      def record(counts, today: today_str)
        increments = sanitize_counts(counts)
        return false if increments.empty?

        with_lock do
          existing = read_existing
          schema = existing['schema']
          if schema.is_a?(Integer) && schema > SCHEMA
            # Subor z novsej verzie pluginu — starsi kod mu nerozumie a nesmie
            # ho degradovat (schema by sa prepisala, counts mohli znicit).
            Engine.log("UsageStats: subor ma novsiu schemu #{schema} — flush preskoceny")
            return false
          end
          JsonFileStore.write(path, merge(existing, increments, today: today))
        end
        true
      rescue StandardError => e
        Engine.log_error(e, 'UsageStats.record')
        false
      end

      # --- cista merge logika (bez IO — testovatelna headless) ----------------

      # Zluci existujuci obsah suboru s prirastkami. first_seen ostava, ak je
      # platny datum; counts sa scitavaju (obe strany sanitizovane); neznane
      # top-level polia existujuceho JSON prezivaju zapis.
      def merge(existing, increments, today:)
        base = existing.is_a?(Hash) ? existing : {}
        merged_counts = sanitize_counts(base['counts'])
        sanitize_counts(increments).each do |key, value|
          merged_counts[key] = [merged_counts.fetch(key, 0) + value, MAX_COUNT].min
        end
        first_seen = base['first_seen']
        first_seen = today unless first_seen.is_a?(String) && first_seen.match?(DATE_RE)
        extras = base.reject { |key, _| MANAGED_KEYS.include?(key) }
        {
          'schema' => SCHEMA,
          'first_seen' => first_seen,
          'last_seen' => today,
          'counts' => merged_counts
        }.merge(extras)
      end

      # Ocisti pocitadla: len Hash; kluc String (nie prazdny, max dlzka);
      # hodnota kladne cele cislo (Integer / Float zaokruhleny / ciselny
      # String), so stropom. Vsetko ostatne sa TICHO zahodi (vadny payload
      # nesmie zhodit flush).
      def sanitize_counts(raw)
        return {} unless raw.is_a?(Hash)

        out = {}
        raw.each do |k, v|
          key = k.to_s
          next if key.empty? || key.length > MAX_KEY_LENGTH

          n = to_count(v)
          next if n.nil? || n <= 0

          out[key] = [n, MAX_COUNT].min
        end
        out
      end

      def to_count(value)
        case value
        when Integer then value
        when Float then value.finite? ? value.round : nil
        when String then value.match?(/\A\d+\z/) ? value.to_i : nil
        end
      end

      # --- IO helpery ---------------------------------------------------------

      # Exkluzivny zamok na SIDECAR subore (nie na datovom — drzany handle by na
      # Windows zablokoval atomicky rename JsonFileStore). Chráni read+merge+write
      # medzi viacerymi instanciami SketchUpu; vnutri sa cache invaliduje, aby sa
      # citalo cerstvo z disku (cache JsonFileStore ma 1 s okno).
      def with_lock
        FileUtils.mkdir_p(dir)
        File.open(lock_path, File::RDWR | File::CREAT) do |f|
          f.flock(File::LOCK_EX)
          begin
            JsonFileStore.invalidate(path)
            yield
          ensure
            f.flock(File::LOCK_UN)
          end
        end
      end

      def read_existing
        return {} unless JsonFileStore.available?(path)

        data = JsonFileStore.read(path)
        data.is_a?(Hash) ? data : {}
      rescue StandardError => e
        Engine.log_error(e, 'UsageStats.read_existing')
        {}
      end

      def today_str
        Time.now.strftime('%Y-%m-%d')
      end
    end
  end
end
