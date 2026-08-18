# frozen_string_literal: true
# UI-C1b — VKLADACIA KARTA: guardy nad ZDROJOM (panel.html / panel.css / js /
# payloads.rb). Spravanie testuje JS sada (tests/js/test_uic1b_vkladanie.js);
# tu sa strazia invarianty, ktore sa daju stratit tichou upravou markupu:
#   1) typ = TRI segmentove tlacidla; po radiach nesmie ostat stopa,
#   2) sablona = zrolovatelna sekcia s DLAZDICAMI (ziadny <select id="template">),
#   3) klik/dvojklik idu cez JEDNU delegaciu a TU ISTU validovanu insert cestu
#      (ziadny onclick per dlazdica, ziadne priame volanie bridgu),
#   4) doskove zamky (D-39) su LEN v UI — do Ruby whitelistu nepatria,
#   5) vkladana doska MA nahlad (N10) a ikony typu su v sprite,
#   6) kontrakt HRUBKY doskovej sablony ma v kode obe strany (templates.rb
#      hovori „implementuje C1b", board_card.js to naozaj robi cez UNI).
require_relative '../helper' unless defined?(NxTest)

UIC1B_UI    = File.join(NxTest::ROOT, 'noxun_engine', 'ui')
UIC1B_HTML  = File.read(File.join(UIC1B_UI, 'panel.html'), encoding: 'UTF-8')
UIC1B_CSS   = File.read(File.join(UIC1B_UI, 'css', 'panel.css'), encoding: 'UTF-8')
UIC1B_FORM  = File.read(File.join(UIC1B_UI, 'js', 'form.js'), encoding: 'UTF-8')
UIC1B_BOARD = File.read(File.join(UIC1B_UI, 'js', 'board_card.js'), encoding: 'UTF-8')
UIC1B_INS   = File.read(File.join(UIC1B_UI, 'js', 'insert_state.js'), encoding: 'UTF-8')
UIC1B_ICONS = File.read(File.join(UIC1B_UI, 'js', 'icons.js'), encoding: 'UTF-8')
UIC1B_PAY   = File.read(File.join(UIC1B_UI, 'panel', 'payloads.rb'), encoding: 'UTF-8')
UIC1B_ACAB  = File.read(File.join(UIC1B_UI, 'panel', 'actions_cabinet.rb'), encoding: 'UTF-8')
UIC1B_TPL   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'templates.rb'), encoding: 'UTF-8')

# Guardy sa tykaju KODU, nie komentarov (v komentaroch tieto retazce zamerne su).
def uic1b_code(src, style)
  out = src.dup
  out = out.gsub(/<!--.*?-->/m, ' ') if style == :html
  out = out.gsub(%r{/\*.*?\*/}m, ' ') if style == :css
  if style == :js
    out = out.gsub(%r{/\*.*?\*/}m, ' ')
    out = out.lines.map { |l| l.sub(%r{//.*$}, '') }.join
  end
  out
end
UIC1B_HTML_CODE = uic1b_code(UIC1B_HTML, :html)
UIC1B_FORM_CODE = uic1b_code(UIC1B_FORM, :js)

# --- 1) typ = tri segmentove tlacidla ----------------------------------------

NxTest.test('UI-C1b: typ vkladania su TRI segmentove tlacidla so statickym id') do
  { 'insTypeLower' => 'lower', 'insTypeUpper' => 'upper', 'insTypeBoard' => 'board' }.each do |id, type|
    tag = UIC1B_HTML_CODE[/<button [^>]*id="#{id}"[^>]*>/].to_s
    NxTest.refute(tag.empty?, "chyba tlacidlo typu #{type} (id=#{id})")
    NxTest.assert(tag.include?(%(data-ins-type="#{type}")), "#{id} nenesie data-ins-type=\"#{type}\"")
    NxTest.assert(tag.include?("onInsertType('#{type}')"), "#{id} nevola guard onInsertType")
    NxTest.assert(tag.include?('aria-pressed='), "#{id}: stav prepinaca musi citat aj citacka")
  end
  # D-25 invariant: id su STATICKE identifikatory (merac ich berie ako kluc).
  NxTest.assert(UIC1B_HTML.include?('id="insertTypeRow"'), 'rad tlacidiel nema staticke id')
end

NxTest.test('UI-C1b: po radiach typu nesmie ostat stopa') do
  ['name="ctype"', 'name="ikind"', 'onTypeChange(', 'onInsertKindChange()"'].each do |dead|
    NxTest.refute(UIC1B_HTML_CODE.include?(dead), "panel.html stale obsahuje '#{dead}'")
  end
  NxTest.refute(UIC1B_CSS.include?('.typerow'), 'panel.css stale nesie pravidlo pre zrusene .typerow')
  # Autorita typu je CISTY STAV (NXInsert), nie DOM — inak by ho prekreslenie
  # kostry alebo prepis body.className vedelo stratit.
  NxTest.refute(uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'core.js'), encoding: 'UTF-8'), :js)
                  .include?("querySelector('input[name=ctype]"),
                'getType uz nesmie citat radia — typ zije v premennej/NXInsert')
  NxTest.assert(UIC1B_INS.include?('function setInsertType('),
                'prepinanie typu je cista funkcia insert_state.js (testovana v Node)')
