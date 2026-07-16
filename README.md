# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generované kódom z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale→automatická prestavba na mm, 2D náhľad korpusu v paneli s auto-úpravou.

- **Špecifikácia:** [Noxun Component Standard](SYSTEM/01_STANDARD_draft.md) · [Roadmapa](SYSTEM/04_ROADMAP.md) · [docs](docs/) — všetko v tomto repe
- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Workflow:** vetva → PR → Codex review → merge (viď `CLAUDE.md`)

Stav: **v0.2.2 (V0.2c)** — jadro korpusu (dolná/horná, konštrukčné varianty, strom zón, čelá, šablóny) + UX: interaktívny 2D náhľad (klik na zónu, ťahanie priečok, zámky rozmerov), auto-apply, ghost zóny na 1 klik (top-level), tagy dielov (Korpus/Chrbát/Čelá/Vnútro). Ďalej: materiály+ABS, kovanie, výstupy (kusovník, VEPO).
