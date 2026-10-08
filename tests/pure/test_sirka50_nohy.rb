# frozen_string_literal: true
# SIRKA 50 (Michal 7.-8.10.2026) — UZKA DOLNA SKRINKA MA 2 NOHY.
#
# Najmensia sirka skrinky klesla z 200 na 50 mm (`CONFIG_SCHEMA` 23, parita
# a regresie schemy su v `test_s1e0_min_vyska.rb`). Audit BLOCKER 1: sirka
# nesmie ist von bez pravidla noh — pri 50 mm by sa 4 nohy nakreslili do
# dvoch rovnakych poloh a nakup by objednal 4. Rozhodnutie Michala: skrinka
# uzsia nez 200 mm ma 2 nohy v STREDE SIRKY (vpredu + vzadu), v nakupe 2 ks.
#
# CO SA OVERUJE:
#   1) PASMA seed pravidla `nohy-zakladne` — 199 / 199,5 / 199,99 -> 2,
#      200 -> 4 (audit FIX 4: konvencia `v <= max` nesmie 199,5 pustit do 4),
#      a prichyt sokla ostava 1 ks (zacate 4 nohy),
#   2) MIGRACIA SEEDU v7 -> v8 — nedotknuty tvar 4/6 sa obnovi (kniznica aj
#      „Doplniť nové predvoľby"), upraveny sa NIKDY neprepise,
#   3) `leg_stale` v8 — uzka skrinka so snapshotom < v8 a 4 nohami z pravidla
#      = ORANGE „prestav"; hranice v6 sa nepohli (audit FIX 3),
#   4) POLOHY NOH (`Construction.leg_layout`) — uzka skrinka: x v strede, dve
#      rozne y, plytka bez prekrytia, za doskou sokla a na nosnom dne; ked sa
#      nezmestia, menej (aj 0) valcov + info warning planu (audit FIX 2, Codex
#      P2-1/P2-2), ktory Kontrola neukazuje ako nalez. Skrinka od 200 mm
#      kresli presne povodne polohy (Codex P2-3).
#
# MUTACNE OVERENIE (rucne pred commitom): kazda z mutacii nizsie zhodi
# aspon jeden test tejto sady:
#   M1 pasmo uzkej skrinky `max 199.0` namiesto 199,999 -> „(1) 199,5"
#   M2 `LEGACY_SEED_SHAPES` bez tvaru v6/v7 -> „(2) kniznica v7"
#   M3 `narrow4` bez kontroly sirky -> „(3) sirka 200 so starym snapshotom"
#   M4 `narrow_leg_ys` bez vetvy plytkej skrinky -> „(4) plytka skrinka"
#   M5 `legs_drawn_merged` mimo `BUILD_INFO_ONLY` -> „(4) Kontrola"
require_relative '../helper' unless defined?(NxTest)
require 'json'

