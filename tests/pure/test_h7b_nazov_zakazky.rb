# frozen_string_literal: true
# H7b — NAZOV ZAKAZKY V HLAVICKE STUDIA (server): payload `vepo`, mena
# exportov pre tooltip, veta po exporte s predvolenym nazvom, echo hlavicky po
# exporte a POVINNA kontrola `expect` v styroch exportoch (package
# `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H7.md` §6 R-B1–R-B3, R-B5b, R-B9 +
# §16 B2 a §17 C1/C2 — §17 MA PREDNOST).
#
#   T-B7  payload aj echo: 3 povodne kluce v poradi + source/file/export_names
#         (+ pending/notice §15 A1); `source` pre vsetky tri podoby; mena =
#         vystupy 4 funkcii exportu (parita s golden T0a, bez regeneracie)
#   R-B2  skladac mien: jedno miesto mena CSV kovania, `export_file_names`
#   T-B8  veta po exporte pri „projekt" na konci, farba bez zmeny; file/set bez vety
#   T-B9  4 obaly `StudioDialog` volaju `push_vepo_bar` po navrate (aj pri
#         odmietnuti), generacia sa nemeni
#   T-B11 export s `expect`: zlyhany zapis nazvu -> odmietnuty PRED vyberom
#         suboru; uspech -> mena = T0c; prekrizene nazov × 18 + 36; obratene
#         poradie; BEZ `expect` / neplatny tvar = odmietnuty (fail-closed, C1);
#         rucny zaznam > 120 znakov nevyrobi falosny nesulad (C2); relay panela
#   T-B12 payload `pending`/`notice` v scenari T-A11
#   P3 z H7a: samooprava neplatneho `project_names` pri zapise NAZVU sa loguje
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'

require_relative 'test_h7a_export_settings' unless defined?(NxH7A) && NxH7A.const_defined?(:SD)

