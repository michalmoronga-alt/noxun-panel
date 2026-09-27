# frozen_string_literal: true
# KON-B · K2 — CHRBAT Z DVOCH LIST (blok 7 KONŠTRUKCIA).
# Package: SYSTEM/archiv/bloky/KONSTRUKCIA/PACKAGE_KONB_K2.md.
#
# CO PLATI:
#   * `back_mode 'rails'`: namiesto dosky chrbta dve listy z korpusovej dosky
#     medzi bokmi — dolna na dne, horna pod stropom / vystuhami / vrchom bokov;
#     vyska `back_rail_height` (H, predvolene 100, 20–300, PRISNE parsovanie,
#     do configu LEN pri H != 100), zadna plocha v zadnom doraze R;
#   * vnutro konci pred listami v celej vyske: `back_front_y = R − t`;
#   * validacia `2H + 20 <= vnutro` (plati aj bez komina);
#   * roly `back_rail_top` / `back_rail_bottom` (dolna STOJACA), obe ABS `{L1}`,
#     spolocny nazov „Lista chrbta" -> kusovnik 1 riadok 2 ks, VEPO „Chrb HD";
#   * material chrbta sa pri listach nepouzije (preflighty ako „Bez chrbta");
#   * CONFIG_SCHEMA 21, BuildPlan SCHEMA 6, ABS SEED_VERSION 5;
#   * ostatne rezimy chrbta sa NEMENIA (H ich plan neovplyvni).
#
# MUTACIE, ktore tato sada chyta (overene rucne pri davke, report/PR):
#   M1 `back_front_y` pri listach bez `− t`        -> „matica: vnutro"
#   M2 dolna lista nie je stojaca                   -> „olep: paska na viditelnej ploche"
#                                                      (NIE pocet riadkov — audit FIX 2)
#   M3 chyba seed bump                              -> „ABS seed 5: merge"
#   M4 `rails` padne na predvoleny chrbat (enum)    -> „normalize pozna rails"
#   M5 chyba vynimka preflightu chrbta              -> „preflight chrbta pri listach"
#   M6 chyba `ROLE_AXES`                            -> „osi zo snapshotu"
#   M7 H sa validuje aj skryte                      -> JS sada test_konb_listy.js
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  %w[actions_cabinet payloads].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog') unless defined?(Noxun::Engine::RulesDialog)
end

module NxKonB
  module_function

  E   = Noxun::Engine
  CB  = E::CabinetBuilder
  CN  = E::Construction
  BP  = E::BuildPlan
  PF  = E::PartFaces
  ABS = E::AbsRules
  BOM = E::Bom

  W = 600.0; H = 720.0; D = 510.0; S = 100.0; T = 18.0

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def plan(params, cid = 'CAB-001')
    CN.build_plan(CB.normalize(params), cid)
  end

  def part(plan, key)
    plan[:parts].find { |pd| pd[:part_key] == key }
  end

  def stored(params)
    JSON.parse(JSON.generate(CB.cabinet_config(CB.normalize(params))))
  end

  def vec(a)
    a.map { |v| v.to_f.round(3) }
  end

  def top_params(tp)
    case tp
    when 'flat' then { 'top_mode' => 'two_rails', 'rails_orientation' => 'flat' }
    when 'upright' then { 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' }
    else { 'top_mode' => tp }
    end
  end

  # NEZAVISLE prepisanie tabulky package (bod 2.1) — dolna skrinka 600 x 720 x
  # 510, sokel 100, t 18, pas vystuh 100.
  def expected(tp, x, hr)
    r = x.positive? ? D - x : D
    z_lo = S + T
    z_hi =
      case tp
      when 'none' then H
      when 'upright' then H - 100.0
      else H - T # plny strop aj vystuhy naplocho (spodna hrana = h − t)
      end
    len = W - 2 * T
    { bottom: [[len, T, hr], [T, r - T, z_lo]], top: [[len, T, hr], [T, r - T, z_hi - hr]],
      prod: { length: len, width: hr, thickness: T }, bfy: r - T, avail: z_hi - z_lo }
  end

  def fixture
    JSON.parse(File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'konb_cases.json'), encoding: 'UTF-8'))
  end

  def reset_abs_file!
    path = ABS.path
    FileUtils.rm_f(path)
    FileUtils.rm_f("#{path}.bak")
    E::JsonFileStore.invalidate(path)
  end

  # Vyrobny zaznam (vzor snapshotu dielca) -> `Bom.record` (headless: resolve_part
  # nad seedom katalogu a ABS pravidiel v APPDATA sandboxe).
  def records(plan, owner, overrides = {})
    plan[:parts].map do |pd|
      res = CB.resolve_part(pd, 'K009_PW_DTDL_18', 'W1000_DTDL_18', 'HDF_WHITE_3', overrides)
      snap = { 'length' => pd[:prod][:length], 'width' => pd[:prod][:width],
               'thickness' => pd[:prod][:thickness], 'quantity' => 1,
               'material_id' => res[:material_id], 'edges' => res[:edges],
               'grain_direction' => res[:grain_direction] }
      BOM.record(snap, owner_id: owner, name: pd[:name], part_key: pd[:part_key], role: pd[:role])
    end
  end

  def rail_rows(rows)
    rows.select { |r| Array(r['names']).include?(CN::BACK_RAIL_NAME) }
  end

  # Katalog s ABS paskami (legacy seed helpera) LEN pocas bloku — potom sa
  # vrati presne predosly stav sandboxu (ostatne sady si stav nesu samy, ale
  # tato ho nesmie zmenit pod nimi).
  def with_abs_catalog
    mat = E::Materials
    path = mat.path
    before = File.exist?(path) ? File.binread(path) : nil
    NxTest.install_legacy_catalog!
    reset_abs_file!
    yield
  ensure
    if before
      File.binwrite(path, before)
    else
      FileUtils.rm_f(path)
    end
    FileUtils.rm_f("#{path}.bak")
    E::JsonFileStore.invalidate(path)
    mat.reset_catalog_state!
    reset_abs_file!
  end
