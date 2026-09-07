# frozen_string_literal: true
# Testy D-118: KATALOGOVY SEED v3 (dáta z Démosu) + migrácia v2 -> v3.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 kazdy kod, ktory pouzivaju SEED sety kovania, MA polozku v katalogu —
#      inak je v Nakupe „bez ceny" a nazov len z kodu (povod D-118)
#   R2 seed riadok s Demos vazbou nesie cenu S DPH aj DATUM overenia
#      (`SEED_PRICE_CHECKED_AT`); riadok bez vazby alebo bez ceny stamp NEMA
#   R3 kody, ktore Demos uz nepozna, su NEAKTIVNE a nesu dovod v poznamke —
#      nikdy sa nemazu (stare zakazky ich maju v nakupe)
#   R4 vyrobca a rada seed riadku existuju v TAXONOMII (inak by ich strom
#      katalogu zhodil pod „— bez vyrobcu" a editor by ich odmietol ulozit)
#   R5 migracia v2 -> v3: doplni sa LEN `SEED_PATCH_V3_ADD` (plny seed sa do
#      existujuceho katalogu NELEJE), NEZMENENY v2 riadok sa osviezi,
#      POUZIVATELSKY riadok ostava — a to aj vtedy, ked pouzivatel zmenil LEN
#      vyrobcu/radu alebo si polozku naviazal na Demos (Astra #21 BLOCKER 1)
#   R6 `use_count` a rucne VYPNUTA aktivnost migraciu prezijú (patch nikdy
#      polozku nezapne spat)
#
# MUTACIE (kazda overena rucne — po zaneseni chyby spadne uvedeny test):
#   M1 z `SEED_ROWS` sa vymaze riadok 357694 (kod, ktory pouziva seed set)
#      -> „D-118 (R1): kazdy kod seed setov je v katalogu"; vymazanie 352908
#      (modul, ktory set zacne pouzivat az v D-118b) zhodi „(R5) migracia doplni
#      LEN vymenovane kody" a zmrazeny rozsah manifestu
#   M2 `SEED_PRICE_CHECKED_AT` sa zapise aj riadku bez URL -> „D-118 (R2): datum overenia patri VAZBE"
#   M3 zo `SEED_INACTIVE` sa vyhodi 197611 -> „D-118 (R3): zrusene kody su neaktivne s dovodom"
#   M4 vyrobca riadku sa zmeni na „Häfele" -> „D-118 (R4): vyrobca a rada su v taxonomii"
#   M5 z podmienky nedotknutosti sa vyhodi `manufacturer` -> „D-118 (R5): riadok s vlastnym vyrobcom sa NEPREPISE"
#   M6 `items[idx] = rec` namiesto `cur.merge(rec)` -> „D-118 (R6): use_count a vypnuta aktivnost prezijú"
require_relative '../helper' unless defined?(NxTest)

