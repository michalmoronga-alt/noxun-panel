# frozen_string_literal: true
# V0.6 E-a: ROZPOCET — cisty vypocet (core/budget.rb) + data zakazky
# (core/budget_store.rb). Kontrakty z auditu: montaz LEN raz, duplaky podla
# poctu kusov, fallback formatu, nezname ceny nikdy ako 0, zaokruhlenie brutto,
# priorita override nad rezimom, vek cien len nad POUZITYMI polozkami.
require_relative '../helper' unless defined?(NxTest)

module NxBudget
  module_function

  def bd
    Noxun::Engine::Budget
  end

  def bs
    Noxun::Engine::BudgetStore
  end

  def settings
    Noxun::Engine::SupplierSettings.seed_supplier
  end

  # --- katalogove mapy -----------------------------------------------------

  def sheets
    {
      'DTDL18' => { 'material_id' => 'DTDL18', 'decor' => 'K009 PW', 'type' => 'DTDL',
                    'thickness' => 18.0, 'price_per_m2' => 12.5, 'sheet_size' => [2800.0, 2070.0],
                    'code' => 'K009', 'supplier' => 'Demos',
                    'demos_url' => 'https://demos-trade.sk/k009',
                    'price_checked_at' => '2026-08-01T10:00:00Z' },
      'PD38' => { 'material_id' => 'PD38', 'decor' => 'F206', 'type' => 'PD',
                  'thickness' => 38.0, 'price_per_m2' => 40.0, 'sheet_size' => [4100.0, 600.0],
                  'demos_url' => 'https://demos-trade.sk/f206',
                  'price_checked_at' => '2026-01-02T10:00:00Z' }, # stara cena
      'BEZCENY' => { 'material_id' => 'BEZCENY', 'decor' => 'Bez ceny', 'type' => 'DTDL',
                     'thickness' => 18.0 }, # bez ceny aj bez formatu
      'NEPOUZITY' => { 'material_id' => 'NEPOUZITY', 'decor' => 'Neposkvrnený', 'type' => 'DTDL',
                       'thickness' => 18.0, 'price_per_m2' => 9.0, 'sheet_size' => [2800.0, 2070.0],
                       'demos_url' => 'https://demos-trade.sk/x', 'price_checked_at' => '2020-01-01T00:00:00Z' }
    }
  end

  def edges
    { 'ABS_K009_10' => { 'abs_id' => 'ABS_K009_10', 'decor' => 'K009 PW', 'thickness' => 1.0,
                         'width' => 23.0, 'price_per_bm' => 0.55 } }
  end

  # --- BOM fixture ---------------------------------------------------------
  # DTDL18: 20 x (2000x500) = 20 m2 + duplak 3 x (1000x500) x2 = 3 m2 -> 23 m2
  # PD38:   1 x (4100x600) = 2,46 m2   |  BEZCENY: 1 x (1000x1000) = 1 m2
  def bom
    { rows: [
        { 'material_id' => 'DTDL18', 'length' => 2000.0, 'width' => 500.0, 'quantity' => 20 },
        { 'material_id' => 'DUP36', 'length' => 1000.0, 'width' => 500.0, 'quantity' => 3,
          'material_source' => { 'material_id' => 'DTDL18', 'multiplier' => 2 } },
        { 'material_id' => 'PD38', 'length' => 4100.0, 'width' => 600.0, 'quantity' => 1 },
        { 'material_id' => 'BEZCENY', 'length' => 1000.0, 'width' => 1000.0, 'quantity' => 1 }
      ],
      edging: [{ 'abs_id' => 'ABS_K009_10', 'bm' => 100.0, 'edges' => 40 }] }
  end

  def hardware_expansion
    { 'rows' => [
      { 'code' => 'H100', 'quantity' => 10, 'name_sk' => 'Záves Sensys', 'category' => 'ZAVES',
        'unit' => 'ks', 'price_eur_vat' => 3.5, 'subtotal_eur_vat' => 35.0, 'missing' => false },
      { 'code' => 'X999', 'quantity' => 4, 'name_sk' => nil, 'unit' => nil,
        'price_eur_vat' => nil, 'subtotal_eur_vat' => nil, 'missing' => true }
    ], 'unmapped' => [], 'summary' => { 'unknown_prices' => 1 } }
  end

  def hardware_catalog
    [{ 'item_code' => 'H100', 'name_sk' => 'Záves Sensys', 'category' => 'ZAVES', 'unit' => 'ks',
       'price_eur_vat' => 3.5, 'supplier' => 'Demos', 'demos_url' => 'https://demos-trade.sk/h100' }]
  end

  def state(over = {})
    { 'mode' => 'standard', 'overrides' => {}, 'std_multipliers' => {}, 'viz_m2' => nil,
      'custom_items' => [], 'appliances' => [], 'appliances_included' => false }.merge(over)
  end

  def compute(state_over = {}, settings_over = {}, opts = {})
    sup = settings
    settings_over.each { |k, v| sup[k] = v }
    bd.compute(bom, state(state_over), sup,
               sheets: sheets, edges: edges,
               hardware_expansion: hardware_expansion, hardware_catalog: hardware_catalog,
               now: Time.utc(2026, 8, 6), **opts)
  end

  def section(payload, key)
    payload['sections'].find { |s| s['key'] == key }
  end

  def row(payload, section_key, row_key)
    section(payload, section_key)['rows'].find { |r| r['key'] == row_key }
  end

  # Fake model pre BudgetStore: dict + pocitadlo undo operacii.
  class FakeModel < NxTest::FakeEntity
    attr_reader :ops, :committed, :aborted

    def initialize
      super
      @ops = []
      @committed = 0
      @aborted = 0
    end

    def start_operation(name, _disable_ui = false)
      @ops << name
      true
    end

    def commit_operation
      @committed += 1
      true
    end

    def abort_operation
      @aborted += 1
      true
    end
  end
