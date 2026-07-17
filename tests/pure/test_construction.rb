# frozen_string_literal: true
# Testy Construction.build_plan + interior_dims + rail_parts + validate!.
# Cisto vypoctove (ziadne katalogy, ziadny %APPDATA%) - bezia headless aj v SketchUpe.
# cfg sa tvori cez CabinetBuilder.normalize(params) - presne ako v builderi.
# Golden hodnoty fixuju SUCASNE spravanie (buduci BuildPlan kontrakt ich zmeni vedome).
require_relative '../helper' unless defined?(NxTest)

# Bezstavove pomocne metody len pre tento subor (ziadny zdielany mutovatelny stav).
module NxConsHelp
  # Zakladna kostra korpusu - part_key vsetkych 5 dielcov (boky, dno, vrch, chrbat).
  CORE_KEYS = %w[cabinet/side:left cabinet/side:right cabinet/bottom cabinet/top cabinet/back].freeze

  module_function

  def cb
    Noxun::Engine::CabinetBuilder
  end

  def cn
    Noxun::Engine::Construction
  end

  def keys(plan)
    plan[:parts].map { |p| p[:part_key] }
  end

  # Najde dielec podla part_key; chybajuci dielec = fail testu.
  def part(plan, key)
    pd = plan[:parts].find { |p| p[:part_key] == key }
    NxTest.assert(pd, "dielec #{key} chyba v plane")
    pd
  end

  # Porovna trojicu floatov (box / origin) po zlozkach s toleranciou.
  def assert_vec(expected, actual, label)
    NxTest.assert_equal(3, Array(actual).size, "#{label}: ocakavane 3 zlozky")
    expected.each_with_index do |e, i|
      NxTest.assert_close(e, actual[i], 0.01, "#{label}[#{i}]: ocakavane ~#{e}, dostal #{actual[i].inspect}")
    end
  end

  # Porovna prod hash {length, width, thickness}.
  def assert_prod(len, wid, thk, prod, label)
    NxTest.assert_close(len, prod[:length], 0.01, "#{label} prod length")
    NxTest.assert_close(wid, prod[:width], 0.01, "#{label} prod width")
    NxTest.assert_close(thk, prod[:thickness], 0.01, "#{label} prod thickness")
  end

  # Plny cfg (symbolove kluce) pre priame volania interior_dims/rail_parts/validate!.
  def raw_cfg(over = {})
    {
      width: 600.0, height: 720.0, depth: 510.0, thickness: 18.0, floor_height: 100.0,
      bottom_mode: 'under_sides', top_mode: 'full', back_mode: 'overlay', back_thickness: 3.0,
      plinth_mode: 'none', plinth_recess: 50.0,
      rail_depth: 100.0, rails_orientation: 'flat', rails_top_offset: 0.0
    }.merge(over)
  end

  # Zlozitejsi korpus pre identitne testy: v-split + polica + dvojkridlove dvierka.
  # wings su pevne '2' - auto wings by pri zmene sirky prepli single<->left/right kluce.
  # Kazde volanie vrati NOVY hash (ziadny zdielany stav medzi testami).
  def identity_params
    {
      'zone_tree' => { 'split' => { 'axis' => 'v', 'count' => 2 },
                       'children' => [{ 'shelves' => 1 }, { 'shelves' => 0 }] },
      'fronts' => { 'items' => [{ 'type' => 'door', 'wings' => '2' }] }
    }
  end
end

# --- Golden: dolny korpus (LOWER_DEFAULTS cez normalize({})) --------------------

