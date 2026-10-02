# frozen_string_literal: true
# H7a / R-38 — CHARAKTERIZACIA PRED ZASAHOM (T0a–T0c, package H7 §6 R0).
#
# PRECO: H7a presuva nastavenia exportu (`vepo_settings.json` — nazov zakazky,
# 18 + 36, posledny priecinok) z `ui/production_core.rb` do jadra
# (`core/export_settings.rb`) a dava im ochranu R-38. Zavazok davky: pri
# ZDRAVOM subore sa mena vystupov, bajty suboru nastaveni ani pomenovanie
# styroch exportov NEMENIA. Tieto odtlacky to dokazuju:
#   T0a names.json    — mena a nadpisy pre 11 nazvov (VEPO priecinok a jeho
#                       subory, hlavicka LOGu, CSV kovania presne vyrazom
#                       z `do_hw_csv`, 1. riadok nakupneho CSV, XLSX rozpoctu
#                       a ponuky + ich nadpisy harkov),
#   T0b bytes.json    — bajty primaru AJ `.bak` po kazdom kroku zapisu cez
#                       verejne API (nazov ulozeneho aj neulozeneho modelu,
#                       prenos pri prvom ulozeni, 18 + 36, posledny priecinok,
#                       zmazanie, 130 znakov, zapis druhej instancie),
#   T0c exports.json  — styri exporty end-to-end (`do_export`, `do_hw_csv`,
#                       `do_budget_xlsx`, `do_cp_xlsx`) BEZ stubu nazvu
#                       a nastaveni: navrhnute meno, priecinok VEPO a jeho
#                       subory, ulozeny posledny priecinok.
# T0d (payload `vepo` v pushi Studia) drzi `test_h14_studio_sekcie.rb`.
#
# Odtlacok vznikol na MAINE pred zasahom H7a (`18f45933`, v0.17.19). Fixtura
# sa NEREGENERUJE — rozdiel je NALEZ, nie sum. Generator (rucne, test ho
# NEVOLA): C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h7_golden/generate.rb
#
# Kluc sedenia neulozeneho modelu (`guid:<DocKey token>`) je inak nahodny —
# sada podstrci DETERMINISTICKY token odvodeny z `guid` testovacieho modelu
# (vzor `test_st1a_studio.rb`); cesta kluca `guid:` cez DocKey sa tym NEOBCHADZA.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxH7G
  E      = Noxun::Engine
  PC     = E::ProductionCore
  STORE  = E::JsonFileStore
  MAT    = E::Materials
  DK_SC  = E::DocKey.singleton_class
  FIXTURES = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h7_golden')
  NOW = Time.new(2026, 10, 1, 14, 5)
  STAMP = '2026-10-01 14:05'

  NAMES = ['Kuchyňa Novák', 'projekt', 'Kuchyna_Novak', 'con', 'COM1', '', '   ',
           'a/b:c*?"<>|', 'Žltá skriňa – 2. NP', 'A' * 120, 'Ťažká "zákazka"'].freeze

  MODEL = Struct.new(:path, :guid)

  module_function

  # --- API nastaveni exportu ----------------------------------------------
  # JEDINE miesto sady, ktore pozna modul nastaveni. Presun H7a z
  # ProductionCore do ExportSettings prepojil LEN tieto riadky — odtlacky
  # a kroky sa nemenili (fixtura vznikla nad ProductionCore na maine).
  def api
    E::ExportSettings
  end

  def settings_path
    E::ExportSettings.path
  end

  def save_last_dir(dir)
    E::ExportSettings.save_last_dir(dir)
  end

  # Surova hodnota posledneho priecinka (presne ako ju vidia exporty).
  def last_dir_raw
    E::ExportSettings.last_dir
  end

  # --- sandbox ---------------------------------------------------------------

  def with_sandbox
    prev = MAT.test_dir_override
    dir = Dir.mktmpdir('nx-h7g-')
    MAT.test_dir_override = dir
    STORE.invalidate
    with_doc_key { yield dir }
  ensure
    MAT.test_dir_override = prev
    STORE.invalidate
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  # Deterministicky DocKey token (`nxdoc-<guid>`) — inak nahodny hex.
  def with_doc_key
    DK_SC.send(:alias_method, :h7g_orig_key, :key)
    DK_SC.send(:define_method, :key) do |model|
      model.respond_to?(:guid) ? "nxdoc-#{model.guid}" : ''
    end
    yield
  ensure
    DK_SC.send(:remove_method, :key)
    DK_SC.send(:alias_method, :key, :h7g_orig_key)
    DK_SC.send(:remove_method, :h7g_orig_key)
  end

  # `module_function` metody ziju na SINGLETON triede (vzor test_p0hf_brany.rb).
  def with_stubs(mod, overrides)
    sc = mod.singleton_class
    names = overrides.keys
    names.each do |name|
      sc.send(:alias_method, :"h7g_orig_#{name}", name)
      sc.send(:define_method, name, &overrides[name])
    end
    yield
  ensure
    names.each do |name|
      sc.send(:remove_method, name)
      sc.send(:alias_method, name, :"h7g_orig_#{name}")
      sc.send(:remove_method, :"h7g_orig_#{name}")
    end
  end

  def bytes(path)
    File.exist?(path) ? File.binread(path).force_encoding('UTF-8') : nil
  end

  def json(obj)
    JSON.parse(JSON.generate(obj))
  end

  def fixture(name)
    JSON.parse(File.read(File.join(FIXTURES, "#{name}.json"), encoding: 'UTF-8'))
  end

  # --- T0a mena a nadpisy -----------------------------------------------------

  VEPO_MATS = { 'M18' => { 'label' => 'K009 PW DTDL' } }.freeze

  def vepo_row
    { 'names' => ['Bok'], 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0,
      'quantity' => 1, 'material_id' => 'M18', 'grain_direction' => 'length',
      'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
      'kde' => [{ 'owner_id' => 'CAB-1', 'quantity' => 1 }] }
  end

  def min_exp
    { 'rows' => [], 'unmapped' => [], 'summary' => {} }
  end

  def names_snapshot
    NAMES.each_with_object({}) do |name, out|
      vepo = E::VepoExport
      result = vepo.build([vepo_row], project: name, materials: VEPO_MATS, edge_thicknesses: {},
                                      version: 'GOLDEN', generated_at: STAMP, merge_18_36: true)
      # Priecinok a subory na DISKU overuje T0c (kratke nazvy) — 120 znakov
      # by v docasnom priecinku prekrocilo limit cesty Windows a vysledok by
      # zavisel od stroja. Tu: slug davky (= meno priecinka v `write`) a mena CSV.
      out[name] = {
        'project_slug' => vepo.project_slug(name),
        'vepo_dir' => result['project_slug'],
        'csv_filenames' => result['groups'].map { |g| g['filename'] },
        'log_head' => result['log_text'].lines.first(2).map(&:chomp),
        # presne vyraz `do_hw_csv` (ProductionCore) — kopia, nie volanie
        'hw_csv' => "kovanie_#{vepo.project_slug(name)}.csv",
        'hw_csv_head' => E::HardwareSets.purchase_csv(min_exp, project: name, generated_at: STAMP)
                                        .lines.first.to_s.chomp,
        'budget_xlsx' => E::BudgetXlsx.file_name(name, NOW),
        'budget_title' => E::BudgetXlsx.title(name, NOW),
        'offer_xlsx' => E::CpXlsx.file_name(name, NOW),
        'offer_title' => E::CpXlsx.title(name, NOW)
      }
    end
  end

  # --- T0b bajty suboru nastaveni ----------------------------------------------

  # Zapis „druhej instancie" priamo do suboru (iny proces nase dvere nepozna).
  def other_instance(path, key, name)
    data = begin
      JSON.parse(File.binread(path))
    rescue StandardError
      {}
    end
    data = {} unless data.is_a?(Hash)
    names = data['project_names'].is_a?(Hash) ? data['project_names'].dup : {}
    names[key] = name
    STORE.write(path, data.merge('project_names' => names))
  end

  def bytes_snapshot
    steps = []
    with_sandbox do |_dir|
      path = settings_path
      m1 = MODEL.new('C:/Zakazky/Kuchyna_Novak.skp', 'T0B-1')
      m2 = MODEL.new('', 'T0B-2')
      m3 = MODEL.new('C:/Zakazky/Treti.skp', 'T0B-3')
      snap = lambda do |label|
        STORE.invalidate
        steps << { 'step' => label, 'primary' => bytes(path), 'bak' => bytes("#{path}.bak"),
                   'name_m1' => api.project_name(m1), 'name_m2' => api.project_name(m2),
                   'merge_18_36' => api.merge_18_36 }
      end
      api.save_project_name(m1, 'Kuchyňa Novák')
      snap.call('nazov ulozeneho modelu')
      api.save_project_name(m2, 'Nová zákazka 2')
      snap.call('nazov neulozeneho modelu (kluc sedenia)')
      m2.path = 'C:/Zakazky/Nova.skp'
      api.project_name(m2)
      snap.call('prve ulozenie + citanie (prenos na cestu)')
      api.save_merge_18_36(false)
      snap.call('18 + 36 vypnute')
      save_last_dir('D:/Export/VEPO')
      snap.call('posledny priecinok')
      api.save_project_name(m1, '')
      snap.call('zmazanie nazvu')
      api.save_project_name(m1, 'B' * 130)
      snap.call('130 znakov (strop 120)')
      orig = MAT.method(:with_catalog_lock)
      begin
        MAT.define_singleton_method(:with_catalog_lock) do |&blk|
          NxH7G.other_instance(path, 'c:/zakazky/druha.skp', 'Druhá inštancia')
          orig.call(&blk)
        end
        api.save_project_name(m3, 'Tretia')
      ensure
        MAT.define_singleton_method(:with_catalog_lock, orig)
      end
      snap.call('zapis druhej instancie medzi nasim citanim a zapisom')
    end
    steps
  end

  # --- T0c styri exporty end-to-end --------------------------------------------

  def collected(records)
    { records: records, hardware: [], hardware_overrides: [], cabinet_sets: {},
      cabinet_set_conflicts: {}, placements: [], warnings: [], identities: [],
      hardware_issues: [], cut_issues: [] }
  end

  def record(id, thickness)
    { 'name' => 'Bok', 'part_key' => "p#{id}", 'owner_id' => 'CAB-1', 'pid' => id,
      'role' => 'side_left', 'length' => 720.0, 'width' => 560.0, 'thickness' => thickness,
      'quantity' => 1, 'material_id' => "M#{thickness.to_i}", 'grain_direction' => 'length',
      'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  end

  def budget
    { 'totals' => { 'total' => 1234.0, 'unknown_count_in_total' => 0 },
      'cp_preview' => { 'total' => 1234.0, 'rows' => [], 'assembly' => 100.0,
                        'assembly_negative' => false, 'consistent' => true, 'diff' => 0.0 } }
  end

  # Stuby ZBERU (model, katalog, rozpocet) — nazov a nastavenia NIE.
  def collect_stubs(col)
    exp = { 'rows' => [{ 'code' => 'ZAVES', 'quantity' => 2, 'sources' => [] }], 'unmapped' => [] }
    bud = budget
    mats = { 'M18' => { 'label' => 'K009 PW DTDL' }, 'M36' => { 'label' => 'K009 PW DTDL' } }
    { fresh_collect: ->(*_a) { col },
      sheets_map: ->(*_a) { {} },
      hardware_expansion: ->(*_a) { exp },
      budget_payload: ->(*_a) { bud },
      control_payload: ->(*_a) { nil },
      vepo_materials: ->(*_a) { mats },
      vepo_edge_thicknesses: ->(*_a) { {} },
      vepo_edge_decors: ->(*_a) { {} },
      vepo_sheet_decors: ->(*_a) { {} } }
  end

  # Fake `UI` — zaznamena NAVRHNUTE meno a startovaci priecinok pickera.
  def with_ui(dir, seen)
    ui = Module.new
    ui.define_singleton_method(:savepanel) do |_title, start, name|
      seen << { 'picker' => 'savepanel', 'start' => start, 'name' => name }
      File.join(dir, name.to_s)
    end
    ui.define_singleton_method(:select_directory) do |**kw|
      seen << { 'picker' => 'select_directory', 'start' => kw[:directory], 'name' => nil }
      dir
    end
    Object.const_set(:UI, ui)
    yield
  ensure
    Object.send(:remove_const, :UI) if Object.const_defined?(:UI, false)
  end

  def with_now
    sc = Time.singleton_class
    sc.send(:alias_method, :h7g_orig_now, :now)
    now = NOW
    sc.send(:define_method, :now) { now }
    yield
  ensure
    sc.send(:remove_method, :now)
    sc.send(:alias_method, :now, :h7g_orig_now)
    sc.send(:remove_method, :h7g_orig_now)
  end

  def norm(value, dir)
    value.is_a?(String) ? value.gsub(dir, '<DIR>') : value
  end

  def run_export(method, model, col, dir)
    seen = []
    err = nil
    msg = nil
    with_stubs(PC, collect_stubs(col)) do
      with_ui(dir, seen) do
        with_now do
          PC.send(method, model, { 'gen' => 1 }, generation: 1,
                                                 status: ->(m, e = false) { msg = m; err = e },
                                                 repush: -> {})
        end
      end
    end
    STORE.invalidate
    { 'export' => method.to_s,
      'pickers' => seen.map { |s| s.transform_values { |v| norm(v, dir) } },
      'error' => err == true,
      'ok' => !msg.to_s.empty? && err != true,
      'last_dir' => norm(last_dir_raw, dir) }
  end

  SCENARIOS = [
    ['zadany_nazov', 'C:/Zakazky/Kuchyna_Novak.skp', 'Kuchyňa Novák', true],
    ['zadany_nazov_bez_18_36', 'C:/Zakazky/Kuchyna_Novak.skp', 'Kuchyňa Novák', false],
    ['ulozeny_bez_nazvu', 'C:/Zakazky/Kúpeľňa Horná.skp', nil, true],
    ['neulozeny', '', nil, true]
  ].freeze

  def exports_snapshot
    SCENARIOS.each_with_object({}) do |(label, path, name, merge), out|
      with_sandbox do |_sd|
        model = MODEL.new(path, "T0C-#{label}")
        api.save_project_name(model, name) if name
        api.save_merge_18_36(false) unless merge
        Dir.mktmpdir('nx-h7g-exp-') do |dir|
          vepo_col = collected([record(1, 18.0), record(2, 36.0)])
          rows = []
          rows << run_export(:do_export, model, vepo_col, dir)
          vepo_dirs = Dir.children(dir).select { |c| File.directory?(File.join(dir, c)) }.sort
          rows.last['vepo_dirs'] = vepo_dirs.map do |d|
            { 'dir' => d, 'files' => Dir.children(File.join(dir, d)).sort }
          end
          %i[do_hw_csv do_budget_xlsx do_cp_xlsx].each do |m|
            rows << run_export(m, model, collected([]), dir)
          end
          rows.last['files_in_dir'] = Dir.children(dir).reject { |c| File.directory?(File.join(dir, c)) }.sort
          out[label] = rows
        end
      end
    end
  end
end

NxTest.test('H7a T0a: mena a nadpisy exportov pre 11 nazvov bajtovo zhodne s mainom') do
  NxTest.assert_equal(NxH7G.fixture('names'), NxH7G.json(NxH7G.names_snapshot))
end

NxTest.test('H7a T0b: bajty vepo_settings.json aj .bak po kazdom kroku zhodne s mainom') do
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  want = NxH7G.fixture('bytes')
  got = NxH7G.json(NxH7G.bytes_snapshot)
  NxTest.assert_equal(want.length, got.length, 'pocet krokov')
  want.zip(got).each do |w, g|
    NxTest.assert_equal(w, g, "krok: #{w['step']}")
  end
end

NxTest.test('H7a T0c: styri exporty pomenuju subory, priecinok VEPO a posledny priecinok ako main') do
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  want = NxH7G.fixture('exports')
  got = NxH7G.json(NxH7G.exports_snapshot)
  NxTest.assert_equal(want.keys, got.keys, 'scenare')
  want.each do |label, rows|
    NxTest.assert_equal(rows, got[label], "scenar #{label}")
  end
end
