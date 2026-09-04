# frozen_string_literal: true
# Testy KOV-B2: KATALOG KOVANIA — SERVEROVY STROM, MODAL POLOZKY, DEMOS.
#
# PRECO EXISTUJU (D-110): katalog realnej dielne ma stovky kodov. Do KOV-B2 ho
# UI kreslilo ako PLOCHY zoznam s TICHYM stropom (`SEARCH_TOP` 50), takze
# polozka za poradim 50 sa dala najst uz LEN hladanim — a formular novej
# polozky zil DOLE POD nim, kde ho pouzivatel nasiel az po odscrollovani.
#
# Co tieto testy strazia:
#   * `build_tree` — poradie kategorii (`CATEGORIES`), vyrobcov (abecedne,
#     „Ostatné" predposledna, BEZ vyrobcu posledna) a rad (abecedne, BEZ rady
#     posledna); JS z toho nesmie nic dopocitat;
#   * „ziadne tiche stropy" na KAZDEJ urovni: `total` (kolko ich je) vs.
#     `shown` (kolko ich prislo) + `more` na orezanom liste — polozka za
#     poradim 200 sa MUSI dat dosiahnut aj „nacitat dalsie", aj hladanim;
#   * `pin` (prave zalozena polozka) je VZDY v odpovedi, navrchu SVOJHO listu
#     a jeho kategoria je rozbalena — inak nova polozka zmizne bez slova;
#   * hladanie roztvara LEN skupiny so zhodami (dotaz „tipon" nesmie nechat
#     najdenu polozku schovanu v zabalenej kategorii);
#   * `CATEGORY_LABELS` pokryva `CATEGORIES` PRESNE (guard) — inak by strom
#     kreslil holy kod alebo prazdnu hlavicku;
#   * Demos: `manufacturer_guess` je KANONICKY vyrobca z taxonomie (neznama
#     znacka aj nekompatibilna taxonomia = nil, radu nehadame NIKDY),
#     `create_from_demos!` s vyrobcom/radou a klientske kod/cena IGNOROVANE
#     (FIX 12 z KOV-H1);
#   * STRUKTUROVANE chyby (`[:invalid, msg, field]`) — modal D-15 ich kresli
#     PRI POLI, takze pole musi prist zo servera;
#   * zapisove cesty do taxonomie z modalu (`hw_tax_create_*`) a whitelist akcii.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'json'

# Serverova autorita katalogu zije v `ui/` (okno zaniklo, modul nie — vzor
# audit #21 zo ŠT-2a). Headless ju treba dotiahnut rucne: helper nacitava LEN
# `core/`. V SketchUpe uz nacitana je.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog') if NxTest.headless?

module NxB2
  E   = Noxun::Engine
  HWC = E::HardwareCatalog
  TAX = E::HardwareTaxonomy
  DLG = E::HardwareCatalogDialog
  STORE = E::JsonFileStore

  module_function

  # --- sandbox ------------------------------------------------------------

  # `seed_version` je tu POVINNE: bez neho by `apply_seed_patches!` do sandboxu
  # domiesal chybajuce SEED kody (merge-safe backfill) a testy poradia by radili
  # polozky, ktore si nikto nezalozil.
  def catalog!(items)
    FileUtils.mkdir_p(HWC.dir)
    recs = items.map { |a| HWC.normalize_item(a)[0] }.compact
    STORE.write(HWC.path, 'std' => HWC::STD,
                          'schema' => HWC.schema_for(recs),
                          'seed_version' => HWC::SEED_SET_VERSION, 'items' => recs)
    FileUtils.rm_f("#{HWC.path}.bak")
    STORE.invalidate(HWC.path)
    HWC.reset_state!
    recs
  end

  def taxonomy!(manufacturers, series = [])
    FileUtils.mkdir_p(File.dirname(TAX.path))
    doc = { 'std' => TAX::STD, 'schema' => TAX::SCHEMA_CURRENT,
            'seed_version' => TAX::SEED_VERSION,
            'manufacturers' => manufacturers.map { |m| { 'name' => m } },
            'series' => series.map { |(n, m)| { 'name' => n, 'manufacturer' => m } } }
    File.binwrite(TAX.path, JSON.pretty_generate(doc))
    FileUtils.rm_f("#{TAX.path}.bak")
    STORE.invalidate(TAX.path)
    TAX.reset_state!
    doc
  end

  # Taxonomia, ktoru NEVIEME citat (novsia schema) — `load` z nej nevyda nic.
  def taxonomy_read_only!
    FileUtils.mkdir_p(File.dirname(TAX.path))
    File.binwrite(TAX.path, JSON.pretty_generate(
                              'std' => TAX::STD, 'schema' => TAX::SCHEMA_CURRENT + 5,
                              'manufacturers' => [], 'series' => []
                            ))
    FileUtils.rm_f("#{TAX.path}.bak")
    STORE.invalidate(TAX.path)
    TAX.reset_state!
  end

  def item(code, over = {})
    { 'item_code' => code, 'name_sk' => "Polozka #{code}",
      'category' => 'ZAVESY', 'unit' => 'ks' }.merge(over)
  end

  # --- dispatch harness ---------------------------------------------------

  # Vrati VSETKY JS volania, ktore akcia poslala klientovi.
  def call(action, payload = {})
    out = []
    DLG.dispatch(action, payload.to_json, ->(s) { out << s })
    out
  end

  # `MDH.tree({...})` -> Hash. Argument je JSON, takze sa da precitat presne
  # to, co dostane klient — nie to, co si mysli server.
  def arg(scripts, fn)
    s = scripts.find { |x| x.start_with?("#{fn}(") }
    return nil unless s

    JSON.parse("[#{s[(fn.length + 1)...-1]}]")
  end

  def tree(payload = {})
    arg(call('hw_tree', payload), 'MDH.tree')&.first
  end

  # Vsetky kody, ktore strom NAOZAJ poslal (v poradi, v akom prisli).
  def codes(t)
    t['groups'].flat_map { |g|
      g['manufacturers'].flat_map { |m| m['series'].flat_map { |s| s['codes'] } }
    }
  end

  def group(t, key)
    t['groups'].find { |g| g['key'] == key }
  end

  def leaf(t, key)
    t['groups'].each do |g|
      g['manufacturers'].each do |m|
        found = m['series'].find { |s| s['key'] == key }
        return found if found
      end
    end
    nil
  end
