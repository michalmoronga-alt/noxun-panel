# frozen_string_literal: true
# ŠT-4a — NASTAVENIA (`sup` · `bset` · `about`) ako sekcie Štúdia a ZÁNIK
# POSLEDNÉHO SATELITU.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. Sadzby su GLOBALNE a su VSTUPOM ROZPOCTU — po ich ulozeni MUSI Studio
#      prepocitat cisla. Keby ta cesta zanikla spolu s oknom, rozpocet by
#      ukazoval stare sumy a clovek by to zistil az na objednavke.
#   2. BASELINE REVIZIA (optimisticky zamok) je jediny dovod, preco sa dva
#      subezne zapisy nemozu ticho prepisat. Presun do sekcie ju nesmie stratit.
#   3. Sekcia dostava plny push pri KAZDEJ zmene modelu (okno ho dostavalo len
#      pri otvoreni a po ulozeni). Rozpisane sadzby preto MUSIA push prezit —
#      inak by ticho zmizli uprostred pisania.
#   4. Zanik okna musi byt UPLNY: html, `UI::HtmlDialog`, `DLG_KEY`, menu,
#      ⚙ cesta v jadre — a NAVYSE cela masineria premosteni, lebo toto bol
#      POSLEDNY satelit (dokaz zaniku premosteni je v test_st1a_studio.rb).
#   5. „O plugine" je JEDEN OBSAH s DVOMA VSTUPMI (kontrakt Š19) — dve kopie
#      markupu by sa pri prvej uprave rozisli.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync') if NxTest.headless?

ST4A_SUP_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog.rb'),
                        encoding: 'UTF-8')
ST4A_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
ST4A_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio_settings.js'),
                    encoding: 'UTF-8')
ST4A_ABOUT_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'about.js'),
                          encoding: 'UTF-8')
ST4A_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')
ST4A_PANEL_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'),
                            encoding: 'UTF-8')
ST4A_MAIN_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')

def st4a_body(name)
  ST4A_SUP_RB[/def #{Regexp.escape(name)}\b.*?\n        end\n/m].to_s
end

# --- 1) ZANIK OKNA -----------------------------------------------------------

NxTest.test('ŠT-4a: okno „Nastavenia rozpočtu" ZANIKLO — a bol to POSLEDNY satelit') do
  %w[UI::HtmlDialog DLG_KEY ensure_dialog register_dialog_fit set_on_closed].each do |gone|
    NxTest.refute(ST4A_SUP_RB.include?(gone), "#{gone} v module uz nie je")
  end
  %i[show ensure_dialog register_callbacks push_state].each do |m|
    NxTest.refute(Noxun::Engine::SupplierSettingsDialog.respond_to?(m),
                  "`SupplierSettingsDialog.#{m}` uz neexistuje")
  end
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings.html')),
                'HTML okna je zmazane (inak by zilo druhe UI nad tym istym suborom)')
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'supplier_settings.js')),
                'a jeho klient tiez')
  # Modul ZOSTAVA (audit #21) — je to jedina serverova autorita nastaveni
  # a premenovanie by rozbilo kazdy `defined?` guard aj kazdy odkaz.
  NxTest.assert(defined?(Noxun::Engine::SupplierSettingsDialog),
                'serverovy modul zije dalej (NEPREMENUVA sa)')
  NxTest.assert(ST4A_MAIN_RB.include?("Sketchup.require 'noxun_engine/ui/supplier_settings_dialog'"),
                'a loader ho nacitava')
end

NxTest.test('ŠT-4a: VSTUPNE BODY vedu do SEKCIE, nie do okna') do
  NxTest.assert(ST4A_MAIN_RB.include?("menu.add_item('Nastavenia rozpočtu') { StudioDialog.show(open_section: 'bset') }"),
                'zauzivana polozka menu ostava, ale otvara sekciu')
  NxTest.refute(ST4A_MAIN_RB.include?('SupplierSettingsDialog.show'),
                'nikde uz nie je volanie `show` zaniknuteho okna')
  core = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'), encoding: 'UTF-8')
  NxTest.refute(core.include?('def open_budget_settings'),
                '⚙ cesta jadra k satelitu zanikla (prepnutie sekcie je klientske)')
  NxTest.refute(ST4A_STUDIO_RB.include?("cb(dlg, 'budget_settings')"),
                'a s nou aj callback okna')
  bud = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'), encoding: 'UTF-8')
  NxTest.assert(bud.include?("studioGoSection('bset')"), '⚙ v liste Rozpoctu prepina SEKCIU')
  NxTest.refute(bud.include?('sketchup.budget_settings'), 'a uz nevola server')
end

# --- 2) KANAL SEKCIE ---------------------------------------------------------

