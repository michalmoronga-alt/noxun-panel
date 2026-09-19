# D-129/D-130 rework kontextu Čelá — outside-in, 19.9.2026

> Stav: KONCEPT / research packet + reconcile — podklad pre package D-130a/D-130b; vizuálna autorita je [ui20/mockup_cela_final.html](../ui20/mockup_cela_final.html) (schválený Michalom 19.9.2026).

Tri malé behy agy `gemini-3.8-flash-high`, `--mode plan`, izolovaný scratch, po dvoch cielených otázkach (Q1 medzery/okraje a znamienka · Q2 tooltipy v CEF + ikony v hlavičke skupiny · Q3 zoznam čiel, hromadná úchytka, AUTO výška). Surové packety nižšie bez úprav; reconcile orchestrátora pod nimi.

## Packet 1 — medzery a okraje (reveal/overlay), znamienka

| Kategória | Tvrdenie | Dôkaz (URL+verzia) | Overenie | Odporúčanie | Prácnosť S/M/L | Licencia |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **GOOD CUSTOM SOLUTION** | Väčšina CAD/pluginov používa len formulárové polia; schematický 2D diagram s kótami na hranách používa iba Blum na webe, v úzkom SketchUp paneli (470 px) je schéma čiel ergonomickejšia než 5 polí. | [Blum Cabinet Configurator](https://e-services.blum.com) (v2026) | VERIFIED | Ponechať schému s 5 poľami na obryse; zaberie menej vertikálneho miesta a eliminuje zámenu strán. | S | Proprietárny (vzory) |
| **CAD PRECEDENT** | SketchUp pluginy (CabinetSense) používajú presne 5 atribútov: `Top/Bottom/Left/Right Reveal` a `Door Gap`, zobrazené v HTML dialógu ako formulárové polia. | [CabinetSense Wiki – Reveals](https://sites.google.com/a/cabinetsensesoftware.com/cabinetsense-wiki/attribute/reveals) (v2020+) | VERIFIED | Ponechať dátovú štruktúru 4 okrajov + 1 medzery; schéma je len lepší vizuálny wrapper týchto polí. | S | Proprietárny (vzory) |
| **CAD PRECEDENT** | Konvencia znamienka „kladný reveal = zmenšenie čela (odskok), záporný reveal = presah čela cez korpus“ je v SketchUp nábytkárstve štandardizovaná. | [CabinetSense Wiki – Reveals](https://sites.google.com/a/cabinetsensesoftware.com/cabinetsense-wiki/attribute/reveals) (v2020+) | VERIFIED | Zachovať rovnakú logiku znamienok v kóde/engine; je matematicky aj precedenčne konzistentná. | S | Proprietárny (vzory) |
| **MISSED CONSTRAINT** | Slovenský stolár v dielni neuvažuje v záporných číslach; termín „záporný okraj“ bez vysvetlenia vyvolá chybu (zadá kladné číslo pre presah na úchop). | [Polyboard Help Centre](https://wooddesigner.org/help-centre/polyboard/) (v7.x) | VERIFIED | Do tooltipu ikony (?) uviesť: `+ = odskok (vidno korpus), 0 = zarovno, - = presah (napr. -20 mm úchop dole)`. Názov skupiny: „Okraje a medzery“. | S | Proprietárny (terminológia) |
| **CAD PRECEDENT** | Polyboard rieši medzery cez globálne pravidlá výroby (`Slack` / `Clearance`) a presahy cez `Overlap / Overpass`, Mozaik cez tabuľku parametrov (`FLRevT`, `FLRevB`, `FLRevC`). | [Polyboard Help Centre](https://wooddesigner.org/help-centre/polyboard/) (v7.x) | VERIFIED | Pre single-cabinet Inspector nepoužívať tabuľku ani zložité väzby (links); lokálne prepísanie na schéme je rýchlejšie. | S | Proprietárny (vzory) |
| **NO ACTION** | OpenCutList nerieši parametrické škáry ani presahy; spracováva iba hotové komponenty cez bounding box. | [OpenCutList GitHub](https://raw.githubusercontent.com/lairdubois/lairdubois-opencutlist-sketchup-extension/master/README.md) (v6.x) | VERIFIED | Z OpenCutListu nemožno pre konfiguráciu čiel prevziať kód ani UI vzor. | S | GNU GPLv3 |

Nenašiel som: verejnú dokumentáciu CabMaker (záložka Rules 2 — len uzavreté fórum, UNVERIFIED) · CAD so slovenským prekladom „reveal"; v CZ/SK praxi **medzera / škára** (gap), **odskok / priznaná hrana** (kladný reveal), **presah / naloženie** (záporný reveal, overlay).

## Packet 2 — tooltipy v CEF, ikony v hlavičke skupiny, popover

| Kategória | Tvrdenie | Dôkaz (URL+verzia) | Overenie | Odporúčanie | Prácnosť S/M/L | Licencia |
|---|---|---|---|---|---|---|
| **MISSED CONSTRAINT** | HTML atribút `title` v CEF funguje, ale má kritické vady: nezobrazuje sa na `disabled` prvkoch, má fixný delay (500–1000 ms), nezobrazuje sa bez fokusu a pri HiDPI škálovaní (125% DPI) sa text orezáva. | [CEF Issue #3769](https://github.com/chromiumembedded/cef/issues/3769) + [SketchUp HtmlDialog](https://ruby.sketchup.com/UI/HtmlDialog.html) (SU 2024–2026) | VERIFIED | Nepoužívať natívny `title`; nasadiť vlastný CSS/JS tooltip (napr. Floating UI/Tippy alebo čisté CSS s `data-tooltip`). Disabled prvky obaliť do `<span tabindex="0">` s `pointer-events: auto`. | S | MIT / Web standard |
| **CAD PRECEDENT** | Zavedené SketchUp pluginy (OpenCutList, Eneroth) nepoužívajú pre pomocné nápovedy surový `title`, ale dedikované webové komponenty bežiace čisto na strane DOM/JS bez volania Ruby callbackov. | [OpenCutList repo](https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension) (v6.1.0/v7.1.0) + [Eneroth dialogs-lib](https://github.com/Eneroth3/dialogs-lib) (v1.0.0) | VERIFIED | Implementovať interný tooltip komponent v JS/CSS; nezaťažovať Ruby-JS bridge pri `mouseenter`/`mouseleave`. | S | GPL-3.0 / MIT |
| **ALREADY EXISTS** | Klik na akčnú ikonu v zbaliteľnej skupine nesmie zbaliť panel. Štandardné riešenie: `event.stopPropagation()` na ikone a oddelenie triggerov (klikateľný je iba chevron/názov, ikony akcií sú v samostatnom flex kontajneri). | [OpenCutList JS UI](https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension) (v7.1.0, `src/ladb_opencutlist/js/plugins/`) | VERIFIED | Hlavičku rozdeliť cez flex na `[toggle (šípka + názov)]` a `[actions (ikony)]`. Na akčné tlačidlá v hlavičke priradiť `e.stopPropagation()`. | S | MIT / Web standard |
| **MISSED CONSTRAINT** | Otvorenie plávajúceho popoveru z ikony v hlavičke pri šírke panela 470 px naráža na okraj okna (`overflow: hidden`). CEF nepovolí vykreslenie HTML mimo okna dialógu. | [SketchUp HtmlDialog](https://ruby.sketchup.com/UI/HtmlDialog.html) (SU 2026, pevný rozmer okna) | VERIFIED | Popover ukotviť smerom dovnútra panela (`placement: bottom-end`), alebo ho riešiť ako rozbaľovací sub-panel priamo pod hlavičkou (in-flow accordion/drawer). | S | Proprietárna / Noxun |
| **GOOD CUSTOM SOLUTION** | Schválený mockup správne hierarchizuje informácie: kritické vstupy idú priamo do grafickej schémy korpusu s 5 poliami, kým (?) ikony slúžia len na sekundárnu nápovedu sémantiky. | [OpenCutList Docs](https://docs.opencutlist.org) (OpenCutList v7.x UI diagramy) | VERIFIED | Ponechať grafickú schému; tooltipy vyhradiť výhradne pre kontextové pravidlá (napr. „záporné číslo = presah čela"). | S | N/A |

Nenašiel som: natívne SketchUp API pre HTML tooltipy (100 % CEF/web vrstva) · spôsob vykresliť popover mimo rámca HtmlDialog · zdrojový kód UI Curic/Skalp/PlusSpec/Profile Builder (šifrované `.rbe`).

## Packet 3 — zoznam čiel, hromadná úchytka, AUTO výška

| Kategória | Tvrdenie | Dôkaz (URL+verzia) | Overenie | Odporúčanie | Prácnosť S/M/L | Licencia |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **CAD PRECEDENT** | Zoznam čiel: CAD nástroje (Blum, Mozaik) využívajú 2D fasádu; OpenCutList riadkový zoznam s rozklikom detailov do kariet | [OpenCutList Edit Part](https://docs.opencutlist.org/features/parts/parts-list/edit-part.md) (v7.1) | VERIFIED | Ponechať mockup (riadok + tlmený súhrn + akordeón); pre 470 px panel je to ergonomickejšie než 2D schéma | S | GNU GPLv3 (vzory áno) |
| **CAD PRECEDENT** | Hromadné kovanie: Blum a Polyboard aplikujú kovanie z predvolieb skrinky s lokálnymi prepismi (Overrides); OpenCutList cez editáciu skupiny | [Polyboard Help](https://wooddesigner.org/help-centre/polyboard/) (v7) | VERIFIED | Ponechať hlavičkový popover „všetkým" (rozsah/profil/hrana), na riadku indikovať manuálnu výnimku | M | Proprietárny (vzory) |
| **MISSED CONSTRAINT** | AUTO výška cez placeholder („≈ 275"): Placeholder je UX pasca (zameniteľnosť s reálnou hodnotou, strata po fokuse, v DOM je pole prázdne) | [NN/g Placeholders](https://www.nngroup.com/articles/form-design-placeholders/) (2024) | VERIFIED | Nepoužívať prázdny placeholder; zobraziť skutočnú vypočítanú hodnotu + badge `[AUTO]` a reset ikonu `↺` | S | Copyright NN/g |
| **CAD PRECEDENT** | Režim výšky čiel: CAD systémy (Cabinet Vision, Polyboard) nemajú prázdny input, ale stav „Proportional/Equal" vs „Fixed mm" s akciou „Equalize" | Mozaik Face Tab / Cabinet Vision Section Editor | UNVERIFIED | Akceptovať v poli reťazec `auto` aj číslo, prepnutie na fixnú hodnotu vykonať zápisom čísla | S | Proprietárny (vzory) |
| **GOOD CUSTOM SOLUTION** | Schéma medzier a okrajov (obrys korpusu s 5 poliami na hranách): Zodpovedá kótovaniu v konfigurátoroch Blum a Hettich adaptovanému do panelu | [Blum Configurator](https://www.blum.com/eu/en/services/planning-construction-product-selection/cabinet-configurator/) (2026) | VERIFIED | Ponechať schválený diagram medzier; výrazne eliminuje omyly v orientácii hrán oproti 5 zoznamovým poliam | S | Proprietárny (vzory) |

Nenašiel som: CAD s prázdnym inputom + vlnovkou v placeholderi pre AUTO bez indikátora režimu · úzky jednoriadkový akordeón s inline súhrnom je špecifický pre web/plugin UI, v desktop CADoch dominuje plná grafická fasáda.

## Reconcile orchestrátora (19.9.2026)

| Nález | Rozhodnutie | Dôvod / kam ide |
|---|---|---|
| P1 znamienka (CabinetSense: + odskok, − presah) | **berieme ako potvrdenie** | naša konvencia je rovnaká (D-119 `gap_*`, záporné = presah); nič sa nemení |
| P1 MISSED CONSTRAINT: stolár nemyslí v záporných číslach | **berieme** → D-130b | tooltip ? pri schéme dostane vetu „+ = odskok (vidno korpus) · 0 = zarovno · − = presah (napr. −20 mm)" a slová škára/odskok/presah; názov skupiny ostáva „Spoločné pre skrinku", riadok „Medzery a okraje" |
| P1 schéma = ergonomickejšia než 5 polí (Blum precedens) | **berieme ako potvrdenie** schváleného mockupu | — |
| P2 `title` v CEF nespoľahlivý (disabled, delay, HiDPI) | **berieme** → D-130a R8 | vlastný CSS tooltip komponent `nxtip` (čisté CSS `data-tip`, žiadna knižnica, žiadny Ruby callback); disabled ovládač s tooltipom obaliť do fokusovateľného spanu, ak taký vznikne |
| P2 hlavička: toggle vs. akcie, `stopPropagation` | **berieme ako potvrdenie** R1 | — |
| P2 popover naráža na okraj okna / `overflow` | **berieme** → D-130a pasca | popover ukotvený `right` dovnútra panela, mimo `summary`, a NESMIE byť orezaný `overflow` skupiny ani scroll kontajnera `.cbody` — overiť in-SU pri 470 px; ak by orezával, fallback = in-flow sub-panel pod hlavičkou |
| P3 zoznam s riadkom + súhrnom + akordeón (OCL vzor, GPL = vzory áno) | **berieme ako potvrdenie** | žiadny kód sa nepreberá |
| P3 hromadne = predvoľba + lokálne prepisy; výnimku indikovať na riadku | **berieme čiastočne** | hromadná akcia „všetkým" ostáva akcia (nie uložený default — vedomé, vzor D-131); výnimku „indikuje" súhrn riadku slovom („Profil J hore" / „bez úchytky") |
| P3 MISSED CONSTRAINT: placeholder „≈ 275" ako AUTO je UX pasca (NN/g) | **berieme čiastočne** → D-130a R4 | pravidlo „zamknuté ⇔ vypísané" ostáva (schválené, testované, jeden zdroj pravdy); zmiernenie: placeholder kurzívou a tlmene s „≈" (nezameniteľné s tučnou pevnou hodnotou), tooltip boxu „AUTO — výška sa dopočítava z voľného miesta; vypíš číslo = pevná výška", chip AUTO len pri pevnej hodnote (= akcia späť). Plná varianta (hodnota v poli + badge AUTO) by rozbila rozlíšenie „vypísané = zamknuté" a vyžadovala by tretí stav — odložené, ak sa v praxi ukáže zámena |
| P3 „Proportional/Fixed + Equalize" (UNVERIFIED) | **neberieme** | bez zdroja; náš AUTO = dopočet z voľného miesta, „Equalize" nemá u nás význam |
| P1 NO ACTION OpenCutList, P2 GOOD CUSTOM | — | bez zmeny |

Žiadny nález nemení schválený mockup; dva menia znenie tooltipov a jeden pridáva pascu pre implementáciu (popover vs. overflow). Probe v SketchUpe nie je potrebný (žiadny ALREADY EXISTS/SIMPLER NATIVE PATH nad API).
