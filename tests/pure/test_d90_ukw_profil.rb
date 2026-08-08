# frozen_string_literal: true
# D-90: uchytkovy profil UKW-7 na celach — ENGINE cast (PR 1).
#
# Co sa overuje:
#   1) FrontProfiles = jediny zdroj konstant (registry, normalize, forward-compat)
#   2) Fronts — riadok drzi vysku, PANEL sa skracuje o 36 mm, z ostava; kridla 1-4,
#      zasuvkove celo; guard 70 mm (warning) a MIN_DIM (raise); stary config = 'none'
#   3) HardwareRules kind part_flag_length — emisia, identita, override/disable,
#      seed v3, warning profile_rule_missing
#   4) params_label („rez 597 mm") — serverovy format pre tab Vyroba aj CSV
#   5) sablona — config s profilom prezije JSON round-trip
#
# ABS sa profilom NEMENI (Michal 9.8., foto realnej montaze): hrana pod
# profilom sa olepuje normalne — profil sa nasuva na hotovu olepenu hranu.
require_relative '../helper' unless defined?(NxTest)

module NxD90
  module_function

  def e
    Noxun::Engine
  end

  def f
    e::Fronts
  end

  def fp
    e::FrontProfiles
  end

  def hr
    e::HardwareRules
  end

  # Config ciel s jednym riadkom (profil sa zapina cez kluc 'profile').
  def cfg(item, extra = {})
    { 'items' => [item] }.merge(extra)
  end

  def layout(item, extra = {}, width = 600.0, height = 720.0, floor = 100.0)
    f.layout(cfg(item, extra), width, height, floor, 18.0)
  end

  def door(over = {})
    { 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 500.0,
      'wings' => '1' }.merge(over)
  end

  # Deskriptor cela pre unit testy pravidiel (rovnaky tvar ako v plane).
  def part(profile, width = 596.0, role = 'front_door', key = 'front:F1/wing:single')
    { role: role, part_key: key, suffix: 'DOOR-1', name: 'Dvierka 1',
      profile: profile, prod: { length: 464.0, width: width, thickness: 18.0 } }
  end

  def ctx
    { 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'floor_height' => 100.0,
      'available_width' => 564.0, 'available_height' => 584.0, 'available_depth' => 510.0,
      'support' => 'legs', 'cabinet_type' => 'lower' }
  end

  def rules
    hr.normalize_rules(hr::SEED_RULES)
  end

  def handles(res)
    res[:items].select { |it| it['generic_type'] == 'handle' }
  end
end

# ---------------------------------------------------------------------------
# 1) FrontProfiles — registry
# ---------------------------------------------------------------------------

NxTest.test('D-90 profily: registry UKW-7 (36 mm) + normalize je forward-compat') do
  fp = NxD90.fp
  NxTest.assert_close(36.0, fp.reduction('ukw7'), 0.001, 'UKW-7 skracuje celo o 36 mm')
  NxTest.assert_equal('Profil UKW-7', fp.name('ukw7'))
  NxTest.assert(fp.known?('ukw7'))
  NxTest.refute(fp.known?('none'), "'none' nie je profil, ale jeho absencia")
  # Neznamy / prazdny / chybajuci vstup = 'none' (ziadna migracia starych configov,
  # config z NOVSEJ verzie sa sklopi na neutral namiesto padu).
  [nil, '', 'ukw11', 'UKW7', 42].each do |raw|
    NxTest.assert_equal('none', fp.normalize(raw), "#{raw.inspect} -> none")
    NxTest.assert_close(0.0, fp.reduction(raw), 0.001)
  end
  NxTest.assert_equal('ukw7', fp.of(profile: 'ukw7'), 'of() cita symbolovy kluc deskriptora')
  NxTest.assert_equal('ukw7', fp.of('profile' => 'ukw7'), 'of() cita aj string kluc')
  NxTest.assert_equal(nil, fp.of(profile: 'none'))
  NxTest.assert_equal(nil, fp.of({}))
  NxTest.assert_equal(nil, fp.of(nil))
