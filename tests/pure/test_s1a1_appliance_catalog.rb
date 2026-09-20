# frozen_string_literal: true
# Testy S1-A1: katalog spotrebicov — schema zaznamu a stvorice blokov `dims`,
# seed 9 overenych modelov, `rev` guard na KAZDEJ mutacii, tombstone, matica
# `assess!` (ok / read_only / degraded), prilohy (nemenny nazov, staging,
# limit velkosti, jeden nahlad) a `snapshot_for` pre zakazku.
#
# IZOLACIA: vlastny `test_dir_override` do docasneho priecinka — testy sa
# NIKDY nedotknu realneho `%APPDATA%\NOXUN\Engine` (ani ked sada bezi vnutri
# SketchUpu, kde helper APPDATA nepresmeruje).
require_relative '../helper' unless defined?(NxTest)
require 'rbconfig'
require 'tmpdir'

APPLC = Noxun::Engine::ApplianceCatalog
APPLC_JFS = Noxun::Engine::JsonFileStore
APPLC_ROOT = File.join(Dir.mktmpdir('noxun-appl-'), 'Engine')

# Cisty stav BEZ suboru (seed sa spusti pri prvom pristupe).
def applc_wipe!
  APPLC.test_dir_override = APPLC_ROOT
  FileUtils.rm_rf(APPLC_ROOT)
  FileUtils.mkdir_p(APPLC_ROOT)
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
end

# Nainstaluje PRESNY dokument (na testy matice assess! a forward guardu).
def applc_install!(doc)
  applc_wipe!
  File.binwrite(APPLC.path, JSON.pretty_generate(doc))
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
end

def applc_doc
  JSON.parse(File.binread(APPLC.path))
end

def applc_seeded!
  applc_wipe!
  APPLC.list # prvy pristup = seed
end

def applc_new(over = {})
  { 'category' => 'sink', 'name' => 'Legra XL 6 S', 'manufacturer' => 'Blanco' }.merge(over)
end

# Docasny subor so ZADANYM menom (diakritika a medzery su tu zamerne).
def applc_tmp_file(name, bytes = 'PDF')
  dir = File.join(APPLC_ROOT, 'zdroj')
  FileUtils.mkdir_p(dir)
  path = File.join(dir, name)
  File.binwrite(path, bytes)
  path
end

# Docasny stub `JsonFileStore.write` (zlyhany zapis JSON).
def applc_with_failing_write
  orig = APPLC_JFS.method(:write)
  APPLC_JFS.define_singleton_method(:write) { |*| raise IOError, 'test: disk plny' }
  yield
ensure
  APPLC_JFS.define_singleton_method(:write, orig)
end

# Docasny stub `File.size` (velkost prilohy sa nesimuluje realnym 25 MB suborom).
# `resolver` je lambda (cesta, povodna_metoda) -> velkost.
def applc_with_size_stub(resolver)
  orig = File.method(:size)
  File.define_singleton_method(:size) { |p| resolver.call(p.to_s, orig) }
  yield
ensure
  File.define_singleton_method(:size, orig)
end

# --- seed --------------------------------------------------------------------

NxTest.test('spotrebice: seed = PRESNE 9 overenych modelov, vsetky so `seed: true` a bez priloh') do
  applc_seeded!
  st, info = APPLC.list
  NxTest.assert_equal(:ok, st)
  recs = info[:records]
  NxTest.assert_equal(9, recs.length, "seed ma 9 modelov, dostal #{recs.length}")
  NxTest.assert(recs.all? { |r| r['seed'] == true }, 'kazdy seed zaznam nesie seed: true')
  NxTest.assert(recs.none? { |r| r.key?('attachments') }, 'seed nesie len URL, ziadne prilohy')
  NxTest.assert(recs.all? { |r| !r['id'].to_s.empty? && !r['created_at'].to_s.empty? },
                'seed zaznam ma UUID aj cas vzniku')
  # Drez Blanco sa VEDOME neseeduje (list vyrobcu neoverený, OVERENIE §12).
  NxTest.assert(recs.none? { |r| r['category'] == 'sink' }, 'drez v seede nie je')
  counts = recs.group_by { |r| r['category'] }.transform_values(&:length)
  NxTest.assert_equal({ 'oven' => 2, 'microwave' => 2, 'fridge' => 1, 'dishwasher' => 2,
                        'hob' => 1, 'hood' => 1 }, counts, 'rozlozenie kategorii seedu')
  NxTest.assert_equal(1, applc_doc['seed_version'], 'marker seedu je v subore')
  NxTest.assert_equal(1, applc_doc['std'], 'marker schemy je v subore')
end

NxTest.test('spotrebice: seed nesie cisla z overenia listov (rura, chladnicka, umyvacka, doska, digestor)') do
  applc_seeded!
  by_name = APPLC.list[1][:records].each_with_object({}) { |r, out| out[r['name']] = r }

  rura = by_name['OMSR58RU1SB']['dims']
  NxTest.assert_close(548.0, rura['body']['width'], 0.01)
  NxTest.assert_close(583.0, rura['niche']['height_min'], 0.01)
  NxTest.assert_close(9.0, rura['front']['vent_gap_below'], 0.01, 'povinna medzera pod celom')
  NxTest.assert_equal('body', rura['front']['overhang_ref'], 'Whirlpool kotuje presah voci TELU')

  bosch = by_name['BFL7221B1']
  NxTest.assert_equal('niche', bosch['dims']['front']['overhang_ref'], 'Bosch kotuje presah voci NIKE')
  NxTest.assert_equal(%w[body.width body.height], bosch['derived'], 'telo BFL7221B1 je odvodene')

  hbg = by_name['HBG774KB1']
  NxTest.refute(hbg['dims']['body'].key?('width'), 'sirku tela list nekotuje — kluc CHYBA (ziadny default)')
  NxTest.assert_equal(%w[body.depth], hbg['derived'])

  beko = by_name['BCNA306E5ZSN']['dims']
  NxTest.assert_close(1940.0, beko['niche']['height_min'], 0.01)
  NxTest.assert_close(1950.0, beko['niche']['height_max'], 0.01)
  NxTest.assert_close(629.0, beko['front']['door_lower'], 0.01)
  NxTest.assert_close(71.0, beko['front']['door_gap'], 0.01)
  NxTest.assert_equal('sliding', beko['install']['door_system'])

  wio = by_name['WIO 3O540 PELG']['dims']
  NxTest.assert_equal('600', wio['install']['dishwasher_class'], 'trieda je KOD, nie rozmer')
  NxTest.assert_close(720.0, wio['front']['height_max'], 0.01)
  NxTest.assert_close(10.0, wio['front']['weight_max'], 0.01, 'hmotnost je v kg')

  spv = by_name['SPV6EMX05E']['dims']
  NxTest.assert_equal('450', spv['install']['dishwasher_class'])
  NxTest.assert_close(220.0, spv['install']['plinth_max'], 0.01)

  hob = by_name['WL B1160 BF']['dims']['front']
  NxTest.assert_close(560.0, hob['cutout_width'], 0.01)
  NxTest.assert_close(480.0, hob['cutout_depth'], 0.01)
  NxTest.assert_close(492.0, hob['cutout_depth_max'], 0.01)
  NxTest.refute(hob.key?('radius'), 'radius vyrezu dosky je v poznamke, nie pole (R ≤ 10)')

  hood = by_name['WCT3 63F LTK']['dims']['front']
  NxTest.assert_close(437.0, hood['cutout_width'], 0.01)
  NxTest.assert_close(216.0, hood['cutout_depth'], 0.01)
  NxTest.assert_close(149.0, hood['duct_diameter'], 0.01)

  NxTest.assert(by_name.values.all? { |r| Array(r['sheet_urls']).any? },
                'kazdy seed model nesie odkaz na list vyrobcu (§11)')
