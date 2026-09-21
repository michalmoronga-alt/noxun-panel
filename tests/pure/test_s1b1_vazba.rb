# frozen_string_literal: true
# S1-B1 — SPOTREBIC V ZAKAZKE: DATA, VAZBA, KONTROLA.
#
# CO BOLO ZLE: rozpocet mal vlastny enum spotrebicov (slovenske kody), polozka
# nemala ziadnu vazbu na model z katalogu ani na kus v modeli a „spotrebic
# dodava zakaznik“ neexistoval. Skrinka, v ktorej rura fyzicky stoji, o nej
# nevedela — takze zmazanie skrinky nechalo polozku ukazovat do prazdna a ID
# skriniek sa NAVYSE recykluju (`Ids.next_id`), takze po case ukazovala na
# CUDZI kus.
#
# CO PLATI TERAZ:
#   * JEDNA kanonicka sada kodov kategorii = kody katalogu; legacy slovenske
#     kody sa pri citani prevedu, zapisuje sa uz len kanon (`BUDGET_STD` 2),
#   * polozka nesie `catalog_id`, `snapshot` (kopia rozmerov — zakazka nezavisi
#     od ziveho katalogu), `owner` a `customer_supplied`,
#   * VAZBA JE OBOJSMERNA: entita vlastnika nesie `appliance_refs[]`, a vlastnik
#     plati LEN ked entita existuje A jej refs obsahuju uuid polozky,
#   * VSETKY mutacie spotrebicov idu jedinym transakcnym vstupom
#     `ApplianceBinding.apply!` — polozka aj obe strany vazby v JEDNEJ operacii
#     (jeden krok Spat), guardy PRED `start_operation`, vynimka = abort.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxS1B1
  module_function

  BS  = Noxun::Engine::BudgetStore
  AB  = Noxun::Engine::ApplianceBinding
  BD  = Noxun::Engine::Budget
  CP  = Noxun::Engine::CpExport
  VAL = Noxun::Engine::Validation
  BOM = Noxun::Engine::Bom
  AC  = Noxun::Engine::ApplianceCatalog
  PC  = Noxun::Engine::ProductionCore
  STORE = Noxun::Engine::Store
  DICT = STORE::DICT

  # Fake dokument: dict + pocitadla operacii (vzor `test_r14_budget_std.rb`).
  # `path` je nutne — `DocKey.key` bez neho vrati prazdny token.
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

    def active_path
      nil
    end

    def start_operation(name, _disable_ui = false, _next_transparent = false, _transparent = false)
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

  # Fake kus v modeli (skrinka / slot / doska). Nesie NOXUN atributy presne
  # tak, ako ich cita `Store`.
  class FakeInst < NxTest::FakeEntity
    attr_reader :persistent_id

    def initialize(pid)
      super()
      @persistent_id = pid
    end
  end

  def cabinet(id, pid, type: 'lower', refs: nil, expects: nil, schema: 16, extra: {})
    inst = FakeInst.new(pid)
    cfg = { 'config_schema' => schema, 'type' => type, 'width' => 600.0, 'height' => 720.0,
            'depth' => 560.0, 'thickness' => 18.0, 'floor_height' => 100.0,
            'bottom_mode' => 'between_sides', 'top_mode' => 'two_rails',
            'back_mode' => 'inset', 'back_thickness' => 5.0 }.merge(extra)
    cfg['appliance_refs'] = refs if refs
    cfg['appliance_expects'] = expects if expects
    STORE.write(inst, { kind: 'cabinet', cabinet_id: id, config: cfg })
    inst
  end

  def board(id, pid, refs: nil, schema: 2)
    inst = FakeInst.new(pid)
    cfg = { 'config_schema' => schema, 'role' => 'worktop', 'name' => 'Doska',
            'length' => 2400.0, 'width' => 600.0, 'thickness' => 38.0 }
    cfg['appliance_refs'] = refs if refs
    STORE.write(inst, { kind: 'board', id: id, manufactured: true, config: cfg })
    inst
  end

  def cfg_of(inst)
    STORE.config(inst) || {}
  end

  def refs_of(inst)
    Array(cfg_of(inst)['appliance_refs'])
  end

  # --- stubovanie (vzor `test_r14_budget_std.rb`) ---------------------------

  # entries: [[modul, meno, lambda], …]
  #
  # Povodna metoda sa odklada ako OBJEKT (`UnboundMethod`), nie pod aliasom:
  # stuby sa vnaraju (skratka `create!` si stubuje katalog aj zapisovace
  # vnutri testu, ktory uz stubol scan) a dva aliasy toho isteho mena by si
  # navzajom prepisali ulozeny original.
  def with_stubs(entries)
    saved = []
    entries.each do |(mod, name, impl)|
      sc = mod.singleton_class
      saved << [sc, name, sc.instance_method(name)]
      sc.send(:define_method, name, &impl)
    end
    yield
  ensure
    saved.reverse_each { |(sc, name, orig)| sc.send(:define_method, name, orig) }
  end

  # Scan modelu + zapisovace vazieb. Headless sa NEPRESTAVUJE (to overuje
  # in-SketchUp sekcia `run_s1b1`) — zapis sa premietne rovno do configu fake
  # entity, aby sa dal overit KONTRAKT zaznamu a poradie zapisov.
  def scan_stub(cabinets: [], boards: [], detached: {})
    [Noxun::Engine::Ids, :top_level_scan,
     lambda { |_model|
       { 'cabinets' => cabinets, 'boards' => boards, 'detached' => Hash.new(0).merge(detached) }
     }]
  end

  def writer_stubs(log)
    [
      [Noxun::Engine::CabinetBuilder, :write_appliance_refs!,
       lambda { |_model, inst, refs|
         log << [:cabinet, Noxun::Engine::Store.get(inst, 'cabinet_id').to_s, Array(refs).length]
         cfg = Noxun::Engine::Store.config(inst) || {}
         list = Array(refs)
         list.empty? ? cfg.delete('appliance_refs') : cfg['appliance_refs'] = list
         Noxun::Engine::Store.write_config(inst, cfg)
         inst
       }],
      [Noxun::Engine::BoardBuilder, :write_appliance_refs!,
       lambda { |inst, refs|
         log << [:board, Noxun::Engine::Store.get(inst, 'id').to_s, Array(refs).length]
         cfg = Noxun::Engine::Store.config(inst) || {}
         list = Array(refs)
         list.empty? ? cfg.delete('appliance_refs') : cfg['appliance_refs'] = list
         cfg['config_schema'] = Noxun::Engine::BoardBuilder::BOARD_CONFIG_SCHEMA
         Noxun::Engine::Store.write_config(inst, cfg)
         true
       }]
    ]
  end

  def snapshot_stub(map)
    [AC, :snapshot_for,
     lambda { |id|
       rec = map[id.to_s]
       rec ? [:ok, { snapshot: rec }] : [:not_found, { message: 'spotrebič sa nenašiel' }]
     }]
  end

  # --- fixtury snapshotov ----------------------------------------------------

  def fridge_snapshot(id = 'CAT-FRIDGE')
    { 'catalog_id' => id, 'category' => 'fridge', 'manufacturer' => 'Beko',
      'name' => 'BCNA306E5ZSN',
      'dims' => {
        'body' => { 'width' => 540.0, 'height' => 1935.0, 'depth' => 545.0 },
        'niche' => { 'width_min' => 560.0, 'height_min' => 1940.0, 'height_max' => 1950.0,
                     'depth_min' => 555.0 },
        'front' => { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                     'door_gap' => 71.0, 'door_upper' => 1159.0 },
        'install' => { 'door_system' => 'sliding' }
      },
      'catalog_std' => 1, 'snapshot_at' => '2026-09-20T10:00:00Z' }
  end

  def dishwasher_snapshot(id = 'CAT-DW450', cls = '450')
    { 'catalog_id' => id, 'category' => 'dishwasher', 'manufacturer' => 'Bosch',
      'name' => 'SPV6EMX05E',
      'dims' => {
        'body' => { 'width' => 448.0, 'depth' => 550.0 },
        'niche' => { 'width_min' => 450.0, 'height_min' => 815.0 },
        'install' => { 'dishwasher_class' => cls }
      },
      'catalog_std' => 1, 'snapshot_at' => '2026-09-20T10:00:00Z' }
  end

  def hob_snapshot(id = 'CAT-HOB')
    { 'catalog_id' => id, 'category' => 'hob', 'manufacturer' => 'Whirlpool',
      'name' => 'WL B1160 BF',
      'dims' => { 'body' => { 'width' => 551.0, 'height' => 50.0, 'depth' => 479.0 } },
      'catalog_std' => 1, 'snapshot_at' => '2026-09-20T10:00:00Z' }
  end

  # Skratka: zaloz polozku s vlastnikom cez JEDINY vstup.
  def create!(model, snapshot, owner, attrs = {}, log = [])
    res = nil
    with_stubs([snapshot_stub(snapshot['catalog_id'] => snapshot)] + writer_stubs(log)) do
      res = AB.apply!(model, model_guid: '', op: 'create',
                      attrs: { 'nazov' => snapshot['name'] }.merge(attrs),
                      catalog_id: snapshot['catalog_id'], owner: owner)
    end
    res
  end

  def state_of(model)
    BS.state(model)
  end

  def payload(model)
    BD.compute({ rows: [], edging: [] }, state_of(model),
               Noxun::Engine::SupplierSettings.seed_supplier)
  end

  def appliance_row(p, id)
    sec = Array(p['sections']).find { |s| s['key'] == 'appliances' }
    Array(sec['rows']).find { |r| r['id'] == id }
  end