module NxD118
  E     = Noxun::Engine
  HWC   = E::HardwareCatalog
  HWS   = E::HardwareSets
  TAX   = E::HardwareTaxonomy
  STORE = E::JsonFileStore

  module_function

  # Katalog v STAROM (v2) stave: zoznam zaznamov + seed_version 2.
  def install_v2!(items)
    FileUtils.mkdir_p(HWC.dir)
    STORE.write(HWC.path, 'std' => HWC::STD, 'schema' => HWC::SCHEMA_CURRENT,
                          'seed_version' => 2, 'items' => items)
    FileUtils.rm_f("#{HWC.path}.bak")
    STORE.invalidate(HWC.path)
    HWC.reset_state!
  end

  def wipe!
    [HWC.path, "#{HWC.path}.bak"].each { |f| FileUtils.rm_f(f) }
    STORE.invalidate(HWC.path)
    HWC.reset_state!
  end

  # Vlastna taxonomia v sandboxe (napr. rada uz patri INEMU vyrobcovi).
  # Vracia povodny obsah suboru, aby ho volajuci vedel vratit.
  def install_taxonomy!(manufacturers, series, seed_version: TAX::SEED_VERSION)
    before = (File.binread(TAX.path) if File.exist?(TAX.path))
    FileUtils.mkdir_p(TAX.dir)
    STORE.write(TAX.path, 'std' => TAX::STD, 'schema' => TAX::SCHEMA_CURRENT,
                          'seed_version' => seed_version,
                          'manufacturers' => manufacturers.map { |n| { 'name' => n } },
                          'series' => series.map { |(n, m)| { 'name' => n, 'manufacturer' => m } })
    FileUtils.rm_f("#{TAX.path}.bak")
    STORE.invalidate(TAX.path)
    TAX.reset_state!
    before
  end

  def restore_taxonomy!(before)
    if before
      File.binwrite(TAX.path, before)
    else
      FileUtils.rm_f(TAX.path)
    end
    FileUtils.rm_f("#{TAX.path}.bak")
    STORE.invalidate(TAX.path)
    TAX.reset_state!
  end

  def v2_item(code)
    rec, = HWC.normalize_item(HWC::SEED_ITEMS_V2.find { |i| i['item_code'] == code })
    rec
  end

  def v3_item(code)
    HWC::SEED_ITEMS.find { |i| i['item_code'] == code }
  end

  # Vsetky kody, ktore pouzivaju seed sety (pevny kod, rad NL aj pasma).
  def set_codes
    out = []
    HWS::SEED_SETS.each do |s|
      Array(s['members']).each do |m|
        out << m['code'] if m['code']
        (m['code_by_nl'] || {}).each_value { |c| out << c }
        ((m['param_bands'] || {})['bands'] || []).each { |b| out << b['code'] if b['code'] }
      end
    end
    out.uniq
  end
end

# ============================================================================
# R1–R4 — obsah seedu
# ============================================================================

NxTest.test('D-118 (R1): kazdy kod seed setov je v katalogu') do
  by_code = {}
  NxD118::HWC::SEED_ITEMS.each { |i| by_code[i['item_code']] = i }
  missing = NxD118.set_codes.reject { |c| by_code.key?(c) }
  NxTest.assert_equal([], missing, 'kod zo setu bez katalogovej polozky = „bez ceny" v Nakupe')
end

NxTest.test('D-118 (R2): datum overenia patri VAZBE (cena + URL), nie kazdemu riadku') do
  NxD118::HWC::SEED_ITEMS.each do |i|
    if i['demos_url'] && i['price_eur_vat']
      NxTest.assert_equal(NxD118::HWC::SEED_PRICE_CHECKED_AT, i['price_checked_at'],
                          "#{i['item_code']}: vazba s cenou ma datum")
    else
      NxTest.refute(i.key?('price_checked_at'),
                    "#{i['item_code']}: bez vazby alebo bez ceny ziadny datum")
    end
    next unless i['demos_url']

    NxTest.assert(i['demos_url'].start_with?('https://www.demos-trade.sk/'),
                  "#{i['item_code']}: URL musi byt z demos-trade.sk")
  end
end

NxTest.test('D-118 (R3): zrusene kody su neaktivne s dovodom v poznamke') do
  NxD118::HWC::SEED_INACTIVE.each do |code|
    item = NxD118.v3_item(code)
    NxTest.assert(item, "#{code} ostava v manifeste (nikdy sa nemaze)")
    NxTest.assert_equal(false, item['active'], "#{code} je neaktivny")
    NxTest.assert(item['notes'].to_s.include?('nepozná'), "#{code} vysvetluje dovod: #{item['notes']}")
  end
  aktivne = NxD118::HWC::SEED_ITEMS.reject { |i| NxD118::HWC::SEED_INACTIVE.include?(i['item_code']) }
  NxTest.assert(aktivne.none? { |i| i.key?('active') }, 'aktivne polozky priznak neukladaju (sparse)')
end

