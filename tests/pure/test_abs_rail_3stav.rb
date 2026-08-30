# frozen_string_literal: true
# „ABS kontrola v raile: 3-stavove nastavenie" (v0.7.28) — guardy nad ZDROJOM.
#
# Kontrakt davky: rohovy trojuholnik pri ABS ikone otvara TO ISTE nastavenie,
# ktore ma lista sekcie Kontrola v okne Studio (ŠT-1c PR B3: okno Vyroba
# zaniklo — druhym vstupnym bodom je Studio). Kontrolovane invarianty:
#   1) rail ma rohove tlacidlo s vlastnym aria-label a vlastnym klucom meraca
#      (D-25) z allowlistu usage.js; toggle sa NEMENI,
#   2) 3-stavove UI je JEDEN zdielany komponent (ui/js/edge_menu.js) — nacitava
#      ho panel aj okno Studio a jeho styly ziju v ZDIELANOM panel.css,
#   3) JEDEN zdroj stavu: obe okna zapisuju cez Engine.set_edge_check_option
#      (ktora broadcastuje), NIKDY priamo do EdgeCheck.set_option a nikdy do
#      vlastnej kopie stavu,
#   4) serverove guardy panela su rovnako prisne ako v zdielanom jadre
#      (whitelist kluca + VYSLOVNY boolean + zhoda dokumentu),
#   5) nastavenie sa nedotyka modelu — ziadna operacia, ziadny krok Spat.
require_relative '../helper' unless defined?(NxTest)

A3S_HTML   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
# ŠT-1b: druhym vstupnym bodom uz nie je okno Vyroba, ale sekcia KONTROLA
# v okne Studio — tvrdenia o nacitani zdielaneho modulu a o stavoch sa presunuli
# na studio.html / studio_dialog.rb / production_core.rb.
# ŠT-1c PR B3: `production.html` uz NEEXISTUJE — okno Vyroba zaniklo.
A3S_STUDIO_H = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'), encoding: 'UTF-8')
A3S_STUDIO = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'), encoding: 'UTF-8')
A3S_PCORE  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'), encoding: 'UTF-8')
A3S_CSS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
A3S_PANEL  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
A3S_ACT    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_materials.rb'), encoding: 'UTF-8')
A3S_MAIN   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
A3S_USAGE  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'usage.js'), encoding: 'UTF-8')
A3S_MENU   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'edge_menu.js'), encoding: 'UTF-8')
A3S_SHELL  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')
A3S_BOOT   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'boot.js'), encoding: 'UTF-8')

# Headless: ui/production_core.rb nie je v require zozname helpera (UI vrstva),
# ale nazvy stavov su jeho konstanta a rail ich pouziva — nacitava sa TU.
# V SketchUpe uz nacitany je.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

# --- 1) rohova zona v raile ---------------------------------------------------

NxTest.test('ABS rail: rohove tlacidlo existuje a je SAMOSTATNE (nie vnorene v prepinaci)') do
  NxTest.assert(A3S_HTML.include?('id="railAbsMore"'), 'rail musi mat rohove tlacidlo')
  NxTest.assert(A3S_HTML.include?('id="railAbsBox"'), 'obal drzi vzajomnu poziciu prepinaca a rohu')
  # Vnorene <button> je neplatne HTML (lekcia krizika docasnej polozky):
  # medzi otvaracim tagom prepinaca a jeho </button> nesmie byt dalsi <button>.
  toggle = A3S_HTML[/<button[^>]*id="railAbs"[^>]*>.*?<\/button>/m].to_s
  NxTest.refute(toggle.empty?, 'prepinac ABS kontroly sa nenasiel')
  NxTest.refute(toggle.include?('railAbsMore'), 'rohove tlacidlo NESMIE byt vnorene v prepinaci')
end

NxTest.test('ABS rail: toggle sa nemeni — roh ma VLASTNY handler a VLASTNY popis') do
  NxTest.assert(A3S_HTML.include?('onclick="onEdgeCheckToggle()"'), 'klik na ikonu ostava toggle')
  NxTest.assert(A3S_HTML.include?('onclick="onEdgeMenuToggle(event)"'), 'roh otvara nastavenie')
  NxTest.assert(A3S_HTML.include?('aria-label="ABS kontrola hrán"'), 'prepinac ma svoj aria-label')
  NxTest.assert(A3S_HTML.include?('aria-label="Nastavenie ABS kontroly"'),
                'roh ma ODLISNY aria-label (citacka musi vediet, ze su to dve akcie)')
  NxTest.assert(A3S_HTML.include?('aria-expanded="false"') && A3S_HTML.include?('aria-haspopup="true"'),
                'roh hlasi rozbalenie aj citacke')