module NxH7B
  E  = Noxun::Engine
  PC = E::ProductionCore
  S  = E::ExportSettings
  KEYS = %w[project default_project merge_18_36 source file export_names pending notice].freeze
  EXPORTS = %i[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].freeze

  module_function

  def unsaved(guid = 'U-B7')
    NxH7A::MODEL.new('', guid)
  end

  def saved(path = 'C:/Zakazky/Kúpeľňa Horná.skp', guid = 'S-B7')
    NxH7A::MODEL.new(path, guid)
  end

  # Ten isty `expect`, aky by po pushi poslalo okno (payload `vepo`).
  def window_expect(mdl)
    v = PC.vepo_payload(mdl)
    { 'project' => v['project'], 'merge' => v['merge_18_36'] }
  end

  # Jeden export nad sandboxom (nazov a nastavenia SKUTOCNE, zber stubnuty).
  # -> { msg:, err:, pickers: [...], files: [...], collects: n }
  def run(method, mdl, data)
    msg = nil
    err = nil
    seen = []
    files = []
    collects = 0
    col = method == :do_export ? NxH7G.collected([NxH7G.record(1, 18.0)]) : NxH7G.collected([])
    stubs = NxH7G.collect_stubs(col).merge(fresh_collect: ->(*_a) { collects += 1; col })
    Dir.mktmpdir('nx-h7b-') do |dir|
      NxH7G.with_stubs(PC, stubs) do
        NxH7G.with_ui(dir, seen) do
          NxH7G.with_now do
            PC.send(method, mdl, { 'gen' => 1 }.merge(data), generation: 1,
                                                             status: ->(t, e = false) { msg = t; err = e },
                                                             repush: -> {})
          end
        end
      end
      files = Dir.children(dir).sort
    end
    { msg: msg.to_s, err: err, pickers: seen, files: files, collects: collects }
  end

  def method_body(src, name)
    src[/def #{name}\(model, data, generation:, status:, repush:\).*?\n      rescue StandardError/m].to_s
  end

  def core_src
    File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'), encoding: 'UTF-8')
  end

  def studio_rb
    File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'), encoding: 'UTF-8')
  end
end

# =============================================================================
# T-B7 PAYLOAD A ECHO `vepo`
# =============================================================================

NxTest.test('H7b T-B7: payload `vepo` — 3 povodne kluce v poradi, za nimi zdroj, subor, mena, cakajuci nazov') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7G.with_now do
      m = NxH7B.unsaved
      v = NxH7B::PC.vepo_payload(m)
      NxTest.assert_equal(NxH7B::KEYS, v.keys, 'poradie klucov (prve tri bez zmeny — golden H14 T0d)')
      NxTest.assert_equal(['projekt', 'projekt', true, 'default', '', false, ''],
                          [v['project'], v['default_project'], v['merge_18_36'], v['source'], v['file'],
                           v['pending'], v['notice']], 'neulozeny bez nazvu = predvoleny „projekt"')
      s = NxH7B.saved
      v = NxH7B::PC.vepo_payload(s)
      NxTest.assert_equal(['Kúpeľňa Horná', 'file', 'Kúpeľňa Horná'], [v['project'], v['source'], v['file']],
                          'ulozeny bez nazvu = podla suboru')
      NxTest.assert_equal([:ok, ''], NxH7B::S.save_project_name(m, 'Kuchyňa Novák'))
      v = NxH7B::PC.vepo_payload(m)
      NxTest.assert_equal(['Kuchyňa Novák', 'set', ''], [v['project'], v['source'], v['file']],
                          'zadany na NEULOZENOM modeli = set (subor prazdny)')
      NxTest.assert_equal([:ok, ''], NxH7B::S.save_project_name(s, 'Kúpeľňa Horná 2'))
      v = NxH7B::PC.vepo_payload(s)
      NxTest.assert_equal(['Kúpeľňa Horná 2', 'set', 'Kúpeľňa Horná'], [v['project'], v['source'], v['file']],
                          'zadany na ulozenom = set + meno suboru')
      names = v['export_names']
      NxTest.assert_equal(%w[vepo_dir hw_csv budget_xlsx offer_xlsx], names.keys, 'styri mena exportov')
      NxTest.assert_equal(
        { 'vepo_dir' => NxH7B::E::VepoExport.project_slug('Kúpeľňa Horná 2'),
          'hw_csv' => "kovanie_#{NxH7B::E::VepoExport.project_slug('Kúpeľňa Horná 2')}.csv",
          'budget_xlsx' => NxH7B::E::BudgetXlsx.file_name('Kúpeľňa Horná 2', NxH7G::NOW),
          'offer_xlsx' => NxH7B::E::CpXlsx.file_name('Kúpeľňa Horná 2', NxH7G::NOW) },
        names, 'mena = vystupy tych istych funkcii, ktorymi export pomenuje subory (O7)'
      )
    end
  end
end

NxTest.test('H7b R-B2: export_file_names pre 11 nazvov T0a = golden mena (bez regeneracie)') do
  fx = NxH7G.fixture('names')
  NxH7G::NAMES.each do |name|
    got = NxH7B::PC.export_file_names(name, NxH7G::NOW)
    want = { 'vepo_dir' => fx[name]['vepo_dir'], 'hw_csv' => fx[name]['hw_csv'],
             'budget_xlsx' => fx[name]['budget_xlsx'], 'offer_xlsx' => fx[name]['offer_xlsx'] }
    NxTest.assert_equal(want, got, "nazov #{name.inspect}")
    NxTest.assert_equal(fx[name]['hw_csv'], NxH7B::PC.hw_csv_file_name(name), "hw_csv_file_name #{name.inspect}")
  end
end

NxTest.test('H7b R-B2: meno CSV kovania ma JEDNO miesto, skladac vola len 4 funkcie exportu') do
  src = NxH7B.core_src
  NxTest.assert_equal(1, src.scan('"kovanie_#{VepoExport.project_slug(project)}.csv"').length,
                      'vyraz mena CSV kovania je len v `hw_csv_file_name`')
  NxTest.assert(NxH7B.method_body(src, 'do_hw_csv').include?('fname = hw_csv_file_name(project)'),
                '`do_hw_csv` pomenuje subor skladacom (nie vlastnou kopiou)')
  body = src[/def export_file_names\(project, now = Time\.now\).*?\n      end\n/m].to_s
  %w[VepoExport.project_slug(project) hw_csv_file_name(project) BudgetXlsx.file_name(project,\ now)
     CpXlsx.file_name(project,\ now)].each do |call|
    NxTest.assert(body.include?(call), "skladac vola #{call}")
  end
end

NxTest.test('H7b T-B7 (§17 C2): rucny zaznam > 120 znakov — payload posiela UZ normalizovany nazov') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    long = "#{'Z' * 130}  "
    NxH7A.write_raw(NxH7A.path, { 'project_names' => { 'c:/z/a.skp' => long }, 'merge_18_36' => true })
    m = NxH7A.model
    v = NxH7B::PC.vepo_payload(m)
    NxTest.assert_equal('Z' * 120, v['project'], 'payload = strip + strop 120 (to iste, co sa uklada)')
    NxTest.assert_equal('set', v['source'])
  end
end

NxTest.test('H7b T-B7: push_state aj echo `push_vepo_bar` skladaju `vepo` JEDNOU funkciou') do
  rb = NxH7B.studio_rb
  NxTest.assert(rb.include?('vepo: ProductionCore.vepo_payload(model),'), 'plny push')
  echo = rb[/def push_vepo_bar.*?\n        end\n/m].to_s
  NxTest.assert(echo.include?('st = ProductionCore.vepo_payload(m)'), 'echo')
  NxTest.refute(rb.include?('default_project: ExportSettings'), 'ziadna druha kopia skladania payloadu')
  next unless NxTest.headless?

  NxH7A.with_sandbox do
    m = NxH7B.saved
    NxH7B::S.save_project_name(m, 'Echo')
    _t, _r, bar, = NxH7A.opts(m, 'merge' => true)
    NxTest.assert_equal(NxH7B::KEYS, bar.keys, 'echo nesie ten isty tvar ako payload')
    NxTest.assert_equal(%w[Echo set], [bar['project'], bar['source']])
  end
end

# =============================================================================
# T-B12 CAKAJUCI NAZOV V PAYLOADE
# =============================================================================

NxTest.test('H7b T-B12: cakajuci nazov — payload `pending` + serverova `notice` (scenar T-A11)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.pending_setup('{"x":')
    v = NxH7B::PC.vepo_payload(m)
    NxTest.assert_equal(['Zakazka L', 'set', true], [v['project'], v['source'], v['pending']])
    NxTest.assert(v['notice'].start_with?('Názov zákazky „Zakazka L" platí len do zatvorenia SketchUpu'), v['notice'])
    NxTest.assert(v['notice'].include?(NxH7A.path) && v['notice'].include?('vepo_settings.poskodeny.json'),
                  'notice menuje subor a radi PREMENOVAT')
    NxTest.assert(v['notice'].include?('spravidla sa stratí len posledná zmena'), 'C4: podmienena veta nápravy')
    NxTest.assert_equal('', NxH7B::PC.default_name_note(m, v['project']), 'veta „projekt" sa s cakajucim vylucuje')
    zdravy = NxH7B::PC.vepo_payload(NxH7B.unsaved('Z-B12'))
    NxTest.assert_equal([false, ''], [zdravy['pending'], zdravy['notice']], 'zdravy subor = bez stavu')
  end
end

# =============================================================================
# T-B8 VETA PO EXPORTE S PREDVOLENYM NAZVOM
# =============================================================================

NxTest.test('H7b T-B8: veta „pomenované predvoleným názvom" na konci 4 exportov len pri „projekt"') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  note = ' · pomenované predvoleným názvom „projekt" — názov zákazky zadáš v hlavičke Štúdia'
  NxH7A.with_sandbox do
    dflt = NxH7B.unsaved('U-B8')
    file = NxH7B.saved('C:/Zakazky/B8.skp', 'S-B8')
    set = NxH7B.saved('C:/Zakazky/B8b.skp', 'S-B8b')
    NxH7B::S.save_project_name(set, 'Zadana B8')
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, dflt, 'expect' => NxH7B.window_expect(dflt))
      NxTest.assert(r[:msg].end_with?(note), "#{exp}: veta na KONCI statusu: #{r[:msg]}")
      NxTest.refute(r[:err], "#{exp}: farba statusu bez zmeny (neblokuje)")
      NxTest.refute(r[:files].empty?, "#{exp}: subor vznikol (veta nic neblokuje)")
      [file, set].each do |mdl|
        r = NxH7B.run(exp, mdl, 'expect' => NxH7B.window_expect(mdl))
        NxTest.refute(r[:msg].include?('predvoleným názvom'), "#{exp} #{mdl.path}: bez vety: #{r[:msg]}")
        NxTest.refute(r[:err], "#{exp} #{mdl.path}: zeleno")
      end
    end
  end
end

# =============================================================================
# T-B11 EXPORT S `expect` (§16 B2, §17 C1/C2)
# =============================================================================

NxTest.test('H7b T-B11: zlyhany zapis nazvu — export s `expect` sa ODMIETNE pred vyberom suboru') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7B.saved('C:/Zakazky/Zaklad.skp', 'S-B11')
    NxH7B::S.save_project_name(m, 'Stary')
    st = nil
    NxH7A.with_lock_probe(raise_error: Errno::EACCES.new('materials.lock (test)')) do
      st = NxH7B::S.save_project_name(m, 'Nový')
    end
    NxTest.assert_equal(:failed, st.first, 'zapis nazvu zlyhal (zamok)')
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, m, 'expect' => { 'project' => 'Nový', 'merge' => true })
      NxTest.assert(r[:pickers].empty?, "#{exp}: vyber suboru sa NEOTVORIL")
      NxTest.assert(r[:files].empty?, "#{exp}: ziadny subor")
      NxTest.assert_equal(0, r[:collects], "#{exp}: odmietnutie PRED zberom modelu")
      NxTest.assert(r[:err], "#{exp}: cerveno")
      NxTest.assert_equal('Názov zákazky sa neuložil (platí „Stary") — export sa nespustil, skontroluj názov a klikni znova.',
                          r[:msg], exp.to_s)
    end
    # zapis uspeje -> export prejde a mena = to, co skladac (a golden T0c) hovori
    NxTest.assert_equal([:ok, ''], NxH7B::S.save_project_name(m, 'Nový'))
    names = NxH7B::PC.export_file_names('Nový', NxH7G::NOW)
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, m, 'expect' => { 'project' => 'Nový', 'merge' => true })
      NxTest.refute(r[:err], "#{exp}: po uspesnom zapise zeleno (#{r[:msg]})")
      case exp
      when :do_export then NxTest.assert_equal([names['vepo_dir']], r[:files], 'VEPO priecinok')
      when :do_hw_csv then NxTest.assert_equal(names['hw_csv'], r[:pickers].first['name'])
      when :do_budget_xlsx then NxTest.assert_equal(names['budget_xlsx'], r[:pickers].first['name'])
      when :do_cp_xlsx then NxTest.assert_equal(names['offer_xlsx'], r[:pickers].first['name'])
      end
    end
  end
