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
  NxTest.refute(st.const_defined?(:WINDOW_BRIDGES),
                'jeden kluc nesmie byt zaroven sekcia aj premostenie')
  # ŠT-4a: cela tabulka hlasok premosteni ZANIKLA s poslednym satelitom.
  NxTest.refute(st.const_defined?(:BRIDGE_STATUS), 'a nesmie existovat ani tabulka hlasok premosteni')
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

NxTest.test('ŠT-3b-1: baseline formulara stoji na identite dokumentu, NIE na `model.path`') do
  code = ST3B_RULES_CODE
  NxTest.refute(code.include?('model.path'),
                'cesta dva NEULOZENE modely nerozlisi (oba maju prazdny path)')
  NxTest.refute(code.include?('@baseline_path'), 'stara premenna zanikla')
  guid = ST3B_RULES_RB[/def model_guid\(model\).*?\n        end\n/m].to_s
  # 1d/R-02b: identitou je token DocKey — Model#guid sa meni pri kazdom
  # ulozeni, takze Ctrl+S s otvorenym oknom Pravidiel zneplatnoval baseline.
  NxTest.assert(guid.include?('DocKey.key(model)'), 'identita dokumentu je token DocKey')
  valid = ST3B_RULES_RB[/def baseline_valid\?\(model\).*?\n        end\n/m].to_s
  NxTest.assert(valid.include?('model_guid(model) != @baseline_guid'), 'guard porovnava guid')
  NxTest.assert(valid.include?('current == @baseline_rules'),
                'a ZHODU aktualnych pravidiel s baseline (chyti undo aj subeznu zmenu)')
  pay = ST3B_RULES_RB[/def rules_payload\(model, collected = nil\).*?\n        end\n/m].to_s
  # ŠT-3b-2c2 (audit B4): baseline sa obnovuje pri kazdom USPESNOM zostaveni
  # payloadu — a AZ NA KONCI tela. Ked zostavenie spadne (`rescue` -> nil),
  # klient si drzi STARY stav; posunuty baseline by roztvoril NOZNICE
  # (server caka nove hodnoty, klient posiela stare = vecne odmietanie).
  NxTest.assert(pay.include?('@baseline_guid  = guid'),
                'baseline sa obnovi pri USPESNOM zostaveni payloadu')
  NxTest.assert(pay.include?('@baseline_rules = rules'), 'aj s pravidlami')
  NxTest.assert(pay.index('payload = {') < pay.index('@baseline_guid'),
                'a to AZ ZA telom — nikdy pred nim')
  rescue_part = pay[/rescue StandardError.*\z/m].to_s
  NxTest.refute(rescue_part.include?('@baseline'),
                'rescue vetva baseline NEMENI (inak by zlyhany payload rozbil kazde dalsie ulozenie)')
  NxTest.refute(pay.include?('Sketchup.active_model'),
                'F4: model chodi ARGUMENTOM — inak by sekcia dostala pravidla STAREHO dokumentu')
end

NxTest.test('ŠT-3b-1 (review P2): SERVER overuje `model_guid` Z PAYLOADU') do
  # Druha vrstva k baseline: klient posiela guid z TOHO ISTEHO payloadu,
  # ktorym bol formular naplneny. Kym ho server necital, bolo to MRTVE pole.
  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(save.include?(%q<DocKey.foreign?(data['model_guid'], model>),
                'guid z payloadu sa naozaj cita')
  NxTest.assert(save.include?(%q<DocKey.foreign?(data['model_guid'], model, tolerate_blank_client: true)>),
                'a porovnava sa s modelom — TOLERANTNE (prazdny udaj guard neblokuje)')
  guard = save[/if DocKey\.foreign\?.*?\n          end\n/m].to_s
  NxTest.assert(guard.include?('refresh_studio(bump: false)'),
                'PREPNUTY DOKUMENT je cudzi pre VSETKY sekcie — tu ZAMERNE ostava PLNY push ' \
                '(echo jednej sekcie by nechalo kusovnik a rozpocet na cislach ineho projektu); ' \
                'BEZ zdvihu generacie, lebo sa nic nezapisalo')
  NxTest.assert(save.index('DocKey.foreign?') < save.index('rebuild_many'),
                'guard je PRED prestavbou skriniek')
end

NxTest.test('ŠT-3b-1: odmietnuty zapis NIC nezapise a formular sa nacita nanovo') do
  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  head = save[/\A.*?baseline_valid\?\(model\).*?\n          end\n/m].to_s
  # ŠT-3b-2c1: baseline vetva presla na LACNE ECHO sekcie — plny push okna ide
  # cez zber modelu a ten deduplikuje ID kopii, cize ODMIETNUTY zapis by model
  # ZMENIL (ten isty nalez ako P1 pri resete). `force: true` je tu podstatny:
  # pravidla na modeli sa zmenili, takze rozpisany formular UZ NEPLATI a MUSI
  # sa prekreslit — je to JEDINA vetva, kde sa rozpisane hodnoty vedome stracaju.
  NxTest.assert(head.include?('push_section_echo(model, force: true)'),
                'formular sa nacita nanovo ECHOM sekcie — bez dedupu a s vynutenym prekreslenim')
  NxTest.refute(head.include?('refresh_studio'),
                'ziadny plny push okna (jeho zber ZAPISUJE do modelu)')
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

# --- 1b-4: drobnosti sekcie Pravidlá (D1–D4) --------------------------------

NxTest.test('1b-4 (D2): pri `disabled` vypisuje riadok VITAZA, nie vsetky ulozene hodnoty') do
  rd = Noxun::Engine::RulesDialog
  base = { 'owner_id' => 'CAB-001', 'owner_name' => 'Dolná 600', 'owner_part_key' => '',
           'generic_type' => 'hinge', 'rule_id' => 'zavesy' }

  # Polia zaznamu su NEZAVISLE (D-93), ale neplatia naraz: `apply_overrides`
  # polozku pri `disabled` zahodi este PRED prepisom poctu aj dlzky.
  both = rd.hw_override_row(base.merge('disabled' => true, 'quantity' => 6))
  NxTest.refute(both['value'].include?('počet 6 ks'),
                'pocet, ktory sa nikdy nepouzije, sa netvari ako platny')
  NxTest.assert(both['value'].start_with?('vypnuté — nepočíta sa do súpisu'),
                'vitazom je vypnutie')
  NxTest.assert(both['value'].include?('uložený počet sa neuplatní'),
                'ale ulozena hodnota sa NEZAMLCI — sipka „vrátiť na pravidlo" zrusi aj ju')

  all3 = rd.hw_override_row(base.merge('disabled' => true, 'quantity' => 6,
                                       'nominal_length' => 420.0))
  NxTest.assert(all3['value'].include?('ani dĺžka sa neuplatnia'), 'plati to aj pre dlzku')
  NxTest.refute(all3['value'].include?('420'), 'a zamknuta dlzka sa tiez nevypisuje ako platna')

  only = rd.hw_override_row(base.merge('disabled' => true))
  NxTest.assert_equal('vypnuté — nepočíta sa do súpisu', only['value'],
                      'holé vypnutie ziadnu zatvorku nema')

  # ZAPNUTY zaznam sa nemeni ani o znak.
  live = rd.hw_override_row(base.merge('quantity' => 6, 'nominal_length' => 420.0))
  NxTest.assert_equal('počet 6 ks · dĺžka 420 mm', live['value'],
                      'bez `disabled` platia obe hodnoty a vypisuju sa obe')
  NxTest.assert_equal(nil, rd.hw_override_row(base), 'bezobsazny zaznam sa nekresli')

  # A je to ZRKADLO spravania buildera, nie nazor UI.
  hr = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_rules.rb'),
                 encoding: 'UTF-8')[/def apply_overrides.*?\n      end\n/m].to_s
  NxTest.assert(hr.index("next nil if ov['disabled'] == true") < hr.index('clamp_qty'),
                'builder polozku pri `disabled` zahodi PRED prepisom poctu — `disabled` vitazi')
