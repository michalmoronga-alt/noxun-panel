# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.12.7 · 19.9.2026 — M-R VZHĽAD KOMPLET, nad ním sedem dávok D-94 až D-130a** (Nákup s pôvodom · výška dreveného boxu · Kresba čiel · dormantný zámok · rozsah zákazky pri „Nahradiť UNI" aj pri hromadných zápisoch · **nový zoznam čiel**). Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340 — plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md)).
**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo).
**Kompatibilita:** konfigurácia skrinky je od D-128 v **schéme 14**, výrobný plán v schéme 5; vzhľad používa katalógovú schému 10 až pri prvom uložení. Starší plugin nové konfigurácie neprestaví — pred takou zákazkou aktualizovať **obe PC**.

**D-130a (najnovšie):** **4141 headless · 119 JS sád · 2765 in-SketchUp PASS / 0 FAIL** (nové sady `test_d130a_zoznam_ciel.rb` + `test_d130a_suhrn_karta.js`, nová in-SU
sekcia `run_d130a`: segment „Krídla" postaví dva panely a 1 krok Späť ich vráti · tab Kovanie má serverový text aj box vlastníka · popover „všetkým" zapíše profil aj hranu celému rozsahu naraz · chip AUTO vráti automat · čítacie payloady nenechajú krok Späť).
**D-134:** 4128 · 118 · 2745 PASS / 0 FAIL. **D-133:** 4111 · 118 · 2717. **D-132:** 4095 · 118 · 2705. **D-131:** 4080 · 117 · 2693. **D-128:** 4029 · 116 · 2658.
**M-R:** 3983 headless · 114 JS sád · 2606 in-SketchUp PASS / 0 FAIL; CEF Štúdia **18 PASS**, controller → uloženie/otvorenie bez SKM → prestavba → výroba **50 PASS**, živá zmena mierky bez Apply **11 PASS** ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md); fyzický druhý PC, SU 2024 a render netestované). Ručné Redo Čiel zostáva nepotvrdené.
**Michal 11.9. potvrdil** test produktových odkazov aj potvrdzovania cien (CENY-KOV-A/B, PR #345/#346) **a** používateľskú kontrolu balíka Čiel v0.11.0 (funguje, bez chýb).

## Robí sa

**D-130a „Nový zoznam čiel" je hotové (PR #371, v0.12.7) — čaká na smoke.** Riadok čela je **mriežka so stálymi stĺpcami** (číslo · názov + súhrn · pole výšky · ✕), takže polia
už „nelietajú"; pod názvom je **súhrn stavu** („1 krídlo (auto) · smer? · bez úchytky · Sensys klasik · 2 ks →") — stav všetkých čiel vidno bez otvárania kariet. Klik otvorí
**kartu s dvoma tabmi**: **Čelo** (typ · krídla · smer · otváranie · konštrukcia · zásuvka · úchytka) a **Kovanie** (vyriešený set, zámky osí, detail, „Otvoriť v Kovaní").
**Úchytka je na jednom mieste** (karta), hromadne cez **„všetkým"** v hlavičke — skupina „Úchytky" zanikla (**D-129 vyriešené**). Pomocné texty sú tooltipy `?`; dáta, zápis,
Undo ani server sa nemenia.
**Tiež čakajú na smoke: D-134** (jednotný rozsah hromadných zápisov; #369), **D-133** (zámena UNI vidí top-level zákazku; #368), **D-132** (dormantný zámok v Kovaní; #367),
**D-131** („Kresba čiel" v Štúdiu; #365) a **D-128** (tretí chip osi „box 360"; #364). **D-94** (#361) aj **M-R** (#353–#359) sú hotové a Michal 12.9. potvrdil oba smoke
**PASS**; D-28 vyriešené, Čelá A/B1/B2/C používateľsky potvrdené. **Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**. Blok **1b** uzavretý, **1c/1e hotové**.

## Ďalší krok

**Ďalší blok vyberá Michal** — automaticky sa nič neštartuje; po uzávere M-R mala nasledovať slovná diskusia o workflow. Skupina „KONTROLA + VÝROBA" v
[DOGFOODING.md](DOGFOODING.md) je po D-94 prázdna. Budúca rotácia obrázka a umiestnenie textúr sú D-126/D-127 v [PLAN.md](PLAN.md); D-48 a **D-109** (pomerová mechanika kovania, R-05) zostávajú po V1; ručné Redo Čiel je stále samostatne nepotvrdené.
**Otvorené po D-130a:** **D-130b — skupina „Spoločné pre skrinku"** (materiál čiel · **schéma medzier** namiesto dvoch riadkov polí · ikony zámku limitu a „Predvolené" v hlavičke; `fgaps` + `fronts` → `cabfront`). Mockup [zdroje/ui20/mockup_cela_final.html](zdroje/ui20/mockup_cela_final.html) je schválený, outside-in hotový — stačí package. Znenie v [DOGFOODING.md](DOGFOODING.md).

## Posledné uzávery

- **D-130a · Nový zoznam čiel, karta s tabmi, úchytka na jednom mieste** (v0.12.6 → **v0.12.7**, 19.9.2026, PR #371). Riadok = CSS grid `22 / 1fr / 112 / 22`; pole výšky je
  jeden box s konštantnou šírkou (chip AUTO odoberá miesto hodnote, nie boxu); súhrn z čistej `frontRowSummary` (počet krídel zo servera, smer len z uloženej hodnoty);
  karta má taby Čelo | Kovanie (`frontCardModel.tabs` + `hwRows`), krídla sú segment v karte (`dataset.frontWings`); `fhandles` zanikla, hromadná úchytka je popover
  „všetkým" so **zápisom až pri „Použiť"**; pomocný text = tooltip `.nxtip`, stavové vety ostávajú. **D-129 vyriešené.** Bez zmeny kontraktu a payloadov.
- **D-134 · Jednotný rozsah hromadných zápisov zákazky** (→ **v0.12.6**, 13.9.2026, PR #369). Pravidlá kovania, projektová predvoľba materiálu a „aj na podobné v projekte"
  stoja na spoločnom `Panel.job_cabinets` nad `Ids.top_level_scan` — všetkých **päť** hromadných zápisov zákazky má jeden rozsah. Skrinka s odpojeným dielcom sa **preskočí a vymenuje**, projektový zápis prebehne.
- **D-133** „Nahradiť UNI…" má rozsah výstupov a blokuje pri odpojenom dielci (→ **v0.12.5**, #368) · **D-132** dormantný zámok osi zásuvky je viditeľný a dá sa zrušiť
  (→ **v0.12.4**, #367) · **D-131** Kresba čiel celej zákazky jedným klikom (→ **v0.12.3**, #365) · **D-128** ručná výška dreveného boxu (→ **v0.12.2**, #364,
  `CONFIG_SCHEMA` 13 → 14) · **D-94** Nákup s pôvodom (→ **v0.12.1**, #361) — 12.–13.9.2026, plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359). Spoločná knižnica dosiek/ABS, natívny editor, fyzické UV, zachovanie pri prestavbe/kópii a ovládanie v Štúdiu. D-28 vyriešené; [plný blok](archiv/ROADMAP_hotove_etapy.md).
- **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR #277–#340). **Čo plugin odteraz vie:** klasifikované sety a katalóg (strom Kategória → Výrobca → Rada,
  editor so živým náhľadom) · **zásuvka z nemenného receptu** (Atira, Quadro V6) s objednávacími kódmi zo setu, bez tichého fallbacku na inú NL, so zámkami osí a povýšením
  receptu · **závesy** podľa Noxun tabuľky (Tip-On vlastný set) · **výklopy AVENTOS HK/HL top** podľa výšky a **hmotnosti čela** · **nohy 4/6 podľa šírky + príchyt sokla** ·
  **šablóny aj s kovaním** · **ad-hoc kovanie** v Inspectore · **114 katalógových kódov** (D-118) · **updater** (D-52). Vyriešené: D-52 · D-110 · D-111 · D-115 · D-116 ·
  D-118 · D-121 · D-125. D-114/D-119/D-120 uzavrel balík Čiel (v0.11.0); otvorené ostáva **D-109** (pomerová mechanika = R-05 po V1). Detail v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **Staršie uzávery** (v0.9.58–v0.9.61 **KOV-G** + **KOV-I** · v0.9.53–v0.9.57 **KOV-E** + fixy #335/#336 · v0.9.48–v0.9.52 **KOV-F** · v0.9.47 **KOV-W** · v0.9.43–v0.9.46
  **D-118** a **D-121** · v0.9.29–v0.9.42 **KOV-C/KOV-D** · v0.9.19–v0.9.26 **KOV-B** · v0.9.16–v0.9.21 **KOV-A** + **KOV-H** · v0.9.14 **D-52** · v0.9.24–v0.9.28 **NÁSTROJE-1**
  a **GHOST-D1/D2** · v0.9.22 D-112/D-113 · v0.9.0 **GHOST VKLADANIE** · v0.8.0 **fáza ŠTÚDIO** · staršie etapy až po V0.1) — plné texty
  v [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

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
