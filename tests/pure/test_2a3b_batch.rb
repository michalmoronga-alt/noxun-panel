# frozen_string_literal: true
# Testy 2A-3b: batch schema 3 (audit B4 + B5 + F13) + O-ensure universal.
#
# KONTRAKT DAVKY: zivy katalog je stale SCHEMA 1 — pri nom sa spravanie davky
# NEMENI (batch 1/2 bezia presne ako dnes); batch 3 je NOVA cesta a pri
# katalogu 1 sa odmieta. Katalog SCHEMA 2 prijima VYHRADNE plne validny
# batch 3 (B5 matica). Vsetko headless (APPDATA sandbox helpera).
require_relative '../helper' unless defined?(NxTest)

# 2A-4b: seedy su nativne SCHEMA 2 — tento subor overuje DUAL-MODE (legacy)
# spravanie, preto si ako prvy krok instaluje predcutoverovy legacy katalog
# (registrovany setup test — testy bezia sekvencne v poradi registracie).
NxTest.test('2a3b setup: legacy SCHEMA 1 katalog (dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_legacy_catalog!, 'legacy katalog sa nenainstaloval')
  NxTest.assert_equal(1, Noxun::Engine::Materials.catalog_schema, 'sandbox ma byt SCHEMA 1')
end

B3MAT = Noxun::Engine::Materials
B3STORE = Noxun::Engine::JsonFileStore

# Docasne nainstaluje CELY katalog (sheets + edges + schema marker) a po bloku
# vrati bajt-presny povodny stav (vzor a3_with_catalog z test_2a3_picker).
def b3_with_catalog(sheets, edges, schema: 2)
  path = B3MAT.path
  B3MAT.catalog # seed, aby subor existoval
  before = File.binread(path)
  B3STORE.write(path, { 'std' => B3MAT::STD, 'schema' => schema,
                        'sheets' => sheets, 'edges' => edges })
  yield
ensure
  if before
    File.binwrite(path, before)
    B3STORE.invalidate(path)
  end
end

# Doska SCHEMA 2 (group_id + struktura; prazdne stringy sa vynechavaju).
def b3_sheet(id, decor, structure, extra = {})
  { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => decor,
    'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length',
    'color' => [200, 200, 200], 'production_class' => 'sheet',
    'group_id' => "GRP-#{decor.upcase}", 'structure' => structure.to_s }
    .reject { |_k, v| v.is_a?(String) && v.empty? }.merge(extra)
end

# Platny batch 3 payload (Egger K111, 1 doska ST9 18 + 1 paska 23/1 ST9).
def b3_attrs(over = {})
  {
    'batch_schema' => 3, 'decor' => 'K111', 'manufacturer' => 'Egger',
    'decor_name' => 'Testovací dub', 'type' => 'DTDL', 'grain' => 'length',
    'color' => [10, 20, 30],
    'sheet_variants' => [{ 'thickness' => 18.0, 'structure' => 'ST9' }],
    'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9' }]
  }.merge(over)
end

# ---------------------------------------------------------------------------
# B5: kompatibilna matica schema katalogu x batch_schema (4 kombinacie)
# ---------------------------------------------------------------------------

