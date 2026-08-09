# frozen_string_literal: true
# D-88 (farba ABS na hranach dielca v modeli) + D-102 („podľa pravidla" povie, CO vybralo).
#
# Co sa overuje:
#   1) PartFaces — kontrakt hrana -> plocha kvadra: osi su EXPLICITNY udaj
#      deskriptora (nie odhad z hodnot), overenie proti box/prod, mapovanie
#      stredu plochy na kod hrany, bezpecnostny ventil (nil = nefarbi sa)
#   2) osi REALNYCH deskriptorov (Construction, zone_tree, Fronts, BoardBuilder)
#      — kazdy dielec planu ich ma a sedia s rozmermi; mapovanie sedi so
#      slovenskymi labelmi z AbsRules::EDGE_LABELS (bok = Predna na Y=0 …),
#      vratane STVORCOVEHO cela (miesto, kde by odhad z rozmerov zlyhal)
#   3) BuildPlan.validate_axes! — polovicna/kolizna mapa je chyba planu
#   4) Materials — farba pasky, vlastny namespace SU materialu (NOXUN_ABS_),
#      fallback pre pasku mimo katalogu
#   5) D-102 payloady — text vysledku pravidla (paska / bez ABS / nelepí sa),
#      skratka do nahladu, tooltipy, volba dosky pri nelepitelnom materiali
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

# Payload helpery ziju v ui/panel/payloads.rb (reopen Panel bez SketchUp zavislosti).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')

D88PF   = Noxun::Engine::PartFaces
D88BP   = Noxun::Engine::BuildPlan
D88CON  = Noxun::Engine::Construction
D88CB   = Noxun::Engine::CabinetBuilder
D88BB   = Noxun::Engine::BoardBuilder
D88ABS  = Noxun::Engine::AbsRules
D88MAT  = Noxun::Engine::Materials
D88PAN  = Noxun::Engine::Panel
D88STORE = Noxun::Engine::JsonFileStore

# --- pomocne ---------------------------------------------------------------

# Stred plochy kvadra na danej stene: [os, :min|:max] -> [x, y, z] v mm.
def d88_center(box, axis, side)
  c = box.map { |v| v.to_f / 2.0 }
  c[axis] = side == :min ? 0.0 : box[axis].to_f
  c
end

# Mapa kod hrany -> [os, strana] pre deskriptor (co PartFaces realne vrati).
def d88_map(pd)
  ax = D88PF.verified_axes(pd)
  return nil unless ax
  out = {}
  (0..2).each do |axis|
    %i[min max].each do |side|
      code = D88PF.edge_code_for_center(d88_center(pd[:box], axis, side), pd[:box], ax)
      out[code] = [axis, side] if code
    end
  end
  out
end

def d88_plan(extra = {})
  cfg = D88CB.normalize({ 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
                          'thickness' => 18.0 }.merge(extra))
  D88CON.build_plan(cfg)
end

def d88_part(plan, role)
  plan[:parts].find { |pd| pd[:role].to_s == role }
end

# Katalog pre payload testy (SCHEMA 2 — dnesny ostry rezim).
def d88_with_catalog(sheets, edges)
  path = D88MAT.path
  D88MAT.catalog # seed, aby subor existoval
  before = File.binread(path)
  D88STORE.write(path, { 'std' => D88MAT::STD, 'schema' => 2, 'sheets' => sheets, 'edges' => edges })
  yield
ensure
  if before
    File.binwrite(path, before)
    D88STORE.invalidate(path)
  end
end

D88_SHEET_BIELA = {
  'material_id' => 'D88_BIELA_18', 'manufacturer' => 'Egger', 'decor' => '500 SM',
  'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'none', 'color' => [246, 246, 244],
  'production_class' => 'sheet', 'group_id' => 'GRP-D88BIELA', 'structure' => 'SM'
}.freeze
D88_SHEET_KOMPAKT = {
  'material_id' => 'D88_KOMPAKT_12', 'manufacturer' => 'Egger', 'decor' => 'F800',
  'type' => 'KOMPAKT', 'thickness' => 12.0, 'grain' => 'none', 'color' => [40, 40, 40],
  'production_class' => 'sheet', 'group_id' => 'GRP-D88KOMPAKT', 'structure' => 'ST'
}.freeze
D88_SHEET_BEZPASKY = {
  'material_id' => 'D88_NOABS_18', 'manufacturer' => 'Egger', 'decor' => 'NOABS',
  'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'none', 'color' => [180, 180, 180],
  'production_class' => 'sheet', 'group_id' => 'GRP-D88NOABS', 'structure' => 'SM'
}.freeze
D88_EDGE_HNEDA = {
  'abs_id' => 'D88_ABS_HNEDA_23X10', 'decor' => '500 SM', 'thickness' => 1.0, 'width' => 23.0,
  'color' => [120, 80, 40], 'group_id' => 'GRP-D88BIELA', 'structure' => 'SM'
}.freeze