end

NxTest.test('1b-4 (D3): poradie jantarovych riadkov je DETERMINISTICKE') do
  rd = Noxun::Engine::RulesDialog
  rows = [
    { 'owner_id' => 'CAB-010', 'owner_name' => '', 'part_key' => 'p1', 'role' => 'shelf',
      'name' => 'Polica', 'edges' => { 'L1' => 'ABS-X' } },
    { 'owner_id' => 'CAB-002', 'owner_name' => '', 'part_key' => 'p2', 'role' => 'shelf',
      'name' => 'Polica B', 'edges' => { 'L1' => 'ABS-X' } },
    { 'owner_id' => 'CAB-002', 'owner_name' => '', 'part_key' => 'p1', 'role' => 'shelf',
      'name' => 'Polica A', 'edges' => { 'L1' => 'ABS-X' } }
  ]
  order = lambda do |list|
    pay = rd.overrides_payload({ manual_overrides: { 'abs' => list, 'hardware' => [] } })
    pay['abs']['groups'].flat_map { |g| g['rows'].map { |r| [r['owner_id'], r['part_key']] } }
  end
  want = [%w[CAB-002 p1], %w[CAB-002 p2], %w[CAB-010 p1]]
  NxTest.assert_equal(want, order.call(rows), 'radi sa skrinka -> dielec')
  NxTest.assert_equal(want, order.call(rows.reverse),
                      'a INE poradie zberu (vlozena/zmazana skrinka) da TEN ISTY zoznam')
  NxTest.assert_equal(want, order.call(rows.rotate), 'v akomkolvek poradi')

  # Cislo v identite sa radi ako CISLO: `CAB-1000` patri ZA `CAB-999`.
  big = [{ 'owner_id' => 'CAB-1000', 'owner_name' => '', 'part_key' => 'p1', 'role' => 'shelf',
           'name' => 'A', 'edges' => { 'L1' => 'ABS-X' } },
         { 'owner_id' => 'CAB-999', 'owner_name' => '', 'part_key' => 'p1', 'role' => 'shelf',
           'name' => 'B', 'edges' => { 'L1' => 'ABS-X' } }]
  NxTest.assert_equal([%w[CAB-999 p1], %w[CAB-1000 p1]], order.call(big),
                      'inak by tisica skrinka skocila pred devatstodevadesiatu deviatu')

  # STROP sa aplikuje AZ PO radeni — inak by o tom, ktore riadky vidno,
  # rozhodovalo poradie entit v modeli.
  many = (1..(rd::MAX_OVERRIDE_ROWS + 3)).map do |i|
    { 'owner_id' => format('CAB-%03d', i), 'owner_name' => '', 'part_key' => 'p1',
      'role' => 'shelf', 'name' => "Polica #{i}", 'edges' => { 'L1' => 'ABS-X' } }
  end
  shown = lambda do |list|
    pay = rd.overrides_payload({ manual_overrides: { 'abs' => list, 'hardware' => [] } })
    pay['abs']['groups'].flat_map { |g| g['rows'].map { |r| r['owner_id'] } }
  end
  NxTest.assert_equal(shown.call(many), shown.call(many.shuffle),
                      'zastropovany zoznam ukazuje TIE ISTE riadky bez ohladu na poradie zberu')
  NxTest.assert_equal('CAB-001', shown.call(many.shuffle).first, 'a zacina od prvej skrinky')

  # Duplicitna identita (kandidat registra, KRONIKA 1b-3) sa radenim NEMENI:
  # dva riadky ostavaju DVA a maju pevne poradie.
  dup = [rows[1], rows[1].merge('name' => 'Kópia')]
  pay = rd.overrides_payload({ manual_overrides: { 'abs' => dup, 'hardware' => [] } })
  NxTest.assert_equal(2, pay['abs']['total'],
                      'radenie riadky NEDEDUPLIKUJE — zdvojenie pri duplicitnej identite je ' \
                      'samostatny nalez a tato zmena ho ani nerobi, ani neskryva')
end

NxTest.test('1b-4 (D1): katalog ABS pasok sa stava LENIVO') do
  rd = Noxun::Engine::RulesDialog
  src = ST3B_RULES_RB[/def overrides_payload\(collected\).*?\n        end\n/m].to_s
  NxTest.assert(src.include?('abs.empty? ||'),
                'prazdny zoznam ABS overridov katalog pasok NEPOTREBUJE')
  NxTest.refute(src.match?(/^\s+emap = defined\?\(ProductionCore\) \? ProductionCore\.edges_map : nil$/),
                'bezpodmienecne volanie je PREC (beralo sa pri KAZDOM pushi okna)')

  # Behavioralne: bez ABS riadkov sa `edges_map` nezavola ANI RAZ.
  calls = 0
  pc = Noxun::Engine::ProductionCore
  sc = pc.singleton_class
  sc.send(:alias_method, :orig_edges_map_1b4, :edges_map)
  pc.define_singleton_method(:edges_map) { calls += 1; {} }
  begin
    rd.overrides_payload({ manual_overrides: { 'abs' => [], 'hardware' => [
      { 'owner_id' => 'CAB-001', 'owner_part_key' => '', 'generic_type' => 'leg',
        'rule_id' => 'nohy', 'quantity' => 4 }
    ] } })
    NxTest.assert_equal(0, calls, 'zakazka bez rucnych hran za katalog pasok NEPLATI')

    rd.overrides_payload({ manual_overrides: { 'abs' => [
      { 'owner_id' => 'CAB-001', 'owner_name' => '', 'part_key' => 'p1', 'role' => 'shelf',
        'name' => 'Polica', 'edges' => { 'L1' => 'ABS-X' } }
    ], 'hardware' => [] } })
    NxTest.assert_equal(1, calls, 'prvy ABS riadok si ho vypyta — a PRAVE RAZ pre cely zoznam')
  ensure
    sc.send(:alias_method, :edges_map, :orig_edges_map_1b4)
    sc.send(:remove_method, :orig_edges_map_1b4)
  end
