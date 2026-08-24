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
  # ŠT-3b-2b: k trom akciam okna pribudli DVA zapisove resety (a nic viac —
  # presnu rovnost strazi sada 3b-2b nizsie aj in-SU runner).
  NxTest.assert_equal(%w[save_rules load_global merge_seed reset_abs_override reset_hw_override],
                      actions, 'sekcia vie PRESNE tri akcie okna + dva resety — nic viac')
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
  pay = ST3B_RULES_RB[/def rules_payload\(model, collected = nil\).*?\n        end\n/m].to_s
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
  NxTest.assert(push.include?('rules: rules_payload(model, collected)'),
                'sekcia dostava stav plnym pushom — a HOTOVY zber (ziadny druhy sken)')
  NxTest.refute(ST3B_STUDIO_CODE.include?('@rules_full_pending'),
                'ziadna zapadka — pravidla su maly JSON, druhy kanal by bol drahsi nez payload')
  pay = ST3B_STUDIO_RB[/def rules_payload\(model, collected = nil\).*?\n        end\n/m].to_s
  NxTest.assert(pay.include?('RulesDialog.rules_payload(model, collected)'), 'telo je v RulesDialog')
  NxTest.assert(pay.include?("Engine.log_error(e, 'StudioDialog.rules_payload')"),
                'zlyhanie payloadu sa NEZAMLCUJE')
  rp = ST3B_RULES_RB[/def rules_payload\(model, collected = nil\).*?\n        end\n/m].to_s
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

NxTest.test('ŠT-3b-2a (F8): hint sekcie uz NEPOSIELA nikoho do neexistujuceho okna') do
  # Do 3b-2a tu stal riadok „zatiaľ ich spravuje okno „Pravidlá ABS"" — take
  # okno NIKDY neexistovalo. Hint musi hovorit PRAVDU: editor pravidiel ABS
  # nie je, menia sa hrany konkretneho dielca v Inspectore (D-78 duchom).
  meta = ST3B_STUDIO_JS[/rules: \{ t: 'Pravidlá',.*?\},/m].to_s
  NxTest.assert(meta.include?('ABS podľa roly'), 'hlavicka sekcie menuje OBE skupiny')
  NxTest.refute(meta.include?('ŠT-3b-2'), 'a uz nesluby, ze ABS „pribudne" — je tam')
  body = ST3B_STUDIO_HTML[/<template id="rulesBodyTpl">.*?<\/template>/m].to_s
  NxTest.refute(body.include?('Pravidlá ABS"'), 'klamlivy riadok o okne je PREC')
  NxTest.refute(body.include?('ďalšej dávke (ŠT-3b-2)'), 'aj slub buducej davky')
  hint = Noxun::Engine::RulesDialog.abs_payload['hint']
  NxTest.assert(hint.include?('nemajú editor'),
                'text hintu sklada SERVER a priznava, ze editor ABS pravidiel neexistuje')
  NxTest.refute(hint.include?('okno'), 'a nikam do okna neposiela')
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

# ============================================================================
# ŠT-3b-2a — ABS podla roly (read-only) + jantarove riadky rucnych zasahov
#
# Co tato cast strazi (a preco to klikanim neoveris):
#   1. ZDROJ ABS OVERRIDU. Autorita je PRITOMNOST kluca `edges` v configu
#      KORPUSU. Config ENTITY dielca nesie vyriesenu mapu hran VZDY — keby sa
#      citala ona, kazdy dielec by vyzeral ako „rucne nastaveny" a zoznam by
#      stratil vyznam.
#   2. MRTVE KLUCE. `PartKeys.migrate_overrides` zachovava kluce dielcov, ktore
#      uz neexistuju. Riadok bez dielca sa neda ani najst, ani vratit — musi
#      vypadnut UZ PRI ZBERE.
#   3. TEXTY SKLADA SERVER. Pravidlo ABS je HRUBKA, nie paska; riadok overridu
#      hovori o ROZHODNUTI cloveka, nie o spravnosti olepu (to je vec Kontroly).
#   4. RENDER MIMO ZAPADKY. Jantarove riadky sa musia obnovit pri KAZDOM pushi
#      (rucny zasah v Inspectore pravidla nemeni), ale formular pravidiel
#      kovania sa pritom NESMIE prekreslit.
require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'bom') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'abs_rules') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'part_keys') if NxTest.headless?
# `display_name` (D-100 živý default názvu skrinky) — nadpis skupiny riadkov.
require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder') if NxTest.headless?

ST3B2_CSS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'),
                      encoding: 'UTF-8')
ST3B2_PC_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                        encoding: 'UTF-8')

# Vnoreny dielec tak, ako ho vidi `Bom.collect` (zaznam zo snapshotu).
def st3b2_part(key, role, name)
  { 'part_key' => key, 'role' => role, 'name' => name, 'pid' => 101,
    'material_id' => 'MAT-1' }
end

