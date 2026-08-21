# frozen_string_literal: true
# „ABS kontrola v raile: 3-stavove nastavenie" (v0.7.28) — guardy nad ZDROJOM.
#
# Kontrakt davky: rohovy trojuholnik pri ABS ikone otvara TO ISTE nastavenie,
# ktore ma okno Vyroba pod chevronom. Kontrolovane invarianty:
#   1) rail ma rohove tlacidlo s vlastnym aria-label a vlastnym klucom meraca
#      (D-25) z allowlistu usage.js; toggle sa NEMENI,
#   2) 3-stavove UI je JEDEN zdielany komponent (ui/js/edge_menu.js) — nacitava
#      ho panel aj okno Vyroba a jeho styly ziju v ZDIELANOM panel.css,
#   3) JEDEN zdroj stavu: obe okna zapisuju cez Engine.set_edge_check_option
#      (ktora broadcastuje), NIKDY priamo do EdgeCheck.set_option a nikdy do
#      vlastnej kopie stavu,
#   4) serverove guardy panela su rovnako prisne ako v okne Vyroba (whitelist
#      kluca + VYSLOVNY boolean + zhoda dokumentu),
#   5) nastavenie sa nedotyka modelu — ziadna operacia, ziadny krok Spat.
require_relative '../helper' unless defined?(NxTest)

A3S_HTML   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
A3S_PROD_H = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production.html'), encoding: 'UTF-8')
A3S_CSS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
A3S_PANEL  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
A3S_ACT    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_materials.rb'), encoding: 'UTF-8')
A3S_PROD   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'), encoding: 'UTF-8')
A3S_MAIN   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
A3S_USAGE  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'usage.js'), encoding: 'UTF-8')
A3S_MENU   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'edge_menu.js'), encoding: 'UTF-8')
A3S_SHELL  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')
A3S_BOOT   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'boot.js'), encoding: 'UTF-8')

# Headless: ui/production_dialog.rb nie je v require zozname helpera (UI vrstva),
# ale nazvy stavov su jeho konstanta a rail ich pouziva — nacitava sa TU (vzor
# tests/pure/test_production_dialog_api.rb). V SketchUpe uz nacitany je.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog') if NxTest.headless?

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
  NxTest.assert(A3S_PROD_H.include?('js/edge_menu.js'), 'okno Vyroba nacitava TEN ISTY modul')
  NxTest.assert(A3S_MENU.include?('global.NXEdgeMenu = API'), 'modul sa vystavuje ako NXEdgeMenu')
  NxTest.assert(A3S_SHELL.include?('NXEdgeMenu.menuHtml'), 'rail kresli okno modulom')
end

NxTest.test('ABS rail: styly okna su v ZDIELANOM panel.css (nie dve kopie)') do
  NxTest.assert(A3S_CSS.include?('.ecmenu {') && A3S_CSS.include?('.ecsw-missing'),
                'zdielany komponent musi mat styly v panel.css')
  code = A3S_PROD_H.gsub(%r{/\*.*?\*/}m, ' ')
  NxTest.refute(code.include?('.ecmenu {'), 'okno Vyroba uz nesmie mat vlastnu kopiu stylov okna')
  NxTest.refute(code.include?('.ecsw-taped'), 'farebne stvorceky ziju na JEDNOM mieste')
  # Pravidla zdielaneho okna NESMU byt scopnute pod `.nx-inspector` — okno
  # Vyroba o raile nevie a nasadenu triedu nema.
  NxTest.refute(A3S_CSS =~ /\.nx-inspector \.ecmenu \{/, 'zdielane pravidla nesmu byt scopnute na Inspector')
end

# --- 3) JEDEN zdroj stavu ----------------------------------------------------

NxTest.test('ABS rail: obe okna zapisuju ZDIELANOU cestou Engine.set_edge_check_option') do
  NxTest.assert(A3S_MAIN.include?('def self.set_edge_check_option'), 'zdielana cesta musi existovat')
  NxTest.assert(A3S_MAIN =~ /def self\.set_edge_check_option.*?broadcast_edge_check/m,
                'zdielana cesta rozposiela novy stav OBOM oknam')
  NxTest.assert(A3S_ACT.include?('Engine.set_edge_check_option'), 'rail ide zdielanou cestou')
  NxTest.assert(A3S_PROD.include?('Engine.set_edge_check_option'), 'okno Vyroba ide tou istou cestou')
  # Priamy zapis mimo zdielanej cesty by rozdelil stav na dva.
  [A3S_ACT, A3S_PROD].each do |src|
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

NxTest.test('ABS rail: nikdy dve kopie okna naraz — otvorenie zavrie to druhe') do
  NxTest.assert(A3S_MAIN.include?('def self.close_edge_menu'), 'zdielana cesta zatvarania')
  NxTest.assert(A3S_PANEL.include?("cb(dlg, 'nx_edge_menu_open')"), 'panel hlasi otvorenie')
  NxTest.assert(A3S_PROD.include?("cb(dlg, 'edge_menu_open')"), 'okno Vyroba hlasi otvorenie')
  NxTest.assert(A3S_PROD.include?('def close_edge_menu'), 'okno Vyroba vie svoje okno zavriet')
end

NxTest.test('ABS rail: okno zatvara klik mimo aj Escape (vzor warnpanelu)') do
  NxTest.assert(A3S_BOOT.include?('bindEdgeMenu()'), 'zatvaranie sa naozaj pripaja pri starte')
  NxTest.assert(A3S_BOOT =~ /function bindEdgeMenu\(\).*?Escape/m, 'Escape zatvara okno')
  NxTest.assert(A3S_BOOT =~ /function bindEdgeMenu\(\).*?nxCloseEdgeMenu/m, 'klik mimo zatvara okno')
end

# --- 4) serverove guardy panela ----------------------------------------------

NxTest.test('ABS rail: panel prijima LEN whitelistovany kluc a VYSLOVNY boolean') do
  h = A3S_ACT[/def handle_edge_option.*?\n        end\n/m].to_s
  NxTest.refute(h.empty?, 'handler rohoveho nastavenia sa nenasiel')
  NxTest.assert(h.include?('EdgeCheck::OPTION_KEYS.include?(key)'), 'kluc musi prejst whitelistom servera')
  NxTest.assert(h.include?('(value == true || value == false)'),
                'hodnota musi byt VYSLOVNE boolean (retazec "false" je v Ruby pravdivy)')
  NxTest.assert(h.include?("data['model_guid'].to_s == model_guid(model)"),
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
  pd = Noxun::Engine::ProductionDialog
  NxTest.assert(A3S_ACT.include?('ProductionDialog.edge_check_option_status'),
                'status panela sklada TA ISTA metoda ako v okne Vyroba')
  NxTest.assert(pd.respond_to?(:edge_check_option_status),
                'skladanie statusu musi byt PUBLIC — rail ju vola zvonku')
  Noxun::Engine::EdgeCheck::OPTION_KEYS.each do |key|
    text = pd.edge_check_option_status(key, true)
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
