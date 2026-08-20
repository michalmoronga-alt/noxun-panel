# frozen_string_literal: true
# K1 / D-108 — SMER DEKORU PER DIELEC ako VSTUP.
#
# PRECO tato sada existuje (realny incident 19.8.2026): v objednavke naostro
# mala tenka horna blenda POZDLZNU kresbu a vysoke uzke dvere pod nou PRIECNU.
# Plugin to vtedy nevedel ani nastavit, ani ukazat — smer urcoval VYHRADNE
# material. Davka K1 zaviedla per-dielec override `part_overrides['grain_direction']`.
#
# ZAVAZNY KONTRAKT, ktory tu zamykame (porusenie = zle objednany dielec):
#   1) ROTACIA SA NEROBI NIKDE NOVO. Snapshot dielca nesie GEOMETRICKE rozmery
#      + efektivny `grain_direction`. Vymenu dlzka<->sirka (a dvojic hran) robi
#      VYHRADNE `VepoExport.oriented` a zrkadlovo `Validation.fits_on_sheet?` —
#      presne ako pred K1. Dvojity swap by dielec objednal v POVODNEJ orientacii.
#   2) K1 meni JEDINE ZDROJ smeru: `CabinetBuilder.effective_grain`
#      (override -> material), materializovany RAZ do snapshotu dielca.
#   3) STALE OVERRIDE: material bez smeru ('none', UNI, material mimo katalogu)
#      override NEMAZE, len IGNORUJE. Otacat kresbu, ktora neexistuje, by bola
#      lož; mazanie by zahodilo rozhodnutie pouzivatela.
#   4) ENUM: do configu sa dostane LEN 'length'/'width'. Neznama hodnota
#      (aj z novsej verzie pluginu) vypadne — NIKDY tichy fallback.
#   5) STARY MODEL BEZ POLA je platny a otvorenie ho NESMIE zmenit (round-trip
#      config -> params -> normalize je identita).
#   6) ABS bezne metre su INVARIANTNE voci otoceniu (bm sa nesmie zmenit tym,
#      ze dielec ide do VEPO otoceny) — to je krizova kontrola „ziadny dvojity
#      swap" medzi kusovnikom a exportom.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

K1CB    = Noxun::Engine::CabinetBuilder
K1MAT   = Noxun::Engine::Materials
K1STORE = Noxun::Engine::JsonFileStore
K1BOM   = Noxun::Engine::Bom
K1VEPO  = Noxun::Engine::VepoExport
K1VAL   = Noxun::Engine::Validation

# Docasny katalog (vzor `a3_with_catalog`): po bloku sa vrati BAJT-PRESNY
# povodny stav, takze poradie testovych suborov ostava nedotknute.
def k1_with_catalog(sheets, edges)
  path = K1MAT.path
  K1MAT.catalog # seed, aby subor existoval
  before = File.binread(path)
  K1STORE.write(path, { 'std' => K1MAT::STD, 'schema' => 2, 'sheets' => sheets, 'edges' => edges })
  K1STORE.invalidate(path)
  K1MAT.reset_catalog_state!
  yield
ensure
  if before
    File.binwrite(path, before)
    K1STORE.invalidate(path)
    K1MAT.reset_catalog_state!
  end
end

def k1_sheet(id, grain, extra = {})
  { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => "DEC-#{id}",
    'type' => 'DTDL', 'thickness' => 18.0, 'grain' => grain,
    'color' => [200, 200, 200], 'production_class' => 'sheet',
    'group_id' => "GRP-#{id}", 'structure' => 'ST9',
    'sheet_size' => [2800.0, 2070.0] }.merge(extra)
end

K1_SHEETS = [
  k1_sheet('DUB18', 'length'),                       # dekor s kresbou po dlzke
  k1_sheet('DUB_W18', 'width'),                      # dekor s kresbou po sirke
  k1_sheet('BIELA18', 'none'),                       # jednofarebny — smer nema
  k1_sheet('UNI18', 'none', 'uni' => true, 'uni_role' => 'body')
].freeze

