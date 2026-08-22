# frozen_string_literal: true
# UI-D3 — KLIKATELNOST: warnpanel N5, deep-linky do okna Vyroba a zvysne prekliky.
#
# Co sa tu strazi (a preco to nestaci overit klikanim):
#   1) Warnpanel je OVERLAY zaveseny pod hlavickou, nie riadok layoutu —
#      otvorenie zoznamu upozorneni nesmie posunut obsah panela nadol
#      (vertikalny priestor je vzacny) a povodny `scrollTo(0,0)` odpada.
#   2) Panel sa zatvara klikom MIMO a Escapom; klik VNUTRI panela (a na ⚠ chip)
#      bublanie zastavi — inak by sa v tom istom kliku otvoril a hned zavrel.
#   3) Oko v riadku oznacuje v modeli EXISTUJUCOU serverovou cestou
#      (`nx_select_hw_owner`) — ziadny druhy handler s vlastnymi guardmi, ktory
#      by sa casom rozisiel. Lisia sa LEN podstatne mena v statusoch.
#   4) Deep-link do okna Vyroba ma whitelist tabov na strane RUBY a spotrebuje
#      sa PRAVE RAZ (inak by kazdy refresh vratil pouzivatela na tab, z ktoreho
#      medzitym odisiel). JS zoznam je jeho ZRKADLO, nie druha autorita.
#   5) Klikatelne je LEN to, co niekam vedie (N13): „Materiál" vedie do
#      Kusovnika, „Hrúbka" v karte dielca nikam viest nema — a teda ani netvrdi,
#      ze vedie.
require_relative '../helper' unless defined?(NxTest)

UID3_PANEL_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
UID3_CSS        = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
UID3_BRIDGE_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
UID3_BOOT_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'boot.js'), encoding: 'UTF-8')
UID3_ACTIONS_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'actions.js'), encoding: 'UTF-8')
UID3_SHELL_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')
UID3_PART_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'part_card.js'), encoding: 'UTF-8')
UID3_PANEL_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
UID3_RESOLV_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'resolvers.rb'), encoding: 'UTF-8')
UID3_SEL_RB     = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'selection.rb'), encoding: 'UTF-8')

# --- 1) warnpanel je OVERLAY -------------------------------------------------

NxTest.test('UI-D3: warnpanel zije VNUTRI sticky hlavicky (kotva overlayu)') do
  hdr = UID3_PANEL_HTML[/<header class="nxhdr">.*?<\/header>/m].to_s
  NxTest.assert(!hdr.empty?, 'hlavicka sa nasla')
  NxTest.assert(hdr.include?('id="warnList"'),
                'panel je dieta hlavicky — `position: sticky` predok drzi overlay pri ⚠ chipe')
  NxTest.assert(hdr.include?('class="warnpanel"'), 'trieda je warnpanel (overlay), nie warnlist (blok)')
end

NxTest.test('UI-D3: warnpanel NEZABERA vertikalny priestor (position: absolute)') do
  rule = UID3_CSS[/\.nx-inspector \.nxhdr \.warnpanel \{.*?\}/m].to_s
  NxTest.assert(!rule.empty?, 'pravidlo overlayu existuje')
  NxTest.assert(rule.include?('position: absolute'),
                'blokovy zoznam by otvorenim posunul cely obsah panela nadol')
  NxTest.assert(rule.include?('top: calc(100% + 2px)'), 'panel visi tesne pod hlavickou')
  # Stara blokova trieda uz nesmie zit — dve pravdy o tom istom zozname.
  NxTest.refute(UID3_CSS.include?('.warnlist {'), 'blokovy `.warnlist` zanikol')
  NxTest.refute(UID3_PANEL_HTML.include?('class="warnlist"'), 'a nikde sa uz nepouziva')
end

