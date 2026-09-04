# frozen_string_literal: true
# D-112 + D-113 (3.9.2026, dielna — zakazka KLINIKA): VEPO kontrakt v1.1.
#
#   D-112 — dielec s pasku v INOM dekore, nez ma doska, sa do objednavky VEPO
#           prepisuje rucne do pola „Poznámka pre VEPO"; na to sa da zabudnut a
#           z vyroby pride zly olep. Plugin rozdiel POZNA (hrana nesie abs_id,
#           katalog vie dekor pasky aj dosky), takze ho povie sam: DEVIATY stlpec
#           CSV `poznamka` + kontrolny oddiel v LOGu.
#   D-113 — dielce prichadzaju z VEPO oznacene nazvom z CSV („Dno", „Bok lavy"),
#           takze pri skladani nie je vidno, ku ktorej skrinke patria. Nazov
#           riadku preto nesie SKRATKY dielcov a skrinky („Bok LP s1 s2").
#           Nalepky VEPO tlacia ~20 znakov bez interpunkcie — kratky tvar je tam
#           jediny citatelny; orez dalsich skriniek do „ +K" je vedomy.
#
# Bajtove vzorky CSV su v test_vepo_export.rb (tam sa kontrakt zamyka), tu je
# SPRAVANIE: kedy poznamka vznikne, ako sa sklada nazov a co sa NEMENI.
require_relative '../helper' unless defined?(NxTest)
require 'tmpdir'
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxD112
  module_function

  def vepo
    Noxun::Engine::VepoExport
  end

  MATS = { 'BIELA_18' => { 'label' => 'Biela DTD' } }.freeze
  ETHS = { 'ABS_BIELA' => 1.0, 'ABS_DUB' => 1.0, 'ABS_TAUPE' => 2.0 }.freeze
  # Mapy dekorov presne v tvare, aky sklada ProductionCore — vratane `group_id`
  # (GH #287 P1: zavazna identita vazby doska<->ABS je SKUPINA, nie text kodu).
  EDEC = {
    'ABS_BIELA' => { 'decor' => 'W1000', 'decor_name' => 'Biela', 'group_id' => 'G-BIELA' },
    'ABS_DUB'   => { 'decor' => 'H1181', 'decor_name' => 'Dub Halifax tabakový', 'group_id' => 'G-DUB' },
    'ABS_TAUPE' => { 'decor' => 'U750', 'decor_name' => 'Taupe sivá', 'group_id' => 'G-TAUPE' },
    'ABS_HOLY'  => { 'decor' => '', 'decor_name' => '', 'group_id' => '' }
  }.freeze
  SDEC = { 'BIELA_18' => { 'decor' => 'W1000', 'group_id' => 'G-BIELA' } }.freeze

  def row(over = {})
    { 'names' => ['Dno'], 'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0,
      'quantity' => 1, 'material_id' => 'BIELA_18', 'grain_direction' => 'length',
      'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
      'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 1 }] }.merge(over)
  end

  def edges(l1 = nil, l2 = nil, w1 = nil, w2 = nil)
    { 'L1' => l1, 'L2' => l2, 'W1' => w1, 'W2' => w2 }
  end

  def note(over = {}, edec = EDEC, sdec = SDEC)
    vepo.abs_note(row(over), edec, sdec)
  end

  def build(rows, over = {})
    args = { project: 'Klinika', materials: MATS, edge_thicknesses: ETHS,
             edge_decors: EDEC, sheet_decors: SDEC,
             version: '9.9.9', generated_at: 'TEST-CAS', merge_18_36: true }.merge(over)
    vepo.build(rows, **args)
  end

  # Prvy CSV riadok rozbity na polia (bez uvodzoviek) — na kontrolu poctu stlpcov.
  def fields(csv)
    csv.split("\r\n").first.to_s.split(';').map { |f| f.sub(/\A"/, '').sub(/"\z/, '') }
  end
end

# --- D-112: poznamka o odlisnej ABS ----------------------------------------

NxTest.test('D-112: paska v INOM dekore nez doska ide do poznamky (kod + nazov dekoru)') do
  NxTest.assert_equal('ABS H1181 Dub Halifax tabakový',
                      NxD112.note('edges' => NxD112.edges('ABS_DUB')))
end

NxTest.test('D-112: paska v dekore DOSKY poznamku NEROBI (bezny dielec ostava ticho)') do
  NxTest.assert_equal('', NxD112.note('edges' => NxD112.edges('ABS_BIELA', 'ABS_BIELA')))
end

NxTest.test('D-112: legacy zaznam bez skupiny — fallback na text je odolny voci medzeram a velkosti pismen') do
  # Zhodna normalizacia s Materials.decor_norm_key (D-41: dekor = kluc skupiny).
  edec = { 'ABS_X' => { 'decor' => 'W1000', 'decor_name' => 'Biela' } }
  sdec = { 'BIELA_18' => { 'decor' => ' w 1000 ' } }
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_X') }, edec, sdec))
end

# --- GH #287 P1: identita vazby je SKUPINA, nie text kodu -------------------

NxTest.test('P1: rovnaky KOD dekoru v ROZNYCH skupinach = poznamka JE (dva vyrobcovia)') do
  # Katalog vedome dovoli dvom vyrobcom rovnaky kod dekoru v roznych skupinach.
  # Porovnanie len podla textu by ich vyhlasilo za zhodu a poznamka by TICHO
  # chybala — presne to je vyrobna chyba (zly olep).
  edec = { 'ABS_CUDZI' => { 'decor' => 'W1000', 'decor_name' => 'Biela iného výrobcu',
                            'group_id' => 'G-INY' } }
  sdec = { 'BIELA_18' => { 'decor' => 'W1000', 'group_id' => 'G-BIELA' } }
  NxTest.assert_equal('ABS W1000 Biela iného výrobcu',
                      NxD112.note({ 'edges' => NxD112.edges('ABS_CUDZI') }, edec, sdec))
end

NxTest.test('P1: rovnaka SKUPINA = ziadna poznamka, aj ked sa text kodu lisi') do
  # Skupina je zdroj pravdy — inak zapisany kod v ramci JEDNEJ skupiny (D-41
  # near-match guard ho aj tak nepusti dvakrat) nesmie robit falosnu poznamku.
  edec = { 'ABS_A' => { 'decor' => 'W1000 ST9', 'decor_name' => 'Biela', 'group_id' => 'G-BIELA' } }
  sdec = { 'BIELA_18' => { 'decor' => 'W1000', 'group_id' => 'G-BIELA' } }
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_A') }, edec, sdec))
end

NxTest.test('P1: legacy bez `group_id` (na oboch stranach) padne na text — oba smery') do
  # Chyba len skupina PASKY
  edec_a = { 'ABS_A' => { 'decor' => 'H1181', 'decor_name' => 'Dub' } }
  sdec_g = { 'BIELA_18' => { 'decor' => 'W1000', 'group_id' => 'G-BIELA' } }
  NxTest.assert_equal('ABS H1181 Dub', NxD112.note({ 'edges' => NxD112.edges('ABS_A') }, edec_a, sdec_g))
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_W') },
                                      { 'ABS_W' => { 'decor' => 'W1000' } }, sdec_g))
  # Chyba len skupina DOSKY
  sdec_p = { 'BIELA_18' => { 'decor' => 'W1000' } }
  NxTest.assert_equal('ABS H1181 Dub Halifax tabakový',
                      NxD112.note({ 'edges' => NxD112.edges('ABS_DUB') }, NxD112::EDEC, sdec_p))
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_BIELA') }, NxD112::EDEC, sdec_p))
end

