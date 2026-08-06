# frozen_string_literal: true
# Testy V0.6 E-c: PREPOCITAT CENY — orchestrator PriceRefresh.
# Ziadny zivy fetch: vsetko cez fake transport (Db1Transport z test_demos_b1)
# nad ulozenymi fixtures. Overuje sa: vyber viazanych poloziek z payloadu
# rozpoctu, dedup, sekvencny beh, PER ZAZNAM zapis (ciastocny uspech),
# semantika Zrusit, price_checked_at stamp, tvar reportu a jeden bezaci beh.
require_relative '../helper' unless defined?(NxTest)

PR_EC = Noxun::Engine::PriceRefresh
MAT_EC = Noxun::Engine::Materials
HWC_EC = Noxun::Engine::HardwareCatalog

EC_DTDL18_URL = 'https://www.demos-trade.sk/dtdl-h3303-st10-dub-hamilton-prirodny-2800-2070-18/'
EC_HW_URL = 'https://www.demos-trade.sk/zaves-sensys-ec/'
# Cena z fixture h3303_dtdl18_product.html po prepocte ks -> m2 (vzor b2).
EC_FIXTURE_M2 = 18.9924

def ec_fixture(name)
  File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'demos', name), encoding: 'UTF-8')
end

def ec_page_map(extra = {})
  { EC_DTDL18_URL => [200, {}, ec_fixture('h3303_dtdl18_product.html')] }.merge(extra)
end

# Cerstvy katalog + jedna doska ZVIAZANA s Demosom (D-70 bound cesta —
# ziadna sitemap). Volitelne druha doska s NEEXISTUJUCOU adresou (chybovy
# scenar) a jej cena.
def ec_install_catalog!(price: 15.0, second_url: nil)
  NxTest.install_fresh_seed_catalog!
  gid = MAT_EC.group_id_for('Egger', 'H3303')
  data = MAT_EC.load
  data['sheets'] << MAT_EC.normalize_sheet(
    'material_id' => 'EC_DTDL_18', 'manufacturer' => 'Egger', 'decor' => 'H3303',
    'structure' => 'ST10', 'type' => 'DTDL', 'thickness' => 18.0, 'group_id' => gid,
    'price_per_m2' => price, 'sheet_size' => [2800.0, 2070.0], 'demos_url' => EC_DTDL18_URL
  )
  if second_url
    data['sheets'] << MAT_EC.normalize_sheet(
      'material_id' => 'EC_DTDL_16', 'manufacturer' => 'Egger', 'decor' => 'H3303',
      'structure' => 'ST10', 'type' => 'DTDL', 'thickness' => 16.0, 'group_id' => gid,
      'price_per_m2' => 12.0, 'sheet_size' => [2800.0, 2070.0], 'demos_url' => second_url
    )
  end
  raise 'ec fixtures write failed' unless MAT_EC.write(data)
end

def ec_target(kind, id, label = 'X')
  { 'kind' => kind, 'id' => id, 'label' => label, 'url' => EC_DTDL18_URL }
end

# Spusti beh nad fake transportom; vrati [events, fake].
def ec_run(targets, map, alive: -> { true }, on_event: nil)
  events = []
  fake = Db1Transport.new(map)
  Noxun::Engine::Demos.transport = fake
  PR_EC.reset_state!
  PR_EC.run(targets, alive: alive, emit: lambda { |e|
    events << e
    on_event&.call(e)
  })
  [events, fake]
ensure
  Noxun::Engine::Demos.transport = nil
  PR_EC.reset_state!
end

def ec_report(events)
  ev = events.find { |e| e['type'] == 'complete' }
  ev && ev['report']
end

