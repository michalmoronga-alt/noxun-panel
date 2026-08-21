# frozen_string_literal: true
# Testy K2 / D-87 „Vizuálna kontrola smeru kresby" — CISTA geometria ciar
# (bez SketchUpu, bez Overlay API).
#
# Kontrolovane invarianty:
#   1) zdroj smeru je VYHRADNE snapshot dielca (`grain_direction`); 'none',
#      chybajuca a neznama hodnota = dielec sa NEKRESLI,
#   2) ciary bezia po osi, ktoru urcuje SMER + OSI DESKRIPTORA — nikdy po
#      „tej dlhsej" (stvorcove celo by inak vysielo na hlavani),
#   3) pocet ciar je adaptivny podla rozmeru NAPRIEC kresbou (3/4/5) a rozostup
#      je rovnomerny,
#   4) kresli sa na OBE dekorove plochy a POSUVA sa von z telesa (z-fighting),
#   5) neoveritelne osi / degenerovany kvader = ziadna kresba (zasada D-88).
require_relative '../helper' unless defined?(NxTest)

K2 = Noxun::Engine::GrainCheck
K2PF = Noxun::Engine::PartFaces

# Celo: dlzka = VYSKA (Z), sirka = sirka kridla (X), hrubka Y.
K2_AX_FRONT = K2PF::AXES_FRONT
# Polica: dlzka = X, sirka = Y (hlbka), hrubka Z.
K2_AX_LYING = K2PF::AXES_LYING

# Kvader dielca: vysoke uzke dvere 400 x 2000, hrubka 18 (v osiach cela).
K2_FRONT_LO = [0.0, 0.0, 0.0].freeze
K2_FRONT_HI = [400.0, 18.0, 2000.0].freeze

# Ktora suradnica sa v usecke MENI (index osi), alebo nil pri degenerovanej.
def k2_axis_of(seg)
  a, b = seg
  moving = (0..2).select { |i| (a[i] - b[i]).abs > 0.001 }
  moving.length == 1 ? moving.first : nil
end

# --- 1) zdroj smeru = snapshot dielca -----------------------------------------

NxTest.test('K2: smer sa cita zo snapshotu dielca (length/width)') do
  NxTest.assert_equal('length', K2.drawable_grain('grain_direction' => 'length'))
  NxTest.assert_equal('width', K2.drawable_grain('grain_direction' => 'width'))
end

NxTest.test('K2: material bez kresby (none) sa NEKRESLI') do
  NxTest.assert_equal(nil, K2.drawable_grain('grain_direction' => 'none'))
  NxTest.assert_equal([], K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'none'))
end

NxTest.test('K2: chybajuca ani neznama hodnota sa NEPREKLOPI na tichy default') do
  NxTest.assert_equal(nil, K2.drawable_grain({}))
  NxTest.assert_equal(nil, K2.drawable_grain('grain_direction' => 'diagonal'))
  NxTest.assert_equal(nil, K2.drawable_grain(nil))
  NxTest.assert_equal([], K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'diagonal'))
end

# --- 2) smer ciar urcuju OSI DESKRIPTORA, nie velkost rozmerov ----------------

NxTest.test('K2: pozdlzna kresba cela bezi po VYSKE (os dlzky = Z)') do
  segs = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'length')
  NxTest.assert(!segs.empty?, 'ziadne usecky')
  NxTest.assert(segs.all? { |s| k2_axis_of(s) == 2 }, 'ciary nebezia po osi Z')
end

NxTest.test('K2: priecna kresba toho isteho cela bezi KOLMO (os sirky = X)') do
  segs = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'width')
  NxTest.assert(segs.all? { |s| k2_axis_of(s) == 0 }, 'ciary nebezia po osi X')
end

NxTest.test('K2: STVORCOVE celo — smer rozhodne deskriptor, nie „ta dlhsia" strana') do
  lo = [0.0, 0.0, 0.0]
  hi = [600.0, 18.0, 600.0]
  len = K2.segments_mm(lo, hi, K2_AX_FRONT, 'length')
  wid = K2.segments_mm(lo, hi, K2_AX_FRONT, 'width')
  NxTest.assert(len.all? { |s| k2_axis_of(s) == 2 }, 'pozdlzna na stvorci nesmie skocit na X')
  NxTest.assert(wid.all? { |s| k2_axis_of(s) == 0 }, 'priecna na stvorci nesmie skocit na Z')