NxTest.test('2a3b: B5 matica — katalog 1 + batch 3 = odmietnutie (katalog neprepnuty), bez zapisu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  before = B3MAT.catalog_revision
  ok, err = B3MAT.add_decor_batch(b3_attrs)
  NxTest.refute(ok, 'batch 3 do katalogu 1 nesmie prejst')
  NxTest.assert(err.include?('nie je prepnutý'), "chyba vysvetluje stav katalogu: #{err}")
  NxTest.assert_equal(before, B3MAT.catalog_revision, 'ziadny zapis')
end

NxTest.test('2a3b: B5 matica — katalog 1 + batch 1/2 bezi presne ako dnes (dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = B3MAT.add_decor_batch('decor' => 'Matica Legacy', 'thicknesses' => '18')
  NxTest.assert(ok, "batch 1 pri katalogu 1 musi prejst: #{res.inspect}")
  NxTest.assert_equal(1, res['sheets'].size)
  ok2, res2 = B3MAT.add_decor_batch('batch_schema' => 2, 'decor' => 'Matica Legacy',
                                    'sheet_variants' => [{ 'thickness' => 36.0 }])
  NxTest.assert(ok2, "batch 2 pri katalogu 1 musi prejst: #{res2.inspect}")
  (res['sheets'] + res2['sheets']).each { |id| B3MAT.delete_sheet(id) }
end

NxTest.test('2a3b: B5 matica — katalog 2 odmieta batch 1/2 (obnov sekciu), prijme len batch 3') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([b3_sheet('S1', 'G1', 'ST9')], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch('decor' => 'Novy', 'thicknesses' => '18')
    NxTest.refute(ok, 'batch 1 do katalogu 2 nesmie prejst')
    NxTest.assert(err.include?('obnov sekciu'), err.to_s)
    ok2, err2 = B3MAT.add_decor_batch('batch_schema' => 2, 'decor' => 'Novy',
                                      'sheet_variants' => [{ 'thickness' => 18.0 }])
    NxTest.refute(ok2, 'batch 2 do katalogu 2 nesmie prejst')
    NxTest.assert(err2.include?('obnov sekciu'), err2.to_s)
    ok3, res3 = B3MAT.add_decor_batch(b3_attrs)
    NxTest.assert(ok3, "plne validny batch 3 musi prejst: #{res3.inspect}")
  end
end

# ---------------------------------------------------------------------------
# B4: group_id — nova skupina deterministicky, existujuca prevzata, kolizie
# ---------------------------------------------------------------------------

NxTest.test('2a3b: B4 — nova skupina = group_id_for; doska aj paska davky sa stretnu v jednej skupine') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok, res = B3MAT.add_decor_batch(b3_attrs)
    NxTest.assert(ok, "batch mal prejst: #{res.inspect}")
    gid = B3MAT.group_id_for('Egger', 'K111')
    s = B3MAT.sheet(res['sheets'][0])
    e = B3MAT.edge(res['edges'][0])
    NxTest.assert_equal(gid, s['group_id'], 'doska nesie deterministicky gid')
    NxTest.assert_equal(gid, e['group_id'], 'paska nesie TEN ISTY gid')
    NxTest.assert_equal('Testovací dub', s['decor_name'])
    NxTest.assert_equal('Testovací dub', e['decor_name'])
    NxTest.assert_equal('ST9', s['structure'])
    NxTest.assert_equal('ST9', e['structure'])
    NxTest.assert_equal('Egger', s['manufacturer'])
    NxTest.refute(e.key?('manufacturer'), 'ABS vyrobcu NIKDY nenesie (standard 7.5)')
    # stretnutie: picker abs_for_sheet vyberie pasku z tej istej davky
    NxTest.assert_equal([e['abs_id'], nil], B3MAT.abs_for_sheet(s, :jednotka, 18.0))
  end
end

NxTest.test('2a3b: B4 — existujuca skupina (presna identita) preberie svoj group_id, nie novy hash') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  existing = b3_sheet('S1', 'K111', 'PW', 'group_id' => 'GRP-POVODNA', 'decor_name' => 'Testovací dub')
  b3_with_catalog([existing], [], schema: 2) do
    ok, res = B3MAT.add_decor_batch(b3_attrs)
    NxTest.assert(ok, "batch mal prejst: #{res.inspect}")
    s = B3MAT.sheet(res['sheets'][0])
    NxTest.assert_equal('GRP-POVODNA', s['group_id'], 'prevzaty gid existujucej skupiny')
    NxTest.assert_equal('GRP-POVODNA', B3MAT.edge(res['edges'][0])['group_id'])
    NxTest.refute(s['group_id'] == B3MAT.group_id_for('Egger', 'K111'), 'hash sa NEgeneruje nanovo')
  end
end

NxTest.test('2a3b: B4 — near-match skupiny (rozdiel len pismom) = chyba s presnym tvarom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([b3_sheet('S1', 'K111', 'ST9')], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch(b3_attrs('decor' => 'k111', 'decor_name' => ''))
    NxTest.refute(ok, 'near-match nesmie zalozit druhu skupinu')
    NxTest.assert(err.include?('len zápisom') && err.include?('K111'), err.to_s)
  end
end

NxTest.test('2a3b: B4 — rovnake cislo dekoru ineho vyrobcu = DVE skupiny (standard 7.1)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([b3_sheet('S1', 'K111', 'ST9')], [], schema: 2) do
    ok, res = B3MAT.add_decor_batch(b3_attrs('manufacturer' => 'Kronospan'))
    NxTest.assert(ok, "iny vyrobca je legitimna nova skupina: #{res.inspect}")
    s = B3MAT.sheet(res['sheets'][0])
    NxTest.assert_equal(B3MAT.group_id_for('Kronospan', 'K111'), s['group_id'])
    NxTest.refute(s['group_id'] == 'GRP-K111', 'povodna skupina nedotknuta')
  end
end

NxTest.test('2a3b: B4 — kolizia group_id s inou identitou = chyba celej davky') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  stolen = B3MAT.group_id_for('Egger', 'K111')
  cudzia = b3_sheet('SX', 'INY', 'ST9', 'group_id' => stolen)
  b3_with_catalog([cudzia], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch(b3_attrs)
    NxTest.refute(ok, 'obsadeny gid s inou identitou nesmie prejst')
    NxTest.assert(err.include?('Kolízia'), err.to_s)
  end
end

# ---------------------------------------------------------------------------
# F13: universal konflikt vs dedup + dup identity dosky v davke
# ---------------------------------------------------------------------------

NxTest.test('2a3b: F13 — rovnaka identita ABS s roznym universal = chyba CELEJ davky bez zapisu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    before = B3MAT.catalog_revision
    ok, err = B3MAT.add_decor_batch(b3_attrs('edge_variants' => [
      { 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9', 'universal' => true },
      { 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9' }
    ]))
    NxTest.refute(ok, 'universal konflikt nesmie prejst tichym prvy-vyhrava')
    NxTest.assert(err.include?('univerzálna'), err.to_s)
    NxTest.assert_equal(before, B3MAT.catalog_revision, 'ziadny zapis (validate-all)')
  end
end

NxTest.test('2a3b: F13 — rovnaka identita ABS s ROVNAKYM universal = tichy dedup (1 paska)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok, res = B3MAT.add_decor_batch(b3_attrs('edge_variants' => [
      { 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9', 'universal' => 'true' },
      { 'width' => 23.004, 'thickness' => 1.0, 'structure' => 'st9', 'universal' => true }
    ]))
    NxTest.assert(ok, "dedup mal prejst: #{res.inspect}")
    NxTest.assert_equal(1, res['edges'].size, 'tolerancna identita = jedna paska')
    NxTest.assert_equal(true, B3MAT.edge(res['edges'][0])['universal'], 'vedomy priznak sa ulozil')
  end
end

NxTest.test('2a3b: F13 — rovnaka identita dosky dvakrat = chyba; INA struktura = dva varianty') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [
      { 'thickness' => 18.0, 'structure' => 'ST9' },
      { 'thickness' => 18.004, 'structure' => 'st9' }
    ]))
    NxTest.refute(ok, 'tolerancne rovnaka identita (case-insensitive struktura) = dup')
    NxTest.assert(err.include?('dvakrát'), err.to_s)
    ok2, res2 = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [
      { 'thickness' => 18.0, 'structure' => 'ST9' },
      { 'thickness' => 18.0, 'structure' => 'MG' }
    ]))
    NxTest.assert(ok2, "rozne struktury su dva varianty: #{res2.inspect}")
    NxTest.assert_equal(2, res2['sheets'].size)
  end
end

# ---------------------------------------------------------------------------
# Batch 3 obsah: obchodne hrubky, decor_name, stringove polia, PD format, skip
# ---------------------------------------------------------------------------

NxTest.test('2a3b: batch 3 — obchodne hrubky 0,8/1,5/0,4 do katalogu 2 prejdu (vedome zalozenie)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok, res = B3MAT.add_decor_batch(b3_attrs('edge_variants' => [
      { 'width' => 23.0, 'thickness' => 0.8, 'structure' => 'ST9' },
      { 'width' => 23.0, 'thickness' => 1.5, 'structure' => 'ST9' },
      { 'width' => 23.0, 'thickness' => 0.4, 'structure' => 'ST9' }
    ]))
    NxTest.assert(ok, "obchodne hrubky maju prejst: #{res.inspect}")
    ths = res['edges'].map { |id| B3MAT.edge(id)['thickness'] }.sort
    NxTest.assert_equal([0.4, 0.8, 1.5], ths)
    ok2, err2 = B3MAT.add_decor_batch(b3_attrs('edge_variants' => [
      { 'width' => 23.0, 'thickness' => 0.5, 'structure' => 'ST9' }
    ]))
    NxTest.refute(ok2, '0,5 nie je obchodna hodnota ani v schema 2')
    NxTest.assert(err2.include?('0,4/0,8/1/1,2/1,5/2'), err2.to_s)
  end
end

NxTest.test('2a3b: batch 3 — decor_name: existujucej skupine sa davkou NEMENI, prazdny sa dedi') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  existing = b3_sheet('S1', 'K111', 'PW', 'decor_name' => 'Dub prírodný')
  b3_with_catalog([existing], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch(b3_attrs('decor_name' => 'Iný názov'))
    NxTest.refute(ok, 'iny nazov skupiny nesmie prejst davkou')
    NxTest.assert(err.include?('názov'), err.to_s)
    ok2, res2 = B3MAT.add_decor_batch(b3_attrs('decor_name' => ''))
    NxTest.assert(ok2, "prazdny nazov = zdedit: #{res2.inspect}")
    NxTest.assert_equal('Dub prírodný', B3MAT.sheet(res2['sheets'][0])['decor_name'])
    NxTest.assert_equal('Dub prírodný', B3MAT.edge(res2['edges'][0])['decor_name'])
  end
end

NxTest.test('2a3b: batch 3 — stringove polia (thicknesses/abs_tokens) sa odmietnu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch(b3_attrs('thicknesses' => '18'))
    NxTest.refute(ok)
    NxTest.assert(err.include?('štruktúrovane'), err.to_s)
    ok2, err2 = B3MAT.add_decor_batch(b3_attrs('abs_tokens' => '23/1'))
    NxTest.refute(ok2)
    NxTest.assert(err2.include?('štruktúrovane'), err2.to_s)
  end
end

NxTest.test('2a3b: batch 3 — PD bez formatu = chyba; dva formaty = dva varianty s formatom v ID') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch(b3_attrs(
      'sheet_variants' => [{ 'type' => 'PD', 'thickness' => 38.0 }], 'edge_variants' => []
    ))
    NxTest.refute(ok, 'PD bez formatu je neuplna identita (vzor migracie O8)')
    NxTest.assert(err.include?('formát'), err.to_s)
    ok2, res2 = B3MAT.add_decor_batch(b3_attrs(
      'sheet_variants' => [
        { 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0] },
        { 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 920.0] }
      ], 'edge_variants' => []
    ))
    NxTest.assert(ok2, "dva PD formaty su dva varianty: #{res2.inspect}")
    NxTest.assert_equal(2, res2['sheets'].size)
    NxTest.assert(res2['sheets'].any? { |id| id.include?('4100X600') }, res2['sheets'].inspect)
    ok3, err3 = B3MAT.add_decor_batch(b3_attrs(
      'sheet_variants' => [
        { 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 640.0] },
        { 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [640.0, 4100.0] }
      ], 'edge_variants' => []
    ))
    NxTest.refute(ok3, 'ten isty format v inom poradi stran = duplicita v davke')
    NxTest.assert(err3.include?('dvakrát'), err3.to_s)
  end
end

NxTest.test('2a3b: batch 3 — existujuce varianty sa preskocia cez kanonicku identitu (+ variant flow)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok1, res1 = B3MAT.add_decor_batch(b3_attrs)
    NxTest.assert(ok1, res1.inspect)
    ok2, err2 = B3MAT.add_decor_batch(b3_attrs)
    NxTest.refute(ok2, 'vsetko existuje = false')
    NxTest.assert(err2.include?('už v katalógu'), err2.to_s)
    ok3, res3 = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [
      { 'thickness' => 18.0, 'structure' => 'ST9' },
      { 'thickness' => 36.0, 'structure' => 'ST9' }
    ]))
    NxTest.assert(ok3, res3.inspect)
    NxTest.assert_equal(1, res3['sheets'].size, 'len nova 36')
    NxTest.assert_equal(2, res3['skipped'].size, 'preskocena doska 18 + paska 23/1')
  end
