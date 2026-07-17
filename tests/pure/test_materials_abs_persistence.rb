# frozen_string_literal: true
# Testy perzistencie: JsonFileStore (atomicky zapis, .bak fallback, cache),
# Materials (seed katalog, ABS hrubky 1/2 mm, normalized_abs_id), AbsRules
# (pravidlove defaulty hran podla roly, write-on-read normalizacia) a
# TemplateStore (seed sablon, find/upsert/delete, reload!).
#
# VSETKY testy bezia len headless — helper presmeroval %APPDATA% do sandboxu,
# takze mazanie/prepis katalogovych suborov NIKDY nesiahne na realne data.
# .bak subory sa generuju runtime (gitignore *.bak — fixture by sa nedostala do repa).
require_relative '../helper' unless defined?(NxTest)

# Reset katalogoveho suboru v APPDATA sandboxe — kazdy test si zacina cisty stav
# (sandbox je zdielany celym behom, preto sa nespolieha na poradie testov).
def nx_reset_catalog_file(path)
  FileUtils.rm_f(path)
  FileUtils.rm_f("#{path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(path)
end

# ============================ JsonFileStore ====================================

NxTest.test('json_file_store: write/read round-trip') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  store = Noxun::Engine::JsonFileStore
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'store.json')
    payload = { 'a' => 1, 'list' => [1, 2, 3], 'nested' => { 'k' => 'v' } }
    NxTest.assert_equal(true, store.write(path, payload))
    NxTest.assert(File.exist?(path), 'primarny subor po write neexistuje')
    NxTest.assert_equal(payload, store.read(path))
  end
end

NxTest.test('json_file_store: druhy zapis vytvori .bak s predoslou validnou verziou') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  store = Noxun::Engine::JsonFileStore
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'store.json')
    v1 = { 'verzia' => 1 }
    v2 = { 'verzia' => 2 }
    store.write(path, v1)
    # Prvy zapis nema co zalohovat — .bak vznika az pri prepise existujuceho suboru.
    NxTest.refute(File.exist?("#{path}.bak"), '.bak nema existovat po prvom zapise')
    store.write(path, v2)
    NxTest.assert(File.exist?("#{path}.bak"), '.bak ma existovat po druhom zapise')
    NxTest.assert_equal(v1, JSON.parse(File.binread("#{path}.bak")))
    NxTest.assert_equal(v2, JSON.parse(File.binread(path)))
  end
end

NxTest.test('json_file_store: poskodeny primarny subor -> read fallback na .bak') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  store = Noxun::Engine::JsonFileStore
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'store.json')
    v1 = { 'verzia' => 1 }
    store.write(path, v1)
    store.write(path, 'verzia' => 2) # .bak = v1
    File.binwrite(path, '{ toto nie je json')
    store.invalidate(path)
    NxTest.assert_equal(v1, store.read(path))
  end
end

NxTest.test('json_file_store: poskodeny primarny neprepise validny .bak pri dalsom zapise') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  store = Noxun::Engine::JsonFileStore
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'store.json')
    v1 = { 'verzia' => 1 }
    v3 = { 'verzia' => 3 }
    store.write(path, v1)
    store.write(path, 'verzia' => 2) # .bak = v1
    File.binwrite(path, '{ poskodene')
    store.invalidate(path)
    store.write(path, v3)
    # preserve_valid_backup nesmie skopcit poskodeny primarny subor do .bak.
    NxTest.assert_equal(v1, JSON.parse(File.binread("#{path}.bak")))
    NxTest.assert_equal(v3, store.read(path))
  end
end

NxTest.test('json_file_store: read copy:false vrati zmrazenu cache, copy:true mutovatelnu kopiu') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  store = Noxun::Engine::JsonFileStore
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'store.json')
    store.write(path, { 'a' => 1, 'list' => [1, 2, 3] })
    frozen1 = store.read(path, copy: false)
    NxTest.assert(frozen1.frozen?, 'copy:false ma vratit frozen hash')
    NxTest.assert(frozen1['list'].frozen?, 'deep_freeze ma zmrazit aj vnorene pole')
    frozen2 = store.read(path, copy: false)
    NxTest.assert(frozen1.equal?(frozen2), 'copy:false ma vratit ten isty cache objekt')
    copy = store.read(path)
    NxTest.refute(copy.frozen?, 'copy:true nema byt frozen')
    NxTest.refute(copy['list'].frozen?, 'kopia ma byt mutovatelna aj vnorene')
    copy['list'] << 99
    NxTest.assert_equal([1, 2, 3], store.read(path, copy: false)['list'])
  end
