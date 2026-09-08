# frozen_string_literal: true
# Testy KOV-D2a: ZAMKY OSI — JADRO. Vyskovy zamok, poradie resolvera, receptova
# zapisovacia cesta, stav per os v payloade, schema 7.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 pole `height_variant` v `hardware_overrides` — LEN na receptovej identite
#      ATIRY, strict tvar; `CONFIG_SCHEMA` 6 -> 7, `DRAWER_ACTIVATION_SCHEMA` 5
#   R2 poradie resolvera: zamknuta/auto VYSKA -> rad NL TEJ vysky -> zamknuta/
#      auto NL -> dielce. Zamok sa NIKDY nemeni: zamknuta NL 520 po automatickom
#      prechode H70 -> H144 je `nl_lock_invalid`, nie navrat na H70
#   R3 receptova zapisovacia cesta (vlastnik -> pripnuty recept -> VYSLEDNA
#      vyska -> rad tej vysky), hodnoty z CERSTVEHO serveroveho stavu
#   R4 polozka OSTAVA `source: recipe`; payload nesie stav KAZDEJ osi
#      (auto | locked | conflict), Quadro BEZ `axes.height`
#   R5 nahrada meni LEN opravovanu os (druhy zamok ostava a znovu sa overi),
#      reset per os maze JEDNO pole
#   R6 charakterizacia — zakazka BEZ zamkov sa sprava presne ako pred davkou
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do core spadne uvedeny test):
#   M1 resolver pri neplatnej zamknutej NL vrati vysku o stupen nizsie
#      -> „KOV-D2a (R2): zamknuta NL mimo radu VYSLEDNEJ vysky = konflikt"
#   M2 receptovy zamok prejde `HardwareRules.apply_overrides`
#      -> „KOV-D2a (R4): polozka so zamkami OSTAVA `source: recipe`"
#   M3 reset osi zahodi CELY zaznam (dnesny orphan reset)
#      -> „KOV-D2a (R5): odomknutie jednej osi necha druhy zamok zit"
#   M4 zapisova cesta nedopocita AUTOMATICKU vysku, ked polozka chyba
#      -> „KOV-D2a (R3): navrh nahrady NL sa da ulozit AJ BEZ zamku vysky"
#   M5 legacy NL zaznam sa pri zapise osi NEkonsoliduje
#      -> „KOV-D2a (P1): legacy NL a novy vyskovy zamok su JEDEN zaznam"
#   M6 `apply_drawer_writes` premenuje legacy zaznam BEZ zlucenia
#      -> „KOV-D2a (P1): prestavba zluci premenovany legacy zamok s receptovym"
#   M7 zapisova cesta neoveri, ci sa vyska do svetlej vysky ZMESTI
#      -> „KOV-D2a (P2): vyskovy zamok, ktory sa uz nezmesti, sa ODMIETNE"
#   M8 `drawer_contexts` prehltne necakanu vynimku bez logu
#      -> „KOV-D2a (P2): necakana vynimka v kontexte osi sa ZALOGUJE"
#   M9 rescue nacitania receptu v payloade neloguje
#      -> „KOV-D2a (P2): nenacitatelny recept sa pri stavbe osi ZALOGUJE"
#   M10 hlaska osi sa berie LEN z ulozeneho `drawer_conflicts`
#      -> „KOV-D2a (P2): os v konflikte MA hlasku aj pri SKORSOM zlyhani"
#   M11 normalizacia neoveri `generic_type` vyskoveho zamku
#      -> „KOV-D2a (P2): vyskovy zamok zije LEN na polozke `slide`"
#   M12 zapisova akcia neoveri `generic_type` (ta ista os, druhy koniec)
#      -> „KOV-D2a (P2): vyskovy zamok zije LEN na polozke `slide`"
require_relative '../helper' unless defined?(NxTest)

# Panelove akcie nie su v require zozname helpera (vzor KOV-D1a).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxD2a
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

  def rec(id = 'atira_sisy_v1')
    r.load(id)
  end

  OWNER = 'front:F1/panel'
  RID   = 'recipe:atira_sisy_v1'

  def ctx(clear_height: 175.0, clear_depth: 497.0, clear_width: 864.0,
          side_thickness: 18.0, obstructions: [], owner: OWNER)
    { clear_width: clear_width, clear_height: clear_height, clear_depth: clear_depth,
      side_thickness: side_thickness, obstructions: obstructions, owner_part_key: owner }
  end

  def th
    { 'drawer_bottom' => 16.0, 'drawer_back' => 16.0 }
  end

  def th_quadro
    { 'drawer_bottom' => 16.0, 'box_side' => 16.0,
      'drawer_inner_front' => 16.0, 'drawer_back' => 16.0 }
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

  # --- fixtury pre PAYLOAD a ZAPISOVU cestu --------------------------------
  #
  # Zakazka: spodna skrinka 900x720x500, jedno zasuvkove celo F1 (metal +
  # classic = Atira SiSy). Rovnaka ako in-SU `kovc2b_params`, takze cisla
  # (H70, NL 470) sedia s tym, co Michal vidi v plugine.
  def params(front_height: 175.0, cabinet_height: 720.0, depth: 500.0, front: {})
    item = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
             'height' => front_height, 'opening_mode' => 'classic',
             'drawer' => { 'construction' => 'metal' } }.merge(front)
    { 'type' => 'lower', 'width' => 900.0, 'height' => cabinet_height, 'depth' => depth,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'fronts' => { 'items' => [item] } }
  end

  # ULOZENY config skrinky presne tak, ako ho po stavbe vidi panel: ide cez
  # tie iste dve funkcie ako realny zapis (`merge_final` -> `cabinet_config`)
  # a JSON round-trip z neho spravi string-keyed hash ako `Store.config`.
  # Musi byt PLNY (rozmery, cela, hrubky) — zapisova cesta zamku z neho
  # prepocitava svetle rozmery, takze orezany fixture by merala inu skrinku.
  def cfg_for(par, overrides = [])
    norm = cb.normalize(par.merge('hardware_overrides' => overrides))
    plan = e::Construction.build_plan(norm, 'CAB-1',
                                      part_thicknesses: cb.drawer_thicknesses(norm, {}))
    JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(norm, plan))))
  end

  def axes_for(par, overrides = [])
    cfg = cfg_for(par, overrides)
    [cfg, panel.drawer_axes_map(cfg, cb.config_to_params(cfg))]
  end

  # KOV-D4: `attach_override_axes` uz berie CELY index (`by_owner` + `idents`) —
  # osiroteny zaznam dostane chipy len ked patri PRIPNUTEMU receptu.
  def index_for(par, overrides = [])
    cfg = cfg_for(par, overrides)
    [cfg, panel.drawer_axes_index(cfg, cb.config_to_params(cfg))]
  end

  def slide_item(cfg)
    Array(cfg['hardware']).find { |h| h['source'].to_s == 'recipe' }
  end

  # Fake skrinka s ULOZENYM configom — zapisova cesta cita VYHRADNE jeho.
  def cab_with(cfg)
    inst = NxTest::FakeEntity.new
    inst.set_attribute(e::Store::DICT, 'config', JSON.generate(cfg))
    inst
  end

  def write_value(cfg, field, raw, rid = RID, owner = OWNER)
    panel.override_value(field, raw, nil, cab_with(cfg), owner, 'slide', rid)
  end
