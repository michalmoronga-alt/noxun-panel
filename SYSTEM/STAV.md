# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.14.1 · 28.9.2026 — BLOK 8 · K3 ROHOVÁ SKRINKA beží: ROH-A1 jadro rohovej** (PR #?). Plugin pozná nový typ **„Rohová"** (`corner_blind`) — dolnú slepú
rohovú skrinku podľa DC „Rohová": korpus ako dolná + rohová zostava na prednej rovine (**blenda korpusová**, **výstuha závesov**, **CR 1**, **CR 2**, **rohová
výstuha**), dvere vľavo aj vpravo (zrkadlo), jedny dvierka s pántmi predvolene pri rohu, vnútri len police. Ide do **kusovníka, VEPO, nákupu aj ponuky** (CR z čelového
materiálu s ABS dookola, nohy 6 pri 1100, závesy podľa výšky dverí). **Tlačidlo „Rohová" a náhľad ešte nie sú** — prinesie ich **ROH-A2**; rohová v otvorenom modeli je
editovateľná bežnými riadkami Inspectora a chránená serverom (typ ani stranu nezmeníš, čelá ostanú jedny dvierka, zóny sa nedelia).
Pod tým **blok 7 · KONŠTRUKCIA K1+K2** (v0.14.0, smoke **PASS 27.9.**, delenie čiel Chladničkovej 719 / 1274 potvrdené) a blok **SPOTREBIČE S1** (v0.13.0, smoke PASS 26.9.).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **trinástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · **Spotrebiče** · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
V1 ciele **Materiály, Kovanie, Spotrebiče a Dvaja používatelia** sú odškrtnuté ([V1_VIZIA.md](V1_VIZIA.md)); pri **Konštrukcii** (bod 2) sú K1 a K2 hotové, **K3 rohová skrinka beží** (blok 8).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.10.0) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) · **blok KONŠTRUKCIA K1+K2** (v0.14.0) — plné texty
v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 22** (ROH-A1: typ `corner_blind`), **doska v schéme 2**, **šablóny v STD 7**, výrobný plán v **schéme 7**, ABS pravidlá
v **seede 6** — starší plugin zákazku neprestaví ani nevyexportuje (rohovú by sklopil na dolnú). **Dáta rozpočtu sú od S1-B1 v `BUDGET_STD` 2** (starší plugin zákazku
po prvej mutácii rozpočtu needituje a zastaví oba cenové exporty). **Aktualizovať OBE PC (aj Luciino) pred prvou rohovou** — starší plugin rohovú nepozná a knižnicu
šablón STD 7 len číta (nedá sa v nej ukladať, premenovať ani mazať).

**Testy (posledná kódová dávka, ROH-A1 #?):** **4688 headless · 135 JS sád · 3208 in-SU PASS / 0 FAIL**. KON-D (#404): 4643 · 134 · 3172. KON-B (#403): 4621 · 133 · 3158.
**M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md)).

## Robí sa

**Blok 8 · K3 ROHOVÁ SKRINKA** ([PLAN.md](PLAN.md), priečinok [zdroje/bloky/ROHOVA/](zdroje/bloky/ROHOVA/)): ✅ **ROH-A1** jadro → **ROH-A2** vkladanie a náhľad
(tlačidlo „Rohová", dvere a pánty v náhľade v dverovej časti) → **ROH-B** ovládače (dverová časť, CR lišty, prepínač strany) po Michalovom schválení mockupu.
Návrhy na potvrdenie (mockup ROH-B): rozsahy dverovej časti a CR, názvy dielcov a VEPO skratky, predvolená konštrukcia (ako dolná vs. DC), výrez police × výstuha
závesov ako ORANGE. **Smoke rohovej** sa robí spolu s ROH-A2 (vrátane skúšky závesu Sensys na výstuhe závesov v dielni).
**Čakajú na smoke:** **D-132** (#367), **D-133** (#368), **D-134** (#369). **D-141**, **D-142** a **D-145** sú v zásobníku. **Blok 1d** podľa kapacity — R-18; **R-13 čaká na Michala**.

## Ďalší krok

**ROH-A2** z čerstvého `main` po mergi ROH-A1. **Aktualizovať plugin na oboch PC** (Michal aj Lucia) pred prvou rohovou. Po bloku 8 vyberá ďalší blok Michal
([PLAN.md](PLAN.md)) — kandidáti: **ceny materiálov/ABS** a viac URL na položke (zvyšok V1-03) · **nárezový plán primitívny** · **V1.0 zostavy** · blok 1d.
Nálezy z výroby a cien majú prednosť.

## Posledné uzávery

- **BLOK 7 · KONŠTRUKCIA K1+K2 UZAVRETÝ** (v0.13.0 → **v0.14.0**, 26.–27.9.2026, PR #401–#404 + uzáver PR #405; smoke **PASS 27.9.**). Chrbát v drážke do nárezu v plnom
  rozmere, komín vzadu a zapustený strop, oprava D-144, chrbát z líšt, šablóna Chladničková; priečinok bloku je od uzáveru v [archiv/bloky/KONSTRUKCIA/](archiv/bloky/KONSTRUKCIA/).
  [Plný blok](archiv/ROADMAP_hotove_etapy.md) · [výsledok, dávky a checklist](archiv/KONSTRUKCIA_ZAVER_2026-09-27.md) · priebeh v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK SPOTREBIČE S1 UZAVRETÝ** (v0.12.9 → **v0.13.0**, 20.–24.9.2026, PR #375–#389 + uzáver #390; smoke PASS 26.9.). Katalóg spotrebičov, spotrebič v zákazke,
  slot umývačky, telo chladničky s Kontrolou niky a delenia čiel, očakávaný spotrebič; smoke opravy D-136 až D-140.
  [Výsledok, dávky a checklist](archiv/S1_ZAVER_2026-09-24.md).
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
