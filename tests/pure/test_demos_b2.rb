# frozen_string_literal: true
# Testy V0.6 B-2a: identity hardening matchera (poradie dekorov zasteny, ABS
# bez sirky), orchestrator DemosLookup (fetch kazdeho variantu, verify slug
# finalnej URL + identity_match?, cancel, single-flight refresh, terminalny
# complete) a atomicky Materials.apply_demos_batch (preflight, simulovane
# duplicity, price_checked_at semantika, SCHEMA 5).
require_relative '../helper' unless defined?(NxTest)

DL2 = Noxun::Engine::DemosLookup
MAT2 = Noxun::Engine::Materials

def db2_fixture(name)
  File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'demos', name), encoding: 'UTF-8')
end

def db2_urls
  db2_fixture('sitemap_sample.xml').scan(%r{<loc>([^<]+)</loc>}).flatten
end

DB2_DTDL18_URL = 'https://www.demos-trade.sk/dtdl-h3303-st10-dub-hamilton-prirodny-2800-2070-18/'
DB2_DTDL28_URL = 'https://www.demos-trade.sk/dtdl-h3303-st10-dub-hamilton-prirodny-2800-2070-28/'
DB2_PD_URL = 'https://www.demos-trade.sk/pracovna-doska-h3303-st10-dub-hamilton-prirodny-4100-600-38/'

def db2_sitemap!(urls)
  Noxun::Engine::JsonFileStore.write(Noxun::Engine::DemosSitemapCache.path,
                                     'fetched_at' => Time.now.to_f, 'urls' => urls)
end

def db2_clear_sitemap!
  p = Noxun::Engine::DemosSitemapCache.path
  File.delete(p) if File.exist?(p)
  File.delete("#{p}.bak") if File.exist?("#{p}.bak")
  Noxun::Engine::JsonFileStore.invalidate(p)
end

def db2_dtdl_rec(over = {})
  { 'material_id' => 'B2_DTDL_18', 'decor' => 'H3303', 'structure' => 'ST10', 'type' => 'DTDL',
    'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'price_per_m2' => 15.0,
    'group_id' => 'GRP-TEST' }.merge(over)
end

# Zozbiera eventy jedneho behu; alive cez mutovatelny box (cancel testy).
def db2_run(records, map, alive_box = { 'alive' => true })
  events = []
  fake = Db1Transport.new(map)
  Noxun::Engine::Demos.transport = fake
  DL2.run(records, alive: -> { alive_box['alive'] },
                   emit: ->(e) { events << e })
  [events, fake]
ensure
  Noxun::Engine::Demos.transport = nil
end

def db2_proposals(events)
  events.select { |e| e['type'] == 'proposal' }.map { |e| e['proposal'] }
end

def db2_complete(events)
  events.select { |e| e['type'] == 'complete' }
end

# --- matcher hardening (audit BLOCKER 2/3) -----------------------------------

NxTest.test('demos b2: matcher — prehodene strany zasteny NEmatchnu (poradie lice pred rubom)') do
  urls = db2_urls
  ok = { 'material_id' => 'X', 'decor' => 'H1180', 'structure' => 'ST37', 'type' => 'ZASTENA',
         'thickness' => 9.2, 'sheet_size' => [4100.0, 640.0],
         'back_decor' => 'W908', 'back_structure' => 'ST37' }
  NxTest.assert_equal('match', Noxun::Engine::DemosSlugMatcher.match(ok, urls)['status'],
                      'spravne poradie stale matchne')
  swapped = ok.merge('decor' => 'W908', 'back_decor' => 'H1180')
  NxTest.assert_equal('miss', Noxun::Engine::DemosSlugMatcher.match(swapped, urls)['status'],
                      'lice a rub prehodene = INY produkt (BLOCKER 3)')
end

NxTest.test('demos b2: matcher — ABS paska bez sirky sa NIKDY neparuje automaticky') do
  urls = db2_urls
  abs = { 'abs_id' => 'A', 'decor' => 'H3303', 'structure' => 'ST10', 'thickness' => 2.0 }
  NxTest.assert_equal('miss', Noxun::Engine::DemosSlugMatcher.match(abs, urls)['status'],
                      'bez sirky by sa nekontrolovala ani hrubka (BLOCKER 3)')
end

# --- DemosLookup.run ---------------------------------------------------------

