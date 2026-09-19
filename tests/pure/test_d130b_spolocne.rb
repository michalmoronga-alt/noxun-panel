# frozen_string_literal: true
# D-130b — SKUPINA „SPOLOČNÉ PRE SKRINKU": MATERIAL CIEL + SCHEMA MEDZIER.
#
# Michalovo hlasenie, ktore davka dokoncuje (D-130, cast b):
#   „medzery a okraje su styri popisane riadky — musim citat popisky, aby som
#    vedel, ktora hrana je ktora; a material ciel visi na konci zoznamu."
#   Riesenie: JEDNA skupina `cabfront` pod zoznamom ciel, v nej material ciel
#   a SCHEMA — obrys korpusu s dvoma celami, kde kazde z PIATICH EXISTUJUCICH
#   poli `fr_gap*` lezi na hrane, ktorej sa tyka. Data sa NEMENIA.
#
# PRECO GUARD TEST A NIE KLIKANIE:
#   1) KOSTRA: poradie skupin kontextu je kontrakt (`test_uic3_cela.rb`); tu
#      strazime, ze `fgaps` sa uz nevrati a ze material stoji PRED schemou
#      (prvy riadok skupiny — tak to schvalil mockup).
#   2) ID POLI su zmluva s validaciou (`boot.js` LIMITS), vyrazmi
#      (`attachExprField`), echo-guardom `keepGaps` aj so serverom. Schema
#      presunula polia v DOM — keby pri tom niektore ID zaniklo alebo sa
#      zdvojilo, prestala by fungovat cela cesta „pole -> config".
#   3) SPECIFICITA CSS: `.row input` nastavuje `flex: 1`. Bez selektora
#      `.row .gapdiag input.gd` by sa polia roztiahli cez cely riadok a
#      schema by sa rozpadla — v testoch to nevidno, v paneli hned.
#   4) IKONY V HLAVICKE musia byt v `<summary>` (inak nie su vidno pri
#      zbalenej skupine) a MUSIA zastavit propagaciu (inak skupinu zbalia).
#   5) TOOLTIP nesie STOLARSKE vysvetlenie znamienok (+ / 0 / −) — je to
#      jediny text, ktory pouzivatelovi povie, ze zaporny okraj je PRESAH.
require_relative '../helper' unless defined?(NxTest)

D130B_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
D130B_FORM = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')
D130B_CORE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'core.js'), encoding: 'UTF-8')
D130B_PV   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'preview.js'), encoding: 'UTF-8')
# Komentare von PRED parsovanim CSS (su plne mien tried z minulosti).
D130B_CSS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
                .gsub(%r{/\*.*?\*/}m, ' ')

D130B_GAP_IDS = %w[fr_gap fr_gap_top fr_gap_bottom fr_gap_left fr_gap_right].freeze

# Telo skupiny `cabfront` v panel.html (od jej `<details>` po zaciatok dalsej).
def d130b_group
  D130B_HTML[/<details data-key="cabfront" data-s4="cela">.*?(?=<details data-key=)/m].to_s
end

def d130b_summary
  d130b_group[%r{<summary[^>]*>.*?</summary>}m].to_s
end

# --- 1) KOSTRA ---------------------------------------------------------------

NxTest.test('D-130b R1: skupina `fgaps` zanikla, kontext ma `cabfront`') do
  NxTest.refute(D130B_HTML.include?('data-key="fgaps"'),
                'skupina „Medzery a presahy" ZANIKLA (zlucila sa do „Spoločné pre skrinku")')
  NxTest.refute(d130b_group.empty?, 'skupina `cabfront` v panel.html existuje')
  NxTest.assert(d130b_group.include?('Spoločné pre skrinku'), 'a vola sa „Spoločné pre skrinku"')
  # `fgaps` nesmie prezit ani v JS, ktore sa nan viazalo (N26 stav).
  NxTest.refute(D130B_PV.include?('fgaps'), 'preview.js sa uz na zaniknutu skupinu neodvolava')
end

