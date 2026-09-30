# frozen_string_literal: true
# CENY-M2 [STAV] — vek rucnych cien dosiek a ABS v Rozpocte (server).
# Package: SYSTEM/archiv/bloky/CENY/PACKAGE_CENY_M2.md (§6.2, §7 bod 2).
#
# Co sa tu dokazuje:
#   R9   `freshness_item` pre dosku/ABS bez Demosu berie stav z M1b
#        (`Materials.manual_price_state` — jedina autorita): fresh/stale podla
#        prahu, nikdy/poskodeny/buduci datum/bez ceny = `manual`; 0 € je platna
#        cena; overenie NEVYZADUJE odkaz (O9); UNI a duplak = nil; Demos bajtovo
#        ako pred M2.
#   R10  pocty: `manual_hardware` LEN kovanie, `manual_materials` dosky+ABS,
#        `manual_pending` jednym priechodom (sucet je dosledok), `attention` bez
#        dvojiteho zapoctu.
#   R11  riadok nesie tu istu polozku ako scan (`price_check`), `demos_link` /
#        `product_link`; UNI, duplak a chybajuci zaznam nic.
#   R12  `PriceRefresh`: ciele len Demos, rucne na kontrolu bez UNI a bez fresh.
#   Integracia: sandbox katalog -> potvrdenie M1b -> Rozpocet `fresh`, cip
#        zmizne; zmena ceny bunkou -> spat `manual`.
require_relative '../helper' unless defined?(NxTest)
require_relative 'test_ceny_m1_links'
require_relative '../fixtures/ceny_m2_golden/fixture'

module CenyM2Stale
  E = Noxun::Engine
  B = E::Budget
  M = E::Materials
  P = E::PriceRefresh
  NOW = Time.utc(2026, 9, 30, 12)

  module_function

  def ago(days)
    (NOW - (days * 86_400)).iso8601
  end

  def sheet(over = {})
    { 'decor' => 'Číre', 'type' => 'SKLO', 'thickness' => 4.0, 'price_per_m2' => 41.5 }.merge(over)
  end

  def checked(days, over = {})
    sheet({ 'price_check_method' => 'manual', 'price_checked_at' => ago(days) }.merge(over))
  end

  def item(rec, days = 45, kind = 'sheet')
    B.freshness_item(kind, 'SK4', 'Sklo', rec, days, NOW)
  end

  def hw(over = {})
    { 'item_code' => 'K1', 'name_sk' => 'Noha', 'unit' => 'ks', 'price_eur_vat' => 2.0,
      'product_url' => 'https://supplier.example/k1' }.merge(over)
  end

  # Zakazka: sheets/edges/kovanie; `hw_items` = katalog kovania pouzity v rozpocte.
  def compute(sheets, edges = {}, hw_items = [], stale_days: 30)
    rows = sheets.keys.map { |mid| { 'material_id' => mid, 'length' => 600.0, 'width' => 500.0, 'quantity' => 1 } }
    edging = edges.keys.map { |aid| { 'abs_id' => aid, 'bm' => 5.0 } }
    hwx = { 'rows' => hw_items.map { |i| { 'code' => i['item_code'], 'name_sk' => i['name_sk'], 'unit' => i['unit'],
                                           'quantity' => 2, 'price_eur_vat' => i['price_eur_vat'] } } }
    sup = E::SupplierSettings.seed_supplier.merge('stale_days' => stale_days)
    B.compute({ rows: rows, edging: edging }, {}, sup, sheets: sheets, edges: edges,
              hardware_expansion: hwx, hardware_catalog: hw_items, now: NOW)
  end
end

# --- R9 ------------------------------------------------------------------------------

