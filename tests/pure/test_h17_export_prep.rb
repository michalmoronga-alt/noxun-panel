# frozen_string_literal: true
# H17a — STRAZCOVIA spolocnej pripravy exportov `ExportPrep` (package
# `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H17.md` §6 R1–R6, §7 T1–T3, §15 A2–A5).
#
#   R4 a  jedno miesto uvodu (zber, brany, refresh, `expect` len v `start`)
#   R4 b  novy vystup = riadok `KINDS` (mnozina exportov s pickerom == KINDS,
#         kazdy zacina `ExportPrep.start` pred pickerom; inventar matice G2 == KINDS)
#   R4 c  bez stavu modulu (dva exporty po sebe = dva zbery a dve brany)
#   R4 d  nacitanie: main.rb hned za ui/production_core, helper, subor pri
#         nacitani nevola nic mimo definicii
#   R4 e  data a nazov v telach exportov LEN z kontextu
#   R4 f  rozdielne brany druhu vystupu ostali (spravanie G2)
#   T1    `Context`: pamat citacky vratane `nil`, fallback expanzie rozpoctu,
#         `gate` nemenny, rozpocet bez `estimate`/`layout`, vynimka prejde von,
#         cas harnessu (novy objekt, lokalny cas po rozpocte)
#   T2    `start`: kazda vetva R1.2, `merge: true` len pri :vepo, neznamy druh
require_relative '../helper' unless defined?(NxTest)
require_relative 'h17_harness'
require 'rbconfig'
require 'open3'