module NxSirka50
  E   = Noxun::Engine
  HR  = E::HardwareRules
  CN  = E::Construction
  CB  = E::CabinetBuilder
  BP  = E::BuildPlan
  BOM = E::Bom
  V   = E::Validation

  LEG_RULE = HR::LEG_RULE_ID

  module_function

  def rules
    HR.normalize_rules(HR::SEED_RULES)
  end

  def rule_of(rid, list)
    list.find { |r| r['rule_id'] == rid }
  end

  def ctx(over = {})
    { 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'floor_height' => 100.0,
      'available_width' => 564.0, 'available_height' => 584.0, 'available_depth' => 490.0,
      'kh' => 620.0, 'kb' => 600.0, 'front_rows' => 0,
      'support' => 'legs', 'cabinet_type' => 'lower' }.merge(over)
  end

  def qty(res, type)
    it = res[:items].find { |i| i['generic_type'] == type }
    it && it['quantity']
  end

  def legs_at(width, rules_list = rules)
    qty(HR.evaluate({}, [], ctx('width' => width), rules: rules_list), 'leg')
  end

  # Tvar v6/v7 (4/6 podla sirky) — presne to, co mali kniznice pred v8.
  def v7_leg_rule
    HR::LEGACY_SEED_SHAPES[LEG_RULE].find { |r| r['kind'] == 'bands' }
  end

  def leg_item(quantity, over = {})
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'quantity' => quantity,
      'rule_id' => LEG_RULE, 'source' => 'rule', 'params' => { 'height' => 100.0 } }.merge(over)
  end

  def clip_item(quantity = 1)
    { 'owner_part_key' => nil, 'generic_type' => HR::PLINTH_CLIP_OUTPUT, 'quantity' => quantity,
      'rule_id' => HR::PLINTH_CLIP_RULE_ID, 'source' => 'rule', 'params' => {} }
  end

  # Ulozeny config uzkej skrinky postavenej so snapshotom v7 (4 nohy + prichyt).
  def narrow_cfg(over = {})
    { 'config_schema' => CB::CONFIG_SCHEMA, 'rules_seed_version' => 7,
      'width' => 150.0, 'floor_height' => 100.0,
      'support' => { 'type' => 'legs', 'height' => 100.0 },
      'hardware' => [leg_item(4), clip_item(1)], 'front_items' => [] }.merge(over)
  end

  def stale(over = {})
    BOM.leg_stale_issue('S1', 42, narrow_cfg(over))
  end

  # To iste, ale s odpovedou modelu `seed_managed_leg_rule?` (Codex #466 P2).
  def stale_managed(managed)
    BOM.leg_stale_issue('S1', 42, narrow_cfg, leg_rule_managed: managed)
  end

  def lower(over = {})
    CB.normalize({ 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 560.0,
                   'thickness' => 18.0, 'floor_height' => 100.0 }.merge(over))
  end

  def layout(over, qty)
    CN.leg_layout(lower(over), qty)[:positions]
  end

  # Najmensia vzdialenost stredov dvoch valcov (nekonecno pri 0-1 valci).
  def min_gap(pos)
    pos.combination(2).map { |(ax, ay), (bx, by)| Math.hypot(ax - bx, ay - by) }.min || Float::INFINITY
  end

  def plan(over)
    CN.build_plan(lower(over), 'CAB-W50', hardware_rules: rules)
  end
end

# ============================================================================
# 1 — PASMA
# ============================================================================

NxTest.test('SIRKA 50 (1): uzka skrinka < 200 mm ma 2 nohy, od 200 4, od 1000 6') do
  c = NxSirka50
  { 50.0 => 2, 150.0 => 2, 199.0 => 2, 200.0 => 4, 600.0 => 4, 999.0 => 4, 1000.0 => 6 }.each do |w, want|
    NxTest.assert_equal(want, c.legs_at(w), "šírka #{w} -> #{want} nohy")
  end
end

NxTest.test('SIRKA 50 (1): 199,5 a 199,99 mm su este UZKE (audit FIX 4 — konvencia `v <= max`)') do
  c = NxSirka50
  NxTest.assert_equal(2, c.legs_at(199.5), '199,5 -> 2 (max 199 by dal 4)')
  NxTest.assert_equal(2, c.legs_at(199.99), '199,99 -> 2')
  NxTest.assert_equal(4, c.legs_at(200.0), 'presne 200 uz 4')
  NxTest.assert(c::HR::LEG_NARROW_MAX_MM < c::HR::LEG_NARROW_BELOW_MM, 'horna hranica pasma je POD 200')
  NxTest.assert(c::HR::LEG_NARROW_MAX_MM >= 199.999, 'a pokryje tri desatinne miesta')
  NxTest.assert_equal([], c::HR.rules_problems(c.rules), 'seed sa da ulozit (validator pasiem)')
end

NxTest.test('SIRKA 50 (1): prichyt sokla ostava 1 ks aj pri 2 nohach (zacate 4)') do
  c = NxSirka50
  res = c::HR.evaluate({}, [], c.ctx('width' => 150.0), rules: c.rules)
  NxTest.assert_equal([2, 1], [c.qty(res, 'leg'), c.qty(res, c::HR::PLINTH_CLIP_OUTPUT)])
  # A Kontrola `plinth_clip_check` (ceil(nohy / 4) == prichyty) mlci.
  cfg = c.narrow_cfg('rules_seed_version' => c::HR::SEED_VERSION, 'hardware' => [c.leg_item(2), c.clip_item(1)])
  NxTest.assert_equal(nil, c::BOM.plinth_clip_check_issue('S1', 42, cfg), '2 nohy + 1 prichyt sedi')
