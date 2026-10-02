# frozen_string_literal: true
# Noxun Engine — H16 (C-04, priprava D-48): SUPIS KNIZNIC A ULOZISK MIMO MODELU.
#
#   T0 golden prveho behu — bezec `tests/h16_first_use.rb` v SAMOSTATNOM procese
#      (cerstvy sandbox + pamat modulov; package §15 A5), DVA behy = opakovatelnost;
#      fixtura `tests/fixtures/h16_golden/first_use.json` vznikla na kode PRED
#      zasahom a v davke sa NEREGENERUJE (rozdiel = nalez).
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'rbconfig'

module NxH16
  RUNNER = File.join(NxTest::ROOT, 'tests', 'h16_first_use.rb')
  GOLDEN = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h16_golden', 'first_use.json')

  module_function

  def run_once
    out = IO.popen([RbConfig.ruby, RUNNER], err: File::NULL, &:read).to_s
    line = out.lines.find { |l| l.start_with?('NXH16_JSON=') }
    raise "bezec H16 nevratil vysledok:\n#{out[0, 2000]}" unless line

    JSON.parse(line.sub('NXH16_JSON=', ''))
  end

  # Dva behy bezca (memo) — volaju ich vsetky testy nad prvym behom.
  def runs
    @runs ||= [run_once, run_once]
  end

  def golden
    @golden ||= JSON.parse(File.read(GOLDEN, encoding: 'UTF-8'))
  end

  # Rozdiely behu voci goldenu (prazdne = zhoda).
  def golden_problems(run, gold)
    probs = []
    extra = run['files'] - gold['files']
    gone = gold['files'] - run['files']
    probs << "novy subor po prvom behu: #{extra.join(', ')}" unless extra.empty?
    probs << "chyba subor po prvom behu: #{gone.join(', ')}" unless gone.empty?
    gold['sha'].each do |f, sha|
      probs << "#{f}: obsah sa zmenil (SHA-256)" unless run['sha'][f] == sha
    end
    probs << "zamky pri zapise sa zmenili: #{run['locks_at_write'].inspect}" unless run['locks_at_write'] == gold['locks_at_write']
    probs
  end
end

NxTest.test('H16 T0: golden prveho behu — dva behy v samostatnych procesoch = fixtura (subory, SHA, zamky)') do
  NxTest.skip!('bezec potrebuje samostatny Ruby interpreter (len headless)') unless NxTest.headless?
  a, b = NxH16.runs
  [a, b].each_with_index do |run, i|
    probs = NxH16.golden_problems(run, NxH16.golden)
    NxTest.assert(probs.empty?, "beh #{i + 1}: #{probs.join(' · ')} — golden sa v H16 NEREGENERUJE (nalez)")
  end
  NxTest.assert_equal(a['files'], b['files'], 'dva behy vyrobili inu mnozinu suborov')
  NxTest.assert(NxH16.golden['files'].length >= 25, 'golden ma podozrivo malo suborov')
end

NxTest.test('H16 T0: negativ — iny subor, iny obsah alebo iny zamok golden zhodi') do
  gold = { 'files' => %w[a.json b.lock], 'sha' => { 'a.json' => 'x' }, 'locks_at_write' => { 'a.json' => ['b.lock'] } }
  ok = { 'files' => %w[a.json b.lock], 'sha' => { 'a.json' => 'x' }, 'locks_at_write' => { 'a.json' => ['b.lock'] } }
  NxTest.assert(NxH16.golden_problems(ok, gold).empty?)
  NxTest.refute(NxH16.golden_problems(ok.merge('files' => %w[a.json b.lock presets.json]), gold).empty?)
  NxTest.refute(NxH16.golden_problems(ok.merge('sha' => { 'a.json' => 'y' }), gold).empty?)
  NxTest.refute(NxH16.golden_problems(ok.merge('locks_at_write' => { 'a.json' => [''] }), gold).empty?)
end
