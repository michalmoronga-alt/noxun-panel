# frozen_string_literal: true
# Guard nastroja na fotenie okien (davka H2, blok 9 HARDENING, D-10): scripts/ui_foto.ps1
# + scripts/ui_foto/*. Nastroj nie je sucast pluginu — test strazi, aby:
#   (a) prehravac (nx_stub.js) sa NIKDY nedostal do noxun_engine/ui (vklada sa len do
#       docasnej kopie v %TEMP%) a obe stranky mali <meta charset>, za ktory sa vklada,
#   (b) zoznam fotiek (shots.json) presne kryl sekcie Studia (StudioDialog::SECTIONS)
#       a znacky, ktore zapisuje nahravka (record.rb) — nova sekcia bez fotky = FAIL,
#   (c) skript zdielal zamok s in-SU runnerom a bol cisto ASCII (Windows PowerShell 5.1
#       cita .ps1 bez BOM v systemovej kodovej stranke — diakritika by sa rozbila).
# Vyber suborov nahravky (upto/kind) testuje tests/js/test_ui_foto_stub.js.
require 'json'
require_relative '../helper' unless defined?(NxTest)

module NxUiFotoTest
  ROOT = NxTest::ROOT
  TOOL = File.join(ROOT, 'scripts', 'ui_foto')

  def self.read(*parts)
    File.binread(File.join(ROOT, *parts)).force_encoding('UTF-8')
  end

  def self.shots
    JSON.parse(read('scripts', 'ui_foto', 'shots.json'))
  end

  def self.studio_sections
    src = read('noxun_engine', 'ui', 'studio_dialog.rb')
    m = src.match(/SECTIONS\s*=\s*%w\[([^\]]*)\]/)
    m ? m[1].split : []
  end
end

NxTest.test('ui_foto: prehravac nx_stub.js nie je v noxun_engine/ui (ani odkaz v HTML)') do
  ui = File.join(NxUiFotoTest::ROOT, 'noxun_engine', 'ui')
  stray = Dir.glob(File.join(ui, '**', '*')).select { |f| File.basename(f).downcase.include?('nx_stub') }
  NxTest.assert(stray.empty?, "stub v plugine: #{stray.join(', ')}")
  Dir.glob(File.join(ui, '**', '*.{html,js}')).each do |f|
    txt = File.binread(f)
    NxTest.refute(txt.include?('nx_stub') || txt.include?('__nx_report') || txt.include?('__nxReplay'),
                  "prehravac fotenia v plugine: #{f.sub(NxUiFotoTest::ROOT, '')}")
  end
end

NxTest.test('ui_foto: studio.html aj panel.html maju <meta charset> (miesto vlozenia stubu)') do
  %w[studio.html panel.html].each do |page|
    html = NxUiFotoTest.read('noxun_engine', 'ui', page)
    NxTest.assert(html =~ /<meta\s+charset="[^"]*"\s*\/?>/i, "#{page}: chyba <meta charset=\"...\">")
  end
end

NxTest.test('ui_foto: shots.json kryje vsetky sekcie Studia v poradi StudioDialog::SECTIONS') do
  sections = NxUiFotoTest.studio_sections
  NxTest.assert(sections.length >= 10, "SECTIONS sa nepodarilo precitat (#{sections.length})")
  studio = NxUiFotoTest.shots['shots'].select { |s| s['kind'] == 'studio' }
  NxTest.assert_equal(sections.map { |s| "studio_#{s}" }, studio.map { |s| s['id'] },
                      'fotky Studia != StudioDialog::SECTIONS (nova sekcia? doplnit shots.json)')
  studio.each do |s|
    NxTest.assert_equal(s['id'], s['upto'], "#{s['id']}: upto musi byt znacka sekcie")
    NxTest.assert(s['label'].to_s.start_with?('Štúdio · '), "#{s['id']}: popis pre harok")
  end
end