NxTest.test('CENY-M2 (R9): rucna doska — stav z M1b (den 29/30 pri prahu 30, prah 45, nikdy, poskodeny a buduci datum)') do
  c = CenyM2Stale
  f = c.item(c.checked(29), 30)
  NxTest.assert_equal(['fresh', 29, c.ago(29), 'manual', true], f.values_at('state', 'age_days', 'checked_at', 'price_check_method', 'manual_check'))
  NxTest.assert_equal(['stale', 30], c.item(c.checked(30), 30).values_at('state', 'age_days'), 'den 30 pri prahu 30 = na kontrolu')
  NxTest.assert_equal('fresh', c.item(c.checked(44), 45)['state'], 'prah z nastaveni (45)')
  NxTest.assert_equal('stale', c.item(c.checked(45), 45)['state'])
  never = c.item(c.sheet)
  NxTest.assert_equal(['manual', nil, nil, nil, false, false], never.values_at('state', 'checked_at', 'age_days', 'price_check_method',
                                                                               'price_missing', 'product_link'), 'nikdy neoverena')
  NxTest.assert_equal('manual', c.item(c.checked(3, 'price_checked_at' => 'nie-datum'))['state'], 'poskodeny datum')
  NxTest.assert_equal('manual', c.item(c.checked(-2))['state'], 'buduci datum')
  # Stav nepocita Rozpocet sam — zhoda s jedinou autoritou M1b.
  [c.checked(10), c.checked(50), c.sheet].each do |rec|
    st = c::M.manual_price_state(rec, stale_days: 45, now: c::NOW)
    mine = c.item(rec)
    NxTest.assert_equal(st['state'] == 'never' ? 'manual' : st['state'], mine['state'], 'stav = manual_price_state')
    NxTest.assert_equal(st['age_days'], mine['age_days'])
  end
end

NxTest.test('CENY-M2 (R9): bez ceny = manual + price_missing; 0 € platna; bez odkazu fresh (O9); ABS; UNI/duplak nil; Demos bajtovo') do
  c = CenyM2Stale
  miss = c.item(c.checked(3).reject { |k, _| k == 'price_per_m2' })
  NxTest.assert_equal(['manual', true], miss.values_at('state', 'price_missing'), 'bez ceny = na kontrolu, nikdy fresh')
  NxTest.assert_equal(['fresh', false], c.item(c.checked(3, 'price_per_m2' => 0)).values_at('state', 'price_missing'), '0 € je platna cena')
  NxTest.assert_equal(['fresh', false], c.item(c.checked(3)).values_at('state', 'product_link'), 'overenie bez odkazu plati (O9)')
  NxTest.assert_equal(true, c.item(c.checked(3, 'product_url' => 'https://sklo.example/p'))['product_link'])
  abs = { 'decor' => 'H1180', 'width' => 43.0, 'price_per_bm' => 0.39, 'price_check_method' => 'manual',
          'price_checked_at' => c.ago(5) }
  NxTest.assert_equal(%w[fresh edge], c.item(abs, 45, 'edge').values_at('state', 'kind'), 'ABS bez abs_id kluca (ciste volanie)')
  NxTest.assert_equal('fresh', c.item(abs.merge('abs_id' => 'E43'), 45, 'edge')['state'], 'ABS z katalogu (s abs_id)')
  NxTest.assert_equal(['manual', true], c.item(abs.reject { |k, _| k == 'price_per_bm' }, 45, 'edge').values_at('state', 'price_missing'))
  NxTest.assert(c.item(c.sheet('uni' => true)).nil?, 'UNI do scanu nepatri')
  NxTest.assert(c.item(c.sheet('source_material_id' => 'X')).nil?, 'duplak do scanu nepatri')
  demos = c.sheet('demos_url' => 'https://www.demos-trade.sk/p', 'price_checked_at' => c.ago(40))
  NxTest.assert_equal({ 'kind' => 'sheet', 'id' => 'SK4', 'label' => 'Sklo', 'state' => 'stale', 'checked_at' => c.ago(40),
                        'age_days' => 40, 'demos_url' => 'https://www.demos-trade.sk/p' }, c.item(demos, 30), 'Demos bajtovo')
  NxTest.assert_equal('unverified', c.item(c.sheet('demos_url' => 'https://www.demos-trade.sk/p'))['state'], 'Demos bez datumu')
end

# --- R10 ------------------------------------------------------------------------------

