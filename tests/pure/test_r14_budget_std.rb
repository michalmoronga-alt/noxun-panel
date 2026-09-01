# frozen_string_literal: true
# 1d/R-14 — VERZIA FORMATU DAT ROZPOCTU V ZAKAZKE (`budget_std`).
#
# CO BOLO ZLE: osem NOXUN klucov rozpoctu na modeli (rezim, overridy, nasobky,
# m2 vizualizacie, vlastne polozky, spotrebice, ich zapocitanie a zaradenie
# v ponuke) nenieslo ZIADNU verziu formatu. Zakazka ulozena NOVSIM pluginom sa
# pritom cita cez uzavrete whitelisty (`build_custom`/`build_appliance`/
# `numeric_map`), takze PRVY klik v Rozpocte by neznáme polia ticho orezal
# a zapisom zvecnil — a nasledny XLSX by nesol podhodnotene cislo.
#
# CO PLATI TERAZ:
#   * `BudgetStore::BUDGET_STD` (Integer) je verzia, ktorej tato verzia rozumie,
#     a zapisuje sa na model pod klucom `budget_std` (POZOR na zamenu mien:
#     `budget_std_multipliers` su CENOVE nasobice, nie verzia),
#   * dopredny guard stoji v JEDINOM choke pointe `BudgetStore.write!` — tesne
#     PRED `start_operation`, takze odmietnuta mutacia nezalozi krok Spat;
#     marker sa zapisuje PO mutacnom bloku, ale PRED `commit_operation`
#     (udaj + marker = JEDNA operacia = jeden krok Spat),
#   * legacy = VYHRADNE NEPRITOMNY atribut. Ziadny fail-open `.to_i`:
#     '', 'abc', 1.0, -1, 0 aj vynimka pri citani su NEPLATNY marker a mutacie
#     sa odmietaju s VLASTNOU hlaskou o poskodenych datach,
#   * kompatibilitny priznak cestuje V PAYLOADE rozpoctu (`budget_std`) — cita
#     ho banner oboch sekcii okna aj brana OBOCH CENOVYCH exportov, ktora ich
#     zastavi EŠTE PRED `savepanel`. VEPO a nakupny CSV kovania branu
#     NEDOSTAVAJU (rozpoctove data nenesu), a blokuje sa NEKOMPATIBILNA VERZIA
#     DAT — nie rozpracovanost rozpoctu, ktoru STANDARD §11.3 vyslovne pripusta.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require 'tmpdir'

