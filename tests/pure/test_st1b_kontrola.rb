# frozen_string_literal: true
# ŠT-1b — sekcia KONTROLA v okne ŠTÚDIO (Š8–Š11) a presun z okna Výroba.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. JEDNO CISLO PRE VSETKYCH (audit #2). Semafor sekcie, badge navigacie,
#      ⚠ chip hlavicky okna Vyroba aj suhrn v statuse a LOGu VEPO exportu musia
#      ukazovat TO ISTE — teda vypocet KONTROLY (vratane rozpoctovych ORANGE)
#      smie zit na JEDNOM mieste. Dve kopie by sa casom rozisli a rozdiel by sa
#      ukazal az na objednavke. (⚠ chip INSPECTORA je nieco INE — build warnings
#      oznacenej skrinky; do sekcie Kontrola len VEDIE deep-linkom.)
#   2. ZELENE CISLO semaforu (audit #4) pocita SERVER vo `Validation.counts`.
#      Tvar counts je kontrakt — klient si pocet skriniek nedopocitava; a jeho
#      MENOVATEL je skutocny pocet skriniek zo zberu, nie dlzka zoznamu ID
#      z placements (review #2 — kopie so zhodnym ID a skrinky bez ID).
#   3. ZDIELANY GUARD prepinacov (audit #5) nesmie mat OKENNY STAV: telo zije
#      v `ProductionCore`, okna su len tenke obaly nad vlastnou generaciou.
#   4. TRETIE OKNO v broadcaste (audit #6). Bez neho by prepnutie z railu nebolo
#      v otvorenom Studiu vidiet a na obrazovke by stali dve kopie nastavenia.
#   5. LIFECYCLE (audit #1) — zatvorenie okna Vyroba uz overlaye NEVYPINA (je to
#      vedoma zmena), zato Studio zapamatanu kresbu pri otvoreni OBNOVI.
#   6. DEEP-LINK reťaz warnpanel → Studio → sekcia `ctrl` (audit #11).
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog') if NxTest.headless?

S1B_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                          encoding: 'UTF-8')
S1B_PROD_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'),
                          encoding: 'UTF-8')
S1B_CORE_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                          encoding: 'UTF-8')
S1B_MAIN_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
S1B_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                          encoding: 'UTF-8')
S1B_PROD_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'production.js'),
                          encoding: 'UTF-8')
S1B_SHELL_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'),
                          encoding: 'UTF-8')
S1B_BRIDGE_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                          encoding: 'UTF-8')
S1B_PROD_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production.html'),
                          encoding: 'UTF-8')
S1B_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                            encoding: 'UTF-8')

# --- 1) zrkadla whitelistov ---------------------------------------------------

NxTest.test('ŠT-1b: sekcia `ctrl` je v RUBY whiteliste a JS je jeho ZRKADLO') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = S1B_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = S1B_SHELL_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert_equal(%w[bom ctrl], rb, 'v Studiu ziju sekcie Kusovník a Kontrola')
  NxTest.assert_equal(rb, js, 'zoznam v studio.js sa nesmie rozist s Ruby autoritou')
  NxTest.assert_equal(rb, shell, 'ani zrkadlo v paneli (shell.js)')
end