end

# ============================ SEKCIE A PORADIE ==============================

NxTest.test('budget: sekcie v zavaznom poradi (spotrebice predposledne, zaokruhlenie za nimi)') do
  p = NxBudget.compute
  NxTest.assert_equal(%w[materials abs hardware services standard_rows custom appliances rounding],
                      p['sections'].map { |s| s['key'] })
end

NxTest.test('budget: material — cele platne x cena za platnu (€/m2 x plocha platne)') do
  p = NxBudget.compute
  r = NxBudget.row(p, 'materials', 'material:DTDL18')
  # 23 m2 -> count_max 5,0 -> 5 celych platni; 12,50 €/m2 x 5,796 m2 = 72,45 €/platna
  NxTest.assert_equal(5, r['mnozstvo'])
  NxTest.assert_equal('PLATŇA', r['mj'])
  NxTest.assert_close(72.45, r['cena_mj'], 0.01)
  NxTest.assert_close(362.25, r['spolu'], 0.01)
  NxTest.assert_equal('K009', r['kod'])
  NxTest.assert_equal('Demos', r['dodavatel'])
  NxTest.refute(r['price_missing'])
end

NxTest.test('budget: duplak sa preleje do ZDROJOVEHO materialu (cena na nakupny material)') do
  p = NxBudget.compute
  NxTest.assert(NxBudget.row(p, 'materials', 'material:DUP36').nil?,
                'duplakovy material nesmie mat vlastny riadok — kupuje sa zdroj')
  r = NxBudget.row(p, 'materials', 'material:DTDL18')
  NxTest.assert_close(23.0, r['m2'], 0.01, '20 m2 vlastnych + 3 m2 duplakov (uz x2)')
end

NxTest.test('budget: chybajuci format platne = fallback + priznak estimated (audit 3)') do
  p = NxBudget.compute
  r = NxBudget.row(p, 'materials', 'material:BEZCENY')
  NxTest.assert_equal(true, r['estimated'])
  NxTest.assert(r['poznamka'].include?('2800×2070'), "poznamka ma priznat fallback: #{r['poznamka']}")
  NxTest.assert(r['price_missing'], 'material bez ceny = riadok bez ceny')
  NxTest.assert(r['spolu'].nil?, 'nezadana cena NIKDY nie je 0')
end

NxTest.test('budget: ABS — bm + rezerva zo settings, cena €/bm') do
  p = NxBudget.compute
  r = NxBudget.row(p, 'abs', 'abs:ABS_K009_10')
  NxTest.assert_close(110.0, r['mnozstvo'], 0.01, '100 bm + 10 %')
  NxTest.assert_equal('BM', r['mj'])
  NxTest.assert_close(60.5, r['spolu'], 0.01)
  p20 = NxBudget.compute({}, 'abs_reserve_pct' => 20.0)
  NxTest.assert_close(120.0, NxBudget.row(p20, 'abs', 'abs:ABS_K009_10')['mnozstvo'], 0.01)
