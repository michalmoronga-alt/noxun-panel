# frozen_string_literal: true
# Testy V0.6 M-A1: nazvove hladanie v sitemap cache (DemosNameSearch), obrazok
# dekoru (parser itemprop=image + sanitize_image_url + DemosImageCache),
# rodina dekoru z produktovej stranky (DemosFamily.load_family/klasifikacia),
# atomicke zalozenie skupiny (create -> Materials.create_group_from_demos,
# SCHEMA 6) a watchdog fix prveho sitemap refreshu (audit F6).
require_relative '../helper' unless defined?(NxTest)

DMA = Noxun::Engine::Demos
DNS_MA = Noxun::Engine::DemosNameSearch
DIC = Noxun::Engine::DemosImageCache
DFA = Noxun::Engine::DemosFamily
DPP_MA = Noxun::Engine::DemosProductParser
MAT_MA = Noxun::Engine::Materials

def ma1_fixture(name)
  File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'demos', name), encoding: 'UTF-8')
end

MA1_PD_URL = 'https://www.demos-trade.sk/pracovna-doska-h3303-st10-dub-hamilton-prirodny-4100-600-38/'
MA1_DTDL18_URL = 'https://www.demos-trade.sk/dtdl-h3303-st10-dub-hamilton-prirodny-2800-2070-18/'
MA1_ABS_URL = 'https://www.demos-trade.sk/absb-h3303-st10-dub-hamilton-prirodny-23-1/'
MA1_IMG_URL = 'https://www.demos-trade.sk/content/images/product/default/244894.jpeg'

# Synteticka ABS stranka (fixture ABS neexistuje) — presne bloky, ktore parser
# cita: kod, h1, brand, cenovy blok za meter, tabulka parametrov, obrazok.
def ma1_abs_html(code: '311501', brand: 'Egger', decor: 'H3303', width: '23', th: '1')
  <<~HTML
    <html><body>
    <h1>ABS #{decor} ST10 Dub Hamilton prírodný #{width}x#{th}</h1>
    <span>Kód sortimentu</span> <strong>#{code}</strong>
    <span itemprop="brand">#{brand}</span>
    <dl><dt>Základná cena za m</dt><dd>0,43 EUR<br>0,52 EUR s DPH</dd></dl>
    <img itemprop="image" src="https://www.demos-trade.sk/content/images/product/default/311501.jpg">
    <table>
      <tr><td>Číslo dekoru</td><td>#{decor}</td></tr>
      <tr><td>Názov dekoru</td><td>Dub Hamilton prírodný</td></tr>
      <tr><td>Štruktúra materiálu</td><td>ST10</td></tr>
      <tr><td>Šírka materiálu (mm)</td><td>#{width}</td></tr>
      <tr><td>Hrúbka materiálu (mm)</td><td>#{th}</td></tr>
    </table>
    </body></html>
  HTML
end

# JPEG telo s platnym magic headerom (image cache validuje obsah).
def ma1_jpeg_body
  String.new("\xFF\xD8\xFF\xE0fakejpegdata", encoding: Encoding::BINARY)
end

def ma1_with_transport(map)
  fake = Db1Transport.new(map)
  DMA.transport = fake
  yield fake
ensure
  DMA.transport = nil
end

# Family create beh: header/items ako by ich drzal dialog store.
def ma1_run_create(header, items, iids, map, alive_box = { 'alive' => true })
  events = []
  ma1_with_transport(map) do |fake|
    DFA.create(header, items, iids,
               alive: -> { alive_box['alive'] },
               emit: ->(e) { events << e })
    [events, fake]
  end
end

def ma1_header
  { 'manufacturer' => 'Egger', 'decor' => 'H3303',
    'decor_name' => 'Dub Hamilton prírodný', 'structure' => 'ST10',
    'title' => 'x', 'url' => MA1_PD_URL, 'image_url' => MA1_IMG_URL }
end

def ma1_sheet_item(over = {})
  { 'iid' => 'i0', 'kind' => 'sheet', 'type' => 'DTDL',
    'name' => 'DTDL H3303 18', 'code' => '175718', 'url' => MA1_DTDL18_URL,
    'reason' => nil }.merge(over)
end

def ma1_edge_item(over = {})
  { 'iid' => 'i1', 'kind' => 'edge', 'name' => 'ABS H3303 23x1',
    'code' => '311501', 'url' => MA1_ABS_URL, 'reason' => nil }.merge(over)
end

def ma1_complete(events)
  events.find { |e| e['type'] == 'complete' }
end

# --- DemosNameSearch ---------------------------------------------------------

NxTest.test('ma1 name search: diakritika/case dotazu, vsetky tokeny musia sediet') do
  urls = [MA1_DTDL18_URL, MA1_PD_URL, MA1_ABS_URL,
          'https://www.demos-trade.sk/dtdl-u750-st9-taupe-seda-2800-2070-18/']
  hits = DNS_MA.search(urls, 'Dub Hamiltón prírodný')
  NxTest.assert_equal(3, hits.length, hits.inspect)
  NxTest.assert_equal(%w[ABS DTDL PD].sort, hits.map { |h| h['type'] }.sort)
  NxTest.assert_equal([], DNS_MA.search(urls, 'dub hamilton cierny'),
                      'token bez zhody = ziadny vysledok')
end

NxTest.test('ma1 name search: min 3 znaky, top limit, deterministicke poradie') do
  urls = [MA1_PD_URL, MA1_DTDL18_URL, MA1_ABS_URL]
  NxTest.assert_equal([], DNS_MA.search(urls, 'du'), 'pod 3 znaky sa nehlada')
  NxTest.assert_equal(1, DNS_MA.search(urls, 'hamilton', top: 1).length)
  two = DNS_MA.search(urls, 'hamilton')
  NxTest.assert_equal(DNS_MA.search(urls, 'hamilton').map { |h| h['url'] },
                      two.map { |h| h['url'] }, 'rovnaky dotaz = rovnake poradie')
end

NxTest.test('ma1 name search: neznamy prefix sa nehlada, absb je ABS, label bez prefixu') do
  urls = ['https://www.demos-trade.sk/lista-prechodova-h3303/',
          MA1_ABS_URL]
  hits = DNS_MA.search(urls, 'h3303')
  NxTest.assert_equal(1, hits.length, 'lista (neznamy prefix) sa nehlada')
  NxTest.assert_equal('ABS', hits[0]['type'])
  # D-74: label je citatelny — dekor VELKYM, rozmery ABS "23/1".
  NxTest.assert(hits[0]['label'].start_with?('H3303'), hits[0]['label'])
  NxTest.assert(hits[0]['label'].include?('23/1'), "ABS rozmery formatovane: #{hits[0]['label']}")
end

