# frozen_string_literal: true
# S1-B2 — SPOTREBIC V ZAKAZKE: POHLAD „V ZAKAZKE", RIADOK SPOTREBIC, TELO SLOTU.
#
# CO BOLO ZLE: vazba (S1-B1) existovala, ale nebolo ju kde VIDIET. Sekcia
# Spotrebice mala druhy pohlad priznany ako placeholder, Inspector o spotrebici
# mlcal a slot umyvacky kreslil GENERICKE telo aj vtedy, ked uz mal priradeny
# konkretny model.
#
# CO PLATI TERAZ:
#   * pohlad „V zákazke" sklada SERVER (`ApplianceDialog.job_view`) ako
#     PROJEKCIU uz hotoveho zberu, rozpoctu a kontroly — poradie, tony, ceny
#     aj akcie su serverove, klient nic nepreskladava,
#   * Inspector ma riadok „Spotrebič" (`Panel.appliance_rows`) — jeden per
#     viazany model + jeden per nesplnene ocakavanie; ponuka je filtrovana
#     podla niky LEN po osiach, ktore kategoria kontroluje, a filter NIE JE
#     brana,
#   * telo slotu ma JEDNU autoritu (`Construction.dw_body_dims`) pre builder,
#     Inspector aj Kontrolu — s vazbou je z katalogu, bez nej genericke.
#
# MUTACIE, ktore tato sada chyta:
#   M1 filter niky ignoruje osi kategorie (rura filtruje aj vysku) -> padne
#      „rura sa filtruje LEN po Š + H",
#   M2 telo slotu ignoruje `body` vazby -> padne „telo slotu je z katalogu",
#   M3 tabulka „V zákazke" sa rada na klientovi -> padne „poradie sklada server".
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'appliance_catalog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_appliance')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'appliance_dialog')
end

module NxS1B2
  module_function

  AD = Noxun::Engine::ApplianceDialog
  PANEL = Noxun::Engine::Panel
  BS = Noxun::Engine::BudgetStore
  VAL = Noxun::Engine::Validation
  CON = Noxun::Engine::Construction
  BOM = Noxun::Engine::Bom
  STORE = Noxun::Engine::Store

  # --- fixtury polozek zakazky ------------------------------------------------

  def snapshot(category, name, manufacturer, dims)
    { 'catalog_id' => "CAT-#{name}", 'category' => category, 'manufacturer' => manufacturer,
      'name' => name, 'dims' => dims, 'shop_urls' => ['https://obchod.sk/x'],
      'sheet_urls' => ['https://vyrobca.sk/list.pdf'],
      'snapshot_at' => '2026-09-20T10:00:00Z' }
  end

  def fridge_dims
    { 'body' => { 'width' => 540.0, 'height' => 1935.0, 'depth' => 545.0 },
      'niche' => { 'width_min' => 560.0, 'height_min' => 1940.0, 'height_max' => 1950.0,
                   'depth_min' => 555.0 } }
  end

  def oven_dims(depth_min = 560.0)
    { 'body' => { 'width' => 548.0, 'height' => 570.0, 'depth' => 558.0 },
      'niche' => { 'width_min' => 560.0, 'width_max' => 568.0, 'height_min' => 583.0,
                   'height_max' => 585.0, 'depth_min' => depth_min } }
  end

  def dw_dims(cls = '450')
    { 'body' => { 'width' => 448.0, 'depth' => 550.0 },
      'niche' => { 'width_min' => 450.0, 'height_min' => 815.0 },
      'install' => { 'dishwasher_class' => cls, 'body_height_min' => 815.0,
                     'body_height_max' => 875.0 } }
  end

  def item(id, typ, owner, extra = {})
    { 'id' => id, 'typ' => typ, 'nazov' => id, 'cena' => 100.0,
      'owner' => owner, 'cp_skupina' => 'zostava' }.merge(extra)
  end

  def owner(kind, id)
    { 'kind' => kind, 'id' => id }
  end

  # --- fixtury pre pohlad „V zakazke" ----------------------------------------

  def record(state, category, own, extra = {})
    { 'item_id' => extra['item_id'], 'name' => extra['name'], 'category' => category,
      'owner' => own, 'state' => state, 'customer_supplied' => extra['customer_supplied'] == true,
      'snapshot' => extra['snapshot'], 'slot' => nil, 'interior' => nil }
  end

  def budget_payload(rows, owners)
    { 'sections' => [{ 'key' => 'appliances', 'rows' => rows }],
      'totals' => { 'appliances_subtotal' => 1234.5, 'appliances_included' => false },
      'appliance_owners' => owners }
  end

  def owners_map
    { 'matrix' => {}, 'job_label' => 'len zákazka (bez väzby)',
      'options' => {
        'cabinet' => [{ 'kind' => 'cabinet', 'id' => 'CAB-3', 'pid' => 11,
                        'label' => 'CAB-3 · Chladničková skriňa' },
                      { 'kind' => 'cabinet', 'id' => 'CAB-9', 'pid' => 12,
                        'label' => 'CAB-9 · Vysoká skriňa' }],
        'slot' => [{ 'kind' => 'slot', 'id' => 'CAB-7', 'pid' => 13, 'label' => 'CAB-7 · Umývačka 60' }],
        'board' => [{ 'kind' => 'board', 'id' => 'BRD-2', 'pid' => 14, 'label' => 'BRD-2 · Pracovná doska' }]
      } }
  end

  # Cely pohlad nad jednou zakazkou: 5 riadkov vo vsetkych stavoch.
  def job_fixture
    records = [
      record('job', 'hood', owner('job', ''), 'item_id' => 'I-HOOD', 'name' => 'Whirlpool WCT3'),
      record('bound', 'hob', owner('board', 'BRD-2'), 'item_id' => 'I-HOB', 'name' => 'Whirlpool WL'),
      record('owner_missing', 'oven', owner('cabinet', 'CAB-11'),
             'item_id' => 'I-OVEN', 'name' => 'Bosch HBF'),
      record('bound', 'fridge', owner('cabinet', 'CAB-3'), 'item_id' => 'I-FRIDGE',
             'name' => 'Beko BCNA306', 'snapshot' => { 'niche' => fridge_dims['niche'] }),
      record('expected_missing', 'dishwasher', owner('slot', 'CAB-7'))
    ]
    items = [
      item('I-HOOD', 'hood', owner('job', '')),
      item('I-HOB', 'hob', owner('board', 'BRD-2'),
           'snapshot' => snapshot('hob', 'WL B1160', 'Whirlpool', {}), 'catalog_id' => 'CAT-WL'),
      item('I-OVEN', 'oven', owner('cabinet', 'CAB-11'), 'cena' => nil),
      item('I-FRIDGE', 'fridge', owner('cabinet', 'CAB-3'),
           'snapshot' => snapshot('fridge', 'BCNA306', 'Beko', fridge_dims),
           'catalog_id' => 'CAT-BCNA306', 'customer_supplied' => true)
    ]
    rows = [
      { 'id' => 'I-HOOD', 'cena_mj' => 255.0 },
      { 'id' => 'I-HOB', 'cena_mj' => 289.0 },
      { 'id' => 'I-OVEN', 'cena_mj' => nil },
      { 'id' => 'I-FRIDGE', 'cena_mj' => 639.0, 'customer_supplied' => true }
    ]
    control = { 'items' => [
      { 'category' => 'appliance', 'severity' => 'orange', 'owner_id' => nil,
        'message_sk' => 'Spotrebič „Bosch HBF“ má vlastníka CAB-11, ktorý už neexistuje.',
        'data' => { 'route' => 'appl', 'item_id' => 'I-OVEN' },
        'stable_key' => 'appliance|I-OVEN|appliance_owner_missing' }
    ] }
    [records, items, budget_payload(rows, owners_map), control]
  end

  def job_view
    recs, items, budget, control = job_fixture
    AD.job_view(recs, items, budget, control)
  end

  def row_of(view, id)
    Array(view['rows']).find { |r| r['item_id'].to_s == id.to_s }
  end

  # --- fixtury pre riadok Inspectora ------------------------------------------

  def ref(item_id, category, extra = {})
    { 'item_id' => item_id, 'category' => category }.merge(extra)
  end

  # Vnutro 564 × 1924 × 562 (chladnickova skriňa 600 × 2076 × 580).
  def tall_cfg(extra = {})
    { 'type' => 'lower', 'width' => 600.0, 'height' => 2076.0, 'depth' => 580.0,
      'thickness' => 18.0, 'floor_height' => 100.0, 'bottom_mode' => 'between_sides',
      'top_mode' => 'full', 'back_mode' => 'inset', 'back_thickness' => 5.0,
      'zones' => [] }.merge(extra)
  end

  def slot_cfg(extra = {})
    { 'type' => 'dishwasher', 'width' => 600.0, 'height' => 870.0, 'depth' => 560.0,
      'thickness' => 18.0, 'dw_class' => 600, 'dw_body_height' => 820.0,
      'dw_front_bottom' => 64.0, 'dw_front_height' => 776.0 }.merge(extra)
  end

  def board_cfg(extra = {})
    { 'config_schema' => 2, 'role' => 'free_panel', 'name' => 'Doska',
      'length' => 2400.0, 'width' => 600.0, 'thickness' => 38.0, 'edges' => {} }.merge(extra)
  end

  def interior(cfg)
    PANEL.appliance_interior(cfg)
  end

  # Fake kus v modeli s PID (`NxTest::FakeInstance` ho nema — a identita ciela
  # vazby stoji PRAVE na nom).
  class FakeInst < NxTest::FakeEntity
    attr_reader :persistent_id

    def initialize(pid)
      super()
      @persistent_id = pid
    end
  end

  def fake_cabinet(id, pid, cfg)
    inst = FakeInst.new(pid)
    STORE.write(inst, { std: STORE::STD, kind: 'cabinet', cabinet_id: id, config: cfg })
    inst
  end
