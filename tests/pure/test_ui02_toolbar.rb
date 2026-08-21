# frozen_string_literal: true
# Testy UI-02: ikony znacky + SketchUp toolbar (logo · Studio · ABS · Vlozit).
#
# Kontrolovane invarianty:
#   1) styri ikony toolbaru existuju, su validne XML, bez BOM a s PEVNOU farbou
#      (`currentColor` v samostatnom SVG zdedi cierna — toolbar nie je HTML),
#   2) main.rb registruje toolbar so styrmi tlacidlami a GUARDOM proti dvojitej
#      registracii (reload pluginu by inak pridal dalsi rad tlacidiel),
#   3) prepinace (Inspector, ABS) maju validation proc — zapnuty stav musi byt
#      na tlacidle vidno,
#   4) ABS tlacidlo LEN prepina existujuce EdgeCheck API (D-104/D-105) — ziadna
#      nova logika zvyraznenia,
#   5) z toolbaru sa NEZAPISUJE do modelu (lekcia D-103/D-105: ziadny
#      start_operation, ziadny dedup) a `Panel.show_insert` cisti vyber pod
#      suspend guardom.
#
# POZN. k forme: `noxun_engine/main.rb` sa headless nacitat NEDA (`require
# 'sketchup.rb'` + registracia menu/toolbaru pri nacitani), preto sa kontrakt
# overuje nad ZDROJOM — rovnaky vzor ako test_guards.rb a test_ui01_paleta.rb.
require_relative '../helper' unless defined?(NxTest)
require 'rexml/document'

UI02_MAIN = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
UI02_PANEL = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
UI02_ICON_DIR = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'icons')
UI02_ICONS = %w[noxun_logo.svg noxun_studio.svg noxun_abs.svg noxun_insert.svg].freeze
UI02_INK = '#37474f' # tlmena firemna ciernomodra (token --nx-ink-strong)

# Telo metody `install_toolbar` — vsetky kontroly toolbaru sa tykaju JEJ,
# nie celeho suboru (inak by test presiel na nahodnom vyskyte inde).
def ui02_install_toolbar
  UI02_MAIN[/def self\.install_toolbar.*?\n    end\n/m].to_s
end

# --- 1) ikony -----------------------------------------------------------------

NxTest.test('UI-02: styri ikony toolbaru existuju a su validne SVG') do
  UI02_ICONS.each do |name|
    path = File.join(UI02_ICON_DIR, name)
    NxTest.assert(File.exist?(path), "chyba ikona toolbaru #{name}")

    raw = File.binread(path)
    NxTest.refute(raw[0, 3] == "\xEF\xBB\xBF".b, "#{name}: BOM (SketchUp cita subor priamo)")

    doc = nil
    begin
      doc = REXML::Document.new(File.read(path, encoding: 'UTF-8'))
    rescue StandardError => e
      NxTest.assert(false, "#{name}: nie je validne XML (#{e.class})")
    end
    root = doc && doc.root
    NxTest.assert_equal('svg', root && root.name, "#{name}: korenom musi byt <svg>")
    NxTest.refute(root.attributes['viewBox'].to_s.empty?,
                  "#{name}: bez viewBox sa ikona v toolbari neskaluje")
  end
end

NxTest.test('UI-02: ikony toolbaru maju PEVNU farbu (ziadny currentColor)') do
  # Samostatne SVG nema od koho farbu zdedit — `currentColor` by sa vykreslil
  # cierny. Sprite v paneli (ui/js/icons.js) ostava currentColor, ten je v HTML.
  UI02_ICONS.each do |name|
    src = File.read(File.join(UI02_ICON_DIR, name), encoding: 'UTF-8')
    NxTest.refute(src.include?('currentColor'),
                  "#{name}: currentColor mimo HTML znamena ciernu ikonu")
    NxTest.assert(src.downcase.include?(UI02_INK),
                  "#{name}: ikona ma kreslit firemnou #{UI02_INK}")
  end
end

# --- 1b) logo: sprite panela a ikona toolbaru kreslia TU ISTU znacku ----------

# Zrolovana znacka z originalnych kriviek webu ma DVE podoby: samostatny SVG
# subor pre SketchUp toolbar a symbol #i-logo v HTML sprite (hlavicka panela +
# koliesko „O plugine"). Krivky musia byt zhodne — inak by plugin nosil dve
# rozne znacky. Lisit sa smie LEN viewBox (toolbar ma ~12 % vnutorny okraj).
UI02_SPRITE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')
UI02_PANEL_CSS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')

# Kresba = vsetky `d="…"` a `points="…"` v poradi, v akom su v zdroji.
def ui02_curves(src)
  src.scan(/(?:\bd|\bpoints)="([^"]+)"/).flatten.map { |s| s.gsub(/\s+/, ' ').strip }
end

def ui02_logo_symbol
  UI02_SPRITE[/var LOGO = (.*?);\n/m].to_s
end