NxTest.test('demos b2: lookup happy path — match s kodom a cenou, miss zaznam, progress, complete raz') do
  db2_sitemap!([DB2_DTDL18_URL])
  recs = [db2_dtdl_rec,
          db2_dtdl_rec('material_id' => 'B2_MISS', 'decor' => 'U9999')]
  events, fake = db2_run(recs, DB2_DTDL18_URL => [200, {}, db2_fixture('h3303_dtdl18_product.html')])
  props = db2_proposals(events)
  match = props.find { |p| p['record_id'] == 'B2_DTDL_18' }
  NxTest.assert_equal('match', match && match['status'], props.inspect)
  NxTest.assert_equal('175718', match['code']['new'])
  NxTest.assert_equal('Demos', match['supplier']['new'])
  NxTest.assert_close(18.9924, match['price']['new'], 0.001, 'ks -> m2 cez format stranky')
  NxTest.assert_equal(false, match['price']['unchanged'], 'old 15.0 != new')
  NxTest.assert_equal('miss', props.find { |p| p['record_id'] == 'B2_MISS' }['status'])
  NxTest.assert_equal(1, fake.calls.length, 'fetchol sa LEN match zaznam')
  NxTest.assert_equal(1, events.count { |e| e['type'] == 'progress' })
  dones = db2_complete(events)
  NxTest.assert_equal(1, dones.length, 'complete presne raz')
  NxTest.assert(dones[0]['ok'])
  acc_codes = dones[0]['accessories'].map { |a| a['code'] }
  NxTest.refute(acc_codes.include?('175718'), 'navrhnuty kod nie je v prislusenstve')
ensure
  db2_clear_sitemap!
end

NxTest.test('demos b2: lookup — cudzi obsah stranky = identity_fail bez kodu a ceny') do
  db2_sitemap!([DB2_DTDL18_URL])
  # URL slug sedi so zaznamom, ale telo je INY produkt (PD 38) — obrana proti
  # zlemu obsahu/redirectu: identity_match? parametre odmietne.
  events, = db2_run([db2_dtdl_rec], DB2_DTDL18_URL => [200, {}, db2_fixture('h3303_pd_product.html')])
  p = db2_proposals(events).first
  NxTest.assert_equal('identity_fail', p['status'])
  NxTest.assert_equal(nil, p['code'], 'ziadne data na prevzatie')
  NxTest.assert(p['warnings'].any? { |w| w.include?('nesedí') }, p.inspect)
  NxTest.assert(db2_complete(events).first['ok'], 'identity_fail nie je chyba behu')
ensure
  db2_clear_sitemap!
end

NxTest.test('demos b2: manualna URL — PD stranka proti DTDL zaznamu zomrie na slug prefixe') do
  events = []
  fake = Db1Transport.new(DB2_PD_URL => [200, {}, db2_fixture('h3303_pd_product.html')])
  Noxun::Engine::Demos.transport = fake
  DL2.manual(db2_dtdl_rec, DB2_PD_URL, alive: -> { true }, emit: ->(e) { events << e })
  p = db2_proposals(events).first
  NxTest.assert_equal('identity_fail', p['status'], 'typ prefix je sucast identity (BLOCKER 2)')
  NxTest.assert_equal(1, db2_complete(events).length)
ensure
  Noxun::Engine::Demos.transport = nil
end

NxTest.test('demos b2: manualna URL — zla adresa a cudzi host = fetch_error bez fetchu') do
  events = []
  fake = Db1Transport.new({})
  Noxun::Engine::Demos.transport = fake
  DL2.manual(db2_dtdl_rec, 'https://evil.sk/x', alive: -> { true }, emit: ->(e) { events << e })
  NxTest.assert_equal('fetch_error', db2_proposals(events).first['status'])
  NxTest.assert_equal(0, fake.calls.length, 'sanitize zomrie PRED transportom')
ensure
  Noxun::Engine::Demos.transport = nil
end