end

# ============================================================================
# R2 — PORADIE RESOLVERA (vyska -> rad NL tej vysky -> NL)
# ============================================================================

NxTest.test('KOV-D2a (R2): zamknuta NL mimo radu VYSLEDNEJ vysky = konflikt (nikdy navrat na nizsiu vysku)') do
  c = NxD2a
  # Svetla vyska 200 -> automat H144 (min 189). Rad H144 je 350/420/470;
  # NL 520 v nom NIE JE, hoci v rade H70 by bola. Fail-closed: zasuvka sa
  # NEVRACIA na H70 a NL sa nemeni.
  res = c.r.resolve(c.rec, c.ctx(clear_height: 200.0, clear_depth: 560.0), c.th,
                    c.ov('nominal_length' => 520.0))
  c.assert_fail_closed(res, 'nl_lock_invalid')
  NxTest.assert(res[:conflicts].first[:message].include?('H144'),
                "hlaska menuje rad VYSLEDNEJ vysky: #{res[:conflicts].first[:message]}")
end

NxTest.test('KOV-D2a (R2): zamknuta vyska DRZI aj ked by automat vybral vyssi variant') do
  c = NxD2a
  # Svetla vyska 230 by dala H176; zamok H70 ju musi udrzat — dielce aj
  # parametre polozky (kit) su potom H70.
  res = c.r.resolve(c.rec, c.ctx(clear_height: 230.0, clear_depth: 560.0), c.th,
                    c.ov('height_variant' => 70))
  NxTest.assert_equal([], c.codes(res))
  NxTest.assert_equal(70, res[:height_variant])
  NxTest.assert_equal(70, res[:hardware_params]['height_variant'], 'kit sa objednava na H70')
  back = res[:parts].find { |p| p[:role] == 'drawer_back' }
  NxTest.assert_close(65.5, back[:height], 0.001, 'chrbat je z varianta H70')
  NxTest.assert(res[:explain].any? { |x| x.include?('Výška: H70 (ručný zámok)') },
                res[:explain].inspect)
end

NxTest.test('KOV-D2a (R2): zamknuta vyska MIMO receptu = height_lock_invalid bez dielcov') do
  c = NxD2a
  res = c.r.resolve(c.rec, c.ctx(clear_height: 230.0, clear_depth: 560.0), c.th,
                    c.ov('height_variant' => 100))
  c.assert_fail_closed(res, 'height_lock_invalid')
  NxTest.assert(res[:conflicts].first[:message].include?('neexistuje'),
                res[:conflicts].first[:message])
end

NxTest.test('KOV-D2a (R2): zamknuta vyska, ktora sa NEZMESTI = height_lock_invalid') do
  c = NxD2a
  # H176 potrebuje svetlu vysku 221; je 200 -> RED, nikdy tichy pad na H144.
  res = c.r.resolve(c.rec, c.ctx(clear_height: 200.0, clear_depth: 560.0), c.th,
                    c.ov('height_variant' => 176))
  c.assert_fail_closed(res, 'height_lock_invalid')
  NxTest.assert(res[:conflicts].first[:message].include?('221'),
                res[:conflicts].first[:message])
end

NxTest.test('KOV-D2a (R2): rad NL sa berie z radu ZAMKNUTEJ vysky') do
  c = NxD2a
  # H70 + NL 520: v rade H70 520 JE, takze plati; pri automate (H176) by
  # rad tiez 520 mal, preto sa druhy pripad meria na H144.
  ok = c.r.resolve(c.rec, c.ctx(clear_height: 230.0, clear_depth: 560.0), c.th,
                   c.ov('height_variant' => 70, 'nominal_length' => 520.0))
  NxTest.assert_equal([], c.codes(ok))
  NxTest.assert_close(520.0, ok[:nl], 0.001)

  bad = c.r.resolve(c.rec, c.ctx(clear_height: 230.0, clear_depth: 560.0), c.th,
                    c.ov('height_variant' => 144, 'nominal_length' => 520.0))
  c.assert_fail_closed(bad, 'nl_lock_invalid')
end

NxTest.test('KOV-D2a (R2): vyskovy zamok plati LEN na receptovej identite a LEN bez `disabled`') do
  c = NxD2a
  base = c.ctx(clear_height: 230.0, clear_depth: 560.0)
  legacy = c.r.resolve(c.rec, base, c.th,
                       c.ov({ 'height_variant' => 70 }, 'vysuvy-nl-podla-hlbky'))
  NxTest.assert_equal(176, legacy[:height_variant], 'legacy pravidlo vysku nikdy nedrzalo')

  off = c.r.resolve(c.rec, base, c.th, c.ov('height_variant' => 70, 'disabled' => true))
  NxTest.assert_equal(176, off[:height_variant], 'vypnuty zaznam zamok nenesie')

  other = c.r.resolve(c.rec, base, c.th, c.ov({ 'height_variant' => 70 }, c::RID, 'front:F2/panel'))
  NxTest.assert_equal(176, other[:height_variant], 'zamok ineho cela sa ignoruje')
end

