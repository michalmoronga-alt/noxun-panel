# frozen_string_literal: true
# Testy KOV-A2b „Smer otvárania v modeli" — CISTE jadro overlayu (bez
# SketchUpu, bez Overlay API).
#
# Preco su to testy a nie klikanie v modeli:
#   1. TROJSTAV (R-39) sa v modeli neda „pozriet". „Kluc chyba" (legacy —
#      nekresli sa NIC) a „neurcene" (kruh + „?") su dva RÔZNE stavy, ktore
#      vyzeraju na obrazovke podobne; jediny sposob, ako ustrazit, ze overlay
#      nikdy nedopisal default smeru, je prejst maticu stavov.
#   2. NAHLAD A MODEL musia kreslit TO ISTE. Vyber symbolu je cista funkcia na
#      oboch stranach a obe sady citaju TU ISTU tabulku fixtur
#      (tests/fixtures/kova2b_symbols.json) — rozchod padne naraz.
#   3. GEOMETRIA symbolu (hrot pri VOLNEJ hrane, ∧ hore, ∨ dole) sa v modeli
#      overuje az in-SketchUp behom; tu sa overuje pravidlo, ktore ju urcuje.
#   4. FARBY prekryti sa nesmu miesat — a tri prekrytia uz v modeli ziju.
require_relative '../helper' unless defined?(NxTest)

A2B = Noxun::Engine::DirectionCheck
A2B_PF = Noxun::Engine::PartFaces
A2B_FIX = JSON.parse(File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'kova2b_symbols.json'),
                               encoding: 'UTF-8'))

# Celo: dlzka = VYSKA (Z), sirka = sirka kridla (X), hrubka Y.
A2B_AX = A2B_PF::AXES_FRONT
A2B_LO = [0.0, 0.0, 0.0].freeze
A2B_HI = [400.0, 18.0, 2000.0].freeze

def a2b_lines(symbol, lo = A2B_LO, hi = A2B_HI, ax = A2B_AX)
  A2B.symbol_mm(lo, hi, ax, symbol)['lines']
end

def a2b_points(symbol, lo = A2B_LO, hi = A2B_HI, ax = A2B_AX)
  a2b_lines(symbol, lo, hi, ax).flatten(1)
end

def a2b_dist(a, b)
  Math.sqrt(a.each_with_index.map { |v, i| (v - b[i])**2 }.sum)
end

# --- 1) VYBER SYMBOLU = ZRKADLO NAHLADU (spolocne fixtury) --------------------

NxTest.test('KOV-A2b: symboly kridiel sedia s tabulkou fixtur (zrkadlo frontWingSymbols)') do
  rows = A2B_FIX['wings']
  NxTest.assert(rows.length >= 10, 'tabulka fixtur je podozrivo kratka')
  rows.each do |row|
    got = A2B.wing_symbols(row['wings_n'], row['slots'])
    NxTest.assert_equal(row['expect'], got, "#{row['case']}: #{got.inspect}")
  end
end

NxTest.test('KOV-A2b: symboly typov sedia s tabulkou fixtur (zrkadlo frontTypeSymbol)') do
  A2B_FIX['types'].each do |row|
    NxTest.assert_equal(row['expect'], A2B.type_symbol(row['type']), row['case'])
  end
end

NxTest.test('KOV-A2b: stav slotu -> symbol, ZIADNY fallback na stranu (R-39)') do
  NxTest.assert_equal('left', A2B.dir_symbol('left'))
  NxTest.assert_equal('right', A2B.dir_symbol('right'))
  NxTest.assert_equal('unknown', A2B.dir_symbol('unset'))
  NxTest.assert_equal(nil, A2B.dir_symbol(nil), 'LEGACY sa NEKRESLI')
  NxTest.assert_equal(nil, A2B.dir_symbol(''), 'prazdna hodnota tiez nie je strana')
  NxTest.assert_equal(nil, A2B.dir_symbol('vlavo'), 'neznamy stav sa NEPREKLOPI na stranu')
end

# --- 2) CO SA MA PRI POLOZKE NAKRESLIT (kluce + symboly) ---------------------