NxTest.test('CENY-M2 (R10): pocty — len material · len kovanie · zmiesane · stara rucna cena bez dvojiteho zapoctu') do
  c = CenyM2Stale
  only_mat = c.compute({ 'SK4' => c.sheet })['stale']['counts']
  NxTest.assert_equal([0, 1, 1, 1], only_mat.values_at('manual_hardware', 'manual_materials', 'manual_pending', 'attention'),
                      'len rucny material')
  only_hw = c.compute({}, {}, [c.hw])['stale']['counts']
  NxTest.assert_equal([1, 0, 1, 1], only_hw.values_at('manual_hardware', 'manual_materials', 'manual_pending', 'attention'),
                      'len rucne kovanie (dnesne cisla KOV-B)')
  mixed = c.compute({ 'SK4' => c.sheet }, { 'E43' => { 'decor' => 'X', 'width' => 43.0, 'price_per_bm' => 0.4 } }, [c.hw])
  cnt = mixed['stale']['counts']
  NxTest.assert_equal([1, 2, 3, 3], cnt.values_at('manual_hardware', 'manual_materials', 'manual_pending', 'attention'),
                      'zmiesane material + ABS + kovanie')
  NxTest.assert_equal(cnt['manual_hardware'] + cnt['manual_materials'], cnt['manual_pending'], 'sucet je dosledok')
  old = c.compute({ 'SK4' => c.checked(40) })['stale']
  NxTest.assert_equal([1, 0, 1, 1, 1], old['counts'].values_at('stale', 'manual', 'manual_materials', 'manual_pending', 'attention'),
                      'stara rucna cena sa v attention neráta dvakrat')
  NxTest.assert_equal([['sheet', 'SK4', 'stale', 40]], old['items'].map { |i| i.values_at('kind', 'id', 'state', 'age_days') })
  fresh = c.compute({ 'SK4' => c.checked(2) })['stale']
  NxTest.assert_equal([[], 0, 1], [fresh['items'], fresh['counts']['manual_pending'], fresh['counts']['fresh']], 'fresh vynechany')
end

# --- R11 ------------------------------------------------------------------------------

NxTest.test('CENY-M2 (R11): riadok nesie tu istu polozku ako scan; demos_link / product_link; UNI a chybajuci zaznam nic') do
  g = NxCenyM2Golden
  p = g.payload
  mats = p['sections'].find { |s| s['key'] == 'materials' }['rows']
  abs = p['sections'].find { |s| s['key'] == 'abs' }['rows']
  scan = p['stale']['items'].each_with_object({}) { |i, o| o["#{i['kind']}|#{i['id']}"] = i }
  %w[H25 NOF SK4 NOP].each do |mid|
    row = mats.find { |r| r['material_id'] == mid }
    NxTest.assert_equal(scan["sheet|#{mid}"], row['price_check'], "#{mid}: price_check = polozka scanu")
    NxTest.assert_equal(false, row['product_link'], "#{mid}: odkaz chyba")
    NxTest.refute(row.key?('demos_link'))
  end
  h18 = mats.find { |r| r['material_id'] == 'H18' }
  NxTest.assert_equal([true, false, false], [h18['demos_link'], h18.key?('product_link'), h18.key?('price_check')], 'Demos riadok')
  uni = mats.find { |r| r['material_id'] == 'UNI' }
  NxTest.refute(uni.key?('demos_link') || uni.key?('product_link') || uni.key?('price_check'), 'UNI nic')
  e43 = abs.find { |r| r['abs_id'] == 'E43' }
  NxTest.assert_equal(scan['edge|E43'], e43['price_check'], 'ABS: ta ista polozka')
  NxTest.assert_equal(true, abs.find { |r| r['abs_id'] == 'E23' }['demos_link'], 'ABS Demos')
  # Fresh rucna cena: v riadku ostava (datum), zo zoznamu vypadne.
  c = CenyM2Stale
  fp = c.compute({ 'SK4' => c.checked(2, 'product_url' => 'https://sklo.example/p') })
  row = fp['sections'].find { |s| s['key'] == 'materials' }['rows'].first
  NxTest.assert_equal(['fresh', true], [row['price_check']['state'], row['product_link']], 'fresh v riadku')
  NxTest.assert_equal([], fp['stale']['items'])
  # Chybajuci zaznam v katalogu.
  miss = CenyM2Stale::B.compute({ rows: [{ 'material_id' => 'ZZ', 'length' => 500.0, 'width' => 500.0, 'quantity' => 1 }],
                                  edging: [] }, {}, CenyM2Stale::E::SupplierSettings.seed_supplier, sheets: {}, now: CenyM2Stale::NOW)
  zz = miss['sections'].first['rows'].first
  NxTest.refute(zz.key?('product_link') || zz.key?('price_check') || zz.key?('demos_link'), 'chybajuci zaznam nic')