NxTest.test('KOV-D2a (R2): Quadro vyskovy zamok NEMA — pole sa ignoruje') do
  c = NxD2a
  q = c.rec('quadro_v6_sisy_v1')
  res = c.r.resolve(q, c.ctx(clear_height: 175.0, clear_depth: 497.0), c.th_quadro,
                    c.ov({ 'height_variant' => 70 }, 'recipe:quadro_v6_sisy_v1'))
  NxTest.assert_equal([], c.codes(res))
  NxTest.assert_equal(nil, res[:height_variant], 'Quadro vyskovy variant nema')
  NxTest.assert(res[:box_height].is_a?(Float), 'vyska boxu plynie z geometrie')
  NxTest.assert_equal(nil, c.r.height_lock_value(q, c.ctx, c.ov({ 'height_variant' => 70 },
                                                                'recipe:quadro_v6_sisy_v1')))
end

NxTest.test('KOV-D2a (R2): `height_lock_invalid` je REGISTROVANY blocker stavby') do
  c = NxD2a
  NxTest.assert(c.r::CONFLICT_CODES.include?('height_lock_invalid'))
  NxTest.assert(c.r::BUILD_BLOCKERS.include?('height_lock_invalid'),
                'RED bez dielcov = blokuje CSV, rozpocet aj ponuku')
  NxTest.refute(c.r::ALL_EXPORT_BLOCKERS.include?('height_lock_invalid'),
                'geometria sa nevydala, VEPO chrani prave to')
  NxTest.assert(c.r::BLOCKER_LABELS['height_lock_invalid'].to_s.length > 5,
                'brana musi mat slovensky nazov')
end

# ============================================================================
# R1 — POLE `height_variant` V CONFIGU + SCHEMA 7
# ============================================================================

NxTest.test('KOV-D2a (R1): `height_variant` prezije normalizaciu LEN na receptovej ATIRE') do
  c = NxD2a
  keep = c.cb.norm_hardware_overrides(c.ov('height_variant' => 144))
  NxTest.assert_equal(144, keep.first['height_variant'])

  [['recipe:quadro_v6_sisy_v1', 'Quadro vyskove varianty nema'],
   ['vysuvy-nl-podla-hlbky', 'legacy pravidlo vysku nedrzi'],
   ['recipe:vymysleny_v1', 'neparsovatelny recept']].each do |rid, why|
    out = c.cb.norm_hardware_overrides(c.ov({ 'height_variant' => 144, 'quantity' => 1 }, rid))
    NxTest.refute(out.first.key?('height_variant'), why)
  end
end

NxTest.test('KOV-D2a (R1): tvar hodnoty je STRICT (kladne cele cislo)') do
  c = NxD2a
  ['144', 144.5, -70, 0, nil, true].each do |bad|
    out = c.cb.norm_hardware_overrides(c.ov('height_variant' => bad, 'quantity' => 1))
    NxTest.refute(out.first.key?('height_variant'), "#{bad.inspect} nie je vyskovy zamok")
  end
  NxTest.assert_equal(144, c.cb.norm_hardware_overrides(c.ov('height_variant' => 144.0))
                             .first['height_variant'], 'cely Float je platna vyska')
end

NxTest.test('KOV-D2a (R1): zaznam LEN s vyskovym zamkom je OBSAZNY (neprepadne)') do
  c = NxD2a
  NxTest.assert_equal(1, c.cb.norm_hardware_overrides(c.ov('height_variant' => 70)).length)
  NxTest.assert_equal(0, c.cb.norm_hardware_overrides(c.ov('note' => 'x')).length,
                      'zaznam bez obsahoveho pola zanika')
end

NxTest.test('KOV-D2a (R1): panelove polia a whitelist normalizacie su TEN ISTY zoznam') do
  c = NxD2a
  # `OVERRIDE_FIELDS` zije v `class << self` panela — cez singleton triedu.
  NxTest.assert_equal(c.cb::OVERRIDE_CONTENT_KEYS.sort,
                      c.panel.singleton_class::OVERRIDE_FIELDS.sort,
                      'panel by inak ulozil pole, ktore normalizacia zahodi')
end

NxTest.test('KOV-D2a (R1): vyskovy zamok potrebuje ASPON schemu 7, aktivacia zasuviek ostava 5') do
  c = NxD2a
  # PRESNE cislo `CONFIG_SCHEMA` strazi VZDY najnovsia davka, ktora ho zdvihla
  # (dnes KOV-F1 = 9); tu sa strazi to, co si vyziadala D2a — vyskovy zamok
  # potrebuje aspon 7 a `DRAWER_ACTIVATION_SCHEMA` sa s bumpom nehybe.
  NxTest.assert(c.cb::CONFIG_SCHEMA >= 7, 'vyskovy zamok zaviedol schemu 7')
  NxTest.assert_equal(5, c.cb::DRAWER_ACTIVATION_SCHEMA)
  # Downgrade: plugin odmietne PRESTAVBU configu NOVSEJ schemy; vlastna
  # a starsie prejdu. Vyskovy zamok sa NIKDY ticho neoreze.
  cur = c.cb::CONFIG_SCHEMA
  NxTest.refute(c.cb.newer_config?('config_schema' => cur))
  NxTest.refute(c.cb.newer_config?('config_schema' => 6))
  NxTest.assert(c.cb.newer_config?('config_schema' => cur + 1))
  inst = NxTest::FakeEntity.new
  inst.set_attribute(c.e::Store::DICT, 'config', JSON.generate('config_schema' => cur + 1))
  NxTest.assert_raise(/novšej verzie/) { c.cb.guard_newer_config!(inst) }
end

NxTest.test('KOV-D2a (R1): prestavba zapise AKTUALNU schemu aj bez zamku') do
  c = NxD2a
  cfg = c.cb.normalize(c.params)
  NxTest.assert_equal(c.cb::CONFIG_SCHEMA, c.cb.cabinet_config(cfg)[:config_schema])
end

# ============================================================================
# R3 — RECEPTOVA ZAPISOVACIA CESTA
# ============================================================================

NxTest.test('KOV-D2a (R3): NL zamok zasuvky sa UZ DA ulozit (rad pripnuteho receptu)') do
  c = NxD2a
  cfg = c.cfg_for(c.params)
  NxTest.assert_equal(70, c.slide_item(cfg)['params']['height_variant'], 'predpoklad: H70')

  field, value, err = c.write_value(cfg, 'nominal_length', 420.0)
  NxTest.assert_equal(nil, err, err.to_s)
  NxTest.assert_equal(['nominal_length', 420.0], [field, value])
end

