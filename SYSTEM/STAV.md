# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.13.3 · 27.9.2026 — BEŽÍ BLOK 7 · KONŠTRUKCIA K1+K2; hotové KON-0 (#401), KON-A (#402) a KON-B · K2** (PR #403). Chrbát má novú voľbu
**„Z líšt"**: namiesto dosky chrbta **dve vodorovné lišty z korpusovej dosky** medzi bokmi — dolná na dne, horná pod stropom (pod výstuhami, pri „Bez stropu"
po vrch bokov); riadok **„Výška líšt"** (predvolene 100) sedí na mieste hrúbky chrbta. Dolná 600 × 720 × 510 → dve lišty **564 × 100 × 18**, „Vnút. hĺbka"
**492** — police, priečky a zásuvky končia pred lištami v celej výške. **Kusovník: jeden riadok, 2 ks „Lista chrbta"**, VEPO **„Chrb HD"**, páska na jednej
dlhej hrane viditeľnej zvnútra; s výstuhami 100 sa zlúčia do jedného riadku 4 ks („Vyst PZ/Chrb HD"). Lišty, ktoré sa nezmestia (2 × výška + 20 > vnútro),
zočervenajú pole s vetou a nič sa nepostaví. Materiál chrbta (HDF) sa pri lištách nepoužije. **Ostatné typy chrbta sa nemenia.**
Pod tým KON-A (komín vzadu a zapustenie stropu, v0.13.2), KON-0 (chrbát v drážke do nárezu, v0.13.1), blok **SPOTREBIČE S1** (v0.13.0, smoke **PASS 26.9.**).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **trinástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · **Spotrebiče** · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
V1 ciele **Materiály, Kovanie, Spotrebiče a Dvaja používatelia** sú odškrtnuté ([V1_VIZIA.md](V1_VIZIA.md)); Konštrukcia (bod 2) je rozpracovaná blokom 7.

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 21** (KON-B), **doska v schéme 2**, šablóny v STD 6, výrobný plán v schéme 6, ABS pravidlá v seede 5 — starší plugin
zákazku neprestaví ani nevyexportuje. **Dáta rozpočtu sú od S1-B1 v `BUDGET_STD` 2** (starší plugin zákazku po prvej mutácii rozpočtu needituje a zastaví oba cenové exporty).
**Pred prvou výrobou s lištami aktualizovať OBE PC (aj Luciino)** — starší plugin „Z líšt" nepozná (prestavbou by vrátil dosku chrbta) a samostatne prenesenú
lištu by vo VEPO vydal pod plným názvom.

**Testy (posledná kódová dávka, KON-B · K2 #403):** **4621 headless · 133 JS sád · 3158 in-SU PASS / 0 FAIL**. KON-A (#402): 4600 · 132 · 3136.
**KON-0 (#401):** 4577 · 131 · 3111. **S1-C:** 4499 · 127 · 3036. **M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md)).

## Robí sa

**Blok 7 · KONŠTRUKCIA K1+K2** ([PLAN.md](PLAN.md), priečinok [zdroje/bloky/KONSTRUKCIA/](zdroje/bloky/KONSTRUKCIA/)) — po KON-0, KON-A a KON-B zostáva
**KON-D** (šablóna Chladničková); audit-povinná dávka prejde auditom svojho návrhu. Potom uzáver bloku (minor verzia + smoke).
**Čakajú na smoke:** **KON-0** (#401), **KON-A** (#402), **KON-B** (#403), **D-132** (#367), **D-133** (#368), **D-134** (#369). **D-141**, **D-142** a **D-145** sú v zásobníku.
**Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**.

## Ďalší krok

**Smoke KON-B (Michal, v0.13.3):** (1) dolná 600 × 720 × 510, Chrbát **„Z líšt"**, výška 100 → v modeli dve lišty 564 × 100 × 18 (dole na dne, hore pod
stropom); „Vnút. hĺbka" 492; kusovník **1 riadok, 2 ks „Lista chrbta"**, VEPO „Chrb HD s…", páska na jednej dlhej hrane · (2) tá istá skrinka so stropom
„Dve výstuhy" (100) → 1 riadok **4 ks**, VEPO „Vyst PZ/Chrb HD s…" · (3) výška líšt 290 → pole červené a veta „Dve lišty po 290 mm sa do vnútra 584 mm
nezmestia", nič sa nepostaví · (4) späť na „Naložený" → chrbát HDF sa vráti (aj s ručným materiálom, ak bol) · (5) Kontrola olepov: páska na hornej hrane
dolnej lišty a na dolnej hrane hornej · (6) komín 50 + lišty → lišty posunuté o 50 dopredu, vnútro 442 · (6a) ručne zmeň materiál len jednej lišty →
kusovník 2 riadky (správne) · (6b) „Z líšt" → výška 999 → „Bez chrbta" → „Aplikuj" funguje · (7) aktualizovať plugin aj u Lucie (schéma 21).
Smoke KON-A (v0.13.2) a KON-0 (v0.13.1) platia ďalej ([archiv/KRONIKA.md](archiv/KRONIKA.md)). Potom package **KON-D**.

## Posledné uzávery

- **KON-B · K2** (v0.13.2 → **v0.13.3**, 27.9.2026, PR #403) — chrbát z dvoch líšt, vnútro pred lištami, jeden riadok „Chrb HD", `CONFIG_SCHEMA` 21, BuildPlan 6,
  ABS seed 5. Plné znenie v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KON-A · K1** (v0.13.1 → **v0.13.2**, 27.9.2026, PR #402) — komín vzadu a zapustenie stropu, nika z hĺbky boku, config-aware minimum hĺbky pri mierke,
  oprava D-144 so zastaranými skrinkami v registri výrobnej brány, `CONFIG_SCHEMA` 20.
- **KON-0 · D-143** (v0.13.0 → **v0.13.1**, 27.9.2026, PR #401) — chrbát v drážke do nárezu v plnom rozmere, jedna výrobná brána, zastarané skrinky, `CONFIG_SCHEMA` 19.
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
