# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generované kódom z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale→automatická prestavba na mm, 2D náhľad korpusu v paneli s auto-úpravou.

- **Špecifikácia:** [Noxun Component Standard](SYSTEM/01_STANDARD_draft.md) · [Roadmapa](SYSTEM/04_ROADMAP.md) · [docs](docs/) — všetko v tomto repe
- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Workflow:** vetva → PR → Codex review → merge (viď `CLAUDE.md`)

Stav: **v0.4.7 — dogfooding: samostatná doska HOTOVÁ** — parametrické korpusy (strom zón, čelá s lockmi, šablóny), **kovanie fáza 1** (pravidlá nohy/závesy/výsuvy s projektovým snapshotom), **Inspector UI** (kontextové karty, satelitné okná Pravidlá/Materiály/Šablóny), katalóg materiálov/ABS s dedením projekt → skrinka → dielec a **samostatný výrobný dielec „Doska"** (kind `board`: vlastná identita BRD-xxx, karta v paneli, ABS hrany, kópie s novým ID, scale absorpcia s hrúbkou viazanou na materiál) + **matematické výrazy v rozmerových poliach** (`650-36` → Enter). Kontrakty: BuildPlan (plán stavby korpusu) + výrobný snapshot na entite (štandard 8.2/8.3) — kusovník a VEPO (V0.5) budú čítať jeden svet. Testy: 185 headless + 46 JS (CI) + in-SketchUp runner 45 scenárov (geometria, undo, kópie, scale). Ďalej: **V0.4.8 konštrukčné možnosti**, potom **V0.5 výstupy** (kusovník, VEPO CSV).
