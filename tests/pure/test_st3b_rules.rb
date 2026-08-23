# frozen_string_literal: true
# ŠT-3b-1 — sekcia PRAVIDLÁ (`rules`) v okne Štúdio: KANÁL (server) a jeho hranice.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. Whitelist akcii sekcie je UZAVRETY. Pravidla PRESTAVUJU VSETKY korpusy —
#      akcia, ktora sa tam dostane omylom, prepise zakazku.
#   2. BASELINE guard formulara stoji na `model.guid`, NIE na `model.path`.
#      Cesta dva NEULOZENE modely nerozlisi (oba maju prazdny path) — a presne
#      to si priznaval uz povodny komentar okna. Ulozenie nad cudzim dokumentom
#      by ticho prepisalo jeho snapshot.
#   3. Po ZAPISE DO MODELU musia cerstve cisla dostat OBAJA odberatelia (panel
#      aj Studio, so zdvihom generacie) — prestavba vsetkych skriniek meni
#      kusovnik, nakupny zoznam aj rozpocet.
#   4. NO-OP „Doplniť nové predvolené" NESMIE robit ziadny push (lekcia F8 zo
#      ŠT-3a-2): zdvih generacie po akcii, ktora NIC neurobila, zneplatni
#      rozkliknuty riadok Kusovnika a rozrobeny export inej sekcie.
#   5. Zanik okna musi byt UPLNY — kym existuje HTML, polozka menu alebo
#      panelove tlacidlo, ziju nad jednymi pravidlami dve UI s roznym stavom.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog') if NxTest.headless?

ST3B_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
ST3B_RULES_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog.rb'),
                           encoding: 'UTF-8')
ST3B_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
ST3B_SHELL_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'),
                           encoding: 'UTF-8')
ST3B_RULES_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'rules.js'),
                           encoding: 'UTF-8')
ST3B_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# Zdrojak BEZ komentarov — mena zaniknutych veci v komentaroch ZAMERNE ostavaju.
ST3B_RULES_CODE  = ST3B_RULES_RB.lines.reject { |l| l.strip.start_with?('#') }.join
ST3B_STUDIO_CODE = ST3B_STUDIO_RB.lines.reject { |l| l.strip.start_with?('#') }.join
ST3B_RULES_JS_CODE = ST3B_RULES_JS.lines.reject { |l| l.strip.start_with?('//') }.join

# --- 1) `rules` je sekcia, okno ZANIKLO --------------------------------------

NxTest.test('ŠT-3b-1: `rules` je ZIVA sekcia vo VSETKYCH TROCH zrkadlach') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = ST3B_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = ST3B_SHELL_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert(rb.include?('rules'), 'Ruby je autorita zoznamu sekcii')
  NxTest.assert_equal(rb, js, 'studio.js je jeho zrkadlo')
  NxTest.assert_equal(rb, shell, 'a shell.js (deep-link `openStudio`) tiez')
end

NxTest.test('ŠT-3b-1: okno Pravidla kovania ZANIKLO — a s nim VSETKY jeho vstupy') do
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules.html')),
                'HTML satelitu je zmazane')
  %w[DLG_KEY ensure_dialog register_callbacks UI::HtmlDialog @dialog].each do |gone|
    NxTest.refute(ST3B_RULES_CODE.include?(gone), "#{gone} je z rules_dialog.rb PREC")
  end
  NxTest.refute(ST3B_RULES_CODE.match?(/def show\b/), 'a `show` tiez')
  st = Noxun::Engine::StudioDialog
  NxTest.refute(st::WINDOW_BRIDGES.key?('rules'),
                'jeden kluc nesmie byt zaroven sekcia aj premostenie')
  NxTest.assert(st::BRIDGE_STATUS['rules'].to_s.empty?, 'a nesmie mat ani hlasku premostenia')
  nav = ST3B_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  item = nav[/\{ id: 'rules'.*?\},/m].to_s
  NxTest.assert(!item.empty?, 'polozka navigacie sa nasla')
  NxTest.refute(item.include?('bridge:'), 'polozka Pravidlá uz nie je premostenie')
  NxTest.refute(item.include?('disabled:'), 'a nie je ani neaktivna')

  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  NxTest.assert(main.include?("menu.add_item('Pravidlá kovania') { StudioDialog.show(open_section: 'rules') }"),
                'zauzivana polozka menu ostava, ale otvara SEKCIU')
  NxTest.refute(main.include?('RulesDialog.show'), 'okno sa uz nikde neotvara')
  panel_rb = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
                  .lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.refute(panel_rb.include?('open_rules'),
                'panelovy callback satelitu zanikol — tlacidlo ide deep-linkom openStudio')
  panel_html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  NxTest.assert(panel_html.include?(%q(onclick="openStudio('rules')")),
                'tlacidlo „Pravidlá kovania…" vedie do sekcie')
  hw_js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'), encoding: 'UTF-8')
              .lines.reject { |l| l.strip.start_with?('//') }.join
  NxTest.refute(hw_js.include?('openRulesDialog'), 'a jeho JS obal tiez zanikol')
