# frozen_string_literal: true
# Noxun Engine — D-52a: JADRO AKTUALIZATORA PLUGINU (bez UI).
#
# CO TO ROBI: z priecinka s KOPIOU REPA (`noxun_engine.rb` + strom
# `noxun_engine/`) prenesie novsiu verziu do zivej SketchUp `Plugins` zlozky.
# Jednotka atomicity je CELY BALIK — loader aj strom su jedna generacia;
# novy strom so starym loaderom je zakazany stav (main.rb fallback by hlasil
# staru verziu nad novym kodom).
#
# CISTY MODUL: ziadne `Sketchup.*` ani `UI.*` pri nacitani, vsetky cesty
# prichadzaju ako PARAMETRE. `Engine.plugin_dir` / `find_support_file` patria
# UI vrstve (D-52b). Vdaka tomu bezi cela sada headless nad TEMP sandboxom.
#
# ROZLOZENIE NA DISKU (vsetko v `Plugins`, teda RODICOVI stromu):
#   noxun_engine/            ziva generacia — strom
#   noxun_engine.rb          ziva generacia — loader
#   noxun_engine.new/        pripraveny (staged) strom
#   noxun_engine.rb.new      pripraveny loader
#   noxun_engine.old/        predchadzajuca generacia — strom
#   noxun_engine.rb.old      predchadzajuca generacia — loader
#   noxun_engine.update.json transakcny marker
#   noxun_engine.update.lock medziprocesovy zamok aktualizacie
#   noxun_engine.leases/     <pid>.lease kazdeho beziaceho procesu
#
# KROKY (kazdy s definovanym rollbackom):
#   1. manifest zo ZDROJA (relativna cesta -> SHA1 + velkost)
#   2. staging KOPIOU do `.new` (nie rename — sietovy share moze streamovat
#      useknuty subor) + VALIDACIA staged stromu proti manifestu byte-for-byte;
#      VERSION sa parsuje zo STAGED loadera (autorita) a krizom proti staged
#      `main.rb`; rozhodnutie „novsia" sa prepocita zo STAGED (F8)
#   3. `noxun_engine` -> `noxun_engine.old`   (zlyhanie -> uprac `.new`, koniec)
#   4. `noxun_engine.new` -> `noxun_engine`   (zlyhanie -> vrat `.old` spat)
#   5. loader `.rb` -> `.rb.old`, `.rb.new` -> `.rb` (zlyhanie -> VRAT CELY SWAP)
#   6. `.old` sa maze az po uspechu; zlyhanie mazania je USPECH s poznamkou
#      (zvysky uprace recovery pri najblizsom boote)
#
# CO TU NIE JE (D-52b): About UI, asynchronny check s deadline, bariera
# zatvarania okien, `UI.messagebox` vysledku, in-SU smoke.
#
# RECOVERY PO PADE ZIJE V LOADERI `noxun_engine.rb`, NIE TU — pri pade medzi
# krokmi 3 a 5 moze strom CHYBAT, takze kod, ktory ho oprava, sa z neho nesmie
# nacitavat. Tento modul recovery NEDUPLIKUJE; pri starte aktualizacie iba
# ODMIETNE bezat, ked marker existuje (= predchadzajuca transakcia sa
# nedokoncila a poriadok urobi az najblizsi boot).
require 'json'
require 'fileutils'
require 'digest'
require 'rbconfig'

