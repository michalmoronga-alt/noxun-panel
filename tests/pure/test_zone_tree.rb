# frozen_string_literal: true
# Testy noxun_engine/core/zone_tree.rb (+ modules/shelves.rb pre policove zony).
# Cisto vypoctovy modul (mm Float) — ziadne katalogy/APPDATA, ziadny skip,
# bezi headless aj v SketchUpe. Standardny box vnutra: 600 x 500 x 700 mm, t = 18.
require_relative '../helper' unless defined?(NxTest)

NxTest.test('zone_tree: default_tree vytvori koren Z1 bez splitu') do
  zt = Noxun::Engine::ZoneTree
  tree = zt.default_tree(2)
  NxTest.assert_equal('Z1', tree['id'])
  NxTest.assert_equal(0, tree['generation'])
  NxTest.assert_equal(nil, tree['split'])
  NxTest.assert_equal(2, tree['shelves'])
  NxTest.assert_equal([], tree['children'])
  # default_node clampuje police cez Shelves.clamp a generation drzi >= 0
  NxTest.assert_equal(4, zt.default_node(9)['shelves'])
  NxTest.assert_equal(0, zt.default_node(-3)['shelves'])
  NxTest.assert_equal(0, zt.default_node(0, 'X', -5)['generation'])
end

NxTest.test('zone_tree: sanitize akceptuje symbolove kluce aj legacy at_mm') do
  zt = Noxun::Engine::ZoneTree
  raw = { id: :Z1, generation: 2, shelves: 3,
          split: { axis: :h, count: 2,
                   cuts: [{ at_mm: '300', locked: 'true' }, {}] },
          children: [{ shelves: 2 }, nil] }
  out = zt.sanitize(raw)
  NxTest.assert_equal('Z1', out['id'])
  NxTest.assert_equal(2, out['generation'])
  NxTest.assert_equal('h', out['split']['axis'])
  NxTest.assert_equal(2, out['split']['count'])
  cuts = out['split']['cuts']
  NxTest.assert_close(300.0, cuts[0]['size'])   # legacy at_mm string -> Float size
  NxTest.assert_equal(true, cuts[0]['locked'])  # locked ako string 'true'
  NxTest.assert_equal(nil, cuts[1]['size'])
  NxTest.assert_equal(false, cuts[1]['locked'])
  NxTest.assert_equal(0, out['shelves']) # deleny uzol ma police vzdy 0
  # deti: symbolove kluce a nil dieta; legacy id deterministicky podla cesty
  NxTest.assert_equal(2, out['children'].size)
  NxTest.assert_equal('Z1_1', out['children'][0]['id'])
  NxTest.assert_equal(2, out['children'][0]['shelves'])
  NxTest.assert_equal('Z1_2', out['children'][1]['id'])
  NxTest.assert_equal(0, out['children'][1]['shelves'])
end

NxTest.test('zone_tree: sanitize normalizuje os, count a doplna deti') do
  zt = Noxun::Engine::ZoneTree
  out = zt.sanitize('id' => 'R', 'split' => { 'axis' => 'x', 'count' => 9 })
  NxTest.assert_equal('v', out['split']['axis'])     # neznama os -> 'v'
  NxTest.assert_equal(4, out['split']['count'])      # clamp 2..4
  NxTest.assert_equal(4, out['children'].size)       # chybajuce deti sa doplnia
  NxTest.assert_equal(4, out['split']['cuts'].size)
  NxTest.assert_equal(%w[Z1_1 Z1_2 Z1_3 Z1_4], out['children'].map { |c| c['id'] })
  out2 = zt.sanitize('split' => { 'axis' => 'h', 'count' => 1 })
  NxTest.assert_equal(2, out2['split']['count'])     # count < 2 -> 2
  # nehashovy vstup = default uzol s id podla cesty
  out3 = zt.sanitize(nil)
  NxTest.assert_equal('Z1', out3['id'])
  NxTest.assert_equal(nil, out3['split'])
  NxTest.assert_equal(0, out3['shelves'])
end

