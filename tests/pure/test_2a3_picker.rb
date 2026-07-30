# frozen_string_literal: true
# Testy 2A-3a: vyberove cesty ABS so strukturou (Ruby jadro, dual-mode).
#
# KONTRAKT DAVKY: zivy katalog je stale SCHEMA 1 a spravanie sa pri nom NEMENI
# — nove pravidla (schema-aware hrubky, nominalne triedy, picker abs_for_sheet,
# remap so zaznamami, pick_body_sheet structure guard, warnings plumbing) ziju
# VYHRADNE vo vetve SCHEMA 2. Jedina vedoma vynimka: AUTO_WIDTHS 22 -> 23
# GLOBALNE (audit N16 — oprava obchodneho udaju; testovane v test_abs_remap).
# Vsetko headless (APPDATA sandbox helpera).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

A3MAT = Noxun::Engine::Materials
A3STORE = Noxun::Engine::JsonFileStore
A3CB  = Noxun::Engine::CabinetBuilder
A3BB  = Noxun::Engine::BoardBuilder
A3CON = Noxun::Engine::Construction
A3VAL = Noxun::Engine::Validation
A3ABS = Noxun::Engine::AbsRules

# Docasne nainstaluje CELY katalog (sheets + edges + schema marker) a po bloku
# vrati bajt-presny povodny stav. Zapis ide priamo cez JsonFileStore (obchadza
# Materials.write guardy — testy potrebuju aj stavy, ktore by write odmietol).
def a3_with_catalog(sheets, edges, schema: 2)
  path = A3MAT.path
  A3MAT.catalog # seed, aby subor existoval
  before = File.binread(path)
  A3STORE.write(path, { 'std' => A3MAT::STD, 'schema' => schema,
                        'sheets' => sheets, 'edges' => edges })
  yield
ensure
  if before
    File.binwrite(path, before)
    A3STORE.invalidate(path)
  end
end

# Doska SCHEMA 2 (group_id + struktura).
def a3_sheet(id, group, structure, extra = {})
  { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => group,
    'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length',
    'color' => [200, 200, 200], 'production_class' => 'sheet',
    'group_id' => "GRP-#{group.upcase}", 'structure' => structure.to_s }
    .reject { |_k, v| v.is_a?(String) && v.empty? }.merge(extra)
end

# Paska SCHEMA 2 (group_id + struktura + volitelne universal/width).
def a3_edge(id, group, structure, thickness, width = nil, extra = {})
  rec = { 'abs_id' => id, 'decor' => group, 'thickness' => thickness,
          'color' => [200, 200, 200], 'group_id' => "GRP-#{group.upcase}" }
  rec['structure'] = structure.to_s unless structure.to_s.empty?
  rec['width'] = width if width
  rec.merge(extra)
end

# ---------------------------------------------------------------------------
# B1: schema-aware povolene hrubky ABS
# ---------------------------------------------------------------------------

NxTest.test('2a3: supported_edge_thickness? — schema 1 presne {1;2}, schema 2 obchodne hodnoty') do
  NxTest.assert(A3MAT.supported_edge_thickness?(1.0, 1))
  NxTest.assert(A3MAT.supported_edge_thickness?(2.0, 1))
  [0.4, 0.8, 1.2, 1.5].each do |th|
    NxTest.refute(A3MAT.supported_edge_thickness?(th, 1), "schema 1 NESMIE pustit #{th}")
  end
  [0.4, 0.8, 1.0, 1.2, 1.5, 2.0].each do |th|
    NxTest.assert(A3MAT.supported_edge_thickness?(th, 2), "schema 2 musi pustit #{th}")
  end
  NxTest.refute(A3MAT.supported_edge_thickness?(3.0, 2), 'mimo whitelistu ani schema 2')
  NxTest.refute(A3MAT.supported_edge_thickness?(0.5, 2))
end

NxTest.test('2a3: edge_thickness_options_label vymenuje hodnoty podla schemy') do
  NxTest.assert_equal('1/2', A3MAT.edge_thickness_options_label(1))
  NxTest.assert_equal('0,4/0,8/1/1,2/1,5/2', A3MAT.edge_thickness_options_label(2))
end

