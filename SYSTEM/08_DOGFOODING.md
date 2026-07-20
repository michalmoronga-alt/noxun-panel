# Dogfooding zápisník (živý dokument)

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú dole do „Vyriešené" s odkazom na PR. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia).

## Blokery (bránia dokončeniu zákazky)

*(momentálne žiadne)*

## Spomaľovače (vysoká priorita)

- **D-30 · Nadnože/výstuhy bez defaultnej ABS** (smoke test 20.7., B1) — `abs_rules` má pre roly `rail_front`/`rail_back` prázdne pravidlo (vedomé v V0.3, komentár v kóde). Michal: každá výstuha má mať default aspoň 1 čelnú pozdĺžnu 1,0 mm z materiálu (v teste ich olepoval ručne — export ich už má). *Fix: default pravidlo pre obe rail roly; existujúce korpusy cez seed-merge NEprepisovať, len nové.*
- **D-31 · Chýba „skrinka bez chrbta"** (smoke test 20.7., B2) — overené v kóde: `back_mode` má len overlay/inset/groove, `none` neexistuje. Blokuje reálny use-case (otvorené regály a pod.). *Fix: back_mode `none` = žiadny BACK dielec, vnútro po zadnú stenu (ako overlay); UI option v sekcii Chrbát. Koncepčne predsunutý kúsok V0.4.8 „bez dielca".*
- **D-32 · Nový korpus preberá nastavenia posledného editovaného** (smoke test 20.7., B3) — diagnóza z kódu: NIE je to Ruby cache/singleton — `insertCabinet()` vkladá AKTUÁLNY obsah formulára (`collectAll()` + `currentZoneTree`), a formulár po označení korpusu A drží hodnoty A (zóny aj čelá). „Vlož ďalší" = kópia naposledy zobrazeného. Je to aj feature (rýchle množenie rovnakých skriniek — používané), aj pasca (nečakané dedenie). *Návrh na rozhodnutie: vkladacia karta dostane viditeľný prepínač zdroja — „z defaultov typu / kópia označeného / zo šablóny" — žiadne tiché dedenie.*
- **D-33 · Šablóna nepreberá rozmery / polia držia staré hodnoty** (smoke test 20.7., B4) — rovnaký root cause ako D-32 (formulár sa pri výbere šablóny prepíše len čiastočne). Príklad: po chladničke 2500×600 šablóna „skriňa+šuflík" natiahla staré rozmery. *Rieši sa spolu s D-32 (definovať, ktoré polia šablóna VŽDY nastavuje).*
- **D-34 · Panel „visí" na zmazanej skrinke** (smoke test 20.7., B5) — po Delete skrinky panel ďalej zobrazuje jej dáta; ESC/cancel nefunguje, treba prekliknúť inam. *Fix: observer zmazania/deselection → clearSelected + mode-insert; overiť prečo onSelectionCleared po Delete nechodí.*

## UX drobnosti (nízka priorita)

- **D-29 · Hlavička panela — reorganizácia** (smoke test 20.7., A1) — názov pluginu + verziu presunúť dole/do nastavení; hore fixný sticky obsah relevantný pre aktuálny kontext (označený korpus), viditeľný aj pri scrollovaní. *Stav: návrh, stredná priorita.*

## Nápady na zváženie (nerozhodnuté)

- **D-15 · UX vzor: „pridávačky" ako modal** (Michal 19.7.) — všetky akcie „pridať niečo" (šablóna, materiál, …) zjednotiť na modal s formulárom. Napĺňa sa postupne (prvý bude D-14; materiál formulár sa prerobí neskôr).
- **D-26 · Režim Jednoduchý/Rozšírený** (Michal 19.7. večer, debata) — prepínač v UI: jednoduchý = najčastejšie polia, rozšírený = všetko (tvorba šablón, špeciálne zostavy). Rozhodnuté MIESTO samostatného okna Nastavenia (nastavenie ostáva pri svojom poli). *Stav: čaká na dáta z merača D-25 (čo reálne skrývať) — pár týždňov zberu.*
- **D-27 · Rýchle zobraziť/skryť tagy z panela** (Michal 19.7. večer) — mini prepínače priamo v paneli (Čelá 👁 · Chrbát 👁 …) v logike Ghost checkboxu, nech sa nepreklikáva do SketchUp Tags. *Stav: zápis bokom, kandidát na budúcu UX dávku.*
- **D-28 · Textúry materiálov (render)** (Michal 19.7. večer) — katalóg rozšíriť o textúru (obrázok dekoru) + mierku rapportu; builder ich aplikuje pri rebuilde → model pripravený na render (Lucia). Fáza 2: orientácia textúry podľa smeru dekoru dielca. Michal má kompletnú knižnicu textúr; **injecting dát (kódy, materiály, kovania, spotrebiče, vybavenie) príde v dávkach po uzavretí V1** — dovtedy pripraviť architektúru. *Stav: zaradené po V0.6.*
- **D-35 · ABS — olepiť všetky 4 hrany jedným klikom** (smoke test 20.7., C1) — tlačidlo v ABS editore dielca (a karte dosky). *Stav: malý UX kúsok, kandidát do najbližšej dávky.*
- **D-36 · ABS — logická väzba na materiál** (smoke test 20.7., C2) — pri výbere materiálu dielca ponúknuť „odporúčanú" ABS k dekoru navrchu zoznamu / jedným klikom (v ~95 % sa používa jedna konkrétna hrana k materiálu). So škálovaním katalógu plochý zoznam neobstojí. *Poznámka: párovanie dekorov už robí abs_rules (ABS s rovnakým dekorom ako materiál) — využiť; súvisí s D-16 autocomplete. Priorita rastie s počtom materiálov.*