NxTest.test('zone_tree: sanitize cisti znaky id a dedupuje duplicity') do
  zt = Noxun::Engine::ZoneTree
  raw = { 'id' => 'A B/c', 'split' => { 'axis' => 'v', 'count' => 2 },
          'children' => [{ 'id' => 'DUP' }, { 'id' => 'DUP' }] }
  out = zt.sanitize(raw)
  NxTest.assert_equal('A_B_c', out['id']) # PartKeys.segment: nepovolene znaky -> _
  NxTest.assert_equal('DUP', out['children'][0]['id'])
  NxTest.assert_equal('DUP-2', out['children'][1]['id']) # dedup suffix
  # canonical_node_id priamo: prazdne id -> cesta; druha kolizia dostane -2
  state = { used: {} }
  NxTest.assert_equal('Z1_2', zt.canonical_node_id('', [1, 2], state))
  NxTest.assert_equal('Z1_2-2', zt.canonical_node_id(nil, [1, 2], state))
end

NxTest.test('zone_tree: resolve_fields kumulativny clamp zamknutych (2x500 v 600)') do
  zt = Noxun::Engine::ZoneTree
  # Toto deterministicky vyvola overflow vetvu s Engine.log (r.274-277) —
  # headless ju kryje stub Noxun::Engine.log, test overuje ze nespadne.
  cuts = [{ 'size' => 500, 'locked' => true }, { 'size' => 500, 'locked' => true }]
  sizes = zt.resolve_fields(cuts, 2, 600.0, 18.0)
  # clear = 600 - 18 = 582; faktor 582/1000 -> obe polia 291, sucet drzi v spane
  NxTest.assert_close(291.0, sizes[0])
  NxTest.assert_close(291.0, sizes[1])
  NxTest.assert_close(582.0, sizes.reduce(0.0, :+))
  # s nezamknutym susedom sa mu najprv rezervuje MIN_FIELD (20 mm)
  cuts3 = [{ 'size' => 500, 'locked' => true }, { 'size' => 500, 'locked' => true },
           { 'size' => nil, 'locked' => false }]
  sizes3 = zt.resolve_fields(cuts3, 3, 600.0, 18.0)
  # clear = 600 - 36 = 564; avail = 544 -> locked 272 + 272, nezamknute 20
  NxTest.assert_close(272.0, sizes3[0])
  NxTest.assert_close(272.0, sizes3[1])
  NxTest.assert_close(20.0, sizes3[2])
end

NxTest.test('zone_tree: resolve_fields identita ked sucet sedi so spanom') do
  zt = Noxun::Engine::ZoneTree
  cuts = [{ 'size' => 382.0, 'locked' => false }, { 'size' => 400.0, 'locked' => false }]
  # clear = 800 - 18 = 782 = 382 + 400 -> rozmery drzia presne (fix #5)
  sizes = zt.resolve_fields(cuts, 2, 800.0, 18.0)
  NxTest.assert_close(382.0, sizes[0])
  NxTest.assert_close(400.0, sizes[1])
end

NxTest.test('zone_tree: resolve_fields proporcny prepocet nezamknutych pri resize') do
  zt = Noxun::Engine::ZoneTree
  cuts = [{ 'size' => 382.0, 'locked' => false }, { 'size' => 400.0, 'locked' => false }]
  # span narastie na 1018 -> clear 1000; pomer 382:400 sa zachova
  sizes = zt.resolve_fields(cuts, 2, 1018.0, 18.0)
  NxTest.assert_close(488.49, sizes[0])
  NxTest.assert_close(511.51, sizes[1])
  NxTest.assert_close(1000.0, sizes.reduce(0.0, :+))
end

NxTest.test('zone_tree: resolve_fields zamok drzi rozmer, min velkost, nil zamok') do
  zt = Noxun::Engine::ZoneTree
  # zamknute 500 sa zmesti -> drzi presne, nezamknute dostane zvysok
  sizes = zt.resolve_fields([{ 'size' => 500, 'locked' => true }, { 'size' => nil }], 2, 800.0, 18.0)
  NxTest.assert_close(500.0, sizes[0])
  NxTest.assert_close(282.0, sizes[1])
  # zamknuta velkost pod MIN_FIELD sa dvihne na 20 mm
  sizes2 = zt.resolve_fields([{ 'size' => 5, 'locked' => true }, { 'size' => nil }], 2, 800.0, 18.0)
  NxTest.assert_close(20.0, sizes2[0])
  NxTest.assert_close(762.0, sizes2[1])
  # locked bez size sa sprava ako nezamknute (rovnomerny podiel)
  sizes3 = zt.resolve_fields([{ 'size' => nil, 'locked' => true }, { 'size' => nil }], 2, 800.0, 18.0)
  NxTest.assert_close(391.0, sizes3[0])
  NxTest.assert_close(391.0, sizes3[1])