K1_EDGES = [
  { 'abs_id' => 'ABS_DUB_10', 'decor' => 'DEC-DUB18', 'thickness' => 1.0,
    'group_id' => 'GRP-DUB18', 'structure' => 'ST9', 'color' => [200, 200, 200] }
].freeze

# Deskriptor dielca (to, co dava Construction) — pouzivame synteticky, aby sada
# ostala cisto vypoctova (ziadna geometria, ziadny model).
def k1_pd(key: 'zone:Z1/shelf:1', role: 'shelf', length: 2000.0, width: 250.0, th: 18.0)
  { part_key: key, suffix: 'SHELF-1-1', role: role, material: :korpus,
    prod: { length: length, width: width, thickness: th } }
end

# ---------------------------------------------------------------------------
# 1) effective_grain — cela matica retaze override -> material
# ---------------------------------------------------------------------------

NxTest.test('K1: effective_grain — override prebija material, ale LEN ked material smer MA') do
  sheet_l = { 'grain' => 'length' }
  sheet_w = { 'grain' => 'width' }
  sheet_n = { 'grain' => 'none' }

  # dedenie (ziadny override) = dnesne spravanie pred K1
  NxTest.assert_equal('length', K1CB.effective_grain(sheet_l, nil))
  NxTest.assert_equal('width',  K1CB.effective_grain(sheet_w, nil))
  NxTest.assert_equal('none',   K1CB.effective_grain(sheet_n, nil))
  NxTest.assert_equal('none',   K1CB.effective_grain(nil, nil), 'material mimo katalogu = bez smeru')

  # override otoci kresbu OBOMA smermi
  NxTest.assert_equal('width',  K1CB.effective_grain(sheet_l, 'width'), 'incident 19.8.: blenda naprieč')
  NxTest.assert_equal('length', K1CB.effective_grain(sheet_w, 'length'))
  NxTest.assert_equal('length', K1CB.effective_grain(sheet_l, 'length'), 'override zhodny s materialom')

  # STALE OVERRIDE: material bez smeru — override sa IGNORUJE (nie zmaze)
  NxTest.assert_equal('none', K1CB.effective_grain(sheet_n, 'width'),
                      'jednofarebny material nema co otacat')
  NxTest.assert_equal('none', K1CB.effective_grain(nil, 'width'),
                      'material mimo katalogu tiez nie')

  # ENUM: neznama hodnota nikdy nevytvori novy smer — spadne na material
  ['none', 'diagonal', '', nil, 42, 'LENGTH'].each do |bad|
    NxTest.assert_equal('length', K1CB.effective_grain(sheet_l, bad),
                        "neznamy override #{bad.inspect} sa NESMIE uplatnit")
  end
end

# ---------------------------------------------------------------------------
# 2) norm_overrides — whitelist zapisovaneho tvaru
# ---------------------------------------------------------------------------

NxTest.test('K1: norm_overrides pusti do configu LEN length/width') do
  ov = K1CB.norm_overrides(
    'a' => { 'grain_direction' => 'length' },
    'b' => { 'grain_direction' => 'width' },
    'c' => { 'grain_direction' => 'none' },
    'd' => { 'grain_direction' => 'diagonal' },
    'e' => { 'grain_direction' => '' },
    'f' => { 'grain_direction' => nil },
    'g' => { grain_direction: 'width' } # symbolovy kluc (stary klient/JSON)
  )
  NxTest.assert_equal('length', ov['a']['grain_direction'])
  NxTest.assert_equal('width', ov['b']['grain_direction'])
  NxTest.assert_equal('width', ov['g']['grain_direction'])
  # Zaznam, z ktoreho vypadol jediny kluc, je BEZOBSAZNY a miznе cely —
  # inak by config zbieral prazdne skrupiny po kazdom neplatnom vstupe.
  %w[c d e f].each do |k|
    NxTest.assert(!ov.key?(k), "neplatny smer (#{k}) nesmie ostat v configu")
  end