end

# ---------------------------------------------------------------------------
# 1) POHLAD „V ZAKAZKE" — riadky, poradie, stavy, ceny
# ---------------------------------------------------------------------------

NxTest.test('S1-B2: pohlad ma riadok pre KAZDY zaznam zberu (aj „nevybraný")') do
  view = NxS1B2.job_view
  NxTest.assert_equal(5, Array(view['rows']).length, 'styri polozky + jedno ocakavanie')
  NxTest.assert_equal(4, view['total'], '„nevybraný" nie je polozka zakazky')
  states = Array(view['rows']).map { |r| r['state'] }.sort
  NxTest.assert_equal(%w[bound bound expected_missing job owner_missing], states)
end

NxTest.test('S1-B2 (M3): PORADIE sklada SERVER — skrinky, dosky, sloty, len zakazka') do
  view = NxS1B2.job_view
  order = Array(view['rows']).map { |r| "#{r['owner']['kind']}|#{r['owner']['id']}" }
  NxTest.assert_equal(['cabinet|CAB-3', 'cabinet|CAB-11', 'board|BRD-2', 'slot|CAB-7', 'job|'],
                      order,
                      'skrinky v poradi ponuky vlastnikov (sirota na konci svojej skupiny), ' \
                      'potom dosky, sloty a „len zákazka"')
end

NxTest.test('S1-B2: popisok vlastnika je z PONUKY rozpoctu (ID + popis zvlast)') do
  view = NxS1B2.job_view
  fridge = NxS1B2.row_of(view, 'I-FRIDGE')
  NxTest.assert_equal('CAB-3', fridge['owner_label'])
  NxTest.assert_equal('Chladničková skriňa', fridge['owner_desc'])
  job = NxS1B2.row_of(view, 'I-HOOD')
  NxTest.assert_equal('—', job['owner_label'], '„len zákazka" nema co oznacit')
  NxTest.assert_equal('len zákazka', job['owner_desc'])
end

NxTest.test('S1-B2: stav riadku — OK, evidencia, nalez Kontroly, nevybraný, vlastnik zmizol') do
  view = NxS1B2.job_view
  NxTest.assert_equal('ok', NxS1B2.row_of(view, 'I-FRIDGE')['tone'], 'viazana chladnicka s nikou')
  hob = NxS1B2.row_of(view, 'I-HOB')
  NxTest.assert_equal('info', hob['tone'], 'doska kontrolu nema')
  NxTest.assert_equal('evidencia', hob['status_text'])
  oven = NxS1B2.row_of(view, 'I-OVEN')
  NxTest.assert_equal('warn', oven['tone'])
  NxTest.assert_equal('vlastník zmizol', oven['status_text'])
  exp = Array(view['rows']).find { |r| r['state'] == 'expected_missing' }
  NxTest.assert_equal('nevybraný', exp['status_text'])
  NxTest.assert_equal('warn', exp['tone'])
end

NxTest.test('S1-B2: nalez Kontroly sa premietne do stlpca (skratka + cely text v tooltipe)') do
  recs, items, budget, _ = NxS1B2.job_fixture
  control = { 'items' => [
    { 'category' => 'appliance', 'severity' => 'orange', 'owner_id' => 'CAB-3',
      'message_sk' => 'Spotrebič „Beko“ nemá v katalógu rozmery niky — kontrola sa nedá urobiť.',
      'data' => { 'route' => 'appl', 'item_id' => 'I-FRIDGE' },
      'stable_key' => 'appliance|I-FRIDGE|appliance_specs_missing' }
  ] }
  view = NxS1B2::AD.job_view(recs, items, budget, control)
  row = NxS1B2.row_of(view, 'I-FRIDGE')
  NxTest.assert_equal('warn', row['tone'])
  NxTest.assert_equal('chýbajú údaje niky', row['status_text'])
  NxTest.assert(row['status_title'].include?('Beko'), 'cela veta nalezu ostava v tooltipe')
end

NxTest.test('S1-B2: cena je z ROZPOCTU; „dodáva zákazník" je stitok, nie nula') do
  view = NxS1B2.job_view
  NxTest.assert_equal('dodáva zákazník', NxS1B2.row_of(view, 'I-FRIDGE')['price_text'])
  NxTest.assert(NxS1B2.row_of(view, 'I-FRIDGE')['customer_supplied'])
  NxTest.assert_equal('289,00 €', NxS1B2.row_of(view, 'I-HOB')['price_text'])
  NxTest.assert_equal('—', NxS1B2.row_of(view, 'I-OVEN')['price_text'], 'polozka bez ceny')
  NxTest.assert_equal('1234,50 €', view['subtotal_text'], 'medzisucet pocita ROZPOCET')
  NxTest.refute(view['subtotal_included'], 'a prizna, ze do SPOLU nevstupuje')
end