end

NxTest.test('H7b T-B11: prekrizene — nazov ulozeny + 18 + 36 nie: VEPO odmietnuty, CSV/XLSX prejdu; naopak vsetky 4 odmietnute') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7B.saved('C:/Zakazky/Kriz.skp', 'S-KRIZ')
    NxTest.assert_equal([:ok, ''], NxH7B::S.save_project_name(m, 'Kríž'))
    NxH7A.with_lock_probe(raise_error: Errno::EACCES.new('lock')) do
      NxTest.assert_equal(:failed, NxH7B::S.save_merge_18_36(false).first, '18 + 36 sa nezapisalo')
    end
    exp_data = { 'expect' => { 'project' => 'Kríž', 'merge' => false } }
    r = NxH7B.run(:do_export, m, exp_data)
    NxTest.assert(r[:pickers].empty? && r[:err], 'VEPO: 18 + 36 nesedi -> odmietnuty pred vyberom priecinka')
    NxTest.assert_equal('Nastavenie 18 + 36 sa neuložilo (platí: zapnuté) — export sa nespustil, skontroluj nastavenie a klikni znova.',
                        r[:msg])
    %i[do_hw_csv do_budget_xlsx do_cp_xlsx].each do |exp|
      r = NxH7B.run(exp, m, exp_data)
      NxTest.refute(r[:err], "#{exp}: 18 + 36 vystup nemeni -> prejde (#{r[:msg]})")
      NxTest.refute(r[:pickers].empty?, "#{exp}: vyber suboru sa otvoril")
    end
  end
  NxH7A.with_sandbox do
    m = NxH7B.saved('C:/Zakazky/Kriz2.skp', 'S-KRIZ2')
    NxTest.assert_equal([:ok, ''], NxH7B::S.save_merge_18_36(false))
    NxH7A.with_lock_probe(raise_error: Errno::EACCES.new('lock')) do
      NxTest.assert_equal(:failed, NxH7B::S.save_project_name(m, 'Neulozeny').first)
    end
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, m, 'expect' => { 'project' => 'Neulozeny', 'merge' => false })
      NxTest.assert(r[:pickers].empty? && r[:err], "#{exp}: nazov nesedi -> odmietnuty")
      NxTest.assert(r[:msg].start_with?('Názov zákazky sa neuložil (platí „Kriz2")'), "#{exp}: #{r[:msg]}")
    end
  end
