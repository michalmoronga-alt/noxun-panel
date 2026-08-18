# frozen_string_literal: true
# UI-B1 — kostra Inspectora: guardy nad ZDROJOM (panel.html / panel.css /
# panel.rb / js). Kontrolovane invarianty:
#   1) rail ma STATICKE ID a vyhlasene kluce meraca z allowlistu usage.js (A9),
#   2) obsah je v styroch sektoroch (data-key s1..s4) a skupiny S4 su oznacene
#      kontextom (data-s4) — bez toho by ich CSS nevedelo prepinat (A3/A5),
#   3) stare taby su NAHRADENE, nie prekryte: v paneli ani v CSS nesmie ostat
#      `data-cab-tab`, `.cabtab` ani satelitne tlacidla hlavicky (A8),
#   4) JEDNA PRAVDA sirky (A7): NX_FIT_MIN v HTML a rozmery HtmlDialogu v
#      panel.rb hovoria to iste (obsah 470 px + ramik okna),
#   5) nove CSS pravidla kostry visia pod korenovou triedou `.nx-inspector`,
#      lebo panel.css zdielaju satelitne okna (A8).
require_relative '../helper' unless defined?(NxTest)

UIB1_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
UIB1_CSS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
UIB1_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
UIB1_USAGE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'usage.js'), encoding: 'UTF-8')
UIB1_SHELL = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), encoding: 'UTF-8')
UIB1_ICONS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')

UIB1_RAIL_IDS = %w[railKorpus railZony railCela railKovanie railTemp railAbs railCfg railStudio].freeze
UIB1_CTX = %w[korpus zony cela kovanie].freeze

# Guardy sa tykaju KODU, nie komentarov (v komentaroch tieto retazce zamerne
# su — vysvetluju kontrakt). Preto sa komentare pred kontrolou odstranuju.
def uib1_no_comments(src, style)
  out = src.dup
  out = out.gsub(/<!--.*?-->/m, ' ') if style == :html
  out = out.gsub(%r{/\*.*?\*/}m, ' ') if style == :css
  if style == :js
    out = out.gsub(%r{/\*.*?\*/}m, ' ')
    out = out.lines.map { |l| l.sub(%r{//[^
]*}, '') }.join
  end
  out
end
UIB1_HTML_CODE = uib1_no_comments(UIB1_HTML, :html)
UIB1_CSS_CODE = uib1_no_comments(UIB1_CSS, :css)
UIB1_SHELL_CODE = uib1_no_comments(UIB1_SHELL, :js)

# --- 1) rail -----------------------------------------------------------------

NxTest.test('UI-B1: rail ma vsetky tlacidla so STATICKYM id (merac D-25)') do
  UIB1_RAIL_IDS.each do |id|
    NxTest.assert(UIB1_HTML.include?("id=\"#{id}\""), "raily chyba tlacidlo s id=\"#{id}\"")
  end
end

NxTest.test('UI-B1: vyhlasene kluce meraca su z ALLOWLISTU usage.js') do
  allow = UIB1_USAGE[/var USAGE_KEYS = \[(.*?)\];/m].to_s.scan(/'([^']+)'/).flatten
  NxTest.refute(allow.empty?, 'usage.js musi mat allowlist USAGE_KEYS')
  used = UIB1_HTML.scan(/data-nx-usage="([^"]+)"/).flatten
  NxTest.refute(used.empty?, 'rail musi vyhlasovat kluce meraca')
  (used - allow).each do |k|
    NxTest.assert(false, "kluc '#{k}' nie je v allowliste usage.js — merac by ho zahodil")
  end
  NxTest.assert(used.uniq.length == used.length, 'kazdy kluc meraca smie byt v paneli raz')
end

NxTest.test('UI-B1: kontexty raily volaju guard setViewContext (nie priamu zmenu DOM)') do
  UIB1_CTX.each do |ctx|
    NxTest.assert(UIB1_HTML.include?("setViewContext('#{ctx}')"), "kontext #{ctx} nema handler")
  end
  NxTest.assert(UIB1_SHELL.include?('if (!ctxEnabled()) return false;'),
                'guard: mimo oznaceneho korpusu sa kontext NESMIE prepnut (autorita je JS, nie CSS)')
end

NxTest.test('UI-B1: krizik docasnej polozky je REALNE tlacidlo (klavesnica)') do
  # Codex #168 P2: span s role="button" sa neda aktivovat Enterom/medzernikom
  # a tlacidlo vnorene v tlacidle je neplatne HTML — krizik preto stoji VEDLA
  # ukazovatela ako samostatny <button>.
  x = UIB1_HTML_CODE[/<[a-z]+ [^>]*id="railTempX"[^>]*>/].to_s
  NxTest.assert(x.start_with?('<button'), 'krizik musi byt <button>, nie span s role')
  NxTest.assert(x.include?('aria-label='), 'krizik nesie aria-label (citacka aj klavesnica)')
  temp = UIB1_HTML_CODE[/<[a-z]+ id="railTemp"[^>]*>/].to_s
  NxTest.refute(temp.start_with?('<button'), 'ukazovatel sam nic nerobi — nesmie byt tlacidlo')
  NxTest.refute(temp.include?('railTempX'), 'krizik NESMIE byt vnoreny v ukazovateli')