end

# ---------------------------------------------------------------------------
# 2) Fronts — matematika panelu
# ---------------------------------------------------------------------------

NxTest.test('D-90 fronts: profil skrati PANEL o 36 mm, riadok aj z ostavaju') do
  base = NxD90.layout(NxD90.door)
  prof = NxD90.layout(NxD90.door('profile' => 'ukw7'))
  b = base[:parts][0]
  p = prof[:parts][0]
  NxTest.assert_close(500.0, b[:box][2], 0.01, 'bez profilu panel = cela vyska riadku')
  NxTest.assert_close(464.0, p[:box][2], 0.01, 'panel = 500 - 36')
  NxTest.assert_close(464.0, p[:prod][:length], 0.01, 'prod length = skrateny panel (kusovnik/VEPO bez zasahu)')
  NxTest.assert_close(b[:prod][:width], p[:prod][:width], 0.01, 'sirka sa nemeni')
  NxTest.assert_equal(b[:origin], p[:origin], 'panel ostava na z (cela sa kladu odspodu)')
  NxTest.assert_close(500.0, prof[:items][0]['height'], 0.01, 'riadok v rade drzi POVODNU vysku')
  NxTest.assert_equal('ukw7', prof[:items][0]['profile'], 'resolved item nesie profil (nahlad/UI)')
  # pasmo profilu nad panelom (vizual PR 2)
  NxTest.assert_close(102.0 + 464.0, p[:profile_band][:z], 0.01, 'pasmo zacina na vrchu panelu')
  NxTest.assert_close(36.0, p[:profile_band][:h], 0.01)
  NxTest.assert_equal('none', base[:items][0]['profile'])
  NxTest.assert_equal(nil, base[:parts][0][:profile_band], 'bez profilu ziadne pasmo')
  # ABS sa profilom NEMENI — deskriptor ziadne hrany nepotlaca
  NxTest.assert_equal(nil, p[:suppress_edges], 'ziadne potlacenie hran (hrana sa olepuje aj pod profilom)')
end

NxTest.test('D-90 fronts: profil na 2/3/4 kridlach — kazde kridlo skratene, sirky nedotknute') do
  [2, 3, 4].each do |n|
    base = NxD90.layout(NxD90.door('wings' => n.to_s))
    prof = NxD90.layout(NxD90.door('wings' => n.to_s, 'profile' => 'ukw7'))
    NxTest.assert_equal(n, prof[:parts].length, "#{n} kridla")
    prof[:parts].each_with_index do |p, i|
      NxTest.assert_close(464.0, p[:box][2], 0.01, "kridlo #{i + 1}: panel skrateny")
      NxTest.assert_close(base[:parts][i][:box][0], p[:box][0], 0.01, "kridlo #{i + 1}: sirka nedotknuta")
      NxTest.assert_equal(base[:parts][i][:origin], p[:origin], "kridlo #{i + 1}: poloha nedotknuta")
    end
  end
end

NxTest.test('D-90 fronts: profil na zasuvkovom cele') do
  out = NxD90.layout({ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                       'height' => 200.0, 'profile' => 'ukw7' })
  p = out[:parts][0]
  NxTest.assert_equal('drawer_front', p[:role])
  NxTest.assert_close(164.0, p[:box][2], 0.01, 'zasuvkove celo 200 - 36')
end