NxTest.test('D-130b R1: material ciel je PRVY riadok skupiny, pred schemou') do
  g = d130b_group
  NxTest.assert(g.include?('id="cab_front_c"'), 'druhy ovladac materialu ciel sa prestahoval sem')
  NxTest.assert_equal(1, D130B_HTML.scan('id="cab_front_c"').length, 'a je v paneli PRAVE RAZ')
  NxTest.assert(g.index('id="cab_front_c"') < g.index('class="gapdiag"'),
                'material stoji PRED schemou medzier (poradie z mockupu)')
  # `.matrow` ma vlastnu sirku popisku (118) — v tejto skupine by rozhodil
  # jednotny stlpec popisov, preto je riadok `.row` (R1).
  NxTest.refute(g.include?('class="matrow"'), 'riadok je `.row`, nie `.matrow` (jeden stlpec popisov)')
end

# --- 2) SCHEMA: pat existujucich poli na hranach ------------------------------

NxTest.test('D-130b R2: pat poli `fr_gap*` existuje prave raz a je v scheme') do
  diag = d130b_group[/<div class="gapdiag">.*?<\/div>\s*<span class="unit">mm<\/span>/m].to_s
  NxTest.refute(diag.empty?, 'kontajner `.gapdiag` v skupine existuje')
  D130B_GAP_IDS.each do |id|
    NxTest.assert_equal(1, D130B_HTML.scan(%(id="#{id}")).length, "#{id} je v paneli prave raz")
    NxTest.assert(diag.include?(%(id="#{id}")), "#{id} lezi v scheme")
    NxTest.assert(diag[/id="#{id}"[^>]*/].include?('oninput="onField()"'),
                  "#{id} si nechava povodnu zapisovu cestu (onField)")
    NxTest.assert(diag[/id="#{id}"[^>]*/].include?('title="'), "#{id} pomenuje svoju hranu v `title`")
  end
  # Medzera medzi celami je JANTAROVA (`.mid`) — ta ista farba ako N26 pasy.
  NxTest.assert(diag.include?('id="fr_gap" class="gd mid"'), 'medzera medzi celami je stredne pole')
  # Kresba je ILUSTRACIA, nie ovladac — citacka ju preskoci.
  NxTest.assert(diag.include?('class="gd-box" aria-hidden="true"'), 'obrys korpusu je dekoracia')
end

NxTest.test('D-130b R2: mriezka `.front-gap-grid` zanikla, schema ma vlastnu specificitu') do
  NxTest.refute(D130B_CSS.include?('.front-gap-grid'), 'stara mriezka styroch riadkov uz v CSS nie je')
  # `.row input { flex: 1 }` (0,0,2,1) musi prehrat s pravidlom schemy.
  NxTest.assert(D130B_CSS.include?('.nx-inspector .row .gapdiag input.gd'),
                'polia schemy su adresovane cez `.row .gapdiag input.gd` (inak by sa roztiahli)')
  NxTest.assert(D130B_CSS.include?('.nx-inspector .gd-box'), 'obrys korpusu ma vlastne pravidlo')
  %w[top bottom left right mid].each do |pos|
    NxTest.assert(D130B_CSS.include?(".nx-inspector .row .gapdiag input.gd.#{pos}"),
                  "poloha `#{pos}` je v CSS (cislo sedi na svojej hrane)")
  end
end

# --- 3) HLAVICKA: meta, zamok, reset, tooltip --------------------------------

