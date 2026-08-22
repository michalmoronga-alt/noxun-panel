# frozen_string_literal: true
# ŠT-1c PR A — sekcia NÁKUP KOVANIA v okne ŠTÚDIO (Š7) + presun z okna Výroba.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. PRESUN, NIE KOPIA. Tab Kovanie okna Vyroba zanikol — jeho render, jeho
#      styly aj jeho payload polia ziju UZ LEN v Studiu. Kopia by sa casom
#      rozisla a dva nakupne zoznamy tej istej zakazky by dali dve objednavky.
#   2. OBOHATENIE `label`/`params_label` (audit #3) zije v ZDIELANOM jadre —
#      nie v okne. Klient nesmie mat vlastny preklad enumu ani vlastny format.
#   3. GEN GUARD na CSV kovania (audit #15, VEDOMA ZMENA): nakupny dokument
#      nesmie vzniknut z okna, ktoreho data uz neplatia. Ostatne tri exporty
#      guard maju odjakziva.
#   4. RELAY RETAZ Studia (audit #13): vlastny kanal `studioRelayHwCsv` ->
#      `studio_do_hw_csv` s FLUSH GUARDOM — cervene pole panela export zastavi
#      (inak by sa objednavalo kovanie pre stare rozmery).
#   5. FIX ZIVEJ CHYBY (audit #2): `EdgeCheck.notify_*` rozposiela stav
#      ZDIELANYM `Engine.broadcast_edge_check` — jeho povodny zoznam poznal len
#      Vyrobu a Inspector, takze lista sekcie Kontrola v Studiu drzala po
#      prepocte cache stare pocty.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog') if NxTest.headless?

S1C_CORE_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                          encoding: 'UTF-8')
S1C_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                          encoding: 'UTF-8')
S1C_PROD_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'),
                          encoding: 'UTF-8')
S1C_PANEL_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
S1C_EDGE_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'edge_check.rb'),
                          encoding: 'UTF-8')
S1C_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                          encoding: 'UTF-8')
S1C_PROD_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'production.js'),
                          encoding: 'UTF-8')
S1C_BRIDGE_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                          encoding: 'UTF-8')
S1C_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                            encoding: 'UTF-8')
S1C_PROD_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production.html'),
                          encoding: 'UTF-8')

# --- 1) sekcia `buy` je ZIVA a premostenie po nej nezostalo -------------------

NxTest.test('ŠT-1c: `buy` je SEKCIA Studia — a premostenie do okna Vyroba zaniklo') do
  st = Noxun::Engine::StudioDialog
  NxTest.assert(st::SECTIONS.include?('buy'), 'Ruby whitelist sekciu pozna')
  NxTest.refute(st::PRODUCTION_BRIDGES.key?('buy'), 'premostenie do tabu Kovanie zaniklo')
  NxTest.assert(st::BRIDGE_STATUS['buy'].to_s.empty?, 'a s nim aj jeho hlaska')
  # Navigacia okna: polozka `buy` uz NESMIE mat `bridge` (sipka + tooltip
  # „zatiaľ v okne Výroba") — inak by tvrdila, ze obsah je inde.
  nav = S1C_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  NxTest.assert(nav.include?("{ id: 'buy',    ic: 'cart',            t: 'Nákup kovania' }"),
                'polozka navigacie je ZIVA sekcia, nie premostenie')
  NxTest.assert(S1C_STUDIO_JS.include?('buy: { t: \'Nákup kovania\''),
                'sekcia ma vlastnu hlavicku a hint')
end

NxTest.test('ŠT-1c: okno Vyroba stratilo tab Kovanie CELY (JS aj HTML aj CSS)') do
  # PR B1 vzala oknu aj POSLEDNY tab (Rozpocet) — whitelist je uz prazdny.
  NxTest.assert_equal([], Noxun::Engine::ProductionDialog::TABS,
                      'whitelist tabov uz Kovanie (ani nic ine) nepozna')
  NxTest.refute(S1C_PROD_HTML.include?('id="pt_hardware"'), 'tlacidlo tabu zaniklo')
  NxTest.refute(S1C_PROD_HTML.include?('id="prodHint"'),
                'hint „klik na riadok kovania" zanikol s nim (patri sekcii)')
  %w[renderHardware hwCsvExport hwManualMark price].each do |fn|
    NxTest.refute(S1C_PROD_JS.include?("function #{fn}"), "mrtvy helper #{fn} sa mal odstranit")
    NxTest.assert(S1C_STUDIO_JS.include?("function #{fn}") || fn == 'renderHardware',
                  "#{fn} zije v Studiu")
  end
  NxTest.assert(S1C_STUDIO_JS.include?('function buySection'),
                'render sekcie je v studio.js (v okne Vyroba sa volal renderHardware)')
  NxTest.refute(S1C_PROD_JS.include?('tr.hwrow'), 'klik-select kovania odisiel s tabom')
  NxTest.assert(S1C_STUDIO_JS.include?("t.closest('tr.hwrow')"), 'a zije v Studiu')
