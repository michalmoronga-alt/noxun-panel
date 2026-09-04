# frozen_string_literal: true
# NASTROJE-1 (T1b): BOOT MIGRACIA STARYCH INSTALACII Mower/Snaper.
#
# CO SA DOKAZUJE:
#   * vsetky styri legacy ciele (subory AJ priecinky) po `run!` zmiznu a marker
#     nesie kluc TEJTO Plugins cesty so zoznamom odstraneneho;
#   * druhy beh nad tou istou cestou uz nerobi NIC (idempotencia);
#   * druha instalacia SketchUpu (iny Plugins koren nad TYM ISTYM app-data)
#     sa uprace samostatne — v markeri su POTOM dva kluce;
#   * kluc je NORMALIZOVANY: `\` vs `/`, koncove lomitko a velkost pismen
#     ukazuju na ten isty zaznam (inak by sa migracia opakovala donekonecna);
#   * „mazanie vratilo bez vynimky, ale cesta ostala" (presne to robi `rm_rf`)
#     NEZAPISE kluc a vysledok nesie stav `failed` s cestami;
#   * chybajuce legacy = kluc s PRAZDNYM `removed` (migracia bezi aj tak, aby
#     sa cista instalacia neprehladavala pri kazdom boote);
#   * poskodeny marker boot NEZHODI — cita sa `.bak`, inak sa zalozi novy;
#   * vynimka v migracii NEUTECIE k volajucemu (boot enginu je nedotknutelny);
#   * cudzie subory v Plugins sa NEDOTKNU;
#   * SUBOH DVOCH PROCESOV (Codex #295 P2): kym nas boot caka na zamok, cudzi
#     proces zapise svoj kluc PRIAMO na disk — po nasom zapise musi marker
#     niest OBA (citaj-zluc-zapis cele pod zamkom + zahodena cache store-u).
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. kluc sa zapise aj pri zlyhanom mazani (postkontrola vyhodena)
#      -> „T1b: mazanie bez vynimky, ale cesta OSTALA = NIE je hotovo";
#   2. marker je jeden zdielany priznak bez cesty Plugins (`done` = bool)
#      -> „T1b: druha instalacia SketchUpu sa uprace SAMOSTATNE";
#   3. `rescue` v `run!` odstraneny (vynimka uteka von)
#      -> „T1b: vynimka v migracii NEZHODI volajuceho";
#   4. citanie a zlucenie markera SPAT pred zamok (stav pred Codex #295 P2)
#      -> „T1b: sucasny boot druheho procesu NEPRIDE o svoj kluc".
#
# CELA SADA BEZI NAD DOCASNYM `Plugins` STROMOM — nikdy nad zivym priecinkom
# SketchUpu. Marker sa vzdy podava ako parameter do TEMP suboru, takze sa
# nedotkne ani realneho `%APPDATA%\NOXUN\Engine`.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'
require 'json'
require 'rbconfig'

LC = Noxun::Engine::Tools::LegacyCleanup