NxTest.test('UI-D3: dlhy zoznam nalezov sa scrolluje VNUTRI panela (Codex #182 P2)') do
  # Panel je mimo dokumentoveho toku — pri mnohych nalezoch by spodne riadky AJ
  # tlacidlo „Otvoriť v Štúdiu" skoncili pod okrajom okna a scroll dokumentu by
  # ich nedotiahol. Vyska je preto ohranicena viewportom a scrolluje sa zoznam.
  rule = UID3_CSS[/\.nx-inspector \.nxhdr \.warnpanel \{.*?\}/m].to_s
  NxTest.assert(rule.include?('max-height: calc(100vh'), 'vyska panela je viazana na viewport')
  NxTest.assert(rule.include?('flex-direction: column'), 'panel je flex stlpec (zoznam + cesta von)')
  NxTest.assert(UID3_CSS.include?('.warnpanel .wrows { overflow-y: auto; min-height: 0; }'),
                'scrolluje LEN zoznam riadkov — `min-height: 0` je nutne, inak sa flex polozka nezmensi')
  NxTest.assert(UID3_CSS.match?(/\.warnpanel \.wgoto \{ flex: 0 0 auto;/),
                'cesta von sa nescvrkne ani nescrolluje prec')
  NxTest.assert(UID3_BRIDGE_JS.include?("var h = '<div class=\"wrows\">'"),
                'riadky su naozaj v scrolleri (CSS bez wrappera by nic nerobilo)')
end

NxTest.test('UI-D3: scroll-to-top pri otvoreni ZANIKOL (overlay ho nepotrebuje)') do
  body = UID3_BRIDGE_JS[/function toggleWarnList.*?\n  \}/m].to_s
  NxTest.assert(!body.empty?, 'toggle sa nasiel')
  NxTest.refute(body.include?('scrollTo'),
                'sticky hlavicka drzi panel na ocnom mieste — skok hore uz nema dovod')
  NxTest.assert(body.include?('stopPropagation'),
                'klik na chip nesmie doletiet k documentu (zavrel by panel v tom istom kliku)')
end

# --- 2) zatvaranie -----------------------------------------------------------

NxTest.test('UI-D3: `aria-expanded` chipu hovori pravdu (jedno miesto zmeny)') do
  # Panel zatvara viac ciest (chip, klik mimo, Escape, prazdny zoznam) — keby
  # kazda menila `display` sama, chip by po niektorej z nich tvrdil opak.
  NxTest.assert(UID3_BRIDGE_JS.include?('function setWarnPanel'), 'viditelnost meni JEDNA funkcia')
  NxTest.assert(UID3_BRIDGE_JS.include?("chip.setAttribute('aria-expanded'"),
                'a spolu s nou aj stav chipu')
  NxTest.assert(UID3_BRIDGE_JS.include?('setWarnPanel(warnPanelOpen())'),
                'prekreslenie chipu (echo push) stav NEPREPISE na zatvoreny')
end

NxTest.test('UI-D3: panel zatvara klik MIMO a Escape (jedna delegacia, nie per riadok)') do
  body = UID3_BOOT_JS[/function bindWarnPanel.*?\n  \}\n/m].to_s
  NxTest.assert(!body.empty?, 'bindWarnPanel existuje')
  NxTest.assert(body.include?("document.addEventListener('click'"), 'klik mimo zatvara')
  NxTest.assert(body.include?("ev.key !== 'Escape'"), 'Escape zatvara')
  NxTest.assert(body.include?('ev.stopPropagation()'),
                'klik VNUTRI panela sa k documentu nedostane (inak by oko nestihlo dobehnut)')
  NxTest.assert(UID3_BOOT_JS.include?('bindWarnPanel();'),
                'delegacia sa naozaj pripaja pri starte (staticky uzol, obsah sa prekresluje)')
end

# --- 3) oko v riadku ---------------------------------------------------------

