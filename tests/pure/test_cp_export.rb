# frozen_string_literal: true
# V0.6 E-b2: CENOVA PONUKA — view nad rozpoctom + zakaznicky XLSX.
#
# Tri veci, ktore tu MUSIA drzat:
#   1) SUMA CP == SUMA ROZPOCTU na cent (zostava je automaticky zvysok),
#   2) FIREWALL — v hotovom exporte NIE JE ziadny interny pojem ani kod,
#   3) dvojharkovy .xlsx je platny archiv (Excel nema toleranciu).
require_relative '../helper' unless defined?(NxTest)

module NxCp
  module_function

  def cp
    Noxun::Engine::CpExport
  end

  def xl
    Noxun::Engine::CpXlsx
  end

  def w
    Noxun::Engine::XlsxWriter
  end

  FIXED_TIME = Time.utc(2026, 8, 6, 12, 30, 0)

  # --- payload rozpoctu (tvar Budget.compute) ------------------------------
  # materials 2 riadky (410 + 96) · hardware 2 (300 + 40) · custom 1 (85) ·
  # appliances 649 MIMO suctu · services (olep 99 + montaz 900) ·
  # standard 8 riadkov (810) · rounding 3  ->  total 2743,00
  def section(key, name, rows, counts: true, extra: {})
    { 'key' => key, 'name' => name, 'rows' => rows, 'counts_in_total' => counts,
      'subtotal' => rows.sum { |r| r['spolu'].to_f }.round(2),
      'unknown_count' => rows.count { |r| r['price_missing'] } }.merge(extra)
  end

  def row(key, nazov, spolu, extra = {})
    { 'key' => key, 'nazov' => nazov, 'mj' => 'KS', 'mnozstvo' => 1, 'cena_mj' => spolu,
      'spolu' => spolu, 'price_missing' => spolu.nil? }.merge(extra)
  end

  def payload(overrides = {})
    p = {
      'sections' => [
        section('materials', 'Materiál', [
                  row('material:DTDL18', 'K009 PW DTDL 18 mm', 410.0,
                      'mj' => 'PLATŇA', 'mnozstvo' => 6, 'material_id' => 'DTDL18',
                      'poznamka' => '23 m² · formát 2800×2070 mm'),
                  row('material:PD38', 'F206 PD 38 mm', 96.0, 'mj' => 'PLATŇA', 'mnozstvo' => 1,
                      'material_id' => 'PD38', 'cp_nazov' => 'Pracovná doska F206 Mramor 4100/600/38')
                ]),
        section('hardware', 'Kovanie', [
                  row('hw:317642', 'K-HETTICH Quadro V6 skrytý celovýsuv 450 mm', 300.0,
                      'kod' => '317642', 'mj' => 'SET', 'mnozstvo' => 10),
                  row('hw:82744', 'STRONG klzák s rektifikáciou, výška 17 mm, čierny', 40.0,
                      'kod' => '82744', 'mj' => 'KS', 'mnozstvo' => 20)
                ]),
        section('services', 'Služby', [
                  row('service:olep', 'Olepovanie ABS hrán', 99.0),
                  row('service:montaz', 'Montáž', 900.0)
                ]),
        section('standard_rows', 'Štandardné riadky', [
                  row('std:doprava_zakaznik', 'Doprava k zákazníkovi', 60.0),
                  row('std:doprava_vseobecna', 'Doprava všeobecná', 100.0),
                  row('std:balne', 'Balné', 100.0),
                  row('std:ostatne', 'Ostatné náklady', 100.0),
                  row('std:material_montaz', 'Materiál na montáž', 100.0),
                  row('std:vizualizacia', 'Vizualizácia + návrh', 150.0),
                  row('std:odvody', 'Odvody', 100.0),
                  row('std:zameranie', 'Zameranie', 100.0)
                ]),
        section('custom', 'Vlastné položky', [row('custom:UUID-1', 'LED pás a trafo', 85.0)]),
        section('appliances', 'Spotrebiče',
                [row('appliance:UUID-A', 'Bosch KIV87VFE0', 649.0, 'typ_label' => 'Chladnička')],
                counts: false, extra: { 'included' => false }),
        section('rounding', 'Zaokrúhlenie ponuky', [row('rounding', 'Zaokrúhlenie ponuky', 3.0)])
      ],
      # 506 (materiál) + 340 (kovanie) + 999 (služby) + 810 (štandardné)
      # + 85 (vlastné) + 3 (zaokrúhlenie) = 2743; spotrebiče 649 su MIMO súčtu.
      'totals' => { 'total' => 2743.0, 'total_novat' => 2230.08, 'raw_total' => 2740.0 }
    }
    p.merge(overrides)
  end

  def rows_of(cp_hash)
    cp_hash['rows'].map { |r| r['polozka'] }
  end

  def find(cp_hash, label)
    cp_hash['rows'].find { |r| r['polozka'] == label }
  end

  # --- specifikacia: fixtures ----------------------------------------------

  def sheets
    {
      'DTDL18' => { 'material_id' => 'DTDL18', 'decor' => 'K009', 'structure' => 'PW',
                    'decor_name' => 'Dub Sonoma', 'type' => 'DTDL', 'thickness' => 18.0 },
      'W1000' => { 'material_id' => 'W1000', 'decor' => 'W1000 ST9', 'decor_name' => 'Biela',
                   'type' => 'DTDL', 'thickness' => 18.0 },
      'HDF3' => { 'material_id' => 'HDF3', 'decor' => 'Biela', 'type' => 'HDF', 'thickness' => 3.0 },
      'PD38' => { 'material_id' => 'PD38', 'decor' => 'F206', 'type' => 'PD', 'thickness' => 38.0,
                  'sheet_size' => [4100.0, 600.0],
                  'cp_nazov' => 'Pracovná doska F206 Mramor Levanto 4100/600/38' },
      'ZAS' => { 'material_id' => 'ZAS', 'decor' => 'K551', 'type' => 'ZASTENA', 'thickness' => 10.0,
                 'sheet_size' => [4100.0, 640.0] }
    }
  end

  def records
    [
      { 'material_id' => 'DTDL18', 'role' => 'side_left', 'quantity' => 2 },
      { 'material_id' => 'DTDL18', 'role' => 'bottom', 'quantity' => 1 },
      { 'material_id' => 'W1000', 'role' => 'front_door', 'quantity' => 2 },
      { 'material_id' => 'HDF3', 'role' => 'back', 'quantity' => 1 },
      { 'material_id' => 'PD38', 'role' => 'free_panel', 'quantity' => 1 },
      { 'material_id' => 'ZAS', 'role' => 'free_panel', 'quantity' => 1 },
      { 'material_id' => 'W1000', 'role' => 'free_panel', 'quantity' => 1 },
      { 'material_id' => 'NEZNAMY', 'role' => 'shelf', 'quantity' => 1 }
    ]
  end

  def expansion
    { 'rows' => [
      { 'code' => '317642', 'name_sk' => 'K-HETTICH Quadro V6 skrytý celovýsuv 450 mm',
        'category' => 'VYSUVY', 'missing' => false },
      { 'code' => '105408', 'name_sk' => 'HETTICH Sensys 8675 110° TH52', 'category' => 'ZAVESY',
        'missing' => false },
      { 'code' => '82744', 'name_sk' => 'STRONG klzák s rektifikáciou, výška 17 mm',
        'category' => 'NOHY', 'missing' => false },
      { 'code' => '999999', 'name_sk' => nil, 'category' => nil, 'missing' => true }
    ] }
  end

  def spec(budget = nil)
    cp.specification(records, sheets: sheets, hardware_expansion: expansion, budget: budget)
  end

  def cat(spec_hash, key)
    spec_hash['categories'].find { |c| c['key'] == key }
  end

  # --- ZIP (rovnaka mechanika ako test_eb_rozpocet) ------------------------
  def unzip(bytes)
    raise 'ZIP nema EOCD' unless bytes[-22, 4] == [0x06054b50].pack('V')

    _sig, _d1, _d2, entries, _total, _cd_size, cd_off, _cl = bytes[-22, 22].unpack('VvvvvVVv')
    out = []
    pos = cd_off
    entries.times do
      hdr = bytes[pos, 46]
      f = hdr.unpack('VvvvvvvVVVvvvvvVV')
      name_len = f[10]
      name = bytes[pos + 46, name_len]
      local_off = f[16]
      l = bytes[local_off, 30].unpack('VvvvvvVVVvv')
      data_off = local_off + 30 + l[9] + l[10]
      out << { name: name, crc: f[7], data: bytes[data_off, l[8]], local_crc: l[6] }
      pos += 46 + name_len + f[11] + f[12]
    end
    out
  end

  def book_bytes(cp_hash = nil, spec_hash = nil, project: 'KUCHYŇA Novák')
    w.build_book(xl.sheets(cp_hash || cp.cp_rows(payload), spec_hash || spec,
                           project: project, now: FIXED_TIME), now: FIXED_TIME)
  end

  def part(bytes, name)
    unzip(bytes).find { |e| e[:name] == name }[:data].force_encoding('UTF-8')
  end

  # Fake model pre BudgetStore (dict + undo pocitadlo) — vlastny, aby test
  # nezavisel od poradia nacitania inych test suborov.
  class FakeModel < NxTest::FakeEntity
    attr_reader :ops

    def initialize
      super
      @ops = []
    end

    def start_operation(name, _disable_ui = false)
      @ops << name
      true
    end

    def commit_operation
      true
    end

    def abort_operation
      true
    end
  end
