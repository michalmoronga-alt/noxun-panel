# frozen_string_literal: true
# Guard nastroja EXPORT TEST (davka H19, blok 9 HARDENING): scripts/export_test.ps1 +
# scripts/export_compare.rb + tests/sketchup/su_export_probe.rb. Nastroj nie je sucast
# pluginu. Test strazi:
#   (a) porovnavac (PACKAGE_H17 R9.3): zhodne stromy = zhoda; povolene su LEN riadky
#       `Verzia:`/`Datum:` vo VEPO LOGu, cas v 1. riadku CSV kovania a datum v nazve;
#       rozdiel v dielci VEPO, v XML harka, chybajuci/nadbytocny subor, zmena mimo povoleneho
#       riadku = rozdiel; vynimka vstupneho modelu je MENOVITA,
#   (b) vety statusu 4 exportov (cesty normalizovane) a CLI exit kody,
#   (c) sonda: vola vsetky 4 do_*, chyba exportu = FAIL, marker presne raz + quit,
#   (d) skript: ASCII, zamok + sentinel zdielany s runnerom, proces sa nezabija.
require 'json'
require 'zlib'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'
require_relative '../helper' unless defined?(NxTest)
require File.join(NxTest::ROOT, 'scripts', 'export_compare')

module NxExpCmp
  ROOT = NxTest::ROOT
  EC = ExportCompare
  LOG_LINES = ["Projekt: Test\n", "Verzia:  0.17.31\n", "Dátum:   2026-10-11 10:00\n", "KONTROLA: 0 chyb\n"].freeze

  def self.read(*parts)
    File.binread(File.join(ROOT, *parts)).force_encoding('UTF-8')
  end

  # Minimalny ZIP (STORE alebo DEFLATE); `dos_time` simuluje cas zapisu v hlavickach.
  def self.zip(entries, dos_time: 0, deflate: false)
    out = ''.b
    cd = ''.b
    entries.each do |name, data|
      data = data.b
      crc = Zlib.crc32(data)
      body = data
      method = 0
      if deflate
        body = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS).deflate(data, Zlib::FINISH)
        method = 8
      end
      off = out.bytesize
      out << [0x04034b50, 20, 0, method, dos_time, 0, crc, body.bytesize, data.bytesize, name.bytesize, 0].pack('VvvvvvVVVvv')
      out << name.b << body
      cd << [0x02014b50, 20, 20, 0, method, dos_time, 0, crc, body.bytesize, data.bytesize, name.bytesize, 0, 0, 0, 0, 0, off]
        .pack('VvvvvvvVVVvvvvvVV') << name.b
    end
    out + cd + [0x06054b50, 0, 0, entries.length, entries.length, cd.bytesize, out.bytesize, 0].pack('VvvvvVVv')
  end

  SHEET = '<worksheet><sheetData><row r="1"><c r="A1"><v>10</v></c></row></sheetData></worksheet>'
  PARTS = { '[Content_Types].xml' => '<Types/>', 'xl/workbook.xml' => '<workbook/>', 'xl/worksheets/sheet1.xml' => SHEET }.freeze

  # Strom vystupov jednej strany; `over` prepise obsah: 'vepo/<kluc>', 'hw_csv', 'budget', 'offer'.
  def self.tree(dir, date: '9.10.2026', und: '9_10_2026', stamp: '2026-10-09 19:07', version: '0.17.31', over: {}, skip: [])
    slug = "zakazka_#{und}"
    FileUtils.mkdir_p(File.join(dir, slug))
    files = {
      "#{slug}/#{slug}_500_sm_biela_dtdl_16.csv" => "Dielec;Dlzka\nA;100\n",
      "#{slug}/#{slug}_101_pe_biela_hdf_3.csv" => "Dielec;Dlzka\nB;200\n",
      "#{slug}/#{slug}_export.log" => LOG_LINES.join.sub('0.17.31', version).sub('2026-10-11 10:00', stamp),
      "kovanie_zakazka_#{und}.csv" => "\"NOXUN kovanie\";\"Zakazka: #{date}\";\"#{stamp}\"\nZaves;4\nVodic;8\n",
      "Rozpocet zakazka- #{date} - AKT #{date}.xlsx" => zip(PARTS),
      "Cenova ponuka zakazka- #{date}.xlsx" => zip(PARTS.merge('xl/workbook.xml' => '<workbook name="ponuka"/>'))
    }
    over.each do |k, v|
      path = case k
             when 'hw_csv' then "kovanie_zakazka_#{und}.csv"
             when 'budget' then "Rozpocet zakazka- #{date} - AKT #{date}.xlsx"
             when 'offer' then "Cenova ponuka zakazka- #{date}.xlsx"
             else "#{slug}/#{slug}_#{k}"
             end
      files[path] = v
    end
    files.each do |rel, data|
      next if skip.any? { |s| rel.end_with?("#{slug}_#{s}") }

      File.binwrite(File.join(dir, rel), data)
    end
  end

  def self.pair(k_opts = {}, p_opts = {}, exclude: [])
    Dir.mktmpdir('expcmp-') do |root|
      k = File.join(root, 'K')
      p = File.join(root, 'P')
      FileUtils.mkdir_p([k, p])
      tree(k, **k_opts)
      tree(p, **p_opts)
      yield EC.compare_trees(k, p, exclude: exclude), k, p
    end
  end

  def self.diffs(rows)
    rows.select { |r| r.verdict == :diff }
  end
