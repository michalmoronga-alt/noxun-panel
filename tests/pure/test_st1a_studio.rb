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
ST1B_PANEL_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
ST1B_MAIN_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
ST1B_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
ST1B_BUDGET_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'),
                           encoding: 'UTF-8')
ST1B_BRIDGE_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                           encoding: 'UTF-8')
ST1B_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# --- 1) whitelist sekcii + zrkadlo -------------------------------------------

NxTest.test('ST-1a: SECTIONS je whitelist v RUBY a JS je jeho ZRKADLO') do
  rb = ST1B_STUDIO_RB[/SECTIONS = %w\[([a-z ]+)\]/, 1].to_s.split
  js = ST1B_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  # ŠT-1b pridala sekciu Kontrola (`ctrl`) — dovtedy premostenie do okna Vyroba.
  # ŠT-1c PR A pridala Nakup kovania (`buy`) — presun tabu Kovanie 1:1 (Š7).
  # ŠT-1c PR B1 pridala Rozpocet (`budget`) — POSLEDNY tab okna Vyroba.
  NxTest.assert_equal(%w[bom ctrl buy budget offer], rb,
                      'v Studiu ziju sekcie Kusovník, Kontrola, Nákup kovania, Rozpočet a Cenová ponuka')
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
  # ŠT-1c PR A: telo CSV kovania sa prestahovalo do jadra; PR B1 tam presunula
  # aj oba XLSX exporty. VSETKY STYRI teda citaju nazov v ZDIELANOM jadre —
  # dve kopie by sa casom rozisli.
  NxTest.assert_equal(3, ST1B_CORE_RB.scan(/project = project_name\(model\)/).length,
                      'CSV kovania, XLSX rozpoctu aj XLSX cenovej ponuky citaju nazov v jadre')
  # Komentare (ktore o zaniknutej ceste hovoria) sa vynechavaju — hlada sa KOD.
  strip = ->(src) { src.lines.map { |l| l.sub(/#.*$/, '') }.join }
  NxTest.refute(strip.call(ST1B_CORE_RB).include?("data['project']"),
                'zdielane jadro nazov z klienta NECITA')
  [['budget.js', ST1B_BUDGET_JS], ['studio.js', ST1B_STUDIO_JS]].each do |(name, src)|
    NxTest.refute(src.match?(/project:\s*\(/),
                  "#{name} uz nesmie posielat `project:` z DOM (server je autorita)")
  end
  NxTest.assert(ST1B_STUDIO_HTML.include?('id="secbody"') && ST1B_STUDIO_JS.include?("id=\"prjInput\""),
                'editovatelny input zije v liste Kusovnika v Studiu')
end

NxTest.test('ST-1a: merge 18+36 je GLOBALNE nastavenie a chodi v KAZDOM pushi (audit #16)') do
  NxTest.assert(ST1B_CORE_RB.include?("vepo_settings['merge_18_36'] != false"),
                'default je zapnute')
  NxTest.assert(ST1B_CORE_RB.include?('merge = merge_18_36'),
                'export cita merge zo SERVERA, nie z checkboxu')
  NxTest.assert(ST1B_STUDIO_RB.include?('merge_18_36: ProductionCore.merge_18_36'),
                'stav checkboxu je v KAZDOM pushi Studia — cita sa zo SERVERA')
  # SMOKE 22.8.: checkbox sa z listy prestahoval do ROHOVEHO nastavenia VEPO
  # (`vepoMenuHtml`) — pravidlo „hodnota je z payloadu" plati bezo zmeny.
  NxTest.assert(ST1B_STUDIO_JS.include?("(s.merge_18_36 === false ? '' : ' checked')"),
                'checkbox sa NASADZUJE z payloadu (nie z pamate klienta)')
  NxTest.assert(ST1B_STUDIO_JS.include?('NX.setVepoBar') || ST1B_STUDIO_JS.include?('setVepoBar:'),
                'a echo servera ho dorovna aj v otvorenom nastaveni')
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

NxTest.test('ST-1a: export zo Studia ma PLNY flush handshake') do
  # ŠT-1c PR B3: relaye okna Vyroba, s ktorymi sa tvar handshaku porovnaval,
  # ZANIKLI — kontrakt teraz drzia relaye Studia samy (a strazi ho aj to, ze
  # kazdy z nich ma vsetky tri prvky: guard, flush, flush_blocked).
  studio = ST1B_BRIDGE_JS[/studioRelayExport: function\(p\)\{.*?\n    \},/m].to_s
  NxTest.assert(!studio.empty?, 'relay Studia sa nasiel')
  NxTest.refute(ST1B_BRIDGE_JS.include?('productionRelayExport: function(p)'),
                'relay zaniknuteho okna Vyroba je PREC')
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
  NxTest.refute(opts.include?('ProductionDialog'),
                'ŠT-1c PR B3: vetva zaniknuteho okna Vyroba je PREC')
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

NxTest.test('SMOKE 22.8. (1A–1D): LISTA Kusovnika a rohove nastavenie VEPO — kontrakt') do
  kontrakt = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'zdroje', 'ui20', 'UI20_KONTRAKT.md'),
                       encoding: 'UTF-8')
  mockup = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'zdroje', 'ui20', 'mockup_studio.html'),
                     encoding: 'UTF-8')

  # 1B: neaktivne XLSX/CSV placeholdery zanikli vo VSETKYCH TROCH miestach
  # (pravidlo troch miest: kod · kontrakt · mockup) — inak by sa pri porovnani
  # panela s mockupom 1:1 hlasil rozdiel, ktory je v skutocnosti rozhodnutim.
  NxTest.refute(ST1B_STUDIO_JS.include?('XLSX zatiaľ neexistuje'),
                'kod: placeholder XLSX kusovnika je prec')
  NxTest.refute(ST1B_STUDIO_JS.include?('CSV zatiaľ neexistuje'),
                'kod: a placeholder CSV kusovnika tiez')
  NxTest.assert(kontrakt.include?('tlačidlá sa NEZOBRAZUJÚ'),
                'kontrakt Š5 nesie verdikt zo smoke testu 22.8.')
  NxTest.refute(mockup.include?('XLSX kusovník pripravený') || mockup.include?(' XLSX</button>'),
                'mockup: lista Kusovnika uz XLSX/CSV nekresli')

  # 1A: checkbox „18+36 spolu" sa PRESUNUL do rohoveho nastavenia VEPO.
  NxTest.refute(ST1B_STUDIO_JS.include?('class="mergebox"'), 'z listy checkbox zmizol')
  NxTest.refute(ST1B_STUDIO_HTML.include?('.mergebox'), 'a jeho styl v okne neostal mrtvy')
  NxTest.assert(ST1B_STUDIO_JS.include?('function vepoMenuHtml'),
                'nastavenie ma vlastny maly markup (obsah je iny nez 3-stavova kontrola hran)')
  NxTest.assert(ST1B_STUDIO_JS.include?('id="vepoMore" class="cornerzone"'),
                'ale klikaciu zonu ZDIELA s existujucim vzorom (rail + lista Kontroly)')
  NxTest.assert(ST1B_STUDIO_JS.include?('id="mergeChk"'),
                'checkbox zije dalej — len na inom mieste')
  NxTest.assert(ST1B_STUDIO_JS.include?("if (vepoMenuOpen && !t.closest('.vepofly')) vepoMenuClose();"),
                'zatvara ho klik mimo')
  NxTest.assert(ST1B_STUDIO_JS.include?('if (vepoMenuOpen){'), 'aj Escape')
  # Zapis ide EXISTUJUCOU cestou — ziadny druhy kanal na server.
  NxTest.assert_equal(1, ST1B_STUDIO_JS.scan(/sketchup\.studio_set_vepo_opts\(/).length,
                      'zapis nastavenia ma jedinu cestu (`studio_set_vepo_opts`)')
  NxTest.assert(kontrakt.include?('ROHOVÉ NASTAVENIE'), 'kontrakt roh pozna')

  # Review #1: obe menu listy visia na SVOJOM tlacidle (vlastny pozicovaci
  # obal), nie na `.sectools` — inak sa po presune tlacidla od neho odtrhnu.
  NxTest.assert(ST1B_STUDIO_JS.include?('<span class="colfly">'), 'menu stlpcov ma obal')
  NxTest.assert(ST1B_STUDIO_HTML.include?('.colfly { position: relative;'),
                'a obal je pozicovaci kontext')
  colcss = ST1B_STUDIO_HTML[/\.colmenu \{[^}]*\}/m].to_s
  NxTest.assert(colcss.include?('right: 0;'), 'menu je kotvene na tlacidlo, nie na okraj listy')
  NxTest.refute(colcss.include?('right: 12px'), 'stare kotvenie na listu je PREC')
  NxTest.assert(mockup.include?('colfly'), 'mockup drzi ten isty vzor (1:1)')

  # Review #4: obe rohove/rozbalovacie okna maju hlavicku `.mgrp`.
  NxTest.assert(ST1B_STUDIO_JS.include?('<div class="mgrp">Nastavenie VEPO exportu</div>'),
                'nastavenie VEPO ma hlavicku')
  NxTest.assert(ST1B_STUDIO_HTML.include?('.vepomenu .mgrp'), 'a jej styl (klon .colmenu .mgrp)')

  # Review #5: pravidlo pre neaktivne ovladace listy ZANIKLO spolu s poslednym
  # z nich — mrtve CSS sluby vzor, ktory sa uz nekresli.
  NxTest.refute(ST1B_STUDIO_HTML.include?('.sectools [aria-disabled="true"]'),
                'mrtve pravidlo `.sectools [aria-disabled]` je zmazane')

  # Review #7: KAZDA sekcia ma vlastnu cestu k cerstvym cislam. Kontrola bola
  # posledna bez nej — a je to sekcia, kvoli ktorej sa clovek do okna vracia.
  ctrl = ST1B_STUDIO_JS[/if \(studioSec === 'ctrl'\)\{.*?\n    \}/m].to_s
  # Od 22.8. kresli tlacidlo ZDIELANY helper `refreshBtnHtml` (jeden markup pre
  # vsetkych 5 mist) — sekcia si ho pyta aj s vlastnym tooltipom.
  NxTest.assert(ctrl.include?('refreshBtnHtml(staleFlag,'), 'lista Kontroly ma „Obnoviť"')
  NxTest.assert(ctrl.include?('Prepočítať kontrolu z aktuálneho modelu'),
                'a tooltip hovori o KONTROLE')
  NxTest.assert(ST1B_STUDIO_JS.include?("ctrl: 'Prepočítavam kontrolu…'"),
                'aj priebezna hlaska je per sekciu')
  NxTest.assert_equal(1, ST1B_STUDIO_JS.scan(/t\.closest\('#refreshBtn'\)/).length,
                      'vsetky sekcie idu JEDNYM handlerom (ziadna druha serverova cesta)')
  NxTest.assert(mockup.include?('Kontrola prepočítaná z modelu'), 'mockup Kontroly to drzi tiez')

  # Review #8: otvoreny overlay patri sekcii, z ktorej odchadzame.
  NxTest.assert(ST1B_STUDIO_JS.include?('function closeSectionMenus'),
                'zhasnutie overlayov ma JEDNO miesto')
  go = ST1B_STUDIO_JS[/function studioGoSection\(id\)\{.*?\n  \}/m].to_s
  NxTest.assert(go.include?('closeSectionMenus();'), 'prepnutie sekcie ich zhasne')
  NxTest.assert(ST1B_STUDIO_JS[/if \(ST && ST\.open_section.*?\n      \}/m].to_s
                              .include?('closeSectionMenus();'),
                'a deep-link zo servera tiez')

  # 1D: „Projekt" je VSTUP so stitkom, nie popisok medzi tlacidlami.
  NxTest.assert(ST1B_STUDIO_JS.include?('<span class="prjlbl">Projekt</span>'),
                'pole ma viditelny stitok')
  NxTest.assert(ST1B_STUDIO_HTML.include?('.prjbox .prjlbl'), 'a stitok ma svoj styl')
  NxTest.assert(mockup.include?('prjbox'), 'mockup pole Projekt tiez ukazuje')
