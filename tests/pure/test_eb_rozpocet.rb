# frozen_string_literal: true
# V0.6 E-b: XLSX rozpocet (vlastny ZIP writer + Luciin harok), integracia
# upozorneni rozpoctu do KONTROLY a baseline revizia okna Nastavenia.
#
# ZIP nema toleranciu: zly CRC alebo posunuty offset = "poskodeny archiv" bez
# hlasky. Preto sa tu archiv ROZOBERA SPAT (local headers, central directory,
# EOCD) a kontroluje sa kazdy invariant, ktory by Excel odmietol.
require_relative '../helper' unless defined?(NxTest)

module NxXlsx
  module_function

  def w
    Noxun::Engine::XlsxWriter
  end

  def bx
    Noxun::Engine::BudgetXlsx
  end

  FIXED_TIME = Time.utc(2026, 8, 6, 12, 30, 0)

  # --- rozober ZIP spat (male citanie hlaviciek, ziadne gemy) --------------
  # -> [{ name, crc, size, offset, data }]
  def unzip(bytes)
    raise 'ZIP nema EOCD' unless bytes[-22, 4] == [0x06054b50].pack('V')

    _sig, _d1, _d2, entries, total, cd_size, cd_off, _cl = bytes[-22, 22].unpack('VvvvvVVv')
    raise "pocet zaznamov nesedi (#{entries} vs #{total})" unless entries == total

    out = []
    pos = cd_off
    entries.times do
      hdr = bytes[pos, 46]
      raise 'zly podpis central directory' unless hdr[0, 4] == [0x02014b50].pack('V')

      f = hdr.unpack('VvvvvvvVVVvvvvvVV')
      name_len = f[10]
      name = bytes[pos + 46, name_len]
      local_off = f[16]
      lh = bytes[local_off, 30]
      raise 'zly podpis local header' unless lh[0, 4] == [0x04034b50].pack('V')

      l = lh.unpack('VvvvvvVVVvv')
      data_off = local_off + 30 + l[9] + l[10]
      data = bytes[data_off, l[8]]
      out << { name: name, crc: f[7], size: f[9], offset: local_off, data: data,
               local_crc: l[6], method: f[4], cd_size: cd_size }
      pos += 46 + name_len + f[11] + f[12]
    end
    out
  end

  # Minimalny payload rozpoctu — realne cisla nie su dolezite, dolezity je TVAR
  # (payload je jediny vstup exportu).
  def payload
    {
      'mode' => 'standard', 'mode_label' => 'Štandard', 'vat_divisor' => 1.23,
      'sections' => [
        { 'key' => 'materials', 'name' => 'Materiál', 'subtotal' => 411.0,
          'counts_in_total' => true, 'unknown_count' => 0, 'rows' => [
            { 'key' => 'material:D18', 'nazov' => 'K009 PW <DTDL> & 18 mm', 'kod' => 'K009',
              'mj' => 'PLATŇA', 'mnozstvo' => 6, 'cena_mj' => 68.5, 'spolu' => 411.0,
              'poznamka' => '5,32 m²', 'price_missing' => false }
          ] },
        { 'key' => 'custom', 'name' => 'Vlastné položky', 'subtotal' => 85.0,
          'counts_in_total' => true, 'unknown_count' => 1, 'rows' => [
            { 'key' => 'custom:1', 'nazov' => 'Doprava a vynáška', 'kod' => nil, 'mj' => 'KS',
              'mnozstvo' => 2, 'cena_mj' => 42.5, 'spolu' => 85.0, 'poznamka' => nil,
              'price_missing' => false },
            { 'key' => 'custom:2', 'nazov' => 'Silikón', 'kod' => nil, 'mj' => 'KS',
              'mnozstvo' => 1, 'cena_mj' => nil, 'spolu' => nil, 'poznamka' => nil,
              'price_missing' => true }
          ] },
        { 'key' => 'appliances', 'name' => 'Spotrebiče', 'subtotal' => 649.0,
          'counts_in_total' => false, 'included' => false, 'unknown_count' => 0, 'rows' => [
            { 'key' => 'appliance:1', 'nazov' => 'Bosch KIV87VFE0', 'kod' => nil, 'mj' => 'KS',
              'mnozstvo' => 1, 'cena_mj' => 649.0, 'spolu' => 649.0, 'price_missing' => false }
          ] },
        { 'key' => 'rounding', 'name' => 'Zaokrúhlenie ponuky', 'subtotal' => 4.0,
          'counts_in_total' => true, 'unknown_count' => 0, 'rows' => [
            { 'key' => 'rounding', 'nazov' => 'Zaokrúhlenie ponuky', 'mj' => 'FIX',
              'mnozstvo' => 1, 'cena_mj' => 4.0, 'spolu' => 4.0, 'poznamka' => 'na 1 € nahor',
              'price_missing' => false }
          ] }
      ],
      'totals' => { 'raw_total' => 496.0, 'rounding' => 4.0, 'total' => 500.0,
                    'total_novat' => 406.5, 'unknown_count_in_total' => 1 }
    }
  end

  def build_bytes
    w.build(bx.sheet(payload, project: 'KUCHYŇA "A" & B', now: FIXED_TIME), now: FIXED_TIME)
  end

  def sheet_xml(bytes = nil)
    entries = unzip(bytes || build_bytes)
    entries.find { |e| e[:name] == 'xl/worksheets/sheet1.xml' }[:data].force_encoding('UTF-8')
  end
