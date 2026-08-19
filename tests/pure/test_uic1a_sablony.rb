# frozen_string_literal: true
# UI-C1a — DATOVA VRSTVA SABLON: druh (kind) na zazname, migracia std 1->2 so
# seedom doskovych sablon, forward guard (novsia schema = len na citanie),
# identita (kind, name) a poradie „naposledy pouzite" vo VLASTNOM subore.
#
# Kontrakty z Codex auditu davky:
#   BLOCKER 1 — doskovy zaznam nesie REDUNDANTNE config['type'] = 'board'
#   BLOCKER 2 — std > STD = read-only (upsert/delete/touch_used nezapisu)
#   BLOCKER 3 — doskovy seed pouziva KANONICKE polia dosky (STANDARD 8.3)
#   BLOCKER 4 — seed nemal orientaciu; UI-C1c ju doplnila (marker std 3,
#               hodnoty a migraciu strazi tests/pure/test_uic1c_orientacia.rb)
#   BLOCKER 5 — okno Sablony vidi VYHRADNE korpusove sablony
#   BLOCKER 6 — rovnake meno v inom druhu je INA sablona (seed nic neprepise)
#   BLOCKER 7 / FIX 13 — pouzitie zije v template_usage.json ako MONOTONNE
#                        pocitadlo (ziadne hodiny), subor sablon sa nemeni (N11)
#   FIX 8     — seed je viazany na PRECHOD markera, jeden atomicky zapis
#   FIX 9/10  — peciatka je samostatna operacia po vlozeni; metadata sablony sa
#               z insert payloadu odstrania PRED builderom
require_relative '../helper' unless defined?(NxTest)

# UI vrstva: reopeny Panel modulov su parse-safe (SketchUp API zije vyhradne
# vnutri metod). V SketchUpe su uz nacitane pluginom.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates')
end

module NxC1a
  TS = Noxun::Engine::TemplateStore
  TU = Noxun::Engine::TemplateUsage
  JFS = Noxun::Engine::JsonFileStore

  module_function

  # Cisty stav oboch suborov (sandbox APPDATA je zdielany celym behom, poradie
  # testov sa nesmie prenasat).
  def reset!
    [TS.path, TU.path].each do |p|
      FileUtils.rm_f(p)
      FileUtils.rm_f("#{p}.bak")
      JFS.invalidate(p)
    end
  end

  # Zapise subor sablon rucne (simulacia stareho/novsieho klienta).
  def write_raw!(payload)
    FileUtils.mkdir_p(TS.dir)
    File.binwrite(TS.path, JSON.generate(payload))
    FileUtils.rm_f("#{TS.path}.bak")
    JFS.invalidate(TS.path)
  end

  def raw
    JSON.parse(File.binread(TS.path))
  end

  def legacy_payload(templates)
    { 'std' => 1, 'templates' => templates }
  end

  def cab(name, width = 600.0)
    { 'name' => name, 'config' => { 'type' => 'lower', 'width' => width } }
  end
end

# ---------------------------------------------------------------------------
# migracia std 1 -> 2 + seed doskovych sablon (FIX 8)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a migracia: std 1 -> 2 doplni kind a doseje doskove sablony JEDNYM zapisom') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a.write_raw!(NxC1a.legacy_payload([NxC1a.cab('Stara dolna')]))

  list = NxC1a::TS.load
  NxTest.assert_equal(4, list.size, '1 legacy + 3 doskove zo seedu')
  legacy = list.find { |t| t['name'] == 'Stara dolna' }
  NxTest.assert_equal('cabinet', legacy['kind'], 'zaznam bez kind je korpusovy')

  raw = NxC1a.raw
  # UI-C1c: migracia je stupnovana — std 1 prejde rovno na AKTUALNY marker
  # (seed uz s orientaciou), stale JEDNYM zapisom.
  NxTest.assert_equal(NxC1a::TS::STD, raw['std'], 'marker posunuty na aktualny std')
  NxTest.assert_equal(%w[Diel Pracovná\ doska Zástena],
                      raw['templates'].select { |t| t['kind'] == 'board' }.map { |t| t['name'] })
end

