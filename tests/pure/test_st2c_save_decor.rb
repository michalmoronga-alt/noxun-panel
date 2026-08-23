# frozen_string_literal: true
# ŠT-2c PR 2c-2a — atomicka zapisova cesta `Materials.save_decor` (D-69 editor).
#
# Preco su to testy a nie klikanie: KATALOG SU CENY REALNYCH OBJEDNAVOK.
# Kazdy test nizsie zabija KONKRETNU branu — ked ju z kodu odstranis, test
# padne (mutacna kontrola, poznamka „zabija:" v nazve sekcie):
#
#   1  allowlist        — server-owned polia (price_checked_at, uni*, source_*,
#                         group_id/color/family na riadku) sa STRHAVAJU
#   2  base_rev         — zapis nad starsim katalogom = :stale
#   3  row_rev          — cudzia zmena RIADKU = :stale
#   4  validate-all     — vsetky chyby NARAZ, ziadny fail-fast
#   5  identita         — riadok s ID meni LEN neidentitne polia
#   6  ziadne mazanie   — zaznam, ktory vo formulari nie je, PREZIJE
#   7  price_checked_at — rucna zmena ceny rusi datum overenia
#   8  atomicita        — chyba v POSLEDNOM riadku = ZIADNY zapis
#                         (dokaz: `catalog_revision` pred a po je ROVNAKA)
#   9  read-only        — nudzovy rezim mutaciu odmietne
#  10  skupinove polia  — premenovanie + vyrobca + farba v JEDNEJ transakcii
#  11  kod+dodavatel    — duplicita vyzaduje `allow_duplicate_code`
require_relative '../helper' unless defined?(NxTest)

SDM = Noxun::Engine::Materials

# --- seed: jeden realny dekor (2 dosky + 1 paska) ----------------------------
def sd_seed!
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  ok, res = SDM.add_decor_batch_v3(
    'decor' => 'H3303', 'decor_name' => 'Dub Halifax', 'manufacturer' => 'Egger',
    'type' => 'DTDL', 'grain' => 'length', 'color' => [200, 180, 150],
    'sheet_variants' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST10' },
                         { 'type' => 'DTDL', 'thickness' => 36.0, 'structure' => 'ST10' }],
    'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST10' }]
  )
  raise "seed H3303 zlyhal: #{res.inspect}" unless ok
  res
end

def sd_gid
  SDM.sheets.find { |s| s['decor'] == 'H3303' }['group_id']
end

def sd_group_sheets(gid)
  SDM.sheets.select { |s| s['group_id'] == gid }.sort_by { |s| s['thickness'].to_f }
end

def sd_group_edges(gid)
  SDM.edges.select { |a| a['group_id'] == gid }
end

# Riadky presne v tvare, aky posiela editor (skryte id/rev + viditelne stlpce).
def sd_sheet_row(s, over = {})
  { 'material_id' => s['material_id'], 'row_rev' => SDM.record_rev(s),
    'type' => s['type'], 'thickness' => SDM.fmt_mm(s['thickness']),
    'sheet_size' => s['sheet_size'] ? s['sheet_size'].map { |x| SDM.fmt_mm(x) }.join('×') : '',
    'code' => s['code'].to_s, 'supplier' => s['supplier'].to_s,
    'price_per_m2' => s['price_per_m2'].nil? ? '' : SDM.fmt_mm(s['price_per_m2']) }.merge(over)
end

def sd_edge_row(a, over = {})
  { 'abs_id' => a['abs_id'], 'row_rev' => SDM.record_rev(a),
    'width' => SDM.fmt_mm(a['width']), 'thickness' => SDM.fmt_mm(a['thickness']),
    'code' => a['code'].to_s, 'supplier' => a['supplier'].to_s,
    'price_per_bm' => a['price_per_bm'].nil? ? '' : SDM.fmt_mm(a['price_per_bm']) }.merge(over)
end

def sd_payload(gid, over = {})
  { 'mode' => 'edit', 'group_id' => gid, 'base_rev' => SDM.catalog_revision,
    'catalog_schema' => SDM::SCHEMA_CURRENT,
    'decor' => 'H3303', 'decor_name' => 'Dub Halifax', 'manufacturer' => 'Egger',
    'sheets' => sd_group_sheets(gid).map { |s| sd_sheet_row(s) },
    'edges' => sd_group_edges(gid).map { |a| sd_edge_row(a) } }.merge(over)
end

def sd_headless!
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
end

