# frozen_string_literal: true
# UI-C2 — ZONY: serverovy kontrakt kontextu Zony.
#
# Co sa tu strazi (a preco to nestaci overit klikanim):
#   1) POCET POLIC 0–6 (Shelves::MAX) a jeho zrkadlo v JS,
#   2) GUARDY delenia — delit smie LEN LIST a LEN do 3 urovni; obe pravidla
#      musia zit na SERVERI, nie len ako HTML `disabled`,
#   3) LEGACY hlbky strom sa NIKDY neoreze (orezanie by zmazalo dielce zakazky),
#   4) JEDNA geometria pre zlomky aj magnet tahania priecky,
#   5) PRISNA validacia poli z panela ('650-36' sa nesmie ticho stat 650),
#   6) identita dokumentu + skrinky v KAZDOM zonovom callbacku,
#   7) navratova hodnota mutacie sa VETVI (odmietnutie = ziadny rebuild).
require_relative '../helper' unless defined?(NxTest)

ZT = Noxun::Engine::ZoneTree
UIC2_ZONES_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_zones.rb'))
UIC2_RESOLV_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'resolvers.rb'))
UIC2_ZONE_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'zone_tree.js'))
UIC2_ACTIONS_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'actions.js'))
UIC2_PANEL_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'))

# --- 1) police 0–6 -----------------------------------------------------------

NxTest.test('UI-C2: police maju strop 6 (pills 0–6), nie 4') do
  NxTest.assert_equal(6, Noxun::Engine::Shelves::MAX)
  NxTest.assert_equal(6, Noxun::Engine::Shelves.clamp(9))
  NxTest.assert_equal(6, Noxun::Engine::Shelves.clamp(6))
  NxTest.assert_equal(0, Noxun::Engine::Shelves.clamp(-2))
  # strom prevezme 6 bez orezania (default_node ide cez Shelves.clamp)
  NxTest.assert_equal(6, ZT.default_node(6)['shelves'])
end

NxTest.test('UI-C2: 6 polic sa aj rozlozi a zmesti do dost vysokej zony') do
  lay = Noxun::Engine::Shelves.layout(0.0, 1400.0, 18.0, 6)
  NxTest.assert_equal(6, lay[:shelves].size)
  NxTest.assert_equal(7, lay[:zones].size)
  NxTest.assert_close((1400.0 - 6 * 18.0) / 7.0, lay[:gap])
  box = { x0: 0.0, x1: 600.0, y0: 0.0, y1: 500.0, z0: 0.0, z1: 1400.0 }
  ZT.validate_shelves!(6, box, 18.0, 'CAB-001-Z1') # nesmie raisnut
  # prilis nizka zona 6 polic ODMIETNE (radsej odmietnut nez tichy nezmysel)
  low = box.merge(z1: 200.0)
  NxTest.assert_raise(/prilis nizka/) { ZT.validate_shelves!(6, low, 18.0, 'CAB-001-Z1') }
end

NxTest.test('UI-C2: JS zrkadlo konstant sedi na Ruby (jedno cislo, dve strany)') do
  NxTest.assert(UIC2_ZONE_JS.include?('MIN_FIELD: 20'), 'JS MIN_FIELD musi sediet na ZoneTree::MIN_FIELD')
  NxTest.assert_equal(20.0, ZT::MIN_FIELD)
  NxTest.assert(UIC2_ZONE_JS.include?('MAX_LEVELS: 3'), 'JS MAX_LEVELS musi sediet na ZoneTree::MAX_LEVELS')
  NxTest.assert_equal(3, ZT::MAX_LEVELS)
  NxTest.assert(UIC2_ZONE_JS.include?('MAX_SHELVES: 6'), 'JS MAX_SHELVES musi sediet na Shelves::MAX')
  NxTest.assert(UIC2_ZONE_JS.include?('EPS: 0.01'), 'JS presnost musi sediet na FIELD_EPS')
  NxTest.assert_close(0.01, ZT::FIELD_EPS)
end

# --- 2) guardy delenia (list + hlbka) ---------------------------------------

NxTest.test('UI-C2: delit smie LEN listova zona (delena = najprv Vycistit)') do
  tree = ZT.default_tree(0)
  NxTest.assert_equal(true, ZT.set_split!(tree, [1], 'v', 2))
  NxTest.assert_equal(false, ZT.set_split!(tree, [1], 'h', 3),
                      'druhe delenie tej istej zony by ticho zmazalo cely podstrom')
  # strom ostal nedotknuty (os aj pocet z PRVEHO delenia)
  NxTest.assert_equal('v', tree['split']['axis'])
  NxTest.assert_equal(2, tree['split']['count'])
  # po vycisteni sa uz delit da
  NxTest.assert_equal(true, ZT.clear_zone!(tree, [1]))
  NxTest.assert_equal(true, ZT.set_split!(tree, [1], 'h', 3))