end

NxTest.test('export_compare: zhodne stromy = zhoda (bajtovo)') do
  NxExpCmp.pair do |rows, _k, _p|
    NxTest.assert(rows.length >= 6, "malo poloziek (#{rows.length})")
    NxTest.assert(NxExpCmp::EC.ok?(rows), NxExpCmp.diffs(rows).map(&:key).join(','))
  end
end

NxTest.test('export_compare: povolene su LEN Verzia/Datum v LOGu, cas v 1. riadku CSV kovania, datum v nazve') do
  NxExpCmp.pair({}, { date: '10.10.2026', und: '10_10_2026', stamp: '2026-10-10 21:45', version: '0.17.32' }) do |rows, _k, _p|
    NxTest.assert(NxExpCmp::EC.ok?(rows), NxExpCmp.diffs(rows).map { |r| [r.key, r.note, r.details] }.inspect)
    log = rows.find { |r| r.key == 'vepo/export.log' }
    NxTest.assert(log.note.include?('povolene'), 'LOG: poznamka o povolenom rozdiele')
  end
end

NxTest.test('export_compare: rozdiel v dielci VEPO CSV, v XML harka a v LOGu mimo povolenych riadkov = rozdiel') do
  NxExpCmp.pair({}, { over: { '500_sm_biela_dtdl_16.csv' => "Dielec;Dlzka\nA;101\n" } }) do |rows, _k, _p|
    d = NxExpCmp.diffs(rows)
    NxTest.assert_equal(['vepo/500_sm_biela_dtdl_16.csv'], d.map(&:key), 'len zmeneny dielec')
    NxTest.assert(d.first.details.first.include?('riadok 2'), d.first.details.inspect)
  end
  sheet2 = NxExpCmp.zip(NxExpCmp::PARTS.merge('xl/worksheets/sheet1.xml' => NxExpCmp::SHEET.sub('<v>10</v>', '<v>11</v>')))
  NxExpCmp.pair({}, { over: { 'budget' => sheet2 } }) do |rows, _k, _p|
    d = NxExpCmp.diffs(rows)
    NxTest.assert_equal(['budget_xlsx'], d.map(&:key))
    NxTest.assert(d.first.details.first.include?('xl/worksheets/sheet1.xml'), d.first.details.inspect)
  end
  log = NxExpCmp::LOG_LINES.join.sub('0 chyb', '3 chyby')
  NxExpCmp.pair({}, { over: { 'export.log' => log } }) do |rows, _k, _p|
    NxTest.assert_equal(['vepo/export.log'], NxExpCmp.diffs(rows).map(&:key), 'zmena riadku KONTROLA nie je povolena')
  end
