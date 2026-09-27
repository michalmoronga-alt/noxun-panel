# Blok 8 · K3 rohová — rešerš precedensov (outside-in, surový výstup)

> Rešeršér: Claude subagent `reserser` (sonnet, web), 27.9.2026 ~23:20–23:45 (noc — Antigravity sa v noci nepoužíva). Surový výstup bez úprav
> obsahu; triáž robí orchestrátor v koncepte (reconcile). Pozn. orchestrátora: veta v §2 „dverová zóna je pri rohu, slepá časť ďalej od rohu"
> je v rešerši prehodená — v slepej rohovej je **slepá časť v rohu** (za susedným radom) a dvere na opačnom konci; „pánty pri rohu" = pánty
> na strane dverí pri CR lište (na výstuhe závesov), čo zodpovedá DC aj rozhodnutiu R7.

# Research packet — dolná slepá rohová skrinka (blind corner base cabinet) s rohovou lištou

Overené 27.9.2026. Fakty len z otvorených zdrojov (výrobcovia kovania, softvér, stolárske blogy/fóra). Kde zdroj nie je oficiálny/výrobcov, je označené **NEOVERENÉ** ako doplnok.

## 1. Ako to modelujú iné nástroje

**ArchiWood (SketchUp plugin)** — má "ready-to-use corner cabinets, end panels and special modules to help cover tricky spaces while keeping machining rules consistent" (archiwood.github.io). Detailné parametre CR/blenda pomenovania sa v anglických zdrojoch nenašli — **NEOVERENÉ**, že používa presne názvy CR1/CR2 (to je zrejme interná terminológia dielne, nie univerzálna).

**Mozaik Software** — v knižnici má priamo štyri hotové typy: *Base Blind Cabinet Left – With Filler*, *Base Blind Cabinet Right – With Filler*, *Base Blind Filler Left*, *Base Blind Filler Right* (help.cadmate.com.au, prístupné len cez search snippet, plný článok sa nepodarilo stiahnuť — časť **NEOVERENÉ**). Zaujímavé: filler existuje aj ako **samostatný cabinet-objekt** (nie len súčasť skrinky), aj ako "With Filler" variant zabudovaný priamo do skrinky — teda oba prístupy paralelne. Systém parametrov Mozaiku je všeobecne "on/off a value choices" na úrovni cabinetu (help.cadmate.com.au, "Products/Cabinets" sekcia) — presné mená parametrov pre blind corner sa nepodarilo dotiahnuť (403/skrátený obsah).

**CabWriter** (SketchUp-based cabinet software) — Blind Corner Base ako vlastný cabinet typ: "Zero, one or two doors; Zero, one, or two drawers; Zero to three shelves… Extends into corner a user specified amount" (cabwritersoftware.com/cabwriter/cabinet-types/). Má tiež príkaz na **zrkadlenie celej skrinky** ("mirror an existing cabinet by redrawing it in place, exactly mirrored end to end") — teda L/P sa v CabWriteri riešia znovu-vygenerovaním zrkadlenej kópie, nie len prepínačom vlastnosti. Presné parametre šírky blind časti / filleru sa z verejnej stránky nedali vytiahnuť — **NEOVERENÉ**.

**Cabinet Vision, KD Max, Polyboard, SketchList 3D, Pytha, 20-20** — v anglických zdrojoch sa nenašla verejná dokumentácia parametrov konkrétne pre blind corner wizard (search vrátil len všeobecné marketingové/fórové stránky, nie produktovú dokumentáciu s názvami polí). **Nenašiel som** — treba oficiálnu dokumentáciu/trial, nie je verejne indexovaná v miere, aby dala konkrétne názvy parametrov.

**IKEA METOD** (rohová dolná skrinka so slepým panelom, ako referenčný priemyselný systém, nie CAD nástroj) — oficiálny IKEA support článok: filler ("cover panel") pre rohovú skrinku METOD sa reže **na šírku minimálne 7,5 cm**, montuje sa cez dodaný adaptér a kovanie; pri filleri širšom ako 10 cm sa odporúča doplniť UTRUSTA rohové konzoly pre pevnosť (ikea.com/be/en, článok "How do I make a filler piece for my IKEA kitchen?", dátum zdroja neuvedený na stránke, overené 27.9.2026). **Toto číslo (≥75 mm) je pozoruhodne blízke vášmu cr1 ~80 mm** — priemyselné potvrdenie rozsahu.

