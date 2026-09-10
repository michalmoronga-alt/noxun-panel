# frozen_string_literal: true
# KOV-G1b (10.9.2026) — NOHY 4/6 PODLA SIRKY + PRAVIDLO PRICHYTU SOKLA.
#
# G1a priniesla DATA (set „Nohy podľa výšky sokla", set „Príchyt sokla AXILO",
# typ `plinth_clip`); TATO davka prinasa PRAVIDLA, ktore ich naplnia:
#   * `nohy-zakladne` uz nie je `fixed 4`, ale `bands` podla SIRKY korpusu
#     (< 1000 mm -> 4 nohy, od 1000 mm -> 6),
#   * nove seed pravidlo `prichyt-sokla` — 1 ks na ZACATE 4 nohy, LEN pri
#     samostatnej soklovej liste (`support legs`) a LEN od vysky sokla 55 mm
#     (nizsie ziadna lista na nohach AXILO neexistuje).
#
# CO SA OVERUJE:
#   1) POCET NOH podla sirky — 600 / 999 / 1000 / 1200 -> 4 / 4 / 6 / 6
#      a PRICHYT na tej istej hranici -> 1 / 1 / 2 / 2 (sokel 100 mm)
#   2) PRAH VYSKY SOKLA (`applies_to.floor_height_min`) — 17 a 54,9 mm nedaju
#      ziadny prichyt, 55 mm uz ano; nohy prah NEOVPLYVNUJE
#   3) PODOPRETIE — `plinth` (sokel vpredu je sucast korpusu) dostane nohy,
#      ale NIKDY prichyt; `none` (horna skrinka / skrinka na zemi) nic
#   4) EXPANZIA cez sety G1a — sirka 1200 + sokel 100 -> 6x 9078 + 6x 9079 +
#      2x 950; sokel 17 -> len klzaky, ZIADNA platnicka a ZIADNY prichyt
#   5) SEED — `SEED_VERSION` 6; `merge_seed` obnovi NEDOTKNUTY stary tvar noh
#      a doplni prichyt, pouzivatelom upravene pravidlo necha tak;
#      `project_seed_plan` to iste pre snapshot projektu; VLASTNE zapnute
#      pravidlo na `plinth_clip` doplnenie seedu ZASTAVI (`OVERLAP_OUTPUTS`)
#   6) NORMALIZACIA — prah je Float; nepouzitelna hodnota ('abc', -1, 0) sa
#      aj s klucom ZAHODI (pravidlo plati bez prahu); kluc prezije round-trip
#      formular -> ulozenie (`normalize_rules`) aj zapisovu branu
#   7) KONTROLA — prichyt bez setu je ORANGE „Príchyt sokla … nemá priradený
#      set"; `leg_stale` je ORANGE (NIE RED, ziadna exportna brana) a po
#      prestavbe s novym seedom zhasne
#
# MUTACIE (kazda overena spustenim — po zaneseni chyby spadnu uvedene testy):
#   M1 filter prahu sa v `apply_rule` vynecha (prah 55 sa ignoruje)
#      -> „(2): prah výšky sokla…" + „(2): pravidlo BEZ prahu…" + „(4): sokel
#         17 mm…" + „(4): zóna 20-55 mm…" + „(6): kľúč prežije round-trip…"
#   M2 hranica pasma je 1000,0 namiesto 999,0 („<= 1000" miesto „< 1000")
#      -> „(1): počet nôh podľa šírky korpusu…" + „(5): `SEED_VERSION` je 6…"
#   M3 `prichyt-sokla` dostane filter `support legs plinth`
#      -> „(3): sokel VPREDU…" + „(3): reálna stavba…" + „(5): `SEED_VERSION`…"
#   M4 `LEGACY_SEED_SHAPES` nedostane stary tvar noh (`fixed 4`)
#      -> „(5): knižnica v5…" + „(5): používateľom UPRAVENÉ…" + „(5): Doplniť…"
#   M5 `OVERLAP_OUTPUTS` neobsahuje `plinth_clip`
#      -> „(5): vlastné pravidlo na príchyt…" + „(5): dve zapnuté pravidlá…"
#   M6 `leg_stale` sa dostane do `BuildPlan::HW_ISSUE_BLOCKERS` (RED + brana)
#      -> „(7): `leg_stale` je ORANGE a NEZASTAVUJE výrobu ani nákup"
require_relative '../helper' unless defined?(NxTest)