NxTest.test('ŠT-4a: akcie sekcie maju JEDINY whitelist a prefixovane mena') do
  sd = Noxun::Engine::SupplierSettingsDialog
  NxTest.assert(sd.const_defined?(:SECTION_ACTIONS), 'whitelist zije v module')
  actions = sd::SECTION_ACTIONS
  NxTest.assert(actions.frozen?, 'zoznam je uzavrety')
  NxTest.assert_equal(%w[ss_save ss_reload], actions, 'ulozenie + nacitanie nanovo — nic viac')
  # `save`/`reload`/`ready` su prilis vseobecne mena na to, aby zili v JEDNOM
  # priestore callbackov okna vedla akcii ostatnych sekcii.
  %w[save reload ready].each do |bare|
    NxTest.refute(actions.include?(bare), "hole meno `#{bare}` by prepisalo cudzi callback")
  end
  own = ST4A_STUDIO_RB.scan(/cb\(dlg, '([a-z_]+)'\)/).flatten
  NxTest.assert_equal([], actions & own, 'mena akcii sa nesmu zrazit s callbackmi Studia')
  %w[MaterialsDialog HardwareCatalogDialog RulesDialog TemplatesDialog].each do |mod|
    other = Noxun::Engine.const_get(mod)::SECTION_ACTIONS
    NxTest.assert_equal([], actions & other, "ani s akciami sekcie #{mod}")
  end
  run = st4a_body('run_section_action')
  actions.each { |a| NxTest.assert(run.include?("when '#{a}'"), "#{a} ma telo") }
  NxTest.assert(ST4A_STUDIO_RB.include?('settings_actions.each { |name| cb(dlg, name)'),
                'callbacky vznikaju Z NEHO (druhy zoznam v Studiu by sa rozisiel)')
end

NxTest.test('ŠT-4a: `dispatch` NEPUSTI neznamu akciu ani vynimku bez slova') do
  got = []
  Noxun::Engine::SupplierSettingsDialog.dispatch('ss_vymyslena', '{}', ->(s) { got << s.to_s })
  NxTest.assert(got.any? { |s| s.include?('Neznáma akcia') }, 'neznama akcia = hlaska, nie ticho')
  with = st4a_body('with_client')
  NxTest.assert(with.include?('ensure'),
                'sink sa vracia v `ensure` — inak by ho zdedila NASLEDUJUCA odpoved')
end

# --- 3) SADZBY SU VSTUP ROZPOCTU (refresh cesta) -----------------------------

NxTest.test('ŠT-4a: ulozenie sadzieb PREPOCITA Studio (kontrakt refresh ciest)') do
  save = st4a_body('handle_save')
  # Dlh 1b-A: `handle_save` uz nevola `refresh_studio` priamo — ide cez
  # `refresh_and_report`, ktory podla VYSLEDKU prepoctu vetvi hlasku. Cesta
  # prepoctu je ta ista, len sa uz nepotvrdzuje nieco, co neprebehlo.
  NxTest.assert(save.include?('refresh_and_report'), 'po uspesnom zapise sa Studio prepocita')
  NxTest.assert(st4a_body('refresh_and_report').include?('refresh_studio'),
                'a `refresh_and_report` naozaj prepocitava (nie je to len hlaska)')
  # `refresh_and_report` je aj v guarde revizie (formular sa nacita nanovo),
  # preto sa poradie meria na POSLEDNOM vyskyte — tom v uspesnej vetve.
  NxTest.assert(save.index('patch_active!') < save.rindex('refresh_and_report'),
                'v uspesnej vetve az PO zapise (nie pred nim)')
  NxTest.assert(save.rindex("js('SS.saved()')") < save.rindex('refresh_and_report'),
                'a potvrdenie klientovi ide pred prepoctom (rozpisane sa zahadzuju len po zapise)')
  refresh = st4a_body('refresh_studio')
  NxTest.assert(refresh.include?('StudioDialog.refresh_if_open(bump: bump)'),
                'je to TA ISTA cesta, aku mal satelit')
  NxTest.assert(refresh.include?('bump: true'),
                'generacia sa ZDVIHA — zmenil sa VSTUP vypoctu, nie rozpocet sam')
  reload = st4a_body('handle_reload')
  NxTest.assert(reload.include?('refresh_and_report'), 'nacitanie nanovo prepocita rovnako')
end