end

NxTest.test('budget: kovanie — prebera expanziu setov, neznamy kod je riadok bez ceny') do
  p = NxBudget.compute
  hw = NxBudget.section(p, 'hardware')
  NxTest.assert_close(35.0, hw['subtotal'], 0.01, 'medzisucet LEN zo znamych cien')
  NxTest.assert_equal(1, hw['unknown_count'])
  NxTest.refute(hw['complete'])
  NxTest.assert_equal('Demos', NxBudget.row(p, 'hardware', 'hw:h100')['dodavatel'])
end

# ============================ AUTOMATICKE SLUZBY ============================

NxTest.test('budget: sluzby — olep/porez/duplaky/PD/montaz z jednych cisel') do
  p = NxBudget.compute
  plates = NxBudget.section(p, 'materials')['rows'].sum { |r| r['mnozstvo'] }
  NxTest.assert_equal(8, plates, '5 (DTDL) + 2 (PD) + 1 (bez ceny)')
  olep = NxBudget.row(p, 'services', 'service:olep')
  NxTest.assert_close(110.0, olep['mnozstvo'], 0.01, 'olep berie bm VRATANE rezervy')
  NxTest.assert_close(99.0, olep['spolu'], 0.01)
  porez = NxBudget.row(p, 'services', 'service:porez')
  NxTest.assert_equal(8, porez['mnozstvo'])
  NxTest.assert_close(136.0, porez['spolu'], 0.01)
  pd = NxBudget.row(p, 'services', 'service:pd_opracovanie')
  NxTest.assert_close(100.0, pd['spolu'], 0.01, 'zakazka obsahuje PD')
end

NxTest.test('budget: dupláky = POCET zlepenych kusov, nikdy nie x2 znova (audit 4)') do
  p = NxBudget.compute
  r = NxBudget.row(p, 'services', 'service:duplaky')
  NxTest.assert_equal(3, r['mnozstvo'], 'doubled_quantity = 3 ks (nie 6, nie m2)')
  NxTest.assert_close(150.0, r['spolu'], 0.01)
end

NxTest.test('budget: MONTAZ je LEN raz — auto sluzba, ziadny standardny riadok (BLOCKER 1)') do
  p = NxBudget.compute
  montaz = NxBudget.row(p, 'services', 'service:montaz')
  NxTest.assert_close(46.4, montaz['mnozstvo'], 0.01, '8 platni x 5,8 m2')
  NxTest.assert_close(696.0, montaz['spolu'], 0.01, '46,4 m2 x 15 €/m2')
  std_keys = NxBudget.section(p, 'standard_rows')['rows'].map { |r| r['key'] }
  NxTest.refute(std_keys.include?('std:montaz'), 'montaz nesmie byt aj medzi standardnymi riadkami')
  all = p['sections'].flat_map { |s| s['rows'] }.select { |r| r['nazov'].to_s.downcase.start_with?('montáž') }
  NxTest.assert_equal(1, all.length, "montaz sa v rozpocte objavi PRAVE RAZ: #{all.map { |r| r['key'] }.inspect}")
end

NxTest.test('budget: PD sluzba je nulovy VIDITELNY riadok, ked zakazka PD nema') do
  bom_bez_pd = { rows: [{ 'material_id' => 'DTDL18', 'length' => 2000.0, 'width' => 500.0, 'quantity' => 4 }],
                 edging: [] }
  p = NxBudget.bd.compute(bom_bez_pd, NxBudget.state, NxBudget.settings,
                          sheets: NxBudget.sheets, edges: NxBudget.edges)
  r = p['sections'].find { |s| s['key'] == 'services' }['rows'].find { |x| x['key'] == 'service:pd_opracovanie' }
  NxTest.assert(r, 'riadok ostava viditelny')
  NxTest.assert_equal(0, r['mnozstvo'])
  NxTest.assert_close(0.0, r['spolu'], 0.001)
end

# ========================== STANDARDNE RIADKY ==============================