NxTest.test('S1-B2: odkaz a technicky list su zo SNAPSHOTU polozky (a len http/https)') do
  view = NxS1B2.job_view
  hob = NxS1B2.row_of(view, 'I-HOB')
  NxTest.assert_equal('https://obchod.sk/x', hob['shop_url'])
  NxTest.assert_equal('https://vyrobca.sk/list.pdf', hob['sheet_url'])
  NxTest.assert(hob['actions']['shop'] && hob['actions']['sheet'])
  recs, items, budget, control = NxS1B2.job_fixture
  items.each { |it| it['snapshot']['shop_urls'] = ['file:///C:/tajne.pdf'] if it['snapshot'] }
  bad = NxS1B2::AD.job_view(recs, items, budget, control)
  NxTest.assert_equal('', NxS1B2.row_of(bad, 'I-HOB')['shop_url'],
                      'nehttp adresa sa do okna nedostane vobec')
end

# Codex #383 kolo 1 (P2): ADRESA OBCHODU je z POLOZKY, snapshot az potom.
NxTest.test('S1-B2 (kolo 1 P2): „obchod" berie adresu polozky, katalog je az fallback') do
  recs, items, budget, control = NxS1B2.job_fixture
  # (a) rucna polozka BEZ katalogu, ale S adresou -> akcia JE.
  items.find { |i| i['id'] == 'I-OVEN' }['url'] = 'https://obchod.sk/rucny'
  view = NxS1B2::AD.job_view(recs, items, budget, control)
  oven = NxS1B2.row_of(view, 'I-OVEN')
  NxTest.assert_equal('https://obchod.sk/rucny', oven['shop_url'],
                      'polozka bez katalogu ma adresu — a teda aj akciu')
  NxTest.assert(oven['actions']['shop'])
  # (b) UPRAVENA adresa nad katalogovou polozkou PREBIJE snapshot.
  items.find { |i| i['id'] == 'I-HOB' }['url'] = 'https://obchod.sk/nova'
  view2 = NxS1B2::AD.job_view(recs, items, budget, control)
  NxTest.assert_equal('https://obchod.sk/nova', NxS1B2.row_of(view2, 'I-HOB')['shop_url'],
                      'stara katalogova URL sa uz neotvara')
  # (c) Neplatna adresa polozky sa IGNORUJE a padne sa na snapshot.
  items.find { |i| i['id'] == 'I-HOB' }['url'] = 'file:///C:/tajne.pdf'
  view3 = NxS1B2::AD.job_view(recs, items, budget, control)
  NxTest.assert_equal('https://obchod.sk/x', NxS1B2.row_of(view3, 'I-HOB')['shop_url'],
                      'nehttp adresa sa do okna nedostane ani takto')
  # (d) LIST ostava zo snapshotu — polozka pole pre list nema.
  NxTest.assert_equal('https://vyrobca.sk/list.pdf', NxS1B2.row_of(view3, 'I-HOB')['sheet_url'])
end

# Codex #383 kolo 1 (P2): vlastnik MIMO ponuky sa nepriradzuje.
NxTest.test('S1-B2 (kolo 1 P2): „vybrať…" je LEN pri vlastnikovi, ktory je v ponuke') do
  recs, items, budget, control = NxS1B2.job_fixture
  view = NxS1B2::AD.job_view(recs, items, budget, control)
  exp = Array(view['rows']).find { |r| r['state'] == 'expected_missing' }
  NxTest.assert(exp['actions']['assign'], 'slot CAB-7 je v ponuke — vybrat sa da')

  # Ten isty pohlad, ale ponuka vlastnikov slot NEOBSAHUJE (odpojeny dielec,
  # config z novsej verzie — `owner_options_map` ho vynecha).
  owners = NxS1B2.owners_map
  owners['options']['slot'] = []
  budget2 = budget.merge('appliance_owners' => owners)
  view2 = NxS1B2::AD.job_view(recs, items, budget2, control)
  exp2 = Array(view2['rows']).find { |r| r['state'] == 'expected_missing' }
  NxTest.refute(exp2['actions']['assign'],
                'modal by spadol na „len zákazka" a vyrobil nepriradenu polozku')
  NxTest.assert(exp2['model_sub'].include?('nedá'), "riadok povie DOVOD: #{exp2['model_sub']}")
end

NxTest.test('S1-B2: AKCIE riadku urcuje server (oko len pri zivom vlastnikovi)') do
  view = NxS1B2.job_view
  fridge = NxS1B2.row_of(view, 'I-FRIDGE')['actions']
  NxTest.assert(fridge['select'], 'viazana polozka sa da oznacit v modeli')
  NxTest.assert(fridge['unbind'] && fridge['edit'] && fridge['remove'])
  orphan = NxS1B2.row_of(view, 'I-OVEN')['actions']
  NxTest.refute(orphan['select'], 'sirota nema co oznacit — vlastnik neexistuje')
  NxTest.assert(orphan['unbind'], 'ale da sa odpojit')
  job = NxS1B2.row_of(view, 'I-HOOD')['actions']
  NxTest.refute(job['select'] || job['unbind'], '„len zákazka" nema vlastnika')
  exp = Array(view['rows']).find { |r| r['state'] == 'expected_missing' }['actions']
  NxTest.assert(exp['assign'], 'riadok „nevybraný" ponuka vyber modelu')
  NxTest.refute(exp['edit'] || exp['remove'], 'nie je co editovat ani mazat')
end

NxTest.test('S1-B2: badge navigacie rata RIADKY, nie nalezy') do
  recs, items, budget, _ = NxS1B2.job_fixture
  control = { 'items' => [
    { 'category' => 'appliance', 'data' => { 'item_id' => 'I-FRIDGE' },
      'message_sk' => 'a', 'stable_key' => 'appliance|I-FRIDGE|appliance_specs_missing' },
    { 'category' => 'appliance', 'data' => { 'item_id' => 'I-FRIDGE' },
      'message_sk' => 'b', 'stable_key' => 'appliance|I-FRIDGE|appliance_class_mismatch' }
  ] }
  view = NxS1B2::AD.job_view(recs, items, budget, control)
  # 1× chladnicka s dvoma nalezmi + 1× „nevybraný" (sirota tu nalez nema).
  NxTest.assert_equal(3, view['counts']['orange'], 'dva nalezy nad jednou polozkou = JEDEN riadok')
  NxTest.assert_equal(0, view['counts']['red'], 'spotrebic exportnu branu nedrzi')
  NxTest.assert_equal(view['warn'], view['counts']['total'])
end

NxTest.test('S1-B2: suhrn pod tabulkou sklada server') do
  view = NxS1B2.job_view
  NxTest.assert(view['summary'].start_with?('4 spotrebiče'), "suhrn: #{view['summary']}")
  NxTest.assert(view['summary'].include?('1 nevybraný'))
  NxTest.assert(view['summary'].include?('1 bez vlastníka'))
  NxTest.assert(view['summary'].include?('1 dodáva zákazník'))
end

NxTest.test('S1-B2: payload sekcie nesie `job` LEN ked pozna dokument') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'appliance_dialog.rb'),
                  encoding: 'UTF-8')
  body = src[/def section_payload.*?\n        end\n/m].to_s
  NxTest.assert(body.include?("out['job'] = job if job"),
                'bez modelu (legacy volanie) kluc CHYBA — sekcia kresli len katalog')
  NxTest.assert(File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'appliances.js'),
                          encoding: 'UTF-8').include?('if (p.job) AP_JOB = p.job'),
                'echo katalogu tabulku NEPREPISE')