NxTest.test('KOV-A2b: jednokridlove dvierka kreslia na SVOJ dielec') do
  item = { 'id' => 'F1', 'type' => 'door', 'wings_n' => 1, 'direction' => 'left' }
  NxTest.assert_equal([{ key: 'front:F1/wing:single', symbol: 'left' }], A2B.marks(item))
end

NxTest.test('KOV-A2b: dvojkridlo ma ODVODENE kluce left/right (tak ich pomenoval builder)') do
  item = { 'id' => 'F2', 'type' => 'door', 'wings_n' => 2 }
  NxTest.assert_equal([{ key: 'front:F2/wing:left', symbol: 'left' },
                       { key: 'front:F2/wing:right', symbol: 'right' }], A2B.marks(item))
end

NxTest.test('KOV-A2b: 3 kridla — krajne odvodene, stredne podla ulozeneho stavu') do
  item = { 'id' => 'F3', 'type' => 'door', 'wings_n' => 3,
           'wing_directions' => { 'p2' => 'unset' } }
  NxTest.assert_equal([{ key: 'front:F3/wing:p1', symbol: 'left' },
                       { key: 'front:F3/wing:p2', symbol: 'unknown' },
                       { key: 'front:F3/wing:p3', symbol: 'right' }], A2B.marks(item))
end

NxTest.test('KOV-A2b: LEGACY jednokridlove dvierka nekreslia NIC') do
  NxTest.assert_equal([], A2B.marks('id' => 'F1', 'type' => 'door', 'wings_n' => 1))
end

NxTest.test('KOV-A2b: 3 kridla bez ulozeneho stredneho — krajne ANO, stredne NIE') do
  got = A2B.marks('id' => 'F1', 'type' => 'door', 'wings_n' => 3)
  NxTest.assert_equal([{ key: 'front:F1/wing:p1', symbol: 'left' },
                       { key: 'front:F1/wing:p3', symbol: 'right' }], got)
end

NxTest.test('KOV-A2b: vyklop/sklop/blenda maju kanonicke kluce A1, zasuvka nic') do
  NxTest.assert_equal([{ key: 'front:F1/flap', symbol: 'up' }],
                      A2B.marks('id' => 'F1', 'type' => 'lift'))
  NxTest.assert_equal([{ key: 'front:F1/flap', symbol: 'down' }],
                      A2B.marks('id' => 'F1', 'type' => 'fall'))
  NxTest.assert_equal([{ key: 'front:F1/blind', symbol: 'cross' }],
                      A2B.marks('id' => 'F1', 'type' => 'blind'))
  NxTest.assert_equal([], A2B.marks('id' => 'F1', 'type' => 'drawer_front'))
  NxTest.assert_equal([], A2B.marks('id' => 'F1', 'type' => 'none'))
  NxTest.assert_equal([], A2B.marks('id' => '', 'type' => 'lift'), 'polozka bez ID nema adresu')
  NxTest.assert_equal([], A2B.marks(nil))
end

NxTest.test('KOV-A2b: „bez smeru (legacy)" sa POCITA, aj ked sa nekresli') do
  NxTest.assert_equal(1, A2B.legacy_count('id' => 'F1', 'type' => 'door', 'wings_n' => 1))
  NxTest.assert_equal(0, A2B.legacy_count('id' => 'F1', 'type' => 'door', 'wings_n' => 1,
                                          'direction' => 'unset'), 'neurcene NIE JE legacy')
  NxTest.assert_equal(0, A2B.legacy_count('id' => 'F1', 'type' => 'door', 'wings_n' => 2),
                      'dvojkridlo sa na smer nepyta')
  NxTest.assert_equal(2, A2B.legacy_count('id' => 'F1', 'type' => 'door', 'wings_n' => 4))
  NxTest.assert_equal(0, A2B.legacy_count('id' => 'F1', 'type' => 'blind'))
end

# --- 3) GEOMETRIA symbolu na PREDNEJ ploche ----------------------------------

NxTest.test('KOV-A2b: kresli sa na PREDNEJ ploche, posunutej VON z telesa') do
  pts = a2b_points('left')
  NxTest.assert(!pts.empty?, 'ziadne usecky')
  NxTest.assert(pts.all? { |p| (p[1] - (-A2B::OUT_MM)).abs < 0.0001 },
                'symbol nelezi na rovine MIN osi hrubky posunutej von')