end

# --- 2) sablona = zrolovatelne dlazdice --------------------------------------

NxTest.test('UI-C1b: sektor Sablona je zrolovatelny a nesie mriezku dlazdic') do
  sect = UIC1B_HTML_CODE[/<details class="insect"[^>]*>/].to_s
  NxTest.refute(sect.empty?, 'sektor Sablona musi byt <details> (vertikalny priestor je vzacny)')
  NxTest.assert(sect.include?('data-key="itpl"'),
                'bez data-key by si bindDetails zbalenie nezapamatal')
  NxTest.assert(UIC1B_HTML.include?('id="tplTiles"'), 'chyba kontajner mriezky dlazdic')
  NxTest.assert(UIC1B_HTML.include?('id="insTplMeta"'), 'lista sektora Sablona nema miesto na meta')
  # Stary quick-pick select zanikol — dlazdice su jedina cesta k sablone.
  NxTest.refute(UIC1B_HTML_CODE.include?('<select id="template"'),
                'select sablony nahradili dlazdice')
  NxTest.assert(UIC1B_HTML.include?('id="insTplMng"'),
                'vstup do okna Sablony musi ostat (jediny z panela)')
end

NxTest.test('UI-C1b: mriezka sa prestavuje LEN pri zmene typu / novej kniznici') do
  # Codex FIX 14 + pasca CEF: keby vyber sablony prekreslil mriezku, druhy klik
  # dvojkliku by uz nemal na com dopadnut.
  fn = UIC1B_FORM_CODE[/function renderTemplateTiles\(force\).+?\n  \}/m].to_s
  NxTest.refute(fn.empty?, 'renderTemplateTiles sa nenasla')
  NxTest.assert(fn.include?("if (!force && box.dataset.forType === type){ syncTemplateTiles(); return; }"),
                'bez tejto poistky by kazdy vyber sablony prestaval mriezku')
  NxTest.assert(UIC1B_FORM_CODE.include?('function syncTemplateTiles('),
                'vyber sa musi dat prepnut samotnou triedou .on')
end

# --- 3) delegacia + jedna insert cesta ---------------------------------------

