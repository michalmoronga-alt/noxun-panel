# frozen_string_literal: true
# KOV-C1 — `Construction.context_for` (svetly priestor pre recept zasuvky)
# a CHARAKTERIZACIA: surove hranice pribudli ADITIVNE, ulozeny config
# a vsetky vystupy ostavaju bajt na bajt rovnake.
require_relative '../helper' unless defined?(NxTest)

module NxKovC1C
  # Kluce, ktore `ZoneTree` dava do plochych zon (= do ULOZENEHO configu).
  # Novy kluc tu = zmena obsahu modelu, preto guard.
  ZONE_KEYS = %i[id stable_id parent label position width height depth split shelves leaf].freeze

  module_function

  def cb
    Noxun::Engine::CabinetBuilder
  end

  def cn
    Noxun::Engine::Construction
  end

  # Skrinka 900 x 720 x 500 (KD 18, sokel 100) s jednym zasuvkovym celom 175.
  def cfg(over = {})
    cb.normalize({ 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                   'fronts' => { 'items' => [{ 'type' => 'drawer_front', 'mode' => 'fixed',
                                               'height' => 175.0 }] } }.merge(over))
  end

  def plan(over = {})
    cn.build_plan(cfg(over), 'CAB-C1')
  end

  def ctx(over = {})
    c = cfg(over)
    p = cn.build_plan(c, 'CAB-C1')
    cn.context_for(p[:front_items].first, p, c)
  end
end

# --- context_for: zaklad ------------------------------------------------------

NxTest.test('KOV-C1 context: 16 mm offset riadku voci interieru sa ODRATA zo svetlej vysky') do
  c = NxKovC1C.cfg
  p = NxKovC1C.plan
  fb = p[:front_bounds]['F1']
  interior = NxKovC1C.cn.interior_dims(c)
  # celo zacina na floor + gap_bottom = 102, interier az na floor + t = 118
  NxTest.assert_close(102.0, fb[:z0], 0.001, 'spodok riadku cela')
  NxTest.assert_close(118.0, interior[:z_lo], 0.001, 'spodok interieru')
  ctx = NxKovC1C.cn.context_for(p[:front_items].first, p, c)
  NxTest.assert_close(159.0, ctx[:clear_height], 0.001, 'svetla vyska = 277 - 118, nie 175')
end

NxTest.test('KOV-C1 context: svetla sirka je LISTOVA zona (864 pri 900/KD 18)') do
  ctx = NxKovC1C.ctx
  NxTest.assert_close(864.0, ctx[:clear_width], 0.001)
  NxTest.assert_close(18.0, ctx[:side_thickness], 0.001)
  NxTest.assert_equal('front:F1/panel', ctx[:owner_part_key])
  NxTest.assert_equal('F1', ctx[:front_id])
  NxTest.assert_equal([], ctx[:obstructions])
end

NxTest.test('KOV-C1 context: clear_depth == interior[:back_front_y] pre KAZDY rezim chrbta') do
  { 'overlay' => 497.0, 'inset' => 497.0, 'none' => 500.0 }.each do |mode, expected|
    over = { 'back_mode' => mode, 'back_thickness' => 3.0 }
    ctx = NxKovC1C.ctx(over)
    interior = NxKovC1C.cn.interior_dims(NxKovC1C.cfg(over))
    NxTest.assert_close(expected, ctx[:clear_depth], 0.001, "rezim chrbta #{mode}")
    NxTest.assert_close(interior[:back_front_y], ctx[:clear_depth], 0.001, "rezim chrbta #{mode}: zhoda s interierom")
  end
  # drazka: hlbka je este mensia o GROOVE_OFFSET
  groove = NxKovC1C.ctx('back_mode' => 'groove', 'back_thickness' => 3.0)
  NxTest.assert(groove[:clear_depth] < 497.0, 'drazka odobera dalsiu hlbku')
end

NxTest.test('KOV-C1 context: listova zona UZSIA nez korpus da uzsiu svetlu sirku') do
  over = { 'zone_tree' => { 'split' => { 'axis' => 'v', 'count' => 2 },
                            'children' => [{ 'shelves' => 0 }, { 'shelves' => 0 }] } }
  ctx = NxKovC1C.ctx(over)
  NxTest.assert(ctx[:clear_width] < 864.0, "svetla sirka #{ctx[:clear_width]} ma byt zona, nie cely korpus")
  NxTest.assert_close(423.0, ctx[:clear_width], 0.01, 'polovica z 864 minus priecka 18')
  roles = ctx[:obstructions].map { |o| o[:role] }
  NxTest.assert(roles.include?('divider_v'), 'zvisla priecka cez riadok je prekazka')
end