NxTest.test('ŠT-3b-2a (B1): ABS override sa cita z CONFIGU KORPUSU, nie zo snapshotu dielca') do
  nested = { 'side:left' => st3b2_part('side:left', 'side_left', 'Bok ľavý') }
  ccfg = { 'name' => 'Dolná 600',
           'part_overrides' => { 'side:left' => { 'edges' => { 'L1' => 'ABS-1' } } } }
  out = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(out, ccfg, 'CAB-001', nested)
  NxTest.assert_equal(1, out['abs'].length, 'zaznam s klucom `edges` je rucny zasah')
  row = out['abs'].first
  NxTest.assert_equal('CAB-001', row['owner_id'], 'adresa nesie korpus')
  NxTest.assert_equal('side:left', row['part_key'], 'a stabilny kluc dielca')
  NxTest.assert_equal('side_left', row['role'], 'rola sa berie z REALNEHO dielca (nie z kluca)')

  # Zaznam BEZ kluca `edges` (napr. len material dielca) rucnym zasahom do hran NIE JE.
  out2 = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(
    out2, { 'part_overrides' => { 'side:left' => { 'material_id' => 'MAT-9' } } },
    'CAB-001', nested
  )
  NxTest.assert_equal([], out2['abs'], 'iny override (material) hrany nezmenil — riadok nevznika')

  # Zdrojak: snapshot hran ENTITY sa ako override necita NIKDY.
  body = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'bom.rb'), encoding: 'UTF-8')[
    /def collect_manual_overrides.*?\n      end\n/m
  ].to_s
  NxTest.refute(body.include?('Store.config'),
                'zber nesiaha na config dielca — vyriesenu mapu hran nesie KAZDY dielec')
end

NxTest.test('ŠT-3b-2a (review P2): nadpis skupiny nesie ZIVY nazov skrinky, nie holé id') do
  # D-100: do configu sa uklada LEN RUCNY nazov (nil = zivy default podla typu
  # a sirky). Keby zoznam cital `ccfg['name']`, mala by VACSINA skriniek
  # v nadpise hole „CAB-004" — presne tie, ktore pouzivatel nikdy nepremenoval.
  nested = { 'p1' => st3b2_part('p1', 'shelf', 'Polica 1') }
  ov = { 'part_overrides' => { 'p1' => { 'edges' => { 'L1' => 'ABS-1' } } } }

  auto = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(
    auto, ov.merge('type' => 'lower', 'width' => 600.0), 'CAB-004', nested
  )
  NxTest.assert_equal('Spodná skrinka 600', auto['abs'].first['owner_name'],
                      'skrinka bez rucneho nazvu ma ZIVY default (to iste, co vidno v paneli)')

  manual = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(
    manual, ov.merge('type' => 'lower', 'width' => 600.0, 'name' => 'Drezová'), 'CAB-004', nested
  )
  NxTest.assert_equal('Drezová', manual['abs'].first['owner_name'], 'rucny nazov ma prednost')

  # A nadpis skupiny z neho vznikne aj s identitou (najst sa musi dat oboje).
  pay = Noxun::Engine::RulesDialog.overrides_payload({ manual_overrides: manual })
  NxTest.assert_equal('CAB-004 · Drezová', pay['abs']['groups'].first['title'],
                      'nadpis skupiny = id + nazov')
end

NxTest.test('ŠT-3b-2a (B2/F14): mrtve kluce a odpojene dvojcata sa NEKRESLIA') do
  # Presne to, co robi migracia: kluc zmazaneho dielca v configu PREZIJE.
  kept = Noxun::Engine::PartKeys.migrate_overrides(
    { 'zone:z1/shelf:9' => { 'edges' => { 'L1' => 'ABS-1' } } },
    [{ role: :shelf, part_key: 'zone:z1/shelf:1' }]
  )
  NxTest.assert(kept.key?('zone:z1/shelf:9'),
                'migracia mrtvy kluc ZACHOVAVA — preto ho musi odfiltrovat az zber')

  out = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(
    out, { 'part_overrides' => kept }, 'CAB-001',
    { 'zone:z1/shelf:1' => st3b2_part('zone:z1/shelf:1', 'shelf', 'Polica 1') }
  )
  NxTest.assert_equal([], out['abs'],
                      'kluc bez REALNEHO dielca sa nekresli (neda sa najst ani vratit)')
end

NxTest.test('ŠT-3b-2a: kovanie sa paruje TYM ISTYM jointom') do
  nested = { 'front:F1/wing:left' => st3b2_part('front:F1/wing:left', 'front_door', 'Dvierka ľavé') }
  ccfg = { 'hardware_overrides' => [
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'nohy', 'quantity' => 6 },
    { 'owner_part_key' => 'front:F1/wing:left', 'generic_type' => 'hinge',
      'rule_id' => 'zavesy', 'disabled' => true },
    { 'owner_part_key' => 'front:ZANIKLO/wing:left', 'generic_type' => 'hinge',
      'rule_id' => 'zavesy', 'quantity' => 3 }
  ] }
  out = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(out, ccfg, 'CAB-002', nested)
  NxTest.assert_equal(2, out['hardware'].length,
                      'zaznam s nesediacim `owner_part_key` sa ticho neaplikuje — ani nekresli')
  NxTest.assert_equal('', out['hardware'][0]['owner_part_key'].to_s,
                      'korpusovy override (bez dielca) ostava')
  NxTest.assert_equal('Dvierka ľavé', out['hardware'][1]['part_name'],
                      'a sparovany zaznam dostal LUDSKY nazov dielca')
