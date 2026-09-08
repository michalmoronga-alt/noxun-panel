# frozen_string_literal: true
# D-121b (8.9.2026) — VEPO KONTRAKT v1.2: NAZOV RIADKU MA VZDY NAJVIAC 20 ZNAKOV.
#
# Michal 7.9.2026 overil v praxi, ze IMPORT objednavky VEPO pole `nazov` nad 20
# znakov ODMIETA. Kontrakt v1.1 pritom tvrdil, ze 20 je len tlac nalepky a pole
# nesie 60 — dlhe riadky sa preto pred odoslanim prepisovali RUCNE. Revizia v1.2.
#
# Co sa overuje:
#   1) `NAME_MAX` je 20 a je to JEDINA autorita limitu (validation.rb ho cita)
#   2) ZLUCOVANIE CISEL v riadku: `Polica 1/Polica 2/Polica 3` -> `Polica 1 2 3`,
#      vyhradne pre tokeny zo skratky GENEROVANEHO nazvu (volne nazvy dosiek nie)
#   3) `cut_name` — deterministicky orez po HRANICI TOKENU, nikdy cez cislo
#      dielca a NIKDY s vypustkou `…` (audit Astra, nalez 1)
#   4) `row_name_info` — orez ani stratena skrinka nie su TICHE: `build` vracia
#      `shortened` (s `filename` az po dedupe, s rozmermi a vlastnikmi — audit
#      nalez 3) a LOG ma oddiel „Skratene nazvy"
#   5) KONTROLA hodnoti AGREGOVANE RIADKY, nie jednotlive zaznamy (audit nalez 2):
#      dve kratke dosky v jednom riadku sa orezu a semafor to MUSI povedat
#   6) guard: kazdy kratky tvar dielca + vlastnik `s12` sa do 20 znakov zmesti
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1 `NAME_MAX` spat na 60                     -> testy limitu a orezu
#   M2 zlucovanie cisel zluci aj VOLNE nazvy     -> „Polička 1/Polička 2"
#   M3 tvrdy rez cez cislo (`Polica … 7 1`)      -> regres z auditu
#   M4 KONTROLA hodnoti zaznamy, nie riadky      -> dve kratke dosky prejdu ticho
#   M5 LOG oddiel chyba pri nule                 -> „Skratene nazvy (0):"
#   M6 `filename` priradeny PRED `dedup_filenames!` -> kolizia slugov
require_relative '../helper' unless defined?(NxTest)

module NxD121b
  V = Noxun::Engine::Validation
  B = Noxun::Engine::Bom

  module_function

  def vepo
    Noxun::Engine::VepoExport
  end

  MATS = { 'BIELA_18' => { 'label' => 'Biela DTD' } }.freeze
  FILE = 'klinika_biela_dtd_18_36.csv'
  CAB  = [{ 'owner_id' => 'CAB-001', 'quantity' => 1 }].freeze
  SHEETS = {
    'BIELA_18' => { 'material_id' => 'BIELA_18', 'thickness' => 18.0,
                    'sheet_size' => [2800.0, 2070.0], 'grain' => 'length' }
  }.freeze

  # --- BOM riadok (vstup `VepoExport.build`) --------------------------------
  def row(over = {})
    { 'names' => ['Dno'], 'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0,
      'quantity' => 1, 'material_id' => 'BIELA_18', 'grain_direction' => 'length',
      'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
      'kde' => CAB.dup }.merge(over)
  end

  def build(rows, over = {})
    args = { project: 'Klinika', materials: MATS,
             version: '9.9.9', generated_at: 'TEST-CAS', merge_18_36: true }.merge(over)
    vepo.build(rows, **args)
  end

  # `row_name` z riadku so samotnymi nazvami (kde = jedna skrinka).
  def name(names, over = {})
    vepo.row_name({ 'names' => names, 'kde' => CAB.dup }.merge(over))
  end

  def full(names, over = {})
    vepo.row_name_info({ 'names' => names, 'kde' => CAB.dup }.merge(over))['full']
  end

  # --- zaznam zberu (vstup `Validation.run`) --------------------------------
  # Hrana L1 je zamerne olepena — bez nej by `free_panel` dostal ORANGE
  # „bez ABS" a testy poctov by merali nieco ine.
  def rec(over = {})
    { 'name' => 'Dno', 'part_key' => 'cabinet/x', 'owner_id' => 'CAB-1', 'pid' => 1,
      'role' => 'shelf', 'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0,
      'quantity' => 1, 'material_id' => 'BIELA_18', 'grain_direction' => 'length',
      'edges' => { 'L1' => 'ABS1', 'L2' => nil, 'W1' => nil, 'W2' => nil } }.merge(over)
  end

  # Samostatna doska: `part_key` v namespace `board/` + `owner_id` BRD-<cislo>
  # (presne to, podla coho `Bom.free_board_record?` pozna volny text pouzivatela).
  def board(text, owner = 'BRD-1', over = {})
    rec({ 'name' => text, 'part_key' => 'board/main', 'owner_id' => owner,
          'role' => 'free_panel' }.merge(over))
  end

  def control(records)
    V.run({ records: records, hardware_overrides: [], warnings: [] }, sheets: SHEETS)
  end

  def long_items(records)
    control(records)['items'].select { |i| i['category'] == V::CAT_NAME_LONG }
  end