NxTest.test('UI-D3: oko ide EXISTUJUCOU cestou vyberu, nie novym handlerom') do
  body = UID3_BRIDGE_JS[/function onWarnRowPick.*?\n  \}/m].to_s
  NxTest.assert(!body.empty?, 'handler sa nasiel')
  NxTest.assert(body.include?('nx_select_hw_owner'),
                'ta ista serverova cesta ako box vlastnika v Kovani (jedny guardy)')
  NxTest.assert(body.include?("origin: 'warn'"),
                'povie, ODKIAL klik prisiel — status potom nehovori o „vlastníkovi" a Kovani')
  NxTest.assert(body.include?('model_guid'), 'nesie identitu dokumentu (callback je asynchronny)')
end

NxTest.test('UI-D3: oko ma FLUSH handshake (vzor onInfoParts / onHwOwnerPick)') do
  body = UID3_BRIDGE_JS[/function onWarnRowPick.*?\n  \}/m].to_s
  NxTest.assert(body.include?('flushCabinetEditsNow()'), 'rozpisany edit ide na server PRED vyberom')
  NxTest.assert(body.include?('!validateFields()'), 'neplatne pole akciu ZASTAVI')
  NxTest.assert(body.index('!validateFields()') < body.index('nx_select_hw_owner'),
                'kontrola aj flush bezia PRED odoslanim vyberu')
end

NxTest.test('UI-D3: nalez o NEPOSTAVENOM dielci nespusta akciu, co nemoze uspiet (Codex #182 P2)') do
  # `part_skipped_degenerate` VYRADI dielec z planu, ale jeho `part_key` si v
  # upozorneni ponecha (aby sa dalo povedat, ktory to bol). Poslat taky kluc na
  # vyber = zarucene „Dielec sa v modeli nenašiel". Zoznam je UZKY a explicitny.
  NxTest.assert(
    UID3_SHELL_JS.include?(
      "var WARN_PART_NOT_BUILT = ['part_skipped_degenerate', 'shelf_skipped_shallow_zone'];"
    ),
    'kody nepostavenych dielcov su vymenovane, nie uhadnute heuristikou'
  )
  body = UID3_SHELL_JS[/function warnRows.*?\n    \}/m].to_s
  NxTest.assert(body.include?('WARN_PART_NOT_BUILT.indexOf(code) < 0'),
                'nalez sa pyta kodu PRED tym, nez z neho spravi cielovy kluc')
  # Zdroj pravdy o tom, ze taky dielec naozaj v modeli nie je:
  cons = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'construction.rb'), encoding: 'UTF-8')
  NxTest.assert(cons.include?("BuildPlan.warning('part_skipped_degenerate'"),
                'kod stale existuje na strane planu (inak by zoznam mieril do prazdna)')
  # Sweep review P2: plytka zona police NEPOSTAVI, ale kluc prvej z nich si v
  # upozorneni ponecha — v allowliste chybal, takze oko na tom riadku koncilo
  # hlaskou „Dielec sa v modeli nenašiel".
  zt = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'zone_tree.rb'), encoding: 'UTF-8')
  NxTest.assert(zt.include?("BuildPlan.warning('shelf_skipped_shallow_zone'"),
                'plytka zona naozaj hlasi preskocene police')
  NxTest.assert(zt[/shelf_skipped_shallow_zone.*?\n.*?\n.*?part_key:/m],
                'a nesie pritom part_key nepostavenej police (preto patri do allowlistu)')
end