end

NxTest.test('K2: ta ista hodnota na INEJ ROLI kresli po inej osi (police vs celo)') do
  # Polica 900 x 500 x 18 lezi — os dlzky je X, nie Z.
  segs = K2.segments_mm([0.0, 0.0, 0.0], [900.0, 500.0, 18.0], K2_AX_LYING, 'length')
  NxTest.assert(segs.all? { |s| k2_axis_of(s) == 0 }, 'polica ma dlzku po X')
end

NxTest.test('K2: line_axes vrati [os ciary, os rozostupu] a nil pri poskodenych osiach') do
  NxTest.assert_equal([2, 0], K2.line_axes(K2_AX_FRONT, 'length'))
  NxTest.assert_equal([0, 2], K2.line_axes(K2_AX_FRONT, 'width'))
  NxTest.assert_equal(nil, K2.line_axes(nil, 'length'))
  NxTest.assert_equal(nil, K2.line_axes({ length: 1, width: 0, thickness: 1 }, 'length'))
end

# --- 3) pocet a rozostupy -----------------------------------------------------

NxTest.test('K2: pocet ciar je adaptivny podla rozmeru naprieč kresbou (3/4/5)') do
  NxTest.assert_equal(3, K2.line_count(120.0))
  NxTest.assert_equal(3, K2.line_count(199.9))
  NxTest.assert_equal(4, K2.line_count(200.0))
  NxTest.assert_equal(4, K2.line_count(499.9))
  NxTest.assert_equal(5, K2.line_count(500.0))
  NxTest.assert_equal(5, K2.line_count(2800.0))
end

NxTest.test('K2: uzka blenda dostane 3 ciary na plochu, siroke dvere 4, cely bok 5') do
  # Blenda 150 mm naprieč (pozdlzna kresba => rozostup po X = 150 mm).
  blend = K2.segments_mm([0.0, 0.0, 0.0], [150.0, 18.0, 2000.0], K2_AX_FRONT, 'length')
  NxTest.assert_equal(3 * 2, blend.length) # 3 ciary x 2 dekorove plochy
  # Dvere 400 mm naprieč.
  door = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'length')
  NxTest.assert_equal(4 * 2, door.length)
  # Tie iste dvere s PRIECNOU kresbou: rozostup bezi po vyske 2000 mm.
  side = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'width')
  NxTest.assert_equal(5 * 2, side.length)
end

NxTest.test('K2: ciary su rozostupene ROVNOMERNE a nikdy nelezia na hrane') do
  segs = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'length')
  # rozostup je po osi X (sirka cela 400 mm), 4 ciary => 80 / 160 / 240 / 320
  xs = segs.map { |s| s[0][0] }.uniq.sort
  NxTest.assert_equal([80.0, 160.0, 240.0, 320.0], xs.map { |v| v.round(3) })
  NxTest.assert(xs.first > 0.0 && xs.last < 400.0, 'ciara lezi na bocnej hrane')
end

NxTest.test('K2: ciara nedobieha az k hrane dielca (odsadenie na oboch koncoch)') do
  segs = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'length')
  z0 = segs.map { |s| s[0][2] }.min
  z1 = segs.map { |s| s[1][2] }.max
  NxTest.assert_close(2000.0 * K2::INSET_FRAC, z0, 0.01)
  NxTest.assert_close(2000.0 - 2000.0 * K2::INSET_FRAC, z1, 0.01)
  NxTest.assert(z0 > 0.0 && z1 < 2000.0, 'ciara sa dotyka hrany dielca')
end

# --- 4) obe dekorove plochy + posun von ---------------------------------------

NxTest.test('K2: kresli sa na OBE dekorove plochy a POSUVA sa von z telesa') do
  segs = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'length', 0.6)
  ys = segs.map { |s| s[0][1] }.uniq.sort
  NxTest.assert_equal([-0.6, 18.6], ys.map { |v| v.round(3) })
  # obe plochy nesu rovnaky pocet ciar
  NxTest.assert_equal(segs.length / 2, segs.count { |s| s[0][1] < 0 })