require 'json'

# UI vrstva (brana exportov) — headless nie je v require zozname helpera.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxKovG1b
  E   = Noxun::Engine
  HR  = E::HardwareRules
  HWS = E::HardwareSets
  CN  = E::Construction
  CB  = E::CabinetBuilder
  BP  = E::BuildPlan
  BOM = E::Bom
  V   = E::Validation
  PC  = E::ProductionCore

  LEG_RULE  = HR::LEG_RULE_ID
  CLIP_RULE = HR::PLINTH_CLIP_RULE_ID
  CLIP_TYPE = HR::PLINTH_CLIP_OUTPUT
  CLIP_SET  = 'prichyt-sokla-axilo'

  module_function

  def rules
    HR.normalize_rules(HR::SEED_RULES)
  end

  def rule_of(rid, list = rules)
    list.find { |r| r['rule_id'] == rid }
  end

  # Kontext SPODNEJ skrinky tak, ako ho sklada `Construction.build_plan`.
  def ctx(over = {})
    { 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'floor_height' => 100.0,
      'available_width' => 564.0, 'available_height' => 584.0, 'available_depth' => 490.0,
      'kh' => 620.0, 'kb' => 600.0, 'front_rows' => 0,
      'support' => 'legs', 'cabinet_type' => 'lower' }.merge(over)
  end

  def evaluate(over_ctx = {}, rules_over = nil)
    HR.evaluate({}, [], ctx(over_ctx), rules: rules_over || rules)
  end

  # Pocet kusov daneho druhu kovania (nil = polozka vobec nevznikla).
  def qty(res, type)
    it = res[:items].find { |i| i['generic_type'] == type }
    it && it['quantity']
  end

  def legs(res)
    qty(res, 'leg')
  end

  def clips(res)
    qty(res, CLIP_TYPE)
  end

  # --- sety a expanzia (vzor `test_kovg1a_nohy_data.rb`) --------------------

  def state(sets = HWS.normalize_sets(HWS::SEED_SETS), mapping = nil)
    defs = {}
    sets.each { |s| defs[s['set_id']] = s }
    { 'mapping' => mapping || HWS::SEED_MAPPING.merge(HWS::MAPPING_ADDITIONS), 'sets' => defs }
  end

  # Nakupne riadky { kod => pocet } pre skrinku danej sirky a vysky sokla.
  def buy(width, floor_height, st = state)
    res = evaluate('width' => width, 'kb' => width, 'floor_height' => floor_height)
    items = res[:items].map { |i| i.merge('owner_id' => 'CAB-1') }
    exp = HWS.expand(items, st)
    [exp['rows'].each_with_object({}) { |r, out| out[r['code'].to_s] = r['quantity'] }, exp]
  end

  # --- ULOZENY config skrinky (zber cita LEN toto) --------------------------

  def leg_item(quantity, over = {})
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'quantity' => quantity,
      'rule_id' => LEG_RULE, 'source' => 'rule', 'params' => { 'height' => 100.0 } }.merge(over)
  end

  def clip_item(quantity = 1)
    { 'owner_part_key' => nil, 'generic_type' => CLIP_TYPE, 'quantity' => quantity,
      'rule_id' => CLIP_RULE, 'source' => 'rule', 'params' => {} }
  end

  def stale_cfg(over = {})
    { 'config_schema' => CB::CONFIG_SCHEMA,
      'rules_seed_version' => HR::LEG_WIDTH_SEED_VERSION - 1,
      'width' => 1200.0, 'floor_height' => 100.0,
      'support' => { 'type' => 'legs', 'height' => 100.0 },
      'hardware' => [leg_item(4)], 'front_items' => [] }.merge(over)
  end

  def stale_issue(over = {})
    BOM.leg_stale_issue('S1', 42, stale_cfg(over))
  end

  # Zber v tvare, aky `Validation.run` dostava z `Bom.collect`.
  def run_items(issues, expansion = nil)
    V.run({ records: [], hardware_overrides: [], warnings: [], cabinets: 1,
            hardware_issues: issues }, hardware_expansion: expansion)['items']
  end
