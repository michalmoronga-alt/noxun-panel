# frozen_string_literal: true
# ŠT-2c PR 2c-2b — `Materials.save_decor` v rezime `create` („Pridať ručne").
#
# Preco su to testy a nie klikanie: KATALOG SU CENY REALNYCH OBJEDNAVOK a novy
# dekor je miesto, kde vznika jeho IDENTITA — cislo, ktore uz nikto nezmeni bez
# premenovania celej skupiny. Kazdy test nizsie zabija KONKRETNU branu; ked ju
# z kodu odstranis, sada padne (mutacna kontrola je v PR popise):
#
#   1  cislo dekoru     — povinne (identita skupiny a kluc vazby doska<->ABS)
#   2  near-match       — „h 3303" vedla „H3303" je PREKLEP, nie novy dekor
#   3  uz existuje      — zalozenie druhej skupiny s tou istou identitou = STOP
#   4  aspon jeden riadok — prazdny formular nezaklada prazdnu skupinu
#   5  znackova skupina — vyrobcu NESIE DOSKA (standard 7.5)
#   6  validate-all     — vsetky chyby NARAZ, ziadny fail-fast
#   7  atomicita        — chyba v POSLEDNOM riadku = ZIADNY zapis
#                         (dokaz: `catalog_revision` pred a po je ROVNAKA)
#   8  specialne typy   — zastena a PD sa odtialto nezakladaju (chyba s navodom)
#   9  riadok s ID      — create ho neprevezme (bol by to tichy edit cudzieho)
#  10  kod+dodavatel    — duplicita vyzaduje `allow_duplicate_code`
#  11  base_rev         — zapis nad starsim katalogom = :stale
#  12  skupinove polia  — farba a smer dekoru dostane KAZDY zalozeny zaznam
require_relative '../helper' unless defined?(NxTest)

SDC = Noxun::Engine::Materials

def sdc_headless!
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
end

def sdc_fresh!
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
end

# Payload presne v tvare, aky posiela prazdny D-69 formular.
def sdc_payload(over = {})
  { 'mode' => 'create', 'base_rev' => SDC.catalog_revision,
    'catalog_schema' => SDC::SCHEMA_CURRENT,
    'decor' => 'N9001', 'decor_name' => 'Testovací dub', 'manufacturer' => 'Egger',
    'color' => '#102030', 'grain' => 'length',
    'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18', 'structure' => 'ST10',
                   'sheet_size' => '2800×2070', 'code' => 'K-18', 'price_per_m2' => '18,40' }],
    'edges' => [{ 'width' => '23', 'thickness' => '1', 'structure' => 'ST10',
                  'code' => 'E-23', 'price_per_bm' => '0,52' }] }.merge(over)
end

def sdc_group(decor = 'N9001')
  SDC.sheets.select { |s| s['decor'] == decor }
end

# ---------------------------------------------------------------------------
# HLAVNY TOK — zabija: cela vetva save_decor_create_locked
# ---------------------------------------------------------------------------

