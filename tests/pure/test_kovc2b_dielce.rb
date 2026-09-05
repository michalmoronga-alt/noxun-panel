# frozen_string_literal: true
# KOV-C2b — AKTIVACIA RECEPTOV ZASUVIEK: dielce v plane, JEDNA polozka vysuvu,
# hrubky ako VSTUP receptu, fail-closed konflikty a D-93 migracia zamku.
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1 legacy `slide` pravidlo sa NEPOTLACI -> „R2: presne JEDNA polozka vysuvu"
#   M2 zamok mimo radu ticho spadne na inu NL -> „D-93: zamok mimo radu = RED"
#   M3 dielce sa emituju aj pri konflikte -> „fail-closed: ziadne dielce…"
#   M4 hrubka sa berie z korpusu, nie z kanala -> „hrubka je VSTUP receptu"
require_relative '../helper' unless defined?(NxTest)

module NxC2bD
  E   = Noxun::Engine
  CB  = E::CabinetBuilder
  CN  = E::Construction
  BP  = E::BuildPlan
  REC = E::Recipes
  FR  = E::Fronts

  module_function

  # Skrinka 900 x 720 x 500 (KD 18, sokel 100) s JEDNYM zasuvkovym celom 175.
  def cfg(front = {}, over = {})
    item = { 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
             'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }
    item = item.merge(front)
    CB.normalize({ 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                   'fronts' => { 'items' => [item] } }.merge(over))
  end

  def plan(front = {}, over = {}, th = nil)
    CN.build_plan(cfg(front, over), 'CAB-1', part_thicknesses: th)
  end

  # Dielce zasuvky z planu: { rola => deskriptor } (box_side po stranach).
  def drawer_parts(pl)
    pl[:parts].select { |p| p[:material] == :drawer }
  end

  def part(pl, key)
    drawer_parts(pl).find { |p| p[:part_key] == key }
  end

  def slides(pl)
    pl[:hardware].select { |h| h['generic_type'] == 'slide' }
  end

  def conflict(pl)
    Array(pl[:drawer_conflicts]).first
  end

  # Hrubky VSETKYCH roli jedneho cela (vstup receptu).
  def th_for(front_id, mm, over = {})
    CB::DRAWER_ROLES.each_with_object({}) do |role, acc|
      acc[E::PartKeys.front(front_id, role)] = mm
    end.merge(over)
  end

  # Rucny NL zamok (D-93) na zasuvkovom cele.
  def lock(nl, rule_id = REC::LOCK_LEGACY_RULE_ID, over = {})
    [{ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
       'rule_id' => rule_id, 'nominal_length' => nl }.merge(over)]
  end
end

# ============================================================================
# R1 — DIELCE V PLANE
# ============================================================================

NxTest.test('KOV-C2b (R1): Atira 900/KD18, celo 175 -> dno 791,5 x 480 + chrbat 780 x 65,5') do
  c = NxC2bD
  pl = c.plan
  NxTest.assert_equal(['front:F1/drawer_bottom', 'front:F1/drawer_back'],
                      c.drawer_parts(pl).map { |p| p[:part_key] },
                      'metal box = PRAVE dva vyrabane dielce')
  bottom = c.part(pl, 'front:F1/drawer_bottom')
  NxTest.assert_close(791.5, bottom[:prod][:length], 0.001, 'BB = 864 - 2*10,5 - 51,5')
  NxTest.assert_close(480.0, bottom[:prod][:width], 0.001, 'BL = NL 470 + 10')
  NxTest.assert_equal('drawer_bottom', bottom[:role])
  NxTest.assert_equal(:drawer, bottom[:material], '4. materialovy kanal')
  back = c.part(pl, 'front:F1/drawer_back')
  NxTest.assert_close(780.0, back[:prod][:length], 0.001, 'RB = 864 - 2*10,5 - 63')
  NxTest.assert_close(65.5, back[:prod][:width], 0.001, 'rear_height H70')
end

NxTest.test('KOV-C2b (R1): KD 16 zmeni svetlu sirku, EB ostava 10,5 -> dno 795,5 x 480') do
  c = NxC2bD
  pl = c.plan({}, 'thickness' => 16.0)
  NxTest.assert_close(795.5, c.part(pl, 'front:F1/drawer_bottom')[:prod][:length], 0.001)
  NxTest.assert_close(480.0, c.part(pl, 'front:F1/drawer_bottom')[:prod][:width], 0.001)
end

NxTest.test('KOV-C2b (R1): Quadro V6 900/KD18/hlbka 500 -> 5 dielcov, NL 450') do
  c = NxC2bD
  pl = c.plan('drawer' => { 'construction' => 'wood' })
  keys = c.drawer_parts(pl).map { |p| p[:part_key] }.sort
  NxTest.assert_equal(['front:F1/box_side:left', 'front:F1/box_side:right',
                       'front:F1/drawer_back', 'front:F1/drawer_bottom',
                       'front:F1/drawer_inner_front'], keys)
  bottom = c.part(pl, 'front:F1/drawer_bottom')
  NxTest.assert_close(818.0, bottom[:prod][:length], 0.001, 'SKW = 864 - 46')
  NxTest.assert_close(450.0, bottom[:prod][:width], 0.001, 'dlzka dna = NL')
  side = c.part(pl, 'front:F1/box_side:left')
  NxTest.assert_close(450.0, side[:prod][:length], 0.001, 'bok = NL')
  NxTest.assert_close(119.0, side[:prod][:width], 0.001, 'box_height = svetla 159 - vola 40')
  ifr = c.part(pl, 'front:F1/drawer_inner_front')
  NxTest.assert_close(818.0, ifr[:prod][:length], 0.001)
  NxTest.assert_close(91.0, ifr[:prod][:width], 0.001, '119 - 16 (dno) - 12 (odsadenie)')
  NxTest.assert_close(91.0, c.part(pl, 'front:F1/drawer_back')[:prod][:width], 0.001)
end

NxTest.test('KOV-C2b (R1): Atira H176, celo 300, hlbka 560 -> NL 520') do
  c = NxC2bD
  pl = c.plan({ 'height' => 300.0 }, 'depth' => 560.0)
  NxTest.assert_equal([], Array(pl[:drawer_conflicts]), 'zasuvka sa zmesti')
  NxTest.assert_close(520.0, c.slides(pl).first['params']['nominal_length'], 0.001)
  NxTest.assert_equal(176, c.slides(pl).first['params']['height_variant'])
  NxTest.assert_close(530.0, c.part(pl, 'front:F1/drawer_bottom')[:prod][:width], 0.001, 'BL = 520 + 10')
end

NxTest.test('KOV-C2b (R1): dielce maju PLNU geometriu v svetlom priestore niky') do
  c = NxC2bD
  pl = c.plan
  bottom = c.part(pl, 'front:F1/drawer_bottom')
  # Vycentrovane v listovej zone 18..882 (stred 450), spodok riadku = interier 118.
  NxTest.assert_close(54.25, bottom[:origin][0], 0.001)
  NxTest.assert_close(0.0, bottom[:origin][1], 0.001, 'od prednej roviny vnutra')
  NxTest.assert_close(118.0, bottom[:origin][2], 0.001)
  NxTest.assert_equal([791.5, 480.0, 16.0], bottom[:box].map { |v| v.round(2) })
  back = c.part(pl, 'front:F1/drawer_back')
  NxTest.assert_close(464.0, back[:origin][1], 0.001, 'chrbat na zadnej hrane dna (480 - 16)')
  NxTest.assert_close(134.0, back[:origin][2], 0.001, 'stoji NA dne')
  # Deskriptory prechadzaju kontraktom planu (vratane novych roli a schemy 4).
  NxTest.assert_equal(4, NxC2bD::BP::SCHEMA)
  NxTest.assert_equal(pl, NxC2bD::BP.validate!(pl))
end

# ============================================================================
# R1 — HRUBKA JE VSTUP RECEPTU (4. materialovy kanal PRED planom)
# ============================================================================

NxTest.test('KOV-C2b (R1): bez dodanych hrubok plati UNI 16 fallback kanala') do
  c = NxC2bD
  NxTest.assert_close(16.0, NxC2bD::CN::DRAWER_DEFAULT_THICKNESS, 0.001)
  NxTest.assert_close(16.0, c.part(c.plan, 'front:F1/drawer_bottom')[:prod][:thickness], 0.001)
end

NxTest.test('KOV-C2b (R1): 18 mm pri Atire = RED `drawer_thickness_unsupported`') do
  c = NxC2bD
  pl = c.plan({}, {}, c.th_for('F1', 18.0))
  NxTest.assert_equal([], c.drawer_parts(pl), 'ziadne dielce')
  NxTest.assert_equal([], c.slides(pl), 'ziadna polozka vysuvu')
  NxTest.assert_equal('drawer_thickness_unsupported', c.conflict(pl)['code'])
end

NxTest.test('KOV-C2b (R1): Quadro dno 18 mm znizi vnutorne celo aj chrbat o 2 mm') do
  c = NxC2bD
  th = c.th_for('F1', 16.0, NxC2bD::E::PartKeys.front('F1', 'drawer_bottom') => 18.0)
  pl = c.plan({ 'drawer' => { 'construction' => 'wood' } }, {}, th)
  NxTest.assert_close(18.0, c.part(pl, 'front:F1/drawer_bottom')[:prod][:thickness], 0.001)
  NxTest.assert_close(89.0, c.part(pl, 'front:F1/drawer_inner_front')[:prod][:width], 0.001,
                      '119 - 18 - 12 (predtym 91)')
  NxTest.assert_close(89.0, c.part(pl, 'front:F1/drawer_back')[:prod][:width], 0.001)
end

NxTest.test('KOV-C2b (R1): builder pocita hrubky Z KANALA :drawer PRED planom') do
  c = NxC2bD
  cfg = c.cfg
  eff = NxC2bD::CB.effective_materials(nil, cfg)
  NxTest.assert_equal('UNI_ZASUVKA_16', eff['drawer'])
  th = NxC2bD::CB.drawer_thicknesses(cfg, eff)
  # Codex #304 kolo 2 P1: `box_side` sa emituje DVAKRAT, takze hrubka sa musi
  # citat pod OBOMA klucmi — pod holym `front:F1/box_side` neexistuje ziadny
  # dielec a teda ani ziadny override.
  want = NxC2bD::CB::DRAWER_ROLES.flat_map { |r| NxC2bD::CN.drawer_thickness_keys('F1', r) }
  NxTest.assert_equal(%w[front:F1/box_side:left front:F1/box_side:right],
                      NxC2bD::CN.drawer_thickness_keys('F1', 'box_side'))
  NxTest.assert_equal(['front:F1/drawer_bottom'],
                      NxC2bD::CN.drawer_thickness_keys('F1', 'drawer_bottom'))
  NxTest.assert_equal(want.sort, th.keys.sort, 'kluc pre KAZDY emitovany dielec zasuvky')
  # Poradie v `build_into` je zavazne: efektivne materialy PRED planom.
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'),
                  encoding: 'UTF-8')
  body = src[/def build_into.*?merge_final\(cfg, plan\)/m].to_s
  NxTest.assert(body.index('eff = effective_materials(model, cfg)') <
                body.index('plan = Construction.build_plan'),
                'hrubky kanala sa MUSIA vyriesit pred planom (Codex #301 kolo 3 P1)')