NxTest.test('ui_foto: fotky Inspectora — znacky z nahravky, kontexty z raily, unikatne id') do
  cfg = NxUiFotoTest.shots
  ids = cfg['shots'].map { |s| s['id'] }
  NxTest.assert_equal(ids.uniq.length, ids.length, 'duplicitne id fotky')
  NxTest.assert(ids.all? { |i| i =~ /\A[a-z0-9_]+\z/ }, 'id fotky = [a-z0-9_] (meno suboru a -Only)')
  record = NxUiFotoTest.read('scripts', 'ui_foto', 'record.rb')
  shell = NxUiFotoTest.read('noxun_engine', 'ui', 'js', 'shell.js')
  contexts = shell[/var CONTEXTS = \[([^\]]*)\]/, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert_equal(%w[korpus zony cela kovanie], contexts, 'kontexty Inspectora v shell.js')
  panel = cfg['shots'].select { |s| s['kind'] == 'panel' }
  NxTest.assert(panel.length >= 5, 'Inspector: bez vyberu + 4 kontexty')
  panel.each do |s|
    NxTest.assert(record.include?("mark('#{s['upto']}')"), "#{s['id']}: record.rb nezapisuje znacku #{s['upto']}")
    NxTest.assert(s['ctx'].nil? || contexts.include?(s['ctx']), "#{s['id']}: neznamy kontext #{s['ctx']}")
  end
  NxTest.assert_equal(contexts.sort, panel.map { |s| s['ctx'] }.compact.sort, 'kazdy kontext Inspectora ma fotku')
  NxTest.assert(record.include?('mark("studio_#{section}")'), 'record.rb: znacka sekcie Studia')
  NxTest.assert(record.include?('StudioDialog::SECTIONS'), 'record.rb: sekcie z pluginu, nie vlastny zoznam')
  NxTest.assert_equal({ 'width' => 486, 'height' => 850 }, cfg['sizes']['panel'].slice('width', 'height'), 'Inspector 486x850')
  NxTest.assert_equal({ 'width' => 1280, 'height' => 800 }, cfg['sizes']['studio'].slice('width', 'height'), 'Studio 1280x800')
end

NxTest.test('ui_foto: nahravka zapisuje surove bajty (nie to_json — diakritika)') do
  record = NxUiFotoTest.read('scripts', 'ui_foto', 'record.rb')
  NxTest.assert(record.include?('script.to_s.b'), 'capture: File.binwrite surovych bajtov')
  NxTest.refute(record =~ /binwrite\([^)]*to_json/, 'capture nesmie ist cez to_json')
  NxTest.assert(record.include?("base.start_with?('enginetests')"), 'guard modelu: len ENGINEtests*.skp')
end

NxTest.test('ui_foto: ui_foto.ps1 je ASCII a zdiela zamok + sentinel s run_su_tests.ps1') do
  ps = File.binread(File.join(NxUiFotoTest::ROOT, 'scripts', 'ui_foto.ps1'))
  NxTest.assert(ps.bytes.all? { |b| b < 128 }, 'ui_foto.ps1 musi byt ASCII (PS 5.1 bez BOM)')
  runner = File.binread(File.join(NxUiFotoTest::ROOT, 'scripts', 'run_su_tests.ps1'))
  ["'noxun_su_tests'", "'deploy.lock'", "'last_run.txt'", "'KONIEC SUBORU'", '[System.IO.FileShare]::Read)'].each do |tok|
    NxTest.assert(runner.include?(tok), "runner: #{tok}")
    NxTest.assert(ps.include?(tok), "ui_foto.ps1 nezdiela #{tok} s runnerom")
  end
  NxTest.refute(ps =~ /Stop-Process[^\n]*\$suProc/i, 'proces SketchUpu sa nikdy nezabija')
  %w[nx_stub.js record.rb serve.py shots.json sheet.html lib.ps1].each do |f|
    NxTest.assert(File.file?(File.join(NxUiFotoTest::TOOL, f)), "chyba scripts/ui_foto/#{f}")
  end
  NxTest.assert(File.binread(File.join(NxUiFotoTest::TOOL, 'lib.ps1')).bytes.all? { |b| b < 128 }, 'lib.ps1 musi byt ASCII')
end

# --- Codex #434 (kolo 1) -------------------------------------------------------