end

NxTest.test('zone_tree: compute vertikalny split — zony, priecka, geometria') do
  zt = Noxun::Engine::ZoneTree
  box = { x0: 0.0, x1: 600.0, y0: 0.0, y1: 500.0, z0: 0.0, z1: 700.0 }
  tree = { 'id' => 'Z1', 'split' => { 'axis' => 'v', 'count' => 2 },
           'children' => [{ 'id' => 'ZA' }, { 'id' => 'ZB' }] }
  acc = zt.compute(tree, box, 18.0, 'CAB1')
  zones = acc[:zones]
  NxTest.assert_equal(3, zones.size)
  root = zones[0]
  NxTest.assert_equal('CAB1-Z1', root[:id])
  NxTest.assert_equal('Z1', root[:stable_id])
  NxTest.assert_equal(nil, root[:parent])
  NxTest.assert_equal(false, root[:leaf])
  NxTest.assert_close(600.0, root[:width])
  NxTest.assert_close(700.0, root[:height])
  NxTest.assert_close(500.0, root[:depth])
  NxTest.assert_equal('v', root[:split][:axis])
  NxTest.assert_equal(2, root[:split][:count])
  f = root[:split][:fields]
  NxTest.assert_equal(2, f.size)
  NxTest.assert_close(291.0, f[0][:size]) # (600 - 18) / 2
  NxTest.assert_equal(false, f[0][:locked])
  NxTest.assert_equal(false, f[0][:set])  # auto pole (size nil)
  c1 = zones[1]
  c2 = zones[2]
  NxTest.assert_equal('CAB1-Z1.1', c1[:id])
  NxTest.assert_equal('ZA', c1[:stable_id])
  NxTest.assert_equal('CAB1-Z1', c1[:parent])
  NxTest.assert_equal(true, c1[:leaf])
  NxTest.assert_close(0.0, c1[:position][0])
  NxTest.assert_close(291.0, c1[:width])
  NxTest.assert_equal('CAB1-Z1.2', c2[:id])
  NxTest.assert_equal('ZB', c2[:stable_id])
  NxTest.assert_close(309.0, c2[:position][0]) # 291 + 18 (za prieckou)
  NxTest.assert_close(291.0, c2[:width])
  # priecka: dielec plnej hlbky/vysky, part_key viazany na id DELENEHO uzla
  NxTest.assert_equal(1, acc[:dividers].size)
  d = acc[:dividers][0]
  NxTest.assert_equal('divider_v', d[:role])
  NxTest.assert_equal('DIVV-1-1', d[:suffix])
  NxTest.assert_equal('zone:Z1/divider_v:1', d[:part_key])
  NxTest.assert_equal(:korpus, d[:material])
  NxTest.assert_close(291.0, d[:origin][0])
  NxTest.assert_close(0.0, d[:origin][1])
  NxTest.assert_close(0.0, d[:origin][2])
  NxTest.assert_close(18.0, d[:box][0])
  NxTest.assert_close(500.0, d[:box][1])
  NxTest.assert_close(700.0, d[:box][2])
  NxTest.assert_close(700.0, d[:prod][:length])
  NxTest.assert_close(500.0, d[:prod][:width])
  NxTest.assert_close(18.0, d[:prod][:thickness])
end

NxTest.test('zone_tree: compute horizontalny split — priecka vodorovna') do
  zt = Noxun::Engine::ZoneTree
  box = { x0: 0.0, x1: 600.0, y0: 0.0, y1: 500.0, z0: 0.0, z1: 700.0 }
  tree = { 'id' => 'Z1', 'split' => { 'axis' => 'h', 'count' => 2 },
           'children' => [{ 'id' => 'ZD' }, { 'id' => 'ZH' }] }
  acc = zt.compute(tree, box, 18.0, 'CAB1')
  d = acc[:dividers][0]
  NxTest.assert_equal('divider_h', d[:role])
  NxTest.assert_equal('DIVH-1-1', d[:suffix])
  NxTest.assert_equal('zone:Z1/divider_h:1', d[:part_key])
  NxTest.assert_close(0.0, d[:origin][0])
  NxTest.assert_close(341.0, d[:origin][2]) # (700 - 18) / 2
  NxTest.assert_close(600.0, d[:box][0])
  NxTest.assert_close(500.0, d[:box][1])
  NxTest.assert_close(18.0, d[:box][2])
  NxTest.assert_close(600.0, d[:prod][:length])
  NxTest.assert_close(500.0, d[:prod][:width])
  c2 = acc[:zones][2]
  NxTest.assert_close(359.0, c2[:position][2]) # 341 + 18 nad prieckou
  NxTest.assert_close(341.0, c2[:height])
