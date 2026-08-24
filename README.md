# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generuje kód z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale → automatická prestavba na mm, 2D náhľad v paneli, materiály s dekorovými skupinami, kovanie so setmi a výrobné aj obchodné výstupy (kusovník, VEPO CSV, nákupné zoznamy, rozpočet, cenová ponuka).

**Stav: v0.8.0 — FÁZA ŠTÚDIO KOMPLET.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste). Štúdio má **dvanásť živých sekcií** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine (Nárezový plán je jediná neaktívna, patrí do fázy 2). Fáza ŠTÚDIO (ŠT-1a … ŠT-4b, PR #192–#228) zrušila **šesť satelitných okien** — Výroba · Materiály projektu · Katalóg kovania · Pravidlá kovania · Šablóny · Nastavenia rozpočtu — a ich obsah presunula do sekcií **1:1 s jedinou výnimkou**: uloženie novej šablóny ostalo v Inspectore (má po ruke označenú skrinku), takže sekcia Šablóny ich len spravuje. Žiadna funkcia sa nestratila. Predtým: etapa V0.6 (katalógy a ceny) obsahovo splnená, prvá reálna zákazka **KLINIKA** (254 dielcov) postavená čisto z pluginu a porovnaná s ručným rozpočtom; Inspector rework (UI 2.0, bloky UI-A…UI-D). Ďalej: **stabilizačná revízia** (dlhy fázy, refactory) a potom blok **KOVANIE**.

## Kam sa pozrieť

| | |
|---|---|
| **Kde projekt je** (vstupný bod každého sedenia) | [SYSTEM/STAV.md](SYSTEM/STAV.md) |
| Čo sa ide robiť — bloky prác a zaradené položky | [SYSTEM/PLAN.md](SYSTEM/PLAN.md) |
| Záväzný dátový kontrakt (Noxun Component Standard) | [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) |
| Pravidlá kódu — SketchUp, DC, UI dizajn, architektúra modulov | [docs/](docs/) |
| História dávok a rozhodnutí | [SYSTEM/archiv/KRONIKA.md](SYSTEM/archiv/KRONIKA.md) |
| Pravidlá práce v repe (workflow, verzie, testovanie) | [CLAUDE.md](CLAUDE.md) |

## Inštalácia a vývoj

- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Testy:** `ruby tests/run_all.rb` (headless) · JS sady po jednej — bash: `for f in tests/js/test_*.js; do node "$f" || exit 1; done` (glob priamo za `node` spustí len prvý súbor) · `scripts\run_su_tests.ps1` (in-SketchUp)
- **Workflow:** vetva → PR → Codex review → merge (podrobne v [CLAUDE.md](CLAUDE.md))