NxTest.test('ma1 name search D-65: alias prefixy najditelne, clanky bez cislic von, label bez aliasu') do
  urls = ['https://www.demos-trade.sk/dtd-laminovana-k003-pw-gold-craft-oak-2800-2070-25/',
          'https://www.demos-trade.sk/mdfl-101-sm-front-white-2800-2070-8/',
          'https://www.demos-trade.sk/kd-in-w980-st7-platinovo-biela-cj-cgs-2790-2060-12/',
          'https://www.demos-trade.sk/absl-76955-14-mamba-green-7190-bs-22-0-4/',
          'https://www.demos-trade.sk/pracovna-doska-v-hlbokom-mate/',
          'https://www.demos-trade.sk/kompaktne-dosky-prehlad-skladovej-kolekcie/']
  dtd = DNS_MA.search(urls, 'gold craft')
  NxTest.assert_equal(1, dtd.length, dtd.inspect)
  NxTest.assert_equal('DTDL', dtd[0]['type'])
  NxTest.assert(dtd[0]['label'].start_with?('K003'), "alias prefix odstrihnuty: #{dtd[0]['label']}")
  NxTest.assert_equal('MDF', DNS_MA.search(urls, 'front white')[0]['type'])
  NxTest.assert_equal('KOMPAKT', DNS_MA.search(urls, 'platinovo')[0]['type'])
  NxTest.assert_equal('ABS', DNS_MA.search(urls, 'mamba')[0]['type'])
  NxTest.assert_equal([], DNS_MA.search(urls, 'hlbokom mate'),
                      'clanok bez cislic sa neindexuje (digit guard)')
  NxTest.assert_equal([], DNS_MA.search(urls, 'prehlad skladovej'),
                      'kategoria sa neindexuje')
end

NxTest.test('ma1/D-74: citatelne labely — dekor VELKYM, nazov s velkym zaciatkom, rozmery per typ') do
  urls = ['https://www.demos-trade.sk/dtdl-f206-st9-pietra-grigia-cierna-2800-2070-8/',
          'https://www.demos-trade.sk/zastena-f206-pm-protitah-sm-4100-640-9-2/',
          'https://www.demos-trade.sk/kd-in-f206-st9-pietra-grigia-cierna-cj-cgs-4100-650-12/',
          'https://www.demos-trade.sk/absb-f206-st9-pietra-grigia-cierna-23-0-8-2/',
          'https://www.demos-trade.sk/absb-f206-st9-pietra-grigia-cierna-stara-23-2/']
  labels = DNS_MA.search(urls, 'f206').map { |h| h['label'] }
  NxTest.assert(labels.include?('F206 ST9 Pietra Grigia Cierna · 2800×2070 · 8 mm'), labels.inspect)
  NxTest.assert(labels.include?('F206 PM Protitah SM · 4100×640 · 9,2 mm'), labels.inspect)
  NxTest.assert(labels.include?('F206 ST9 Pietra Grigia Cierna CJ Cgs · 4100×650 · 12 mm'), labels.inspect)
  NxTest.assert(labels.include?('F206 ST9 Pietra Grigia Cierna · 23/0,8'), labels.inspect)
  NxTest.assert(labels.include?('F206 ST9 Pietra Grigia Cierna Stara · 23/2'), labels.inspect)
end

NxTest.test('d74c: edge_dims_from_slug — dedup sufixy (Michalov smoke F206: sirka uz nie je 2.0/8.0)') do
  sm = Noxun::Engine::DemosSlugMatcher
  # F206 realne slugy so sufixom -2 (516784/516785/516786...)
  NxTest.assert_equal([43.0, 2.0], sm.edge_dims_from_slug('absb-f206-st9-pietra-grigia-cierna-43-2-2'))
  NxTest.assert_equal([23.0, 0.8], sm.edge_dims_from_slug('absb-f206-st9-pietra-grigia-cierna-23-0-8-2'))
  NxTest.assert_equal([23.0, 2.0], sm.edge_dims_from_slug('absb-f206-st9-pietra-grigia-cierna-23-2-2'))
  NxTest.assert_equal([100.0, 0.8], sm.edge_dims_from_slug('absb-jumbo-f206-st9-pietra-grigia-cierna-100-0-8'))
  NxTest.assert_equal([43.0, 1.5], sm.edge_dims_from_slug('absb-f206-st9-pietra-grigia-cierna-43-1-5-2'))
  # bez sufixu presne ako doteraz
  NxTest.assert_equal([23.0, 1.0], sm.edge_dims_from_slug('absb-5981-23-1'))
  NxTest.assert_equal([43.0, 1.5], sm.edge_dims_from_slug('absb-h1180-43-1-5'))
  # GH #124 P1: …-23-1-2 je AMBIVALENTNE (realna 1,2 vs 23/1 dedup) — bez
  # prefer vyhrava DESATINNY vyklad (1,2 je podporovana a v sortimente);
  # prefer (hrubka zo stranky/zaznamu) rozhodne s istotou oboma smermi.
  NxTest.assert_equal([23.0, 1.2], sm.edge_dims_from_slug('absb-h1180-23-1-2'))
  NxTest.assert_equal([23.0, 1.0], sm.edge_dims_scan('absb-h1180-23-1-2', prefer_thickness: 1.0)[0, 2])
  NxTest.assert_equal([23.0, 1.2], sm.edge_dims_scan('absb-h1180-23-1-2', prefer_thickness: 1.2)[0, 2])
  NxTest.assert_equal([43.0, 2.0], sm.edge_dims_scan('absb-x-43-2-2', prefer_thickness: 2.0)[0, 2])
  # token_count zrkadlo — dekor tesne pred sufixovymi rozmermi prezije
  NxTest.assert_equal(4, sm.edge_dims_token_count('absb-x-23-0-8-2'))
  NxTest.assert(DFA.edge_slug_decor?('absb-5981-23-0-8-2', '5981'),
                'ciselny dekor pred sufixovymi rozmerami sa neodsekne')
end

NxTest.test('ma1/D-74 (GH #121 P2): dedup sufixy a ciselne dekory v labeloch') do
  urls = ['https://www.demos-trade.sk/zastena-h1180-st37-w908-st37-4100-640-9-2-2/',
          'https://www.demos-trade.sk/absb-h1180-st37-dub-halifax-23-1-2/',
          'https://www.demos-trade.sk/absb-5981-mg-cashmere-23-1/',
          'https://www.demos-trade.sk/dtdl-5981-mg-cashmere-2800-2050-18/']
  labels = DNS_MA.search(urls, 'h1180') + DNS_MA.search(urls, '5981')
  labels = labels.map { |h| h['label'] }
  NxTest.assert(labels.include?('H1180 ST37 W908 ST37 · 4100×640 · 9,2 mm'),
                "doskovy dedup sufix (9-2-2) nesmie dat 640×9 · 2,2: #{labels.inspect}")
  # GH #124 P1 (revizia #121 P2): bez prefer vyhrava desatinny vyklad —
  # 1,2 je realna podporovana paska; label nasleduje zapisovu autoritu.
  NxTest.assert(labels.include?('H1180 ST37 Dub Halifax · 23/1,2'),
                "ABS -23-1-2 bez prefer = 23/1,2 (dec priorita): #{labels.inspect}")
  NxTest.assert(labels.include?('5981 MG Cashmere · 23/1'),
                "ciselny dekor pasky musi v labeli ostat: #{labels.inspect}")
  NxTest.assert(labels.include?('5981 MG Cashmere · 2800×2050 · 18 mm'),
                "ciselny dekor dosky musi v labeli ostat: #{labels.inspect}")
end

