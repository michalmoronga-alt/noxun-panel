# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.13.4 · 27.9.2026 — BEŽÍ BLOK 7 · KONŠTRUKCIA K1+K2; hotové všetky štyri dávky — KON-0 (#401), KON-A (#402), KON-B (#403) a KON-D** (PR #404).
V Štúdiu (Šablóny) aj pri vkladaní pribudla vstavaná šablóna **„Chladničková"**: vysoká skriňa **600 × 2100 × 560**, sokel 100, **komín 50** (dno a strop 510,
boky 560), **bez chrbta**, očakáva chladničku, **dve dvierka nad sebou — dolné 719, horné 1274** so smerom otvárania **neurčený** (Kontrola vyzve zvoliť stranu
pántov). Nika chladničky sa meria z hĺbky boku (560); vnútro na výšku 1964 → po priradení chladničky Beko treba **výšku osadenia 14–24 mm**. Delenie 719 / 1274
je **návrh na potvrdenie pri smoke**. Dlaždica šablóny ukazuje **„komín vzadu 50"** (súhrn komína, zapustenia a líšt — len keď niečo z toho má) a tooltip vetu
o vetraní. **Knižnica šablón je v STD 7** — migrácia pridá Chladničkovú raz, vlastnú rovnomennú šablónu neprepíše, zmazanú nevráti a poškodený súbor šablón
**migrácia neprepíše** (prvé uloženie šablóny ho však nahradí obsahom zálohy — vedomá hranica, `docs/architecture/model-a-identita.md`). Pod tým KON-B (v0.13.3),
KON-A (v0.13.2), KON-0 (v0.13.1), blok **SPOTREBIČE S1** (v0.13.0, smoke **PASS 26.9.**).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **trinástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · **Spotrebiče** · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
V1 ciele **Materiály, Kovanie, Spotrebiče a Dvaja používatelia** sú odškrtnuté ([V1_VIZIA.md](V1_VIZIA.md)); Konštrukcia (bod 2) je rozpracovaná blokom 7.

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 21** (KON-B), **doska v schéme 2**, **šablóny v STD 7** (KON-D), výrobný plán v schéme 6, ABS pravidlá v seede 5 — starší plugin
zákazku neprestaví ani nevyexportuje. **Dáta rozpočtu sú od S1-B1 v `BUDGET_STD` 2** (starší plugin zákazku po prvej mutácii rozpočtu needituje a zastaví oba cenové exporty).
**Aktualizovať OBE PC (aj Luciino)** — starší plugin „Z líšt" nepozná (prestavbou by vrátil dosku chrbta, samostatnú lištu by vo VEPO vydal pod plným názvom) a knižnicu šablón STD 7 len číta (nedá sa v nej
ukladať, premenovať ani mazať).

