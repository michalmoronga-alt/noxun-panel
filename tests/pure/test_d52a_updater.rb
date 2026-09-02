# frozen_string_literal: true
# Testy D-52a: JADRO AKTUALIZATORA PLUGINU (`core/updater.rb` + recovery
# bootstrap v loaderi `noxun_engine.rb`).
#
# CO SA DOKAZUJE:
#   * porovnanie verzii je CISELNE (`0.9.9 < 0.10.0`), chybajuca/neplatna/
#     duplicitna VERSION je CHYBA, nie „nejaka hodnota";
#   * manifest (SHA1 + velkost) chyti KAZDY rozdiel medzi zdrojom a staged
#     stromom — chybajuci, skrateny, ROVNAKO VELKY ale poskodeny aj subor
#     NAVYSE; zdroj zmeneny POCAS kopirovania konci odmietnutim;
#   * kanonicke hranice odmietnu zdroj == ciel, zdroj vnutri ciela, `.new/.old`
#     a symlink/junction;
#   * zlyhanie KTOREHOKOLVEK z krokov 3–5 necha ciel BYTE-IDENTICKY (strom AJ
#     loader), zlyhanie mazania `.old` je USPECH s poznamkou;
#   * SIMULOVANY PAD po kazdej hranici (staged / tree_swapped / loader_swapped /
#     pred cleanupom) skonci pri DALSOM BOOTE jednou KOMPLETNOU generaciou —
#     boot je skutocne nacitanie loadera v samostatnom Ruby procese;
#   * dva OS procesy: druhy dostane odmietnutie OKAMZITE (LOCK_NB) a staging
#     prveho NEMAZE;
#   * lease: ziva ina instancia swap zastavi, mrtve lease sa upracu;
#   * restart latch blokuje VSETKY vstupne body (guard nad zdrojom);
#   * DOWNGRADE je zakazany a rovnaka verzia sa odmieta;
#   * settings store nesie `std` a nad degradovanou `.bak` zapisy odmieta.
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. recovery bootstrap odstraneny z loadera
#      -> „D-52a: pad po kroku 4 (tree_swapped) — boot dokonci swap" a dalsie
#         tri pado­ve testy (staged / loader_swapped / pred cleanupom);
#   2. update lock odstraneny (`with_update_lock` = obycajny yield)
#      -> „D-52a: druhy proces dostane odmietnutie OKAMZITE a staging nemaze";
#   3. restart latch odstraneny (`Engine.restart_required!` sa po commite
#      nevola / guardy vo vstupnych bodoch zmiznu)
#      -> „D-52a: uspesny swap zapne restart latch" a
#         „D-52a: KAZDY vstupny bod pluginu ma restart latch";
#   4. latch az PO uprataní (nie hned po commite loadera)
#      -> „(#277 P1): latch je zapnuty aj ked upratanie po commite zlyha";
#   5. `rollback_after_loader_failure!` hlasi uspech vzdy
#      -> „(#277 P1): ZLYHANY rollback nemaze zalozne generacie ani marker";
#   6. opakovana kontrola lease po stagingu odstranena
#      -> „(#277 P1): nova instancia POCAS stagingu swap zastavi";
#   7. `assert_single_version!` nad staged loaderom odstraneny
#      -> „(#277 P2): DUPLICITNA VERSION za hlavickou sa odmietne pred commitom";
#   8. boot ignoruje vysledok recovery a registruje extension vzdy
#      -> „(#277 P1): boot pri DRZANOM zamku plugin NENACITA";
#   9. recovery dokonci transakciu DOPREDU aj spod stareho loadera
#      -> „pad v stave tree_swapped…" + „(#277 P1): ZLYHANY rollback…";
#  10. boot berie zamok LEN ked su na disku artefakty
#      -> „(#277/2 P1): boot pri drzanom zamku NENACITA ani BEZ artefaktov" (+2);
#  11. boot nezapisuje lease / ignoruje zlyhanie zapisu
#      -> „(#277/2 P1): lease zapisuje LOADER…" + „(#277/2 P2): nezapisatelny lease…";
#  12. `live_leases` pri nezistitelnom stave ticho vrati []
#      -> „(#277/2 P2): nezistitelny stav lease zastavi aktualizaciu";
#  13. `discard_previous!` bez guardu na zivy strom
#      -> „(#277/2 P1): `.old` sa nesmie zmazat…" + guard nad zdrojom;
#  14. zlyhanie zapisu markera po kroku 4 utecie von (bez rollbacku a latchu)
#      -> „(#277/2 P1): zlyhany zapis markera po kroku 4…" + guard nad zdrojom;
#  15. zaloha loadera RENAMEOM namiesto kopie (okno bez `noxun_engine.rb`)
#      -> „(#277/3 P1): zaloha loadera je KOPIA…" + guard nad zdrojom;
#  16. recovery rozhoduje podla PRITOMNOSTI `.rb.new`, nie podla obsahu
#      -> „pad v stave loader_copied…" + „(#277/3 P1): recovery rozhoduje
#         z OBSAHU loadera…";
#  17. `generation_matches?` sa na ceste bez artefaktov preskoci
#      -> „(#277/3 P1): boot po CAKANI na zamok pozna cudzi update (:restart)";
#  18. lease neoveruje identitu procesu (staci zivy PID)
#      -> „(#277/3 P2): recyklovany PID neblokuje aktualizaciu";
#  19. `cb` wrappery panela a Studia bez latchu
#      -> „(#277/4 P1): KAZDY cb wrapper cita restart_required?";
#  20. `tasklist` bez kontroly exit statusu (prazdny vystup = mrtvy PID)
#      -> „(#277/4 P2): zlyhany tasklist NIE JE mrtvy PID" (+ lease sada);
#  21. `chomp('/')` aj nad korenovou cestou
#      -> „(#277/4 P2): normalize_path nezmrza korenove cesty";
#  22. `clear_marker` znova hlasi uspech vzdy
#      -> „(#277/4 P2): nezmazatelny marker sa PRIZNA, nezamlci".
#
# CELA SADA BEZI NAD TEMP SANDBOXOM — nikdy nad zivym `Plugins` priecinkom.
# Testy, ktore spustaju druhy Ruby proces alebo zapisuju do %APPDATA%, sa
# v SketchUpe PRESKOCIA (`RbConfig.ruby` tam nie je samostatny interpreter
# a APPDATA je zdielana so zivym pluginom).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'
require 'rbconfig'
require 'open3'

module NxD52
  E = Noxun::Engine
  U = E::Updater

  # Realny loader — testy tym overuju SKUTOCNY recovery bootstrap, nie kopiu.
  LOADER_SRC = File.binread(File.join(NxTest::ROOT, 'noxun_engine.rb'))

  module_function

  def loader_text(version)
    LOADER_SRC.sub(/VERSION = '[^']+'/, "VERSION = '#{version}'")
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
    path
  end

  # Kompletny balik = kopia repa: loader + strom `noxun_engine/`.
  # `salt` meni obsah suborov bez zmeny verzie (test „rovnako velky, ale iny").
  def build_package(root, version, salt = 'a')
    FileUtils.rm_rf(root)
    write(File.join(root, 'noxun_engine.rb'), loader_text(version))
    write(File.join(root, 'noxun_engine', 'main.rb'),
          "# main\nmodule Noxun\n  module Engine\n    VERSION = '#{version}' unless defined?(VERSION)\n  end\nend\n")
    write(File.join(root, 'noxun_engine', 'core', 'demo.rb'), "# demo #{version} #{salt}\n")
    write(File.join(root, 'noxun_engine', 'ui', 'panel.html'), "<html>#{version} #{salt}</html>\n")
    write(File.join(root, 'noxun_engine', 'ui', 'js', 'boot.js'), "// boot #{version} #{salt}\n")
    root
  end

  # Sandbox: `<root>/src` (zdrojovy balik) + `<root>/plugins` (ciel).
  # Koren sa berie cez `realpath` — na Windows moze `%TEMP%` prist v 8.3 tvare
  # a kontrola symlinkov by ho odmietla ako „odkaz na ine miesto".
  def sandbox(current = '0.9.4', available = '0.9.5')
    root = File.realpath(Dir.mktmpdir('nx-d52a-')).tr('\\', '/')
    src = File.join(root, 'src')
    plugins = File.join(root, 'plugins')
    build_package(src, available, 'new')
    build_package(plugins, current, 'old')
    # Realna instalacia ma lease VZDY — zapisuje ho LOADER hned na zaciatku
    # bootu. `live_leases` je od kola 2 FAIL-CLOSED, takze bez neho by `apply!`
    # spravne odmietol bezat.
    U.write_lease!(plugins)
    { root: root, src: src, plugins: plugins, tree: File.join(plugins, 'noxun_engine') }
  end

  def fingerprint(plugins)
    U.manifest_of(File.join(plugins, 'noxun_engine'), File.join(plugins, 'noxun_engine.rb'))
  end

  def leftovers(plugins)
    %w[noxun_engine.new noxun_engine.rb.new noxun_engine.old noxun_engine.rb.old
       noxun_engine.update.json].select { |n| File.exist?(File.join(plugins, n)) }
  end

  # Po KAZDOM odmietnuti musi byt ciel byte-identicky a bez zvyskov.
  def assert_untouched(plugins, before, ctx)
    NxTest.assert_equal(before, fingerprint(plugins), "#{ctx}: ciel sa zmenil, hoci sa aktualizacia odmietla")
    rest = leftovers(plugins)
    NxTest.assert(rest.empty?, "#{ctx}: po odmietnuti ostali zvysky #{rest.join(', ')}")
  end

  # Jedna KOMPLETNA generacia = strom aj loader hlasia tu istu verziu.
  def generation(plugins, ctx)
    ldr = File.join(plugins, 'noxun_engine.rb')
    main = File.join(plugins, 'noxun_engine', 'main.rb')
    NxTest.assert(File.file?(ldr), "#{ctx}: loader chyba")
    NxTest.assert(File.file?(main), "#{ctx}: strom pluginu chyba")
    a = U.read_version(ldr)
    b = U.read_version(main)
    NxTest.assert_equal(a, b, "#{ctx}: loader (#{a}) a main.rb (#{b}) NIE su jedna generacia")
    a
  end

  # --- pasce na kroky swapu ---------------------------------------------------
  # Trap je na DVOJICU (basename zdroja -> basename ciela), nie na jeden nazov:
  # rollback prepisuje tie iste cesty opacnym smerom a musi prejst.
  # `pairs` = zoznam [zdroj, ciel]; polozka je String (presna zhoda) alebo
  # Regexp. `skip` prepusti prvych N zhod (marker sa zapisuje viackrat, pasca
  # ma platit az po commite).
  def with_rename_trap(from_base, to_base = nil, skip: 0)
    pairs = to_base.nil? ? from_base : [[from_base, to_base]]
    seen = 0
    sc = File.singleton_class
    sc.send(:alias_method, :nx_d52_orig_rename, :rename)
    sc.send(:define_method, :rename) do |src, dst|
      hit = pairs.any? { |(f, t)| f === File.basename(src.to_s) && t === File.basename(dst.to_s) } # rubocop:disable Style/CaseEquality
      if hit
        seen += 1
        raise Errno::EACCES, "test trap #{File.basename(src.to_s)} -> #{File.basename(dst.to_s)}" if seen > skip
      end

      nx_d52_orig_rename(src, dst)
    end
    yield
  ensure
    sc.send(:remove_method, :rename)
    sc.send(:alias_method, :rename, :nx_d52_orig_rename)
    sc.send(:remove_method, :nx_d52_orig_rename)
  end

  # Nahradny `Process::Status` pre stub `Open3.capture2e`.
  FakeStatus = Struct.new(:ok) do
    def success?
      ok
    end
  end

  # Stub `Open3.capture2e` — vracia pevnu dvojicu [vystup, stav].
  def with_capture2e(result)
    sc = Open3.singleton_class
    sc.send(:alias_method, :nx_d52_orig_capture2e, :capture2e)
    sc.send(:define_method, :capture2e) { |*_a, **_k| result }
    yield
  ensure
    sc.send(:remove_method, :capture2e)
    sc.send(:alias_method, :capture2e, :nx_d52_orig_capture2e)
    sc.send(:remove_method, :nx_d52_orig_capture2e)
  end

  # Zablokuje `FileUtils.rm_f` pre jeden konkretny nazov suboru.
  def with_rmf_block(basename)
    sc = FileUtils.singleton_class
    sc.send(:alias_method, :nx_d52_orig_rm_f, :rm_f)
    sc.send(:define_method, :rm_f) do |list, **opts|
      next nil if Array(list).any? { |p| File.basename(p.to_s) == basename }

      nx_d52_orig_rm_f(list, **opts)
    end
    yield
  ensure
    sc.send(:remove_method, :rm_f)
    sc.send(:alias_method, :rm_f, :nx_d52_orig_rm_f)
    sc.send(:remove_method, :nx_d52_orig_rm_f)
  end

  # Stub `Updater.process_image`: `map` je PID -> navratova hodnota
  # (String = image name, nil = proces nezije, :raise = nezistitelny stav).
  def with_process_image(map)
    sc = U.singleton_class
    sc.send(:alias_method, :nx_d52_orig_image, :process_image)
    sc.send(:define_method, :process_image) do |pid|
      raise Noxun::Engine::Updater::Refused, 'test: tasklist zlyhal' if map[pid.to_i] == :raise

      map.key?(pid.to_i) ? map[pid.to_i] : nx_d52_orig_image(pid)
    end
    yield
  ensure
    sc.send(:remove_method, :process_image)
    sc.send(:alias_method, :process_image, :nx_d52_orig_image)
    sc.send(:remove_method, :nx_d52_orig_image)
  end

  # Docasna pasca nad `Updater.stage!` — simuluje instanciu SketchUpu, ktora
  # nabehne AZ POCAS kopirovania balika (lease vznikne po prvej kontrole).
  def with_lease_during_staging(pid, exe = 'SketchUp.exe')
    sc = U.singleton_class
    sc.send(:alias_method, :nx_d52_orig_stage, :stage!)
    sc.send(:define_method, :stage!) do |src, plugins, manifest|
      out = nx_d52_orig_stage(src, plugins, manifest)
      write_lease!(plugins, pid, exe)
      out
    end
    yield
  ensure
    sc.send(:remove_method, :stage!)
    sc.send(:alias_method, :stage!, :nx_d52_orig_stage)
    sc.send(:remove_method, :nx_d52_orig_stage)
  end

  def with_rmrf_block(basename)
    sc = FileUtils.singleton_class
    sc.send(:alias_method, :nx_d52_orig_rm_rf, :rm_rf)
    sc.send(:define_method, :rm_rf) do |list, **opts|
      next nil if Array(list).any? { |p| File.basename(p.to_s) == basename }

      nx_d52_orig_rm_rf(list, **opts)
    end
    yield
  ensure
    sc.send(:remove_method, :rm_rf)
    sc.send(:alias_method, :rm_rf, :nx_d52_orig_rm_rf)
    sc.send(:remove_method, :nx_d52_orig_rm_rf)
  end

  # --- „dalsi boot" = SKUTOCNE nacitanie loadera v samostatnom procese --------
  # Loader je SketchUp subor (`require 'sketchup.rb'`), preto sandbox dostane
  # minimalne stuby. Nic ine sa nestubuje — recovery sekcia bezi presne tak,
  # ako bezi pri realnom starte SketchUpu.
  # Vracia hash so stavom bootu: `status` (recovery), `version` (verzia loadera,
  # ktory sa PRAVE VYKONAL), `registered` (nacital sa plugin?) a `message`
  # (natívna hláška, ak nejaká bola).
  def boot!(env, preload: nil)
    stubs = File.join(env[:root], 'stubs')
    write(File.join(stubs, 'sketchup.rb'), <<~RUBY)
      module Sketchup
        def self.register_extension(*)
          $nx_registered = true
        end
      end
      module UI
        def self.messagebox(msg)
          $nx_message = msg
        end
      end
    RUBY
    write(File.join(stubs, 'extensions.rb'),
          "class SketchupExtension\n  attr_accessor :description, :version, :creator, :copyright\n" \
          "  def initialize(*); end\nend\n")
    script = File.join(env[:root], 'boot.rb')
    write(script, <<~RUBY)
      $LOAD_PATH.unshift(#{stubs.inspect})
      #{preload ? "require #{preload.inspect}" : ''}
      $nx_registered = false
      $nx_message = ''
      load #{File.join(env[:plugins], 'noxun_engine.rb').inspect}
      puts "NX_STATUS=\#{Noxun::Engine::Boot.status}"
      puts "NX_VERSION=\#{Noxun::Engine::VERSION}"
      puts "NX_REGISTERED=\#{$nx_registered ? 1 : 0}"
      puts "NX_MESSAGE=\#{$nx_message}"
    RUBY
    out = IO.popen([RbConfig.ruby, script], err: %i[child out], &:read).to_s
    { 'raw' => out,
      'status' => out[/^NX_STATUS=(.*)$/, 1].to_s,
      'version' => out[/^NX_VERSION=(.*)$/, 1].to_s,
      'registered' => out[/^NX_REGISTERED=(\d)$/, 1].to_s == '1',
      'message' => out[/^NX_MESSAGE=(.*)$/, 1].to_s }
  end

  # Rucne poskladany stav po PADE — presne to, co po sebe necha zabity proces.
  def crash_state!(env, state)
    plugins = env[:plugins]
    tree = File.join(plugins, 'noxun_engine')
    tree_new = "#{tree}.new"
    tree_old = "#{tree}.old"
    ldr = File.join(plugins, 'noxun_engine.rb')
    new_pkg = File.join(env[:root], 'staged')
    build_package(new_pkg, '0.9.5', 'new')

    case state
    when 'staged' # kroky 1–2 hotove, swap sa nezacal
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree_new)
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), "#{ldr}.new")
    when 'tree_moved' # pad MEDZI krokom 3 a 4 (strom bokom, novy este nie na mieste)
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree_new)
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), "#{ldr}.new")
      File.rename(tree, tree_old)
    when 'tree_swapped' # krok 4 hotovy, loader este stary
      File.rename(tree, tree_old)
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree)
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), "#{ldr}.new")
    when 'loader_copied' # pad MEDZI (5a) kopiou zalohy a (5b) renameom
      File.rename(tree, tree_old)
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree)
      FileUtils.cp(ldr, "#{ldr}.old")  # zaloha je KOPIA — `.rb` ostava stary
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), "#{ldr}.new")
    when 'loader_swapped' # krok 5 hotovy, `.old` este nie je upratany
      File.rename(tree, tree_old)
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree)
      FileUtils.cp(ldr, "#{ldr}.old")
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), ldr)
    when 'before_cleanup' # to iste, ale marker uz hlasi `done`
      File.rename(tree, tree_old)
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree)
      FileUtils.cp(ldr, "#{ldr}.old")
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), ldr)
    else
      raise ArgumentError, state
    end

    marker_state = case state
                   when 'tree_moved' then 'staged'
                   when 'before_cleanup' then 'done'
                   else state
                   end
    marker = { 'std' => 1, 'state' => marker_state,
               'from' => '0.9.4', 'to' => '0.9.5', 'started_at' => '2026-09-02T08:00:00Z', 'pid' => 424_242 }
    write(File.join(plugins, 'noxun_engine.update.json'), JSON.pretty_generate(marker))
    env
  end
