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
#         „D-52a: KAZDY vstupny bod pluginu ma restart latch".
#
# CELA SADA BEZI NAD TEMP SANDBOXOM — nikdy nad zivym `Plugins` priecinkom.
# Testy, ktore spustaju druhy Ruby proces alebo zapisuju do %APPDATA%, sa
# v SketchUpe PRESKOCIA (`RbConfig.ruby` tam nie je samostatny interpreter
# a APPDATA je zdielana so zivym pluginom).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'
require 'rbconfig'

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
  def with_rename_trap(from_base, to_base)
    sc = File.singleton_class
    sc.send(:alias_method, :nx_d52_orig_rename, :rename)
    sc.send(:define_method, :rename) do |src, dst|
      if File.basename(src.to_s) == from_base && File.basename(dst.to_s) == to_base
        raise Errno::EACCES, "test trap #{from_base} -> #{to_base}"
      end

      nx_d52_orig_rename(src, dst)
    end
    yield
  ensure
    sc.send(:remove_method, :rename)
    sc.send(:alias_method, :rename, :nx_d52_orig_rename)
    sc.send(:remove_method, :nx_d52_orig_rename)
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
  def boot!(env)
    stubs = File.join(env[:root], 'stubs')
    write(File.join(stubs, 'sketchup.rb'),
          "module Sketchup\n  def self.register_extension(*)\n    true\n  end\nend\n")
    write(File.join(stubs, 'extensions.rb'),
          "class SketchupExtension\n  attr_accessor :description, :version, :creator, :copyright\n" \
          "  def initialize(*); end\nend\n")
    script = File.join(env[:root], 'boot.rb')
    write(script, "$LOAD_PATH.unshift(#{stubs.inspect})\nload #{File.join(env[:plugins], 'noxun_engine.rb').inspect}\n")
    IO.popen([RbConfig.ruby, script], err: %i[child out], &:read).to_s
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
    when 'loader_swapped' # krok 5 hotovy, `.old` este nie je upratany
      File.rename(tree, tree_old)
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree)
      File.rename(ldr, "#{ldr}.old")
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), ldr)
    when 'before_cleanup' # to iste, ale marker uz hlasi `done`
      File.rename(tree, tree_old)
      FileUtils.cp_r(File.join(new_pkg, 'noxun_engine'), tree)
      File.rename(ldr, "#{ldr}.old")
      FileUtils.cp(File.join(new_pkg, 'noxun_engine.rb'), ldr)
    else
      raise ArgumentError, state
    end

    marker = { 'std' => 1, 'state' => state == 'tree_moved' ? 'staged' : (state == 'before_cleanup' ? 'done' : state),
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

{
  'staged' => '0.9.4',        # swap sa nezacal -> plati STARA generacia
  'tree_moved' => '0.9.4',    # pad MEDZI krokom 3 a 4 -> STARA generacia
  'tree_swapped' => '0.9.5',  # krok 4 presiel -> transakcia sa DOKONCI
  'loader_swapped' => '0.9.5',
  'before_cleanup' => '0.9.5'
}.each do |state, expected|
  NxTest.test("D-52a: pad v stave #{state} — boot da jednu kompletnu generaciu (#{expected})") do
    NxTest.skip!('recovery sa overuje skutocnym nacitanim loadera v druhom Ruby procese') unless NxTest.headless?

    env = NxD52.sandbox
    NxD52.crash_state!(env, state)
    out = NxD52.boot!(env)
    NxTest.assert(out.to_s !~ /recovery aktualizacie zlyhala/,
                  "recovery hlasila chybu: #{out.to_s.lines.first(3).join(' ')}")
    NxTest.assert_equal(expected, NxD52.generation(env[:plugins], "boot po pade (#{state})"))
    rest = NxD52.leftovers(env[:plugins])
    NxTest.assert(rest.empty?, "po recovery ostali zvysky #{rest.join(', ')}")

    # Druhy boot uz nema co robit a nic nerozbije.
    NxD52.boot!(env)
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
  NxTest.refute(out.to_s.include?('nedokoncena aktualizacia'), 'bezny start nema co dorovnavat')
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
  u.write_lease!(plugins, alive)
  before = NxD52.fingerprint(plugins)
  NxTest.assert(u.live_leases(plugins).include?(alive), 'zivy PID sa musi najst')
  NxTest.assert_raise('ďalšia inštancia') { u.apply!(env[:src], env[:tree]) }
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