end

NxTest.test('zone_tree: compute police — pozicie cez Shelves a predny inset') do
  zt = Noxun::Engine::ZoneTree
  box = { x0: 0.0, x1: 600.0, y0: 0.0, y1: 500.0, z0: 0.0, z1: 700.0 }
  acc = zt.compute({ 'id' => 'Z1', 'shelves' => 2 }, box, 18.0, 'CAB1')
  NxTest.assert_equal(1, acc[:zones].size)
  NxTest.assert_equal(true, acc[:zones][0][:leaf])
  NxTest.assert_equal(2, acc[:zones][0][:shelves])
  NxTest.assert_equal(0, acc[:dividers].size)
  NxTest.assert_equal(2, acc[:shelves].size)
  layout = Noxun::Engine::Shelves.layout(0.0, 700.0, 18.0, 2)
  s1 = acc[:shelves][0]
  NxTest.assert_equal('SHELF-1-1', s1[:suffix])
  NxTest.assert_equal('zone:Z1/shelf:1', s1[:part_key])
  NxTest.assert_equal('shelf', s1[:role])
  NxTest.assert_close(0.0, s1[:origin][0])
  NxTest.assert_close(20.0, s1[:origin][1])                 # SHELF_FRONT_INSET
  NxTest.assert_close(layout[:shelves][0][:z], s1[:origin][2])
  NxTest.assert_close(221.33, s1[:origin][2])               # gap = (700 - 36) / 3
  NxTest.assert_close(600.0, s1[:box][0])
  NxTest.assert_close(480.0, s1[:box][1])                   # hlbka 500 - inset 20
  NxTest.assert_close(18.0, s1[:box][2])
  NxTest.assert_close(600.0, s1[:prod][:length])
  NxTest.assert_close(480.0, s1[:prod][:width])
  s2 = acc[:shelves][1]
  NxTest.assert_equal('zone:Z1/shelf:2', s2[:part_key])
  NxTest.assert_close(layout[:shelves][1][:z], s2[:origin][2])
  NxTest.assert_close(460.67, s2[:origin][2])
end

NxTest.test('zone_tree: part_key viazany na node id — zmena suseda/poradia ho nemeni') do
  zt = Noxun::Engine::ZoneTree
  box = { x0: 0.0, x1: 600.0, y0: 0.0, y1: 500.0, z0: 0.0, z1: 700.0 }
  tree_ab = { 'id' => 'Z1', 'split' => { 'axis' => 'v', 'count' => 2 },
              'children' => [{ 'id' => 'ZA', 'shelves' => 0 }, { 'id' => 'ZB', 'shelves' => 1 }] }
  tree_ba = { 'id' => 'Z1', 'split' => { 'axis' => 'v', 'count' => 2 },
              'children' => [{ 'id' => 'ZB', 'shelves' => 1 }, { 'id' => 'ZA', 'shelves' => 0 }] }
  acc_ab = zt.compute(tree_ab, box, 18.0, 'CAB1')
  acc_ba = zt.compute(tree_ba, box, 18.0, 'CAB1')
  # priecka patri delenemu uzlu Z1 — na poradi deti nezalezi
  NxTest.assert_equal('zone:Z1/divider_v:1', acc_ab[:dividers][0][:part_key])
  NxTest.assert_equal(acc_ab[:dividers][0][:part_key], acc_ba[:dividers][0][:part_key])
  # polica zony ZB ma rovnaky part_key bez ohladu na to, ci je ZB prva alebo druha
  NxTest.assert_equal(1, acc_ab[:shelves].size)
  NxTest.assert_equal(1, acc_ba[:shelves].size)
  NxTest.assert_equal('zone:ZB/shelf:1', acc_ab[:shelves][0][:part_key])
  NxTest.assert_equal('zone:ZB/shelf:1', acc_ba[:shelves][0][:part_key])
  # renderovaci suffix je naopak podla cesty — ten sa pri presune zmenit smie
  NxTest.assert_equal('SHELF-1_2-1', acc_ab[:shelves][0][:suffix])
  NxTest.assert_equal('SHELF-1_1-1', acc_ba[:shelves][0][:suffix])