NxTest.test('P1: holy String v mape dosiek = legacy volajuci, cita sa ako samotny dekor') do
  NxTest.assert_equal('ABS H1181 Dub Halifax tabakový',
                      NxD112.note({ 'edges' => NxD112.edges('ABS_DUB') }, NxD112::EDEC,
                                  { 'BIELA_18' => 'W1000' }))
end

NxTest.test('P1: zaznam bez skupiny AJ bez dekoru je neporovnatelny — ziadna poznamka') do
  edec = { 'ABS_PRAZDNA' => { 'decor' => '', 'decor_name' => 'Nič', 'group_id' => '' } }
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_PRAZDNA') }, edec, NxD112::SDEC))
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_DUB') }, NxD112::EDEC,
                                      { 'BIELA_18' => { 'decor' => '', 'group_id' => '' } }))
end

NxTest.test('P1: doska SO SKUPINOU, ale bez dekoru, sa stale porovnava (skupina staci)') do
  sdec = { 'BIELA_18' => { 'decor' => '', 'group_id' => 'G-BIELA' } }
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_BIELA') }, NxD112::EDEC, sdec),
                      'zhodna skupina mlci aj bez textu dekoru')
  NxTest.assert_equal('ABS H1181 Dub Halifax tabakový',
                      NxD112.note({ 'edges' => NxD112.edges('ABS_DUB') }, NxD112::EDEC, sdec))
