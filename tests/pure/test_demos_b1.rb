# frozen_string_literal: true
# Testy V0.6-B (B-1): Demos core vrstva — URL guardy + async fetch flow (fake
# transport), throttle sloty, sitemap cache (F11 atomicky publish), slug
# matcher (B5 prisna identita) a parser produktovej stranky (realne fixtures
# tests/fixtures/demos/ — B3 jednotky, F8 dedup kopii, F10 encoding).
require_relative '../helper' unless defined?(NxTest)

DMS = Noxun::Engine::Demos
DSC = Noxun::Engine::DemosSitemapCache
DSM = Noxun::Engine::DemosSlugMatcher
DPP = Noxun::Engine::DemosProductParser

def db1_fixture(name)
  File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'demos', name), encoding: 'UTF-8')
end

def db1_urls
  db1_fixture('sitemap_sample.xml').scan(%r{<loc>([^<]+)</loc>}).flatten
end

# Fake transport: mapa url -> [status, headers, body] alebo :err.
class Db1Transport
  attr_reader :calls

  def initialize(map)
    @map = map
    @calls = []
  end

  def start(url, _limit)
    @calls << url
    entry = @map[url]
    if entry.nil?
      yield(404, {}, '', nil)
    elsif entry == :err
      yield(nil, {}, nil, 'spojenie zlyhalo')
    else
      yield(entry[0], entry[1], entry[2], nil)
    end
    true
  end
end

def db1_with_transport(map)
  fake = Db1Transport.new(map)
  DMS.transport = fake
  yield fake
ensure
  DMS.transport = nil
end

# --- URL guardy (audit B2) ---------------------------------------------------

NxTest.test('demos b1: sanitize_url — allowlist, https, zakaz /vyhledavani aj enkodovany') do
  ok, = DMS.sanitize_url('https://www.demos-trade.sk/dtdl-h3303-st10-x-2800-2070-18/')
  NxTest.assert(ok, 'produktova URL prejde')
  NxTest.assert(DMS.sanitize_url('https://demos-trade.sk/x/')[0], 'holy host prejde')
  NxTest.assert_equal(nil, DMS.sanitize_url('http://www.demos-trade.sk/x/')[0], 'http downgrade nie')
  NxTest.assert_equal(nil, DMS.sanitize_url('https://evil.sk/x')[0], 'cudzi host nie')
  NxTest.assert_equal(nil, DMS.sanitize_url('https://demos-trade.sk.evil.sk/x')[0], 'subdomenovy trik nie')
  NxTest.assert_equal(nil, DMS.sanitize_url('https://www.demos-trade.sk/vyhledavani?q=532848')[0],
                      '/vyhledavani je zakazane (robots)')
  NxTest.assert_equal(nil, DMS.sanitize_url('https://www.demos-trade.sk/vyhledavani/foo')[0], 'aj podcesta')
  NxTest.assert_equal(nil, DMS.sanitize_url('https://www.demos-trade.sk/%76yhledavani?q=x')[0],
                      'percent-encoded obideniu zabrani decode (B2)')
  NxTest.assert_equal(nil, DMS.sanitize_url('https://www.demos-trade.sk//vyhledavani')[0], 'dvojita lomka')
  NxTest.assert_equal(nil, DMS.sanitize_url('')[0], 'prazdna adresa')
  NxTest.assert_equal(nil, DMS.sanitize_url('nie je url')[0], 'neplatna adresa')
end

NxTest.test('demos b1: resolve_redirect — absolutna, relativna, prazdna') do
  base = 'https://www.demos-trade.sk/a/b/'
  NxTest.assert_equal('https://www.demos-trade.sk/nova/', DMS.resolve_redirect(base, '/nova/'))
  NxTest.assert_equal('https://evil.sk/x', DMS.resolve_redirect(base, 'https://evil.sk/x'),
                      'absolutny redirect sa vrati — guard ho zabije az v dalsom fetchi')
  NxTest.assert_equal(nil, DMS.resolve_redirect(base, ''))