end

NxTest.test('zone_tree: validate_split! odmietne nezmyselne delenia') do
  zt = Noxun::Engine::ZoneTree
  box600 = { x0: 0.0, x1: 600.0, y0: 0.0, y1: 500.0, z0: 0.0, z1: 700.0 }
  box100 = box600.merge(x1: 100.0)
  # 4 polia v 100 mm: clear 46 < minimum 80
  NxTest.assert_raise('prilis mala') do
    zt.validate_split!({ 'axis' => 'v', 'count' => 4, 'cuts' => nil }, box100, 18.0, 'ZX')
  end
  # zamknute 700 + nezamknuty sused v spane 600
  NxTest.assert_raise('nezmestia') do
    zt.validate_split!({ 'axis' => 'v', 'count' => 2,
                         'cuts' => [{ 'size' => 700, 'locked' => true },
                                    { 'size' => nil, 'locked' => false }] }, box600, 18.0, 'ZX')
  end
  # vsetky zamknute a nevyplnia zonu (100 + 100 < 582)
  NxTest.assert_raise('nevyplnia') do
    zt.validate_split!({ 'axis' => 'v', 'count' => 2,
                         'cuts' => [{ 'size' => 100, 'locked' => true },
                                    { 'size' => 100, 'locked' => true }] }, box600, 18.0, 'ZX')
  end
  # vsetky zamknute a pretecu (500 + 500 > 582)
  NxTest.assert_raise('nezmestia') do
    zt.validate_split!({ 'axis' => 'v', 'count' => 2,
                         'cuts' => [{ 'size' => 500, 'locked' => true },
                                    { 'size' => 500, 'locked' => true }] }, box600, 18.0, 'ZX')
  end
  # presny sucet (291 + 291 = clear 582) prejde bez vynimky
  zt.validate_split!({ 'axis' => 'v', 'count' => 2,
                       'cuts' => [{ 'size' => 291, 'locked' => true },
                                  { 'size' => 291, 'locked' => true }] }, box600, 18.0, 'ZX')
  # chyba prebuble aj cez compute (walk validuje pred split_boxes)
  bad = { 'id' => 'Z1',
          'split' => { 'axis' => 'v', 'count' => 2,
                       'cuts' => [{ 'size' => 700, 'locked' => true }, {}] },
          'children' => [{}, {}] }
  NxTest.assert_raise('nezmestia') { zt.compute(bad, box600, 18.0, 'CAB1') }
end

NxTest.test('zone_tree: validate_shelves! odmietne prilis nizku zonu') do
  zt = Noxun::Engine::ZoneTree
  low = { x0: 0.0, x1: 600.0, y0: 0.0, y1: 500.0, z0: 0.0, z1: 100.0 }
  # 4 police: minimum 4*18 + 5*20 = 172 > 100
  NxTest.assert_raise('prilis nizka') { zt.validate_shelves!(4, low, 18.0, 'ZX') }
  # count sa clampuje na 4 -> rovnaka chyba aj pre 9
  NxTest.assert_raise('prilis nizka') { zt.validate_shelves!(9, low, 18.0, 'ZX') }
  # 0 polic nehadze nikdy; 2 police v 700 mm prejdu (96 <= 700)
  zt.validate_shelves!(0, low, 18.0, 'ZX')
  zt.validate_shelves!(2, low.merge(z1: 700.0), 18.0, 'ZX')
end

NxTest.test('zone_tree: navigate najde uzol podla cesty, mimo rozsahu nil') do
  zt = Noxun::Engine::ZoneTree
  tree = zt.sanitize('id' => 'Z1', 'split' => { 'axis' => 'v', 'count' => 2 },
                     'children' => [{ 'id' => 'ZA' }, { 'id' => 'ZB' }])
  NxTest.assert(zt.navigate(tree, [1]).equal?(tree), 'koren cesty [1] je samotny strom')
  NxTest.assert_equal('ZB', zt.navigate(tree, [1, 2])['id'])
  NxTest.assert_equal(nil, zt.navigate(tree, [1, 3]))
  NxTest.assert_equal(nil, zt.navigate(tree, [1, 1, 1])) # list nema deti
