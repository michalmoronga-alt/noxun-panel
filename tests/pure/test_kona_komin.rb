# frozen_string_literal: true
# KON-A · K1 — KOMIN VZADU, ZAPUSTENY STROP VPREDU, OPRAVA D-144 (blok 7
# KONŠTRUKCIA). Package: SYSTEM/archiv/bloky/KONSTRUKCIA/PACKAGE_KONA_K1.md.
#
# CO PLATI:
#   * config smie niest `back_setback` (X) a `top_front_setback` (Y), mm Float
#     0..300, PRISNE parsovane, zapisane LEN ked su > 0; slot ich nema;
#   * X > 0: boky plna `d`, dno/strop/zadna vystuha koncia na R = d − X, chrbat
#     naloženy a v drazke MEDZI bokmi na R, vlozeny pred R; vnutro po chrbat;
#   * Y > 0: plny strop a predna vystuha zacinaju na Y (dno nie);
#   * odmietnutia (minimum komina podla chrbta, vnutro 40 pri komine, strop 60,
#     vystuhy v intervale Y … R) — pri X = Y = 0 ZIADNE nove;
#   * nika spotrebica pri komine z hlbky BOKU (oba citatelia);
#   * mierka: config-aware minimum hlbky (`min_valid_depth`);
#   * D-144: chrbat vlozeny / v drazke pri vystuhach na vysku konci POD nimi
#     (aj rozmer do narezu), zastarane skrinky v registri vyrobnej brany KON-0.
#
# MUTACIE, ktore tato sada chyta (overene rucne pri davke, PR popis):
#   M1 `back_front_y` ignoruje X            -> „matica: vnutro"
#   M2 boky ostanu `carcass_depth` pri X>0  -> „matica: boky"
#   M3 `config_to_params` zahodi X          -> „round-trip configu"
#   M4 `merge_template` stara -> 0          -> „merge_template: stara sablona"
#   M5 D-144 bez „nizsej z dvoch"           -> „D-144: chrbat pod vystuhami"
#   M6 nika pri X>0 z `back_front_y`        -> „nika: z hlbky boku"
#   M7 chyba minimum vnutra pri komine      -> „validacia: vnutro 40"
#   M8 vyber kandidatov len podla D-143     -> „D-144: spolocny vyber kandidatov"
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  %w[actions_cabinet payloads].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  # ScaleWatch definuje triedy observerov nad `Sketchup::*Observer` — headless
  # ich na chvilu podstrcime a hned uprateme (vzor KON-0 `UI` stub), aby
  # `clamp_depth` isiel otestovat bez SketchUpu.
  unless defined?(Noxun::Engine::ScaleWatch)
    su = Module.new
    %w[EntityObserver EntitiesObserver AppObserver].each { |c| su.const_set(c, Class.new) }
    Object.const_set(:Sketchup, su)
    begin
      require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer')
    ensure
      Object.send(:remove_const, :Sketchup)
    end
  end
end

module NxKonA
  module_function

  E   = Noxun::Engine
  CB  = E::CabinetBuilder
  CN  = E::Construction
  BOM = E::Bom
  PC  = E::ProductionCore

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def plan(params)
    CN.build_plan(CB.normalize(params), 'CAB-001')
  end

  def part(plan, key)
    plan[:parts].find { |pd| pd[:part_key] == key }
  end

  # Config tak, ako ho vidi prestavba: normalize -> cabinet_config -> JSON (model).
  def stored(params)
    JSON.parse(JSON.generate(CB.cabinet_config(CB.normalize(params))))
  end

  def vec(a)
    a.map { |v| v.to_f.round(3) }
  end

  # NEZAVISLE prepisanie tabulky package (bod 2) — ocakavana geometria dielcov
  # dolnej skrinky 600 x 720 x 510, sokel 100, t 18, chrbat 3, pas 100.
  W = 600.0; H = 720.0; D = 510.0; S = 100.0; T = 18.0; BT = 3.0

  def expected(bm, tp, bottom, x, y)
    cd = bm == 'overlay' ? D - BT : D
    r = x.positive? ? D - x : cd
    side = x.positive? ? D : cd
    z0 = bottom == 'under_sides' ? S + T : 0.0
    out = {}
    out['cabinet/side:left'] = [[T, side, H - z0], [0, 0, z0]]
    out['cabinet/side:right'] = [[T, side, H - z0], [W - T, 0, z0]]
    out['cabinet/bottom'] = bottom == 'under_sides' ? [[W, r, T], [0, 0, S]] : [[W - 2 * T, r, T], [T, 0, S]]
    z_hi = H - T
    case tp
    when 'full'
      out['cabinet/top'] = [[W - 2 * T, r - y, T], [T, y, H - T]]
    when 'none'
      z_hi = H
    when 'flat'
      rd = [100.0, (r - y) / 2.0 - 10.0].min
      out['cabinet/rail:front'] = [[W - 2 * T, rd, T], [T, y, H - T]]
      out['cabinet/rail:back'] = [[W - 2 * T, rd, T], [T, r - rd, H - T]]
    when 'upright'
      z_hi = H - 100.0
      out['cabinet/rail:front'] = [[W - 2 * T, T, 100.0], [T, y, z_hi]]
      out['cabinet/rail:back'] = [[W - 2 * T, T, 100.0], [T, r - T, z_hi]]
    end
    z_lo = S + T
    bfy =
      if x.positive? then bm == 'inset' ? r - BT : r
      else { 'none' => D, 'inset' => D - BT, 'groove' => D - 10 - BT, 'overlay' => D - BT }[bm]
      end
    back_top = %w[flat upright].include?(tp) ? [H - T, z_hi].min : z_hi
    cut = nil
    case bm
    when 'overlay'
      out['cabinet/back'] = x.positive? ? [[W - 2 * T, BT, H - S], [T, r, S]] : [[W, BT, H - S], [0, D - BT, S]]
    when 'groove'
      if x.positive?
        out['cabinet/back'] = [[W - 2 * T, BT, H - S], [T, r, S]]
        cut = [W, H - S]
      else
        out['cabinet/back'] = [[W - 2 * T, BT, back_top - z_lo], [T, D - 10 - BT, z_lo]]
        cut = [W, (H - S) - (tp == 'upright' ? 100.0 - T : 0.0)]
      end
    when 'inset'
      out['cabinet/back'] = [[W - 2 * T, BT, back_top - z_lo], [T, (x.positive? ? r : D) - BT, z_lo]]
    end
    [out, bfy, cut]
  end

  def top_params(tp)
    case tp
    when 'flat' then { 'top_mode' => 'two_rails', 'rails_orientation' => 'flat' }
    when 'upright' then { 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' }
    else { 'top_mode' => tp }
    end
  end

  def min_x(bm)
    { 'overlay' => BT, 'groove' => 10 + BT }[bm] || 1.0
  end

  def fixture
    JSON.parse(File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'kona_cases.json'), encoding: 'UTF-8'))
  end