# ---------------------------------------------------------------------------
# 1) PartFaces — kontrakt
# ---------------------------------------------------------------------------

NxTest.test('D-88: axes su EXPLICITNY udaj deskriptora (chybajuce/kolizne = nil)') do
  ok = { box: [18.0, 500.0, 720.0], prod: { length: 720.0, width: 500.0, thickness: 18.0 },
         axes: D88PF::AXES_UPRIGHT }
  NxTest.assert_equal({ length: 2, width: 1, thickness: 0 }, D88PF.axes(ok))
  NxTest.assert(D88PF.axes(ok.reject { |k, _| k == :axes }).nil?, 'bez osi = nil')
  NxTest.assert(D88PF.axes(ok.merge(axes: { length: 2, width: 2, thickness: 0 })).nil?, 'kolizne osi = nil')
  NxTest.assert(D88PF.axes(ok.merge(axes: { length: 2, width: 1 })).nil?, 'neuplne osi = nil')
  NxTest.assert(D88PF.axes(ok.merge(axes: { length: 3, width: 1, thickness: 0 })).nil?, 'os mimo 0..2 = nil')
  # string kluce (deskriptor po JSON round-tripe)
  NxTest.assert_equal({ length: 2, width: 1, thickness: 0 },
                      D88PF.axes('box' => ok[:box], 'axes' => { 'length' => 2, 'width' => 1, 'thickness' => 0 }))
end

NxTest.test('D-88: verified_axes odmietne osi, ktore NESEDIA s box/prod (ventil proti zlej farbe)') do
  pd = { box: [18.0, 500.0, 720.0], prod: { length: 720.0, width: 500.0, thickness: 18.0 },
         axes: D88PF::AXES_UPRIGHT }
  NxTest.assert(!D88PF.verified_axes(pd).nil?, 'spravne osi prejdu')
  NxTest.assert(D88PF.verified_axes(pd.merge(axes: D88PF::AXES_LYING)).nil?, 'zamenene osi = nil')
  # rozdiel do tolerancie (prod je miestami round(2)) este prejde
  near = { box: [18.0, 500.004, 720.0], prod: { length: 720.0, width: 500.0, thickness: 18.0 },
           axes: D88PF::AXES_UPRIGHT }
  NxTest.assert(!D88PF.verified_axes(near).nil?, 'zaokruhlenie 2 desatin je v tolerancii')
end

NxTest.test('D-88: velke dekorove plochy NEDOSTANU kod hrany (ABS sa ich netyka)') do
  pd = { box: [600.0, 500.0, 18.0], prod: { length: 600.0, width: 500.0, thickness: 18.0 },
         axes: D88PF::AXES_LYING }
  ax = D88PF.verified_axes(pd)
  NxTest.assert(D88PF.edge_code_for_center(d88_center(pd[:box], 2, :min), pd[:box], ax).nil?)
  NxTest.assert(D88PF.edge_code_for_center(d88_center(pd[:box], 2, :max), pd[:box], ax).nil?)
  # stred telesa nie je ziadna plocha
  NxTest.assert(D88PF.edge_code_for_center([300.0, 250.0, 9.0], pd[:box], ax).nil?)
  # presne 4 bocne plochy = presne 4 kody, kazdy raz
  map = d88_map(pd)
  NxTest.assert_equal(%w[L1 L2 W1 W2].sort, map.keys.sort)
end

# ---------------------------------------------------------------------------
# 2) REALNE deskriptory — osi + zhoda so slovenskymi labelmi
# ---------------------------------------------------------------------------