end

NxTest.test('spotrebice: seed sa po zmazani zaznamu NEOPAKUJE (markerovy, nie obsahovy)') do
  applc_seeded!
  doc = applc_doc
  doc['records'] = doc['records'][0, 8] # pouzivatel jeden model zmazal
  File.binwrite(APPLC.path, JSON.pretty_generate(doc))
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
  NxTest.assert_equal(8, APPLC.list[1][:records].length, 'plugin zmazany seed zaznam nevrati')
end

NxTest.test('spotrebice: SK popisky pokryvaju kategorie PRESNE (parity guard)') do
  NxTest.assert_equal(APPLC::CATEGORIES.sort, APPLC::CATEGORY_LABELS.keys.sort,
                      'kazdy kod ma popisok a kazdy popisok patri kodu')
  NxTest.assert(APPLC::CATEGORY_LABELS.values.none? { |v| v.to_s.strip.empty? }, 'ziadny prazdny popisok')
  NxTest.assert_equal('Umývačka', APPLC.category_label('dishwasher'))
  NxTest.assert_equal('neznamy', APPLC.category_label('neznamy'), 'neznamy kod sa NEPREKLADA')
  NxTest.assert(APPLC::FRONT_FIELDS.keys.sort == APPLC::CATEGORIES.sort,
                'blok `front` ma definiciu pre kazdu kategoriu')
end

# --- create / patch / rev guard ----------------------------------------------

NxTest.test('spotrebice: create — kategoria povinna, UUID a casy zo servera, klientske kluce sa ignoruju') do
  applc_seeded!
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('category' => 'ine'))[0], 'neznama kategoria')
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('name' => '  '))[0], 'bez nazvu nie')

  st, info = APPLC.create!(applc_new('id' => 'PODVRH', 'rev' => 'x', 'seed' => true,
                                     'attachments' => [{ 'id' => 'x' }],
                                     'created_at' => '2000-01-01T00:00:00Z'))
  NxTest.assert_equal(:ok, st)
  rec = info[:record]
  NxTest.refute(rec['id'] == 'PODVRH', 'id je serverove UUID')
  NxTest.refute(rec.key?('seed'), 'seed sa z klienta nepreberie')
  NxTest.refute(rec.key?('attachments'), 'prilohy sa z klienta nepreberu')
  NxTest.refute(rec['created_at'] == '2000-01-01T00:00:00Z', 'cas vzniku dava server')
  NxTest.assert_equal(12, rec['rev'].to_s.length, 'rev je odtlacok obsahu (12 hex)')
  NxTest.refute(applc_doc['records'].last.key?('rev'), 'rev sa do suboru NEUKLADA (A6)')
  NxTest.assert_equal(10, APPLC.list[1][:records].length)
end

NxTest.test('spotrebice: patch — rev guard, not_found, kategoria sa uz nemeni, whitelist vstupu') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]

  NxTest.assert_equal(:not_found, APPLC.patch!('neexistuje', { 'name' => 'X' }, rev: rec['rev'])[0])
  NxTest.assert_equal(:conflict, APPLC.patch!(rec['id'], { 'name' => 'X' }, rev: 'stara')[0])
  NxTest.assert_equal(:conflict, APPLC.patch!(rec['id'], { 'name' => 'X' }, rev: '')[0],
                      'prazdna rev NIKDY neprejde — server ju za klienta nedosadi (A1)')
  st, info = APPLC.patch!(rec['id'], { 'category' => 'oven' }, rev: rec['rev'])
  NxTest.assert_equal(:invalid, st)
  NxTest.assert_equal('category', info[:field], 'chyba nesie POLE (modal ju kresli pri nom)')

  st2, info2 = APPLC.patch!(rec['id'], { 'name' => 'Legra XL 6 S antracit', 'seed' => true,
                                         'id' => 'PODVRH', 'attachments' => [] }, rev: rec['rev'])
  NxTest.assert_equal(:ok, st2)
  NxTest.assert_equal('Legra XL 6 S antracit', info2[:record]['name'])
  NxTest.assert_equal(rec['id'], info2[:record]['id'], 'id sa patchom nemeni')
  NxTest.refute(info2[:record].key?('seed'), 'seed sa z klienta nepreberie ani patchom')
  NxTest.refute(rec['rev'] == info2[:record]['rev'], 'zmena obsahu zmeni rev')
  # Stare okno s povodnou rev uz neprejde (optimisticka sucasnost).
  NxTest.assert_equal(:conflict, APPLC.patch!(rec['id'], { 'note' => 'stare okno' }, rev: rec['rev'])[0])
end

