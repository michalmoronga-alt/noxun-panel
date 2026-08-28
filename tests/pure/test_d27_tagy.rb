# frozen_string_literal: true
# D-27 „Rýchle zobraziť/skryť tagy modelu z panela" — kontrakt dávky.
#
# Kontrolovane invarianty:
#   1) REGISTER TAGOV nema vlastnu kopiu mien — cita konstanty builderov;
#      whitelist klucov je uzavrety a `Noxun/Zóny` je jediny kluc, ktory smie
#      vzniknut z panela,
#   2) CITANIE STAVU je ciste (ziadna operacia, ziadny `layers.add`) a vracia
#      LEN tagy, ktore v modeli su (D-78),
#   3) ZAPIS bezi v JEDNEJ operacii s ABORT vetvou (viditelnost tagu je zapis
#      do .skp — na rozdiel od overlayov D-103/D-104/D-105),
#   4) JEDEN ZDROJ STAVU, DVA OVLADACE: okno tagov v raile aj checkbox ghost
#      zon idu cez `Engine.set_tag_visible`; `Zones` uz vlastnu cestu nema,
#   5) SERVEROVE GUARDY panela: identita dokumentu + whitelist + vyslovny
#      boolean; odmietnutie NEZAPISUJE a obnovi stav,
#   6) stav chodi s KAZDYM pushom vyberu (Spat/Znova, prepnutie dokumentu),
#   7) rail: vlastny kluc meraca, ziadny rohovy trojuholnik (nie je to
#      „toggle + nastavenie"), ziadny novy riadok v obsahu panela,
#   8) overlay kontroly hran a kresby NEKRESLI nad skrytym tagom.
require_relative '../helper' unless defined?(NxTest)

D27 = Noxun::Engine::Tags

D27_SRC    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'tags.rb'), encoding: 'UTF-8')
D27_ZONES  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'zones.rb'), encoding: 'UTF-8')
D27_MAIN   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
D27_PANEL  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
D27_ACT    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates.rb'),
                       encoding: 'UTF-8')
D27_SYNC   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'), encoding: 'UTF-8')
D27_HTML   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
D27_CSS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
D27_SHELL  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')
D27_ACTJS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'actions.js'), encoding: 'UTF-8')
D27_BRIDGE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
D27_BOOT   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'boot.js'), encoding: 'UTF-8')
D27_USAGE  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'usage.js'), encoding: 'UTF-8')
D27_MENU   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'tag_menu.js'), encoding: 'UTF-8')
D27_EDGE   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'edge_check.rb'), encoding: 'UTF-8')

# --- 1) register tagov --------------------------------------------------------

NxTest.test('D-27: mena tagov cita register z KONSTANT builderov (ziadna kopia retazca)') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert_equal(cb::PART_TAG_DEFAULT, D27.tag_name('korpus'))
  NxTest.assert_equal(cb::PART_TAGS['back'], D27.tag_name('chrbat'))
  NxTest.assert_equal(cb::PART_TAGS['front_door'], D27.tag_name('cela'))
  NxTest.assert_equal(cb::PART_TAGS['shelf'], D27.tag_name('vnutro'))
  NxTest.assert_equal(cb::HARDWARE_TAG, D27.tag_name('kovanie'))
  # BoardBuilder ma konstanty vnutri `class << self` — register ich musi najst
  # aj tam (inak by `Noxun/Dosky` z ponuky ticho vypadlo).
  NxTest.assert_equal(Noxun::Engine::BoardBuilder.singleton_class::BOARD_TAG, D27.tag_name('dosky'))
  NxTest.assert_equal(Noxun::Engine::Zones::TAG, D27.tag_name('zony'))
  # Meno tagu sa v module NESMIE vyskytnut ako literal — inak by sa po
  # premenovani v builderi ticho rozislo.
  %w[Noxun/Korpus Noxun/Chrbát Noxun/Čelá Noxun/Vnútro Noxun/Kovanie Noxun/Dosky Noxun/Zóny].each do |lit|
    NxTest.refute(D27_SRC.include?(lit), "meno tagu #{lit} je v tags.rb opisane natvrdo")
  end
end

NxTest.test('D-27: whitelist klucov je uzavrety a neznamy kluc nema meno') do
  NxTest.assert_equal(%w[korpus chrbat cela vnutro kovanie dosky zony], D27::KEYS)
  NxTest.assert_equal(nil, D27.tag_name('cudzi'))
  NxTest.assert_equal(nil, D27.tag_name(nil))
  NxTest.assert_equal(D27::ROWS.length, D27::KEYS.length)
  NxTest.assert(D27::ROWS.all? { |r| !r['label'].to_s.strip.empty? }, 'kazdy riadok ma popis')