end

NxTest.test('json_file_store: invalidate/reload! vynutia nove citanie po rucnom zapise') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  store = Noxun::Engine::JsonFileStore
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'store.json')
    store.write(path, { 'k' => 'v1' })
    NxTest.assert_equal({ 'k' => 'v1' }, store.read(path))
    File.binwrite(path, JSON.generate({ 'k' => 'v2' }))
    NxTest.assert_equal(true, store.reload!(path))
    NxTest.assert_equal({ 'k' => 'v2' }, store.read(path))
    File.binwrite(path, JSON.generate({ 'k' => 'v3' }))
    NxTest.assert_equal(true, store.invalidate(path))
    NxTest.assert_equal({ 'k' => 'v3' }, store.read(path))
  end
end

NxTest.test('json_file_store: available? plati pre primarny subor aj samotny .bak') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  store = Noxun::Engine::JsonFileStore
  Dir.mktmpdir do |dir|
    path = File.join(dir, 'store.json')
    NxTest.refute(store.available?(path), 'neexistujuci store nema byt available')
    store.write(path, { 'verzia' => 1 })
    NxTest.assert(store.available?(path))
    store.write(path, 'verzia' => 2) # vytvori .bak
    File.delete(path)
    NxTest.assert(store.available?(path), 'samotny .bak ma stacit na available?')
    File.delete("#{path}.bak")
    NxTest.refute(store.available?(path))
  end
end

# ============================ Materials ========================================

NxTest.test('materials: prvy pristup seedne katalog v APPDATA sandboxe') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  nx_reset_catalog_file(mat.path)
  NxTest.refute(File.exist?(mat.path), 'reset mal zmazat materials.json')
  sheets = mat.sheets # prvy pristup -> ensure_seeded
  NxTest.assert(File.exist?(mat.path), 'prvy pristup mal vytvorit materials.json')
  NxTest.assert_equal(4, sheets.size)
  NxTest.assert_equal(3, mat.edges.size)
  # Obsah suboru kontrolujeme AZ PO prvom citani (write-on-read normalizacia).
  parsed = JSON.parse(File.binread(mat.path))
  NxTest.assert_equal(1, parsed['std'])
  NxTest.assert_equal(%w[HDF_WHITE_3 K009_PW_DTDL_16 K009_PW_DTDL_18 W1000_DTDL_18],
                      parsed['sheets'].map { |s| s['material_id'] }.sort)
  NxTest.assert_equal(%w[ABS_K009_10 ABS_K009_20 ABS_W1000_10],
                      parsed['edges'].map { |a| a['abs_id'] }.sort)
end

NxTest.test('materials: sheet/edge lookup, decor_of a color_of') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  nx_reset_catalog_file(mat.path)
  s = mat.sheet('K009_PW_DTDL_18')
  NxTest.assert(s, 'seed sheet K009_PW_DTDL_18 sa nenasiel')
  NxTest.assert_close(18.0, s['thickness'])
  NxTest.assert_equal('K009 PW', s['decor'])
  e = mat.edge('ABS_K009_20')
  NxTest.assert(e, 'seed edge ABS_K009_20 sa nenasiel')
  NxTest.assert_close(2.0, e['thickness'])
  NxTest.assert_equal(nil, mat.sheet(nil))
  NxTest.assert_equal(nil, mat.sheet('NEEXISTUJE'))
  NxTest.assert_equal(nil, mat.edge(nil))
  NxTest.assert_equal(nil, mat.edge('NEEXISTUJE'))
  NxTest.assert_equal('W1000 ST9 Biela', mat.decor_of('W1000_DTDL_18'))
  NxTest.assert_equal(nil, mat.decor_of('NEEXISTUJE'))
  NxTest.assert_equal([238, 236, 230], mat.color_of('HDF_WHITE_3'))
  NxTest.assert_equal(nil, mat.color_of('NEEXISTUJE'))