end

# ============================================================================
# 1. DATA A KONTRAKT
# ============================================================================

NxTest.test('KON-A: prisne parsovanie X/Y v normalize (audit FIX 5)') do
  cb = NxKonA::CB
  {
    50 => 50.0, 12.5 => 12.5, '50' => 50.0, ' 30 ' => 30.0, '12.5' => 12.5,
    '50oops' => 0.0, '50-20' => 0.0, 'NaN' => 0.0, 'Infinity' => 0.0, Float::NAN => 0.0,
    Float::INFINITY => 0.0, {} => 0.0, [] => 0.0, true => 0.0, nil => 0.0, '' => 0.0,
    -5 => 0.0, '-5' => 0.0, 400 => 300.0, '301' => 300.0, 300 => 300.0, '0x1A' => 0.0
  }.each do |raw, want|
    cfg = cb.normalize('back_setback' => raw, 'top_front_setback' => raw)
    NxTest.assert_equal(want, cfg[:back_setback], "back_setback #{raw.inspect}")
    NxTest.assert_equal(want, cfg[:top_front_setback], "top_front_setback #{raw.inspect}")
    NxTest.assert(cfg[:back_setback].is_a?(Float), 'vzdy Float')
  end
  d = cb.normalize({})
  NxTest.assert_equal([0.0, 0.0], [d[:back_setback], d[:top_front_setback]], 'chybajuci kluc = 0')
  slot = cb.normalize('type' => 'dishwasher', 'back_setback' => 50, 'top_front_setback' => 30)
  NxTest.assert_equal([0.0, 0.0], [slot[:back_setback], slot[:top_front_setback]], 'slot ich ignoruje')
end

NxTest.test('KON-A: config zapisuje X/Y LEN ked su > 0; vnorene top/back bez zmeny') do
  cb = NxKonA::CB
  zero = NxKonA.stored({})
  NxTest.refute(zero.key?('back_setback') || zero.key?('top_front_setback'),
                'skrinka s X = Y = 0 nedostane NOVE kluce (config existujucich skriniek sa nemeni)')
  up = NxKonA.stored('type' => 'upper')
  NxTest.refute(up.key?('back_setback'), 'ani horna')
  one = NxKonA.stored('back_setback' => 50)
  NxTest.assert_equal(50.0, one['back_setback'])
  NxTest.refute(one.key?('top_front_setback'), 'nulove Y sa nezapisuje')
  both = NxKonA.stored('back_setback' => 50, 'top_front_setback' => 30)
  NxTest.assert_equal([50.0, 30.0], [both['back_setback'], both['top_front_setback']])
  NxTest.assert_equal(zero['top'], both['top'], 'vnoreny `top` bez zmeny')
  NxTest.assert_equal(zero['back'], both['back'], 'vnoreny `back` bez zmeny')
  slot = JSON.parse(JSON.generate(cb.cabinet_config(cb.normalize('type' => 'dishwasher').merge(back_setback: 50.0))))
  NxTest.refute(slot.key?('back_setback'), 'slotu sa nezapisuju ani podvrhnute')
end