end

# ============================ ZIP =========================================

NxTest.test('xlsx: archiv ma vsetkych 6 casti v spravnom poradi') do
  names = NxXlsx.unzip(NxXlsx.build_bytes).map { |e| e[:name] }
  NxTest.assert_equal(['[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml',
                       'xl/_rels/workbook.xml.rels', 'xl/styles.xml', 'xl/worksheets/sheet1.xml'], names)
end

NxTest.test('xlsx: CRC32 sedi s obsahom a central directory sedi s local headerom') do
  NxXlsx.unzip(NxXlsx.build_bytes).each do |e|
    expected = NxXlsx.w.crc32(e[:data])
    NxTest.assert_equal(expected, e[:crc], "#{e[:name]}: CRC v central directory nesedi")
    NxTest.assert_equal(expected, e[:local_crc], "#{e[:name]}: CRC v local headeri nesedi")
    NxTest.assert_equal(e[:data].bytesize, e[:size], "#{e[:name]}: velkost nesedi")
    NxTest.assert_equal(0, e[:method], "#{e[:name]}: metoda musi byt STORE (0)")
  end
end

NxTest.test('xlsx: offsety local headerov su rastuce a mieria na podpis') do
  bytes = NxXlsx.build_bytes
  last = -1
  NxXlsx.unzip(bytes).each do |e|
    NxTest.assert(e[:offset] > last, "offset #{e[:name]} nie je rastuci")
    NxTest.assert_equal([0x04034b50].pack('V'), bytes[e[:offset], 4], 'offset nemieri na local header')
    last = e[:offset]
  end
end

NxTest.test('xlsx: ciste Ruby CRC32 sa zhoduje so Zlib') do
  data = 'Rozpočet KUCHYŇA & spol. <test>'.dup.force_encoding('BINARY')
  NxTest.skip!('Zlib nie je dostupny') unless defined?(Zlib) && Zlib.respond_to?(:crc32)
  NxTest.assert_equal(Zlib.crc32(data), NxXlsx.w.crc32_pure(data))
end

# ============================ XML =========================================

NxTest.test('xlsx: XML escapuje &, <, > a uvodzovky; diakritika ostava') do
  xml = NxXlsx.sheet_xml
  NxTest.assert(xml.include?('K009 PW &lt;DTDL&gt; &amp; 18 mm'), 'text riadku nie je escapovany')
  NxTest.assert(xml.include?('KUCHYŇA &quot;A&quot; &amp; B'), 'titulok nie je escapovany')
  NxTest.assert(xml.include?('Zaokrúhlenie ponuky'), 'diakritika sa nesmie meniť')
  # Kazdy textovy obsah musi byt bez holych <, > a bez & mimo entity.
  xml.scan(%r{<t[^>]*>(.*?)</t>}m).flatten.each do |body|
    NxTest.refute(body =~ /[<>]/, "v texte ostal holy znak: #{body.inspect}")
    NxTest.refute(body =~ /&(?!amp;|lt;|gt;|quot;|apos;)/, "v texte ostal holy & : #{body.inspect}")
  end