NxTest.test('budget: standardne riadky — nasobok x sadzba, nulovy riadok ostava viditelny') do
  p = NxBudget.compute('std_multipliers' => { 'std:doprava_vseobecna' => 0.0,
                                              'std:balne' => 2.0 })
  rows = NxBudget.section(p, 'standard_rows')['rows']
  NxTest.assert_equal(8, rows.length)
  NxTest.assert_close(60.0, NxBudget.row(p, 'standard_rows', 'std:doprava_zakaznik')['spolu'], 0.01)
  nula = NxBudget.row(p, 'standard_rows', 'std:doprava_vseobecna')
  NxTest.assert_close(0.0, nula['spolu'], 0.001, 'nulovy riadok = 0 €, nie zmizol')
  NxTest.assert_close(200.0, NxBudget.row(p, 'standard_rows', 'std:balne')['spolu'], 0.01, 'nasobok 2')
end

NxTest.test('budget: vizualizacia — m2 z meračky; bez m2 pri nenulovom nasobku je riadok NEUPLNY') do
  p = NxBudget.compute
  viz = NxBudget.row(p, 'standard_rows', 'std:vizualizacia')
  NxTest.assert(viz['missing_m2'], 'bez m2 sa suma neda vypocitat')
  NxTest.assert(viz['spolu'].nil?, 'nikdy nie 0 €')
  keys = p['budget_check'].map { |w| w['stable_key'] }
  NxTest.assert(keys.include?('budget|std:vizualizacia|missing_m2'), keys.inspect)

  p2 = NxBudget.compute('viz_m2' => 20.0)
  viz2 = NxBudget.row(p2, 'standard_rows', 'std:vizualizacia')
  NxTest.assert_close(300.0, viz2['spolu'], 0.01, '20 m2 x 15 €')
  NxTest.refute(viz2['price_missing'])

  p3 = NxBudget.compute('std_multipliers' => { 'std:vizualizacia' => 0.0 })
  viz3 = NxBudget.row(p3, 'standard_rows', 'std:vizualizacia')
  NxTest.assert_close(0.0, viz3['spolu'], 0.001, 'nasobok 0 = ciste nulovy riadok bez varovania')
  NxTest.refute(viz3['price_missing'])
end

# =========================== REZIM A OVERRIDY ==============================

NxTest.test('budget: rezim meni sadzby BEZ overridu, override rezim PREZIJE (audit 6)') do
  base = NxBudget.compute
  NxTest.assert_close(100.0, NxBudget.row(base, 'services', 'service:pd_opracovanie')['spolu'], 0.01)
  NxTest.assert_close(60.0, NxBudget.row(base, 'standard_rows', 'std:doprava_zakaznik')['spolu'], 0.01)

  nizky = NxBudget.compute('mode' => 'nizky')
  NxTest.assert_close(50.0, NxBudget.row(nizky, 'services', 'service:pd_opracovanie')['spolu'], 0.01,
                      'rezim prepocita riadok bez overridu')
  vysoky = NxBudget.compute('mode' => 'vysoky')
  NxTest.assert_close(80.0, NxBudget.row(vysoky, 'standard_rows', 'std:doprava_zakaznik')['spolu'], 0.01)

  s_ov = { 'overrides' => { 'service:pd_opracovanie' => 77.0 } }
  with_ov = NxBudget.compute(s_ov.merge('mode' => 'nizky'))
  r = NxBudget.row(with_ov, 'services', 'service:pd_opracovanie')
  NxTest.assert_close(77.0, r['spolu'], 0.01, 'override vitazi nad rezimom')
  NxTest.assert_close(50.0, r['spolu_auto'], 0.01, 'payload nesie AJ povodny vypocet (precarknuty v UI)')
  NxTest.assert_equal('override', r['zdroj'])

  reset = NxBudget.compute('mode' => 'nizky')
  NxTest.assert_close(50.0, NxBudget.row(reset, 'services', 'service:pd_opracovanie')['spolu'], 0.01,
                      'po zruseni overridu sa riadok vrati na auto')
end

NxTest.test('budget: override standardneho riadku nahradi vypocet (nie sadzbu)') do
  p = NxBudget.compute('overrides' => { 'std:zameranie' => 0.0 })
  r = NxBudget.row(p, 'standard_rows', 'std:zameranie')
  NxTest.assert_close(0.0, r['spolu'], 0.001)
  NxTest.assert_close(100.0, r['spolu_auto'], 0.01)
end

# ====================== NEZNAME CENY, SUCTY, ZAOKRUHLENIE ==================