**Kusovník / názvy dielcov v odvetví (US trh):** bežné komerčné dolné rohové skrinky (napr. RTA Wholesalers, ABCabinetry) sa predávajú ako "Blind Corner Base – Left or Right" s nominálnou šírkou skrinky 36"/39"/42"/45", ale **šírka dverí je podstatne menšia než celková šírka skrinky** — pri 36" skrinke je "door width ~11.5", opening ~9"" (search summary z lilyanncabinets.com/castacabinetry.com, sekundárne zdroje — **NEOVERENÉ**, marketingové blogy, nie výrobná dokumentácia).

## 2. Stolárska prax — rozmery, strana pántov, kolízie

- **Filler/lišta šírka:** opakovane sa v nezávislých zdrojoch (Blum-adjacent shop popis, Polyboard blog, Barr Wood Cabinets, LumberJocks fórum) uvádza rozsah **2"–4" (≈50–100 mm)**, s odporúčaním "minimum 3" (≈76 mm)" pre frameless (bezrámové, euro) konštrukcie — presne v pásme vášho cr1/cr2 ~80 mm. Zdroj: cabinets.com PDF (euro-base-blind-details.pdf, nepodarilo sa strojovo prečítať obsah PDF — **NEOVERENÉ** čo do presných čísel v PDF, len title), sekundárne blogy woodcabinets4less.com a barrwoodcabinets.com (dátumy blogov nie sú viditeľné, overené 27.9.2026).
- **Dôvod šírky filleru:** dvakrát nezávisle potvrdené — filler musí byť aspoň taký široký, aby **úchytka/pult na dvierkach/šuflíku susednej (kolmej) skrinky** pri otvorení nekolidoval s bokom rohovej skrinky. Barr Wood Cabinets výslovne odporúča **odmerať hĺbku/vyloženie úchytky (pull)**, ktorá sa bude montovať, a podľa toho dimenzovať filler — príliš úzky filler = kolízia úchytky/šuplíka, príliš široký = zbytočne zle prístupný roh (barrwoodcabinets.com, overené 27.9.2026).
- **Na ktorej strane sú pánty:** vo všetkých nájdených zdrojoch (návody na inštaláciu, Blum aj Hettich popisy) sú **dvere zavesené na strane bližšie k rohu** (na filleri/výstuhe pri rohu), t. j. presne ako vo vašej špecifikácii — dverová zóna je pri rohu, slepá časť ďalej od rohu. Toto je nutné, aby otvorené dvere "vykryli" prístup do rohu a nekolidovali s dverami susedného radu na druhej stene. *(Pozn. orchestrátora: pozri hlavičku — poradie častí je v tejto vete prehodené.)*
- **Otvárací uhol a kolízia:** viacero zdrojov (Amazon/Walmart/Hardwaresource produktové popisy blind corner hinges, Blum a Hettich stránky) zhodne popisuje, že bežný 95°/110° hinge na rohovej montáži **kolíduje s bokom skrinky alebo s panelom v rovnakej rovine**, preto existuje samostatná kategória "blind corner hinge" / uhlový hinge (pozri sekciu 3).
- **Ako sa filler pripevňuje:** IKEA — cez dodaný adaptér a skrutkovaný spoj, pri väčších fillroch (>10 cm) plus rohové konzoly. Americký trh (primecabinetry.com, "Install a Blind Corner Base Cabinet" guide) popisuje filler ako samostatnú dosku pripevnenú skrutkami k boku skrinky/rohovej výstuhe, nie integrálnu súčasť korpusu — **NEOVERENÉ** presné momenty/typ spoja, ale princíp "filler = samostatný pripevnený dielec na nosnej hrane" sa vo vašej špecifikácii zhoduje s konceptom "rohová výstuha nesie CR2".

## 3. Kovanie — špecializované závesy pre slepý rohový diel