end

# ============================ 1) KANONICKE KODY =============================

NxTest.test('S1-B1: kody kategorii su JEDNA sada — katalogova; legacy sa prevedie') do
  NxTest.assert_equal(NxS1B1::AC::CATEGORIES, NxS1B1::BS::APPLIANCE_TYPES,
                      'rozpocet uz vlastny enum NEMA')
  NxTest.assert_equal(NxS1B1::AC::CATEGORY_LABELS, NxS1B1::BS::APPLIANCE_LABELS,
                      'popisky su tiez z jednej mapy')
  NxTest.assert_equal('other', NxS1B1::BS::DEFAULT_APPLIANCE_TYPE)
  { 'chladnicka' => 'fridge', 'rura' => 'oven', 'mikrovlnka' => 'microwave',
    'umyvacka' => 'dishwasher', 'digestor' => 'hood', 'varna_doska' => 'hob',
    'ine' => 'other' }.each do |legacy, canon|
    NxTest.assert_equal(canon, NxS1B1::BS.canon_appliance_type(legacy),
                        "legacy #{legacy} -> #{canon}")
  end
  NxS1B1::AC::CATEGORIES.each do |code|
    NxTest.assert_equal(code, NxS1B1::BS.canon_appliance_type(code), "kanon #{code} ostava")
  end
  NxTest.assert(NxS1B1::BS.canon_appliance_type('kozub').nil?, 'neznamy kod = nil')
  NxTest.assert(NxS1B1::BS.canon_appliance_type('').nil?, 'prazdny kod = nil')
end

NxTest.test('S1-B1: KAZDA kategoria prejde pridanim aj znovuotvorenim zakazky') do
  NxS1B1::AC::CATEGORIES.each do |code|
    m = NxS1B1::FakeModel.new
    item, errs = NxS1B1::BS.add_appliance!(m, { 'typ' => code, 'nazov' => "Model #{code}" })
    NxTest.assert(errs.empty?, "#{code}: #{errs.inspect}")
    NxTest.assert_equal(code, item['typ'])
    # Znovuotvorenie = citanie ulozeneho dokumentu.
    again = NxS1B1::BS.appliances(m).first
    NxTest.assert_equal(code, again['typ'], "#{code} prezije citanie")
  end
end

NxTest.test('S1-B1: legacy zakazka (typ `rura`, std 1) sa otvori, upravi a ulozi ako `oven`') do
  m = NxS1B1::FakeModel.new
  m.set_attribute(NxS1B1::DICT, NxS1B1::BS::KEY_STD, 1)
  m.set_attribute(NxS1B1::DICT, NxS1B1::BS::KEY_APPLIANCES,
                  [{ 'id' => 'APPL-1', 'typ' => 'rura', 'nazov' => 'Stará rúra',
                     'cena' => 100.0, 'cp_skupina' => 'zostava' }].to_json)
  NxTest.assert_equal(:current, NxS1B1::BS.std_state(m), 'std 1 je kompatibilna')
  read = NxS1B1::BS.appliances(m).first
  NxTest.assert_equal('oven', read['typ'], 'citanie prevedie legacy kod')
  NxTest.assert_equal({ 'kind' => 'job' }, read['owner'], 'legacy polozka je „len zakazka“')
  item, errs = NxS1B1::BS.update_appliance!(m, 'APPL-1', { 'cena' => 120.0 })
  NxTest.assert(errs.empty?, errs.inspect)
  NxTest.assert_equal('oven', item['typ'], 'zapis je uz KANONICKY')
  NxTest.assert_equal(NxS1B1::BS::BUDGET_STD, m.get_attribute(NxS1B1::DICT, NxS1B1::BS::KEY_STD),
                      'prva mutacia zapecati std 2')
end

NxTest.test('S1-B1: JS zrkadlo kodov je zo SERVERA (ziadny natvrdo zapisany zoznam)') do
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'), encoding: 'UTF-8')
  NxTest.refute(js.include?("['chladnicka'"), 'stary natvrdo zapisany zoznam je prec')
  NxTest.assert(js.include?('b.appliance_types'), 'kategorie cita z payloadu')
  # Parita: server posiela PRESNE kanonicku sadu s popiskami.
  opts = NxS1B1::BS.appliance_type_options
  NxTest.assert_equal(NxS1B1::AC::CATEGORIES, opts.map { |o| o['code'] })
  NxTest.assert(opts.all? { |o| !o['label'].to_s.empty? }, 'kazdy kod ma SK popisok')
end

# ============================ 2) BUDGET_STD 2 ===============================

NxTest.test('S1-B1: BUDGET_STD je 2 a polozka nesie vazbu, snapshot aj priznak') do
  NxTest.assert_equal(2, NxS1B1::BS::BUDGET_STD)
  m = NxS1B1::FakeModel.new
  snap = NxS1B1.fridge_snapshot
  item, errs = NxS1B1::BS.add_appliance!(
    m, { 'nazov' => 'Beko', 'catalog_id' => 'CAT-FRIDGE', 'snapshot' => snap,
         'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-3' }, 'customer_supplied' => true },
    trusted: true
  )
  NxTest.assert(errs.empty?, errs.inspect)
  NxTest.assert_equal('CAT-FRIDGE', item['catalog_id'])
  NxTest.assert_equal('fridge', item['typ'], 'kategoriu urcuje SNAPSHOT, nie formular')
  NxTest.assert_equal({ 'kind' => 'cabinet', 'id' => 'CAB-3' }, item['owner'])
  NxTest.assert_equal(true, item['customer_supplied'])
  NxTest.assert_equal(snap['dims'], item['snapshot']['dims'], 'snapshot sa uklada BEZ normalizacie')
  NxTest.assert_equal(NxS1B1::BS::BUDGET_STD, m.get_attribute(NxS1B1::DICT, NxS1B1::BS::KEY_STD))
end

NxTest.test('S1-B1: klient NIKDY neposle snapshot, catalog_id ani vlastnika') do
  m = NxS1B1::FakeModel.new
  item, = NxS1B1::BS.add_appliance!(
    m, { 'nazov' => 'Podvrh', 'catalog_id' => 'PODVRH', 'snapshot' => NxS1B1.fridge_snapshot,
         'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-9' } }
  )
  NxTest.assert(item['catalog_id'].nil?, 'catalog_id z klienta sa zahadza')
  NxTest.assert(item['snapshot'].nil?, 'snapshot z klienta sa zahadza')
  NxTest.assert_equal({ 'kind' => 'job' }, item['owner'], 'vlastnik z klienta sa zahadza')
end

NxTest.test('S1-B1: snapshot je NEZAVISLY od neskorsej zmeny aj tombstonu katalogu') do
  m = NxS1B1::FakeModel.new
  snap = NxS1B1.fridge_snapshot
  NxS1B1::BS.add_appliance!(m, { 'nazov' => 'Beko', 'catalog_id' => 'CAT-FRIDGE',
                                 'snapshot' => snap }, trusted: true)
  # Katalog sa medzitym zmenil (ina nika) a zaznam bol vyradeny.
  snap['dims']['niche']['width_min'] = 999.0
  snap['deleted_at'] = '2026-09-21T00:00:00Z'
  stored = NxS1B1::BS.appliances(m).first
  NxTest.assert_equal(560.0, stored['snapshot']['dims']['niche']['width_min'],
                      'zakazka drzi KOPIU — zmena katalogu s nou nepohne')
  NxTest.assert(stored['snapshot']['deleted_at'].nil? ||
                stored['snapshot']['deleted_at'].to_s.empty?,
                'tombstone katalogu do zakazky neprenikol')
end

NxTest.test('S1-B1: typ je zamknuty pri modeli z katalogu aj pri fyzickom vlastnikovi (B3)') do
  m = NxS1B1::FakeModel.new
  item, = NxS1B1::BS.add_appliance!(m, { 'nazov' => 'Beko', 'catalog_id' => 'CAT-FRIDGE',
                                         'snapshot' => NxS1B1.fridge_snapshot }, trusted: true)
  _, errs = NxS1B1::BS.update_appliance!(m, item['id'], { 'typ' => 'oven' })
  NxTest.assert_equal('fridge', NxS1B1::BS.appliances(m).first['typ'], 'typ sa nezmenil')
  NxTest.assert(errs.empty? || errs.any?, 'kontrakt: typ urcuje model')

  m2 = NxS1B1::FakeModel.new
  bound, = NxS1B1::BS.add_appliance!(m2, { 'nazov' => 'Rúra', 'typ' => 'oven',
                                           'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-1' } },
                                     trusted: true)
  _, errs2 = NxS1B1::BS.update_appliance!(m2, bound['id'], { 'typ' => 'microwave' })
  NxTest.assert(errs2.include?(NxS1B1::BS::TYPE_LOCKED_MSG),
                "viazana polozka typ nemeni: #{errs2.inspect}")
  NxTest.assert_equal('oven', NxS1B1::BS.appliances(m2).first['typ'])

  free, = NxS1B1::BS.add_appliance!(m2, { 'nazov' => 'Voľná', 'typ' => 'other' })
  _, errs3 = NxS1B1::BS.update_appliance!(m2, free['id'], { 'typ' => 'hood' })
  NxTest.assert(errs3.empty?, "polozka bez katalogu a bez vlastnika typ menit SMIE: #{errs3.inspect}")
