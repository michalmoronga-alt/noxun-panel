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
require 'open3'
require 'securerandom'

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
      @locked_announced = nil
      true
    end

    # Guard pre CALLBACKY UZ OTVORENEHO okna (Codex #277 kolo 4, P1).
    # `update_restart_pending?` chrani OTVARANIE; toto chrani okno, ktore v
    # case commitu uz bezalo — jeho stare handlery by inak mutovali model nad
    # NOVYM balikom. Hlaska ide RAZ ZA OKNO (`tag`), nie pri kazdom callbacku:
    # panel ich posiela desiatky za sekundu a rad modalov by SketchUp zablokoval.
    CB_LOCKED_MESSAGE = 'Noxun Engine bol aktualizovaný — zatvor okno a reštartuj SketchUp.'

    def self.update_locked?(tag)
      return false unless restart_required?

      @locked_announced ||= {}
      unless @locked_announced[tag]
        @locked_announced[tag] = true
        begin
          ::UI.messagebox(CB_LOCKED_MESSAGE) if defined?(::UI) && ::UI.respond_to?(:messagebox)
        rescue StandardError
          nil
        end
      end
      true
    end

    # Best-effort zatvorenie okien po commite. UPLNA bariera (zavriet okna
    # PRED swapom a pockat na `set_on_closed`) je scope D-52b — tu ide len
    # o to, aby okna nezostali visiet nad vymenenym balikom. Vynimky sa
    # prehltnu: aktualizacia UZ presla a zlyhane zatvorenie z nej nesmie
    # spravit neuspech (latch drzi vstupy aj tak).
    def self.close_all_dialogs
      [defined?(Panel) ? Panel : nil, defined?(StudioDialog) ? StudioDialog : nil].compact.each do |mod|
        begin
          mod.hide if mod.respond_to?(:hide)
        rescue StandardError
          nil
        end
      end
      true
    rescue StandardError
      true
    end

    # D-52b2 (Codex #278 kolo 3, P1): KYM AKTUALIZACIA BEZI, sa okna NESMU
    # otvarat. Latch (`restart_required?`) zapina az COMMIT — priprava balika
    # zo sietoveho share pritom trva desiatky sekund a v tom case je este
    # vypnuty. Pouzivatel by si stihol otvorit Inspector z toolbaru a commit
    # by bezal s CEF drziacim subory z `ui/` — presne to, comu bariera
    # predchadza. Priznak vlastni UI vrstva (`SupplierSettingsDialog`), tu je
    # len jeho citanie a natívna hlaska.
    APPLY_IN_PROGRESS_MESSAGE = 'Prebieha aktualizácia Noxun Engine — počkaj na jej výsledok. ' \
                                'Okná pluginu sa medzitým neotvárajú (inak by ich SketchUp držal ' \
                                'otvorené a výmena súborov by zlyhala).'

    def self.update_in_progress?
      return false unless defined?(SupplierSettingsDialog) &&
                          SupplierSettingsDialog.respond_to?(:updater_apply_inflight?)
      return false unless SupplierSettingsDialog.updater_apply_inflight?

      begin
        ::UI.messagebox(APPLY_IN_PROGRESS_MESSAGE) if defined?(::UI) && ::UI.respond_to?(:messagebox)
      rescue StandardError
        nil # hlaska nesmie prebit samotne odmietnutie
      end
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
      # Image name ziveho procesu pluginu (case-insensitive podretazec).
      LEASE_IMAGE_HINT = 'sketchup'

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

      # Lacne citanie hlavicky staci na KONTROLU verzie (jedno male citanie zo
      # sietoveho share). Pred COMMITOM to nestaci: druha definicia `VERSION`
      # moze lezat az za hranicou hlavicky a v Ruby by prebila prvu, takze by
      # sa nasadil balik s inou verziou, nez akou sa rozhodovalo. Preto sa tu
      # skenuje CELY subor (Codex #277 P2).
      def assert_single_version!(path, label)
        raise Refused, "súbor #{File.basename(path)} chýba" unless File.file?(path)

        text = File.binread(path).force_encoding(Encoding::UTF_8)
        hits = text.scan(VERSION_RE).flatten
        raise Refused, "#{label}: v súbore nie je VERSION" if hits.empty?
        raise Refused, "#{label}: VERSION je v súbore #{hits.length}× — balík je nejednoznačný" if hits.length > 1

        value = hits.first.to_s.strip
        raise Refused, "#{label}: neplatná VERSION #{value.inspect}" unless value =~ VALID_VERSION_RE

        value
      end

      # --- kanonicke hranice (F9) -------------------------------------------
      # Codex #277 kolo 4 (P2): koncove lomitko sa strihá LEN ked cesta nie je
      # KOREN. `chomp('/')` nad korenom da nepouzitelny vysledok — `/` -> ``
      # (prazdna cesta), `G:/` -> `G:` (na Windows to znamena „aktualny
      # priecinok na disku G", nie koren disku) a `//server/share` -> UNC koren
      # bez zdielania. Vsetky tri sa mozu objavit ako ciel `Engine.plugin_dir`
      # na sietovej instalacii.
      ROOT_PATH_RE = %r{\A(?:/|[A-Za-z]:/|//[^/]+/[^/]+)\z}.freeze

      def normalize_path(path)
        p = File.expand_path(path.to_s).tr('\\', '/')
        return p if p =~ ROOT_PATH_RE

        p.chomp('/')
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
      STATES = %w[staged tree_swapped loader_copied loader_swapped done].freeze

      def write_marker!(plugins_dir, state, from: nil, to: nil)
        raise Refused, "neznámy stav aktualizácie (#{state})" unless STATES.include?(state.to_s)

        payload = {
          'std' => STD,
          'state' => state.to_s,
          'from' => from.to_s,
          'to' => to.to_s,
          'started_at' => (@started_at ||= Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')),
          # NONCE = identita KONKRETNEJ pripravy (Codex #278/b1 P2). Dvojica
          # (pid, `started_at`) nestaci: peciatka ma sekundove rozlisenie, takze
          # dve pripravy v tej istej sekunde nad tymi istymi verziami by mali
          # ROVNAKY „podpis" a oneskoreny `commit!` prveho tiketu by presiel
          # proti markeru toho DRUHEHO. Nonce zije po cely cas transakcie
          # (marker sa v nej prepisuje viackrat) a zanika s `clear_marker`.
          'nonce' => (@nonce ||= SecureRandom.hex(8)),
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

      # Codex #277 kolo 4 (P2): `rm_f` chybu POTLACI, takze „zmazane" sa nedalo
      # odlisit od „ostalo lezat". Marker, ktory prezil, pritom pri najblizsom
      # `apply!` zablokuje aktualizaciu hlaskou o nedokoncenej transakcii.
      # Vysledok sa preto OVERUJE na disku a volajuci sa o nom dozvie.
      def clear_marker(plugins_dir)
        @started_at = nil
        @nonce = nil
        begin
          FileUtils.rm_f(marker_path(plugins_dir))
        rescue StandardError => e
          Engine.log_error(e, 'Updater.clear_marker') if Engine.respond_to?(:log_error)
        end
        !File.exist?(marker_path(plugins_dir))
      end

      # D-52b (P3 z delta-verifikacie #277): USPESNA cesta vysledok
      # `clear_marker` uz priznavala (`state` = `cleanup_pending`), ODMIETACIA
      # a ROLLBACKOVA nie — tam sa navratova hodnota zahadzovala. Marker, ktory
      # prezije, je pritom TRVALA BRZDA: kazdy dalsi `apply!` sa o neho zastavi
      # hlaskou „predchádzajúca aktualizácia sa nedokončila" a pouzivatel by
      # netusil, odkial sa vzala. Poznamka sa preto pripaja do KAZDEJ `Refused`
      # spravy, ktora vznikla na ceste mazajucej marker.
      MARKER_STUCK_NOTE = ' (pozn.: stopa po pokuse — súbor noxun_engine.update.json ' \
                          'v priečinku Plugins — sa nedala zmazať; ďalšia aktualizácia sa ' \
                          'o ňu zastaví, kým ju nezmažeš alebo nereštartuješ SketchUp)'

      def marker_note(cleared)
        cleared ? '' : MARKER_STUCK_NOTE
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

      # Lease nesie aj IDENTITU procesu (Codex #277 kolo 3, P2): samotny PID
      # nestaci — po ukonceni SketchUpu ho OS pridelí inemu programu a mrtva
      # stopa by aktualizaciu blokovala klamlivou hlaskou „zavri ostatne okna".
      # `exe` je image name pri zapise, `started_at` cas vzniku stopy.
      def current_image_name
        File.basename(Process.argv0.to_s)
      rescue StandardError
        ''
      end

      def write_lease!(plugins_dir, pid = Process.pid, exe = current_image_name)
        dir = leases_dir(plugins_dir)
        FileUtils.mkdir_p(dir)
        now = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
        File.binwrite(lease_path(plugins_dir, pid),
                      JSON.generate('std' => STD, 'pid' => pid.to_i, 'exe' => exe.to_s,
                                    'started_at' => now, 'at' => now))
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

      # Image name procesu s danym PID:
      #   String  — proces zije a takto sa vola jeho program,
      #   nil     — proces NEZIJE,
      #   :unknown — beziaci system to nevie povedat (mimo Windows).
      # Ked sa dotaz NEPODARI vykonat, vyleti `Refused` — fail-closed z kola 2:
      # nezistitelny stav nie je „nikto nebezi".
      def process_image(pid)
        n = pid.to_i
        return nil if n <= 0

        unless windows?
          begin
            Process.kill(0, n)
            return :unknown # POSIX: proces zije, meno programu nezistujeme
          rescue Errno::ESRCH
            return nil
          rescue Errno::EPERM
            return :unknown # cudzi pouzivatel, ale ZIJE
          rescue StandardError => e
            raise Refused, "stav procesu #{n} sa nedá zistiť (#{e.class})"
          end
        end

        # Codex #277 kolo 4 (P2): kontroluje sa EXIT STATUS. Zlyhany `tasklist`
        # (chybajuci nastroj, obmedzene prava, zahlteny system) vracia prazdny
        # vystup — a ten by sa bez tejto kontroly precital ako „PID nezije",
        # takze by sa ZMAZALA stopa ZIVEJ instancie a swap by bezal pod nou.
        out, status = begin
          Open3.capture2e('tasklist', '/FI', "PID eq #{n}", '/NH', '/FO', 'CSV')
        rescue StandardError => e
          raise Refused, "`tasklist` sa nedá spustiť (#{e.class}) — nedá sa zistiť, " \
                         'či nebeží ďalšia inštancia SketchUpu'
        end
        unless status.respond_to?(:success?) && status.success?
          raise Refused, '`tasklist` skončil chybou — nedá sa zistiť, či nebeží ' \
                         'ďalšia inštancia SketchUpu'
        end

        # `tasklist` pise v KONZOLOVEJ kodovej stranke (na SK Windows CP852),
        # nie v UTF-8 — regex nad takym retazcom by hodil „invalid byte
        # sequence". Parsuje sa preto BINARNE a vysledok sa az potom ocisti.
        raw = out.to_s.dup.force_encoding(Encoding::BINARY)
        row = raw.lines.find { |l| l.include?("\"#{n}\"") }
        return row[/\A"([^"]*)"/, 1].to_s.force_encoding(Encoding::UTF_8).scrub if row

        # Ziadny riadok pre nas PID. Jedina PLATNA podoba tejto odpovede je
        # informacna hlaska bez CSV riadkov (lokalizovana, preto sa na jej
        # ZNENIE nespoliehame). Prazdny alebo inak vyzerajuci vystup je
        # NEZROZUMITELNY — a nezrozumitelny vystup nie je „mrtvy PID".
        raise Refused, '`tasklist` nevrátil žiadnu odpoveď — nedá sa zistiť, či nebeží ' \
                       'ďalšia inštancia SketchUpu' if raw.strip.empty?
        raise Refused, '`tasklist` vrátil odpoveď, ktorej nerozumieme — nedá sa zistiť, ' \
                       'či nebeží ďalšia inštancia SketchUpu' if raw.lines.any? { |l| l.start_with?('"') }

        nil # informacna hlaska = proces NEZIJE
      end

      # Patri PID STALE tomu procesu, ktory si stopu zapisal?
      #
      # Codex #277 kolo 3 (P2): po ukonceni SketchUpu stopa na disku ostane a OS
      # ten PID casom pridelí uplne inemu programu. Bez kontroly identity by
      # `chrome.exe` s recyklovanym cislom navzdy zablokoval aktualizaciu
      # hlaskou „zavri ostatne okna SketchUpu". Preto musi image name
      #   (a) sediet s tym, co je v stope (ked ho stopa nesie), A ZAROVEN
      #   (b) byt instancia SketchUpu.
      # Mimo Windows sa image name zistit neda — tam rozhoduje samotna zivost
      # (produkcia bezi vyhradne na Windows, headless CI je Linux).
      def lease_alive?(pid, recorded_exe = nil)
        n = pid.to_i
        return false if n <= 0
        return true if n == Process.pid

        image = process_image(n)
        return false if image.nil? # proces nezije
        return true if image == :unknown

        name = image.to_s.strip.downcase
        want = recorded_exe.to_s.strip.downcase
        return false unless want.empty? || want == name

        name.include?(LEASE_IMAGE_HINT)
      end

      # Mrtve lease sa upracu, zive sa vratia. `self_pid` je NAS proces —
      # ten aktualizaciu prave robi a sam sebe neprekaza.
      # `exe` zo stopy. Poskodena alebo stara stopa (bez pola) vrati prazdny
      # retazec — kontrola identity sa vtedy opiera len o to, ze PID patri
      # instancii SketchUpu.
      def recorded_exe(lease_file)
        raw = JSON.parse(File.binread(lease_file))
        raw.is_a?(Hash) ? raw['exe'].to_s : ''
      rescue StandardError
        ''
      end

      # FAIL-CLOSED (Codex #277 kolo 2, P2): nezistitelny stav lease NIE JE
      # „nikto nebezi". Chybajuci alebo necitatelny priecinok znamena, ze o inych
      # instanciach nevieme NIC — a swap pod cudzou instanciou je presne to, comu
      # lease brani. Preto sa vyhodi `Refused` a `apply!` skonci odmietnutim.
      # (Kazda ziva instancia si lease zapisuje uz v LOADERI, este pred nacitanim
      # stromu, takze v realnej instalacii priecinok VZDY existuje.)
      def live_leases(plugins_dir, self_pid = Process.pid)
        dir = leases_dir(plugins_dir)
        if File.exist?(dir) && !File.directory?(dir)
          raise Refused, "#{LEASES_DIR} v Plugins nie je priečinok — nedá sa zistiť, či nebeží " \
                         'ďalšia inštancia SketchUpu (zmaž ten súbor a reštartuj SketchUp)'
        end
        unless File.directory?(dir)
          raise Refused, "v Plugins chýba priečinok #{LEASES_DIR} — nedá sa zistiť, či nebeží " \
                         'ďalšia inštancia SketchUpu (reštartuj SketchUp)'
        end

        live = []
        entries = begin
          Dir.children(dir)
        rescue StandardError => e
          raise Refused, "priečinok #{LEASES_DIR} sa nedá prečítať (#{e.class}) — " \
                         'nedá sa zistiť, či nebeží ďalšia inštancia SketchUpu'
        end
        entries.sort.each do |name|
          next unless name =~ /\A(\d+)\.lease\z/

          pid = Regexp.last_match(1).to_i
          next if pid == self_pid.to_i

          if lease_alive?(pid, recorded_exe(File.join(dir, name)))
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

      # Codex #278 kolo 3 (P2): koncove lomitko sa strihá LEN tam, kde nejde
      # o KOREN — presne ako v `normalize_path`. `chomp('/')` nad korenom dava
      # nepouzitelnu cestu (`/` -> prazdna, `D:/` -> „aktualny priecinok na
      # disku D", `//server/share` -> UNC koren bez zdielania) a vsetky tri sa
      # daju do pola distribucneho priecinka realne napisat.
      def normalize_source(value)
        v = value.to_s.strip
        return '' if v.empty?

        p = v.tr('\\', '/')
        return p if p =~ ROOT_PATH_RE

        p.chomp('/')
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

      # --- samotna aktualizacia (DVE FAZY) -----------------------------------
      #
      # D-52b (Codex #278 kolo 2, P1): `apply!` robil VSETKO v jednom volani —
      # vratane manifestu a KOPIROVANIA celeho balika zo (sietoveho) zdroja.
      # V UI vrstve to bezalo v hlavnom vlakne, takze visiaci UNC share zamrazil
      # SketchUp na desiatky sekund. Preto su fazy dve:
      #
      #   `prepare!` — VSETKO blokujuce I/O nad ZDROJOM (manifest, staging do
      #                `.new`, validacia, rozhodnutie o verzii). Je WORKER-SAFE:
      #                ziadne `Sketchup.*`, ziadne `UI.*` a ZIVEJ generacie sa
      #                nedotyka — meni sa vyhradne `.new`. Vracia TIKET.
      #   `commit!`  — LEN renamey v `Plugins` (lokalne, rychle) + latch. Bezi
      #                VYHRADNE v hlavnom vlakne.
      #
      # Medzi fazami sa zamok PUSTA a mutualnu exkluziu drzi MARKER: kazdy iny
      # proces (aj druhy pokus) sa o neho zastavi. `commit!` preto overi, ze
      # marker na disku je NAS (pid + `started_at` + obe verzie) — inak odmietne
      # a nic nesahne. Kto `prepare!` nedokonci commitom, MUSI zavolat
      # `abort_prepared!` (UI to robi na deadline aj pri nezhode verzie).
      #
      # `apply!` ostava ako jednoduchy obal (headless sada aj in-SU sekcia ho
      # pouzivaju) — je to presne `prepare!` + `commit!`.
      def apply!(source_dir_value, plugin_dir)
        commit!(prepare!(source_dir_value, plugin_dir))
      end

      # FAZA 1 — bezpecna vo vlakne. Vracia tiket pre `commit!`.
      def prepare!(source_dir_value, plugin_dir)
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
          stage_transaction!(source, plugins)
        end
      end

      # Telo pripravy — bezi VYHRADNE pod `with_update_lock`.
      def stage_transaction!(source, plugins)
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

          # P2 (#277): duplicitna VERSION sa v hlavicke (4 kB) najst NEMUSI —
          # druha definicia moze lezat hlbsie a prebila by prvu. Tesne pred
          # commitom sa preto skenuje CELY staged loader aj `main.rb`.
          assert_single_version!(staged_loader(plugins), 'loader balíka')
          assert_single_version!(File.join(staged_tree(plugins), 'main.rb'), 'main.rb balíka')

          # P1 (#277): lease sa kontroluje ZNOVA, tesne pred swapom. Medzi
          # prvou kontrolou a koncom stagingu (kopirovanie zo share trva) mohla
          # nabehnut dalsia instancia SketchUpu — renamovat strom pod nou by jej
          # zobralo subory spod ruk. (Druhy raz to robi `commit!`, lebo medzi
          # fazami moze ubehnut cas.)
          late = live_leases(plugins)
          unless late.empty?
            raise Refused, "medzitým sa spustila ďalšia inštancia SketchUpu (PID #{late.join(', ')}) — " \
                           'zavri ostatné okná a skús znova'
          end

          payload = write_marker!(plugins, 'staged', from: current, to: target)
          { 'plugins' => plugins, 'source' => source, 'from' => current, 'to' => target,
            'pid' => payload['pid'], 'stamp' => payload['started_at'],
            'nonce' => payload['nonce'] }
        rescue StandardError => e
          cleanup_staging(plugins)
          # D-52b (P3 #277): ked marker prezije, pouzivatel to musi vediet UZ
          # TERAZ — inak sa o nom dozvie az z nasledujuceho pokusu, ktory sa
          # o neho zastavi celkom inou hlaskou.
          note = marker_note(clear_marker(plugins))
          raise if note.empty?

          raise Refused, "#{e.message}#{note}"
        end
      end

      # FAZA 2 — LEN renamey (lokalne, rychle). Hlavne vlakno.
      def commit!(ticket)
        t = ticket.is_a?(Hash) ? ticket : {}
        plugins = t['plugins'].to_s
        raise Refused, 'aktualizácia nie je pripravená' if plugins.empty?

        with_update_lock(plugins) do
          # Marker je JEDINY doklad o tom, ze `.new` v priecinku je NAS. Ked
          # nesedi (cudzi proces, iny pokus, medzitym upratane), NIC sa nedeje —
          # cudzie artefakty sa nemazu.
          unless own_prepared_marker?(read_marker(plugins), t)
            raise Refused, 'pripravená aktualizácia už neplatí — skús znova'
          end

          unless Dir.exist?(staged_tree(plugins)) && File.file?(staged_loader(plugins))
            note = marker_note(clear_marker(plugins))
            raise Refused, "pripravený balík už v Plugins nie je — skús znova#{note}"
          end

          late = live_leases(plugins)
          unless late.empty?
            cleanup_staging(plugins)
            note = marker_note(clear_marker(plugins))
            raise Refused, "medzitým sa spustila ďalšia inštancia SketchUpu (PID #{late.join(', ')}) — " \
                           "zavri ostatné okná a skús znova#{note}"
          end

          swap!(plugins, t['from'], t['to'])
        end
      end

      # Zrusenie PRIPRAVENEJ aktualizacie (deadline, nezhoda verzie). Uprace
      # `.new` aj marker — ale LEN ked su NASE. Vracia `true` pri upratani.
      def abort_prepared!(ticket)
        t = ticket.is_a?(Hash) ? ticket : {}
        plugins = t['plugins'].to_s
        return false if plugins.empty?

        with_update_lock(plugins) do
          next false unless own_prepared_marker?(read_marker(plugins), t)

          cleanup_staging(plugins)
          clear_marker(plugins)
        end
      rescue StandardError => e
        Engine.log_error(e, 'Updater.abort_prepared!') if Engine.respond_to?(:log_error)
        false
      end

      # Marker patri TEJTO pripravenej transakcii? Rozhoduje NONCE — identita
      # konkretnej pripravy. Pid, peciatka aj obe verzie ostavaju ako doplnkova
      # kontrola, ale samy o sebe NESTACIA: peciatka ma sekundove rozlisenie,
      # takze dve pripravy v tej istej sekunde nad tymi istymi verziami by boli
      # nerozoznatelne a oneskoreny `commit!` prveho tiketu by nasadil balik
      # toho druheho (Codex #278/b1 P2).
      def own_prepared_marker?(marker, ticket)
        return false unless marker.is_a?(Hash) && ticket.is_a?(Hash)
        return false if ticket['nonce'].to_s.empty?

        marker['nonce'].to_s == ticket['nonce'].to_s &&
          marker['state'].to_s == 'staged' &&
          marker['pid'].to_i == Process.pid &&
          !ticket['stamp'].to_s.empty? &&
          marker['started_at'].to_s == ticket['stamp'].to_s &&
          marker['from'].to_s == ticket['from'].to_s &&
          marker['to'].to_s == ticket['to'].to_s
      end

      # Kroky 3–6.
      #
      # JEDNO PRAVIDLO PRE CELY SWAP (Codex #277 kolo 2): od okamihu, kedy
      # USPEJE prvy rename kroku 3 (`noxun_engine` -> `.old`), plati BUD
      #   (A) PLNY ROLLBACK OVERENY NA DISKU — zivy strom aj loader su spat,
      #       artefakty upratane, marker zmazany, ziadny latch; ALEBO
      #   (B) LATCH + ZACHOVANE ARTEFAKTY (`.new`, `.old`) + ZACHOVANY MARKER
      #       a chyba s presnym stavom, ktoru dorovna boot recovery.
      # TRETIA MOZNOST NEEXISTUJE. Kazda chybova cesta za krokom 3 preto konci
      # v `abort_after_move!` — nikde inde sa `raise` nepise (strazi guard test).
      def swap!(plugins, from_version, to_version)
        tree = tree_path(plugins)
        tree_new = staged_tree(plugins)
        loader = loader_path(plugins)
        loader_new = staged_loader(plugins)
        loader_old = previous_loader(plugins)

        # Zvysky predchadzajucej generacie sa upratuju LEN kym je zivy strom na
        # mieste (viac v `discard_previous!`).
        discard_previous!(plugins)

        # (3) strom bokom — POSLEDNY krok, po ktorom je este mozne skoncit
        # uplne bez stopy.
        begin
          File.rename(tree, previous_tree(plugins))
        rescue StandardError => e
          cleanup_staging(plugins)
          note = marker_note(clear_marker(plugins)) # D-52b (P3 #277)
          raise Refused, "priečinok pluginu sa nedá presunúť (#{e.class}) — " \
                         "zavri SketchUp a skús znova#{note}"
        end

        # ----- OD TEJTO CHVILE PLATI PRAVIDLO (A) ALEBO (B) -----------------

        # (4) novy strom na miesto
        begin
          File.rename(tree_new, tree)
        rescue StandardError => e
          abort_after_move!(plugins, "nový priečinok pluginu sa nedá nasadiť (#{e.class})")
        end

        # Marker po kroku 4. Zlyhanie zapisu (plny disk, prava, antivirus) je
        # rovnako vazne ako zlyhanie renameu: bez markera by po pade nikto
        # nevedel, ze transakcia bezala — a hlavne by vynimka utiekla so ZIVYM
        # NOVYM stromom a VYPNUTYM latchom.
        begin
          write_marker!(plugins, 'tree_swapped', from: from_version, to: to_version)
        rescue StandardError => e
          abort_after_move!(plugins, "stav aktualizácie sa nedá zapísať (#{e.class})")
        end

        # (5a) ZALOHA LOADERA = KOPIA, nie rename (Codex #277 kolo 3, P1).
        # Rename by na okamih nechal `Plugins` BEZ `noxun_engine.rb` — a prave
        # v tom okne nema SketchUp co spustit, takze by nikdy nenabehla ani
        # recovery a plugin by ostal mrtvy az do reinstalu. Kopia stary loader
        # nechava na mieste, takze bootovatelny je v KAZDOM okamihu.
        begin
          copy_file!(loader, loader_old)
        rescue StandardError => e
          abort_after_move!(plugins, "zálohu loadera sa nedá vytvoriť (#{e.class})")
        end
        begin
          write_marker!(plugins, 'loader_copied', from: from_version, to: to_version)
        rescue StandardError => e
          abort_after_move!(plugins, "stav aktualizácie sa nedá zapísať (#{e.class})")
        end

        # (5b) JEDINY atomicky krok: `File.rename` PREPISE existujuci ciel
        # (Windows MoveFileExW s MOVEFILE_REPLACE_EXISTING, POSIX rename(2)).
        # Ked zlyha, stary `.rb` ostava NEDOTKNUTY a plati pravidlo po kroku 3.
        begin
          File.rename(loader_new, loader)
        rescue StandardError => e
          abort_after_move!(plugins, "loader sa nedá vymeniť (#{e.class})")
        end

        # COMMIT BOD: od tejto chvile lezi v `Plugins` NOVA generacia a v pamati
        # bezi STARY Ruby kod. Latch sa preto zapina OKAMZITE — vsetko dalsie je
        # uz len upratovanie a nesmie rozhodovat o tom, ci sa vstupne body
        # zamknu (vynimka v upratovani by inak nechala okna otvorene nad novymi
        # subormi).
        Engine.restart_required!
        # Okna, ktore bezali v case commitu, uz drzi latch v `cb` wrapperoch;
        # tu sa este best-effort zavru, nech nad vymenenym balikom nevisia.
        Engine.close_all_dialogs

        # (6) upratanie predchadzajucej generacie
        note = ''
        state = 'done'
        begin
          write_marker!(plugins, 'loader_swapped', from: from_version, to: to_version)
          unless discard_previous!(plugins)
            note = 'starú verziu sa nepodarilo zmazať — upratá sa pri najbližšom štarte SketchUpu'
          end
          write_marker!(plugins, 'done', from: from_version, to: to_version)
          unless clear_marker(plugins)
            state = 'cleanup_pending'
            note = 'aktualizácia prebehla, ale stopu po nej sa nepodarilo zmazať ' \
                   '(marker noxun_engine.update.json) — po reštarte sa upratá; ak nie, oprav práva ' \
                   'k priečinku Plugins'
          end
        rescue StandardError => e
          # Aktualizacia UZ PRESLA — chyba v upratovani z nej nesmie spravit
          # neuspech (volajuci by hlasil zlyhanie updatu, ktory sa NAOZAJ stal).
          Engine.log_error(e, 'Updater.swap! upratanie') if Engine.respond_to?(:log_error)
          note = 'aktualizácia prebehla, upratanie sa nedokončilo — dorovná sa pri najbližšom štarte SketchUpu'
        end
        { 'ok' => true, 'state' => state, 'from' => from_version, 'to' => to_version, 'note' => note }
      end

      # JEDINY vychod z chyby za krokom 3. Bud vrati predchadzajucu generaciu
      # (a je to cisty neuspech), alebo zapne latch, NECHA vsetky artefakty
      # a povie presny stav. Vzdy vyhadzuje `Refused`.
      #
      # Latch sa pri USPESNOM rollbacku ZAMERNE NEZAPINA: na disku je presne to,
      # co tam bolo pred pokusom, ziadne nove subory sa nikam nenacitali a
      # zbytocny latch by pouzivatelovi zamkol plugin po chybe, ktora ho nijako
      # nepoznacila.
      def abort_after_move!(plugins, reason)
        if restore_previous_generation!(plugins)
          # D-52b (P3 #277): rollback vratil generaciu, ale marker po nom mohol
          # ostat lezat (`clear_marker` vnutri `restore_previous_generation!`).
          # Stav sa cita z DISKU — inak by hlaska tvrdila „nič sa nezmenilo"
          # nad brzdou, ktora zastavi kazdy dalsi pokus.
          note = marker_note(!File.exist?(marker_path(plugins)))
          raise Refused, "#{reason} — nič sa nezmenilo, pôvodná verzia beží ďalej#{note}"
        end

        # Rollback ZLYHAL: marker, `.new` ani `.old` sa NESMU mazat — su to
        # jedine stopy, z ktorych vie boot recovery zlozit kompletnu generaciu.
        Engine.restart_required!
        # Recovery bootstrap zije v LOADERI — ked ten na disku nie je, boot ju
        # nema odkial spustit a hlaska „restartuj" by klamala.
        if File.file?(loader_path(plugins))
          raise Refused, "#{reason} a vrátenie zmien zlyhalo — REŠTARTUJ SketchUp, " \
                         'plugin sa dorovná pri štarte'
        end

        raise Refused, "#{reason} a vrátenie zmien zlyhalo — v Plugins chýba noxun_engine.rb, " \
                       'spusti INSTALL_noxun_engine.ps1'
      end

      # Vrati predchadzajucu generaciu (strom AJ loader). `true` LEN vtedy, ked
      # KAZDY krok uspel a DISK to potvrdzuje — navratove hodnoty renameov samy
      # o sebe nestacia.
      def restore_previous_generation!(plugins)
        tree = tree_path(plugins)
        tree_new = staged_tree(plugins)
        tree_old = previous_tree(plugins)
        loader = loader_path(plugins)
        loader_old = previous_loader(plugins)

        ok = true
        ok = try_rename(loader_old, loader) if File.file?(loader_old) && !File.file?(loader)
        ok &&= try_rename(tree, tree_new) if ok && Dir.exist?(tree) && !File.exist?(tree_new)
        ok &&= try_rename(tree_old, tree) if ok && Dir.exist?(tree_old) && !Dir.exist?(tree)

        ok &&= File.file?(loader) && Dir.exist?(tree)
        return false unless ok

        cleanup_staging(plugins)
        discard_previous!(plugins)
        clear_marker(plugins)
        true
      end

      # JEDINE miesto, kde sa maze predchadzajuca generacia (`.old`).
      #
      # GUARD (Codex #277 kolo 2): `.old` je posledna KOMPLETNA kopia pluginu,
      # takze sa nikdy nesmie zmazat, kym na svojom mieste nestoji zivy strom AJ
      # loader. Bez tejto poistky by opakovany pokus o aktualizaciu po zlyhanom
      # kroku 4 zmazal jediny strom, ktory na disku ostal.
      # Vracia `true`, ked po nom uz ziadny `.old` zvysok nie je.
      def discard_previous!(plugins)
        return false unless Dir.exist?(tree_path(plugins)) && File.file?(loader_path(plugins))

        tree_old = previous_tree(plugins)
        loader_old = previous_loader(plugins)
        begin
          FileUtils.rm_rf(tree_old, secure: true)
          FileUtils.rm_f(loader_old)
        rescue StandardError => e
          Engine.log_error(e, 'Updater.discard_previous!') if Engine.respond_to?(:log_error)
        end
        !File.exist?(tree_old) && !File.exist?(loader_old)
      end

      # Zaloha KOPIOU (Codex #277 kolo 3): zdroj ostava na mieste, takze
      # `Plugins` nie su ani na okamih bez bootovatelneho `noxun_engine.rb`.
      # Kopiruje sa cez BOKOVY subor a az potom sa premenuje — polovicna zaloha
      # by pri recovery vyzerala ako platna generacia. Zapis sa fsyncuje: po
      # pade musi byt na disku bud cela zaloha, alebo ziadna.
      def copy_file!(src, dst)
        tmp = "#{dst}.tmp-#{Process.pid}"
        FileUtils.rm_f(tmp)
        begin
          data = File.binread(src)
          File.open(tmp, 'wb') do |f|
            f.write(data)
            f.flush
            begin
              f.fsync
            rescue StandardError
              nil
            end
          end
          FileUtils.rm_f(dst)
          File.rename(tmp, dst)
          raise IOError, "zaloha #{File.basename(dst)} nevznikla" unless File.file?(dst)
          unless File.size(dst) == data.bytesize
            raise IOError, "zaloha #{File.basename(dst)} je neuplna"
          end

          true
        ensure
          FileUtils.rm_f(tmp)
        end
      end

      def try_rename(src, dst)
        File.rename(src, dst)
        true
      rescue StandardError => e
        Engine.log_error(e, 'Updater rollback') if Engine.respond_to?(:log_error)
        false
      end
    end
  end
end
