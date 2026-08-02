# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generované kódom z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale→automatická prestavba na mm, 2D náhľad v paneli, materiály s dekorovými skupinami a výrobné výstupy.

- **Špecifikácia:** [Noxun Component Standard](SYSTEM/01_STANDARD.md) · [Roadmapa](SYSTEM/04_ROADMAP.md) · [docs](docs/) — všetko v tomto repe
- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Workflow:** vetva → PR → Codex review → merge (viď `CLAUDE.md`)

Stav: **v0.5.32 — etapa V0.6 KATALÓGY A CENY v behu; MATERIÁLY KOMPLET (2.8.2026), ďalej KOVANIE.** Systém dnes vie: parametrické korpusy (strom zón s priečkami, čelá fixed/auto s lockmi aj „bez čela", šablóny, krídla 1–4), **samostatná doska** (kind board s ABS editorom a výrazmi `650-36` v poliach), **kovanie fáza 1** (pravidlá nohy/závesy/výsuvy s projektovým snapshotom a ručnými zásahmi), **materiály a ABS s dekorovými skupinami** (dekor viaže dosky+pásky, deterministický výber šírky pásky, katalóg ako mriežka dlaždíc s kódmi/dodávateľmi/cenami, remap ručných ABS pri zmene materiálu) a **výstupy s kontrolou** (interný kusovník, okno Výroba s klik-selectom, **VEPO CSV validovaný krížovo proti OCL flow**, odhad platní, kontrolný semafor — RED nikdy neblokuje export). UI = kontextový **Inspector** so sticky hlavičkou, režimovými tabmi Korpus·Zóny·Čelá a satelitnými oknami (Pravidlá kovania, Materiály, Šablóny).

Vo V0.6 doteraz pribudlo: **dekorové skupiny s identitou výrobca+číslo** (SCHEMA 2, automatická migrácia katalógu so zálohou), duplák 36 = 2×18 a zástena s dvomi dekormi, **Demos konektor** — „Pridať z Demosu" založí celú rodinu dekoru z jedného fetchu (kódy, ceny s DPH, fotky dekorov) a „Aktualizovať z Demosu" číta uložené URL väzby, **katalóg kovania** a **UNI pracovné materiály** (modelovanie bez záväzku — hrúbku určuje dielec, materiály sa dovolia aj na konci projektu).

Materiály sú od 2.8.2026 KOMPLET: „Nahradiť UNI…" (hromadná zámena s rozpisom dopadu a 1 undo), duplák automaticky v selectoch, zástena vrátane protiťahovej, PD hranová logika + kompakt bez ABS, hustoty per typ, čitateľný našeptávač s kontrolou linku.

Kontrakty: BuildPlan (geometria, kusovník aj VEPO čítajú ten istý plán) + výrobný snapshot na entite (štandard 8.2/8.3). Testy: **780 headless + 604 JS (CI na každý push) + ~140 in-SketchUp scenárov**. Ďalej vo V0.6: **D — sety kovania** (podklad debaty pripravený), **E — ceny v sumári**, potom UI 2.0 — viď roadmapa.
