# frozen_string_literal: true
# CENY-M1a — odkaz na produkt pri doske a ABS bez Demosu (SCHEMA 11).
#
# Co tato sada strazi (package CENY-M1, poziadavky [A]):
#   R1/R2  marker 11 vznika LEN obsahom (neprazdny odkaz), nezavisi od poradia
#          zaznamov (oprava pasce S2) a po zmazani odkazu neklesa;
#   R3/R4  normalizacia odkaz nesie cez kazdu zapisovu cestu, UNI ani duplak ho
#          nedostanu, sanitizer ma paritu s katalogom kovania (http aj https);
#   R5     whitelisty — duplak ho nezdedi, UNI ho odmietne, bunka ani editor
#          „Upraviť…" ho nemenia a server-owned polia neprijmu;
#   R6     formular variantu: platny / neplatny = nic nezapisane / prazdny =
#          zmazanie / Demos zamok / Demos vymazane + odkaz v jednom ulozeni /
#          podvrhnute server-owned polia strhnute;
#   R6b    formular drzi baseline z otvorenia — zmena inde + echo = konflikt;
#   R6c    kontrola aj zapis pod JEDNYM zamkom — konkurencny zapis medzi
#          dnesnou kontrolou a zamkom = konflikt, nic sa neprepise;
#   R7     `mat_product_open` otvara len cerstvy platny odkaz rucneho zaznamu,
#          URL od klienta neberie a NIC nezapisuje;
#   R8     payload `product_link` len pri rucnych zaznamoch, `row_rev` zo
#          suroveho zaznamu;
#   S15    starsi plugin (SCHEMA_CURRENT 10) katalog s markerom 11 len cita.
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog')
end

