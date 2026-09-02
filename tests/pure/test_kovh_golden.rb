# frozen_string_literal: true
# KOV-H1 — GOLDEN CHARAKTERIZACIA NAKUPU KOVANIA (dokaz „bez ad-hoc poloziek
# sa nakup ani CSV nezmenia ani o bajt").
#
# PRECO: KOV-H1 pridava do `HardwareSets.expand` DRUHY KANAL (ad-hoc polozky
# `hardware_manual`) PRED set rezoluciou a rozsiruje riadky o `origin`/`free`.
# Zavazok davky je, ze zakazka BEZ ad-hoc poloziek dava PRESNE to, co dnes.
# Golden subory su odtlacok stavu z MAINU (pred zmenou) pre 6 reprezentativnych
# scenarov; test porovnava CERSTVY vypocet s nimi — a to ISTE porovnanie musi
# prejst PO implementacii (inak je zmena regresia, nie aditivny kanal).
#
# CO SA ODTLACA: cely vystup `expand` (rows / unmapped / summary) A K TOMU
# `purchase_csv` ako SUROVY TEXT — bajtova identita CSV je samostatny zavazok
# (audit FIX 13: „nakupny CSV bez noveho stlpca"), ktory by porovnanie
# strukturovaneho vystupu samo o sebe nedokazalo (poradie stlpcov, sekcia
# NEMAPOVANE, desatinna ciarka, CRLF).
#
# KATALOG JE FIXNY (nie `HardwareCatalog.items`): golden nesmie zavisiet od
# obsahu %APPDATA% katalogu — inak by sa „rozisiel" pri kazdej zmene ceny.
#
# SPUSTA SA RUCNE (test generator NEVOLA — inak by charakterizacia „dokazovala"
# samu seba):  C:/Ruby32-x64/bin/ruby.exe tests/fixtures/kovh_golden/generate.rb
require_relative '../helper' unless defined?(NxTest)

require 'json'

