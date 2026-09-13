# frozen_string_literal: true
# Testy D-128: RUCNA VYSKA DREVENEHO BOXU ZASUVKY — tretia os zamku.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 pole `box_height` v `hardware_overrides` — LEN na receptovej identite
#      systemu, ktoreho resolver vysku boxu POCITA (nie Atira), strict Float > 0
#   R2 `CONFIG_SCHEMA` 13 -> 14; `DRAWER_ACTIVATION_SCHEMA` ostava 5
#   R3 resolver: zamok v rozsahu narezhe dielce boxu na neho (dno sa nemeni),
#      mimo rozsahu je RED `box_lock_invalid` bez dielcov a bez vysuvu;
#      hranice su INKLUZIVNE a bez EPS
#   R4 upgrade receptu zamok znovu overi (`UPGRADE_LOCK_AXES` pozna os `box`)
#   R5 payload nesie `axes['box']` (auto | locked | conflict) s `min`/`max`;
#      Atira kluc `box` NEMA, Quadro nadalej NEMA kluc `height`
#   R6 zapisova cesta: brany typu a identity, Atira odmietnuta, rozsah proti
#      CERSTVEMU stavu, `value: null` odomkne LEN tuto os
#   A1 sablona ZIADNU os zamku nenesie (existujuci kontrakt, charakterizacia)
#   A4 rozsah pozna SKUTOCNU hrubku dna (16 vs 18 = min 58 vs 60)
#   A5 dormantny zamok po classic <-> tipon (charakterizacia existujucej medzery)
#   A6 `max < min` = zamknut sa neda nic (`min`/`max`/`proposal` su nil)
#   A7 karta pri aktivnom zamku NETVRDI vzorec a veta „ručne zamknuté" MENUJE OSI
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do core spadne uvedeny test):
#   M1 resolver prijme zamok nad automat (`>` -> `>=` v `box_lock_problem`)
#      -> „D-128 (R3): zamok NAD automatom = box_lock_invalid bez dielcov"
#   M2 normalizacia prijme `box_height` na Atire (vypadne kontrola systemu)
#      -> „D-128 (R1): `box_height` na ATIRE normalizacia zahodi S LOGOM"
#   M3 odomknutie osi zahodi CELY zaznam (`merge_override` field -> :all)
#      -> „D-128 (R6): odomknutie osi boxu necha NL zamok zit"
#   M4 JS posle hodnotu z textu chipu namiesto pola (tests/js/test_d128_ui.js)
#      -> „D-128: zapis ide z POLA, nie z textu chipu"
#   M5 payload `axes['box']` chyba pri `locked` (vetva `else` v `drawer_axes`)
#      -> „D-128 (R5): zamknuta os boxu ma `state: locked` a hodnotu zamku"
#   M6 JS `parseFloat` bez prisneho regexu (tests/js/test_d128_ui.js)
#      -> „D-128: prisny parser odmietne „1e309" aj „300,5xx""
#   M7 `proposal` = max aj pri `max < min`
#      -> „D-128 (A6): prazdny rozsah nedava ani pole, ani navrh nahrady"
#   M8 `locked_note` pise „Dĺžka výsuvu" pri samotnom zamku boxu
#      -> „D-128 (A7): veta „ručne zamknuté" MENUJE prave zamknute osi"
# Codex #364 kolo 1 (P2):
#   M9  JS neoznaci pole ako odoslane (tests/js/test_d128_ui.js)
#       -> „D-128 (P2): Enter dvakrat + blur = JEDEN zapis"
#   M10 zapisova cesta hodnotu NEZAOKRUHLI (`mm.round(1)` vypadne)
#       -> „D-128 (P2): zapis zaokruhli na 0,1 mm — panel ukazuje, co je ulozene"
#   M12 `box_range` vrati SUROVE hranice (bez mriezky 0,1)
#       -> „D-128 (P3): hranice rozsahu lezia na mriezke 0,1 mm"
require_relative '../helper' unless defined?(NxTest)