module CenyM1
  E = Noxun::Engine
  M = E::Materials
  S = E::JsonFileStore
  D = E::MaterialsDialog
  SHOP = 'https://shop.example.sk/dtdl-25?ref=noxun'
  DEMOS = 'https://www.demos-trade.sk/h1180-dtdl-18'

  module_function

  def headless!
    NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  end

  # Cerstvy katalog: seed (UNI) + dekor H1180 so 3 doskami a 2 paskami;
  # DTDL 18 a ABS 23/1 su viazane na Demos a nesu ODLOZENY rucny odkaz.
  def seed!
    NxTest.assert(NxTest.install_fresh_seed_catalog!)
    ok, res = M.add_decor_batch_v3(
      'decor' => 'H1180', 'decor_name' => 'Dub Halifax', 'manufacturer' => 'Egger',
      'type' => 'DTDL', 'grain' => 'length', 'color' => [150, 120, 90],
      'sheet_variants' => [{ 'type' => 'DTDL', 'thickness' => 18.0, 'structure' => 'ST37' },
                           { 'type' => 'DTDL', 'thickness' => 25.0, 'structure' => 'ST37' }],
      'edge_variants' => [{ 'width' => 43.0, 'thickness' => 0.8, 'structure' => 'ST37' },
                          { 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST37' }]
    )
    raise "seed H1180 zlyhal: #{res.inspect}" unless ok
    s18, s25 = res['sheets'].map { |id| M.sheet(id) }.sort_by { |s| s['thickness'] }
    e08, e10 = res['edges'].map { |id| M.edge(id) }.sort_by { |a| a['thickness'] }
    raise 'upsert' unless M.upsert_sheet(s25.merge('price_per_m2' => 31.0, 'sheet_size' => [2800.0, 2070.0],
                                                   'code' => '310418', 'supplier' => 'Drevocentrum'))
    raise 'upsert' unless M.upsert_sheet(s18.merge('price_per_m2' => 20.0, 'demos_url' => DEMOS,
                                                   'price_checked_at' => '2026-09-01T10:00:00Z',
                                                   'product_url' => 'https://odlozeny.example/p'))
    raise 'upsert' unless M.upsert_edge(e08.merge('price_per_bm' => 0.9, 'code' => 'ABS-08'))
    raise 'upsert' unless M.upsert_edge(e10.merge('price_per_bm' => 0.5, 'demos_url' => 'https://www.demos-trade.sk/abs-h1180',
                                                  'price_checked_at' => '2026-09-01T10:00:00Z',
                                                  'product_url' => 'https://odlozeny.example/abs'))
    { s18: s18['material_id'], s25: s25['material_id'], e08: e08['abs_id'], e10: e10['abs_id'] }
  end

  def raw
    JSON.parse(File.binread(M.path))
  end

  def bytes
    File.binread(M.path)
  end

  def marker
    raw['schema'].to_i
  end

  # Formular dosky presne v tvare, aky posiela `mdSaveSheet` (+ baseline).
  def sheet_form(id, over = {})
    s = M.sheet(id)
    { 'material_id' => id, 'catalog_schema' => M::SCHEMA_CURRENT, 'catalog_rev' => M.catalog_revision,
      'row_rev' => M.record_rev(s), 'decor' => s['decor'], 'type' => s['type'],
      'thickness' => s['thickness'].to_s, 'grain' => s['grain'],
      'price_per_m2' => s['price_per_m2'].nil? ? '' : s['price_per_m2'].to_s,
      'code' => s['code'].to_s, 'supplier' => s['supplier'].to_s,
      'demos_url' => s['demos_url'].to_s, 'family' => s['family'].to_s,
      'manufacturer' => s['manufacturer'].to_s, 'supplier_decor' => s['supplier_decor'].to_s,
      'allow_duplicate_code' => false }
      .merge(s['sheet_size'] ? { 'sheet_size' => s['sheet_size'] } : { 'clear_sheet_size' => true })
      .merge(over)
  end

  def edge_form(id, over = {})
    a = M.edge(id)
    { 'abs_id' => id, 'catalog_schema' => M::SCHEMA_CURRENT, 'catalog_rev' => M.catalog_revision,
      'row_rev' => M.record_rev(a), 'decor' => a['decor'], 'width' => a['width'].to_s,
      'thickness' => a['thickness'].to_s,
      'price_per_bm' => a['price_per_bm'].nil? ? '' : a['price_per_bm'].to_s,
      'code' => a['code'].to_s, 'supplier' => a['supplier'].to_s,
      'demos_url' => a['demos_url'].to_s, 'allow_duplicate_code' => false }.merge(over)
  end

  # Dispatch akcie sekcie; vrati odoslane JS retazce. Echo po zapise
  # (`after_catalog_change`) sa len zarata — jeho telo patri Studiu.
  def call(action, payload)
    out = []
    stub(D, :after_catalog_change, -> { out << 'ECHO' }) do
      D.dispatch(action, JSON.generate(payload), ->(s) { out << s })
    end
    out
  end

  def status_of(out)
    js = out.reverse.find { |s| s.start_with?('MD.setStatus(') }
    js && JSON.parse("[#{js.sub('MD.setStatus(', '').sub(/\)\z/, '')}]")
  end

  def stub(target, name, impl)
    old = target.method(name)
    target.define_singleton_method(name, &impl)
    yield
  ensure
    target.define_singleton_method(name, old)
  end

  def with_ui
    made_ui = !Object.const_defined?(:UI)
    Object.const_set(:UI, Module.new) if made_ui
    opened = []
    had = UI.respond_to?(:openURL)
    old = UI.method(:openURL) if had
    UI.define_singleton_method(:openURL) { |url| opened << url; true }
    yield opened
  ensure
    if had
      UI.define_singleton_method(:openURL, old)
    elsif !made_ui
      UI.singleton_class.send(:remove_method, :openURL)
    end
    Object.send(:remove_const, :UI) if made_ui
  end
end

# --- R1 / R2: marker 11 LEN obsahom, poradie, neklesa ------------------------

NxTest.test('CENY-M1a (R1): SCHEMA_PRODUCT_URL = 11 (CENY-M1b posunul SCHEMA_CURRENT na 12)') do
  NxTest.assert_equal(11, CenyM1::M::SCHEMA_PRODUCT_URL)
  NxTest.assert(CenyM1::M::SCHEMA_CURRENT >= CenyM1::M::SCHEMA_PRODUCT_URL, 'plugin pozna odkaz na produkt')
end

NxTest.test('CENY-M1a (R2): required_schema_for nezavisi od poradia zaznamov (pasca S2)') do
  m = CenyM1::M
  recs = {
    appearance: { 'appearance' => { 'version' => 1 } },
    uni: { 'uni' => true },
    demos: { 'demos_url' => 'https://www.demos-trade.sk/x' },
    product: { 'product_url' => 'https://shop.example/p' }
  }
  recs.values.permutation.each do |perm|
    NxTest.assert_equal(11, m.required_schema_for(perm, []), perm.map(&:keys).inspect)
    NxTest.assert_equal(11, m.required_schema_for([], perm), "ABS: #{perm.map(&:keys).inspect}")
  end
  without = recs.reject { |k, _| k == :product }.values
  without.permutation.each do |perm|
    NxTest.assert_equal(10, m.required_schema_for(perm, []), 'bez odkazu drzi 10 (vzhlad) v kazdom poradi')
  end
  NxTest.assert_equal(0, m.required_schema_for([{ 'product_url' => '  ' }], []),
                      'prazdny odkaz marker nezdviha')
end

NxTest.test('CENY-M1a (R1): marker 11 zdvihne az prvy ulozeny odkaz a po zmazani neklesa') do
  CenyM1.headless!
  ids = CenyM1.seed!
  # seed dal odlozeny odkaz na Demos zaznamy — zacneme od katalogu bez odkazov
  data = CenyM1.raw
  (data['sheets'] + data['edges']).each { |r| r.delete('product_url') }
  data['schema'] = 10
  File.binwrite(CenyM1::M.path, JSON.generate(data))
  CenyM1::S.invalidate(CenyM1::M.path)
  NxTest.assert(CenyM1::M.upsert_sheet(CenyM1::M.sheet(ids[:s25]).merge('code' => 'X1')))
  NxTest.assert_equal(10, CenyM1.marker, 'zapis bez odkazu marker nemeni (S1)')
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal(11, CenyM1.marker, 'prvy odkaz zdvihol marker')
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => ''))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.refute(CenyM1::M.sheet(ids[:s25]).key?('product_url'), 'odkaz zmazany')
  NxTest.assert_equal(11, CenyM1.marker, 'marker po zmazani posledneho odkazu NEKLESA')
end

# --- R3 / R4: normalizacia a sanitizer ---------------------------------------