NxTest.test('ma1 name search: cache index sa memoizuje podla fetched_at') do
  DNS_MA.index_reset!
  Noxun::Engine::JsonFileStore.write(Noxun::Engine::DemosSitemapCache.path,
                                     'fetched_at' => 111.0, 'urls' => [MA1_DTDL18_URL])
  NxTest.assert_equal(1, DNS_MA.search_cached('hamilton').length)
  # novy fetched_at = novy index (stary sa nesmie pouzit)
  Noxun::Engine::JsonFileStore.write(Noxun::Engine::DemosSitemapCache.path,
                                     'fetched_at' => 222.0, 'urls' => [MA1_PD_URL, MA1_ABS_URL])
  types = DNS_MA.search_cached('hamilton').map { |h| h['type'] }.sort
  NxTest.assert_equal(%w[ABS PD], types, 'index sa prestavia po refreshi cache')
ensure
  p = Noxun::Engine::DemosSitemapCache.path
  File.delete(p) if File.exist?(p)
  Noxun::Engine::JsonFileStore.invalidate(p)
  DNS_MA.index_reset!
end

# --- obrazok: sanitize + parser + cache --------------------------------------

NxTest.test('ma1 image: sanitize_image_url — https, host, cesta, pripona, query prec') do
  ok = DMA.sanitize_image_url("#{MA1_IMG_URL}?w=200")
  NxTest.assert_equal(MA1_IMG_URL, ok, 'query sa zahadzuje')
  NxTest.assert_equal(nil, DMA.sanitize_image_url('http://www.demos-trade.sk/content/images/product/default/1.jpg'))
  NxTest.assert_equal(nil, DMA.sanitize_image_url('https://evil.sk/content/images/product/default/1.jpg'))
  NxTest.assert_equal(nil, DMA.sanitize_image_url('https://www.demos-trade.sk/obrazky/1.jpg'), 'ina cesta nie')
  NxTest.assert_equal(nil, DMA.sanitize_image_url('https://www.demos-trade.sk/content/images/product/default/x.svg'), 'ina pripona nie')
  NxTest.assert_equal(nil, DMA.sanitize_image_url(''))
end

NxTest.test('ma1 image: parser vytiahne itemprop=image z oboch fixtures') do
  d = DPP_MA.parse(ma1_fixture('h3303_dtdl18_product.html'))
  NxTest.assert_equal(MA1_IMG_URL, d['image_url'])
  p = DPP_MA.parse(ma1_fixture('h3303_pd_product.html'))
  NxTest.assert_equal('https://www.demos-trade.sk/content/images/product/default/231680.jpg',
                      p['image_url'])
end

NxTest.test('ma1 image cache: store validuje magic bytes, ensure nefetchuje existujuci subor') do
  path = DIC.path_for(MA1_IMG_URL)
  NxTest.assert(path && path.include?('textures'), path.inspect)
  NxTest.assert_equal(nil, DIC.path_for('https://evil.sk/x.jpg'), 'zla URL nema cestu')
  FileUtils.rm_f(path)
  NxTest.assert_equal(nil, DIC.store(path, '<html>chyba</html>'), 'HTML telo sa neulozi')
  NxTest.refute(File.exist?(path))
  got = nil
  ma1_with_transport(MA1_IMG_URL => [200, {}, ma1_jpeg_body]) do |fake|
    DIC.ensure(MA1_IMG_URL) { |local| got = local }
    NxTest.assert_equal(path, got, 'stiahnuty a ulozeny')
    NxTest.assert(File.exist?(path))
    # druhy ensure ide z disku — ziadny dalsi fetch
    DIC.ensure(MA1_IMG_URL) { |local| got = local }
    NxTest.assert_equal(path, got)
    NxTest.assert_equal(1, fake.calls.length, 'existujuci subor sa nefetchuje')
  end
ensure
  FileUtils.rm_f(DIC.path_for(MA1_IMG_URL).to_s)
end

# --- klasifikacia poloziek rodiny ---------------------------------------------

NxTest.test('ma1 family: klasifikacia slugov — sheet typy, ABS rozmery, vzorka, lista, zastena') do
  c = DFA.classify_item('x', '1', MA1_DTDL18_URL, 'ks', 10.0)
  NxTest.assert_equal(%w[sheet DTDL], [c['kind'], c['type']])
  NxTest.assert_close(18.0, c['thickness_hint'], 0.01)
  pd = DFA.classify_item('x', '2', MA1_PD_URL, 'ks', 10.0)
  NxTest.assert_equal(%w[sheet PD], [pd['kind'], pd['type']])
  abs = DFA.classify_item('x', '3', MA1_ABS_URL, 'm', 1.0)
  NxTest.assert_equal('edge', abs['kind'])
  NxTest.assert_close(23.0, abs['width_hint'], 0.01)
  NxTest.assert_close(1.0, abs['thickness_hint'], 0.01)
  abs15 = DFA.classify_item('x', '4', 'https://www.demos-trade.sk/absb-h3303-st10-x-43-1-5/', 'm', 1.0)
  NxTest.assert_close(43.0, abs15['width_hint'], 0.01, 'desatinna hrubka: sirka je token pred')
  NxTest.assert_close(1.5, abs15['thickness_hint'], 0.01)
  vz = DFA.classify_item('x', '5', 'https://www.demos-trade.sk/kompakt-h3303-vzorka-a5/', 'ks', 1.0)
  NxTest.assert_equal('other', vz['kind'])
  NxTest.assert(vz['reason'].include?('vzorka'), vz['reason'])
  li = DFA.classify_item('x', '6', 'https://www.demos-trade.sk/lista-prechodova-h3303/', 'ks', 1.0)
  NxTest.assert_equal('other', li['kind'])
  NxTest.assert_equal('mimo podporovaných typov materiálu', li['reason'], 'D-65: uz nie "(prislusenstvo)"')
  # D-66: zastena uz NIE JE "zaloz rucne" — je doskovy kandidat (rub cita
  # verify_sheet z parametrov stranky pri fetchi variantu).
  za = DFA.classify_item('x', '7', 'https://www.demos-trade.sk/zastena-h3303-st10-f620-4100-640-9-2/', 'ks', 1.0)
  NxTest.assert_equal(%w[sheet ZASTENA], [za['kind'], za['type']], za.inspect)
  NxTest.assert_equal(nil, za['reason'])
  NxTest.assert_close(9.2, za['thickness_hint'], 0.01)
  # D-74b: rodina nesie formatovany label (jednotna autorita name_search).
  NxTest.assert_equal('H3303 ST10 F620 · 4100×640 · 9,2 mm', za['label'], za.inspect)
  kd = DFA.classify_item('x', '8', 'https://www.demos-trade.sk/kd-in-f206-st9-pietra-grigia-cierna-cj-cgs-4100-650-12/', 'ks', 1.0)
  NxTest.assert_equal('F206 ST9 Pietra Grigia Cierna CJ Cgs · 4100×650 · 12 mm', kd['label'], kd.inspect)
  ab = DFA.classify_item('x', '9', 'https://www.demos-trade.sk/absb-f206-st9-pietra-grigia-cierna-23-0-8-2/', 'm', 1.0)
  NxTest.assert_equal('edge', ab['kind'])
  NxTest.assert_equal('F206 ST9 Pietra Grigia Cierna · 23/0,8', ab['label'], ab.inspect)
