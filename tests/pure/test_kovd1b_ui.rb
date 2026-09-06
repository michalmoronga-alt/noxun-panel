# frozen_string_literal: true
# Testy KOV-D1b: MAPOVANIE — UI. Ponuka setov pre TRIEDNY kluc (Pravidla
# Studia), prepnutie setu na karte skrinky/cela a rozbalitelny detail zasuvky
# („co je v baleni").
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 Pravidla Studia — riadok pre KAZDY triedny kluc (`CLASS_MAPPING_KEYS`)
#      s ponukou LEN kompatibilnych moznosti: Atira ako RODINA (vyber podla
#      vyskoveho variantu), Quadro ako PEVNY set; neaktivny set sa NEPONUKA
#      a uz ULOZENA hodnota sa zobrazi (`stored`), ale nedá sa vybrat znova
#   R2 Karta — ponuka pre celu skrinku aj pre KONKRETNE celo, prva volba
#      povie, co plati bez vlastneho vyberu (skrinka -> projekt); zmiesane
#      triedy skrinkovy riadok NEDOSTANU; neklasifikovana polozka ponuku nema
#   R3 Detail zasuvky = vety receptu (`explain_stored`) + „co je v baleni"
#      z JEDINEHO existujuceho rozpisu (`HardwareSets.explain`) — NOSNOST
#      vydava VYHRADNE recept, nakupna volba ju nikdy nezvysuje (Astra #20 F11)
#   R4 charakterizacia — zakazka bez klasifikovanych zasuviek ma payload karty
#      prazdny a `compat` je nil (karta kresli povodny plochy zoznam setov)
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne test):
#   M1 `class_set_options` nefiltruje `opening_mode`
#      -> „KOV-D1b (R1): ponuka triedneho kluca je LEN kompatibilna"
#   M2 `class_set_options` neaktivny set NEODFILTRUJE
#      -> „KOV-D1b (R1): neaktivny set sa NEPONUKA, ulozeny sa PRIZNA"
#   M3 `class_set_options` vyda set s `height_variant` ako PEVNU volbu
#      -> „KOV-D1b (R1): Atira sa ponuka ako RODINA, nikdy napevno"
#   M4 `drawer_buy_lines` prida nosnost zo setu
#      -> „KOV-D1b (R3): nosnost vydava VYHRADNE recept"
#   M5 `compat_scope` cita projektovu hodnotu pod GENERICKYM klucom
#      -> „KOV-D1b (R2): prva volba povie, co plati z projektu"
require_relative '../helper' unless defined?(NxTest)

# UI vrstva nie je headless v require zozname helpera (vzor KOV-C2c/D1a).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog')
end