module NxT1b
  module_function

  # Docasny sandbox: `<root>/plugins` (ciel) + `<root>/marker.json`.
  def sandbox
    root = File.realpath(Dir.mktmpdir('nx-t1b-')).tr('\\', '/')
    plugins = File.join(root, 'plugins')
    FileUtils.mkdir_p(plugins)
    { root: root, plugins: plugins, marker: File.join(root, 'marker.json') }
  end

  # Presne tie styri ciele, ktore realna instalacia ma: dva loadery a dva stromy.
  def seed_legacy!(plugins)
    File.binwrite(File.join(plugins, 'noxun_mower_loader.rb'), "require 'Noxun_Mower/loader'\n")
    FileUtils.mkdir_p(File.join(plugins, 'Noxun_Mower', 'icons'))
    File.binwrite(File.join(plugins, 'Noxun_Mower', 'loader.rb'), "# legacy\n")
    File.binwrite(File.join(plugins, 'Noxun_Mower', 'icons', 'rot.png'), 'x')
    File.binwrite(File.join(plugins, 'snaper.rb'), "# legacy loader\n")
    FileUtils.mkdir_p(File.join(plugins, 'snaper'))
    File.binwrite(File.join(plugins, 'snaper', 'main.rb'), "# legacy\n")
    plugins
  end

  def alive(plugins)
    LC::TARGETS.select { |n| File.exist?(File.join(plugins, n)) }
  end

  def marker_done(path)
    raw = JSON.parse(File.binread(path))
    raw['done']
  end

  # Pasca na mazanie: `rm_rf` sa vrati BEZ vynimky, ale cesta ostane lezat.
  # Presne tak sa sprava zamknuty subor na Windowse.
  def with_dead_rm(match)
    FileUtils.singleton_class.send(:alias_method, :nx_t1b_orig_rm_rf, :rm_rf)
    FileUtils.singleton_class.send(:define_method, :rm_rf) do |list, **opts|
      return nil if Array(list).any? { |p| p.to_s.include?(match) }

      nx_t1b_orig_rm_rf(list, **opts)
    end
    yield
  ensure
    sc = FileUtils.singleton_class
    if sc.method_defined?(:nx_t1b_orig_rm_rf) || sc.private_method_defined?(:nx_t1b_orig_rm_rf)
      sc.send(:remove_method, :rm_rf)
      sc.send(:alias_method, :rm_rf, :nx_t1b_orig_rm_rf)
      sc.send(:remove_method, :nx_t1b_orig_rm_rf)
    end
  end
end

# --- (1) plny prechod ---------------------------------------------------------

NxTest.test('T1b: vsetky STYRI legacy ciele zmiznu a marker nesie kluc TEJTO cesty') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    # Cudzi plugin je kontrola blast radiusu — zoznam cielov je uzavrety.
    File.binwrite(File.join(env[:plugins], 'ladb_opencutlist.rb'), "# cudzi\n")

    res = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('done', res['state'])
    NxTest.assert(res['ok'], 'uspesna migracia musi byt ok')
    NxTest.assert_equal(LC::TARGETS.sort, res['removed'].sort)
    NxTest.assert_equal([], NxT1b.alive(env[:plugins]))
    NxTest.assert(File.exist?(File.join(env[:plugins], 'ladb_opencutlist.rb')),
                  'cudzi plugin sa NESMIE zmazat')

    done = NxT1b.marker_done(env[:marker])
    key = LC.normalize_key(env[:plugins])
    NxTest.assert(done.key?(key), "marker nema kluc #{key}: #{done.keys.inspect}")
    NxTest.assert_equal(LC::TARGETS.sort, done[key]['removed'].sort)
    NxTest.assert(done[key]['at'].to_s =~ /\A\d{4}-\d{2}-\d{2}T/, 'kluc nema casovu peciatku')
    NxTest.assert_equal(LC::STD, JSON.parse(File.binread(env[:marker]))['std'])
    # Hlaska je jednorazova a hovori o RESTARTE — legacy toolbary ostavaju v
    # pamati beziaceho SketchUpu.
    NxTest.assert(LC.message_for(res).include?('reštarte'), 'hlaska musi pytat restart')
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- (2) idempotencia ---------------------------------------------------------

NxTest.test('T1b: druhy beh nad tou istou cestou uz nerobi NIC') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    LC.run!(env[:plugins], marker_path: env[:marker])

    # Legacy sa medzitym „vratilo" (rucna reinstalacia stareho pluginu). Marker
    # uz cestu pozna, takze migracia sa jej NEDOTKNE — je to jednorazova
    # migracia, nie strazca priecinka.
    NxT1b.seed_legacy!(env[:plugins])
    again = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('skipped', again['state'])
    NxTest.assert_equal([], again['removed'])
    NxTest.assert_equal(LC::TARGETS.sort, NxT1b.alive(env[:plugins]).sort)
    NxTest.assert_equal('', LC.message_for(again), 'preskocena migracia nesmie nic hlasit')
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- (3) dve instalacie SketchUpu nad jednym app-data --------------------------

