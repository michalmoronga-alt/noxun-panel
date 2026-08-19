# frozen_string_literal: true
# UI-C3 — CELA: kontrakt kontextu Cela + D-84, D-96 a D-89a.
#
# Co sa tu strazi (a preco to nestaci overit klikanim):
#   1) ZAMOK PRI VYSKE ZANIKOL — `locked` uz nie je samostatny checkbox, ale
#      PRESNE to, co pouzivatel vidi (vypisana hodnota drzi). Keby sa v paneli
#      vratil checkbox, dve pravdy o tom istom by sa zase rozisli.
#   2) D-84 rec stolara — „+ pridaj dvere" / „+ pridaj čelo"; „− riadok" ZANIKOL.
#   3) D-96 Uchytky — profil sa nastavuje V SEKCII pre ROZSAH ciel, ikona
#      v riadku je len indikator (ziadne cyklenie klikom).
#   4) N25 vyskovy rad — riadok cela cita TEN ISTY rad `vyska_cela`, ktory sa
#      edituje v koliesku, a hodnota ide EXISTUJUCOU zapisovou cestou pola.
#   5) D-89a hover hrany — Overlay NAD modelom: ziadna operacia, ziadny zapis,
#      ziadny krok Spat; guard dokumentu; odpojenie pri zatvoreni panela.
require_relative '../helper' unless defined?(NxTest)

UIC3_PANEL_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
UIC3_FORM_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')
UIC3_SETTINGS_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'settings.js'), encoding: 'UTF-8')
UIC3_ICONS_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')
UIC3_PART_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'part_card.js'), encoding: 'UTF-8')
UIC3_PANEL_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
UIC3_PARTS_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts.rb'), encoding: 'UTF-8')
UIC3_HOVER_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hover_edge.rb'), encoding: 'UTF-8')

# --- 1) zamok pri vyske ZANIKOL (zamknute <=> vypisane) ----------------------

NxTest.test('UI-C3: vyska cela nema samostatny zamok — zamknute je to, co je vypisane') do
  NxTest.refute(UIC3_FORM_JS.include?("class=\"flock\""),
                'checkbox zamku v riadku cela musi byt prec (dve pravdy o tom istom)')
  NxTest.refute(UIC3_FORM_JS.include?(".fh').closest"), 'kontrola nahodnej regresie zapisu')
  NxTest.assert(UIC3_FORM_JS.include?('locked: hasH'),
                'locked = „vyska je vypisana" (nic ine sa uz neposiela)')
  NxTest.assert(UIC3_FORM_JS.include?('function frontHeightAuto'),
                'chip AUTO vracia pole na automat')
  NxTest.assert(UIC3_FORM_JS.include?("inp.dispatchEvent(new Event('input'"),
                'chip AUTO ohlasi zmenu POVODNOU udalostou — vsetky guardy beziat nezmenene')
end

NxTest.test('UI-C3: server rozumie zamku rovnako (fixed + locked prezije round-trip)') do
  fr = Noxun::Engine::Fronts
  cfg = fr.normalize_config('items' => [
                              { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                                'height' => 180.0, 'locked' => true },
                              { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto',
                                'height' => nil, 'locked' => true }
                            ])
  NxTest.assert_equal(true, cfg['items'][0]['locked'], 'vypisana vyska = zamknuta')
  NxTest.assert_equal(false, cfg['items'][1]['locked'],
                      'AUTO riadok nemoze byt zamknuty (server to drzi bez ohladu na klienta)')
end

# --- 2) D-84 rec stolara -----------------------------------------------------