# Panelove akcie nie su v require zozname helpera (vzor KOV-D2a).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxD128
  module_function

  def e
    Noxun::Engine
  end

  def r
    e::Recipes
  end

  def cb
    e::CabinetBuilder
  end

  def panel
    e::Panel
  end

  def rec(id = 'quadro_v6_sisy_v1')
    r.load(id)
  end

  OWNER = 'front:F1/panel'
  RID   = 'recipe:quadro_v6_sisy_v1'
  ARID  = 'recipe:atira_sisy_v1'
  BOTTOM_KEY = 'front:F1/drawer_bottom'
  # Katalogovy zaznam UNI 18 mm (seed) — jedina cesta, ako headless dostat
  # dno inej hrubky nez UNI 16 do CELEJ retaze (materialy -> hrubky -> plan).
  SHEET18 = 'UNI_DOSKA_18'

  # Svetly priestor JEDNEJ zasuvky. Cisla su tie iste, s akymi pocita stavba:
  # clear_height 400 -> automat boxu 360 (400 - vola 40); dno 16 -> min 58
  # (celo/chrbat 30 + dno 16 + odsadenie 12).
  def ctx(clear_height: 400.0, clear_depth: 497.0, clear_width: 864.0,
          side_thickness: 18.0, obstructions: [], owner: OWNER, bottom: 16.0)
    { clear_width: clear_width, clear_height: clear_height, clear_depth: clear_depth,
      side_thickness: side_thickness, obstructions: obstructions, owner_part_key: owner,
      part_thicknesses: th(bottom) }
  end

  def th(bottom = 16.0)
    { 'drawer_bottom' => bottom, 'box_side' => 16.0,
      'drawer_inner_front' => 16.0, 'drawer_back' => 16.0 }
  end

  def th_atira
    { 'drawer_bottom' => 16.0, 'drawer_back' => 16.0 }
  end

  # Jeden zaznam `hardware_overrides` s lubovolnou kombinaciou osi.
  def ov(fields, rule_id = RID, owner = OWNER)
    [{ 'owner_part_key' => owner, 'generic_type' => 'slide',
       'rule_id' => rule_id }.merge(fields)]
  end

  def codes(res)
    res[:conflicts].map { |c| c[:code] }
  end

  def assert_fail_closed(res, code)
    NxTest.assert_equal([code], codes(res), "ocakavany konflikt #{code}")
    NxTest.assert_equal([], res[:parts], 'konflikt = ziadny dielec')
    NxTest.assert_equal({}, res[:hardware_params], 'konflikt = ziadne parametre polozky')
  end

  def part(res, role, side = nil)
    res[:parts].find { |p| p[:role] == role && (side.nil? || p[:side] == side) }
  end

  # --- fixtury pre PAYLOAD a ZAPISOVU cestu --------------------------------
  #
  # Skrinka 900 x 720 x 500 s JEDNYM zasuvkovym celom DREVENEJ konstrukcie
  # (Quadro V6 SiSy). Vyska cela 416 -> svetla vyska 400 (16 mm rozdiel medzi
  # spodkom riadku a spodkom interieru) -> automat boxu 360, min 58.
  def params(front_height: 416.0, opening: 'classic', over: {})
    item = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
             'height' => front_height, 'opening_mode' => opening,
             'drawer' => { 'construction' => 'wood' } }
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'fronts' => { 'items' => [item] } }.merge(over)
  end

  # ULOZENY config skrinky presne tak, ako ho po stavbe vidi panel (vzor D2a).
  def cfg_for(par, overrides = [])
    norm = cb.normalize(par.merge('hardware_overrides' => overrides))
    eff = cb.effective_materials(nil, norm)
    plan = e::Construction.build_plan(norm, 'CAB-1',
                                      part_thicknesses: cb.drawer_thicknesses(norm, eff))
    JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(norm, plan))))
  end

  def axes_for(par, overrides = [])
    cfg = cfg_for(par, overrides)
    [cfg, panel.drawer_axes_map(cfg, cb.config_to_params(cfg))]
  end

  def index_for(par, overrides = [])
    cfg = cfg_for(par, overrides)
    [cfg, panel.drawer_axes_index(cfg, cb.config_to_params(cfg))]
  end

  def slide_item(cfg)
    Array(cfg['hardware']).find { |h| h['source'].to_s == 'recipe' }
  end

  def cab_with(cfg)
    inst = NxTest::FakeEntity.new
    inst.set_attribute(e::Store::DICT, 'config', JSON.generate(cfg))
    inst
  end

  def write_value(cfg, field, raw, rid = RID, owner = OWNER, gt = 'slide')
    panel.override_value(field, raw, nil, cab_with(cfg), owner, gt, rid)
  end

  # Odchyti, co by islo do konzoly SketchUpu (`Engine.log` je headless stub).
  def with_log_capture
    msgs = []
    orig = e.method(:log)
    e.define_singleton_method(:log) { |m| msgs << m.to_s; nil }
    yield msgs
  ensure
    e.define_singleton_method(:log, orig)
  end
end

# ============================================================================
# R3 — RESOLVER
# ============================================================================

NxTest.test('D-128 (R3): zamok v rozsahu nareze VSETKY dielce boxu na seba (dno sa nemeni)') do
  c = NxD128
  auto = c.r.resolve(c.rec, c.ctx, c.th, [])
  NxTest.assert_equal([], c.codes(auto))
  NxTest.assert_close(360.0, auto[:box_height], 0.001, 'automat = svetla 400 - vola 40')

  res = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 300.0))
  NxTest.assert_equal([], c.codes(res))
  NxTest.assert_close(300.0, res[:box_height], 0.001)
  NxTest.assert_close(300.0, res[:hardware_params]['box_height'], 0.001,
                      'polozka vysuvu nesie ZAMKNUTU vysku')
  # Boky: NL x vyska boxu (NL 450 — hlbka 497 na 500 nestaci).
  %w[left right].each do |side|
    p = c.part(res, 'box_side', side)
    NxTest.assert_close(450.0, p[:width], 0.001, "#{side} bok: dlzka = NL")
    NxTest.assert_close(300.0, p[:height], 0.001, "#{side} bok: vyska = zamok")
  end
  # Celo aj chrbat: SKW x (zamok - hrubka dna - odsadenie) = 818 x 272.
  %w[drawer_inner_front drawer_back].each do |role|
    p = c.part(res, role)
    NxTest.assert_close(818.0, p[:width], 0.001)
    NxTest.assert_close(272.0, p[:height], 0.001, "#{role}: 300 - 16 - 12")
  end
  # DNO sa zamkom NEMENI — je to SKW x NL.
  bottom = c.part(res, 'drawer_bottom')
  NxTest.assert_close(818.0, bottom[:width], 0.001)
  NxTest.assert_close(450.0, bottom[:height], 0.001)
  NxTest.assert_equal(c.part(auto, 'drawer_bottom')[:height], bottom[:height],
                      'dno je pri automate aj pri zamku to iste')
  NxTest.assert(res[:explain].any? { |x| x.include?('ručný zámok; automat 360') },
                res[:explain].inspect)
end

NxTest.test('D-128 (R3): zamok NAD automatom = box_lock_invalid bez dielcov') do
  c = NxD128
  res = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 400.0))
  c.assert_fail_closed(res, 'box_lock_invalid')
  msg = res[:conflicts].first[:message]
  NxTest.assert(msg.include?('nad automatom 360'), msg)
  NxTest.assert(msg.include?('zámok sa nikdy nemení automaticky'), msg)
end