# ---------------------------------------------------------------------------
# 1) ALLOWLIST — zabija: SAVE_DECOR_KEYS / SAVE_DECOR_*_KEYS
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 1): server-owned polia sa STRHAVAJU — datum overenia, UNI, duplak, farba riadku') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  s18 = sd_group_sheets(gid).first
  # datum overenia zapisuje VYHRADNE server (Demos apply) — simulujeme stav po nom
  NxTest.assert(SDM.upsert_sheet(s18.merge('price_per_m2' => 20.0,
                                           'price_checked_at' => '2026-08-09T10:00:00Z')))
  s18 = SDM.sheet(s18['material_id'])
  rows = sd_group_sheets(gid).map do |s|
    next sd_sheet_row(s) unless s['material_id'] == s18['material_id']
    sd_sheet_row(s, 'code' => 'H3303-18',
                    # PODVRHNUTE server-owned polia — nesmu prejst ani jedno
                    'price_checked_at' => '2099-01-01T00:00:00Z',
                    'uni' => true, 'uni_role' => 'body',
                    'source_material_id' => 'K009_PW_DTDL_18', 'source_multiplier' => 2,
                    'color' => [1, 2, 3], 'family' => 'PODVRH', 'group_id' => 'GRP-cudzia',
                    'decor' => 'INY', 'manufacturer' => 'INY')
  end
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows))
  NxTest.assert_equal(:ok, st, info.inspect)
  after = SDM.sheet(s18['material_id'])
  NxTest.assert_equal('H3303-18', after['code'], 'povolene pole preslo')
  NxTest.refute(after.key?('price_checked_at'),
                'datum overenia padol so zmenou kodu (bod 9) — a NIE je to hodnota z klienta')
  NxTest.refute(after['price_checked_at'].to_s.start_with?('2099'),
                'podvrhnuty datum overenia sa NIKDY nezapise')
  NxTest.refute(after['uni'], 'UNI priznak z klienta neprejde')
  NxTest.refute(after.key?('source_material_id'), 'duplakova vazba z klienta neprejde')
  NxTest.assert_equal([200, 180, 150], after['color'], 'farba je vlastnost SKUPINY, nie riadku')
  NxTest.assert_equal(gid, after['group_id'], 'kotva skupiny sa riadkom nepresuva')
  NxTest.assert_equal('H3303', after['decor'], 'dekor riadok nemeni')
  NxTest.assert_equal('Egger', after['manufacturer'], 'vyrobcu riadok nemeni')
end

# ---------------------------------------------------------------------------
# 2) + 3) BASELINE — zabija: base_rev guard a row_rev guard
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 4): stary base_rev = :stale a ZIADNY zapis') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |s| sd_sheet_row(s, 'code' => 'X1') }
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'base_rev' => 'stary123'))
  NxTest.assert_equal(:stale, st)
  NxTest.assert(info['message'].to_s.include?('zmenil'), info.inspect)
  NxTest.assert(sd_group_sheets(gid).none? { |s| s['code'] == 'X1' }, 'nic sa nezapisalo')
  # prazdny base_rev sa NEPREPUSTA (na rozdiel od legacy revision_ok?) — editor
  # ho zmrazuje pri otvoreni, takze prazdny znamena rozbity klient.
  st2, = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'base_rev' => ''))
  NxTest.assert_equal(:stale, st2, 'prazdny baseline neotvara zadne vratka')
end

NxTest.test('save_decor (bod 4): cudzia zmena RIADKU = :stale (row_rev), aj ked base_rev sedi') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  sheets = sd_group_sheets(gid)
  stale_row = sd_sheet_row(sheets.first, 'row_rev' => 'cudzirev', 'code' => 'X2')
  payload = sd_payload(gid, 'sheets' => [stale_row] + sheets.drop(1).map { |s| sd_sheet_row(s) })
  st, info = SDM.save_decor(payload)
  NxTest.assert_equal(:stale, st)
  NxTest.assert_equal(sheets.first['material_id'], info['id'])
  NxTest.assert(sd_group_sheets(gid).none? { |s| s['code'] == 'X2' }, 'nic sa nezapisalo')
end

NxTest.test('save_decor (bod 10): zaznam, ktory medzitym zmizol, = :conflict') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |s| sd_sheet_row(s) }
  rows << { 'material_id' => 'NEEXISTUJE_18', 'row_rev' => 'x', 'type' => 'DTDL',
            'thickness' => '18', 'code' => 'Y' }
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows))
  NxTest.assert_equal(:conflict, st)
  NxTest.assert_equal('NEEXISTUJE_18', info['id'])
end

# ---------------------------------------------------------------------------
# 4) VALIDATE-ALL — zabija: akumulator `errors` (fail-fast by vratil 1 chybu)
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 5): vsetky chyby prídu NARAZ, s riadkom aj polom') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  sheets = sd_group_sheets(gid)
  rows = [sd_sheet_row(sheets[0], 'thickness' => '20'),      # identita: ina hrubka
          sd_sheet_row(sheets[1], 'price_per_m2' => 'abc')]  # cena nie je cislo
  edges = [sd_edge_row(sd_group_edges(gid).first, 'width' => '30')] # identita: ina sirka
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'edges' => edges,
                                            'decor' => '')) # + skupinove pole
  NxTest.assert_equal(:invalid, st)
  errs = info['errors']
  NxTest.assert_equal(4, errs.size, "ocakavane 4 chyby naraz: #{errs.inspect}")
  NxTest.assert(errs.any? { |e| e['row'].nil? && e['field'] == 'decor' }, 'skupinove pole')
  NxTest.assert(errs.any? { |e| e['row'] == 'sheets:0' && e['field'] == 'thickness' }, 'riadok 0')
  NxTest.assert(errs.any? { |e| e['row'] == 'sheets:1' }, 'riadok 1')
  NxTest.assert(errs.any? { |e| e['row'] == 'edges:0' && e['field'] == 'width' }, 'ABS riadok')
  NxTest.assert(errs.all? { |e| e['msg'].to_s.length > 5 }, 'kazda chyba ma vetu pre cloveka')
