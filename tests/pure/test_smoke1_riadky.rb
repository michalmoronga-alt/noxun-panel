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

NxTest.test('SMOKE1 cela: `.frow` je stlpec a `.fmain` sa NEZALAMUJE') do
  NxTest.assert_equal('column', smoke1_decl('.frow', 'flex-direction'),
                      'riadok cela = ovladace + kovanie pod nimi, nie jeden zalamovaci rad')
  NxTest.assert_equal('nowrap', smoke1_decl('.frow .fmain', 'flex-wrap'),
                      'ovladace sa NIKDY nesmu zalomit — presne to poslalo krizik o riadok nizsie')
  NxTest.assert_equal(nil, smoke1_decl('.frow', 'flex-wrap'),
                      'stary `flex-wrap: wrap` na `.frow` uz neexistuje')
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

NxTest.test('SMOKE1 cela: sucet pevnych stop + medzier sa VOJDE do sirky karty') do
  # Poradie zodpoveda markupu `addFrontRow` (form.js).
  # KOV-A2a: `select.ftype` z radu ZANIKOL (typ sa vybera piktogramom v karte
  # cela) a jeho miesto zabralo tlacidlo `.ftname`. Ikona typu `.ftico` uz nie
  # je samostatna polozka radu — zije UVNUTRI `.ftname`, takze ju kryje jeho
  # `min-width` a do rozpoctu sa NERATA druhykrat.
  fixed = {
    '.frow .fnum' => smoke1_fixed_px('.frow .fnum'),
    '.frow input.fh' => smoke1_fixed_px('.frow input.fh'),
    '.frow select.fw' => smoke1_fixed_px('.frow select.fw'),
    '.frow .fprof' => smoke1_fixed_px('.frow .fprof'),
    '.frow .fdel' => smoke1_fixed_px('.frow .fdel')
  }
  fixed.each { |sel, px| NxTest.assert(!px.nil?, "#{sel} ma PEVNU stopu (flex: 0 0 Npx)") }

  gap = smoke1_decl('.frow .fmain', 'gap').to_f
  NxTest.assert(gap.positive?, 'rad ma deklarovanu medzeru')

  # 8 flex poloziek radu = 7 medzier: fnum · ftname · dwrap · funit · fauto ·
  # fw · fprof · fdel.
  gaps = gap * 7
  # `.dwrap` je obal pola vysky: input + 2 px + sipka radu (`.pbtn` 17 px).
  dwrap = fixed['.frow input.fh'] + 2 + 17
  # Nemeratelne, ale realne: „mm" (~14 px) + chip AUTO (~36 px) — prave tato
  # dvojica riadok pretiekla, takze v rozpocte MUSI byt.
  unit_auto = 14 + 36
  ftname_min = smoke1_min_px('.frow .ftname')
  NxTest.assert(ftname_min.positive?, 'nazov typu ma citatelne minimum (aj s ikonou vnutri)')
  # Badge „smer?" (KOV-A2a) sa v riadku objavi LEN pri neurcenom smere — je
  # nemeratelny, ale realny (text 9 px ~24 px + padding 8 + ramik 2), takze
  # v rozpocte MUSI byt: pri vypisanej vyske stoji vedla „mm" aj chipu AUTO.
  badge = 34

  total = fixed['.frow .fnum'] + ftname_min + badge + dwrap + unit_auto +
          fixed['.frow select.fw'] + fixed['.frow .fprof'] + fixed['.frow .fdel'] + gaps
  NxTest.assert(total <= SMOKE1_FRONT_BUDGET,
                "riadok cela pri 470 px: #{total.round} px <= #{SMOKE1_FRONT_BUDGET} px")
end