NxTest.test('CENY-M1a (R3): normalize nesie platny odkaz, zahodi neplatny, UNI ani duplak ho nedostanu') do
  m = CenyM1::M
  base = { 'material_id' => 'X', 'decor' => 'D', 'type' => 'DTDL', 'thickness' => 18.0, 'group_id' => 'G' }
  NxTest.assert_equal('https://a.sk/p', m.normalize_sheet(base.merge('product_url' => ' https://a.sk/p '))['product_url'])
  NxTest.assert_equal('http://a.sk/p', m.normalize_sheet(base.merge('product_url' => 'http://a.sk/p'))['product_url'])
  NxTest.refute(m.normalize_sheet(base.merge('product_url' => 'ftp://a.sk/p')).key?('product_url'))
  NxTest.refute(m.normalize_sheet(base.merge('product_url' => 'https://a.sk/x y')).key?('product_url'))
  NxTest.refute(m.normalize_sheet(base.merge('uni' => true, 'uni_role' => 'body',
                                             'product_url' => 'https://a.sk/p')).key?('product_url'),
                'UNI pracovny material odkaz nema')
  NxTest.refute(m.normalize_sheet(base.merge('source_material_id' => 'Y', 'source_multiplier' => 2,
                                             'product_url' => 'https://a.sk/p')).key?('product_url'),
                'duplak sa nekupuje — odkaz patri zdroju')
  edge = { 'abs_id' => 'A', 'decor' => 'D', 'thickness' => 1.0, 'group_id' => 'G' }
  NxTest.assert_equal('https://a.sk/abs', m.normalize_edge(edge.merge('product_url' => 'https://a.sk/abs'))['product_url'])
  NxTest.assert_equal('https://a.sk/abs',
                      m.normalize_edge(edge.merge('demos_url' => CenyM1::DEMOS, 'product_url' => 'https://a.sk/abs'))['product_url'],
                      'Demos vazba odkaz NEMAZE — ostava odlozeny (O8)')
end

NxTest.test('CENY-M1a (R4): sanitize_product_url ma paritu s katalogom kovania') do
  m = CenyM1::M
  h = CenyM1::E::HardwareCatalog
  table = ['https://shop.sk/p', 'http://shop.sk/p', 'HTTPS://SHOP.SK/P', 'https://shop.sk/p?a=1&b=2',
           'https://shop.sk/p#detail', 'https://shop.sk:8443/p', '  https://shop.sk/p  ',
           'javascript:alert(1)', 'ftp://shop.sk/p', 'file:///C:/x', 'mailto:a@b.sk', 'data:text/html,x',
           '//shop.sk/p', 'https:///missing', "https://x.sk/a\nb", 'https://x.sk/a b', 'https://x.sk/"x',
           "https://x.sk/'x", 'https://x.sk/<x>', 'https://x.sk/\\x', 'www.shop.sk/p', '', '   ',
           nil, 3, {}, []]
  table.each do |raw|
    NxTest.assert_equal(h.sanitize_product_url(raw), m.sanitize_product_url(raw), "parita: #{raw.inspect}")
  end
  NxTest.assert_equal('https://shop.sk/p', m.sanitize_product_url('https://shop.sk/p'))
  NxTest.assert_equal('http://shop.sk/p', m.sanitize_product_url('http://shop.sk/p'), 'http aj https (D1)')
  NxTest.assert_equal(nil, m.sanitize_product_url('javascript:alert(1)'))
end

# --- R5: whitelisty -----------------------------------------------------------

NxTest.test('CENY-M1a (R5): duplak odkaz nezdedi, UNI ho odmietne, bunka ani editor ho nemenia') do
  m = CenyM1::M
  src = { 'material_id' => 'S', 'decor' => 'D', 'type' => 'DTDL', 'thickness' => 18.0,
          'product_url' => 'https://a.sk/p', 'demos_url' => CenyM1::DEMOS }
  dup = m.duplak_record_from(src, 2)
  NxTest.refute(dup.key?('product_url'), 'duplak odkaz nezdedi (S4)')
  NxTest.refute(dup.key?('demos_url'))
  uni = { 'uni' => true }
  NxTest.assert(m.uni_edit_error(uni, 'product_url' => 'https://a.sk/p'), 'UNI s odkazom = chyba (S5)')
  NxTest.assert_equal(nil, m.uni_edit_error(uni, 'product_url' => '  '), 'prazdny odkaz nie je zasah')
  NxTest.assert_equal({ 'sheet' => %w[code supplier price_per_m2 cp_nazov supplier_decor],
                        'edge' => %w[code supplier price_per_bm universal] }, m::PATCHABLE,
                      'bunka odkaz ani server-owned polia nemeni (S19)')
  NxTest.assert_equal(%w[material_id row_rev type thickness sheet_size structure code supplier price_per_m2],
                      m::SAVE_DECOR_SHEET_KEYS)
  NxTest.assert_equal(%w[abs_id row_rev width thickness structure code supplier price_per_bm],
                      m::SAVE_DECOR_EDGE_KEYS)
end

NxTest.test('CENY-M1a (R5): patch bunky s odkazom nic nezapise') do
  CenyM1.headless!
  ids = CenyM1.seed!
  s = CenyM1::M.sheet(ids[:s25])
  before = CenyM1.bytes
  st, = CenyM1::M.patch_record('sheet', ids[:s25], { 'product_url' => CenyM1::SHOP }, row_rev: CenyM1::M.record_rev(s))
  NxTest.assert_equal(:invalid, st)
  NxTest.assert_equal(before, CenyM1.bytes)
end

# --- R3: odkaz prezije kazdu merge-safe zapisovu cestu ---------------------

