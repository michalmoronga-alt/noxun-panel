# frozen_string_literal: true
# ŠT-3c-1 — sekcia ŠABLÓNY (`tpl`) v okne Štúdio: KANÁL (server) a jeho hranice.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. Whitelist akcii sekcie je UZAVRETY. Sablony su GLOBALNA kniznica —
#      akcia, ktora sa tam dostane omylom, ju meni pre VSETKY zakazky naraz.
#   2. PNG kanal sekcie je VLASTNY. Panelovy `push_template_preview` ma guard
#      `dialog_alive?` INSPECTORA a odpoved posiela prijimacu panela; keby si
#      ho sekcia „pozicala", nahlady by v Studiu chodili LEN kym je otvoreny
#      Inspector — a nikto by nevedel preco.
#   3. VYBER sekcia NESLEDUJE (ziadny observer): tlacidla su vzdy aktivne
#      a verdikt dava SERVER pri kliku. Keby sa niekto vratil k `disabled`
#      stavu, tlacidlo by po zatvoreni Inspectora zamrzlo v poslednom stave.
#   4. MAZANIE nesmie mat v callbacku `UI.messagebox` — nativny modal blokuje
#      callback HtmlDialogu a v Studiu by zamrzol cely kanal okna.
#   5. Zanik okna musi byt UPLNY — kym existuje HTML, polozka menu alebo
#      panelovy callback, ziju nad jednou kniznicou dve UI s roznym stavom.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog') if NxTest.headless?

ST3C_TPL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'),
                        encoding: 'UTF-8')
ST3C_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
ST3C_TPL_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'templates.js'),
                        encoding: 'UTF-8')
ST3C_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
ST3C_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# Zdrojak BEZ komentarov — mena zaniknutych veci v komentaroch ZAMERNE ostavaju.
ST3C_TPL_CODE = ST3C_TPL_RB.lines.reject { |l| l.strip.start_with?('#') }.join
ST3C_TPL_JS_CODE = ST3C_TPL_JS.lines.reject { |l| l.strip.start_with?('//') }.join

def st3c_body(name)
  edge = name.end_with?('?', '!') ? '' : '\b'
  ST3C_TPL_RB[/def #{Regexp.escape(name)}#{edge}.*?\n        end\n/m].to_s
end

# --- 1) `tpl` je sekcia, okno ZANIKLO ---------------------------------------

NxTest.test('ŠT-3c-1: `tpl` je ZIVA sekcia vo VSETKYCH TROCH zrkadlach') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = ST3C_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')[
    /var STUDIO_SECTIONS = \[(.*?)\];/m, 1
  ].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert(rb.include?('tpl'), 'Ruby je autorita zoznamu sekcii')
  NxTest.assert_equal(rb, js, 'studio.js je jeho zrkadlo')
  NxTest.assert_equal(rb, shell, 'a shell.js (deep-link `openStudio`) tiez')
end

NxTest.test('ŠT-3c-1: okno Šablóny ZANIKLO — a s nim VSETKY jeho vstupy') do
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates.html')),
                'HTML satelitu je zmazane')
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'templates_dialog.js')),
                'a jeho JS tiez (sekcia ma vlastny `js/templates.js`)')
  %w[DLG_KEY ensure_dialog register_callbacks UI::HtmlDialog @dialog].each do |gone|
    NxTest.refute(ST3C_TPL_CODE.include?(gone), "#{gone} je z templates_dialog.rb PREC")
  end
  NxTest.refute(ST3C_TPL_CODE.match?(/def show\b/), 'a `show` tiez')
  st = Noxun::Engine::StudioDialog
  NxTest.refute(st::WINDOW_BRIDGES.key?('tpl'),
                'jeden kluc nesmie byt zaroven sekcia aj premostenie')
  NxTest.assert(st::BRIDGE_STATUS['tpl'].to_s.empty?, 'a nesmie mat ani hlasku premostenia')
  nav = ST3C_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  item = nav[/\{ id: 'tpl'.*?\}/m].to_s
  NxTest.assert(!item.empty?, 'polozka navigacie sa nasla')
  NxTest.refute(item.include?('bridge:'), 'polozka Šablóny uz nie je premostenie')

  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  NxTest.assert(main.include?("menu.add_item('Šablóny') { StudioDialog.show(open_section: 'tpl') }"),
                'zauzivana polozka menu ostava, ale otvara SEKCIU')
  NxTest.refute(main.include?('TemplatesDialog.show'), 'okno sa uz nikde neotvara')
  panel_rb = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
                  .lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.refute(panel_rb.include?('open_templates'),
                'panelovy callback satelitu zanikol — tlacidlo ide deep-linkom openStudio')
  panel_html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  NxTest.assert(panel_html.include?(%q(onclick="openStudio('tpl')")),
                'tlacidlo spravy sablon vo vkladacej karte vedie do sekcie')
  mat_js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'materials.js'), encoding: 'UTF-8')
  NxTest.refute(mat_js.include?('openTemplatesDialog'), 'a jeho JS obal tiez zanikol')
