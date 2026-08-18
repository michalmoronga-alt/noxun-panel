# frozen_string_literal: true
# Testy UI-03 / D-85: zdielany combobox materialov a ABS — SERVEROVA cast.
#
# Spravanie komponentu testuje JS sada (tests/js/test_ui03_combobox.js). Tu sa
# strazia invarianty, ktore ziju v Ruby a v HTML/CSS zdrojoch:
#   1) materials_payload nesie odvodeny zoznam „Použité v projekte" (used_ids) —
#      bez neho by prva sekcia comboboxu ostala prazdna,
#   2) filter „nie zo sablon" je NAVIAZANY na text, ktory sklada core
#      (collect_template_usage) — ked sa jedna strana zmeni, test to povie,
#   3) komponent nemieša farby natvrdo (paleta ide vyhradne cez tokeny/resolver),
#   4) panel komponent naozaj nacitava.
#
# POZN. k forme: `ui/panel/payloads.rb` sa headless nacitat NEDA (SketchUp API),
# preto sa kontrakt overuje nad ZDROJOM — rovnaky vzor ako test_guards.rb
# a test_ui02_toolbar.rb.
require_relative '../helper' unless defined?(NxTest)

UI03_UI_DIR      = File.join(NxTest::ROOT, 'noxun_engine', 'ui')
UI03_PAYLOADS    = File.read(File.join(UI03_UI_DIR, 'panel', 'payloads.rb'), encoding: 'UTF-8')
UI03_CATALOG     = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'materials_catalog.rb'), encoding: 'UTF-8')
UI03_COMBO_JS    = File.read(File.join(UI03_UI_DIR, 'js', 'nx_combo.js'), encoding: 'UTF-8')
UI03_PANEL_HTML  = File.read(File.join(UI03_UI_DIR, 'panel.html'), encoding: 'UTF-8')
UI03_CSS         = File.read(File.join(UI03_UI_DIR, 'css', 'panel.css'), encoding: 'UTF-8')

# --- 1) payload nesie „Použité v projekte" ------------------------------------

NxTest.test('UI-03: materials_payload nesie odvodene used_ids (sheets + edges)') do
  blok = UI03_PAYLOADS[/def materials_payload.+?\n        end/m].to_s
  NxTest.assert(blok.include?("'used_ids' => used_ids_payload"),
                'payload katalogu musi niest used_ids — inak je sekcia „Použité v projekte" vzdy prazdna')
  fn = UI03_PAYLOADS[/def used_ids_payload.+?\n        end/m].to_s
  NxTest.assert(fn.include?('Materials.used_material_ids'), 'dosky sa citaju existujucim read-only scanom')
  NxTest.assert(fn.include?('Materials.used_abs_ids'), 'ABS pasky sa citaju existujucim read-only scanom')
  NxTest.assert(fn.include?("'sheets' =>") && fn.include?("'edges' =>"),
                'payload ma obe vetvy (dekory aj pasky)')
end

NxTest.test('UI-03: cerstve used_ids sa PYTAJU pri otvoreni ponuky, netlacia sa') do
  # Codex #167 P2: zoznam sa meni pri kazdom zapise materialu (vratane Spat/Znova
  # a vkladania), ale CITA sa len pri otvoreni ponuky. Kanal je preto PULL —
  # `push_selected` (bezi pri kazdom kliku vo vybere) nesmie robit scan modelu.
  sync = File.read(File.join(UI03_UI_DIR, 'panel', 'sync.rb'), encoding: 'UTF-8')
  panel = File.read(File.join(UI03_UI_DIR, 'panel.rb'), encoding: 'UTF-8')
  NxTest.assert(sync.include?('def push_used_ids'), 'chyba tenky push samotneho zoznamu')
  NxTest.assert(sync[/def push_used_ids.+?\n        end/m].to_s.include?('NX.setUsedIds'),
                'push_used_ids posiela NX.setUsedIds (NIE cely katalog — formular sa nesmie resetovat)')
  NxTest.assert(panel.include?("cb(dlg, 'nx_used_ids')"), 'callback nx_used_ids nie je registrovany')
  # Poistka proti „opravam", ktore by scan modelu vratili do horucej cesty vyberu.
  NxTest.refute(sync[/def push_selected.+?\n        end/m].to_s.include?('used_ids'),
                'push_selected NESMIE pocitat used_ids — je to plny scan modelu pri kazdom kliku')
  combo = UI03_COMBO_JS
  NxTest.assert(combo.include?('usedRefresher'), 'komponent si vie vypytat cerstvy zoznam')
  NxTest.assert(combo.include?('function rerender'),
                'odpoved musi vediet prekreslit UZ OTVORENY zoznam (dobehne asynchronne)')
end

NxTest.test('UI-03: sync zvonka zavrie otvoreny popup') do
  # Codex #167 P2: popup drzi polozky z casu otvorenia. Ked medzitym pride
  # serverovy push (iny korpus / novy katalog), klik by potvrdil volbu STAREHO
  # kontextu do NOVEHO — preto sa zatvara (rovnako ako nativna rozbalovacka).
  scan = UI03_COMBO_JS[/function scan\(root\).+?\n    \}/m].to_s
  NxTest.assert(scan.include?('if (OPEN && OPEN.sel === sel) close();'),
                'scan musi zavriet popup selectu, ktory sa prave resyncoval')
  NxTest.assert(UI03_COMBO_JS.include?("global.addEventListener('blur'"),
                'odchod z okna popup tiez zatvara')
