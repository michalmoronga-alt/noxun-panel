# frozen_string_literal: true
# H6a (blok 9 HARDENING, D-01) - guardy nad HTML/CSS Inspectora po presune pomocnych
# textov do „?", spodnom bloku v jednom rade a stavovej vete len so spravou.
#   T1  v skupinach Struktura zon / Polozky / Sety / Pravidla nie je `.hint`;
#       v panel.html nie je `pvhint`, `zoneline`, `zonesChk`, „Pripravene.";
#       `#status` ma `hidden`; `.cabacts` ma prave dve tlacidla s povodnymi akciami;
#       kazdy `.nxtip` ma `aria-label` a `nxTipStop`; patica a `#verline` ostali;
#       CSS: `.cabacts` len v `mode-cab`, `#status[hidden]`, legenda `#basicCard`
#       skryta len v `mode-cab`, `#s3Help` len v `mode-cab`.
# Zrkadlo JS: tests/js/test_h6a_napovedy.js, inventar viet: test_h6a_texty.rb.
# MUTACIE (kazda overena rucne - po zanesi chyby do HTML/CSS spadne uvedeny test):
#   M1 spat `<div class="pvhint">`                       -> „bez pvhint"
#   M2 `#status` bez `hidden` v HTML                     -> „#status je skryty"
#   M4 `.cabacts` viditelne aj vo vkladani               -> „.cabacts len v mode-cab"
#   M6 `.hint` spat v Sety                               -> „skupiny bez .hint"
require_relative '../helper' unless defined?(NxTest)

H6AH_UI   = File.join(NxTest::ROOT, 'noxun_engine', 'ui')
H6AH_HTML = File.read(File.join(H6AH_UI, 'panel.html'), encoding: 'UTF-8')
H6AH_CSS  = File.read(File.join(H6AH_UI, 'css', 'panel.css'), encoding: 'UTF-8')

# Komentare HTML/CSS vysvetluju kontrakt (a tie retazce zamerne obsahuju) - kontroluje sa KOD.
H6AH_CODE_HTML = H6AH_HTML.gsub(/<!--.*?-->/m, ' ')
H6AH_CODE_CSS  = H6AH_CSS.gsub(%r{/\*.*?\*/}m, ' ')

def h6ah_group(key)
  H6AH_CODE_HTML[/<details data-key="#{key}".*?<\/details>/m].to_s
end

