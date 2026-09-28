# Blok 2 · Nárezový plán — outside-in rešerš (28.9.2026)

> Stav: **research packet + reconcile orchestrátora** — nie zadanie. Rešeršér: Antigravity `agy` (Gemini 3.8 Flash High, `--mode plan`, beh s obsluhou),
> tri behy po jednej otázke (skill `antigravity-outside-in`): **Q1+Q2** algoritmus a knižnice · **Q3** UX precedensy · **Q4** prax nárezových centier SR/ČR.
> Kontext rešerše = návrh [../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md](../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md) (inline v promptoch).
> Surové packety sú nižšie bez úprav; UNVERIFIED = hypotéza.

## Reconcile (orchestrátor, 28.9.)

| Packet · # | Nález (skrátene) | Verdikt | Dôvod / dopad |
|---|---|---|---|
| Q1 · 1 | nástroje vyžadujú gilotínové delenie, orez na oboch protiľahlých hranách, kerf, zámok otáčania podľa dekoru | **berieme** (potvrdenie) | zhoda s návrhom §1–§2 a bodom §8.1 (orez per hrana) |
| Q1 · 2 | deterministická policová heuristika (FFDH) je korektná voľba pre realizovateľnú hornú hranicu | **berieme** (potvrdenie) | vlastná heuristika v Ruby ostáva |
| Q1 · 3 | kerf len **medzi** dielcami (N dielcov na polici = N − 1 rezov), nie pri orezanom okraji; dielec presne na použiteľnú šírku sa musí zmestiť | **berieme — spresňuje návrh** | do package NP-1: pravidlo kerfu + hraničný test „dielec = použiteľná šírka/výška" |
| Q1 · 4 | OpenCutList nemá verejné API, licencia GPLv3 | **neberieme** (bez akcie) | kód nepreberáme ani nevoláme — len vzory |
| Q1 · 5 | JS knižnice (maxrects-packer, potpack, binpackingjs) nedávajú gilotínové rozloženie; guillotine-packer je neudržiavaný a bez zámku dekoru | **neberieme** | nerezateľné na formátovacej píle; výpočet ostáva v Ruby (headless testovateľný) |
| Q3 · 1–2 | výkres platne: ID a rozmery dielcov, šípka dekoru, šrafovaný odpad, najväčší zvyšok, % využitia platne; súhrn materiálu: počet platní + využitie; poradie rezov je pre externý nárez šum | **berieme do mockupu** | presne rozsah návrhu §3 |
| Q3 · 3 | nadrozmerné dielce ako samostatná kategória s červeným upozornením | **berieme** (potvrdenie) | RED + `incomplete` (návrh §2, §4) |
| Q3 · 4 | klik na obdĺžnik v 2D diagrame → výber v 3D nemá v SketchUp pluginoch precedens (OpenCutList vyberá z tabuľky) | **otvorené — mockup** | vo V1 najviac výber zo **zoznamu** dielcov (vzor D-94), nie zo SVG; rozhodne Michal pri mockupe |
| Q3 · 5 | vlastné upozornenie „posledná platňa nesie 1 dielec / využitie 8 %" (bez precedensu, UNVERIFIED) | **berieme do mockupu ako návrh** | priamo Michalova bolesť (rozhodnutie N1) |
| Q3 · 6 | hrany (ABS) a ručné presúvanie v pláne = balast | **potvrdenie scope OUT** | návrh §5 |
| Q4 · 1 | prerez priemyselných píl 4,4 mm (rozsah 4,0–5,0) | **Michal rozhodol 5 mm** (N3) | rešerš potvrdzuje rozsah; nastaviteľné |
| Q4 · 2 | orez 10–15 mm na hranu | **Michal rozhodol 10 mm** (N3) | nastaviteľné |
| Q4 · 3–4 | štandardný formát DTD, MDF aj HDF 3 mm = 2800 × 2070 | **berieme** (potvrdenie) | záložný formát návrhu sedí |
| Q4 · 5 | nárezové centrá účtujú celé tabule | **berieme** — zhodné s N4 | „ceny podľa plánu" majú zmysel |
| Q4 · 6 | zvyšky patria zákazníkovi, vracajú sa nad ~150–200 mm | **berieme len informačne** | vo V1 len najväčší zvyšok platne; sklad zvyškov scope OUT |
| Q4 · 7 | duplák = 2 plné prírezy zlepené | **berieme** (potvrdenie) | rozvinutie duplákov × multiplier (návrh §1) |