NxTest.test('demos b2: lookup skipy — duplak, ABS bez sirky, neznamy typ (aj v manuale)') do
  db2_sitemap!([DB2_DTDL18_URL])
  recs = [db2_dtdl_rec('material_id' => 'B2_DUP', 'source_material_id' => 'B2_DTDL_18',
                       'source_multiplier' => 2),
          { 'abs_id' => 'B2_ABS_NW', 'decor' => 'H3303', 'structure' => 'ST10', 'thickness' => 1.0 },
          db2_dtdl_rec('material_id' => 'B2_ALIEN', 'type' => 'MOJTYP')]
  events, fake = db2_run(recs, {})
  by_id = db2_proposals(events).map { |p| [p['record_id'], p['status']] }.to_h
  NxTest.assert_equal('skipped_duplak', by_id['B2_DUP'])
  NxTest.assert_equal('no_width', by_id['B2_ABS_NW'])
  NxTest.assert_equal('unsupported', by_id['B2_ALIEN'])
  NxTest.assert_equal(0, fake.calls.length, 'ziadne fetche')
  NxTest.assert_equal(1, db2_complete(events).length, 'complete aj pri prazdnej fronte')
  # manual na duplak konci rovnako (skip plati aj pre rucnu URL)
  events2 = []
  Noxun::Engine::Demos.transport = Db1Transport.new({})
  DL2.manual(recs[0], DB2_DTDL18_URL, alive: -> { true }, emit: ->(e) { events2 << e })
  NxTest.assert_equal('skipped_duplak', db2_proposals(events2).first['status'])
ensure
  Noxun::Engine::Demos.transport = nil
  db2_clear_sitemap!
end

NxTest.test('demos b2: cancel po prvom naleze zastavi buduce fetche a stlmi eventy (FIX 7)') do
  db2_sitemap!([DB2_DTDL18_URL, DB2_DTDL28_URL])
  recs = [db2_dtdl_rec,
          db2_dtdl_rec('material_id' => 'B2_DTDL_28', 'thickness' => 28.0)]
  box = { 'alive' => true }
  events = []
  fake = Db1Transport.new(
    DB2_DTDL18_URL => [200, {}, db2_fixture('h3303_dtdl18_product.html')],
    DB2_DTDL28_URL => [200, {}, db2_fixture('h3303_dtdl18_product.html')]
  )
  Noxun::Engine::Demos.transport = fake
  DL2.run(recs, alive: -> { box['alive'] },
                emit: ->(e) { events << e; box['alive'] = false if e['type'] == 'proposal' })
  NxTest.assert_equal(1, fake.calls.length, 'druhy fetch sa uz nespustil')
  NxTest.assert_equal(0, db2_complete(events).length, 'mrtvy volajuci nedostane ani complete')
  NxTest.assert_equal(0, events.count { |e| e['type'] == 'progress' }, 'ani progress po cancel')
ensure
  Noxun::Engine::Demos.transport = nil
  db2_clear_sitemap!
end

# Odlozeny transport — start() len uklada, flush! vola callbacky (single-flight).
class Db2DeferredTransport
  attr_reader :pending

  def initialize(map)
    @map = map
    @pending = []
  end

  def start(url, _limit, &block)
    @pending << [url, block]
    true
  end

  def flush!
    batch = @pending.dup
    @pending.clear
    batch.each do |url, block|
      entry = @map[url]
      entry ? block.call(entry[0], entry[1], entry[2], nil) : block.call(404, {}, '', nil)
    end
  end
end

NxTest.test('demos b2: single-flight — dva lookupy nad chybajucou cache zdielaju JEDEN refresh (FIX 8)') do
  db2_clear_sitemap!
  DL2.refresh_state_reset!
  index_xml = "<urlset><url><loc>#{DB2_DTDL18_URL}</loc></url></urlset>"
  fake = Db2DeferredTransport.new(Noxun::Engine::DemosSitemapCache::INDEX_URL => [200, {}, index_xml])
  Noxun::Engine::Demos.transport = fake
  ev1 = []
  ev2 = []
  miss_rec = db2_dtdl_rec('material_id' => 'B2_MISS', 'decor' => 'U9999')
  DL2.run([miss_rec], alive: -> { true }, emit: ->(e) { ev1 << e })
  DL2.run([miss_rec], alive: -> { true }, emit: ->(e) { ev2 << e })
  NxTest.assert_equal(1, fake.pending.length, 'druhy beh sa PRIPOJIL k bezajucemu refreshu')
  fake.flush!
  NxTest.assert_equal(1, db2_complete(ev1).length, ev1.inspect)
  NxTest.assert_equal(1, db2_complete(ev2).length, 'obaja cakatelia dostali vysledok')
  NxTest.assert(db2_complete(ev1).first['ok'] && db2_complete(ev2).first['ok'])
ensure
  Noxun::Engine::Demos.transport = nil
  DL2.refresh_state_reset!
  db2_clear_sitemap!
end

