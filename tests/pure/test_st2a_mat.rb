# frozen_string_literal: true
# ŠT-2a — sekcia MATERIÁLY v okne Štúdio: KANÁL (server) a jeho hranice.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. `mat` je ZIVA sekcia — a zaroven premostenie `mat` MUSI zaniknut.
#      Keby ostali oba, jeden klik by otvaral okno a druhy sekciu; dve UI nad
#      tym istym katalogom, kazde s inym stavom.
#   2. KATALOGOVE ECHO nesmie zdvihnut generaciu okna. Keby ju zdvihlo, oprava
#      ceny v katalogu by zneplatnila rozkliknuty riadok Kusovnika a rozrobeny
#      export inej sekcie — a pouzivatel by dostal „Dáta okna sa medzitým
#      zmenili" po tom, co iba prepisal cislo.
#   3. Payload sekcie sa NESMIE dopytat modelu DRUHYKRAT. Okno Materialy malo
#      vlastny `Ids` sken (`model_decor_usage`); v Studiu by bezal pri KAZDOM
#      prepocte kusovnika navyse. Pocty preto vznikaju z UZ zozbieraneho BOM.
#   4. Telo akcii katalogu ostava v `MaterialsDialog` (modul sa NEPREMENUVA) —
#      sekcia je len DALSI vstup a odpoved si necha presmerovat. Druha kopia
#      handlerov by sa casom rozisla a jedno UI by zapisovalo inak nez druhe.
#   5. `@ready` — CEF zahadzuje `execute_script` poslany pred nacitanim HTML.
#      Priznak musi vzniknut aj zaniknut na spravnych miestach, inak na nom
#      ŠT-2b postavi odlozenu poziadavku, ktora sa bude tvarit ziva v mrtvom okne.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
# Telo akcii katalogu zije v `MaterialsDialog` (audit #21) — sada overuje
# kontrakt OBOCH modulov, takze ho headless potrebuje tiez. Parse-time tu
# ziadne SketchUp API nie je (vsetko je vnutri metod).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog') if NxTest.headless?

ST2A_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
ST2A_MAT_RB    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog.rb'),
                           encoding: 'UTF-8')
ST2A_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
ST2A_SHELL_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'),
                           encoding: 'UTF-8')
ST2A_MAT_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'proj_materials.js'),
                           encoding: 'UTF-8')
ST2A_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# Zdrojak BEZ komentarov. Zanik okna sa overuje na KODE — v komentaroch mena
# zaniknutych veci ZAMERNE ostavaju (vysvetluju, co a preco zmizlo).
ST2A_MAT_CODE    = ST2A_MAT_RB.lines.reject { |l| l.strip.start_with?('#') }.join
ST2A_STUDIO_CODE = ST2A_STUDIO_RB.lines.reject { |l| l.strip.start_with?('#') }.join
ST2A_MAT_JS_CODE = ST2A_MAT_JS.lines.reject { |l| l.strip.start_with?('//') }.join

# --- 1) `mat` je sekcia a premostenie zaniklo --------------------------------

NxTest.test('ŠT-2a: `mat` je ZIVA sekcia vo VSETKYCH TROCH zrkadlach') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = ST2A_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = ST2A_SHELL_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert(rb.include?('mat'), 'Ruby je autorita zoznamu sekcii')
  NxTest.assert_equal(rb, js, 'studio.js je jeho zrkadlo')
  NxTest.assert_equal(rb, shell, 'a shell.js (deep-link z panela) tiez')
end

NxTest.test('ŠT-2a: premostenie `mat` ZANIKLO — navigacia uz neotvara satelit') do
  st = Noxun::Engine::StudioDialog
  NxTest.refute(st::WINDOW_BRIDGES.key?('mat'),
                'jeden kluc nesmie byt zaroven sekcia aj premostenie')
  NxTest.assert(st::BRIDGE_STATUS['mat'].to_s.empty?, 'a nesmie mat ani hlasku premostenia')
  nav = ST2A_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  mat_item = nav[/\{ id: 'mat'.*?\},/m].to_s
  NxTest.assert(!mat_item.empty?, 'polozka navigacie sa nasla')
  NxTest.refute(mat_item.include?('bridge:'), 'polozka Materiály uz nie je premostenie')
  NxTest.refute(mat_item.include?('disabled:'), 'a nie je ani neaktivna')
end