module NxR14
  module_function

  BS = Noxun::Engine::BudgetStore
  BD = Noxun::Engine::Budget
  PC = Noxun::Engine::ProductionCore
  SC = PC.singleton_class

  # Fake model: dict + pocitadla operacii. `path` je nutne — `DocKey.key` bez
  # neho vrati prazdny token a kazdy identity guard by zapis odmietol.
  class FakeModel < NxTest::FakeEntity
    attr_reader :ops, :committed, :aborted

    def initialize
      super
      @ops = []
      @committed = 0
      @aborted = 0
    end

    def path
      ''
    end

    def start_operation(name, _disable_ui = false)
      @ops << name
      true
    end

    def commit_operation
      @committed += 1
      true
    end

    def abort_operation
      @aborted += 1
      true
    end
  end

  # Model, ktoremu citanie atributu VYHODI vynimku (poskodeny dict / zomrety
  # dokument) — fail-open by z toho spravil legacy, teda povolenie.
  class RaisingModel < FakeModel
    def get_attribute(_dict, _key, _default = nil)
      raise 'citanie atributu zlyhalo'
    end
  end

  DICT = Noxun::Engine::Store::DICT

  def model(marker = :none)
    m = FakeModel.new
    m.set_attribute(DICT, BS::KEY_STD, marker) unless marker == :none
    m
  end

  def dict_of(m)
    Marshal.load(Marshal.dump(m.dicts[DICT]))
  rescue StandardError
    m.dicts[DICT].dup
  end

  def marker_of(m)
    m.get_attribute(DICT, BS::KEY_STD)
  end

  # VSETKYCH 12 mutacnych vstupov `BudgetStore` s PLATNYMI hodnotami — kazdy
  # z nich musi pri nekompatibilnom markeri skoncit odmietnutim.
  # -> [meno, lambda(model) -> [ok, chyby]]
  def mutations
    [
      ['set_mode!', ->(m) { BS.set_mode!(m, 'vysoky') }],
      ['set_override!', ->(m) { BS.set_override!(m, 'service:montaz', 120.0) }],
      ['clear_override!', ->(m) { BS.clear_override!(m, 'service:montaz') }],
      ['set_std_multiplier!', ->(m) { BS.set_std_multiplier!(m, 'std:doprava', 2.0) }],
      ['set_viz_m2!', ->(m) { BS.set_viz_m2!(m, 12.5) }],
      ['set_appliances_included!', ->(m) { BS.set_appliances_included!(m, true) }],
      ['set_cp_group!', ->(m) { BS.set_cp_group!(m, 'material:DTDL18', 'samostatne') }],
      ['add_custom_item!', ->(m) { BS.add_custom_item!(m, 'popis' => 'Doprava', 'cena' => 50.0) }],
      ['update_custom_item!', ->(m) { BS.update_custom_item!(m, seeded_id(m, :custom), 'cena' => 99.0) }],
      ['remove_custom_item!', ->(m) { BS.remove_custom_item!(m, seeded_id(m, :custom)) }],
      ['add_appliance!', ->(m) { BS.add_appliance!(m, 'nazov' => 'Bosch', 'typ' => 'umyvacka') }],
      ['update_appliance!', ->(m) { BS.update_appliance!(m, seeded_id(m, :appliance), 'cena' => 649.0) }],
      ['remove_appliance!', ->(m) { BS.remove_appliance!(m, seeded_id(m, :appliance)) }]
    ]
  end

  # Update/remove potrebuju EXISTUJUCU polozku — inak by skoncili na
  # „polozka sa nenasla" uz PRED guardom a scenar by nic nedokazal.
  # Polozky sa preto vkladaju priamo do dict (mimo `write!`).
  def seed_items!(m)
    m.set_attribute(DICT, BS::KEY_CUSTOM,
                    [{ 'id' => 'CUST-1', 'popis' => 'Stará položka', 'pocet' => 1,
                       'cena' => 10.0, 'cp_skupina' => 'zostava' }].to_json)
    m.set_attribute(DICT, BS::KEY_APPLIANCES,
                    [{ 'id' => 'APPL-1', 'typ' => 'rura', 'nazov' => 'Stará rúra',
                       'cena' => 100.0, 'cp_skupina' => 'zostava' }].to_json)
    m
  end

  def seeded_id(_m, kind)
    kind == :custom ? 'CUST-1' : 'APPL-1'
  end

  def ok_of(result)
    first = result.is_a?(Array) ? result[0] : result
    first == true || first.is_a?(Hash)
  end

  def errors_of(result)
    Array(result.is_a?(Array) ? result[1] : nil)
  end

  # --- payload -------------------------------------------------------------

  def state(std)
    { 'mode' => 'standard', 'overrides' => {}, 'std_multipliers' => {}, 'viz_m2' => nil,
      'custom_items' => [], 'appliances' => [], 'appliances_included' => false,
      'cp_overrides' => {}, 'std' => std }
  end

  def payload(std)
    BD.compute({ rows: [], edging: [] }, state(std), Noxun::Engine::SupplierSettings.seed_supplier)
  end

  # --- stubbing exportov (vzor test_p0hf_brany.rb) -------------------------

  def with_stubs(overrides)
    names = overrides.keys
    names.each do |name|
      SC.send(:alias_method, :"r14_orig_#{name}", name)
      SC.send(:define_method, name, &overrides[name])
    end
    yield
  ensure
    names.each do |name|
      SC.send(:remove_method, name)
      SC.send(:alias_method, name, :"r14_orig_#{name}")
      SC.send(:remove_method, :"r14_orig_#{name}")
    end
  end

  def with_ui(target, calls)
    ui = Module.new
    ui.define_singleton_method(:savepanel) do |_title, _dir, _name|
      calls << :savepanel
      target
    end
    ui.define_singleton_method(:select_directory) do |**_kw|
      calls << :select_directory
      target
    end
    Object.const_set(:UI, ui)
    yield
  ensure
    Object.send(:remove_const, :UI) if Object.const_defined?(:UI, false)
  end

  def collected
    { records: [], hardware: [], hardware_overrides: [], cabinet_sets: {},
      cabinet_set_conflicts: {}, placements: [], warnings: [], identities: [] }
  end

  # Rozpocet v tvare, aky brany citaju: cisty (ziadne blokujuce dovody P0-HF)
  # + priznak kompatibility R-14.
  def export_budget(std)
    { 'totals' => { 'total' => 1234.0, 'unknown_count_in_total' => 0 },
      'cp_preview' => { 'total' => 1234.0, 'rows' => [], 'assembly' => 100.0,
                        'assembly_negative' => false, 'consistent' => true, 'diff' => 0.0 },
      'budget_std' => BD.std_payload(std) }
  end

  def base_stubs(bud)
    col = collected
    { refresh_vepo_settings: ->(*_a) {},
      vepo_settings: ->(*_a) { {} },
      save_vepo_settings: ->(*_a) { true },
      project_name: ->(*_a) { 'Test zákazka' },
      fresh_collect: ->(*_a) { col },
      sheets_map: ->(*_a) { {} },
      hardware_expansion: ->(*_a) { { 'rows' => [], 'unmapped' => [] } },
      budget_payload: ->(*_a) { bud } }
  end

  # -> [status_sprava, chyba?, subory v priecinku, volania pickera]
  def run_export(method, std, dir, file_name)
    msg = nil
    err = nil
    calls = []
    with_stubs(base_stubs(export_budget(std))) do
      with_ui(File.join(dir, file_name), calls) do
        PC.send(method, :model, { 'gen' => 1 }, generation: 1,
                                                status: ->(m, e = false) { msg = m; err = e },
                                                repush: -> {})
      end
    end
    [msg, err, Dir.children(dir).sort, calls]
  end

  def src(file)
    File.read(File.join(NxTest::ROOT, 'noxun_engine', file), encoding: 'UTF-8')
  end
