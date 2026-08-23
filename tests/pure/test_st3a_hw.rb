# frozen_string_literal: true
# ŠT-3a-1 — sekcia KOVANIE (`hw`) v okne Štúdio: KANÁL (server) a jeho hranice.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. Whitelist akcii sekcie je UZAVRETY a obsahuje LEN katalogove zapisy.
#      Keby sa don dostal `hws_map_project` (alebo `hws_reset_project` /
#      `hws_merge_seed`), sekcia by ZAPISOVALA DO MODELU cestou, ktoru v tejto
#      davke nikto neotestoval — a zapis do zakazky sa nedá vziať späť tym, ze
#      sa na neho zabudlo.
#   2. `ready` v zozname BYT NESMIE: Studio registruje callbacky pod TYMI
#      ISTYMI menami, takze by prepisal svoj vlastny `ready` — okno by
#      prestalo dostat prvy push a ostalo by prazdne. Toto je presne ten druh
#      chyby, ktoru vidis az po spusteni SketchUpu.
#   3. ZIVOTNOST asynchronneho behu. Overenie ceny a nahlad z Demosu dobiehaju
#      z casovaca uz PO navrate z `dispatch`. Ked ich adresat medzitym zmizol
#      (zatvorene Studio, prepnuty dokument, odchod zo sekcie), vysledok nesmie
#      prist — a hlavne nesmie prist NOVEJ instancii okna (ABA).
#   4. `after_sets_change` NESMIE ist cez `StudioDialog.on_model_changed`.
#      To je vetva PREPNUTIA DOKUMENTU (prevesi observer, zdvihne zapadku
#      celeho katalogu materialov) — po ulozeni setu by sa Studio tvarilo, ze
#      sa vymenil dokument.
#   5. Katalogovy zapis NESMIE zdvihnut generaciu okna. Inak by oprava ceny
#      kovania zneplatnila rozkliknuty riadok Kusovnika a rozrobeny export.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
# Telo akcii katalogu kovania zije v `HardwareCatalogDialog` (modul sa
# NEPREMENUVA) — sada overuje kontrakt OBOCH modulov. Parse-time tu ziadne
# SketchUp API nie je (vsetko je vnutri metod).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog') if NxTest.headless?
# Sada porovnava mena akcii OBOCH sekcii (kolizia by prepisala cudzi callback),
# takze `MaterialsDialog` potrebuje aj vtedy, ked bezi SAMOSTATNE (review P2 #7).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog') if NxTest.headless?

ST3A_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
ST3A_HW_RB     = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog.rb'),
                           encoding: 'UTF-8')
ST3A_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
ST3A_SHELL_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'),
                           encoding: 'UTF-8')
ST3A_HW_JS     = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hw_catalog.js'),
                           encoding: 'UTF-8')
ST3A_HWSETS_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hw_sets.js'),
                           encoding: 'UTF-8')
ST3A_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# Zdrojak BEZ komentarov — mena zaniknutych veci v komentaroch ZAMERNE ostavaju.
ST3A_STUDIO_CODE = ST3A_STUDIO_RB.lines.reject { |l| l.strip.start_with?('#') }.join
ST3A_HW_CODE     = ST3A_HW_RB.lines.reject { |l| l.strip.start_with?('#') }.join
ST3A_HW_JS_CODE  = ST3A_HW_JS.lines.reject { |l| l.strip.start_with?('//') }.join

# --- 1) `hw` je sekcia a premostenie navigacie zaniklo -----------------------

NxTest.test('ŠT-3a-1: `hw` je ZIVA sekcia vo VSETKYCH TROCH zrkadlach') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = ST3A_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = ST3A_SHELL_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert(rb.include?('hw'), 'Ruby je autorita zoznamu sekcii')
  NxTest.assert_equal(rb, js, 'studio.js je jeho zrkadlo')
  NxTest.assert_equal(rb, shell, 'a shell.js (deep-link `openStudio` z panela) tiez')
end

NxTest.test('ŠT-3a-1: premostenie navigacie `hw` ZANIKLO, ale OKNO zije dalej') do
  st = Noxun::Engine::StudioDialog
  NxTest.refute(st::WINDOW_BRIDGES.key?('hw'),
                'jeden kluc nesmie byt zaroven sekcia aj premostenie navigacie')
  NxTest.assert(st::BRIDGE_STATUS['hw'].to_s.empty?, 'a nesmie mat ani hlasku premostenia')
  nav = ST3A_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  item = nav[/\{ id: 'hw'.*?\},/m].to_s
  NxTest.assert(!item.empty?, 'polozka navigacie sa nasla')
  NxTest.refute(item.include?('bridge:'), 'polozka Kovanie uz nie je premostenie')
  NxTest.refute(item.include?('disabled:'), 'a nie je ani neaktivna')
  NxTest.assert(item.include?("ic: 'hammer'"),
                'ikona = hammer, ta ista ako rail Inspectora (kontrakt „Ikony navigácie")')
end