end

# ============================================================================
# 1 — POCET NOH A PRICHYTOV PODLA SIRKY
# ============================================================================

NxTest.test('KOV-G1b (1): počet nôh podľa šírky korpusu — < 1000 mm 4, od 1000 mm 6') do
  c = NxKovG1b
  { 600.0 => 4, 999.0 => 4, 1000.0 => 6, 1200.0 => 6, 2400.0 => 6 }
    .each do |w, want|
    NxTest.assert_equal(want, c.legs(c.evaluate('width' => w)), "šírka #{w} -> #{want} nôh")
  end
  # VEDOMY DOSLEDOK konvencie „max 999,0" (rovnakej ako 849,0 pri zavesoch):
  # NECELOCISELNA sirka v medzere 999-1000 spadne uz do horneho pasma. Sirky
  # korpusov su v praxi cele milimetre; radsej o nohu VIAC nez o menej.
  NxTest.assert_equal(6, c.legs(c.evaluate('width' => 999.5)),
                      'šírka 999,5 mm padne do horného pásma (konvencia „max 999")')
end

NxTest.test('KOV-G1b (1): príchyt sokla — 1 ks na začaté 4 nohy (tá istá hranica)') do
  c = NxKovG1b
  { 600.0 => 1, 999.0 => 1, 1000.0 => 2, 1200.0 => 2 }.each do |w, want|
    NxTest.assert_equal(want, c.clips(c.evaluate('width' => w)), "šírka #{w} -> #{want} príchytov")
  end
end

NxTest.test('KOV-G1b (1): nohy si NECHÁVAJÚ výšku sokla v params (set podľa nej vyberá kód)') do
  c = NxKovG1b
  it = c.evaluate('width' => 1200.0, 'floor_height' => 150.0)[:items]
        .find { |i| i['generic_type'] == 'leg' }
  NxTest.assert_equal({ 'height' => 150.0 }, it['params'],
                      'params_from_context ostáva — šírka rieši POČET, výška KÓD')
  NxTest.assert_equal(6, it['rule_quantity'], 'rule_quantity je počet z pravidla')
  NxTest.assert_equal('rule', it['source'])
end

# ============================================================================
# 2 — PRAH VYSKY SOKLA (`applies_to.floor_height_min`)
# ============================================================================