NxTest.test('spotrebice: patch — nezname kluce PREZIJU, ale z klienta sa NEPREBERAJU (A3)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  doc = applc_doc
  row = doc['records'].find { |r| r['id'] == rec['id'] }
  row['legacy_note'] = 'z novsej verzie'
  row['dims'] = { 'front' => { 'outer_width' => 860.0, 'future_key' => 'x' },
                  'future_block' => { 'a' => 1 } }
  File.binwrite(APPLC.path, JSON.pretty_generate(doc))
  APPLC_JFS.invalidate(APPLC.path)

  fresh = APPLC.find(rec['id'])[1][:record]
  st, info = APPLC.patch!(rec['id'], { 'note' => 'poznamka', 'legacy_note' => 'PODVRH' },
                          rev: fresh['rev'])
  NxTest.assert_equal(:ok, st)
  out = info[:record]
  NxTest.assert_equal('z novsej verzie', out['legacy_note'], 'neznamy kluc zaznamu prezije zapis')
  NxTest.assert_equal('x', out['dims']['front']['future_key'], 'neznamy kluc bloku prezije')
  NxTest.assert_equal({ 'a' => 1 }, out['dims']['future_block'], 'neznamy BLOK prezije nedotknuty')
  NxTest.assert_close(860.0, out['dims']['front']['outer_width'], 0.01, 'znama hodnota ostava')
end

NxTest.test('spotrebice: patch `dims` je hlboke zlucenie po listoch — null maze, susedia ostavaju (A10)') do
  applc_seeded!
  rec = APPLC.create!(applc_new('dims' => {
                                  'front' => { 'outer_width' => 860, 'outer_depth' => 500,
                                               'cutout_width' => 840, 'mount' => 'top' },
                                  'install' => { 'hinge_side' => 'left' }
                                }))[1][:record]
  st, info = APPLC.patch!(rec['id'], { 'dims' => { 'front' => { 'outer_width' => 870 } } },
                          rev: rec['rev'])
  NxTest.assert_equal(:ok, st)
  front = info[:record]['dims']['front']
  NxTest.assert_close(870.0, front['outer_width'], 0.01)
  NxTest.assert_close(500.0, front['outer_depth'], 0.01, 'neprítomne pole sa ZACHOVA')
  NxTest.assert_equal('left', info[:record]['dims']['install']['hinge_side'], 'iny blok sa nedotkne')

  st2, info2 = APPLC.patch!(rec['id'], { 'dims' => { 'front' => { 'outer_depth' => nil } } },
                            rev: info[:record]['rev'])
  NxTest.assert_equal(:ok, st2)
  NxTest.refute(info2[:record]['dims']['front'].key?('outer_depth'), 'explicitne null ZMAZE kluc')
  NxTest.assert_close(870.0, info2[:record]['dims']['front']['outer_width'], 0.01)

  st3, info3 = APPLC.patch!(rec['id'], { 'dims' => { 'install' => nil } }, rev: info2[:record]['rev'])
  NxTest.assert_equal(:ok, st3)
  NxTest.refute(info3[:record]['dims'].key?('install'), 'null nad celym blokom ho zmaze')
end

# --- validacia ----------------------------------------------------------------

NxTest.test('spotrebice: validacia `dims` — min ≤ max, rozsahy, enumy; chyba nesie CESTU pola') do
  applc_seeded!
  st, info = APPLC.create!(applc_new('dims' => { 'niche' => { 'width_min' => 700, 'width_max' => 600 } }))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert_equal('dims.niche.width_min', info[:field])

  st2, info2 = APPLC.create!(applc_new('dims' => { 'body' => { 'width' => 9000 } }))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert_equal('dims.body.width', info2[:field], 'mimo rozsahu 0–5000')

  st3, info3 = APPLC.create!(applc_new('dims' => { 'body' => { 'width' => -1 } }))
  NxTest.assert_equal(:invalid, st3)
  NxTest.assert_equal('dims.body.width', info3[:field], 'zaporny rozmer nie')

  st4, info4 = APPLC.create!(applc_new('dims' => { 'front' => { 'mount' => 'bokom' } }))
  NxTest.assert_equal(:invalid, st4)
  NxTest.assert_equal('dims.front.mount', info4[:field], 'enum montaze')

  st5, info5 = APPLC.create!(applc_new('dims' => { 'front' => { 'outer_width' => 'sirka' } }))
  NxTest.assert_equal(:invalid, st5)
  NxTest.assert_equal('dims.front.outer_width', info5[:field], 'necislo sa odmietne, neprepadne na 0')

  st6, info6 = APPLC.create!(applc_new('category' => 'dishwasher', 'name' => 'Test 45',
                                       'dims' => { 'front' => { 'weight_min' => 4, 'weight_max' => 300 } }))
  NxTest.assert_equal(:invalid, st6)
  NxTest.assert_equal('dims.front.weight_max', info6[:field], 'kg maju vlastny strop (0–100)')

  st7, info7 = APPLC.create!(applc_new('category' => 'hob', 'name' => 'Doska',
                                       'dims' => { 'front' => { 'cutout_depth' => 500,
                                                                'cutout_depth_max' => 492 } }))
  NxTest.assert_equal(:invalid, st7)
  NxTest.assert_equal('dims.front.cutout_depth', info7[:field], 'vyrez dosky ma vlastnu dvojicu min/max')

  st8, info8 = APPLC.create!(applc_new('category' => 'fridge', 'name' => 'Chlad',
                                       'dims' => { 'front' => { 'furniture_doors' => { 'lower_min' => 700,
                                                                                       'lower_max' => 600 } } }))
  NxTest.assert_equal(:invalid, st8)
  NxTest.assert_equal('dims.front.furniture_doors.lower_min', info8[:field], 'aj vnoreny blok ma cestu')

  st9, = APPLC.create!(applc_new('category' => 'fridge', 'name' => 'Chlad OK',
                                 'dims' => { 'front' => { 'furniture_doors' => { 'lower_min' => 600,
                                                                                 'lower_max' => 700,
                                                                                 'gap_ref' => 4 } },
                                             'install' => { 'door_system' => 'sliding',
                                                            'hinge_side' => 'reversible' } }))
  NxTest.assert_equal(:ok, st9, 'platny zaznam chladnicky prejde')
end

NxTest.test('spotrebice: validacia identity a odkazov — nazov, poznamka, URL, derived') do
  applc_seeded!
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('name' => 'x' * 201))[0], 'nazov nad 200')
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('note' => 'x' * 1001))[0], 'poznamka nad 1000')
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('shop_urls' => ['ftp://x.sk']))[0], 'len http(s)')
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('sheet_urls' => ["https://x.sk/#{'a' * 500}"]))[0],
                      'odkaz nad 500 znakov')
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('derived' => ['cena']))[0],
                      'derived musi byt cesta do znameho bloku')
  st, info = APPLC.create!(applc_new('shop_urls' => ['https://drezyonline.sk/p47410', ' '],
                                     'derived' => ['front.outer_width']))
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal(['https://drezyonline.sk/p47410'], info[:record]['shop_urls'], 'prazdne odkazy vypadnu')
end

# --- tombstone / restore -------------------------------------------------------

NxTest.test('spotrebice: delete = TOMBSTONE s rev guardom; restore ma rovnaky guard (A1)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  NxTest.assert_equal(:conflict, APPLC.delete!(rec['id'], rev: 'stara')[0], 'stale okno nevyradi zaznam')

  st, info = APPLC.delete!(rec['id'], rev: rec['rev'])
  NxTest.assert_equal(:ok, st)
  deleted = info[:record]
  NxTest.refute(deleted['deleted_at'].to_s.empty?, 'tombstone nesie cas vyradenia')
  NxTest.assert_equal(9, APPLC.list[1][:records].length, 'vyradeny zaznam v zozname nie je')
  NxTest.assert_equal(10, APPLC.list(include_deleted: true)[1][:records].length)
  NxTest.assert_equal(:ok, APPLC.find(rec['id'])[0], 'find ho stale najde (zakazka nan moze odkazovat)')

  NxTest.assert_equal(:conflict, APPLC.restore!(rec['id'], rev: rec['rev'])[0],
                      'obnova zo STAREHO okna = conflict')
  st2, info2 = APPLC.restore!(rec['id'], rev: deleted['rev'])
  NxTest.assert_equal(:ok, st2)
  NxTest.refute(info2[:record].key?('deleted_at'), 'obnoveny zaznam uz tombstone nema')
  NxTest.assert_equal(10, APPLC.list[1][:records].length)
end

# --- matica assess! ------------------------------------------------------------

NxTest.test('spotrebice: assess! — chybajuci primar s platnou .bak NIE JE prva instalacia (ziadny seed)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  NxTest.assert(File.exist?("#{APPLC.path}.bak"), 'druhy zapis zalohu vyrobil')
  File.delete(APPLC.path)
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
  st, info = APPLC.list
  NxTest.assert_equal(:ok, st)
  NxTest.assert(info[:records].any? { |r| r['id'] == rec['id'] } || info[:records].length >= 9,
                'cita sa zaloha, katalog sa NESEJE nanovo')
  NxTest.refute(File.exist?(APPLC.path), 'citanie samo primar neobnovi')
end

NxTest.test('spotrebice: assess! — poskodeny primar s platnou .bak = DEGRADED (citanie zo zalohy, zapisy stoja)') do
  applc_seeded!
  APPLC.create!(applc_new) # druhy zapis = vznikne .bak
  File.binwrite(APPLC.path, '{ toto nie je JSON')
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
  NxTest.assert_equal(:degraded, APPLC.state)
  NxTest.assert(APPLC.list[1][:records].length >= 9, 'citanie bezi zo zalohy')
  st, info = APPLC.create!(applc_new('name' => 'Dalsi'))
  NxTest.assert_equal(:degraded, st, 'zapis nad zalohou by zahodil zmeny po poslednej zalohe')
  NxTest.assert(info[:message].to_s.include?('poškodený'), 'odpoved nesie dovod')
end

NxTest.test('spotrebice: assess! — poskodeny primar BEZ zalohy = READ-ONLY s dovodom') do
  applc_wipe!
  File.binwrite(APPLC.path, 'rozbite')
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
  NxTest.assert_equal(:read_only, APPLC.state)
  NxTest.assert(APPLC.state_reason.include?('poškodený'), "dovod: #{APPLC.state_reason}")
  NxTest.assert_equal(:read_only, APPLC.create!(applc_new)[0])
end

NxTest.test('spotrebice: forward guard — subor z NOVSIEHO pluginu sa CITA, ale nezapisuje') do
  applc_install!('std' => 99, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'oven', 'name' => 'Z novsej verzie' }])
  NxTest.assert_equal(:read_only, APPLC.state)
  NxTest.assert(APPLC.state_reason.include?('aktualizuj plugin'), "dovod: #{APPLC.state_reason}")
  st, info = APPLC.list
  NxTest.assert_equal(:ok, st, 'citanie bezi dalej')
  NxTest.assert_equal(1, info[:records].length)
  NxTest.assert_equal(:read_only, APPLC.create!(applc_new)[0], 'create odmietnuty')
  NxTest.assert_equal(:read_only, APPLC.patch!('a1', { 'name' => 'X' }, rev: info[:records][0]['rev'])[0])
  NxTest.assert_equal(:read_only, APPLC.delete!('a1', rev: info[:records][0]['rev'])[0])
  NxTest.assert_equal(99, applc_doc['std'], 'subor ostal bajtovo na svojej schéme')