end

NxTest.test('SIRKA 50 (1): realna stavba — dolna 150 so soklom 100 da 2 nohy + 1 prichyt') do
  c = NxSirka50
  hw = c.plan('width' => 150.0)[:hardware]
  legs = hw.select { |h| h['generic_type'] == 'leg' }.sum { |h| h['quantity'].to_i }
  clips = hw.select { |h| h['generic_type'] == c::HR::PLINTH_CLIP_OUTPUT }.sum { |h| h['quantity'].to_i }
  NxTest.assert_equal([2, 1], [legs, clips])
  NxTest.assert_equal(4, c.plan('width' => 200.0)[:hardware].find { |h| h['generic_type'] == 'leg' }['quantity'])
end

# ============================================================================
# 2 — SEED v8 A MIGRACIA
# ============================================================================

NxTest.test('SIRKA 50 (2): SEED_VERSION 8 a vlastna proveniencna konstanta') do
  c = NxSirka50
  NxTest.assert_equal(8, c::HR::SEED_VERSION)
  NxTest.assert_equal(8, c::HR::LEG_NARROW_SEED_VERSION)
  NxTest.assert_equal(6, c::HR::LEG_WIDTH_SEED_VERSION, 'proveniencia v6 sa NEPOHLA (audit FIX 3)')
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_rules.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?('# v8 (SIRKA 50'), 'historia seedu ma dovod v8')
end

NxTest.test('SIRKA 50 (2): kniznica v7 — NEDOTKNUTY tvar 4/6 dostane pasmo uzkej skrinky') do
  c = NxSirka50
  old = c::HR.normalize_rules([c.v7_leg_rule] + c::HR::SEED_RULES.reject { |r| r['rule_id'] == c::LEG_RULE })
  NxTest.assert_equal(4, c.legs_at(150.0, old), 'pred migraciou ma uzka skrinka 4 nohy')
  merged, changed = c::HR.merge_seed(old, 7)
  NxTest.assert(changed, 'migracia z v7 prebehne')
  NxTest.assert_equal(2, c.legs_at(150.0, merged), 'po migracii 2')
  NxTest.assert_equal(c.rule_of(c::LEG_RULE, c.rules), c.rule_of(c::LEG_RULE, merged), 'presne seed v8')
  NxTest.assert_equal([merged, false], c::HR.merge_seed(merged, 8), 'z v8 sa nic nemeni')
end

NxTest.test('SIRKA 50 (2): pouzivatelom UPRAVENE pravidlo noh sa NEPREPISE') do
  c = NxSirka50
  mine = JSON.parse(JSON.generate(c.v7_leg_rule))
  mine['bands'][0]['max'] = 1199.0 # vlastna hranica 6 noh
  merged, = c::HR.merge_seed(c::HR.normalize_rules([mine]), 7)
  NxTest.assert_equal([1199.0, nil], c.rule_of(c::LEG_RULE, merged)['bands'].map { |b| b['max'] },
                      'vlastne pasma ostali')
  NxTest.assert_equal(4, c.legs_at(150.0, merged), 'a uzka skrinka podla nich dostane 4 (vedome)')
  five = c::HR.normalize_rules([c.v7_leg_rule.merge('enabled' => false)])
  NxTest.assert_equal(false, c.rule_of(c::LEG_RULE, c::HR.merge_seed(five, 7).first)['enabled'],
                      'vypnute pravidlo ostava vypnute')
end

NxTest.test('SIRKA 50 (2): „Doplniť nové predvoľby" obnovi snapshot projektu v7') do
  c = NxSirka50
  existing = c::HR.normalize_rules([c.v7_leg_rule])
  out, _added, refreshed = c::HR.project_seed_plan(existing)
  NxTest.assert(refreshed.include?(c::LEG_RULE), "tvar v7 sa obnovi (#{refreshed.inspect})")
  NxTest.assert_equal(2, c.legs_at(150.0, out))
  _, added2, refreshed2 = c::HR.project_seed_plan(out)
  NxTest.assert(refreshed2.empty? && !added2.include?(c::LEG_RULE), 'druhy raz nic')
