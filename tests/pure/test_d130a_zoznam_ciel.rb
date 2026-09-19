# frozen_string_literal: true
# D-130a — NOVY ZOZNAM CIEL + KARTA S TABMI + UCHYTKA NA JEDNOM MIESTE.
#
# Michalove hlasenia, ktore tato davka riesi:
#   D-129 „úchytka je na dvoch miestach" — profil a hrana sa dali nastavit
#         v karte cela AJ v skupine „Úchytky"; pouzivatel nevedel, ktore
#         z dvoch miest plati. Skupina ZANIKLA; hromadna zmena ostala ako
#         AKCIA (popover „všetkým"), ktora zapisuje LEN tlacidlom „Použiť".
#   D-130 „polia lietajú" — poloha pola vysky zavisela od toho, co v riadku
#         prave bolo (chip AUTO, „mm", select kridel, ikona profilu). Riadok
#         je teraz CSS GRID so STALYMI STLPCAMI.
#
# PRECO GUARD TEST A NIE KLIKANIE:
#   1) KOSTRA sa da rozbit tichym pridanim skupiny — poradie skupin kontextu
#      je kontrakt (`test_uic3_cela.rb`), tu strazime, ze `fhandles` sa uz
#      nevrati a ze popover stoji MIMO `<summary>` (inak by ho klik zbalil).
#   2) POMOCNE TEXTY: pravidlo „pomocny text = tooltip, stavova veta ostava"
#      sa da porusit jednym `.hint`-om. Pocet `.hint` v skupine Cela je preto
#      merany — jediny povoleny je `frontDraftMessage` (stav D-120).
#   3) ROZPOCET MRIEZKY je v CSS, nie v JS — bez guardu by novy ovladac znova
#      posunul pole vysky (presne to bol D-130).
#   4) ZDROJ HODNOT: `collectFronts` uz NESMIE citat `select.fw` (zanikol)
#      a suhrn MUSI byt cista funkcia v core.js (inak sa neda testovat).
require_relative '../helper' unless defined?(NxTest)

D130A_HTML  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
D130A_FORM  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')
D130A_CORE  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'core.js'), encoding: 'UTF-8')
D130A_ICONS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')
D130A_USAGE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'usage.js'), encoding: 'UTF-8')
# Komentare von PRED parsovanim CSS (su plne zatvoriek a vysvetlujuceho textu).
D130A_CSS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
                .gsub(%r{/\*.*?\*/}m, ' ')

# Telo skupiny `fronts` v panel.html (od jej `<details>` po zaciatok dalsej).
def d130a_fronts_group
  D130A_HTML[/<details data-key="fronts" data-s4="cela">.*?(?=<details data-key=)/m].to_s
end

# --- 1) KOSTRA: skupina `fhandles` zanikla, popover stoji mimo hlavicky ------

NxTest.test('D-130a R1: kontext Cela ma skupinu „Čelá" s meta, akciou a tooltipom') do
  g = d130a_fronts_group
  NxTest.refute(g.empty?, 'skupina `fronts` v panel.html existuje')
  NxTest.refute(D130A_HTML.include?('data-key="fhandles"'),
                'skupina „Úchytky" ZANIKLA (D-129: uchytka ma JEDINE miesto stavu)')
  NxTest.assert(g.include?('id="frontMeta"'), 'hlavicka nesie meta („3 čelá · 1 bez smeru")')
  NxTest.assert(g.include?('id="frontBulkBtn"'), 'hlavicka ma akciu „všetkým"')
  NxTest.assert(g.include?('id="frontBulkPop"'), 'a k nej popover')
  NxTest.assert(g.include?('class="nxtip r"'), 'hlavicka ma tooltip `?` zarovnany vpravo')
end