end

# --- 1) limit -------------------------------------------------------------

NxTest.test('D-121b: NAME_MAX je 20 — jedina autorita limitu (kontrakt v1.2)') do
  NxTest.assert_equal(20, NxD121b.vepo.const_get(:NAME_MAX),
                      'import VEPO pole nad 20 znakov odmieta (Michal 7.9.2026)')
end

# --- 2) zlucovanie cislovanych tokenov -------------------------------------

NxTest.test('D-121b: rovnake dielce s cislom sa v riadku zluia do jedneho tokenu') do
  d = NxD121b
  NxTest.assert_equal('Polica 1 2 3 s1', d.name(['Polica 1', 'Polica 2', 'Polica 3']))
  NxTest.assert_equal('Zas dno 1 2 s1', d.name(['Dno zasuvky 1', 'Dno zasuvky 2']))
  NxTest.assert_equal('Zas celo 1 2 3 s1',
                      d.name(['Zasuvkove celo 1', 'Zasuvkove celo 2', 'Zasuvkove celo 3']))
  # cisla su unikatne a VZOSTUPNE (nie v poradi prichodu)
  NxTest.assert_equal('Polica 1 12 s1', d.name(['Polica 12', 'Polica 1']))
  # zluci sa aj to, co uz vzniklo parovanim bokov boxu
  NxTest.assert_equal('Zas bok LP 1 2 s1',
                      d.name(['Bok boxu lavy 1', 'Bok boxu pravy 1',
                              'Bok boxu lavy 2', 'Bok boxu pravy 2']))
end

NxTest.test('D-121b: cislo MUSI byt na konci tokenu — `Dv1 LP`/`Dv2 LP` sa nezluia') do
  d = NxD121b
  NxTest.assert_equal('Dv1 LP/Dv2 LP s1',
                      d.name(['Dvierka 1 lave', 'Dvierka 1 prave',
                              'Dvierka 2 lave', 'Dvierka 2 prave']),
                      'cislo je vnutri skratky, nie je to poradove cislo dielcov')
  NxTest.assert_equal('Dv1/Dv2 s1', d.name(['Dvierka 1', 'Dvierka 2']))
end

NxTest.test('M2: VOLNE nazvy dosiek sa NEZLUCUJU, ani ked vyzeraju cislovane') do
  d = NxD121b
  free = %w[Polička\ 1 Polička\ 2]
  NxTest.assert_equal('Polička 1/Polička 2', d.full(free, 'free_names' => free),
                      'volny text pouzivatela: „Polička 1" a „Polička 2" mozu byt dve rozne veci')
  # zmieseny riadok (jeden nazov z buildera, druhy z dosky) sa tiez nezluci
  mix = ['Polica 1', 'Polica 2']
  NxTest.assert_equal('Polica 1/Polica 2', d.full(mix, 'free_names' => ['Polica 2']))
  # ...a bez `free_names` sa ten isty riadok zluci
  NxTest.assert_equal('Polica 1 2', d.full(mix))
end

NxTest.test('D-121b: zluceny token stoji na POZICII PRVEHO clena') do
  NxTest.assert_equal('Polica 1 2/Dno s1', NxD121b.name(['Polica 1', 'Dno', 'Polica 2']))
end

# --- 3) cut_name: orez po hranici tokenu, bez vypustky ---------------------

NxTest.test('M3: orez NIKDY nerozsekne cislo dielca (audit Astra, nalez 1)') do
  v = NxD121b.vepo
  # 21 znakov: tvrdy rez by dal „…7 1" a stitok by uvadzal policu 1 namiesto 10
  NxTest.assert_equal('Polica 2 3 4 5 6 7', v.cut_name('Polica 2 3 4 5 6 7 10'))