end

NxTest.test('export_compare: povolenie CSV kovania je len cas v 1. riadku (nie ine riadky ani ine stlpce)') do
  csv = "\"NOXUN kovanie\";\"Zakazka: 9.10.2026\";\"2026-10-09 19:07\"\nZaves;5\nVodic;8\n"
  NxExpCmp.pair({}, { over: { 'hw_csv' => csv } }) do |rows, _k, _p|
    NxTest.assert_equal(['hw_csv'], NxExpCmp.diffs(rows).map(&:key), 'zmena poctu v 2. riadku')
  end
  csv2 = "\"NOXUN kovanie\";\"Zakazka INA\";\"2026-10-09 19:07\"\nZaves;4\nVodic;8\n"
  NxExpCmp.pair({}, { over: { 'hw_csv' => csv2 } }) do |rows, _k, _p|
    NxTest.assert_equal(['hw_csv'], NxExpCmp.diffs(rows).map(&:key), 'zmena textu v 1. riadku mimo casu')
  end
end

NxTest.test('export_compare: chybajuci a nadbytocny subor = rozdiel') do
  NxExpCmp.pair({}, { skip: ['500_sm_biela_dtdl_16.csv'] }) do |rows, _k, _p|
    d = NxExpCmp.diffs(rows)
    NxTest.assert_equal(['vepo/500_sm_biela_dtdl_16.csv'], d.map(&:key))
    NxTest.assert(d.first.note.include?('chyba v P'), d.first.note)
  end
  NxExpCmp.pair({ skip: ['500_sm_biela_dtdl_16.csv'] }, {}) do |rows, _k, _p|
    NxTest.assert(NxExpCmp.diffs(rows).first.note.include?('chyba v K'))
  end
  NxExpCmp.pair do |_rows, k, p|
    File.binwrite(File.join(p, 'navyse.txt'), 'x')
    rows = NxExpCmp::EC.compare_trees(k, p)
    NxTest.assert_equal(['other/navyse.txt'], NxExpCmp.diffs(rows).map(&:key), 'nadbytocny subor')
  end
  Dir.mktmpdir('expcmp-') do |root|
    FileUtils.mkdir_p([File.join(root, 'K'), File.join(root, 'P')])
    NxTest.refute(NxExpCmp::EC.ok?(NxExpCmp::EC.compare_trees(File.join(root, 'K'), File.join(root, 'P'))), 'dva prazdne stromy nie su zhoda')
  end
end

NxTest.test('export_compare: vstupny model sa vyluci LEN menovite (--exclude-input), ziadne masky') do
  NxExpCmp.pair do |_rows, k, p|
    File.binwrite(File.join(k, 'TEST projekt.skp'), 'a')
    File.binwrite(File.join(p, 'TEST projekt P.skp'), 'b')
    NxTest.refute(NxExpCmp::EC.ok?(NxExpCmp::EC.compare_trees(k, p)), 'bez vynimky je model rozdiel')
    NxTest.refute(NxExpCmp::EC.ok?(NxExpCmp::EC.compare_trees(k, p, exclude: ['TEST projekt.skp'])), 'vynimka platí len pre jedno meno')
    rows = NxExpCmp::EC.compare_trees(k, p, exclude: ['TEST projekt.skp', 'TEST projekt P.skp'])
    NxTest.assert(NxExpCmp::EC.ok?(rows), NxExpCmp.diffs(rows).map(&:key).join(','))
  end
end

NxTest.test('export_compare: zmena nazvu suboru (nie datumu) = rozdiel; datum v nazve nie') do
  NxExpCmp.pair do |_rows, k, p|
    old = File.join(p, 'kovanie_zakazka_9_10_2026.csv')
    File.rename(old, File.join(p, 'kovanie_ina_9_10_2026.csv'))
    rows = NxExpCmp::EC.compare_trees(k, p)
    d = NxExpCmp.diffs(rows)
    NxTest.assert_equal(['hw_csv'], d.map(&:key))
    NxTest.assert(d.first.details.first.include?('nazov suboru'), d.first.details.inspect)
  end