NxTest.test('UI-C1b: mriezka ponuka aj CESTU SPAT na predvolby (Codex #175 P2)') do
  # Klik na uz vybranu dlazdicu je no-op (dvojklik posiela dva kliky), takze bez
  # dlazdice „Bez šablóny" by sa vyber nedal zrusit — najma pri doske, ktora si
  # ho drzi aj cez prepnutie typu. Je to nahrada za volbu „— vyber —" v selecte.
  NxTest.assert(UIC1B_FORM_CODE.include?('function tplClearTileHtml('),
                'chyba dlazdica „Bez šablóny"')
  render = UIC1B_FORM_CODE[/function renderTemplateTiles\(force\).+?\n  \}/m].to_s
  NxTest.assert(render.include?('tplClearTileHtml(sel)'),
                'dlazdica „Bez šablóny" musi byt v mriezke, nie len v kode')
  NxTest.assert(UIC1B_FORM_CODE.include?("data-tpl-clear=\"1\""),
                'dlazdica sa musi dat rozoznat od sablony rovnakeho mena')
  name_fn = UIC1B_FORM_CODE[/function tplTileName\(node\).+?\n  \}/m].to_s
  NxTest.assert(name_fn.include?("hasAttribute('data-tpl-clear')"),
                'delegacia musi z clear dlazdice vratit prazdne meno')
  pick = UIC1B_FORM_CODE[/function pickTemplateTile\(name\).+?\n  \}/m].to_s
  NxTest.refute(pick.include?('if (!name'),
                'prazdne meno uz NIE JE no-op — je to navrat na predvolby typu')
end

NxTest.test('UI-C1b: odhad navrhu sa obnovi aj po zmene ZON (Codex #175 P2)') do
  # Zonove operacie navrhu maju vlastnu cestu (renderPreview + refreshZoneUI) —
  # bez tohto hooku ostal „≈ Dielcov / ≈ Materiál" zatuchnuty.
  NxTest.assert(UIC1B_FORM_CODE.include?('function nxDraftChanged('),
                'chyba obnovovaci bod odhadu mimo updateAvailable')
  actions = uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'actions.js'), encoding: 'UTF-8'), :js)
  NxTest.assert(actions.scan('nxDraftChanged()').length >= 5,
                'delenie, police, vycistenie aj rozmery poli musia odhad obnovit')
  pvjs = uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'preview.js'), encoding: 'UTF-8'), :js)
  NxTest.assert(pvjs[/function endDivDrag\(ev\).+?\n  \}/m].to_s.include?('nxDraftChanged'),
                'tah priecky v navrhu meni plochy polic — odhad ide s nimi')
end

NxTest.test('UI-C1b: scena vkladania obsiahne PRESAHY draft ciel (Codex #175 P2)') do
  pvjs = uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'preview.js'), encoding: 'UTF-8'), :js)
  NxTest.assert(pvjs.include?('function nxFrontsExtent('),
                'rozsah draft ciel je cista funkcia (Node testy)')
  scene = pvjs[/function sceneSize\(\).+?\n  \}/m].to_s
  NxTest.assert(scene.include?('insertFrontsExtent()'),
                'scena vkladania musi ratat s celami mimo obrysu (D-22 odomknute presahy)')
end

NxTest.test('UI-C1b: zony sa vo vkladani nekreslia dvakrat (Codex #175 P2)') do
  # Zhasnute cela odkryvaju vnutro — zony sa vtedy kreslia ako podklad. Ked ich
  # uz prisvietil CHIP, kresli ich ghost vrstva; obe naraz = dvojity tah.
  pvjs = uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'preview.js'), encoding: 'UTF-8'), :js)
  NxTest.assert(pvjs.include?("} else if (NXLayers.stateOf('insert', 'zony', pvAvail()) !== 'on'){"),
                'podklad zon sa musi preskocit, ked je chip Zóny zapnuty (vzor drawHwBase)')
end

NxTest.test('UI-C1b: klik aj dvojklik idu cez JEDNU delegaciu na kontajneri') do
  tile = UIC1B_FORM_CODE[/function tplTileHtml\(tp, sel\).+?\n  \}/m].to_s
  NxTest.refute(tile.empty?, 'tplTileHtml sa nenasla')
  NxTest.refute(tile.include?('onclick'), 'dlazdica NESMIE mat vlastny onclick (delegacia)')
  NxTest.refute(tile.include?('ondblclick'), 'dvojklik tiez patri delegacii')
  setup = UIC1B_FORM_CODE[/function setupTemplateTiles\(\).+?\n  \}/m].to_s
  NxTest.assert(setup.include?("box.addEventListener('click'"), 'chyba delegovany klik')
  NxTest.assert(setup.include?("box.addEventListener('dblclick'"), 'chyba delegovany dvojklik (N17)')
  # N17: dvojklik vklada TOU ISTOU validovanou cestou ako zelene tlacidlo —
  # ziadny priamy `sketchup.*` call z handlera dlazdice.
  NxTest.assert(setup.include?('insertBoard()') && setup.include?('insertCabinet()'),
                'dvojklik musi volat tie iste insert funkcie ako zelene tlacidlo')
  NxTest.refute(setup.include?('sketchup.'), 'z dlazdice sa NIKDY nevola bridge priamo')