end

NxTest.test('D-121b: `cut_name` — hranica tokenu, `/` bez konca, jedno dlhe slovo') do
  v = NxD121b.vepo
  # do limitu = bez zmeny (aj presne na 20)
  NxTest.assert_equal('Dno s1', v.cut_name('Dno s1'))
  NxTest.assert_equal('X' * 20, v.cut_name('X' * 20))
  # rez padne PRESNE na hranicu (21. znak je medzera) -> berie sa cely `head`
  NxTest.assert_equal('Doska pod umyvadlo A', v.cut_name('Doska pod umyvadlo A B'))
  # rez na '/' — vysledok nikdy nekonci oddelovacom
  NxTest.assert_equal('Dno/Vrch/Chrbat/Bok', v.cut_name('Dno/Vrch/Chrbat/Bok/Polica'))
  # jedno dlhe slovo (volny nazov dosky) oddelovac nema -> tvrdy rez na 20
  NxTest.assert_equal('X' * 20, v.cut_name('X' * 25))
  # DIAKRITIKA je jeden znak (nie bajt): „Polička pod televízorom veľká" ma 29
  NxTest.assert_equal(29, 'Polička pod televízorom veľká'.length)
  NxTest.assert_equal('Polička pod', v.cut_name('Polička pod televízorom veľká'))
end

NxTest.test('D-121b: v ziadnom `row_name` nie je vypustka a nic nepresiahne 20') do
  d = NxD121b
  [['X' * 100], ['Doska pod umyvadlo velka'], ['Polica 2', 'Polica 3', 'Polica 40'],
   ['Dno', 'Vrch', 'Chrbat', 'Polica 1'], ['Polička pod televízorom veľká']].each do |names|
    got = d.name(names)
    NxTest.assert(got.length <= 20, "#{names.inspect} -> #{got.inspect} (#{got.length})")
    NxTest.refute(got.include?('…'), "vypustka minie znak z 20: #{got.inspect}")
  end
end

# --- 4) row_name_info + `shortened` + LOG ---------------------------------

NxTest.test('D-121b: `row_name_info` povie DOVOD — orez aj nezmestena skrinka') do
  v = NxD121b.vepo
  cut = v.row_name_info('names' => ['Doska pod umyvadlo velka'], 'kde' => NxD121b::CAB.dup)
  NxTest.assert_equal('Doska pod umyvadlo', cut['name'])
  NxTest.assert_equal('Doska pod umyvadlo velka', cut['full'], 'plny tvar sa nestraca')
  NxTest.assert_equal(true, cut['cut'])
  NxTest.assert_equal([1, 0], [cut['owners_total'], cut['owners_shown']],
                      'orez vycerpal limit — skrinka sa uz nepridava')
  # nazov presne na 20 znakov: orez NIE, ale skrinka sa uz nezmesti
  six = (1..6).map { |i| "Zasuvkove celo #{i}" }
  full = v.row_name_info('names' => six, 'kde' => NxD121b::CAB.dup)
  NxTest.assert_equal('Zas celo 1 2 3 4 5 6', full['name'])
  NxTest.assert_equal(false, full['cut'])
  NxTest.assert_equal([1, 0], [full['owners_total'], full['owners_shown']])
  # bezny riadok: nic sa nedeje
  ok = v.row_name_info('names' => ['Dno'], 'kde' => NxD121b::CAB.dup)
  NxTest.assert_equal(['Dno s1', false, 1, 1],
                      [ok['name'], ok['cut'], ok['owners_total'], ok['owners_shown']])
end

NxTest.test('D-121b: `build` vracia `shortened` s filenamom, rozmermi, ks a vlastnikmi') do
  d = NxD121b
  out = d.build([d.row('names' => ['Doska pod umyvadlo velka'],
                       'free_names' => ['Doska pod umyvadlo velka'], 'length' => 800.0,
                       'quantity' => 2, 'kde' => [{ 'owner_id' => 'BRD-007' }])])
  NxTest.assert_equal(1, out['shortened'].length)
  NxTest.assert_equal({ 'full' => 'Doska pod umyvadlo velka', 'name' => 'Doska pod umyvadlo',
                        'reason' => 'cut', 'length' => 800, 'width' => 500, 'thickness' => 18,
                        'quantity' => 2, 'owners' => ['BRD-007'], 'filename' => NxD121b::FILE },
                      out['shortened'].first)
  # do CSV ide OREZANY nazov
  NxTest.assert(out['groups'].first['csv'].start_with?('"Doska pod umyvadlo";'),
                out['groups'].first['csv'])
