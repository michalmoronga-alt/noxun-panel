# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.12.11 · 20.9.2026 — M-R VZHĽAD KOMPLET, nad ním osem dávok D-94 až D-135 a začiatok bloku SPOTREBIČE S1** (S1-E0 = min výška korpusu 80 mm, PR #375 · **S1-A1 = katalóg spotrebičov so seedom 9 overených modelov** · **S1-A2 = sekcia Štúdia Spotrebiče (pohľad Katalóg)** · (Nákup s pôvodom · výška dreveného boxu · Kresba čiel · dormantný zámok ·
rozsah zákazky pri „Nahradiť UNI" aj pri hromadných zápisoch · **rework kontextu Čelá komplet — nový zoznam čiel + skupina „Spoločné pre skrinku"**).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **trinástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · **Spotrebiče** · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340 — plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md)). **Výstupy zákaziek bez
zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo).
**Kompatibilita:** konfigurácia skrinky je od D-128 v **schéme 14**, výrobný plán v schéme 5; vzhľad používa katalógovú schému 10 až pri prvom uložení. Starší plugin nové konfigurácie neprestaví — pred takou zákazkou aktualizovať **obe PC**.

**D-130b (najnovšie):** **4155 headless · 120 JS sád · 2779 in-SketchUp PASS / 0 FAIL** (nové sady `test_d130b_spolocne.rb` + `test_d130b_spolocne.js`, nová in-SU sekcia
`run_d130b`: číslo zo schémy dojde do configu ako `gap_top` a 1 krok Späť ho vráti · odomknutý zámok pustí presah −300 mm a zamknutý ho odmietne · „Predvolené" vrátia 3/2/2/2/2
jedným krokom Späť · materiál čiel zo skupiny zapíše `front_material_id`). **D-130a:** 4141 · 119 · 2765. **D-134:** 4128 · 118 · 2745. **D-133:** 4111 · 118 · 2717.
**D-132:** 4095 · 118 · 2705. **D-131:** 4080 · 117 · 2693. **M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md); fyzický druhý PC, SU 2024 a render
netestované). **Michal 11.9. potvrdil** test produktových odkazov aj potvrdzovania cien (CENY-KOV-A/B, #345/#346) **a** kontrolu balíka Čiel v0.11.0 (funguje, bez chýb).

## Robí sa

**REWORK KONTEXTU ČELÁ JE KOMPLET (D-130a PR #371 v0.12.7 + D-130b PR #372 v0.12.8) — čaká na smoke.** Kontext má **dve skupiny**: **Čelá** (riadok = mriežka so stálymi
stĺpcami, súhrn stavu pod názvom, karta s tabmi Čelo | Kovanie, úchytka na jednom mieste — **D-129 vyriešené**) a **Spoločné pre skrinku** (materiál čiel + **schéma medzier
a okrajov**: obrys korpusu, päť tých istých polí sedí na hranách, ktorých sa týka; medzera v strede jantárovo). Zámok limitu presahov a „Predvolené" sú **ikony v hlavičke**,
meta povie stav aj zbalenej skupiny („dub Halifax · 3 · 2/2/0/0"), tooltip `?` vysvetlí znamienka (+ odskok / 0 zarovno / − presah, škára); jantárové prisvietenie medzier
v náhľade sa viaže na **fokus v poli alebo hover nad schémou**. Dáta, zápis, Undo ani server sa nemenia.
**Tiež čakajú na smoke: D-134** (#369), **D-133** (#368), **D-132** (#367), **D-131** (#365) a **D-128** (#364). **D-94** (#361) aj **M-R** (#353–#359) sú hotové a Michal
12.9. potvrdil oba smoke **PASS**; D-28 vyriešené, Čelá A/B1/B2/C používateľsky potvrdené. **Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**.

## Ďalší krok

**Blok SPOTREBIČE S1 beží** (Michal schválil 20.9.2026, nočný autonómny beh): debata polí hotová, cross outside-in audit ×3 (Codex · Grok · Gemini) vyhodnotený, **mockup schválený**
(`zdroje/ui20/mockup_spotrebice_s1.html`), packages v [PLAN.md](PLAN.md) blok 5. Poradie: **S1-E0** (✅ PR #375) → **A1 katalóg** (✅ v0.12.10) → **A2 sekcia** (✅ v0.12.11) → E slot umývačky → B väzba →
F telo chladničky + Kontrola → C šablóna → D uzáver (v0.13.0). Slot umývačky a telo chladničky sú nové vo V1. Po S1: **K1–K3**, **ceny materiálov/ABS**; D-126/D-127, D-48, D-109 po V1.

## Posledné uzávery

- **D-130b · Skupina „Spoločné pre skrinku" — materiál čiel + schéma medzier** (v0.12.7 → **v0.12.8**, 19.9.2026, PR #372). `fgaps` zanikla, kontext Čelá má dve skupiny
  `fronts` · `cabfront`; štyri popísané riadky okrajov nahradila **schéma `.gapdiag`** (tie isté polia `fr_gap*` na hranách obrysu, `fr_gap` v strede jantárovo, mriežka
  `.front-gap-grid` zanikla); zámok limitu a reset sú **ikony v `<summary>`** (stav = ikona + `title` + `aria-pressed` + `amber`), meta `#cabfrontMeta` z čistej
  `cabfrontMetaText`; N26 sa viaže na **fokus/hover**. **D-130 vyriešené celé.** Bez zmeny kontraktu.
- **D-130a · Nový zoznam čiel, karta s tabmi, úchytka na jednom mieste** (v0.12.6 → **v0.12.7**, 19.9.2026, PR #371). Riadok = CSS grid `22 / 1fr / 112 / 22`; pole výšky je
  jeden box s konštantnou šírkou; súhrn z čistej `frontRowSummary` (počet krídel zo servera, smer len z uloženej hodnoty); karta má taby Čelo | Kovanie, krídla sú segment
  v karte; `fhandles` zanikla, hromadná úchytka je popover „všetkým" so **zápisom až pri „Použiť"**; pomocný text = tooltip `.nxtip`. **D-129 vyriešené.** Bez zmeny kontraktu.
- **D-134 · Jednotný rozsah hromadných zápisov zákazky** (→ **v0.12.6**, 13.9.2026, PR #369). Pravidlá kovania, projektová predvoľba materiálu a „aj na podobné v projekte"
  stoja na spoločnom `Panel.job_cabinets` nad `Ids.top_level_scan`. Skrinka s odpojeným dielcom sa **preskočí a vymenuje**, projektový zápis prebehne.
- **D-133** „Nahradiť UNI…" má rozsah výstupov a blokuje pri odpojenom dielci (→ **v0.12.5**, #368) · **D-132** dormantný zámok osi zásuvky je viditeľný a dá sa zrušiť
  (→ **v0.12.4**, #367) · **D-131** Kresba čiel jedným klikom (→ **v0.12.3**, #365) · **D-128** ručná výška dreveného boxu (→ **v0.12.2**, #364, `CONFIG_SCHEMA` 13 → 14) · **D-94** Nákup s pôvodom (→ **v0.12.1**, #361) — plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359). Spoločná knižnica dosiek/ABS, natívny editor, fyzické UV, zachovanie pri prestavbe/kópii a ovládanie v Štúdiu. D-28 vyriešené; [plný blok](archiv/ROADMAP_hotove_etapy.md).
- **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR #277–#340). Klasifikované sety a katalóg s editorom · **zásuvka z nemenného receptu** (Atira,
  Quadro V6) s kódmi zo setu, bez tichého fallbacku, so zámkami osí · **závesy** podľa Noxun tabuľky · **výklopy AVENTOS HK/HL top** podľa výšky a hmotnosti čela ·
  **nohy 4/6 + príchyt sokla** · šablóny aj s kovaním · ad-hoc kovanie · 114 katalógových kódov (D-118) · updater (D-52). Vyriešené: D-52 · D-110 · D-111 · D-115 · D-116 · D-118 · D-121 · D-125; otvorené ostáva **D-109** (R-05 po V1). Detail v [archiv/KRONIKA.md](archiv/KRONIKA.md).
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
