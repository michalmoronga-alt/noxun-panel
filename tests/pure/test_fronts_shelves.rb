# frozen_string_literal: true
# Testy pre noxun_engine/modules/fronts.rb + modules/shelves.rb.
# Cisto vypoctove moduly (mm Float) — bezia headless aj v SketchUpe.
require_relative '../helper' unless defined?(NxTest)

# ---------------------------------------------------------------------------
# Fronts — konfiguracia (empty_config, legacy_string, normalize_config)
# ---------------------------------------------------------------------------

NxTest.test('fronts: empty_config ma kanonicky tvar a defaultne medzery') do
  f = Noxun::Engine::Fronts
  cfg = f.empty_config
  NxTest.assert_equal(%w[split_axis gap gap_top gap_bottom gap_sides items], cfg.keys)
  NxTest.assert_equal('height', cfg['split_axis'])
  NxTest.assert_close(3.0, cfg['gap'])
  NxTest.assert_close(2.0, cfg['gap_top'])
  NxTest.assert_close(2.0, cfg['gap_bottom'])
  NxTest.assert_close(2.0, cfg['gap_sides'])
  NxTest.assert_equal([], cfg['items'])
end

NxTest.test('fronts: legacy string none/prazdny/0 -> prazdne items') do
  f = Noxun::Engine::Fronts
  ['none', '', '  ', '0'].each do |s|
    cfg = f.normalize_config(s)
    NxTest.assert_equal([], cfg['items'], "legacy #{s.inspect} ma dat prazdne items")
    NxTest.assert_close(3.0, cfg['gap'])
  end
end

NxTest.test('fronts: legacy string 1/2 -> wings, ine -> auto') do
  f = Noxun::Engine::Fronts
  cfg1 = f.normalize_config('1')
  NxTest.assert_equal(1, cfg1['items'].size)
  it1 = cfg1['items'].first
  NxTest.assert_equal('F1', it1['id'])
  NxTest.assert_equal('door', it1['type'])
  NxTest.assert_equal('auto', it1['mode'])
  NxTest.assert(it1['height'].nil?, 'legacy celo nema pevnu vysku')
  NxTest.assert_equal(false, it1['locked'])
  NxTest.assert_equal('1', it1['wings'])

  NxTest.assert_equal('2', f.normalize_config('2')['items'].first['wings'])
  NxTest.assert_equal('auto', f.normalize_config('auto')['items'].first['wings'])
  NxTest.assert_equal('auto', f.normalize_config('hocico')['items'].first['wings'])
end

NxTest.test('fronts: normalize_config nil -> empty_config, hash defaulty gap/edge') do
  f = Noxun::Engine::Fronts
  NxTest.assert_equal(f.empty_config, f.normalize_config(nil))

  cfg = f.normalize_config({})
  NxTest.assert_close(3.0, cfg['gap'])
  NxTest.assert_close(2.0, cfg['gap_top'])
  NxTest.assert_close(2.0, cfg['gap_bottom'])
  NxTest.assert_close(2.0, cfg['gap_sides'])
  NxTest.assert_equal([], cfg['items'])
end

NxTest.test('fronts: normalize_config berie string aj symbol kluce, explicitne hodnoty vyhravaju') do
  f = Noxun::Engine::Fronts
  cfg_sym = f.normalize_config(gap: 5, gap_top: 0, gap_bottom: '4', gap_sides: 1.5,
                               items: [{ id: 'F1', type: 'door' }])
  NxTest.assert_close(5.0, cfg_sym['gap'])
  NxTest.assert_close(0.0, cfg_sym['gap_top'], 0.01, 'nula je platna hodnota, nie default')
  NxTest.assert_close(4.0, cfg_sym['gap_bottom'])
  NxTest.assert_close(1.5, cfg_sym['gap_sides'])
  NxTest.assert_equal(1, cfg_sym['items'].size)
  NxTest.assert_equal('F1', cfg_sym['items'].first['id'])

  cfg_str = f.normalize_config('gap' => 7, 'items' => [])
  NxTest.assert_close(7.0, cfg_str['gap'])
end

# ---------------------------------------------------------------------------
# Fronts — normalize_items
# ---------------------------------------------------------------------------