NxTest.test('SWEEP: warnpanel sa otvara TRIEDOU, nie inline `display` (scroller by inak bol mrtvy)') do
  # Inline `display: block` prebijalo `display: flex` z CSS — panel prestal byt
  # stlpcovy flex, `.wrows` uz nebola flex polozka a `min-height: 0` nemalo co
  # obmedzit, takze scroller z #182 fixu NEROBIL NIC a dlhy zoznam sa neposuval.
  body = UID3_BRIDGE_JS[/function setWarnPanel.*?\n  \}/m].to_s
  NxTest.assert(!body.empty?, 'setWarnPanel sa nasiel')
  NxTest.refute(body.include?("list.style.display = open"),
                'viditelnost sa uz NENASTAVUJE inline hodnotou')
  NxTest.assert(body.include?("classList.add('open')") && body.include?("classList.remove('open')"),
                'prepina sa trieda `open`')
  NxTest.assert(body.include?("list.style.display = ''"),
                'stary inline stav (CEF cache) sa CISTI — inak by trieda nemala sancu')
  NxTest.assert(UID3_BRIDGE_JS.scan(/list\.style\.display = 'none'/).empty?,
                'ziadna cesta uz panel nezatvara inline — vsetky idu cez setWarnPanel')
  open_fn = UID3_BRIDGE_JS[/function warnPanelOpen.*?\n  \}/m].to_s
  NxTest.assert(open_fn.include?("classList.contains('open')"),
                'stav sa CITA z tej istej triedy, akou sa nastavuje')
  NxTest.assert(UID3_CSS.include?('.nx-inspector .nxhdr .warnpanel.open { display: flex; }'),
                'CSS otvoreny stav vracia na flex (scroller ozije)')
  rule = UID3_CSS[/\.nx-inspector \.nxhdr \.warnpanel \{.*?\}/m].to_s
  NxTest.assert(rule.include?('display: none'), 'zavrety stav je default v CSS, nie v HTML atribute')
  html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  NxTest.assert(html.include?('<div id="warnList" class="warnpanel"></div>'),
                'kostra uz nenesie inline `display` (jedno miesto pravdy)')
end

NxTest.test('UI-D3: kliky vo warnpaneli sa DOSTANU do meraca D-25 (Codex #182 P2)') do
  # Panel zastavuje bublanie (potrebuje to na zatvaranie klikom mimo), takze
  # merac v BUBBLE faze by o nom nevedel — a odpocet D-25, podla ktoreho sa
  # rozhoduje o rezimoch panela, by tvrdil, ze warnpanel nikto nepouziva.
  usage = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'usage.js'), encoding: 'UTF-8')
  NxTest.assert(usage.include?("document.addEventListener('click', onClick, true)"),
                'klik sa pocita v CAPTURE faze — stopPropagation ho uz neschova')
  # K1 (D-108): `part:smer` nahradili TRI kluce segmentu smeru dekoru a ziju
  # v `panel.html` (statická kostra), nie v JS — allowlist bez prvku nic nezmeria.
  panel_html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  %w[warn:chip warn:oko warn:studio part:smer-dedi part:smer-pozdlz part:smer-priecna].each do |k|
    NxTest.assert(usage.include?("'#{k}'"), "kluc #{k} je v allowliste USAGE_KEYS")
    NxTest.assert(UID3_BRIDGE_JS.include?("data-nx-usage=\"#{k}\"") ||
                  UID3_PART_JS.include?("data-nx-usage=\"#{k}\"") ||
                  panel_html.include?("data-nx-usage=\"#{k}\""),
                  "kluc #{k} naozaj visi na prvku (allowlist bez prvku nic nezmeria)")
  end
  NxTest.refute(usage.include?("'part:smer'"),
                'mrtvy kluc `part:smer` z allowlistu zmizol — merac by ho uz nikdy nenaplnil')
end

NxTest.test('UI-D3: statusy vyberu nesu podstatne meno podla povodu kliku') do
  NxTest.assert(UID3_SEL_RB.include?('SELECT_OWNER_NOUNS'), 'mena su na JEDNOM mieste')
  NxTest.assert(UID3_SEL_RB.include?("'warn' => { subject: 'Nález'"),
                'nalez sa nevola „vlastník" — pouzivatel klikal na upozornenie')
  NxTest.assert(UID3_SEL_RB.include?("'hardware' => { subject: 'Vlastník'"),
                'povodne znenie kovania ostava nezmenene')
  NxTest.assert(UID3_SEL_RB.include?('def select_owner_nouns'),
                'neznamy/chybajuci povod padne na kovanie (spatna kompatibilita)')
  NxTest.refute(UID3_SEL_RB.include?('panel ostáva v Kovaní."'),
                'veta o Kovani uz nie je natvrdo v statuse — sklada ju povod kliku')
