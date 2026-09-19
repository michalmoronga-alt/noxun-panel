# frozen_string_literal: true
# SMOKE PACK 1 (Michal 20.8.) — RIADKY, KTORE SA NESMU ROZBIT.
#
# Dva nalezy zo smoke testu Inspector reworku maju spolocnu pricinu: riadok
# plny ovladacov sa pri DEFAULT sirke panela (obsah 470 px, D-51) nezmestil.
#   1) Zoznam ciel — pri VYPISANEJ vyske pribudlo „mm" + chip AUTO, sucet
#      presiahol sirku a `.frow` (zalamovaci flex rad) poslal krizik ✗
#      o riadok nizsie.
#   2) Kovanie — `.hwname` nemal ellipsis, takze dlhy label („Výsuv zásuvkové
#      čelo") pretiekol cez select dlzky/setu a PREKRYL ho.
#
# Tento test je POISTKA PRE BUDUCNOST: ked niekto do riadku prida dalsi
# ovladac, spadne tu — nie az na Michalovej obrazovke. Ratame len to, co sa
# rátať DA (deklarovane pevne stopy + medzery); text a natívne selecty sa
# neratáju, tie su prave preto pruzne a s ellipsis.
#
# D-130a (19.9.2026) — PRECO UZ NIE FLEX, ALE GRID:
# Flex rad drzal riadok pohromade, ale poloha poli zavisela od TOHO, CO
# v riadku prave bolo: chip AUTO, „mm", select kridel a ikona profilu tlacili
# pole vysky vpravo, takze pri kazdom cele stalo inde a oko ho muselo hladat
# (D-130 „polia lietajú"). `.frow` je preto CSS GRID so STALYMI STLPCAMI
#   [22 cislo][minmax(0,1fr) nazov + suhrn][112 pole vysky][22 ✕]
# a riadkami 1 = nazov · 2 = suhrn · 3 = karta. Rozpocet sa tym NEMENI, len
# sa rata z `grid-template-columns` namiesto zo sumy `flex` stop.
#
# ROZPOCET SIRKY (odvodenie, panel.css + panel.html):
#   470  obsahovy viewport Inspectora (NX_FIT_MIN, docs/UI_DIZAJN.md §D-51)
#   -54  `body` padding-left (10 + rail 44)   -10  `body` padding-right
#   -18  `.sect > .sectbody` padding           -2  ramik sektora
#   -20  `.body` skupiny padding               -2  ramik skupiny
#   -15  rezerva na zvisly scrollbar CEF
#   = 349 px pre riadok zoznamu ciel; box kovania ma navyse ramik `.hwbox`
#     a `.hwboxb` padding, teda 349 - 2 - 16 = 331 px.
require_relative '../helper' unless defined?(NxTest)

# Komentare von PRED parsovanim — v panel.css su plne vysvetlujuceho textu
# (aj so zatvorkami), ktory by hranice pravidiel rozhodil.
SMOKE1_CSS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
                 .gsub(%r{/\*.*?\*/}m, ' ')
SMOKE1_FORM = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')

# Sirka karty pre riadok cela / riadok kovania (odvodenie v hlavicke suboru).
SMOKE1_FRONT_BUDGET = 349
SMOKE1_HW_BUDGET = 331

# Tela VSETKYCH pravidiel daneho selektora, v poradi zdroja.
def smoke1_rules(selector)
  out = []
  SMOKE1_CSS.scan(/(^|\})\s*([^{}]+?)\s*\{([^{}]*)\}/m) do |_pre, sel, body|
    out << body if sel.split(',').map(&:strip).include?(selector)
  end
  out
end