# Spusti record.rb v SAMOSTATNOM Ruby procese so stubmi UI/Sketchup (headless sada
# nesmie definovat Sketchup — iné testy podla neho rozpoznavaju SketchUp). Casovace
# sa nespustaju naozaj: stub ich zbiera a harness ich odpali po jednom.
NX_UIFOTO_HARNESS = <<~'RUBY'
  require 'json'
  module UI
    @timers = []
    class << self
      attr_reader :timers
      def start_timer(_s, _r = false, &b)
        @timers << b
        @timers.length
      end
    end
    class HtmlDialog
      def execute_script(_s); end
    end
  end
  module Sketchup
    @quits = 0
    class << self
      attr_reader :quits
      def quit
        @quits += 1
      end
      def active_model
        nil
      end
    end
  end
  load ARGV[0]
  if ARGV[1] == 'finish_fail'
    # step_finish so zivym guardom, ale bez priecinka nahravky -> zapis znacky zlyha
    NoxunUiFoto.instance_variable_set(:@guard_ok, true)
    UI.timers.clear
    Dir.rmdir(NoxunUiFoto::REC) if Dir.exist?(NoxunUiFoto::REC)
    NoxunUiFoto.step_finish
  end
  20.times do
    t = UI.timers.shift
    break unless t
    t.call
  end
  puts JSON.generate('quits' => Sketchup.quits, 'result' => File.read(ENV['NOXUN_UIFOTO_RESULT']))
RUBY

def nx_uifoto_run(mode, rec)
  require 'open3'
  require 'rbconfig'
  require 'tmpdir'
  Dir.mktmpdir('uifoto-') do |dir|
    harness = File.join(dir, 'harness.rb')
    File.write(harness, NX_UIFOTO_HARNESS)
    env = { 'NOXUN_UIFOTO_REC' => rec.call(dir), 'NOXUN_UIFOTO_RESULT' => File.join(dir, 'result.txt') }
    out, err, st = Open3.capture3(env, RbConfig.ruby, harness, File.join(NxUiFotoTest::TOOL, 'record.rb'), mode)
    NxTest.assert(st.success?, "harness #{mode}: #{err}")
    return JSON.parse(out.lines.last)
  end
end

NxTest.test('ui_foto: zlyhanie nahravky po zapise markera vzdy zavrie SketchUp (nikdy visiaca instancia)') do
  # (1) start: priecinok nahravky sa neda vytvorit (cesta vedie cez SUBOR)
  r = nx_uifoto_run('start_fail', lambda { |dir|
    blocker = File.join(dir, 'blocker')
    File.write(blocker, 'x')
    File.join(blocker, 'rec')
  })
  NxTest.assert(r['result'].include?('FAIL: start:'), "start: FAIL riadok (#{r['result']})")
  NxTest.assert(r['result'].include?('=== KONIEC SUBORU ==='), 'start: koncovy marker')
  NxTest.assert_equal(1, r['quits'], 'start: po markeri Sketchup.quit')
  # (2) guard: plugin nie je nacitany -> :abort -> step_finish -> marker + quit
  r = nx_uifoto_run('abort', ->(dir) { File.join(dir, 'rec') })
  NxTest.assert(r['result'].include?('FAIL: Noxun Engine nie je nacitany'), "abort: FAIL (#{r['result']})")
  NxTest.assert_equal(1, r['quits'], 'abort: po markeri Sketchup.quit')
  # (3) step_finish: vynimka pri zapise (rescue vetva) -> marker + quit
  r = nx_uifoto_run('finish_fail', ->(dir) { File.join(dir, 'rec') })
  NxTest.assert(r['result'].include?('FAIL: finish:'), "finish: FAIL riadok (#{r['result']})")
  NxTest.assert_equal(1, r['result'].scan('=== KONIEC SUBORU ===').length, 'finish: marker presne raz')
  NxTest.assert_equal(1, r['quits'], 'finish: po markeri Sketchup.quit (raz)')
  # boot.rb (load record.rb zlyhal) — po markeri tiez quit
  ps = File.binread(File.join(NxUiFotoTest::ROOT, 'scripts', 'ui_foto.ps1'))
  boot = ps[/\$bootText = @'(.*?)'@/m, 1].to_s
  NxTest.assert(boot.index('KONIEC SUBORU') && boot.index('Sketchup.quit').to_i > boot.index('KONIEC SUBORU'),
                'boot.rb: po markeri zlyhaneho load naplanovany Sketchup.quit')