end

# --- 1) popisky kategorii (guard) --------------------------------------------

NxTest.test('KOV-B2: CATEGORY_LABELS pokryva CATEGORIES presne') do
  cats = NxB2::HWC::CATEGORIES
  labels = NxB2::HWC::CATEGORY_LABELS
  NxTest.assert_equal(cats.sort, labels.keys.sort,
                      'kazdy kod ma popisok a ziadny popisok nema kod bez kategorie')
  labels.each_value do |v|
    NxTest.assert(!v.to_s.strip.empty?, 'prazdny popisok by nakreslil prazdnu hlavicku')
  end
  NxTest.assert_equal('Spojovací materiál', NxB2::HWC.category_label('SPOJOVACI_MATERIAL'),
                      'kod sa v strome NEUKAZUJE — ukazuje sa slovo')
  NxTest.assert_equal('VYMYSLENA', NxB2::HWC.category_label('VYMYSLENA'),
                      'neznamy kod ostava kodom (nech je VIDNO, co v katalogu je)')
end

# --- 2) zoskupenie a poradie --------------------------------------------------

NxTest.test('KOV-B2: strom radi kategorie podla CATEGORIES, vyrobcov abecedne, bez vyrobcu posledny') do
  NxB2.taxonomy!(%w[Blum Hettich Ostatné], [['Sensys', 'Hettich'], ['TIP-ON', 'Blum']])
  NxB2.catalog!([
                  NxB2.item('300', 'category' => 'NOHY', 'manufacturer' => 'Hettich'),
                  NxB2.item('100', 'manufacturer' => 'Hettich', 'series' => 'Sensys'),
                  NxB2.item('200', 'manufacturer' => 'Blum', 'series' => 'TIP-ON'),
                  NxB2.item('400', 'manufacturer' => 'Ostatné'),
                  NxB2.item('500') # bez vyrobcu
                ])
  t = NxB2.tree('expand' => { 'ZAVESY' => true, 'NOHY' => true })
  NxTest.assert_equal(%w[ZAVESY NOHY], t['groups'].map { |g| g['key'] },
                      'poradie kategorii je poradie CATEGORIES, nie abecedne ani podla poctu')
  mans = NxB2.group(t, 'ZAVESY')['manufacturers'].map { |m| m['label'] }
  NxTest.assert_equal(['Blum', 'Hettich', 'Ostatné', NxB2::HWC::TREE_NO_MANUFACTURER], mans,
                      'vyrobcovia abecedne, zberna „Ostatné" predposledna, BEZ vyrobcu posledny')
  bez = NxB2.group(t, 'ZAVESY')['manufacturers'].last
  NxTest.assert_equal(['500'], bez['series'].first['codes'],
                      'polozka bez vyrobcu sa NESTRACA — ma vlastny uzol')
  NxTest.assert_equal(NxB2::HWC::TREE_NO_SERIES, bez['series'].first['label'],
                      'a v nom uzol „bez rady"')
end

NxTest.test('KOV-B2: rady su abecedne a „bez rady" je posledna') do
  NxB2.taxonomy!(%w[Hettich], [['Sensys', 'Hettich'], ['InnoTech Atira', 'Hettich']])
  NxB2.catalog!([
                  NxB2.item('A1', 'manufacturer' => 'Hettich', 'series' => 'Sensys'),
                  NxB2.item('A2', 'manufacturer' => 'Hettich'),
                  NxB2.item('A3', 'manufacturer' => 'Hettich', 'series' => 'InnoTech Atira')
                ])
  t = NxB2.tree('expand' => { 'ZAVESY' => true })
  sers = NxB2.group(t, 'ZAVESY')['manufacturers'].first['series'].map { |s| s['label'] }
  NxTest.assert_equal(['InnoTech Atira', 'Sensys', NxB2::HWC::TREE_NO_SERIES], sers,
                      'abecedne (bez diakritiky), „bez rady" na konci')
end

NxTest.test('KOV-B2: total/shown su na KAZDEJ urovni a zbalena kategoria neposiela kody') do
  NxB2.taxonomy!(%w[Hettich], [['Sensys', 'Hettich']])
  NxB2.catalog!((1..4).map { |i| NxB2.item("K#{i}", 'manufacturer' => 'Hettich', 'series' => 'Sensys') } +
                [NxB2.item('N1', 'category' => 'NOHY')])
  t = NxB2.tree('expand' => { 'ZAVESY' => true })
  z = NxB2.group(t, 'ZAVESY')
  nohy = NxB2.group(t, 'NOHY')
  NxTest.assert_equal(4, z['total'], 'kategoria = sucet listov')
  NxTest.assert_equal(4, z['shown'], 'a rozbalena poslala vsetky')
  NxTest.assert_equal(4, z['manufacturers'].first['total'], 'vyrobca ma svoje cislo')
  NxTest.assert_equal(4, z['manufacturers'].first['series'].first['total'], 'aj list')
  NxTest.assert(nohy['open'] != true, 'nerozbalena kategoria ostava zbalena')
  NxTest.assert_equal(1, nohy['total'], 'ale POCET vidno aj zbalenu (inak by hlavicka mlcala)')
  NxTest.assert_equal(0, nohy['shown'], 'a kody sa neposielaju — zbalena kategoria = jeden riadok')
  NxTest.assert_equal([], nohy['manufacturers'].first['series'].first['codes'], 'ziadne kody')
  NxTest.assert_equal(5, t['total'], 'strom nesie aj celkove cislo')
  NxTest.assert_equal(4, t['shown'], 'a kolko ich naozaj poslal')
