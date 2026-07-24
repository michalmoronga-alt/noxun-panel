# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generované kódom z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale→automatická prestavba na mm, 2D náhľad v paneli, materiály s dekorovými skupinami a výrobné výstupy.

- **Špecifikácia:** [Noxun Component Standard](SYSTEM/01_STANDARD.md) · [Roadmapa](SYSTEM/04_ROADMAP.md) · [docs](docs/) — všetko v tomto repe
- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Workflow:** vetva → PR → Codex review → merge (viď `CLAUDE.md`)

Stav: **v0.5.0 — etapa V0.5 KOMPLET (24.7.2026).** Systém dnes vie: parametrické korpusy (strom zón s priečkami, čelá fixed/auto s lockmi aj „bez čela", šablóny, krídla 1–4), **samostatná doska** (kind board s ABS editorom a výrazmi `650-36` v poliach), **kovanie fáza 1** (pravidlá nohy/závesy/výsuvy s projektovým snapshotom a ručnými zásahmi), **materiály a ABS s dekorovými skupinami** (dekor viaže dosky+pásky, deterministický výber šírky pásky, katalóg ako mriežka dlaždíc s kódmi/dodávateľmi/cenami, remap ručných ABS pri zmene materiálu) a **výstupy s kontrolou** (interný kusovník, okno Výroba s klik-selectom, **VEPO CSV validovaný krížovo proti OCL flow**, odhad platní, kontrolný semafor — RED nikdy neblokuje export). UI = kontextový **Inspector** so sticky hlavičkou, režimovými tabmi Korpus·Zóny·Čelá a satelitnými oknami (Pravidlá kovania, Materiály, Šablóny).

Kontrakty: BuildPlan (geometria, kusovník aj VEPO čítajú ten istý plán) + výrobný snapshot na entite (štandard 8.2/8.3). Testy: **372 headless + 200 JS (CI na každý push) + ~140 in-SketchUp scenárov**. Ďalej: **V0.6 kovanie fáza 2** (katalóg a ceny, Demos) — viď roadmapa.
