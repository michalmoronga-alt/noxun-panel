# frozen_string_literal: true
# ŠÍRKA OD 50 mm — ČASŤ B: 2 NOHY POD ÚZKOU SKRINKOU (Michal 7.-8.10.2026).
#
# Rozhodnutia Michala: skrinka UŽŠIA než 200 mm má 2 nohy v strede šírky
# (vpredu + vzadu v osi), v nákupe 2 ks; 200–999 mm ostáva 4, od 1000 mm 6.
# Počet nôh žije v pravidle kovania `nohy-zakladne` (pásma podľa šírky), takže
# sa strážia štyri veci:
#   1. PÁSMA — konvencia `v <= max`: 199 aj 199,5 dá 2, 200 dá 4 (audit FIX 4);
#   2. MIGRÁCIA SEEDU 7 -> 8 — `merge_seed` obnoví LEN nedotknutý starší tvar,
#      vlastná úprava pravidla ostáva;
#   3. `Bom.leg_stale_issue` — úzka skrinka s uloženými 4 nohami a snapshotom
#      pravidiel < 8 = ORANGE „prestav skrinku" (migračné hranice v6 nedotknuté);
#   4. KRESLENIE — pozície valcov (čistá `leg_layout`): stred šírky, rôzne y;
#      plytká skrinka neprekryje valce (audit FIX 2), počet v nákupe ostáva.
require_relative '../helper' unless defined?(NxTest)
require_relative 'test_kovg1b_nohy_pravidla' unless defined?(NxKovG1b)

module NxSirka50
  module_function

  C  = NxKovG1b
  HR = Noxun::Engine::HardwareRules
  CB = Noxun::Engine::CabinetBuilder
  CN = Noxun::Engine::Construction

  def cfg(over = {})
    CB.normalize({ 'type' => 'lower', 'width' => 150.0, 'height' => 720.0, 'depth' => 560.0,
                   'thickness' => 18.0, 'floor_height' => 100.0 }.merge(over))
  end

  def dist(a, b)
    Math.hypot(a[0] - b[0], a[1] - b[1])
  end
end

NxTest.test('Šírka 50 (B1): pásma nôh — pod 200 mm 2, 200–999 4, od 1000 6 (konvencia v <= max)') do
  c = NxSirka50::C
  { 50.0 => 2, 75.0 => 2, 150.0 => 2, 199.0 => 2, 199.5 => 2, 199.999 => 2,
    200.0 => 4, 200.5 => 4, 600.0 => 4, 999.0 => 4,
    1000.0 => 6, 1200.0 => 6, 3000.0 => 6 }.each do |w, want|
    res = c.evaluate('width' => w, 'kb' => w)
    NxTest.assert_equal(want, c.legs(res), "šírka #{w} -> #{want} nôh")
  end
  # Príchyt sokla: 1 ks na začaté 4 nohy -> pri 2 nohách tiež 1.
  NxTest.assert_equal(1, c.clips(c.evaluate('width' => 150.0, 'kb' => 150.0)), 'úzka skrinka: 1 príchyt')
  NxTest.assert_equal(1, c.clips(c.evaluate('width' => 600.0)), '600: 1 príchyt (bez zmeny)')
  NxTest.assert_equal(2, c.clips(c.evaluate('width' => 1200.0)), '1200: 2 príchyty (bez zmeny)')
end

NxTest.test('Šírka 50 (B1): seed nesie tri pásma a prechádza uložením pravidiel') do
  c = NxKovG1b
  leg = c.rule_of(c::LEG_RULE)
  NxTest.assert_equal([[NxSirka50::HR::LEG_NARROW_BAND_MAX, 2], [999.0, 4], [nil, 6]],
                      leg['bands'].map { |b| [b['max'], b['quantity']] })
  NxTest.assert(NxSirka50::HR::LEG_NARROW_BAND_MAX < NxSirka50::HR::LEG_NARROW_BELOW_MM,
                'pásmo 2 nôh končí tesne pod 200')
  NxTest.assert_equal([], NxSirka50::HR.rules_problems(c.rules), 'pravidlá sa dajú uložiť')
  NxTest.assert(NxSirka50::HR::SEED_VERSION >= NxSirka50::HR::LEG_NARROW_SEED_VERSION)
