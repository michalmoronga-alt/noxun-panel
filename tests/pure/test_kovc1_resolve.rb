# frozen_string_literal: true
# KOV-C1 — `Recipes.resolve`: jedna vyska, jedna NL, dielce, konflikty.
#
# Zasady, ktore testy strazia:
#   * porovnania su INKLUZIVNE nad NEZAOKRUHLENOU hodnotou a bez EPS
#     (105.00 plati, 104.995 pada) — zaokruhlenie by ticho povolilo zasuvku,
#     ktora sa nezmesti;
#   * NL zamok sa NIKDY nemeni ticho — bud plati, alebo je `nl_lock_invalid`;
#   * emisia dielcov je ATOMICKA: akykolvek konflikt -> ziadne dielce.
require_relative '../helper' unless defined?(NxTest)

module NxKovC1R
  module_function

  def r
    Noxun::Engine::Recipes
  end

  def rec(id)
    r.load(id)
  end

  def ctx(clear_width: 864.0, clear_height: 175.0, clear_depth: 497.0,
          side_thickness: 18.0, obstructions: [], owner: 'front:F1/panel')
    { clear_width: clear_width, clear_height: clear_height, clear_depth: clear_depth,
      side_thickness: side_thickness, obstructions: obstructions, owner_part_key: owner }
  end

  def th_atira(bottom: 16.0, back: 16.0)
    { 'drawer_bottom' => bottom, 'drawer_back' => back }
  end

  def th_quadro(t = 16.0)
    { 'drawer_bottom' => t, 'box_side' => t, 'drawer_inner_front' => t, 'drawer_back' => t }
  end

  def lock(nl, rule_id = 'vysuvy-nl-podla-hlbky', owner = 'front:F1/panel')
    [{ 'owner_part_key' => owner, 'generic_type' => 'slide', 'rule_id' => rule_id,
       'nominal_length' => nl }]
  end

  def part(res, role, side = nil)
    res[:parts].find { |p| p[:role] == role && (side.nil? || p[:side] == side) }
  end

  def codes(res)
    res[:conflicts].map { |c| c[:code] }
  end

  # Kazdy konflikt MUSI zhodit dielce aj parametre polozky (atomicita).
  def assert_fail_closed(res, code)
    NxTest.assert_equal([code], codes(res), "ocakavany konflikt #{code}, dostal #{codes(res).inspect}")
    NxTest.assert_equal([], res[:parts], 'pri konflikte sa nesmie emitovat ani jeden dielec')
    NxTest.assert_equal({}, res[:hardware_params], 'pri konflikte nesmu vzniknut parametre polozky')
  end
end

# --- 3. Tabulkove testy vzorcov (bez zaokruhlovania) --------------------------

NxTest.test('KOV-C1: Atira 900/KD18 -> LB 864, dno 791,5 x 480, chrbat 780 x 65,5') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx, NxKovC1R.th_atira, [])
  NxTest.assert_equal([], NxKovC1R.codes(res))
  NxTest.assert_equal(70, res[:height_variant])
  NxTest.assert_close(470.0, res[:nl], 0.001)
  bottom = NxKovC1R.part(res, 'drawer_bottom')
  NxTest.assert_close(791.5, bottom[:width], 0.001)
  NxTest.assert_close(480.0, bottom[:height], 0.001)
  NxTest.assert_equal({}, bottom[:abs], 'dno nema ABS')
  back = NxKovC1R.part(res, 'drawer_back')
  NxTest.assert_close(780.0, back[:width], 0.001)
  NxTest.assert_close(65.5, back[:height], 0.001)
  NxTest.assert_close(1.0, back[:abs][:l1], 0.001, 'chrbat ma hornu dlhu hranu 1,0')
  NxTest.assert_equal(2, res[:parts].size, 'Atira emituje presne 2 dielce')
end