NxTest.test('KOV-D2a (R3): NL mimo radu VYSLEDNEJ vysky sa odmietne s hlaskou') do
  c = NxD2a
  cfg = c.cfg_for(c.params)
  _f, _v, err = c.write_value(cfg, 'nominal_length', 620.0)
  NxTest.assert(err.to_s.include?('rade H70'), err.to_s)
end

NxTest.test('KOV-D2a (R3): rad sa berie z CERSTVEHO stavu — zamknuta vyska prebija params polozky') do
  c = NxD2a
  # Skrinka, ktorej automat da H144 (rad 350/420/470 — 520 v nom NIE JE).
  par = c.params(front_height: 220.0, cabinet_height: 900.0)
  cfg = c.cfg_for(par)
  NxTest.assert_equal(144, c.slide_item(cfg)['params']['height_variant'].to_i, 'predpoklad: H144')
  _f, _v, err = c.write_value(cfg, 'nominal_length', 520.0)
  NxTest.assert(err.to_s.include?('rade H144'), "bez zamku plati rad automatu: #{err}")

  # ULOZENY zamok H70 (platny — H70 sa do svetlej vysky zmesti) MUSI prebit
  # `params` polozky, ktora este nesie H144 z predoslej stavby: rad H70 ma 520.
  cfg['hardware_overrides'] = c.cb.norm_hardware_overrides(c.ov('height_variant' => 70))
  field, value, ok_err = c.write_value(cfg, 'nominal_length', 520.0)
  NxTest.assert_equal(nil, ok_err, "rad musi plynut zo ZAMKNUTEJ vysky: #{ok_err}")
  NxTest.assert_equal(['nominal_length', 520.0], [field, value])
end

NxTest.test('KOV-D2a (R3): vyskovy zamok prijme LEN vysku pripnuteho receptu') do
  c = NxD2a
  # Skrinka, v ktorej sa H144 este zmesti (svetla 204) — tento test meria
  # ZOZNAM receptu, nie geometriu (tu meria test „uz sa nezmesti" nizsie).
  cfg = c.cfg_for(c.params(front_height: 220.0, cabinet_height: 900.0))
  field, value, err = c.write_value(cfg, 'height_variant', 144)
  NxTest.assert_equal(nil, err, err.to_s)
  NxTest.assert_equal(['height_variant', 144], [field, value])

  _f, _v, bad = c.write_value(cfg, 'height_variant', 100)
  NxTest.assert(bad.to_s.include?('H70'), bad.to_s)
end

NxTest.test('KOV-D2a (R3): Quadro vyskovy zamok NEPRIJME (hlaska, nie tichy zapis)') do
  c = NxD2a
  par = c.params(front: { 'drawer' => { 'construction' => 'wood' } })
  cfg = c.cfg_for(par)
  _f, _v, err = c.panel.override_value('height_variant', 70, nil, c.cab_with(cfg),
                                       c::OWNER, 'slide', 'recipe:quadro_v6_sisy_v1')
  NxTest.assert(err.to_s.include?('výškové varianty nemá'), err.to_s)
end

NxTest.test('KOV-D2a (R3): zamok k INEJ verzii receptu, nez je pripnuta, sa odmietne') do
  c = NxD2a
  cfg = c.cfg_for(c.params)
  _f, _v, err = c.write_value(cfg, 'nominal_length', 420.0, 'recipe:atira_p2o_v1')
  NxTest.assert(err.to_s.include?('medzitým'), err.to_s)
end

NxTest.test('KOV-D2a (R3): projektove `fit_series` pravidla ostavaju pre NE-receptove polozky') do
  c = NxD2a
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware.rb'),
                  encoding: 'UTF-8')
  NxTest.assert(src.include?('unless series_value?(model, rid, gt, nl)'),
                'legacy vetva D-93 musi ostat')
  NxTest.assert(src.include?('return recipe_nl_value(cab, owner, gt, rid, nl) if recipe_rule?(rid)'),
                'receptova vetva stoji PRED nou')
end

# ============================================================================
# R4 — STAV PER OS V PAYLOADE
# ============================================================================

NxTest.test('KOV-D2a (R4): payload nesie obe osi so stavom `auto` a ponukou') do
  c = NxD2a
  cfg, axes = c.axes_for(c.params)
  a = axes[c::OWNER]
  NxTest.assert(a.is_a?(Hash), axes.inspect)
  NxTest.assert_equal('auto', a['height']['state'])
  NxTest.assert_equal(70, a['height']['value'])
  NxTest.assert_equal([70], a['height']['options'], 'do svetlej vysky 175 sa zmesti len H70')
  NxTest.assert_equal('auto', a['nl']['state'])
  NxTest.assert_close(470.0, a['nl']['value'], 0.001)
  NxTest.assert_equal([350.0, 420.0, 470.0], a['nl']['options'])
  # Polozka aj osiroteny riadok dostanu TEN ISTY stav.
  item = c.panel.attach_drawer_axes(cfg['hardware'], axes).find { |h| h['source'] == 'recipe' }
  NxTest.assert_equal(a, item['axes'])
end

NxTest.test('KOV-D2a (R4): Quadro NEMA kluc `axes.height` (nie `state: auto`)') do
  c = NxD2a
  _cfg, axes = c.axes_for(c.params(front: { 'drawer' => { 'construction' => 'wood' } }))
  a = axes[c::OWNER]
  NxTest.refute(a.key?('height'), 'os, ktora neexistuje, sa neponuka ani ako automat')
  NxTest.assert_equal('auto', a['nl']['state'])
end

NxTest.test('KOV-D2a (R4): zamknuta os ma `state: locked`, konfliktna `conflict` + hlasku z `drawer_conflicts`') do
  c = NxD2a
  ok_cfg, ok_axes = c.axes_for(c.params, c.ov('height_variant' => 70))
  NxTest.assert_equal('locked', ok_axes[c::OWNER]['height']['state'])
  NxTest.assert_equal([], Array(ok_cfg['drawer_conflicts']))

  bad_cfg, bad_axes = c.axes_for(c.params, c.ov('height_variant' => 176))
  h = bad_axes[c::OWNER]['height']
  NxTest.assert_equal('conflict', h['state'])
  NxTest.assert_equal(176, h['value'])
  NxTest.assert_equal(Array(bad_cfg['drawer_conflicts']).first['message'], h['message'],
                      'hlaska osi = ULOZENY dovod, nikdy druhy text')
  # Pri konflikte VYSKY sa NL nema z coho pocitat — ponuka je prazdna a riadok
  # to PRIZNA (nikdy nehada rad).
  NxTest.assert_equal([], bad_axes[c::OWNER]['nl']['options'])
  NxTest.assert_equal('height', bad_axes[c::OWNER]['nl']['blocked_by'])