NxTest.test('create: prazdny formular zalozi CELY dekor jednym zapisom') do
  sdc_headless!
  sdc_fresh!
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload)
  NxTest.assert_equal(:ok, st, info.inspect)
  NxTest.assert_equal('create', info['mode'], 'odpoved priznava rezim — klient podla nej skace do detailu')
  NxTest.assert_equal(2, info['created'].size, 'doska + paska')
  NxTest.assert_equal([], info['updated'])
  NxTest.refute(rev == SDC.catalog_revision, 'zapis prebehol')

  sheet = SDC.sheets.find { |s| s['decor'] == 'N9001' }
  edge = SDC.edges.find { |a| a['decor'] == 'N9001' }
  NxTest.assert(sheet && edge, 'oba zaznamy su v katalogu')
  NxTest.assert_equal(info['group_id'], sheet['group_id'], 'server vratil group_id NOVEJ skupiny')
  NxTest.assert_equal(sheet['group_id'], edge['group_id'],
                      'doska aj paska su v JEDNEJ skupine — inak by sa nikdy nestretli')
  NxTest.assert_equal('Egger', sheet['manufacturer'])
  NxTest.assert_equal('Egger N9001', sheet['family'])
  NxTest.assert_equal('Testovací dub', sheet['decor_name'])
  NxTest.assert_equal('ST10', sheet['structure'], 'struktura z formulara sedi na zazname')
  NxTest.assert_equal([2800.0, 2070.0], sheet['sheet_size'])
  NxTest.assert_equal('K-18', sheet['code'])
  NxTest.assert_close(18.4, sheet['price_per_m2'], 0.001)
  NxTest.assert_close(0.52, edge['price_per_bm'], 0.001)
  # (12) skupinove polia: farba aj smer dekoru
  NxTest.assert_equal([16, 32, 48], sheet['color'], 'farba z formulara')
  NxTest.assert_equal([16, 32, 48], edge['color'], 'a TA ISTA aj na paske (farba je vlastnost skupiny)')
  NxTest.assert_equal('length', sheet['grain'])
  NxTest.refute(sheet.key?('price_checked_at'),
                'datum overenia ceny zapisuje VYHRADNE Demos — rucne zalozenie ho nema odkial vziat')
end

NxTest.test('create (bod 12): smer dekoru „width" dostane KAZDA zalozena doska') do
  sdc_headless!
  sdc_fresh!
  st, = SDC.save_decor(sdc_payload('grain' => 'width', 'edges' => [],
                                   'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18' },
                                                { 'type' => 'DTDL', 'thickness' => '36' }]))
  NxTest.assert_equal(:ok, st)
  NxTest.assert(sdc_group.all? { |s| s['grain'] == 'width' }, 'obe dosky maju smer z formulara')
  st2, info2 = SDC.save_decor(sdc_payload('decor' => 'N9002', 'grain' => 'sikmo'))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['errors'].any? { |e| e['field'] == 'grain' }, info2.inspect)
end

# ---------------------------------------------------------------------------
# IDENTITA SKUPINY — zabija: save_decor_create_group
# ---------------------------------------------------------------------------

NxTest.test('create (bod 1): cislo dekoru je POVINNE') do
  sdc_headless!
  sdc_fresh!
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload('decor' => '   '))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['row'].nil? && e['field'] == 'decor' }, info.inspect)
  NxTest.assert_equal(rev, SDC.catalog_revision, 'ZIADNY zapis')
end

NxTest.test('create (bod 2): dekor lisiaci sa len ZAPISOM je preklep, nie novy dekor') do
  sdc_headless!
  sdc_fresh!
  NxTest.assert_equal(:ok, SDC.save_decor(sdc_payload)[0])
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload('decor' => 'n 9001', 'base_rev' => rev))
  NxTest.assert_equal(:invalid, st)
  err = info['errors'].find { |e| e['field'] == 'decor' }
  NxTest.assert(err, info.inspect)
  NxTest.assert(err['msg'].include?('zápisom'), "hlaska ma povedat PRESNY tvar: #{err['msg']}")
  NxTest.assert_equal(rev, SDC.catalog_revision, 'ZIADNY zapis')
  NxTest.assert(SDC.sheets.none? { |s| s['decor'] == 'n 9001' })
end