end

# ============================ KONTRAKT MARKERA ==============================

NxTest.test('R-14: BUDGET_STD je Integer >= 1 a kluc je `budget_std` (nie nasobice)') do
  NxTest.assert(NxR14::BS::BUDGET_STD.is_a?(Integer) && NxR14::BS::BUDGET_STD >= 1,
                "BUDGET_STD musi byt cele kladne cislo: #{NxR14::BS::BUDGET_STD.inspect}")
  NxTest.assert_equal('budget_std', NxR14::BS::KEY_STD)
  NxTest.refute(NxR14::BS::KEY_STD == NxR14::BS::KEY_MULTIPLIERS,
                'verzia formatu a cenove nasobice su DVE rozne veci s podobnym menom')
end

NxTest.test('R-14: std_state — legacy je VYHRADNE nepritomny atribut (ziadny fail-open)') do
  cur = NxR14::BS::BUDGET_STD
  NxTest.assert_equal(:legacy, NxR14::BS.std_state(NxR14.model), 'zakazka spred R-14')
  NxTest.assert_equal(:current, NxR14::BS.std_state(NxR14.model(cur)))
  NxTest.assert_equal(:newer, NxR14::BS.std_state(NxR14.model(cur + 1)))
  # NEPLATNE markery — kazdy z nich by fail-open `.to_i` spravil legacy (0)
  [0, -1, 1.0, '1', '', '  ', 'abc', nil, true, [1], { 'v' => 1 }].each do |bad|
    NxTest.assert_equal(:invalid, NxR14::BS.std_state(NxR14.model(bad)),
                        "neplatny marker #{bad.inspect} NESMIE prejst ako legacy")
  end
  NxTest.assert_equal(:invalid, NxR14::BS.std_state(NxR14::RaisingModel.new),
                      'vynimka pri citani nie je povolenie')
  NxTest.assert(NxR14::BS.std_compatible?(NxR14.model), 'legacy je kompatibilna')
  NxTest.assert(NxR14::BS.std_compatible?(NxR14.model(cur)))
  NxTest.refute(NxR14::BS.std_compatible?(NxR14.model(cur + 1)))
end

NxTest.test('R-14: hlasky su JEDEN zdroj a rozlisuju NOVSIU verziu od POSKODENYCH dat') do
  newer = NxR14::BS.std_block_reason(:newer)
  invalid = NxR14::BS.std_block_reason(:invalid)
  NxTest.assert(newer.include?('novšej verzie Noxun') && newer.include?('aktualizuj plugin'), newer)
  NxTest.assert(invalid.include?('poškodené') && invalid.include?('nahlás'), invalid)
  NxTest.refute(newer == invalid, 'dva rozne stavy = dve rozne hlasky')
  NxTest.assert_equal('', NxR14::BS.std_block_reason(:legacy))
  NxTest.assert_equal('', NxR14::BS.std_block_reason(:current))
  # payload posiela STRING — hlaska musi sediet aj tak (jeden zdroj textu)
  NxTest.assert_equal(newer, NxR14::BS.std_block_reason('newer'))