NxTest.test('demos b2: stale cache sa pouzije HNED + warning; refresh fail bez cache = complete error') do
  # stale cache: pouzije sa hned, complete nesie warning
  Noxun::Engine::JsonFileStore.write(Noxun::Engine::DemosSitemapCache.path,
                                     'fetched_at' => 1.0, 'urls' => [DB2_DTDL18_URL])
  DL2.refresh_state_reset!
  miss_rec = db2_dtdl_rec('material_id' => 'B2_MISS', 'decor' => 'U9999')
  events, = db2_run([miss_rec], Noxun::Engine::DemosSitemapCache::INDEX_URL => :err)
  done = db2_complete(events).first
  NxTest.assert(done && done['ok'], events.inspect)
  NxTest.assert(done['warnings'].any? { |w| w.include?('starší') }, 'warning o starej cache')
  db2_clear_sitemap!
  # bez cache + refresh fail = complete s chybou (terminalny stav, FIX 9)
  DL2.refresh_state_reset!
  events2, = db2_run([miss_rec], Noxun::Engine::DemosSitemapCache::INDEX_URL => :err)
  done2 = db2_complete(events2).first
  NxTest.assert_equal(false, done2 && done2['ok'])
  NxTest.assert(done2['error'].to_s.include?('sitemap'), done2.inspect)
ensure
  DL2.refresh_state_reset!
  db2_clear_sitemap!
end

NxTest.test('demos b2: cena len bez DPH sa NEnavrhne (F9), kod ano; nezmenena cena ma unchanged flag') do
  db2_sitemap!([DB2_DTDL18_URL])
  no_vat_html = <<~HTML
    <html><h1>DTDL H3303 ST10 Dub Hamilton</h1>
    <span>Kód sortimentu</span> <strong>175718</strong>
    <dl><dt>Základná cena za ks</dt><dd>89,49 EUR</dd></dl>
    <table>
    <tr><td>Číslo dekoru</td><td>H3303</td></tr>
    <tr><td>Štruktúra materiálu</td><td>ST10</td></tr>
    <tr><td>Hrúbka materiálu (mm)</td><td>18</td></tr>
    <tr><td>Formát materiálu (mm)</td><td>2800 x 2070</td></tr>
    </table></html>
  HTML
  events, = db2_run([db2_dtdl_rec], DB2_DTDL18_URL => [200, {}, no_vat_html])
  p = db2_proposals(events).first
  NxTest.assert_equal('match', p['status'], p.inspect)
  NxTest.assert_equal('175718', p['code']['new'])
  NxTest.assert_equal(nil, p['price']['new'], 'bez DPH sa neprepocitava (F9)')
  NxTest.assert(p['warnings'].any? { |w| w.include?('bez DPH') })
  # nezmenena cena: old presne ako prepocet stranky -> unchanged true
  events2, = db2_run([db2_dtdl_rec('price_per_m2' => 18.9924)],
                     DB2_DTDL18_URL => [200, {}, db2_fixture('h3303_dtdl18_product.html')])
  NxTest.assert_equal(true, db2_proposals(events2).first['price']['unchanged'])
ensure
  db2_clear_sitemap!
end

# --- apply_demos_batch (audit B6/FIX 10/11/12/14) ----------------------------

def db2_seed!
  NxTest.install_fresh_seed_catalog!
end

def db2_sheet_item(id, fields)
  rec = MAT2.sheet(id)
  { 'kind' => 'sheet', 'id' => id, 'row_rev' => MAT2.record_rev(rec), 'fields' => fields }
end

def db2_edge_item(id, fields)
  rec = MAT2.load['edges'].find { |e| e['abs_id'] == id }
  { 'kind' => 'edge', 'id' => id, 'row_rev' => MAT2.record_rev(rec), 'fields' => fields }
end