module NxD1b
  E   = Noxun::Engine
  HWS = E::HardwareSets

  CLASSIC_METAL = 'class:slide|classic|metal'
  TIPON_METAL   = 'class:slide|tipon|metal'
  CLASSIC_WOOD  = 'class:slide|classic|wood'
  OWNER         = 'front:F1/panel'

  module_function

  def seed_set(sid)
    HWS::SEED_SETS.find { |s| s['set_id'] == sid }.dup
  end

  # FIXTUROVA alternativna rodina: ta ista klasifikacia AJ ta ista rada ako
  # biela Atira — lisi sa VYHRADNE nazvom (presne ako bude vyzerat antracit,
  # ktory je samostatna DATOVA davka po D1b). Produkcny seed sa NEMENI.
  def alt_family(active_h144: true)
    [[70, '357694'], [144, '357734'], [176, '357773']].map do |hv, code|
      set = { 'set_id' => "atira-antracit-h#{hv}-sisy",
              'name' => "Atira antracit H#{hv} — klasické",
              'generic_type' => 'slide', 'use_type' => 'drawer',
              'opening_mode' => 'classic', 'drawer_construction' => 'metal',
              'manufacturer' => 'Hettich', 'series' => 'InnoTech Atira',
              'height_variant' => hv,
              'members' => [{ 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
                              'code_by_nl' => { '470' => code } }] }
      set['active'] = false if hv == 144 && !active_h144
      set
    end
  end

  def white_family
    %w[atira-biela-h70-sisy atira-biela-h144-sisy atira-biela-h176-sisy].map { |s| seed_set(s) }
  end

  def tipon_family
    %w[atira-biela-h70-p2o atira-biela-h144-p2o atira-biela-h176-p2o].map { |s| seed_set(s) }
  end

  def wood_sets
    %w[vysuv-quadro-v6-sisy vysuv-quadro-v6-p2o].map { |s| seed_set(s) }
  end

  def library(extra = [])
    white_family + tipon_family + wood_sets + extra
  end

  def defs_of(sets)
    HWS.index_sets(sets)
  end

  # Receptova polozka vysuvu pre kartu (tvar `Construction.drawer_hardware_item`).
  def slide_item(owner: OWNER, opening: 'classic', construction: 'metal',
                 height_variant: 70.0, over: {})
    { 'owner_part_key' => owner, 'generic_type' => 'slide', 'quantity' => 1,
      'rule_id' => 'recipe:atira_sisy_v1', 'source' => 'recipe',
      'params' => { 'opening_mode' => opening, 'drawer_construction' => construction,
                    'system' => 'atira', 'height_variant' => height_variant,
                    'nominal_length' => 470.0, 'load' => 30.0,
                    'recipe_id' => 'atira_sisy_v1' } }.merge(over)
  end

  def white_selector
    HWS::MAPPING_ADDITIONS[CLASSIC_METAL]
  end
end

# ============================================================================
# R1 — PONUKA PRE TRIEDNY KLUC
# ============================================================================

NxTest.test('KOV-D1b (R1): ponuka triedneho kluca je LEN kompatibilna') do
  c = NxD1b
  sets = c.library
  opts = c::HWS.class_set_options(c::CLASSIC_METAL, sets, {}, [])
  NxTest.assert_equal(1, opts.length, 'jedna rodina (Atira biela klasicka)')
  ids = opts.first['selector']['bands'].map { |b| b['set_id'] }
  NxTest.assert_equal(%w[atira-biela-h70-sisy atira-biela-h144-sisy atira-biela-h176-sisy], ids)

  # Tip-On kluc NIKDY neponukne klasicke sety (a naopak).
  tip = c::HWS.class_set_options(c::TIPON_METAL, sets, {}, [])
  NxTest.assert_equal(1, tip.length)
  NxTest.assert(tip.first['selector']['bands'].all? { |b| b['set_id'].end_with?('-p2o') },
                'Tip-On kluc vydava LEN Tip-On sety')

  # Drevena konstrukcia = Quadro, a to PEVNYM setom (vyskovy variant nema).
  wood = c::HWS.class_set_options(c::CLASSIC_WOOD, sets, {}, [])
  NxTest.assert_equal(1, wood.length)
  NxTest.assert_equal('vysuv-quadro-v6-sisy', wood.first['set_id'])
  NxTest.assert(wood.first['selector'].nil?, 'Quadro sa vybera napevno')
end

NxTest.test('KOV-D1b (R1): Atira sa ponuka ako RODINA, nikdy napevno') do
  c = NxD1b
  opts = c::HWS.class_set_options(c::CLASSIC_METAL, c.library(c.alt_family), {}, [])
  NxTest.assert_equal(2, opts.length, 'biela + antracit = dve rodiny')
  NxTest.assert(opts.all? { |o| o['set_id'].nil? && o['selector'].is_a?(Hash) },
                'set s vyskovym variantom sa PEVNE vybrat NEDA')
  NxTest.assert_equal(['Atira antracit — klasické · podľa výšky zásuvky (H70 · H144 · H176)',
                       'Atira biela — klasické · podľa výšky zásuvky (H70 · H144 · H176)'],
                      opts.map { |o| o['label'] }, 'rodinu menuje nazov bez vyskoveho tokenu')
  # Pasma su jednobodove a zoradene — nikdy sa neprekryvaju.
  bands = opts.first['selector']['bands']
  NxTest.assert_equal([70.0, 144.0, 176.0], bands.map { |b| b['min'] })
  NxTest.assert(bands.all? { |b| b['min'] == b['max'] }, 'jedno pasmo = jedna vyska')
  NxTest.assert_equal('height_variant', opts.first['selector']['param'])