end

NxTest.test('UI-B1: rail pouziva vlastnu bublinu, nie nativny title') do
  # Dva tooltipy naraz (vlastna bublina + oneskoreny systemovy) su chyba —
  # vysvetlenie neaktivneho kontextu ide do .railtip a do aria-label.
  NxTest.refute(UIB1_SHELL_CODE.include?('.title ='), 'shell.js nesmie nasadzovat nativny title')
  NxTest.assert(UIB1_SHELL_CODE.include?("querySelector('.railtip')"),
                'popis kontextu sa pise do vlastnej bubliny')
  UIB1_RAIL_IDS.each do |id|
    tag = UIB1_HTML_CODE[/<[a-z]+ [^>]*id="#{id}"[^>]*>/].to_s
    NxTest.refute(tag.include?(' title='), "#{id}: nativny title by zdvojil bublinu raily")
  end
end

NxTest.test('UI-B1: ikony raily su v sprite icons.js') do
  %w[cabinet front hammer shell slab].each do |icon|
    NxTest.assert(UIB1_ICONS.include?("'#{icon}':"), "sprite nema ikonu '#{icon}'")
    NxTest.assert(UIB1_HTML.include?("#i-#{icon}"), "panel ikonu '#{icon}' nepouziva")
  end
end

# --- 2) sektory a skupiny -----------------------------------------------------

NxTest.test('UI-B1: obsah je v styroch sektoroch S1–S4') do
  %w[s1 s2 s3 s4].each do |k|
    NxTest.assert(UIB1_HTML.include?("data-key=\"#{k}\""), "chyba sektor data-key=\"#{k}\"")
  end
  NxTest.assert_equal(4, UIB1_HTML.scan(/class="sect"/).length, 'sektory su presne styri')
  %w[secPreview secBasic secMat secSet].each do |id|
    NxTest.assert(UIB1_HTML.include?("id=\"#{id}\""), "sektor #{id} chyba")
  end
end

NxTest.test('UI-B1: kazdy kontext ma v S4 aspon jednu skupinu (data-s4)') do
  UIB1_CTX.each do |ctx|
    NxTest.assert(UIB1_HTML.include?("data-s4=\"#{ctx}\""), "kontext #{ctx} nema v S4 ziadny obsah")
  end
  # Neznamy kontext v data-s4 by bol ticho neviditelny (CSS ho nikdy neukaze).
  UIB1_HTML_CODE.scan(/data-s4="([^"]+)"/).flatten.uniq.each do |ctx|
    NxTest.assert(UIB1_CTX.include?(ctx), "data-s4=\"#{ctx}\" nie je platny kontext raily")
  end
end

NxTest.test('UI-B1: strom zon je z exkluzivity vynaty (data-s4-solo)') do
  zones = UIB1_HTML[/<details data-key="zones"[^>]*>/].to_s
  NxTest.assert(zones.include?('data-s4-solo'),
                'strom zon ma vlastne rozrolovanie (UI-C2) — nesmie ho zavriet susedna skupina')
end

# --- 3) stare taby su NAHRADENE ----------------------------------------------

NxTest.test('UI-B1: po raile nesmie ostat ziadny zvysok rezimovych tabov') do
  ['data-cab-tab', 'class="cabtab', 'nxhdr-modes', 'satbtns', 'prodbtn'].each do |dead|
    NxTest.refute(UIB1_HTML_CODE.include?(dead), "panel.html stale obsahuje '#{dead}'")
  end
  ['data-cab-tab', '.cabtab', '.satbtns', '.prodbtn'].each do |dead|
    NxTest.refute(UIB1_CSS_CODE.include?(dead), "panel.css stale nesie pravidlo pre '#{dead}'")
  end
end

# --- 4) jedna pravda sirky (D-51) --------------------------------------------