end

# ============================================================================
# 3 — leg_stale v8
# ============================================================================

NxTest.test('SIRKA 50 (3): uzka skrinka so snapshotom v7 a 4 nohami = ORANGE „prestav"') do
  c = NxSirka50
  iss = c.stale
  NxTest.assert(iss, 'nalez vznikne')
  NxTest.assert_equal([c::BP::LEG_STALE, 'orange'], [iss['code'], iss['severity']])
  NxTest.assert(iss['message'].include?('šírka 150 → 2 nohy + 1 príchyt sokla'), iss['message'])
  NxTest.assert(iss['message'].include?('Doplniť nové predvoľby'), 'a naprava')
  NxTest.assert(!c::BP::HW_ISSUE_BLOCKERS.include?(iss['code']), 'nezastavuje vyrobu ani nakup')
end

NxTest.test('SIRKA 50 (3): leg_stale mlci po prestavbe, pri rucnom zamku a pri sirke 200') do
  c = NxSirka50
  NxTest.assert_equal(nil, c.stale('rules_seed_version' => 8), 'snapshot v8 = prestavana')
  NxTest.assert_equal(nil, c.stale('hardware' => [c.leg_item(2), c.clip_item(1)]), 'uz ma 2 nohy')
  NxTest.assert_equal(nil, c.stale('hardware' => [c.leg_item(4, 'source' => 'manual'), c.clip_item(1)]),
                      'rucne zamknute 4 nohy su vedome rozhodnutie')
  NxTest.assert_equal(nil, c.stale('width' => 200.0), 'sirka 200 so starym snapshotom: nic sa nezmeni')
  NxTest.assert_equal(nil, c.stale('support' => { 'type' => 'none', 'height' => 0.0 }), 'bez podstavca nic')
  plinth = c.stale('support' => { 'type' => 'plinth', 'height' => 100.0 }, 'hardware' => [c.leg_item(4)])
  NxTest.assert(plinth && !plinth['message'].include?('príchyt'), 'sokel vpredu: nohy ano, prichyt nie')
end

NxTest.test('SIRKA 50 (3): hranice v6 sa NEPOHLI (siroka a prichyt len pod v6)') do
  c = NxSirka50
  wide = c.narrow_cfg('width' => 1200.0, 'hardware' => [c.leg_item(4), c.clip_item(2)])
  NxTest.assert_equal(nil, c::BOM.leg_stale_issue('S1', 42, wide.merge('rules_seed_version' => 6)),
                      'siroka skrinka so snapshotom v6/v7 uz ma pravidlo 4/6 — v8 na nej nic nemeni')
  NxTest.assert(c::BOM.leg_stale_issue('S1', 42, wide.merge('rules_seed_version' => 5)), 'pod v6 ako doteraz')
  noclip = c.narrow_cfg('width' => 600.0, 'hardware' => [c.leg_item(4)])
  NxTest.assert_equal(nil, c::BOM.leg_stale_issue('S1', 42, noclip.merge('rules_seed_version' => 7)),
                      'chybajuci prichyt je symptom LEN pod v6')
end

module NxSirka50
  # Model so SNAPSHOTOM pravidiel — `HardwareRules.project_rules` cita len
  # modelovy atribut (duck-type, vzor `test_kovg1b_nohy_pravidla.rb`).
  class RulesModel
    def initialize(rules, seed_version = 7)
      raw = JSON.generate('std' => HR::STD, 'seed_version' => seed_version, 'rules' => rules)
      @attrs = { Noxun::Engine::Store::DICT => { HR::MODEL_KEY => raw } }
    end

    def get_attribute(dict, key, default = nil)
      (@attrs[dict] || {}).fetch(key, default)
    end
  end

  module_function

  def custom_v7_rule
    mine = JSON.parse(JSON.generate(v7_leg_rule))
    mine['bands'][0]['max'] = 1199.0 # vedome: 6 noh az od 1200, pod 200 dalej 4
    mine
  end
end

