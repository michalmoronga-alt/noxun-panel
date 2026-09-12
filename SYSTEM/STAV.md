# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.12.1 · 12.9.2026 — M-R VZHĽAD KOMPLET, nad ním dávka D-94 „Nákup s pôvodom".** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu;
nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340 — plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md)).
**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo).
**Kompatibilita:** konfigurácia skrinky ostáva v schéme 13, výrobný plán v schéme 5. Nový voliteľný vzhľad používa katalógovú schému 10 až pri prvom uložení; staré katalógy sa otvorením nemenia. Plugin podporujúci schému nižšiu než 13 nové konfigurácie neprestaví ani nepoužije ako šablónu.
Pred prvou takou zákazkou aktualizovať **obe PC** (Štúdio → O plugine → Aktualizovať).

**Testy uzáveru Čiel:** **3830 headless · 113 JS sád**, skutočný Inspector pri 470 px: šesť typov, jedna karta, klávesnica, pevná výška/AUTO, hrany a potvrdenie návrhu.
**D-94:** **3993 headless · 115 JS sád · 2632 in-SketchUp PASS / 0 FAIL** (z toho 26 nových kontrol sekcie `run_d94`: resolver, deep-link, 0 krokov Späť).
**M-R:** **3983 headless · 114 JS sád · 2606 in-SketchUp PASS / 0 FAIL**. Skutočné CEF Štúdia **18 PASS**; konečný controller → uloženie/otvorenie bez SKM → prestavba → výroba **50 PASS**.
Dosky 18/25 mm, ABS, skrinka a cudzí zdieľaný dielec; textúra, mierka, UV, presné živé materiály aj kusovník/VEPO ostali zachované. Samostatná živá zmena mierky bez Apply/rebuildu: **11 PASS**.
Pracovné SKM/PBR/pixely, Undo/Redo, rollback a D-40 prešli v jednotlivých dávkach. [Plná evidencia a smoke](archiv/MR_ZAVER_2026-09-12.md); fyzický druhý PC, SU 2024 a render netestované.
Geometrický dôkaz ČELÁ-B2: **in-SketchUp 2297 PASS / 0 FAIL** (osadenia, výroba/rezy, šablóny, uloženie/návrat, Scale/Späť a kópia); C geometriu nemení. Ručné Redo zostáva.
**Michal 11.9. potvrdil úspešný test produktových odkazov aj potvrdzovania cien** (CENY-KOV-A/B, PR #345/#346).
**Michal 11.9. potvrdil aj používateľskú kontrolu hotového balíka Čiel v0.11.0: funguje, bez nájdených chýb.** Samostatné ručné Redo nebolo výslovne potvrdené.

## Robí sa

**D-94 „Nákup s pôvodom" je hotové (PR #361, v0.12.1).** Riadok v sekcii Nákup kovania sa rozklikne na pôvod **zoskupený po skrinkách** (jeden riadok na skrinku s počtom kusov
a za ním položky s ľudským názvom vlastníka); **klik na skrinku aj na čelo označí kus v modeli a zdvihne Inspector**, pri čele sa otvorí jeho karta. Rozklik **prežije „Obnoviť"**
aj prestavbu. Výstup zákazky (CSV, rozpočet, ponuka) sa nemení ani o znak. **Čaká používateľský smoke Michala.**
**M-R je dokončené v #353–#359, uzáver v0.12.0** — Michal 12.9. potvrdil jeho smoke **PASS**; D-28 vyriešené, Čelá A/B1/B2/C zostávajú používateľsky potvrdené.
**Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**. Blok **1b** je uzavretý, **1c/1e hotové**.

## Ďalší krok

**Ďalší blok vyberá Michal** — automaticky sa nič neštartuje; po uzávere M-R mala nasledovať slovná diskusia o workflow. Skupina „KONTROLA + VÝROBA" v
[DOGFOODING.md](DOGFOODING.md) je po D-94 prázdna. Budúca rotácia obrázka a umiestnenie textúr sú D-126/D-127 v [PLAN.md](PLAN.md); D-48 zostáva po V1,
**D-109** (pomerová mechanika kovania, R-05) po V1 a ručné Redo Čiel je stále samostatne nepotvrdené.

## Posledné uzávery

- **D-94 · Nákup s pôvodom** (v0.12.0 → **v0.12.1**, 12.9.2026, PR #361). Rozklik nákupného riadku po skrinkách, klik-select zdroja s deep-linkom na kartu čela, pamäť rozkliku
  podľa identity riadku + regresný strážca invariantu „súčet zdrojov = počet riadku". Zvyšok package z 30.8. (tvar `sources`, popis vlastníka) priniesli už KOV-H2/KOV-D4.
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359). Spoločná knižnica dosiek/ABS, natívny editor, fyzické UV, zachovanie pri prestavbe/kópii a ovládanie v Štúdiu. D-28 vyriešené; [plný blok](archiv/ROADMAP_hotove_etapy.md).
- **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR #277–#340). **Čo plugin odteraz vie:** sety a katalógové položky sú **klasifikované**
  (typ použitia · otváranie · konštrukcia · výrobca · rada), katalóg má strom Kategória → Výrobca → Rada a set sa upravuje v editore so **živým náhľadom** ·
  **zásuvka vzniká z nemenného receptu** (Atira, Quadro V6) — dielce, výška, NL a nosnosť drží recept, **objednávacie kódy set** (dve vrstvy, §6); žiadny tichý fallback na inú NL;
  os sa dá zamknúť a recept povýšiť · **závesy** podľa Noxun tabuľky, Tip-On vlastný set · **výklopy AVENTOS HK top / HL top** podľa výšky a **hmotnosti čela**
  (hmotnosť dielcov aj skrinky je v Inspectore) · **nohy 4/6 podľa šírky korpusu + príchyt sokla**, vetou v Základných **už pri vkladaní** · **šablóny vedia uložiť
  aj kovanie** (voľba + súhrn na dlaždici) · **ad-hoc kovanie** priamo v Inspectore · katalóg pozná **kódy, ktoré si plugin sám objednáva** (114 položiek D-118
  + AXILO/STRONG) · **updater** „Aktualizovať jedným klikom" (D-52) — vstupná podmienka celého bloku. Vyriešené postrehy: D-52 · D-110 · D-111 · D-115 · D-116 ·
  D-118 · D-121 · D-125. D-114/D-119/D-120 uzavrel balík Čiel (v0.11.0); otvorené ostáva **D-109** (pomerová mechanika = R-05 po V1). Detail v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **Staršie uzávery** (v0.9.58–v0.9.61 **KOV-G** nohy a príchyty + **KOV-I** šablóny · v0.9.53–v0.9.57 **KOV-E** výklopy + fixy #335/#336 · v0.9.48–v0.9.52 **KOV-F** závesy ·
  v0.9.47 **KOV-W** hmotnosť · v0.9.43–v0.9.46 **D-118** katalógový seed a **D-121** názvy dielcov + VEPO ≤ 20 znakov · v0.9.29–v0.9.42 **KOV-C/KOV-D** recepty zásuviek a ich
  ovládanie · v0.9.19–v0.9.26 **KOV-B** sety a katalóg · v0.9.16–v0.9.21 **KOV-A** typy čiel a smery + **KOV-H** ad-hoc kovanie · v0.9.14 **D-52** updater · v0.9.24–v0.9.28
  **NÁSTROJE-1** a **GHOST-D1/D2** · v0.9.22 výstupy D-112/D-113 · v0.9.0 uzáver bloku **GHOST VKLADANIE** · v0.8.0 uzáver **fázy ŠTÚDIO** · staršie etapy až po V0.1)
  — plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

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
