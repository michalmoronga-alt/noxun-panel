# frozen_string_literal: true
# ST-1a PR B — okno ŠTÚDIO (skelet + sekcia Kusovník) a SERVEROVY nazov projektu.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. SEKCIE su whitelist v RUBY a JS je jeho zrkadlo. Keby sa rozisli, panel by
#      posielal meno, ktore okno nepozna — deep-link by skoncil ticho.
#   2. Deep-link sa spotrebuje PRAVE RAZ. Bez toho by kazdy refresh vratil
#      pouzivatela do sekcie, z ktorej medzitym odisiel (lekcia `@pending_tab`).
#   3. NAZOV PROJEKTU je od tejto davky SERVEROVY (audit #1). Dokial ho posielal
#      DOM, mali by dve okna dve pravdy — VEPO z jedneho a rozpocet z druheho by
#      pomenovali TU ISTU zakazku inak. Test preto vyzaduje, aby vsetky STYRI
#      exporty citali `project_name(model)` a aby JS `project:` uz neposielal.
#   4. `materials_meta` je kontrakt Š1 — bez neho by klient musel skladat nazov
#      dekoru sam a mal by druhu pravdu o tom, ako sa material vola.
#   5. Premostenia navigacie su uzavrety zoznam v Ruby. Klient posiela iba kluc;
#      keby o cieli rozhodoval on, dalo by sa z okna otvorit cokolvek.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva). Parse-time
# tu ziadne SketchUp API nie je — vsetko je vnutri metod.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?

ST1B_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
ST1B_CORE_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                           encoding: 'UTF-8')
ST1B_PROD_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'),
                           encoding: 'UTF-8')
ST1B_PANEL_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
ST1B_MAIN_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
ST1B_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
ST1B_PROD_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'production.js'),
                           encoding: 'UTF-8')
ST1B_BUDGET_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'),
                           encoding: 'UTF-8')
ST1B_BRIDGE_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                           encoding: 'UTF-8')
ST1B_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')
ST1B_PROD_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production.html'),
                           encoding: 'UTF-8')

# --- 1) whitelist sekcii + zrkadlo -------------------------------------------

NxTest.test('ST-1a: SECTIONS je whitelist v RUBY a JS je jeho ZRKADLO') do
  rb = ST1B_STUDIO_RB[/SECTIONS = %w\[([a-z ]+)\]/, 1].to_s.split
  js = ST1B_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  # ŠT-1b pridala sekciu Kontrola (`ctrl`) — dovtedy premostenie do okna Vyroba.
  NxTest.assert_equal(%w[bom ctrl], rb, 'v Studiu ziju sekcie Kusovník a Kontrola')
  NxTest.assert_equal(rb, js, 'JS zoznam sekcii sa nesmie rozist s Ruby autoritou')
  NxTest.assert_equal(rb, Noxun::Engine::StudioDialog::SECTIONS,
                      'konstanta a zdrojak hovoria to iste')
end

NxTest.test('ST-1a: deep-link sekcie sa spotrebuje PRAVE RAZ') do
  body = ST1B_STUDIO_RB[/def consume_pending_section.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'spotreba ma vlastnu funkciu')
  NxTest.assert(body.include?('@pending_section = nil'),
                'bez vynulovania by kazdy refresh vratil pouzivatela do starej sekcie')
  NxTest.assert(body.include?('SECTIONS.include?'), 'aj pri spotrebe plati whitelist')
  anchor = ST1B_STUDIO_RB[/def consume_pending_anchor.*?\n        end\n/m].to_s
  NxTest.assert(anchor.include?('@pending_anchor = nil'),
                'kotva hladania sa spotrebuje rovnako — inak by sa filter vracal po kazdom pushi')
  NxTest.assert(ST1B_STUDIO_RB.include?('open_section: consume_pending_section'),
                'sekcia cestuje v tom istom pushi ako data (okno po `show` este nemusi mat HTML)')
  NxTest.assert(ST1B_STUDIO_RB.include?('anchor: consume_pending_anchor'),
                'a kotva s nou')
end