NxTest.test('ŠT-2b: okno Materialy ZANIKLO — a s nim VSETKY jeho vstupy') do
  # Zaniknut musi CELE, nie len z navigacie: kym existuje HTML, menu polozka
  # alebo panelove tlacidlo, ziju nad jednym katalogom dve UI s roznym stavom.
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'proj_materials.html')),
                'HTML satelitu je zmazane')
  %w[DLG_KEY ensure_dialog register_callbacks dialog_js UI::HtmlDialog].each do |gone|
    NxTest.refute(ST2A_MAT_CODE.include?(gone), "#{gone} je z materials_dialog.rb PREC")
  end
  NxTest.refute(ST2A_STUDIO_CODE.include?('mat_open_window'),
                'premostenie zo sekcie do okna zaniklo spolu s oknom')
  NxTest.assert(ST2A_STUDIO_RB.include?("cb(dlg, 'mat_leave')"),
                'namiesto neho hlasi klient ODCHOD zo sekcie (zrusi bezaci Demos fetch)')
  NxTest.refute(Noxun::Engine::StudioDialog.const_defined?(:MAT_BRIDGE_STATUS),
                'a jeho hlasky tiez')
  NxTest.refute(ST2A_MAT_JS_CODE.include?('mdBridgeToWindow'), 'klient uz nema kam premostovat')
  NxTest.assert(ST2A_MAT_JS_CODE.include?('function matOnLeaveSection()'),
                'namiesto toho hlasi odchod zo sekcie a zavrie modaly')
  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  NxTest.assert(main.include?("menu.add_item('Materiály projektu') { StudioDialog.show(open_section: 'mat') }"),
                'zauzivana polozka menu ostava, ale otvara SEKCIU')
  NxTest.refute(main.include?('MaterialsDialog.show'), 'okno sa uz nikde neotvara')
  panel_rb = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
                     .lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.refute(panel_rb.include?('open_project_materials'),
                'panelovy callback satelitu zanikol — tlacidlo ide deep-linkom openStudio')
  panel_html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  NxTest.assert(panel_html.include?(%q(onclick="openStudio('mat')")),
                'tlacidlo „Materiály projektu…" vedie do sekcie')
end

# --- 2) generacny kontrakt kanala (audit #4) ---------------------------------

NxTest.test('ŠT-2a (audit #4): katalogove echo NEZDVIHA generaciu okna') do
  body = ST2A_STUDIO_RB[/def push_mat_catalog.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'echo ma vlastnu cestu (vzor push_vepo_bar)')
  NxTest.assert(body.include?('NX.setMatCatalog'), 'posiela LEN katalog do klienta')
  NxTest.refute(body.include?('@generation'), 'a generacie sa NEDOTYKA')
  NxTest.refute(body.include?('fresh_collect'), 'ani model neprepocitava')
  # Plny push po zapise do katalogu ide ZAMERNE bez zdvihu generacie.
  after = ST2A_MAT_RB[/def after_catalog_change.*?\n        end\n/m].to_s
  NxTest.assert(after.include?('StudioDialog.refresh_if_open(bump: false)'),
                'katalogovy zapis nemeni model — pending klik ostava platny')
  NxTest.assert(after.include?('StudioDialog.push_mat_catalog(catalog_payload)'),
                'a sekcia dostane cerstvy katalog echom')
  # ŠT-2b: druhe UI neexistuje, takze aj echo je JEDNO.
  NxTest.refute(after.include?('dialog_js('), 'vetva satelitneho okna je PREC')
  code = after.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(1, code.scan(/catalog_payload/).length,
                      'payload sa stava RAZ — druhy by znamenal druhy vypocet row_rev')
end

NxTest.test('ŠT-2a: `refresh_if_open` vie oba rezimy a plny push je default') do
  NxTest.assert(ST2A_STUDIO_RB.include?('def refresh_if_open(bump: true)'),
                'ostatne refresh cesty (nastavenia, prepocet cien) ostavaju s bumpom')
  NxTest.assert(ST2A_STUDIO_RB.include?('push_state(bump: bump)'), 'rezim sa naozaj preposiela')
end