end

# ============================================================================
# R2 — JEDNA POLOZKA VYSUVU + EXKLUZIVITA
# ============================================================================

NxTest.test('KOV-C2b (R2): jedno zasuvkove celo = PRESNE jedna polozka vysuvu') do
  c = NxC2bD
  pl = c.plan
  NxTest.assert_equal(1, c.slides(pl).length)
  it = c.slides(pl).first
  NxTest.assert_equal(['front:F1/panel', 'slide', 1, 'recipe:atira_sisy_v1', 'recipe', 1],
                      [it['owner_part_key'], it['generic_type'], it['quantity'],
                       it['rule_id'], it['source'], it['rule_quantity']])
  NxTest.assert_equal('counted', it['production_class'])
  NxTest.assert_equal(true, it['manufactured'])
  NxTest.refute(it.key?('locked'), 'bez zamku polozka znamienko NEMA (Astra #19 N11)')
  NxTest.assert_equal({ 'recipe_id' => 'atira_sisy_v1', 'system' => 'atira',
                        'nominal_length' => 470.0, 'load' => 30.0, 'opening' => 'sisy',
                        'opening_mode' => 'classic', 'drawer_construction' => 'metal',
                        'height_variant' => 70 }, it['params'])
end

NxTest.test('KOV-C2b (R2): legacy `slide` pravidlo je na zasuvkovom cele POTLACENE') do
  c = NxC2bD
  pl = c.plan
  NxTest.refute(c.slides(pl).any? { |h| h['rule_id'] == 'vysuvy-nl-podla-hlbky' },
                'dva vysuvy na jednu zasuvku by boli dvojita objednavka')
  codes = pl[:warnings].map { |w| w['code'] }
  NxTest.assert_equal(1, codes.count('legacy_slide_suppressed'), 'raz per stavba, nie per celo')
  w = pl[:warnings].find { |x| x['code'] == 'legacy_slide_suppressed' }
  NxTest.assert_equal('info', w['severity'])
  # Kontrola ho ZAMERNE neukazuje — pouzivatel nema co opravovat.
  NxTest.assert(NxC2bD::E::Validation::BUILD_INFO_ONLY.include?('legacy_slide_suppressed'))