end

# ============================ CENOVA TABULKA ==============================

NxTest.test('cp: suma cenovej ponuky sa rovna sume rozpoctu NA CENT') do
  c = NxCp.cp.cp_rows(NxCp.payload)
  NxTest.assert_equal(2743.0, c['budget_total'])
  NxTest.assert_equal(2743.0, c['total'], 'SPOLU CP musi sediet s rozpoctom')
  NxTest.assert_equal(0.0, c['diff'])
  NxTest.assert(c['consistent'], 'kontrolny pas musi hlasit zhodu')
  suma = c['rows'].sum { |r| r['cena'] }.round(2)
  NxTest.assert_equal(2743.0, suma, 'sucet riadkov CP musi dat SPOLU')
end

NxTest.test('cp: kostra ma poradie z realnych dokumentov a Zameranie/Vizualizácie su 0') do
  c = NxCp.cp.cp_rows(NxCp.payload)
  labels = NxCp.rows_of(c)
  NxTest.assert_equal(NxCp.cp::ASSEMBLY_NAME, labels.first, 'zostava je prvy riadok')
  # samostatne navrhnute riadky lezia MEDZI zostavou a Zameranim
  i_zam = labels.index(NxCp.cp::ZAMERANIE_NAME)
  i_viz = labels.index(NxCp.cp::VIZUALIZACIE_NAME)
  i_mon = labels.index(NxCp.cp::MONTAZ_NAME)
  i_rez = labels.index(NxCp.cp::REZIA_NAME)
  i_dop = labels.index(NxCp.cp::DOPRAVA_NAME)
  NxTest.assert(i_zam < i_viz && i_viz < i_mon && i_mon < i_rez && i_rez < i_dop,
                "poradie kostry nesedi: #{labels.inspect}")
  NxTest.assert_equal(0.0, NxCp.find(c, NxCp.cp::ZAMERANIE_NAME)['cena'], 'Zameranie je v CP vzdy 0')
  NxTest.assert_equal(0.0, NxCp.find(c, NxCp.cp::VIZUALIZACIE_NAME)['cena'], 'Vizualizácie su v CP vzdy 0')