NxTest.test('construction: golden plan dolneho korpusu (normalize({}))') do
  h = NxConsHelp
  cfg = h.cb.normalize({})
  # Sanity defaults z LOWER_DEFAULTS (fixuje kontrakt normalize -> build_plan).
  NxTest.assert_equal('lower', cfg[:type])
  NxTest.assert_equal('under_sides', cfg[:bottom_mode])
  NxTest.assert_equal('full', cfg[:top_mode])
  NxTest.assert_equal('overlay', cfg[:back_mode])
  NxTest.assert_equal('none', cfg[:plinth_mode])
  NxTest.assert_close(100.0, cfg[:floor_height])

  plan = h.cn.build_plan(cfg, 'CAB-001')
  NxTest.assert_equal(NxConsHelp::CORE_KEYS.sort, h.keys(plan).sort, 'mnozina part_key dolneho korpusu')

  # Boky: under_sides -> stoja NA dne (z0 = floor + t), vyska h - z0.
  sl = h.part(plan, 'cabinet/side:left')
  NxTest.assert_equal('side_left', sl[:role])
  h.assert_vec([18.0, 510.0, 602.0], sl[:box], 'SIDE-L box')
  h.assert_vec([0.0, 0.0, 118.0], sl[:origin], 'SIDE-L origin')
  h.assert_prod(602.0, 510.0, 18.0, sl[:prod], 'SIDE-L')

  sr = h.part(plan, 'cabinet/side:right')
  NxTest.assert_equal('side_right', sr[:role])
  h.assert_vec([18.0, 510.0, 602.0], sr[:box], 'SIDE-R box')
  h.assert_vec([582.0, 0.0, 118.0], sr[:origin], 'SIDE-R origin')

  # Dno: under_sides -> plna sirka, na Z = floor_height.
  bo = h.part(plan, 'cabinet/bottom')
  NxTest.assert_equal('bottom', bo[:role])
  h.assert_vec([600.0, 510.0, 18.0], bo[:box], 'BOTTOM box')
  h.assert_vec([0.0, 0.0, 100.0], bo[:origin], 'BOTTOM origin')
  h.assert_prod(600.0, 510.0, 18.0, bo[:prod], 'BOTTOM')

  # Vrch full: medzi bokmi.
  tp = h.part(plan, 'cabinet/top')
  NxTest.assert_equal('top', tp[:role])
  h.assert_vec([564.0, 510.0, 18.0], tp[:box], 'TOP box')
  h.assert_vec([18.0, 0.0, 702.0], tp[:origin], 'TOP origin')

  # Chrbat overlay: ZA korpusom (y = d), plna sirka, vyska h - floor.
  bk = h.part(plan, 'cabinet/back')
  NxTest.assert_equal('back', bk[:role])
  h.assert_vec([600.0, 3.0, 620.0], bk[:box], 'BACK box')
  h.assert_vec([0.0, 510.0, 100.0], bk[:origin], 'BACK origin')
  h.assert_prod(600.0, 620.0, 3.0, bk[:prod], 'BACK')

  # Available: sirka w-2t, vyska z_hi-z_lo, hlbka po celnu hranu chrbta (overlay = d).
  NxTest.assert_close(564.0, plan[:available][:width])
  NxTest.assert_close(584.0, plan[:available][:height])
  NxTest.assert_close(510.0, plan[:available][:depth])

  # Vnutro: jedina listova zona s ID podla cabinet_id.
  NxTest.assert_equal(1, plan[:zones].size)
  zone = plan[:zones].first
  NxTest.assert_equal('CAB-001-Z1', zone[:id])
  NxTest.assert(zone[:leaf], 'koren bez splitu ma byt leaf')
  NxTest.assert_close(564.0, zone[:width])
  NxTest.assert_close(584.0, zone[:height])
  NxTest.assert_close(510.0, zone[:depth])
  NxTest.assert_equal([], plan[:front_items])
  NxTest.assert_equal(0, plan[:wings])
end

# --- Golden: horny korpus (UPPER_DEFAULTS cez normalize type upper) -------------