end

NxTest.test('KOV-C2b (R2): fail-closed celo NEDOSTANE ani legacy vysuv') do
  c = NxC2bD
  pl = c.plan({}, 'depth' => 250.0)
  NxTest.assert_equal('drawer_no_fit', c.conflict(pl)['code'])
  NxTest.assert_equal([], c.slides(pl), 'ziadny vysuv — ani receptovy, ani legacy')
  NxTest.assert_equal([], c.drawer_parts(pl))
end

NxTest.test('KOV-C2b (R2): dvierka a legacy zasuvka bez klasifikacie idu STAROU cestou') do
  c = NxC2bD
  pl = c.plan('opening_mode' => nil, 'drawer' => nil)
  NxTest.assert_equal([], Array(pl[:drawer_conflicts]), 'legacy celo sa resolvera netyka')
  NxTest.assert_equal([], c.drawer_parts(pl))
  NxTest.assert_equal(['vysuvy-nl-podla-hlbky'], c.slides(pl).map { |h| h['rule_id'] },
                      'legacy vysuv z pravidla ostal nedotknuty')
  NxTest.refute(pl[:warnings].any? { |w| w['code'] == 'legacy_slide_suppressed' })
end

# ============================================================================
# D-93 — NL ZAMOK A JEHO MIGRACIA
# ============================================================================

