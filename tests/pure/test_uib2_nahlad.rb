# frozen_string_literal: true
# UI-B2 — nahlad ako kontextova projekcia + spodny pas: guardy nad ZDROJOM
# (panel.html / panel.css / panel.rb / selection.rb / preview.js).
# Kontrolovane invarianty:
#   1) spodny pas existuje a je STATICKA kostra (chipy kresli JS do #pvChips,
#      nastroje maju staticke ID) — rohovy fit overlay uz v paneli nie je,
#   2) kamera N7 je CISTE CITANIE: callback je registrovany, ale v jeho ceste
#      nesmie byt operacia ani zapis do modelu (lekcia D-103),
#   3) kamera nesie IDENTITU (dokument + skrinka) — callback HtmlDialogu je
#      asynchronny a ID skriniek sa naprie dokumentmi opakuju,
#   4) nahlad kresli LEN z existujucich payloadov — preview.js si nepyta
#      ziadny vlastny serverovy callback na data,
#   5) chipy vrstiev maju kluce meraca z allowlistu (drzi ho sada UI-B1).
require_relative '../helper' unless defined?(NxTest)

UIB2_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
UIB2_CSS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
UIB2_PANEL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
UIB2_SEL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'selection.rb'), encoding: 'UTF-8')
UIB2_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'preview.js'), encoding: 'UTF-8')
UIB2_ICONS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')