end

NxTest.test('ABS rail: rohovy klik ma VLASTNY kluc meraca (D-25) z allowlistu') do
  allow = A3S_USAGE[/var USAGE_KEYS = \[(.*?)\];/m].to_s.scan(/'([^']+)'/).flatten
  NxTest.assert(allow.include?('rail:abs-nastavenie'), 'kluc rohoveho kliku musi byt v allowliste')
  NxTest.assert(allow.include?('rail:abs'), 'kluc prepinaca ostava')
  NxTest.assert(A3S_HTML.include?('data-nx-usage="rail:abs-nastavenie"'), 'roh kluc naozaj vyhlasuje')
  NxTest.assert(allow.count('rail:abs-nastavenie') == 1, 'kluc smie byt v allowliste raz')
end

NxTest.test('ABS rail: trojuholnik je ZNAMIENKO, klikacia zona je cely pravy dolny kvadrant') do
  css = A3S_CSS.gsub(%r{/\*.*?\*/}m, ' ')
  NxTest.assert(css.include?('.railfly .railbtn::after'), 'trojuholnik kresli pseudo-prvok prepinaca')
  NxTest.assert(css =~ /\.railfly \.railbtn::after[^}]*border-bottom:\s*6px solid/,
                'trojuholnik je maly PLNY (6 px CSS trojuholnik)')
  NxTest.assert(css =~ /\.railcorner\s*\{[^}]*width:\s*17px[^}]*height:\s*16px/,
                'klikacia zona je kvadrant tlacidla (17 x 16 px), nie 6 px trojuholnika')
  NxTest.assert(css =~ /\.railcorner\s*\{[^}]*z-index:\s*2/,
                'roh lezi NAD prepinacom — klik nan sa k toggle nedostane')
  NxTest.assert(css.include?('.ecmenu-rail'), 'okno s nastavenim ma polohu PRI RAILE')
  NxTest.assert(css =~ /\.ecmenu-rail\s*\{[^}]*left:\s*40px/,
                'okno stoji vedla ikony (nie v strede obrazovky)')
end

# --- 2) JEDNO nastavenie: zdielany komponent ---------------------------------

NxTest.test('ABS rail: 3-stavove UI je JEDEN zdielany modul (nacitany v OBOCH oknach)') do
  NxTest.assert(A3S_HTML.include?('js/edge_menu.js'), 'panel nacitava zdielany modul')
  NxTest.assert(A3S_STUDIO_H.include?('js/edge_menu.js'),
                'okno Studio (sekcia Kontrola) nacitava TEN ISTY modul')
  # ŠT-1c PR B3: okno Vyroba zaniklo — ostali PRESNE dva vstupne body.
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production.html')),
                'okno Vyroba zaniklo — jeho HTML uz v repe nie je')
  NxTest.assert(A3S_MENU.include?('global.NXEdgeMenu = API'), 'modul sa vystavuje ako NXEdgeMenu')
  NxTest.assert(A3S_SHELL.include?('NXEdgeMenu.menuHtml'), 'rail kresli okno modulom')
end