NxTest.test('construction: golden plan horneho korpusu (normalize type upper)') do
  h = NxConsHelp
  cfg = h.cb.normalize('type' => 'upper')
  # Sanity defaults z UPPER_DEFAULTS: bez sokla, dno medzi bokmi, chrbat v drazke.
  NxTest.assert_equal('upper', cfg[:type])
  NxTest.assert_close(0.0, cfg[:floor_height], 0.01, 'upper ma floor_height vynutene 0')
  NxTest.assert_equal('between_sides', cfg[:bottom_mode])
  NxTest.assert_equal('groove', cfg[:back_mode])
  NxTest.assert_equal('none', cfg[:plinth_mode])
  NxTest.assert_close(320.0, cfg[:depth])

  plan = h.cn.build_plan(cfg, 'CAB-002')
  NxTest.assert_equal(NxConsHelp::CORE_KEYS.sort, h.keys(plan).sort, 'mnozina part_key horneho korpusu')

  # Boky: between_sides -> plna vyska od Z=0.
  sl = h.part(plan, 'cabinet/side:left')
  h.assert_vec([18.0, 320.0, 720.0], sl[:box], 'SIDE-L box')
  h.assert_vec([0.0, 0.0, 0.0], sl[:origin], 'SIDE-L origin')
  h.assert_prod(720.0, 320.0, 18.0, sl[:prod], 'SIDE-L')
  sr = h.part(plan, 'cabinet/side:right')
  h.assert_vec([582.0, 0.0, 0.0], sr[:origin], 'SIDE-R origin')

  # Dno: between_sides -> MEDZI bokmi (w - 2t), na Z=0 (floor 0).
  bo = h.part(plan, 'cabinet/bottom')
  h.assert_vec([564.0, 320.0, 18.0], bo[:box], 'BOTTOM box')
  h.assert_vec([18.0, 0.0, 0.0], bo[:origin], 'BOTTOM origin')
  h.assert_prod(564.0, 320.0, 18.0, bo[:prod], 'BOTTOM')

  tp = h.part(plan, 'cabinet/top')
  h.assert_vec([564.0, 320.0, 18.0], tp[:box], 'TOP box')
  h.assert_vec([18.0, 0.0, 702.0], tp[:origin], 'TOP origin')

  # Chrbat groove: v drazke 10 mm od zadnej hrany, medzi bokmi, medzi dnom a vrchom.
  bk = h.part(plan, 'cabinet/back')
  h.assert_vec([564.0, 3.0, 684.0], bk[:box], 'BACK box')
  h.assert_vec([18.0, 307.0, 18.0], bk[:origin], 'BACK origin')
  h.assert_prod(564.0, 684.0, 3.0, bk[:prod], 'BACK')

  # Available depth = celna hrana chrbta (d - 10 - bt).
  NxTest.assert_close(564.0, plan[:available][:width])
  NxTest.assert_close(684.0, plan[:available][:height])
  NxTest.assert_close(307.0, plan[:available][:depth])
end

# --- Matrix smoke: vsetky konstrukcne varianty --------------------------------