end

# --- fetch flow s fake transportom (audit B1/F12) ----------------------------

NxTest.test('demos b1: fetch — 200 ok, redirect chain s guardom, redirect na cudzi host zomrie') do
  ok_url = 'https://www.demos-trade.sk/produkt-x/'
  redir = 'https://www.demos-trade.sk/stary/'
  evil_redir = 'https://www.demos-trade.sk/presmeruj-von/'
  db1_with_transport(
    ok_url => [200, {}, '<html>telo</html>'],
    redir => [301, { 'location' => '/produkt-x/' }, ''],
    evil_redir => [302, { 'location' => 'https://evil.sk/x' }, '']
  ) do
    got = nil
    DMS.fetch(ok_url) { |r| got = r }
    NxTest.assert(got['ok'], '200 prejde')
    NxTest.assert_equal('<html>telo</html>', got['body'])

    got = nil
    DMS.fetch(redir) { |r| got = r }
    NxTest.assert(got['ok'], 'redirect na povoleny ciel prejde')
    NxTest.assert_equal(ok_url, got['url'], 'vysledok nesie finalnu URL')

    got = nil
    DMS.fetch(evil_redir) { |r| got = r }
    NxTest.refute(got['ok'], 'redirect na cudzi host sa odmietne')
    NxTest.assert(got['error'].to_s.include?('demos-trade'), got['error'].inspect)
  end
end

NxTest.test('demos b1: fetch — redirect loop konci, 429 zrozumitelne, transport chyba') do
  loop_a = 'https://www.demos-trade.sk/a/'
  loop_b = 'https://www.demos-trade.sk/b/'
  busy = 'https://www.demos-trade.sk/busy/'
  dead = 'https://www.demos-trade.sk/dead/'
  db1_with_transport(
    loop_a => [302, { 'location' => loop_b }, ''],
    loop_b => [302, { 'location' => loop_a }, ''],
    busy => [429, {}, ''],
    dead => :err
  ) do |fake|
    got = nil
    DMS.fetch(loop_a) { |r| got = r }
    NxTest.refute(got['ok'], 'loop sa zastavi')
    NxTest.assert(got['error'].to_s.include?('presmerovan'), got['error'].inspect)
    NxTest.assert(fake.calls.length <= DMS::MAX_REDIRECTS + 1, 'max redirect strop plati')

    got = nil
    DMS.fetch(busy) { |r| got = r }
    NxTest.refute(got['ok'])
    NxTest.assert(got['error'].to_s.include?('429'), '429 hlasi spomalenie')

    got = nil
    DMS.fetch(dead) { |r| got = r }
    NxTest.refute(got['ok'])
    NxTest.assert(got['error'].to_s.include?('zlyhalo'), got['error'].inspect)
  end
end

NxTest.test('demos b1: fetch bez transportu = cista chyba (ziadny pad)') do
  DMS.transport = nil
  got = nil
  DMS.fetch('https://www.demos-trade.sk/x/') { |r| got = r }
  NxTest.refute(got['ok'])
  NxTest.assert(got['error'].to_s.include?('transport'), got['error'].inspect)
end

NxTest.test('demos b1: reserve_slot! — sloty po sebe (crawl-delay 3 s, medziprocesovy subor)') do
  NxTest.skip!('throttle subor pise do sandboxu — len headless') unless NxTest.headless?
  File.delete(DMS.throttle_path) if File.exist?(DMS.throttle_path)
  t0 = 1000.0
  NxTest.assert_close(0.0, DMS.reserve_slot!(t0), 0.001, 'prvy request ide hned')
  w2 = DMS.reserve_slot!(t0 + 0.5)
  NxTest.assert_close(2.5, w2, 0.001, 'druhy o 0,5 s neskor caka do slotu +3 s')
  w3 = DMS.reserve_slot!(t0 + 0.6)
  NxTest.assert_close(5.4, w3, 0.001, 'treti dostane slot +6 s')
  NxTest.assert_close(0.0, DMS.reserve_slot!(t0 + 100), 0.001, 'po pauze ide hned')