end

NxTest.test('KOV-D2a (R4): konfliktna zasuvka nevydá polozku — stav osi nesie OSIROTENY riadok') do
  c = NxD2a
  overrides = c.ov('height_variant' => 176)
  cfg, index = c.index_for(c.params, overrides)
  NxTest.assert_equal(nil, c.slide_item(cfg), 'fail-closed: polozka vysuvu nevznikla')
  rows = c.panel.attach_override_axes(cfg['hardware_overrides'], index)
  NxTest.assert_equal('conflict', rows.first['axes']['height']['state'],
                      'bez toho by sa konfliktna zasuvka nedala odomknut')
end

NxTest.test('KOV-D2a (R4): polozka so zamkami OSTAVA `source: recipe` a nesie suhrn `locked`') do
  c = NxD2a
  cfg = c.cfg_for(c.params, c.ov('height_variant' => 70, 'nominal_length' => 470.0))
  it = c.slide_item(cfg)
  NxTest.assert_equal('recipe', it['source'],
                      'zamok NIKDY nesmie prejst `apply_overrides` (prepol by zdroj na manual)')
  NxTest.assert_equal(true, it['locked'], '`locked` = aspon jedna os je zamknuta')
  NxTest.refute(it.key?('rule_nominal_length'), 'receptova polozka nema hodnotu automatu z pravidla')
end

# ============================================================================
# R5 — NAHRADA A RESET PER OS
# ============================================================================

NxTest.test('KOV-D2a (R5): navrh nahrady NL = najdlhsia z radu VYSLEDNEJ vysky') do
  c = NxD2a
  # Zamknuta vyska H70 + NL 620 (v ziadnom rade H70 nie je) -> navrh 470
  # (najdlhsia, ktora sa zmesti do svetlej hlbky tejto skrinky).
  _cfg, axes = c.axes_for(c.params, c.ov('height_variant' => 70, 'nominal_length' => 620.0))
  nl = axes[c::OWNER]['nl']
  NxTest.assert_equal('conflict', nl['state'])
  NxTest.assert_close(470.0, nl['proposal'], 0.001)
  NxTest.assert_equal('locked', axes[c::OWNER]['height']['state'], 'druhy zamok ostava')
end

NxTest.test('KOV-D2a (R5): navrh VYSKY respektuje DRUHY zamok, inak je `nil`') do
  c = NxD2a
  r = c.r
  recipe = c.rec
  # Svetla vyska 230 (H70/H144/H176 sa zmestia), hlbka 560.
  opts = r.height_options(recipe, 230.0)
  NxTest.assert_equal([70, 144, 176], opts)
  # Bez druheho zamku: najvyssia, ktora ma pouzitelnu NL -> H176.
  NxTest.assert_equal(176, c.panel.height_proposal(recipe, opts, nil, 560.0))
  # So zamknutou NL 520: H144 ju v rade nema, H176 ano -> H176.
  NxTest.assert_equal(176, c.panel.height_proposal(recipe, opts, 520.0, 560.0))
  # So zamknutou NL 620: v rade ju ma len H176, ale potrebuje hlbku 635 ->
  # ziadna platna nahrada, potvrdenie sa neponukne.
  NxTest.assert_equal(nil, c.panel.height_proposal(recipe, opts, 620.0, 560.0))
end

NxTest.test('KOV-D2a (R5): odomknutie jednej osi necha druhy zamok zit') do
  c = NxD2a
  all = c.ov('height_variant' => 144, 'nominal_length' => 470.0)
  # `value: null` = odomknut JEDNU os (dnesny orphan reset by zahodil CELY zaznam).
  out = c.panel.merge_override(all, c::OWNER, 'slide', c::RID, 'height_variant', nil)
  NxTest.assert_equal(1, out.length)
  NxTest.refute(out.first.key?('height_variant'), 'odomknuta os zmizla')
  NxTest.assert_close(470.0, out.first['nominal_length'], 0.001, 'druhy zamok prezil')

  # Odomknutie OBOCH osi = zaznam zanikne (prazdny sa neuklada).
  empty = c.panel.merge_override(out, c::OWNER, 'slide', c::RID, 'nominal_length', nil)
  NxTest.assert_equal([], empty)
end

NxTest.test('KOV-D2a (R5): reset CELEHO zaznamu ostava pre `disabled` / `quantity`') do
  c = NxD2a
  all = c.ov('height_variant' => 144, 'disabled' => true)
  NxTest.assert_equal([], c.panel.merge_override(all, c::OWNER, 'slide', c::RID, :all, nil))
end

# ============================================================================
# R6 — CHARAKTERIZACIA (zakazka BEZ zamkov sa nezmenila)
# ============================================================================

NxTest.test('KOV-D2a (R6): zakazka BEZ zamkov dava tie iste dielce, polozku aj explain') do
  c = NxD2a
  res = c.r.resolve(c.rec, c.ctx, c.th)
  NxTest.assert_equal([], c.codes(res))
  NxTest.assert_equal(70, res[:height_variant])
  NxTest.assert_close(470.0, res[:nl], 0.001)
  NxTest.assert_equal(2, res[:parts].length)
  NxTest.assert(res[:explain].any? { |x| x.start_with?('Výška: H70 (svetlá') }, res[:explain].inspect)
  NxTest.assert(res[:explain].any? { |x| x.start_with?('NL: 470 (rad H70') }, res[:explain].inspect)

  cfg = c.cfg_for(c.params)
  it = c.slide_item(cfg)
  NxTest.assert_equal('recipe:atira_sisy_v1', it['rule_id'])
  NxTest.assert_equal(1, it['quantity'])
  NxTest.refute(it.key?('locked'), 'bez zamku polozka znamienko NEMA')
  NxTest.assert_equal([], Array(cfg['drawer_conflicts']))
end

NxTest.test('KOV-D2a (R6): zakazka BEZ zasuviek si payload osi vobec nepyta') do
  c = NxD2a
  par = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
          'thickness' => 18.0, 'floor_height' => 100.0 }
  NxTest.assert_equal({}, c.cb.drawer_axis_contexts(par))
  NxTest.assert_equal({}, c.panel.drawer_axes_map({}, par))