NxTest.test('CENY-M1a (R3): odkaz prezije bunku, editor, Demos apply, nazov, vyrobcu, premenovanie, vzhlad aj duplak sync') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e08], 'product_url' => 'https://abs.example/43'))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  keep = lambda do |why|
    NxTest.assert_equal(CenyM1::SHOP, m.sheet(ids[:s25])['product_url'], "doska po: #{why}")
    NxTest.assert_equal('https://abs.example/43', m.edge(ids[:e08])['product_url'], "ABS po: #{why}")
  end
  s = m.sheet(ids[:s25])
  NxTest.assert_equal(:ok, m.patch_record('sheet', ids[:s25], { 'code' => 'N1' }, row_rev: m.record_rev(s))[0])
  a = m.edge(ids[:e08])
  NxTest.assert_equal(:ok, m.patch_record('edge', ids[:e08], { 'price_per_bm' => '1.1' }, row_rev: m.record_rev(a))[0])
  keep.call('bunka')
  gid = m.sheet(ids[:s25])['group_id']
  rows = m.sheets.select { |x| x['group_id'] == gid }.map do |x|
    { 'material_id' => x['material_id'], 'row_rev' => m.record_rev(x), 'type' => x['type'],
      'thickness' => m.fmt_mm(x['thickness']),
      'sheet_size' => x['sheet_size'] ? x['sheet_size'].map { |v| m.fmt_mm(v) }.join('×') : '',
      'code' => x['code'].to_s, 'supplier' => x['supplier'].to_s,
      'price_per_m2' => x['material_id'] == ids[:s25] ? '33' : (x['price_per_m2'].nil? ? '' : m.fmt_mm(x['price_per_m2'])) }
  end
  st, info = m.save_decor('mode' => 'edit', 'group_id' => gid, 'base_rev' => m.catalog_revision,
                          'catalog_schema' => m::SCHEMA_CURRENT, 'decor' => 'H1180', 'decor_name' => 'Dub Halifax',
                          'manufacturer' => 'Egger', 'sheets' => rows, 'edges' => [])
  NxTest.assert_equal(:ok, st, info.inspect)
  NxTest.assert_equal(33.0, m.sheet(ids[:s25])['price_per_m2'])
  keep.call('editor Upraviť…')
  a = m.edge(ids[:e08])
  st, info = m.apply_demos_batch([{ 'kind' => 'edge', 'id' => ids[:e08], 'row_rev' => m.record_rev(a),
                                    'fields' => { 'price' => 1.25, 'demos_url' => 'https://www.demos-trade.sk/abs-43' } }],
                                 catalog_rev: m.catalog_revision)
  NxTest.assert_equal(:ok, st, info.inspect)
  NxTest.assert_equal('https://www.demos-trade.sk/abs-43', m.edge(ids[:e08])['demos_url'])
  keep.call('Demos apply (odkaz ostava odlozeny)')
  NxTest.assert(m.set_decor_name(gid, 'Dub Halifax prírodný')[0])
  NxTest.assert(m.set_decor_manufacturer('H1180', 'Egger AG', group_id: gid)[0])
  NxTest.assert(m.rename_decor('H1180', 'H1180X', group_id: gid)[0])
  keep.call('nazov, vyrobca, premenovanie')
  NxTest.assert(m.upsert_sheet_with_duplak_sync(m.sheet(ids[:s25]).merge('grain' => 'width')))
  keep.call('upsert so synchrom duplakov')
  _, scope = m.appearance_scope('sheet', ids[:s25])
  st, info = m.publish_appearance('sheet', ids[:s25], baseline: scope['baseline'], mode: 'color')
  NxTest.assert_equal(:ok, st, info.inspect)
  keep.call('zapis vzhladu')
end

# --- R6: formular variantu -----------------------------------------------------

NxTest.test('CENY-M1a (R6): formular dosky — platny, neplatny, nie text, prazdny, chybajuci kluc') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  before_price = m.sheet(ids[:s25])['price_per_m2']
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => " #{CenyM1::SHOP} "))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  rec = m.sheet(ids[:s25])
  NxTest.assert_equal(CenyM1::SHOP, rec['product_url'])
  NxTest.assert_equal(before_price, rec['price_per_m2'], 'ulozenie odkazu nemeni cenu')
  NxTest.refute(rec.key?('price_checked_at'), 'ulozenie odkazu nie je overenie ceny')
  ['ftp://shop.sk/p', 'www.shop.sk/p', 'https://shop.sk/a b', 'javascript:alert(1)', 'https:///x'].each do |bad|
    before = CenyM1.bytes
    out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => bad, 'code' => 'ZMENA'))
    NxTest.refute(out.include?('ECHO'), bad)
    NxTest.assert(out.include?('MD.formRejected("sheet")'),
                  "predrecenzia P3: odmietnuty odkaz formular otvori nanovo s rozpisanymi hodnotami (#{bad})")
    NxTest.assert_equal(['Odkaz nie je platná webová adresa — musí začínať http:// alebo https:// a nesmie mať medzery, úvodzovky, diakritiku ani znaky ako | { } ^.', true],
                        CenyM1.status_of(out), bad)
    NxTest.assert_equal(before, CenyM1.bytes, "neplatny odkaz = NIC sa nezapise (#{bad})")
  end
  [3, nil, { 'x' => 1 }].each do |bad|
    before = CenyM1.bytes
    out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => bad))
    NxTest.assert_equal(['Odkaz musí byť text.', true], CenyM1.status_of(out), bad.inspect)
    NxTest.assert_equal(before, CenyM1.bytes)
  end
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'code' => 'BEZ-KLUCA'))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal(CenyM1::SHOP, m.sheet(ids[:s25])['product_url'], 'chybajuci kluc = bez zmeny')
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => '   '))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.refute(m.sheet(ids[:s25]).key?('product_url'), 'prazdne pole = vedome zmazanie')
end