end

NxTest.test('xlsx: riadiace znaky sa z XML odstrania (inak neotvoritelny subor)') do
  NxTest.assert_equal('AB', NxXlsx.w.esc("A\x01B"))
  NxTest.assert_equal("A\tB", NxXlsx.w.esc("A\tB"))
end

NxTest.test('xlsx: cisla su ciselne bunky s formatom #,##0.00, texty inlineStr') do
  xml = NxXlsx.sheet_xml
  # R1 titulok, R2 hlavicka, R3 nadpis sekcie, R4 prvy materialovy riadok.
  NxTest.assert(xml.include?('<c r="G4" s="3"><v>411</v></c>'),
                "ciselna bunka SPOLU s formatom #,##0.00 chyba: #{xml[0, 400]}")
  NxTest.assert(xml.include?('t="inlineStr"'), 'texty musia byt inline stringy (bez sharedStrings)')
  styles = NxXlsx.unzip(NxXlsx.build_bytes).find { |e| e[:name] == 'xl/styles.xml' }[:data]
  NxTest.assert(styles.include?('formatCode="#,##0.00"'), 'chyba format cisel')
  NxTest.assert(styles.include?('<cellXfs count="7">'), 'pocet stylov nesedi s indexmi S_*')
end

NxTest.test('xlsx: SPOLU su HODNOTY, nie excelovske vzorce (server je autorita)') do
  xml = NxXlsx.sheet_xml
  NxTest.refute(xml.include?('<f>'), 'harok nesmie obsahovat ziadny vzorec')
  NxTest.refute(xml.include?('SUM('), 'harok nesmie obsahovat SUM()')
end

