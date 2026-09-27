# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.13.2 · 27.9.2026 — BEŽÍ BLOK 7 · KONŠTRUKCIA K1+K2; hotové KON-0 (D-143, PR #401) a KON-A · K1** (PR #402). Skrinka má v Inspectore nové
nastavenia: **„Komín vzadu"** (Chrbát) — dno, strop a zadná výstuha končia o komín skôr ako boky, chrbát sa posunie dopredu na ich zadné hrany a za ním
ostane vzduchový kanál (dolná 600 × 720 × 510, komín 50 → boky 510, dno a strop 460, naložený chrbát **medzi bokmi 564 × 620**, „Vnút. hĺbka" 460) —
a **„Zapustenie vpredu"** (Strop) — plný strop alebo predná výstuha začína za prednou hranou boku, dno sa neposúva. Neplatný komín (napr. 2 pri HDF 3)
zočervená pole s vetou a nič sa nepostaví; nika chladničky sa pri komíne meria z hĺbky boku; ťahanie hĺbky pod minimum sa zastaví na najmenšej platnej
hĺbke s hláškou. **D-144:** vložený chrbát a chrbát v drážke pri výstuhách na výšku končí pod výstuhami (aj do nárezu); staršie skrinky s touto kombináciou
sú zastarané (RED, exporty stoja, „Prestaviť zastarané skrinky"). Skupina Boky v Nastaveniach zanikla. **Pri komíne 0 sa nemení nič.**
Pod tým KON-0 (chrbát v drážke do nárezu 600 × 720, v0.13.1), blok **SPOTREBIČE S1** (v0.13.0, smoke **PASS 26.9.**) a blok M-R VZHĽAD (v0.12.0).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **trinástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · **Spotrebiče** · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
V1 ciele **Materiály, Kovanie, Spotrebiče a Dvaja používatelia** sú odškrtnuté ([V1_VIZIA.md](V1_VIZIA.md)); Konštrukcia (bod 2) je rozpracovaná blokom 7.

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.9.14 → v0.10.0, 50 PR #277–#340) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 20** (KON-A), **doska v schéme 2**, šablóny v STD 6, výrobný plán v schéme 5 — starší plugin ich neprestaví ani nevyexportuje.
**Dáta rozpočtu sú od S1-B1 v `BUDGET_STD` 2** (starší plugin zákazku po prvej mutácii rozpočtu needituje a zastaví oba cenové exporty).
**Pred prvým použitím v0.13.2 aktualizovať OBE PC (aj Luciino)** — starší plugin komín nepozná (prestavbou by narezal dno a strop na plnú hĺbku).

**Testy (posledná kódová dávka, KON-A · K1 #402):** **4600 headless · 132 JS sád · 3136 in-SU PASS / 0 FAIL**. KON-0 (#401): 4577 · 131 · 3111.
**Smoke oprava C (#389):** 4545 · 129 · 3081. **S1-C:** 4499 · 127 · 3036. **M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md)).

## Robí sa

**Blok 7 · KONŠTRUKCIA K1+K2** ([PLAN.md](PLAN.md), priečinok [zdroje/bloky/KONSTRUKCIA/](zdroje/bloky/KONSTRUKCIA/)) — po KON-0 a KON-A nasledujú **KON-B**
(chrbát z dvoch líšt) a **KON-D** (šablóna Chladničková); každá audit-povinná dávka prejde auditom svojho návrhu.
**Čakajú na smoke:** **KON-0** (#401), **KON-A** (#402), **D-132** (#367), **D-133** (#368), **D-134** (#369). **D-141** a **D-142** sú v zásobníku.
**Blok 1d** podľa kapacity — hotové po R-14, ďalej R-18; **R-13 čaká na Michala**.

## Ďalší krok

**Smoke KON-A (Michal, v0.13.2):** (1) dolná 600 × 720 × 510, naložený HDF 3, **Komín vzadu 50** → „Vnút. hĺbka" 460; kusovník boky 510, dno a strop 460, chrbát
564 × 620; hlavička Chrbát „komín 50" · (2) komín 2 → červené pole a veta, nič sa nepostaví · (3) horná 600 × 720 × 320 v drážke: komín 12 → odmietnutie, 13 → vnútro
307, do nárezu 600 × 720 · (4) Strop „Zapustenie vpredu 30" → strop začína 30 mm za hranou, dno nie; pri „Bez stropu" riadok zmizne · (5) chladnička v skrinke
600 × 2100 × 560 bez chrbta, komín 50 → nika meria 560 · (6) potiahni hĺbku skrinky s komínom 100 pod minimum → zastaví sa na 160 + hláška, jedno Späť vráti ·
(7) šablóna s komínom na inú skrinku → komín ide; stará šablóna → komín ostane · (8) do poľa Komín napíš `50-20` → 30 · (9) aktualizovať plugin aj u Lucie (schéma 20).
Smoke KON-0 (v0.13.1) platí ďalej. Potom package **KON-B**.

## Posledné uzávery

- **KON-A · K1** (v0.13.1 → **v0.13.2**, 27.9.2026, PR #402) — komín vzadu a zapustenie stropu, nika z hĺbky boku, config-aware minimum hĺbky pri mierke,
  oprava D-144 so zastaranými skrinkami v registri výrobnej brány, `CONFIG_SCHEMA` 20. Plné znenie v [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md).
- **KON-0 · D-143** (v0.13.0 → **v0.13.1**, 27.9.2026, PR #401) — chrbát v drážke do nárezu v plnom rozmere, jedna výrobná brána, zastarané skrinky, `CONFIG_SCHEMA` 19.
- **BLOK SPOTREBIČE S1 UZAVRETÝ** (v0.12.9 → **v0.13.0**, 20.–24.9.2026, PR #375–#389 + uzáver #390; smoke PASS 26.9.). Katalóg spotrebičov, spotrebič v zákazke,
  slot umývačky, telo chladničky s Kontrolou niky a delenia čiel, očakávaný spotrebič; smoke opravy D-136 až D-140.
  [Plný blok](archiv/ROADMAP_hotove_etapy.md) · [výsledok, dávky a checklist](archiv/S1_ZAVER_2026-09-24.md) · priebeh v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **REWORK KONTEXTU ČELÁ** — **D-130b** (v0.12.8, #372) a **D-130a** (v0.12.7, #371) · **D-134** jednotný rozsah hromadných zápisov (v0.12.6, #369) ·
  **D-133** „Nahradiť UNI…" (v0.12.5, #368) · **D-132** dormantný zámok (v0.12.4, #367) · **D-131** Kresba čiel (v0.12.3, #365) · **D-128** ručná výška boxu
  (v0.12.2, #364) · **D-94** Nákup s pôvodom (v0.12.1, #361) — plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359) · **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR
  #277–#340; otvorené ostáva **D-109**, R-05 po V1) — [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
- **Staršie uzávery** (v0.9.x KOV-G/I/E/F/W/C/D/B/A/H, D-52, NÁSTROJE-1, GHOST-D1/D2, v0.9.0 **GHOST VKLADANIE**, v0.8.0 **fáza ŠTÚDIO**, staršie až po V0.1) —
  [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

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
