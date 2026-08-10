# frozen_string_literal: true
# Testy D-104 „Kontrola hran light" — CISTE rozhodnutie „ktoru hranu zvyraznit"
# a citanie osi zo SNAPSHOTU dielca (bez SketchUpu, bez Overlay API).
#
# Kontrolovane invarianty:
#   1) zvyrazni sa hrana, ktoru PRAVIDLO ziada a dielec ju nema (aj vedome zrusenu),
#   2) NEZVYRAZNI sa: hrana s paskou, rola bez pravidla (chrbat/sokel),
#      nelepitelny material (KOMPAKT / PD postforming), UNI, material mimo katalogu,
#   3) definicia „nelepitelneho" a „UNI" je TA ISTA ako v semafore (Validation),
#   4) osi zo snapshotu: jednoznacna zhoda ANO, ziadna/dvojita zhoda = nil
#      (D-88 zasada „radsej ziadna farba nez farba na zlej hrane"),
#   5) ploska hrany sedi na spravnej stene kvadra a posuva sa VON.
require_relative '../helper' unless defined?(NxTest)

D104 = Noxun::Engine::EdgeCheck
D104PF = Noxun::Engine::PartFaces

def d104_rec(edges, quantity = 1)
  { 'edges' => edges, 'quantity' => quantity }
end

D104_SHEET = { 'material_id' => 'X18', 'type' => 'DTDL', 'thickness' => 18.0 }.freeze
D104_RULE_SHELF = { 'L1' => 1.0 }.freeze
D104_RULE_FRONT = { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }.freeze

# --- 1) zaklad: pravidlo ziada, paska chyba -----------------------------------