NxTest.test('ŠT-4a: BASELINE REVIZIA prezila presun do sekcie') do
  save = st4a_body('handle_save')
  NxTest.assert(save.include?("data['revision'].to_s != current"),
                'zapis sa porovnava s CERSTVOU reviziou skladu')
  NxTest.assert(save.index('revision') < save.index('patch_active!'),
                'guard bezi PRED zapisom')
  NxTest.assert(save.include?('Nastavenia sa medzitým zmenili'),
                'a odmietnutie povie PRECO')
  pay = st4a_body('settings_payload')
  NxTest.assert(pay.include?('@baseline_revision = rev'), 'payload obnovuje baseline')
  NxTest.assert(pay.rindex('@baseline_revision = rev') > pay.index('SupplierSettings.revision'),
                'AZ PO uspesnom zostaveni (inak by sa server a klient rozisli)')
end

NxTest.test('ŠT-4a: payload sekcii NEPOTREBUJE model a chodi plnym pushom') do
  NxTest.skip!('payload cita realny %APPDATA%') unless NxTest.headless?

  data = Noxun::Engine::SupplierSettingsDialog.settings_payload
  NxTest.assert(data.is_a?(Hash), 'payload sa zostavil')
  %w[version revision supplier modes rate_keys rate_labels standard_rows path demos about].each do |k|
    NxTest.assert(data.key?(k), "payload nesie `#{k}`")
  end
  NxTest.assert_equal(Noxun::Engine::VERSION, data['about']['version'],
                      '„O plugine" berie verziu zo servera (ziadny hardcode)')
  push = ST4A_STUDIO_RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  NxTest.assert(push.include?('settings: settings_payload'), 'sekcie dostavaju stav plnym pushom')
  pay = ST4A_STUDIO_RB[/def settings_payload\n.*?\n        end\n/m].to_s
  NxTest.assert(pay.include?('SupplierSettingsDialog.settings_payload'), 'telo je v module')
  NxTest.assert(pay.include?("Engine.log_error(e, 'StudioDialog.settings_payload')"),
                'zlyhanie payloadu sa NEZAMLCUJE')
  NxTest.refute(pay.include?('model'), 'nastavenia su GLOBALNE — model netreba')
end

# --- 4) KLIENT ---------------------------------------------------------------

NxTest.test('ŠT-4a: klient kresli LEN do otvorenej sekcie a rozpisane NEZAHADZUJE') do
  code = ST4A_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  NxTest.assert(code.include?('function ssActive()'), 'sekcia si overuje, ci je otvorena')
  NxTest.assert(code.include?('studioActiveSection'), 'autoritou je studio.js')
  body = code[/function ssRenderBody\(\).*?\n  \}/m].to_s
  NxTest.assert(body.include?('if (!sec || !box) return;'),
                'do zdielanych uzlov sa kresli LEN z otvorenej sekcie (lekcia review #225 P1)')
  NxTest.assert(body.include?('ssTyping()'),
                'a NEPREKRESLUJE sa, kym pouzivatel pise (fokus + rozpisane cislo)')
  apply = code[/function ssApplyState\(s\).*?\n  \}/m].to_s
  NxTest.refute(apply.include?('SS_DIRTY = {}'),
                'plny push NESMIE zahodit rozpisane sadzby (chodi pri kazdej zmene modelu)')
  saved = code[/saved: function\(\).*?\n    \}/m].to_s
  NxTest.assert(saved.include?('SS_DIRTY = {}'),
                'rozpisane zanikaju AZ na potvrdenie servera')
  # Review #227 P2: povodny assert bol DISJUNKCIA, ktorej druhy operand bol
  # vzdy pravdivy (`SS.saved()` je v subore aj v komentari) — pokrytie len
  # predstieral. Hlada sa TELO handlera, nie subor.
  NxTest.assert(st4a_body('handle_save').include?("js('SS.saved()')"),
                'a server to potvrdenie posiela z TELA ulozenia')
  NxTest.assert(st4a_body('handle_reload').include?("js('SS.saved()')"),
                'aj z tela „Načítať nanovo"')
end

NxTest.test('ŠT-4a: „O plugine" je JEDEN OBSAH s DVOMA VSTUPMI') do
  NxTest.assert(ST4A_ABOUT_JS.include?('function nxAboutHtml(info)'), 'markup stavia zdielany builder')
  NxTest.assert(ST4A_PANEL_HTML.include?('id="cfgAbout"'), 'koliesko Inspectora ma hostitela')
  NxTest.refute(ST4A_PANEL_HTML.include?('class="aboutname"'),
                'a NEMA vlastnu kopiu markupu (dve kopie by sa rozisli)')
  NxTest.assert(ST4A_PANEL_HTML.include?('js/about.js'), 'panel builder nacitava')
  NxTest.assert(ST4A_STUDIO_HTML.include?('js/about.js'), 'a Studio tiez')
  NxTest.assert(ST4A_STUDIO_HTML.index('js/about.js') < ST4A_STUDIO_HTML.index('js/studio_settings.js'),
                'builder sa nacita PRED sekciou, ktora ho vola')
  bridge = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
  NxTest.assert(bridge.include?("nxAboutFill('cfgAbout'"), 'panel plni obsah cez builder')
  sync = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'), encoding: 'UTF-8')
  NxTest.assert(sync.include?('appdata_dir: about_dir'), 'a priecinok chodi zo SERVERA')
  NxTest.assert(ST4A_JS.include?('nxAboutFill'), 'sekcia `about` pouziva TEN ISTY builder')