end

NxTest.test('KOV-D1b (R1): neaktivny set sa NEPONUKA, ulozeny sa PRIZNA') do
  c = NxD1b
  sets = c.library(c.alt_family(active_h144: false))
  opts = c::HWS.class_set_options(c::CLASSIC_METAL, sets, {}, [])
  antracit = opts.find { |o| o['label'].include?('antracit') }
  NxTest.assert_equal(%w[atira-antracit-h70-sisy atira-antracit-h176-sisy],
                      antracit['selector']['bands'].map { |b| b['set_id'] },
                      'neaktivne pasmo z ponuky vypadne')
  # A vypadne AJ ked ho projekt REFERENCUJE — `set_options` taky set zamerne
  # drzi (aby select neukazoval prazdno), ponuka NOVEHO vyberu ho niest nesmie.
  refd = c::HWS.class_set_options(c::CLASSIC_METAL, sets, {}, ['atira-antracit-h144-sisy'])
  NxTest.refute(refd.any? { |o| Array(o['selector'] && o['selector']['bands'])
                                .any? { |b| b['set_id'] == 'atira-antracit-h144-sisy' } },
                'neaktivny set sa NEPONUKA ani ked nan projekt ukazuje')

  # Ulozena hodnota s neaktivnym setom sa v riadku ZOBRAZI, ale nie je to
  # ziadna z ponuk (F10: novy vyber sa nedá spravit, stara volba ostava).
  inactive_sel = { 'param' => 'height_variant',
                   'bands' => [{ 'min' => 144.0, 'max' => 144.0,
                                 'set_id' => 'atira-antracit-h144-sisy' }] }
  row = c::E::HardwareCatalogDialog.class_mapping_rows(
    { c::CLASSIC_METAL => inactive_sel }, sets, {}, c.defs_of(sets)
  ).find { |r| r['key'] == c::CLASSIC_METAL }
  NxTest.assert(row['stored'], 'ulozena hodnota mimo ponuky sa prizna')
  NxTest.assert_equal(nil, row['current'], 'a nie je to vybrana volba z ponuky')
  NxTest.assert(row['value_text'].include?('Atira antracit'), 'text ulozenej hodnoty menuje rodinu')
  NxTest.refute(row['options'].any? { |o| o['id'] == c::HWS.mapping_option_id(inactive_sel) },
                'neaktivna volba sa NEPONUKA')
end

NxTest.test('KOV-D1b (R1): riadky Pravidiel = vsetky triedne kluce, RED bez setu') do
  c = NxD1b
  sets = c.library
  rows = c::E::HardwareCatalogDialog.class_mapping_rows(
    { c::CLASSIC_METAL => c.white_selector }, sets, {}, c.defs_of(sets)
  )
  NxTest.assert_equal(c::HWS::CLASS_MAPPING_KEYS, rows.map { |r| r['key'] },
                      'zoznam klucov je JEDEN (MAPPING_ADDITIONS)')
  metal = rows.first
  NxTest.assert_equal(c::HWS.mapping_option_id(c.white_selector), metal['current'],
                      'ulozena hodnota je vybrana volba z ponuky')
  NxTest.refute(metal['stored'], 'a nie je to „mimo ponuky"')
  NxTest.assert_equal('Výsuv · Klasické · Kovové bočnice', metal['label'])
  # Nenamapovana KLASIFIKOVANA zasuvka je RED (`drawer_kit_missing`), nie ORANGE.
  empty = rows.find { |r| r['key'] == c::TIPON_METAL }
  NxTest.assert_equal(nil, empty['current'])
  NxTest.assert(empty['none_label'].include?('RED'), 'bez setu = RED, nie ORANGE')
  NxTest.assert_equal('bez setu', empty['value_text'])