end

NxTest.test('audit 3: dva rozne nazvy s rovnakym orezom su v LOGu rozlisitelne rozmermi') do
  d = NxD121b
  rows = [d.row('names' => ['Doska pod umyvadlo velka'], 'length' => 800.0,
                'kde' => [{ 'owner_id' => 'BRD-007' }]),
          d.row('names' => ['Doska pod umyvadlo mala'], 'length' => 600.0,
                'kde' => [{ 'owner_id' => 'BRD-008' }])]
  out = d.build(rows)
  NxTest.assert_equal(['Doska pod umyvadlo', 'Doska pod umyvadlo'],
                      out['shortened'].map { |s| s['name'] }, 'oba sa orezu na to iste')
  log = out['log_text']
  NxTest.assert(log.include?('Skrátené názvy (2):'), log)
  NxTest.assert(log.include?("  * Doska pod umyvadlo velka -> Doska pod umyvadlo [#{NxD121b::FILE}] " \
                             '— 800×500×18, 1 ks @ BRD-007'), log)
  NxTest.assert(log.include?("  * Doska pod umyvadlo mala -> Doska pod umyvadlo [#{NxD121b::FILE}] " \
                             '— 600×500×18, 1 ks @ BRD-008'), log)
end

NxTest.test('M5: LOG ma oddiel „Skrátené názvy" AJ pri nule a v spravnom poradi') do
  d = NxD121b
  log = d.build([d.row])['log_text']
  NxTest.assert(log.include?('Skrátené názvy (0):'), log)
  NxTest.assert(log.include?('  (žiadne)'), log)
  NxTest.assert(log.index('Riadky vyradené z CSV') < log.index('Skrátené názvy'),
                'oddiel je ZA vyradenymi riadkami')
  NxTest.assert(log.index('Skrátené názvy') < log.index('Poznámky pre VEPO'),
                'oddiel je PRED poznamkami')
  NxTest.assert(log.index('Poznámky pre VEPO') < log.index('KONTROLA'))
end

NxTest.test('D-121b: riadok bez skrinky v nazve je v LOGu, ale NIE v Kontrole') do
  d = NxD121b
  six = (1..6).map { |i| "Zasuvkove celo #{i}" }
  out = d.build([d.row('names' => six)])
  s = out['shortened'].first
  NxTest.assert_equal('no_owner', s['reason'])
  NxTest.assert_equal('Zas celo 1 2 3 4 5 6', s['name'])
  NxTest.assert(out['log_text'].include?("  * Zas celo 1 2 3 4 5 6 [#{NxD121b::FILE}] — " \
                                         'bez skrinky v názve (CAB-001): 600×500×18, 1 ks'),
                out['log_text'])
  # Kontrola mlci — nie je to strata dielca, len horsia orientacia v dielni
  recs = six.each_with_index.map { |n, i| d.rec('name' => n, 'part_key' => "front:F#{i}/panel") }
  NxTest.assert_equal([], d.long_items(recs).map { |i| i['message_sk'] })
end

NxTest.test('D-121b: vyradeny riadok ukaze v LOGu aj PLNY nazov') do
  d = NxD121b
  out = d.build([d.row('names' => ['Doska pod umyvadlo velka'], 'thickness' => 0.0)])
  NxTest.assert_equal(1, out['errors'].length)
  NxTest.assert_equal('Doska pod umyvadlo velka', out['errors'].first['full'])
  NxTest.assert(out['log_text'].include?('! Doska pod umyvadlo (plný názov: Doska pod umyvadlo velka)'),
                out['log_text'])
end

NxTest.test('M6: `filename` v `shortened` je az PO dedupe nazvov suborov') do
  d = NxD121b
  # 'Dub-A' a 'Dub A' sa slugnu na to iste — druhy subor dostane pripona `_2`.
  mats = { 'M1' => { 'label' => 'Dub-A' }, 'M2' => { 'label' => 'Dub A' } }
  long = ['Doska pod umyvadlo velka']
  out = d.build([d.row('names' => long, 'material_id' => 'M1'),
                 d.row('names' => long, 'material_id' => 'M2')],
                materials: mats)
  NxTest.assert_equal(%w[klinika_dub_a_18_36.csv klinika_dub_a_18_36_2.csv],
                      out['groups'].map { |g| g['filename'] }.sort)
  NxTest.assert_equal(%w[klinika_dub_a_18_36.csv klinika_dub_a_18_36_2.csv],
                      out['shortened'].map { |s| s['filename'] }.sort,
                      'pred dedupom by oba niesli ten isty nazov suboru')
  NxTest.refute(out['groups'].first.key?('shortened'), 'docasny kluc zo skupiny zmizne')
