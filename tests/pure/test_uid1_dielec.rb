# frozen_string_literal: true
# UI-D1 — DIELEC: dotiahnutie karty dielca podla kontraktu UI 2.0.
#
# Co sa tu strazi (a preco to nestaci overit klikanim):
#   1) „Zakladne hore" — rozmery dielca su VYSTUP (informacne riadky), nikdy
#      polia. Vedoma odchylka: aj `Smer dekoru` je informacia, lebo per-dielec
#      override smeru neexistuje (urcuje ho material) — karta preto nesmie mat
#      rozbalovacku, ktora by sa tvarila, ze nieco nastavuje.
#   2) Hranova ikona je JEDNA kresba a STYRI ROTACIE, odvodene zo strany 2D
#      nahladu (`edge_sides`) — nie styri ikony a nie pevna mapa nazvov.
#   3) „Označiť v modeli" je CISTE CITANIE + zmena vyberu: ziadna operacia,
#      ziadny zapis, ziadny krok Spat (lekcia D-103) + PRISNE guardy identity.
#   4) „Použiť na podobné…" ma JEDINU autoritu vyberu (`similar_parts_map`) pre
#      POCET aj ZAPIS — inak by modal slubil iny pocet, nez sa zapise — a zapisuje
#      cez `rebuild_many`, teda JEDNU operaciu = JEDEN krok Spat (vzor D-35).
#   5) Prenasa sa LEN olep hran. Material ani smer dekoru sa nedotknu.
require_relative '../helper' unless defined?(NxTest)

UID1_PANEL_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
UID1_PART_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'part_card.js'), encoding: 'UTF-8')
UID1_BRIDGE_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
UID1_ICONS_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')
UID1_USAGE_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'usage.js'), encoding: 'UTF-8')
UID1_CSS        = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
UID1_PANEL_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
UID1_PARTS_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts.rb'), encoding: 'UTF-8')
UID1_PAYLOADS_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads.rb'), encoding: 'UTF-8')

# Karta dielca v HTML — vsetky poradove kontroly miera PRESNE do nej.
UID1_CARD = UID1_PANEL_HTML[/<fieldset id="partCard".*?<\/fieldset>/m].to_s
# Handlery, na ktore sa pytame nizsie.
UID1_SELECT_PART = UID1_PARTS_RB[/def handle_select_part\b.*?\n        end\n/m].to_s
UID1_APPLY       = UID1_PARTS_RB[/def handle_apply_edges_similar\b.*?\n        end\n/m].to_s
UID1_COUNT       = UID1_PARTS_RB[/def handle_similar_parts_count\b.*?\n        end\n/m].to_s
UID1_MAP         = UID1_PARTS_RB[/def similar_parts_map\b.*?\n        end\n/m].to_s

# --- 1) Zakladne hore --------------------------------------------------------

NxTest.test('UI-D1: karta dielca ma Zakladne HORE — pred materialom aj hranami') do
  NxTest.assert(!UID1_CARD.empty?, 'karta dielca sa nasla')
  basic = UID1_CARD.index('id="pcBasic"')
  mat   = UID1_CARD.index('id="pcMaterial"')
  edges = UID1_CARD.index('id="edgeRows"')
  NxTest.assert(basic && mat && edges, 'vsetky tri bloky su v karte')
  NxTest.assert(basic < mat && mat < edges, 'poradie: Zakladne -> Material -> Hrany')
end

NxTest.test('UI-D1: rozmery dielca su VYSTUP — informacne riadky, nie polia') do
  # „Vystup nikdy nevyzera ako vstup" (trvala zasada z kol 15.8.). Povodny
  # jednoriadkovy `pcDim` zanikol; hodnoty skladaju `.inforow` riadky ako
  # v informacnom stlpci Zakladnych korpusu.
  NxTest.assert(!UID1_PANEL_HTML.include?('id="pcDim"'), 'stary riadok rozmerov uz neexistuje')
  NxTest.assert(!UID1_PART_JS.include?("el('pcDim')"), 'JS uz na neho nesiaha')
  NxTest.assert(UID1_PART_JS.include?("class=\"inforow\""), 'riadky su informacne (.inforow)')
  NxTest.assert(UID1_CARD.include?('class="pcbasic basicgrid"'),
                'pouziva sa TA ISTA mriezka ako v Zakladnych korpusu — jeden vizualny jazyk')
