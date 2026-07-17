# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generované kódom z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale→automatická prestavba na mm, 2D náhľad korpusu v paneli s auto-úpravou.

- **Špecifikácia:** [Noxun Component Standard](SYSTEM/01_STANDARD_draft.md) · [Roadmapa](SYSTEM/04_ROADMAP.md) · [docs](docs/) — všetko v tomto repe
- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Workflow:** vetva → PR → Codex review → merge (viď `CLAUDE.md`)

Stav: **v0.3.4 — stabilizácia pred kovaním HOTOVÁ** — parametrické korpusy, strom zón, čelá, šablóny a interaktívny 2D náhľad + katalóg materiálov/ABS s dedením projekt → skrinka → dielec; stabilná identita dielcov (part_key). Základná vrstva je uzavretá: **BuildPlan kontrakt** (validátor, warnings kanál, pripravené miesto pre kovanie), 140 automatických testov s CI, in-SketchUp runner (geometria + undo scenáre), panel rozdelený podľa domén, funkčné undo pri scale aj kópiách. Ďalej: **V0.4 kovanie** (pravidlá + flagy), kusovník a VEPO výstupy.