end

NxTest.test('ma1 family: klasifikacia D-65 — alias prefixy dtd-laminovana/mdfl/kd-in/absl') do
  dtd = DFA.classify_item('x', '1', 'https://www.demos-trade.sk/dtd-laminovana-k003-pw-gold-craft-oak-2800-2070-25/', 'ks', 10.0)
  NxTest.assert_equal(%w[sheet DTDL], [dtd['kind'], dtd['type']], dtd.inspect)
  NxTest.assert_close(25.0, dtd['thickness_hint'], 0.01)
  ml = DFA.classify_item('x', '2', 'https://www.demos-trade.sk/mdfl-101-sm-front-white-2800-2070-8/', 'ks', 10.0)
  NxTest.assert_equal(%w[sheet MDF], [ml['kind'], ml['type']])
  kd = DFA.classify_item('x', '3', 'https://www.demos-trade.sk/kd-in-w980-st7-platinovo-biela-cj-cgs-2790-2060-12/', 'ks', 10.0)
  NxTest.assert_equal(%w[sheet KOMPAKT], [kd['kind'], kd['type']])
  al = DFA.classify_item('x', '4', 'https://www.demos-trade.sk/absl-76955-14-mamba-green-7190-bs-22-0-4/', 'm', 1.0)
  NxTest.assert_equal('edge', al['kind'])
  NxTest.assert_close(22.0, al['width_hint'], 0.01)
  NxTest.assert_close(0.4, al['thickness_hint'], 0.01)
  md = DFA.classify_item('x', '5', 'https://www.demos-trade.sk/mdfd-dub-comfort-a-b-2520-1810-19/', 'ks', 10.0)
  NxTest.assert_equal('other', md['kind'], 'dyhovana MDF vedome mimo')
end

NxTest.test('ma1 family: load_family — hlavicka + polozky z PD fixture, complete raz') do
  events = []
  ma1_with_transport(MA1_PD_URL => [200, {}, ma1_fixture('h3303_pd_product.html')]) do
    DFA.load_family(MA1_PD_URL, alive: -> { true }, emit: ->(e) { events << e })
  end
  fam = events.find { |e| e['type'] == 'family' }
  NxTest.assert(fam, events.map { |e| e['type'] }.inspect)
  h = fam['header']
  NxTest.assert_equal(%w[Egger H3303 ST10], [h['manufacturer'], h['decor'], h['structure']])
  NxTest.assert(h['image_url'].include?('231680'), 'obrazok hlavicky zo stranky')
  items = fam['items']
  NxTest.assert_equal('sheet', items[0]['kind'], 'hlavny produkt je prva polozka')
  NxTest.assert_equal('PD', items[0]['type'])
  NxTest.assert(items.all? { |it| !it['iid'].to_s.empty? && !it['code'].to_s.empty? })
  NxTest.assert(items.any? { |it| it['kind'] == 'edge' }, 'ABS 43x2 z relateds')
  dtdl = items.select { |it| it['type'] == 'DTDL' }
  NxTest.assert(dtdl.length >= 2, 'related DTDL 10 aj 18')
  codes = items.map { |it| it['code'] }
  NxTest.assert_equal(codes.uniq.length, codes.length, 'dedup kodov')
  done = ma1_complete(events)
  NxTest.assert(done && done['ok'] == true)
end

NxTest.test('ma1 family: load_family — stranka bez dekoru/vyrobcu = chyba, fetch fail = chyba') do
  events = []
  ma1_with_transport(MA1_PD_URL => [200, {}, '<html><h1>x</h1></html>']) do
    DFA.load_family(MA1_PD_URL, alive: -> { true }, emit: ->(e) { events << e })
  end
  done = ma1_complete(events)
  NxTest.assert_equal(false, done['ok'])
  events2 = []
  ma1_with_transport(MA1_PD_URL => :err) do
    DFA.load_family(MA1_PD_URL, alive: -> { true }, emit: ->(e) { events2 << e })
  end
  NxTest.assert_equal(false, ma1_complete(events2)['ok'])
end

# --- create: overenie poloziek + atomicky zapis --------------------------------

NxTest.test('ma1 create: happy path — skupina s kodmi, cenami, URL, obrazkom, SCHEMA 6') do
  NxTest.install_fresh_seed_catalog!
  img = 'https://www.demos-trade.sk/content/images/product/default/244894.jpeg'
  FileUtils.rm_f(DIC.path_for(img).to_s)
  map = {
    MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')],
    MA1_ABS_URL => [200, {}, ma1_abs_html],
    img => [200, {}, ma1_jpeg_body]
  }
  events, fake = ma1_run_create(ma1_header, [ma1_sheet_item, ma1_edge_item], %w[i0 i1], map)
  done = ma1_complete(events)
  NxTest.assert(done && done['ok'] == true, events.inspect)
  res = done['result']
  NxTest.assert_equal(1, res['sheets'].length)
  NxTest.assert_equal(1, res['edges'].length)
  NxTest.assert_equal(true, res['image'], 'obrazok stiahnuty do cache')
  NxTest.assert_equal(3, fake.calls.length, '2 polozky + 1 obrazok')
  NxTest.assert_equal(2, events.count { |e| e['type'] == 'progress' })
  s = MAT_MA.sheet(res['sheets'][0])
  NxTest.assert_equal(%w[Egger H3303 ST10 DTDL], [s['manufacturer'], s['decor'], s['structure'], s['type']])
  NxTest.assert_close(18.0, s['thickness'], 0.01)
  NxTest.assert_equal('175718', s['code'])
  NxTest.assert_equal('Demos', s['supplier'])
  NxTest.assert_close(18.9924, s['price_per_m2'], 0.001, 'ks -> m2 cez format stranky')
  NxTest.assert_equal(MA1_DTDL18_URL, s['demos_url'])
  NxTest.assert(s['price_checked_at'].to_s.length > 5, 'datum overenia pri cene')
  NxTest.assert_equal(img, s['image_url'])
  NxTest.assert_equal(MAT_MA.group_id_for('Egger', 'H3303'), s['group_id'])
  e = MAT_MA.edge(res['edges'][0])
  NxTest.assert_close(23.0, e['width'], 0.01)
  NxTest.assert_close(1.0, e['thickness'], 0.01)
  NxTest.assert_equal('311501', e['code'])
  NxTest.assert_close(0.52, e['price_per_bm'], 0.001, 'cena s DPH za meter')
  NxTest.assert_equal(s['group_id'], e['group_id'], 'paska v tej istej skupine')
  raw = JSON.parse(File.read(MAT_MA.path))
  # M-B1: seed je UNI (marker 7 od zaciatku) — image_url by sam dvihol na 6,
  # marker drzi vyssiu zo schem (downgrade zakazany).
  NxTest.assert(raw['schema'] >= 6, "image_url vyzaduje aspon 6, marker je #{raw['schema']}")
  NxTest.assert(File.exist?(DIC.path_for(img)), 'obrazok v textures cache')
