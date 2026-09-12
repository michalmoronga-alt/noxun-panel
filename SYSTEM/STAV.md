# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.11.7 · 12.9.2026 — M-R: MR-2B SPOLOČNÉ OVLÁDANIE VZHĽADU.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
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
**MR-1A:** **3849 headless · 113 JS sád**, vrátane skutočných súbežných katalógových zápisov počas exportu. Natívne sondy overili predpoklady ďalšej dávky; nová geometria ani ovládanie ešte nie sú vydané.
**MR-1B1:** **3856 headless · 113 JS sád · 2321 in-SketchUp PASS / 0 FAIL**, z toho 24 nových kontrol adaptéra. Identita, celý skúšaný PBR stav, dve revízie a obnova zdroja prešli; fyzický SU 2024 ani renderová zhoda nie sú overené.
**MR-1B2:** **3898 headless · 113 JS sád · 2381 in-SketchUp PASS / 0 FAIL**, z toho 60 nových kontrol. Oba buildery, spoločná ABS, R1/R2, kópie, scale, batch a rollback; snapshot, kusovník a VEPO zhodné. Save/reopen bez `.skm` zachová celý otvorený stav pri prestavbe; samotný SketchUp pri otvorení zjednotí sekundárne PBR mierky s albedom (priznaný charakterizačný rozdiel, render netestovaný).
**MR-3A:** **3925 headless · 113 JS sád · 2442 in-SketchUp PASS / 0 FAIL** (61 nových kontrol). Fyzické UV, ABS, zástena, duplák, R1/R2, copy/scale, Undo/Redo a úplný rollback; výroba zhodná. Samostatné save/reopen bez `.skm`: **21 PASS**, materiály/UV/snapshot aj následná prestavba zachované; bez sekundárnych PBR máp a renderového overenia.
**MR-3B:** **3953 headless · 113 JS sád · 2518 in-SketchUp PASS / 0 FAIL** (76 nových kontrol). Spoločné Apply dosiek/ABS, vnorené/skryté kópie, ochrana cudzích dielcov aj následného rebuildu, výroba a úplný rollback.
D-40 opravené úzkou zmenou operácie; výber žije po Apply/Undo/Redo/abort. Save/reopen bez `.skm`: **24 PASS**, presný vzhľad, UV a prestavba zachované; bez sekundárnych PBR máp/renderu.
**MR-2A:** **3971 headless · 113 JS sád · 2563 in-SketchUp PASS / 0 FAIL** (45 nových natívnych kontrol). Pracovný SKM, PBR/pixely/mierka, nulový RGB, spoločné Undo/Redo a rollback prípravy; D-40 ostáva funkčné.
**MR-2B:** **3983 headless · 114 JS sád · 2606 in-SketchUp PASS / 0 FAIL** (43 nových natívnych kontrol). Skutočné CEF Štúdia **18 PASS**; spoločné ovládanie dosiek/ABS, presný Save/retry, farba, Reset, natívny Edit, Undo/Redo a ochrana životnosti okna.
Geometrický dôkaz ČELÁ-B2: **in-SketchUp 2297 PASS / 0 FAIL** (osadenia, výroba/rezy, šablóny, uloženie/návrat, Scale/Späť a kópia); C geometriu nemení. Ručné Redo zostáva.
**Michal 11.9. potvrdil úspešný test produktových odkazov aj potvrdzovania cien** (CENY-KOV-A/B, PR #345/#346).
**Michal 11.9. potvrdil aj používateľskú kontrolu hotového balíka Čiel v0.11.0: funguje, bez nájdených chýb.** Samostatné ručné Redo nebolo výslovne potvrdené.

## Robí sa

**Michal schválil blok M-R a mockup (11.9.).** Jeden spoločný vzhľad pre dosky aj ABS rovnakého dekoru a povrchu naprieč hrúbkami; dnešné plošné farby ostávajú, zástena má jeden vzhľad. UNI ostáva pracovnou farbou.
**MR-1A/1B1/1B2, MR-3A/3B a MR-2A sú v maine (#353–#358).** MR-2B sprístupňuje spoločný Vzhľad pri povrchu v Materiáloch: obrázok, natívny editor, uloženie do knižnice a návrat k farbe.
Každý Pick/Edit vytvorí nový pracovný materiál a má jeden krok Späť. Save zachytí konkrétny zdroj, aj keď sa medzitým vyberie iný materiál; úspešné uloženie s chybným použitím umožňuje samostatný retry.
Ďalšie dávky určuje blok M-R v [PLAN.md](PLAN.md), audit a sondy zachytáva [MR podklad](zdroje/next_sessions/MR_VZHLAD_PACKAGE_2026-09-11.md). Čelá A/B1/B2/C ostávajú dokončené a používateľsky potvrdené.
**Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**. Blok **1b** je uzavretý, **1c/1e hotové**.

## Ďalší krok

Po uzavretí MR-2B záverečný smoke a uzáver M-R z čerstvého mainu. D-28 ostáva otvorené do dokončenia celého bloku; ručné Redo Čiel ostáva samostatne nepotvrdené.

## Posledné uzávery

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