end

# --- sitemap cache (audit F11) ----------------------------------------------

NxTest.test('demos b1: sitemap locs/children parse') do
  xml = db1_fixture('sitemap_sample.xml')
  urls = DSC.locs(xml)
  NxTest.assert(urls.length >= 40, "vzorka ma #{urls.length} URL")
  index = '<sitemapindex><sitemap><loc>https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.8.xml</loc></sitemap></sitemapindex>'
  NxTest.assert_equal(['https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.8.xml'],
                      DSC.child_sitemaps(index))
end

NxTest.test('demos b1: sitemap refresh — uspech publikuje, zlyhanie child NECHA stary cache') do
  NxTest.skip!('cache pise do sandboxu — len headless') unless NxTest.headless?
  File.delete(DSC.path) if File.exist?(DSC.path)
  Noxun::Engine::JsonFileStore.invalidate(DSC.path)
  index_xml = '<sitemapindex><sitemap><loc>https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.8.xml</loc></sitemap></sitemapindex>'
  child_xml = '<urlset><url><loc>https://www.demos-trade.sk/p1/</loc></url><url><loc>https://www.demos-trade.sk/p2/</loc></url></urlset>'
  db1_with_transport(
    DSC::INDEX_URL => [200, {}, index_xml],
    'https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.8.xml' => [200, {}, child_xml]
  ) do
    got = nil
    DSC.refresh!(now: 111.0) { |r| got = r }
    NxTest.assert(got['ok'], got.inspect)
    NxTest.assert_equal(2, got['count'])
    NxTest.assert_equal(2, DSC.urls.length)
    NxTest.refute(DSC.stale?(111.0 + 100), 'cerstvy cache nie je stale')
    NxTest.assert(DSC.stale?(111.0 + DSC::STALE_AFTER_S + 1), 'po 7 dnoch stale')
  end
  # zlyhanie childu — stary cache (p1/p2) PREZIJE
  db1_with_transport(
    DSC::INDEX_URL => [200, {}, index_xml],
    'https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.8.xml' => :err
  ) do
    got = nil
    DSC.refresh!(now: 222.0) { |r| got = r }
    NxTest.refute(got['ok'])
    NxTest.assert_equal(2, DSC.urls.length, 'stary cache ostal (F11)')
    NxTest.assert_equal(111.0, DSC.load['fetched_at'], 'timestamp povodny')
  end
ensure
  File.delete(DSC.path) if File.exist?(DSC.path)
  Noxun::Engine::JsonFileStore.invalidate(DSC.path)
end

# --- slug matcher (audit B5) -------------------------------------------------