NxTest.test('demos b2: apply — kod+cena+URL na doske, price_confirmed na paske; SCHEMA 5, stamp servera') do
  db2_seed!
  NxTest.assert(MAT2.catalog_schema < MAT2::SCHEMA_DEMOS, 'pred applyom marker pod 5')
  items = [db2_sheet_item('K009_PW_DTDL_18',
                          'code' => '175718', 'price' => 18.9924,
                          'demos_url' => DB2_DTDL18_URL),
           db2_edge_item('ABS_K009_10', 'price_confirmed' => true, 'demos_url' => DB2_DTDL18_URL)]
  status, report = MAT2.apply_demos_batch(items, catalog_rev: MAT2.catalog_revision)
  NxTest.assert_equal(:ok, status, report.inspect)
  NxTest.assert_equal(2, report['applied'].length)
  sheet = MAT2.sheet('K009_PW_DTDL_18')
  NxTest.assert_equal('175718', sheet['code'])
  NxTest.assert_equal('Demos', sheet['supplier'], 'dodavatel ide SPOLU s kodom (FIX 11)')
  NxTest.assert_close(18.9924, sheet['price_per_m2'], 0.001)
  NxTest.assert_equal(DB2_DTDL18_URL, sheet['demos_url'])
  NxTest.assert(sheet['price_checked_at'].to_s.match?(/\A\d{4}-\d{2}-\d{2}T/), 'ISO8601 stamp servera')
  edge = MAT2.load['edges'].find { |e| e['abs_id'] == 'ABS_K009_10' }
  NxTest.assert_close(0.55, edge['price_per_bm'], 0.001, 'price_confirmed hodnotu NEMENI')
  NxTest.assert(edge['price_checked_at'].to_s.length > 0, 'datum overenia sa obnovil (FIX 10)')
  NxTest.assert_equal(nil, edge['supplier'], 'bez prijateho kodu sa dodavatel neprepisuje')
  NxTest.assert_equal(MAT2::SCHEMA_DEMOS, MAT2.catalog_schema, 'lazy bump na 5')
end

NxTest.test('demos b2: apply — kod-only NEobnovi datum overenia ceny (FIX 10)') do
  db2_seed!
  status, = MAT2.apply_demos_batch([db2_sheet_item('K009_PW_DTDL_18', 'code' => '175718')],
                                   catalog_rev: MAT2.catalog_revision)
  NxTest.assert_equal(:ok, status)
  sheet = MAT2.sheet('K009_PW_DTDL_18')
  NxTest.assert_equal(nil, sheet['price_checked_at'], 'cena nebola potvrdena')
  NxTest.assert_equal('Demos', sheet['supplier'])
end

NxTest.test('demos b2: apply atomicita — zly row_rev druhej polozky NEzapise ani prvu') do
  db2_seed!
  before = MAT2.sheet('K009_PW_DTDL_18')
  items = [db2_sheet_item('K009_PW_DTDL_18', 'code' => '175718'),
           db2_sheet_item('K009_PW_DTDL_16', 'code' => '999999').merge('row_rev' => 'deadbeef0000')]
  status, report = MAT2.apply_demos_batch(items, catalog_rev: MAT2.catalog_revision)
  NxTest.assert_equal(:conflict, status)
  NxTest.assert_equal('K009_PW_DTDL_16', report['id'], 'report menuje vinnika')
  NxTest.assert_equal(before, MAT2.sheet('K009_PW_DTDL_18'), 'all-or-nothing: prva polozka nezapisana')
end

NxTest.test('demos b2: apply — stale catalog_rev, not_found, duplak, zle payloady') do
  db2_seed!
  ok_item = db2_sheet_item('K009_PW_DTDL_18', 'code' => 'X')
  NxTest.assert_equal(:stale_catalog, MAT2.apply_demos_batch([ok_item], catalog_rev: 'stary')[0])
  NxTest.assert_equal(:not_found, MAT2.apply_demos_batch(
    [{ 'kind' => 'sheet', 'id' => 'NEEXISTUJE', 'row_rev' => 'x', 'fields' => { 'code' => 'A' } }],
    catalog_rev: MAT2.catalog_revision
  )[0])
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch([], catalog_rev: MAT2.catalog_revision)[0])
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch(
    [ok_item.merge('kind' => 'foo')], catalog_rev: MAT2.catalog_revision
  )[0], 'neznamy kind sa neinterpretuje ako sheet (FIX 12)')
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch(
    [ok_item, db2_sheet_item('K009_PW_DTDL_18', 'code' => 'Y')],
    catalog_rev: MAT2.catalog_revision
  )[0], 'duplicitna (kind,id) polozka')
  # duplak v katalogu -> apply na neho zomrie
  NxTest.assert(MAT2.upsert_sheet(MAT2.sheet('K009_PW_DTDL_18')
    .merge('material_id' => 'B2_DUP_36', 'thickness' => 36.0,
           'source_material_id' => 'K009_PW_DTDL_18', 'source_multiplier' => 2)), 'duplak seed')
  dup_rec = MAT2.sheet('B2_DUP_36')
  NxTest.assert_equal(:duplak, MAT2.apply_demos_batch(
    [{ 'kind' => 'sheet', 'id' => 'B2_DUP_36', 'row_rev' => MAT2.record_rev(dup_rec),
       'fields' => { 'code' => 'X' } }],
    catalog_rev: MAT2.catalog_revision
  )[0])