NxTest.test('construction: matrix smoke bottom x top x back x plinth') do
  h = NxConsHelp
  tol = 0.01
  %w[between_sides under_sides].each do |bm|
    %w[full two_rails none].each do |tm|
      %w[overlay inset groove].each do |bkm|
        %w[none front].each do |pm|
          label = "#{bm}/#{tm}/#{bkm}/#{pm}"
          cfg = h.cb.normalize('bottom_mode' => bm, 'top_mode' => tm,
                               'back_mode' => bkm, 'plinth_mode' => pm)
          plan = h.cn.build_plan(cfg, 'CAB-777') # nesmie hodit vynimku
          keys = h.keys(plan)

          # KRITICKE: unikatnost part_key cez cely plan (build_plan sam ju nekontroluje).
          NxTest.assert_equal(keys.uniq.size, keys.size,
                              "#{label}: duplicitne part_key: #{keys.sort.join(', ')}")

          # Pritomnost dielcov podla variantu.
          NxTest.assert_equal(tm == 'full', keys.include?('cabinet/top'), "#{label}: cabinet/top")
          NxTest.assert_equal(tm == 'two_rails', keys.include?('cabinet/rail:front'), "#{label}: rail front")
          NxTest.assert_equal(tm == 'two_rails', keys.include?('cabinet/rail:back'), "#{label}: rail back")
          NxTest.assert_equal(pm == 'front', keys.include?('cabinet/plinth:front'), "#{label}: plinth")
          NxTest.assert(keys.include?('cabinet/back'), "#{label}: chrbat chyba")

          # Essential invarianty kazdeho dielca: kladny box + obalka korpusu.
          # Obalka: X 0..600, Z 0..720, Y 0..510; overlay chrbat smie za d (po d + bt).
          bt = h.cn.back_thickness(cfg)
          plan[:parts].each do |pd|
            pd[:box].each_with_index do |v, i|
              NxTest.assert(v.to_f > 0.0, "#{label} #{pd[:part_key]}: box[#{i}] = #{v.inspect} nie je > 0")
            end
            x0, y0, z0 = pd[:origin]
            sx, sy, sz = pd[:box]
            y_max = pd[:role] == 'back' ? 510.0 + bt : 510.0
            NxTest.assert(x0 >= -tol && x0 + sx <= 600.0 + tol, "#{label} #{pd[:part_key]}: X mimo obalky")
            NxTest.assert(y0 >= -tol && y0 + sy <= y_max + tol, "#{label} #{pd[:part_key]}: Y mimo obalky")
            NxTest.assert(z0 >= -tol && z0 + sz <= 720.0 + tol, "#{label} #{pd[:part_key]}: Z mimo obalky")
          end
        end
      end
    end
  end
end

# --- interior_dims -------------------------------------------------------------

NxTest.test('construction: interior_dims varianty chrbta a vrchu') do
  h = NxConsHelp

  # overlay: vnutro po zadnu stenu (back_front_y = d).
  i1 = h.cn.interior_dims(h.raw_cfg(back_mode: 'overlay'))
  NxTest.assert_close(510.0, i1[:back_front_y])
  NxTest.assert_close(118.0, i1[:z_lo], 0.01, 'z_lo = floor + t')
  NxTest.assert_close(702.0, i1[:z_hi], 0.01, 'z_hi = h - t pri top full')
  NxTest.assert_close(584.0, i1[:avail_h])

  # inset: chrbat medzi bokmi (back_front_y = d - bt).
  i2 = h.cn.interior_dims(h.raw_cfg(back_mode: 'inset'))
  NxTest.assert_close(507.0, i2[:back_front_y])

  # groove: drazka 10 mm od zadnej hrany (back_front_y = d - 10 - bt).
  i3 = h.cn.interior_dims(h.raw_cfg(back_mode: 'groove'))
  NxTest.assert_close(497.0, i3[:back_front_y])

  # groove s hrubym chrbtom 18: d - 10 - 18.
  i4 = h.cn.interior_dims(h.raw_cfg(back_mode: 'groove', back_thickness: 18.0))
  NxTest.assert_close(482.0, i4[:back_front_y])
  NxTest.assert_close(18.0, i4[:back_thickness])

  # top_mode 'none': vnutro az po vrch korpusu (z_hi = h).
  i5 = h.cn.interior_dims(h.raw_cfg(top_mode: 'none'))
  NxTest.assert_close(720.0, i5[:z_hi])
  NxTest.assert_close(602.0, i5[:avail_h])
end