end

NxTest.test('ŠT-4a: cache-bust, poradie skriptov a zrkadla sekcii') do
  ver = Noxun::Engine::VERSION
  NxTest.assert(ST4A_STUDIO_HTML.include?("js/studio_settings.js?v=#{ver}"),
                'CEF cachuje js — `?v=` musi byt presne VERSION')
  NxTest.assert(ST4A_STUDIO_HTML.include?("js/about.js?v=#{ver}"), 'to iste zdielany builder')
  NxTest.assert(ST4A_STUDIO_HTML.index('js/studio.js') < ST4A_STUDIO_HTML.index('js/studio_settings.js'),
                'sekcia sa nacitava AZ ZA studio.js — obaluje jeho NX.setStudio')
  rb = Noxun::Engine::StudioDialog::SECTIONS
  %w[sup bset about].each { |k| NxTest.assert(rb.include?(k), "Ruby whitelist pozna sekciu `#{k}`") }
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'), encoding: 'UTF-8')
  shell = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')
  [js, shell].each do |src|
    list = src[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
    NxTest.assert_equal(rb, list, 'JS zrkadlo sa nesmie rozist s Ruby autoritou')
  end
end

NxTest.test('ŠT-4a: `sup` NESLUBUJE nastavenia, ktore neexistuju') do
  code = ST4A_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  sup = code[/function ssRenderSupInto\(box\).*?\n  \}/m].to_s
  NxTest.refute(sup.include?("ssInput("),
                'sekcia `sup` nema ZIADNE editovatelne pole — Demos nema co nastavovat')
  NxTest.assert(sup.include?('data-ssgo') || sup.include?('ssLinkBtn'),
                'namiesto toho VEDIE tam, kde vazba naozaj zije')
  NxTest.assert(sup.include?("'mat'") && sup.include?("'budget'"),
                'do Materialov (vazba dekoru) a do Rozpoctu (prepocet cien)')
  tools = code[/function ssToolsHtml\(sec, failed\).*?\n  \}/m].to_s
  NxTest.assert(tools.include?("if (sec !== 'bset') return '';"),
                'a lista je prazdna — tlacidlo, ktore nema co robit, je horsie nez ziadne (D-78)')
end

# --- 5) BEHAVIORALNE dokazy (grep by prezil `if false && ...`) ---------------

# Docasna zamena modulovej metody — vzor `st3c2_with_stub`.
def st4a_with_stub(mod, name, impl)
  sc = mod.singleton_class
  alias_name = :"st4a_orig_#{name}"
  sc.send(:alias_method, alias_name, name)
  mod.define_singleton_method(name, impl)
  yield
ensure
  sc.send(:alias_method, name, alias_name)
  sc.send(:remove_method, alias_name)
end

NxTest.test('ŠT-4a (behavioralne): ulozenie sadzby ZAPISE a PREPOCITA, stara revizia NIE') do
  NxTest.skip!('zapis do realneho testovacieho %APPDATA%') unless NxTest.headless?

  e = Noxun::Engine
  sd = e::SupplierSettingsDialog
  e::SupplierSettings.reload!
  before = File.binread(e::SupplierSettings.path)
  sup = e::SupplierSettings.active
  rev = e::SupplierSettings.revision(sup)
  base = e::SupplierSettings.rate(sup, 'montaz').to_f
  NxTest.assert(base.positive? && !rev.to_s.empty?, 'fixture: sadzba aj revizia existuju')

  # STARA revizia = medzitym to niekto zmenil -> odmietnutie a ZIADNY zapis.
  got = []
  sd.dispatch('ss_save',
              { 'revision' => "#{rev}-STARA", 'patch' => { 'rates' => { 'montaz' => 999.0 } } }.to_json,
              ->(js) { got << js.to_s })
  NxTest.assert(got.any? { |x| x.include?('Nastavenia sa medzitým zmenili') },
                'zapis nad starym stavom sa ODMIETNE s hlaskou')
  NxTest.assert_equal(before, File.binread(e::SupplierSettings.path),
                      'a subor je BYTE-NEZMENENY (nikdy tichy prepis cudzej zmeny)')

  # SPRAVNA revizia -> zapis + POTVRDENIE + prepocet Studia.
  refreshed = []
  got.clear
  st4a_with_stub(e::StudioDialog, :refresh_if_open, ->(bump: true) { refreshed << bump }) do
    sd.dispatch('ss_save',
                { 'revision' => rev, 'patch' => { 'rates' => { 'montaz' => (base + 3.0).round(2) } } }.to_json,
                ->(js) { got << js.to_s })
  end
  NxTest.assert_close(base + 3.0, e::SupplierSettings.rate(e::SupplierSettings.active, 'montaz').to_f,
                      0.001, 'sadzba je zapisana')
  NxTest.assert(got.any? { |x| x.include?('SS.saved()') },
                'klient dostal POTVRDENIE (rozpisane hodnoty smie zahodit AZ TU)')
  NxTest.assert_equal([true], refreshed,
                      'a Studio sa PREPOCITALO so zdvihnutou generaciou — sadzby su vstup rozpoctu')