end

# ---------------------------------------------------------------------------
# 5) IDENTITA — zabija: identitne guardy v save_decor_edit_sheet/edge
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 7): riadok s ID nemeni typ, hrubku ani strukturu') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  s = sd_group_sheets(gid).first
  { 'type' => 'MDF', 'thickness' => '19', 'structure' => 'ST38' }.each do |field, value|
    rows = sd_group_sheets(gid).map do |x|
      x['material_id'] == s['material_id'] ? sd_sheet_row(x, field => value) : sd_sheet_row(x)
    end
    st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows))
    NxTest.assert_equal(:invalid, st, "#{field} musi byt nemenne")
    err = info['errors'].find { |e| e['field'] == field }
    NxTest.assert(err, "chyba patri k polu #{field}: #{info.inspect}")
    NxTest.assert(err['msg'].include?('variant'), "hlaska hovori NAVOD: #{err['msg']}")
  end
  fresh = SDM.sheet(s['material_id'])
  NxTest.assert_equal(s['type'], fresh['type'], 'zaznam ostal nedotknuty')
  NxTest.assert_close(s['thickness'], fresh['thickness'], 0.001)
end

NxTest.test('save_decor (bod 7): pri type s formatom v identite je format NEMENNY, pri DTDL nie') do
  sd_headless!
  sd_seed!
  ok, res = SDM.add_decor_batch_v3(
    'decor' => 'F206', 'manufacturer' => 'Egger', 'type' => 'PD', 'grain' => 'length',
    'sheet_variants' => [{ 'type' => 'PD', 'thickness' => 38.0, 'structure' => 'ST9',
                           'sheet_size' => [4100.0, 600.0] }],
    'edge_variants' => []
  )
  NxTest.assert(ok, res.inspect)
  pd = SDM.sheet(res['sheets'].first)
  gid = pd['group_id']
  st, info = SDM.save_decor(sd_payload(gid, 'decor' => 'F206', 'decor_name' => '',
                                            'sheets' => [sd_sheet_row(pd, 'sheet_size' => '4100×920')],
                                            'edges' => []))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].first['msg'].include?('Formát'), info.inspect)
  NxTest.assert_equal([4100.0, 600.0], SDM.sheet(pd['material_id'])['sheet_size'], 'format ostal')

  # DTDL — format NIE JE identita, dopisat sa smie
  gid2 = sd_gid
  s = sd_group_sheets(gid2).first
  rows = sd_group_sheets(gid2).map do |x|
    x['material_id'] == s['material_id'] ? sd_sheet_row(x, 'sheet_size' => '2800×2070') : sd_sheet_row(x)
  end
  st2, info2 = SDM.save_decor(sd_payload(gid2, 'sheets' => rows))
  NxTest.assert_equal(:ok, st2, info2.inspect)
  NxTest.assert_equal([2800.0, 2070.0], SDM.sheet(s['material_id'])['sheet_size'])
end

# ---------------------------------------------------------------------------
# 6) ZIADNE MAZANIE — zabija: absencia „co nie je vo formulari, zmaz"
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 7): zaznam MIMO formulara sa NEMAZE') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  sheets = sd_group_sheets(gid)
  edges = sd_group_edges(gid)
  # formular nesie LEN prvu dosku a ziadnu pasku
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => [sd_sheet_row(sheets.first, 'code' => 'ONLY')],
                                            'edges' => []))
  NxTest.assert_equal(:ok, st, info.inspect)
  NxTest.assert_equal(sheets.size, sd_group_sheets(gid).size, 'druha doska PREZILA')
  NxTest.assert_equal(edges.size, sd_group_edges(gid).size, 'paska PREZILA')
  NxTest.assert(SDM.edge(edges.first['abs_id']), 'paska ma stale svoje ID')
end