end

NxTest.test('ŠT-3b-2a: zber nemutuje config a `compute()` novy kluc IGNORUJE') do
  edges = { 'L1' => 'ABS-1' }
  ccfg = { 'part_overrides' => { 'p1' => { 'edges' => edges } } }
  out = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(out, ccfg, 'CAB-003',
                                              { 'p1' => st3b2_part('p1', 'shelf', 'Polica') })
  out['abs'].first['edges']['L2'] = 'ABS-2'
  NxTest.assert_equal({ 'L1' => 'ABS-1' }, edges, 'config korpusu sa zberom NEMENI')

  computed = Noxun::Engine::Bom.compute(
    { records: [], hardware: [], warnings: [],
      manual_overrides: { 'abs' => [{ 'owner_id' => 'CAB-001' }], 'hardware' => [] },
      cabinets: 1, boards: 0 }
  )
  NxTest.refute(computed.key?(:manual_overrides), 'vypocet kusovnika o novom kluci nevie')
  NxTest.assert(computed.key?(:rows), 'a bezi presne ako predtym')
end

NxTest.test('ŠT-3b-2a (N19): pravidlo ABS je HRUBKA — riadok nikdy nepise pasku') do
  rd = Noxun::Engine::RulesDialog
  shelf = rd.abs_rule_row('shelf', { 'L1' => 1.0 })
  NxTest.assert_equal('Polica', shelf['label'], 'nazov roly sklada SERVER (`role_label`)')
  NxTest.assert_equal('Predná', shelf['desc'], 'popis menuje hranu recou stolara')
  NxTest.assert_equal('1,0 mm', shelf['value'], 'hodnota je HRUBKA s desatinnou CIARKOU')

  door = rd.abs_rule_row('front_door', { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 })
  NxTest.assert_equal('všetky štyri hrany', door['desc'], 'olep dookola sa nevypisuje po hranach')
  back = rd.abs_rule_row('back', {})
  NxTest.assert_equal('bez olepu', back['value'], 'prazdne pravidlo je VEDOME „bez olepu"')
  mixed = rd.abs_rule_row('shelf', { 'L1' => 1.0, 'L2' => 2.0 })
  NxTest.assert(mixed['value'].include?('Predná 1,0 mm') && mixed['value'].include?('Zadná 2,0 mm'),
                'rozne hrubky sa vypisu po hranach — nic sa nezlieva')

  src = ST3B_RULES_RB[/def abs_rule_row.*?\n        end\n/m].to_s
  NxTest.refute(src.include?('ProductionCore.edge_label') || src.include?('Materials'),
                'pravidlo NIKDY nesiaha na katalog pasok — dekor sa dopocita az pri stavbe')
end

NxTest.test('ŠT-3b-2a: prehlad ABS pravidiel ma poradie a VLASTNY riadok zdroja (F9)') do
  abs = Noxun::Engine::RulesDialog.abs_payload
  roles = abs['rows'].map { |r| r['role'] }
  NxTest.assert(roles.include?('shelf') && roles.include?('front_door'), 'vsetky roly su v prehlade')
  NxTest.assert(roles.index('side_left') < roles.index('front_door'),
                'poradie je dane serverom (korpus -> cela), nie nahodnym poradim hashu')
  NxTest.assert(abs['source'].include?('globálne'),
                'rozsah ABS je GLOBALNY — kovanie je projektove, kazda skupina ma vlastny zdroj')
  NxTest.assert(abs['source'].include?('neprestaví'),
                'a povie aj to, ze zmena pravidla hotove skrinky neprestavi')
end

