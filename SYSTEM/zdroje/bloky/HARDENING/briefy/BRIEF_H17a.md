> Zadanie orchestrátora (Claude), 9.10.2026; package a audit dávky sú v nadradenom priečinku.

# Brief — dávka H17a · spoločná príprava exportov (blok 9 HARDENING, C-06, prvý rez R-15) — trieda Ť

Si implementátor dávky **H17a** bloku 9 · HARDENING PO V1. Trieda **Ť**: audit-povinná (nový modul — audit návrhu je hotový), **výrobná/cenová**
(mení sa cesta, ktorou vznikajú VEPO, CSV kovania, XLSX rozpočtu a ponuky), predrecenzia povinná. **Pre používateľa sa nemení nič** — bajty súborov, mená,
vety, farby statusu, poradie brán.

## Vetva a štart
- Pracuj na vetve **`feat/h17a-export-prep`** (na `origin` už existuje; prvý commit nesie package, audit a tento brief). Vo svojom worktree ju checkoutni
  z `origin/feat/h17a-export-prep` — je to čerstvý `main` (`2114e1a3`, v0.17.28) + dokumentácia. Nestackuj na inú vetvu.

## Povinné čítanie (v tomto poradí)
1. `CLAUDE.md` (riadky „zmenu Ruby kódu", „výstupy", „testy"; sekcie Verzia a uzáver, Testovanie).
2. **`SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H17.md` — najprv §00** (má prednosť), potom §0–§15. Kontrakt = R0–R7 + nový R9 v §00/§6. §14b a §15 sú história
   rozhodnutí a auditu — FIX body auditu sú už zapracované v R0–R7 a sú záväzné.
3. `SYSTEM/zdroje/bloky/HARDENING/AUDIT_H17_raw.md` (audit návrhu; BLOCKER 1 a NOTE 8 sa týkajú zrušeného nástroja).
4. `docs/architecture/outputs.md` — len odseky `### production_core.rb` a `### export_settings.rb` (Grep nadpisu), `docs/ARCHITEKTURA.md` (rozcestník),
   `docs/architecture/rozsirovacie-body.md` (scenáre — pridávaš 8).
5. Vzory testov: `tests/pure/test_h7a_golden.rb` (`NxH7G`), `tests/pure/test_h7b_nazov_zakazky.rb` (`NxH7B`), `tests/pure/test_h11a_nacitanie.rb` (`MAIN_PARTS`),
   `tests/pure/test_h14_studio_sekcie.rb` (harness T0b pre G5), `tests/helper.rb`.

**NEČÍTAJ a nepoužívaj** nič z `C:\Users\PC\.codex\worktrees\h17-export-porovnanie\` ani z `_dev\h17_root_review\` — H17-0 je zrušené (§00) a ten materiál
platforma zablokovala. Baseline `_dev\h17_baseline\` sa v H17a nepoužíva.

## Čo robíš (package §2 — poradie commitov je záväzné)
1. **Golden T0 + harness** (R0): `tests/pure/h17_harness.rb`, `tests/fixtures/h17_golden/` (fixtúra + generátor + golden), `tests/pure/test_h17_golden.rb` —
   **plugin bez zmeny**, zelené na nezmenenom kóde. Čas podľa §15 A4 (`FIXED.dup`, pásmo `+02:00`). Prípad so skutočnou expanziou nad seedom: ak headless nejde,
   vypadne (R0.1) a napíš to do reportu.
2. **`noxun_engine/ui/export_prep.rb`** (R1, R2: `KINDS`, `GEN_MSG`, `FLUSH_MSG`, `start`, `Context` s lenivými čítačkami vrátane pamäte `nil`) + `main.rb`
   (`require_part` hneď za `ui/production_core`) + `MAIN_PARTS` (prepočítaj počet na dnešnom maine — package uvádza 95 → 96 k inému commitu) + `tests/helper.rb`
   + strážca načítania.
3. **Prepnutie 4 exportov** (R1.3, R3) — telo exportu začína `ctx = ExportPrep.start(…)` / `return unless ctx`; brány druhu výstupu a ich poradie ostávajú
   v exporte; komentáre úvodu sa **presunú** k `start`. **Golden T0 sa NEREGENERUJE.**
4. **Prepis strážcov** §0.3 / R5 (každý rozbitý assert nahradiť ekvivalentom, nie zmazať — zoznam do reportu) + **R4 a–f** (`tests/pure/test_h17_export_prep.rb`)
   + T1, T2, G2 nad `KINDS`, G3, G4, G5, G6.
5. **Dokumentácia a uzáver** (R7, §11): bump **0.17.28 → 0.17.29** (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`**; odsek `### export_prep.rb`
   v `outputs.md` + prepis dotknutých odstavcov `production_core.rb`/`export_settings.rb` na mieste; riadok rozcestníka `docs/ARCHITEKTURA.md`; scenár 8
   v `rozsirovacie-body.md`; `AUDIT_REGISTER.md` R-15 „prvý rez ✅ H17a (PR #?)"; Grep zoznamov („VSETKY STYRI exporty", „štyri exporty", „hneď po
   `fresh_collect`", „v každom zo štyroch exportov"); prepis `SYSTEM/STAV.md`; odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md`; v `SYSTEM/PLAN.md`
   riadok H17 → „H17a ✅ (PR #?)", H17-0 prečiarknuté s odkazom na §00, H17b ostáva voliteľná (D9, nerobíš ju).

## Poistky (STOP → report orchestrátorovi, nepokračuj)
- zmena fixtúry alebo golden T0 po commite 1 · nová logika nad čistý presun > ~60 riadkov · golden T0 sa po prepnutí exportov líši · zistenie, že kontrakt §6
  na dnešnom kóde neplatí (mimo mechanických posunov riadkov) · in-SU alebo iný zásah do SketchUpu.

## Testy (T6) a mutácie (T5)
- `ruby tests/run_all.rb` · **každá** JS sada zvlášť (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) · `ruby scripts/encoding_guard.rb --repo`.
- Mutácie **M1–M24, M26–M29** (M25, M30, M31 zrušené): každú dočasne vnes, spusti test, ktorý ju má zhodiť, zapíš výsledok, vráť. Tabuľka do reportu.
- Zmeraj skutočný diff kódu pluginu (`git diff --stat main...HEAD -- noxun_engine/`) a uveď ho.

## Čo NErobíš
- **In-SU runner nespúšťaj** — orchestrátor ho spustí sám až po ručných exportoch K od Michala (R9 §00; runner nechá nasadenú vetvu, K musí vzniknúť pred ním).
- **PR neotváraj** — predrecenzia je povinná; vetvu len **pushni**. PR otvorí orchestrátor alebo ti dá pokyn.
- H17b, `push_state`, `layout_block_reasons`, jadrá výstupov, JS, payload — mimo scope (§4).
- Nemerguj. Commit trailer `Co-Authored-By: Claude <tvoj skutočný model> <noreply@anthropic.com>`. Commity vecne, po slovensky, selektívne cesty (nie `git add -A`).

## Report (posledná správa)
Hlava vetvy (SHA) · zoznam commitov · diff pluginu (+/−) · počty testov Ruby/JS · tabuľka mutácií · zoznam prepísaných assertov R5 (pôvodný → náhrada) ·
odchýlky od package a prečo · čo vypadlo (napr. prípad skutočnej expanzie) · otvorené otázky.