end

NxTest.test('KOV-A2b: OUT_MM je medzi olepom a hoverom (poradie vrstiev)') do
  NxTest.assert(A2B::OUT_MM > Noxun::Engine::EdgeCheck::OUT_MM,
                'symbol by zmizol pod ploskou olepu')
  NxTest.assert(A2B::OUT_MM < Noxun::Engine::HoverEdge::OUT_MM,
                'hover hrany musi ostat navrchu')
end

NxTest.test('KOV-A2b: sipka „panty vlavo" ma HROT pri VOLNEJ hrane vpravo') do
  pts = a2b_points('left')
  xs = pts.map { |p| p[0] }
  NxTest.assert_equal(3, a2b_lines('left').length, 'driek + dve ramena hrotu')
  NxTest.assert(xs.max > 300.0, "hrot nie je pri pravej hrane (max x #{xs.max})")
  NxTest.assert(xs.min < 100.0, 'driek nezacina pri pantoch')
  # Hrot je bod, v ktorom sa stretavaju VSETKY tri usecky.
  tip = pts.group_by { |p| p.map { |v| v.round(3) } }.max_by { |_, v| v.length }
  NxTest.assert_equal(3, tip[1].length, 'tri usecky sa musia stretat v jednom bode')
  NxTest.assert_close(xs.max, tip[0][0], 0.01, 'a ten bod je hrot pri volnej hrane')
end

NxTest.test('KOV-A2b: sipka „panty vpravo" je presnym ZRKADLOM tej lavej') do
  left = a2b_points('left').map { |p| [(400.0 - p[0]).round(3), p[1].round(3), p[2].round(3)] }.sort
  right = a2b_points('right').map { |p| p.map { |v| v.round(3) } }.sort
  NxTest.assert_equal(left, right, 'strany nie su zrkadlove — jedna z nich je nakreslena zle')
end

NxTest.test('KOV-A2b: ∧ vyklop mieri HORE, ∨ sklop DOLE (os dlzky cela)') do
  up = a2b_points('up')
  down = a2b_points('down')
  NxTest.assert_equal(2, a2b_lines('up').length, 'dve ramena')
  # Apex je spolocny bod oboch ramien.
  apex_up = up.group_by { |p| p.map { |v| v.round(3) } }.max_by { |_, v| v.length }[0]
  apex_down = down.group_by { |p| p.map { |v| v.round(3) } }.max_by { |_, v| v.length }[0]
  NxTest.assert(apex_up[2] > 1000.0, 'vyklop musi mat hrot pri HORNEJ hrane')
  NxTest.assert(apex_down[2] < 1000.0, 'sklop musi mat hrot pri DOLNEJ hrane')
  NxTest.assert(up.all? { |p| p[2] <= apex_up[2] + 0.001 }, 'ramena vyklopu idu NADOL od hrotu')
  NxTest.assert(down.all? { |p| p[2] >= apex_down[2] - 0.001 }, 'ramena sklopu idu NAHOR')
  NxTest.assert_close(200.0, apex_up[0], 0.01, 'hrot je v strede sirky')
end

NxTest.test('KOV-A2b: blenda je PLNE X cez cely panel (nehybe sa)') do
  segs = a2b_lines('cross')
  NxTest.assert_equal(2, segs.length, 'dve uhloprieciek')
  pts = segs.flatten(1)
  NxTest.assert(pts.map { |p| p[0] }.min > 0.0 && pts.map { |p| p[0] }.max < 400.0,
                'X je odsadene od hran')
  NxTest.assert(pts.map { |p| p[2] }.max > 1500.0 && pts.map { |p| p[2] }.min < 500.0,
                'X ide cez cely panel')
end