NxTest.test('UI-C1a migracia: bezi RAZ — zmazanu doskovu sablonu seed nevrati') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a.write_raw!(NxC1a.legacy_payload([NxC1a.cab('Stara dolna')]))
  NxC1a::TS.load                                  # migracia + seed
  NxTest.assert_equal(true, NxC1a::TS.delete('board', 'Zástena'))

  before = File.binread(NxC1a::TS.path)
  list = NxC1a::TS.load
  NxTest.assert_equal(nil, list.find { |t| t['kind'] == 'board' && t['name'] == 'Zástena' },
                      'seed je markerovy, nie obsahovy — zmazana sablona sa nevracia')
  NxTest.assert_equal(before, File.binread(NxC1a::TS.path),
                      'load nad aktualnym markerom NEZAPISUJE')
end

NxTest.test('UI-C1a migracia: existujuca doskova sablona nezablokuje zvysok seedu') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  # Rucne upraveny subor std 1 uz obsahuje doskovu „Diel" (kind odvodeny z type).
  NxC1a.write_raw!(NxC1a.legacy_payload(
                     [NxC1a.cab('Stara dolna'),
                      { 'name' => 'Diel', 'config' => { 'type' => 'board', 'length' => 111.0 } }]
                   ))
  list = NxC1a::TS.load
  boards = list.select { |t| t['kind'] == 'board' }
  NxTest.assert_equal(%w[Diel Pracovná\ doska Zástena], boards.map { |t| t['name'] }.sort)
  NxTest.assert_close(111.0, NxC1a::TS.find('board', 'Diel')['config']['length'], 0.01,
                      'existujuca doskova sablona sa seedom NEPREPISE')
end

NxTest.test('UI-C1a migracia: nezname top-level kluce suboru prezijú zapis') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a.write_raw!(NxC1a.legacy_payload([NxC1a.cab('Stara dolna')]).merge('buduce_pole' => { 'x' => 1 }))
  NxC1a::TS.load
  NxTest.assert_equal({ 'x' => 1 }, NxC1a.raw['buduce_pole'], 'forward kompatibilita zapisu')
end

# ---------------------------------------------------------------------------
# doskovy seed — kanonicke polia (BLOCKER 3) bez orientacie (BLOCKER 4)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a seed dosiek: kanonicke polia dosky + redundantny type (orientaciu pridala UI-C1c)') do
  seeds = Noxun::Engine::TemplateStore.build_predefined_boards
  NxTest.assert_equal(%w[Diel Pracovná\ doska Zástena], seeds.map { |t| t['name'] })
  expected = { 'Diel' => [18.0, 800.0, 600.0],
               'Pracovná doska' => [38.0, 2600.0, 600.0],
               'Zástena' => [10.0, 2600.0, 580.0] }
  seeds.each do |t|
    NxTest.assert_equal('board', t['kind'], "#{t['name']}: kind na zazname")
    cfg = t['config']
    NxTest.assert_equal('board', cfg['type'], "#{t['name']}: redundantny config.type (BLOCKER 1)")
    th, len, wid = expected[t['name']]
    NxTest.assert_close(th, cfg['thickness'], 0.01, "#{t['name']}: hrubka")
    NxTest.assert_close(len, cfg['length'], 0.01, "#{t['name']}: dlzka")
    NxTest.assert_close(wid, cfg['width'], 0.01, "#{t['name']}: sirka")
    NxTest.assert_equal('length', cfg['grain_direction'], "#{t['name']}: smer dekoru")
    # UI-C1c: orientacia UZ v seede JE (slovnik a hodnoty strazi
    # tests/pure/test_uic1c_orientacia.rb) — tu len, ze kluc existuje.
    NxTest.assert(cfg.key?('orientation'), "#{t['name']}: orientaciu doplnila UI-C1c")
    NxTest.refute(cfg.key?('height'), "#{t['name']}: doska nema vysku (kanonicke su length/width)")
    # Codex #174 P2: material_id musi byt EXPLICITNE nil (kluc existuje) —
    # sablona bez materialu = vlozenie cez UNI mechanizmus s odomknutou
    # hrubkou (E-03), inak by insert_thickness_for hrubku sablony zahodil.
    NxTest.assert(cfg.key?('material_id'), "#{t['name']}: kontrakt „bez materialu“ je ZAPISANY")
    NxTest.assert_equal(nil, cfg['material_id'], "#{t['name']}: material_id je nil")
  end
end