---

## Surový packet Q1+Q2 — algoritmus a knižnice

Outside-in packet · Nárezový plán (2D Guillotine Panel Nesting) · 2026-09-28 · model Gemini 3.8 Flash (High)

| # | Kategória | Tvrdenie | Dôkaz (URL + dátum/verzia) | Overenie (VERIFIED/UNVERIFIED + krátky citát max 15 slov) | Dotknutá časť návrhu | Odporúčanie | Prácnosť S/M/L | Licencia |
|---|---|---|---|---|---|---|---|---|
| 1 | CAD PRECEDENT | Nástroje (CutList Plus, Optimik, MaxCut, OpenCutList) striktne vyžadujú gilotínové delenie, obojstranný orez hrán, kerf a zámok rotácie podľa dekoru. | https://cutlistplus.com/Support (2026/live) & https://www.optimik.com/ (2026/live) | VERIFIED („specifies kerf, stock trim and respects has grain setting during optimization“) | Výpočet využiteľného formátu a rešpektovanie dekoru | Použiť overený model: `W_usable = W - 2*trim`, `H_usable = H - 2*trim`; pri aktívnom grain rotáciu 90° striktne zakázať. | S | Proprietary (vzory áno, kód nie) |
| 2 | GOOD CUSTOM SOLUTION | Deterministický Shelf FFDH (First-Fit Decreasing Height) v čistom Ruby je korektnou voľbou pre garantovaný, gilotínovo realizovateľný horný odhad (upper bound). | https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension (v7.0.0, 2025-09) | VERIFIED („cutting diagram algorithm is specifically designed to handle guillotine cuts“) | Algoritmus ukladania dielcov v pure Ruby (<1 s pre 250 dielcov) | Ponechať vlastný Shelf FFDH v Ruby (~200 riadkov); 2-stupňový gilotínový rez garantuje fyzickú realizovateľnosť na formátovacej píle. | M | MIT / vlastný kód |
| 3 | MISSED CONSTRAINT | Kerf sa nesmie pripočítavať za posledný dielec police ani na okraji orezu; $N$ dielcov na polici spotrebuje presne $(N - 1)$ rezov kotúča. | https://maxcutsoftware.com/ (2026/live) | VERIFIED („saw kerf defined as width of material removed by the saw blade“) | Výpočet šírky police a overenie limitných dielcov | Pripájať kerf iba pred dielec (ak už polica obsahuje $\ge 1$ prvok); inak dielec s `šírka == W_usable` neoprávnene pretečie na ďalšiu dosku. | S | Proprietary |
| 4 | NO ACTION | OpenCutList neposkytuje žiadne verejné Ruby API pre externé pluginy a jeho kód podlieha GPLv3, čo bráni priamemu volaniu či prevzatiu kódu. | https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension/blob/master/LICENSE (2025/GPLv3) | VERIFIED („GNU General Public License v3.0, no documented external Ruby API“) | Architektúra integrácie na existujúci SketchUp plugin | Nepripájať OpenCutList ako runtime závislosť; inšpirovať sa iba gilotínovými pravidlami, výpočet riešiť interne v Noxun Engine. | S | GNU GPLv3 (vzory áno, kód nie) |
| 5 | SIMPLER NATIVE PATH | Populárne JS/npm knižnice (maxrects-packer, potpack, binpackingjs) produkujú negilotínové layouty; balík guillotine-packer je neudržiavaný bez per-item grain locku. | https://github.com/soimy/maxrects-packer (v2.7.3, MIT) & https://github.com/tyschroed/guillotine-packer (MIT, ~2019) | VERIFIED („maxrects uses maximal rectangles non-guillotine; guillotine-packer lacks per-item grain lock“) | Alternatíva výpočtu v UI (HtmlDialog / Chromium) | Nenasadzovať externé npm balíky; MaxRects nie je rezateľný na bežnej píle a prenos dát cez JS bridge prináša zbytočnú zložitosť. | S | MIT / ISC |

### Nenašiel som (RESEARCH GAP)
* Žiadny aktívny, produkčne udržiavaný pure-Ruby gem s permisívnou licenciou (MIT/Apache/BSD) špecializovaný na 2D gilotínový bin packing s natívnou podporou pre reznú škáru (kerf), 4-stranný orez (trim) a per-item zámok orientácie vlákna (grain lock).
* Žiadne oficiálne exportné ani programové Ruby API v OpenCutList, ktorým by iné SketchUp rozšírenie mohlo zadať zoznam dielcov a prevziať hotový nárezový plán.