NxTest.test('ŠT-3a-2: okno Katalog kovania ZANIKLO — a s nim VSETKY jeho vstupy') do
  # Zaniknut musi CELE, nie len z navigacie: kym existuje HTML, menu polozka
  # alebo panelove tlacidlo, ziju nad jednym katalogom dve UI s roznym stavom.
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog.html')),
                'HTML satelitu je zmazane')
  %w[DLG_KEY ensure_dialog register_callbacks UI::HtmlDialog win_js
     @dialog def\ show].each do |gone|
    NxTest.refute(ST3A_HW_CODE.include?(gone), "#{gone} je z hardware_catalog_dialog.rb PREC")
  end
  st = Noxun::Engine::StudioDialog
  NxTest.refute(st.const_defined?(:HW_BRIDGE_STATUS),
                'hlaska premostenia do okna zanikla spolu s nim')
  NxTest.refute(ST3A_STUDIO_CODE.include?('hw_open_window'),
                'premostenie zo sekcie do okna zaniklo (callback aj telo)')
  NxTest.refute(ST3A_HWSETS_JS.include?('hws-open-window'), 'klient uz nema kam premostovat')
  NxTest.refute(ST3A_HWSETS_JS.include?('HWS_PROJ_RO ='),
                'read-only rezim predvolieb projektu zanikol — sekcia ich ovlada priamo')
  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  NxTest.assert(main.include?("menu.add_item('Katalóg kovania') { StudioDialog.show(open_section: 'hw') }"),
                'zauzivana polozka menu ostava, ale otvara SEKCIU')
  NxTest.refute(main.include?('HardwareCatalogDialog.show'), 'okno sa uz nikde neotvara')
  panel_rb = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
                    .lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.refute(panel_rb.include?('open_hardware_catalog'),
                'panelovy callback satelitu zanikol — tlacidlo ide deep-linkom openStudio')
  panel_html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  NxTest.assert(panel_html.include?(%q(onclick="openStudio('hw')")),
                'tlacidlo „Katalóg kovania…" vedie do sekcie')
  hw_js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'), encoding: 'UTF-8')
               .lines.reject { |l| l.strip.start_with?('//') }.join
  NxTest.refute(hw_js.include?('openHardwareCatalogDialog'), 'a jeho JS obal tiez zanikol')
  css = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
             .gsub(%r{/\*.*?\*/}m, ' ')
  NxTest.refute(css.include?('.pvtabs'), 'CSS tabov satelitu zaniklo s jeho jedinym konzumentom')
  NxTest.refute(css.include?('#hwTabs'), 'a identifikator pasu tabov tiez')
  NxTest.refute(ST3A_HWSETS_JS.include?('function hwsSetTab'),
                'prepinac tabov OKNA zanikol — pohlady sekcie riadi lista')
end