NxTest.test('D-128 (R3): zamok POD minimom = box_lock_invalid s druhou vetou') do
  c = NxD128
  res = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 50.0))
  c.assert_fail_closed(res, 'box_lock_invalid')
  msg = res[:conflicts].first[:message]
  NxTest.assert(msg.include?('pod minimom 58'), msg)
  NxTest.assert(msg.include?('30'), "veta menuje minimum cela/chrbta: #{msg}")
end

NxTest.test('D-128 (R3): hranice su INKLUZIVNE a bez EPS') do
  c = NxD128
  ok_max = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 360.0))
  NxTest.assert_equal([], c.codes(ok_max), 'presne automat PLATI')
  bad_max = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 360.01))
  NxTest.assert_equal(['box_lock_invalid'], c.codes(bad_max), '360,01 uz nie')

  ok_min = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 58.0))
  NxTest.assert_equal([], c.codes(ok_min), 'presne minimum PLATI')
  bad_min = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 57.99))
  NxTest.assert_equal(['box_lock_invalid'], c.codes(bad_min), '57,99 uz nie')
end

NxTest.test('D-128 (A4): rozsah pozna SKUTOCNU hrubku dna (16 vs 18 = min 58 vs 60)') do
  c = NxD128
  r16 = c.r.box_range(c.rec, 400.0, c.th(16.0))
  r18 = c.r.box_range(c.rec, 400.0, c.th(18.0))
  NxTest.assert_close(58.0, r16[:min], 0.001)
  NxTest.assert_close(60.0, r18[:min], 0.001)
  NxTest.assert_close(360.0, r16[:max], 0.001)
  NxTest.assert_close(360.0, r18[:max], 0.001, 'automat na hrubke dna nezavisi')
  # 59 mm: pri dne 16 PLATI, pri dne 18 uz nie.
  NxTest.assert_equal([], c.codes(c.r.resolve(c.rec, c.ctx(bottom: 16.0), c.th(16.0),
                                              c.ov('box_height' => 59.0))))
  NxTest.assert_equal(['box_lock_invalid'],
                      c.codes(c.r.resolve(c.rec, c.ctx(bottom: 18.0), c.th(18.0),
                                          c.ov('box_height' => 59.0))))
  # ATIRA os NEMA — rozsah sa pre nu nikdy nepocita.
  NxTest.assert_equal(nil, c.r.box_range(c.rec('atira_sisy_v1'), 400.0, c.th_atira))
  # Neurcitelna hrubka dna = rozsah sa NEHADA.
  NxTest.assert_equal(nil, c.r.box_range(c.rec, 400.0, {}))
end

NxTest.test('D-128 (R1): `box_height` na ATIRE resolver NIKDY nepouzije') do
  c = NxD128
  lock = c.ov({ 'box_height' => 100.0 }, c::ARID)
  res = c.r.resolve(c.rec('atira_sisy_v1'), c.ctx(clear_height: 200.0, clear_depth: 560.0),
                    c.th_atira, lock)
  NxTest.assert_equal([], c.codes(res), 'Atira zamok boxu ignoruje, nie je to konflikt')
  NxTest.assert_equal(nil, res[:box_height])
  NxTest.assert_equal(144, res[:height_variant], 'vyska plynie z varianta')
  NxTest.assert_equal(nil, c.r.box_lock_value(c.rec('atira_sisy_v1'), c.ctx, lock))
end

NxTest.test('D-128 (R1): `disabled` VITAZI — vypnuty zaznam zamok boxu nenesie') do
  c = NxD128
  res = c.r.resolve(c.rec, c.ctx, c.th, c.ov('box_height' => 300.0, 'disabled' => true))
  NxTest.assert_close(360.0, res[:box_height], 0.001, 'plati automat')
  NxTest.assert_equal(nil, c.r.box_lock_value(c.rec, c.ctx,
                                              c.ov('box_height' => 300.0, 'disabled' => true)))
end

NxTest.test('D-128 (R1): zamok boxu patri LEN svojmu receptu a svojmu vlastnikovi') do
  c = NxD128
  NxTest.assert_equal(nil, c.r.box_lock_value(c.rec, c.ctx,
                                              c.ov({ 'box_height' => 300.0 }, 'recipe:quadro_v6_p2o_v1')),
                      'zaznam INEHO receptu je dormantny')
  NxTest.assert_equal(nil, c.r.box_lock_value(c.rec, c.ctx,
                                              c.ov({ 'box_height' => 300.0 }, c::RID, 'front:F9/panel')),
                      'zaznam INEHO cela sa nepouzije')
  NxTest.assert_equal(nil, c.r.box_lock_value(c.rec, c.ctx,
                                              c.ov({ 'box_height' => 300.0 }, 'vysuvy-nl-podla-hlbky')),
                      'legacy pravidlo vysku boxu nikdy nedrzalo')
end

# ============================================================================
# R1 / R2 — NORMALIZACIA A SCHEMA
# ============================================================================

NxTest.test('D-128 (R1): `box_height` prezije normalizaciu na receptovej polozke Quadra') do
  c = NxD128
  out = c.cb.norm_hardware_overrides(c.ov('box_height' => 300.5))
  NxTest.assert_equal(1, out.length)
  NxTest.assert_close(300.5, out.first['box_height'], 0.001, 'desatiny su platna vyska')
  NxTest.assert_equal(1, c.cb.norm_hardware_overrides(c.ov('box_height' => 300.0)).length,
                      'zaznam LEN so zamkom boxu je OBSAZNY')
end

NxTest.test('D-128 (R1): `box_height` na ATIRE normalizacia zahodi S LOGOM') do
  c = NxD128
  c.with_log_capture do |msgs|
    out = c.cb.norm_hardware_overrides(c.ov({ 'box_height' => 300.0 }, c::ARID))
    NxTest.assert_equal([], out, 'zaznam bez ineho obsahoveho pola zanikne')
    NxTest.assert(msgs.any? { |m| m.include?('box_height zahodeny') && m.include?('nepocita') },
                  msgs.inspect)
  end
