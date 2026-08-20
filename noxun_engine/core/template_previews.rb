# frozen_string_literal: true
# Noxun Engine — UI-D2: REALNE PNG nahlady sablon.
#
# Nahlad je SUBOR, nie datovy zaznam: schema `templates.json` sa NEMENI (std
# ostava 3) a v zozname sablon nikdy nepribudne ziadny novy kluc. Obrazky ziju
# vedla neho v %APPDATA%\NOXUN\Engine\template_previews\.
#
# SEMANTIKA (vedome rozhodnutie, zapisane aj v UI20_KONTRAKT.md):
# nahlad je KONTEXTOVA FOTOGRAFIA aktualneho pohladu doramovana na skrinku,
# nie izolovany render. Izolovany render by vyzadoval skryvanie zvysku modelu
# (zapisy do modelu = undo kroky a riziko), pricom sablona sa typicky uklada
# hned po postaveni skrinky na obrazovke. Zakryt inou geometriou alebo rez
# rovinou = nedokonaly nahlad — akceptovane.
#
# KAMERA (Codex audit BLOCKER 3): capture berie NEZAVISLU kopiu CELEJ kamery
# (eye/target/up + perspective + fov/height + aspect_ratio) a obnovi ju v
# `ensure` — aj ked `write_image` vrati false, aj pri vynimke. `write_image`
# meni aspect_ratio kamery (renderuje na iny pomer nez viewport), takze
# obnova SAMOTNEHO eye/target/up NESTACI. Cely capture je CISTY POHLAD:
# ziadna `model.start_operation`, ziadny zapis do modelu, ziadny undo krok
# (rovnaka zasada ako D-103/D-104/D-105 a `Panel.focus_camera_on`).
#
# IDENTITA SUBORU (Codex audit BLOCKER 1): `<kind>-<slug>-<sha1_16>.png`.
# Autorita je HASH — prvych 16 hex znakov SHA1("kind:name"); `slug` je LEN
# citatelnost (whitelist [a-z0-9-], strop dlzky). Preto ziadne meno sablony —
# ani „..\..\zakazka", ani cinske znaky, ani `CON` — nemoze uniknut z adresara
# ani zrazit dve rozne sablony do jedneho suboru. Vysledna cesta sa NAVYSE
# overuje containment testom (expand_path musi lezat v `dir`).
#
# ZAMOK (Codex audit BLOCKER 2): presun capture -> finalne meno aj mazanie
# bezia POD TYM ISTYM sidecar flockom ako `upsert`/`delete` (TemplateStore
# .with_lock je reentrantny) — inak by dve instancie SketchUpu mali zaznam
# jednej a obrazok druhej. Volaju sa VYHRADNE z TemplateStore, nie z UI.
require 'digest'
require 'fileutils'

