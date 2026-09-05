# frozen_string_literal: true
# Testy KOV-B1: KLASIFIKACIA SETOV KOVANIA, std 3, triedny kluc `class:` a
# bezstratova brana definicii setov v sablone.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1  slovniky su UZAVRETE a doména setov drzi JEDNU pravdu s `Fronts`
#   R2  zapis: klasifikacia bud UPLNE chyba (legacy „nezaradeny"), alebo je
#       UPLNA a kontextovo platna; `generic_type` je ODVODENY kanonickou mapou
#   R3  citanie: tolerantne, ale CELE-ALEBO-VOBEC — a strata sa PRIZNA
#       (4. vrstva detektora `classification_lost?` vo VSETKYCH troch branach)
#   R4  `active` je sparse a `expand`/`explain`/`resolve_set_id` ho NECITAJU
#   R5  `save_set!` MERGUJE klasifikaciu z ulozeneho setu (editor posiela 4
#       kluce) a vracia STRUKTUROVANE chyby `{row, field, msg}`
#   R6  `snapshot_std` bumpne na 3 per KAZDE nove pole samostatne; legacy nie
#   R7  `class:` kluc round-tripuje, ale expanzia ho IGNORUJE
#   R8  `assess_set_defs` — sablona z novsej verzie sa ODMIETNE bez zapisu
#   R13 charakterizacia: klasifikovana kopia seed setu nakupuje IDENTICKY
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do core spadne uvedeny test):
#   M1 `read_set_classification` doplni klasifikaciu aj legacy setu
#      -> „KOV-B1 (M1): legacy setu sa klasifikacia NIKDY nedoplna"
#   M2 `read_active` ulozi aj `true` (sparse zrusene)
#      -> „KOV-B1 (M2): `active` je SPARSE — uklada sa LEN false"
#   M3 `assess_set_defs` pusti definiciu z novsej verzie (brana vypnuta)
#      -> „KOV-B1 (M3): sablona s definiciami z NOVSEJ verzie sa ODMIETNE…"
#   M4 `parse_mapping` triedny kluc zahodi (round-trip nebezstratovy)
#      -> „KOV-B1 (M4): triedny kluc round-tripuje…"
#   M5 `save_set!` neurobi merge klasifikacie (4-klucovy vstup ju zhodi)
#      -> „KOV-B1 (M5): uprava clena zo 4-kluc. editora klasifikaciu ZACHOVA"
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

# UI vrstva (brana vkladu) — headless nie je v require zozname helpera.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
end

module NxB1
  E     = Noxun::Engine
  HWS   = E::HardwareSets
  TAX   = E::HardwareTaxonomy
  STORE = E::JsonFileStore
  BP    = E::BuildPlan
  PANEL = E::Panel

  # Uplna a platna klasifikacia zavesu (vyrobca aj rada su v seede taxonomie).
  DOOR = { 'use_type' => 'door', 'opening_mode' => 'classic',
           'manufacturer' => 'Hettich', 'series' => 'Sensys' }.freeze

  module_function

  # --- sandbox ------------------------------------------------------------

  # Ulozi kniznicu AJ taxonomiu a vrati PRESNY povodny stav (vzor R-07/R-08).
  def with_library
    paths = [HWS.path, TAX.path]
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    yield
  ensure
    before.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
      FileUtils.rm_f("#{p}.bak")
      STORE.invalidate(p)
    end
    HWS.reset_library_state!
    TAX.reset_state!
  end

  # Zapise dokument kniznice PRIAMO na disk (obide brany).
  def install(doc)
    FileUtils.mkdir_p(File.dirname(HWS.path))
    File.binwrite(HWS.path, JSON.pretty_generate(doc))
    STORE.invalidate(HWS.path)
    HWS.reset_library_state!
    true
  end

  def raw_lib
    JSON.parse(File.binread(HWS.path))
  end

  # PRAZDNA kniznica spadne v `read_library` na SEED (historicke spravanie),
  # takze zapisove testy startuju z JEDNEHO nesuvisiaceho setu — inak by
  # `load['sets'].first` bol seed „zaves-klasik" a nie to, co testujeme.
  def install_base
    install(doc([set_def('set_id' => 'zaklad', 'name' => 'Základ')]))
  end

  def stored(sid)
    HWS.load['sets'].find { |s| s['set_id'] == sid }
  end

  def doc(sets, mapping = {}, over = {})
    { 'std' => HWS::STD, 'seed_version' => HWS::SEED_VERSION,
      'sets' => sets, 'mapping' => mapping }.merge(over)
  end

  # --- fixtury ------------------------------------------------------------

  def set_def(over = {})
    { 'set_id' => 'zaves-a', 'name' => 'Záves A', 'generic_type' => 'hinge',
      'members' => [{ 'code' => 'KOD-1', 'per' => 'unit', 'qty' => 1 }] }.merge(over)
  end

  def classified(over = {})
    set_def(DOOR.merge(over))
  end

  def model_with(state = nil)
    m = NxTest::FakeEntity.new
    m.set_attribute(E::Store::DICT, HWS::MODEL_KEY, state.to_json) if state
    m
  end

  def snapshot_of(sets, mapping)
    by_id = {}
    HWS.normalize_sets(sets).each { |s| by_id[s['set_id']] = s }
    { 'std' => HWS.snapshot_std(mapping, by_id.values), 'mapping' => mapping, 'sets' => by_id }
  end

  def hinge_item(over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/wing:single',
      'generic_type' => 'hinge', 'quantity' => 2, 'rule_id' => 'zavesy',
      'params' => {}, 'source' => 'rule' }.merge(over)
  end

  # Projektovy stav zo seed kniznice (charakterizacia R13).
  def seed_state(sets)
    by_id = {}
    HWS.normalize_sets(sets).each { |s| by_id[s['set_id']] = s }
    { 'mapping' => HWS::SEED_MAPPING.dup, 'sets' => by_id }
  end

  # Klasifikovana KOPIA seed setu — typ pouzitia podla typu kovania.
  USE_BY_GT = { 'hinge' => %w[door classic], 'slide' => %w[drawer classic],
                'leg' => %w[other other], 'wall_hanger' => %w[other other],
                'shelf_pin' => %w[other other] }.freeze

  def classify_seed(set)
    ut, om = USE_BY_GT[set['generic_type']]
    out = set.merge('use_type' => ut, 'opening_mode' => om, 'manufacturer' => 'Hettich')
    out['drawer_construction'] = 'metal' if ut == 'drawer'
    out
  end

  # KOV-C2a: cast seed setov je klasifikovana UZ V ZDROJI (drawer sety
  # zasuviek), takze „nezaradeny" pol charakterizacie R13 sa musi vyrobit
  # ODOBRATIM klasifikacie — inak by test porovnaval dva klasifikovane stavy
  # a o metadata-vs-nakup by nepovedal nic.
  def strip_class(set)
    out = set.dup
    (HWS::CLASS_KEYS + ['active']).each { |k| out.delete(k) }
    out
  end