end

NxTest.test('D-112: neznama paska, neznama doska ani prazdny dekor NEHADAJU poznamku') do
  # neznamy abs_id (v katalogu nie je) — hlasi ho KONTROLA aj oddiel vyradenych
  NxTest.assert_equal('', NxD112.note('edges' => NxD112.edges('ABS_NEZNAMA')))
  # doska mimo mapy (napr. UNI material alebo material mimo katalogu)
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_DUB') }, NxD112::EDEC, {}))
  # paska s prazdnym dekorom
  NxTest.assert_equal('', NxD112.note('edges' => NxD112.edges('ABS_HOLY')))
  # ziadne mapy vobec (legacy volajuci) = ziadna poznamka
  NxTest.assert_equal('', NxD112.note({ 'edges' => NxD112.edges('ABS_DUB') }, {}, {}))
end

NxTest.test('D-112: dve RÔZNE pasky = "A, B" v poradi hran, bez duplicit') do
  n = NxD112.note('edges' => NxD112.edges('ABS_DUB', 'ABS_TAUPE', 'ABS_DUB', 'ABS_BIELA'))
  NxTest.assert_equal('ABS H1181 Dub Halifax tabakový, ABS U750 Taupe sivá', n)
end

NxTest.test('D-112: paska bez nazvu dekoru ide do poznamky len kodom') do
  edec = { 'ABS_X' => { 'decor' => 'K097' } }
  NxTest.assert_equal('ABS K097', NxD112.note({ 'edges' => NxD112.edges('ABS_X') }, edec))
end

NxTest.test('D-112: CSV ma VZDY 9 stlpcov — poznamka je prazdny retazec, nie chybajuce pole') do
  plain = NxD112.build([NxD112.row])
  NxTest.assert_equal(9, NxD112.fields(plain['groups'].first['csv']).length)
  NxTest.assert_equal('', NxD112.fields(plain['groups'].first['csv'])[8])
  NxTest.assert(plain['groups'].first['csv'].end_with?(";\"\"\r\n"), 'prazdna poznamka je "" v uvodzovkach')

  noted = NxD112.build([NxD112.row('edges' => NxD112.edges('ABS_DUB'))])
  f = NxD112.fields(noted['groups'].first['csv'])
  NxTest.assert_equal(9, f.length)
  NxTest.assert_equal('ABS H1181 Dub Halifax tabakový', f[8], 'diakritika ostava (cita ju clovek vo VEPO)')
end