end

NxTest.test('KOV-D1b (R1): token hodnoty je stabilny a jednoznacny') do
  c = NxD1b
  NxTest.assert_equal('set:quadro', c::HWS.mapping_option_id('quadro'))
  a = c::HWS.mapping_option_id(c.white_selector)
  b = c::HWS.mapping_option_id(c::HWS.deep_copy(c.white_selector))
  NxTest.assert_equal(a, b, 'rovnaka hodnota = rovnaky token')
  other = { 'param' => 'height_variant',
            'bands' => [{ 'min' => 70.0, 'max' => 70.0, 'set_id' => 'atira-biela-h70-sisy' }] }
  NxTest.refute(a == c::HWS.mapping_option_id(other), 'ine pasma = iny token')
  NxTest.assert_equal(nil, c::HWS.mapping_option_id(nil))
  NxTest.assert_equal(nil, c::HWS.mapping_option_id(42), 'neplatny tvar nema token')
end

NxTest.test('KOV-D1b (R1): text ulozenej hodnoty sa nikdy nedopocitava') do
  c = NxD1b
  defs = c.defs_of(c.library)
  NxTest.assert_equal('bez setu', c::HWS.mapping_value_text(nil, defs))
  NxTest.assert_equal('Quadro V6 EB23 — klasické',
                      c::HWS.mapping_value_text('vysuv-quadro-v6-sisy', defs))
  NxTest.assert_equal('neznamy (chýba)', c::HWS.mapping_value_text('neznamy', defs),
                      'chybajucu definiciu PRIZNA, nikdy nenahradi')
  NxTest.assert_equal('Atira biela — klasické · podľa výšky zásuvky (H70 · H144 · H176)',
                      c::HWS.mapping_value_text(c.white_selector, defs))
  # Zmiesana rodina rodinu NEMENUJE (radsej menej nez vymysleny nazov).
  mixed = { 'param' => 'height_variant',
            'bands' => [{ 'min' => 70.0, 'max' => 70.0, 'set_id' => 'atira-biela-h70-sisy' },
                        { 'min' => 144.0, 'max' => 144.0, 'set_id' => 'atira-biela-h144-p2o' }] }
  NxTest.assert_equal('podľa výšky zásuvky (H70 · H144)', c::HWS.mapping_value_text(mixed, defs))
end

NxTest.test('KOV-D1b (R1): zapisova cesta prijme TRIEDNY kluc z payloadu') do
  c = NxD1b
  dlg = c::E::HardwareCatalogDialog
  NxTest.assert_equal(c::CLASSIC_METAL,
                      dlg.mapping_key('mapping_key' => c::CLASSIC_METAL, 'generic_type' => 'slide'))
  NxTest.assert_equal('slide', dlg.mapping_key('generic_type' => 'slide'),
                      'stary tvar payloadu (bez `mapping_key`) ostava funkcny')
  # Kluc, typ aj popisok cita JEDINA autorita — panel nic neskladá.
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hw_sets.js'),
                  encoding: 'UTF-8')
  NxTest.refute(src.include?("'class:"), 'JS triedny kluc NESKLADA')
  NxTest.assert_equal('Výsuv · Tip-On · Kovové bočnice', c::HWS.class_key_label(c::TIPON_METAL))
  NxTest.assert_equal(nil, c::HWS.class_key_label('slide'), 'genericky kluc triedny popisok nema')
end

# ============================================================================
# R2 — KARTA SKRINKY / CELA
# ============================================================================