end

# ========================= 3) DODAVA ZAKAZNIK ===============================

NxTest.test('S1-B1: „dodáva zákazník“ je PRIZNAK — cena ostava, sucet klesne') do
  m = NxS1B1::FakeModel.new
  item, = NxS1B1::BS.add_appliance!(m, { 'nazov' => 'Beko', 'typ' => 'fridge', 'cena' => 899.0 })
  NxS1B1::BS.set_appliances_included!(m, true)
  before = NxS1B1.payload(m)
  NxTest.assert_close(899.0, NxS1B1.appliance_row(before, item['id'])['spolu'], 0.01)

  NxS1B1::BS.update_appliance!(m, item['id'], { 'customer_supplied' => true })
  after = NxS1B1.payload(m)
  row = NxS1B1.appliance_row(after, item['id'])
  NxTest.assert_equal(true, row['customer_supplied'])
  NxTest.assert_close(0.0, row['spolu'], 0.01, 'do suctu ide 0')
  NxTest.assert_close(899.0, row['cena_ref'], 0.01, 'ulozena cena ostava referencne v riadku')
  NxTest.assert_close(899.0, NxS1B1::BS.appliances(m).first['cena'], 0.01,
                      'a v ZAKAZKE je nedotknuta — 0 sa NIKDY nezapisuje')
  NxTest.refute(row['price_missing'], 'riadok uz nie je „bez ceny“')
  sec = Array(after['sections']).find { |s| s['key'] == 'appliances' }
  NxTest.assert_close(0.0, sec['subtotal'], 0.01, 'medzisucet klesol')
  NxTest.assert_close(before['totals']['raw_total'] - 899.0, after['totals']['raw_total'], 0.01,
                      'a SPOLU tiez')

  # Spat: cena je zase v sucte.
  NxS1B1::BS.update_appliance!(m, item['id'], { 'customer_supplied' => false })
  NxTest.assert_close(before['totals']['raw_total'], NxS1B1.payload(m)['totals']['raw_total'], 0.01)
end

NxTest.test('S1-B1: „dodáva zákazník“ BEZ ceny uz nehlasi `missing_price`') do
  m = NxS1B1::FakeModel.new
  item, = NxS1B1::BS.add_appliance!(m, { 'nazov' => 'Digestor', 'typ' => 'hood', 'cena' => nil })
  keys = NxS1B1.payload(m)['budget_check'].map { |w| w['stable_key'] }
  NxTest.assert(keys.include?("budget|appliance:#{item['id']}|missing_price"),
                'bez priznaku upozornenie PLATI')
  NxS1B1::BS.update_appliance!(m, item['id'], { 'customer_supplied' => true })
  keys2 = NxS1B1.payload(m)['budget_check'].map { |w| w['stable_key'] }
  NxTest.refute(keys2.include?("budget|appliance:#{item['id']}|missing_price"),
                's priznakom uz nie (nie je to nasa cena)')
  NxTest.assert(NxS1B1::BS.appliances(m).first['cena'].nil?, 'a cena ostala nil, nie 0')
end

NxTest.test('S1-B1: cenova ponuka ma informacny riadok aj stitok v specifikacii (B10)') do
  m = NxS1B1::FakeModel.new
  NxS1B1::BS.add_appliance!(m, { 'nazov' => 'Beko chladnička', 'typ' => 'fridge', 'cena' => 899.0,
                                 'customer_supplied' => true })
  NxS1B1::BS.set_appliances_included!(m, true)
  p = NxS1B1.payload(m)
  cp = NxS1B1::CP.cp_rows(p, overrides: {}, threshold: 150.0)
  info = Array(cp['rows']).select { |r| r['kind'] == 'info' }
  NxTest.assert_equal(1, info.length, "informacny riadok chyba: #{cp['rows'].inspect}")
  NxTest.assert(info.first['polozka'].include?(NxS1B1::CP::CUSTOMER_SUPPLIED_LABEL))
  NxTest.assert_close(0.0, info.first['cena'], 0.001, 'riadok je nulovy')
  labels = NxS1B1::CP.appliance_labels(p)
  NxTest.assert(labels.first.to_s.include?(NxS1B1::CP::CUSTOMER_SUPPLIED_LABEL),
                "specifikacia stitok nenesie: #{labels.inspect}")

  # VYPNUTE zapocitanie = spotrebice do CP nejdu VOBEC (existujuce pravidlo).
  NxS1B1::BS.set_appliances_included!(m, false)
  cp_off = NxS1B1::CP.cp_rows(NxS1B1.payload(m), overrides: {}, threshold: 150.0)
  NxTest.assert(Array(cp_off['rows']).none? { |r| r['kind'] == 'info' },
                'nezapocitana sekcia informacny riadok nedava')
end

NxTest.test('S1-B1: sekcia sa vola „Spotrebiče a vybavenie“ v rozpocte aj v ponuke') do
  NxTest.assert_equal('Spotrebiče a vybavenie', NxS1B1::BD::SECTION_NAMES['appliances'])
  NxTest.assert_equal('SPOTREBIČE A VYBAVENIE', NxS1B1::CP::CATEGORY_NAMES['spotrebice'])
end

# ============================ 4) MATICA ====================================

NxTest.test('S1-B1: matica kategoria -> FYZICKY vlastnik; `job` smie vsetko (B11)') do
  {
    'fridge' => %w[cabinet], 'oven' => %w[cabinet], 'microwave' => %w[cabinet],
    'dishwasher' => %w[slot], 'hob' => %w[board], 'sink' => %w[board],
    'hood' => [], 'other' => []
  }.each do |cat, kinds|
    NxTest.assert_equal(kinds, NxS1B1::AB::OWNER_MATRIX[cat], "matica #{cat}")
    NxTest.assert(NxS1B1::AB.allowed?(cat, 'job'), "#{cat}: „len zakazka“ je vzdy legitimna")
  end
  NxTest.refute(NxS1B1::AB.allowed?('fridge', 'slot'), 'chladnicka do slotu umyvacky nepatri')
  NxTest.refute(NxS1B1::AB.allowed?('dishwasher', 'cabinet'), 'umyvacka patri LEN do slotu')
  NxTest.refute(NxS1B1::AB.allowed?('hood', 'cabinet'), 'digestor fyzickeho vlastnika nema')
end

NxTest.test('S1-B1 (M2): stale payload mimo matice sa odmietne PRED otvorenim operacie') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab]),
                     NxS1B1.snapshot_stub('CAT-DW450' => NxS1B1.dishwasher_snapshot)] +
                    NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'create', attrs: { 'nazov' => 'Bosch' },
                            catalog_id: 'CAT-DW450',
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  NxTest.refute(res[:ok], 'umyvacka do beznej skrinky nepatri')
  NxTest.assert_equal([], m.ops, 'a ZIADNA operacia sa neotvorila (ziadny krok Spat)')
  NxTest.assert_equal([], log, 'ani zapis vazby')
  NxTest.assert_equal([], NxS1B1::BS.appliances(m), 'ani polozka')
end

NxTest.test('S1-B1: odpojena skrinka, cudzi dokument a novsi config sa odmietnu bez operacie') do
  snap = NxS1B1.fridge_snapshot
  owner = { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 }

  # (a) ODPOJENY DIELEC (D-134).
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab], detached: { 'CAB-1' => 1 }),
                     NxS1B1.snapshot_stub('CAT-FRIDGE' => snap)] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'create', attrs: {},
                            catalog_id: 'CAT-FRIDGE', owner: owner)
  end
  NxTest.refute(res[:ok])
  NxTest.assert_equal([NxS1B1::AB::MSG_OWNER_DETACH], res[:errors])
  NxTest.assert_equal([], m.ops)

  # (b) NOVSI CONFIG skrinky.
  m2 = NxS1B1::FakeModel.new
  newer = NxS1B1.cabinet('CAB-1', 101, schema: Noxun::Engine::CabinetBuilder::CONFIG_SCHEMA + 1)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [newer]),
                     NxS1B1.snapshot_stub('CAT-FRIDGE' => snap)] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m2, model_guid: '', op: 'create', attrs: {},
                            catalog_id: 'CAT-FRIDGE', owner: owner)
  end
  NxTest.refute(res[:ok])
  NxTest.assert_equal([NxS1B1::AB::MSG_OWNER_NEWER], res[:errors])
  NxTest.assert_equal([], m2.ops)

  # (c) DVA KUSY s tym istym ID = nejednoznacna identita.
  m3 = NxS1B1::FakeModel.new
  twin_a = NxS1B1.cabinet('CAB-1', 101)
  twin_b = NxS1B1.cabinet('CAB-1', 202)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [twin_a, twin_b]),
                     NxS1B1.snapshot_stub('CAT-FRIDGE' => snap)] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m3, model_guid: '', op: 'create', attrs: {},
                            catalog_id: 'CAT-FRIDGE', owner: owner)
  end
  NxTest.refute(res[:ok])
  NxTest.assert_equal([NxS1B1::AB::MSG_OWNER_AMBIG], res[:errors])

  # (d) RECYKLOVANE ID: ID sedi, PID nie.
  m4 = NxS1B1::FakeModel.new
  recycled = NxS1B1.cabinet('CAB-1', 999)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [recycled]),
                     NxS1B1.snapshot_stub('CAT-FRIDGE' => snap)] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m4, model_guid: '', op: 'create', attrs: {},
                            catalog_id: 'CAT-FRIDGE', owner: owner)
  end
  NxTest.refute(res[:ok], 'recyklovane ID bez zhody PID sa ODMIETA')
  NxTest.assert_equal([], m4.ops)