NxTest.test('ŠT-3a-2 (B1): vetva prepnutia dokumentu OSTAVA — mení sa len telo') do
  # Precedens `MaterialsDialog.on_model_changed`: modul uz ziadne UI nevlastni,
  # ale MUSI zneplatnit beziaci serverovy beh — inak by vysledok stahovania
  # z Demosu dobehol do NOVEHO dokumentu s datami stareho.
  obs = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer.rb'),
                  encoding: 'UTF-8')
  NxTest.assert(obs.include?('HardwareCatalogDialog.on_model_changed(model)'),
                'broadcast prepnutia dokumentu vetvu drzi dalej')
  body = ST3A_HW_RB[/def on_model_changed\(_model\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('section_bump_session'), 'telo zneplatni beziaci beh sekcie')
  NxTest.assert(body.include?('@section_running = nil'), 'a zhasne priznak behu')
  NxTest.refute(body.include?('push_sets'), 'refresh UI uz nerobi — to je vec plneho pushu Studia')
end

# --- 2) whitelist akcii sekcie ----------------------------------------------

NxTest.test('ŠT-3a-1: akcie sekcie maju JEDINY whitelist a JEDINE telo') do
  hw = Noxun::Engine::HardwareCatalogDialog
  NxTest.assert(hw.const_defined?(:SECTION_ACTIONS), 'whitelist zije v HardwareCatalogDialog')
  actions = hw::SECTION_ACTIONS
  NxTest.assert(actions.frozen?, 'zoznam je uzavrety')
  %w[hw_search hw_create hw_patch hw_delete hw_check_price hw_apply_price
     hw_demos_search hw_demos_preview hw_demos_cancel hw_demos_create
     hws_save_set hws_delete_set hws_map_global].each do |a|
    NxTest.assert(actions.include?(a), "sekcia musi vediet #{a}")
  end
  NxTest.refute(ST3A_STUDIO_RB.include?('HW_ACTIONS = %w['),
                'druhy zoznam v Studiu by sa casom rozisiel — cita sa ten z HardwareCatalogDialog')
  NxTest.assert(ST3A_STUDIO_RB.include?('hw_actions.each { |name| cb(dlg, name)'),
                'callbacky vznikaju Z NEHO')
end

NxTest.test('ŠT-3a-2: MODELOVE zapisy predvolieb projektu su UZ v sekcii') do
  actions = Noxun::Engine::HardwareCatalogDialog::SECTION_ACTIONS
  %w[hws_map_project hws_merge_seed hws_reset_project].each do |a|
    NxTest.assert(actions.include?(a), "sekcia musi vediet #{a}")
  end
  runner = ST3A_HW_RB[/def run_section_action\(key, payload\).*?\n        end\n/m].to_s
  %w[handle_map_project handle_merge_seed handle_reset_project].each do |h|
    NxTest.assert(runner.include?(h), "#{h} ma vetvu v ceste sekcie")
  end
  # KAZDY z troch je 1 zmena = 1 krok Spat a KAZDY ma serverovy `model_guid`
  # guard — zapis zo zastaraneho UI sa musi odmietnut, nie prejst.
  %w[handle_map_project handle_merge_seed handle_reset_project].each do |m|
    body = ST3A_HW_RB[/def #{m}\(payload\).*?\n        end\n/m].to_s
    NxTest.assert(body.include?("data['model_guid'].to_s != model.guid.to_s"),
                  "#{m}: guard identity dokumentu")
    NxTest.assert(body.include?('resync_sets'),
                  "#{m}: odmietnutie MUSI obnovit sekciu (inak posle dalsi zapis so starym stavom)")
  end
  map = ST3A_HW_RB[/def handle_map_project\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(map.include?("model.start_operation('NOXUN: Predvoľba setu kovania', true)") &&
                map.include?('model.commit_operation'),
                'predvolba setu = JEDNA operacia (1 krok Spat)')
  NxTest.assert(map.include?('after_sets_change(model)'),
                'a po nej PLNY push so zdvihom generacie (model sa naozaj zmenil)')
end

NxTest.test('ŠT-3a-2 (F8): merge_seed NO-OP nerobi push ani nezdviha generaciu') do
  body = ST3A_HW_RB[/def handle_merge_seed\(payload\).*?\n        end\n/m].to_s
  noop = body[/unless res == :updated.*?end\n/m].to_s
  NxTest.assert(!noop.empty?, 'no-op ma vlastnu vetvu')
  NxTest.refute(noop.include?('after_sets_change'),
                'NIC sa nezmenilo — plny prepocet by bol zbytocny a zdvih generacie by ' \
                'zneplatnil rozkliknuty riadok Kusovnika po akcii, ktora nic neurobila')
  NxTest.assert(noop.include?('nič sa nedopĺňalo'), 'status to povie nahlas')
  NxTest.assert(body.index('unless res == :updated') < body.index('after_sets_change(model)'),
                'push ide AZ v uspesnej vetve')
end

NxTest.test('ŠT-3a-1: `ready` NIE JE akciou sekcie — prepisal by callback Studia') do
  actions = Noxun::Engine::HardwareCatalogDialog::SECTION_ACTIONS
  NxTest.refute(actions.include?('ready'),
                'Studio registruje callbacky pod TYMI ISTYMI menami — `ready` by prepisal jeho vlastny')
  # Prvotny stav sekcie preto nesie payload Studia (vzor `mat`).
  push = ST3A_STUDIO_RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  NxTest.assert(push.include?('hw: hw_payload(model)'), 'sekcia dostava stav plnym pushom')
  # A ziadne meno akcie sa nesmie zrazit s callbackmi, ktore Studio uz ma.
  own = ST3A_STUDIO_RB.scan(/cb\(dlg, '([a-z_]+)'\)/).flatten
  clash = actions & own
  NxTest.assert_equal([], clash,
                      "mena akcii sekcie sa nesmu zrazit s vlastnymi callbackmi Studia (#{clash.inspect})")
  mat = Noxun::Engine::MaterialsDialog::SECTION_ACTIONS
  NxTest.assert_equal([], actions & mat, 'ani s akciami sekcie Materialy')
end

# --- 3) adresat odpovede -----------------------------------------------------

NxTest.test('ŠT-3a-1: odpoved dostane TEN, KTO sa pytal') do
  disp = ST3A_HW_RB[/def dispatch\(name, payload, sink\).*?\n        end\n/m].to_s
  NxTest.assert(disp.include?('SECTION_ACTIONS.include?(key)'),
                'klient posiela iba meno — co sa smie zavolat, rozhoduje server')
  NxTest.assert(disp.include?('with_client(sink)'), 'a odpoved sa presmeruje na volajuceho')
  wc = ST3A_HW_RB[/def with_client\(sink\).*?\n        end\n/m].to_s
  NxTest.assert(wc.include?('ensure'),
                'vynimka v handleri nesmie nechat sink viset — dalsia odpoved by odisla cudziemu')
  js = ST3A_HW_RB[/def js\(script\).*?\n        end\n/m].to_s
  NxTest.assert(js.include?('sink.call(script) if sink'), 'sink ma prednost')
  # ŠT-3a-2 (B3): bez sinku uz nie je kam ist inam — okno zaniklo.
  NxTest.assert(js.include?('studio_js(script)'), 'bez neho ide vsetko do Studia')
  NxTest.refute(ST3A_HW_CODE.include?('def win_js'), 'kanal okna zanikol')
  NxTest.assert(ST3A_HW_RB.include?('StudioDialog.hw_js(script)'),
                'do sekcie sa pise VEREJNYM mostom (kanalove `js` Studia je private)')
  NxTest.assert(ST3A_STUDIO_RB.include?('def hw_js(script)'), 'a ten most existuje')
end

NxTest.test('ŠT-3a-1: `dispatch` NEPUSTI vynimku do klienta bez slova') do
  hw = Noxun::Engine::HardwareCatalogDialog
  got = []
  sink = ->(script) { got << script.to_s }
  hw.dispatch('hw_totalne_vymyslena', '{}', sink)
  NxTest.assert(got.first.to_s.include?('Neznáma akcia'),
                'neznama akcia sa odmietne NAHLAS (klient inak caka navzdy)')
end

# --- 4) zivotnost asynchronneho behu ----------------------------------------

NxTest.test('ŠT-3a-2 (F7): beh zomiera so session tokenom (zatvorenie · model · odchod)') do
  hw = Noxun::Engine::HardwareCatalogDialog
  # Zjednodusenie po zaniku okna NESMIE stratit ABA guard: token sa zachytava
  # pri STARTE behu, nie az pri jeho dobehnuti.
  target = hw.run_target
  NxTest.assert_equal([:session], target.keys, 'ciel nesie UZ LEN session token')
  NxTest.refute(target.key?(:kind), 'rozlisenie okno/sekcia zaniklo s oknom')

  before = hw.instance_variable_get(:@section_session).to_i
  hw.on_ui_closed
  after_close = hw.instance_variable_get(:@section_session).to_i
  NxTest.assert(after_close > before, 'zatvorenie Studia zneplatni beziaci fetch')
  hw.on_model_changed(nil)
  after_model = hw.instance_variable_get(:@section_session).to_i
  NxTest.assert(after_model > after_close, 'prepnutie dokumentu tiez')
  hw.cancel_runs_on_leave
  NxTest.assert(hw.instance_variable_get(:@section_session).to_i > after_model,
                'a odchod zo sekcie tiez')
  NxTest.refute(hw.target_alive?({ session: before }),
                'vysledok so starym tokenom sa ZAHODI (ABA)')
end

NxTest.test('ŠT-3a-1: odchod zo sekcie POCAS behu sa priznane hlasi (a druhy uz mlci)') do
  hw = Noxun::Engine::HardwareCatalogDialog
  sent = []
  hw.singleton_class.class_eval do
    alias_method :nx_studio_js_orig_st3a, :studio_js
    define_method(:studio_js) { |script| sent << script.to_s; true }
  end
  begin
    # Priznak sa zapaluje VYHRADNE cez `mark_running` (od kola 2 nesie identitu
    # behu) — rucne nastaveny retazec by testoval tvar, ktory uz neexistuje.
    hw.mark_running('overenie ceny z Demosu')
    hw.cancel_runs_on_leave
    NxTest.assert(sent.any? { |x| x.include?('opustil si sekciu Kovanie') },
                  'odchod POCAS behu sa priznane hlasi')
    sent.clear
    hw.cancel_runs_on_leave
    NxTest.assert(sent.empty?,
                  'druhy odchod uz nema co rusit — prepinanie sekcii nesmie prepisovat status')
  ensure
    sc = hw.singleton_class
    sc.class_eval do
      alias_method :studio_js, :nx_studio_js_orig_st3a
      remove_method :nx_studio_js_orig_st3a
    end
    hw.instance_variable_set(:@section_running, nil)
  end
end

NxTest.test('ŠT-3a-1: asynchronne cesty naozaj pouzivaju `run_target`, nie `@dialog`') do
  %w[handle_check_price handle_demos_preview].each do |m|
    body = ST3A_HW_RB[/def #{m}\(payload\).*?\n        end\n/m].to_s
    NxTest.assert(body.include?('target = run_target'), "#{m}: adresat sa zapamata pri STARTE")
    NxTest.assert(body.include?('target_alive?(target)'), "#{m}: a pred emitom sa overi")
    NxTest.refute(body.include?('@dialog.equal?(dlg)'),
                  "#{m}: stary okno-guard uz nesmie rozhodovat sam (sekcia by nikdy nedostala vysledok)")
  end
  search = ST3A_HW_RB[/def handle_demos_search\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(search.include?('target_alive?(target)'),
                'refresh sitemap cache je tiez dlhy beh — a jeho vysledok tiez ma adresata')
end

# --- 4b) ŠT-3a-3: undo kontrakt modelových zápisov -------------------------

NxTest.test('ŠT-3a-3: vynimka medzi start_operation a commit NENECHA otvorenu operaciu') do
  # Bez rescue ostala operacia OTVORENA — dalsi zapis do modelu by sa do nej
  # pribalil a JEDEN krok Spat by vratil OBA. Kontrakt „1 zmena = 1 krok Spat"
  # by tak padol na zapise, ktory s tym prvym nema nic spolocne.
  helper = ST3A_HW_RB[/def abort_open_operation\(model, state\).*?\n        end\n/m].to_s
  NxTest.assert(!helper.empty?, 'zatvaranie operacie ma JEDNU cestu')
  NxTest.assert(helper.include?('state[:open]'),
                'rusi sa VYHRADNE operacia, ktoru handler otvoril a este nezavrel')
  NxTest.assert(helper.index('state[:open] = false') < helper.index('model.abort_operation'),
                'priznak padne PRED abortom — opakovany rescue nesmie abortovat druhykrat')

  %w[handle_map_project handle_merge_seed handle_reset_project].each do |m|
    body = ST3A_HW_RB[/def #{m}\(payload\).*?\n        end\n/m].to_s
    NxTest.assert(body.include?('op = { open: false }'), "#{m}: priznak otvorenej operacie")
    NxTest.assert(body.include?('op[:open] = true'), "#{m}: zapina sa PO start_operation")
    NxTest.assert(body.include?('op[:open] = false'), "#{m}: a gasne PO commite")
    resc = body[/rescue StandardError => e.*/m].to_s
    NxTest.assert(resc.include?('abort_open_operation(model, op)'),
                  "#{m}: vynimka zavrie otvorenu operaciu")
    NxTest.assert(body.include?('raise e'), "#{m}: chyba ide dalej (klient dostane hlasku z `cb`)")
    code = body.lines.reject { |l| l.strip.start_with?('#') }.join
    NxTest.refute(code.include?('model.abort_operation'),
                  "#{m}: NIKDY priamy abort — po commite by zrusil zapis, ktory sa uz potvrdil")
  end
end

NxTest.test('ŠT-3a-3: odmietnuty `reset_project` NEROBI plny push') do
  body = ST3A_HW_RB[/def handle_reset_project\(payload\).*?\n        end\n/m].to_s
  code = body.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert(code.include?('resync_sets'),
                'sekcia dostane cerstvy stav — hlaska hovori o zlyhani a zoznam uz nemusi platit')
  # Plny push smie byt PRAVE JEDEN a PRAVE v uspesnej vetve: `after_sets_change(nil)`
  # by po zlyhanom zapise prepocital cely kusovnik pre nic.
  NxTest.assert_equal(1, code.scan(/after_sets_change/).length,
                      'plny push je v metode PRAVE RAZ')
  NxTest.assert(code.include?('after_sets_change(model)'),
                'a je to vetva USPECHU (model sa naozaj zmenil)')
  # `resync_sets` je v metode DVAKRAT (guard prepnuteho dokumentu + zlyhany
  # zapis) — obe su zotavovacie vetvy, obe patria sekcii.
  NxTest.assert_equal(2, code.scan(/resync_sets/).length,
                      'obe odmietnutia obnovia sekciu (prepnuty dokument aj zlyhany zapis)')
end

# --- 5) refresh cesty --------------------------------------------------------

NxTest.test('ŠT-3a-1 (nalez auditu): `after_sets_change` uz NEJDE cez `on_model_changed`') do
  body = ST3A_HW_RB[/def after_sets_change\(model = nil\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'cesta sa nasla')
  NxTest.refute(body.include?('StudioDialog.on_model_changed'),
                'to je vetva PREPNUTIA DOKUMENTU — prevesila by observer a poslala cely katalog materialov')
  NxTest.assert(body.include?('StudioDialog.refresh_if_open(bump: !model.nil?)'),
                'kniznicny zapis bez bumpu, MODELOVY zapis (predvolby projektu) so zdvihom')
  # Meno zaniknutej cesty smie ostat v HISTORICKEJ poznamke — kontroluje sa KOD.
  NxTest.refute(body.lines.reject { |l| l.strip.start_with?('#') }.join.include?('push_sets'),
                'ŠT-3a-2: vetva okna zanikla — sekcia dostava sety plnym pushom')
  NxTest.assert(body.include?('Panel.push_hardware_sets'),
                'panel ZIJE dalej a jeho selecty setov musia byt cerstve')
end

NxTest.test('ŠT-3a-1: `push_items` obsluhuje OBA ciele a NEDVIHA generaciu') do
  body = ST3A_HW_RB[/def push_items\(refresh_studio: true\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'cesta sa nasla')
  NxTest.refute(body.include?('win_js'), 'ŠT-3a-2: vetva okna zanikla')
  NxTest.assert(body.include?('StudioDialog.push_hw_catalog(payload)'),
                'sekcia dostava katalogove echo — jediny ciel')
  NxTest.assert(body.include?('bump: false'),
                'katalogovy zapis nemeni model — pending klik ani rozrobeny export nesmie zastarat')
  code = body.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(1, code.scan(/items_payload/).length,
                      'payload sa stava RAZ — druhy by znamenal druhy vypocet row_rev')
  echo = ST3A_STUDIO_RB[/def push_hw_catalog\(payload = nil\).*?\n        end\n/m].to_s
  NxTest.assert(echo.include?('NX.setHwCatalog'), 'echo posiela LEN katalog do klienta')
  NxTest.refute(echo.include?('@generation'), 'a generacie sa NEDOTYKA')
  NxTest.refute(echo.include?('fresh_collect'), 'ani model neprepocitava')
end

NxTest.test('ŠT-3a-1 (review P1 #1): ZOTAVOVACIE vetvy setov obnovia OBE UI') do
  # `hws_save_set` aj `hws_delete_set` su v SECTION_ACTIONS, takze odmietnuty
  # zapis moze prist ZO SEKCIE. Keby sa obnovilo len okno, hlaska by tvrdila
  # „obnovené", ale sekcia by drzala STARU `revision` — dalsi pokus by spadol
  # na tom istom konflikte donekonecna (a `:not_found` by v nej nespravilo NIC).
  resync = ST3A_HW_RB[/def resync_sets.*?\n        end\n/m].to_s
  NxTest.assert(!resync.empty?, 'zotavovacia cesta ma vlastne meno (nie je to `push_sets`)')
  NxTest.refute(resync.include?('win_js'), 'ŠT-3a-2: vetva okna zanikla')
  NxTest.assert(resync.include?('StudioDialog.push_hw_sets(sets_payload)'),
                'sekcia dostane cerstvu `revision` — inak slucka konfliktov')
  code = resync.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(1, code.scan(/sets_payload/).length,
                      'payload sa stava RAZ — druhy by znamenal druhy `HardwareSets.load`')
  # ŠT-3a-2 (B2): `push_sets` (win-only) zanikol a VSETKYCH pat jeho volani
  # v zotavovacich vetvach MODELOVYCH handlerov preslo sem.
  NxTest.refute(ST3A_HW_CODE.include?("\n            push_sets\n"),
                'ziadna zotavovacia vetva uz nepise do zaniknuteho okna')
  %w[handle_map_project handle_merge_seed handle_reset_project].each do |m|
    b = ST3A_HW_RB[/def #{m}\(payload\).*?\n        end\n/m].to_s
    NxTest.assert(b.include?('resync_sets'), "#{m}: odmietnutie obnovi SEKCIU")
  end
  NxTest.refute(code.include?('refresh_if_open'),
                'NIC sa nezapisalo — plny push Studia by bol zbytocny prepocet kusovnika')
  echo = ST3A_STUDIO_RB[/def push_hw_sets\(payload = nil\).*?\n        end\n/m].to_s
  NxTest.assert(echo.include?('NX.setHwSets'), 'echo ma vlastny prijimac')
  NxTest.refute(echo.include?('@generation'), 'a generacie sa NEDOTYKA')
  NxTest.assert(ST3A_HW_JS.include?('NX.setHwSets = function(data)'),
                'klient ho vie prijat (ten isty `HWSETS.init` ako okno)')
  # Vsetky STYRI zotavovacie vetvy musia ist novou cestou.
  save = ST3A_HW_RB[/def handle_set_save\(payload\).*?\n        end\n/m].to_s
  del  = ST3A_HW_RB[/def handle_set_delete\(payload\).*?\n        end\n/m].to_s
  NxTest.assert_equal(2, save.scan(/resync_sets/).length,
                      'save: `:conflict` aj neznáme zlyhanie obnovia obe UI')
  NxTest.assert_equal(2, del.scan(/resync_sets/).length,
                      'delete: `:conflict` aj `:not_found` tiez')
  NxTest.refute(save.include?("\n            push_sets\n"), 'a stara okno-only cesta tam uz nie je')
  NxTest.refute(del.include?("\n            push_sets\n"), 'ani v mazani')
end

NxTest.test('ŠT-3a-1 (review kolo 2, P2-1): priznak behu nesie IDENTITU — cudzi beh ho nezhasne') do
  # SLED, ktory to zachytava (grep na ` if ` ho nezachytil):
  #   A = overenie ceny (`@gen`), B = nahlad z Demosu (`@demos_gen`).
  #   Su to DVE nezavisle pocitadla nad JEDNYM priznakom, takze podmienka na
  #   generaciu unikala na obe strany — zahodene A zhaslo CUDZIE zive B
  #   (odchod potom o zruseni mlcal), a A zabite konkurencnou generaciou
  #   z OKNA sa neupratalo (odchod vypisal falosne „Zrušené: …").
  hw = Noxun::Engine::HardwareCatalogDialog
  running = -> { hw.instance_variable_get(:@section_running) }
  begin
    hw.instance_variable_set(:@section_running, nil)
    a = hw.mark_running('overenie ceny z Demosu')
    b = hw.mark_running('náhľad položky z Demosu')
    NxTest.assert(!a.nil? && !b.nil? && a != b, 'kazdy beh dostane VLASTNU identitu')

    # (a) UNIK DNU: dobehne zahodene A, kym B este bezi.
    hw.clear_running(a)
    NxTest.assert(running.call.is_a?(Hash) && running.call['id'] == b,
                  'zahodeny beh A NESMIE zhasnut priznak beziaceho B')
    NxTest.assert_equal('náhľad položky z Demosu', running.call['label'],
                        'a hlaska pri odchode musi hovorit o B')

    # (b) UNIK VON: B dobehne (aj ked ho zabila cudzia generacia) a upratie SA.
    hw.clear_running(b)
    NxTest.assert(running.call.nil?, 'vlastny beh priznak zhasne — ziadne falosne „Zrušené"')

    # Vyslovne zrusenie pouzivatelom gasi bez ohladu na identitu.
    hw.mark_running('náhľad položky z Demosu')
    hw.clear_running
    NxTest.assert(running.call.nil?, 'zrusenie pouzivatelom zhasina to, co prave bezi')

    # Po zaniku okna uz ziadny „cudzi" beh neexistuje — jediny bezec je
    # sekcia, a tu chrani identita `run_id` (vyssie).
  ensure
    hw.instance_variable_set(:@section_running, nil)
  end
end

NxTest.test('ŠT-3a-1 (review kolo 2, P2-1): kazdy dlhy beh sekcie ma `run_id` a gasi sa PRED guardom') do
  # Bez `run_id` by identita nemala odkial prist; bez poradia (gasit PRED
  # guardom adresata) by mrtve Studio nechalo priznak visiet.
  %w[handle_check_price handle_demos_preview].each do |m|
    body = ST3A_HW_RB[/def #{m}\(payload\).*?\n        end\n/m].to_s
    NxTest.assert(body.include?('run_id = mark_running('), "#{m}: beh si berie identitu")
    NxTest.assert(body.include?('clear_running(run_id)'), "#{m}: a gasi VYHRADNE seba")
    NxTest.assert(body.index('clear_running(run_id)') < body.index('next unless'),
                  "#{m}: gasi sa PRED guardom adresata (mrtve Studio nie je dovod nechat priznak)")
  end
  # `handle_demos_search` (single-flight refresh sitemapy) guard dovtedy NEMAL.
  search = ST3A_HW_RB[/def handle_demos_search\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(search.include?('run_id = mark_running('), 'aj stahovanie zoznamu produktov')
  NxTest.assert(search.include?('clear_running(run_id)'), 'a gasi sa rovnako')
  cancel = ST3A_HW_RB[/def handle_demos_cancel\(_payload\).*?\n        end\n/m].to_s
  NxTest.assert(cancel.include?('clear_running') && !cancel.include?('clear_running('),
                'vyslovne zrusenie ZAMERNE bez identity — gasi to, co prave bezi')
end

NxTest.test('ŠT-3a-1: prepocet cien si plny push robi SAM (ziadny dvojity prepocet)') do
  proc_body = ST3A_STUDIO_RB[/def price_refresh_after_proc.*?\n        end\n/m].to_s
  NxTest.assert(proc_body.include?('HardwareCatalogDialog.push_items(refresh_studio: false)'),
                'inak by sa cely kusovnik prepocital dvakrat za sebou')
  NxTest.assert(proc_body.include?('push_state'), 'plny push robi tato cesta sama')
end

# --- 6) payload sekcie -------------------------------------------------------

NxTest.test('ŠT-3a-1: CELY katalog chodi len pri prvom pushi, po prepnuti modelu a po „Obnoviť"') do
  pay = ST3A_STUDIO_RB[/def hw_payload\(model\).*?\n        end\n/m].to_s
  NxTest.assert(pay.include?("'sets' => HardwareCatalogDialog.sets_payload"),
                'sety chodia v KAZDOM pushi — riadia nakupny zoznam sekcie Nákup')
  NxTest.assert(pay.include?("out['catalog'] = HardwareCatalogDialog.state_payload if @hw_full_pending"),
                'inak by sa `row_rev` kazdej polozky pocital pri KAZDOM prepocte kusovnika')
  NxTest.assert(pay.include?("Engine.log_error(e, 'StudioDialog.hw_payload')"),
                'zlyhanie payloadu sekcie sa NEZAMLCUJE — inak niet stopy, preco je prazdna')
  NxTest.assert(ST3A_STUDIO_RB.include?("@hw_full_pending = false if sent && data[:hw].is_a?(Hash) && data[:hw]['catalog']"),
                'zapadka padne AZ ked katalog naozaj odosiel klientovi')
  changed = ST3A_STUDIO_RB[/def on_model_changed\(model\).*?\n        end\n/m].to_s
  NxTest.assert(changed.include?('@hw_full_pending = true'),
                'novy dokument = katalog sa posle cely (mohlo ho zmenit ZIJUCE okno)')
  refresh = ST3A_STUDIO_RB[/def do_refresh_bom.*?\n        end\n/m].to_s
  NxTest.assert(refresh.include?('@hw_full_pending = true'),
                'rucne „Obnoviť" je JEDINA cesta k cerstvemu katalogu — inak by tlacidlo klamalo')
  closed = ST3A_STUDIO_RB[/@dialog\.set_on_closed do.*?\n          end\n/m].to_s
  NxTest.assert(closed.include?('@hw_full_pending = true'),
                'dalsie otvorenie musi dostat katalog cely')
  NxTest.assert(closed.include?('HardwareCatalogDialog.on_ui_closed'),
                'a beziaci fetch sekcie zomiera s oknom')
end

# --- 7) UI kontrakt sekcie ---------------------------------------------------

NxTest.test('ŠT-3a-1: modaly sekcie ziju MIMO tela sekcie') do
  NxTest.assert(ST3A_STUDIO_HTML.include?('<div id="hwModalRoot">'),
                'kotva modalov je vlastna (vzor #matModalRoot)')
  root = ST3A_STUDIO_HTML[/<div id="hwModalRoot">.*?\n<\/div>/m].to_s
  NxTest.assert(root.include?('id="hwDelModal"'), 'potvrdenie mazania polozky')
  body = ST3A_STUDIO_HTML[/<template id="hwBodyTpl">.*?<\/template>/m].to_s
  NxTest.assert(!body.empty?, 'telo sekcie je SABLONA — klonuje sa RAZ')
  NxTest.refute(body.include?('nxmodal'),
                'v tele sekcie nesmie byt ziadny modal — prekreslenie by ho zhodilo')
  %w[hwList hwNewForm hwTabItems hwTabSets hwTabProj hwRoBanner].each do |id|
    NxTest.assert(body.include?(%(id="#{id}")), "uzol #{id} je v tele sekcie")
  end
  NxTest.refute(body.include?('id="hwSearch"'),
                'hladanie patri do LISTY sekcie, nie do obsahu')
  NxTest.refute(body.include?('id="hwTabs"'),
                'taby okna zanikli — pohlady su segmentom v liste (Š16)')
  NxTest.assert(ST3A_HW_JS.include?('function hwToolsHtml(st)'),
                'listu kresli cista funkcia (testuje ju tests/js/test_st3a_hw.js)')
end

NxTest.test('ŠT-3a-1: banner nudzoveho rezimu je PRVY riadok obsahu') do
  body = ST3A_STUDIO_HTML[/<template id="hwBodyTpl">.*?<\/template>/m].to_s
  NxTest.assert(body.index('id="hwRoBanner"') < body.index('id="hwList"'),
                'inak sa o read-only katalogu dozvies az po skrolovani')
end

NxTest.test('ŠT-3a-1: cache-bust presunutych skriptov sedi s VERSION a poradie je zavazne') do
  ver = Noxun::Engine::VERSION
  NxTest.assert(ST3A_STUDIO_HTML.include?("js/hw_catalog.js?v=#{ver}"),
                'CEF cachuje js — `?v=` musi byt presne VERSION')
  NxTest.assert(ST3A_STUDIO_HTML.include?("js/hw_sets.js?v=#{ver}"), 'to iste pre sety')
  NxTest.assert(ST3A_STUDIO_HTML.index('window.NX_HW_SECTION') <
                ST3A_STUDIO_HTML.index('js/hw_catalog.js'),
                'priznak sekcie musi byt nastaveny PRED nacitanim suboru')
  NxTest.assert(ST3A_STUDIO_HTML.index('js/hw_sets.js') < ST3A_STUDIO_HTML.index('js/hw_catalog.js'),
                'hw_sets.js pred hw_catalog.js (ten mu zapina read-only rezim predvolieb)')
  NxTest.assert(ST3A_STUDIO_HTML.index('js/studio.js') < ST3A_STUDIO_HTML.index('js/hw_catalog.js'),
                'a AZ ZA studio.js — obaluje jeho NX.setStudio')
  NxTest.assert(ST3A_STUDIO_HTML.index('js/proj_materials.js') <
                ST3A_STUDIO_HTML.index('js/hw_catalog.js'),
                'kazdy dalsi obal musi vidiet ten predchadzajuci')
end

NxTest.test('ŠT-3a-2 (F6): `sketchup.ready` z hw_catalog.js ZANIKOL CELY') do
  # V okne bol tento subor POSLEDNY a jeho `ready` znamenal „HTML je nacitane".
  # Okno zaniklo; v Studiu `ready` posiela `studio.js` (`window.onload`)
  # a druhe volanie by prinutilo okno poslat CELY payload dvakrat.
  NxTest.refute(ST3A_HW_JS_CODE.include?('sketchup.ready('),
                'volanie je PREC (vzor `proj_materials.js` po ŠT-2b)')
  # Ziadne INE volanie `sketchup.*` sa pri nacitani suboru nesmie vykonat —
  # vsetky ostatne su vnutri funkcii (odsadene aspon 4 medzerami).
  top = ST3A_HW_JS_CODE.lines.select { |l| l =~ /\bsketchup\.[a-z_]+\(/ && l[/\A */].length < 4 }
  NxTest.assert_equal([], top.map(&:strip),
                      'pri nacitani sa uz nevola NIC')
  NxTest.assert(ST3A_STUDIO_HTML.include?('window.NX_HW_SECTION = true'),
                'priznak ostava ako citatelne prihlasenie sa do rezimu sekcie')
  NxTest.refute(ST3A_HWSETS_JS.include?('sketchup.ready'),
                'hw_sets.js `ready` nikdy neposielal a ani nesmie zacat')
end

NxTest.test('ŠT-3a-1: odchod zo sekcie ma OBE cesty (navigacia aj deep-link)') do
  NxTest.assert(ST3A_STUDIO_JS.include?("studioSec === 'hw' && id !== 'hw'"),
                'studioGoSection ohlasi odchod zo sekcie Kovanie')
  NxTest.assert(ST3A_STUDIO_JS.include?("studioSec === 'hw' && ST.open_section !== 'hw'"),
                'a deep-link zo servera tiez')
  NxTest.assert_equal(2, ST3A_STUDIO_JS.scan(/hwOnLeaveSection\(\)/).length,
                      'obe cesty volaju TEN ISTY odchodovy hook')
  NxTest.assert(ST3A_HW_JS.include?('sketchup.hw_leave'), 'a klient to hlasi SERVERU (ten beh rusi)')
  leave = ST3A_HW_JS[/function hwOnLeaveSection\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(leave.index('hw_leave') < leave.index('hwCloseModals'),
                'poradie: najprv server (zrusi a povie preco), az potom lokalne zatvorenie modalov')
  NxTest.assert(ST3A_STUDIO_RB.include?("cb(dlg, 'hw_leave')"), 'callback existuje')
  body = ST3A_STUDIO_RB[/def do_hw_leave\(_payload = nil\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('HardwareCatalogDialog.cancel_runs_on_leave'),
                'a rusi beziaci fetch')
end

NxTest.test('ŠT-3a-1: telo aj listu sekcie kresli VYHRADNE hw_catalog.js') do
  body_fn = ST3A_STUDIO_JS[/function renderBody\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(body_fn.include?("studioSec === 'hw'") && body_fn.include?('hwRenderBody()'),
                'telo sekcie `hw` kresli hwRenderBody — studio.js si ho nekresli sam')
  tools_fn = ST3A_STUDIO_JS[/function renderTools\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(tools_fn.include?("studioSec === 'hw'") && tools_fn.include?('hwRenderTools(staleFlag)'),
                'a listu hwRenderTools — s jantarovym priznakom zo `staleFlag` (jedina autorita)')
  NxTest.assert(ST3A_HW_JS.include?('function hwRenderBody()'), 'telo je JEDEN klonovany uzol')
  NxTest.assert(ST3A_HW_JS.include?("HW_BODY.id = 'hwBody'"), 'a ma vlastnu identitu')
end