NxTest.test('construction: back_thickness default pri chybajucej alebo nulovej hodnote') do
  h = NxConsHelp

  # Chybajuci kluc -> default 3.0 (HDF).
  cfg_missing = h.raw_cfg(back_mode: 'inset')
  cfg_missing.delete(:back_thickness)
  NxTest.assert_close(3.0, h.cn.back_thickness(cfg_missing))
  NxTest.assert_close(507.0, h.cn.interior_dims(cfg_missing)[:back_front_y])

  # Nula -> default 3.0 (nie nulovy chrbat).
  NxTest.assert_close(3.0, h.cn.back_thickness(h.raw_cfg(back_thickness: 0.0)))
  i = h.cn.interior_dims(h.raw_cfg(back_mode: 'groove', back_thickness: 0.0))
  NxTest.assert_close(497.0, i[:back_front_y])
  NxTest.assert_close(3.0, i[:back_thickness])
end

# --- rail_parts ----------------------------------------------------------------

NxTest.test('construction: rail_parts flat geometria a clamp minima') do
  h = NxConsHelp

  # Flat default: rd = min(rail_depth, d/2 - 10) = min(100, 245) = 100; naplocho pod vrchom.
  rails = h.cn.rail_parts(h.raw_cfg(rails_orientation: 'flat'))
  NxTest.assert_equal(2, rails.size)
  NxTest.assert_equal(%w[rail_front rail_back], rails.map { |r| r[:role] })
  NxTest.assert_equal(['cabinet/rail:front', 'cabinet/rail:back'], rails.map { |r| r[:part_key] })
  rf, rb = rails
  h.assert_vec([564.0, 100.0, 18.0], rf[:box], 'RAIL-F flat box')
  h.assert_vec([18.0, 0.0, 702.0], rf[:origin], 'RAIL-F flat origin')
  h.assert_vec([564.0, 100.0, 18.0], rb[:box], 'RAIL-B flat box')
  h.assert_vec([18.0, 410.0, 702.0], rb[:origin], 'RAIL-B flat origin (d - rd)')
  h.assert_prod(564.0, 100.0, 18.0, rf[:prod], 'RAIL-F flat')

  # Clamp minima: rail_depth 5 -> hlbka vystuhy min 20.
  small = h.cn.rail_parts(h.raw_cfg(rails_orientation: 'flat', rail_depth: 5.0))
  h.assert_vec([564.0, 20.0, 18.0], small[0][:box], 'RAIL-F clamp box')
  h.assert_vec([18.0, 490.0, 702.0], small[1][:origin], 'RAIL-B clamp origin (d - 20)')

  # rails_top_offset posuva vystuhy nadol: z0 = h - off - t.
  off = h.cn.rail_parts(h.raw_cfg(rails_orientation: 'flat', rails_top_offset: 50.0))
  h.assert_vec([18.0, 0.0, 652.0], off[0][:origin], 'RAIL-F offset origin')
  h.assert_vec([18.0, 410.0, 652.0], off[1][:origin], 'RAIL-B offset origin')
end

NxTest.test('construction: rail_parts upright geometria a clamp na vysku') do
  h = NxConsHelp

  # Upright default: rdp = min(100, h - s - t - 10 = 592) = 100; na hranu (hrubka v Y).
  rails = h.cn.rail_parts(h.raw_cfg(rails_orientation: 'upright'))
  NxTest.assert_equal(2, rails.size)
  rf, rb = rails
  h.assert_vec([564.0, 18.0, 100.0], rf[:box], 'RAIL-F upright box')
  h.assert_vec([18.0, 0.0, 620.0], rf[:origin], 'RAIL-F upright origin (z = h - rdp)')
  h.assert_vec([18.0, 492.0, 620.0], rb[:origin], 'RAIL-B upright origin (y = d - t)')
  h.assert_prod(564.0, 100.0, 18.0, rf[:prod], 'RAIL-F upright')

  # Clamp hlbky na vysku: h=200, s=100 -> rdp = min(100, 200-100-18-10=72) = 72.
  low = h.cn.rail_parts(h.raw_cfg(rails_orientation: 'upright', height: 200.0))
  h.assert_vec([564.0, 18.0, 72.0], low[0][:box], 'RAIL-F upright clamp box')
  h.assert_vec([18.0, 0.0, 128.0], low[0][:origin], 'RAIL-F upright clamp origin')

  # Clamp minima: rail_depth 5 -> 20.
  tiny = h.cn.rail_parts(h.raw_cfg(rails_orientation: 'upright', rail_depth: 5.0))
  h.assert_vec([564.0, 18.0, 20.0], tiny[0][:box], 'RAIL-F upright min box')
  h.assert_vec([18.0, 0.0, 700.0], tiny[0][:origin], 'RAIL-F upright min origin')

  # rails_top_offset aj pri upright: z0 = h - off - rdp.
  off = h.cn.rail_parts(h.raw_cfg(rails_orientation: 'upright', rails_top_offset: 50.0))
  h.assert_vec([18.0, 0.0, 570.0], off[0][:origin], 'RAIL-F upright offset origin')