end

NxTest.test('ŠT-3b-1: vetva `RulesDialog.on_model_changed` ZANIKLA (modul nema async behy)') do
  # Na rozdiel od ŠT-3a-2 (katalog kovania) tu NIE JE co rusit — ziadny fetch,
  # ziadny session token. Sekciu obsluzi PLNY push Studia z toho isteho
  # broadcastu, a ten dostane PODANY model (lekcia F4).
  obs = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer.rb'),
                  encoding: 'UTF-8').lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.refute(obs.include?('RulesDialog.on_model_changed'), 'vetva je z broadcastu PREC')
  NxTest.assert(obs.include?('StudioDialog.on_model_changed(model)'),
                'sekciu obsluzi plny push Studia')
  NxTest.refute(ST3B_RULES_CODE.include?('def on_model_changed'),
                'a metoda zanikla s nou (inak by ostala mrtva)')
end

# --- 2) whitelist akcii sekcie ----------------------------------------------

NxTest.test('ŠT-3b-1: akcie sekcie maju JEDINY whitelist a JEDINE telo') do
  rd = Noxun::Engine::RulesDialog
  NxTest.assert(rd.const_defined?(:SECTION_ACTIONS), 'whitelist zije v RulesDialog')
  actions = rd::SECTION_ACTIONS
  NxTest.assert(actions.frozen?, 'zoznam je uzavrety')
  NxTest.assert_equal(%w[save_rules load_global merge_seed], actions,
                      'sekcia vie PRESNE tri akcie okna — nic viac')
  NxTest.refute(actions.include?('ready'),
                'Studio registruje callbacky pod TYMI ISTYMI menami — `ready` by prepisal jeho vlastny')
  NxTest.refute(ST3B_STUDIO_RB.include?('RULES_ACTIONS = %w['),
                'druhy zoznam v Studiu by sa casom rozisiel — cita sa ten z RulesDialog')
  NxTest.assert(ST3B_STUDIO_RB.include?('rules_actions.each { |name| cb(dlg, name)'),
                'callbacky vznikaju Z NEHO')
  # Ziadne meno sa nesmie zrazit s vlastnymi callbackmi Studia ani s inou sekciou.
  own = ST3B_STUDIO_RB.scan(/cb\(dlg, '([a-z_]+)'\)/).flatten
  NxTest.assert_equal([], actions & own, 'mena akcii sa nesmu zrazit s callbackmi Studia')
  %w[MaterialsDialog HardwareCatalogDialog].each do |mod|
    other = Noxun::Engine.const_get(mod)::SECTION_ACTIONS
    NxTest.assert_equal([], actions & other, "ani s akciami sekcie #{mod}")
  end
end

NxTest.test('ŠT-3b-1: odpoved dostane TEN, KTO sa pytal') do
  disp = ST3B_RULES_RB[/def dispatch\(name, payload, sink\).*?\n        end\n/m].to_s
  NxTest.assert(disp.include?('SECTION_ACTIONS.include?(key)'),
                'klient posiela iba meno — co sa smie zavolat, rozhoduje server')
  NxTest.assert(disp.include?('with_client(sink)'), 'a odpoved sa presmeruje na volajuceho')
  wc = ST3B_RULES_RB[/def with_client\(sink\).*?\n        end\n/m].to_s
  NxTest.assert(wc.include?('ensure'),
                'vynimka v handleri nesmie nechat sink viset — dalsia odpoved by odisla cudziemu')
  js = ST3B_RULES_RB[/def js\(script\).*?\n        end\n/m].to_s
  NxTest.assert(js.include?('sink.call(script) if sink'), 'sink ma prednost')
  NxTest.assert(js.include?('studio_js(script)'), 'bez neho ide vsetko do Studia')
  NxTest.assert(ST3B_RULES_RB.include?('StudioDialog.rules_js(script)'),
                'a to VEREJNYM mostom (kanalove `js` Studia je private)')
  NxTest.assert(ST3B_STUDIO_RB.include?('def rules_js(script)'), 'a ten most existuje')