NxTest.test('D-90 fronts: guard — panel pod 70 mm hlasi warning, bez panelu raise') do
  # 100 - 36 = 64 mm panel: postavi sa, ale hlasi sa (skoro iste omyl)
  out = NxD90.layout(NxD90.door('height' => 100.0, 'profile' => 'ukw7'))
  w = out[:warnings].find { |x| x['code'] == 'profile_panel_low' }
  NxTest.refute(w.nil?, 'nizky panel = warning v kanali planu')
  NxTest.assert_close(64.0, w['data']['panel_height'], 0.01)
  NxTest.assert(w['message'].include?('64'), "sprava uvadza vysku panelu: #{w['message']}")
  NxTest.assert_close(100.0, out[:items][0]['height'], 0.01, 'riadok drzi vysku aj s warningom')
  # hranica: 106 - 36 = 70 mm uz warning NEspusti
  ok = NxD90.layout(NxD90.door('height' => 106.0, 'profile' => 'ukw7'))
  NxTest.assert_equal([], ok[:warnings], 'presne 70 mm panel je este OK')
  # 36 mm riadok = panel 0 -> tvrdy raise (profil bez panelu nesmie ticho prejst)
  NxTest.assert_raise(/príliš nízke/) do
    NxD90.layout(NxD90.door('height' => 36.0, 'profile' => 'ukw7'))
  end
  NxTest.assert_raise(/príliš nízke/) do
    NxD90.layout(NxD90.door('height' => 20.0, 'profile' => 'ukw7'))
  end
  # bez profilu sa nic z toho nedeje (spravanie starych korpusov nedotknute)
  NxTest.assert_equal([], NxD90.layout(NxD90.door('height' => 36.0))[:warnings])
end

NxTest.test('D-90 fronts: normalize — stary config bez kluca = none, neznamy profil = none') do
  f = NxD90.f
  n = f.normalize_config('items' => [
                           { 'id' => 'F1', 'type' => 'door' },
                           { 'id' => 'F2', 'type' => 'door', 'profile' => 'ukw7' },
                           { 'id' => 'F3', 'type' => 'door', 'profile' => 'ukw99' },
                           { 'id' => 'F4', 'type' => 'none', 'profile' => 'ukw7' },
                           { 'id' => 'F5', 'type' => 'drawer_front', :profile => 'ukw7' }
                         ])
  NxTest.assert_equal(%w[none ukw7 none none ukw7], n['items'].map { |it| it['profile'] },
                      'chybajuci/neznamy kluc = none; „Bez cela" profil nema; symbolovy kluc prejde')
  NxTest.assert_equal('none', f.legacy_string('2')['items'][0]['profile'], 'legacy string config = bez profilu')
  # round-trip: normalize(normalize(x)) je stabilne
  NxTest.assert_equal(n, f.normalize_config(n))
end

# ---------------------------------------------------------------------------
# 3) Pravidla kovania — kind part_flag_length
# ---------------------------------------------------------------------------

NxTest.test('D-90 pravidla: seed v3 nesie obe pravidla profilu (dvierka + zasuvky)') do
  hr = NxD90.hr
  NxTest.assert_equal(3, hr::SEED_VERSION, 'seed v3 = D-90')
  ids = hr::SEED_RULES.map { |r| r['rule_id'] }
  NxTest.assert(ids.include?('uchytkovy-profil'), 'pravidlo pre dvierka')
  NxTest.assert(ids.include?('uchytkovy-profil-zasuvky'), 'pravidlo pre zasuvkove cela')
  hr::SEED_RULES.select { |r| r['kind'] == 'part_flag_length' }.each do |r|
    NxTest.assert_equal('handle', r['output'])
    NxTest.assert(%w[front_door drawer_front].include?(r['applies_to']['role']),
                  'applies_to je JEDNA rola (ako ostatne pravidla)')
  end
  NxTest.assert(hr::KINDS.include?('part_flag_length'), 'kind je v slovniku (inak by ho evaluate preskocil)')
end