end

# ---------------------------------------------------------------------------
# 2) DEEP-LINK z Kontroly
# ---------------------------------------------------------------------------

NxTest.test('S1-B2: nalez o spotrebici vedie do sekcie SPOTREBIČE (nie do Rozpoctu)') do
  pc = Noxun::Engine::ProductionCore
  NxTest.assert_equal({ 'appl' => 'appl' }, pc::ROUTE_SECTIONS)
  item = { 'owner_id' => nil, 'data' => { 'route' => 'appl', 'item_id' => 'I-1' } }
  rt = pc.route_target(item)
  NxTest.assert_equal({ 'route' => 'appl', 'section' => 'appl', 'anchor' => 'appliance:I-1' }, rt)
  NxTest.assert(pc.route_status(rt).include?('Spotrebičoch'))
end

# ---------------------------------------------------------------------------
# 3) RIADOK „SPOTREBIC" v Inspectore
# ---------------------------------------------------------------------------

NxTest.test('S1-B2: viazany riadok nesie nazov modelu, ton a odkaz do Studia') do
  cfg = NxS1B2.tall_cfg('appliance_refs' => [NxS1B2.ref('I-1', 'fridge')])
  items = [NxS1B2.item('I-1', 'fridge', NxS1B2.owner('cabinet', 'CAB-3'),
                       'snapshot' => NxS1B2.snapshot('fridge', 'BCNA306', 'Beko',
                                                     NxS1B2.fridge_dims))]
  rows = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg))
  # S1-C: POSLEDNY riadok je VOLBA „očakáva" (kresli sa vzdy — inak by sa
  # ocakavanie bez sablony nedalo zapnut). Viazany riadok je ten prvy.
  NxTest.assert_equal(%w[bound expects], rows.map { |r| r['state'] })
  NxTest.assert_equal('Beko BCNA306', rows.first['text'])
  NxTest.assert_equal('ok', rows.first['tone'])
  NxTest.assert(rows.first['link'])
end

NxTest.test('S1-B2: DVA viazane spotrebice = DVA riadky (rura + mikrovlnka)') do
  cfg = NxS1B2.tall_cfg('appliance_refs' => [NxS1B2.ref('I-1', 'oven'),
                                             NxS1B2.ref('I-2', 'microwave')])
  items = [NxS1B2.item('I-1', 'oven', NxS1B2.owner('cabinet', 'CAB-5'),
                       'snapshot' => NxS1B2.snapshot('oven', 'OMSR58', 'Whirlpool',
                                                     NxS1B2.oven_dims)),
           NxS1B2.item('I-2', 'microwave', NxS1B2.owner('cabinet', 'CAB-5'),
                       'snapshot' => NxS1B2.snapshot('microwave', 'MBNA900', 'Whirlpool',
                                                     NxS1B2.oven_dims))]
  rows = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg))
  bound = rows.reject { |r| r['state'] == 'expects' } # S1-C: volba je samostatny riadok
  NxTest.assert_equal(%w[I-1 I-2], bound.map { |r| r['item_id'] })
end

NxTest.test('S1-B2: riadok „očakáva" vznikne z `appliance_expects[]` a ponuka len VOLNE polozky') do
  cfg = NxS1B2.tall_cfg('appliance_expects' => ['fridge'])
  items = [
    NxS1B2.item('FREE', 'fridge', NxS1B2.owner('job', ''),
                'snapshot' => NxS1B2.snapshot('fridge', 'BCNA306', 'Beko', NxS1B2.fridge_dims)),
    NxS1B2.item('TAKEN', 'fridge', NxS1B2.owner('cabinet', 'CAB-1'),
                'snapshot' => NxS1B2.snapshot('fridge', 'ART 97101', 'Whirlpool',
                                              NxS1B2.fridge_dims)),
    NxS1B2.item('OVEN', 'oven', NxS1B2.owner('job', ''))
  ]
  rows = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg))
  NxTest.assert_equal(%w[expected expects], rows.map { |r| r['state'] }) # S1-C: + volba
  row = rows.first
  NxTest.assert_equal('expected', row['state'])
  NxTest.assert_equal('očakáva: chladnička', row['text'])
  NxTest.assert_equal(['FREE'], row['options'].map { |o| o['item_id'] },
                      'viazana polozka ani ina kategoria sa neponukaju')
  NxTest.assert_equal('vyber model…', row['placeholder'], 'prva volba je NEUTRALNA')
end

NxTest.test('S1-B2: ocakavanie, ktore uz vazbu MA, riadok nevyrobi') do
  cfg = NxS1B2.tall_cfg('appliance_expects' => ['fridge'],
                        'appliance_refs' => [NxS1B2.ref('I-1', 'fridge')])
  items = [NxS1B2.item('I-1', 'fridge', NxS1B2.owner('cabinet', 'CAB-3'),
                       'snapshot' => NxS1B2.snapshot('fridge', 'BCNA306', 'Beko',
                                                     NxS1B2.fridge_dims))]
  # S1-C (Codex #385 kolo 1 P2): „uz vazbu MA" znamena OBOJSMERNY dokaz, takze
  # riadok potrebuje ID vlastnika — bez neho by sa nemalo co porovnavat
  # s vlastnikom polozky a panel by kategoriu za splnenu NEPOVAZOVAL.
  rows = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg),
                                      owner_id: 'CAB-3')
  NxTest.assert_equal(%w[bound expects], rows.map { |r| r['state'] })

  # Polozka, ktora patri INEJ skrinke (recyklovane ID), ocakavanie NESPLNI —
  # Kontrola v tej istej situacii hlasi `appliance_missing`.
  other = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg),
                                       owner_id: 'CAB-9')
  NxTest.assert_equal(%w[bound expected expects], other.map { |r| r['state'] },
                      'sirota riadok „očakáva" NEPOTLACI — inak by sa nalez nedal vybavit')
end

# S1-C VEDOMA REVIZIA pravidla B2 „prazdny zoznam riadok skryje": bez VIDITELNEJ
# volby by sa ocakavanie bez sablony nedalo zapnut vobec (mockup R10 „Bez
# spotrebiča riadok ukáže len voľbu očakáva: —"). Riadok je preto PRESNE JEDEN
# a tlmeny; kus, ktory podla matice nemoze ocakavat nic, ho stale nema.
NxTest.test('S1-C: skrinka bez vazby a bez ocakavania ma UZ LEN volbu „očakáva"') do
  cfg = NxS1B2.tall_cfg
  rows = NxS1B2::PANEL.appliance_rows('cabinet', cfg, [], NxS1B2.interior(cfg))
  NxTest.assert_equal(%w[expects], rows.map { |r| r['state'] },
                      'jeden tlmeny riadok — inak sa ocakavanie bez sablony neda zapnut')
  row = rows.first
  NxTest.assert_equal([], row['expects'], 'UPLNY zoznam je prazdny')
  NxTest.assert_equal('bez spotrebiča — nastav „očakáva", ak sem spotrebič patrí', row['text'])
  NxTest.assert_equal('očakáva: —', row['placeholder'], 'prva volba je NEUTRALNA')
  NxTest.assert_equal(%w[add:fridge add:oven add:microwave],
                      row['options'].map { |o| o['value'] },
                      'ponuka je MATICA vlastnikov v kanonickom poradi')
  NxTest.refute(row['link'], 'volba nie je odkaz do Studia')
end