end

# --- 1) verzie ----------------------------------------------------------------

NxTest.test('D-52a: porovnanie verzii je CISELNE — 0.9.9 < 0.10.0') do
  u = NxD52::U
  NxTest.assert(u.compare('0.9.9', '0.10.0').negative?, '0.9.9 musi byt STARSIA nez 0.10.0')
  NxTest.assert(u.compare('0.10.0', '0.9.9').positive?, 'a opacne')
  NxTest.assert_equal(0, u.compare('0.9', '0.9.0'), 'chybajuci segment je 0')
  NxTest.assert_equal(0, u.compare('1.2.3', '1.2.3'))
  NxTest.assert_equal(:newer, u.classify('0.9.9', '0.10.0'))
  NxTest.assert_equal(:same, u.classify('0.9.4', '0.9.4'))
  NxTest.assert_equal(:older, u.classify('0.10.0', '0.9.9'))
end

NxTest.test('D-52a: chybajuca, neplatna aj DUPLICITNA VERSION je chyba') do
  u = NxD52::U
  NxTest.assert_equal('0.9.5', u.parse_version("# hlavicka\n    VERSION = '0.9.5'\n"))
  NxTest.assert_raise('nie je VERSION') { u.parse_version("# nic tu nie je\n") }
  NxTest.assert_raise('VERSION je v hlavičke 2') do
    u.parse_version("VERSION = '0.9.5'\nVERSION = '0.9.6'\n")
  end
  NxTest.assert_raise('neplatná VERSION') { u.parse_version("VERSION = ''\n") }
  NxTest.assert_raise('neplatná VERSION') { u.parse_version("VERSION = '0.9.5-beta'\n") }
  NxTest.assert_raise('neplatná VERSION') { u.parse_version("VERSION = 'a.b.c'\n") }
end

NxTest.test('D-52a: hlavicka sa cita OBMEDZENE a chybajuci subor je chyba') do
  env = NxD52.sandbox
  loader = File.join(env[:plugins], 'noxun_engine.rb')
  NxTest.assert_equal('0.9.4', NxD52::U.read_version(loader))
  NxTest.assert_raise('chýba') { NxD52::U.read_version(File.join(env[:plugins], 'nic.rb')) }

  # VERSION az za limitom hlavicky sa NENAJDE — je to vedoma hranica (a preto
  # VERSION zije v loaderi hned pod komentarom).
  far = NxD52.write(File.join(env[:root], 'far.rb'), "#{'# vypln' + ' x' * 40 + "\n"}" * 200 + "VERSION = '9.9.9'\n")
  NxTest.assert_raise('nie je VERSION') { NxD52::U.read_version(far) }
  FileUtils.rm_rf(env[:root])
end

# --- 2) manifest, staging, validacia -----------------------------------------

NxTest.test('D-52a: manifest zdroja nesie SHA1 aj velkost kazdeho suboru balika') do
  env = NxD52.sandbox
  m = NxD52::U.source_manifest(env[:src])
  NxTest.assert(m.key?('noxun_engine.rb'), 'loader patri do manifestu')
  NxTest.assert(m.key?('noxun_engine/main.rb'), 'strom patri do manifestu')
  NxTest.assert(m.key?('noxun_engine/ui/js/boot.js'), 'aj vnorene subory')
  NxTest.assert(m['noxun_engine/main.rb']['sha1'].to_s.length == 40, 'SHA1 ma 40 znakov')
  NxTest.assert(m['noxun_engine/main.rb']['size'].to_i.positive?, 'velkost je cislo')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: validacia staged stromu chyti chybajuci, skrateny, poskodeny aj subor navyse') do
  env = NxD52.sandbox
  u = NxD52::U
  plugins = env[:plugins]
  before = NxD52.fingerprint(plugins)
  m = u.source_manifest(env[:src])

  # (a) chybajuci
  u.stage!(env[:src], plugins, m)
  FileUtils.rm_f(File.join(plugins, 'noxun_engine.new', 'ui', 'js', 'boot.js'))
  NxTest.assert_raise('chýba') { u.validate_staged!(plugins, m) }

  # (b) skrateny (mensia velkost)
  u.stage!(env[:src], plugins, m)
  File.binwrite(File.join(plugins, 'noxun_engine.new', 'ui', 'js', 'boot.js'), '//')
  NxTest.assert_raise('veľkosť') { u.validate_staged!(plugins, m) }

  # (c) ROVNAKO VELKY, ale poskodeny — velkost sedi, SHA1 nie
  u.stage!(env[:src], plugins, m)
  path = File.join(plugins, 'noxun_engine.new', 'ui', 'js', 'boot.js')
  orig = File.binread(path)
  File.binwrite(path, 'X' * orig.bytesize)
  NxTest.assert_equal(orig.bytesize, File.size(path), 'test si sam overuje, ze velkost sedi')
  NxTest.assert_raise('obsah sa nezhoduje') { u.validate_staged!(plugins, m) }

  # (d) subor NAVYSE
  u.stage!(env[:src], plugins, m)
  NxD52.write(File.join(plugins, 'noxun_engine.new', 'ui', 'cudzie.js'), '// cudzie')
  NxTest.assert_raise('navyše') { u.validate_staged!(plugins, m) }

  u.cleanup_staging(plugins)
  NxD52.assert_untouched(plugins, before, 'validacia staged')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: zdroj zmeneny POCAS kopirovania konci odmietnutim, pribudnuty subor sa neberie') do
  env = NxD52.sandbox
  u = NxD52::U
  plugins = env[:plugins]
  m = u.source_manifest(env[:src])

  # ZMENA po manifeste = nesulad SHA1 na staged strome.
  # ROVNAKO DLHY, ale iny obsah — nesulad chyti az SHA1, nie velkost.
  puvodne = File.binread(File.join(env[:src], 'noxun_engine', 'core', 'demo.rb'))
  NxD52.write(File.join(env[:src], 'noxun_engine', 'core', 'demo.rb'), 'Z' * puvodne.bytesize)
  u.stage!(env[:src], plugins, m)
  NxTest.assert_raise('obsah sa nezhoduje') { u.validate_staged!(plugins, m) }

  # PRIBUDNUTY subor sa do `.new` nedostane vobec (kopiruje sa len manifest).
  env2 = NxD52.sandbox
  m2 = u.source_manifest(env2[:src])
  NxD52.write(File.join(env2[:src], 'noxun_engine', 'core', 'pribudlo.rb'), "# neskoro\n")
  u.stage!(env2[:src], env2[:plugins], m2)
  NxTest.refute(File.exist?(File.join(env2[:plugins], 'noxun_engine.new', 'core', 'pribudlo.rb')),
                'subor, ktory v zdroji pribudol po manifeste, sa NESMIE dostat do balika')
  NxTest.assert(u.validate_staged!(env2[:plugins], m2), 'a validacia prejde')

  FileUtils.rm_rf(env[:root])
  FileUtils.rm_rf(env2[:root])