NxTest.test('KOV-G1b (2): prah výšky sokla — príchyt vzniká až od 55 mm') do
  c = NxKovG1b
  { 17.0 => nil, 20.0 => nil, 40.0 => nil, 54.9 => nil, 55.0 => 1, 100.0 => 1 }
    .each do |fh, want|
    NxTest.assert_equal(want, c.clips(c.evaluate('floor_height' => fh)),
                        "sokel #{fh} mm -> #{want.nil? ? 'žiadny príchyt' : "#{want} ks"}")
  end
end

NxTest.test('KOV-G1b (2): prah sa týka LEN príchytu — nohy vzniknú pri každej výške sokla') do
  c = NxKovG1b
  [17.0, 40.0, 54.9, 55.0, 220.0].each do |fh|
    NxTest.assert_equal(4, c.legs(c.evaluate('floor_height' => fh)),
                        "sokel #{fh} mm -> nohy stále 4 (zóna 20-55 je vec SETU, nie pravidla)")
  end
end

NxTest.test('KOV-G1b (2): pravidlo BEZ prahu platí ako doteraz, prah bez výšky v kontexte NIE') do
  c = NxKovG1b
  bez = c.rules.map do |r|
    next r unless r['rule_id'] == c::CLIP_RULE

    r.merge('applies_to' => r['applies_to'].reject { |k, _| k == c::HR::FLOOR_HEIGHT_MIN })
  end
  NxTest.assert_equal(1, c.clips(c.evaluate({ 'floor_height' => 17.0 }, bez)),
                      'bez kľúča sa nič nemení — pravidlo platí na každú výšku')
  # Kontext BEZ pouzitelnej vysky (cudzi volajuci, poskodeny plan) prah NESPLNI:
  # hadat by znamenalo objednat prichyt ku klzaku.
  NxTest.assert_equal(nil, c.clips(c.evaluate('floor_height' => nil)),
                      'chýbajúca výška sokla = pravidlo s prahom sa NEUPLATNÍ')
end

# ============================================================================
# 3 — PODOPRETIE KORPUSU
# ============================================================================

NxTest.test('KOV-G1b (3): sokel VPREDU dostane nohy, ale NIKDY príchyt') do
  c = NxKovG1b
  res = c.evaluate('support' => 'plinth', 'width' => 1200.0)
  NxTest.assert_equal(6, c.legs(res), 'nohy sú pod skrinkou aj pri sokli vpredu')
  NxTest.assert_equal(nil, c.clips(res),
                      'sokel vpredu je súčasť korpusu — samostatná lišta neexistuje')
end

NxTest.test('KOV-G1b (3): horná skrinka / skrinka na zemi (`none`) nedostane ani jedno') do
  c = NxKovG1b
  res = c.evaluate('support' => 'none', 'cabinet_type' => 'upper', 'floor_height' => 0.0)
  NxTest.assert_equal(nil, c.legs(res), 'bez podstavca žiadne nohy')
  NxTest.assert_equal(nil, c.clips(res), 'a žiadny príchyt')
end

NxTest.test('KOV-G1b (3): reálna stavba — `Construction.build_plan` dá to isté') do
  NxTest.skip!('build_plan v SketchUpe číta knižnicu pravidiel') unless NxTest.headless?
  c = NxKovG1b
  cfg = c::CB.normalize('type' => 'lower', 'width' => 1200.0, 'height' => 720.0,
                        'depth' => 510.0, 'floor_height' => 100.0)
  pl = c::CN.build_plan(cfg, 'CAB-1', hardware_rules: c.rules)
  by = pl[:hardware].each_with_object({}) { |h, out| out[h['generic_type']] = h['quantity'] }
  NxTest.assert_equal({ 'leg' => 6, c::CLIP_TYPE => 2 }, by,
                      'skrinka 1200 na nohách so soklom 100 -> 6 nôh + 2 príchyty')
  # Sokel VPREDU: `Construction.support_type` da 'plinth' -> prichyt nevznikne.
  cfg2 = c::CB.normalize('type' => 'lower', 'width' => 1200.0, 'height' => 720.0,
                         'depth' => 510.0, 'floor_height' => 100.0, 'plinth_mode' => 'front')
  pl2 = c::CN.build_plan(cfg2, 'CAB-1', hardware_rules: c.rules)
  NxTest.assert_equal(['leg'], pl2[:hardware].map { |h| h['generic_type'] },
                      'sokel vpredu = len nohy')
end

# ============================================================================
# 4 — EXPANZIA CEZ SETY G1a (co sa naozaj objedna)
# ============================================================================

NxTest.test('KOV-G1b (4): šírka 1200 + sokel 100 -> 6x noha + 6x platnička + 2x príchyt') do
  c = NxKovG1b
  rows, exp = c.buy(1200.0, 100.0)
  NxTest.assert_equal({ '9078' => 6, '9079' => 6, '950' => 2 }, rows,
                      'AXILO noha 91-115 mm, platnička na každú nohu, príchyt 2x')
  NxTest.assert_equal([], exp['unmapped'], 'všetko má set aj kód')
end

NxTest.test('KOV-G1b (4): sokel 17 mm -> klzáky BEZ platničky a BEZ príchytu') do
  c = NxKovG1b
  rows600, = c.buy(600.0, 17.0)
  NxTest.assert_equal({ '272212' => 4 }, rows600, 'úzka skrinka: 4 klzáky, nič iné')
  rows1200, exp = c.buy(1200.0, 17.0)
  NxTest.assert_equal({ '272212' => 6 }, rows1200,
                      'široká skrinka má 6 klzákov — príchyt ani tak nevzniká (žiadna lišta)')
  NxTest.assert_equal([], exp['unmapped'])
end

NxTest.test('KOV-G1b (4): zóna 20-55 mm ostáva nepokrytá SETOM (ORANGE), nie pravidlom') do
  c = NxKovG1b
  rows, exp = c.buy(1200.0, 40.0)
  NxTest.assert_equal({}, rows, 'pre sokel 40 mm neexistuje kód nohy')
  NxTest.assert_equal(%w[leg], exp['unmapped'].map { |u| u['generic_type'] }.uniq,
                      'nemapované sú LEN nohy — príchyt tam vôbec nevznikol')
end

# ============================================================================
# 5 — SEED, MIGRACIA KNIZNICE A SNAPSHOTU
# ============================================================================

NxTest.test('KOV-G1b (5): `SEED_VERSION` je 6 a seed nesie obe pravidlá v novom tvare') do
  c = NxKovG1b
  NxTest.assert_equal(6, c::HR::SEED_VERSION, 'bez bumpu by `merge_seed` migráciu preskočil')
  leg = c.rule_of(c::LEG_RULE)
  NxTest.assert_equal('bands', leg['kind'])
  NxTest.assert_equal('width', leg['input'])
  NxTest.assert_equal([[999.0, 4], [nil, 6]], leg['bands'].map { |b| [b['max'], b['quantity']] },
                      'konvencia „< 1000" = max 999,0 (ako 849,0 pri závesoch)')
  NxTest.assert_equal(%w[legs plinth], leg['applies_to']['support'], 'filter podopretia ostáva')
  clip = c.rule_of(c::CLIP_RULE)
  NxTest.assert_equal(c::CLIP_TYPE, clip['output'])
  NxTest.assert_equal(%w[legs], clip['applies_to']['support'])
  NxTest.assert_equal(55.0, clip['applies_to'][c::HR::FLOOR_HEIGHT_MIN])
  NxTest.assert_equal([[999.0, 1], [nil, 2]], clip['bands'].map { |b| [b['max'], b['quantity']] })
  NxTest.assert_equal([], c::HR.rules_problems(c.rules), 'obe pravidlá sa dajú uložiť')
end

NxTest.test('KOV-G1b (5): knižnica v5 dostane NOVÝ tvar nôh, upravené pravidlo ostáva') do
  c = NxKovG1b
  legacy = c::HR::LEGACY_SEED_SHAPES[c::LEG_RULE][0]
  NxTest.assert_equal('fixed', legacy['kind'], 'starý tvar je pevné 4 (v1..v5)')
  old = c::HR.normalize_rules([legacy] + c::HR::SEED_RULES.reject do |r|
    [c::LEG_RULE, c::CLIP_RULE].include?(r['rule_id'])
  end)
  merged, changed = c::HR.merge_seed(old, 5)
  NxTest.assert(changed, 'migrácia z v5 prebehne')
  leg = c.rule_of(c::LEG_RULE, merged)
  NxTest.assert_equal('bands', leg['kind'], 'NEDOTKNUTÝ starý tvar sa obnoví na nový')
  NxTest.assert(merged.any? { |r| r['rule_id'] == c::CLIP_RULE }, 'a príchyt sa doplní')
  NxTest.assert_equal([merged, false], c::HR.merge_seed(merged, 6), 'z v6 sa už nič nemení')
end

NxTest.test('KOV-G1b (5): používateľom UPRAVENÉ pravidlo nôh sa NEPREPÍŠE') do
  c = NxKovG1b
  mine = c::HR.normalize_rules([c::HR::LEGACY_SEED_SHAPES[c::LEG_RULE][0]
                                  .merge('quantity' => 5)])
  merged, = c::HR.merge_seed(mine, 5)
  leg = c.rule_of(c::LEG_RULE, merged)
  NxTest.assert_equal('fixed', leg['kind'], 'ruky preč od cudzej úpravy')
  NxTest.assert_equal(5, leg['quantity'], '5 nôh ostáva 5 nôh')
end

NxTest.test('KOV-G1b (5): „Doplniť nové predvoľby" osvieži snapshot projektu') do
  c = NxKovG1b
  existing = c::HR.normalize_rules([c::HR::LEGACY_SEED_SHAPES[c::LEG_RULE][0]])
  out, added, refreshed = c::HR.project_seed_plan(existing)
  NxTest.assert_equal([c::LEG_RULE], refreshed, 'starý tvar nôh sa obnoví')
  NxTest.assert(added.include?(c::CLIP_RULE), "príchyt sa doplní (#{added.inspect})")
  NxTest.assert_equal('bands', c.rule_of(c::LEG_RULE, out)['kind'])
  # Druhy beh uz nema co robit.
  _, added2, refreshed2 = c::HR.project_seed_plan(out)
  NxTest.assert_equal([[], []], [added2, refreshed2], 'druhý raz sa nič nemení')
end

NxTest.test('KOV-G1b (5): vlastné pravidlo na príchyt seed doplniť NEDÁ') do
  c = NxKovG1b
  NxTest.assert(c::HR::OVERLAP_OUTPUTS.include?(c::CLIP_TYPE),
                'príchyt je v registri prekryvu — inak by nákup rátal dvakrát')
  mine = { 'rule_id' => 'moj-prichyt', 'enabled' => true, 'output' => c::CLIP_TYPE,
           'kind' => 'fixed', 'quantity' => 3, 'applies_to' => { 'role' => 'cabinet' } }
  existing = c::HR.normalize_rules(
    c::HR::SEED_RULES.reject { |r| r['rule_id'] == c::CLIP_RULE } + [mine]
  )
  out, added, = c::HR.project_seed_plan(existing)
  NxTest.assert_equal([], added, 'seed príchytu sa NEDOPLNÍ k vlastnému pravidlu')
  NxTest.assert_equal(3, c.rule_of('moj-prichyt', out)['quantity'])
  # VYPNUTE vlastne pravidlo prekryv NEROBI (rovnako ako pri zavesoch a vyklopoch).
  vypnute = c::HR.normalize_rules(
    c::HR::SEED_RULES.reject { |r| r['rule_id'] == c::CLIP_RULE } +
    [mine.merge('enabled' => false)]
  )
  _, added2, = c::HR.project_seed_plan(vypnute)
  NxTest.assert_equal([c::CLIP_RULE], added2, 'vypnuté vlastné pravidlo doplneniu nebráni')
end

NxTest.test('KOV-G1b (5): dve zapnuté pravidlá príchytu = JEDNA položka + ORANGE') do
  c = NxKovG1b
  mine = { 'rule_id' => 'moj-prichyt', 'enabled' => true, 'output' => c::CLIP_TYPE,
           'kind' => 'fixed', 'quantity' => 3,
           'applies_to' => { 'role' => 'cabinet', 'support' => %w[legs] } }
  res = c.evaluate({}, c.rules + c::HR.normalize_rules([mine]))
  clips = res[:items].select { |i| i['generic_type'] == c::CLIP_TYPE }
  NxTest.assert_equal(1, clips.length, 'použije sa PRVÉ pravidlo, druhé sa prizná')
  w = res[:warnings].find { |x| x['code'] == 'hardware_rule_overlap' }
  NxTest.assert(w, 'prekryv je ORANGE, nikdy ticho')
  NxTest.assert(w['message'].include?('príchytov sokla'),
                "veta menuje SPRÁVNY druh kovania: #{w['message']}")
end

# ============================================================================
# 6 — NORMALIZACIA PRAHU A ROUND-TRIP ULOZENIA
# ============================================================================

NxTest.test('KOV-G1b (6): prah sa normalizuje na Float, nepoužiteľná hodnota sa zahodí') do
  c = NxKovG1b
  key = c::HR::FLOOR_HEIGHT_MIN
  base = { 'rule_id' => 'x', 'enabled' => true, 'output' => c::CLIP_TYPE, 'kind' => 'fixed',
           'quantity' => 1 }
  norm = lambda do |value|
    c::HR.normalize_rules([base.merge('applies_to' => { 'role' => 'cabinet', key => value })])
         .first['applies_to']
  end
  NxTest.assert_equal(55.0, norm.call(55)[key], 'Integer -> Float (mm)')
  NxTest.assert_equal(55.5, norm.call(55.5)[key], 'Float ostáva')
  ['abc', -1, 0, nil, { 'a' => 1 }, [55]].each do |bad|
    NxTest.assert(!norm.call(bad).key?(key),
                  "nepoužiteľný prah (#{bad.inspect}) sa zahodí aj s kľúčom")
  end
end

NxTest.test('KOV-G1b (6): kľúč prežije round-trip formulár -> uloženie -> evaluácia') do
  c = NxKovG1b
  # Klient posiela CELE pravidlo (`JSON.parse(JSON.stringify(src))`), server ho
  # normalizuje a validuje — TOTO je cela zapisova cesta `handle_save`.
  klient = JSON.parse(JSON.generate(c.rule_of(c::CLIP_RULE)))
  ulozene = c::HR.normalize_rules([klient]).first
  NxTest.assert_equal(55.0, ulozene['applies_to'][c::HR::FLOOR_HEIGHT_MIN],
                      'prah prežije JSON aj normalizáciu (editor ho needituje)')
  NxTest.assert_equal([], c::HR.rules_problems([ulozene]), 'zápisová brána ho nezhodí')
  NxTest.assert_equal([], c::HR.lift_input_problems([ulozene]), 'ani brána nad surovým vstupom')
  # A po ulozeni sa spravanie NEZMENI.
  rules = c.rules.map { |r| r['rule_id'] == c::CLIP_RULE ? ulozene : r }
  NxTest.assert_equal(nil, c.clips(c.evaluate({ 'floor_height' => 17.0 }, rules)))
  NxTest.assert_equal(1, c.clips(c.evaluate({ 'floor_height' => 55.0 }, rules)))
end

# ============================================================================
# 7 — KONTROLA (ORANGE) A NAKUP
# ============================================================================

NxTest.test('KOV-G1b (7): príchyt bez setu je ORANGE „Príchyt sokla … nemá priradený set"') do
  c = NxKovG1b
  # Pouzivatel si set prichytu zmazal (alebo mapovanie zrusil).
  bez = c.state(c::HWS.normalize_sets(c::HWS::SEED_SETS)
                     .reject { |s| s['set_id'] == c::CLIP_SET },
                c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS)
                                    .reject { |k, _| k == c::CLIP_TYPE })
  _, exp = c.buy(600.0, 100.0, bez)
  un = exp['unmapped'].select { |u| u['generic_type'] == c::CLIP_TYPE }
  NxTest.assert_equal(1, un.length, 'príchyt bez setu je nemapovaný záznam')
  item = c.run_items([], exp).find { |i| i['message_sk'].include?('Príchyt sokla') }
  NxTest.assert(item, 'Kontrola o ňom hovorí')
  NxTest.assert_equal('orange', item['severity'], 'a je to ORANGE (nákup sa nezastavuje)')
  NxTest.assert(item['message_sk'].include?('nemá priradený set'),
                "veta sa zloží správne: #{item['message_sk']}")