NxTest.test('S1-C: SLOT volbu NEMA (ocakava umyvacku vzdy) a doska ma svoje dve') do
  slot = NxS1B2::PANEL.appliance_rows('slot', NxS1B2.slot_cfg, [], nil)
  NxTest.refute(slot.any? { |r| r['state'] == 'expects' },
                'volba by pri slote bola klamstvo — server umyvacku vynucuje')
  board = NxS1B2::PANEL.appliance_rows('board', NxS1B2.board_cfg, [], nil)
  pick = board.find { |r| r['state'] == 'expects' }
  NxTest.assert_equal(%w[add:hob add:sink], pick['options'].map { |o| o['value'] },
                      'doska smie ocakavat varnu dosku a drez')
end

NxTest.test('S1-C: volba nesie UPLNY zoznam a viazanu kategoriu ODOBRAT nedovoli') do
  cfg = NxS1B2.tall_cfg('appliance_expects' => %w[oven microwave],
                        'appliance_refs' => [NxS1B2.ref('I-1', 'oven')])
  items = [NxS1B2.item('I-1', 'oven', NxS1B2.owner('cabinet', 'CAB-3'),
                       'snapshot' => NxS1B2.snapshot('oven', 'OMSR58', 'Whirlpool',
                                                     NxS1B2.oven_dims))]
  rows = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg),
                                      owner_id: 'CAB-3')
  pick = rows.find { |r| r['state'] == 'expects' }
  NxTest.assert_equal(%w[oven microwave], pick['expects'],
                      'UPLNY zoznam (aj splnene) — klient z neho sklada novy')
  by = pick['options'].each_with_object({}) { |o, h| h[o['code']] = o }
  NxTest.assert_equal('del:oven', by['oven']['value'])
  NxTest.assert(by['oven']['disabled'], 'viazanu ruru sa odobrat neda')
  NxTest.assert(by['oven']['text'].include?('najprv odpoj'), by['oven']['text'])
  NxTest.refute(by['microwave']['disabled'], 'nesplnene ocakavanie sa zrusit da')
  NxTest.assert_equal('add:fridge', by['fridge']['value'])
end

NxTest.test('S1-B2: SLOT bez modelu ocakava umyvacku vzdy (aj bez `appliance_expects`)') do
  cfg = NxS1B2.slot_cfg
  rows = NxS1B2::PANEL.appliance_rows('slot', cfg, [], nil)
  NxTest.assert_equal(1, rows.length)
  NxTest.assert_equal('dishwasher', rows.first['category'])
  NxTest.assert_equal('expected', rows.first['state'])
end

# --- filter niky ------------------------------------------------------------

NxTest.test('S1-B2 (M1): rura sa filtruje LEN po sirke a hlbke — vyska je vec zon') do
  cfg = NxS1B2.tall_cfg('appliance_expects' => ['oven'])
  inter = NxS1B2.interior(cfg)
  NxTest.assert(inter['height'] > 1000.0, "vnutro vysoke #{inter['height']} mm")
  items = [NxS1B2.item('OK', 'oven', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('oven', 'OMSR58', 'Whirlpool',
                                                     NxS1B2.oven_dims)),
           NxS1B2.item('DEEP', 'oven', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('oven', 'HBG774', 'Bosch',
                                                     NxS1B2.oven_dims(900.0)))]
  row = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, inter).first
  fits = row['options'].select { |o| o['fits'] }
  NxTest.assert_equal(['OK'], fits.map { |o| o['item_id'] },
                      'vyska niky 583–585 vs vnutro 1924 sa NEKONTROLUJE (inak by nesedelo nic)')
  bad = row['options'].find { |o| o['item_id'] == 'DEEP' }
  NxTest.assert(bad['hint'].include?('hĺbka'), "dovod menuje os: #{bad['hint']}")
  NxTest.assert(row['all'], 'a riadok prizna, ze v ponuke su aj nesediace')
end

NxTest.test('S1-B2: chladnicka sa filtruje po vsetkych troch osiach') do
  cfg = NxS1B2.tall_cfg('appliance_expects' => ['fridge'], 'height' => 2060.0)
  inter = NxS1B2.interior(cfg)
  items = [NxS1B2.item('BEKO', 'fridge', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('fridge', 'BCNA306', 'Beko',
                                                     NxS1B2.fridge_dims))]
  row = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, inter).first
  opt = row['options'].first
  NxTest.refute(opt['fits'], 'ulozna vyska vnutra < nika 1940')
  NxTest.assert(opt['hint'].include?('výška'), "dovod menuje os: #{opt['hint']}")
  NxTest.assert(opt['text'].include?('nesedí'), 'a text volby to prizna')
end

NxTest.test('S1-B2: VIAC ZON = nejednoznacna nika -> chladnicka sa nefiltruje (rura ano)') do
  zones = [{ 'id' => 'Z1' }, { 'id' => 'Z2' }]
  fcfg = NxS1B2.tall_cfg('appliance_expects' => ['fridge'], 'height' => 2060.0, 'zones' => zones)
  items = [NxS1B2.item('BEKO', 'fridge', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('fridge', 'BCNA306', 'Beko',
                                                     NxS1B2.fridge_dims))]
  row = NxS1B2::PANEL.appliance_rows('cabinet', fcfg, items, NxS1B2.interior(fcfg)).first
  NxTest.assert(row['options'].first['fits'], 'pri viacerych zonach sa neda povedat, co je vnutro')
  NxTest.assert(row['sub'].include?('nejednoznačná'), "riadok to PRIZNA: #{row['sub']}")
  NxTest.refute(row['all'], 'ked sa nefiltruje, niet co odkryvat')

  ocfg = NxS1B2.tall_cfg('appliance_expects' => ['oven'], 'zones' => zones)
  ovens = [NxS1B2.item('DEEP', 'oven', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('oven', 'HBG774', 'Bosch',
                                                     NxS1B2.oven_dims(900.0)))]
  orow = NxS1B2::PANEL.appliance_rows('cabinet', ocfg, ovens, NxS1B2.interior(ocfg)).first
  NxTest.refute(orow['options'].first['fits'],
                'sirka a hlbka su jednoznacne aj v delenej skrinke — rura o filter neprichadza')
end

NxTest.test('S1-B2: model BEZ rozmerov niky sa NIKDY neoznaci ako „nesedí"') do
  cfg = NxS1B2.tall_cfg('appliance_expects' => ['oven'])
  items = [NxS1B2.item('RUCNY', 'oven', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('oven', 'HBF153', 'Bosch', {}))]
  row = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg)).first
  NxTest.assert(row['options'].first['fits'], '„nevieme" nie je „nesedí"')
end

NxTest.test('S1-B2: PORADIE volieb — najprv sediace, potom nesediace') do
  cfg = NxS1B2.tall_cfg('appliance_expects' => ['oven'])
  items = [NxS1B2.item('A_DEEP', 'oven', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('oven', 'A', 'X', NxS1B2.oven_dims(900.0))),
           NxS1B2.item('Z_OK', 'oven', NxS1B2.owner('job', ''),
                       'snapshot' => NxS1B2.snapshot('oven', 'Z', 'X', NxS1B2.oven_dims))]
  row = NxS1B2::PANEL.appliance_rows('cabinet', cfg, items, NxS1B2.interior(cfg)).first
  NxTest.assert_equal(%w[Z_OK A_DEEP], row['options'].map { |o| o['item_id'] },
                      'prva volba nikdy nie je model, o ktorom vieme, ze nesedi')
