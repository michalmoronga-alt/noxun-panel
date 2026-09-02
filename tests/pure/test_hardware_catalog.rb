# frozen_string_literal: true
# Testy V0.6 C-1: katalog kovania — normalize/enum/MJ, create/patch/delete
# s revision guardmi, search (diakritika, tokeny, tie-break, inactive),
# read-only matica, serverovy price proposal flow (BLOCKER 1) a seed
# integrita. Izolacia: vlastny subor v APPDATA sandboxe (helper).
require_relative '../helper' unless defined?(NxTest)

HWC = Noxun::Engine::HardwareCatalog

# Prazdny katalog (BEZ seedu) — testy si polozky tvoria samy.
def hwc_empty!
  FileUtils.mkdir_p(HWC.dir)
  Noxun::Engine::JsonFileStore.write(HWC.path,
                                     'std' => HWC::STD, 'schema' => HWC::SCHEMA_CURRENT, 'items' => [])
  File.delete("#{HWC.path}.bak") if File.exist?("#{HWC.path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
end

# Cisty stav BEZ suboru (na seed / assess testy).
def hwc_wipe!
  [HWC.path, "#{HWC.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
end

def hwc_item(over = {})
  { 'item_code' => '104717', 'name_sk' => 'Záves Sensys 8645i TH52 110°',
    'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 4.18 }.merge(over)
end

# --- normalize + enum --------------------------------------------------------

NxTest.test('hw katalog: normalize — povinne polia, enum kategorie a MJ, aliasy jednotiek') do
  rec, err = HWC.normalize_item(hwc_item)
  NxTest.assert_equal(nil, err)
  NxTest.assert_equal('104717', rec['item_code'])
  NxTest.assert_close(4.18, rec['price_eur_vat'], 0.001)
  NxTest.refute(rec.key?('active'), 'active true sa neuklada (sparse, Q1)')
  NxTest.assert_equal(nil, HWC.normalize_item(hwc_item('item_code' => ' '))[0], 'bez kodu nie')
  NxTest.assert_equal(nil, HWC.normalize_item(hwc_item('name_sk' => ''))[0], 'bez nazvu nie')
  NxTest.assert_equal(nil, HWC.normalize_item(hwc_item('category' => 'KLUCKY'))[0], 'neznama kategoria')
  NxTest.assert_equal(nil, HWC.normalize_item(hwc_item('unit' => 'krabica'))[0], 'neznama MJ')
  NxTest.assert_equal('set', HWC.normalize_item(hwc_item('unit' => 'sada'))[0]['unit'], 'alias sada->set')
  NxTest.assert_equal('par', HWC.normalize_item(hwc_item('unit' => 'pár'))[0]['unit'], 'alias par')
  NxTest.assert_equal('m', HWC.normalize_item(hwc_item('unit' => 'bm'))[0]['unit'], 'alias bm->m')
  bez = HWC.normalize_item(hwc_item('price_eur_vat' => ''))[0]
  NxTest.refute(bez.key?('price_eur_vat'), 'prazdna cena = kluc chyba (nil != 0)')
  off = HWC.normalize_item(hwc_item('active' => false))[0]
  NxTest.assert_equal(false, off['active'], 'active false sa uklada')
  # GH #99 P2: zaporna / nekonecna cena sa odmietne (0 je legalna)
  NxTest.assert_equal(nil, HWC.normalize_item(hwc_item('price_eur_vat' => -5))[0], 'zaporna nie')
  NxTest.assert_equal(nil, HWC.normalize_item(hwc_item('price_eur_vat' => '1e999'))[0],
                      'nekonecno by zhodilo JSON zapis')
  NxTest.assert_close(0.0, HWC.normalize_item(hwc_item('price_eur_vat' => 0))[0]['price_eur_vat'],
                      0.0001, 'nula je legalna cena')
end

# --- create / patch / delete -------------------------------------------------

NxTest.test('hw katalog: create — unikatny kod (CI), cache polia sa z klienta neprevezmu') do
  hwc_empty!
  st, rec = HWC.create_item(hwc_item('demos_url' => 'https://www.demos-trade.sk/x/',
                                     'price_checked_at' => '2026-01-01T00:00:00Z',
                                     'use_count' => 99))
  NxTest.assert_equal(:ok, st)
  NxTest.refute(rec.key?('demos_url'), 'URL z klienta sa pri create ignoruje (F7)')
  NxTest.refute(rec.key?('price_checked_at'), 'stamp z klienta nie')
  NxTest.refute(rec.key?('use_count'), 'use_count z klienta nie')
  NxTest.assert_equal(:exists, HWC.create_item(hwc_item)[0], 'duplicitny kod')
  NxTest.assert_equal(:exists, HWC.create_item(hwc_item('item_code' => ' 104717 '))[0], 'CI/trim zhoda')
  NxTest.assert_equal(:invalid, HWC.create_item(hwc_item('category' => 'X'))[0])
end

NxTest.test('hw katalog: patch — whitelist, row_rev conflict, invalidacia price_checked_at (F5)') do
  hwc_empty!
  HWC.create_item(hwc_item)
  rec = HWC.find('104717')
  rev = HWC.record_rev(rec)
  st, out = HWC.patch_item('104717', { 'price_eur_vat' => '5.10', 'item_code' => 'HACK',
                                       'use_count' => 5 }, row_rev: rev)
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal('104717', out['item_code'], 'identita nemenna (whitelist)')
  NxTest.assert_close(5.10, out['price_eur_vat'], 0.001)
  NxTest.refute(out.key?('use_count'), 'use_count nie je patchable')
  NxTest.assert_equal(:conflict, HWC.patch_item('104717', { 'notes' => 'x' }, row_rev: rev)[0],
                      'stary row_rev = conflict')
  NxTest.assert_equal(:conflict, HWC.patch_item('104717', { 'notes' => 'x' }, row_rev: '')[0],
                      'prazdny row_rev sa NEPRESKAKUJE (povinny baseline)')
  NxTest.assert_equal(:invalid, HWC.patch_item('104717', { 'price_eur_vat' => 'abc' },
                                               row_rev: HWC.record_rev(HWC.find('104717')))[0],
                      'necislo cenu NEVYMAZE ticho')
  # price_checked_at invalidacia: nastav stamp primo (simulacia proposal apply)
  hwc_empty!
  HWC.create_item(hwc_item)
  base = HWC.find('104717').merge('price_checked_at' => '2026-01-01T00:00:00Z',
                                  'demos_url' => 'https://www.demos-trade.sk/x/')
  Noxun::Engine::JsonFileStore.write(HWC.path, 'std' => HWC::STD, 'schema' => 1, 'items' => [base])
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  st2, out2 = HWC.patch_item('104717', { 'price_eur_vat' => '9.99' },
                             row_rev: HWC.record_rev(HWC.find('104717')))
  NxTest.assert_equal(:ok, st2)
  NxTest.refute(out2.key?('price_checked_at'), 'rucna zmena ceny zmaze datum overenia (F5)')
  NxTest.assert_equal('https://www.demos-trade.sk/x/', out2['demos_url'], 'vazba ostava')
  st3, out3 = HWC.patch_item('104717', { 'demos_url' => '' },
                             row_rev: HWC.record_rev(HWC.find('104717')))
  NxTest.assert_equal(:ok, st3)
  NxTest.refute(out3.key?('demos_url'), 'prazdny patch URL vymaze vazbu')
  st4, = HWC.patch_item('104717', { 'demos_url' => 'https://www.demos-trade.sk/nova/' },
                        row_rev: HWC.record_rev(HWC.find('104717')))
  NxTest.assert_equal(:invalid, st4, 'neprazdnu URL patch odmietne (len proposal flow)')
end

NxTest.test('hw katalog: delete s row_rev; MJ patch zmaze datum overenia') do
  hwc_empty!
  HWC.create_item(hwc_item)
  NxTest.assert_equal(:conflict, HWC.delete_item('104717', row_rev: 'zly')[0])
  NxTest.assert_equal(:ok, HWC.delete_item('104717', row_rev: HWC.record_rev(HWC.find('104717')))[0])
  NxTest.assert_equal(nil, HWC.find('104717'))
  # unit patch — datum prec (cena je per MJ)
  HWC.create_item(hwc_item('item_code' => 'X1', 'unit' => 'ks'))
  base = HWC.find('X1').merge('price_checked_at' => '2026-01-01T00:00:00Z')
  Noxun::Engine::JsonFileStore.write(HWC.path, 'std' => HWC::STD, 'schema' => 1, 'items' => [base])
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  st, out = HWC.patch_item('X1', { 'unit' => 'bal' }, row_rev: HWC.record_rev(HWC.find('X1')))
  NxTest.assert_equal(:ok, st)
  NxTest.refute(out.key?('price_checked_at'), 'zmena MJ zneplatni overenie')
end

# --- search ------------------------------------------------------------------

NxTest.test('hw katalog: search — diakritika, tokeny, skore, tie-break use_count, inactive') do
  list = [
    hwc_item('item_code' => '104717', 'name_sk' => 'Záves Sensys 8645i naložený'),
    hwc_item('item_code' => '104719', 'name_sk' => 'Záves Sensys 8645i vložený'),
    hwc_item('item_code' => '360281', 'name_sk' => 'Skrutka SPAX 3,5×16',
             'category' => 'SPOJOVACI_MATERIAL', 'unit' => 'bal'),
    hwc_item('item_code' => '82744', 'name_sk' => 'Klzák STRONG s rektifikáciou',
             'category' => 'NOHY', 'active' => false),
    hwc_item('item_code' => '900001', 'name_sk' => 'Záves testovací', 'use_count' => 9),
    hwc_item('item_code' => '900002', 'name_sk' => 'Záves testovací', 'use_count' => 2)
  ]
  r = HWC.search(list, 'zaves')
  NxTest.assert(r.length >= 4, 'diakritika: "zaves" najde "Záves"')
  NxTest.refute(r.any? { |i| i['item_code'] == '82744' }, 'inactive sa v beznom hladani skryva')
  NxTest.assert_equal('82744', HWC.search(list, '82744').first&.fetch('item_code', nil),
                      'presny kod najde aj inactive')
  r2 = HWC.search(list, 'zaves vlozeny')
  NxTest.assert_equal(['104719'], r2.map { |i| i['item_code'] }, 'kazdy token musi matchnut')
  r3 = HWC.search(list, '1047')
  NxTest.assert_equal('104717', r3.first['item_code'], 'kod prefix boduje, tie-break item_code')
  r4 = HWC.search(list, 'zaves testovaci')
  NxTest.assert_equal(%w[900001 900002], r4.map { |i| i['item_code'] },
                      'pri rovnakom skore rozhoduje use_count DESC')
  NxTest.assert_equal(2, HWC.search(list, '', category: 'ZAVESY', top: 2).length, 'kategoria + top limit')
  NxTest.assert_equal([], HWC.search(list, 'neexistujuce'), 'ziadny match = prazdno')
end

# --- read-only matica (F3) ---------------------------------------------------

NxTest.test('hw katalog: assess — poskodeny/novsi/zly tvar = READ-ONLY, mutacie odmietnute') do
  hwc_wipe!
  File.write(HWC.path, '{zlomeny json')
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
  NxTest.assert_equal(:read_only, HWC.assess!)
  NxTest.assert_equal(:read_only, HWC.create_item(hwc_item)[0], 'zapis odmietnuty')
  hwc_wipe!
  Noxun::Engine::JsonFileStore.write(HWC.path, 'std' => HWC::STD, 'schema' => 99, 'items' => [])
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
  NxTest.assert_equal(:read_only, HWC.assess!, 'novsia schema = read-only')
  hwc_wipe!
  Noxun::Engine::JsonFileStore.write(HWC.path, 'std' => 'cudzi', 'schema' => 1, 'items' => [])
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
  NxTest.assert_equal(:read_only, HWC.assess!, 'cudzi std = read-only')
  hwc_wipe!
  Noxun::Engine::JsonFileStore.write(HWC.path, 'std' => HWC::STD, 'schema' => 1, 'items' => 'nie pole')
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
  NxTest.assert_equal(:read_only, HWC.assess!, 'items nie Array = read-only')
end

NxTest.test('hw katalog: poskodeny PRIMAR s platnou zalohou = read-only (GH #99 P1), dup kody = read-only') do
  # platny katalog -> vznikne .bak -> primar sa poskodi -> citanie bezi z .bak,
  # ale zapis STOJI (mutacia by prepisala primar starsim obsahom zalohy)
  hwc_empty!
  HWC.create_item(hwc_item)
  HWC.create_item(hwc_item('item_code' => 'X2')) # 2. zapis -> .bak drzi 1-polozkovy stav
  File.write(HWC.path, '{zlomeny')
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
  NxTest.assert_equal(:read_only, HWC.assess!, 'fallback na .bak NIE JE :ok')
  NxTest.assert(HWC.items.length >= 1, 'citanie z .bak dalej funguje')
  NxTest.assert_equal(:read_only, HWC.create_item(hwc_item('item_code' => 'X3'))[0])
  # duplicitne kody (case-insensitive) v subore = nejednoznacna identita
  hwc_wipe!
  Noxun::Engine::JsonFileStore.write(HWC.path, 'std' => HWC::STD, 'schema' => 1, 'items' => [
    HWC.normalize_item(hwc_item)[0],
    HWC.normalize_item(hwc_item('item_code' => ' 104717 ', 'name_sk' => 'Duplikat'))[0]
  ])
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
  NxTest.assert_equal(:read_only, HWC.assess!, 'CI duplicitne kody = read-only (GH #99 P2)')
end

NxTest.test('hw katalog: write_unlocked cita CERSTVY marker — cudzi novsi subor sa neprepise (GH #99 P1)') do
  hwc_empty!
  HWC.create_item(hwc_item)
  rec = HWC.find('104717')
  # iny proces medzitym nahradi subor NOVSOU schemou (cached @state je :ok)
  File.write(HWC.path, JSON.generate('std' => HWC::STD, 'schema' => 99, 'items' => []))
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  st, = HWC.patch_item('104717', { 'notes' => 'x' }, row_rev: HWC.record_rev(rec))
  NxTest.refute(st == :ok, 'zapis nad novsou schemou sa odmietne')
  raw = JSON.parse(File.binread(HWC.path))
  NxTest.assert_equal(99, raw['schema'], 'novsi subor ostal nedotknuty')
end

# --- price proposal flow (BLOCKER 1) -----------------------------------------

def hwc_product_html(code, price_vat, unit = 'ks')
  <<~HTML
    <html><h1>Produkt #{code}</h1>
    <span itemprop="brand">Hettich</span>
    <span>Kód sortimentu</span> <strong>#{code}</strong>
    <dl><dt>Základná cena za #{unit}</dt><dd>3,40 EUR
    #{format('%.2f', price_vat).tr('.', ',')} EUR s DPH</dd></dl>
    <table><tr><td>Číslo dekoru</td><td>—</td></tr></table></html>
  HTML
end

NxTest.test('hw katalog: check_price! — identity guard kodu, MJ zhoda, len s DPH; proposal server-side') do
  hwc_empty!
  HWC.create_item(hwc_item) # 104717, ks, 4.18
  url = 'https://www.demos-trade.sk/zaves-sensys/'
  # zly kod stranky
  fake = Db1Transport.new(url => [200, {}, hwc_product_html('999999', 4.30)])
  Noxun::Engine::Demos.transport = fake
  got = nil
  HWC.check_price!('104717', url: url) { |r| got = r }
  NxTest.assert_equal('error', got['status'])
  NxTest.assert(got['error'].include?('999999'), 'hlaska menuje cudzi kod')
  NxTest.assert_equal(nil, HWC.price_proposals['104717'], 'ziadny proposal pri zlyhani')
  # zla jednotka
  Noxun::Engine::Demos.transport = Db1Transport.new(url => [200, {}, hwc_product_html('104717', 4.30, 'bal')])
  HWC.check_price!('104717', url: url) { |r| got = r }
  NxTest.assert_equal('error', got['status'])
  NxTest.assert(got['error'].include?('jednotka'), got.inspect)
  # OK — proposal vznikne na serveri
  Noxun::Engine::Demos.transport = Db1Transport.new(url => [200, {}, hwc_product_html('104717', 4.30)])
  HWC.check_price!('104717', url: url) { |r| got = r }
  NxTest.assert_equal('proposal', got['status'], got.inspect)
  NxTest.assert_close(4.30, got['new'], 0.001)
  NxTest.assert(HWC.price_proposals['104717'], 'proposal ulozeny server-side')
ensure
  Noxun::Engine::Demos.transport = nil
end

NxTest.test('hw katalog: apply_price_proposal! — zapis len z proposalu, pid vazba, base_row_rev conflict') do
  hwc_empty!
  HWC.create_item(hwc_item)
  url = 'https://www.demos-trade.sk/zaves-sensys/'
  Noxun::Engine::Demos.transport = Db1Transport.new(url => [200, {}, hwc_product_html('104717', 4.30)])
  got = nil
  HWC.check_price!('104717', url: url) { |r| got = r }
  Noxun::Engine::Demos.transport = nil
  NxTest.assert(got['pid'].to_s.length.positive?, 'vysledok nesie pid navrhu')
  NxTest.assert_equal(:no_proposal, HWC.apply_price_proposal!('999', pid: got['pid'])[0], 'cudzi kod nic')
  NxTest.assert_equal(:no_proposal, HWC.apply_price_proposal!('104717', pid: 'iny')[0],
                      'pid mismatch = zapis odmietnuty (GH #99 P2 — prekryvajuce sa checky)')
  st, rec = HWC.apply_price_proposal!('104717', pid: got['pid'])
  NxTest.assert_equal(:ok, st)
  NxTest.assert_close(4.30, rec['price_eur_vat'], 0.001)
  NxTest.assert_equal(url, rec['demos_url'], 'finalna URL sa ulozi ako vazba')
  NxTest.assert(rec['price_checked_at'].to_s.match?(/\A\d{4}-/), 'server stamp')
  NxTest.assert_equal(nil, HWC.price_proposals['104717'], 'proposal skonzumovany')
  # conflict: proposal nad starym zaznamom
  Noxun::Engine::Demos.transport = Db1Transport.new(url => [200, {}, hwc_product_html('104717', 4.55)])
  got2 = nil
  HWC.check_price!('104717') { |r| got2 = r } # pouzije ulozenu demos_url
  Noxun::Engine::Demos.transport = nil
  fresh = HWC.find('104717')
  HWC.patch_item('104717', { 'notes' => 'medzitym' }, row_rev: HWC.record_rev(fresh))
  NxTest.assert_equal(:conflict, HWC.apply_price_proposal!('104717', pid: got2['pid'])[0],
                      'zaznam zmeneny od checku = conflict (base_row_rev)')
  NxTest.assert_equal(nil, HWC.price_proposals['104717'], 'konfliktny proposal zahodeny')
ensure
  Noxun::Engine::Demos.transport = nil
end

NxTest.test('hw katalog: seed — deterministicky manifest, unikatne kody, enum, ceny; bezi pri chybajucom subore') do
  hwc_wipe!
  NxTest.assert_equal(:ok, HWC.assess!, 'chybajuci subor -> seed -> ok')
  list = HWC.items
  NxTest.assert_equal(HWC::SEED_ROWS.length, list.length, 'kazdy riadok manifestu sa seedol')
  NxTest.assert_equal(60, list.length, 'zmrazeny rozsah manifestu (58 + krytky 105408/105425 — D1)')
  codes = list.map { |i| i['item_code'].downcase }
  NxTest.assert_equal(codes.uniq.length, codes.length, 'unikatne kody')
  list.each do |i|
    NxTest.assert(HWC::CATEGORIES.include?(i['category']), "enum kategorie: #{i['item_code']}")
    NxTest.assert(HWC::UNITS.include?(i['unit']), "enum MJ: #{i['item_code']}")
    NxTest.assert(i['price_eur_vat'].nil? || i['price_eur_vat'].is_a?(Float),
                  "cena Float alebo chyba: #{i['item_code']}")
    NxTest.assert_equal('Demos', i['supplier'])
    NxTest.refute(i.key?('price_checked_at'), 'seed cena nie je "overena" (ziadny stamp)')
  end
  NxTest.assert_close(4.18, HWC.find('104717')['price_eur_vat'], 0.001, 'Sensys KLASIK s cenou z CSV')
  NxTest.assert_equal(nil, HWC.find('360281')['price_eur_vat'], 'SPAX bez ceny (nil != 0)')
  NxTest.assert_equal('set', HWC.find('357695')['unit'], 'Atira K-sada = set')
  NxTest.refute(codes.include?('25031'), 'preklepovy TipOn kod z CSV sa NEseeduje (zmrazene 250831)')
  # opakovany assess uz NEseeduje (subor existuje) — zmena preziva
  rec = HWC.find('104717')
  HWC.patch_item('104717', { 'notes' => 'moje' }, row_rev: HWC.record_rev(rec))
  HWC.reset_state!
  HWC.assess!
  NxTest.assert_equal('moje', HWC.find('104717')['notes'], 'druhy boot seed NEPREPISE data')
end

NxTest.test('hw katalog: check_price! unchanged — ZACHOVA ulozenu cenu, obnovi len URL+datum (GH #99 P2)') do
  hwc_empty!
  HWC.create_item(hwc_item) # cena 4.18
  url = 'https://www.demos-trade.sk/zaves-sensys/'
  # stranka ma 4.1840 — v tolerancii 0.005 = "nezmenene"; katalogova hodnota
  # sa NESMIE posunut na fetchnute 4.184 (sucty by sa hybali bez dovodu)
  Noxun::Engine::Demos.transport = Db1Transport.new(url => [200, {}, hwc_product_html('104717', 4.184)])
  got = nil
  HWC.check_price!('104717', url: url) { |r| got = r }
  Noxun::Engine::Demos.transport = nil
  NxTest.assert_equal('unchanged', got['status'])
  st, rec = HWC.apply_price_proposal!('104717', pid: got['pid'])
  NxTest.assert_equal(:ok, st)
  NxTest.assert_close(4.18, rec['price_eur_vat'], 0.0001, 'ulozena cena OSTALA presne 4.18')
  NxTest.assert_equal(url, rec['demos_url'])
  NxTest.assert(rec['price_checked_at'].to_s.length.positive?, 'datum overenia obnoveny')
end

# --- V0.6 D2: Pridat z Demosu (proposal -> zapis s vazbou) --------------------

NxTest.test('d2 katalog: category_guess — heuristika slug/nazov, fallback OSTATNE') do
  NxTest.assert_equal('ZAVESY', HWC.category_guess('zaves-sensys-8645i Sensys 110'))
  NxTest.assert_equal('VYSUVY', HWC.category_guess('k-innotech-atira-celny-biely-420-70'))
  NxTest.assert_equal('SPOJOVACI_MATERIAL', HWC.category_guess('podperka-policova-7-5'))
  NxTest.assert_equal('SPOJOVACI_MATERIAL', HWC.category_guess('zavesne-kovanie-bystrica'))
  NxTest.assert_equal('VYKLOPY', HWC.category_guess('blum aventos hl'))
  NxTest.assert_equal('OSTATNE', HWC.category_guess('nieco-uplne-ine-123'))
end

NxTest.test('d2 katalog: build_create_proposal — kod/nazov/MJ povinne, cena volitelna, related') do
  html_err = HWC.build_create_proposal('https://x/', 'ok' => false, 'error' => 'timeout')
  NxTest.assert_equal(false, html_err['ok'])
  bad = HWC.build_create_proposal('https://x/', 'ok' => true, 'body' => '<html><body>nic</body></html>')
  NxTest.assert_equal(false, bad['ok'], 'neproduktova stranka = chyba')
end

NxTest.test('d2 katalog: create_from_demos! — zapis z proposalu so server vazbou; exists/no_proposal') do
  hwc_wipe!
  HWC.assess!
  prop = { 'pid' => 'test-pid-1', 'url' => 'https://www.demos-trade.sk/zaves-x-999001/',
           'code' => '999001', 'name_sk' => 'Testovací záves', 'unit' => 'ks',
           'price_vat' => 3.5, 'category_guess' => 'ZAVESY' }
  HWC.create_proposals['test-pid-1'] = prop
  status, rec = HWC.create_from_demos!('test-pid-1', category: '', notes: 'z testu')
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal('ZAVESY', rec['category'], 'prazdna kategoria = guess')
  NxTest.assert_close(3.5, rec['price_eur_vat'], 0.001)
  NxTest.assert_equal('https://www.demos-trade.sk/zaves-x-999001/', rec['demos_url'], 'vazba zo servera')
  NxTest.assert(rec['price_checked_at'].to_s.length.positive?, 'cena overena = datum')
  NxTest.assert_equal('z testu', rec['notes'])
  NxTest.assert_equal(:no_proposal, HWC.create_from_demos!('test-pid-1')[0],
                      'proposal je jednorazovy (zmizol po zapise)')
  HWC.create_proposals['test-pid-2'] = prop.merge('pid' => 'test-pid-2')
  NxTest.assert_equal(:exists, HWC.create_from_demos!('test-pid-2')[0], 'duplicitny kod = exists')
  HWC.create_proposals['test-pid-3'] = prop.merge('pid' => 'test-pid-3', 'code' => '999002',
                                                  'price_vat' => nil)
  status, rec = HWC.create_from_demos!('test-pid-3', category: 'NOHY')
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal('NOHY', rec['category'], 'kategoriu smie klient zmenit (enum guard)')
  NxTest.refute(rec.key?('price_eur_vat'), 'bez ceny = kluc chyba (nil != 0)')
  NxTest.refute(rec.key?('price_checked_at'), 'bez ceny ziadny datum overenia')
  NxTest.assert_equal('https://www.demos-trade.sk/zaves-x-999001/', rec['demos_url'], 'vazba aj bez ceny')
end

NxTest.test('d2 katalog GH#128: materialova stranka sa do kovania NEDOSTANE') do
  body = File.read(File.join(__dir__, '..', 'fixtures', 'demos', 'h3303_dtdl18_product.html'),
                   mode: 'rb:UTF-8')
  url = 'https://www.demos-trade.sk/dtd-laminovana-h3303-st10-dub-hamilton-2800-2070-18/'
  out = HWC.build_create_proposal(url, 'ok' => true, 'body' => body)
  NxTest.assert_equal(false, out['ok'], 'DTDL doska sa neda zalozit ako kovanie')
  NxTest.assert(out['error'].to_s.include?('materiál'), "zrozumitelny dovod: #{out['error']}")
end

NxTest.test('d2 katalog GH#128: redirect URL a cas fetchu putuju do zaznamu') do
  hwc_wipe!
  HWC.assess!
  final = 'https://www.demos-trade.sk/zaves-novy-999003/'
  prop = { 'pid' => 'p-redir', 'url' => final, 'code' => '999003',
           'name_sk' => 'Záves po presmerovaní', 'unit' => 'ks', 'price_vat' => 2.0,
           'fetched_at' => '2026-07-30T08:00:00Z', 'category_guess' => 'ZAVESY' }
  HWC.create_proposals['p-redir'] = prop
  status, rec = HWC.create_from_demos!('p-redir')
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal(final, rec['demos_url'], 'ulozena je KONECNA adresa')
  NxTest.assert_equal('2026-07-30T08:00:00Z', rec['price_checked_at'],
                      'datum overenia = cas FETCHU, nie kliku na Vytvorit')
end

# --- KOV-B1: vyrobca a rada polozky ------------------------------------------

NxTest.test('KOV-B1 katalog: `manufacturer`/`series` su VOLITELNE a normalizuju sa') do
  rec, err = HWC.normalize_item(hwc_item('manufacturer' => ' Hettich ', 'series' => ' Sensys '))
  NxTest.assert_equal(nil, err)
  NxTest.assert_equal('Hettich', rec['manufacturer'], 'trim')
  NxTest.assert_equal('Sensys', rec['series'])
  bez = HWC.normalize_item(hwc_item)[0]
  NxTest.refute(bez.key?('manufacturer'), 'bez vyrobcu = kluc CHYBA (skrutky ho mat nemusia)')
  NxTest.refute(bez.key?('series'))
  prazdna = HWC.normalize_item(hwc_item('manufacturer' => 'Hettich', 'series' => '  '))[0]
  NxTest.refute(prazdna.key?('series'), 'prazdna rada sa neuklada')
  NxTest.assert(HWC::PATCHABLE.include?('manufacturer') && HWC::PATCHABLE.include?('series'),
                'obe polia su editovatelne patchom (whitelist je KONTRAKT)')
end

NxTest.test('KOV-B1 katalog: marker schemy je LAZY podla obsahu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  hwc_empty!
  NxTest.assert_equal(HWC::SCHEMA_BASE, HWC.schema_for([]), 'prazdny katalog')
  NxTest.assert_equal(HWC::SCHEMA_BASE, HWC.schema_for([hwc_item]), 'polozky bez vyrobcu')
  NxTest.assert_equal(HWC::SCHEMA_CLASSIFIED,
                      HWC.schema_for([hwc_item('manufacturer' => 'Hettich')]))
  NxTest.assert_equal(HWC::SCHEMA_CLASSIFIED,
                      HWC.schema_for([hwc_item('series' => 'Sensys')]), 'aj samotna rada')
  # ostry zapis: kym nikto vyrobcu nema, subor ostava citatelny pre STARSI plugin
  NxTest.assert_equal(:ok, HWC.create_item(hwc_item)[0])
  stored = JSON.parse(File.binread(HWC.path))
  NxTest.assert_equal(HWC::SCHEMA_BASE, stored['schema'], 'legacy obsah = schema 1')
  rec = HWC.find('104717')
  NxTest.assert_equal(:ok, HWC.patch_item('104717', { 'manufacturer' => 'Hettich' },
                                          row_rev: HWC.record_rev(rec))[0])
  stored2 = JSON.parse(File.binread(HWC.path))
  NxTest.assert_equal(HWC::SCHEMA_CLASSIFIED, stored2['schema'],
                      'prvy vyrobca marker POVYSI (starsi plugin subor odmietne)')
  NxTest.assert_equal(:ok, HWC.assess!, 'a nas vlastny zapis je VZDY citatelny')
end

NxTest.test('KOV-B1 katalog: ne-String vyrobca/rada = necitatelne polozky (read-only)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  hwc_empty!
  bad = HWC.normalize_item(hwc_item)[0].merge('manufacturer' => { 'id' => 7 })
  Noxun::Engine::JsonFileStore.write(HWC.path,
                                     'std' => HWC::STD, 'schema' => HWC::SCHEMA_CLASSIFIED,
                                     'items' => [bad])
  Noxun::Engine::JsonFileStore.invalidate(HWC.path)
  HWC.reset_state!
  NxTest.assert_equal(:read_only, HWC.assess!, 'novsi TVAR znameho pola sa NEOREZE ticho')
  NxTest.assert(HWC.state_reason.include?('nečitateľné'), HWC.state_reason)
end

NxTest.test('KOV-B1 katalog: hladanie indexuje vyrobcu aj radu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  hwc_empty!
  list = [HWC.normalize_item(hwc_item('manufacturer' => 'Hettich', 'series' => 'InnoTech Atira'))[0],
          HWC.normalize_item(hwc_item('item_code' => '999111', 'name_sk' => 'Skrutka',
                                      'category' => 'SPOJOVACI_MATERIAL'))[0]]
  NxTest.assert_equal(['104717'], HWC.search(list, 'hettich').map { |i| i['item_code'] },
                      'dotaz na vyrobcu najde polozku')
  NxTest.assert_equal(['104717'], HWC.search(list, 'atira').map { |i| i['item_code'] },
                      'aj na radu (diakritika/velkost sa normalizuje)')
  NxTest.assert_equal([], HWC.search(list, 'blum'), 'cudzi vyrobca nic nenajde')
end

NxTest.test('KOV-B1 katalog: vyrobca polozky musi byt v TAXONOMII') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  tax = Noxun::Engine::HardwareTaxonomy
  tax_path = tax.path
  before = (File.binread(tax_path) if File.exist?(tax_path))
  begin
    hwc_empty!
    FileUtils.rm_f(tax_path)
    Noxun::Engine::JsonFileStore.invalidate(tax_path)
    tax.reset_state!
    NxTest.assert_equal(:ok, HWC.create_item(hwc_item)[0], 'polozka BEZ vyrobcu prejde vzdy')
    status, msg = HWC.create_item(hwc_item('item_code' => '999222',
                                           'manufacturer' => 'Vymyslena'))
    NxTest.assert_equal(:invalid, status)
    NxTest.assert(msg.to_s.include?('Vymyslena'), msg.to_s)
    NxTest.assert_equal(:ok, HWC.create_item(hwc_item('item_code' => '999333',
                                                      'manufacturer' => 'Hettich',
                                                      'series' => 'Sensys'))[0],
                        'seedovana dvojica prejde')
    st2, msg2 = HWC.create_item(hwc_item('item_code' => '999444',
                                         'manufacturer' => 'Blum', 'series' => 'Sensys'))
    NxTest.assert_equal(:invalid, st2, 'rada musi patrit svojmu vyrobcovi')
    NxTest.assert(msg2.to_s.include?('Hettich'), msg2.to_s)
    # patch: kontroluje sa EFEKTIVNA dvojica (patch prebija ulozene)
    rec = HWC.find('999333')
    NxTest.assert_equal(:invalid,
                        HWC.patch_item('999333', { 'series' => 'Neznama' },
                                       row_rev: HWC.record_rev(rec))[0])
    NxTest.assert_equal(:ok,
                        HWC.patch_item('999333', { 'series' => 'Quadro' },
                                       row_rev: HWC.record_rev(rec))[0],
                        'ina rada TOHO ISTEHO vyrobcu prejde')
  ensure
    if before then File.binwrite(tax_path, before) else FileUtils.rm_f(tax_path) end
    FileUtils.rm_f("#{tax_path}.bak")
    Noxun::Engine::JsonFileStore.invalidate(tax_path)
    tax.reset_state!
  end
end

NxTest.test('KOV-B1 katalog: kontrola taxonomie bezi MIMO katalogoveho zamku') do
  # Taxonomia ma vlastny sidecar (`materials.lock`); vnorit ho do katalogoveho
  # by vyrobilo PORADIE zamkov a s nim riziko zaseknutia dvoch instancii.
  src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_catalog.rb'))
            .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  %w[create_item patch_item].each do |m|
    body = src[/^      def #{Regexp.escape(m)}.*?\n      end\n/m].to_s
    NxTest.assert(!body.empty?, "telo `#{m}` sa naslo")
    gate = body.index('taxonomy_refusal(')
    lock = body.index('with_lock do')
    NxTest.assert(gate && lock, "#{m}: kontrola aj zamok su v tele")
    NxTest.assert(gate < lock, "#{m}: taxonomia sa pyta PRED katalogovym zamkom")
  end
  refusal = src[/^      def taxonomy_refusal.*?\n      end\n/m].to_s
  NxTest.assert(refusal.include?('HardwareTaxonomy.read_only?'),
                'fail-closed: nad nekompatibilnou taxonomiou sa polozka s vyrobcom neulozi')
end