NxTest.test('KOV-C1: Atira KD 16 -> LB 868, dno 795,5 (EB ostava 10,5)') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'),
                           NxKovC1R.ctx(clear_width: 868.0, side_thickness: 16.0),
                           NxKovC1R.th_atira, [])
  NxTest.assert_equal([], NxKovC1R.codes(res))
  NxTest.assert_close(795.5, NxKovC1R.part(res, 'drawer_bottom')[:width], 0.001)
  NxTest.assert_close(784.0, NxKovC1R.part(res, 'drawer_back')[:width], 0.001)
end

NxTest.test('KOV-C1: Quadro 900/KD18 hlbka 497 -> SKW 818, NL 450, 5 dielcov') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('quadro_v6_sisy_v1'),
                           NxKovC1R.ctx(clear_height: 200.0), NxKovC1R.th_quadro, [])
  NxTest.assert_equal([], NxKovC1R.codes(res))
  NxTest.assert(res[:height_variant].nil?, 'Quadro nema vyskovy variant')
  NxTest.assert_close(160.0, res[:box_height], 0.001)
  NxTest.assert_close(450.0, res[:nl], 0.001)
  NxTest.assert_equal(5, res[:parts].size)
  left = NxKovC1R.part(res, 'box_side', 'left')
  NxTest.assert_close(450.0, left[:width], 0.001)
  NxTest.assert_close(160.0, left[:height], 0.001)
  NxTest.assert(NxKovC1R.part(res, 'box_side', 'right'), 'chyba pravy bok')
  bottom = NxKovC1R.part(res, 'drawer_bottom')
  NxTest.assert_close(818.0, bottom[:width], 0.001)
  NxTest.assert_close(450.0, bottom[:height], 0.001)
  [NxKovC1R.part(res, 'drawer_inner_front'), NxKovC1R.part(res, 'drawer_back')].each do |p|
    NxTest.assert_close(818.0, p[:width], 0.001)
    NxTest.assert_close(132.0, p[:height], 0.001) # 160 - 16 - 12
  end
end

# --- 4. Hranice vysky a NL ----------------------------------------------------

NxTest.test('KOV-C1: celo 175 -> H70 (nie H144)') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx(clear_height: 175.0),
                           NxKovC1R.th_atira, [])
  NxTest.assert_equal(70, res[:height_variant])
end

NxTest.test('KOV-C1: svetla vyska 105,00 plati, 104,995 pada (inkluzivne, bez EPS)') do
  ok = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx(clear_height: 105.0),
                          NxKovC1R.th_atira, [])
  NxTest.assert_equal(70, ok[:height_variant])
  bad = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx(clear_height: 104.995),
                           NxKovC1R.th_atira, [])
  NxKovC1R.assert_fail_closed(bad, 'drawer_no_fit')
end

NxTest.test('KOV-C1: Tip-On ma vlastnu hranicu 108 (105 uz nestaci)') do
  p2o = NxKovC1R.rec('atira_p2o_v1')
  NxKovC1R.assert_fail_closed(
    NxKovC1R.r.resolve(p2o, NxKovC1R.ctx(clear_height: 107.999), NxKovC1R.th_atira, []),
    'drawer_no_fit'
  )
  ok = NxKovC1R.r.resolve(p2o, NxKovC1R.ctx(clear_height: 108.0), NxKovC1R.th_atira, [])
  NxTest.assert_equal(70, ok[:height_variant])
end

NxTest.test('KOV-C1: Atira SiSy H70 — hlbka 500 -> NL 470, hlbka 560 -> NL 520') do
  rec = NxKovC1R.rec('atira_sisy_v1')
  a = NxKovC1R.r.resolve(rec, NxKovC1R.ctx(clear_depth: 500.0), NxKovC1R.th_atira, [])
  NxTest.assert_close(470.0, a[:nl], 0.001)
  b = NxKovC1R.r.resolve(rec, NxKovC1R.ctx(clear_depth: 560.0), NxKovC1R.th_atira, [])
  NxTest.assert_close(520.0, b[:nl], 0.001)
  NxTest.assert_equal(70, b[:height_variant])