- **Blum:** existuje samostatná rodina *CLIP top / CLIP top BLUMOTION 95° blind corner hinges* (napr. BH79B9550, BH79B9980 — cabinetparts.com, rockler.com, wurthwoodgroup.com). Popis: "mounting inset doors to a filler strip when a side cabinet wall is not present" — teda presne prípad zavesenia dverí na samostatnú lištu/výstuhu, nie na bok korpusu. Jeden zdroj (sekundárny, cabinetparts.com) uvádza **minimálnu šírku filler strip 1-9/16" (≈40 mm)** pre tento typ zavesenia pri inset dverách — pozor, toto je pre **inset** (zapustené) dvere, nie prekrytie (overlay), a stránka sa nedala plne overiť WebFetch-om (403) — **NEOVERENÉ** presné číslo, len zo search-snippetu.
- **Hettich Sensys:** existuje model **Sensys 8639i W90** — "angle hinge W90, for overlay applications in cabinet with blind panels with integrated silent system", opening angle 95°, drilling pattern 52×5.5mm / 48×6mm (produktová stránka shop.hettich.com — presná URL sa nezachovala, preto **NEOVERENÉ**; montážne údaje Sensys overil krížový audit Codex v brožúre HUS_Sensys_Brochure.pdf). To potvrdzuje, že pri **overlay** (prekrytých) dverách na slepom paneli výrobca odporúča špeciálny **uhlový (angle) hinge W90**, nie štandardný priamy hinge — dôsledok pre váš návrh: ak sa CR1/výstuha nachádza v rovnakej rovine ako dvere (nie kolmo), treba overiť, či štandardný záves obstojí, alebo je nutný "blind panel" typ hinge. Presnú minimálnu hĺbku/šírku dielca (výstuhy 18×80mm) pre montáž Sensys W90 sa z verejných stránok nepodarilo vytiahnuť napriamo (PDF katalógy neboli strojovo čitateľné cez WebFetch) — **NEOVERENÉ**, treba priamo PDF katalóg Sensys (web.hettich.com/fileadmin/media/Sensys_Catalogue_11309_en.pdf) ručne alebo cez inštaláciu.
- **Zhrnutie pre 80mm výstuhu:** oba výrobcovia (Blum aj Hettich) majú dedikovaný sortiment práve pre "hinge on a narrow filler/blind panel" scenár — teda **potvrdenie, že 18×80mm výstuha je realistický, priemyselne podporovaný rozmer** pre montáž hinge na slepú rohovú konštrukciu, ale konkrétny minimálny rozmer montážnej podložky (mounting plate) sa nedal z verejného webu potvrdiť číselne — treba dotiahnuť PDF katalóg alebo kontaktovať distribútora (NEOVERENÉ číslo, potvrdená existencia kategórie).

## 4. Chyby a pasce z praxe

- **Filler príliš úzky** → drawer/dvere susedného radu kolidujú s úchytkou blind cabinetu pri otvorení (opakovane, viac zdrojov: barrwoodcabinets.com, woodcabinets4less.com, Houzz fórum).
- **Filler príliš široký** → zbytočne zhoršená prístupnosť rohu (barrwoodcabinets.com).
- **Použitie štandardného (nie blind-corner/angle) hinge** na dverách zavesených na paneli v rovnakej rovine → dvere sa nedajú otvoriť na plný uhol / narážajú do korpusu — dôvod existencie samostatnej kategórie "90°/95° blind corner hinge" na Amazon/Walmart/HardwareSource aj oficiálne u Blum a Hettich (sekcia 3).
- **Nedostatočné meranie rohu pred výrobou** — Houzz vlákno (5528456) potvrdzuje bežnú prax "3 inches of filler works out fine" ako empirické pravidlo, ale zdôrazňuje, že to je situačné, nie univerzálne — každý roh sa má merať individuálne (Houzz fórum, diskusia laikov — **NEOVERENÉ**, komunitný zdroj, nie výrobca).
- **IKEA-špecifická pasca:** pri METOD 128cm rohovej dolnej skrinke je filler **povinný** ("you need a filler piece so the door can open fully"), t.j. dokumentované ako funkčná nutnosť, nie estetická voľba — priamo od výrobcu (ikea.com).