## Návrhy väčších celkov (na rozpracovanie)

- **D-20 · Quick actions — bezpečný move plugin** (Michal 19.7., „pre budúceho Michala a Fable, keď bude základ top 😉") — zlúčiť funkčné pluginy noxun_mower + Snaper do jedného toolbar pluginu (rýchly pohyb, kopírovanie, rotácie, prisunutie na doraz). **Známy poznatok:** mower „rýchla kópia skrinky vedľa" vytvorí kópiu LEN ako geometriu — bez NOXUN identity kabinetu (kópia mimo observer/dedup flow). Pri stavbe quick actions kopírovanie prerobiť tak, aby kópia prešla štandardným dedup tickom (plná identita + config). *Stav: budúcnosť (po V1 / pri zostavách).*

- **D-09 · Snap body pri presúvaní priečok** (1/4, 1/2, 3/4…) v zónovom náhľade. *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-14 · Uložiť korpus do knižnice priamo z panela** (Michal 19.7.) — dnes sa šablóna ukladá v satelitnom okne Šablóny (nenájditeľné pri práci). Návrh: tlačidlo „★ Uložiť ako šablónu" dole vedľa „+ Vložiť ďalší korpus" → **modal** s názvom a potrebnými údajmi (prvý kus vzoru D-15). *Stav: dávka 5.*
- **D-16 · Autocomplete dekoru** (Michal 19.7.) — pri výbere materiálu/ABS písať názov z katalógu, návrhy sa dopĺňajú za každým písmenom, → a Enter potvrdí. *Stav: ODLOŽENÉ (Michal 19.7. večer — „nice to have"), v zásobe.*

## Otvorené otázky (na Michalovo posúdenie pri teste)

- **Z porovnania VEPO exportov (test 8, 20.7.):** (a) polica v Engine vychádza o 8 mm plytšia než v starej DC kuchyni (prírez 499 vs 507) — ktorá hĺbka police je správna? (b) spodné boky v Engine o 2 mm vyššie (746 vs 744) — sedí výška tela/sokla? (c) stará kuchyňa olepovala aj PRIEČNE hrany dna a stropu (kód `=`), Engine defaulty nie — chceš ich do defaultov? (d) korpusové šírky majú systematicky −2 mm v starom exporte — vyzerá na 2 mm ABS v starej vs 1 mm v Engine defaultoch — ktorá hrúbka je tvoj štandard na korpus?

## Smoke test 20.7. — výsledok (testy 1–11)

Testy 1–7, 9, 11: **PASS** · test 10 merač: **PASS** (súbor sa plní, len prvky+počty, žiadne hodnoty) · test 8 = porovnanie VEPO exportov Engine vs. OCL+vepo_exporter na zrkadlovej kuchyni: **26 = 26 dielcov, materiálové skupiny sedia** (1 bok v inom materiáli = známy Michalov rozdiel). Formát CSV byte-kompatibilný. Rozdiely: systematické ABS delty (viď otázky vyššie), škárové rozdiely na čelách (staré defaulty vs. Engine 3/2), orientation swap pri dekore `none` (výrobne neškodné), **stará linka NEodpočítavala ABS z 36 mm dosky (1618×600) — Engine odpočítava správne (1616×598)**, 1 nespárovaný pomocný dielec v každom teste (rôzne krycie prvky). Bonus: starý vepo_exporter má bug v názve LOGu (`LOG_#{proj}.txt` — neinterpolované). Nálezy A1/B1–B5/C1/C2 zapísané ako **D-29 až D-36**.

## Vyriešené

- **D-18 · Čelo „BEZ"** → **vyriešené v nočnej fronte 19.→20.7. (PR #52)**: typ riadku „Bez čela" — drží výšku v rade ako čelo (fixed aj auto, locky), panel sa negeneruje = otvorená nika. Rozhodnutia z debaty 19.7.: pásmo ako čelo (reálny otvor = pásmo + susedné škáry, žiadna špeciálna vetva); kovanie nevznikne (štrukturálne — pravidlá iterujú dielce plánu, dokázané testami + prune mŕtvych hardware_overridov); kusovník/VEPO nič; náhľad čiarkovaný obrys s výškou; voľba krídel sa skryje; oddelené od V0.4.8 konštrukčných ník. 70/0 SU scenárov.
- **D-19 · Orientačný prepočet na platne** → **vyriešené (PR #53)**: tab Materiály okna Výroba — stĺpce Formát a Platne (odhad) ako rozsah 10–25 % prerezu („4,5 – 5,5"); formát platne per materiál v katalógu (editor materiálov, default 2800×2070). **Stabilný základ:** výpočet dostáva jednotlivé dielce → budúci nárezový prepočet (fáza 2: guillotine, kerf, orezky, orientácia dekoru — inšpirácia OpenCutList algoritmami, kód GPL neprebrať) vymení len vnútro. 
- **D-21 · Výrazy vo výškach čiel** → **bez kódu — UŽ EXISTOVALO**: výšky čiel majú výrazy od V0.4.7e, medzery/presahy od D-07. Zistené pri príprave dávky 20.7.
- **D-22 · Odomykateľný limit presahov** → **vyriešené (PR #54)**: 🔒/🔓 v riadku medzier — default ±100 mm ostáva, odomknutie per korpus povolí ±2000 (obklady/pilastre); stav v configu aj šablónach, pod echo-guardom; backend autorita.
- **D-23 · Orientácia v riadkoch čiel** → **vyriešené (PR #55)**: zoznam čiel zobrazený ako skrinka pred tebou (najvyššie čelo hore, F1 ostáva spodné); prázdne auto pole ukazuje sivú dopočítanú výšku „≈ 358"; hover/klik sync riadok↔náhľad (klik na čelo v náhľade otvorí sekciu a fokusne výšku); F-čísla v náhľade.
- **D-24 · Krídla dvierok do 4** → **vyriešené (PR #54)**: voľba krídel 1/2/3/4/auto (3 bežné, 4 zriedka — Michal); `auto` NEMENENÉ (1/2 podľa šírky 600). Identita dielcov byte-stabilná (staré skrinky nedotknuté; nové kľúče wing:p1..p4), závesy per krídlo automaticky (3 krídla = 3× závesy), UI kovania číta nové kľúče.
- **D-25 · Merač používania panela** → **vyriešené (PR #50)**: lokálne počítadlá prvkov Inspectora (len ID prvkov a počty — nikdy hodnoty), `%APPDATA%\NOXUN\Engine\usage_stats.json`, flush 30 s, zámok proti dvom SketchUpom. Podklad pre D-26; report na vyžiadanie („ukáž merač").
- **D-17 · Sokel o 36 mm kratší** → **vyriešené v dávke 4 (PR #45)**: plná šírka skrinky, lícuje s bokmi; výnimka „dno medzi bokmi" (boky na zem) — sokel ostáva medzi nimi (kolíziu chytil Codex audit ako blocker). Predný rad proxy nôh sa kreslí za soklom.
- **D-13 · Default zapustenia sokla** → **vyriešené v dávke 4 (PR #45)**: 40 mm pre nové skrinky aj seed šablóny; existujúce korpusy a legacy šablóny chránené (fallback 50 ostáva).
- **D-12 · Zoom pri scrollovaní panela** → **vyriešené v dávke 4 (PR #45)**: zoom len Ctrl+koliesko, čistý scroll scrolluje panel; hint aktualizovaný.
- **D-11 · Kóty sokla/tela + pole** → **vyriešené v dávke 4 (PR #45)**: kóty vľavo v tabe Korpus (len keď sokel existuje); Výška sokla v Základných, pri hornej sa skrýva.
- **D-08 · Režimové taby Inspectora** → **vyriešené v dávke 3 (PR #43)**: taby Korpus · Zóny · Čelá = režimy práce — prepínajú náhľad AJ sekcie. Korpus (default) = kótovaný obrys (Š/V/hĺbka) + Základné/Strop/Dno/Boky/Chrbát/Kovanie/Materiály; Zóny = zónový náhľad + ghost checkbox + karta Zóna + strom; Čelá = náhľad čiel + riadky + medzery/presahy. Tab sa pamätá cez zmeny výberu; dielec vynúti zónový náhľad (klik na zónu = odchod z dielca) a po návrate sa tab obnoví; prepnutie tabu = čistý fit. Čelá na drafte pred vložením ostávajú hláškou (vedomé). Codex audit 0 blockerov / 6 fixov; DOM smoke test PASS.
- **D-07 · Medzery/presahy čiel** → **vyriešené v dávke „noc na 19.7." (PR #41)**: sekcia Čelá má polia *Medzi čelami / Okraj hore / dole / po stranách* (+ Reset 3/2 mm); záporný okraj = presah cez obrys korpusu (limity 0–50 / ±100 mm); výrazy fungujú; šablóny hodnoty ukladajú; medzera dvojkrídlových poslúcha nastavenie (bola natvrdo) a náhľad ich kreslí ako 2 panely; fit náhľadu zahrnie presahy. Sémantika: čelá sa kladú odspodu — „Okraj hore" posúva geometriu cez AUTO čelo, pri samých pevných výškach je rezervou (vysvetlené v hinte).
- **D-03 · Police sa hľadajú ťažko** → **vyriešené (PR #42)**: jednozónová skrinka zobrazí kartu Zóna rovno pri označení (auto-výber, náhľad zvýrazní); hint pod náhľadom spomína police; vysvetlenie v akordeóne Štruktúra zón; karta Zóna sa už neplietie do režimu Čelá. (Pôvodne evidované ako falošný poplach + nápady — nápady zrealizované.)
- **D-05 · Vlastný materiál sa nedá pridať** → **vyriešené v dávke 2 (PR #39)**: okno Materiály projektu = plná správa katalógu — pridať/upraviť/zmazať doskový materiál aj ABS pásku; ID generuje server (transliterácia, kolízie -2/-3); **hrúbka existujúceho materiálu je nemenná** (iná hrúbka = nový variant); mazanie s guardom — PROTECTED_SHEET_IDS (fallbacky) + scan použitia v modeli, overridoch, dielcoch, doskách aj šablónach; živý sync do panela bez resetu formulára. Michal: „materiál editor je bomba."
- **D-06 · Scale úchopy fungujú opačne** → **vyriešené v dávke 1 (PR #38)**: `scaletool` maska 7→**120** (roviny+rohy skryté, čisté osi X/Y/Z ostávajú) + zápis aj na definíciu (odstránený rozdiel prvý/druhý beh).
- **D-02 · Náhľad prepočítava pri každom písmene** → **vyriešené v dávke 1 (PR #38)**: debounce prekreslenia náhľadu 500 ms; výrazy ostávajú na Enter.
- **D-01 · Náhľad je malý** → **vyriešené v dávke 1 (PR #38)** variantom (a): náhľad rastie s veľkosťou okna panela (clamp 38 % výšky okna). Varianty (b) satelitný veľký náhľad / (c) nastaviteľná výška ostávajú v zálohe, ak to nebude stačiť.
- **D-04 · Ghost zóny zavadzajú** → **vyriešené v dávke 1 (PR #38)** variantom (a): ghosty predvolene VYPNUTÉ (aj novo vzniknutý tag je neviditeľný); klik na zóny primárne cez 2D náhľad; checkbox „Zobraziť zóny" na zapnutie ostáva.

## Postrehy, ktoré potešili (nechávame tak)

- D-08 taby (19.7.): „na prvý pohľad je to omnoho prehľadnejšie."
- **Prvá zákazka dokončená BEZ blokov (19.7.)** — vrátane pridania vlastného materiálu a celého workflow: „zatiaľ super."
- **Okno Výroba (19.7. neskoro večer): „kusovník funguje tip top — nenašiel som chyby, funguje aj preklikávanie na diely."** Bonus: pri klik-selecte okamžite vidno olepenie v 2D náhľade panela = rýchla orientácia a kontrola ABS. Po posledných úpravách žiadne blockery ani bugy; viac menších zákaziek — „začína to byť funkčné a použiteľné."

- Výrazy v poliach: „650-36 → super, nemusím rátať z pamäti a preklikávať kalkulačku — bomba." Medzivýpočet 950-28=922 prehľadný, Enter potvrdenie sedí.
- Blokovanie nezmyselnej hrúbky materiálu (20 mm bez katalógového materiálu → červený blok) funguje.
- Police: vygenerovanie, presun dovnútra, ABS preklik aj S5 scale — bez problémov.
- UI: „začína pôsobiť veľmi konzistentne a zrozumiteľne — už to nie je zhluk, ale pre každé označenie jasné kroky."