module NxKovhGolden
  E  = Noxun::Engine
  HS = E::HardwareSets

  FIXTURES = File.join(NxTest::ROOT, 'tests', 'fixtures', 'kovh_golden')

  # Fixny katalog — kody, ktore sa v scenaroch pouzivaju. `ZABUDNUTY` v nom
  # zamerne NIE JE (scenar „kod mimo katalogu").
  CATALOG = [
    { 'item_code' => 'BLUM-71B3550', 'name_sk' => 'Záves Clip Top 110°',
      'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 3.42 },
    { 'item_code' => 'BLUM-TIPON', 'name_sk' => 'TipOn krátky',
      'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 2.10 },
    { 'item_code' => 'HET-Q470', 'name_sk' => 'Quadro V6 470 mm',
      'category' => 'VYSUVY', 'unit' => 'par', 'price_eur_vat' => 18.90 },
    { 'item_code' => 'HET-Q500', 'name_sk' => 'Quadro V6 500 mm',
      'category' => 'VYSUVY', 'unit' => 'par', 'price_eur_vat' => 19.50 },
    { 'item_code' => 'AXILO-100', 'name_sk' => 'Noha AXILO 100 mm',
      'category' => 'NOHY', 'unit' => 'ks', 'price_eur_vat' => 1.15 }
  ].freeze

  module_function

  # --- stavebne kamene scenarov -------------------------------------------

  def set_def(sid, gt, members)
    { 'set_id' => sid, 'name' => sid, 'generic_type' => gt, 'members' => members }
  end

  # Projektovy snapshot { 'mapping' => ..., 'sets' => ... } z pola definicii.
  def state(mapping, defs)
    sets = {}
    HS.normalize_sets(defs).each { |s| sets[s['set_id']] = s }
    { 'mapping' => mapping, 'sets' => sets }
  end

  def item(over = {})
    { 'owner_id' => 'CAB-001', 'owner_part_key' => nil, 'generic_type' => 'hinge',
      'quantity' => 2, 'rule_id' => 'zavesy-podla-vysky', 'source' => 'rule',
      'params' => {} }.merge(over)
  end

  # --- scenare -------------------------------------------------------------
  #
  # Kazdy scenar = { 'items' => [...], 'state' => {...}, 'overrides' => {...} }.

  ZAVES_SET  = set_def('zaves-klasik', 'hinge', [{ 'code' => 'BLUM-71B3550', 'per' => 'unit', 'qty' => 1 }])
  # Clen `per: 'owner'` — TipOn sa uctuje NA VLASTNIKA (dedup v expand_members).
  TIPON_SET  = set_def('zaves-tipon', 'hinge',
                       [{ 'code' => 'BLUM-71B3550', 'per' => 'unit', 'qty' => 1 },
                        { 'code' => 'BLUM-TIPON', 'per' => 'owner', 'qty' => 1 }])
  # Rad podla NL (`code_by_nl`) — vyber kodu podla params.nominal_length.
  VYSUV_SET  = set_def('vysuv-quadro', 'slide',
                       [{ 'code_by_nl' => { '470' => 'HET-Q470', '500' => 'HET-Q500' },
                          'per' => 'unit', 'qty' => 1 }])
  NOHY_SET   = set_def('nohy-axilo', 'leg', [{ 'code' => 'AXILO-100', 'per' => 'unit', 'qty' => 1 }])
  # Set s kodom, ktory v katalogu NIE JE — riadok `missing: true`, bez ceny.
  CHYBA_SET  = set_def('nohy-neznama', 'leg', [{ 'code' => 'ZABUDNUTY', 'per' => 'unit', 'qty' => 1 }])

  CASES = {
    # 1) polozky z ROZNYCH skriniek — agregacia podla kodu cez cely projekt
    'viac_skriniek' => {
      'items' => [item, item('owner_id' => 'CAB-002', 'quantity' => 3),
                  item('owner_id' => 'CAB-003', 'quantity' => 2)],
      'state' => state({ 'hinge' => 'zaves-klasik' }, [ZAVES_SET])
    },
    # 2) clen `per: 'owner'` — dva zaznamy na TOM ISTOM vlastnikovi sa zlievaju
    'per_owner' => {
      'items' => [item('owner_part_key' => 'front:F1/wing:single'),
                  item('owner_part_key' => 'front:F1/wing:single', 'rule_id' => 'zavesy-extra'),
                  item('owner_part_key' => 'front:F2/wing:single')],
      'state' => state({ 'hinge' => 'zaves-tipon' }, [TIPON_SET])
    },
    # 3) `code_by_nl` — dve rozne NL a jedna NL mimo radu (ORANGE `nl_missing`)
    'code_by_nl' => {
      'items' => [item('generic_type' => 'slide', 'rule_id' => 'vysuv-podla-hlbky',
                       'quantity' => 1, 'params' => { 'nominal_length' => 470.0 }),
                  item('generic_type' => 'slide', 'rule_id' => 'vysuv-podla-hlbky',
                       'owner_id' => 'CAB-002', 'quantity' => 2,
                       'params' => { 'nominal_length' => 500.0 }),
                  item('generic_type' => 'slide', 'rule_id' => 'vysuv-podla-hlbky',
                       'owner_id' => 'CAB-003', 'quantity' => 1,
                       'params' => { 'nominal_length' => 419.6 })],
      'state' => state({ 'slide' => 'vysuv-quadro' }, [VYSUV_SET])
    },
    # 4) D-93 rucny zasah (`source: 'manual'`) — `manual_quantity` + `manual_note`
    'manual_d93' => {
      'items' => [item('generic_type' => 'slide', 'rule_id' => 'vysuv-podla-hlbky',
                       'quantity' => 1, 'source' => 'manual',
                       'params' => { 'nominal_length' => 470.0 },
                       'rule_nominal_length' => 500.0),
                  item('generic_type' => 'slide', 'rule_id' => 'vysuv-podla-hlbky',
                       'owner_id' => 'CAB-002', 'quantity' => 1,
                       'params' => { 'nominal_length' => 470.0 })],
      'state' => state({ 'slide' => 'vysuv-quadro' }, [VYSUV_SET])
    },
    # 5) NEMAPOVANA polozka — typ bez setu (sekcia NEMAPOVANE v CSV)
    'nemapovana' => {
      'items' => [item, item('generic_type' => 'leg', 'rule_id' => 'nohy-fixne', 'quantity' => 4)],
      'state' => state({ 'hinge' => 'zaves-klasik' }, [ZAVES_SET])
    },
    # 6) KOD MIMO KATALOGU — riadok `missing: true`, cena nil, sekcia
    #    „MIMO KATALÓGU" v CSV + override skrinky (druha cesta k setu)
    'chybajuci_kod' => {
      'items' => [item('generic_type' => 'leg', 'rule_id' => 'nohy-fixne', 'quantity' => 4),
                  item('generic_type' => 'leg', 'rule_id' => 'nohy-fixne',
                       'owner_id' => 'CAB-002', 'quantity' => 4)],
      'state' => state({ 'leg' => 'nohy-axilo' }, [NOHY_SET, CHYBA_SET]),
      'overrides' => { 'CAB-002' => { 'leg' => 'nohy-neznama' } }
    }
  }.freeze

  # Rekurzivny prevod na cisty JSON tvar + zaokruhlenie Floatov (reprezentacia
  # Floatu sa medzi behmi lisi na poslednom bite, hodnota nie).
  def norm(value)
    case value
    when Hash  then value.each_with_object({}) { |(k, v), out| out[k.to_s] = norm(v) }
    when Array then value.map { |v| norm(v) }
    when Float then value.round(3)
    when Symbol then value.to_s
    else value
    end
  end

  def expand_of(kase)
    HS.expand(kase['items'], kase['state'],
              cabinet_overrides: (kase['overrides'] || {}), catalog: CATALOG)
  end

  # Odtlacok jedneho scenara: expanzia + SUROVY text nakupneho CSV.
  # `generated_at`/`project` su FIXNE — inak by sa golden rozisiel s casom.
  def snapshot(kase)
    exp = expand_of(kase)
    { 'expand' => norm(exp),
      'csv' => HS.purchase_csv(exp, project: 'GOLDEN', generated_at: '2026-09-03 00:00') }
  end

  def golden_path(name)
    File.join(FIXTURES, "#{name}.json")
  end

  def golden(name)
    JSON.parse(File.read(golden_path(name)))
  end
end

NxKovhGolden::CASES.each_key do |name|
  NxTest.test("KOV-H1 golden: #{name} — expanzia aj nakupny CSV su zhodne s odtlackom z mainu") do
    g = NxKovhGolden
    path = g.golden_path(name)
    NxTest.assert(File.file?(path), "chyba golden subor #{path} (spusti tests/fixtures/kovh_golden/generate.rb)")
    want = g.golden(name)
    have = g.snapshot(g::CASES[name])
    NxTest.assert_equal(want['expand']['summary'], have['expand']['summary'], "#{name}: summary sa rozisiel")
    NxTest.assert_equal(want['expand']['unmapped'], have['expand']['unmapped'], "#{name}: unmapped sa rozisiel")
    NxTest.assert_equal(want['expand']['rows'].length, have['expand']['rows'].length, "#{name}: iny pocet riadkov")
    want['expand']['rows'].each_with_index do |wr, i|
      NxTest.assert_equal(wr, have['expand']['rows'][i], "#{name}: riadok ##{i + 1} (#{wr['code']}) sa rozisiel")
    end
    # BAJTOVA identita CSV — samostatny zavazok davky (audit FIX 13).
    NxTest.assert_equal(want['csv'], have['csv'], "#{name}: nakupny CSV sa rozisiel s goldenom")
  end
end

NxTest.test('KOV-H1 golden: sada pokryva vsetky ulozene fixtures (ziadny osirely subor)') do
  files = Dir[File.join(NxKovhGolden::FIXTURES, '*.json')].map { |p| File.basename(p, '.json') }.sort
  NxTest.assert_equal(NxKovhGolden::CASES.keys.sort, files,
                      'zoznam golden suborov nesedi so zoznamom pripadov CASES')
end