NxTest.test('D-112: poznamka NEMENI grouping, nazvy suborov, rozmery ani pocet riadkov') do
  rows = [NxD112.row('edges' => NxD112.edges('ABS_DUB')), NxD112.row('names' => ['Vrch'])]
  bare = NxD112.build(rows, edge_decors: {}, sheet_decors: {})
  full = NxD112.build(rows)
  NxTest.assert_equal(bare['groups'].map { |g| g['filename'] }, full['groups'].map { |g| g['filename'] })
  NxTest.assert_equal(bare['total_rows'], full['total_rows'])
  NxTest.assert_equal(bare['total_pieces'], full['total_pieces'])
  # jediny rozdiel v CSV je 9. stlpec
  strip9 = ->(csv) { csv.split("\r\n").map { |l| l.sub(/;"[^"]*"\z/, '') } }
  NxTest.assert_equal(strip9.call(bare['groups'].first['csv']), strip9.call(full['groups'].first['csv']),
                      'prvych osem stlpcov je bajtovo zhodnych s v1.0 spravanim')
end

NxTest.test('D-112: `universal` pasky sa NEVYNIMAJU — VEPO odvodzuje pasku z materialu') do
  # V katalogu je H1181 paska universal=true; poznamka ju MUSI ukazat, inak by
  # VEPO olepilo dielec paskou dekoru dosky.
  NxTest.assert_equal('ABS H1181 Dub Halifax tabakový',
                      NxD112.note('edges' => NxD112.edges(nil, nil, 'ABS_DUB')))
end

# --- D-112: LOG oddiel „Poznámky pre VEPO" ---------------------------------

NxTest.test('D-112: LOG ma oddiel Poznamky pre VEPO s nazvom riadku, suborom a textom') do
  out = NxD112.build([NxD112.row('edges' => NxD112.edges('ABS_DUB')),
                      NxD112.row('names' => ['Vrch'], 'edges' => NxD112.edges('ABS_TAUPE'))])
  log = out['log_text']
  NxTest.assert(log.include?('Poznámky pre VEPO (2 riadkov):'), log)
  NxTest.assert(log.include?('  * Dno s1 [klinika_biela_dtd_18_36.csv]: ABS H1181 Dub Halifax tabakový'), log)
  NxTest.assert(log.include?('  * Vrch s1 [klinika_biela_dtd_18_36.csv]: ABS U750 Taupe sivá'), log)
  # poradie oddielov: vyradene riadky -> poznamky -> KONTROLA
  NxTest.assert(log.index('Riadky vyradené z CSV') < log.index('Poznámky pre VEPO'), 'oddiel je za vyradenymi')
  NxTest.assert(log.index('Poznámky pre VEPO') < log.index('KONTROLA'), 'oddiel je pred KONTROLOU')
end

NxTest.test('D-112: bez poznamok ma LOG oddiel s nulou a jasnou vetou') do
  log = NxD112.build([NxD112.row])['log_text']
  NxTest.assert(log.include?('Poznámky pre VEPO (0 riadkov):'), log)
  NxTest.assert(log.include?('(žiadne — všetky pásky v dekore dosky)'), log)
end

NxTest.test('D-112: sekcia KONTROLA ostava BAJTOVO nezmenena (poznamka je vedla nej)') do
  validation = { 'items' => [{ 'severity' => 'red', 'message_sk' => 'Testovací nález' }],
                 'counts' => { 'red' => 1, 'orange' => 0, 'total' => 1 } }
  log = NxD112.build([NxD112.row('edges' => NxD112.edges('ABS_DUB'))], validation: validation)['log_text']
  control = log[/#{Regexp.escape('KONTROLA')}.*\z/m]
  NxTest.assert_equal("KONTROLA — 1 kritických (RED), 0 na kontrolu (ORANGE):\r\n" \
                      "  [RED]    Testovací nález\r\n" \
                      "  Pozn.: RED je varovanie, export sa neblokuje.\r\n", control)
end

# --- D-113: skratky nazvov --------------------------------------------------

NxTest.test('D-113: tabulka skratiek sedi na SKUTOCNE nazvy builderov') do
  v = NxD112.vepo
  {
    'Bok lavy' => 'Bok L', 'Bok pravy' => 'Bok P',
    'Vystuha predna' => 'Vyst P', 'Vystuha zadna' => 'Vyst Z',
    'Sokel predny' => 'Sokel',
    'Priecka zvisla' => 'Priecka Z', 'Priecka vodorovna' => 'Priecka V',
    'Dvierka 1 lave' => 'Dv1 L', 'Dvierka 12 prave' => 'Dv12 P',
    'Dvierka 2 kridlo 3/4' => 'Dv2 k3', 'Dvierka 7' => 'Dv7',
    'Zasuvkove celo 3' => 'Zas celo 3',
    # bez zmeny (kratke uz dnes / volny text)
    'Dno' => 'Dno', 'Vrch' => 'Vrch', 'Chrbat' => 'Chrbat', 'Polica 2' => 'Polica 2',
    'Blenda 1' => 'Blenda 1', 'Výklop 2' => 'Výklop 2', 'Sklop 1' => 'Sklop 1'
  }.each { |from, to| NxTest.assert_equal(to, v.short_name(from), "skratka #{from.inspect}") }
end

NxTest.test('D-113: neznamy nazov ide BEZ ZMENY (samostatna doska = volny text)') do
  v = NxD112.vepo
  NxTest.assert_equal('Polička pod TV', v.short_name('Polička pod TV'))
  NxTest.assert_equal('Dvierka lave', v.short_name('Dvierka lave'), 'bez cisla to nie je nas vzor')
  NxTest.assert_equal('', v.short_name(nil))
end

NxTest.test('D-113: zdruzenie dvojic LP / PZ / Dv<N> LP, ostatne cez /') do
  v = NxD112.vepo
  NxTest.assert_equal('Bok LP', v.row_name('names' => ['Bok lavy', 'Bok pravy']))
  NxTest.assert_equal('Vyst PZ', v.row_name('names' => ['Vystuha predna', 'Vystuha zadna']))
  NxTest.assert_equal('Dv2 LP', v.row_name('names' => ['Dvierka 2 lave', 'Dvierka 2 prave']))
  # rozne cisla dvierok sa NEZDRUZUJU
  NxTest.assert_equal('Dv1 L/Dv2 P', v.row_name('names' => ['Dvierka 1 lave', 'Dvierka 2 prave']))
  # len jeden clen paru = ziadne zdruzenie
  NxTest.assert_equal('Bok L', v.row_name('names' => ['Bok lavy']))
  # ostatne rozne nazvy = '/', poradie podla `names`
  NxTest.assert_equal('Vrch/Dno', v.row_name('names' => %w[Vrch Dno]))
  NxTest.assert_equal('Bok LP/Dno', v.row_name('names' => ['Bok lavy', 'Dno', 'Bok pravy']),
                      'zdruzeny token drzi poziciu PRVEHO clena')
end

NxTest.test('D-113: skrinky z `kde` — s<N>, d<N>, unikatne a zoradene podla cisla') do
  v = NxD112.vepo
  kde = [{ 'owner_id' => 'CAB-012' }, { 'owner_id' => 'BRD-007' }, { 'owner_id' => 'CAB-001' },
         { 'owner_id' => 'CAB-012' }]
  NxTest.assert_equal('Dno s1 s12 d7', v.row_name('names' => ['Dno'], 'kde' => kde))
  NxTest.assert_equal('Dno', v.row_name('names' => ['Dno'], 'kde' => []), 'prazdne kde = bez pripony')
  NxTest.assert_equal('Dno', v.row_name('names' => ['Dno']), 'chybajuce kde = bez pripony')
  # neznamy tvar ID sa NEZAHADZUJE (informacia o mieste dielca je cennejsia)
  NxTest.assert_equal('Dno s1 LEGACY-X',
                      v.row_name('names' => ['Dno'], 'kde' => [{ 'owner_id' => 'LEGACY-X' },
                                                               { 'owner_id' => 'CAB-1' }]))
end

NxTest.test('D-113: orez na NAME_MAX — " +K" namiesto odseknutej skratky') do
  v = NxD112.vepo
  kde = (1..30).map { |i| { 'owner_id' => format('CAB-%03d', i) } }
  name = v.row_name('names' => ['Bok lavy', 'Bok pravy'], 'kde' => kde)
  NxTest.assert(name.length <= 60, "#{name.length}: #{name}")
  NxTest.assert(name.start_with?('Bok LP s1 s2 s3'), name)
  NxTest.assert(name =~ / \+\d+\z/, "koniec zhrnie nezmestene skrinky: #{name}")
  # ziadna skratka nie je rozseknuta v polovici
  shown = name.sub(/ \+\d+\z/, '').split(' ')[2..] || []
  NxTest.assert(shown.all? { |t| kde.any? { |k| "s#{k['owner_id'][/\d+/].to_i}" == t } },
                "kazdy vypisany token je CELE ID: #{shown.inspect}")
  # a pocet za '+' sedi s tym, co sa nezmestilo
  NxTest.assert_equal(30 - shown.length, name[/\+(\d+)\z/, 1].to_i)
end

NxTest.test('D-113: samotny nazov nad limit = dnesny orez s vypustkou, skrinky sa nepridavaju') do
  v = NxD112.vepo
  name = v.row_name('names' => ['X' * 100], 'kde' => [{ 'owner_id' => 'CAB-001' }])
  NxTest.assert_equal(60, name.length)
  NxTest.assert(name.end_with?('…'), name)
  NxTest.refute(name.include?('s1'), 'na skrinky uz miesto nie je')
end

# --- GH #287 P2: volny nazov samostatnej dosky sa neskracuje ani nepari -----

NxTest.test('P2: doska pomenovana ako dielec skrinky ide BEZ ZMENY') do
  v = NxD112.vepo
  row = { 'names' => ['Bok lavy'], 'free_names' => ['Bok lavy'],
          'kde' => [{ 'owner_id' => 'BRD-003' }] }
  NxTest.assert_equal('Bok lavy d3', v.row_name(row), 'volny text pouzivatela sa NESKRACUJE')
  # ten isty nazov z BUILDERA sa skracuje ako doteraz
  NxTest.assert_equal('Bok L s1', v.row_name('names' => ['Bok lavy'],
                                             'kde' => [{ 'owner_id' => 'CAB-001' }]))
end

NxTest.test('P2: dielec skrinky + doska v jednom riadku sa NEPARUJU do „Bok LP"') do
  # `Bom.aggregate_rows` zlucuje podla VYROBNYCH parametrov, takze dielec „Bok lavy"
  # a doska „Bok P" mozu skoncit v jednom riadku. Par by tvrdil, ze ide o zrkadlovu
  # dvojicu jednej skrinky — a to nie je pravda.
  row = { 'names' => ['Bok lavy', 'Bok P'], 'free_names' => ['Bok P'],
          'kde' => [{ 'owner_id' => 'CAB-001' }, { 'owner_id' => 'BRD-002' }] }
  NxTest.assert_equal('Bok L/Bok P s1 d2', NxD112.vepo.row_name(row))
end

NxTest.test('P2: volny nazov, ktory skratku aj tak nema, ostava nezmeneny') do
  v = NxD112.vepo
  NxTest.assert_equal('Dno d1', v.row_name('names' => ['Dno'], 'free_names' => ['Dno'],
                                           'kde' => [{ 'owner_id' => 'BRD-001' }]))
  NxTest.assert_equal('Polička pod TV d1',
                      v.row_name('names' => ['Polička pod TV'], 'free_names' => ['Polička pod TV'],
                                 'kde' => [{ 'owner_id' => 'BRD-001' }]))
end

NxTest.test('P2: ten isty retazec od dosky AJ od skrinky = konzervativne pass-through') do
  # Povod sa neda rozhodnut, tak sa nehada: nazov ostava cely a nepari sa.
  row = { 'names' => ['Bok lavy', 'Bok pravy'], 'free_names' => ['Bok lavy'],
          'kde' => [{ 'owner_id' => 'CAB-001' }, { 'owner_id' => 'BRD-002' }] }
  NxTest.assert_equal('Bok lavy/Bok P s1 d2', NxD112.vepo.row_name(row))
end

NxTest.test('P2: `free_names` nie su, tak sa nic nemeni (legacy riadok)') do
  NxTest.assert_equal('Bok LP', NxD112.vepo.row_name('names' => ['Bok lavy', 'Bok pravy']))
end

NxTest.test('P2: Bom.aggregate_rows zbiera `free_names` z DOSIEK a nemeni agregaciu') do
  bom = Noxun::Engine::Bom
  base = { 'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0, 'material_id' => 'M1',
           'grain_direction' => 'none', 'quantity' => 1,
           'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  records = [
    base.merge('name' => 'Bok lavy', 'owner_id' => 'CAB-001', 'part_key' => 'cabinet/side:left', 'pid' => 1),
    base.merge('name' => 'Bok P', 'owner_id' => 'BRD-002', 'part_key' => 'board/main', 'pid' => 2)
  ]
  rows = bom.aggregate_rows(records)
  NxTest.assert_equal(1, rows.length, 'zhodne vyrobne parametre = JEDEN riadok (agregacia nezmenena)')
  NxTest.assert_equal(['Bok lavy', 'Bok P'], rows.first['names'])
  NxTest.assert_equal(['Bok P'], rows.first['free_names'], 'volny nazov je LEN ten z dosky')
  NxTest.assert_equal(2, rows.first['quantity'])
  NxTest.assert_equal('Bok L/Bok P s1 d2', NxD112.vepo.row_name(rows.first),
                      'cela cesta BOM -> VEPO drzi povod nazvu')
  # riadok bez dosky ma kluc prazdny (nikdy nil — citatel nemusi branit)
  only_cab = bom.aggregate_rows([records.first])
  NxTest.assert_equal([], only_cab.first['free_names'])
end

NxTest.test('P2: doska bez `part_key` sa pozna podla `owner_id` BRD-<cislo>') do
  bom = Noxun::Engine::Bom
  rec = { 'name' => 'Bok lavy', 'owner_id' => 'BRD-007', 'part_key' => '', 'pid' => 3,
          'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0, 'material_id' => 'M1',
          'grain_direction' => 'none', 'quantity' => 1,
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  NxTest.assert_equal(['Bok lavy'], bom.aggregate_rows([rec]).first['free_names'])
end

NxTest.test('D-113: fallback „dielec" a `name` bez `names` platia dalej') do
  v = NxD112.vepo
  NxTest.assert_equal('dielec', v.row_name('names' => []))
  NxTest.assert_equal('Bok L s1', v.row_name('name' => 'Bok lavy',
                                             'kde' => [{ 'owner_id' => 'CAB-001' }]))
end

# --- mapy dekorov zo ZIVEHO katalogu (ProductionCore) -----------------------

NxTest.test('D-112: vepo_edge_decors a vepo_sheet_decors drzia kontrakt mapy') do
  NxTest.skip!('vyzaduje headless sandbox katalogu') unless NxTest.headless?
  mat = Noxun::Engine::Materials
  core = Noxun::Engine::ProductionCore
  tmp = Dir.mktmpdir('nx-d112-')
  catalog = {
    'schema' => 2,
    'sheets' => [
      { 'material_id' => 'REAL_18', 'family' => 'DTDL', 'decor' => 'H1181', 'group_id' => 'G-H1181',
        'thickness' => 18.0, 'production_class' => 'sheet' },
      { 'material_id' => 'KORPUS_UNI_18', 'family' => 'UNI', 'decor' => 'Korpus UNI',
        'thickness' => 18.0, 'production_class' => 'sheet', 'uni' => true, 'uni_role' => 'body' }
    ],
    'edges' => [
      { 'abs_id' => 'ABS_H1181', 'decor' => 'H1181', 'decor_name' => 'Dub Halifax tabakový',
        'group_id' => 'G-H1181', 'thickness' => 0.8, 'universal' => true },
      { 'abs_id' => 'ABS_U750', 'decor' => 'U750', 'thickness' => 2.0 }
    ]
  }
  File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(catalog))
  mat.test_dir_override = tmp
  mat.reset_catalog_state!
  mat.reload!
  begin
    edec = core.vepo_edge_decors
    NxTest.assert_equal(%w[ABS_H1181 ABS_U750], edec.keys.sort, 'mapa pokryva VSETKY pasky katalogu')
    NxTest.assert_equal('H1181', edec['ABS_H1181']['decor'])
    NxTest.assert_equal('Dub Halifax tabakový', edec['ABS_H1181']['decor_name'])
    NxTest.assert_equal('G-H1181', edec['ABS_H1181']['group_id'], 'P1: mapa nesie identitu skupiny')
    NxTest.assert_equal('', edec['ABS_U750']['decor_name'], 'chybajuci nazov dekoru = prazdny retazec')
    NxTest.assert_equal('', edec['ABS_U750']['group_id'], 'chybajuca skupina = prazdny retazec (legacy)')

    sdec = core.vepo_sheet_decors
    NxTest.assert_equal(['REAL_18'], sdec.keys, 'UNI doska v mape NIE JE — jej „dekor" nie je dekor')
    NxTest.assert_equal({ 'decor' => 'H1181', 'group_id' => 'G-H1181' }, sdec['REAL_18'],
                        'P1: hodnota je ZAZNAM (dekor + skupina), nie holy String')
    # skupina rozhoduje: paska tej istej skupiny mlci, cudzia s rovnakym kodom nie
    NxTest.assert_equal('', NxD112.vepo.abs_note(
      { 'material_id' => 'REAL_18', 'edges' => NxD112.edges('ABS_H1181') }, edec, sdec
    ))
    # a preto UNI dielec s paskou ziadnu poznamku nedostane (KONTROLA ho hlasi zvlast)
    NxTest.assert_equal('', NxD112.vepo.abs_note(
      { 'material_id' => 'KORPUS_UNI_18', 'edges' => NxD112.edges('ABS_H1181') }, edec, sdec
    ))
  ensure
    # Sandbox po sebe upratuje VZDY (aj vo FAIL vetve) — inak by dalsie sady
    # citali cudzi katalog (kontrakt test_dir_override).
    mat.test_dir_override = nil
    mat.reset_catalog_state!
    mat.reload!
    FileUtils.rm_rf(tmp)
  end
end