NxTest.test('fronts: normalize_items priraduje unikatne id, duplicity a prazdne dostanu F<n>') do
  f = Noxun::Engine::Fronts
  items = f.normalize_items([
    { 'id' => 'F2' },   # explicitne obsadi F2
    { 'id' => '' },     # prazdne -> prve volne F1
    { 'id' => 'F2' },   # duplicita -> preskoci F2, dostane F3
    {}                  # bez id -> F4
  ])
  NxTest.assert_equal(%w[F2 F1 F3 F4], items.map { |it| it['id'] })
end

NxTest.test('fronts: normalize_items cisti id cez PartKeys.segment') do
  f = Noxun::Engine::Fronts
  items = f.normalize_items([{ 'id' => ' moje celo! ' }])
  NxTest.assert_equal('moje_celo_', items.first['id'])
end

NxTest.test('fronts: normalize_items type whitelist door/drawer_front') do
  f = Noxun::Engine::Fronts
  items = f.normalize_items([
    { 'id' => 'A', 'type' => 'drawer_front' },
    { 'id' => 'B', 'type' => 'door' },
    { 'id' => 'C', 'type' => 'polica' },
    { 'id' => 'D' }
  ])
  NxTest.assert_equal(%w[drawer_front door door door], items.map { |it| it['type'] })
end

NxTest.test('fronts: normalize_items mode — fixed bez vysky pada na auto, neznamy mode podla vysky') do
  f = Noxun::Engine::Fronts
  items = f.normalize_items([
    { 'id' => 'A', 'mode' => 'fixed', 'height' => '250' },
    { 'id' => 'B', 'mode' => 'fixed' },                    # fixed bez vysky -> auto
    { 'id' => 'C', 'mode' => 'divny', 'height' => 100 },   # neznamy mode + vyska -> fixed
    { 'id' => 'D', 'mode' => 'divny' },                    # neznamy mode bez vysky -> auto
    { 'id' => 'E', 'mode' => 'auto', 'height' => 100 }     # auto ostava auto, vyska sa zachova
  ])
  NxTest.assert_equal(%w[fixed auto fixed auto auto], items.map { |it| it['mode'] })
  NxTest.assert_close(250.0, items[0]['height'])
  NxTest.assert(items[1]['height'].nil?, 'auto bez vysky ma height nil')
  NxTest.assert_close(100.0, items[4]['height'], 0.01, 'auto s vyskou si hodnotu zachova')
end

NxTest.test('fronts: normalize_items locked len pri fixed, truthy varianty') do
  f = Noxun::Engine::Fronts
  items = f.normalize_items([
    { 'id' => 'A', 'mode' => 'fixed', 'height' => 200, 'locked' => true },
    { 'id' => 'B', 'mode' => 'fixed', 'height' => 200, 'locked' => 'yes' },
    { 'id' => 'C', 'mode' => 'fixed', 'height' => 200, 'locked' => '1' },
    { 'id' => 'D', 'mode' => 'fixed', 'height' => 200, 'locked' => 'nie' },
    { 'id' => 'E', 'mode' => 'auto', 'locked' => true } # auto nikdy locked
  ])
  NxTest.assert_equal([true, true, true, false, false], items.map { |it| it['locked'] })
end

NxTest.test('fronts: normalize_items wings whitelist 1/2/auto, drawer_front vzdy wings=1') do
  f = Noxun::Engine::Fronts
  items = f.normalize_items([
    { 'id' => 'A', 'type' => 'door', 'wings' => '2' },
    { 'id' => 'B', 'type' => 'door', 'wings' => 2 },     # integer -> string '2'
    { 'id' => 'C', 'type' => 'door', 'wings' => '3' },   # mimo whitelist -> auto
    { 'id' => 'D', 'type' => 'door' },                   # default auto
    { 'id' => 'E', 'type' => 'drawer_front', 'wings' => '2' }
  ])
  NxTest.assert_equal(['2', '2', 'auto', 'auto', 1], items.map { |it| it['wings'] })
end

# ---------------------------------------------------------------------------
# Fronts — layout matematika
# ---------------------------------------------------------------------------

NxTest.test('fronts: layout bez items vrati prazdny vysledok') do
  f = Noxun::Engine::Fronts
  out = f.layout(nil, 600.0, 720.0, 100.0, 18.0)
  NxTest.assert_equal({ parts: [], items: [], wings: 0 }, out)
  NxTest.assert_equal({ parts: [], items: [], wings: 0 }, f.layout('none', 600.0, 720.0, 100.0, 18.0))