end

NxTest.test('K1: smer dekoru NEZAHADZUJE ostatne polia overridu (a naopak)') do
  ov = K1CB.norm_overrides(
    'zone:Z1/shelf:1' => { 'material_id' => 'DUB18', 'grain_direction' => 'width',
                           'edges' => { 'L1' => nil } }
  )
  rec = ov['zone:Z1/shelf:1']
  NxTest.assert_equal('DUB18', rec['material_id'])
  NxTest.assert_equal('width', rec['grain_direction'])
  NxTest.assert(rec['edges'].key?('L1'), 'explicitne „bez ABS" prezije')
end

# ---------------------------------------------------------------------------
# 3) STARY MODEL BEZ POLA — regresna brana
# ---------------------------------------------------------------------------

NxTest.test('K1: config STAREJ zakazky BEZ pola prejde round-tripom NEZMENENY') do
  # Otvorenie starej zakazky nesmie nic zapisat, nic prestavat a nesmie
  # vyrobit krok Spat. Headless ekvivalent: retaz config -> params -> normalize
  # je IDENTITA (kluc `grain_direction` nikde nepribudne).
  legacy = {
    'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
    'thickness' => 18.0, 'floor_height' => 100.0,
    'part_overrides' => {
      'cabinet/side:left' => { 'material_id' => 'DUB18' },
      'zone:Z1/shelf:1' => { 'edges' => { 'L1' => nil } }
    }
  }
  params = K1CB.config_to_params(legacy)
  out = K1CB.normalize(params)[:part_overrides]
  NxTest.assert_equal({ 'material_id' => 'DUB18' }, out['cabinet/side:left'])
  NxTest.assert(!out['cabinet/side:left'].key?('grain_direction'),
                'stary zaznam NESMIE dostat smer dekoru — dedenie je prave „ziadny kluc"')
  NxTest.assert(!out['zone:Z1/shelf:1'].key?('grain_direction'))
  # a druhy prechod uz nesmie zmenit vobec nic (idempotencia)
  again = K1CB.normalize(K1CB.config_to_params(legacy.merge('part_overrides' => out)))[:part_overrides]
  NxTest.assert_equal(out, again)
end

NxTest.test('K1: override PREZIJE round-trip configu (kopia korpusu, dedup, rebuild)') do
  # Kopia skrinky aj kazdy rebuild idu cez `config_to_params` -> `normalize`.
  # Keby tade smer vypadol, kopia by sa objednala s inou kresbou nez original.
  cfg = { 'type' => 'lower', 'part_overrides' => {
    'front:F1/wing:single' => { 'grain_direction' => 'width' }
  } }
  2.times do
    out = K1CB.normalize(K1CB.config_to_params(cfg))[:part_overrides]
    NxTest.assert_equal('width', out['front:F1/wing:single']['grain_direction'])
    cfg = cfg.merge('part_overrides' => out)
  end
end

# ---------------------------------------------------------------------------
# 4) resolve_part nad KATALOGOM — co sa naozaj zapise do snapshotu dielca
# ---------------------------------------------------------------------------

NxTest.test('K1: resolve_part materializuje efektivny smer do snapshotu dielca') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  k1_with_catalog(K1_SHEETS, K1_EDGES) do
    pd = k1_pd
    # dedenie
    r = K1CB.resolve_part(pd, 'DUB18', 'DUB18', 'DUB18', {})
    NxTest.assert_equal('length', r[:grain_direction])
    # override na priecnu
    ov = { 'zone:Z1/shelf:1' => { 'grain_direction' => 'width' } }
    r2 = K1CB.resolve_part(pd, 'DUB18', 'DUB18', 'DUB18', ov)
    NxTest.assert_equal('width', r2[:grain_direction])
    NxTest.assert_equal('DUB18', r2[:material_id], 'smer sa nedotyka materialu')
    # opacny pripad: material s kresbou po sirke + override na pozdlznu
    r3 = K1CB.resolve_part(pd, 'DUB_W18', 'DUB_W18', 'DUB_W18',
                           { 'zone:Z1/shelf:1' => { 'grain_direction' => 'length' } })
    NxTest.assert_equal('length', r3[:grain_direction])
  end