NxTest.test('ŠT-3b-2a (F11/F15): jantarove riadky — rozhodnutie, zoskupenie, strop') do
  rd = Noxun::Engine::RulesDialog
  collected = { manual_overrides: {
    'abs' => [
      { 'owner_id' => 'CAB-001', 'owner_name' => 'Dolná 600', 'part_key' => 'p1',
        'role' => 'shelf', 'name' => 'Polica 1', 'edges' => { 'L1' => '', 'W1' => 'ABS-X' } },
      { 'owner_id' => 'CAB-001', 'owner_name' => 'Dolná 600', 'part_key' => 'p2',
        'role' => 'shelf', 'name' => 'Polica 2', 'edges' => { 'L1' => 'ABS-X' } },
      { 'owner_id' => 'CAB-002', 'owner_name' => '', 'part_key' => 'p1',
        'role' => 'side_left', 'name' => '', 'edges' => { 'L1' => 'ABS-X' } }
    ],
    'hardware' => [
      { 'owner_id' => 'CAB-001', 'owner_name' => 'Dolná 600', 'owner_part_key' => '',
        'generic_type' => 'leg', 'rule_id' => 'nohy', 'quantity' => 6 },
      { 'owner_id' => 'CAB-001', 'owner_name' => 'Dolná 600',
        'owner_part_key' => 'front:F1/wing:left', 'part_name' => 'Dvierka ľavé',
        'generic_type' => 'hinge', 'rule_id' => 'zavesy', 'disabled' => true },
      { 'owner_id' => 'CAB-001', 'owner_name' => '', 'owner_part_key' => '',
        'generic_type' => 'slide', 'rule_id' => 'vysuvy', 'nominal_length' => 420.0 }
    ]
  } }
  pay = rd.overrides_payload(collected)
  abs = pay['abs']
  NxTest.assert_equal(3, abs['total'], 'spocitane su VSETKY riadky')
  NxTest.assert_equal(2, abs['groups'].length, 'zoskupene po SKRINKACH')
  NxTest.assert_equal('CAB-001 · Dolná 600', abs['groups'][0]['title'],
                      'nadpis skupiny nesie id aj rucny nazov skrinky')
  NxTest.assert_equal('CAB-002', abs['groups'][1]['title'], 'bez nazvu ostava samotne id')
  row = abs['groups'][0]['rows'][0]
  NxTest.assert_equal('Polica 1', row['label'], 'riadok menuje DIELEC')
  NxTest.assert_equal('ručne nastavené hrany', row['desc'],
                      'text hovori o ROZHODNUTI cloveka, nie o spravnosti olepu')
  NxTest.assert(row['value'].include?('Predná: bez olepu'),
                'prazdna hodnota je VEDOME „bez olepu" (nie „chyba")')
  NxTest.assert(row['value'].include?('Ľavá: ABS-X'),
                'paska mimo katalogu sa ukaze SUROVYM id — nikdy vymyslenym nazvom')
  NxTest.assert_equal('Bok ľavý', abs['groups'][1]['rows'][0]['label'],
                      'dielec bez nazvu ma aspon rolu')

  hw = pay['hardware']
  NxTest.assert_equal(3, hw['total'], 'kovanie ma vlastnu skupinu')
  vals = hw['groups'][0]['rows'].map { |r| r['value'] }
  NxTest.assert(vals.any? { |v| v.include?('počet 6 ks') }, 'rucny pocet je vidiet')
  NxTest.assert(vals.any? { |v| v.include?('vypnuté') }, 'vypnuta polozka tiez')
  NxTest.assert(vals.any? { |v| v == 'dĺžka 420 mm' },
                'rucna dlzka vysuvu bez falosneho desatinneho miesta')
  NxTest.assert(hw['groups'][0]['rows'].any? { |r| r['desc'].include?('Dvierka ľavé') },
                'override na dielci povie, na KTOROM')

  # Strop zoznamu: „Použiť na podobné" vie vyrobit desiatky riadkov naraz.
  many = (1..(rd::MAX_OVERRIDE_ROWS + 5)).map do |i|
    { 'owner_id' => "CAB-#{i}", 'owner_name' => '', 'part_key' => 'p1', 'role' => 'shelf',
      'name' => "Polica #{i}", 'edges' => { 'L1' => 'ABS-X' } }
  end
  capped = rd.overrides_payload({ manual_overrides: { 'abs' => many, 'hardware' => [] } })['abs']
  NxTest.assert_equal(rd::MAX_OVERRIDE_ROWS + 5, capped['total'], 'celkovy pocet sa PRIZNA')
  NxTest.assert_equal(rd::MAX_OVERRIDE_ROWS,
                      capped['groups'].sum { |g| g['rows'].length }, 'ale zoznam je zastropovany')
  NxTest.assert(capped['more_text'].include?('5'), 'a zvysok povie suhrn')
  NxTest.assert_equal('', abs['more_text'], 'kratky zoznam ziadny suhrn nema')
end

NxTest.test('ŠT-3b-2a (F7): zlyhanie zberu overridov NEZHODI formular pravidiel') do
  rd = Noxun::Engine::RulesDialog
  broken = Object.new
  def broken.[](_key)
    raise 'zber zlyhal'
  end
  def broken.is_a?(klass)
    klass == Hash
  end
  pay = rd.overrides_payload(broken)
  NxTest.assert_equal(0, pay['abs']['total'], 'zoznam ostane prazdny')
  NxTest.assert_equal(0, pay['hardware']['total'], 'v oboch skupinach')
  src = ST3B_RULES_RB[/def overrides_payload\(collected\).*?\n        end\n/m].to_s
  NxTest.assert(src.include?('rescue StandardError'), 'ma VLASTNY rescue')
  NxTest.assert(src.include?("Engine.log_error(e, 'RulesDialog.overrides_payload')"),
                'a zlyhanie sa NEZAMLCUJE')
end