NxTest.test('D-84: tlacidla hovoria, CO pridavaju — a „− riadok" zanikol') do
  NxTest.assert(UIC3_PANEL_HTML.include?('pridaj dvere'), 'kridlove celo = „+ pridaj dvere"')
  NxTest.assert(UIC3_PANEL_HTML.include?('pridaj čelo'), 'zasuvkove celo = „+ pridaj čelo"')
  NxTest.refute(UIC3_PANEL_HTML.include?('− riadok'), '„− riadok" zanikol — maze sa krizikom pri riadku')
  NxTest.refute(UIC3_PANEL_HTML.include?('+ riadok'), '„+ riadok" uz nehovori nic o tom, co vznikne')
  NxTest.refute(UIC3_FORM_JS.include?('function removeLastFront'),
                's tlacidlom zanikla aj jeho funkcia (ziadny mrtvy kod)')
  NxTest.assert(UIC3_FORM_JS.include?("function addFrontKind"),
                'novy riadok dostane TYP hned — pouzivatel ho neprestavuje po pridani')
  NxTest.assert(UIC3_PANEL_HTML.include?('class="fdel"') || UIC3_FORM_JS.include?('class="fdel"'),
                'krizik pri riadku ostava jedinou mazacou cestou')
end

# --- 3) D-96 Uchytky ---------------------------------------------------------

NxTest.test('D-96: profil sa vybera v sekcii Uchytky pre ROZSAH ciel') do
  NxTest.assert(UIC3_PANEL_HTML.include?('id="frontProfileSel"'), 'sekcia ma vyber profilu')
  NxTest.assert(UIC3_PANEL_HTML.include?('id="frontProfileScope"'), 'sekcia ma vyber rozsahu')
  NxTest.assert(UIC3_PANEL_HTML.include?('data-key="fhandles"'), 'Uchytky su vlastna skupina kontextu Cela')
  NxTest.assert(UIC3_FORM_JS.include?('function onFrontProfilePick'), 'volba profilu ma vlastnu cestu')
  # Ikona v riadku je INDIKATOR, nie ovladac — ziadny onclick, ziadne cyklenie.
  NxTest.refute(UIC3_FORM_JS.include?('toggleFrontProfile'), 'cyklenie ikonou zaniklo')
  NxTest.refute(UIC3_FORM_JS.include?("class=\"fprof\" type=\"button\""),
                'indikator uz nie je tlacidlo')
end

NxTest.test('D-96: hrana osadenia sa NEPONUKA, kym ju registry nepozna') do
  # Registry (core/front_profiles.rb) pozna len skratenie HORNEJ hrany. Sekcia
  # preto o hrane mlci — ponukat volbu, ktora nema kam sadnut, by bola lož.
  rec = Noxun::Engine::FrontProfiles::REGISTRY['ukw7']
  NxTest.refute(rec.key?(:edge), 'kym registry hranu nema, UI ju nesmie ponukat')
  NxTest.refute(UIC3_PANEL_HTML.include?('id="frontProfileEdge"'),
                'ziadny mrtvy select hrany osadenia v paneli')
end

# --- 4) N25 vyskovy rad ------------------------------------------------------

NxTest.test('N25: riadok cela cita rad `vyska_cela` a zapisuje POVODNOU cestou') do
  NxTest.assert(UIC3_FORM_JS.include?("data-dim-key=\"vyska_cela\""),
                'mini-ponuka riadku nesie svoj rad v atributoch (riadky vznikaju az za behu)')
  NxTest.assert(UIC3_SETTINGS_JS.include?('function nxDimFillRow'),
                'dynamicke ponuky sa plnia TOU ISTOU cestou ako staticke')
  NxTest.assert(UIC3_SETTINGS_JS.include?('nxDimFillRow(document)'),
                'uprava radu v koliesku sa premietne aj do uz vykreslenych riadkov')
  NxTest.assert(Noxun::Engine::DimSeries::KEYS.include?('vyska_cela'),
                'rad `vyska_cela` je sucastou serveroveho kontraktu radov')
end

NxTest.test('N27: ikona typu cela ma svoj symbol v sprite (ziadne emoji)') do
  NxTest.assert(UIC3_ICONS_JS.include?("'door':"), 'kridlove dvierka maju vlastny symbol')
  NxTest.assert(UIC3_FORM_JS.include?('FRONT_TYPE_ICON'), 'mapa typ -> ikona je JEDINE miesto prekladu')
  NxTest.assert(UIC3_FORM_JS.include?("NXIcons.set(ico, frontTypeIcon(sel.value))"),
                'zmena typu meni `href` v <use>, nie innerHTML celeho uzla')