end

NxTest.test('SMOKE 22.8.: „Prepočítať ceny" prizna stare ceny (projekcia payloadu)') do
  # ZIADEN novy vypocet: `stale` uz v payloade JE (kresli sa z neho chip aj
  # zoznam). Klient ho len premietne na tlacidlo, ktore ten stav riesi.
  NxTest.assert(ST1B_BUDGET_JS.include?('function budPriceBtnHtml'),
                'tlacidlo ma vlastnu cistu funkciu (testuje ju tests/js/test_budget_ui.js)')
  body = ST1B_BUDGET_JS[/function budPriceBtnHtml.*?\n  \}\n/m].to_s
  NxTest.assert(body.include?('budStaleLabel(b && b.stale)'),
                'pocet aj prah beru z UZ EXISTUJUCEHO pasu cenovej cerstvosti')
  NxTest.assert(body.include?('bstalebtn'), 'a menia LEN triedu (farba je v CSS tokene)')
  NxTest.refute(body.match?(/Date|now|age_days\s*>/),
                'ziadny vypocet veku v klientovi — server je autorita')
  # Od 22.8. zdiela pravidlo s jantarovym „Obnoviť" (`.nxstale`) — obe tlacidla
  # hovoria to iste („cisla mozu byt stare"), takze maju aj ten isty vzhlad.
  css = ST1B_STUDIO_HTML[/\.sectools \.ghostbtn\.bstalebtn,[^{]*\{[^}]*\}/m].to_s
  NxTest.assert(css.include?('--nx-warn'), 'farba ide cez jantarove tokeny')
  NxTest.refute(css.match?(/green|--nx-state-green|--nx-ok/),
                'ZIADNA zelena — vyznamove farby ostavaju semaforu Kontroly')