end

NxTest.test('export_compare: ZIP citacka — STORE aj DEFLATE, cas v hlavickach sa neporovnava') do
  ec = NxExpCmp::EC
  a = NxExpCmp.zip(NxExpCmp::PARTS)
  b = NxExpCmp.zip(NxExpCmp::PARTS, dos_time: 0x4A3B, deflate: true)
  NxTest.assert_equal(NxExpCmp::PARTS.transform_values(&:b), ec.zip_entries(a), 'STORE')
  NxTest.assert_equal(NxExpCmp::PARTS.transform_values(&:b), ec.zip_entries(b), 'DEFLATE')
  Dir.mktmpdir('expcmp-') do |dir|
    File.binwrite(File.join(dir, 'a.xlsx'), a)
    File.binwrite(File.join(dir, 'b.xlsx'), b)
    v, note, = ec.cmp_xlsx(File.join(dir, 'a.xlsx'), File.join(dir, 'b.xlsx'))
    NxTest.assert_equal(:ok, v, note)
    File.binwrite(File.join(dir, 'c.xlsx'), 'toto nie je zip')
    NxTest.assert_equal(:diff, ec.cmp_xlsx(File.join(dir, 'a.xlsx'), File.join(dir, 'c.xlsx')).first, 'nečitateľný XLSX = rozdiel')
  end
end

NxTest.test('export_compare: vety statusu — cesty a datum sa normalizuju, iná veta / chýbajúci export = rozdiel') do
  ec = NxExpCmp::EC
  log = lambda do |out, sentence|
    lines = ec::METHODS.map do |m|
      "STATUS #{JSON.generate('m' => m, 'err' => false, 'msg' => m == 'do_export' ? sentence : "ok #{m}")}"
    end
    lines << "PICKER #{JSON.generate('m' => 'do_export', 'api' => 'select_directory', 'start' => "#{out}/s")}"
    lines << "REPUSH #{JSON.generate('m' => 'do_cp_xlsx')}"
    lines.join("\n") + "\n"
  end
  k = log.call('C:/Temp/nxkp/K/out', 'Export hotovy: C:\\Temp\\nxkp\\K\\out\\zakazka_9_10_2026 (3 subory)')
  p = log.call('C:/Temp/nxkp/P/out', 'Export hotovy: C:\\Temp\\nxkp\\P\\out\\zakazka_10_10_2026 (3 subory)')
  rows = ec.compare_status(k, p, ['C:/Temp/nxkp/K/out'], ['C:/Temp/nxkp/P/out'])
  NxTest.assert_equal(4, rows.length)
  NxTest.assert(ec.ok?(rows), rows.map { |r| [r.key, r.note, r.details] }.inspect)
  p2 = log.call('C:/Temp/nxkp/P/out', 'Export hotovy: C:\\Temp\\nxkp\\P\\out\\zakazka_10_10_2026 (4 subory)')
  d = ec.compare_status(k, p2, ['C:/Temp/nxkp/K/out'], ['C:/Temp/nxkp/P/out']).select { |r| r.verdict == :diff }
  NxTest.assert_equal(['do_export'], d.map(&:key), 'iná veta')
  nop = p.lines.reject { |l| l.include?('do_hw_csv') }.join
  d = ec.compare_status(k, nop, ['C:/Temp/nxkp/K/out'], ['C:/Temp/nxkp/P/out']).select { |r| r.verdict == :diff }
  NxTest.assert_equal(['do_hw_csv'], d.map(&:key), 'chýbajúci export')
  NxTest.assert_equal(['FAIL: x'], ec.log_failures("INFO: a\nFAIL: x\n"), 'FAIL riadky logu')
end