NxTest.test('KOV-A2b: „neurcene" je KRUH okolo stredu + kotva otaznika') do
  shape = A2B.symbol_mm(A2B_LO, A2B_HI, A2B_AX, 'unknown')
  pts = shape['lines'].flatten(1)
  NxTest.assert_equal(A2B::RING_SEGS, shape['lines'].length, 'kruh je polygon RING_SEGS usecek')
  centre = [200.0, -A2B::OUT_MM, 1000.0]
  radii = pts.map { |p| a2b_dist(p, centre) }
  NxTest.assert(radii.max - radii.min < 0.001, 'body kruhu nie su rovnako daleko od stredu')
  NxTest.assert(radii.max.positive?, 'kruh s nulovym polomerom')
  NxTest.assert_equal(centre.map { |v| v.round(3) }, shape['text'].map { |v| v.round(3) },
                      'otaznik patri do STREDU cela')
  NxTest.assert_equal(nil, A2B.symbol_mm(A2B_LO, A2B_HI, A2B_AX, 'left')['text'],
                      'vyriesena strana ziadny text nema')
end

NxTest.test('KOV-A2b: symbol sa NEKRESLI bez osi, bez tvaru a na degenerovanom kvadri') do
  NxTest.assert_equal([], a2b_lines('nonsense'), 'neznamy symbol')
  NxTest.assert_equal([], a2b_lines(nil))
  NxTest.assert_equal([], A2B.symbol_mm(A2B_LO, A2B_HI, nil, 'left')['lines'], 'bez osi')
  NxTest.assert_equal([], A2B.symbol_mm(A2B_LO, A2B_HI, { length: 2, width: 2, thickness: 1 },
                                        'left')['lines'], 'poskodene osi')
  NxTest.assert_equal([], a2b_lines('left', [0.0, 0.0, 0.0], [0.0, 18.0, 2000.0]), 'nulova sirka')
  NxTest.assert_equal([], a2b_lines('left', [0.0, 0.0, 0.0], [400.0, 18.0, 0.0]), 'nulova vyska')
end

NxTest.test('KOV-A2b: osi urcuje deskriptor — polozena doska kresli po INEJ osi') do
  # Ta ista sipka na dielci s AXES_LYING (dlzka X, sirka Y, hrubka Z): „doprava"
  # uz nie je X. Kontrola, ze modul nema vlastnu mapu roli.
  pts = a2b_points('left', [0.0, 0.0, 0.0], [900.0, 500.0, 18.0], A2B_PF::AXES_LYING)
  NxTest.assert(!pts.empty?, 'nic sa nenakreslilo')
  NxTest.assert(pts.all? { |p| (p[2] - (-A2B::OUT_MM)).abs < 0.0001 },
                'plocha je urcena osou HRUBKY deskriptora, nie natvrdo Y')
end

# --- 4) FARBY prekryti ------------------------------------------------------

NxTest.test('KOV-A2b: farby vsetkych prekryti su NAVZAJOM rozne') do
  all = Noxun::Engine::EdgeCheck::COLORS.values.map { |c| c.map(&:to_i) }
  all << Noxun::Engine::GrainCheck::COLOR.map(&:to_i)
  all << Noxun::Engine::HoverEdge::COLOR.map(&:to_i)
  all << A2B::COLOR.map(&:to_i)
  all << A2B::COLOR_UNSET.map(&:to_i)
  NxTest.assert_equal(all.length, all.uniq.length, 'dve prekrytia maju rovnaku farbu')
end

NxTest.test('KOV-A2b: vyriesena farba ma ODSTUP od kazdeho ineho prekrytia') do
  others = Noxun::Engine::EdgeCheck::COLORS.values.map { |c| c.map(&:to_f) } +
           [Noxun::Engine::GrainCheck::COLOR.map(&:to_f),
            Noxun::Engine::HoverEdge::COLOR.map(&:to_f)]
  mine = A2B::COLOR.map(&:to_f)
  worst = others.map { |c| a2b_dist(mine, c) }.min
  NxTest.assert(worst >= 90.0, "najblizsie prekrytie je #{worst.round(1)} — to uz je zamena")
end

NxTest.test('KOV-A2b: „neurcene" a „vyriesene" musia byt na prvy pohlad rozne') do
  d = a2b_dist(A2B::COLOR.map(&:to_f), A2B::COLOR_UNSET.map(&:to_f))
  NxTest.assert(d >= 120.0, "otaznik a sipka su prilis podobne (#{d.round(1)})")
end

