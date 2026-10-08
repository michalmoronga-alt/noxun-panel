# frozen_string_literal: true
# Sirka od 50 mm + nohy 2/4/6 (jedna davka, 8.10.2026).
#
# Sirku (schema 23, MIN 50, krizova kontrola hrubky) drzi `test_s1e0_min_vyska.rb`.
# Tu su veci, ktore by sa bez spolocneho bumpnu seedu rozisli so sirkou:
#   * nedotknute pravidlo noh z verzie 5 aj z verzie 7 (pasma 4/6) sa obnovi
#     na 2/4/6; upravene pasma ostanu,
#   * `leg_stale` pri seede 6/7 uz nehlasi siroku skrinku ani chybajuci prichyt,
#     ale uzku skrinku so 4 nohami z pravidla este ano; seed 8 mlci,
#   * dve nohy stoja v strede sirky (predna + zadna); ked sa dva valce
#     nezmestia, kresli sa jeden a plan to povie — nakup ostava 2.
require_relative '../helper' unless defined?(NxTest)

module NxSirka50
  E  = Noxun::Engine
  HR = E::HardwareRules
  CB = E::CabinetBuilder
  CN = E::Construction
  BOM = E::Bom
  LEG = HR::LEG_RULE_ID

  module_function

  def rules
    HR.normalize_rules(HR::SEED_RULES)
  end

  def leg_rule(list)
    list.find { |r| r['rule_id'] == LEG }
  end

  def bands_of(rule)
    Array(rule['bands']).map { |b| [b['max'], b['quantity']] }
  end

  def want_bands
    [[HR::LEG_NARROW_BAND_MAX, 2], [999.0, 4], [nil, 6]]
  end

  # Knižnica, v ktorej nohy este nesu dany stary tvar a zvysok seedu chyba
  # len pravidlo noh (ostatne seed pravidla ostanu, aby merge neriesil nic ine
  # nez obnovu noh — prichyt uz v seede v6+ je).
  def library_with(leg_shape)
    HR.normalize_rules([leg_shape] + HR::SEED_RULES.reject { |r| r['rule_id'] == LEG })
  end

  def leg_item(quantity, over = {})
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'quantity' => quantity,
      'rule_id' => LEG, 'source' => 'rule', 'params' => { 'height' => 100.0 } }.merge(over)
  end

  def stale(over = {})
    BOM.leg_stale_issue('S1', 42, {
      'config_schema' => CB::CONFIG_SCHEMA,
      'rules_seed_version' => 7,
      'width' => 150.0, 'floor_height' => 100.0,
      'support' => { 'type' => 'legs', 'height' => 100.0 },
      'hardware' => [leg_item(4)], 'front_items' => []
    }.merge(over))
  end

  def plan_for(over)
    cfg = CB.normalize({
      'type' => 'lower', 'width' => 150.0, 'height' => 720.0, 'depth' => 560.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'back_mode' => 'none', 'plinth_mode' => 'none', 'plinth_recess' => 40.0
    }.merge(over))
    CN.build_plan(cfg, 'CAB-SIRKA', hardware_rules: rules)
  end

  def leg_qty(plan)
    Array(plan[:hardware]).select { |h| h['generic_type'].to_s == 'leg' }
                          .sum { |h| h['quantity'].to_i }
  end

  def collapsed_warning(plan)
    Array(plan[:warnings]).find { |w| w['code'].to_s == 'legs_drawn_collapsed' }
  end
end

# ============================================================================
# 1 — MIGRACIA PRAVIDLA NOH
# ============================================================================

NxTest.test('sirka 50: konstanty pasma a bran zostavaju pevne cisla') do
  c = NxSirka50
  NxTest.assert_equal(8, c::HR::SEED_VERSION)
  NxTest.assert_equal(6, c::HR::LEG_WIDTH_SEED_VERSION, 'brana sirokej skrinky sa neposuva')
  NxTest.assert_equal(8, c::HR::LEG_NARROW_SEED_VERSION)
  NxTest.assert_close(200.0, c::HR::LEG_NARROW_BELOW_MM)
  NxTest.assert_close(199.999, c::HR::LEG_NARROW_BAND_MAX)
  NxTest.assert_equal(c.want_bands, c.bands_of(c.leg_rule(c.rules)))
end

