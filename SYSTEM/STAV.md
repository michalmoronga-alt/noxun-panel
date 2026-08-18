# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md).
> **Údržba:** pri uzávere dávky/etapy alebo zmene smeru sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide ako odsek do [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia.

## Stav

**v0.7.2 · 18.8.2026.** Etapa V0.6 (katalógy a ceny) je obsahovo splnená — plugin vie zákazku od návrhu cez materiály, ABS a kovanie až po VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku; upratovacia etapa U1–U4 uzavrela dokumentáciu a hygienu repa (checkpoint v0.6.0), blok ŠTART AUTONÓMIE (D-101 · D-86 · D-77, PR #162–#164) prebehol prvýkrát autonómne.

**Beží blok UI 2.0.** Koncept Inspectora je uzavretý (Michal 18.8.) — záväzný kontrakt a mockupy sú v repe: [zdroje/ui20/](zdroje/ui20/) ([UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md) + mockupy Inspector C, štúdio, dizajnový lístok); práca je narezaná do dávok UI-A → UI-B → UI-C → UI-D a fázy ŠTÚDIO ([PLAN.md](PLAN.md)).

Zákazka **KLINIKA** (254 dielcov) je postavená čisto z pluginu, prekontrolovaná a overená veľkým testom (porovnanie s ručným rozpočtom). Posledná zmena kódu: **UI-02** — plugin má vlastný SketchUp toolbar so 4 tlačidlami (logo · Štúdio · ABS kontrola · Vložiť) a firemná značka je prvýkrát vidieť priamo v SketchUpe. Testy: **1206 headless · 32 JS sád · in-SketchUp 334 PASS / 0 FAIL** (posledný beh pri D-101; UI dávky bez buildera/observera in-SU beh nepotrebujú — vizuál overuje Michal).

## Robí sa

**BLOK UI-A · základ značky.** Hotové **UI-01** (paleta + téma) a **UI-02** (logo + SketchUp toolbar), ďalej **UI-03** (zdieľaný combobox materiálov a ABS, D-85) — posledná dávka bloku.

## Ďalší krok

Po UI-A nasleduje **UI-B** (kostra Inspectora: rail + 4 sektory, náhľad, obsah Korpusu a koliesko s prepínačom témy). *(Štandard rozmerov okien D-51 sa rieši v UI-B1 a nadväzuje na D-77 — mechanika „okno sa pri otvorení dorovná na svoje minimum" už existuje, chýbajú len jednotné hodnoty.)*

## Posledné uzávery

- **UI-02 logo ikony + SketchUp toolbar** (toolbar „Noxun Engine": Inspector ako prepínač · Štúdio (dočasne okno Výroba) · ABS kontrola hrán ako prepínač · Vložiť skrinku) — PR **#166**, v0.7.2 (18.8.)
- **UI-01 paleta NOXUN teal + rádius 6 + mechanizmus témy Lucia** (prvá dávka bloku UI-A) — PR **#165**, v0.7.1 (18.8.)
- **BLOK ŠTART AUTONÓMIE UZAVRETÝ** (D-101 #162 · D-86 #163 · D-77 #164) — checkpoint **v0.7.0** (12.8.)
- **D-77 okná sa neotvárajú odseknuté** (väčšie východzie rozmery a minimá všetkých okien + dorovnanie zapamätanej veľkosti pri otvorení oboma smermi — nahor po minimum, nadol po plochu obrazovky) — PR **#164**, v0.7.0 (12.8.)
- **D-86 guard smeru dekoru vo vkladacej karte** (vedomá voľba prežije živý refresh katalógu z okna Materiály; pole sa mení len pri skutočnej zmene materiálu) — PR **#163**, v0.6.2 (12.8.)
- **D-101 panel po Späť/Znova** (Ctrl+Z aj Ctrl+Y obnovia Inspector sám — čisté čítanie bez nového kroku Späť, zlúčenie rýchlych vrátení) — PR **#162**, v0.6.1 (12.8.)
- **RETRO — workflow retrospektíva** (risk-based codex-audit, pravidlo 3 kôl, autonómne bloky s merge po bránach, denný report; blok ŠTART AUTONÓMIE predsunutý) — PR **#161** (12.8.)
- **ETAPA UPRATANIE UZAVRETÁ** (U1–U4, PR **#157–#160**) — checkpoint **v0.6.0** (11.8.)
- **U4 presuny a checkpoint** (premenovanie súborov na mená bez čísel, pôvodná vízia a návrh panela do archívu, ARCHIWOOD do zdrojov, README, bump v0.6.0) — PR **#160** (11.8.)
- **U3 diéta CLAUDE.md** (architektúra do vlastnej referencie [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md), tabuľka povinného čítania podľa typu zásahu) — PR **#159** (11.8.)
- **U2 čistka dogfooding zápisníka** (otvorené postrehy v skupinách podľa blokov, história do archívu, merač do zdrojov) — PR **#158** (11.8.)
- **U1 navigácia docs (STAV · PLAN · KRONIKA)** — PR **#157** (11.8.)
- **D-93 ručný zámok dĺžky výsuvu** — PR **#156**, v0.5.61 (11.8.)
- **Séria okolo zákazky KLINIKA** (D-90…D-105: úchytkový profil UKW-7, kovanie v paneli, živé názvy, farba ABS na hranách, kontrola hrán v modeli) — PR **#144–#155**, v0.5.49 → v0.5.60 (9.–11.8.)
- **Materiály 2.0 KOMPLET + dávky D a E** (identita dekorov, Demos konektor, sety kovania, rozpočet a cenová ponuka) — PR **#89–#140**, do v0.5.48 (30.7.–6.8.)

Plné texty všetkých uzáverov a starších etáp: [archiv/KRONIKA.md](archiv/KRONIKA.md).

## Kam sa pozrieť

| Keď riešiš… | Dokument |
|---|---|
| dátový kontrakt — dictionary, roly, identita, plán, mm Float | [STANDARD.md](STANDARD.md) |
| čo sa ide robiť, bloky prác, zaradenie D-čísel | [PLAN.md](PLAN.md) |
| otvorené postrehy z praxe (plné znenie D-čísel) | [DOGFOODING.md](DOGFOODING.md) |
| „prečo je X takto?" — história dávok, etáp a rozhodnutí | [archiv/KRONIKA.md](archiv/KRONIKA.md) · [archiv/](archiv/) |
| pojmy, stolárska doména, fakty o materiáloch a kovaní | [POJMY.md](POJMY.md) |
| pravidlá písania kódu — SketchUp / DC / UI dizajn | [../docs/SKETCHUP_PRAVIDLA.md](../docs/SKETCHUP_PRAVIDLA.md) · [../docs/DC_PRAVIDLA.md](../docs/DC_PRAVIDLA.md) · [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) |
| architektúra modulov (core / modules / ui) + invarianty | [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md) |
| workflow, verzie, uzáver dávky, testovanie, čo si pred zásahom prečítať | [../CLAUDE.md](../CLAUDE.md) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [V1_VIZIA.md](V1_VIZIA.md) |
| smer UI | [UI_VIZIA.md](UI_VIZIA.md) |
| kontrakt výstupu do VEPO | [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) |
| rešerše, prieskumy dodávateľov, seed podklady | [zdroje/](zdroje/) |