NxTest.test('ŠT-2a (audit #4): zapis do MODELU dostane PLNY push AJ so zdvihom') do
  # Dve cesty `materials_dialog.rb` menia model (prestavaju skrinky) — po nich
  # su v Studiu naozaj INE cisla a stary klik sa uz odmietnut MA.
  helper = ST2A_MAT_RB[/def refresh_studio_after_model_write.*?\n        end\n/m].to_s
  NxTest.assert(helper.include?('StudioDialog.refresh_if_open'), 'plny push s bumpom')
  NxTest.refute(helper.include?('bump: false'), 'zmena modelu generaciu ZDVIHNUT musi')
  proj = ST2A_MAT_RB[/def handle_set_project_material.*?\n        end\n/m].to_s
  NxTest.assert(proj.include?('refresh_studio_after_model_write'),
                'projektova predvolba prestavia skrinky — Studio to musi vediet')
  # ŠT-2b: `push_state_both` (ten isty stav do DVOCH UI) zanikol spolu s druhym
  # UI — predvolby nesie `mat` payload Studia z `refresh_studio_after_model_write`.
  uni = ST2A_MAT_RB[/def handle_replace_uni_apply.*?\n        end\n/m].to_s
  NxTest.assert(uni.include?('refresh_studio_after_model_write'),
                'to iste plati pre apply „Nahradiť UNI…"')
  %w[push_state_both state_payload model_decor_usage].each do |gone|
    NxTest.refute(ST2A_MAT_CODE.include?(gone),
                  "#{gone} zanikol s oknom — druhy sken modelu uz sekcia nepotrebuje")
  end
  # Nota #20: poradie proti bliknutiu jantaru — AZ ZA refreshom Inspectora.
  NxTest.assert(proj.index('Panel.push_selected') < proj.index('refresh_studio_after_model_write'),
                'push ide AZ ZA push_selected (dedup by inak zozltil prave prepocitane okno)')
end

# --- 3) payload sekcie: ziadny druhy sken modelu (audit #15) ------------------

NxTest.test('ŠT-2a (audit #15): `used` vznika z UZ zozbieraneho kusovnika') do
  push = ST2A_STUDIO_RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  NxTest.assert(push.include?('mat: mat_payload(model, collected)'),
                'payload sekcie ide z TOHO ISTEHO zberu ako kusovnik')
  NxTest.refute(push.include?('model_decor_usage'),
                'druhy sken modelu (Ids) v prepocte Studia NESMIE byt')
  used = ST2A_STUDIO_RB[/def mat_used\(collected\).*?\n        end\n/m].to_s
  NxTest.assert(used.include?('collected[:records]'), 'pocty sa ratajú z BOM zaznamov')
  NxTest.assert(used.include?('Materials.decor_key_by_material_id'),
                'kluc skupiny podava katalog — JS ani Studio si ho neskladaju')
  NxTest.assert(Noxun::Engine::Materials.respond_to?(:decor_key_by_material_id),
                'helper je verejny (zdielaju ho okno aj sekcia)')
end

NxTest.test('ŠT-2a (audit #15): CELY katalog chodi LEN pri prvom pushi a po prepnuti modelu') do
  pay = ST2A_STUDIO_RB[/def mat_payload\(model, collected\).*?\n        end\n/m].to_s
  NxTest.assert(pay.include?("out['catalog'] = MaterialsDialog.catalog_payload if @mat_full_pending"),
                'inak by sa `row_rev` kazdeho zaznamu pocital pri KAZDOM prepocte kusovnika')
  # Review #1: zapadka sa gasi LEN ked katalog v odoslanom payloade REALNE bol.
  # Holy `if sent` by pri zlyhanom `mat_payload` (rescue -> nil) nechal sekciu
  # NAVZDY prazdnu a bez hlasky.
  NxTest.assert(ST2A_STUDIO_RB.include?("@mat_full_pending = false if sent && data[:mat].is_a?(Hash) && data[:mat]['catalog']"),
                'priznak padne AZ ked katalog naozaj odosiel klientovi')
  NxTest.assert(pay.include?("Engine.log_error(e, 'StudioDialog.mat_payload')"),
                'zlyhanie payloadu sekcie sa NEZAMLCUJE — inak niet stopy, preco je prazdna')
  changed = ST2A_STUDIO_RB[/def on_model_changed\(model\).*?\n        end\n/m].to_s
  NxTest.assert(changed.include?('@mat_full_pending = true'),
                'novy dokument = katalog sa posle cely (klient nema ako vediet o cudzich zmenach)')
end

# --- 4) telo akcii ostava v MaterialsDialog (audit #21) ----------------------