end

NxTest.test('UI-C1b: zelene „Vložiť" je POSLEDNE a obe cesty nesu identitu sablony') do
  NxTest.assert(UIC1B_HTML.include?('id="insertGoRow"'), 'chyba rad s primarnou akciou')
  # Poradie v HTML: karta (typ/sablona/rozmery) -> materialy -> Vlozit.
  NxTest.assert(UIC1B_HTML.index('id="insertGoRow"') > UIC1B_HTML.index('id="insertBoardMatForm"'),
                'primarna akcia musi stat AZ ZA volbou materialu')
  actions = uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'actions.js'), encoding: 'UTF-8'), :js)
  NxTest.assert(actions.include?('p.template_kind = ref.kind'),
                'vklad korpusu nesie identitu sablony (UI-C1a peciatka)')
  NxTest.assert(UIC1B_BOARD.include?('res.payload.template_kind = ref.kind'),
                'vklad dosky nesie identitu sablony (bez nej sa poradie „naposledy použité" nezmeni)')
end

# --- 4) doskove zamky su LEN v UI --------------------------------------------

NxTest.test('UI-C1b: doskove zamky maju vlastne kluce a do Ruby NEIDU') do
  NxTest.assert(UIC1B_INS.include?("BOARD_LOCK_FIELDS = ['length', 'width']"),
                'doska ma vlastny whitelist zamkov (ziadne mapovanie na korpus — FIX 12)')
  %w[ib_length ib_width].each do |id|
    row = UIC1B_HTML_CODE[/<div class="rowc">(?:(?!<\/div>).)*#{id}.*?<\/div>/m].to_s
    NxTest.assert(row.include?('data-lock-scope="board"'),
                  "#{id}: zamok musi byt oznaceny doskovym rozsahom")
  end
  push = UIC1B_FORM_CODE[/function toggleInsertLock\(field, scope\).+?\n  \}/m].to_s
  NxTest.assert(push.include?("if (scope !== 'board') pushInsertLocksNow();"),
                'doskovy zamok sa do Ruby neposiela (server ho nepozna)')
  # Serverovy whitelist ostava KORPUSOVY — poistka proti „doplneniu" length/width.
  fields = UIC1B_ACAB[/INSERT_LOCK_FIELDS = %w\[([^\]]+)\]/, 1].to_s.split
  NxTest.assert_equal(%w[width height depth thickness floor_height], fields,
                      'Ruby whitelist zamkov je korpusovy a taky ma ostat')
end

# --- 5) nahlad vkladania + ikony ---------------------------------------------

NxTest.test('UI-C1b: vkladana doska MA nahlad (N10)') do
  # Do UI-C1b bol sektor S1 pri vkladani dosky zakryty — teraz kresli obdlznik
  # so sipkami smeru dekoru, takze skryvacie pravidla musia byt prec.
  NxTest.refute(UIC1B_CSS.include?('body[data-insert-kind="board"].mode-insert #secPreview'),
                'sektor Nahlad sa uz pri vkladani dosky neskryva')
  NxTest.refute(UIC1B_CSS.include?('body[data-insert-kind="board"].mode-insert .pvbox'),
                'plocha nahladu sa uz pri vkladani dosky neskryva')
  pvjs = uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'preview.js'), encoding: 'UTF-8'), :js)
  NxTest.assert(pvjs.include?('function renderInsertBoardPreview('), 'chyba projekcia vkladanej dosky')
  NxTest.assert(pvjs.include?('function nxFrontsResolve('),
                'vkladanie korpusu potrebuje DRAFT ciel (frontItems je tu null — FIX 11)')
  bridge = uic1b_code(File.read(File.join(UIC1B_UI, 'js', 'bridge.js'), encoding: 'UTF-8'), :js)
  NxTest.assert(bridge.include?("previewMode = 'insert';"),
                'vkladanie ma VLASTNU projekciu, nie korpusovy pohlad')