NxTest.test('KOV-D1b (R2): prva volba povie, co plati z projektu') do
  c = NxD1b
  sets = c.library(c.alt_family)
  hw = [c.slide_item]
  out = c::E::Panel.class_compat_payload('slide', hw, {}, { c::CLASSIC_METAL => c.white_selector },
                                         sets, {}, [])
  cab = out['cab']
  NxTest.assert_equal(c::CLASSIC_METAL, cab['class_key'])
  NxTest.assert_equal('Set pre túto skrinku', cab['scope_label'])
  NxTest.assert(cab['none_label'].start_with?('podľa projektu — Atira biela'),
                "prva volba menuje PROJEKTOVU hodnotu (#{cab['none_label']})")
  NxTest.assert_equal(nil, cab['current'], 'bez overridu nie je vybrana ziadna volba')
  NxTest.assert_equal(2, cab['options'].length, 'ponuka = obe kompatibilne rodiny')

  owner = out['owners'][c::OWNER]
  NxTest.assert_equal('Set pre toto čelo', owner['scope_label'])
  NxTest.assert(owner['none_label'].start_with?('podľa projektu — '), 'celo dedí projekt')
end

NxTest.test('KOV-D1b (R2): vyber per celo prebija skrinku a vracia sa na projekt') do
  c = NxD1b
  sets = c.library(c.alt_family)
  hw = [c.slide_item]
  antracit = { 'param' => 'height_variant',
               'bands' => [{ 'min' => 70.0, 'max' => 70.0, 'set_id' => 'atira-antracit-h70-sisy' },
                           { 'min' => 144.0, 'max' => 144.0, 'set_id' => 'atira-antracit-h144-sisy' },
                           { 'min' => 176.0, 'max' => 176.0, 'set_id' => 'atira-antracit-h176-sisy' }] }
  overrides = { c::CLASSIC_METAL => antracit }
  out = c::E::Panel.class_compat_payload('slide', hw, overrides,
                                         { c::CLASSIC_METAL => c.white_selector }, sets, {}, [])
  NxTest.assert_equal(c::HWS.mapping_option_id(antracit), out['cab']['current'],
                      'override skrinky je vybrany')
  NxTest.assert(out['owners'][c::OWNER]['none_label'].start_with?('podľa skrinky — Atira antracit'),
                'celo bez vlastneho vyberu dedí SKRINKU')

  # Vlastny vyber cela (owner triedny kluc) prebije skrinku.
  own = overrides.merge("#{c::CLASSIC_METAL}@#{c::OWNER}" => c.white_selector)
  out2 = c::E::Panel.class_compat_payload('slide', hw, own,
                                          { c::CLASSIC_METAL => c.white_selector }, sets, {}, [])
  NxTest.assert_equal(c::HWS.mapping_option_id(c.white_selector),
                      out2['owners'][c::OWNER]['current'])
end

NxTest.test('KOV-D1b (R2): zmiesane triedy skrinkovy riadok NEDOSTANU') do
  c = NxD1b
  sets = c.library
  hw = [c.slide_item, c.slide_item(owner: 'front:F2/panel', opening: 'tipon')]
  out = c::E::Panel.class_compat_payload('slide', hw, {}, {}, sets, {}, [])
  NxTest.assert_equal(nil, out['cab'],
                      'jeden kluc by platil len na cast poloziek — riadok sa neponuka')
  NxTest.assert_equal(%w[front:F1/panel front:F2/panel], out['owners'].keys.sort)
  NxTest.assert_equal(c::TIPON_METAL, out['owners']['front:F2/panel']['class_key'])
end

NxTest.test('KOV-D1b (R4): neklasifikovana polozka ponuku podla triedy NEMA') do
  c = NxD1b
  legacy = { 'owner_part_key' => c::OWNER, 'generic_type' => 'slide', 'quantity' => 1,
             'rule_id' => 'vysuvy-zakladne', 'params' => { 'nominal_length' => 470.0 } }
  NxTest.assert_equal(nil, c::E::Panel.class_compat_payload('slide', [legacy], {}, {},
                                                            c.library, {}, []),
                      'stara zakazka kresli povodny plochy zoznam setov')
  NxTest.assert_equal(nil, c::E::Panel.class_compat_payload('hinge', [], {}, {},
                                                            c.library, {}, []))