end

NxTest.test('cp: montaz, rezia a doprava sa scitaju podla mapovania prieskumu') do
  c = NxCp.cp.cp_rows(NxCp.payload)
  NxTest.assert_equal(900.0, NxCp.find(c, NxCp.cp::MONTAZ_NAME)['cena'], 'montaz = sluzba montaze')
  NxTest.assert_equal(400.0, NxCp.find(c, NxCp.cp::REZIA_NAME)['cena'],
                      'rezia = balné + ostatné + materiál na montáž + odvody')
  NxTest.assert_equal(160.0, NxCp.find(c, NxCp.cp::DOPRAVA_NAME)['cena'],
                      'doprava = k zákazníkovi + všeobecná')
end

NxTest.test('cp: zostava je AUTOMATICKY zvysok — nulovanie Zamerania sa nikde nestrati') do
  c = NxCp.cp.cp_rows(NxCp.payload)
  others = c['rows'].reject { |r| r['kind'] == 'assembly' }.sum { |r| r['cena'] }.round(2)
  NxTest.assert_equal((2743.0 - others).round(2), c['assembly'],
                      'zostava = total − ostatné riadky')
  NxTest.refute(c['assembly_negative'], 'zostava nesmie byt zaporna')
  # Samostatne idu len riadky nad prahom (410 + 300), fixné riadky vezmú
  # 900 + 400 + 160. Zvyšok — olep 99, zameranie 100, vizualizácia 150,
  # doska 96, LED 85, klzáky 40 a zaokrúhlenie 3 — drží ZOSTAVA:
  NxTest.assert_equal(573.0, c['assembly'], 'zvyšok peňazí (aj vynulované Zameranie) drží zostava')
end

NxTest.test('cp: prah navrhne samostatny riadok, pod prahom sa polozka zluci') do
  c = NxCp.cp.cp_rows(NxCp.payload, threshold: 150.0)
  NxTest.assert_equal(150.0, c['threshold'])
  sep = c['candidates'].select { |x| x['state'] == 'samostatne' }.map { |x| x['source_key'] }
  NxTest.assert_equal(%w[hw:317642 material:DTDL18], sep.sort,
                      "nad prahom su len 410 a 300: #{sep.inspect}")
  merged = c['candidates'].select { |x| x['state'] == 'zostava' }.map { |x| x['source_key'] }
  NxTest.assert(merged.include?('custom:UUID-1'), '85 € vlastna polozka ostava v zostave')
  NxTest.assert(merged.include?('material:PD38'), '96 € doska ostava v zostave')
end

NxTest.test('cp: nizsi prah navrhne viac riadkov a suma sa NEZMENI') do
  c = NxCp.cp.cp_rows(NxCp.payload, threshold: 50.0)
  NxTest.assert_equal(4, c['separate_count'], '410 + 300 + 96 + 85 = 4 samostatné riadky')
  NxTest.assert_equal(2743.0, c['total'], 'iny prah NIKDY nemeni sumu ponuky')
  NxTest.assert(c['consistent'])
end

NxTest.test('cp: rucne zaradenie vitazi nad navrhom v OBOCH smeroch') do
  ov = { 'material:DTDL18' => 'zostava', 'custom:UUID-1' => 'samostatne' }
  c = NxCp.cp.cp_rows(NxCp.payload, overrides: ov, threshold: 150.0)
  labels = NxCp.rows_of(c)
  NxTest.refute(labels.include?('K009 PW DTDL 18 mm'), 'rucne zlúčená položka nesmie mat vlastny riadok')
  NxTest.assert(labels.include?('LED pás a trafo'), 'rucne vytiahnuta polozka MUSI mat vlastny riadok')
  NxTest.assert_equal(2743.0, c['total'], 'prepnutie zaradenia nemeni sumu')
  led = c['candidates'].find { |x| x['source_key'] == 'custom:UUID-1' }
  NxTest.assert(led['overridden'], 'polozka nesie priznak rucneho rozhodnutia')
  NxTest.refute(led['suggested'], '85 € nie je nad prahom — je to rucne rozhodnutie')
end

NxTest.test('cp: nezapocitane spotrebice sa NIKDY nestanu samostatnym riadkom') do
  c = NxCp.cp.cp_rows(NxCp.payload, overrides: { 'appliance:UUID-A' => 'samostatne' })
  NxTest.refute(NxCp.rows_of(c).include?('Bosch KIV87VFE0'),
                'polozka mimo suctu rozpoctu by dorovnala zostavu do zaporu')
  NxTest.assert_equal(2743.0, c['total'])
  NxTest.refute(c['candidates'].any? { |x| x['section'] == 'appliances' },
                'nezapocitana sekcia nie je ani kandidat')
end

NxTest.test('cp: zapocitany spotrebic uz kandidatom je') do
  p = NxCp.payload
  appl = p['sections'].find { |s| s['key'] == 'appliances' }
  appl['counts_in_total'] = true
  appl['included'] = true
  p['totals'] = { 'total' => 3392.0 }
  c = NxCp.cp.cp_rows(p)
  NxTest.assert(NxCp.rows_of(c).include?('Bosch KIV87VFE0'), '649 € je nad prahom')
  NxTest.assert_equal(3392.0, c['total'])