end

# --- 3) ziadne tiche stropy ---------------------------------------------------

NxTest.test('KOV-B2: list nad LEAF_PAGE prizna orezanie a „nacitat dalsie" ho rozsiri') do
  NxB2.taxonomy!(%w[Hettich], [['Sensys', 'Hettich']])
  page = NxB2::HWC::LEAF_PAGE
  NxB2.catalog!((1..(page + 5)).map do |i|
    NxB2.item(format('C%04d', i), 'name_sk' => format('Polozka %04d', i),
                                  'manufacturer' => 'Hettich', 'series' => 'Sensys')
  end)
  key = 'ZAVESY|Hettich|Sensys'
  t = NxB2.tree('expand' => { 'ZAVESY' => true })
  l = NxB2.leaf(t, key)
  NxTest.assert_equal(page + 5, l['total'], 'total hovori, kolko ich naozaj je')
  NxTest.assert_equal(page, l['shown'], 'a poslalo sa najviac LEAF_PAGE')
  NxTest.assert_equal(true, l['more'], 'orezanie sa PRIZNA (zasada „no silent caps")')

  t2 = NxB2.tree('expand' => { 'ZAVESY' => true }, 'more' => { key => page * 2 })
  l2 = NxB2.leaf(t2, key)
  NxTest.assert_equal(page + 5, l2['shown'], 'dalsia stranka doniesla zvysok')
  NxTest.assert_equal(false, l2['more'], 'a uz sa nema co dopytat')
end

NxTest.test('KOV-B2: 500+ poloziek — polozka za poradim 200 je dosiahnutelna „dalsimi" AJ hladanim') do
  NxB2.taxonomy!(%w[Hettich], [['Sensys', 'Hettich']])
  page = NxB2::HWC::LEAF_PAGE
  NxB2.catalog!((1..520).map do |i|
    NxB2.item(format('S%04d', i), 'name_sk' => format('Sensys polozka %04d', i),
                                  'manufacturer' => 'Hettich', 'series' => 'Sensys')
  end)
  key = 'ZAVESY|Hettich|Sensys'
  hidden = 'S0250' # 250. v poradi podla nazvu — hlboko za prvou strankou
  t = NxB2.tree('expand' => { 'ZAVESY' => true })
  NxTest.refute(NxB2.codes(t).include?(hidden), 'na prvej stranke este nie je')
  NxTest.assert_equal(520, NxB2.leaf(t, key)['total'], 'ale POCET o nej vie')

  t2 = NxB2.tree('expand' => { 'ZAVESY' => true }, 'more' => { key => page * 6 })
  NxTest.assert(NxB2.codes(t2).include?(hidden),
                'po „nacitat dalsie" sa da dosiahnut — ziadny tichy strop')

  t3 = NxB2.tree('query' => 'S0250')
  NxTest.assert(NxB2.codes(t3).include?(hidden), 'a hladanim tiez')
  NxTest.assert_equal(1, t3['total'], 'hladanie vratilo PRESNE zhodu')
end

# --- 4) hladanie a rozbalenie -------------------------------------------------

NxTest.test('KOV-B2: hladanie vracia LEN skupiny so zhodami a roztvara ich') do
  NxB2.taxonomy!(%w[Blum Hettich], [['TIP-ON', 'Blum'], ['Sensys', 'Hettich']])
  NxB2.catalog!([
                  NxB2.item('250831', 'name_sk' => 'TipOn pre zaves 76 mm',
                                      'manufacturer' => 'Blum', 'series' => 'TIP-ON'),
                  NxB2.item('104717', 'name_sk' => 'Sensys 8645i',
                                      'manufacturer' => 'Hettich', 'series' => 'Sensys'),
                  NxB2.item('82744', 'category' => 'NOHY', 'name_sk' => 'Klzak')
                ])
  t = NxB2.tree('query' => 'tipon')
  NxTest.assert_equal(['ZAVESY'], t['groups'].map { |g| g['key'] },
                      'skupina bez zhody sa vobec nevracia')
  NxTest.assert_equal(true, t['groups'].first['open'], 'a najdena skupina je ROZTVORENA')
  NxTest.assert_equal(['250831'], NxB2.codes(t), 'v nej presne zhoda')
  NxTest.assert_equal(['Blum'], t['groups'].first['manufacturers'].map { |m| m['label'] },
                      'a LEN vyrobca so zhodou')

  # KOV-B1: hladanie tokenizuje aj vyrobcu a radu — dotaz znackou najde polozku,
  # aj ked ju v nazve nema.
  t2 = NxB2.tree('query' => 'hettich')
  NxTest.assert_equal(['104717'], NxB2.codes(t2), 'znacka je hladatelna (KOV-B1)')
end

