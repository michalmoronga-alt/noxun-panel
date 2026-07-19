# frozen_string_literal: true
# D-07: nastavitelne medzery a presahy cel (zaporne okraje = presah cez obrys).
# Testuje rozsahy validacie, geometriu presahov a zjednotenie medzery kridiel.
require_relative '../helper' unless defined?(NxTest)

# ---------------------------------------------------------------------------
# Rozsahy validacie: gap 0..50, okraje -100..+100
# ---------------------------------------------------------------------------

NxTest.test('fronts gaps: medzera medzi celami mimo 0..50 pada') do
  f = Noxun::Engine::Fronts
  base = { 'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }

  NxTest.assert_raise(/Medzera medzi celami/) do
    f.layout(base.merge('gap' => -1.0), 600, 720, 100, 18.0)
  end
  NxTest.assert_raise(/Medzera medzi celami/) do
    f.layout(base.merge('gap' => 50.5), 600, 720, 100, 18.0)
  end
  # hranicne hodnoty prejdu
  f.layout(base.merge('gap' => 0.0), 600, 720, 100, 18.0)
  f.layout(base.merge('gap' => 50.0), 600, 720, 100, 18.0)
end

NxTest.test('fronts gaps: okraje mimo -100..+100 padaju, hranicne prejdu') do
  f = Noxun::Engine::Fronts
  base = { 'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }

  NxTest.assert_raise(/Okraj/) { f.layout(base.merge('gap_top' => -101.0), 600, 720, 100, 18.0) }
  NxTest.assert_raise(/Okraj/) { f.layout(base.merge('gap_bottom' => 101.0), 600, 2000, 100, 18.0) }
  NxTest.assert_raise(/Okraj/) { f.layout(base.merge('gap_sides' => -100.5), 600, 720, 100, 18.0) }
  f.layout(base.merge('gap_top' => -100.0), 600, 720, 100, 18.0)
  f.layout(base.merge('gap_sides' => 100.0), 600, 720, 100, 18.0)
end

# ---------------------------------------------------------------------------
# Geometria presahov (zaporne okraje)
# ---------------------------------------------------------------------------

NxTest.test('fronts gaps: zaporny gap_bottom = celo presahuje pod spodnu hranu') do
  f = Noxun::Engine::Fronts
  cfg = { 'gap_bottom' => -30.0,
          'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }
  r = f.layout(cfg, 600, 720, 100, 18.0)
  part = r[:parts].first
  # z = floor_height + gb = 100 - 30 = 70; vyska = total_v - gt - gb = 620 - 2 + 30 = 648
  NxTest.assert_close(70.0, part[:origin][2])
  NxTest.assert_close(648.0, part[:box][2])
  NxTest.assert_close(648.0, r[:items].first['height'])
end

NxTest.test('fronts gaps: zaporny gap_top = celo presahuje nad vrch korpusu') do
  f = Noxun::Engine::Fronts
  cfg = { 'gap_top' => -15.0,
          'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }
  r = f.layout(cfg, 600, 720, 100, 18.0)
  part = r[:parts].first
  top = part[:origin][2] + part[:box][2]
  NxTest.assert_close(735.0, top) # 720 - (-15)
end

NxTest.test('fronts gaps: zaporny gap_sides = celo sirsie nez korpus') do
  f = Noxun::Engine::Fronts
  cfg = { 'gap_sides' => -20.0,
          'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }
  r = f.layout(cfg, 600, 720, 100, 18.0)
  part = r[:parts].first
  NxTest.assert_close(-20.0, part[:origin][0])
  NxTest.assert_close(640.0, part[:box][0]) # 600 + 2*20
end

NxTest.test('fronts gaps: tesny fit so zapornymi okrajmi prejde (required klesa)') do
  f = Noxun::Engine::Fronts
  # total_v = 120; fixed 150 by sa nezmestilo s kladnymi okrajmi,
  # so zapornymi gt/gb (-20/-20) je required = 150 - 40 + 0 = 110 <= 120.
  cfg = { 'gap_top' => -20.0, 'gap_bottom' => -20.0,
          'items' => [{ 'type' => 'door', 'mode' => 'fixed', 'height' => 150.0, 'wings' => '1' }] }
  r = f.layout(cfg, 600, 220, 100, 18.0)
  NxTest.assert_close(150.0, r[:parts].first[:box][2])
end

NxTest.test('fronts gaps: fixed-only — zaporny gap_top je rezerva, geometriu nemeni (Codex B1)') do
  f = Noxun::Engine::Fronts
  # Cela sa kladu odspodu: fixed celo drzi z aj vysku bez ohladu na gap_top;
  # gap_top vstupuje len do fit validacie (tu povoli sucet vyssi nez total_v).
  fixed = [{ 'type' => 'door', 'mode' => 'fixed', 'height' => 200.0, 'wings' => '1' }]
  base = f.layout({ 'items' => fixed }, 600, 720, 100, 18.0)
  over = f.layout({ 'gap_top' => -50.0, 'items' => fixed }, 600, 720, 100, 18.0)
  NxTest.assert_close(base[:parts].first[:origin][2], over[:parts].first[:origin][2])
  NxTest.assert_close(base[:parts].first[:box][2], over[:parts].first[:box][2])
  # fit: total_v=120, fixed 160 > 120 pada s gt=2, prejde s gt=-45 (required 117)
  tight = [{ 'type' => 'door', 'mode' => 'fixed', 'height' => 160.0, 'wings' => '1' }]
  NxTest.assert_raise(/nezmestia do vysky/) { f.layout({ 'items' => tight }, 600, 220, 100, 18.0) }
  f.layout({ 'gap_top' => -45.0, 'items' => tight }, 600, 220, 100, 18.0)
end

NxTest.test('fronts gaps: mixed fixed+auto na hranici MIN_AUTO so zapornymi okrajmi (Codex F7)') do
  f = Noxun::Engine::Fronts
  # total_v = 200; gt=-10, gb=0, gap=0, fixed=200 -> remaining pre auto = 200+10-200 = 10 = presne MIN_AUTO.
  mixed = [{ 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 200.0 },
           { 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }]
  ok = f.layout({ 'gap' => 0.0, 'gap_top' => -10.0, 'gap_bottom' => 0.0, 'items' => mixed },
                600, 300, 100, 18.0)
  auto_part = ok[:parts].last
  NxTest.assert_close(10.0, auto_part[:box][2])
  # o 1 mm mensi priestor (gt=-9) -> auto celo 9 mm < MIN_AUTO -> pada
  NxTest.assert_raise(/nezmestia do vysky/) do
    f.layout({ 'gap' => 0.0, 'gap_top' => -9.0, 'gap_bottom' => 0.0, 'items' => mixed },
             600, 300, 100, 18.0)
  end
end

NxTest.test('fronts gaps: 2 kridla + velka medzera/okraje = zrozumitelna chyba, nie tichy zanik (Codex GH P2)') do
  f = Noxun::Engine::Fronts
  two = [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '2' }]
  # opening_w = 200 - 2*95 = 10; dw = (10-50)/2 zaporne -> raise
  NxTest.assert_raise(/Kridla dvierok/) do
    f.layout({ 'gap' => 50.0, 'gap_sides' => 95.0, 'items' => two }, 200, 720, 100, 18.0)
  end
  # hranica: dw presne MIN_AUTO (ow=30, gap=10 -> dw=10) prejde
  r = f.layout({ 'gap' => 10.0, 'gap_sides' => 85.0, 'items' => two }, 200, 720, 100, 18.0)
  NxTest.assert_close(10.0, r[:parts].first[:box][0])
end

NxTest.test('fronts gaps: resolved items nesu wings_n pre nahlad (1 vs 2 kridla)') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '2' },
                      { 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 150.0 }] }
  r = f.layout(cfg, 500, 720, 100, 18.0)
  NxTest.assert_equal(2, r[:items][0]['wings_n'])
  NxTest.assert_equal(1, r[:items][1]['wings_n'])
end

# ---------------------------------------------------------------------------
# Dvojkridlove dvierka: medzera kridiel = cfg gap (nie konstanta)
# ---------------------------------------------------------------------------

NxTest.test('fronts gaps: medzera medzi kridlami nasleduje cfg gap') do
  f = Noxun::Engine::Fronts
  cfg = { 'gap' => 10.0,
          'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '2' }] }
  r = f.layout(cfg, 800, 720, 100, 18.0)
  left, right = r[:parts]
  ow = 800 - 2 * 2.0
  dw = (ow - 10.0) / 2.0
  NxTest.assert_close(dw, left[:box][0])
  NxTest.assert_close(dw, right[:box][0])
  NxTest.assert_close(2.0 + dw + 10.0, right[:origin][0])
end

NxTest.test('fronts gaps: default medzera kridiel ostava 3 (bez zmeny geometrie)') do
  f = Noxun::Engine::Fronts
  cfg = { 'items' => [{ 'type' => 'door', 'mode' => 'auto', 'wings' => '2' }] }
  r = f.layout(cfg, 800, 720, 100, 18.0)
  left, right = r[:parts]
  dw = (796.0 - 3.0) / 2.0
  NxTest.assert_close(dw, left[:box][0])
  NxTest.assert_close(2.0 + dw + 3.0, right[:origin][0])
end

# ---------------------------------------------------------------------------
# Normalizacia drzi explicitne (aj zaporne) hodnoty
# ---------------------------------------------------------------------------

NxTest.test('fronts gaps: normalize_config drzi explicitne zaporne okraje') do
  f = Noxun::Engine::Fronts
  cfg = f.normalize_config('gap' => 7.5, 'gap_top' => -50.0, 'gap_bottom' => 0.0,
                           'gap_sides' => -12.0, 'items' => [])
  NxTest.assert_close(7.5, cfg['gap'])
  NxTest.assert_close(-50.0, cfg['gap_top'])
  NxTest.assert_close(0.0, cfg['gap_bottom'])
  NxTest.assert_close(-12.0, cfg['gap_sides'])
end