NxTest.test('create (bod 3): existujuci dekor sa nezaklada druhy raz — hlaska posle na „Upraviť…"') do
  sdc_headless!
  sdc_fresh!
  NxTest.assert_equal(:ok, SDC.save_decor(sdc_payload)[0])
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload('base_rev' => rev,
                                        'sheets' => [{ 'type' => 'DTDL', 'thickness' => '36' }],
                                        'edges' => []))
  NxTest.assert_equal(:invalid, st)
  err = info['errors'].find { |e| e['field'] == 'decor' }
  NxTest.assert(err, info.inspect)
  NxTest.assert(err['msg'].include?('Upraviť'), "hlaska ma NAVOD: #{err['msg']}")
  NxTest.assert_equal(1, sdc_group.size, 'druha doska sa NEPRIDALA — create nie je „+ variant"')
  NxTest.assert_equal(rev, SDC.catalog_revision)

  # ten isty dekor u INEHO vyrobcu je legitimna nova skupina (kod musi byt
  # vlastny — rovnaky par kod+dodavatel by si vypytal potvrdenie duplicity)
  st2, info2 = SDC.save_decor(sdc_payload('manufacturer' => 'Kronospan', 'decor_name' => '',
                                          'base_rev' => SDC.catalog_revision, 'edges' => [],
                                          'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18',
                                                         'structure' => 'ST10', 'code' => 'KR-18' }]))
  NxTest.assert_equal(:ok, st2, info2.inspect)
  NxTest.assert_equal(2, sdc_group.map { |s| s['group_id'] }.uniq.size,
                      'dve skupiny s rovnakym cislom, ale roznym vyrobcom')
end

NxTest.test('create (bod 4+5): prazdny formular a znackova skupina bez dosky sa odmietaju') do
  sdc_headless!
  sdc_fresh!
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload('sheets' => [], 'edges' => []))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['msg'].include?('aspoň jednu') }, info.inspect)

  st2, info2 = SDC.save_decor(sdc_payload('sheets' => []))
  NxTest.assert_equal(:invalid, st2)
  err = info2['errors'].find { |e| e['field'] == 'manufacturer' }
  NxTest.assert(err, info2.inspect)
  NxTest.assert(err['msg'].include?('dosku'), err.inspect)
  NxTest.assert_equal(rev, SDC.catalog_revision, 'ZIADNY zapis ani raz')

  # bez vyrobcu je skupina len s paskami legitimna (vyrobcu nesie doska)
  st3, info3 = SDC.save_decor(sdc_payload('sheets' => [], 'manufacturer' => '',
                                          'base_rev' => SDC.catalog_revision))
  NxTest.assert_equal(:ok, st3, info3.inspect)
end

# ---------------------------------------------------------------------------
# RIADKY — zabija: zdielana cesta save_decor_new_sheet / _edge
# ---------------------------------------------------------------------------

NxTest.test('create (bod 6+7): vsetky chyby NARAZ a chyba v poslednom riadku = ZIADNY zapis') do
  sdc_headless!
  sdc_fresh!
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload(
                              'decor' => '',
                              'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18' },
                                           { 'type' => '', 'thickness' => '18' },
                                           { 'type' => 'DTDL', 'thickness' => 'hrubka' }],
                              'edges' => [{ 'width' => '5', 'thickness' => '1' }]
                            ))
  NxTest.assert_equal(:invalid, st)
  errs = info['errors']
  NxTest.assert(errs.any? { |e| e['row'].nil? && e['field'] == 'decor' }, 'skupinove pole')
  NxTest.assert(errs.any? { |e| e['row'] == 'sheets:1' && e['field'] == 'type' }, 'riadok 1')
  NxTest.assert(errs.any? { |e| e['row'] == 'sheets:2' && e['field'] == 'thickness' }, 'riadok 2')
  NxTest.assert(errs.any? { |e| e['row'] == 'edges:0' && e['field'] == 'width' }, 'ABS riadok')
  NxTest.assert(errs.size >= 4, "vsetky naraz, ziadny fail-fast: #{errs.inspect}")
  NxTest.assert(errs.all? { |e| e['msg'].to_s.length > 5 }, 'kazda chyba ma vetu pre cloveka')
  NxTest.assert_equal(rev, SDC.catalog_revision,
                      'ATOMICITA: ani prvy (platny) riadok sa nezapisal')
  NxTest.assert(SDC.sheets.none? { |s| s['decor'] == 'N9001' }, 'katalog je nedotknuty')
end