NxTest.test('KOV-A2b: jantar otaznika je ZRKADLOM tokenu --nx-warn-fg') do
  css = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
  hex = css[/--nx-warn-fg:\s*#([0-9a-fA-F]{6})/, 1]
  NxTest.assert(hex, 'token --nx-warn-fg sa v panel.css nenasiel')
  rgb = [hex[0, 2], hex[2, 2], hex[4, 2]].map { |h| h.to_i(16) }
  NxTest.assert_equal(rgb, A2B::COLOR_UNSET.to_a,
                      'badge „smer?" v paneli a otaznik v modeli musia mat TU ISTU farbu')
end

# --- 5) STAV PRE OKNO + pamat prepinaca --------------------------------------

NxTest.test('KOV-A2b: ui_state ma stabilny tvar aj bez Overlay API') do
  st = A2B.ui_state(nil)
  NxTest.assert_equal(false, st['available'], 'headless (bez Overlay triedy) = nedostupne')
  NxTest.assert_equal(false, st['active'])
  %w[wings unknown legacy marks].each do |k|
    NxTest.assert(st.key?(k), "chyba kluc #{k}")
    NxTest.assert_equal(nil, st[k], "vypnuty prepinac nesmie mat cislo v #{k}")
  end
end

NxTest.test('KOV-A2b: prepinac si pamata POCITAC (%APPDATA%), nikdy zakazka') do
  NxTest.assert(A2B::SETTINGS_FILE.end_with?('.json'))
  NxTest.assert(A2B.settings_path.include?('NOXUN') || A2B.settings_path.include?('noxun-tests'),
                "pamat prepinaca nie je v %APPDATA%: #{A2B.settings_path}")
  A2B.remember!(true)
  NxTest.assert_equal(true, A2B.remembered?, 'zapamatane zapnutie sa neprecitalo')
  A2B.remember!(false)
  NxTest.assert_equal(false, A2B.remembered?)
  # Poskodeny subor = false (nikdy vynimka a nikdy „nahodne zapnute").
  File.write(A2B.settings_path, '{ toto nie je JSON', encoding: 'UTF-8')
  NxTest.assert_equal(false, A2B.remembered?)
  File.delete(A2B.settings_path)
  NxTest.assert_equal(false, A2B.remembered?, 'chybajuci subor = vypnute')
end

NxTest.test('KOV-A2b: prepnutie dokumentu bez overlayu nic nerobi (a nespadne)') do
  NxTest.assert_equal(nil, A2B.on_model_changed(nil))
end

# --- 6) DEEP-LINK: front_id z kluca dielca -----------------------------------

NxTest.test('KOV-A2b: front_id sa cita z kluca dielca (deep-link do karty cela)') do
  pk = Noxun::Engine::PartKeys
  NxTest.assert_equal('F2', pk.front_id('front:F2/wing:single'))
  NxTest.assert_equal('F10', pk.front_id('front:F10/flap'))
  NxTest.assert_equal('F1', pk.front_id('front:F1/blind'))
  NxTest.assert_equal('F3', pk.front_id(' front:F3/panel '), 'okraje sa orezu')
  NxTest.assert_equal(nil, pk.front_id('zone:Z1/shelf:1'), 'zonovy kluc nie je celo')
  NxTest.assert_equal(nil, pk.front_id('cabinet/side_left'))
  NxTest.assert_equal(nil, pk.front_id('board/main'))
  NxTest.assert_equal(nil, pk.front_id(''), 'prazdny kluc = ziadny deep-link')
  NxTest.assert_equal(nil, pk.front_id(nil))
  NxTest.assert_equal(nil, pk.front_id('front:F1'), 'kluc bez dielca nie je adresa')
end

# --- 7) JEDEN ZDROJ STAVU, DVA VSTUPNE BODY ---------------------------------

A2B_MAIN = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
A2B_CORE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'direction_check.rb'),
                     encoding: 'UTF-8')
A2B_SYNC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'),
                     encoding: 'UTF-8')
A2B_ACT = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_materials.rb'),
                    encoding: 'UTF-8')
A2B_PANEL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
A2B_STUDIO = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                       encoding: 'UTF-8')
A2B_PCORE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                      encoding: 'UTF-8')
A2B_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
A2B_OBS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer.rb'),
                    encoding: 'UTF-8')