ensure
  if NxTest.headless?
    begin
      File.binwrite(Noxun::Engine::SupplierSettings.path, before) if before
      Noxun::Engine::SupplierSettings.reload!
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end
  end
end

NxTest.test('ŠT-4a (behavioralne): ZLYHANY payload NEPOSUNIE baseline (lekcia B4)') do
  NxTest.skip!('cita realny testovaci %APPDATA%') unless NxTest.headless?

  e = Noxun::Engine
  sd = e::SupplierSettingsDialog
  e::SupplierSettings.reload!
  before = File.binread(e::SupplierSettings.path)
  rev = e::SupplierSettings.revision(e::SupplierSettings.active)
  sd.settings_payload # baseline sedi na `rev`

  # Medzitym sa sklad ZMENI (druha instancia) — revizia je teda uz ina nez ta,
  # ktoru drzi klient.
  ok_write, = e::SupplierSettings.patch_active!({ 'rates' => { 'montaz' => 42.0 } })
  NxTest.assert(ok_write, 'fixture: cudzi zapis prebehol')
  NxTest.assert(e::SupplierSettings.revision(e::SupplierSettings.active) != rev,
                'fixture: revizia sa naozaj zmenila')

  # Zostavenie payloadu SPADNE (chyba disku, poskodeny zaznam). Keby si server
  # pri tom posunul baseline na NOVU reviziu, klient by drzal STARY stav
  # a kazde dalsie ulozenie by sa uz navzdy odmietalo.
  failed = st4a_with_stub(e::SupplierSettings, :standard_rows, ->(_sup) { raise 'BOOM' }) do
    sd.settings_payload
  end
  NxTest.assert(failed.nil?, 'zlyhany payload vracia nil (a NEZAMLCUJE sa)')
  NxTest.assert_equal(rev, sd.instance_variable_get(:@baseline_revision),
                      'baseline ostal na poslednom USPESNE odoslanom stave')

  # A ked payload nabuduce prejde, baseline sa dorovna na CERSTVY stav — takze
  # ulozenie zo stavu, ktory klient VIDEL, prejde.
  fresh = sd.settings_payload
  NxTest.assert(fresh.is_a?(Hash), 'dalsi payload uz prejde')
  got = []
  st4a_with_stub(e::StudioDialog, :refresh_if_open, ->(bump: true) { bump }) do
    sd.dispatch('ss_save', { 'revision' => fresh['revision'], 'patch' => {} }.to_json,
                ->(js) { got << js.to_s })
  end
  NxTest.refute(got.any? { |x| x.include?('Nastavenia sa medzitým zmenili') },
                'a ulozenie zo stavu, ktory klient naozaj videl, PREJDE')
ensure
  if NxTest.headless?
    begin
      File.binwrite(Noxun::Engine::SupplierSettings.path, before) if before
      Noxun::Engine::SupplierSettings.reload!
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end
  end
end

# --- 6) review #227: odmietacia vetva, pripnuta revizia, zbalena navigacia ---