NxTest.test('KOV-C2b (D-93): zamok V RADE drzi NL a polozka dostane `locked`') do
  c = NxC2bD
  pl = c.plan({}, 'hardware_overrides' => c.lock(420.0))
  it = c.slides(pl).first
  NxTest.assert_close(420.0, it['params']['nominal_length'], 0.001, 'automat by dal 470')
  NxTest.assert_equal(true, it['locked'])
  NxTest.assert_close(430.0, c.part(pl, 'front:F1/drawer_bottom')[:prod][:width], 0.001,
                      'dielce sa rezu na ZAMKNUTU dlzku')
end

NxTest.test('KOV-C2b (D-93): zamok MIMO RADU = RED `nl_lock_invalid`, NIKDY ticha zmena') do
  c = NxC2bD
  pl = c.plan({}, 'hardware_overrides' => c.lock(400.0))
  NxTest.assert_equal('nl_lock_invalid', c.conflict(pl)['code'])
  NxTest.assert_equal([], c.drawer_parts(pl))
  NxTest.assert_equal([], c.slides(pl))
end

NxTest.test('KOV-C2b (D-93): legacy `rule_id` sa premapuje na receptovu identitu') do
  c = NxC2bD
  pl = c.plan({}, 'hardware_overrides' => c.lock(420.0))
  NxTest.assert_equal([{ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
                         'from_rule_id' => 'vysuvy-nl-podla-hlbky',
                         'to_rule_id' => 'recipe:atira_sisy_v1' }],
                      pl[:drawer_override_writes])
  out = NxC2bD::CB.apply_drawer_writes(c.cfg({}, 'hardware_overrides' => c.lock(420.0)), pl)
  NxTest.assert_equal('recipe:atira_sisy_v1', out[:hardware_overrides].first['rule_id'])
  # Uz premapovany zaznam drzi zamok dalej a NEmigruje sa druhykrat.
  pl2 = c.plan({}, 'hardware_overrides' => c.lock(420.0, 'recipe:atira_sisy_v1'))
  NxTest.assert_equal([], pl2[:drawer_override_writes])
  NxTest.assert_equal(true, c.slides(pl2).first['locked'])
end