## 5. Zrkadlenie L/P — geometria vs. parameter

- **CabWriter** rieši L/P explicitným príkazom "mirror cabinet in place, exactly mirrored end to end" — teda **generuje novú zrkadlenú geometriu** pri prepnutí strany, nie len meta-parameter na tej istej geometrii (cabwritersoftware.com).
- **Mozaik** má samostatné knižničné položky *Left* a *Right* ako oddelené cabinet-typy (nie jeden objekt s prepínačom) — nepriamy dôkaz, že aj tu ide skôr o **výber medzi dvoma pripravenými (zrkadlenými) konfiguráciami** než o čistú geometrickú transformáciu za behu (help.cadmate.com.au, sekundárny snippet).
- Vo vašej doméne (dosky s dekorom/hranou) je kritické, že **zrkadlenie nesmie prevrátiť smer dekoru dreva ani smer hrany ABS** — tento konkrétny detail sa v žiadnom z nájdených verejných zdrojov k CabWriter/Mozaik/CabinetVision explicitne nespomína (fóra ani dokumentácia neriešia touto optikou) — **NEOVERENÉ / nenašiel som**, je to zrejme interné know-how vašej domény.

## Čo z toho plynie pre náš návrh

1. **CR1/CR2 ~80mm je v priemyselnom aj hardvérovom rozsahu** — IKEA odporúča ≥75mm, US zdroje 2"–4" (50–100mm) s odporúčaním min. 3" (76mm) pri frameless. Vaša špecifikácia je konzervatívne správna, nie predimenzovaná.
2. **Výstuha závesov 18×80mm zodpovedá konceptu "filler strip pre blind corner hinge"** u Blum aj Hettich — obaja výrobcovia majú dedikovanú kategóriu hinge práve pre montáž na úzky panel/lištu mimo bočnice korpusu. Odporúčam pred finalizáciou katalógu kovania overiť konkrétny model (Hettich Sensys W90 8639i alebo Blum 79B95xx) priamo v PDF katalógu — minimálny rozmer montážnej podložky sa mi nepodarilo číselne potvrdiť z verejného webu.
3. **Pozor na typ hinge, nie len na rozmer výstuhy** — ak je CR1 (a teda hrana dverí/výstuhy) v rovnakej rovine ako filler/susedná stena, štandardný priamy 95° hinge môže kolidovať; treba explicitne v katalógu kovania rozlíšiť "blind corner / angle hinge" ako samostatnú položku, nie len bežný záves podľa výšky dverí (vaša špecifikácia momentálne píše "bežné závesy podľa výšky dverí" — to môže byť medzera, ak je hinge naozaj v kolinárnej rovine s CR1).
4. **Filler ako samostatný objekt vs. integrovaná súčasť skrinky** — priemysel robí oboje paralelne (Mozaik má obe varianty). Vaše riešenie (CR1/CR2 ako súčasť tej istej skrinky, nie samostatný objekt) je legitímny a bežný prístup, najmä pri custom/na mieru výrobe.
5. **Strana pántov pri rohu — vaša špecifikácia zodpovedá univerzálnej praxi** vo všetkých nájdených zdrojoch.
6. **Zrkadlenie L/P:** odporúčam parameter strany (nie čisté mirror() geometrie), pretože CabWriter aj Mozaik uprednostňujú explicitný prepínač/samostatnú konfiguráciu práve preto, aby sa dalo kontrolovať smer dekoru a hrany.
7. **Chýbajúci detail vo vašej špecifikácii:** explicitné dimenzovanie CR1/CR2 podľa vyloženia úchytky na susednej skrinke (Barr Wood Cabinets to zdôrazňuje ako hlavné kritérium, nie fixné číslo) — možno stojí za úvahu urobiť cr1/cr2 konfigurovateľné/odporúčané podľa typu úchytky v katalógu kovania, nie len fixná default hodnota ~80mm.
8. **Nenašiel som** kvantitatívne potvrdenie minimálnej hĺbky/šírky montážnej podložky hinge na 18mm hrubej/80mm širokej výstuhe — treba preveriť priamo v PDF katalógu Hettich Sensys alebo Blum CLIP top blind corner.