end

# --- 5) KONTROLA hodnoti RIADKY, nie zaznamy (audit nalez 2) ---------------

NxTest.test('M4: dve KRATKE dosky v jednom riadku = jeden nalez (per zaznam by Kontrola mlcala)') do
  d = NxD121b
  # obe pod 20 znakov, ale zhodne vyrobne parametre = JEDEN riadok CSV
  recs = [d.board('Doska pod umyvadlo', 'BRD-1'), d.board('Polica nad pracku', 'BRD-2')]
  NxTest.assert(recs.all? { |r| r['name'].length < 20 }, 'kazda doska sama je pod limitom')
  items = d.long_items(recs)
  NxTest.assert_equal(1, items.length, 'jeden riadok = jeden nalez')
  row = NxD121b::B.aggregate_rows(recs).first
  NxTest.assert_equal(1, NxD121b::B.aggregate_rows(recs).length, 'zhodne parametre = JEDEN riadok')
  msg = items.first['message_sk']
  NxTest.assert(msg.include?('„Doska pod umyvadlo/Polica nad pracku“ má 36 znakov'), msg)
  NxTest.assert(msg.include?('VEPO prijme najviac 20'), msg)
  NxTest.assert(msg.include?("pôjde ako „#{d.vepo.row_name(row)}“"),
                "hlaska ukazuje PRESNE to, co pojde do CSV: #{msg}")
  NxTest.assert(msg.include?('Skráť názov dosky (Doska pod umyvadlo, Polica nad pracku).'), msg)
  NxTest.assert_equal('orange', items.first['severity'])
  NxTest.assert_equal(nil, items.first['part_key'], 'riadok nie je jeden dielec')
  NxTest.assert_equal('BRD-1', items.first['owner_id'], 'klik mieri na prveho vlastnika')
end

NxTest.test('D-121b: dlha doska sama = nalez s hintom „Skráť názov dosky"') do
  d = NxD121b
  items = d.long_items([d.board('Polica nad velkou prackou')])
  NxTest.assert_equal(1, items.length)
  NxTest.assert(items.first['message_sk'].include?('pôjde ako „Polica nad velkou“'),
                items.first['message_sk'])
  NxTest.assert(items.first['message_sk'].include?('Skráť názov dosky (Polica nad velkou prackou).'),
                items.first['message_sk'])
end

NxTest.test('audit 2: dielec skrinky + dlha doska v riadku — hlaska ukaze SPOLOCNY orez') do
  d = NxD121b
  recs = [d.rec, d.board('Polica nad velkou prackou', 'BRD-1')]
  items = d.long_items(recs)
  NxTest.assert_equal(1, items.length)
  msg = items.first['message_sk']
  NxTest.assert(msg.include?('„Dno/Polica nad velkou prackou“'), msg)
  NxTest.assert(msg.include?('pôjde ako „Dno/Polica nad“'),
                "orez SPOLOCNEHO nazvu, nie orez samotnej dosky: #{msg}")
end

NxTest.test('D-121b: doska presne na 20 znakov = ziadny nalez') do
  d = NxD121b
  NxTest.assert_equal(20, 'Polica nad prackou A'.length)
  NxTest.assert_equal([], d.long_items([d.board('Polica nad prackou A')]))
end

NxTest.test('D-121b: generovana kombinacia nad limit = nalez s hintom o LOGu') do
  d = NxD121b
  names = ['Dno', 'Vrch', 'Polica 1', 'Polica 2', 'Polica 3']
  recs = names.each_with_index.map { |n, i| d.rec('name' => n, 'part_key' => "cabinet/p#{i}") }
  out = d.control(recs)
  items = out['items'].select { |i| i['category'] == 'name_long' }
  NxTest.assert_equal(1, items.length)
  msg = items.first['message_sk']
  NxTest.assert(msg.include?('„Dno/Vrch/Polica 1 2 3“ má 21 znakov'), msg)
  NxTest.assert(msg.include?('Sú to dielce skrinky CAB-1'), msg)
  NxTest.assert(msg.include?('plný tvar je v LOGu exportu.'), msg)
  NxTest.assert_equal(1, out['counts']['orange'], out['items'].inspect)
  NxTest.assert_equal(0, out['counts']['red'])