# ---------------------------------------------------------------------------
# 7) CENA vs DATUM OVERENIA — zabija: bod 9 v save_decor_edit_sheet/edge
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 9): rucna zmena ceny rusi price_checked_at (doska aj paska)') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  s = sd_group_sheets(gid).first
  a = sd_group_edges(gid).first
  NxTest.assert(SDM.upsert_sheet(s.merge('price_per_m2' => 20.0,
                                         'demos_url' => 'https://www.demos-trade.sk/x/',
                                         'price_checked_at' => '2026-08-09T10:00:00Z')))
  NxTest.assert(SDM.upsert_edge(a.merge('price_per_bm' => 1.2,
                                        'price_checked_at' => '2026-08-09T10:00:00Z')))
  s = SDM.sheet(s['material_id'])
  a = SDM.edge(a['abs_id'])
  rows = sd_group_sheets(gid).map do |x|
    x['material_id'] == s['material_id'] ? sd_sheet_row(x, 'price_per_m2' => '22,50') : sd_sheet_row(x)
  end
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows,
                                            'edges' => [sd_edge_row(a, 'price_per_bm' => '1,45')]))
  NxTest.assert_equal(:ok, st, info.inspect)
  after_s = SDM.sheet(s['material_id'])
  after_a = SDM.edge(a['abs_id'])
  NxTest.assert_close(22.5, after_s['price_per_m2'], 0.001)
  NxTest.refute(after_s.key?('price_checked_at'), 'doska: datum overenia padol')
  NxTest.assert_equal('https://www.demos-trade.sk/x/', after_s['demos_url'], 'vazba na produkt OSTAVA')
  NxTest.assert_close(1.45, after_a['price_per_bm'], 0.001)
  NxTest.refute(after_a.key?('price_checked_at'), 'ABS: datum overenia padol')
end

NxTest.test('save_decor (bod 9): nedotknuta cena/kod/dodavatel datum overenia NERUSIA') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  s = sd_group_sheets(gid).first
  NxTest.assert(SDM.upsert_sheet(s.merge('price_per_m2' => 20.0, 'code' => 'K1',
                                         'price_checked_at' => '2026-08-09T10:00:00Z')))
  # meni sa LEN format platne (pri DTDL nie je identita ani nakupny udaj)
  rows = sd_group_sheets(gid).map do |x|
    x['material_id'] == s['material_id'] ? sd_sheet_row(x, 'sheet_size' => '2800×2070') : sd_sheet_row(x)
  end
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows))
  NxTest.assert_equal(:ok, st, info.inspect)
  after = SDM.sheet(s['material_id'])
  NxTest.assert_equal([2800.0, 2070.0], after['sheet_size'])
  NxTest.assert_equal('2026-08-09T10:00:00Z', after['price_checked_at'],
                      'zmena formatu datum overenia nerusi')
end

# --- review #3: kod a dodavatel rusia datum overenia rovnako ako cena --------

NxTest.test('save_decor (review #3): zmena KODU aj DODAVATELA rusi price_checked_at') do
  sd_headless!
  [['code', 'INY_KOD'], ['supplier', 'Iný dodávateľ']].each do |field, value|
    sd_seed!
    gid = sd_gid
    s = sd_group_sheets(gid).first
    a = sd_group_edges(gid).first
    stamp = '2026-08-09T10:00:00Z'
    NxTest.assert(SDM.upsert_sheet(s.merge('code' => 'K1', 'supplier' => 'Demos',
                                           'price_per_m2' => 20.0, 'price_checked_at' => stamp)))
    NxTest.assert(SDM.upsert_edge(a.merge('code' => 'E1', 'supplier' => 'Demos',
                                          'price_per_bm' => 1.2, 'price_checked_at' => stamp)))
    s = SDM.sheet(s['material_id'])
    a = SDM.edge(a['abs_id'])
    rows = sd_group_sheets(gid).map do |x|
      x['material_id'] == s['material_id'] ? sd_sheet_row(x, field => value) : sd_sheet_row(x)
    end
    st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows,
                                              'edges' => [sd_edge_row(a, field => value)],
                                              'allow_duplicate_code' => true))
    NxTest.assert_equal(:ok, st, info.inspect)
    NxTest.refute(SDM.sheet(s['material_id']).key?('price_checked_at'),
                  "doska: zmena #{field} rusi datum overenia")
    NxTest.refute(SDM.edge(a['abs_id']).key?('price_checked_at'),
                  "ABS: zmena #{field} rusi datum overenia")
  end
end

# ---------------------------------------------------------------------------
# 8) ATOMICITA — zabija: „return pred zapisom pri chybe" (dokaz revizie)
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 5+10): chyba v POSLEDNOM riadku = ZIADNY zapis (revizia sa nehne)') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  sheets = sd_group_sheets(gid)
  edges = sd_group_edges(gid)
  rev_before = SDM.catalog_revision
  rows = [sd_sheet_row(sheets[0], 'code' => 'PRVY', 'price_per_m2' => '19'),
          sd_sheet_row(sheets[1], 'code' => 'DRUHY', 'price_per_m2' => '25')]
  bad_edge = sd_edge_row(edges.first, 'price_per_bm' => '-5') # zaporna cena = chyba
  st, = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'edges' => [bad_edge],
                                       'decor' => 'H3303NOVY', 'manufacturer' => 'Kronospan'))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert_equal(rev_before, SDM.catalog_revision,
                      'ATOMICITA: revizia katalogu sa NEHLA — nezapisalo sa NIC')
  NxTest.assert(sd_group_sheets(gid).none? { |s| s['code'] == 'PRVY' }, 'prvy riadok sa nezapisal')
  NxTest.assert_equal('H3303', sd_group_sheets(gid).first['decor'], 'ani premenovanie skupiny')
  NxTest.assert_equal('Egger', sd_group_sheets(gid).first['manufacturer'], 'ani vyrobca')