NxTest.test('sirka 50: nedotknute nohy z verzie 5 aj 7 sa obnovia na 2/4/6') do
  c = NxSirka50
  shapes = c::HR::LEGACY_SEED_SHAPES[c::LEG]
  NxTest.assert_equal('fixed', shapes[0]['kind'], 'index [0] ostava pevne 4 (v1..v5)')
  NxTest.assert_equal(4, shapes[0]['quantity'])
  NxTest.assert_equal([[999.0, 4], [nil, 6]], c.bands_of(shapes[1]),
                      'index [1] je stary tvar 4/6 (v6..v7)')

  [[5, shapes[0]], [7, shapes[1]]].each do |from, shape|
    merged, changed = c::HR.merge_seed(c.library_with(shape), from)
    NxTest.assert(changed, "migracia z verzie #{from} prebehne")
    NxTest.assert_equal(c.want_bands, c.bands_of(c.leg_rule(merged)),
                        "verzia #{from} dostane 2/4/6, nie stare 4/6")
  end
  fresh, = c::HR.merge_seed(c.rules, c::HR::SEED_VERSION)
  NxTest.assert_equal(c.rules, fresh, 'z aktualneho seedu sa uz nic nemeni')
end

NxTest.test('sirka 50: upravene pasma noh z verzie 7 sa neprepisuju') do
  c = NxSirka50
  mine = c::HR::LEGACY_SEED_SHAPES[c::LEG][1].merge(
    'bands' => [
      { 'max' => 999.0, 'quantity' => 5 },
      { 'max' => nil, 'quantity' => 6 }
    ]
  )
  merged, = c::HR.merge_seed(c.library_with(mine), 7)
  leg = c.leg_rule(merged)
  NxTest.assert_equal('bands', leg['kind'])
  NxTest.assert_equal(5, leg['bands'][0]['quantity'], '5 noh ostava 5 noh')

  out, _added, refreshed = c::HR.project_seed_plan(c::HR.normalize_rules([mine]))
  NxTest.refute(refreshed.include?(c::LEG), 'Doplnit predvolby cudziu upravu neobnovi')
  NxTest.assert_equal(5, c.leg_rule(out)['bands'][0]['quantity'])

  untouched, _a, refreshed_ok = c::HR.project_seed_plan(
    c::HR.normalize_rules([c::HR::LEGACY_SEED_SHAPES[c::LEG][1]])
  )
  NxTest.assert_equal([c::LEG], refreshed_ok, 'nedotknute 4/6 sa obnovi')
  NxTest.assert_equal(c.want_bands, c.bands_of(c.leg_rule(untouched)))
end

# ============================================================================
# 2 — ORANGE leg_stale
# ============================================================================

NxTest.test('sirka 50: uzka skrinka so 4 nohami z pravidla je ORANGE az po seed 8') do
  c = NxSirka50
  iss = c.stale
  NxTest.assert(iss, 'seed 7, sirka 150, 4 nohy z pravidla')
  NxTest.assert_equal('orange', iss['severity'])
  NxTest.assert(iss['message'].include?('pred pravidlom 2/4/6'), iss['message'])
  NxTest.assert(iss['message'].include?('2 nôh'), iss['message'])
  NxTest.assert(iss['message'].include?('1 príchyt'), iss['message'])

  NxTest.assert_equal(nil, c.stale('rules_seed_version' => 8),
                      'po Doplnit predvolby a prestavbe (seed 8) veta zhasne')
  NxTest.assert_equal(nil, c.stale('width' => 600.0),
                      'seed 7 a sirka 600 so 4 nohami je aj podla noveho pravidla 4 — mlci')
  NxTest.assert_equal(nil, c.stale('rules_seed_version' => 6, 'width' => 600.0,
                                    'floor_height' => 100.0),
                      'chybajuci prichyt pod seedom 6 uz nie je symptomy')
  NxTest.assert_equal(nil, c.stale('hardware' => [c.leg_item(4, 'source' => 'manual')]),
                      'rucne 4 nohy sa nekomentuju')
  NxTest.assert_equal(nil, c.stale('hardware' => [c.leg_item(2)]),
                      'skrinka, ktora uz ma 2 nohy, nalez nerobi')
end

# ============================================================================
# 3 — KRESBA DVOCH NOH A VAROVANIE PLANU
# ============================================================================

NxTest.test('sirka 50: dve nohy stoja v strede sirky, predna a zadna') do
  c = NxSirka50
  cfg = { width: 150.0, thickness: 18.0, plinth_mode: 'none', plinth_recess: 40.0 }
  lay = c::CB.leg_layout(cfg, 2, 560.0)
  NxTest.refute(lay[:collapsed], 'hlbka 560 dva valce zmesti')
  NxTest.assert_equal(2, lay[:points].length)
  lay[:points].each { |x, _y| NxTest.assert_close(75.0, x, 0.01) }
  ys = lay[:points].map { |_x, y| y }.sort
  NxTest.assert_close(60.0, ys[0], 0.01, 'predna noha na insete')
  NxTest.assert_close(500.0, ys[1], 0.01, 'zadna noha na hlbke minus inset')

  # Bez explicitnej hlbky rozhoduje zadny doraz, nie celkova hlbka s nalozenym chrbtom.
  none = c::CB.normalize('type' => 'lower', 'width' => 150.0, 'height' => 720.0,
                         'depth' => 560.0, 'thickness' => 18.0, 'floor_height' => 100.0,
                         'back_mode' => 'none', 'plinth_mode' => 'none')
  over = none.merge(back_mode: 'overlay', back_thickness: 3.0)
  NxTest.assert_close(500.0, c::CB.leg_layout(none, 2)[:points].map { |_x, y| y }.max, 0.01)
  NxTest.assert_close(497.0, c::CB.leg_layout(over, 2)[:points].map { |_x, y| y }.max, 0.01,
                      'nalozeny chrbat 3 mm posunie zadnu nohu (back_stop)')