NxTest.test('ŠT-4a (review #227 P1-2): ODMIETNUTIE zahodi rozpisane A obnovi zoznam') do
  NxTest.skip!('zapis do realneho testovacieho %APPDATA%') unless NxTest.headless?

  e = Noxun::Engine
  sd = e::SupplierSettingsDialog
  e::SupplierSettings.reload!
  before = File.binread(e::SupplierSettings.path)
  rev = e::SupplierSettings.revision(e::SupplierSettings.active)

  got = []
  refreshed = []
  st4a_with_stub(e::StudioDialog, :refresh_if_open, ->(bump: true) { refreshed << bump }) do
    sd.dispatch('ss_save',
                { 'revision' => "#{rev}-STARA", 'patch' => { 'rates' => { 'montaz' => 999.0 } } }.to_json,
                ->(js) { got << js.to_s })
  end
  # Bez `SS.saved()` by rozpisane hodnoty push PREZILI, prekryli cerstve cisla
  # a DRUHY klik by ich ticho prepisal — pricom hlaska tvrdi opak.
  NxTest.assert(got.any? { |x| x.include?('SS.saved()') },
                'odmietnutie ZAHADZUJE rozpisane hodnoty (hlaska hovori „nacitany nanovo")')
  NxTest.assert_equal([true], refreshed, 'a formular sa naozaj nacita nanovo (plny push)')
  NxTest.assert(got.any? { |x| x.include?('formulár je načítaný nanovo') },
                'hlaska sedi so spravanim')
  NxTest.assert(got.index { |x| x.include?('SS.saved()') } <
                got.index { |x| x.include?('SS.setStatus') },
                'poradie: najprv zahodenie rozpisu, az potom hlaska')
  NxTest.assert_equal(before, File.binread(e::SupplierSettings.path), 'a NIC sa nezapisalo')
ensure
  if NxTest.headless?
    begin
      File.binwrite(Noxun::Engine::SupplierSettings.path, before) if before
      Noxun::Engine::SupplierSettings.reload!
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end
  end
end

# --- 6b) dlh 1b-A: hlaska nesmie potvrdzovat prepocet, ktory neprebehol ------

NxTest.test('ŠT-4a (dlh 1b-A): ZLYHANY prepocet sa PRIZNA — „uložené áno, prepočet nie"') do
  NxTest.skip!('zapis do realneho testovacieho %APPDATA%') unless NxTest.headless?

  e = Noxun::Engine
  sd = e::SupplierSettingsDialog
  e::SupplierSettings.reload!
  before = File.binread(e::SupplierSettings.path)
  rev = e::SupplierSettings.revision(e::SupplierSettings.active)
  base = e::SupplierSettings.rate(e::SupplierSettings.active, 'montaz').to_f
  NxTest.assert(base.positive?, 'fixture: sadzba existuje')

  # Plny push NEDORAZIL: okno este neohlasilo `ready` alebo `push_state` spadol
  # — `refresh_if_open` vtedy vracia `false`/`nil`. Zapis do SUBORU uz pritom
  # prebehol a `SS.saved()` uz rozpis zahodil, takze na obrazovke ostanu STARE
  # cisla. Kym sa navratova hodnota ignorovala, hlaska tvrdila opak.
  got = []
  st4a_with_stub(e::StudioDialog, :refresh_if_open, ->(bump: true) { bump && nil }) do
    sd.dispatch('ss_save',
                { 'revision' => rev,
                  'patch' => { 'rates' => { 'montaz' => (base + 2.0).round(2) } } }.to_json,
                ->(js) { got << js.to_s })
  end
  NxTest.assert_close(base + 2.0, e::SupplierSettings.rate(e::SupplierSettings.active, 'montaz').to_f,
                      0.001, 'zapis do suboru PREBEHOL — zlyhal LEN prepocet okna')
  NxTest.refute(got.any? { |x| x.include?('Rozpočet je prepočítaný') },
                'hlaska NEPOTVRDZUJE prepocet, ktory neprebehol')
  NxTest.assert(got.any? { |x| x.include?('ULOŽENÉ') && x.include?('NEPREPOČÍTAL') },
                'povie oboje: subor ulozeny ANO, prepocet NIE')
  # Review #238 P2-1: „Obnoviť" v sekcii `bset` NIE JE (lista ma len „Načítať
  # nanovo" a „Uložiť"), preto hlaska musi POSLAT tam, kde to tlacidlo zije —
  # inak clovek siahne po „Načítať nanovo" a pride o rozpisane hodnoty. Test
  # drzi PRESNE znenie, aby nebetonoval nepravdu.
  NxTest.assert(got.any? { |x| x.include?('Otvor sekciu Rozpočet a klikni na Obnoviť.') },
                'a povie, co s tym — menom tlacidla AJ sekciou, v ktorej to tlacidlo naozaj je')
  NxTest.assert(got.any? { |x| x.start_with?('SS.setStatus') && x.end_with?('true)') },
                'zlyhanie je CERVENE (nie tichy zeleny status)')

  # Ta ista cesta s FUNGUJUCIM pushom potvrdzuje prepocet — vetva sa naozaj
  # vetvi podla vysledku, nie podla toho, ze sa `refresh_studio` zavolal.
  got.clear
  rev2 = e::SupplierSettings.revision(e::SupplierSettings.active)
  st4a_with_stub(e::StudioDialog, :refresh_if_open, ->(bump: true) { bump }) do
    sd.dispatch('ss_save',
                { 'revision' => rev2,
                  'patch' => { 'rates' => { 'montaz' => (base + 4.0).round(2) } } }.to_json,
                ->(js) { got << js.to_s })
  end
  NxTest.assert(got.any? { |x| x.include?('Rozpočet je prepočítaný') },
                'ked push dorazi, potvrdenie plati')

  # ODMIETACIA vetva tvrdi to iste o obsahu okna („formulár je načítaný
  # nanovo") — a plati pre nu ten isty zaver.
  got.clear
  st4a_with_stub(e::StudioDialog, :refresh_if_open, ->(bump: true) { bump && false }) do
    sd.dispatch('ss_save',
                { 'revision' => "#{rev}-STARA", 'patch' => { 'rates' => { 'montaz' => 999.0 } } }.to_json,
                ->(js) { got << js.to_s })
  end
  NxTest.refute(got.any? { |x| x.include?('formulár je načítaný nanovo') },
                'ani odmietnutie netvrdi nacitanie, ktore sa nepodarilo')
  NxTest.assert(got.any? { |x| x.include?('NIČ neuložilo') && x.include?('Načítať nanovo') },
                'namiesto toho povie, ze sa nic neulozilo a kde je cesta von')