# Polozka kovania so ZVIAZANOU adresou. create_item vazbu z klienta NIKDY
# nepreberie (F7) — vznika vyhradne proposal flowom, takze ju tu zalozime
# presne tak, ako to robi tlacidlo „Over cenu" (rovnaka cena = unchanged).
def ec_bind_hw!(code, url, price)
  hwc_empty!
  HWC_EC.create_item(hwc_item('item_code' => code, 'price_eur_vat' => price))
  Noxun::Engine::Demos.transport = Db1Transport.new(url => [200, {}, hwc_product_html(code, price)])
  got = nil
  HWC_EC.check_price!(code, url: url) { |r| got = r }
  raise "ec bind hw: #{got.inspect}" unless got && got['ok']
  status, = HWC_EC.apply_price_proposal!(code, pid: got['pid'])
  raise "ec bind hw apply: #{status}" unless status == :ok
ensure
  Noxun::Engine::Demos.transport = nil
end

# --- ciste funkcie: vyber cielov z payloadu ----------------------------------

NxTest.test('ec ceny: targets_from_budget — LEN viazane polozky rozpoctu, dedup, kind guard') do
  budget = { 'stale' => { 'items' => [
    { 'kind' => 'sheet', 'id' => 'S1', 'label' => 'Doska', 'state' => 'stale',
      'demos_url' => 'https://www.demos-trade.sk/a/' },
    { 'kind' => 'sheet', 'id' => 'S1', 'label' => 'Doska (znova)', 'state' => 'unverified',
      'demos_url' => 'https://www.demos-trade.sk/a/' },
    { 'kind' => 'edge', 'id' => 'A1', 'label' => 'ABS', 'state' => 'unverified',
      'demos_url' => 'https://www.demos-trade.sk/b/' },
    { 'kind' => 'hardware', 'id' => '104717', 'label' => 'Záves', 'state' => 'stale',
      'demos_url' => 'https://www.demos-trade.sk/c/' },
    { 'kind' => 'sheet', 'id' => 'S2', 'label' => 'Ručná doska', 'state' => 'manual',
      'demos_url' => nil },
    { 'kind' => 'ine', 'id' => 'X', 'label' => 'Cudzí druh', 'state' => 'stale',
      'demos_url' => 'https://www.demos-trade.sk/d/' },
    { 'kind' => 'sheet', 'id' => '', 'label' => 'Bez id', 'state' => 'stale',
      'demos_url' => 'https://www.demos-trade.sk/e/' }
  ] } }
  t = PR_EC.targets_from_budget(budget)
  NxTest.assert_equal(3, t.length, "len viazane a zname druhy: #{t.inspect}")
  NxTest.assert_equal(%w[S1 A1 104717], t.map { |x| x['id'] }, 'poradie zo scanu, dedup podla (kind,id)')
  NxTest.assert_equal('Záves', t.last['label'])
  NxTest.assert_equal([], PR_EC.targets_from_budget(nil), 'chybajuci payload = ziadne ciele')
  NxTest.assert_equal([], PR_EC.targets_from_budget('stale' => {}), 'prazdny scan = ziadne ciele')
end

NxTest.test('ec ceny: manual_from_budget + estimate_seconds') do
  budget = { 'stale' => { 'items' => [
    { 'kind' => 'sheet', 'id' => 'S1', 'demos_url' => 'https://www.demos-trade.sk/a/' },
    { 'kind' => 'sheet', 'id' => 'S2', 'label' => 'Ručná', 'demos_url' => nil },
    { 'kind' => 'hardware', 'id' => 'H1', 'label' => 'Ručné kovanie' }
  ] } }
  manual = PR_EC.manual_from_budget(budget)
  NxTest.assert_equal(%w[S2 H1], manual.map { |m| m['id'] }, 'bez vazby = rucne overenie')
  NxTest.assert_equal(0, PR_EC.estimate_seconds(0))
  NxTest.assert_equal(4 * PR_EC::SECONDS_PER_ITEM / 4 * 4, PR_EC.estimate_seconds(4), 'linearny odhad')
  NxTest.assert_equal(PR_EC::SECONDS_PER_ITEM * 12, PR_EC.estimate_seconds(12))
end

# --- happy path ---------------------------------------------------------------