NxTest.test('T1b: druha instalacia SketchUpu sa uprace SAMOSTATNE (dva kluce)') do
  env = NxT1b.sandbox
  begin
    second = File.join(env[:root], 'plugins2026')
    FileUtils.mkdir_p(second)
    NxT1b.seed_legacy!(env[:plugins])
    NxT1b.seed_legacy!(second)

    first = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('done', first['state'])
    # Kluc prvej cesty NESMIE upratat druhu instalaciu.
    NxTest.assert_equal(LC::TARGETS.sort, NxT1b.alive(second).sort)

    other = LC.run!(second, marker_path: env[:marker])
    NxTest.assert_equal('done', other['state'])
    NxTest.assert_equal([], NxT1b.alive(second))

    done = NxT1b.marker_done(env[:marker])
    NxTest.assert_equal(2, done.keys.length, "marker ma kluce #{done.keys.inspect}")
    NxTest.assert(done.key?(LC.normalize_key(env[:plugins])) && done.key?(LC.normalize_key(second)),
                  'marker nema kluc oboch instalacii')
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

NxTest.test('T1b: kluc je NORMALIZOVANY — koncove lomitko (a na Windowse aj `\\` a velkost pismen)') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    LC.run!(env[:plugins], marker_path: env[:marker])
    key = LC.normalize_key(env[:plugins])

    # Koncove lomitko odstrani `File.expand_path` na KAZDEJ platforme, takze
    # cely prechod cez `run!` sa da overit prenosne.
    NxTest.assert_equal(key, LC.normalize_key("#{env[:plugins]}/"))
    NxTest.assert_equal('skipped', LC.run!("#{env[:plugins]}/", marker_path: env[:marker])['state'])

    # `\` ako oddelovac a case-insensitivita su vlastnosti WINDOWS filesystemu
    # — cielovej platformy pluginu. Na Linuxe (CI) je `\` bezny znak v mene a
    # `/TMP/...` je INA cesta, takze by sa tam netestovala normalizacia, ale
    # rozdiel platforiem. Kluc je cista funkcia, preto sa testuje priamo.
    if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
      NxTest.assert_equal(key, LC.normalize_key(env[:plugins].tr('/', '\\')))
      NxTest.assert_equal(key, LC.normalize_key(env[:plugins].upcase))
      NxTest.assert_equal('skipped', LC.run!(env[:plugins].upcase, marker_path: env[:marker])['state'])
    end

    NxTest.assert_equal(1, NxT1b.marker_done(env[:marker]).keys.length,
                        'ta ista cesta v inom zapise vyrobila DALSI kluc')
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- (4) zlyhanie mazania = NIE je hotovo -------------------------------------

NxTest.test('T1b: mazanie bez vynimky, ale cesta OSTALA = NIE je hotovo') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    res = NxT1b.with_dead_rm('snaper.rb') do
      LC.run!(env[:plugins], marker_path: env[:marker])
    end

    NxTest.assert_equal('failed', res['state'])
    NxTest.assert(!res['ok'], 'zlyhana migracia nesmie hlasit ok')
    NxTest.assert(res['failed'].any? { |p| p.end_with?('snaper.rb') },
                  "vysledok neuvadza cestu, ktora ostala: #{res['failed'].inspect}")
    NxTest.assert(!File.exist?(env[:marker]), 'kluc sa zapisal napriek zlyhaniu mazania')
    NxTest.assert(LC.message_for(res).include?('snaper.rb'),
                  'hlaska o zlyhani musi niest konkretnu cestu')

    # Dalsi boot uz prekazku nema — migracia sa ZOPAKUJE a dokonci.
    retry_res = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('done', retry_res['state'])
    NxTest.assert_equal([], NxT1b.alive(env[:plugins]))
    NxTest.assert(NxT1b.marker_done(env[:marker]).key?(LC.normalize_key(env[:plugins])))
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- (5) cista instalacia -----------------------------------------------------