NxTest.test('export_compare: CLI — exit 0 pri zhode, 1 pri rozdiele, vystup obsahuje VERDIKT') do
  script = File.join(NxExpCmp::ROOT, 'scripts', 'export_compare.rb')
  NxExpCmp.pair do |_rows, k, p|
    out, err, st = Open3.capture3(RbConfig.ruby, script, k, p)
    NxTest.assert(st.success?, "zhoda: #{err}#{out}")
    NxTest.assert(out.include?('VERDIKT: P == K'), out)
    File.binwrite(File.join(p, 'navyse.txt'), 'x')
    out, = Open3.capture3(RbConfig.ruby, script, k, p, '--out', File.join(k, '..', 'report.txt'))
    NxTest.assert(out.include?('VERDIKT: P != K'), out)
    NxTest.assert(File.read(File.join(k, '..', 'report.txt')).include?('P != K'), 'report subor')
    _o, _e, st = Open3.capture3(RbConfig.ruby, script, k, p)
    NxTest.assert_equal(1, st.exitstatus, 'exit 1 pri rozdiele')
  end
end

# --- sonda ----------------------------------------------------------------------------
NX_EXPPROBE_HARNESS = <<~'RUBY'
  require 'json'
  require 'fileutils'
  module UI
    @timers = []
    class << self
      attr_reader :timers
      def start_timer(_s, repeat = false, &b)
        @timers << { blk: b, repeat: repeat, stopped: false }
        @timers.last
      end

      def stop_timer(t)
        t[:stopped] = true if t
      end
    end
  end
  module Sketchup
    @quits = 0
    @closed = []
    class << self
      attr_reader :quits, :closed

      def quit
        @quits += 1
      end

      def version
        '26.0'
      end

      def active_model
        Model
      end
    end
    module Model
      def self.path
        ENV['MODEL_PATH']
      end

      def self.close(arg)
        Sketchup.closed << arg
      end
    end
  end
  module Noxun
    module Engine
      VERSION = '9.9.9'
      module Bom
        def self.compute(_c)
          :bom
        end
      end
      module ExportSettings
        def self.project_name(_m) = 'Zakazka'
        def self.merge_18_36 = true
        def self.name_source(_m, _n) = 'auto'
      end
      module ProductionCore
        CALLS = []
        MODE = ENV['MODE']
        class << self
          private

          def fresh_collect(_m) = :c
          def budget_payload(*_a) = :bud
          def hardware_expansion(*_a) = :hw
          def sheets_map = :sm
          def unpriced_count(_b) = 2
        end

        class << self
          %w[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].each do |name|
            define_method(name) do |model, data, generation:, status:, repush:|
              CALLS << [name, data['confirm_unpriced'], data['expect']]
              raise 'porucha exportu' if MODE == 'fail' && name == 'do_hw_csv'

              dir = UI.select_directory(title: 't', directory: 'C:/start')
              file = UI.savepanel('t', 'C:/start', "#{name}.out")
              FileUtils.touch(file) unless MODE == 'fail' && name == 'do_budget_xlsx'
              status.call("hotovo #{name} #{dir}", MODE == 'fail' && name == 'do_cp_xlsx')
              repush.call if name == 'do_export'
            end
          end
        end
      end
    end
  end
  load ARGV[0]
  200.times do
    t = UI.timers.find { |x| !x[:stopped] }
    break unless t
    t[:blk].call
    t[:stopped] = true unless t[:repeat]
  end
  puts JSON.generate('quits' => Sketchup.quits, 'closed' => Sketchup.closed,
                     'calls' => Noxun::Engine::ProductionCore::CALLS.map { |c| [c[0], c[1]] },
                     'expect' => Noxun::Engine::ProductionCore::CALLS.first&.last,
                     'log' => File.read(ENV['NOXUN_EXPORT_LOG']))
RUBY