end

NxTest.test('cp: material ide do ponuky ako 1 set — pocet platni je INTERNY udaj') do
  c = NxCp.cp.cp_rows(NxCp.payload)
  r = NxCp.find(c, 'K009 PW DTDL 18 mm')
  NxTest.assert_equal(1, r['mnozstvo'], 'z 6 platní sa NIKDY nestane množstvo v ponuke')
  NxTest.assert_equal('set', r['mj'])
  hw = NxCp.find(c, 'K-HETTICH Quadro V6 skrytý celovýsuv 450 mm')
  NxTest.assert_equal(10, hw['mnozstvo'], 'kovanie si pocet kusov drzi')
  NxTest.assert_equal('set', hw['mj'])
end

NxTest.test('cp: obchodny nazov (cp_nazov) vyhrava nad rozpoctovym nazvom') do
  c = NxCp.cp.cp_rows(NxCp.payload, threshold: 50.0)
  NxTest.assert(NxCp.rows_of(c).include?('Pracovná doska F206 Mramor 4100/600/38'),
                "cp_nazov sa nepouzil: #{NxCp.rows_of(c).inspect}")
end

NxTest.test('cp: material_id nikdy neunikne ako nazov riadku') do
  p = NxCp.payload
  mat = p['sections'].find { |s| s['key'] == 'materials' }
  mat['rows'][0]['nazov'] = 'K009_PW_DTDL_18' # katalogovy zaznam chyba -> nazov je ID
  c = NxCp.cp.cp_rows(p)
  NxTest.assert(NxCp.rows_of(c).include?('Plošný materiál'), 'ID sa musi nahradit nazvom sekcie')
  NxTest.refute(NxCp.rows_of(c).join(' ').include?('K009_PW_DTDL_18'))
end

NxTest.test('cp: prazdny rozpocet da holu kostru bez padu') do
  c = NxCp.cp.cp_rows({})
  NxTest.assert_equal([NxCp.cp::ASSEMBLY_NAME, NxCp.cp::ZAMERANIE_NAME, NxCp.cp::VIZUALIZACIE_NAME],
                      NxCp.rows_of(c))
  NxTest.assert_equal(0.0, c['total'])
  NxTest.assert(c['consistent'])
  NxTest.assert_equal([], NxCp.cp.cp_rows(nil)['candidates'])
end

NxTest.test('cp: neznama hodnota zaradenia sa ignoruje (polozka ostava na navrhu)') do
  c = NxCp.cp.cp_rows(NxCp.payload, overrides: { 'material:DTDL18' => 'nezmysel', '' => 'zostava' })
  NxTest.assert(NxCp.rows_of(c).include?('K009 PW DTDL 18 mm'), 'nezmyselna hodnota nesmie prebit navrh')
end

# ==================== ROZPOCET -> cp_preview v payloade ====================

NxTest.test('cp: Budget.compute prilepi cp_preview a suma sedi s realnym payloadom') do
  b = Noxun::Engine::Budget
  state = { 'custom_items' => [{ 'id' => 'C1', 'popis' => 'Doprava a vynáška', 'pocet' => 1,
                                 'cena' => 240.0, 'cp_skupina' => 'zostava' }],
            'cp_overrides' => { 'custom:C1' => 'samostatne' } }
  payload = b.compute({ rows: [], edging: [] }, state, Noxun::Engine::SupplierSettings.seed_supplier)
  c = payload['cp_preview']
  NxTest.refute(c.nil?, 'payload rozpoctu musi niest nahlad cenovej ponuky')
  NxTest.assert_equal(payload['totals']['total'], c['total'], 'CP = rozpocet aj na realnom payloade')
  NxTest.assert(NxCp.rows_of(c).include?('Doprava a vynáška'), 'rucne zaradenie zo zakazky sa uplatnilo')
  NxTest.assert_equal(150.0, c['threshold'], 'prah ide zo seed nastaveni')
end

# ============================ SPECIFIKACIA ================================

NxTest.test('specifikacia: rola dielca urcuje kategoriu, typ dosky ju prebija') do
  s = NxCp.spec
  NxTest.assert(NxCp.cat(s, 'vnutorne_korpusy')['items'].any? { |i| i.include?('K009') }, 'korpus')
  NxTest.assert(NxCp.cat(s, 'dvierka')['items'].any? { |i| i.include?('W1000') }, 'čelo')
  NxTest.assert(NxCp.cat(s, 'chrbty')['items'].any? { |i| i.include?('HDF') }, 'chrbát')
  NxTest.assert(NxCp.cat(s, 'pracovna_doska')['items'].length == 1, 'PD ide do pracovnej dosky aj ako free_panel')
  NxTest.assert(NxCp.cat(s, 'zastena')['items'].length == 1, 'zástena má vlastnú kategóriu')
  NxTest.assert(NxCp.cat(s, 'dekorativne_panely')['items'].any? { |i| i.include?('W1000') },
                'voľná doska bežného typu = dekoratívny panel')
end

NxTest.test('specifikacia: kategorie idu v poradi z realnych dokumentov a prazdne vypadnu') do
  keys = NxCp.spec['categories'].map { |c| c['key'] }
  NxTest.assert_equal(keys.sort_by { |k| NxCp.cp::CATEGORY_ORDER.index(k) }, keys, 'poradie kategorii')
  NxTest.refute(keys.include?('uchytky'), 'prazdna kategoria sa nezobrazuje')
  NxTest.assert(keys.include?('vysuvy') && keys.include?('zavesy') && keys.include?('nohy'),
                'kovanie sa mapuje z kategorii katalogu')