end

# ---------------------------------------------------------------------------
# 9) READ-ONLY — zabija: brana catalog_read_only? pred zamkom
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 3): read-only katalog mutaciu ODMIETNE') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |s| sd_sheet_row(s, 'code' => 'RO') }
  payload = sd_payload(gid, 'sheets' => rows)
  SDM.instance_variable_set(:@catalog_state, :read_only)
  SDM.instance_variable_set(:@catalog_state_reason, 'test')
  begin
    st, info = SDM.save_decor(payload)
    NxTest.assert_equal(:catalog_read_only, st)
    NxTest.assert(info['message'].to_s.length > 5)
  ensure
    SDM.reset_catalog_state!
  end
  NxTest.assert(sd_group_sheets(gid).none? { |s| s['code'] == 'RO' }, 'nic sa nezapisalo')
end

NxTest.test('save_decor (bod 3): stary klient (nizsia schema) nezapise') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |s| sd_sheet_row(s, 'code' => 'STARY') }
  st, = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'catalog_schema' => 1))
  NxTest.assert_equal(:stale, st)
  NxTest.assert(sd_group_sheets(gid).none? { |s| s['code'] == 'STARY' }, 'nic sa nezapisalo')
end

# ---------------------------------------------------------------------------
# 10) SKUPINOVE POLIA — zabija: save_decor_apply_group! a jeho guardy
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 8): premenovanie + vyrobca + farba idú CELEJ skupine v jednom zapise') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |s| sd_sheet_row(s) }
  edges = sd_group_edges(gid).map { |a| sd_edge_row(a) }
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'edges' => edges,
                                            'decor' => 'H3304', 'decor_name' => 'Dub Halifax tabak',
                                            'manufacturer' => 'Kronospan', 'color' => '#102030'))
  NxTest.assert_equal(:ok, st, info.inspect)
  after_sheets = SDM.sheets.select { |s| s['group_id'] == gid }
  after_edges = SDM.edges.select { |a| a['group_id'] == gid }
  NxTest.assert(after_sheets.all? { |s| s['decor'] == 'H3304' }, 'dosky premenovane')
  NxTest.assert(after_edges.all? { |a| a['decor'] == 'H3304' }, 'PASKY premenovane tiez')
  NxTest.assert(after_sheets.all? { |s| s['manufacturer'] == 'Kronospan' }, 'vyrobca')
  NxTest.assert(after_sheets.all? { |s| s['family'] == 'Kronospan H3304' }, 'family prepocitane')
  NxTest.assert(after_sheets.all? { |s| s['decor_name'] == 'Dub Halifax tabak' }, 'nazov skupiny')
  NxTest.assert((after_sheets + after_edges).all? { |r| r['color'] == [16, 32, 48] },
                'farba prefarbila dosky AJ pasky')
  NxTest.assert_equal(gid, after_sheets.first['group_id'], 'group_id sa premenovanim NEMENI')
end

NxTest.test('save_decor (bod 8): kolizia obchodnej identity skupiny sa odmietne') do
  sd_headless!
  sd_seed!
  ok, = SDM.add_decor_batch_v3('decor' => 'H1180', 'manufacturer' => 'Egger', 'type' => 'DTDL',
                               'grain' => 'length',
                               'sheet_variants' => [{ 'type' => 'DTDL', 'thickness' => 18.0,
                                                      'structure' => 'ST37' }],
                               'edge_variants' => [])
  NxTest.assert(ok)
  gid = sd_gid
  st, info = SDM.save_decor(sd_payload(gid, 'decor' => 'H1180'))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['field'] == 'decor' }, info.inspect)
  NxTest.assert_equal('H3303', sd_group_sheets(gid).first['decor'], 'nic sa nepremenovalo')
  # near-match (rozdiel len zapisom) je rovnaka kolizia
  st2, info2 = SDM.save_decor(sd_payload(gid, 'decor' => 'h 1180'))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['errors'].first['msg'].include?('zápisom'), info2.inspect)
end

NxTest.test('save_decor (bod 8): prazdny vyrobca sa nevymaze nechtiac; UNI farba je zamknuta') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  st, info = SDM.save_decor(sd_payload(gid, 'manufacturer' => ''))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['field'] == 'manufacturer' }, info.inspect)
  NxTest.assert_equal('Egger', sd_group_sheets(gid).first['manufacturer'])

  uni = SDM.sheets.find { |s| SDM.uni?(s) }
  ugid = uni['group_id']
  st2, info2 = SDM.save_decor('mode' => 'edit', 'group_id' => ugid,
                              'base_rev' => SDM.catalog_revision,
                              'catalog_schema' => SDM::SCHEMA_CURRENT,
                              'decor' => uni['decor'], 'color' => '#ff0000',
                              'sheets' => [], 'edges' => [])
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['errors'].any? { |e| e['field'] == 'color' }, info2.inspect)
end