NxTest.test('ec ceny: doska — nova cena sa zapise, price_checked_at stampuje server, report sedi') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!
  events, fake = ec_run([ec_target('sheet', 'EC_DTDL_18', 'H3303 DTDL 18')], ec_page_map)
  NxTest.assert_equal(1, fake.calls.length, 'jeden fetch na jednu polozku')
  NxTest.assert_equal(EC_DTDL18_URL, fake.calls.first, 'ide sa na ULOZENU vazbu (D-70, bez sitemap)')
  report = ec_report(events)
  NxTest.assert(report, "complete musi prist: #{events.map { |e| e['type'] }.inspect}")
  NxTest.assert_equal(1, report['changed'], report.inspect)
  NxTest.assert_equal(0, report['errors'])
  NxTest.assert_equal(false, report['cancelled'])
  item = report['items'].first
  NxTest.assert_equal('changed', item['status'])
  NxTest.assert_close(15.0, item['old_price'], 0.001)
  NxTest.assert_close(EC_FIXTURE_M2, item['new_price'], 0.001)
  NxTest.assert_close(EC_FIXTURE_M2 - 15.0, item['diff'], 0.001, 'rozdiel do reportu')
  rec = MAT_EC.sheet('EC_DTDL_18')
  NxTest.assert_close(EC_FIXTURE_M2, rec['price_per_m2'], 0.001, 'cena je v KATALOGU')
  NxTest.assert(rec['price_checked_at'].to_s.match?(/\A\d{4}-\d{2}-\d{2}T/), 'ISO8601 stamp servera')
  NxTest.assert_equal(EC_DTDL18_URL, rec['demos_url'], 'vazba ostava')
end

NxTest.test('ec ceny: eventy — start, progress pred polozkou, item, complete presne RAZ') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!
  events, = ec_run([ec_target('sheet', 'EC_DTDL_18', 'H3303')], ec_page_map)
  types = events.map { |e| e['type'] }
  NxTest.assert_equal(%w[start progress item complete], types, types.inspect)
  NxTest.assert_equal(1, events.first['total'])
  NxTest.assert_equal('H3303', events[1]['label'], 'progress nesie prave stahovanu polozku')
  NxTest.assert_equal(0, events[1]['done'], 'progress ide PRED stiahnutim (0/1)')
  NxTest.assert_equal(1, events[2]['done'], 'item uz je hotovy (1/1)')
  pids = events.map { |e| e['pid'] }.uniq
  NxTest.assert_equal(1, pids.length, 'vsetky eventy nesu pid behu')
  NxTest.assert(pids.first.to_i.positive?)
end

NxTest.test('ec ceny: nezmenena cena — hodnota v katalogu ostava, obnovi sa len datum overenia') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!(price: EC_FIXTURE_M2)
  events, = ec_run([ec_target('sheet', 'EC_DTDL_18', 'H3303')], ec_page_map)
  report = ec_report(events)
  NxTest.assert_equal(1, report['unchanged'], report.inspect)
  NxTest.assert_equal(0, report['changed'])
  item = report['items'].first
  NxTest.assert_equal(nil, item['diff'], 'bez zmeny sa rozdiel neuvadza')
  NxTest.assert_close(EC_FIXTURE_M2, item['new_price'], 0.001, 'nova = stara')
  rec = MAT_EC.sheet('EC_DTDL_18')
  NxTest.assert_close(EC_FIXTURE_M2, rec['price_per_m2'], 0.001)
  NxTest.assert(rec['price_checked_at'].to_s.length.positive?, 'datum overenia sa obnovil (FIX 10)')
end

# --- ciastocny uspech ---------------------------------------------------------

