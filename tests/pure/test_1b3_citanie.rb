# frozen_string_literal: true
# 1b-3 (brana G bloku 1b) — „Obnoviť" je CISTE CITANIE.
#
# CO BOLO ZLE: `ProductionCore.fresh_collect` (jediny zber pre kusovnik, semafor,
# klik-select aj vsetky styri exporty) spustal pred kazdym citanim `dedup_copies`
# — prepis ID duplicitnych kopii, cize REALNU operaciu a krok Späť. Obycajne
# „Obnoviť" teda potichu ZAPISOVALO do modelu.
#
# CO PLATI: citanie nezapisuje. Duplicitna identita sa PRIZNA ako ORANGE nalez
# Kontroly (`Validation::CAT_DUP_ID`) a opravu spusti az REALNA akcia zapisu
# (dedup tik observera po kopirovani, `Panel.push_selected` po zapise z panela).
#
# Sada ma dve casti:
#   1. GUARD nad zdrojakom — v CELEJ UI vrstve nesmie byt volanie `dedup_copies`.
#      Formuluje sa nad CELYM priecinkom (lekcia review #223: zoznam mien metod
#      sa sam nikdy nedopise), takze vratenie opravy do KTOREJKOLVEK citacej
#      cesty okna sadu zhodi.
#   2. SPRAVANIE novej kontroly — cisty `Validation.run` nad fixturami `identities`
#      v presne tom tvare, aky zbiera `Bom.collect`.
require_relative '../helper' unless defined?(NxTest)

module Nx1b3Fix
  module_function

  V = Noxun::Engine::Validation
  ROOT = File.expand_path('../../noxun_engine', __dir__)

  def ui_files
    Dir[File.join(ROOT, 'ui', '**', '*.rb')].sort
  end

  def core_files
    Dir[File.join(ROOT, 'core', '**', '*.rb')].sort
  end

  # Riadky kodu bez komentarov — komentar smie o dedupe HOVORIT (a hovori,
  # aby to nikto nevratil spat), volanie tam byt nesmie.
  def code_lines(path)
    File.read(path, encoding: 'UTF-8').lines.reject { |l| l.strip.start_with?('#') }
  end

  def hits(path)
    code_lines(path).each_with_index
                    .select { |l, _i| l.include?('dedup_copies') }
                    .map { |l, i| "#{File.basename(path)}:#{i + 1}: #{l.strip}" }
  end

  def ident(id, kind: 'cabinet')
    { 'kind' => kind, 'id' => id }
  end

  def run(identities)
    V.run({ records: [], hardware_overrides: [], warnings: [] },
          sheets: {}, identities: identities)
  end

  def dups(out)
    out['items'].select { |i| i['category'] == V::CAT_DUP_ID }
  end

  def pc_src
    File.read(File.join(ROOT, 'ui', 'production_core.rb'), encoding: 'UTF-8')
  end
end

# --- 1. GUARD nad zdrojakom -------------------------------------------------

NxTest.test('1b-3 GUARD: v celej UI vrstve nie je ANI JEDNO volanie `dedup_copies`') do
  found = Nx1b3Fix.ui_files.flat_map { |p| Nx1b3Fix.hits(p) }
  NxTest.assert(found.empty?,
                "citacie cesty okien nesmu menit model — najdene: #{found.join(' | ')}")
end

NxTest.test('1b-3 GUARD: dedup ostava VYHRADNE v zapisovej ceste (buildery + observer)') do
  callers = Nx1b3Fix.core_files.reject { |p| Nx1b3Fix.hits(p).empty? }
                    .map { |p| File.basename(p) }.sort
  # cabinet_builder/board_builder = DEFINICIA metody, scale_observer = jediny
  # volajuci (dedup tik po kopirovani, transparentny k pouzivatelovmu kroku).
  NxTest.assert_equal(%w[board_builder.rb cabinet_builder.rb scale_observer.rb], callers)
end

