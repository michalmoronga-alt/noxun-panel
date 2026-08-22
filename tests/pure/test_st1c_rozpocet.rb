# frozen_string_literal: true
# ŠT-1c PR B1 — sekcia ROZPOČET v okne ŠTÚDIO (Š12–Š13) + zánik posledného
# tabu okna Výroba.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. GENERACNY KONTRAKT (audit #1). Rozpocet je JEDINA cesta, ktora zapisuje
#      do modelu, a po kazdom zapise prichadza cerstvy payload. Keby ten push
#      zdvihol generaciu okna, kazdy prepis sumy by zneplatnil rozkliknuty
#      riadok Kusovnika a rozrobeny export inej sekcie („Dáta okna sa medzitým
#      zmenili"). Preto `push_state(bump: false)` — plny payload, generacia TAK.
#   2. UVOLNENIE FRONTY ZAPISOV (audit #6) visi VYHRADNE na `NX.setStudio`.
#      Male echa (`setVepoBar`, `setEdgeCheck`, `setGrainCheck`) cerstvu `gen`
#      NENESU — keby fronta padala na nich, dalsi zapis by odisiel so starou
#      generaciou a server by ho odmietol ako zastaraly.
#   3. PORADIE SKRIPTOV. `studio.js` PRIRADUJE cele `window.NX = {…}`, takze
#      `budget.js` MUSI byt az za nim; v opacnom poradi by sa obal aj
#      `budgetResult`/`priceRefresh` prepisali a rozpocet by po prvom zapise
#      zamrzol na „cakam na odpoved".
#   4. PRESUN, NIE KOPIA — telo mutacii, oboch XLSX exportov aj prepoctu cien
#      zije v ZDIELANOM jadre; okna maju len tenke obaly.
#   5. Okno Vyroba stratilo POSLEDNY tab: prazdna skrupina, ktora POVIE, kam sa
#      obsah presunul (prazdna plocha bez vysvetlenia vyzera ako chyba).
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog') if NxTest.headless?

S1CB_CORE_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                           encoding: 'UTF-8')
S1CB_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
S1CB_PROD_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'),
                           encoding: 'UTF-8')
S1CB_PANEL_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
S1CB_SUP_RB    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog.rb'),
                           encoding: 'UTF-8')
S1CB_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
S1CB_BUDGET_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'),
                           encoding: 'UTF-8')
S1CB_PROD_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'production.js'),
                           encoding: 'UTF-8')
S1CB_BRIDGE_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                           encoding: 'UTF-8')
S1CB_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')
S1CB_PROD_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production.html'),
                           encoding: 'UTF-8')

# --- 1) sekcia `budget` je ZIVA a premostenia po nej nezostali ----------------

NxTest.test('ŠT-1c B1: `budget` je SEKCIA Studia — premostenia do okna Vyroba zanikli') do
  st = Noxun::Engine::StudioDialog
  NxTest.assert(st::SECTIONS.include?('budget'), 'Ruby whitelist sekciu pozna')
  NxTest.assert_equal([], st::PRODUCTION_BRIDGES.keys,
                      'do okna Vyroba uz nevedie ziadne premostenie')
  %w[budget offer].each do |k|
    NxTest.assert(st::BRIDGE_STATUS[k].to_s.empty?, "a s nim aj hlaska premostenia `#{k}`")
  end
  nav = S1CB_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  NxTest.refute(nav.empty?, 'navigacia sa nasla')
  NxTest.assert(nav.include?("{ id: 'budget', ic: 'euro',            t: 'Rozpočet' }"),
                'polozka navigacie je ZIVA sekcia, nie premostenie')
  NxTest.assert(S1CB_STUDIO_JS.include?("budget: { t: 'Rozpočet',"),
                'sekcia ma vlastnu hlavicku a hint')
  # Cenova ponuka este NEMA vlastnu sekciu (PR B2) — ale uz ani nepremostuje do
  # ineho okna: jej nahlad je CASTOU Rozpoctu, takze klik ostava tu.
  NxTest.assert(nav.include?("goto: { sec: 'budget', open: 'cp' }"),
                'Cenová ponuka preklikne na nahlad vnutri Rozpoctu')
  NxTest.assert(S1CB_STUDIO_JS.include?('function studioGoSection'),
                'prepnutie sekcie z kodu ma jedno miesto')
  NxTest.assert(S1CB_STUDIO_JS.include?('window.studioGoSection = studioGoSection'),
                'a je globalne — vola ho aj budget.js (nacita sa AZ ZA studio.js)')