end

NxTest.test('D-128 (R1): zamok boxu zije LEN na polozke `slide` a LEN na receptovej identite') do
  c = NxD128
  cases = [
    [c.ov({ 'box_height' => 300.0 }, c::RID).map { |o| o.merge('generic_type' => 'hinge') },
     'polozke slide'],
    [c.ov({ 'box_height' => 300.0 }, 'vysuvy-nl-podla-hlbky'), 'receptovej polozke'],
    [c.ov({ 'box_height' => 300.0 }, 'recipe:nieco_ine_v1'), 'nepocita']
  ]
  cases.each do |raw, why|
    c.with_log_capture do |msgs|
      out = c.cb.norm_hardware_overrides(raw)
      NxTest.assert_equal([], out.map { |o| o['box_height'] }.compact, "#{why}: pole musi zaniknut")
      NxTest.assert(msgs.any? { |m| m.include?('box_height zahodeny') }, "#{why}: chyba log")
    end
  end
end

NxTest.test('D-128 (R1): neplatny TVAR sa zahodi S LOGOM, `disabled` prezije') do
  c = NxD128
  [['300', 'String'], [0, 'nula'], [-5.0, 'zaporne'], [Float::INFINITY, 'Infinity']].each do |raw, why|
    c.with_log_capture do |msgs|
      out = c.cb.norm_hardware_overrides(c.ov('box_height' => raw, 'disabled' => true))
      NxTest.assert_equal(1, out.length, "#{why}: zaznam nesie `disabled`, takze NEZANIKA")
      NxTest.refute(out.first.key?('box_height'), "#{why}: neplatny zamok sa nezapisal")
      NxTest.assert_equal(true, out.first['disabled'])
      NxTest.assert(msgs.any? { |m| m.include?('box_height zahodeny') }, "#{why}: chyba log")
    end
  end
end

NxTest.test('D-128 (R2): schema 14, aktivacie sa nehybu, dopredny guard drzi') do
  c = NxD128
  NxTest.assert_equal(14, c.cb::CONFIG_SCHEMA, 'D-128 zaviedla schemu 14')
  NxTest.assert_equal(5, c.cb::DRAWER_ACTIVATION_SCHEMA)
  NxTest.assert_equal(9, c.cb::HINGE_ACTIVATION_SCHEMA)
  NxTest.assert_equal(11, c.cb::LIFT_ACTIVATION_SCHEMA)
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'),
                  encoding: 'UTF-8')
  NxTest.assert(src.include?('#  14 = D-128'), 'HISTORIA musi povedat, PRECO sa bumplo')

  cur = c.cb::CONFIG_SCHEMA
  NxTest.refute(c.cb.newer_config?('config_schema' => cur))
  NxTest.refute(c.cb.newer_config?('config_schema' => 13))
  NxTest.assert(c.cb.newer_config?('config_schema' => cur + 1),
                'config schemy 15 by tento plugin prestavat NESMEL')
  inst = NxTest::FakeEntity.new
  inst.set_attribute(c.e::Store::DICT, 'config', JSON.generate('config_schema' => cur + 1))
  NxTest.assert_raise(/novšej verzie/) { c.cb.guard_newer_config!(inst) }
  # Ulozeny config TEJTO davky nesie novy marker.
  NxTest.assert_equal(cur, c.cfg_for(c.params)['config_schema'])
end

NxTest.test('D-128 (R1): panelove polia a whitelist normalizacie su TEN ISTY zoznam') do
  c = NxD128
  NxTest.assert_equal(c.cb::OVERRIDE_CONTENT_KEYS.sort,
                      c.panel.singleton_class::OVERRIDE_FIELDS.sort,
                      'panel by inak ulozil pole, ktore normalizacia zahodi')
  NxTest.assert(c.cb::OVERRIDE_CONTENT_KEYS.include?('box_height'))
end

NxTest.test('D-128: kod `box_lock_invalid` je v registri brany aj vo whitelist ceruzky') do
  c = NxD128
  NxTest.assert(c.r::CONFLICT_CODES.include?('box_lock_invalid'))
  NxTest.assert(c.r::DRAWER_BLOCKERS.include?('box_lock_invalid'))
  NxTest.assert(c.r::BUILD_BLOCKERS.include?('box_lock_invalid'), 'fail-closed konflikt STAVBY')
  NxTest.refute(c.r::ALL_EXPORT_BLOCKERS.include?('box_lock_invalid'))
  NxTest.assert(c.r::OVERRIDE_CONFLICT_CODES.include?('box_lock_invalid'),
                'napravou je RIADOK rucneho zasahu, takze ceruzka nan smie mierit')
  NxTest.assert(c.r::BLOCKER_LABELS['box_lock_invalid'].to_s.include?('výška boxu'))
end

# ============================================================================
# R5 — PAYLOAD OSI
# ============================================================================

NxTest.test('D-128 (R5): Quadro dostane os `box` v stave `auto` s rozsahom, Atira ju NEMA') do
  c = NxD128
  _cfg, axes = c.axes_for(c.params)
  a = axes[c::OWNER]
  NxTest.assert(a.is_a?(Hash), axes.inspect)
  NxTest.refute(a.key?('height'), 'Quadro vyskove varianty nema — pravidlo D2a plati dalej')
  box = a['box']
  NxTest.assert_equal('auto', box['state'])
  NxTest.assert_close(360.0, box['value'], 0.001, 'automat')
  NxTest.assert_close(58.0, box['min'], 0.001)
  NxTest.assert_close(360.0, box['max'], 0.001)
  NxTest.refute(box.key?('options'), 'spojity rozsah ziadnu ponuku nema')

  # Atira: kluc `box` NEEXISTUJE (payload je zhodny s tym pred D-128).
  atira = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
            'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }
  _c2, axes2 = c.axes_for(c.params.merge('fronts' => { 'items' => [atira] }))
  NxTest.refute(axes2[c::OWNER].key?('box'), 'Atira vysku boxu nepocita')
  NxTest.assert(axes2[c::OWNER].key?('height'))
