# frozen_string_literal: true
# Testy 1d/R-06a: BRANA dlzkoveho kovania — polozka, ktora sa REZE NA DLZKU
# (uchytkovy profil D-90, params['cut_length_mm'], cena katalogu za METER),
# sa cez set NESMIE nacenit ako KUSY (price x quantity).
#
# Co brana garantuje:
#   * expand taku polozku do naceneneho riadku NEDA — vyda ORANGE dovod
#     `length_unsupported` (sekcia NEMAPOVANE nesie rozmer, D-90);
#   * rozpocet aj cenova ponuka citaju TIE ISTE `rows`, takze sa k nej
#     nedostanu;
#   * panel (explain) hovori to iste co supis — ziadne cislo, ktore v nakupe
#     nevznikne;
#   * KUSOVE polozky (panty, nohy, vysuvy, kusova uchytka) sa NEMENIA.
#
# Plny rezim `per: 'length'` (Σ mm, MJ „m") pride s R-05 v bloku KOVANIE —
# dovtedy je toto jedina hranica a plati aj pre sety ulozene v starsom .skp.
require_relative '../helper' unless defined?(NxTest)

module NxR06
  HWS = Noxun::Engine::HardwareSets
  HR  = Noxun::Engine::HardwareRules
  VAL = Noxun::Engine::Validation

  module_function

  # Uchytkovy profil na cele: rez = SIRKA dielca (D-90), cena katalogu za meter.
  def profile_item(cut = 597.0, over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'handle', 'quantity' => 1, 'rule_id' => 'uchytkovy-profil',
      'params' => (cut.nil? ? {} : { HR::LENGTH_PARAM => cut, 'profile' => 'ukw7' }),
      'source' => 'rule' }.merge(over)
  end

  # Kusova uchytka — TEN ISTY generic_type, ale bez dlzky rezu.
  def knob_item(over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'handle', 'quantity' => 2, 'rule_id' => 'uchytky-kusove',
      'params' => {}, 'source' => 'rule' }.merge(over)
  end

  def hinge_item(over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'hinge', 'quantity' => 2, 'rule_id' => 'zavesy-podla-vysky',
      'params' => {}, 'source' => 'rule' }.merge(over)
  end

  def set_def(sid, gt, code)
    { 'set_id' => sid, 'name' => sid, 'generic_type' => gt,
      'members' => [{ 'code' => code, 'per' => 'unit', 'qty' => 1 }] }
  end

  # Michal si namapoval uchytku na set — presne stav, ktory registru vadi.
  def state
    sets = {}
    [set_def('profil-ukw', 'handle', 'UKW7'),
     set_def('zaves-basic', 'hinge', 'H100')].each { |s| sets[s['set_id']] = s }
    { 'mapping' => { 'handle' => 'profil-ukw', 'hinge' => 'zaves-basic' }, 'sets' => sets }
  end

  def catalog
    [{ 'item_code' => 'UKW7', 'name_sk' => 'Úchytkový profil UKW7', 'category' => 'UCHYTKY',
       'unit' => 'm', 'price_eur_vat' => 12.5, 'supplier' => 'Demos' },
     { 'item_code' => 'H100', 'name_sk' => 'Záves Sensys', 'category' => 'ZAVESY',
       'unit' => 'ks', 'price_eur_vat' => 3.5, 'supplier' => 'Demos' }]
  end

  def expand(items)
    HWS.expand(items, state, catalog: catalog)
  end
end

# --- 1) brana: nacenenie ako kusy NEVZNIKNE -----------------------------------

NxTest.test('R-06 brána: profil rezaný na dĺžku sa cez set NENACENÍ ako kusy') do
  exp = NxR06.expand([NxR06.profile_item])
  # ziadny nacene(ny) riadok — cena 12,50 €/m sa nema com vynasobit
  NxTest.assert_equal([], exp['rows'], 'dlzkova polozka do nakupneho riadku NEPATRI')
  NxTest.assert_equal(0.0, exp['summary']['total_eur_vat'], 'do sumy neprispieva nic')
  NxTest.assert_equal(0, exp['summary']['quantity'])
  NxTest.assert_equal(1, exp['summary']['unmapped'])

  u = exp['unmapped'].first
  NxTest.assert_equal('length_unsupported', u['reason'])
  NxTest.assert_equal('profil-ukw', u['set_id'], 'dovod ukazuje set, ktory to chcel nacenit')
  NxTest.assert_equal('CAB-1', u['cabinet_id'])
  NxTest.assert_equal('front:F1/panel', u['owner_part_key'])
  # D-90: rozmer musi prezit — bez neho sa profil neda objednat rucne
  NxTest.assert_equal('rez 597 mm', u['params_label'])
end

NxTest.test('R-06 brána: dôvod je v kanonickom zozname UNMAPPED_REASONS') do
  NxTest.assert(NxR06::HWS::UNMAPPED_REASONS.include?('length_unsupported'),
                'zoznam dovodov je jedina autorita — novy dovod do neho patri')
end

# --- 2) uzky rozsah: kusove polozky sa NEMENIA --------------------------------

