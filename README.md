# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generované kódom z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale→automatická prestavba na mm, 2D náhľad v paneli, materiály s dekorovými skupinami a výrobné výstupy.

- **Špecifikácia:** [Noxun Component Standard](SYSTEM/01_STANDARD.md) · [Stav](SYSTEM/STAV.md) · [Plán](SYSTEM/PLAN.md) · [docs](docs/) — všetko v tomto repe
- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → SketchUp 2026 → Extensions → Noxun Engine → Panel
- **Workflow:** vetva → PR → Codex review → merge (viď `CLAUDE.md`)

Stav: **v0.5.60 — etapa V0.6 KATALÓGY A CENY v behu; materiály KOMPLET (2.8.2026), kovanie so setmi a nákupným zoznamom KOMPLET (2.8.2026), peňažná vrstva (rozpočet + cenová ponuka) hotová 6.8.2026 — beží test na prvej reálnej zákazke, ďalej UI 2.0.** Systém dnes vie: parametrické korpusy (strom zón s priečkami, čelá fixed/auto s lockmi aj „bez čela", šablóny, krídla 1–4), **samostatná doska** (kind board s ABS editorom a výrazmi `650-36` v poliach), **kovanie fáza 1** (pravidlá nohy/závesy/výsuvy s projektovým snapshotom a ručnými zásahmi), **materiály a ABS s dekorovými skupinami** (dekor viaže dosky+pásky, deterministický výber šírky pásky, katalóg ako mriežka dlaždíc s kódmi/dodávateľmi/cenami, remap ručných ABS pri zmene materiálu) a **výstupy s kontrolou** (interný kusovník, okno Výroba s klik-selectom, **VEPO CSV validovaný krížovo proti OCL flow**, odhad platní, kontrolný semafor — RED nikdy neblokuje export). UI = kontextový **Inspector** so sticky hlavičkou, režimovými tabmi Korpus·Zóny·Čelá a satelitnými oknami (Pravidlá kovania, Materiály, Šablóny).

Vo V0.6 doteraz pribudlo: **dekorové skupiny s identitou výrobca+číslo** (SCHEMA 2, automatická migrácia katalógu so zálohou), duplák 36 = 2×18 a zástena s dvomi dekormi, **Demos konektor** — „Pridať z Demosu" založí celú rodinu dekoru z jedného fetchu (kódy, ceny s DPH, fotky dekorov) a „Aktualizovať z Demosu" číta uložené URL väzby, **katalóg kovania** a **UNI pracovné materiály** (modelovanie bez záväzku — hrúbku určuje dielec, materiály sa dovolia aj na konci projektu).

Materiály sú od 2.8.2026 KOMPLET: „Nahradiť UNI…" (hromadná zámena s rozpisom dopadu a 1 undo), duplák automaticky v selectoch, zástena vrátane protiťahovej, PD hranová logika + kompakt bez ABS, hustoty per typ, čitateľný našeptávač s kontrolou linku.

Od 2.8.2026 ďalej pribudlo: **sety kovania** (generický typ → zoznam objednávateľných kódov, nákupný zoznam s cenami a CSV), **rozpočet a zákaznícka cenová ponuka** vrátane XLSX exportov a tlačidla „Prepočítať ceny", **úchytkový profil UKW-7** na hrane čela, **farba ABS pásky priamo na hranách v modeli** a **kontrola olepov v troch stavoch** so zvýraznením v modeli (bez zásahu do súboru).

Kontrakty: BuildPlan (geometria, kusovník aj VEPO čítajú ten istý plán) + výrobný snapshot na entite (štandard 8.2/8.3). Testy: **1163 headless + 29 JS sád / 966 kontrol (CI na každý push) + 302 in-SketchUp scenárov**. Ďalej: dokončiť prvú reálnu zákazku vyrobenú čisto z pluginu → kontrola a testy → **UI 2.0** (mockup pred implementáciou), potom M-R render — viď [plán](SYSTEM/PLAN.md).