NxTest.test('UI-C1a seed dosiek: kontrakt „bez materialu“ prezije aj zapis na disk') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load
  pd = NxC1a.raw['templates'].find { |t| t['kind'] == 'board' && t['name'] == 'Pracovná doska' }
  NxTest.assert(pd['config'].key?('material_id'), 'kluc material_id je v ulozenom JSON')
  NxTest.assert_equal(nil, pd['config']['material_id'], 'a ma hodnotu null')
  NxTest.assert_close(38.0, pd['config']['thickness'], 0.01, 'deklarovana hrubka PD ostava 38')
end

NxTest.test('UI-C1a: upsert doskovej sablony dopise config.type = board (ochrana stareho klienta)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.upsert('board', 'Rucna doska', 'length' => 500.0, 'width' => 400.0)
  rec = NxC1a::TS.find('board', 'Rucna doska')
  NxTest.assert_equal('board', rec['config']['type'], 'redundantny marker doplnil store')
end

# ---------------------------------------------------------------------------
# identita (kind, name) — BLOCKER 6
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a identita: rovnake meno v inom druhu su DVE sablony') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.upsert('cabinet', 'Zástena', 'type' => 'upper', 'width' => 333.0)

  cabinet = NxC1a::TS.find('cabinet', 'Zástena')
  board = NxC1a::TS.find('board', 'Zástena')
  NxTest.assert_close(333.0, cabinet['config']['width'], 0.01, 'korpusova Zastena ostala vlastna')
  NxTest.assert_equal('board', board['config']['type'], 'doskova Zastena zo seedu zije vedla nej')

  NxTest.assert_equal(true, NxC1a::TS.delete('cabinet', 'Zástena'))
  NxTest.assert_equal(nil, NxC1a::TS.find('cabinet', 'Zástena'), 'zmazana bola korpusova')
  NxTest.assert(NxC1a::TS.find('board', 'Zástena'), 'doskova Zastena mazanie prezila')
end

NxTest.test('UI-C1a identita: EXPLICITNY neznamy kind sa NEPREKLASIFIKUJE (Codex #174 P2)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  # Zaznam z hypotetickej novsej verzie — druh, ktoremu tento plugin nerozumie.
  NxC1a.write_raw!({ 'std' => 2,
                     'templates' => [{ 'name' => 'Zostava', 'kind' => 'fancy',
                                       'config' => { 'type' => 'lower' }, 'buduci_kluc' => 7 },
                                     { 'name' => 'Dolna klasik', 'kind' => 'cabinet',
                                       'config' => { 'type' => 'lower' } }] })

  rec = NxC1a::TS.load.find { |t| t['name'] == 'Zostava' }
  NxTest.assert_equal('fancy', rec['kind'], 'neznamy druh ostal, NEstal sa korpusom')
  NxTest.assert_equal(7, rec['buduci_kluc'], 'nezname kluce zaznamu prezili normalizaciu')

  # Nikde sa neponukne ani nenajde: ziadny filter cabinet/board ho nezachyti.
  NxTest.assert_equal(nil, NxC1a::TS.find('cabinet', 'Zostava'), 'find cabinet ho nevrati')
  NxTest.assert_equal(nil, NxC1a::TS.find('board', 'Zostava'), 'find board ho nevrati')
  panel_cab = Noxun::Engine::Panel.template_list(kind: 'cabinet')
  NxTest.refute(panel_cab.any? { |t| t['name'] == 'Zostava' }, 'okno Sablony ho neukaze')

  # Prezije zapis (cudzi upsert) BEZ ZMENY — vratane neznameho kluca.
  NxC1a::TS.upsert('cabinet', 'Nova', { 'type' => 'lower' })
  stored = NxC1a.raw['templates'].find { |t| t['name'] == 'Zostava' }
  NxTest.assert_equal('fancy', stored['kind'], 'zapis druh nezmenil')
  NxTest.assert_equal(7, stored['buduci_kluc'], 'zapis neznamy kluc zaznamu zachoval')
end

# ---------------------------------------------------------------------------
# forward guard — BLOCKER 2
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a guard: subor s novsou schemou je LEN NA CITANIE') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a.write_raw!({ 'std' => 99,
                     'templates' => [{ 'name' => 'Z buducnosti', 'kind' => 'cabinet',
                                       'config' => { 'type' => 'lower' } }] })
  before = File.binread(NxC1a::TS.path)

  NxTest.assert_equal(true, NxC1a::TS.read_only?, 'std > STD = read-only')
  NxTest.assert_equal(1, NxC1a::TS.load.size, 'citanie funguje dalej')
  NxTest.assert_equal(false, NxC1a::TS.upsert('cabinet', 'Nova', { 'type' => 'lower' }), 'upsert odmietnuty')
  NxTest.assert_equal(false, NxC1a::TS.delete('cabinet', 'Z buducnosti'), 'delete odmietnuty')
  NxTest.assert_equal(false, NxC1a::TS.touch_used('cabinet', 'Z buducnosti'), 'peciatka odmietnuta')
  NxTest.assert_equal(before, File.binread(NxC1a::TS.path), 'subor sa NEZMENIL ani o bajt')
  NxTest.refute(File.exist?(NxC1a::TU.path), 'ani subor pouzitia nevznikol')
