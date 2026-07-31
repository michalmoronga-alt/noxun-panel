# frozen_string_literal: true
# Testy D-46: projektova predvolba KORPUSU s inou hrubkou (potvrdzovacia lista
# namiesto tvrdeho stopu).
#   CabinetBuilder.adopt_thickness              — JEDNA implementacia prevzatia
#     katalogovej hrubky (panel D-45 aj davka D-46 volaju TOTO)
#   CabinetBuilder.classify_body_default_change — dry-run klasifikacia dediacich
#     skriniek: adopting / recompute / blocked + pripravene params davky
#   Materials.pending_default_ok?               — kontrakt potvrdenia (zastaraly
#     suhlas sa NIKDY nevykona slepo)
# Serverovu obalku (handle_set_project_material: ponuka -> potvrdenie -> 1 undo
# krok) testuje su_runner.rb, sekcia D-46.
require_relative '../helper' unless defined?(NxTest)

# 2A-4b: seedy su nativne SCHEMA 2 — tento subor overuje DUAL-MODE (legacy)
# spravanie, preto si ako prvy krok instaluje predcutoverovy legacy katalog
# (registrovany setup test — testy bezia sekvencne v poradi registracie).
NxTest.test('d46 setup: legacy SCHEMA 1 katalog (dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_legacy_catalog!, 'legacy katalog sa nenainstaloval')
  NxTest.assert_equal(1, Noxun::Engine::Materials.catalog_schema, 'sandbox ma byt SCHEMA 1')
end

D46CB  = Noxun::Engine::CabinetBuilder
D46MAT = Noxun::Engine::Materials

def d46_seed(tag, thicknesses, abs_tokens = '22/1')
  ok, res = D46MAT.add_decor_batch(
    'decor' => tag, 'manufacturer' => 'Test D46', 'type' => 'DTDL',
    'thicknesses' => thicknesses, 'abs_tokens' => abs_tokens
  )
  raise "seed #{tag} zlyhal: #{res.inspect}" unless ok
  res
end

def d46_cleanup(*results)
  results.compact.each do |res|
    (res['sheets'] || []).each { |id| D46MAT.delete_sheet(id) }
    (res['edges'] || []).each { |id| D46MAT.delete_edge(id) }
  end
end

def d46_sheet_of(res, th)
  id = (res['sheets'] || []).find { |sid| (D46MAT.sheet(sid)['thickness'].to_f - th).abs < 0.01 }
  D46MAT.sheet(id)
end

def d46_params(thickness = 18.0, overrides = {})
  { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
    'thickness' => thickness, 'part_overrides' => overrides }
end

def d46_key_for(params, role)
  D46CB.plan_parts_by_key(params).find { |_k, pd| pd[:role].to_s == role }&.first
end

def d46_eff(body_id)
  { 'body' => body_id, 'front' => 'FRONT_X', 'back' => 'BACK_X' }
end

# ---------------------------------------------------------------------------
# adopt_thickness — jedna implementacia prevzatia hrubky (D-45 + D-46)
# ---------------------------------------------------------------------------

NxTest.test('d46: adopt_thickness — sediaca hrubka je :same (params sa nedotkne)') do
  p = d46_params(18.6)
  state, extra = D46CB.adopt_thickness(p, 'thickness' => 18.6)
  NxTest.assert_equal(:same, state)
  NxTest.assert_equal(nil, extra)
  NxTest.assert_close(18.6, p['thickness'])
end

NxTest.test('d46: adopt_thickness — ina hrubka sa PREVEZME do params') do
  p = d46_params(18.0)
  state, = D46CB.adopt_thickness(p, 'thickness' => 18.6)
  NxTest.assert_equal(:adopted, state)
  NxTest.assert_close(18.6, p['thickness'], 0.01, 'hrubka korpusu sa riadi materialom')
end

NxTest.test('d46: adopt_thickness — hrubka mimo rozsahu (HDF 3) = :range, params bez zmeny') do
  p = d46_params(18.0)
  state, = D46CB.adopt_thickness(p, 'thickness' => 3.0)
  NxTest.assert_equal(:range, state)
  NxTest.assert_close(18.0, p['thickness'], 0.01, 'nic sa nemeni')
  # nezmyselny zaznam sa sprava ako "netreba nic" (ziadna vynimka)
  NxTest.assert_equal(:same, D46CB.adopt_thickness(p, 'thickness' => 0)[0])
  NxTest.assert_equal(:same, D46CB.adopt_thickness(p, nil)[0])
end

NxTest.test('d46: adopt_thickness — blokujuci dielec vrati mena a VRATI povodnu hrubku') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d46_seed('D46Adopt', '18, 18.6')
  begin
    s18 = d46_sheet_of(res, 18.0)
    s186 = d46_sheet_of(res, 18.6)
    side = d46_key_for(d46_params, 'side_left')
    p = d46_params(18.0, side => { 'material_id' => s18['material_id'] })
    state, blocked = D46CB.adopt_thickness(p, s186)
    NxTest.assert_equal(:blocked, state)
    NxTest.assert_equal(1, blocked.size, blocked.inspect)
    NxTest.assert(blocked[0].to_s.length.positive?, 'dielec sa vymenuje menom')
    NxTest.assert_close(18.0, p['thickness'], 0.01, 'params ostanu netknute, kym konflikt trva')
  ensure
    d46_cleanup(res)
  end
end

# ---------------------------------------------------------------------------
# dry-run klasifikacia dediacich skriniek (jadro D-46)
# ---------------------------------------------------------------------------

NxTest.test('d46: classify — adopting/recompute/blocked v jednej davke') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d46_seed('D46Mix', '18, 18.6')
  begin
    s18 = d46_sheet_of(res, 18.0)
    s186 = d46_sheet_of(res, 18.6)
    id18 = s18['material_id']
    id186 = s186['material_id']
    side = d46_key_for(d46_params, 'side_left')

    entries = [
      ['CAB-001', d46_params(18.0), d46_eff(id18), :ref_a],                 # prevezme 18 -> 18,6
      ['CAB-002', d46_params(18.6), d46_eff(id18), :ref_b],                 # hrubka uz sedi
      ['CAB-003', d46_params(18.0, side => { 'material_id' => id18 }), d46_eff(id18), :ref_c] # blokuje
    ]
    out = D46CB.classify_body_default_change(entries, s186, id186)

    NxTest.assert_equal(['CAB-001'], out['adopting'])
    NxTest.assert_equal(['CAB-002'], out['recompute'])
    NxTest.assert_equal(1, out['blocked'].size)
    NxTest.assert_equal('CAB-003', out['blocked'][0][0])
    NxTest.assert_equal(:parts, out['blocked'][0][1], 'dovod = dielce s vlastnym materialom')
    NxTest.assert(out['blocked'][0][2].first.to_s.length.positive?, 'blokujuci dielec sa vymenuje')

    # jobs nesu referenciu volajuceho a params s PREVZATOU hrubkou; blokujuca
    # skrinka job NEMA (davka sa aj tak odmietne cela)
    NxTest.assert_equal(%i[ref_a ref_b], out['jobs'].map(&:first))
    NxTest.assert_close(18.6, out['jobs'][0][1]['thickness'], 0.01)
    NxTest.assert_close(18.6, out['jobs'][1][1]['thickness'], 0.01, 'sediaca hrubka ostava')
    NxTest.assert(out['jobs'].none? { |_ref, p| p.key?('material_id') && p['material_id'] },
                  'skrinka dalej DEDI — vlastny material sa jej nenastavuje')
  ensure
    d46_cleanup(res)
  end
end

NxTest.test('d46: classify — prazdny vstup aj skrinky bez zmeny su bezpecne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d46_seed('D46Prazdno', '18')
  begin
    s18 = d46_sheet_of(res, 18.0)
    empty = D46CB.classify_body_default_change([], s18, s18['material_id'])
    NxTest.assert_equal([], empty['adopting'])
    NxTest.assert_equal([], empty['recompute'])
    NxTest.assert_equal([], empty['blocked'])
    NxTest.assert_equal([], empty['jobs'])
    NxTest.assert_equal(0, empty['remap']['changed'])

    same = D46CB.classify_body_default_change(
      [['CAB-009', d46_params(18.0), d46_eff(s18['material_id']), :r]], s18, s18['material_id']
    )
    NxTest.assert_equal(['CAB-009'], same['recompute'], 'ta ista hrubka = ziadne potvrdenie')
    NxTest.assert_equal([], same['adopting'])
  ensure
    d46_cleanup(res)
  end
end

NxTest.test('d46: classify — rucne ABS overridy nasleduju novy dekor (remap)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  old_res = d46_seed('D46Stary', '18')
  new_res = d46_seed('D46Novy', '18.6')
  begin
    old_sheet = d46_sheet_of(old_res, 18.0)
    new_sheet = d46_sheet_of(new_res, 18.6)
    old_abs = (old_res['edges'] || []).first
    NxTest.assert(old_abs, 'seed ma ABS pasku stareho dekoru')

    side = d46_key_for(d46_params, 'side_left')
    params = d46_params(18.0, side => { 'edges' => { 'L1' => old_abs } })
    out = D46CB.classify_body_default_change(
      [['CAB-001', params, d46_eff(old_sheet['material_id']), :ref]],
      new_sheet, new_sheet['material_id']
    )
    NxTest.assert_equal(['CAB-001'], out['adopting'])
    NxTest.assert_equal(1, out['remap']['changed'], 'ABS override sa preladil')
    NxTest.assert_equal([], out['remap']['lost'])
    new_abs = params['part_overrides'][side]['edges']['L1']
    NxTest.assert(new_abs && new_abs != old_abs, "ABS ostala na starom dekore: #{new_abs.inspect}")
    NxTest.assert_equal('D46Novy', D46MAT.edge(new_abs)['decor'])
  ensure
    d46_cleanup(old_res, new_res)
  end
end

# ---------------------------------------------------------------------------
# kontrakt potvrdenia — zastaraly suhlas sa NEVYKONA
# ---------------------------------------------------------------------------

def d46_fresh(extra = {})
  { 'model_guid' => 'GUID-1', 'key' => 'default_material_id', 'value' => 'HALIFAX_186',
    'old_default' => 'BIELA_18', 'adopting_ids' => %w[CAB-001 CAB-002],
    'recompute_ids' => ['CAB-003'] }.merge(extra)
end

NxTest.test('d46: pending_default_ok? — zhodny kontrakt prejde (poradie ID nerozhoduje)') do
  fresh = d46_fresh
  NxTest.assert(D46MAT.pending_default_ok?(d46_fresh, fresh))
  NxTest.assert(D46MAT.pending_default_ok?(d46_fresh('adopting_ids' => %w[CAB-002 CAB-001]), fresh),
                'poradie skriniek nie je sucastou suhlasu')
end

NxTest.test('d46: pending_default_ok? — zastaraly old_default = NOVA ponuka') do
  fresh = d46_fresh
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh('old_default' => 'INY_18'), fresh),
                'medzitym zmenena predvolba rusi suhlas')
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh('model_guid' => 'GUID-2'), fresh),
                'suhlas patri konkretnemu modelu')
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh('value' => 'INY_186'), fresh),
                'suhlas patri konkretnemu materialu')
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh('key' => 'default_front_material_id'), fresh))
end

NxTest.test('d46: pending_default_ok? — ina mnozina skriniek = NOVA ponuka') do
  fresh = d46_fresh
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh('adopting_ids' => ['CAB-001']), fresh),
                'medzitym pribudla/zmizla skrinka')
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh('adopting_ids' => %w[CAB-001 CAB-002 CAB-004]), fresh))
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh('recompute_ids' => []), fresh))
end

NxTest.test('d46: pending_default_ok? — chybajuci/nezmyselny pending nikdy neprejde') do
  fresh = d46_fresh
  NxTest.refute(D46MAT.pending_default_ok?(nil, fresh))
  NxTest.refute(D46MAT.pending_default_ok?('confirm', fresh))
  NxTest.refute(D46MAT.pending_default_ok?({}, fresh))
  NxTest.refute(D46MAT.pending_default_ok?(d46_fresh, nil))
end