end

NxTest.test('spotrebice: assess! — necitatelny tvar, chybajuci marker a duplicitne identity = READ-ONLY') do
  applc_install!('std' => 1, 'records' => 'nie je pole')
  NxTest.assert_equal(:read_only, APPLC.state, 'records musi byt pole')

  applc_install!('seed_version' => 1, 'records' => [])
  NxTest.assert_equal(:read_only, APPLC.state, 'chybajuci std')

  applc_install!('std' => '1', 'records' => [])
  NxTest.assert_equal(:read_only, APPLC.state, 'std musi byt cislo')

  applc_install!('std' => 1, 'records' => [{ 'category' => 'oven', 'name' => 'Bez identity' }])
  NxTest.assert_equal(:read_only, APPLC.state, 'zaznam bez UUID')

  applc_install!('std' => 1, 'records' => [{ 'id' => 'x', 'name' => 'A' }, { 'id' => 'x', 'name' => 'B' }])
  NxTest.assert_equal(:read_only, APPLC.state, 'duplicitne identity')
  NxTest.assert(APPLC.state_reason.include?('duplicitné'), "dovod: #{APPLC.state_reason}")
end

NxTest.test('spotrebice: rev je ODTLACOK OBSAHU — po obnove zo zalohy sa pre INY obsah nezopakuje (A6)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  r1 = rec['rev']
  patched = APPLC.patch!(rec['id'], { 'note' => 'A' }, rev: r1)[1][:record]
  NxTest.refute(r1 == patched['rev'], 'iny obsah = ina revizia')
  NxTest.assert_equal(12, patched['rev'].to_s.length)
  NxTest.refute(applc_doc['records'].any? { |r| r.key?('rev') }, 'rev sa do suboru NEUKLADA')

  # Obnova zo zalohy: subor pod nami nahradi STARSI obsah toho isteho zaznamu.
  # Pocitadlo by po obnove mohlo vydat TU ISTU hodnotu pre iny obsah a zapis zo
  # stareho okna by presiel; odtlacok obsahu to nedovoli.
  doc = applc_doc
  row = doc['records'].find { |r| r['id'] == rec['id'] }
  row['note'] = 'obsah zo zalohy'
  File.binwrite(APPLC.path, JSON.pretty_generate(doc))
  APPLC_JFS.invalidate(APPLC.path)
  NxTest.assert_equal(:conflict, APPLC.patch!(rec['id'], { 'note' => 'B' }, rev: r1)[0])
  NxTest.assert_equal(:conflict, APPLC.patch!(rec['id'], { 'note' => 'B' }, rev: patched['rev'])[0])
  restored = APPLC.find(rec['id'])[1][:record]
  NxTest.assert_equal(:ok, APPLC.patch!(rec['id'], { 'note' => 'B' }, rev: restored['rev'])[0],
                      'kto cital obnoveny obsah, ten zapisat SMIE')
end

# --- prilohy -------------------------------------------------------------------

NxTest.test('spotrebice: attach — kopia do priecinka zaznamu, sanitizovany a NEMENNY nazov suboru') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  src = applc_tmp_file('Technický list — drez.pdf', 'PDF-1')
  st, info = APPLC.attach!(rec['id'], src, kind: 'sheet', rev: rec['rev'])
  NxTest.assert_equal(:ok, st, "attach: #{info.inspect}")
  item = info[:record]['attachments'].first
  NxTest.assert_equal('sheet', item['kind'])
  NxTest.assert_equal('Technický list — drez.pdf', item['name'], 'povodny nazov ostava v zazname')
  NxTest.assert(item['file'].match?(/\A[0-9a-f-]{36}_technicky_list_drez\.pdf\z/),
                "nazov suboru je <uuid>_<sanitized>.<ext>, dostal #{item['file']}")
  NxTest.assert_equal(5, item['bytes'])
  target = File.join(APPLC.record_dir(rec['id']), item['file'])
  NxTest.assert(File.file?(target), 'subor lezi v prieconku zaznamu')
  NxTest.assert_equal('PDF-1', File.binread(target))
  NxTest.assert(File.expand_path(target).start_with?(File.expand_path(APPLC.attachments_root)),
                'prilohy ziju MIMO stromu pluginu, v %APPDATA%\\NOXUN\\Engine\\appliances')
  NxTest.assert(Dir.glob(File.join(APPLC.record_dir(rec['id']), '*.tmp')).empty?, 'staging po sebe upratal')
end

NxTest.test('spotrebice: attach — pripona mimo whitelistu, chybajuci zdroj a rev guard') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  exe = applc_tmp_file('virus.exe')
  NxTest.assert_equal(:invalid, APPLC.attach!(rec['id'], exe, kind: 'sheet', rev: rec['rev'])[0])
  NxTest.assert_equal(:invalid, APPLC.attach!(rec['id'], applc_tmp_file('a.pdf'), kind: 'video',
                                              rev: rec['rev'])[0], 'neznamy druh prilohy')
  NxTest.assert_equal(:copy_failed, APPLC.attach!(rec['id'], File.join(APPLC_ROOT, 'niet.pdf'),
                                                  kind: 'sheet', rev: rec['rev'])[0])
  NxTest.assert_equal(:conflict, APPLC.attach!(rec['id'], applc_tmp_file('b.pdf'), kind: 'sheet',
                                               rev: 'stara')[0], 'attach ma rev guard ako patch (A1)')
end

NxTest.test('spotrebice: attach — limit 25 MB sa meria NA ULOZENEJ KOPII (zdroj sa mohol zvacsit)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  src = applc_tmp_file('velky.pdf')
  limit = APPLC::MAX_ATTACHMENT_BYTES

  applc_with_size_stub(->(p, orig) { p == src ? limit + 1 : orig.call(p) }) do
    NxTest.assert_equal(:too_large, APPLC.attach!(rec['id'], src, kind: 'sheet', rev: rec['rev'])[0],
                        'limit + 1 sa odmietne uz na zdroji')
  end
  # Zdroj presne na limite prejde…
  applc_with_size_stub(->(p, orig) { p == src ? limit : orig.call(p) }) do
    st, info = APPLC.attach!(rec['id'], src, kind: 'sheet', rev: rec['rev'])
    NxTest.assert_equal(:ok, st, 'hranica presne na limite je OK')
    rec = info[:record]
  end
  # …a zdroj, ktory sa medzi kontrolou a kopiou zvacsil, chyti kontrola STAGINGU.
  src2 = applc_tmp_file('rastuci.pdf')
  applc_with_size_stub(->(p, orig) { p.end_with?('.tmp') ? limit + 1 : orig.call(p) }) do
    NxTest.assert_equal(:too_large, APPLC.attach!(rec['id'], src2, kind: 'sheet', rev: rec['rev'])[0])
  end
  NxTest.assert(Dir.glob(File.join(APPLC.record_dir(rec['id']), '*.tmp')).empty?,
                'staging sa po odmietnuti zmazal')
  NxTest.assert_equal(1, APPLC.find(rec['id'])[1][:record]['attachments'].length,
                      'odmietnuta priloha sa do zaznamu nedostala')
end

NxTest.test('spotrebice: neocakavana chyba v mutacii je :write_failed, nie falosne :locked') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  orig = APPLC.method(:record_rev)
  APPLC.define_singleton_method(:record_rev) { |_r| raise NoMethodError, 'test: bug v mutacii' }
  begin
    st, info = APPLC.patch!(rec['id'], { 'note' => 'x' }, rev: rec['rev'])
    NxTest.assert_equal(:write_failed, st, 'bug sa nesmie tvarit ako obsadeny zamok')
    NxTest.assert(info[:message].to_s.length.positive?)
  ensure
    APPLC.define_singleton_method(:record_rev, orig)
  end
end

NxTest.test('spotrebice: attach — zlyhany zapis JSON nenecha sirotu ani „uspech" (A5)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  before = File.binread(APPLC.path)
  src = applc_tmp_file('list.pdf')
  st, = applc_with_failing_write { APPLC.attach!(rec['id'], src, kind: 'sheet', rev: rec['rev']) }
  NxTest.assert_equal(:write_failed, st)
  NxTest.assert_equal(before, File.binread(APPLC.path), 'predosly JSON ostal nedotknuty')
  NxTest.assert(Dir.glob(File.join(APPLC.record_dir(rec['id']), '*')).empty?,
                'sirota po zlyhanom zapise sa zmazala')
end

NxTest.test('spotrebice: nazov prilohy sa NIKDY nerecykluje — po remove ostava subor aj jeho meno (A2)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  src = applc_tmp_file('list.pdf', 'PRVY')
  rec = APPLC.attach!(rec['id'], src, kind: 'sheet', rev: rec['rev'])[1][:record]
  first = rec['attachments'].first
  first_path = File.join(APPLC.record_dir(rec['id']), first['file'])

  snap = APPLC.snapshot_for(rec['id'])[1][:snapshot]
  NxTest.assert_equal(first['file'], snap['attachments'].first['file'], 'snapshot nesie referenciu prilohy')

  rec = APPLC.remove_attachment!(rec['id'], first['id'], rev: rec['rev'])[1][:record]
  NxTest.refute(rec.key?('attachments'), 'zo zaznamu priloha zmizla')
  NxTest.assert(File.file?(first_path), 'SUBOR ostava — zakazkovy snapshot nan moze odkazovat')

  src2 = applc_tmp_file('list.pdf', 'DRUHY')
  rec = APPLC.attach!(rec['id'], src2, kind: 'sheet', rev: rec['rev'])[1][:record]
  second = rec['attachments'].first
  NxTest.refute(second['file'] == first['file'], 'novy subor ma INY nazov (uuid sa nerecykluje)')
  NxTest.assert_equal('PRVY', File.binread(first_path), 'stary subor ostal bajtovo nezmeneny')
  NxTest.assert_equal(:ok, APPLC.attachment_path_for(snap['attachments'].first)[0],
                      'stara referencia zo snapshotu sa stale otvori')
end

NxTest.test('spotrebice: nahlad je najviac JEDEN a set_thumbnail prepina image <-> thumbnail') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  rec = APPLC.attach!(rec['id'], applc_tmp_file('foto1.jpg'), kind: 'thumbnail', rev: rec['rev'])[1][:record]
  st, = APPLC.attach!(rec['id'], applc_tmp_file('foto2.jpg'), kind: 'thumbnail', rev: rec['rev'])
  NxTest.assert_equal(:invalid, st, 'druhy nahlad sa neprida')
  rec = APPLC.attach!(rec['id'], applc_tmp_file('foto2.jpg'), kind: 'image', rev: rec['rev'])[1][:record]
  second = rec['attachments'].last

  st2, info2 = APPLC.set_thumbnail!(rec['id'], second['id'], rev: rec['rev'])
  NxTest.assert_equal(:ok, st2)
  kinds = info2[:record]['attachments'].map { |a| a['kind'] }
  NxTest.assert_equal(1, kinds.count('thumbnail'), 'nahlad ostava presne jeden')
  NxTest.assert_equal('thumbnail', info2[:record]['attachments'].last['kind'])
  NxTest.assert_equal('image', info2[:record]['attachments'].first['kind'], 'povodny nahlad sa vratil na obrazok')

  rec = info2[:record]
  sheet = APPLC.attach!(rec['id'], applc_tmp_file('list.pdf'), kind: 'sheet', rev: rec['rev'])[1][:record]
  st3, = APPLC.set_thumbnail!(sheet['id'], sheet['attachments'].last['id'], rev: sheet['rev'])
  NxTest.assert_equal(:invalid, st3, 'PDF sa nahladom nestane')
  NxTest.assert_equal(:conflict, APPLC.set_thumbnail!(sheet['id'], second['id'], rev: 'stara')[0])
  NxTest.assert_equal(:conflict, APPLC.remove_attachment!(sheet['id'], second['id'], rev: 'stara')[0])

  # Odobratie JEDNEJ z viacerych priloh necha ostatne (aj nahlad) na pokoji.
  st4, info4 = APPLC.remove_attachment!(sheet['id'], sheet['attachments'].last['id'], rev: sheet['rev'])
  NxTest.assert_equal(:ok, st4)
  NxTest.assert_equal(2, info4[:record]['attachments'].length, 'ostatne prilohy ostavaju')
  NxTest.assert_equal('thumbnail', info4[:record]['attachments'].last['kind'], 'nahlad sa odobratim listu nestrati')
end

NxTest.test('spotrebice: resolver prilohy — containment, chybajuci subor a file:/// URL') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  rec = APPLC.attach!(rec['id'], applc_tmp_file('list.pdf'), kind: 'sheet', rev: rec['rev'])[1][:record]
  ref = { 'id' => rec['id'], 'file' => rec['attachments'].first['file'] }

  st, info = APPLC.attachment_path_for(ref)
  NxTest.assert_equal(:ok, st)
  NxTest.assert(File.file?(info[:path]))
  NxTest.assert_equal(:invalid, APPLC.attachment_path_for('id' => rec['id'], 'file' => '../../tajne.pdf')[0])
  NxTest.assert_equal(:invalid, APPLC.attachment_path_for('id' => '..', 'file' => 'a.pdf')[0])
  NxTest.assert_equal(:invalid, APPLC.attachment_path_for('id' => rec['id'], 'file' => 'a.exe')[0])
  NxTest.assert_equal(:missing_file,
                      APPLC.attachment_path_for('id' => rec['id'], 'file' => "#{'0' * 36}_x.pdf")[0],
                      'chybajuci subor sa prizna, nie ticho')
  NxTest.assert_equal(:not_found, APPLC.attachment_path(rec['id'], 'neexistuje')[0])

  url = APPLC.file_url('C:\\Users\\PC\\NOXUN\\Technický list.pdf')
  NxTest.assert(url.start_with?('file:///C:/'), "URL zacina file:///, dostal #{url}")
  NxTest.assert(url.include?('%20'), 'medzera je zakodovana')
  NxTest.refute(url.include?('ý'), 'diakritika je zakodovana')
  NxTest.refute(url.include?('\\'), 'v URL su LEN dopredne lomky')
end

NxTest.test('spotrebice: zamok drzany INYM procesom mutaciu zdrzi (nikdy nezapise popri nom)') do
  NxTest.skip!('detsky proces sa spusta len headless (v SketchUpe nie je samostatny ruby)') unless NxTest.headless?
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  lock = APPLC.lock_path
  ready = File.join(APPLC_ROOT, 'lock_ready')
  FileUtils.rm_f(ready)
  script = <<~RUBY
    File.open(ARGV[0], File::RDWR | File::CREAT) do |f|
      f.flock(File::LOCK_EX)
      File.binwrite(ARGV[1], 'ready')
      sleep 1.5
      f.flock(File::LOCK_UN)
    end
  RUBY
  pid = Process.spawn(RbConfig.ruby, '-e', script, lock, ready)
  begin
    waited = 0.0
    while !File.exist?(ready) && waited < 5.0
      sleep 0.05
      waited += 0.05
    end
    NxTest.assert(File.exist?(ready), 'detsky proces zamok nezobral — test by nic nemeral')
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    st, = APPLC.attach!(rec['id'], applc_tmp_file('pod_zamkom.pdf'), kind: 'sheet', rev: rec['rev'])
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    NxTest.assert(%i[ok locked].include?(st), "attach skoncil #{st}")
    NxTest.assert(elapsed > 0.5,
                  "attach na zamok NECAKAL (#{elapsed.round(2)} s) — dvojica zaznam+subor sa medzi " \
                  'dvoma instanciami SketchUpu rozide')
  ensure
    begin
      Process.wait(pid)
    rescue StandardError
      nil
    end
  end
end

# --- snapshot pre zakazku ------------------------------------------------------

NxTest.test('spotrebice: snapshot_for — uzavrety whitelist, catalog_std a NEZAVISLOST od neskorsej zmeny') do
  applc_seeded!
  rec = APPLC.create!(applc_new('note' => 'povodna poznamka', 'derived' => ['front.outer_width'],
                                'shop_urls' => ['https://drezyonline.sk/p47410'],
                                'dims' => { 'front' => { 'outer_width' => 860, 'cutout_width' => 840 } }))[1][:record]
  st, info = APPLC.snapshot_for(rec['id'])
  NxTest.assert_equal(:ok, st)
  snap = info[:snapshot]
  NxTest.assert_equal(rec['id'], snap['catalog_id'])
  NxTest.assert_equal(APPLC::STD, snap['catalog_std'])
  NxTest.refute(snap['snapshot_at'].to_s.empty?)
  %w[rev updated_at created_at deleted_at id].each do |key|
    NxTest.refute(snap.key?(key), "snapshot nenesie stav katalogu (#{key})")
  end

  APPLC.patch!(rec['id'], { 'note' => 'zmenena', 'derived' => [],
                            'dims' => { 'front' => { 'outer_width' => 900 } } }, rev: rec['rev'])
  NxTest.assert_equal('povodna poznamka', snap['note'], 'snapshot sa neskorsou zmenou nemeni')
  NxTest.assert_equal(['front.outer_width'], snap['derived'])
  NxTest.assert_close(860.0, snap['dims']['front']['outer_width'], 0.01)
  NxTest.assert_equal(['https://drezyonline.sk/p47410'], snap['shop_urls'])
end

NxTest.test('spotrebice: snapshot_for — vyradeny zaznam, neznamy id a nepodporovany zdroj') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  NxTest.assert_equal(:not_found, APPLC.snapshot_for('neexistuje')[0])
  del = APPLC.delete!(rec['id'], rev: rec['rev'])[1][:record]
  st, info = APPLC.snapshot_for(rec['id'])
  NxTest.assert_equal(:deleted, st, 'vyradeny model sa uz nepriraduje')
  NxTest.assert(info[:message].to_s.length.positive?)
  NxTest.assert_equal(:ok, APPLC.restore!(rec['id'], rev: del['rev'])[0])

  applc_install!('std' => 99, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'oven', 'name' => 'Z novsej verzie' }])
  st2, info2 = APPLC.snapshot_for('a1')
  NxTest.assert_equal(:unsupported, st2, 'z novsieho suboru sa snapshot nerobi')
  NxTest.assert(info2[:message].to_s.include?('aktualizuj plugin'))

  # Zdroj sa overuje CERSTVO: subor prepisala novsia instancia AZ PO tom, co
  # sedenie uz katalog precitalo ako zdravy.
  applc_seeded!
  rec = APPLC.list[1][:records].first
  NxTest.assert_equal(:ok, APPLC.snapshot_for(rec['id'])[0])
  doc = applc_doc
  doc['std'] = 99
  File.binwrite(APPLC.path, JSON.pretty_generate(doc))
  APPLC_JFS.invalidate(APPLC.path)
  NxTest.assert_equal(:unsupported, APPLC.snapshot_for(rec['id'])[0],
                      'cachovane :ok nie je dokaz — zakazka si snapshot ODLOZI')
end

NxTest.test('spotrebice: snapshot_for berie CERSTVY dokument, nikdy druhe cachovane citanie (#377 P1)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  stale = applc_doc # stav, ktory drzi sekundova cache JsonFileStore

  doc = applc_doc # na disku ho druha instancia SketchUpu prave VYRADILA
  doc['records'].find { |r| r['id'] == rec['id'] }['deleted_at'] = '2026-09-20T00:00:00Z'
  File.binwrite(APPLC.path, JSON.pretty_generate(doc))

  orig = APPLC_JFS.method(:read)
  APPLC_JFS.define_singleton_method(:read) { |*| stale }
  begin
    NxTest.assert_equal(:deleted, APPLC.snapshot_for(rec['id'])[0],
                        'snapshot ide z DISKU — cachovany zaznam by sa dostal do zakazky')
  ensure
    APPLC_JFS.define_singleton_method(:read, orig)
  end
end

NxTest.test('spotrebice: boot pluginu katalog ZALOZI (guard nad main.rb, #377 P2)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?('ApplianceCatalog.assess!'),
                'boot blok main.rb musi katalog zalozit — inak subor vznikne az pri prvom otvoreni sekcie')
  NxTest.assert(src.include?("log_error(e, 'appliance_catalog_boot')"),
                'zlyhanie katalogu nesmie zhodit menu, toolbar ani observer')
end

NxTest.test('spotrebice: ZLYHANY prvy seed = read_only, nie zdravy prazdny katalog (#377 P2)') do
  applc_wipe!
  st = applc_with_failing_write { APPLC.state }
  NxTest.assert_equal(:read_only, st, 'nezapisovatelny %APPDATA% nesmie vydat stav :ok')
  NxTest.assert(APPLC.state_reason.include?('nepodarilo založiť'), "dovod: #{APPLC.state_reason}")
  NxTest.assert_equal(:read_only, APPLC.create!(applc_new)[0], 'zapis nad nezalozenym katalogom sa odmietne')
  # Po naprave (zapis znova funguje) sa katalog zalozi pri najblizsom pristupe.
  APPLC.reset_state!
  NxTest.assert_equal(9, APPLC.list[1][:records].length)
end

NxTest.test('spotrebice: neznamy kluc `dims` OD KLIENTA sa odmietne, ulozeny prezije (#377 P2)') do
  applc_seeded!
  st, info = APPLC.create!(applc_new('dims' => { 'front' => { 'cutout_dept' => 480 } }))
  NxTest.assert_equal(:invalid, st, 'preklep sa nesmie ticho ulozit')
  NxTest.assert_equal('dims.front.cutout_dept', info[:field])
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('dims' => { 'bodyy' => { 'width' => 100 } }))[0],
                      'neznamy BLOK od klienta tiez nie')

  rec = APPLC.create!(applc_new)[1][:record]
  doc = applc_doc # zapis NOVSEJ verzie pluginu — ten neznamy kluc priniesol
  row = doc['records'].find { |r| r['id'] == rec['id'] }
  row['dims'] = { 'front' => { 'outer_width' => 860.0, 'future_key' => 'x' } }
  File.binwrite(APPLC.path, JSON.pretty_generate(doc))
  APPLC_JFS.invalidate(APPLC.path)
  fresh = APPLC.find(rec['id'])[1][:record]

  st2, info2 = APPLC.patch!(rec['id'], { 'dims' => { 'front' => { 'outer_depth' => 500 } } }, rev: fresh['rev'])
  NxTest.assert_equal(:ok, st2)
  NxTest.assert_equal('x', info2[:record]['dims']['front']['future_key'], 'ulozeny neznamy kluc prezije patch')
  st3, = APPLC.patch!(rec['id'], { 'dims' => { 'front' => { 'future_key' => 'z' } } },
                      rev: info2[:record]['rev'])
  NxTest.assert_equal(:ok, st3, 'kluc, ktory v zazname UZ JE, smie klient zmenit aj zmazat')
end

NxTest.test('spotrebice: nečitateľná polozka `attachments[]` = READ-ONLY, nie pad v mutacii (#377 P2)') do
  applc_install!('std' => 1, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'oven', 'name' => 'S prilohou',
                                 'attachments' => [nil] }])
  NxTest.assert_equal(:read_only, APPLC.state, '[null] v prilohach je poskodeny subor')
  NxTest.assert(APPLC.state_reason.include?('nečitateľný'), "dovod: #{APPLC.state_reason}")

  bad = [{ 'id' => 'x', 'kind' => 'sheet', 'file' => '../tajne.pdf', 'name' => 'x' }]
  applc_install!('std' => 1, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'oven', 'name' => 'X', 'attachments' => bad }])
  NxTest.assert_equal(:read_only, APPLC.state, 'nazov suboru mimo jedneho segmentu')

  bad2 = [{ 'id' => 'x', 'kind' => 'video', 'file' => 'a_b.pdf', 'name' => 'x' }]
  applc_install!('std' => 1, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'oven', 'name' => 'X', 'attachments' => bad2 }])
  NxTest.assert_equal(:read_only, APPLC.state, 'neznamy druh prilohy')
