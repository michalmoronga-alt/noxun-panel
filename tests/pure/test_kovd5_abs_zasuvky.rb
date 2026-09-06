# frozen_string_literal: true
# KOV-D5 — ABS FARBENIE DIELCOV ZASUVIEK: osi (`axes:`) pre roly zasuvky +
# orientacia hran STOJACICH roli (L1 = HORNA plocha) ako JEDNA zdielana mapa.
#
# Co sa overuje:
#   1) kazdy dielec zasuvky (Atira: dno + chrbat; Quadro: dno + 2 boky +
#      vnutorne celo + chrbat) nesie OVERITELNE osi z pomenovanej konstanty
#   2) `axes_for_snapshot` (citanie UZ POSTAVENEJ zakazky, kde osi na entite
#      nie su) vrati pre kazdu drawer rolu PRAVE jedneho kandidata
#   3) STOJACE roly (`drawer_back`, `box_side`, `drawer_inner_front`) maju
#      L1 = HORNU plochu (maximum osi vysky), L2 dolnu, W1/W2 lavu/pravu resp.
#      prednu/zadnu — presne to, co hovoria `AbsRules::EDGE_LABELS`
#   4) JEDNO miesto pravdy: farbenie (`CabinetBuilder.paint_edge_faces`),
#      Kontrola (`EdgeCheck`) aj hover (`HoverEdge`) posielaju ROLU do
#      `PartFaces` a vlastnu mapu hrana -> stena nemaju
#   5) charakterizacia: korpusove dielce (bok, polica, dno, celo, chrbat,
#      sokel, vystuhy) mapuju hrany PRESNE ako pred D5 a recept ani ABS
#      pravidla sa nemenia; do vyrobneho snapshotu (kusovnik/VEPO) sa `axes`
#      nedostanu
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1 `STANDING_EDGE_FACES` L1 spat na minimum osi sirky -> „L1 = HORNA plocha"
#   M2 dielec zasuvky bez `axes:` -> „kazdy dielec zasuvky nesie overitelne osi"
#   M3 `EdgeCheck` vola `face_rect_mm` BEZ roly -> zdrojovy guard jedneho miesta
#   M4 `box_side` chyba v `ROLE_AXES` -> „stary model bez `axes` osi dopocita"
#   M5 `AbsRules::STANDING_ROLES` ako vlastny literal -> „jediny zoznam roli"
require_relative '../helper' unless defined?(NxTest)