end

# ============================================================================
# 1) SLOVNIKY A KONTRAKT (R1)
# ============================================================================

NxTest.test('KOV-B1 (R1): slovniky klasifikacie su uzavrete a `SET_KEYS` je ich sucet') do
  b = NxB1
  NxTest.assert_equal(%w[door drawer lift fall other], b::HWS::USE_TYPES)
  NxTest.assert_equal(%w[classic tipon other], b::HWS::OPENING_MODES)
  NxTest.assert_equal(%w[metal wood other], b::HWS::DRAWER_CONSTRUCTIONS)
  NxTest.assert_equal(%w[set_id name generic_type members], b::HWS::LEGACY_SET_KEYS,
                      'legacy tvar je zaklad detekcie std — nesmie sa hybat')
  NxTest.assert_equal(b::HWS::LEGACY_SET_KEYS + b::HWS::CLASS_KEYS + ['active'],
                      b::HWS::SET_KEYS, 'whitelist je KONTRAKT: legacy + klasifikacia + active')
  # Kanonicka mapa pokryva vsetky typy pouzitia okrem `other` a jej ciele su
  # v slovniku BuildPlan (`lift` sem pribudol prave v tejto davke).
  NxTest.assert_equal(%w[door drawer lift fall].sort, b::HWS::USE_TYPE_GENERIC.keys.sort)
  b::HWS::USE_TYPE_GENERIC.each_value do |gt|
    NxTest.assert(b::BP::GENERIC_TYPES.include?(gt), "cielovy typ #{gt} musi byt v GENERIC_TYPES")
  end
  NxTest.assert(b::BP::GENERIC_TYPES.include?('lift'), 'KOV-B1 pridava typ `lift`')
end

NxTest.test('KOV-B1 (R1): sety a cela drzia JEDNU domenovu pravdu (Fronts vs HardwareSets)') do
  f = Noxun::Engine::Fronts
  h = NxB1::HWS
  # `Fronts` sa nacitava PO `hardware_sets`, takze vazba nemoze byt referenciou —
  # drzi ju tento guard. Sety maju NAVYSE `other` („neuplatnuje sa" pri nohach,
  # podperkach a zaveseni), preto podmnozina, nie rovnost.
  NxTest.assert_equal([], f::OPENING_MODES - h::OPENING_MODES,
                      'kazdy sposob otvarania cela musi vediet aj set')
  NxTest.assert_equal(h::DRAWER_CONSTRUCTIONS, f::DRAWER_CONSTRUCTIONS,
                      'konstrukcia zasuvky je ta ista domena na oboch stranach')
  NxTest.assert(h::OPENING_MODES.include?('other'), 'sety maju navyse „neuplatnuje sa"')
end

# ============================================================================
# 2) ZAPIS: all-or-nothing + kanonicka mapa (R2)
# ============================================================================

NxTest.test('KOV-B1 (R2): legacy set BEZ klasifikacie sa uklada presne ako doteraz') do
  norm, errs = NxB1::HWS.validate_set(NxB1.set_def)
  NxTest.assert_equal([], errs)
  NxTest.assert_equal(%w[set_id name generic_type members], norm.keys,
                      'nezaradeny set nema ani jeden klasifikacny kluc')
end

NxTest.test('KOV-B1 (R2): uplna klasifikacia sa uklada v PEVNOM poradi klucov') do
  norm, errs = NxB1::HWS.validate_set(NxB1.classified)
  NxTest.assert_equal([], errs)
  NxTest.assert_equal(%w[set_id name generic_type use_type opening_mode
                         manufacturer series members], norm.keys)
end

NxTest.test('KOV-B1 (R2): CIASTOCNA klasifikacia sa ODMIETNE (nie doplni)') do
  b = NxB1
  %w[use_type opening_mode manufacturer].each do |only|
    _, errs = b::HWS.validate_set(b.set_def(only => b::DOOR[only]))
    NxTest.assert(!errs.empty?, "samotne `#{only}` je ciastocny tvar a musi padnut")
  end
  norm, = b::HWS.validate_set(b.classified.tap { |s| s.delete('series') })
  NxTest.assert(!norm.nil?, 'rada je VOLITELNA — bez nej je klasifikacia uplna')
  NxTest.refute(norm.key?('series'), 'prazdna rada sa neuklada')
  norm2, = b::HWS.validate_set(b.classified('series' => '  '))
  NxTest.refute(norm2.key?('series'), 'prazdny retazec = kluc sa neuklada')
end

NxTest.test('KOV-B1 (R2): `drawer_construction` je PRAVE pri zasuvke') do
  b = NxB1
  _, errs = b::HWS.validate_set(b.set_def('use_type' => 'drawer', 'opening_mode' => 'classic',
                                          'manufacturer' => 'Hettich', 'generic_type' => 'slide'))
  NxTest.assert(errs.first.to_s.include?('konštrukciu'), "chybajuca konstrukcia: #{errs.inspect}")
  _, errs2 = b::HWS.validate_set(b.classified('drawer_construction' => 'metal'))
  NxTest.assert(errs2.first.to_s.include?('len set na zásuvky'), errs2.inspect)
  norm, errs3 = b::HWS.validate_set(b.set_def('use_type' => 'drawer', 'opening_mode' => 'tipon',
                                              'drawer_construction' => 'metal',
                                              'manufacturer' => 'Hettich',
                                              'generic_type' => 'slide'))
  NxTest.assert_equal([], errs3)
  NxTest.assert_equal('metal', norm['drawer_construction'])
end