end

# ---------------------------------------------------------------------------
# zamok read-modify-write (Codex #174 P2)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a zamok: zapis cita CERSTVY stav disku, nie stary snapshot') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load # naplni cache JsonFileStore

  # Simulacia DRUHEJ instancie SketchUpu: subor sa medzitym zmenil, ale nasa
  # cache o tom nevie (cache ma 1 s okno bez kontroly podpisu). Bez zamku,
  # ktory cache pod nim invaliduje, by upsert zapisal stary zoznam a cudziu
  # sablonu ticho zahodil.
  data = NxC1a.raw
  data['templates'] << { 'name' => 'Cudzia', 'kind' => 'cabinet',
                         'config' => { 'type' => 'lower', 'width' => 700.0 } }
  File.binwrite(NxC1a::TS.path, JSON.generate(data)) # ZAMERNE bez invalidate

  NxTest.assert_equal(true, NxC1a::TS.upsert('cabinet', 'Moja', { 'type' => 'lower' }))
  names = NxC1a.raw['templates'].map { |t| t['name'] }
  NxTest.assert(names.include?('Cudzia'), 'cudzi zapis prezil — citalo sa cerstvo z disku')
  NxTest.assert(names.include?('Moja'), 'vlastny zapis prebehol')
end

NxTest.test('UI-C1a zamok: je REENTRANTNY (verejny zapis pod uz drzanym zamkom)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  # upsert -> load -> ensure_current -> with_lock: vnutorne kroky uz pod zamkom
  # bezia. Druhy flock v tom istom procese by sa zablokoval sam na sebe, takze
  # tento test by pri chybajucej reentrancii NEDOBEHOL.
  res = NxC1a::TS.with_lock { NxC1a::TS.upsert('cabinet', 'Vnorena', { 'type' => 'lower' }) }
  NxTest.assert_equal(true, res, 'vnoreny zapis prebehol bez deadlocku')
  NxTest.assert(NxC1a::TS.find('cabinet', 'Vnorena'), 'sablona sa naozaj ulozila')
  NxTest.assert(File.exist?("#{NxC1a::TS.path}.lock"), 'zamok je SIDECAR subor, nie datovy')
end

NxTest.test('UI-C1a zamok: migracia sa pod zamkom znovu overi (dvojita kontrola)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load # marker uz je 2
  before = File.binread(NxC1a::TS.path)
  NxTest.assert_equal(true, NxC1a::TS.migrate!, 'migrate! nad aktualnym markerom je no-op')
  NxTest.assert_equal(before, File.binread(NxC1a::TS.path), 'a nic nezapisal')
end

# ---------------------------------------------------------------------------
# recency — vlastny subor, monotonne pocitadlo (FIX 13, BLOCKER 7)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a pouzitie: peciatka ide do INEHO suboru — templates.json ostava byte-nezmeneny') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load
  before = File.binread(NxC1a::TS.path)

  NxTest.assert_equal(true, NxC1a::TS.touch_used('cabinet', 'Dolna klasik'))
  NxTest.assert_equal(before, File.binread(NxC1a::TS.path), 'N11: subor sablon sa pouzitim NEMENI')
  NxTest.assert(File.exist?(NxC1a::TU.path), 'pouzitie ma vlastny subor')
  NxTest.assert_equal(1, NxC1a::TU.seq_for('cabinet', 'Dolna klasik'), 'prve pouzitie = 1')
end

NxTest.test('UI-C1a pouzitie: monotonne poradie, kluc nesie druh') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load
  NxC1a::TS.touch_used('cabinet', 'Dolna klasik')
  NxC1a::TS.touch_used('board', 'Zástena')
  NxC1a::TS.touch_used('cabinet', 'Dolna klasik')

  map = NxC1a::TU.map
  NxTest.assert_equal(3, map['cabinet:Dolna klasik'], 'druhe pouzitie posunulo poradie')
  NxTest.assert_equal(2, map['board:Zástena'], 'doskova sablona ma vlastny kluc')
  NxTest.assert(map['cabinet:Dolna klasik'] > map['board:Zástena'], 'najnovsie ma najvyssie cislo')
end

NxTest.test('UI-C1a pouzitie: cisla su odolne voci rucne upravenemu suboru') do
  # next_seq je cista funkcia — vzdy o 1 nad NAJVYSSIM znamym cislom
  # (ulozeny seq aj najvyssia peciatka), takze skrateny/rozbity subor
  # poradie nezvrati.
  tu = Noxun::Engine::TemplateUsage
  NxTest.assert_equal(1, tu.next_seq(nil, {}), 'prazdny subor')
  NxTest.assert_equal(6, tu.next_seq(5, {}), 'pokracuje za ulozenym seq')
  NxTest.assert_equal(10, tu.next_seq(2, { 'a' => 9 }), 'zaostavajuci seq doskoci na peciatky')
  NxTest.assert_equal({ 'a' => 3 }, tu.sanitize_entries('a' => 3, 'b' => -1, '' => 5, 'c' => 'x'),
                      'vadne polozky sa ticho zahodia')
  NxTest.assert_equal(nil, tu.key_for('cabinet', ''), 'prazdne meno nema kluc')
  NxTest.assert_equal('board:Diel', tu.key_for('board', 'Diel'))
end

NxTest.test('UI-C1a pouzitie: subor pouzitia s novsou schemou sa NEPREPISUJE') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load
  FileUtils.mkdir_p(NxC1a::TU.dir)
  File.binwrite(NxC1a::TU.path, JSON.generate({ 'std' => 42, 'seq' => 7, 'entries' => {} }))
  NxC1a::JFS.invalidate(NxC1a::TU.path)
  before = File.binread(NxC1a::TU.path)

  NxTest.assert_equal(false, NxC1a::TS.touch_used('cabinet', 'Dolna klasik'), 'peciatka preskocena')
  NxTest.assert_equal(before, File.binread(NxC1a::TU.path), 'subor pouzitia nezmeneny')
end

# ---------------------------------------------------------------------------
# payload panela + filter okna Sablony (BLOCKER 5)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a payload: panel dostane cely zoznam s kind a poradim pouzitia') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load
  NxC1a::TS.touch_used('board', 'Diel')

  list = Noxun::Engine::Panel.template_list
  NxTest.assert_equal(7, list.size, 'panel vidi korpusove AJ doskove')
  NxTest.assert(list.all? { |t| Noxun::Engine::TemplateStore::KINDS.include?(t['kind']) },
                'kazdy zaznam nesie kind')
  diel = list.find { |t| t['kind'] == 'board' && t['name'] == 'Diel' }
  NxTest.assert_equal(1, diel['used_seq'], 'pouzita sablona nesie poradove cislo')
  dolna = list.find { |t| t['name'] == 'Dolna klasik' }
  NxTest.assert_equal(nil, dolna['used_seq'], 'nikdy nepouzita = nil')
end

NxTest.test('UI-C1a payload: okno Sablony dostane VYHRADNE korpusove (BLOCKER 5)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load

  list = Noxun::Engine::Panel.template_list(kind: 'cabinet')
  NxTest.assert_equal(4, list.size, 'len 4 korpusove seedy')
  NxTest.refute(list.any? { |t| t['kind'] == 'board' }, 'doskova sablona sa v okne neukaze')
end

NxTest.test('UI-C1a guard: zdrojak okna Sablony filtruje kind aj v serverovych akciach') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?("Panel.template_list(kind: 'cabinet')"), 'payload okna je filtrovany')
  NxTest.assert(src.include?("TemplateStore.find('cabinet', name)"), 'apply hlada len korpusove')
  NxTest.assert(src.include?("TemplateStore.delete('cabinet', name)"), 'delete maze len korpusove')
  # UI-D2: save odovzdava aj capture nahladu (4. pozicny argument).
  NxTest.assert(src.include?("TemplateStore.upsert('cabinet', name, config, preview)"), 'save uklada korpusovu')
end

NxTest.test('UI-C1a guard: okno Sablony vetvi na ZLYHANY zapis (Codex #174 P2)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?("unless TemplateStore.upsert('cabinet', name, config, preview)"),
                'save vetvi na navratovu hodnotu — ziadny falosny uspech')
  NxTest.assert(src.include?("unless TemplateStore.delete('cabinet', name)"),
                'delete vetvi na navratovu hodnotu')
  # after_change (hlaska o uspechu + refresh) smie bezat LEN po uspesnom zapise:
  # v oboch vetvach musi byt medzi volanim store a after_change chybovy return.
  %w[upsert delete].each do |op|
    seg = src[/unless TemplateStore\.#{op}\('cabinet'.*?after_change/m]
    NxTest.assert(seg && seg.include?('set_status(') && seg.include?('return'),
                  "#{op}: pri zlyhani sa vracia chybovy status, nie hlaska o uspechu")
  end
end

# ---------------------------------------------------------------------------
# insert payload — metadata sablony (FIX 10) a nezavislost peciatky (FIX 9)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a insert: metadata sablony sa z payloadu ODSTRANIA pred builderom') do
  panel = Noxun::Engine::Panel
  params = { 'type' => 'lower', 'width' => 600.0,
             'template_kind' => 'cabinet', 'template_name' => 'Dolna klasik' }
  ref = panel.take_template_ref!(params, 'cabinet')
  NxTest.assert_equal(%w[cabinet Dolna\ klasik], ref, 'identita na peciatku')
  NxTest.refute(params.key?('template_kind'), 'builder metadata nevidi')
  NxTest.refute(params.key?('template_name'), 'builder metadata nevidi')
  NxTest.assert_equal(%w[type width], params.keys, 'ostatne polia ostali nedotknute')
end

NxTest.test('UI-C1a insert: nesediaci alebo chybajuci druh = ziadna peciatka') do
  panel = Noxun::Engine::Panel
  board_meta = { 'template_kind' => 'board', 'template_name' => 'Diel' }
  NxTest.assert_equal(nil, panel.take_template_ref!(board_meta.dup, 'cabinet'),
                      'doskova sablona vo vklade korpusu sa nepeciatkuje')
  NxTest.assert_equal(nil, panel.take_template_ref!({ 'template_kind' => 'cabinet' }, 'cabinet'),
                      'bez mena niet identity')
  NxTest.assert_equal(nil, panel.take_template_ref!({}, 'board'), 'vklad bez sablony')

  stripped = board_meta.dup
  panel.take_template_ref!(stripped, 'cabinet')
  NxTest.refute(stripped.key?('template_name'), 'metadata sa odstrania aj pri nesedacom druhu')
end

NxTest.test('UI-C1a insert: zmiznuta sablona peciatku ticho vynecha (vklad je uz hotovy)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a::TS.load
  panel = Noxun::Engine::Panel
  panel.stamp_template_used(%w[cabinet Neexistuje])
  NxTest.refute(File.exist?(NxC1a::TU.path), 'peciatka pre neznamu sablonu nevznikla')

  panel.stamp_template_used(nil) # vklad bez sablony — ziadny zapis, ziadna vynimka
  NxTest.refute(File.exist?(NxC1a::TU.path), 'vklad bez sablony nic nezapisuje')
end

# ---------------------------------------------------------------------------
# ciste citanie — scany katalogu nesmu zapisovat
# ---------------------------------------------------------------------------

NxTest.test('UI-C1a: load(migrate: false) je CISTE CITANIE (dry_run kontrakt)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1a.reset!
  NxC1a.write_raw!(NxC1a.legacy_payload([NxC1a.cab('Stara dolna')]))
  before = File.binread(NxC1a::TS.path)

  list = NxC1a::TS.load(migrate: false)
  NxTest.assert_equal(1, list.size, 'vrati obsah suboru bez seedu')
  NxTest.assert_equal('cabinet', list[0]['kind'], 'kind sa doplni v pamati')
  NxTest.assert_equal(before, File.binread(NxC1a::TS.path), 'subor sa NEZMENIL')

  NxC1a.reset!
  NxTest.assert_equal([], NxC1a::TS.load(migrate: false), 'chybajuci subor sa NESEEDUJE')
  NxTest.refute(File.exist?(NxC1a::TS.path), 'scan subor nevytvoril')
end
