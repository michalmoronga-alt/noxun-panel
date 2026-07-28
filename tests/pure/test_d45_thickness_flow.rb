# frozen_string_literal: true
# Testy D-45: rozbitie deadlocku „hrubka <-> material" korpusu.
#   CabinetBuilder.thickness_in_range? / thickness_eq?  — rozsah 6–50 (audit B1)
#   CabinetBuilder.pick_body_sheet                      — deterministicky vyber (audit B6)
#   CabinetBuilder.effective_materials                  — dedenie projekt->korpus (audit B5)
#   CabinetBuilder.parts_blocking_thickness             — per-dielec konflikt (audit F8)
#   CabinetBuilder.thickness_ok_for? / validate_material_thickness! — cela beru
#     KATALOGOVU hrubku materialu (audit B2)
#   Materials.fmt_mm                                    — mm s ciarkou (audit F10)
# Panelova obalka (body_preflight, adopt_body_thickness!, insert/sablona) sa
# testuje v SketchUpe — tests/sketchup/su_runner.rb, sekcia D-45.
require_relative '../helper' unless defined?(NxTest)

D45CB  = Noxun::Engine::CabinetBuilder
D45MAT = Noxun::Engine::Materials

# Dekor s doskami 18 + 18,6 (Halifax scenar z testovania).
def d45_seed(tag, thicknesses = '18, 18.6', type = 'DTDL')
  ok, res = D45MAT.add_decor_batch(
    'decor' => tag, 'manufacturer' => 'Test D45', 'type' => type, 'thicknesses' => thicknesses
  )
  raise "seed #{tag} zlyhal: #{res.inspect}" unless ok
  res
end

def d45_cleanup(res)
  (res['sheets'] || []).each { |id| D45MAT.delete_sheet(id) }
  (res['edges'] || []).each { |id| D45MAT.delete_edge(id) }
end

def d45_sheet(id, decor, type, th)
  { 'material_id' => id, 'decor' => decor, 'type' => type, 'thickness' => th }
end

def d45_params(overrides = {})
  { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
    'thickness' => 18.0, 'part_overrides' => overrides }
end

def d45_key_for(params, role)
  D45CB.plan_parts_by_key(params).find { |_k, pd| pd[:role].to_s == role }&.first
end

# ---------------------------------------------------------------------------
# rozsah hrubky (audit B1) + tolerancia zhody
# ---------------------------------------------------------------------------

NxTest.test('d45: thickness_in_range? kryje 6–50 mm (HDF 3 ani 60 mm neprejde)') do
  NxTest.assert(D45CB.thickness_in_range?(18.0))
  NxTest.assert(D45CB.thickness_in_range?(18.6), 'Halifax 18,6 je legitimna hrubka korpusu')
  NxTest.assert(D45CB.thickness_in_range?(6.0), 'dolna hranica vratane')
  NxTest.assert(D45CB.thickness_in_range?(50.0), 'horna hranica vratane')
  NxTest.refute(D45CB.thickness_in_range?(3.0), 'HDF 3 = korpus by nestal (audit B1)')
  NxTest.refute(D45CB.thickness_in_range?(60.0))
  NxTest.refute(D45CB.thickness_in_range?(0))
  NxTest.refute(D45CB.thickness_in_range?(nil))
  NxTest.refute(D45CB.thickness_in_range?('abc'))
  NxTest.assert_equal([6.0, 50.0], D45CB::THICKNESS_RANGE, 'rozsah je JEDNA konstanta (clamp aj guardy)')
end

NxTest.test('d45: thickness_eq? ma rovnaku toleranciu ako hrubkovy guard (0,05)') do
  NxTest.assert(D45CB.thickness_eq?(18.6, 18.6))
  NxTest.assert(D45CB.thickness_eq?(18.0, 18.04))
  NxTest.refute(D45CB.thickness_eq?(18.0, 18.6))
  NxTest.refute(D45CB.thickness_eq?(18.0, 18.06))
end

# ---------------------------------------------------------------------------
# deterministicky vyber nahradneho materialu (audit B6)
# ---------------------------------------------------------------------------

NxTest.test('d45: pick_body_sheet — rovnaky dekor A typ ma prednost') do
  pool = [
    d45_sheet('B_INY_DTDL_186', 'Iny dekor', 'DTDL', 18.6),
    d45_sheet('A_HALIFAX_DTDL_186', 'Halifax', 'DTDL', 18.6),
    d45_sheet('C_HALIFAX_PD_186', 'Halifax', 'PD', 18.6),
    d45_sheet('D_HALIFAX_DTDL_18', 'Halifax', 'DTDL', 18.0)
  ]
  cur = d45_sheet('D_HALIFAX_DTDL_18', 'Halifax', 'DTDL', 18.0)
  res = D45CB.pick_body_sheet(18.6, cur, pool)
  NxTest.assert_equal('A_HALIFAX_DTDL_186', res[:pick]['material_id'], 'dekor+typ zhoda')
  NxTest.assert_equal(%w[A_HALIFAX_DTDL_186 B_INY_DTDL_186 C_HALIFAX_PD_186],
                      res[:candidates].map { |s| s['material_id'] },
                      'kandidati = vsetky dosky hladanej hrubky, zoradene material_id')