end

def nx_uifoto_pwsh
  %w[pwsh powershell].each do |exe|
    ok = system(exe, '-NoProfile', '-Command', 'exit 0', out: File::NULL, err: File::NULL)
    return exe if ok
  rescue StandardError
    next
  end
  nil
end

NxTest.test('ui_foto: -Shoot bez -Rec vyberie len USPESNU nahravku; -Only filtruje a odmieta preklep') do
  exe = nx_uifoto_pwsh
  NxTest.skip!('pwsh/powershell nie je k dispozicii') unless exe
  require 'open3'
  require 'tmpdir'
  require 'fileutils'
  Dir.mktmpdir('uifoto-rec-') do |root|
    mk = lambda do |name, ok, age|
      d = File.join(root, name)
      FileUtils.mkdir_p(d)
      File.write(File.join(d, 'index.json'), '[]')
      File.write(File.join(d, 'NAHRAVKA_OK.txt'), 'OK') if ok
      t = Time.now - age
      File.utime(t, t, d)
    end
    mk.call('rec_0.17.0_20261001_100000', true, 300)   # starsia uspesna
    mk.call('rec_0.17.0_20261001_110000', false, 100)  # novsia ODMIETNUTA (FAIL pri stavbe)
    FileUtils.mkdir_p(File.join(root, 'rec_0.17.0_20261001_120000')) # rozbehnuta bez index.json
    lib = File.join(NxUiFotoTest::TOOL, 'lib.ps1')
    script = ". '#{lib}'; Write-Output ('LATEST=' + (Find-NxLatestRec '#{root}')); " \
             "$s = @([pscustomobject]@{id='panel_cela'}, [pscustomobject]@{id='studio_bom'}, [pscustomobject]@{id='studio_cut'}); " \
             "Write-Output ('ONLY=' + (((Select-NxShots $s 'studio_*, panel_cela') | ForEach-Object { $_.id }) -join ',')); " \
             "Write-Output ('ALL=' + (@(Select-NxShots $s '')).Count); " \
             "try { Select-NxShots $s 'studio_cutt' | Out-Null; Write-Output 'TYPO=ok' } catch { Write-Output 'TYPO=throw' }"
    out, err, st = Open3.capture3(exe, '-NoProfile', '-Command', script)
    NxTest.assert(st.success?, "pwsh: #{err}")
    NxTest.assert(out.include?("LATEST=#{File.join(root, 'rec_0.17.0_20261001_100000')}") ||
                  out.tr('\\', '/').include?("LATEST=#{File.join(root, 'rec_0.17.0_20261001_100000').tr('\\', '/')}"),
                  "predvolena nahravka = najnovsia USPESNA, nie odmietnuta (#{out})")
    NxTest.assert(out.include?('ONLY=panel_cela,studio_bom,studio_cut'), "-Only vzory (#{out})")
    NxTest.assert(out.include?('ALL=3'), "-Only prazdne = vsetko (#{out})")
    NxTest.assert(out.include?('TYPO=throw'), "-Only preklep = chyba (#{out})")
  end
  ps = File.binread(File.join(NxUiFotoTest::ROOT, 'scripts', 'ui_foto.ps1'))
  ok_at = ps.index('Set-NxRecOk $recDir')
  NxTest.assert(ok_at && ok_at > ps.index("VYSLEDOK NAHRAVKY: $failed FAIL").to_i, 'marker uspechu az po validacii FAIL riadkov')
end

NxTest.test('ui_foto: vystup -Shoot ma unikatny priecinok aj pre subezne behy (PID)') do
  ps = File.binread(File.join(NxUiFotoTest::ROOT, 'scripts', 'ui_foto.ps1'))
  NxTest.assert(ps.include?("('shots_{0}_{1}' -f $stamp, $PID)"), 'shots_<cas>_<PID>')
  NxTest.refute(ps.include?("('shots_' + $stamp)"), 'stary nazov bez PID')
end