NxTest.test('D-130a R1: popover NIE JE v `<summary>` (inak by ho klik zbalil)') do
  g = d130a_fronts_group
  summary = g[%r{<summary[^>]*>.*?</summary>}m].to_s
  NxTest.refute(summary.empty?, 'hlavicka skupiny sa nasla')
  NxTest.refute(summary.include?('id="frontBulkPop"'),
                '`<details>` toggluje na klik KDEKOLVEK v hlavicke — popover musi byt mimo nej')
  NxTest.assert(g.index('id="frontBulkPop"') > g.index('</summary>'),
                'popover je surodenec ZA hlavickou')
  NxTest.assert(g.index('id="frontBulkPop"') < g.index('<div class="body">'),
                'a PRED telom skupiny')
  # Kazde tlacidlo v hlavicke musi zastavit natívny toggle `<details>`.
  NxTest.assert(summary.include?('onclick="onFrontBulkToggle(event)"'),
                'akcia „všetkým" ide cez handler, ktory `preventDefault` robi')
  NxTest.assert(summary.include?('onclick="nxTipStop(event)"'),
                'tooltip v hlavicke tiez (klik na `?` skupinu nezbali)')
  NxTest.assert(D130A_FORM.include?('function nxTipStop(ev)'), 'handler existuje')
  body = D130A_FORM[/function nxTipStop\(ev\)\{.*?\n  \}/m].to_s
  NxTest.assert(body.include?('preventDefault') && body.include?('stopPropagation'),
                'a robi OBOJE — `preventDefault` sam `<details>` nezastavi pri bublani')
end

