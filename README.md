# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generuje kód z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale → automatická prestavba na mm, 2D náhľad v paneli, materiály s dekorovými skupinami, kovanie so setmi a výrobné aj obchodné výstupy (kusovník, VEPO CSV, nákupné zoznamy, rozpočet, cenová ponuka).

**Stav: v0.6.0** — etapa V0.6 (katalógy a ceny) je obsahovo splnená a prvá reálna zákazka **KLINIKA** (254 dielcov) je postavená čisto z pluginu, prekontrolovaná a porovnaná s ručným rozpočtom. Ďalej: workflow retrospektíva → **UI 2.0**.

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
- **Testy:** `ruby tests/run_all.rb` (headless) · `node tests/js/test_*.js` · `scripts\run_su_tests.ps1` (in-SketchUp)
- **Workflow:** vetva → PR → Codex review → merge (podrobne v [CLAUDE.md](CLAUDE.md))