end

NxTest.test('K1: STALE override — jednofarebny aj UNI material smer IGNORUJU, nemazu ho') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  k1_with_catalog(K1_SHEETS, K1_EDGES) do
    pd = k1_pd
    ov = { 'zone:Z1/shelf:1' => { 'grain_direction' => 'width' } }
    %w[BIELA18 UNI18].each do |mat|
      r = K1CB.resolve_part(pd, mat, mat, mat, ov)
      NxTest.assert_equal('none', r[:grain_direction], "#{mat}: neucinny override")
    end
    # ZAZNAM OSTAVA v configu — po navrate na dekorovy material znova plati.
    kept = K1CB.norm_overrides(ov)
    NxTest.assert_equal('width', kept['zone:Z1/shelf:1']['grain_direction'],
                        'override sa pri materiali bez smeru NEMAZE')
    back = K1CB.resolve_part(pd, 'DUB18', 'DUB18', 'DUB18', kept)
    NxTest.assert_equal('width', back[:grain_direction], 'a s dekorom znova ozije')
  end
end

NxTest.test('K1: STVORCOVY dielec — smer je udaj, nie odvodenie z rozmerov') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  k1_with_catalog(K1_SHEETS, K1_EDGES) do
    pd = k1_pd(length: 500.0, width: 500.0)
    r = K1CB.resolve_part(pd, 'DUB18', 'DUB18', 'DUB18',
                          { 'zone:Z1/shelf:1' => { 'grain_direction' => 'width' } })
    NxTest.assert_equal('width', r[:grain_direction],
                        'pri stvorci sa smer z rozmerov ODVODIT NEDA — musi to byt udaj')
  end
end

# ---------------------------------------------------------------------------
# 5) VYSTUPY — ziadny dvojity swap (BOM <-> VEPO <-> narez <-> ABS bm)
# ---------------------------------------------------------------------------

# Riadok presne v tvare, aky vyrobi `Bom.record` zo snapshotu dielca:
# GEOMETRIA 2000×250, olep na jednej POZDLZNEJ hrane (L1).
def k1_row(grain)
  K1BOM.record({ 'length' => 2000.0, 'width' => 250.0, 'thickness' => 18.0, 'quantity' => 2,
                 'material_id' => 'DUB18', 'grain_direction' => grain,
                 'edges' => { 'L1' => 'ABS_DUB_10', 'L2' => nil, 'W1' => nil, 'W2' => nil } },
               owner_id: 'CAB-1', name: 'Blenda', part_key: 'front:F1/wing:single', role: 'front_door')
end

NxTest.test('K1: BOM drzi GEOMETRIU + smer; rotaciu robi az VEPO (jeden jediny swap)') do
  row = k1_row('width')
  NxTest.assert_close(2000.0, row['length'], 0.01, 'snapshot ostava geometricky')
  NxTest.assert_close(250.0, row['width'])
  NxTest.assert_equal('width', row['grain_direction'])

  o = K1VEPO.oriented(row)
  NxTest.assert_close(250.0, o['length'], 0.01, 'VEPO chce dlzku POZDLZ dekoru')
  NxTest.assert_close(2000.0, o['width'])
  NxTest.assert_equal('ABS_DUB_10', o['edges']['W1'], 'olep presiel na PRIECNU dvojicu')
  NxTest.assert_equal(nil, o['edges']['L1'])
  # Druhy prechod uz NEROTUJE (grain je po prvom swape 'length') — poistka
  # proti dvojitemu swapu, keby niekto zaradil `oriented` do retaze dvakrat.
  o2 = K1VEPO.oriented(o)
  NxTest.assert_close(250.0, o2['length'], 0.01)
  NxTest.assert_close(2000.0, o2['width'])