# ---------------------------------------------------------------------------
# 11) NOVE RIADKY — zabija: create vetva a jej guardy
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 7): riadok BEZ id je novy variant; uz existujuci sa PRESKOCI') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  sheets = sd_group_sheets(gid)
  rows = sheets.map { |s| sd_sheet_row(s) }
  rows << { 'type' => 'DTDL', 'thickness' => '25', 'sheet_size' => '', 'code' => 'NOVA25',
            'price_per_m2' => '30' }
  rows << { 'type' => 'DTDL', 'thickness' => '18', 'code' => 'DUPLIKAT' } # uz existuje
  edges = sd_group_edges(gid).map { |a| sd_edge_row(a) }
  edges << { 'width' => '43', 'thickness' => '2', 'code' => 'ABS43' }
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'edges' => edges))
  NxTest.assert_equal(:ok, st, info.inspect)
  NxTest.assert_equal(2, info['created'].size, "vznikli 2 nove: #{info.inspect}")
  NxTest.assert_equal(1, info['skipped'].size, 'existujuci variant sa PRESKOCIL, nic neprepisal')
  novy = SDM.sheets.find { |s| s['code'] == 'NOVA25' }
  NxTest.assert(novy, 'nova doska je v katalogu')
  NxTest.assert_close(25.0, novy['thickness'], 0.001)
  NxTest.assert_equal('ST10', novy['structure'], 'strukturu zdedil po skupine')
  NxTest.assert_equal(gid, novy['group_id'], 'a kotvu skupiny')
  NxTest.assert_equal([200, 180, 150], novy['color'], 'farbu urcuje SKUPINA, nie payload')
  NxTest.assert_equal('length', novy['grain'], 'smer dekoru zdedil po skupine')
  NxTest.assert_equal(3, sd_group_sheets(gid).size, 'presne jedna doska pribudla')
  abs = SDM.edges.find { |a| a['code'] == 'ABS43' }
  NxTest.assert(abs, 'nova paska je v katalogu')
  NxTest.refute(abs['universal'], 'universal ostava patch-only (audit #8)')
end

NxTest.test('save_decor (bod 6): ten isty novy variant DVAKRAT vo formulari je chyba') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |s| sd_sheet_row(s) }
  rows << { 'type' => 'DTDL', 'thickness' => '25', 'code' => 'A' }
  rows << { 'type' => 'DTDL', 'thickness' => '25', 'code' => 'B' }
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['row'] == 'sheets:3' }, info.inspect)
  NxTest.assert_equal(2, sd_group_sheets(gid).size, 'nic nepribudlo')
end

NxTest.test('save_decor (bod 6): novy variant s chybnou hrubkou/sirkou/formatom povie POLE') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |s| sd_sheet_row(s) }
  rows << { 'type' => 'PD', 'thickness' => '38', 'sheet_size' => '' }  # PD bez formatu
  rows << { 'type' => '', 'thickness' => '18' }                        # bez typu
  rows << { 'type' => 'DTDL', 'thickness' => '0' }                     # nula
  rows << { 'type' => 'DTDL', 'thickness' => '18', 'sheet_size' => '2800' } # zly format
  edges = [{ 'width' => '400', 'thickness' => '1' },                   # sirka mimo rozsahu
           { 'width' => '23', 'thickness' => '3' }]                    # hrubka mimo whitelistu
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'edges' => edges))
  NxTest.assert_equal(:invalid, st)
  fields = info['errors'].map { |e| [e['row'], e['field']] }
  NxTest.assert(fields.include?(['sheets:2', 'sheet_size']), fields.inspect)
  NxTest.assert(fields.include?(['sheets:3', 'type']), fields.inspect)
  NxTest.assert(fields.include?(['sheets:4', 'thickness']), fields.inspect)
  NxTest.assert(fields.include?(['sheets:5', 'sheet_size']), fields.inspect)
  NxTest.assert(fields.include?(['edges:0', 'width']), fields.inspect)
  NxTest.assert(fields.include?(['edges:1', 'thickness']), fields.inspect)
end

# ---------------------------------------------------------------------------
# 12) KOD + DODAVATEL — zabija: save_decor_code_conflict
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 6): duplicitny par kod+dodavatel vyzaduje potvrdenie') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  sheets = sd_group_sheets(gid)
  rows = [sd_sheet_row(sheets[0], 'code' => 'ROVNAKY', 'supplier' => 'Demos'),
          sd_sheet_row(sheets[1], 'code' => 'ROVNAKY', 'supplier' => 'Demos')]
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows))
  NxTest.assert_equal(:code_conflict, st)
  NxTest.assert_equal('ROVNAKY', info['code'])
  NxTest.assert(sd_group_sheets(gid).none? { |s| s['code'] == 'ROVNAKY' }, 'nezapisalo sa nic')
  # druhy pokus s potvrdenim prejde
  st2, info2 = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'allow_duplicate_code' => true))
  NxTest.assert_equal(:ok, st2, info2.inspect)
  NxTest.assert_equal(2, sd_group_sheets(gid).count { |s| s['code'] == 'ROVNAKY' })