end

NxTest.test('materials: supported_edge_thickness? presne 1.0 a 2.0 bez tolerancie') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  NxTest.assert(mat.supported_edge_thickness?(1.0))
  NxTest.assert(mat.supported_edge_thickness?(2.0))
  NxTest.assert(mat.supported_edge_thickness?(1), 'Integer 1 sa cez to_f ma uznat')
  NxTest.assert(mat.supported_edge_thickness?('2'), 'String "2" sa cez to_f ma uznat')
  NxTest.refute(mat.supported_edge_thickness?(0.4), 'legacy 0.4 uz nie je podporovana')
  NxTest.refute(mat.supported_edge_thickness?(0.8), 'legacy 0.8 uz nie je podporovana')
  NxTest.refute(mat.supported_edge_thickness?(1.5))
  NxTest.refute(mat.supported_edge_thickness?(3.0))
  NxTest.refute(mat.supported_edge_thickness?(1.001), 'v0.3.3 BEZ tolerancie — presna zhoda')
  NxTest.refute(mat.supported_edge_thickness?(0.999), 'v0.3.3 BEZ tolerancie — presna zhoda')
  NxTest.refute(mat.supported_edge_thickness?(nil), 'nil.to_f = 0.0 -> nepodporovana')
end

NxTest.test('materials: normalized_abs_id pusti len id existujuce v katalogu') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  nx_reset_catalog_file(mat.path)
  NxTest.assert_equal('ABS_K009_10', mat.normalized_abs_id('ABS_K009_10'))
  NxTest.assert_equal('ABS_W1000_10', mat.normalized_abs_id('  ABS_W1000_10  '), 'id sa ma strip-nut')
  # v0.3.3 (PR #12): ZIADNA migracia legacy id podla dekoru — nezname/legacy -> nil.
  NxTest.assert_equal(nil, mat.normalized_abs_id('ABS_K009_04'))
  NxTest.assert_equal(nil, mat.normalized_abs_id('ABS_K009_08'))
  NxTest.assert_equal(nil, mat.normalized_abs_id('ABS_NEZNAME'))
  NxTest.assert_equal(nil, mat.normalized_abs_id(''))
  NxTest.assert_equal(nil, mat.normalized_abs_id('   '))
  NxTest.assert_equal(nil, mat.normalized_abs_id(nil))
end

NxTest.test('materials: abs_for_decor toleruje hrubku len do 0.01 mm') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  nx_reset_catalog_file(mat.path)
  NxTest.assert_equal('ABS_K009_10', mat.abs_for_decor('K009 PW', 1.0))
  NxTest.assert_equal('ABS_K009_20', mat.abs_for_decor('K009 PW', 2.0))
  # Tolerancia v kode je STRIKTNE < 0.01 mm.
  NxTest.assert_equal('ABS_K009_10', mat.abs_for_decor('K009 PW', 1.005))
  NxTest.assert_equal(nil, mat.abs_for_decor('K009 PW', 1.02))
  NxTest.assert_equal(nil, mat.abs_for_decor('K009 PW', 0.4), 'legacy hrubka nema variant')
  NxTest.assert_equal(nil, mat.abs_for_decor('W1000 ST9 Biela', 2.0), 'W1000 ma len 1.0 mm')
  NxTest.assert_equal(nil, mat.abs_for_decor('NeznamyDekor', 1.0))
  NxTest.assert_equal(nil, mat.abs_for_decor(nil, 1.0))
end

NxTest.test('materials: catalog pri citani odfiltruje nepodporovane ABS a prepise subor') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  store = Noxun::Engine::JsonFileStore
  nx_reset_catalog_file(mat.path)
  legacy = { 'abs_id' => 'ABS_K009_08', 'decor' => 'K009 PW', 'thickness' => 0.8,
             'price_per_bm' => 0.4, 'color' => [198, 168, 122] }
  store.write(mat.path, { 'std' => 1, 'sheets' => mat.seed_sheets,
                          'edges' => mat.seed_edges + [legacy] })
  cat = mat.catalog # write-on-read: legacy edge sa odfiltruje a subor sa prepise
  NxTest.assert_equal(3, cat['edges'].size)
  NxTest.refute(cat['edges'].any? { |a| a['abs_id'] == 'ABS_K009_08' })
  NxTest.assert_equal(4, cat['sheets'].size, 'sheets musia prezit filtrovanie edges')
  parsed = JSON.parse(File.binread(mat.path))
  NxTest.assert_equal(3, parsed['edges'].size, 'subor sa mal prepisat bez legacy ABS')
  NxTest.refute(parsed['edges'].any? { |a| a['abs_id'] == 'ABS_K009_08' })
  NxTest.assert_equal(nil, mat.normalized_abs_id('ABS_K009_08'))