end

NxTest.test('demos b2: apply — validacia poli: cena, URL, prazdny kod') do
  db2_seed!
  rev = MAT2.catalog_revision
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch(
    [db2_sheet_item('K009_PW_DTDL_18', 'price' => 'abc')], catalog_rev: rev
  )[0], 'necislo nie je cena')
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch(
    [db2_sheet_item('K009_PW_DTDL_18', 'price' => -5)], catalog_rev: rev
  )[0], 'zaporna cena nie')
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch(
    [db2_sheet_item('K009_PW_DTDL_18', 'code' => 'X', 'demos_url' => 'https://evil.sk/x')],
    catalog_rev: rev
  )[0], 'cudzia URL neprejde sanitize')
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch(
    [db2_sheet_item('K009_PW_DTDL_18', 'code' => '   ')], catalog_rev: rev
  )[0], 'prazdny kod')
  NxTest.assert_equal(:invalid, MAT2.apply_demos_batch(
    [db2_sheet_item('K009_PW_DTDL_18', {})], catalog_rev: rev
  )[0], 'polozka nic nemeni')
end

NxTest.test('demos b2: apply — duplicitny kod v SIMULOVANOM stave (dve polozky davky aj proti katalogu)') do
  db2_seed!
  items = [db2_sheet_item('K009_PW_DTDL_18', 'code' => 'DUPKOD'),
           db2_sheet_item('K009_PW_DTDL_16', 'code' => 'DUPKOD')]
  status, report = MAT2.apply_demos_batch(items, catalog_rev: MAT2.catalog_revision)
  NxTest.assert_equal(:code_conflict, status, 'polozky davky sa VIDIA navzajom (FIX 12)')
  NxTest.assert(report['detail'].is_a?(Array) && !report['detail'].empty?)
  # proti existujucemu zaznamu: najprv zapis kod na 18-ku, potom davka na 16-ku s tym istym
  st, = MAT2.apply_demos_batch([db2_sheet_item('K009_PW_DTDL_18', 'code' => 'OBSADENY')],
                               catalog_rev: MAT2.catalog_revision)
  NxTest.assert_equal(:ok, st)
  st2, = MAT2.apply_demos_batch([db2_sheet_item('K009_PW_DTDL_16', 'code' => 'OBSADENY')],
                                catalog_rev: MAT2.catalog_revision)
  NxTest.assert_equal(:code_conflict, st2, 'kolizia s nedotknutym zaznamom (supplier Demos na oboch)')
end

NxTest.test('demos b2: demos polia preziju cudzi patch (merge-safe normalize) a nesu SCHEMA 5') do
  db2_seed!
  st, = MAT2.apply_demos_batch(
    [db2_sheet_item('K009_PW_DTDL_18', 'code' => '175718', 'price' => 18.99,
                    'demos_url' => DB2_DTDL18_URL)],
    catalog_rev: MAT2.catalog_revision
  )
  NxTest.assert_equal(:ok, st)
  fresh = MAT2.sheet('K009_PW_DTDL_18')
  st2, = MAT2.patch_record('sheet', 'K009_PW_DTDL_18', { 'price_per_m2' => '21.5' },
                           row_rev: MAT2.record_rev(fresh))
  NxTest.assert_equal(:ok, st2)
  after = MAT2.sheet('K009_PW_DTDL_18')
  NxTest.assert_equal(DB2_DTDL18_URL, after['demos_url'], 'patch inej bunky vazbu nezhodil')
  NxTest.assert(after['price_checked_at'].to_s.length > 0)
  # required_schema_for pozna demos polia na doskach AJ paskach
  NxTest.assert_equal(MAT2::SCHEMA_DEMOS,
                      MAT2.required_schema_for([{ 'demos_url' => 'x' }], []))
  NxTest.assert_equal(MAT2::SCHEMA_DEMOS,
                      MAT2.required_schema_for([], [{ 'price_checked_at' => 'x' }]))
  NxTest.assert_equal(0, MAT2.required_schema_for([{ 'decor' => 'K009' }], [{}]))
end