NxTest.test('SIRKA 50 (3) Codex #466 P2: seed_managed_leg_rule? — nedotknuty a aktualny ano, upraveny nie') do
  c = NxSirka50
  NxTest.assert(c::HR.seed_managed_leg_rule?(c::RulesModel.new([c.v7_leg_rule])), 'nedotknuty v7 = caka na Doplniť')
  NxTest.assert(c::HR.seed_managed_leg_rule?(c::RulesModel.new([c.rule_of(c::LEG_RULE, c.rules)], 8)),
                'aktualny seed = caka na prestavbu')
  NxTest.refute(c::HR.seed_managed_leg_rule?(c::RulesModel.new([c.custom_v7_rule])), 'vedome upravene pasma')
  NxTest.refute(c::HR.seed_managed_leg_rule?(c::RulesModel.new([c.v7_leg_rule.merge('enabled' => false)])),
                'vypnute pravidlo')
  NxTest.refute(c::HR.seed_managed_leg_rule?(c::RulesModel.new([])), 'zmazane pravidlo (ziadne nohy)')
end

NxTest.test('SIRKA 50 (3) Codex #466 P2: UPRAVENE pravidlo v7 — leg_stale mlci, Doplniť je no-op') do
  c = NxSirka50
  model = c::RulesModel.new([c.custom_v7_rule])
  _, added, refreshed = c::HR.project_seed_plan(c::HR.project_rules(model))
  NxTest.refute(refreshed.include?(c::LEG_RULE), '„Doplniť" vlastne pravidlo neprepise')
  NxTest.refute(added.include?(c::LEG_RULE), 'ani nezdvoji')
  NxTest.assert_equal(4, c.legs_at(150.0, c::HR.project_rules(model)), 'pravidlo pouzivatela dava uzkej 4 nohy')
  NxTest.assert_equal(nil, c.stale_managed(c::HR.seed_managed_leg_rule?(model)),
                      'ziadny trvaly ORANGE, ktory by akcia nezhasla')
end

NxTest.test('SIRKA 50 (3) Codex #466 P2: NEDOTKNUTE v7 — leg_stale svieti, po Doplniť + prestavbe zhasne') do
  c = NxSirka50
  model = c::RulesModel.new([c.v7_leg_rule])
  NxTest.assert(c.stale_managed(c::HR.seed_managed_leg_rule?(model)), 'pred Doplniť: nalez')
  out, _added, refreshed = c::HR.project_seed_plan(c::HR.project_rules(model))
  NxTest.assert(refreshed.include?(c::LEG_RULE), 'Doplniť tvar obnovi')
  after = c::RulesModel.new(out, 8)
  NxTest.assert(c.stale_managed(c::HR.seed_managed_leg_rule?(after)),
                'po Doplniť, pred prestavbou: skrinka ma stale 4 nohy -> nalez ostava')
  rebuilt = c.narrow_cfg('rules_seed_version' => 8, 'hardware' => [c.leg_item(2), c.clip_item(1)])
  NxTest.assert_equal(nil, c::BOM.leg_stale_issue('S1', 42, rebuilt,
                                                  leg_rule_managed: c::HR.seed_managed_leg_rule?(after)),
                      'po prestavbe zhasne')
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'bom.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?('leg_rule_managed: legs_managed') &&
                src.include?('HardwareRules.seed_managed_leg_rule?(model)'), 'zber posiela odpoved modelu')
end

# ============================================================================
# 4 — POLOHY NOH
# ============================================================================

NxTest.test('SIRKA 50 (4): 2 nohy uzkej skrinky = stred sirky, predna + zadna') do
  c = NxSirka50
  [50.0, 150.0, 199.0].each do |w|
    pos = c.layout({ 'width' => w }, 2)
    NxTest.assert_equal(2, pos.length, "#{w}: dva valce")
    NxTest.assert(pos.all? { |x, _| (x - w / 2.0).abs < 0.001 }, "#{w}: oba v strede sirky #{pos.inspect}")
    ys = pos.map { |_, y| y }
    NxTest.assert_close(c::CN::LEG_INSET, ys.min, 0.001, "#{w}: predna noha LEG_INSET od celnej hrany")
    d = c::CN.back_stop(c.lower('width' => w))
    NxTest.assert_close(d - c::CN::LEG_INSET, ys.max, 0.001, "#{w}: zadna noha LEG_INSET pred zadnym dorazom")
  end
end