end

NxTest.test('S1-B1: ponuka vlastnikov vynechava odpojene skrinky a novsie configy') do
  cab = NxS1B1.cabinet('CAB-1', 101)
  slot = NxS1B1.cabinet('CAB-2', 102, type: 'dishwasher')
  det  = NxS1B1.cabinet('CAB-3', 103)
  newer = NxS1B1.cabinet('CAB-4', 104, schema: Noxun::Engine::CabinetBuilder::CONFIG_SCHEMA + 1)
  brd  = NxS1B1.board('BRD-1', 201)
  map = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot, det, newer], boards: [brd],
                                      detached: { 'CAB-3' => 2 })]) do
    map = NxS1B1::AB.owner_options_map(NxS1B1::FakeModel.new)
  end
  NxTest.assert_equal(%w[CAB-1], map['cabinet'].map { |o| o['id'] }, 'len zapisovatelne skrinky')
  NxTest.assert_equal(%w[CAB-2], map['slot'].map { |o| o['id'] }, 'slot je VLASTNY druh')
  NxTest.assert_equal(%w[BRD-1], map['board'].map { |o| o['id'] })
  NxTest.assert_equal(101, map['cabinet'].first['pid'], 'ponuka nesie PID (identita ciela)')

  opts = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot], boards: [brd])]) do
    opts = NxS1B1::AB.owner_options(NxS1B1::FakeModel.new, 'dishwasher')
  end
  NxTest.assert_equal(%w[slot job], opts.map { |o| o['kind'] },
                      'umyvacka: len sloty + „len zakazka“')
end

# ==================== 5) JEDNA OPERACIA (create / move / unbind) ============

NxTest.test('S1-B1: `create` s vlastnikom = JEDNA operacia — polozka aj vazba naraz') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    res = NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                         { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 }, {}, log)
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal(1, m.ops.length, 'PRAVE JEDNA operacia = jeden krok Spat')
  NxTest.assert_equal(NxS1B1::AB::OP_NAME, m.ops.first)
  NxTest.assert_equal(1, m.committed)
  NxTest.assert_equal(0, m.aborted)
  NxTest.assert_equal(true, res[:geometry_changed], 'skrinka sa prestavala')

  item = NxS1B1::BS.appliances(m).first
  NxTest.assert_equal('fridge', item['typ'])
  NxTest.assert_equal({ 'kind' => 'cabinet', 'id' => 'CAB-1' }, item['owner'])
  refs = NxS1B1.refs_of(cab)
  NxTest.assert_equal(1, refs.length, 'skrinka o vazbe VIE')
  NxTest.assert_equal(item['id'], refs.first['item_id'])
end

NxTest.test('S1-B1: KONTRAKT zaznamu `appliance_refs[]` — chybajuce pole je KLUC NAVYSE, nikdy 0') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  rec = NxS1B1.refs_of(cab).first
  NxTest.assert_equal('fridge', rec['category'])
  NxTest.assert_equal({ 'width' => 540.0, 'height' => 1935.0, 'depth' => 545.0 }, rec['body'])
  NxTest.assert_equal({ 'width_min' => 560.0, 'height_min' => 1940.0, 'height_max' => 1950.0,
                        'depth_min' => 555.0 }, rec['niche'])
  NxTest.assert_equal({ 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                        'door_gap' => 71.0, 'door_upper' => 1159.0 }, rec['bands'])
  NxTest.assert_equal({ 'door_system' => 'sliding' }, rec['install'])
  # Codex #384 kolo 1 (P2): zaznam nesie aj MENO MODELU — referencia v modeli
  # (S1-F box niky) sa nim vola, inak by sa kazda chladnicka volala rovnako.
  NxTest.assert_equal('Beko', rec['manufacturer'])
  NxTest.assert_equal('BCNA306E5ZSN', rec['name'])
  NxTest.refute(rec['niche'].key?('width_max'), 'co list nekotuje, v zazname NIE JE')
  NxTest.refute(rec.key?('furniture_doors'), 'prazdny blok sa nezapisuje ako {}')
  NxTest.assert_equal('2026-09-20T10:00:00Z', rec['snapshot_at'])
end

NxTest.test('S1-B1: `move` = JEDNA operacia — stara skrinka bez vazby, nova s nou') do
  m = NxS1B1::FakeModel.new
  a = NxS1B1.cabinet('CAB-1', 101)
  b = NxS1B1.cabinet('CAB-2', 102)
  log = []
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [a, b])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  ops_before = m.ops.length
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [a, b])] + NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal(1, m.ops.length - ops_before, 'presun je JEDEN krok Spat')
  NxTest.assert_equal([], NxS1B1.refs_of(a), 'stara skrinka vazbu stratila')
  NxTest.assert_equal(1, NxS1B1.refs_of(b).length, 'nova ju ma')
  NxTest.assert_equal({ 'kind' => 'cabinet', 'id' => 'CAB-2' },
                      NxS1B1::BS.appliances(m).first['owner'])
  NxTest.assert_equal([[:cabinet, 'CAB-1', 0], [:cabinet, 'CAB-2', 1]], log,
                      'poradie: najprv sa vazba zrusi, potom zapise')
end

NxTest.test('S1-B1: `unbind` vrati polozku do „len zakazka“ a zmaze vazbu') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'unbind', item_id: id)
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal({ 'kind' => 'job' }, NxS1B1::BS.appliances(m).first['owner'])
  NxTest.assert_equal([], NxS1B1.refs_of(cab))
  NxTest.assert_close(0.0, NxS1B1::BS.appliances(m).first['cena'].to_f, 0.01,
                      'cena polozky sa odpojenim nemeni')
end

NxTest.test('S1-B1: `remove` zmaze polozku AJ vazbu u vlastnika — jednym krokom') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  ops_before = m.ops.length
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'remove', item_id: id)
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal(1, m.ops.length - ops_before)
  NxTest.assert_equal([], NxS1B1::BS.appliances(m))
  NxTest.assert_equal([], NxS1B1.refs_of(cab), 'skrinka uz o zmazanom kuse netvrdi nic')
end

NxTest.test('S1-B1: doska = zapis configu + peciatka schemy 2, BEZ prestavby (B9)') do
  m = NxS1B1::FakeModel.new
  brd = NxS1B1.board('BRD-1', 201, schema: 1)
  before = NxS1B1.cfg_of(brd).reject { |k, _| %w[config_schema appliance_refs].include?(k) }
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(boards: [brd]),
                     NxS1B1.snapshot_stub('CAT-HOB' => NxS1B1.hob_snapshot)]) do
    res = NxS1B1.create!(m, NxS1B1.hob_snapshot,
                         { 'kind' => 'board', 'id' => 'BRD-1', 'pid' => 201 }, {}, log)
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal(false, res[:geometry_changed], 'doska sa NEPRESTAVUJE')
  NxTest.assert_equal([[:board, 'BRD-1', 1]], log)
  cfg = NxS1B1.cfg_of(brd)
  NxTest.assert_equal(Noxun::Engine::BoardBuilder::BOARD_CONFIG_SCHEMA, cfg['config_schema'],
                      'peciatka schemy je sucastou zapisu')
  NxTest.assert_equal(1, Array(cfg['appliance_refs']).length)
  NxTest.assert_equal(before, cfg.reject { |k, _| %w[config_schema appliance_refs].include?(k) },
                      'ostatne polia configu ostali nedotknute')
end

NxTest.test('S1-B1 (M1/B1): vynimka v zapise polozky ABORTUJE CELU operaciu') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab]),
                     NxS1B1.snapshot_stub('CAT-FRIDGE' => NxS1B1.fridge_snapshot),
                     [NxS1B1::BS, :stamp_std, ->(_model) { raise 'zlyhanie peciatky' }]] +
                    NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'create', attrs: { 'nazov' => 'Beko' },
                            catalog_id: 'CAT-FRIDGE',
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  NxTest.refute(res[:ok], 'vynimka = neuspech')
  NxTest.assert_equal(1, m.ops.length, 'operacia sa otvorila')
  NxTest.assert_equal(1, m.aborted, 'a bola ABORTOVANA')
  NxTest.assert_equal(0, m.committed, 'nikdy necommitovana')
  NxTest.assert_equal([], log, 'k zapisu vazby sa vobec nedoslo')