# EFEKTIVNA hodnota vlastnosti: posledna deklaracia v zdroji vyhrava (presne
# ako kaskada pri rovnakej specificite — `.hwrow .hwname` je napr. deklarovany
# dvakrat, druhy raz pre okno Katalog kovania). nil = nikde sa nedeklaruje.
def smoke1_decl(selector, prop)
  val = nil
  smoke1_rules(selector).each do |body|
    m = body[/(?:\A|;)\s*#{Regexp.escape(prop)}\s*:\s*([^;]+)/, 1]
    val = m.strip unless m.nil?
  end
  val
end

# Pevna stopa flex polozky v px: `flex: <grow> <shrink> <basis>` alebo `width`.
# nil = polozka nie je pevna (rastie/zmrsti sa) — do rozpoctu ide ako 0 a
# spolieha sa na `min-width`, ktora sa rata zvlast.
def smoke1_fixed_px(selector)
  flex = smoke1_decl(selector, 'flex').to_s
  m = flex.match(/\A(\d+)\s+(\d+)\s+(\d+(?:\.\d+)?)px\z/)
  return m[3].to_f if m && m[1] == '0' && m[2] == '0'

  nil
end

def smoke1_min_px(selector)
  v = smoke1_decl(selector, 'min-width').to_s
  v.end_with?('px') ? v.to_f : 0.0
end

# ---------------------------------------------------------------------------
# 1) Zoznam ciel — riadok je STLPEC, ovladace su NEZALAMOVACI rad
# ---------------------------------------------------------------------------

NxTest.test('SMOKE1 cela: `.frow` je GRID so STALYMI stlpcami (polia uz nelietaju)') do
  NxTest.assert_equal('grid', smoke1_decl('.frow', 'display'),
                      'riadok cela je mriezka — poloha pola nezavisi od toho, co v riadku prave je')
  NxTest.assert_equal('22px minmax(0, 1fr) 112px 22px', smoke1_decl('.frow', 'grid-template-columns'),
                      'stlpce: cislo · nazov+suhrn · pole vysky · ✕ (pevny rozpocet)')
  NxTest.assert_equal(nil, smoke1_decl('.frow', 'flex-wrap'),
                      'stary `flex-wrap: wrap` na `.frow` uz neexistuje')
  NxTest.assert_equal(nil, smoke1_decl('.frow .fmain', 'flex-wrap'),
                      'obal `.fmain` zanikol — deti ziju priamo v mriezke')
end

NxTest.test('SMOKE1 cela: jemne predelenie medzi celami NEPRIDAVA vertikalny priestor') do
  border = smoke1_decl('.frow + .frow', 'border-top').to_s
  NxTest.assert(border.include?('1px'), 'predel je hairline, nie ram')
  NxTest.assert(border.include?('var(--nx-border-soft)'), 'pouziva sa TOKEN jemneho rozdelovnika')

  # 4 px odstupu zostava: bolo `margin: 4px 0` (kolabujuce), teraz
  # `padding: 2px 0 1px` + 1 px linka = 1 + 2 + 1.
  NxTest.assert_equal('0', smoke1_decl('.frow', 'margin'), 'odstup sa presunul do paddingu')
  NxTest.assert_equal('2px 0 1px', smoke1_decl('.frow', 'padding'),
                      'spodok 1 px + vrch 2 px + linka 1 px = povodne 4 px medzi celami')
end

NxTest.test('SMOKE1 cela: sucet stlpcov + medzier sa VOJDE do sirky karty') do
  # D-130a: rozpocet uz nie je sucet `flex` stop, ale STLPCE MRIEZKY. Sirky su
  # deklarovane na JEDNOM mieste (`grid-template-columns`), takze novy ovladac
  # sa uz nema kde „pritlacit" — musi si v mriezke najst miesto.
  cols = smoke1_decl('.frow', 'grid-template-columns').to_s
  fixed_cols = cols.scan(/(\d+(?:\.\d+)?)px/).flatten.map(&:to_f)
  NxTest.assert_equal(3, fixed_cols.length, 'tri PEVNE stlpce (cislo, pole vysky, ✕)')
  NxTest.assert(cols.include?('minmax(0, 1fr)'),
                'stredny stlpec rastie a SMIE sa zmrstit (`minmax(0,1fr)` — bez neho ho dlhy suhrn rozsiri)')

  gap = smoke1_decl('.frow', 'column-gap').to_f
  NxTest.assert(gap.positive?, 'mriezka ma deklarovanu medzeru')
  gaps = gap * 3 # 4 stlpce = 3 medzery

  # Stredny stlpec nesie NAZOV aj SUHRN — obe su jednoriadkove s ellipsis,
  # takze do rozpoctu ide ich CITATELNE minimum (nie skutocna dlzka textu).
  middle_min = 120

  total = fixed_cols.sum + middle_min + gaps
  NxTest.assert(total <= SMOKE1_FRONT_BUDGET,
                "riadok cela pri 470 px: #{total.round} px <= #{SMOKE1_FRONT_BUDGET} px")

  # Pole vysky je JEDEN BOX s KONSTANTNOU sirkou — chip AUTO odobera miesto
  # HODNOTE, nie boxu. Prave toto bola pricina „lietajucich poli" (D-130).
  NxTest.assert_equal('3', smoke1_decl('.frow .hbox', 'grid-column'),
                      'box vysky ma SVOJ stlpec (nie „to, co zvysi")')
  NxTest.assert_equal('1 / 3', smoke1_decl('.frow .hbox', 'grid-row'),
                      'a stoji cez oba riadky (nazov + suhrn)')
  NxTest.assert_equal('1 1 0', smoke1_decl('.frow .hbox input.fh', 'flex'),
                      'hodnota berie zvysok boxu — chip AUTO ju zmensi, box nie')
end

# KOV-A2a: karta cela nesmie rozbit ani mriezku, ani predel medzi celami.
NxTest.test('SMOKE1 cela: karta cela je TRETI RIADOK mriezky, nie polozka radu') do
  NxTest.assert(SMOKE1_FORM.include?("card.className = 'fcard'"), 'karta ma svoju triedu')
  NxTest.assert(SMOKE1_FORM.include?('row.appendChild(card); // karta je VZDY posledna v riadku'),
                'karta patri do `.frow`, nie do ziadneho obalu ovladacov')
  NxTest.assert_equal('3', smoke1_decl('.nx-inspector .frow .fcard', 'grid-row'),
                      'karta je TRETI riadok mriezky (pod nazvom aj suhrnom)')
  NxTest.assert_equal('2 / 5', smoke1_decl('.nx-inspector .frow .fcard', 'grid-column'),
                      'a tiahne sa od nazvu po ✕ (cislo cela ostava vlavo)')
  NxTest.assert(smoke1_decl('.nx-inspector .frow .fcard', 'border').to_s.include?('var(--nx-part-border)'),
                'karta pouziva TOKEN ramika (ziadny natvrdo zapisany hex)')
end

NxTest.test('SMOKE1 cela (Codex #183 P2): zivy nahlad vyrazu NEZABERA sirku pola') do
  # `= 450` pri rozpisanom vyraze `300+150` je v riadku cela OVERLAY. Ako flex
  # polozka (`flex: 0 0 auto`) by odtlacil hodnotu v 112 px boxe.
  #
  # Codex #371 P2: SELEKTOR MUSI SEDIET NA SKUTOCNEHO RODICA. `expr.js` vklada
  # hint `insertAdjacentElement('afterend')` hned za `input.fh`, teda do
  # `.hbox` — nie do `.dwrap` (tam ostala len sipka vyskoveho radu). Pravidlo
  # na `.dwrap` by nesedelo na nic a hint by sa spraval ako flex polozka.
  sel = '.nx-inspector .frow .hbox .exprhint'
  NxTest.assert_equal('absolute', smoke1_decl(sel, 'position'), 'hint je mimo toku boxu')
  NxTest.assert_equal('none', smoke1_decl(sel, 'pointer-events'),
                      'overlay nesmie kradnut kliky poliam pod nim')
  NxTest.assert_equal('relative', smoke1_decl('.frow .hbox', 'position'),
                      'a `.hbox` je jeho KOTVA (inak by sa ukotvil na cudzieho predka)')
  NxTest.assert_equal(nil, smoke1_decl('.nx-inspector .frow .dwrap .exprhint', 'position'),
                      'stary (nesediaci) selektor na `.dwrap` uz neexistuje')
  # Pod `.miniopts` (120) — ked je otvoreny rozmerovy rad, hodnoty maju prednost.
  NxTest.assert(smoke1_decl(sel, 'z-index').to_i <
                smoke1_decl('.nx-inspector .miniopts', 'z-index').to_i,
                'hint nesmie prekryt otvorenu ponuku rozmeroveho radu')
end

NxTest.test('SMOKE1 cela: nazov a suhrn ziju v ROVNAKOM (rastucom) stlpci') do
  # D-130a: rastucim prvkom uz nie je jedna flex polozka, ale STREDNY STLPEC
  # mriezky. Nazov aj suhrn su v nom nad sebou — obe sa musia OREZAT (nie
  # tlacit susedov), inak by dlhy text rozsiril cely riadok.
  NxTest.assert_equal('2', smoke1_decl('.frow .ftname', 'grid-column'), 'nazov je v strednom stlpci')
  NxTest.assert_equal('1', smoke1_decl('.frow .ftname', 'grid-row'), 'a v prvom riadku')
  # R3-f: suhrn zije v OBALE `.fsubwrap` spolu s koncovkou kovania — obal je
  # ten, kto sedi v mriezke.
  NxTest.assert_equal('2', smoke1_decl('.frow .fsubwrap', 'grid-column'),
                      'suhrn je v TOM ISTOM stlpci')
  NxTest.assert_equal('2', smoke1_decl('.frow .fsubwrap', 'grid-row'), 'a pod nazvom')
  NxTest.assert_equal('1 1 0', smoke1_decl('.frow .fsub', 'flex'), 'suhrn rastie a oreze sa')
  NxTest.assert_equal('0 0 auto', smoke1_decl('.frow .fhwlink', 'flex'),
                      'koncovka kovania ma PEVNU stopu')
  NxTest.assert_equal(nil, smoke1_decl('.frow select.ftype', 'flex'),
                      'rozbalovacka typu v riadku uz neexistuje')
  NxTest.assert_equal(nil, smoke1_decl('.frow select.fw', 'flex'),
                      'rozbalovacka kridel v riadku uz neexistuje (je to segment v karte)')
  NxTest.assert_equal(nil, smoke1_decl('.frow .fprof', 'flex'),
                      'indikator profilu v riadku uz neexistuje (hovori SUHRN slovom)')
  # Oba texty su JEDNORIADKOVE s ellipsis — plne znenie nesie `title`.
  NxTest.assert_equal('ellipsis', smoke1_decl('.frow .ftname .ftl', 'text-overflow'))
  NxTest.assert_equal('nowrap', smoke1_decl('.frow .ftname .ftl', 'white-space'))
  NxTest.assert_equal('ellipsis', smoke1_decl('.frow .fsub', 'text-overflow'))
  NxTest.assert_equal('nowrap', smoke1_decl('.frow .fsub', 'white-space'))
  NxTest.assert_equal('0', smoke1_decl('.frow .fsub', 'min-width'),
                      'suhrn sa SMIE zmrstit — bez toho by dlhy text rozsiril mriezku')
end

NxTest.test('SMOKE1 cela: markup riadku kladie deti PRIAMO do mriezky') do
  body = SMOKE1_FORM[/function addFrontRow.*?\n  \}\n/m].to_s
  NxTest.refute(body.include?('class="fmain"'), 'obal `.fmain` zanikol — deti ziju v mriezke')
  NxTest.assert(body.include?("'<span class=\"fnum\">F' + idx + '</span>'"), 'riadok zacina cislom cela')
  # Kazde dieta sa hlada VYHRADNE cez triedu (nikdy cez index) — obrateny
  # render D-23 a `keepGaps` guard na tom stoja.
  ['class="ftname"', 'class="fsub"', 'class="hbox"', 'class="fdel"'].each do |cls|
    NxTest.assert(body.include?(cls), "riadok ma #{cls}")
  end
  # Samostatny riadok kovania `.fhw` ZANIKOL — je to posledna cast suhrnu.
  NxTest.refute(SMOKE1_FORM.include?("row.querySelector('.fhw')"), 'riadok kovania zanikol')