end

# --- ton riadku vs Kontrola --------------------------------------------------

NxTest.test('S1-B2: TON riadku sa nemoze rozist s Kontrolou (chybajuca nika)') do
  cfg = NxS1B2.tall_cfg('appliance_refs' => [NxS1B2.ref('I-1', 'oven')])
  item = NxS1B2.item('I-1', 'oven', NxS1B2.owner('cabinet', 'CAB-5'),
                     'snapshot' => NxS1B2.snapshot('oven', 'HBF153', 'Bosch', {}))
  row = NxS1B2::PANEL.appliance_rows('cabinet', cfg, [item], NxS1B2.interior(cfg)).first
  NxTest.assert_equal('warn', row['tone'])
  # A TA ISTA situacia ocami Kontroly (jedina autorita nalezov).
  items = []
  NxS1B2::VAL.check_appliances(
    [{ 'item_id' => 'I-1', 'name' => 'Bosch HBF153', 'category' => 'oven', 'state' => 'bound',
       'owner' => { 'kind' => 'cabinet', 'id' => 'CAB-5', 'pid' => 5 }, 'snapshot' => {} }], items
  )
  NxTest.assert(items.any? { |i| i['stable_key'].include?('appliance_specs_missing') },
                'Kontrola hlasi to iste, co riadok priznava tonom')
end

NxTest.test('S1-B2: TON riadku sa nemoze rozist s Kontrolou (trieda umyvacky)') do
  cfg = NxS1B2.slot_cfg('appliance_refs' => [NxS1B2.ref('I-9', 'dishwasher',
                                                        'body' => { 'width' => 448.0,
                                                                    'depth' => 550.0 })])
  item = NxS1B2.item('I-9', 'dishwasher', NxS1B2.owner('slot', 'CAB-7'),
                     'snapshot' => NxS1B2.snapshot('dishwasher', 'SPV6EMX05E', 'Bosch',
                                                   NxS1B2.dw_dims('450')))
  row = NxS1B2::PANEL.appliance_rows('slot', cfg, [item], nil).first
  NxTest.assert_equal('warn', row['tone'], 'trieda 450 v slote 600')
  NxTest.assert(row['sub'].include?('450'), "dovod menuje obe triedy: #{row['sub']}")
  items = []
  NxS1B2::VAL.check_appliances(
    [{ 'item_id' => 'I-9', 'name' => 'Bosch', 'category' => 'dishwasher', 'state' => 'bound',
       'owner' => { 'kind' => 'slot', 'id' => 'CAB-7', 'pid' => 7 },
       'snapshot' => { 'niche' => { 'width_min' => 450.0 },
                       'install' => { 'dishwasher_class' => '450' } },
       'slot' => { 'dw_class' => 600 } }], items
  )
  NxTest.assert(items.any? { |i| i['stable_key'].include?('appliance_class_mismatch') })
end

NxTest.test('S1-B2: polozka, ktora uz v rozpocte NIE JE, riadok NESKRYVA') do
  cfg = NxS1B2.tall_cfg('appliance_refs' => [NxS1B2.ref('GHOST', 'fridge')])
  row = NxS1B2::PANEL.appliance_rows('cabinet', cfg, [], NxS1B2.interior(cfg)).first
  NxTest.assert_equal('warn', row['tone'])
  NxTest.assert(row['text'].include?('už v rozpočte nie je'), 'refs na entite treba vediet odpojit')
end

# --- karta dosky -------------------------------------------------------------

NxTest.test('S1-B2: karta DOSKY ma ten isty riadok (a niku nefiltruje)') do
  cfg = NxS1B2.board_cfg('appliance_refs' => [NxS1B2.ref('I-HOB', 'hob'),
                                              NxS1B2.ref('I-SINK', 'sink')])
  items = [NxS1B2.item('I-HOB', 'hob', NxS1B2.owner('board', 'BRD-2'),
                       'snapshot' => NxS1B2.snapshot('hob', 'WL B1160', 'Whirlpool', {})),
           NxS1B2.item('I-SINK', 'sink', NxS1B2.owner('board', 'BRD-2'),
                       'snapshot' => NxS1B2.snapshot('sink', 'Legra XL', 'Blanco', {}))]
  rows = NxS1B2::PANEL.appliance_rows('board', cfg, items, nil)
  bound = rows.reject { |r| r['state'] == 'expects' } # S1-C: volba je samostatny riadok
  NxTest.assert_equal(2, bound.length, 'doska nesie aj dosku aj drez')
  NxTest.assert(bound.all? { |r| r['tone'] == 'ok' },
                'doska niku nema, takze chybajuce rozmery niky nie su nalez')
end

NxTest.test('S1-B2: `board_payload` riadky NESIE (aditivny kluc)') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  inst = NxS1B2::FakeInst.new(21) # S1-C: payload nesie `persistent_id`
  NxS1B2::STORE.write(inst, { std: NxS1B2::STORE::STD, kind: 'board', id: 'BRD-2',
                              role: 'free_panel', name: 'D',
                              config: NxS1B2.board_cfg })
  pay = NxS1B2::PANEL.board_payload(inst)
  NxTest.assert(pay.key?('appliance_rows'), 'kluc je vzdy')
  # S1-C: doska bez vazby ma volbu „očakáva" (varna doska / drez) a payload
  # nesie aj jej `persistent_id` — bez neho server zapis odmietne.
  NxTest.assert_equal(%w[expects], pay['appliance_rows'].map { |r| r['state'] })
  NxTest.assert_equal(21, pay['board_pid'])
end

# ---------------------------------------------------------------------------
# 4) TELO SLOTU Z VAZBY
# ---------------------------------------------------------------------------

NxTest.test('S1-B2 (M2): telo slotu je Z KATALOGU, ked je model priradeny') do
  # Trieda slotu je 600 (genericke telo 598 × 555), model je 45 cm (448 × 550)
  # — cisla sa teda NESMU rovnat, inak by test nevedel povedat, odkial su.
  cfg = NxS1B2.slot_cfg('dw_class' => 600, 'dw_body_height' => 820.0,
                        'appliance_refs' => [NxS1B2.ref('I-9', 'dishwasher',
                                                        'body' => { 'width' => 448.0,
                                                                    'depth' => 550.0 })])
  generic = NxS1B2::CON.dw_class_dims(600)
  body = NxS1B2::CON.dw_body_dims(cfg.transform_keys(&:to_sym))
  NxTest.refute(generic[:body_w].to_f == 448.0, 'fixtura sa lisi od generiky')
  NxTest.assert_equal(448.0, body[:w])
  NxTest.assert_equal(550.0, body[:d])
  NxTest.assert_equal('catalog', body[:source])
  NxTest.assert_equal('I-9', body[:item_id])
end

NxTest.test('S1-B2: bez vazby ostava telo GENERICKE (tabulka triedy)') do
  body = NxS1B2::CON.dw_body_dims(NxS1B2.slot_cfg.transform_keys(&:to_sym))
  dims = NxS1B2::CON.dw_class_dims(600)
  NxTest.assert_equal(dims[:body_w].to_f, body[:w])
  NxTest.assert_equal('generic', body[:source])
  NxTest.assert(body[:item_id].nil?)
end