NxTest.test('create (bod 8): zastenu a pracovnu dosku odtialto zalozit nejde — s NAVODOM') do
  sdc_headless!
  sdc_fresh!
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload('edges' => [],
                                        'sheets' => [{ 'type' => 'ZASTENA', 'thickness' => '9,2',
                                                       'sheet_size' => '4100×640' }]))
  NxTest.assert_equal(:invalid, st)
  err = info['errors'].find { |e| e['row'] == 'sheets:0' && e['field'] == 'type' }
  NxTest.assert(err, info.inspect)
  NxTest.assert(err['msg'].include?('+ variant'), "hlaska povie, KDE sa to zaklada: #{err['msg']}")

  st2, info2 = SDC.save_decor(sdc_payload('decor' => 'N9003', 'edges' => [],
                                          'sheets' => [{ 'type' => 'PD', 'thickness' => '38',
                                                         'sheet_size' => '4100×600' }]))
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['errors'].first['msg'].include?('+ variant'), info2.inspect)
  NxTest.assert_equal(rev, SDC.catalog_revision, 'ani jedno nic nezapisalo')
end

NxTest.test('create (bod 9): riadok s ID existujuceho variantu create NEPREVEZME') do
  sdc_headless!
  sdc_fresh!
  NxTest.assert_equal(:ok, SDC.save_decor(sdc_payload('edges' => []))[0])
  existing = SDC.sheets.find { |s| s['decor'] == 'N9001' }
  NxTest.assert(existing, 'vychodisko: jedna zalozena doska')
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload(
                              'decor' => 'N9009', 'base_rev' => rev, 'edges' => [],
                              'sheets' => [{ 'material_id' => existing['material_id'],
                                             'row_rev' => SDC.record_rev(existing),
                                             'type' => existing['type'],
                                             'thickness' => SDC.fmt_mm(existing['thickness']),
                                             'code' => 'PODVRH' }]
                            ))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['row'] == 'sheets:0' }, info.inspect)
  NxTest.assert_equal(rev, SDC.catalog_revision, 'ZIADNY zapis')
  NxTest.refute(SDC.sheet(existing['material_id'])['code'] == 'PODVRH',
                'cudzi zaznam ostal NEDOTKNUTY — create ho neupravil ani nepresunul')
  NxTest.assert_equal(existing['group_id'], SDC.sheet(existing['material_id'])['group_id'],
                      'ani sa nepresunul do prave zakladanej skupiny')
end

# ---------------------------------------------------------------------------
# BRANY — zabija: base_rev guard, code_conflict, read-only
# ---------------------------------------------------------------------------

NxTest.test('create (bod 11): stary base_rev = :stale a ZIADNY zapis') do
  sdc_headless!
  sdc_fresh!
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload('base_rev' => 'stary123'))
  NxTest.assert_equal(:stale, st)
  NxTest.assert(info['message'].to_s.include?('zmenil'), info.inspect)
  NxTest.assert_equal(rev, SDC.catalog_revision)
  NxTest.assert(SDC.sheets.none? { |s| s['decor'] == 'N9001' })
  st2, = SDC.save_decor(sdc_payload('base_rev' => ''))
  NxTest.assert_equal(:stale, st2, 'prazdny baseline neotvara ziadne vratka')
end

NxTest.test('create (bod 10): duplicitny par kod+dodavatel pyta POTVRDENIE') do
  sdc_headless!
  sdc_fresh!
  first = sdc_payload('sheets' => [{ 'type' => 'DTDL', 'thickness' => '18',
                                     'code' => 'DUP1', 'supplier' => 'Demos' }],
                      'edges' => [])
  NxTest.assert_equal(:ok, SDC.save_decor(first)[0])
  rev = SDC.catalog_revision
  second = sdc_payload('decor' => 'N9004', 'decor_name' => '', 'base_rev' => rev,
                       'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18',
                                      'code' => 'DUP1', 'supplier' => 'Demos' }],
                       'edges' => [])
  st, info = SDC.save_decor(second)
  NxTest.assert_equal(:code_conflict, st)
  NxTest.assert_equal('DUP1', info['code'])
  NxTest.assert_equal(rev, SDC.catalog_revision, 'nepotvrdena duplicita NEZAPISUJE')
  st2, info2 = SDC.save_decor(second.merge('allow_duplicate_code' => true,
                                           'base_rev' => SDC.catalog_revision))
  NxTest.assert_equal(:ok, st2, info2.inspect)
  NxTest.assert_equal(2, SDC.sheets.count { |s| s['code'] == 'DUP1' },
                      'po potvrdeni su v katalogu obe')