NxTest.test('D-118 (R4): vyrobca a rada seed riadku su v taxonomii') do
  mans = NxD118::TAX::SEED_MANUFACTURERS
  sers = {}
  NxD118::TAX::SEED_SERIES.each { |(name, man)| sers[name] = man }
  NxD118::HWC::SEED_ITEMS.each do |i|
    next unless i['manufacturer']

    NxTest.assert(mans.include?(i['manufacturer']),
                  "#{i['item_code']}: vyrobca „#{i['manufacturer']}“ nie je v taxonomii")
    next unless i['series']

    NxTest.assert_equal(i['manufacturer'], sers[i['series']],
                        "#{i['item_code']}: rada „#{i['series']}“ patri inemu vyrobcovi")
  end
end

# ============================================================================
# R5–R6 — migracia v2 -> v3
# ============================================================================

NxTest.test('D-118 (R5): migracia doplni LEN vymenovane kody, plny seed sa NELEJE') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  vlastna = { 'item_code' => '999001', 'name_sk' => 'Vlastná položka',
              'category' => 'OSTATNE', 'unit' => 'ks' }
  NxD118.install_v2!([NxD118.v2_item('104717'), NxD118::HWC.normalize_item(vlastna)[0]])
  NxTest.assert_equal(:ok, NxD118::HWC.assess!)

  doc = NxD118::STORE.read(NxD118::HWC.path)
  NxTest.assert_equal(NxD118::HWC::SEED_SET_VERSION, doc['seed_version'], 'verzia sady bumpnuta')
  NxTest.assert(NxD118::HWC.find('352908'), 'PTOs modul doplneny (je na zozname)')
  NxTest.assert(NxD118::HWC.find('357889'), 'opravena antracit K-sada doplnena')
  NxTest.assert_equal(nil, NxD118::HWC.find('104802'),
                      'zmazany v2 riadok MIMO zoznamu sa nevzkriesi (plny seed sa neleje)')
  NxTest.assert(NxD118::HWC.find('999001'), 'pouzivatelska polozka nedotknuta')

  osviezeny = NxD118::HWC.find('104717')
  NxTest.assert_equal(NxD118.v3_item('104717')['name_sk'], osviezeny['name_sk'],
                      'NEZMENENY v2 riadok dostal overeny nazov')
  NxTest.assert_equal('Hettich', osviezeny['manufacturer'], '… aj vyrobcu')
  NxTest.assert(osviezeny['demos_url'].to_s.start_with?('https://'), '… aj vazbu na stranku')
  NxTest.assert_equal(NxD118::HWC::SEED_PRICE_CHECKED_AT, osviezeny['price_checked_at'],
                      '… aj datum overenia ceny')
end

NxTest.test('D-118 (R5): riadok s vlastnym vyrobcom, radou alebo vazbou sa NEPREPISE') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  s_vyrobcom = NxD118.v2_item('104718').merge('manufacturer' => 'Ostatné')
  s_vazbou   = NxD118.v2_item('104719').merge('demos_url' => 'https://www.demos-trade.sk/moje/')
  s_upravou  = NxD118.v2_item('106412').merge('name_sk' => 'Môj názov')
  NxD118.install_v2!([s_vyrobcom, s_vazbou, s_upravou])
  NxTest.assert_equal(:ok, NxD118::HWC.assess!)

  NxTest.assert_equal('Ostatné', NxD118::HWC.find('104718')['manufacturer'],
                      'vlastna klasifikacia sa neprepise (Astra #21 BLOCKER 1)')
  NxTest.assert_equal(NxD118.v2_item('104718')['name_sk'], NxD118::HWC.find('104718')['name_sk'],
                      '… a nezmeni sa ani nazov')
  NxTest.assert_equal('https://www.demos-trade.sk/moje/', NxD118::HWC.find('104719')['demos_url'],
                      'vlastna vazba na stranku ma prednost')
  NxTest.assert_equal('Môj názov', NxD118::HWC.find('106412')['name_sk'], 'vlastny nazov ostava')
end