end

# ---------------------------------------------------------------------------
# 13) TVAR ODPOVEDE + drobnosti kontraktu
# ---------------------------------------------------------------------------

NxTest.test('save_decor (bod 10): tvar odpovede + „bez zmien" nerobi zbytocny zapis') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rev = SDM.catalog_revision
  st, info = SDM.save_decor(sd_payload(gid))
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal(gid, info['group_id'])
  NxTest.assert_equal([], info['created'])
  NxTest.assert_equal([], info['updated'])
  NxTest.assert_equal([], info['skipped'])
  NxTest.assert_equal(rev, SDM.catalog_revision, 'nic sa nezmenilo => ziadny zapis')
end

NxTest.test('save_decor (bod 1): neznamy mode a chybajuci group_id sa odmietaju') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  # 2c-2b: `create` uz JE platny rezim (vlastna sada tests/pure/test_st2c_create.rb),
  # cokolvek ine ale nie — rozbity klient nesmie trafit ziadnu vetvu.
  st, info = SDM.save_decor(sd_payload(gid, 'mode' => 'nieco'))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert_equal('mode', info['errors'].first['field'])
  st2, info2 = SDM.save_decor(sd_payload(gid, 'group_id' => ''))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert_equal('group_id', info2['errors'].first['field'])
end

NxTest.test('save_decor (bod 6): UNI skupina nedostane ABS pasku ani novy variant') do
  sd_headless!
  sd_seed!
  uni = SDM.sheets.find { |s| SDM.uni?(s) }
  ugid = uni['group_id']
  base = { 'mode' => 'edit', 'group_id' => ugid, 'base_rev' => SDM.catalog_revision,
           'catalog_schema' => SDM::SCHEMA_CURRENT, 'decor' => uni['decor'] }
  st, info = SDM.save_decor(base.merge('sheets' => [],
                                       'edges' => [{ 'width' => '23', 'thickness' => '1' }]))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].first['msg'].include?('UNI'), info.inspect)
  st2, info2 = SDM.save_decor(base.merge('sheets' => [{ 'type' => 'DTDL', 'thickness' => '18' }],
                                         'edges' => []))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['errors'].first['msg'].include?('UNI'), info2.inspect)
end


# ---------------------------------------------------------------------------
# 14) REVIEW #2: duplak sa dorovna V TEJ ISTEJ transakcii
#     zabija: volanie sync_duplaks_in! v update vetve save_decor
# ---------------------------------------------------------------------------

NxTest.test('save_decor (review #2): zmena formatu/farby zdroja DOROVNA duplak v tom istom zapise') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  # zdroj = 36-ka (jej dvojnasobok 72 v katalogu este nie je; 18x2 by kolidovalo
  # s uz existujucou kupovanou 36-kou a duplak by nevznikol)
  src = sd_group_sheets(gid).last
  st0, dup = SDM.create_duplak_sheet(src['material_id'], 2)
  NxTest.assert_equal(:ok, st0, dup.inspect)
  dup_id = dup['material_id']
  NxTest.assert(SDM.sheet(dup_id), 'duplak vznikol')
  rows = sd_group_sheets(gid).reject { |x| SDM.duplak?(x) }.map do |x|
    x['material_id'] == src['material_id'] ? sd_sheet_row(x, 'sheet_size' => '2800×2070') : sd_sheet_row(x)
  end
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows, 'color' => '#102030'))
  NxTest.assert_equal(:ok, st, info.inspect)
  after_src = SDM.sheet(src['material_id'])
  after_dup = SDM.sheet(dup_id)
  NxTest.assert_equal([2800.0, 2070.0], after_src['sheet_size'], 'zdroj ma novy format')
  NxTest.assert_equal([2800.0, 2070.0], after_dup['sheet_size'],
                      'DUPLAK je dorovnany — inak by odhad platni ratal podla vymysleneho formatu')
  NxTest.assert_equal([16, 32, 48], after_dup['color'], 'a farbu dedi tiez')
  NxTest.assert(info['updated'].include?(dup_id), 'duplak je zaratany medzi upravene')
  NxTest.assert_equal(src['material_id'], after_dup['source_material_id'], 'vazba drzi')
end

# ---------------------------------------------------------------------------
# 15) REVIEW #6: ten isty variant dvakrat vo formulari
# ---------------------------------------------------------------------------