end

NxTest.test('D-128 (R5): zamknuta os boxu ma `state: locked` a hodnotu zamku') do
  c = NxD128
  cfg, axes = c.axes_for(c.params, c.ov('box_height' => 300.0))
  box = axes[c::OWNER]['box']
  NxTest.assert_equal('locked', box['state'])
  NxTest.assert_close(300.0, box['value'], 0.001)
  NxTest.assert_close(360.0, box['max'], 0.001, 'automat sa priznava aj pri zamku')
  NxTest.assert_equal([], Array(cfg['drawer_conflicts']))
  NxTest.assert_equal(true, c.slide_item(cfg)['locked'], 'suhrn zahrna aj os boxu')
  # Polozka aj karta cela dostanu TEN ISTY stav.
  item = c.panel.attach_drawer_axes(cfg['hardware'], axes).find { |h| h['source'] == 'recipe' }
  NxTest.assert_equal(axes[c::OWNER], item['axes'])
end

NxTest.test('D-128 (R5): neplatny zamok = `conflict` + hlaska + navrh = AUTOMAT') do
  c = NxD128
  cfg, axes = c.axes_for(c.params, c.ov('box_height' => 500.0))
  box = axes[c::OWNER]['box']
  NxTest.assert_equal('conflict', box['state'])
  NxTest.assert_close(500.0, box['value'], 0.001)
  NxTest.assert_close(360.0, box['proposal'], 0.001, 'navrh je automat, nikdy nic ine')
  NxTest.assert(box['message'].to_s.include?('nad automatom'), box['message'].to_s)
  NxTest.assert_equal('box_lock_invalid', Array(cfg['drawer_conflicts']).first['code'])
  NxTest.assert_equal([], Array(cfg['hardware']).select { |h| h['source'] == 'recipe' },
                      'konflikt = ziadna polozka vysuvu')
end

NxTest.test('D-128 (R5): os v konflikte MA hlasku aj pri SKORSOM zlyhani resolvera') do
  c = NxD128
  # Prekazka (polica cez riadok) zlyha PRED zamkom, takze `drawer_conflicts`
  # o zamku nevie vobec — veta sa musi odvodit z receptu a kontextu.
  box = c.panel.drawer_box_axis(c.rec, c.ctx, c.ov('box_height' => 500.0),
                                { 'code' => 'drawer_obstruction', 'message' => 'polica' })
  NxTest.assert_equal('conflict', box['state'])
  NxTest.assert(box['message'].to_s.include?('nad automatom'), box['message'].to_s)
end

NxTest.test('D-128 (A6): prazdny rozsah nedava ani pole, ani navrh nahrady') do
  c = NxD128
  # Svetla vyska 90 -> max 50, min 58 (dno 16): zamknut sa neda NIC.
  low = c.ctx(clear_height: 90.0)
  box = c.panel.drawer_box_axis(c.rec, low, [], nil)
  NxTest.assert_equal('auto', box['state'])
  NxTest.assert_equal(nil, box['min'])
  NxTest.assert_equal(nil, box['max'])
  NxTest.assert_equal(nil, box['value'])
  NxTest.refute(box.key?('proposal'))

  locked = c.panel.drawer_box_axis(c.rec, low, c.ov('box_height' => 300.0), nil)
  NxTest.assert_equal('conflict', locked['state'])
  NxTest.assert_equal(nil, locked['proposal'], 'navrh, ktory sa nedá vyrobit, sa NEPONUKA')
end

# ============================================================================
# R6 — ZAPISOVA CESTA
# ============================================================================

NxTest.test('D-128 (R6): zapis v rozsahu prejde, nad automatom sa odmietne s rozsahom') do
  c = NxD128
  cfg = c.cfg_for(c.params)
  field, value, err = c.write_value(cfg, 'box_height', 300.0)
  NxTest.assert_equal(nil, err, err.to_s)
  NxTest.assert_equal('box_height', field)
  NxTest.assert_close(300.0, value, 0.001)

  _f, _v, bad = c.write_value(cfg, 'box_height', 400.0)
  NxTest.assert(bad.to_s.include?('58'), bad.to_s)
  NxTest.assert(bad.to_s.include?('360'), bad.to_s)
  NxTest.assert(bad.to_s.include?('automat'), bad.to_s)

  # Hranice INKLUZIVNE aj na zapisovej ceste. Meria sa na mriezke 0,1 mm —
  # jemnejsi rozdiel zapisova cesta zaokruhli (Codex #364 kolo 1 P2, test nizsie).
  NxTest.assert_equal(nil, c.write_value(cfg, 'box_height', 360.0)[2])
  NxTest.assert(c.write_value(cfg, 'box_height', 360.1)[2].to_s.length.positive?)
  NxTest.assert_equal(nil, c.write_value(cfg, 'box_height', 58.0)[2])
  NxTest.assert(c.write_value(cfg, 'box_height', 57.9)[2].to_s.length.positive?)
end

NxTest.test('D-128 (R6): zapis odmietne ATIRU, cudzi `generic_type` aj nereceptove pravidlo') do
  c = NxD128
  atira = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
            'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }
  acfg = c.cfg_for(c.params.merge('fronts' => { 'items' => [atira] }))
  _f, _v, err = c.write_value(acfg, 'box_height', 100.0, c::ARID)
  NxTest.assert(err.to_s.include?('výškové varianty'), err.to_s)

  cfg = c.cfg_for(c.params)
  _f2, _v2, gt_err = c.write_value(cfg, 'box_height', 300.0, c::RID, c::OWNER, 'hinge')
  NxTest.assert(gt_err.to_s.include?('položke výsuvu'), gt_err.to_s)

  _f3, _v3, rid_err = c.write_value(cfg, 'box_height', 300.0, 'vysuvy-nl-podla-hlbky')
  NxTest.assert(rid_err.to_s.include?('receptovej položke'), rid_err.to_s)