ensure
  if NxTest.headless?
    begin
      File.binwrite(Noxun::Engine::SupplierSettings.path, before) if before
      Noxun::Engine::SupplierSettings.reload!
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end
  end
end

NxTest.test('ŠT-4a (dlh 1b-A): `refresh_studio` vracia BOOLEAN, nie „zavolalo sa"') do
  save = st4a_body('handle_save')
  NxTest.refute(save.match?(/^\s*refresh_studio\s*$/),
                'vysledok prepoctu sa uz NEZAHADZUJE (bol to zdroj klamlivej hlasky)')
  NxTest.assert(st4a_body('handle_reload').include?('refresh_and_report'),
                'aj „Načítať nanovo" vetvi hlasku podla vysledku')
  rep = st4a_body('refresh_and_report')
  NxTest.assert(rep.include?('if refresh_studio'), 'hlaska sa vetvi podla NAVRATOVEJ hodnoty')
  ref = st4a_body('refresh_studio')
  NxTest.assert(ref.include?('return false unless defined?(StudioDialog)'),
                'nedostupne Studio = prepocet NEPREBEHOL (nie `nil`, ktory sa da prehliadnut)')
  NxTest.assert(ref.include?('StudioDialog.refresh_if_open(bump: bump) ? true : false'),
                'a vysledok pushu sa preklada na boolean')
  NxTest.assert(ref[/rescue StandardError.*/m].to_s.include?('false'),
                'zachytena vynimka je tiez „neprebehlo"')
end

NxTest.test('ŠT-4a (review #227 P1): ulozenie posiela PRIPNUTU reviziu, nie omladenu') do
  code = ST4A_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  NxTest.assert(code.include?('var SS_BASE_REV = null;'), 'klient drzi pripnutu reviziu')
  save = code[/function ssSave\(\).*?
  \}/m].to_s
  NxTest.assert(save.include?('(SS_BASE_REV === null) ? SS_STATE.revision : SS_BASE_REV'),
                'a posiela JU (cerstva by nechala zamok prejst a cudziu zmenu prepisat)')
  NxTest.refute(save.include?('revision: SS_STATE.revision'), 'omladena revizia sa uz neposiela')
  # Review #227 kolo 2: pin sa berie UZ PRI FOKUSE. Prve pismeno je NESKORO —
  # fokus zmrazi zobrazeny obsah (telo sa neprekresluje), takze medzi nim
  # a prvym pismenom moze dorazit push s cudzou zmenou; pripnutie az vtedy by
  # priplo NOVU reviziu k STARYM hodnotam a zapis by cudziu zmenu prepisal.
  NxTest.assert(code.include?("document.addEventListener('focusin'"),
                'pripina sa uz pri FOKUSE pola')
  focus_h = code[/addEventListener\('focusin'.*?
    \}\);/m].to_s
  NxTest.assert(focus_h.include?('SS_BASE_REV = SS_STATE.revision'), 'a naozaj pin nastavuje')
  NxTest.assert(focus_h.include?("getAttribute('data-ss')"), 'len pre POLIA sekcie')
  apply = code[/function ssApplyState\(s\).*?
  \}/m].to_s
  NxTest.refute(apply.include?('SS_BASE_REV = s.revision'),
                'push pin NEPREPISUJE — obsah na obrazovke je stale ten, ktory pouzivatel videl')
  # Review #227 kolo 3 + dlh 1b-A: pin, ktory NIKTO NEVYUZIL (fokus bez
  # pisania, potom odchod z pola), sa naopak UVOLNI — inak by dalsia uprava
  # isla proti revizii, ktoru pouzivatel uz nikde nevidi, a skoncila by
  # FALOSNYM konfliktom. Miesto uvolnenia je `ssRenderBody`, nie `ssApplyState`:
  # pin patri k OBSAHU NA OBRAZOVKE, a ten sa prekresluje aj BEZ pushu
  # (navrat do sekcie cez `studioGoSection` → `render` → `renderBody`).
  NxTest.refute(apply.include?('SS_BASE_REV = null'),
                'uvolnenie pinu uz NEZIJE v ceste pushu (navigacii by uslo)')
  body = code[/function ssRenderBody\(\).*?\n  \}/m].to_s
  NxTest.assert(body.include?('if (!ssDirty()) SS_BASE_REV = null;'),
                'nevyuzity pin uvolnuje prekreslenie tela — ale LEN ked nie je co chranit')
  NxTest.assert(body.index('if (ssTyping()) return;') < body.index('SS_BASE_REV = null'),
                'a AZ ZA strazou `ssTyping()` — pod kurzorom je obsah zmrazeny a pin sa drzi')
  NxTest.assert(body.index('SS_BASE_REV = null') < body.index("box.innerHTML = '';"),
                'uvolnenie patri k TOMU prekresleniu, ktore sa o riadok nizsie naozaj deje')
  saved = code[/saved: function\(\).*?
    \}/m].to_s
  NxTest.assert(saved.include?('SS_BASE_REV = null'), 'potvrdenie/odmietnutie pin uvolni')