end

# --- validate! -----------------------------------------------------------------

NxTest.test('construction: validate! styri chybove vetvy') do
  h = NxConsHelp

  # 1. Sirka <= 2t + 10 (cez normalize nedosiahnutelne - clampy; priame volanie).
  c1 = h.raw_cfg(width: 40.0)
  NxTest.assert_raise('prilis mala') { h.cn.validate!(c1, h.cn.interior_dims(c1)) }

  # 2. Hlbka: back_front_y <= 10 (overlay d = 10).
  c2 = h.raw_cfg(depth: 10.0)
  NxTest.assert_raise('Hlbka') { h.cn.validate!(c2, h.cn.interior_dims(c2)) }

  # 3. Sokel/podstavec >= vyska korpusu.
  c3 = h.raw_cfg(floor_height: 720.0)
  NxTest.assert_raise('sokel') { h.cn.validate!(c3, h.cn.interior_dims(c3)) }

  # 4. Vnutorna vyska <= 10 (h=200, s=160, t=18 -> avail 4).
  c4 = h.raw_cfg(height: 200.0, floor_height: 160.0)
  NxTest.assert_raise('Vnutorna vyska') { h.cn.validate!(c4, h.cn.interior_dims(c4)) }
end

# --- Stabilita identity (part_key) ---------------------------------------------

NxTest.test('construction: rovnaky cfg da identicke part_keys') do
  h = NxConsHelp
  keys1 = h.keys(h.cn.build_plan(h.cb.normalize(h.identity_params), 'CAB-005'))
  keys2 = h.keys(h.cn.build_plan(h.cb.normalize(h.identity_params), 'CAB-005'))
  NxTest.assert_equal(keys1, keys2, 'dva behy s rovnakym cfg musia dat identicke part_keys (aj poradie)')
  NxTest.assert_equal(keys1.uniq.size, keys1.size, 'part_keys musia byt unikatne')

  # Ocakavana mnozina: korpus + priecka (id uzla Z1) + polica (id uzla Z1_1) + 2 kridla F1.
  expected = NxConsHelp::CORE_KEYS + ['zone:Z1/divider_v:1', 'zone:Z1_1/shelf:1',
                          'front:F1/wing:left', 'front:F1/wing:right']
  NxTest.assert_equal(expected.sort, keys1.sort)
end

NxTest.test('construction: zmena width/height nemeni mnozinu part_keys') do
  h = NxConsHelp
  base = h.keys(h.cn.build_plan(h.cb.normalize(h.identity_params), 'CAB-006')).sort

  wide = h.keys(h.cn.build_plan(
                  h.cb.normalize(h.identity_params.merge('width' => 800.0)), 'CAB-006'
                )).sort
  NxTest.assert_equal(base, wide, 'zmena sirky nesmie zmenit mnozinu part_keys')

  tall = h.keys(h.cn.build_plan(
                  h.cb.normalize(h.identity_params.merge('height' => 900.0)), 'CAB-006'
                )).sort
  NxTest.assert_equal(base, tall, 'zmena vysky nesmie zmenit mnozinu part_keys')
end