end

NxTest.test('UI-D1 (vedoma odchylka): Smer dekoru je INFORMACIA, nie rozbalovacka') do
  # Per-dielec override smeru dekoru neexistuje: `part_overrides` pozna len
  # `material_id`, `edges` a `edge_warnings` (CabinetBuilder.norm_overrides),
  # smer urcuje katalogove pole `grain` materialu. Pole, ktore by sa tvarilo,
  # ze nieco nastavuje, by bola lož — preto je to text s vysvetlenim.
  NxTest.assert(UID1_PART_JS.include?('Smer dekoru'), 'udaj sa v karte ukazuje')
  NxTest.assert(!UID1_CARD.include?('pc_grain'), 'karta dielca NEMA select smeru dekoru')
  NxTest.assert(UID1_PART_JS.include?('mení sa v katalógu materiálov'),
                'karta povie, kde sa smer naozaj meni (nikdy ticho mŕtvy udaj)')
  NxTest.assert(UID1_PAYLOADS_RB.include?("'grain_direction' => cfg['grain_direction']"),
                'payload karty nesie smer zo SNAPSHOTU dielca (server, nie JS)')
end

# --- 2) hranove ikony --------------------------------------------------------

NxTest.test('UI-D1: hranova ikona je JEDNA kresba a STYRI rotacie') do
  NxTest.assert(UID1_ICONS_JS.include?("'edge':"), 'symbol #i-edge zije v sprite')
  NxTest.assert(UID1_PART_JS.include?('data-rot="'), 'rotaciu nesie atribut, nie styri ikony')
  %w[90 180 270].each do |deg|
    NxTest.assert(UID1_CSS.include?(".eic[data-rot=\"#{deg}\"] { transform: rotate(#{deg}deg); }"),
                  "CSS pozna rotaciu #{deg}°")
  end
end

NxTest.test('UI-D1: rotacia sa odvodzuje zo STRANY 2D nahladu (edge_sides)') do
  # Ikona musi ukazovat presne tu hranu, ktoru nahlad nad zoznamom farebne
  # kresli — preto sa uhol berie z `pc.edge_sides` (AbsRules, jediny zdroj
  # pravdy o orientacii dielca), nie z prekladu nazvu hrany.
  NxTest.assert(UID1_PART_JS.include?('nxEdgeRotOf(sides[code])'), 'uhol pochadza zo strany hrany')
  NxTest.assert(UID1_PART_JS.include?('PC_EDGE_ROT = { top: 0, right: 90, bottom: 180, left: 270 }'),
                'mapa strana -> uhol je JEDNA a explicitna')
end

# --- 3) „Označiť v modeli" ---------------------------------------------------

NxTest.test('UI-D1: „Označiť v modeli" NIE JE zapis ani krok Spat') do
  NxTest.assert(!UID1_SELECT_PART.empty?, 'handler sa nasiel')
  NxTest.assert(!UID1_SELECT_PART.include?('start_operation'), 'ziadna operacia (lekcia D-103)')
  NxTest.assert(!UID1_SELECT_PART.include?('CabinetBuilder.rebuild'), 'ziadna prestavba')
  NxTest.assert(!UID1_SELECT_PART.include?('store_override'), 'ziadny zapis do configu')
  NxTest.assert(UID1_SELECT_PART.include?('suspend_selection_sync'),
                'zmena vyberu bezi pod guardom (vzor handle_select_parts)')
end