end

# ============================ ZAPIS MARKERA =================================

NxTest.test('R-14: LEGACY zakazka mutuje a marker si tym ZAPISE (jedna operacia)') do
  m = NxR14.model
  ok, errors = NxR14::BS.set_mode!(m, 'vysoky')
  NxTest.assert(ok, "legacy zakazka sa musi dat editovat: #{errors.inspect}")
  NxTest.assert_equal(NxR14::BS::BUDGET_STD, NxR14.marker_of(m), 'prva mutacia marker zapisala')
  NxTest.assert_equal('vysoky', NxR14::BS.mode(m), 'a udaj sa zapisal tiez')
  NxTest.assert_equal(1, m.ops.length,
                      'marker NESMIE mat vlastnu operaciu — udaj + marker = JEDEN krok Spat')
  NxTest.assert_equal(1, m.committed)
  NxTest.assert_equal(0, m.aborted)
end

NxTest.test('R-14: marker nesu VSETKY mutacie a vzdy ako AKTUALNA hodnota') do
  NxR14.mutations.each do |name, run|
    m = NxR14.seed_items!(NxR14.model)
    result = run.call(m)
    NxTest.assert(NxR14.ok_of(result), "#{name}: legacy mutacia musi prejst #{result.inspect}")
    NxTest.assert_equal(NxR14::BS::BUDGET_STD, NxR14.marker_of(m), "#{name}: marker chyba")
    NxTest.assert_equal(1, m.ops.length, "#{name}: jedna mutacia = jedna operacia")
  end
end

NxTest.test('R-14: marker prezije dalsie mutacie a nedvihne sa nad BUDGET_STD') do
  m = NxR14.model
  NxR14::BS.set_mode!(m, 'nizky')
  NxR14::BS.set_viz_m2!(m, 12.0)
  NxR14::BS.set_std_multiplier!(m, 'std:doprava', 2.0)
  NxTest.assert_equal(NxR14::BS::BUDGET_STD, NxR14.marker_of(m))
  NxTest.assert_equal(3, m.ops.length, 'tri mutacie = tri kroky Spat')
  NxTest.assert_equal(3, m.committed)
end

NxTest.test('R-14: marker sa NIKDY nepreberá z ulozeneho stavu — zapisuje sa aktualny') do
  # STARSI marker (0 by bola legacy; simulacia „medzi verziami" nie je mozna,
  # lebo BUDGET_STD je 1 — testuje sa kontrakt zdroja hodnoty).
  s = NxR14.src(File.join('core', 'budget_store.rb'))
  NxTest.assert_equal(1, s.scan(/write_attr\(model, KEY_STD, BUDGET_STD\)/).length,
                      'marker sa zapisuje z JEDINEHO miesta a VZDY ako BUDGET_STD')
  NxTest.assert_equal(1, s.scan(/^\s+stamp_std\(model\)$/).length,
                      'a `stamp_std` sa vola z JEDINEHO miesta (`write!`)')
end

# ============================ DOPREDNY GUARD ================================

NxTest.test('R-14: NOVSI marker odmietne VSETKYCH 13 mutacnych vstupov — bez zapisu a bez operacie') do
  NxR14.mutations.each do |name, run|
    m = NxR14.seed_items!(NxR14.model(NxR14::BS::BUDGET_STD + 1))
    before = NxR14.dict_of(m)
    result = run.call(m)
    NxTest.refute(NxR14.ok_of(result), "#{name}: mutacia musi byt ODMIETNUTA")
    NxTest.assert_equal([NxR14::BS.std_block_reason(:newer)], NxR14.errors_of(result),
                        "#{name}: dovod je hlaska o novsej verzii")
    NxTest.assert_equal(before, NxR14.dict_of(m), "#{name}: dict ostal NEDOTKNUTY")
    NxTest.assert_equal([], m.ops, "#{name}: odmietnutie nesmie otvorit operaciu (ziadny krok Spat)")
    NxTest.assert_equal(0, m.committed)
    NxTest.assert_equal(0, m.aborted)
  end
end

