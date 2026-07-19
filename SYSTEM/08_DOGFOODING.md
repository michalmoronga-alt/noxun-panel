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

- **D-15 · UX vzor: „pridávačky" ako modal** (Michal 19.7.) — všetky akcie „pridať niečo" (šablóna, materiál, …) zjednotiť na modal s formulárom. Napĺňa sa postupne (prvý bude D-14; materiál formulár sa prerobí neskôr).

## Návrhy väčších celkov (na rozpracovanie)

- **D-18 · Čelo „BEZ" — otvorený priestor** (Michal 19.7. neskoro večer) — do riadkov čiel pridať typ „BEZ/NIE": pozícia zaberie výšku ako čelo, ale panel sa negeneruje = otvorená nika v rade čiel (medzery/presahy na to nestačia). **Premyslieť logiku pred kódom:** dopad na závesy (pásma čítajú čelá — BEZ nesmie generovať kovanie), auto-výšky (BEZ sa správa ako auto/fixed?), VEPO/kusovník (nič sa neexportuje), badge kovania, dvojkrídlové. Pozor, či „bez dielca" varianty z V0.4.8 (otvorené niky konštrukcie) nie sú príbuzná téma — riešiť koordinovane. *Stav: na rozbor + Codex audit logiky, potom dávka.*
- **D-19 · Orientačný prepočet na platne** (Michal 19.7.) — v okne Výroba k m² doplniť odhad počtu platní na materiál (plocha / plocha platne s koeficientom prerezu; NIE nárezové plány). *Stav: nápad na V0.5+ (po C/D).*
- **D-20 · Quick actions — bezpečný move plugin** (Michal 19.7., „pre budúceho Michala a Fable, keď bude základ top 😉") — zlúčiť funkčné pluginy noxun_mower + Snaper do jedného toolbar pluginu (rýchly pohyb, kopírovanie, rotácie, prisunutie na doraz). **Známy poznatok:** mower „rýchla kópia skrinky vedľa" vytvorí kópiu LEN ako geometriu — bez NOXUN identity kabinetu (kópia mimo observer/dedup flow). Pri stavbe quick actions kopírovanie prerobiť tak, aby kópia prešla štandardným dedup tickom (plná identita + config). *Stav: budúcnosť (po V1 / pri zostavách).*

- **D-09 · Snap body pri presúvaní priečok** (1/4, 1/2, 3/4…) v zónovom náhľade. *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-14 · Uložiť korpus do knižnice priamo z panela** (Michal 19.7.) — dnes sa šablóna ukladá v satelitnom okne Šablóny (nenájditeľné pri práci). Návrh: tlačidlo „★ Uložiť ako šablónu" dole vedľa „+ Vložiť ďalší korpus" → **modal** s názvom a potrebnými údajmi (prvý kus vzoru D-15). *Stav: dávka 5.*
- **D-16 · Autocomplete dekoru** (Michal 19.7.) — pri výbere materiálu/ABS písať názov z katalógu, návrhy sa dopĺňajú za každým písmenom, → a Enter potvrdí. *Stav: ODLOŽENÉ (Michal 19.7. večer — „nice to have"), v zásobe.*

## Otvorené otázky (na Michalovo posúdenie pri teste)

*(momentálne žiadne — D-08 default tab Korpus potvrdený 19.7. večer: „jednoznačne vyhovuje")*

## Vyriešené

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