NxTest.test('demos b1: matcher — plna identita matchne, chybajuci format = ambiguous, cudzi dekor = miss') do
  urls = db1_urls
  pd = { 'material_id' => 'X', 'decor' => 'H3303', 'structure' => 'ST10', 'type' => 'PD',
         'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0] }
  r = DSM.match(pd, urls)
  NxTest.assert_equal('match', r['status'])
  NxTest.assert(r['url'].include?('pracovna-doska-h3303-st10') && r['url'].include?('4100-600-38'))

  r2 = DSM.match(pd.reject { |k, _| k == 'sheet_size' }, urls)
  NxTest.assert_equal('ambiguous', r2['status'], 'PD bez formatu = kandidati 600 aj 920')
  NxTest.assert_equal(2, r2['candidates'].length)

  NxTest.assert_equal('miss', DSM.match(pd.merge('decor' => 'U9999'), urls)['status'])
end

NxTest.test('demos b1: matcher — ina hrubka/struktura NEmatchne (identita je povinna)') do
  urls = db1_urls
  dt = { 'material_id' => 'X', 'decor' => 'H3303', 'structure' => 'ST10', 'type' => 'DTDL',
         'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0] }
  NxTest.assert_equal('miss', DSM.match(dt, urls)['status'],
                      'vzorka ma DTDL 8/12/28 — hrubka 18 NIKDY nematchne inu (B5)')
  NxTest.assert_equal('match', DSM.match(dt.merge('thickness' => 12.0), urls)['status'])
  NxTest.assert_equal('miss', DSM.match(dt.merge('thickness' => 12.0, 'structure' => 'PW'), urls)['status'],
                      'ina struktura diskvalifikuje')
end

NxTest.test('demos b1: matcher — ABS sirka/hrubka, zastena s rubom (aj -2 dedup sufix)') do
  urls = db1_urls
  abs = { 'abs_id' => 'A', 'decor' => 'H3303', 'structure' => 'ST10', 'width' => 43.0, 'thickness' => 2.0 }
  NxTest.assert_equal('match', DSM.match(abs, urls)['status'])
  NxTest.assert_equal('miss', DSM.match(abs.merge('width' => 54.0), urls)['status'], 'neexistujuca sirka nie')
  r08 = DSM.match(abs.merge('width' => 23.0, 'thickness' => 0.8), urls)
  NxTest.assert_equal('match', r08['status'], 'desatinna hrubka 0,8 v slugu (23-0-8)')
  NxTest.assert(r08['url'].include?('23-0-8'), r08.inspect)

  za = { 'material_id' => 'X', 'decor' => 'H1180', 'structure' => 'ST37', 'type' => 'ZASTENA',
         'thickness' => 9.2, 'sheet_size' => [4100.0, 640.0],
         'back_decor' => 'W908', 'back_structure' => 'ST37' }
  r = DSM.match(za, urls)
  NxTest.assert_equal('match', r['status'], r.inspect)
  NxTest.assert(r['url'].include?('zastena-h1180-st37-w908-st37'), 'slug nesie oba dekory')
  NxTest.assert_equal('miss', DSM.match(za.merge('back_decor' => 'F620'), urls)['status'],
                      'iny rub diskvalifikuje (B4)')
end

# --- parser (audit B3/F8/F10) ------------------------------------------------

NxTest.test('demos b1: parser PD fixture — kod, ceny s/bez DPH, parametre, 21 related bez warningov') do
  r = DPP.parse(db1_fixture('h3303_pd_product.html'))
  NxTest.assert(r['ok'])
  NxTest.assert_equal('180799', r['code'])
  NxTest.assert_equal('ks', r['unit'])
  NxTest.assert_close(106.31, r['price_no_vat'], 0.001)
  NxTest.assert_close(130.76, r['price_vat'], 0.001)
  p = r['params']
  NxTest.assert_equal('H3303', p['decor'])
  NxTest.assert_equal('ST10', p['structure'])
  NxTest.assert_equal([4100.0, 600.0], p['format'])
  NxTest.assert_close(38.0, p['thickness'], 0.001)
  NxTest.assert_equal('Postforming', p['pd_type'])
  NxTest.assert_equal(21, r['related'].length, 'cela rodina zo Suvisiaceho sortimentu')
  NxTest.assert_equal([], r['warnings'], 'dedup kopii bez falosnych konfliktov (F8)')
  dtdl18 = r['related'].find { |x| x['code'] == '175718' }
  NxTest.assert(dtdl18, 'DTDL 18 v rodine')
  NxTest.assert_close(110.08, dtdl18['price_vat'], 0.001, 'mobil kopia doplnila s DPH')
  NxTest.assert_close(89.49, dtdl18['price_no_vat'], 0.001)
  NxTest.assert(dtdl18['url'].include?('dtdl-h3303-st10'), 'URL pre retazenie fetchov')
end

NxTest.test('demos b1: parser DTDL fixture + neprodukova stranka') do
  r = DPP.parse(db1_fixture('h3303_dtdl18_product.html'))
  NxTest.assert(r['ok'])
  NxTest.assert_equal('175718', r['code'])
  NxTest.assert_close(110.08, r['price_vat'], 0.001)
  NxTest.assert_equal([2800.0, 2070.0], r['params']['format'])
  bad = DPP.parse('<html><body>nic tu nie je</body></html>')
  NxTest.refute(bad['ok'], 'stranka bez kodu sortimentu nie je produkt')
end

NxTest.test('demos b1: price_for_catalog — jednotky (B3): ks->m2, m->m2, m->bm, neznama=nil') do
  NxTest.assert_close(18.9924, DPP.price_for_catalog(110.08, 'ks', 'sheet', [2800.0, 2070.0]), 0.001,
                      'doska EUR/ks / plocha')
  NxTest.assert_close(53.1545, DPP.price_for_catalog(130.76, 'ks', 'sheet', [4100.0, 600.0]), 0.001)
  NxTest.assert_close(50.0, DPP.price_for_catalog(30.0, 'm', 'sheet', [4100.0, 600.0]), 0.001,
                      'PD EUR/m / sirka v metroch')
  NxTest.assert_close(12.5, DPP.price_for_catalog(12.5, 'm2', 'sheet', nil), 0.001)
  NxTest.assert_close(3.96, DPP.price_for_catalog(3.96, 'm', 'edge', nil), 0.001, 'ABS EUR/m = EUR/bm')
  NxTest.assert_equal(nil, DPP.price_for_catalog(10.0, 'bal', 'sheet', [2800.0, 2070.0]), 'neznama jednotka')
  NxTest.assert_equal(nil, DPP.price_for_catalog(10.0, 'ks', 'sheet', nil), 'ks bez formatu sa neda prepocitat')
  NxTest.assert_equal(nil, DPP.price_for_catalog(nil, 'ks', 'sheet', [1.0, 1.0]))
end

NxTest.test('demos b1: identity_match? — dekor/struktura/hrubka/format proti zaznamu (B5)') do
  parsed = DPP.parse(db1_fixture('h3303_pd_product.html'))
  rec = { 'decor' => 'H3303', 'structure' => 'ST10', 'type' => 'PD',
          'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0] }
  NxTest.assert(DPP.identity_match?(parsed, rec), 'plna zhoda')
  NxTest.refute(DPP.identity_match?(parsed, rec.merge('decor' => 'H1180')), 'iny dekor')
  NxTest.refute(DPP.identity_match?(parsed, rec.merge('structure' => 'ST9')), 'ina struktura')
  NxTest.refute(DPP.identity_match?(parsed, rec.merge('thickness' => 20.0)), 'ina hrubka')
  NxTest.refute(DPP.identity_match?(parsed, rec.merge('sheet_size' => [4100.0, 920.0])),
                'iny format pri format-identity type')
  dtdl = rec.merge('type' => 'DTDL', 'sheet_size' => [9999.0, 1.0])
  NxTest.assert(DPP.identity_match?(parsed, dtdl.merge('thickness' => 38.0)),
                'format sa NEporovnava pri type bez formatu v identite')
end

NxTest.test('demos b1: normalize_html — entity, NBSP, mojibake nezhodi parser') do
  html = DPP.normalize_html("A&nbsp;B C   D")
  NxTest.refute(html.include?('&nbsp;'))
  NxTest.refute(html.include?(" "))
  NxTest.assert_equal(38.5, DPP.num("38,5"))
  NxTest.assert_equal(1234.56, DPP.num("1 234,56"), 'NBSP tisicky')
  NxTest.assert_equal(nil, DPP.num('abc'))
  broken = "z\xFFle".dup.force_encoding('UTF-8')
  NxTest.assert(DPP.normalize_html(broken).valid_encoding?, 'nevalidne bajty sa vycistia')
end
