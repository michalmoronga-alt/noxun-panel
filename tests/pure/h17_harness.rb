# frozen_string_literal: true
# H17 / R0.1 — HARNESS golden T0 spolocnej pripravy exportov (nie sada — nacitava
# ho `test_h17_golden.rb` a generator `tests/fixtures/h17_golden/generate.rb`).
#
# Spusti JEDEN export (`ProductionCore.do_*`) nad fixturou zakazky a zaznamena
# vsetko, co z neho vidi pouzivatel aj disk: vetu a farbu statusu, `repush`,
# volania pickera (druh, startovaci priecinok, navrhnute meno), vznikle subory
# (cely text CSV a LOG; XLSX SHA-256 + velkost), ulozeny posledny priecinok
# a PORADIE KROKOV (G4).
#
# Zasady (package H17 §6 R0.1, §15 A4):
#   * CERSTVY sandbox `Materials.test_dir_override` pre KAZDY pripad, `DocKey.key`
#     deterministicky (vzor `NxH7G`), nastavenia exportu SKUTOCNE (nazov cez
#     `save_project_name`, `expect` cez `NxTest.export_expect` — ako okno).
#   * `Time.now` zamrazeny LEN okolo volania exportu a KAZDE volanie vrati NOVY
#     objekt (`FIXED.dup`, pasmo pripnute) — `Time.now.utc` v rozpocte by inak
#     prepol zdielany objekt do UTC (sonda A4: 14:05 +0200 -> 12:05 +0000).
#   * Stubuju sa LEN datove zdroje: `fresh_collect`, `sheets_map`, `edges_map`,
#     `hardware_catalog_items`, `vepo_*`, `hardware_expansion` (pri skutocnej
#     expanzii ani ten). Brany, `ExportSettings`, `export_expect_check`, rozpocet,
#     kontrola, `Bom.compute`, `CpExport` a zapisovace bezia SKUTOCNE; kazdy stub
#     pocita pouzitie (S21 — nenacitany modul nesmie prejst naprazdno).
#   * Poruchy (`faults`) a prepis `Budget.cp_preview` su VSTUP pripadu (vynimka
#     v kroku, zaporna zostava), nie nahrada testovaneho kodu.
#   * PORADIE KROKOV sa zapisuje pri NAVRATE volania (poradie DOKONCENYCH krokov).
#     Argumenty volania sa vyhodnotia skor, nez volanie zacne — `budget_payload`
#     preto stoji za citaniami, ktore mu dodali vstup (aj za `sheets_map`, ktore
#     si dnes rozpocet XLSX zavola sam vnutri). Vynimka v kroku = `!` za menom.
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'digest'
require 'fileutils'
require 'tmpdir'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
end
require_relative '../fixtures/h17_golden/fixture'

