# frozen_string_literal: true
# Testy KOV-B3: ZIVY NAHLAD EXPANZIE rozpracovaneho setu + serverovy kontrakt
# editora (struktura chyb pre modal, popisky uzavretych slovnikov, akcia
# `hws_preview`).
#
# Co davka slubuje (a co tieto testy strazia):
#   R2  `save_set!` je TROJICA a dialog jej treti prvok (STRUKTUROVANE chyby)
#       posiela modalu; zastarala revizia = `:conflict`, nikdy tichy prepis
#   R4  nahlad je CISTA funkcia nad DRAFTOM: ten isty vysledok, aky vyda
#       `expand` PO ulozeni toho isteho setu — a pritom NIC nezapisuje
#   R5  `active` rozhoduje VYHRADNE o ponuke; expanzia sa nemeni
#   R6  datovy tvar setu ani clena sa NEMENI
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do core spadne uvedeny test):
#   M2 `preview_expansion` si nacita ULOZENY set namiesto draftu
#      -> „KOV-B3 (M2): nahlad pocita z DRAFTU, nie z ulozeneho setu"
#   M3 `expand` zacne citat `active` (ponuka a NAKUP by sa rozisli)
#      -> „KOV-B1 (R4): `expand` aj `explain` `active` IGNORUJU…" (test_kovb1_sety.rb)
#   M4 `preview_expansion` zavola zapisovu cestu (napr. `save_set!`)
#      -> „KOV-B3 (M4): nahlad NIKDY nezapisuje…"
#   (M1 — nepripnuta revizia editora — strazi `tests/js/test_kovb3_modal.js`.)
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'json'

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog') if NxTest.headless?

module NxB3
  E     = Noxun::Engine
  HWS   = E::HardwareSets
  TAX   = E::HardwareTaxonomy
  STORE = E::JsonFileStore
  DLG   = E::HardwareCatalogDialog

  # Katalog nahladu — nazvy a ceny kodov (nahlad ho dostava LEN NA CITANIE).
  CATALOG = [
    { 'item_code' => '357695', 'name_sk' => 'K-Atira 420', 'category' => 'VYSUVY',
      'unit' => 'ks', 'price_eur_vat' => 18.9 },
    { 'item_code' => '357696', 'name_sk' => 'K-Atira 470', 'category' => 'VYSUVY',
      'unit' => 'ks', 'price_eur_vat' => 19.6 },
    { 'item_code' => '104717', 'name_sk' => 'Sensys 110', 'category' => 'ZAVESY',
      'unit' => 'ks', 'price_eur_vat' => 2.5 }
  ].freeze

  module_function

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

  # ZNAMA taxonomia v sandboxe. Klasifikovany set sa bez nej ulozit NEDA
  # (fail-closed `taxonomy_refusal`) a testy by zavisel na tom, co po sebe
  # nechala predchadzajuca sada — headless %APPDATA% je zdielany.
  def taxonomy!
    FileUtils.mkdir_p(File.dirname(TAX.path))
    doc = { 'std' => TAX::STD, 'schema' => TAX::SCHEMA_CURRENT,
            'seed_version' => TAX::SEED_VERSION,
            'manufacturers' => [{ 'name' => 'Hettich' }],
            'series' => [{ 'name' => 'InnoTech Atira', 'manufacturer' => 'Hettich' }] }
    File.binwrite(TAX.path, JSON.pretty_generate(doc))
    FileUtils.rm_f("#{TAX.path}.bak")
    STORE.invalidate(TAX.path)
    TAX.reset_state!
    doc
  end

  # Draft zasuvkoveho setu s radom NL (smoke scenar Michala).
  def atira(over = {})
    { 'set_id' => 'b3-atira', 'name' => 'B3 Atira',
      'use_type' => 'drawer', 'opening_mode' => 'classic',
      'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
      'series' => 'InnoTech Atira',
      'members' => [{ 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
                      'code_by_nl' => { '420' => '357695', '470' => '357696' } }] }.merge(over)
  end

  def hinge(over = {})
    { 'set_id' => 'b3-zaves', 'name' => 'B3 Záves', 'generic_type' => 'hinge',
      'members' => [{ 'code' => '104717', 'per' => 'unit', 'qty' => 2 }] }.merge(over)
  end

  # Ten isty synteticky vlastnik, akeho si sklada `preview_expansion` — bez
  # neho by sa `expand` porovnaval s inym vstupom a test by nedokazoval nic.
  def preview_item(gt, params)
    { 'generic_type' => gt, 'quantity' => 1, 'owner_id' => HWS::PREVIEW_OWNER,
      'owner_part_key' => nil, 'rule_id' => 'preview', 'params' => params }
  end

  # Docasne nahradenie modulovej metody (stub zapisovej cesty). `stub` je
  # ARGUMENT, nie blok — blok patri telu testu.
  def with_stub(name, stub)
    sing = HWS.singleton_class
    orig = HWS.method(name)
    sing.send(:define_method, name, stub)
    yield
  ensure
    sing.send(:define_method, name) { |*a, **k, &b| orig.call(*a, **k, &b) }
  end