end

NxTest.test('KOV-C1: Atira SiSy H176 — hlbka 560 -> NL 520 (620 potrebuje 635)') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'),
                           NxKovC1R.ctx(clear_height: 300.0, clear_depth: 560.0),
                           NxKovC1R.th_atira, [])
  NxTest.assert_equal(176, res[:height_variant])
  NxTest.assert_close(520.0, res[:nl], 0.001)
  NxTest.assert_close(176.0, NxKovC1R.part(res, 'drawer_back')[:height], 0.001)
end

NxTest.test('KOV-C1: nosnost bunky — Atira NL 620 = 50 kg, Tip-On H176/520 = 50 kg, inak 30') do
  sisy = NxKovC1R.rec('atira_sisy_v1')
  base = NxKovC1R.r.resolve(sisy, NxKovC1R.ctx, NxKovC1R.th_atira, [])
  NxTest.assert_close(30.0, base[:load], 0.001)
  big = NxKovC1R.r.resolve(sisy, NxKovC1R.ctx(clear_height: 300.0, clear_depth: 700.0),
                           NxKovC1R.th_atira, [])
  NxTest.assert_close(620.0, big[:nl], 0.001)
  NxTest.assert_close(50.0, big[:load], 0.001)
  p2o = NxKovC1R.r.resolve(NxKovC1R.rec('atira_p2o_v1'),
                           NxKovC1R.ctx(clear_height: 300.0, clear_depth: 560.0),
                           NxKovC1R.th_atira, [])
  NxTest.assert_equal(176, p2o[:height_variant])
  NxTest.assert_close(520.0, p2o[:nl], 0.001)
  NxTest.assert_close(50.0, p2o[:load], 0.001)
end

NxTest.test('KOV-C1: Quadro hlbka 300 -> drawer_no_fit (350 potrebuje 363)') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('quadro_v6_sisy_v1'),
                           NxKovC1R.ctx(clear_height: 200.0, clear_depth: 300.0),
                           NxKovC1R.th_quadro, [])
  NxKovC1R.assert_fail_closed(res, 'drawer_no_fit')
  NxTest.assert(res[:conflicts].first[:message].include?('363'), 'hlaska musi povedat potrebnu hlbku')
end

NxTest.test('KOV-C1: Quadro svetla vyska 60 -> drawer_no_fit (nie zaporny chrbat)') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('quadro_v6_sisy_v1'),
                           NxKovC1R.ctx(clear_height: 60.0), NxKovC1R.th_quadro, [])
  NxKovC1R.assert_fail_closed(res, 'drawer_no_fit')
end

NxTest.test('KOV-C1: Quadro minimum celo/chrbat 30 mm je hranica (98 pada, 98,001 prejde)') do
  rec = NxKovC1R.rec('quadro_v6_sisy_v1')
  # box_height = clear - 40; celo/chrbat = box - 16 - 12 >= 30  =>  clear >= 98
  ok = NxKovC1R.r.resolve(rec, NxKovC1R.ctx(clear_height: 98.0), NxKovC1R.th_quadro, [])
  NxTest.assert_equal([], NxKovC1R.codes(ok))
  NxTest.assert_close(30.0, NxKovC1R.part(ok, 'drawer_back')[:height], 0.001)
  bad = NxKovC1R.r.resolve(rec, NxKovC1R.ctx(clear_height: 97.995), NxKovC1R.th_quadro, [])
  NxKovC1R.assert_fail_closed(bad, 'drawer_no_fit')
end

# --- 5. NL zamok ---------------------------------------------------------------

NxTest.test('KOV-C1: zamok v rade a zmesti sa -> DRZI (aj ked automat by dal inu NL)') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx,
                           NxKovC1R.th_atira, NxKovC1R.lock(420.0))
  NxTest.assert_equal([], NxKovC1R.codes(res))
  NxTest.assert_close(420.0, res[:nl], 0.001)
  NxTest.assert_close(430.0, NxKovC1R.part(res, 'drawer_bottom')[:height], 0.001)