end

NxTest.test('1b-4 (D4): zaznam ABS overridu nenesie MRTVE polia') do
  nested = { 'p1' => st3b2_part('p1', 'shelf', 'Polica 1') }
  out = { 'abs' => [], 'hardware' => [] }
  Noxun::Engine::Bom.collect_manual_overrides(
    out, { 'part_overrides' => { 'p1' => { 'edges' => { 'L1' => 'ABS-1' } } } }, 'CAB-001', nested
  )
  row = out['abs'].first
  NxTest.assert_equal(%w[owner_id owner_name part_key role name edges], row.keys,
                      'zaznam nesie PRESNE to, z coho sa kresli jantarovy riadok')
  NxTest.refute(row.key?('material_id'),
                'material riadok nikdy nevypisal — hovori o ROZHODNUTI cloveka, nie o materiali')
  NxTest.refute(row.key?('pid'),
                'a persistent_id uz vobec: adresa „oka" je ZAMERNE identita (owner_id + part_key)')
  js = ST3B_RULES_JS[/function rdSelectOverride\(ownerId, partKey\)\{.*?\n  \}/m].to_s
  NxTest.assert(js.include?('rule_ref'), 'klient posiela identitu…')
  NxTest.refute(js.include?('pid'), '…a ziadne pids — mrtve pole by k nim len zvadzalo')
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
  # `\b` za otaznikom (`detached_twin?`) NESEDI — hranica slova tam nie je
  # a regex by ticho vratil prazdny retazec (test by potom strazil NIC).
  edge = name.end_with?('?', '!') ? '' : '\b'
  ST3B_RULES_RB[/def #{Regexp.escape(name)}#{edge}.*?\n        end\n/m].to_s
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
  NxTest.assert(ctx.include?(%q<DocKey.foreign?(data['model_guid'], model, tolerate_blank_client: true)>),
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
  NxTest.assert(rej.include?('push_section_echo(model)'),
                'odmietnutie nacita sekciu LACNYM ECHOM — bez zdvihu generacie a bez dedupu '                 '(detail v sade „review P1" nizsie)')
end

NxTest.test('ŠT-3b-2b (F13/F14): status hovori VYSLEDOK a odpojene dvojca sa neprehliadne') do
  abs = st3b2_rd_body('abs_rule_result')
  NxTest.assert(abs.include?('Store.config(part)'),
                'vysledok sa cita zo SNAPSHOTU po prestavbe — to iste, co ide do vyroby')
  NxTest.assert(abs.include?('abs_result_text('),
                'a SAMOTNY text sklada CISTA funkcia (meria ju fixtura v sade „review P2-4")')
  twin = st3b2_rd_body('detached_twin_note')
  NxTest.assert(twin.include?('vytiahnutý zo skrinky'),
                'odpojene dvojca sa PRIZNA — prestavba ho neprekresli a do vystupu ide po starom')
  NxTest.assert(st3b2_rd_body('handle_reset_abs').include?('detached_twin_note(model, cid, rk)'),
                'a kontroluje sa pri KAZDOM ABS resete (nikdy tichy uspech)')
  hw = st3b2_rd_body('hw_rule_result')
  NxTest.assert(hw.include?('hw_result_text('),
                'pocet z pravidla sklada CISTA funkcia (fixtura v sade „review P2-3")')
end

NxTest.test('ŠT-3b-2b (review #221): vyber podla `rule_ref` uz nerobi zbytocny zber modelu') do
  sel = ST3B2_PC_RB[/def do_select\(model, data, generation:, status:, repush:\).*?\n      end\n/m].to_s
  branch = sel[/elsif data\['rule_ref'\].*?\n        else/m].to_s
  NxTest.refute(branch.include?('fresh_collect'),
                'vetva oka hlada podla identity — plny sken modelu je cista rezia')
  NxTest.assert(sel.include?("if data['problem_key']\n          collected = fresh_collect(model)"),
                'zber sa robi AZ vo vetve, ktora ho naozaj potrebuje')
  NxTest.assert(sel.include?('refs_for(Bom.compute(fresh_collect(model)), data)'),
                'a vseobecna vetva ho ma dalej (BOM bez zberu neexistuje)')
end

# ---------------------------------------------------------------------------
# ŠT-3b-2b — REVIEW #222, kolo 1
#
# Co pribudlo a PRECO to grep neuchytil:
#   1. Odmietnuty klik MUTOVAL MODEL. Cesta odmietnutia siahala na plny push
#      okna, ten na zber modelu a ten na dedup kopii — cize odmietnutie
#      PRECISLOVALO skrinky a pridavalo krok Spat, kym hlaska tvrdila
#      „nič sa nezmenilo". Testy tela guardu to nemohli vidiet: chyba bola
#      v tom, CO robi odmietnutie POTOM.
#   2. Hlasky boli overene len grepom zdrojaka — mutacia (`if false` na vetve
#      „bez olepu", natvrdo vrateny pocet) presla zelena. Text sa preto sklada
#      v CISTYCH funkciach a tie sa meraju fixturami.
#   3. Zhoda vlastnika pri kovani nekopirovala identitu overridu (nil sedelo
#      s cimkolvek) — korpusovy reset zratal do statusu aj polozky CUDZICH
#      dielcov a povedal zly pocet.
#   4. Odpojene dvojca sa hladalo len podla suroveho `part_key` — dielec, ktory
#      ho nema (legacy `role_key`), by sa NEPRIZNAL. To je presne ten tichy
#      uspech, ktoremu ma F14 zabranit.

# VEDOMA UPRAVA (davka 1b-3, brana G bloku 1b): posledny assert tejto sady
# vyzadoval OPAK dnesneho stavu — trval na tom, ze `fresh_collect` obsahuje
# `dedup_copies`, teda ze CITANIE zapisuje do modelu. Bola to „dokazova" poistka
# proti kontrole prazdna (aby refutacie vyssie nemerali nic), lenze fixovala
# prave to spravanie, ktore brana G ruší. Nahrada meria TU ISTU vec z druhej
# strany: `fresh_collect` `dedup_copies` NESMIE obsahovat — a to je odteraz
# strazene vlastnou sadou `test_1b3_citanie.rb` nad CELOU UI vrstvou.
# Refutacie plneho pushu v zapisovych cestach OSTAVAJU — ich dovod sa len zmenil
# zo „zapisuje do modelu" na „zbytocne drahy a zdvihol by generaciu okna".
NxTest.test('ŠT-3b-2b (review P1): ODMIETNUTIE nesmie siahnut na model') do
  code = ST3B_RULES_RB.lines.reject { |l| l.strip.start_with?('#') }.join
  # Plny push okna smie ostat LEN v ceste ulozenia pravidiel z 3b-1; ZAPISOVE
  # resety a ich odmietnutia ho pouzit NESMU (cely prepocet okna + zdvih
  # generacie za odmietnuty klik, ktory nic nezmenil).
  %w[handle_reset_abs handle_reset_hw reset_context reject_reset].each do |m|
    body = st3b2_rd_body(m)
    NxTest.refute(body.include?('refresh_studio'),
                  "#{m}: ziadny plny push okna — odmietnutie nic nezmenilo, prepocet je zbytocny")
  end
  echo = st3b2_rd_body('push_section_echo')
  NxTest.assert(echo.include?('Bom.collect(model)'), 'echo cita model PRIAMO')
  NxTest.assert(echo.include?('RD.setSection'), 'a posiela ho vlastnym prijimacom sekcie')
  NxTest.assert(ST3B_RULES_JS.include?('setSection: function(r, force)'),
                'ktory na klientovi existuje — a vie aj VYNUTIT prekreslenie formulara')
  # 1b-3: dokaz, ze sa nekontroluje prazdno, ide odteraz OPACNE — citacia cesta
  # je cista a musi taka ostat.
  fc = ST3B2_PC_RB[/def fresh_collect\(model\).*?\n      end\n/m].to_s
  NxTest.assert(fc.include?('Bom.collect(model)'), '`fresh_collect` naozaj zbiera model')
  NxTest.refute(fc.include?('dedup_copies'),
                'a robi UZ LEN to — ziadny dedup, ziadny zapis pri citani (brana G, 1b-3)')
  # A odmietnutie nesmie zdvihnut generaciu okna (nic sa nezapisalo).
  NxTest.refute(st3b2_rd_body('push_section_echo').include?('bump'),
                'echo generaciu nezdviha — rozkliknute riadky inych sekcii ostavaju platne')
end

NxTest.test('ŠT-3b-2b (review P2-4): text ABS vysledku sa MERIA, nie greppuje') do
  rd = Noxun::Engine::RulesDialog
  NxTest.assert_equal('podľa pravidla bez olepu', rd.abs_result_text('shelf', {}),
                      'ziadna hrana = VEDOME bez olepu (kompakt, postforming, dekor bez pasky)')
  NxTest.assert_equal('podľa pravidla bez olepu',
                      rd.abs_result_text('shelf', { 'L1' => nil, 'L2' => '', 'W1' => nil, 'W2' => nil }),
                      'prazdne hodnoty su to iste — nie „olep bez pasky"')
  # Paska MIMO katalogu: surove id (neklame o hrubke).
  NxTest.assert_equal('podľa pravidla: predná ABS-X', rd.abs_result_text('shelf', { 'L1' => 'ABS-X' }),
                      'label hrany je z roly a hodnota surova, ked katalog pasku nepozna')
  NxTest.assert_equal('podľa pravidla: ľavá ABS-X', rd.abs_result_text('front_door', { 'L1' => 'ABS-X' }),
                      'ta ista hrana ma pri INEJ role INY nazov (L1 cela je ľavá)')

  # S katalogom: hrubka v mm. `Materials.edge` sa zastupuje, aby test nezavisel
  # od obsahu katalogu na disku.
  mat = Noxun::Engine::Materials
  mat.singleton_class.class_eval do
    alias_method :nx_orig_edge, :edge
    define_method(:edge) { |id| id.to_s.start_with?('ABS-') ? { 'thickness' => 1.0 } : nil }
  end
  begin
    NxTest.assert_equal('podľa pravidla: predná 1,0 mm', rd.abs_result_text('shelf', { 'L1' => 'ABS-1' }),
                        'hrubka sa cita z katalogu a pise s desatinnou CIARKOU')
    all4 = { 'L1' => 'ABS-1', 'L2' => 'ABS-2', 'W1' => 'ABS-3', 'W2' => 'ABS-4' }
    NxTest.assert_equal('podľa pravidla: všetky štyri hrany 1,0 mm', rd.abs_result_text('front_door', all4),
                        'olep DOOKOLA je JEDNA veta — nie styri rovnake kusy textu')
    NxTest.assert_equal('podľa pravidla: všetky štyri hrany 1,0 mm', rd.abs_result_text('free_panel', all4),
                        'a plati to aj pre neutralne labely dosky („pozdĺžna 1 · pozdĺžna 2…")')
    mixed = rd.abs_result_text('shelf', { 'L1' => 'ABS-1', 'L2' => 'INE' })
    NxTest.assert(mixed.include?('predná 1,0 mm') && mixed.include?('zadná INE'),
                  'rozne hodnoty sa vypisu PO HRANACH — zliatie by zamlcalo rozdiel')
  ensure
    mat.singleton_class.class_eval do
      alias_method :edge, :nx_orig_edge
      remove_method :nx_orig_edge
    end
  end
end

NxTest.test('ŠT-3b-2b (review P2-3): pocet z pravidla rata LEN polozky TOHO vlastnika') do
  rd = Noxun::Engine::RulesDialog
  items = [
    { 'generic_type' => 'hinge', 'rule_id' => 'zavesy', 'owner_part_key' => nil, 'quantity' => 2 },
    { 'generic_type' => 'hinge', 'rule_id' => 'zavesy', 'owner_part_key' => 'front:F1/wing:left',
      'quantity' => 3 },
    { 'generic_type' => 'hinge', 'rule_id' => 'zavesy', 'owner_part_key' => 'front:F2/wing:right',
      'quantity' => 4 },
    { 'generic_type' => 'hinge', 'rule_id' => 'INE', 'owner_part_key' => nil, 'quantity' => 9 },
    { 'generic_type' => 'leg', 'rule_id' => 'zavesy', 'owner_part_key' => nil, 'quantity' => 9 }
  ]
  # KORPUSOVY override (owner = nil): prazdny/chybajuci kluc sedi LEN s nil —
  # povodne `owner.nil? || ...` zratalo VSETKY tri polozky (2+3+4) a status
  # by povedal 9 ks tam, kde pravidlo dava 2.
  NxTest.assert_equal('podľa pravidla: 2 ks', rd.hw_result_text(items, nil, 'hinge', 'zavesy'),
                      'korpusovy zaznam nezbiera polozky cudzich dielcov')
  NxTest.assert_equal('podľa pravidla: 3 ks',
                      rd.hw_result_text(items, 'front:F1/wing:left', 'hinge', 'zavesy'),
                      'a dielcovy zaznam vidi LEN svoj dielec')
  NxTest.assert_equal('podľa pravidla sa tu nepočíta nič',
                      rd.hw_result_text(items, 'front:F9/wing:left', 'hinge', 'zavesy'),
                      'ked pravidlo pre tohto vlastnika nic nedava, POVIE sa to')
  NxTest.assert_equal('podľa pravidla sa tu nepočíta nič', rd.hw_result_text([], nil, 'hinge', 'zavesy'),
                      'prazdny snapshot tiez (prazdny riadok by vyzeral ako chyba)')
  # Prazdny RETAZEC je to iste co chybajuci kluc (vzor `present_str`) — inak by
  # sa korpusovy override rozpadol na dva rozne „vlastnikov".
  NxTest.assert_equal('podľa pravidla: 5 ks',
                      rd.hw_result_text([{ 'generic_type' => 'leg', 'rule_id' => 'nohy',
                                           'owner_part_key' => '', 'quantity' => 5 }],
                                        nil, 'leg', 'nohy'),
                      'prazdny `owner_part_key` = korpusova polozka')
end

NxTest.test('ŠT-3b-2b (review P2-6): dvojca sa hlada TOU ISTOU identitou ako v paneli') do
  rd = Noxun::Engine::RulesDialog
  make = lambda do |attrs|
    ent = NxTest::FakeEntity.new
    attrs.each { |k, v| ent.set_attribute('NOXUN', k, v) }
    ent
  end
  NxTest.assert_equal('zone:z1/shelf:1',
                      rd.twin_identity(make.call('part_key' => 'zone:z1/shelf:1'), 'CAB-001'),
                      'novy dielec ma part_key')
  NxTest.assert_equal('SHELF-2', rd.twin_identity(make.call('role_key' => 'SHELF-2'), 'CAB-001'),
                      'starsi LEGACY dielec ma len role_key — a musi sa najst tiez')
  NxTest.assert_equal('SIDE-L', rd.twin_identity(make.call('part_id' => 'CAB-001-SIDE-L'), 'CAB-001'),
                      'najstarsi ma len part_id — prefix skrinky sa odreze (vzor `fallback_role_key`)')
  NxTest.assert_equal('CUDZI-SIDE-L', rd.twin_identity(make.call('part_id' => 'CUDZI-SIDE-L'), 'CAB-001'),
                      'cudzi prefix sa NEODREZAVA (nepatri tejto skrinke)')
  NxTest.assert_equal('', rd.twin_identity(make.call({}), 'CAB-001'), 'dielec bez identity nesedi s nicim')
  body = st3b2_rd_body('detached_twin?')
  NxTest.assert(body.include?('twin_identity(i, cid)'),
                'hladanie ide cez tuto identitu, nie cez surovy `part_key`')
end

# ============================================================================
# ŠT-3b-2c1 — SERVEROVA VALIDACIA PRAVIDIEL (brana pred ulozenim)
#
# Co tato cast strazi (a preco to klikanim neoveris):
#   1. Klientska `rdValidate` je LEN to, co sa da povedat bez servera. Do
#      `handle_save` sa da dostat aj mimo nej (starsi cachovany DOM, in-SU
#      volanie, buduci iny klient) — brana musi stat NA SERVERI.
#   2. Vynutenie NESMIE byt v `normalize_rules`: ma dvanast volajucich a vacsina
#      CITA (load, project_rules, evaluate, seed-merge). Keby validovala, LEGACY
#      snapshot z .skp by sa pri CITANI ticho orezal — presne ta tichá strata
#      dat, ktorej ma brana zabranit.
#   3. Kriterium musi visiet na `kind`, nie na pritomnosti kluca `bands`:
#      `kind` je jedina autorita toho, ktora vetva vyhodnotenia sa spusti,
#      a `normalize_rules` nezname kluce ZACHOVAVA — zaznam z novsej verzie,
#      z cudzieho snapshotu alebo po zmene `kind` vo formulari teda smie niest
#      oba kluce naraz a validovat mu treba LEN to, co sa naozaj pouzije.
#   4. Klient a server musia mat ROVNAKE kriteria — inak vznikne formular,
#      ktory sa neda ulozit a nikto nevie preco (alebo naopak diera).
ST3B2C1_FIXTURE = JSON.parse(
  File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'rules_validation_parity.json'),
            encoding: 'UTF-8')
)