end

# ============================ AbsRules =========================================

NxTest.test('abs_rules: seed pravidla — cela dookola, ostatne predna, chrbat nic') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  rules = Noxun::Engine::AbsRules
  nx_reset_catalog_file(rules.path)
  # Cela (front_door/drawer_front): vsetky 4 hrany 1.0 mm.
  %w[front_door drawer_front].each do |role|
    th = rules.thicknesses_for(role)
    NxTest.assert_equal(%w[L1 L2 W1 W2], th.keys.sort, "rola #{role}")
    th.each_value { |v| NxTest.assert_close(1.0, v) }
  end
  # Lezace/zvisle dielce: len predna hrana (L1) 1.0 mm.
  %w[shelf side_left side_right bottom top divider_v divider_h].each do |role|
    th = rules.thicknesses_for(role)
    NxTest.assert_equal(%w[L1], th.keys, "rola #{role} ma mat len L1")
    NxTest.assert_close(1.0, th['L1'])
  end
  # Chrbat, sokel a vystuhy: ziadne ABS.
  %w[back plinth rail_front rail_back].each do |role|
    NxTest.assert_equal({}, rules.thicknesses_for(role), "rola #{role} nema mat ABS")
  end
  # Neznama rola -> prazdna mapa, ziadna vynimka.
  NxTest.assert_equal({}, rules.thicknesses_for('neznama_rola'))
  parsed = JSON.parse(File.binread(rules.path))
  NxTest.assert_equal(1, parsed['std'])
end

NxTest.test('abs_rules: nepodporovane hrubky a nezname hrany sa pri citani normalizuju') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  rules = Noxun::Engine::AbsRules
  nx_reset_catalog_file(rules.path)
  rules.write({ 'shelf' => { 'L1' => 0.8, 'L2' => 2.0, 'X9' => 1.0 },
                'back'  => { 'W1' => 3.0 } })
  loaded = rules.rules # write-on-read: normalizacia + prepis suboru
  NxTest.assert_equal(%w[L2], loaded['shelf'].keys, 'legacy 0.8 a neznamy kod X9 mali vypadnut')
  NxTest.assert_close(2.0, loaded['shelf']['L2'])
  NxTest.assert_equal({}, loaded['back'], 'hrubka 3.0 mala vypadnut')
  parsed = JSON.parse(File.binread(rules.path))
  NxTest.assert_equal(%w[L2], parsed['rules']['shelf'].keys)
  NxTest.assert_close(2.0, parsed['rules']['shelf']['L2'])
  NxTest.assert_equal({}, parsed['rules']['back'])
  th = rules.thicknesses_for('shelf')
  NxTest.assert_equal(%w[L2], th.keys)
  NxTest.assert_close(2.0, th['L2'])
end