end

NxTest.test('D-52a: relativna cesta nesmie uniknut zo stromu balika') do
  u = NxD52::U
  NxTest.assert_equal('noxun_engine/core/a.rb', u.safe_relative!('noxun_engine/core/a.rb'))
  NxTest.assert_raise('uniká') { u.safe_relative!('noxun_engine/../../evil.rb') }
  NxTest.assert_raise('absolútna') { u.safe_relative!('/etc/passwd') }
  NxTest.assert_raise('absolútna') { u.safe_relative!('C:/Windows/system32/a.dll') }
  NxTest.assert_raise('spätné lomítko') { u.safe_relative!('noxun_engine\\core\\a.rb') }
  NxTest.assert_raise('neplatná cesta') { u.safe_relative!('') }
end

NxTest.test('D-52a: symlink/junction v balíku sa odmietne') do
  env = NxD52.sandbox
  target = File.join(env[:src], 'noxun_engine', 'core', 'demo.rb')
  link = File.join(env[:src], 'noxun_engine', 'core', 'odkaz.rb')
  made = begin
    File.symlink(target, link)
    File.symlink?(link) || File.exist?(link)
  rescue StandardError
    false
  end
  unless made
    # Windows bez developer modu: skus aspon junction na priecinok.
    dir_link = File.join(env[:src], 'noxun_engine', 'ui2')
    system('cmd', '/c', 'mklink', '/J', dir_link.tr('/', '\\'),
           File.join(env[:src], 'noxun_engine', 'ui').tr('/', '\\'),
           out: File::NULL, err: File::NULL)
    made = File.exist?(dir_link)
  end
  unless made
    FileUtils.rm_rf(env[:root])
    NxTest.skip!('symlink ani junction sa v tomto prostredi nedaju vytvorit')
  end

  NxTest.assert_raise(/symlink|odkaz na iné miesto/) { NxD52::U.source_manifest(env[:src]) }
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: kanonicke hranice — zdroj == ciel, zdroj vnutri ciela, .new/.old, nie balik') do
  env = NxD52.sandbox
  u = NxD52::U
  tree = env[:tree]

  NxTest.assert_raise('nie je zadaný') { u.check_boundaries!('', tree) }
  NxTest.assert_raise('neexistuje') { u.check_boundaries!(File.join(env[:root], 'nic'), tree) }
  NxTest.assert_raise('ten istý priečinok') { u.check_boundaries!(env[:plugins], tree) }

  vnutri = NxD52.build_package(File.join(env[:plugins], 'balik'), '0.9.6')
  NxTest.assert_raise('vnútri cieľového') { u.check_boundaries!(vnutri, tree) }

  # `.new`/`.old` su PRACOVNE priecinky aktualizacie, nie zdroj.
  stary = NxD52.build_package(File.join(env[:root], 'noxun_engine.old'), '0.9.6')
  NxTest.assert_raise('pracovný priečinok') { u.check_boundaries!(stary, tree) }

  prazdny = File.join(env[:root], 'prazdny')
  FileUtils.mkdir_p(prazdny)
  NxTest.assert_raise('nie je balík') { u.check_boundaries!(prazdny, tree) }

  # Ciel vnutri zdroja (zdroj je rodic celeho sandboxu).
  NxTest.assert_raise('vnútri zdrojového') { u.check_boundaries!(env[:root], tree) }

  NxTest.assert(u.check_boundaries!(env[:src], tree).is_a?(Array), 'platny balik prejde')
  FileUtils.rm_rf(env[:root])
end

# --- 3) uspesny swap ---------------------------------------------------------

NxTest.test('D-52a: uspesny swap vymeni CELU generaciu a nenecha siroty') do
  env = NxD52.sandbox
  Noxun::Engine.reset_restart_latch!
  # Osireny subor STAREJ verzie musi po swape zaniknut (zrkadlenie cez `.old`).
  NxD52.write(File.join(env[:tree], 'core', 'zaniknute.rb'), "# stare\n")

  res = NxD52::U.apply!(env[:src], env[:tree])
  NxTest.assert(res['ok'], 'aktualizacia hlasi uspech')
  NxTest.assert_equal('0.9.4', res['from'])
  NxTest.assert_equal('0.9.5', res['to'])
  NxTest.assert_equal('', res['note'], 'ziadna poznamka pri cistom behu')

  NxTest.assert_equal('0.9.5', NxD52.generation(env[:plugins], 'po swape'))
  NxTest.refute(File.exist?(File.join(env[:tree], 'core', 'zaniknute.rb')),
                'osireny subor starej verzie musi so `.old` zaniknut')
  NxTest.assert(NxD52.leftovers(env[:plugins]).empty?,
                "po uspechu nesmu ostat zvysky: #{NxD52.leftovers(env[:plugins]).join(', ')}")
  # Ciel je BYTE-IDENTICKY so zdrojom.
  NxTest.assert_equal(NxD52::U.source_manifest(env[:src]), NxD52.fingerprint(env[:plugins]),
                      'nasadeny balik sa musi presne zhodovat so zdrojom')
  Noxun::Engine.reset_restart_latch!
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: uspesny swap zapne restart latch') do
  env = NxD52.sandbox
  Noxun::Engine.reset_restart_latch!
  NxTest.refute(Noxun::Engine.restart_required?, 'pred aktualizaciou je latch zhasnuty')
  NxD52::U.apply!(env[:src], env[:tree])
  NxTest.assert(Noxun::Engine.restart_required?, 'po commite MUSI byt latch zapnuty')
  NxTest.assert(Noxun::Engine.update_restart_pending?, 'guard vstupneho bodu hlasi „skonci"')
  Noxun::Engine.reset_restart_latch!
  NxTest.refute(Noxun::Engine.update_restart_pending?, 'po restarte guard pusta')
  FileUtils.rm_rf(env[:root])
end

# --- 4) zlyhania krokov 3–5 a mazania `.old` ---------------------------------

NxTest.test('D-52a: zlyhanie kroku 3 (strom bokom) necha ciel byte-identicky') do
  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  NxD52.with_rename_trap('noxun_engine', 'noxun_engine.old') do
    NxTest.assert_raise('nedá presunúť') { NxD52::U.apply!(env[:src], env[:tree]) }
  end
  NxTest.assert_equal('0.9.4', NxD52.generation(env[:plugins], 'krok 3'))
  NxD52.assert_untouched(env[:plugins], before, 'krok 3')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: zlyhanie kroku 4 (nasadenie noveho stromu) vrati `.old` spat') do
  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  NxD52.with_rename_trap('noxun_engine.new', 'noxun_engine') do
    NxTest.assert_raise('nedá nasadiť') { NxD52::U.apply!(env[:src], env[:tree]) }
  end
  NxTest.assert_equal('0.9.4', NxD52.generation(env[:plugins], 'krok 4'))
  NxD52.assert_untouched(env[:plugins], before, 'krok 4')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: zlyhanie kroku 5 (loader) vrati CELY swap — zmieseny stav nevznikne') do
  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  NxD52.with_rename_trap('noxun_engine.rb.new', 'noxun_engine.rb') do
    NxTest.assert_raise('nedá vymeniť') { NxD52::U.apply!(env[:src], env[:tree]) }
  end
  # KLUCOVE: strom sa musi vratit tiez — novy strom so starym loaderom je zakaz.
  NxTest.assert_equal('0.9.4', NxD52.generation(env[:plugins], 'krok 5'))
  NxD52.assert_untouched(env[:plugins], before, 'krok 5')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: zlyhanie mazania `.old` je USPECH s poznamkou') do
  env = NxD52.sandbox
  res = NxD52.with_rmrf_block('noxun_engine.old') do
    NxD52::U.apply!(env[:src], env[:tree])
  end
  NxTest.assert(res['ok'], 'nedokoncene upratanie NIE JE zlyhanie aktualizacie')
  NxTest.assert(res['note'].include?('nepodarilo'), "poznamka o zvysku chyba (#{res['note']})")
  NxTest.assert_equal('0.9.5', NxD52.generation(env[:plugins], 'po neuprataniu'))
  NxTest.assert(File.exist?(File.join(env[:plugins], 'noxun_engine.old')), 'zvysok naozaj ostal')
  NxTest.refute(File.exist?(File.join(env[:plugins], 'noxun_engine.update.json')), 'marker sa zmazal')
  Noxun::Engine.reset_restart_latch!

  # A dalsi boot ho uprace.
  NxTest.skip!('dalsi boot potrebuje samostatny Ruby proces') unless NxTest.headless?
  NxD52.boot!(env)
  NxTest.assert(NxD52.leftovers(env[:plugins]).empty?,
                "boot mal zvysky upratat: #{NxD52.leftovers(env[:plugins]).join(', ')}")
  NxTest.assert_equal('0.9.5', NxD52.generation(env[:plugins], 'po boote'))
  FileUtils.rm_rf(env[:root])
end

# --- 5) simulovany pad po kazdej hranici -> recovery pri dalsom boote ---------

# ZELEZNE PRAVIDLO (Codex #277 P1): strom na disku musi zodpovedat loaderu,
# ktory sa PRAVE VYKONAVA. Recovery preto NIKDY nedokoncuje dopredu spod
# stareho loadera — `tree_swapped` (na disku je este stary loader) sa VRACIA
# na `.old`, nie dotahuje na novu generaciu.
{
  'staged' => '0.9.4',         # swap sa nezacal -> plati STARA generacia
  'tree_moved' => '0.9.4',     # pad MEDZI krokom 3 a 4 -> STARA generacia
  'tree_swapped' => '0.9.4',   # loader je este STARY -> ROLLBACK stromu
  'loader_copied' => '0.9.4',  # zaloha hotova, `.rb` este STARY -> ROLLBACK
  'loader_swapped' => '0.9.5', # vykonava sa uz NOVY loader -> dokonci upratanie
  'before_cleanup' => '0.9.5'
}.each do |state, expected|
  NxTest.test("D-52a: pad v stave #{state} — boot da jednu kompletnu generaciu (#{expected})") do
    NxTest.skip!('recovery sa overuje skutocnym nacitanim loadera v druhom Ruby procese') unless NxTest.headless?

    env = NxD52.sandbox
    NxD52.crash_state!(env, state)
    # Codex #277 kolo 3 (P1): SketchUp musi mat co spustit v KAZDOM okamihu —
    # bez `noxun_engine.rb` by recovery nikdy nenabehla.
    NxTest.assert(File.file?(File.join(env[:plugins], 'noxun_engine.rb')),
                  "v stave #{state} chyba bootovatelny loader — recovery by nemala odkial bezat")
    out = NxD52.boot!(env)
    NxTest.assert(out['raw'] !~ /recovery aktualizacie zlyhala/,
                  "recovery hlasila chybu: #{out['raw'].lines.first(3).join(' ')}")
    NxTest.assert_equal(expected, NxD52.generation(env[:plugins], "boot po pade (#{state})"))
    # KLUCOVE: verzia, ktoru hlasi VYKONANY loader, musi sedat so stromom.
    NxTest.assert_equal(expected, out['version'],
                        "loader vykonany pri boote hlasi #{out['version']}, strom je #{expected} — zmiesana generacia")
    NxTest.assert(out['registered'], 'po uspesnej recovery sa plugin MA nacitat')
    NxTest.assert_equal('done', out['status'])
    rest = NxD52.leftovers(env[:plugins])
    NxTest.assert(rest.empty?, "po recovery ostali zvysky #{rest.join(', ')}")

    # Druhy boot uz nema co robit a nic nerozbije.
    again = NxD52.boot!(env)
    NxTest.assert_equal('idle', again['status'], 'druhy boot uz nema transakciu co riesit')
    NxTest.assert_equal(expected, NxD52.generation(env[:plugins], "druhy boot (#{state})"))
    NxTest.assert(NxD52.leftovers(env[:plugins]).empty?, 'druhy boot nesmie nic vyrobit')
    FileUtils.rm_rf(env[:root])
  end
end

NxTest.test('D-52a: bezny boot BEZ markera a zvyskov nerobi nic') do
  NxTest.skip!('potrebuje samostatny Ruby proces') unless NxTest.headless?

  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  out = NxD52.boot!(env)
  NxTest.assert_equal('idle', out['status'], 'bezny start nema co dorovnavat')
  NxTest.assert(out['registered'], 'a plugin sa normalne nacita')
  NxTest.assert_equal(before, NxD52.fingerprint(env[:plugins]), 'bezny boot sa suborov nedotkne')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: aktualizacia sa ODMIETNE, kym lezi nedokonceny marker') do
  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  NxD52.write(File.join(env[:plugins], 'noxun_engine.update.json'),
              JSON.generate('std' => 1, 'state' => 'staged', 'from' => '0.9.4', 'to' => '0.9.5'))
  NxTest.assert_raise('nedokončila') { NxD52::U.apply!(env[:src], env[:tree]) }
  NxTest.assert_equal(before, NxD52.fingerprint(env[:plugins]), 'ciel ostal nedotknuty')
  FileUtils.rm_rf(env[:root])