end

NxTest.test('d45: pick_body_sheet — viac zhod dekor+typ = tie-break podla material_id') do
  pool = [
    d45_sheet('Z_HALIFAX_DTDL_186', 'Halifax', 'DTDL', 18.6),
    d45_sheet('A_HALIFAX_DTDL_186', 'Halifax', 'DTDL', 18.6)
  ]
  cur = d45_sheet('HALIFAX_DTDL_18', 'Halifax', 'DTDL', 18.0)
  NxTest.assert_equal('A_HALIFAX_DTDL_186', D45CB.pick_body_sheet(18.6, cur, pool)[:pick]['material_id'],
                      'stabilne poradie nezavisle od poradia v katalogu')
  NxTest.assert_equal('A_HALIFAX_DTDL_186', D45CB.pick_body_sheet(18.6, cur, pool.reverse)[:pick]['material_id'])
end

NxTest.test('d45: pick_body_sheet — jediny kandidat rovnakeho typu (iny dekor) prejde') do
  pool = [
    d45_sheet('INY_DTDL_186', 'Iny dekor', 'DTDL', 18.6),
    d45_sheet('INY_PD_186', 'Iny dekor', 'PD', 18.6)
  ]
  cur = d45_sheet('HALIFAX_DTDL_18', 'Halifax', 'DTDL', 18.0)
  NxTest.assert_equal('INY_DTDL_186', D45CB.pick_body_sheet(18.6, cur, pool)[:pick]['material_id'])
end

NxTest.test('d45: pick_body_sheet — nejednoznacnost aj prazdny katalog = ziadny vyber') do
  cur = d45_sheet('HALIFAX_DTDL_18', 'Halifax', 'DTDL', 18.0)
  ambiguous = [
    d45_sheet('X_DTDL_186', 'Dekor X', 'DTDL', 18.6),
    d45_sheet('Y_DTDL_186', 'Dekor Y', 'DTDL', 18.6)
  ]
  res = D45CB.pick_body_sheet(18.6, cur, ambiguous)
  NxTest.assert_equal(nil, res[:pick], 'dva cudzie dekory rovnakeho typu = pouzivatel vybera rucne')
  NxTest.assert_equal(2, res[:candidates].size, 'kandidati idu do hlasky')

  none = D45CB.pick_body_sheet(18.6, cur, [d45_sheet('HALIFAX_DTDL_18', 'Halifax', 'DTDL', 18.0)])
  NxTest.assert_equal(nil, none[:pick])
  NxTest.assert_equal([], none[:candidates], 'ziadna doska tej hrubky')

  # material mimo katalogu (current nil) — bez kotvy dekor/typ sa nehada
  NxTest.assert_equal(nil, D45CB.pick_body_sheet(18.6, nil, ambiguous)[:pick])
end

# ---------------------------------------------------------------------------
# dedenie projekt->korpus (audit B5): prazdna hodnota = dedit, nie nil material
# ---------------------------------------------------------------------------