NxTest.test('ec ceny: PER ZAZNAM — zlyhana polozka NEZASTAVI zvysok (ciastocny uspech)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  dead = 'https://www.demos-trade.sk/uz-neexistuje/'
  ec_install_catalog!(second_url: dead)
  events, fake = ec_run([ec_target('sheet', 'EC_DTDL_16', 'H3303 16'),
                         ec_target('sheet', 'EC_DTDL_18', 'H3303 18')],
                        ec_page_map) # 'dead' v mape nie je -> 404
  NxTest.assert_equal(2, fake.calls.length, 'obe polozky sa skusili')
  report = ec_report(events)
  NxTest.assert_equal(1, report['errors'], report.inspect)
  NxTest.assert_equal(1, report['changed'])
  NxTest.assert_equal(2, report['done'])
  NxTest.assert_equal(0, report['skipped'])
  bad = report['items'].find { |i| i['id'] == 'EC_DTDL_16' }
  NxTest.assert_equal('error', bad['status'])
  NxTest.assert(bad['error'].to_s.length.positive?, 'chyba ma dovod')
  NxTest.assert_close(12.0, MAT_EC.sheet('EC_DTDL_16')['price_per_m2'], 0.001, 'zlyhana cena sa NEMENI')
  NxTest.assert_close(EC_FIXTURE_M2, MAT_EC.sheet('EC_DTDL_18')['price_per_m2'], 0.001,
                      'uspesna polozka je zapisana (ziadne all-or-nothing)')
end

NxTest.test('ec ceny: zaznam mimo katalogu / bez vazby = chyba bez fetchu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!
  events, fake = ec_run([ec_target('sheet', 'NEEXISTUJE', 'Duch')], ec_page_map)
  NxTest.assert_equal(0, fake.calls.length, 'neexistujuci zaznam sa nefetchuje')
  item = ec_report(events)['items'].first
  NxTest.assert_equal('error', item['status'])
  NxTest.assert(item['error'].include?('nenašiel'), item.inspect)
end

NxTest.test('ec ceny: zastarany row_rev = conflict (cudzia zmena sa NEPREPISE)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!
  proposal = { 'record_id' => 'EC_DTDL_18', 'kind' => 'sheet', 'status' => 'match',
               'url' => EC_DTDL18_URL, 'warnings' => [],
               'price' => { 'old' => 15.0, 'new' => 20.0, 'unchanged' => false } }
  out = PR_EC.write_material(ec_target('sheet', 'EC_DTDL_18'), 'sheet', 'deadbeef0000',
                             proposal, proposal['price'])
  NxTest.assert_equal('error', out['status'])
  NxTest.assert(out['error'].include?('medzitým'), out.inspect)
  NxTest.assert_close(15.0, MAT_EC.sheet('EC_DTDL_18')['price_per_m2'], 0.001, 'cena netknuta')
end

# --- Zrusit -------------------------------------------------------------------

NxTest.test('ec ceny: Zrusit — rozbehnuta polozka dobehne a ZAPISE sa, zvysok sa preskoci') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!(second_url: EC_DTDL18_URL)
  cancel_after_first = lambda do |e|
    PR_EC.cancel! if e['type'] == 'item'
  end
  events, fake = ec_run([ec_target('sheet', 'EC_DTDL_18', 'H3303 18'),
                         ec_target('sheet', 'EC_DTDL_16', 'H3303 16')],
                        ec_page_map, on_event: cancel_after_first)
  NxTest.assert_equal(1, fake.calls.length, 'druha polozka sa uz nestiahla')
  report = ec_report(events)
  NxTest.assert_equal(true, report['cancelled'], report.inspect)
  NxTest.assert_equal(1, report['done'])
  NxTest.assert_equal(1, report['skipped'])
  NxTest.assert_equal(1, report['changed'], 'prva polozka je zapisana — cena je realne overena')
  NxTest.assert_close(EC_FIXTURE_M2, MAT_EC.sheet('EC_DTDL_18')['price_per_m2'], 0.001)
  NxTest.assert_close(12.0, MAT_EC.sheet('EC_DTDL_16')['price_per_m2'], 0.001, 'preskocena cena netknuta')
end

NxTest.test('ec ceny: mrtve okno — ziadne eventy, ziadny fetch, lock sa uvolni') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!
  events, fake = ec_run([ec_target('sheet', 'EC_DTDL_18')], ec_page_map, alive: -> { false })
  NxTest.assert_equal([], events, 'mrtvemu volajucemu sa neposiela nic (ani complete)')
  NxTest.assert_equal(0, fake.calls.length)
  NxTest.assert_equal(false, PR_EC.running?, 'beh sa uvolnil')
end

# --- jeden bezaci beh ---------------------------------------------------------

class EcHangTransport
  attr_reader :calls

  def initialize
    @calls = []
  end

  # Odpoved NIKDY nepride — simuluje visiaci request (beh ostava rozbehnuty).
  def start(url, _limit)
    @calls << url
    true
  end
end

NxTest.test('ec ceny: bezi LEN JEDEN prepocet — druhe spustenie je NO-OP') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!
  hang = EcHangTransport.new
  Noxun::Engine::Demos.transport = hang
  PR_EC.reset_state!
  pid = PR_EC.run([ec_target('sheet', 'EC_DTDL_18')], alive: -> { true }, emit: ->(_e) {})
  NxTest.assert(pid.to_i.positive?, 'prvy beh dostal pid')
  NxTest.assert_equal(true, PR_EC.running?)
  NxTest.assert_equal(nil, PR_EC.run([ec_target('sheet', 'EC_DTDL_18')],
                                     alive: -> { true }, emit: ->(_e) {}),
                      'druhy beh sa NESPUSTI (throttle sloty aj row_rev baseline)')
  NxTest.assert_equal(1, hang.calls.length, 'ziadny druhy fetch')
  NxTest.assert_equal(nil, PR_EC.run([], alive: -> { true }, emit: ->(_e) {}), 'prazdny zoznam = nil')
ensure
  Noxun::Engine::Demos.transport = nil
  PR_EC.reset_state!
end

NxTest.test('ec ceny: zavrete okno uvolni lock aj pri visiacom behu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_install_catalog!
  alive = { 'v' => true }
  Noxun::Engine::Demos.transport = EcHangTransport.new
  PR_EC.reset_state!
  PR_EC.run([ec_target('sheet', 'EC_DTDL_18')], alive: -> { alive['v'] }, emit: ->(_e) {})
  NxTest.assert_equal(true, PR_EC.running?)
  alive['v'] = false
  NxTest.assert_equal(false, PR_EC.running?, 'mrtvy kontext nesmie drzat lock navzdy')
ensure
  Noxun::Engine::Demos.transport = nil
  PR_EC.reset_state!
end

# --- kovanie ------------------------------------------------------------------

NxTest.test('ec ceny: kovanie ide cestou „Over cenu" — zapis z proposalu, stamp, report') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_bind_hw!('104717', EC_HW_URL, 4.18)
  events, fake = ec_run([{ 'kind' => 'hardware', 'id' => '104717', 'label' => 'Záves Sensys',
                           'url' => EC_HW_URL }],
                        { EC_HW_URL => [200, {}, hwc_product_html('104717', 4.55)] })
  NxTest.assert_equal([EC_HW_URL], fake.calls, 'pouzila sa ULOZENA vazba polozky')
  report = ec_report(events)
  NxTest.assert_equal(1, report['changed'], report.inspect)
  item = report['items'].first
  NxTest.assert_close(4.18, item['old_price'], 0.001)
  NxTest.assert_close(4.55, item['new_price'], 0.001)
  rec = HWC_EC.find('104717')
  NxTest.assert_close(4.55, rec['price_eur_vat'], 0.001, 'cena v katalogu kovania')
  NxTest.assert(rec['price_checked_at'].to_s.match?(/\A\d{4}-/), 'server stamp')
end

NxTest.test('ec ceny: kovanie — stranka s inym kodom nic nezapise a dovod je v reporte') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ec_bind_hw!('104717', EC_HW_URL, 4.18)
  events, = ec_run([{ 'kind' => 'hardware', 'id' => '104717', 'label' => 'Záves Sensys',
                      'url' => EC_HW_URL }],
                   { EC_HW_URL => [200, {}, hwc_product_html('999999', 9.99)] })
  item = ec_report(events)['items'].first
  NxTest.assert_equal('error', item['status'])
  NxTest.assert(item['error'].include?('nesedí'), item.inspect)
  NxTest.assert_close(4.18, HWC_EC.find('104717')['price_eur_vat'], 0.001, 'cena netknuta')
end