NxTest.test('ST-1a: kotva sa posiela LEN so sekciou (inak nema kam sadnut)') do
  body = ST1B_STUDIO_RB[/def show\(open_section:.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'show sa nasiel')
  NxTest.assert(body.include?('@pending_anchor = @pending_section ? anchor.to_s.strip : nil'),
                'bez platnej sekcie sa kotva zahadzuje')
end

# --- 2) nazov projektu je SERVEROVY (audit #1) -------------------------------

NxTest.test('ST-1a: nazov projektu zije v ProductionCore (mapa project_names)') do
  core = Noxun::Engine::ProductionCore
  %i[project_names project_name save_project_name merge_18_36 save_merge_18_36
     project_key project_session_key normalize_project_path].each do |m|
    NxTest.assert(core.respond_to?(m), "ProductionCore neodpoveda na #{m}")
  end
  NxTest.assert_equal('project_names', Noxun::Engine::ProductionCore::PROJECT_NAMES_KEY,
                      'kluc mapy je sucastou kontraktu suboru vepo_settings.json')
end

NxTest.test('ST-1a (review P1): klucom je CESTA, nie model.guid — guid sa meni pri ulozeni') do
  # SketchUp dokumentuje, ze `Model#guid` sa MENI po kazdom ulozeni. Na guid
  # kluci by sa nazov po Ctrl+S ticho stratil a v subore by rastli mrtve
  # zaznamy. Tento test simuluje presne to: medzi zapisom a citanim sa guid
  # zmeni, cesta ostane — a nazov MUSI prezit.
  core = Noxun::Engine::ProductionCore
  m1 = Struct.new(:path, :guid).new('C:/Zakazky/KLINIKA_v7.skp', 'GUID-PRED-ULOZENIM')
  m2 = Struct.new(:path, :guid).new('C:/Zakazky/KLINIKA_v7.skp', 'GUID-PO-ULOZENI')
  begin
    core.save_project_name(m1, 'Klinika Bratislava')
    NxTest.assert_equal('Klinika Bratislava', core.project_name(m2),
                        'zmena guid (ulozenie modelu) nesmie nazov zahodit')
    # Kluc je normalizovany — Windows nerozlisuje velkost pismen ani lomitka.
    m3 = Struct.new(:path, :guid).new('c:\\zakazky\\KLINIKA_v7.skp', 'GUID-INY')
    NxTest.assert_equal('Klinika Bratislava', core.project_name(m3),
                        'ta ista cesta inak zapisana = ten isty zaznam')
    NxTest.assert_equal('c:/zakazky/klinika_v7.skp', core.project_key(m3),
                        'kluc je normalizovana cesta')
  ensure
    core.save_project_name(m1, '')
  end
end

NxTest.test('ST-1a (review P1): neulozeny model ma NAHRADNY kluc a pri ulozeni sa ZMIGRUJE') do
  core = Noxun::Engine::ProductionCore
  untitled = Struct.new(:path, :guid).new('', 'GUID-UNTITLED')
  saved = Struct.new(:path, :guid).new('C:/Zakazky/Nova.skp', 'GUID-UNTITLED')
  begin
    NxTest.assert_equal('guid:GUID-UNTITLED', core.project_key(untitled),
                        'neulozeny model ma kluc sedenia (plati len dovtedy, kym sa neulozi)')
    core.save_project_name(untitled, 'Rozrobena zakazka')
    NxTest.assert_equal('Rozrobena zakazka', core.project_name(untitled))
    # Ctrl+S: model teraz MA cestu. Zaznam sedenia je zaloha, takze nazov drzi.
    NxTest.assert_equal('Rozrobena zakazka', core.project_name(saved),
                        'po ulozeni sa nazov nestrati (citanie padne na kluc sedenia)')
    # Prvy zapis s platnou cestou zaznam PRESUNIE a guid kluc zmaze.
    core.save_project_name(saved, 'Rozrobena zakazka')
    map = core.project_names
    NxTest.assert(map.key?('c:/zakazky/nova.skp'), 'zaznam sadol na cestu')
    NxTest.refute(map.key?('guid:GUID-UNTITLED'),
                  'guid zaznam po migracii zanikol — inak by v subore rastli mrtve kluce')
  ensure
    core.save_project_name(saved, '')
    map = core.project_names.dup
    map.delete('guid:GUID-UNTITLED')
    core.save_vepo_settings(Noxun::Engine::ProductionCore::PROJECT_NAMES_KEY => map)
  end
end

NxTest.test('ST-1a: nazov projektu je nastavenie POCITACA — nikdy sa nezapisuje do modelu') do
  body = ST1B_CORE_RB[/def save_project_name.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'zapis ma vlastnu funkciu')
  NxTest.assert(body.include?('save_vepo_settings'),
                'zapisuje sa do %APPDATA% (vepo_settings.json), nie do .skp')
  NxTest.refute(body.include?('start_operation'), 'ziadna operacia = ziadny krok Spat')
  NxTest.refute(body.include?('Store.'), 'ziadny zapis do NOXUN dictionary modelu')
end

NxTest.test('ST-1a: model bez akejkolvek identity dostane DEFAULT (nema sa kam zapisat)') do
  core = Noxun::Engine::ProductionCore
  # Ani cesta, ani guid = neexistuje stabilny kluc. Vymyslat ho by znamenalo,
  # ze si dva rozne dokumenty prepisu ten isty zaznam.
  empty = Struct.new(:path, :guid).new('', '')
  NxTest.assert_equal('', core.project_key(empty), 'bez cesty aj bez guid nie je kluc')
  NxTest.assert_equal('projekt', core.project_name(empty), 'neulozena zakazka ma zastupny nazov')
  NxTest.assert_equal('projekt', core.save_project_name(empty, 'ine meno'),
                      'a zapis sa NEUDEJE')
  named = Struct.new(:path, :guid).new('C:/x/KLINIKA_v7.skp', '')
  NxTest.assert_equal('KLINIKA_v7', core.project_name(named),
                      'bez ulozeneho zaznamu sa nazov berie zo suboru zakazky')
end

NxTest.test('ST-1a: VSETKY STYRI exporty citaju nazov zo SERVERA — z DOM uz nechodi') do
  # Presne toto bol BLOCKER #1: dokial nazov posielal DOM, dve okna mali dve
  # pravdy a ta ista zakazka sa v dvoch vystupoch volala inak.
  NxTest.assert(ST1B_CORE_RB.include?('project: project_name(model)'),
                'VEPO export cita nazov v Ruby')
  NxTest.assert_equal(3, ST1B_PROD_RB.scan(/project = project_name\(model\)/).length,
                      'CSV kovania, XLSX rozpoctu aj XLSX cenovej ponuky citaju nazov v Ruby')
  # Komentare (ktore o zaniknutej ceste hovoria) sa vynechavaju — hlada sa KOD.
  strip = ->(src) { src.lines.map { |l| l.sub(/#.*$/, '') }.join }
  NxTest.refute(strip.call(ST1B_PROD_RB).include?("data['project']"),
                'okno Vyroba uz nazov z klienta NECITA')
  NxTest.refute(strip.call(ST1B_CORE_RB).include?("data['project']"),
                'ani zdielane jadro')
  [['production.js', ST1B_PROD_JS], ['budget.js', ST1B_BUDGET_JS], ['studio.js', ST1B_STUDIO_JS]].each do |(name, src)|
    NxTest.refute(src.match?(/project:\s*\(/),
                  "#{name} uz nesmie posielat `project:` z DOM (server je autorita)")
  end
  NxTest.refute(ST1B_PROD_HTML.include?('id="vepoProject"'),
                'input nazvu projektu v okne Vyroba ZANIKOL — je to vystup, nie vstup')
  NxTest.assert(ST1B_PROD_HTML.include?('id="prodProject"'),
                'okno Vyroba ukazuje nazov ako TEXT')
  NxTest.assert(ST1B_STUDIO_HTML.include?('id="secbody"') && ST1B_STUDIO_JS.include?("id=\"prjInput\""),
                'editovatelny input zije v liste Kusovnika v Studiu')
end

NxTest.test('ST-1a: merge 18+36 je GLOBALNE nastavenie a chodi v KAZDOM pushi (audit #16)') do
  NxTest.assert(ST1B_CORE_RB.include?("vepo_settings['merge_18_36'] != false"),
                'default je zapnute')
  NxTest.assert(ST1B_CORE_RB.include?('merge = merge_18_36'),
                'export cita merge zo SERVERA, nie z checkboxu')
  NxTest.assert(ST1B_STUDIO_RB.include?('merge_18_36: ProductionCore.merge_18_36'),
                'stav checkboxu je v KAZDOM pushi Studia')
  NxTest.assert(ST1B_PROD_RB.include?('merge_18_36: ProductionCore.merge_18_36'),
                'a v kazdom pushi okna Vyroba (obe okna citaju to iste)')
  NxTest.assert(ST1B_STUDIO_JS.include?("(v.merge_18_36 === false ? '' : ' checked')"),
                'checkbox sa NASADZUJE z payloadu (nie z pamate klienta)')
end

# --- 3) kontrakt payloadu Kusovnika (audit #4) -------------------------------

NxTest.test('ST-1a: materials_meta nesie label, farbu a hrubku per material_id') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert(core.respond_to?(:materials_meta), 'ProductionCore.materials_meta existuje')
  NxTest.assert(core.respond_to?(:edges_meta), 'a jeho protajsok pre ABS pasky')
  NxTest.assert(ST1B_STUDIO_RB.include?('materials_meta: ProductionCore.materials_meta(bom)'),
                'payload Studia ich naozaj nesie')
  NxTest.assert(ST1B_STUDIO_RB.include?('edges_meta: ProductionCore.edges_meta(bom)'),
                'aj pasky (pohlad ABS)')
  # tvar zaznamu — klient sa na tieto kluce spolieha
  meta = core.materials_meta(rows: [{ 'material_id' => 'NEEXISTUJE' }], sheets: [])
  NxTest.assert(meta.key?('NEEXISTUJE'), 'material z riadku dostane zaznam aj bez katalogu')
  NxTest.assert_equal(%w[label color th uni].sort, meta['NEEXISTUJE'].keys.sort,
                      'tvar zaznamu je kontrakt Š1')
  NxTest.assert_equal('NEEXISTUJE', meta['NEEXISTUJE']['label'],
                      'material mimo katalogu sa pomenuje svojim ID — nikdy sa nevymysla nazov')
  NxTest.assert_equal(nil, meta['NEEXISTUJE']['color'],
                      'bez katalogovej farby sa vzorka NEKRESLI (radsej nic nez nahodna farba)')
end

NxTest.test('ST-1a: farba je katalogove pole [r,g,b], nie CSS retazec') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert_equal([1, 2, 3], core.catalog_color('color' => [1, 2, 3]))
  NxTest.assert_equal(nil, core.catalog_color('color' => '#ff0000'), 'CSS retazec sa odmietne')
  NxTest.assert_equal(nil, core.catalog_color('color' => [1, 2]), 'neuplne pole sa odmietne')
  NxTest.assert_equal(nil, core.catalog_color(nil), 'chybajuci zaznam nezhodi prevod')
end

NxTest.test('ST-1a: rola dielca je SERVEROVY text a NEMENI kluc agregacie') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert_equal('Bok ľavý', core.role_label('side_left'), 'enum ma slovensky nazov')
  NxTest.assert_equal('Polica', core.role_label('shelf'))
  NxTest.assert_equal('', core.role_label(''), 'prazdna rola nevymysla text')
  NxTest.assert_equal('nieco_ine', core.role_label('nieco_ine'),
                      'nezname enum sa vypise, nie zahodí (aby sa nova rola nestratila)')
  # Kluc agregacie sa NESMIE zmenit — kusovnik aj VEPO na nom stoja.
  bom_src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'bom.rb'), encoding: 'UTF-8')
  NxTest.refute(bom_src[/def row_key.*?\n      end/m].to_s.include?("r['role']"),
                'rola sa do kluca riadku NEPRIDALA — zmenila by kusovnik aj VEPO')
  NxTest.assert(ST1B_CORE_RB.include?('def rows_with_roles'),
                'rola sa doplna READ-ONLY obohatenim riadku')
end

NxTest.test('ST-1a: rows_with_roles paruje zaznamy s riadkami cez TEN ISTY row_key') do
  core = Noxun::Engine::ProductionCore
  rec = { 'name' => 'Bok', 'part_key' => 'p1', 'owner_id' => 'CAB-1', 'pid' => 1,
          'role' => 'side_left', 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0,
          'quantity' => 1, 'material_id' => 'M1', 'grain_direction' => 'length',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  bom = Noxun::Engine::Bom.compute(records: [rec])
  out = core.rows_with_roles(bom[:rows], records: [rec])
  NxTest.assert_equal('Bok ľavý', out.first['role_label'], 'riadok dostal svoju rolu')
  NxTest.assert_equal(bom[:rows].first['key'], out.first['key'], 'kluc riadku ostal NEDOTKNUTY')
  NxTest.assert_equal([], core.rows_with_roles([], records: []), 'prazdny kusovnik nezhodi obohatenie')
end

NxTest.test('ST-1a: sucty suctoveho riadku pocita SERVER (JS zo `totals` LEN cita)') do
  NxTest.assert(ST1B_STUDIO_RB.include?('totals: totals_payload(bom, estimate)'),
                'payload nesie hotove sucty')
  body = ST1B_STUDIO_RB[/def totals_payload.*?\n        end\n/m].to_s
  %w[parts rows m2 bm materials edges plates_min plates_max].each do |k|
    NxTest.assert(body.include?("'#{k}'"), "sucet #{k} chyba v payloade")
  end
  NxTest.refute(ST1B_STUDIO_JS.match?(/reduce\(|\+=\s*\w+\.m2|\+=\s*\w+\.quantity/),
                'studio.js nesmie scitavat sumy — od toho je server')
end

# --- 4) vlastny kanal okna (audit #3) ----------------------------------------

NxTest.test('ST-1a: Studio ma VLASTNY generacny token aj vlastny relay') do
  NxTest.assert(ST1B_STUDIO_RB.include?('@generation = @generation.to_i + 1'),
                'push_state zdviha vlastnu generaciu')
  NxTest.assert(ST1B_STUDIO_RB.include?('generation: @generation'),
                'a odovzdava ju zdielanemu jadru')
  NxTest.assert(ST1B_STUDIO_RB.include?('NX.studioRelay('),
                'vyber ide vlastnym relayom (inak by odpoved prisla do okna Vyroba)')
  NxTest.assert(ST1B_STUDIO_RB.include?('NX.studioRelayExport('), 'export tiez')
  NxTest.assert(ST1B_BRIDGE_JS.include?('studioRelay: function(p)'), 'panel relay existuje')
  NxTest.assert(ST1B_BRIDGE_JS.include?('studioRelayExport: function(p)'), 'aj pre export')
  NxTest.assert(ST1B_BRIDGE_JS.include?('sketchup.studio_do_select'), 'a vola vlastny callback')
  NxTest.assert(ST1B_PANEL_RB.include?("cb(dlg, 'studio_do_select')"), 'panel ho registruje')
  NxTest.assert(ST1B_PANEL_RB.include?("cb(dlg, 'studio_do_export')"), 'aj export')
end

NxTest.test('ST-1a: export zo Studia ma ROVNAKY flush handshake ako okno Vyroba') do
  studio = ST1B_BRIDGE_JS[/studioRelayExport: function\(p\)\{.*?\n    \},/m].to_s
  prod = ST1B_BRIDGE_JS[/productionRelayExport: function\(p\)\{.*?\n    \},/m].to_s
  NxTest.assert(!studio.empty? && !prod.empty?, 'oba relaye sa nasli')
  NxTest.assert(studio.include?('!validateFields()'), 'neplatne pole export ZASTAVI')
  NxTest.assert(studio.include?('p.flush_blocked = blocked'), 'a povie to serveru')
  NxTest.assert(studio.include?('flushCabinetEditsNow()') && studio.include?('flushBoardEditsNow()'),
                'rozpisane edity korpusu aj dosky idu na server PRED zberom modelu')
end

NxTest.test('ST-1a: gen mismatch = RE-PUSH a status, nikdy ticho') do
  body = ST1B_CORE_RB[/def do_export\(model, data.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'zdielane telo exportu sa nasiel')
  NxTest.assert(body.include?('repush.call'), 'stary DOM klik obnovi okno')
  NxTest.assert(body.include?('Dáta okna sa medzitým zmenili'), 'a povie preco')
  # Review P2: vyber koncil TICHYM no-opom — pouzivatel klikol, nic sa
  # neoznacilo a okno mlcalo.
  sel = ST1B_CORE_RB[/def do_select\(model, data.*?\n      end\n/m].to_s
  NxTest.assert(sel.include?('Dáta okna sa medzitým obnovili — klikni znova.'),
                'aj vyber povie, PRECO sa nic neoznacilo')
  opts = ST1B_STUDIO_RB[/def do_set_vepo_opts.*?\n        end\n/m].to_s
  NxTest.assert(opts.include?('Okno sa medzitým prepočítalo'), 'to iste pri zapise nastaveni')
  NxTest.assert(opts.include?('Model sa medzitým prepol'), 'a pri prepnutom dokumente')
end

NxTest.test('ST-1a (review P2): zapis nastaveni NEZDVIHA generaciu (inak by prvy export spadol)') do
  # `change` na inpute Projekt priletí tesne pred `click` na VEPO. Keby zapis
  # koncil plnym push_state, generacia by sa zdvihla a prvy export by ZARUCENE
  # spadol na „Dáta okna sa medzitým zmenili" — pritom kusovnik sa nezmenil.
  opts = ST1B_STUDIO_RB[/def do_set_vepo_opts.*?\n        end\n/m].to_s
  NxTest.assert(!opts.empty?, 'handler sa nasiel')
  NxTest.assert(opts.include?('push_vepo_bar(model)'),
                'lista sa synchronizuje CIELENYM echom (vzor push_edge_check)')
  # Jediny push_state v handleri smie byt v ODMIETACICH vetvach (gen/model guard).
  tail = opts.split('msg = []').last.to_s
  NxTest.refute(tail.include?('push_state'),
                'uspesny zapis NESMIE prepocitat cele okno — zdvihol by generaciu')
  NxTest.assert(opts.include?('ProductionDialog.refresh_if_open'),
                'okno Vyroba ma vlastnu generaciu — tam staci bezny refresh')
  echo = ST1B_STUDIO_RB[/def push_vepo_bar.*?\n        end\n/m].to_s
  NxTest.refute(echo.include?('@generation'), 'echo sa generacie NEDOTYKA')
  NxTest.assert(echo.include?('NX.setVepoBar'), 'a meni LEN obsah listy')
  NxTest.assert(ST1B_STUDIO_JS.include?('setVepoBar: function(state)'), 'klient echo pozna')
  NxTest.assert(ST1B_STUDIO_JS.include?('document.activeElement !== inp'),
                'hodnota inputu sa nenasadzuje, kym v nom pouzivatel pise')
end

NxTest.test('ST-1a (review P2): sekcia ma RUCNY refresh (prestavba z Inspectora sem sama nedorazi)') do
  NxTest.assert(ST1B_STUDIO_RB.include?("cb(dlg, 'refresh_bom')"), 'callback existuje')
  NxTest.assert(ST1B_STUDIO_JS.include?("id=\"refreshBtn\""),
                'a MA ho co zavolat — inak by okno exportovalo VEPO zo starych cisel')
  NxTest.assert(ST1B_STUDIO_JS.include?("sketchup.refresh_bom('')"), 'tlacidlo vola callback')
end

# --- 5) premostenia navigacie (audit #2) -------------------------------------

NxTest.test('ST-1a: premostenia su UZAVRETY whitelist v Ruby, klient posiela iba kluc') do
  st = Noxun::Engine::StudioDialog
  # ŠT-1b: `ctrl` uz NIE JE premostenie — Kontrola je ziva sekcia tohto okna.
  NxTest.assert_equal(%w[budget buy offer].sort, st::PRODUCTION_BRIDGES.keys.sort,
                      'do okna Vyroba vedu uz len tri polozky navigacie')
  NxTest.refute(st::PRODUCTION_BRIDGES.key?('ctrl'),
                'Kontrola sa presunula do Studia — premostenie zaniklo')
  NxTest.assert_equal(%w[bset hw mat rules sup tpl].sort, st::WINDOW_BRIDGES.keys.sort,
                      'satelitne okna otvara sest poloziek')
  st::PRODUCTION_BRIDGES.each_value do |tab|
    NxTest.assert(Noxun::Engine::ProductionDialog::TABS.include?(tab),
                  "premostenie mieri na tab `#{tab}`, ktory okno Vyroba nepozna")
  end
  # Kazde premostenie ma slovensku hlasku — inak by pouzivatel nevedel, PRECO
  # sa mu otvorilo ine okno.
  (st::PRODUCTION_BRIDGES.keys + st::WINDOW_BRIDGES.keys + ['about']).each do |k|
    NxTest.assert(!st::BRIDGE_STATUS[k].to_s.empty?, "premostenie #{k} nema hlasku")
  end
  body = ST1B_STUDIO_RB[/def do_bridge.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('PRODUCTION_BRIDGES.key?(key)') && body.include?('WINDOW_BRIDGES.key?(key)'),
                'o cieli rozhoduje whitelist na SERVERI (HTML nie je ochrana)')
  NxTest.assert(body.include?('Táto sekcia zatiaľ neexistuje.'),
                'neznamy kluc sa odmietne nahlas')
end

NxTest.test('ST-1a: „Nárezový plán" je JEDINA neaktivna polozka a ma dovod (D-78)') do
  nav = ST1B_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  NxTest.assert(!nav.empty?, 'navigacia sa nasla')
  NxTest.assert_equal(1, nav.scan(/disabled:/).length,
                      'jedina neaktivna polozka — vsetko ostatne je premostenie')
  NxTest.assert(nav.include?("disabled: 'fáza 2"), 'a dovod je vypisany, nie zamlcany')
end

# --- 6) okno Vyroba prislo o tri taby ----------------------------------------

NxTest.test('ST-1a: okno Vyroba stratilo taby Kusovník / Materiály / ABS') do
  # ŠT-1b: a k nim aj tab Kontrola (sekcia `ctrl` okna Studio).
  NxTest.assert_equal(%w[hardware budget], Noxun::Engine::ProductionDialog::TABS,
                      'whitelist tabov uz zaniknute taby nepozna')
  %w[pt_rows pt_sheets pt_edging].each do |id|
    NxTest.refute(ST1B_PROD_HTML.include?("id=\"#{id}\""), "tlacidlo #{id} zaniklo")
  end
  NxTest.refute(ST1B_PROD_HTML.include?('class="vepobar"'), 'VEPO lista okna Vyroba zanikla')
  NxTest.assert(ST1B_PROD_JS.include?("var prodTab = 'hardware'"),
                'prvy tab zlava je odteraz Kovanie')
  # audit #9: zoznam tabov sa cita z DOM — natvrdo pisane pole by po odstraneni
  # tabu skoncilo na `el(null).classList` (TypeError) a okno by ostalo cierne.
  NxTest.assert(ST1B_PROD_JS.include?('function prodTabIds'), 'zoznam tabov sa odvodzuje z DOM')
  NxTest.assert(ST1B_PROD_JS.include?("if (b) b.classList.toggle('on', k === t);"),
                'a prepinac znesie chybajuce tlacidlo')
  NxTest.assert(ST1B_PROD_HTML.include?('id="prodTabs"'), 'kontajner tabov ma ID, z ktoreho sa cita')
end

NxTest.test('ST-1a: `price()` v okne Vyroba OSTAVA — pouziva ho tab Kovanie (audit #9)') do
  NxTest.assert(ST1B_PROD_JS.include?('function price(v)'), 'helper zije dalej')
  NxTest.assert(ST1B_PROD_JS.include?('price(r.price_eur_vat)'), 'a naozaj sa pouziva')
  %w[renderRows renderSheets renderEdging edgesLabel plateCell budgetRowMap budgetSumRow].each do |fn|
    NxTest.refute(ST1B_PROD_JS.include?("function #{fn}"),
                  "mrtvy helper #{fn} sa mal odstranit spolu s tabmi")
  end
  # Payload sa NEMENI: globalny BOM cita budget.js aj tab Kontrola/Kovanie.
  NxTest.assert(ST1B_PROD_RB.include?('rows: bom[:rows], sheets: bom[:sheets], edging: bom[:edging]'),
                'push_state okna Vyroba nesie rovnake polia ako pred davkou')
end

# --- 7) lifecycle okna a refresh cesty (audit #10, #14) ----------------------

NxTest.test('ST-1a: okno sa po zatvoreni vynuluje a JS chyby idu do logu (audit #14)') do
  NxTest.assert(ST1B_STUDIO_RB.include?('@dialog.set_on_closed { @dialog = nil }'),
                'referencia na mrtve okno by tichla na vynimke pri kazdom pushi')
  NxTest.assert(ST1B_STUDIO_RB.include?("add_action_callback('js_error')"),
                'JS chyby okna sa daju precitat (konzolu HtmlDialogu nevidno)')
  NxTest.assert(ST1B_STUDIO_HTML.include?('js/errors.js'), 'okno nacitava errors.js')
  NxTest.assert(ST1B_STUDIO_RB.include?("Engine.register_dialog_fit(dlg, 'studio')"),
                'spolocny boot hook = tema (UI-01) + dorovnanie velkosti (D-77)')
end

NxTest.test('ST-1a: Studio je vo VSETKYCH piatich refresh cestach (audit #10)') do
  cesty = {
    'core/scale_observer.rb' => 'StudioDialog.on_model_changed(model)',
    'ui/materials_dialog.rb' => 'StudioDialog.refresh_if_open',
    'ui/supplier_settings_dialog.rb' => 'StudioDialog.refresh_if_open',
    'ui/hardware_catalog_dialog.rb' => 'StudioDialog.on_model_changed(model)',
    'ui/production_dialog.rb' => 'StudioDialog.refresh_if_open'
  }
  cesty.each do |rel, needle|
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
    NxTest.assert(src.include?(needle),
                  "#{rel} neobnovuje Studio — okno by drzalo stare cisla")
  end
end

NxTest.test('ST-1a: D-51 trojica rozmerov okna si zodpoveda (obsah 1060 × 640)') do
  fit = ST1B_STUDIO_HTML[/NX_FIT_MIN = \{ w: (\d+), h: (\d+) \}/]
  NxTest.assert(!fit.nil?, 'studio.html deklaruje obsahove minimum')
  w = Regexp.last_match(1).to_i
  h = Regexp.last_match(2).to_i
  NxTest.assert_equal([1060, 640], [w, h], 'obsahovy viewport podla kontraktu D-51')
  dlg_w = ST1B_STUDIO_RB[/width: (\d+),/, 1].to_i
  min_w = ST1B_STUDIO_RB[/min_width: (\d+),/, 1].to_i
  NxTest.assert(dlg_w > w && dlg_w - w <= 24,
                "vonkajsia sirka #{dlg_w} musi byt obsah #{w} + ramik (~16 px)")
  NxTest.assert_equal(dlg_w, min_w, 'min_width drzi tu istu sirku (okno sa neda stiahnut pod obsah)')
end

# --- 8) vstupne body (audit #2) ---------------------------------------------

NxTest.test('ST-1a: toolbar aj rail vedu do ŠTÚDIA; Výroba ostava v Extensions menu') do
  NxTest.assert(ST1B_MAIN_RB.include?("UI::Command.new('Štúdio') { StudioDialog.show }"),
                'toolbar tlacidlo Štúdio otvara Studio')
  NxTest.assert(ST1B_MAIN_RB.include?("menu.add_item('Výroba (dočasné — presúva sa do Štúdia)')"),
                'okno Vyroba ostava dostupne z menu — dokial nezanikne (ŠT-1c)')
  panel_html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  rail = panel_html[/<button[^>]*id="railStudio".*?<\/button>/m].to_s
  NxTest.assert(rail.include?('onclick="openStudio()"'),
                'rail „Štúdio" otvara Studio, nie okno Vyroba')
  NxTest.assert(ST1B_MAIN_RB.include?("Sketchup.require 'noxun_engine/ui/studio_dialog'"),
                'loader okno nacitava')
end

NxTest.test('ST-1a: ceruzka riadku zdvihne Inspector — a NIC v modeli nezapise') do
  body = ST1B_CORE_RB[/def do_select\(model, data.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'zdielane telo vyberu sa nasiel')
  NxTest.assert(body.include?("data['focus_inspector'] == true && Panel.dialog_alive?"),
                'Inspector sa zdviha LEN ked zije (nikdy sa neotvara sam)')
  NxTest.assert(body.include?('Panel.bring_to_front'), 'a robi to jedna metoda panela')
  NxTest.assert(body.include?('Panel.suspend_selection_sync'),
                'zmena vyberu bezi pod suspend guardom (vzor B2)')
  NxTest.assert(body.include?('Panel.push_selected(model, dedup: false)'),
                'refresh panela BEZ dedup ticku — dedup MENI model (lekcia D-103)')
  NxTest.refute(body.include?('start_operation'), 'vyber nie je operacia = ziadny krok Spat')
  NxTest.assert(ST1B_STUDIO_JS.include?("data-act=\"edit\""), 'ceruzka je vlastna akcia riadku')
  NxTest.assert(ST1B_STUDIO_JS.include?("data-act=\"eye\""), 'oko tiez')
  # Š3: riadok KUSOVNIKA ma PRAVE DVE hover akcie — tretia („detail") pride az
  # s D-94. Riadok KONTROLY (ŠT-1b) ma navyse KONTEXTOVU opravu, preto sa
  # pocita len markup tabulky kusovnika.
  parts = ST1B_STUDIO_JS[/function partsTable.*?\n  \}/m].to_s
  NxTest.assert_equal(2, parts.scan(/data-act="/).length,
                      'Š3: PRAVE DVE hover akcie v Kusovníku — tretia („detail") pride az s D-94')
end