NxTest.test('ŠT-3b-2c1: `rules_problems` je CISTA brana — bez IO a bez zapisu') do
  hr = Noxun::Engine::HardwareRules
  NxTest.assert(hr.respond_to?(:rules_problems), 'funkcia existuje')
  body = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_rules.rb'),
                   encoding: 'UTF-8')[/def rules_problems\(rules\).*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'telo sa naslo')
  %w[write set_project_rules JsonFileStore model.set_attribute].each do |io|
    NxTest.refute(body.include?(io), "ziadne IO (#{io}) — je to CISTA funkcia")
  end
  NxTest.assert_equal([], hr.rules_problems(nil), 'nil vstup nespadne')
  NxTest.assert_equal([], hr.rules_problems(['nie je hash']), 'ani smetie v poli')
end

NxTest.test('ŠT-3b-2c1: kriterium visi na `kind`, nie na pritomnosti kluca `bands`') do
  hr = Noxun::Engine::HardwareRules
  # Seedove pravidlo vysuvov nesie OBOJE — podla kluca by sa mu validovali
  # pasma, ktore vobec nepouziva, a projekt by sa nedal ulozit.
  seed_slide = { 'rule_id' => 'vysuvy', 'output' => 'slide', 'kind' => 'fit_series',
                 'enabled' => true, 'series' => [400.0], 'bands' => [] }
  NxTest.assert_equal([], hr.rules_problems([seed_slide]),
                      'fit_series s prazdnymi `bands` je v poriadku')
  bands_rule = { 'rule_id' => 'zavesy', 'output' => 'hinge', 'kind' => 'bands',
                 'enabled' => true, 'bands' => [{ 'max' => 900.0, 'quantity' => 2 }] }
  problems = hr.rules_problems([bands_rule])
  NxTest.assert_equal(1, problems.length, 'derave pasma sa odmietnu')
  NxTest.assert_equal('zavesy', problems.first['rule_id'], 'nalez nesie ADRESU pravidla')
  NxTest.assert(problems.first['message'].include?('Závesy'),
                'a hlaska ho menuje recou stolara (pri desiatich pravidlach inak nevie, co opravit)')
  NxTest.assert(problems.first['message'].include?('všetko nad'), 'aj tym, CO chyba')

  # Neznamy `kind` z NOVSEJ verzie nesmie zablokovat ulozenie (forward-compat:
  # `normalize_rules` nezname kluce zachovava, brana ich nesmie zhodit).
  NxTest.assert_equal([], hr.rules_problems([{ 'rule_id' => 'x', 'output' => 'handle',
                                               'kind' => 'buduci_tvar', 'enabled' => true }]),
                      'pravidlo novsej verzie prejde')