end

NxTest.test('KOV-C1: zamok MIMO radu -> nl_lock_invalid (nikdy ticha zmena na inu NL)') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx,
                           NxKovC1R.th_atira, NxKovC1R.lock(400.0))
  NxKovC1R.assert_fail_closed(res, 'nl_lock_invalid')
end

NxTest.test('KOV-C1: zamok v rade, ale nezmesti sa -> nl_lock_invalid') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx(clear_depth: 500.0),
                           NxKovC1R.th_atira, NxKovC1R.lock(520.0))
  NxKovC1R.assert_fail_closed(res, 'nl_lock_invalid')
end

NxTest.test('KOV-C1: zamok plati pod OBOMA tvarmi rule_id (legacy aj recipe:<id>)') do
  rec = NxKovC1R.rec('atira_sisy_v1')
  %w[vysuvy-nl-podla-hlbky recipe:atira_sisy_v1].each do |rule_id|
    res = NxKovC1R.r.resolve(rec, NxKovC1R.ctx, NxKovC1R.th_atira, NxKovC1R.lock(420.0, rule_id))
    NxTest.assert_close(420.0, res[:nl], 0.001, "rule_id #{rule_id}")
  end
end

NxTest.test('KOV-C1: zamok patriaci INEMU celu sa ignoruje') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx, NxKovC1R.th_atira,
                           NxKovC1R.lock(400.0, 'vysuvy-nl-podla-hlbky', 'front:F2/panel'))
  NxTest.assert_equal([], NxKovC1R.codes(res))
  NxTest.assert_close(470.0, res[:nl], 0.001)
end

NxTest.test('KOV-C1: zaznam override BEZ nominal_length nie je zamok') do
  overrides = [{ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
                 'rule_id' => 'vysuvy-nl-podla-hlbky', 'quantity' => 2 }]
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx, NxKovC1R.th_atira, overrides)
  NxTest.assert_equal([], NxKovC1R.codes(res))
  NxTest.assert_close(470.0, res[:nl], 0.001)
end

# --- 6. Hrubky, KD, prekazky ---------------------------------------------------

NxTest.test('KOV-C1: Atira chrbat 18 mm -> drawer_thickness_unsupported') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx,
                           NxKovC1R.th_atira(back: 18.0), [])
  NxKovC1R.assert_fail_closed(res, 'drawer_thickness_unsupported')
end

NxTest.test('KOV-C1: Quadro 18 mm je platne a znizi celo/chrbat o 2 mm') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('quadro_v6_sisy_v1'),
                           NxKovC1R.ctx(clear_height: 200.0), NxKovC1R.th_quadro(18.0), [])
  NxTest.assert_equal([], NxKovC1R.codes(res))
  NxTest.assert_close(130.0, NxKovC1R.part(res, 'drawer_back')[:height], 0.001)
  NxTest.assert_close(18.0, NxKovC1R.part(res, 'drawer_bottom')[:thickness], 0.001)
end

NxTest.test('KOV-C1: neznama hrubka dielca (chybajuci vstup) = konflikt, nie tichy default') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx,
                           { 'drawer_bottom' => 16.0 }, [])
  NxKovC1R.assert_fail_closed(res, 'drawer_thickness_unsupported')
end

NxTest.test('KOV-C1: KD 25 -> drawer_kd_unsupported') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx(side_thickness: 25.0),
                           NxKovC1R.th_atira, [])
  NxKovC1R.assert_fail_closed(res, 'drawer_kd_unsupported')
end

NxTest.test('KOV-C1: prekazka v riadku -> drawer_obstruction') do
  obs = [{ role: 'shelf', part_key: 'zone:Z1/shelf:1', z0: 150.0, z1: 168.0 }]
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx(obstructions: obs),
                           NxKovC1R.th_atira, [])
  NxKovC1R.assert_fail_closed(res, 'drawer_obstruction')