NxTest.test('D-90 pravidla: polozka vznikne LEN pre dielec s profilom, params nesu rez') do
  hr = NxD90.hr
  parts = [NxD90.part('ukw7', 596.0), NxD90.part('none', 400.0, 'front_door', 'front:F2/wing:single')]
  res = hr.evaluate({}, parts, NxD90.ctx, rules: NxD90.rules)
  hs = NxD90.handles(res)
  NxTest.assert_equal(1, hs.length, 'celo bez profilu polozku nedostane')
  it = hs.first
  NxTest.assert_equal('front:F1/wing:single', it['owner_part_key'], 'vlastnik = kluc dielca')
  NxTest.assert_equal('uchytkovy-profil', it['rule_id'])
  NxTest.assert_equal(1, it['quantity'])
  NxTest.assert_equal(1, it['rule_quantity'])
  NxTest.assert_equal('counted', it['production_class'], 'faza 1 kontrakt nezmeneny')
  NxTest.assert_equal(true, it['manufactured'])
  NxTest.assert_equal(nil, it['variant_id'], 'kod/farbu mapuje az faza 2 (davka D)')
  NxTest.assert_equal('rule', it['source'])
  NxTest.assert_close(596.0, it['params']['cut_length_mm'], 0.01, 'rez = SIRKA dielca')
  NxTest.assert_equal('ukw7', it['params']['profile'])
  # polozka musi prejst kontraktom planu
  Noxun::Engine::BuildPlan.validate_hardware!(it)
end

NxTest.test('D-90 pravidla: zasuvkove celo dostane vlastne pravidlo; iné roly nikdy') do
  hr = NxD90.hr
  drw = NxD90.part('ukw7', 500.0, 'drawer_front', 'front:F3/panel')
  shelf = { role: 'shelf', part_key: 'zone:Z1/shelf:1', suffix: 'SHELF-1', name: 'Polica',
            profile: 'ukw7', prod: { length: 564.0, width: 500.0, thickness: 18.0 } }
  res = hr.evaluate({}, [drw, shelf], NxD90.ctx, rules: NxD90.rules)
  hs = NxD90.handles(res)
  NxTest.assert_equal(1, hs.length, 'profil na police (nezmysel) nikdy nevyrobi polozku')
  NxTest.assert_equal('front:F3/panel', hs.first['owner_part_key'])
  NxTest.assert_equal('uchytkovy-profil-zasuvky', hs.first['rule_id'])
  NxTest.assert_close(500.0, hs.first['params']['cut_length_mm'], 0.01)
end

NxTest.test('D-90 pravidla: override/disable funguju cez existujucu identitu') do
  hr = NxD90.hr
  parts = [NxD90.part('ukw7', 596.0)]
  ov = { hardware_overrides: [{ 'owner_part_key' => 'front:F1/wing:single',
                                'generic_type' => 'handle',
                                'rule_id' => 'uchytkovy-profil', 'quantity' => 2 }] }
  res = hr.evaluate(ov, parts, NxD90.ctx, rules: NxD90.rules)
  it = NxD90.handles(res).first
  NxTest.assert_equal(2, it['quantity'], 'rucny pocet prebije pravidlo')
  NxTest.assert_equal('manual', it['source'])
  NxTest.assert_equal(1, it['rule_quantity'], 'povodny pocet z pravidla ostava')
  off = { hardware_overrides: [{ 'owner_part_key' => 'front:F1/wing:single',
                                 'generic_type' => 'handle',
                                 'rule_id' => 'uchytkovy-profil', 'disabled' => true }] }
  NxTest.assert_equal(0, NxD90.handles(hr.evaluate(off, parts, NxD90.ctx, rules: NxD90.rules)).length,
                      'vypnutie profilu na jednom kridle')
end

NxTest.test('D-90 pravidla: vypnute pravidlo (enabled false) polozku nevyrobi, ale ani nehlasi') do
  hr = NxD90.hr
  rules = NxD90.rules.map { |r| r['kind'] == 'part_flag_length' ? r.merge('enabled' => false) : r }
  res = hr.evaluate({}, [NxD90.part('ukw7')], NxD90.ctx, rules: rules)
  NxTest.assert_equal(0, NxD90.handles(res).length)
  NxTest.assert_equal([], res[:warnings].select { |w| w['code'] == 'profile_rule_missing' },
                      'vedome vypnute pravidlo NIE JE profile_rule_missing (kryje ho ORANGE vypnuteho kovania)')
end

