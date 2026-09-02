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

# V0.6 M-B1: seed je UNI sada — testy klasickej mechaniky lookup/filter/picker
# si instaluju EXPLICITNY stary SCHEMA 2 katalog (presne byvale seed zaznamy).
def mabs_classic!
  mat = Noxun::Engine::Materials
  nx_reset_catalog_file(mat.path)
  gid_k = mat.group_id_for('Kronospan', 'K009')
  gid_w = mat.group_id_for('Egger', 'W1000')
  data = {
    'sheets' => [
      mat.normalize_sheet('material_id' => 'K009_PW_DTDL_18', 'manufacturer' => 'Kronospan',
                          'decor' => 'K009', 'structure' => 'PW', 'group_id' => gid_k,
                          'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length',
                          'price_per_m2' => 12.5, 'sheet_size' => [2800.0, 2070.0],
                          'color' => [198, 168, 122]),
      mat.normalize_sheet('material_id' => 'K009_PW_DTDL_16', 'manufacturer' => 'Kronospan',
                          'decor' => 'K009', 'structure' => 'PW', 'group_id' => gid_k,
                          'type' => 'DTDL', 'thickness' => 16.0, 'sheet_size' => [2800.0, 2070.0]),
      mat.normalize_sheet('material_id' => 'HDF_WHITE_3', 'manufacturer' => 'Kronospan',
                          'decor' => 'Biela HDF', 'group_id' => mat.group_id_for('Kronospan', 'Biela HDF'),
                          'type' => 'HDF', 'thickness' => 3.0, 'grain' => 'none',
                          'color' => [238, 236, 230]),
      mat.normalize_sheet('material_id' => 'W1000_DTDL_18', 'manufacturer' => 'Egger',
                          'decor' => 'W1000', 'decor_name' => 'Biela', 'structure' => 'ST9',
                          'group_id' => gid_w, 'type' => 'DTDL', 'thickness' => 18.0,
                          'color' => [246, 246, 244])
    ],
    'edges' => [
      mat.normalize_edge('abs_id' => 'ABS_K009_10', 'decor' => 'K009', 'structure' => 'PW',
                         'group_id' => gid_k, 'thickness' => 1.0, 'price_per_bm' => 0.55),
      mat.normalize_edge('abs_id' => 'ABS_K009_20', 'decor' => 'K009', 'structure' => 'PW',
                         'group_id' => gid_k, 'thickness' => 2.0, 'price_per_bm' => 0.85),
      mat.normalize_edge('abs_id' => 'ABS_W1000_10', 'decor' => 'W1000', 'structure' => 'ST9',
                         'group_id' => gid_w, 'thickness' => 1.0, 'price_per_bm' => 0.6)
    ]
  }
  # Explicitny marker 2 — write bez neho by na cistom subore zapisal 1 a
  # vznikol by hybrid (group_id data pod legacy markerom).
  raise 'mabs classic write failed' unless mat.write(data.merge('schema' => 2))
  mat
end

NxTest.test('materials: prvy pristup seedne katalog v APPDATA sandboxe (M-B1: UNI sada)') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  nx_reset_catalog_file(mat.path)
  NxTest.refute(File.exist?(mat.path), 'reset mal zmazat materials.json')
  sheets = mat.sheets # prvy pristup -> ensure_seeded
  NxTest.assert(File.exist?(mat.path), 'prvy pristup mal vytvorit materials.json')
  NxTest.assert_equal(5, sheets.size)
  NxTest.assert_equal(0, mat.edges.size, 'UNI sada je bez pasok')
  parsed = JSON.parse(File.binread(mat.path))
  NxTest.assert_equal(1, parsed['std'])
  NxTest.assert_equal(%w[HDF_WHITE_3 K009_PW_DTDL_18 UNI_DEKOR2_18 UNI_DOSKA_18 W1000_DTDL_18],
                      parsed['sheets'].map { |s| s['material_id'] }.sort)
  NxTest.assert(parsed['sheets'].all? { |s| s['uni'] == true })
end