NxTest.test('CENY-M1a (R6, O8/C4): Demos zamok — odlozeny odkaz sa nezmeni ani nezmaze; v jednom ulozeni sa da vazba zrusit') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  %w[https://iny.example/p].push('').each do |val|
    before = CenyM1.bytes
    out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s18], 'product_url' => val))
    NxTest.assert_equal(['Položka je viazaná na Demos — ručný odkaz zadáš až po vymazaní Demos URL.', true],
                        CenyM1.status_of(out), val)
    NxTest.assert_equal(before, CenyM1.bytes)
  end
  # vlozenie Demos URL a zmena odkazu v jednom ulozeni: vysledna vazba zamyka
  before = CenyM1.bytes
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'demos_url' => 'https://www.demos-trade.sk/h1180-25',
                                                                 'product_url' => CenyM1::SHOP))
  NxTest.assert_equal('Položka je viazaná na Demos — ručný odkaz zadáš až po vymazaní Demos URL.',
                      CenyM1.status_of(out)[0])
  NxTest.assert_equal(before, CenyM1.bytes)
  # ten isty (odlozeny) odkaz pri Demos vazbe prejde — formular ho nemeni
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s18], 'product_url' => 'https://odlozeny.example/p',
                                                                 'code' => 'D18'))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal('https://odlozeny.example/p', m.sheet(ids[:s18])['product_url'])
  # vymazat Demos URL a vlozit odkaz v JEDNOM ulozeni
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s18], 'demos_url' => '', 'product_url' => CenyM1::SHOP))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  rec = m.sheet(ids[:s18])
  NxTest.refute(rec.key?('demos_url'), 'vazba zrusena')
  NxTest.refute(rec.key?('price_checked_at'), 'datum patril zrusenej vazbe')
  NxTest.assert_equal(CenyM1::SHOP, rec['product_url'])
  # ABS: rovnaky zamok
  before = CenyM1.bytes
  out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e10], 'product_url' => 'https://iny.example/abs'))
  NxTest.assert_equal('Položka je viazaná na Demos — ručný odkaz zadáš až po vymazaní Demos URL.',
                      CenyM1.status_of(out)[0])
  NxTest.assert_equal(before, CenyM1.bytes)
  out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e10], 'demos_url' => '', 'product_url' => 'https://iny.example/abs'))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal('https://iny.example/abs', m.edge(ids[:e10])['product_url'])
end

NxTest.test('CENY-M1a (R6): podvrhnute server-owned polia a ozdoby payloadu sa strhnu') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  spoof = { 'price_checked_at' => '2099-01-01T00:00:00Z', 'price_check_method' => 'manual',
            'product_link' => true, 'price_check' => { 'state' => 'fresh' }, 'label' => 'X',
            'row_label' => 'X', 'row_key' => 'X', 'image_file' => 'C:/x.png' }
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], spoof.merge('code' => 'S1')))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  rec = m.sheet(ids[:s25])
  NxTest.assert_equal('S1', rec['code'])
  (spoof.keys - ['label']).each { |k| NxTest.refute(rec.key?(k), "#{k} od klienta neprejde") }
  NxTest.refute(rec.key?('label'))
  # Demos zaznam: ulozeny datum ostava SERVEROVY, klientsky sa nezapise
  stamp = m.sheet(ids[:s18])['price_checked_at']
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s18], spoof.merge('product_url' => 'https://odlozeny.example/p')))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal(stamp, m.sheet(ids[:s18])['price_checked_at'], 'datum overenia NIKDY od klienta (S8/T20)')
  a_stamp = m.edge(ids[:e10])['price_checked_at']
  # CENY-M1b (D-148): zmena kodu pri Demos polozke datum rusi — tu sa kod
  # nemeni, takze datum ostava SERVEROVY (podvrhnuty sa nezapise).
  out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e10], spoof.merge('supplier' => '')))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal(a_stamp, m.edge(ids[:e10])['price_checked_at'])
  NxTest.refute(m.edge(ids[:e10]).key?('price_check_method'))
end

NxTest.test('CENY-M1a (R6): UNI a duplak odkaz formularom nedostanu') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  uni = m.sheets.find { |s| m.uni?(s) }
  before = CenyM1.bytes
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(uni['material_id'], 'product_url' => CenyM1::SHOP))
  NxTest.assert_equal(m.uni_edit_error(uni, 'product_url' => 'x'), CenyM1.status_of(out)[0])
  NxTest.assert_equal(before, CenyM1.bytes)
  st, dup = m.create_duplak_sheet(ids[:s25], 2)
  NxTest.assert_equal(:ok, st, dup.inspect)
  dup_id = m.sheets.find { |s| s['source_material_id'] == ids[:s25] }['material_id']
  before = CenyM1.bytes
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(dup_id, 'product_url' => CenyM1::SHOP))
  NxTest.refute(out.include?('ECHO'))
  NxTest.assert_equal(before, CenyM1.bytes)
end

# --- R6b: baseline z otvorenia ------------------------------------------------