end

# --- 2) whitelist akcii sekcie ----------------------------------------------

NxTest.test('ŠT-3c-1: akcie sekcie maju JEDINY whitelist a JEDINE telo') do
  td = Noxun::Engine::TemplatesDialog
  NxTest.assert(td.const_defined?(:SECTION_ACTIONS), 'whitelist zije v TemplatesDialog')
  actions = td::SECTION_ACTIONS
  NxTest.assert(actions.frozen?, 'zoznam je uzavrety')
  NxTest.assert_equal(%w[tpl_apply tpl_delete tpl_capture tpl_rename tpl_preview], actions,
                      'tri akcie okna + premenovanie (ŠT-3c-2) + VLASTNY PNG kanal sekcie — nic viac')
  NxTest.refute(actions.include?('tpl_save'),
                'ukladanie sa do sekcie NEPRENIESLO (jediny vstup je mini-modal Inspectora)')
  NxTest.refute(actions.include?('ready'),
                'Studio registruje callbacky pod TYMI ISTYMI menami — `ready` by prepisal jeho vlastny')
  run = st3c_body('run_section_action')
  actions.each { |a| NxTest.assert(run.include?("when '#{a}'"), "#{a} ma telo") }
  # Ziadne meno sa nesmie zrazit s vlastnymi callbackmi Studia ani s inou sekciou.
  own = ST3C_STUDIO_RB.scan(/cb\(dlg, '([a-z_]+)'\)/).flatten
  NxTest.assert_equal([], actions & own, 'mena akcii sa nesmu zrazit s callbackmi Studia')
  %w[MaterialsDialog HardwareCatalogDialog RulesDialog].each do |mod|
    other = Noxun::Engine.const_get(mod)::SECTION_ACTIONS
    NxTest.assert_equal([], actions & other, "ani s akciami sekcie #{mod}")
  end
  NxTest.assert(ST3C_STUDIO_RB.include?('tpl_actions.each { |name| cb(dlg, name)'),
                'callbacky vznikaju Z NEHO')
  NxTest.refute(ST3C_STUDIO_RB.include?('TPL_ACTIONS = %w['),
                'druhy zoznam v Studiu by sa casom rozisiel')
end

NxTest.test('ŠT-3c-1: `dispatch` NEPUSTI neznamu akciu ani vynimku bez slova') do
  got = []
  Noxun::Engine::TemplatesDialog.dispatch('tpl_totalne_vymyslena', '{}', ->(s) { got << s.to_s })
  NxTest.assert(got.first.to_s.include?('Neznáma akcia'),
                'neznama akcia sa odmietne NAHLAS (klient inak caka navzdy)')
  disp = st3c_body('dispatch')
  NxTest.assert(disp.include?('SECTION_ACTIONS.include?(key)'),
                'klient posiela iba meno — co sa smie zavolat, rozhoduje server')
  NxTest.assert(disp.include?('with_client(sink)'), 'a odpoved sa presmeruje na volajuceho')
  wc = st3c_body('with_client')
  NxTest.assert(wc.include?('ensure'),
                'vynimka v handleri nesmie nechat sink viset — dalsia odpoved by odisla cudziemu')
end

# --- 3) PNG kanal sekcie (audit N24/N26) ------------------------------------