end

NxTest.test('ŠT-3b-2c1: CITACIE cesty ostavaju NEDOTKNUTE — validuje sa LEN pri ulozeni') do
  hr_src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_rules.rb'),
                     encoding: 'UTF-8')
  norm = hr_src[/def normalize_rules\(rules\).*?\n      end\n/m].to_s
  NxTest.refute(norm.include?('rules_problems'),
                'normalize NEVALIDUJE — inak by sa legacy snapshot pri CITANI ticho orezal')
  %w[ensure_project_rules! merge_project_seed! project_seed_plan set_project_rules load].each do |m|
    body = hr_src[/def #{Regexp.escape(m)}(\(.*?\))?.*?\n      end\n/m].to_s
    NxTest.refute(body.include?('rules_problems'),
                  "#{m}: seed a stavba validaciu NEVOLAJU (builder nesmie odmietnut stavbu)")
  end
  # LEGACY snapshot sa MUSI dat precitat — validacia mu nesmie stat v ceste.
  legacy = [{ 'rule_id' => 'zavesy', 'output' => 'hinge', 'kind' => 'bands', 'enabled' => true,
              'bands' => [{ 'max' => 900, 'quantity' => 2 }] }]
  read_back = Noxun::Engine::HardwareRules.normalize_rules(legacy)
  NxTest.assert_equal(1, read_back.length, 'derave legacy pravidlo sa NACITA (a vyhodnoti)')
  NxTest.assert_equal(1, Noxun::Engine::HardwareRules.rules_problems(read_back).length,
                      'ale ULOZIT sa uz neda — az zapis je branou')

  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(save.include?('HardwareRules.rules_problems(rules)'), 'brana je v ceste ULOZENIA')
  NxTest.assert(save.index('normalize_rules') < save.index('rules_problems'),
                'a stoji AZ ZA normalizaciou — validuje sa presne to, co sa zapise')
  NxTest.assert(save.index('rules_problems') < save.index('rebuild_many'),
                'este PRED prestavbou skriniek')
  reject = save[/return set_status\("Pravidlá sa neuložili.*?\n/m].to_s
  NxTest.assert(reject.include?('return set_status'), 'odmietnutie sa povie NAHLAS')
  NxTest.refute(reject.include?('push_section_echo') || reject.include?('refresh_studio'),
                'a formular sa NEPREKRESLUJE — pouzivatel ma svoje hodnoty OPRAVIT, nie o ne prist')
end

NxTest.test('ŠT-3b-2c1 (review P2-2): brana ma v CELOM plugine PRAVE JEDNO volanie') do
  # Predosla verzia tohto guardu vymenovavala citacie metody PO MENE — a prave
  # preto neplatila: mutacia, ktora `rules_problems` zavolala v `project_rules`,
  # presla zelena, lebo ta metoda v zozname CHYBALA. Zoznam mien sa sam nedopise;
  # jedina spolahliva formulacia je „v celom plugine existuje PRESNE JEDNO
  # volanie — a to v zapisovej ceste".
  root = File.join(NxTest::ROOT, 'noxun_engine')
  hits = []
  Dir[File.join(root, '**', '*.rb')].sort.each do |file|
    code = File.read(file, encoding: 'UTF-8').lines
               .reject { |l| l.strip.start_with?('#') }.join
    rel = file.sub("#{NxTest::ROOT}/", '').tr('\\', '/')
    code.scan(/rules_problems/) { hits << rel }
  end
  in_core = hits.select { |c| c.end_with?('core/hardware_rules.rb') }
  outside = hits.reject { |c| c.end_with?('core/hardware_rules.rb') }
  NxTest.assert_equal(1, in_core.length,
                      'v `hardware_rules.rb` je LEN definicia (modul sa sam nevola)')
  NxTest.assert_equal(['noxun_engine/ui/rules_dialog.rb'], outside,
                      'a JEDINY volajuci v celom plugine je sekcia Pravidlá (zapisova cesta)')
  rd_code = ST3B_RULES_RB.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(1, rd_code.scan(/rules_problems/).length,
                      'aj v nom PRESNE RAZ — nikde inde v module')
  NxTest.assert(st3b2_rd_body('handle_save').include?('HardwareRules.rules_problems(rules)'),
                'a je to naozaj `handle_save`')
end

NxTest.test('ŠT-3b-2c1 (PARITA): server a klient maju ROVNAKE kriteria') do
  hr = Noxun::Engine::HardwareRules
  cases = ST3B2C1_FIXTURE['cases']
  NxTest.assert(cases.length >= 10, 'fixtura ma dost pripadov (inak parita nic nestrazi)')
  cases.each do |c|
    rules = hr.normalize_rules(c['rules'])
    got = !hr.rules_problems(rules).empty?
    NxTest.assert_equal(c['invalid'], got, "server: #{c['name']}")
  end
  # Ten isty subor cita aj JS sada — ked sa kriteria rozidu, padne prave jedna.
  js = File.read(File.join(NxTest::ROOT, 'tests', 'js', 'test_st3b_rules.js'), encoding: 'UTF-8')
  NxTest.assert(js.include?('rules_validation_parity.json'),
                'JS sada cita TU ISTU fixturu (inak by parita bola len na papieri)')
end

NxTest.test('ŠT-3b-2c1 (review P2-1): hlaska ADRESUJE pravidlo JEDNOZNACNE') do
  hr = Noxun::Engine::HardwareRules
  # Dve pravidla s TYM ISTYM vystupom su legalne (dva rozne uchytkove profily,
  # dve pasmove pravidla na zavesy) — samotny nazov typu by ukazoval na obe.
  rules = [
    { 'rule_id' => 'uchytky-hlavne', 'output' => 'handle', 'kind' => 'bands',
      'enabled' => true, 'bands' => [{ 'max' => 600.0, 'quantity' => 1 }] },
    { 'rule_id' => 'uchytky-vysoke', 'output' => 'handle', 'kind' => 'bands',
      'enabled' => true, 'bands' => [{ 'max' => 900.0, 'quantity' => 2 }] }
  ]
  msgs = hr.rules_problems(rules).map { |p| p['message'] }
  NxTest.assert_equal(2, msgs.length, 'obe pravidla su pokazene')
  NxTest.assert(msgs[0].include?('uchytky-hlavne') && msgs[1].include?('uchytky-vysoke'),
                'a KAZDA hlaska nesie identitu SVOJHO pravidla (nazov typu je pri oboch rovnaky)')
  NxTest.assert(msgs.uniq.length == 2, 'takze dve hlasky nie su na nerozoznanie')
  NxTest.assert(msgs[0].include?('Úchytky'), 'nazov PRE CLOVEKA v hlaske ostava')
  # Pravidlo bez `rule_id` normalizacia zahadzuje, ale brana nesmie spadnut ani
  # na surovom vstupe (in-SU / iny klient posiela, co chce).
  raw = hr.rules_problems([{ 'output' => 'hinge', 'kind' => 'bands', 'enabled' => true,
                             'bands' => [] }])
  NxTest.assert_equal(1, raw.length, 'aj zaznam bez identity sa odmietne')
  NxTest.assert(raw.first['message'].start_with?('Pravidlo „Závesy“'),
                'a hlaska je aspon o type (prazdna zatvorka by mätla)')
end

NxTest.test('ŠT-3b-2c1 (review NOTE 1): hlaska ma STROP — zvysok sa PRIZNA poctom') do
  rd = Noxun::Engine::RulesDialog
  probs = (1..7).map { |i| { 'rule_id' => "r#{i}", 'message' => "Chyba #{i}." } }
  txt = rd.problems_text(probs)
  NxTest.assert(txt.include?('Chyba 1.') && txt.include?('Chyba 3.'), 'prve tri sa vypisu')
  NxTest.refute(txt.include?('Chyba 4.'), 'stvrta uz nie (stavovy riadok nie je odsek)')
  NxTest.assert(txt.include?('a ďalšie 4'), 'ale zvysok sa PRIZNA — opravou prvej sa nekonci')
  short = rd.problems_text(probs.first(2))
  NxTest.assert_equal('Chyba 1. Chyba 2.', short, 'kratky zoznam ziadny suhrn nema')
  NxTest.assert_equal('', rd.problems_text([]), 'a prazdny nic')
end

NxTest.test('ŠT-3b-2c1 (review NOTE 2): nazvy kovania su JEDNA pravda (server = sekcia)') do
  hr = Noxun::Engine::HardwareRules
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'rules.js'), encoding: 'UTF-8')
  map = js[/function rdLabel\(t\)\{.*?\n  \}/m].to_s
  NxTest.assert(!map.empty?, 'klientska mapa sa nasla')
  # Ta ista hlaska o tom istom pravidle chodi raz z klienta (`rdValidate`) a raz
  # zo servera (`rules_problems`) — dva nazvy pre jednu vec su chyba.
  %w[leg hinge slide handle shelf_pin connector wall_hanger].each do |gt|
    server = hr.label_for(gt)
    client = map[/#{gt}\s*:\s*'([^']+)'/, 1].to_s
    NxTest.assert_equal(server, client, "nazov `#{gt}` musi byt na oboch stranach rovnaky")
  end
end

# ============================================================================
# ŠT-3b-2c2 — ODTLACOK PRAVIDIEL (`rules_rev`)
#
# Co tato cast strazi (a preco to klikanim neoveris):
#   1. Odtlacok pocita VYHRADNE server a LEN z `rules`. Keby siel z celeho
#      payloadu, zozltol by pri kazdom rucnom zasahu v Inspectore (menia sa
#      `overrides`, nie pravidla) a pouzivatel by nemohol ulozit pravidla,
#      lebo si medzitym prestavil hranu na dielci.
#   2. Klient si ho LEN drzi. Vlastny vypocet by NIKDY nesedel (Ruby `900.0`
#      vs JS `900`) — a mlcky by odmietal kazde ulozenie.
#   3. „Načítať globálne" odtlacok NEPREPISUJE: globalne predvolby nie su stav
#      projektu, takze ulozenie po nich by serveru tvrdilo, ze formular vznikol
#      z aktualnych pravidiel — a prepisalo by cudziu zmenu.
#   4. Baseline aj rev sa obnovuju AZ pri USPESNOM zostaveni payloadu. Zlyhane
#      zostavenie by inak roztvorilo nozice: server by mal novy stav, klient
#      stary, a kazde ulozenie by sa navzdy odmietalo.

NxTest.test('ŠT-3b-2c2: odtlacok pocita SERVER a LEN z pravidiel') do
  hr = Noxun::Engine::HardwareRules
  rules = [{ 'rule_id' => 'nohy', 'output' => 'leg', 'kind' => 'fixed',
             'enabled' => true, 'quantity' => 4 }]
  rev = hr.rules_rev(rules)
  NxTest.assert_equal(12, rev.length, 'kratky hash (vzor `HardwareCatalog.record_rev`)')
  NxTest.assert_equal(rev, hr.rules_rev(rules), 'ten isty vstup = ten isty odtlacok')
  changed = [rules.first.merge('quantity' => 5)]
  NxTest.assert(rev != hr.rules_rev(changed), 'zmena pravidla odtlacok ZMENI')
  # Normalizovany tvar: to iste pravidlo zapisane inak (symbol/retazec, poradie
  # klucov) ma dat TEN ISTY odtlacok — inak by sa formular odmietal sam od seba.
  loose = [{ 'quantity' => 4, 'kind' => 'fixed', 'output' => 'leg',
             'enabled' => true, 'rule_id' => 'nohy' }]
  NxTest.assert_equal(rev, hr.rules_rev(loose),
                      'iné poradie klucov toho isteho pravidla = ten isty odtlacok')
  NxTest.assert_equal(12, hr.rules_rev(nil).length,
                      'nil vstup nespadne — vrati odtlacok prazdneho zoznamu')

  # Payload: rev ide LEN z `rules`. Kontrolujeme ZDROJAK, lebo `rules_payload`
  # potrebuje model — a prave zamena zdroja by bola tichá regresia.
  pay = ST3B_RULES_RB[/def rules_payload\(model, collected = nil\).*?\n        end\n/m].to_s
  NxTest.assert(pay.include?('rev = HardwareRules.rules_rev(rules)'),
                'odtlacok sa pocita z PRAVIDIEL')
  NxTest.refute(pay.include?('rules_rev(payload)') || pay.include?('rules_rev(collected)'),
                'nikdy z celeho payloadu ani zo zberu — inak by zozltol pri zasahu v Inspectore')
  NxTest.assert(pay.include?("'rules_rev' => rev"), 'a ide klientovi v payloade')
end

NxTest.test('ŠT-3b-2c2: rev je DRUHA vrstva popri baseline, nie jeho nahrada') do
  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(save.include?('baseline_valid?(model)'), 'baseline guard OSTAVA')
  NxTest.assert(save.include?("rev = data['rules_rev'].to_s"), 'a rev je DALSI guard')
  NxTest.assert(save.index('baseline_valid?(model)') < save.index("data['rules_rev']"),
                'baseline sa pyta prvy (je lacnejsi a chyti aj undo)')
  # Review #224 (Codex P2): PRAZDNY rev sa UZ NETOLERUJE, ked server odtlacok
  # vydal. Povodna premisa zadania („baseline tuto vetvu kryje") NEPLATI —
  # `@baseline_*` je stav MODULU, takze kazdy push ho posunie na aktualny stav
  # modelu a stary cachovany DOM by cez baseline presiel a prepisal novsie
  # pravidla. Tolerancia ostava LEN na stav, kym server ziadny odtlacok nevydal.
  NxTest.assert(save.include?('unless @baseline_rev.to_s.empty?'),
                'guard sa spusti, ked server odtlacok UZ vydal')
  NxTest.assert(save.include?('if rev.empty?'),
                'a vtedy je PRAZDNY rev DOVOD ODMIETNUTIA (nie tolerancia)')
  NxTest.assert(save.include?('predošlej verzie pluginu'),
                'hlaska povie, co sa deje — stare okno nema ako poslat odtlacok')
  NxTest.assert(save.include?('Zavri a otvor Štúdio znova'),
                'a co ma pouzivatel urobit (stary DOM prijimac echa nema)')
  guard = save[/unless @baseline_rev\.to_s\.empty\?.*?\n          end\n/m].to_s
  NxTest.assert(guard.scan('push_section_echo(model, force: true)').length == 2,
                'obe odmietnutia prekreslia formular ECHOM (bez dedupu, s omladenim odtlacku)')
  NxTest.assert(save.index("data['rules_rev']") < save.index('rebuild_many'),
                'guard je PRED prestavbou skriniek')
  valid = ST3B_RULES_RB[/def baseline_valid\?\(model\).*?\n        end\n/m].to_s
  NxTest.refute(valid.include?('rev'),
                'baseline sa NEPREPISUJE revom — su to dve NEZAVISLE vrstvy')
end

NxTest.test('ŠT-3b-2c2: OPAKOVANY konflikt ma DRUHE znenie (a uspech ho nuluje)') do
  rd = Noxun::Engine::RulesDialog
  rd.instance_variable_set(:@rev_conflicts, 0)
  first = rd.rev_conflict_status
  second = rd.rev_conflict_status
  NxTest.assert(first != second, 'druhy konflikt za sebou znie INAK')
  NxTest.assert(first.include?('načítaný nanovo'), 'prvy hovori, co sa stalo')
  NxTest.assert(second.include?('ZNOVA') && second.include?('súbežne'),
                'druhy prizna, ze pravidla meni nieco ine — inak by sa pouzivatel tocil dokola')
  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(save.include?('@rev_conflicts = 0'), 'uspesne ulozenie seriu konfliktov ukonci')
  NxTest.assert(save.index('@rev_conflicts = 0') > save.index('rebuild_many'),
                'a to AZ po skutocnom zapise')
  rd.instance_variable_set(:@rev_conflicts, 0)
end

NxTest.test('ŠT-3b-2c2: klient odtlacok LEN drzi a vracia — nepocita ho') do
  js = ST3B_RULES_JS
  NxTest.assert(js.include?('rules_rev: d.rules_rev'), 'rdSetState si ho ulozi z payloadu')
  NxTest.assert(js.include?('rules_rev: RD_META.rules_rev'), 'a rdSaveRules ho vrati')
  code = js.lines.reject { |l| l.strip.start_with?('//') }.join
  %w[sha1 SHA1 hash( digest].each do |calc|
    NxTest.refute(code.include?(calc), "klient odtlacok NEPOCITA (#{calc}) — Ruby a JS by sa nikdy nezhodli")
  end
  set_rules = js[/setRules: function\(rules, _source\)\{.*?\n    \},/m].to_s
                .lines.reject { |l| l.strip.start_with?('//') }.join
  NxTest.assert(!set_rules.empty?, 'telo `setRules` sa naslo')
  NxTest.refute(set_rules.include?('rules_rev'),
                '„Načítať globálne" odtlacok NEPREPISUJE — inak by ulozenie po nom prepisalo cudziu zmenu')
end

NxTest.test('ŠT-3b-2c2 (review #224, Codex P2): odtlacok NESTRACA `false`') do
  hr = Noxun::Engine::HardwareRules
  # `normalize_rules` NEZNAME kluce zachovava (forward-compat), takze v pravidle
  # moze zit lubovolne pole novsej verzie. Ked take pole zmeni hodnotu z `false`
  # na `null`, MUSI sa to na odtlacku prejavit — inak by suberzna zmena
  # prekĺzla cez guard a ticho prepisala cudziu upravu.
  base  = [{ 'rule_id' => 'x', 'output' => 'leg', 'kind' => 'fixed',
             'enabled' => true, 'quantity' => 4, 'buduce_pole' => false }]
  nulled = [base.first.merge('buduce_pole' => nil)]
  truthy = [base.first.merge('buduce_pole' => true)]
  NxTest.assert(hr.rules_rev(base) != hr.rules_rev(nulled),
                '`false` a `null` NIE SU to iste — odtlacok ich rozlisi')
  NxTest.assert(hr.rules_rev(base) != hr.rules_rev(truthy), 'a `false` vs `true` tiez')
  # A `enabled: false` (zname pole) tiez musi mat vlastny odtlacok.
  off = [base.first.merge('enabled' => false)]
  NxTest.assert(hr.rules_rev(base) != hr.rules_rev(off),
                'vypnute pravidlo ma iny odtlacok nez zapnute')
  canon = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_rules.rb'),
                    encoding: 'UTF-8')[/def canonical_rules\(value\).*?\n      end\n/m].to_s
  NxTest.assert(canon.include?('value.key?(k)'),
                'hodnota sa vybera podla PRITOMNOSTI kluca, nie cez `||` (to by zhltlo `false`)')
end

NxTest.test('ŠT-3b-2c2 (review #224): odmietnutie stareho DOM je SAMOLIECIVE') do
  # Odmietnutie neposiela pouzivatela do slepej ulicky: server pri nom vzdy
  # posle echo s CERSTVYM odtlackom, takze klient, ktory prijimac echa MA,
  # ma po nom vsetko, co potrebuje na uspesny druhy pokus.
  save = ST3B_RULES_RB[/def handle_save\(payload\).*?\n        end\n/m].to_s
  guard = save[/unless @baseline_rev\.to_s\.empty\?.*?\n          end\n/m].to_s
  NxTest.assert(guard.index('push_section_echo') < guard.index('return set_status'),
                'echo ide PRED hlaskou (klient dostane data aj vysvetlenie)')
  echo = st3b2_rd_body('push_section_echo')
  NxTest.assert(echo.include?("'rules_rev' => rev") || ST3B_RULES_RB.include?("'rules_rev' => rev"),
                'a to echo nesie odtlacok (inak by druhy pokus dopadol rovnako)')
end