NxTest.test('materials: sheet/edge lookup, decor_of a color_of') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  mabs_classic!
  s = mat.sheet('K009_PW_DTDL_18')
  NxTest.assert(s, 'seed sheet K009_PW_DTDL_18 sa nenasiel')
  NxTest.assert_close(18.0, s['thickness'])
  # 2A-4b: seedy su nativne SCHEMA 2 — dekor = CISLO, struktura samostatne.
  NxTest.assert_equal('K009', s['decor'])
  NxTest.assert_equal('PW', s['structure'])
  e = mat.edge('ABS_K009_20')
  NxTest.assert(e, 'seed edge ABS_K009_20 sa nenasiel')
  NxTest.assert_close(2.0, e['thickness'])
  NxTest.assert_equal(nil, mat.sheet(nil))
  NxTest.assert_equal(nil, mat.sheet('NEEXISTUJE'))
  NxTest.assert_equal(nil, mat.edge(nil))
  NxTest.assert_equal(nil, mat.edge('NEEXISTUJE'))
  NxTest.assert_equal('W1000', mat.decor_of('W1000_DTDL_18'))
  NxTest.assert_equal(nil, mat.decor_of('NEEXISTUJE'))
  NxTest.assert_equal([238, 236, 230], mat.color_of('HDF_WHITE_3'))
  NxTest.assert_equal(nil, mat.color_of('NEEXISTUJE'))
end

NxTest.test('materials: supported_edge_thickness? — SCHEMA 1 presne {1;2}, SCHEMA 2 obchodne hodnoty') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  # 2A-4b: default katalog je uz SCHEMA 2 — SCHEMA 1 semantika sa overuje
  # EXPLICITNYM parametrom (dual-mode pre nerozhodnutelne legacy katalogy).
  legacy = mat::SCHEMA_LEGACY
  NxTest.assert(mat.supported_edge_thickness?(1.0, legacy))
  NxTest.assert(mat.supported_edge_thickness?(2.0, legacy))
  NxTest.assert(mat.supported_edge_thickness?(1, legacy), 'Integer 1 sa cez to_f ma uznat')
  NxTest.assert(mat.supported_edge_thickness?('2', legacy), 'String "2" sa cez to_f ma uznat')
  NxTest.refute(mat.supported_edge_thickness?(0.4, legacy), 'legacy whitelist 0.4 nepodporuje')
  NxTest.refute(mat.supported_edge_thickness?(0.8, legacy), 'legacy whitelist 0.8 nepodporuje')
  NxTest.refute(mat.supported_edge_thickness?(1.5, legacy))
  NxTest.refute(mat.supported_edge_thickness?(3.0, legacy))
  NxTest.refute(mat.supported_edge_thickness?(1.001, legacy), 'v0.3.3 BEZ tolerancie — presna zhoda')
  NxTest.refute(mat.supported_edge_thickness?(0.999, legacy), 'v0.3.3 BEZ tolerancie — presna zhoda')
  NxTest.refute(mat.supported_edge_thickness?(nil, legacy), 'nil.to_f = 0.0 -> nepodporovana')
  # SCHEMA 2 (default seedovaneho katalogu): obchodne hodnoty (2A-3), 3.0 nie.
  mabs_classic!
  mat.catalog
  NxTest.assert_equal(2, mat.catalog_schema, 'cerstvy seed je SCHEMA 2')
  NxTest.assert(mat.supported_edge_thickness?(0.8), 'SCHEMA 2 pusti 0.8')
  NxTest.assert(mat.supported_edge_thickness?(1.5), 'SCHEMA 2 pusti 1.5')
  NxTest.refute(mat.supported_edge_thickness?(3.0), '3.0 nie je obchodna hodnota')
end

NxTest.test('materials: normalized_abs_id pusti len id existujuce v katalogu') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  mabs_classic!
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
  mabs_classic!
  # 2A-4b: seed dekory su cisla (K009/W1000) — abs_for_decor je textovy legacy
  # picker, semantika tolerancie sa nemeni.
  NxTest.assert_equal('ABS_K009_10', mat.abs_for_decor('K009', 1.0))
  NxTest.assert_equal('ABS_K009_20', mat.abs_for_decor('K009', 2.0))
  # Tolerancia v kode je STRIKTNE < 0.01 mm.
  NxTest.assert_equal('ABS_K009_10', mat.abs_for_decor('K009', 1.005))
  NxTest.assert_equal(nil, mat.abs_for_decor('K009', 1.02))
  NxTest.assert_equal(nil, mat.abs_for_decor('K009', 0.4), 'hrubka bez variantu nema pasku')
  NxTest.assert_equal(nil, mat.abs_for_decor('W1000', 2.0), 'W1000 ma len 1.0 mm')
  NxTest.assert_equal(nil, mat.abs_for_decor('NeznamyDekor', 1.0))
  NxTest.assert_equal(nil, mat.abs_for_decor(nil, 1.0))
