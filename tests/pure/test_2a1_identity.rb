# frozen_string_literal: true
# Testy 2A-1: jadro identity variantov a skupin (SCHEMA 2) — kanonicke identity
# helpery, register kanonickych typov, generovanie ID so strukturou/formatom,
# SCHEMA marker + guard mutacii, nemenna predmigracna zaloha.
#
# KONTRAKT DAVKY (dual-mode): katalog ostava na SCHEMA 1 a spravanie sa NESMIE
# zmenit ani o vlas — cely aparat SCHEMA 2 sa AKTIVUJE az migraciou (2A-2).
# Testy preto vsade overuju OBE vetvy: schema 1 = presne dnesok, schema 2 = nove
# pravidla zo standardu 7.1/7.5. Vsetko headless (APPDATA sandbox).
require_relative '../helper' unless defined?(NxTest)

A1MAT = Noxun::Engine::Materials
A1STORE = Noxun::Engine::JsonFileStore

# Docasne prepne KATALOGOVY SUBOR na SCHEMA 2 (fixture migrovaneho stavu) a po
# bloku vrati bajt-presny povodny obsah — ziadny test nesmie nechat katalog
# prepnuty pre tie dalsie.
def a1_with_schema2
  path = A1MAT.path
  A1MAT.catalog # zabezpeci seed, aby subor existoval
  before = File.binread(path)
  A1STORE.write(path, JSON.parse(before).merge('schema' => 2))
  yield
ensure
  if before
    File.binwrite(path, before)
    A1STORE.invalidate(path)
  end
end

def a1_sheet(extra = {})
  { 'decor' => 'A1 Dekor', 'type' => 'DTDL', 'thickness' => 18.0 }.merge(extra)
end

def a1_edge(extra = {})
  { 'decor' => 'A1 Dekor', 'thickness' => 1.0, 'width' => 22.0 }.merge(extra)
end

# ---------------------------------------------------------------------------
# identity_norm — JEDINA normalizacia textovej casti identity
# ---------------------------------------------------------------------------

NxTest.test('2A-1: identity_norm — trim, kolaps medzier, case-insensitive') do
  NxTest.assert_equal('ST9', A1MAT.identity_norm(' st9 '))
  NxTest.assert_equal('ST9', A1MAT.identity_norm('ST9'))
  NxTest.assert_equal('ST 9', A1MAT.identity_norm('ST  9'), 'viacnasobna medzera sa zrazi na jednu')
  NxTest.assert_equal('ST 9', A1MAT.identity_norm("ST \t 9"), 'tabulator je tiez medzera')
  NxTest.assert_equal('K009 PW', A1MAT.identity_norm('  k009   pw  '))
  NxTest.assert_equal('', A1MAT.identity_norm(nil))
  NxTest.assert_equal('', A1MAT.identity_norm('   '))
  # POZOR (zamok): medzery sa NEODSTRANUJU — 'ST9' a 'ST 9' su dva ROZNE zapisy.
  # Preklepy tohto druhu chyta near-match guard decor_conflict (ten medzery
  # ignoruje uplne), nie identity kluc.
  NxTest.refute(A1MAT.identity_norm('ST9') == A1MAT.identity_norm('ST 9'),
                "'ST9' a 'ST 9' NESMU byt ten isty identity kluc")
  NxTest.assert_equal('u702st9', 'U702 ST9'.gsub(/\s+/, '').downcase, 'kontrola predpokladu near-match kluca')
  NxTest.assert_equal(A1MAT.decor_norm_key('U702ST9'), A1MAT.decor_norm_key('U702 ST9'),
                      'near-match guard ostava prisnejsi ako identity kluc')
end

NxTest.test('2A-1: group_identity_key — vyrobca + cislo dekoru, case-insensitive') do
  NxTest.assert_equal(A1MAT.group_identity_key('Kronospan', 'K009'),
                      A1MAT.group_identity_key(' kronospan ', 'k009'))
  NxTest.refute(A1MAT.group_identity_key('Kronospan', 'K009') == A1MAT.group_identity_key('Egger', 'K009'),
                'rovnake cislo dvoch vyrobcov su DVE skupiny (standard 7.1)')
  NxTest.refute(A1MAT.group_identity_key('Egger', 'H1180') == A1MAT.group_identity_key('Egger', 'H1181'))
end

# ---------------------------------------------------------------------------
# schema-aware kluce variantov
# ---------------------------------------------------------------------------