end

NxTest.test('Šírka 50 (B2): nákup úzkej skrinky = 2 nohy (ks aj kód)') do
  c = NxKovG1b
  rows, = c.buy(150.0, 100.0)
  legs_rows = rows.reject { |code, _| code == c::CLIP_SET || code == '950' }
  NxTest.assert(legs_rows.values.any? { |q| q == 2 }, "nohy v nákupe po 2 ks: #{rows.inspect}")
  NxTest.refute(legs_rows.values.any? { |q| q == 4 }, 'a nie po 4')
  rows600, = c.buy(600.0, 100.0)
  NxTest.assert(rows600.values.any? { |q| q == 4 }, '600 mm ostáva na 4 nohách')
end

NxTest.test('Šírka 50 (B3): migrácia seedu — nedotknutý v6/v7 tvar sa obnoví, upravený ostáva') do
  c = NxKovG1b
  hr = NxSirka50::HR
  v7 = hr.normalize_rules([{ 'rule_id' => c::LEG_RULE, 'enabled' => true,
                             'applies_to' => { 'role' => 'cabinet', 'support' => %w[legs plinth] },
                             'output' => 'leg', 'kind' => 'bands', 'input' => 'width',
                             'bands' => [{ 'max' => 999.0, 'quantity' => 4 }, { 'max' => nil, 'quantity' => 6 }],
                             'params_from_context' => { 'height' => 'floor_height' } }] +
                           c::HR::SEED_RULES.reject { |r| r['rule_id'] == c::LEG_RULE })
  merged, changed = hr.merge_seed(v7, 7)
  NxTest.assert(changed, 'seed 7 -> 8 prebehne')
  NxTest.assert_equal([2, 4, 6], c.rule_of(c::LEG_RULE, merged)['bands'].map { |b| b['quantity'] },
                      'nedotknutý v6/v7 tvar dostal pásmo 2 nôh')
  # Používateľ mal vlastné pásma (napr. 5 nôh od 800) — NEPREPISUJE sa.
  mine = v7.map do |r|
    next r unless r['rule_id'] == c::LEG_RULE
    r.merge('bands' => [{ 'max' => 799.0, 'quantity' => 4 }, { 'max' => nil, 'quantity' => 5 }])
  end
  merged2, = hr.merge_seed(mine, 7)
  NxTest.assert_equal([[799.0, 4], [nil, 5]],
                      c.rule_of(c::LEG_RULE, merged2)['bands'].map { |b| [b['max'], b['quantity']] },
                      'upravené pravidlo ostáva presne tak, ako ho nechal používateľ')
  # Aj iná ÚPRAVA (vypnuté pravidlo) sa neprepisuje.
  off = v7.map { |r| r['rule_id'] == c::LEG_RULE ? r.merge('enabled' => false) : r }
  merged3, = hr.merge_seed(off, 7)
  NxTest.assert_equal(false, c.rule_of(c::LEG_RULE, merged3)['enabled'], 'vypnuté pravidlo ostáva vypnuté')
  # Starší tvar `fixed 4` (v1–v5) sa tiež obnoví na NOVÝ tvar (s pásmom 2).
  fixed = hr.normalize_rules([hr::LEGACY_SEED_SHAPES[c::LEG_RULE][0]] +
                             hr::SEED_RULES.reject { |r| r['rule_id'] == c::LEG_RULE })
  merged4, = hr.merge_seed(fixed, 5)
  NxTest.assert_equal([2, 4, 6], c.rule_of(c::LEG_RULE, merged4)['bands'].map { |b| b['quantity'] })
  # Z aktuálnej verzie sa už nič nemení.
  NxTest.assert_equal([merged, false], hr.merge_seed(merged, hr::SEED_VERSION))
  # „Doplniť nové predvoľby" (snapshot projektu) ide tou istou cestou.
  _, _, refreshed = hr.project_seed_plan(v7)
  NxTest.assert_equal([c::LEG_RULE], refreshed, 'snapshot v7: pravidlo nôh sa obnoví')
end