end

NxTest.test('ŠT-1c B1: zrkadla whitelistu sekcii sedia vo VSETKYCH TROCH suboroch') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = S1CB_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')
  shell_list = shell[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert_equal(%w[bom ctrl buy budget], rb, 'Ruby je autorita zoznamu')
  NxTest.assert_equal(rb, js, 'studio.js je jeho zrkadlo')
  NxTest.assert_equal(rb, shell_list, 'a shell.js (panel) tiez')
end

# --- 2) GENERACNY KONTRAKT (audit #1) ----------------------------------------

NxTest.test('ŠT-1c B1 (audit #1): rozpoctovy push NEZDVIHA generaciu okna') do
  sig = S1CB_STUDIO_RB[/def push_state\(([^)]*)\)/, 1].to_s
  NxTest.assert_equal('bump: true', sig.strip,
                      'push_state ma prepinac `bump` s bezpecnym defaultom')
  body = S1CB_STUDIO_RB[/def push_state\(bump: true\).*?\n          js\("NX\.setStudio/m].to_s
  NxTest.assert(body.include?('@generation = @generation.to_i + 1 if bump || @generation.to_i.zero?'),
                'generacia sa zdviha LEN pri bump (prvy push vzdy — gen 0 = „ziadne data")')
  # Mutacia rozpoctu ide VYHRADNE cez `bump: false` proc.
  repush = S1CB_STUDIO_RB[/def budget_repush_proc.*?\n        end\n/m].to_s
  NxTest.refute(repush.empty?, 'rozpocet ma VLASTNY repush proc')
  NxTest.assert(repush.include?('push_state(bump: false)'),
                'a ten generaciu NEDVIHA (pending klik inej sekcie ostava platny)')
  # Review #3: `ProductionCore.do_budget` vola `repush` AJ vo svojej rescue
  # vetve — vynimka v prvom pokuse by druhy pokus poslala uz MIMO rescue, ten
  # by vyletel z callbacku a klientovi by nedosiel payload; jeho fronta zapisov
  # by potom visela az do 6 s poistky.
  NxTest.assert(repush.include?('rescue StandardError') && repush.include?('Engine.log_error'),
                'repush rozpoctu nesmie pustit vynimku von (fronta klienta by visela)')
  NxTest.assert(S1CB_STUDIO_RB.include?('repush: budget_repush_proc'),
                'do_budget ho naozaj odovzdava jadru')
  # Vsetko ostatne (export, klik, prepocet cien, refresh z inych okien) bumpuje
  # ako doteraz — inak by ochrana proti zastaranemu zapisu prestala platit.
  %w[do_export do_select do_hw_csv do_budget_xlsx do_cp_xlsx].each do |m|
    body = S1CB_STUDIO_RB[/def #{m}\(payload\).*?\n        end\n/m].to_s
    NxTest.assert(body.include?('repush: repush_proc'),
                  "#{m} pouziva BEZNY repush (s bumpom)")
  end
  NxTest.assert(S1CB_STUDIO_RB[/def price_refresh_after_proc.*?\n        end\n/m].to_s.include?('push_state'),
                'po prepocte cien ide BEZNY push (zmenil sa katalog, nie rozpocet)')
end

NxTest.test('ŠT-1c B1 (audit #6): fronta zapisov sa uvolnuje VYHRADNE v setStudio') do
  NxTest.assert(S1CB_BUDGET_JS.include?("typeof NX.setStudio === 'function'"),
                'obal sa vesia na setStudio')
  NxTest.assert(S1CB_BUDGET_JS.include?('var budPrevSetStudio = NX.setStudio;'),
                'povodna funkcia sa zachova (obal, nie nahrada)')
  NxTest.refute(S1CB_BUDGET_JS.include?('NX.setBom'),
                'na setBom (okno Vyroba) uz nic neviselo — to okno rozpocet nema')
  # `budAfterPush` (uvolnenie fronty) sa smie objavit LEN trikrat: definicia,
  # poistny timer (keby Ruby callback spadol pred pushom) a obal setStudio.
  # Kazdy stvrty vyskyt by znamenal, ze fronta padla aj na niecom inom.
  callers = S1CB_BUDGET_JS.scan(/^.*budAfterPush.*$/)
  NxTest.assert_equal(3, callers.length,
                      'uvolnenie fronty ma presne tri vyskyty (definicia, poistny timer, ' \
                      "obal setStudio) — najdene: #{callers.length}")
  # A na male echa sa budget.js NEVESIA vobec (ziadny obal, ziadne priradenie).
  %w[setVepoBar setEdgeCheck setGrainCheck].each do |echo|
    NxTest.refute(S1CB_BUDGET_JS.include?("NX.#{echo} ="),
                  "male echo #{echo} NENESIE cerstvu gen — fronta na nom visiet nesmie")
  end
end

NxTest.test('ŠT-1c B1: poradie skriptov — budget.js AZ ZA studio.js') do
  studio_at = S1CB_STUDIO_HTML.index('js/studio.js')
  budget_at = S1CB_STUDIO_HTML.index('js/budget.js')
  icons_at = S1CB_STUDIO_HTML.index('js/icons.js')
  NxTest.assert(!studio_at.nil? && !budget_at.nil?, 'oba skripty su v studio.html')
  NxTest.assert(budget_at > studio_at,
                'budget.js MUSI byt za studio.js — inak `window.NX = {…}` prepise jeho obal')
  NxTest.assert(icons_at < budget_at, 'sprite ikon je pred nim (rozpocet kresli ikony akcii)')
  NxTest.refute(S1CB_PROD_HTML.include?('<script src="js/budget.js'),
                'okno Vyroba rozpocet uz nenacitava (kopia by sa rozisla)')
end

# --- 3) telo v ZDIELANOM jadre, okna su len obaly -----------------------------

NxTest.test('ŠT-1c B1: mutacie, oba XLSX aj prepocet cien maju telo v jadre') do
  core = Noxun::Engine::ProductionCore
  %i[do_budget do_budget_xlsx do_cp_xlsx do_price_refresh price_refresh_cancel
     budget_open_url open_budget_settings apply_budget_op].each do |m|
    NxTest.assert(core.respond_to?(m), "ProductionCore.#{m} existuje")
  end
  %i[do_budget do_budget_xlsx do_cp_xlsx].each do |m|
    NxTest.assert(Noxun::Engine::StudioDialog.respond_to?(m),
                  "StudioDialog.#{m} je VEREJNY (vola ho relay z panela)")
    # DOCASNE — obal v okne Vyroba zanika v ŠT-1c PR B3 spolu s celym oknom.
    NxTest.assert(Noxun::Engine::ProductionDialog.respond_to?(m),
                  "ProductionDialog.#{m} ostava verejny (relay `production_do_*`)")
  end
  # Ziadne okno nesmie mat VLASTNY zapis do BudgetStore ani vlastny XLSX.
  [['studio_dialog.rb', S1CB_STUDIO_RB], ['production_dialog.rb', S1CB_PROD_RB]].each do |(name, src)|
    NxTest.refute(src.include?('BudgetStore.set_mode!'), "#{name} nesmie mat vlastnu mutaciu")
    NxTest.refute(src.include?('BudgetXlsx.sheet'), "#{name} nesmie mat vlastny zapis XLSX")
    NxTest.refute(src.include?('CpXlsx.sheets'), "#{name} nesmie mat vlastnu cenovu ponuku")
    NxTest.refute(src.include?('PriceRefresh.run'), "#{name} nesmie spustat prepocet sama")
  end
  NxTest.assert_equal(12, S1CB_CORE_RB[/def apply_budget_op.*?\n      end\n/m].to_s.scan(/^        when /).length,
                      'jadro pozna presne 12 operacii rozpoctu (jedna = jeden krok Spat)')
end

NxTest.test('ŠT-1c B1 (audit #12): prepocet cien obnovi okna nad KATALOGOM, nie Vyrobu') do
  after = S1CB_STUDIO_RB[/def price_refresh_after_proc.*?\n        end\n/m].to_s
  NxTest.refute(after.empty?, 'refresh cesty su na jednom mieste')
  %w[push_state MaterialsDialog.push_catalog Panel.push_materials
     HardwareCatalogDialog.push_items].each do |call|
    NxTest.assert(after.include?(call), "#{call} je v refresh cestach")
  end
  # Review #1: okno Vyroba je v zozname TIEZ. Rozpocet uz nezobrazuje, ale jeho
  # ⚠ chip nesie `counts` KONTROLY — a tie zahrnaju ROZPOCTOVE oranzove nalezy,
  # ktore prepocet cien vie zmenit (riadok bez ceny cenu dostane). Bez toho by
  # chip ukazoval stare cislo (kontrakt „KAZDE okno s cislami zakazky je vo
  # VSETKYCH refresh cestach"). Zanikne az s oknom v PR B3.
  NxTest.assert(after.include?('ProductionDialog.refresh_if_open'),
                'okno Vyroba dostane cerstve counts pre svoj ⚠ chip')
  alive = S1CB_STUDIO_RB[/def price_refresh_alive_proc.*?\n        end\n/m].to_s
  NxTest.assert(alive.include?('@dialog.equal?(dlg)'),
                'beh visi na TEJ ISTEJ instancii okna (znovuotvorenie ho neozivi)')
end

# --- 4) relay retaz Studia (audit #13) ---------------------------------------

NxTest.test('ŠT-1c B1: oba XLSX exporty idu VLASTNYM kanalom Studia s flush guardom') do
  NxTest.assert(S1CB_STUDIO_RB.include?("cb(dlg, 'budget_xlsx')     { |p| handle_budget_xlsx(p) }"),
                'okno ma vlastny callback pre XLSX rozpoctu')
  NxTest.assert(S1CB_STUDIO_RB.include?("cb(dlg, 'cp_xlsx')         { |p| handle_cp_xlsx(p) }"),
                'a pre cenovu ponuku')
  NxTest.assert(S1CB_STUDIO_RB.include?('NX.studioRelayBudget('), 'relay ide cez panel')
  NxTest.assert(S1CB_STUDIO_RB.include?('NX.studioRelayCp('), 'obe cesty')
  NxTest.assert(S1CB_PANEL_RB.include?("cb(dlg, 'studio_do_budget_xlsx')"),
                'panel ma vlastny vstupny bod pre Studio')
  NxTest.assert(S1CB_PANEL_RB.include?("cb(dlg, 'studio_do_cp_xlsx')"), 'pre obe cesty')
  [%w[studioRelayBudget studio_do_budget_xlsx], %w[studioRelayCp studio_do_cp_xlsx]].each do |(fn, cb)|
    relay = S1CB_BRIDGE_JS[/#{fn}: function\(p\)\{.*?\n    \},/m].to_s
    NxTest.refute(relay.empty?, "relay #{fn} sa nasiel v bridge.js")
    NxTest.assert(relay.include?('validateFields()'), "#{fn}: neplatne pole panela sa deteguje")
    NxTest.assert(relay.include?('p.flush_blocked = blocked'),
                  "#{fn}: export sa NEPOSLE ako platny (server ho odmietne s hlaskou)")
    NxTest.assert(relay.include?("sketchup.#{cb}"),
                  "#{fn}: odpoved chodi do TOHO okna, ktore klikalo (vlastny `gen`)")
  end
  # Mutacia rozpoctu relay NEMA — nie je to export a flush handshake by pri
  # kazdom prepise sumy zbytocne prehnal rozpisane edity panela.
  NxTest.assert(S1CB_STUDIO_RB.include?("cb(dlg, 'budget_mutate')   { |p| do_budget(p) }"),
                'mutacia ide priamo (bez relayu)')
end

# --- 5) CSS presun + okno Vyroba ako prazdna skrupina ------------------------

NxTest.test('ŠT-1c B1: styly rozpoctu sa PRESUNULI (nie skopirovali)') do
  %w[.bsum .btotal .bseg .bchip .blist .bsec .bcnt .bsubt .btab .bedit .bacts
     .baddbig .bdraft .broundrow .bprog .bcpband .bcpmerged].each do |sel|
    NxTest.assert(S1CB_STUDIO_HTML.include?(sel), "#{sel} je v studio.html")
    NxTest.refute(S1CB_PROD_HTML.include?("  #{sel} {"),
                  "#{sel} uz v production.html NIE JE (kopia by sa rozisla)")
  end
  # UI_DIZAJN: v Studiu ziadny natvrdo pisany hex — okno ma dve temy.
  block = S1CB_STUDIO_HTML[/sekcia ROZPOČET \(Š12–Š13\).*?súčtový riadok/m].to_s
  NxTest.refute(block.empty?, 'blok stylov sekcie sa nasiel')
  NxTest.refute(block.match?(/#[0-9a-fA-F]{3,6}\b/),
                'farby su VYHRADNE cez --nx-* tokeny (hex by v teme Lucia svietil)')
  # Kolizie s triedami Studia: rozpocet kresli `.btab`, Kusovnik `.bomtab`.
  # Uvodny komentar bloku (a vsetky dalsie) sa vynechavaju — hladaju sa
  # PRAVIDLA, nie prosa o nich.
  rules = block.split('*/', 2).last.to_s.gsub(%r{/\*.*?\*/}m, ' ')
  NxTest.refute(rules.include?('.bomtab'), 'blok rozpoctu sa nedotyka tabuliek Kusovnika')
  NxTest.refute(rules.include?('.totrow'), 'ani suctoveho riadku Kusovnika')
end

NxTest.test('ŠT-1c B1: okno Vyroba je PRAZDNA SKRUPINA (a povie to)') do
  NxTest.assert_equal([], Noxun::Engine::ProductionDialog::TABS, 'ziadny tab')
  NxTest.refute(S1CB_PROD_HTML.include?('id="prodTabs"'), 'lista tabov zanikla')
  NxTest.refute(S1CB_PROD_HTML.include?('id="pt_budget"'), 'tlacidlo posledneho tabu zaniklo')
  NxTest.assert(S1CB_PROD_JS.include?('presťahoval do <b>Štúdia</b>'),
                'telo POVIE, kam sa obsah presunul (prazdna plocha vyzera ako chyba)')
  NxTest.assert(S1CB_PROD_JS.include?('id="ctrlBadge"') || S1CB_PROD_HTML.include?('id="ctrlBadge"'),
                '⚠ chip do sekcie Kontrola v okne OSTAVA (zanikne az s oknom)')
  NxTest.assert(S1CB_PROD_RB.include?("cb(dlg, 'open_studio')"), 'a jeho cesta do Studia tiez')
  # Payload okna stratil pole `budget` — citalo ho VYHRADNE telo tabu.
  NxTest.refute(S1CB_PROD_RB.match?(/^\s{12}budget: budget,$/),
                'okno Vyroba rozpocet uz nedostava')
  NxTest.assert(S1CB_STUDIO_RB.match?(/^\s{12}budget: budget,$/),
                'zato Studio ano (sekcia ho kresli)')
  # Rozpocet sa vsak v okne Vyroba POCITA dalej — kvoli ORANGE nalezom KONTROLY
  # pod ⚠ chipom. Bez toho by chip ukazal ine cislo nez semafor v Studiu.
  NxTest.assert(S1CB_PROD_RB.include?('budget = budget_payload(model, bom, collected, estimate, hw_exp, smap)'),
                'rozpocet sa pocita dalej — jeho ORANGE patria do KONTROLY')
end

# --- 6) klamuce texty, ktore tato davka opravila -----------------------------

NxTest.test('ŠT-1c B1 (#20, #22): texty uz neposielaju do okna Vyroba za rozpoctom') do
  NxTest.assert(S1CB_SUP_RB.include?('Rozpočet v Štúdiu je prepočítaný.'),
                'Nastavenia rozpoctu hlasia spravne okno')
  NxTest.refute(S1CB_SUP_RB.include?('Rozpočet v okne Výroba'), 'stary text zanikol')
  bset = Noxun::Engine::StudioDialog::BRIDGE_STATUS['bset'].to_s
  NxTest.assert(bset.include?('sadzby'),
                '⚙ v liste Rozpoctu a polozka navigacie otvaraju TO ISTE okno — text to povie')
  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  tip = main[/cmd_studio\.tooltip = '([^']+)'/, 1].to_s
  NxTest.refute(tip.include?('Výroba'), 'tooltip toolbaru uz neposiela do okna Vyroba')
  NxTest.refute(S1CB_STUDIO_JS.include?('zatiaľ okno Výroba'),
                'ani hinty Kusovnika (Rozpocet je o klik vedla)')
end