NxTest.test('budget: neznama cena — medzisucet len zo znamych, complete=false (audit 5)') do
  p = NxBudget.compute('viz_m2' => 20.0)
  mat = NxBudget.section(p, 'materials')
  NxTest.assert_equal(1, mat['unknown_count'])
  NxTest.refute(mat['complete'])
  NxTest.assert_close(362.25 + 196.8, mat['subtotal'], 0.01, 'riadok bez ceny do medzisuctu nevstupuje')
  NxTest.refute(p['totals']['complete'], 'neuplnost sa NIKDY neskryva')
  NxTest.assert(p['totals']['unknown_count'] >= 2)
  keys = p['budget_check'].map { |w| w['stable_key'] }
  NxTest.assert(keys.include?('budget|section:materials|incomplete'), keys.inspect)
  NxTest.assert(keys.include?('budget|section:hardware|incomplete'), keys.inspect)
end

NxTest.test('budget: zaokruhlenie BRUTTO sumy nahor (1 € default aj krok 10 €) + DPH prepocet') do
  p = NxBudget.compute('viz_m2' => 20.0)
  t = p['totals']
  step_row = NxBudget.row(p, 'rounding', 'rounding')
  NxTest.assert_close(t['rounding'], step_row['spolu'], 0.01, 'riadok zaokruhlenia je VIDITELNY')
  NxTest.assert_close(t['raw_total'] + t['rounding'], t['total'], 0.01)
  NxTest.assert_equal(t['total'], t['total'].round, 'krok 1 € = cele euro')
  NxTest.assert(t['rounding'] >= 0 && t['rounding'] < 1.0, 'zaokruhluje sa NAHOR o menej ako krok')
  NxTest.assert_close(t['total'] / 1.23, t['total_novat'], 0.01, 'bez DPH je len informativny prepocet')

  p10 = NxBudget.compute({ 'viz_m2' => 20.0 }, 'rounding_step' => 10.0)
  t10 = p10['totals']
  NxTest.assert_close(0.0, (t10['total'] / 10.0) - (t10['total'] / 10.0).round, 0.001, 'nasobok 10 €')
  NxTest.assert(t10['total'] >= t10['raw_total'], 'nikdy nadol')
  NxTest.assert_close(t['raw_total'], t10['raw_total'], 0.01, 'zaokruhlenie nemeni podklad')
end

NxTest.test('budget: ceil_to — presna hranica sa nezdvihne, tesne nad ide hore') do
  NxTest.assert_close(1235.0, NxBudget.bd.ceil_to(1234.56, 1.0), 0.001)
  NxTest.assert_close(1234.0, NxBudget.bd.ceil_to(1234.0, 1.0), 0.001, 'presna suma sa nezaokruhli hore')
  NxTest.assert_close(1240.0, NxBudget.bd.ceil_to(1234.56, 10.0), 0.001)
  NxTest.assert_close(1230.0, NxBudget.bd.ceil_to(1230.0, 10.0), 0.001)
end

# ===================== VLASTNE POLOZKY A SPOTREBICE =======================

NxTest.test('budget: vlastne polozky — pocet x cena, chybajuca cena = warning s UUID identitou') do
  items = [{ 'id' => 'uuid-1', 'popis' => 'Doprava kameňa', 'cena' => 45.0, 'pocet' => 2,
             'cp_skupina' => 'zostava' },
           { 'id' => 'uuid-2', 'popis' => 'Subdodávka sklo', 'cena' => nil, 'pocet' => 1,
             'cp_skupina' => 'sklo' }]
  p = NxBudget.compute('custom_items' => items)
  sec = NxBudget.section(p, 'custom')
  NxTest.assert_close(90.0, sec['subtotal'], 0.01)
  NxTest.assert_equal(1, sec['unknown_count'])
  NxTest.assert_equal('sklo', NxBudget.row(p, 'custom', 'custom:uuid-2')['cp_skupina'])
  keys = p['budget_check'].map { |w| w['stable_key'] }
  NxTest.assert(keys.include?('budget|custom:uuid-2|missing_price'), keys.inspect)
end