end

NxTest.test('2a3b: batch 3 — poskodena polozka / prazdna davka / zla sirka = chyba (validate-all)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], [], schema: 2) do
    ok, err = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => ['zlo']))
    NxTest.refute(ok)
    NxTest.assert(err.include?('Poškodená'), err.to_s)
    ok2, err2 = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [], 'edge_variants' => []))
    NxTest.refute(ok2)
    NxTest.assert(err2.include?('aspoň jeden'), err2.to_s)
    ok3, err3 = B3MAT.add_decor_batch(b3_attrs('edge_variants' => [
      { 'width' => 5.0, 'thickness' => 1.0 }
    ]))
    NxTest.refute(ok3, 'sirka pod rozsahom')
    NxTest.assert(err3.include?('10–200'), err3.to_s)
  end
end

# ---------------------------------------------------------------------------
# O-ensure: bezstrukturna doska -> dovytvorena paska universal:true
# ---------------------------------------------------------------------------

NxTest.test('2a3b: ensure — doska BEZ struktury dava dovytvorenej paske universal:true') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([b3_sheet('S1', 'G1', '')], [], schema: 2) do
    status, abs_id = B3MAT.ensure_edge_for_sheet('S1', client_schema: 2)
    NxTest.assert_equal(:created, status)
    rec = B3MAT.edge(abs_id)
    NxTest.assert_equal(true, rec['universal'], 'universal je jedina cesta k pouzitelnosti')
    NxTest.refute(rec.key?('structure'), 'ziadna struktura sa nevymysla')
    NxTest.assert_equal(1.0, rec['thickness'])
    NxTest.assert_equal('GRP-G1', rec['group_id'])
    NxTest.assert_equal([abs_id, nil], B3MAT.abs_for_sheet(B3MAT.sheet('S1'), :jednotka, 18.0),
                        'picker novu pasku hned najde universal vetvou')
  end