end

NxTest.test('sirka 50: plytka hlbka bez sokla este zmesti dva valce, so soklom vpredu jeden') do
  c = NxSirka50
  cfg = { width: 80.0, thickness: 18.0, plinth_mode: 'none', plinth_recess: 40.0 }
  lay = c::CB.leg_layout(cfg, 2, 150.0)
  NxTest.refute(lay[:collapsed], 'po uvolneni zadneho insetu sa 150 mm zmesti')
  ys = lay[:points].map { |_x, y| y }.sort
  NxTest.assert_equal(2, ys.length)
  NxTest.assert_close(60.0, ys[0], 0.01)
  NxTest.assert_close(125.0, ys[1], 0.01, 'zadna noha az na okraj valca (hlbka minus polomer)')
  NxTest.assert(ys[1] - ys[0] >= c::CB::LEG_DIAMETER - 0.01)

  front = cfg.merge(plinth_mode: 'front')
  one = c::CB.leg_layout(front, 2, 150.0)
  NxTest.assert(one[:collapsed], 'sokel vpredu necha medzi nohami menej nez priemer')
  NxTest.assert_equal(1, one[:points].length)
  NxTest.assert_close(40.0, one[:points][0][0], 0.01)
  NxTest.assert_close(106.5, one[:points][0][1], 0.01)

  # 4 nohy ostanu na starych dvoch radoch — uzke pravidlo sa na ne nevzťahuje.
  four = c::CB.leg_layout({ width: 600.0, thickness: 18.0, plinth_mode: 'none' }, 4, 560.0)
  NxTest.refute(four[:collapsed])
  NxTest.assert_equal(4, four[:points].length)
  NxTest.refute(four[:points].all? { |x, _y| (x - 300.0).abs < 0.01 },
                'styri nohy nestoja vsetky v strede sirky')
end

NxTest.test('sirka 50: plan varuje len ked sa kresba zlozi, nakup ostava 2') do
  c = NxSirka50
  deep = c.plan_for('width' => 50.0, 'depth' => 560.0)
  NxTest.assert_equal(2, c.leg_qty(deep), 'sirka 50 kupuje 2 nohy')
  NxTest.assert_equal(nil, c.collapsed_warning(deep))

  shallow = c.plan_for('depth' => 150.0, 'back_mode' => 'none', 'plinth_mode' => 'none')
  NxTest.assert_equal(2, c.leg_qty(shallow))
  NxTest.assert_equal(nil, c.collapsed_warning(shallow), '150 mm bez sokla este kresli dva valce')

  tight = c.plan_for('depth' => 150.0, 'back_mode' => 'none',
                     'plinth_mode' => 'front', 'plinth_recess' => 40.0)
  NxTest.assert_equal(2, c.leg_qty(tight), 'nakup sa kresbou nemeni')
  w = c.collapsed_warning(tight)
  NxTest.assert(w, 'plan povie, ze sa kresli jeden valec')
  NxTest.assert(w['message'].to_s.include?('2 nohy'), w['message'].inspect)
  NxTest.assert(w['message'].to_s.include?('objednáva sa 2'), w['message'].inspect)

  upper = c::CN.build_plan(
    c::CB.normalize('type' => 'upper', 'width' => 50.0, 'height' => 720.0,
                    'depth' => 320.0, 'thickness' => 18.0),
    'CAB-HORNA', hardware_rules: c.rules
  )
  NxTest.assert_equal(0, c.leg_qty(upper), 'horna skrinka nohy nema')
  NxTest.assert_equal(nil, c.collapsed_warning(upper))

  dw = c::CB.normalize('type' => 'dishwasher', 'width' => 50.0, 'height' => 880.0,
                       'depth' => 560.0, 'thickness' => 18.0)
  NxTest.assert_close(300.0, dw[:width], 0.01, 'umyvacka si dolnu hranicu 300 necha')
  low = c::CB.normalize('type' => 'lower', 'width' => 50.0, 'height' => 720.0,
                        'depth' => 510.0, 'thickness' => 18.0, 'floor_height' => 100.0)
  NxTest.assert_close(50.0, low[:width], 0.01)
  NxTest.assert_close(50.0, c::CN.min_valid_width(low), 0.01,
                      'nerohova sirka ostava na holom minime typu')
end