end

NxTest.test('K2: usecka lezi CELA v jednej hlbke (ciara je rovnobezna s plochou)') do
  segs = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, K2_AX_FRONT, 'width')
  NxTest.assert(segs.all? { |s| (s[0][1] - s[1][1]).abs < 0.001 }, 'ciara sa lame do hlbky')
end

NxTest.test('K2: kvader s nenulovym pociatkom (obal definicie) sa nekresli od nuly') do
  segs = K2.segments_mm([100.0, 50.0, 10.0], [500.0, 68.0, 2010.0], K2_AX_FRONT, 'length', 0.0)
  xs = segs.map { |s| s[0][0] }.uniq.sort
  NxTest.assert_equal([180.0, 260.0, 340.0, 420.0], xs.map { |v| v.round(3) })
  NxTest.assert(segs.all? { |s| s[0][2] > 10.0 }, 'ciara zacina pod dolnou hranou dielca')
end

# --- 5) „radsej ziadna kresba nez kresba v zlom smere" -------------------------

NxTest.test('K2: bez overitelnych osi sa NEKRESLI nic') do
  NxTest.assert_equal([], K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, nil, 'length'))
end

NxTest.test('K2: degenerovany kvader (nulovy rozmer) nekresli nic') do
  NxTest.assert_equal([], K2.segments_mm([0.0, 0.0, 0.0], [400.0, 18.0, 0.0], K2_AX_FRONT, 'length'))
  NxTest.assert_equal([], K2.segments_mm([0.0, 0.0, 0.0], [0.0, 18.0, 2000.0], K2_AX_FRONT, 'length'))
end

NxTest.test('K2: poskodene rohy kvadra nekreslia nic (a nepadaju)') do
  NxTest.assert_equal([], K2.segments_mm([0.0, 0.0], K2_FRONT_HI, K2_AX_FRONT, 'length'))
  NxTest.assert_equal([], K2.segments_mm(nil, nil, K2_AX_FRONT, 'length'))
end

# --- 6) osi zo snapshotu su TA ISTA cesta ako pri kontrole hrán ----------------

NxTest.test('K2: osi dielca pri citani z modelu su zdielany kontrakt PartFaces') do
  # Celo 400 x 2000 x 18: rola front_door -> AXES_FRONT (kontrola, ze K2 nema
  # vlastnu mapu roli — pouziva tu istu ako D-104).
  ax = K2PF.axes_for_snapshot('front_door', [400.0, 18.0, 2000.0],
                              'length' => 2000.0, 'width' => 400.0, 'thickness' => 18.0)
  NxTest.assert_equal(K2PF::AXES_FRONT, ax)
  segs = K2.segments_mm(K2_FRONT_LO, K2_FRONT_HI, ax, 'length')
  NxTest.assert(segs.all? { |s| k2_axis_of(s) == 2 }, 'kresba po vyske cela')
end

NxTest.test('K2: farba kresby sa NEMIESA so stavmi kontroly hrán') do
  states = Noxun::Engine::EdgeCheck::COLORS.values.map { |c| c.map(&:to_i) }
  NxTest.refute(states.include?(K2::COLOR.map(&:to_i)),
                'farba smeru kresby sa zhoduje s niektorym stavom olepu')
end

# --- 7) JEDEN ZDROJ STAVU, DVA VSTUPNE BODY (v0.7.27, rail Inspectora) --------
# Prepinac zije v raile aj v okne Vyroba. Keby si kazde okno prepinalo overlay
# samo, stavy by sa rozisli: rail by tvrdil „zapnute" nad modelom, v ktorom uz
# kresba nie je. Preto obe cesty vedu cez Engine.toggle_grain_check a citaju ten
# isty GrainCheck.ui_state.

K2_MAIN = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
K2_PROD = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'),
                    encoding: 'UTF-8')
K2_PANEL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
K2_SYNC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'), encoding: 'UTF-8')
K2_ACT = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_materials.rb'),
                   encoding: 'UTF-8')