NxTest.test('Šírka 50 (B4): leg_stale v8 — úzka skrinka so 4 nohami a seedom < 8 = ORANGE') do
  c = NxKovG1b
  hr = NxSirka50::HR
  narrow = { 'width' => 150.0, 'hardware' => [c.leg_item(4), c.clip_item(1)] }
  iss = c.stale_issue(narrow.merge('rules_seed_version' => 7))
  NxTest.assert(iss, 'úzka skrinka s 4 nohami a seedom 7')
  NxTest.assert_equal('orange', iss['severity'])
  NxTest.assert(iss['message'].include?('2 nohy') && iss['message'].include?('1 príchyt'),
                "hláška počíta 2 nohy + 1 príchyt: #{iss['message']}")
  NxTest.assert(iss['message'].include?('Doplniť nové predvoľby'), 'a nápravu')
  NxTest.assert_equal(nil, c.stale_issue(narrow.merge('rules_seed_version' => hr::LEG_NARROW_SEED_VERSION)),
                      'po prestavbe pod seedom 8 veta zhasne')
  NxTest.assert_equal(nil, c.stale_issue('width' => 150.0, 'rules_seed_version' => 7,
                                         'hardware' => [c.leg_item(2), c.clip_item(1)]),
                      'úzka skrinka s 2 nohami je v poriadku')
  NxTest.assert_equal(nil, c.stale_issue('width' => 150.0, 'rules_seed_version' => 7,
                                         'hardware' => [c.leg_item(4, 'source' => 'manual'), c.clip_item(1)]),
                      'ručne zamknuté 4 nohy sú vedomé rozhodnutie')
  NxTest.assert_equal(nil, c.stale_issue('width' => 200.0, 'rules_seed_version' => 7,
                                         'hardware' => [c.leg_item(4), c.clip_item(1)]),
                      '200 mm je už pásmo 4 nôh — nič sa nemení')
  # Pôvodné migračné hranice (v6) sa NEMENIA: široká skrinka pod seedom 5 stále hlási 6 nôh.
  wide = c.stale_issue
  NxTest.assert(wide && wide['message'].include?('6 nôh + 2 príchyty') && wide['message'].include?('pravidlom 4/6'),
                "v6 symptóm bez zmeny: #{wide && wide['message']}")
  # Seed 6 / 7 so širokou skrinkou nehlási nič (v6 symptómy sa pýtajú len seedu < 6).
  NxTest.assert_equal(nil, c.stale_issue('rules_seed_version' => 7), 'široká skrinka s seedom 7 je v poriadku')
  # Úzka skrinka pod starým seedom (5): veta počíta 2 nohy, nie 4.
  old = c.stale_issue('width' => 150.0, 'hardware' => [c.leg_item(4)])
  NxTest.assert(old && old['message'].include?('2 nohy'), "úzka pod seedom 5: #{old && old['message']}")
  NxTest.assert(old['message'].include?('2/4/6'), 'a pomenuje pravidlo podľa šírky')
end

NxTest.test('Šírka 50 (B5): pozície 2 nôh — stred šírky, predná a zadná v osi') do
  [50.0, 75.0, 150.0, 199.0].each do |w|
    lay = NxSirka50::CB.leg_layout(NxSirka50.cfg('width' => w), 2)
    NxTest.assert_equal(2, lay[:positions].length, "šírka #{w}: dva valce")
    NxTest.assert_equal(false, lay[:overlap])
    xs = lay[:positions].map { |x, _| x }
    ys = lay[:positions].map { |_, y| y }
    NxTest.assert(xs.all? { |x| (x - w / 2.0).abs < 0.001 }, "šírka #{w}: x v strede šírky (#{xs.inspect})")
    NxTest.assert(ys[1] - ys[0] >= NxSirka50::CB::LEG_DIAMETER, "šírka #{w}: predná a zadná sa nekryjú (#{ys.inspect})")
    NxTest.assert(ys[0] < ys[1], 'prvá je predná')
  end
  lay = NxSirka50::CB.leg_layout(NxSirka50.cfg('width' => 150.0), 2)
  NxTest.assert_close(60.0, lay[:positions][0][1], 0.001, 'predná pozícia = odsadenie 60 mm')
  d = NxSirka50::CN.back_stop(NxSirka50.cfg('width' => 150.0))
  NxTest.assert_close(d - 60.0, lay[:positions][1][1], 0.001, 'zadná pozícia = hĺbka dna − 60 mm')