end

NxTest.test('2a3b: ensure — doska SO strukturou dedi strukturu, universal sa NENASTAVUJE (2A-3a kontrakt)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([b3_sheet('S1', 'G1', 'ST9')], [], schema: 2) do
    status, abs_id = B3MAT.ensure_edge_for_sheet('S1', client_schema: 2)
    NxTest.assert_equal(:created, status)
    rec = B3MAT.edge(abs_id)
    NxTest.assert_equal('ST9', rec['structure'])
    NxTest.refute(rec.key?('universal'))
  end
end

# ---------------------------------------------------------------------------
# GH #91 kolo 1: zamok + fresh load, branded edge-only zakaz
# ---------------------------------------------------------------------------

NxTest.test('2a3b: GH P2 — NOVA znackova skupina bez dosky sa nezaklada (edge-only si zamkne identitu)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], []) do
    ok, err = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => []))
    NxTest.refute(ok, 'znackova edge-only davka sa odmietne')
    NxTest.assert(err.include?('aspoň jednu dosku'), err)
    # vlastna (bez vyrobcu) edge-only skupina je legalna
    ok2, res2 = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [], 'manufacturer' => '',
                                               'decor' => 'VlastnaPaska', 'decor_name' => ''))
    NxTest.assert(ok2, res2.inspect)
    NxTest.assert_equal(1, res2['edges'].length)
    # pridanie pasky do EXISTUJUCEJ znackovej skupiny (doska uz stoji) funguje
    ok3, res3 = B3MAT.add_decor_batch(b3_attrs)
    NxTest.assert(ok3, res3.inspect)
    ok4, res4 = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [],
                                               'edge_variants' => [{ 'width' => 43.0, 'thickness' => 1.0, 'structure' => 'ST9' }]))
    NxTest.assert(ok4, res4.inspect)
    NxTest.assert_equal(1, res4['edges'].length, 'edge-only do existujucej znackovej skupiny presiel')
  end