NxTest.test('ŠT-3c-1 (N26): sekcia ma VLASTNY PNG kanal — panelovy sa NEPOZICIAVA') do
  body = st3c_body('handle_preview')
  NxTest.assert(!body.empty?, 'kanal existuje')
  NxTest.assert(body.include?('TemplatePreviews.data_uri(kind, name)'),
                'PNG cita ta ista autorita (limit 64 kB + magic bytes su V NEJ)')
  NxTest.assert(body.include?('TPL.setPreview'), 'a odpoved ide prijimacu SEKCIE')
  NxTest.refute(body.include?('NX.setTemplatePreview'),
                'nikdy prijimacu PANELA — ten patri Inspectoru')
  NxTest.refute(body.include?('dialog_alive?'),
                'a bez guardu Inspectora (kvoli nemu sa panelova cesta pouzit NEDALA)')
  NxTest.assert(body.include?("data['rev'].to_s"),
                'revizia sa vracia SPAT nezmenena — klient si odpoved priradi k spravnej verzii')
  NxTest.assert(body.include?('KINDS.include?(kind)'), 'druh je z uzavreteho zoznamu')
  # A panelova cesta ostava NEDOTKNUTA (Inspector ju pouziva dalej).
  sync = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'), encoding: 'UTF-8')
  NxTest.assert(sync.include?('def push_template_preview'), 'panelovy kanal zije dalej')
  NxTest.assert(sync[/def push_template_preview.*?\n        end\n/m].to_s.include?('dialog_alive?'),
                'aj so svojim guardom Inspectora')
end

# --- 4) vyber, guardy a zapisove cesty --------------------------------------

NxTest.test('ŠT-3c-1 (N27): sekcia vyber NESLEDUJE — verdikt dava SERVER pri kliku') do
  NxTest.refute(ST3C_TPL_CODE.include?('def on_selection_changed'),
                'observerova vetva zanikla s oknom (zila z `Panel.push_selected`)')
  panel_sync = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'),
                         encoding: 'UTF-8')
  NxTest.refute(panel_sync.include?('TemplatesDialog.on_selection_changed'),
                'a panel ju uz nevola')
  pay = st3c_body('tpl_payload')
  NxTest.refute(pay.include?('selected_cab') || pay.include?('find_cabinet'),
                'payload NENESIE vyber — bez observera by aj tak zastaral')
  apply = st3c_body('handle_apply')
  # Review #225: vyber sa cita PRIAMO a musi byt PRAVE JEDEN (detail v sade nizsie).
  NxTest.assert(apply.include?('Panel.selected_cabinets(model)'), 'vyber sa hlada CERSTVO pri kliku')
  NxTest.assert(apply.include?('Označ v modeli práve jednu'), 'a chybajuci vyber sa POVIE')
  NxTest.assert(apply.include?('tpl_type != cab_type'), 'typovy guard je SERVEROVY')
  NxTest.assert(apply.index('tpl_type != cab_type') < apply.index('rebuild_many'),
                'a stoji PRED prestavbou')
  NxTest.refute(apply.include?('push_state'), 'okenny `push_state` zanikol')
  js = ST3C_TPL_JS_CODE
  NxTest.refute(js.include?('disabled'),
                'klient tlacidla NEZNEAKTIVNUJE — mrtve tlacidlo bez vysvetlenia je zakazane (D-78)')
end

NxTest.test('ŠT-3c-1 (N28): mazanie NEMA nativny modal — potvrdenie je D-15') do
  del = st3c_body('handle_delete')
  NxTest.refute(del.include?('UI.messagebox'),
                'nativny modal v callbacku HtmlDialogu by zamrzol kanal okna')
  NxTest.refute(ST3C_TPL_CODE.include?('UI.inputbox'), 'a inputbox uz v module nie je vobec')
  NxTest.assert(ST3C_TPL_JS.include?('NXModal.open('), 'potvrdzuje D-15 modal na klientovi')
  NxTest.assert(ST3C_TPL_JS.include?("okLabel: 'Zmazať'"), 'a hovori, co sa stane')
  NxTest.assert(ST3C_TPL_JS.include?('danger: true'),
                'destruktivne potvrdenie je CERVENE (UI_DIZAJN), nie zelene')
end