NxTest.test('ŠT-2a: akcie katalogu maju JEDINY whitelist a JEDINE telo') do
  md = Noxun::Engine::MaterialsDialog
  NxTest.assert(md.const_defined?(:SECTION_ACTIONS), 'whitelist zije v MaterialsDialog')
  actions = md::SECTION_ACTIONS
  NxTest.assert(actions.frozen?, 'zoznam je uzavrety')
  %w[set_project_material patch_sheet patch_edge add_decor_batch delete_preflight
     restore_pre_schema2].each do |a|
    NxTest.assert(actions.include?(a), "sekcia musi vediet #{a}")
  end
  # ŠT-2b: Demos toky aj „Nahradiť UNI…" su UZ v sekcii — ich zivotnost sa
  # presunula z instancie okna na SESSION token (viz `demos_alive_proc`).
  %w[demos_lookup demos_manual_url demos_apply demos_cancel demos_name_search
     demos_family demos_family_create demos_family_cancel open_search_url
     replace_uni_preview replace_uni_apply].each do |a|
    NxTest.assert(actions.include?(a), "sekcia musi vediet aj #{a}")
  end
  NxTest.refute(ST2A_STUDIO_RB.include?('MAT_ACTIONS = %w['),
                'druhy zoznam v Studiu by sa casom rozisiel — cita sa ten z MaterialsDialog')
  NxTest.assert(ST2A_STUDIO_RB.include?('mat_actions.each { |name| cb(dlg, name)'),
                'callbacky vznikaju Z NEHO')
end

NxTest.test('ŠT-2a (audit #21): odpoved dostane TEN, KTO sa pytal') do
  disp = ST2A_MAT_RB[/def dispatch\(name, payload, sink\).*?\n        end\n/m].to_s
  NxTest.assert(disp.include?('SECTION_ACTIONS.include?(key)'),
                'klient posiela iba meno — co sa smie zavolat, rozhoduje server')
  NxTest.assert(disp.include?('with_client(sink)'), 'a odpoved sa presmeruje na volajuceho')
  wc = ST2A_MAT_RB[/def with_client\(sink\).*?\n        end\n/m].to_s
  NxTest.assert(wc.include?('ensure'),
                'vynimka v handleri nesmie nechat sink viset — dalsia odpoved by odisla do Studia')
  js = ST2A_MAT_RB[/def js\(script\).*?\n        end\n/m].to_s
  NxTest.assert(js.include?('sink.call(script) if sink'), 'sink ma prednost')
  # ŠT-2b: bez sinku (asynchronny Demos emit, refresh cesty zvonku) je jediny
  # mozny adresat okno Studio — vlastne uz neexistuje.
  NxTest.assert(js.include?('studio_js(script)'), 'bez neho ide vsetko do Studia')
  NxTest.assert(ST2A_MAT_RB.include?('StudioDialog.mat_js(script)'),
                'a to VEREJNYM mostom (kanalove `js` Studia je private)')
  # Modul sa NEPREMENUVA (audit #21) — zanika okno, nie serverova autorita.
  NxTest.assert(defined?(Noxun::Engine::MaterialsDialog), 'modul MaterialsDialog zije dalej')
end

NxTest.test('ŠT-2a (review #3): katalogovy zapis Z INSPECTORA ma JEDNU fan-out cestu') do
  # D-41 dovytvorena ABS paska a D-49 automaticky duplak zapisuju do
  # GLOBALNEHO katalogu. Kym si refresh posielali samy, sekcia Materialy
  # o zmene nevedela — a hlavne jej ostal STARY `catalog_rev`, takze jej
  # najblizsi zapis by server odmietol ako „katalóg sa medzitým zmenil".
  sync = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'),
                   encoding: 'UTF-8')
  helper = sync[/def broadcast_catalog_change.*?\n        end\n/m].to_s
  NxTest.assert(helper.include?('MaterialsDialog.after_catalog_change'),
                'jedina cesta je fan-out katalogu')
  NxTest.assert(helper.include?('push_materials'),
                'bez nacitaneho satelitu sa aspon obnovi panel — mlcanie by bolo horsie')
  parts = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts.rb'),
                    encoding: 'UTF-8')
  abs = parts[/def ensure_missing_abs.*?\n        end\n/m].to_s
  NxTest.assert(abs.include?('broadcast_catalog_change'), 'D-41: dovytvorena paska ide cezen')
  NxTest.refute(abs.include?('MaterialsDialog.push_state'),
                'a NIE vlastnym refreshom (ten sekciu obisiel)')
  res = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'resolvers.rb'),
                  encoding: 'UTF-8')
  dup = res[/def resolve_virtual_material.*?\n        end\n/m].to_s
  NxTest.assert(dup.include?('broadcast_catalog_change'), 'D-49: automaticky duplak tiez')
  NxTest.assert_equal(1, dup.scan(/broadcast_catalog_change/).length,
                      'vetva :exists_regular NIC nezapisala — plny fan-out by hlasil zmenu, ktora sa nestala')
end

# --- 5) `@ready` lifecycle (audit #8) ----------------------------------------