end

NxTest.test('K1: ABS bezne metre su INVARIANTNE voci otoceniu (krizova kontrola)') do
  # Fyzicka paska je jedna a ta ista 2000 mm hrana. Ked by niekde vznikol
  # druhy swap, kusovnik a VEPO by si prestali sediet a nakup ABS by bol zly.
  bm_plain = K1BOM.compute(records: [k1_row('length')])[:edging]
  bm_turn  = K1BOM.compute(records: [k1_row('width')])[:edging]
  NxTest.assert_equal(1, bm_plain.length)
  NxTest.assert_close(4.0, bm_plain.first['bm'], 0.001, '2 ks × 2000 mm')
  NxTest.assert_close(bm_plain.first['bm'], bm_turn.first['bm'], 0.001,
                      'otocenie kresby NESMIE zmenit spotrebu ABS')
  # a to iste z pohladu VEPO riadku (tam je paska na dvojici W)
  o = K1VEPO.oriented(k1_row('width'))
  NxTest.assert_close(2.0, o['width'] / 1000.0, 0.001)
  NxTest.assert_close(bm_turn.first['bm'], (o['width'] / 1000.0) * o['quantity'], 0.001,
                      'ta ista hrana, ta ista dlzka — len iny nazov dvojice')
end

NxTest.test('K1: kusovnik NEZLUCI dielec s opacnou kresbou (row_key ostal nezmeneny)') do
  rows = K1BOM.compute(records: [k1_row('length'), k1_row('width')])[:rows]
  NxTest.assert_equal(2, rows.length,
                      'vyrobne su to ine dielce — zlucenie by objednalo polovicu naopak')
  NxTest.assert_equal(%w[length width].sort, rows.map { |r| r['grain_direction'] }.sort)
end

NxTest.test('K1: kontrola narezu — otocena kresba dielec z platne VYHODI (RED)') do
  sheets = { 'DUB18' => { 'material_id' => 'DUB18', 'thickness' => 18.0,
                          'sheet_size' => [2800.0, 2070.0] } }
  base = { 'length' => 2500.0, 'width' => 250.0, 'thickness' => 18.0, 'quantity' => 1,
           'material_id' => 'DUB18', 'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
           'name' => 'Blenda', 'owner_id' => 'CAB-1', 'part_key' => 'front:F1/wing:single',
           'role' => 'front_door' }
  ok = K1VAL.run({ records: [base.merge('grain_direction' => 'length')] }, sheets: sheets)
  bad = K1VAL.run({ records: [base.merge('grain_direction' => 'width')] }, sheets: sheets)
  NxTest.assert_equal(0, ok['items'].count { |i| i['category'] == K1VAL::CAT_OVERSIZE },
                      'pozdlz kresby sa 2500 mm na platnu 2800 zmesti')
  over = bad['items'].select { |i| i['category'] == K1VAL::CAT_OVERSIZE }
  NxTest.assert_equal(1, over.length,
                      'naprieč kresbou by dielec potreboval 2500 mm v smere 2070 — RED')
  NxTest.assert_equal(K1VAL::RED, over.first['severity'])
  # Kontrola pouziva TU ISTU logiku ako VEPO — ziadny vlastny druhy swap.
  NxTest.assert(K1VAL.fits_on_sheet?(2500.0, 250.0, 'length', 2800.0, 2070.0))
  NxTest.refute(K1VAL.fits_on_sheet?(2500.0, 250.0, 'width', 2800.0, 2070.0))
end