NxTest.test('S1-B2: deskriptor referencie nesie `source` aj `item_id` (a vysku od pouzivatela)') do
  cfg = NxS1B2.slot_cfg('appliance_refs' => [NxS1B2.ref('I-9', 'dishwasher',
                                                        'body' => { 'width' => 598.0,
                                                                    'depth' => 555.0 })])
  rd = NxS1B2::CON.dw_body_reference(cfg.transform_keys(&:to_sym))
  NxTest.assert_equal('catalog', rd[:source])
  NxTest.assert_equal('I-9', rd[:item_id])
  NxTest.assert_equal([598.0, 555.0, 820.0], rd[:box], 'vysku tela urcuje VZDY pouzivatel')
  NxTest.refute(rd[:label].include?('generické'))
  plain = NxS1B2::CON.dw_body_reference(NxS1B2.slot_cfg.transform_keys(&:to_sym))
  NxTest.assert_equal('generic', plain[:source])
  NxTest.assert(plain[:item_id].nil?, 'bez vazby kluc CHYBA — nikdy prazdny retazec')
  NxTest.assert(plain[:label].include?('generické'))
end

NxTest.test('S1-B2: plan slotu kresli referenciu z VAZBY (jedna autorita pre model aj cisla)') do
  cfg = Noxun::Engine::CabinetBuilder.normalize(
    NxS1B2.slot_cfg('appliance_refs' => [NxS1B2.ref('I-9', 'dishwasher',
                                                    'body' => { 'width' => 448.0,
                                                                'depth' => 550.0 })])
  )
  plan = NxS1B2::CON.appliance_slot_plan(cfg, 'CAB-7')
  ref = Array(plan[:references]).first
  NxTest.assert_equal('catalog', ref[:source])
  NxTest.assert_equal(448.0, ref[:box][0])
  NxTest.assert_equal(550.0, ref[:box][1])
  NxTest.assert_equal(1, Array(plan[:parts]).length, 'vyrobny dielec ostava JEDEN (celo)')
end

NxTest.test('S1-B2: Kontrola meria telo, ktore v slote NAOZAJ stoji') do
  cfg = NxS1B2.slot_cfg('width' => 500.0,
                        'appliance_refs' => [NxS1B2.ref('I-9', 'dishwasher',
                                                        'body' => { 'width' => 448.0,
                                                                    'depth' => 550.0 })])
  rec = NxS1B2::BOM.appliance_slot_record('CAB-7', 7, cfg)
  NxTest.assert_equal(448.0, rec['body_width'], 'nie genericke 598 — to by hlasilo „nezmesti sa"')
  NxTest.assert_equal('catalog', rec['body_source'])
  items = []
  NxS1B2::VAL.check_appliance_slots([rec], items)
  NxTest.refute(items.any? { |i| i['stable_key'].to_s.include?('dw_body_fit') },
                'telo 448 sa do slotu 500 zmesti')
end

NxTest.test('S1-B2: vystupy slotu menuju MODEL a rozsah vysky tela z listu') do
  cfg = NxS1B2.slot_cfg('dw_class' => 450, 'width' => 450.0,
                        'appliance_refs' => [NxS1B2.ref('I-9', 'dishwasher',
                                                        'body' => { 'width' => 448.0,
                                                                    'depth' => 550.0 })])
  item = NxS1B2.item('I-9', 'dishwasher', NxS1B2.owner('slot', 'CAB-7'),
                     'snapshot' => NxS1B2.snapshot('dishwasher', 'SPV6EMX05E', 'Bosch',
                                                   NxS1B2.dw_dims('450')))
  pay = NxS1B2::PANEL.slot_payload(cfg, [item])
  NxTest.assert_equal('448 × 820 × 550', pay['body'])
  NxTest.assert_equal('Bosch SPV6EMX05E', pay['body_note'], 'telo menuje MODEL, nie triedu')
  NxTest.assert_equal('list 815–875', pay['body_range'])
  NxTest.assert_equal('ok', pay['class_state'], 'trieda 450 v slote 450')
  NxTest.assert(pay['class_text'].include?('Bosch SPV6EMX05E'))
  NxTest.assert(pay['class_text'].include?('✓'))
  bez = NxS1B2::PANEL.slot_payload(NxS1B2.slot_cfg, [])
  NxTest.assert(bez['body_note'].include?('generické'))
  NxTest.assert(bez['class_text'].include?('bez modelu'))
  NxTest.assert_equal('unknown', bez['class_state'], 'bez modelu sa NETVRDI nic')
  NxTest.assert_equal('', bez['body_range'], 'bez modelu sa rozsah nevymysla')
end

# Codex #383 kolo 1 (P2): TRI STAVY triedy — „nevieme" nie je „sedí".
NxTest.test('S1-B2 (kolo 1 P2): model BEZ triedy v liste je `unknown`, nie zelene „ok"') do
  cfg = NxS1B2.slot_cfg('appliance_refs' => [NxS1B2.ref('I-9', 'dishwasher',
                                                        'body' => { 'width' => 598.0,
                                                                    'depth' => 555.0 })])
  dims = NxS1B2.dw_dims('450')
  dims['install'] = dims['install'].reject { |k, _| k == 'dishwasher_class' }
  item = NxS1B2.item('I-9', 'dishwasher', NxS1B2.owner('slot', 'CAB-7'),
                     'snapshot' => NxS1B2.snapshot('dishwasher', 'SPV bez triedy', 'Bosch', dims))
  pay = NxS1B2::PANEL.slot_payload(cfg, [item])
  NxTest.assert_equal('unknown', pay['class_state'],
                      'list triedu nekótuje — nie je proti comu porovnavat')
  NxTest.assert(pay['class_text'].include?('trieda neuvedená'), 'a text to povie')
  NxTest.refute(pay['class_text'].include?('✓'), 'ziadna fajka nad neoverenou vecou')
  NxTest.refute(pay['class_text'].include?('✗'))
  # A to, co Kontrola nad tou istou fixturou hovori: NIC (Astra B15).
  items = []
  NxS1B2::VAL.check_appliances(
    [{ 'item_id' => 'I-9', 'name' => 'Bosch', 'category' => 'dishwasher', 'state' => 'bound',
       'owner' => { 'kind' => 'slot', 'id' => 'CAB-7', 'pid' => 7 },
       'snapshot' => { 'niche' => { 'width_min' => 450.0 }, 'install' => {} },
       'slot' => { 'dw_class' => 600 } }], items
  )
  NxTest.refute(items.any? { |i| i['stable_key'].to_s.include?('appliance_class_mismatch') },
                'Kontrola pri neznamej triede tiez mlci — Inspector sa s nou nerozide')
end

NxTest.test('S1-B2 (kolo 1 P2): Inspector farbi triedu LEN pri ok/mismatch') do
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                 encoding: 'UTF-8')
  body = js[/var c = el\('inf_dw_class'\);.*?\n    \}/m].to_s
  NxTest.assert(!body.empty?, 'vetva farbenia sa nasla')
  NxTest.assert(body.include?("st === 'ok'") && body.include?("st === 'mismatch'"),
                'obe farby maju VLASTNY stav')
  NxTest.refute(body.include?('class_ok'), 'binarny priznak uz neexistuje')
end

# ---------------------------------------------------------------------------
# 5) AKCIA `set_appliance_owner` — guardy panela
# ---------------------------------------------------------------------------

NxTest.test('S1-B2: whitelist panela pozna `set_appliance_owner`') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?("cb(dlg, 'set_appliance_owner')"), 'callback je registrovany')
  NxTest.assert(src.include?("Sketchup.require 'noxun_engine/ui/panel/actions_appliance'"),
                'a subor sa nacitava')
