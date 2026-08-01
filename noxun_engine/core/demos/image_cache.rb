# frozen_string_literal: true
# Noxun Engine — V0.6 M-A: lokalna cache obrazkov dekorov z Demosu.
#
# Audit M-A BLOCKER 1: HtmlDialog NIKDY nedostane vzdialenu URL — CEF by
# stahoval obrazky paralelne mimo Demos klienta (bez throttle, allowlistu,
# User-Agenta). Obrazok sa stiahne RAZ pri zakladani skupiny cez Demos.fetch
# (plny guard + 3 s throttle) a ulozi do %APPDATA%/NOXUN/Engine/textures/;
# okno cita VYHRADNE lokalny subor. Chybajuci/nestiahnuty obrazok = fallback
# farba dlazdice (best effort — NIKDY neblokuje zalozenie skupiny).
#
# Subory su zaroven buduci zdroj textur pre render (M-R) — preto 'textures'.

require 'digest'
require 'fileutils'

module Noxun
  module Engine
    module DemosImageCache
      DIR_NAME = 'textures'
      # Produktove JPG maju desiatky-stovky kB; 3 MB strop je stedry.
      MAX_IMAGE_BYTES = 3_000_000
      JPEG_MAGIC = String.new("\xFF\xD8", encoding: Encoding::BINARY).freeze
      PNG_MAGIC = String.new("\x89PNG", encoding: Encoding::BINARY).freeze

      module_function

      def dir
        File.join(Materials.dir, DIR_NAME)
      end

      # Deterministicka lokalna cesta pre URL (hash prefix drzi unikatnost,
      # basename citatelnost). Nil pri URL mimo guardu.
      def path_for(url)
        clean = Demos.sanitize_image_url(url)
        return nil unless clean
        base = File.basename(URI.parse(clean).path)
        File.join(dir, "#{Digest::SHA1.hexdigest(clean)[0, 10]}_#{base}")
      end

      # Lokalny subor pre URL, ak uz je stiahnuty (rychla cesta pre payloady
      # okna — ziadna siet). Nil = nie je v cache.
      # GH #101 P2: velkost suboru NIE JE dokaz platnosti — preruseny zapis
      # by nechal neprazdny fragment a kazdy dalsi ensure by ho vecne
      # preskakoval. Overuju sa magic bytes; nevalidny subor = nil (refetch).
      def local_for(url)
        p = path_for(url)
        p && valid_image_file?(p) ? p : nil
      end

      def valid_image_file?(path)
        return false unless File.exist?(path) && File.size(path) >= 4
        head = File.open(path, 'rb') { |f| f.read(4) }
        head.to_s.start_with?(JPEG_MAGIC) || head.to_s.start_with?(PNG_MAGIC)
      rescue StandardError
        false
      end

      # ensure(url) { |local_path_or_nil| } — existujuci subor vrati HNED bez
      # siete; inak async fetch cez Demos klienta (throttle/guardy) + kontrola
      # magic bytes + zapis. KAZDA chyba konci nil (best effort).
      def ensure(url, &done)
        clean = Demos.sanitize_image_url(url)
        return done.call(nil) unless clean
        if (existing = local_for(clean))
          return done.call(existing)
        end
        Demos.fetch(clean, limit: :page) do |res|
          done.call(res['ok'] ? store(path_for(clean), res['body']) : nil)
        end
        true
      end

      # Binarny zapis s validaciou obsahu (JPEG/PNG magic — HTML chybova
      # stranka s 200 sa nesmie ulozit ako "obrazok").
      # GH #101 P2: zapis cez temp + presun (preruseny binwrite priamo do
      # ciela by nechal fragment, ktory vyzera ako subor).
      def store(local, body)
        return nil unless local
        b = body.to_s.dup.force_encoding(Encoding::BINARY)
        return nil if b.empty? || b.bytesize > MAX_IMAGE_BYTES
        return nil unless b.start_with?(JPEG_MAGIC) || b.start_with?(PNG_MAGIC)
        FileUtils.mkdir_p(File.dirname(local))
        tmp = "#{local}.tmp#{Process.pid}"
        File.binwrite(tmp, b)
        FileUtils.mv(tmp, local, force: true)
        local
      rescue StandardError => e
        Engine.log_error(e, 'DemosImageCache.store') if defined?(Engine)
        begin
          FileUtils.rm_f(tmp) if tmp
        rescue StandardError
          nil
        end
        nil
      end
    end
  end
end