NxTest.test('R-06 brána: kusové položky ostávajú bajtovo nedotknuté') do
  base = NxR06.expand([NxR06.hinge_item, NxR06.knob_item])
  withp = NxR06.expand([NxR06.hinge_item, NxR06.knob_item, NxR06.profile_item])
  NxTest.assert_equal(JSON.generate(base['rows']), JSON.generate(withp['rows']),
                      'pridanie dlzkovej polozky nesmie zmenit ANI JEDEN kusovy riadok')
  NxTest.assert_equal(base['summary']['total_eur_vat'], withp['summary']['total_eur_vat'])
  NxTest.assert_equal([], base['unmapped'], 'kusove polozky nemaju co hlasit')
  # kusova uchytka na TOM ISTOM sete sa nacenuje dalej (zakaz typu by ju vzal tiez)
  knob = NxR06.expand([NxR06.knob_item])
  NxTest.assert_equal(1, knob['rows'].length)
  NxTest.assert_equal(2, knob['rows'].first['quantity'])
  NxTest.assert_equal(25.0, knob['rows'].first['subtotal_eur_vat'])
end

NxTest.test('R-06 brána: spúšťa ju LEN kladná dĺžka rezu, nič iné') do
  # ziadna dlzka / nula / necislo / iny dlzkovy parameter (NL vysuvu) = kusova cesta
  [NxR06.profile_item(nil), NxR06.profile_item(0.0), NxR06.profile_item(-5.0),
   NxR06.profile_item('597'),
   NxR06.knob_item('params' => { 'nominal_length' => 450.0 })].each do |it|
    exp = NxR06.expand([it])
    NxTest.assert_equal(1, exp['rows'].length, "polozka bez dlzky rezu sa nacenuje: #{it['params']}")
    NxTest.assert_equal([], exp['unmapped'])
  end
end

# --- 3) hlaska: preco a co s tym (s rozmerom) ---------------------------------

NxTest.test('R-06 hláška: dôvod aj semafor nesú rozmer a povedia, čo s tým') do
  exp = NxR06.expand([NxR06.profile_item])
  u = exp['unmapped'].first

  short = NxR06::HWS.unmapped_reason_sk(u)
  NxTest.assert(short.include?('rez 597 mm'), "kratky dovod nesie rozmer: #{short}")
  NxTest.assert(short.include?('profil-ukw'), 'kratky dovod nesie set')
  NxTest.assert(short.include?('počíta kusy'), 'kratky dovod povie PRECO')

  items = []
  NxR06::VAL.check_hardware_expansion(exp, items)
  row = items.find { |i| i['message_sk'].include?('reže na dĺžku') }
  NxTest.assert(!row.nil?, 'semafor ORANGE riadok chyba')
  NxTest.assert_equal(NxR06::VAL::ORANGE, row['severity'], 'NIKDY tvrdy blok — len ORANGE')
  NxTest.assert_equal('CAB-1', row['owner_id'], 'klik-select mieri na skrinku')
  NxTest.assert(row['message_sk'].include?('rez 597 mm'), "semafor nesie rozmer: #{row['message_sk']}")
  NxTest.assert(row['message_sk'].include?('ručne'), 'semafor povie, CO S TYM')
  NxTest.assert(row['stable_key'].include?('length_unsupported'),
                'stable_key nesie dovod — iny problem tej istej polozky ho neprebije')

  # nakupny CSV: nemapovana sekcia (rozmer je v stlpci „rozmer"), ZIADNY nacene(ny) riadok
  csv = NxR06::HWS.purchase_csv(exp, project: 'T', generated_at: '2026-08-29')
  NxTest.assert(csv.include?('NEMAPOVANÉ'), 'CSV ma sekciu nemapovanych')
  NxTest.assert(csv.include?('rez 597 mm'), 'CSV nesie rozmer profilu')
  NxTest.assert(!csv.include?('12,5') && !csv.include?('12.5'), 'cena za meter sa v CSV neobjavi')
end

# --- 4) peniaze: rozpocet a cenova ponuka -------------------------------------

NxTest.test('R-06 peniaze: rozpočet ani cenová ponuka tú položku nenacenia') do
  exp = NxR06.expand([NxR06.profile_item, NxR06.hinge_item])

  sec = Noxun::Engine::Budget.hardware_section(exp, NxR06.catalog)
  keys = sec['rows'].map { |r| r['key'] }
  NxTest.assert(!keys.include?('hw:ukw7'), "rozpocet nesmie mat riadok profilu: #{keys}")
  NxTest.assert(keys.include?('hw:h100'), 'zavesy sa nacenuju dalej')
  NxTest.assert(sec['rows'].none? { |r| r['kod'].to_s.casecmp('UKW7').zero? })

  spec = Noxun::Engine::CpExport.specification([], hardware_expansion: exp)
  labels = spec['categories'].flat_map { |c| c['items'] }
  NxTest.assert(!labels.include?('Úchytkový profil UKW7'), "CP nesmie profil ponukat: #{labels}")
  NxTest.assert(labels.include?('Záves Sensys'), 'ostatne kovanie v CP ostava')
end

# --- 5) panel = supis (explain) -----------------------------------------------

NxTest.test('R-06 panel: explain ukáže ten istý dôvod a ŽIADNE členy s cenou') do
  out = NxR06::HWS.explain(NxR06.profile_item, NxR06.state, catalog: NxR06.catalog)
  NxTest.assert_equal('profil-ukw', out['set_id'], 'set sa pomenuje — pouzivatel vidi, co si zvolil')
  NxTest.assert_equal([], out['members'], 'ziadne cislo, ktore v nakupe nevznikne')
  NxTest.assert_equal(1, out['problems'].length)
  NxTest.assert(out['problems'].first.include?('rez 597 mm'))
  # kusova polozka na tom istom sete sa v paneli rozpisuje dalej
  knob = NxR06::HWS.explain(NxR06.knob_item, NxR06.state, catalog: NxR06.catalog)
  NxTest.assert_equal([], knob['problems'])
  NxTest.assert_equal(1, knob['members'].length)
  NxTest.assert_equal(2, knob['members'].first['qty'])
end