end

# --- 5) naviazane kovanie pod riadkom ---------------------------------------

NxTest.test('UI-C3: naviazane kovanie je JEDEN drobny riadok a vedie do Kovania') do
  NxTest.assert(UIC3_FORM_JS.include?('function openFrontHardware'),
                'klik na riadok kovania prepne kontext a najde box vlastnika')
  NxTest.assert(UIC3_FORM_JS.include?("setViewContext('kovanie')"), 'klik vedie tam, kam ukazuje (N13)')
  NxTest.assert(UIC3_FORM_JS.include?('ev.stopPropagation()'),
                'interaktivne prvky v riadku STOPUJU bublanie')
  css = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
  NxTest.assert(css.include?('.frow .fhw'), 'riadok kovania ma vlastny styl')
  NxTest.assert(css[/\.frow \.fhw \{[^}]*\}/m].include?('text-overflow: ellipsis'),
                'jednoriadkovy s ellipsis — vertikalny priestor panela je vzacny')
end

# --- 6) D-89a hover hrany ----------------------------------------------------

NxTest.test('D-89a: zvyraznenie hrany je POHLAD — ziadna operacia, ziadny zapis') do
  NxTest.refute(UIC3_HOVER_RB.include?('start_operation'),
                'overlay nesmie otvorit operaciu (prazdny krok Spat — lekcia D-103)')
  NxTest.refute(UIC3_HOVER_RB.include?('set_attribute'), 'nic sa nezapisuje do modelu')
  NxTest.refute(UIC3_PARTS_RB[/def handle_hover_edge.*?\n        end/m].to_s.include?('start_operation'),
                'ani handler panela neotvara operaciu')
  NxTest.assert(UIC3_HOVER_RB.include?('Sketchup::Overlay') || UIC3_HOVER_RB.include?('HoverEdgeOverlay'),
                'kresli sa Overlay-om NAD modelom')
end

NxTest.test('D-89a: hover ma guard dokumentu a vzdy zhasina') do
  NxTest.assert(UIC3_PARTS_RB.include?("data['model_guid'].to_s != model_guid(model)"),
                'callback je asynchronny — dokument sa overuje (vzor nx_edge_toggle)')
  NxTest.assert(UIC3_PANEL_RB.include?("cb(dlg, 'nx_hover_edge')"), 'callback je zaregistrovany')
  NxTest.assert(UIC3_PANEL_RB.include?('HoverEdge.release if defined?(HoverEdge)'),
                'zatvorenie panela overlay odpoji — v modeli nic neostane')
  NxTest.assert(UIC3_PART_JS.include?('function nxHoverEdgeClear'), 'JS vie zhasnut')
  NxTest.assert(UIC3_PART_JS.include?("if (c === nxHoverEdgeCode) return;"),
                'posiela sa LEN ZMENA — pohyb mysou nesmie zaplavit most do Ruby')
end

NxTest.test('D-89a: geometria hrany ide cez ZDIELANY kontrakt PartFaces') do
  NxTest.assert(UIC3_HOVER_RB.include?('PartFaces.axes_for_snapshot'),
                'osi dielca overuje ta ista funkcia ako pri D-104')
  NxTest.assert(UIC3_HOVER_RB.include?('PartFaces.face_rect_mm'),
                'ploska hrany ide z toho isteho kontraktu (kod hrany -> stena kvadra)')
  NxTest.assert(UIC3_HOVER_RB.include?('return nil if ax.nil?'),
                'neoveritelne osi = NEKRESLI SA NIC (radsej ziadna farba nez zla hrana)')
  # Farba je VYBER (--nx-select), nie stav olepu — mieru s EdgeCheck::COLORS
  # by si pouzivatel vylozil ako „tato hrana ma problem".
  NxTest.assert(UIC3_HOVER_RB.include?('COLOR = [16, 119, 135]'),
                'hover nesie farbu vyberu, nie farbu stavu olepu')