end

NxTest.test('spotrebice: PDF sa nestane nahladom ani obrazkom (matica druh -> pripona, #377 P2)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  pdf = applc_tmp_file('manual.pdf')
  st, info = APPLC.attach!(rec['id'], pdf, kind: 'thumbnail', rev: rec['rev'])
  NxTest.assert_equal(:invalid, st, 'PDF ako nahlad nie')
  NxTest.assert_equal('kind', info[:field], 'chyba patri k druhu, subor je v poriadku')
  NxTest.assert_equal(:invalid, APPLC.attach!(rec['id'], pdf, kind: 'image', rev: rec['rev'])[0],
                      'PDF ako obrazok tiez nie')
  rec = APPLC.attach!(rec['id'], pdf, kind: 'sheet', rev: rec['rev'])[1][:record]
  NxTest.assert_equal('sheet', rec['attachments'].first['kind'], 'ako LIST prejde')
  NxTest.assert_equal(:invalid, APPLC.set_thumbnail!(rec['id'], rec['attachments'].first['id'], rev: rec['rev'])[0],
                      'a nahladom sa uz nestane')
  ok_img = APPLC.attach!(rec['id'], applc_tmp_file('foto.webp'), kind: 'thumbnail', rev: rec['rev'])
  NxTest.assert_equal(:ok, ok_img[0], 'webp nahlad prejde')
end

NxTest.test('spotrebice: file_url — UNC cesta si NECHA hostitela (#377 P2)') do
  unc = APPLC.file_url('\\\\server\\share\\NOXUN\\Technický list.pdf')
  NxTest.assert(unc.start_with?('file://server/share/'), "UNC ma dva lomky a hostitela, dostal #{unc}")
  NxTest.refute(unc.start_with?('file:///'), 'z UNC sa nesmie stat lokalna cesta na disk')
  NxTest.assert(unc.include?('%20'), 'kodovanie ostava')
  local = APPLC.file_url('C:\\NOXUN\\list.pdf')
  NxTest.assert_equal('file:///C:/NOXUN/list.pdf', local, 'lokalna cesta ostava s tromi lomkami')
end

NxTest.test('spotrebice: degradovany stav — NEPLATNA zaloha sa nesnapshotuje ani necita (kolo 2 P1)') do
  # Platna zaloha: snapshot bezi dalej (citanie zo zalohy je v poriadku).
  # Snapshotuje sa SEED zaznam — `.bak` drzi stav PRED poslednym zapisom,
  # takze cerstvo zalozeny zaznam v nej este nie je.
  applc_seeded!
  seed_id = APPLC.list[1][:records].first['id']
  APPLC.create!(applc_new) # druhy zapis vyrobi `.bak` zo seedoveho dokumentu
  File.binwrite(APPLC.path, '{ toto nie je JSON')
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
  NxTest.assert_equal(:degraded, APPLC.state)
  st, info = APPLC.snapshot_for(seed_id)
  NxTest.assert_equal(:ok, st, 'platna zaloha snapshot dovoli')
  NxTest.assert_equal(seed_id, info[:snapshot]['catalog_id'])
  NxTest.assert_equal(APPLC::STD, info[:snapshot]['catalog_std'])

  # Zaloha z NOVSEJ verzie: parsuje sa, ale pouzit sa neda.
  doc = JSON.parse(File.binread("#{APPLC.path}.bak"))
  doc['std'] = 99
  File.binwrite("#{APPLC.path}.bak", JSON.pretty_generate(doc))
  APPLC_JFS.invalidate(APPLC.path)
  APPLC.reset_state!
  NxTest.assert_equal(:read_only, APPLC.state, 'zaloha z novsej verzie nie je „degradovany" stav')
  NxTest.assert(APPLC.state_reason.include?('aktualizuj plugin'), "dovod: #{APPLC.state_reason}")
  st2, info2 = APPLC.snapshot_for(seed_id)
  NxTest.assert_equal(:unsupported, st2, 'snapshot zo zalohy novsej verzie NEVZNIKNE')
  NxTest.assert(info2[:message].to_s.length.positive?)
end

NxTest.test('spotrebice: ULOZENE `dims` prechadzaju validaciou znamych poli (kolo 2 P2)') do
  applc_install!('std' => 1, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'oven', 'name' => 'Rucna uprava',
                                 'dims' => { 'body' => { 'width' => 'oops' } } }])
  NxTest.assert_equal(:read_only, APPLC.state, 'retazec v rozmere nie je zdravy katalog')
  NxTest.assert(APPLC.state_reason.include?('dims.body.width'), "dovod nesie cestu pola: #{APPLC.state_reason}")
  NxTest.assert_equal(:unsupported, APPLC.snapshot_for('a1')[0], 'a do zakazky sa taky zaznam nedostane')

  applc_install!('std' => 1, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'fridge', 'name' => 'Zla nika',
                                 'dims' => { 'niche' => { 'width_min' => 700, 'width_max' => 600 } } }])
  NxTest.assert_equal(:read_only, APPLC.state, 'min > max v ulozenom zazname')

  applc_install!('std' => 1, 'seed_version' => 1,
                 'records' => [{ 'id' => 'a1', 'category' => 'oven', 'name' => 'Z novsej verzie',
                                 'dims' => { 'body' => { 'width' => 548.0 },
                                             'future_block' => { 'x' => 'lubovolne' },
                                             'front' => { 'future_key' => 'ok' } } }])
  NxTest.assert_equal(:ok, APPLC.state, 'NEZNAME kluce ostavaju dopredne kompatibilne')