NxTest.test('UI-D1: „Označiť v modeli" ma PRISNY guard dokumentu aj skrinky') do
  NxTest.assert(UID1_SELECT_PART.include?("data['model_guid'].to_s != model_guid(model)"),
                'cudzi dokument akciu zastavi (ID skriniek sa naprie dokumentmi opakuju)')
  NxTest.assert(UID1_SELECT_PART.include?("Store.get(cab, 'cabinet_id').to_s != data['cabinet_id'].to_s"),
                'oneskoreny callback nesmie oznacit dielec inej skrinky')
  NxTest.assert(UID1_SELECT_PART.include?('find_part_by_role_key'),
                'dielec sa hlada podla part_key — skrinka sa medzitym mohla prestavat')
end

# --- 4) „Použiť na podobné…" -------------------------------------------------

NxTest.test('UI-D1: definicia „podobny" je ROLA + MATERIAL a zdroj sa vynecha') do
  NxTest.assert(!UID1_MAP.empty?, 'vyberova funkcia sa nasla')
  NxTest.assert(UID1_MAP.include?("Store.get(p, 'role').to_s == role"), 'rovnaka ROLA')
  NxTest.assert(UID1_MAP.include?("(Store.config(p) || {})['material_id'].to_s == mat"),
                'rovnaky VYSLEDNY material (snapshot dielca)')
  NxTest.assert(UID1_MAP.include?('keys.delete(src_key) if cid == src_cid'),
                'zdrojovy dielec sa do vyberu nepocita')
  NxTest.assert(UID1_MAP.include?('all_cabinets(model)') && UID1_MAP.include?("scope == 'project'"),
                'rozsah „celý projekt" ide cez vsetky korpusy modelu')
end

NxTest.test('UI-D1: POCET aj ZAPIS idu TOU ISTOU funkciou') do
  NxTest.assert(UID1_COUNT.include?('similar_parts_map('), 'pocet sa pyta vyberovej funkcie')
  NxTest.assert(UID1_APPLY.include?('similar_parts_map('), 'zapis sa pyta TEJ ISTEJ funkcie')
  NxTest.assert(UID1_PARTS_RB.include?('SIMILAR_SCOPES = %w[cabinet project].freeze'),
                'rozsah je whitelist na strane servera (HTML nie je ochrana)')
  NxTest.assert(!UID1_PART_JS.include?('part_keys'),
                'JS neposiela zoznam cielov — podobne dielce si server najde SAM')
end

NxTest.test('UI-D1: zapis je JEDNA operacia = JEDEN krok Spat') do
  NxTest.assert(UID1_APPLY.include?('CabinetBuilder.rebuild_many'),
                'vsetky dotknute korpusy sa prestavaju naraz (vzor D-35, nikdy slucka rebuildov)')
  NxTest.assert(!UID1_APPLY.include?('CabinetBuilder.rebuild(') && !UID1_APPLY.include?('rebuild_focus_part'),
                'ziadny rebuild po jednom — inak by Ctrl+Z vracalo po skrinkach')
  NxTest.assert(UID1_APPLY.include?('suspend_selection_sync'), 'prestavba bezi pod selection guardom')
  NxTest.assert(UID1_APPLY.include?('focus_part(model, cab, src_rk)'),
                'po prestavbe ostava vo vybere ZDROJOVY dielec (karta sa nestrati)')
end

NxTest.test('UI-D1: prenasa sa LEN olep hran (material ani smer sa nedotknu)') do
  NxTest.assert(UID1_APPLY.include?("rec['edges'] = JsonFileStore.deep_copy(src_edges)"),
                'kopiruje sa ZAZNAM overridu hran')
  NxTest.assert(!UID1_APPLY.include?("rec['material_id']"), 'material ciela sa nemeni')
  NxTest.assert(!UID1_APPLY.include?('grain'), 'smer dekoru sa nemeni')
  NxTest.assert(UID1_APPLY.include?("rec.delete('edges')"),
                'prazdny override zdroja VRATI ciele na pravidlo (je to tiez rozhodnutie)')
  NxTest.assert(UID1_APPLY.include?("rec.delete('edge_warnings')"),
                'sticky remap dovody patria starym hranam — s prepisom zanikaju')
end