NxTest.test('R-14: POSKODENY marker odmieta rovnako, ale s vlastnou hlaskou') do
  ['abc', '', 1.5, -3].each do |bad|
    m = NxR14.model(bad)
    ok, errors = NxR14::BS.set_mode!(m, 'vysoky')
    NxTest.refute(ok, "marker #{bad.inspect}: mutacia musi byt odmietnuta")
    NxTest.assert_equal([NxR14::BS.std_block_reason(:invalid)], Array(errors))
    NxTest.assert_equal(bad, NxR14.marker_of(m), 'poskodena hodnota sa NEPREPISUJE potichu')
    NxTest.assert_equal([], m.ops)
  end
  m = NxR14::RaisingModel.new
  ok, errors = NxR14::BS.set_mode!(m, 'vysoky')
  NxTest.refute(ok, 'vynimka pri citani markera = odmietnutie, nie povolenie')
  NxTest.assert_equal([NxR14::BS.std_block_reason(:invalid)], Array(errors))
end

NxTest.test('R-14: CITANIE sa neblokuje NIKDY — novsia zakazka sa da precitat aj zobrazit') do
  m = NxR14.seed_items!(NxR14.model(NxR14::BS::BUDGET_STD + 1))
  m.set_attribute(NxR14::DICT, NxR14::BS::KEY_MODE, 'vysoky')
  st = NxR14::BS.state(m)
  NxTest.assert_equal('vysoky', st['mode'], 'rezim sa cita dalej')
  NxTest.assert_equal(1, st['custom_items'].length, 'aj vlastne polozky')
  NxTest.assert_equal('newer', st['std'], 'stav markera cestuje SO STAVOM')
end

NxTest.test('R-14: nizkourovnovy zapis MIMO write! je zakazany (buduca mutacia guard neobide)') do
  m = NxR14.model
  err = begin
    NxR14::BS.write_attr(m, 'budget_mode', 'vysoky')
    nil
  rescue StandardError => e
    e.message
  end
  NxTest.assert(err.to_s.include?('mimo write!'), "write_attr mimo write! musi vyletiet: #{err.inspect}")
  err2 = begin
    NxR14::BS.write_json(m, 'budget_overrides', {})
    nil
  rescue StandardError => e
    e.message
  end
  NxTest.assert(err2.to_s.include?('mimo write!'), "write_json mimo write! musi vyletiet: #{err2.inspect}")
  NxTest.assert_equal({}, m.dicts[NxR14::DICT], 'a nic sa nezapisalo')
  # ...a zamok sa po behu VZDY pusti (inak by druhy pokus presiel)
  NxR14::BS.set_mode!(m, 'nizky')
  NxTest.assert_raise('mimo write!') { NxR14::BS.write_attr(m, 'budget_mode', 'vysoky') }
end

NxTest.test('R-14: vynimka v mutacnom bloku ABORTUJE cely krok (ziadny polovicny zapis)') do
  m = NxR14.model
  ok, errors = NxR14::BS.write!(m, 'R-14 test') { raise 'zlyhanie zapisu' }
  NxTest.refute(ok)
  NxTest.assert_equal(['zmenu sa nepodarilo uložiť'], Array(errors))
  NxTest.assert_equal(1, m.aborted, 'operacia sa abortovala')
  NxTest.assert_equal(0, m.committed)
  NxTest.assert(NxR14.marker_of(m).nil?, 'marker sa NEZAPISAL — krok neexistuje')
end

# ============================ PAYLOAD =======================================

NxTest.test('R-14: payload rozpoctu nesie kompatibilitny priznak pre OBE sekcie okna') do
  ok_p = NxR14.payload('current')
  NxTest.assert_equal({ 'state' => 'current', 'blocked' => false, 'reason' => '' }, ok_p['budget_std'])
  NxTest.assert_equal(false, NxR14.payload('legacy')['budget_std']['blocked'],
                      'legacy zakazka sa edituje bez obmedzenia')
  newer = NxR14.payload('newer')['budget_std']
  NxTest.assert_equal(true, newer['blocked'])
  NxTest.assert_equal(NxR14::BS.std_block_reason(:newer), newer['reason'],
                      'text je zo servera — klient si ho neskladá')
  invalid = NxR14.payload('invalid')['budget_std']
  NxTest.assert_equal(true, invalid['blocked'])
  NxTest.assert_equal(NxR14::BS.std_block_reason(:invalid), invalid['reason'])
  # stav bez kluca (legacy volanie vypoctu / ciste testy) NESMIE nic zablokovat
  legacy_call = Noxun::Engine::Budget.compute({ rows: [], edging: [] },
                                              { 'mode' => 'standard' },
                                              Noxun::Engine::SupplierSettings.seed_supplier)
  NxTest.assert_equal(false, legacy_call['budget_std']['blocked'])
end