end

NxTest.test('fronts: layout 2 auto dvierka — auto_h, z postupnost, origin, box, prod') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [{ 'id' => 'F1' }, { 'id' => 'F2' }] }
  out = f.layout(cfg, 600.0, 720.0, 100.0, 18.0)
  # total_v = 720-100 = 620; auto_h = (620 - 2 - 2 - 1*3) / 2 = 306.5
  NxTest.assert_equal(2, out[:parts].size)
  NxTest.assert_equal(2, out[:wings], 'dve jednokridlove dvierka = 2 kridla')

  p1 = out[:parts][0]
  NxTest.assert_equal('DOOR-1', p1[:suffix])
  NxTest.assert_equal('front:F1/wing:single', p1[:part_key])
  NxTest.assert_equal('front_door', p1[:role])
  NxTest.assert_equal(:front, p1[:material])
  NxTest.assert_close(596.0, p1[:box][0]) # opening = 600 - 2*2
  NxTest.assert_close(18.0, p1[:box][1])  # FRONT_THICKNESS
  NxTest.assert_close(306.5, p1[:box][2])
  NxTest.assert_close(2.0, p1[:origin][0])    # gap_sides
  NxTest.assert_close(-18.0, p1[:origin][1], 0.01, 'celo stoji pred korpusom, y = -hrubka')
  NxTest.assert_close(102.0, p1[:origin][2])  # floor_height + gap_bottom
  # KONVENCIA pre VEPO: prod length = vyska cela, width = sirka
  NxTest.assert_close(306.5, p1[:prod][:length])
  NxTest.assert_close(596.0, p1[:prod][:width])
  NxTest.assert_close(18.0, p1[:prod][:thickness])

  p2 = out[:parts][1]
  NxTest.assert_equal('DOOR-2', p2[:suffix])
  NxTest.assert_close(411.5, p2[:origin][2], 0.01, 'z2 = 102 + 306.5 + gap 3')

  i1 = out[:items][0]
  NxTest.assert_equal(%w[id type mode height locked wings z], i1.keys)
  NxTest.assert_equal('F1', i1['id'])
  NxTest.assert_equal('door', i1['type'])
  NxTest.assert_equal('auto', i1['mode'])
  NxTest.assert_close(306.5, i1['height'])
  NxTest.assert_equal(false, i1['locked'])
  NxTest.assert_equal('auto', i1['wings'], 'resolved wings je konfiguracna hodnota, nie pocet kridel')
  NxTest.assert_close(102.0, i1['z'])
  NxTest.assert_close(411.5, out[:items][1]['z'])
end

NxTest.test('fronts: layout siroky otvor nad 600 -> auto 2 kridla, dw = (opening-3)/2') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [{ 'id' => 'F1' }] }
  out = f.layout(cfg, 800.0, 720.0, 100.0, 18.0)
  # opening = 800 - 4 = 796 > AUTO_TWO_ABOVE 600 -> 2 kridla; auto_h = 620-2-2 = 616
  NxTest.assert_equal(2, out[:parts].size)
  NxTest.assert_equal(2, out[:wings])

  left, right = out[:parts]
  NxTest.assert_equal('DOOR-1-L', left[:suffix])
  NxTest.assert_equal('front:F1/wing:left', left[:part_key])
  NxTest.assert_close(396.5, left[:box][0], 0.01, 'dw = (796 - 3) / 2')
  NxTest.assert_close(2.0, left[:origin][0])
  NxTest.assert_close(616.0, left[:box][2])

  NxTest.assert_equal('DOOR-1-R', right[:suffix])
  NxTest.assert_equal('front:F1/wing:right', right[:part_key])
  NxTest.assert_close(396.5, right[:box][0])
  NxTest.assert_close(401.5, right[:origin][0], 0.01, 'x = gs + dw + gap = 2 + 396.5 + 3')
end

NxTest.test('fronts: explicitne wings prepisu auto hranicu 600') do
  f = Noxun::Engine::Fronts
  # siroky otvor (796), ale vynutene 1 kridlo
  out1 = f.layout({ 'items' => [{ 'id' => 'F1', 'wings' => '1' }] }, 800.0, 720.0, 100.0, 18.0)
  NxTest.assert_equal(1, out1[:parts].size)
  NxTest.assert_equal(1, out1[:wings])
  NxTest.assert_close(796.0, out1[:parts][0][:box][0])

  # uzky otvor (596), ale vynutene 2 kridla
  out2 = f.layout({ 'items' => [{ 'id' => 'F1', 'wings' => '2' }] }, 600.0, 720.0, 100.0, 18.0)
  NxTest.assert_equal(2, out2[:parts].size)
  NxTest.assert_close(296.5, out2[:parts][0][:box][0], 0.01, 'dw = (596 - 3) / 2')