NxTest.test('ŠT-3c-1 (N29): doskove sablony — zobrazit a ZMAZAT, apply/odfotit nie') do
  pay = st3c_body('tpl_payload')
  NxTest.assert(pay.include?("kind: 'cabinet'") && pay.include?("kind: 'board'"),
                'payload nesie OBA druhy — doskove sa v sekcii ZOBRAZUJU')
  del = st3c_body('handle_delete')
  NxTest.assert(del.include?('TemplateStore.delete(kind, name)'),
                'mazanie ide podla PODANEHO druhu (prva sprava doskovych)')
  NxTest.assert(del.include?('KINDS.include?(kind)'), 'ale len z uzavreteho zoznamu')
  apply = st3c_body('handle_apply')
  NxTest.assert(apply.include?("TemplateStore.find('cabinet', name)"),
                'apply ostava VYHRADNE korpusovy (serverovy guard)')
  # Klient doskam akcie NEKRESLI (nie disabled — vobec).
  tile = ST3C_TPL_JS[/function tplTileHtml\(tp, kind, idx\)\{.*?\n  \}/m].to_s
  NxTest.assert(tile.include?("var isCab = kind === 'cabinet'"), 'dlazdica vetvi podla druhu')
  NxTest.assert(tile.index('if (isCab)') < tile.index('stpldel'),
                'apply a odfotit su V PODMIENKE, mazanie mimo nej (plati pre oba druhy)')
end

NxTest.test('ŠT-3c-1 (N32): potvrdenie doskovej hovori, ze sa uz NIKDY nevrati') do
  js = ST3C_TPL_JS[/function tplDeleteNote\(kind\)\{.*?\n  \}/m].to_s
  NxTest.assert(js.include?('NIKDY'), 'markerovy seed doskove sablony NEDOPLNA')
  NxTest.assert(js.include?('neobnovujú'), 'a povie sa to recou pouzivatela')
end

NxTest.test('ŠT-3c-1 (N30): „odfotiť" ma ikonu CAMERA, nie oko') do
  tile = ST3C_TPL_JS[/function tplTileHtml\(tp, kind, idx\)\{.*?\n  \}/m].to_s
  NxTest.assert(tile.include?("tplIco('camera')"), 'fotenie = camera')
  NxTest.refute(tile.include?("tplIco('eye')"),
                'oko v celom Studiu znamena „označ v modeli" — dva vyznamy jednej ikony su chyba')
  NxTest.assert(tile.include?("tplIco('trash')"), 'mazanie = kos')
  NxTest.assert(tile.include?("tplIco('box')"), 'pouzitie na skrinku = box')
end

# --- 5) zapis do modelu vs. zmena kniznice ----------------------------------

NxTest.test('ŠT-3c-1: ZAPIS DO MODELU a zmena KNIZNICE maju RÔZNY refresh') do
  apply = st3c_body('handle_apply')
  NxTest.assert(apply.include?('after_model_write(model)'),
                'apply meni MODEL — plny push so zdvihom generacie')
  amw = st3c_body('after_model_write')
  NxTest.assert(amw.include?('Panel.push_selected(model)'), 'panel dostane cerstvy stav')
  NxTest.assert(amw.include?('refresh_if_open(bump: true)'), 'a Studio so zdvihom generacie')
  NxTest.assert(amw.index('Panel.push_selected') < amw.index('StudioDialog'),
                'poradie: NAJPRV panel, az potom Studio')
  ch = st3c_body('after_change')
  NxTest.assert(ch.include?('refresh_if_open'), 'zmena KNIZNICE ide LACNYM echom sekcie')
  NxTest.refute(ch.include?('bump'), 'bez zdvihu generacie — kniznica s kusovnikom nesuvisi')
  NxTest.assert(ch.include?('Panel.push_templates'), 'a quick-pick v paneli dostane novy zoznam')
  echo = st3c_body('refresh_if_open')
  NxTest.assert(echo.include?('TPL.init'), 'echo posiela payload sekcie')
  NxTest.refute(echo.include?('push_state'), 'nikdy plny push okna')
  # A panel po ulozeni sablony vola PRAVE toto echo.
  at = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates.rb'),
                 encoding: 'UTF-8')
  NxTest.assert(at.include?('TemplatesDialog.refresh_if_open'),
                'ulozenie sablony z Inspectora obnovi sekciu')
end

NxTest.test('ŠT-3c-1: payload sekcie chodi plnym pushom a NEPOTREBUJE model') do
  push = ST3C_STUDIO_RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  NxTest.assert(push.include?('tpl: tpl_payload'), 'sekcia dostava stav plnym pushom')
  pay = ST3C_STUDIO_RB[/def tpl_payload\n.*?\n        end\n/m].to_s
  NxTest.assert(pay.include?('TemplatesDialog.tpl_payload'), 'telo je v TemplatesDialog')
  NxTest.assert(pay.include?("Engine.log_error(e, 'StudioDialog.tpl_payload')"),
                'zlyhanie payloadu sa NEZAMLCUJE')
  NxTest.refute(pay.include?('model'),
                'sablony su GLOBALNE — jedina sekcia okna, ktora model nepotrebuje')