NxTest.test('SIRKA 50 (4): bezna skrinka sa NEZMENILA (600 / 4 nohy, 1200 / 6 noh)') do
  c = NxSirka50
  d = c::CN.back_stop(c.lower)
  NxTest.assert_equal([[60.0, 60.0], [540.0, 60.0], [60.0, d - 60.0], [540.0, d - 60.0]], c.layout({}, 4))
  six = c.layout({ 'width' => 1200.0 }, 6)
  NxTest.assert_equal(6, six.length)
  NxTest.assert_equal([60.0, 600.0, 1140.0], six.map(&:first).uniq.sort, 'tri stlpce')
end

NxTest.test('SIRKA 50 (4): plytka skrinka — 2 nohy sa NEPREKRYJU (audit FIX 2)') do
  c = NxSirka50
  # Hlbka 150 (ucinna 147): dva rady s LEG_INSET sa nezmestia (147 <= 60 + 60 + 50).
  pos = c.layout({ 'width' => 150.0, 'depth' => 150.0 }, 2)
  NxTest.assert_equal(2, pos.length, "dva valce #{pos.inspect}")
  NxTest.assert(pos.all? { |x, _| (x - 75.0).abs < 0.001 }, 'oba v strede sirky')
  NxTest.assert(c.min_gap(pos) >= c::CN::LEG_DIAMETER - 0.001, "nepretinaju sa (#{c.min_gap(pos)})")
  r = c::CN::LEG_DIAMETER / 2.0
  d = c::CN.back_stop(c.lower('depth' => 150.0))
  NxTest.assert(pos.all? { |_, y| y >= r - 0.001 && y <= d - r + 0.001 }, 'a nevycnievaju spod dna')
end

NxTest.test('SIRKA 50 (4): uzka skrinka — ziadna kombinacia nekresli prekryte ani bocne valce') do
  c = NxSirka50
  r = c::CN::LEG_DIAMETER / 2.0
  [50.0, 120.0, 150.0, 199.0, 199.5].each do |w|
    [150.0, 200.0, 560.0].each do |dep|
      [{}, { 'plinth_mode' => 'front' }, { 'plinth_mode' => 'front', 'plinth_recess' => 100.0 }].each do |pl|
        [1, 2, 4, 6].each do |q|
          cfg = c.lower({ 'width' => w, 'depth' => dep }.merge(pl))
          pos = c::CN.leg_layout(cfg, q)[:positions]
          tag = "#{w}x#{dep} #{pl} q#{q}"
          NxTest.assert(pos.length <= [q, 2].min, "#{tag}: najviac 2 valce (#{pos.length})")
          NxTest.assert(pos.all? { |x, _| (x - w / 2.0).abs < 0.001 }, "#{tag}: vzdy v strede sirky #{pos.inspect}")
          NxTest.assert(c.min_gap(pos) >= c::CN::LEG_DIAMETER - 0.001, "#{tag}: prekryv #{pos.inspect}")
          d = c::CN.back_stop(cfg)
          lo = pl.empty? ? r : cfg[:plinth_recess] + cfg[:thickness] + r + c::CN::LEG_PLINTH_CLEAR
          NxTest.assert(pos.all? { |_, y| y >= lo - 0.001 && y + r <= d + 0.001 },
                        "#{tag}: za doskou sokla a na nosnom dne #{pos.inspect}")
        end
      end
    end
  end
end

NxTest.test('SIRKA 50 (4) Codex P2-1: 199 x 150 so soklom vpredu — jeden valec v STREDE, nie dve bocne') do
  c = NxSirka50
  over = { 'width' => 199.0, 'depth' => 150.0, 'plinth_mode' => 'front' }
  pos = c.layout(over, 2)
  NxTest.assert_equal([[99.5, 88.0]], pos, 'jeden valec v strede sirky za doskou sokla')
  w = c.plan(over)[:warnings].find { |x| x['code'] == c::CN::LEGS_DRAWN_MERGED }
  NxTest.assert(w && w['message'].include?('v nákupe 2 ks, v modeli sa kreslí 1'), 'a plan to prizna')
end