module NxH17
  E     = Noxun::Engine
  PC    = E::ProductionCore
  ES    = E::ExportSettings
  STORE = E::JsonFileStore
  MAT   = E::Materials
  FX    = NxH17Fixture
  DIR   = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h17_golden')
  FIXED = Time.new(2026, 10, 1, 14, 5, 0, '+02:00')
  STAMP = '2026-10-01 14:05'

  # Inventar exportov pred H17a (zrkadlo `ExportPrep::KINDS`). Po H17a plati
  # `ExportPrep::KINDS` — matica G2 sa iteruje nad NIM (§15 A5).
  LEGACY_KINDS = { vepo: 'do_export', hw_csv: 'do_hw_csv', budget: 'do_budget_xlsx', offer: 'do_cp_xlsx' }.freeze

  SAVED_PATH = 'C:/Zakazky/Kuchyna_Novak.skp'
  NAME = 'Kuchyňa Novák'

  # Model so slovnikom atributov (rozpocet cita BudgetStore z modelu).
  class Model < NxTest::FakeEntity
    attr_accessor :guid, :boom

    def initialize(path, guid)
      super()
      @path = path
      @guid = guid
      @boom = false
    end

    def path
      raise 'H17 porucha: model.path' if @boom

      @path
    end

    attr_writer :path

    def title
      File.basename(@path.to_s, '.*')
    end
  end

  # Datove zdroje ProductionCore (stub — fixtura). `hardware_expansion` zvlast.
  DATA_STUBS = %i[fresh_collect sheets_map edges_map hardware_catalog_items vepo_materials
                  vepo_edge_thicknesses vepo_edge_decors vepo_sheet_decors].freeze

  # Kroky, ktorych PORADIE sa zapisuje (G4). [modul, metoda].
  ORDER_SPIES = [
    [:ES, :refresh], [:PC, :export_expect_check], [:PC, :fresh_collect], [:PC, :newer_config_stop],
    [:PC, :cut_stop], [:PC, :hardware_expansion], [:Bom, :compute], [:PC, :sheets_map], [:PC, :budget_payload],
    [:PC, :control_payload], [:PC, :budget_std_block], [:CpExport, :specification], [:PC, :drawer_stop],
    [:PC, :dup_partition], [:PC, :export_confirmations], [:ES, :last_dir], [:VepoExport, :build],
    [:VepoExport, :write], [:HardwareSets, :purchase_csv], [:XlsxWriter, :write], [:XlsxWriter, :write_book],
    [:CpExport, :firewall_hits], [:ES, :save_last_dir], [:PC, :pending_name_note], [:PC, :default_name_note]
  ].freeze

  # Poruchy a prepisy sa daju vlozit len sem (vstup pripadu).
  FAULTABLE = [[:SheetEstimate, :estimate], [:Budget, :payload_for], [:Budget, :cp_preview]].freeze

  module_function

  def mod(sym)
    { ES: ES, PC: PC, Bom: E::Bom, CpExport: E::CpExport, VepoExport: E::VepoExport,
      HardwareSets: E::HardwareSets, XlsxWriter: E::XlsxWriter, SheetEstimate: E::SheetEstimate,
      Budget: E::Budget }.fetch(sym)
  end

  def kinds
    E.const_defined?(:ExportPrep, false) ? E::ExportPrep::KINDS : LEGACY_KINDS
  end

  # --- sandbox a prostredie ---------------------------------------------------

  def reset_modules!
    STORE.invalidate
    E::HardwareSets.reset_library_state! if E::HardwareSets.respond_to?(:reset_library_state!)
    E::HardwareCatalog.reset_state! if E::HardwareCatalog.respond_to?(:reset_state!)
    E::HardwareTaxonomy.reset_state! if E::HardwareTaxonomy.respond_to?(:reset_state!)
  end

  def with_sandbox
    prev = MAT.test_dir_override
    dir = Dir.mktmpdir('nx-h17-')
    MAT.test_dir_override = dir
    reset_modules!
    with_doc_key { yield dir }
  ensure
    MAT.test_dir_override = prev
    reset_modules!
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  def with_doc_key
    sc = E::DocKey.singleton_class
    sc.send(:alias_method, :h17_orig_key, :key)
    sc.send(:define_method, :key) { |model| model.respond_to?(:guid) ? "nxdoc-#{model.guid}" : '' }
    yield
  ensure
    sc.send(:remove_method, :key)
    sc.send(:alias_method, :key, :h17_orig_key)
    sc.send(:remove_method, :h17_orig_key)
  end

  # §15 A4: NOVY objekt pri kazdom volani (pasmo pripnute v FIXED).
  def with_now
    sc = Time.singleton_class
    sc.send(:alias_method, :h17_orig_now, :now)
    fixed = FIXED
    sc.send(:define_method, :now) { fixed.dup }
    yield
  ensure
    sc.send(:remove_method, :now)
    sc.send(:alias_method, :now, :h17_orig_now)
    sc.send(:remove_method, :h17_orig_now)
  end

  # Fake `UI`: zaznam druhu, startovacieho priecinka a navrhnuteho mena; `mode`
  # :ok (vrati cestu), :nil a :empty (zrusene vyberom).
  def with_ui(out, mode, rec)
    ui = Module.new
    ui.define_singleton_method(:savepanel) do |_title, start, name|
      rec.ui('savepanel', start, name)
      next nil if mode == :nil
      next '' if mode == :empty

      File.join(out, name.to_s)
    end
    ui.define_singleton_method(:select_directory) do |**kw|
      rec.ui('select_directory', kw[:directory], nil)
      next nil if mode == :nil
      next '' if mode == :empty

      out
    end
    Object.const_set(:UI, ui)
    yield
  ensure
    Object.send(:remove_const, :UI) if Object.const_defined?(:UI, false)
  end

  # Zaznamnik jedneho behu.
  class Recorder
    attr_reader :log, :counts, :pickers, :statuses, :repushes, :expansions

    def initialize
      @log = []
      @counts = Hash.new(0)
      @pickers = []
      @statuses = []
      @repushes = 0
      @expansions = 0
    end

    def step(label)
      @log << label
    end

    def count(name)
      @counts[name.to_s] += 1
    end

    def ui(kind, start, name)
      @pickers << { 'picker' => kind, 'start' => start, 'name' => name }
      step("UI.#{kind}")
    end

    def status(msg, err)
      @statuses << [msg, err == true]
      step('status')
    end

    def repush
      @repushes += 1
      step('repush')
    end

    def expansion!
      @expansions += 1
    end
  end

  def label(mod_sym, name, args, kw)
    base = "#{mod_sym}.#{name}"
    case [mod_sym, name]
    when [:PC, :drawer_stop] then "#{base}(#{(kw[:scope] || :all).inspect})"
    when [:PC, :export_expect_check] then "#{base}(merge: #{kw[:merge] == true})"
    else base
    end
  end

  # Docasne nahradi singleton metodu: zapis poradia/poctu, porucha, stub alebo
  # povodne telo. `saved` = [[modul, meno, povodna Method], ...] na obnovu.
  def patch!(saved, mod_sym, name, rec, order: false, impl: nil, fault: nil, post: nil)
    m = mod(mod_sym)
    orig = m.method(name)
    me = self
    m.define_singleton_method(name) do |*a, **kw, &b|
      lbl = me.label(mod_sym, name, a, kw)
      begin
        raise fault if fault

        res = impl ? impl.call(*a, **kw) : orig.call(*a, **kw, &b)
      rescue StandardError
        rec.step("#{lbl}!") if order
        raise
      end
      res = post.call(res) if post
      rec.step(lbl) if order
      res
    end
    saved << [m, name, orig]
  end

  def restore!(saved)
    saved.reverse_each { |m, name, orig| m.define_singleton_method(name, orig) }
  end

  # --- vstup pripadu ------------------------------------------------------------

  # Spec (Hash):
  #   kind:    kluc z `kinds`
  #   model:   :saved (zadany nazov) | :saved_noname | :unsaved | :long_name
  #   merge:   ulozene 18 + 36 (default true)
  #   expect:  :window (default) | :auto_then_saved | :none | Hash (presny tvar) | ->(window) { … }
  #   data:    navyse do `data` (gen, flush_blocked)
  #   confirm: :auto (default — spravny pocet riadkov bez ceny) | :none | Integer
  #   col:     ->(collected) { … } uprava zberu
  #   exp:     :fixture (default) | :real | :none (nil) | :empty | [hodnoty v poradi volani]
  #   faults:  { 'PC.fresh_collect' => 'veta', 'Bom.compute' => …, 'PC.control_payload' => …,
  #             'SheetEstimate.estimate' => …, 'Budget.payload_for' => … }
  #   cp:      Hash zlucovany do vysledku `Budget.cp_preview`
  #   attrs:   { kluc => hodnota } v slovniku NOXUN modelu (rozpocet)
  #   ui:      :ok | :nil | :empty
  #   last_dir: :out (default) | :none
  #   foreign: true = cudzi subor v cielovom priecinku VEPO
  def build_model(kind_model)
    case kind_model
    when :unsaved then Model.new('', 'H17-UNSAVED')
    when :saved_noname then Model.new('C:/Zakazky/Kupelna Horna.skp', 'H17-FILE')
    else Model.new(SAVED_PATH, 'H17-SAVED')
    end
  end

  def prepare_model(spec)
    model = build_model(spec.fetch(:model, :saved))
    case spec.fetch(:model, :saved)
    when :saved then ES.save_project_name(model, NAME)
    when :long_name
      # H7b review #457: rucny zaznam nad 120 znakov — exporty ho pomenuju
      # NORMALIZOVANE (orez 120), nie surovou hodnotou.
      STORE.write(ES.path, { 'project_names' => { SAVED_PATH.downcase => "#{'D' * 125}  " },
                             'merge_18_36' => true })
      STORE.invalidate
    end
    ES.save_merge_18_36(false) if spec.fetch(:merge, true) == false
    (spec[:attrs] || {}).each { |k, v| model.set_attribute('NOXUN', k, v) }
    model
  end

  def collected_for(spec)
    col = FX.collected
    col = col.merge(hardware: FX.real_hardware) if spec[:exp] == :real
    spec[:col] ? spec[:col].call(col) : col
  end

  def expansion_impl(spec, rec)
    exp = spec.fetch(:exp, :fixture)
    return nil if exp == :real

    seq = case exp
          when :fixture then [FX.expansion]
          when :none then [nil]
          when :empty then [{ 'rows' => [], 'unmapped' => [], 'summary' => {}, 'state_status' => 'ok' }]
          when Array then exp
          else [exp]
          end
    i = -1
    lambda do |*_a|
      rec.expansion!
      i += 1
      v = seq[[i, seq.length - 1].min]
      v.nil? ? nil : Marshal.load(Marshal.dump(v))
    end
  end

  # Datove stuby (pocitaju pouzitie). Expanzia: stub so sekvenciou alebo skutocna.
  def data_impls(spec, col, rec)
    vals = { fresh_collect: col, sheets_map: FX::SHEETS, edges_map: FX::EDGES,
             hardware_catalog_items: nil, vepo_materials: FX::VEPO_MATERIALS,
             vepo_edge_thicknesses: FX::VEPO_EDGE_THICKNESSES, vepo_edge_decors: FX::VEPO_EDGE_DECORS,
             vepo_sheet_decors: FX::VEPO_SHEET_DECORS }
    out = {}
    DATA_STUBS.each do |name|
      next if spec[:exp] == :real && name == :hardware_catalog_items

      v = vals[name]
      out[name] = lambda do |*_a|
        rec.count(name)
        v.nil? ? nil : Marshal.load(Marshal.dump(v))
      end
    end
    out
  end

  # Pocet riadkov bez ceny v rozpocte, ktory by export videl (vstup potvrdenia —
  # okno ho posle z toho isteho rozpoctu). Pocita sa NEZAZNAMENANE.
  def unpriced_for(spec, model)
    rec = Recorder.new
    saved = []
    col = collected_for(spec)
    data_impls(spec, col, rec).each { |name, impl| patch!(saved, :PC, name, rec, impl: impl) }
    ei = expansion_impl(spec, rec)
    patch!(saved, :PC, :hardware_expansion, rec, impl: ei) if ei
    begin
      with_now do
        c = PC.fresh_collect(model)
        bud = PC.budget_payload(model, E::Bom.compute(c), c, nil, PC.hardware_expansion(model, c), PC.sheets_map)
        PC.unpriced_count(bud)
      end
    ensure
      restore!(saved)
    end
  rescue StandardError
    0
  end

  def window_expect(spec, model)
    ex = spec.fetch(:expect, :window)
    case ex
    when :none then nil
    when :window then NxTest.export_expect(model)
    when Proc then ex.call(NxTest.export_expect(model))
    else ex
    end
  end

  # --- jeden beh ------------------------------------------------------------------

  def run(spec)
    kind = spec.fetch(:kind)
    method = kinds.fetch(kind)
    with_sandbox do |sandbox|
      model = prepare_model(spec)
      Dir.mktmpdir('nx-h17-out-') do |out|
        ES.save_last_dir(out) if spec.fetch(:last_dir, :out) == :out
        if spec[:foreign]
          slug = E::VepoExport.project_slug(ES.normalize_project_name(model, ES.project_name(model)))
          FileUtils.mkdir_p(File.join(out, slug))
          File.binwrite(File.join(out, slug, 'dodavatel.txt'), 'cudzi subor')
        end
        data = { 'gen' => 1 }
        exp = window_expect(spec, model)
        data['expect'] = exp unless exp.nil?
        confirm = spec.fetch(:confirm, :auto)
        confirm = unpriced_for(spec, model) if confirm == :auto
        data['confirm_unpriced'] = confirm if confirm.is_a?(Integer)
        data.merge!(spec[:data] || {})
        spec[:before]&.call(model)
        STORE.invalidate
        rec = Recorder.new
        last_before = ES.last_dir
        result = execute(spec, method, model, data, out, rec)
        STORE.invalidate
        result.merge(snapshot(out, sandbox, rec, last_before))
      end
    end
  end

  def execute(spec, method, model, data, out, rec)
    saved = []
    col = collected_for(spec)
    faults = spec[:faults] || {}
    begin
      data_impls(spec, col, rec).each { |name, impl| patch!(saved, :PC, name, rec, impl: impl) }
      ei = expansion_impl(spec, rec)
      if ei
        patch!(saved, :PC, :hardware_expansion, rec, impl: ei)
      else
        patch!(saved, :PC, :hardware_expansion, rec, post: ->(r) { rec.expansion!; r })
      end
      ORDER_SPIES.each do |mod_sym, name|
        f = faults["#{mod_sym}.#{name}"]
        patch!(saved, mod_sym, name, rec, order: true, fault: f && RuntimeError.new(f))
      end
      FAULTABLE.each do |mod_sym, name|
        f = faults["#{mod_sym}.#{name}"]
        post = spec[:cp] && name == :cp_preview ? ->(r) { r.is_a?(Hash) ? r.merge(spec[:cp]) : r } : nil
        next unless f || post

        patch!(saved, mod_sym, name, rec, fault: f && RuntimeError.new(f), post: post)
      end
      model.boom = true if spec[:boom]
      with_ui(out, spec.fetch(:ui, :ok), rec) do
        with_now do
          PC.send(method, model, data, generation: 1,
                                       status: ->(m, e = false) { rec.status(m, e) },
                                       repush: -> { rec.repush })
        end
      end
    ensure
      model.boom = false
      restore!(saved)
    end
    { 'export' => method.to_s }
  end

  # --- vystup behu -------------------------------------------------------------

  def norm(value, out, sandbox)
    return value unless value.is_a?(String)

    value.gsub(out, '«DIR»').gsub(sandbox, '«SANDBOX»')
  end

  def version_norm(text)
    v = E::VERSION.to_s
    hits = v.empty? ? 0 : text.scan(v).length
    [v.empty? ? text : text.gsub(v, '«VERSION»'), hits]
  end

  def files_of(out)
    Dir.glob(File.join(out, '**', '*'), File::FNM_DOTMATCH).sort.each_with_object([]) do |path, acc|
      next unless File.file?(path)

      rel = path.sub("#{out}/", '')
      bytes = File.binread(path)
      if File.extname(path).downcase == '.xlsx'
        acc << { 'file' => rel, 'sha256' => Digest::SHA256.hexdigest(bytes), 'size' => bytes.bytesize }
      else
        text, hits = version_norm(bytes.force_encoding('UTF-8'))
        acc << { 'file' => rel, 'text' => text, 'version_hits' => hits }
      end
    end
  end

  def snapshot(out, sandbox, rec, last_before)
    msg, err = rec.statuses.last
    { 'status' => norm(msg, out, sandbox), 'error' => err == true, 'statuses' => rec.statuses.length,
      'repush' => rec.repushes,
      'pickers' => rec.pickers.map { |p| p.transform_values { |v| norm(v, out, sandbox) } },
      'files' => files_of(out),
      'last_dir_before' => norm(last_before, out, sandbox),
      'last_dir' => norm(ES.last_dir, out, sandbox),
      'order' => rec.log, 'counts' => rec.counts.sort.to_h, 'expansions' => rec.expansions }
  end

  def json(obj)
    JSON.parse(JSON.generate(obj))
  end

  def golden(name)
    JSON.parse(File.read(File.join(DIR, "#{name}.json"), encoding: 'UTF-8'))
  end

  # --- katalog pripadov (R0.3) ----------------------------------------------------

  def with_hw(col, items)
    col.merge(hardware: Array(col[:hardware]) + items)
  end

  def with_issue(col, code, owner = 'CAB-001')
    col.merge(hardware_issues: Array(col[:hardware_issues]) + [{ 'code' => code, 'owner_id' => owner }])
  end

  def with_unmapped(reason, owner = 'CAB-001')
    exp = FX.expansion
    exp['unmapped'] += [{ 'cabinet_id' => owner, 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'lift',
                          'rule_id' => 'vyklop', 'quantity' => 1, 'set_id' => 'vyklop-hk-klasik',
                          'reason' => reason, 'reason_sk' => reason, 'nominal_length' => nil,
                          'params_label' => nil }]
    [exp]
  end

  def dup_ids(col, kind, id)
    col.merge(identities: Array(col[:identities]) + [{ 'kind' => kind, 'id' => id }])
  end

  RECIPE_ITEM = { 'generic_type' => 'slide', 'source' => 'recipe', 'owner_id' => 'CAB-001',
                  'owner_part_key' => 'front:F2/drawer', 'rule_id' => 'recept', 'quantity' => 1 }.freeze
  LIFT_ITEM = { 'generic_type' => 'lift', 'source' => 'rule', 'owner_id' => 'CAB-002',
                'owner_part_key' => 'front:F1/panel', 'rule_id' => 'vyklop', 'quantity' => 1 }.freeze

  # G1 — subory a vety v sastnej ceste (bajty).
  def g1_cases
    {
      'vepo_zadany_18_36' => { kind: :vepo },
      'vepo_zadany_bez_18_36' => { kind: :vepo, merge: false },
      'vepo_projekt_18_36' => { kind: :vepo, model: :unsaved, last_dir: :none },
      'vepo_projekt_bez_18_36' => { kind: :vepo, model: :unsaved, merge: false, last_dir: :none },
      'csv_zadany' => { kind: :hw_csv },
      'csv_projekt' => { kind: :hw_csv, model: :unsaved, last_dir: :none },
      'rozpocet_zadany' => { kind: :budget },
      'rozpocet_projekt' => { kind: :budget, model: :unsaved, last_dir: :none },
      'ponuka_zadany' => { kind: :offer },
      'ponuka_projekt' => { kind: :offer, model: :unsaved, last_dir: :none },
      # okno ukazovalo „projekt", model sa medzitym ulozil -> prejde s `gate[:note]`
      'vepo_auto_auto' => { kind: :vepo, model: :unsaved, before: ->(m) { m.path = SAVED_PATH } },
      'csv_auto_auto' => { kind: :hw_csv, model: :unsaved, before: ->(m) { m.path = SAVED_PATH } },
      'rozpocet_auto_auto' => { kind: :budget, model: :unsaved, before: ->(m) { m.path = SAVED_PATH } },
      'ponuka_auto_auto' => { kind: :offer, model: :unsaved, before: ->(m) { m.path = SAVED_PATH } },
      # ulozeny model bez zadaneho nazvu (podla suboru)
      'csv_podla_suboru' => { kind: :hw_csv, model: :saved_noname },
      # rucny zaznam nad 120 znakov — mena z NORMALIZOVANEHO nazvu (VEPO by
      # v docasnom priecinku prekrocil limit cesty Windows — vzor H7b)
      'csv_nazov_nad_120' => { kind: :hw_csv, model: :long_name },
      'rozpocet_nazov_nad_120' => { kind: :budget, model: :long_name },
      'ponuka_nazov_nad_120' => { kind: :offer, model: :long_name },
      # skutocna expanzia nad seedom kovania (stavba dvojkridlovych dvierok)
      'csv_skutocna_expanzia' => { kind: :hw_csv, exp: :real },
      'rozpocet_skutocna_expanzia' => { kind: :budget, exp: :real },
      # ceny podla planu -> `repush` po zapise XLSX
      'rozpocet_ceny_podla_planu' => { kind: :budget, attrs: { 'budget_plan_prices' => true } },
      'ponuka_ceny_podla_planu' => { kind: :offer, attrs: { 'budget_plan_prices' => true } }
    }
  end

  # G2 — spustace odmietnutia (kazdy × kazdy export z `kinds`). `intro: true` =
  # spolocny spustac uvodu (rovnaka veta pre KAZDY registrovany export, picker 0,
  # zapisy 0 — plati aj pre export, ktory golden este nepozna; §15 A5);
  # `intro: :rescue` = to iste bez porovnania vety (vynimka -> veta `rescue`).
  def g2_triggers
    t = {
      'generacia' => { intro: true, data: { 'gen' => 0 } },
      'flush' => { intro: true, data: { 'flush_blocked' => true } },
      'expect_chyba' => { intro: true, expect: :none },
      'expect_prazdny' => { intro: true, expect: {} },
      'expect_merge_nie_bool' => { intro: true, expect: ->(w) { w.merge('merge' => 'ano') } },
      'expect_neznamy_zdroj' => { intro: true, expect: ->(w) { w.merge('source' => 'okno') } },
      'expect_iny_nazov' => { intro: true, expect: ->(w) { w.merge('project' => 'Iná zákazka') } },
      'expect_zadany_vs_auto' => { intro: true,
                                   expect: ->(w) { w.merge('project' => 'Kuchyna_Novak', 'source' => 'file') } },
      'expect_ine_18_36' => { expect: ->(w) { w.merge('merge' => !w['merge']) } },
      'expect_vynimka' => { intro: true, boom: true },
      'novsia_skrinka' => { intro: true,
                            col: ->(c) { c.merge(newer_configs: [{ 'kind' => 'cabinet', 'id' => 'CAB-009' }]) } },
      'novsia_doska' => { intro: true, col: ->(c) { c.merge(newer_configs: [{ 'kind' => 'board', 'id' => 'BRD-007' }]) } },
      # veta je `rescue` exportu (styri rozne) — spolocne je len „nic sa neotvorilo"
      'vynimka_zber' => { intro: :rescue, faults: { 'PC.fresh_collect' => 'H17 porucha zberu' } },
      'expanzia_nil_recept' => { exp: :none, col: ->(c) { with_hw(c, [RECIPE_ITEM]) } },
      'expanzia_nil_vyklop' => { exp: :none, col: ->(c) { with_hw(c, [LIFT_ITEM]) } },
      'expanzia_nil' => { exp: :none },
      'expanzia_prazdna' => { exp: :empty },
      'expanzia_nil_nil' => { exp: [nil, nil] },
      'expanzia_nil_platna' => { exp: [nil, FX.expansion] },
      'kit_chyba' => { col: ->(c) { with_issue(c, E::Recipes::KIT_MISSING) } },
      'konflikt_stavby' => { col: ->(c) { with_issue(c, E::Recipes::BUILD_BLOCKERS.first) } },
      'vyklop_neuplny' => { exp: with_unmapped(E::HardwareSets::LIFT_SET_INCOMPLETE) },
      'zaves_nesedi' => { exp: with_unmapped(E::HardwareSets::HINGE_SET_MISMATCH) },
      'duplicita_blokujuca' => { col: ->(c) { dup_ids(c, 'cabinet', 'CAB-001') } },
      'duplicita_neskodna' => { col: ->(c) { dup_ids(c, 'cabinet', 'CAB-002') } },
      'duplicita_dosky' => { col: ->(c) { dup_ids(c, 'board', 'BRD-001') } },
      'rozpocet_nil' => { faults: { 'Budget.payload_for' => 'H17 porucha rozpoctu' } },
      'budget_std' => { attrs: { 'budget_std' => 99 } },
      'zostava_zaporna' => { cp: { 'assembly_negative' => true, 'assembly' => -12.5 } },
      'ponuka_nesedi' => { cp: { 'consistent' => false, 'diff' => 3.4 } },
      'bez_ceny_bez_potvrdenia' => { confirm: :none },
      'bez_ceny_zly_pocet' => { confirm: 99 },
      'bez_ceny_spravny_pocet' => {},
      'picker_nil' => { ui: :nil },
      'picker_prazdny' => { ui: :empty },
      'vepo_bez_dielcov' => { col: ->(c) { c.merge(records: []) } },
      'vynimka_bom' => { faults: { 'Bom.compute' => 'H17 porucha kusovnika' } },
      'vynimka_kontrola' => { faults: { 'PC.control_payload' => 'H17 porucha kontroly' } },
      'vynimka_odhad' => { faults: { 'SheetEstimate.estimate' => 'H17 porucha odhadu' } },
      'cudzi_subor_vepo' => { foreign: true }
    }
    E::Bom::CUT_BLOCKERS.each do |code|
      t["chrbat_#{code}"] = { intro: true, col: ->(c) { c.merge(cut_issues: [{ 'code' => code, 'owner_id' => 'CAB-002' }]) } }
    end
    t
  end

  # G3 — subeh dvoch spustacov (kazdy × kazdy export).
  def g3_combos
    tr = g2_triggers
    pairs = [%w[generacia flush], %w[flush expect_chyba], %w[expect_chyba novsia_skrinka],
             %W[novsia_skrinka chrbat_#{E::Bom::CUT_BLOCKERS.first}], %W[chrbat_#{E::Bom::CUT_BLOCKERS.first} kit_chyba],
             %w[budget_std konflikt_stavby], %w[rozpocet_nil konflikt_stavby], %w[expanzia_nil konflikt_stavby],
             %w[konflikt_stavby duplicita_blokujuca], %w[duplicita_blokujuca bez_ceny_bez_potvrdenia],
             %w[duplicita_blokujuca zostava_zaporna]]
    pairs.to_h { |a, b| ["#{a}+#{b}", merge_specs(tr.fetch(a), tr.fetch(b))] }
  end

  def merge_specs(a, b)
    out = a.merge(b)
    out[:data] = (a[:data] || {}).merge(b[:data] || {}) if a[:data] || b[:data]
    out[:faults] = (a[:faults] || {}).merge(b[:faults] || {}) if a[:faults] || b[:faults]
    out[:attrs] = (a[:attrs] || {}).merge(b[:attrs] || {}) if a[:attrs] || b[:attrs]
    out[:col] = ->(c) { b[:col].call(a[:col].call(c)) } if a[:col] && b[:col]
    out
  end

  # Kompaktny tvar odmietnutia (G2/G3): subory len menom a odtlackom obsahu
  # (plne texty drzi G1).
  def compact(res)
    files = res['files'].map do |f|
      [f['file'], f['sha256'] || Digest::SHA256.hexdigest(f['text'].to_s)]
    end
    res.reject { |k, _| k == 'files' }.merge('files' => files)
  end

  def g1_snapshot
    g1_cases.transform_values { |spec| json(run(spec)) }
  end

  def g2_run(trigger, kind)
    json(compact(run(g2_triggers.fetch(trigger).merge(kind: kind))))
  end

  def g2_snapshot
    g2_triggers.keys.to_h { |t| [t, kinds.keys.to_h { |k| [k.to_s, g2_run(t, k)] }] }
  end

  def g3_snapshot
    g3_combos.to_h { |name, spec| [name, kinds.keys.to_h { |k| [k.to_s, json(compact(run(spec.merge(kind: k))))] }] }
  end

  # --- G5 parita Kontroly: `counts` pushu Studia nad TOU ISTOU fixturou -------
  # (vzor harnessu H14 T0b — skutocny `StudioDialog.push_state`, stuby len
  # datovych zdrojov a payloadov inych sekcii).
  def push_counts(spec = {})
    if NxTest.headless? && !E.const_defined?(:StudioDialog, false)
      require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog')
    end
    sd = E::StudioDialog
    sent = nil
    with_sandbox do |_sandbox|
      model = prepare_model(spec)
      rec = Recorder.new
      saved = []
      col = collected_for(spec)
      own = []
      sk = Module.new
      sk.define_singleton_method(:active_model) { model }
      Object.const_set(:Sketchup, sk)
      begin
        data_impls(spec, col, rec).each { |name, impl| patch!(saved, :PC, name, rec, impl: impl) }
        ei = expansion_impl(spec, rec)
        patch!(saved, :PC, :hardware_expansion, rec, impl: ei) if ei
        stubs = { js: ->(s) { sent = s; true } }
        %i[mat_payload hw_payload appl_payload rules_payload tpl_payload settings_payload].each do |n|
          stubs[n] = ->(*_a) { nil }
        end
        targets = [[sd, stubs]]
        %i[EdgeCheck GrainCheck DirectionCheck].each do |c|
          targets << [E.const_get(c), { ui_state: ->(*_a) { nil } }] if E.const_defined?(c, false)
        end
        targets.each do |m, map|
          map.each do |n, fn|
            own << [m, n, m.method(n)]
            m.define_singleton_method(n, &fn)
          end
        end
        with_now { sd.send(:push_state) }
      ensure
        own.reverse_each { |m, n, orig| m.define_singleton_method(n, orig) }
        restore!(saved)
        Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup, false)
      end
    end
    JSON.parse(sent.to_s[/\ANX\.setStudio\((.*)\)\z/m, 1].to_s)['counts']
  end

  # Pocty KONTROLY z VEPO LOGu („KONTROLA — N kritických (RED), M na kontrolu (ORANGE)").
  def log_counts(result)
    log = Array(result['files']).find { |f| f['file'].to_s.end_with?('_export.log') }
    m = log && log['text'].to_s.match(/KONTROLA — (\d+) kritických \(RED\), (\d+) na kontrolu \(ORANGE\)/)
    m ? { 'red' => m[1].to_i, 'orange' => m[2].to_i } : nil
  end

  # --- G6 parita Narezoveho planu: dovody `layout_block_reasons` nad TYM ISTYM
  # zberom a expanziou, akymi export zastavi VEPO.
  def layout_reasons(spec)
    with_sandbox do |_sandbox|
      model = prepare_model(spec)
      rec = Recorder.new
      saved = []
      col = collected_for(spec)
      data_impls(spec, col, rec).each { |name, impl| patch!(saved, :PC, name, rec, impl: impl) }
      ei = expansion_impl(spec, rec)
      patch!(saved, :PC, :hardware_expansion, rec, impl: ei) if ei
      begin
        c = PC.fresh_collect(model)
        PC.layout_block_reasons(c, PC.hardware_expansion(model, c))
      ensure
        restore!(saved)
      end
    end
  end
end