end

NxTest.test('UI-C2: police smie dostat LEN listova zona') do
  tree = ZT.default_tree(0)
  ZT.set_split!(tree, [1], 'v', 2)
  NxTest.assert_equal(false, ZT.set_shelves!(tree, [1], 3),
                      'police na delenej zone by zmazali podstrom aj s materialmi dielcov')
  NxTest.assert(tree['split'].is_a?(Hash), 'delenie muselo prezit')
  NxTest.assert_equal(true, ZT.set_shelves!(tree, [1, 1], 3)) # dieta je list
  NxTest.assert_equal(3, tree['children'][0]['shelves'])
  NxTest.assert_equal(false, ZT.set_shelves!(tree, [1, 5], 1), 'neexistujuca cesta = false')
end

NxTest.test('UI-C2 (N22): strom ma najviac 3 urovne — 4. delenie sa odmietne') do
  tree = ZT.default_tree(0)
  NxTest.assert_equal(true, ZT.set_split!(tree, [1], 'v', 2))        # uroven 2
  NxTest.assert_equal(true, ZT.set_split!(tree, [1, 1], 'h', 2))     # uroven 3
  NxTest.assert_equal(false, ZT.set_split!(tree, [1, 1, 1], 'v', 2), # uroven 4 = stop
                      'delenie na 3. urovni by vyrobilo 4. uroven')
  NxTest.assert_equal(nil, ZT.navigate(tree, [1, 1, 1])['split'])
  NxTest.assert_equal(3, ZT.depth(tree))
end

NxTest.test('UI-C2 (B4): legacy hlboky strom sa NEOREZAVA — len sa oznaci') do
  legacy = { 'id' => 'Z1', 'split' => { 'axis' => 'v', 'count' => 2 },
             'children' => [
               { 'id' => 'A', 'split' => { 'axis' => 'h', 'count' => 2 },
                 'children' => [
                   { 'id' => 'B', 'split' => { 'axis' => 'v', 'count' => 2 },
                     'children' => [{ 'id' => 'C', 'shelves' => 2 }, { 'id' => 'D' }] },
                   { 'id' => 'E' }
                 ] },
               { 'id' => 'F' }
             ] }
  NxTest.assert_equal(4, ZT.depth(legacy))
  out = ZT.sanitize(legacy)
  NxTest.assert_equal(4, ZT.depth(out), 'sanitize nesmie hlbku orezat — zmazal by dielce zakazky')
  # 4. uroven ostava aj s policami a svojim ID (material/ABS override drzia na ID)
  deep = ZT.navigate(out, [1, 1, 1, 1])
  NxTest.assert_equal('C', deep['id'])
  NxTest.assert_equal(2, deep['shelves'])
  # ale delit sa uz nedá
  NxTest.assert_equal(false, ZT.set_split!(out, [1, 1, 1], 'v', 2))
end

# --- 3) JEDNA geometria: zlomky aj magnet ------------------------------------

NxTest.test('UI-C2 (F6): zlomok sa pocita zo SVETLEHO priestoru, stred priecky na zlomku') do
  span = 864.0
  t = 18.0
  NxTest.assert_close(846.0, ZT.clear_space(span, 2, t))
  # 1/2 pri dvoch poliach = presne polovica SVETLEHO priestoru (nie 432 z mockupu)
  half = ZT.cum_for_fraction(span, 2, t, 0, Rational(1, 2))
  NxTest.assert_close(423.0, half)
  NxTest.assert_close(ZT.clear_space(span, 2, t) / 2.0, half)
  # a stred priecky vtedy sedi PRESNE v polovici rozpatia
  NxTest.assert_close(span / 2.0, half + t / 2.0)
  # 1/4 a 3/4 su symetricke okolo stredu
  q1 = ZT.cum_for_fraction(span, 2, t, 0, Rational(1, 4))
  q3 = ZT.cum_for_fraction(span, 2, t, 0, Rational(3, 4))
  NxTest.assert_close(span / 4.0, q1 + t / 2.0)
  NxTest.assert_close(3 * span / 4.0, q3 + t / 2.0)
end

NxTest.test('UI-C2 (F6): tri polia — zlomok druhej priecky rata OBE priecky pred nou') do
  span = 900.0
  t = 18.0
  # priecka s indexom 1: pred jej stredom lezia 2 polia a 1 cela priecka
  cum = ZT.cum_for_fraction(span, 3, t, 1, Rational(1, 2))
  NxTest.assert_close(span / 2.0, cum + 1 * t + t / 2.0)