K2_CORE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'grain_check.rb'),
                    encoding: 'UTF-8')

NxTest.test('K2: prepnutie ma JEDNU zdielanu cestu (Engine.toggle_grain_check)') do
  shared = K2_MAIN[/def self\.toggle_grain_check.*?\n    end\n/m].to_s
  NxTest.refute(shared.empty?, 'Engine.toggle_grain_check musi existovat')
  NxTest.assert(shared.include?('GrainCheck.toggle('), 'zdielana cesta prepina samotny overlay')
  NxTest.assert(shared.include?('broadcast_grain_check(state)'),
                'po prepnuti sa stav VZDY rozposle (inak druhe okno ostane na starom)')
  NxTest.assert(K2_PROD.include?('Engine.toggle_grain_check(model)'),
                'okno Vyroba musi ist tou istou cestou (ziadny vlastny GrainCheck.toggle)')
  NxTest.assert(K2_ACT.include?('Engine.toggle_grain_check(model)'),
                'rail Inspectora musi ist tou istou cestou')
end

NxTest.test('K2: novy stav dostanu OBE okna (rail aj Vyroba)') do
  cast = K2_MAIN[/def self\.broadcast_grain_check.*?\n    end\n/m].to_s
  NxTest.refute(cast.empty?, 'Engine.broadcast_grain_check rozposiela novy stav')
  NxTest.assert(cast.include?('ProductionDialog.push_grain_check(state)'),
                'okno Vyroba musi dostat novy stav')
  NxTest.assert(cast.include?('Panel.push_grain_check(state)'),
                'rail Inspectora musi dostat novy stav')
  NxTest.assert(cast.include?('defined?(ProductionDialog)') && cast.include?('defined?(Panel)'),
                'push je defenzivny — zavrete okno ho ticho zahodi')
  # Prepocet po prestavbe aj vypnutie pri prepnuti dokumentu idu TOU ISTOU
  # cestou — inak by rail po Spat/Znova ukazoval stare cisla.
  NxTest.assert(K2_CORE.include?('Engine.broadcast_grain_check'),
                'GrainCheck po prepocte/zmene modelu rozposiela stav obom oknam')
  NxTest.refute(K2_CORE.include?('ProductionDialog.push_grain_check'),
                'core nesmie posielat stav LEN oknu Vyroba (rail by zamrzol)')
end

NxTest.test('K2: rail cita ten isty stav a nema vlastnu kopiu') do
  NxTest.assert(K2_SYNC.include?('def grain_check_state'), 'Panel musi vediet stav prečítať')
  NxTest.assert(K2_SYNC.include?('GrainCheck.ui_state(Sketchup.active_model)'),
                'stav je VYHRADNE GrainCheck.ui_state — ziadny druhy vypocet')
  NxTest.assert(K2_SYNC.include?('def push_grain_check'), 'Panel.push_grain_check je protajsok okna')
  NxTest.assert(K2_SYNC.include?('grain_check: grain_check_state'),
                'init panela nesie stav prepinaca (PULL pri otvoreni)')
  NxTest.assert(K2_PANEL_RB.include?("cb(dlg, 'nx_grain_toggle')"),
                'callback raily musi byt zaregistrovany')
end

NxTest.test('K2: rail ma identity guard dokumentu a NEZAPISUJE do modelu') do
  h = K2_ACT[/def handle_grain_toggle.*?\n        end\n/m].to_s
  NxTest.refute(h.empty?, 'handler raily musi existovat')
  NxTest.assert(h.include?('GrainCheck.available?(model)'),
                'starsi SketchUp bez Overlay API sa hlasi nahlas, nie tichym mrtvym tlacidlom')
  NxTest.assert(h.include?("== model_guid(model)"),
                'PRISNY guard dokumentu (asynchronny callback by zapol kresbu v cudzom modeli)')
  NxTest.refute(h.include?('start_operation'), 'kresba je overlay NAD modelom — ziadna operacia')
  NxTest.refute(h.include?('Store.set'), 'rail nesmie nic zapisat do modelu')
end
