# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md).
> **Údržba:** pri uzávere dávky/etapy alebo zmene smeru sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide ako odsek do [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia.

## Stav

**v0.5.61 · 11.8.2026.** Etapa V0.6 (katalógy a ceny) je obsahovo splnená — plugin vie zákazku od návrhu cez materiály, ABS a kovanie až po VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.

Zákazka **KLINIKA** (254 dielcov) je postavená čisto z pluginu, prekontrolovaná a overená veľkým testom (porovnanie s ručným rozpočtom). Posledná zmena kódu: **D-93** — ručný zámok nominálnej dĺžky výsuvu, PR **#156**. Testy: **1176 headless · 30 JS sád · 312 in-SketchUp scenárov**.

## Robí sa

**Upratovacia etapa U1–U4** — dokumentácia a hygiena repa pred veľkými etapami. Rozsah a poradie: [PLAN.md](PLAN.md), blok UPRATANIE. U1 (navigácia docs) je uzavretá — **aktuálna dávka = U2**.

- **U2 (nasleduje)** — čistka zápisníka [08_DOGFOODING.md](08_DOGFOODING.md) (otvorené D-čísla podľa blokov, história do archívu, merač do zdrojov).
- **U3** — diéta [../CLAUDE.md](../CLAUDE.md) + nová `docs/ARCHITEKTURA.md` + tabuľka povinného čítania.
- **U4** — presuny do archívu, premenovanie súborov na mená bez čísel, README, checkpoint verzie.

Dávky sa NEstackujú — každá štartuje z čerstvého `main` až po mergi predchodcu.

## Ďalší krok

Po upratovaní: **workflow retrospektíva** (samostatná session — pravidlá Michal ↔ Claude ↔ Codex, skilly, PR rytmus) → **UI 2.0** (debata → klikateľné wireframes/mockup vzorom Materiály 2.0 → až potom implementačné dávky).

## Posledné uzávery

- **U1 navigácia docs (STAV · PLAN · KRONIKA)** — PR **#157** (11.8.)
- **D-93 ručný zámok dĺžky výsuvu** — PR **#156**, v0.5.61 (11.8.)
- **Séria okolo zákazky KLINIKA** (D-90…D-105: úchytkový profil UKW-7, kovanie v paneli, živé názvy, farba ABS na hranách, kontrola hrán v modeli) — PR **#144–#155**, v0.5.49 → v0.5.60 (9.–11.8.)
- **Materiály 2.0 KOMPLET + dávky D a E** (identita dekorov, Demos konektor, sety kovania, rozpočet a cenová ponuka) — PR **#89–#140**, do v0.5.48 (30.7.–6.8.)

Plné texty všetkých uzáverov a starších etáp: [archiv/KRONIKA.md](archiv/KRONIKA.md).

## Kam sa pozrieť

| Keď riešiš… | Dokument |
|---|---|
| dátový kontrakt — dictionary, roly, identita, plán, mm Float | [01_STANDARD.md](01_STANDARD.md) |
| čo sa ide robiť, bloky prác, zaradenie D-čísel | [PLAN.md](PLAN.md) |
| otvorené postrehy z praxe (plné znenie D-čísel) | [08_DOGFOODING.md](08_DOGFOODING.md) |
| „prečo je X takto?" — história dávok, etáp a rozhodnutí | [archiv/KRONIKA.md](archiv/KRONIKA.md) · [archiv/](archiv/) |
| pojmy, stolárska doména, fakty o materiáloch a kovaní | [09_POJMY.md](09_POJMY.md) |
| pravidlá písania kódu — SketchUp / DC / UI dizajn | [../docs/SKETCHUP_PRAVIDLA.md](../docs/SKETCHUP_PRAVIDLA.md) · [../docs/DC_PRAVIDLA.md](../docs/DC_PRAVIDLA.md) · [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) |
| architektúra modulov (core / modules / ui) | [../CLAUDE.md](../CLAUDE.md) — sekcia „Architektúra" |
| workflow, verzie, uzáver dávky, testovanie | [../CLAUDE.md](../CLAUDE.md) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [10_V1_VIZIA.md](10_V1_VIZIA.md) |
| smer UI | [07_UI_VIZIA.md](07_UI_VIZIA.md) |
| kontrakt výstupu do VEPO | [03_VYSTUP_vepo_kontrakt.md](03_VYSTUP_vepo_kontrakt.md) |
| rešerše, prieskumy dodávateľov, seed podklady | [zdroje/](zdroje/) |