end

NxTest.test('ŠT-3b-1: `dispatch` NEPUSTI neznamu akciu ani vynimku bez slova') do
  rd = Noxun::Engine::RulesDialog
  got = []
  rd.dispatch('rules_totalne_vymyslena', '{}', ->(s) { got << s.to_s })
  NxTest.assert(got.first.to_s.include?('Neznáma akcia'),
                'neznama akcia sa odmietne NAHLAS (klient inak caka navzdy)')
end

# --- 3) baseline guard: model_guid, nie path --------------------------------

NxTest.test('ŠT-3b-1: baseline formulara stoji na `model.guid`, NIE na `model.path`') do
  code = ST3B_RULES_CODE
  NxTest.refute(code.include?('model.path'),
                'cesta dva NEULOZENE modely nerozlisi (oba maju prazdny path)')
  NxTest.refute(code.include?('@baseline_path'), 'stara premenna zanikla')
  guid = ST3B_RULES_RB[/def model_guid\(model\).*?\n        end\n/m].to_s
  NxTest.assert(guid.include?('model.guid'), 'identita dokumentu je guid')
  valid = ST3B_RULES_RB[/def baseline_valid\?\(model\).*?\n        end\n/m].to_s
  NxTest.assert(valid.include?('model_guid(model) != @baseline_guid'), 'guard porovnava guid')
  NxTest.assert(valid.include?('current == @baseline_rules'),
                'a ZHODU aktualnych pravidiel s baseline (chyti undo aj subeznu zmenu)')
  pay = ST3B_RULES_RB[/def rules_payload\(model\).*?\n        end\n/m].to_s
  NxTest.assert(pay.include?('@baseline_guid  = model_guid(model)'),
                'baseline sa obnovi pri KAZDOM zostaveni payloadu (vzor `push_state` okna)')
  NxTest.assert(pay.include?('@baseline_rules = rules'), 'aj s pravidlami')
  NxTest.refute(pay.include?('Sketchup.active_model'),
                'F4: model chodi ARGUMENTOM — inak by sekcia dostala pravidla STAREHO dokumentu')
end

NxTest.test('ŠT-3b-1 (review P2): SERVER overuje `model_guid` Z PAYLOADU') do
  # Druha vrstva k baseline: klient posiela guid z TOHO ISTEHO payloadu,
  # ktorym bol formular naplneny. Kym ho server necital, bolo to MRTVE pole.
  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(save.include?("guid = data['model_guid'].to_s"),
                'guid z payloadu sa naozaj cita')
  NxTest.assert(save.include?('!guid.empty? && guid != model_guid(model)'),
                'a porovnava sa s modelom — TOLERANTNE (prazdny udaj guard neblokuje)')
  guard = save[/if !guid\.empty\?.*?\n          end\n/m].to_s
  NxTest.assert(guard.include?('refresh_studio(bump: false)'),
                'odmietnutie nacita formular nanovo — BEZ zdvihu generacie (nic sa nezapisalo)')
  NxTest.assert(save.index('guid != model_guid(model)') < save.index('rebuild_many'),
                'guard je PRED prestavbou skriniek')
end

NxTest.test('ŠT-3b-1: odmietnuty zapis NIC nezapise a formular sa nacita nanovo') do
  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  head = save[/\A.*?baseline_valid\?\(model\).*?\n          end\n/m].to_s
  NxTest.assert(head.include?('refresh_studio(bump: false)'),
                'formular sa nacita nanovo PLNYM pushom — a BEZ zdvihu generacie (nic sa nezapisalo)')
  NxTest.assert(head.include?('return set_status'), 'a odmietnutie sa povie NAHLAS')
  NxTest.assert(save.index('baseline_valid?(model)') < save.index('rebuild_many'),
                'guard je PRED prestavbou skriniek, nie za nou')
end

# --- 4) refresh po zapise do modelu -----------------------------------------