NxTest.test('T1b: cista instalacia dostane kluc s PRAZDNYM removed a nic nehlasi') do
  env = NxT1b.sandbox
  begin
    res = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('done', res['state'])
    NxTest.assert_equal([], res['removed'])
    NxTest.assert_equal('', LC.message_for(res), 'bez odstraneneho sa nic nehlasi')

    done = NxT1b.marker_done(env[:marker])
    NxTest.assert_equal([], done[LC.normalize_key(env[:plugins])]['removed'])
    NxTest.assert_equal('skipped', LC.run!(env[:plugins], marker_path: env[:marker])['state'])
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- (6) poskodeny marker -----------------------------------------------------

NxTest.test('T1b: poskodeny marker BEZ zalohy boot nezhodi — zalozi sa novy') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    File.binwrite(env[:marker], '{ toto nie je JSON')
    Noxun::Engine::JsonFileStore.reload!(env[:marker])

    res = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('done', res['state'])
    NxTest.assert_equal([], NxT1b.alive(env[:plugins]))
    NxTest.assert(NxT1b.marker_done(env[:marker]).key?(LC.normalize_key(env[:plugins])),
                  'novy marker nema kluc tejto cesty')
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

NxTest.test('T1b: poskodeny marker s platnou `.bak` si zaznamenane cesty PONECHA') do
  env = NxT1b.sandbox
  begin
    second = File.join(env[:root], 'plugins2026')
    FileUtils.mkdir_p(second)
    NxT1b.seed_legacy!(env[:plugins])
    NxT1b.seed_legacy!(second)

    LC.run!(env[:plugins], marker_path: env[:marker])
    # `.bak` vznikne az pri DRUHOM zapise (prvy nema co zalohovat).
    LC.run!(second, marker_path: env[:marker])
    NxTest.assert(File.exist?("#{env[:marker]}.bak"), 'zaloha markera nevznikla')

    File.binwrite(env[:marker], 'rozbite')
    Noxun::Engine::JsonFileStore.reload!(env[:marker])
    # Zaloha pozna aspon prvu cestu — tá sa uz nesmie upratovat druhykrat.
    NxT1b.seed_legacy!(env[:plugins])
    res = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('skipped', res['state'])
    NxTest.assert_equal(LC::TARGETS.sort, NxT1b.alive(env[:plugins]).sort)
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- (7) migracia nikdy nezhodi boot ------------------------------------------

NxTest.test('T1b: vynimka v migracii NEZHODI volajuceho') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    sc = LC.singleton_class
    sc.send(:alias_method, :nx_t1b_orig_present, :present?)
    sc.send(:define_method, :present?) { |_t| raise Errno::EACCES, 'test' }
    res = LC.run!(env[:plugins], marker_path: env[:marker])
    NxTest.assert_equal('error', res['state'])
    NxTest.assert(!res['ok'], 'chybova migracia nesmie hlasit ok')
    NxTest.assert_equal('', LC.message_for(res), 'vnutorna chyba nie je hlaska pre pouzivatela')
  ensure
    sc = LC.singleton_class
    if sc.method_defined?(:nx_t1b_orig_present) || sc.private_method_defined?(:nx_t1b_orig_present)
      sc.send(:remove_method, :present?)
      sc.send(:alias_method, :present?, :nx_t1b_orig_present)
      sc.send(:remove_method, :nx_t1b_orig_present)
    end
    FileUtils.rm_rf(env[:root])
  end
end