def nx_expprobe_run(mode, model_in_work: true)
  Dir.mktmpdir('expprobe-') do |dir|
    out = File.join(dir, 'work', 'out')
    FileUtils.mkdir_p(out)
    harness = File.join(dir, 'harness.rb')
    File.write(harness, NX_EXPPROBE_HARNESS)
    env = { 'NOXUN_EXPORT_OUT' => out, 'NOXUN_EXPORT_LOG' => File.join(dir, 'work', 'log.txt'),
            'NOXUN_EXPORT_WORK' => File.join(dir, 'work'), 'MODE' => mode,
            'MODEL_PATH' => model_in_work ? File.join(dir, 'work', 'zakazka.skp') : File.join(dir, 'inde', 'zakazka.skp') }
    probe = File.join(NxExpCmp::ROOT, 'tests', 'sketchup', 'su_export_probe.rb')
    o, e, st = Open3.capture3(env, RbConfig.ruby, harness, probe)
    NxTest.assert(st.success?, "harness #{mode}: #{e}")
    return JSON.parse(o.lines.last)
  end
end

NxTest.test('export sonda: zavola vsetky 4 do_* s expect zo servera, confirm_unpriced len pri rozpocte a ponuke') do
  r = nx_expprobe_run('ok')
  NxTest.assert_equal([['do_export', nil], ['do_hw_csv', nil], ['do_budget_xlsx', 2], ['do_cp_xlsx', 2]], r['calls'])
  NxTest.assert_equal({ 'project' => 'Zakazka', 'merge' => true, 'source' => 'auto' }, r['expect'])
  NxTest.refute(r['log'].include?('FAIL:'), r['log'])
  NxTest.assert_equal(1, r['log'].scan('=== KONIEC SUBORU ===').length, 'marker presne raz')
  NxTest.assert_equal(1, r['quits'], 'Sketchup.quit raz')
  NxTest.assert_equal([true], r['closed'], 'model sa zatvara BEZ ulozenia (close(true))')
  NxTest.assert_equal(4, r['log'].scan(/^STATUS /).length, 'status 4 exportov')
  NxTest.assert_equal(8, r['log'].scan(/^PICKER /).length, 'picker 2x na export (adresar + savepanel)')
  NxTest.assert(r['log'].include?('REPUSH'), 'repush zaznamenany')
end

NxTest.test('export sonda: vynimka exportu a export bez suboru = FAIL (cervena veta nie); ostatne exporty bezia dalej') do
  r = nx_expprobe_run('fail')
  fails = r['log'].lines.grep(/^FAIL:/)
  NxTest.assert_equal(2, fails.length, fails.inspect)
  NxTest.assert(fails.any? { |l| l.include?('do_hw_csv') && l.include?('porucha exportu') }, fails.inspect)
  NxTest.assert(r['log'].include?('"err":true'), 'cervena veta sa zapise ako udalost statusu')
  NxTest.assert(fails.any? { |l| l.include?('do_budget_xlsx') && l.include?('ziadny subor') }, fails.inspect)
  NxTest.assert_equal(4, r['calls'].length, 'vsetky 4 exporty zavolane aj po chybe')
  NxTest.assert_equal(1, r['log'].scan('=== KONIEC SUBORU ===').length)
  NxTest.assert_equal(1, r['quits'])
end

NxTest.test('export sonda: model mimo pracovneho priecinka behu = FAIL, nic sa neexportuje (poistka pred zakazkou)') do
  r = nx_expprobe_run('ok', model_in_work: false)
  NxTest.assert(r['log'].include?('FAIL: model nelezi v pracovnom priecinku'), r['log'])
  NxTest.assert_equal([], r['calls'])
  NxTest.assert_equal(1, r['quits'])
end

