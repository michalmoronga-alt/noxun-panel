# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.13.0 · 24.9.2026 — BLOK SPOTREBIČE S1 UZAVRETÝ** (E0 · A1 · A2 · E · B1 · B2 · F · C + smoke opravy A–C, PR #375–#389, uzáver #390): **katalóg spotrebičov**
s odkazmi, listami a prílohami · **spotrebič v zákazke** s vlastníkom (skrinka · slot umývačky · doska · len zákazka) a riadkom Spotrebič v Inspectore · **slot umývačky**
(prvý typ skrinky bez korpusu, čelo „Dv myčka" = výška linky − sokel − medzera hore) · **chladnička v skrinke** (box niky, Kontrola niky a delenia čiel, výška osadenia) ·
**očakávaný spotrebič** zo šablóny. Pod ním blok M-R VZHĽAD (v0.12.0) a dávky D-94 až D-135 (Nákup s pôvodom · výška dreveného boxu · Kresba čiel · dormantný zámok ·
rozsah zákazky pri hromadných zápisoch · **rework kontextu Čelá**).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **trinástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · **Spotrebiče** · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 18**, **doska v schéme 2**, šablóny v STD 6, výrobný plán v schéme 5 — starší plugin ich neprestaví. **Dáta rozpočtu sú
od S1-B1 v `BUDGET_STD` 2:** marker zapíše **prvá** mutácia rozpočtu akéhokoľvek druhu a starší plugin odvtedy zákazku needituje **a zastaví oba cenové exporty**.
Pred takou zákazkou aktualizovať **obe PC**.

**Testy (posledná kódová dávka, smoke oprava C #389):** **4545 headless · 129 JS sád · 3081 in-SU PASS / 0 FAIL**. **B2 (#388):** 4520 · 128 · 3049. **B1:** 4509 · 127 · 3039.
**S1-C:** 4499 · 127 · 3036. **S1-F:** 4452 · 126 · 2989. **S1-B1:** 4369 · 124 · 2935. **D-130b:** 4155 · 120 · 2779. **M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md)).
**Michal 11.9. potvrdil** test produktových odkazov aj potvrdzovania cien (CENY-KOV-A/B, #345/#346) **a** kontrolu balíka Čiel v0.11.0.

## Robí sa

**Michalov smoke bloku S1 pokračuje** (od 21.9.2026; checklist po aktualizácii v [archiv/S1_ZAVER_2026-09-24.md](archiv/S1_ZAVER_2026-09-24.md)) — nálezy **D-136 až D-140**
sú opravené (#386–#389), **D-141** a **D-142** čakajú v zásobníku; nové nálezy sa zapíšu do [DOGFOODING.md](DOGFOODING.md) (skupina SPOTREBIČE S1) a opravia ako v0.13.x.
**Tiež čakajú na smoke: D-134** (#369), **D-133** (#368), **D-132** (#367), **D-131** (#365) a **D-128** (#364). **D-94** (#361) aj **M-R** (#353–#359) sú hotové a Michal
12.9. potvrdil oba smoke **PASS**; D-28 vyriešené, Čelá A/B1/B2/C používateľsky potvrdené. **Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**.

## Ďalší krok

**Ďalší blok vyberá Michal** ([PLAN.md](PLAN.md); cieľ V1 v [V1_VIZIA.md](V1_VIZIA.md) — odškrtnuté sú už Materiály a Spotrebiče). Plán pred S1 počítal po ňom
s blokom **K1–K3** (konštrukcia: odsadenia, chrbát z výstuh, rohová skrinka) a **cenami materiálov/ABS** (zvyšok V1-03). Nálezy z výroby a cien majú prednosť.

## Posledné uzávery

- **BLOK SPOTREBIČE S1 UZAVRETÝ** (v0.12.9 → **v0.13.0**, 20.–24.9.2026, PR #375–#389 + uzáver #390). Katalóg spotrebičov, spotrebič v zákazke s obojsmernou väzbou
  (jeden krok Späť), slot umývačky, telo chladničky s Kontrolou niky a delenia čiel, očakávaný spotrebič; smoke opravy D-136 až D-140 (výška osadenia chladničky = schéma 18).
  [Plný blok](archiv/ROADMAP_hotove_etapy.md) · [výsledok, dávky a checklist](archiv/S1_ZAVER_2026-09-24.md) · priebeh v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **REWORK KONTEXTU ČELÁ** — **D-130b** skupina „Spoločné pre skrinku" (materiál čiel + schéma medzier, zámok a reset ako ikony v hlavičke; v0.12.7 → **v0.12.8**, #372)
  a **D-130a** nový zoznam čiel + karta s tabmi + úchytka na jednom mieste (v0.12.6 → **v0.12.7**, #371). **D-129 aj D-130 vyriešené** — [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **D-134** jednotný rozsah hromadných zápisov zákazky — spoločný `Panel.job_cabinets`, skrinka s odpojeným dielcom sa **preskočí a vymenuje** (→ **v0.12.6**, #369) ·
  **D-133** „Nahradiť UNI…" má rozsah výstupov a blokuje pri odpojenom dielci (→ **v0.12.5**, #368) · **D-132** dormantný zámok osi zásuvky je viditeľný a dá sa zrušiť
  (→ **v0.12.4**, #367) · **D-131** Kresba čiel jedným klikom (→ **v0.12.3**, #365) · **D-128** ručná výška dreveného boxu (→ **v0.12.2**, #364, `CONFIG_SCHEMA` 13 → 14) · **D-94** Nákup s pôvodom (→ **v0.12.1**, #361) — plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359). Spoločná knižnica dosiek/ABS, natívny editor, fyzické UV, zachovanie pri prestavbe/kópii a ovládanie v Štúdiu. D-28 vyriešené; [plný blok](archiv/ROADMAP_hotove_etapy.md).
- **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR #277–#340). Klasifikované sety a katalóg s editorom · **zásuvka z nemenného receptu** (Atira,
  Quadro V6) so zámkami osí · **závesy** podľa Noxun tabuľky · **výklopy AVENTOS HK/HL top** · **nohy 4/6 + príchyt sokla** · šablóny aj s kovaním · ad-hoc kovanie ·
  114 katalógových kódov (D-118) · updater (D-52). Otvorené ostáva **D-109** (R-05 po V1). Detail v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **Staršie uzávery** (v0.9.58–v0.9.61 **KOV-G**/**KOV-I** · v0.9.53–v0.9.57 **KOV-E** + fixy #335/#336 · v0.9.48–v0.9.52 **KOV-F** · v0.9.47 **KOV-W** · v0.9.43–v0.9.46
  **D-118**/**D-121** · v0.9.29–v0.9.42 **KOV-C/KOV-D** · v0.9.19–v0.9.26 **KOV-B** · v0.9.16–v0.9.21 **KOV-A**/**KOV-H** · v0.9.14 **D-52** · v0.9.24–v0.9.28 **NÁSTROJE-1**
  a **GHOST-D1/D2** · v0.9.22 D-112/D-113 · v0.9.0 **GHOST VKLADANIE** · v0.8.0 **fáza ŠTÚDIO** · staršie až po V0.1) — [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

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