end

# --- 4) deep-link: uz LEN do sekcii Studia ----------------------------------

NxTest.test('ŠT-1c PR B3: deep-link na TAB zanikol spolu s oknom Vyroba') do
  # ST-1a odviedla taby `rows`/`sheets`/`edging` do sekcie Kusovnik, ŠT-1b tab
  # `control`, ŠT-1c PR A tab `hardware` a PR B1 posledny tab `budget`. PR B3
  # zmazala okno aj CELU mechaniku deep-linku na tab (Ruby whitelist, JS mirror
  # aj tolerantny resolver panela).
  NxTest.refute(defined?(Noxun::Engine::ProductionDialog), 'modul okna uz neexistuje')
  NxTest.refute(UID3_SHELL_JS.include?('STUDIO_TABS'), 'JS mirror tabov je PREC')
  NxTest.refute(UID3_SHELL_JS.include?('function studioLink'), 'a s nim skladanie payloadu')
  NxTest.refute(UID3_PANEL_RB.include?('open_tab:'), 'panel uz ziadny tab neposiela')
  NxTest.refute(UID3_RESOLV_RB.include?('def studio_tab_of'),
                'a mrtvy resolver tabu zanikol tiez')
end

NxTest.test('UI-D3: deep-link sa spotrebuje PRAVE RAZ (uz len sekcia Studia)') do
  studio_rb = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                        encoding: 'UTF-8')
  body = studio_rb[/def consume_pending_section.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'spotreba ma vlastnu funkciu')
  NxTest.assert(body.include?('@pending_section = nil'),
                'bez vynulovania by kazdy refresh vratil pouzivatela na staru sekciu')
  NxTest.assert(body.include?('SECTIONS.include?'), 'aj pri spotrebe plati whitelist')
  NxTest.assert(studio_rb.include?('open_section: consume_pending_section'),
                'sekcia cestuje v tom istom pushi ako data (okno po `show` este nemusi mat HTML)')
end

# --- 5) klikatelne je LEN to, co niekam vedie -------------------------------

NxTest.test('UI-D3 (N13) + ST-1a: „Materiál" vedie do Kusovnika v ŠTÚDIU — a rovno na skrinku') do
  body = UID3_ACTIONS_JS[/function onInfoArea.*?\n  \}/m].to_s
  NxTest.assert(!body.empty?, 'handler sa nasiel')
  # ST-1a (audit #12): kusovnik sa prestahoval do Studia a slub UI-D3 („filter
  # na jednu skrinku pribudne v Štúdiu") sa SPLNIL — ID skrinky ide ako kotva,
  # ktora predvyplni hladanie sekcie.
  NxTest.assert(body.include?("openStudio('bom', selectedCabId)"),
                'otvori Štúdio na sekcii Kusovník a kotvou je ID skrinky')
  NxTest.refute(body.include?('openProductionDialog'),
                'stara cesta do okna Výroba na tabe „rows" zanikla spolu s tym tabom')
  NxTest.assert(body.include?('vyfiltrovaný na'),
                'status povie, ze zoznam je ZUZENY — a ako sa zuzenie zrusi')
end