NxTest.test('D-118 (R6): use_count a vypnuta aktivnost migraciu prezijú') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  pouzivany = NxD118.v2_item('104717').merge('use_count' => 7)
  vypnuty   = NxD118.v2_item('104454').merge('active' => false)
  NxD118.install_v2!([pouzivany, vypnuty])
  NxTest.assert_equal(:ok, NxD118::HWC.assess!)

  NxTest.assert_equal(7, NxD118::HWC.find('104717')['use_count'], 'use_count prezije')
  NxTest.assert_equal(NxD118.v3_item('104717')['name_sk'], NxD118::HWC.find('104717')['name_sk'],
                      'a riadok sa napriek tomu osviezil')
  NxTest.assert_equal(false, NxD118::HWC.find('104454')['active'],
                      'rucne vypnuta polozka sa NIKDY nezapne spat')
end

NxTest.test('D-118 (R4): klasifikacia seedu prejde ZIVOU taxonomiou, cudzia rada sa VYNECHA') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  # Pouzivatel si uz zalozil radu „StrongBox" POD INYM vyrobcom — taxonomia jeho
  # meno zamerne zachova, takze seed ju tam NESMIE zapisat pod Strongom (Codex
  # #320 P2). Vyrobca sa vyriesi, rada vypadne — polozka bez rady je legalna.
  before = NxD118.install_taxonomy!(%w[Hettich Blum Grass Strong Tulip Ostatné],
                                    [['StrongBox', 'Hettich'], ['InnoTech Atira', 'Hettich']])
  begin
    NxD118.wipe!
    NxTest.assert_equal(:ok, NxD118::HWC.assess!, 'chybajuci subor -> seed')
    box = NxD118::HWC.find('179252')
    NxTest.assert_equal('Strong', box['manufacturer'], 'vyrobca sa vyriesil')
    NxTest.refute(box.key?('series'), 'rada patriaca inemu vyrobcovi sa NEZAPISE')
    atira = NxD118::HWC.find('357695')
    NxTest.assert_equal('InnoTech Atira', atira['series'], 'sediaca rada ostava')
  ensure
    NxD118.restore_taxonomy!(before)
    NxD118.wipe!
  end
end