end

NxTest.test('H7b T-B11: obratene poradie (export pred zapisom) — odmietnutie, druhy pokus po zapise prejde') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7B.saved('C:/Zakazky/Poradie.skp', 'S-POR')
    NxH7B::S.save_project_name(m, 'Staré')
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, m, 'expect' => { 'project' => 'Nové', 'merge' => true })
      NxTest.assert(r[:err] && r[:pickers].empty?, "#{exp}: export pred zapisom odmietnuty")
    end
    NxH7B::S.save_project_name(m, 'Nové')
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, m, 'expect' => { 'project' => 'Nové', 'merge' => true })
      NxTest.refute(r[:err], "#{exp}: klik znova po zapise prejde (#{r[:msg]})")
    end
  end
end

NxTest.test('H7b T-B11 (§17 C1): BEZ `expect` alebo s neplatnym tvarom = odmietnute vo vsetkych 4 (fail-closed)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  stale = 'Okno je zastarané — zatvor a otvor Štúdio a klikni znova.'
  NxH7A.with_sandbox do
    m = NxH7B.saved('C:/Zakazky/Stary.skp', 'S-OLD')
    bad = [{}, { 'expect' => {} }, { 'expect' => nil }, { 'expect' => 'Stary' },
           { 'expect' => { 'project' => 5, 'merge' => true } },
           { 'expect' => { 'project' => 'Stary' } },
           { 'expect' => { 'project' => 'Stary', 'merge' => 'true' } },
           { 'expect' => { project: 'Stary', merge: true } }]
    NxH7B::EXPORTS.each do |exp|
      bad.each do |data|
        r = NxH7B.run(exp, m, data)
        NxTest.assert_equal(stale, r[:msg], "#{exp} #{data.inspect}")
        NxTest.assert(r[:err] && r[:pickers].empty? && r[:files].empty?, "#{exp} #{data.inspect}: nic nevzniklo")
        NxTest.assert_equal(0, r[:collects], "#{exp} #{data.inspect}: PRED zberom")
      end
      ok = NxH7B.run(exp, m, 'expect' => { 'project' => 'Stary', 'merge' => true })
      NxTest.refute(ok[:err], "#{exp}: platny `expect` prejde (#{ok[:msg]})")
    end
  end
end

NxTest.test('H7b T-B11 (§17 C2): rucny zaznam > 120 znakov — export s `expect` z payloadu PREJDE') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, { 'project_names' => { 'c:/z/a.skp' => 'Q' * 130 }, 'merge_18_36' => true })
    m = NxH7A.model
    # Brana `expect` musi prejst (vyber suboru sa otvori). Dobehnutie VEPO zapisu
    # sa tu neoveruje — 130-znakovy priecinok by v docasnom adresari prekrocil
    # limit cesty Windows (vzor T0a).
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, m, 'expect' => NxH7B.window_expect(m))
      NxTest.refute(r[:pickers].empty?, "#{exp}: ziadny trvaly falosny nesulad (#{r[:msg]})")
      NxTest.refute(r[:msg].start_with?('Názov zákazky sa neuložil'), "#{exp}: #{r[:msg]}")
    end
    # aj prazdny/medzerovy text = predvoleny nazov (to iste pravidlo ako pri zapise)
    m2 = NxH7B.saved('C:/Zakazky/Pr.skp', 'S-PR')
    r = NxH7B.run(:do_hw_csv, m2, 'expect' => { 'project' => '   ', 'merge' => true })
    NxTest.refute(r[:err], "prazdny expect = predvoleny nazov suboru (#{r[:msg]})")
  end