ensure
  FileUtils.rm_f(DIC.path_for('https://www.demos-trade.sk/content/images/product/default/244894.jpeg').to_s)
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 create: iny vyrobca DOSKY = fail CELEJ davky, katalog nezmeneny (D-64: len dosky)') do
  NxTest.install_fresh_seed_catalog!
  before = File.read(MAT_MA.path)
  map = {
    MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')],
    MA1_ABS_URL => [200, {}, ma1_abs_html]
  }
  header = ma1_header.merge('manufacturer' => 'Kronospan')
  events, = ma1_run_create(header, [ma1_sheet_item, ma1_edge_item], %w[i0 i1], map)
  done = ma1_complete(events)
  NxTest.assert_equal(false, done['ok'])
  NxTest.assert_equal(1, done['failed'].length, 'vinnik menovany (paska cez slug dekoru presla)')
  NxTest.assert_equal('i0', done['failed'][0]['iid'])
  NxTest.assert(done['failed'][0]['reason'].include?('výrobca'), done['failed'][0]['reason'])
  NxTest.assert_equal(before, File.read(MAT_MA.path), 'all-or-nothing: ziadny zapis')
end

NxTest.test('ma1 create D-64+D-58: paska tretej strany (cudzi brand aj params-decor) prejde slugom, dedi strukturu rodiny') do
  NxTest.install_fresh_seed_catalog!
  # Realny vzor Rehau: brand=Rehau, "Cislo dekoru"=79098/LPE05 (vlastne cislo
  # vyrobcu pasky), struktura POVRCHU na stranke nie je — dekor rodiny nesie
  # len slug URL. Tabulkove rozmery zamerne ziadne (realne stranky pasok maju
  # ine nazvy poli — parser ich necita).
  rehau = <<~HTML
    <html><body>
    <h1>ABSB 79098/OHNE/LPE05 Dub Hamilton 23/1</h1>
    <span>Kód sortimentu</span> <strong>356427</strong>
    <span itemprop="brand">Rehau</span>
    <dl><dt>Základná cena za m</dt><dd>0,43 EUR<br>0,52 EUR s DPH</dd></dl>
    <table>
      <tr><td>Číslo dekoru</td><td>79098/LPE05</td></tr>
    </table>
    </body></html>
  HTML
  map = { MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')],
          MA1_ABS_URL => [200, {}, rehau] }
  events, = ma1_run_create(ma1_header, [ma1_sheet_item, ma1_edge_item], %w[i0 i1], map)
  done = ma1_complete(events)
  NxTest.assert_equal(true, done['ok'], events.inspect)
  e = MAT_MA.edge(done['result']['edges'][0])
  NxTest.assert_close(23.0, e['width'], 0.01, 'sirka zo slugu (autorita)')
  NxTest.assert_close(1.0, e['thickness'], 0.01)
  NxTest.assert_equal('ST10', e['structure'], 'D-58: struktura zdedena z hlavicky rodiny')
  NxTest.assert_equal('356427', e['code'])
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 create D-64: paska bez dekoru rodiny v adrese aj parametroch = fail; dekor sa nehlada v rozmeroch') do
  NxTest.install_fresh_seed_catalog!
  before = File.read(MAT_MA.path)
  cudzia = 'https://www.demos-trade.sk/absb-79098-ohne-lpe05-iny-vzor-23-1/'
  map = { cudzia => [200, {}, ma1_abs_html(decor: '79098/LPE05')] }
  events, = ma1_run_create(ma1_header, [ma1_edge_item('url' => cudzia)], %w[i1], map)
  done = ma1_complete(events)
  NxTest.assert_equal(false, done['ok'])
  NxTest.assert(done['failed'][0]['reason'].include?('nenesie číslo dekoru'), done['failed'][0]['reason'])
  NxTest.assert_equal(before, File.read(MAT_MA.path))
  # kolizia dekoru s rozmermi: dekor rodiny '23' NESMIE matchnut sirku 23 v konci slugu
  NxTest.refute(DFA.edge_slug_decor?('absb-79098-ohne-iny-vzor-23-1', '23'),
                'koncove rozmery sa do dokazu dekoru neratatju')
  NxTest.assert(DFA.edge_slug_decor?('absb-23-nieco-42-2', '23'), 'dekor v tele slugu plati')
  NxTest.assert(DFA.edge_slug_decor?('absb-79098-ohne-lpe05-cashmere-5981-bs-5981-pd-23-0-8', '5981'),
                'realny Rehau slug s dekorom 5981 v tele')
  # GH #106 P2: ciselny dekor TESNE pred rozmermi — odsekavaju sa LEN tokeny
  # realne parsovane ako sirka×hrubka (2 cele / 3 desatinna), nie vsetky cisla.
  NxTest.assert(DFA.edge_slug_decor?('absb-5981-23-1', '5981'),
                'dekor hned pred sirka-hrubka prezije (cele)')
  NxTest.assert(DFA.edge_slug_decor?('absb-5981-23-0-8', '5981'),
                'dekor hned pred sirka-desatinna-hrubka prezije')
  NxTest.refute(DFA.edge_slug_decor?('absb-5981-23-1', '23'),
                'sirka sa ani tak nestane dekorom')
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 create: fetch chyba polozky = ziadny zapis; cancel medzi fetchmi = ticho bez zapisu') do
  NxTest.install_fresh_seed_catalog!
  before = File.read(MAT_MA.path)
  map = { MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')],
          MA1_ABS_URL => :err }
  events, = ma1_run_create(ma1_header, [ma1_sheet_item, ma1_edge_item], %w[i0 i1], map)
  NxTest.assert_equal(false, ma1_complete(events)['ok'])
  NxTest.assert_equal(before, File.read(MAT_MA.path))
  # cancel: alive zhasne po prvom progresse — retaz konci, complete nepride
  box = { 'alive' => true }
  events2 = []
  ma1_with_transport(map) do
    DFA.create(ma1_header, [ma1_sheet_item, ma1_edge_item], %w[i0 i1],
               alive: -> { box['alive'] },
               emit: ->(e) {
                 events2 << e
                 box['alive'] = false if e['type'] == 'progress'
               })
  end
  NxTest.assert_equal(nil, ma1_complete(events2), 'mrtvy volajuci nedostane complete')
  NxTest.assert_equal(before, File.read(MAT_MA.path), 'cancel = ziadny zapis')
end

NxTest.test('ma1 create: nevybrata/other polozka a prazdny vyber su chyby pred fetchom') do
  events, fake = ma1_run_create(ma1_header, [ma1_sheet_item], [], {})
  NxTest.assert_equal(false, ma1_complete(events)['ok'])
  NxTest.assert_equal(0, fake.calls.length)
  other = ma1_sheet_item('kind' => 'other', 'reason' => 'vzorka')
  events2, fake2 = ma1_run_create(ma1_header, [other], %w[i0], {})
  NxTest.assert_equal(false, ma1_complete(events2)['ok'])
  NxTest.assert(ma1_complete(events2)['error'].include?('vzorka'))
  NxTest.assert_equal(0, fake2.calls.length)
end