end

# ---------------------------------------------------------------------------
# 2) Kovanie — nazov sa OREZE, nikdy nepretecie cez susedny ovladac
# ---------------------------------------------------------------------------

NxTest.test('SMOKE1 kovanie: `.hwname` je jednoriadkovy s ellipsis') do
  NxTest.assert_equal('hidden', smoke1_decl('.hwrow .hwname', 'overflow'))
  NxTest.assert_equal('ellipsis', smoke1_decl('.hwrow .hwname', 'text-overflow'))
  NxTest.assert_equal('nowrap', smoke1_decl('.hwrow .hwname', 'white-space'))
  NxTest.assert_equal('nowrap', smoke1_decl('.hwrow', 'flex-wrap'), 'riadok kovania sa nezalamuje')
end

NxTest.test('SMOKE1 kovanie: plny popis riadku nesie `title` (orezany text sa MUSI dat precitat)') do
  hw = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'), encoding: 'UTF-8')
  item = hw[/function hwItemHtml.*?\n  \}\n/m].to_s
  NxTest.assert(item.include?('<span class="hwname" title='), 'polozka ma plny popis v title')
  off = hw[/function hwOffHtml.*?\n  \}\n/m].to_s
  NxTest.assert(off.include?('<span class="hwname" title='), 'aj vypnuta kategoria ma plny popis v title')