NxTest.test('ŠT-2a (audit #8 / review #6): `@ready` naozaj RIADI odosielanie skriptov') do
  # Nestaci, ze priznak existuje — musi mat spotrebitela. Inak je to mrtva
  # premenna, na ktorej ŠT-2b postavi odlozenu poziadavku.
  js = ST2A_STUDIO_RB[/def js\(script\).*?\n        end\n/m].to_s
  NxTest.assert(js.include?('return false unless @ready'),
                'push pred nacitanim HTML sa PRIZNANE zahodi (CEF ho zahodi tak ci tak)')
  NxTest.assert(js.index('return false unless @dialog') < js.index('return false unless @ready'),
                'najprv zive okno, potom pripravenost — poradie guardov')
  ready_cb = ST2A_STUDIO_RB[/cb\(dlg, 'ready'\) do.*?\n          end\n/m].to_s
  NxTest.assert(ready_cb.include?('@ready = true') && ready_cb.include?('push_state'),
                'priznak sa zapina AZ ked HTML naozaj bezi — a PRED prvym pushom')
  NxTest.assert(ready_cb.index('push_state') < ready_cb.index('flush_pending_replace_uni'),
                'ŠT-2b: odlozeny modal „Nahradiť UNI…" az ZA prvym pushom (potrebuje katalog)')
  ensure_dlg = ST2A_STUDIO_RB[/def ensure_dialog.*?\n        end\n/m].to_s
  NxTest.assert(ensure_dlg.include?('@ready = false'),
                'nove okno zacina ako NEPRIPRAVENE (CEF by skript pred nacitanim zahodil)')
  closed = ST2A_STUDIO_RB[/@dialog\.set_on_closed do.*?\n          end\n/m].to_s
  NxTest.assert(closed.include?('@ready = false'),
                'zatvorene okno nie je pripravene — inak by ŠT-2b poslala poziadavku do mrtveho okna')
  NxTest.assert(closed.include?('@mat_full_pending = true'),
                'a dalsie otvorenie musi dostat katalog cely')
end

# --- 6) UI kontrakt sekcie ---------------------------------------------------

NxTest.test('ŠT-2a (audit #2): modaly sekcie ziju MIMO tela sekcie') do
  NxTest.assert(ST2A_STUDIO_HTML.include?('<div id="matModalRoot">'),
                'kotva modalov je vlastna (vzor #nxModalRoot)')
  root = ST2A_STUDIO_HTML[/<div id="matModalRoot">.*?\n<\/div>/m].to_s
  NxTest.assert(root.include?('id="mdRestoreModal"'), 'obnova predmigracnej zalohy')
  NxTest.assert(root.include?('id="mdDeleteModal"'), 'potvrdenie mazania variantu')
  body = ST2A_STUDIO_HTML[/<template id="matBodyTpl">.*?<\/template>/m].to_s
  NxTest.assert(!body.empty?, 'telo sekcie je SABLONA — klonuje sa RAZ')
  NxTest.refute(body.include?('nxmodal'),
                'v tele sekcie nesmie byt ziadny modal — prekreslenie by ho zhodilo')
  NxTest.assert(body.include?('id="mdDecorList"') && body.include?('id="mdDecorForm"'),
                'dlazdice aj batch formular su v tele')
  NxTest.refute(body.include?('id="mdSearch"'),
                'hladanie patri do LISTY sekcie (#17), nie do obsahu')
  NxTest.assert(ST2A_MAT_JS.include?('function matToolsHtml(st)'),
                'listu kresli cista funkcia (testuje ju tests/js/test_st2a_mat.js)')
end

NxTest.test('ŠT-2a: bannery su PRVE riadky obsahu sekcie (#17)') do
  body = ST2A_STUDIO_HTML[/<template id="matBodyTpl">.*?<\/template>/m].to_s
  %w[mdRoBanner mdEdgeBanner mdCutoverBanner].each do |id|
    NxTest.assert(body.include?(%(id="#{id}")), "banner #{id} sa presunul do sekcie")
    NxTest.assert(body.index(%(id="#{id}")) < body.index('id="mdDecorList"'),
                  "#{id} musi byt NAD zoznamom — inak sa o nudzovom rezime dozvies az po skrolovani")
  end
end

NxTest.test('ŠT-2a: cache-bust presunutych skriptov sedi s VERSION') do
  ver = Noxun::Engine::VERSION
  NxTest.assert(ST2A_STUDIO_HTML.include?("js/proj_materials.js?v=#{ver}"),
                'CEF cachuje js — `?v=` musi byt presne VERSION')
  NxTest.assert(ST2A_STUDIO_HTML.include?('window.NX_MAT_SECTION = true'),
                'okno Studio prepina zdielany subor do rezimu SEKCIE')
end