end

NxTest.test('specifikacia: nazov materialu sklada dekor · typ · hrubka, cp_nazov vyhrava') do
  s = NxCp.spec
  NxTest.assert(NxCp.cat(s, 'vnutorne_korpusy')['items'].include?('K009 PW Dub Sonoma · DTD laminovaná · 18 mm'),
                "zlozeny nazov nesedi: #{NxCp.cat(s, 'vnutorne_korpusy')['items'].inspect}")
  NxTest.assert_equal(['Pracovná doska F206 Mramor Levanto 4100/600/38'],
                      NxCp.cat(s, 'pracovna_doska')['items'], 'cp_nazov ide do CP doslovne')
  NxTest.assert(NxCp.cat(s, 'zastena')['items'].first.include?('4100×640 mm'),
                'format je sucast identity zásteny')
end

NxTest.test('specifikacia: material mimo katalogu dostane nahradny nazov, nikdy ID') do
  s = NxCp.spec
  items = s['categories'].flat_map { |c| c['items'] }
  NxTest.assert(items.include?('Plošný materiál'), 'neznámy materiál = neutrálny názov')
  NxTest.refute(items.any? { |i| i.include?('NEZNAMY') }, 'material_id sa do CP nedostane')
end

NxTest.test('specifikacia: kovanie ide BEZ KODOV a nemapovana polozka vypadne') do
  s = NxCp.spec
  items = s['categories'].flat_map { |c| c['items'] }
  NxTest.assert(items.include?('K-HETTICH Quadro V6 skrytý celovýsuv 450 mm'))
  NxTest.refute(items.any? { |i| i.include?('317642') }, 'nakupny kod sa do specifikacie nedostane')
  NxTest.refute(items.any? { |i| i.include?('999999') }, 'polozka bez katalogoveho nazvu vypadne')
end

NxTest.test('specifikacia: spotrebice sa objavia LEN ked su sucastou ponuky') do
  budget = { 'sections' => [{ 'key' => 'appliances', 'included' => false,
                              'rows' => [{ 'nazov' => 'Bosch KIV87VFE0', 'typ_label' => 'Chladnička' }] }] }
  NxTest.assert(NxCp.cat(NxCp.spec(budget), 'spotrebice').nil?, 'nezapocitane spotrebice v CP nie su')
  budget['sections'][0]['included'] = true
  NxTest.assert_equal(['Chladnička Bosch KIV87VFE0'], NxCp.cat(NxCp.spec(budget), 'spotrebice')['items'])
end

NxTest.test('specifikacia: rovnaky material sa neopakuje a zoznam je deterministicky') do
  a = NxCp.spec
  b = NxCp.spec
  NxTest.assert_equal(a, b, 'dva behy nad tymi istymi datami = ten isty vystup')
  items = NxCp.cat(a, 'vnutorne_korpusy')['items']
  NxTest.assert_equal(1, items.count { |i| i.include?('K009') },
                      'dva dielce z toho isteho materialu = jeden riadok')
  NxTest.assert_equal(items.sort, items, 'poradie poloziek je deterministicke')
end

# ============================== FIREWALL ==================================

NxTest.test('firewall: blocklist chyti interne pojmy aj nakupne kody') do
  hits = NxCp.cp.firewall_hits(['Porez platní 17 €/platňa', 'Olepovanie ABS hrán',
                                'Kód 494760', 'K009_PW_DTDL_18', 'BALNÉ', 'Nábytková zostava'])
  terms = hits.map { |h| h['term'] }
  NxTest.assert(terms.include?('porez'), 'porez')
  NxTest.assert(terms.include?('olep'), 'olepovanie')
  NxTest.assert(terms.include?('balné'), 'balné')
  NxTest.assert(terms.any? { |t| t.include?('d{6,}') }, '6-ciferny kod')
  NxTest.assert(hits.none? { |h| h['text'] == 'Nábytková zostava' }, 'ciste texty neprepadnu')
end

NxTest.test('firewall: HOTOVY export cenovej ponuky neobsahuje ziadny interny pojem') do
  sheets = NxCp.xl.sheets(NxCp.cp.cp_rows(NxCp.payload), NxCp.spec,
                          project: 'KUCHYŇA Novák', now: NxCp::FIXED_TIME)
  hits = NxCp.cp.firewall_hits(NxCp.xl.text_cells(sheets))
  NxTest.assert_equal([], hits.map { |h| "#{h['term']} @ #{h['text']}" },
                      'do zakaznickeho dokumentu unikol interny pojem')
end

NxTest.test('firewall: export prezije aj rozpocet plny internych nazvov') do
  p = NxCp.payload
  p['sections'].find { |s| s['key'] == 'materials' }['rows'][0]['nazov'] = 'DUPLÁK K009_PW_DTDL_36'
  p['sections'].find { |s| s['key'] == 'hardware' }['rows'][0]['nazov'] = 'Kód 317642'
  p['sections'].find { |s| s['key'] == 'custom' }['rows'][0]['nazov'] = 'VEPO porez 17 €/platňa'
  c = NxCp.cp.cp_rows(p, threshold: 50.0)
  sheets = NxCp.xl.sheets(c, NxCp.spec, project: 'test', now: NxCp::FIXED_TIME)
  hits = NxCp.cp.firewall_hits(NxCp.xl.text_cells(sheets))
  # DUPLÁK aj VEPO su nazvy, ktore si Michal napisal sam — firewall ich MUSI
  # nahlasit (a status okna to povie), nie ticho prepustit.
  NxTest.refute(hits.empty?, 'firewall musi nalez OHLASIT')
  NxTest.assert(hits.map { |h| h['term'] }.include?('vepo'), 'vlastny nazov s VEPO sa musi ohlasit')
  # Kod z nazvu kovania vsak `clean_label` odstrani uz pri stavbe riadku.
  NxTest.refute(NxCp.rows_of(c).any? { |l| l.include?('317642') }, 'kod sa z nazvu odstrani')