end

NxTest.test('UI-C2 (F6/N20): magnet prilepi na zlomok len v ramci prahu; Alt ho vypina') do
  span = 864.0
  t = 18.0
  half = ZT.cum_for_fraction(span, 2, t, 0, Rational(1, 2))
  NxTest.assert_close(half, ZT.snap_cum(span, 2, t, 0, half + 3.0, 6.0))  # v prahu -> prilepi
  NxTest.assert_close(half + 30.0, ZT.snap_cum(span, 2, t, 0, half + 30.0, 6.0)) # mimo prahu -> nedotknute
  # Alt = tolerancia 0 -> magnet vypnuty aj presne na zlomku
  NxTest.assert_close(half + 0.4, ZT.snap_cum(span, 2, t, 0, half + 0.4, 0.0))
end

NxTest.test('UI-C2 (N21): ponuka zlomkov vynecha tie, ktore sa do zony nezmestia') do
  # uzka zona: 1/4 by prvemu polu nechalo menej nez MIN_FIELD (25 - 9 = 16 mm)
  opts = ZT.fraction_options(100.0, 2, 18.0, 0)
  NxTest.assert(opts.none? { |o| o['label'] == '1/4' }, 'nedosiahnutelny zlomok sa nesmie ponukat')
  NxTest.assert(opts.any? { |o| o['label'] == '1/2' })
  full = ZT.fraction_options(864.0, 2, 18.0, 0)
  NxTest.assert_equal(%w[1/4 1/3 1/2], full.map { |o| o['label'] })
end

# --- 4) prisna validacia poli z panela ---------------------------------------

NxTest.test('UI-C2 (F8): prisny parse — text sa NIKDY ticho nestane cislom') do
  NxTest.assert_equal(nil, ZT.strict_mm(nil))
  NxTest.assert_equal(nil, ZT.strict_mm('   '))
  NxTest.assert_close(650.0, ZT.strict_mm('650'))
  NxTest.assert_close(650.5, ZT.strict_mm('650,5'))  # slovenska desatinna ciarka
  NxTest.assert_equal(:invalid, ZT.strict_mm('650-36'), "'650-36'.to_f by ticho vratilo 650")
  NxTest.assert_equal(:invalid, ZT.strict_mm('abc'))
  NxTest.assert_equal(:invalid, ZT.strict_mm(Float::INFINITY))
  NxTest.assert_equal(:invalid, ZT.strict_mm(Float::NAN))
end

NxTest.test('UI-C2 (F8): cuts z panela musia sediet poctom, minimom aj suctom') do
  ok = [{ 'size' => 400.0, 'locked' => true }, { 'size' => 446.0, 'locked' => false }]
  NxTest.assert_equal(nil, ZT.validate_cuts(ok, 2, clear: 846.0))
  NxTest.assert(ZT.validate_cuts(ok, 3, clear: nil).to_s.include?('poškodené'), 'iny pocet poli = odmietnutie')
  small = [{ 'size' => 5.0 }, { 'size' => 841.0 }]
  NxTest.assert(ZT.validate_cuts(small, 2, clear: 846.0).to_s.include?('najmenšie pole'))
  over = [{ 'size' => 700.0 }, { 'size' => 400.0 }]
  NxTest.assert(ZT.validate_cuts(over, 2, clear: 846.0).to_s.include?('nezmestia'))
  under = [{ 'size' => 300.0 }, { 'size' => 300.0 }]
  NxTest.assert(ZT.validate_cuts(under, 2, clear: 846.0).to_s.include?('nevyplnia'))
  bad = [{ 'size' => '650-36' }, { 'size' => 200.0 }]
  NxTest.assert(ZT.validate_cuts(bad, 2, clear: 846.0).to_s.include?('platné číslo'))
  # AUTO pole (prazdne) je platne a kontrolu suctu vypina
  auto = [{ 'size' => nil }, { 'size' => 400.0 }]
  NxTest.assert_equal(nil, ZT.validate_cuts(auto, 2, clear: 846.0))
  # tolerancia 0,01 mm — mm Float, nie cele mm
  NxTest.assert_equal(nil, ZT.validate_cuts([{ 'size' => 423.004 }, { 'size' => 423.0 }], 2, clear: 846.0))
end