NxTest.test('ŠT-3b-2a (F11): riadky NEVSTUPUJU do poctov Kontroly') do
  val = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'validation.rb'), encoding: 'UTF-8')
  NxTest.refute(val.include?('manual_overrides'),
                'kontrola o novom kluci nevie — jantarovy riadok nie je nalez')
  js = ST3B_RULES_JS[/function rdOvrHtml\(g\)\{.*?\n  \}/m].to_s
  NxTest.refute(js.include?("rdIco('alert')"), 'ziadna ⚠ — riadok nehovori o chybe')
  NxTest.assert(js.include?("rdIco('pencil')"), 'ale o rucnom zasahu (ceruzka)')
  NxTest.assert(js.include?('rdChip') || ST3B_RULES_JS.include?('class="rdchip"'),
                'stitok „override" je jantarovy chip')
end

NxTest.test('ŠT-3b-2a (F10): oko ide novou vetvou (owner_id, part_key), NIE cez pids') do
  sel = ST3B2_PC_RB[/def do_select\(model, data, generation:, status:, repush:\).*?\n      end\n/m].to_s
  NxTest.assert(sel.include?("elsif data['rule_ref']"), 'vyber ma vlastnu vetvu')
  NxTest.assert(sel.include?("pids_for_override(model, data['rule_ref'])"), 'a vlastny resolver')
  NxTest.assert(sel.index("data['rule_ref']") < sel.index('refs_for(Bom.compute'),
                'vetva je PRED vseobecnou (inak by spadla do klucov kusovnika)')
  body = ST3B2_PC_RB[/def pids_for_override\(model, ref\).*?\n      end\n/m].to_s
  NxTest.assert(body.include?('pids_for_problem(model,'),
                'telo sa NEDUPLIKUJE — pouzije sa hotove hladanie podla identity')
  NxTest.refute(body.include?("data['pids']"), 'ziadne pids z DOM (rebuild ich meni)')
  js = ST3B_RULES_JS[/function rdSelectOverride\(ownerId, partKey\)\{.*?\n  \}/m].to_s
  NxTest.assert(js.include?('gen: st.gen'), 'klik nesie generaciu okna (stary DOM sa odmietne)')
  NxTest.assert(js.include?('rule_ref:'), 'a adresu overridu')
end