# KOV-A2a: karta cela nesmie rozbit ani rad, ani predel medzi celami.
NxTest.test('SMOKE1 cela: karta cela je SAMOSTATNY riadok stlpca, nie polozka radu') do
  NxTest.assert(SMOKE1_FORM.include?("card.className = 'fcard'"), 'karta ma svoju triedu')
  NxTest.assert(SMOKE1_FORM.include?('row.appendChild(card); // karta je VZDY posledna v stlpci'),
                'karta patri do `.frow` (stlpec), NIE do `.fmain` (nezalamovaci rad)')
  # Riadok kovania sa pri otvorenej karte vklada NAD nu — inak by predel medzi
  # celami ostal nad kovanim a karta by visela pod nim.
  NxTest.assert(SMOKE1_FORM.include?('if (card) row.insertBefore(span, card);'),
                'kovanie ostava nad kartou')
  NxTest.assert(smoke1_decl('.nx-inspector .frow .fcard', 'border').to_s.include?('var(--nx-part-border)'),
                'karta pouziva TOKEN ramika (ziadny natvrdo zapisany hex)')
end

NxTest.test('SMOKE1 cela (Codex #183 P2): zivy nahlad vyrazu NEZABERA sirku radu') do
  # `= 450` pri rozpisanom vyraze `300+150` je v riadku cela OVERLAY. Ako flex
  # polozka (`flex: 0 0 auto`) by pridal ~34 px, na ktore rad pri `nowrap` uz
  # nema rezervu — riadok by pretiekol presne tak, ako predtym zalamoval.
  NxTest.assert_equal('absolute', smoke1_decl('.nx-inspector .frow .dwrap .exprhint', 'position'),
                      'hint je mimo toku radu')
  NxTest.assert_equal('none', smoke1_decl('.nx-inspector .frow .dwrap .exprhint', 'pointer-events'),
                      'overlay nesmie kradnut kliky poliam pod nim')
  # Pod `.miniopts` (120) — ked je otvoreny rozmerovy rad, hodnoty maju prednost.
  NxTest.assert(smoke1_decl('.nx-inspector .frow .dwrap .exprhint', 'z-index').to_i <
                smoke1_decl('.nx-inspector .miniopts', 'z-index').to_i,
                'hint nesmie prekryt otvorenu ponuku rozmeroveho radu')
end

NxTest.test('SMOKE1 cela: nazov typu je JEDINY rastuci prvok (vyuzije zvysok sirky)') do
  # KOV-A2a: rastucim prvkom bola rozbalovacka typu, teraz je nim tlacidlo
  # `.ftname` (ikona + nazov + pripadny badge „smer?"). Pravidlo je to iste:
  # PRAVE JEDEN prvok radu rastie, vsetky ostatne maju pevnu stopu.
  flex = smoke1_decl('.frow .ftname', 'flex').to_s
  NxTest.assert(flex.start_with?('1 1'), "`.ftname` rastie aj sa zmrsti (#{flex})")
  NxTest.assert_equal(nil, smoke1_decl('.frow select.ftype', 'flex'),
                      'rozbalovacka typu v riadku uz neexistuje')
  ['.frow .fnum', '.frow input.fh', '.frow select.fw',
   '.frow .fprof', '.frow .fdel', '.frow .fbadge'].each do |sel|
    NxTest.assert(smoke1_decl(sel, 'flex').to_s.start_with?('0 0'), "#{sel} nerastie ani sa nezmrsti")
  end
  # Nazov sa v uzkom rade musi OREZAT (nie tlacit susedov) — ellipsis + nowrap.
  NxTest.assert_equal('ellipsis', smoke1_decl('.frow .ftname .ftl', 'text-overflow'))
  NxTest.assert_equal('nowrap', smoke1_decl('.frow .ftname .ftl', 'white-space'))
end

NxTest.test('SMOKE1 cela: markup riadku obaluje ovladace do `.fmain`') do
  body = SMOKE1_FORM[/function addFrontRow.*?\n  \}\n/m].to_s
  NxTest.assert(body.include?("row.innerHTML = '<span class=\"fmain\">'"), 'rad zacina obalom')
  NxTest.assert(body.include?("'</span>';"), 'a je aj uzavrety')
  # Riadok kovania (UI-C3) patri k celu — pripaja sa na `.frow`, teda POD rad,
  # takze jemny predel medzi celami lezi az pod nim.
  NxTest.assert(SMOKE1_FORM.include?('row.appendChild(span)'), 'kovanie zije v `.frow`, nie v `.fmain`')
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