end

NxTest.test('materials: catalog pri citani odfiltruje nepodporovane ABS a prepise subor') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  mat = Noxun::Engine::Materials
  store = Noxun::Engine::JsonFileStore
  # M-B1: seed_sheets/seed_edges su uz UNI sada — SCHEMA 1 filter test pouziva
  # explicitne legacy zaznamy z helpera (4 dosky + 3 pasky, marker 1).
  base = JSON.parse(JSON.generate(NxTest::LEGACY_SEED_CATALOG))
  legacy = { 'abs_id' => 'ABS_K009_08', 'decor' => 'K009 PW', 'thickness' => 0.8,
             'price_per_bm' => 0.4, 'color' => [198, 168, 122] }
  nx_reset_catalog_file(mat.path)
  store.write(mat.path, { 'std' => 1, 'sheets' => base['sheets'],
                          'edges' => base['edges'] + [legacy] })
  mat.reset_catalog_state!
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

NxTest.test('abs_rules: seed pravidla — ZAMOK presnej mapy VSETKYCH roli (D-30)') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  rules = Noxun::Engine::AbsRules
  nx_reset_catalog_file(rules.path)
  # Rozhodnutie vlastnika (D-30): CELA sa olepuju DOOKOLA (4 hrany — dvierka v
  # Michalovych exportoch vzdy so 4 hranami), KORPUSOVE roly vratane vystuh presne
  # 1 dlha hrana L1 1.0 mm, chrbat a sokel NIC. Test drzi CELU mapu — zmena
  # ktorejkolvek roly musi byt vedome rozhodnutie, nie vedlajsi efekt.
  expected = {
    'front_door'   => { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 },
    'drawer_front' => { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 },
    # KOV-A1: vyklop/sklop (flap) a blenda (false_front) su cela -> 4 hrany 1,0
    # ako dvierka (SEED_VERSION 3).
    'flap'         => { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 },
    'false_front'  => { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 },
    'shelf'        => { 'L1' => 1.0 },
    'side_left'    => { 'L1' => 1.0 },
    'side_right'   => { 'L1' => 1.0 },
    'bottom'       => { 'L1' => 1.0 },
    'top'          => { 'L1' => 1.0 },
    'divider_v'    => { 'L1' => 1.0 },
    'divider_h'    => { 'L1' => 1.0 },
    'back'         => {},
    'plinth'       => {},
    'rail_front'   => { 'L1' => 1.0 },
    'rail_back'    => { 'L1' => 1.0 },
    'free_panel'   => { 'L1' => 1.0 }
  }
  NxTest.assert_equal(expected, rules::SEED_RULES, 'SEED_RULES sa lisia od zamknutej mapy')
  NxTest.assert_equal(expected, rules.load, 'cerstvy subor musi vratit presne seed mapu')
  # Funkcny pohlad cez thicknesses_for (rovnake skupiny ako mapa vyssie).
  %w[front_door drawer_front flap false_front].each do |role|
    th = rules.thicknesses_for(role)
    NxTest.assert_equal(%w[L1 L2 W1 W2], th.keys.sort, "rola #{role}")
    th.each_value { |v| NxTest.assert_close(1.0, v) }
  end
  %w[shelf side_left side_right bottom top divider_v divider_h
     rail_front rail_back free_panel].each do |role|
    NxTest.assert_equal({ 'L1' => 1.0 }, rules.thicknesses_for(role), "rola #{role} ma mat len L1 1.0")
  end
  %w[back plinth].each do |role|
    NxTest.assert_equal({}, rules.thicknesses_for(role), "rola #{role} nema mat ABS")
  end
  # Neznama rola -> prazdna mapa, ziadna vynimka.
  NxTest.assert_equal({}, rules.thicknesses_for('neznama_rola'))
  # D-30 audit FIX 4: labely vystuh su orientacne NEUTRALNE ("Predná" by pri
  # upright orientacii klamala) — L = dlha (pozdlzna) hrana.
  %w[rail_front rail_back].each do |role|
    NxTest.assert_equal('Pozdĺžna 1', rules.edge_labels(role)['L1'], "label L1 roly #{role}")
    NxTest.assert_equal('Priečna 2', rules.edge_labels(role)['W2'], "label W2 roly #{role}")
  end
  parsed = JSON.parse(File.binread(rules.path))
  NxTest.assert_equal(1, parsed['std'])
  NxTest.assert_equal(rules::SEED_VERSION, parsed['seed_version'])