end

# (review 2c-2b #1) NAJTICHSIA pasca celej vetvy: keby `save_decor_code_conflict`
# dostal PRAZDNY snimok spred davky, kazdy zaznam katalogu by sa tvaril ako
# „zmeneny touto davkou" — a JEDNA stara, vedome potvrdena duplicita kodu by
# potom zablokovala zalozenie KAZDEHO dalsieho dekoru. Bez tohto testu by to
# nikto nezistil, kym by sa katalog nezasekol.
NxTest.test('create (bod 10): CUDZIA potvrdena duplicita NEBLOKUJE zalozenie ineho dekoru') do
  sdc_headless!
  sdc_fresh!
  # dva existujuce dekory ZAMERNE zdielaju par kod+dodavatel (vedome potvrdena
  # duplicita — presne stav, aky v katalogu realne vznika)
  NxTest.assert_equal(:ok, SDC.save_decor(sdc_payload('edges' => [],
                                                      'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18',
                                                                     'code' => 'SPOLOCNY', 'supplier' => 'Demos' }]))[0])
  st_dup, = SDC.save_decor(sdc_payload('decor' => 'N9101', 'decor_name' => '', 'edges' => [],
                                       'base_rev' => SDC.catalog_revision,
                                       'allow_duplicate_code' => true,
                                       'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18',
                                                      'code' => 'SPOLOCNY', 'supplier' => 'Demos' }]))
  NxTest.assert_equal(:ok, st_dup, 'vychodisko: duplicita je v katalogu a bola POTVRDENA')
  NxTest.assert_equal(2, SDC.sheets.count { |s| s['code'] == 'SPOLOCNY' })

  # TRETI dekor s UPLNE INYM kodom — s duplicitou nema nic spolocne
  st, info = SDC.save_decor(sdc_payload('decor' => 'N9102', 'decor_name' => '', 'edges' => [],
                                        'base_rev' => SDC.catalog_revision,
                                        'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18',
                                                       'code' => 'VLASTNY', 'supplier' => 'Demos' }]))
  NxTest.assert_equal(:ok, st, "stara duplicita nesmie zamknut katalog: #{info.inspect}")
  NxTest.assert(SDC.sheets.any? { |s| s['code'] == 'VLASTNY' }, 'dekor sa zalozil')
  # a NOVA duplicita sa nadalej vycita (guard nezoslabol)
  st2, info2 = SDC.save_decor(sdc_payload('decor' => 'N9103', 'decor_name' => '', 'edges' => [],
                                          'base_rev' => SDC.catalog_revision,
                                          'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18',
                                                         'code' => 'VLASTNY', 'supplier' => 'Demos' }]))
  NxTest.assert_equal(:code_conflict, st2, info2.inspect)
  NxTest.assert_equal('VLASTNY', info2['code'])
end

