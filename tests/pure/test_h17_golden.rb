# frozen_string_literal: true
# H17 / R0 — GOLDEN T0 SPOLOCNEJ PRIPRAVY EXPORTOV (package
# `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H17.md` §6 R0, §15 A2–A5).
#
# PRECO: H17a vyreze spolocny uvod styroch exportov (VEPO, CSV kovania, XLSX
# rozpoctu a ponuky) do `ExportPrep.start` a ich data do lenivého kontextu.
# Pre pouzivatela sa NESMIE zmenit nic. Tento test to dokazuje odtlackom
# zachytenym na NEZMENENOM kode (1. commit H17a, v0.17.28):
#   G1 bajty sastnej cesty — cele texty CSV a LOG (verzia -> «VERSION», prave
#      1 nahrada vo VEPO LOGu), XLSX SHA-256, mena suborov a priecinka, veta,
#      farba, `repush`, picker, ulozeny posledny priecinok,
#   G2 matica odmietnuti — kazdy spustac × KAZDY export z `ExportPrep::KINDS`
#      (spolocne spustace uvodu povinne aj pre export, ktory golden nepozna),
#   G3 subeh dvoch bran, G4 poradie krokov (v kazdom zazname G1–G3),
#   G5 parita Kontroly (VEPO LOG == `counts` pushu Studia),
#   G6 parita Narezoveho planu (VEPO stoji <=> `layout_block_reasons`).
# Fixtura sa NEREGENERUJE (generator `tests/fixtures/h17_golden/generate.rb`
# len na nezmenenom kode) — rozdiel je NALEZ.
require_relative '../helper' unless defined?(NxTest)
require_relative 'h17_harness'

module NxH17T
  module_function

  # Prva odlisnost dvoch JSON stromov (citatelna sprava pri pade).
  def first_diff(want, got, path = [])
    return nil if want == got
    if want.is_a?(Hash) && got.is_a?(Hash)
      return "#{path.join('/')}: kluce #{want.keys.inspect} != #{got.keys.inspect}" if want.keys != got.keys

      want.each_key do |k|
        d = first_diff(want[k], got[k], path + [k])
        return d if d
      end
      return nil
    end
    if want.is_a?(Array) && got.is_a?(Array)
      return "#{path.join('/')}: dlzka #{want.length} != #{got.length} (#{want.inspect[0, 300]} vs #{got.inspect[0, 300]})" if want.length != got.length

      want.each_with_index do |w, i|
        d = first_diff(w, got[i], path + [i])
        return d if d
      end
      return nil
    end
    "#{path.join('/')}: ocakavane #{want.inspect[0, 400]}, dostal #{got.inspect[0, 400]}"
  end

  def same!(want, got, what)
    d = first_diff(want, got)
    NxTest.assert(d.nil?, "#{what}: #{d}")
  end

  def expect_calls(res)
    res['order'].count { |s| s.start_with?('PC.export_expect_check') }
  end
end

NxTest.test('H17 T0 G1: sastna cesta 4 exportov — subory, mena, vety, picker a poradie bajtovo ako main') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  want = NxH17.golden('g1')
  NxTest.assert_equal(want.keys, NxH17.g1_cases.keys, 'pripady G1')
  NxH17.g1_cases.each do |name, spec|
    got = NxH17.json(NxH17.run(spec))
    NxH17T.same!(want[name], got, "G1 #{name}")
    # S21: kazdy export cita CERSTVY zber prave raz a branu `expect` prave raz.
    NxTest.assert_equal(1, got['counts']['fresh_collect'], "G1 #{name}: jeden cerstvy zber cez stub")
    NxTest.assert_equal(1, NxH17T.expect_calls(got), "G1 #{name}: brana `expect` prave raz (G4)")
    NxTest.assert(got['expansions'] >= 1, "G1 #{name}: expanzia kovania pouzita")
  end
end

NxTest.test('H17 T0 G1: lokalny cas po rozpocte — VEPO LOG a CSV kovania nesu zamrazeny LOKALNY cas, verzia prave raz') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  vepo = NxH17.run(kind: :vepo)
  log = vepo['files'].find { |f| f['file'].end_with?('_export.log') }
  NxTest.assert(log, 'VEPO LOG vznikol')
  NxTest.assert(log['text'].include?("Dátum:   #{NxH17::STAMP}"), 'Dátum v LOGu = zamrazeny lokalny cas (nie UTC po rozpocte)')
  NxTest.assert_equal(1, vepo['files'].sum { |f| f['version_hits'].to_i }, 'verzia pluginu v exporte prave raz (LOG)')
  NxTest.assert(vepo['order'].index('PC.budget_payload') < vepo['order'].index('VepoExport.build'),
                'rozpocet sa pocita PRED zostavenim VEPO (cas sa cita po nom)')
  csv = NxH17.run(kind: :hw_csv)['files'].first
  NxTest.assert(csv['text'].lines.first.include?(NxH17::STAMP), '1. riadok CSV kovania = zamrazeny lokalny cas')