**Testy (posledná kódová dávka, KON-D #404):** **4643 headless · 134 JS sád · 3172 in-SU PASS / 0 FAIL**. KON-B (#403): 4621 · 133 · 3158. KON-A (#402): 4600 · 132 · 3136.
**KON-0 (#401):** 4577 · 131 · 3111. **S1-C:** 4499 · 127 · 3036. **M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md)).

## Robí sa

**Blok 7 · KONŠTRUKCIA K1+K2** ([PLAN.md](PLAN.md), priečinok [zdroje/bloky/KONSTRUKCIA/](zdroje/bloky/KONSTRUKCIA/)) — všetky štyri dávky hotové;
nasleduje **uzáver bloku** (vetva `release/`, minor verzia **v0.14.0** + smoke checklist bloku).
**Čakajú na smoke:** **KON-0** (#401), **KON-A** (#402), **KON-B** (#403), **KON-D** (#404), **D-132** (#367), **D-133** (#368), **D-134** (#369). **D-141**, **D-142** a **D-145** sú v zásobníku.
**Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**.

## Ďalší krok

**Smoke KON-D (Michal, v0.13.4):** (1) Štúdio → Šablóny: dlaždica **„Chladničková"** — „dolná · 600×2100×560", **„komín vzadu 50"**, „očakáva chladničku";
tooltip s vetou o vetraní; ostatné dlaždice bez zmeny · (2) vlož ju (Inspector → Šablóna → Všetky šablóny): dno a strop 510, boky 560, **bez chrbta**, dve dvierka
(dolné 719, horné 1274); Kontrola: „očakáva chladničku" a **neurčený smer otvárania** — zvoľ stranu pántov · (3) priraď chladničku Beko: hĺbka niky 560 sedí,
výška hlási oranžovú, kým nenastavíš **výšku osadenia 14–24 mm** — **potvrď, či delenie 719 / 1274 sedí na vašu prax** (ak nie, povedz iné čísla) ·
(4) tooltip šablóny pri vkladaní: „komín vzadu 50" a veta o vetraní · (5) aktualizuj plugin aj u Lucie (knižnica šablón 7).
Smoke KON-B (v0.13.3), KON-A (v0.13.2) a KON-0 (v0.13.1) platia ďalej ([archiv/KRONIKA.md](archiv/KRONIKA.md)). Potom **uzáver bloku 7**.

## Posledné uzávery

- **KON-D** (v0.13.3 → **v0.13.4**, 27.9.2026, PR #404) — vstavaná šablóna Chladničková, knižnica šablón STD 7 (migrácia len nad zdravým primárom), súhrn
  konštrukcie na dlaždici šablóny. Plné znenie v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KON-B · K2** (**v0.13.3**, PR #403) — chrbát z dvoch líšt, jeden riadok „Chrb HD", `CONFIG_SCHEMA` 21, BuildPlan 6, ABS seed 5 · **KON-A · K1** (**v0.13.2**,
  PR #402) — komín vzadu a zapustenie stropu, nika z hĺbky boku, oprava D-144, `CONFIG_SCHEMA` 20 · **KON-0 · D-143** (**v0.13.1**, PR #401) — chrbát v drážke
  do nárezu v plnom rozmere, zastarané skrinky, `CONFIG_SCHEMA` 19 (všetko 27.9.2026).
- **BLOK SPOTREBIČE S1 UZAVRETÝ** (v0.12.9 → **v0.13.0**, 20.–24.9.2026, PR #375–#389 + uzáver #390; smoke PASS 26.9.). Katalóg spotrebičov, spotrebič v zákazke,
  slot umývačky, telo chladničky s Kontrolou niky a delenia čiel, očakávaný spotrebič; smoke opravy D-136 až D-140.
  [Plný blok](archiv/ROADMAP_hotove_etapy.md) · [výsledok, dávky a checklist](archiv/S1_ZAVER_2026-09-24.md) · priebeh v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **REWORK KONTEXTU ČELÁ** — **D-130b** (v0.12.8, #372) a **D-130a** (v0.12.7, #371) · **D-134** jednotný rozsah hromadných zápisov (v0.12.6, #369) ·
  **D-133** „Nahradiť UNI…" (v0.12.5, #368) · **D-132** dormantný zámok (v0.12.4, #367) · **D-131** Kresba čiel (v0.12.3, #365) — plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359) · **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR
  #277–#340; otvorené ostáva **D-109**, R-05 po V1) · **staršie uzávery** (v0.9.x až V0.1) — [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

## Kam sa pozrieť

| Keď riešiš… | Dokument |
|---|---|
| ktorý dokument je autorita na čo (mapa `SYSTEM/`) | [README.md](README.md) |
| dátový kontrakt — dictionary, roly, identita, plán, mm Float | [STANDARD.md](STANDARD.md) |
| čo sa ide robiť, bloky prác, zaradenie D-čísel | [PLAN.md](PLAN.md) |
| otvorené postrehy z praxe (plné znenie D-čísel) | [DOGFOODING.md](DOGFOODING.md) |
| „prečo je X takto?" — história dávok, etáp a rozhodnutí | [archiv/KRONIKA.md](archiv/KRONIKA.md) · [archiv/](archiv/) |
| plné texty hotových blokov a etáp (vrátane KOVANIA) | [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md) |
| pojmy, stolárska doména, fakty o materiáloch a kovaní | [POJMY.md](POJMY.md) |
| pravidlá písania kódu — SketchUp / DC / UI dizajn | [../docs/SKETCHUP_PRAVIDLA.md](../docs/SKETCHUP_PRAVIDLA.md) · [../docs/DC_PRAVIDLA.md](../docs/DC_PRAVIDLA.md) · [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) |
| architektúra modulov (core / modules / ui) + invarianty | rozcestník [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md) → mapa v [../docs/architecture/](../docs/architecture/) |
| workflow, verzie, uzáver dávky, testovanie | [../CLAUDE.md](../CLAUDE.md) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [V1_VIZIA.md](V1_VIZIA.md) |
| kontrakt výstupu do VEPO | [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) |
| rešerše, koncepty, prieskumy dodávateľov (nezáväzné) | [zdroje/](zdroje/) |