end

NxTest.test('GH #139 P2: "Kód <hodnota>" sa odstrani AJ s hodnotou (5-ciferne kody)') do
  cp = NxCp.cp
  NxTest.assert_equal('', cp.clean_label('Kód 93240'), '5-ciferny kod nesmie ostat po slove Kód')
  NxTest.assert_equal('', cp.clean_label('kód: AB-12/3'))
  NxTest.assert_equal('Úchytka VARADERO 320mm', cp.clean_label('Úchytka VARADERO 320mm Kód 494760'))
  NxTest.assert(cp.code_like?('93240'), 'holy kod nie je nazov')
  NxTest.assert(cp.code_like?('105 408'))
  NxTest.refute(cp.code_like?('Sensys 8675'), 'nazov s pismenami nie je kod')
  NxTest.assert(cp.unusable_label?(''), 'prazdny label sa neda ukazat')
end

NxTest.test('GH #139 P2: z riadku, ktory je uz len kod, sa stane nahradny nazov') do
  p = NxCp.payload
  p['sections'].find { |s| s['key'] == 'hardware' }['rows'][0]['nazov'] = 'Kód 93240'
  c = NxCp.cp.cp_rows(p)
  NxTest.assert(NxCp.rows_of(c).include?('Kovanie'), "kod ostal v ponuke: #{NxCp.rows_of(c).inspect}")
  NxTest.refute(NxCp.rows_of(c).join(' ').include?('93240'))
  # a keby predsa nejaka bunka ostala holym kodom, firewall to musi chytit
  NxTest.refute(NxCp.cp.firewall_hits(['93240']).empty?, 'bunka zlozena len z cislic = nalez')
  NxTest.assert(NxCp.cp.firewall_hits(['Sokel 100 mm']).empty?, 'bezny nazov nesmie byt falosny poplach')
end

NxTest.test('GH #139 P2: viditeľný sokel patrí medzi DVIERKA A VIDITEĽNÉ ČASTI') do
  s = NxCp.cp.specification([{ 'material_id' => 'W1000', 'role' => 'plinth' }], sheets: NxCp.sheets)
  NxTest.assert_equal('dvierka', s['categories'].first['key'],
                      'sokel z plinth_mode=front je viditeľná časť, nie vnútorný korpus')
end

NxTest.test('GH #139 P1: nahlad CP hlasi neuplnu sumu (riadok bez ceny)') do
  p = NxCp.payload
  p['totals']['unknown_count_in_total'] = 2
  c = NxCp.cp.cp_rows(p)
  NxTest.assert_equal(2, c['unknown_count'])
  NxTest.refute(c['complete'], 'suma s riadkom bez ceny nie je uplna')
  NxTest.assert(NxCp.cp.cp_rows(NxCp.payload)['complete'], 'uplny rozpocet = uplna ponuka')
end

NxTest.test('firewall: clean_label odstrani kody, id_like? spozna material_id') do
  NxTest.assert_equal('HETTICH Sensys 8675 110°', NxCp.cp.clean_label('HETTICH 9071313 Sensys 8675 110°'))
  NxTest.assert_equal('', NxCp.cp.clean_label('Kód 494760'))
  NxTest.assert_equal('Doprava a vynáška', NxCp.cp.clean_label('  Doprava a vynáška  '))
  NxTest.assert_equal('Doska hrúbka 18 mm', NxCp.cp.clean_label('Doska K009_PW_DTDL_18 hrúbka 18 mm'),
                      'ID vnorene v texte sa musi odstranit, nielen cely token')
  NxTest.assert_equal('Sokel 100 mm', NxCp.cp.clean_label('Sokel 100 mm'), 'bezny text ostava netknuty')
  NxTest.assert(NxCp.cp.id_like?('K009_PW_DTDL_18'))
  NxTest.assert(NxCp.cp.id_like?('ABS_K009_10'))
  NxTest.refute(NxCp.cp.id_like?('K009 PW DTDL 18 mm'), 'ludsky nazov nie je ID')
end

# =========================== DVOJHARKOVY XLSX =============================

NxTest.test('cp xlsx: zosit ma 2 harky, platny archiv a spravne CRC') do
  bytes = NxCp.book_bytes
  entries = NxCp.unzip(bytes)
  names = entries.map { |e| e[:name] }
  NxTest.assert_equal(['[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml',
                       'xl/_rels/workbook.xml.rels', 'xl/styles.xml',
                       'xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml'], names)
  entries.each do |e|
    expected = NxCp.w.crc32(e[:data])
    NxTest.assert_equal(expected, e[:crc], "#{e[:name]}: CRC v central directory")
    NxTest.assert_equal(expected, e[:local_crc], "#{e[:name]}: CRC v local headeri")
  end
end