NxTest.test('D-118 (R4): nad read-only taxonomiou sa klasifikacia NEZAPISUJE (fail-closed)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  before = (File.binread(NxD118::TAX.path) if File.exist?(NxD118::TAX.path))
  begin
    FileUtils.mkdir_p(NxD118::TAX.dir)
    NxD118::STORE.write(NxD118::TAX.path, 'std' => NxD118::TAX::STD,
                                          'schema' => NxD118::TAX::SCHEMA_CURRENT + 5,
                                          'seed_version' => NxD118::TAX::SEED_VERSION,
                                          'manufacturers' => [], 'series' => [])
    NxD118::STORE.invalidate(NxD118::TAX.path)
    NxD118::TAX.reset_state!
    NxD118.wipe!
    NxTest.assert_equal(:ok, NxD118::HWC.assess!)
    rec = NxD118::HWC.find('357695')
    NxTest.refute(rec.key?('manufacturer'), 'bez citatelnej taxonomie ziadny vyrobca')
    NxTest.refute(rec.key?('series'), 'ani rada')
  ensure
    NxD118.restore_taxonomy!(before)
    NxD118.wipe!
  end
end

NxTest.test('D-118 (R4): aj legacy v1 -> v2 doplnenie ide cez ZIVU taxonomiu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  # Rada „Sensys" uz patri inemu vyrobcovi. Krytky 105408/105425, ktore dopĺňa
  # LEGACY vetva v1 -> v2, ju preto zapisat NESMU — inak by ich nasledny v3
  # prechod povazoval za pouzivatelsku upravu a nechal navzdy nekonzistentne.
  before = NxD118.install_taxonomy!(%w[Hettich Blum Grass Strong Tulip Ostatné],
                                    [['Sensys', 'Blum']], seed_version: NxD118::TAX::SEED_VERSION)
  begin
    FileUtils.mkdir_p(NxD118::HWC.dir)
    NxD118::STORE.write(NxD118::HWC.path, 'std' => NxD118::HWC::STD,
                                          'schema' => NxD118::HWC::SCHEMA_CURRENT,
                                          'seed_version' => 1,
                                          'items' => [NxD118.v2_item('104717')])
    FileUtils.rm_f("#{NxD118::HWC.path}.bak")
    NxD118::STORE.invalidate(NxD118::HWC.path)
    NxD118::HWC.reset_state!
    NxTest.assert_equal(:ok, NxD118::HWC.assess!)

    krytka = NxD118::HWC.find('105408')
    NxTest.assert(krytka, 'legacy vetva krytku doplnila')
    NxTest.assert_equal('Hettich', krytka['manufacturer'], 'vyrobca sa vyriesil')
    NxTest.refute(krytka.key?('series'), 'cudzia rada sa NEZAPISE ani v legacy vetve')
  ensure
    NxD118.restore_taxonomy!(before)
    NxD118.wipe!
  end
end

NxTest.test('D-118 (R4): seedovana rada sa naviaze na ULOZENY zapis vyrobcu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  # Pouzivatel ma „STRONG"; merge vyrobcu NEdopĺňa (slug sedi), takze rada
  # zapisana s nasim „Strong" by v selecte rad zmizla — JS filtruje podla
  # PRESNEHO retazca (Codex #320 kolo 2 P2).
  before = NxD118.install_taxonomy!(%w[Hettich Blum Grass STRONG Ostatné], [], seed_version: 1)
  begin
    NxTest.assert(NxD118::TAX.ensure_seeded, 'seed prebehol')
    box = NxD118::TAX.series_of('STRONG').find { |s| s['name'] == 'StrongBox' }
    NxTest.assert(box, 'StrongBox sa naviazal na ulozeny zapis vyrobcu')
    NxTest.assert_equal('STRONG', box['manufacturer'], 'vlastnik = ULOZENY tvar mena')
    mans = NxD118::TAX.manufacturers.map { |m| m['name'] }
    NxTest.assert(mans.include?('STRONG') && !mans.include?('Strong'),
                  "vyrobca sa nezdvojil: #{mans.inspect}")
  ensure
    NxD118.restore_taxonomy!(before)
  end
end

NxTest.test('D-118 (R4): seed aj migracia sa pytaju taxonomie PRED katalogovym zamkom') do
  # Taxonomia ma vlastny sidecar; vnorit ho do katalogoveho zamku by vyrobilo
  # PORADIE zamkov (rovnaky zdrojovy guard ako pri create_item/patch_item).
  src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_catalog.rb'))
            .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  %w[seed! apply_seed_patches!].each do |m|
    body = src[/^      def #{Regexp.escape(m)}.*?\n      end\n/m].to_s
    NxTest.assert(!body.empty?, "telo `#{m}` sa naslo")
    gate = body.index('seed_items_resolved')
    lock = body.index('with_lock do')
    NxTest.assert(gate && lock, "#{m}: rozlisenie taxonomie aj zamok su v tele")
    NxTest.assert(gate < lock, "#{m}: taxonomia sa pyta PRED katalogovym zamkom")
  end
end

NxTest.test('D-118 (R5): read-only katalog sa migraciou nedotkne') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  FileUtils.mkdir_p(NxD118::HWC.dir)
  NxD118::STORE.write(NxD118::HWC.path, 'std' => NxD118::HWC::STD,
                                        'schema' => NxD118::HWC::SCHEMA_CURRENT + 5,
                                        'seed_version' => 2, 'items' => [])
  NxD118::STORE.invalidate(NxD118::HWC.path)
  NxD118::HWC.reset_state!
  NxTest.assert_equal(:read_only, NxD118::HWC.assess!, 'novsia schema = read-only')
  doc = NxD118::STORE.read(NxD118::HWC.path)
  NxTest.assert_equal(2, doc['seed_version'], 'do cudzieho suboru sa nezapisuje')
  NxTest.assert_equal([], doc['items'], 'ani polozky')
ensure
  NxD118.wipe!
end
