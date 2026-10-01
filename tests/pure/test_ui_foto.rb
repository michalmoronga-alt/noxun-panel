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
  %w[nx_stub.js record.rb serve.py shots.json sheet.html].each do |f|
    NxTest.assert(File.file?(File.join(NxUiFotoTest::TOOL, f)), "chyba scripts/ui_foto/#{f}")
  end
end
