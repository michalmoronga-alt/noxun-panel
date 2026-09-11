# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.10.7 · 11.9.2026 — ČELÁ-A/B: samostatné presahy a profily na všetkých hranách.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu;
nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340 — plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md)).
**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo).
**Pozor na kompatibilitu:** blok KOVANIE priniesol sériu schema bumpov — čo uloží v0.10.0, to starší plugin už nepoužije (model/šablóna `CONFIG_SCHEMA`, plán `BuildPlan::SCHEMA` 5,
knižnica setov a snapshot `std`, katalóg kovania `schema`). Pred prvou takou zákazkou aktualizovať **obe PC** (updater D-52: Štúdio → O plugine → Aktualizovať).

**Testy k v0.10.7:** **3825 headless · 113 JS sád · in-SketchUp 2279 PASS / 0 FAIL**. Skutočný Inspector pri 470 px s Ruby preflight.
Osadenie profilov, rezy, šablóny s/bez kovania, Scale/Späť, kópia, save/reopen a staré predvoľby overené. Neplatný Scale bezpečne vráti pôvodný stav; Redo API je na Windows nedostupné.
**Michal 11.9. potvrdil úspešný test produktových odkazov aj potvrdzovania cien** (CENY-KOV-A/B, PR #345/#346).

## Robí sa

**BALÍK ČIEL (D-114 + D-119 + D-120) — implementácia, 11.9.2026.** Michal schválil samostatné ľavé/pravé presahy pre celú skrinku,
UKW na všetkých štyroch hranách a aj na výklope/sklope/blende; zvislé profily dvierok vždy oproti pántom (dvojkrídlo v strede).
Ovládanie: profil/hrana v karte čela + hromadné Úchytky; štyri okraje v dvoch riadkoch; šesť piktogramov na pridanie typu.
Úplné packages **ČELÁ-A → B → C** sú v [PLAN.md](PLAN.md). Lokálna interaktívna ukážka `_dev/cela-plan/index.html` je návrh, nie runtime pluginu.
Outside-in a Astra audit spracované (4 FIX, 2 NOTE), kontrola zapracovania **SOUND**. Michal schválil mockup aj implementáciu 11.9.; ČELÁ-A/B implementované v PR #347/#348 (v0.10.6–0.10.7).
Neplatný návrh zostáva vo formulári; export/kópia/šablóna pokračuje až po platnom návrhu a potvrdenom uložení.
**Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**. Blok **1b** je uzavretý, **1c/1e hotové**.

## Ďalší krok

Uzavrieť review/merge ČELÁ-B (#348), potom z čerstvého mainu ČELÁ-C (šesť piktogramov, kompaktné karty a súhrn hrán).
Ostatné V1 bloky ostávajú podľa [PLAN.md](PLAN.md).

## Posledné uzávery

- **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR #277–#340). **Čo plugin odteraz vie:** sety a katalógové položky sú **klasifikované**
  (typ použitia · otváranie · konštrukcia · výrobca · rada), katalóg má strom Kategória → Výrobca → Rada a set sa upravuje v editore so **živým náhľadom** ·
  **zásuvka vzniká z nemenného receptu** (Atira, Quadro V6) — dielce, výška, NL a nosnosť drží recept, **objednávacie kódy set** (dve vrstvy, §6); žiadny tichý fallback na inú NL;
  os sa dá zamknúť a recept povýšiť · **závesy** podľa Noxun tabuľky, Tip-On vlastný set · **výklopy AVENTOS HK top / HL top** podľa výšky a **hmotnosti čela**
  (hmotnosť dielcov aj skrinky je v Inspectore) · **nohy 4/6 podľa šírky korpusu + príchyt sokla**, vetou v Základných **už pri vkladaní** · **šablóny vedia uložiť
  aj kovanie** (voľba + súhrn na dlaždici) · **ad-hoc kovanie** priamo v Inspectore · katalóg pozná **kódy, ktoré si plugin sám objednáva** (114 položiek D-118
  + AXILO/STRONG) · **updater** „Aktualizovať jedným klikom" (D-52) — vstupná podmienka celého bloku. Vyriešené postrehy: D-52 · D-110 · D-111 · D-115 · D-116 ·
  D-118 · D-121 · D-125. Otvorené ostáva **D-114 balík Čiel** (s D-119/D-120) a **D-109** (pomerová mechanika = R-05 po V1). Detail v [archiv/KRONIKA.md](archiv/KRONIKA.md).
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