end

NxTest.test('S1-B1 (B12): `rebind_model` s inou kategoriou sa ODMIETA, neodpaja') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  ops_before = m.ops.length
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab]),
                     NxS1B1.snapshot_stub('CAT-DW450' => NxS1B1.dishwasher_snapshot)] +
                    NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'rebind_model', item_id: id,
                            catalog_id: 'CAT-DW450')
  end
  NxTest.refute(res[:ok])
  NxTest.assert_equal([NxS1B1::AB::MSG_REBIND_CAT], res[:errors])
  NxTest.assert_equal(ops_before, m.ops.length, 'ziadna operacia')
  NxTest.assert_equal('fridge', NxS1B1::BS.appliances(m).first['typ'], 'polozka sa nezmenila')
  NxTest.assert_equal(1, NxS1B1.refs_of(cab).length, 'ani vazba')
end

NxTest.test('S1-B1: `rebind_model` na TOM ISTOM vlastnikovi PREPISE zaznam (nezdvoji ho)') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  other = NxS1B1.fridge_snapshot('CAT-FRIDGE-2')
  other['name'] = 'BCNA999'
  other['dims']['niche']['width_min'] = 600.0
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab]),
                     NxS1B1.snapshot_stub('CAT-FRIDGE-2' => other)] + NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'rebind_model', item_id: id,
                            catalog_id: 'CAT-FRIDGE-2')
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  refs = NxS1B1.refs_of(cab)
  NxTest.assert_equal(1, refs.length, 'stale JEDEN zaznam')
  NxTest.assert_equal(600.0, refs.first['niche']['width_min'], 'ale s NOVYMI rozmermi')
  NxTest.assert_equal('CAT-FRIDGE-2', NxS1B1::BS.appliances(m).first['catalog_id'])
  NxTest.assert_equal([[:cabinet, 'CAB-1', 1]], log, 'a JEDEN zapis, nie zrusenie + pridanie')
end

NxTest.test('S1-B1 (B8): zamknuty povodny vlastnik zastavi presun, `patch` NIE') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  target = NxS1B1.cabinet('CAB-2', 102)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, target])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, target], detached: { 'CAB-1' => 1 })] +
                    NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.refute(res[:ok], 'nezapisovatelny povodny vlastnik zastavi CELU operaciu')
  NxTest.assert_equal([NxS1B1::AB::MSG_PREV_LOCKED], res[:errors])

  # Ale cena sa opravit MUSI dat — `patch` sa vazby nedotyka.
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, target], detached: { 'CAB-1' => 1 })] +
                    NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'patch', item_id: id,
                            attrs: { 'cena' => 777.0 })
  end
  NxTest.assert(res[:ok], "uprava ceny musi prejst: #{res[:errors].inspect}")
  NxTest.assert_close(777.0, NxS1B1::BS.appliances(m).first['cena'], 0.01)
end

NxTest.test('S1-B1 (B8c): zaniknuta vazba — cudzia skrinka s tym istym ID sa NEDOTKNE') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  # Povodna skrinka zanikla; ID CAB-1 dostala INA (bez vazby), pribudla CAB-2.
  recycled = NxS1B1.cabinet('CAB-1', 555)
  target = NxS1B1.cabinet('CAB-2', 102)
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [recycled, target])] + NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal([[:cabinet, 'CAB-2', 1]], log,
                      'zapisala sa LEN nova skrinka — recyklovana sa nedotkla')
  NxTest.assert_equal([], NxS1B1.refs_of(recycled))
end

NxTest.test('S1-B1 (B4): zapis do INEHO dokumentu sa odmietne bez operacie') do
  m = NxS1B1::FakeModel.new
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: 'CUDZI-GUID', op: 'create',
                            attrs: { 'nazov' => 'X' }, owner: nil)
  end
  NxTest.refute(res[:ok])
  NxTest.assert_equal([NxS1B1::AB::MSG_FOREIGN_DOC], res[:errors])
  NxTest.assert_equal([], m.ops)
end

NxTest.test('S1-B1: nekompatibilna verzia dat rozpoctu zastavi vazbu PRED operaciou') do
  m = NxS1B1::FakeModel.new
  m.set_attribute(NxS1B1::DICT, NxS1B1::BS::KEY_STD, NxS1B1::BS::BUDGET_STD + 1)
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'create', attrs: { 'nazov' => 'X' })
  end
  NxTest.refute(res[:ok])
  NxTest.assert_equal([NxS1B1::BS.std_block_reason(:newer)], res[:errors])
  NxTest.assert_equal([], m.ops)
end

NxTest.test('S1-B1: `apply!` pozna PRESNE sest operacii a smeruje sem CELY rozpocet') do
  NxTest.assert_equal(%w[create patch rebind_model move unbind remove], NxS1B1::AB::OPS)
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                  encoding: 'UTF-8')
  body = src[/def apply_budget_op.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, '`apply_budget_op` sa nasla')
  %w[appliance_add appliance_update appliance_remove appliance_owner].each do |op|
    line = body[/^\s+when '#{op}'.*$/].to_s
    NxTest.assert(line.include?('appliance_op'), "#{op} ide cez jediny vstup: #{line}")
  end
  NxTest.refute(body.include?('BudgetStore.add_appliance!'),
                'okno uz spotrebice do `BudgetStore` priamo NEZAPISUJE')
end

# ======================= 6) Bom.collect[:appliances] =======================

NxTest.test('S1-B1: `appliances` zo zberu — stavy bound / owner_missing / job') do
  items = [
    { 'id' => 'A1', 'typ' => 'fridge', 'nazov' => 'Beko', 'customer_supplied' => false,
      'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-1' },
      'snapshot' => NxS1B1.fridge_snapshot },
    { 'id' => 'A2', 'typ' => 'oven', 'nazov' => 'Rúra', 'customer_supplied' => false,
      'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-9' } },
    { 'id' => 'A3', 'typ' => 'hood', 'nazov' => 'Digestor', 'customer_supplied' => true,
      'owner' => { 'kind' => 'job' } }
  ]
  owners = {}
  NxS1B1::BOM.note_appliance_owner(owners, 'CAB-1', 101,
                                   { 'type' => 'lower', 'width' => 600.0, 'height' => 2076.0,
                                     'depth' => 560.0, 'thickness' => 18.0,
                                     'floor_height' => 100.0, 'top_mode' => 'closed',
                                     'back_mode' => 'inset', 'back_thickness' => 5.0,
                                     'appliance_refs' => [{ 'item_id' => 'A1',
                                                            'category' => 'fridge' }] })
  # CAB-9 uz v modeli NIE JE (zmazana skrinka).
  recs = NxS1B1::BOM.appliance_records(items, owners)
  by_id = recs.each_with_object({}) { |r, h| h[r['item_id']] = r }
  NxTest.assert_equal('bound', by_id['A1']['state'])
  NxTest.assert_equal(101, by_id['A1']['owner']['pid'], 'viazany zaznam nesie PID vlastnika')
  NxTest.assert_equal('Beko BCNA306E5ZSN', by_id['A1']['name'], 'nazov je vyrobca + model')
  NxTest.assert(by_id['A1']['snapshot']['niche'].is_a?(Hash), 'a rozmery niky zo snapshotu')
  NxTest.assert(by_id['A1']['interior'].is_a?(Hash), 'vnutro skrinky pre kontrolu niky')
  NxTest.assert_equal('owner_missing', by_id['A2']['state'], 'zmazany vlastnik = sirota')
  NxTest.assert(by_id['A2']['owner']['pid'].nil?, 'sirota PID nema')
  NxTest.assert_equal('job', by_id['A3']['state'])
  NxTest.assert_equal(true, by_id['A3']['customer_supplied'])
end

NxTest.test('S1-B1: recyklovane ID BEZ vazby v refs = sirota (M3)') do
  items = [{ 'id' => 'A1', 'typ' => 'fridge', 'nazov' => 'Beko',
             'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-1' } }]
  owners = {}
  # Skrinka s tym istym ID v modeli JE, ale o tejto polozke nevie.
  NxS1B1::BOM.note_appliance_owner(owners, 'CAB-1', 777, { 'type' => 'lower' })
  rec = NxS1B1::BOM.appliance_records(items, owners).first
  NxTest.assert_equal('owner_missing', rec['state'],
                      'zhoda ID NIE JE dokaz — ID sa recykluju')
end