end

NxTest.test('D-27: z panela smie vzniknut LEN tag zon (ostatne tvori stavba)') do
  NxTest.assert_equal(%w[zony], D27::CREATABLE_KEYS)
  NxTest.assert(D27::CREATABLE_KEYS.all? { |k| D27::KEYS.include?(k) },
                'tvoritelny kluc musi byt aj vo whitelist')
end

# --- 2) citanie stavu je ciste ------------------------------------------------

NxTest.test('D-27: citanie stavu NIKDY netvori ani nepremenuva tag') do
  read = D27_SRC[/def state\(model\).*?\n      end\n/m].to_s
  NxTest.refute(read.empty?, 'Tags.state sa nenasiel')
  ['layers.add', 'start_operation', 'commit_operation', '.name =', '.visible ='].each do |forbidden|
    NxTest.refute(read.include?(forbidden), "citanie stavu nesmie obsahovat #{forbidden}")
  end
  lay = D27_SRC[/def layer_of\(model, key\).*?\n      end\n/m].to_s
  NxTest.refute(lay.include?('layers.add'), 'hladanie tagu ho nesmie zalozit')
end

NxTest.test('D-27: bez modelu / bez tagov je stav prazdny a nepada') do
  st = D27.state(nil)
  NxTest.assert_equal([], st['rows'])
  NxTest.assert_equal(0, st['hidden'])
end

NxTest.test('D-27: legacy tag zon (NOXUN_SLOTY) sa cita rovnako tolerantne ako Zones.visible?') do
  body = D27_SRC[/def layer_of\(model, key\).*?\n      end\n/m].to_s
  NxTest.assert(body.include?(':OLD_TAG'),
                'stara zakazka by inak tag zon „nenasla" a riadok by z ponuky vypadol')
  NxTest.assert(body.include?("key.to_s == 'zony'"), 'tolerancia patri VYHRADNE zonam')
end

# --- 3) zapis = jedna operacia s abort vetvou ---------------------------------

NxTest.test('D-27: viditelnost tagu sa zapisuje v JEDNEJ operacii (je to zapis do .skp)') do
  w = D27_SRC[/def write\(model, lay, name, want\).*?\n      end\n/m].to_s
  NxTest.refute(w.empty?, 'Tags.write sa nenasiel')
  NxTest.assert(w.include?("model.start_operation(OP_NAME, true)"), 'zapis musi otvorit operaciu')
  NxTest.assert(w.include?('model.commit_operation'), 'a zavriet ju')
  NxTest.assert(w.include?('model.abort_operation'),
                'vynimka nesmie nechat otvorenu transakciu (rozbila by nasledujuce Spat)')
  NxTest.assert_equal(1, w.scan(/start_operation/).length)
end

NxTest.test('D-27: ked sa nic nemeni, ziadna operacia sa NEOTVORI') do
  s = D27_SRC[/def set_visible\(model, key, visible\).*?\n      end\n/m].to_s
  NxTest.refute(s.empty?, 'Tags.set_visible sa nenasiel')
  NxTest.refute(s.include?('start_operation'), 'rozhodovanie sa deje PRED otvorenim operacie')
  NxTest.assert(s.include?('KEYS.include?(k)'), 'neznamy kluc = nic')
  NxTest.assert(s.include?('CREATABLE_KEYS.include?(k)'), 'neexistujuci tag = nic')
  NxTest.assert(s.include?("(lay.visible? ? true : false) == want"),
                'uz platna hodnota = ziadny prazdny krok Spat')
  NxTest.assert(s.include?('visible == true'), 'hodnota je VYSLOVNY boolean')
end

NxTest.test('D-27: skrytie AKTIVNEHO tagu presunie kreslenie vedome a v tej istej operacii') do
  m = D27_SRC[/def move_active_layer_away\(model, lay\).*?\n      end\n/m].to_s
  NxTest.refute(m.empty?, 'presun aktivneho tagu sa nenasiel')
  NxTest.assert(m.include?('model.active_layer = untagged'), 'kreslenie ide na Untagged')
  w = D27_SRC[/def write\(model, lay, name, want\).*?\n      end\n/m].to_s
  NxTest.assert(w =~ /start_operation.*move_active_layer_away.*commit_operation/m,
                'presun musi byt SUCASTOU tej istej operacie (inak dva kroky Spat)')
  NxTest.assert(w.include?('unless want'), 'presuva sa len pri SKRYVANI')