module Noxun
  module Engine
    module TemplatePreviews
      DIR_NAME = 'template_previews'
      TMP_NAME = 'tmp'
      WIDTH = 240                       # 3:2 — pomer dlazdice v paneli
      HEIGHT = 160
      MAX_SLUG = 40
      HASH_LEN = 16
      # Tvrdy strop prenosu do panela. Shaded render 240x160 ma bezne 10-30 kB;
      # subor nad strop sa ani NEULOZI (nemalo by zmysel ulozit nieco, co sa
      # do panela aj tak nedostane — dlazdica by ticho ukazovala schemu).
      MAX_BYTES = 64 * 1024
      PNG_MAGIC = String.new("\x89PNG", encoding: Encoding::BINARY).freeze

      module_function

      def dir
        File.join(TemplateStore.dir, DIR_NAME)
      end

      def tmp_dir
        File.join(dir, TMP_NAME)
      end

      # --- identita suboru ----------------------------------------------------

      # Bezpecny ASCII slug (vzor VepoExport.slug / Materials.slug, lowercase
      # a spojovnik): diakritika von cez NFD, vsetko mimo [a-z0-9] na '-',
      # bez krajnych spojovnikov, strop dlzky. Prazdny vysledok = 'x' (slug je
      # len citatelnost — identitu drzi hash).
      def slug(value)
        s = value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')
        s = s.downcase.gsub(/[^a-z0-9]+/, '-')
        s = s[0, MAX_SLUG].to_s.gsub(/\A-+|-+\z/, '')
        s.empty? ? 'x' : s
      rescue StandardError
        'x'
      end

      # AUTORITA identity: prvych 16 hex SHA1("kind:name"). Kind sa berie tak,
      # ako pride (TemplateStore ho normalizuje pred volanim) — neznamy druh
      # z novsej verzie ma tak vlastny subor a nekoliduje s korpusovym.
      def digest(kind, name)
        Digest::SHA1.hexdigest("#{kind}:#{name}")[0, HASH_LEN]
      end

      def file_name(kind, name)
        "#{slug(kind)}-#{slug(name)}-#{digest(kind, name)}.png"
      end

      # Cesta k PNG sablony, alebo nil (prazdne meno / cesta mimo adresara).
      # CONTAINMENT: aj ked slug uz nemoze obsahovat '/', '\' ani '..', cesta
      # sa overuje expand_path testom — je to posledna poistka, nie ozdoba.
      def path_for(kind, name)
        return nil if name.to_s.empty?

        base = File.expand_path(dir)
        full = File.expand_path(File.join(base, file_name(kind, name)))
        return nil unless full.start_with?("#{base}/") || full.start_with?("#{base}#{File::SEPARATOR}")

        full
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.path_for')
        nil
      end

      # --- citanie (transport do panela) --------------------------------------

      # TRANSIENTNA revizia nahladu — odtlacok (mtime, velkost) suboru.
      # nil = sablona nahlad nema. Do `templates.json` sa NIKDY nezapisuje;
      # `template_list` ju pripaja cez `t.merge` (vzor `used_seq`).
      def rev_for(kind, name)
        p = path_for(kind, name)
        return nil unless p && File.file?(p)

        st = File.stat(p)
        Digest::SHA1.hexdigest("#{st.mtime.to_f}:#{st.size}")[0, 12]
      rescue StandardError
        nil
      end

      # data: URI pre HtmlDialog (CEF nesmie citat subory zo systemu priamo).
      # Serverova kontrola: PNG magic bytes + TVRDY byte limit — poskodeny
      # alebo podvrhnuty subor sa do panela nikdy nedostane. nil = bez nahladu
      # (JS si to zacachuje a dlazdica ostane na schematickom fallbacku).
      def data_uri(kind, name)
        p = path_for(kind, name)
        return nil unless p && File.file?(p)
        return nil if File.size(p) > MAX_BYTES

        bytes = File.binread(p)
        return nil unless png?(bytes)

        "data:image/png;base64,#{[bytes].pack('m0')}"
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.data_uri')
        nil
      end

      def png?(bytes)
        b = bytes.to_s
        b = b.dup.force_encoding(Encoding::BINARY) unless b.encoding == Encoding::BINARY
        b.bytesize >= 4 && b.start_with?(PNG_MAGIC)
      end

      def valid_file?(path)
        return false unless path && File.file?(path)

        size = File.size(path)
        return false if size < 4 || size > MAX_BYTES

        png?(File.open(path, 'rb') { |f| f.read(8) })
      rescue StandardError
        false
      end

      # --- capture (jediny workflow pre OBE save cesty) -----------------------

      # Odfoti `ent` do TEMP suboru a vrati jeho cestu, alebo nil (zlyhanie).
      # Volajuci ju odovzda `TemplateStore.upsert(..., preview: tmp)`, ktory
      # ju POD ZAMKOM presunie na finalne meno; nil = capture zlyhal a starý
      # PNG sa zmaze (stary obrazok k novemu configu je horsi nez schema).
      #
      # Vola sa AZ PO potvrdeni mena/prepisu a z TOHO ISTEHO model+entita
      # snapshotu ako config sablony (Codex audit FIX 5).
      def capture(model, ent)
        return nil unless model && ent && ent.respond_to?(:valid?) && ent.valid?

        view = model.active_view
        return nil unless view

        tmp = new_tmp_path
        cam = snapshot_camera(view.camera)
        done = false
        begin
          view.zoom(ent) # doramovanie na skrinku (ziadny zapis do modelu)
          # write_image vracia BOOLEAN — absencia vynimky nie je dokaz uspechu
          # (Codex audit FIX 6). Standardny render, NIE source: :framebuffer
          # (ten nepodporuje vlastne rozmery).
          written = view.write_image(filename: tmp, width: WIDTH, height: HEIGHT,
                                     antialias: true, transparent: false)
          done = (written == true) && valid_file?(tmp)
        ensure
          restore_camera(view, cam) # aj pri written == false, aj pri vynimke
        end
        return tmp if done

        Engine.log('TemplatePreviews: nahlad sablony sa nepodarilo odfotit — ostane schema')
        discard(tmp)
        nil
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.capture')
        discard(tmp)
        nil
      end

      # NEZAVISLA kopia CELEJ kamery. Klonuju sa aj body/vektory — `cam.eye`
      # vracia zivy objekt, ktory by sa nam pod rukami zmenil.
      def snapshot_camera(cam)
        return nil unless cam

        { eye: cam.eye.clone, target: cam.target.clone, up: cam.up.clone,
          perspective: (cam.perspective? ? true : false),
          fov: cam_num(cam, :fov), height: cam_num(cam, :height),
          aspect_ratio: cam_num(cam, :aspect_ratio) }
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.snapshot_camera')
        nil
      end

      def cam_num(cam, meth)
        v = cam.public_send(meth)
        v.is_a?(Numeric) && v.to_f.finite? ? v.to_f : nil
      rescue StandardError
        nil
      end

      # Obnova CELEJ kamery. Poradie je dolezite: najprv rezim (perspektiva vs.
      # orto), potom eye/target/up, az potom zorny uhol / vyska orto okna —
      # `fov` v orto rezime a `height` v perspektive nemaju vyznam.
      # `aspect_ratio` sa obnovuje VZDY (0.0 = „pomer viewportu"), lebo prave
      # ten `write_image` prepisuje.
      def restore_camera(view, snap)
        return false unless view && snap

        cam = view.camera
        cam.perspective = snap[:perspective]
        cam.set(snap[:eye], snap[:target], snap[:up])
        if snap[:perspective]
          cam.fov = snap[:fov] if snap[:fov]
        elsif snap[:height]
          cam.height = snap[:height]
        end
        cam.aspect_ratio = snap[:aspect_ratio] if snap[:aspect_ratio]
        view.invalidate
        true
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.restore_camera')
        false
      end

      # --- zapis do skladu (VYHRADNE spod zamku TemplateStore) ----------------

      # Samotny presun capture temp suboru na finalne meno. NIC nemaze —
      # o osude STAREHO obrazka rozhoduje volajuci (`replace` vs. `attach`),
      # lebo odpoved zavisi od toho, ci sa medzitym zmenil config sablony.
      # Nepouzitelny temp (chybajuca cesta, nie PNG, nad limitom) = false BEZ
      # vynimky, takze sa nic nemaze ani v jednej ceste.
      def move_into_place(kind, name, tmp)
        target = path_for(kind, name)
        return false unless target && valid_file?(tmp)

        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.mv(tmp, target, force: true)
        true
      end

      # UPSERT cesta (config sablony sa PRAVE ZMENIL): zlyhanie presunu sa berie
      # rovnako ako zlyhany capture — stary PNG uz patri inemu tvaru skrinky,
      # takze sa zmaze (obrazok stareho tvaru k novemu configu je horsi nez
      # schematicky fallback).
      def replace(kind, name, tmp)
        move_into_place(kind, name, tmp)
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.replace')
        discard(tmp)
        delete(kind, name)
        false
      end

      # SMOKE PACK 1 (Codex #183 P2): NEDESTRUKTIVNY protejsok — cesta, ktora
      # meni VYHRADNE obrazok (`TemplateStore.set_preview`, rucne „Prefotiť").
      # Config sablony sa nemeni, takze uz ulozeny nahlad je STALE PLATNY:
      # prechodna chyba disku pri presune noveho suboru ho NESMIE zmazat, inak
      # by neuspesne prefotenie zobralo pouzivatelovi aj to, co uz mal.
      def attach(kind, name, tmp)
        move_into_place(kind, name, tmp)
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.attach')
        discard(tmp)
        false
      end

      def delete(kind, name)
        p = path_for(kind, name)
        return false unless p

        FileUtils.rm_f(p)
        true
      rescue StandardError => e
        Engine.log_error(e, 'TemplatePreviews.delete')
        false
      end

      # Zahodenie NEPOUZITEHO capture temp suboru (odmietnuty zapis, zlyhany
      # capture). Maze VYHRADNE v temp adresari — nikdy nie ulozeny nahlad.
      def discard(tmp)
        return false unless tmp.is_a?(String) && !tmp.empty?

        base = File.expand_path(tmp_dir)
        full = File.expand_path(tmp)
        return false unless full.start_with?("#{base}/") || full.start_with?("#{base}#{File::SEPARATOR}")

        FileUtils.rm_f(full)
        true
      rescue StandardError
        false
      end

      def new_tmp_path
        FileUtils.mkdir_p(tmp_dir)
        File.join(tmp_dir, "capture-#{Process.pid}-#{Time.now.to_i}-#{rand(1 << 24).to_s(16)}.png")
      end
    end
  end
end