NxTest.test('D-130a R7-b: popover ma pristupnostny kontrakt (dialog, Esc, fokus)') do
  g = d130a_fronts_group
  NxTest.assert(g.include?('aria-haspopup="dialog"'), 'tlacidlo priznava, ze otvara dialog')
  NxTest.assert(g.include?('aria-expanded="false"'), 'a nesie stav')
  NxTest.assert(g.include?('role="dialog"'), 'popover je dialog')
  NxTest.assert(D130A_FORM.include?("ev.key !== 'Escape' || !frontBulkOpen()"),
                'Escape popover zatvara')
  close = D130A_FORM[/function closeFrontBulk\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(close.include?("closest('#frontBulkPop')"),
                'fokus sa vracia na tlacidlo LEN ked bol v popoveri (inak by sa ukradol)')
end

NxTest.test('D-130a R7-c: trigger otvori ZBALENU skupinu, inak by popover nebolo vidno') do
  # Popover je dieta `<details>` — pri zbalenej skupine ho prehliadac
  # nevykresli, takze klik na „všetkým" by navonok neurobil nic.
  body = D130A_FORM[/function openFrontBulk\(\)\{.*?\n  \}/m].to_s
  NxTest.refute(body.empty?, 'funkcia sa nasla')
  NxTest.assert(body.include?("p.closest('details')"), 'trigger si najde svoju skupinu')
  NxTest.assert(body.include?('grp.open = true'), 'a NAJPRV ju otvori')
  NxTest.assert(body.index('grp.open = true') < body.index('p.hidden = false'),
                'az potom ukaze popover')
end

# --- 2) POMOCNY TEXT = TOOLTIP, STAVOVA VETA OSTAVA -------------------------

NxTest.test('D-130a R8/R9: v kontexte Cela uz nie su `.hint` okrem stavovej vety D-120') do
  g = d130a_fronts_group
  hints = g.scan(/class="hint"/).length
  ids = g.scan(/<div id="(\w+)" class="hint"/).flatten
  NxTest.assert_equal(1, hints, "v skupine Čelá ostal presne jeden `.hint`, nasiel som #{hints}")
  NxTest.assert_equal(['frontDraftMessage'], ids,
                      'a je to STAVOVA veta D-120 (pomocny text patri do tooltipu)')
  # Vety, ktore sa PRESUNULI do tooltipu — v HTML uz nesmu stat ako `.hint`.
  ['F1 je spodné čelo', 'Profil skracuje panel'].each do |moved|
    NxTest.assert(D130A_HTML.include?(moved), "veta #{moved} sa nestratila")
    NxTest.refute(D130A_HTML[/<div class="hint"[^>]*>[^<]*#{Regexp.escape(moved)}/],
                  "veta #{moved} uz nie je `.hint`, ale tooltip")
    NxTest.assert(D130A_HTML[/data-tip="[^"]*#{Regexp.escape(moved)}/],
                  "veta #{moved} zije v `data-tip`")
  end
  edge = D130A_FORM[/function refreshFrontProfileEdgeUI\(items\)\{.*?\n  \}/m].to_s
  NxTest.refute(edge.include?('frontProfileEdgeHint'),
                'hint hrany zanikol aj z JS (je v tooltipe popoveru)')
  # Riadky `kind: 'hint'` vo view-modeli karty zanikli uplne — pomocny text uz
  # nie je riadok, ale tooltip (`tip` pri segmente).
  NxTest.refute(D130A_CORE.include?("kind: 'hint'"),
                'karta cela uz nema riadky typu `hint` (su to tooltipy)')
  NxTest.refute(D130A_FORM.include?("r.kind === 'hint'"), 'a renderer ich uz nekresli')
  # Stavove vety OSTAVAJU — nie su to pomocne texty.
  NxTest.assert(D130A_CORE.include?('Zásuvka bez klasifikácie'), 'stavova veta zasuvky ostava')
  NxTest.assert(D130A_CORE.include?('Mechanizmus vyberá automat'), 'a veta o automate tiez')
end

NxTest.test('D-130a R8: tooltip je vlastny komponent (CEF natívny `title` nestaci)') do
  NxTest.assert(D130A_CSS.include?('.nx-inspector .nxtip::after'),
                'obsah kresli pseudo-element z `data-tip`')
  after = D130A_CSS[/\.nx-inspector \.nxtip::after \{([^}]*)\}/m, 1].to_s
  NxTest.assert(after.include?('content: attr(data-tip)'), 'text ide z atributu, nie z DOM')
  NxTest.assert(after.include?('width: 250px'), 'pevna sirka bubliny (470 px panel)')
  NxTest.refute(after.include?('#'), "farby VYHRADNE cez --nx-* tokeny: #{after}")
  NxTest.assert(D130A_CSS.include?('.nx-inspector .nxtip:hover::after'), 'otvara hover')
  NxTest.assert(D130A_CSS.include?('.nx-inspector .nxtip:focus::after'), 'AJ fokus (klavesnica)')
  NxTest.assert(D130A_CSS.include?('.nx-inspector .nxtip.r::after'),
                'varianta pri pravom okraji (inak by bublina utiekla z panela)')
  NxTest.assert(D130A_ICONS.include?("'help-circle':"), 'ikona `?` je v sprite (ziadne emoji)')
end

# --- 3) MRIEZKA RIADKU ------------------------------------------------------

NxTest.test('D-130a R2: riadok cela je grid so styrmi stalymi stlpcami') do
  cols = D130A_CSS[/\.frow \{([^}]*)\}/m, 1].to_s
  NxTest.assert(cols.include?('display: grid'), 'riadok je mriezka')
  NxTest.assert(cols.include?('grid-template-columns: 22px minmax(0, 1fr) 112px 22px'),
                "stlpce su pevny rozpocet 22 / 1fr / 112 / 22: #{cols}")
  NxTest.refute(cols.include?('flex-wrap'), 'ziadne zalamovanie — poloha stlpcov je dana')
  # Pole vysky ma KONSTANTNU sirku: chip AUTO odobera miesto HODNOTE, nie boxu.
  hbox = D130A_CSS[/\.frow \.hbox \{([^}]*)\}/m, 1].to_s
  NxTest.assert(hbox.include?('grid-column: 3'), 'box vysky ma SVOJ stlpec')
  NxTest.assert(hbox.include?('height: 26px'), 'a pevnu vysku (chip ho nerozhodi)')
  NxTest.assert(D130A_CSS.include?('.frow .hbox.fixed .fauto'),
                'chip AUTO sa ukazuje LEN pri vypisanej vyske')
  # R6-c: chip je TLACIDLO (fokusovatelne), nie dekoracia.
  NxTest.assert(D130A_FORM.include?('<button type="button" class="fauto" onclick="frontHeightAuto(this, event)"'),
                'chip AUTO je tlacidlo s povodnym handlerom')
  NxTest.assert(D130A_FORM.include?('aria-label="Vrátiť výšku čela na AUTO"'), 'a ma popis pre citacku')
end

NxTest.test('D-130a R4: placeholder „≈" sa neda zamenit s pevnou hodnotou') do
  ph = D130A_CSS[/\.frow \.hbox input\.fh::placeholder \{([^}]*)\}/m, 1].to_s
  NxTest.assert(ph.include?('font-style: italic'), 'odhad je KURZIVOU (outside-in packet 3)')
  NxTest.assert(ph.include?('var(--nx-ink-faint)'), 'a tlmeny')
  fixed = D130A_CSS[/\.frow \.hbox\.fixed input\.fh \{([^}]*)\}/m, 1].to_s
  NxTest.assert(fixed.include?('font-weight: 700'), 'pevna hodnota je TUCNA')
  NxTest.assert(D130A_FORM.include?('title="AUTO — výška sa dopočítava z voľného miesta'),
                'box vysvetli pravidlo v `title`')