NxTest.test('budget: spotrebice — POSLEDNA sekcia, do SPOLU len ked su zapnute') do
  appl = [{ 'id' => 'a-1', 'typ' => 'umyvacka', 'nazov' => 'Bosch SMV', 'cena' => 499.0,
            'cp_skupina' => 'zostava' }]
  off = NxBudget.compute('appliances' => appl, 'appliances_included' => false, 'viz_m2' => 20.0)
  on  = NxBudget.compute('appliances' => appl, 'appliances_included' => true, 'viz_m2' => 20.0)
  NxTest.assert_close(499.0, NxBudget.section(off, 'appliances')['subtotal'], 0.01,
                      'medzisucet je v payloade VZDY')
  NxTest.refute(NxBudget.section(off, 'appliances')['counts_in_total'])
  NxTest.assert_close(499.0, on['totals']['raw_total'] - off['totals']['raw_total'], 0.01)
  keys = off['budget_check'].map { |w| w['stable_key'] }
  NxTest.assert(keys.include?('budget|appliances|not_included'), keys.inspect)
  NxTest.refute(on['budget_check'].map { |w| w['stable_key'] }.include?('budget|appliances|not_included'))
  r = NxBudget.row(on, 'appliances', 'appliance:a-1')
  NxTest.assert_equal('Umývačka', r['typ_label'])
end

NxTest.test('budget: spotrebic bez ceny — stabilny kluc warningu cez UUID') do
  appl = [{ 'id' => 'a-9', 'typ' => 'ine', 'nazov' => 'Drez', 'cena' => nil }]
  p = NxBudget.compute('appliances' => appl)
  keys = p['budget_check'].map { |w| w['stable_key'] }
  NxTest.assert(keys.include?('budget|appliance:a-9|missing_price'), keys.inspect)
  NxTest.assert(p['budget_check'].all? { |w| w['category'] == 'budget' && w['severity'] == 'orange' })
end

# ============================== EXPORTNE POLIA =============================

NxTest.test('budget: kazdy riadok nesie exportne polia pre Luciin harok (audit 12)') do
  items = [{ 'id' => 'c1', 'popis' => 'LED pás', 'cena' => 7.0, 'pocet' => 5, 'cp_skupina' => 'zostava' }]
  appl = [{ 'id' => 'a1', 'typ' => 'rura', 'nazov' => 'Rúra', 'cena' => 300.0 }]
  p = NxBudget.compute('custom_items' => items, 'appliances' => appl, 'viz_m2' => 12.0)
  fields = %w[nazov kod dodavatel mj mnozstvo cena_mj spolu poznamka zdroj cp_skupina]
  p['sections'].each do |sec|
    sec['rows'].each do |r|
      fields.each { |f| NxTest.assert(r.key?(f), "sekcia #{sec['key']} riadok #{r['key']} nema pole #{f}") }
      NxTest.assert(%w[auto manual override].include?(r['zdroj']), "zdroj #{r['zdroj'].inspect}")
      NxTest.assert(!r['cp_skupina'].to_s.strip.empty?, 'cp_skupina musi byt vyplnena')
    end
  end
  NxTest.assert_equal('manual', NxBudget.row(p, 'custom', 'custom:c1')['zdroj'])
end

# ============================== VEK CIEN ===================================

NxTest.test('budget: vek cien — 3 stavy, VYHRADNE nad polozkami pouzitymi v rozpocte (audit 11)') do
  p = NxBudget.compute
  stale = p['stale']
  ids = stale['items'].map { |i| i['id'] }
  NxTest.refute(ids.include?('NEPOUZITY'), 'nepouzity material sa v rozpocte nekontroluje')
  pd = stale['items'].find { |i| i['id'] == 'PD38' }
  NxTest.assert_equal('stale', pd['state'], 'cena z januara je starsia ako 30 dni')
  NxTest.assert(pd['age_days'] > 200)
  abs = stale['items'].find { |i| i['id'] == 'ABS_K009_10' }
  NxTest.assert_equal('manual', abs['state'], 'neviazany zaznam nikdy nie je stary')
  bez = stale['items'].find { |i| i['id'] == 'BEZCENY' }
  NxTest.assert_equal('manual', bez['state'])
  NxTest.refute(ids.include?('DTDL18'), 'cerstva cena (5 dni) sa v zozname neukazuje')
  NxTest.assert_equal(1, stale['counts']['fresh'])
  NxTest.assert_equal(30, stale['stale_days'])
end

NxTest.test('budget: vek cien — viazany zaznam bez datumu je unverified, kovanie vstupuje do scanu') do
  sh = NxBudget.sheets
  sh['DTDL18'] = sh['DTDL18'].merge('price_checked_at' => '')
  p = NxBudget.bd.compute(NxBudget.bom, NxBudget.state, NxBudget.settings,
                          sheets: sh, edges: NxBudget.edges,
                          hardware_expansion: NxBudget.hardware_expansion,
                          hardware_catalog: NxBudget.hardware_catalog,
                          now: Time.utc(2026, 8, 6))
  item = p['stale']['items'].find { |i| i['id'] == 'DTDL18' }
  NxTest.assert_equal('unverified', item['state'])
  hw = p['stale']['items'].find { |i| i['kind'] == 'hardware' }
  NxTest.assert_equal('unverified', hw['state'], 'kovanie bez datumu overenia')