NxTest.test('UI-02: logo v sprite kresli TIE ISTE krivky ako ikona toolbaru') do
  symbol = ui02_logo_symbol
  NxTest.refute(symbol.empty?, 'icons.js musi mat symbol #i-logo (LOGO)')
  file = File.read(File.join(UI02_ICON_DIR, 'noxun_logo.svg'), encoding: 'UTF-8')
  NxTest.assert_equal(ui02_curves(file), ui02_curves(symbol),
                      'sprite a toolbar musia kreslit rovnaku zrolovanu znacku')
  NxTest.assert(symbol.include?('fill="currentColor"'),
                'logo je FILL vynimka — bez currentColor by v paneli ostalo cierne')
  vb = symbol[/viewBox="([^"]+)"/, 1].to_s
  NxTest.refute(vb.empty?, 'symbol #i-logo musi mat vlastny viewBox')
  NxTest.refute(vb == '0 0 100 100',
                'viewBox 0 0 100 100 = stary zjednoduseny prstenec, nie originalne krivky')
end

NxTest.test('UI-02: logo v hlavicke panela ma 24 px (kontrakt UI 2.0)') do
  rule = UI02_PANEL_CSS[/\.nxhdr \.nx-logo \{([^}]*)\}/, 1].to_s
  NxTest.refute(rule.empty?, 'panel.css musi urcovat velkost loga v hlavicke')
  NxTest.assert(rule.include?('width: 24px') && rule.include?('height: 24px'),
                "hlavicka nesie znacku 24 px (kontrakt UI 2.0), je: #{rule.strip}")
end

# --- 2) registracia toolbaru --------------------------------------------------

NxTest.test('UI-02: toolbar sa registruje s guardom proti dvojitej registracii') do
  body = ui02_install_toolbar
  NxTest.refute(body.empty?, 'main.rb musi mat metodu install_toolbar')
  NxTest.assert(body.include?('return @toolbar if @toolbar'),
                'bez guardu by reload pluginu pridal dalsi rad tlacidiel')
  NxTest.assert(body.include?("UI::Toolbar.new(TOOLBAR_NAME)"), 'toolbar sa tvori z TOOLBAR_NAME')
  NxTest.assert(body.include?('tb.restore'), 'po zlozeni toolbaru je povinny restore')
  NxTest.assert(UI02_MAIN.include?('install_toolbar #'),
                'toolbar sa musi pri load-e naozaj nainstalovat')
end