end

# ============================================================================
# 1) NAHLAD = TEN ISTY VYSLEDOK AKO `expand` PO ULOZENI (R4)
# ============================================================================

NxTest.test('KOV-B3: nahlad draftu = deep-equal riadky ako `expand` po ulozeni toho isteho setu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB3
  b.with_library do
    b.taxonomy!
    draft = b.atira
    out, errors = b::HWS.preview_expansion(draft, catalog: b::CATALOG)
    NxTest.assert_equal([], errors, 'platny draft chyby nema')
    NxTest.assert(out.is_a?(Hash), 'nahlad vratil vysledok')

    status, saved = b::HWS.save_set!(draft, create: true)
    NxTest.assert_equal(:ok, status, "ten isty set sa da ULOZIT (#{saved.inspect})")
    state = { 'mapping' => { saved['generic_type'] => saved['set_id'] },
              'sets' => { saved['set_id'] => saved } }
    exp = b::HWS.expand([b.preview_item(saved['generic_type'], out['sample'])],
                        state, catalog: b::CATALOG)
    NxTest.assert_equal(exp['rows'], out['rows'],
                        'RIADKY nahladu su totozne s expanziou ulozeneho setu')
    NxTest.assert_equal(exp['unmapped'], out['unmapped'], 'aj nemapovane')
    NxTest.assert_equal(exp['summary'], out['summary'], 'aj sumar (vratane ceny)')
  end
end

NxTest.test('KOV-B3: nahlad ukaze kod, nazov aj cenu podla vzorovej NL (smoke scenar)') do
  b = NxB3
  out, = b::HWS.preview_expansion(b.atira, catalog: b::CATALOG)
  NxTest.assert_equal(['357696'], out['rows'].map { |r| r['code'] },
                      'NL 470 vybrala kod 357696')
  NxTest.assert_equal('K-Atira 470', out['rows'].first['name_sk'], 'nazov je z katalogu')
  NxTest.assert(out['text'].include?('NL 470'), "text menuje vzorovu NL: #{out['text']}")
  NxTest.assert(out['text'].include?('357696'), 'a objednavany kod')
  NxTest.assert(out['text'].include?('Zásuvka'), 'aj to, NA COM sa pocitalo')
  NxTest.assert(out['text'].include?('19,60'), "a cenu s DPH: #{out['text']}")
end

NxTest.test('KOV-B3 (M2): nahlad pocita z DRAFTU, nie z ulozeneho setu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB3
  b.with_library do
    status, = b::HWS.save_set!(b.hinge, create: true)
    NxTest.assert_equal(:ok, status, 'v kniznici je set s kodom 104717')
    # DRAFT s TOU ISTOU identitou, ale INYM kodom — nahlad musi ukazat DRAFT.
    draft = b.hinge('members' => [{ 'code' => '357695', 'per' => 'unit', 'qty' => 1 }])
    out, = b::HWS.preview_expansion(draft, catalog: b::CATALOG)
    NxTest.assert_equal(['357695'], out['rows'].map { |r| r['code'] },
                        'nahlad ukazal kod z DRAFTU')
    NxTest.assert_equal([104717].map(&:to_s), b::HWS.load['sets']
      .find { |s| s['set_id'] == 'b3-zaves' }['members'].map { |m| m['code'] },
                        'a ULOZENY set sa pritom nezmenil')
  end
end

NxTest.test('KOV-B3: nahlad zvlada aj set, ktory v kniznici VOBEC NIE JE') do
  b = NxB3
  out, errors = b::HWS.preview_expansion(b.hinge('set_id' => 'este-neexistuje'),
                                         catalog: b::CATALOG)
  NxTest.assert_equal([], errors, 'novy set nie je chyba')
  NxTest.assert_equal(['104717'], out['rows'].map { |r| r['code'] }, 'a nahlad ho spocita')
  NxTest.assert_equal(2, out['rows'].first['quantity'], 'pocet clena sa nasobi')
end

# ============================================================================
# 2) NAHLAD NIKDY NEZAPISUJE (R4, M4)
# ============================================================================

NxTest.test('KOV-B3 (M4): nahlad NIKDY nezapisuje — ani nesiahne na zamok kniznice') do
  b = NxB3
  # Zamok berie KAZDA zapisova cesta setov (`write`, `save_set!`, `delete_set!`,
  # `set_global_mapping!`, seed-merge). Ked ho nahlad nepotrebuje, nezapisuje.
  # Stub ZAZNAMENAVA (nie len vybuchne): `save_set!` ma vlastny `rescue`, takze
  # vynimka zo zamku by sa v nom stratila a mutacia „nahlad zapisuje" by cez
  # tento test presla.
  touched = []
  lock = proc { |*| touched << :lock; raise 'KOV-B3: nahlad siahol na ZAMOK kniznice' }
  write = proc { |*| touched << :write; raise 'KOV-B3: nahlad ZAPISAL do kniznice' }
  b.with_stub(:with_catalog_lock, lock) do
    b.with_stub(:write, write) do
      out, errors = b::HWS.preview_expansion(b.atira, catalog: b::CATALOG)
      NxTest.assert_equal([], errors, 'nahlad prebehol')
      NxTest.assert_equal(['357696'], out['rows'].map { |r| r['code'] }, 'a spocital riadky')
    end
  end
  NxTest.assert_equal([], touched,
                      "nahlad nesiahol ani na zamok, ani na zapis: #{touched.inspect}")
end

NxTest.test('KOV-B3: nahlad je CISTA funkcia — vstupny draft sa NEMENI') do
  b = NxB3
  draft = b.atira
  frozen = Marshal.dump(draft)
  b::HWS.preview_expansion(draft, catalog: b::CATALOG)
  NxTest.assert_equal(Marshal.load(frozen), draft, 'draft odisiel z nahladu nedotknuty')
end

# ============================================================================
# 3) VZOROVE PARAMETRE VLASTNIKA
# ============================================================================

NxTest.test('KOV-B3: vzorova NL — default, najblizsia vyssia, najdlhsia') do
  b = NxB3
  out, = b::HWS.preview_expansion(b.atira, catalog: b::CATALOG)
  NxTest.assert_equal(470.0, out['sample']['nominal_length'], 'rad 470 pozna -> default')

  kratky = b.atira('members' => [{ 'per' => 'unit', 'qty' => 1,
                                   'code_by_nl' => { '260' => '357695', '300' => '357696' } }])
  short, = b::HWS.preview_expansion(kratky, catalog: b::CATALOG)
  NxTest.assert_equal(300.0, short['sample']['nominal_length'],
                      'rad bez 470 dostane NAJDLHSIU existujucu (nie falosny ORANGE)')

  dlhy = b.atira('members' => [{ 'per' => 'unit', 'qty' => 1,
                                 'code_by_nl' => { '520' => '357695', '620' => '357696' } }])
  long, = b::HWS.preview_expansion(dlhy, catalog: b::CATALOG)
  NxTest.assert_equal(520.0, long['sample']['nominal_length'], 'inak najblizsiu VYSSIU')

  fixed, = b::HWS.preview_expansion(b.atira, catalog: b::CATALOG,
                                             sample: { 'nominal_length' => 420 })
  NxTest.assert_equal(420.0, fixed['sample']['nominal_length'],
                      'hodnota od pouzivatela ma VZDY prednost')
  NxTest.assert_equal(['357695'], fixed['rows'].map { |r| r['code'] }, 'a vyberie iny kod')
end

NxTest.test('KOV-B3: vzorove parametre su UZAVRETY zoznam — cudzi kluc sa zahodi') do
  b = NxB3
  out, = b::HWS.preview_expansion(b.atira, catalog: b::CATALOG,
                                           sample: { 'cut_length_mm' => 900,
                                                     'front_height' => 144 })
  NxTest.assert(!out['sample'].key?('cut_length_mm'),
                "cudzi parameter sa do vlastnika nedostane: #{out['sample'].inspect}")
  NxTest.assert_equal(144.0, out['sample']['front_height'], 'znamy parameter prejde')
end

NxTest.test('KOV-B3: pasma clena beru vzorovy parameter (noha podla vysky sokla)') do
  b = NxB3
  set = { 'set_id' => 'b3-nohy', 'name' => 'B3 Nohy', 'generic_type' => 'leg',
          'members' => [{ 'per' => 'unit', 'qty' => 4, 'label' => 'noha',
                          'param_bands' => { 'param' => 'height',
                                             'bands' => [{ 'min' => 90, 'max' => 120,
                                                           'code' => '104717' }] } }] }
  out, = b::HWS.preview_expansion(set, catalog: b::CATALOG)
  NxTest.assert_equal(['104717'], out['rows'].map { |r| r['code'] }, 'pasmo 90-120 chytilo 100 mm')
  NxTest.assert(out['text'].include?('výška sokla 100 mm'), "hlavicka to prizna: #{out['text']}")

  mimo, = b::HWS.preview_expansion(set, catalog: b::CATALOG, sample: { 'height' => 500 })
  NxTest.assert_equal([], mimo['rows'], 'hodnota mimo pasiem NIC neobjedna')
  NxTest.assert(mimo['text'].include?('mimo pásiem'),
                "a dovod je TA ISTA veta ako v supise: #{mimo['text']}")
end

# ============================================================================
# 4) STRUKTUROVANE CHYBY (R2)
# ============================================================================

NxTest.test('KOV-B3: neplatny draft vracia STRUKTUROVANE chyby s `row` a `field`') do
  b = NxB3
  out, errors = b::HWS.preview_expansion(b.atira('members' => [{ 'per' => 'unit', 'qty' => 1 }]),
                                         catalog: b::CATALOG)
  NxTest.assert(out.nil?, 'neplatny draft nahlad nevyda')
  NxTest.assert(errors.any?, 'ale povie PRECO')
  err = errors.first
  NxTest.assert_equal(0, err['row'], 'chyba nesie INDEX clena (editor ju ukaze pri nom)')
  NxTest.assert_equal('members', err['field'], 'a pole, ktoreho sa tyka')
  NxTest.assert(err['msg'].is_a?(String) && !err['msg'].empty?, 'sprava je hotova SK veta')
end

NxTest.test('KOV-B3: polovicna klasifikacia je chyba PRI POLI (ALL-OR-NOTHING)') do
  b = NxB3
  _out, errors = b::HWS.preview_expansion(b.atira('drawer_construction' => ''),
                                          catalog: b::CATALOG)
  NxTest.assert_equal(['drawer_construction'], errors.map { |e| e['field'] },
                      "chyba sadne na chybajucu konstrukciu: #{errors.inspect}")
  NxTest.assert(errors.first['row'].nil?, 'chyba CELEHO setu nema riadok')
end

NxTest.test('KOV-B3: `generic_type` odvodzuje SERVER — draft ho neposiela') do
  b = NxB3
  draft = b.atira
  NxTest.assert(!draft.key?('generic_type'), 'fixture ho naozaj nema')
  out, errors = b::HWS.preview_expansion(draft, catalog: b::CATALOG)
  NxTest.assert_equal([], errors, 'a napriek tomu prejde')
  NxTest.assert_equal(['357696'], out['rows'].map { |r| r['code'] },
                      'expanzia bezala ako VYSUV (odvodene z typu pouzitia)')
  # Protirecivy zapis sa ulozit NEDA — dva zapisy o tom istom sete by si klamali.
  _bad, berrors = b::HWS.preview_expansion(b.atira('generic_type' => 'hinge'),
                                           catalog: b::CATALOG)
  NxTest.assert_equal(['generic_type'], berrors.map { |e| e['field'] },
                      "nesediaci typ je chyba: #{berrors.inspect}")
end

NxTest.test('KOV-B3: nezaradeny (legacy) set sa da nahliadnut aj ulozit') do
  b = NxB3
  out, errors = b::HWS.preview_expansion(b.hinge, catalog: b::CATALOG)
  NxTest.assert_equal([], errors, 'legacy set bez klasifikacie je platny stav')
  NxTest.assert_equal(['104717'], out['rows'].map { |r| r['code'] }, 'a expanduje ako doteraz')
  NxTest.assert(out['text'].include?('Závesy'), "hlavicka menuje typ kovania: #{out['text']}")
end

# ============================================================================
# 5) SERVEROVY KONTRAKT DIALOGU (akcia, chyby, konflikt)
# ============================================================================

NxTest.test('KOV-B3: `hws_preview` je v UZAVRETOM whiteliste akcii sekcie') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  actions = NxB3::DLG::SECTION_ACTIONS
  NxTest.assert(actions.include?('hws_preview'), 'akcia nahladu je povolena')
  NxTest.assert_equal(actions.uniq, actions, 'whitelist nema duplicity')
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog.rb'))
  NxTest.assert(src.include?("when 'hws_preview'"), 'a dispatcher ju naozaj obsluhuje')
  NxTest.assert(src.include?('HWSETS.setResult'),
                'vysledok zapisu setu ide modalu (nie len do stavoveho riadku)')
  NxTest.assert(src.include?('HWSETS.taxonomy'),
                'a echo taxonomie dostane AJ modal setu (inak by cakal donekonecna)')
end

NxTest.test('KOV-B3: `hws_preview` vrati klientovi `gen`, `ok` aj hotovy text') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  b = NxB3
  out = []
  b::DLG.dispatch('hws_preview', { 'gen' => 7, 'set' => b.atira }.to_json, ->(s) { out << s })
  script = out.find { |s| s.start_with?('HWSETS.preview(') }
  NxTest.assert(script, "server poslal nahlad: #{out.inspect}")
  data = JSON.parse(script[('HWSETS.preview('.length)...-1])
  NxTest.assert_equal(7, data['gen'], 'generacia sa ECHUJE (poradie odpovedi drzi klient)')
  NxTest.assert_equal(true, data['ok'], 'platny draft')
  NxTest.assert(data['text'].to_s.include?('357696'), 'text nesie objednavany kod')
  NxTest.assert(data['rows'].is_a?(Array), 'a riadky pre dalsie pouzitie')
end

NxTest.test('KOV-B3: neplatny draft ide klientovi ako `ok: false` s chybami pri poli') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  b = NxB3
  out = []
  b::DLG.dispatch('hws_preview',
                  { 'gen' => 3, 'set' => b.atira('manufacturer' => '') }.to_json,
                  ->(s) { out << s })
  script = out.find { |s| s.start_with?('HWSETS.preview(') }
  data = JSON.parse(script[('HWSETS.preview('.length)...-1])
  NxTest.assert_equal(3, data['gen'], 'generacia sa echuje aj pri chybe')
  NxTest.assert_equal(false, data['ok'], 'a vysledok je odmietnutie')
  NxTest.assert_equal(['manufacturer'], data['errors'].map { |e| e['field'] },
                      "chyba mieri na pole: #{data['errors'].inspect}")
end

NxTest.test('KOV-B3: zastarala revizia je `:conflict` — nikdy tichy prepis') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  b = NxB3
  b.with_library do
    status, = b::HWS.save_set!(b.hinge, create: true)
    NxTest.assert_equal(:ok, status, 'set je v kniznici')
    stale = b::HWS.revision
    b::HWS.save_set!(b.hinge('name' => 'Cudzia zmena'))
    st2, _info, errs = b::HWS.save_set!(b.hinge('name' => 'Moja zmena'), revision: stale)
    NxTest.assert_equal(:conflict, st2, 'PRIPNUTA (zastarala) revizia zapis zastavi')
    NxTest.assert_equal('Cudzia zmena',
                        b::HWS.load['sets'].find { |s| s['set_id'] == 'b3-zaves' }['name'],
                        'a cudzia zmena zostala nedotknuta')
    NxTest.assert(errs.nil? || errs.empty?, 'konflikt nie je chyba POLA')
  end
end

# ============================================================================
# 6) SLOVNIKY KLASIFIKACIE MAJU JEDINU AUTORITU (R1)
# ============================================================================

NxTest.test('KOV-B3: popisky klasifikacie ziju v core a pokryvaju CELY slovnik') do
  b = NxB3
  opts = b::HWS::CLASS_OPTIONS
  NxTest.assert_equal(%w[use_type opening_mode drawer_construction], opts.keys,
                      'popisky ma kazdy uzavrety slovnik')
  NxTest.assert_equal(b::HWS::USE_TYPES, opts['use_type'].map(&:first), 'typ pouzitia 1:1')
  NxTest.assert_equal(b::HWS::OPENING_MODES, opts['opening_mode'].map(&:first), 'otvaranie 1:1')
  NxTest.assert_equal(b::HWS::DRAWER_CONSTRUCTIONS, opts['drawer_construction'].map(&:first),
                      'konstrukcia zasuvky 1:1')
  opts.each_value do |list|
    list.each { |(key, label)| NxTest.assert(!label.to_s.strip.empty?, "#{key} ma popisok") }
  end
  NxTest.assert_equal('Zásuvka', b::HWS.class_label('use_type', 'drawer'), 'popisok sa vracia')
  NxTest.assert_equal('sliding', b::HWS.class_label('use_type', 'sliding'),
                      'hodnota z NOVSEJ verzie sa NEPREKLADA')
end

NxTest.test('KOV-B3: JS ziadny vlastny zoznam klasifikacie nema (jedna pravda)') do
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hw_sets.js'))
  %w[Zásuvka Výklop Tip-On].each do |word|
    NxTest.assert(!js.include?(word), "hw_sets.js neopisuje slovnik (naslo sa „#{word}“)")
  end
  NxTest.assert(js.include?('class_options'), 'popisky berie z payloadu servera')
  # `code_by_height` je pojem, ktory NIKDY nevznikol (R4 architektury) —
  # v kode sa smie nanajvys spominat v komentari, nikdy sa nesmie ZAPISAT.
  NxTest.assert(!js.include?('code_by_height:') && !js.include?("'code_by_height'"),
                '`code_by_height` sa v editore nikdy nezapisuje')
end

NxTest.test('KOV-B3: payload sekcie nesie slovniky, vzorove parametre aj taxonomiu') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  b = NxB3
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog.rb'))
  NxTest.assert(src.include?("'class_options' => HardwareSets::CLASS_OPTIONS"),
                'slovniky idu klientovi z JEDINEJ autority')
  NxTest.assert(src.include?("'preview_sample' => HardwareSets::PREVIEW_SAMPLE"),
                'vzorove parametre nahladu tiez')
  NxTest.assert(src.include?("'taxonomy' => taxonomy_payload"),
                'a taxonomia pre selecty modalu setu')
end

# ============================================================================
# 7) PONUKA SETOV — `active` rozhoduje LEN tu (a referencovany set OSTAVA)
# ============================================================================

NxTest.test('KOV-B3: ponuka sekcie (`type_options`) neaktivny set UZ NENUKA') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  b = NxB3
  off = { 'set_id' => 'b3-off', 'name' => 'B3 neaktivny', 'generic_type' => 'hinge',
          'active' => false, 'members' => [{ 'code' => '104717', 'per' => 'unit', 'qty' => 1 }] }
  on  = { 'set_id' => 'b3-on', 'name' => 'B3 aktivny', 'generic_type' => 'hinge',
          'members' => [{ 'code' => '104717', 'per' => 'unit', 'qty' => 1 }] }
  lib = { 'sets' => [on, off], 'mapping' => {} }

  opts = b::DLG.project_type_options(lib, nil)
  NxTest.assert_equal(['b3-on'], opts['hinge'].map { |s| s['set_id'] },
                      'ponuka PROJEKTU neaktivny set preskoci')

  # ...ALE ked ho projekt PRAVE POUZIVA, v ponuke OSTAT MUSI — inak by select
  # ukazoval prazdno tam, kde hodnota je, a prvy klik vedla by ju prepisal.
  # (Toto je presne scenar in-SU sekcie `run_kovb3`.)
  state = { 'mapping' => { 'hinge' => 'b3-off' }, 'sets' => { 'b3-off' => off } }
  used = b::DLG.project_type_options(lib, state)
  NxTest.assert_equal(%w[b3-off b3-on].sort, used['hinge'].map { |s| s['set_id'] }.sort,
                      'REFERENCOVANY neaktivny set v ponuke OSTAVA')
end

NxTest.test('KOV-B3: `sets_payload` ma filter na TEJ ISTEJ ceste ako panel') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  dlg = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog.rb'))
  pay = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads.rb'))
  # OBE UI ponuky (predvolby projektu v Studiu aj override skrinky v paneli)
  # stavia TA ISTA funkcia — filter `active` preto nemoze mat dve pravdy.
  NxTest.assert(dlg.include?('HardwareSets.set_options('),
                'ponuka sekcie ide cez `set_options`')
  NxTest.assert(pay.include?('HardwareSets.set_options('),
                'a ponuka panela tiez (jedna cesta, jedno pravidlo)')
end