end

NxTest.test('2a3b: GH P1 — batch bezi nad CERSTVYM obsahom (cudzi zapis pred zamkom sa neprepise)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], []) do
    ok, res = B3MAT.add_decor_batch(b3_attrs)
    NxTest.assert(ok, res.inspect)
    # "iny proces": zapise dalsi zaznam PRIAMO do suboru (cache o nom nevie)
    raw = JSON.parse(File.binread(B3MAT.path))
    cudzia = raw['edges'].first.merge('abs_id' => 'ABS_CUDZIA_43X10', 'width' => 43.0)
    raw['edges'] << cudzia
    File.binwrite(B3MAT.path, JSON.pretty_generate(raw))
    # batch s TOU ISTOU 43-kou: fresh load pod zamkom ju musi vidiet -> skip,
    # a cudzi zaznam NESMIE zmiznut zo suboru
    ok2, res2 = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [],
                                               'edge_variants' => [{ 'width' => 43.0, 'thickness' => 1.0, 'structure' => 'ST9' }]))
    NxTest.refute(ok2, 'vsetko uz existuje = davka nic nevytvorila')
    NxTest.assert(res2.include?('už v katalógu'), res2.to_s)
    after = JSON.parse(File.binread(B3MAT.path))
    NxTest.assert(after['edges'].any? { |a| a['abs_id'] == 'ABS_CUDZIA_43X10' },
                  'cudzi zapis prezil davku')
  end