NxTest.test('ŠT-1b: okno Vyroba stratilo tab `control` (a jeho UI s nim)') do
  rb = Noxun::Engine::ProductionDialog::TABS
  js = S1B_SHELL_JS[/var STUDIO_TABS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert_equal(%w[hardware budget], rb, 'whitelist tabov uz Kontrolu nepozna')
  NxTest.assert_equal(rb, js, 'JS mirror sa nesmie rozist s Ruby autoritou')
  NxTest.refute(S1B_PROD_HTML.include?('id="pt_control"'), 'tlacidlo tabu zaniklo')
  NxTest.refute(S1B_PROD_HTML.include?('id="ctrlTabBadge"'), 'badge tabu zanikol s nim')
  NxTest.refute(S1B_PROD_HTML.include?('id="ecBar"'), 'lista prepinacov v okne Vyroba zanikla')
  %w[renderControl ctrlActionHtml edgeCheckBarHtml grainBtnHtml renderEdgeBar renderBadge].each do |fn|
    NxTest.refute(S1B_PROD_JS.include?("function #{fn}"), "mrtvy helper #{fn} sa mal odstranit")
  end
  # Prijimace JS pushov zanikaju spolu s UI (Ruby push je guardovany
  # `if (window.NX && ...)`, takze mu prazdno neprekaza).
  %w[setEdgeCheck setGrainCheck closeEdgeMenu].each do |fn|
    NxTest.refute(S1B_PROD_JS.include?("#{fn}: function"), "prijimac #{fn} sa mal odstranit")
  end
  # DEFAULT vetva tela okna musi byt Kovanie — inak by okno po zaniku Kontroly
  # skoncilo na neexistujucej vetve a ostalo prazdne.
  NxTest.assert(S1B_PROD_JS.include?('renderHardware(box);'), 'default vetva je Kovanie')
  NxTest.refute(S1B_PROD_JS.include?("prodTab === 'control'"), 'ziadna vetva tabu Kontrola')
end

# --- 2) JEDNO cislo kontroly (audit #2) --------------------------------------

NxTest.test('ŠT-1b: KONTROLU pocita JEDNO miesto — obe okna volaju to iste') do
  NxTest.assert(Noxun::Engine::ProductionCore.respond_to?(:control_payload),
                'ProductionCore.control_payload existuje')
  NxTest.assert(S1B_CORE_RB =~ /def control_payload.*?Validation\.with_budget/m,
                'zlucenie s upozorneniami ROZPOCTU je SUCASTOU zdielaneho vypoctu')
  NxTest.assert(S1B_PROD_RB.include?('ProductionCore.control_payload'),
                'okno Vyroba cita zdielany vypocet')
  NxTest.assert(S1B_STUDIO_RB.include?('ProductionCore.control_payload'),
                'a okno Studio ten isty')
  # Vlastny (druhy) vypocet v okne by sa casom rozisiel — v push_state uz
  # ziadne okno Validation.run nevola.
  [['production_dialog.rb', S1B_PROD_RB], ['studio_dialog.rb', S1B_STUDIO_RB]].each do |(name, src)|
    NxTest.refute(src.include?('Validation.with_budget'),
                  "#{name} nesmie mat vlastne zlucenie rozpoctovych nalezov")
    NxTest.refute(src.include?('Validation.run('),
                  "#{name} nesmie mat vlastny vypocet kontroly")
  end
  NxTest.assert(S1B_STUDIO_RB.include?("control: control['items'], counts: control['counts']"),
                'payload Studia nesie zoznam AJ counts (JS si nic neprepocitava)')
end

NxTest.test('ŠT-1b (review #1): aj VEPO export cita to iste cislo kontroly') do
  # Export pisal suhrn KONTROLY do statusu aj do LOGu z vlastneho
  # `Validation.run` BEZ rozpoctovych ORANGE — a hlasil teda ine cislo nez
  # semafor sekcie. Teraz ide tou istou zdielanou cestou.
  body = S1B_CORE_RB[/def do_export\(model, data.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'telo exportu sa nasiel')
  NxTest.assert(body.include?('control_payload('),
                'export pocita kontrolu ZDIELANOU cestou')
  NxTest.assert(body.include?('budget: budget_payload('),
                'a to VRATANE rozpoctovych nalezov (inak by hlasil mensie cislo)')
  NxTest.refute(body.include?('Validation.run('),
                'ziadny vlastny vypocet kontroly v exporte')
  NxTest.assert(body.include?('validation: control'),
                'ten isty vysledok ide do VEPO LOGu')
  NxTest.assert(body.include?('control_suffix(control)'),
                'a do suhrnu v statuse okna')
end

NxTest.test('ŠT-1b: rozpoctove nalezy su v zozname a maju kam viest (audit #3)') do
  NxTest.assert(S1B_STUDIO_JS.include?("it.category === 'budget'"),
                'rozpoctovy nalez ma vlastnu vetvu')
  NxTest.assert(S1B_STUDIO_JS.include?("bridgeTo('budget')"),
                'klik na neho premosti do Rozpoctu (okno Vyroba)')
  NxTest.assert(S1B_STUDIO_JS.include?('okne Výroba'),
                'a tooltip to PRIZNA (kotva na sekciu tam nevedie)')
  NxTest.assert(Noxun::Engine::StudioDialog::PRODUCTION_BRIDGES['budget'] == 'budget',
                'premostenie mieri na tab Rozpocet, ktory okno Vyroba pozna')
end

# --- 3) zelene cislo semaforu (audit #4) -------------------------------------

NxTest.test('ŠT-1b: counts nesie ZELENE cislo „skriniek bez nálezu" (tvar payloadu)') do
  v = Noxun::Engine::Validation
  items = [{ 'severity' => 'red', 'owner_id' => 'CAB-1', 'stable_key' => 'a' },
           { 'severity' => 'orange', 'owner_id' => 'CAB-1', 'stable_key' => 'b' },
           { 'severity' => 'orange', 'owner_id' => 'CAB-2', 'stable_key' => 'c' }]
  out = v.counts(items, cabinet_ids: %w[CAB-1 CAB-2 CAB-3 CAB-4])
  NxTest.assert_equal(1, out['red'])
  NxTest.assert_equal(2, out['orange'])
  NxTest.assert_equal(3, out['total'])
  NxTest.assert_equal(4, out['cabinets'], 'pocet korpusov je zo SERVERA')
  NxTest.assert_equal(2, out['clean'],
                      'skrinky bez nalezu = korpusy minus VLASTNICI nalezov (nie minus nalezy)')
  # Bez zoznamu skriniek sa tvar counts NEMENI — legacy volania a headless
  # testy o zelene cislo nezakopnu.
  NxTest.assert_equal({ 'red' => 1, 'orange' => 2, 'total' => 3 }, v.counts(items),
                      'bez cabinet_ids ostava povodny tvar')
end

NxTest.test('ŠT-1b: zoznam skriniek berie run() z placements (a bez nich mlci)') do
  v = Noxun::Engine::Validation
  places = [{ 'kind' => 'cabinet', 'owner_id' => 'CAB-1' },
            { 'kind' => 'cabinet', 'owner_id' => 'CAB-1' }, # kopia toho isteho ID
            { 'kind' => 'board', 'owner_id' => 'BRD-9' },
            { 'kind' => 'cabinet', 'owner_id' => '' }]
  NxTest.assert_equal(%w[CAB-1], v.cabinet_ids(places),
                      'mnozina ID = LEN korpusy a KAZDE ID raz')
  NxTest.assert_equal(nil, v.cabinet_ids(nil), 'bez placements sa zelene cislo nepocita')

  out = v.run({ records: [], cabinets: 3 }, placements: places)
  NxTest.assert_equal(3, out['counts']['cabinets'], 'run zelene cislo doplni')
  NxTest.assert_equal(3, out['counts']['clean'], 'ciste korpusy bez nalezov')
  NxTest.refute(v.run({ records: [] })['counts'].key?('clean'),
                'legacy volanie bez placements ma NEZMENENY tvar')
end

NxTest.test('ŠT-1b (review #2): MENOVATEL je skutocny pocet skriniek, nie dlzka zoznamu ID') do
  # Presny scenar z review: TRI skrinky v modeli — dve kopie so ZHODNYM ID
  # (`Bom.add_placement` ich zbiera raz) a jedna BEZ ID (placement nedostane
  # vobec). Kym sa menovatel bral z placements, semafor tvrdil „1 skrinka",
  # hoci v zakazke stali tri — a zelene cislo klamalo.
  v = Noxun::Engine::Validation
  places = [{ 'kind' => 'cabinet', 'owner_id' => 'CAB-1' },
            { 'kind' => 'cabinet', 'owner_id' => 'CAB-1' }]
  collected = { records: [], cabinets: 3, placements: places }
  out = v.run(collected, placements: places)
  NxTest.assert_equal(3, out['counts']['cabinets'],
                      'pocet skriniek je zo ZBERU (collected[:cabinets])')
  NxTest.assert_equal(3, out['counts']['clean'], 'ziadna z nich nema nalez')

  # Nalez na zdielanom ID „spini" prave jednu (viac ich rozlisit nevieme —
  # dve kopie maju to iste ID; menovatel vsak ostava pravdivy).
  items = [{ 'severity' => 'red', 'owner_id' => 'CAB-1', 'stable_key' => 'x' }]
  dirty = v.counts(items, cabinet_ids: %w[CAB-1], cabinets: 3)
  NxTest.assert_equal(3, dirty['cabinets'])
  NxTest.assert_equal(2, dirty['clean'])

  # Bez `cabinets:` (spatna kompatibilita) sa pocet odvodi zo zoznamu ID.
  legacy = v.counts([], cabinet_ids: %w[CAB-1 CAB-2])
  NxTest.assert_equal(2, legacy['cabinets'])
  NxTest.assert_equal(2, legacy['clean'])
  # Menovatel a citatel su z dvoch zdrojov — zaporne cislo sa NIKDY neukaze.
  NxTest.assert_equal(0, v.counts(items, cabinet_ids: %w[CAB-1], cabinets: 0)['clean'],
                      'zelene cislo sa nikdy nedostane pod nulu')
end

NxTest.test('ŠT-1b: zlucenie s rozpoctom zelene cislo NEZAHODI (rozpocet nema vlastnika)') do
  v = Noxun::Engine::Validation
  base = { 'items' => [{ 'severity' => 'red', 'owner_id' => 'CAB-1', 'stable_key' => 'a' }],
           'counts' => { 'red' => 1, 'orange' => 0, 'total' => 1, 'cabinets' => 5, 'clean' => 4 } }
  out = v.with_budget(base, [{ 'message' => 'montáž bez sadzby', 'stable_key' => 'budget|x',
                               'section' => 'services' }])
  NxTest.assert_equal(1, out['counts']['red'])
  NxTest.assert_equal(1, out['counts']['orange'], 'rozpoctovy nalez sa doratal')
  NxTest.assert_equal(4, out['counts']['clean'], 'zelene cislo prezilo zlucenie')
  NxTest.assert_equal(5, out['counts']['cabinets'])
end

# --- 4) zdielany guard prepinacov (audit #5) ---------------------------------

NxTest.test('ŠT-1b: guard prepinacov zije v ProductionCore a NEMA okenny stav') do
  core = Noxun::Engine::ProductionCore
  %i[edge_check_guard do_edge_check do_edge_check_option do_grain_check
     edge_check_status edge_check_option_status grain_check_status replace_uni].each do |m|
    NxTest.assert(core.respond_to?(m), "ProductionCore neodpoveda na #{m}")
  end
  guard = S1B_CORE_RB[/def edge_check_guard.*?\n      end\n/m].to_s
  ident = S1B_CORE_RB[/def identity_guard.*?\n      end\n/m].to_s
  NxTest.refute(guard.empty? || ident.empty?, 'oba guardy sa nasli')
  [guard, ident].each do |src|
    %w[@dialog @generation @pending].each do |state|
      NxTest.refute(src.include?(state), "zdielane jadro nesmie siahat na okenny stav #{state}")
    end
  end
  NxTest.assert(guard.include?('EdgeCheck.available?(model)'), 'bez Overlay API sa nic nezapina')
  NxTest.assert(guard.include?('identity_guard('), 'zvyrazenie hran zdiela identitu kliku')
  NxTest.assert(ident.include?("data['gen'].to_i == generation.to_i"),
                'generaciu odovzdava OKNO (kazde ma vlastnu)')
  NxTest.assert(ident.include?("data['model_guid'].to_s == model_guid(model)"),
                'PRISNA zhoda dokumentu (callback HtmlDialogu je asynchronny)')
  # Obe okna su len obaly — vlastne telo by znamenalo dve rozne spravania.
  NxTest.assert(S1B_STUDIO_RB.include?('ProductionCore.do_edge_check(') &&
                S1B_STUDIO_RB.include?('generation: @generation'),
                'Studio odovzdava svoju generaciu zdielanemu jadru')
  NxTest.assert(S1B_PROD_RB.include?('ProductionCore.do_edge_check('),
                'okno Vyroba tiez (kym zije)')
end

NxTest.test('ŠT-1b (review #6): kresba hlasi NEDOSTUPNE API vlastnou vetou') do
  body = S1B_CORE_RB[/def do_grain_check\(model, data.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'telo prepinaca kresby sa nasiel')
  NxTest.assert(body.include?('GrainCheck.available?(model)'),
                'dostupnost si overuje VLASTNU (nie cez zvyraznenie hran)')
  NxTest.assert(body.include?('Smer kresby vyžaduje SketchUp 2023 alebo novší.'),
                'a hlasi ju vetou o KRESBE')
  NxTest.refute(body.include?('edge_check_guard'),
                'nesmie ist cez guard hran — pri starom SketchUpe by hlasil text o hranach')
  NxTest.assert(body.include?('identity_guard('), 'identita kliku ostava ZDIELANA')
end

NxTest.test('ŠT-1b: prepinace sa NEDOTYKAJU modelu (ziadna operacia, ziadny krok Spat)') do
  %w[do_edge_check do_edge_check_option do_grain_check replace_uni].each do |m|
    body = S1B_CORE_RB[/def #{m}\(model, data.*?\n      end\n/m].to_s
    NxTest.refute(body.empty?, "telo #{m} sa nasiel")
    %w[start_operation commit_operation Store. set_attribute].each do |forbidden|
      NxTest.refute(body.include?(forbidden), "#{m} nesmie volat #{forbidden}")
    end
  end
end

NxTest.test('ŠT-1b: sekcia Kontrola registruje vlastne callbacky (klient posiela iba kluc)') do
  %w[replace_uni edge_check_toggle edge_check_option edge_menu_open grain_check_toggle].each do |cb|
    NxTest.assert(S1B_STUDIO_RB.include?("cb(dlg, '#{cb}')"), "callback #{cb} musi byt zaregistrovany")
  end
  NxTest.assert(S1B_STUDIO_RB.include?('ProductionCore.replace_uni'),
                'telo „Nahradiť UNI…" je zdielane s oknom Vyroba')
  NxTest.assert(S1B_CORE_RB.include?('MaterialsDialog.request_replace_uni(uni_id, model)'),
                'a otvara PLNE FUNKCNY modal okna Materialy')
  NxTest.assert(S1B_STUDIO_JS.include?('sketchup.replace_uni'), 'klient ma protajsok')
end

# --- 5) tretie okno v broadcaste (audit #6) ----------------------------------

NxTest.test('ŠT-1b: stav prepinacov dostanu VSETKY tri okna') do
  edge = S1B_MAIN_RB[/def self\.broadcast_edge_check.*?\n    end\n/m].to_s
  grain = S1B_MAIN_RB[/def self\.broadcast_grain_check.*?\n    end\n/m].to_s
  [['edge', edge], ['grain', grain]].each do |(name, cast)|
    NxTest.refute(cast.empty?, "broadcast #{name} sa nasiel")
    NxTest.assert(cast.include?('StudioDialog.push_'), "#{name}: Studio musi dostat novy stav")
    NxTest.assert(cast.include?('Panel.push_'), "#{name}: rail musi dostat novy stav")
    NxTest.assert(cast.include?('ProductionDialog.push_'), "#{name}: okno Vyroba tiez")
    NxTest.assert(cast.include?('defined?(StudioDialog)'),
                  "#{name}: push je defenzivny — nenacitane okno ho ticho zahodi")
  end
  NxTest.assert(S1B_STUDIO_RB.include?('def push_edge_check') &&
                S1B_STUDIO_RB.include?('def push_grain_check'),
                'Studio ma obidva prijimace')
  NxTest.assert(S1B_STUDIO_RB.include?('if (window.NX && NX.setEdgeCheck)'),
                'push je guardovany — okno bez nacitaneho HTML nezhodi')
  NxTest.assert(S1B_STUDIO_JS.include?('setEdgeCheck: function(state)') &&
                S1B_STUDIO_JS.include?('setGrainCheck: function(state)') &&
                S1B_STUDIO_JS.include?('closeEdgeMenu: function()'),
                'klient pozna vsetky tri echa')
end

# --- 6) lifecycle overlayov (audit #1, #14) ----------------------------------

NxTest.test('ŠT-1b: zatvorenie okna Vyroba uz overlaye NEVYPINA (vedoma zmena)') do
  body = S1B_PROD_RB[/@dialog\.set_on_closed.*?\n          @dialog\n/m].to_s
  NxTest.refute(body.include?('EdgeCheck.disable!'),
                'okno, ktore prepinac uz nezobrazuje, ho nesmie vypinat')
  NxTest.refute(body.include?('GrainCheck.disable!'), 'to iste pre kresbu smeru')
  NxTest.assert(S1B_PROD_RB.include?('@dialog.set_on_closed { @dialog = nil }'),
                'referencia na mrtve okno sa NADALEJ vynuluje')
  # Studio disable NEPRIDAVA — trvalym vstupnym bodom je rail Inspectora.
  NxTest.refute(S1B_STUDIO_RB.include?('EdgeCheck.disable!'),
                'Studio prepinac pri zatvoreni NEVYPINA')
  NxTest.refute(S1B_STUDIO_RB.include?('GrainCheck.disable!'), 'ani kresbu')
end

NxTest.test('ŠT-1b: Studio obnovi zapamatanu kresbu PRED prvym pushom (audit #14)') do
  NxTest.assert(S1B_STUDIO_RB.include?('def restore_grain_check'), 'obnova ma vlastnu metodu')
  NxTest.assert(S1B_STUDIO_RB.include?('GrainCheck.restore!(Sketchup.active_model)'),
                'obnovuje sa zapamatany prepinac z %APPDATA%')
  # Komentare (ktore o poradi hovoria) sa vynechavaju — hlada sa KOD.
  show = S1B_STUDIO_RB[/def show\(open_section:.*?\n        end\n/m].to_s
                      .lines.map { |l| l.sub(/#.*$/, '') }.join
  NxTest.assert(show.include?('restore_grain_check'), 'obnova bezi pri otvoreni okna')
  NxTest.assert(show.index('restore_grain_check') < show.index('push_state'),
                'a to PRED prvym pushom — inak by lista hlasila vypnute')
end

# --- 7) deep-link reťaz (audit #11) ------------------------------------------

NxTest.test('ŠT-1b: warnpanel Inspectora vedie do ŠTÚDIA na sekciu Kontrola') do
  body = S1B_BRIDGE_JS[/function onWarnStudio.*?\n  \}/m].to_s
  NxTest.assert(body.include?("openStudio('ctrl')"), 'deep-link mieri na sekciu `ctrl`')
  NxTest.refute(body.include?('openProductionDialog'), 'stara cesta do okna Vyroba zanikla')
  NxTest.assert(S1B_SHELL_JS.include?('function studioOpenLink'),
                'payload sklada zdielana cista funkcia (whitelist je aj tak v Ruby)')
end

NxTest.test('ŠT-1b: ⚠ chip okna Vyroba otvara Studio (ziadne mrtve tlacidlo)') do
  NxTest.assert(S1B_PROD_HTML.include?('onclick="openStudioControl()"'),
                'chip ma kam viest')
  NxTest.assert(S1B_PROD_JS.include?('function openStudioControl'), 'klient ma handler')
  NxTest.assert(S1B_PROD_JS.include?('sketchup.open_studio'), 'a vola serverovy callback')
  NxTest.assert(S1B_PROD_RB.include?("cb(dlg, 'open_studio')"), 'okno Vyroba callback registruje')
  NxTest.assert(S1B_PROD_RB.include?("StudioDialog.show(open_section: 'ctrl')"),
                'a otvara Studio rovno na Kontrole')
end

# --- 8) UI kontrakt sekcie ---------------------------------------------------

NxTest.test('ŠT-1b: sekcia Kontrola ma semafor, riadky aj oba prepinace') do
  NxTest.assert(S1B_STUDIO_JS.include?('function ctrlSection'), 'telo sekcie existuje')
  NxTest.assert(S1B_STUDIO_JS.include?('function semaforHtml'), 'Š8 semafor')
  NxTest.assert(S1B_STUDIO_JS.include?('function ctrlRowHtml'), 'Š9 riadky')
  NxTest.assert(S1B_STUDIO_JS.include?('function navBadgeHtml'), 'Š11 badge navigacie')
  NxTest.assert(S1B_STUDIO_HTML.include?('.semafor') && S1B_STUDIO_HTML.include?('.ctrlrow'),
                'styly sekcie ziju v studio.html (rozlozenie okna do panel.css nepatri)')
  NxTest.assert(S1B_STUDIO_HTML.include?('js/edge_menu.js'),
                'okno nacitava ZDIELANY komponent 3-stavoveho nastavenia')
  # Emoji su v ovladacich prvkoch zakazane (UI_DIZAJN §4) — bodky zavaznosti
  # su CSS, ikony zo spritu.
  ctrl = S1B_STUDIO_JS[/function ctrlRowHtml.*?\n  \}/m].to_s
  NxTest.refute(ctrl =~ /[\u{1F300}-\u{1FAFF}]/, 'ziadne emoji v riadku nalezu')
end