end

# --- 4) ZDROJ HODNOT: kridla v datasete, suhrn v core.js --------------------

NxTest.test('D-130a R5: `collectFronts` cita kridla z DATASETU (select v riadku zanikol)') do
  body = D130A_FORM[/function collectFronts\(\)\{.*?\n  \}\n/m].to_s
  NxTest.refute(body.empty?, 'funkcia sa nasla')
  NxTest.refute(body.include?(".querySelector('.fw')"), 'rozbalovacka kridel sa uz necita')
  NxTest.assert(body.include?("r.dataset.frontWings || 'auto'"),
                'hodnota zije v datasete; legacy riadok bez kluca ide na `auto` (1:1 so selectom)')
  NxTest.refute(D130A_FORM.include?('aria-label="Počet krídel"'),
                'select kridel v riadku uz neexistuje')
  NxTest.assert(D130A_CORE.include?('var FRONT_WINGS_OPTIONS'),
                'volby kridiel ziju v ciestom jadre (segment karty)')
end

NxTest.test('D-130a R3: suhrn riadku je CISTA funkcia v core.js a je exportovana') do
  NxTest.assert(D130A_CORE.include?('function frontRowSummary(item, entry, hw, reg, drawer)'),
                'suhrn sklada `frontRowSummary` (testovatelna bez DOM)')
  NxTest.assert(D130A_CORE.include?('frontRowSummary: frontRowSummary'),
                'a je exportovana pre Node sady')
  NxTest.assert(D130A_FORM.include?('function updateFrontRowSummary(row)'),
                'panel ju LEN kresli — jedna obnovovacia cesta')
  # R3-a: pocet kridiel hovori SERVER (AUTO nad 600 mm = 2 kridla).
  NxTest.assert(D130A_CORE.include?('function frontSumWings(entry)'),
                'pocet kridiel sa cita zo `front_slots[fid].wings_n`, neodvodzuje sa v JS')
  # Samostatny riadok `.fhw` zanikol — kovanie je koncovka riadku suhrnu.
  NxTest.refute(D130A_FORM.include?("row.querySelector('.fhw')"), 'riadok `.fhw` zanikol')
  NxTest.refute(D130A_CSS.include?('.frow .fhw {'), 'aj jeho styl')
end

NxTest.test('D-130a R3-f: kovanie je SURODENEC suhrnu, nie ovladac v ovladaci') do
  body = D130A_FORM[/function addFrontRow\(item, userAdd\)\{.*?\n  \}\n/m].to_s
  NxTest.assert(body.include?('<span class="fsubwrap">'), 'druhy riadok mriezky je obal')
  NxTest.assert(body.include?('<button type="button" class="fsub"'), 'suhrn je NATIVNE tlacidlo')
  NxTest.assert(body.include?('<button type="button" class="fhwlink"'),
                'kovanie je VLASTNE, fokusovatelne tlacidlo (nie `role=link` v tlacidle)')
  # Vnorene tlacidlo je neplatne HTML a neda sa fokusovat — obe musia byt
  # PRIAMYMI detmi obalu.
  NxTest.assert(body.index('class="fhwlink"') > body.index('class="fsub"'),
                'poradie: suhrn, potom koncovka kovania')
  NxTest.refute(body.include?('role="link"'), 'ziadny `role=link` v tlacidle')
  wrap = D130A_CSS[/\.frow \.fsubwrap \{([^}]*)\}/m, 1].to_s
  NxTest.assert(wrap.include?('display: flex'), 'obal je flex')
  NxTest.assert(D130A_CSS[/\.frow \.fsub \{([^}]*)\}/m, 1].to_s.include?('flex: 1 1 0'),
                'suhrn rastie a oreze sa')
  NxTest.assert(D130A_CSS[/\.frow \.fhwlink \{([^}]*)\}/m, 1].to_s.include?('flex: 0 0 auto'),
                'koncovka kovania ma PEVNU stopu (suhrn ju nikdy neoreze)')
  NxTest.assert(D130A_FORM.include?('function onFrontSummaryHw(ev, node)'),
                'klik otvori kartu rovno na tabe Kovanie')
  hw = D130A_FORM[/function onFrontSummaryHw\(ev, node\)\{.*?\n  \}/m].to_s
  NxTest.assert(hw.include?("openFrontCardTab = 'hw'"), 'a naozaj na tabe Kovanie')
  NxTest.refute(hw.include?('setViewContext'),
                'prepnutie KONTEXTU robi az tlacidlo v tabe (N13 — jeden klik, jeden skok)')