end

# --- 5b) nalezy Codex review #277 --------------------------------------------

NxTest.test('D-52a (#277 P1): boot pri DRZANOM zamku plugin NENACITA') do
  NxTest.skip!('potrebuje dva OS procesy') unless NxTest.headless?

  env = NxD52.sandbox
  plugins = env[:plugins]
  # Transakcne artefakty + drzany zamok = „v inom okne prave bezi aktualizacia".
  NxD52.write(File.join(plugins, 'noxun_engine.update.json'),
              JSON.generate('std' => 1, 'state' => 'staged', 'from' => '0.9.4', 'to' => '0.9.5'))
  ready = File.join(env[:root], 'ready_boot')
  go = File.join(env[:root], 'go_boot')
  holder = NxD52.write(File.join(env[:root], 'holder_boot.rb'), <<~RUBY)
    File.open(#{File.join(plugins, 'noxun_engine.update.lock').inspect}, File::RDWR | File::CREAT, 0o644) do |f|
      f.flock(File::LOCK_EX)
      File.binwrite(#{ready.inspect}, 'x')
      300.times { break if File.exist?(#{go.inspect}); sleep 0.05 }
    end
  RUBY
  pid = Process.spawn(RbConfig.ruby, holder)
  300.times { break if File.exist?(ready); sleep 0.02 }
  NxTest.assert(File.exist?(ready), 'drziaci proces sa nespustil')

  out = NxD52.boot!(env)
  NxTest.assert_equal('busy', out['status'], 'boot musí spoznať cudziu bežiacu aktualizáciu')
  NxTest.refute(out['registered'],
                'plugin sa NESMIE nacitat — updater by mu strom vymenil pod rukami')
  NxTest.assert(out['message'].include?('aktualizuje'), "chyba natívna hláška: #{out['message']}")
  NxTest.assert(File.exist?(File.join(plugins, 'noxun_engine.update.json')),
                'boot, ktory nedostal zamok, sa markera nesmie dotknut')

  File.binwrite(go, 'x')
  Process.wait(pid)
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277 P1): nova instancia POCAS stagingu swap zastavi') do
  NxTest.skip!('potrebuje druhy OS proces') unless NxTest.headless?

  env = NxD52.sandbox
  plugins = env[:plugins]
  before = NxD52.fingerprint(plugins)
  go = File.join(env[:root], 'go_late')
  holder = NxD52.write(File.join(env[:root], 'holder_late.rb'),
                       "300.times { break if File.exist?(#{go.inspect}); sleep 0.05 }\n")
  alive = Process.spawn(RbConfig.ruby, holder)

  # Pri VSTUPE lease este neexistuje — vznikne az po skopirovani balika.
  # Identita procesu je stubnuta: spusteny `ruby.exe` by inak (spravne) nebol
  # povazovany za instanciu SketchUpu.
  err = NxD52.with_process_image(alive => 'SketchUp.exe') do
    NxD52.with_lease_during_staging(alive) do
      NxTest.assert_raise('medzitým') { NxD52::U.apply!(env[:src], env[:tree]) }
    end
  end
  NxTest.assert(err.message.include?(alive.to_s), "odmietnutie pomenuje PID: #{err.message}")
  NxD52.assert_untouched(plugins, before, 'neskory lease')

  File.binwrite(go, 'x')
  Process.wait(alive)
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277 P1): ZLYHANY rollback nemaze zalozne generacie ani marker') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  Noxun::Engine.reset_restart_latch!

  # (5b) vymena loadera zlyha => loader ostava STARY na mieste;
  # rollback stromu potom zlyha tiez => nic sa nesmie zmazat.
  err = NxD52.with_rename_trap([%w[noxun_engine.rb.new noxun_engine.rb],
                                %w[noxun_engine noxun_engine.new]]) do
    NxTest.assert_raise('vrátenie zmien zlyhalo') { NxD52::U.apply!(env[:src], env[:tree]) }
  end
  NxTest.assert(err.message.include?('REŠTARTUJ'), "hlaska posiela na restart: #{err.message}")
  NxTest.assert(Noxun::Engine.restart_required?,
                'pri nedokoncenom rollbacku MUSI byt latch zapnuty — v Plugins lezi novy strom')

  NxTest.assert(File.file?(File.join(plugins, 'noxun_engine.rb')),
                'loader je od kola 3 na mieste POCAS celeho swapu — kopia, nie rename')

  NxTest.assert(File.exist?(File.join(plugins, 'noxun_engine.old')), '.old strom MUSI ostat')
  NxTest.assert(File.exist?(File.join(plugins, 'noxun_engine.rb.new')), '.rb.new MUSI ostat')
  NxTest.assert(File.exist?(File.join(plugins, 'noxun_engine.update.json')), 'marker MUSI ostat')
  Noxun::Engine.reset_restart_latch!

  # A boot recovery z tych artefaktov naozaj zlozi kompletnu STARU generaciu.
  NxTest.skip!('boot potrebuje samostatny Ruby proces') unless NxTest.headless?
  out = NxD52.boot!(env)
  NxTest.assert_equal('done', out['status'])
  NxTest.assert_equal('0.9.4', NxD52.generation(env[:plugins], 'boot po zlyhanom rollbacku'))
  NxTest.assert_equal('0.9.4', out['version'], 'vykonany loader sedi so stromom')
  NxTest.assert(out['registered'], 'po oprave sa plugin nacita')
  NxTest.assert(NxD52.leftovers(plugins).empty?, 'boot uprace vsetky artefakty')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277 P1): latch je zapnuty aj ked upratanie po commite zlyha') do
  env = NxD52.sandbox
  Noxun::Engine.reset_restart_latch!
  # Marker sa zapisuje 6× (staged, staged+to, tree_swapped, loader_copied,
  # loader_swapped, done); pasca plati az na ten PO commite loadera.
  res = NxD52.with_rename_trap(/\Anoxun_engine\.update\.json\.tmp-/, 'noxun_engine.update.json', skip: 4) do
    NxD52::U.apply!(env[:src], env[:tree])
  end
  NxTest.assert(res['ok'], 'aktualizacia PRESLA — chyba v upratovani z nej nesmie spravit neuspech')
  NxTest.assert(res['note'].include?('upratanie'), "poznamka o nedokoncenom uprataní chyba: #{res['note']}")
  NxTest.assert(Noxun::Engine.restart_required?,
                'latch sa MUSI zapnut hned po commite loadera, nie az po uprataní')
  NxTest.assert_equal('0.9.5', NxD52.generation(env[:plugins], 'po commite'))
  Noxun::Engine.reset_restart_latch!
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277 P2): DUPLICITNA VERSION za hlavickou sa odmietne pred commitom') do
  env = NxD52.sandbox
  loader = File.join(env[:src], 'noxun_engine.rb')
  text = File.binread(loader).force_encoding('UTF-8')
  # Druha definicia lezi az hlboko za hranicou hlavicky (4 kB) — lacne citanie
  # hlavicky ju NENAJDE, sken celeho suboru ano.
  vypln = "# vypln#{' x' * 40}\n" * 200
  NxD52.write(loader, "#{text}\n#{vypln}VERSION = '9.9.9'\n")
  NxTest.assert(File.size(loader) > 4096, 'test si sam overuje, ze duplikat je za hlavickou')
  NxTest.assert_equal('0.9.5', NxD52::U.read_version(loader), 'hlavicka sama duplikat nevidi')

  before = NxD52.fingerprint(env[:plugins])
  err = NxTest.assert_raise('VERSION je v súbore') { NxD52::U.apply!(env[:src], env[:tree]) }
  NxTest.assert(err.message.include?('nejednoznačný'), "dovod je zrozumitelny: #{err.message}")
  NxD52.assert_untouched(env[:plugins], before, 'duplicitna VERSION')
  FileUtils.rm_rf(env[:root])
end

# --- 5c) nalezy Codex review #277, kolo 2 ------------------------------------