end

NxTest.test('SMOKE1 kovanie: sucet ovladacov riadku sa VOJDE do boxu vlastnika') do
  qty = smoke1_fixed_px('.hwrow .hwqty')
  NxTest.assert(!qty.nil?, 'pole poctu ma pevnu stopu')
  gap = smoke1_decl('.hwrow', 'gap').to_f
  NxTest.assert(gap.positive?, 'riadok ma deklarovanu medzeru')

  nl = smoke1_min_px('.hwrow .hwnlsel')       # rad dlzok vysuvu (D-93)
  set = smoke1_min_px('.hwrow:not(.hwsetrow) .hwsetsel') # set kovania (D-81)
  NxTest.assert(nl.positive? && set.positive?, 'oba selecty maju citatelne minimum')

  # Najhorsi realny riadok (vysuv zasuvkoveho cela): nazov · NL select · zamok ·
  # set · pocet · jednotka · zdroj/reset · vypnut = 8 poloziek, 7 medzier.
  lock = 26 # `.hwlock` = ghost tlacidlo s ikonou
  unit = 26 # „sada"
  src = 16  # `.hwsrc`
  del = 26  # „Vypnúť položku"
  total = nl + lock + set + qty + unit + src + del + gap * 7
  NxTest.assert(total <= SMOKE1_HW_BUDGET,
                "riadok kovania pri 470 px: #{total.round} px <= #{SMOKE1_HW_BUDGET} px " \
                '(zvysok ostava nazvu, ktory sa oreze)')