end

# --- 5) KARTA S TABMI a preklik do Kovania ----------------------------------

NxTest.test('D-130a R6: karta ma taby a preklik pouziva TU ISTU konvenciu skupiny') do
  NxTest.assert(D130A_CORE.include?('function frontCardTabs(type, dirUnset)'),
                'taby su cisty view-model')
  NxTest.assert(D130A_FORM.include?('function onFrontCardTab(btn)'), 'prepnutie tabu ma handler')
  tab = D130A_FORM[/function onFrontCardTab\(btn\)\{.*?\n  \}/m].to_s
  NxTest.refute(tab.include?('onField'), 'prepnutie tabu NIC NEZAPISUJE (ziadny krok Späť)')
  NxTest.assert(D130A_FORM.include?("var openFrontCardTab = 'celo'"),
                'default je tab Čelo')
  # Preklik do kontextu Kovanie ide cez JEDINE miesto konvencie kluca skupiny.
  hw = D130A_FORM[/function frontCardHwHtml\(row, m\)\{.*?\n  \}/m].to_s
  NxTest.assert(hw.include?('hwBoxByGroup(hwFrontGroup(fid))'),
                'tlacidlo vie, ci box vlastnika VOBEC existuje (D-78)')
  NxTest.assert(hw.include?('aria-disabled="true"'),
                'a ked neexistuje, ostane viditelne s dovodom v `title` (nikdy sa neskryva)')
  NxTest.assert(hw.include?('Bez kovania.'), 'prazdny tab povie jednou vetou, ze nic nie je')
end

# --- 5b) CODEX #371 kolo 1: sest P2 nalezov --------------------------------

NxTest.test('D-130a (Codex #371 P2-1): „Bez kovania" sa odvodzuje z REALNEHO kovania vlastnika') do
  # Vyriesne riadky (`front_drawer` / `front_lift`) ma LEN zasuvka a vyklop.
  # Dvierka, sklop aj blenda s uchytkovym profilom kovanie MAJU — hovori oň
  # plan a nakup, nie serverovy zaznam. Prazdny stav sa preto NESMIE odvodzovat
  # len z `m.hwRows`.
  hw = D130A_FORM[/function frontCardHwHtml\(row, m\)\{.*?\n  \}/m].to_s
  NxTest.refute(hw.empty?, 'funkcia sa nasla')
  NxTest.assert(hw.include?('frontHwBadge(fid)') && hw.include?('frontHwBuy(fid)'),
                'prazdny stav pozna TEXT kovania (tie iste zdroje ako suhrn riadku)')
  NxTest.assert(hw.index('if (text)') < hw.index('Bez kovania.'),
                'a veta „Bez kovania" padne az ako POSLEDNA moznost')
  NxTest.assert(hw.include?('has'), 'do rozhodnutia vstupuje aj existencia boxu vlastnika')
end

NxTest.test('D-130a (Codex #371 P2-3): deep-link `nxFocusFront` otvara kartu na tabe Čelo') do
  # RED nalez SMERU vedie na otazku, ktora zije v tabe Čelo — bez resetu by sa
  # cielova karta otvorila na tabe Kovanie (stav po predchadzajucej karte).
  body = D130A_FORM[/function nxFocusFront\(fid\)\{.*?\n  \}/m].to_s
  NxTest.refute(body.empty?, 'funkcia sa nasla')
  NxTest.assert(body.include?("openFrontCardTab = 'celo'"), 'tab sa RESETUJE')
  NxTest.assert(body.index("openFrontCardTab = 'celo'") < body.index('refreshFrontCards()'),
                'a to PRED prekreslenim karty')
end