end

NxTest.test('KOV-G1b (7): `leg_stale` — stará skrinka na nohách dostane ORANGE') do
  c = NxKovG1b
  iss = c.stale_issue
  NxTest.assert(iss, 'skrinka 1200 so 4 nohami z pravidla a seedom 5')
  NxTest.assert_equal(c::BP::LEG_STALE, iss['code'])
  NxTest.assert_equal('orange', iss['severity'])
  NxTest.assert_equal('S1', iss['owner_id'])
  NxTest.assert(iss['message'].include?('6 nôh + 2 príchyty'),
                "veta menuje, čo z toho bude: #{iss['message']}")
  NxTest.assert(iss['message'].include?('Doplniť nové predvoľby'), 'a nápravu')
  NxTest.assert_equal(JSON.parse(JSON.generate(iss)), iss, 'záznam je čistý JSON tvar')
end

NxTest.test('KOV-G1b (7): `leg_stale` mlčí, keď sa nič nezmení alebo je skrinka prestavaná') do
  c = NxKovG1b
  NxTest.assert_equal(nil, c.stale_issue('rules_seed_version' => c::HR::LEG_WIDTH_SEED_VERSION),
                      'prestavaná skrinka (seed 6) nález nerobí')
  NxTest.assert_equal(nil,
                      c.stale_issue('hardware' => [c.leg_item(6), c.clip_item(2)]),
                      'skrinka s novými počtami tiež nie')
  NxTest.assert_equal(nil,
                      c.stale_issue('support' => { 'type' => 'plinth', 'height' => 100.0 },
                                    'hardware' => [c.leg_item(6)]),
                      'sokel vpredu príchyt nepotrebuje')
  NxTest.assert_equal(nil,
                      c.stale_issue('width' => 600.0, 'floor_height' => 17.0,
                                    'hardware' => [c.leg_item(4)]),
                      'úzka skrinka s klzákom dostane presne to isté aj po prestavbe')
  NxTest.assert_equal(nil,
                      c.stale_issue('hardware' => [c.leg_item(4, 'source' => 'manual'),
                                                   c.clip_item(2)]),
                      'RUČNE zamknuté 4 nohy sú vedomé rozhodnutie — nekomentujú sa')
  NxTest.assert(c.stale_issue('width' => 600.0, 'hardware' => [c.leg_item(4)]),
                'úzka skrinka so soklom 100 mm ale príchyt CHÝBA -> nález')