NxTest.test('ma1 create: existujuci variant = skipped (ziadne prepisanie), druha polozka sa zalozi') do
  NxTest.install_fresh_seed_catalog!
  map = {
    MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')],
    MA1_ABS_URL => [200, {}, ma1_abs_html]
  }
  events, = ma1_run_create(ma1_header, [ma1_sheet_item], %w[i0], map)
  NxTest.assert(ma1_complete(events)['ok'] == true)
  # druhy beh: doska uz existuje (skip), paska pribudne
  events2, = ma1_run_create(ma1_header, [ma1_sheet_item, ma1_edge_item], %w[i0 i1], map)
  done2 = ma1_complete(events2)
  NxTest.assert_equal(true, done2['ok'], events2.inspect)
  NxTest.assert_equal(0, done2['result']['sheets'].length)
  NxTest.assert_equal(1, done2['result']['edges'].length)
  NxTest.assert_equal(1, done2['result']['skipped'].length)
ensure
  NxTest.install_fresh_seed_catalog!
end

# --- M-A3b: demos_code_known? (D-59) + demos_open_target (D-60) ----------------

NxTest.test('ma3b: demos_code_known? — kind+kod+dodavatel; demos_open_target — sanitize pred otvorenim') do
  NxTest.install_fresh_seed_catalog!
  st, info = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H9999', 'decor_name' => 'Testovací',
    'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST9',
                        'sheet_size' => [2800.0, 2070.0], 'code' => '111222', 'price' => 10.0,
                        'demos_url' => 'https://www.demos-trade.sk/dtdl-h9999-st9-x-2800-2070-18/',
                        'image_url' => nil }],
    'edge_items' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9',
                       'code' => '333444', 'price' => 0.5, 'demos_url' => nil }]
  )
  NxTest.assert_equal(:ok, st, info.inspect)
  sid = info['sheets'][0]
  # D-59: match je kind+kod (ci, trim) + dodavatel Demos/prazdny
  NxTest.assert_equal(true, MAT_MA.demos_code_known?('sheet', '111222'))
  NxTest.assert_equal(true, MAT_MA.demos_code_known?('sheet', '  111222  '), 'trim')
  NxTest.assert_equal(false, MAT_MA.demos_code_known?('edge', '111222'), 'kod dosky nematchuje pasky')
  NxTest.assert_equal(true, MAT_MA.demos_code_known?('edge', '333444'))
  NxTest.assert_equal(false, MAT_MA.demos_code_known?('sheet', ''), 'prazdny kod nikdy')
  NxTest.assert_equal(false, MAT_MA.demos_code_known?('sheet', '999999'), 'neznamy kod')
  # iny dodavatel toho isteho kodu nematchuje (kolizia kodov nezamyka polozku)
  rec = MAT_MA.sheet(sid)
  st2, = MAT_MA.patch_record('sheet', sid, { 'supplier' => 'InyVelkoobchod' },
                             row_rev: MAT_MA.record_rev(rec), allow_duplicate_code: true)
  NxTest.assert_equal(:ok, st2)
  NxTest.assert_equal(false, MAT_MA.demos_code_known?('sheet', '111222'), 'cudzi dodavatel sa nerata')
  # D-60: URL vyhradne zo zaznamu + cerstvy sanitize (audit BLOCKER 2)
  NxTest.assert_equal('https://www.demos-trade.sk/dtdl-h9999-st9-x-2800-2070-18/',
                      MAT_MA.demos_open_target('sheet', sid))
  NxTest.assert_equal(nil, MAT_MA.demos_open_target('edge', info['edges'][0]), 'zaznam bez vazby = nil')
  NxTest.assert_equal(nil, MAT_MA.demos_open_target('sheet', 'NEEXISTUJE'), 'nezname id = nil')
  # poskodeny zaznam (cudzi host vpisany priamo do JSON) sa NIKDY neotvori
  raw = JSON.parse(File.read(MAT_MA.path))
  raw['sheets'].find { |s| s['material_id'] == sid }['demos_url'] = 'https://evil.example.com/x'
  File.write(MAT_MA.path, JSON.pretty_generate(raw))
  Noxun::Engine::JsonFileStore.invalidate(MAT_MA.path)
  NxTest.assert_equal(nil, MAT_MA.demos_open_target('sheet', sid), 'cudzi host neprejde sanitize')
ensure
  NxTest.install_fresh_seed_catalog!
end

# --- M-A3e (D-71): rucna vazba z formulara --------------------------------------

NxTest.test('ma3e: manual_demos_url — sanitize, vedome zmazanie, invalidacia datumu') do
  ok_url = 'https://www.demos-trade.sk/dtdl-h9999-st9-x-2800-2070-18/'
  # platna adresa na cisty zaznam: ziadna invalidacia netreba? — nova vazba
  # znamena, ze stary datum (ak bol) uz neplati; bez existujucej = invalidate
  # true je neskodne (kluc neexistuje).
  st, val, inv = MAT_MA.manual_demos_url(ok_url, nil)
  NxTest.assert_equal([:ok, ok_url, true], [st, val, inv])
  # ta ista adresa znova = ZIADNA zmena vazby (datum overenia prezije)
  st2, val2, inv2 = MAT_MA.manual_demos_url("  #{ok_url}  ", ok_url)
  NxTest.assert_equal([:ok, ok_url, false], [st2, val2, inv2], 'trim + porovnanie po sanitize')
  # ina adresa = invalidacia
  iny = 'https://www.demos-trade.sk/dtdl-h9999-st9-x-2800-2070-25/'
  NxTest.assert_equal(true, MAT_MA.manual_demos_url(iny, ok_url)[2])
  # prazdne pole = vedome zmazanie; invalidacia len ak vazba existovala
  NxTest.assert_equal([:ok, nil, true], MAT_MA.manual_demos_url('   ', ok_url)[0..2])
  NxTest.assert_equal([:ok, nil, false], MAT_MA.manual_demos_url('', nil)[0..2])
  # zly host / nezmysel = invalid (save sa odmietne)
  NxTest.assert_equal(:invalid, MAT_MA.manual_demos_url('https://evil.example.com/x', nil)[0])
  NxTest.assert_equal(:invalid, MAT_MA.manual_demos_url('nie je url', nil)[0])
end

NxTest.test('ma3e: uni_edit_error — demos_url je nakupne pole (UNI ho odmietne)') do
  NxTest.install_fresh_seed_catalog!
  uni = MAT_MA.sheets.find { |s| MAT_MA.uni?(s) }
  NxTest.assert(uni, 'seed ma UNI zaznam')
  err = MAT_MA.uni_edit_error(uni, { 'demos_url' => 'https://www.demos-trade.sk/x-18/' })
  NxTest.assert(err.to_s.include?('UNI'), err.inspect)
  NxTest.assert_equal(nil, MAT_MA.uni_edit_error(uni, { 'demos_url' => '' }),
                      'prazdne pole formulara UNI needituje')
ensure
  NxTest.install_fresh_seed_catalog!
end

# --- Materials.create_group_from_demos (mutator) -------------------------------