end

# ============================================================================
# PREDPOKLAD IN-SU SCENARA (`run_kovd2a`)
# ============================================================================

NxTest.test('KOV-D2a: geometria in-SU scenara DETERMINISTICKY dava automat H144 a ponuku H70') do
  c = NxD2a
  # Prve znenie in-SU scenara stavilo na celo 250 mm — svetla vyska vysla 234
  # a automat vybral H176, takze sa CELY scenar preskocil a nedokazal nic.
  # Tento test drzi jeho predpoklad V CI: skrinka 900 / celo 220 musi dat
  # svetlu vysku BEZPECNE v pasme H144 (189 az 221) a server musi ponuknut aj
  # inu platnu vysku, na ktoru sa da zamok ukazat.
  par = c.params(front_height: 220.0, cabinet_height: 900.0)
  ctx = c.cb.drawer_axis_contexts(par)['F1']
  NxTest.assert_close(204.0, ctx[:clear_height], 0.001, 'svetla vyska riadku cela')
  NxTest.assert(ctx[:clear_height] > 189.0 + 10.0 && ctx[:clear_height] < 221.0 - 10.0,
                'rezerva aspon 10 mm na obe strany pasma H144')

  cfg, axes = c.axes_for(par)
  NxTest.assert_equal(144, c.slide_item(cfg)['params']['height_variant'].to_i, 'automat = H144')
  NxTest.assert_equal([70, 144], axes[c::OWNER]['height']['options'],
                      'server ponuka aj H70 — na nu scenar zamyka')
end