end

NxTest.test('spotrebice: patch `dims: null` ZMAZE rozmery, `dims.body: null` zmaze blok (kolo 2 P2)') do
  applc_seeded!
  rec = APPLC.create!(applc_new('dims' => { 'body' => { 'width' => 860 },
                                            'front' => { 'outer_width' => 860 } }))[1][:record]
  st, info = APPLC.patch!(rec['id'], { 'dims' => { 'body' => nil } }, rev: rec['rev'])
  NxTest.assert_equal(:ok, st)
  NxTest.refute(info[:record]['dims'].key?('body'), 'null nad blokom ho zmaze')
  NxTest.assert(info[:record]['dims'].key?('front'), 'ostatne bloky ostanu')

  st2, info2 = APPLC.patch!(rec['id'], { 'dims' => nil }, rev: info[:record]['rev'])
  NxTest.assert_equal(:ok, st2)
  NxTest.refute(info2[:record].key?('dims'), 'null nad celym `dims` zmaze rozmery (nie ticho ponecha)')
end

NxTest.test('spotrebice: subory medzitym ZMIZLI — mutacia pod zamkom katalog naseeduje (kolo 2 P2)') do
  applc_seeded!
  NxTest.assert_equal(9, APPLC.list[1][:records].length)
  [APPLC.path, "#{APPLC.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  APPLC_JFS.invalidate(APPLC.path)

  st, info = APPLC.create!(applc_new)
  NxTest.assert_equal(:ok, st, 'mutacia nad zmiznutym katalogom prejde')
  doc = applc_doc
  NxTest.assert_equal(10, doc['records'].length, 'seed 9 modelov + novy zaznam')
  NxTest.assert_equal(9, doc['records'].count { |r| r['seed'] == true }, 'devat seed modelov sa naozaj doselo')
  NxTest.assert_equal(1, doc['seed_version'])
  NxTest.assert(doc['records'].any? { |r| r['id'] == info[:record]['id'] })
end

NxTest.test('spotrebice: `derived` sa overuje proti SCHEME kategorie, nie len prvym segmentom (kolo 2 P2)') do
  applc_seeded!
  st, info = APPLC.create!(applc_new('derived' => ['body.wdith']))
  NxTest.assert_equal(:invalid, st, 'preklep v druhom segmente')
  NxTest.assert_equal('derived', info[:field])
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('derived' => ['front.overhang_top']))[0],
                      'pole inej kategorie (presah nie je pole drezu)')
  NxTest.assert_equal(:invalid, APPLC.create!(applc_new('derived' => ['body.width.extra']))[0],
                      'tretí segment mimo furniture_doors')
  NxTest.assert_equal(:ok, APPLC.create!(applc_new('derived' => %w[body.width front.cutout_width]))[0])
  st2, = APPLC.create!(applc_new('category' => 'fridge', 'name' => 'Chlad',
                                 'derived' => ['front.furniture_doors.lower_min']))
  NxTest.assert_equal(:ok, st2, 'vnorene pole nabytkovych dveri je platna cesta')