NxTest.test('ma1 mutator: legacy katalog odmietnuty; znackova skupina bez dosky odmietnuta') do
  NxTest.install_legacy_catalog!
  st, info = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => 'x',
    'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST10',
                        'code' => '1', 'demos_url' => MA1_DTDL18_URL }], 'edge_items' => [])
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['detail'].include?('pôvodnom formáte'), info.inspect)
  NxTest.install_fresh_seed_catalog!
  st2, info2 = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H9999', 'decor_name' => 'x',
    'sheet_items' => [],
    'edge_items' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST10',
                       'code' => '2', 'demos_url' => MA1_ABS_URL }])
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['detail'].include?('dosku'), info2.inspect)
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 mutator: duplicitny kod+Demos v katalogu = code_conflict, nic sa nezapise') do
  NxTest.install_fresh_seed_catalog!
  base = { 'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => 'Dub',
           'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST10',
                               'code' => '175718', 'price' => 10.0,
                               'demos_url' => MA1_DTDL18_URL }],
           'edge_items' => [] }
  st, = MAT_MA.create_group_from_demos(base)
  NxTest.assert_equal(:ok, st)
  before = File.read(MAT_MA.path)
  dup = base.merge('decor' => 'H4444',
                   'sheet_items' => [base['sheet_items'][0].merge('thickness' => 19.0)])
  st2, info2 = MAT_MA.create_group_from_demos(dup)
  NxTest.assert_equal(:code_conflict, st2, info2.inspect)
  NxTest.assert_equal(before, File.read(MAT_MA.path))
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 mutator: existujuca skupina — nazov sa NEprepise, variant pribudne do group_id') do
  NxTest.install_fresh_seed_catalog!
  st, info = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => 'Dub Hamilton',
    'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST10',
                        'code' => '175718', 'demos_url' => MA1_DTDL18_URL }],
    'edge_items' => [])
  NxTest.assert_equal(:ok, st)
  st2, info2 = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => 'INY NAZOV ZO STRANKY',
    'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 36.0, 'structure' => 'ST10',
                        'code' => '175720', 'demos_url' => MA1_DTDL18_URL }],
    'edge_items' => [])
  NxTest.assert_equal(:ok, st2, info2.inspect)
  NxTest.assert_equal(info['group_id'], info2['group_id'], 'ta ista skupina')
  s36 = MAT_MA.sheet(info2['sheets'][0])
  NxTest.assert_equal('Dub Hamilton', s36['decor_name'], 'existujuci nazov vyhrava (prefer_existing_name)')
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 mutator: cena nil = bez price_checked_at; PD bez formatu = invalid') do
  NxTest.install_fresh_seed_catalog!
  st, info = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => '',
    'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST10',
                        'code' => '175718', 'price' => nil, 'demos_url' => MA1_DTDL18_URL }],
    'edge_items' => [])
  NxTest.assert_equal(:ok, st)
  s = MAT_MA.sheet(info['sheets'][0])
  NxTest.assert_equal(nil, s['price_per_m2'])
  NxTest.assert_equal(nil, s['price_checked_at'], 'bez ceny niet datumu overenia')
  st2, info2 = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H5555', 'decor_name' => '',
    'sheet_items' => [{ 'type' => 'PD', 'thickness' => 38.0, 'structure' => 'ST10',
                        'code' => '9', 'demos_url' => MA1_PD_URL }],
    'edge_items' => [])
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['detail'].to_s.include?('formát'), info2.inspect)
ensure
  NxTest.install_fresh_seed_catalog!
end

# --- GH #101 review fixy ---------------------------------------------------------

NxTest.test('ma1 p1: dve polozky davky s rovnakou identitou variantu = invalid, nic sa nezapise') do
  NxTest.install_fresh_seed_catalog!
  before = File.read(MAT_MA.path)
  item = { 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST10',
           'code' => '111', 'demos_url' => MA1_DTDL18_URL }
  st, info = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => '',
    'sheet_items' => [item, item.merge('code' => '222')], 'edge_items' => [])
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(info['detail'].include?('ten istý variant'), info.inspect)
  NxTest.assert_equal(before, File.read(MAT_MA.path))
  eitem = { 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST10',
            'code' => '333', 'demos_url' => MA1_ABS_URL }
  st2, info2 = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => '',
    'sheet_items' => [item],
    'edge_items' => [eitem, eitem.merge('code' => '444')])
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(info2['detail'].include?('pásky'), info2.inspect)
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 p1: opakovany iid vo vybere = jedna polozka (jeden fetch)') do
  NxTest.install_fresh_seed_catalog!
  map = { MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')] }
  header = ma1_header.merge('image_url' => '')
  events, fake = ma1_run_create(header, [ma1_sheet_item], %w[i0 i0 i0], map)
  done = ma1_complete(events)
  NxTest.assert_equal(true, done['ok'], events.inspect)
  NxTest.assert_equal(1, done['result']['sheets'].length)
  NxTest.assert_equal(1, fake.calls.count { |u| u == MA1_DTDL18_URL },
                      'duplicitny iid nefetchuje polozku druhykrat')
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 p2: skupina bez mena dostane meno pri doplneni variantu — VSETKY zaznamy') do
  NxTest.install_fresh_seed_catalog!
  st, info = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => '',
    'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST10',
                        'code' => '111', 'demos_url' => MA1_DTDL18_URL }],
    'edge_items' => [])
  NxTest.assert_equal(:ok, st)
  first_id = info['sheets'][0]
  NxTest.assert_equal(nil, MAT_MA.sheet(first_id)['decor_name'], 'skupina zatial bez mena')
  st2, = MAT_MA.create_group_from_demos(
    'manufacturer' => 'Egger', 'decor' => 'H3303', 'decor_name' => 'Dub Hamilton',
    'sheet_items' => [{ 'type' => 'DTDL', 'thickness' => 36.0, 'structure' => 'ST10',
                        'code' => '222', 'demos_url' => MA1_DTDL18_URL }],
    'edge_items' => [])
  NxTest.assert_equal(:ok, st2)
  NxTest.assert_equal('Dub Hamilton', MAT_MA.sheet(first_id)['decor_name'],
                      'PRVY zaznam skupiny dostal meno v tej istej transakcii')
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 p2: na dosky sa zapisuje TA ISTA obrazkova URL, ktora sa stahuje (header)') do
  NxTest.install_fresh_seed_catalog!
  header_img = 'https://www.demos-trade.sk/content/images/product/default/231680.jpg'
  FileUtils.rm_f(DIC.path_for(header_img).to_s)
  map = {
    MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')], # stranka nesie 244894
    header_img => [200, {}, ma1_jpeg_body]
  }
  events, fake = ma1_run_create(ma1_header.merge('image_url' => header_img),
                                [ma1_sheet_item], %w[i0], map)
  done = ma1_complete(events)
  NxTest.assert_equal(true, done['ok'], events.inspect)
  NxTest.assert_equal(true, done['result']['image'])
  s = MAT_MA.sheet(done['result']['sheets'][0])
  NxTest.assert_equal(header_img, s['image_url'], 'zapisana URL = stahovana URL (cache hit)')
  NxTest.assert(fake.calls.include?(header_img))
  NxTest.assert(File.exist?(DIC.path_for(header_img)))