NxTest.test('ŠT-3b-2a (F5/N22): ABS je NAD kovanim a render NEROBI cez zapadku formulara') do
  body = ST3B_STUDIO_HTML[/<template id="rulesBodyTpl">.*?<\/template>/m].to_s
  NxTest.assert(body.index('ABS podľa roly dielca') < body.index('Kovanie podľa rozmerov'),
                'poradie skupin podla mockupu — ABS NAD kovanim')
  %w[rdAbsSrc rdAbsBox rdAbsHint rdAbsOvr rdHwOvr].each do |id|
    NxTest.assert(body.include?(%(id="#{id}")), "novy blok ma VLASTNY uzol `#{id}`")
  end
  NxTest.assert(ST3B_RULES_JS.include?("RD_BODY.id = 'rulesBody'"),
                'identita klonovaneho tela sa nestratila (uzol putuje do sekcie a spat)')

  apply = ST3B_RULES_JS[/function rdApplyState\(r\)\{.*?\n  \}/m].to_s
  early = apply[/if \(seed === RD_SEED\)\{.*?\n    \}/m].to_s
  NxTest.assert(early.include?('rdRenderExtra()'),
                'push s NEZMENENYMI pravidlami jantarove riadky OBNOVI (rucny zasah pravidla nemeni)')
  NxTest.assert(apply.scan('rdRenderExtra()').length >= 2, 'a obnovi ich aj druha vetva')
  render_extra = ST3B_RULES_JS[/function rdRenderExtra\(\)\{.*?\n  \}/m].to_s
  NxTest.refute(render_extra.include?('RD_NEEDS_RENDER'),
                'read-only bloky sa zapadky formulara NEDOTYKAJU')
  NxTest.refute(render_extra.include?("rdEl('rulesBox')"), 'ani samotneho formulara')
  body_js = ST3B_RULES_JS[/function rulesRenderBody\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(body_js.index('rdRenderExtra()') < body_js.index('if (RD_NEEDS_RENDER){'),
                'pri navrate do sekcie sa dokresli aj to, co prislo, kym bolo telo odpojene')
end

NxTest.test('ŠT-3b-2a (F18): riadky maju VLASTNY CSS blok — tokeny, ziadne emoji') do
  %w[.rdrow .rdovr .rdchip .rdeye .rdovrbox].each do |cls|
    NxTest.assert(ST3B2_CSS.include?(cls), "trieda #{cls} existuje (mockupove .lrow su len prototyp)")
  end
  %w[.lrow .lnm .lcd .lpr .bsecbody].each do |ghost|
    NxTest.refute(ST3B2_CSS.include?("#{ghost} "), "trieda mockupu #{ghost} sa NEDOMYSLA")
  end
  block = ST3B2_CSS[/\.rdrow \{.*?\.rdeye \.ic[^\n]*\n/m].to_s
  NxTest.assert(!block.empty?, 'blok sa nasiel')
  NxTest.refute(block.match?(/#[0-9a-fA-F]{3,6}\b/), 'ziadne natvrdo napisane farby — len --nx-* tokeny')
  NxTest.assert(block.include?('--nx-warn-bg'), 'jantar je z rodiny --nx-warn*')
  # Nove bloky: ikony VYHRADNE zo spritu (`<use href="#i-...">`), ziadny znak
  # z emoji/dingbat rozsahov. (Starsi formular pravidiel ma „✕" pri pasmach —
  # ten sa touto davkou nemeni, preto sa kontroluje LEN novy kod.)
  new_js = ST3B_RULES_JS[/function rdIco\(n\).*?function rdSrcLine/m].to_s
  NxTest.assert(new_js.include?('rdOvrHtml'), 'novy blok sa nasiel')
  NxTest.refute(new_js.match?(/[\u{1F300}-\u{1FAFF}\u{2190}-\u{27BF}]/),
                'ziadne emoji ani sipky — ikony su zo spritu')
  NxTest.assert(new_js.include?("<use href=\"#i-'"), 'ikony sa berú zo zdieľaného spritu')
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

# ============================================================================
# ŠT-3b-2b — „VRÁTIŤ NA PRAVIDLO" (zapisove cesty sekcie)
#
# Co tato cast strazi (a preco to klikanim neoveris):
#   1. TELO ZAPISU je JEDNO. Keby si sekcia mazala override po svojom, jedna
#      z ciest by casom nechala v configu zvysok (napr. `edge_warnings`) a
#      dielec by ostal mimo pravidla — bez jedineho viditelneho priznaku.
#   2. GUARDY STOJA PRED ZAPISOM. Zastarany klik, cudzi dokument a
#      NEJEDNOZNACNE `cabinet_id` (cerstva kopia pred dedup tikom) musia zapis
#      ODMIETNUT. „Vezmi prvu" by prestavala skrinku, na ktoru nikto neklikol.
#   3. STATUS HOVORI VYSLEDOK, nie „override zrušený" — a priznava dosledky,
#      ktore z riadku nevidno (vratenie polozky do nakupu, strateny zamok dlzky).
#   4. VYBER SA NEMENI. Zoznam v sekcii nema s oznacenim v modeli nic spolocne;
#      reselect by pouzivatelovi prepisal to, co ma prave oznacene.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware') if NxTest.headless?

ST3B2_PARTS_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts.rb'),
                           encoding: 'UTF-8')

def st3b2_rd_body(name)
  ST3B_RULES_RB[/def #{Regexp.escape(name)}\b.*?\n        end\n/m].to_s
end

NxTest.test('ŠT-3b-2b (F17): whitelist je uzavrety a KAZDA akcia ma telo') do
  actions = Noxun::Engine::RulesDialog::SECTION_ACTIONS
  NxTest.assert_equal(%w[save_rules load_global merge_seed reset_abs_override reset_hw_override],
                      actions, 'sekcia vie PRESNE tri akcie okna + dva resety')
  NxTest.assert(actions.frozen?, 'zoznam ostava uzavrety')
  run = st3b2_rd_body('run_section_action')
  %w[reset_abs_override reset_hw_override].each do |a|
    NxTest.assert(run.include?("when '#{a}'"), "#{a} ma telo (inak by akcia ticho nic neurobila)")
  end
  # Mena sa nesmu zrazit s callbackmi Studia ani s inou sekciou (ta ista brana
  # ako pri troch povodnych akciach).
  own = ST3B_STUDIO_RB.scan(/cb\(dlg, '([a-z_]+)'\)/).flatten
  NxTest.assert_equal([], actions & own, 'mena akcii sa nesmu zrazit s callbackmi Studia')
  %w[MaterialsDialog HardwareCatalogDialog].each do |mod|
    other = Noxun::Engine.const_get(mod)::SECTION_ACTIONS
    NxTest.assert_equal([], actions & other, "ani s akciami sekcie #{mod}")
  end
  runner = File.read(File.join(NxTest::ROOT, 'tests', 'sketchup', 'su_runner.rb'), encoding: 'UTF-8')
  NxTest.assert(runner.include?('reset_abs_override reset_hw_override'),
                'in-SU runner strazi PRESNU rovnost whitelistu — a pozna nove akcie')
end

NxTest.test('ŠT-3b-2b (B4): ABS reset ma JEDNO telo — a to telo je spravne') do
  panel = Noxun::Engine::Panel
  params = { 'part_overrides' => {
    'p1' => { 'edges' => { 'L1' => 'ABS-1' }, 'edge_warnings' => [{ 'code' => 'x' }],
              'material_id' => 'MAT-9' },
    'p2' => { 'edges' => { 'L1' => 'ABS-1' } },
    'p3' => { 'material_id' => 'MAT-1' }
  } }
  NxTest.assert(panel.reset_part_edges!(params, 'p1'), 'reset hlasi, ze bolo CO vratit')
  rec = params['part_overrides']['p1']
  NxTest.refute(rec.key?('edges'), 'kluc `edges` je PREC — jeho pritomnost JE definicia overridu')
  NxTest.refute(rec.key?('edge_warnings'),
                'a s nim aj sticky dovody — patria STARYM hranam, inak by karta varovala pred ' \
                'paskou, ktora tam uz nie je')
  NxTest.assert_equal('MAT-9', rec['material_id'],
                      'INE rozhodnutia dielca (material, smer) reset NEMAZE')

  panel.reset_part_edges!(params, 'p2')
  NxTest.refute(params['part_overrides'].key?('p2'),
                'zaznam, z ktoreho nic neostalo, zanikne (inak by v configu rastlo smetie)')
  NxTest.refute(panel.reset_part_edges!(params, 'p3'),
                'dielec bez rucnych hran = nie je co vratit (a nic sa nerozbije)')
  NxTest.assert(params['part_overrides'].key?('p3'), 'a jeho ostatne rozhodnutia ostavaju')

  # JEDNO telo: „Použiť na podobné" s prazdnym zdrojom sa nan napaja.
  similar = ST3B2_PARTS_RB[/def handle_apply_edges_similar.*?\n        end\n/m].to_s
  NxTest.assert(similar.include?('reset_part_edges!(params, key)'),
                'druha vstupna cesta vola TO ISTE telo')
  NxTest.refute(similar.include?("rec.delete('edges')"),
                'a nema uz vlastnu kopiu mazania (dve kopie by sa casom rozisli)')
  NxTest.assert(st3b2_rd_body('handle_reset_abs').include?('Panel.reset_part_edges!(params, rk)'),
                'sekcia vola to iste telo — neduplikuje mutaciu configu')
end

NxTest.test('ŠT-3b-2b (odpoved D): kovanie reset maze CELY zaznam identity') do
  panel = Noxun::Engine::Panel
  all = [
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'nohy', 'quantity' => 6 },
    { 'owner_part_key' => 'front:F1/wing:left', 'generic_type' => 'hinge', 'rule_id' => 'zavesy',
      'disabled' => true, 'nominal_length' => 420.0 },
    { 'owner_part_key' => nil, 'generic_type' => 'slide', 'rule_id' => 'vysuvy', 'quantity' => 2 }
  ]
  out = panel.merge_override(all, 'front:F1/wing:left', 'hinge', 'zavesy', :all, nil)
  NxTest.assert_equal(2, out.length, 'zaznam identity zanikol CELY (vsetky polia naraz)')
  NxTest.assert(out.none? { |o| o['generic_type'] == 'hinge' }, 'a je to naozaj ten spravny')
  NxTest.assert_equal(all[0], out[0], 'ostatne zaznamy ostali NEDOTKNUTE')
  NxTest.assert(st3b2_rd_body('handle_reset_hw')
                .include?('Panel.merge_override(all, owner, gt, rid, :all, nil)'),
                'sekcia ide TOU ISTOU cestou ako reset v Inspectore (field :all)')
end

NxTest.test('ŠT-3b-2b (odpoved D): status prizna dosledky, ktore z riadku NEVIDNO') do
  rd = Noxun::Engine::RulesDialog
  panel = Noxun::Engine::Panel
  # `series_value?` sa pyta pravidiel MODELU — headless ho zastupime, aby sa
  # dalo overit SPRAVANIE hlasky (nie len jej text v zdrojaku).
  panel.singleton_class.class_eval do
    alias_method :nx_orig_series_value?, :series_value?
    define_method(:series_value?) { |_model, _rid, _gt, nl| nl.to_f == 400.0 }
  end
  begin
    off = rd.hw_reset_note(nil, { 'disabled' => true }, 'hinge', 'zavesy')
    NxTest.assert(off.include?('do nákupu'),
                  'zrusenie „vypnuté" VRACIA polozku do supisu aj nakupu — mení to cenu')
    keep = rd.hw_reset_note(nil, { 'nominal_length' => 400.0 }, 'slide', 'vysuvy')
    NxTest.assert_equal('', keep, 'zamok NA hodnote z radu sa da nastavit znova — niet co priznavat')
    lost = rd.hw_reset_note(nil, { 'nominal_length' => 437.0 }, 'slide', 'vysuvy')
    NxTest.assert(lost.include?('nenávratne'),
                  'zamok MIMO radu sa strati nenavratne — pouzivatel to musi vediet PRED klikom')
    NxTest.assert(lost.include?('437'), 'a hlaska menuje konkretnu dlzku')
    both = rd.hw_reset_note(nil, { 'disabled' => true, 'nominal_length' => 437.0 }, 'slide', 'vysuvy')
    NxTest.assert(both.include?('do nákupu') && both.include?('nenávratne'),
                  'zaznam s viacerymi polami prizna OBA dosledky (polia su nezavisle, D-93)')
    NxTest.assert_equal('', rd.hw_reset_note(nil, { 'quantity' => 6 }, 'leg', 'nohy'),
                        'obycajny rucny pocet ziadny skryty dosledok nema')
  ensure
    panel.singleton_class.class_eval do
      alias_method :series_value?, :nx_orig_series_value?
      remove_method :nx_orig_series_value?
    end
  end
end

NxTest.test('ŠT-3b-2b (B3): guardy stoja PRED zapisom — a nejednoznacna adresa je ODMIETNUTIE') do
  ctx = st3b2_rd_body('reset_context')
  NxTest.assert(!ctx.empty?, 'spolocny guard existuje (jedno miesto pre obe akcie)')
  NxTest.assert(ctx.include?("data['gen'].to_i != gen"),
                'generacia okna — klik zo zastaraneho zoznamu sa nevykona')
  NxTest.assert(ctx.include?('guid != model_guid(model)') && ctx.include?('!guid.empty?'),
                'identita dokumentu, TOLERANTNE na prazdny udaj (starsi cachovany DOM)')
  NxTest.assert(ctx.include?('cands.length > 1'), 'viac kandidatov na `cabinet_id` je vetva')
  NxTest.assert(ctx.include?('viac kusov'), 'a povie sa to slovami, nie tichym no-op')
  # Kod BEZ komentarov — o dedupe sa v komentari HOVORI (a musi), ale volat sa
  # tu nesmie: otvoril by DRUHU operaciu (z jedneho kliku dva kroky Späť).
  ctx_code = ctx.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.refute(ctx_code.include?('dedup'), 'dedup sa TU nespusta')

  %w[handle_reset_abs handle_reset_hw].each do |m|
    body = st3b2_rd_body(m)
    NxTest.assert(body.index('reset_context(payload)') < body.index('rebuild_many'),
                  "#{m}: guard je PRED prestavbou")
    NxTest.assert(body.include?('CabinetBuilder.rebuild_many(model, [[cab, params]]'),
                  "#{m}: prestavba je JEDNA operacia = JEDEN krok Späť")
    NxTest.assert(body.include?('after_model_write(model)'),
                  "#{m}: po zapise dostanu cerstve cisla OBAJA odberatelia")
    NxTest.refute(body.include?('reselect'),
                  "#{m}: VYBER SA NEMENI — zoznam sekcie nema s oznacenim v modeli nic spolocne")
    NxTest.assert(body.include?('selection_note(model, had_sel)'),
                  "#{m}: ak prestavba vyber zhodi, PRIZNA sa to")
  end
  rej = st3b2_rd_body('reject_reset')
  NxTest.assert(rej.include?('refresh_studio(bump: false)'),
                'odmietnutie nacita sekciu nanovo BEZ zdvihu generacie (nic sa nezapisalo)')
end

NxTest.test('ŠT-3b-2b (F13/F14): status hovori VYSLEDOK a odpojene dvojca sa neprehliadne') do
  abs = st3b2_rd_body('abs_rule_result')
  NxTest.assert(abs.include?('Store.config(part)'),
                'vysledok sa cita zo SNAPSHOTU po prestavbe — to iste, co ide do vyroby')
  NxTest.assert(abs.include?('podľa pravidla bez olepu'),
                'potlaceny default (kompakt, postforming, dekor bez pasky) MA vlastnu vetu')
  NxTest.assert(abs.include?('podľa pravidla:'), 'inak sa vymenuju hrany a hrubky')
  twin = st3b2_rd_body('detached_twin_note')
  NxTest.assert(twin.include?('vytiahnutý zo skrinky'),
                'odpojene dvojca sa PRIZNA — prestavba ho neprekresli a do vystupu ide po starom')
  NxTest.assert(st3b2_rd_body('handle_reset_abs').include?('detached_twin_note(model, cid, rk)'),
                'a kontroluje sa pri KAZDOM ABS resete (nikdy tichy uspech)')
  hw = st3b2_rd_body('hw_rule_result')
  NxTest.assert(hw.include?('nepočíta nič'),
                'ked pravidlo na skrinke negeneruje nic, povie sa to (prazdno vyzera ako chyba)')
end

NxTest.test('ŠT-3b-2b (review #221): vyber podla `rule_ref` uz nerobi zbytocny zber modelu') do
  sel = ST3B2_PC_RB[/def do_select\(model, data, generation:, status:, repush:\).*?\n      end\n/m].to_s
  branch = sel[/elsif data\['rule_ref'\].*?\n        else/m].to_s
  NxTest.refute(branch.include?('fresh_collect'),
                'vetva oka hlada podla identity — plny sken modelu (a dedup v nom) je cista rezia')
  NxTest.assert(sel.include?("if data['problem_key']\n          collected = fresh_collect(model)"),
                'zber sa robi AZ vo vetve, ktora ho naozaj potrebuje')
  NxTest.assert(sel.include?('refs_for(Bom.compute(fresh_collect(model)), data)'),
                'a vseobecna vetva ho ma dalej (BOM bez zberu neexistuje)')
end