end

# ============================================================================
# 1. DATA A KONTRAKT
# ============================================================================

NxTest.test('KON-B: normalize pozna `rails` (inak by padol na predvoleny chrbat typu)') do
  cb = NxKonB::CB
  NxTest.assert_equal('rails', cb.normalize('back_mode' => 'rails')[:back_mode])
  NxTest.assert_equal('rails', cb.normalize('type' => 'upper', 'back_mode' => 'rails')[:back_mode])
  NxTest.assert_equal('overlay', cb.normalize('back_mode' => 'lista')[:back_mode], 'neznama hodnota = predvolba')
  cfg = NxKonB.stored('back_mode' => 'rails')
  NxTest.assert_equal('rails', cfg['back_mode'])
  NxTest.assert_equal('rails', cfg['back']['mode'], 'vnoreny `back.mode` nesie rails')
  NxTest.assert_equal('rails', cb.config_to_params(cfg)['back_mode'])
  legacy = cb.config_to_params('type' => 'lower', 'back' => { 'mode' => 'rails' })
  NxTest.assert_equal('rails', cb.normalize(legacy)[:back_mode], 'vnoreny tvar configu prejde tiez')
end

NxTest.test('KON-B: prisne parsovanie vysky list (predvolba 100, klamp 20..300)') do
  cb = NxKonB::CB
  {
    100 => 100.0, 150 => 150.0, 12.5 => 20.0, '150' => 150.0, ' 80 ' => 80.0, '80.5' => 80.5,
    '150oops' => 100.0, '100-20' => 100.0, 'NaN' => 100.0, Float::NAN => 100.0, Float::INFINITY => 100.0,
    {} => 100.0, [] => 100.0, true => 100.0, nil => 100.0, '' => 100.0,
    0 => 20.0, -5 => 20.0, '-5' => 20.0, 400 => 300.0, '301' => 300.0, 300 => 300.0, 20 => 20.0
  }.each do |raw, want|
    got = cb.normalize('back_mode' => 'rails', 'back_rail_height' => raw)[:back_rail_height]
    NxTest.assert_equal(want, got, "H #{raw.inspect}")
    NxTest.assert(got.is_a?(Float), 'vzdy Float')
  end
  NxTest.assert_equal(100.0, cb.normalize({})[:back_rail_height], 'chybajuci kluc = 100')
  NxTest.assert_equal(100.0, cb.normalize('type' => 'dishwasher', 'back_rail_height' => 150)[:back_rail_height],
                      'slot vysku list nema')
  # Construction cita H prisne aj nad rucne skladanym configom.
  NxTest.assert_equal(100.0, NxKonB::CN.back_rail_height(back_rail_height: 'x'))
  NxTest.assert_equal(300.0, NxKonB::CN.back_rail_height(back_rail_height: 999))
  NxTest.assert_equal(100.0, NxKonB::CN.back_rail_height(nil))
end

NxTest.test('KON-B: config zapisuje H LEN pri H != 100; pri inom chrbte sa H pamata; slot nikdy') do
  zero = NxKonB.stored('back_mode' => 'rails')
  NxTest.refute(zero.key?('back_rail_height'), 'H 100 sa nezapisuje')
  NxTest.refute(NxKonB.stored({}).key?('back_rail_height'), 'skrinka bez list nedostane novy kluc')
  one = NxKonB.stored('back_mode' => 'rails', 'back_rail_height' => 150)
  NxTest.assert_equal(150.0, one['back_rail_height'])
  kept = NxKonB.stored('back_mode' => 'none', 'back_rail_height' => 150)
  NxTest.assert_equal(150.0, kept['back_rail_height'], 'pri „Bez chrbta" sa H pamata (vzor back_thickness)')
  slot = JSON.parse(JSON.generate(NxKonB::CB.cabinet_config(
    NxKonB::CB.normalize('type' => 'dishwasher').merge(back_rail_height: 150.0)
  )))
  NxTest.refute(slot.key?('back_rail_height'), 'slotu sa nezapisuje ani podvrhnuta')