NxTest.test('2A-1: sheet kluc — schema 1 STRUKTURU IGNORUJE, schema 2 ju rozlisuje') do
  st9 = a1_sheet('structure' => 'ST9')
  mg  = a1_sheet('structure' => 'MG')
  bez = a1_sheet
  NxTest.assert_equal(A1MAT.sheet_identity_key(st9, 1), A1MAT.sheet_identity_key(mg, 1),
                      'schema 1: struktura nie je sucastou identity')
  NxTest.assert_equal(A1MAT.sheet_identity_key(bez, 1), A1MAT.sheet_identity_key(st9, 1))
  NxTest.refute(A1MAT.sheet_identity_key(st9, 2) == A1MAT.sheet_identity_key(mg, 2),
                'schema 2: 5981/DTDL/18/MG a /BS su DVA varianty')
  NxTest.refute(A1MAT.sheet_identity_key(bez, 2) == A1MAT.sheet_identity_key(st9, 2))
  NxTest.assert_equal(A1MAT.sheet_identity_key(st9, 2),
                      A1MAT.sheet_identity_key(a1_sheet('structure' => ' st9 '), 2),
                      'struktura sa normalizuje (trim + case)')
end

NxTest.test('2A-1: sheet kluc — typ case-insensitive, hrubka na 2 desatiny (obe schemy)') do
  [1, 2].each do |schema|
    NxTest.assert_equal(A1MAT.sheet_identity_key(a1_sheet('type' => 'DTDL'), schema),
                        A1MAT.sheet_identity_key(a1_sheet('type' => ' dtdl '), schema),
                        "schema #{schema}: typ je case-insensitive")
    NxTest.assert_equal(A1MAT.sheet_identity_key(a1_sheet('thickness' => 18.0), schema),
                        A1MAT.sheet_identity_key(a1_sheet('thickness' => 18.004), schema),
                        "schema #{schema}: 18 a 18.004 su ten isty variant")
    NxTest.refute(A1MAT.sheet_identity_key(a1_sheet('thickness' => 18.0), schema) ==
                  A1MAT.sheet_identity_key(a1_sheet('thickness' => 19.0), schema),
                  "schema #{schema}: 18 a 19 su dva varianty")
    NxTest.refute(A1MAT.sheet_identity_key(a1_sheet('type' => 'DTDL'), schema) ==
                  A1MAT.sheet_identity_key(a1_sheet('type' => 'MDF'), schema))
  end
  # dekor: schema 1 porovnava PRESNY (trimnuty) text — dnesne spravanie 1:1
  NxTest.assert_equal(A1MAT.sheet_identity_key(a1_sheet('decor' => 'A1 Dekor'), 1),
                      A1MAT.sheet_identity_key(a1_sheet('decor' => ' A1 Dekor '), 1))
  NxTest.refute(A1MAT.sheet_identity_key(a1_sheet('decor' => 'A1 Dekor'), 1) ==
                A1MAT.sheet_identity_key(a1_sheet('decor' => 'a1 dekor'), 1),
                'schema 1: dekor ostava case-SENSITIVE (dnesne porovnanie)')
end