end

NxTest.test('KOV-G1b (7): `leg_stale` je ORANGE a NEZASTAVUJE výrobu ani nákup') do
  c = NxKovG1b
  NxTest.assert(!c::BP::HW_ISSUE_BLOCKERS.include?(c::BP::LEG_STALE),
                'kód NIE JE v registri blokerov')
  NxTest.assert(!c::BP.hw_blockers.include?(c::BP::LEG_STALE), 'ani v bráne exportov')
  iss = c.stale_issue
  collected = { records: [], hardware_overrides: [], warnings: [], cabinets: 1,
                hardware_issues: [iss] }
  %i[all kit].each do |scope|
    NxTest.assert_equal([], c::PC.hardware_blockers(collected, nil, scope: scope),
                        "nákup ani VEPO (#{scope}) sa nezastavia")
  end
  item = c.run_items([iss]).find { |i| i['message_sk'].include?('pred pravidlom 4/6') }
  NxTest.assert(item, 'Kontrola nález ukáže')
  NxTest.assert_equal('orange', item['severity'])
  NxTest.assert_equal('S1', item['owner_id'], 'so skrinkou, ktorej sa týka (klik-select)')
  NxTest.assert(item['message_sk'].include?('nezastavujú'), 'a povie, že export beží ďalej')
end