NxTest.test('ST-1a: deep-link do Studia ma whitelist sekcii v RUBY a JS je jeho ZRKADLO') do
  studio_rb = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                        encoding: 'UTF-8')
  rb = studio_rb[/SECTIONS = %w\[([a-z ]+)\]/, 1].to_s.split
  js = UID3_SHELL_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert_equal(%w[bom ctrl buy budget offer mat], rb,
                      'v Studiu ziju sekcie Kusovník, Kontrola, Nákup, Rozpočet, Ponuka a Materiály')
  NxTest.assert_equal(rb, js, 'JS mirror sa nesmie rozist s Ruby autoritou')
  NxTest.assert(UID3_PANEL_RB.include?("cb(dlg, 'open_studio')"),
                'panel ma vlastny callback na otvorenie Studia')
  NxTest.assert(UID3_RESOLV_RB.include?('def studio_link_of'),
                'prazdny payload (rail Štúdio) sa tolerantne mapuje na nil')
  NxTest.assert(UID3_ACTIONS_JS.include?('NXShell.studioOpenLink(section, anchor)'),
                'panel posiela iba meno sekcie a kotvu — filtruje ich server')
end

NxTest.test('UI-D3 + ŠT-1b: warnpanel ma JEDNU cestu von — deep-link do ŠTÚDIA na KONTROLU') do
  NxTest.assert(UID3_BRIDGE_JS.include?('Otvoriť v Štúdiu → Kontrola'), 'tlacidlo nesie znenie kontraktu')
  body = UID3_BRIDGE_JS[/function onWarnStudio.*?\n  \}/m].to_s
  # ŠT-1b: KONTROLA je sekcia okna Studio — deep-link uz nevedie do okna Vyroba.
  NxTest.assert(body.include?("openStudio('ctrl')"), 'vedie na sekciu KONTROLA v Studiu')
  NxTest.refute(body.include?('openProductionDialog'), 'stara cesta do okna Vyroba zanikla')
  NxTest.assert(body.include?('closeWarnPanel()'), 'pri odchode do ineho okna sa panel zavrie')
end

NxTest.test('UI-D3 + K1: „Hrúbka" nikam nevedie; zamknuty smer vedie na material') do
  rows = UID3_PART_JS[/function nxPartBasicRows.*?\n  \}/m].to_s
  NxTest.assert(!rows.empty?, 'skladanie riadkov sa naslo')
  hr = rows[/\{ label: 'Hrúbka'.*?\},/m].to_s
  NxTest.refute(hr.include?('click:'),
                'hrubku urcuje material KORPUSU — v rezime dielca sa neda otvorit, teda nikam nevedie')
  # K1 (D-108): „Smer dekoru" uz NIE JE informacny riadok — je to segment
  # (vstup). Preklik na material prezil pre JEDINY pripad, ked sa smer naozaj
  # meni inde: material BEZ smeru (zamknuty segment). Klik vtedy nezapisuje.
  NxTest.refute(rows.include?("label: 'Smer dekoru'"),
                'smer dekoru uz nie je informacny riadok — je to vstup')
  body = UID3_PART_JS[/function onPartGrain.*?\n  \}/m].to_s
  NxTest.assert(body.include?('nxGrainSegmentState(partCard).locked'),
                'zamknuty stav sa cita z TEJ ISTEJ ciste funkcie, ako maluje segment')
  NxTest.assert(body.include?('onPartInfoGrain(null)'), 'zamknuty klik vedie na material dielca')
  NxTest.assert(UID3_PART_JS.include?('function onPartInfoGrain'), 'preklik ma svoju cestu')
  NxTest.assert(UID3_PART_JS.include?('nxRevealTarget(sel)'),
                'zbaleny sektor sa najprv rozbali (combobox by sa otvoril z nulovej plochy)')
end

NxTest.test('UI-D3: klikatelny informacny riadok je TLACIDLO (klavesnica, citacka)') do
  body = UID3_PART_JS[/function nxInfoRowHtml.*?\n  \}/m].to_s
  NxTest.assert(body.include?('<button type="button" class="inforow click"'),
                'klikatelny riadok je nativne tlacidlo, nie div s onclick')
  NxTest.assert(body.include?("if (!r.click) return '<div class=\"inforow\"'"),
                'neklikatelny ostava textom — vystup sa nesmie tvarit ako ovladac')
end