# ============================ BRANA CENOVYCH EXPORTOV =======================

NxTest.test('R-14: XLSX rozpoctu sa pri novsom markeri zastavi PRED savepanel') do
  Dir.mktmpdir('nx-r14-') do |dir|
    msg, err, files, calls = NxR14.run_export(:do_budget_xlsx, 'newer', dir, 'rozpocet.xlsx')
    NxTest.assert_equal([], files, 'subor NESMIE vzniknut')
    NxTest.assert_equal([], calls, 'a picker sa ani neotvoril')
    NxTest.assert(err, 'status je cerveny')
    NxTest.assert_equal(NxR14::BS.std_block_reason(:newer), msg)
  end
end

NxTest.test('R-14: XLSX cenovej ponuky rovnako — dokument pre zakaznika nevznikne') do
  Dir.mktmpdir('nx-r14-') do |dir|
    msg, err, files, calls = NxR14.run_export(:do_cp_xlsx, 'invalid', dir, 'ponuka.xlsx')
    NxTest.assert_equal([], files)
    NxTest.assert_equal([], calls)
    NxTest.assert(err)
    NxTest.assert_equal(NxR14::BS.std_block_reason(:invalid), msg)
  end
end

NxTest.test('R-14: kompatibilna zakazka exportuje dalej (brana nemeri prazdno)') do
  Dir.mktmpdir('nx-r14-') do |dir|
    _msg, err, files, calls = NxR14.run_export(:do_budget_xlsx, 'current', dir, 'rozpocet.xlsx')
    NxTest.assert_equal(['rozpocet.xlsx'], files, 'subor NAOZAJ vznikol')
    NxTest.assert_equal([:savepanel], calls)
    NxTest.refute(err)
  end
end

NxTest.test('R-14: branu maju LEN cenove exporty — VEPO a nakupny CSV nie') do
  s = NxR14.src(File.join('ui', 'production_core.rb'))
  %w[do_budget_xlsx do_cp_xlsx].each do |m|
    body = s[/def #{m}\(model, data, generation:, status:, repush:\).*?\n      rescue StandardError/m].to_s
    NxTest.refute(body.empty?, "#{m} sa nasla")
    NxTest.assert(body.include?('budget_std_block(budget)'), "#{m}: kompatibilitna brana chyba")
  end
  %w[do_export do_hw_csv].each do |m|
    body = s[/def #{m}\(model, data, generation:, status:, repush:\).*?\n      rescue StandardError/m].to_s
    NxTest.refute(body.empty?, "#{m} sa nasla")
    NxTest.refute(body.include?('budget_std_block'),
                  "#{m}: rezaci/nakupny vystup rozpoctove data nenesie — blokovat ho by zastavilo vyrobu")
  end
end

NxTest.test('R-14: budget_std_block — prazdny dovod ma nahradu, kompatibilny payload prejde') do
  NxTest.assert(NxR14::PC.budget_std_block(nil).nil?)
  NxTest.assert(NxR14::PC.budget_std_block('totals' => {}).nil?, 'payload bez priznaku neblokuje')
  NxTest.assert(NxR14::PC.budget_std_block(NxR14.export_budget('current')).nil?)
  msg = NxR14::PC.budget_std_block('budget_std' => { 'blocked' => true, 'reason' => '' })
  NxTest.assert(msg.to_s.length > 10, "prazdny dovod nesmie skoncit prazdnou hlaskou: #{msg.inspect}")
end

# ============================ KANAL CHYB DO OKNA ============================

NxTest.test('R-14: do_budget — echo(false) PRED payloadom, potom cerveny status s dovodom') do
  m = NxR14.model(NxR14::BS::BUDGET_STD + 1)
  order = []
  msg = nil
  err = nil
  NxR14::PC.do_budget(m, { 'gen' => 1, 'op' => 'mode', 'mode' => 'vysoky' },
                      generation: 1,
                      status: ->(t, e = false) { order << :status; msg = t; err = e },
                      repush: -> { order << :repush },
                      result: ->(op, ok) { order << [:result, op, ok] })
  NxTest.assert_equal([[:result, 'mode', false], :repush, :status], order,
                      'poradie kanalov: echo vysledku -> cerstvy payload -> status')
  NxTest.assert(err, 'status je cerveny')
  NxTest.assert_equal("Nezapísané: #{NxR14::BS.std_block_reason(:newer)}", msg)
  NxTest.assert_equal([], m.ops, 'a v modeli sa nic nedialo')
end