NxTest.test('KOV-A2b: prepnutie ide JEDNOU cestou a stav dostanu OBE okna') do
  cast = A2B_MAIN[/def self\.broadcast_direction_check.*?\n    end\n/m].to_s
  NxTest.refute(cast.empty?, 'broadcast musi existovat')
  NxTest.assert(cast.include?('StudioDialog.push_direction_check(state)'),
                'okno Studio (sekcia Kontrola) musi dostat novy stav')
  NxTest.assert(cast.include?('Panel.push_direction_check(state)'),
                'rail Inspectora musi dostat novy stav')
  NxTest.assert(cast.include?('defined?(Panel)') && cast.include?('defined?(StudioDialog)'),
                'push je defenzivny — zavrete okno ho ticho zahodi')
  NxTest.assert(A2B_CORE.include?('Engine.broadcast_direction_check'),
                'core po prepocte/zmene modelu rozposiela stav obom oknam')
  NxTest.refute(A2B_CORE.include?('StudioDialog.push_direction_check'),
                'core nesmie posielat stav LEN Studiu (rail by zamrzol)')
  NxTest.refute(A2B_CORE.include?('Panel.push_direction_check'),
                'ani LEN railu (Studio by zamrzlo)')
end

NxTest.test('KOV-A2b: overlay NIC nezapisuje do modelu') do
  NxTest.refute(A2B_CORE.include?('start_operation'), 'kresba je overlay NAD modelom')
  NxTest.refute(A2B_CORE.include?('Store.set'), 'do modelu sa nesmie zapisat nic')
  NxTest.refute(A2B_CORE.match?(/set_attribute/), 'ani cez surove atributy')
  NxTest.assert(A2B_CORE.include?('def scan(model)'), 'sken existuje')
  NxTest.assert(A2B_CORE.include?("SETTINGS_FILE = 'direction_check.json'"),
                'prepinac zije v %APPDATA%, nie v .skp')
end

NxTest.test('KOV-A2b: modul sa nacita PRED overlay triedami a odpaja sa pri zmene dokumentu') do
  i_dir = A2B_MAIN.index("core/direction_check")
  i_ovl = A2B_MAIN.index("core/edge_overlay")
  NxTest.assert(i_dir && i_ovl && i_dir < i_ovl,
                'direction_check sa musi nacitat pred edge_overlay (ten definuje jeho Overlay triedu)')
  NxTest.assert(A2B_OBS.include?('DirectionCheck.on_model_changed(model) if defined?(DirectionCheck)'),
                'prepnutie dokumentu musi overlay vypnut')
end

NxTest.test('KOV-A2b: rail cita ten isty stav a nema vlastnu kopiu') do
  NxTest.assert(A2B_SYNC.include?('def direction_check_state'), 'Panel musi vediet stav precitat')
  NxTest.assert(A2B_SYNC.include?('DirectionCheck.ui_state(Sketchup.active_model)'),
                'stav je VYHRADNE DirectionCheck.ui_state — ziadny druhy vypocet')
  NxTest.assert(A2B_SYNC.include?('def push_direction_check'), 'protajsok okna')
  NxTest.assert(A2B_SYNC.include?('direction_check: direction_check_state'),
                'init panela nesie stav prepinaca (PULL pri otvoreni)')
  NxTest.assert(A2B_PANEL_RB.include?("cb(dlg, 'nx_direction_toggle')"),
                'callback raily musi byt zaregistrovany')
  NxTest.assert(A2B_HTML.include?('id="railSmer"') && A2B_HTML.include?('data-nx-usage="rail:smer"'),
                'tlacidlo raily s vlastnym klucom meraca')
  NxTest.assert(A2B_HTML.include?('#i-direction'), 'ikona zo spritu')
  NxTest.assert(A2B_HTML.include?('onclick="onDirectionCheckToggle()"'), 'klik ide do zdielanej cesty')
end

