# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generované kódom z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale→automatická prestavba na mm, 2D náhľad korpusu v paneli s auto-úpravou.

- **Špecifikácia:** [Noxun Component Standard](SYSTEM/01_STANDARD_draft.md) · [Roadmapa](SYSTEM/04_ROADMAP.md) · [docs](docs/) — všetko v tomto repe
- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Workflow:** vetva → PR → Codex review → merge (viď `CLAUDE.md`)

Stav: **v0.3.3** — parametrické korpusy, strom zón, čelá, šablóny a interaktívny 2D náhľad + katalóg materiálov/ABS s dedením projekt → skrinka → dielec. Stabilná identita dielcov chráni individuálne materiály a ABS pri zmenách susedných zón alebo poradí čiel; ABS katalóg a pravidlá povoľujú výhradne reálne hrúbky 1 a 2 mm. Ďalej: kovanie, kusovník a VEPO výstupy.