NxTest.test('save_decor (review #6): druhy vyskyt toho isteho ID je CHYBA, nie tichy prepis') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  s = sd_group_sheets(gid).first
  rows = [sd_sheet_row(s, 'code' => 'PRVY'), sd_sheet_row(s, 'code' => 'DRUHY')]
  st, info = SDM.save_decor(sd_payload(gid, 'sheets' => rows))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['row'] == 'sheets:1' && e['msg'].include?('dvakrát') },
                info.inspect)
  NxTest.assert_equal(s['code'], SDM.sheet(s['material_id'])['code'], 'nic sa nezapisalo')
  a = sd_group_edges(gid).first
  st2, info2 = SDM.save_decor(sd_payload(gid, 'edges' => [sd_edge_row(a), sd_edge_row(a)]))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['errors'].any? { |e| e['row'] == 'edges:1' }, info2.inspect)
end

# ---------------------------------------------------------------------------
# 16) REVIEW #8: nove riadky LEN pre typy bez dalsej identity
# ---------------------------------------------------------------------------

NxTest.test('save_decor (review #8): zastenu a PD editor nezaklada — odkaze na „+ variant"') do
  sd_headless!
  sd_seed!
  gid = sd_gid
  rows = sd_group_sheets(gid).map { |x| sd_sheet_row(x) }
  st, info = SDM.save_decor(sd_payload(gid,
                                       'sheets' => rows + [{ 'type' => 'ZASTENA', 'thickness' => '9,2',
                                                             'sheet_size' => '4100×640' }]))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].first['msg'].include?('+ variant'), info.inspect)
  st2, info2 = SDM.save_decor(sd_payload(gid,
                                         'sheets' => rows + [{ 'type' => 'PD', 'thickness' => '38',
                                                               'sheet_size' => '4100×600' }]))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['errors'].first['msg'].include?('hranovú úpravu'), info2.inspect)
  NxTest.assert_equal(2, sd_group_sheets(gid).size, 'nic nepribudlo')
  # bezny typ sa zalozit DA (brana je uzka, nie plosna)
  st3, info3 = SDM.save_decor(sd_payload(gid,
                                         'sheets' => rows + [{ 'type' => 'MDF', 'thickness' => '19' }]))
  NxTest.assert_equal(:ok, st3, info3.inspect)
  NxTest.assert_equal(1, info3['created'].size)
end

NxTest.test('patch_record (review #3): kod aj dodavatel rusia price_checked_at ako cena') do
  sd_headless!
  [['code', 'INY'], ['supplier', 'Iný'], ['price_per_m2', '33']].each do |field, value|
    sd_seed!
    gid = sd_gid
    s = sd_group_sheets(gid).first
    stamp = '2026-08-09T10:00:00Z'
    NxTest.assert(SDM.upsert_sheet(s.merge('code' => 'K1', 'supplier' => 'Demos',
                                           'price_per_m2' => 20.0, 'price_checked_at' => stamp)))
    fresh = SDM.sheet(s['material_id'])
    st, err = SDM.patch_record('sheet', fresh['material_id'], { field => value },
                               row_rev: SDM.record_rev(fresh), allow_duplicate_code: true)
    NxTest.assert_equal(:ok, st, err.inspect)
    NxTest.refute(SDM.sheet(fresh['material_id']).key?('price_checked_at'),
                  "inline bunka: zmena #{field} rusi datum overenia")
  end
  # kontrola opacnej strany: obchodny nazov datum NERUSI (nie je to nakupny udaj)
  sd_seed!
  gid = sd_gid
  s = sd_group_sheets(gid).first
  NxTest.assert(SDM.upsert_sheet(s.merge('price_per_m2' => 20.0,
                                         'price_checked_at' => '2026-08-09T10:00:00Z')))
  fresh = SDM.sheet(s['material_id'])
  st, = SDM.patch_record('sheet', fresh['material_id'], { 'cp_nazov' => 'Dub Halifax prírodný' },
                         row_rev: SDM.record_rev(fresh))
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal('2026-08-09T10:00:00Z', SDM.sheet(fresh['material_id'])['price_checked_at'],
                      'obchodny nazov s overenim ceny nesuvisi')
end

NxTest.test('save_decor (bod 6): UNI zaznam nedostane nakupne polia ani cez editor') do
  sd_headless!
  sd_seed!
  uni = SDM.sheets.find { |s| SDM.uni?(s) }
  ugid = uni['group_id']
  row = { 'material_id' => uni['material_id'], 'row_rev' => SDM.record_rev(uni),
          'type' => uni['type'], 'thickness' => SDM.fmt_mm(uni['thickness']),
          'code' => 'PODVRH', 'price_per_m2' => '10' }
  st, info = SDM.save_decor('mode' => 'edit', 'group_id' => ugid,
                            'base_rev' => SDM.catalog_revision,
                            'catalog_schema' => SDM::SCHEMA_CURRENT,
                            'decor' => uni['decor'], 'sheets' => [row], 'edges' => [])
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].first['msg'].include?('UNI'), info.inspect)
  NxTest.refute(SDM.sheet(uni['material_id'])['code'], 'kod sa nezapisal')
end