NxTest.test('KOV-A2b: rail ma identity guard dokumentu a NEZAPISUJE do modelu') do
  h = A2B_ACT[/def handle_direction_toggle.*?\n        end\n/m].to_s
  NxTest.refute(h.empty?, 'handler raily musi existovat')
  NxTest.assert(h.include?('DirectionCheck.available?(model)'),
                'starsi SketchUp bez Overlay API sa hlasi nahlas, nie tichym mrtvym tlacidlom')
  NxTest.assert(h.include?(%q<DocKey.foreign?(payload ? parse(payload)['model_guid'] : nil, model)>),
                'PRISNY guard dokumentu (asynchronny callback by zapol symboly v cudzom modeli)')
  NxTest.assert(h.include?('Engine.toggle_direction_check(model)'), 'prepina sa ZDIELANOU cestou')
  NxTest.refute(h.include?('start_operation'), 'ziadna operacia')
  NxTest.refute(h.include?('Store.set'), 'rail nesmie nic zapisat do modelu')
end

NxTest.test('KOV-A2b: Studio prepina tym istym jadrom a obnovuje zapamatany stav') do
  NxTest.assert(A2B_STUDIO.include?("cb(dlg, 'direction_check_toggle')"), 'callback listy sekcie')
  NxTest.assert(A2B_STUDIO.include?('def restore_direction_check'), 'obnova zapamataneho prepinaca')
  show = A2B_STUDIO[/def show\(open_section.*?\n        end\n/m].to_s
  NxTest.assert(show.include?('restore_direction_check'),
                'obnova musi bezat pri otvoreni okna')
  # Porovnava sa poloha VOLANIA (`\n… push_state`), nie slova — v komentari
  # nad obnovou to slovo stoji tiez.
  call = show.index("\n            push_state")
  NxTest.assert(call && show.index('restore_direction_check') < call,
                'a to PRED prvym push_state (inak by lista hlasila vypnute)')
  NxTest.assert(A2B_STUDIO.include?('direction_check: (defined?(DirectionCheck)'),
                'payload okna nesie stav prepinaca')
  body = A2B_PCORE[/def do_direction_check.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'telo prepnutia zije v zdielanom jadre')
  NxTest.assert(body.include?('DirectionCheck.available?(model)'), 'vlastna hlaska o Overlay API')
  NxTest.assert(body.include?('identity_guard'), 'ZDIELANY identity guard (gen + model_guid)')
  NxTest.assert(body.include?('Engine.toggle_direction_check(model)'), 'jedna cesta prepnutia')
end

NxTest.test('KOV-A2b: text listy sklada SERVER a priznava vsetky tri cisla') do
  pc = Noxun::Engine::ProductionCore
  off = pc.direction_check_status('active' => false)
  NxTest.assert(off.include?('vypnutý') && off.include?('nič neostalo'), off)
  on = pc.direction_check_status('active' => true, 'wings' => 5, 'unknown' => 2, 'legacy' => 3)
  NxTest.assert(on.include?('5 krídel'), on)
  NxTest.assert(on.include?('2 neurčených'), on)
  NxTest.assert(on.include?('3 bez smeru (legacy)'), on)
  clean = pc.direction_check_status('active' => true, 'wings' => 1, 'unknown' => 0, 'legacy' => 0)
  NxTest.assert(clean.include?('1 krídlo'), clean)
  NxTest.refute(clean.include?('neurčených'), 'ked netreba, o neurcenych sa nehovori')
  NxTest.refute(clean.include?('legacy'), 'ani o legacy')
  NxTest.assert_equal('krídlo', pc.direction_wing_plural(1))
  NxTest.assert_equal('krídla', pc.direction_wing_plural(3))
  NxTest.assert_equal('krídel', pc.direction_wing_plural(5))
  NxTest.assert_equal('krídel', pc.direction_wing_plural(0))
end

NxTest.test('KOV-A2b: deep-link posiela LEN ID cela a len pri otvorenom Inspectorovi') do
  sel = A2B_PCORE[/def do_select.*?\n      end\n/m].to_s
  NxTest.assert(sel.include?('PartKeys.front_id('), 'front_id sa cita ZDIELANYM parserom')
  NxTest.assert(sel.include?('Panel.push_focus_front(front_id)') && sel.include?('if focus && front_id'),
                'bez ceruzky (focus_inspector) a bez cela sa neposiela nic')
  push = A2B_SYNC[/def push_focus_front.*?\n        end\n/m].to_s
  NxTest.refute(push.empty?, 'kanal musi existovat')
  NxTest.assert(push.include?('dialog_alive?'), 'zavrety Inspector nedostane nic')
  NxTest.assert(push.include?('NX.focusFront'), 'klientska cesta')
  NxTest.refute(push.include?('Store.set'), 'deep-link nic nezapisuje')
end

# --- 8) Codex #282 P2: CO sa pri ceruzke oznaci -------------------------------
#
# Karta cela zije v Inspectorovi LEN nad oznacenou SKRINKOU. Keby ceruzka
# oznacila VNORENY dielec, panel by presiel do rezimu „dielec", kontext Cela by
# sa nedal zapnut a deep-link by ticho zomrel. Vyber je autorita SERVERA, takze
# rozhodnutie robi on — klient si druhy krok nevymysla.

A2B_ITEM = { 'severity' => 'red', 'category' => 'front_direction', 'owner_id' => 'CAB-1',
             'owner_pid' => 42, 'part_key' => 'front:F2/wing:single',
             'stable_key' => 'front_direction|CAB-1|front:F2/wing:single' }.freeze

NxTest.test('KOV-A2b: ceruzka na nalez o CELE adresuje VLASTNIKA (kluc dielca padne)') do
  pc = Noxun::Engine::ProductionCore
  got = pc.select_target_item(A2B_ITEM, 'F2', true)
  NxTest.assert_equal(nil, got['part_key'], 'bez `part_key` = vyber korpusu (vzor korpusoveho nalezu)')
  NxTest.assert_equal('CAB-1', got['owner_id'], 'identita vlastnika ostava')
  NxTest.assert_equal(42, got['owner_pid'], 'a scope na KONKRETNU instanciu tiez')
  NxTest.assert_equal('front:F2/wing:single', A2B_ITEM['part_key'], 'povodna polozka sa NEMENI')
end

NxTest.test('KOV-A2b: bez ceruzky a mimo ciel sa vyber NEMENI (dnesne spravanie)') do
  pc = Noxun::Engine::ProductionCore
  NxTest.assert_equal(A2B_ITEM, pc.select_target_item(A2B_ITEM, 'F2', false),
                      'obycajny klik na riadok oznaci DIELEC ako doteraz')
  NxTest.assert_equal(A2B_ITEM, pc.select_target_item(A2B_ITEM, nil, true),
                      'nalez, ktory nie je o cele, ostava bez zmeny')
  NxTest.assert_equal(A2B_ITEM, pc.select_target_item(A2B_ITEM, '', true), 'prazdne ID tiez')
  NxTest.assert_equal(nil, pc.select_target_item(nil, 'F2', true), 'poskodena polozka nespadne')
end

NxTest.test('KOV-A2b: veta po ceruzke hovori o SKRINKE a o otvorenej karte') do
  pc = Noxun::Engine::ProductionCore
  one = pc.front_focus_status(1, 'F2')
  NxTest.assert(one.include?('Vybraná skrinka'), one)
  NxTest.assert(one.include?('karta čela F2 je otvorená'), one)
  NxTest.refute(one.include?('položiek'), 'oznacil sa korpus, nie „položky"')
  many = pc.front_focus_status(3, 'F1')
  NxTest.assert(many.include?('Vybraných 3 skriniek'), many)
end

NxTest.test('KOV-A2b: `focus` sa pocita PRED vyberom (inak by nemal na co vplyvat)') do
  sel = A2B_PCORE[/def do_select.*?\n      end\n/m].to_s
  i_focus = sel.index("focus = data['focus_inspector']")
  i_pids = sel.index('pids = pids_for_problem(model, select_target_item(')
  NxTest.assert(i_focus && i_pids, 'obe miesta musia existovat')
  NxTest.assert(i_focus < i_pids, 'ceruzka rozhoduje aj o CIELI vyberu, nielen o zdvihnuti okna')
  NxTest.assert_equal(1, sel.scan("focus = data['focus_inspector']").length,
                      'jedno miesto, kde sa ceruzka vyhodnocuje (dve by sa rozisli)')
  NxTest.assert(sel.include?('return status.call(front_focus_status(targets.length, front_id))'),
                'ceruzka na celo ma vlastnu vetu o skrinke')
end