end

NxTest.test('H7b T-B11: brany generacie a flush idu PRED `expect` (ich hlasky sa nemenia)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7B.saved
    NxH7B::EXPORTS.each do |exp|
      r = NxH7B.run(exp, m, 'gen' => 0)
      NxTest.assert_equal('Dáta okna sa medzitým zmenili — skús export znova.', r[:msg], "#{exp}: generacia prva")
      r = NxH7B.run(exp, m, 'flush_blocked' => true)
      NxTest.assert(r[:msg].start_with?('V paneli sú neplatné polia'), "#{exp}: flush pred `expect`")
    end
  end
end

NxTest.test('H7b T-B11: poradie v tele 4 exportov — refresh → expect → zber → vyber suboru; 18 + 36 len VEPO') do
  src = NxH7B.core_src
  NxH7B::EXPORTS.each do |exp|
    body = NxH7B.method_body(src, exp)
    NxTest.refute(body.empty?, "#{exp}: telo sa naslo")
    i_gen = body.index("data['gen'].to_i == generation.to_i")
    i_flush = body.index("data['flush_blocked']")
    i_ref = body.index('ExportSettings.refresh')
    i_exp = body.index('export_expect_stop(model, data')
    i_col = body.index('fresh_collect(model)')
    i_ui = body.index('UI.savepanel') || body.index('UI.select_directory')
    NxTest.assert([i_gen, i_flush, i_ref, i_exp, i_col, i_ui].none?(&:nil?), "#{exp}: vsetky kroky su v tele")
    NxTest.assert(i_gen < i_flush && i_flush < i_ref && i_ref < i_exp && i_exp < i_col && i_col < i_ui,
                  "#{exp}: poradie generacia → flush → refresh → expect → zber → vyber suboru")
    NxTest.assert_equal(exp == :do_export, body.include?('export_expect_stop(model, data, merge: true)'),
                        "#{exp}: 18 + 36 sa porovnava len vo VEPO")
  end
end

# =============================================================================
# T-B9 ECHO HLAVICKY PO EXPORTE (StudioDialog)
# =============================================================================

NxTest.test('H7b T-B9: 4 obaly StudioDialog volaju `push_vepo_bar` po navrate — aj pri odmietnuti, generacia bez zmeny') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7B.saved
    NxH7B::EXPORTS.each do |exp|
      NxH7A.with_window(m) do |scripts, pushes|
        sd = NxH7A::SD
        gen = sd.instance_variable_get(:@generation)
        # zastarana generacia = realne odmietnutie v jadre (repush + status)
        sd.send(exp, { 'gen' => gen - 5 }.to_json)
        i_st = scripts.index { |s| s.start_with?('NX.setStatus(') }
        i_bar = scripts.rindex { |s| s.include?('NX.setVepoBar(') }
        NxTest.refute(i_bar.nil?, "#{exp}: echo hlavicky ide aj po odmietnuti")
        NxTest.assert(i_st < i_bar, "#{exp}: echo PO navrate jadra (po statuse)")
        NxTest.assert_equal(gen, sd.instance_variable_get(:@generation), "#{exp}: echo generaciu nedviha")
        NxTest.assert(pushes.empty?, "#{exp}: echo nie je plny push")
        scripts.clear
        # bez `expect` — odmietnutie branou C1, echo tiez
        sd.send(exp, { 'gen' => gen }.to_json)
        NxTest.assert(scripts.any? { |s| s.include?('Okno je zastarané') }, "#{exp}: C1 hlaska")
        NxTest.assert(scripts.last.include?('NX.setVepoBar('), "#{exp}: echo je posledne")
      end
    end
  end
end

NxTest.test('H7b T-B9: echo ide aj ked jadro vyhodi (ensure)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7B.saved
    NxH7A.with_window(m) do |scripts, _pushes|
      NxH7G.with_stubs(NxH7B::PC, do_cp_xlsx: ->(*_a, **_k) { raise ArgumentError, 'test' }) do
        NxTest.assert_raise('test') { NxH7A::SD.do_cp_xlsx({ 'gen' => 1 }.to_json) }
      end
      NxTest.assert(scripts.any? { |s| s.include?('NX.setVepoBar(') }, 'echo po vynimke')
    end
  end
end

NxTest.test('H7b T-B11: relay panela preposle `expect` (cesta VEPO cez panel aj priama)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  sd = NxH7A::SD
  sent = []
  direct = []
  alive = { v: true }
  # Panel (Inspector) sa headless nenacitava — nahradny modul s TYMI ISTYMI
  # dvoma volaniami, ktore relay pouziva (`dialog_alive?`, `js`).
  own = !Noxun::Engine.const_defined?(:Panel, false)
  if own
    fake = Module.new
    fake.define_singleton_method(:dialog_alive?) { alive[:v] }
    fake.define_singleton_method(:js) { |s| sent << s; true }
    Noxun::Engine.const_set(:Panel, fake)
  end
  begin
    panel = Noxun::Engine::Panel
    NxH7G.with_stubs(panel, dialog_alive?: ->(*_a) { alive[:v] }, js: ->(s) { sent << s; true }) do
      sd.send(:handle_export, { 'gen' => 3, 'expect' => { 'project' => 'Relay', 'merge' => false } }.to_json)
      alive[:v] = false
      NxH7G.with_stubs(sd, do_export: ->(data) { direct << data }) do
        sd.send(:handle_export, { 'gen' => 3, 'expect' => { 'project' => 'Priamo', 'merge' => true } }.to_json)
      end
    end
  ensure
    Noxun::Engine.send(:remove_const, :Panel) if own
  end
  NxTest.assert(sent.first.to_s.include?('NX.studioRelayExport({"gen":3,"expect":{"project":"Relay","merge":false}})'),
                "relay posiela CELY payload: #{sent.first}")
  NxTest.assert_equal([{ 'gen' => 3, 'expect' => { 'project' => 'Priamo', 'merge' => true } }], direct,
                      'bez panela ide payload s `expect` priamo do exportu')
end

# =============================================================================
# P3 z H7a: samooprava pri zapise NAZVU sa loguje (komentar self_repair = pravda)
# =============================================================================

NxTest.test('H7b (P3 z H7a): zly `project_names` BEZ zalohy — zapis NAZVU kontajner opravi a ZALOGUJE') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  ['{"project_names":[]}', '{"project_names":"x","merge_18_36":false}', '{"project_names":null}'].each do |bad|
    NxH7A.with_sandbox do
      NxH7A.write_raw(NxH7A.path, bad)
      NxH7A.with_log do |logs|
        NxTest.assert_equal([:ok, ''], NxH7B::S.save_project_name(NxH7A.model, 'Opravene'), bad)
        NxTest.assert_equal(1, logs.count { |l| l.include?('samooprava') }, "#{bad}: jedna veta samoopravy")
      end
      doc = JSON.parse(File.binread(NxH7A.path))
      NxTest.assert_equal({ 'c:/z/a.skp' => 'Opravene' }, doc['project_names'], bad)
    end
  end
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, { 'project_names' => { 'c:/z/b.skp' => 'B' } })
    NxH7A.with_log do |logs|
      NxH7B::S.save_project_name(NxH7A.model, 'A')
      NxTest.refute(logs.any? { |l| l.include?('samooprava') }, 'platna mapa = ziadna samooprava')
    end
  end
end