end

# --- hladanie a tvar odpovede --------------------------------------------------

NxTest.test('spotrebice: search — bez diakritiky, aj cez SK popisok kategorie, deterministicke poradie') do
  applc_seeded!
  names = APPLC.search('umyvacka')[1][:records].map { |r| r['name'] }
  NxTest.assert_equal(%w[SPV6EMX05E WIO\ 3O540\ PELG], names, 'popisok „Umývačka" najde obe umyvacky')
  NxTest.assert_equal(%w[BFL7221B1 HBG774KB1 SPV6EMX05E],
                      APPLC.search('bosch')[1][:records].map { |r| r['name'] }, 'poradie podla nazvu')
  NxTest.assert_equal(2, APPLC.search('', category: 'oven')[1][:records].length, 'filter kategorie')
  NxTest.assert_equal(1, APPLC.search('whirlpool mikro')[1][:records].length, 'kazdy token musi sediet')
  NxTest.assert_equal(0, APPLC.search('neexistujuci model')[1][:records].length)

  rec = APPLC.create!(applc_new('name' => 'Legra XL 6 S'))[1][:record]
  APPLC.delete!(rec['id'], rev: rec['rev'])
  NxTest.assert_equal(0, APPLC.search('legra')[1][:records].length, 'vyradene sa nehladaju')
  NxTest.assert_equal(1, APPLC.search('legra', include_deleted: true)[1][:records].length)