end

NxTest.test('fronts: layout mix fixed + auto — auto berie zvysok, z naduvazuje') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [
    { 'id' => 'D1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 200, 'locked' => true },
    { 'id' => 'F2', 'type' => 'door' }
  ] }
  out = f.layout(cfg, 600.0, 720.0, 100.0, 18.0)
  # auto_h = 620 - 2 - 2 - 3 - 200 = 413
  drw = out[:parts][0]
  NxTest.assert_equal('DRW-1', drw[:suffix])
  NxTest.assert_equal('front:D1/panel', drw[:part_key])
  NxTest.assert_equal('drawer_front', drw[:role])
  NxTest.assert_close(200.0, drw[:box][2])
  NxTest.assert_close(102.0, drw[:origin][2])
  NxTest.assert_close(200.0, drw[:prod][:length])
  NxTest.assert_close(596.0, drw[:prod][:width])

  door = out[:parts][1]
  NxTest.assert_equal('DOOR-2', door[:suffix])
  NxTest.assert_close(413.0, door[:box][2])
  NxTest.assert_close(305.0, door[:origin][2], 0.01, 'z = 102 + 200 + gap 3')

  NxTest.assert_equal(1, out[:wings], 'zasuvkove celo sa do kridel nepocita')
  i1, i2 = out[:items]
  NxTest.assert_equal('fixed', i1['mode'])
  NxTest.assert_close(200.0, i1['height'])
  NxTest.assert_equal(true, i1['locked'])
  NxTest.assert_equal(1, i1['wings'], 'drawer_front ma wings ako Integer 1')
  NxTest.assert_equal('auto', i2['mode'])
  NxTest.assert_close(413.0, i2['height'])
end

NxTest.test('fronts: drawer_front je vzdy 1 panel aj pri sirokom otvore') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [{ 'id' => 'D1', 'type' => 'drawer_front' }] }
  out = f.layout(cfg, 800.0, 720.0, 100.0, 18.0)
  NxTest.assert_equal(1, out[:parts].size)
  NxTest.assert_equal('DRW-1', out[:parts][0][:suffix])
  NxTest.assert_close(796.0, out[:parts][0][:box][0])
  NxTest.assert_equal(0, out[:wings])
  NxTest.assert_equal(1, out[:items][0]['wings'])
end

NxTest.test('fronts: layout prijme legacy string priamo') do
  f = Noxun::Engine::Fronts
  out = f.layout('2', 600.0, 720.0, 100.0, 18.0)
  NxTest.assert_equal(2, out[:parts].size, 'legacy 2 vynuti dve kridla aj pod hranicou 600')
  NxTest.assert_equal(2, out[:wings])
  NxTest.assert_equal(1, out[:items].size)
  NxTest.assert_close(616.0, out[:items][0]['height'], 0.01, 'auto_h = 620 - 2 - 2')
end

# ---------------------------------------------------------------------------
# Fronts — validate_layout! (cez layout, substringy sprav)
# ---------------------------------------------------------------------------

NxTest.test('fronts: validate — zaporna medzera') do
  f = Noxun::Engine::Fronts
  cfg = { 'gap' => -1, 'items' => [{ 'id' => 'F1' }] }
  NxTest.assert_raise('Medzery') { f.layout(cfg, 600.0, 720.0, 100.0, 18.0) }
end

NxTest.test('fronts: validate — otvor uzsi ako MIN_AUTO') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [{ 'id' => 'F1' }] }
  # opening = 10 - 2*2 = 6 < 10
  NxTest.assert_raise('nezmestia na sirku') { f.layout(cfg, 10.0, 720.0, 100.0, 18.0) }
end

NxTest.test('fronts: validate — pevna vyska pod 10 mm') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [{ 'id' => 'F1', 'mode' => 'fixed', 'height' => 5 }] }
  NxTest.assert_raise('Pevna vyska') { f.layout(cfg, 600.0, 720.0, 100.0, 18.0) }