NxTest.test('ABS rail: styly okna su v ZDIELANOM panel.css (nie dve kopie)') do
  NxTest.assert(A3S_CSS.include?('.ecmenu {') && A3S_CSS.include?('.ecsw-missing'),
                'zdielany komponent musi mat styly v panel.css')
  # ŠT-1b: aj SPUSTACE (.ecbtn/.gcbtn) a rohova zona ziju v zdielanom
  # panel.css — studio.html ich kopiu mat NESMIE.
  NxTest.assert(A3S_CSS.include?('.ecbtn, .gcbtn {') && A3S_CSS.include?('.cornerzone {'),
                'spustace prepinacov maju styly v panel.css')
  [['studio.html', A3S_STUDIO_H]].each do |(name, html)|
    code = html.gsub(%r{/\*.*?\*/}m, ' ')
    NxTest.refute(code.include?('.ecmenu {'), "#{name} nesmie mat vlastnu kopiu stylov okna")
    NxTest.refute(code.include?('.ecsw-taped'), "#{name}: farebne stvorceky ziju na JEDNOM mieste")
    NxTest.refute(code.include?('.ecbtn'), "#{name}: spustac ma styl v zdielanom panel.css")
  end
  # Pravidla zdielaneho okna NESMU byt scopnute pod `.nx-inspector` — satelitne
  # okna o raile nevedia a nasadenu triedu nemaju.
  NxTest.refute(A3S_CSS =~ /\.nx-inspector \.ecmenu \{/, 'zdielane pravidla nesmu byt scopnute na Inspector')
  NxTest.refute(A3S_CSS =~ /\.nx-inspector \.ecbtn/, 'ani spustac')
end

# --- 3) JEDEN zdroj stavu ----------------------------------------------------

NxTest.test('ABS rail: obe okna zapisuju ZDIELANOU cestou Engine.set_edge_check_option') do
  NxTest.assert(A3S_MAIN.include?('def self.set_edge_check_option'), 'zdielana cesta musi existovat')
  NxTest.assert(A3S_MAIN =~ /def self\.set_edge_check_option.*?broadcast_edge_check/m,
                'zdielana cesta rozposiela novy stav OBOM oknam')
  NxTest.assert(A3S_ACT.include?('Engine.set_edge_check_option'), 'rail ide zdielanou cestou')
  # ŠT-1b: telo je v ProductionCore a obe okna su len tenke obaly — trojica
  # vstupnych bodov tak nemoze mat tri rozne cesty.
  NxTest.assert(A3S_PCORE.include?('Engine.set_edge_check_option'),
                'zdielane jadro ide tou istou cestou')
  NxTest.assert(A3S_STUDIO.include?('ProductionCore.do_edge_check_option'),
                'sekcia Kontrola v Studiu vola zdielane jadro')
  # Priamy zapis mimo zdielanej cesty by rozdelil stav na dva.
  [A3S_ACT, A3S_STUDIO].each do |src|
    NxTest.refute(src.gsub(/#.*$/, '').include?('EdgeCheck.set_option'),
                  'okna nesmu volat EdgeCheck.set_option priamo — obislo by to broadcast')
  end
end

NxTest.test('ABS rail: rail si nedrzi vlastny stav prepinacov (server je autorita)') do
  code = A3S_SHELL.gsub(%r{/\*.*?\*/}m, ' ').lines.map { |l| l.sub(%r{//.*$}, '') }.join
  NxTest.refute(code.include?('localStorage'), 'nastavenie nesmie zit v prehliadaci — patri do %APPDATA%')
  NxTest.refute(code.include?('show_missing'), 'rail nepozna kluce stavov — sklada ich zdielany modul')
  NxTest.assert(code.include?('nxEdgeState = st'), 'rail si drzi LEN posledny stav zo servera (zive pocty)')
end

NxTest.test('ABS rail: nikdy dve kopie okna naraz — otvorenie zavrie OSTATNE') do
  NxTest.assert(A3S_MAIN.include?('def self.close_edge_menu'), 'zdielana cesta zatvarania')
  cast = A3S_MAIN[/def self\.close_edge_menu.*?\n    end\n/m].to_s
  NxTest.assert(A3S_PANEL.include?("cb(dlg, 'nx_edge_menu_open')"), 'panel hlasi otvorenie')
  # ŠT-1b: DRUHA instancia — sekcia Kontrola v okne Studio. Bez vlastnej
  # vetvy v `close_edge_menu` by ostali na obrazovke dve kopie naraz.
  # (ŠT-1c PR B3: tretia instancia — okno Vyroba — zanikla s oknom.)
  NxTest.assert(A3S_STUDIO.include?("cb(dlg, 'edge_menu_open')"), 'Studio hlasi otvorenie')
  NxTest.assert(A3S_STUDIO.include?('Engine.close_edge_menu(:studio)'),
                'a hlasi ho pod VLASTNYM zdrojom (inak by zavrelo samo seba)')
  NxTest.assert(A3S_STUDIO.include?('def close_edge_menu'), 'Studio vie svoje okno zavriet')
  NxTest.assert(cast.include?('source != :studio') && cast.include?('StudioDialog.close_edge_menu'),
                'zdielana cesta pozna vetvu Studia')
  NxTest.assert(cast.include?('source != :panel'), 'a vetva panela ostava')
  NxTest.refute(cast.include?('ProductionDialog'),
                'vetva zaniknuteho okna Vyroba je PREC')
end

NxTest.test('ABS rail: okno zatvara klik mimo aj Escape (vzor warnpanelu)') do
  NxTest.assert(A3S_BOOT.include?('bindEdgeMenu()'), 'zatvaranie sa naozaj pripaja pri starte')
  NxTest.assert(A3S_BOOT =~ /function bindEdgeMenu\(\).*?Escape/m, 'Escape zatvara okno')
  NxTest.assert(A3S_BOOT =~ /function bindEdgeMenu\(\).*?nxCloseEdgeMenu/m, 'klik mimo zatvara okno')
  # ŠT-1b: to iste musi platit pre tretiu instanciu v Studiu.
  studio_js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                        encoding: 'UTF-8')
  NxTest.assert(studio_js.include?("!t.closest('.echk')"), 'klik mimo spustaca zatvara okno')
  # SMOKE 22.8.: Studio ma od tejto davky DVE rohove nastavenia (kontrola hran
  # + VEPO export), takze Escape vetva zacina JEDNOU brankou a az za nou riesi
  # jednotlive okna. Kontrola je preto na obe casti.
  NxTest.assert(studio_js.include?("if (ev.key !== 'Escape' || nxModalOpen()) return;"),
                'Escape vetva Studia zacina brankou (modal ma prednost)')
  NxTest.assert(studio_js =~ /if \(ev\.key !== 'Escape'.*?if \(ecMenuOpen\)\{\s*\n\s*edgeMenuClose\(\);/m,
                'Escape zatvara okno aj v Studiu')
end

# --- 4) serverove guardy panela ----------------------------------------------

NxTest.test('ABS rail: panel prijima LEN whitelistovany kluc a VYSLOVNY boolean') do
  h = A3S_ACT[/def handle_edge_option.*?\n        end\n/m].to_s
  NxTest.refute(h.empty?, 'handler rohoveho nastavenia sa nenasiel')
  NxTest.assert(h.include?('EdgeCheck::OPTION_KEYS.include?(key)'), 'kluc musi prejst whitelistom servera')
  NxTest.assert(h.include?('(value == true || value == false)'),
                'hodnota musi byt VYSLOVNE boolean (retazec "false" je v Ruby pravdivy)')
  NxTest.assert(h.include?(%q<DocKey.foreign?(data['model_guid'], model)>),
                'PRISNA zhoda dokumentu (callback HtmlDialogu je asynchronny)')
  NxTest.assert(h.include?('EdgeCheck.available?(model)'), 'bez Overlay API sa nic nenastavuje')
  NxTest.assert(h.include?('push_edge_check'), 'odmietnutie vrati okno na PRAVDIVY stav')
end

NxTest.test('ABS rail: nastavenie sa NEDOTYKA modelu (ziadna operacia, ziadny krok Spat)') do
  h = A3S_ACT[/def handle_edge_option.*?\n        end\n/m].to_s
  %w[start_operation commit_operation set_attribute rebuild].each do |forbidden|
    NxTest.refute(h.include?(forbidden), "rohove nastavenie nesmie volat #{forbidden}")
  end
  m = A3S_MAIN[/def self\.set_edge_check_option.*?\n    end\n/m].to_s
  %w[start_operation commit_operation].each do |forbidden|
    NxTest.refute(m.include?(forbidden), "zdielana cesta nesmie volat #{forbidden}")
  end
end

NxTest.test('ABS rail: nazvy stavov ma na starosti SERVER (rail si ich nevymysla)') do
  # ŠT-1c PR B3: text berie rail PRIAMO zo zdielaneho jadra — okno, cez ktore
  # sa doň predtym pytal (Vyroba), zaniklo.
  pc = Noxun::Engine::ProductionCore
  NxTest.assert(A3S_ACT.include?('ProductionCore.edge_check_option_status'),
                'status panela sklada TA ISTA metoda ako lista sekcie Kontrola')
  NxTest.refute(A3S_ACT.include?('ProductionDialog'),
                'rail sa uz nesmie pytat zaniknuteho okna Vyroba')
  NxTest.assert(pc.respond_to?(:edge_check_option_status),
                'skladanie statusu musi byt PUBLIC — rail ju vola zvonku')
  Noxun::Engine::EdgeCheck::OPTION_KEYS.each do |key|
    text = pc.edge_check_option_status(key, true)
    NxTest.assert(text.is_a?(String) && !text.start_with?(key) && text.end_with?('zapnuté.'),
                  "stav #{key} musi mat slovensky nazov (dostal: #{text})")
  end
end

# --- 5) callback je zaregistrovany -------------------------------------------

NxTest.test('ABS rail: callback nx_edge_option je zaregistrovany a mieri na handler') do
  NxTest.assert(A3S_PANEL.include?("cb(dlg, 'nx_edge_option')"), 'callback musi byt zaregistrovany')
  NxTest.assert(A3S_PANEL.include?('handle_edge_option(p)'), 'callback mieri na handler')
  NxTest.assert(A3S_ACT.include?('def handle_edge_option'), 'handler existuje v akciach panela')
  NxTest.assert(A3S_SHELL.include?('function onEdgeMenuOption'), 'klient ma protajsok handlera')
  # Callback musi ist cez `cb` wrapper (begin/rescue + slovensky status) — holy
  # add_action_callback by chybu pustil von.
  NxTest.refute(A3S_PANEL.include?("add_action_callback('nx_edge_option')"),
                'callback ide cez zdielany cb wrapper, nie priamo')
end