NxTest.test('D-90 pravidla: profile_rule_missing — projekt bez pravidla profilu') do
  hr = NxD90.hr
  old = NxD90.rules.reject { |r| r['kind'] == 'part_flag_length' } # snapshot zo starsieho projektu
  parts = [NxD90.part('ukw7'), NxD90.part('none', 400.0, 'front_door', 'front:F2/wing:single')]
  res = hr.evaluate({}, parts, NxD90.ctx, rules: old)
  ws = res[:warnings].select { |w| w['code'] == 'profile_rule_missing' }
  NxTest.assert_equal(1, ws.length, 'len dielec S profilom (nie kazde celo)')
  NxTest.assert_equal('front:F1/wing:single', ws.first['part_key'])
  NxTest.assert_equal('ukw7', ws.first['data']['profile'])
  NxTest.assert(ws.first['message'].include?('Doplniť nové predvolené'),
                "sprava obsahuje navod: #{ws.first['message']}")
  NxTest.assert_equal('warn', ws.first['severity'], 'ORANGE v semafore (kategoria stavba)')
  # so seed pravidlami sa uz nic nehlasi
  NxTest.assert_equal([], hr.evaluate({}, parts, NxD90.ctx, rules: NxD90.rules)[:warnings]
                             .select { |w| w['code'] == 'profile_rule_missing' })
end

NxTest.test('D-90 pravidla: profile_rule_missing sa nespusti pri vyradenom OVERRIDE (pravidlo existuje)') do
  hr = NxD90.hr
  off = { hardware_overrides: [{ 'owner_part_key' => 'front:F1/wing:single',
                                 'generic_type' => 'handle',
                                 'rule_id' => 'uchytkovy-profil', 'disabled' => true }] }
  res = hr.evaluate(off, [NxD90.part('ukw7')], NxD90.ctx, rules: NxD90.rules)
  NxTest.assert_equal([], res[:warnings].select { |w| w['code'] == 'profile_rule_missing' })
end

NxTest.test('D-90 pravidla: build_plan koncoveho korpusu — profil, rez a hrany naraz') do
  NxTest.skip!('build_plan default cita globalnu kniznicu — headless only') unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  cn = Noxun::Engine::Construction
  cfg = cb.normalize('fronts' => { 'items' => [
                       { 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 500.0,
                         'wings' => '2', 'profile' => 'ukw7' }
                     ] })
  plan = cn.build_plan(cfg, 'CAB-001')
  fronts = plan[:parts].select { |pd| pd[:role] == 'front_door' }
  NxTest.assert_equal(2, fronts.length)
  fronts.each { |pd| NxTest.assert_close(464.0, pd[:prod][:length], 0.01, 'plan nesie skrateny panel') }
  hs = plan[:hardware].select { |h| h['generic_type'] == 'handle' }
  NxTest.assert_equal(2, hs.length, 'kazde kridlo ma vlastny kus profilu')
  hs.each do |h|
    NxTest.assert_close(fronts.first[:prod][:width], h['params']['cut_length_mm'], 0.01,
                        'rez = sirka kridla')
  end
  NxTest.assert_equal('ukw7', plan[:front_items][0]['profile'])
end

NxTest.test('D-90 pravidla: project_seed_plan je CISTA (nic nezapise) a vie, co pribudne') do
  hr = NxD90.hr
  m = NxTest::FakeEntity.new
  old = NxD90.rules.reject { |r| r['kind'] == 'part_flag_length' }
  hr.set_project_rules(m, old)
  rules, added, refreshed = hr.project_seed_plan(hr.project_rules(m))
  NxTest.assert_equal(%w[uchytkovy-profil uchytkovy-profil-zasuvky], added.sort,
                      'plan vie DOPREDU, ktore pravidla pribudnu')
  NxTest.assert_equal([], refreshed)
  NxTest.assert_equal(hr::SEED_RULES.length, rules.length)
  NxTest.assert_equal(old, hr.project_rules(m), 'plan je cisty — snapshot ostal nedotknuty')
  # idempotencia: nad uz doplnenym snapshotom nic nepribudne
  hr.set_project_rules(m, rules)
  _, added2, refreshed2 = hr.project_seed_plan(hr.project_rules(m))
  NxTest.assert_equal([[], []], [added2, refreshed2])