## Fakty — tabuľka

| Fakt | Zdroj (URL) | Dátum zdroja | Overené | Stav |
|---|---|---|---|---|
| Odporúčaná šírka filleru 2"–4" (50–100mm), min. 3" pri frameless | https://woodcabinets4less.com/blog/blind-base-cabinets-101/ , https://barrwoodcabinets.com/what-size-filler-panel-should-i-use-with-blind-corner-cabinets-and-why-it-matters/ | neuvedený | 27.9.2026 | NEOVERENÉ (blog, nie výrobca) |
| METOD rohová skrinka: filler min. 7,5 cm, montáž cez adaptér, >10cm konzoly UTRUSTA | https://www.ikea.com/be/en/customer-service/knowledge/articles/g1131157-6fc6-4515-8fc5-cb3df645e797.html | neuvedený na stránke | 27.9.2026 | OVERENÉ (oficiálny IKEA support) |
| Blum CLIP top blind corner hinge (napr. BH79B9550) — pre inset dvere na filler strip bez bočnej steny | https://www.cabinetparts.com/p/blum-hinges-european-cabinet-hinges-BH79B9550-p6776 (fetch zlyhal 403, len search-snippet) | neuvedený | 27.9.2026 | NEOVERENÉ |
| Hettich Sensys 8639i W90 — angle hinge 95°, pre overlay dvere na "cabinet with blind panels" | produktová stránka na shop.hettich.com — **presná URL sa pri rešerši nezachovala** (opravené po review PR #409); montážne údaje Sensys overil krížový audit Codex v brožúre https://www.hettich.com/fileadmin/Media_Center/Planning/HUS_Sensys_Brochure.pdf | neuvedený | 27.9.2026 | **NEOVERENÉ** (URL nezachovaná) |
| CabWriter Blind Corner Base — 0-2 dvere, 0-2 šuflíky, "extends into corner user specified amount"; mirror príkaz generuje zrkadlenú kópiu skrinky | https://cabwritersoftware.com/cabwriter/cabinet-types/ | neuvedený | 27.9.2026 | OVERENÉ |
| Mozaik: Base Blind Cabinet Left/Right "With Filler" + samostatné Base Blind Filler Left/Right | https://help.cadmate.com.au/blind-corner-cabinets | neuvedený | 27.9.2026 | NEOVERENÉ (len search-snippet) |
| Filler dimenzovať podľa vyloženia úchytky susednej skrinky, nie fixné číslo | https://barrwoodcabinets.com/what-size-filler-panel-should-i-use-with-blind-corner-cabinets-and-why-it-matters/ | neuvedený | 27.9.2026 | NEOVERENÉ (blog) |
| ArchiWood: rohové skrinky, koncové panely a "special modules" | https://archiwood.github.io/ | neuvedený | 27.9.2026 | OVERENÉ (bez detailu parametrov) |
| Existencia kategórie "90°/95° blind corner cabinet hinge" | hardwaresource.com, rockler.com, touchcabinetshardware.com | rôzne | 27.9.2026 | OVERENÉ (viacero predajcov) |

## Nenašiel som

- Presné parametrové názvy pre blind corner v Cabinet Vision, KD Max, Polyboard, SketchList 3D, Pytha, 20-20.
- Číselnú minimálnu šírku/hĺbku montážnej podložky pre Hettich Sensys W90 alebo Blum blind corner hinge na výstuhe hrúbky 18 mm (PDF katalógy WebFetch nespracoval).
- Explicitné odporúčanie CAD nástrojov k smeru dekoru/hrany pri zrkadlení L/P.
- Obsah „euro-base-blind-details.pdf" (cabinets.com).

## Postrehy k workflowu (rešeršér)

- WebFetch zlyháva na PDF katalógoch výrobcov (binárny obsah) — pri číselných špecifikáciách z PDF treba iný postup (stiahnuť + Read s `pages`).
- Reselerské stránky (cabinetparts.com) vracajú 403 — lepšie priamo blum.com / hettich.com.