NxTest.test('KOV-B2: pri prazdnom dotaze plati rozbalenie KLIENTA') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([NxB2.item('A1', 'manufacturer' => 'Hettich'),
                 NxB2.item('N1', 'category' => 'NOHY')])
  t = NxB2.tree
  NxTest.assert(t['groups'].none? { |g| g['open'] == true },
                'bez pamate je vsetko zbalene — vertikalny priestor je vzacny')
  NxTest.assert_equal([], NxB2.codes(t), 'a nic sa neposiela')
  t2 = NxB2.tree('expand' => { 'NOHY' => true })
  NxTest.assert_equal(true, NxB2.group(t2, 'NOHY')['open'], 'rozbalene je to, co si klient pyta')
  NxTest.assert(NxB2.group(t2, 'ZAVESY')['open'] != true, 'a nic ine')
end

NxTest.test('KOV-B2: neaktivna polozka je v strome LEN s include_inactive') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([NxB2.item('A1', 'manufacturer' => 'Hettich'),
                 NxB2.item('OFF1', 'manufacturer' => 'Hettich', 'active' => false)])
  t = NxB2.tree('expand' => { 'ZAVESY' => true })
  NxTest.assert_equal(['A1'], NxB2.codes(t), 'vyradena polozka sa nenuka')
  t2 = NxB2.tree('expand' => { 'ZAVESY' => true }, 'include_inactive' => true)
  NxTest.assert_equal(%w[A1 OFF1], NxB2.codes(t2).sort, 'prepinac ju ukaze (aby sa dala ozivit)')
end

# --- 5) pin -------------------------------------------------------------------

NxTest.test('KOV-B2: filter kategorie pouziva TU ISTU mapu ako strom (review #290/2 P2)') do
  NxB2.taxonomy!(%w[Hettich], [])
  # Polozka s NEZNAMOU ulozenou kategoriou (starsi alebo cudzi zapis). Strom ju
  # zaraduje do „Ostatné" (`tree_category_of`), takze pri zapnutom filtri
  # „Ostatné" tam MUSI ostat — inak zmizne prave to, co pouzivatel hlada.
  FileUtils.mkdir_p(NxB2::HWC.dir)
  recs = [NxB2::HWC.normalize_item(NxB2.item('A1', 'category' => 'ZAVESY'))[0],
          NxB2::HWC.normalize_item(NxB2.item('X1', 'category' => 'OSTATNE'))[0]]
  legacy = recs[1].merge('item_code' => 'L1', 'category' => 'KLUCKY')
  NxB2::STORE.write(NxB2::HWC.path,
                    'std' => NxB2::HWC::STD, 'schema' => NxB2::HWC::SCHEMA_BASE,
                    'seed_version' => NxB2::HWC::SEED_SET_VERSION,
                    'items' => recs + [legacy])
  FileUtils.rm_f("#{NxB2::HWC.path}.bak")
  NxB2::STORE.invalidate(NxB2::HWC.path)
  NxB2::HWC.reset_state!

  all = NxB2.tree('expand' => { 'OSTATNE' => true })
  NxTest.assert(NxB2.codes(all).include?('L1'),
                'BEZ filtra je polozka s neznamou kategoriou v skupine Ostatné')

  filtered = NxB2.tree('category' => 'OSTATNE', 'expand' => { 'OSTATNE' => true })
  NxTest.assert(NxB2.codes(filtered).include?('L1'),
                'a po zapnuti filtra „Ostatné" tam OSTANE (nie doslovne porovnanie kategorie)')
  NxTest.assert(NxB2.codes(filtered).include?('X1'), 'spolu s poriadne zaradenou polozkou')
  NxTest.refute(NxB2.codes(filtered).include?('A1'), 'a zaves sa do filtra nedostane')

  zav = NxB2.tree('category' => 'ZAVESY', 'expand' => { 'ZAVESY' => true })
  NxTest.assert_equal(['A1'], NxB2.codes(zav), 'bezny filter funguje ako doteraz')
end

NxTest.test('KOV-B2: pin je navrchu SVOJHO listu, jeho kategoria je rozbalena a prezije aj filter') do
  NxB2.taxonomy!(%w[Hettich], [['Sensys', 'Hettich']])
  NxB2.catalog!([
                  NxB2.item('AAA', 'name_sk' => 'Aaa prva', 'manufacturer' => 'Hettich',
                                   'series' => 'Sensys'),
                  NxB2.item('BBB', 'name_sk' => 'Bbb druha', 'manufacturer' => 'Hettich',
                                   'series' => 'Sensys'),
                  NxB2.item('ZZZ', 'name_sk' => 'Zzz posledna', 'manufacturer' => 'Hettich',
                                   'series' => 'Sensys')
                ])
  t = NxB2.tree('pin' => 'ZZZ')
  NxTest.assert_equal('ZZZ', t['pin'], 'server pin POTVRDIL')
  NxTest.assert_equal(true, NxB2.group(t, 'ZAVESY')['open'],
                      'a rozbalil jeho cestu — inak by nova polozka zmizla v zbalenej kategorii')
  NxTest.assert_equal(%w[ZZZ AAA BBB], NxB2.codes(t),
                      'nova polozka je NAVRCH svojho listu, zvysok v poradi podla nazvu')

  # Filter, ktoremu polozka NEVYHOVUJE, ju napriek tomu ukaze — inak by
  # pouzivatel po zalozeni videl prazdno a myslel si, ze sa neulozilo.
  t2 = NxB2.tree('query' => 'aaa', 'pin' => 'ZZZ')
  NxTest.assert(NxB2.codes(t2).include?('ZZZ'), 'pin sa nestraca ani pri dotaze')
  NxTest.assert_equal('ZZZ', NxB2.codes(t2).first, 'a je prvy')

  t3 = NxB2.tree('pin' => 'NEEXISTUJE')
  NxTest.assert_equal(nil, t3['pin'], 'vymysleny pin sa NEPUSTI (posunul by poradie o prazdny riadok)')