end

NxTest.test('zone_tree: set_split! a set_field! upravuju strom') do
  zt = Noxun::Engine::ZoneTree
  tree = zt.default_tree
  NxTest.assert_equal(true, zt.set_split!(tree, [1], 'h', 3))
  NxTest.assert_equal('h', tree['split']['axis'])
  NxTest.assert_equal(3, tree['split']['count'])
  NxTest.assert_equal(1, tree['generation']) # topologia bumpne generaciu
  NxTest.assert_equal(3, tree['children'].size)
  ids = tree['children'].map { |c| c['id'] }
  NxTest.assert_equal(3, ids.uniq.size)
  ids.each { |i| NxTest.assert(i =~ /\AZ[0-9a-f]{12}\z/, "nahodne id uzla: #{i.inspect}") }
  # neznama os padne na 'v', count clamp 2..4
  t2 = zt.default_tree
  zt.set_split!(t2, [1], 'x', 0)
  NxTest.assert_equal('v', t2['split']['axis'])
  NxTest.assert_equal(2, t2['split']['count'])
  t3 = zt.default_tree
  zt.set_split!(t3, [1], 'v', 9)
  NxTest.assert_equal(4, t3['split']['count'])
  # set_field!: rozmer + zamok
  NxTest.assert_equal(true, zt.set_field!(tree, [1], 0, 250, true))
  NxTest.assert_close(250.0, tree['split']['cuts'][0]['size'])
  NxTest.assert_equal(true, tree['split']['cuts'][0]['locked'])
  zt.set_field!(tree, [1], 1, 5, false)
  NxTest.assert_close(20.0, tree['split']['cuts'][1]['size']) # min MIN_FIELD
  zt.set_field!(tree, [1], 2, nil, true)
  NxTest.assert_equal(nil, tree['split']['cuts'][2]['size'])
  NxTest.assert_equal(false, tree['split']['cuts'][2]['locked']) # zamok bez rozmeru neexistuje
  NxTest.assert_equal(false, zt.set_field!(tree, [1], 9, 100, true)) # index mimo cuts
end

NxTest.test('zone_tree: set_field_cuts!, set_shelves! a clear_zone!') do
  zt = Noxun::Engine::ZoneTree
  tree = zt.default_tree
  zt.set_split!(tree, [1], 'v', 3)
  # kratsi zoznam sa doplni auto polami na count
  NxTest.assert_equal(true, zt.set_field_cuts!(tree, [1], [{ 'size' => 100, 'locked' => 'true' }]))
  cuts = tree['split']['cuts']
  NxTest.assert_equal(3, cuts.size)
  NxTest.assert_close(100.0, cuts[0]['size'])
  NxTest.assert_equal(true, cuts[0]['locked'])
  NxTest.assert_equal(nil, cuts[1]['size'])
  NxTest.assert_equal(false, cuts[2]['locked'])
  # dlhsi zoznam sa oreze na count
  zt.set_field_cuts!(tree, [1], Array.new(5) { { 'size' => 50, 'locked' => false } })
  NxTest.assert_equal(3, tree['split']['cuts'].size)
  # set_shelves! zrusi split a clampuje pocet
  NxTest.assert_equal(true, zt.set_shelves!(tree, [1], 9))
  NxTest.assert_equal(nil, tree['split'])
  NxTest.assert_equal([], tree['children'])
  NxTest.assert_equal(4, tree['shelves'])
  NxTest.assert_equal(false, zt.set_field_cuts!(tree, [1], [])) # list bez splitu = false
  # clear_zone! vynuluje zonu
  zt.set_shelves!(tree, [1], 2)
  NxTest.assert_equal(true, zt.clear_zone!(tree, [1]))
  NxTest.assert_equal(0, tree['shelves'])
  NxTest.assert_equal(nil, tree['split'])
  NxTest.assert_equal(false, zt.set_shelves!(tree, [1, 5], 1)) # neexistujuca cesta
end