NxTest.test('UI-C2 (Codex #177 P2): tolerancia suctu rastie s poctom poli') do
  # Kazda hodnota z panela je zaokruhlena na 0,01 mm — pri 4 poliach sa sucet
  # moze od skutocneho svetleho priestoru lisit az o 4 pol-jednotky. Prisnejsia
  # tolerancia by odmietala geometricky spravne rozdelenia.
  four = Array.new(4) { { 'size' => 201.78 } } # skutocnost 4 x 201.775 = 807.1
  NxTest.assert_equal(nil, ZT.validate_cuts(four, 4, clear: 807.1))
  # a naozaj zla hodnota sa aj tak odmietne
  NxTest.assert(ZT.validate_cuts(four, 4, clear: 900.0).to_s.include?('nevyplnia'))
end

NxTest.test('UI-C2 (Codex #177 P2): svetly priestor sa cita z ROZPATIA, nie zo suctu poli') do
  body = UIC2_ZONES_RB[/def zone_clear_span\(.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'zone_clear_span sa nenasiel')
  NxTest.assert(body.include?('ZoneTree.clear_space('),
                'clear sa musi pocitat z rozpatia — sucet poli je uz zaokruhleny (r2 na kazdom poli)')
  NxTest.refute(body.include?('[:fields]'), 'sucet zaokruhlenych poli sa uz pouzivat nesmie')
  # a zdielana funkcia naozaj odratava priecky
  NxTest.assert_close(846.0, ZT.clear_space(864.0, 2, 18.0))
  NxTest.assert_close(807.1, ZT.clear_space(861.1, 4, 18.0))
end

# --- 5) handlery: identita dokumentu, listovost, navratova hodnota ------------

NxTest.test('UI-C2 (F9): KAZDY zonovy callback overuje dokument aj skrinku') do
  ctx = UIC2_ZONES_RB[/def zone_ctx.*?\n        end\n/m].to_s
  NxTest.refute(ctx.empty?, 'spolocny vstup zone_ctx sa nenasiel')
  NxTest.assert(ctx.include?(%q<DocKey.foreign?(data['model_guid'], model)>),
                'identita dokumentu sa musi porovnavat PRISNE (ID zon sa medzi dokumentmi opakuju)')
  NxTest.assert(ctx.include?("data['cabinet_id'].to_s"), 'callback musi niest aj identitu skrinky')
  %w[handle_split_zone handle_set_zone_shelves handle_clean_zone handle_set_zone_field].each do |h|
    body = UIC2_ZONES_RB[/def #{h}\(.*?\n        end\n/m].to_s
    NxTest.assert(body.include?('zone_ctx('), "#{h} musi ist cez spolocny guard zone_ctx")
  end
  # aj necinny select_zone (inak by ghost cudzieho modelu prepol aktivnu zonu)
  sel = UIC2_ZONES_RB[/def handle_select_zone\(.*?\n        end\n/m].to_s
  NxTest.assert(sel.include?(%q<DocKey.foreign?(data['model_guid'], model)>))
  # a klient metadata naozaj posiela — z JEDNEHO miesta
  NxTest.assert(UIC2_ZONE_JS.include?('function nxZonePayload'), 'JS musi mat jedno miesto pre metadata')
  NxTest.assert(UIC2_ZONE_JS.include?('o.model_guid') && UIC2_ZONE_JS.include?('o.cabinet_id'))
  %w[split_zone set_zone_shelves clean_zone select_zone].each do |cb|
    NxTest.refute((UIC2_ACTIONS_JS + UIC2_ZONE_JS + File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'preview.js')))
                    .include?("sketchup.#{cb}(JSON.stringify("),
                  "#{cb} sa nesmie posielat bez metadat identity (nxZonePayload)")
  end
end

NxTest.test('UI-C2: poskodene zone_id sa ODMIETNE — ziadny fallback na koren') do
  code = UIC2_RESOLV_RB[/def zone_path\(.*?\n        end\n/m].to_s
  NxTest.refute(code.include?('return [1]'),
                'fallback na koren by nechal „Vycistit zonu" zmazat cele vnutro skrinky')
  NxTest.assert(code.include?('return nil'), 'poskodene ID musi vratit nil')
  NxTest.assert(UIC2_RESOLV_RB.include?('ZONE_ID_RE'), 'format ID sa musi validovat celý')
  guard = UIC2_ZONES_RB[/def zone_ctx.*?\n        end\n/m].to_s
  NxTest.assert(guard.include?('path.nil?'), 'handler musi nil cestu vetvit hlaskou')
end

NxTest.test('UI-C2: odmietnuta mutacia NESMIE spustit rebuild') do
  body = UIC2_ZONES_RB[/def apply_zone_mod\(.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'apply_zone_mod sa nenasiel')
  NxTest.assert(body.include?('unless yield(tree, ctx[:path])'),
                'navratova hodnota mutacie sa musi vetvit')
  idx_guard = body.index('unless yield')
  idx_build = body.index('CabinetBuilder.rebuild')
  NxTest.assert(idx_guard && idx_build && idx_guard < idx_build,
                'kontrola musi bezat PRED prestavbou')
  NxTest.assert(body.include?('return nil'), 'neuspech vracia nil — volajuci nesmie hlasit uspech')
  # a volajuci to naozaj vetvi
  %w[handle_split_zone handle_set_zone_shelves handle_clean_zone].each do |h|
    NxTest.assert(UIC2_ZONES_RB[/def #{h}\(.*?\n        end\n/m].to_s.include?('return unless apply_zone_mod'),
                  "#{h} musi status uspechu vypisat az po uspesnej mutacii")
  end
end

NxTest.test('UI-C2 (F12): status presnej cesty sa cita z toho, co sa ULOZILO') do
  body = UIC2_ZONES_RB[/def field_status\(.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'field_status sa nenasiel')
  NxTest.assert(body.include?("cuts.is_a?(Array) ? cuts[index] : nil"),
                'status musi vychadzat z cuts[index], nie z prazdneho size (inak klame „auto")')
end

NxTest.test('UI-C2 (B4): legacy hlbka sa pri vlozeni aj sablone POVIE nahlas') do
  note = UIC2_ZONES_RB[/def zone_depth_note\(.*?\n        end\n/m].to_s
  NxTest.refute(note.empty?, 'zone_depth_note sa nenasiel')
  NxTest.assert(note.include?('MAX_LEVELS'), 'varovanie sa musi viazat na MAX_LEVELS')
  cab = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'))
  NxTest.assert(cab.include?('zone_depth_note('), 'vlozenie musi varovanie ukazat')
  tpl = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'))
  NxTest.assert(tpl.include?('Panel.zone_depth_note('), 'aplikacia sablony musi varovanie ukazat')
end

# --- 6) kostra panela (kontrakt UI 2.0) --------------------------------------

NxTest.test('UI-C2: kostra kontextu Zony ma poradie Struktura · Delenie · Police · Vnutro') do
  order = UIC2_PANEL_HTML.scan(/data-key="(zones|zsplit|zshelves|zinside)"/).flatten
  NxTest.assert_equal(%w[zones zsplit zshelves zinside], order,
                      'Struktura zon patri NAVRCH kontextu (kontrakt UI 2.0)')
  struct = UIC2_PANEL_HTML[/data-key="zones"[^>]*>/].to_s
  NxTest.assert(struct.include?('data-s4-solo'), 'strom ostava MIMO exkluzivity skupin')
  NxTest.assert(UIC2_PANEL_HTML.include?('id="zoneTiles"'), 'chybaju dlazdice delenia')
  NxTest.assert(UIC2_PANEL_HTML.include?('id="zoneShelfPills"'), 'chybaju pilulky polic')
  NxTest.assert(UIC2_PANEL_HTML.include?('id="zoneFirst"'), 'chyba pole „Prva zona"')
  # 4 dlazdice presne podla mockupu
  %w[2\ stĺpce 3\ stĺpce 2\ riadky 3\ riadky].each do |lab|
    NxTest.assert(UIC2_PANEL_HTML.include?(">#{lab.tr('\\', '')}<"), "chyba dlazdica „#{lab.tr('\\', '')}\"")
  end
  NxTest.assert(UIC2_PANEL_HTML.include?('Vnútro'), 'chyba rezervovany slot Vnutro')
end

NxTest.test('UI-C2: neaktivny ovladac je aria-disabled s vysvetlenim (vzor D-78)') do
  fn = UIC2_ACTIONS_JS[/function setZoneCtl\(.*?\n  \}/m].to_s
  NxTest.refute(fn.empty?, 'setZoneCtl sa nenasiel')
  NxTest.assert(fn.include?("setAttribute('aria-disabled'"), 'stav musi ist cez aria-disabled')
  NxTest.assert(fn.include?("setAttribute('title'"), 'dovod musi byt citatelny v tooltipe')
  NxTest.refute(fn.include?('.disabled = true'), 'HTML disabled by zhltol hover aj tooltip')
end

NxTest.test('UI-C2: ikony dlazdic ziju v sprite (ziadne emoji v UI chrome)') do
  icons = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'))
  %w[columns-2 columns-3 rows-2 rows-3].each do |n|
    NxTest.assert(icons.include?("'#{n}':"), "chyba ikona #{n} v sprite")
    NxTest.assert(UIC2_PANEL_HTML.include?("#i-#{n}"), "dlazdica nepouziva sprite ikonu #{n}")
  end
end