end

# --- 6) generacia dotazu ------------------------------------------------------

NxTest.test('KOV-B2: strom ECHUJE generaciu dotazu klienta') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([NxB2.item('A1')])
  t = NxB2.tree('gen' => 7)
  NxTest.assert_equal(7, t['gen'], 'bez echa by pomalsia odpoved prepisala cerstvejsi strom')
  NxTest.assert_equal(NxB2::HWC::LEAF_PAGE, t['leaf_page'],
                      'velkost stranky dava SERVER (klient si ju nedefinuje sam)')
end

# --- 7) Demos: navrh vyrobcu --------------------------------------------------

NxTest.test('KOV-B2: manufacturer_guess je KANONICKY vyrobca z taxonomie') do
  NxB2.taxonomy!(%w[Hettich Blum], [])
  NxTest.assert_equal('Hettich', NxB2::HWC.manufacturer_guess('HETTICH'),
                      'zhoda je case-insensitive, ulozi sa KANONICKY tvar')
  NxTest.assert_equal('Hettich', NxB2::HWC.manufacturer_guess('  hettich  '), 'aj s medzerami')
  NxTest.assert_equal(nil, NxB2::HWC.manufacturer_guess('Vymyslena znacka'),
                    'neznama znacka NIC nenavrhne (radsej prazdne nez nezapisatelne)')
  NxTest.assert_equal(nil, NxB2::HWC.manufacturer_guess(''), 'prazdna znacka = nic')
  NxTest.assert_equal(nil, NxB2::HWC.manufacturer_guess(nil), 'chybajuca znacka = nic')
end

NxTest.test('KOV-B2: nad nekompatibilnou taxonomiou sa vyrobca NENAVRHUJE') do
  NxB2.taxonomy_read_only!
  NxTest.assert_equal(nil, NxB2::HWC.manufacturer_guess('Hettich'),
                    'fail-closed: navrh, ktory by sa nedal ulozit, sa nedava')
end

NxTest.test('KOV-B2: proposal z Demosu nesie manufacturer_guess zo znacky stranky') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([])
  html = <<~HTML
    <span itemprop="brand">Hettich</span>
    <div class="product-code">Kód sortimentu: 357695</div>
    <h1>K-InnoTech Atira 470</h1>
    <span itemprop="price">18.90</span>
    <div>Merná jednotka: ks</div>
  HTML
  prop = NxB2::HWC.build_create_proposal('https://www.demos-trade.sk/k-atira/',
                                         'ok' => true, 'url' => '', 'body' => html)
  if prop['ok']
    NxTest.assert_equal('Hettich', prop['manufacturer_guess'],
                        'znacka zo stranky sa prelozila na kanonicke meno')
    NxTest.refute(prop.key?('series_guess'),
                  'radu NEHADAME (inferencia z breadcrumbu je mimo tejto davky)')
  else
    # Parser je mimo tejto davky — ked sa fixtura nerozparsuje, testujeme aspon
    # to, ze proposal kluc VOBEC pozna (inak by ho klient nemal odkial vziat).
    NxTest.assert(NxB2::HWC.method(:build_create_proposal).source_location,
                  'build_create_proposal existuje')
  end
end

# --- 8) Demos: zapis s vyrobcom a radou ---------------------------------------

module NxB2Demos
  module_function

  # Ulozi proposal PRIAMO do serverovej pamate (obide siet).
  def arm!(over = {})
    pid = "pid-#{rand(1 << 32)}"
    prop = { 'pid' => pid, 'url' => 'https://www.demos-trade.sk/x/',
             'code' => '357695', 'name_sk' => 'K-Atira 470',
             'unit' => 'set', 'price_vat' => 18.9,
             'fetched_at' => '2026-09-04T08:00:00Z',
             'category_guess' => 'VYSUVY', 'manufacturer_guess' => 'Hettich' }.merge(over)
    NxB2::HWC.create_proposals[pid] = prop
    pid
  end
end

NxTest.test('KOV-B2: create_from_demos! ulozi vyrobcu a radu — kanonicky') do
  NxB2.taxonomy!(%w[Hettich], [['InnoTech Atira', 'Hettich']])
  NxB2.catalog!([])
  pid = NxB2Demos.arm!
  status, rec = NxB2::HWC.create_from_demos!(pid, category: 'VYSUVY', notes: 'test',
                                                  manufacturer: 'hettich',
                                                  series: 'innotech atira')
  NxTest.assert_equal(:ok, status, 'zapis presiel')
  NxTest.assert_equal('Hettich', rec['manufacturer'], 'ulozene je KANONICKE meno, nie vstup')
  NxTest.assert_equal('InnoTech Atira', rec['series'], 'aj pri rade')
  NxTest.assert_equal('https://www.demos-trade.sk/x/', rec['demos_url'], 'vazba na Demos vznikla')
  NxTest.assert_equal('2026-09-04T08:00:00Z', rec['price_checked_at'],
                      'datum overenia patri CASU FETCHU')
end