NxTest.test('CENY-M1a (R6b): otvorena ceruzka → Demos apply alebo bunka inde → echo → ulozenie odkazu = konflikt (doska aj ABS)') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  # doska: formular otvoreny nad starym stavom, potom Demos apply zmeni cenu a vazbu
  form = CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP)
  s = m.sheet(ids[:s25])
  st, info = m.apply_demos_batch([{ 'kind' => 'sheet', 'id' => ids[:s25], 'row_rev' => m.record_rev(s),
                                    'fields' => { 'price' => 44.0, 'demos_url' => 'https://www.demos-trade.sk/h1180-25' } }],
                                 catalog_rev: m.catalog_revision)
  NxTest.assert_equal(:ok, st, info.inspect)
  # echo omladi globalny catalog_rev — klient ho posle cerstvy, baseline riadku NIE
  before = CenyM1.bytes
  out = CenyM1.call('update_sheet', form.merge('catalog_rev' => m.catalog_revision))
  NxTest.assert(out.any? { |x| x == %(MD.formConflict("sheet", #{ids[:s25].to_json})) }, out.inspect)
  NxTest.assert(out.any? { |x| x.start_with?('MD.setCatalog(') }, 'cerstvy katalog ide PRED znovuotvorenim')
  NxTest.assert(out.index { |x| x.start_with?('MD.setCatalog(') } < out.index { |x| x.start_with?('MD.formConflict(') })
  NxTest.assert_equal(['Položka sa medzitým zmenila — formulár sa otvoril s aktuálnymi údajmi.', true], CenyM1.status_of(out))
  NxTest.assert_equal(before, CenyM1.bytes, 'nic sa nezapisalo')
  rec = m.sheet(ids[:s25])
  NxTest.assert_equal(44.0, rec['price_per_m2'], 'cena sa nevratila do stavu z otvorenia')
  NxTest.assert_equal('https://www.demos-trade.sk/h1180-25', rec['demos_url'], 'ani Demos vazba')
  # ABS: zmena bunky inde
  form = CenyM1.edge_form(ids[:e08], 'product_url' => 'https://abs.example/43')
  a = m.edge(ids[:e08])
  NxTest.assert_equal(:ok, m.patch_record('edge', ids[:e08], { 'price_per_bm' => '2.5' }, row_rev: m.record_rev(a))[0])
  before = CenyM1.bytes
  out = CenyM1.call('update_edge', form.merge('catalog_rev' => m.catalog_revision))
  NxTest.assert(out.include?(%(MD.formConflict("edge", #{ids[:e08].to_json}))), out.inspect)
  NxTest.assert_equal(before, CenyM1.bytes)
  NxTest.assert_equal(2.5, m.edge(ids[:e08])['price_per_bm'])
  NxTest.refute(m.edge(ids[:e08]).key?('product_url'))
  # chybajuci baseline (stary klient) = konflikt, nie tichy zapis
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'row_rev' => '', 'code' => 'Q'))
  NxTest.assert(out.any? { |x| x.start_with?('MD.formConflict(') }, out.inspect)
  NxTest.refute(m.sheet(ids[:s25])['code'] == 'Q')
end

# --- R6c: kontrola aj zapis pod jednym zamkom ---------------------------------

NxTest.test('CENY-M1a (R6c): konkurencny zapis medzi dnesnou kontrolou a zamkom = konflikt (doska aj ABS)') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  [['update_sheet', 'sheets', 'material_id', ids[:s25], CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP)],
   ['update_edge', 'edges', 'abs_id', ids[:e08], CenyM1.edge_form(ids[:e08], 'product_url' => 'https://abs.example/43')]]
    .each do |action, listk, idk, id, form|
    orig = m.method(:with_catalog_lock)
    injected = false
    # Druha instancia SketchUpu zapise PRESNE v okamihu, ked prva ide po zamok
    # (po dnesnej kontrole revizie, pred ziskanim zamku upsertom).
    m.define_singleton_method(:with_catalog_lock) do |&blk|
      unless injected
        injected = true
        data = JSON.parse(File.binread(m.path))
        rec = data[listk].find { |r| r[idk] == id }
        rec['product_url'] = 'https://konkurent.example/p'
        rec[listk == 'edges' ? 'price_per_bm' : 'price_per_m2'] = 77.0
        File.binwrite(m.path, JSON.generate(data))
        CenyM1::S.invalidate(m.path)
      end
      orig.call(&blk)
    end
    begin
      out = CenyM1.call(action, form)
    ensure
      m.define_singleton_method(:with_catalog_lock, orig)
    end
    NxTest.assert(injected, 'konkurencny zapis sa vlozil')
    NxTest.assert(out.any? { |x| x.start_with?('MD.formConflict(') }, "#{action}: #{out.inspect}")
    rec = listk == 'edges' ? m.edge(id) : m.sheet(id)
    NxTest.assert_equal('https://konkurent.example/p', rec['product_url'], "#{action}: konkurencny odkaz sa neprepisal")
    NxTest.assert_equal(77.0, rec[listk == 'edges' ? 'price_per_bm' : 'price_per_m2'], "#{action}: ani cena")
  end
end

NxTest.test('CENY-M1a (R6c): zdrojova brana — revizia sa porovnava az pod zamkom') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog.rb'), encoding: 'UTF-8')
  %w[sheet edge].each do |k|
    handler = src[/def handle_save_#{k}\(payload\).*?\n        end\n/m].to_s
    NxTest.assert(handler.include?("Materials.with_catalog_lock { save_#{k}_locked(data) }"), "#{k}: telo pod zamkom")
    NxTest.refute(handler.include?('catalog_write_ok?'), "#{k}: ziadna kontrola revizie mimo zamku")
    body = src[/def save_#{k}_locked\(data\).*?\n        end\n/m].to_s
    NxTest.assert(body.include?('JsonFileStore.invalidate(Materials.path)'), "#{k}: cerstvy disk pod zamkom")
    NxTest.assert(body.include?('Materials.record_rev(existing)'), "#{k}: baseline riadku pod zamkom")
  end
end

# --- R7: otvorenie odkazu -------------------------------------------------------

NxTest.test('CENY-M1a (R7): mat_product_open otvori cerstvy odkaz rucneho zaznamu a NIC nezapise') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => 'https://stary.example/p'))
  CenyM1.with_ui do |opened|
    # medzitym niekto odkaz zmenil — otvara sa CERSTVY zaznam, nie echo klienta
    CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP))
    before = CenyM1.bytes
    out = CenyM1.call('mat_product_open', 'kind' => 'sheet', 'id' => ids[:s25], 'url' => 'javascript:evil()')
    NxTest.assert_equal([CenyM1::SHOP], opened, 'server nepouzije URL klienta')
    NxTest.assert_equal([], out.select { |x| x.start_with?('MD.setStatus(') })
    NxTest.assert_equal(before, CenyM1.bytes, 'otvorenie nic nezapisuje')
    uni = m.sheets.find { |s| m.uni?(s) }
    [['sheet', ids[:s18]], ['edge', ids[:e10]], ['sheet', uni['material_id']], ['sheet', 'NEEXISTUJE'],
     ['edge', ids[:e08]], ['nieco', ids[:s25]]].each do |kind, id|
      out = CenyM1.call('mat_product_open', 'kind' => kind, 'id' => id)
      NxTest.assert_equal(1, opened.length, "#{kind} #{id}: Demos/UNI/chybajuci/bez odkazu sa neotvori")
      NxTest.assert_equal(['Odkaz sa medzitým zmenil alebo chýba — katalóg sa obnovil.', true], CenyM1.status_of(out))
      NxTest.assert(out.any? { |x| x.start_with?('MD.setCatalog(') }, 'katalog sa obnovi')
      NxTest.assert_equal(before, CenyM1.bytes)
    end
    # poskodeny ulozeny odkaz (rucny zapis do suboru) sa neotvori
    data = CenyM1.raw
    data['sheets'].find { |s| s['material_id'] == ids[:s25] }['product_url'] = 'file:///C:/Windows'
    File.binwrite(m.path, JSON.generate(data))
    CenyM1::S.invalidate(m.path)
    CenyM1.call('mat_product_open', 'kind' => 'sheet', 'id' => ids[:s25])
    NxTest.assert_equal(1, opened.length, 'neplatny ulozeny odkaz sa neotvori')
  end
end

NxTest.test('CENY-M1a (R7): mat_product_open je v uzavretom whiteliste a nezraza sa s inymi sekciami') do
  acts = CenyM1::D::SECTION_ACTIONS
  NxTest.assert(acts.include?('mat_product_open'))
  others = []
  others += CenyM1::E::HardwareCatalogDialog::SECTION_ACTIONS if defined?(CenyM1::E::HardwareCatalogDialog)
  others += CenyM1::E::ApplianceDialog::SECTION_ACTIONS if defined?(CenyM1::E::ApplianceDialog)
  others += CenyM1::E::RulesDialog::SECTION_ACTIONS if defined?(CenyM1::E::RulesDialog)
  others += CenyM1::E::TemplatesDialog::SECTION_ACTIONS if defined?(CenyM1::E::TemplatesDialog)
  NxTest.assert((acts & others).empty?, "kolizia: #{(acts & others).inspect}")
end

# --- R8: payload katalogu --------------------------------------------------------

NxTest.test('CENY-M1a (R8): product_link len pri rucnych zaznamoch, row_rev zo suroveho zaznamu') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP))
  st, = m.create_duplak_sheet(ids[:s25], 2)
  NxTest.assert_equal(:ok, st)
  pay = CenyM1::D.full_catalog_payload
  row = ->(list, key, id) { pay[list].find { |r| r[key] == id } }
  s25 = row.call('sheets', 'material_id', ids[:s25])
  NxTest.assert_equal(true, s25['product_link'])
  NxTest.assert_equal(m.record_rev(m.sheet(ids[:s25])), s25['row_rev'], 'row_rev zo SUROVEHO zaznamu')
  NxTest.refute(row.call('sheets', 'material_id', ids[:s18]).key?('product_link'), 'Demos riadok ikonu odkazu nema')
  NxTest.assert_equal(false, row.call('edges', 'abs_id', ids[:e08])['product_link'], 'chybajuci odkaz = jantar')
  NxTest.refute(row.call('edges', 'abs_id', ids[:e10]).key?('product_link'))
  uni = m.sheets.find { |s| m.uni?(s) }
  NxTest.refute(row.call('sheets', 'material_id', uni['material_id']).key?('product_link'), 'UNI bez ikony')
  dup = m.sheets.find { |s| s['source_material_id'] == ids[:s25] }
  NxTest.refute(row.call('sheets', 'material_id', dup['material_id']).key?('product_link'), 'duplak bez ikony')
end

# --- predrecenzia: odpovede formulara variantu (P2) a parita odkazu (P3) --------

NxTest.test('CENY-M1a (predrecenzia P3): server a klient maju tu istu tabulku platnosti odkazu') do
  path = File.join(NxTest::ROOT, 'tests', 'fixtures', 'ceny_m1_product_urls.json')
  rows = JSON.parse(File.read(path, encoding: 'UTF-8'))['rows']
  NxTest.assert(rows.length >= 40)
  rows.each do |raw, valid|
    NxTest.assert_equal(valid, !CenyM1::M.sanitize_product_url(raw).nil?, "server: #{raw.inspect}")
  end
end

NxTest.test('CENY-M1a (predrecenzia P3): odmietnuty odkaz ABS tiez formular otvori nanovo, nic nezapise') do
  CenyM1.headless!
  ids = CenyM1.seed!
  before = CenyM1.bytes
  out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e08], 'product_url' => 'https://obchod.sk/dvierka|biela',
                                                               'price_per_bm' => '9.9'))
  NxTest.assert(out.include?('MD.formRejected("edge")'), out.inspect)
  NxTest.assert_equal(CenyM1::D::PRODUCT_URL_BAD_MSG, CenyM1.status_of(out)[0])
  NxTest.assert(out.index('MD.formRejected("edge")') < out.index { |x| x.start_with?('MD.setStatus(') },
                'znovuotvorenie PRED hlaskou (hlaska ostava viditelna)')
  NxTest.assert_equal(before, CenyM1.bytes)
  # Demos zamok (pretek — klient zamknute pole neposiela) ide tou istou cestou
  out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e10], 'product_url' => 'https://iny.example/abs'))
  NxTest.assert(out.include?('MD.formRejected("edge")'), out.inspect)