NxTest.test('KON-A: round-trip configu cabinet_config -> config_to_params -> normalize (X a Y, 0 aj > 0)') do
  cb = NxKonA::CB
  [[0.0, 0.0], [50.0, 0.0], [0.0, 30.0], [50.0, 30.0], [12.5, 7.5]].each do |x, y|
    params = cb.config_to_params(NxKonA.stored('back_setback' => x, 'top_front_setback' => y))
    NxTest.assert_equal(x, params['back_setback'].to_f, "params X #{x}")
    NxTest.assert_equal(y, params['top_front_setback'].to_f, "params Y #{y}")
    again = cb.normalize(params)
    NxTest.assert_equal([x, y], [again[:back_setback], again[:top_front_setback]], "normalize #{x}/#{y}")
  end
  legacy = cb.config_to_params('type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0)
  NxTest.assert_equal([0.0, 0.0], [legacy['back_setback'], legacy['top_front_setback']],
                      'stary config bez kluca = 0 (chybajuci kluc -> 0.0)')
end

NxTest.test('KON-A: guard parity konstrukcnych poli — normalize, PARAM_KEYS, JS, sablona, mosty, vyrazy, LIMITS') do
  keys = NxKonA::CB::SETBACK_KEYS.map(&:to_s)
  NxTest.assert_equal(%w[back_setback top_front_setback], keys)
  norm = NxKonA::CB.normalize({})
  core = NxKonA.src('noxun_engine', 'ui', 'js', 'core.js')
  fields = core[/var\s+CONSTRUCTION_FIELDS\s*=\s*\[(.*?)\];/m, 1].to_s
  bridge = core[/function currentCarcass\(over\)\{(.*?)\n  \}/m, 1].to_s
  boot = NxKonA.src('noxun_engine', 'ui', 'js', 'boot.js')
  expr = boot[/function bindExprFields\(\)\{(.*?)\n  \}/m, 1].to_s
  form = NxKonA.src('noxun_engine', 'ui', 'js', 'form.js')
  limits = form[/var LIMITS = \{(.*?)\};/m, 1].to_s
  prev = NxKonA.src('noxun_engine', 'ui', 'js', 'preview.js')
  html = NxKonA.src('noxun_engine', 'ui', 'panel.html')
  tpl = Noxun::Engine::Panel.template_config_from(NxKonA.stored({}))
  keys.each do |k|
    NxTest.assert(norm.key?(k.to_sym), "normalize pozna #{k}")
    NxTest.assert(Noxun::Engine::Panel::PARAM_KEYS.include?(k), "PARAM_KEYS (apply) pozna #{k}")
    NxTest.assert(fields.include?("id:'#{k}', kind:'num', dflt:0"), "CONSTRUCTION_FIELDS nesie #{k} s dflt 0 (riedky config)")
    NxTest.assert(bridge.include?("#{k}: numv('#{k}')"), "most currentCarcass cita #{k} (audit FIX 2)")
    NxTest.assert(expr.include?("'#{k}'"), "bindExprFields chrani #{k} (audit FIX 3)")
    NxTest.assert(limits.include?("#{k}:[0,300]"), "LIMITS #{k} = 0..300 (Construction::SETBACK_MAX)")
    NxTest.assert(html.include?(%(id="#{k}")), "panel.html ma pole #{k}")
    NxTest.assert(tpl.key?(k), "template_config_from zapisuje #{k} aj pri 0 (Codex FIX 7)")
    NxTest.assert_equal(0.0, tpl[k], "nova sablona 0 = 0 #{k}")
  end
  NxTest.assert(prev.include?('pvSetbackDepths('), 'most pvGeom siaha po komine/zapusteni (audit FIX 2)')
  NxTest.assert_equal(300.0, NxKonA::CN::SETBACK_MAX)
  NxTest.assert(core.include?('var NX_SETBACK_MAX    = 300.0'), 'JS strop = Ruby strop')
end

NxTest.test('KON-A: sablona — nova zapisuje X/Y vyslovne, stara (bez kluca) zachova ciel, nova s 0 prepise na 0') do
  panel = Noxun::Engine::Panel
  td = Noxun::Engine::TemplatesDialog
  src = NxKonA.stored('back_setback' => 50, 'top_front_setback' => 30)
  tpl = panel.template_config_from(src)
  NxTest.assert_equal([50.0, 30.0], [tpl['back_setback'], tpl['top_front_setback']], 'sablona nesie komin')
  slot_tpl = panel.template_config_from(NxKonA.stored('type' => 'dishwasher'))
  NxTest.refute(slot_tpl.key?('back_setback'), 'sablona slotu komin nema')
  target = NxKonA::CB.config_to_params(NxKonA.stored('back_setback' => 70, 'top_front_setback' => 20))
  old_tpl = tpl.reject { |k, _| %w[back_setback top_front_setback].include?(k) }
  m_old = td.merge_template(target, old_tpl)
  NxTest.assert_equal([70.0, 20.0], [m_old['back_setback'], m_old['top_front_setback']],
                      'stara sablona bez kluca = zachovaj hodnotu CIELA (M10, vzor D-13)')
  m_zero = td.merge_template(target, tpl.merge('back_setback' => 0.0, 'top_front_setback' => 0.0))
  NxTest.assert_equal([0.0, 0.0], [m_zero['back_setback'], m_zero['top_front_setback']],
                      'nova sablona s 0 prepise na 0')
  m_new = td.merge_template(target, tpl)
  NxTest.assert_equal([50.0, 30.0], [m_new['back_setback'], m_new['top_front_setback']], 'nova sablona prenesie komin')
  # Poskodena hodnota v sablone (rucne upravena kniznica) skonci pri stavbe na 0.
  bad = NxKonA::CB.normalize(td.merge_template(target, tpl.merge('back_setback' => '50oops', 'top_front_setback' => 'NaN')))
  NxTest.assert_equal([0.0, 0.0], [bad[:back_setback], bad[:top_front_setback]], 'neplatna hodnota zo sablony = 0')
end

# ============================================================================
# 2. GEOMETRIA
# ============================================================================

NxTest.test('KON-A: matica X x chrbat x strop x dno x Y — box, origin, prod kazdeho dielca, vnutro, cut_size') do
  n = 0
  %w[overlay inset groove none].each do |bm|
    %w[full none flat upright].each do |tp|
      %w[under_sides between_sides].each do |bottom|
        [0.0, 30.0].each do |y|
          [0.0, NxKonA.min_x(bm), 50.0].each do |x|
            tag = "#{bm}/#{tp}/#{bottom}/X#{x}/Y#{y}"
            params = { 'back_mode' => bm, 'bottom_mode' => bottom, 'back_setback' => x,
                       'top_front_setback' => y }.merge(NxKonA.top_params(tp))
            pl = NxKonA.plan(params)
            want, bfy, cut = NxKonA.expected(bm, tp, bottom, x, y)
            NxTest.assert_close(bfy, pl[:interior][:back_front_y], 0.001, "#{tag}: vnutro (M1)")
            NxTest.assert_close(bfy, pl[:available][:depth], 0.001, "#{tag}: available.depth")
            cab = pl[:parts].select { |pd| pd[:part_key].start_with?('cabinet/') && pd[:part_key] != 'cabinet/plinth:front' }
            NxTest.assert_equal(want.keys.sort, cab.map { |pd| pd[:part_key] }.sort, "#{tag}: sada dielcov")
            want.each do |key, (box, origin)|
              pd = NxKonA.part(pl, key)
              NxTest.assert_equal(NxKonA.vec(box), NxKonA.vec(pd[:box]), "#{tag}: #{key} box (M2)")
              NxTest.assert_equal(NxKonA.vec(origin), NxKonA.vec(pd[:origin]), "#{tag}: #{key} origin")
              # prod = rozmery dielca v osiach deskriptora (dlzka/sirka/hrubka).
              dims = pd[:box].map(&:to_f).sort
              NxTest.assert_equal(dims.map { |v| v.round(3) },
                                  pd[:prod].values_at(:length, :width, :thickness).map { |v| v.to_f.round(3) }.sort,
                                  "#{tag}: #{key} prod = box")
            end
            bk = NxKonA.part(pl, 'cabinet/back')
            got_cut = bk && bk[:cut_size] ? [bk[:cut_size][:length].to_f, bk[:cut_size][:width].to_f] : nil
            NxTest.assert_equal(cut, got_cut, "#{tag}: cut_size")
            n += 1
          end
        end
      end
    end
  end
  NxTest.assert_equal(192, n, 'cela matica')
end

NxTest.test('KON-A: priklady package — smoke 1, 3 a 5 (kusovnik v cislach)') do
  pl = NxKonA.plan('back_setback' => 50)
  NxTest.assert_equal(460.0, pl[:available][:depth], 'Vnút. hĺbka 460')
  NxTest.assert_equal(510.0, NxKonA.part(pl, 'cabinet/side:left')[:prod][:width], 'boky 510')
  NxTest.assert_equal(460.0, NxKonA.part(pl, 'cabinet/bottom')[:prod][:width], 'dno 460')
  NxTest.assert_equal(460.0, NxKonA.part(pl, 'cabinet/top')[:prod][:width], 'strop 460')
  bk = NxKonA.part(pl, 'cabinet/back')[:prod]
  NxTest.assert_equal([564.0, 620.0], [bk[:length], bk[:width]], 'chrbat 564 x 620 medzi bokmi')
  up = NxKonA.plan('type' => 'upper', 'back_setback' => 13)
  NxTest.assert_equal(307.0, up[:available][:depth], 'horna v drazke, komin 13: vnutro 307 ako bez komina')
  NxTest.assert_equal({ length: 600.0, width: 720.0 }, NxKonA.part(up, 'cabinet/back')[:cut_size], 'do narezu 600 x 720')
  fr = NxKonA.plan('height' => 2100, 'depth' => 560, 'back_mode' => 'none', 'back_setback' => 50)
  NxTest.assert_equal(510.0, NxKonA.part(fr, 'cabinet/bottom')[:prod][:width], 'Chladnickova: dno 510')
  NxTest.assert_equal(560.0, NxKonA.part(fr, 'cabinet/side:left')[:prod][:width], 'boky 560')
  NxTest.assert_equal(nil, NxKonA.part(fr, 'cabinet/back'), 'bez chrbta')
end

NxTest.test('KON-A: D-144 — chrbat vlozeny a v drazke konci pod vystuhami na vysku (aj rozmer do narezu)') do
  pl = NxKonA.plan('back_mode' => 'groove', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright')
  bk = NxKonA.part(pl, 'cabinet/back')
  NxTest.assert_equal([564.0, 502.0], [bk[:prod][:length], bk[:prod][:width]], 'model 564 x 502 (dnes 564 x 584) — M5')
  NxTest.assert_equal({ length: 600.0, width: 538.0 }, bk[:cut_size], 'do narezu 600 x 538 (dnes 600 x 620)')
  rail = NxKonA.part(pl, 'cabinet/rail:back')
  NxTest.assert(bk[:origin][2] + bk[:box][2] <= rail[:origin][2] + 0.001, 'horna hrana chrbta pod spodnou hranou vystuhy')
  ins = NxKonA.part(NxKonA.plan('back_mode' => 'inset', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright'),
                    'cabinet/back')
  NxTest.assert_equal(502.0, ins[:prod][:width], 'vlozeny rovnako')
  # Vystuha na vysku <= hrubka korpusu: nic sa nemeni (nizsia z dvoch = dnesna).
  low = NxKonA.part(NxKonA.plan('back_mode' => 'groove', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright',
                                'rail_depth' => 20, 'thickness' => 25), 'cabinet/back')
  base = NxKonA.part(NxKonA.plan('back_mode' => 'groove', 'top_mode' => 'two_rails', 'rails_orientation' => 'flat',
                                 'thickness' => 25), 'cabinet/back')
  NxTest.assert_equal(base[:prod][:width], low[:prod][:width], 'vystuha 20 < hrubka 25: vyska chrbta ako dnes')
  NxTest.assert_equal(base[:cut_size], low[:cut_size], 'aj rozmer do narezu')
  # Pri komine stoji chrbat v drazke ZA vystuhami -> plna vyska h − s.
  sb = NxKonA.part(NxKonA.plan('back_mode' => 'groove', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright',
                               'back_setback' => 50), 'cabinet/back')
  NxTest.assert_equal([620.0, { length: 600.0, width: 620.0 }], [sb[:prod][:width], sb[:cut_size]],
                      'X > 0: D-144 sa chrbta v drazke netyka')
end

NxTest.test('KON-A: nohy (proxy) podla hlbky dna R — zdroj buildera') do
  cb_src = NxKonA.src('noxun_engine', 'core', 'cabinet_builder.rb')
  legs = cb_src[/def draw_legs\(ents, cfg, qty\)(.*?)\n        end\n/m, 1].to_s
  NxTest.assert(legs.include?('Construction.back_stop(cfg)'), 'draw_legs cita zadny doraz R')
  NxTest.refute(legs.include?('Construction.carcass_depth(cfg)'), 'uz nie carcass_depth')
  NxTest.assert_equal(NxKonA::CN.carcass_depth(NxKonA::CB.normalize({})), NxKonA::CN.back_stop(NxKonA::CB.normalize({})),
                      'pri X = 0 rovnake cislo ako dnes')
end

# ============================================================================
# 3. VALIDACIA
# ============================================================================

NxTest.test('KON-A: spolocna fixtura Ruby <-> JS (R, boky, vnutro, flat limit, veta)') do
  fx = NxKonA.fixture
  NxTest.assert(fx['cases'].length >= 100, 'fixtura pokryva maticu aj hranice')
  fx['cases'].each do |c|
    sym = NxKonA::CB.normalize(c['cfg'])
    tag = c['case']
    NxTest.assert_close(c['back_stop'], NxKonA::CN.back_stop(sym), 0.001, "#{tag}: R")
    NxTest.assert_close(c['side_depth'], NxKonA::CN.side_depth(sym), 0.001, "#{tag}: boky")
    NxTest.assert_close(c['interior_depth'], NxKonA::CN.interior_dims(sym)[:back_front_y], 0.001, "#{tag}: vnutro")
    NxTest.assert_close(c['flat_limit'], NxKonA::CN.rail_geometry(sym)[:flat_limit], 0.001, "#{tag}: flat limit")
    NxTest.assert_equal(c['error'], NxKonA::CN.setback_error(sym), "#{tag}: veta")
    if c['error']
      NxTest.assert_raise(c['error']) { NxKonA::CN.build_plan(sym, 'CAB-V') }
    end
  end
end

NxTest.test('KON-A: minimum komina podla chrbta — hranica −1 / 0 / +1 mm a vety') do
  [['overlay', 3.0, 'naloženom'], ['groove', 13.0, 'drážka 10 + chrbát 3']].each do |bm, min, word|
    e = NxTest.assert_raise(word) { NxKonA.plan('back_mode' => bm, 'back_setback' => min - 1) }
    NxTest.assert(e.message.include?("aspoň #{min.round} mm"), e.message)
    NxKonA.plan('back_mode' => bm, 'back_setback' => min)
    NxKonA.plan('back_mode' => bm, 'back_setback' => min + 1)
  end
  e18 = NxTest.assert_raise('aspoň 18 mm') { NxKonA.plan('back_setback' => 17, 'back_thickness' => 18) }
  NxTest.assert(e18.message.include?('hrúbka chrbta'), e18.message)
  %w[inset none].each { |bm| NxKonA.plan('back_mode' => bm, 'back_setback' => 1) } # bez minima
  NxKonA.plan('back_mode' => 'none', 'back_setback' => 1, 'back_thickness' => 18) # skryta hrubka sa nepocita
end

NxTest.test('KON-A: minimum vnutra 40 pri komine — police nikdy nevypadnu (audit BLOCKER 1, M7)') do
  e = NxTest.assert_raise('ostane vnútro len 11 mm') do
    NxKonA.plan('depth' => 161, 'back_mode' => 'none', 'top_mode' => 'none', 'back_setback' => 150)
  end
  NxTest.assert(e.message.include?('police sa nezmestia'), e.message)
  ok = NxKonA.plan('depth' => 190, 'back_mode' => 'none', 'top_mode' => 'none', 'back_setback' => 150,
                   'zone_tree' => { 'shelves' => 2 })
  shelves = ok[:parts].select { |pd| pd[:role] == 'shelf' }
  NxTest.assert_equal(2, shelves.length, 'pri vnutri 40 police OSTANU (ziadne tiche vypadnutie)')
  NxTest.refute(ok[:warnings].any? { |w| w['code'] == 'shelf_skipped_shallow_zone' }, 'bez ORANGE vynechania')
  NxTest.assert_raise('ostane vnútro len 39 mm') do
    NxKonA.plan('depth' => 192, 'back_mode' => 'inset', 'top_mode' => 'none', 'back_setback' => 150)
  end
end

NxTest.test('KON-A: plny strop R − Y >= 60, vystuhy v intervale Y … R') do
  NxTest.assert_raise('ostalo by z neho 47 mm') { NxKonA.plan('depth' => 150, 'top_front_setback' => 100) }
  NxKonA.plan('depth' => 163, 'top_front_setback' => 100) # presne 60
  NxTest.assert_raise('strop mal len 50 mm') { NxKonA.plan('depth' => 150, 'back_mode' => 'none', 'back_setback' => 100) }
  # flat: orezanie s upozornenim (priklad auditu d 260, X 50, Y 70 -> limit 60)
  pl = NxKonA.plan('depth' => 260, 'top_mode' => 'two_rails', 'back_setback' => 50, 'top_front_setback' => 70)
  NxTest.assert_equal(60.0, NxKonA.part(pl, 'cabinet/rail:front')[:prod][:width], 'pas orezany na 60')
  w = pl[:warnings].find { |x| x['code'] == 'rail_depth_clamped' }
  NxTest.assert(!w.nil?, 'orezanie NIE je tiche (rail_depth_clamped)')
  rf = NxKonA.part(pl, 'cabinet/rail:front'); rb = NxKonA.part(pl, 'cabinet/rail:back')
  NxTest.assert(rf[:origin][1] + rf[:box][1] <= rb[:origin][1] + 0.001, 'vystuhy sa neprekryvaju')
  NxTest.assert_raise('na každú by ostalo 15 mm') do
    NxKonA.plan('depth' => 200, 'top_mode' => 'two_rails', 'back_mode' => 'none', 'back_setback' => 50,
                'top_front_setback' => 100)
  end
  NxTest.assert_raise('potrebujú 146 mm hĺbky') do
    NxKonA.plan('depth' => 200, 'top_mode' => 'two_rails', 'rails_orientation' => 'upright', 'back_mode' => 'none',
                'back_setback' => 60, 'top_front_setback' => 90)
  end
end

NxTest.test('KON-A: pri X = Y = 0 ZIADNE nove odmietnutie (audit FIX 4 — hranicne configy)') do
  # Dnes platna skrinka, ktoru by nepodmienene pravidlo upright odmietlo.
  pl = NxKonA.plan('depth' => 150, 'thickness' => 50, 'back_thickness' => 50, 'top_mode' => 'two_rails',
                   'rails_orientation' => 'upright')
  NxTest.assert(pl[:parts].any? { |pd| pd[:part_key] == 'cabinet/rail:back' }, 'postavi sa ako dnes')
  NxTest.assert_equal(nil, NxKonA::CN.setback_error(NxKonA::CB.normalize('depth' => 150)))
  # Najplytsie legalne kombinacie pri X = Y = 0 — ziadna veta KON-A.
  %w[overlay inset groove none].each do |bm|
    %w[full none two_rails].each do |tm|
      %w[flat upright].each do |ori|
        cfg = NxKonA::CB.normalize('depth' => 150, 'back_mode' => bm, 'top_mode' => tm, 'rails_orientation' => ori,
                                   'back_thickness' => 50, 'thickness' => 50)
        NxTest.assert_equal(nil, NxKonA::CN.setback_error(cfg), "#{bm}/#{tm}/#{ori}: bez vety KON-A")
      end
    end
  end
end

# ============================================================================
# 4. NIKA SPOTREBICA (M9)
# ============================================================================

NxTest.test('KON-A: nika pri komine z hlbky BOKU — Kontrola niky aj ponuka „zmesti sa" rovnake cislo (M6)') do
  ac = Noxun::Engine::ApplianceChecks
  panel = Noxun::Engine::Panel
  fr = NxKonA.stored('height' => 2100, 'depth' => 560, 'back_mode' => 'none', 'back_setback' => 50)
  NxTest.assert_equal(560.0, ac.context(fr)['interior']['depth'], 'Kontrola niky meria 560 (hlbka boku)')
  NxTest.assert_equal(560.0, panel.appliance_interior(fr)['depth'], 'ponuka „zmesti sa" tiez 560')
  ov = NxKonA.stored('depth' => 580, 'back_setback' => 50)
  NxTest.assert_equal(580.0, ac.context(ov)['interior']['depth'], 'aj s nalozenym chrbtom: hlbka boku')
  [NxKonA.stored('depth' => 560, 'back_mode' => 'none'), NxKonA.stored('depth' => 580),
   NxKonA.stored('type' => 'upper')].each do |cfg|
    bfy = NxKonA::CN.interior_dims(NxKonA::CB.normalize(NxKonA::CB.config_to_params(cfg)))[:back_front_y]
    NxTest.assert_equal(bfy.round(2), ac.context(cfg)['interior']['depth'], 'X = 0: dnesne meranie po chrbat')
    NxTest.assert_equal(ac.context(cfg)['interior']['depth'], panel.appliance_interior(cfg)['depth'], 'oba citatelia zhodne')
  end
end

# ============================================================================
# 5. MIERKA (SCALE)
# ============================================================================

NxTest.test('KON-A: min_valid_depth — sonda cez cely plan (komin, zapustenie, vystuhy, minimum vnutra)') do
  cn = NxKonA::CN
  cb = NxKonA::CB
  NxTest.assert_equal(150.0, cn.min_valid_depth(cb.normalize({})), 'bez komina = MIN[:depth]')
  NxTest.assert_equal(160.0, cn.min_valid_depth(cb.normalize('back_setback' => 100)),
                      'komin 100 + nalozeny chrbat + plny strop: najmenej 160 (strop 60)')
  NxTest.assert_equal(190.0, cn.min_valid_depth(cb.normalize('back_setback' => 150, 'back_mode' => 'none',
                                                             'top_mode' => 'none')),
                      'minimum vnutra 40 pri komine sa dedi (audit BLOCKER 1)')
  NxTest.assert_equal(163.0, cn.min_valid_depth(cb.normalize('top_front_setback' => 100)), 'zapustenie 100: strop 60')
  up = cb.normalize('back_setback' => 60, 'back_mode' => 'none', 'top_mode' => 'two_rails',
                    'rails_orientation' => 'upright', 'top_front_setback' => 90)
  NxTest.assert_equal(206.0, cn.min_valid_depth(up), 'upright: Y + 2t + 20 + X')
  %w[back_setback top_front_setback].each do |k|
    cfg = cb.normalize(k => 100)
    d = cn.min_valid_depth(cfg)
    cn.build_plan(cfg.merge(depth: d), 'CAB-S')
    NxTest.assert_raise { cn.build_plan(cfg.merge(depth: d - 1), 'CAB-S') }
  end
  NxTest.assert_equal(0.0, cn.min_valid_depth(cb.normalize('type' => 'dishwasher')), 'slot: bez konstrukcneho minima')
end

NxTest.test('KON-A: ScaleWatch.clamp_depth — klamp na min_valid_depth + nemodalna hlaska; absorpcia sonduje len pri zmenseni') do
  sw = Noxun::Engine::ScaleWatch
  params = NxKonA::CB.config_to_params(NxKonA.stored('back_setback' => 100))
  d, note = sw.clamp_depth(params, 150.0, 'CAB-004')
  NxTest.assert_equal(160.0, d)
  NxTest.assert_equal('Hĺbka skrinky CAB-004 je pri komíne 100 mm najmenej 160 mm — nastavená na 160.', note)
  d2, note2 = sw.clamp_depth(params, 300.0, 'CAB-004')
  NxTest.assert_equal([300.0, nil], [d2, note2], 'platna hlbka ostava, bez hlasky')
  plain = NxKonA::CB.config_to_params(NxKonA.stored({}))
  NxTest.assert_equal([150.0, nil], sw.clamp_depth(plain, 150.0, 'CAB-1'), 'bez komina: ziadna hlaska')
  zp = NxKonA::CB.config_to_params(NxKonA.stored('top_front_setback' => 100))
  NxTest.assert(sw.clamp_depth(zp, 150.0, 'CAB-2')[1].include?('pri zapustení stropu 100 mm'), 'veta pri zapusteni')
  src = NxKonA.src('noxun_engine', 'core', 'scale_observer.rb')
  absorb = src[/def absorb\(inst\)(.*?)\n        end\n/m, 1].to_s
  NxTest.assert(absorb.include?('if new_d < base_d'), 'sonda len pri zmenseni hlbky')
  # ROH-A1: sondy dostavaju ucinne hrubky CR list (4. argument).
  NxTest.assert(absorb.include?('clamp_depth(params, new_d, cid'), 'absorpcia klampuje config-aware')
  NxTest.assert(absorb.index('notify_user(') > absorb.index('refresh_panel(model)'),
                'hlaska az po refreshi panela')
  NxTest.assert(absorb.include?('depth_note'), 'veta hlbky ide do tej istej hlasky')
  NxTest.assert(absorb.include?('transparent: true'), 'jeden krok Spat (transparentna operacia)')
end

# ============================================================================
# 6. D-144 — ZASTARANE SKRINKY V REGISTRI VYROBNEJ BRANY
# ============================================================================

NxTest.test('KON-A: D-144 predikat — rezimy ako config_to_params (aj stary vnoreny zapis), schema < 20') do
  b = NxKonA::BOM
  base = { 'config_schema' => 19, 'back_mode' => 'inset', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' }
  NxTest.assert(b.back_rail_stale?(base))
  NxTest.assert(b.back_rail_stale?(base.merge('back_mode' => 'groove')))
  NxTest.refute(b.back_rail_stale?(base.merge('config_schema' => 20)), 'schema 20 nie je zastarana')
  NxTest.refute(b.back_rail_stale?(base.merge('back_mode' => 'overlay')), 'nalozeny chrbat nie')
  NxTest.refute(b.back_rail_stale?(base.merge('back_mode' => 'none')), 'bez chrbta nie')
  NxTest.refute(b.back_rail_stale?(base.merge('rails_orientation' => 'flat')), 'vystuhy naplocho nie')
  NxTest.refute(b.back_rail_stale?(base.reject { |k, _| k == 'rails_orientation' }), 'chybajuca orientacia = flat')
  NxTest.refute(b.back_rail_stale?(base.merge('top_mode' => 'full')), 'plny strop nie')
  legacy = { 'config_schema' => 7, 'back' => { 'mode' => 'groove' }, 'top' => { 'mode' => 'two_rails' },
             'rails_orientation' => 'upright' }
  NxTest.assert(b.back_rail_stale?(legacy), 'stary vnoreny zapis back.mode / top.mode')
  NxTest.assert(b.back_rail_stale?(legacy.reject { |k, _| k == 'config_schema' }), 'bez markera = legacy 0')
  NxTest.refute(b.back_rail_stale?({ 'config_schema' => 19, 'back' => 'x', 'top' => 5 }), 'poskodeny atribut nepadne')
  # Cerstva stavba je vzdy aktualna.
  NxTest.refute(b.back_rail_stale?(NxKonA.stored('back_mode' => 'groove', 'top_mode' => 'two_rails',
                                                 'rails_orientation' => 'upright')), 'prestavana skrinka OK')
end

NxTest.test('KON-A: D-144 nalez — RED, rebuild_stale, veta netvrdi koliziu; register brany ho zastavi') do
  b = NxKonA::BOM
  cfg = { 'config_schema' => 19, 'back_mode' => 'inset', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' }
  iss = b.back_rail_stale_issue('CAB-012', 9, cfg)
  NxTest.assert_equal([b::BACK_RAIL_STALE, 'red', true, nil], [iss['code'], iss['severity'], iss['rebuild_stale'], iss['part_key']])
  NxTest.assert_equal('Skrinka CAB-012 má vložený chrbát spolu s výstuhami na výšku zo staršej verzie — treba ju prestaviť ' \
                      '(chrbát môže prechádzať zadnou výstuhou). Kontrola → Prestaviť zastarané skrinky; dovtedy výrobné ' \
                      'exporty stoja.', iss['message'])
  NxTest.assert(b.back_rail_stale_issue('C', 1, cfg.merge('back_mode' => 'groove'))['message'].include?('má chrbát v drážke'))
  NxTest.assert_equal(nil, b.back_rail_stale_issue('C', 1, cfg.merge('config_schema' => 20)))
  NxTest.assert(b::CUT_BLOCKERS.include?(b::BACK_RAIL_STALE), 'ten isty register ako D-143')
  NxTest.assert(NxKonA::PC::CUT_BLOCKER_TEXTS.key?(b::BACK_RAIL_STALE), 'veta brany')
  msg = NxKonA::PC.cut_stop({ cut_issues: [iss] })
  NxTest.assert(msg.to_s.include?('NEVYKONAL') && msg.include?('CAB-012') && msg.include?('výstuhách na výšku'), msg.to_s)
  items = Noxun::Engine::Validation.run({ records: [], cut_issues: [iss] })['items']
  it = items.find { |i| i['category'] == Noxun::Engine::Validation::CAT_BACK_CUT }
  NxTest.assert_equal(%w[red rebuild_stale], [it['severity'], it['fix']], 'Kontrola RED + ponuka prestavby')
end

NxTest.test('KON-A: D-144 spolocny vyber kandidatov hromadnej prestavby (D-143 ALEBO D-144, M8)') do
  pc = NxKonA::PC
  d143 = { 'config_schema' => 18, 'back_mode' => 'groove' }
  d144 = { 'config_schema' => 19, 'back_mode' => 'inset', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' }
  ok = NxKonA.stored({})
  entries = [pc.back_stale_entry('CAB-1', d143, false), pc.back_stale_entry('CAB-2', d144, false),
             pc.back_stale_entry('CAB-3', ok, false), pc.back_stale_entry('CAB-4', d144, true)]
  NxTest.assert_equal([true, true, false, true], entries.map { |e| e['stale'] }, 'D-144 je kandidat rovnako ako D-143')
  plan = pc.back_stale_plan(entries)
  NxTest.assert_equal(%w[CAB-1 CAB-2], plan['jobs'].map { |e| e['id'] })
  NxTest.assert_equal(['CAB-4'], plan['skipped'].map(&:first), 'odpojeny dielec: vymenuje a necha blokovanu')
  NxTest.assert_equal(3, plan['stale'])
  done = pc.back_stale_done_msg(plan)
  NxTest.assert(done.start_with?('Prestavané zastarané skrinky: 2 (chrbát je teraz podľa aktuálnej verzie; jeden krok Späť)'), done)
  NxTest.refute(done.include?('v plnom rozmere'), 'veta uz nehovori len o drazke (audit FIX 6)')
  NxTest.assert_equal('Žiadna skrinka nie je zastaraná — nič sa neprestavovalo.',
                      pc.back_stale_empty_msg(pc.back_stale_plan([pc.back_stale_entry('CAB-3', ok, false)])))
  # Vyber ide VYHRADNE cez spolocny predikat (zdroj).
  src = NxKonA.src('noxun_engine', 'ui', 'production_core.rb')
  NxTest.assert(src.include?("'stale' => Bom.rebuild_stale?(c)"), 'back_stale_entry sa pyta spolocneho predikatu')
end

NxTest.test('KON-A: text D-143 pocita rozmer do narezu pravidlom buildera — pri D-144 600 x 538 (audit FIX 6)') do
  b = NxKonA::BOM
  both = { 'config_schema' => 18, 'back_mode' => 'groove', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright',
           'width' => 600.0, 'height' => 720.0, 'floor_height' => 100.0, 'thickness' => 18.0, 'depth' => 510.0,
           'back_thickness' => 3.0, 'rail_depth' => 100.0, 'rails_top_offset' => 0.0 }
  m = b.back_stale_issue('CAB-9', 1, both)['message']
  NxTest.assert(m.include?('(600 × 538)'), m)
  plain = both.merge('top_mode' => 'full')
  NxTest.assert(b.back_stale_issue('CAB-9', 1, plain)['message'].include?('(600 × 620)'), 'bez vystuh plny rozmer')
  # Obe brany naraz — dva nalezy, obe v registri.
  NxTest.assert(b.back_rail_stale?(both), 'ta ista skrinka je aj D-144')
  NxTest.assert_equal(b.stale_back_cut_dims(both),
                      begin
                        bk = NxKonA.part(NxKonA.plan(NxKonA::CB.config_to_params(both)), 'cabinet/back')
                        [bk[:cut_size][:length], bk[:cut_size][:width]]
                      end, 'text = to iste cislo, ake po prestavbe vyda builder')
end

NxTest.test('KON-A (predrecenzia P3): texty chrbta v drazke netvrdia „plny rozmer" (pri D-144 ide do narezu 600 x 538)') do
  %w[noxun_engine/ui/panel.html noxun_engine/core/bom.rb noxun_engine/ui/panel/payloads.rb].each do |rel|
    NxTest.refute(NxKonA.src(*rel.split('/')).include?('v plnom rozmere'), "#{rel}: veta o plnom rozmere")
  end
  msg = NxKonA::BOM.send(:back_edged_message, { 'owner_id' => 'CAB-1', 'name' => 'Chrbat' })
  NxTest.assert(msg.include?('plná šírka skrinky'), msg)
end

# ============================================================================
# 7. KONZUMENTI VNUTRA (vedoma vyrobna zmena, M10)
# ============================================================================

NxTest.test('KON-A: konzumenti — automaticka NL sa pri komine skrati, zamknuta nezmestena = RED, HL vyklop = RED') do
  df = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
         'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }
  nl = lambda do |x|
    pl = NxKonA.plan('fronts' => { 'items' => [df] }, 'back_setback' => x)
    sl = pl[:hardware].find { |h| h['generic_type'] == 'slide' }
    sl ? sl['params']['nominal_length'] : pl[:drawer_conflicts].map { |c| c['code'] }
  end
  NxTest.assert_equal(470.0, nl.call(0), 'bez komina NL 470')
  NxTest.assert_equal(350.0, nl.call(100), 'komin 100: NL sa sama skrati na 350')
  NxTest.assert_equal(['drawer_no_fit'], nl.call(200), 'nezmesti sa nic = RED (existujuce)')
  base = NxKonA.plan('fronts' => { 'items' => [df] })
  rid = base[:hardware].find { |h| h['generic_type'] == 'slide' }['rule_id']
  lock = [{ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide', 'rule_id' => rid, 'nominal_length' => 470.0 }]
  locked = NxKonA.plan('fronts' => { 'items' => [df] }, 'back_setback' => 100, 'hardware_overrides' => lock)
  NxTest.assert_equal(['nl_lock_invalid'], locked[:drawer_conflicts].map { |c| c['code'] }, 'zamknuta NL, ktora sa nezmesti')
  lift = { 'id' => 'F1', 'type' => 'lift', 'mode' => 'auto', 'height' => nil, 'opening_mode' => 'classic',
           'lift' => { 'system' => 'hl_top' } }
  hl = lambda do |x|
    NxKonA.plan('type' => 'upper', 'height' => 400, 'fronts' => { 'items' => [lift] }, 'back_setback' => x)[:hardware_conflicts]
      .map { |c| c['code'] }
  end
  NxTest.refute(hl.call(56).include?('lift_dimension_unsupported'), 'HL: vnutro 264 este staci')
  NxTest.assert(hl.call(57).include?('lift_dimension_unsupported'), 'HL: vnutro 263 = RED')
end

# ============================================================================
# 8. SCHEMA
# ============================================================================

NxTest.test('KON-A: CONFIG_SCHEMA >= 20 + HISTORIA + aktivacna schema D-144 = 20, ostatne sa nehybu') do
  cb = NxKonA::CB
  # KON-B · K2 bumpla na 21 (chrbat z list) — vlastne cislo drzi jej sada.
  NxTest.assert(cb::CONFIG_SCHEMA >= 20, 'schema pod KON-A neklesne')
  NxTest.assert_equal(20, cb::BACK_RAIL_ACTIVATION_SCHEMA)
  NxTest.assert_equal([5, 9, 11, 19], [cb::DRAWER_ACTIVATION_SCHEMA, cb::HINGE_ACTIVATION_SCHEMA,
                                       cb::LIFT_ACTIVATION_SCHEMA, cb::BACK_CUT_ACTIVATION_SCHEMA])
  NxTest.assert(NxKonA.src('noxun_engine', 'core', 'cabinet_builder.rb').include?('#  20 = KON-A · K1'),
                'HISTORIA hovori, preco sa bumplo')
  NxTest.assert(cb.newer_config?({ 'config_schema' => cb::CONFIG_SCHEMA + 1 }))
  NxTest.refute(cb.newer_config?({ 'config_schema' => 20 }))
  NxTest.assert_equal(cb::CONFIG_SCHEMA, NxKonA.stored('back_setback' => 50)['config_schema'])
  NxTest.assert_equal(1, Noxun::Engine::PartKeys::SCHEMA, 'PartKeys bez zmeny')
end