NxTest.test('T1b: neexistujuci alebo prazdny priecinok Plugins skonci chybou BEZ zapisu') do
  env = NxT1b.sandbox
  begin
    ghost = LC.run!(File.join(env[:root], 'niet'), marker_path: env[:marker])
    NxTest.assert_equal('error', ghost['state'])
    NxTest.assert(ghost['reason'].include?('niet'), "dovod neuvadza cestu: #{ghost['reason']}")
    NxTest.assert_equal('error', LC.run!('  ', marker_path: env[:marker])['state'])
    NxTest.assert(!File.exist?(env[:marker]), 'odmietnuta migracia zapisala marker')
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- (8) suboh dvoch procesov nad zdielanym markerom (Codex #295 P2) ---------

# Cudzi PROCES zapisuje PRIAMO na disk — nasa `JsonFileStore` cache o tom nevie.
# Stub `with_catalog_lock` zrkadli realne casovanie: kym prvy proces caka na
# zamok, druhy stihne dokoncit svoj zapis.
module NxT1b
  module_function

  def with_foreign_write(marker, done_payload)
    sc = LC.singleton_class
    sc.send(:alias_method, :nx_t1b_orig_lock, :with_catalog_lock)
    sc.send(:define_method, :with_catalog_lock) do |&blk|
      File.binwrite(marker, JSON.pretty_generate('std' => LC::STD, 'done' => done_payload))
      nx_t1b_orig_lock(&blk)
    end
    yield
  ensure
    sc = LC.singleton_class
    if sc.method_defined?(:nx_t1b_orig_lock) || sc.private_method_defined?(:nx_t1b_orig_lock)
      sc.send(:remove_method, :with_catalog_lock)
      sc.send(:alias_method, :with_catalog_lock, :nx_t1b_orig_lock)
      sc.send(:remove_method, :nx_t1b_orig_lock)
    end
  end
end

NxTest.test('T1b: sucasny boot druheho procesu NEPRIDE o svoj kluc (citaj-zluc-zapis pod zamkom)') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    other = '/c/sketchup 2025/plugins'
    older = '/c/sketchup 2024/plugins'

    # Marker uz nieco obsahuje — `run!` si ho precita hned na zaciatku (kontrola
    # `skipped`) a tym si NAPLNI sekundovu cache `JsonFileStore`.
    File.binwrite(env[:marker], JSON.pretty_generate(
                                  'std' => LC::STD,
                                  'done' => { older => { 'at' => '2026-09-01T00:00:00Z', 'removed' => [] } }
                                ))
    Noxun::Engine::JsonFileStore.reload!(env[:marker])

    # Kym nas proces caka na zamok, CUDZI proces zapise svoj kluc priamo na disk.
    res = NxT1b.with_foreign_write(env[:marker],
                                   older => { 'at' => '2026-09-01T00:00:00Z', 'removed' => [] },
                                   other => { 'at' => '2026-09-04T00:00:00Z', 'removed' => ['snaper.rb'] }) do
      LC.run!(env[:plugins], marker_path: env[:marker])
    end
    NxTest.assert_equal('done', res['state'])

    done = NxT1b.marker_done(env[:marker])
    NxTest.assert(done.key?(LC.normalize_key(env[:plugins])), 'chyba kluc NASEJ instalacie')
    NxTest.assert(done.key?(other),
                  'kluc SUCASNE bootujuceho procesu sa stratil — marker sa cita pred zamkom ' \
                  "alebo zo stale cache (#{done.keys.inspect})")
    NxTest.assert(done.key?(older), "stratil sa starsi kluc (#{done.keys.inspect})")
    NxTest.assert_equal(['snaper.rb'], done[other]['removed'], 'cudzi zaznam sa prepisal')
    NxTest.assert_equal(3, done.keys.length, "marker ma kluce #{done.keys.inspect}")
  ensure
    FileUtils.rm_rf(env[:root])
  end
end

# --- kontrakt zoznamu cielov ---------------------------------------------------

NxTest.test('T1b: zoznam cielov je UZAVRETY a doslovny (styri cesty)') do
  NxTest.assert_equal(%w[noxun_mower_loader.rb Noxun_Mower snaper.rb snaper], LC::TARGETS)
  # Instalator maze TIE ISTE cesty — druhy kanal sa nesmie rozist s prvym.
  ps1 = File.binread(File.join(NxTest::ROOT, 'INSTALL_noxun_engine.ps1')).force_encoding(Encoding::UTF_8)
  line = ps1[/^\$legacyTargets\s*=.*$/].to_s
  LC::TARGETS.each do |name|
    NxTest.assert(line.include?("'#{name}'"),
                  "INSTALL_noxun_engine.ps1 nemaze #{name} — kanaly sa rozisli")
  end
end

NxTest.test('T1b: instalator uz NEPONUKA zivy `load` a konci restartom') do
  ps1 = File.binread(File.join(NxTest::ROOT, 'INSTALL_noxun_engine.ps1')).force_encoding(Encoding::UTF_8)
  # Komentar smie o zaniknutom hinte HOVORIT (a vysvetlit preco) — zakazany je
  # len VYKONNY riadok, ktory ho pouzivatelovi este ponuka.
  live = ps1.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert(!live.include?('load "noxun_engine.rb"'),
                'instalator stale ponuka zivy load — po uprataní by toolbar nezaregistroval')
  NxTest.assert(ps1.include?('Restartuj SketchUp.'), 'instalator nekonci pokynom na restart')
  # „HOTOVO" smie zaznit LEN vo vetve bez zlyhanych cielov.
  NxTest.assert(ps1 =~ /if \(\$legacyFailed\.Count -gt 0\)/,
                'instalator nema vetvu pre zlyhanu postkontrolu legacy cielov')
end

# --- boot hook ------------------------------------------------------------------

NxTest.test('T1b: main.rb spusta migraciu PRED registraciou toolbaru') do
  src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb')).force_encoding(Encoding::UTF_8)
  # Boot vola VYSLOVNE `boot!` — ten si zapamata POUZITU cestu markera. `run!`
  # by ju nechal na neskorsom dopocitani (`path`), ktore uz moze ukazovat inam
  # (test override, sandbox APPDATA).
  cleanup_at = src.index('Tools::LegacyCleanup.boot!')
  toolbar_at = src.index('install_toolbar # UI-02')
  tools_at = src.index('Tools.install!(menu)')
  NxTest.assert(cleanup_at, 'main.rb nevola boot migraciu')
  NxTest.assert(toolbar_at && tools_at, 'main.rb nema registraciu toolbarov')
  NxTest.assert(cleanup_at < toolbar_at && cleanup_at < tools_at,
                'migracia bezi AZ PO registracii toolbaru — legacy by sa upratalo o boot neskor')
  NxTest.assert(src.include?("Sketchup.require 'noxun_engine/tools/legacy_cleanup'"),
                'main.rb nenacitava tools/legacy_cleanup')
end

NxTest.test('T1b: `boot!` si zapamata VYSLEDOK aj POUZITU cestu markera') do
  env = NxT1b.sandbox
  begin
    NxT1b.seed_legacy!(env[:plugins])
    # Cestu markera si `boot!` vyberie SAM z `path` — a prave tu si musi
    # zapamatat. Neskorsie presmerovanie `Materials.dir` (test override, sandbox
    # APPDATA in-SU runnera) uz o nej nic nevie, takze kto sa spyta `path` az
    # potom, hlada kluc v subore, ktory nikdy nevznikol.
    expected = LC.path
    res = LC.boot!(env[:plugins])
    NxTest.assert_equal('done', res['state'])
    NxTest.assert_equal(res, LC.boot_result)
    NxTest.assert_equal(expected, LC.boot_marker_path)
    NxTest.assert_equal(LC.normalize_key(env[:plugins]), LC.boot_result['plugins'])
    NxTest.assert(File.exist?(LC.boot_marker_path), 'boot nezapisal marker na zapamatanu cestu')
    NxTest.assert(NxT1b.marker_done(LC.boot_marker_path).key?(LC.normalize_key(env[:plugins])),
                  'marker na zapamatanej ceste nenesie kluc bootovanej instalacie')

    # Testy (a in-SU sekcie) volajuce `run!` priamo zaznam NEPREPISU.
    second = File.join(env[:root], 'plugins2026')
    FileUtils.mkdir_p(second)
    LC.run!(second, marker_path: env[:marker])
    NxTest.assert_equal(expected, LC.boot_marker_path, '`run!` prepisal boot zaznam')
    NxTest.assert_equal(LC.normalize_key(env[:plugins]), LC.boot_result['plugins'])
  ensure
    FileUtils.rm_rf(env[:root])
  end
end
