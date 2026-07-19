# Dogfooding zápisník (živý dokument)

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú dole do „Vyriešené" s odkazom na PR. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia).

## Blokery (bránia dokončeniu zákazky)

*(momentálne žiadne)*

## Spomaľovače (vysoká priorita)

*(momentálne žiadne)*

## UX drobnosti (nízka priorita)

*(momentálne žiadne)*

## Nápady na zváženie (nerozhodnuté)

*(momentálne žiadne)*

## Návrhy väčších celkov (na rozpracovanie)

- **D-09 · Snap body pri presúvaní priečok** (1/4, 1/2, 3/4…) v zónovom náhľade. *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*

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

- Výrazy v poliach: „650-36 → super, nemusím rátať z pamäti a preklikávať kalkulačku — bomba." Medzivýpočet 950-28=922 prehľadný, Enter potvrdenie sedí.
- Blokovanie nezmyselnej hrúbky materiálu (20 mm bez katalógového materiálu → červený blok) funguje.
- Police: vygenerovanie, presun dovnútra, ABS preklik aj S5 scale — bez problémov.
- UI: „začína pôsobiť veľmi konzistentne a zrozumiteľne — už to nie je zhluk, ale pre každé označenie jasné kroky."
