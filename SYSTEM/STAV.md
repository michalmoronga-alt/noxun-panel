# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.12.6 · 13.9.2026 — M-R VZHĽAD KOMPLET, nad ním šesť fixov D-94 až D-134** (Nákup s pôvodom · výška dreveného boxu · Kresba čiel · dormantný zámok · rozsah zákazky pri „Nahradiť UNI" aj pri hromadných zápisoch). Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu;
nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340 — plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md)).
**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo).
**Kompatibilita:** konfigurácia skrinky je od D-128 v **schéme 14**, výrobný plán v schéme 5; vzhľad používa katalógovú schému 10 až pri prvom uložení. Starší plugin nové konfigurácie neprestaví — pred takou zákazkou aktualizovať **obe PC**.

**D-134 (najnovšie):** **4128 headless · 118 JS sád · 2745 in-SketchUp PASS / 0 FAIL** (nová sekcia `run_d134`: zákazka A + B s odpojeným dielcom + vnorená C — A sa prestaví, B sa preskočí a vymenuje, C ostane nedotknutá, projektový zápis prebehne aj pri 0 joboch, 1 krok Späť).
**D-133:** 4111 · 118 · 2717 PASS / 0 FAIL. **D-132:** 4095 · 118 · 2705 PASS / 0 FAIL. **D-131:** 4080 · 117 · 2693 PASS / 0 FAIL. **D-128:** 4029 · 116 · 2658 PASS / 0 FAIL. **D-94:** 3993 · 115 · 2632 PASS / 0 FAIL.
**M-R:** 3983 headless · 114 JS sád · 2606 in-SketchUp PASS / 0 FAIL; CEF Štúdia **18 PASS**, controller → uloženie/otvorenie bez SKM → prestavba → výroba **50 PASS**, živá zmena mierky bez Apply **11 PASS** ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md); fyzický druhý PC, SU 2024 a render netestované). Ručné Redo Čiel zostáva nepotvrdené.
**Michal 11.9. potvrdil** test produktových odkazov aj potvrdzovania cien (CENY-KOV-A/B, PR #345/#346) **a** používateľskú kontrolu balíka Čiel v0.11.0 (funguje, bez chýb).

## Robí sa

**D-134 „Jednotný rozsah hromadných zápisov zákazky" je hotové (PR #369, v0.12.6) — čaká na smoke.** Uloženie **pravidiel kovania**, zmena **projektovej predvoľby materiálu**
aj **„aj na podobné v projekte"** pracujú s tou istou zákazkou ako kusovník: vnorená skrinka v cudzom komponente sa už neprestavuje a skrinka s **odpojeným dielcom** sa **preskočí a vymenuje** v statuse, kým nastavenie projektu sa uloží. Bežná zákazka sa správa ako doteraz.
**Tiež čakajú na smoke: D-133** (zámena UNI vidí top-level zákazku a odpojený dielec ju blokuje; PR #368), **D-132** (riadok „Dormantný zámok · NL 470" v Kovaní s dôvodom a tlačidlom „zrušiť"; PR #367), **D-131** (riadok „Kresba čiel" v Štúdiu otočí kresbu všetkých čiel zákazky v jednej operácii; PR #365) a **D-128** (tretí chip osi „box 360",
dielce boxu sa režú na zámok, zmenšená zóna = RED s náhradou; PR #364). **D-94** (#361) aj **M-R** (#353–#359) sú hotové a Michal 12.9. potvrdil oba smoke **PASS**;
D-28 vyriešené, Čelá A/B1/B2/C používateľsky potvrdené. **Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**. Blok **1b** uzavretý, **1c/1e hotové**.

## Ďalší krok

**Ďalší blok vyberá Michal** — automaticky sa nič neštartuje; po uzávere M-R mala nasledovať slovná diskusia o workflow. Skupina „KONTROLA + VÝROBA" v
[DOGFOODING.md](DOGFOODING.md) je po D-94 prázdna. Budúca rotácia obrázka a umiestnenie textúr sú D-126/D-127 v [PLAN.md](PLAN.md); D-48 a **D-109** (pomerová mechanika kovania, R-05) zostávajú po V1; ručné Redo Čiel je stále samostatne nepotvrdené.
**Otvorené po D-134:** **D-129 + D-130** rework kontextu Čelá (úchytky na dvoch miestach + menší UI/UX rework) — **v novom okne**: debata s Michalom → draft → outside-in → reconcile → mockup → package. Plné znenie v [DOGFOODING.md](DOGFOODING.md). **Codex weekly kvóta je vyčerpaná (reset 19.9.)** — do vtedy platí náhradná brána podľa [../CLAUDE.md](../CLAUDE.md).

## Posledné uzávery

- **D-134 · Jednotný rozsah hromadných zápisov zákazky** (v0.12.5 → **v0.12.6**, 13.9.2026, PR #369). Pravidlá kovania, projektová predvoľba materiálu a „aj na podobné v projekte" stoja na spoločnom `Panel.job_cabinets` nad `Ids.top_level_scan` — všetkých **päť** hromadných zápisov zákazky má tak jeden rozsah.
  Skrinka s odpojeným dielcom sa **preskočí a vymenuje**, projektový zápis prebehne (skip, nie blokáda — na rozdiel od all-or-nothing náhrady dekoru). Čítacie cesty a kontrakt bez zmeny.
- **D-133 · „Nahradiť UNI…" má rozsah výstupov a blokuje pri odpojenom dielci** (v0.12.4 → **v0.12.5**, 13.9.2026, PR #368). Zber stojí na zdieľanom `Ids.top_level_scan` (ten istý prechod koreňom má D-131), takže vnorená skrinka sa už neprestavuje; nový blokujúci dôvod `:detached` so zdieľanou vetou. All-or-nothing, odtlačok plánu aj kontrakt bez zmeny.
- **D-132 · Dormantný zámok osi zásuvky je viditeľný a dá sa zrušiť** (v0.12.3 → **v0.12.4**, 13.9.2026, PR #367). Štvrtý druh osirotenia `dormant` (iný recept · čelo nie je zásuvka · čelo zaniklo); riadok v Kovaní s dôvodom a rušením **existujúcou** cestou `reset: true`. Bez zmeny kontraktu.
- **D-131 · Kresba čiel celej zákazky jedným klikom** (v0.12.2 → **v0.12.3**, PR #365) a **D-128 · Ručná výška dreveného boxu zásuvky** (v0.12.1 → **v0.12.2**, PR #364, `CONFIG_SCHEMA` 13 → 14) — 13.9.2026, plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **D-94 · Nákup s pôvodom** (v0.12.0 → **v0.12.1**, 12.9.2026, PR #361). Rozklik nákupného riadku po skrinkách, klik-select zdroja s deep-linkom na kartu čela, pamäť rozkliku podľa identity riadku + regresný strážca invariantu „súčet zdrojov = počet riadku".
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