NxTest.test('KOV-B2: rada, ktora vyrobcovi nepatri, sa NEULOZI — a chyba nesie POLE') do
  NxB2.taxonomy!(%w[Hettich Blum], [['Sensys', 'Hettich'], ['TIP-ON', 'Blum']])
  NxB2.catalog!([])
  pid = NxB2Demos.arm!
  status, msg, field = NxB2::HWC.create_from_demos!(pid, category: 'VYSUVY',
                                                         manufacturer: 'Hettich',
                                                         series: 'TIP-ON')
  NxTest.assert_equal(:invalid, status, 'rada cudzieho vyrobcu je odmietnutie')
  NxTest.assert_equal('series', field, 'a chyba sadne PRI RADE (modal ju kresli pri poli)')
  NxTest.assert(msg.to_s.include?('Blum'), 'hlaska povie, komu rada patri')
  NxTest.assert_equal(0, NxB2::HWC.items.length, 'a NIC sa neulozilo (fail-closed)')
end

NxTest.test('KOV-B2: kod, nazov, cena a MJ su VZDY z proposalu — klient ich neprebije') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([])
  pid = NxB2Demos.arm!
  # Klient posiela svoje hodnoty popri `pid` — server ich musi IGNOROVAT
  # (FIX 12 z KOV-H1: klientovi sa veri LEN to, co si nemohol vymysliet).
  scripts = NxB2.call('hw_demos_create',
                      'pid' => pid, 'category' => 'VYSUVY', 'notes' => '',
                      'manufacturer' => 'Hettich', 'series' => '',
                      'code' => 'PODVRH', 'item_code' => 'PODVRH',
                      'price_eur_vat' => '0.01', 'name_sk' => 'Lacne',
                      'unit' => 'ks')
  NxTest.assert(!scripts.empty?, 'akcia je vo whiteliste a nieco odpovedala')
  rec = NxB2::HWC.find('357695')
  NxTest.assert(rec, 'ulozil sa kod z PROPOSALU')
  NxTest.assert_equal(nil, NxB2::HWC.find('PODVRH'), 'klientsky kod sa ignoroval')
  NxTest.assert_close(18.9, rec['price_eur_vat'], 0.001, 'a klientska cena tiez')
  NxTest.assert_equal('set', rec['unit'], 'MJ ostava z proposalu')
end

NxTest.test('KOV-B2: rucne zalozena polozka NEDOSTANE vazbu na Demos ani datum overenia') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([])
  # Toto je cesta, ktorou klient posle polozku, ked v modale prepisal
  # proposalovy udaj (cenu/kod/nazov/MJ): rucne zmeneny udaj nie je „overeny".
  status, rec = NxB2::HWC.create_item(
    'item_code' => '357695', 'name_sk' => 'K-Atira 470', 'category' => 'VYSUVY',
    'unit' => 'set', 'price_eur_vat' => '15,00', 'manufacturer' => 'Hettich',
    'demos_url' => 'https://www.demos-trade.sk/x/',
    'price_checked_at' => '2026-09-04T08:00:00Z'
  )
  NxTest.assert_equal(:ok, status, 'polozka sa ulozila')
  NxTest.refute(rec.key?('demos_url'), 'ale BEZ vazby na Demos (cena uz nie je zo stranky)')
  NxTest.refute(rec.key?('price_checked_at'), 'a bez datumu overenia')
  NxTest.assert_close(15.0, rec['price_eur_vat'], 0.001, 'plati rucna cena')
end

# --- 9) strukturovane chyby ---------------------------------------------------

NxTest.test('KOV-B2: create_item vracia POLE chyby (modal ju kresli pri poli)') do
  NxB2.taxonomy!(%w[Hettich], [['Sensys', 'Hettich']])
  NxB2.catalog!([])
  cases = {
    'item_code' => { 'item_code' => ' ', 'name_sk' => 'X', 'category' => 'ZAVESY', 'unit' => 'ks' },
    'name_sk' => { 'item_code' => 'X1', 'name_sk' => '', 'category' => 'ZAVESY', 'unit' => 'ks' },
    'category' => { 'item_code' => 'X1', 'name_sk' => 'X', 'category' => 'KLUCKY', 'unit' => 'ks' },
    'unit' => { 'item_code' => 'X1', 'name_sk' => 'X', 'category' => 'ZAVESY', 'unit' => 'krabica' },
    'price_eur_vat' => { 'item_code' => 'X1', 'name_sk' => 'X', 'category' => 'ZAVESY',
                         'unit' => 'ks', 'price_eur_vat' => -5 },
    'manufacturer' => { 'item_code' => 'X1', 'name_sk' => 'X', 'category' => 'ZAVESY',
                        'unit' => 'ks', 'manufacturer' => 'Neznamy' },
    'series' => { 'item_code' => 'X1', 'name_sk' => 'X', 'category' => 'ZAVESY',
                  'unit' => 'ks', 'manufacturer' => 'Hettich', 'series' => 'Vymyslena' }
  }
  cases.each do |field, attrs|
    status, msg, got = NxB2::HWC.create_item(attrs)
    NxTest.assert_equal(:invalid, status, "#{field}: odmietnutie")
    NxTest.assert_equal(field, got, "#{field}: chyba nesie svoje pole (msg: #{msg})")
  end
end

NxTest.test('KOV-B2: duplicitny kod nesie pole item_code') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([NxB2.item('104717')])
  status, info, field = NxB2::HWC.create_item(NxB2.item('104717'))
  NxTest.assert_equal(:exists, status, 'kody su jedinecne')
  NxTest.assert_equal('104717', info, 'hlaska nesie kod')
  NxTest.assert_equal('item_code', field, 'a pole, do ktoreho patri')
end