end

NxTest.test('D-128 (R6): tvar hodnoty je PRISNY — Infinity, 1e309 ani text neprejdu') do
  c = NxD128
  cfg = c.cfg_for(c.params)
  ['Infinity', '1e309', 'NaN', '300,5', '', 'abc', '-1'].each do |raw|
    _f, _v, err = c.write_value(cfg, 'box_height', raw)
    NxTest.assert(err.to_s.include?('Neplatná výška boxu'), "#{raw.inspect}: #{err.inspect}")
  end
  [Float::INFINITY, -Float::INFINITY, 0, -3.0].each do |raw|
    _f, _v, err = c.write_value(cfg, 'box_height', raw)
    NxTest.assert(err.to_s.include?('Neplatná výška boxu'), "#{raw.inspect}: #{err.inspect}")
  end
  # `1e309` ako JSON cislo je uz Infinity — musi padnut rovnako.
  NxTest.assert_equal(Float::INFINITY, JSON.parse('{"v":1e309}')['v'])
end

NxTest.test('D-128 (P3): hranice rozsahu lezia na mriezke 0,1 mm') do
  c = NxD128
  # Svetla 400,25 -> surovy automat 360,25. Zapis zaokruhluje na desatinu,
  # takze surova hranica by sa v paneli ukazala ako 360,3 — a tu by server
  # odmietol. `max` sa preto zaokruhluje NADOL, `min` NAHOR.
  rng = c.r.box_range(c.rec, 400.25, c.th(16.0))
  NxTest.assert_close(360.2, rng[:max], 0.0001, 'max NADOL na mriezku')
  NxTest.assert_close(58.0, rng[:min], 0.0001, 'min uz na mriezke lezi')
  # Dno 16,04 -> surove min 58,04 -> NAHOR na 58,1 (zapis 58,0 by resolver odmietol).
  NxTest.assert_close(58.1, c.r.box_range(c.rec, 400.0, c.th(16.04))[:min], 0.0001,
                      'min NAHOR na mriezku')
  # Presne na mriezke sa nic neposuva.
  NxTest.assert_close(360.0, c.r.box_range(c.rec, 400.0, c.th(16.0))[:max], 0.0001)
  NxTest.assert_close(360.1, c.r.box_range(c.rec, 400.1, c.th(16.0))[:max], 0.0001)

  # AUTOMAT (bez zamku) ostava PRESNY — zaokruhluje sa LEN rozsah zamku,
  # inak by sa mlcky zmenila geometria zakaziek bez zamku.
  auto = c.r.resolve(c.rec, c.ctx(clear_height: 400.25), c.th, [])
  NxTest.assert_close(360.25, auto[:box_height], 0.0001, 'automat sa NEZAOKRUHLUJE')

  # Obe hranice mriezky sa daju ZAMKNUT, o desatinu vyssie uz nie.
  ok_lock = c.r.resolve(c.rec, c.ctx(clear_height: 400.25), c.th, c.ov('box_height' => 360.2))
  NxTest.assert_equal([], c.codes(ok_lock))
  bad_lock = c.r.resolve(c.rec, c.ctx(clear_height: 400.25), c.th, c.ov('box_height' => 360.3))
  NxTest.assert_equal(['box_lock_invalid'], c.codes(bad_lock))
  NxTest.assert(bad_lock[:conflicts].first[:message].include?('360,2'),
                "hlaska menuje hranicu z mriezky: #{bad_lock[:conflicts].first[:message]}")
end

NxTest.test('D-128 (P2): zapis zaokruhli na 0,1 mm — panel ukazuje, co je ulozene') do
  c = NxD128
  cfg = c.cfg_for(c.params)
  # Panel formatuje vysku cez `hwNlFmt`: do 0,05 od celeho cisla ukaze CELE
  # cislo. Bez zaokruhlenia by zamok 300,04 znel „box 300", ale dielce by sa
  # rezali na 300,04 — UI a vyroba by sa rozisli.
  NxTest.assert_close(300.0, c.write_value(cfg, 'box_height', 300.04)[1], 0.0001,
                      '300,04 -> 300,0 (panel aj tak ukaze „box 300")')
  NxTest.assert_close(300.1, c.write_value(cfg, 'box_height', 300.06)[1], 0.0001,
                      '300,06 -> 300,1 (panel ukaze „box 300,1")')
  NxTest.assert_close(300.5, c.write_value(cfg, 'box_height', 300.5)[1], 0.0001,
                      'desatina sa NEZAHADZUJE')
  NxTest.assert_close(300.0, c.write_value(cfg, 'box_height', '300,04'.tr(',', '.'))[1], 0.0001,
                      'to iste pri textovom vstupe')
  # Rozsah sa overuje AZ PO zaokruhleni — hodnota tesne nad automatom, ktora
  # sa na automat zaokruhli, prejde a ulozi sa PRESNE automat.
  NxTest.assert_equal(nil, c.write_value(cfg, 'box_height', 360.04)[2])
  NxTest.assert_close(360.0, c.write_value(cfg, 'box_height', 360.04)[1], 0.0001)
  NxTest.assert(c.write_value(cfg, 'box_height', 360.06)[2].to_s.include?('58'),
                'a co sa zaokruhli NAD automat, to padne')
  # Zaokruhluje LEN zapis — normalizacia ulozeny tvar nemeni.
  NxTest.assert_close(300.04, c.cb.norm_hardware_overrides(c.ov('box_height' => 300.04))
                                 .first['box_height'], 0.0001,
                      'normalizacia je citac, nie druhy zaokruhlovac')
end