end

NxTest.test('H17 T0 G2: matica odmietnuti — kazdy spustac × kazdy export z KINDS (veta, farba, picker, zapisy, poradie)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  want = NxH17.golden('g2')
  triggers = NxH17.g2_triggers
  NxTest.assert_equal(want.keys.sort, triggers.keys.sort, 'spustace G2')
  NxH17.kinds.each_key do |kind|
    triggers.each do |name, spec|
      got = NxH17.g2_run(name, kind)
      ref = want[name][kind.to_s]
      NxH17T.same!(ref, got, "G2 #{name} × #{kind}") if ref
      NxTest.assert(NxH17T.expect_calls(got) <= 1, "G2 #{name} × #{kind}: brana `expect` najviac raz")
      next unless spec[:intro]

      # §15 A5: spolocny spustac uvodu — pre KAZDY registrovany export (aj
      # novy, ktory golden este nepozna) rovnaka veta, ziadny picker ani zapis.
      shared = want[name]['vepo']
      if spec[:intro] == true
        NxTest.assert_equal(shared['status'], got['status'], "G2 #{name} × #{kind}: veta uvodu")
      end
      NxTest.assert_equal(true, got['error'], "G2 #{name} × #{kind}: cervena")
      NxTest.assert_equal([], got['pickers'], "G2 #{name} × #{kind}: picker sa neotvoril")
      NxTest.assert_equal([], got['files'], "G2 #{name} × #{kind}: ziadny subor")
      NxTest.assert_equal(got['last_dir_before'], got['last_dir'], "G2 #{name} × #{kind}: posledny priecinok bez zmeny")
    end
  end
end

NxTest.test('H17 T0 G2: sekvencie expanzie nil -> nil a nil -> platna — pocet skutocnych expanzii ako main') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  want = NxH17.golden('g2')
  %w[budget offer].each do |k|
    NxTest.assert_equal(2, want['expanzia_nil_nil'][k]['expansions'], "#{k}: nil -> nil = 2 expanzie (fallback rozpoctu)")
    NxTest.assert_equal(2, want['expanzia_nil_platna'][k]['expansions'], "#{k}: nil -> platna = 2 expanzie")
  end
  NxTest.assert_equal(1, want['expanzia_nil_platna']['hw_csv']['expansions'], 'CSV pri nil skonci po prvej')
end

NxTest.test('H17 T0 G3: subeh dvoch bran — prednost a veta ako main') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  want = NxH17.golden('g3')
  NxTest.assert_equal(want.keys, NxH17.g3_combos.keys, 'kombinacie G3')
  got = NxH17.g3_snapshot
  want.each do |name, by_kind|
    by_kind.each { |kind, w| NxH17T.same!(w, got[name][kind], "G3 #{name} × #{kind}") }
  end
end

NxTest.test('H17 T0 G5: parita Kontroly — pocty KONTROLA vo VEPO LOGu == counts pushu Studia (s ORANGE rozpoctu)') do
  NxTest.skip!('headless: stub Sketchup') unless NxTest.headless?
  log = NxH17.log_counts(NxH17.run(kind: :vepo))
  push = NxH17.push_counts
  NxTest.assert(log, 'LOG ma sekciu KONTROLA')
  NxTest.assert_equal([push['red'], push['orange']], [log['red'], log['orange']], 'LOG a sekcia Kontrola hovoria jedno cislo')
  vepo_text = NxH17.run(kind: :vepo)['files'].find { |f| f['file'].end_with?('_export.log') }['text']
  NxTest.assert(vepo_text.include?('riadok bez ceny'), 'fixtura nesie ORANGE z rozpoctu (kontrola s `budget:`)')
end

NxTest.test('H17 T0 G6: parita Narezoveho planu — VEPO stoji prave vtedy, ked layout_block_reasons nesie dovody') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  tr = NxH17.g2_triggers
  names = %w[novsia_skrinka novsia_doska kit_chyba konflikt_stavby vyklop_neuplny zaves_nesedi
             expanzia_nil_recept expanzia_nil_vyklop] + tr.keys.grep(/\Achrbat_/)
  names.each do |name|
    reasons = NxH17.layout_reasons(tr.fetch(name))
    res = NxH17.run(tr.fetch(name).merge(kind: :vepo))
    stopped = res['pickers'].empty?
    NxTest.assert_equal(!reasons.empty?, stopped, "G6 #{name}: VEPO stoji <=> plan blokovany")
    next unless stopped

    NxTest.assert_equal(NxH17::PC.export_blocked_status(reasons), res['status'], "G6 #{name}: tie iste dovody")
  end
end