end

NxTest.test('fronts: validate — cela sa nezmestia do vysky') do
  f = Noxun::Engine::Fronts
  # total_v = 620, fixed 700 -> required 704 > 620
  cfg = { 'items' => [{ 'id' => 'F1', 'mode' => 'fixed', 'height' => 700 }] }
  NxTest.assert_raise('nezmestia do vysky') { f.layout(cfg, 600.0, 720.0, 100.0, 18.0) }
end

# ---------------------------------------------------------------------------
# Fronts — migrate_legacy_config
# ---------------------------------------------------------------------------

NxTest.test('fronts: migrate_legacy_config — fixed pod MIN_AUTO padne na auto') do
  f = Noxun::Engine::Fronts
  raw = { 'items' => [
    { 'id' => 'A', 'mode' => 'fixed', 'height' => 5, 'locked' => true },
    { 'id' => 'B', 'mode' => 'fixed', 'height' => 50, 'locked' => true }
  ] }
  cfg = f.migrate_legacy_config(raw)
  a, b = cfg['items']
  NxTest.assert_equal('auto', a['mode'])
  NxTest.assert(a['height'].nil?, 'migrovane celo ma height nil')
  NxTest.assert_equal(false, a['locked'])
  NxTest.assert_equal('fixed', b['mode'], 'platne fixed ostava')
  NxTest.assert_close(50.0, b['height'])
  NxTest.assert_equal(true, b['locked'])
end

# ---------------------------------------------------------------------------
# Shelves — layout + clamp
# ---------------------------------------------------------------------------

NxTest.test('shelves: 0 polic = 1 zona cez cely svetly priestor') do
  out = Noxun::Engine::Shelves.layout(0.0, 600.0, 18.0, 0)
  NxTest.assert_equal([], out[:shelves])
  NxTest.assert_equal(1, out[:zones].size)
  NxTest.assert_close(600.0, out[:gap])
  z = out[:zones].first
  NxTest.assert_equal(0, z[:index])
  NxTest.assert_close(0.0, z[:z0])
  NxTest.assert_close(600.0, z[:z1])
  NxTest.assert_close(600.0, z[:height])
end

NxTest.test('shelves: 2 police -> 3 zony, gap = (clear - n*t)/(n+1), pozicie z') do
  out = Noxun::Engine::Shelves.layout(18.0, 702.0, 18.0, 2)
  # clear = 684; gap = (684 - 36) / 3 = 216
  NxTest.assert_close(216.0, out[:gap])
  NxTest.assert_equal(2, out[:shelves].size)
  NxTest.assert_equal(3, out[:zones].size)

  s1, s2 = out[:shelves]
  NxTest.assert_equal(0, s1[:index])
  NxTest.assert_close(234.0, s1[:z], 0.01, 'spodna hrana 1. police = 18 + 216')
  NxTest.assert_close(18.0, s1[:thickness])
  NxTest.assert_close(468.0, s2[:z], 0.01, '234 + 18 + 216')

  z1, z2, z3 = out[:zones]
  NxTest.assert_close(18.0, z1[:z0])
  NxTest.assert_close(234.0, z1[:z1])
  NxTest.assert_close(252.0, z2[:z0])
  NxTest.assert_close(468.0, z2[:z1])
  NxTest.assert_close(486.0, z3[:z0])
  NxTest.assert_close(702.0, z3[:z1], 0.01, 'posledna zona konci na vrchu svetleho priestoru')
  NxTest.assert_close(216.0, z2[:height])
end

NxTest.test('shelves: clamp 0..4 — zaporne na 0, nad MAX na 4') do
  sh = Noxun::Engine::Shelves
  NxTest.assert_equal(0, sh.clamp(-3))
  NxTest.assert_equal(4, sh.clamp(9))
  NxTest.assert_equal(3, sh.clamp('3'))
  NxTest.assert_equal(4, sh.clamp(4))

  out_hi = sh.layout(0.0, 700.0, 18.0, 9)
  NxTest.assert_equal(4, out_hi[:shelves].size)
  NxTest.assert_equal(5, out_hi[:zones].size)

  out_lo = sh.layout(0.0, 700.0, 18.0, -5)
  NxTest.assert_equal([], out_lo[:shelves])
  NxTest.assert_equal(1, out_lo[:zones].size)
end
