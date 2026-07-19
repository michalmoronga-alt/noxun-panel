# Dogfooding zápisník (živý dokument)

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú dole do „Vyriešené" s odkazom na PR. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia).

## Blokery (bránia dokončeniu zákazky)

*(momentálne žiadne)*

## Spomaľovače (vysoká priorita)

- **D-17 · BUG: sokel o 36 mm kratší ako skrinka** (Michal 19.7. večer) — soklový panel sa stavia medzi boky (`šírka − 2×hrúbka`); výrobný štandard = plná šírka skrinky, lícuje s bokmi. *Stav: fix v dávke 4.*
- **D-12 · Zoom náhľadu pri scrollovaní panela** — čistý scroll nad náhľadom nechtiac zoomuje pri scrollovaní pluginu. Riešenie: **Ctrl+koliesko = zoom**, čistý scroll = scroll panela (štandard máp/CAD; hint to napíše). *Stav: dávka 4.*

## UX drobnosti (nízka priorita)

- **D-11 · Kóty sokla a tela + pole Výška sokla** — do kótovaného náhľadu Korpus pridať vľavo kóty výšky sokla a výšky tela korpusu; pole „Výška podstavca" presunúť do Základných. *Stav: dávka 4.*
- **D-13 · Default zapustenia sokla 40 mm** — soklový panel predvolene 40 mm od prednej hrany (uľahčí neskoršie výpočty — nohy pod prednou hranou); doteraz 50. Nové skrinky; existujúce bez zmeny. *Stav: dávka 4.*

## Nápady na zváženie (nerozhodnuté)

- **D-15 · UX vzor: „pridávačky" ako modal** (Michal 19.7.) — všetky akcie „pridať niečo" (šablóna, materiál, …) zjednotiť na modal s formulárom. Napĺňa sa postupne (prvý bude D-14; materiál formulár sa prerobí neskôr).

## Návrhy väčších celkov (na rozpracovanie)

- **D-09 · Snap body pri presúvaní priečok** (1/4, 1/2, 3/4…) v zónovom náhľade. *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-14 · Uložiť korpus do knižnice priamo z panela** (Michal 19.7.) — dnes sa šablóna ukladá v satelitnom okne Šablóny (nenájditeľné pri práci). Návrh: tlačidlo „★ Uložiť ako šablónu" dole vedľa „+ Vložiť ďalší korpus" → **modal** s názvom a potrebnými údajmi (prvý kus vzoru D-15). *Stav: dávka 5.*
- **D-16 · Autocomplete dekoru** (Michal 19.7.) — pri výbere materiálu/ABS písať názov z katalógu, návrhy sa dopĺňajú za každým písmenom, → a Enter potvrdí. *Stav: dávka 5.*

## Otvorené otázky (na Michalovo posúdenie pri teste)

- **D-08 vs D-03:** karta Zóna jednozónovej skrinky sa ukáže až v tabe Zóny (predvolený tab je Korpus). Ak bude chýbať hneď pri označení, možnosť: novo vložená skrinka štartuje v tabe Zóny.

## Vyriešené

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

- Výrazy v poliach: „650-36 → super, nemusím rátať z pamäti a preklikávať kalkulačku — bomba." Medzivýpočet 950-28=922 prehľadný, Enter potvrdenie sedí.
- Blokovanie nezmyselnej hrúbky materiálu (20 mm bez katalógového materiálu → červený blok) funguje.
- Police: vygenerovanie, presun dovnútra, ABS preklik aj S5 scale — bez problémov.
- UI: „začína pôsobiť veľmi konzistentne a zrozumiteľne — už to nie je zhluk, ale pre každé označenie jasné kroky."