NxTest.test('SIRKA 50 (4) Codex P2-2: sokel zapusteny 100 pri hlbke 150 — ziadny valec v doske sokla') do
  c = NxSirka50
  over = { 'width' => 150.0, 'depth' => 150.0, 'plinth_mode' => 'front', 'plinth_recess' => 100.0 }
  NxTest.assert_equal([], c.layout(over, 2), 'za soklom (100-118) na nosnom dne nie je miesto ani pre jeden')
  pl = c.plan(over)
  NxTest.assert_equal(2, pl[:hardware].find { |h| h['generic_type'] == 'leg' }['quantity'], 'nakup: 2 nohy')
  w = pl[:warnings].find { |x| x['code'] == c::CN::LEGS_DRAWN_MERGED }
  NxTest.assert(w && w['message'].include?('v modeli sa kreslí 0'), 'plan prizna 0 valcov')
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?('return if Construction.leg_layout(cfg, qty)[:positions].empty?'),
                'render_hardware prazdnu definiciu noh nekresli')
end

module NxSirka50
  module_function

  # Povodny algoritmus `CabinetBuilder.draw_legs` + `leg_xs` (main pred sirkou
  # 50) — referencia pre skrinku od 200 mm, ktora sa nesmie zmenit ani o bajt.
  def legacy_positions(cfg, qty)
    w = cfg[:width]; d = CN.back_stop(cfg)
    r = 25.0
    count = [qty, 16].min
    front_y = 60.0
    front_y = [front_y, cfg[:plinth_recess].to_f + cfg[:thickness].to_f + r + 5.0].max if cfg[:plinth_mode] == 'front'
    two_rows = count > 1 && d > front_y + 60.0 + 2 * r
    rows = if two_rows
             front = (count / 2.0).ceil
             [[front_y, front], [d - 60.0, count - front]].reject { |_, n| n < 1 }
           else
             [[d / 2.0, count]]
           end
    rows.flat_map do |y, n|
      xs = if n == 1
             [w / 2.0]
           else
             inset = [60.0, w / 2.0].min
             span = w - 2 * inset
             (0...n).map { |i| inset + span * i / (n - 1.0) }
           end
      xs.map { |x| [x, y] }
    end
  end
end

NxTest.test('SIRKA 50 (4) Codex P2-3: skrinka od 200 mm = POVODNE polohy bajtovo (aj 600 x 150 s 2 nohami)') do
  c = NxSirka50
  [200.0, 260.0, 600.0, 1200.0].each do |w|
    [150.0, 200.0, 560.0].each do |dep|
      [{}, { 'plinth_mode' => 'front' }].each do |pl|
        [1, 2, 4, 5, 6, 20].each do |q|
          cfg = c.lower({ 'width' => w, 'depth' => dep }.merge(pl))
          NxTest.assert_equal(c.legacy_positions(cfg, q), c::CN.leg_layout(cfg, q)[:positions],
                              "#{w}x#{dep} #{pl} q#{q}: polohy ako pred sirkou 50")
        end
      end
    end
  end
  # Ručne zamknuté 2 nohy na plytkej sirokej skrinke: jeden rad v strede hlbky
  # (60 / 540), nie nove predne + zadne rozlozenie uzkej skrinky.
  NxTest.assert_equal([[60.0, 73.5], [540.0, 73.5]], c.layout({ 'depth' => 150.0 }, 2))
  NxTest.refute(c.plan('depth' => 150.0)[:warnings].any? { |x| x['code'] == c::CN::LEGS_DRAWN_MERGED },
                'siroka skrinka info warning nema')
end