NxTest.test('KOV-B1 (R2): `generic_type` je ODVODENY — chybajuci sa doplni, nesediaci padne') do
  b = NxB1
  bez = b.classified
  bez.delete('generic_type')
  norm, errs = b::HWS.validate_set(bez)
  NxTest.assert_equal([], errs)
  NxTest.assert_equal('hinge', norm['generic_type'], 'door -> hinge')
  # nesediaca kombinacia = odmietnutie s vetou, ktora obe strany MENUJE
  _, errs2 = b::HWS.validate_set(b.set_def('use_type' => 'drawer', 'opening_mode' => 'classic',
                                           'drawer_construction' => 'metal',
                                           'manufacturer' => 'Hettich', 'generic_type' => 'hinge'))
  NxTest.assert(errs2.first.include?('slide') && errs2.first.include?('hinge'), errs2.inspect)
  # vsetky odvodenia mapy
  { 'door' => 'hinge', 'drawer' => 'slide', 'lift' => 'lift', 'fall' => 'lift' }.each do |ut, gt|
    s = b.set_def('use_type' => ut, 'opening_mode' => 'classic', 'manufacturer' => 'Hettich')
    s['drawer_construction'] = 'metal' if ut == 'drawer'
    s.delete('generic_type')
    NxTest.assert_equal(gt, b::HWS.validate_set(s)[0]['generic_type'], "#{ut} -> #{gt}")
  end
end

NxTest.test('KOV-B1 (R2): `use_type: other` vyzaduje EXPLICITNY typ kovania') do
  b = NxB1
  bez = b.set_def('use_type' => 'other', 'opening_mode' => 'other', 'manufacturer' => 'Hettich')
  bez.delete('generic_type')
  _, errs = b::HWS.validate_set(bez)
  NxTest.assert(!errs.empty?, 'mapa pre `other` neexistuje — typ musi prist')
  norm, = b::HWS.validate_set(b.set_def('use_type' => 'other', 'opening_mode' => 'other',
                                        'manufacturer' => 'Hettich', 'generic_type' => 'shelf_pin'))
  NxTest.assert_equal('shelf_pin', norm['generic_type'], 'podperky su legitimne „iné"')
end

NxTest.test('KOV-B1 (R2): neznama hodnota enumu = odmietnutie so STRUKTUROVANOU chybou') do
  b = NxB1
  { 'use_type' => 'sliding', 'opening_mode' => 'push' }.each do |field, bad|
    norm, errs = b::HWS.validate_set_detailed(b.classified(field => bad))
    NxTest.assert_equal(nil, norm)
    NxTest.assert(errs.any? { |e| e['field'] == field }, "chyba musi menovat pole #{field}: #{errs.inspect}")
    NxTest.assert(errs.all? { |e| e.key?('row') && e.key?('field') && e.key?('msg') },
                  'kontrakt B3: kazda chyba ma row/field/msg')
  end
  # chyba CLENA nesie index riadku
  _, errs = b::HWS.validate_set_detailed(
    b.classified('members' => [{ 'code' => 'A', 'per' => 'unit', 'qty' => 1 },
                               { 'per' => 'unit', 'qty' => 1 }])
  )
  NxTest.assert_equal([1], errs.map { |e| e['row'] }, 'druhy clen (index 1)')
  NxTest.assert_equal('members', errs.first['field'])
end