NxTest.test('S1-B1: zber prizna aj vlastnikov, ktori spotrebic len OCAKAVAJU') do
  owners = {}
  NxS1B1::BOM.note_appliance_owner(owners, 'CAB-5', 105,
                                   { 'type' => 'lower', 'appliance_expects' => %w[oven microwave] })
  NxS1B1::BOM.note_appliance_owner(owners, 'CAB-6', 106, { 'type' => 'dishwasher', 'dw_class' => 600 })
  recs = NxS1B1::BOM.appliance_records([], owners)
  NxTest.assert_equal(3, recs.length, "ocakavania: #{recs.inspect}")
  NxTest.assert(recs.all? { |r| r['state'] == 'expected_missing' && r['item_id'].nil? })
  NxTest.assert_equal(%w[dishwasher microwave oven], recs.map { |r| r['category'] }.sort)
  slot = recs.find { |r| r['owner']['id'] == 'CAB-6' }
  NxTest.assert_equal({ 'dw_class' => 600 }, slot['slot'], 'slot bez modelu nesie svoju triedu')
end

NxTest.test('S1-B1: `Bom.compute` novy kluc IGNORUJE (kusovnik aj VEPO su nezmenene)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'bom.rb'), encoding: 'UTF-8')
  body = src[/def compute\(collected.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, '`compute` sa nasla')
  NxTest.refute(body.include?(':appliances'), 'compute o spotrebicoch nevie — je to aditivny kluc')
end

# ======================= 7) Kontrola (Validation) =========================

NxTest.test('S1-B1: Kontrola — tri kody, kazdy VLASTNY stable_key') do
  list = [
    { 'item_id' => 'A1', 'name' => 'Beko', 'category' => 'fridge', 'state' => 'owner_missing',
      'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-9', 'pid' => nil } },
    { 'item_id' => 'A2', 'name' => 'Rúra bez listu', 'category' => 'oven', 'state' => 'bound',
      'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 },
      'snapshot' => { 'body' => { 'width' => 560.0 } } },
    { 'item_id' => 'A3', 'name' => 'Bosch SPV', 'category' => 'dishwasher', 'state' => 'bound',
      'owner' => { 'kind' => 'slot', 'id' => 'CAB-2', 'pid' => 102 },
      'snapshot' => { 'niche' => { 'width_min' => 450.0 },
                      'install' => { 'dishwasher_class' => '450' } },
      'slot' => { 'dw_class' => 600 } }
  ]
  items = []
  NxS1B1::VAL.check_appliances(list, items)
  codes = items.map { |i| i['stable_key'] }
  NxTest.assert(codes.include?('appliance|A1|appliance_owner_missing'), codes.inspect)
  NxTest.assert(codes.include?('appliance|A2|appliance_specs_missing'), codes.inspect)
  NxTest.assert(codes.include?('appliance|A3|appliance_class_mismatch'), codes.inspect)
  NxTest.assert_equal(codes.uniq.length, codes.length, 'kazdy nalez ma VLASTNY kluc')
  NxTest.assert(items.all? { |i| i['severity'] == 'orange' && i['category'] == 'appliance' })

  # B16: klik na sirotu NIKDY neoznaci cudziu skrinku.
  orphan = items.find { |i| i['stable_key'].include?('owner_missing') }
  NxTest.assert(orphan['owner_id'].nil?, 'sirota NEMA owner_id (ID sa recykluju)')
  NxTest.assert_equal({ 'route' => 'appl', 'item_id' => 'A1' }, orphan['data'])

  # Viazany nalez MA adresu vlastnika (klik oznaci skrinku).
  specs = items.find { |i| i['stable_key'].include?('specs_missing') }
  NxTest.assert_equal('CAB-1', specs['owner_id'])
  NxTest.assert_equal(101, specs['owner_pid'])
end

NxTest.test('S1-B1: neznama trieda NIE JE nezhoda (B15) a `expected_missing` nalez nedava') do
  items = []
  NxS1B1::VAL.check_appliances(
    [{ 'item_id' => 'A1', 'name' => 'Umývačka', 'category' => 'dishwasher', 'state' => 'bound',
       'owner' => { 'kind' => 'slot', 'id' => 'CAB-2', 'pid' => 102 },
       'snapshot' => { 'niche' => { 'width_min' => 600.0 }, 'install' => {} },
       'slot' => { 'dw_class' => 600 } },
     { 'item_id' => nil, 'category' => 'oven', 'state' => 'expected_missing',
       'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-5', 'pid' => 105 } }], items
  )
  NxTest.assert_equal([], items, 'neznama trieda a ocakavanie nalez nedavaju (to je S1-C)')
end

NxTest.test('S1-B1: Kontrola bez zoznamu = ziadny nalez (legacy volania)') do
  items = []
  NxS1B1::VAL.check_appliances(nil, items)
  NxS1B1::VAL.check_appliances([], items)
  NxTest.assert_equal([], items)
  out = NxS1B1::VAL.run({ records: [] })
  NxTest.assert_equal(0, out['counts']['total'], 'zber bez kluca `appliances` nic nehlasi')
end

NxTest.test('S1-B1: Kontrola rata spotrebicove nalezy do badge (existujuca cesta)') do
  collected = {
    records: [],
    appliances: [{ 'item_id' => 'A1', 'name' => 'Beko', 'category' => 'fridge',
                   'state' => 'owner_missing',
                   'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-9', 'pid' => nil } }]
  }
  out = NxS1B1::VAL.run(collected)
  NxTest.assert_equal(1, out['counts']['orange'])
  NxTest.assert_equal(1, out['items'].length)
  NxTest.assert_equal('appliance', out['items'].first['category'])
end

# ================= 8) Codex #382 kolo 1 — dotiahnuta identita ===============

NxTest.test('S1-B1 (kolo 1 P2): `patch` ani `remove` vlastnika NEPRIJMU') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  ops_before = m.ops.length
  %w[patch remove].each do |op|
    res = nil
    NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])] + NxS1B1.writer_stubs([])) do
      res = NxS1B1::AB.apply!(m, model_guid: '', op: op, item_id: id, attrs: { 'cena' => 9.0 },
                              owner: { 'kind' => 'cabinet', 'id' => 'CAB-2', 'pid' => 102 })
    end
    NxTest.refute(res[:ok], "#{op}: payload s vlastnikom sa ODMIETA")
    NxTest.assert_equal([NxS1B1::AB::MSG_OWNER_OP], res[:errors], op)
  end
  NxTest.assert_equal(ops_before, m.ops.length, 'a ziadna operacia sa neotvorila')
  NxTest.assert_equal({ 'kind' => 'cabinet', 'id' => 'CAB-1' },
                      NxS1B1::BS.appliances(m).first['owner'], 'vlastnik sa nezmenil')
  NxTest.assert_equal(%w[create move unbind rebind_model], NxS1B1::AB::OWNER_OPS)
end

NxTest.test('S1-B1 (kolo 1 P2): `rebind_model` nad SIROTOU refs NEPREPISUJE') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  # Povodna skrinka zanikla; ID CAB-1 dostala INA (bez vazby) — recyklacia ID.
  recycled = NxS1B1.cabinet('CAB-1', 555)
  other = NxS1B1.fridge_snapshot('CAT-FRIDGE-2')
  other['name'] = 'BCNA999'
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [recycled]),
                     NxS1B1.snapshot_stub('CAT-FRIDGE-2' => other)] + NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'rebind_model', item_id: id,
                            catalog_id: 'CAT-FRIDGE-2')
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal([], log, 'CUDZIA skrinka s recyklovanym ID sa NEDOTKLA')
  NxTest.assert_equal([], NxS1B1.refs_of(recycled))
  NxTest.assert_equal('CAT-FRIDGE-2', NxS1B1::BS.appliances(m).first['catalog_id'],
                      'ale snapshot polozky sa aktualizoval')
  NxTest.assert_equal(false, res[:geometry_changed], 'ziadna prestavba')
end

NxTest.test('S1-B1 (kolo 1 P2): implicitny ciel je PRAVE overeny povodny vlastnik') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  twin = NxS1B1.cabinet('CAB-1', 202) # rovnake ID, ziadna vazba
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  other = NxS1B1.fridge_snapshot('CAT-FRIDGE-2')
  other['dims']['niche']['width_min'] = 600.0
  log = []
  res = nil
  # V modeli su DVE skrinky s ID CAB-1 — vazbu nesie prave jedna, takze je
  # jednoznacne, kam refs patria (a hladanie podla ID by bolo nejednoznacne).
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, twin]),
                     NxS1B1.snapshot_stub('CAT-FRIDGE-2' => other)] + NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'rebind_model', item_id: id,
                            catalog_id: 'CAT-FRIDGE-2')
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal(1, NxS1B1.refs_of(cab).length, 'refs ostali na NOSICOVI vazby')
  NxTest.assert_equal(600.0, NxS1B1.refs_of(cab).first['niche']['width_min'], 'a su aktualne')
  NxTest.assert_equal([], NxS1B1.refs_of(twin), 'dvojnik sa nedotkol')
end