end

# ---------------------------------------------------------------------------
# 3) Podperky polic — suhrnny rozklik (zoskupenie ZOBRAZENIA, nie dat)
# ---------------------------------------------------------------------------

NxTest.test('SMOKE1 podperky: suhrnny rozklik je `<details>` so zapamatanym stavom') do
  hw = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'), encoding: 'UTF-8')
  NxTest.assert(hw.include?("'<details class=\"hwgrp\""), 'rozklik je natívny <details> (nxRevealTarget ho vie otvorit)')
  NxTest.assert(hw.include?("var HW_PINS_KEY = 'nx_hw_shelfpins_open'"), 'stav rozkliku zije v localStorage POCITACA')
  NxTest.assert(hw.include?('function onHwGrpToggle'), 'zmena stavu sa uklada')
  # Zbaleny je default: `open` sa nasadzuje LEN ked localStorage povie '1'.
  NxTest.assert(hw.include?("(hwShelfPinsOpen() ? ' open' : '')"), 'zbalene je predvolene')
  NxTest.assert_equal(nil, smoke1_decl('.hwgrpb', 'display'),
                      'zbalenie robi <details>, nie CSS display — inak by sa stavy rozisli')
end

NxTest.test('SMOKE1 podperky: zoskupenie sa DAT nedotyka (identita riadku ostava)') do
  hw = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'), encoding: 'UTF-8')
  pins = hw[/function hwShelfPinsHtml.*?\n  \}\n/m].to_s
  NxTest.assert(pins.include?('hwItemHtml(it, cabId, groupKey)'),
                'pod rozklikom su POVODNE riadky — pocet per polica sa da dalej editovat')
  NxTest.assert_equal(false, pins.include?('quantity'), 'suhrn nic nedopocitava do riadku')
  # Codex #183 P2: vypnuta polica patri POD ten isty rozklik.
  NxTest.assert(pins.include?('hwOffHtml(ov, cabId, groupKey)'),
                'vypnute podperky su v rozkliku, nie vedla neho')
  box = hw[/function hwBoxHtml.*?\n  \}\n/m].to_s
  NxTest.assert(box.include?('hwSplitShelfPins(g.key, g.items, g.offs)'),
                'delenie vidi OBA zoznamy — inak by vypnuta polica utiekla vedla suhrnu')
  NxTest.assert(box.include?('split.restOffs'), 'mimo suhrnu ostavaju len NEpodperkove vypnute kategorie')
  # Zivy refresh nakupu hlada riadky selektorom (nie indexom deti) — o uroven
  # hlbsie zanorenie mu preto nevadi.
  NxTest.assert(hw.include?("var row = box.querySelector(sel);"), 'refresh hlada riadok selektorom')
end