NxTest.test('K1: DUPLAK 36 mm — otocenie nedotkne vazbu na zdrojovy material') do
  # Duplak (dva zlepene 18 mm dielce) nesie v snapshote `material_source` a ta
  # patri do kluca riadku. Otocenie kresby ju nesmie zmenit ani zhodit — nakupny
  # prepocet plochy na ZDROJOVY material bezi dalej.
  cfg = { 'length' => 2000.0, 'width' => 250.0, 'thickness' => 36.0, 'quantity' => 1,
          'material_id' => 'DUB18_DUPLAK', 'grain_direction' => 'width',
          'material_source' => { 'material_id' => 'DUB18', 'multiplier' => 2 },
          'edges' => { 'L1' => 'ABS_DUB_10', 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  r = K1BOM.record(cfg, owner_id: 'CAB-1', name: 'Blenda 36',
                   part_key: 'front:F1/wing:single', role: 'front_door')
  NxTest.assert_equal({ 'material_id' => 'DUB18', 'multiplier' => 2 }, r['material_source'])
  o = K1VEPO.oriented(r)
  NxTest.assert_close(250.0, o['length'], 0.01)
  NxTest.assert_equal(36, K1VEPO.commercial_thickness(o['thickness']), 'obchodna hrubka ostava 36')
  NxTest.assert_equal({ 'material_id' => 'DUB18', 'multiplier' => 2 }, o['material_source'])
end

NxTest.test('K1: ODPOJENY dielec drzi SVOJ snapshot — katalog uz nema slovo') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  # Dielec vytiahnuty z korpusu na najvyssiu uroven sa uz neprestavuje.
  # `Bom.record` preto MUSI citat smer z jeho configu, nie z materialu —
  # inak by sa stara zakazka po zmene katalogu objednala inak, nez sa vyrobila.
  k1_with_catalog(K1_SHEETS, K1_EDGES) do
    cfg = { 'length' => 2000.0, 'width' => 250.0, 'thickness' => 18.0, 'quantity' => 1,
            'material_id' => 'DUB18', 'grain_direction' => 'width',
            'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
    r = K1BOM.record(cfg, owner_id: 'CAB-1', name: 'Blenda',
                     part_key: 'front:F1/wing:single', role: 'front_door')
    NxTest.assert_equal('width', r['grain_direction'],
                        'snapshot je autorita — katalogovy grain „length" ho neprebije')
  end
end

# ---------------------------------------------------------------------------
# 6) ZAPISOVA CESTA PANELA — enum guard a jedna prestavba (staticka kontrola)
# ---------------------------------------------------------------------------

K1_PARTS_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts.rb'),
                        encoding: 'UTF-8')
K1_PANEL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
K1_PAYLOADS_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads.rb'),
                           encoding: 'UTF-8')
K1_PART_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'part_card.js'),
                        encoding: 'UTF-8')
K1_HANDLER  = K1_PARTS_RB[/def handle_set_part_grain\b.*?\n        end\n/m].to_s

NxTest.test('K1: JS posiela PRESNE ten sentinel dedenia, aky server prijima (Codex #185 P1)') do
  # Segment pouziva UI token `inherit`, zapisova cesta sentinel `__inherit__`.
  # Keby sa rozisli, klik na „Podľa materiálu" by server odmietol ako neznamy
  # smer (enum guard) a override by aj s rotaciou vo VEPO TICHO ostal — chyba
  # by sa prejavila az na objednavke. Zamykame OBE strany naraz.
  wire = K1_PART_JS[/function nxGrainWire.*?\n  \}|function nxGrainWire[^\n]*\n/m].to_s
  NxTest.assert(wire.include?("'__inherit__'"), 'JS preklada `inherit` na sentinel `__inherit__`')
  send_body = K1_PART_JS[/function onPartGrain.*?\n  \}/m].to_s
  NxTest.assert(send_body.include?('grain: nxGrainWire(v)'),
                'zapis ide cez preklad, nie surovym UI tokenom')
  NxTest.assert(K1_HANDLER.include?("raw == '__inherit__'"),
                'server ten isty sentinel prijima')
  NxTest.refute(K1_HANDLER.include?("raw == 'inherit'"),
                'server NEMA druhy, tichy sentinel — jedna hodnota, jedno miesto')