NxTest.test('1b-3 GUARD: `fresh_collect` robi UZ LEN zber (dokaz, ze guard nemeria prazdno)') do
  body = Nx1b3Fix.pc_src[/def fresh_collect\(model\).*?\n      end\n/m].to_s
  NxTest.assert(body.include?('Bom.collect(model)'), 'zber tam je')
  code = body.lines.reject { |l| l.strip.start_with?('#') || l.strip.empty? }
  NxTest.assert_equal(3, code.length,
                      "telo je `def` + `Bom.collect` + `end`, nic viac: #{code.map(&:strip).inspect}")
end

NxTest.test('1b-3 GUARD: OBE volania `Validation.run` v jadre posielaju `identities:`') do
  runs = Nx1b3Fix.pc_src.scan(/Validation\.run\((.*?)\)\['items'\]|Validation\.run\((.*?)\)\n/m)
  # Spolahlivejsie nez rozbor argumentov: pocet volani a pocet `identities:` musi sedet.
  n_run = Nx1b3Fix.pc_src.scan('Validation.run(').length
  n_ident = Nx1b3Fix.pc_src.scan('identities: collected[:identities]').length
  NxTest.assert_equal(2, n_run, 'jadro vola kontrolu na dvoch miestach (payload okna + klik-select)')
  NxTest.assert_equal(n_run, n_ident,
                      'a KAZDE z nich musi duplicitne identity priznat — inak by ich videlo len jedno')
  NxTest.assert(runs.length.positive?)
end

# --- 2. SPRAVANIE kontroly --------------------------------------------------

NxTest.test('1b-3: dve skrinky s tym istym ID = 1 ORANGE nalez (varuje, neblokuje)') do
  f = Nx1b3Fix
  out = f.run([f.ident('CAB-001'), f.ident('CAB-001')])
  d = f.dups(out)
  NxTest.assert_equal(1, d.length)
  NxTest.assert_equal('orange', d.first['severity'])
  NxTest.assert_equal(0, out['counts']['red'])
  NxTest.assert_equal(1, out['counts']['orange'])
end

NxTest.test('1b-3: hlaska nesie ID, POCET kusov aj VYROBNY dosledok (kovanie sa zapocita raz)') do
  f = Nx1b3Fix
  msg = f.dups(f.run([f.ident('CAB-007')] * 3)).first['message_sk']
  NxTest.assert(msg.include?('CAB-007'), "ID v hlaske: #{msg}")
  NxTest.assert(msg.include?('3'), "pocet kusov v hlaske: #{msg}")
  NxTest.assert(msg.include?('kovanie'), "dosledok pre objednavku v hlaske: #{msg}")
end

NxTest.test('1b-3: pri DOSKACH sa o kovani nehovori (dosky ho nemaju)') do
  f = Nx1b3Fix
  msg = f.dups(f.run([f.ident('BRD-002', kind: 'board')] * 2)).first['message_sk']
  NxTest.assert(msg.include?('Dosky s ID BRD-002'), msg)
  NxTest.refute(msg.include?('kovanie'), "doskova hlaska o kovani mlci: #{msg}")
end

NxTest.test('1b-3: unikatne ID nevyrobia NIC (nula falosnych poplachov)') do
  f = Nx1b3Fix
  out = f.run([f.ident('CAB-001'), f.ident('CAB-002'), f.ident('BRD-001', kind: 'board')])
  NxTest.assert_equal(0, f.dups(out).length)
  NxTest.assert_equal(0, out['counts']['total'])
end

NxTest.test('1b-3: to iste ID v INOM druhu nie je duplicita (skrinka a doska su iny svet)') do
  f = Nx1b3Fix
  out = f.run([f.ident('X-1'), f.ident('X-1', kind: 'board')])
  NxTest.assert_equal(0, f.dups(out).length)
end