end

NxTest.test('D-121b: `stable_key` je medzi dvoma behmi `run` ROVNAKY (klik-select)') do
  d = NxD121b
  recs = [d.board('Doska pod umyvadlo', 'BRD-1'), d.board('Polica nad pracku', 'BRD-2')]
  a = d.long_items(recs).map { |i| i['stable_key'] }
  b = d.long_items(recs).map { |i| i['stable_key'] }
  NxTest.assert_equal(a, b)
  NxTest.assert_equal(['name_long|Doska pod umyvadlo/Polica nad pracku|BIELA_18|6000x5000x180'], a,
                      'kluc = kategoria + plny nazov + material + rozmery v desatinach mm')
end

NxTest.test('D-121b: Kontrola znesie zaznamy BEZ `edges`, `quantity` a `material_source`') do
  d = NxD121b
  # legacy/fixturovy tvar: `Bom.aggregate_rows` by na nich padol, preto sa
  # vstup doplna na strane Kontroly (nie zmenou `Bom`).
  bare = { 'name' => 'Doska pod umyvadlo velka', 'owner_id' => 'BRD-9',
           'part_key' => 'board/main', 'role' => 'shelf', 'material_id' => 'BIELA_18',
           'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0 }
  items = d.long_items([bare, 'nie je hash', nil])
  NxTest.assert_equal(1, items.length, 'zaznam bez polí prejde, smeti sa preskocia')
end

# --- 6) guardy -------------------------------------------------------------

NxTest.test('D-121b guard: kazdy kratky tvar + vlastnik `s12` sa zmesti do 20 znakov') do
  v = NxD121b.vepo
  # regexove tvary sa najprv OVERIA proti `short_name` (guard nesmie testovat
  # retazce, ktore modul v skutocnosti nevyrabia)
  { 'Dvierka 12 lave' => 'Dv12 L', 'Dvierka 12 prave' => 'Dv12 P',
    'Dvierka 12 kridlo 4/4' => 'Dv12 k4', 'Dvierka 12' => 'Dv12',
    'Zasuvkove celo 12' => 'Zas celo 12', 'Dno zasuvky 12' => 'Zas dno 12',
    'Chrbat zasuvky 12' => 'Zas chrb 12', 'Vnutorne celo zasuvky 12' => 'Zas predok 12',
    'Bok boxu lavy 12' => 'Zas bok L 12', 'Bok boxu pravy 12' => 'Zas bok P 12',
    'Priecka vodorovna' => 'Priecka V', 'Sokel predny' => 'Sokel' }
    .each { |from, to| NxTest.assert_equal(to, v.short_name(from), "skratka #{from.inspect}") }

  forms = v.const_get(:SHORT_NAMES).values +
          ['Dv12 L', 'Dv12 P', 'Dv12 LP', 'Dv12 k4', 'Dv12', 'Zas celo 12', 'Zas dno 12',
           'Zas chrb 12', 'Zas predok 12', 'Zas bok L 12', 'Zas bok P 12', 'Zas bok LP 12',
           'Bok LP', 'Vyst PZ']
  forms.each do |f|
    got = "#{f} s12"
    NxTest.assert(got.length <= 20, "#{got.inspect} ma #{got.length} znakov — nad 20")
  end
end

NxTest.test('D-121b guard: limit zije LEN vo `vepo_export.rb` (validation.rb ho cita)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'validation.rb'),
                  encoding: 'UTF-8')
  NxTest.assert(src.include?('VepoExport::NAME_MAX'),
                'validation.rb musi citat limit z VepoExport, nie ho opakovat')
  NxTest.refute(src.match?(/NAME_MAX\s*=/), 'validation.rb NESMIE definovat vlastny NAME_MAX')
  # v KODE kontroly nazvov nesmie byt ziadny cislovy literal limitu
  # (komentare sa vypustaju — text o limite v nich zit smie)
  body = src[/def check_name_lengths.*?def dim_key.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'sekcia kontroly nazvov sa nenasla — premenovana?')
  code = body.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.refute(code.match?(/(?<![\w.])20(?![\w.])/),
                "literal 20 v kontrole nazvov — limit ma JEDNU autoritu:\n#{code}")
end
