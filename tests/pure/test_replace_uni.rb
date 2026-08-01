# frozen_string_literal: true
# Testy V0.6 M-B2: „Nahradit UNI…" — cista klasifikacia hromadnej zameny UNI
# materialu za realny dekor (materials_replace_uni.rb).
#   Materials.replace_uni_classify   — scan entries -> jobs/writes/blocked/summary
#   Materials.replace_uni_empty?     — nic na nahradenie
#   Materials.replace_uni_pending_ok? — kontrakt potvrdenia (odtlacok planu)
# Scan adapter (replace_uni_scan) potrebuje SketchUp model — overuje ho
# su_runner.rb; tu sa scan struktura stavia rucne (data-in/data-out).
require_relative '../helper' unless defined?(NxTest)

NxTest.test('mb2 setup: cerstvy SCHEMA 2 seed s UNI sadou') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!, 'fresh seed sa nenainstaloval')
  NxTest.assert(Noxun::Engine::Materials.catalog_schema >= 2, 'seed ma byt SCHEMA 2+')
end

RUMAT = Noxun::Engine::Materials
RUCB  = Noxun::Engine::CabinetBuilder

RU_UNI_BODY  = 'K009_PW_DTDL_18'  # Korpus UNI (recyklovane fallback ID)
RU_UNI_FRONT = 'W1000_DTDL_18'    # Celo UNI
RU_UNI_BACK  = 'HDF_WHITE_3'      # HDF UNI
RU_UNI_BOARD = 'UNI_DOSKA_18'     # Doska UNI

def ru_seed_target(decor = 'K111', ths = [18.0, 18.6])
  ok, res = RUMAT.add_decor_batch(
    'batch_schema' => 3, 'decor' => decor, 'manufacturer' => 'Egger',
    'decor_name' => 'Testovaci dub', 'type' => 'DTDL', 'grain' => 'length',
    'color' => [10, 20, 30],
    'sheet_variants' => ths.map { |t| { 'thickness' => t, 'structure' => 'ST9' } },
    'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9' }]
  )
  raise "seed #{decor} zlyhal: #{res.inspect}" unless ok
  res
end

def ru_cleanup(*results)
  results.compact.each do |res|
    (res['sheets'] || []).each { |id| RUMAT.delete_sheet(id) }
    (res['edges'] || []).each { |id| RUMAT.delete_edge(id) }
  end
end

def ru_sheet_of(res, th)
  id = (res['sheets'] || []).find { |sid| (RUMAT.sheet(sid)['thickness'].to_f - th).abs < 0.01 }
  RUMAT.sheet(id)
end

def ru_params(over = {})
  { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
    'thickness' => 18.0 }.merge(over)
end

def ru_eff(body: nil, front: nil, back: nil)
  { 'body' => body || RU_UNI_BODY, 'front' => front || RU_UNI_FRONT,
    'back' => back || RU_UNI_BACK }
end

def ru_scan(cabs: [], boards: [], project: {})
  { 'cabs' => cabs, 'boards' => boards, 'project' => project, 'model_guid' => 'G-1' }
end

def ru_side_key(params)
  RUCB.plan_parts_by_key(params).find { |_k, pd| pd[:role].to_s == 'side_left' }&.first
end

# ---------------------------------------------------------------------------
# klasifikacia — explicitne roly, dedenie, overridy, dosky
# ---------------------------------------------------------------------------