end

NxTest.test('ŠT-4a (review #227 P2): ZLYHANY payload sa PRIZNA, nie zamlci') do
  code = ST4A_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  apply = code[/function ssApplyState\(s\).*?
  \}/m].to_s
  NxTest.assert(apply.include?('if (s === null || s === undefined)'),
                '`settings: nil` je SIGNAL (server ho posiela pri zlyhani), nie „nic nove"')
  NxTest.assert(apply.include?('SS_FAILED = true'), 'sekcia prejde do chyboveho stavu')
  wrap = code[/NX.setStudio = function\(data\)\{.*?
    \};/m].to_s
  NxTest.assert(wrap.include?("hasOwnProperty.call(data, 'settings')"),
                'rozlisuje sa PRITOMNOST kluca, nie pravdivost hodnoty')
  body = code[/function ssRenderBody\(\).*?
  \}/m].to_s
  NxTest.assert(body.index('SS_FAILED') < body.index('SS_STATE'),
                'chybovy stav sa kresli PRED formularom — stary formular nesmie ostat na obrazovke')
  tools = code[/function ssToolsHtml\(sec, failed\).*?\n  \}/m].to_s
  NxTest.assert(tools.include?('if (failed){'), 'lista pozna chybovy stav')
  failed_branch = tools[/if \(failed\)\{.*?\n    \}/m].to_s
  NxTest.refute(failed_branch.include?('ss-save'),
                'nad neznamym stavom sa NEUKLADA (patch proti necitatelnej revizii)')
  NxTest.assert(failed_branch.include?('ss-reload'),
                'ale „Načítať nanovo\" OSTAVA — jedina cesta von z prechodnej chyby disku; \
                 hlaska v tele na nu odkazuje (review #227 kolo 2)')
  NxTest.assert(body.include?('Načítať nanovo'),
                'a hlaska menuje TLACIDLO, ktore sekcia naozaj ma')
end

NxTest.test('ŠT-4a (review #227 P1-1): ZBALENA navigacia skryva texty') do
  css = ST4A_STUDIO_HTML[/<style>(.*?)<\/style>/m, 1].to_s
  NxTest.refute(css.empty?, 'styly okna sa nasli')
  # Pravidlo MUSI byt samostatne: kym v skupine selektorov zila aj `.nbridge`,
  # jej zmazanie (ŠT-4a) vzalo `display: none` celej skupine a zbalena
  # navigacia zacala ukazovat nadpisy skupin aj nazvy poloziek.
  rule = css[/\.studio\.navmini \.snav \.sgrp,\s*\.studio\.navmini \.snav \.navitem span \{([^}]*)\}/m, 1].to_s
  NxTest.assert(rule.include?('display: none'),
                'zbaleny rezim skryva `.sgrp` aj `.navitem span` (inak 48 px pas ukazuje texty)')
  NxTest.refute(rule.include?('justify-content'),
                'a NEDEDI deklaracie susedneho pravidla (presne to bola regresia)')
  NxTest.assert(css.include?('.sectools:empty { display: none; }'),
                'prazdna lista sekcie nezabera vysku (vertikalny priestor je vzacny)')
end