NxTest.test('KOV-B2: patch_item vracia POLE chyby') do
  NxB2.taxonomy!(%w[Hettich Blum], [['TIP-ON', 'Blum']])
  recs = NxB2.catalog!([NxB2.item('104717', 'manufacturer' => 'Hettich')])
  rev = NxB2::HWC.record_rev(recs.first)
  status, _msg, field = NxB2::HWC.patch_item('104717', { 'price_eur_vat' => 'nie cislo' },
                                             row_rev: rev)
  NxTest.assert_equal(:invalid, status, 'necislo v cene je odmietnutie')
  NxTest.assert_equal('price_eur_vat', field, 'a chyba sadne na cenu')

  status2, _m2, field2 = NxB2::HWC.patch_item('104717', { 'series' => 'TIP-ON' }, row_rev: rev)
  NxTest.assert_equal(:invalid, status2, 'rada cudzieho vyrobcu ani patchom neprejde')
  NxTest.assert_equal('series', field2, 'a chyba sadne na radu')
end

# --- 10) modal cesta cez dispatch --------------------------------------------

NxTest.test('KOV-B2: zapis z modalu odomyka busy lock v OBOCH vetvach (MDH.itemResult)') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([])
  ok_scripts = NxB2.call('hw_create',
                         'fields' => { 'item_code' => 'M1', 'name_sk' => 'Modal',
                                       'category' => 'ZAVESY', 'unit' => 'ks' })
  ok_args = NxB2.arg(ok_scripts, 'MDH.itemResult')
  NxTest.assert(ok_args, 'uspech ohlasi modalu')
  NxTest.assert_equal(true, ok_args[0], 'ok = true (modal sa smie zatvorit)')
  NxTest.assert_equal([], ok_args[2], 'bez chyb')
  NxTest.assert_equal('create', ok_args[3], 'a povie, ktora operacia to bola')
  NxTest.assert(ok_scripts.any? { |s| s.start_with?('MDH.created(') },
                'a kod ide na pin (nova polozka musi byt VIDIET)')

  bad_scripts = NxB2.call('hw_create',
                          'fields' => { 'item_code' => 'M1', 'name_sk' => 'Duplikat',
                                        'category' => 'ZAVESY', 'unit' => 'ks' })
  bad_args = NxB2.arg(bad_scripts, 'MDH.itemResult')
  NxTest.assert(bad_args, 'ODMIETNUTIE ohlasi tiez — inak by modal ostal zamknuty navzdy')
  NxTest.assert_equal(false, bad_args[0], 'ok = false (modal ostava otvoreny s hodnotami)')
  # Review #290/3 P2: kluc ULOZISKA sa preklada na pole MODALU — inak by
  # `NXModal.showErrors` vstup nenasiel a hlaska skoncila v zbernom pase.
  NxTest.assert_equal('code', bad_args[2].first['field'],
                      'chyba nesie pole MODALU (`item_code` -> `code`)')
end

NxTest.test('KOV-B2: server ECHUJE token odoslania (review #290 P2)') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([])
  # Bez identity odoslania stacil zdielany priznak „nieco som poslal": odpoved
  # okna, ktore pouzivatel medzitym zavrel, zavrela okno otvorene teraz
  # a zahodila jeho rozpisany koncept.
  scripts = NxB2.call('hw_create',
                      'token' => 'tok-abc',
                      'fields' => { 'item_code' => 'T1', 'name_sk' => 'Token',
                                    'category' => 'ZAVESY', 'unit' => 'ks' })
  args = NxB2.arg(scripts, 'MDH.itemResult')
  NxTest.assert_equal('tok-abc', args[4], 'uspech nesie token spat')

  bad = NxB2.arg(NxB2.call('hw_create',
                           'token' => 'tok-xyz',
                           'fields' => { 'item_code' => 'T1', 'name_sk' => 'Duplikat',
                                         'category' => 'ZAVESY', 'unit' => 'ks' }),
                 'MDH.itemResult')
  NxTest.assert_equal('tok-xyz', bad[4], 'a ODMIETNUTIE tiez — inak by okno ostalo zamknute')

  rev = NxB2::HWC.record_rev(NxB2::HWC.find('T1'))
  pat = NxB2.arg(NxB2.call('hw_patch', 'code' => 'T1', 'row_rev' => rev,
                                       'from' => 'modal', 'token' => 'tok-p',
                                       'patch' => { 'notes' => 'x' }),
                 'MDH.itemResult')
  NxTest.assert_equal('tok-p', pat[4], 'aj patch z modalu')
end

NxTest.test('KOV-B2: patch z modalu ohlasi vysledok, patch z BUNKY nie') do
  NxB2.taxonomy!(%w[Hettich], [])
  recs = NxB2.catalog!([NxB2.item('104717')])
  rev = NxB2::HWC.record_rev(recs.first)
  from_modal = NxB2.call('hw_patch', 'code' => '104717', 'row_rev' => rev,
                                     'from' => 'modal', 'patch' => { 'notes' => 'z modalu' })
  NxTest.assert(NxB2.arg(from_modal, 'MDH.itemResult'), 'modal dostane odpoved')

  rev2 = NxB2::HWC.record_rev(NxB2::HWC.find('104717'))
  from_cell = NxB2.call('hw_patch', 'code' => '104717', 'row_rev' => rev2,
                                    'patch' => { 'notes' => 'z bunky' })
  NxTest.assert_equal(nil, NxB2.arg(from_cell, 'MDH.itemResult'),
                    'inline bunka ziadny modal neotvara — signal by siel do neexistujuceho okna')
end