NxTest.test('D-130b R3: zamok, reset, meta aj tooltip su v `<summary>`') do
  s = d130b_summary
  NxTest.refute(s.empty?, 'hlavicka skupiny sa nasla')
  NxTest.assert(s.include?('id="cabfrontMeta"'), 'meta („dub Halifax · 3 · 2/2/0/0")')
  NxTest.assert(s.include?('id="edgeLimitLock"'), 'zamok limitu presahov je IKONA v hlavicke')
  NxTest.assert(s.include?('id="frontGapsReset"'), 'reset predvolenych medzier je IKONA v hlavicke')
  NxTest.assert(s.include?('class="nxtip r"'), 'tooltip `?` zarovnany vpravo')
  # Klik v <summary> zbaluje skupinu — kazde tlacidlo musi propagaciu zastavit.
  NxTest.assert(s.include?('onclick="toggleEdgeLimit(event)"'), 'zamok dostava udalost (stop-guard)')
  NxTest.assert(s.include?('onclick="resetFrontGaps(event)"'), 'reset dostava udalost (stop-guard)')
  NxTest.assert(s.include?('onclick="nxTipStop(event)"'), 'tooltip nezbali skupinu')
  NxTest.assert(D130B_FORM[/function toggleEdgeLimit\(ev\).*?\n  \}/m].include?('nxTipStop(ev)'),
                '`toggleEdgeLimit` naozaj zastavi propagaciu')
  NxTest.assert(D130B_FORM[/function resetFrontGaps\(ev\)[^\n]*/].include?('nxTipStop(ev)'),
                '`resetFrontGaps` naozaj zastavi propagaciu')
end

NxTest.test('D-130b R3: zamok nesie stav ikonou a farbou, nie textom `.lblLimit`') do
  NxTest.refute(D130B_HTML.include?('lblLimit'), 'textovy label zamku zanikol')
  NxTest.refute(D130B_CSS.include?('.row .lockbtn'), 'a s nim aj jeho CSS pravidlo v riadku')
  set = D130B_FORM[/function setEdgeLimitOff\(off\).*?\n  \}/m].to_s
  NxTest.assert(set.include?("'lock-open' : 'lock'"), 'symbol sa prepina medzi zamknutym a odomknutym')
  NxTest.assert(set.include?("classList.toggle('amber'"), 'odomknuty limit je JANTAROVY (vidno aj zbaleny)')
  NxTest.assert(set.include?('aria-pressed'), 'stav je citatelny aj pre citacku')
  NxTest.assert(D130B_CSS.include?('.nx-inspector .gtools .ibtn.amber'), 'jantarovy stav ikony je v CSS')
end

NxTest.test('D-130b R6: predvolene medzery ostavaju 3 / 2 / 2 / 2 / 2') do
  reset = D130B_FORM[/function resetFrontGaps\(ev\)[^\n]*/].to_s
  NxTest.assert(reset.include?("setNum('fr_gap', 3)"), 'medzera medzi celami 3 mm')
  %w[fr_gap_top fr_gap_bottom fr_gap_left fr_gap_right].each do |id|
    NxTest.assert(reset.include?("setNum('#{id}', 2)"), "okraj #{id} 2 mm")
  end
end

# --- 4) TOOLTIP: stolarske znenie znamienok ----------------------------------

NxTest.test('D-130b R4: tooltip schemy vysvetli + / 0 / − stolarsky') do
  tip = d130b_group[/<button type="button" class="nxtip inl".*?<\/button>/m].to_s
  NxTest.refute(tip.empty?, 'schema ma vlastny tooltip pri popisku')
  ['odskok', 'zarovno', 'presah', 'škára'].each do |word|
    NxTest.assert(tip.include?(word), "tooltip hovori o znamienku/pojme #{word}")
  end
  # Pomocny text uz NIE JE `.hint` (pravidlo D-130a R8) — skupina ziadny nema.
  NxTest.refute(d130b_group.include?('class="hint"'), 'dlhy pomocny text nahradil tooltip')
end

# --- 5) META je CISTA funkcia v core.js --------------------------------------

NxTest.test('D-130b R3: text meta hlavicky sklada cista funkcia v core.js') do
  NxTest.assert(D130B_CORE.include?('function cabfrontMetaText('), 'meta ma cistu funkciu')
  NxTest.assert(D130B_CORE.include?('cabfrontMetaText: cabfrontMetaText'), 'a je exportovana pre JS sadu')
  NxTest.assert(D130B_FORM.include?('function updateCabfrontMeta()'), 'panel ju len kresli')
  # Bez prekreslenia pri editacii by meta klamala pri zbalenej skupine.
  NxTest.assert(D130B_FORM.scan('updateCabfrontMeta()').length >= 4,
                'meta sa obnovuje pri renderi ciel aj pri kazdej zmene pola')
end