end

NxTest.test('abs_rules: D-30 rail migracia — presne prazdne prepise, neprazdne NIKDY') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  ar = Noxun::Engine::AbsRules
  js = Noxun::Engine::JsonFileStore
  # (a) subor spred SEED_VERSION 2 so STOCK prazdnymi railmi ({} zo seedu v1):
  #     jednorazova migracia ich prepise na novy default {'L1'=>1.0}; ine roly nedotknute.
  js.write(ar.path, { 'std' => 1, 'seed_version' => 1,
                      'rules' => { 'rail_front' => {}, 'rail_back' => {},
                                   'shelf' => { 'L1' => 2.0 } } })
  ar.reload!
  rules = ar.load
  NxTest.assert_equal({ 'L1' => 1.0 }, rules['rail_front'], 'stock prazdny rail_front sa migruje')
  NxTest.assert_equal({ 'L1' => 1.0 }, rules['rail_back'], 'stock prazdny rail_back sa migruje')
  NxTest.assert_equal({ 'L1' => 2.0 }, rules['shelf'], 'pouzivatelska uprava inej roly ostava')
  parsed = JSON.parse(File.binread(ar.path))
  NxTest.assert_equal(ar::SEED_VERSION, parsed['seed_version'], 'subor po migracii nesie novu verziu')
  # (b) NEPRAZDNY obsah railu sa neprepise NIKDY — ani neplatny (normalizacia ho
  #     sice vyprazdni, ale migracia rozhoduje podla RAW obsahu suboru).
  js.write(ar.path, { 'std' => 1, 'seed_version' => 1,
                      'rules' => { 'rail_front' => { 'L2' => 2.0 },
                                   'rail_back' => { 'L1' => 0.8 } } })
  ar.reload!
  rules2 = ar.load
  NxTest.assert_equal({ 'L2' => 2.0 }, rules2['rail_front'], 'pouzivatelska uprava railu ostava')
  NxTest.assert_equal({}, rules2['rail_back'], 'neplatny obsah sa znormalizuje na prazdno, ale NEmigruje')
  # (c) subor UZ na aktualnom SEED_VERSION: vedome vyprazdneny rail ostava prazdny
  #     navzdy — migracia je jednorazova, nikdy sa nezopakuje.
  js.write(ar.path, { 'std' => 1, 'seed_version' => ar::SEED_VERSION,
                      'rules' => { 'rail_front' => {}, 'rail_back' => {} } })
  ar.reload!
  rules3 = ar.load
  NxTest.assert_equal({}, rules3['rail_front'], 'po migracii si pouzivatel smie rail vyprazdnit')
  NxTest.assert_equal({}, rules3['rail_back'])
  # cleanup: cisty seed pre dalsie testy v tomto procese
  nx_reset_catalog_file(ar.path)
end