end

NxTest.test('2a3b: GH P2 kolo 2 — existujuci variant s opacnym universal = konflikt davky, nie tichy skip') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], []) do
    ok, = B3MAT.add_decor_batch(b3_attrs)
    NxTest.assert(ok)
    # rovnaka identita (sirka+hrubka+struktura), OPACNY universal -> chyba
    ok2, err = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [],
                                              'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0,
                                                                    'structure' => 'ST9', 'universal' => true }]))
    NxTest.refute(ok2, 'opacny universal sa nesmie ticho skipnut')
    NxTest.assert(err.include?('univerzálna'), err)
    # zhodny universal (false) -> normalny skip
    ok3, res3 = B3MAT.add_decor_batch(b3_attrs('sheet_variants' => [],
                                               'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0,
                                                                     'structure' => 'ST9' }]))
    NxTest.refute(ok3, 'vsetko existuje')
    NxTest.assert(res3.include?('už v katalógu'), res3.to_s)
  end
end

NxTest.test('2a3b: GH P1 kolo 2 — ensure RMW pod zamkom vidi cerstvy obsah (cudzi zapis prezije)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [b3_sheet('ENS18', 'K222', 'ST9')]
  b3_with_catalog(sheets, []) do
    # "iny proces" zapise pasku PRIAMO do suboru (cache o nej nevie)
    raw = JSON.parse(File.binread(B3MAT.path))
    raw['edges'] << { 'abs_id' => 'ABS_CUDZIA_ENS', 'decor' => 'K222', 'thickness' => 1.0,
                      'width' => 23.0, 'group_id' => 'GRP-K222', 'structure' => 'ST9' }
    File.binwrite(B3MAT.path, JSON.pretty_generate(raw))
    status, abs_id = B3MAT.ensure_edge_for_sheet('ENS18', client_schema: 2)
    NxTest.assert_equal(:exists, status, 'fresh load pod zamkom vidi cudziu pasku (ziadna dupla tvorba)')
    NxTest.assert_equal('ABS_CUDZIA_ENS', abs_id)
  end
end

NxTest.test('2a3b: GH P2 kolo 3 — batch_schema 4 sa odmieta (ziadna ciastocna interpretacia ako v3)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b3_with_catalog([], []) do
    ok, err = B3MAT.add_decor_batch(b3_attrs('batch_schema' => 4))
    NxTest.refute(ok, 'buduca schema davky sa nesmie tvarit ako v3')
    NxTest.assert(err.include?('novšom formáte'), err.to_s)
  end
end