end

NxTest.test('KOV-C1: nekladny rozmer dielca -> drawer_no_fit (nie preskoceny dielec)') do
  # Uzka nika: LB 80 -> dno 80 - 21 - 51,5 = 7,5; chrbat 80 - 21 - 63 = -4
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx(clear_width: 80.0),
                           NxKovC1R.th_atira, [])
  NxKovC1R.assert_fail_closed(res, 'drawer_no_fit')
end

NxTest.test('KOV-C1: sync tyc sa odporuca len pri P2O a sirke >= 600 (inkluzivne)') do
  sisy = NxKovC1R.rec('atira_sisy_v1')
  p2o = NxKovC1R.rec('atira_p2o_v1')
  NxTest.refute(NxKovC1R.r.sync_recommended?(sisy, 900.0), 'SiSy sync tyc nepotrebuje')
  NxTest.assert(NxKovC1R.r.sync_recommended?(p2o, 600.0), '600 je inkluzivne')
  NxTest.refute(NxKovC1R.r.sync_recommended?(p2o, 599.99))
end

NxTest.test('KOV-C1: explain je citatelny slovensky text s cislami') do
  res = NxKovC1R.r.resolve(NxKovC1R.rec('atira_sisy_v1'), NxKovC1R.ctx, NxKovC1R.th_atira, [])
  NxTest.assert(res[:explain].size >= 3, 'explain musi popisat vysku, NL aj nosnost')
  NxTest.assert(res[:explain][0].include?('H70'))
  NxTest.assert(res[:explain][1].include?('470'))
end

# --- 10. Golden per vydana verzia ----------------------------------------------

NxTest.test('KOV-C1: golden vysledky resolve sedia pre KAZDY vydany recept') do
  path = File.join(NxTest::ROOT, 'tests', 'pure', 'fixtures', 'kovc1_golden.json')
  NxTest.assert(File.file?(path), 'chyba fixtura kovc1_golden.json')
  golden = JSON.parse(File.read(path, encoding: 'UTF-8'))
  ids = NxKovC1R.r.released.keys.sort
  NxTest.assert_equal(ids, golden['cases'].map { |c| c['recipe_id'] }.uniq.sort,
                      'golden musi pokryvat KAZDY vydany recept — inak by nova verzia presla bez kontroly')

  golden['cases'].each do |c|
    ctx = c['ctx'].each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
    ctx[:obstructions] = Array(ctx[:obstructions])
    res = NxKovC1R.r.resolve(NxKovC1R.rec(c['recipe_id']), ctx, c['part_thicknesses'], Array(c['overrides']))
    name = "#{c['recipe_id']} / #{c['name']}"
    NxTest.assert_equal(Array(c['conflicts']), NxKovC1R.codes(res), "#{name}: konflikty")
    NxTest.assert_equal(c['height_variant'], res[:height_variant], "#{name}: vyskovy variant")
    if c['box_height'].nil?
      NxTest.assert(res[:box_height].nil?, "#{name}: box_height ma byt nil")
    else
      NxTest.assert_close(c['box_height'], res[:box_height], 0.001, "#{name}: box_height")
    end
    if c['nl'].nil?
      NxTest.assert(res[:nl].nil?, "#{name}: NL ma byt nil")
    else
      NxTest.assert_close(c['nl'], res[:nl], 0.001, "#{name}: NL")
      NxTest.assert_close(c['load'], res[:load], 0.001, "#{name}: nosnost")
    end
    actual = res[:parts].map { |p| [p[:role], p[:side], p[:width].round(3), p[:height].round(3), p[:thickness].round(3)] }
    expected = Array(c['parts']).map { |p| [p['role'], p['side'], p['width'], p['height'], p['thickness']] }
    NxTest.assert_equal(expected, actual, "#{name}: dielce")
  end
end