NxTest.test('KOV-D2a: in-SU sekcia `run_kovd2a` stoji na TEJ ISTEJ geometrii a NEpreskakuje sa') do
  src = File.read(File.join(NxTest::ROOT, 'tests', 'sketchup', 'su_runner.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?('KOVD2A_FRONT_H = 220.0'), 'in-SU celo musi ostat 220 mm')
  NxTest.assert(src.include?('KOVD2A_AUTO_H  = 144'), 'in-SU ocakava automat H144')
  section = src[/def run_kovd2a\(model\)[\s\S]*?\n  end\n/].to_s
  NxTest.refute(section.empty?, 'sekcia `run_kovd2a` musi existovat')
  NxTest.refute(section.include?('scenar preskoceny'),
                'nesulad predpokladu musi byt FAIL, nikdy tiche preskocenie')
  NxTest.assert(src.include?('run_kovd2a(model)        #'), 'sekcia musi byt zaradena do behu')
end

# ============================================================================
# R3 — CODEX #312 KOLO 1 P2: nahrada NL bez zamku vysky
# ============================================================================

NxTest.test('KOV-D2a (R3): navrh nahrady NL sa da ulozit AJ BEZ zamku vysky') do
  c = NxD2a
  # Hlbka 400 -> svetla 397: z radu H70 sa zmesti UZ LEN 350 (420 potrebuje 435).
  # Zamknuta 470 tak prestane platit a zasuvka je fail-closed — polozka vysuvu
  # NEVZNIKNE. Vyska je pritom stale urcitelna (automat H70), takze serverom
  # navrhnuta nahrada 350 MUSI prejst; inak by pouzivatel musel zbytocne
  # zamknut vysku, len aby smel opravit dlzku.
  par = c.params(depth: 400.0)
  cfg, axes = c.axes_for(par, c.ov('nominal_length' => 470.0))
  NxTest.assert_equal(nil, c.slide_item(cfg), 'predpoklad: polozka vysuvu nevznikla')
  NxTest.assert_equal(['nl_lock_invalid'],
                      Array(cfg['drawer_conflicts']).map { |x| x['code'].to_s })
  a = axes[c::OWNER]
  NxTest.assert_equal('auto', a['height']['state'], 'vyska je AUTOMATICKA, nie zamknuta')
  NxTest.assert_equal(70, a['height']['value'])
  NxTest.assert_equal('conflict', a['nl']['state'])
  NxTest.assert_equal([350.0], a['nl']['options'])
  NxTest.assert_close(350.0, a['nl']['proposal'], 0.001)

  field, value, err = c.write_value(cfg, 'nominal_length', a['nl']['proposal'])
  NxTest.assert_equal(nil, err, "zapis vlastneho navrhu servera musi prejst: #{err}")
  NxTest.assert_equal(['nominal_length', 350.0], [field, value])

  # Vysledok zapisu: NL 350 zamknuta, vyska OSTAVA automaticka (zaznam nema
  # pole `height_variant`) a zasuvka sa postavi.
  after = c.panel.merge_override(cfg['hardware_overrides'], c::OWNER, 'slide', c::RID,
                                 field, value)
  cfg2, axes2 = c.axes_for(par, after)
  NxTest.assert_close(350.0, c.slide_item(cfg2)['params']['nominal_length'], 0.001)
  NxTest.assert_equal([], Array(cfg2['drawer_conflicts']))
  NxTest.assert_equal('locked', axes2[c::OWNER]['nl']['state'])
  NxTest.assert_equal('auto', axes2[c::OWNER]['height']['state'])
  NxTest.refute(after.first.key?('height_variant'), 'vyska ostala automaticka')
end

NxTest.test('KOV-D2a (R3): pri KONFLIKTE vysky ostava nahrada NL odmietnuta') do
  c = NxD2a
  # Zamknuta vyska H176 pri svetlej 159 = `height_lock_invalid`. Rad NL sa
  # z neplatnej vysky odvodit neda, takze zapis dlzky sa odmietne — poradie
  # osi (vyska pred NL) plati aj na zapisovej ceste.
  cfg, axes = c.axes_for(c.params, c.ov('height_variant' => 176))
  NxTest.assert_equal('conflict', axes[c::OWNER]['height']['state'])
  _f, _v, err = c.write_value(cfg, 'nominal_length', 350.0)
  NxTest.assert(err.to_s.include?('oprav najprv výšku'), err.to_s)
  # Cesta VON je zapis PLATNEJ vysky — ten sa odmietnut nesmie.
  field, value, herr = c.write_value(cfg, 'height_variant', 70)
  NxTest.assert_equal(nil, herr, herr.to_s)
  NxTest.assert_equal(['height_variant', 70], [field, value])
end

# ============================================================================
# CODEX #312 KOLO 2 — P1 (legacy zamok) a P2 (zmestitelnost, diagnostika)
# ============================================================================

NxTest.test('KOV-D2a (P1): legacy NL a novy vyskovy zamok su JEDEN zaznam') do
  c = NxD2a
  # Skrinka nesie zamok NL este pod LEGACY identitou (D-93). Zapis DRUHEJ osi
  # ide na receptovu identitu, takze bez konsolidacie by vznikli DVA zaznamy
  # jedneho vlastnika — a prestavba by z nich spravila dva zaznamy TEJ ISTEJ
  # identity, z ktorych normalizacia necha len posledny.
  legacy = [{ 'owner_part_key' => c::OWNER, 'generic_type' => 'slide',
              'rule_id' => 'vysuvy-nl-podla-hlbky', 'nominal_length' => 420.0 }]
  all = c.panel.consolidate_legacy_lock(legacy, c::OWNER, 'slide', c::RID)
  list = c.panel.merge_override(all, c::OWNER, 'slide', c::RID, 'height_variant', 70)

  NxTest.assert_equal(1, list.length, 'jeden vlastnik = jeden zaznam, nie dve identity')
  NxTest.assert_equal(c::RID, list.first['rule_id'])
  NxTest.assert_close(420.0, list.first['nominal_length'], 0.001, 'NL sa nesmie stratit')
  NxTest.assert_equal(70, list.first['height_variant'])

  # Ne-receptovy zapis sa legacy zaznamu NEDOTKNE (projektove pravidla ziju dalej).
  same = c.panel.consolidate_legacy_lock(legacy, c::OWNER, 'slide', 'vysuvy-nl-podla-hlbky')
  NxTest.assert_equal(legacy, same)

  # PORADIE v zapisovej akcii je sucastou opravy: konsolidacia MUSI bezat PRED
  # `merge_override`, inak by sa legacy zaznam do noveho zoznamu vobec nedostal.
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware.rb'),
                  encoding: 'UTF-8')
  NxTest.assert(src.include?("all = consolidate_legacy_lock(all, owner, gt, rid)\n" \
                             "          list = merge_override(all, owner, gt, rid, field, value)"),
                'konsolidacia legacy zamku musi stat PRED merge_override v akcii zapisu')
end

NxTest.test('KOV-D2a (P1): prestavba zluci premenovany legacy zamok s receptovym') do
  c = NxD2a
  overrides = [{ 'owner_part_key' => c::OWNER, 'generic_type' => 'slide',
                 'rule_id' => 'vysuvy-nl-podla-hlbky', 'nominal_length' => 420.0 },
               { 'owner_part_key' => c::OWNER, 'generic_type' => 'slide',
                 'rule_id' => c::RID, 'height_variant' => 70 }]
  norm = c.cb.normalize(c.params.merge('hardware_overrides' => overrides))
  plan = c.e::Construction.build_plan(norm, 'CAB-1',
                                      part_thicknesses: c.cb.drawer_thicknesses(norm, {}))
  NxTest.assert_equal(1, Array(plan[:drawer_override_writes]).length,
                      'predpoklad: legacy zaznam sa migruje')

  out = c.cb.apply_drawer_writes(norm, plan)
  ovs = Array(out[:hardware_overrides])
  NxTest.assert_equal(1, ovs.length, 'po premenovani ostane JEDEN zaznam')
  NxTest.assert_close(420.0, ovs.first['nominal_length'], 0.001, 'NL sa nesmie ticho stratit')
  NxTest.assert_equal(70, ovs.first['height_variant'])
  NxTest.assert_equal(1, c.cb.norm_hardware_overrides(ovs).length, 'a normalizaciu to prezije')

  # Dopad na VYROBU a NAKUP: zasuvka drzi zamknutu 420, nie automat 470.
  cfg2 = c.cfg_for(c.params, ovs)
  NxTest.assert_close(420.0, c.slide_item(cfg2)['params']['nominal_length'], 0.001)
  NxTest.assert_equal(70, c.slide_item(cfg2)['params']['height_variant'].to_i)
  NxTest.assert_close(470.0, c.slide_item(c.cfg_for(c.params))['params']['nominal_length'], 0.001,
                      'automat by dal 470 — preto je strata zamku merateľna')
end

NxTest.test('KOV-D2a (P2): vyskovy zamok, ktory sa uz nezmesti, sa ODMIETNE') do
  c = NxD2a
  # Chip mohol byt vyskladany nad vyssim celom; medzitym sa celo znizilo.
  # Bez brany by akcia „uspela" a prestavba vzapati zahodila dielce.
  cfg = c.cfg_for(c.params)
  _f, _v, err = c.write_value(cfg, 'height_variant', 144)
  NxTest.assert(err.to_s.include?('nezmestí'), err.to_s)
  NxTest.assert(err.to_s.include?('159'), "hlaska menuje CERSTVU svetlu vysku: #{err}")
  NxTest.assert(err.to_s.include?('189'), "aj potrebnu vysku: #{err}")

  # V skrinke, kde sa H144 zmesti, ten isty zapis PREJDE.
  big = c.cfg_for(c.params(front_height: 220.0, cabinet_height: 900.0))
  field, value, ok_err = c.write_value(big, 'height_variant', 144)
  NxTest.assert_equal(nil, ok_err, ok_err.to_s)
  NxTest.assert_equal(['height_variant', 144], [field, value])
end

NxTest.test('KOV-D2a (P2): necakana vynimka v kontexte osi sa ZALOGUJE, nie prehltne') do
  c = NxD2a
  norm = c.cb.normalize(c.params)
  plan = c.e::Construction.build_plan(norm, 'CAB-1',
                                      part_thicknesses: c.cb.drawer_thicknesses(norm, {}))
  NxTest.assert(plan[:front_bounds].key?('F1'), 'predpoklad: plan hranice cela ma')

  con = c.e::Construction
  logged = []
  con.singleton_class.send(:alias_method, :nx_d2a_ctx, :context_for)
  c.e.singleton_class.send(:alias_method, :nx_d2a_log, :log_error)
  begin
    con.define_singleton_method(:context_for) { |*_a| raise ArgumentError, 'sonda' }
    c.e.define_singleton_method(:log_error) { |ex, where = nil| logged << [ex.class, where.to_s] }

    NxTest.assert_equal({}, con.drawer_contexts(norm, plan), 'zlyhane celo sa do mapy nedostane')
    NxTest.assert_equal(1, logged.length, 'chyba MUSI byt v diagnostike')
    NxTest.assert_equal(ArgumentError, logged.first[0])
    NxTest.assert(logged.first[1].include?('F1'), logged.first[1])

    # OCAKAVANY pripad — plan NEMA surove hranice cela (velmi stary plan) —
    # je TICHY: nie je to chyba, len sa nema z coho pocitat.
    logged.clear
    NxTest.assert_equal({}, con.drawer_contexts(norm, plan.merge(front_bounds: {})))
    NxTest.assert_equal([], logged, 'chybajuce hranice sa neloguju ako chyba')
  ensure
    con.singleton_class.send(:alias_method, :context_for, :nx_d2a_ctx)
    con.singleton_class.send(:remove_method, :nx_d2a_ctx)
    c.e.singleton_class.send(:alias_method, :log_error, :nx_d2a_log)
    c.e.singleton_class.send(:remove_method, :nx_d2a_log)
  end
end

# ============================================================================
# CODEX #312 KOLO 3 — diagnostika receptu, hlaska sekundarnej osi, `slide`
# ============================================================================

NxTest.test('KOV-D2a (P2): nenacitatelny recept sa pri stavbe osi ZALOGUJE') do
  c = NxD2a
  cfg = c.cfg_for(c.params)
  item = Array(cfg['front_items']).first
  NxTest.assert(item.is_a?(Hash), 'predpoklad: zasuvkove celo v configu')

  logged = []
  rec = c.r
  rec.singleton_class.send(:alias_method, :nx_d2a_load, :load)
  c.e.singleton_class.send(:alias_method, :nx_d2a_log2, :log_error)
  begin
    rec.define_singleton_method(:load) { |*_a, **_k| raise rec::RecipeError, 'odtlacok nesedi' }
    c.e.define_singleton_method(:log_error) { |ex, where = nil| logged << [ex.class, where.to_s] }

    NxTest.assert_equal(nil, c.panel.drawer_axis_recipe(item), 'nenacitatelny recept = ziadne osi')
    NxTest.assert_equal(1, logged.length, 'chyba MUSI byt v diagnostike, nie tichy nil')
    NxTest.assert(logged.first[1].include?('F1'), logged.first[1])
  ensure
    rec.singleton_class.send(:alias_method, :load, :nx_d2a_load)
    rec.singleton_class.send(:remove_method, :nx_d2a_load)
    c.e.singleton_class.send(:alias_method, :log_error, :nx_d2a_log2)
    c.e.singleton_class.send(:remove_method, :nx_d2a_log2)
  end
end

NxTest.test('KOV-D2a (P2): os v konflikte MA hlasku aj pri SKORSOM zlyhani resolvera') do
  c = NxD2a
  # Zasuvka ma NEPODPOROVANU hrubku boku (KD 22 = PRVY krok resolvera)
  # A ZAROVEN neplatny vyskovy zamok. Ulozene `drawer_conflicts` nesu LEN
  # to skorsie zlyhanie, takze hlaska osi sa MUSI odvodit z receptu
  # a kontextu — inak by riadok ukazal „konflikt + navrh" bez slova preco.
  par = c.params.merge('thickness' => 22.0)
  cfg, axes = c.axes_for(par, c.ov('height_variant' => 176, 'nominal_length' => 620.0))
  codes = Array(cfg['drawer_conflicts']).map { |x| x['code'].to_s }
  NxTest.refute(codes.include?('height_lock_invalid'),
                "predpoklad: ulozeny je SKORSI dovod (#{codes.inspect})")

  a = axes[c::OWNER]
  NxTest.assert_equal('conflict', a['height']['state'])
  NxTest.refute(a['height']['message'].to_s.strip.empty?,
                'os so `state: conflict` MUSI mat hlasku')
  NxTest.assert(a['height']['message'].include?('H176'), a['height']['message'])
end

NxTest.test('KOV-D2a: KAZDA os so `state: conflict` nesie hlasku (invariant)') do
  c = NxD2a
  cases = [[c.params, c.ov('height_variant' => 176)],
           [c.params, c.ov('nominal_length' => 620.0)],
           [c.params(depth: 400.0), c.ov('nominal_length' => 470.0)],
           [c.params(front_height: 220.0, cabinet_height: 900.0),
            c.ov('height_variant' => 70, 'nominal_length' => 620.0)]]
  cases.each_with_index do |(par, ovs), i|
    _cfg, axes = c.axes_for(par, ovs)
    Array(axes[c::OWNER]).each do |_axis, st|
      next unless st.is_a?(Hash) && st['state'] == 'conflict'

      NxTest.refute(st['message'].to_s.strip.empty?, "pripad #{i}: os bez hlasky #{st.inspect}")
    end
  end
end

NxTest.test('KOV-D2a (P2): vyskovy zamok zije LEN na polozke `slide`') do
  c = NxD2a
  # CITACIA cesta: zaznam ineho typu kovania s receptovym `rule_id` pole
  # zahodi — inak by v configu schemy 7 ostal MRTVY zamok, ktory nikto necita.
  %w[hinge custom].each do |gt|
    next unless Noxun::Engine::BuildPlan::GENERIC_TYPES.include?(gt)

    raw = c.ov('height_variant' => 70, 'quantity' => 1)
    raw.first['generic_type'] = gt
    out = c.cb.norm_hardware_overrides(raw)
    NxTest.refute(out.first.key?('height_variant'), "#{gt}: vyskovy zamok nepatri k inemu typu")
    NxTest.assert_equal(1, out.first['quantity'], "#{gt}: ostatne polia ostavaju")
  end

  # ZAPISOVA cesta: akcia taky zapis ODMIETNE (HTML disabled nie je ochrana).
  cfg = c.cfg_for(c.params)
  _f, _v, err = c.panel.override_value('height_variant', 70, nil, c.cab_with(cfg),
                                       c::OWNER, 'hinge', c::RID)
  NxTest.assert(err.to_s.include?('výsuvu'), err.to_s)
  _f2, _v2, err2 = c.panel.override_value('nominal_length', 470.0, nil, c.cab_with(cfg),
                                          c::OWNER, 'hinge', c::RID)
  NxTest.assert(err2.to_s.include?('výsuvu'), err2.to_s)
end