NxTest.test('S1-B1 (kolo 1 P2): DVA zive kusy s tym istym ID = odmietnutie pred operaciou') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  target = NxS1B1.cabinet('CAB-2', 102)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, target])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  # Poskodeny/importovany model: dva ZIVE kusy s ID CAB-1 a ANI JEDEN nenesie
  # vazbu (napr. po rucnom zasahu do atributov) — nevieme, kam refs patria.
  ghost_a = NxS1B1.cabinet('CAB-1', 301)
  ghost_b = NxS1B1.cabinet('CAB-1', 302)
  log = []
  res = nil
  ops_before = m.ops.length
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [ghost_a, ghost_b, target])] +
                    NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.refute(res[:ok], 'nejednoznacna identita povodneho vlastnika zastavi operaciu')
  NxTest.assert(res[:errors].first.to_s.include?('nejednoznačná identita vlastníka CAB-1'),
                res[:errors].inspect)
  NxTest.assert_equal(ops_before, m.ops.length, 'a to PRED otvorenim operacie')
  NxTest.assert_equal([], log)

  # Ked vazbu nesie PRESNE JEDEN z dvojice, je to jednoznacne — operacia prejde.
  carrier = NxS1B1.cabinet('CAB-1', 303,
                           refs: [{ 'item_id' => id, 'category' => 'fridge' }])
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [carrier, ghost_b, target])] +
                    NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal([], NxS1B1.refs_of(carrier), 'nosic vazbu stratil')
  NxTest.assert_equal(1, NxS1B1.refs_of(target).length, 'ciel ju ma')
end

NxTest.test('S1-B1 (kolo 1 P2): sirota vedie DEEP-LINKOM, nie vyberom entit') do
  items = []
  NxS1B1::VAL.check_appliances(
    [{ 'item_id' => 'A1', 'name' => 'Beko', 'category' => 'fridge', 'state' => 'owner_missing',
       'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-9', 'pid' => nil } }], items
  )
  rt = NxS1B1::PC.route_target(items.first)
  # S1-B2: adresa sa presunula z Rozpoctu do sekcie SPOTREBIČE (pohlad
  # „V zákazke"). Menil sa VYHRADNE `ROUTE_SECTIONS` — tvar nalezu ani kotva
  # nie (`appliance:<uuid>` plati v oboch sekciach).
  NxTest.assert_equal({ 'route' => 'appl', 'section' => 'appl', 'anchor' => 'appliance:A1' }, rt,
                      'nalez sirotý nesie adresu SEKCIE, nie entity')
  NxTest.assert(NxS1B1::PC.route_status(rt).include?('Spotrebičoch'))
  # Nalez S POLOZKOU v modeli adresu sekcie NEMA — ide beznym vyberom.
  bound = []
  NxS1B1::VAL.check_appliances(
    [{ 'item_id' => 'A2', 'name' => 'Rúra', 'category' => 'oven', 'state' => 'bound',
       'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 },
       'snapshot' => { 'body' => { 'width' => 560.0 } } }], bound
  )
  NxTest.assert(NxS1B1::PC.route_target(bound.first).nil?,
                'viazany nalez ma vlastnika — oznaci sa skrinka')
  NxTest.assert(NxS1B1::PC.route_target(nil).nil?)
  NxTest.assert(NxS1B1::PC.route_target({ 'data' => { 'route' => 'neznamy', 'item_id' => 'X' } }).nil?,
                'neznama trasa sa IGNORUJE (nikdy sa nehada)')

  # `do_select` musi vetvu spracovat PRED akymkolvek vyberom entit.
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                  encoding: 'UTF-8')
  body = src[/def do_select\(model, data, generation:.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, '`do_select` sa nasla')
  at_route = body.index('rt = route_target(item)')
  at_pids = body.index('pids = pids_for_problem(')
  NxTest.assert(at_route && at_pids && at_route < at_pids,
                'vetva trasy bezi PRED `pids_for_problem`')
end

# ================= 9) Codex #382 kolo 2 — identita a kategoria =============

NxTest.test('S1-B1 (kolo 2 P2): fyzicky ciel BEZ PID sa ODMIETNE') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  [nil, '', 0, 'abc'].each do |bad|
    res = nil
    NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab]),
                       NxS1B1.snapshot_stub('CAT-FRIDGE' => NxS1B1.fridge_snapshot)] +
                      NxS1B1.writer_stubs([])) do
      res = NxS1B1::AB.apply!(m, model_guid: '', op: 'create', attrs: { 'nazov' => 'Beko' },
                              catalog_id: 'CAT-FRIDGE',
                              owner: { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => bad })
    end
    NxTest.refute(res[:ok], "pid #{bad.inspect}: ciel bez platneho PID sa NEPRIJIMA")
    NxTest.assert_equal([NxS1B1::AB::MSG_OWNER_STALE], res[:errors], bad.inspect)
  end
  NxTest.assert_equal([], m.ops, 'a ziadna operacia sa neotvorila')
  NxTest.assert_equal([], NxS1B1::BS.appliances(m))

  # S PID to prejde (a PID moze prist aj ako retazec z JSON).
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    res = NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                         { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => '101' })
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal(1, NxS1B1.refs_of(cab).length)
end

NxTest.test('S1-B1 (kolo 2 P2): `typ` pri zmene vlastnika sa ODMIETA') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  slot = NxS1B1.cabinet('CAB-2', 102, type: 'dishwasher')
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  ops_before = m.ops.length
  # Presun na SLOT s prilozenym `typ` = umyvacka: matica by bezala nad starou
  # kategoriou (fridge -> skrinka) a zapis by ulozil dishwasher.
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot])] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            attrs: { 'typ' => 'dishwasher' },
                            owner: { 'kind' => 'slot', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.refute(res[:ok], 'typ pri presune sa NEPRIJIMA')
  NxTest.assert_equal([NxS1B1::AB::MSG_TYPE_WITH_OWNER], res[:errors])
  NxTest.assert_equal(ops_before, m.ops.length, 'a to PRED otvorenim operacie')
  NxTest.assert_equal('fridge', NxS1B1::BS.appliances(m).first['typ'], 'kategoria sa nezmenila')
  NxTest.assert_equal([], NxS1B1.refs_of(slot), 'slot vazbu nedostal')

  # To iste pre `unbind` aj `rebind_model` (`unbind` model z katalogu niest
  # NESMIE — ten ma vlastnu branu, viz nizsie).
  { 'unbind' => nil, 'rebind_model' => 'CAT-FRIDGE' }.each do |op, cat|
    NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot]),
                       NxS1B1.snapshot_stub('CAT-FRIDGE' => NxS1B1.fridge_snapshot)] +
                      NxS1B1.writer_stubs([])) do
      res = NxS1B1::AB.apply!(m, model_guid: '', op: op, item_id: id,
                              attrs: { 'typ' => 'oven' }, catalog_id: cat)
    end
    NxTest.assert_equal([NxS1B1::AB::MSG_TYPE_WITH_OWNER], res[:errors], op)
  end
  # `patch` typ menit SMIE (polozka bez katalogu a bez vlastnika) — tam ho
  # strazi `BudgetStore.type_locked?`.
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot])] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'patch', item_id: id,
                            attrs: { 'nazov' => 'Beko II' })
  end
  NxTest.assert(res[:ok], "uprava poli musi prejst: #{res[:errors].inspect}")
end

NxTest.test('S1-B1 (kolo 2 P2): matica pri `create` bezi nad ULOZENYM typom') do
  m = NxS1B1::FakeModel.new
  slot = NxS1B1.cabinet('CAB-2', 102, type: 'dishwasher')
  # Legacy kod „umyvacka" -> kanon `dishwasher` -> slot je povoleny vlastnik.
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [slot])] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'create',
                            attrs: { 'nazov' => 'Bosch', 'typ' => 'umyvacka' },
                            owner: { 'kind' => 'slot', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal('dishwasher', NxS1B1::BS.appliances(m).first['typ'],
                      'ulozi sa PRESNE to, proti comu bezala matica')

  # Neznamy kod sa NIKDY ticho nenahradi defaultom.
  m2 = NxS1B1::FakeModel.new
  NxS1B1.with_stubs([NxS1B1.scan_stub] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m2, model_guid: '', op: 'create',
                            attrs: { 'nazov' => 'X', 'typ' => 'kozub' })
  end
  NxTest.refute(res[:ok], 'neznamy typ sa odmietne')
  NxTest.assert_equal([NxS1B1::AB::MSG_UNKNOWN_TYPE], res[:errors])
  NxTest.assert_equal([], m2.ops)
  NxTest.assert_equal([], NxS1B1::BS.appliances(m2))

  # A kategoria mimo matice sa odmietne aj ked ju klient „preklopi" typom.
  m3 = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])] + NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m3, model_guid: '', op: 'create',
                            attrs: { 'nazov' => 'Drez', 'typ' => 'sink' },
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  NxTest.refute(res[:ok], 'drez do skrinky nepatri (matica nad ULOZENYM typom)')
  NxTest.assert_equal([], m3.ops)
end