end

NxTest.test('SMOKE 22.8.: „Obnoviť" hlasku VZDY zhodi — nikdy vecne „Prepočítavam…"') do
  # Klient si pred volanim nastavi „Prepočítavam…" (per sekciu) a sam o vysledku
  # nema ako vediet — prepocet bezi na SERVERI. Kym hlasku nikto nezhadzoval,
  # visela v okne aj po dobehnutom prepocte a vyzeralo to ako zamrznute okno.
  NxTest.assert(ST1B_STUDIO_JS.include?("var REFRESH_STATUS = {"),
                'klient hlasku „Prepočítavam…" naozaj nastavuje (per sekciu)')
  NxTest.assert(ST1B_STUDIO_RB.include?("cb(dlg, 'refresh_bom')  { |_p| do_refresh_bom }"),
                'callback uz nevola holy push_state — ma vlastnu cestu s hlaskou')
  body = ST1B_STUDIO_RB[/def do_refresh_bom.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'handler sa nasiel')
  NxTest.assert(body.include?('push_state'), 'USPESNA vetva okno prepocita')
  NxTest.assert(body.include?("set_status('Prepočítané.')"),
                'a HNED za tym zhodi hlasku (echo NX.setStatus)')
  # Review #6: potvrdenie LEN ked payload naozaj odosiel. `js` hlta vynimky
  # `execute_script` a mlci pri mrtvom okne — bez navratovej hodnoty by server
  # potvrdil prepocet, ktory sa ku klientovi nikdy nedostal.
  NxTest.assert(body.include?('return unless push_state'),
                'review #6: „Prepočítané." az po OVERENOM odoslani payloadu')
  jsm = ST1B_STUDIO_RB[/def js\(script\).*?\n        end\n/m].to_s
  NxTest.assert(jsm.include?('return false unless'), 'review #6: `js` prizna mrtve okno')
  NxTest.assert(jsm.match?(/execute_script\(script\)\s*\n\s*true/),
                'review #6: a uspesne odoslanie vracia true')
  NxTest.assert(jsm.match?(/log_error.*\n\s*false\n/),
                'review #6: vynimka konci false (nie tichym nil, ktore by sa citalo ako uspech)')
  push = ST1B_STUDIO_RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  # POSLEDNY VYRAZ metody = jej navratova hodnota. Hlada sa posledny riadok
  # s kodom (komentare a zatvaracie `end` sa vynechavaju). Od jantaroveho
  # „Obnoviť" si vysledok drzi premenna `sent` (medzi nou a returnom sa zapisuje
  # epocha) — PREPOSIELA sa nadalej.
  code = push.lines.map(&:strip).reject { |l| l.empty? || l.start_with?('#') || l == 'end' }
  NxTest.assert(code.include?('sent = js("NX.setStudio(#{data.to_json})")'),
                'review #6: push_state si vysledok `js` odklada')
  NxTest.assert_equal('sent', code.last,
                      'review #6: push_state vysledok `js` PREPOSIELA (posledny vyraz metody)')
  # Rescue vetva: hlaska sa nesmie zaseknut ANI pri vynimke a chyba patri do logu.
  NxTest.assert(body.include?('rescue StandardError => e'), 'ma rescue vetvu')
  NxTest.assert(body.include?("Engine.log_error(e, 'StudioDialog.do_refresh_bom')"),
                'vynimka ide do logu s menom TEJTO cesty')
  NxTest.assert(body =~ /set_status\("Prepočet zlyhal.*?, true\)/,
                'a pouzivatel dostane CHYBOVU hlasku, nie vecne „Prepočítavam…"')
end

# --- 5) premostenia navigacie (audit #2) -------------------------------------

NxTest.test('ST-1a: premostenia su UZAVRETY whitelist v Ruby, klient posiela iba kluc') do
  st = Noxun::Engine::StudioDialog
  # ŠT-1b: `ctrl` uz NIE JE premostenie — Kontrola je ziva sekcia tohto okna.
  # ŠT-1c PR A: to iste plati pre `buy` (Nakup kovania).
  # ŠT-1c PR B1: a pre `budget` (Rozpocet) aj `offer` (nahlad CP je jeho
  # sucastou) — do okna Vyroba uz NEVEDIE ZIADNA polozka navigacie.
  # ŠT-1c PR B3: konstanta PRODUCTION_BRIDGES ZANIKLA spolu s oknom.
  NxTest.refute(st.const_defined?(:PRODUCTION_BRIDGES),
                'premostenia do zaniknuteho okna Vyroba uz neexistuju')
  %w[ctrl buy budget offer].each do |k|
    NxTest.assert(st::BRIDGE_STATUS[k].to_s.empty?,
                  "#{k} je sekcia, nie premostenie — nesmie mat hlasku premostenia")
  end
  NxTest.assert_equal(%w[bset hw mat rules sup tpl].sort, st::WINDOW_BRIDGES.keys.sort,
                      'satelitne okna otvara sest poloziek')
  # Kazde premostenie ma slovensku hlasku — inak by pouzivatel nevedel, PRECO
  # sa mu otvorilo ine okno.
  (st::WINDOW_BRIDGES.keys + ['about']).each do |k|
    NxTest.assert(!st::BRIDGE_STATUS[k].to_s.empty?, "premostenie #{k} nema hlasku")
  end
  body = ST1B_STUDIO_RB[/def do_bridge.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('WINDOW_BRIDGES.key?(key)'),
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

# --- 6) okno Vyroba ZANIKLO --------------------------------------------------

NxTest.test('ŠT-1c PR B3: okno Vyroba a jeho tri subory su PREC') do
  # Postupny presun: ST-1a vzala taby Kusovník / Materiály / ABS, ŠT-1b tab
  # Kontrola, ŠT-1c PR A tab Kovanie a PR B1 posledny tab Rozpocet. PR B3
  # zmazala prazdnu skrupinu vratane vsetkych vstupnych bodov.
  %w[production_dialog.rb production.html js/production.js].each do |rel|
    NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', *rel.split('/'))),
                  "ui/#{rel} zanikol spolu s oknom")
  end
  NxTest.refute(defined?(Noxun::Engine::ProductionDialog),
                'modul ProductionDialog uz nesmie existovat')
  NxTest.refute(ST1B_MAIN_RB.include?('noxun_engine/ui/production_dialog'),
                'loader ho uz nenacitava')
  NxTest.refute(ST1B_PANEL_RB.include?('ProductionDialog'),
                'panel uz nema ziadny relay do zaniknuteho okna')
end

NxTest.test('ŠT-1c: `price()` odisiel z okna Vyroba do Studia (sekcia Nakup)') do
  # ST-1a ho tu este drzal tab Kovanie (audit #9). ŠT-1c PR A tab presunula,
  # takze helper — a s nim CELY nakupny zoznam — zije v studio.js.
  NxTest.assert(ST1B_STUDIO_JS.include?('function price(v)'), 'helper zije v Studiu')
  NxTest.assert(ST1B_STUDIO_JS.include?('price(r.price_eur_vat)'), 'a naozaj sa pouziva')
  NxTest.assert(ST1B_STUDIO_RB.include?('hardware_sets: hw_exp'),
                'nakupny zoznam dostava Studio (sekcia Nakup kovania)')
end

# --- 7) lifecycle okna a refresh cesty (audit #10, #14) ----------------------

NxTest.test('ST-1a: okno sa po zatvoreni vynuluje a JS chyby idu do logu (audit #14)') do
  # Od jantaroveho „Obnoviť" (22.8.) je v bloku aj odvesenie observera —
  # kontrakt „referencia sa vynuluje" plati nezmeneny.
  closed = ST1B_STUDIO_RB[/@dialog\.set_on_closed do.*?\n          end\n/m].to_s
  NxTest.assert(closed.include?('@dialog = nil'),
                'referencia na mrtve okno by tichla na vynimke pri kazdom pushi')
  NxTest.assert(ST1B_STUDIO_RB.include?("add_action_callback('js_error')"),
                'JS chyby okna sa daju precitat (konzolu HtmlDialogu nevidno)')
  NxTest.assert(ST1B_STUDIO_HTML.include?('js/errors.js'), 'okno nacitava errors.js')
  NxTest.assert(ST1B_STUDIO_RB.include?("Engine.register_dialog_fit(dlg, 'studio')"),
                'spolocny boot hook = tema (UI-01) + dorovnanie velkosti (D-77)')
end

NxTest.test('ST-1a: Studio je vo VSETKYCH refresh cestach (audit #10)') do
  # ŠT-1c PR B3: piata cesta viedla z okna Vyroba (jeho `price_refresh_after`)
  # — okno zaniklo, prepocet cien riadi Studio samo (`price_refresh_after_proc`
  # vo `studio_dialog.rb`).
  cesty = {
    'core/scale_observer.rb' => 'StudioDialog.on_model_changed(model)',
    'ui/materials_dialog.rb' => 'StudioDialog.refresh_if_open',
    'ui/supplier_settings_dialog.rb' => 'StudioDialog.refresh_if_open',
    'ui/hardware_catalog_dialog.rb' => 'StudioDialog.on_model_changed(model)'
  }
  cesty.each do |rel, needle|
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
    NxTest.assert(src.include?(needle),
                  "#{rel} neobnovuje Studio — okno by drzalo stare cisla")
    NxTest.refute(src.include?('ProductionDialog'),
                  "#{rel} este obsahuje vetvu zaniknuteho okna Vyroba")
  end
  after = ST1B_STUDIO_RB[/def price_refresh_after_proc.*?\n        end\n/m].to_s
  NxTest.assert(after.include?('MaterialsDialog.push_catalog') && after.include?('Panel.push_materials') &&
                after.include?('HardwareCatalogDialog.push_items'),
                'po prepocte cien dostanu cerstve cisla vsetky okna nad katalogom')
  NxTest.refute(after.include?('ProductionDialog'), 'okrem zaniknuteho okna Vyroba')
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

NxTest.test('ST-1a: toolbar aj rail vedu do ŠTÚDIA; Výroba zmizla aj z Extensions menu') do
  NxTest.assert(ST1B_MAIN_RB.include?("UI::Command.new('Štúdio') { StudioDialog.show }"),
                'toolbar tlacidlo Štúdio otvara Studio')
  # ŠT-1c PR B3: docasna polozka menu „Výroba" zanikla spolu s oknom.
  NxTest.refute(ST1B_MAIN_RB.include?("menu.add_item('Výroba"),
                'okno Vyroba uz z menu neotvara nic — zaniklo')
  NxTest.assert(ST1B_MAIN_RB.include?("menu.add_item('Štúdio') { StudioDialog.show }"),
                'Studio v menu ostava')
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