end

NxTest.test('ŠT-3c-1: cache-bust a poradie skriptov') do
  ver = Noxun::Engine::VERSION
  NxTest.assert(ST3C_STUDIO_HTML.include?("js/templates.js?v=#{ver}"),
                'CEF cachuje js — `?v=` musi byt presne VERSION')
  NxTest.assert(ST3C_STUDIO_HTML.index('js/studio.js') < ST3C_STUDIO_HTML.index('js/templates.js'),
                'templates.js sa nacitava AZ ZA studio.js — obaluje jeho NX.setStudio')
  NxTest.assert(ST3C_STUDIO_HTML.index('js/nx_modal.js') < ST3C_STUDIO_HTML.index('js/templates.js'),
                'a za nx_modal.js (D-15 potvrdenie mazania)')
end

NxTest.test('ŠT-3c-1: templates.js je PREFIXOVANY — ziadna kolizia so `studio.js`') do
  NxTest.refute(ST3C_TPL_JS_CODE.match?(/^\s{0,2}function (el|esc)\(/),
                'globalne `el`/`esc` su PREC (kolizia so studio.js)')
  NxTest.assert(ST3C_TPL_JS.include?('function tplEl(id)'), 'helpery su prefixovane `tpl*`')
  NxTest.assert(ST3C_TPL_JS.include?('function tplEsc(s)'), 'obidva')
  NxTest.refute(ST3C_TPL_JS_CODE.include?('sketchup.ready('),
                'okno zaniklo — `ready` posiela `studio.js`')
  NxTest.assert(ST3C_TPL_JS.include?('window.TPL = TPL'), 'a `TPL` je globalny prijimac')
end

NxTest.test('ŠT-3c-1 (review #225): apply potrebuje PRAVE JEDNU oznacenu skrinku') do
  apply = st3c_body('handle_apply')
  # `find_cabinet` by pri viacnasobnom vybere TICHO vzal prvy korpus — hlaska
  # „označených je viac" by pritom nikdy neprisla a prestavala by sa skrinka,
  # ktoru pouzivatel nemyslel. Akcia sa pyta „ktoru prestavat", takze odpoved
  # musi byt jednoznacna (rovnaky guard ako `capture_preview_for`).
  NxTest.assert(apply.include?('Panel.selected_cabinets(model)'),
                'vyber sa cita PRIAMO (nie cez `find_cabinet`, ktory doriesi dielec na skrinku)')
  NxTest.refute(apply.include?('Panel.find_cabinet(model)'), 'stara tolerantna cesta je PREC')
  NxTest.assert(apply.include?('cabs.length > 1'), 'viacnasobny vyber ma vlastnu vetvu')
  NxTest.assert(apply.include?('nechaj označenú práve jednu'), 'a povie sa to slovami')
  NxTest.assert(apply.index('cabs.length > 1') < apply.index('rebuild_many'),
                'guard stoji PRED prestavbou')
  cap = st3c_body('handle_capture')
  NxTest.assert(cap.include?('KINDS.include?(kind)'),
                'fotenie validuje druh proti TOMU ISTEMU uzavretemu zoznamu ako mazanie')
end

NxTest.test('ŠT-3c-1 (review #225 P1): ziadny zdrojak nesmie byt pre git BINARNY') do
  # NUL bajt zo suboru spravi binarku — git ho prestane diffovat a KAZDE review
  # ho vidi ako „Bin 0 -> 0 bytes". Guard zije v `test_encoding_guard.rb`; tu sa
  # kontroluje LEN to, ze ho niekto nezrusil (a novy klientsky subor je cisty).
  guard = File.read(File.join(NxTest::ROOT, 'tests', 'pure', 'test_encoding_guard.rb'),
                    encoding: 'UTF-8')
  NxTest.assert(guard.include?('0.chr.b'), 'kontrola NUL bajtu je v encoding guarde')
  js = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'templates.js'))
  NxTest.refute(js.include?(0.chr.b), 'a `js/templates.js` ho uz nema')
end