NxTest.test('ŠT-3b-1: po ZAPISE dostanu cerstve cisla OBAJA odberatelia') do
  helper = ST3B_RULES_RB[/def after_model_write\(model\).*?\n        end\n/m].to_s
  NxTest.assert(helper.include?('Panel.push_selected(model)'),
                'panel — pravidla menia kovanie v sekcii Kovanie Inspectora')
  NxTest.assert(helper.include?('refresh_studio(bump: true)'),
                'Studio so ZDVIHOM generacie — prestavba VSETKYCH korpusov meni kusovnik aj rozpocet')
  NxTest.assert(helper.index('Panel.push_selected') < helper.index('refresh_studio'),
                'poradie: NAJPRV panel, az potom Studio (inak by jantar zozltol hned po prepocte)')
  %w[handle_save handle_merge_seed].each do |m|
    body = ST3B_RULES_RB[/def #{m}(\(payload\))?.*?\n        end\n/m].to_s
    NxTest.assert(body.include?('after_model_write(model)'), "#{m}: ide JEDNOU cestou")
    NxTest.refute(body.include?('push_state'), "#{m}: `push_state` okna zaniklo")
  end
end

NxTest.test('ŠT-3b-1 (lekcia F8): NO-OP „Doplniť nové predvolené" NEROBI ziadny push') do
  body = ST3B_RULES_RB[/def handle_merge_seed.*?\n        end\n/m].to_s
  noop = body[/if added\.empty\? && refreshed\.empty\?.*?\n          end\n/m].to_s
  NxTest.assert(!noop.empty?, 'no-op ma vlastnu vetvu')
  NxTest.assert(noop.include?('return set_status'), 'a konci STATUSOM')
  NxTest.refute(noop.include?('after_model_write'),
                'NIC sa nezmenilo — zdvih generacie by zneplatnil rozkliknuty riadok Kusovnika')
  code = body.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(1, code.scan(/after_model_write/).length,
                      'push je v metode PRAVE RAZ (v uspesnej vetve)')
  NxTest.assert(body.index('added.empty? && refreshed.empty?') < body.index('rebuild_many'),
                'no-op sa rozhodne PRED prestavbou skriniek')
end

# --- 5) payload sekcie -------------------------------------------------------

NxTest.test('ŠT-3b-1: payload sekcie chodi CELY pri kazdom pushi (bez zapadky)') do
  push = ST3B_STUDIO_RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  NxTest.assert(push.include?('rules: rules_payload(model)'),
                'sekcia dostava stav plnym pushom')
  NxTest.refute(ST3B_STUDIO_CODE.include?('@rules_full_pending'),
                'ziadna zapadka — pravidla su maly JSON, druhy kanal by bol drahsi nez payload')
  pay = ST3B_STUDIO_RB[/def rules_payload\(model\).*?\n        end\n/m].to_s
  NxTest.assert(pay.include?('RulesDialog.rules_payload(model)'), 'telo je v RulesDialog')
  NxTest.assert(pay.include?("Engine.log_error(e, 'StudioDialog.rules_payload')"),
                'zlyhanie payloadu sa NEZAMLCUJE')
  rp = ST3B_RULES_RB[/def rules_payload\(model\).*?\n        end\n/m].to_s
  %w[rules source cabinets model_guid].each do |k|
    NxTest.assert(rp.include?("'#{k}'"), "payload nesie `#{k}`")
  end
end

# --- 6) UI kontrakt sekcie ---------------------------------------------------

NxTest.test('ŠT-3b-1: telo sekcie je SABLONA a lista je cista funkcia') do
  body = ST3B_STUDIO_HTML[/<template id="rulesBodyTpl">.*?<\/template>/m].to_s
  NxTest.assert(!body.empty?, 'telo sekcie je SABLONA — klonuje sa RAZ')
  NxTest.assert(body.include?('id="rulesBox"'), 'zoznam pravidiel je v tele')
  NxTest.assert(body.include?('id="rdSrcLine"'), 'aj meta riadok o zdroji pravidiel')
  NxTest.refute(body.include?('id="alsoGlobal"'),
                'checkbox a akcie patria do LISTY sekcie, nie do obsahu')
  NxTest.refute(body.include?('<h1'), 'nazov nesie hlavicka sekcie')
  NxTest.assert(ST3B_RULES_JS.include?('function rulesToolsHtml(st)'),
                'listu kresli cista funkcia (testuje ju tests/js/test_st3b_rules.js)')
  # Review #220 P1: pripojenie tela pri NAVRATE do sekcie NESMIE prekreslit
  # formular — rucne hodnoty ziju len v DOM.
  body_js = ST3B_RULES_JS[/function rulesRenderBody\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(body_js.include?('if (RD_NEEDS_RENDER){'),
                'render je PODMIENENY — nie bezpodmienecny pri kazdom pripojeni')
  NxTest.assert(ST3B_RULES_JS.include?('RD_NEEDS_RENDER = false;'),
                'priznak gasne AZ ked sa formular naozaj vykreslil')
  apply_js = ST3B_RULES_JS[/function rdApplyState\(r\)\{.*?\n  \}/m].to_s
  NxTest.assert(apply_js.include?('RD_NEEDS_RENDER = true;'),
                'zmena pravidiel NA MODELI priznak zdvihne (dokresli sa aj po navrate)')
  body_fn = ST3B_STUDIO_JS[/function renderBody\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(body_fn.include?("studioSec === 'rules'") && body_fn.include?('rulesRenderBody()'),
                'telo sekcie kresli VYHRADNE rulesRenderBody')
  tools_fn = ST3B_STUDIO_JS[/function renderTools\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(tools_fn.include?("studioSec === 'rules'") &&
                tools_fn.include?('rulesRenderTools(staleFlag)'),
                'a listu rulesRenderTools — s jantarovym priznakom zo `staleFlag`')
end

NxTest.test('ŠT-3b-1: hint sekcie PRIZNAVA, ze ABS skupina pride v 3b-2 (D-78 duchom)') do
  meta = ST3B_STUDIO_JS[/rules: \{ t: 'Pravidlá',.*?\},/m].to_s
  NxTest.assert(meta.include?('ŠT-3b-2'),
                'prazdne miesto po ABS skupine musi mat dovod, inak vyzera ako chyba')
  body = ST3B_STUDIO_HTML[/<template id="rulesBodyTpl">.*?<\/template>/m].to_s
  NxTest.assert(body.include?('ŠT-3b-2'), 'a povie to aj riadok v obsahu')
end

NxTest.test('ŠT-3b-1: rules.js je PREFIXOVANY — ziadna kolizia so `studio.js`') do
  # Subor definoval globalne `el` a `esc` — PRESNE tie, co `studio.js`.
  # V spolocnom okne by si prepisali cudzie funkcie a padlo by nieco uplne ine.
  NxTest.refute(ST3B_RULES_JS_CODE.match?(/^\s{0,2}function (el|esc)\(/),
                'globalne `el`/`esc` su PREC (kolizia so studio.js)')
  NxTest.assert(ST3B_RULES_JS.include?('function rdEl(id)'), 'helpery su prefixovane `rd*`')
  NxTest.assert(ST3B_RULES_JS.include?('function rdEsc(s)'), 'obidva')
  # Prijimace si mena PONECHALI — server posiela presne to, co posielal oknu.
  %w[RD.init RD.setRules RD.setStatus].each do |recv|
    NxTest.assert(ST3B_RULES_RB.include?(recv.split('.').last) ||
                  ST3B_RULES_JS.include?(recv.sub('RD.', '')),
                  "prijimac #{recv} ostava")
  end
  NxTest.assert(ST3B_RULES_JS.include?('window.RD = RD'), 'a `RD` je globalny prijimac')
  NxTest.refute(ST3B_RULES_JS_CODE.include?('sketchup.ready('),
                'okno zaniklo — `ready` posiela `studio.js` (druhe volanie by poslalo payload dvakrat)')
end

NxTest.test('ŠT-3b-1: cache-bust a poradie skriptov') do
  ver = Noxun::Engine::VERSION
  NxTest.assert(ST3B_STUDIO_HTML.include?("js/rules.js?v=#{ver}"),
                'CEF cachuje js — `?v=` musi byt presne VERSION')
  NxTest.assert(ST3B_STUDIO_HTML.index('js/studio.js') < ST3B_STUDIO_HTML.index('js/rules.js'),
                'rules.js sa nacitava AZ ZA studio.js — obaluje jeho NX.setStudio')
  NxTest.assert(ST3B_STUDIO_HTML.index('js/hw_catalog.js') < ST3B_STUDIO_HTML.index('js/rules.js'),
                'a za vsetkymi predoslymi obalmi (kazdy dalsi musi vidiet ten predchadzajuci)')
end