end

NxTest.test('KON-B: round-trip configu cabinet_config -> config_to_params -> normalize (H 100 aj ine)') do
  cb = NxKonB::CB
  [100.0, 20.0, 150.0, 300.0, 87.5].each do |hr|
    params = cb.config_to_params(NxKonB.stored('back_mode' => 'rails', 'back_rail_height' => hr))
    NxTest.assert_equal(hr, params['back_rail_height'].to_f, "params H #{hr}")
    again = cb.normalize(params)
    NxTest.assert_equal([hr, 'rails'], [again[:back_rail_height], again[:back_mode]], "normalize H #{hr}")
  end
  legacy = cb.config_to_params('type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0)
  NxTest.assert_equal(100.0, legacy['back_rail_height'], 'stary config bez kluca = 100')
end

NxTest.test('KON-B: guard parity pola H — normalize, PARAM_KEYS, JS, sablona, mosty, vyrazy, LIMITS, predvolby') do
  k = NxKonB::CB::BACK_RAIL_KEY.to_s
  NxTest.assert_equal('back_rail_height', k)
  core = NxKonB.src('noxun_engine', 'ui', 'js', 'core.js')
  fields = core[/var\s+CONSTRUCTION_FIELDS\s*=\s*\[(.*?)\];/m, 1].to_s
  bridge = core[/function currentCarcass\(over\)\{(.*?)\n  \}/m, 1].to_s
  boot = NxKonB.src('noxun_engine', 'ui', 'js', 'boot.js')
  expr = boot[/function bindExprFields\(\)\{(.*?)\n  \}/m, 1].to_s
  form = NxKonB.src('noxun_engine', 'ui', 'js', 'form.js')
  limits = form[/var LIMITS = \{(.*?)\};/m, 1].to_s
  prev = NxKonB.src('noxun_engine', 'ui', 'js', 'preview.js')
  html = NxKonB.src('noxun_engine', 'ui', 'panel.html')
  NxTest.assert(NxKonB::CB.normalize({}).key?(k.to_sym), 'normalize pozna H')
  NxTest.assert(Noxun::Engine::Panel::PARAM_KEYS.include?(k), 'PARAM_KEYS (apply) pozna H')
  NxTest.assert(fields.include?("id:'#{k}', kind:'num', dflt:100"), 'CONSTRUCTION_FIELDS nesie H s dflt 100 (riedky config)')
  NxTest.assert(bridge.include?("#{k}: numv('#{k}')"), 'most currentCarcass cita H')
  NxTest.assert(expr.include?("'#{k}'"), 'bindExprFields chrani H')
  NxTest.assert(limits.include?("#{k}:[20,300]"), 'LIMITS H = 20..300 (Construction::BACK_RAIL_HEIGHT_RANGE)')
  NxTest.assert_equal([20.0, 300.0], NxKonB::CN::BACK_RAIL_HEIGHT_RANGE)
  NxTest.assert(form.include?('var RAIL_FIELDS = { back_rail_height: 1 };'), 'H sa validuje len pri listach (audit FIX 3)')
  NxTest.assert(html.include?(%(id="#{k}")), 'panel.html ma pole H')
  NxTest.assert(html.include?('<option value="rails">Z líšt</option>'), 'panel.html ma volbu „Z líšt"')
  NxTest.assert(html.index('value="groove"') < html.index('value="rails"') &&
                html.index('value="rails"') < html.index('<option value="none">Bez chrbta'),
                'poradie A3: … V drážke · Z líšt · Bez chrbta')
  NxTest.assert(prev.include?('nxBackRails(c)') && prev.index('nxBackRails(c)') <
                prev.index('if (!(g.backSetback > 0) && !(g.topFrontSetback > 0)) return g;'),
                'most pvGeom doplni listy PRED skorym navratom pri X = Y = 0 (audit NOTE 4)')
  NxTest.assert_equal(100.0, NxKonB::CB::LOWER_DEFAULTS[:back_rail_height], 'predvolby panela (sync DEFAULTS)')
  NxTest.assert_equal(100.0, NxKonB::CB::UPPER_DEFAULTS[:back_rail_height])
  NxTest.assert(core.include?('var NX_BACK_RAIL_H_DFLT = 100.0') && core.include?('var NX_BACK_RAIL_GAP    = 20.0'),
                'JS konstanty = Ruby konstanty')
  NxTest.assert_equal(100.0, NxKonB::CN::BACK_RAIL_HEIGHT_DEFAULT)
  NxTest.assert_equal(20.0, NxKonB::CN::BACK_RAIL_GAP_MIN)
  tpl = Noxun::Engine::Panel.template_config_from(NxKonB.stored({}))
  NxTest.assert(tpl.key?(k), 'template_config_from zapisuje H aj pri 100')
  NxTest.assert_equal(100.0, tpl[k])
end

NxTest.test('KON-B: sablona — nova zapisuje H vyslovne, stara (bez kluca) zachova H ciela, nova so 100 prepise') do
  panel = Noxun::Engine::Panel
  td = Noxun::Engine::TemplatesDialog
  src = NxKonB.stored('back_mode' => 'rails', 'back_rail_height' => 150)
  tpl = panel.template_config_from(src)
  NxTest.assert_equal(['rails', 150.0], [tpl['back_mode'], tpl['back_rail_height']], 'sablona nesie listy')
  NxTest.refute(panel.template_config_from(NxKonB.stored('type' => 'dishwasher')).key?('back_rail_height'),
                'sablona slotu H nema')
  target = NxKonB::CB.config_to_params(NxKonB.stored('back_mode' => 'rails', 'back_rail_height' => 80))
  m_old = td.merge_template(target, tpl.reject { |key, _| key == 'back_rail_height' })
  NxTest.assert_equal(80.0, m_old['back_rail_height'], 'stara sablona bez kluca = H CIELA')
  m_def = td.merge_template(target, tpl.merge('back_rail_height' => 100.0))
  NxTest.assert_equal(100.0, m_def['back_rail_height'], 'nova sablona so 100 prepise na 100')
  NxTest.assert_equal(150.0, td.merge_template(target, tpl)['back_rail_height'])
  bad = NxKonB::CB.normalize(td.merge_template(target, tpl.merge('back_rail_height' => '150oops')))
  NxTest.assert_equal(100.0, bad[:back_rail_height], 'poskodena hodnota zo sablony = 100')
end

# ============================================================================
# 2. SCHEMY
# ============================================================================

# ROH-A1 dvihla schemy (CONFIG 22, BuildPlan 7, ABS seed 6) — presne hodnoty
# drzi `test_roha1_rohova.rb`; tu sa strazi, ze bump KON-B nastal.
NxTest.test('KON-B: CONFIG_SCHEMA >= 21 + HISTORIA, BuildPlan SCHEMA >= 6 + ROLES, aktivacne schemy sa nehybu') do
  cb = NxKonB::CB
  NxTest.assert(cb::CONFIG_SCHEMA >= 21, 'KON-B bump nastal (21)')
  NxTest.assert(NxKonB.src('noxun_engine', 'core', 'cabinet_builder.rb').include?('#  21 = KON-B · K2'),
                'HISTORIA hovori, preco sa bumplo')
  NxTest.assert_equal([5, 9, 11, 19, 20], [cb::DRAWER_ACTIVATION_SCHEMA, cb::HINGE_ACTIVATION_SCHEMA,
                                           cb::LIFT_ACTIVATION_SCHEMA, cb::BACK_CUT_ACTIVATION_SCHEMA,
                                           cb::BACK_RAIL_ACTIVATION_SCHEMA])
  NxTest.assert(cb.newer_config?({ 'config_schema' => cb::CONFIG_SCHEMA + 1 }), 'dopredna brana: vyssia schema je novsia')
  NxTest.refute(cb.newer_config?({ 'config_schema' => 21 }))
  NxTest.assert_equal(cb::CONFIG_SCHEMA, NxKonB.stored('back_mode' => 'rails')['config_schema'])
  NxTest.assert(NxKonB::BP::SCHEMA >= 6, 'KON-B bump planu nastal (6)')
  NxTest.assert(%w[back_rail_top back_rail_bottom].all? { |r| NxKonB::BP::ROLES.include?(r) }, 'nove roly v ROLES')
  NxTest.assert_equal(%w[overlay inset groove], NxKonB::BP::BACK_MODES, 'BACK_MODES sa NEROZSIRUJE (znacka povodu)')
  pl = NxKonB.plan('back_mode' => 'rails')
  NxTest.assert_equal(NxKonB::BP::SCHEMA, pl[:schema])
  NxTest.refute(pl[:parts].any? { |pd| pd.key?(:back_mode) }, 'listy znacku povodu `back_mode` nenesu')
  NxTest.assert(NxKonB::ABS::SEED_VERSION >= 5, 'KON-B bump seedu nastal (5)')
  NxTest.assert_equal(1, Noxun::Engine::PartKeys::SCHEMA, 'PartKeys bez zmeny')
end

NxTest.test('KON-B: D-143/D-144 predikaty skrinku s listami neoznacia ako zastaranu') do
  cfg = NxKonB.stored('back_mode' => 'rails', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright')
  NxTest.assert_equal('rails', NxKonB::BOM.stored_back_mode(cfg))
  [cfg, cfg.merge('config_schema' => 18)].each do |c|
    NxTest.refute(NxKonB::BOM.back_stale?(c), 'D-143 nie')
    NxTest.refute(NxKonB::BOM.back_rail_stale?(c), 'D-144 nie')
  end
end

# ============================================================================
# 3. GEOMETRIA
# ============================================================================

NxTest.test('KON-B: matica — strop x dno x komin x H: box, origin, prod list, vnutro; ziadna doska chrbta') do
  n = 0
  %w[full none flat upright].each do |tp|
    %w[under_sides between_sides].each do |bot|
      [0.0, 50.0].each do |x|
        [20.0, 100.0, 150.0].each do |hr|
          tag = "#{tp}/#{bot}/X#{x}/H#{hr}"
          pl = NxKonB.plan({ 'back_mode' => 'rails', 'bottom_mode' => bot, 'back_setback' => x,
                             'back_rail_height' => hr }.merge(NxKonB.top_params(tp)))
          ex = NxKonB.expected(tp, x, hr)
          bot_p = NxKonB.part(pl, 'cabinet/back_rail:bottom')
          top_p = NxKonB.part(pl, 'cabinet/back_rail:top')
          NxTest.assert(bot_p && top_p, "#{tag}: obe listy")
          NxTest.assert(NxKonB.part(pl, 'cabinet/back').nil?, "#{tag}: doska chrbta nevznika")
          NxTest.assert_equal([NxKonB.vec(ex[:bottom][0]), NxKonB.vec(ex[:bottom][1])],
                              [NxKonB.vec(bot_p[:box]), NxKonB.vec(bot_p[:origin])], "#{tag}: dolna lista")
          NxTest.assert_equal([NxKonB.vec(ex[:top][0]), NxKonB.vec(ex[:top][1])],
                              [NxKonB.vec(top_p[:box]), NxKonB.vec(top_p[:origin])], "#{tag}: horna lista")
          NxTest.assert_equal(ex[:prod], bot_p[:prod], "#{tag}: prod dolnej")
          NxTest.assert_equal(ex[:prod], top_p[:prod], "#{tag}: prod hornej = dolnej")
          NxTest.assert_close(ex[:bfy], pl[:interior][:back_front_y], 0.001, "#{tag}: vnutro R − t")
          NxTest.assert_close(ex[:bfy], pl[:available][:depth], 0.001, "#{tag}: svetla hlbka")
          NxTest.assert_equal(%w[back_rail_bottom back_rail_top], [bot_p[:role], top_p[:role]])
          NxTest.assert_equal(['Lista chrbta'] * 2, [bot_p[:name], top_p[:name]], 'spolocny nazov (M6)')
          NxTest.assert_equal([:korpus, :korpus], [bot_p[:material], top_p[:material]])
          n += 1
        end
      end
    end
  end
  NxTest.assert_equal(48, n)
end

NxTest.test('KON-B: horna lista pri vystuhach NA VYSKU stoji tesne pod zadnou vystuhou v tej istej rovine') do
  pl = NxKonB.plan('back_mode' => 'rails', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright',
                   'back_setback' => 50)
  rail = NxKonB.part(pl, 'cabinet/rail:back')
  top = NxKonB.part(pl, 'cabinet/back_rail:top')
  NxTest.assert_close(rail[:origin][1], top[:origin][1], 0.001, 'ta ista rovina [R − t, R]')
  NxTest.assert_close(rail[:origin][2], top[:origin][2] + top[:box][2], 0.001, 'vrch listy = spodok vystuhy')
end

NxTest.test('KON-B: vnutro pred listami siahne na zony, police aj kovanie (M5)') do
  pl = NxKonB.plan('back_mode' => 'rails', 'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] })
  shelf = pl[:parts].find { |pd| pd[:role] == 'shelf' }
  NxTest.assert(shelf, 'polica je')
  NxTest.assert(shelf[:origin][1] + shelf[:box][1] <= 492.0 + 0.001, 'polica konci pred listami')
  base = NxKonB.plan('back_mode' => 'none', 'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] })
  sh0 = base[:parts].find { |pd| pd[:role] == 'shelf' }
  NxTest.assert_close(18.0, sh0[:box][1] - shelf[:box][1], 0.001, 'o hrubku listy kratsia nez bez chrbta')
end

NxTest.test('KON-B: ostatne rezimy chrbta — H plan NEOVPLYVNI (bajtovo rovnaky plan)') do
  %w[overlay inset groove none].each do |bm|
    %w[full flat upright].each do |tp|
      [0.0, 50.0].each do |x|
        p0 = { 'back_mode' => bm, 'back_setback' => (bm == 'groove' && x.positive? ? 50.0 : x) }.merge(NxKonB.top_params(tp))
        a = JSON.generate(NxKonB.plan(p0))
        b = JSON.generate(NxKonB.plan(p0.merge('back_rail_height' => 150)))
        NxTest.assert_equal(a, b, "#{bm}/#{tp}/X#{x}: plan bez zmeny")
      end
    end
  end
end

# ============================================================================
# 4. VALIDACIA
# ============================================================================

NxTest.test('KON-B: spolocna fixtura Ruby <-> JS (R, vnutro, svetla vyska, H, veta)') do
  fx = NxKonB.fixture
  NxTest.assert(fx['cases'].length >= 70, 'fixtura pokryva maticu aj hranice')
  NxTest.assert(fx['cases'].count { |c| c['error'] } >= 10, 'fixtura ma aj odmietnutia')
  fx['cases'].each do |c|
    sym = NxKonB::CB.normalize(c['cfg'])
    tag = c['case']
    it = NxKonB::CN.interior_dims(sym)
    NxTest.assert_close(c['back_stop'], NxKonB::CN.back_stop(sym), 0.001, "#{tag}: R")
    NxTest.assert_close(c['interior_depth'], it[:back_front_y], 0.001, "#{tag}: vnutro")
    NxTest.assert_close(c['avail_h'], it[:avail_h], 0.001, "#{tag}: svetla vyska")
    NxTest.assert_close(c['rail_height'], NxKonB::CN.back_rail_height(sym), 0.001, "#{tag}: H")
    NxTest.assert_equal(c['error'], NxKonB::CN.setback_error(sym), "#{tag}: veta")
    NxTest.assert_raise(c['error']) { NxKonB::CN.build_plan(sym, 'CAB-V') } if c['error']
  end
end

NxTest.test('KON-B: pravidlo 2H + 20 <= vnutro — hranica, veta mockupu, plati aj bez komina') do
  e = NxTest.assert_raise('Dve lišty po 290 mm sa do vnútra 584 mm nezmestia') do
    NxKonB.plan('back_mode' => 'rails', 'back_rail_height' => 290)
  end
  NxTest.assert(e.message.include?('zmenši výšku líšt alebo zväčši skrinku'), e.message)
  NxKonB.plan('back_mode' => 'rails', 'back_rail_height' => 282) # 584 = 2 x 282 + 20
  NxTest.assert_raise('nezmestia') { NxKonB.plan('back_mode' => 'rails', 'back_rail_height' => 282.5) }
  # Mierka zdedi pravidlo cez sondu `build_plan`.
  NxTest.assert_equal(356.0, NxKonB::CN.min_valid_height(NxKonB::CB.normalize('back_mode' => 'rails')))
  NxTest.assert_equal(147.0, NxKonB::CN.min_valid_height(NxKonB::CB.normalize('back_mode' => 'overlay')),
                      'ine rezimy maju dnesne minimum')
  # Komin pri listach nema minimum (M10).
  NxKonB.plan('back_mode' => 'rails', 'back_setback' => 1)
  NxTest.assert_equal(0.0, NxKonB::CN.min_back_setback(NxKonB::CB.normalize('back_mode' => 'rails')))
end

# ============================================================================
# 5. HRANY (ABS) A PLOCHY
# ============================================================================

NxTest.test('KON-B: ABS seed, labely, strany 2D karty, osi zo snapshotu, tag, nazvy roli') do
  abs = NxKonB::ABS
  pf = NxKonB::PF
  %w[back_rail_top back_rail_bottom].each do |role|
    NxTest.assert_equal({ 'L1' => 1.0 }, abs::SEED_RULES[role], "#{role}: seed L1 1,0")
    NxTest.assert_equal([pf::AXES_WALL], pf::ROLE_AXES[role], "#{role}: ROLE_AXES")
    NxTest.assert_equal('Noxun/Chrbát', NxKonB::CB::PART_TAGS[role], "#{role}: tag Chrbát")
    NxTest.assert(Noxun::Engine::RulesDialog::ABS_ROLE_ORDER.include?(role), "#{role}: poradie v prehlade ABS")
  end
  NxTest.assert_equal('Dolná', abs::EDGE_LABELS['back_rail_top']['L1'], 'horna lista: L1 dolna hrana')
  NxTest.assert_equal('Horná', abs::EDGE_LABELS['back_rail_bottom']['L1'], 'dolna lista: L1 horna hrana')
  NxTest.assert_equal('bottom', abs.edge_sides('back_rail_top')['L1'], '2D karta hornej: paska dole')
  NxTest.assert_equal('top', abs.edge_sides('back_rail_bottom')['L1'], '2D karta dolnej: paska hore')
  NxTest.assert(pf::STANDING_ROLES.include?('back_rail_bottom') && !pf::STANDING_ROLES.include?('back_rail_top'))
  pc = Noxun::Engine::ProductionCore
  NxTest.assert_equal(['Lišta chrbta horná', 'Lišta chrbta dolná'],
                      [pc.role_label('back_rail_top'), pc.role_label('back_rail_bottom')])
  js = NxKonB.src('noxun_engine', 'ui', 'js', 'part_card.js')
  NxTest.assert(js.include?("back_rail_top:'Lišta chrbta horná'") && js.include?("back_rail_bottom:'Lišta chrbta dolná'"),
                'karta dielca pozna nazvy roli')
  NxTest.assert_equal('body', NxKonB::CN.material_channel('back_rail_bottom', :korpus), 'material z korpusu')
  pl = NxKonB.plan('back_mode' => 'rails')
  %w[cabinet/back_rail:bottom cabinet/back_rail:top].each do |key|
    pd = NxKonB.part(pl, key)
    NxTest.assert_equal(pf::AXES_WALL, pf.verified_axes(pd), "#{key}: overene osi deskriptora")
    NxTest.assert_equal(pf::AXES_WALL, pf.axes_for_snapshot(pd[:role], pd[:box], pd[:prod]),
                        "#{key}: osi zo snapshotu (Kontrola olepov, hover, smer dekoru)")
  end
end

NxTest.test('KON-B: olep — paska L1 na ploche VIDITELNEJ ZVNUTRA (dolna hore, horna dole)') do
  pf = NxKonB::PF
  pl = NxKonB.plan('back_mode' => 'rails')
  lo = NxKonB.part(pl, 'cabinet/back_rail:bottom')
  hi = NxKonB.part(pl, 'cabinet/back_rail:top')
  ax = pf.verified_axes(lo)
  # Hodnota osi Z plosky, ktoru kresli farbenie (face_rect_mm) — 0 = spodok, H = vrch.
  z_of = lambda do |pd, code|
    rect = pf.face_rect_mm(code, [0.0, 0.0, 0.0], pd[:box].map(&:to_f), ax, 0.0, pd[:role])
    rect && rect.map { |p| p[2] }.uniq
  end
  NxTest.assert_equal([100.0], z_of.call(lo, 'L1'), 'dolna lista: L1 = HORNA plocha')
  NxTest.assert_equal([0.0], z_of.call(hi, 'L1'), 'horna lista: L1 = DOLNA plocha')
  top_center = [lo[:box][0] / 2.0, lo[:box][1] / 2.0, lo[:box][2]]
  NxTest.assert_equal('L1', pf.edge_code_for_center(top_center, lo[:box], ax, lo[:role]),
                      'Kontrola olepov / hover: horna plocha dolnej listy = L1')
  bot_center = [hi[:box][0] / 2.0, hi[:box][1] / 2.0, 0.0]
  NxTest.assert_equal('L1', pf.edge_code_for_center(bot_center, hi[:box], ax, hi[:role]),
                      'Kontrola olepov / hover: dolna plocha hornej listy = L1')
end

NxTest.test('KON-B: ABS seed 5 — merge doplni listy na existujucom PC, vlastne pravidla ostanu') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  abs = NxKonB::ABS
  NxKonB.reset_abs_file!
  custom = abs::SEED_RULES.reject { |r, _| %w[back_rail_top back_rail_bottom].include?(r) }
                          .merge('shelf' => { 'L1' => 2.0, 'L2' => 1.0 })
  Noxun::Engine::JsonFileStore.write(abs.path, { 'std' => 1, 'seed_version' => 4, 'rules' => custom })
  Noxun::Engine::JsonFileStore.invalidate(abs.path)
  got = abs.load
  NxTest.assert_equal({ 'L1' => 1.0 }, got['back_rail_top'], 'horna lista doplnena')
  NxTest.assert_equal({ 'L1' => 1.0 }, got['back_rail_bottom'], 'dolna lista doplnena')
  NxTest.assert_equal({ 'L1' => 2.0, 'L2' => 1.0 }, got['shelf'], 'vlastne pravidlo police ostalo')
  NxTest.assert_equal(abs::SEED_VERSION, Noxun::Engine::JsonFileStore.read(abs.path)['seed_version'],
                      'subor nesie aktualny seed (5 = KON-B, 6 = ROH-A1)')
  # Vlastne pravidlo listy (ulozene pod seedom 4) sa neprepise.
  NxKonB.reset_abs_file!
  Noxun::Engine::JsonFileStore.write(abs.path, { 'std' => 1, 'seed_version' => 4,
                                                 'rules' => custom.merge('back_rail_top' => {}) })
  Noxun::Engine::JsonFileStore.invalidate(abs.path)
  got2 = abs.load
  NxTest.assert_equal({}, got2['back_rail_top'], 'vedome „bez ABS" na listach ostava')
  NxTest.assert_equal({ 'L1' => 1.0 }, got2['back_rail_bottom'])
  NxKonB.reset_abs_file!
end

# ============================================================================
# 6. VYSTUPY — KUSOVNIK A VEPO
# ============================================================================

NxTest.test('KON-B: kusovnik — listy 1 riadok 2 ks L1; s vystuhami 100 1 riadok 4 ks; rucny zasah = 2 riadky') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  NxKonB.with_abs_catalog { NxKonB.bom_checks }
end

module NxKonB
  module_function

  def bom_checks
  bom = NxKonB::BOM
  vepo = Noxun::Engine::VepoExport
  pl = NxKonB.plan({ 'back_mode' => 'rails' }, 'CAB-015')
  rows = NxKonB.rail_rows(bom.aggregate_rows(NxKonB.records(pl, 'CAB-015')))
  NxTest.assert_equal(1, rows.length, 'jeden riadok')
  r = rows.first
  NxTest.assert_equal([['Lista chrbta'], 2, 564.0, 100.0, 18.0],
                      [r['names'], r['quantity'], r['length'], r['width'], r['thickness']])
  NxTest.assert(!r['edges']['L1'].nil? && r['edges']['L2'].nil? && r['edges']['W1'].nil? && r['edges']['W2'].nil?,
                "paska len na L1 (#{r['edges'].inspect})")
  NxTest.assert_equal('Chrb HD s15', vepo.row_name(r))
  # Vystuhy 100 (na vysku aj naplocho) sa zluia s listami — 1 riadok, 4 ks.
  %w[upright flat].each do |ori|
    pv = NxKonB.plan({ 'back_mode' => 'rails', 'top_mode' => 'two_rails', 'rails_orientation' => ori }, 'CAB-012')
    rv = NxKonB.rail_rows(bom.aggregate_rows(NxKonB.records(pv, 'CAB-012')))
    NxTest.assert_equal(1, rv.length, "#{ori}: jeden riadok")
    NxTest.assert_equal(4, rv.first['quantity'], "#{ori}: 4 ks")
    NxTest.assert_equal('Vyst PZ/Chrb HD s12', vepo.row_name(rv.first), "#{ori}: VEPO nazov")
    NxTest.assert(vepo.row_name(rv.first).length <= vepo::NAME_MAX)
  end
  # Dve skrinky s listami a vystuhami: vlastnici sa do 20 znakov nezmestia -> „+2".
  pa = NxKonB.plan({ 'back_mode' => 'rails', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' }, 'CAB-012')
  pb = NxKonB.plan({ 'back_mode' => 'rails', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' }, 'CAB-013')
  two = NxKonB.rail_rows(bom.aggregate_rows(NxKonB.records(pa, 'CAB-012') + NxKonB.records(pb, 'CAB-013')))
  NxTest.assert_equal([1, 8, 'Vyst PZ/Chrb HD +2'], [two.length, two.first['quantity'], vepo.row_name(two.first)])
  # Rucny material na JEDNEJ liste -> dva riadky (kusy sa naozaj lisia), oba „Chrb HD".
  ov = { 'cabinet/back_rail:top' => { 'material_id' => 'W1000_DTDL_18' } }
  split = NxKonB.rail_rows(bom.aggregate_rows(NxKonB.records(pl, 'CAB-015', ov)))
  NxTest.assert_equal(2, split.length, 'dva riadky')
  NxTest.assert_equal(['Chrb HD s15'] * 2, split.map { |x| vepo.row_name(x) })
  end
end

NxTest.test('KON-B: VEPO skratka a kontrakt nazvov') do
  vepo = Noxun::Engine::VepoExport
  NxTest.assert_equal('Chrb HD', vepo.short_name('Lista chrbta'))
  NxTest.assert_equal('Lista chrbta', NxKonB::CN::BACK_RAIL_NAME)
  kontrakt = NxKonB.src('SYSTEM', 'VEPO_KONTRAKT.md')
  NxTest.assert(kontrakt.include?('Chrb HD'), 'VEPO_KONTRAKT.md menuje skratku list')
end

# ============================================================================
# 7. MATERIAL CHRBTA PRI LISTACH = AKO „BEZ CHRBTA"
# ============================================================================

NxTest.test('KON-B: preflight chrbta pri listach — material chrbta sa nepouzije (ako Bez chrbta)') do
  cn = NxKonB::CN
  NxTest.refute(cn.back_material_used?('rails'))
  NxTest.refute(cn.back_material_used?('none'))
  %w[overlay inset groove].each { |bm| NxTest.assert(cn.back_material_used?(bm), bm) }
  # Panel: pri listach sa hrubka chrbta nekontroluje vobec — ten isty vstup,
  # pri ktorom by naloženy chrbat 18 mm vymenil HDF 3 za 18 mm dosku (D-38),
  # pri listach neurobi nic a parametre nechá nedotknute.
  if NxTest.headless?
    NxKonB.with_abs_catalog do
      mk = ->(bm) { { 'back_mode' => bm, 'back_thickness' => 18.0, 'back_material_id' => 'HDF_WHITE_3' } }
      over = mk.call('overlay')
      NxTest.refute(Noxun::Engine::Panel.back_preflight(over, nil).nil?, 'naloženy 18 na HDF 3 = vymena materialu (kontrola)')
      rails = mk.call('rails')
      NxTest.assert_equal(nil, Noxun::Engine::Panel.back_preflight(rails, nil), 'listy: ziadna vymena ani chyba')
      NxTest.assert_equal(mk.call('rails'), rails, 'listy: parametre nedotknute')
    end
  end
  md = NxKonB.src('noxun_engine', 'ui', 'materials_dialog.rb')
  NxTest.assert(md.include?("key == 'default_back_material_id' && !Construction.back_material_used?(params['back_mode'])"),
                'brana projektoveho chrbta preskoci aj listy')
  ru = NxKonB.src('noxun_engine', 'core', 'materials_replace_uni.rb')
  NxTest.assert(ru.include?("roles_now.include?('back') && Construction.back_material_used?(params['back_mode'])"),
                '„Nahradiť UNI" hrubku chrbta pri listach neprevezme')
end