NxTest.test('SIRKA 50 (4): ked sa nezmestia — menej valcov + info warning, pocet v nakupe ostava') do
  c = NxSirka50
  # Sokel VPREDU pri hlbke 150: predna noha musi byt za doskou sokla (88 mm),
  # zadna najviac 122 — 34 mm je menej nez priemer, kresli sa jedna.
  over = { 'width' => 150.0, 'depth' => 150.0, 'plinth_mode' => 'front' }
  pos = c.layout(over, 2)
  NxTest.assert_equal(1, pos.length, "jeden valec #{pos.inspect}")
  front_min = 40.0 + 18.0 + 25.0 + c::CN::LEG_PLINTH_CLEAR
  NxTest.assert(pos.first[1] >= front_min - 0.001, 'valec nestoji v doske sokla')
  pl = c.plan(over)
  NxTest.assert_equal(2, pl[:hardware].find { |h| h['generic_type'] == 'leg' }['quantity'], 'nakup: 2 nohy')
  w = pl[:warnings].find { |x| x['code'] == c::CN::LEGS_DRAWN_MERGED }
  NxTest.assert(w, 'plan to prizna')
  NxTest.assert_equal('info', w['severity'])
  NxTest.assert(w['message'].include?('v nákupe 2 ks, v modeli sa kreslí 1'), w['message'])
  NxTest.refute(c.plan('width' => 150.0)[:warnings].any? { |x| x['code'] == c::CN::LEGS_DRAWN_MERGED },
                'bezna hlbka warning nema')
end

NxTest.test('SIRKA 50 (4): Kontrola info warning NEUKAZUJE ako nalez (BUILD_INFO_ONLY)') do
  c = NxSirka50
  NxTest.assert(c::V::BUILD_INFO_ONLY.include?(c::CN::LEGS_DRAWN_MERGED))
  w = c::BP.warning(c::CN::LEGS_DRAWN_MERGED, 'Nohy: ...', severity: 'info').merge('owner_id' => 'S1')
  items = c::V.run({ records: [], hardware_overrides: [], warnings: [w], cabinets: 1 })['items']
  NxTest.refute(items.any? { |i| i['message_sk'].to_s.include?('Nohy: ...') }, 'ziadny ORANGE riadok')
end

NxTest.test('SIRKA 50 (4): CabinetBuilder kresli VYHRADNE polohy z leg_layout') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'), encoding: 'UTF-8')
  body = src[/def draw_legs\(ents, cfg, qty\)(.*?)\n        end\n/m, 1].to_s
  NxTest.assert(body.include?('Construction.leg_layout(cfg, qty)[:positions]'))
  NxTest.refute(src.include?('def leg_xs'), 'druha kopia vypoctu poloh zanikla')
  NxTest.assert_equal(Noxun::Engine::Construction::LEG_DIAMETER, Noxun::Engine::CabinetBuilder::LEG_DIAMETER)
end

# ============================================================================
# 5 — MIERKA: 50 mm pri hrubke 18 prejde, hruby material sa odmietne s vetou
# ============================================================================

# ScaleWatch (klampy absorpcie) — vzor `test_h12_golden.rb`: observer triedy
# nad `Sketchup::*Observer` sa na chvilu podstrcia a hned upracu.
if NxTest.headless? && !defined?(Noxun::Engine::ScaleWatch)
  su = Module.new
  %w[EntityObserver EntitiesObserver AppObserver].each { |cl| su.const_set(cl, Class.new) }
  Object.const_set(:Sketchup, su)
  begin
    require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer')
  ensure
    Object.send(:remove_const, :Sketchup)
  end
end

NxTest.test('SIRKA 50 (5): Mierka — hole minimum 50; hruby material = odmietnutie s vetou, nie tichy klamp') do
  sw = Noxun::Engine::ScaleWatch
  c = NxSirka50
  NxTest.assert_equal(50.0, sw.min_for('width', 'lower'), 'absorpcia dolnej klampuje na 50')
  NxTest.assert_equal(50.0, sw.min_for('width', 'upper'), 'aj hornej')
  NxTest.assert_equal(300.0, sw.min_for('width', 'dishwasher'), 'slot ostava 300')
  # Hrubka 25: 50 mm by prestavba odmietla — `reject_scale` vrati skrinku
  # a ukaze PRESNE tuto vetu (vzor D-120: neplatny Scale = rollback).
  NxTest.assert_raise(/Sirka je prilis mala vzhladom na hrubku/) do
    c::CN.build_plan(c.lower('width' => 50.0, 'thickness' => 25.0), 'CAB-002')
  end
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer.rb'), encoding: 'UTF-8')
  absorb = src[/def absorb\(inst\)(.*?)\n        end\n/m, 1].to_s
  NxTest.assert(absorb.include?('if new_w < base_w && Construction.corner?(cfg)'),
                'config-aware klamp sirky ostava len pri rohovej (ina skrinka = hole minimum)')
end