end

NxTest.test('D-90 pravidla: vypnutie profilu upratalo mrtvy override (Codex #144 P2)') do
  cb = Noxun::Engine::CabinetBuilder
  ov = [{ 'owner_part_key' => 'front:F1/wing:single', 'generic_type' => 'handle',
          'rule_id' => 'uchytkovy-profil', 'disabled' => true },
        { 'owner_part_key' => 'front:F1/wing:single', 'generic_type' => 'hinge',
          'rule_id' => 'zavesy-podla-vysky', 'quantity' => 3 }]
  door = { 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 500.0, 'wings' => '1' }
  with_profile = cb.normalize('hardware_overrides' => ov,
                              'fronts' => { 'items' => [door.merge('profile' => 'ukw7')] })
  NxTest.assert_equal(2, with_profile[:hardware_overrides].length,
                      'kym profil zije, zasah zije s nim')
  without = cb.normalize('hardware_overrides' => ov, 'fronts' => { 'items' => [door] })
  rules_left = without[:hardware_overrides].map { |o| o['rule_id'] }
  NxTest.assert_equal(['zavesy-podla-vysky'], rules_left,
                      'po vypnuti profilu ostal len zaves — mrtvy zaznam profilu je prec')
end

NxTest.test('D-90 guard: panel posiela profil spat (form.js round-trip pred PR 2)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')
  NxTest.assert(src.include?('row.dataset.frontProfile = item.profile'),
                'addFrontRow musi ulozit profil riadku do datasetu')
  NxTest.assert(src.include?("profile: r.dataset.frontProfile || 'none'"),
                'collectFronts musi profil posielat spat — inak by ho kazdy edit zhodil')
end

# ---------------------------------------------------------------------------
# 4) ABS — profil ju NEMENI (Michal 9.8.: hrana sa olepuje aj pod profilom)
# ---------------------------------------------------------------------------

# Docasny katalog (vzor test_2a3_picker) — bajt-presna obnova povodneho stavu.
def d90_with_catalog(sheets, edges, schema: 2)
  mat = Noxun::Engine::Materials
  store = Noxun::Engine::JsonFileStore
  mat.catalog # seed, aby subor existoval
  before = File.binread(mat.path)
  store.write(mat.path, { 'std' => mat::STD, 'schema' => schema,
                          'sheets' => sheets, 'edges' => edges })
  yield
ensure
  if before
    File.binwrite(mat.path, before)
    store.invalidate(mat.path)
  end
end

def d90_sheet(id = 'S18')
  { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => 'G1', 'type' => 'DTDL',
    'thickness' => 18.0, 'grain' => 'length', 'color' => [200, 200, 200],
    'production_class' => 'sheet', 'group_id' => 'GRP-G1', 'structure' => 'ST9' }
end

def d90_edge(id = 'E10')
  { 'abs_id' => id, 'decor' => 'G1', 'thickness' => 1.0, 'color' => [200, 200, 200],
    'group_id' => 'GRP-G1', 'structure' => 'ST9', 'width' => 23.0 }
end