end

# ============================================================================
# R3 — DETAIL ZASUVKY („co je v baleni")
# ============================================================================

module NxD1b
  module_function

  def buy_ctx(sets, overrides = {}, mapping = nil)
    { 'status' => :ok,
      'state' => { 'mapping' => mapping || { CLASSIC_METAL => white_selector },
                   'sets' => defs_of(sets) },
      'overrides' => overrides,
      'lookup' => { '357696' => { 'name_sk' => 'Súprava Atira 470 biela' } } }
  end
end

NxTest.test('KOV-D1b (R3): detail rozpise BALENIE z jedineho existujuceho rozpisu') do
  c = NxD1b
  lines = c::E::Panel.drawer_buy_lines(c.slide_item, c.buy_ctx(c.library))
  NxTest.assert_equal('Balenie: Atira biela H70 — klasické', lines.first)
  NxTest.assert_equal(1, lines.length - 1, 'jeden clen setu = jedna veta')
  NxTest.assert(lines[1].include?('357696'), "veta clena nesie KOD (#{lines[1]})")
  NxTest.assert(lines[1].include?('Súprava Atira 470 biela'), 'a nazov z katalogu')
  NxTest.assert(lines[1].end_with?('(1 ks)'))
end

NxTest.test('KOV-D1b (R3): nosnost vydava VYHRADNE recept') do
  c = NxD1b
  lines = c::E::Panel.drawer_buy_lines(c.slide_item, c.buy_ctx(c.library))
  NxTest.refute(lines.any? { |l| l.include?('kg') },
                'nakupny rozpis nosnost NEUVADZA (nezvysuje ju ani nemeni)')
  # Nosnost je v riadku karty a pochadza z ULOZENYCH params polozky vysuvu.
  NxTest.assert(c::E::Panel.drawer_row_text(c.slide_item['params']).include?('30 kg'))
end

NxTest.test('KOV-D1b (R3): bez kontextu sa nedopisuje NIC') do
  c = NxD1b
  NxTest.assert_equal([], c::E::Panel.drawer_buy_lines(c.slide_item, nil))
  NxTest.assert_equal([], c::E::Panel.drawer_buy_lines(nil, c.buy_ctx(c.library)))
  # Nenamapovana trieda = PRIZNANY dovod, nikdy tichy prazdny rozpis.
  lines = c::E::Panel.drawer_buy_lines(c.slide_item, c.buy_ctx(c.library, {}, {}))
  NxTest.assert(lines.any? { |l| l.start_with?('Bez kódu:') }, "dovod sa prizna (#{lines})")
  NxTest.refute(lines.any? { |l| l.start_with?('Balenie:') })
end

NxTest.test('KOV-D1b (R3): riadok karty spaja vety receptu a balenie') do
  c = NxD1b
  cfg = { 'front_items' => [{ 'id' => 'F1' }], 'hardware' => [c.slide_item],
          'config_schema' => c::E::CabinetBuilder::CONFIG_SCHEMA }
  row = c::E::Panel.drawer_card_row(cfg, 'F1', c.buy_ctx(c.library))
  NxTest.assert_equal('ok', row['state'])
  NxTest.assert(row['detail'].first.start_with?('Recept:'), 'najprv vety receptu')
  NxTest.assert(row['detail'].any? { |l| l.start_with?('Balenie:') }, 'potom balenie')
  # BEZ kontextu (stary volajuci) ostava detail presne taky, aky bol v C2c.
  plain = c::E::Panel.drawer_card_row(cfg, 'F1')
  NxTest.assert_equal(c::E::Recipes.explain_stored(c.slide_item['params']), plain['detail'])
end