NxTest.test('KOV-C1 context: polica cez riadok = prekazka (C2 z nej robi drawer_obstruction)') do
  # Vysoke celo (400) siaha az k polici v strede zony -> prienik.
  ctx = NxKovC1C.ctx('zone_tree' => { 'shelves' => 1 },
                     'fronts' => { 'items' => [{ 'type' => 'drawer_front', 'mode' => 'fixed',
                                                 'height' => 400.0 }] })
  roles = ctx[:obstructions].map { |o| o[:role] }
  NxTest.assert(roles.include?('shelf'), "police v riadku sa nenasli (#{ctx[:obstructions].inspect})")
  # Nizke celo pod policou prekazku NEMA (prienik musi byt KLADNY).
  NxTest.assert_equal([], NxKovC1C.ctx('zone_tree' => { 'shelves' => 1 })[:obstructions])
end

NxTest.test('KOV-C1 context: prazdna skrinka bez policek nema ziadnu prekazku') do
  NxTest.assert_equal([], NxKovC1C.ctx[:obstructions])
end

NxTest.test('KOV-C1 context: neznamy front_id = hlasna chyba (nikdy tichy default)') do
  c = NxKovC1C.cfg
  p = NxKovC1C.plan
  NxTest.assert_raise('F9') { NxKovC1C.cn.context_for('F9', p, c) }
end

NxTest.test('KOV-C1 context: prijme aj samotne id riadku, nielen resolved polozku') do
  c = NxKovC1C.cfg
  p = NxKovC1C.plan
  a = NxKovC1C.cn.context_for(p[:front_items].first, p, c)
  b = NxKovC1C.cn.context_for('F1', p, c)
  NxTest.assert_equal(a, b)
end

# --- raw vs r2 ----------------------------------------------------------------

NxTest.test('KOV-C1 context: surove hranice NIE su zaokruhlene (r2 by zasuvku ticho povolil)') do
  # Vyska 720,995 posunie strop interieru na hodnotu s tromi desatinnymi miestami.
  c = NxKovC1C.cfg('height' => 720.995)
  p = NxKovC1C.cn.build_plan(c, 'CAB-C1R')
  zid = p[:zones].first[:id]
  raw = p[:zone_bounds][zid]
  NxTest.assert_close(702.995, raw[:z1], 0.0001, 'surova hranica zony')
  NxTest.assert_close(584.995, raw[:z1] - raw[:z0], 0.0001, 'surova vyska zony')
  NxTest.assert_close(585.0, p[:zones].first[:height], 0.0001, 'ulozena (r2) vyska zony ostava zaokruhlena')
  NxTest.assert(raw[:z1] != p[:zones].first[:height] + raw[:z0],
                'raw a r2 kanal sa nesmu zliat')
end

NxTest.test('KOV-C1 context: surove hranice riadku cela NIE su zaokruhlene') do
  c = NxKovC1C.cfg('fronts' => { 'items' => [{ 'type' => 'drawer_front', 'mode' => 'auto' }] },
                   'height' => 720.0)
  p = NxKovC1C.cn.build_plan(c, 'CAB-C1F')
  fb = p[:front_bounds]['F1']
  item = p[:front_items].first
  NxTest.assert_close(616.0, fb[:height], 0.0001, 'auto vyska cela (720 - 100 - 2 - 2)')
  NxTest.assert_close(item['height'], fb[:height], 0.01, 'r2 a raw sa lisia nanajvys o zaokruhlenie')
end

# --- charakterizacia: aditivne, nic sa neulozi ---------------------------------

NxTest.test('KOV-C1 charakterizacia: ploche zony NEMAJU novy kluc (ulozeny config sa nemeni)') do
  NxKovC1C.plan[:zones].each do |z|
    NxTest.assert_equal(NxKovC1C::ZONE_KEYS.sort, z.keys.sort,
                        "zona #{z[:id]} ma iny sortiment klucov — raw_bounds sa nesmie dostat do configu")
  end
end

NxTest.test('KOV-C1 charakterizacia: front_items nesu iba povodne kluce') do
  expected = %w[id type mode height locked wings wings_n profile z].sort
  NxKovC1C.plan[:front_items].each do |it|
    extra = it.keys - expected - Noxun::Engine::Fronts::DORMANT_KEYS - ['flap_dir']
    NxTest.assert_equal([], extra, "front_item ma nove kluce #{extra.inspect}")
  end
end

NxTest.test('KOV-C1 charakterizacia: merge_final NEZAPISE zone_bounds ani front_bounds') do
  c = NxKovC1C.cfg
  p = NxKovC1C.cn.build_plan(c, 'CAB-C1M')
  merged = NxKovC1C.cb.merge_final(c, p)
  NxTest.refute(merged.key?(:zone_bounds), 'zone_bounds sa nesmie ulozit do configu')
  NxTest.refute(merged.key?(:front_bounds), 'front_bounds sa nesmie ulozit do configu')
  NxTest.assert_equal(p[:zones], merged[:zones])
  NxTest.assert_equal(p[:front_items], merged[:front_items])
end

NxTest.test('KOV-C1 charakterizacia: build_plan NEVOLA resolver — plan nema dielce zasuvky') do
  roles = NxKovC1C.plan[:parts].map { |p| p[:role].to_s }
  %w[drawer_bottom drawer_back box_side drawer_inner_front].each do |role|
    NxTest.refute(roles.include?(role), "C1 nesmie stavat dielec #{role} — to je uloha C2")
  end
end
