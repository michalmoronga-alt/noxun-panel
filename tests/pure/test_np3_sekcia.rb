# frozen_string_literal: true
# NP-3 (blok 2 · Narezovy plan): sekcia Studia + poznamka v Rozpocte.
# Package: SYSTEM/archiv/bloky/NAREZ/PACKAGE_NP3_SEKCIA.md (+ nalezy auditu
# B1–B4, F5–F12 — maju prednost).
#
# Co sa tu dokazuje:
#   1. JEDNA veta o pocte platni (`SheetLayout.count_phrase`) pre kazdu
#      kombinaciu priznakov — ta ista v karte, v poznamke rozpoctu aj v XLSX.
#   2. Plan cita `blocked` zo VSETKYCH bran VEPO (B1) cez strukturovane dovody
#      bez exportnej vety (F5); chyba planu nic nezhodi (F7).
#   3. Rozpocet ani oba XLSX nemenia ZIADNE cislo — len poznamku.
#   4. Oko ide nativnym klucom az cez Ruby `refs_for` (B2); duplak bez vazby
#      ma v rozpocte vlastnu vetu (B3); globalna neuplnost ma banner (B4).
#   5. Push nesie plan z TOHO ISTEHO zberu (guard) a limit velkosti/casu (F9).
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'fileutils'
require 'tmpdir'
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') unless defined?(Noxun::Engine::StudioDialog)
end