end

# --- 4) jeden zdroj stavu, dva ovladace ---------------------------------------

NxTest.test('D-27: prepnutie ma JEDNU zdielanu cestu (Engine.set_tag_visible)') do
  shared = D27_MAIN[/def self\.set_tag_visible.*?\n    end\n/m].to_s
  NxTest.refute(shared.empty?, 'Engine.set_tag_visible musi existovat')
  NxTest.assert(shared.include?('Tags.set_visible('), 'zdielana cesta prepina tag')
  NxTest.assert(shared.include?('broadcast_tags(state)'),
                'po prepnuti sa stav VZDY rozposle (inak ostane druhy ovladac na starom)')
  NxTest.assert(D27_ACT.include?('Engine.set_tag_visible(key, value, model)'),
                'panel ide zdielanou cestou')
end

NxTest.test('D-27: Zones uz vlastnu zapisovaciu cestu NEMA') do
  NxTest.refute(D27_ZONES.include?('def set_visible'),
                'Zones.set_visible zanikol — tag zon prepina zdielana cesta Tags')
  NxTest.assert(D27_ZONES.include?('def visible?'), 'citanie stavu zon ostava')
  # Ziadny druhy zapis viditelnosti v UI vrstve panela — prepina sa VYHRADNE
  # cez core/tags.rb. (V `zones.rb` ostava jediny legitimny zapis: D-04 default
  # „novy tag zon vznika VYPNUTY" pri stavbe ghostov, teda uz v operacii stavby.)
  [D27_ACT, D27_SYNC, D27_PANEL].each do |src|
    code = src.gsub(/#.*$/, '')
    NxTest.refute(code =~ /\.visible\s*=[^=]/, 'viditelnost tagu smie zapisovat LEN core/tags.rb')
  end
  zones_code = D27_ZONES.gsub(/#.*$/, '')
  NxTest.assert_equal(1, zones_code.scan(/\.visible\s*=[^=]/).length)
end

NxTest.test('D-27: checkbox ghost zon ide TOU ISTOU cestou ako okno tagov') do
  NxTest.refute(D27_PANEL.include?("cb(dlg, 'toggle_zones')"),
                'stary callback bez identity dokumentu ZANIKOL')
  NxTest.refute(D27_ACT.include?('def handle_toggle_zones'), 'a jeho handler tiez')
  NxTest.assert(D27_ACTJS.include?('sketchup.nx_tag_visible'), 'checkbox posiela novy callback')
  NxTest.assert(D27_ACTJS =~ /function toggleZones\(\).*?'zony'/m, 'a posiela kluc `zony`')
  NxTest.assert(D27_ACTJS =~ /function toggleZones\(\).*?model_guid/m,
                'checkbox musi niest identitu dokumentu')
end

# --- 5) serverove guardy panela ----------------------------------------------

NxTest.test('D-27: panel prijima LEN whitelistovany kluc a VYSLOVNY boolean') do
  h = D27_ACT[/def handle_tag_visible.*?\n        end\n/m].to_s
  NxTest.refute(h.empty?, 'handler sa nenasiel')
  NxTest.assert(h.include?('Tags::KEYS.include?(key)'), 'kluc musi prejst whitelistom servera')
  NxTest.assert(h.include?('(value == true || value == false)'),
                'hodnota musi byt VYSLOVNE boolean (retazec "false" je v Ruby pravdivy)')
  NxTest.assert(h.include?("data['model_guid'].to_s == model_guid(model)"),
                'PRISNA zhoda dokumentu (callback HtmlDialogu je asynchronny)')
  NxTest.assert_equal(2, h.scan(/push_tags/).length)
  NxTest.assert(h.include?('set_status'), 'odmietnutie sa povie nahlas')
end

NxTest.test('D-27: odmietnuty klik do modelu NEZAPISUJE') do
  h = D27_ACT[/def handle_tag_visible.*?\n        end\n/m].to_s
  # Guardy stoja PRED jedinym volanim zapisovej cesty.
  guards = h.index('Engine.set_tag_visible')
  NxTest.assert(guards, 'zapisova cesta sa v handleri nenasla')
  NxTest.assert(h.index('model_guid(model)') < guards, 'guard dokumentu je PRED zapisom')
  NxTest.assert(h.index('Tags::KEYS.include?') < guards, 'whitelist je PRED zapisom')
  %w[start_operation commit_operation layers.add].each do |forbidden|
    NxTest.refute(h.include?(forbidden), "handler nesmie volat #{forbidden} — zapis patri do Tags")
  end
end

NxTest.test('D-27: potvrdenie sklada SERVER a prizna aj to, ze sa nestalo nic') do
  s = D27_ACT[/def tag_toggle_status.*?\n        end\n/m].to_s
  NxTest.refute(s.empty?, 'skladanie statusu sa nenaslo')
  NxTest.assert(s.include?('nič sa nezmenilo'), 'neexistujuci tag sa prizna')
  NxTest.assert(s.include?('folder_hidden'), 'skryty priecinok tagov sa prizna')
  NxTest.assert(s.include?("state['active_reset']"), 'presun kreslenia sa prizna')
end

# Review #249 P2: uspech sa hlasi podla VYSLEDNEHO stavu, nie podla toho, co si
# klient pytal — zlyhany zapis (abortovana operacia) by inak potvrdil zmenu,
# ktora sa nestala.
NxTest.test('D-27: status potvrdi zmenu az podla VYSLEDNEHO stavu tagu') do
  s = D27_ACT[/def tag_toggle_status.*?\n        end\n/m].to_s
  NxTest.assert(s.include?("(row['visible'] == true) == value"),
                'porovnava sa skutocna viditelnost so ziadanou hodnotou')
  NxTest.assert(s.include?('nepodarilo prepnúť'), 'zlyhanie zapisu sa povie nahlas')
  NxTest.assert(s.scan(/, true\]/).length >= 2, 'a hlasi sa ako CHYBA, nie ako potvrdenie')
  h = D27_ACT[/def handle_tag_visible.*?\n        end\n/m].to_s
  NxTest.assert(h.include?('msg, err = tag_toggle_status'), 'handler vetvi aj priznak chyby')
  NxTest.assert(h.include?('set_status(msg, err)'), 'a posiela ho do statusu')
end

# --- 6) stav chodi s kazdym pushom -------------------------------------------

NxTest.test('D-27: viditelnost tagov chodi PULL pri otvoreni aj s KAZDYM pushom vyberu') do
  NxTest.assert(D27_SYNC.include?('tags: tags_state'), 'init panela nesie stav (PULL)')
  NxTest.assert(D27_SYNC.include?('def push_tags'), 'push kanal existuje')
  push = D27_SYNC[/def push_selected\(model, dedup: true\).*?\n          js\("NX\.loadSelected/m].to_s
  NxTest.assert(push.include?('push_tags(tags_state(model))'),
                'Spat/Znova, prepnutie dokumentu aj zmena vyberu idu TOUTO cestou — bez pushu ' \
                'by ovladace ostali na opacnom stave nez model')
  NxTest.refute(D27_SYNC.include?('zones_visible:'),
                'druhy zdroj pravdy o zonach (pole zones_visible) zanikol')
  NxTest.refute(D27_BRIDGE.include?('data.zones_visible'), 'ani na strane klienta')
end

NxTest.test('D-27: callback nx_tag_visible je zaregistrovany cez zdielany cb wrapper') do
  NxTest.assert(D27_PANEL.include?("cb(dlg, 'nx_tag_visible')"), 'callback musi byt zaregistrovany')
  NxTest.assert(D27_PANEL.include?('handle_tag_visible(p)'), 'callback mieri na handler')
  NxTest.refute(D27_PANEL.include?("add_action_callback('nx_tag_visible')"),
                'callback ide cez zdielany cb wrapper, nie priamo')
end

# --- 7) rail: umiestnenie a merac --------------------------------------------

NxTest.test('D-27: okno tagov je v RAILE — v obsahu panela nepribudol ziadny riadok') do
  NxTest.assert(D27_HTML.include?('id="railTagy"'), 'rail ma tlacidlo tagov')
  NxTest.assert(D27_HTML.include?('id="railTagsMenu"'), 'a okno so zoznamom')
  NxTest.assert(D27_HTML.include?('onclick="onTagMenuToggle(event)"'), 'klik otvara okno')
  NxTest.assert(D27_HTML.include?('aria-haspopup="true"') && D27_HTML.include?('id="railTagyBox"'),
                'citacka musi vediet, ze tlacidlo otvara ponuku')
  css = D27_CSS.gsub(%r{/\*.*?\*/}m, ' ')
  NxTest.assert(css =~ /\.tgmenu \{[^}]*position:\s*absolute/,
                'zoznam je OVERLAY — vertikalny priestor panela sa jeho otvorenim nemeni')
end

NxTest.test('D-27: tlacidlo NEMA rohovy trojuholnik (nie je to „toggle + nastavenie")') do
  box = D27_HTML[/<div class="railmenu" id="railTagyBox">.*?<\/div>\s*<span class="railgap">/m].to_s
  NxTest.refute(box.empty?, 'obal tlacidla sa nenasiel')
  NxTest.refute(box.include?('railfly'),
                '`.railfly` kresli trojuholnik KAZDEMU .railbtn v sebe — obal musi byt vlastny')
  NxTest.refute(box.include?('railcorner'), 'ziadna rohova zona — cele tlacidlo otvara okno')
  css = D27_CSS.gsub(%r{/\*.*?\*/}m, ' ')
  NxTest.assert(css.include?('.nx-inspector .railmenu'), 'vlastny obal ma vlastny styl')
  NxTest.refute(css =~ /\.railmenu \.railbtn::after/, 'obal tagov trojuholnik nekresli')
end

NxTest.test('D-27: klik ma VLASTNY kluc meraca (D-25) z allowlistu') do
  allow = D27_USAGE[/var USAGE_KEYS = \[(.*?)\];/m].to_s.scan(/'([^']+)'/).flatten
  NxTest.assert(allow.include?('rail:tagy'), 'kluc okna tagov musi byt v allowliste')
  NxTest.assert_equal(1, allow.count('rail:tagy'))
  NxTest.assert(D27_HTML.include?('data-nx-usage="rail:tagy"'), 'tlacidlo kluc naozaj vyhlasuje')
end

NxTest.test('D-27: ikona je zo SPRITU (ziadne emoji, ziadna nova kresba)') do
  NxTest.assert(D27_HTML.include?('href="#i-eye"'), 'zakladny stav je `eye` zo spritu')
  NxTest.assert(D27_MENU.include?("icon: 'eye-off'"), 'skryty stav je `eye-off` zo spritu')
  icons = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')
  NxTest.assert(icons.include?("'eye':") && icons.include?("'eye-off':"),
                'obe ikony uz v sprite su — davka ziadnu nepridava')
end

NxTest.test('D-27: okno zatvara klik mimo aj Escape (vzor rohoveho nastavenia ABS)') do
  NxTest.assert(D27_BOOT.include?('bindTagMenu()'), 'zatvaranie sa naozaj pripaja pri starte')
  NxTest.assert(D27_BOOT =~ /function bindTagMenu\(\).*?Escape/m, 'Escape zatvara okno')
  NxTest.assert(D27_BOOT =~ /function bindTagMenu\(\).*?nxCloseTagMenu/m, 'klik mimo zatvara okno')
  NxTest.assert(D27_BOOT =~ /function bindTagMenu\(\).*?stopPropagation/m,
                'klik VNUTRI okna sa k documentu dostat nesmie (prepnutie by nedoletelo)')
end

NxTest.test('D-27: panel si ZIADNY vlastny stav tagov nedrzi (server je autorita)') do
  code = D27_SHELL.gsub(%r{/\*.*?\*/}m, ' ').lines.map { |l| l.sub(%r{//.*$}, '') }.join
  NxTest.assert(code.include?('nxTagState = st'), 'drzi sa LEN posledny stav zo servera')
  fn = code[/function nxApplyTags\(st\)\{?.*?\n  \}/m].to_s
  NxTest.refute(fn.include?('localStorage'), 'viditelnost tagu patri modelu, nie prehliadacu')
  NxTest.assert(fn.include?("el('zonesChk')"),
                'ten isty stav nasadzuje aj checkbox ghost zon (jeden zdroj, dva ovladace)')
end

# --- 8) overlay nekresli nad skrytym tagom -----------------------------------

NxTest.test('D-27: kontrola hran a kresby preskoci SKRYTE dielce') do
  d = D27_EDGE[/def drawable\?\(ent\).*?\n      end\n/m].to_s
  NxTest.refute(d.empty?, 'branka viditelnosti sa nenasla')
  NxTest.assert(d.include?('ent.hidden?'), 'vlastne skrytie entity')
  NxTest.assert(d.include?('lay.visible?'), 'skryty tag')
  NxTest.assert(d.include?('Tags.folder_hidden?(lay)'), 'aj skryty PRIECINOK tagov')
  each = D27_EDGE[/def each_part\(model\).*?\n      end\n/m].to_s
  NxTest.assert(each.include?('next unless drawable?(inst)'), 'skryta skrinka/doska sa preskoci')
  NxTest.assert(each.include?('drawable?(pi)'), 'skryty dielec v skrinke sa preskoci')
end