ensure
  FileUtils.rm_f(DIC.path_for('https://www.demos-trade.sk/content/images/product/default/231680.jpg').to_s)
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 p2: chyba stahovania obrazka NEZHADZUJE uspesne zalozenie (image=false)') do
  NxTest.install_fresh_seed_catalog!
  map = { MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')],
          MA1_IMG_URL => :err }
  events, = ma1_run_create(ma1_header, [ma1_sheet_item], %w[i0], map)
  done = ma1_complete(events)
  NxTest.assert_equal(true, done['ok'], 'katalog je zapisany — obrazok je best effort')
  NxTest.assert_equal(false, done['result']['image'])
  NxTest.assert_equal(1, done['result']['sheets'].length)
ensure
  NxTest.install_fresh_seed_catalog!
end

NxTest.test('ma1 p2: poskodeny subor v image cache sa neuzna a refetch ho opravi') do
  path = DIC.path_for(MA1_IMG_URL)
  FileUtils.mkdir_p(File.dirname(path))
  File.binwrite(path, '<html>fragment po prerusenom zapise</html>')
  NxTest.assert_equal(nil, DIC.local_for(MA1_IMG_URL), 'fragment bez magic bytes nie je platny obrazok')
  got = nil
  ma1_with_transport(MA1_IMG_URL => [200, {}, ma1_jpeg_body]) do |fake|
    DIC.ensure(MA1_IMG_URL) { |local| got = local }
    NxTest.assert_equal(1, fake.calls.length, 'nevalidny subor = refetch')
  end
  NxTest.assert_equal(path, got)
  NxTest.assert_equal(path, DIC.local_for(MA1_IMG_URL), 'po refetchi je cache platna')
ensure
  FileUtils.rm_f(DIC.path_for(MA1_IMG_URL).to_s)
end

# Transport, ktory vybrane URL ODLOZI (callback az flush!) — simulacia cancelu
# POCAS stahovania obrazka, ked katalog uz je zapisany (GH #102 P1).
class Ma1DeferTransport
  attr_reader :calls

  def initialize(map, defer_url)
    @map = map
    @defer_url = defer_url
    @deferred = []
    @calls = []
  end

  def start(url, _limit, &blk)
    @calls << url
    if url == @defer_url
      @deferred << blk
      return true
    end
    entry = @map[url]
    if entry.nil?
      blk.call(404, {}, '', nil)
    elsif entry == :err
      blk.call(nil, {}, nil, 'spojenie zlyhalo')
    else
      blk.call(entry[0], entry[1], entry[2], nil)
    end
    true
  end

  def flush!(status, headers, body, err)
    pending = @deferred
    @deferred = []
    pending.each { |blk| blk.call(status, headers, body, err) }
  end
end

NxTest.test('ma1 p1 #102: cancel POCAS obrazkovej fazy (po zapise) nezataji zalozenie') do
  NxTest.install_fresh_seed_catalog!
  FileUtils.rm_f(DIC.path_for(MA1_IMG_URL).to_s)
  fake = Ma1DeferTransport.new(
    { MA1_DTDL18_URL => [200, {}, ma1_fixture('h3303_dtdl18_product.html')] }, MA1_IMG_URL
  )
  box = { 'alive' => true }
  events = []
  begin
    DMA.transport = fake
    DFA.create(ma1_header, [ma1_sheet_item], %w[i0],
               alive: -> { box['alive'] },
               emit: ->(e) { events << e })
    # polozky overene, katalog ZAPISANY, obrazok visi v odlozenom fetchi
    NxTest.assert_equal(nil, ma1_complete(events), 'complete este necakame')
    NxTest.assert_equal(1, MAT_MA.load['sheets'].count { |s| s['code'] == '175718' }, 'zapis prebehol')
    box['alive'] = false # cancel/zatvorenie okna az TERAZ (image faza)
    fake.flush!(nil, {}, nil, 'spojenie zlyhalo')
  ensure
    DMA.transport = nil
  end
  done = ma1_complete(events)
  NxTest.assert(done, 'committed complete doruceny aj mrtvej session (events: ' + events.map { |e| e['type'] }.inspect + ')')
  NxTest.assert_equal(true, done['ok'])
  NxTest.assert_equal(1, done['result']['sheets'].length, 'skupina JE zalozena')
  NxTest.assert_equal(false, done['result']['image'], 'obrazok zlyhal — best effort')
ensure
  NxTest.install_fresh_seed_catalog!
end

# --- SCHEMA 6 ------------------------------------------------------------------

NxTest.test('ma1 schema 6: required_schema_for + normalize prepusta len cistu image_url') do
  NxTest.assert_equal(6, MAT_MA.required_schema_for([{ 'image_url' => MA1_IMG_URL }], []))
  NxTest.assert_equal(0, MAT_MA.required_schema_for([{ 'material_id' => 'x' }], []))
  rec = MAT_MA.normalize_sheet('material_id' => 'X', 'decor' => 'D', 'type' => 'DTDL',
                               'thickness' => 18.0, 'image_url' => MA1_IMG_URL)
  NxTest.assert_equal(MA1_IMG_URL, rec['image_url'])
  bad = MAT_MA.normalize_sheet('material_id' => 'X', 'decor' => 'D', 'type' => 'DTDL',
                               'thickness' => 18.0, 'image_url' => 'https://evil.sk/x.jpg')
  NxTest.assert_equal(nil, bad['image_url'], 'nevalidna URL sa NIKDY neprenesie')
end

# --- watchdog F6: progress refreshu --------------------------------------------

NxTest.test('ma1 watchdog: refresh! hlasi progress po indexe aj kazdej child sitemape') do
  index = '<sitemapindex><sitemap><loc>https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.1.xml</loc></sitemap>' \
          '<sitemap><loc>https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.2.xml</loc></sitemap></sitemapindex>'
  child1 = '<urlset><url><loc>https://www.demos-trade.sk/dtdl-a-2800-2070-18/</loc></url></urlset>'
  child2 = '<urlset><url><loc>https://www.demos-trade.sk/dtdl-b-2800-2070-18/</loc></url></urlset>'
  ticks = []
  result = nil
  ma1_with_transport(
    Noxun::Engine::DemosSitemapCache::INDEX_URL => [200, {}, index],
    'https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.1.xml' => [200, {}, child1],
    'https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.2.xml' => [200, {}, child2]
  ) do
    Noxun::Engine::DemosSitemapCache.refresh!(progress: ->(p) { ticks << p['done'] }) do |res|
      result = res
    end
  end
  NxTest.assert_equal(true, result['ok'], result.inspect)
  NxTest.assert_equal([0, 1, 2], ticks, 'progress po indexe a po kazdej child sitemape')
ensure
  p = Noxun::Engine::DemosSitemapCache.path
  File.delete(p) if File.exist?(p)
  Noxun::Engine::JsonFileStore.invalidate(p)
end

NxTest.test('ma1 watchdog: refresh watcheri lookupu sa notifikuju a po dokonceni cistia') do
  Noxun::Engine::DemosLookup.refresh_state_reset!
  hits = 0
  Noxun::Engine::DemosLookup.add_refresh_watcher { hits += 1 }
  Noxun::Engine::DemosLookup.notify_refresh_watchers
  NxTest.assert_equal(1, hits)
  Noxun::Engine::DemosLookup.refresh_state_reset!
  Noxun::Engine::DemosLookup.notify_refresh_watchers
  NxTest.assert_equal(1, hits, 'reset watcherov cisti zoznam')
end