end

NxTest.test('D-89a: ploska hovoru sedi na tej istej stene ako kontrola olepu') do
  pf = Noxun::Engine::PartFaces
  # Lezaci dielec 600 x 400 x 18 mm (dlzka = X, sirka = Y, hrubka = Z).
  ax = pf.axes_for_snapshot('shelf', [600.0, 400.0, 18.0],
                            'length' => 600.0, 'width' => 400.0, 'thickness' => 18.0)
  NxTest.assert(ax, 'osi police su jednoznacne')
  lo = [0.0, 0.0, 0.0]
  hi = [600.0, 400.0, 18.0]
  hover = pf.face_rect_mm('L1', lo, hi, ax, Noxun::Engine::HoverEdge::OUT_MM)
  check = pf.face_rect_mm('L1', lo, hi, ax, Noxun::Engine::EdgeCheck::OUT_MM)
  NxTest.assert_equal(4, hover.length, 'ploska je stvoruholnik')
  # Ta ista stena, len o kus dalej von — hover musi byt vidno aj nad farbou olepu.
  NxTest.assert(Noxun::Engine::HoverEdge::OUT_MM > Noxun::Engine::EdgeCheck::OUT_MM,
                'hover lezi NAD kontrolou olepu, nie pod nou')
  NxTest.assert(hover[0][1] < check[0][1], 'obe plosky su na tej istej (min) strane osi')
end

# --- 7) kostra kontextu Cela -------------------------------------------------

NxTest.test('UI-C3: kontext Cela ma tri skupiny v zavaznom poradi') do
  keys = UIC3_PANEL_HTML.scan(/data-key="([a-z_]+)" data-s4="cela"/).flatten
  NxTest.assert_equal(%w[fronts fhandles fgaps], keys,
                      'Zoznam ciel -> Uchytky -> Medzery (poradie je kontrakt)')
end

NxTest.test('UI-C3: material ciel je dostupny aj zo zoznamu ciel (S3 je v tomto kontexte skryty)') do
  NxTest.assert(UIC3_PANEL_HTML.include?('id="cab_front_c"'), 'druhy ovladac materialu ciel')
  NxTest.assert(UIC3_PANEL_HTML.include?("data-nx-combo=\"decor\"></select></div>") ||
                UIC3_PANEL_HTML.include?('id="cab_front_c" data-nx-combo="decor"'),
                'je to TEN ISTY combobox D-85, nie vlastny vynalez')
  mats = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'materials.js'), encoding: 'UTF-8')
  NxTest.assert(mats.include?("setVal('cab_front_c'"),
                'oba ovladace tej istej hodnoty musia ostat v synchro')
end

# --- 8) N26 medzery jantarovo ------------------------------------------------

NxTest.test('N26: pri editacii medzier sa medzery v projekcii prisvietia jantarovo') do
  pv = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'preview.js'), encoding: 'UTF-8')
  NxTest.assert(pv.include?('pvGapsHot'), 'zvyraznenie ma vlastny stav viazany na fokus')
  NxTest.assert(pv.include?("PV_GAP_FILL = '#fff3e0'"), 'jantarova vypln je zrkadlom --nx-warn-bg-soft')
  NxTest.assert(pv.include?("PV_GAP_LINE = '#ffb74d'"), 'jantarova linka je zrkadlom --nx-warn')
  NxTest.assert(pv.include?("PV_GAP_TEXT = '#b26a00'"), 'text je zrkadlom --nx-warnchip-fg')
  # Pasy vznikaju z TOHO ISTEHO rozkladu, ktorym sa uz kotuje — ziadny novy vypocet.
  NxTest.assert(pv[/function drawFrontDims.*?\n  \}/m].include?("d.kind !== 'gap'"),
                'zvyraznenie berie useky z nxFrontDims, nic si nedopocitava')
end