end

NxTest.test('CENY-M1a (predrecenzia P2): duplicitny kod — formular posle hlasku a MD.flagDuplicateCode, potvrdenie ulozi') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  before = CenyM1.bytes
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s18], 'code' => '310418', 'supplier' => 'Drevocentrum',
                                                                 'product_url' => 'https://odlozeny.example/p'))
  NxTest.refute(out.include?('ECHO'))
  NxTest.assert(out.include?('MD.flagDuplicateCode("sheet")'), out.inspect)
  msg, err = CenyM1.status_of(out)
  NxTest.assert(err)
  NxTest.assert(msg.include?('Kód „310418“ už používa 1×') && msg.include?(ids[:s25]) &&
                msg.include?('Ulož znova pre potvrdenie duplicity.'), msg)
  NxTest.assert_equal(before, CenyM1.bytes, 'bez potvrdenia sa nic nezapise')
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s18], 'code' => '310418', 'supplier' => 'Drevocentrum',
                                                                 'product_url' => 'https://odlozeny.example/p',
                                                                 'allow_duplicate_code' => true))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal('310418', m.sheet(ids[:s18])['code'])
  # ABS
  before = CenyM1.bytes
  out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e10], 'code' => 'ABS-08'))
  NxTest.assert(out.include?('MD.flagDuplicateCode("edge")'), out.inspect)
  NxTest.assert(CenyM1.status_of(out)[0].include?('Kód „ABS-08“ už používa 1×'))
  NxTest.assert_equal(before, CenyM1.bytes)