end

# ======================= BUDGET STORE (data zakazky) =======================

NxTest.test('budget_store: default stav bez zapisov') do
  m = NxBudget::FakeModel.new
  st = NxBudget.bs.state(m)
  NxTest.assert_equal('standard', st['mode'])
  NxTest.assert_equal({}, st['overrides'])
  NxTest.assert(st['viz_m2'].nil?)
  NxTest.assert_equal([], st['custom_items'])
  NxTest.assert_equal(false, st['appliances_included'], 'spotrebice sa default NEPOCITAJU')
  NxTest.assert_equal(0, m.ops.length, 'citanie nikdy neotvara operaciu')
end

NxTest.test('budget_store: kazda mutacia = vlastna undo operacia, chybny vstup NEZAPISE') do
  m = NxBudget::FakeModel.new
  ok, = NxBudget.bs.set_mode!(m, 'vysoky')
  NxTest.assert(ok)
  NxTest.assert_equal('vysoky', NxBudget.bs.mode(m))
  NxTest.assert_equal(1, m.ops.length)
  NxTest.assert_equal(1, m.committed)

  bad, errs = NxBudget.bs.set_mode!(m, 'ultra')
  NxTest.refute(bad)
  NxTest.assert(errs.any?)
  NxTest.assert_equal(1, m.ops.length, 'neplatny vstup neotvori undo krok')
  NxTest.assert_equal('vysoky', NxBudget.bs.mode(m))

  NxBudget.bs.set_override!(m, 'service:montaz', 1500.0)
  NxTest.assert_close(1500.0, NxBudget.bs.overrides(m)['service:montaz'], 0.01)
  NxTest.assert_equal(2, m.ops.length)
  NxBudget.bs.clear_override!(m, 'service:montaz')
  NxTest.assert_equal({}, NxBudget.bs.overrides(m), 'explicitny reset override zmaze')

  bad2, = NxBudget.bs.set_override!(m, 'nezmysel', 10.0)
  NxTest.refute(bad2, 'kluc riadku musi mat namespace service:/std:')
  bad3, = NxBudget.bs.set_std_multiplier!(m, 'std:balne', 'abc')
  NxTest.refute(bad3)
  NxBudget.bs.set_std_multiplier!(m, 'std:balne', 2.5)
  NxTest.assert_close(2.5, NxBudget.bs.std_multipliers(m)['std:balne'], 0.01)
end

NxTest.test('budget_store: vlastna polozka — serverove UUID, cp_skupina default, cena nil legalna') do
  m = NxBudget::FakeModel.new
  item, errs = NxBudget.bs.add_custom_item!(m, 'popis' => 'Likvidácia', 'cena' => '', 'pocet' => 3)
  NxTest.assert(errs.empty?, errs.inspect)
  NxTest.assert(item['id'].length > 20, 'ID je serverom generovane UUID')
  NxTest.assert(item['cena'].nil?, 'prazdna cena = nezadana, NIE 0')
  NxTest.assert_equal(3, item['pocet'])
  NxTest.assert_equal('zostava', item['cp_skupina'])

  # klientske ID sa pri zakladani ignoruje
  item2, = NxBudget.bs.add_custom_item!(m, 'popis' => 'Iné', 'id' => 'podvrh')
  NxTest.refute(item2['id'] == 'podvrh')
  NxTest.assert_equal(2, NxBudget.bs.custom_items(m).length)

  upd, uerr = NxBudget.bs.update_custom_item!(m, item['id'], 'cena' => '12,50')
  NxTest.assert(uerr.empty?, uerr.inspect)
  NxTest.assert_close(12.5, upd['cena'], 0.01, 'desatinna ciarka je platny vstup')
  NxTest.assert_equal('Likvidácia', upd['popis'], 'nedodane pole si zachova povodnu hodnotu')
  NxTest.assert_equal(item['id'], upd['id'], 'ID sa updatom nikdy nemeni')

  ok, = NxBudget.bs.remove_custom_item!(m, item2['id'])
  NxTest.assert(ok)
  NxTest.assert_equal(1, NxBudget.bs.custom_items(m).length)
  miss, = NxBudget.bs.remove_custom_item!(m, 'neexistuje')
  NxTest.refute(miss)