NxTest.test('UI-02: toolbar ma presne styri tlacidla so svojimi ikonami') do
  body = ui02_install_toolbar
  NxTest.assert_equal(4, body.scan(/tb\.add_item\(/).length, 'toolbar N4 ma styri tlacidla')
  NxTest.assert_equal(4, body.scan(/UI::Command\.new\(/).length, 'kazde tlacidlo ma vlastny prikaz')
  UI02_ICONS.each do |name|
    NxTest.assert(body.include?("'#{name}'"), "tlacidlo s ikonou #{name} chyba v toolbari")
  end
end

NxTest.test('UI-02 + ST-1a: kazde tlacidlo ma slovensky tooltip a Studio priznava, co v nom EST nie je') do
  body = ui02_install_toolbar
  NxTest.assert_equal(4, body.scan(/\.tooltip =/).length, 'tooltip patri ku kazdemu tlacidlu')
  # ST-1a: tlacidlo uz otvara SKUTOCNE Studio (nie okno Vyroba). Tooltip preto
  # nesmie hovorit „zatiaľ otvára okno Výroba" — musi ale poctivo povedat, ze
  # kontrola a rozpocet su este v inom okne (premostenie v navigacii Studia).
  NxTest.assert(body.include?('cmd_studio = UI::Command.new(\'Štúdio\') { StudioDialog.show }'),
                'tlacidlo Štúdio otvara StudioDialog, nie ProductionDialog')
  studio = body[/cmd_studio\.tooltip = '([^']+)'/, 1].to_s
  NxTest.assert(studio.include?('Výroba'),
                'tooltip musi povedat, co v Studiu este nie je (poctivy nazov cieloveho okna)')
  NxTest.assert(studio.include?('Kusovník') || studio.include?('kusovník'),
                'a zaroven co v nom UZ je')
end

# --- 3) prepinace: zapnuty stav je vidno --------------------------------------

NxTest.test('UI-02: Inspector aj ABS su PREPINACE s validation procom') do
  body = ui02_install_toolbar
  NxTest.assert_equal(2, body.scan(/set_validation_proc/).length,
                      'validation proc maju presne dva prepinace (Inspector, ABS)')
  NxTest.assert(body.include?('Panel.dialog_alive? ? Panel.hide : Panel.show'),
                'logo je prepinac panela — druhy klik zavrie')
  NxTest.assert(UI02_MAIN.include?('MF_CHECKED') && UI02_MAIN.include?('MF_GRAYED'),
                'zapnuty stav = MF_CHECKED, nedostupna kontrola hran = MF_GRAYED')
  proc_src = UI02_MAIN[/def self\.toolbar_state.*?\n    end\n/m].to_s
  NxTest.assert(proc_src.include?('rescue StandardError'),
                'validation proc bezi pri kazdom prekresleni — vynimka sa nesmie dostat von')
end

# --- 4) ABS: len prepnutie existujucej kontroly hran ---------------------------

# Telo ZDIELANEHO prepnutia (UI-B1) — toolbar, rail Inspectora aj okno Vyroba
# musia ist tou istou cestou, inak sa ich spravanie casom rozide.
def ui02_toggle_shared
  UI02_MAIN[/def self\.toggle_edge_check.*?\n    end\n/m].to_s
end

NxTest.test('UI-02: ABS tlacidlo len prepina existujuce EdgeCheck API (D-104/D-105)') do
  body = ui02_install_toolbar
  shared = ui02_toggle_shared
  NxTest.refute(shared.empty?, 'Engine.toggle_edge_check je zdielany vstupny bod prepnutia')
  NxTest.assert(shared.include?('EdgeCheck.toggle('),
                'zapnutie/vypnutie robi EdgeCheck.toggle — ziadna nova logika')
  NxTest.assert(body.include?('toggle_edge_check'),
                'toolbar musi volat ZDIELANU metodu, nie vlastnu kopiu prepnutia')
  NxTest.refute(body.include?('EdgeCheck.toggle('),
                'duplikat prepnutia v toolbari — logika patri do Engine.toggle_edge_check')
  NxTest.assert(body.include?('EdgeCheck.available?') && body.include?('EdgeCheck.active?'),
                'stav tlacidla cita EdgeCheck (available? / active?)')
  NxTest.assert(body.include?('defined?(EdgeCheck)') && shared.include?('defined?(EdgeCheck)'),
                'EdgeCheck sa pouziva len ked je nacitany (starsi SketchUp nema Overlay)')
end

NxTest.test('UI-02/UI-B1: prepnutie ABS obnovi ovladanie vo VSETKYCH oknach') do
  # Okno Vyroba ma vlastne split tlacidlo hran so stavmi a poctami, Inspector ma
  # ikonu v raile. Bez pushu noveho stavu by po prepnuti inde ukazovali stary.
  cast = UI02_MAIN[/def self\.broadcast_edge_check.*?\n    end\n/m].to_s
  NxTest.refute(cast.empty?, 'Engine.broadcast_edge_check rozposiela novy stav')
  NxTest.assert(ui02_toggle_shared.include?('broadcast_edge_check(state)'),
                'po prepnuti sa stav VZDY rozposle (inak okna ostanu na starom)')
  NxTest.assert(cast.include?('ProductionDialog.push_edge_check(state)'),
                'okno Vyroba musi dostat novy stav (split tlacidlo D-105)')
  NxTest.assert(cast.include?('Panel.push_edge_check(state)'),
                'rail Inspectora musi dostat novy stav (UI-B1)')
  NxTest.assert(cast.include?('defined?(ProductionDialog)') && cast.include?('defined?(Panel)'),
                'push je defenzivny — pri zavretom/nenacitanom okne sa ticho zahodi')
  prod = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'), encoding: 'UTF-8')
  verejne = prod[/\A.*?\n\s*private\b/m].to_s # cast triedy PRED `private` (lekcia A-05)
  NxTest.assert(verejne.include?('def push_edge_check'),
                'push_edge_check musi ostat verejne — vola ho aj EdgeCheck a toolbar')
  panel_sync = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'), encoding: 'UTF-8')
  NxTest.assert(panel_sync.include?('def push_edge_check'),
                'Panel.push_edge_check je protajsok v paneli (rail)')
end

# --- 5) ziadny zapis do modelu z toolbaru -------------------------------------

NxTest.test('UI-02: z toolbaru sa do modelu NEZAPISUJE (lekcia D-103/D-105)') do
  body = ui02_install_toolbar
  NxTest.refute(body.include?('start_operation'), 'toolbar prikaz nesmie otvorit operaciu')
  NxTest.refute(body.match?(/Store\.(set|write|config=)/), 'toolbar prikaz nesmie zapisat do NOXUN dict')
  NxTest.refute(body.include?('request_dedup'), 'dedup MENI model — z toolbaru nikdy')
end

NxTest.test('UI-02: vkladaci rezim cisti vyber pod suspend guardom a bez dedupu') do
  src = UI02_PANEL[/def show_insert.*?\n        end\n/m].to_s
  NxTest.refute(src.empty?, 'Panel.show_insert je vstupny bod tlacidla Vlozit')
  NxTest.assert(src.include?('suspend_selection_sync { model.selection.clear }'),
                'vycistenie vyberu musi bezat pod suspend guardom (inak observer dvojity refresh)')
  NxTest.assert(src.include?('dedup: false'),
                'refresh panela z toolbaru NESMIE dedupovat — dedup stavia a meni ID')
  NxTest.refute(src.include?('start_operation'), 'vkladaci rezim je len zobrazenie, nie operacia')
  NxTest.assert(UI02_PANEL.include?('def hide'), 'Panel.hide zatvara panel pre prepinac loga')
end