NxTest.test('2A-1: sheet kluc — PD format v schema 2 (usporiadana dvojica), inde nie') do
  pd600 = a1_sheet('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0])
  pd920 = a1_sheet('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 920.0])
  otoc  = a1_sheet('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [600.0, 4100.0])
  NxTest.assert_equal(A1MAT.sheet_identity_key(pd600, 1), A1MAT.sheet_identity_key(pd920, 1),
                      'schema 1: format NIE JE identita (D-44 spravanie)')
  NxTest.refute(A1MAT.sheet_identity_key(pd600, 2) == A1MAT.sheet_identity_key(pd920, 2),
                'schema 2: F800 PD 38 4100x600 a 4100x920 su dva varianty')
  NxTest.assert_equal(A1MAT.sheet_identity_key(pd600, 2), A1MAT.sheet_identity_key(otoc, 2),
                      'format je USPORIADANA dvojica — 600x4100 je ten isty format')
  NxTest.assert_equal(A1MAT.sheet_identity_key(pd600, 2),
                      A1MAT.sheet_identity_key(a1_sheet('type' => 'pd', 'thickness' => 38.0,
                                                        'sheet_size' => [4100, 600]), 2),
                      'typ PD je case-insensitive aj pre formatove pravidlo')
  # NEPD typ: format identitou nie je ani v schema 2
  dtdl_a = a1_sheet('sheet_size' => [2800.0, 2070.0])
  dtdl_b = a1_sheet('sheet_size' => [2800.0, 2050.0])
  NxTest.assert_equal(A1MAT.sheet_identity_key(dtdl_a, 2), A1MAT.sheet_identity_key(dtdl_b, 2))
end

NxTest.test('2A-1: skupinovy kluc — schema 2 sa drzi group_id, schema 1 textu dekoru') do
  a = a1_sheet('decor' => 'Halifax', 'group_id' => 'GRP-A1', 'manufacturer' => 'Egger')
  b = a1_sheet('decor' => 'Halifax tabakovy', 'group_id' => 'GRP-A1', 'manufacturer' => 'Egger')
  NxTest.assert_equal(A1MAT.sheet_identity_key(a, 2), A1MAT.sheet_identity_key(b, 2),
                      'schema 2: kotva skupiny je group_id, nie text nazvu')
  NxTest.refute(A1MAT.sheet_identity_key(a, 1) == A1MAT.sheet_identity_key(b, 1),
                'schema 1: skupina = presny text dekoru')
  # bez group_id padne schema 2 na obchodnu identitu skupiny (vyrobca + dekor)
  c = a1_sheet('decor' => 'K009', 'manufacturer' => 'Kronospan')
  d = a1_sheet('decor' => 'K009', 'manufacturer' => 'Egger')
  NxTest.refute(A1MAT.sheet_identity_key(c, 2) == A1MAT.sheet_identity_key(d, 2),
                'schema 2 bez group_id: vyrobca skupinu rozlisuje')
  NxTest.assert_equal(A1MAT.sheet_identity_key(c, 1), A1MAT.sheet_identity_key(d, 1),
                      'schema 1: vyrobca do identity nevstupuje')
end

NxTest.test('2A-1: edge kluc — sirka+hrubka vzdy, struktura len v schema 2') do
  w22 = a1_edge
  w43 = a1_edge('width' => 43.0)
  bez = a1_edge('width' => nil)
  [1, 2].each do |schema|
    NxTest.refute(A1MAT.edge_identity_key(w22, schema) == A1MAT.edge_identity_key(w43, schema))
    NxTest.refute(A1MAT.edge_identity_key(w22, schema) == A1MAT.edge_identity_key(bez, schema),
                  "schema #{schema}: univerzalna paska bez sirky je vlastny variant")
    NxTest.assert_equal(A1MAT.edge_identity_key(w22, schema),
                        A1MAT.edge_identity_key(a1_edge('width' => '22,0'), schema),
                        "schema #{schema}: desatinna ciarka v sirke")
    NxTest.assert_equal(A1MAT.edge_identity_key(bez, schema),
                        A1MAT.edge_identity_key(a1_edge('width' => '  '), schema),
                        "schema #{schema}: prazdna sirka = bez sirky")
  end
  mg = a1_edge('structure' => 'MG')
  um = a1_edge('structure' => 'UM')
  NxTest.assert_equal(A1MAT.edge_identity_key(mg, 1), A1MAT.edge_identity_key(um, 1))
  NxTest.refute(A1MAT.edge_identity_key(mg, 2) == A1MAT.edge_identity_key(um, 2),
                'schema 2: 5981 ma DVE rozne 23/1 pasky (MG vs UM)')
  # 'universal' je vlastnost VYBERU, nie identity variantu (standard 7.5)
  NxTest.assert_equal(A1MAT.edge_identity_key(mg, 2), A1MAT.edge_identity_key(mg.merge('universal' => true), 2))
end

# ---------------------------------------------------------------------------
# generovanie ID (opaque kontrakt)
# ---------------------------------------------------------------------------

NxTest.test('2A-1: generate_sheet_id — bez struktury PRESNE dnesne ID') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_equal('A1_ID_TEST_DTDL_18', A1MAT.generate_sheet_id('A1 Id Test', 'DTDL', 18.0))
  NxTest.assert_equal('A1_ID_TEST_DTDL_18',
                      A1MAT.generate_sheet_id('A1 Id Test', 'DTDL', 18.0, structure: nil))
  NxTest.assert_equal('A1_ID_TEST_DTDL_18',
                      A1MAT.generate_sheet_id('A1 Id Test', 'DTDL', 18.0, structure: '  '))
  # format PD sa v SCHEMA 1 do ID NEDOSTANE (formatom sa variant este nedeli)
  NxTest.assert_equal('A1_ID_TEST_PD_38',
                      A1MAT.generate_sheet_id('A1 Id Test', 'PD', 38.0, sheet_size: [4100, 600]))
end

NxTest.test('2A-1: generate_sheet_id — struktura za dekorom, PD format v schema 2') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  # Tvar zo standardu 7.1 (dekor + struktura + typ + hrubka); seed uz obsahuje
  # K009_PW_DTDL_18, preto test pouziva vlastny dekor rovnakeho tvaru.
  NxTest.assert_equal('A1K009_PW_DTDL_18', A1MAT.generate_sheet_id('A1K009', 'DTDL', 18.0, structure: 'PW'),
                      'struktura ide hned za dekor (standard 7.1 priklad)')
  NxTest.assert_equal('A1_ID_TEST_ST9_DTDL_18',
                      A1MAT.generate_sheet_id('A1 Id Test', 'DTDL', 18.0, structure: ' st9 '))
  NxTest.assert_equal('A1_ID_TEST_PD_38_4100X600',
                      A1MAT.generate_sheet_id('A1 Id Test', 'PD', 38.0,
                                              sheet_size: [600, 4100], schema: 2),
                      'schema 2 + PD: token formatu z USPORIADANEJ dvojice')
  NxTest.assert_equal('A1_ID_TEST_DTDL_18',
                      A1MAT.generate_sheet_id('A1 Id Test', 'DTDL', 18.0,
                                              sheet_size: [2800, 2070], schema: 2),
                      'NEPD typ token formatu nedostane ani v schema 2')
  NxTest.assert_equal('A1_ID_TEST_PD_38',
                      A1MAT.generate_sheet_id('A1 Id Test', 'PD', 38.0, schema: 2),
                      'PD bez zadaneho formatu ostava bez tokenu')
end

NxTest.test('2A-1: generate_edge_id — struktura v ID, legacy tvary nedotknute') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_equal('ABS_A1_ID_TEST_22X10', A1MAT.generate_edge_id('A1 Id Test', 1.0, 22))
  NxTest.assert_equal('ABS_A1_ID_TEST_10', A1MAT.generate_edge_id('A1 Id Test', 1.0))
  NxTest.assert_equal('ABS_A1_ID_TEST_MG_22X10',
                      A1MAT.generate_edge_id('A1 Id Test', 1.0, 22, structure: 'mg'))
  NxTest.assert_equal('ABS_A1_ID_TEST_MG_20',
                      A1MAT.generate_edge_id('A1 Id Test', 2.0, nil, structure: 'MG'))
end

NxTest.test('2A-1: generatory ID — kolizie -2/-3 aj s vlastnym zoznamom (davka)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  id1 = A1MAT.generate_sheet_id('A1 Unik', 'DTDL', 18.0)
  A1MAT.upsert_sheet('material_id' => id1, 'decor' => 'A1 Unik', 'type' => 'DTDL', 'thickness' => 18.0)
  NxTest.assert_equal("#{id1}-2", A1MAT.generate_sheet_id('A1 Unik', 'DTDL', 18.0), 'kolizia z katalogu')
  # vlastny (kumulativny) zoznam davky — katalog sa vobec nepozera
  taken = ['A1_DAVKA_DTDL_18']
  NxTest.assert_equal('A1_DAVKA_DTDL_18-2',
                      A1MAT.generate_sheet_id('A1 davka', 'DTDL', 18.0, taken: taken))
  NxTest.assert_equal('ABS_A1_DAVKA_22X10',
                      A1MAT.generate_edge_id('A1 davka', 1.0, 22, taken: taken))
  A1MAT.delete_sheet(id1)
end

# ---------------------------------------------------------------------------
# register kanonickych typov
# ---------------------------------------------------------------------------

NxTest.test('2A-1: TYPE_REGISTRY — deriváty maju PRESNE dnesne hodnoty API') do
  NxTest.assert_equal([2800.0, 2070.0], A1MAT::TYPE_FORMAT_HINTS['DTDL'])
  NxTest.assert_equal([2800.0, 2070.0], A1MAT::TYPE_FORMAT_HINTS['MDF'])
  NxTest.assert_equal([2800.0, 2070.0], A1MAT::TYPE_FORMAT_HINTS['HDF'])
  NxTest.assert_equal(nil, A1MAT::TYPE_FORMAT_HINTS['PD'], 'PD sirok je vela — vedome zadanie')
  NxTest.assert_equal(nil, A1MAT::TYPE_FORMAT_HINTS['kompakt'], 'typ mimo registra = bez navrhu')
  NxTest.assert_equal(A1MAT::TYPE_REGISTRY.keys, A1MAT::TYPE_FORMAT_HINTS.keys, 'hinty su derivat registra')
  NxTest.assert_equal(A1MAT::TYPE_REGISTRY.keys, A1MAT::SEED_TYPES, 'seed typy = kluce registra')
  NxTest.assert_equal(%w[DTDL MDF HDF PD ZASTENA KOMPAKT].sort, A1MAT::TYPE_REGISTRY.keys.sort)
end

NxTest.test('2A-1: register — parametre typov a generické spravanie "ineho" typu') do
  NxTest.assert_equal(%w[postforming abs], A1MAT.pd_edge_subtypes('pd'), 'PD ma hranove podtypy')
  NxTest.assert_equal([], A1MAT.pd_edge_subtypes('KOMPAKT'), 'Kompakt je VLASTNY typ, nie podtyp PD')
  NxTest.assert_equal([], A1MAT.pd_edge_subtypes('Melamin'))
  NxTest.assert_equal([18.0, 19.0, 36.0], A1MAT.type_thickness_suggestions('DTDL'))
  NxTest.assert_equal([9.2, 10.0], A1MAT.type_thickness_suggestions('zastena'))
  NxTest.assert_equal([], A1MAT.type_thickness_suggestions('Melamin'), 'iny typ = ziadne navrhy')
  NxTest.assert(A1MAT.body_candidate_type?('DTDL') && A1MAT.body_candidate_type?('mdf'))
  %w[HDF PD ZASTENA KOMPAKT Melamin].each do |t|
    NxTest.refute(A1MAT.body_candidate_type?(t), "typ #{t} nie je kandidat na telo korpusu")
  end
  NxTest.assert_equal('DTDL', A1MAT.canonical_type(' dtdl '))
  NxTest.assert_equal('Melamin', A1MAT.canonical_type('  Melamin  '), 'iny typ ostava tak, ako ho pisal')
  NxTest.assert_equal(nil, A1MAT.type_registry_entry('Melamin'))
  NxTest.assert(A1MAT.pd_type?(' pd ') && !A1MAT.pd_type?('PDF'))
end

NxTest.test('2A-1: naseptavac typov ponuka kanonicke typy bez case duplicit') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  types = A1MAT.type_suggestions
  %w[DTDL PD MDF HDF ZASTENA KOMPAKT].each { |t| NxTest.assert(types.include?(t), "typ #{t} chyba: #{types.inspect}") }
  NxTest.assert_equal(types.uniq { |t| t.downcase }.size, types.size, 'ziadne case duplicity')
end

# ---------------------------------------------------------------------------
# SCHEMA marker + guard mutacii
# ---------------------------------------------------------------------------

NxTest.test('2A-1: SCHEMA marker — default 1, zapis ho nesie a NEZNIZUJE') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  A1MAT.catalog # seed
  NxTest.assert_equal(1, A1MAT.catalog_schema, 'chybajuci/legacy marker = 1')
  data = A1MAT.load
  NxTest.assert(A1MAT.write(data), 'bezny zapis')
  parsed = JSON.parse(File.binread(A1MAT.path))
  NxTest.assert_equal(1, parsed['schema'], 'marker sa zapisuje do suboru')
  NxTest.assert_equal(1, parsed['std'], 'std ostava (spatna kompatibilita)')
  a1_with_schema2 do
    NxTest.assert_equal(2, A1MAT.catalog_schema)
    # 2A-2 GH P1 (2. kolo): stale LEGACY payload (zaznamy bez group_id) sa do
    # SCHEMA 2 suboru uz nezapise — hybrid marker-2-s-legacy-datami odmietnuty.
    NxTest.refute(A1MAT.write(A1MAT.load), 'legacy payload bez group_id sa do schema 2 odmietne')
    NxTest.assert_equal(2, A1MAT.catalog_schema, 'odmietnuty zapis subor nezmenil')
    full = A1MAT.load
    (full['sheets'] + full['edges']).each { |r| r['group_id'] = 'GRP-A1TESTMARKER01' }
    NxTest.assert(A1MAT.write(full), 'UPLNY schema 2 payload (group_id vsade) prejde')
    NxTest.assert_equal(2, A1MAT.catalog_schema, 'bezna mutacia schemu NESTRATI')
    NxTest.assert(A1MAT.write(full.merge('schema' => 1)))
    NxTest.assert_equal(2, A1MAT.catalog_schema, 'downgrade na 1 sa odmietne (ziadny hybridny stav)')
  end
  NxTest.assert_equal(1, A1MAT.catalog_schema, 'fixture sa upratala')
end

NxTest.test('2A-1: guard mutacii — v schema 1 prejde vsetko, v schema 2 len novy klient') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(A1MAT.schema_write_allowed?(nil), 'schema 1: stary klient bez pola')
  NxTest.assert(A1MAT.schema_write_allowed?(1))
  NxTest.assert(A1MAT.schema_write_allowed?(2))
  a1_with_schema2 do
    NxTest.refute(A1MAT.schema_write_allowed?(nil), 'schema 2: payload bez schemy = stare okno')
    NxTest.refute(A1MAT.schema_write_allowed?(''), 'prazdna hodnota = stare okno')
    NxTest.refute(A1MAT.schema_write_allowed?(1), 'klient na schema 1 uz nesmie zapisovat')
    NxTest.assert(A1MAT.schema_write_allowed?(2))
    NxTest.assert(A1MAT.schema_write_allowed?('2'), 'hodnota z JSON payloadu moze prist ako text')
    NxTest.assert(A1MAT.schema_write_allowed?(3), 'novsi klient nie je dovod odmietat')
  end
end

NxTest.test('2A-1: identita pri edite — schema 1 mlci, schema 2 strazi PD format/strukturu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  pd = { 'material_id' => 'A1_PD', 'decor' => 'A1 Dekor', 'type' => 'PD', 'thickness' => 38.0,
         'sheet_size' => [4100.0, 600.0], 'structure' => 'MAT', 'group_id' => 'GRP-A1' }
  # SCHEMA 1: nove polia nic nedefinuju — ziadna hlaska (dnesne spravanie)
  NxTest.assert_equal(nil, A1MAT.identity_edit_error(pd.merge('sheet_size' => [4100.0, 920.0]), pd))
  NxTest.assert_equal(nil, A1MAT.identity_edit_error(pd.merge('structure' => 'ST9'), pd))
  a1_with_schema2 do
    NxTest.assert_equal(nil, A1MAT.identity_edit_error(pd, pd), 'nezmenena identita prejde')
    NxTest.assert_equal(nil, A1MAT.identity_edit_error({ 'code' => 'X' }, pd), 'payload bez identitnych poli')
    NxTest.assert_equal(nil, A1MAT.identity_edit_error(pd.merge('sheet_size' => [600.0, 4100.0]), pd),
                        'otocena dvojica je ten isty format')
    err = A1MAT.identity_edit_error(pd.merge('sheet_size' => [4100.0, 920.0]), pd)
    NxTest.assert(err.to_s.include?('Formát PD'), err.to_s)
    clr = A1MAT.identity_edit_error(pd.merge('clear_sheet_size' => true), pd)
    NxTest.assert(clr.to_s.include?('Formát PD'), 'vymazanie formatu PD je tiez zmena identity')
    st = A1MAT.identity_edit_error(pd.merge('structure' => 'ST9'), pd)
    NxTest.assert(st.to_s.include?('Štruktúra'), st.to_s)
    NxTest.assert_equal(nil, A1MAT.identity_edit_error(pd.merge('structure' => ' mat '), pd),
                        'ten isty zapis inym pisom nie je zmena')
    gr = A1MAT.identity_edit_error(pd.merge('group_id' => 'GRP-B2'), pd)
    NxTest.assert(gr.to_s.include?('skupina'), gr.to_s)
    # doska bez PD typu: format sa strazit nema (ostava editovatelny ceruzkou)
    dtdl = pd.merge('type' => 'DTDL')
    NxTest.assert_equal(nil, A1MAT.identity_edit_error(dtdl.merge('sheet_size' => [2800.0, 2050.0]), dtdl))
  end
end

# ---------------------------------------------------------------------------
# nemenna predmigracna zaloha
# ---------------------------------------------------------------------------

NxTest.test('2A-1: predmigracna zaloha vznikne RAZ a nikdy sa neprepise') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  backup = A1MAT.pre_schema2_backup_path
  FileUtils.rm_f(backup)
  A1MAT.catalog # seed
  before = File.binread(A1MAT.path)
  target = A1MAT.write_pre_schema2_backup!
  NxTest.assert_equal(backup, target, 'prve volanie zalohu vytvori')
  NxTest.assert_equal(before, File.binread(backup), 'zaloha je bajt-presna kopia katalogu')
  NxTest.assert_equal(File.join(A1MAT.dir, 'materials.pre-schema-2.json'), backup, 'meno podla standardu')
  # katalog sa medzitym zmeni — druhe volanie NESMIE zalohu prepisat
  id = A1MAT.generate_sheet_id('A1 Zaloha', 'DTDL', 18.0)
  A1MAT.upsert_sheet('material_id' => id, 'decor' => 'A1 Zaloha', 'type' => 'DTDL', 'thickness' => 18.0)
  NxTest.refute(before == File.binread(A1MAT.path), 'katalog sa naozaj zmenil')
  NxTest.assert_equal(false, A1MAT.write_pre_schema2_backup!, 'druhe volanie nerobi nic')
  NxTest.assert_equal(before, File.binread(backup), 'obsah zalohy ostal nedotknuty')
  A1MAT.delete_sheet(id)
  FileUtils.rm_f(backup)
end

# ---------------------------------------------------------------------------
# nove polia sa NESU (dual-mode) — merge-safe ako code/supplier
# ---------------------------------------------------------------------------

NxTest.test('2A-1: normalize prenasa group_id/decor_name/structure/universal') do
  s = A1MAT.normalize_sheet('material_id' => 'A1S', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18,
                            'group_id' => ' GRP-1 ', 'decor_name' => ' Dub Halifax ', 'structure' => ' ST9 ')
  NxTest.assert_equal('GRP-1', s['group_id'])
  NxTest.assert_equal('Dub Halifax', s['decor_name'])
  NxTest.assert_equal('ST9', s['structure'])
  bare = A1MAT.normalize_sheet('material_id' => 'A1S2', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18)
  %w[group_id decor_name structure].each { |k| NxTest.refute(bare.key?(k), "prazdne #{k} sa neuklada") }
  cleared = A1MAT.normalize_sheet(s.merge('structure' => ''))
  NxTest.refute(cleared.key?('structure'), 'prazdna hodnota pole VYMAZE (merge-safe)')

  e = A1MAT.normalize_edge('abs_id' => 'A1E', 'decor' => 'X', 'thickness' => 1.0,
                           'group_id' => 'GRP-1', 'structure' => 'MG', 'universal' => true)
  NxTest.assert_equal('GRP-1', e['group_id'])
  NxTest.assert_equal('MG', e['structure'])
  NxTest.assert_equal(true, e['universal'])
  NxTest.assert_equal(true, A1MAT.normalize_edge('abs_id' => 'A1E', 'decor' => 'X', 'thickness' => 1.0,
                                                 'universal' => 'true')['universal'], 'text z payloadu')
  [nil, false, '', '0', 'nie'].each do |v|
    NxTest.refute(A1MAT.normalize_edge('abs_id' => 'A1E', 'decor' => 'X', 'thickness' => 1.0,
                                       'universal' => v).key?('universal'),
                  "universal=#{v.inspect} sa neuklada (priznak je VEDOMY)")
  end
end

NxTest.test('2A-1: PATCHABLE sa NEROZSIRUJE — identita nikdy cez inline patch') do
  %w[sheet edge].each do |kind|
    fields = A1MAT::PATCHABLE[kind]
    %w[group_id structure decor_name universal decor type thickness width sheet_size].each do |f|
      NxTest.refute(fields.include?(f), "#{kind}: #{f} nesmie byt patchovatelne")
    end
  end
  NxTest.assert_equal(%w[code supplier price_per_m2], A1MAT::PATCHABLE['sheet'])
  NxTest.assert_equal(%w[code supplier price_per_bm], A1MAT::PATCHABLE['edge'])
end

NxTest.test('2A-1: lookup variantov v SCHEMA 1 strukturu ignoruje (dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  id = A1MAT.generate_sheet_id('A1 Lookup', 'DTDL', 18.0)
  A1MAT.upsert_sheet('material_id' => id, 'decor' => 'A1 Lookup', 'type' => 'DTDL',
                     'thickness' => 18.0, 'structure' => 'ST9')
  found = A1MAT.find_sheet_variant('A1 Lookup', 'dtdl', 18.0)
  NxTest.assert_equal(id, found && found['material_id'], 'typ case-insensitive, struktura sa neriesi')
  NxTest.assert(A1MAT.find_sheet_variant('A1 Lookup', 'DTDL', 18.0, 'MG'),
                'schema 1: ina struktura je STALE ten isty variant')
  NxTest.assert_equal(nil, A1MAT.find_sheet_variant('A1 Lookup', 'DTDL', 36.0))
  eid = A1MAT.generate_edge_id('A1 Lookup', 1.0, 22)
  A1MAT.upsert_edge('abs_id' => eid, 'decor' => 'A1 Lookup', 'thickness' => 1.0,
                    'width' => 22.0, 'structure' => 'MG')
  NxTest.assert_equal(eid, A1MAT.find_edge_variant('A1 Lookup', 22, 1.0)['abs_id'])
  NxTest.assert(A1MAT.find_edge_variant('A1 Lookup', 22, 1.0, 'UM'), 'schema 1: struktura sa neriesi')
  NxTest.assert_equal(nil, A1MAT.find_edge_variant('A1 Lookup', nil, 1.0), 'sirka JE identita')
  A1MAT.delete_sheet(id)
  A1MAT.delete_edge(eid)
end

NxTest.test('2A-1 GH P2: hranicna tolerancia hrubky drzi legacy spravanie (18.004 vs 18.006)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  id = A1MAT.generate_sheet_id('A1 Tol', 'DTDL', 18.004)
  A1MAT.upsert_sheet('material_id' => id, 'decor' => 'A1 Tol', 'type' => 'DTDL', 'thickness' => 18.004)
  found = A1MAT.find_sheet_variant('A1 Tol', 'DTDL', 18.006)
  NxTest.assert_equal(id, found && found['material_id'],
                      'kluc kvantizuje na 0,01, ale dup guard porovnava tolerancne (legacy abs<0.01)')
  NxTest.assert(A1MAT.identity_keys_tolerant?([:x, 18.0], [:x, 18.004]), 'tolerantne kluce')
  NxTest.refute(A1MAT.identity_keys_tolerant?([:x, 18.0], [:x, 18.02]), 'mimo tolerancie = rozne')
  NxTest.refute(A1MAT.identity_keys_tolerant?([:a, 18.0], [:b, 18.0]), 'nefloat zlozky presne')
  A1MAT.delete_sheet(id)
end

NxTest.test('2A-1 GH P2: SCHEMA 2 guardy — group_id clear, PD clear no-op, PD format v batch dedupe') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a1_with_schema2 do
    # (a) prazdny group_id NEsmie ticho vymazat kotvu skupiny
    existing = { 'type' => 'DTDL', 'group_id' => 'GRP-X', 'structure' => 'ST9' }
    err = A1MAT.identity_edit_error({ 'group_id' => '' }, existing)
    NxTest.assert(err && err.include?('skupina'), 'clear group_id = zmena identity')
    NxTest.assert_equal(nil, A1MAT.identity_edit_error({ 'group_id' => 'GRP-X' }, existing),
                        'rovnaka hodnota prejde')
    # (b) clear_sheet_size na PD BEZ formatu je no-op (editor flag posiela vzdy)
    pd_bez = { 'type' => 'PD', 'structure' => '' }
    NxTest.assert_equal(nil, A1MAT.identity_edit_error({ 'clear_sheet_size' => true }, pd_bez),
                        'no-op clear prejde')
    pd_s = { 'type' => 'PD', 'sheet_size' => [4100.0, 600.0] }
    NxTest.assert(A1MAT.identity_edit_error({ 'clear_sheet_size' => true }, pd_s),
                  'skutocny clear formatu = zmena identity')
    # (c) batch dedup: dva PD 38 s ROZNYM formatom su v SCHEMA 2 dva varianty
    ok, out = A1MAT.dedup_sheet_entries([['PD', 38.0, [4100.0, 600.0], :chip],
                                         ['PD', 38.0, [4100.0, 920.0], :chip]], true)
    NxTest.assert(ok, 'rozne formaty PD nie su duplicita')
    NxTest.assert_equal(2, out.length)
    ok2, = A1MAT.dedup_sheet_entries([['PD', 38.0, [4100.0, 600.0], :chip],
                                      ['PD', 38.0, [600.0, 4100.0], :chip]], true)
    NxTest.refute(ok2, 'rovnaky format (usporiadana dvojica) = duplicita')
  end
end