NxTest.test('mb2: explicitny body UNI — prepis ID + prevzatie hrubky (adopting)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.6)
    scan = ru_scan(cabs: [['CAB-001', ru_params('material_id' => RU_UNI_BODY), ru_eff, 'raw1', :r1]])
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BODY), target)
    NxTest.assert_equal(['CAB-001'], out['adopting'])
    NxTest.assert_equal([], out['blocked'])
    NxTest.assert_equal(1, out['jobs_cab'].size)
    ref, params = out['jobs_cab'][0]
    NxTest.assert_equal(:r1, ref)
    NxTest.assert_equal(target['material_id'], params['material_id'], 'ID sa prepisalo')
    NxTest.assert_close(18.6, params['thickness'], 0.01, 'hrubka prevzata z ciela')
    NxTest.assert_equal(1, out['summary']['th_changes'].size)
    NxTest.assert_equal(1, out['summary']['th_changes'][0]['n'])
    NxTest.assert_equal(['CAB-001'], out['summary']['cabs_explicit'])
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: dediaca skrinka + projektova predvolba — writes + job bez nastavenia ID') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.0)
    scan = ru_scan(
      cabs: [['CAB-002', ru_params, ru_eff, 'raw2', :r2]],
      project: { 'default_material_id' => RU_UNI_BODY }
    )
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BODY), target)
    NxTest.assert_equal({ 'default_material_id' => target['material_id'] }, out['project_writes'])
    NxTest.assert_equal(['CAB-002'], out['recompute'], '18->18 = ziadna adopcia')
    ref, params = out['jobs_cab'][0]
    NxTest.assert_equal(:r2, ref)
    NxTest.assert(params['material_id'].to_s.strip.empty?, 'dediaca skrinka DALEJ dedi (ID sa nenastavuje)')
    NxTest.assert_equal(['CAB-002'], out['summary']['cabs_inherit'])
    NxTest.assert_equal(['Korpus'], out['summary']['project'])
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: skrinka BEZ vyskytu UNI sa do jobs nedostane') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.0)
    other = ru_sheet_of(res, 18.6)
    scan = ru_scan(cabs: [['CAB-003', ru_params('material_id' => other['material_id']),
                           ru_eff(body: other['material_id']), 'raw3', :r3]])
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BODY), target)
    NxTest.assert_equal([], out['jobs_cab'])
    NxTest.assert(RUMAT.replace_uni_empty?(out), 'nic na nahradenie')
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: part_override s UNI — prepis + pocitadlo; ABS override nasleduje dekor') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.0)
    base = ru_params
    side = ru_side_key(base)
    params = ru_params('material_id' => RU_UNI_BODY,
                       'part_overrides' => { side => { 'material_id' => RU_UNI_BODY } })
    scan = ru_scan(cabs: [['CAB-004', params, ru_eff, 'raw4', :r4]])
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BODY), target)
    NxTest.assert_equal(1, out['summary']['overrides_n'])
    _ref, jp = out['jobs_cab'][0]
    NxTest.assert_equal(target['material_id'], jp['part_overrides'][side]['material_id'])
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: back rola — vlastna cesta: target ID + PREVZATIE hrubky do back_thickness') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.6)
    params = ru_params('back_material_id' => RU_UNI_BACK, 'back_mode' => 'groove',
                       'back_thickness' => 3.0)
    scan = ru_scan(cabs: [['CAB-005', params, ru_eff, 'raw5', :r5]])
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BACK), target)
    NxTest.assert_equal([], out['blocked'])
    _ref, jp = out['jobs_cab'][0]
    NxTest.assert_equal(target['material_id'], jp['back_material_id'])
    NxTest.assert_close(18.6, jp['back_thickness'], 0.01, 'chrbat prevzal hrubku ciela')
    NxTest.assert_close(18.0, jp['thickness'], 0.01, 'telo sa nemeni')
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: back_mode none — ID sa prepise, hrubka chrbta sa NEDOTKNE') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.6)
    params = ru_params('back_material_id' => RU_UNI_BACK, 'back_mode' => 'none',
                       'back_thickness' => 3.0)
    scan = ru_scan(cabs: [['CAB-006', params, ru_eff, 'raw6', :r6]])
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BACK), target)
    _ref, jp = out['jobs_cab'][0]
    NxTest.assert_equal(target['material_id'], jp['back_material_id'])
    NxTest.assert_close(3.0, jp['back_thickness'], 0.01, 'bez chrbta = bez hrubkovej zmeny')
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: blokujuci dielec (vlastny material inej hrubky) = blocked :parts, all-or-nothing') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    t18 = ru_sheet_of(res, 18.0)
    t186 = ru_sheet_of(res, 18.6)
    base = ru_params
    side = ru_side_key(base)
    params = ru_params('material_id' => RU_UNI_BODY,
                       'part_overrides' => { side => { 'material_id' => t18['material_id'] } })
    scan = ru_scan(cabs: [['CAB-007', params, ru_eff, 'raw7', :r7]])
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BODY), t186)
    NxTest.assert_equal(1, out['blocked'].size)
    NxTest.assert_equal('CAB-007', out['blocked'][0][0])
    NxTest.assert_equal(:parts, out['blocked'][0][1])
    NxTest.assert_equal([], out['jobs_cab'], 'blokovana skrinka nema job')
    NxTest.assert(out['summary']['blocked'][0].include?('CAB-007'), 'rozpis blokacie nesie ID')
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: doska na UNI — prepis ID, zrusena duplak vazba, hrubka podla ciela v summary') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.6)
    cfg = { 'material_id' => RU_UNI_BOARD, 'thickness' => 12.0, 'length' => 600.0,
            'width' => 400.0, 'quantity' => 2, 'material_source' => { 'x' => 1 },
            'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
    scan = ru_scan(boards: [['BRD-001', cfg, 'rawb1', :rb1]])
    out = RUMAT.replace_uni_classify(scan, RUMAT.sheet(RU_UNI_BOARD), target)
    NxTest.assert_equal(1, out['jobs_board'].size)
    ref, merged = out['jobs_board'][0]
    NxTest.assert_equal(:rb1, ref)
    NxTest.assert_equal(target['material_id'], merged['material_id'])
    NxTest.refute(merged.key?('material_source'), 'zmena materialu rusi duplak vazbu')
    NxTest.assert_equal(1, out['summary']['boards'].size)
    NxTest.assert_close(12.0, out['summary']['boards'][0]['from'])
    NxTest.assert_close(18.6, out['summary']['boards'][0]['to'])
    NxTest.assert_close(12.0, cfg['thickness'], 0.01, 'povodny config sa NEmutuje (deep copy)')
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: front UNI + cielova hrubka nevhodna pre cela = blocked :front') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  # ru_project_target_issue je ta ista kontrola pre predvolbu aj skrinku
  NxTest.assert_equal(:front, RUMAT.ru_project_target_issue('default_front_material_id', 3.0))
  NxTest.assert_equal(nil, RUMAT.ru_project_target_issue('default_front_material_id', 18.6))
  NxTest.assert_equal(:range, RUMAT.ru_project_target_issue('default_material_id', 3.0))
  NxTest.assert_equal(nil, RUMAT.ru_project_target_issue('default_back_material_id', 18.0))
  NxTest.assert_equal(:range, RUMAT.ru_project_target_issue('default_back_material_id', 10.0))
end

# ---------------------------------------------------------------------------
# odtlacok planu + kontrakt potvrdenia
# ---------------------------------------------------------------------------

NxTest.test('mb2: digest — deterministicky; zmena configu entity meni odtlacok') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = ru_seed_target
  begin
    target = ru_sheet_of(res, 18.0)
    uni = RUMAT.sheet(RU_UNI_BODY)
    scan_a = ru_scan(cabs: [['CAB-001', ru_params('material_id' => RU_UNI_BODY), ru_eff, 'rawX', :r]])
    scan_b = ru_scan(cabs: [['CAB-001', ru_params('material_id' => RU_UNI_BODY), ru_eff, 'rawX', :r]])
    scan_c = ru_scan(cabs: [['CAB-001', ru_params('material_id' => RU_UNI_BODY), ru_eff, 'rawY', :r]])
    da = RUMAT.replace_uni_classify(scan_a, uni, target)['digest']
    db = RUMAT.replace_uni_classify(scan_b, uni, target)['digest']
    dc = RUMAT.replace_uni_classify(scan_c, uni, target)['digest']
    NxTest.assert_equal(da, db, 'rovnaky stav = rovnaky odtlacok')
    NxTest.refute(da == dc, 'iny surovy config = iny odtlacok')
  ensure
    ru_cleanup(res)
  end
end

NxTest.test('mb2: pending_ok? — zhoda prejde, kazdy zmeneny kluc zhodi suhlas') do
  fresh = { 'model_guid' => 'G-1', 'uni_id' => 'U', 'target_id' => 'T',
            'catalog_rev' => 'r1', 'digest' => 'd1' }
  NxTest.assert(RUMAT.replace_uni_pending_ok?(fresh.dup, fresh))
  %w[model_guid uni_id target_id catalog_rev digest].each do |k|
    bad = fresh.merge(k => 'INE')
    NxTest.refute(RUMAT.replace_uni_pending_ok?(bad, fresh), "zmena #{k} musi zhodit suhlas")
  end
  NxTest.refute(RUMAT.replace_uni_pending_ok?(nil, fresh))
  NxTest.refute(RUMAT.replace_uni_pending_ok?({}, nil))
end