end

NxTest.test('Šírka 50 (B6): plytká skrinka — 2 nohy sa neprekryjú (audit FIX 2), počet v nákupe ostáva') do
  cfg = NxSirka50.cfg('width' => 150.0, 'depth' => 150.0)
  lay = NxSirka50::CB.leg_layout(cfg, 2)
  NxTest.assert_equal(2, lay[:positions].length, 'dva rôzne valce')
  NxTest.assert_equal(false, lay[:overlap], 'nekryjú sa')
  NxTest.assert(NxSirka50.dist(*lay[:positions]) >= NxSirka50::CB::LEG_DIAMETER,
                "stredy ďalej než priemer valca: #{lay[:positions].inspect}")
  NxTest.assert(lay[:positions].all? { |x, y| x == 75.0 && y.between?(25.0, NxSirka50::CN.back_stop(cfg) - 25.0) },
                'stred šírky a valce celé pod dnom')
  plan = NxSirka50::CN.build_plan(cfg, 'CAB-S50-SHALLOW')
  NxTest.assert_equal(2, plan[:hardware].select { |h| h['generic_type'] == 'leg' }.sum { |h| h['quantity'] },
                      'plán: 2 nohy v nákupe')
end

NxTest.test('Šírka 50 (B7): ani to sa nezmestí (predný sokel + plytká) — 1 valec, warning, nákup 2') do
  cfg = NxSirka50.cfg('width' => 150.0, 'depth' => 150.0, 'plinth_mode' => 'front', 'floor_height' => 100.0)
  lay = NxSirka50::CB.leg_layout(cfg, 2)
  NxTest.assert_equal(1, lay[:positions].length, 'kreslí sa jeden valec')
  NxTest.assert_equal(true, lay[:overlap])
  plan = NxSirka50::CN.build_plan(cfg, 'CAB-S50-PLINTH')
  qty = plan[:hardware].select { |h| h['generic_type'] == 'leg' }.sum { |h| h['quantity'] }
  NxTest.assert_equal(2, qty, 'počet v nákupe ostáva podľa pravidla')
  NxSirka50::CB.attach_leg_fit_warning!(plan, cfg)
  w = plan[:warnings].find { |x| x['code'] == 'legs_not_fit' }
  NxTest.assert(w, 'plán nesie warning legs_not_fit')
  NxTest.assert_equal('info', w['severity'])
  # Bežná skrinka warning nedostane.
  ok = NxSirka50.cfg('width' => 600.0, 'depth' => 560.0)
  plan2 = NxSirka50::CN.build_plan(ok, 'CAB-S50-OK')
  NxSirka50::CB.attach_leg_fit_warning!(plan2, ok)
  NxTest.refute(plan2[:warnings].any? { |x| x['code'] == 'legs_not_fit' }, '600 mm: bez warningu')
end

NxTest.test('Šírka 50 (B8): rozloženie 4 a 6 nôh na bežných skrinkách sa nezmenilo a nekryje sa') do
  lay4 = NxSirka50::CB.leg_layout(NxSirka50.cfg('width' => 600.0), 4)
  NxTest.assert_equal([[60.0, 60.0], [540.0, 60.0], [60.0, 497.0], [540.0, 497.0]], lay4[:positions])
  NxTest.assert_equal(false, lay4[:overlap])
  lay6 = NxSirka50::CB.leg_layout(NxSirka50.cfg('width' => 1200.0), 6)
  NxTest.assert_equal(6, lay6[:positions].length)
  NxTest.assert_equal(false, lay6[:overlap])
  NxTest.assert_equal([], NxSirka50::CB.leg_layout(NxSirka50.cfg, 0)[:positions], '0 nôh = nič')
  NxTest.assert_equal([[75.0, 278.5]], NxSirka50::CB.leg_layout(NxSirka50.cfg('width' => 150.0), 1)[:positions],
                      '1 noha: stred šírky aj hĺbky (bez zmeny)')
end