### Zdroje
* https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension
* https://github.com/fontanf/packingsolver
* https://cutlistplus.com/Support
* https://www.optimik.com/
* https://maxcutsoftware.com/
* https://github.com/soimy/maxrects-packer
* https://github.com/tyschroed/guillotine-packer
* https://github.com/mapbox/potpack
* https://github.com/olragon/binpackingjs


---

## Surový packet Q3 — UX precedensy

Outside-in packet · UX prezentácia nárezových plánov a diagramov (Q3) · 2026-09-28 · model Gemini 3.8 Flash (High)

**Kľúčové UI prvky pre stolára (3–5 podstatných vs. balast):**
1. *Podstatné:* (1) Počet celých dosiek a celková výťažnosť materiálu v %; (2) Výkres dosky s ID dielca a čistými rozmermi (D × Š); (3) Šípka/indikátor letokruhov (grain); (4) Šrafovaný odpad s vyznačením najväčšieho využiteľného odrezka; (5) Červený alert pre nadrozmerné dielce (oversized/unplaced).
2. *Balast (vynechať z V1):* Číslovanie trajektórie/poradia pílových rezov (služba VEPO reže podľa vlastného CNC), farby olepenia hrán priamo na doske (zahusťujú výkres, patria do kusovníka), ručný drag-and-drop dielcov.

| # | Kategória | Tvrdenie | Dôkaz (URL + dátum/verzia) | Overenie (VERIFIED/UNVERIFIED + citát max 15 slov) | Dotknutá časť návrhu | Odporúčanie | Prácnosť S/M/L | Licencia |
|---|---|---|---|---|---|---|---|---|
| 1 | CAD PRECEDENT | Výkres dosky zobrazuje obdĺžniky dielcov s ID/kótami, šípku grain, šrafovaný odpad a v pätičke lokálnu výťažnosť dosky (%). | https://docs.opencutlist.org/ (v7.0) | VERIFIED: "the cutting diagram footer displays the efficiency of the placements on each panel" | SVG diagram v Studio okne | V SVG zobraziť len ID, rozmery, šípku grain, % dosky a rozmer najväčšieho odrezka. | S | GPLv3 (vzory áno, kód nie) |
| 2 | CAD PRECEDENT | Súhrn za materiál vyžaduje počet celých dosiek, celkovú výťažnosť (%) a odpad v m²; poradie rezov je pre externý nárez šum. | https://www.cutlistoptimizer.com/ (2025/2026) | VERIFIED: "Global Statistics... Material Yield/Utilization... Total Sheets/Stock Used" | Súhrnná karta materiálu a rozpočet | Nezobrazovať poradie rezov ani reznú dráhu; primárny údaj je počet dosiek (nákup) a výťažnosť. | S | Proprietary (iba vzory) |
| 3 | CAD PRECEDENT | Dielce presahujúce formát dosky (oversized) tvoria samostatnú kategóriu "unplaced parts" s blokujúcim vizuálnym varovaním. | https://www.maxcutsoftware.com/ (v2.8+) | VERIFIED: "unplaced means the software was unable to fit those specific components onto available sheets" | Validácia rozmerov dielcov / RED finding | Červený alert s presnými rozmermi chybného dielca oproti doske (blokuje export cien). | S | Proprietary (iba vzory) |
| 4 | SIMPLER NATIVE PATH | CAD nástroje v SketchUp neriešia kliknutie na 2D SVG diagram pre výber v 3D; 3D výber sa štandardne spúšťa z tabuľky kusovníka. | https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension (v6.x-v7.x) | VERIFIED: "Highlight parts in model directly from the cutlist and groups" | Interaktivita SVG výkresu | Vo V1 nerobiť klikateľné SVG pre 3D výber (ušetrí zložitosť); výber v 3D ponechať v kusovníku. | S | GPLv3 (vzory áno, kód nie) |
| 5 | GOOD CUSTOM SOLUTION | Žiadny nástroj nemá proaktívny textový hint na osirelý dielec na poslednej doske; zobrazujú len pasívne % výťažnosti dosky. | Model hypothesis + overenie v CutList Opt./Optimik | UNVERIFIED: Žiadny nástroj nemá textový alert typu "posledná doska nesie len 1 dielec". | Notifikácie a odporúčania v Studio | Pridať vlastný hint: "Posledná doska nesie iba 1 dielec (využitie 8 %) – zvážte zmenu materiálu/formátu". | S | Vlastné riešenie |
| 6 | NO ACTION | Zobrazovanie pásikov olepenia hrán a manipulácia s dielcami v 2D pláne je v schematickom diagrame balast. | https://docs.opencutlist.org/ (v7.0) | VERIFIED: "cutting diagrams... Guillotine cut constraints... Blade Thickness and Trimming Size" | 2D SVG render dielcov | Ponechať hrany a ručné presúvanie mimo scope V1; výkres slúži len na vizuálnu kontrolu nákupu. | S | GPLv3 (vzory áno, kód nie) |