NxTest.test('2a3: load filter NEMAZE obchodne hrubky v SCHEMA 2 katalogu (audit B1)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S18', 'G1', 'ST9')]
  edges = [a3_edge('E08', 'G1', 'ST9', 0.8, 23.0),
           a3_edge('E15', 'G1', 'ST9', 1.5, 23.0),
           a3_edge('E04', 'G1', 'ST9', 0.4, 23.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    ids = A3MAT.edges.map { |a| a['abs_id'] }
    NxTest.assert_equal(%w[E08 E15 E04], ids, 'ziadna paska sa nesmie stratit')
    NxTest.assert(File.binread(A3MAT.path).include?('"E04"'), 'subor sa neprepisal filtrom')
  end
end

NxTest.test('2a3: load filter pri SCHEMA 1 reze presne ako dnes (dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S18', 'G1', 'ST9')]
  edges = [{ 'abs_id' => 'E10', 'decor' => 'G1', 'thickness' => 1.0, 'color' => [1, 2, 3] },
           { 'abs_id' => 'E08', 'decor' => 'G1', 'thickness' => 0.8, 'color' => [1, 2, 3] }]
  a3_with_catalog(sheets, edges, schema: 1) do
    ids = A3MAT.edges.map { |a| a['abs_id'] }
    NxTest.assert_equal(%w[E10], ids, '0.8 sa pri legacy katalogu odfiltruje (dnesok)')
  end
end

NxTest.test('2a3: normalize_edge berie hrubku podla schemy katalogu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  # SCHEMA 1 (seed stav): 0.8 sa odmietne uz pri normalize (dnesok).
  NxTest.assert_equal(nil, A3MAT.normalize_edge('abs_id' => 'X', 'decor' => 'D', 'thickness' => 0.8))
  a3_with_catalog([a3_sheet('S18', 'G1', 'ST9')], [], schema: 2) do
    rec = A3MAT.normalize_edge('abs_id' => 'X', 'decor' => 'G1', 'thickness' => 0.8,
                               'group_id' => 'GRP-G1', 'structure' => 'ST9')
    NxTest.refute(rec.nil?, 'schema 2 pusti 0.8')
    NxTest.assert_equal(0.8, rec['thickness'])
    NxTest.assert_equal(nil, A3MAT.normalize_edge('abs_id' => 'X', 'decor' => 'G1', 'thickness' => 0.5),
                        '0.5 nie je obchodna hodnota')
  end
end

NxTest.test('2a3: AUTO_WIDTHS = {23; 43} (N16 — jedina vedoma vynimka z dual-mode)') do
  NxTest.assert_equal([23.0, 43.0], A3MAT::AUTO_WIDTHS)
end

# ---------------------------------------------------------------------------
# B3/N17: nominalne triedy + resolver obchodnej hrubky (ciste funkcie)
# ---------------------------------------------------------------------------

NxTest.test('2a3: edge_thickness_class — nula4/jednotka/dvojka/nil') do
  NxTest.assert_equal(:nula4, A3MAT.edge_thickness_class(0.4))
  [0.8, 1.0, 1.2].each { |t| NxTest.assert_equal(:jednotka, A3MAT.edge_thickness_class(t), t.to_s) }
  [1.5, 2.0].each { |t| NxTest.assert_equal(:dvojka, A3MAT.edge_thickness_class(t), t.to_s) }
  NxTest.assert_equal(nil, A3MAT.edge_thickness_class(3.0))
  NxTest.assert_equal(nil, A3MAT.edge_thickness_class(0.5))
end

NxTest.test('2a3: resolver — jednotka preferuje 0,8 -> 1 -> 1,2') do
  cands = [a3_edge('E12', 'G', 'ST', 1.2, 23.0), a3_edge('E10', 'G', 'ST', 1.0, 23.0),
           a3_edge('E08', 'G', 'ST', 0.8, 23.0)]
  rec, reason = A3MAT.resolve_edge_thickness(cands, :jednotka, 18.0)
  NxTest.assert_equal('E08', rec['abs_id'])
  NxTest.assert_equal(nil, reason)
  rec2, = A3MAT.resolve_edge_thickness(cands.reject { |a| a['abs_id'] == 'E08' }, :jednotka, 18.0)
  NxTest.assert_equal('E10', rec2['abs_id'], 'bez 0,8 pada na 1,0')
end

NxTest.test('2a3: resolver — dvojka 2,0 -> 1,5 s reasonom abs_15_fallback') do
  full = [a3_edge('E20', 'G', 'ST', 2.0, 23.0), a3_edge('E15', 'G', 'ST', 1.5, 23.0)]
  rec, reason = A3MAT.resolve_edge_thickness(full, :dvojka, 18.0)
  NxTest.assert_equal('E20', rec['abs_id'])
  NxTest.assert_equal(nil, reason, '2,0 je plnohodnotna dvojka — bez warningu')
  rec2, reason2 = A3MAT.resolve_edge_thickness([a3_edge('E15', 'G', 'ST', 1.5, 23.0)], :dvojka, 18.0)
  NxTest.assert_equal('E15', rec2['abs_id'])
  NxTest.assert_equal('abs_15_fallback', reason2, 'vyber 1,5 = viditelne upozornenie')
end

NxTest.test('2a3: resolver — siroka prednostna hrubka nepada, uzka NEBLOKUJE dalsiu preferenciu') do
  cands = [a3_edge('E08', 'G', 'ST', 0.8, 23.0), a3_edge('E10', 'G', 'ST', 1.0, 43.0)]
  rec, reason = A3MAT.resolve_edge_thickness(cands, :jednotka, 38.0)
  NxTest.assert_equal('E10', rec['abs_id'], '38+2=40 > 23 -> preferovana 0,8 sirkovo nevyhovuje, berie sa 1,0/43')
  NxTest.assert_equal(nil, reason)
end

NxTest.test('2a3: resolver — reason rozlisuje chybajucu triedu od chybajucej sirky') do
  NxTest.assert_equal([nil, 'abs_nominal_missing'],
                      A3MAT.resolve_edge_thickness([a3_edge('E04', 'G', 'ST', 0.4, 23.0)], :jednotka, 18.0),
                      'skupina len 0,4 — jednotka sa NIKDY nerozriesi na 0,4')
  NxTest.assert_equal([nil, 'abs_nominal_missing'],
                      A3MAT.resolve_edge_thickness([a3_edge('E15', 'G', 'ST', 1.5, 23.0)], :jednotka, 18.0),
                      '1,5 je dvojka, nie jednotka')
  cands = [a3_edge('E10', 'G', 'ST', 1.0, 23.0)]
  NxTest.assert_equal([nil, 'abs_width_missing'], A3MAT.resolve_edge_thickness(cands, :jednotka, 38.0),
                      'trieda existuje, sirka nevyhovuje')
  NxTest.assert_equal([nil, 'abs_nominal_missing'], A3MAT.resolve_edge_thickness([], :jednotka, 18.0))
  NxTest.assert_equal([nil, 'abs_nominal_missing'], A3MAT.resolve_edge_thickness(cands, :nula4, 18.0),
                      'trieda :nula4 sa nikdy nevoli automaticky')
end

NxTest.test('2a3: resolver — tie-break abs_id v ramci hrubky') do
  cands = [a3_edge('B10', 'G', 'ST', 1.0, 23.0), a3_edge('A10', 'G', 'ST', 1.0, 23.0)]
  rec, = A3MAT.resolve_edge_thickness(cands.sort_by { |a| a['abs_id'] }, :jednotka, 18.0)
  NxTest.assert_equal('A10', rec['abs_id'])
end

# ---------------------------------------------------------------------------
# B3: abs_for_sheet — hierarchia skupina -> presna struktura -> universal -> nic
# ---------------------------------------------------------------------------

# Matica bezi nad sandbox katalogom SCHEMA 2 (abs_for_sheet cita Materials.edges).
def a3_pick(sheets, edges, sheet_id, nominal, part_th)
  a3_with_catalog(sheets, edges, schema: 2) do
    return A3MAT.abs_for_sheet(A3MAT.sheet(sheet_id), nominal, part_th)
  end
end

NxTest.test('2a3: picker — skupina bez ABS = abs_structure_missing') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  out = a3_pick([a3_sheet('S1', 'G1', 'ST9')], [], 'S1', :jednotka, 18.0)
  NxTest.assert_equal([nil, 'abs_structure_missing'], out)
end

NxTest.test('2a3: picker — cudzia struktura sa NIKDY nevybera, presna vyhrava aj s horsou preferenciou') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  edges = [a3_edge('EMG08', 'G1', 'MG', 0.8, 23.0),   # cudzia struktura, lepsia preferencia
           a3_edge('EST10', 'G1', 'ST9', 1.0, 23.0)]  # presna struktura, horsia preferencia
  out = a3_pick(sheets, edges, 'S1', :jednotka, 18.0)
  NxTest.assert_equal(['EST10', nil], out, 'struktura ma prednost pred preferenciou hrubky')
end

NxTest.test('2a3: picker — presna prilis uzka, pouzitelna hrubsia tej istej struktury') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9', 'thickness' => 38.0)]
  edges = [a3_edge('E08', 'G1', 'ST9', 0.8, 23.0), a3_edge('E10', 'G1', 'ST9', 1.0, 43.0)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 38.0)
  NxTest.assert_equal(['E10', nil], out)
end

NxTest.test('2a3: picker — exact vetva vyhrava nad universal (1,2 exact > 0,8 universal)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  edges = [a3_edge('EU08', 'G1', '', 0.8, 23.0, 'universal' => true),
           a3_edge('EX12', 'G1', 'ST9', 1.2, 23.0)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 18.0)
  NxTest.assert_equal(['EX12', nil], out, 'universal je az zachranna vetva')
end

NxTest.test('2a3: picker — dve prazdne struktury NIE su zhoda; universal je jedina cesta') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', '')] # doska BEZ struktury
  plain = [a3_edge('E10', 'G1', '', 1.0, 23.0)] # paska bez struktury, BEZ universal
  out = a3_pick(sheets, plain, 'S1', :jednotka, 18.0)
  NxTest.assert_equal([nil, 'abs_structure_missing'], out, 'prazdna=neznama, nie "rovnaka"')
  uni = [a3_edge('EU10', 'G1', '', 1.0, 23.0, 'universal' => true)]
  out2 = a3_pick(sheets, uni, 'S1', :jednotka, 18.0)
  NxTest.assert_equal(['EU10', nil], out2, 'universal:true je vedome "pasuje na vsetko"')
end

NxTest.test('2a3: picker — universal s malou sirkou = nic + abs_width_missing (sirka plati aj tu)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9', 'thickness' => 38.0)]
  edges = [a3_edge('EU10', 'G1', '', 1.0, 23.0, 'universal' => true)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 38.0)
  NxTest.assert_equal([nil, 'abs_width_missing'], out)
end

NxTest.test('2a3: picker — skupina len 0,4 = abs_nominal_missing; dvojka -> 1,5 s fallback reasonom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  only04 = [a3_edge('E04', 'G1', 'ST9', 0.4, 23.0)]
  NxTest.assert_equal([nil, 'abs_nominal_missing'], a3_pick(sheets, only04, 'S1', :jednotka, 18.0))
  only15 = [a3_edge('E15', 'G1', 'ST9', 1.5, 23.0)]
  NxTest.assert_equal(['E15', 'abs_15_fallback'], a3_pick(sheets, only15, 'S1', :dvojka, 18.0))
end

NxTest.test('2a3: picker — cudzia skupina nie je kandidat (ani presna struktura)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S1', 'G1', 'ST9')]
  edges = [a3_edge('ECUDZI', 'G2', 'ST9', 1.0, 23.0)]
  out = a3_pick(sheets, edges, 'S1', :jednotka, 18.0)
  NxTest.assert_equal([nil, 'abs_structure_missing'], out)
end

NxTest.test('2a3: picker — 5981 s dvoma 23/1 roznych struktur sa nikdy nemiesa') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('SMG', '5981', 'MG'), a3_sheet('SAF', '5981', 'AF')]
  edges = [a3_edge('EMG', '5981', 'MG', 1.0, 23.0), a3_edge('EAF', '5981', 'AF', 1.0, 23.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    NxTest.assert_equal(['EMG', nil], A3MAT.abs_for_sheet(A3MAT.sheet('SMG'), :jednotka, 18.0))
    NxTest.assert_equal(['EAF', nil], A3MAT.abs_for_sheet(A3MAT.sheet('SAF'), :jednotka, 18.0))
  end
end

# ---------------------------------------------------------------------------
# B2: warnings plumbing — zber pri resolve, agregacia, retaz do semaforu
# ---------------------------------------------------------------------------

# Params spodnej skrinky nad sandbox materialom.
def a3_cab_params(mat_id, overrides = {})
  { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
    'thickness' => 18.0, 'material_id' => mat_id, 'part_overrides' => overrides }
end

# Rozriesi vsetky dielce planu (ako build_into) a vrati [plan, issues].
def a3_resolve_all(params)
  cfg = A3CB.normalize(params)
  plan = A3CON.build_plan(cfg)
  overrides = cfg[:part_overrides] || {}
  issues = []
  eff = { 'body' => cfg[:material_id], 'front' => cfg[:front_material_id],
          'back' => cfg[:back_material_id] }
  plan[:parts].each do |pd|
    A3CB.resolve_part(pd, eff['body'], eff['front'], eff['back'], overrides, abs_issues: issues)
  end
  [plan, issues, cfg]
end

NxTest.test('2a3: warnings — resolve_part zbiera reason + attach do planu + re-validacia') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a3_with_catalog([a3_sheet('S18', 'G1', 'ST9')], [], schema: 2) do
    plan, issues, = a3_resolve_all(a3_cab_params('S18'))
    NxTest.assert(issues.length >= 4, "boky/dno/vrch maju pravidlo L1 — cakam zber (#{issues.length})")
    NxTest.assert(issues.all? { |i| i[:reason] == 'abs_structure_missing' && i[:code] == 'L1' })
    before = plan[:warnings].length
    A3CB.attach_abs_warnings!(plan, issues)
    added = plan[:warnings][before..]
    NxTest.assert_equal(issues.length, added.length, 'jeden warning na (part_key, reason)')
    w = added.find { |x| x['part_key'] == 'cabinet/side:left' }
    NxTest.refute(w.nil?, 'warning nesie part_key dielca')
    NxTest.assert_equal('abs_structure_missing', w['code'])
    NxTest.assert_equal(['L1'], w['data']['edges'])
    NxTest.assert(w['message'].include?('L1'), 'sprava vymenuje hrany')
  end
end

NxTest.test('2a3: warnings — hrany prepisane overridom sa NEHLASIA (override vitazi)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a3_with_catalog([a3_sheet('S18', 'G1', 'ST9')], [], schema: 2) do
    ov = { 'cabinet/side:left' => { 'edges' => { 'L1' => nil } } } # vedome "bez ABS"
    _plan, issues, = a3_resolve_all(a3_cab_params('S18', ov))
    NxTest.refute(issues.any? { |i| i[:part_key] == 'cabinet/side:left' },
                  'vedomy override nesmie vyrobit warning')
    NxTest.assert(issues.any? { |i| i[:part_key] == 'cabinet/side:right' },
                  'ostatne dielce hlasia dalej')
  end
end

NxTest.test('2a3: warnings — agregacia (part_key, reason) vymenuje hrany, nezlieva reasony') do
  entries = [
    { part_key: 'cabinet/front:1', name: 'Dvierka', code: 'L1', reason: 'abs_15_fallback' },
    { part_key: 'cabinet/front:1', name: 'Dvierka', code: 'W2', reason: 'abs_15_fallback' },
    { part_key: 'cabinet/front:1', name: 'Dvierka', code: 'W1', reason: 'abs_width_missing' }
  ]
  out = A3ABS.pick_warnings(entries)
  NxTest.assert_equal(2, out.length, 'dva reasony = dve polozky (nie 3, nie 1)')
  fb = out.find { |w| w['code'] == 'abs_15_fallback' }
  NxTest.assert_equal(%w[L1 W2], fb['data']['edges'], 'hrany vymenovane v poradi EDGE_ORDER')
  NxTest.assert(fb['message'].include?('L1, W2') && fb['message'].include?('1,5'))
  NxTest.assert_equal('warn', fb['severity'])
end

NxTest.test('2a3: warnings — retaz config -> collect tvar -> Validation.run = ORANGE polozka') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a3_with_catalog([a3_sheet('S18', 'G1', 'ST9')], [], schema: 2) do
    plan, issues, cfg = a3_resolve_all(a3_cab_params('S18'))
    A3CB.attach_abs_warnings!(plan, issues)
    stored = A3CB.merge_final(cfg, plan) # config korpusu (Bom.collect cita 'warnings')
    collected = {
      records: [],
      hardware_overrides: [],
      warnings: stored[:warnings].map { |w| w.merge('owner_id' => 'CAB-T1') }
    }
    control = A3VAL.run(collected)
    items = control['items'].select { |i| i['category'] == 'build' && i['stable_key'].include?('abs_structure_missing') }
    NxTest.assert(items.length >= 4, "semafor ma ORANGE polozky vyberu ABS (#{items.length})")
    NxTest.assert(items.all? { |i| i['severity'] == 'orange' && i['owner_id'] == 'CAB-T1' })
    side = items.find { |i| i['part_key'] == 'cabinet/side:left' }
    NxTest.refute(side.nil?, 'klik-select identita (part_key) prezila retaz')
  end
end

NxTest.test('2a3: warnings — doska: normalize -> board_config -> Validation.run (ORANGE)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a3_with_catalog([a3_sheet('S18', 'G1', 'ST9')], [], schema: 2) do
    cfg = A3BB.normalize('material_id' => 'S18', 'length' => 400.0, 'width' => 300.0)
    NxTest.assert(cfg[:warnings].is_a?(Array) && cfg[:warnings].length == 1,
                  "free_panel pravidlo L1 -> 1 warning (#{cfg[:warnings].inspect})")
    w = cfg[:warnings][0]
    NxTest.assert_equal('abs_structure_missing', w['code'])
    NxTest.assert_equal('board/main', w['part_key'])
    bcfg = A3BB.board_config(cfg)
    NxTest.assert(bcfg[:warnings].is_a?(Array), 'config dosky nesie warnings poslednej stavby')
    collected = { records: [], hardware_overrides: [],
                  warnings: bcfg[:warnings].map { |x| x.merge('owner_id' => 'BRD-T1') } }
    control = A3VAL.run(collected)
    NxTest.assert_equal(1, control['counts']['orange'])
    NxTest.assert(control['items'][0]['message_sk'].include?('L1'))
  end
end

NxTest.test('2a3: dual-mode — identicke vstupy: schema 1 presne dnesok, schema 2 rovnaky vysledok') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  legacy_sheet = { 'material_id' => 'S18', 'manufacturer' => 'Egger', 'decor' => 'G1',
                   'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length',
                   'color' => [1, 2, 3], 'production_class' => 'sheet' }
  legacy_edge = { 'abs_id' => 'E10', 'decor' => 'G1', 'thickness' => 1.0,
                  'width' => 23.0, 'color' => [1, 2, 3] }
  run_case = lambda do
    plan, issues, cfg = a3_resolve_all(a3_cab_params('S18'))
    resolved = A3CB.resolve_part(plan[:parts].find { |pd| pd[:role] == 'side_left' },
                                 cfg[:material_id], nil, nil, {})
    [resolved[:edges], issues]
  end
  a3_with_catalog([legacy_sheet], [legacy_edge], schema: 1) do
    edges1, issues1 = run_case.call
    NxTest.assert_equal('E10', edges1['L1'], 'schema 1: abs_for_decor presne ako dnes')
    NxTest.assert_equal([], issues1, 'schema 1 NIKDY nezbiera warnings (dual-mode)')
  end
  s2_sheet = legacy_sheet.merge('group_id' => 'GRP-G1', 'structure' => 'ST9')
  s2_edge = legacy_edge.merge('group_id' => 'GRP-G1', 'structure' => 'ST9')
  a3_with_catalog([s2_sheet], [s2_edge], schema: 2) do
    edges2, issues2 = run_case.call
    NxTest.assert_equal('E10', edges2['L1'], 'schema 2: abs_for_sheet vybral tu istu pasku')
    NxTest.assert_equal([], issues2)
  end
end

NxTest.test('2a3: dual-mode — doska pri schema 1 bez warnings kluca (config identicky s dneskom)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  legacy_sheet = { 'material_id' => 'S18', 'decor' => 'G1', 'type' => 'DTDL',
                   'thickness' => 18.0, 'grain' => 'length', 'color' => [1, 2, 3],
                   'production_class' => 'sheet' }
  a3_with_catalog([legacy_sheet], [], schema: 1) do
    cfg = A3BB.normalize('material_id' => 'S18', 'length' => 400.0, 'width' => 300.0)
    NxTest.refute(cfg.key?(:warnings), 'schema 1: ziadny zber (legacy log-only cesta)')
    NxTest.refute(A3BB.board_config(cfg).key?(:warnings), 'config bez noveho kluca')
  end
end

# ---------------------------------------------------------------------------
# F7/F8: remap_edges_v2 — stary AJ novy sheet, kompatibilita, 0,4 kontrakt
# ---------------------------------------------------------------------------

# Standardna remap zostava: stara skupina G1/ST9 -> nova skupina G2/XM.
def a3_remap_catalog
  sheets = [a3_sheet('OLD18', 'G1', 'ST9'), a3_sheet('NEW18', 'G2', 'XM')]
  edges = [
    a3_edge('EO10', 'G1', 'ST9', 1.0, 23.0),                       # zladena so starym sheetom
    a3_edge('EO20', 'G1', 'ST9', 2.0, 23.0),                       # dvojka zladena
    a3_edge('EO04', 'G1', 'ST9', 0.4, 23.0),                       # 0,4 zladena (kontrakt: nikdy auto)
    a3_edge('EOMG', 'G1', 'MG', 1.0, 23.0),                        # cudzia struktura V RAMCI skupiny
    a3_edge('EOUNI', 'G1', '', 1.0, 23.0, 'universal' => true),    # universal starej skupiny
    a3_edge('ECUDZI', 'G3', 'ST9', 1.0, 23.0),                     # cudzia skupina (kontrast)
    a3_edge('EN08', 'G2', 'XM', 0.8, 23.0),                        # nova skupina jednotka
    a3_edge('EN15', 'G2', 'XM', 1.5, 23.0)                         # nova skupina dvojka len 1,5
  ]
  [sheets, edges]
end

NxTest.test('2a3: remap v2 — meni LEN kompatibilne pasky, drzi triedu, kontrast/cudzia struktura/nil nedotknute') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    old_s = A3MAT.sheet('OLD18')
    new_s = A3MAT.sheet('NEW18')
    map = { 'L1' => 'EO10', 'L2' => nil, 'W1' => 'EOMG', 'W2' => 'ECUDZI' }
    out, lost = A3MAT.remap_edges_v2(map, old_s, new_s, 18.0)
    NxTest.assert_equal('EN08', out['L1'], 'jednotka 1,0 -> jednotka novej skupiny (0,8 preferencia)')
    NxTest.assert_equal(nil, out['L2'], 'nil (vedome bez ABS) sa nedotyka')
    NxTest.assert_equal('EOMG', out['W1'], 'cudzia struktura V RAMCI skupiny = vedoma volba — nedotknuta')
    NxTest.assert_equal('ECUDZI', out['W2'], 'cudzia skupina (kontrast) — nedotknuta')
    NxTest.assert_equal([], lost)
    NxTest.assert_equal(%w[L1 L2 W1 W2], out.keys, 'kompletna mapa ostava')
  end
end

NxTest.test('2a3: remap v2 — dvojka drzi triedu (2,0 -> 1,5 novej skupiny), universal sa remapuje') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    old_s = A3MAT.sheet('OLD18')
    new_s = A3MAT.sheet('NEW18')
    out, issues = A3MAT.remap_edges_v2({ 'L1' => 'EO20', 'W1' => 'EOUNI' }, old_s, new_s, 18.0)
    NxTest.assert_equal('EN15', out['L1'], '2,0 -> dvojka novej skupiny (len 1,5)')
    NxTest.assert_equal('EN08', out['W1'], 'universal starej skupiny je kompatibilna — nasleduje material')
    # Codex GH #90 P1: uspesny fallback NIE JE strata, ale dovod NESMIE zmiznut —
    # issue nesie abs_id vybranej pasky (odlisenie od lost, kde abs_id chyba).
    NxTest.assert_equal([{ code: 'L1', reason: A3MAT::REASON_ABS_15, abs_id: 'EN15' }], issues,
                        'uspesny 1,5 fallback ide do issues s abs_id')
  end
end

NxTest.test('2a3: remap v2 — 0,4 sa NIKDY nenahradza automaticky: nil + lost abs_04_manual') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    out, lost = A3MAT.remap_edges_v2({ 'L1' => 'EO04' }, A3MAT.sheet('OLD18'), A3MAT.sheet('NEW18'), 18.0)
    NxTest.assert_equal(nil, out['L1'])
    NxTest.assert_equal([{ code: 'L1', reason: 'abs_04_manual' }], lost)
  end
end

NxTest.test('2a3: remap v2 — rovnaka skupina + struktura = nic na prevod (rucny vyber sa neprepisuje)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('OLD18', 'G1', 'ST9'), a3_sheet('OLD36', 'G1', 'ST9', 'thickness' => 36.0)]
  edges = [a3_edge('E43', 'G1', 'ST9', 1.0, 43.0), a3_edge('E23', 'G1', 'ST9', 1.0, 23.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    out, lost = A3MAT.remap_edges_v2({ 'L1' => 'E43' }, A3MAT.sheet('OLD18'), A3MAT.sheet('OLD36'), 36.0)
    NxTest.assert_equal([nil, []], [out, lost], '18 -> 36 v ramci skupiny+struktury necha rucnu 43-ku')
  end
end

NxTest.test('2a3: remap v2 — chybajuci zaznam/nil sheety = nic na prevod (defenziva)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    NxTest.assert_equal([nil, []], A3MAT.remap_edges_v2({ 'L1' => 'EO10' }, nil, A3MAT.sheet('NEW18'), 18.0))
    NxTest.assert_equal([nil, []], A3MAT.remap_edges_v2(nil, A3MAT.sheet('OLD18'), A3MAT.sheet('NEW18'), 18.0))
  end
end

NxTest.test('2a3: remap v2 cez remap_part_edge_overrides! — traversal so schema 2 katalogom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    params = a3_cab_params('OLD18')
    cfg = A3CB.normalize(params)
    side = A3CB.plan_parts_by_key(params).find { |_k, pd| pd[:role].to_s == 'side_left' }&.first
    NxTest.refute(side.nil?)
    params['part_overrides'] = { side => { 'edges' => { 'L1' => 'EO10', 'W1' => 'EO04' } } }
    old_eff = { 'body' => 'OLD18', 'front' => nil, 'back' => nil }
    new_eff = old_eff.merge('body' => 'NEW18')
    result = A3CB.remap_part_edge_overrides!(params, old_eff, new_eff)
    NxTest.assert_equal(1, result['changed'])
    ov = params['part_overrides'][side]['edges']
    NxTest.assert_equal('EN08', ov['L1'])
    NxTest.assert_equal(nil, ov['W1'], '0,4 zhodena na nil')
    NxTest.assert_equal(1, result['lost'].length)
    NxTest.assert(result['lost'][0].include?('W1') && result['lost'][0].include?('0,4'),
                  "lost label nesie 0,4 dovetok (#{result['lost'].inspect})")
    # Codex GH #90 P1: remapove dovody sa ZAPISU k overridu (sticky pre KONTROLU)
    ew = params['part_overrides'][side]['edge_warnings']
    NxTest.assert(ew.is_a?(Hash) && ew.key?('W1'), "edge_warnings nesie W1 (#{ew.inspect})")
    NxTest.assert_equal({ 'reason' => 'abs_04_manual', 'abs_id' => nil }, ew['W1'])
    NxTest.refute(ew.key?('L1'), 'uspesny vyber BEZ dovodu warning nedostava')
    _cfg = cfg
  end
end

NxTest.test('2a3: sticky remap warnings — resolve emituje kym hodnota sedi, zmena hrany ich uprace (GH #90 P1)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    params = a3_cab_params('NEW18')
    side = A3CB.plan_parts_by_key(params).find { |_k, pd| pd[:role].to_s == 'side_left' }&.first
    NxTest.refute(side.nil?)
    params['part_overrides'] = { side => {
      'edges' => { 'L1' => 'EN15', 'W1' => nil },
      'edge_warnings' => { 'L1' => { 'reason' => A3MAT::REASON_ABS_15, 'abs_id' => 'EN15' },
                           'W1' => { 'reason' => 'abs_04_manual', 'abs_id' => nil } }
    } }
    _plan, issues, cfg = a3_resolve_all(params)
    NxTest.assert(cfg[:part_overrides][side].key?('edge_warnings'),
                  'norm_overrides passthrough drzi edge_warnings (round-trip)')
    mine = issues.select { |it| it[:part_key] == side }
    NxTest.assert_equal(%w[abs_04_manual abs_15_fallback], mine.map { |it| it[:reason].to_s }.sort,
                        "sticky dovody sa emituju do kolektora (#{mine.inspect})")
    # pouzivatel zmeni L1 na inu pasku a W1 olepi -> zaznamy su neplatne
    params['part_overrides'][side]['edges'] = { 'L1' => 'EN08', 'W1' => 'EN08' }
    _plan2, issues2, cfg2 = a3_resolve_all(params)
    NxTest.assert_equal([], issues2.select { |it| it[:part_key] == side },
                        'po zmene hodnot ziadne sticky warnings')
    NxTest.refute(cfg2[:part_overrides][side].key?('edge_warnings'),
                  'neplatne zaznamy sa upratali z overridu (prune prezije do configu)')
  end
end

NxTest.test('2a3: remap v2 — zmena hrubkoveho variantu v skupine pre-resolvuje UZKU pasku (GH #90 P1 2. kolo)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('OLD18', 'G1', 'ST9'), a3_sheet('OLD36', 'G1', 'ST9', 'thickness' => 36.0)]
  edges = [a3_edge('E23', 'G1', 'ST9', 1.0, 23.0), a3_edge('E43', 'G1', 'ST9', 1.0, 43.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    # uzka 23 na 36 mm dielci uz nesedi -> pre-resolve v ramci struktury na 43
    out, issues = A3MAT.remap_edges_v2({ 'L1' => 'E23' }, A3MAT.sheet('OLD18'), A3MAT.sheet('OLD36'), 36.0)
    NxTest.assert_equal('E43', out['L1'], 'uzka paska sa vymeni za sirsiu tej istej struktury')
    NxTest.assert_equal([], issues)
    # siroka 43 sedi -> rucny vyber sa NEPREPISUJE (kontrakt drzi)
    out2, = A3MAT.remap_edges_v2({ 'L1' => 'E43' }, A3MAT.sheet('OLD18'), A3MAT.sheet('OLD36'), 36.0)
    NxTest.assert_equal(nil, out2, 'vyhovujuca paska = nic na prevod')
    # bez sirsej alternativy -> nil + width reason
    A3MAT.delete_edge('E43')
    out3, issues3 = A3MAT.remap_edges_v2({ 'L1' => 'E23' }, A3MAT.sheet('OLD18'), A3MAT.sheet('OLD36'), 36.0)
    NxTest.assert_equal(nil, out3['L1'])
    NxTest.assert_equal([{ code: 'L1', reason: A3MAT::REASON_ABS_WIDTH }], issues3)
  end
end

NxTest.test('2a3: pick_warning_message — abs_04_manual ma vlastnu spravu (GH #90 P2 2. kolo)') do
  msg = Noxun::Engine::AbsRules.pick_warning_message('abs_04_manual', 'Bok', ['L1'])
  NxTest.assert(msg.include?('0,4') && msg.include?('ručne'), msg)
  NxTest.refute(msg.include?('štruktúrou'), 'sprava neklame o strukture')
end

NxTest.test('2a3: sticky merge per hranu — remap inej hrany NEZAHODI lost zaznam nil hrany (GH #90 P2 2. kolo)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    params = a3_cab_params('OLD18')
    side = A3CB.plan_parts_by_key(params).find { |_k, pd| pd[:role].to_s == 'side_left' }&.first
    NxTest.refute(side.nil?)
    # W1 je nil so sticky lost zaznamom (z minuleho remapu); L1 sa terazja remapuje
    params['part_overrides'] = { side => {
      'edges' => { 'L1' => 'EO10', 'W1' => nil },
      'edge_warnings' => { 'W1' => { 'reason' => 'abs_04_manual', 'abs_id' => nil } }
    } }
    old_eff = { 'body' => 'OLD18', 'front' => nil, 'back' => nil }
    new_eff = old_eff.merge('body' => 'NEW18')
    A3CB.remap_part_edge_overrides!(params, old_eff, new_eff)
    ew = params['part_overrides'][side]['edge_warnings']
    NxTest.assert(ew.is_a?(Hash) && ew.key?('W1'),
                  "lost zaznam nil hrany prezil remap inej hrany (#{ew.inspect})")
    NxTest.assert_equal('EN08', params['part_overrides'][side]['edges']['L1'])
  end
end

NxTest.test('2a3: board prune deli agregat — oprava jednej hrany NEZMAZE druhu (GH #90 P2 2. kolo)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bb = Noxun::Engine::BoardBuilder
  agg = Noxun::Engine::AbsRules.pick_warnings([
    { code: 'L1', reason: 'abs_structure_missing', part_key: 'board/main', name: 'Doska X' },
    { code: 'W1', reason: 'abs_structure_missing', part_key: 'board/main', name: 'Doska X' }
  ])
  NxTest.assert_equal(1, agg.length, 'sanity: jedna agregovana polozka pre 2 hrany')
  pruned = bb.prune_edge_warnings(agg, ['L1'], 'Doska X')
  NxTest.assert_equal(1, pruned.length, 'agregat sa rozdelil, nie zahodil')
  NxTest.assert_equal(['W1'], pruned[0]['data']['edges'])
  NxTest.assert(pruned[0]['message_sk'] ? pruned[0]['message_sk'].include?('W1') : pruned[0].values.join.include?('W1'))
  NxTest.assert_equal(nil, bb.prune_edge_warnings(agg, ['L2'], 'Doska X'), 'nedotknuty agregat = nil (nic sa nemeni)')
  NxTest.assert_equal([], bb.prune_edge_warnings(agg, %w[L1 W1], 'Doska X'), 'obe hrany prec = prazdne pole')
end

NxTest.test('2a3: board repick zlyhanych defaultov pri zmene materialu (GH #90 P2 2. kolo)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bb = Noxun::Engine::BoardBuilder
  sheets = [a3_sheet('BAD18', 'G1', 'ST9'), a3_sheet('GOOD18', 'G2', 'XM')]
  edges = [a3_edge('EG08', 'G2', 'XM', 0.8, 23.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    stored = Noxun::Engine::AbsRules.pick_warnings([
      { code: 'L1', reason: 'abs_structure_missing', part_key: 'board/main', name: 'Doska X' }
    ])
    cfg = { 'role' => 'free_panel', 'name' => 'Doska X', 'warnings' => stored }
    # novy sheet MA pouzitelnu pasku -> zlyhany default sa doplni, warning prec
    refill, fresh = bb.repick_failed_defaults(cfg, { 'L1' => nil, 'W1' => nil }, A3MAT.sheet('GOOD18'))
    NxTest.assert_equal('EG08', refill['L1'], 'zlyhany default sa doplnil z noveho sheetu')
    NxTest.refute(refill.key?('W1'), 'nil BEZ warningu = vedome bez ABS — nedotknuta')
    NxTest.assert_equal([], fresh)
    # novy sheet tiez bez pasky -> nil ostava + CERSTVY warning
    refill2, fresh2 = bb.repick_failed_defaults(cfg, { 'L1' => nil }, A3MAT.sheet('BAD18'))
    NxTest.assert_equal({ 'L1' => nil }, refill2)
    NxTest.assert_equal(1, fresh2.length, 'cerstvy warning k novemu sheetu')
  end
end

NxTest.test('2a3: board carry-over — rebuild s edges v configu NEZAHADZUJE ulozene warnings (GH #90 P2)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets, edges = a3_remap_catalog
  a3_with_catalog(sheets, edges, schema: 2) do
    stored = [{ 'code' => A3MAT::REASON_ABS_15, 'message' => 'test', 'part_key' => 'board/main',
                'data' => { 'edges' => ['L1'] } }]
    cfg = Noxun::Engine::BoardBuilder.normalize(
      'material_id' => 'NEW18', 'length' => 400.0, 'width' => 300.0,
      'edges' => { 'L1' => 'EN15' }, 'warnings' => stored
    )
    NxTest.assert_equal(stored, cfg[:warnings], 'ulozene warnings prezili rebuild bez zmeny hran')
    out = Noxun::Engine::BoardBuilder.board_config(cfg)
    NxTest.assert_equal(stored, out[:warnings], 'board_config ich uklada dalej')
    # cerstvy pravidlovy beh (bez edges) warnings NAHRADZA vysledkom pickera
    cfg2 = Noxun::Engine::BoardBuilder.normalize(
      'material_id' => 'NEW18', 'length' => 400.0, 'width' => 300.0, 'warnings' => stored
    )
    fresh = cfg2[:warnings]
    NxTest.refute(fresh == stored, 'picker beh stare warnings neprenasa (nahradza ich cerstvymi)')
  end
end

# ---------------------------------------------------------------------------
# F10: pick_body_sheet so schemou ako parametrom + prazdna struktura
# ---------------------------------------------------------------------------

NxTest.test('2a3: pick_body_sheet — schema 2 vyzaduje skupinu + NEPRAZDNU strukturu') do
  s_cur = a3_sheet('CUR18', 'G1', 'ST9')
  pool = [a3_sheet('C36A', 'G1', 'ST9', 'thickness' => 36.0),
          a3_sheet('C36B', 'G1', 'MG', 'thickness' => 36.0),
          a3_sheet('C36C', 'G2', 'ST9', 'thickness' => 36.0)]
  res = A3CB.pick_body_sheet(36.0, s_cur, pool, schema: 2)
  NxTest.assert_equal('C36A', res[:pick] && res[:pick]['material_id'],
                      'vybera sa LEN rovnaka skupina + struktura')
  NxTest.assert_equal(3, res[:candidates].length, 'kandidati do hlasky = vsetky hrubkovo vyhovujuce')
  # bez strukturnej zhody = ziadny pick (ani ked je jediny kandidat hrubky)
  res2 = A3CB.pick_body_sheet(36.0, s_cur, [pool[1]], schema: 2)
  NxTest.assert_equal(nil, res2[:pick], 'cudzia struktura sa NIKDY nevybera automaticky')
  res3 = A3CB.pick_body_sheet(36.0, s_cur, [pool[2]], schema: 2)
  NxTest.assert_equal(nil, res3[:pick], 'cudzia skupina sa NIKDY nevybera automaticky')
end

NxTest.test('2a3: pick_body_sheet — prazdna struktura current = ZIADEN auto vyber (schema 2)') do
  s_cur = a3_sheet('CUR18', 'G1', '')
  pool = [a3_sheet('C36A', 'G1', '', 'thickness' => 36.0)]
  res = A3CB.pick_body_sheet(36.0, s_cur, pool, schema: 2)
  NxTest.assert_equal(nil, res[:pick], 'prazdna struktura = neznama — zmena sa odmietne')
  NxTest.assert_equal(1, res[:candidates].length)
  # schema 1 to iste vyberie po starom (rovnaky dekor+typ) — dual-mode
  res1 = A3CB.pick_body_sheet(36.0, s_cur, pool)
  NxTest.assert_equal('C36A', res1[:pick] && res1[:pick]['material_id'], 'default schema: 1 = dnesok')
end

# ---------------------------------------------------------------------------
# F14: ensure_edge_for_sheet — SCHEMA 2 tvorba resolverom
# ---------------------------------------------------------------------------

NxTest.test('2a3: ensure v2 — existujucu najde cez abs_for_sheet (aj universal vetvou)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S18', 'G1', 'ST9')]
  edges = [a3_edge('EU10', 'G1', '', 1.0, 23.0, 'universal' => true)]
  a3_with_catalog(sheets, edges, schema: 2) do
    NxTest.assert_equal([:exists, 'EU10'], A3MAT.ensure_edge_for_sheet('S18', client_schema: 2))
  end
end

NxTest.test('2a3: ensure v2 — tvorba preberie jednotkovu hrubku POUZIVANU skupinou (0,8)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S18', 'G1', 'ST9')]
  edges = [a3_edge('EMG08', 'G1', 'MG', 0.8, 23.0)] # ina struktura => picker nic, ale skupina MA 0,8
  a3_with_catalog(sheets, edges, schema: 2) do
    status, abs_id = A3MAT.ensure_edge_for_sheet('S18', client_schema: 2)
    NxTest.assert_equal(:created, status)
    rec = A3MAT.edge(abs_id)
    NxTest.assert_equal(0.8, rec['thickness'], 'skupina pouziva 0,8 -> nova paska 0,8')
    NxTest.assert_equal('ST9', rec['structure'], 'struktura dosky (universal sa NEnastavuje)')
    NxTest.refute(rec.key?('universal'))
    NxTest.assert_equal('GRP-G1', rec['group_id'])
    NxTest.assert_equal(23.0, rec['width'])
    NxTest.assert(abs_id.include?('ST9'), "ID nesie strukturu (#{abs_id})")
  end
end

NxTest.test('2a3: ensure v2 — skupina bez jednotkovej pasky -> kanonicka 1,0 (nikdy 0,4)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('S18', 'G1', 'ST9')]
  edges = [a3_edge('E04', 'G1', 'ST9', 0.4, 23.0), a3_edge('E15', 'G1', 'ST9', 1.5, 23.0)]
  a3_with_catalog(sheets, edges, schema: 2) do
    status, abs_id = A3MAT.ensure_edge_for_sheet('S18', client_schema: 2)
    NxTest.assert_equal(:created, status)
    NxTest.assert_equal(1.0, A3MAT.edge(abs_id)['thickness'])
  end
end

NxTest.test('2a3: ensure v2 — bezstrukturna doska dava paske universal:true a picker ju hned najde (GH #90 P2 3. kolo)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheets = [a3_sheet('VLASTNA18', 'G9', '')]
  a3_with_catalog(sheets, [], schema: 2) do
    status, abs_id = A3MAT.ensure_edge_for_sheet('VLASTNA18', client_schema: 2)
    NxTest.assert_equal(:created, status)
    created = A3MAT.edge(abs_id)
    NxTest.assert_equal(true, created['universal'], 'bezstrukturna doska -> universal:true')
    NxTest.refute(created.key?('structure'), 'struktura sa nezapisuje')
    found, why = A3MAT.abs_for_sheet(A3MAT.sheet('VLASTNA18'), :jednotka, 18.0)
    NxTest.assert_equal(abs_id, found, "picker novu pasku hned najde (#{why.inspect})")
  end
end

NxTest.test('2a3: ensure v2 — stary klient pri SCHEMA 2 katalogu stale read-only (2A-2 kontrakt)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a3_with_catalog([a3_sheet('S18', 'G1', 'ST9')], [], schema: 2) do
    NxTest.assert_equal([:schema_read_only, nil], A3MAT.ensure_edge_for_sheet('S18'))
  end
end