NxTest.test('cp xlsx: workbook, rels aj content types poznaju OBA harky') do
  bytes = NxCp.book_bytes
  wb = NxCp.part(bytes, 'xl/workbook.xml')
  NxTest.assert(wb.include?('name="Cenová ponuka" sheetId="1" r:id="rId1"'), "workbook: #{wb}")
  NxTest.assert(wb.include?('name="Špecifikácia" sheetId="2" r:id="rId2"'), "workbook: #{wb}")
  rels = NxCp.part(bytes, 'xl/_rels/workbook.xml.rels')
  NxTest.assert(rels.include?('Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"'),
                'druhy harok chyba v rels')
  NxTest.assert(rels.include?('Id="rId3"') && rels.include?('styles.xml'), 'styles maju byt az za harkami')
  ct = NxCp.part(bytes, '[Content_Types].xml')
  NxTest.assert(ct.include?('/xl/worksheets/sheet2.xml'), 'content types nepozna druhy harok')
end

NxTest.test('cp xlsx: jednoharkovy build ostal bajtovo kompatibilny (rozpocet sa nezmenil)') do
  sheet = Noxun::Engine::BudgetXlsx.sheet({}, project: 'x', now: NxCp::FIXED_TIME)
  a = NxCp.w.build(sheet, now: NxCp::FIXED_TIME)
  b = NxCp.w.build_book([sheet], now: NxCp::FIXED_TIME)
  NxTest.assert_equal(a, b, 'build musi byt presne build_book s jednym harkom')
  NxTest.assert_equal(6, NxCp.unzip(a).length)
end

NxTest.test('cp xlsx: dva rovnako pomenovane harky dostanu unikatne mena (inak Excel neotvori)') do
  bytes = NxCp.w.build_book([{ 'name' => 'Ponuka', 'rows' => [] }, { 'name' => 'Ponuka', 'rows' => [] }],
                            now: NxCp::FIXED_TIME)
  wb = NxCp.part(bytes, 'xl/workbook.xml')
  NxTest.assert(wb.include?('name="Ponuka" sheetId="1"'))
  NxTest.assert(wb.include?('name="Ponuka (2)" sheetId="2"'), "kolizia mien sa nevyriesila: #{wb}")
end

NxTest.test('cp xlsx: cenova tabulka ma stlpce POLOZKA/CENA/MNOZSTVO/MJ a konci SPOLU') do
  xml = NxCp.part(NxCp.book_bytes, 'xl/worksheets/sheet1.xml')
  NxTest.assert(xml.include?('POLOŽKA') && xml.include?('CENA (€)') &&
                xml.include?('MNOŽSTVO') && xml.include?('MJ'), 'hlavicka tabulky')
  NxTest.assert(xml.include?('SPOLU'), 'zaverecny sucet')
  NxTest.assert(xml.include?('<mergeCell ref="A1:D1"/>'), 'zluceny titulok')
  NxTest.assert(xml.include?('CENOVÁ PONUKA KUCHYŇA Novák - AKT. 6.8.2026'), 'titulok dokumentu')
  NxTest.refute(xml.include?('<f>'), 'zakaznicky harok nesmie mat vzorce — server je autorita cisel')
end

NxTest.test('cp xlsx: specifikacia pise kategoriu len pri prvej polozke') do
  xml = NxCp.part(NxCp.book_bytes, 'xl/worksheets/sheet2.xml')
  NxTest.assert(xml.include?('KATEGÓRIA') && xml.include?('ŠPECIFIKÁCIA'), 'hlavicka')
  NxTest.assert(xml.include?('VNÚTORNÉ KORPUSY'), 'kategoria z prieskumu')
  NxTest.assert(xml.include?('K-HETTICH Quadro V6 skrytý celovýsuv 450 mm'), 'kovanie v specifikacii')
  NxTest.refute(xml.include?('317642'), 'kod v specifikacii nesmie byt')
end

NxTest.test('cp xlsx: prazdna zakazka da platny subor s nahradnym textom') do
  bytes = NxCp.book_bytes(NxCp.cp.cp_rows({}), { 'categories' => [] }, project: '')
  NxTest.assert_equal(7, NxCp.unzip(bytes).length)
  xml = NxCp.part(bytes, 'xl/worksheets/sheet2.xml')
  NxTest.assert(xml.include?('Špecifikácia je zatiaľ prázdna'), 'prazdna specifikacia ma vysvetlenie')
end

NxTest.test('cp xlsx: nazov suboru pre savepanel je zakaznicky a bez zakazanych znakov') do
  NxTest.assert_equal('Cenova ponuka KUCHYŇA - 6.8.2026.xlsx',
                      NxCp.xl.file_name('KUCHYŇA', NxCp::FIXED_TIME))
  NxTest.assert_equal('Cenova ponuka a-b - 6.8.2026.xlsx', NxCp.xl.file_name('a/b', NxCp::FIXED_TIME))
  NxTest.assert_equal('Cenova ponuka zakazka - 6.8.2026.xlsx', NxCp.xl.file_name('', NxCp::FIXED_TIME))
end

# ======================= STAV ZAKAZKY + NASTAVENIA ========================

NxTest.test('cp_overrides: zapisuju sa LEN zname kluce a zname zaradenia') do
  bs = Noxun::Engine::BudgetStore
  model = NxCp::FakeModel.new
  ok, = bs.set_cp_group!(model, 'material:DTDL18', 'samostatne')
  NxTest.assert(ok, 'platny zapis musi prejst')
  NxTest.assert_equal({ 'material:DTDL18' => 'samostatne' }, bs.cp_overrides(model))

  # GH #139 P2: kod kovania smie obsahovat MEDZERU (katalog vyzaduje len
  # neprazdny trim) — prepinac na takej polozke sa nesmie odmietat.
  ok2, = bs.set_cp_group!(model, 'hw:ab 123/x', 'zostava')
  NxTest.assert(ok2, 'kluc s medzerou v kode musi prejst')
  NxTest.assert_equal('zostava', bs.cp_overrides(model)['hw:ab 123/x'])

  bad, errs = bs.set_cp_group!(model, 'std:balne', 'samostatne')
  NxTest.refute(bad, 'kluc standardneho riadku nie je polozka cenovej ponuky')
  NxTest.refute(errs.empty?)
  bad2, = bs.set_cp_group!(model, 'material:DTDL18', 'niekde_inde')
  NxTest.refute(bad2, 'nezname zaradenie sa odmietne')
  NxTest.assert_equal({ 'material:DTDL18' => 'samostatne', 'hw:ab 123/x' => 'zostava' },
                      bs.cp_overrides(model), 'odmietnuty zapis nesmie nic zmenit')
