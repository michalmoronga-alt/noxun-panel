# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.16.3 · 30.9.2026 — BLOK CENY, posledná dávka CENY-M2** (Rozpočet, PR #428). **Rozpočet → Materiál a ABS hrany:** doska a páska **bez Demosu** má
v stĺpci „Overená" stav („ručne 18.9." sivé · „ručne 45 dní" / „neoverená" jantárové), ktorý je zároveň tlačidlom **„Overiť cenu"** (formulár z M1b, ostáva
sa v Rozpočte). Čip **„N cien na kontrolu"** a „Skontrolovať ceny" počítajú aj ručné materiály (UNI a duplák nie), pred názvom je ikona odkazu (Demos · obchod ·
jantárová = doplniť odkaz). **Sklo a iný materiál bez formátu mimo bežných dosiek sa v Rozpočte počíta podľa m²** (skutočná plocha dielcov × cena za m²);
**bežná doska bez formátu ako doteraz** (odhad platní — otázka Q2 na Michala otvorená); porez a montáž bez zmeny. Pod tým **blok 2 · KONTROLA + VÝROBA** (v0.16.0, smoke **PASS 29.9.**, PR #423), **blok 8 · K3 ROHOVÁ** (v0.15.0, smoke PASS 28.9.), **blok 7 · K1+K2** (v0.14.0).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
so **štrnástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · **Nárezový plán** · Materiály · Kovanie · Spotrebiče · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Neaktívna položka navigácie už nie je žiadna.

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
V1 ciele **Konštrukcia** (K1 + K2 blok 7, K3 blok 8), **Materiály, Kovanie, Spotrebiče a Dvaja používatelia** sú odškrtnuté ([V1_VIZIA.md](V1_VIZIA.md)); vo **Výstupoch**
ostáva ručné overenie cien materiálov/ABS (blok CENY); **test na kompletnej reálnej zákazke je akceptačný test po V1** (C13).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.10.0) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) · **blok KONŠTRUKCIA K1+K2** (v0.14.0) · **blok K3 ROHOVÁ**
(v0.15.0) · **blok 2 KONTROLA + VÝROBA** (v0.16.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 22** (typ `corner_blind`), **doska v schéme 2**, **šablóny v STD 7**, výrobný plán v **schéme 7**, ABS pravidlá
v **seede 6** — starší plugin zákazku neprestaví ani nevyexportuje (rohovú by sklopil na dolnú). **Dáta rozpočtu sú od NP-4 v `BUDGET_STD` 3** (prvá úprava rozpočtu
v0.15.4 zapíše 3 — potom v0.15.3 a starší zákazku v Rozpočte needituje a zastaví oba cenové exporty). **Nastavenia dodávateľa sú od NP-2 vo verzii súboru 2** (v0.15.1 a starší pri uložení nové polia zahodí).
**Katalóg materiálov je po prvom uloženom odkaze v schéme 11 a po prvom ručnom overení ceny v schéme 12** — starší plugin ho ďalej číta (aj Rozpočet), ale nezapíše doň.
**Aktualizuj plugin na oboch PC pred porovnávaním alebo posielaním ponúk — starší plugin počíta sklo bez formátu po starom.** (0.16.3 aj na Luciino PC; `BUDGET_STD` M2 nemení.)

**Testy (CENY-M2, PR #428):** **4910 headless · 145 JS sád** zelené; 28 mutácií (M1–M24) zabitých; in-SU nie je brána (package §8).
**M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md)).

## Robí sa

**Blok CENY** (posledný kódový bod V1, [PLAN.md](PLAN.md) blok 4; priečinok [zdroje/bloky/CENY/](zdroje/bloky/CENY/) — rozhodnutia, mockup, package M1 s auditom):
**CENY-M1a** (odkaz, v0.16.1) → **CENY-M1b** (ručné overenie ceny, v0.16.2, D-148) → **CENY-M2** (Rozpočet, v0.16.3) — všetky kódové dávky hotové,
nasleduje **uzáver bloku** (`release/ceny`, v0.17.0). Poradie pred V1: **CENY → R-13 → R-37 → R-35**
(**R-13 rozhodnuté 29.9.: čítať** — ORANGE „dielec z inej verzie štandardu"). Pri prvej rohovej v dielni ostáva overiť záves Sensys na výstuhe závesov.
**Čakajú na smoke:** **D-132** (#367), **D-133** (#368), **D-134** (#369). **D-141**, **D-142**, **D-145**, **D-146** a **D-147** sú v zásobníku.

## Ďalší krok

**Uzáver bloku CENY** (`release/ceny`, v0.17.0) hneď po mergi M2, potom **smoke celého bloku** (M1 §10 body 1–14 + M2 §10 body 1–10): najprv
**aktualizovať plugin na oboch PC**, potom odkaz a „Overiť cenu" v Materiáloch, v Rozpočte sklo v m² (porez a montáž bez zmeny), stĺpec „Overená",
čip „na kontrolu" a „Skontrolovať ceny". **Q2 (doska bez formátu) a Q1 (porez skla)** čakajú na Michala. **Test na reálnej zákazke po V1.**

## Posledné uzávery

- **CENY-M2 · Rozpočet** (**v0.16.3**, 30.9.2026, PR #428) — vek ručných cien, „Overiť cenu" a ikona odkazu v Rozpočte, sklo bez formátu podľa m².
- **CENY-M1b · ručné overenie ceny** (**v0.16.2**, PR #427) a **CENY-M1a · odkaz na produkt** (**v0.16.1**, PR #426) — [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK 2 · KONTROLA + VÝROBA UZAVRETÝ** (**v0.16.0**, 29.9.2026; nárezový plán: štart #417, PR #418–#421 + uzáver PR #422; **smoke PASS 29.9.**, PR #423).
  Nárezový plán v Štúdiu, nastavenia prerezu/orezu/prídavku, Kontrola s orezom, ceny podľa plánu; priečinok bloku v [archiv/bloky/NAREZ/](archiv/bloky/NAREZ/).
  [Výsledok, dávky a checklist](archiv/NAREZ_ZAVER_2026-09-29.md).
- **BLOK 8 · K3 ROHOVÁ SKRINKA UZAVRETÝ** (v0.14.0 → **v0.15.0**, 27.–28.9.2026, podklady #409, PR #410–#413 + uzáver PR #414; smoke **PASS 28.9.**, PR #415). Typ „Rohová" s rohovou zostavou,
  vkladanie, riadok rohovej a prepínač strany, kresba zostavy a karta Čelá rohovej; priečinok bloku je od uzáveru v [archiv/bloky/ROHOVA/](archiv/bloky/ROHOVA/).
  [Plný blok](archiv/ROADMAP_hotove_etapy.md) · [výsledok, dávky a checklist](archiv/ROHOVA_ZAVER_2026-09-28.md) · priebeh v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK 7 · KONŠTRUKCIA K1+K2 UZAVRETÝ** (v0.13.0 → **v0.14.0**, 26.–27.9.2026, PR #401–#404 + uzáver PR #405; smoke **PASS 27.9.**) — [výsledok](archiv/KONSTRUKCIA_ZAVER_2026-09-27.md),
  priečinok [archiv/bloky/KONSTRUKCIA/](archiv/bloky/KONSTRUKCIA/) · **BLOK SPOTREBIČE S1** (v0.13.0, PR #375–#390; smoke PASS 26.9.) — [výsledok](archiv/S1_ZAVER_2026-09-24.md).
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