NxTest.test('1b-3: prazdne / chybajuce ID sa NEPOROVNAVA (poskodeny objekt je ina chyba)') do
  f = Nx1b3Fix
  out = f.run([{ 'kind' => 'cabinet', 'id' => '' }, { 'kind' => 'cabinet', 'id' => '  ' },
               { 'kind' => 'cabinet' }, { 'id' => 'CAB-001' }, 'nie hash'])
  NxTest.assert_equal(0, f.dups(out).length)
end

NxTest.test('1b-3: BEZ `identities:` sa nemeni NIC (legacy volania a stare testy)') do
  f = Nx1b3Fix
  out = Nx1b3Fix::V.run({ records: [], hardware_overrides: [], warnings: [] }, sheets: {})
  NxTest.assert_equal(0, f.dups(out).length)
  NxTest.assert_equal(0, out['counts']['total'])
end

NxTest.test('1b-3: klik-adresa je v TOM ISTOM tvare ako pri D-103 — `pids_for_duplicate` ju vie precitat') do
  f = Nx1b3Fix
  it = f.dups(f.run([f.ident('CAB-003')] * 2)).first
  NxTest.assert_equal('cabinet', it['dup_kind'])
  NxTest.assert_equal(['CAB-003'], it['dup_owner_ids'])
  NxTest.assert_equal('CAB-003', it['owner_id'])
  NxTest.assert(it['part_key'].nil?, 'nalez patri CELEMU kusu, nie dielcu')
  # a jadro tuto kategoriu naozaj smeruje na spolocne telo (inak by vseobecna
  # vetva pribalila aj odpojene dielce s tym istym cabinet_id)
  branch = Nx1b3Fix.pc_src[/def pids_for_problem\(model, item\).*?\n        oid =/m].to_s
  NxTest.assert(branch.include?('CAT_DUP_ID'), 'pids_for_problem pozna novu kategoriu')
  NxTest.assert(branch.include?('pids_for_duplicate'), 'a posiela ju na zdielane telo')
end

NxTest.test('1b-3: stabilny kluc rozlisuje druh aj ID — dva nezavisle nalezy sa nezlejú') do
  f = Nx1b3Fix
  out = f.run([f.ident('CAB-001'), f.ident('CAB-001'),
               f.ident('CAB-009'), f.ident('CAB-009'),
               f.ident('BRD-004', kind: 'board'), f.ident('BRD-004', kind: 'board')])
  keys = f.dups(out).map { |i| i['stable_key'] }
  NxTest.assert_equal(3, keys.length)
  NxTest.assert_equal(keys.length, keys.uniq.length)
  NxTest.assert(keys.include?('duplicate_identity|cabinet|CAB-001'), keys.inspect)
  NxTest.assert(keys.include?('duplicate_identity|board|BRD-004'), keys.inspect)
end

NxTest.test('1b-3: vysledok je DETERMINISTICKY — nezavisi od poradia entit v modeli') do
  f = Nx1b3Fix
  base = [f.ident('CAB-009'), f.ident('CAB-009'),
          f.ident('BRD-004', kind: 'board'), f.ident('BRD-004', kind: 'board'),
          f.ident('CAB-001'), f.ident('CAB-001')]
  a = f.dups(f.run(base)).map { |i| i['stable_key'] }
  b = f.dups(f.run(base.reverse)).map { |i| i['stable_key'] }
  NxTest.assert_equal(a, b)
end

NxTest.test('1b-3: `Bom.add_identity` zapisuje jeden zaznam na INSTANCIU a prazdne ID zahadzuje') do
  out = []
  b = Noxun::Engine::Bom
  b.add_identity(out, 'cabinet', 'CAB-001')
  b.add_identity(out, 'cabinet', 'CAB-001')
  b.add_identity(out, 'board', '  BRD-002  ')
  b.add_identity(out, 'board', '')
  b.add_identity(out, 'board', nil)
  NxTest.assert_equal([{ 'kind' => 'cabinet', 'id' => 'CAB-001' },
                       { 'kind' => 'cabinet', 'id' => 'CAB-001' },
                       { 'kind' => 'board', 'id' => 'BRD-002' }], out)
end