# Guardy sa tykaju KODU, nie komentarov (v komentaroch tieto retazce zamerne su).
def uib2_no_comments(src, style)
  out = src.dup
  out = out.gsub(/<!--.*?-->/m, ' ') if style == :html
  case style
  when :js
    out = out.gsub(%r{/\*.*?\*/}m, ' ')
    out = out.lines.map { |l| l.sub(%r{//[^\n]*}, '') }.join
  when :rb
    out = out.lines.reject { |l| l.strip.start_with?('#') }.join
  end
  out
end
UIB2_HTML_CODE = uib2_no_comments(UIB2_HTML, :html)
UIB2_JS_CODE = uib2_no_comments(UIB2_JS, :js)
UIB2_SEL_CODE = uib2_no_comments(UIB2_SEL_RB, :rb)

# --- 1) spodny pas -----------------------------------------------------------

NxTest.test('UI-B2: nahlad ma spodny pas so statickymi ID (chipy + kamera + fit)') do
  NxTest.assert(UIB2_HTML_CODE.include?('class="pvbar"'), 'chyba spodny pas nahladu (.pvbar)')
  %w[pvChips pvCam pvFit].each do |id|
    NxTest.assert(UIB2_HTML_CODE.include?("id=\"#{id}\""), "pasu chyba prvok s id=\"#{id}\"")
  end
end

NxTest.test('UI-B2: fit sa presunul do pasu — rohovy overlay uz neexistuje') do
  NxTest.refute(UIB2_HTML_CODE.include?('pvfitwrap'), 'v paneli ostal stary fit overlay')
  NxTest.refute(uib2_no_comments(UIB2_CSS, :css).include?('.pvfitwrap'),
                'v CSS ostali pravidla zruseneho fit overlayu')
  NxTest.assert(UIB2_HTML_CODE.include?('onclick="fitPreview()"'),
                'fit musi ostat na tej istej funkcii (ziadny duplikat logiky)')
end

NxTest.test('UI-B2: chipy vrstiev kresli JS do prazdneho #pvChips (kostra ostava staticka)') do
  NxTest.assert(UIB2_HTML_CODE.include?('<div class="pvchips" id="pvChips"></div>'),
                'kontajner chipov musi byt v HTML prazdny — obsah plni renderPvBar')
  NxTest.assert(UIB2_JS_CODE.include?("el('pvChips')"), 'renderPvBar musi plnit #pvChips')
end

NxTest.test('UI-B2: kamera ma vlastnu ikonu v sprite (ziadne emoji v UI chrome)') do
  NxTest.assert(UIB2_ICONS.include?("'camera':"), 'sprite icons.js nema symbol camera')
  NxTest.assert(UIB2_HTML_CODE.include?('#i-camera'), 'tlacidlo kamery nepouziva sprite ikonu')
end

# --- 2) kamera = ciste citanie ----------------------------------------------

NxTest.test('UI-B2: callback kamery je registrovany a mieri na vlastny handler') do
  NxTest.assert(UIB2_PANEL_RB.include?("cb(dlg, 'nx_camera_focus')"),
                'panel.rb neregistruje callback nx_camera_focus')
  NxTest.assert(UIB2_SEL_CODE.include?('def handle_camera_focus'), 'chyba handler handle_camera_focus')
  NxTest.assert(UIB2_SEL_CODE.include?('def focus_camera_on'), 'chyba zarovnanie kamery focus_camera_on')
end

NxTest.test('UI-B2: kamera NEZAPISUJE do modelu (ziadna operacia, ziadny krok Spat)') do
  cam = UIB2_SEL_CODE[/def handle_camera_focus.*?\n        end\n/m].to_s +
        UIB2_SEL_CODE[/def focus_camera_on.*?\n        end\n/m].to_s
  NxTest.refute(cam.empty?, 'cesta kamery sa nenasla — guard by bol slepy')
  ['start_operation', 'commit_operation', 'Store.set', 'entities.add', 'selection.add',
   'selection.clear'].each do |bad|
    NxTest.refute(cam.include?(bad), "kamera nesmie volat #{bad} (pohlad nie su data modelu)")
  end
  NxTest.assert(cam.include?('view.camera.set') && cam.include?('view.zoom'),
                'kamera ma pouzivat view API (camera.set + zoom)')
end

NxTest.test('UI-B2: kamera nesie identitu dokumentu aj skrinky (asynchronny callback)') do
  NxTest.assert(UIB2_JS_CODE.include?('sketchup.nx_camera_focus'), 'JS neposiela nx_camera_focus')
  js = UIB2_JS_CODE[/function onPvCamera\(\).*?\n  \}/m].to_s
  NxTest.assert(js.include?('cabinet_id') && js.include?('model_guid'),
                'payload kamery musi niest cabinet_id aj model_guid')
  rb = UIB2_SEL_CODE[/def handle_camera_focus.*?\n        end\n/m].to_s
  NxTest.assert(rb.include?(%q<DocKey.foreign?(data['model_guid'], model)>),
                'server musi porovnat dokument payloadu s aktivnym')
  NxTest.assert(rb.include?("data['cabinet_id']"), 'server musi hladat skrinku podla ID z payloadu')
end

# Codex #169 P2: kym callback dobehne, mohol pouzivatel oznacit inu skrinku —
# vtedy pohlad NESMIE odskocit na tu stara (ostatne asynchronne akcie panela
# maju rovnaky test cerstvosti).
NxTest.test('UI-B2: kamera sa odmietne, ked sa medzitym zmenil VYBER') do
  rb = UIB2_SEL_CODE[/def handle_camera_focus.*?\n        end\n/m].to_s
  NxTest.assert(rb.include?('find_cabinet(model)'),
                'kamera musi vychadzat z AKTUALNEHO vyberu, nie len z ID v payloade')
  NxTest.assert(rb.include?("Store.get(cab, 'cabinet_id')"),
                'kamera musi porovnat oznacenu skrinku s ID z payloadu')
  NxTest.assert(rb.include?('refresh_after_stale'),
                'pri nezhode sa ma panel len zosuladit (ziadny pohyb pohladu)')
end

# Codex #169 P2: otocena skrinka je podporovany stav (rotaciu zachovava
# ScaleWatch.clean_transform) — pevne globalne -Y by pri nej ukazalo bok.
NxTest.test('UI-B2: celny pohlad sa odvodzuje z TRANSFORMACIE skrinky') do
  rb = UIB2_SEL_CODE[/def focus_camera_on.*?\n        end\n/m].to_s
  NxTest.assert(rb.include?('ent.transformation.yaxis') && rb.include?('ent.transformation.zaxis'),
                'smer aj hore musia ist z transformacie skrinky (otocena skrinka)')
  NxTest.refute(rb.include?('center.y -'), 'kamera nesmie pouzivat pevnu globalnu os')
  NxTest.assert(UIB2_SEL_CODE.include?('def camera_axis'),
                'os transformacie sa musi normalizovat (zoskalovana skrinka)')
end

# --- 3) nahlad kresli len z existujucich payloadov ---------------------------

NxTest.test('UI-B2: projekcie nepytaju od servera ziadne nove data') do
  calls = UIB2_JS_CODE.scan(/sketchup\.([a-z_]+)\(/).flatten.uniq.sort
  allowed = %w[nx_camera_focus select_zone].freeze
  (calls - allowed).each do |c|
    NxTest.assert(false, "preview.js vola nepovoleny callback sketchup.#{c} — nahlad kresli z payloadov")
  end
end

NxTest.test('UI-B2: kontext Kovanie ma vlastnu projekciu') do
  NxTest.assert(UIB2_JS_CODE.include?("'hw'"), 'chyba rezim projekcie kovania')
  NxTest.assert(UIB2_JS_CODE.include?('function nxHwMarks'), 'chyba odvodenie znaciek kovania')
  NxTest.assert(UIB2_JS_CODE.include?('function drawHwBase'), 'chyba kresba projekcie kovania')
end

NxTest.test('UI-B2: vysuv sa kresli ako „L" kolajnice + telo suflika (schvalene 20.8.)') do
  marks = UIB2_JS_CODE[/function nxHwMarks\(.*?\n  \}/m].to_s
  NxTest.assert(marks.include?('nxSlideGeom(fr, ix0, ix1)'),
                'geometria vysuvu zije v jednej cistej funkcii (testovatelna v Node)')
  # Codex #184 P2: vysuv drzi BOK korpusu — kotvi sa na vnutorne lica bokov
  # (x = t … W-t, tie iste, ake kresli drawCarcass), nie na bocnu medzeru cela.
  NxTest.assert(marks.match?(/ix0 = t, ix1 = W - t/),
                'kolajnica sa kotvi na hrubku boku, nie na fr_gap_sides')
  %w[slide_rail drawer].each do |kind|
    NxTest.assert(marks.include?("kind: '#{kind}'"), "chyba znacka #{kind}")
  end
  NxTest.refute(marks.include?("kind: 'slide'"),
                'stary pas naprieč celom sa uz nekresli')
  mark = UIB2_JS_CODE[/function hwMarkSvg\(.*?\n  \}/m].to_s
  NxTest.assert(mark.include?("m.kind === 'slide_rail'"), 'kolajnica ma vlastnu kresbu („L" profil)')
  # Hit-oblast znacky: priehladny siroky duplikat tahu. Hover CSS ho MUSI
  # vynechat, inak by sa pri prisvieteni boxu vyfarbil ako hruby pas.
  NxTest.assert(mark.include?('class="hwhit"'), 'kolajnica ma hit-oblast pre klik')
  NxTest.assert(UIB2_CSS.include?('#preview g.hwmk.hov path:not(.hwhit)'),
                'zvyraznenie sa nesmie dotknut priehladnej hit-oblasti')
end

NxTest.test('UI-B2: ghost vrstvy nikdy neprebiju zakladny pohlad (nekliktelne)') do
  %w[drawZonesGhost drawFrontsGhost].each do |fn|
    body = UIB2_JS_CODE[/function #{fn}\(.*?\n  \}/m].to_s
    NxTest.refute(body.empty?, "ghost vrstva #{fn} sa nenasla")
    NxTest.assert(body.include?('pointer-events="none"'),
                  "#{fn} musi kreslit bez interakcie (pointer-events none)")
  end
  # Ghost kovania kresli TIE ISTE znacky, len v tlmenom rezime — preto sa
  # nekliktelnost strazi v hwMarkSvg (jedno miesto pre obe podoby).
  hwg = UIB2_JS_CODE[/function drawHwGhost\(.*?\n  \}/m].to_s
  NxTest.assert(hwg.include?('hwMarkSvg(m, rx, ry, true)'),
                'ghost kovania musi ist cez hwMarkSvg s ghost priznakom')
  mark = UIB2_JS_CODE[/function hwMarkSvg\(.*?\n  \}/m].to_s
  NxTest.assert(mark.include?('if (ghost) return \'<g pointer-events="none"'),
                'ghost znacka kovania nesmie byt klikatelna')
end

NxTest.test('UI-B2: farby kot a ghostu su zrkadlom tokenov (ziadny novy hex v kresbe)') do
  NxTest.assert(UIB2_JS.include?("var PV_DIM = '#90a4ae'"), 'kota musi zrkadlit --nx-ink-faint')
  NxTest.assert(UIB2_JS.include?("var PV_GHOST = '#b0bec5'"), 'ghost musi zrkadlit --nx-border-strong')
  NxTest.assert(UIB2_CSS.include?('--nx-ink-faint:#90a4ae'), 'token --nx-ink-faint sa zmenil — zrkadlo v preview.js tiez')
  NxTest.assert(UIB2_CSS.include?('--nx-border-strong:#b0bec5'), 'token --nx-border-strong sa zmenil — zrkadlo v preview.js tiez')
end