NxTest.test('UI-D1: karta dielca NEROBI flush handshake (a vie preco)') do
  # `flushCabinetEditsNow` posiela `apply_all` BEZPODMIENECNE a ten vzdy prestava
  # korpus + `reselect(model, cab)` — vyrobil by prazdny krok Spat a zhodil by
  # z vyberu DIELEC, takze by nasledny zapis nemal na com pracovat. Karta dielca
  # navyse ziadne debounce polia nema (material aj hrany idu okamzite).
  NxTest.assert(!UID1_PART_JS.include?('flushCabinetEditsNow()'),
                'karta dielca flush NEVOLA (zhoda s onEdgeChange/onPartMaterial/onEdgesAll)')
  NxTest.assert(UID1_PART_JS.include?('FLUSH HANDSHAKE ZAMERNE NEROBI'),
                'dovod je zapisany pri kode — inak to buduci citatel precita ako zabudnutie')
end

NxTest.test('UI-D1: zivy pocet aj zapis maju guard dokumentu') do
  NxTest.assert(UID1_COUNT.include?("data['model_guid'].to_s != model_guid(model)"), 'pocet: guard dokumentu')
  NxTest.assert(UID1_APPLY.include?("data['model_guid'].to_s != model_guid(model)"), 'zapis: guard dokumentu')
  NxTest.assert(UID1_PARTS_RB.include?("return [nil, nil, nil, 'Karta patrí inému dielcu"),
                'karta musi sediet s dielcom vo vybere (asynchronny callback)')
end

# --- 5) modal a callbacky ----------------------------------------------------

NxTest.test('UI-D1: modal ma rozsah, zivy pocet a NIE nativne disabled') do
  modal = UID1_PANEL_HTML[/<div id="simModal".*?\n<\/div>\n/m].to_s
  NxTest.assert(!modal.empty?, 'modal sa nasiel')
  NxTest.assert(modal.include?('data-sim-scope="cabinet"') && modal.include?('data-sim-scope="project"'),
                'rozsah je segmentovy prepinac (dva rovnocenne stavy)')
  NxTest.assert(modal.include?('id="simCount"'), 'zivy pocet ma svoje miesto')
  NxTest.assert(modal.include?('id="simApplyBtn"') && modal.include?('aria-disabled="true"'),
                'neaktivne tlacidlo je aria-disabled (vzor D-78), nie nativne disabled')
  NxTest.assert(!modal.include?(' disabled'), 'nativne `disabled` by zhltlo hover aj vysvetlenie')
end

NxTest.test('UI-D1: rad akcii je JEDEN riadok dole (vertikalny priestor)') do
  row = UID1_CARD[/<div class="btnrow pcactions">.*?<\/div>/m].to_s
  NxTest.assert(!row.empty?, 'rad akcii sa nasiel')
  NxTest.assert(row.include?('selectPartInModel()') && row.include?('openSimilarModal()'),
                'obe akcie zdielaju JEDEN riadok')
  NxTest.assert(UID1_CARD.index('id="edgeRows"') < UID1_CARD.index('class="btnrow pcactions"'),
                'rad stoji pod zoznamom hran (vzor mockupu s4Part)')
end

NxTest.test('UI-D1: callbacky su zaregistrovane a merac pozna svoje kluce') do
  %w[nx_select_part nx_similar_parts_count nx_apply_edges_similar].each do |name|
    NxTest.assert(UID1_PANEL_RB.include?("cb(dlg, '#{name}')"), "callback #{name} je zaregistrovany")
  end
  NxTest.assert(UID1_BRIDGE_JS.include?('setSimilarCount: function(data)'),
                'odpoved servera ma svoju cestu do JS')
  NxTest.assert(UID1_BRIDGE_JS.include?("if (mode !== 'part' && typeof closeSimilarModal === 'function')"),
                'modal sa mimo karty dielca zatvara (oneskorene „Použiť" nesmie zapisat inam)')
  %w[part:select-in-model part:apply-similar].each do |key|
    NxTest.assert(UID1_USAGE_JS.include?("'#{key}'"), "kluc meraca #{key} je v allowliste")
  end
end