module NxNp3
  E  = Noxun::Engine
  SL = E::SheetLayout
  PC = E::ProductionCore
  ROOT = NxTest::ROOT

  SHEETS = {
    'H18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1181',
               'manufacturer' => 'Egger', 'grain' => 'length', 'color' => [124, 90, 58], 'price_per_m2' => 36.5 },
    'H36' => { 'type' => 'DTDL', 'thickness' => 36.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1181 duplák',
               'source_material_id' => 'H18', 'source_multiplier' => 2, 'price_per_m2' => 73.0 },
    'W18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'W1000',
               'grain' => 'none', 'price_per_m2' => 26.9 },
    'UNI' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'UNI', 'uni' => true },
    'NOF' => { 'type' => 'DTDL', 'thickness' => 18.0, 'decor' => 'K001', 'price_per_m2' => 31.2 },
    'PD'  => { 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0], 'decor' => 'Dub', 'price_per_m2' => 62.0 }
  }.freeze

  module_function

  def row(over = {})
    r = { 'names' => ['Bok'], 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0, 'quantity' => 1,
          'material_id' => 'H18', 'grain_direction' => 'length',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
          'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 1 }] }.merge(over)
    r['key'] = E::Bom.row_key(r) unless over.key?('key')
    r['refs'] ||= [{ 'pid' => 1000 + r['length'].to_i }]
    r
  end

  def plan(rows, params: {}, blocked: nil, source: 'file')
    res = SL.compute(rows, sheets: SHEETS, edge_thicknesses: {}, params: params, blocked: blocked)
    res['params_source'] = source
    res
  end

  def mat(res, id)
    res['materials'].find { |m| m['material_id'] == id }
  end

  def estimate(rows)
    E::SheetEstimate.estimate(rows, sheet_sizes: SHEETS.transform_values { |s| s['sheet_size'] },
                                    uni_ids: { 'UNI' => true })
  end

  def budget(rows, layout)
    E::Budget.compute({ rows: rows, edging: [] }, {}, E::SupplierSettings.seed_supplier,
                      sheets: SHEETS, edges: {}, sheet_estimate: estimate(rows), sheet_layout: layout,
                      now: Time.utc(2026, 9, 29, 12))
  end

  def src(rel)
    File.read(File.join(ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
  end

  def body(rel, name)
    s = src(rel)
    m = s.match(/^(\s*)def #{Regexp.escape(name)}(?=[\s(]).*?^\1end\b/m)
    m ? m[0] : ''
  end

  # Cisla riadku rozpoctu bez poznamky (poznamka je jediny rozdiel, ktory smie vzniknut).
  def numbers(payload)
    strip = lambda do |v|
      case v
      when Hash then v.each_with_object({}) { |(k, x), o| o[k] = strip.call(x) unless k == 'poznamka' }
      when Array then v.map { |x| strip.call(x) }
      else v
      end
    end
    strip.call(payload)
  end

  # Izolovane nastavenia dodavatela (vzor R-11/NP-2) — nikdy zivy %APPDATA%.
  def with_sandbox
    prev = E::Materials.test_dir_override
    dir = Dir.mktmpdir('nx-np3-')
    E::Materials.test_dir_override = dir
    E::JsonFileStore.invalidate
    yield dir
  ensure
    E::Materials.test_dir_override = prev
    E::JsonFileStore.invalidate
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  # Docasne nahradi singleton metody modulu (vzor test_kon0_d143).
  def with_stubs(mod, map)
    saved = {}
    map.each do |name, fn|
      saved[name] = mod.method(name)
      mod.define_singleton_method(name, &fn)
    end
    yield
  ensure
    saved.each { |name, m| mod.define_singleton_method(name, m) }
  end
end

# ============================================================================
# 1. JEDNA VETA O POCTE (count_phrase) — kazda kombinacia priznakov
# ============================================================================

NxTest.test('NP-3 veta: uplny plan = „N platní (horná hranica)" a sklonovanie') do
  f = NxNp3
  one = f.mat(f.plan([f.row]), 'H18')
  NxTest.assert_equal('1 platňa (horná hranica)', f::SL.count_phrase(one)['text'])
  NxTest.assert_equal('', f::SL.count_phrase(one)['cls'])
  three = { 'sheets' => 3, 'unplaced' => [], 'rejected_rows' => 0 }
  NxTest.assert_equal('3 platne (horná hranica)', f::SL.count_phrase(three)['text'])
  NxTest.assert_equal('5 platní (horná hranica)', f::SL.count_phrase(three.merge('sheets' => 5))['text'])
  NxTest.assert_equal('0 platní (horná hranica)', f::SL.count_phrase(three.merge('sheets' => 0))['text'])
end

NxTest.test('NP-3 veta: neuplny plan (nezaradeny, vyradeny, konflikt, blocked) = „celkový počet neznámy"') do
  f = NxNp3
  inc = '1 platňa pre zaradené dielce — celkový počet neznámy'
  over = f.mat(f.plan([f.row, f.row('names' => ['Dlhy'], 'length' => 2795.0)]), 'H18')
  NxTest.assert_equal(inc, f::SL.count_phrase(over)['text'], 'nezaradeny (oversize)')
  NxTest.assert_equal('inc', f::SL.count_phrase(over)['cls'])
  rej = f.mat(f.plan([f.row, f.row('names' => ['ABS'], 'edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil })]), 'H18')
  NxTest.assert_equal(inc, f::SL.count_phrase(rej)['text'], 'vyradeny riadok VEPO')
  thk = f.mat(f.plan([f.row, f.row('names' => ['T36'], 'thickness' => 36.0)]), 'H18')
  NxTest.assert_equal(inc, f::SL.count_phrase(thk)['text'], 'konflikt hrubky')
  blk = f.mat(f.plan([f.row], blocked: { 'all' => 'VEPO export by sa zastavil: x' }), 'H18')
  NxTest.assert_equal([false, 'VEPO export by sa zastavil: x'], blk.values_at('upper_bound', 'blocked'))
  NxTest.assert_equal(inc, f::SL.count_phrase(blk)['text'], 'blocked = celkovy pocet neznamy, nikdy horna hranica')
end

NxTest.test('NP-3 veta: fallback / UNI = „orientačne N platní pri formáte L × W"; spolu s neuplnym obe') do
  f = NxNp3
  nof = f.mat(f.plan([f.row('material_id' => 'NOF')]), 'NOF')
  NxTest.assert_equal('orientačne 1 platňa pri formáte 2800 × 2070', f::SL.count_phrase(nof)['text'])
  NxTest.assert_equal('orient', f::SL.count_phrase(nof)['cls'])
  uni = f.mat(f.plan([f.row('material_id' => 'UNI')]), 'UNI')
  NxTest.assert_equal('orientačne 1 platňa pri formáte 2800 × 2070', f::SL.count_phrase(uni)['text'])
  both = f.mat(f.plan([f.row('material_id' => 'NOF'), f.row('material_id' => 'NOF', 'length' => 2900.0)]), 'NOF')
  NxTest.assert_equal('orientačne 1 platňa pri formáte 2800 × 2070 — pre zaradené dielce, celkový počet neznámy',
                      f::SL.count_phrase(both)['text'], 'orientacny a neuplny sa navzajom neschovaju')
end

NxTest.test('NP-3 veta (F8): predvolene nastavenia = „orientačne … nastavenia sa nepodarilo načítať", nikdy horna hranica') do
  f = NxNp3
  m = f.mat(f.plan([f.row]), 'H18')
  %w[seed_fallback unreadable].each do |src|
    NxTest.assert(f::SL.unreliable_source?(src), src)
    t = f::SL.count_phrase(m, unreliable: f::SL.unreliable_source?(src))['text']
    NxTest.assert_equal('orientačne 1 platňa — nastavenia prerezu a orezu sa nepodarilo načítať', t)
    NxTest.refute(t.include?('horná hranica'))
  end
  %w[file backup newer_file].each { |src| NxTest.refute(f::SL.unreliable_source?(src), src) }
  over = f.mat(f.plan([f.row, f.row('length' => 2795.0)]), 'H18')
  NxTest.assert_equal('orientačne 1 platňa — nastavenia prerezu a orezu sa nepodarilo načítať; ' \
                      'pre zaradené dielce, celkový počet neznámy', f::SL.count_phrase(over, unreliable: true)['text'])
  bad = f.mat(f.plan([f.row], params: { 'kerf' => -1 }), 'H18')
  NxTest.assert(f::SL.count_phrase(bad)['text'].start_with?('plán nedostupný'), 'neplatne parametre = ziadny pocet')
  # Predrecenzia P3-3: poznamka rozpoctu bez zdvojeneho „plán: plán …"
  bad_plan = f.plan([f.row], params: { 'kerf' => -1 })
  NxTest.assert_equal('plán nedostupný — neplatné nastavenie prerezu, orezu alebo prídavku',
                      f::SL.budget_note(bad_plan, 'H18', f::SHEETS))
end

NxTest.test('NP-3 veta: skladanie vety zije PRAVE v jednej funkcii (karta, rozpocet, XLSX)') do
  f = NxNp3
  lib = f.src('core/sheet_layout.rb')
  NxTest.assert_equal(1, lib.scan("'(horná hranica)'").length, 'text hornej hranice je v kode raz')
  NxTest.assert_equal(1, lib.scan("'pre zaradené dielce — celkový počet neznámy'").length)
  %w[core/budget.rb ui/production_core.rb ui/js/sheet_layout.js core/xlsx_writer.rb].each do |rel|
    s = f.src(rel)
    NxTest.refute(s.include?("'(horná hranica)'") || s.include?('"(horná hranica)"'),
                  "#{rel} vetu neskladá — len ju zobrazí")
  end
  NxTest.assert(f.body('core/budget.rb', 'layout_note').include?('SheetLayout.budget_note'))
  NxTest.assert(f.body('ui/production_core.rb', 'layout_material_payload').include?('SheetLayout.count_phrase'))
end

# ============================================================================
# 2. POZNAMKA V ROZPOCTE — ta ista veta, cisla BEZ ZMENY (aj oba XLSX)
# ============================================================================

NxTest.test('NP-3 rozpocet: poznamka nesie tu istu vetu ako karta; mnozstvo, ceny a sluzby sa NEMENIA') do
  f = NxNp3
  rows = [f.row, f.row('names' => ['Dvierka'], 'length' => 716.0, 'width' => 596.0, 'quantity' => 3),
          f.row('names' => ['Dlhy'], 'material_id' => 'W18', 'length' => 2795.0, 'grain_direction' => 'none'),
          f.row('material_id' => 'W18', 'grain_direction' => 'none', 'quantity' => 6),
          f.row('material_id' => 'NOF'), f.row('material_id' => 'PD', 'thickness' => 38.0, 'length' => 2400.0, 'width' => 600.0)]
  lay = f.plan(rows)
  a = f.budget(rows, nil)
  b = f.budget(rows, lay)
  NxTest.assert_equal(f.numbers(a), f.numbers(b), 'bez poznamky je payload rozpoctu IDENTICKY (sumy, porez, montaz, CP)')
  ma = a['sections'].find { |s| s['key'] == 'materials' }['rows']
  mb = b['sections'].find { |s| s['key'] == 'materials' }['rows']
  mb.each_with_index do |r, i|
    note = f::SL.budget_note(lay, r['material_id'], f::SHEETS)
    NxTest.assert_equal("#{ma[i]['poznamka']} · #{note}", r['poznamka'], r['material_id'])
    card = f::SL.count_phrase(f.mat(lay, r['material_id']))['text']
    NxTest.assert_equal("plán: #{card}", note, 'poznamka = veta karty')
  end
  NxTest.assert(mb.find { |r| r['material_id'] == 'W18' }['poznamka'].include?('celkový počet neznámy'))
  NxTest.assert(mb.find { |r| r['material_id'] == 'NOF' }['poznamka'].include?('orientačne'))
end

NxTest.test('NP-3 XLSX: rozpoctovy harok sa lisi LEN textom poznamky v nazve; ponuka je bajtovo rovnaka') do
  f = NxNp3
  rows = [f.row, f.row('material_id' => 'W18', 'grain_direction' => 'none', 'quantity' => 4)]
  a = f.budget(rows, nil)
  b = f.budget(rows, f.plan(rows))
  t = Time.utc(2026, 9, 29, 12)
  sa = f::E::BudgetXlsx.sheet(a, project: 'Test', now: t)
  sb = f::E::BudgetXlsx.sheet(b, project: 'Test', now: t)
  NxTest.assert_equal(sa['rows'].length, sb['rows'].length)
  diff = 0
  sa['rows'].each_with_index do |ra, i|
    next if ra == sb['rows'][i]

    diff += 1
    txt = sb['rows'][i].to_s
    NxTest.assert(txt.include?('plán: '), "zmeneny riadok #{i} nesie len poznamku planu")
    # cisla riadku (vsetky bunky okrem nazvu) su rovnake
    NxTest.assert_equal(ra.to_s.scan(/"v"=>([0-9.]+)/), sb['rows'][i].to_s.scan(/"v"=>([0-9.]+)/))
  end
  NxTest.assert_equal(2, diff, 'dva riadky materialu, nic ine')
  spec = f::E::CpExport.specification([], sheets: f::SHEETS, budget: a)
  ca = f::E::XlsxWriter.build_book(f::E::CpXlsx.sheets(a['cp_preview'], spec, project: 'Test', now: t), now: t)
  cb = f::E::XlsxWriter.build_book(f::E::CpXlsx.sheets(b['cp_preview'], spec, project: 'Test', now: t), now: t)
  NxTest.assert_equal(ca, cb, 'cenova ponuka pocty platni nikdy neukaze — XLSX ponuky je bajtovo rovnaky')
end

NxTest.test('NP-3 rozpocet (B3): duplak BEZ vazby ma v riadku duplaku vlastnu vetu; zdroj je neuplny') do
  f = NxNp3
  rows = [f.row('names' => ['Bok'], 'quantity' => 2),
          f.row('names' => ['DUP'], 'material_id' => 'H36', 'thickness' => 36.0, 'length' => 820.0, 'width' => 580.0)]
  lay = f.plan(rows)
  NxTest.assert_equal(['H18'], lay['materials'].map { |m| m['material_id'] }, 'plan duplak pripise zdroju')
  NxTest.assert_equal('H36', f.mat(lay, 'H18')['conflicts'][0]['row_material_id'])
  b = f.budget(rows, lay)
  mrows = b['sections'].find { |s| s['key'] == 'materials' }['rows']
  dup = mrows.find { |r| r['material_id'] == 'H36' }
  NxTest.assert(dup, 'odhad drzi duplak pod ID duplaku (riadok rozpoctu existuje)')
  NxTest.assert(dup['poznamka'].end_with?(f::SL::DUPLAK_UNLINKED_NOTE), dup['poznamka'])
  src = mrows.find { |r| r['material_id'] == 'H18' }
  NxTest.assert(src['poznamka'].include?('celkový počet neznámy'), 'zdroj nie je horna hranica')
  NxTest.assert_equal(nil, f::SL.budget_note(lay, 'NEZNAMY', f::SHEETS), 'iny chybajuci material = ziadna veta')
  NxTest.assert_equal(nil, f::SL.budget_note(nil, 'H18', f::SHEETS), 'rozpocet bez planu (legacy) = bez vety')
end

NxTest.test('NP-3 fail-soft (F7): chyba planu = „plán nedostupný", rozpocet ani cisla nespadnu') do
  f = NxNp3
  rows = [f.row]
  a = f.budget(rows, nil)
  err = f.budget(rows, { 'error' => f::SL::UNAVAILABLE_NOTE })
  NxTest.assert_equal(f.numbers(a), f.numbers(err))
  mr = err['sections'].find { |s| s['key'] == 'materials' }['rows'][0]
  NxTest.assert(mr['poznamka'].end_with?('plán nedostupný'), mr['poznamka'])
  # vynimka pri skladani vety — Budget ju pohlti vlastnym rescue
  f.with_stubs(f::SL, budget_note: ->(*_a) { raise 'boom' }) do
    x = f.budget(rows, f.plan(rows))
    NxTest.assert_equal(f.numbers(a), f.numbers(x))
    NxTest.assert(x['sections'].find { |s| s['key'] == 'materials' }['rows'][0]['poznamka'].end_with?('plán nedostupný'))
  end
  # vynimka v SheetLayout.compute — layout_for je fail-soft
  f.with_sandbox do
    f.with_stubs(f::SL, compute: ->(*_a, **_k) { raise 'vypocet padol' }) do
      res = f::PC.layout_for({ records: [] }, { rows: rows }, f::SHEETS, { 'rows' => [], 'unmapped' => [] })
      NxTest.assert_equal({ 'error' => 'plán nedostupný' }, res)
      pay = f::PC.sheet_layout_payload(res, { rows: rows }, f::SHEETS, [])
      NxTest.assert_equal(false, pay['ok'])
    end
  end
end

# ============================================================================
# 3. BLOCKED = VSETKY BRANY VEPO (B1), strukturovane dovody (F5)
# ============================================================================

NxTest.test('NP-3 blocked (B1, F5): novsia schema, chrbat D-143 aj kit zasuviek (:kit) zastavia horna hranicu') do
  f = NxNp3
  rows = [f.row]
  exp = { 'rows' => [], 'unmapped' => [] }
  base = { records: [], hardware: [], hardware_issues: [], cut_issues: [], newer_configs: [] }
  f.with_sandbox do
    clean = f::PC.layout_for(base, { rows: rows }, f::SHEETS, exp)
    NxTest.assert_equal([true, nil], f.mat(clean, 'H18').values_at('upper_bound', 'blocked'))
    NxTest.assert_equal('file', clean['params_source'])
    cases = {
      'novsia schema' => base.merge(newer_configs: ['CAB-009']),
      'chrbat D-143' => base.merge(cut_issues: [{ 'code' => f::E::Bom::CUT_INVALID, 'owner_id' => 'CAB-002' }]),
      'kit zasuviek' => base.merge(hardware_issues: [{ 'code' => f::E::Recipes::STALE, 'owner_id' => 'CAB-003' }])
    }
    cases.each do |what, col|
      reasons = f::PC.layout_block_reasons(col, exp)
      NxTest.assert_equal(1, reasons.length, what)
      NxTest.refute(reasons.join.include?('NEVYKONAL'), "#{what}: strukturovany dovod bez exportnej vety (F5)")
      res = f::PC.layout_for(col, { rows: rows }, f::SHEETS, exp)
      m = f.mat(res, 'H18')
      NxTest.assert_equal(false, m['upper_bound'], what)
      NxTest.assert(m['blocked'].to_s.start_with?('VEPO export by sa zastavil: '), what)
      NxTest.assert(f::SL.count_phrase(m)['text'].include?('celkový počet neznámy'), what)
      NxTest.assert_equal(m['blocked'], res['blocked_all'])
    end
    # ta ista brana ako VEPO: kit sa pri nedostupnej expanzii s receptovou polozkou nedokaze
    recipe = base.merge(hardware: [{ 'source' => f::E::BuildPlan::HW_SOURCE_RECIPE }])
    NxTest.assert_equal(1, f::PC.layout_block_reasons(recipe, nil).length, 'nil expanzia + recept = fail-closed ako VEPO')
    NxTest.assert_equal(0, f::PC.layout_block_reasons(base.merge(hardware: [{ 'generic_type' => 'lift' }]), nil).length,
                        'vyklop VEPO (:kit) neblokuje — plan tiez nie')
  end
  # export pouziva TIE ISTE dovody — len ich formatuje
  col = base.merge(newer_configs: ['CAB-009'])
  NxTest.assert_equal(f::PC.export_blocked_status(f::PC.newer_config_reasons(col)), f::PC.newer_config_stop(col))
  lb = f.body('ui/production_core.rb', 'layout_block_reasons')
  %w[newer_config_reasons cut_blockers drawer_reasons].each { |fn| NxTest.assert(lb.include?(fn), fn) }
  NxTest.assert(lb.include?('scope: :kit'), 'ta ista brana ako VEPO export')
  %w[drawer_stop newer_config_stop].each do |fn|
    NxTest.assert(f.body('ui/production_core.rb', fn).include?('export_blocked_status'), "#{fn} formatuje dovody")
  end
end

# ============================================================================
# 4. PAYLOAD SEKCIE — natívny kľúč cez refs_for (B2), globálny stav (B4), F10
# ============================================================================

NxTest.test('NP-3 payload (B2): oko nesie NATIVNY kluc — prejde JSON-om aj Ruby resolverom refs_for') do
  f = NxNp3
  rows = [f.row, f.row('names' => ['Dlhy'], 'length' => 2795.0, 'grain_direction' => 'none'),
          f.row('names' => ['ABS'], 'length' => 500.0, 'edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil })]
  bom = { rows: rows }
  lay = f.plan(rows)
  pay = f::PC.sheet_layout_payload(lay, bom, f::SHEETS, f.estimate(rows))
  m = pay['materials'].find { |x| x['id'] == 'H18' }
  keys = m['rows'].map { |r| r['k'] } + m['rejected'].map { |e| e['k'] }
  NxTest.assert_equal(3, keys.compact.length, 'kazdy vyberatelny riadok (karta, cerveny zoznam) ma kluc')
  keys.each do |k|
    data = JSON.parse({ 'gen' => 1, 'parts_key' => k, 'origin' => 'cut' }.to_json)
    pids = f::PC.refs_for(bom, data)
    NxTest.assert_equal(1, pids.length, "kluc #{k.inspect} najde riadok kusovnika")
  end
  NxTest.assert(m['unplaced'][0]['t'].include?('hlási aj Kontrola'), m['unplaced'][0]['t'])
  NxTest.assert(m['rejected'][0]['t'].start_with?('VEPO riadok odmietne — neznáma ABS'), m['rejected'][0]['t'])
  NxTest.assert_equal(['CAB-001', 1], m['rejected'][0].values_at('o', 'q'), 'udaje riadku doplnene podla kluca')
  # riadok, ktory v kusovniku nie je, oko nema (nikdy pids, nikdy klik do prazdna)
  pay2 = f::PC.sheet_layout_payload(lay, { rows: [] }, f::SHEETS, [])
  NxTest.assert_equal([nil], pay2['materials'][0]['rows'].map { |r| r['k'] }.uniq)
  js = f.src('ui/js/sheet_layout.js')
  NxTest.assert(js.include?('parts_key: key'), 'klient posiela kluc riadku')
  NxTest.refute(js =~ /pids\s*:/, 'nikdy pids (flush editov ich meni)')
end

NxTest.test('NP-3 payload: duplak = jeden hotovy dielec; prirez s pridavkom; suradnice na 0,1 mm (F10)') do
  f = NxNp3
  ms = { 'material_id' => 'H18', 'multiplier' => 2 }
  rows = [f.row('names' => ['Bočnica 36'], 'material_id' => 'H36', 'thickness' => 36.0, 'length' => 820.0, 'width' => 580.0,
                'quantity' => 3, 'material_source' => ms)]
  lay = f.plan(rows, params: { 'kerf' => 4.4, 'dup_allowance' => 10.0 })
  pay = f::PC.sheet_layout_payload(lay, { rows: rows }, f::SHEETS, f.estimate(rows))
  r = pay['materials'][0]['rows'][0]
  NxTest.assert_equal([true, 2, 6, 3], r.values_at('d', 'm', 'c', 'q'), '3 hotove kusy = 6 prirezov')
  NxTest.assert_equal([840.0, 600.0, 820.0, 580.0], r.values_at('l', 'w', 'fl', 'fw'))
  xs = pay['materials'][0]['plates'].flat_map { |p| p['p'].map { |_i, x, _y| x } }
  NxTest.assert(xs.include?(844.4), "prerez 4,4 mm ostava na 0,1 mm (#{xs.inspect})")
  NxTest.assert(xs.all? { |x| (x * 10).round(6) == (x * 10).round }, 'rozlisenie 0,1 mm')
end

NxTest.test('NP-3 payload (B4): dielce BEZ materialu a blokacia celej zakazky su globalny stav') do
  f = NxNp3
  rows = [f.row('names' => ['Bez'], 'material_id' => '', 'quantity' => 3)]
  lay = f.plan(rows, blocked: { 'all' => 'VEPO export by sa zastavil: x' })
  lay['blocked_all'] = 'VEPO export by sa zastavil: x'
  pay = f::PC.sheet_layout_payload(lay, { rows: rows }, f::SHEETS, [])
  NxTest.assert_equal([], pay['materials'], 'ziadny material — ziadna karta')
  NxTest.assert_equal([1, 3], pay['without_material'].values_at('rows', 'pieces'))
  NxTest.assert_equal('VEPO export by sa zastavil: x', pay['blocked'])
  NxTest.assert_equal(%w[ok params source unreliable blocked without_material materials].sort, pay.keys.sort)
end

NxTest.test('NP-3 payload: predvoleny zdroj parametrov (seed_fallback) = unreliable + veta karty orientacna') do
  f = NxNp3
  rows = [f.row]
  lay = f.plan(rows, source: 'seed_fallback')
  pay = f::PC.sheet_layout_payload(lay, { rows: rows }, f::SHEETS, f.estimate(rows))
  NxTest.assert_equal(true, pay['unreliable'])
  NxTest.assert(pay['materials'][0]['phrase']['text'].start_with?('orientačne'))
  # F8: TA ISTA veta v poznamke rozpoctu (aj XLSX) — nikdy „horná hranica"
  note = f::SL.budget_note(lay, 'H18', f::SHEETS)
  NxTest.assert_equal("plán: #{pay['materials'][0]['phrase']['text']}", note)
  NxTest.refute(note.include?('horná hranica'), note)
  NxTest.assert(f::SL.budget_note(f.plan(rows, source: 'unreadable'), 'H18', f::SHEETS).include?('orientačne'))
end

NxTest.test('NP-3 payload: „hlási aj Kontrola" len pri materiali, ktory Kontrola kontroluje (nie UNI/bez formatu)') do
  f = NxNp3
  rows = [f.row('material_id' => 'UNI', 'length' => 2900.0, 'grain_direction' => 'none'),
          f.row('material_id' => 'W18', 'length' => 2900.0, 'grain_direction' => 'none'),
          f.row('material_id' => 'H18', 'length' => 2900.0),
          f.row('material_id' => 'W18', 'length' => 600.0, 'width' => 2400.0, 'grain_direction' => 'none')]
  pay = f::PC.sheet_layout_payload(f.plan(rows), { rows: rows }, f::SHEETS, [])
  t = ->(id) { pay['materials'].find { |m| m['id'] == id }['unplaced'].map { |g| g['t'] } }
  NxTest.assert_equal(['nezmestí sa ani otočený'], t.call('UNI'), 'UNI Kontrola nekontroluje')
  NxTest.assert_equal(['nezmestí sa (s kresbou sa neotáča) — hlási aj Kontrola'], t.call('H18'))
  w = t.call('W18')
  NxTest.assert(w.include?('nezmestí sa ani otočený — hlási aj Kontrola'), w.inspect)
  NxTest.assert(w.any? { |x| x.start_with?('nezmestí sa bez otočenia (plán neotáča)') && x.include?('Kontrola nehlási') },
                'needs_rotation: Kontrola ho nehlási')
end

# ============================================================================
# 5. PUSH STUDIA — jeden zber, ten isty plan pre sekciu aj rozpocet
# ============================================================================

NxTest.test('NP-3 push: plan z TOHO ISTEHO zberu (ziadny druhy sken), ten isty plan dostane rozpocet aj sekcia') do
  f = NxNp3
  push = f.body('ui/studio_dialog.rb', 'push_state')
  NxTest.assert_equal(1, push.scan('ProductionCore.fresh_collect(').length, 'jeden zber na push')
  NxTest.refute(push.include?('Bom.collect'), 'ziadny druhy sken modelu')
  NxTest.assert(push.include?('layout = ProductionCore.layout_for(collected, bom, smap, hw_exp)'))
  NxTest.assert(push.include?('budget_payload(model, bom, collected, estimate, hw_exp, smap, layout)'))
  # NP-4 (predrecenzia P2): sekcia dostane aj TEN ISTY rozpocet („v rozpočte N").
  NxTest.assert(push.include?('sheet_layout: ProductionCore.sheet_layout_payload(layout, bom, smap, estimate, budget)'))
  NxTest.assert(push.index('layout_for') < push.index('budget_payload'), 'plan pred rozpoctom')
  lf = f.body('ui/production_core.rb', 'layout_for')
  %w[fresh_collect Bom.collect Bom.compute].each { |bad| NxTest.refute(lf.include?(bad), "layout_for nesmie #{bad}") }
  NxTest.assert(lf.include?('control_layout(edges_map)'), 'TIE ISTE parametre ako Kontrola')
  NxTest.assert(lf.include?('rescue StandardError'), 'fail-soft (F7)')
  bp = f.body('ui/production_core.rb', 'budget_payload')
  NxTest.assert(bp.include?('lay = layout || layout_for(collected, bom, smap, exp)'), 'bez planu si ho spocita sam')
  NxTest.assert(bp.include?('sheet_layout: lay'))
  # vsetkych 5 volajucich ide cez budget_payload (plan tak nesu vsetci)
  pc = f.src('ui/production_core.rb')
  NxTest.assert_equal(4, pc.scan(/(?<!def )budget_payload\(model, bom, collected/).length,
                      'VEPO, XLSX rozpoctu, XLSX ponuky, prepocet cien')
  NxTest.assert_equal(1, f.src('ui/studio_dialog.rb').scan('ProductionCore.budget_payload(').length, 'push Studia')
end

NxTest.test('NP-3 budget_payload: bez planu ho spocita z toho isteho zberu; s planom ho neprepocitava') do
  f = NxNp3
  rows = [f.row]
  seen = []
  calls = 0
  fake_plan = f.plan(rows)
  f.with_stubs(f::E::Budget, payload_for: ->(_m, _b, **kw) { seen << kw[:sheet_layout]; { 'ok' => true } }) do
    f.with_stubs(f::PC, layout_for: ->(*_a) { calls += 1; fake_plan },
                        edges_map: ->(*_a) { {} }, hardware_catalog_items: ->(*_a) { nil }) do
      col = { records: [] }
      exp = { 'rows' => [], 'unmapped' => [] }
      f::PC.budget_payload(:model, { rows: rows }, col, nil, exp, f::SHEETS)
      NxTest.assert_equal(1, calls, 'plan si spocita sam')
      f::PC.budget_payload(:model, { rows: rows }, col, nil, exp, f::SHEETS, fake_plan)
      NxTest.assert_equal(1, calls, 'hotovy plan sa neprepocitava')
    end
  end
  NxTest.assert_equal([fake_plan, fake_plan], seen, 'rozpocet dostane ten isty plan')
end

# ============================================================================
# 6. OKO A VETA STATUSU, LIMIT VELKOSTI A CASU
# ============================================================================

NxTest.test('NP-3 oko: vlastna veta statusu (vsetky rovnake kusy, bez kroku Spat)') do
  f = NxNp3
  NxTest.assert_equal('Vybraný 1 kus v modeli — všetky rovnaké kusy riadku kusovníka, aj z iných platní. ' \
                      'Je to len výber, krok Späť nevzniká.', f::PC.cut_select_status(1))
  NxTest.assert(f::PC.cut_select_status(3).start_with?('Vybrané 3 kusy'))
  NxTest.assert(f::PC.cut_select_status(6).start_with?('Vybraných 6 kusov'))
  sel = f.body('ui/production_core.rb', 'do_select')
  NxTest.assert(sel.include?("data['origin'] == 'cut'"), 'veta len pre oko planu, vyber ide cestou parts_key')
end

NxTest.test('NP-3 limit (F9): ~2000 obdlznikov — payload sekcie <= 250 kB, vypocet + JSON <= 150 ms') do
  f = NxNp3
  rows = []
  mids = %w[H18 W18 PD]
  400.times do |i|
    mid = mids[i % 3]
    rows << f.row('names' => ["P#{i}"], 'material_id' => mid, 'thickness' => mid == 'PD' ? 38.0 : 18.0,
                  'length' => 150.0 + (i * 37) % 1100, 'width' => 80.0 + (i * 53) % (mid == 'PD' ? 400 : 700),
                  'quantity' => 5, 'grain_direction' => 'none', 'kde' => [{ 'owner_id' => "CAB-#{i % 60}" }])
  end
  bom = { rows: rows }
  est = f.estimate(rows)
  best = nil
  bytes = 0
  push_bytes = 0
  3.times do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    lay = f.plan(rows)
    pay = f::PC.sheet_layout_payload(lay, bom, f::SHEETS, est)
    js = pay.to_json
    ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0
    best = ms if best.nil? || ms < best
    bytes = js.bytesize
    data = { rows: rows, sheet_estimate: est, budget: f.budget(rows, lay), sheet_layout: pay }
    push_bytes = data.to_json.bytesize
  end
  puts "    [NP-3 limit] #{rows.sum { |r| r['quantity'] }} obdlznikov: sheet_layout #{bytes} B, " \
       "cast pushu (rows+odhad+rozpocet+plan) #{push_bytes} B, vypocet+JSON #{best.round(1)} ms"
  NxTest.assert(bytes <= 250_000, "payload #{bytes} B")
  NxTest.assert(best <= 150.0, "cas #{best.round(1)} ms")
end

# Predrecenzia P3-1 (audit F9): meria sa CELY `data.to_json` skutocneho
# `StudioDialog.push_state` — zber, kusovnik, odhad, kontrola, rozpocet aj plan
# idu realnym kodom nad syntetickou zakazkou (~2000 dielcov). Zastubovane su
# len vstupy z modelu (zber, katalogy) a sekcie katalogov, ktore s velkostou
# ZAKAZKY nerastu (materialy, kovanie, spotrebice, pravidla, sablony, nastavenia).
module NxNp3Push
  class FakeModel < NxTest::FakeEntity
    def title
      'SYNT_2000'
    end
  end

  EDGES = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.freeze

  module_function

  def collected
    mids = %w[H18 W18 PD]
    recs = []
    pid = 0
    400.times do |i|
      mid = mids[i % 3]
      5.times do |k|
        pid += 1
        recs << { 'name' => "P#{i}", 'part_key' => "cabinet/p#{i}:#{k}", 'owner_id' => "CAB-#{(i * 5 + k) % 60}",
                  'pid' => pid, 'role' => 'shelf', 'length' => 150.0 + (i * 37) % 1100,
                  'width' => 80.0 + (i * 53) % (mid == 'PD' ? 400 : 700),
                  'thickness' => mid == 'PD' ? 38.0 : 18.0, 'quantity' => 1, 'material_id' => mid,
                  'grain_direction' => 'none', 'edges' => EDGES.dup }
      end
    end
    { records: recs, hardware: [], hardware_overrides: [], cabinet_sets: {}, cabinet_set_conflicts: {},
      placements: [], warnings: [], identities: [], hardware_issues: [], cut_issues: [] }
  end

  # -> [bajty celeho JSON pushu, ms celeho push_state, data]
  def push(col)
    e = Noxun::Engine
    sd = e::StudioDialog
    pc = e::ProductionCore
    sent = nil
    model = FakeModel.new
    sk = Module.new
    sk.define_singleton_method(:active_model) { model }
    Object.const_set(:Sketchup, sk)
    stubs_sd = { js: ->(s) { sent = s; true }, mat_payload: ->(*_a) { nil }, hw_payload: ->(*_a) { nil },
                 appl_payload: ->(*_a) { nil }, rules_payload: ->(*_a) { nil }, tpl_payload: ->(*_a) { nil },
                 settings_payload: ->(*_a) { nil } }
    stubs_pc = { fresh_collect: ->(*_a) { col }, sheets_map: ->(*_a) { NxNp3::SHEETS },
                 edges_map: ->(*_a) { {} }, hardware_expansion: ->(*_a) { { 'rows' => [], 'unmapped' => [] } },
                 hardware_catalog_items: ->(*_a) { nil }, model_guid: ->(*_a) { 'g' },
                 project_name: ->(*_a) { 'SYNT' }, default_project_name: ->(*_a) { 'SYNT' },
                 merge_18_36: ->(*_a) { true } }
    checks = [e.const_defined?(:EdgeCheck) ? e::EdgeCheck : nil, e.const_defined?(:GrainCheck) ? e::GrainCheck : nil,
              e.const_defined?(:DirectionCheck) ? e::DirectionCheck : nil].compact
    ms = nil
    NxNp3.with_stubs(sd, stubs_sd) do
      NxNp3.with_stubs(pc, stubs_pc) do
        with_checks(checks) do
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sd.send(:push_state)
          ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0
        end
      end
    end
    json = sent.to_s[/\ANX\.setStudio\((.*)\)\z/m, 1].to_s
    [json.bytesize, ms, JSON.parse(json)]
  ensure
    Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup, false)
  end

  def with_checks(mods, &blk)
    return blk.call if mods.empty?

    NxNp3.with_stubs(mods.first, ui_state: ->(*_a) { nil }) { with_checks(mods.drop(1), &blk) }
  end
end

# Limity podla merania 29.9.2026 s rezervou: cely JSON 377 kB (z toho kusovnik
# 247 kB, plan 118 kB, rozpocet 10 kB) -> 450 kB (~20 %); push_state ~105 ms
# lokalne -> 250 ms (CI je pomalsi). Nafuknuta ktorakolvek cast pushu limit prekroci.
NxTest.test('NP-3 limit (F9, predrecenzia P3-1): CELY JSON pushu Studia ~2000 dielcov <= 450 kB a <= 250 ms') do
  NxTest.skip!('headless: docasna konstanta Sketchup') unless NxTest.headless?
  col = NxNp3Push.collected
  best = nil
  bytes = 0
  data = nil
  NxNp3.with_sandbox do
    3.times do
      b, ms, d = NxNp3Push.push(col)
      bytes = b
      data = d
      best = ms if best.nil? || ms < best
    end
  end
  parts = %w[rows control budget sheet_layout].map { |k| "#{k} #{data[k].to_json.bytesize}" }.join(', ')
  puts "    [NP-3 push] #{col[:records].length} dielcov: cely JSON pushu #{bytes} B (#{parts}), push_state #{best.round(1)} ms"
  NxTest.assert(data['sheet_layout'].is_a?(Hash) && data['sheet_layout']['ok'], 'push nesie plan')
  NxTest.assert(data['budget'].is_a?(Hash), 'push nesie rozpocet')
  NxTest.assert_equal(2000, data['rows'].sum { |r| r['quantity'].to_i }, 'kusovnik celej zakazky')
  NxTest.assert(bytes <= 450_000, "cely JSON pushu #{bytes} B (limit 450 kB)")
  NxTest.assert(best <= 250.0, "push_state #{best.round(1)} ms (limit 250 ms)")
end

# ============================================================================
# 7. TEMA A STYLY (F12)
# ============================================================================

NxTest.test('NP-3 tema (F12): pravidla .np-* a SVG platne len cez tokeny --nx-*, bez tvrdych farieb') do
  f = NxNp3
  html = f.src('ui/studio.html')
  rules = html.scan(/^\s*(\.(?:studio \.)?np[a-z-]*[^{]*)\{([^}]*)\}/m)
  NxTest.assert(rules.length >= 40, "pravidla sekcie sa nasli (#{rules.length})")
  rules.each do |sel, decl|
    decl.scan(/(?:^|;)\s*(color|background|fill|stroke|border(?:-[a-z]+)?)\s*:\s*([^;]+)/).each do |prop, val|
      NxTest.refute(val =~ /#[0-9a-fA-F]{3,6}\b|rgba?\(|hsla?\(/, "#{sel.strip} #{prop}: #{val} (tvrda farba)")
      named = val.gsub(/var\(--nx-[a-z-]+\)|url\(#npHatch[SLD]\)/, '')
      NxTest.refute(named =~ /\b(red|green|blue|black|white|gray|grey|orange|yellow)\b/, "#{sel.strip}: pomenovana farba")
    end
  end
  js = f.src('ui/js/sheet_layout.js')
  NxTest.refute(js =~ /(?:fill|stroke)="/, 'SVG nema inline fill/stroke — len triedy')
  NxTest.refute(js =~ /rgba?\(|hsla?\(/, 'ziadne rgb()/hsl() v kresleni')
  NxTest.assert_equal(2, js.scan("style=\"background:' + hex").length,
                      'jedina datova farba = vzorka dekoru (karta + detail), mimo SVG')
  NxTest.assert(html.include?('id="npHatchS"') && html.include?('class="np-hatch"'), 'srafy maju farbu z triedy')
end