NxTest.test('xlsx: stlpce zacinaju v B (A je odsadzovac) a titulok je zluceny B1:G1') do
  xml = NxXlsx.sheet_xml
  NxTest.assert(xml.include?('<mergeCell ref="B1:G1"/>'), 'chyba zlucenie titulku')
  NxTest.refute(xml =~ /<c r="A\d/, 'stlpec A musi ostat prazdny')
  NxTest.assert(xml.include?('MATERIÁL'), 'chyba hlavicka MATERIÁL')
  NxTest.assert(xml.include?('CENA za 1 MJ (€)'), 'chyba hlavicka ceny')
end

NxTest.test('xlsx: col_letter zvlada aj druhe pismeno (Z/AA)') do
  NxTest.assert_equal('A', NxXlsx.w.col_letter(1))
  NxTest.assert_equal('G', NxXlsx.w.col_letter(7))
  NxTest.assert_equal('Z', NxXlsx.w.col_letter(26))
  NxTest.assert_equal('AA', NxXlsx.w.col_letter(27))
end

# ============================ LUCIIN HAROK ================================

NxTest.test('rozpocet xlsx: titulok a nazov suboru maju format Luciinych harkov') do
  NxTest.assert_equal('Rozpočet KUCHYŇA - AKT. 6.8. 2026',
                      NxXlsx.bx.title('KUCHYŇA', NxXlsx::FIXED_TIME))
  NxTest.assert_equal('Rozpocet KUCHYŇA - AKT 6.8. 2026.xlsx',
                      NxXlsx.bx.file_name('KUCHYŇA', NxXlsx::FIXED_TIME))
  NxTest.assert_equal('Rozpocet a-b - AKT 6.8. 2026.xlsx',
                      NxXlsx.bx.file_name('a/b', NxXlsx::FIXED_TIME),
                      'zakazane znaky nazvu suboru sa musia nahradit')
end

NxTest.test('rozpocet xlsx: kazda sekcia ma nadpis + medzisucet, zaokruhlenie je holy riadok') do
  xml = NxXlsx.sheet_xml
  NxTest.assert(xml.include?('MATERIÁL'), 'chyba nadpis sekcie materialu')
  NxTest.assert(xml.include?('Medzisúčet Materiál (€):'), 'chyba medzisucet sekcie')
  NxTest.assert(xml.include?('SPOLU CELKOM (€):'), 'chyba zaverecny sucet')
  NxTest.refute(xml.include?('Medzisúčet Zaokrúhlenie ponuky'),
                'zaokruhlenie je dorovnavaci riadok, nie sekcia s medzisuctom')
end

NxTest.test('rozpocet xlsx: spotrebice mimo suctu su oznacene ako nezapocitane') do
  xml = NxXlsx.sheet_xml
  NxTest.assert(xml.include?('SPOTREBIČE — nezapočítané do SPOLU'),
                'nezapocitana sekcia musi byt v harku oznacena')
end

NxTest.test('rozpocet xlsx: riadok bez ceny sa nepodstrci ako nula') do
  xml = NxXlsx.sheet_xml
  NxTest.assert(xml.include?('nezadaná'), 'chybajuca cena musi byt textom, nie 0')
  NxTest.assert(xml.include?('Pozor: 1 riadkov bez ceny'), 'harok musi hlasit neuplny sucet')
end

NxTest.test('rozpocet xlsx: poznamka riadku ide do nazvu (harok nema stlpec na poznamku)') do
  NxTest.assert(NxXlsx.sheet_xml.include?('18 mm · 5,32 m²'), 'poznamka sa stratila')
end

NxTest.test('rozpocet xlsx: prazdny rozpocet neprodukuje nevalidny subor') do
  bytes = NxXlsx.w.build(NxXlsx.bx.sheet({}, project: '', now: NxXlsx::FIXED_TIME), now: NxXlsx::FIXED_TIME)
  entries = NxXlsx.unzip(bytes)
  NxTest.assert_equal(6, entries.length)
  NxTest.assert(entries.last[:data].force_encoding('UTF-8').include?('Rozpočet zákazka'),
                'chyba nahradny nazov zakazky')
end

NxTest.test('rozpocet xlsx: harok sa da postavit z REALNEHO payloadu Budget.compute') do
  b = Noxun::Engine::Budget
  payload = b.compute({ rows: [], edging: [] }, {}, Noxun::Engine::SupplierSettings.seed_supplier)
  bytes = NxXlsx.w.build(NxXlsx.bx.sheet(payload, project: 'test', now: NxXlsx::FIXED_TIME),
                         now: NxXlsx::FIXED_TIME)
  xml = NxXlsx.unzip(bytes).last[:data].force_encoding('UTF-8')
  NxTest.assert(xml.include?('SPOLU CELKOM (€):'), 'realny payload nedal zaverecny sucet')
  NxTest.assert(xml.include?('ŠTANDARDNÉ RIADKY'), 'chybaju standardne riadky z realneho payloadu')
end

# ================== KONTROLA: kategoria budget ============================

NxTest.test('kontrola: upozornenia rozpoctu sa pridaju ako ORANGE kategoria budget') do
  v = Noxun::Engine::Validation
  base = { 'items' => [{ 'severity' => 'red', 'category' => 'material', 'owner_id' => 'CAB-1',
                         'part_key' => nil, 'hw_key' => nil, 'message_sk' => 'x',
                         'stable_key' => 'material|CAB-1|' }],
           'counts' => { 'red' => 1, 'orange' => 0, 'total' => 1 } }
  budget = [{ 'severity' => 'orange', 'category' => 'budget', 'stable_key' => 'budget|custom:1|missing_price',
              'section' => 'custom', 'row_key' => 'custom:1', 'message' => 'Položka nemá cenu.' }]
  out = v.with_budget(base, budget)
  NxTest.assert_equal(2, out['items'].length)
  NxTest.assert_equal({ 'red' => 1, 'orange' => 1, 'total' => 2 }, out['counts'],
                      'counts musia rátať aj rozpočtové riadky (badge/tab/status = jedno číslo)')
  item = out['items'].find { |i| i['category'] == 'budget' }
  NxTest.assert_equal('Položka nemá cenu.', item['message_sk'], 'text musi prist zo servera')
  NxTest.assert_equal('custom', item['budget_section'], 'chyba cielova sekcia pre klik')
  NxTest.assert(item['owner_id'].nil?, 'rozpoctovy riadok nesmie mierit na entitu modelu')
end

NxTest.test('kontrola: with_budget nemeni vstup a deduplikuje rovnaky kluc') do
  v = Noxun::Engine::Validation
  base = { 'items' => [], 'counts' => { 'red' => 0, 'orange' => 0, 'total' => 0 } }
  w = { 'stable_key' => 'budget|appliances|not_included', 'section' => 'appliances',
        'message' => 'Spotrebiče nie sú v súčte.' }
  out = v.with_budget(base, [w, w])
  NxTest.assert_equal(1, out['items'].length, 'rovnaky stable_key = jeden riadok')
  NxTest.assert_equal(0, base['items'].length, 'vstup sa nesmie zmutovat')
end

NxTest.test('kontrola: bez rozpoctovych upozorneni sa zoznam nemeni') do
  v = Noxun::Engine::Validation
  base = { 'items' => [{ 'severity' => 'orange', 'category' => 'abs', 'owner_id' => 'BRD-1',
                         'part_key' => nil, 'hw_key' => nil, 'message_sk' => 'y',
                         'stable_key' => 'abs|BRD-1|' }],
           'counts' => { 'red' => 0, 'orange' => 1, 'total' => 1 } }
  out = v.with_budget(base, [])
  NxTest.assert_equal(base['items'], out['items'])
  NxTest.assert_equal(base['counts'], out['counts'])
end

# ================== NASTAVENIA: baseline revizia ==========================

NxTest.test('nastavenia: revizia sa meni len pri zmene obsahu dodavatela') do
  ss = Noxun::Engine::SupplierSettings
  sup = ss.seed_supplier
  r1 = ss.revision(sup)
  NxTest.refute(r1.empty?, 'revizia nesmie byt prazdna')
  NxTest.assert_equal(r1, ss.revision(ss.seed_supplier), 'rovnaky obsah = rovnaka revizia')
  changed = ss.seed_supplier
  changed['rates']['olep'] = 1.25
  NxTest.refute(r1 == ss.revision(changed), 'zmena sadzby musi zmenit reviziu')
end

NxTest.test('nastavenia: patch_active! je all-or-nothing (chybna hodnota nezapise nic)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ss = Noxun::Engine::SupplierSettings
  before = ss.active['rates']['olep']
  ok, errors = ss.patch_active!('rates' => { 'olep' => 1.11, 'porez' => 'nie je cislo' })
  NxTest.refute(ok, 'chybna hodnota musi zapis odmietnut')
  NxTest.refute(errors.empty?, 'chyba musi mat text')
  NxTest.assert_equal(before, ss.reload!['suppliers'].first['rates']['olep'],
                      'ciastocny zapis je zakazany')
end

NxTest.test('nastavenia: patch prejde a revizia sa posunie (baseline guard funguje)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ss = Noxun::Engine::SupplierSettings
  r1 = ss.revision(ss.active)
  ok, = ss.patch_active!('rates' => { 'olep' => 1.05 }, 'stale_days' => 45)
  NxTest.assert(ok, 'platny patch musi prejst')
  sup = ss.active
  NxTest.assert_close(1.05, sup['rates']['olep'], 0.001)
  NxTest.assert_equal(45, sup['stale_days'])
  NxTest.refute(r1 == ss.revision(sup), 'po zapise musi byt revizia ina')
end

NxTest.test('production_dialog: relay XLSX rozpoctu je public (vola ho panel.rb)') do
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog') if NxTest.headless?
  pd = Noxun::Engine::ProductionDialog
  %i[do_budget_xlsx do_budget].each do |m|
    NxTest.assert(pd.respond_to?(m), "ProductionDialog.#{m} musi byt PUBLIC (relay z panel.rb / callback)")
  end
end
