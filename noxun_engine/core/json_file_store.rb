# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tmpdir'

module Noxun
  module Engine
    # Spolocna perzistencia malych JSON katalogov. Drzi read-only cache v pamati,
    # sleduje zmeny suboru a zapisuje cez atomicku vymenu bez okna bez ciela.
    module JsonFileStore
      CHECK_INTERVAL = 1.0

      module_function

      def read(path, copy: true)
        key = File.expand_path(path)
        now = monotonic_time
        entry = cache[key]
        if entry && now - entry[:checked_at] < CHECK_INTERVAL
          return copy ? deep_copy(entry[:value]) : entry[:value]
        end

        signature = file_signature(key)
        if entry && entry[:signature] == signature
          entry[:checked_at] = now
          return copy ? deep_copy(entry[:value]) : entry[:value]
        end

        value = read_primary_or_backup(key)
        frozen = deep_freeze(value)
        cache[key] = { signature: file_signature(key), checked_at: now, value: frozen }
        copy ? deep_copy(frozen) : frozen
      end

      def write(path, payload)
        key = File.expand_path(path)
        FileUtils.mkdir_p(File.dirname(key))
        tmp = temporary_path(key)
        write_temp(tmp, JSON.pretty_generate(payload))
        preserve_valid_backup(key)
        File.rename(tmp, key)
        invalidate(key)
        true
      ensure
        begin
          File.delete(tmp) if defined?(tmp) && tmp && File.exist?(tmp)
        rescue StandardError
          nil
        end
      end

      def reload!(path = nil)
        invalidate(path)
      end

      def available?(path)
        key = File.expand_path(path)
        File.exist?(key) || File.exist?("#{key}.bak")
      end

      def invalidate(path = nil)
        if path
          cache.delete(File.expand_path(path))
        else
          @cache = {}
        end
        true
      end

      def deep_copy(value)
        Marshal.load(Marshal.dump(value))
      end

      def cache
        @cache ||= {}
      end

      def read_primary_or_backup(path)
        JSON.parse(File.binread(path))
      rescue JSON::ParserError, Errno::ENOENT => primary_error
        backup = "#{path}.bak"
        raise primary_error unless File.exist?(backup)
        value = JSON.parse(File.binread(backup))
        Engine.log("json store: #{File.basename(path)} je poskodeny, pouzivam zalohu") if Engine.respond_to?(:log)
        value
      end

      def preserve_valid_backup(path)
        return unless File.exist?(path)
        content = File.binread(path)
        JSON.parse(content)
        backup = "#{path}.bak"
        tmp = temporary_path(backup)
        write_temp(tmp, content)
        File.rename(tmp, backup)
      rescue JSON::ParserError, Errno::ENOENT
        # Poskodeny primarny subor nesmie prepisat poslednu platnu zalohu.
        nil
      ensure
        begin
          File.delete(tmp) if defined?(tmp) && tmp && File.exist?(tmp)
        rescue StandardError
          nil
        end
      end

      def write_temp(path, content)
        File.open(path, 'wb') do |file|
          file.write(content)
          file.flush
          begin
            file.fsync
          rescue Errno::EINVAL, NotImplementedError
            # Nie kazdy filesystem podporuje fsync; flush stale prebehlo.
          end
        end
      end

      def temporary_path(path)
        "#{path}.tmp-#{Process.pid}-#{Thread.current.object_id}"
      end

      def file_signature(path)
        [stat_signature(path), stat_signature("#{path}.bak")]
      end

      def stat_signature(path)
        stat = File.stat(path)
        [stat.mtime.to_f, stat.size]
      rescue Errno::ENOENT
        nil
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, item| deep_freeze(key); deep_freeze(item) }
        when Array
          value.each { |item| deep_freeze(item) }
        end
        value.freeze
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