NxTest.test('KOV-B2: „+ Vytvoriť" zaklada vyrobcu aj radu a vracia CERSTVU taxonomiu') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([])
  scripts = NxB2.call('hw_tax_create_manufacturer', 'name' => 'blum')
  res = NxB2.arg(scripts, 'MDH.taxonomy')&.first
  NxTest.assert(res, 'server odpoveda signalom taxonomie')
  NxTest.assert_equal(true, res['ok'], 'zapis presiel')
  NxTest.assert_equal('manufacturer', res['op'], 'a povie, coho sa tyka')
  NxTest.assert_equal('blum', res['name'], 'vrati KANONICKE meno zo zaznamu (prve zapisane znenie)')
  NxTest.assert(res['taxonomy']['manufacturers'].include?('blum'),
                'a CERSTVY zoznam, aby modal mohol novu hodnotu vybrat')

  s2 = NxB2.call('hw_tax_create_series', 'name' => 'Legrabox', 'manufacturer' => 'blum')
  r2 = NxB2.arg(s2, 'MDH.taxonomy')&.first
  NxTest.assert_equal(true, r2['ok'], 'rada pod existujucim vyrobcom presla')
  NxTest.assert_equal('series', r2['op'], 'op je rada')
  NxTest.assert(r2['taxonomy']['series'].any? { |s| s['name'] == 'Legrabox' && s['manufacturer'] == 'blum' },
                'rada nesie svojho vyrobcu (zavisly select ju bez toho nezuzi)')
end

NxTest.test('KOV-B2: „+ Vytvoriť radu" bez vyrobcu je STRUKTUROVANA chyba, nie tichy zapis') do
  NxB2.taxonomy!(%w[Hettich], [])
  NxB2.catalog!([])
  res = NxB2.arg(NxB2.call('hw_tax_create_series', 'name' => 'Osirela', 'manufacturer' => ''),
                 'MDH.taxonomy')&.first
  NxTest.assert_equal(false, res['ok'], 'rada bez vyrobcu neexistuje (KOV-B1)')
  NxTest.assert_equal('series', res['errors'].first['field'], 'chyba sadne pri poli rady')
  NxTest.assert(TAX_SERIES_EMPTY = NxB2::TAX.load['series'].empty?, 'a NIC sa neulozilo')
end

NxTest.test('KOV-B2: prazdny nazov vyrobcu je odmietnutie s polom') do
  NxB2.taxonomy!(%w[Hettich], [])
  res = NxB2.arg(NxB2.call('hw_tax_create_manufacturer', 'name' => '   '), 'MDH.taxonomy')&.first
  NxTest.assert_equal(false, res['ok'], 'prazdny nazov neprejde')
  NxTest.assert_equal('manufacturer', res['errors'].first['field'], 'chyba pri poli vyrobcu')
end

# --- 11) whitelist akcii + payload stavu -------------------------------------

NxTest.test('KOV-B2: nove akcie su vo whiteliste sekcie a neznama akcia sa odmietne') do
  acts = NxB2::DLG::SECTION_ACTIONS
  %w[hw_tree hw_tax_create_manufacturer hw_tax_create_series].each do |a|
    NxTest.assert(acts.include?(a), "#{a} je vo whiteliste (HTML ani JS nie su ochrana)")
  end
  NxTest.assert(acts.include?('hw_search'),
                'ploche hladanie ostava — je to verejny kontrakt katalogu')
  out = NxB2.call('hw_vymyslena_akcia')
  NxTest.assert(out.first.to_s.start_with?('MDH.setStatus('),
                'neznama akcia konci hlaskou, nie vykonanim')
end

NxTest.test('KOV-B2: state_payload nesie SK popisky a taxonomiu') do
  NxB2.taxonomy!(%w[Hettich Blum], [['Sensys', 'Hettich']])
  NxB2.catalog!([NxB2.item('A1')])
  p = NxB2::DLG.state_payload
  NxTest.assert_equal(NxB2::HWC::CATEGORY_LABELS, p['category_labels'],
                      'popisky maju JEDINY zdroj a chodia klientovi hotove')
  NxTest.assert_equal(%w[Blum Hettich], p['taxonomy']['manufacturers'].sort,
                      'vyrobcovia pre select modalu')
  NxTest.assert_equal([{ 'name' => 'Sensys', 'manufacturer' => 'Hettich' }],
                      p['taxonomy']['series'], 'rady nesu svojho vyrobcu')
  NxTest.assert_equal(false, p['taxonomy']['read_only'], 'stav taxonomie chodi tiez')
  # Review #290/3 P2: `read_only` a `write_blocked` su DVA rozne stavy —
  # degradovana taxonomia sa CITA, ale zapisat sa do nej neda.
  NxTest.assert_equal(false, p['taxonomy']['write_blocked'],
                      'nad zdravou taxonomiou sa zapisat DA')
  NxTest.assert(p['taxonomy'].key?('write_blocked'),
                'priznak chodi vzdy — modal podla neho skryva „+ Vytvoriť"')
end

NxTest.test('KOV-B2: fail-closed payload taxonomie hlasi read_only AJ write_blocked') do
  NxB2.catalog!([])
  # Nekompatibilna taxonomia: `load` nic nevyda, zapisat sa neda.
  NxB2.taxonomy_read_only!
  p = NxB2::DLG.state_payload
  NxTest.assert_equal(true, p['taxonomy']['read_only'], 'cudzi/novsi subor = read-only')
  NxTest.assert_equal(true, p['taxonomy']['write_blocked'], 'a zapis je zablokovany')
  NxTest.assert_equal([], p['taxonomy']['manufacturers'], 'zoznam je prazdny')
end