module Noxun
  module Engine
    # --- B2: RESTART LATCH ---------------------------------------------------
    # Po uspesnom commite bezi v pamati STARY Ruby kod nad NOVYMI subormi.
    # Otvorenie okna by nacitalo nove HTML/JS proti starym callbackom, vkladanie
    # by stavalo starym builderom. Preto sa VSETKY vstupne body pluginu az do
    # restartu odmietnu. Latch je jednosmerny — vypina ho vyhradne restart
    # SketchUpu (a v testoch `reset_restart_latch!`).
    def self.restart_required!
      @restart_required = true
    end

    def self.restart_required?
      @restart_required == true
    end

    # LEN pre testy a rucny reload — v produkcnej ceste latch nikto nezhasina.
    def self.reset_restart_latch!
      @restart_required = false
      true
    end

    # Guard vstupneho bodu: `true` = volajuci ma SKONCIT. Hlaska je NATIVNA
    # (`UI.messagebox`) — CEF uz moze byt nad novymi subormi. Headless (bez UI)
    # sa len vrati `true`.
    def self.update_restart_pending?
      return false unless restart_required?

      begin
        ::UI.messagebox(Updater::RESTART_MESSAGE) if defined?(::UI) && ::UI.respond_to?(:messagebox)
      rescue StandardError
        nil # hlaska nesmie prebit samotne odmietnutie
      end
      true
    end

    module Updater
      # Odmietnutie s DOVODOM. Kazde odmietnutie necha ciel BYTE-IDENTICKY.
      Refused = Class.new(StandardError)

      STD = 1 # verzia formatu updater_settings.json
      SETTINGS_FILE = 'updater_settings.json'

      TREE_NAME   = 'noxun_engine'
      LOADER_NAME = 'noxun_engine.rb'
      MARKER_NAME = 'noxun_engine.update.json'
      LOCK_NAME   = 'noxun_engine.update.lock'
      LEASES_DIR  = 'noxun_engine.leases'

      NEW_SUFFIX = '.new'
      OLD_SUFFIX = '.old'

      # Hlavicka loadera sa cita OBMEDZENE — zdroj moze byt sietovy share a
      # `VERSION` je na 9. riadku. Citat cely subor kvoli jednemu cislu je
      # zbytocna zataz (a pri poskodenom/obrom subore priama pasca).
      VERSION_HEAD_BYTES = 4096
      VERSION_RE = /^[ \t]*VERSION\s*=\s*'([^']*)'/.freeze
      VALID_VERSION_RE = /\A\d{1,5}(?:\.\d{1,5}){0,3}\z/.freeze

      # Strop balika. Realny plugin ma radovo stovky suborov a jednotky MB —
      # ciselka su rezerva, nie limit funkcnosti. Bez nich by omylom zadany
      # priecinok (napr. koren disku) zaplnil `Plugins`.
      MAX_FILES = 5000
      MAX_TOTAL_BYTES = 200 * 1024 * 1024

      RESTART_MESSAGE = 'Noxun Engine bol aktualizovaný — reštartuj SketchUp.'

      module_function

      # --- cesty ------------------------------------------------------------
      # Cielom je VZDY dvojica: strom `plugin_dir` a SURODENECKY loader vedla
      # neho. `plugins_dir` je ich spolocny rodic — tam zije aj marker, zamok,
      # lease a oba `.new`/`.old` zvysky.
      def plugins_dir_of(plugin_dir)
        File.dirname(File.expand_path(plugin_dir))
      end

      def tree_path(plugins_dir)
        File.join(plugins_dir, TREE_NAME)
      end

      def loader_path(plugins_dir)
        File.join(plugins_dir, LOADER_NAME)
      end

      def staged_tree(plugins_dir)
        "#{tree_path(plugins_dir)}#{NEW_SUFFIX}"
      end

      def staged_loader(plugins_dir)
        "#{loader_path(plugins_dir)}#{NEW_SUFFIX}"
      end

      def previous_tree(plugins_dir)
        "#{tree_path(plugins_dir)}#{OLD_SUFFIX}"
      end

      def previous_loader(plugins_dir)
        "#{loader_path(plugins_dir)}#{OLD_SUFFIX}"
      end

      def marker_path(plugins_dir)
        File.join(plugins_dir, MARKER_NAME)
      end

      def lock_path(plugins_dir)
        File.join(plugins_dir, LOCK_NAME)
      end

      def leases_dir(plugins_dir)
        File.join(plugins_dir, LEASES_DIR)
      end

      # --- verzie -----------------------------------------------------------
      # Porovnanie je CISELNE po segmentoch: `0.9.9 < 0.10.0` (textove `<` by
      # dalo opacne). Chybajuci segment = 0, takze `0.9` == `0.9.0`.
      def compare(left, right)
        a = left.to_s.split('.').map(&:to_i)
        b = right.to_s.split('.').map(&:to_i)
        len = [a.length, b.length].max
        len.times do |i|
          cmp = a.fetch(i, 0) <=> b.fetch(i, 0)
          return cmp unless cmp.zero?
        end
        0
      end

      # Trojstav voci BEZIACEJ verzii. `:older` je vo V1 ZAKAZANY smer (B4):
      # samotne VERSION nehovori nic o tom, ci starsi plugin este rozumie
      # datam, ktore uz novsia verzia zapisala (schema katalogov, marker
      # configu). Rucnu cestu ma pouzivatel v INSTALL skripte.
      def classify(current, candidate)
        cmp = compare(candidate, current)
        return :newer if cmp.positive?
        return :older if cmp.negative?

        :same
      end

      # VERSION z textu hlavicky. Chybajuca, prazdna, neplatna aj DUPLICITNA
      # definicia je CHYBA — nie „nejaka hodnota": z balika, ktoremu nerozumieme,
      # sa nesmie stat ziva instalacia.
      def parse_version(text)
        hits = text.to_s.scan(VERSION_RE).flatten
        raise Refused, 'v hlavičke nie je VERSION' if hits.empty?
        raise Refused, "VERSION je v hlavičke #{hits.length}×" if hits.length > 1

        value = hits.first.to_s.strip
        raise Refused, "neplatná VERSION #{value.inspect}" unless value =~ VALID_VERSION_RE

        value
      end

      def read_version(path)
        raise Refused, "súbor #{File.basename(path)} chýba" unless File.file?(path)

        head = File.open(path, 'rb') { |f| f.read(VERSION_HEAD_BYTES) }
        parse_version(head.to_s.force_encoding(Encoding::UTF_8))
      end

      # --- kanonicke hranice (F9) -------------------------------------------
      def normalize_path(path)
        p = File.expand_path(path.to_s).tr('\\', '/')
        p = p.chomp('/') unless p =~ %r{\A[A-Za-z]:/\z} || p == '/'
        p
      end

      # Windows je case-insensitive; porovnavame preto znormalizovane malymi.
      def same_path?(left, right)
        normalize_path(left).downcase == normalize_path(right).downcase
      end

      def inside?(child, parent)
        c = normalize_path(child).downcase
        p = normalize_path(parent).downcase
        c.start_with?("#{p}/")
      end

      # Symlink / junction / reparse point: realna cesta sa lisi od zapisanej.
      # Rename cez link by presunul LINK, nie obsah — a `.old` by po pade
      # ukazoval do cudzieho stromu.
      def refuse_link!(path, label)
        raise Refused, "#{label} je symlink (#{path})" if File.symlink?(path)
        return true unless File.exist?(path)

        real = begin
          File.realpath(path)
        rescue StandardError => e
          raise Refused, "#{label} sa nedá overiť (#{e.class})"
        end
        return true if same_path?(real, path)

        raise Refused, "#{label} je odkaz na iné miesto (#{path} → #{real})"
      end

      # Zdroj MUSI byt kopia repa a MUSI lezat mimo cieloveho priecinka.
      def check_boundaries!(source_dir, plugin_dir)
        source = File.expand_path(source_dir.to_s)
        tree = File.expand_path(plugin_dir.to_s)
        plugins = File.dirname(tree)

        raise Refused, 'zdrojový priečinok nie je zadaný' if source_dir.to_s.strip.empty?
        raise Refused, "zdrojový priečinok neexistuje (#{source})" unless File.directory?(source)

        base = File.basename(normalize_path(source))
        if base.end_with?(NEW_SUFFIX) || base.end_with?(OLD_SUFFIX)
          raise Refused, "zdroj je pracovný priečinok aktualizácie (#{base})"
        end

        raise Refused, 'zdroj a cieľ sú ten istý priečinok' if same_path?(source, plugins) || same_path?(source, tree)
        raise Refused, 'zdroj leží vnútri cieľového priečinka' if inside?(source, plugins)
        raise Refused, 'cieľ leží vnútri zdrojového priečinka' if inside?(plugins, source)

        refuse_link!(source, 'zdrojový priečinok')
        refuse_link!(plugins, 'cieľový priečinok')
        refuse_link!(tree, 'strom pluginu') if File.exist?(tree)
        refuse_link!(loader_path(plugins), 'loader') if File.exist?(loader_path(plugins))

        unless File.file?(File.join(source, LOADER_NAME)) && File.directory?(File.join(source, TREE_NAME))
          raise Refused, "zdroj nie je balík pluginu (chýba #{LOADER_NAME} alebo #{TREE_NAME}/)"
        end

        [source, plugins, tree]
      end

      # Relativna cesta z manifestu sa NIKDY nesmie dostat mimo staging root.
      def safe_relative!(rel)
        r = rel.to_s
        raise Refused, "neplatná cesta v balíku (#{r.inspect})" if r.empty?
        raise Refused, "absolútna cesta v balíku (#{r})" if r.start_with?('/') || r =~ %r{\A[A-Za-z]:}
        raise Refused, "spätné lomítko v ceste balíka (#{r})" if r.include?('\\')

        segments = r.split('/')
        if segments.any? { |s| s.empty? || s == '.' || s == '..' }
          raise Refused, "cesta uniká zo stromu balíka (#{r})"
        end

        r
      end

      # --- manifest ---------------------------------------------------------
      # Kluce su relativne cesty voci KORENU BALIKA: `noxun_engine.rb` a
      # `noxun_engine/...`. Rovnaky tvar ma manifest zdroja aj staged stromu,
      # takze porovnanie je obycajne porovnanie dvoch hashov.
      def digest_of(path)
        sha = Digest::SHA1.new
        File.open(path, 'rb') do |f|
          while (chunk = f.read(65_536))
            sha.update(chunk)
          end
        end
        sha.hexdigest
      end

      def collect_files(root, tree_dir, prefix, out)
        Dir.children(tree_dir).sort.each do |name|
          path = File.join(tree_dir, name)
          rel = prefix.empty? ? name : "#{prefix}/#{name}"
          refuse_link!(path, "položka balíka #{rel}")
          if File.directory?(path)
            collect_files(root, path, rel, out)
          elsif File.file?(path)
            out[safe_relative!(rel)] = { 'size' => File.size(path), 'sha1' => digest_of(path) }
          else
            raise Refused, "položka balíka nie je súbor ani priečinok (#{rel})"
          end
        end
        out
      end

      # Manifest balika: loader + cely strom. Volane nad ZDROJOM aj nad
      # STAGED kopiou — preto `tree_root`/`loader` ako parametre.
      def manifest_of(tree_root, loader, tree_key = TREE_NAME)
        out = {}
        refuse_link!(loader, 'loader balíka')
        raise Refused, "v balíku chýba #{LOADER_NAME}" unless File.file?(loader)

        out[LOADER_NAME] = { 'size' => File.size(loader), 'sha1' => digest_of(loader) }
        refuse_link!(tree_root, 'strom balíka')
        raise Refused, "v balíku chýba priečinok #{TREE_NAME}/" unless File.directory?(tree_root)

        collect_files(tree_root, tree_root, tree_key, out)
        out
      end

      def source_manifest(source_dir)
        m = manifest_of(File.join(source_dir, TREE_NAME), File.join(source_dir, LOADER_NAME))
        raise Refused, "balík má #{m.length} súborov (limit #{MAX_FILES})" if m.length > MAX_FILES

        total = m.values.sum { |v| v['size'].to_i }
        raise Refused, "balík má #{total} B (limit #{MAX_TOTAL_BYTES})" if total > MAX_TOTAL_BYTES

        m
      end

      def staged_manifest(plugins_dir)
        manifest_of(staged_tree(plugins_dir), staged_loader(plugins_dir))
      end

      # Cesta jedneho zaznamu manifestu v STAGING strome.
      def staged_path_for(plugins_dir, rel)
        safe_relative!(rel)
        return staged_loader(plugins_dir) if rel == LOADER_NAME

        rest = rel.sub(/\A#{Regexp.escape(TREE_NAME)}\//, '')
        raise Refused, "cesta mimo stromu balíka (#{rel})" if rest == rel

        File.join(staged_tree(plugins_dir), rest)
      end

      # --- staging + validacia ---------------------------------------------
      # Kopiruje sa VYHRADNE to, co je v manifeste. Subor, ktory v zdroji
      # pribudol POCAS kopirovania, sa teda do `.new` nedostane vobec; subor,
      # ktory sa POCAS kopirovania zmenil, sa dostane v novej podobe a validacia
      # ho zhodi na nesulade SHA1 — v oboch pripadoch koniec bez zmeny ciela.
      def stage!(source_dir, plugins_dir, manifest)
        cleanup_staging(plugins_dir)
        manifest.each_key do |rel|
          src = File.join(source_dir, rel)
          dst = staged_path_for(plugins_dir, rel)
          FileUtils.mkdir_p(File.dirname(dst))
          FileUtils.cp(src, dst)
        end
        true
      end

      # Dokaz, ze v `.new` lezi PRESNE balik zo zdroja — chybajuci, skrateny,
      # rovnako velky ale poskodeny aj NAVYSE pribudnuty subor je odmietnutie.
      def validate_staged!(plugins_dir, manifest)
        staged = staged_manifest(plugins_dir)
        missing = manifest.keys - staged.keys
        raise Refused, "v pripravenom balíku chýba #{missing.length} súborov (#{missing.first})" unless missing.empty?

        extra = staged.keys - manifest.keys
        raise Refused, "pripravený balík má súbory navyše (#{extra.first})" unless extra.empty?

        manifest.each do |rel, meta|
          got = staged[rel]
          if got['size'] != meta['size']
            raise Refused, "#{rel}: veľkosť #{got['size']} B namiesto #{meta['size']} B"
          end
          raise Refused, "#{rel}: obsah sa nezhoduje so zdrojom" if got['sha1'] != meta['sha1']
        end
        true
      end

      def cleanup_staging(plugins_dir)
        FileUtils.rm_rf(staged_tree(plugins_dir))
        FileUtils.rm_f(staged_loader(plugins_dir))
        true
      end

      # --- transakcny marker -------------------------------------------------
      # Atomicky zapis (tmp + rename v tom istom priecinku) — polovicny marker
      # by recovery pri boote precitala ako poskodenu a nevedela by, co robit.
      STATES = %w[staged tree_swapped loader_swapped done].freeze

      def write_marker!(plugins_dir, state, from: nil, to: nil)
        raise Refused, "neznámy stav aktualizácie (#{state})" unless STATES.include?(state.to_s)

        payload = {
          'std' => STD,
          'state' => state.to_s,
          'from' => from.to_s,
          'to' => to.to_s,
          'started_at' => (@started_at ||= Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')),
          'pid' => Process.pid
        }
        path = marker_path(plugins_dir)
        tmp = "#{path}.tmp-#{Process.pid}"
        File.open(tmp, 'wb') do |f|
          f.write(JSON.pretty_generate(payload))
          f.flush
          begin
            f.fsync
          rescue StandardError
            nil
          end
        end
        File.rename(tmp, path)
        payload
      ensure
        begin
          File.delete(tmp) if defined?(tmp) && tmp && File.exist?(tmp)
        rescue StandardError
          nil
        end
      end

      def read_marker(plugins_dir)
        path = marker_path(plugins_dir)
        return nil unless File.file?(path)

        JSON.parse(File.binread(path))
      rescue JSON::ParserError
        {} # poskodeny marker = „nieco tu bezalo" (recovery rozhoduje podla disku)
      end

      def clear_marker(plugins_dir)
        @started_at = nil
        FileUtils.rm_f(marker_path(plugins_dir))
        true
      end

      # --- update lock (B3) --------------------------------------------------
      # VLASTNY zamok, nie `materials.lock`: aktualizacia je DLHA operacia
      # (kopirovanie stovky suborov zo sietoveho share) a katalogovy zamok by
      # cely ten cas blokoval bezne ukony. Nezisany zamok = OKAMZITE odmietnutie
      # (`LOCK_NB`), nikdy cakanie — v UI vlakne by cakanie zmrazilo SketchUp.
      def with_update_lock(plugins_dir)
        FileUtils.mkdir_p(plugins_dir)
        File.open(lock_path(plugins_dir), File::RDWR | File::CREAT, 0o644) do |f|
          unless f.flock(File::LOCK_EX | File::LOCK_NB)
            raise Refused, 'aktualizácia už beží v inom procese'
          end

          begin
            yield
          ensure
            begin
              f.flock(File::LOCK_UN)
            rescue StandardError
              nil
            end
          end
        end
      end

      # --- procesny lease (B3) ----------------------------------------------
      # Kazdy proces pluginu si pri nacitani zapise `<pid>.lease`. Swap smie
      # bezat LEN vtedy, ked je ziva jedina instancia — ina instancia by po
      # renamovani pracovala nad zmiznutymi subormi.
      def lease_path(plugins_dir, pid = Process.pid)
        File.join(leases_dir(plugins_dir), "#{pid.to_i}.lease")
      end

      def write_lease!(plugins_dir, pid = Process.pid)
        dir = leases_dir(plugins_dir)
        FileUtils.mkdir_p(dir)
        File.binwrite(lease_path(plugins_dir, pid),
                      JSON.generate('std' => STD, 'pid' => pid.to_i,
                                    'at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')))
        true
      rescue StandardError => e
        Engine.log_error(e, 'Updater.write_lease!') if Engine.respond_to?(:log_error)
        false
      end

      def drop_lease!(plugins_dir, pid = Process.pid)
        FileUtils.rm_f(lease_path(plugins_dir, pid))
        true
      end

      def windows?
        RbConfig::CONFIG['host_os'].to_s =~ /mswin|mingw|cygwin/ ? true : false
      end

      # Zije PID? Na Windows to vie povedat len `tasklist` (Ruby `Process.kill(0)`
      # tam na cudzi proces nie je spolahlive). CSV format sa parsuje jednoznacne —
      # holy `include?(pid)` by sa trafil do stlpca s pamatou.
      def pid_alive?(pid)
        n = pid.to_i
        return false if n <= 0
        return true if n == Process.pid

        if windows?
          out = `tasklist /FI "PID eq #{n}" /NH /FO CSV 2>NUL`
          out.to_s.include?("\"#{n}\"")
        else
          begin
            Process.kill(0, n)
            true
          rescue Errno::ESRCH
            false
          rescue Errno::EPERM
            true # cudzi pouzivatel, ale ZIJE
          rescue StandardError
            false
          end
        end
      rescue StandardError
        # Neistota sa NEVYDAVA za „mrtvy" — swap radsej neprebehne.
        true
      end

      # Mrtve lease sa upracu, zive sa vratia. `self_pid` je NAS proces —
      # ten aktualizaciu prave robi a sam sebe neprekaza.
      def live_leases(plugins_dir, self_pid = Process.pid)
        dir = leases_dir(plugins_dir)
        return [] unless File.directory?(dir)

        live = []
        Dir.children(dir).sort.each do |name|
          next unless name =~ /\A(\d+)\.lease\z/

          pid = Regexp.last_match(1).to_i
          next if pid == self_pid.to_i

          if pid_alive?(pid)
            live << pid
          else
            begin
              FileUtils.rm_f(File.join(dir, name))
            rescue StandardError
              nil
            end
          end
        end
        live
      end

      # --- settings store (F11) ---------------------------------------------
      # Cesta k distribucnemu priecinku je nastavenie POCITACA (Michal a Lucia
      # maju kazdy svoj share), nie zakazky — zije v %APPDATA%, NIKDY v .skp.
      # Vlastny maly subor, NIE SupplierSettings (nepatri pod jeho revizny zamok).
      def dir
        return Materials.dir if defined?(Materials) && Materials.respond_to?(:dir)

        File.join(ENV['APPDATA'].to_s, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, SETTINGS_FILE)
      end

      def normalize_source(value)
        v = value.to_s.strip
        return '' if v.empty?

        v.tr('\\', '/').chomp('/')
      end

      def settings
        raw = JsonFileStore.available?(path) ? JsonFileStore.read(path) : nil
        src = raw.is_a?(Hash) ? raw['source_dir'] : nil
        { 'std' => STD, 'source_dir' => normalize_source(src) }
      rescue StandardError => e
        Engine.log_error(e, 'Updater.settings')
        { 'std' => STD, 'source_dir' => '' }
      end

      def source_dir
        settings['source_dir']
      end

      # Zlyhanie zapisu vracia NIL — volajuci to MUSI povedat nahlas (vzor
      # `DimSeries.set`). Zapis bezi pod tym istym medziprocesovym zamkom ako
      # ostatne katalogy priecinka (R-08) a nad DEGRADOVANYM suborom sa odmieta
      # (R-11): citanie zo `.bak` + zapis by cestu prepisali starsim obsahom.
      def set_source_dir(value)
        v = normalize_source(value)
        stored = with_catalog_lock do
          next false if degraded_write_blocked?

          JsonFileStore.write(path, 'std' => STD, 'source_dir' => v)
        end
        stored ? v : nil
      rescue StandardError => e
        Engine.log_error(e, 'Updater.set_source_dir')
        nil
      end

      def write_block_reason
        @write_block_reason.to_s
      end

      def degraded_write_blocked?
        prev = @write_block_reason
        @write_block_reason = ''
        return false unless JsonFileStore.degraded?(path)

        @write_block_reason = 'Nastavenie aktualizácie je poškodené — číta sa záloha, zápisy sú vypnuté ' \
                              "(oprav alebo zmaž súbor #{path})"
        if prev.to_s != @write_block_reason && defined?(Engine)
          Engine.log("updater: zapis odmietnuty — #{@write_block_reason}")
        end
        true
      end

      def with_catalog_lock(&blk)
        Materials.with_catalog_lock(&blk)
      end

      # --- kontrola verzie (synchronne jadro) -------------------------------
      # Cita VYHRADNE hlavicku `noxun_engine.rb` zo zdroja — jedno male citanie,
      # ziadne skenovanie stromu. Asynchronny obal s deadline je D-52b (F6).
      def check(source_dir_value, current_version)
        source = File.expand_path(source_dir_value.to_s)
        raise Refused, 'zdrojový priečinok nie je zadaný' if source_dir_value.to_s.strip.empty?
        raise Refused, "zdrojový priečinok neexistuje (#{source})" unless File.directory?(source)

        available = read_version(File.join(source, LOADER_NAME))
        state = classify(current_version, available)
        { 'ok' => true, 'state' => state.to_s, 'current' => current_version.to_s,
          'available' => available, 'reason' => '' }
      rescue Refused => e
        { 'ok' => false, 'state' => 'error', 'current' => current_version.to_s,
          'available' => '', 'reason' => e.message }
      rescue StandardError => e
        Engine.log_error(e, 'Updater.check')
        { 'ok' => false, 'state' => 'error', 'current' => current_version.to_s,
          'available' => '', 'reason' => "zdroj sa nepodarilo prečítať (#{e.class})" }
      end

      # --- samotna aktualizacia ---------------------------------------------
      # Vracia hash `{'ok' => true, 'from', 'to', 'note'}`; kazde odmietnutie je
      # `Refused` s dovodom a ciel ostava BYTE-IDENTICKY.
      def apply!(source_dir_value, plugin_dir)
        source, plugins, = check_boundaries!(source_dir_value, plugin_dir)

        with_update_lock(plugins) do
          if read_marker(plugins)
            raise Refused, 'predchádzajúca aktualizácia sa nedokončila — reštartuj SketchUp'
          end

          others = live_leases(plugins)
          unless others.empty?
            raise Refused, "beží ďalšia inštancia SketchUpu (PID #{others.join(', ')}) — zavri ostatné okná"
          end

          cleanup_staging(plugins) # zvysky po pade, ktory recovery uz vyriesila
          run_transaction!(source, plugins)
        end
      end

      # Telo transakcie — bezi VYHRADNE pod `with_update_lock`.
      def run_transaction!(source, plugins)
        current = read_version(loader_path(plugins))
        manifest = source_manifest(source)

        write_marker!(plugins, 'staged', from: current, to: nil)
        begin
          stage!(source, plugins, manifest)
          validate_staged!(plugins, manifest)

          # F8: verzia aj rozhodnutie „novsia" sa citaju zo STAGED stromu —
          # zdroj sa mohol medzitym zmenit a swapujeme to, co je v `.new`.
          target = read_version(staged_loader(plugins))
          staged_main = read_version(File.join(staged_tree(plugins), 'main.rb'))
          unless target == staged_main
            raise Refused, "balík je nekonzistentný: loader #{target} vs main.rb #{staged_main}"
          end

          state = classify(current, target)
          raise Refused, "v priečinku je rovnaká verzia (#{target})" if state == :same
          if state == :older
            raise Refused, "v priečinku je STARŠIA verzia (#{target} < #{current}) — " \
                           'downgrade je zakázaný, staršiu verziu nainštaluj ručne cez INSTALL'
          end

          write_marker!(plugins, 'staged', from: current, to: target)
        rescue StandardError
          cleanup_staging(plugins)
          clear_marker(plugins)
          raise
        end

        swap!(plugins, current, target)
      end

      # Kroky 3–6. Kazdy krok ma definovany rollback a ZIADNY z nich nesmie
      # nechat NOVY strom so STARYM loaderom.
      def swap!(plugins, from_version, to_version)
        tree = tree_path(plugins)
        tree_new = staged_tree(plugins)
        tree_old = previous_tree(plugins)
        loader = loader_path(plugins)
        loader_new = staged_loader(plugins)
        loader_old = previous_loader(plugins)

        FileUtils.rm_rf(tree_old)
        FileUtils.rm_f(loader_old)

        # (3) strom bokom
        begin
          File.rename(tree, tree_old)
        rescue StandardError => e
          cleanup_staging(plugins)
          clear_marker(plugins)
          raise Refused, "priečinok pluginu sa nedá presunúť (#{e.class}) — zavri SketchUp a skús znova"
        end

        # (4) novy strom na miesto
        begin
          File.rename(tree_new, tree)
        rescue StandardError => e
          begin
            File.rename(tree_old, tree)
          rescue StandardError
            nil
          end
          cleanup_staging(plugins)
          clear_marker(plugins)
          raise Refused, "nový priečinok pluginu sa nedá nasadiť (#{e.class}) — nič sa nezmenilo"
        end
        write_marker!(plugins, 'tree_swapped', from: from_version, to: to_version)

        # (5) loader — TIEZ cez staging; zlyhanie vracia CELY swap
        begin
          File.rename(loader, loader_old) if File.file?(loader)
          File.rename(loader_new, loader)
        rescue StandardError => e
          rollback_after_loader_failure!(plugins)
          raise Refused, "loader sa nedá vymeniť (#{e.class}) — pôvodná verzia beží ďalej"
        end
        write_marker!(plugins, 'loader_swapped', from: from_version, to: to_version)

        # (6) upratanie predchadzajucej generacie
        note = ''
        begin
          FileUtils.rm_rf(tree_old, secure: true)
          FileUtils.rm_f(loader_old)
          raise IOError, 'zvyšok sa nezmazal' if File.exist?(tree_old) || File.exist?(loader_old)
        rescue StandardError
          note = 'starú verziu sa nepodarilo zmazať — upratá sa pri najbližšom štarte SketchUpu'
        end

        write_marker!(plugins, 'done', from: from_version, to: to_version)
        clear_marker(plugins)
        Engine.restart_required!
        { 'ok' => true, 'from' => from_version, 'to' => to_version, 'note' => note }
      end

      # Krok 5 zlyhal: novy strom uz stoji na mieste, ale loader je stary.
      # Tento stav NESMIE prezit — vracia sa CELY swap.
      def rollback_after_loader_failure!(plugins)
        tree = tree_path(plugins)
        tree_new = staged_tree(plugins)
        tree_old = previous_tree(plugins)
        loader = loader_path(plugins)
        loader_old = previous_loader(plugins)

        begin
          File.rename(loader_old, loader) if File.file?(loader_old) && !File.file?(loader)
        rescue StandardError
          nil
        end
        begin
          File.rename(tree, tree_new) if File.directory?(tree) && !File.exist?(tree_new)
        rescue StandardError
          nil
        end
        begin
          File.rename(tree_old, tree) if File.directory?(tree_old) && !File.exist?(tree)
        rescue StandardError
          nil
        end
        cleanup_staging(plugins)
        FileUtils.rm_rf(tree_old)
        FileUtils.rm_f(loader_old)
        clear_marker(plugins)
        true
      end
    end
  end
end