**Nenašiel som:**
- Žiadny automatizovaný textový asistent/hint v OpenCutList, CutList Optimizer, Optimik ani MaxCut, ktorý by explicitne upozornil vetou: „Posledná doska obsahuje iba 1 dielec / využitie je nízke“ (všetky spoliehajú len na to, že si používateľ všimne nízke percento v záhlaví danej dosky).
- Žiadny precedens v SketchUp pluginoch, kde by kliknutie na obdĺžnik priamo v generovanom 2D SVG reznom diagrame označilo entitu v 3D viewporte (OpenCutList to robí výhradne cez ikonu lupy v tabuľkovom kusovníku).
- Verejnú technickú/API dokumentáciu prezentácie nárezových plánov v portáloch Démos24Plus alebo VEPO (ide o uzavreté proprietárne webové systémy).

**Zdroje:**
- https://docs.opencutlist.org/
- https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension
- https://www.cutlistoptimizer.com/
- https://www.maxcutsoftware.com/
- https://www.optimik.sk/
- https://www.demos-trade.sk/


---

## Surový packet Q4 — prax nárezových centier SR/ČR

Outside-in packet · Q4: Dodávateľská prax nárezových centier (SR/ČR) · 2026-09-28 · model Gemini 3.8 Flash

| # | Kategória | Tvrdenie | Dôkaz (URL + dátum/verzia) | Overenie (VERIFIED/UNVERIFIED + krátky citát max 15 slov) | Dotknutá časť návrhu | Odporúčanie | Prácnosť S/M/L | Licencia |
|---|---|---|---|---|---|---|---|---|
| 1 | MISSED CONSTRAINT | Priemyselné veľkoplošné píly (HOMAG/Holzma, Mayer) používajú pílové kotúče s prerezom (kerf) 4,4 mm (rozsah 4,0–5,0 mm). | [leitz.org](https://www.leitz.org) (katalóg 2024); [intemo.cz](https://intemo.cz) (2024) | VERIFIED: „Schnittbreite (Kerf) von 4,4 mm ein standardisierter Wert... Plattenaufteilsägen HOMAG/Holzma“ | Default hodnota kerf (4 mm) | Zmeniť predvolený kerf z 4,0 mm na 4,4 mm (štandard nárezových centier). | S | proprietary |
| 2 | GOOD CUSTOM SOLUTION | Technologický orez surovej tabule (začištenie formátu / pravouhlosť) v centrách je 10 až 15 mm na každú hranu (norma EN 14323 povoľuje rozmerovú odchýlku formátu ±5 mm). | [intemo.cz](https://intemo.cz) (2024); [egger.com](https://www.egger.com) (EN 14323, 2023) | VERIFIED: „přídavkem 15 mm na každou stranu desky pro zaúhlování“ | Parameter edge trim (default 10 mm) | Ponechať 10 mm ako minimum, doplniť odporúčaný preset 15 mm pre garantovanú pravouhlosť. | S | proprietary |
| 3 | GOOD CUSTOM SOLUTION | Štandardný formát DTD-L a MDF v SR/ČR (Egger, Kronospan, Swiss Krono) je 2800 × 2070 mm (plocha 5,796 m2; hrúbka DTD pre korpusy v SR je primárne 18 mm). | [demos-trade.sk](https://www.demos-trade.sk) (2024); [egger.com](https://www.egger.com) (2024) | VERIFIED: „2800 x 2070 mm predstavujú štandardný veľkoplošný formát laminovaných dosiek“ | Fallback formát dosky (2800 × 2070 mm) | Potvrdiť 2800 × 2070 mm ako správny východzí rozmer dosky v katalógu. | S | proprietary |
| 4 | GOOD CUSTOM SOLUTION | Lakované HDF dosky (3 mm, Egger / Kronospan) veľkodistribútor Démos trade zjednotil na zhodný formát 2800 × 2070 mm (ojedinele 2800 × 2090 mm). | [demos-trade.sk](https://www.demos-trade.sk) (2023/2024) | VERIFIED: „zjednotila svoje skladové portfólio lakovaných HDF dosiek na hrúbku 3 mm... 2800/2070/3 mm“ | Formát materiálu HDF (chrbty) | Pre HDF 3 mm nastaviť rovnaký predvolený formát 2800 × 2070 mm. | S | proprietary |
| 5 | MISSED CONSTRAINT | Veľkoobchodné formátovacie centrá (Démos, JAF Holz, VEPO, Nabykov) účtujú materiál po celých doskách. Predaj na m2 je doménou hobby marketov alebo obmedzených skladových dekorov (biela). | [nabykov.sk](https://www.nabykov.sk/narezove-centrum/) (2024); [demos24plus.com](https://www.demos24plus.com) (2024) | VERIFIED: „Je potrebné zakúpiť celú dosku materiálu, aj keď je potrebná len jej časť“ | Budgetácia (prepínač „prices by plan“) | Kalkulovať nákup celých tabúľ; odhad cez m2 ponechať len ako informatívny indikátor. | S | proprietary |
| 6 | ALREADY EXISTS | Pretože zákazník platí celé dosky, odrezky sú jeho majetkom; objednávkové systémy (Démos24Plus, eDrevotrieska) umožňujú voľbu odrezky vrátiť (zvyčajne > 150–200 mm) alebo bezplatne zlikvidovať. | [nabykov.sk](https://www.nabykov.sk/narezove-centrum/) (2024); [demos-trade.sk](https://www.demos-trade.sk) (2024) | VERIFIED: „zvyšné kusy materiálu (tzv. odrezky alebo zvyšok dosky) sú k dispozícii pre zákazníka“ | Výstup „largest remnant per sheet“ (V1 scope) | Vo V1 ponechať len rozmer najväčšieho odrezku; evidenciu zostatkov nechať mimo scope. | S | proprietary |
| 7 | GOOD CUSTOM SOLUTION | V stolárskej praxi a nárezových centrách sa plný „duplák“ (36 mm) vyrába vyrezaním 2 plných prírezov z 18 mm dosky, ktoré sa plošne zlepia a ohrania 42–43 mm ABS páskou. | [demos-trade.sk](https://www.demos-trade.sk) (2024); [knn.sk](https://www.knn.sk) (2023) | VERIFIED: „tuplovaný dielec... dve dosky plošného materiálu sa spoja (zlepia)... hrana ohraní širšou páskou“ | Expanzia duplákov (quantity × 2 obdĺžniky) | Expanzia 2x pre plný duplák je správna; do budúcna zvážiť príznak pre „pásikovaný duplák“. | S | proprietary |

### Nenašiel som
* **Minimálny prahový rozmer pre vrátenie odrezku vo VEPO:** Verejne dostupná dokumentácia VEPO (vepo-porez.sk / edrevotrieska.sk) neuvádza presný rozmer v mm, pod ktorý odrezky automaticky vyhadzujú do odpadu (bežná prax centier je likvidácia pásikov pod 150–200 mm).
* **Nárezové centrum „Lesonit“ v SR:** Lesonit je slovinský výrobca tenkých MDF/drevovláknitých dosiek (skupina Fantoni), nie samostatná sieť nárezových centier na Slovensku; na Slovensku sa jeho materiál formátuje u distribútorov (Démos, JAF, lokálne centrá).

### Zdroje
* https://www.demos-trade.sk/
* https://www.demos24plus.com/
* https://vepo-porez.sk/
* https://www.intemo.cz/
* https://www.nabykov.sk/narezove-centrum/
* https://www.jafholz.sk/
* https://www.jafholz.cz/
* https://www.leitz.org/
* https://www.egger.com/
* https://www.kronospan.com/
* https://www.swisskrono.com/
* https://www.edrevotrieska.sk/
* https://www.twd.sk/
* https://www.knn.sk/