module NxD5
  E   = Noxun::Engine
  PF  = E::PartFaces
  ABS = E::AbsRules
  CB  = E::CabinetBuilder
  CN  = E::Construction
  BP  = E::BuildPlan
  REC = E::Recipes

  # Zdrojove subory pre guardy „jedneho miesta pravdy".
  CB_RB    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'))
  EC_RB    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'edge_check.rb'))
  HOVER_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hover_edge.rb'))
  VEPO_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'vepo_export.rb'))

  # Ocakavane osi per rola dielca zasuvky (vzor: co stava `drawer_part_descriptor`).
  DRAWER_AXES = {
    'front:F1/drawer_bottom'      => PF::AXES_LYING,
    'front:F1/drawer_back'        => PF::AXES_WALL,
    'front:F1/drawer_inner_front' => PF::AXES_WALL,
    'front:F1/box_side:left'      => PF::AXES_WALL_DEPTH,
    'front:F1/box_side:right'     => PF::AXES_WALL_DEPTH
  }.freeze

  module_function

  # Skrinka 900 x 720 x 500 s JEDNYM zasuvkovym celom 175 (vzor test_kovc2b_dielce).
  def cfg(front = {}, over = {})
    item = { 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
             'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }.merge(front)
    CB.normalize({ 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                   'fronts' => { 'items' => [item] } }.merge(over))
  end

  def plan(front = {}, over = {})
    CN.build_plan(cfg(front, over), 'CAB-1')
  end

  def atira_plan
    @atira_plan ||= plan
  end

  def quadro_plan
    @quadro_plan ||= plan('drawer' => { 'construction' => 'wood' })
  end

  def drawer_parts(pl)
    pl[:parts].select { |p| p[:material] == :drawer }
  end

  def part(pl, key)
    pl[:parts].find { |p| p[:part_key] == key }
  end

  def role_part(pl, role)
    pl[:parts].find { |p| p[:role].to_s == role.to_s }
  end

  # Stred plochy kvadra na danej stene: [os, :min|:max] -> [x, y, z] v mm.
  def center(box, axis, side)
    c = box.map { |v| v.to_f / 2.0 }
    c[axis] = side == :min ? 0.0 : box[axis].to_f
    c
  end

  # Co PartFaces realne vrati pre KAZDU zo 6 sten: { kod hrany => [os, strana] }.
  def face_map(pd, role = nil)
    ax = PF.verified_axes(pd)
    return nil unless ax

    out = {}
    (0..2).each do |axis|
      %i[min max].each do |side|
        code = PF.edge_code_for_center(center(pd[:box], axis, side), pd[:box], ax, role)
        out[code] = [axis, side] if code
      end
    end
    out
  end

  # Mapa priamo z deskriptora (rola sa berie z neho — realna cesta farbenia).
  def map_of(pd)
    face_map(pd, pd[:role])
  end

  # Kde lezi ploska, ktoru pre kod hrany vykresli `face_rect_mm` (zrkadlo).
  # -> [os, hodnota suradnice na tej osi]
  def rect_axis_value(pd, code)
    ax = PF.verified_axes(pd)
    lo = [0.0, 0.0, 0.0]
    hi = pd[:box].map(&:to_f)
    rect = PF.face_rect_mm(code, lo, hi, ax, 0.0, pd[:role])
    return nil unless rect

    axis = (0..2).find { |i| rect.map { |p| p[i] }.uniq.length == 1 }
    [axis, rect.first[axis]]
  end
end

# ---------------------------------------------------------------------------
# 1) OSI DIELCOV ZASUVKY (`axes:` v plane)
# ---------------------------------------------------------------------------

NxTest.test('KOV-D5: Atira — dno aj chrbat nesu OVERITELNE osi z pomenovanej konstanty') do
  d = NxD5
  pl = d.atira_plan
  parts = d.drawer_parts(pl)
  NxTest.assert_equal(2, parts.length, 'Atira = dno + chrbat')
  parts.each do |pd|
    NxTest.assert_equal(NxD5::DRAWER_AXES[pd[:part_key]], pd[:axes], "#{pd[:part_key]}: osi")
    NxTest.assert(!NxD5::PF.verified_axes(pd).nil?,
                  "#{pd[:part_key]}: osi sedia s box/prod (#{pd[:box].inspect})")
  end
end

NxTest.test('KOV-D5: Quadro — vsetkych 5 dielcov (dno, 2 boky, vnutorne celo, chrbat) ma osi') do
  d = NxD5
  pl = d.quadro_plan
  parts = d.drawer_parts(pl)
  NxTest.assert_equal(5, parts.length, 'Quadro = 5 vyrabanych dielcov')
  NxTest.assert_equal(NxD5::DRAWER_AXES.keys.sort, parts.map { |p| p[:part_key] }.sort)
  parts.each do |pd|
    NxTest.assert_equal(NxD5::DRAWER_AXES[pd[:part_key]], pd[:axes], "#{pd[:part_key]}: osi")
    NxTest.assert(!NxD5::PF.verified_axes(pd).nil?, "#{pd[:part_key]}: osi sedia s box/prod")
  end
  # Bok boxu je JEDINA rola s osami `AXES_WALL_DEPTH` (dlzka = NL po hlbke Y).
  side = d.part(pl, 'front:F1/box_side:left')
  NxTest.assert_equal({ length: 1, width: 2, thickness: 0 }, side[:axes])
  NxTest.assert_close(side[:prod][:length], side[:box][1], 0.001, 'NL bezi po osi Y')
  NxTest.assert_close(side[:prod][:width], side[:box][2], 0.001, 'vyska boxu je os Z')
end

NxTest.test('KOV-D5: plan s dielcami zasuvky prejde kontraktom BuildPlan (osi validovane)') do
  d = NxD5
  NxTest.assert_equal(d.quadro_plan, NxD5::BP.validate!(d.quadro_plan))
  NxTest.assert_equal(d.atira_plan, NxD5::BP.validate!(d.atira_plan))
end

# ---------------------------------------------------------------------------
# 2) STARY MODEL BEZ `axes` — osi z ROLY + kvadra (D-104 cesta)
# ---------------------------------------------------------------------------

NxTest.test('KOV-D5: `axes_for_snapshot` da kazdej drawer role PRAVE jedneho kandidata') do
  d = NxD5
  (d.drawer_parts(d.atira_plan) + d.drawer_parts(d.quadro_plan)).each do |pd|
    got = NxD5::PF.axes_for_snapshot(pd[:role], pd[:box], pd[:prod])
    NxTest.assert_equal(pd[:axes], got,
                        "#{pd[:part_key]}: osi zo snapshotu = osi deskriptora")
  end
end

NxTest.test('KOV-D5: `ROLE_AXES` pozna vsetky styri roly zasuvky (jeden kandidat)') do
  %w[drawer_bottom drawer_back drawer_inner_front box_side].each do |role|
    cands = NxD5::PF::ROLE_AXES[role]
    NxTest.assert(cands.is_a?(Array) && cands.length == 1, "#{role}: prave jeden kandidat")
  end
end

NxTest.test('KOV-D5: STVORCOVY chrbat zasuvky sa da precitat (kandidat je jediny)') do
  # Sirka = vyska: hodnoty su nejednoznacne, rola nie.
  box = [400.0, 16.0, 400.0]
  prod = { 'length' => 400.0, 'width' => 400.0, 'thickness' => 16.0 }
  NxTest.assert_equal(NxD5::PF::AXES_WALL, NxD5::PF.axes_for_snapshot('drawer_back', box, prod))
  # Kvader, ktory role NESEDI (hrubka na inej osi), sa NEHADA.
  NxTest.assert(NxD5::PF.axes_for_snapshot('drawer_back', [16.0, 400.0, 400.0], prod).nil?)
  NxTest.assert(NxD5::PF.axes_for_snapshot('neznama_rola', box, prod).nil?)
end

# ---------------------------------------------------------------------------
# 3) ORIENTACIA HRAN STOJACICH ROLI — L1 = HORNA (F15)
# ---------------------------------------------------------------------------

NxTest.test('KOV-D5: chrbat zasuvky — L1 je HORNA plocha (Z max), L2 dolna, W1/W2 lava/prava') do
  d = NxD5
  back = d.part(d.atira_plan, 'front:F1/drawer_back')
  map = d.map_of(back)
  NxTest.assert_equal([2, :max], map['L1'], 'L1 (Horná) = maximum osi vysky')
  NxTest.assert_equal([2, :min], map['L2'], 'L2 (Dolná) = minimum osi vysky')
  NxTest.assert_equal([0, :min], map['W1'], 'W1 (Ľavá) = X minimum')
  NxTest.assert_equal([0, :max], map['W2'], 'W2 (Pravá) = X maximum')
  # Labely su naozaj tie, o ktorych tvrdime (jeden zdroj = AbsRules).
  NxTest.assert_equal('Horná', NxD5::ABS.edge_labels('drawer_back')['L1'])
  NxTest.assert_equal('Dolná', NxD5::ABS.edge_labels('drawer_back')['L2'])
  # A presne tam ide pravidlova paska (seed 4 sa nemeni).
  NxTest.assert_equal({ 'L1' => 1.0 }, NxD5::ABS::SEED_RULES['drawer_back'])
end

NxTest.test('KOV-D5: bok boxu Quadro — L1 HORNA (Z max), W1/W2 predna/zadna (Y)') do
  d = NxD5
  side = d.part(d.quadro_plan, 'front:F1/box_side:right')
  map = d.map_of(side)
  NxTest.assert_equal([2, :max], map['L1'], 'L1 (Horná) = Z maximum')
  NxTest.assert_equal([2, :min], map['L2'], 'L2 (Dolná) = Z minimum')
  NxTest.assert_equal([1, :min], map['W1'], 'W1 (Predná) = Y minimum')
  NxTest.assert_equal([1, :max], map['W2'], 'W2 (Zadná) = Y maximum')
  NxTest.assert_equal('Horná', NxD5::ABS.edge_labels('box_side')['L1'])
  NxTest.assert_equal('Predná', NxD5::ABS.edge_labels('box_side')['W1'])
  # Velke dekorove plochy (hrubka = os X) kod hrany NEDOSTANU.
  NxTest.assert_equal(%w[L1 L2 W1 W2].sort, map.keys.sort, 'presne 4 bocne plochy')
end

NxTest.test('KOV-D5: vnutorne celo Quadro — L1 HORNA rovnako ako chrbat') do
  d = NxD5
  map = d.map_of(d.part(d.quadro_plan, 'front:F1/drawer_inner_front'))
  NxTest.assert_equal([2, :max], map['L1'])
  NxTest.assert_equal([2, :min], map['L2'])
  NxTest.assert_equal('Horná', NxD5::ABS.edge_labels('drawer_inner_front')['L1'])
end

NxTest.test('KOV-D5: dno zasuvky LEZI — ostava na default mape (L1 = minimum osi sirky)') do
  d = NxD5
  bottom = d.part(d.atira_plan, 'front:F1/drawer_bottom')
  map = d.map_of(bottom)
  NxTest.assert_equal([1, :min], map['L1'], 'dno L1 = Y minimum (lezaci dielec)')
  NxTest.assert_equal([1, :max], map['L2'])
  NxTest.assert(!NxD5::PF::STANDING_ROLES.include?('drawer_bottom'), 'dno NIE JE stojaca rola')
  # A dno pravidlovu pasku vobec nema (dno sada na prirubu zargy).
  NxTest.assert_equal({}, NxD5::ABS::SEED_RULES['drawer_bottom'])
end

NxTest.test('KOV-D5: `face_rect_mm` kresli ploskou TU ISTU hranu, ktoru farbi mapovanie') do
  d = NxD5
  back = d.part(d.atira_plan, 'front:F1/drawer_back')
  axis, value = d.rect_axis_value(back, 'L1')
  NxTest.assert_equal(2, axis, 'ploska L1 je kolma na os Z')
  NxTest.assert_close(back[:box][2].to_f, value, 0.001, 'a lezi na HORNEJ stene kvadra')
  axis2, value2 = d.rect_axis_value(back, 'L2')
  NxTest.assert_equal(2, axis2)
  NxTest.assert_close(0.0, value2, 0.001, 'L2 na spodnej stene')
  # Korpusovy chrbat (rola `back`, AXES_WALL) ostava na default mape — L1 dole.
  cab_back = d.role_part(d.atira_plan, 'back')
  ax3, val3 = d.rect_axis_value(cab_back, 'L1')
  NxTest.assert_equal(2, ax3)
  NxTest.assert_close(0.0, val3, 0.001, 'korpusovy chrbat: L1 (Dolná) ostava dole')
end

# ---------------------------------------------------------------------------
# 4) JEDNO MIESTO PRAVDY (zdrojovy guard)
# ---------------------------------------------------------------------------

NxTest.test('KOV-D5: zoznam stojacich roli je JEDINY (AbsRules je alias PartFaces)') do
  NxTest.assert(NxD5::ABS::STANDING_ROLES.equal?(NxD5::PF::STANDING_ROLES),
                'AbsRules::STANDING_ROLES musi byt TEN ISTY objekt ako PartFaces::STANDING_ROLES')
  NxTest.assert_equal(%w[drawer_back box_side drawer_inner_front], NxD5::PF::STANDING_ROLES)
end

NxTest.test('KOV-D5: dve mapy hran sa lisia PRESNE v dvojici L1/L2') do
  def_map = NxD5::PF::EDGE_FACES
  std_map = NxD5::PF::STANDING_EDGE_FACES
  NxTest.assert_equal(%w[L1 L2 W1 W2].sort, def_map.keys.sort)
  NxTest.assert_equal(def_map.keys.sort, std_map.keys.sort)
  NxTest.assert_equal(%w[W1 W2], def_map.keys.select { |k| def_map[k] == std_map[k] }.sort)
  NxTest.assert_equal([:width, :max], std_map['L1'], 'stojaca rola: L1 = maximum osi sirky')
  NxTest.assert_equal([:width, :min], def_map['L1'], 'ostatne roly: L1 = minimum osi sirky')
end

NxTest.test('KOV-D5: farbenie, Kontrola aj hover posielaju ROLU do zdielanej mapy') do
  NxTest.assert(NxD5::CB_RB.include?('PartFaces.edge_code_for_center(face_center_mm(f), box, ax, pd[:role])'),
                'paint_edge_faces posiela rolu deskriptora')
  NxTest.assert(NxD5::EC_RB.include?('PartFaces.face_rect_mm(code, lo, hi, ax, OUT_MM, role)'),
                'EdgeCheck posiela rolu dielca')
  NxTest.assert(NxD5::HOVER_RB.include?('PartFaces.face_rect_mm(code, lo, hi, ax, OUT_MM, role)'),
                'HoverEdge posiela rolu dielca')
  # A ziadny z nich nema VLASTNU mapu „kod hrany -> os/stena kvadra" ani vlastnu
  # kopiu zoznamu stojacich roli (mapa `'L1' => nil` v `empty_edges` je zoznam
  # ABS pasiek, nie geometria — preto sa hlada dvojica kod -> os/strana).
  [['cabinet_builder', NxD5::CB_RB], ['edge_check', NxD5::EC_RB], ['hover_edge', NxD5::HOVER_RB]].each do |name, src|
    NxTest.assert(!src.match?(/'L1'\s*=>\s*(\[|:width|:length|:min|:max)/),
                  "#{name}: ziadna vlastna mapa hrana -> stena kvadra")
    NxTest.assert(!src.include?('STANDING'), "#{name}: zoznam stojacich roli sa nekopiruje")
  end
end

# ---------------------------------------------------------------------------
# 5) CHARAKTERIZACIA — korpus, recept a vystupy sa NEMENIA
# ---------------------------------------------------------------------------

NxTest.test('KOV-D5: korpusove dielce mapuju hrany PRESNE ako pred D5 (rola nic nemeni)') do
  d = NxD5
  pl = d.plan({ 'type' => 'drawer_front' },
              'plinth_mode' => 'front', 'top_mode' => 'two_rails',
              'rails_orientation' => 'upright', 'back_mode' => 'overlay',
              'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] })
  corpus = pl[:parts].reject { |p| p[:material] == :drawer }
  NxTest.assert(corpus.length >= 6, "plan ma korpusove dielce (#{corpus.length})")
  corpus.each do |pd|
    NxTest.assert(!NxD5::PF::STANDING_ROLES.include?(pd[:role].to_s),
                  "#{pd[:role]}: korpusova rola nesmie byt stojaca")
    NxTest.assert_equal(d.face_map(pd, nil), d.map_of(pd),
                        "#{pd[:role]}/#{pd[:suffix]}: mapa s rolou = mapa bez roly")
  end
end

NxTest.test('KOV-D5: golden mapa hran roli korpusu (bok, polica, celo, chrbat)') do
  d = NxD5
  pl = d.plan({ 'type' => 'door', 'mode' => 'auto', 'wings' => '1', 'drawer' => {} },
              'back_mode' => 'overlay',
              'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] })
  {
    'side_left'  => { 'L1' => [1, :min], 'L2' => [1, :max], 'W1' => [2, :min], 'W2' => [2, :max] },
    'shelf'      => { 'L1' => [1, :min], 'L2' => [1, :max], 'W1' => [0, :min], 'W2' => [0, :max] },
    'bottom'     => { 'L1' => [1, :min], 'L2' => [1, :max], 'W1' => [0, :min], 'W2' => [0, :max] },
    'front_door' => { 'L1' => [0, :min], 'L2' => [0, :max], 'W1' => [2, :min], 'W2' => [2, :max] },
    'back'       => { 'L1' => [2, :min], 'L2' => [2, :max], 'W1' => [0, :min], 'W2' => [0, :max] }
  }.each do |role, want|
    pd = d.role_part(pl, role)
    NxTest.assert(!pd.nil?, "plan ma dielec roly #{role}")
    NxTest.assert_equal(want, d.map_of(pd), "#{role}: mapovanie hran nezmenene")
  end
end

NxTest.test('KOV-D5: recept ani ABS pravidla dielcov zasuviek sa nemenia') do
  NxTest.assert_equal(4, NxD5::ABS::SEED_VERSION, 'seed sa nebumpuje — pravidla su rovnake')
  { 'drawer_bottom' => {}, 'drawer_back' => { 'L1' => 1.0 },
    'box_side' => { 'L1' => 1.0 }, 'drawer_inner_front' => { 'L1' => 1.0 } }.each do |role, want|
    NxTest.assert_equal(want, NxD5::ABS::SEED_RULES[role], "#{role}: seed pravidlo")
  end
  # Datovy pack receptu: olep ostava na L1 (jednotka), ziadna nova hrana.
  atira = NxD5::REC.load('atira_sisy_v1')
  NxTest.assert_equal({ l1: 1.0 }, atira[:abs]['drawer_back'])
  NxTest.assert_equal({}, atira[:abs]['drawer_bottom'])
  quadro = NxD5::REC.load('quadro_v6_sisy_v1')
  NxTest.assert_equal({ l1: 1.0 }, quadro[:abs]['box_side'])
end

NxTest.test('KOV-D5: deskriptor zasuvky pribral LEN kluc `axes` (kusovnik/VEPO nedotknute)') do
  d = NxD5
  bottom = d.part(d.atira_plan, 'front:F1/drawer_bottom')
  NxTest.assert_equal(%i[axes box material name origin part_key prod role suffix],
                      bottom.keys.sort, 'kluce deskriptora dielca zasuvky')
  # Vyrobne cisla ostavaju presne tie z KOV-C2b (dno 791,5 x 480 x 16).
  NxTest.assert_equal({ length: 791.5, width: 480.0, thickness: 16.0 },
                      bottom[:prod].transform_values { |v| v.to_f.round(2) })
  NxTest.assert_equal('Dno zasuvky F1', bottom[:name])
  NxTest.assert_equal('DRWBOT-F1-1', bottom[:suffix])
  # `axes` je udaj PLANU — do snapshotu na entite (a teda do kusovnika ani VEPO)
  # sa nezapisuje; `CabinetBuilder` ziadny kluc `axes` nepise a VEPO ho nepozna.
  NxTest.assert(NxD5::CB_RB.lines.none? { |l| l.match?(/\baxes:/) || l.match?(/['"]axes['"]/) },
                'CabinetBuilder nikam nezapisuje kluc `axes`')
  NxTest.assert(!NxD5::VEPO_RB.include?('axes'), 'VEPO export o osiach nevie')
end