NxTest.test('abs_rules: uniform_edges — kompletna 4-mapa, nil/prazdne odmieta (bulk kontrakt)') do
  ar = Noxun::Engine::AbsRules
  NxTest.assert_equal({ 'L1' => 'ABS_K009_10', 'L2' => 'ABS_K009_10',
                        'W1' => 'ABS_K009_10', 'W2' => 'ABS_K009_10' },
                      ar.uniform_edges('ABS_K009_10'))
  # D-35 audit FIX 5: bulk bez najdenej ABS musi byt no-op — mapa 4x nil by zmazala
  # existujuce hrany, preto uniform_edges nil/prazdne abs_id tvrdo odmieta.
  [nil, '', '   '].each do |bad|
    raised = false
    begin
      ar.uniform_edges(bad)
    rescue ArgumentError
      raised = true
    end
    NxTest.assert(raised, "uniform_edges(#{bad.inspect}) musi vyhodit ArgumentError")
  end
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
  mabs_classic!
  # Polica: pravidlo len L1 (predna) -> ABS dekoru K009 hrubky 1.0.
  # (2A-4b: seed dekory su cisla — textova legacy cesta resolve_edges bez
  # sheet zaznamu bezi dalej, len s novym textom dekoru.)
  NxTest.assert_equal({ 'L1' => 'ABS_K009_10', 'L2' => nil, 'W1' => nil, 'W2' => nil },
                      rules.resolve_edges('shelf', 'K009'))
  # D-30 (audit NOTE 11): vystuhy cez CELU resolve cestu — znamy dekor s existujucou
  # 1.0 mm ABS musi dat konkretny abs_id na dlhej hrane L1 (nie len thicknesses_for).
  %w[rail_front rail_back].each do |role|
    NxTest.assert_equal({ 'L1' => 'ABS_K009_10', 'L2' => nil, 'W1' => nil, 'W2' => nil },
                        rules.resolve_edges(role, 'K009'), "resolve_edges #{role}")
  end
  # Celo: vsetky 4 hrany rovnaky ABS variant.
  NxTest.assert_equal({ 'L1' => 'ABS_W1000_10', 'L2' => 'ABS_W1000_10',
                        'W1' => 'ABS_W1000_10', 'W2' => 'ABS_W1000_10' },
                      rules.resolve_edges('front_door', 'W1000'))
  # Dekor bez ABS variantu -> hrany bez ABS (nil), ziadna vynimka.
  NxTest.assert_equal(rules.empty_edges, rules.resolve_edges('front_door', 'Biela HDF'))
  # Chrbat nema pravidlo -> kompletna nil mapa.
  NxTest.assert_equal({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
                      rules.resolve_edges('back', 'K009 PW'))
  NxTest.assert_equal({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }, rules.empty_edges)
end

# ============================ TemplateStore ====================================

NxTest.test('templates: prvy load seedne 4 korpusove + 3 doskove sablony') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  tpl = Noxun::Engine::TemplateStore
  nx_reset_catalog_file(tpl.path)
  list = tpl.load
  NxTest.assert_equal(7, list.size)
  NxTest.assert_equal(['Dolna klasik', 'Drezova', 'Varna doska', 'Horna klasik'],
                      list.select { |t| t['kind'] == 'cabinet' }.map { |t| t['name'] })
  NxTest.assert_equal(['Diel', 'Pracovná doska', 'Zástena'],
                      list.select { |t| t['kind'] == 'board' }.map { |t| t['name'] })
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
  NxTest.assert_equal(Noxun::Engine::TemplateStore::STD, parsed['std'],
                      'cerstva instalacia je rovno na AKTUALNOM markeri (UI-C1c: 3)')
  NxTest.assert_equal(7, parsed['templates'].size)
end

NxTest.test('templates: find/upsert/delete round-trip') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  tpl = Noxun::Engine::TemplateStore
  nx_reset_catalog_file(tpl.path)
  NxTest.assert_equal(true, tpl.upsert('cabinet', 'Testovacia', { 'type' => 'lower', 'width' => 450.0 }))
  found = tpl.find('cabinet', 'Testovacia')
  NxTest.assert(found, 'upsertnuta sablona sa nenasla')
  NxTest.assert_equal('Testovacia', found['name'])
  NxTest.assert_equal('cabinet', found['kind'])
  NxTest.assert_equal('lower', found['config']['type'])
  NxTest.assert_close(450.0, found['config']['width'])
  NxTest.assert_equal(8, tpl.load.size, '7 seed + 1 nova')
  NxTest.assert_equal(true, tpl.delete('cabinet', 'Testovacia'))
  NxTest.assert_equal(nil, tpl.find('cabinet', 'Testovacia'))
  NxTest.assert_equal(7, tpl.load.size)
end

NxTest.test('templates: upsert prepise existujucu sablonu podla dvojice (kind, meno)') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  tpl = Noxun::Engine::TemplateStore
  nx_reset_catalog_file(tpl.path)
  tpl.upsert('cabinet', 'Duplikat', { 'width' => 400.0 })
  tpl.upsert('cabinet', 'Duplikat', { 'width' => 500.0 })
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
  # Rucny zapis vratil marker na 1 -> dalsi load spusti migraciu (kind + seed
  # dosiek). Rucna sablona ostava a dostane kind 'cabinet'.
  list = tpl.reload!
  NxTest.assert_equal(4, list.size, '1 rucna + 3 doskove zo seedu migracie')
  NxTest.assert_equal('Rucna', list[0]['name'])
  NxTest.assert_equal('cabinet', list[0]['kind'])
  NxTest.assert_equal('upper', list[0]['config']['type'])
  NxTest.assert_equal(4, tpl.load.size, 'aj dalsi load ma vidiet rucny zapis')
end