NxTest.test('H6a T1: skupiny Struktura zon / Polozky / Sety / Pravidla bez `.hint` ale s „?" v hlavicke') do
  { 'zones' => 'Štruktúra zón', 'hwitems' => 'Položky z pravidiel', 'hwsets' => 'Sety', 'hwrules' => 'Pravidlá' }.each do |key, title|
    g = h6ah_group(key)
    NxTest.refute(g.empty?, "skupina #{key} sa nasla")
    NxTest.assert_equal(0, g.scan(/class="hint/).length, "skupina #{title}: pomocny text je otaznik v hlavicke, nie hint")
    summary = g[/<summary.*?<\/summary>/m].to_s
    NxTest.assert(summary.include?('class="ghdr"'), "#{title}: hlavicka je `.ghdr`")
    NxTest.assert(summary =~ /\A<summary class="ghdr"><svg[^>]*><use [^>]*\/><\/svg>#{Regexp.escape(title)}<span class="gtools">/,
                  "#{title}: nazov ostava PRIAMYM textom <summary>")
    NxTest.assert(summary.include?('class="nxtip r"'), "#{title}: hlavicka nesie otaznik (nxtip)")
  end
end

NxTest.test('H6a T1: D15 - Polozky vo „?" bez ikony v texte, so slovom') do
  tip = h6ah_group('hwitems')[/data-tip="([^"]*)"/, 1].to_s
  NxTest.assert(tip.include?('zmena počtu je ručný zásah pre túto skrinku a tlačidlo so šípkou späť vráti pravidlo.'),
                'tooltip Poloziek: ikonu rotate-ccw nahradilo slovo')
  NxTest.refute(tip.include?('<'), 'data-tip je cisty text')
end

NxTest.test('H6a T1: panel.html bez pvhint, zoneline, zonesChk, „Pripravene."') do
  %w[pvhint zoneline zonesChk toggleZones ph-zones ph-fronts].each do |w|
    NxTest.refute(H6AH_CODE_HTML.include?(w), "panel.html nema #{w}")
  end
  NxTest.refute(H6AH_CODE_HTML.include?('Pripravené.'), 'panel.html nema „Pripravené."')
  NxTest.refute(H6AH_CODE_HTML.include?('Zobraziť obrysy zón v modeli'), 'a nema riadok obrysov zon')
  NxTest.refute(H6AH_CODE_CSS.include?('.pvhint'), 'CSS nema .pvhint')
  NxTest.refute(H6AH_CODE_CSS.include?('.zoneline'), 'CSS nema .zoneline')
end

NxTest.test('H6a T1: #status je skryty, kym nema spravu') do
  NxTest.assert(H6AH_CODE_HTML =~ /<div id="status" hidden><\/div>/, '#status je skryty a prazdny')
  NxTest.assert(H6AH_CODE_CSS.include?('.nx-inspector #status[hidden] { display: none; }'),
                'poistka voci pasci display vs [hidden] (D-137)')
end

NxTest.test('H6a T1: `.cabacts` - prave dve tlacidla s povodnymi akciami') do
  box = H6AH_CODE_HTML[/<div class="cabacts">.*?<\/div>/m].to_s
  NxTest.refute(box.empty?, '.cabacts sa nasiel')
  NxTest.assert_equal(2, box.scan(/<button/).length, 'prave dve tlacidla')
  NxTest.assert(box.include?('onclick="insertCopySelected()"'), 'kopia: povodna akcia')
  NxTest.assert(box.include?('onclick="openSaveTemplateModal()"'), 'sablona: povodna akcia')
  NxTest.assert(box =~ />\s*<svg[^>]*><use href="#i-copy"\/><\/svg> Vložiť kópiu<\/button>/, 'text „Vložiť kópiu" s ikonou copy')
  NxTest.assert(box =~ />\s*<svg[^>]*><use href="#i-star"\/><\/svg> Uložiť šablónu<\/button>/, 'text „Uložiť šablónu" s ikonou star')
  NxTest.assert(box.include?('title="Vloží presnú kópiu označenej skrinky'), 'title kopie bez zmeny')
  NxTest.assert(box.include?('title="Uloží označenú skrinku ako šablónu do knižnice"'), 'title sablony')
  NxTest.refute(H6AH_CODE_HTML.include?('Uložiť ako šablónu do knižnice</button>'), 'dlhy text tlacidla zanikol')
  NxTest.refute(H6AH_CODE_HTML.include?('insertmore'), 'stara trieda insertmore zanikla')
  NxTest.refute(H6AH_CODE_HTML.include?('savetpl'), 'stara trieda savetpl zanikla')
end

NxTest.test('H6a T1: `.cabacts` len v mode-cab, legenda Rozmery len pri skrinke, #s3Help len pri skrinke') do
  NxTest.assert(H6AH_CODE_CSS.include?('.nx-inspector .cabacts { display: none;'), '.cabacts je mimo skrinky skryte')
  NxTest.assert(H6AH_CODE_CSS.include?('.nx-inspector body.mode-cab .cabacts { display: flex; }'), 'a ukaze sa LEN v mode-cab')
  NxTest.assert(H6AH_CODE_CSS.include?('.nx-inspector .cabacts .ghostbtn { flex: 1 1 0;'), 'obe tlacidla rovnako siroke')
  NxTest.assert(H6AH_CODE_CSS.include?('.nx-inspector body.mode-cab #basicCard > legend { display: none; }'),
                'legenda „Rozmery" zmizne len pri oznacenej skrinke (vo vkladani ostava)')
  NxTest.assert(H6AH_CODE_CSS.include?('.nx-inspector body:not(.mode-cab) #s3Help { display: none; }'),
                '„?" materialov je len pri oznacenej skrinke')
  NxTest.assert(H6AH_CODE_HTML =~ %r{<fieldset id="basicCard">\s*<legend>Rozmery</legend>}, 'HTML legendy bez zmeny')
end

NxTest.test('H6a T1: kazdy `.nxtip` v panel.html ma aria-label, data-tip a nxTipStop') do
  tips = H6AH_CODE_HTML.scan(/<button[^>]*class="nxtip[^"]*"[^>]*>/m)
  NxTest.assert(tips.length >= 9, "nasiel som #{tips.length} tooltipov")
  tips.each do |t|
    NxTest.assert(t.include?('aria-label="'), "aria-label: #{t[0, 80]}")
    NxTest.assert(t.include?('data-tip="'), "data-tip: #{t[0, 80]}")
    NxTest.assert(t.include?('onclick="nxTipStop(event)"'), "nxTipStop (klik nezbali skupinu): #{t[0, 80]}")
  end
end

NxTest.test('H6a T1: „?" pod nahladom je v spodnom pase pred kamerou; „?" materialov v liste S3') do
  bar = H6AH_CODE_HTML[/<div class="pvbar">.*?<\/fieldset>/m].to_s
  NxTest.assert(bar.index('class="pvsp"') < bar.index('id="pvHelp"') && bar.index('id="pvHelp"') < bar.index('id="pvCam"'),
                '#pvHelp stoji za .pvsp a PRED #pvCam')
  NxTest.assert(H6AH_CODE_HTML =~ /<button type="button" id="pvHelp" class="nxtip r" aria-label="Pomoc k náhľadu"/, '#pvHelp: aria-label')
  s3 = H6AH_CODE_HTML[/<summary class="secthead"><span class="sn">Materiály<\/span>.*?<\/summary>/m].to_s
  NxTest.assert(s3.include?('id="s3Meta"') && s3.index('id="s3Meta"') < s3.index('id="s3Help"'),
                '#s3Help je SURODENEC za #s3Meta (nie dieta - elipsa by ho orezala)')
  NxTest.assert(s3.include?('data-tip="Materiály tejto skrinky — prázdne = dediť z projektu."'), 'text „?" materialov')
end

NxTest.test('H6a T1: stavova veta materialov ostava ako `.hint` (iba skryta s vyberom)') do
  NxTest.assert(H6AH_CODE_HTML =~ %r{<div class="hint" id="cabMatHint">Označ skrinku pre nastavenie jej materiálov\.</div>},
                'bez vyberu viditelna stavova veta')
end

NxTest.test('H6a T1: patica s verziou ostala (O3 B)') do
  NxTest.assert(H6AH_CODE_HTML.include?('<footer class="nxfoot">Noxun Engine <span id="verline">…</span></footer>'), 'footer + #verline')
  NxTest.assert(H6AH_CODE_CSS.include?('.nxfoot {'), 'CSS patice')
end