NxTest.test('D-128 (R6): odomknutie osi boxu necha NL zamok zit') do
  c = NxD128
  all = c.ov('box_height' => 300.0, 'nominal_length' => 400.0)
  out = c.panel.merge_override(all, c::OWNER, 'slide', c::RID, 'box_height', nil)
  NxTest.assert_equal(1, out.length, 'zaznam ostava — nesie este NL')
  NxTest.refute(out.first.key?('box_height'))
  NxTest.assert_close(400.0, out.first['nominal_length'], 0.001)

  # A naopak: odomknutie NL necha zamok boxu zit.
  out2 = c.panel.merge_override(all, c::OWNER, 'slide', c::RID, 'nominal_length', nil)
  NxTest.assert_close(300.0, out2.first['box_height'], 0.001)

  # Posledna os = zaznam zanikne.
  only = c.ov('box_height' => 300.0)
  NxTest.assert_equal([], c.panel.merge_override(only, c::OWNER, 'slide', c::RID, 'box_height', nil))
end

NxTest.test('D-128 (R6): hlaska statusu menuje OS, nie „kovanie"') do
  c = NxD128
  cab = c.cab_with(c.cfg_for(c.params))
  cab.set_attribute(c.e::Store::DICT, 'cabinet_id', 'CAB-1')
  NxTest.assert(c.panel.override_status_msg(cab, 'box_height', 300.0).include?('Výška boxu zamknutá na 300'),
                c.panel.override_status_msg(cab, 'box_height', 300.0))
  NxTest.assert(c.panel.override_status_msg(cab, 'box_height', nil).include?('Výška boxu odomknutá'),
                c.panel.override_status_msg(cab, 'box_height', nil))
end

NxTest.test('D-128 (A4): zapisova cesta cita SKUTOCNU hrubku dna (18 mm zdvihne minimum)') do
  c = NxD128
  # Test potrebuje KATALOGOVY 18 mm zaznam (`UNI_DOSKA_18`) — deklaruje si
  # preto stav sam (vzor `test_kovc2a_kanal_sety.rb`).
  NxTest.install_fresh_seed_catalog!
  over = { 'part_overrides' => { NxD128::BOTTOM_KEY => { 'material_id' => NxD128::SHEET18 } } }
  cfg18 = c.cfg_for(c.params(over: over))
  ctx = c.panel.drawer_axis_ctx(cfg18, c::OWNER)
  NxTest.assert_close(18.0, ctx[:part_thicknesses]['drawer_bottom'], 0.001,
                      'predpoklad testu: dno je naozaj 18 mm')

  cfg16 = c.cfg_for(c.params)
  NxTest.assert_equal(nil, c.write_value(cfg16, 'box_height', 59.0)[2], 'dno 16: min 58 -> 59 prejde')
  err = c.write_value(cfg18, 'box_height', 59.0)[2]
  NxTest.assert(err.to_s.include?('60'), "dno 18: min 60 -> 59 padne (#{err.inspect})")

  # A to iste vidi aj payload.
  _cfg, axes = c.axes_for(c.params(over: over))
  NxTest.assert_close(60.0, axes[c::OWNER]['box']['min'], 0.001)
end

# ============================================================================
# R4 — UPGRADE RECEPTU
# ============================================================================

NxTest.test('D-128 (R4): dopad prechodu pozna os `box` a vypise jej zamok') do
  c = NxD128
  sc = c.panel.singleton_class
  NxTest.assert_equal('box_height', sc::UPGRADE_LOCK_AXES['box'])
  NxTest.assert_equal([], sc::UPGRADE_LOCK_AXES.values - sc::OVERRIDE_FIELDS,
                      'hodnoty musia byt polia, ktore zapis naozaj pozna')
  locks = c.panel.drawer_upgrade_locks('box_height' => 300.0, 'nominal_length' => 400.0)
  NxTest.assert_equal([{ 'axis' => 'box', 'value' => 300.0, 'kept' => true },
                       { 'axis' => 'nl', 'value' => 400.0, 'kept' => true }], locks)
  NxTest.assert_equal([], c.panel.drawer_upgrade_locks({}), 'bez zamku sa nic nevypisuje')
end

# ============================================================================
# A7 — KARTA CELA
# ============================================================================

NxTest.test('D-128 (A7): karta pri AKTIVNOM zamku NETVRDI vzorec') do
  c = NxD128
  cfg = c.cfg_for(c.params, c.ov('box_height' => 300.0))
  params = c.slide_item(cfg)['params']
  _c2, axes = c.axes_for(c.params, c.ov('box_height' => 300.0))
  ax = axes[c::OWNER]

  plain = c.r.explain_stored(params)
  NxTest.assert(plain.any? { |l| l.include?('svetlá výška zóny − vôľa') },
                "bez `axes` ostava dnesna veta: #{plain.inspect}")
  locked = c.r.explain_stored(params, axes: ax)
  NxTest.assert(locked.any? { |l| l.include?('ručný zámok; automat by dal 360 mm') },
                locked.inspect)
  NxTest.refute(locked.any? { |l| l.include?('svetlá výška zóny − vôľa') },
                'vzorec by pri zamku KLAMAL')

  # Bez zamku sa veta NEMENI (charakterizacia).
  auto_cfg = c.cfg_for(c.params)
  auto_params = c.slide_item(auto_cfg)['params']
  _c3, auto_axes = c.axes_for(c.params)
  NxTest.assert_equal(c.r.explain_stored(auto_params),
                      c.r.explain_stored(auto_params, axes: auto_axes[c::OWNER]))
end