end

NxTest.test('ŠT-1c: styly nakupneho zoznamu sa PRESUNULI (nie skopirovali)') do
  %w[.hwsec .hwbanner hwcat hwmiss hwsum].each do |sel|
    NxTest.assert(S1C_STUDIO_HTML.include?(sel), "#{sel} je v studio.html")
    NxTest.refute(S1C_PROD_HTML.include?("  #{sel} {") || S1C_PROD_HTML.include?("tr.#{sel} td"),
                  "#{sel} uz v production.html NIE JE (kopia by sa rozisla)")
  end
  # UI_DIZAJN: v Studiu ziadny natvrdo pisany hex — okno ma dve temy.
  block = S1C_STUDIO_HTML[/sekcia NÁKUP KOVANIA.*?súčtový riadok/m].to_s
  NxTest.refute(block.empty?, 'blok stylov sekcie sa nasiel')
  NxTest.refute(block.match?(/#[0-9a-fA-F]{3,6}\b/),
                'farby su VYHRADNE cez --nx-* tokeny (hex by v teme Lucia svietil)')
end

NxTest.test('ŠT-1c (review P3): sekcia Nakup nesľubuje klik tam, kde sa nic nedeje') do
  # `.bomtab tbody tr` ma kvoli Kusovniku ruku aj hover. V Nakupe reaguje LEN
  # riadok generiky — kategorie, sucet, polozky setov a jantarove riadky nie.
  # Tabulky sekcie preto nesu marker `.hwtab` a afordancia sa vracia adresne.
  NxTest.assert_equal(3, S1C_STUDIO_JS.scan(/class="bomtab hwtab"/).length,
                      'vsetky TRI tabulky sekcie nesu marker (sety · bez kodov · generika)')
  NxTest.assert(S1C_STUDIO_HTML.include?('.bomtab.hwtab tbody tr { cursor: default; }'),
                'riadok sekcie standardne NEMA ruku')
  NxTest.assert(S1C_STUDIO_HTML.include?('.bomtab.hwtab tbody tr.hwrow { cursor: pointer; }'),
                'ruku dostane VYHRADNE riadok, ktory naozaj reaguje')
  NxTest.assert(S1C_STUDIO_HTML.include?('.bomtab.hwtab tbody tr:hover { background: none; }'),
                'a rovnako sa vracia aj podsvietenie pri prejdeni mysou')
  # Kusovnik vedla NESMIE o afordanciu prist — marker je len na tabulkach Nakupu.
  NxTest.assert(S1C_STUDIO_HTML.include?('.bomtab tbody tr { cursor: pointer; }'),
                'povodne pravidlo Kusovnika ostava nedotknute')
end

NxTest.test('ŠT-1c (review P3): sekcia Nakup ma vlastnu cestu k cerstvym cislam') do
  tools = S1C_STUDIO_JS[/if \(studioSec === 'buy'\)\{.*?\n    \}/m].to_s
  NxTest.refute(tools.empty?, 'lista sekcie sa nasla')
  NxTest.assert(tools.include?('id="hwCsvBtn"'), 'export je v liste sekcie (kontrakt §3)')
  NxTest.assert(tools.include?('id="refreshBtn"'),
                'a je tam aj „Obnoviť" — prestavba skrinky sem sama nedorazi, ' \
                'takze bez neho by sa objednavalo zo starych poctov')
  NxTest.assert(S1C_STUDIO_JS.include?("t.closest('#refreshBtn')"),
                'tlacidlo ma handler (ten isty ako v Kusovniku)')
  NxTest.assert(S1C_STUDIO_JS.include?("buy: 'Prepočítavam nákupný zoznam…'"),
                'status hovori o TEJ sekcii, na ktoru sa pouzivatel pozera')
end

# --- 2) obohatenie generiky zije v ZDIELANOM jadre (audit #3) -----------------

NxTest.test('ŠT-1c: `label`/`params_label` sklada JADRO, nie okno (audit #3)') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert(core.respond_to?(:hardware_labeled), 'ProductionCore.hardware_labeled existuje')
  NxTest.assert(S1C_STUDIO_RB.include?('hardware: ProductionCore.hardware_labeled(bom)'),
                'payload Studia cita zdielane obohatenie')
  NxTest.assert(S1C_STUDIO_RB.include?('hardware_sets: hw_exp'),
                'a nesie aj nakupny zoznam zo setov')
  # Okno Vyroba stratilo OBE polia spolu s tabom — vlastne obohatenie by bolo
  # druha pravda o tom, ako sa polozka vola.
  NxTest.refute(S1C_PROD_RB.include?('hardware_sets: hw_exp'),
                'okno Vyroba nakupny zoznam uz nedostava')
  NxTest.refute(S1C_PROD_RB.include?('HardwareRules.label_for'),
                'ani vlastne obohatenie generiky')
end

NxTest.test('ŠT-1c: hardware_labeled dopĺňa OBA texty a cudzie polia nechá tak') do
  core = Noxun::Engine::ProductionCore
  bom = { hardware: [{ 'generic_type' => 'hinge', 'quantity' => 4, 'key' => 'H1',
                       'params' => {} },
                     'nezmysel'] }
  out = core.hardware_labeled(bom)
  NxTest.assert_equal(2, out.length, 'pocet poloziek sa nemeni')
  NxTest.assert_equal('nezmysel', out[1], 'nehashovy zaznam prejde nedotknuty (ziadny pad)')
  NxTest.assert(out[0].key?('label') && out[0].key?('params_label'),
                'hashova polozka dostane OBA serverove texty')
  NxTest.assert_equal('H1', out[0]['key'], 'a povodne polia ostavaju')
  NxTest.assert_equal(Noxun::Engine::HardwareRules.label_for('hinge'), out[0]['label'],
                      'label je z JEDINEJ autority (HardwareRules)')
  NxTest.assert_equal([], core.hardware_labeled(nil), 'chybajuci BOM = prazdny zoznam, nie vynimka')
end

# --- 3) CSV kovania: telo v jadre + GEN GUARD (audit #15) --------------------

NxTest.test('ŠT-1c: telo CSV kovania je v jadre a obe okna su len obaly') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert(core.respond_to?(:do_hw_csv), 'ProductionCore.do_hw_csv existuje')
  %i[do_export do_select do_hw_csv].each do |m|
    NxTest.assert(Noxun::Engine::StudioDialog.respond_to?(m),
                  "StudioDialog.#{m} je VEREJNY (vola ho relay z panela)")
    # DOCASNE — obal v okne Vyroba zanika v ŠT-1c PR B3 spolu s celym oknom
    # (review #4). Dovtedy ho vola relay `production_do_hw_csv` z panela.
    NxTest.assert(Noxun::Engine::ProductionDialog.respond_to?(m),
                  "ProductionDialog.#{m} ostava verejny (relay `production_do_hw_csv`)")
  end
  [['studio_dialog.rb', S1C_STUDIO_RB], ['production_dialog.rb', S1C_PROD_RB]].each do |(name, src)|
    NxTest.assert(src.include?('ProductionCore.do_hw_csv'), "#{name} vola zdielane telo")
    NxTest.refute(src.include?('HardwareSets.purchase_csv'),
                  "#{name} nesmie mat vlastny zapis CSV (dva exporty by sa rozisli)")
  end
end

NxTest.test('ŠT-1c (audit #15): CSV kovania dostal GENERACNY GUARD — vedoma zmena') do
  body = S1C_CORE_RB[/def do_hw_csv\(model, data.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'telo exportu sa nasiel')
  NxTest.assert(body.include?("data['gen'].to_i == generation.to_i"),
                'stare data okna export NEVYROBIA (nakupny dokument)')
  NxTest.assert(body.include?('repush.call'),
                'odmietnutie nie je tiche — okno sa obnovi')
  NxTest.assert(body.include?("data['flush_blocked']"),
                'a cervene pole panela export zastavi (flush guard ostal)')
  NxTest.assert(body.include?('project_name(model)'),
                'nazov projektu je SERVEROVA autorita (z DOM nechodi)')
  NxTest.assert(body.include?('fresh_collect(model)'),
                'zoznam sa pocita z CERSTVEHO modelu, nie z payloadu okna')
  # Review P3: komentar nesmie slubovat ochranu, ktoru guard nema — prestavba
  # skrinky z Inspectora generaciu NEZDVIHA (chyta ju az cerstvy zber nizsie).
  note = S1C_CORE_RB[/VEDOMA ZMENA \(audit #15\).*?def do_hw_csv/m].to_s
  NxTest.refute(note.empty?, 'komentar guardu sa nasiel')
  NxTest.refute(note.include?('prestavana skrinka'),
                'komentar netvrdi, ze guard chyta prestavbu skrinky (nechyta)')
  NxTest.assert(note.include?('PREPNUTY DOKUMENT'),
                'a pomenuje, co guard NAOZAJ chyta')
  NxTest.assert(note.include?('fresh_collect'),
                'aj to, co je poistkou proti zastaranym poctom (cerstvy zber)')
  # Klient posiela `gen` — bez neho by guard odmietol KAZDY export.
  NxTest.assert(S1C_STUDIO_JS.include?('sketchup.hw_csv_export(JSON.stringify({ gen: ST.gen }))'),
                'lista sekcie posiela generaciu okna')
end

# --- 4) relay retaz Studia (audit #13) ---------------------------------------

NxTest.test('ŠT-1c: CSV kovania ide VLASTNYM kanalom Studia s flush guardom') do
  NxTest.assert(S1C_STUDIO_RB.include?("cb(dlg, 'hw_csv_export') { |p| handle_hw_csv(p) }"),
                'okno ma vlastny callback')
  NxTest.assert(S1C_STUDIO_RB.include?('NX.studioRelayHwCsv('),
                'relay ide cez panel (flush rozpisanych editov PRED zberom)')
  NxTest.assert(S1C_PANEL_RB.include?("cb(dlg, 'studio_do_hw_csv')"),
                'panel ma vlastny vstupny bod pre Studio')
  relay = S1C_BRIDGE_JS[/studioRelayHwCsv: function\(p\)\{.*?\n    \},/m].to_s
  NxTest.refute(relay.empty?, 'relay sa nasiel v bridge.js')
  NxTest.assert(relay.include?('validateFields()'), 'neplatne pole panela sa deteguje')
  NxTest.assert(relay.include?('p.flush_blocked = blocked'),
                'a export sa NEPOSLE ako platny (server ho odmietne s hlaskou)')
  NxTest.assert(relay.include?('sketchup.studio_do_hw_csv'),
                'odpoved chodi do TOHO okna, ktore klikalo (vlastny `gen`)')
end

# --- 5) fix zivej chyby: broadcast stavu hran (audit #2) ---------------------

NxTest.test('ŠT-1c (audit #2): EdgeCheck rozposiela stav ZDIELANYM broadcastom') do
  %w[notify_state_changed notify_count_changed].each do |m|
    body = S1C_EDGE_RB[/def #{m}\b.*?\n      end\n/m].to_s
    NxTest.refute(body.empty?, "#{m} sa nasla")
    NxTest.assert(body.include?('Engine.broadcast_edge_check'),
                  "#{m} rozposiela zdielanou cestou (nie vlastnym zoznamom okien)")
    NxTest.refute(body.include?('ProductionDialog.push_edge_check'),
                  "#{m} uz nemenuje jednotlive okna — Studio by v zozname chybalo")
    NxTest.refute(body.include?('Panel.push_edge_check'),
                  "#{m} nesmie obchadzat broadcast ani pri raile")
  end
  # A broadcast pozna VSETKY tri okna (bez toho by fix nic neriesil).
  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  body = main[/def self\.broadcast_edge_check.*?\n    end\n/m].to_s
  %w[ProductionDialog StudioDialog Panel].each do |win|
    NxTest.assert(body.include?("#{win}.push_edge_check"), "#{win} je v broadcaste")
  end
end