end

NxTest.test('UI-C1b: ikony typu su v sprite a panel ich pouziva') do
  %w[cab-low cab-high slab].each do |icon|
    NxTest.assert(UIC1B_ICONS.include?("'#{icon}':"), "sprite nema ikonu '#{icon}'")
    NxTest.assert(UIC1B_HTML.include?("#i-#{icon}"), "panel ikonu '#{icon}' nepouziva")
  end
  # Ziadne emoji ani ovladacie glyfy v UI chrome (UI_DIZAJN) — dlazdice aj
  # tlacidla kreslia SVG zo spritu. (Matematicke „≈" pri ODHADE glyf ovladania
  # nie je — je to hodnota, nie ovladaci prvok.)
  NxTest.refute(UIC1B_FORM_CODE =~ /[\u{1F300}-\u{1FAFF}🔒✕↺⚙📋★⧉⛶⚠🔗]/,
                'vkladacia karta nesmie pouzivat emoji/glyfy (UI_DIZAJN)')
end

NxTest.test('UI-C1b: dlazdice a segmentove tlacidla su scopnute pod .nx-inspector') do
  %w[.segrow .tpltiles .tpltile .insect .tplsec .tplfoot].each do |sel|
    UIC1B_CSS.lines.each_with_index do |line, i|
      next unless line.include?(sel) && line.include?('{')

      NxTest.assert(line.include?('.nx-inspector'),
                    "panel.css:#{i + 1} — pravidlo pre '#{sel}' nie je scopnute (css zdielaju satelity)")
    end
  end
end

# --- 6) kontrakt hrubky doskovej sablony -------------------------------------

NxTest.test('UI-C1b: kontrakt hrubky doskovej sablony ma obe strany') do
  # Datova strana (C1a) slubuje: material_id nil => vklad cez UNI, aby hrubka
  # sablony platila. Tu sa overuje, ze klient ten slub naozaj plni.
  NxTest.assert(UIC1B_TPL.include?('implementuje C1b'),
                'templates.rb: kontrakt doskovej sablony musi ostat zapisany')
  NxTest.assert(UIC1B_BOARD.include?('function uniBoardSheetId('),
                'karta musi vediet najst UNI material (inak by hrubku sablony zahodil katalog)')
  fn = UIC1B_BOARD[/function applyBoardTemplate\(cfg\).+?\n  \}/m].to_s
  NxTest.refute(fn.empty?, 'applyBoardTemplate sa nenasla')
  NxTest.assert(fn.index('onInsertBoardMaterial()') < fn.index('th.value = fmtdim(cfg.thickness)'),
                'PORADIE JE KONTRAKT: material najprv, hrubka sablony az po nom (inak ju prepise katalog)')
  NxTest.refute(fn.include?('sketchup.'), 'aplikacia sablony je NAVRH karty — nic sa nezapisuje')
  # Ziadna nova autorita hrubky: server ostava jediny, kto o nej rozhoduje.
  builder = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'board_builder.rb'), encoding: 'UTF-8')
  NxTest.assert(builder.include?('def insert_thickness_for'),
                'autorita hrubky ostava BoardBuilder.insert_thickness_for')
end

NxTest.test('UI-C1b: payload materialov nesie uni_role (vyber UNI roly Doska)') do
  blok = UIC1B_PAY[/def materials_payload.+?\n        end/m].to_s
  NxTest.assert(blok.include?("base['uni_role'] = s['uni_role']"),
                'bez uni_role by karta dosadila ktorykolvek UNI zaznam (napr. Korpus UNI)')
  NxTest.assert(blok.include?('unless s[\'uni_role\'].to_s.empty?'),
                'prazdny kluc sa neposiela (zrkadlo katalogovej semantiky)')
end