NxTest.test('D-52a (#277/2 P1): boot pri drzanom zamku NENACITA ani BEZ artefaktov') do
  NxTest.skip!('potrebuje dva OS procesy') unless NxTest.headless?

  # Toto je to NEBEZPECNE okno: `apply!` uz drzi zamok a pocita manifest zdroja,
  # ale ziadny `.new` este neexistuje. Boot, ktory sa pozera len na artefakty,
  # by nic nenasiel a nacital strom, ktory mu updater o chvilu vymeni.
  env = NxD52.sandbox
  plugins = env[:plugins]
  NxTest.assert(NxD52.leftovers(plugins).empty?, 'test zacina BEZ akychkolvek artefaktov')

  ready = File.join(env[:root], 'ready_clean')
  go = File.join(env[:root], 'go_clean')
  holder = NxD52.write(File.join(env[:root], 'holder_clean.rb'), <<~RUBY)
    File.open(#{File.join(plugins, 'noxun_engine.update.lock').inspect}, File::RDWR | File::CREAT, 0o644) do |f|
      f.flock(File::LOCK_EX)
      File.binwrite(#{ready.inspect}, 'x')
      300.times { break if File.exist?(#{go.inspect}); sleep 0.05 }
    end
  RUBY
  pid = Process.spawn(RbConfig.ruby, holder)
  300.times { break if File.exist?(ready); sleep 0.02 }
  NxTest.assert(File.exist?(ready), 'drziaci proces sa nespustil')

  out = NxD52.boot!(env)
  NxTest.assert_equal('busy', out['status'], 'boot MUSI skusit zamok aj bez artefaktov')
  NxTest.refute(out['registered'], 'plugin sa NESMIE nacitat, kym cudzia aktualizacia drzi zamok')
  NxTest.assert(out['message'].include?('aktualizuje'), "chyba natívna hláška: #{out['message']}")

  File.binwrite(go, 'x')
  Process.wait(pid)
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/2 P1): lease zapisuje LOADER na zaciatku bootu') do
  NxTest.skip!('potrebuje samostatny Ruby proces') unless NxTest.headless?

  env = NxD52.sandbox
  FileUtils.rm_rf(File.join(env[:plugins], 'noxun_engine.leases'))
  out = NxD52.boot!(env)
  NxTest.assert_equal('idle', out['status'])
  NxTest.assert(out['registered'], 'bezny boot sa nacita')
  leases = Dir.glob(File.join(env[:plugins], 'noxun_engine.leases', '*.lease'))
  NxTest.assert_equal(1, leases.length, 'boot MUSI zapisat prave jednu stopu procesu')
  NxTest.assert(File.basename(leases.first) =~ /\A\d+\.lease\z/, 'meno stopy je <pid>.lease')
  raw = JSON.parse(File.binread(leases.first))
  NxTest.assert(raw['pid'].to_i.positive?, 'stopa nesie PID')
  NxTest.assert_equal(1, raw['std'], 'a verziu formatu')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/2 P2): nezapisatelny lease = FAIL-CLOSED, plugin sa nenacita') do
  NxTest.skip!('potrebuje samostatny Ruby proces') unless NxTest.headless?

  env = NxD52.sandbox
  # `noxun_engine.leases` ako OBYCAJNY SUBOR — mkdir_p zlyha.
  FileUtils.rm_rf(File.join(env[:plugins], 'noxun_engine.leases'))
  NxD52.write(File.join(env[:plugins], 'noxun_engine.leases'), 'toto nie je priecinok')
  out = NxD52.boot!(env)
  NxTest.assert_equal('lease_failed', out['status'], 'zlyhany lease MUSI byt vlastny stav')
  NxTest.refute(out['registered'],
                'bez lease by nas cudzia aktualizacia nevidela — plugin sa NESMIE nacitat')
  NxTest.assert(out['message'].include?('práva'), "hláška má poradiť: #{out['message']}")
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/2 P2): nezistitelny stav lease zastavi aktualizaciu') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  before = NxD52.fingerprint(plugins)
  u = NxD52::U

  # (a) priecinok chyba — o inych instanciach nevieme NIC
  FileUtils.rm_rf(File.join(plugins, 'noxun_engine.leases'))
  NxTest.assert_raise('chýba priečinok') { u.live_leases(plugins) }
  NxTest.assert_raise('chýba priečinok') { u.apply!(env[:src], env[:tree]) }
  NxD52.assert_untouched(plugins, before, 'chybajuci lease priecinok')

  # (b) je to subor, nie priecinok
  NxD52.write(File.join(plugins, 'noxun_engine.leases'), 'x')
  NxTest.assert_raise('nie je priečinok') { u.live_leases(plugins) }
  NxTest.assert_raise('nie je priečinok') { u.apply!(env[:src], env[:tree]) }
  NxD52.assert_untouched(plugins, before, 'lease ako subor')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/2 P1): DVOJITE zlyhanie kroku 4 zachova artefakty aj .old') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  Noxun::Engine.reset_restart_latch!

  # `.new -> tree` zlyha a kompenzacne `.old -> tree` tiez. Zivy strom teda
  # CHYBA — a prave vtedy sa nesmie zmazat `.old`, jedina kopia, ktora ostala.
  err = NxD52.with_rename_trap([%w[noxun_engine.new noxun_engine],
                                %w[noxun_engine.old noxun_engine]]) do
    NxTest.assert_raise('vrátenie zmien zlyhalo') { NxD52::U.apply!(env[:src], env[:tree]) }
  end
  NxTest.assert(err.message.include?('nasadiť'), "dovod pomenuje krok 4: #{err.message}")
  NxTest.assert(Noxun::Engine.restart_required?, 'latch MUSI byt zapnuty')
  NxTest.refute(Dir.exist?(File.join(plugins, 'noxun_engine')), 'zivy strom v tomto stave chyba')
  NxTest.assert(Dir.exist?(File.join(plugins, 'noxun_engine.old')),
                '.old je JEDINA kompletna kopia — NESMIE sa zmazat')
  NxTest.assert(File.exist?(File.join(plugins, 'noxun_engine.update.json')), 'marker MUSI ostat')

  # Opakovany pokus NESMIE `.old` zmazat — odmietne sa uz na markeri.
  NxTest.assert_raise('nedokončila') { NxD52::U.apply!(env[:src], env[:tree]) }
  NxTest.assert(Dir.exist?(File.join(plugins, 'noxun_engine.old')),
                'opakovany pokus nesmie siahnut na jediny strom')
  Noxun::Engine.reset_restart_latch!

  NxTest.skip!('boot potrebuje samostatny Ruby proces') unless NxTest.headless?
  out = NxD52.boot!(env)
  NxTest.assert_equal('done', out['status'])
  NxTest.assert_equal('0.9.4', NxD52.generation(plugins, 'boot po dvojitom zlyhani kroku 4'))
  NxTest.assert_equal('0.9.4', out['version'], 'vykonany loader sedi so stromom')
  NxTest.assert(out['registered'], 'po oprave sa plugin nacita')
  NxTest.assert(NxD52.leftovers(plugins).empty?, 'boot uprace vsetky artefakty')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/2 P1): `.old` sa nesmie zmazat, kym nie je zivy strom AJ loader') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  u = NxD52::U
  old_tree = File.join(plugins, 'noxun_engine.old')
  old_loader = File.join(plugins, 'noxun_engine.rb.old')

  FileUtils.cp_r(File.join(plugins, 'noxun_engine'), old_tree)
  FileUtils.cp(File.join(plugins, 'noxun_engine.rb'), old_loader)

  # (a) zivy strom chyba — `.old` je jedina kompletna kopia
  FileUtils.mv(File.join(plugins, 'noxun_engine'), File.join(plugins, 'noxun_engine.bokom'))
  NxTest.refute(u.discard_previous!(plugins), 'bez ziveho stromu sa nesmie nic mazat')
  NxTest.assert(Dir.exist?(old_tree), '`.old` strom MUSI prezit')
  NxTest.assert(File.exist?(old_loader), '`.old` loader MUSI prezit')
  FileUtils.mv(File.join(plugins, 'noxun_engine.bokom'), File.join(plugins, 'noxun_engine'))

  # (b) zivy loader chyba
  FileUtils.mv(File.join(plugins, 'noxun_engine.rb'), File.join(plugins, 'loader.bokom'))
  NxTest.refute(u.discard_previous!(plugins), 'bez ziveho loadera sa nesmie nic mazat')
  NxTest.assert(Dir.exist?(old_tree), '`.old` strom MUSI prezit aj tu')
  FileUtils.mv(File.join(plugins, 'loader.bokom'), File.join(plugins, 'noxun_engine.rb'))

  # (c) kompletna generacia na mieste — az teraz sa `.old` uprace
  NxTest.assert(u.discard_previous!(plugins), 'nad kompletnou generaciou sa `.old` uprace')
  NxTest.refute(File.exist?(old_tree), '`.old` strom je prec')
  NxTest.refute(File.exist?(old_loader), '`.old` loader je prec')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/2 P1): zlyhany zapis markera po kroku 4 vrati povodny strom') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  Noxun::Engine.reset_restart_latch!
  before = NxD52.fingerprint(plugins)

  # Marker sa pred krokom 3 zapisuje 2x; pasca teda plati na TRETI zapis —
  # ten po uspesnom nasadeni noveho stromu (krok 4).
  err = NxD52.with_rename_trap(/\Anoxun_engine\.update\.json\.tmp-/, 'noxun_engine.update.json',
                               skip: 2) do
    NxTest.assert_raise('nič sa nezmenilo') { NxD52::U.apply!(env[:src], env[:tree]) }
  end
  NxTest.assert(err.message.include?('stav aktualizácie'), "dovod pomenuje marker: #{err.message}")
  # Rollback presiel => cisty neuspech: ziadny latch, ciel byte-identicky.
  NxTest.refute(Noxun::Engine.restart_required?,
                'po USPESNOM rollbacku sa latch zapinat NEMA — na disku je presne to, co tam bolo')
  NxTest.assert_equal('0.9.4', NxD52.generation(plugins, 'marker zlyhal, rollback presiel'))
  NxD52.assert_untouched(plugins, before, 'zlyhany marker po kroku 4')
  FileUtils.rm_rf(env[:root])
end

# --- 5d) nalezy Codex review #277, kolo 3 ------------------------------------

NxTest.test('D-52a (#277/3 P1): File.rename PREPISE existujuci ciel (atomicky replace)') do
  # Cely krok (5b) na tom stoji: jeden rename nad existujucim `.rb`.
  # Windows: MoveFileExW s MOVEFILE_REPLACE_EXISTING; POSIX: rename(2).
  dir = File.realpath(Dir.mktmpdir('nx-d52a-rn-'))
  a = NxD52.write(File.join(dir, 'ciel.rb'), 'stary obsah')
  b = NxD52.write(File.join(dir, 'ciel.rb.new'), 'novy obsah')
  File.rename(b, a)
  NxTest.assert_equal('novy obsah', File.binread(a), 'rename musí prepísať existujúci cieľ')
  NxTest.refute(File.exist?(b), 'zdroj po renamovaní zaniká')
  FileUtils.rm_rf(dir)
end

