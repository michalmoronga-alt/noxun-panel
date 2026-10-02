> Kópia zadania zo scratchpadu (2.10.2026); autorita = súbory v priečinku bloku.

# Brief — dávka H15 · dáta kovania oddelené od mechaniky setov (C-03) — blok 9 HARDENING

Orchestrátor ti povie, ktorú časť robíš (**H15a** alebo **H15b**). Každá časť = samostatný PR z **čerstvého `origin/main`** (po mergi predchodcu).

| Časť | Vetva | Obsah | Brány |
|---|---|---|---|
| **H15a** · sety | `refactor/h15a-sety-seed` | **T0 golden pre VŠETKY tri moduly (1. commit, G1–G7)** → `core/hardware_sets_seed.rb` → `main.rb` + `tests/helper.rb` → guard R5 (sety) → docs | audit-povinná + výrobná/cenová · predrecenzia povinná (recenzent dostane aj `--color-moved=zebra`) · in-SU 1 beh odporúčaný (§8) |
| **H15b** · katalóg + taxonómia | `refactor/h15b-katalog-seed` | `core/hardware_catalog_seed.rb` + `core/hardware_taxonomy_seed.rb` → `main.rb` + helper → R5 na 3 moduly (vrátane §15 A2) → docs + scenár 6 mapy (D7) | ako H15a; in-SU netreba |

## Zdroj (autorita v tomto poradí)
1. [`../PACKAGE_H15.md`](../PACKAGE_H15.md) — **§15 má prednosť**
   (A1 = golden G7 nákupu s explicitnými materiálmi a overením mechanizmu/kitu, HL ramená a tyče, žiadny blokujúci konflikt — harness inak golden nezapíše;
   A2 = allowlist `SEED_ITEMS`/`SEED_ITEMS_V2`/`SEED_PRODUCT_LINKS` len ako odvodeniny zo seed konštánt + negatívny test literálu), potom §6 R0–R6, §7, §11.
   Surový audit [`../AUDIT_H15_raw.md`](../AUDIT_H15_raw.md). Prototyp a sondy autora package (`proto_split_h15a.rb`, `proto_split_h15b.rb`, `sonda_h15*.rb`,
   `run_guards_h15.rb`) ostali v scratchpade orchestrátora mimo repa — smieš ich použiť ako pomôcku, autorita je package.
2. Package je z mainu `108c808c`; medzitým zmergovali H12d, H6a–c, H7a/b, H11a (podľa poradia) → **krok 0: over čísla riadkov, poradie načítania v `main.rb`
   (H11a mohla zmeniť obal `Sketchup.require` — §5.1) a STANDARD §13 proti aktuálnemu mainu**; rozdiel meniaci zámer → STOP a otázka.
3. Q1 (predvolené pravidlá kovania tým istým vzorom) = **nie** (zásobník Po V1); `hardware_rules.rb` sa nemení.

## Len H15a navyše
- `PACKAGE_H15.md` + `AUDIT_H15_raw.md` → `SYSTEM/zdroje/bloky/HARDENING/`; tento brief → `briefy/BRIEF_H15.md` s úvodným riadkom
  „> Kópia zadania zo scratchpadu (2.10.2026); autorita = súbory v priečinku bloku." a relatívnymi odkazmi (nie cesty do Temp).
- PLAN: riadok H15 rozdeliť na H15a/H15b (H15a ✅ + `PR #?`).

## Testy, uzáver
- `ruby tests/run_all.rb`, **každá JS sada zvlášť**, encoding guard; mutácie M1–M9 (+ §15 A1/A2). Golden T0 z 1. commitu sa v H15a ani H15b **neregeneruje**
  (zmena fixtúry = nález → STOP).
- H15a: in-SU `scripts\run_su_tests.ps1 -CloseWhenDone` na finálnej hlave (worktree nemá `_dev\ENGINEtests.skp` — skopíruj z `C:\APP DEV\RUBY\ENGINE\_dev\`;
  `exit 2` = počkaj; nikdy nezabíjaj SketchUp); bez runnera PR to prizná.
- Uzáver podľa §11 a CLAUDE.md: bump patch (VERSION 2×) + všetky `?v=` · odseky `hardware.md` na mieste + router `docs/ARCHITEKTURA.md` · STANDARD §13 (R4) ·
  Grep tvrdení „seed je v `hardware_sets.rb`" · STAV prepísať (max 80 riadkov) · KRONIKA navrch · PLAN ✅ + `PR #?`.
- PR popis uvedie T5 (`git diff --color-moved=zebra --color-moved-ws=allow-indentation-change main...HEAD -- noxun_engine/core`).
- Commity selektívne, trailer `Co-Authored-By` so **skutočným modelom tvojej session**.
- **Po pushi STOP** — PR neotváraj; vráť report (hlava, riadky presunu/logiky, testy, mutácie, in-SU, odchýlky). PR na pokyn orchestrátora po predrecenzii.
  **Nemerguj.** Nemeň CLAUDE.md.