NxTest.test('D-104: hrana s pravidlom a bez pasky sa zvyrazni') do
  rec = d104_rec({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal(['L1'], D104.flagged_edges(rec, D104_SHEET, D104_RULE_SHELF))
end

NxTest.test('D-104: hrana S PASKOU sa nezvyrazni') do
  rec = d104_rec({ 'L1' => 'ABS_X_10', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal([], D104.flagged_edges(rec, D104_SHEET, D104_RULE_SHELF))
end

NxTest.test('D-104: prazdny retazec/medzery su „bez pasky"') do
  rec = d104_rec({ 'L1' => '  ', 'L2' => '', 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal(%w[L1 L2], D104.flagged_edges(rec, D104_SHEET,
                                                    { 'L1' => 1.0, 'L2' => 1.0 }))
end

NxTest.test('D-104: celo bez jedinej pasky = vsetky 4 hrany') do
  rec = d104_rec({})
  NxTest.assert_equal(%w[L1 L2 W1 W2], D104.flagged_edges(rec, D104_SHEET, D104_RULE_FRONT))
end

NxTest.test('D-104: hrana BEZ pravidla sa nezvyrazni (chrbat/sokel maju pravidlo prazdne)') do
  rec = d104_rec({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal([], D104.flagged_edges(rec, D104_SHEET, {}))
end

NxTest.test('D-104: sada pravidiel je JEDINA autorita — zmenene pravidlo zmeni vysledok') do
  rec = d104_rec({ 'L1' => 'ABS_X_10', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal(['L2'], D104.flagged_edges(rec, D104_SHEET, { 'L1' => 1.0, 'L2' => 1.0 }))
end

# --- 2) preskocene dielce (zhodne so semaforom) --------------------------------

NxTest.test('D-104: KOMPAKT sa nelepi — nic sa nezvyrazni') do
  sheet = { 'material_id' => 'K12', 'type' => 'KOMPAKT' }
  NxTest.assert(D104.skip_part?(sheet), 'kompakt musi byt preskoceny')
  NxTest.assert_equal([], D104.flagged_edges(d104_rec({}), sheet, D104_RULE_FRONT))
end

NxTest.test('D-104: PD s postformingom sa nelepi; PD s ABS uzaverom ano') do
  post = { 'material_id' => 'PD1', 'type' => 'PD', 'pd_edge_subtype' => 'postforming' }
  abs  = { 'material_id' => 'PD2', 'type' => 'PD', 'pd_edge_subtype' => 'abs' }
  NxTest.assert_equal([], D104.flagged_edges(d104_rec({}), post, D104_RULE_SHELF))
  NxTest.assert_equal(['L1'], D104.flagged_edges(d104_rec({}), abs, D104_RULE_SHELF))
end

NxTest.test('D-104: UNI material (neurceny) sa preskoci — hlasi ho semafor') do
  uni = { 'material_id' => 'UNI_KORPUS', 'type' => 'UNI', 'uni' => true }
  NxTest.assert(D104.skip_part?(uni), 'UNI musi byt preskoceny')
  NxTest.assert_equal([], D104.flagged_edges(d104_rec({}), uni, D104_RULE_FRONT))
end

NxTest.test('D-104: material MIMO katalogu (sheet nil) sa preskoci') do
  NxTest.assert(D104.skip_part?(nil), 'bez katalogoveho zaznamu sa nic netvrdi')
  NxTest.assert_equal([], D104.flagged_edges(d104_rec({}), nil, D104_RULE_FRONT))
end

NxTest.test('D-104: definicie UNI/nelepitelneho su ZHODNE so semaforom (Validation)') do
  v = Noxun::Engine::Validation
  kompakt = { 'type' => 'KOMPAKT' }
  uni = { 'uni' => true }
  NxTest.assert_equal(v.abs_impossible?(kompakt), D104.skip_part?(kompakt))
  NxTest.assert_equal(v.uni_sheet?(uni), D104.skip_part?(uni))
end

# --- 3) pocty kusov -----------------------------------------------------------

NxTest.test('D-104: quantity dielca sa cita (chybajuca/nezmyselna = 1 kus)') do
  NxTest.assert_equal(3, D104.quantity_of(d104_rec({}, 3)))
  NxTest.assert_equal(1, D104.quantity_of(d104_rec({}, 0)))
  NxTest.assert_equal(1, D104.quantity_of({}))
end

# --- 4) osi zo snapshotu ------------------------------------------------------

NxTest.test('D-104: osi police (lezaci panel) sa odvodia jednoznacne') do
  ax = D104PF.axes_for_snapshot('shelf', [564.0, 500.0, 18.0],
                                { 'length' => 564.0, 'width' => 500.0, 'thickness' => 18.0 })
  NxTest.assert_equal(D104PF::AXES_LYING, ax)
end

NxTest.test('D-104: osi cela (dlzka = vyska, hrubka v Y)') do
  ax = D104PF.axes_for_snapshot('front_door', [596.0, 18.0, 715.0],
                                { 'length' => 715.0, 'width' => 596.0, 'thickness' => 18.0 })
  NxTest.assert_equal(D104PF::AXES_FRONT, ax)
end

NxTest.test('D-104: STVORCOVE celo je jednoznacne (kandidat je jediny — rola)') do
  ax = D104PF.axes_for_snapshot('front_door', [600.0, 18.0, 600.0],
                                { 'length' => 600.0, 'width' => 600.0, 'thickness' => 18.0 })
  NxTest.assert_equal(D104PF::AXES_FRONT, ax)
end

NxTest.test('D-104: vystuha naplocho = lezaci panel, na hranu = stena') do
  flat = D104PF.axes_for_snapshot('rail_front', [564.0, 100.0, 18.0],
                                  { 'length' => 564.0, 'width' => 100.0, 'thickness' => 18.0 })
  upright = D104PF.axes_for_snapshot('rail_front', [564.0, 18.0, 100.0],
                                     { 'length' => 564.0, 'width' => 100.0, 'thickness' => 18.0 })
  NxTest.assert_equal(D104PF::AXES_LYING, flat)
  NxTest.assert_equal(D104PF::AXES_WALL, upright)
end

NxTest.test('D-104: vystuha so sirkou ROVNOU hrubke = dva kandidati -> nil (nic sa nezvyrazni)') do
  ax = D104PF.axes_for_snapshot('rail_front', [564.0, 18.0, 18.0],
                                { 'length' => 564.0, 'width' => 18.0, 'thickness' => 18.0 })
  NxTest.assert_equal(nil, ax)
end

NxTest.test('D-104: rozmery nesediace s rolou = nil (ziadne hadanie)') do
  ax = D104PF.axes_for_snapshot('shelf', [564.0, 500.0, 18.0],
                                { 'length' => 500.0, 'width' => 564.0, 'thickness' => 18.0 })
  NxTest.assert_equal(nil, ax)
end

NxTest.test('D-104: neznama rola / chybajuce rozmery = nil') do
  NxTest.assert_equal(nil, D104PF.axes_for_snapshot('nieco_ine', [1.0, 2.0, 3.0],
                                                    { 'length' => 1.0, 'width' => 2.0, 'thickness' => 3.0 }))
  NxTest.assert_equal(nil, D104PF.axes_for_snapshot('shelf', [1.0, 2.0], { 'length' => 1.0 }))
  NxTest.assert_equal(nil, D104PF.axes_for_snapshot('shelf', [564.0, 500.0, 18.0],
                                                    { 'length' => 564.0, 'width' => 500.0 }))
end

NxTest.test('D-104: hranica tolerancie 0,05 mm (round(2) v snapshote nesmie zhodit zhodu)') do
  ok = D104PF.axes_for_snapshot('shelf', [564.04, 500.0, 18.0],
                                { 'length' => 564.0, 'width' => 500.0, 'thickness' => 18.0 })
  bad = D104PF.axes_for_snapshot('shelf', [564.2, 500.0, 18.0],
                                 { 'length' => 564.0, 'width' => 500.0, 'thickness' => 18.0 })
  NxTest.assert_equal(D104PF::AXES_LYING, ok)
  NxTest.assert_equal(nil, bad)
end

# --- 5) ploska hrany ----------------------------------------------------------

NxTest.test('D-104: L1 police lezi na MINIME osi sirky (predna hrana) a posuva sa VON') do
  lo = [0.0, 0.0, 0.0]
  hi = [564.0, 500.0, 18.0]
  rect = D104PF.face_rect_mm('L1', lo, hi, D104PF::AXES_LYING, 0.5)
  NxTest.assert_equal(4, rect.length)
  NxTest.assert(rect.all? { |p| (p[1] - (-0.5)).abs < 1e-9 }, "L1 ma lezat na Y = -0,5: #{rect.inspect}")
  NxTest.assert_equal([0.0, 564.0], [rect.map { |p| p[0] }.min, rect.map { |p| p[0] }.max])
  NxTest.assert_equal([0.0, 18.0], [rect.map { |p| p[2] }.min, rect.map { |p| p[2] }.max])
end

NxTest.test('D-104: W2 police lezi na MAXIME osi dlzky (prava hrana)') do
  rect = D104PF.face_rect_mm('W2', [0.0, 0.0, 0.0], [564.0, 500.0, 18.0], D104PF::AXES_LYING, 0.5)
  NxTest.assert(rect.all? { |p| (p[0] - 564.5).abs < 1e-9 }, "W2 ma lezat na X = 564,5: #{rect.inspect}")
end

NxTest.test('D-104: L1 cela je LAVA hrana (min osi X) — mapovanie sedi s AbsRules labelmi') do
  rect = D104PF.face_rect_mm('L1', [0.0, 0.0, 0.0], [596.0, 18.0, 715.0], D104PF::AXES_FRONT, 0.0)
  labels = Noxun::Engine::AbsRules.edge_labels('front_door')
  NxTest.assert_equal('Ľavá', labels['L1'])
  NxTest.assert(rect.all? { |p| p[0].abs < 1e-9 }, "L1 cela ma lezat na X = 0: #{rect.inspect}")
end

NxTest.test('D-104: neznamy kod hrany / chybajuce osi = nil (nic sa nekresli)') do
  NxTest.assert_equal(nil, D104PF.face_rect_mm('XX', [0.0, 0.0, 0.0], [1.0, 1.0, 1.0], D104PF::AXES_LYING))
  NxTest.assert_equal(nil, D104PF.face_rect_mm('L1', [0.0, 0.0, 0.0], [1.0, 1.0, 1.0], nil))
end

NxTest.test('D-104: posun VON ide v LOKALNYCH osiach (min = minus, max = plus)') do
  lo = [10.0, 20.0, 30.0]
  hi = [110.0, 60.0, 48.0]
  r1 = D104PF.face_rect_mm('L1', lo, hi, D104PF::AXES_LYING, 0.5)
  r2 = D104PF.face_rect_mm('L2', lo, hi, D104PF::AXES_LYING, 0.5)
  NxTest.assert(r1.all? { |p| (p[1] - 19.5).abs < 1e-9 }, 'L1 = min osi sirky - 0,5')
  NxTest.assert(r2.all? { |p| (p[1] - 60.5).abs < 1e-9 }, 'L2 = max osi sirky + 0,5')
end