NxTest.test('KOV-C2b (D-93): `disabled` alebo pocet != 1 = RED `drawer_override_invalid`') do
  c = NxC2bD
  off = c.plan({}, 'hardware_overrides' => c.lock(470.0, REC = NxC2bD::REC::LOCK_LEGACY_RULE_ID,
                                                  'disabled' => true))
  NxTest.assert_equal('drawer_override_invalid', c.conflict(off)['code'])
  NxTest.assert_equal([], c.drawer_parts(off))
  many = c.plan({}, 'hardware_overrides' => c.lock(470.0, NxC2bD::REC::LOCK_LEGACY_RULE_ID,
                                                  'quantity' => 2))
  NxTest.assert_equal('drawer_override_invalid', c.conflict(many)['code'])
  NxTest.assert_equal([], c.slides(many))
end

# ============================================================================
# FAIL-CLOSED — VSETKYCH 9 KONFLIKTOV STAVBY
# ============================================================================

NxTest.test('KOV-C2b: kazdy konflikt STAVBY = ziadne dielce, ziadna polozka, RED nosic') do
  c = NxC2bD
  cases = {
    # ciastocna klasifikacia (opening_mode bez konstrukcie)
    'drawer_unclassified' => [{ 'drawer' => nil }, {}],
    'drawer_internal_unsupported' => [{ 'drawer' => { 'construction' => 'metal',
                                                      'variant' => 'internal' } }, {}],
    'drawer_no_fit' => [{}, { 'depth' => 250.0 }],
    'drawer_kd_unsupported' => [{}, { 'thickness' => 25.0 }],
    'nl_lock_invalid' => [{}, { 'hardware_overrides' => c.lock(400.0) }]
  }
  cases.each do |code, (front, over)|
    pl = c.plan(front, over)
    NxTest.assert_equal(code, c.conflict(pl) && c.conflict(pl)['code'], "#{code}: dovod")
    NxTest.assert_equal([], c.drawer_parts(pl), "#{code}: ziadne dielce")
    NxTest.assert_equal([], c.slides(pl), "#{code}: ziadna polozka vysuvu")
    NxTest.assert_equal('front:F1/panel', c.conflict(pl)['part_key'], "#{code}: adresa")
    NxTest.assert(c.conflict(pl)['message'].to_s.length > 10, "#{code}: slovenska hlaska")
  end
end

NxTest.test('KOV-C2b: prekazka v riadku (polica) = `drawer_obstruction`') do
  c = NxC2bD
  # Polica v korennej zone lezi v pasme riadku zasuvky.
  cfg = c.cfg({ 'height' => 600.0 }, 'zone_tree' => { 'shelves' => 1 })
  pl = NxC2bD::CN.build_plan(cfg, 'CAB-1')
  NxTest.assert_equal('drawer_obstruction', Array(pl[:drawer_conflicts]).first['code'],
                      pl[:drawer_conflicts].inspect)
  NxTest.assert_equal([], pl[:parts].select { |p| p[:material] == :drawer })
end

NxTest.test('KOV-C2b: neznamy pripnuty recept = `drawer_recipe_unknown` (aktualizuj plugin)') do
  c = NxC2bD
  pl = c.plan('drawer' => { 'construction' => 'metal',
                            'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v9' } })
  NxTest.assert_equal('drawer_recipe_unknown', c.conflict(pl)['code'])
  NxTest.assert_equal([], c.drawer_parts(pl))
end

# ============================================================================
# R5 — SYNC TYC (ORANGE, ziadny blocker)
# ============================================================================

NxTest.test('KOV-C2b (R5): P2O nad 600 mm = ORANGE `drawer_sync_recommended`, nie blocker') do
  c = NxC2bD
  pl = c.plan('opening_mode' => 'tipon')
  w = pl[:warnings].find { |x| x['code'] == 'drawer_sync_recommended' }
  NxTest.assert(w, pl[:warnings].map { |x| x['code'] }.inspect)
  NxTest.assert_equal('warn', w['severity'])
  NxTest.assert_equal('front:F1/panel', w['part_key'])
  NxTest.assert_equal(2, c.drawer_parts(pl).length, 'dielce sa NORMALNE postavia')
  NxTest.assert_equal([], Array(pl[:drawer_conflicts]))
  # Prah je INKLUZIVNY: svetla sirka presne 600 este odporuca synchronizaciu.
  narrow = c.plan({ 'opening_mode' => 'tipon' }, 'width' => 636.0)
  NxTest.assert(narrow[:warnings].any? { |x| x['code'] == 'drawer_sync_recommended' },
                'svetla sirka 600 = prah „od 600" (inkluzivne)')
  under = c.plan({ 'opening_mode' => 'tipon' }, 'width' => 635.0)
  NxTest.refute(under[:warnings].any? { |x| x['code'] == 'drawer_sync_recommended' },
                'svetla sirka 599 uz nie')
  # SiSy synchronizaciu nikdy neodporuca.
  NxTest.refute(c.plan[:warnings].any? { |x| x['code'] == 'drawer_sync_recommended' })