NxTest.test('export test: skript je ASCII, zdiela zamok + sentinel s runnerom, proces nezabija, nic nemeni v pluginu') do
  ps = File.binread(File.join(NxExpCmp::ROOT, 'scripts', 'export_test.ps1'))
  NxTest.assert(ps.bytes.all? { |b| b < 128 }, 'export_test.ps1 musi byt ASCII (PS 5.1 bez BOM)')
  runner = File.binread(File.join(NxExpCmp::ROOT, 'scripts', 'run_su_tests.ps1'))
  ["'noxun_su_tests'", "'deploy.lock'", "'last_run.txt'", "'KONIEC SUBORU'", '[System.IO.FileShare]::Read)'].each do |tok|
    NxTest.assert(runner.include?(tok), "runner: #{tok}")
    NxTest.assert(ps.include?(tok), "export_test.ps1 nezdiela #{tok} s runnerom")
  end
  NxTest.refute(ps =~ /Stop-Process|\.Kill\(\)/i, 'proces SketchUpu sa nikdy nezabija')
  NxTest.assert(ps.include?('exit 2'), 'zamok => exit 2')
  NxTest.assert(ps.include?('worktree add --detach'), 'K = dociasny git worktree --detach')
  NxTest.assert(ps.include?('export_compare.rb') && ps.include?('su_export_probe.rb'), 'skript pouziva porovnavac aj sondu')
  NxTest.assert(File.binread(File.join(NxExpCmp::ROOT, 'scripts', 'export_compare.rb')).force_encoding('UTF-8').include?('exit(ExportCompare.main(ARGV))'), 'CLI porovnavaca')
  boot = ps[/\$bootLoad = @'(.*?)'@/m, 1].to_s
  NxTest.assert(boot.index('KONIEC SUBORU') && boot.index('Sketchup.quit').to_i > boot.index('KONIEC SUBORU'),
                'boot.rb: po markeri zlyhaneho load naplanovany Sketchup.quit')
end

NxTest.test('export test: sonda vola vsetky 4 ProductionCore.do_* a nezapisuje do modelu ani do pluginu') do
  src = NxExpCmp.read('tests', 'sketchup', 'su_export_probe.rb')
  %w[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].each { |m| NxTest.assert(src.include?(m), "sonda: #{m}") }
  NxTest.assert(src.include?('close(true)') && src.include?('Sketchup.quit'), 'model sa zatvara bez ulozenia a SketchUp konci')
  NxTest.refute(src =~ /\.save\b|start_operation|commit_operation/, 'sonda model neuklada ani nemeni')
  NxTest.assert(src.include?('NOXUN_EXPORT_WORK'), 'poistka pracovneho priecinka')
  kinds = Noxun::Engine::ExportPrep::KINDS.values.sort
  NxTest.assert_equal(kinds, NxExpCmp::EC::METHODS.sort, 'ExportPrep::KINDS != exporty porovnavaca — novy export musi dostat aj porovnanie')
  probe_methods = src[/METHODS = %w\[([^\]]*)\]/, 1].to_s.split.sort
  NxTest.assert_equal(kinds, probe_methods, 'ExportPrep::KINDS != exporty sondy — novy export musi dostat aj sondu')
  ui = Dir.glob(File.join(NxExpCmp::ROOT, 'noxun_engine', '**', '*')).select { |f| File.file?(f) }
  stray = ui.select { |f| File.binread(f).include?('NOXUN_EXPORT_') }
  NxTest.assert(stray.empty?, "premenne export testu v plugine: #{stray.join(', ')}")
end

NxTest.test('export test: skript sa dá parsovat PowerShellom (syntax)') do
  exe = %w[pwsh powershell].find do |x|
    system(x, '-NoProfile', '-Command', 'exit 0', out: File::NULL, err: File::NULL)
  rescue StandardError
    false
  end
  NxTest.skip!('pwsh/powershell nie je k dispozicii') unless exe
  path = File.join(NxExpCmp::ROOT, 'scripts', 'export_test.ps1')
  script = "$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile('#{path}', [ref]$null, [ref]$e); " \
           'if ($e -and $e.Count) { $e | ForEach-Object { Write-Output $_.Message }; exit 1 } else { exit 0 }'
  out, err, st = Open3.capture3(exe, '-NoProfile', '-Command', script)
  NxTest.assert(st.success?, "syntax export_test.ps1: #{out}#{err}")
end