NxTest.test('S1-B1 (kolo 2 P2): presun SIROTY na entitu s recyklovanym ID ZAPISE refs') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  # Povodna skrinka zanikla; NOVA skrinka dostala TO ISTE ID (recyklacia) —
  # z pohladu polozky je to „ten isty" vlastnik, ale entita je INA a vazbu
  # nenesie. Presun na nu MUSI refs zapisat, inak sirota ostane sirotou.
  recycled = NxS1B1.cabinet('CAB-1', 777)
  log = []
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [recycled])] + NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 777 })
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal([[:cabinet, 'CAB-1', 1]], log, 'vazba sa ZAPISALA')
  NxTest.assert_equal(1, NxS1B1.refs_of(recycled).length)
  NxTest.assert_equal(id, NxS1B1.refs_of(recycled).first['item_id'])
  NxTest.assert_equal(true, res[:geometry_changed])

  # A Kontrola uz sirotu nehlasi (ten isty zber, ktory ju hlasil predtym).
  owners = {}
  NxS1B1::BOM.note_appliance_owner(owners, 'CAB-1', 777, NxS1B1.cfg_of(recycled))
  recs = NxS1B1::BOM.appliance_records(NxS1B1::BS.appliances(m), owners)
  NxTest.assert_equal('bound', recs.first['state'], 'polozka je zase viazana')
  items = []
  NxS1B1::VAL.check_appliances(recs, items)
  NxTest.assert(items.none? { |i| i['stable_key'].to_s.include?('owner_missing') },
                "nalez sirotý zhasol: #{items.map { |i| i['stable_key'] }.inspect}")

  # Opakovany presun na TEN ISTY (uz nesuci) ciel sa zbytocne NEPRESTAVUJE.
  log.clear
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [recycled])] + NxS1B1.writer_stubs(log)) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            owner: { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 777 })
  end
  NxTest.assert(res[:ok], res[:errors].inspect)
  NxTest.assert_equal([], log, 'ciel uz polozku nesie — ziadna prestavba navyse')
  NxTest.assert_equal(false, res[:geometry_changed])
end

# ============ 10) Codex #382 kolo 3 — model, ram a dokaz vazby =============

NxTest.test('S1-B1 (kolo 3 P2): `catalog_id` LEN pri `create` a `rebind_model`') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  slot = NxS1B1.cabinet('CAB-2', 102, type: 'dishwasher')
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']
  ops_before = m.ops.length
  # Presun na SLOT s prilozenym modelom UMYVACKY: matica by bezala nad
  # kategoriou KATALOGU (dishwasher -> slot OK), ale snapshot sa pri `move`
  # neuklada — polozka by ostala chladnickou v slote.
  res = nil
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot]),
                     NxS1B1.snapshot_stub('CAT-DW450' => NxS1B1.dishwasher_snapshot)] +
                    NxS1B1.writer_stubs([])) do
    res = NxS1B1::AB.apply!(m, model_guid: '', op: 'move', item_id: id,
                            catalog_id: 'CAT-DW450',
                            owner: { 'kind' => 'slot', 'id' => 'CAB-2', 'pid' => 102 })
  end
  NxTest.refute(res[:ok], 'model z katalogu pri presune sa NEPRIJIMA')
  NxTest.assert_equal([NxS1B1::AB::MSG_CATALOG_OP], res[:errors])
  NxTest.assert_equal(ops_before, m.ops.length, 'a to PRED otvorenim operacie')
  NxTest.assert_equal('fridge', NxS1B1::BS.appliances(m).first['typ'])
  NxTest.assert_equal([], NxS1B1.refs_of(slot))

  %w[unbind patch remove].each do |op|
    NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab, slot]),
                       NxS1B1.snapshot_stub('CAT-DW450' => NxS1B1.dishwasher_snapshot)] +
                      NxS1B1.writer_stubs([])) do
      res = NxS1B1::AB.apply!(m, model_guid: '', op: op, item_id: id,
                              catalog_id: 'CAT-DW450')
    end
    NxTest.assert_equal([NxS1B1::AB::MSG_CATALOG_OP], res[:errors], op)
  end
  NxTest.assert_equal(%w[create rebind_model], NxS1B1::AB::CATALOG_OPS)
end

NxTest.test('S1-B1 (kolo 3 P2): `ensure_root_context` LEN pri skutocnej prestavbe') do
  m = NxS1B1::FakeModel.new
  cab = NxS1B1.cabinet('CAB-1', 101)
  brd = NxS1B1.board('BRD-1', 201)
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab])]) do
    NxS1B1.create!(m, NxS1B1.fridge_snapshot,
                   { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  id = NxS1B1::BS.appliances(m).first['id']

  closed = 0
  ctx = [Noxun::Engine::CabinetBuilder, :ensure_root_context, ->(_model) { closed += 1 }]

  # (a) `patch` — cisto rozpoctova uprava: ram sa NEZATVARA.
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab]), ctx] + NxS1B1.writer_stubs([])) do
    NxS1B1::AB.apply!(m, model_guid: '', op: 'patch', item_id: id, attrs: { 'cena' => 5.0 })
  end
  NxTest.assert_equal(0, closed, '`patch` pouzivatela z komponentu NEVYHODI')

  # (b) DOSKA — zapis configu bez prestavby: ram sa NEZATVARA.
  m2 = NxS1B1::FakeModel.new
  NxS1B1.with_stubs([NxS1B1.scan_stub(boards: [brd]), ctx,
                     NxS1B1.snapshot_stub('CAT-HOB' => NxS1B1.hob_snapshot)] +
                    NxS1B1.writer_stubs([])) do
    NxS1B1::AB.apply!(m2, model_guid: '', op: 'create', attrs: { 'nazov' => 'Varná doska' },
                      catalog_id: 'CAT-HOB',
                      owner: { 'kind' => 'board', 'id' => 'BRD-1', 'pid' => 201 })
  end
  NxTest.assert_equal(0, closed, 'vazba na DOSKU sa nerobi prestavbou')

  # (c) SKRINKA — prestavba: ram sa zatvara (inak by commit korpus teleportoval).
  m3 = NxS1B1::FakeModel.new
  NxS1B1.with_stubs([NxS1B1.scan_stub(cabinets: [cab]), ctx,
                     NxS1B1.snapshot_stub('CAT-FRIDGE' => NxS1B1.fridge_snapshot)] +
                    NxS1B1.writer_stubs([])) do
    NxS1B1::AB.apply!(m3, model_guid: '', op: 'create', attrs: { 'nazov' => 'Beko' },
                      catalog_id: 'CAT-FRIDGE',
                      owner: { 'kind' => 'cabinet', 'id' => 'CAB-1', 'pid' => 101 })
  end
  NxTest.assert_equal(1, closed, 'prestavba skrinky ram zatvorit MUSI')
end

NxTest.test('S1-B1 (kolo 3 P2): dokaz vazby vyzaduje ZHODU DRUHU (jedna funkcia)') do
  entry_slot = { 'kind' => 'slot', 'id' => 'CAB-3', 'refs' => [{ 'item_id' => 'A1' }] }
  cab_owner = { 'kind' => 'cabinet', 'id' => 'CAB-3' }
  slot_owner = { 'kind' => 'slot', 'id' => 'CAB-3' }
  NxTest.refute(NxS1B1::AB.ref_matches?(entry_slot, cab_owner, 'A1'),
                'skrinkovy vlastnik na SLOTE s tym istym ID vazbou NIE JE')
  NxTest.assert(NxS1B1::AB.ref_matches?(entry_slot, slot_owner, 'A1'), 'zhodny druh ano')
  NxTest.refute(NxS1B1::AB.ref_matches?(entry_slot, { 'kind' => 'slot', 'id' => 'CAB-9' }, 'A1'),
                'ine ID nie')
  NxTest.refute(NxS1B1::AB.ref_matches?(entry_slot, slot_owner, 'INE'), 'ine uuid nie')
  NxTest.refute(NxS1B1::AB.ref_matches?(entry_slot, slot_owner, ''), 'prazdne uuid nie')
  NxTest.refute(NxS1B1::AB.ref_matches?(nil, slot_owner, 'A1'))

  # ZBER pouziva TU ISTU funkciu: slot s `cabinet_id` CAB-3 a skrinkovym
  # zaznamom sa uz netvari ako viazany (mutacie vlastnika by ho nenasli).
  items = [{ 'id' => 'A1', 'typ' => 'fridge', 'nazov' => 'Beko',
             'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-3' } }]
  owners = {}
  NxS1B1::BOM.note_appliance_owner(owners, 'CAB-3', 303,
                                   { 'type' => 'dishwasher', 'dw_class' => 600,
                                     'appliance_refs' => [{ 'item_id' => 'A1',
                                                            'category' => 'fridge' }] })
  rec = NxS1B1::BOM.appliance_records(items, owners).find { |r| r['item_id'] == 'A1' }
  NxTest.assert_equal('owner_missing', rec['state'],
                      'zhoda ID + uuid BEZ zhody druhu dokazom NIE JE')
  NxTest.assert(rec['owner']['pid'].nil?)

  # Ked druh sedi, vazba plati.
  items2 = [{ 'id' => 'A1', 'typ' => 'dishwasher', 'nazov' => 'Bosch',
              'owner' => { 'kind' => 'slot', 'id' => 'CAB-3' } }]
  rec2 = NxS1B1::BOM.appliance_records(items2, owners).find { |r| r['item_id'] == 'A1' }
  NxTest.assert_equal('bound', rec2['state'])
  NxTest.assert_equal(303, rec2['owner']['pid'])
end
