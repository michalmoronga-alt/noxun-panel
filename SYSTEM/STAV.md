# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide do záznamu dávky (súbor bloku `zdroje/bloky/<BLOK>/kronika/`, oprava mimo bloku odsek navrch v [archiv/KRONIKA.md](archiv/KRONIKA.md)).
> Dokumentačné PR, ktoré mení stav bloku, smoke alebo poradie prác, aktualizuje faktický stav v „Stav" (verzia a čísla testov sa nemenia) a prepíše „Robí sa" a „Ďalší krok" (od 1.10.2026); ostatné ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.18.1 · 11.10.2026 — BLOK 9 · HARDENING PO V1 UZAVRETÝ** (v0.18.0; v0.18.1 len opravený komentár v kóde o H11c, PR #474; štart PR #432, dávky H1–H19 + uzáver PR #473; **smoke čaká na Michala**): zavádzajúce údaje v oknách opravené, ochrana
poškodeného súboru a dvoch okien, minimum SketchUp 2026, typy skriniek a sekcie Štúdia na jednom mieste, súpis knižníc, spoločná príprava exportov, export test; **čísla a exporty bez zmeny**.
Vedome nové: **skrinka od 50 mm** (ŠÍRKA 50, PR #466: úzka dolná má 2 nohy) a **skutočne použitý set závesov** v Inspectore (H18, H18b-1, PR #462, #463). Pád pri ukončení SketchUpu 2026.2 (#1117)
sa **nepotvrdil** (H11c, quit test 5× exit 0; kód bez zmeny). Výsledok, dávky a **zlúčený smoke checklist**: [archiv/HARDENING_ZAVER_2026-10-11.md](archiv/HARDENING_ZAVER_2026-10-11.md).
Pod tým **BLOK CENY UZAVRETÝ** (v0.17.0, PR #425–#431, smoke PASS 30.9.): odkaz a ručné overenie ceny dosky a ABS bez Demosu, materiál bez formátu podľa m².
Pod tým bloky 2 (v0.16.0), 8 (v0.15.0), 7 (v0.14.0), všetky smoke PASS. Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka, **štrnásť živých sekcií**).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
**Všetkých sedem bodov V1 je odškrtnutých** ([V1_VIZIA.md](V1_VIZIA.md); Výstupy blokom CENY 30.9.) — **V1 je hotové**. Hardeningové body R-13, R-37 a R-35 uzavrel blok 9 (H8–H10); **test na kompletnej reálnej zákazke je akceptačný test po V1** (C13).

**Kompatibilita** (čísla všetkých verzií dát len v [STANDARD §13](STANDARD.md#13-schémy-a-verzie-dát-jedna-tabuľka)): zákazku z novšieho pluginu starší plugin **neprestaví
ani nevyexportuje** (rohovú by sklopil na dolnú, úzku rozšíril na 200). **Rozpočet:** po prvej úprave rozpočtu vo v0.15.4+ ho v0.15.3 a starší needituje a zastaví oba cenové exporty.
**Nastavenia dodávateľa** v0.15.1 a starší pri uložení nové polia zahodí. **Katalóg materiálov** po prvom uloženom odkaze alebo ručnom overení ceny starší plugin
ďalej číta (aj Rozpočet), ale nezapíše doň.
**Plugin beží len v SketchUpe 2026+** (0.17.10+; obe PC majú 2026); po aktualizácii na 0.17.21+ zatvoriť a otvoriť Štúdio (export bez kontroly názvu odmietne).
**Ochranu pred poškodeným súborom nastavení (H9) má len 0.17.7+, nastavení exportu (H7a) 0.17.20+, ochranu dvoch okien 0.17.8+ (pravidlá) a 0.17.9+ (rady) — aktualizovať obe PC a potom zavrieť všetky okná SketchUpu** (staré okno zapisuje bez ochrany).
**Aktualizuj plugin na oboch PC (Michal aj Lucia) na 0.17.0 pred prvým uložením odkazu, ručným overením ceny alebo porovnávaním a posielaním ponúk — starší plugin počíta sklo aj dosku bez formátu po starom** (`BUDGET_STD` blok CENY nemení, takže starší plugin nevaruje).

**Testy (v0.18.1):** 5426 Ruby/0/0, 163 JS PASS; encoding/docs PASS; plná in-SU sada na SketchUp 2026.2: 3421 PASS / 0 FAIL (11.10.). Export test `scripts\export_test.ps1` (H19, P == K).

## Robí sa

**Blok 10 · PRAVIDLA** — pravidlá a workflow agentov, plugin sa nemení ([PLAN.md](PLAN.md), priečinok [zdroje/bloky/PRAVIDLA/](zdroje/bloky/PRAVIDLA/)); hotové sú dávky P1a (definície na jednom mieste, PR #478), P4a
(drobnosti workflowu, PR #479), P1b (pravidlá z `CLAUDE.md` presunuté do jadra `AGENTS.md`, súborov rolí `pravidla/roly/` a `pravidla/POVINNE_CITANIE.md`; `CLAUDE.md` je most; stropy veľkosti a zákaz histórie stráži guard, PR #480),
P2 (karty všetkých rolí, typy agentov generované z kariet bez dedenia `CLAUDE.md`, nová rola analytik, PR #482; smoke typov PASS 26.10.)
P3a (pravidlá oblastí v `.claude/rules/` s `paths:`, POVINNE_CITANIE je rozcestník, IMPLEMENTATOR ≤ 8 kB, PR #483; smoke oblastí PASS 26.10.)
a P3b (postupy uzáveru bloku a smoke sú skilly, ORCHESTRATOR pod vlastný strop 10 kB, WORKFLOW ako mapa, blok OBMEDZENIE NÁSTROJOV v jednom súbore, PR #484)
a P4b (hook pred príkazom odmietne commit a push do `main`, merge bez pripnutej hlavy, merge so zástupným číslom PR a runner bez `-CloseWhenDone`; živý smoke PASS 27.10. v Bash, PowerShelli aj subagentoch, PR #485)
a P4c (prevzatie práce: karta priebehu a `rozpracovane.ps1`, zelené CI pred „hotovo“, čakanie na review podľa stavu Codexu, záznamy dávok po súboroch, výťah zo sessions, PR #486); ďalej P5 (hodnotenia po úlohách a router). Popri ňom čaká **Michalov smoke bloku 9** (94 bodov v 5 skupinách) a aktualizácia pluginu na 0.18.1 na oboch PC.
**Zásobník z bloku:** D-154 „Exportovať všetko" · D-151 · D-152 · D-153 (podmienený) · H18b-2 mimo scope. **Luciin PC:** nevieme, či má SketchUp 2026.2 (H11 Q3 bez odpovede).
**Otázky bez odpovede, platí návrh:** vymenované v [záverečnom dokumente](archiv/HARDENING_ZAVER_2026-10-11.md) (Otvorené body) · pri prvej rohovej v dielni overiť záves Sensys ·
**na smoke čakajú aj** D-132 (#367), D-133 (#368), D-134 (#369) — sú v checkliste (B25, C19, C20).

## Ďalší krok

**Blok PRAVIDLA:** P5 — hodnotenia po úlohách (podľa [PLAN.md](PLAN.md)); živý smoke hooku P4b PASS 12/12 (27.10., `kronika/P4c.md`).
**Michal:** smoke bloku 9 podľa [HARDENING_ZAVER_2026-10-11.md](archiv/HARDENING_ZAVER_2026-10-11.md)** — skupiny A Exporty a čísla (28) · B Inspector (25) · C Štúdio (20) · D Ochrana dát a dve okná (10) ·
E SketchUp a štart (11, vrátane Koniec SketchUpu na 2026.2). Pred ním aktualizovať plugin na oboch PC a zavrieť všetky okná SketchUpu. Nálezy zo smoke = opravy x.y.z (dočasná skupina
v [DOGFOODING.md](DOGFOODING.md)). Potom nový blok podľa výberu Michala. **Test na reálnej zákazke po V1.**

## Posledné uzávery

- **BLOK 9 · HARDENING PO V1 UZAVRETÝ** (**v0.18.0**, 11.10.2026; štart #432, H1–H19 PR #433–#472 + uzáver PR #473; **smoke čaká**). Priečinok bloku v [archiv/bloky/HARDENING/](archiv/bloky/HARDENING/) ·
  [výsledok a smoke checklist](archiv/HARDENING_ZAVER_2026-10-11.md).
- **BLOK CENY UZAVRETÝ** (**v0.17.0**, 30.9.2026; štart #425, CENY-M1a #426 v0.16.1 · CENY-M1b #427 v0.16.2 · CENY-M2 #428 v0.16.3 + uzáver PR #429).
  Odkaz a ručné overenie ceny dosky/ABS bez Demosu, Rozpočet s vekom ručných cien, materiál bez formátu podľa m²; priečinok bloku v [archiv/bloky/CENY/](archiv/bloky/CENY/) · [výsledok](archiv/CENY_ZAVER_2026-09-30.md).
- **BLOK 2 · KONTROLA + VÝROBA UZAVRETÝ** (**v0.16.0**, 29.9.2026; nárezový plán: štart #417, PR #418–#421 + uzáver PR #422; **smoke PASS 29.9.**, PR #423).
  Nárezový plán v Štúdiu, nastavenia prerezu/orezu/prídavku, Kontrola s orezom, ceny podľa plánu; priečinok bloku v [archiv/bloky/NAREZ/](archiv/bloky/NAREZ/) · [výsledok](archiv/NAREZ_ZAVER_2026-09-29.md).
- **BLOK 8 · K3 ROHOVÁ SKRINKA UZAVRETÝ** (**v0.15.0**, 28.9.2026, PR #410–#414; smoke **PASS 28.9.**) — [výsledok](archiv/ROHOVA_ZAVER_2026-09-28.md), priečinok [archiv/bloky/ROHOVA/](archiv/bloky/ROHOVA/) ·
  **BLOK 7 · K1+K2** (**v0.14.0**, PR #401–#405; smoke **PASS 27.9.**) — [výsledok](archiv/KONSTRUKCIA_ZAVER_2026-09-27.md), priečinok [archiv/bloky/KONSTRUKCIA/](archiv/bloky/KONSTRUKCIA/) ·
  **BLOK SPOTREBIČE S1** (v0.13.0, PR #375–#390; smoke PASS 26.9.) — [výsledok](archiv/S1_ZAVER_2026-09-24.md).
- **REWORK KONTEXTU ČELÁ** (v0.12.3–v0.12.8, PR #365–#372: D-131, D-132, D-133, D-134, D-130a/b) — plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
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
| workflow, verzie, uzáver dávky, testovanie | jadro [../AGENTS.md](../AGENTS.md) + roly [pravidla/roly/](pravidla/roly/) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [V1_VIZIA.md](V1_VIZIA.md) |
| kontrakt výstupu do VEPO | [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) |
| rešerše, koncepty, prieskumy dodávateľov (nezáväzné) | [zdroje/](zdroje/) |