NxTest.test('UI-B1/D-51: NX_FIT_MIN a rozmery HtmlDialogu hovoria to iste') do
  fit_w = UIB1_HTML[/NX_FIT_MIN\s*=\s*\{\s*w:\s*(\d+)/, 1].to_i
  fit_h = UIB1_HTML[/NX_FIT_MIN\s*=\s*\{[^}]*h:\s*(\d+)/, 1].to_i
  NxTest.assert_equal(470, fit_w, 'obsahovy viewport Inspectora je 470 px (D-51)')
  NxTest.assert_equal(810, fit_h, 'obsahova vyska Inspectora je 810 px (D-51)')

  dlg = UIB1_RB[/UI::HtmlDialog\.new\((.*?)\)\n/m].to_s
  w = dlg[/width:\s*(\d+)/, 1].to_i
  minw = dlg[/min_width:\s*(\d+)/, 1].to_i
  h = dlg[/height:\s*(\d+)/, 1].to_i
  # Rozmery konstruktora su VONKAJSIE — obsah + ramik okna (Windows ~16/40 px).
  NxTest.assert(w >= fit_w && w <= fit_w + 40,
                "width #{w} nesedi s obsahovym minimom #{fit_w} (+ ramik okna)")
  NxTest.assert_equal(w, minw, 'min_width musi drzat rovnaku sirku ako width (jedna pravda)')
  NxTest.assert(h >= fit_h && h <= fit_h + 60,
                "height #{h} nesedi s obsahovou vyskou #{fit_h} (+ titulok okna)")
end

# --- 5) CSS scope -------------------------------------------------------------

NxTest.test('UI-B1: pravidla kostry visia pod korenovou triedou .nx-inspector') do
  NxTest.assert(UIB1_HTML.include?("documentElement.className = 'nx-inspector'"),
                'korenova trieda sa nasadzuje na <html> (body.className prepisuje setUiMode)')
  # Kazde pravidlo, ktore sa dotyka kostry, musi byt scopnute — panel.css
  # zdielaju satelitne okna a tie o raile ani sektoroch nevedia.
  %w[.crail .railbtn .railtip .raildiv .secthead .sectbody].each do |sel|
    UIB1_CSS_CODE.lines.each_with_index do |line, i|
      next unless line.include?(sel)
      next unless line.include?('{') # len selektorove riadky, nie pokracovanie deklaracii

      NxTest.assert(line.include?('.nx-inspector'),
                    "panel.css:#{i + 1} — pravidlo pre '#{sel}' nie je scopnute pod .nx-inspector")
    end
  end
end

NxTest.test('UI-B1: S2/S3 patria kontextu Korpus, inde je kontextovy riadok') do
  # Kontrakt UI 2.0 (sekcia Kostra): Zakladne a Materialy su vlastnosti SKRINKY
  # a ziju v kontexte Korpus (+ Materialy pri vkladani); Zony/Cela/Kovanie
  # dostanu namiesto nich tenky riadok s preklikom. UI-B1 dala do CSS mapu len
  # pre REZIM VYBERU a tuto cast ticho vynechala — guard to uz nedovoli.
  NxTest.assert(UIB1_CSS.include?('body.mode-cab:not([data-view-ctx="korpus"]) #secBasic'),
                'CSS musi mimo Korpusu skryvat sektor Zakladne')
  NxTest.assert(UIB1_CSS.include?('body.mode-cab:not([data-view-ctx="korpus"]) #secMat'),
                'CSS musi mimo Korpusu skryvat sektor Materialy')
  # Rezimove skryvanie (dielec/doska maju vlastnu kartu) ostava v platnosti.
  NxTest.assert(UIB1_CSS.include?('body.mode-part #secBasic'), 'dielec: S2 sa stale skryva')
  NxTest.assert(UIB1_CSS.include?('body.mode-board #secMat'), 'doska: S3 sa stale skryva')
  # Riadok je STATICKY prvok kostry s preklikom cez rovnaky guard ako rail.
  NxTest.assert(UIB1_HTML.include?('id="ctxNote"'), 'kontextovy riadok chyba v kostre')
  NxTest.assert(UIB1_HTML.include?('id="ctxNoteSum"'), 'riadok musi mat miesto na suhrn skrinky')
  link = UIB1_HTML_CODE[/<[a-z]+ [^>]*id="ctxNoteLink"[^>]*>/].to_s
  NxTest.assert(link.start_with?('<button'), 'preklik na Korpus musi byt <button> (klavesnica)')
  NxTest.assert(link.include?("setViewContext('korpus')"),
                'preklik ide cez guard setViewContext, nie priamou zmenou DOM')
  # Pravidlo zije v JS ako CISTA funkcia — CSS je jej zrkadlo, nie druhy zdroj.
  NxTest.assert(UIB1_SHELL_CODE.include?('function sectorVis('),
                'shell.js musi mat viditelnost sektorov ako cistu funkciu')
  NxTest.assert(UIB1_SHELL_CODE.include?('sectorVis: sectorVis'),
                'sectorVis sa exportuje (inak ju Node matica neotestuje)')
end

NxTest.test('UI-B1: sektor S4 prepina skupiny cez data-view-ctx (nie cez re-render)') do
  NxTest.assert(UIB1_CSS.include?('body.mode-cab[data-view-ctx="korpus"] [data-s4="korpus"]'),
                'CSS musi kontextom vraciat skupiny S4')
  NxTest.assert(UIB1_SHELL.include?("setAttribute('data-view-ctx'"),
                'atribut kontextu nasadzuje shell.js (prezije prepis body.className)')
  NxTest.refute(UIB1_SHELL_CODE.include?('innerHTML'),
                'A4: kostra sa NEPREKRESLUJE — innerHTML by zabil listenery aj rozpisane hodnoty')
end