NxTest.test('d45: effective_materials — zrusenie override vracia projektovu predvolbu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d45_seed('D45Dedenie')
  begin
    m18 = res['sheets'].find { |id| (D45MAT.sheet(id)['thickness'] - 18.0).abs < 0.01 }
    m186 = res['sheets'].find { |id| (D45MAT.sheet(id)['thickness'] - 18.6).abs < 0.01 }
    NxTest.assert(m18 && m186, 'seed ma 18 aj 18,6 variant')

    model = NxTest::FakeEntity.new
    model.set_attribute(Noxun::Engine::Store::DICT, 'default_material_id', m186)

    with_override = D45CB.effective_materials(model, 'material_id' => m18)
    NxTest.assert_equal(m18, with_override['body'], 'explicitny korpusovy material vyhrava')
    NxTest.assert_close(18.0, D45MAT.sheet(with_override['body'])['thickness'])

    inherited = D45CB.effective_materials(model, 'material_id' => '')
    NxTest.assert_equal(m186, inherited['body'], 'prazdna hodnota = dedit projektovu predvolbu (audit B5)')
    NxTest.assert_close(18.6, D45MAT.sheet(inherited['body'])['thickness'], 0.01,
                        'hrubka sa preberá z EFEKTIVNEHO materialu (18 -> 18,6)')

    # bez akejkolvek predvolby na modeli plati fallback katalogu
    empty = D45CB.effective_materials(NxTest::FakeEntity.new, {})
    NxTest.assert_equal(D45MAT::PROJECT_FALLBACK['default_material_id'], empty['body'])
  ensure
    d45_cleanup(res)
  end
end

# ---------------------------------------------------------------------------
# per-dielec konflikt (audit F8): nic sa nemaze, zmena sa ODMIETNE
# ---------------------------------------------------------------------------

NxTest.test('d45: parts_blocking_thickness — dielec s vlastnym 18 mm blokuje 18,6') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d45_seed('D45Blok')
  begin
    m18 = res['sheets'].find { |id| (D45MAT.sheet(id)['thickness'] - 18.0).abs < 0.01 }
    m186 = res['sheets'].find { |id| (D45MAT.sheet(id)['thickness'] - 18.6).abs < 0.01 }
    side = d45_key_for(d45_params, 'side_left')
    NxTest.assert(side, 'plan ma side_left')

    ok_params = d45_params(side => { 'material_id' => m186 })
    ok_params['thickness'] = 18.6
    NxTest.assert_equal([], D45CB.parts_blocking_thickness(ok_params), 'zladeny override neblokuje')

    bad = d45_params(side => { 'material_id' => m18 })
    bad['thickness'] = 18.6
    blocked = D45CB.parts_blocking_thickness(bad)
    NxTest.assert_equal(1, blocked.size, blocked.inspect)
    NxTest.assert(blocked[0].to_s.length.positive?, 'hlaska vymenuje dielec menom')

    # bez overridu materialu (len ABS hrany) sa nic neblokuje
    NxTest.assert_equal([], D45CB.parts_blocking_thickness(
                              d45_params(side => { 'edges' => { 'L1' => 'ABS_K009_10' } })
                                .merge('thickness' => 18.6)
                            ))
    # legacy material mimo katalogu sa nekontroluje (stary rezim)
    NxTest.assert_equal([], D45CB.parts_blocking_thickness(
                              d45_params(side => { 'material_id' => 'LEGACY_MIMO_KATALOGU' })
                                .merge('thickness' => 18.6)
                            ))
  ensure
    d45_cleanup(res)
  end
end

NxTest.test('d45: parts_blocking_thickness — celo s inou katalogovou hrubkou neblokuje') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d45_seed('D45Celo')
  begin
    m18 = res['sheets'].find { |id| (D45MAT.sheet(id)['thickness'] - 18.0).abs < 0.01 }
    params = d45_params
    params['fronts'] = '1' # legacy skratka = 1 dvierka auto
    front = d45_key_for(params, 'front_door')
    NxTest.assert(front, 'plan ma celo')
    params['part_overrides'] = { front => { 'material_id' => m18 } }
    params['thickness'] = 18.6
    NxTest.assert_equal([], D45CB.parts_blocking_thickness(params),
                        'celo hrubku korpusu nededi — vlastny material je legitimny')
  ensure
    d45_cleanup(res)
  end
end

# ---------------------------------------------------------------------------
# cela beru katalogovu hrubku (audit B2)
# ---------------------------------------------------------------------------

NxTest.test('d45: thickness_ok_for? cela = katalogovy rozsah (18,6 prejde, HDF 3 nie)') do
  NxTest.assert(D45CB.thickness_ok_for?('front_door', 18.0, 18.6), 'Halifax 18,6 celo (D-45)')
  NxTest.assert(D45CB.thickness_ok_for?('front_door', 18.0, 19.0), 'povodne 18/19 varianty stale platia')
  NxTest.assert(D45CB.thickness_ok_for?('drawer_front', 19.0, 18.0))
  NxTest.assert(D45CB.thickness_ok_for?('front_door', 18.0, 36.0), 'hrube celo je legitimne')
  NxTest.refute(D45CB.thickness_ok_for?('front_door', 18.0, 3.0), 'HDF 3 ako celo nie')
  NxTest.refute(D45CB.thickness_ok_for?('front_door', 18.0, 60.0))
  # ostatne roly ostavaju na presnej zhode s konstrukcnou hrubkou
  NxTest.refute(D45CB.thickness_ok_for?('shelf', 18.0, 18.6))
  NxTest.assert(D45CB.thickness_ok_for?('shelf', 18.6, 18.6))
end

NxTest.test('d45: validate_material_thickness! pusti 18,6 celo, dielec korpusu nie') do
  fpd = { suffix: 'DOOR-1', role: 'front_door', prod: { thickness: 18.0 } }
  NxTest.assert_equal(nil, D45CB.validate_material_thickness!('HALIFAX_186', { 'thickness' => 18.6 }, fpd))
  spd = { suffix: 'SIDE-L', role: 'side_left', prod: { thickness: 18.0 } }
  NxTest.assert_raise('18,6') do
    D45CB.validate_material_thickness!('HALIFAX_186', { 'thickness' => 18.6 }, spd)
  end
end

# ---------------------------------------------------------------------------
# format mm do hlasok (audit F10)
# ---------------------------------------------------------------------------

NxTest.test('d45: fmt_mm — desatinna CIARKA, cele cisla bez desatin') do
  NxTest.assert_equal('18', D45MAT.fmt_mm(18.0))
  NxTest.assert_equal('18,6', D45MAT.fmt_mm(18.6))
  NxTest.assert_equal('1', D45MAT.fmt_mm(1.0))
  NxTest.assert_equal('0,5', D45MAT.fmt_mm(0.5))
  NxTest.assert_equal('22', D45MAT.fmt_mm('22'))
  NxTest.assert_equal('3', D45MAT.fmt_mm(3))
  NxTest.assert(D45MAT.fmt_mm(18.6).is_a?(String), 'vzdy String — nikdy Float do interpolacie')
end