end

NxTest.test('budget_store: URL sa sanitizuje serverovo (len http/https)') do
  m = NxBudget::FakeModel.new
  item, errs = NxBudget.bs.add_custom_item!(m, 'popis' => 'Drez', 'url' => 'https://drezyonline.sk/x')
  NxTest.assert(errs.empty?, errs.inspect)
  NxTest.assert_equal('https://drezyonline.sk/x', item['url'])
  _, bad = NxBudget.bs.add_custom_item!(m, 'popis' => 'Zlé', 'url' => 'javascript:alert(1)')
  NxTest.assert(bad.any?, 'javascript: sa nesmie ulozit')
  _, bad2 = NxBudget.bs.add_custom_item!(m, 'popis' => 'Zlé', 'url' => 'file:///C:/tajne.txt')
  NxTest.assert(bad2.any?)
  NxTest.assert_equal(1, NxBudget.bs.custom_items(m).length)
end

NxTest.test('budget_store: spotrebic — enum typu, UUID, prepinac sceitania') do
  m = NxBudget::FakeModel.new
  a, errs = NxBudget.bs.add_appliance!(m, 'typ' => 'chladnicka', 'nazov' => 'Liebherr',
                                       'cena' => 899.0, 'dodavatel' => 'Nay')
  NxTest.assert(errs.empty?, errs.inspect)
  NxTest.assert_equal('chladnicka', a['typ'])
  NxTest.assert_equal('zostava', a['cp_skupina'])
  _, bad = NxBudget.bs.add_appliance!(m, 'typ' => 'kozub', 'nazov' => 'X')
  NxTest.assert(bad.any?, 'typ mimo enumu sa odmietne')
  NxTest.assert_equal(1, NxBudget.bs.appliances(m).length)
  NxBudget.bs.set_appliances_included!(m, true)
  NxTest.assert_equal(true, NxBudget.bs.appliances_included?(m))
  NxBudget.bs.set_appliances_included!(m, false)
  NxTest.assert_equal(false, NxBudget.bs.appliances_included?(m))
end

NxTest.test('budget_store: viz m2 a poskodene data v dict') do
  m = NxBudget::FakeModel.new
  NxBudget.bs.set_viz_m2!(m, '18,5')
  NxTest.assert_close(18.5, NxBudget.bs.viz_m2(m), 0.01)
  bad, = NxBudget.bs.set_viz_m2!(m, 'abc')
  NxTest.refute(bad)
  NxBudget.bs.set_viz_m2!(m, nil)
  NxTest.assert(NxBudget.bs.viz_m2(m).nil?, 'prazdna hodnota vymaze m2')
  m.set_attribute('NOXUN', 'budget_custom_items', '{nie je json')
  NxTest.assert_equal([], NxBudget.bs.custom_items(m), 'poskodeny JSON nezhodi rozpocet')
  m.set_attribute('NOXUN', 'budget_overrides', { 'zly kluc' => 5, 'std:balne' => 12.0 }.to_json)
  NxTest.assert_equal({ 'std:balne' => 12.0 }, NxBudget.bs.overrides(m), 'neplatne kluce sa zahodia')
end

NxTest.test('budget: stav zo BudgetStore prejde vypoctom (kontrakt state -> payload)') do
  m = NxBudget::FakeModel.new
  NxBudget.bs.set_mode!(m, 'nizky')
  NxBudget.bs.set_viz_m2!(m, 10.0)
  NxBudget.bs.add_custom_item!(m, 'popis' => 'Klzáky', 'cena' => 0.5, 'pocet' => 20)
  p = NxBudget.bd.compute(NxBudget.bom, NxBudget.bs.state(m), NxBudget.settings,
                          sheets: NxBudget.sheets, edges: NxBudget.edges)
  NxTest.assert_equal('nizky', p['mode'])
  NxTest.assert_equal('Nízky', p['mode_label'])
  NxTest.assert_close(150.0, NxBudget.section(p, 'standard_rows')['rows']
    .find { |r| r['key'] == 'std:vizualizacia' }['spolu'], 0.01, '10 m2 x 15 €')
  NxTest.assert_close(10.0, NxBudget.section(p, 'custom')['subtotal'], 0.01)
end