NxTest.test('KOV-B1 (R2): `validate_set` je CISTA — taxonomiu NEcita') do
  # Snapshot v .skp aj sablona cestuju medzi PC s inou taxonomiou; keby ju
  # `validate_set` vyzadovala, zakazka z ineho pocitaca by sa neotvorila.
  src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_sets.rb'))
            .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  body = src[/^      def validate_set_detailed.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'telo `validate_set_detailed` sa naslo')
  NxTest.refute(body.include?('HardwareTaxonomy'), 'validacia setu nesmie siahat na taxonomiu')
  classify = src[/^      def classify\(.*?\n      end\n/m].to_s
  NxTest.assert(!classify.empty?, 'telo `classify` sa naslo')
  NxTest.refute(classify.include?('HardwareTaxonomy'), 'ani pravidla klasifikacie')
end

# ============================================================================
# 3) CITANIE: tolerantne, CELE-ALEBO-VOBEC + detektor straty (R3)
# ============================================================================

NxTest.test('KOV-B1 (R3): platna klasifikacia sa PRECITA, `generic_type` sa nemeni') do
  norm = NxB1::HWS.normalize_sets([NxB1.classified]).first
  NxTest.assert_equal('door', norm['use_type'])
  NxTest.assert_equal('hinge', norm['generic_type'])
end

NxTest.test('KOV-B1 (R3): necitatelna klasifikacia sa zahodi CELA — set je „nezaradeny"') do
  b = NxB1
  cases = {
    'neznamy use_type' => b.classified('use_type' => 'sliding'),
    'neuplny blok' => b.set_def('use_type' => 'door'),
    'nesulad s mapou' => b.set_def('use_type' => 'drawer', 'opening_mode' => 'classic',
                                   'drawer_construction' => 'metal',
                                   'manufacturer' => 'Hettich', 'generic_type' => 'hinge')
  }
  cases.each do |why, raw|
    norm = b::HWS.normalize_sets([raw]).first
    NxTest.assert(!norm.nil?, "#{why}: set sa cita dalej (citanie nesmie zhodit prestavbu)")
    NxTest.assert_equal(raw['generic_type'], norm['generic_type'],
                        "#{why}: typ kovania (a teda NAKUP) sa NIKDY nemeni")
    NxTest.assert(b::HWS::CLASS_KEYS.none? { |k| norm.key?(k) },
                  "#{why}: klasifikacia sa zahadzuje CELA, nie po poliach")
    NxTest.assert(b::HWS.classification_lost?([raw], [norm]),
                  "#{why}: a strata sa PRIZNA (nikdy tichy orez)")
  end
end

NxTest.test('KOV-B1 (M1): legacy setu sa klasifikacia NIKDY nedoplna') do
  norm = NxB1::HWS.normalize_sets([NxB1.set_def]).first
  NxTest.assert(NxB1::HWS::CLASS_KEYS.none? { |k| norm.key?(k) },
                "nezaradeny set ostava nezaradeny: #{norm.inspect}")
  NxTest.refute(NxB1::HWS.classification_lost?([NxB1.set_def], [norm]),
                'a nie je to strata — nebolo co stratit')
end

NxTest.test('KOV-B1 (R3): whitelist pozna klasifikaciu — novy TVAR znameho kluca je nekompatibilny') do
  b = NxB1
  NxTest.refute(b::HWS.incompatible_set?(b.classified), 'platna klasifikacia je kompatibilna')
  NxTest.assert(b::HWS.incompatible_set?(b.classified('use_type' => %w[door drawer])),
                'pole namiesto skalaru = tvar novsej verzie')
  NxTest.assert(b::HWS.incompatible_set?(b.classified('manufacturer' => { 'id' => 1 })),
                'objekt namiesto mena = tvar novsej verzie')
  NxTest.assert(b::HWS.incompatible_set?(b.set_def('active' => 'zajtra')),
                '`active` je BOOL — datum je tvar novsej verzie')
  NxTest.refute(b::HWS.incompatible_set?(b.set_def('active' => false)))
  NxTest.refute(b::HWS.incompatible_set?(b.set_def('active' => true)))
  NxTest.assert(b::HWS.incompatible_set?(b.set_def('rating' => 3)), 'uplne neznamy kluc')
end

NxTest.test('KOV-B1 (R3): detektor straty bezi vo VSETKYCH TROCH branach') do
  b = NxB1
  b.with_library do
    # (1) globalna kniznica
    b.install(b.doc([b.classified('use_type' => 'sliding')]))
    NxTest.assert_equal(:read_only, b::HWS.library_state, 'kniznica z novsej verzie')
    NxTest.assert_equal(:unknown_shape, b::HWS.library_state_code)
    NxTest.assert_equal({ 'sets' => [], 'mapping' => {} }, b::HWS.load,
                        'a NIC sa z nej nevyda')
  end
  # (2) projektovy snapshot
  bad = { 'std' => 3, 'mapping' => {},
          'sets' => { 'zaves-a' => b.classified('use_type' => 'sliding') } }
  NxTest.assert_equal(:invalid, b::HWS.project_state_status(b.model_with(bad))[0])
  ok = { 'std' => 3, 'mapping' => {}, 'sets' => { 'zaves-a' => b.classified } }
  NxTest.assert_equal(:ok, b::HWS.project_state_status(b.model_with(ok))[0])
  # (3) definicie v sablone
  NxTest.assert_equal(:lossy, b::HWS.assess_set_defs([b.classified('use_type' => 'sliding')])[0])
  NxTest.assert_equal(:ok, b::HWS.assess_set_defs([b.classified])[0])
end

# ============================================================================
# 4) `active` je SPARSE a nakup ho NECITA (R4)
# ============================================================================

NxTest.test('KOV-B1 (M2): `active` je SPARSE — uklada sa LEN false') do
  b = NxB1
  NxTest.assert_equal(false, b::HWS.validate_set(b.set_def('active' => false))[0]['active'])
  NxTest.refute(b::HWS.validate_set(b.set_def('active' => true))[0].key?('active'),
                '`true` je default — kluc sa NEUKLADA')
  NxTest.refute(b::HWS.validate_set(b.set_def)[0].key?('active'), 'chybajuci kluc ostava chybajuci')
  NxTest.assert_equal(false, b::HWS.normalize_sets([b.set_def('active' => 'false')]).first['active'],
                      'citanie tolerantne pozna aj retazec')
  NxTest.refute(b::HWS.normalize_sets([b.set_def('active' => 'ano')]).first.key?('active'),
                'nezmyselna hodnota = kluc chyba')
end

NxTest.test('KOV-B1 (R4): `expand` aj `explain` `active` IGNORUJU (nakup je totozny)') do
  b = NxB1
  on  = b::HWS.normalize_sets([b.classified]).first
  off = b::HWS.normalize_sets([b.classified('active' => false)]).first
  NxTest.assert_equal(false, off['active'], 'fixture: priznak naozaj je')
  cat = [{ 'item_code' => 'KOD-1', 'name_sk' => 'Záves', 'category' => 'ZAVESY',
           'unit' => 'ks', 'price_eur_vat' => 2.0 }]
  st_on  = { 'mapping' => { 'hinge' => 'zaves-a' }, 'sets' => { 'zaves-a' => on } }
  st_off = { 'mapping' => { 'hinge' => 'zaves-a' }, 'sets' => { 'zaves-a' => off } }
  NxTest.assert_equal(b::HWS.expand([b.hinge_item], st_on, catalog: cat),
                      b::HWS.expand([b.hinge_item], st_off, catalog: cat),
                      'expanzia je deep-equal')
  NxTest.assert_equal(b::HWS.explain(b.hinge_item, st_on, catalog: cat),
                      b::HWS.explain(b.hinge_item, st_off, catalog: cat),
                      'aj rozpis polozky v paneli')
  # KOV-B3: ponuka UZ filtruje — je to JEDINE miesto, kde `active` nieco
  # rozhoduje. Expanzia, rozpis polozky ani resolver ostavaju nedotknute
  # (dva asserty vyssie), takze existujuce mapovanie nakupuje IDENTICKY.
  NxTest.assert_equal([],
                      b::HWS.set_options('hinge', [off], {}, []).map { |s| s['set_id'] },
                      'ponuka setov NEAKTIVNY set uz nenuka (KOV-B3)')
  NxTest.assert_equal(['zaves-a'],
                      b::HWS.set_options('hinge', [off], {}, ['zaves-a']).map { |s| s['set_id'] },
                      'ale REFERENCOVANY neaktivny set v ponuke OSTAVA (inak by select klamal)')
end

# ============================================================================
# 5) `save_set!` — merge, struktura chyb, taxonomia (R5)
# ============================================================================

NxTest.test('KOV-B1 (M5): uprava clena zo 4-kluc. editora klasifikaciu ZACHOVA') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    NxTest.assert_equal(:ok, b::HWS.save_set!(b.classified)[0], 'zaklad ulozeny')
    # PRESNE to, co posiela `hwsBuildSetPayload` v ui/js/hw_sets.js — 4 kluce.
    status, rec = b::HWS.save_set!({ 'set_id' => 'zaves-a', 'name' => 'Záves A',
                                     'generic_type' => 'hinge',
                                     'members' => [{ 'code' => 'KOD-2', 'per' => 'unit', 'qty' => 1 }] })
    NxTest.assert_equal(:ok, status)
    NxTest.assert_equal('KOD-2', rec['members'][0]['code'], 'clen sa naozaj zmenil')
    NxTest.assert_equal('door', rec['use_type'], 'a klasifikacia PREZILA (merge)')
    NxTest.assert_equal('Sensys', rec['series'])
    NxTest.assert_equal('Hettich', b.stored('zaves-a')['manufacturer'], 'aj v subore')
  end
end

NxTest.test('KOV-B1 (R5): kluc s prazdnou hodnotou je VEDOME vymazanie') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    b::HWS.save_set!(b.classified)
    status, rec = b::HWS.save_set!(b.classified('series' => ''))
    NxTest.assert_equal(:ok, status)
    NxTest.refute(rec.key?('series'), 'prazdna rada = zmazana')
    NxTest.assert_equal('Hettich', rec['manufacturer'], 'ostatne polia drzia')
    # `active: true` = zrusenie priznaku
    b::HWS.save_set!(b.classified('active' => false))
    NxTest.assert_equal(false, b.stored('zaves-a')['active'])
    _, rec2 = b::HWS.save_set!(b.classified('active' => true))
    NxTest.refute(rec2.key?('active'), '`true` priznak ZRUSI')
    NxTest.refute(b.stored('zaves-a').key?('active'), 'aj v subore')
  end
end

NxTest.test('KOV-B1 (R5): `save_set!` vracia STRUKTUROVANE chyby, dvojica dalej funguje') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    status, msg, errs = b::HWS.save_set!(b.classified('use_type' => 'sliding'))
    NxTest.assert_equal(:invalid, status)
    NxTest.assert(msg.is_a?(String) && !msg.empty?, 'druhy prvok ostava HLASKA (dialog ju vypisuje)')
    NxTest.assert(errs.is_a?(Array) && errs.first['field'] == 'use_type', errs.inspect)
    # dnesne dvojprvkove destruovanie (ui/hardware_catalog_dialog.rb) nesmie padnut
    st, info = b::HWS.save_set!(b.classified('use_type' => 'sliding'))
    NxTest.assert_equal(:invalid, st)
    NxTest.assert(info.is_a?(String), 'volajuci s dvojicou dostane hlasku, nie strukturu')
  end
end

NxTest.test('KOV-B1 (R5): taxonomia sa kontroluje LEN v `save_set!`') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    NxTest.assert_equal(:ok, b::HWS.save_set!(b.classified)[0], 'seedovany vyrobca + rada prejdu')
    status, msg, errs = b::HWS.save_set!(b.classified('manufacturer' => 'Vymyslena'))
    NxTest.assert_equal(:invalid, status)
    NxTest.assert(msg.include?('Vymyslena'), msg)
    NxTest.assert_equal('manufacturer', errs.first['field'])
    st2, _msg2, errs2 = b::HWS.save_set!(b.classified('manufacturer' => 'Blum'))
    NxTest.assert_equal(:invalid, st2, 'rada Sensys nepatri Blumu')
    NxTest.assert_equal('series', errs2.first['field'])
    # LEGACY set taxonomiu nepotrebuje
    NxTest.assert_equal(:ok, b::HWS.save_set!(b.set_def('set_id' => 'legacy'), create: true)[0])
  end
end

NxTest.test('KOV-B1 (R5): nad read-only taxonomiou sa KLASIFIKOVANY set neulozi, legacy ano') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    FileUtils.mkdir_p(File.dirname(b::TAX.path))
    File.binwrite(b::TAX.path, JSON.pretty_generate('std' => 'cudzi-system', 'schema' => 1))
    b::STORE.invalidate(b::TAX.path)
    b::TAX.reset_state!
    NxTest.assert_equal(:read_only, b::TAX.state, 'fixture: taxonomia je cudzia')
    status, reason = b::HWS.save_set!(b.classified)
    NxTest.assert_equal(:write_failed, status, 'fail-closed — nie „vyrobca nie je v zozname"')
    NxTest.assert(reason.to_s.include?('výrobcov'), "dovod menuje taxonomiu: #{reason}")
    NxTest.assert_equal(:ok, b::HWS.save_set!(b.set_def('set_id' => 'legacy'), create: true)[0],
                        'nezaradeny set sa uklada dalej')
  end
end

# ============================================================================
# 6) std 3 podla OBSAHU (R6)
# ============================================================================

NxTest.test('KOV-B1 (R6): std 3 bumpne KAZDE nove pole samostatne, legacy ostava') do
  b = NxB1
  legacy = b::HWS.normalize_sets([b.set_def]).first
  NxTest.assert_equal(b::HWS::STD, b::HWS.snapshot_std({}, [legacy]), 'cisty legacy = std 1')
  fields = {
    'use_type' => 'door', 'opening_mode' => 'classic',
    'manufacturer' => 'Hettich', 'series' => 'Sensys'
  }
  fields.each do |k, v|
    # Kluc sa vklada PRIAMO do normalizovaneho tvaru — detekcia std sa pyta
    # LEN na pritomnost kluca, nie na to, ci by prezil validaciu.
    s = legacy.merge(k => v)
    NxTest.assert_equal(b::HWS::STD_CLASSIFIED, b::HWS.snapshot_std({}, [s]),
                        "pole `#{k}` samo o sebe bumpne std")
  end
  NxTest.assert_equal(b::HWS::STD_CLASSIFIED, b::HWS.snapshot_std({}, [legacy.merge('active' => false)]),
                      '`active` tiez')
  NxTest.assert_equal(b::HWS::STD_CLASSIFIED,
                      b::HWS.snapshot_std({ 'class:hinge|classic' => 'zaves-a' }, [legacy]),
                      'triedny kluc mapovania tiez')
  # KOV-C2a: najvyssi marker uz nie je 3 (pribudol std 4 = `height_variant`),
  # ale invariant plati dalej: KAZDY marker, ktory vieme SAMI opeciatkovat,
  # musime vediet aj precitat — inak by si plugin vlastny zapis odmietol.
  NxTest.assert(b::HWS::STD_SUPPORTED.include?(b::HWS::STD_CLASSIFIED),
                'std 3 je PODPOROVANY (inak by sme si vlastny zapis neprecitali)')
end

NxTest.test('KOV-B1 (R6): zapis kniznice stampuje std 3 az podla obsahu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    b::HWS.write([b.set_def], {})
    NxTest.assert_equal(b::HWS::STD, b.raw_lib['std'], 'legacy obsah = std 1')
    b::HWS.write([b.classified], {})
    NxTest.assert_equal(b::HWS::STD_CLASSIFIED, b.raw_lib['std'])
    b::STORE.invalidate(b::HWS.path)
    b::HWS.reset_library_state!
    NxTest.assert_equal(:ok, b::HWS.library_state, 'vlastny zapis je VZDY citatelny')
  end
end

NxTest.test('KOV-B1 (R6/downgrade): std 3 je pre STARSI plugin read-only, subor sa nezmeni') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install(b.doc([b.classified], { 'class:hinge|classic' => 'zaves-a' },
                    'std' => b::HWS::STD_CLASSIFIED))
    before = File.binread(b::HWS.path)
    # Starsi plugin = ten, ktory std 3 NEPODPORUJE. Simuluje sa zuzenim
    # `STD_SUPPORTED` (obsah suboru sa nemeni — meni sa „verzia pluginu").
    orig = b::HWS::STD_SUPPORTED
    b::HWS.send(:remove_const, :STD_SUPPORTED)
    b::HWS.const_set(:STD_SUPPORTED, [1, 2].freeze)
    b::HWS.reset_library_state!
    NxTest.assert_equal(:read_only, b::HWS.library_state, 'starsi plugin ju musi odmietnut')
    NxTest.assert_equal(:newer, b::HWS.library_state_code)
    NxTest.refute(b::HWS.save_set!(b.set_def('set_id' => 'x'))[0] == :ok, 'a nic nezapise')
    NxTest.assert_equal(before, File.binread(b::HWS.path), 'subor ostal BAJT NA BAJT')
    # snapshot v .skp rovnako
    snap = { 'std' => b::HWS::STD_CLASSIFIED, 'mapping' => {},
             'sets' => { 'zaves-a' => b.classified } }
    NxTest.assert_equal(:invalid, b::HWS.project_state_status(b.model_with(snap))[0],
                        'a snapshot zakazky tiez (NIKDY ciastocne citanie)')
  ensure
    b::HWS.send(:remove_const, :STD_SUPPORTED)
    b::HWS.const_set(:STD_SUPPORTED, orig)
    b::HWS.reset_library_state!
  end
end

# ============================================================================
# 7) TRIEDNY kluc `class:` (R7)
# ============================================================================

NxTest.test('KOV-B1 (R7): kanonicky tvar triedneho kluca') do
  h = NxB1::HWS
  NxTest.assert_equal(['class:hinge|classic', nil], h.parse_class_key('class:hinge|classic'))
  NxTest.assert_equal(['class:slide|tipon|metal', nil], h.parse_class_key('class:slide|tipon|metal'))
  NxTest.assert_equal('class:hinge|classic', h.parse_class_key(' CLASS: Hinge | Classic ')[0],
                      'trim + downcase segmentov')
  NxTest.assert_equal('class:lift|classic', h.parse_class_key('class:lift|classic')[0],
                      'typ `lift` uz existuje (KOV-B1)')
  # neplatne tvary
  { 'class:hinge|tipon|metal' => 'konštrukciu',
    'class:foo|classic' => 'typ kovania',
    'class:slide|nieco' => 'spôsob otvárania',
    'class:slide|tipon@front:F1/panel' => 'na úrovni dielca',
    'class:slide' => 'spôsob otvárania' }.each do |bad, needle|
    key, err = h.parse_class_key(bad)
    NxTest.assert_equal(nil, key, "#{bad} musi padnut")
    NxTest.assert(err.to_s.include?(needle), "#{bad}: #{err}")
  end
end

NxTest.test('KOV-B1 (M4): triedny kluc round-tripuje vo VSETKYCH mapach') do
  h = NxB1::HWS
  key = 'class:slide|tipon|metal'
  [{ allow_owner: false }, { allow_owner: true }].each do |opts|
    out, errs = h.parse_mapping({ key => 'vysuv-a' }, **opts)
    NxTest.assert_equal([], errs, "#{opts.inspect}: #{errs.inspect}")
    NxTest.assert_equal({ key => 'vysuv-a' }, out, 'kluc PREZIJE (nic ho nezahadzuje)')
  end
  NxTest.assert_equal({}, h.parse_mapping({ 'class:hinge|tipon|metal' => 'x' })[0],
                      'neplatny tvar sa NEUKLADA')
  NxTest.assert(!h.parse_mapping({ 'class:hinge|tipon|metal' => 'x' })[1].empty?,
                'a zapisova cesta ho ODMIETNE chybou')
  NxTest.assert_equal(['vysuv-a'], h.referenced_set_ids(key => 'vysuv-a'),
                      'zmrazovanie snapshotu ho vidi')
  NxTest.assert_equal({ 'vysuv-a' => 'slide' }, h.mapping_types_by_set(key => 'vysuv-a'),
                      'typ sa berie z prveho segmentu')
  NxTest.assert_equal('slide', NxB1::BP.hardware_set_key_type(key))
  NxTest.assert_equal(nil, NxB1::BP.parse_hardware_set_key(key),
                      'nie je to vyber podla typu ani podla dielca')
  NxTest.assert_equal([], NxB1::BP.unknown_generic_types([], [key]),
                      'a prestavbu neblokuje (typ je znamy)')
  NxTest.assert_equal(['sliding'], NxB1::BP.unknown_generic_types([], ['class:sliding|classic']),
                      'triedny kluc z NOVSEJ verzie prestavbu blokuje')
end

NxTest.test('KOV-B1 (R7): kniznica s triednym klucom je :ok, ale expanzia ho IGNORUJE') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install(b.doc([b.set_def], { 'class:hinge|classic' => 'zaves-a' },
                    'std' => b::HWS::STD_CLASSIFIED))
    NxTest.assert_equal(:ok, b::HWS.library_state, 'vlastny tvar sa cita bez problemu')
    NxTest.assert_equal({ 'class:hinge|classic' => 'zaves-a' }, b::HWS.load['mapping'],
                        'a round-tripuje aj cez `load`')
  end
  # expanzia: mapovanie LEN s triednym klucom = polozka je `no_set`, presne
  # ako pred KOV-B1 (nic sa nezacne ticho nakupovat).
  set = b::HWS.normalize_sets([b.set_def]).first
  st = { 'mapping' => { 'class:hinge|classic' => 'zaves-a' }, 'sets' => { 'zaves-a' => set } }
  exp = b::HWS.expand([b.hinge_item], st, catalog: [])
  NxTest.assert_equal([], exp['rows'], 'ziadny riadok')
  NxTest.assert_equal(['no_set'], exp['unmapped'].map { |u| u['reason'] })
  NxTest.assert_equal(nil, b::HWS.explain(b.hinge_item, st)['set_id'], 'ani panel ho neresolvuje')
end

# ============================================================================
# 8) BRANA DEFINICII SETOV V SABLONE (R8)
# ============================================================================

NxTest.test('KOV-B1 (M3): sablona s definiciami z NOVSEJ verzie sa ODMIETNE bez zapisu') do
  b = NxB1
  novsia = b.classified('use_type' => 'sliding')
  # (a) VKLAD zo sablony — brana bezi PRED `prepare_insert` aj pred ghostom
  params = { 'type' => 'lower', 'hardware_sets' => { 'hinge' => 'zaves-a' },
             'hardware_set_defs' => { 'zaves-a' => novsia } }
  status, lost = b::PANEL.take_insert_hardware!(params)
  NxTest.assert_equal(:lossy_defs, status, 'vlastny status = vlastna hlaska')
  NxTest.assert_equal(['zaves-a'], lost, 'hlaska menuje, ktora definicia sa necita')
  # (b) POUZITIE sablony — kontrakt cesty (headless `handle_apply` potrebuje model)
  src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'))
            .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  body = src[/^        def handle_apply.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'telo `handle_apply` sa naslo')
  # Porovnavaju sa VOLANIA, nie holé slová — komentáre ich menuju skôr.
  gate = body.index('HardwareSets.assess_set_defs(')
  build = body.index('CabinetBuilder.rebuild_many(')
  NxTest.assert(gate && build, 'brana aj prestavba su v tele')
  NxTest.assert(gate < build, 'brana bezi PRED prestavbou — model sa nesmie dotknut')
  NxTest.assert(body.include?('nič sa nezmenilo'), 'a hlaska to hovori')
  # (c) neznamy kluc definicie aj ne-Hash vstup
  NxTest.assert_equal(:lossy, b::HWS.assess_set_defs([b.set_def('foo' => 1)])[0])
  NxTest.assert_equal([:lossy, ['hardware_set_defs']], b::HWS.assess_set_defs('nieco'))
end

NxTest.test('KOV-B1 (R8): legacy sablona a platne definicie prechadzaju') do
  b = NxB1
  NxTest.assert_equal([:ok, {}], b::HWS.assess_set_defs(nil), 'sablona bez kovania')
  NxTest.assert_equal([:ok, {}], b::HWS.assess_set_defs([]))
  status, defs = b::HWS.assess_set_defs('zaves-a' => b.classified)
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal(['zaves-a'], defs.keys)
  NxTest.assert_equal('door', defs['zaves-a']['use_type'], 'vracia NORMALIZOVANY tvar')
  NxTest.assert_equal(:ok, b::HWS.assess_set_defs(b.set_def)[0], 'jedna definicia priamo')
  # vklad s platnymi definiciami dalej funguje presne ako doteraz
  params = { 'hardware_sets' => { 'hinge' => 'zaves-a' },
             'hardware_set_defs' => { 'zaves-a' => b.classified } }
  st, hw = b::PANEL.take_insert_hardware!(params)
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal({ 'hinge' => 'zaves-a' }, hw['mapping'])
end

# ============================================================================
# 9) CHARAKTERIZACIA: klasifikacia NAKUP NEMENI (R13)
# ============================================================================

NxTest.test('KOV-B1 (R13): klasifikovana kopia SEED kniznice nakupuje deep-equal') do
  b = NxB1
  plain = b.seed_state(b::HWS::SEED_SETS.map { |s| b.strip_class(s) })
  klas  = b.seed_state(b::HWS::SEED_SETS.map { |s| b.classify_seed(b.strip_class(s)) })
  # fixture: klasifikacia sa naozaj precitala
  NxTest.assert(klas['sets'].each_value.all? { |s| s.key?('use_type') },
                'vsetky seed sety su klasifikovane')
  NxTest.assert(plain['sets'].each_value.none? { |s| s.key?('use_type') })
  cat = [{ 'item_code' => '104717', 'name_sk' => 'Záves', 'category' => 'ZAVESY',
           'unit' => 'ks', 'price_eur_vat' => 4.18 },
         { 'item_code' => '82744', 'name_sk' => 'Klzák', 'category' => 'NOHY',
           'unit' => 'ks', 'price_eur_vat' => 0.48 }]
  items = [b.hinge_item,
           b.hinge_item('owner_part_key' => 'front:F2/wing:single', 'quantity' => 3),
           { 'owner_id' => 'CAB-1', 'generic_type' => 'slide', 'quantity' => 1,
             'rule_id' => 'vysuv', 'params' => { 'nominal_length' => 420.0 } },
           { 'owner_id' => 'CAB-1', 'generic_type' => 'leg', 'quantity' => 4,
             'rule_id' => 'nohy', 'params' => { 'height' => 150.0 } },
           { 'owner_id' => 'CAB-2', 'generic_type' => 'wall_hanger', 'quantity' => 2,
             'rule_id' => 'zavesenie', 'params' => {} },
           { 'owner_id' => 'CAB-1', 'generic_type' => 'shelf_pin', 'quantity' => 4,
             'rule_id' => 'podperky', 'params' => {} }]
  a = b::HWS.expand(items, plain, catalog: cat)
  c = b::HWS.expand(items, klas, catalog: cat)
  NxTest.assert_equal(a, c, 'nakup je IDENTICKY — klasifikacia je metadata, nie vyber kodu')
  NxTest.assert_equal(b::HWS.purchase_csv(a, project: 'X', generated_at: 'Y'),
                      b::HWS.purchase_csv(c, project: 'X', generated_at: 'Y'),
                      'a nakupny CSV je BAJTOVO ten isty')
  items.each do |it|
    NxTest.assert_equal(b::HWS.explain(it, plain, catalog: cat),
                        b::HWS.explain(it, klas, catalog: cat),
                        "aj rozpis polozky #{it['generic_type']}")
  end
end

NxTest.test('KOV-B1 (R13): kazdy SEED set sa da klasifikovat (mapa pokryva realne data)') do
  b = NxB1
  b::HWS::SEED_SETS.each do |s|
    norm, errs = b::HWS.validate_set(b.classify_seed(s))
    NxTest.assert_equal([], errs, "#{s['set_id']}: #{errs.inspect}")
    NxTest.assert_equal(s['generic_type'], norm['generic_type'],
                        "#{s['set_id']}: typ kovania sa klasifikaciou NEMENI")
  end
end

# --- Codex #284 P2-A: do kniznice sa uklada KANONICKE meno z taxonomie ------

NxTest.test('KOV-B1 (P2-A): set ulozeny s „hettich"/„sensys" ma v subore KANONICKE mena') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    # Kontrola je case-insensitive (aby sa dalo pisat rukou), ULOZIT sa vsak
    # smie LEN kanonicky zapis — inak by v kniznici vyrastlo „hettich" VEDLA
    # „Hettich" a zoskupenie (B2) ani filtre (D) by na tom nesadli.
    status, rec = b::HWS.save_set!(b.classified('manufacturer' => ' hettich ',
                                                'series' => 'SENSYS'))
    NxTest.assert_equal(:ok, status)
    NxTest.assert_equal('Hettich', rec['manufacturer'], 'vratena definicia je kanonicka')
    NxTest.assert_equal('Sensys', rec['series'])
    stored = b.stored('zaves-a')
    NxTest.assert_equal('Hettich', stored['manufacturer'], 'a v SUBORE tiez')
    NxTest.assert_equal('Sensys', stored['series'])
    NxTest.assert_equal(%w[set_id name generic_type use_type opening_mode
                           manufacturer series members], stored.keys,
                        'poradie klucov sa prepisom nemeni')
  end
end

NxTest.test('KOV-B1 (P2-A): setu BEZ rady sa kluc `series` nedoplna') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB1
  b.with_library do
    b.install_base
    bez = b.classified
    bez.delete('series')
    status, rec = b::HWS.save_set!(bez)
    NxTest.assert_equal(:ok, status)
    NxTest.refute(rec.key?('series'), 'rada je volitelna — kanonizacia ju nesmie pridat')
    NxTest.refute(b.stored('zaves-a').key?('series'))
    # legacy (nezaradeny) set sa taxonomie netyka vobec
    st2, rec2 = b::HWS.save_set!(b.set_def('set_id' => 'legacy'), create: true)
    NxTest.assert_equal(:ok, st2)
    NxTest.refute(rec2.key?('manufacturer'))
  end
end

# --- Codex #284 P2-B: nekanonicky triedny kluc v sablone NIE JE strata ------

NxTest.test('KOV-B1 (P2-B): platny triedny kluc v nekanonickom zapise sablonu NEODMIETNE') do
  h = NxB1::HWS
  status, map = h.read_template_mapping(' CLASS: Hinge | Classic ' => 'zaves-a')
  NxTest.assert_equal(:ok, status, 'trim a velkost pismen NIE SU strata')
  NxTest.assert_equal({ 'class:hinge|classic' => 'zaves-a' }, map, 'ulozi sa KANONICKY tvar')
  # kanonicky zapis funguje dalej rovnako
  NxTest.assert_equal([:ok, { 'class:slide|tipon|metal' => 'vysuv-a' }],
                      h.read_template_mapping('class:slide|tipon|metal' => 'vysuv-a'))
  # NEPLATNY triedny kluc ostava stratou (novsia verzia / rucna uprava)
  NxTest.assert_equal(:lossy, h.read_template_mapping('class:foo|classic' => 'x')[0])
  NxTest.assert_equal(['class:hinge|tipon|metal'],
                      h.read_template_mapping('class:hinge|tipon|metal' => 'x')[1],
                      'hlaska menuje SUROVY zapis, ktory sa necita')
  # a beznych klucov sa zmena nedotyka
  NxTest.assert_equal([:ok, { 'leg' => 'nohy-a' }],
                      h.read_template_mapping(' leg ' => ' nohy-a '))
  NxTest.assert_equal(:lossy, h.read_template_mapping('slide@front:F1/panel' => 'x')[0],
                      'composite kluc je v sablone stale neprenosny')
  NxTest.assert_equal('class:hinge|classic', h.canonical_mapping_key(' CLASS: Hinge|Classic '))
  NxTest.assert_equal(nil, h.canonical_mapping_key('class:foo|classic'))
  NxTest.assert_equal('leg', h.canonical_mapping_key('  leg '))
end

NxTest.test('KOV-B1 (P2-B): vklad zo sablony s nekanonickym triednym klucom prejde') do
  b = NxB1
  params = { 'type' => 'lower', 'hardware_sets' => { ' CLASS: Hinge | Classic ' => 'zaves-a' } }
  status, hw = b::PANEL.take_insert_hardware!(params)
  NxTest.assert_equal(:ok, status, 'sablona sa uz falosne neodmieta')
  NxTest.assert_equal({ 'class:hinge|classic' => 'zaves-a' }, hw['mapping'])
end

# --- Codex #284 P2-C: duplicitny `set_id` v definiciach sablony = odmietnutie -

NxTest.test('KOV-B1 (P2-C): dve definicie s rovnakym `set_id` sa ODMIETNU, nikdy neprepisu') do
  b = NxB1
  prva = b.set_def('members' => [{ 'code' => 'PRVA', 'per' => 'unit', 'qty' => 1 }])
  druha = b.set_def('members' => [{ 'code' => 'DRUHA', 'per' => 'unit', 'qty' => 1 }])
  status, lost = b::HWS.assess_set_defs([prva, druha])
  NxTest.assert_equal(:lossy, status,
                      'brana by inak zvalidovala INU definiciu, nez sa zmrazi do projektu')
  NxTest.assert(lost.any? { |l| l.to_s.include?('zaves-a') }, lost.inspect)
  # kontrola dokazu: `collect_set_defs` drzi PRVU definiciu, brana by (bez opravy)
  # bola posudila DRUHU — presne ten rozpor, ktory sa tu zakazuje
  NxTest.assert_equal('PRVA', b::HWS.collect_set_defs([prva, druha])['zaves-a']['members'][0]['code'])
  # dve ROZNE definicie prechadzaju dalej
  NxTest.assert_equal(:ok, b::HWS.assess_set_defs([prva, b.set_def('set_id' => 'zaves-b')])[0])
end

NxTest.test('KOV-B1 (P2-C): sablona s duplicitnym `set_id` sa neuplatni ani pri vklade') do
  b = NxB1
  defs = [b.set_def('members' => [{ 'code' => 'PRVA', 'per' => 'unit', 'qty' => 1 }]),
          b.set_def('members' => [{ 'code' => 'DRUHA', 'per' => 'unit', 'qty' => 1 }])]
  params = { 'type' => 'lower', 'hardware_sets' => { 'hinge' => 'zaves-a' },
             'hardware_set_defs' => defs }
  status, lost = b::PANEL.take_insert_hardware!(params)
  NxTest.assert_equal(:lossy_defs, status)
  NxTest.assert(lost.any? { |l| l.to_s.include?('zaves-a') }, lost.inspect)
  # a cesta POUZITIA sablony ma tu istu branu (zdrojovy kontrakt je overeny
  # v teste „KOV-B1 (M3)"), takze do modelu sa nezapise nic
end