end

# --- R12 ------------------------------------------------------------------------------

NxTest.test('CENY-M2 (R12): PriceRefresh — ciele len Demos (rucny odkaz nikdy), rucne na kontrolu bez UNI a bez fresh') do
  c = CenyM2Stale
  sheets = { 'H18' => c.sheet('type' => 'DTDL', 'sheet_size' => [2800.0, 2070.0], 'demos_url' => 'https://www.demos-trade.sk/h',
                              'price_checked_at' => c.ago(40)),
             'SK4' => c.sheet('product_url' => 'https://www.demos-trade.sk/rucny-odkaz'),
             'OK1' => c.checked(2, 'decor' => 'Ok'),
             'UNI' => c.sheet('uni' => true) }
  p = c.compute(sheets)
  NxTest.assert_equal([%w[sheet H18]], c::P.targets_from_budget(p).map { |t| t.values_at('kind', 'id') }, 'len Demos ciel')
  NxTest.assert_equal([%w[sheet SK4 manual]], c::P.manual_from_budget(p).map { |t| t.values_at('kind', 'id', 'state') },
                      'rucne na kontrolu: bez UNI a bez cerstvo overenych')
end

# --- integracia s katalogom M1b -----------------------------------------------------

NxTest.test('CENY-M2 integracia: potvrdenie M1b -> Rozpocet fresh a cip zmizne; zmena ceny bunkou -> spat manual') do
  CenyM1.headless!
  ids = CenyM1.seed!
  m = CenyM2Stale::M
  b = CenyM2Stale::B
  run = lambda do
    sheets = m.sheets.each_with_object({}) { |s, o| o[s['material_id']] = s }
    rows = [{ 'material_id' => ids[:s25], 'length' => 600.0, 'width' => 500.0, 'quantity' => 1 }]
    b.compute({ rows: rows, edging: [] }, {}, Noxun::Engine::SupplierSettings.seed_supplier,
              sheets: sheets, edges: {}, now: Time.now.utc)
  end
  before = run.call
  NxTest.assert_equal([1, 'manual'], [before['stale']['counts']['manual_pending'], before['stale']['items'].first['state']],
                      'pred potvrdenim na kontrolu')
  rec = m.sheet(ids[:s25])
  st, info, = m.confirm_manual_price('sheet', ids[:s25], price: '179,90', basis: 'plate', row_rev: m.record_rev(rec))
  NxTest.assert_equal(:ok, st, "potvrdenie: #{info.inspect}")
  after = run.call
  row = after['sections'].first['rows'].first
  NxTest.assert_equal(['fresh', 0, []], [row['price_check']['state'], after['stale']['counts']['manual_pending'], after['stale']['items']],
                      'po potvrdeni fresh, cip zmizne')
  NxTest.assert_equal(179.9, row['cena_mj'], 'cena za platnu presne zadana')
  rec = m.sheet(ids[:s25])
  NxTest.assert_equal(:ok, m.patch_record('sheet', ids[:s25], { 'price_per_m2' => '32' }, row_rev: m.record_rev(rec))[0])
  again = run.call
  NxTest.assert_equal([1, 'manual'], [again['stale']['counts']['manual_pending'], again['stale']['items'].first['state']],
                      'zmena ceny bunkou vrati na kontrolu')
end