end

# ============================================================================
# CODEX #304 KOLO 2 — hrubky bokov Quadro
# ============================================================================

NxTest.test('Codex #304 P1: override na BOKU Quadra sa dostane do receptu') do
  c = NxC2bD
  # Oba boky 18 mm (a dno 16) — boky sa POSTAVIA na 18, cielo/chrbat sa ratia
  # z hrubky DNA (119 - 16 - 12 = 91), nie z hrubky bokov.
  th = c.th_for('F1', 16.0,
                'front:F1/box_side:left' => 18.0, 'front:F1/box_side:right' => 18.0)
  pl = c.plan({ 'drawer' => { 'construction' => 'wood' } }, {}, th)
  NxTest.assert_equal([], Array(pl[:drawer_conflicts]), pl[:drawer_conflicts].inspect)
  NxTest.assert_close(18.0, c.part(pl, 'front:F1/box_side:left')[:prod][:thickness], 0.001)
  NxTest.assert_close(18.0, c.part(pl, 'front:F1/box_side:right')[:prod][:thickness], 0.001)
  NxTest.assert_close(16.0, c.part(pl, 'front:F1/drawer_bottom')[:prod][:thickness], 0.001)
  NxTest.assert_close(91.0, c.part(pl, 'front:F1/drawer_inner_front')[:prod][:width], 0.001,
                      'celo/chrbat sa ratia z hrubky DNA')
  # Vonkajsia sirka boxu rastie s hrubkou bokov (dno ostava 818).
  NxTest.assert_close(818.0, c.part(pl, 'front:F1/drawer_bottom')[:prod][:length], 0.001)
end

NxTest.test('Codex #304 P1: ROZNE hrubky bokov = fail-closed conflict') do
  c = NxC2bD
  th = c.th_for('F1', 16.0,
                'front:F1/box_side:left' => 18.0, 'front:F1/box_side:right' => 16.0)
  pl = c.plan({ 'drawer' => { 'construction' => 'wood' } }, {}, th)
  NxTest.assert_equal('drawer_thickness_unsupported', c.conflict(pl)['code'])
  NxTest.assert(c.conflict(pl)['message'].include?('rovnakú hrúbku'), c.conflict(pl)['message'])
  NxTest.assert_equal([], c.drawer_parts(pl), 'ziadne dielce')
  NxTest.assert_equal([], c.slides(pl), 'ziadna polozka vysuvu')
end

NxTest.test('Codex #304 P1: nepodporovana hrubka BOKA uz naozaj padne') do
  c = NxC2bD
  # Oba boky 25 mm — Quadro pozna 16/18, takze `drawer_thickness_unsupported`.
  th = c.th_for('F1', 16.0,
                'front:F1/box_side:left' => 25.0, 'front:F1/box_side:right' => 25.0)
  pl = c.plan({ 'drawer' => { 'construction' => 'wood' } }, {}, th)
  NxTest.assert_equal('drawer_thickness_unsupported', c.conflict(pl)['code'])
  NxTest.assert_equal([], c.drawer_parts(pl))
end

NxTest.test('Codex #304 P1: dormantny override boku NEBLOKUJE Atiru') do
  c = NxC2bD
  # Po prepnuti Quadro -> Atira ostanu overridy `box_side` v configu (kluce
  # neexistujucich dielcov sa ZACHOVAVAJU). Atira boky nevyraba, takze rozdiel
  # medzi nimi ju nesmie zastavit.
  th = c.th_for('F1', 16.0,
                'front:F1/box_side:left' => 18.0, 'front:F1/box_side:right' => 25.0)
  pl = c.plan({}, {}, th)
  NxTest.assert_equal([], Array(pl[:drawer_conflicts]), pl[:drawer_conflicts].inspect)
  NxTest.assert_equal(2, c.drawer_parts(pl).length)
end