NxTest.test('D-90 ABS: celo s profilom sa olepuje DOOKOLA presne ako bez profilu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  d90_with_catalog([d90_sheet], [d90_edge], schema: 2) do
    base = { role: 'front_door', part_key: 'front:F1/wing:single', suffix: 'DOOR-1',
             name: 'Dvierka 1', material: :front,
             box: [596.0, 18.0, 464.0], origin: [2.0, -18.0, 102.0],
             prod: { length: 464.0, width: 596.0, thickness: 18.0 } }
    plain_issues = []
    plain = cb.resolve_part(base.merge(profile: 'none'), 'S18', 'S18', 'S18', {},
                            abs_issues: plain_issues)
    prof_issues = []
    prof = cb.resolve_part(base.merge(profile: 'ukw7', profile_band: { z: 566.0, h: 36.0 }),
                           'S18', 'S18', 'S18', {}, abs_issues: prof_issues)
    NxTest.assert_equal(%w[E10 E10 E10 E10], %w[L1 L2 W1 W2].map { |c| prof[:edges][c] },
                        'profil ABS NEMENI — profil sa nasuva na hotovu olepenu hranu')
    NxTest.assert_equal(plain[:edges], prof[:edges], 'hrany su zhodne s celom bez profilu')
    NxTest.assert_equal([[], []], [plain_issues, prof_issues])
  end
end

# ---------------------------------------------------------------------------
# 5) Zobrazenie — serverovy format „rez XXX mm"
# ---------------------------------------------------------------------------

NxTest.test('D-90 zobrazenie: params_label je serverovy text pre Vyrobu aj CSV') do
  hr = NxD90.hr
  NxTest.assert_equal('rez 597 mm', hr.params_label('cut_length_mm' => 597.0))
  NxTest.assert_equal('rez 596 mm', hr.params_label('cut_length_mm' => 596.0, 'profile' => 'ukw7'))
  NxTest.assert_equal('rez 596,5 mm', hr.params_label('cut_length_mm' => 596.5), 'desatiny so slovenskou ciarkou')
  NxTest.assert_equal(nil, hr.params_label('height' => 150.0), 'polozka bez rezu nema co zobrazit')
  NxTest.assert_equal(nil, hr.params_label({}))
  NxTest.assert_equal(nil, hr.params_label(nil))
  NxTest.assert_equal(nil, hr.params_label('cut_length_mm' => 'x'), 'necislo sa ignoruje')
end

NxTest.test('D-90 zobrazenie: nemapovana polozka nesie params_label do CSV aj do okna') do
  hws = Noxun::Engine::HardwareSets
  item = { 'owner_id' => 'CAB-001', 'owner_part_key' => 'front:F1/wing:single',
           'generic_type' => 'handle', 'rule_id' => 'uchytkovy-profil', 'quantity' => 1,
           'params' => { 'cut_length_mm' => 597.0, 'profile' => 'ukw7' } }
  exp = hws.expand([item], nil)
  u = exp['unmapped'].first
  NxTest.refute(u.nil?, 'bez setu (davka D) je profil nemapovany — ale VIDITELNY')
  NxTest.assert_equal('rez 597 mm', u['params_label'])
  csv = hws.purchase_csv(exp, project: 'Test')
  NxTest.assert(csv.include?('rez 597 mm'), "CSV kovania nesie rez: #{csv.inspect[0, 400]}")
end

# ---------------------------------------------------------------------------
# 6) Sablony — round-trip configu s profilom
# ---------------------------------------------------------------------------

NxTest.test('D-90 sablony: config s profilom prezije ulozenie aj nacitanie sablony') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  ts = Noxun::Engine::TemplateStore
  cb = Noxun::Engine::CabinetBuilder
  cn = Noxun::Engine::Construction
  ts.reload!
  before = ts.load.length
  fronts = Noxun::Engine::Fronts.normalize_config(
    'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 500.0,
                  'wings' => '1', 'profile' => 'ukw7' }]
  )
  config = ts.find('Dolna klasik')['config'].merge('fronts' => fronts)
  NxTest.assert(ts.upsert('D90 profil test', config))
  ts.reload!
  back = ts.find('D90 profil test')
  NxTest.assert_equal('ukw7', back['config']['fronts']['items'][0]['profile'],
                      'profil prezil JSON round-trip sablony')
  plan = cn.build_plan(cb.normalize(back['config']), 'CAB-001')
  door = plan[:parts].find { |pd| pd[:role] == 'front_door' }
  NxTest.assert_close(464.0, door[:prod][:length], 0.01, 'sablona postavi skratene celo')
ensure
  if NxTest.headless?
    Noxun::Engine::TemplateStore.delete('D90 profil test')
    Noxun::Engine::TemplateStore.reload!
    NxTest.assert_equal(before, Noxun::Engine::TemplateStore.load.length) if before
  end
end