NxTest.test('D-52a (#277/3 P1): zaloha loadera je KOPIA — `.rb` nezmizne ani na okamih') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  loader = File.join(plugins, 'noxun_engine.rb')
  videne = []

  # Snimame existenciu `.rb` po KAZDOM renamovani pocas celeho swapu.
  sc = File.singleton_class
  sc.send(:alias_method, :nx_d52_watch_rename, :rename)
  sc.send(:define_method, :rename) do |src, dst|
    out = nx_d52_watch_rename(src, dst)
    videne << File.file?(loader)
    out
  end
  begin
    res = NxD52::U.apply!(env[:src], env[:tree])
  ensure
    sc.send(:remove_method, :rename)
    sc.send(:alias_method, :rename, :nx_d52_watch_rename)
    sc.send(:remove_method, :nx_d52_watch_rename)
  end

  NxTest.assert(res['ok'], 'aktualizacia presla')
  NxTest.assert(videne.length > 3, "cakalo sa viac renameov (#{videne.length})")
  NxTest.assert(videne.all?, 'po ZIADNOM kroku swapu nesmie `noxun_engine.rb` chybat')
  NxTest.assert_equal('0.9.5', NxD52.generation(plugins, 'po swape'))
  Noxun::Engine.reset_restart_latch!
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/3 P1): zlyhanie (5b) necha STARY loader nedotknuty') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  before = NxD52.fingerprint(plugins)
  Noxun::Engine.reset_restart_latch!

  err = NxD52.with_rename_trap([%w[noxun_engine.rb.new noxun_engine.rb]]) do
    NxTest.assert_raise('nič sa nezmenilo') { NxD52::U.apply!(env[:src], env[:tree]) }
  end
  NxTest.assert(err.message.include?('vymeniť'), "dovod pomenuje loader: #{err.message}")
  NxTest.assert(File.file?(File.join(plugins, 'noxun_engine.rb')), 'loader ostal na mieste')
  NxTest.refute(Noxun::Engine.restart_required?, 'rollback presiel — latch netreba')
  NxTest.assert_equal('0.9.4', NxD52.generation(plugins, 'po zlyhani (5b)'))
  NxD52.assert_untouched(plugins, before, 'zlyhanie kroku 5b')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/3 P1): boot po CAKANI na zamok pozna cudzi update (:restart)') do
  NxTest.skip!('potrebuje dva OS procesy') unless NxTest.headless?

  # Proces A drzi zamok a medzitym „dokonci" update: strom je uz NOVY a ziadne
  # artefakty neostali. Proces B ma v pamati STARY loader — `pending?` je false,
  # takze bez kontroly generacie by sa zaregistroval nad cudzim stromom.
  env = NxD52.sandbox
  plugins = env[:plugins]
  ready = File.join(env[:root], 'ready_wait')
  go = File.join(env[:root], 'go_wait')
  novy = NxD52.build_package(File.join(env[:root], 'novy'), '0.9.5', 'new')
  holder = NxD52.write(File.join(env[:root], 'holder_wait.rb'), <<~RUBY2)
    require 'fileutils'
    File.open(#{File.join(plugins, 'noxun_engine.update.lock').inspect}, File::RDWR | File::CREAT, 0o644) do |f|
      f.flock(File::LOCK_EX)
      File.binwrite(#{ready.inspect}, 'x')
      # „Cudzi update" vymeni STROM, ale loader na disku necha stary — presne
      # tak to vidí proces, ktory uz stary loader vykonava.
      FileUtils.rm_rf(#{File.join(plugins, 'noxun_engine').inspect})
      FileUtils.cp_r(#{File.join(novy, 'noxun_engine').inspect}, #{File.join(plugins, 'noxun_engine').inspect})
      300.times { break if File.exist?(#{go.inspect}); sleep 0.05 }
    end
  RUBY2
  pid = Process.spawn(RbConfig.ruby, holder)
  300.times { break if File.exist?(ready); sleep 0.02 }
  NxTest.assert(File.exist?(ready), 'drziaci proces sa nespustil')
  File.binwrite(go, 'x') # nech zamok pusti, kym boot caka

  out = NxD52.boot!(env)
  NxTest.assert(NxD52.leftovers(plugins).empty?, 'po cudzom update neostali ziadne artefakty')
  NxTest.assert_equal('restart', out['status'],
                      'boot MUSI porovnat generaciu aj ked `pending?` je false')
  NxTest.refute(out['registered'], 'stary loader sa NESMIE zaregistrovat nad novym stromom')
  NxTest.assert(out['message'].include?('Reštartuj'), "chyba hláška: #{out['message']}")

  Process.wait(pid)
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/3 P2): recyklovany PID neblokuje aktualizaciu') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  u = NxD52::U
  cudzi = 424_242

  # Stopa po ukoncenom SketchUpe; OS medzitym PID pridelil inemu programu.
  u.write_lease!(plugins, cudzi, 'SketchUp.exe')
  NxTest.assert(File.exist?(u.lease_path(plugins, cudzi)), 'stopa vznikla')
  raw = JSON.parse(File.binread(u.lease_path(plugins, cudzi)))
  NxTest.assert_equal('SketchUp.exe', raw['exe'], 'stopa nesie image name')
  NxTest.refute(raw['started_at'].to_s.empty?, 'a cas vzniku')

  NxD52.with_process_image(cudzi => 'chrome.exe') do
    NxTest.assert_equal([], u.live_leases(plugins), 'cudzi program NIE JE ziva instancia')
  end
  NxTest.refute(File.exist?(u.lease_path(plugins, cudzi)), 'mrtva stopa sa uprace')

  # Ta ista PID, ale STALE SketchUp -> stopa plati a swap sa odmietne.
  u.write_lease!(plugins, cudzi, 'SketchUp.exe')
  before = NxD52.fingerprint(plugins)
  NxD52.with_process_image(cudzi => 'SketchUp.exe') do
    NxTest.assert_equal([cudzi], u.live_leases(plugins), 'ziva instancia SketchUpu sa najde')
    NxTest.assert_raise('ďalšia inštancia') { u.apply!(env[:src], env[:tree]) }
  end
  NxD52.assert_untouched(plugins, before, 'ziva instancia')

  # Iný program s tým istým menom v stope: image name sedí, ale nie je to
  # SketchUp -> stopa neplatí.
  u.write_lease!(plugins, cudzi, 'notepad.exe')
  NxD52.with_process_image(cudzi => 'notepad.exe') do
    NxTest.assert_equal([], u.live_leases(plugins), 'iny program stopu nedrzi')
  end

  # Nezistitelny stav ostava FAIL-CLOSED (kolo 2).
  u.write_lease!(plugins, cudzi, 'SketchUp.exe')
  NxD52.with_process_image(cudzi => :raise) do
    NxTest.assert_raise('tasklist') { u.live_leases(plugins) }
    NxTest.assert_raise('tasklist') { u.apply!(env[:src], env[:tree]) }
  end
  NxD52.assert_untouched(plugins, before, 'nezistitelny stav procesu')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/3 P1): recovery rozhoduje z OBSAHU loadera, nie z pritomnosti suborov') do
  NxTest.skip!('potrebuje samostatny Ruby proces') unless NxTest.headless?

  # Stav `loader_copied` BEZ `.rb.new` (zvysok sa nedopatrenim zmazal): podla
  # pritomnosti suborov by to vyzeralo ako „loader uz je novy" a recovery by
  # dokoncila dopredu. Podla OBSAHU je `.rb` stale stary -> rollback stromu.
  env = NxD52.sandbox
  NxD52.crash_state!(env, 'loader_copied')
  FileUtils.rm_f(File.join(env[:plugins], 'noxun_engine.rb.new'))

  out = NxD52.boot!(env)
  NxTest.assert_equal('done', out['status'])
  NxTest.assert_equal('0.9.4', NxD52.generation(env[:plugins], 'obsahove rozhodnutie'))
  NxTest.assert_equal('0.9.4', out['version'], 'vykonany loader sedi so stromom')
  NxTest.assert(out['registered'], 'po oprave sa plugin nacita')
  NxTest.assert(NxD52.leftovers(env[:plugins]).empty?, 'zvysky su upratane')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/3 P1): zmieseny stav (novy loader, stary strom) sa dorovna zo zalohy') do
  NxTest.skip!('potrebuje samostatny Ruby proces') unless NxTest.headless?

  # Ziadny `.new` ani `.old` STROM, ale loader patri inej generacii nez strom.
  env = NxD52.sandbox
  plugins = env[:plugins]
  novy = NxD52.build_package(File.join(env[:root], 'novy'), '0.9.5', 'new')
  FileUtils.cp(File.join(plugins, 'noxun_engine.rb'), File.join(plugins, 'noxun_engine.rb.old'))
  FileUtils.cp(File.join(novy, 'noxun_engine.rb'), File.join(plugins, 'noxun_engine.rb'))

  out = NxD52.boot!(env)
  NxTest.assert_equal('0.9.4', NxD52.generation(plugins, 'zmieseny stav dorovnany'))
  NxTest.assert(NxD52.leftovers(plugins).empty?, 'zvysky su upratane')
  NxTest.refute(out['registered'],
                'vykonany loader bol NOVY nad starym stromom — registrovat sa NESMIE')
  NxTest.assert_equal('restart', out['status'])

  # Dalsi boot uz cita opraveny loader a je konzistentny.
  again = NxD52.boot!(env)
  NxTest.assert_equal('idle', again['status'])
  NxTest.assert(again['registered'], 'po restarte uz vsetko sedi')
  NxTest.assert_equal('0.9.4', again['version'])
  FileUtils.rm_rf(env[:root])
end

# --- 5e) nalezy Codex review #277, kolo 4 ------------------------------------

NxTest.test('D-52a (#277/4 P1): latch zastavi aj callback UZ OTVORENEHO okna') do
  Noxun::Engine.reset_restart_latch!
  NxTest.refute(Noxun::Engine.update_locked?(:panel), 'bez latchu callbacky bezia')

  Noxun::Engine.restart_required!
  NxTest.assert(Noxun::Engine.update_locked?(:panel), 'po commite sa callback MUSI zastavit')
  NxTest.assert(Noxun::Engine.update_locked?(:studio), 'a to v KAZDOM okne')
  # Hlaska ide RAZ ZA OKNO — panel posiela desiatky callbackov za sekundu.
  NxTest.assert(Noxun::Engine.update_locked?(:panel), 'opakovany callback ostava zablokovany')
  NxTest.assert_equal(%i[panel studio].sort,
                      Noxun::Engine.instance_variable_get(:@locked_announced).keys.sort,
                      'kazde okno ohlasilo prave raz')
  Noxun::Engine.reset_restart_latch!
  NxTest.assert_equal(nil, Noxun::Engine.instance_variable_get(:@locked_announced),
                      'reset latchu vycisti aj priznaky hlasky')
end

NxTest.test('D-52a (#277/4 P1): KAZDY cb wrapper cita restart_required?') do
  root = NxTest::ROOT
  {
    'panel.rb' => File.read(File.join(root, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8'),
    'studio_dialog.rb' => File.read(File.join(root, 'noxun_engine', 'ui', 'studio_dialog.rb'), encoding: 'UTF-8')
  }.each do |name, src|
    body = src[/def cb\(dlg, name\).*?\n        end\n/m].to_s
    NxTest.refute(body.empty?, "#{name}: generic cb wrapper sa nenasiel — uprav guard test")
    NxTest.assert(body.include?('update_locked?'),
                  "#{name}: cb wrapper nema latch — okno otvorene v case commitu by " \
                  'starymi handlermi mutovalo model nad NOVYM balikom')
  end

  # Po commite sa okna este best-effort zavru (uplna bariera PRED swapom je D-52b).
  upd = File.read(File.join(root, 'noxun_engine', 'core', 'updater.rb'), encoding: 'UTF-8')
  NxTest.assert(upd.include?('Engine.close_all_dialogs'), 'swap! po commite zatvara okna')
  NxTest.assert(Noxun::Engine.respond_to?(:close_all_dialogs), 'a metoda existuje')
  NxTest.assert(Noxun::Engine.close_all_dialogs, 'bez otvorenych okien je to no-op bez vynimky')
end

NxTest.test('D-52a (#277/4 P2): zlyhany tasklist NIE JE „mrtvy PID"') do
  NxTest.skip!('vetva sa tyka Windows volania tasklistu') unless NxD52::U.windows?

  env = NxD52.sandbox
  plugins = env[:plugins]
  u = NxD52::U
  cudzi = 424_243
  u.write_lease!(plugins, cudzi, 'SketchUp.exe')

  # (a) nenulovy exit
  NxD52.with_capture2e(['', NxD52::FakeStatus.new(false)]) do
    NxTest.assert_raise('skončil chybou') { u.live_leases(plugins) }
  end
  NxTest.assert(File.exist?(u.lease_path(plugins, cudzi)),
                'stopa ZIVEJ instancie sa pri zlyhanom dotaze NESMIE zmazat')

  # (b) prazdny vystup pri nulovom exite
  NxD52.with_capture2e(['', NxD52::FakeStatus.new(true)]) do
    NxTest.assert_raise('nevrátil žiadnu odpoveď') { u.live_leases(plugins) }
  end
  NxTest.assert(File.exist?(u.lease_path(plugins, cudzi)), 'ani tu')

  # (c) informacna hlaska = proces naozaj NEZIJE (lokalizovana, bez CSV riadkov)
  NxD52.with_capture2e(["INFORMACIE: Neboli najdene ziadne ulohy.\n", NxD52::FakeStatus.new(true)]) do
    NxTest.assert_equal([], u.live_leases(plugins), 'informacna hlaska = mrtvy PID')
  end
  NxTest.refute(File.exist?(u.lease_path(plugins, cudzi)), 'az teraz sa stopa uprace')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/4 P2): normalize_path nezmrza korenove cesty') do
  u = NxD52::U
  # Jadro opravy je PREDIKAT — ten je platformovo nezavisly a bezi aj v CI.
  re = Noxun::Engine::Updater::ROOT_PATH_RE
  ['/', 'C:/', 'g:/', '//server/share'].each do |root|
    NxTest.assert(root =~ re, "#{root} je KOREN — koncove lomitko sa strihat nesmie")
  end
  ['/opt', 'C:/Plugins', '//server/share/plugins', '//server'].each do |cesta|
    NxTest.refute(cesta =~ re, "#{cesta} korenom NIE JE")
  end

  # A sprava sa podla neho aj sama metoda. `File.expand_path('/')` vrati na
  # Windows koren AKTUALNEHO disku, preto sa hodnota nefixuje — kontroluje sa
  # to, co je podstatne: koren si koncove lomitko UDRZI.
  root = u.normalize_path('/')
  NxTest.assert(root.end_with?('/'), "koren prisiel o koncove lomitko (#{root})")
  if u.windows?
    NxTest.assert_equal('c:/', u.normalize_path('C:/').downcase, 'koren disku ostava korenom')
    NxTest.assert_equal('//server/share', u.normalize_path('//server/share'), 'UNC koren zdielania')
    NxTest.assert_equal('//server/share/plugins', u.normalize_path('//server/share/plugins/'),
                        'beznej ceste sa koncove lomitko stale strihá')
    NxTest.assert(u.same_path?('C:/', 'C:\\'), 'oba zapisy korena disku su ta ista cesta')
  else
    NxTest.assert_equal('/', root, 'POSIX koren ostava korenom')
    NxTest.assert_equal('/opt/plugins', u.normalize_path('/opt/plugins/'),
                        'beznej ceste sa koncove lomitko stale strihá')
  end
  NxTest.assert(u.inside?('//server/share/plugins', '//server/share'),
                'priecinok v koreni zdielania je „vnutri" — bez toho by hranice nefungovali')
end

NxTest.test('D-52a (#277/4 P2): nezmazatelny marker sa PRIZNA, nezamlci') do
  env = NxD52.sandbox
  plugins = env[:plugins]
  Noxun::Engine.reset_restart_latch!

  res = NxD52.with_rmf_block('noxun_engine.update.json') do
    NxD52::U.apply!(env[:src], env[:tree])
  end
  NxTest.assert(res['ok'], 'aktualizacia PRESLA')
  NxTest.assert_equal('cleanup_pending', res['state'], 'ale stav to priznava')
  NxTest.assert(res['note'].include?('marker'), "poznamka pomenuje subor: #{res['note']}")
  NxTest.assert(Noxun::Engine.restart_required?, 'latch je zapnuty')
  NxTest.assert_equal('0.9.5', NxD52.generation(plugins, 'po commite'))
  NxTest.assert(File.exist?(File.join(plugins, 'noxun_engine.update.json')), 'marker naozaj ostal')
  # D-52b (P3 z delta-verifikacie #277): povodny assert porovnaval navratovu
  # hodnotu s RETAZCOM `'true'` — to nemohlo zlyhat ani vtedy, keby
  # `clear_marker` vzdy klamal. Meria sa teda SPRAVANIE: pod blokovanym `rm_f`
  # vrati `false` (marker ostal), po jeho uvolneni `true` a marker je prec.
  NxTest.refute(NxD52.with_rmf_block('noxun_engine.update.json') { NxD52::U.clear_marker(plugins) },
                'kym sa marker neda zmazat, `clear_marker` hlasi NEUSPECH')
  NxTest.assert(File.exist?(File.join(plugins, 'noxun_engine.update.json')),
                'a marker pri tom naozaj ostal lezat')
  NxTest.assert(NxD52::U.clear_marker(plugins), 'ked sa zmazat DA, hlasi uspech')
  NxTest.refute(File.exist?(File.join(plugins, 'noxun_engine.update.json')), 'a marker je prec')
  Noxun::Engine.reset_restart_latch!
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a (#277/4 P2): boot s nezmazatelnym markerom plugin NENACITA') do
  NxTest.skip!('potrebuje samostatny Ruby proces') unless NxTest.headless?

  env = NxD52.sandbox
  NxD52.crash_state!(env, 'staged')
  # Marker sa da citat, ale nie zmazat (read-only priecinok sa na Windows
  # nespravuje spolahlivo, preto sa mazanie zablokuje v samotnom loaderi).
  NxD52.write(File.join(env[:root], 'stub_rm.rb'), <<-'RUBY2')
    require 'fileutils'
    module FileUtils
      class << self
        alias nx_orig_rm_f rm_f
        def rm_f(list, **opts)
          return nil if Array(list).any? { |p| File.basename(p.to_s) == 'noxun_engine.update.json' }

          nx_orig_rm_f(list, **opts)
        end
      end
    end
  RUBY2
  out = NxD52.boot!(env, preload: File.join(env[:root], 'stub_rm.rb'))
  NxTest.assert_equal('marker_stuck', out['status'], 'stav priznava nezmazany marker')
  NxTest.refute(out['registered'], 'plugin sa NENACITA — dalsi update by sa o marker zastavil')
  NxTest.assert(out['message'].include?('noxun_engine.update.json'),
                "hláška pomenuje súbor: #{out['message']}")
  FileUtils.rm_rf(env[:root])
end

# --- 6) dva procesy: zamok a lease -------------------------------------------

NxTest.test('D-52a: druhy proces dostane odmietnutie OKAMZITE a staging nemaze') do
  NxTest.skip!('potrebuje druhy OS proces') unless NxTest.headless?

  env = NxD52.sandbox
  plugins = env[:plugins]
  ready = File.join(env[:root], 'ready')
  go = File.join(env[:root], 'go')
  holder = NxD52.write(File.join(env[:root], 'holder.rb'), <<~RUBY)
    lock = #{File.join(plugins, 'noxun_engine.update.lock').inspect}
    File.open(lock, File::RDWR | File::CREAT, 0o644) do |f|
      f.flock(File::LOCK_EX)
      File.binwrite(#{ready.inspect}, 'x')
      120.times { break if File.exist?(#{go.inspect}); sleep 0.05 }
    end
  RUBY

  pid = Process.spawn(RbConfig.ruby, holder)
  200.times { break if File.exist?(ready); sleep 0.02 }
  NxTest.assert(File.exist?(ready), 'drziaci proces sa nespustil')

  # Staging „prveho" procesu — druhy ho NESMIE zmazat.
  sentinel = NxD52.write(File.join(plugins, 'noxun_engine.new', 'sentinel.txt'), 'drz ma')
  before = NxD52.fingerprint(plugins)

  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  err = NxTest.assert_raise('už beží v inom procese') { NxD52::U.apply!(env[:src], env[:tree]) }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0

  NxTest.assert(elapsed < 3.0, "odmietnutie trvalo #{elapsed.round(2)} s — zamok sa NESMIE cakat")
  NxTest.assert(File.exist?(sentinel), 'druhy proces NESMIE mazat staging prveho')
  NxTest.assert_equal(before, NxD52.fingerprint(plugins), 'ciel ostal nedotknuty')
  NxTest.refute(err.message.empty?, 'odmietnutie ma dovod')

  File.binwrite(go, 'x')
  Process.wait(pid)
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: lease — ziva ina instancia swap zastavi, mrtve lease sa upracu') do
  NxTest.skip!('potrebuje druhy OS proces') unless NxTest.headless?

  env = NxD52.sandbox
  plugins = env[:plugins]
  u = NxD52::U

  # Vlastny lease sa IGNORUJE — aktualizaciu robi prave tento proces.
  u.write_lease!(plugins)
  NxTest.assert(File.exist?(u.lease_path(plugins)), 'lease sa zapisal')
  NxTest.assert_equal([], u.live_leases(plugins), 'vlastny lease sam sebe neprekaza')

  # MRTVY PID: spusti a pockaj, kym proces skonci.
  dead = Process.spawn(RbConfig.ruby, '-e', '')
  Process.wait(dead)
  u.write_lease!(plugins, dead)
  NxTest.assert_equal([], u.live_leases(plugins), 'mrtvy PID nie je ziva instancia')
  NxTest.refute(File.exist?(u.lease_path(plugins, dead)), 'mrtve lease sa MUSI upratat')

  # ZIVY PID: druhy proces bezi, swap sa odmietne.
  go = File.join(env[:root], 'go2')
  holder = NxD52.write(File.join(env[:root], 'holder2.rb'),
                       "200.times { break if File.exist?(#{go.inspect}); sleep 0.05 }\n")
  alive = Process.spawn(RbConfig.ruby, holder)
  u.write_lease!(plugins, alive, 'SketchUp.exe')
  before = NxD52.fingerprint(plugins)
  # Stub identity: proces naozaj ZIJE (skutocny PID), tvarime sa len, ze je to
  # SketchUp — inak by ho kontrola z kola 3 spravne zahodila ako `ruby.exe`.
  NxD52.with_process_image(alive => 'SketchUp.exe') do
    NxTest.assert(u.live_leases(plugins).include?(alive), 'zivy PID sa musi najst')
    NxTest.assert_raise('ďalšia inštancia') { u.apply!(env[:src], env[:tree]) }
  end
  NxD52.assert_untouched(plugins, before, 'lease')

  File.binwrite(go, 'x')
  Process.wait(alive)
  u.drop_lease!(plugins)
  FileUtils.rm_rf(env[:root])
end

# --- 7) downgrade a rovnaka verzia -------------------------------------------

NxTest.test('D-52a: DOWNGRADE je zakazany a rovnaka verzia sa odmieta') do
  env = NxD52.sandbox('0.10.0', '0.9.9') # v priecinku je STARSIA verzia
  before = NxD52.fingerprint(env[:plugins])
  err = NxTest.assert_raise('downgrade') { NxD52::U.apply!(env[:src], env[:tree]) }
  NxTest.assert(err.message.include?('INSTALL'), 'odmietnutie povie, kade ide rucna cesta')
  NxD52.assert_untouched(env[:plugins], before, 'downgrade')
  FileUtils.rm_rf(env[:root])

  same = NxD52.sandbox('0.9.5', '0.9.5')
  before2 = NxD52.fingerprint(same[:plugins])
  NxTest.assert_raise('rovnaká verzia') { NxD52::U.apply!(same[:src], same[:tree]) }
  NxD52.assert_untouched(same[:plugins], before2, 'rovnaka verzia')
  FileUtils.rm_rf(same[:root])
end

NxTest.test('D-52a: nekonzistentny balik (loader vs main.rb) sa odmietne pred swapom') do
  env = NxD52.sandbox
  NxD52.write(File.join(env[:src], 'noxun_engine', 'main.rb'),
              "module Noxun\n  module Engine\n    VERSION = '0.9.7' unless defined?(VERSION)\n  end\nend\n")
  before = NxD52.fingerprint(env[:plugins])
  NxTest.assert_raise('nekonzistentný') { NxD52::U.apply!(env[:src], env[:tree]) }
  NxD52.assert_untouched(env[:plugins], before, 'nekonzistentny balik')
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52a: check cita VYHRADNE hlavicku zdroja a vracia trojstav') do
  env = NxD52.sandbox
  u = NxD52::U
  NxTest.assert_equal('newer', u.check(env[:src], '0.9.4')['state'])
  NxTest.assert_equal('same', u.check(env[:src], '0.9.5')['state'])
  NxTest.assert_equal('older', u.check(env[:src], '0.10.0')['state'])
  NxTest.assert_equal('0.9.5', u.check(env[:src], '0.9.4')['available'])

  bad = u.check(File.join(env[:root], 'nikde'), '0.9.4')
  NxTest.refute(bad['ok'], 'nedostupny zdroj nie je uspech')
  NxTest.assert_equal('error', bad['state'])
  NxTest.refute(bad['reason'].empty?, 'a nesie dovod')
  FileUtils.rm_rf(env[:root])
end

# --- 8) settings store -------------------------------------------------------

NxTest.test('D-52a: settings store nesie `std` a normalizuje cestu') do
  NxTest.skip!('zapisuje do %APPDATA% — v SketchUpe je zdielana so zivym pluginom') unless NxTest.headless?

  u = NxD52::U
  FileUtils.rm_f(u.path)
  FileUtils.rm_f("#{u.path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(u.path)
  NxTest.assert_equal('', u.source_dir, 'bez suboru je cesta prazdna')

  NxTest.assert_equal('C:/balik/noxun', u.set_source_dir('C:\\balik\\noxun\\'))
  raw = JSON.parse(File.binread(u.path))
  NxTest.assert_equal(1, raw['std'], 'subor nesie verziu formatu')
  NxTest.assert_equal('C:/balik/noxun', raw['source_dir'])
  Noxun::Engine::JsonFileStore.invalidate(u.path)
  NxTest.assert_equal('C:/balik/noxun', u.source_dir)
end

NxTest.test('D-52a: degradovana `.bak` zastavi zapisy nastavenia (R-11)') do
  NxTest.skip!('zapisuje do %APPDATA%') unless NxTest.headless?

  u = NxD52::U
  u.set_source_dir('C:/balik/v1')            # vznikne platny primar
  u.set_source_dir('C:/balik/v2')            # a z neho platna `.bak`
  File.binwrite(u.path, '{ toto nie je json')
  Noxun::Engine::JsonFileStore.invalidate(u.path)

  NxTest.assert(Noxun::Engine::JsonFileStore.degraded?(u.path), 'stav je degradovany')
  NxTest.assert(u.set_source_dir('C:/balik/v3').nil?, 'zapis nad degradovanym suborom sa MUSI odmietnut')
  NxTest.refute(u.write_block_reason.empty?, 'a povedat dovod')
  NxTest.assert(u.write_block_reason.include?('zálohy') || u.write_block_reason.include?('poškodené'),
                "dovod je zrozumitelny: #{u.write_block_reason}")

  FileUtils.rm_f(u.path)
  FileUtils.rm_f("#{u.path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(u.path)
end

# --- 9) guardy nad zdrojom ---------------------------------------------------

NxTest.test('D-52a: KAZDY vstupny bod pluginu ma restart latch') do
  root = NxTest::ROOT
  main = File.read(File.join(root, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  panel = File.read(File.join(root, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
  studio = File.read(File.join(root, 'noxun_engine', 'ui', 'studio_dialog.rb'), encoding: 'UTF-8')

  # Toolbar: kazdy prikaz musi guard volat v SVOJOM tele.
  blocks = main.scan(/UI::Command\.new\([^\n]*\n(?:.*?\n)??\s*end\b/m)
  cmds = main.scan(/UI::Command\.new\(/).length
  NxTest.assert_equal(4, cmds, 'toolbar ma styri prikazy (kontrakt N4)')
  NxTest.assert_equal(4, blocks.length, 'kazdy prikaz je viacriadkovy blok s guardom')
  blocks.each_with_index do |b, i|
    NxTest.assert(b.include?('update_restart_pending?'),
                  "toolbar prikaz #{i + 1} nema restart latch — po aktualizacii by otvoril okno nad novymi subormi")
  end

  {
    'Panel.show' => panel[/def show\b.*?(?=\n        def |\n      end\b)/m].to_s,
    'Panel.show_insert' => panel[/def show_insert\b.*?(?=\n        def |\n      end\b)/m].to_s,
    'StudioDialog.show' => studio[/def show\(open_section.*?(?=\n        def |\n      end\b)/m].to_s
  }.each do |name, body|
    NxTest.refute(body.empty?, "#{name} sa v zdrojaku nenasiel — uprav guard test")
    NxTest.assert(body.include?('update_restart_pending?'),
                  "#{name} nema restart latch (B2) — okno by sa otvorilo nad novymi subormi")
  end
end

NxTest.test('D-52a: recovery zije LEN v loaderi a VERSION kontrakt loadera ostava') do
  root = NxTest::ROOT
  loader = File.read(File.join(root, 'noxun_engine.rb'), encoding: 'UTF-8')
  mod = File.read(File.join(root, 'noxun_engine', 'core', 'updater.rb'), encoding: 'UTF-8')

  NxTest.assert(loader.include?('module Boot'), 'loader musi niest recovery sekciu')
  NxTest.assert(loader =~ /Boot\.recover!\(/, 'recovery sa musi pri starte NAOZAJ spustit')
  idx_boot = loader.index('Boot.recover!(')
  idx_ext = loader.index('Sketchup.register_extension')
  NxTest.assert(idx_boot < idx_ext,
                'recovery musi bezat PRED registraciou extensionu — strom sa nacitava az potom')

  # Recovery sa nesmie oprieť o strom pluginu (moze chybat).
  # Komentare sa odstrihnu — posudzuje sa KOD, nie odkazy v poznamkach.
  boot_code = loader[/module Boot\b.*?\n    end\n/m].to_s.lines.map { |l| l.sub(/#.*$/, '') }.join
  NxTest.refute(boot_code.empty?, 'recovery sekcia sa v loaderi nenasla')
  NxTest.refute(boot_code.include?('Sketchup.'), 'recovery nesmie volat SketchUp API')
  NxTest.refute(boot_code.include?('Updater'), 'recovery sa nesmie oprieť o modul zo stromu')
  NxTest.refute(boot_code.include?('Sketchup.require'), 'recovery nesmie nacitavat strom pluginu')

  # Modul recovery NEDUPLIKUJE — inak by sa obe kopie casom rozisli.
  NxTest.refute(mod.include?('def recover'), 'core/updater.rb nesmie mat vlastnu recovery vetvu')

  # VERSION kontrakt loadera: PRAVE JEDNA definicia a synchro s main.rb strazi
  # test_guards.rb; tu sa strazi, ze recovery sekcia ju nerozmnozila.
  hits = loader.scan(/^\s*VERSION\s*=\s*'[^']+'/).length
  NxTest.assert_equal(1, hits, "loader ma #{hits} definicii VERSION — musi byt PRAVE JEDNA")
  head = File.open(File.join(root, 'noxun_engine.rb'), 'rb') { |f| f.read(Noxun::Engine::Updater::VERSION_HEAD_BYTES) }
  NxTest.assert_equal(NxTest::LOADER_VERSION, Noxun::Engine::Updater.parse_version(head.force_encoding('UTF-8')),
                      'VERSION musi ostat v hlavicke loadera — inak ju updater neprecita')
end

NxTest.test('D-52a (#277/2): za krokom 3 vedie KAZDA chybova cesta cez abort_after_move!') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'updater.rb'), encoding: 'UTF-8')
  body = src[/def swap!.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'swap! sa v zdrojaku nenasiel — uprav guard test')

  # Rez presne v mieste, kde zacina platit pravidlo (A)/(B).
  after = body[/OD TEJTO CHVILE PLATI PRAVIDLO.*?COMMIT BOD/m].to_s
  NxTest.refute(after.empty?, 'v swap! chybaju znacky hranice invariantu')
  rescues = after.scan(/rescue StandardError/).length
  aborts = after.scan(/abort_after_move!/).length
  NxTest.assert(rescues >= 3, "medzi krokom 3 a commitom su len #{rescues} chranene kroky — cakalo sa 3+")
  NxTest.assert_equal(rescues, aborts,
                      'kazdy chyteny krok za krokom 3 MUSI koncit v abort_after_move! ' \
                      '(inak vznikne stav „strom vymeneny, latch vypnuty")')
  NxTest.refute(after.include?('raise Refused'),
                'za krokom 3 sa `raise Refused` nepise priamo — jediny vychod je abort_after_move!')

  abort_body = src[/def abort_after_move!.*?\n      end\n/m].to_s
  NxTest.assert(abort_body.include?('restore_previous_generation!'), 'abort najprv skusi plny rollback')
  NxTest.assert(abort_body.include?('Engine.restart_required!'),
                'a pri neuspesnom rollbacku zapina latch')
  # Dve vetvy hlasky: recovery zije v loaderi, takze bez neho je jedina pravdiva
  # rada INSTALL (swapom uz taky stav vzniknut nevie — zaloha je KOPIA).
  NxTest.assert(abort_body.include?('REŠTARTUJ'), 'vetva s pritomnym loaderom')
  NxTest.assert(abort_body.include?('INSTALL'), 'vetva s chybajucim loaderom')

  # Kolo 3: zaloha loadera je KOPIA + JEDINY atomicky replace-rename.
  NxTest.assert(body.include?('copy_file!(loader, loader_old)'),
                'zaloha loadera MUSI byt kopia — rename by nechal Plugins bez noxun_engine.rb')
  NxTest.refute(body.include?('File.rename(loader, loader_old)'),
                'rename `.rb -> .rb.old` je presne ta diera, ktoru kolo 3 zatvorilo')
  NxTest.assert_equal(1, body.scan(/File\.rename\(loader_new, loader\)/).length,
                      'vymena loadera je JEDEN atomicky krok')

  # `.old` je posledna kompletna kopia — maze sa na JEDNOM mieste, pod guardom.
  NxTest.assert_equal(1, src.scan(/rm_rf\(tree_old/).length,
                      '`.old` sa smie mazat len v discard_previous! (jedine miesto s guardom)')
  discard = src[/def discard_previous!.*?\n      end\n/m].to_s
  NxTest.assert(discard.include?('return false unless Dir.exist?(tree_path(plugins)) && File.file?(loader_path(plugins))'),
                'discard_previous! musi odmietnut mazat `.old`, kym nie je zivy strom AJ loader')
end

NxTest.test('D-52a (#277/3): recovery rozhoduje z OBSAHU a nikdy nemaze zivy loader') do
  loader = File.read(File.join(NxTest::ROOT, 'noxun_engine.rb'), encoding: 'UTF-8')
  boot = loader[/module Boot\b.*?\n    end\n/m].to_s
  NxTest.refute(boot.empty?, 'recovery sekcia sa nenasla')

  repair = boot[/def self\.repair!.*?\n      end\n/m].to_s
  NxTest.assert(repair.include?('loader_matches_tree?'),
                'o generacii loadera rozhoduje OBSAH (VERSION), nie pritomnost `.rb.new`')
  NxTest.refute(repair.include?('ldr_new'),
                'pritomnost `.rb.new` uz nesmie rozhodovat — zaloha je od kola 3 kopia')

  # V `Plugins` nesmie ani na okamih chybat bootovatelny loader, takze recovery
  # zivy `.rb` NIKDY nemaze; nova verzia sa nasadzuje atomickym prepisom.
  code = boot.lines.map { |l| l.sub(/#.*$/, '') }.join
  NxTest.refute(code.include?('rm_quiet(p[:ldr])'),
                'recovery nesmie mazat zivy loader — SketchUp by nemal co spustit')
  NxTest.assert(code.include?('File.rename(p[:ldr_old], p[:ldr])'),
                'stary loader sa vracia atomickym prepisom')

  # Kontrola generacie bezi VZDY, aj na ceste bez artefaktov.
  rec = boot[/def self\.recover!.*?\n      end\n/m].to_s
  NxTest.assert(rec.include?('generation_matches?'),
                'generation_matches? musi bezat aj ked `pending?` je false')
  NxTest.assert(rec.include?(':restart'), 'nesulad konci stavom :restart')
end

NxTest.test('D-52a (#277/2): loader a modul zapisuju lease v ROVNAKOM tvare') do
  loader = File.read(File.join(NxTest::ROOT, 'noxun_engine.rb'), encoding: 'UTF-8')
  mod = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'updater.rb'), encoding: 'UTF-8')
  NxTest.assert(loader.include?("LEASES_DIR = 'noxun_engine.leases'"), 'loader pozna priecinok lease')
  NxTest.assert(mod.include?("LEASES_DIR  = 'noxun_engine.leases'"), 'modul pozna ten isty priecinok')
  NxTest.assert(loader.include?('.lease"'), 'loader zapisuje <pid>.lease')
  NxTest.assert(mod.include?('.lease"'), 'modul cita/zapisuje ten isty tvar')

  # Lease uz NEZAPISUJE main.rb — bol by az po nacitani celeho stromu.
  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  NxTest.refute(main.include?('Updater.write_lease!'),
                'lease patri do LOADERA (zaciatok bootu), nie na koniec main.rb')
end

NxTest.test('D-52a: modul je CISTY — pri nacitani ziadny Sketchup./UI.') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'updater.rb'), encoding: 'UTF-8')
  offenders = []
  src.each_line.with_index do |line, i|
    code = line.sub(/#.*$/, '')
    next if code.include?('::UI.messagebox') || code.include?('::UI.respond_to?')

    offenders << (i + 1) if code =~ /(?<![:\w])Sketchup\./ || code =~ /(?<![:\w.])UI\./
  end
  NxTest.assert(offenders.empty?,
                "core/updater.rb sa dotyka SketchUp API na riadkoch #{offenders.join(', ')} — " \
                'jadro musi ostat headless (cesty chodia ako parametre)')
end

# --- D-52b (Codex #278 kolo 2, P1): ROZDELENIE `apply!` NA DVE FAZY ---------
#
# `prepare!` (manifest + staging + validacia) je od kola 2 WORKER-SAFE a bezi
# v UI vrstve vo vlakne; `commit!` (renamey) v hlavnom. Medzi fazami sa zamok
# PUSTA, takze jedina vec, ktora drzi exkluzivitu, je MARKER — a `commit!` musi
# trvat na tom, ze je NAS. Bez toho by sa dal commitnut cudzi (alebo starsi)
# staging.

NxTest.test('D-52b (#278/2 P1): `commit!` BEZ platnej pripravy ODMIETNE') do
  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  Noxun::Engine.reset_restart_latch!

  # (a) ziadny tiket
  NxTest.assert_raise('nie je pripravená') { NxD52::U.commit!(nil) }
  NxTest.assert_raise('nie je pripravená') { NxD52::U.commit!({}) }

  # (b) tiket bez pripravy na disku (nic sa nestagovalo)
  bogus = { 'plugins' => env[:plugins], 'from' => '0.9.4', 'to' => '0.9.5', 'stamp' => 'X' }
  err = NxTest.assert_raise { NxD52::U.commit!(bogus) }
  NxTest.assert(err.message.include?('neplatí'), "dovod: #{err.message}")
  NxD52.assert_untouched(env[:plugins], before, 'commit bez pripravy')

  # (c) REALNA priprava — tiket z nej PLATI, cudzi (zmenena verzia/peciatka) NIE
  ticket = NxD52::U.prepare!(env[:src], env[:tree])
  NxTest.assert_equal('0.9.5', ticket['to'], 'priprava vrati verziu STAGED balika')
  NxTest.assert(Dir.exist?(File.join(env[:plugins], 'noxun_engine.new')), 'a `.new` naozaj stoji')
  NxTest.assert(File.file?(File.join(env[:plugins], 'noxun_engine.update.json')), 'marker tiez')
  NxTest.assert(NxD52.generation(env[:plugins], 'po priprave') == '0.9.4',
                'ZIVA generacia je po priprave NEDOTKNUTA')

  foreign = ticket.merge('stamp' => 'cudzia-peciatka')
  err2 = NxTest.assert_raise { NxD52::U.commit!(foreign) }
  NxTest.assert(err2.message.include?('neplatí'), "cudzi tiket sa odmietne: #{err2.message}")
  NxTest.assert(Dir.exist?(File.join(env[:plugins], 'noxun_engine.new')),
                'a CUDZI staging sa pri tom NEMAZE')

  res = NxD52::U.commit!(ticket)
  NxTest.assert(res['ok'], 'nas tiket commitne')
  NxTest.assert_equal('0.9.5', NxD52.generation(env[:plugins], 'po commite'))
  NxTest.assert(Noxun::Engine.restart_required?, 'a latch je zapnuty')
  Noxun::Engine.reset_restart_latch!
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52b (#278/2 P1): `abort_prepared!` uprace `.new` aj marker') do
  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  Noxun::Engine.reset_restart_latch!

  ticket = NxD52::U.prepare!(env[:src], env[:tree])
  # Cudzi tiket neuprace NIC — inak by si dva behy zmazali staging navzajom.
  NxTest.refute(NxD52::U.abort_prepared!(ticket.merge('stamp' => 'ina')), 'cudzi tiket neuprace nic')
  NxTest.assert(Dir.exist?(File.join(env[:plugins], 'noxun_engine.new')), 'staging ostal')

  NxTest.assert(NxD52::U.abort_prepared!(ticket), 'nas tiket sa uprace')
  NxD52.assert_untouched(env[:plugins], before, 'po zruseni pripravy')
  NxTest.refute(Noxun::Engine.restart_required?, 'zrusena priprava latch NEZAPINA')

  # A po zruseni sa da skusit ZNOVA (marker uz nebrzdi).
  res = NxD52::U.apply!(env[:src], env[:tree])
  NxTest.assert(res['ok'], 'druhy pokus po zruseni prejde')
  Noxun::Engine.reset_restart_latch!
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52b (#278/2 P1): `prepare!` sa ZIVEJ generacie NEDOTYKA') do
  env = NxD52.sandbox
  before = NxD52.fingerprint(env[:plugins])
  Noxun::Engine.reset_restart_latch!

  ticket = NxD52::U.prepare!(env[:src], env[:tree])
  live = NxD52.fingerprint(env[:plugins])
  NxTest.assert_equal(before, live,
                      'priprava (manifest + staging) meni VYHRADNE `.new` — ziva generacia je ' \
                      'byte-identicka, takze zrusenie po deadline je bez nasledkov')
  NxD52::U.abort_prepared!(ticket)
  FileUtils.rm_rf(env[:root])
end

NxTest.test('D-52b1 (#278/3 P2): settings store nezmrza KORENOVE cesty') do
  NxTest.skip!('zapisuje do %APPDATA%') unless NxTest.headless?

  u = NxD52::U
  # `chomp('/')` nad korenom dava nepouzitelnu cestu — a vsetky tri tvary sa
  # daju do pola distribucneho priecinka realne napisat (najma UNC share).
  NxTest.assert_equal('//server/share', u.normalize_source('\\\\server\\share'),
                      'UNC koren zdielania ostava korenom')
  NxTest.assert_equal('//server/share', u.normalize_source('//server/share/'),
                      'aj s koncovym lomitkom')
  NxTest.assert_equal('D:/', u.normalize_source('D:\\'), 'koren disku ostava korenom')
  NxTest.assert_equal('/', u.normalize_source('/'), 'POSIX koren tiez')
  # Beznej ceste sa koncove lomitko STALE strihá (inak by sa ta ista cesta
  # ulozila raz s nim a raz bez neho a doklad o kontrole by sa nezhodoval).
  NxTest.assert_equal('//server/share/dist', u.normalize_source('//server/share/dist/'),
                      'priecinok v zdielani sa normalizuje ako doteraz')
  NxTest.assert_equal('D:/balik', u.normalize_source('D:\\balik\\'), 'a to isté na disku')

  # A to iste PLATI AJ PRI ZAPISE (store si tvar nesmie prerobit po svojom).
  NxTest.assert_equal('//server/share', u.set_source_dir('\\\\server\\share'),
                      'ulozenie vracia korenovy tvar')
  NxTest.assert_equal('//server/share', u.source_dir, 'a nacita sa rovnako')
  u.set_source_dir('')
end