module NxH17P
  E = Noxun::Engine
  H = NxH17
  PC = E::ProductionCore
  EP = E::ExportPrep

  # Text uvodu, ktory v tele exportu NESMIE byt (R4 a) a data, ktore telo
  # nesmie citat mimo kontextu (R4 e).
  INTRO_IN_BODY = ['fresh_collect(', 'newer_config_stop(', 'cut_stop(', 'ExportSettings.refresh',
                   'export_expect_check(', 'Dáta okna sa medzitým zmenili', 'V paneli sú neplatné polia'].freeze
  DATA_IN_BODY = ['Bom.compute(', 'hardware_expansion(', 'budget_payload(', 'control_payload(', 'sheets_map',
                  'gate[', 'project_name('].freeze
  NEW_OUTPUT_MSG = 'nový výstup: pridaj riadok do ExportPrep::KINDS a začni ExportPrep.start — žiadna kópia úvodu'

  GATE = { stop: nil, note: ' · Zákazka: X (podľa súboru)', project: 'Kuchyňa Novák', merge: true }.freeze

  module_function

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def prep_src
    src('noxun_engine', 'ui', 'export_prep.rb')
  end

  def core_src
    src('noxun_engine', 'ui', 'production_core.rb')
  end

  def body(meth)
    core_src[/def #{meth}\(model, data, generation:, status:, repush:\).*?\n      rescue StandardError/m].to_s
  end

  # Mena funkcii pluginu, ktore otvaraju vyber suboru/priecinka (R4 b).
  def picker_functions
    Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')).sort.each_with_object([]) do |path, out|
      current = nil
      File.read(path, encoding: 'UTF-8').each_line do |line|
        m = line.match(/^\s*def (?:self\.)?([a-z_][a-zA-Z0-9_?!]*)/)
        current = m[1] if m
        next if line.strip.start_with?('#')
        next unless line.include?('UI.savepanel') || line.include?('UI.select_directory')

        out << current unless out.include?(current)
      end
    end
  end

  # Prostredie harnessu H17 pre priame volania `Context`/`start`: sandbox,
  # model, datove stuby, spy poradia (a poruchy) — bez exportu.
  def with_env(spec = {})
    H.with_sandbox do |_sb|
      model = H.prepare_model(spec)
      rec = H::Recorder.new
      saved = []
      col = H.collected_for(spec)
      faults = spec[:faults] || {}
      begin
        H.data_impls(spec, col, rec).each { |n, impl| H.patch!(saved, :PC, n, rec, impl: impl) }
        ei = H.expansion_impl(spec, rec)
        H.patch!(saved, :PC, :hardware_expansion, rec, impl: ei) if ei
        H::ORDER_SPIES.each do |m, n|
          f = faults["#{m}.#{n}"]
          H.patch!(saved, m, n, rec, order: true, fault: f && RuntimeError.new(f))
        end
        H.with_now { yield model, rec }
      ensure
        H.restore!(saved)
      end
    end
  end

  # Argumenty, s ktorymi sa zavolal `budget_payload` (T1 — bez estimate/layout).
  def capture_budget_args
    seen = []
    orig = PC.method(:budget_payload)
    PC.define_singleton_method(:budget_payload) do |*a|
      seen << a
      orig.call(*a)
    end
    yield seen
  ensure
    PC.define_singleton_method(:budget_payload, orig)
  end

  def start_call(model, data, kind, rec)
    EP.start(model, data, kind, generation: 1, status: ->(m, e = false) { rec.status(m, e) },
                                repush: -> { rec.repush })
  end
end

# =============================================================================
# R4 a JEDNO MIESTO UVODU
# =============================================================================

NxTest.test('H17 R4 a: telo ziadneho exportu z KINDS nema uvod (zber, brany, refresh, `expect`, vety uvodu)') do
  NxH17P::EP::KINDS.each do |kind, meth|
    b = NxH17P.body(meth)
    NxTest.refute(b.empty?, "#{meth}: telo sa naslo")
    NxH17P::INTRO_IN_BODY.each do |needle|
      NxTest.refute(b.include?(needle), "#{meth} (#{kind}): #{needle.inspect} patri do ExportPrep.start")
    end
  end
end

NxTest.test('H17 R4 a: v export_prep.rb su brana `expect`, novsia schema a chrbat PRAVE RAZ') do
  src = NxH17P.prep_src
  %w[export_expect_check( newer_config_stop( cut_stop(].each do |needle|
    NxTest.assert_equal(1, src.scan(needle).length, "#{needle} prave raz")
  end
  code = src.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(1, code.scan('ExportSettings.refresh').length, 'refresh prave raz')
  NxTest.assert(src.include?('ProductionCore.export_expect_check(model, data, merge: kind == :vepo)'),
                '18 + 36 sa porovnava len vo VEPO (`merge: kind == :vepo`)')
  NxTest.assert_equal(0, NxH17P.core_src.scan(/(?<!def )export_expect_check\(/).length,
                      'v ProductionCore brana `expect` uz nikde nevola (len definicia)')
end

# =============================================================================
# R4 b NOVY VYSTUP = RIADOK KINDS
# =============================================================================

NxTest.test('H17 R4 b: funkcie s vyberom suboru/priecinka == hodnoty ExportPrep::KINDS a kazda zacina start') do
  found = NxH17P.picker_functions.sort
  NxTest.assert_equal(NxH17P::EP::KINDS.values.sort, found, NxH17P::NEW_OUTPUT_MSG)
  NxH17P::EP::KINDS.each do |kind, meth|
    b = NxH17P.body(meth)
    i_start = b.index("ExportPrep.start(model, data, #{kind.inspect}, generation: generation, status: status, repush: repush)")
    i_ui = b.index('UI.savepanel') || b.index('UI.select_directory')
    NxTest.assert(i_start && i_ui && i_start < i_ui, "#{meth}: #{NxH17P::NEW_OUTPUT_MSG}")
    NxTest.assert(b.include?("repush: repush)\n        return unless ctx\n"),
                  "#{meth}: odmietnutie pripravy sa respektuje hned (`return unless ctx`)")
  end
  NxTest.assert(NxH17P::EP::KINDS.frozen?, 'KINDS je zmrazeny')
end

NxTest.test('H17 R4 b (§15 A5): inventar matice odmietnuti G2 == ExportPrep::KINDS') do
  NxTest.assert(NxH17P::H.kinds.equal?(NxH17P::EP::KINDS), 'matica G2 iteruje PRAVE ExportPrep::KINDS')
  NxTest.assert_equal(NxH17P::EP::KINDS.keys.map(&:to_s).sort,
                      NxH17P::H.golden('g2').values.first.keys.sort, 'golden G2 pozna kazdy registrovany export')
end

# =============================================================================
# R4 c BEZ STAVU
# =============================================================================

NxTest.test('H17 R4 c: export_prep.rb mimo `class Context` bez @, @@ nikde, Context.new len v start') do
  src = NxH17P.prep_src
  code = src.lines.reject { |l| l.strip.start_with?('#') }.join
  outside = code.sub(/^      class Context\b.*?^      end\n/m, '')
  NxTest.refute(outside.include?('class Context'), 'trieda Context sa vystrihla')
  NxTest.refute(outside.include?('@'), 'modul ExportPrep nema stav (@)')
  NxTest.refute(code.include?('@@'), 'ziadna premenna triedy')
  plugin = Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')).sum do |f|
    File.read(f, encoding: 'UTF-8').scan('Context.new(').length
  end
  NxTest.assert_equal(1, plugin, 'Context vznika LEN v ExportPrep.start')
  NxTest.assert(NxH17P::EP.constants.sort == %i[Context FLUSH_MSG GEN_MSG KINDS], 'ziadna meniteľná konštanta navyse')
  NxTest.assert(NxH17P::EP::GEN_MSG.frozen? && NxH17P::EP::FLUSH_MSG.frozen?, 'vety su zmrazene')
end

NxTest.test('H17 R4 c: dva exporty po sebe = dva zbery a dve brany `expect` (kontext sa nezdiela)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P.with_env do |model, rec|
    data = { 'gen' => 1, 'expect' => NxTest.export_expect(model) }
    a = NxH17P.start_call(model, data, :hw_csv, rec)
    b = NxH17P.start_call(model, data, :budget, rec)
    NxTest.assert(a.is_a?(NxH17P::EP::Context) && b.is_a?(NxH17P::EP::Context), 'oba prejdu')
    NxTest.refute(a.equal?(b), 'dva kontexty')
    NxTest.assert_equal(2, rec.counts['fresh_collect'], 'dva cerstve zbery')
    NxTest.assert_equal(2, rec.log.count { |s| s.start_with?('PC.export_expect_check') }, 'dve brany `expect`')
  end
end

# =============================================================================
# R4 d NACITANIE
# =============================================================================

NxTest.test('H17 R4 d: main.rb nacita ui/export_prep HNED za ui/production_core, pred ui/studio_dialog') do
  parts = NxH17P.src('noxun_engine', 'main.rb').scan(/AppLifecycle\.require_part '([^']+)'/).flatten
  i = parts.index('noxun_engine/ui/export_prep')
  NxTest.assert(i, 'export_prep je v zozname casti main.rb')
  NxTest.assert_equal('noxun_engine/ui/production_core', parts[i - 1], 'hned za ui/production_core')
  NxTest.assert_equal('noxun_engine/ui/studio_dialog', parts[i + 1], 'pred ui/studio_dialog')
  NxTest.assert_equal(1, parts.count('noxun_engine/ui/export_prep'), 'prave raz')
end

NxTest.test('H17 R4 d: tests/helper.rb nacita ui/export_prep (S21 — nenacitany modul nesmie prejst naprazdno)') do
  NxTest.assert(NxH17P.src('tests', 'helper.rb').include?("require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'export_prep')"),
                'helper nacita export_prep')
  NxTest.assert(defined?(Noxun::Engine::ExportPrep), 'ExportPrep je po helperi definovany')
end

NxTest.test('H17 R4 d: export_prep.rb pri nacitani nevola nic mimo definicii (samostatny proces bez ProductionCore)') do
  NxTest.skip!('samostatny Ruby proces len headless') unless NxTest.headless?
  path = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'export_prep.rb')
  code = "require #{path.inspect}; e = Noxun::Engine; " \
         "puts [e.const_defined?(:ProductionCore), e::ExportPrep::KINDS.keys.join(',')].join('|')"
  out, err, st = Open3.capture3(RbConfig.ruby, '-e', code)
  NxTest.assert(st.success?, "nacitanie zlyhalo: #{err}")
  NxTest.assert_equal('false|vepo,hw_csv,budget,offer', out.strip, 'nacita sa bez ProductionCore')
end

# =============================================================================
# R4 e DATA A NAZOV LEN Z KONTEXTU
# =============================================================================

NxTest.test('H17 R4 e: telo exportu z KINDS necita kusovnik, expanziu, rozpocet, kontrolu, katalog ani nazov mimo kontextu') do
  NxH17P::EP::KINDS.each_value do |meth|
    b = NxH17P.body(meth)
    NxH17P::DATA_IN_BODY.each do |needle|
      NxTest.refute(b.include?(needle), "#{meth}: #{needle.inspect} — data a nazov idu z `ctx`")
    end
    NxTest.assert(b.include?('ctx.project'), "#{meth}: nazov = ctx.project")
    NxTest.assert(b.include?('ctx.name_note'), "#{meth}: veta automatickeho nazvu = ctx.name_note")
  end
end

# =============================================================================
# R4 f ROZDIELNE BRANY OSTALI (spravanie z golden G2 — ten isty beh drzi test_h17_golden)
# =============================================================================

NxTest.test('H17 R4 f: brany druhu vystupu ostali rozdielne (G2: 18 + 36, kit/stavba, budget_std, duplicity, ponuka)') do
  g2 = NxH17P::H.golden('g2')
  stops = ->(t, k) { g2[t][k]['pickers'].empty? }
  NxTest.assert(stops.call('expect_ine_18_36', 'vepo'), 'ine 18 + 36: VEPO stoji')
  %w[hw_csv budget offer].each { |k| NxTest.refute(stops.call('expect_ine_18_36', k), "ine 18 + 36: #{k} prejde") }
  NxTest.refute(stops.call('konflikt_stavby', 'vepo'), 'konflikt stavby: VEPO prejde (scope :kit)')
  %w[hw_csv budget offer].each { |k| NxTest.assert(stops.call('konflikt_stavby', k), "konflikt stavby: #{k} stoji") }
  %w[vepo hw_csv budget offer].each { |k| NxTest.assert(stops.call('kit_chyba', k), "chybajuci kit: #{k} stoji") }
  %w[vepo hw_csv].each { |k| NxTest.refute(stops.call('budget_std', k), "budget_std: #{k} prejde") }
  %w[budget offer].each { |k| NxTest.assert(stops.call('budget_std', k), "budget_std: #{k} stoji") }
  NxTest.refute(stops.call('duplicita_blokujuca', 'vepo'), 'duplicita: VEPO prejde')
  %w[vepo hw_csv budget].each { |k| NxTest.refute(stops.call('zostava_zaporna', k), "zaporna zostava: #{k} prejde") }
  NxTest.assert(stops.call('zostava_zaporna', 'offer'), 'zaporna zostava: ponuka stoji')
  NxTest.assert(g2['expanzia_prazdna']['hw_csv']['status'].start_with?('Model nemá žiadne kovanie'),
                'CSV: prazdne kovanie ma vlastnu vetu')
end

# =============================================================================
# T1 CONTEXT
# =============================================================================

NxTest.test('H17 T1: citacka si pamata aj nil — hw_exp sa vyhodnoti RAZ, rozpocet expanziu zopakuje (nil -> nil = 2)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P.with_env(exp: [nil, nil]) do |model, rec|
    ctx = NxH17P::EP::Context.new(model, :budget, NxH17P::GATE)
    NxTest.assert(ctx.hw_exp.nil?, 'expanzia nil')
    NxTest.assert(ctx.hw_exp.nil?, 'druhe citanie nil')
    NxTest.assert_equal(1, rec.expansions, 'citacka sa vyhodnotila RAZ (pamata si nil)')
    NxTest.assert(ctx.budget.is_a?(Hash), 'rozpocet vznikne aj bez expanzie')
    NxTest.assert_equal(2, rec.expansions, 'fallback `budget_payload` expanziu zopakoval (§15 A2) — ako main')
    ctx.budget
    ctx.control
    NxTest.assert_equal(2, rec.expansions, 'ziadna dalsia expanzia (rozpocet aj kontrola su v pamati)')
  end
end

NxTest.test('H17 T1: nil -> platna — rozpocet je z DRUHEHO (platneho) vysledku, citacka ostava nil') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P.with_env(exp: [nil, NxH17Fixture.expansion]) do |model, rec|
    ctx = NxH17P::EP::Context.new(model, :offer, NxH17P::GATE)
    NxTest.assert(ctx.hw_exp.nil?, 'citacka = prvy vysledok (nil)')
    hw = Array(ctx.budget['sections']).find { |s| s['key'] == 'hardware' }
    NxTest.assert(hw && !Array(hw['rows']).empty?, 'rozpocet nesie kovanie z druhej (platnej) expanzie')
    NxTest.assert_equal(2, rec.expansions, 'dve skutocne expanzie — ako main')
    NxTest.assert(ctx.hw_exp.nil?, 'kontext expanziu neopravil (M26)')
  end
end

NxTest.test('H17 T1: gate je nemenny a z jedneho volania; project/merge/name_note = gate') do
  src = { stop: nil, note: '', project: 'A', merge: false }
  ctx = NxH17P::EP::Context.new(Object.new, :vepo, src)
  src[:project] = 'B'
  NxTest.assert(ctx.gate.frozen?, 'gate je zmrazeny')
  NxTest.assert_equal(%w[A false], [ctx.project, ctx.merge.to_s], 'zmena povodneho Hashu kontext nemeni')
  NxTest.assert_equal('', ctx.name_note)
  NxTest.assert_equal(:vepo, ctx.kind)
end

NxTest.test('H17 T1: rozpocet bez estimate/layout, s tou istou expanziou a katalogom dosiek; dva kontexty = dva zbery') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P.with_env do |model, rec|
    NxH17P.capture_budget_args do |seen|
      ctx = NxH17P::EP::Context.new(model, :vepo, NxH17P::GATE)
      ctx.control
      NxTest.assert_equal(1, seen.length, 'rozpocet raz')
      args = seen.first
      NxTest.assert_equal(6, args.length, 'model, bom, zber, estimate, expanzia, katalog — bez layout')
      NxTest.assert(args[3].nil?, 'estimate = nil (odhad si rozpocet spocita sam — S9)')
      NxTest.assert(args[4].equal?(ctx.hw_exp), 'ta ista expanzia')
      NxTest.assert(args[5].equal?(ctx.smap), 'ten isty katalog dosiek')
      NxTest.assert(args[1].equal?(ctx.bom) && args[2].equal?(ctx.collected), 'ten isty kusovnik a zber')
      NxH17P::EP::Context.new(model, :vepo, NxH17P::GATE).collected
      NxTest.assert_equal(2, rec.counts['fresh_collect'], 'dva kontexty = dva zbery')
    end
  end
end

NxTest.test('H17 T1: poradie prvych citani urcuje export — budget sam = bom -> hw_exp -> smap, ponuka cita smap vopred') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P.with_env do |model, rec|
    NxH17P::EP::Context.new(model, :budget, NxH17P::GATE).budget
    NxTest.assert_equal(%w[PC.fresh_collect Bom.compute PC.hardware_expansion PC.sheets_map PC.budget_payload], rec.log,
                        'argumenty rozpoctu v poradi kusovnik -> expanzia -> katalog dosiek')
  end
  NxH17P.with_env do |model, rec|
    ctx = NxH17P::EP::Context.new(model, :offer, NxH17P::GATE)
    ctx.bom
    ctx.smap
    ctx.budget
    NxTest.assert_equal(%w[PC.fresh_collect Bom.compute PC.sheets_map PC.hardware_expansion PC.budget_payload], rec.log,
                        'ponuka (§15 A3): kusovnik -> katalog dosiek -> expanzia -> rozpocet')
  end
end

NxTest.test('H17 T1: vynimka citacky prejde von (ziadny rescue v kontexte) a nic sa nezapamata') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P.with_env(faults: { 'Bom.compute' => 'H17 T1 porucha' }) do |model, _rec|
    ctx = NxH17P::EP::Context.new(model, :budget, NxH17P::GATE)
    NxTest.assert_raise('H17 T1 porucha') { ctx.bom }
    NxTest.assert_raise('H17 T1 porucha') { ctx.bom }
    NxTest.assert_raise('H17 T1 porucha') { ctx.control }
  end
  NxTest.assert(NxH17P.prep_src.lines.none? { |l| !l.strip.start_with?('#') && l.include?('rescue') },
                'export_prep.rb nema rescue (S9)')
end

NxTest.test('H17 T1 (§15 A4): harness — Time.now vrati NOVY objekt, lokalny cas po rozpocte ostava') do
  NxH17P::H.with_now do
    a = Time.now
    b = Time.now
    NxTest.refute(a.equal?(b), 'kazde volanie = novy objekt')
    a.utc
    NxTest.assert_equal('14:05 +0200', Time.now.strftime('%H:%M %z'), 'Time.now.utc v rozpocte cas exportu neposunie')
  end
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P.with_env do |model, _rec|
    NxH17P::EP::Context.new(model, :vepo, NxH17P::GATE).budget
    NxTest.assert_equal('2026-10-01 14:05 +0200', Time.now.strftime('%Y-%m-%d %H:%M %z'), 'lokalny cas po rozpocte')
  end
end

# =============================================================================
# T2 START
# =============================================================================

NxTest.test('H17 T2: start — kazda vetva R1.2 (veta, farba, repush, nil) a poradie; uspech = Context') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  ep = NxH17P::EP
  cases = [
    [{ 'gen' => 0 }, {}, ep::GEN_MSG, 1, []],
    [{ 'flush_blocked' => true }, {}, ep::FLUSH_MSG, 0, []],
    [{ 'expect' => nil }, {}, Noxun::Engine::ExportSettings::EXPECT_STALE, 0, ['ES.refresh', 'PC.export_expect_check(merge: false)']],
    [{}, { col: ->(c) { c.merge(newer_configs: ['CAB-009']) } }, :newer, 0,
     ['ES.refresh', 'PC.export_expect_check(merge: false)', 'PC.fresh_collect', 'PC.newer_config_stop']],
    [{}, { col: ->(c) { c.merge(cut_issues: [{ 'code' => Noxun::Engine::Bom::CUT_BLOCKERS.first, 'owner_id' => 'C' }]) } },
     :cut, 0, ['ES.refresh', 'PC.export_expect_check(merge: false)', 'PC.fresh_collect', 'PC.newer_config_stop', 'PC.cut_stop']]
  ]
  cases.each do |extra, spec, want, repush, order|
    NxH17P.with_env(spec) do |model, rec|
      data = { 'gen' => 1, 'expect' => NxTest.export_expect(model) }.merge(extra)
      data.delete('expect') if extra.key?('expect')
      res = NxH17P.start_call(model, data, :hw_csv, rec)
      NxTest.assert(res.nil?, "#{want}: start vrati nil")
      msg, err = rec.statuses.last
      NxTest.assert_equal(true, err, "#{want}: cervena")
      NxTest.assert_equal(1, rec.statuses.length, "#{want}: jedna veta")
      NxTest.assert(msg.start_with?('Export sa NEVYKONAL'), "#{want}: #{msg}") if want.is_a?(Symbol)
      NxTest.assert_equal(want, msg) unless want.is_a?(Symbol)
      NxTest.assert_equal(repush, rec.repushes, "#{want}: repush")
      NxTest.assert_equal(order + ['status'], rec.log.reject { |s| s == 'repush' },
                          "#{want}: poradie krokov")
    end
  end
  NxH17P.with_env do |model, rec|
    ctx = NxH17P.start_call(model, { 'gen' => 1, 'expect' => NxTest.export_expect(model) }, :offer, rec)
    NxTest.assert(ctx.is_a?(ep::Context), 'uspech = Context')
    NxTest.assert_equal([:offer, 'Kuchyňa Novák', true, ''], [ctx.kind, ctx.project, ctx.merge, ctx.name_note])
    NxTest.assert(rec.statuses.empty? && rec.repushes.zero?, 'uspech je ticho (veta patri exportu)')
    NxTest.assert_equal(['ES.refresh', 'PC.export_expect_check(merge: false)', 'PC.fresh_collect', 'PC.newer_config_stop', 'PC.cut_stop'],
                        rec.log, 'zber raz, brany v poradi')
  end
end

NxTest.test('H17 T2: `merge: true` LEN pre :vepo — ostatne druhy 18 + 36 neporovnavaju') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH17P::EP::KINDS.each_key do |kind|
    NxH17P.with_env do |model, rec|
      exp = NxTest.export_expect(model).merge('merge' => false) # ulozene je true
      res = NxH17P.start_call(model, { 'gen' => 1, 'expect' => exp }, kind, rec)
      NxTest.assert_equal(kind == :vepo, res.nil?, "#{kind}: iny 18 + 36 zastavi len VEPO")
      NxTest.assert_equal(["PC.export_expect_check(merge: #{kind == :vepo})"],
                          rec.log.grep(/export_expect_check/), "#{kind}: brana raz, merge len vo VEPO")
    end
  end
end

NxTest.test('H17 T2: neznamy druh = ArgumentError; v exporte konci vetou jeho rescue („Chyba exportu: …")') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  ep = NxH17P::EP
  NxH17P.with_env do |model, rec|
    NxTest.assert_raise(/neznámy druh exportu :xyz/) { NxH17P.start_call(model, { 'gen' => 1 }, :xyz, rec) }
    NxTest.assert(rec.log.empty?, 'pred chybou programu sa nic nevola')
  end
  orig = ep::KINDS
  begin
    ep.send(:remove_const, :KINDS)
    ep.const_set(:KINDS, orig.reject { |k, _| k == :vepo }.freeze)
    msg = nil
    NxH17P.with_env do |model, _rec|
      NxH17P::PC.do_export(model, { 'gen' => 1 }, generation: 1, status: ->(m, _e = false) { msg = m }, repush: -> {})
    end
    NxTest.assert_equal('Chyba exportu: ExportPrep: neznámy druh exportu :vepo', msg, 'rescue VEPO exportu')
  ensure
    ep.send(:remove_const, :KINDS)
    ep.const_set(:KINDS, orig)
  end
end