NxTest.test('abs_rules: resolve_edges spoji pravidla s ABS katalogom podla dekoru') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  rules = Noxun::Engine::AbsRules
  mat = Noxun::Engine::Materials
  nx_reset_catalog_file(rules.path)
  nx_reset_catalog_file(mat.path)
  # Polica: pravidlo len L1 (predna) -> ABS dekoru K009 PW hrubky 1.0.
  NxTest.assert_equal({ 'L1' => 'ABS_K009_10', 'L2' => nil, 'W1' => nil, 'W2' => nil },
                      rules.resolve_edges('shelf', 'K009 PW'))
  # Celo: vsetky 4 hrany rovnaky ABS variant.
  NxTest.assert_equal({ 'L1' => 'ABS_W1000_10', 'L2' => 'ABS_W1000_10',
                        'W1' => 'ABS_W1000_10', 'W2' => 'ABS_W1000_10' },
                      rules.resolve_edges('front_door', 'W1000 ST9 Biela'))
  # Dekor bez ABS variantu -> hrany bez ABS (nil), ziadna vynimka.
  NxTest.assert_equal(rules.empty_edges, rules.resolve_edges('front_door', 'Biela HDF'))
  # Chrbat nema pravidlo -> kompletna nil mapa.
  NxTest.assert_equal({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
                      rules.resolve_edges('back', 'K009 PW'))
  NxTest.assert_equal({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }, rules.empty_edges)
end

# ============================ TemplateStore ====================================

NxTest.test('templates: prvy load seedne 4 predvolene sablony') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  tpl = Noxun::Engine::TemplateStore
  nx_reset_catalog_file(tpl.path)
  list = tpl.load
  NxTest.assert_equal(4, list.size)
  NxTest.assert_equal(['Dolna klasik', 'Drezova', 'Varna doska', 'Horna klasik'],
                      list.map { |t| t['name'] })
  dolna = list[0]['config']
  NxTest.assert_equal('lower', dolna['type'])
  NxTest.assert_equal('two_rails', dolna['top_mode'])
  NxTest.assert_equal('flat', dolna['rails_orientation'])
  NxTest.assert_close(600.0, dolna['width'])
  NxTest.assert_close(720.0, dolna['height'])
  NxTest.assert_equal('upright', list[1]['config']['rails_orientation'], 'Drezova ma listy nastojato')
  NxTest.assert_close(20.0, list[2]['config']['rails_top_offset'], 0.01, 'Varna doska ma odsadene vystuhy')
  horna = list[3]['config']
  NxTest.assert_equal('upper', horna['type'])
  NxTest.assert_equal('groove', horna['back_mode'])
  NxTest.assert_close(320.0, horna['depth'])
  parsed = JSON.parse(File.binread(tpl.path))
  NxTest.assert_equal(1, parsed['std'])
  NxTest.assert_equal(4, parsed['templates'].size)
end

NxTest.test('templates: find/upsert/delete round-trip') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  tpl = Noxun::Engine::TemplateStore
  nx_reset_catalog_file(tpl.path)
  NxTest.assert_equal(true, tpl.upsert('Testovacia', { 'type' => 'lower', 'width' => 450.0 }))
  found = tpl.find('Testovacia')
  NxTest.assert(found, 'upsertnuta sablona sa nenasla')
  NxTest.assert_equal('Testovacia', found['name'])
  NxTest.assert_equal('lower', found['config']['type'])
  NxTest.assert_close(450.0, found['config']['width'])
  NxTest.assert_equal(5, tpl.load.size, '4 seed + 1 nova')
  NxTest.assert_equal(true, tpl.delete('Testovacia'))
  NxTest.assert_equal(nil, tpl.find('Testovacia'))
  NxTest.assert_equal(4, tpl.load.size)
end

NxTest.test('templates: upsert prepise existujucu sablonu podla mena') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  tpl = Noxun::Engine::TemplateStore
  nx_reset_catalog_file(tpl.path)
  tpl.upsert('Duplikat', { 'width' => 400.0 })
  tpl.upsert('Duplikat', { 'width' => 500.0 })
  matching = tpl.load.select { |t| t['name'] == 'Duplikat' }
  NxTest.assert_equal(1, matching.size, 'upsert nesmie duplikovat meno')
  NxTest.assert_close(500.0, matching[0]['config']['width'])
end

NxTest.test('templates: reload! nacita subor po rucnom zapise mimo store') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  tpl = Noxun::Engine::TemplateStore
  nx_reset_catalog_file(tpl.path)
  tpl.load # seed + naplni cache
  File.binwrite(tpl.path, JSON.generate(
                            { 'std' => 1,
                              'templates' => [{ 'name' => 'Rucna', 'config' => { 'type' => 'upper' } }] }
                          ))
  list = tpl.reload!
  NxTest.assert_equal(1, list.size)
  NxTest.assert_equal('Rucna', list[0]['name'])
  NxTest.assert_equal('upper', list[0]['config']['type'])
  NxTest.assert_equal(1, tpl.load.size, 'aj dalsi load ma vidiet rucny zapis')
end