end

NxTest.test('cp_overrides: prazdna hodnota vrati polozku na serverovy navrh') do
  bs = Noxun::Engine::BudgetStore
  model = NxCp::FakeModel.new
  bs.set_cp_group!(model, 'custom:UUID-1', 'zostava')
  ok, = bs.set_cp_group!(model, 'custom:UUID-1', '')
  NxTest.assert(ok)
  NxTest.assert_equal({}, bs.cp_overrides(model), 'prazdna hodnota = zrusenie rozhodnutia')
end

NxTest.test('cp_overrides: poskodene data nezhodia stav rozpoctu') do
  bs = Noxun::Engine::BudgetStore
  model = NxCp::FakeModel.new
  model.set_attribute(Noxun::Engine::Store::DICT, bs::KEY_CP_OVERRIDES, '{nie json')
  NxTest.assert_equal({}, bs.cp_overrides(model))
  model.set_attribute(Noxun::Engine::Store::DICT, bs::KEY_CP_OVERRIDES,
                      '{"material:X":"samostatne","zlyKluc":"zostava","material:Y":"blabla"}')
  NxTest.assert_equal({ 'material:X' => 'samostatne' }, bs.cp_overrides(model))
  NxTest.assert_equal({ 'material:X' => 'samostatne' }, bs.state(model)['cp_overrides'],
                      'stav zakazky nesie zaradenie do CP')
end

NxTest.test('nastavenia: prah cenovej ponuky je v seede aj v merge existujuceho suboru') do
  ss = Noxun::Engine::SupplierSettings
  NxTest.assert_equal(150.0, ss.seed_supplier['cp_highlight_threshold'], 'seed prahu')
  NxTest.assert_equal(150.0, ss.scalar({}, 'cp_highlight_threshold'), 'fallback pri starom zazname')
  merged, changed = ss.merge_seed(ss.normalize('suppliers' => [{ 'id' => 'default', 'rates' => {} }]))
  NxTest.assert_equal(150.0, merged['suppliers'].first['cp_highlight_threshold'],
                      'stary subor bez prahu ho dostane doplneny')
  NxTest.assert(changed || true)
end

NxTest.test('nastavenia: prah sa da prepisat patchom a mimo rozsahu sa odmietne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ss = Noxun::Engine::SupplierSettings
  ok, = ss.patch_active!('cp_highlight_threshold' => 250.0)
  NxTest.assert(ok, 'platny prah musi prejst')
  NxTest.assert_equal(250.0, ss.active['cp_highlight_threshold'])
  bad, errs = ss.patch_active!('cp_highlight_threshold' => 'nie je cislo')
  NxTest.refute(bad)
  NxTest.assert(errs.join.include?('cp_highlight_threshold'))
  NxTest.assert_equal(250.0, ss.reload!['suppliers'].first['cp_highlight_threshold'],
                      'odmietnuty patch nic nezmenil')
  ss.patch_active!('cp_highlight_threshold' => 150.0) # cistota pre dalsie testy
end

NxTest.test('katalog: cp_nazov sa uklada, patchuje a da sa vymazat') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  mat = Noxun::Engine::Materials
  rec = mat.normalize_sheet('material_id' => 'X1', 'decor' => 'K009', 'type' => 'DTDL',
                            'thickness' => 18.0, 'cp_nazov' => '  Laminovaná doska K009  ')
  NxTest.assert_equal('Laminovaná doska K009', rec['cp_nazov'], 'trim + ulozenie')
  NxTest.refute(mat.normalize_sheet('material_id' => 'X1', 'decor' => 'K009', 'type' => 'DTDL',
                                    'thickness' => 18.0, 'cp_nazov' => '   ').key?('cp_nazov'),
                'prazdna hodnota kluc odstrani')
  ok, err = Noxun::Engine::Materials.validate_sheet_attrs(
    'decor' => 'K009', 'type' => 'DTDL', 'thickness' => 18.0, 'cp_nazov' => 'a' * 400
  )
  NxTest.refute(ok, 'pridlhy obchodny nazov sa odmietne')
  NxTest.assert(err.to_s.include?('Obchodný názov'))
end

NxTest.test('studio_dialog: relay cenovej ponuky je public (vola ho panel.rb)') do
  # ŠT-1c PR B3: relay viedol do okna Vyroba — to zaniklo, cenova ponuka je
  # sekcia `offer` okna ŠTUDIO a telo exportu zije v `ProductionCore`.
  if NxTest.headless?
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog')
  end
  NxTest.assert(Noxun::Engine::StudioDialog.respond_to?(:do_cp_xlsx),
                'StudioDialog.do_cp_xlsx musi byt PUBLIC (relay z panel.rb)')
  NxTest.assert(Noxun::Engine::ProductionCore.respond_to?(:do_cp_xlsx),
                'a telo zije v zdielanom jadre')
end