NxTest.test('D-130a (Codex #371 P2-4): badge „smer?" rata LEN z aktivnych slotov') do
  # Navrat zo 4 kridiel na 2 necha `p2: unset` ako DORMANTNU hodnotu (A1
  # kontrakt: navrat nic nemaze). Skenovanie celeho `wing_directions` by badge
  # nechalo svietit navzdy na otazku, ktoru uz nikto nekladie.
  body = D130A_CORE[/function frontSumDirUnset\(item, entry\)\{.*?\n  \}/m].to_s
  NxTest.refute(body.empty?, 'funkcia berie aj ZAZNAM SERVERA')
  NxTest.assert(body.include?('Array.isArray(e.slots)'), 'rozhoduju AKTIVNE sloty')
  NxTest.assert(body.include?('frontDirValue(it, wing)'),
                'hodnota sa cita pre KONKRETNE kridlo (nie prechodom cez vsetky ulozene)')
  NxTest.refute(body.include?('for (var k in wd)'),
                'prechod cez vsetky ulozene `wing_directions` zanikol')
  NxTest.assert(body.include?('it.direction === FRONT_DIR_UNSET'),
                'bez slotov rozhoduje scalarny smer (pri jednom kridle)')
end

NxTest.test('D-130a (Codex #371 P2-5): stlmene „Otvoriť v Kovaní" nerobi nic a skok overi ciel') do
  guard = D130A_FORM[/function onFrontOpenHardware\(btn, fid\)\{.*?\n  \}/m].to_s
  NxTest.refute(guard.empty?, 'klik ma vlastny guard')
  NxTest.assert(guard.include?("getAttribute('aria-disabled') === 'true'"),
                'a `aria-disabled` tlacidlo NEROBI NIC (D-78 stlmenie nie je len vzhlad)')
  open = D130A_FORM[/function openFrontHardware\(fid\)\{.*?\n  \}/m].to_s
  NxTest.refute(open.empty?, 'skok sa nasiel')
  NxTest.assert(open.index('hwBoxByGroup(hwFrontGroup(fid))') < open.index("setViewContext('kovanie')"),
                'ciel sa overuje PRED prepnutim kontextu — neuspesny skok kontext NEMENI')
end

NxTest.test('D-130a (Codex #371 P2-6): Escape popoveru SPOTREBUJE udalost') do
  # Vsetky Escape listenery okna visia na `document` a `stopPropagation` medzi
  # nimi nefunguje (lekcia nx_esc.js) — bez spotrebovania by jedno stlacenie
  # zavrelo popover AJ flyout z boot.js.
  esc = D130A_FORM[/document\.addEventListener\('keydown'.*?\n    \}\);/m].to_s
  NxTest.refute(esc.empty?, 'handler sa nasiel')
  NxTest.assert(esc.include?('stopImmediatePropagation'), 'udalost sa SPOTREBUJE')
  NxTest.assert(esc.include?('preventDefault'), 'a natívne spravanie sa zrusi')
  # Poradie skriptov je kontrakt: retaz modalov (`nx_esc.js`) bezi PRVA,
  # popover (`form.js`) az za nou, flyouty raily (`boot.js`) nakoniec.
  esc_i = D130A_HTML.index('js/nx_esc.js')
  form_i = D130A_HTML.index('js/form.js')
  boot_i = D130A_HTML.index('js/boot.js')
  NxTest.assert(esc_i && form_i && boot_i, 'vsetky tri skripty su v panel.html')
  NxTest.assert(esc_i < form_i, '`nx_esc.js` PRED `form.js` (modal je nad popoverom)')
  NxTest.assert(form_i < boot_i, '`form.js` PRED `boot.js` (popover je nad flyoutmi raily)')
end

# --- 6) MERAC: nove kluce su v allowliste -----------------------------------

NxTest.test('D-130a: nove ovladace maju kluce meraca (D-25 invariant)') do
  %w[fronts:karta fronts:suhrn fronts:suhrn-kovanie fronts:vsetkym
     fronts:vsetkym-pouzit fronts:do-kovania].each do |key|
    NxTest.assert(D130A_USAGE.include?("'#{key}'"), "kluc `#{key}` je v allowliste usage.js")
    NxTest.assert(D130A_FORM.include?("data-nx-usage=\"#{key}\"") ||
                  D130A_HTML.include?("data-nx-usage=\"#{key}\""),
                  "a niekto ho naozaj pouziva")
  end
end