NxTest.test('D-128 (A7): veta „ručne zamknuté" MENUJE prave zamknute osi') do
  c = NxD128
  hw = { 'locked' => true }
  box = { 'box' => { 'state' => 'locked', 'value' => 300.0 },
          'nl' => { 'state' => 'auto', 'value' => 450.0 } }
  nl = { 'box' => { 'state' => 'auto', 'value' => 360.0 },
         'nl' => { 'state' => 'locked', 'value' => 400.0 } }
  both = { 'box' => { 'state' => 'locked', 'value' => 300.0 },
           'nl' => { 'state' => 'locked', 'value' => 400.0 } }
  height = { 'height' => { 'state' => 'locked', 'value' => 70 },
             'nl' => { 'state' => 'auto', 'value' => 470.0 } }
  none = { 'box' => { 'state' => 'auto', 'value' => 360.0 },
           'nl' => { 'state' => 'auto', 'value' => 450.0 } }

  NxTest.assert_equal('Ručne zamknuté: výška boxu (Inspector → Kovanie).', c.panel.locked_note(hw, box))
  NxTest.assert_equal('Ručne zamknuté: dĺžka výsuvu (Inspector → Kovanie).', c.panel.locked_note(hw, nl))
  NxTest.assert_equal('Ručne zamknuté: výška boxu · dĺžka výsuvu (Inspector → Kovanie).',
                      c.panel.locked_note(hw, both))
  NxTest.assert_equal('Ručne zamknuté: výška zásuvky (Inspector → Kovanie).',
                      c.panel.locked_note(hw, height))
  NxTest.assert_equal(nil, c.panel.locked_note({ 'locked' => nil }, none), 'bez zamku ZIADNA veta')
  NxTest.assert_equal(nil, c.panel.locked_note(hw, none),
                      'ked osi hovoria „nic nie je zamknute", veta sa NEVYMYSLA')
end

NxTest.test('D-128 (A7): riadok karty nesie vetu aj detail zo STAVU OSI') do
  c = NxD128
  cfg = c.cfg_for(c.params, c.ov('box_height' => 300.0))
  index = c.panel.drawer_axes_index(cfg, c.cb.config_to_params(cfg))
  row = c.panel.front_drawer_payload(cfg, index['by_owner'])['F1']
  NxTest.assert_equal('ok', row['state'])
  NxTest.assert(row['text'].include?('box 300 mm'), row['text'])
  NxTest.assert_equal('Ručne zamknuté: výška boxu (Inspector → Kovanie).', row['locked_note'])
  NxTest.assert(row['detail'].any? { |l| l.include?('ručný zámok; automat by dal 360 mm') },
                row['detail'].inspect)
end

# ============================================================================
# A1 / A5 — CHARAKTERIZACIA EXISTUJUCEHO SPRAVANIA
# ============================================================================

NxTest.test('D-128 (A1): sablona NENESIE ZIADNU os zamku (existujuci kontrakt)') do
  c = NxD128
  cfg = c.cfg_for(c.params, c.ov('box_height' => 300.0, 'nominal_length' => 400.0))
  NxTest.assert_equal(1, Array(cfg['hardware_overrides']).length, 'predpoklad: zamok v configu je')

  tc = c.panel.template_config_from(cfg, model: nil)
  NxTest.refute(tc.key?('hardware_overrides'),
                'sablona zamky neuklada — plati pre VSETKY tri osi rovnako')
  # Nove vlozenie zo sablony = ZIADNY zamok, teda automat.
  built = c.cfg_for(tc.merge('fronts' => cfg['fronts']))
  NxTest.assert_equal([], Array(built['hardware_overrides']))
  NxTest.assert_close(360.0, c.slide_item(built)['params']['box_height'], 0.001, 'automat')

  # Aplikacia sablony na EXISTUJUCU skrinku zamok CIELA nezhodi — sablona
  # kluc `hardware_overrides` vobec nenesie, takze ho nema cim prepisat.
  merged = c.cb.config_to_params(cfg).merge(tc)
  NxTest.assert_equal(1, Array(merged['hardware_overrides']).length)
end

NxTest.test('D-128 (A5): dormantny zamok po classic -> tipon (D-132, existujuca medzera)') do
  c = NxD128
  # Zamok patri receptu SiSy, ale celo je uz Tip-On -> pripnuty je P2O recept.
  cfg = c.cfg_for(c.params(opening: 'tipon'), c.ov('box_height' => 300.0))
  NxTest.assert_close(360.0, c.slide_item(cfg)['params']['box_height'], 0.001,
                      'novy recept stavia AUTOMAT — dormantny zamok sa nepouzije')
  NxTest.assert_equal(1, Array(cfg['hardware_overrides']).length, 'zaznam OSTAVA v configu')

  index = c.panel.drawer_axes_index(cfg, c.cb.config_to_params(cfg))
  rows = c.panel.attach_override_axes(cfg['hardware_overrides'], index)
  NxTest.refute(rows.first.key?('axes'),
                'dormantny zamok INEHO receptu chipy NEDOSTANE (pravidlo KOV-D4)')
end

NxTest.test('D-128: zakazka BEZ zamku sa sprava presne ako pred davkou') do
  c = NxD128
  cfg = c.cfg_for(c.params)
  item = c.slide_item(cfg)
  NxTest.assert_equal(nil, item['locked'], 'bez zamku ziadny suhrn')
  NxTest.assert_close(360.0, item['params']['box_height'], 0.001)
  NxTest.assert_equal([], Array(cfg['drawer_conflicts']))
  # Dielce: boky 450 x 360, celo/chrbat 818 x 332, dno 818 x 450.
  res = c.r.resolve(c.rec, c.ctx, c.th, [])
  NxTest.assert_close(360.0, c.part(res, 'box_side', 'left')[:height], 0.001)
  NxTest.assert_close(332.0, c.part(res, 'drawer_inner_front')[:height], 0.001)
  NxTest.assert_close(450.0, c.part(res, 'drawer_bottom')[:height], 0.001)
  NxTest.assert(res[:explain].any? { |x| x.include?('Výška boxu: 360 (svetlá 400 − vôľa 40)') },
                res[:explain].inspect)
end