NxTest.test('D-88: KAZDY dielec planu nesie overitelne osi (aj zony, cela, vystuhy, sokel)') do
  [{}, { 'top_mode' => 'two_rails', 'rails_orientation' => 'upright' },
   { 'top_mode' => 'two_rails', 'rails_orientation' => 'flat' },
   { 'plinth_mode' => 'front', 'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto' }] },
     'zone_tree' => { 'id' => 'Z1', 'split' => { 'axis' => 'v', 'count' => 2, 'cuts' => [{ 'size' => nil }, { 'size' => nil }] },
                      'children' => [{ 'id' => 'ZL', 'shelves' => 2, 'children' => [] },
                                     { 'id' => 'ZR', 'shelves' => 0, 'children' => [] }] } },
   { 'back_mode' => 'overlay' }].each do |extra|
    plan = d88_plan(extra)
    NxTest.assert(plan[:parts].length.positive?, 'plan ma dielce')
    plan[:parts].each do |pd|
      NxTest.assert(!D88PF.verified_axes(pd).nil?,
                    "dielec #{pd[:role]}/#{pd[:suffix]} nema overitelne osi (#{pd[:axes].inspect} vs #{pd[:box].inspect})")
    end
  end
end

NxTest.test('D-88: mapovanie hrana -> plocha sedi so slovenskymi labelmi roly') do
  plan = d88_plan('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
                  'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] })
  # bok: dlzka = vyska (Z), sirka = hlbka (Y) -> L1 Predna na Y=0, W1 Dolna na Z=0
  side = d88_map(d88_part(plan, 'side_left'))
  NxTest.assert_equal([1, :min], side['L1'], 'bok L1 (Predná) = Y minimum')
  NxTest.assert_equal([1, :max], side['L2'], 'bok L2 (Zadná) = Y maximum')
  NxTest.assert_equal([2, :min], side['W1'], 'bok W1 (Dolná) = Z minimum')
  NxTest.assert_equal([2, :max], side['W2'], 'bok W2 (Horná) = Z maximum')
  # dno: dlzka = sirka korpusu (X) -> L1 Predna na Y=0, W1 Lava na X=0
  bottom = d88_map(d88_part(plan, 'bottom'))
  NxTest.assert_equal([1, :min], bottom['L1'], 'dno L1 (Predná) = Y minimum')
  NxTest.assert_equal([0, :min], bottom['W1'], 'dno W1 (Ľavá) = X minimum')
  NxTest.assert_equal([0, :max], bottom['W2'], 'dno W2 (Pravá) = X maximum')
  # polica — rovnaka orientacia ako dno
  shelf = d88_map(d88_part(plan, 'shelf'))
  NxTest.assert_equal([1, :min], shelf['L1'], 'polica L1 (Predná) = Y minimum')
  # celo: dlzka = VYSKA (Z), sirka = X -> L1 Lava na X=0, W1 Dolna na Z=0
  front = d88_map(d88_part(plan, 'front_door'))
  NxTest.assert_equal([0, :min], front['L1'], 'celo L1 (Ľavá) = X minimum')
  NxTest.assert_equal([0, :max], front['L2'], 'celo L2 (Pravá) = X maximum')
  NxTest.assert_equal([2, :min], front['W1'], 'celo W1 (Dolná) = Z minimum')
  NxTest.assert_equal([2, :max], front['W2'], 'celo W2 (Horná) = Z maximum')
  # chrbat: dlzka X, sirka = VYSKA (Z) -> L1 Dolna na Z=0, W1 Lava na X=0
  back = d88_map(d88_part(plan, 'back'))
  NxTest.assert_equal([2, :min], back['L1'], 'chrbat L1 (Dolná) = Z minimum')
  NxTest.assert_equal([0, :min], back['W1'], 'chrbat W1 (Ľavá) = X minimum')
  # labely su naozaj tie, o ktorych tvrdime (jeden zdroj = AbsRules)
  NxTest.assert_equal('Predná', D88ABS.edge_labels('side_left')['L1'])
  NxTest.assert_equal('Ľavá', D88ABS.edge_labels('front_door')['L1'])
  NxTest.assert_equal('Dolná', D88ABS.edge_labels('back')['L1'])
end

NxTest.test('D-88: STVORCOVE celo — mapovanie drzi (odhad z rozmerov by tu zlyhal)') do
  # sirka kridla == vyska panelu: hodnoty su nejednoznacne, osi z deskriptora nie su.
  pd = { role: 'front_door', box: [500.0, 18.0, 500.0],
         prod: { length: 500.0, width: 500.0, thickness: 18.0 }, axes: D88PF::AXES_FRONT }
  map = d88_map(pd)
  NxTest.assert_equal([0, :min], map['L1'], 'stvorcove celo: L1 (Ľavá) ostava na X minimum')
  NxTest.assert_equal([2, :min], map['W1'], 'stvorcove celo: W1 (Dolná) ostava na Z minimum')
  # a to iste pre stvorcovu policu (lezaci dielec) — nesmie sa prehodit
  pl = { role: 'shelf', box: [500.0, 500.0, 18.0],
         prod: { length: 500.0, width: 500.0, thickness: 18.0 }, axes: D88PF::AXES_LYING }
  NxTest.assert_equal([1, :min], d88_map(pl)['L1'], 'stvorcova polica: L1 (Predná) na Y minimum')
end

NxTest.test('D-88: vystuha flat aj upright — osi idu z deskriptora, nie z rozmerov') do
  flat = d88_part(d88_plan('top_mode' => 'two_rails', 'rails_orientation' => 'flat'), 'rail_front')
  up   = d88_part(d88_plan('top_mode' => 'two_rails', 'rails_orientation' => 'upright'), 'rail_front')
  NxTest.assert_equal([1, :min], d88_map(flat)['L1'], 'flat vystuha: pozdlzna hrana na Y minimum')
  NxTest.assert_equal([2, :min], d88_map(up)['L1'], 'upright vystuha: pozdlzna hrana na Z minimum')
end

NxTest.test('D-88: samostatna doska lezi (dlzka X, sirka Y, hrubka Z)') do
  d88_with_catalog([D88_SHEET_BIELA], [D88_EDGE_HNEDA]) do
    pd = D88BB.descriptor(D88BB.normalize('length' => 800.0, 'width' => 400.0,
                                          'material_id' => 'D88_BIELA_18'))
    NxTest.assert_equal(D88PF::AXES_LYING, pd[:axes])
    map = d88_map(pd)
    NxTest.assert_equal([1, :min], map['L1'])
    NxTest.assert_equal([0, :min], map['W1'])
  end
end

# ---------------------------------------------------------------------------
# 3) BuildPlan — kontrakt osi
# ---------------------------------------------------------------------------

NxTest.test('D-88: BuildPlan odmietne polovicne aj kolizne axes') do
  base = { part_key: 'cabinet/side:left', suffix: 'SIDE-L', role: 'side_left', name: 'Bok',
           material: :korpus, box: [18.0, 500.0, 720.0], origin: [0.0, 0.0, 0.0],
           prod: { length: 720.0, width: 500.0, thickness: 18.0 } }
  NxTest.assert(!D88BP.validate_part!(base.dup, {}).nil?, 'bez osi je deskriptor stale platny')
  NxTest.assert(!D88BP.validate_part!(base.merge(axes: D88PF::AXES_UPRIGHT), {}).nil?)
  NxTest.assert_raise(/axes/) { D88BP.validate_part!(base.merge(axes: { length: 2, width: 1 }), {}) }
  NxTest.assert_raise(/kolizne axes/) do
    D88BP.validate_part!(base.merge(axes: { length: 1, width: 1, thickness: 0 }), {})
  end
  NxTest.assert_raise(/axes/) { D88BP.validate_part!(base.merge(axes: [2, 1, 0]), {}) }
end

# ---------------------------------------------------------------------------
# 4) Materials — farba pasky a jej SketchUp material
# ---------------------------------------------------------------------------

NxTest.test('D-88: SU material pasky ma VLASTNY namespace (nesmie prepisat dosku rovnakeho ID)') do
  NxTest.assert_equal('NOXUN_ABS_D88_ABS_HNEDA_23X10', D88MAT.su_edge_material_name('D88_ABS_HNEDA_23X10'))
  NxTest.assert(D88MAT.su_edge_material_name('X') != 'X', 'nikdy hole abs_id')
end

NxTest.test('D-88: farba pasky z katalogu; paska mimo katalogu = neutralny fallback') do
  d88_with_catalog([D88_SHEET_BIELA], [D88_EDGE_HNEDA]) do
    NxTest.assert_equal([120, 80, 40], D88MAT.edge_color_of('D88_ABS_HNEDA_23X10'))
    NxTest.assert(D88MAT.edge_color_of('NEEXISTUJE').nil?, 'paska mimo katalogu nema farbu')
    NxTest.assert_equal([176, 190, 197], D88MAT::FALLBACK_EDGE_RGB)
    # doska ostava na svojej farbe (dva katalogy sa nemiesaju)
    NxTest.assert_equal([246, 246, 244], D88MAT.color_of('D88_BIELA_18'))
  end
end

# ---------------------------------------------------------------------------
# 5) D-102 — serverove texty
# ---------------------------------------------------------------------------

NxTest.test('D-102: „podľa pravidla" nesie VYSLEDOK — pasku, „bez ABS" aj „nelepí sa"') do
  d88_with_catalog([D88_SHEET_BIELA, D88_SHEET_BEZPASKY, D88_SHEET_KOMPAKT], [D88_EDGE_HNEDA]) do
    # a) rola s pravidlom nad dekorom, ktory pasku MA
    res = D88PAN.edge_rule_results('shelf', 'D88_BIELA_18', 18.0)
    NxTest.assert(res['L1'].include?('23/1'), "cakam pasku v texte, dostal #{res['L1'].inspect}")
    NxTest.assert_equal('bez ABS', res['L2'], 'hrana bez pravidla = bez ABS')
    # b) dekor bez pasky — pravidlo existuje, ale vysledok je nic
    res2 = D88PAN.edge_rule_results('shelf', 'D88_NOABS_18', 18.0)
    NxTest.assert_equal('bez ABS', res2['L1'])
    # c) KOMPAKT — ABS defaulty su potlacene (M-C)
    res3 = D88PAN.edge_rule_results('front_door', 'D88_KOMPAKT_12', 12.0)
    NxTest.assert_equal('nelepí sa', res3['L1'])
    NxTest.assert_equal('nelepí sa', res3['W2'])
  end
end

NxTest.test('D-102: karta dielca posiela HOTOVE texty volby aj popiskov nahladu') do
  d88_with_catalog([D88_SHEET_BIELA], [D88_EDGE_HNEDA]) do
    cfg = { 'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0,
            'material_id' => 'D88_BIELA_18',
            'edges' => { 'L1' => 'D88_ABS_HNEDA_23X10', 'L2' => nil, 'W1' => nil, 'W2' => nil } }
    out = D88PAN.part_edge_texts('shelf', cfg)
    NxTest.assert(out['edge_rule_options']['L1'].start_with?('(podľa pravidla — '),
                  "cakam serverovy text volby, dostal #{out['edge_rule_options']['L1'].inspect}")
    NxTest.assert(out['edge_rule_options']['L1'].end_with?(')'))
    NxTest.assert_equal('(podľa pravidla — bez ABS)', out['edge_rule_options']['L2'])
    # tooltip = nazov strany + vysledok; skratka = sirka/hrubka pasky
    NxTest.assert(out['edge_hints']['L1']['title'].start_with?('Predná — '),
                  out['edge_hints']['L1']['title'].to_s)
    NxTest.assert_equal('23/1', out['edge_hints']['L1']['short'])
    NxTest.assert_equal('Zadná — bez ABS', out['edge_hints']['L2']['title'])
    NxTest.assert_equal('', out['edge_hints']['L2']['short'], 'hrana bez pasky nema skratku')
  end
end

NxTest.test('D-102: karta dosky — „Bez ABS" povie „nelepí sa" pri nelepitelnom materiali') do
  d88_with_catalog([D88_SHEET_BIELA, D88_SHEET_KOMPAKT], [D88_EDGE_HNEDA]) do
    plain = D88PAN.board_edge_texts('free_panel', 'material_id' => 'D88_BIELA_18',
                                                  'edges' => { 'L1' => 'D88_ABS_HNEDA_23X10' })
    NxTest.assert_equal('Bez ABS', plain['edge_none_option'])
    NxTest.assert_equal('23/1', plain['edge_hints']['L1']['short'])
    comp = D88PAN.board_edge_texts('free_panel', 'material_id' => 'D88_KOMPAKT_12', 'edges' => {})
    NxTest.assert_equal('Bez ABS (nelepí sa)', comp['edge_none_option'])
    NxTest.assert_equal('Pozdĺžna 1 — nelepí sa', comp['edge_hints']['L1']['title'])
  end
end

NxTest.test('D-102: hrubka pre ABS picker je JEDNA autorita (zdielana s builderom)') do
  sheet = { 'thickness' => 19.0 }
  NxTest.assert_close(19.0, D88CB.abs_pick_thickness(sheet, 18.0), 0.001, 'katalogova hrubka vitazi')
  NxTest.assert_close(18.0, D88CB.abs_pick_thickness(nil, 18.0), 0.001, 'bez sheetu plati dielec')
  NxTest.assert_close(18.0, D88CB.abs_pick_thickness({ 'thickness' => 0.0 }, 18.0), 0.001, 'nekladna sa ignoruje')
  NxTest.assert_close(18.0, D88CB.abs_pick_thickness({ 'thickness' => 25.0, 'uni' => true }, 18.0), 0.001,
                      'UNI hrubku neurcuje')
end