end

NxTest.test('K1: karta cita EFEKTIVNY smer zo SNAPSHOTU, katalog len prospektivne (Codex #185 P1)') do
  # Katalog sa medzi prestavbami meni (zmazany material, prepisany `grain`,
  # .skp z ineho stroja). Keby karta pocitala vysledok z katalogu, tvrdila by
  # iny smer a iny vyrobny rozmer, nez s akym dielec ide do VEPO.
  body = K1_PAYLOADS_RB[/def part_grain_payload\b.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'payload segmentu sa nasiel')
  NxTest.assert(body.include?("snapshot = norm_grain_value(cfg['grain_direction'])"),
                'vysledok sa berie zo snapshotu dielca')
  NxTest.assert(body.include?("'grain_effective' => snapshot"),
                'efektivny smer = snapshot, nie dopocet z katalogu')
  NxTest.assert(body.include?("'grain_pending' => pending"),
                'prospektivny vysledok je SAMOSTATNY udaj, nezamiena sa s efektivnym')
  NxTest.assert(body.include?('CabinetBuilder.effective_grain(sheet, override)'),
                'prospektivny vysledok pocita TA ISTA funkcia ako builder (ziadny druhy vypocet)')
  hint = K1_PAYLOADS_RB[/def grain_hint\b.*?\n        end\n/m].to_s
  NxTest.assert(hint.include?('return nil if pending == snapshot'),
                'bez rozporu sa hint nezobrazuje (vertikalny priestor)')
  NxTest.assert(hint.include?('po najbližšej prestavbe'),
                'rozpor snapshot vs. katalog karta POVIE, nezamlci ho')
end

NxTest.test('K1: zapisova cesta ma enum guard, identity guard a JEDNU prestavbu') do
  NxTest.assert(!K1_HANDLER.empty?, 'handler smeru dekoru existuje')
  NxTest.assert(K1_PANEL_RB.include?("cb(dlg, 'set_part_grain')"), 'callback je zaregistrovany')
  NxTest.assert(K1_HANDLER.include?('CabinetBuilder::GRAIN_OVERRIDES.include?(raw)'),
                'enum sa overuje proti JEDINEJ konstante buildera')
  NxTest.assert(K1_HANDLER.include?('zápis odmietnutý') || K1_HANDLER.include?('zapis odmietnuty'),
                'neznama hodnota sa ODMIETNE, nikdy ticho neprelozi')
  NxTest.assert(K1_HANDLER.include?('stale_cabinet_echo?'), 'echo z ineho korpusu sa zahodi')
  NxTest.assert(K1_HANDLER.include?('rebuild_focus_part'),
                'zapis ide JEDNOU prestavbou = jeden krok Spat (vzor D-35)')
  NxTest.assert(K1_HANDLER.scan(/rebuild_focus_part|CabinetBuilder\.rebuild/).length == 1,
                'nikdy slucka viacerych prestavieb')
end

NxTest.test('K1: „Použiť na podobné" smer dekoru NEPRENASA (prenasa sa len olep)') do
  apply = K1_PARTS_RB[/def handle_apply_edges_similar\b.*?\n        end\n/m].to_s
  NxTest.assert(!apply.empty?, 'handler sa nasiel')
  NxTest.refute(apply.include?('grain_direction'),
                'hromadne otocenie kresby by ticho prekreslilo celu zakazku')
  NxTest.assert(apply.include?("rec.delete('edge_warnings')"), 'olep sa prenasa dalej ako doteraz')
end