end

NxTest.test('S1-B2: CIEL vazby sklada server z OZNACENEJ entity (slot vs skrinka)') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  cab = NxS1B2.fake_cabinet('CAB-3', 31, NxS1B2.tall_cfg)
  target, err = NxS1B2::PANEL.appliance_cabinet_target(cab, { 'cabinet_id' => 'CAB-3' })
  NxTest.assert(err.nil?)
  NxTest.assert_equal({ 'kind' => 'cabinet', 'id' => 'CAB-3', 'pid' => 31 }, target)

  slot = NxS1B2.fake_cabinet('CAB-7', 32, NxS1B2.slot_cfg)
  starget, = NxS1B2::PANEL.appliance_cabinet_target(slot, {})
  NxTest.assert_equal('slot', starget['kind'], 'typ `dishwasher` je v matici SLOT, nie skrinka')
  NxTest.assert_equal(32, starget['pid'], 'identita nesie PID — ID sa recykluju')
end

NxTest.test('S1-B2: echo ID z cudzieho vyberu sa ODMIETNE (GH #127 P2)') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  cab = NxS1B2.fake_cabinet('CAB-3', 33, NxS1B2.tall_cfg)
  target, err = NxS1B2::PANEL.appliance_cabinet_target(cab, { 'cabinet_id' => 'CAB-9' })
  NxTest.assert(target.nil?)
  NxTest.assert_equal(NxS1B2::PANEL::APPL_MSG_STALE, err)
end

NxTest.test('S1-B2: panel NEZAPISUJE — deleguje na jediny transakcny vstup') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel',
                            'actions_appliance.rb'), encoding: 'UTF-8')
  code = src.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert(code.include?('ApplianceBinding.apply!'), 'zapis robi jadro')
  NxTest.assert(code.include?('foreign_document?'), 'identita dokumentu sa overuje')
  NxTest.assert(code.include?("op: (unbind ? 'unbind' : 'move')"), 'dve operacie, obe z jadra')
  # S1-C + D-140: vlastne operacie v tomto subore su PRESNE DVE — zapis
  # OCAKAVANI (config bez prestavby) a VYSKY OSADENIA (prestavba boxu niky).
  # Ani v jednej sa polozka zakazky nemeni, takze jadro vazby nemá co pouzit;
  # vazba samotna ostava VYHRADNE na `ApplianceBinding.apply!`.
  NxTest.assert_equal(2, code.scan('start_operation').length,
                      'vlastne operacie ma LEN zapis `appliance_expects[]` a osadenie')
  NxTest.assert(code.include?('APPL_EXPECTS_OP'), 'a su pomenovane konstantou')
  NxTest.assert(code.include?('model.start_operation(APPL_MOUNT_OP, true)'), 'aj osadenie')
  NxTest.assert(code.include?('CabinetBuilder.guarded'), 'zapis configu bezi pod ScaleWatch guardom')
end

# ---------------------------------------------------------------------------
# 6) GUARDY DAVKY
# ---------------------------------------------------------------------------

NxTest.test('S1-B2: whitelist sekcie pribudol PRESNE o `appl_job_select`') do
  NxTest.assert(NxS1B2::AD::SECTION_ACTIONS.include?('appl_job_select'))
  writers = NxS1B2::AD::SECTION_ACTIONS.select { |a| a.start_with?('appl_job') }
  NxTest.assert_equal(['appl_job_select'], writers,
                      'zapisy pohladu idu kanalom ROZPOCTU — sekcia vlastnu zapisovu akciu NEMA')
end

NxTest.test('S1-B2: `appl_job_select` je CISTE CITANIE (ziadna operacia)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'appliance_dialog.rb'),
                  encoding: 'UTF-8')
  body = src[/def handle_job_select.*?\n        end\n/m].to_s
  target = src[/def job_select_target.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty? && !target.empty?, 'handler aj resolver sa nasli')
  NxTest.refute(body.include?('start_operation'), 'oznacenie nie je krok Spat')
  NxTest.assert(target.include?('ApplianceBinding.instances_of'),
                'identitu overuje TA ISTA funkcia ako vazba')
  NxTest.assert(target.include?('persistent_id'), 'a PID musi sediet (ID sa recykluju)')
end

# Codex #383 kolo 1 (P2): klik zo ZASTARANEHO pohladu sa nesmie vykonat.
NxTest.test('S1-B2 (kolo 1 P2): „oko" odmietne cudzi dokument aj stare kolo okna') do
  ad = NxS1B2::AD
  model = Object.new
  stub = lambda do |claimed, gen, &blk|
    dk = Noxun::Engine::DocKey.singleton_class
    sd = Noxun::Engine::StudioDialog.singleton_class
    old_foreign = dk.instance_method(:foreign?)
    old_gen = sd.instance_method(:generation)
    dk.send(:define_method, :foreign?) { |asked, _m, **_o| asked.to_s != 'DOC-1' }
    sd.send(:define_method, :generation) { 7 }
    begin
      blk.call(ad.job_view_stale?({ 'model_guid' => claimed, 'gen' => gen }, model))
    ensure
      dk.send(:define_method, :foreign?, old_foreign)
      sd.send(:define_method, :generation, old_gen)
    end
  end
  stub.call('DOC-1', 7) { |stale| NxTest.refute(stale, 'ten isty dokument a to iste kolo') }
  stub.call('DOC-2', 7) { |stale| NxTest.assert(stale, 'INY dokument = odmietnut') }
  stub.call('DOC-1', 6) { |stale| NxTest.assert(stale, 'STARE kolo okna = odmietnut') }
  stub.call('', 7) { |stale| NxTest.assert(stale, 'chybajuca identita sa NETOLERUJE') }
  stub.call('DOC-1', nil) { |stale| NxTest.assert(stale, 'ani chybajuca generacia') }

  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'appliance_dialog.rb'),
                  encoding: 'UTF-8')
  body = src[/def handle_job_select.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('job_view_stale?'), 'guard bezi v handleri, nie az v resolveri')
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'appliances.js'),
                 encoding: 'UTF-8')
  NxTest.assert(js.include?('model_guid: AP_JOB_DOC.guid') && js.include?('gen: AP_JOB_DOC.gen'),
                'klient identitu payloadu posiela')
end

NxTest.test('S1-B2: `?v=` vo vsetkych html = presne VERSION') do
  ver = Noxun::Engine::VERSION
  Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', 'ui', '*.html')).each do |f|
    File.read(f, encoding: 'UTF-8').scan(/\?v=([0-9.]+)/).flatten.uniq.each do |v|
      NxTest.assert_equal(ver, v, "#{File.basename(f)} ma cache-bust #{v}")
    end
  end
end

NxTest.test('S1-B2: novy JS panela je v panel.html a ma ikony zo spritu') do
  html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  NxTest.assert(html.include?('js/appliance_row.js?v='), 'subor sa nacitava')
  NxTest.assert(html.include?('id="applRows"') && html.include?('id="boardApplRows"'),
                'oba kontajnery su v HTML')
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'appliance_row.js'),
                 encoding: 'UTF-8')
  icons = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'),
                    encoding: 'UTF-8')
  used = js.scan(/aprIco\('([a-z0-9-]+)'\)/).flatten.uniq
  missing = used.reject { |i| icons.include?("'#{i}':") }
  NxTest.assert(missing.empty?, "ikony mimo spritu: #{missing.join(' · ')}")
end