# (review 2c-2b #2) Skupina s dvoma strukturami je pre editor NEROZHODNUTELNA
# (`sd_new_structure`) — zalozit ju znamena vyrobit dekor, do ktoreho sa uz
# nikdy neda pridat riadok inak nez cez „+ variant".
NxTest.test('create: dve rozne struktury v jednom formulari sa ODMIETNU') do
  sdc_headless!
  sdc_fresh!
  rev = SDC.catalog_revision
  st, info = SDC.save_decor(sdc_payload(
                              'edges' => [],
                              'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18', 'structure' => 'ST10' },
                                           { 'type' => 'DTDL', 'thickness' => '36', 'structure' => 'PW' }]
                            ))
  NxTest.assert_equal(:invalid, st)
  err = info['errors'].find { |e| e['row'] == 'sheets:1' && e['field'] == 'structure' }
  NxTest.assert(err, info.inspect)
  NxTest.assert(err['msg'].include?('+ variant'), "hlaska povie, KDE sa dalsia struktura pridava: #{err['msg']}")
  NxTest.assert_equal(rev, SDC.catalog_revision, 'ZIADNY zapis')

  # rovnaka struktura (aj s inym zapisom) je v poriadku, aj krizom doska<->ABS
  st2, info2 = SDC.save_decor(sdc_payload(
                                'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18', 'structure' => 'ST10' },
                                             { 'type' => 'DTDL', 'thickness' => '36', 'structure' => 'st10' }],
                                'edges' => [{ 'width' => '23', 'thickness' => '1', 'structure' => 'ST10' }]
                              ))
  NxTest.assert_equal(:ok, st2, info2.inspect)
  # ABS s INOU strukturou nez dosky je tiez dvojstrukturova skupina
  st3, info3 = SDC.save_decor(sdc_payload('decor' => 'N9201', 'decor_name' => '',
                                          'base_rev' => SDC.catalog_revision,
                                          'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18', 'structure' => 'ST10' }],
                                          'edges' => [{ 'width' => '23', 'thickness' => '1', 'structure' => 'PW' }]))
  NxTest.assert_equal(:invalid, st3)
  NxTest.assert(info3['errors'].any? { |e| e['row'] == 'edges:0' && e['field'] == 'structure' }, info3.inspect)
end

# (review 2c-2b #3) Farba ide OBOMA rezimami cez `sd_color_plan` — dve kopie
# pravidla by sa casom rozisli a jedna z nich by prestala platit.
NxTest.test('create: neplatna farba a UNI zamok su TA ISTA autorita ako pri edite') do
  sdc_headless!
  sdc_fresh!
  st, info = SDC.save_decor(sdc_payload('color' => 'zelena'))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['errors'].any? { |e| e['field'] == 'color' }, info.inspect)

  # UNI zamok: `uni_group?` pozna skupinu aj podla TEXTU dekoru, takze
  # zalozenie dekoru s menom existujucej UNI skupiny narazi na to iste pravidlo
  uni = SDC.sheets.find { |s| SDC.uni?(s) }
  NxTest.assert(uni, 'seed nesie UNI sadu')
  st2, info2 = SDC.save_decor(sdc_payload('decor' => uni['decor'], 'decor_name' => '',
                                          'manufacturer' => '', 'edges' => [],
                                          'color' => '#ff0000',
                                          'sheets' => [{ 'type' => 'DTDL', 'thickness' => '18' }]))
  NxTest.assert_equal(:invalid, st2)
  err = info2['errors'].find { |e| e['field'] == 'color' }
  NxTest.assert(err, info2.inspect)
  NxTest.assert(err['msg'] == SDC.uni_color_locked_message, "TA ISTA hlaska ako v edite: #{err['msg']}")
end

NxTest.test('create: nudzovy (read-only) katalog zakladanie ODMIETNE') do
  sdc_headless!
  sdc_fresh!
  SDC.instance_variable_set(:@catalog_state, :read_only)
  SDC.instance_variable_set(:@catalog_state_reason, 'test')
  begin
    st, info = SDC.save_decor(sdc_payload)
    NxTest.assert_equal(:catalog_read_only, st)
    NxTest.assert(info['message'].to_s.length > 5, info.inspect)
    NxTest.assert(SDC.sheets.none? { |s| s['decor'] == 'N9001' })
  ensure
    SDC.reset_catalog_state!
  end
end