end

NxTest.test('spotrebice: KAZDA odpoved je dvojica [status, Hash] (jeden navratovy tvar, A11)') do
  applc_seeded!
  rec = APPLC.create!(applc_new)[1][:record]
  calls = [
    APPLC.list, APPLC.find(rec['id']), APPLC.find('neexistuje'), APPLC.search('x'),
    APPLC.create!(applc_new('category' => 'ine')),
    APPLC.patch!(rec['id'], { 'name' => 'X' }, rev: 'stara'),
    APPLC.delete!('neexistuje', rev: 'x'),
    APPLC.restore!('neexistuje', rev: 'x'),
    APPLC.attach!(rec['id'], 'nic.exe', kind: 'sheet', rev: rec['rev']),
    APPLC.set_thumbnail!(rec['id'], 'x', rev: rec['rev']),
    APPLC.remove_attachment!(rec['id'], 'x', rev: rec['rev']),
    APPLC.attachment_path(rec['id'], 'x'),
    APPLC.attachment_path_for({}),
    APPLC.snapshot_for('neexistuje'),
    APPLC.open_path(File.join(APPLC_ROOT, 'nic.pdf'))
  ]
  calls.each_with_index do |(status, info), i|
    NxTest.assert(status.is_a?(Symbol), "odpoved #{i} nema symbolovy status")
    NxTest.assert(info.is_a?(Hash), "odpoved #{i} (#{status}) nema Hash s detailom")
  end
  NxTest.assert_equal(:open_failed, calls.last[0], 'mimo SketchUpu sa otvorenie prizna, nespadne')
end

NxTest.test('spotrebice: ulozisko je per-PC vedla ostatnych katalogov (bez override)') do
  APPLC.test_dir_override = nil
  NxTest.assert_equal(Noxun::Engine::Materials.dir, APPLC.dir, 'zdielany %APPDATA%\\NOXUN\\Engine')
  NxTest.assert_equal(File.join(APPLC.dir, 'appliances.json'), APPLC.path)
  NxTest.assert_equal("#{APPLC.path}.lock", APPLC.lock_path, 'vlastny sidecar zamok, nie cudzi')
  NxTest.assert_equal(File.join(APPLC.dir, 'appliances'), APPLC.attachments_root)
ensure
  APPLC.test_dir_override = APPLC_ROOT
  APPLC.reset_state!
end