end

NxTest.test('CENY-M1a (predrecenzia P2): katalog len na citanie — formular povie dovod a obnovi katalog, nic nezapise') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  before = CenyM1.bytes
  begin
    m.instance_variable_set(:@catalog_state, :read_only)
    m.instance_variable_set(:@catalog_state_reason, 'testovaci dovod')
    [['update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP)],
     ['update_edge', CenyM1.edge_form(ids[:e08], 'product_url' => CenyM1::SHOP)]].each do |action, form|
      out = CenyM1.call(action, form)
      NxTest.refute(out.include?('ECHO'), action)
      NxTest.assert_equal([m.catalog_read_only_message, true], CenyM1.status_of(out), action)
      NxTest.assert(m.catalog_read_only_message.include?('testovaci dovod'))
      NxTest.assert(out.any? { |x| x.start_with?('MD.setCatalog(') }, "#{action}: UI sa vrati podla servera")
      NxTest.assert_equal(before, CenyM1.bytes, action)
    end
  ensure
    m.reset_catalog_state!
  end
end

NxTest.test('CENY-M1a (predrecenzia P2): schema sa overuje znova POD zamkom — novsi marker medzitym = odmietnutie') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  original = CenyM1.bytes
  [['update_sheet', 'sheets', 'material_id', ids[:s25], CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP)],
   ['update_edge', 'edges', 'abs_id', ids[:e08], CenyM1.edge_form(ids[:e08], 'product_url' => CenyM1::SHOP)]]
    .each do |action, _listk, _idk, id, form|
    File.binwrite(m.path, original)
    CenyM1::S.invalidate(m.path)
    orig = m.method(:with_catalog_lock)
    injected = nil
    # Pred-zamkova kontrola `schema_ok?` presla (marker 11); novsi plugin v inej
    # instancii zdvihne marker PRESNE pred ziskanim zamku.
    m.define_singleton_method(:with_catalog_lock) do |&blk|
      unless injected
        data = JSON.parse(File.binread(m.path))
        data['schema'] = m::SCHEMA_CURRENT + 1
        File.binwrite(m.path, JSON.generate(data))
        CenyM1::S.invalidate(m.path)
        injected = File.binread(m.path)
      end
      orig.call(&blk)
    end
    begin
      out = CenyM1.call(action, form)
    ensure
      m.define_singleton_method(:with_catalog_lock, orig)
    end
    NxTest.assert(injected, 'novsi marker sa vlozil')
    NxTest.refute(out.include?('ECHO'), action)
    NxTest.assert_equal(['Katalóg je v novom formáte — obnov Štúdio (Obnoviť) a potom ulož.', true],
                        CenyM1.status_of(out), action)
    NxTest.assert(out.any? { |x| x.start_with?('MD.setCatalog(') }, action)
    NxTest.assert_equal(injected, CenyM1.bytes, "#{action}: po vlozeni sa uz nic nezapisalo")
    NxTest.refute(JSON.parse(CenyM1.bytes)[action == 'update_edge' ? 'edges' : 'sheets']
                    .find { |r| r[action == 'update_edge' ? 'abs_id' : 'material_id'] == id }.key?('product_url'))
  end
ensure
  File.binwrite(m.path, original) if original
  CenyM1::S.invalidate(m.path) if m
end

# --- S15: starsi plugin -----------------------------------------------------------

NxTest.test('CENY-M1a (S15): starsi plugin (SCHEMA_CURRENT 10) katalog s markerom 11 len cita') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM1::M
  CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'product_url' => CenyM1::SHOP))
  NxTest.assert_equal(11, CenyM1.marker)
  current = m::SCHEMA_CURRENT
  before = CenyM1.bytes
  begin
    m.send(:remove_const, :SCHEMA_CURRENT)
    m.const_set(:SCHEMA_CURRENT, m::SCHEMA_APPEARANCE)
    state, reason = m.assess_catalog!
    NxTest.assert_equal(:read_only, state, 'novsi marker = read-only')
    NxTest.assert(reason.to_s.include?('11'), reason.inspect)
    NxTest.refute(m.schema_write_allowed?(10))
    NxTest.refute(m.write(m.load), 'zapis starsieho pluginu odmietnuty')
    NxTest.assert_equal(before, CenyM1.bytes, 'odkaz sa nestratil')
    NxTest.assert_equal(CenyM1::SHOP, m.sheet(ids[:s25])['product_url'], 'citanie bezi')
  ensure
    m.send(:remove_const, :SCHEMA_CURRENT)
    m.const_set(:SCHEMA_CURRENT, current)
    m.reset_catalog_state!
  end
end