end

NxTest.test('UI-03: odvodenie used_ids je CISTE CITANIE (ziadny zapis do modelu)') do
  # D-103 lekcia: cesta, ktora sa spusta pri kazdom pushi katalogu, sa NESMIE
  # dotknut modelu (ziadna operacia, ziadny undo krok, ziadny dedup).
  fn = UI03_PAYLOADS[/def used_ids_payload.+?def used_model_ids/m].to_s
  %w[start_operation commit_operation request_dedup Store.set set_attribute].each do |zakazane|
    NxTest.refute(fn.include?(zakazane), "used_ids_payload nesmie obsahovat #{zakazane}")
  end
end

# --- 2) vazba na text zdroja zo sablon ----------------------------------------

NxTest.test('UI-03: filter sablon sedi s textom, ktory sklada core') do
  # „Použité v projekte" = tato ZAKAZKA. Globalna kniznica sablon do nej nepatri,
  # a rozlisit ju vieme len podla zdrojoveho textu z Materials.collect_template_usage.
  # Ked sa text zmeni, sablony by sa ticho zacali tvarit ako pouzitie v projekte.
  prefix = UI03_PAYLOADS[/TEMPLATE_SOURCE_PREFIX\s*=\s*'([^']+)'/, 1].to_s
  NxTest.refute(prefix.empty?, 'TEMPLATE_SOURCE_PREFIX sa v payloads.rb nenasla')
  NxTest.assert(UI03_CATALOG.include?(%(<< "#{prefix}\#{)),
                "core sklada zdroj sablony inak nez '#{prefix}' — filter used_ids by prestal fungovat")
  NxTest.assert(UI03_PAYLOADS.include?('start_with?(TEMPLATE_SOURCE_PREFIX)'),
                'filter sa musi opierat o konstantu, nie o dalsiu kopiu textu')
end

# --- 3) komponent nemieša farby natvrdo ---------------------------------------

NxTest.test('UI-03: nx_combo.js neobsahuje ziadny hex — farby dava panel') do
  # Komponent ZIADNY katalog ani paletu nepozna: stvorcek farbi resolver
  # (nxComboColorOf v core.js), zvysok CSS tokeny. Hex v komponente = uz zase
  # farba mimo systemu.
  offenders = []
  UI03_COMBO_JS.each_line.with_index do |line, i|
    code = line.sub(%r{//.*$}, '') # komentare von — „Codex #167" nie je farba
    offenders << "nx_combo.js:#{i + 1}" if code =~ /#[0-9a-fA-F]{3,8}\b/
  end
  NxTest.assert(offenders.empty?, "hex farba v komponente (patri do tokenu): #{offenders.join(', ')}")
end

NxTest.test('UI-03: zvyraznenie zhody ma vlastny token (--nx-mark-bg)') do
  NxTest.assert(UI03_CSS[/--nx-mark-bg\s*:\s*#fff3b0/],
                'token --nx-mark-bg musi byt v :root (vzor mockupu)')
  NxTest.assert(UI03_CSS.include?('.cbopt mark { background: var(--nx-mark-bg)'),
                'zvyraznenie berie farbu z tokenu, nie natvrdo')
end

# --- 4) komponent je v paneli a selecty su oznacene ----------------------------

NxTest.test('UI-03: panel nacitava nx_combo.js PRED kartami, ktore ho volaju') do
  i_combo = UI03_PANEL_HTML.index('js/nx_combo.js')
  NxTest.refute(i_combo.nil?, 'panel.html nenacitava js/nx_combo.js')
  %w[js/core.js js/part_card.js js/board_card.js js/boot.js].each do |src|
    i = UI03_PANEL_HTML.index(src)
    NxTest.refute(i.nil?, "panel.html nenacitava #{src}")
    NxTest.assert(i_combo < i, "nx_combo.js musi byt PRED #{src} (volaju NXCombo.scan)")
  end
end

NxTest.test('UI-03: kazdy materialovy/ABS select panela ma marker data-nx-combo') do
  # Inventura davky. Novy select bez markera by ostal starou rozbalovackou —
  # presne to, co D-85 rusi.
  %w[cab_body cab_front cab_back pcMaterial bc_material ib_material].each do |id|
    NxTest.assert(UI03_PANEL_HTML[/<select id="#{id}"[^>]*data-nx-combo="decor"/],
                  "select ##{id} nema data-nx-combo=\"decor\"")
  end
  # Dynamicke selecty hran (dielec + doska) dostavaju marker v JS.
  %w[part_card.js board_card.js].each do |f|
    src = File.read(File.join(UI03_UI_DIR, 'js', f), encoding: 'UTF-8')
    NxTest.assert(src.include?("setAttribute('data-nx-combo', 'abs')"),
                  "#{f}: hrany musia byt ABS combobox")
  end
  # Smer dekoru nie je material — combobox tam nepatri. (Select sablony zanikol
  # v UI-C1b: nahradili ho dlazdice, preto uz v zozname nie je.)
  %w[ib_grain bc_grain].each do |id|
    NxTest.refute(UI03_PANEL_HTML[/<select id="#{id}"[^>]*data-nx-combo/],
                  "select ##{id} nie je material/ABS — combobox sem nepatri")
  end
end
