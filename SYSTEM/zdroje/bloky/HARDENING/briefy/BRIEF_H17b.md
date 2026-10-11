> Zadanie orchestrátora (Claude Opus 5.5), 11.10.2026; package a audit dávky sú v nadradenom priečinku. Rozhodnutie Michala 11.10.2026: „H17b áno".

# Brief — dávka H17b · koniec exportu (blok 9 HARDENING, C-06, R-15) — trieda Ť

Si implementátor dávky **H17b** bloku 9 · HARDENING PO V1. Trieda **Ť**: **výrobná/cenová** (mení sa cesta, ktorou vznikajú VEPO, CSV kovania,
XLSX rozpočtu a ponuky), audit návrhu je hotový (`AUDIT_H17_raw.md` pokryl celý package vrátane R8), **predrecenzia povinná**.
**Jediná vedomá zmena správania = N1:** keď uložený „posledný priečinok exportu" neexistuje alebo nie je text, CSV kovania a oba XLSX otvoria okno výberu
bez štartovacieho priečinka (dnes ho dostanú surový — `savepanel` môže zlyhať). Bajty súborov, mená, vety, farby statusu a poradie brán **bez zmeny**.

## Vetva a štart
- Vetva **`feat/h17b-koniec-exportu`** z **čerstvého `origin/main`** (po mergi Q1 = v0.17.30; over `git log -1 origin/main` a VERSION). Nestackuj.
- **1. commit:** skopíruj tento brief do `SYSTEM/zdroje/bloky/HARDENING/briefy/BRIEF_H17b.md` (bez úprav, docs commit).

## Povinné čítanie (v tomto poradí)
1. `CLAUDE.md` (riadky „zmenu Ruby kódu", „výstupy", „testy"; sekcie Verzia a uzáver, Testovanie).
2. `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H17.md` — **§00** (má prednosť), §0 (sondy S11, S13), §2 (rez, riadok H17b), **§6 R8** (kontrakt tejto dávky), R9,
   §7 (T0–T7, DoD), §10 bod 4, §11. Súbor má 70 kB — čítaj po kapitolách Grepom nadpisov.
3. `SYSTEM/zdroje/bloky/HARDENING/AUDIT_H17_raw.md` — len časti, ktoré sa týkajú R8 / koniec exportu / N1 (Grep `R8`, `N1`, `last_dir`, `save_last_dir`).
4. `docs/architecture/outputs.md` — odseky `### export_prep.rb`, `### export_settings.rb`, `### production_core.rb` (Grep nadpisu).
5. Kód: `noxun_engine/ui/export_prep.rb` (z H17a), `noxun_engine/ui/export_settings.rb` (~`last_dir`, `save_last_dir`, komentár „zjednotenie je H17"),
   a 4 exporty (Grep `save_last_dir`, `pending_name_note`, `default_name_note`, `savepanel`).
6. Vzory testov: `tests/pure/test_h17_golden.rb`, `tests/pure/h17_harness.rb`, `tests/fixtures/h17_golden/`, `tests/pure/test_h17_export_prep.rb`.

**NEČÍTAJ** nič z `C:\Users\PC\.codex\worktrees\h17-export-porovnanie\` ani z `_dev\h17_root_review\` (§00).

## Čo robíš (R8)
- **R8.1 `ExportPrep.start_dir`** = `ExportSettings.last_dir`, ak `String` ∧ `File.directory?`, inak `nil` — použijú **všetky 4 pickery** (VEPO dnes overuje
  samo — zjednotiť na jedno miesto bez zmeny jeho správania).
- **R8.2 `ExportPrep.remember_dir(dir)`** → `ExportSettings.save_last_dir(dir)`, výsledok ignorovaný (H7 D5) — 4 volania exportov cez neho.
- **R8.3 `ExportPrep.name_suffix(ctx)`** = `pending_name_note(model)` + `default_name_note(model, ctx.project)` + `ctx.name_note` — jedno miesto namiesto 4 kópií; farba bez zmeny.
- **R8.4** Golden: **samostatný commit „vedomá zmena N1"** — nové prípady N1 (uložený priečinok neexistuje · číslo · objekt) → CSV/XLSX štartovací priečinok `nil`;
  existujúce golden H17 **bez zmeny** (žiadna regenerácia).
- Strážcovia: test, že v exportoch už nie je priame `save_last_dir` ani skladanie viet názvu (Grep-strážca vo vzore H17a R4), testy `start_dir` / `remember_dir` / `name_suffix`.
- **Mutácie** (navrhni a spusti, tabuľka do reportu), minimálne: `start_dir` bez `File.directory?` · `start_dir` bez kontroly `String` · export obíde `start_dir` ·
  `remember_dir` sa nevolá · `name_suffix` v inom poradí častí · `name_suffix` bez `ctx.name_note`. Každá musí byť zhodená testom.
- **Uzáver** (§11): bump patch (na čerstvom maine +1, očakávane **0.17.30 → 0.17.31**) v `noxun_engine.rb` + `noxun_engine/main.rb` + **všetky `?v=`**;
  odsek `### export_prep.rb` v `docs/architecture/outputs.md` doplniť o koniec exportu **na mieste** + dotknutý odsek `export_settings.rb`; Grep tvrdení o
  „posledný priečinok", „surový", „H17b", „zjednotenie je H17" v docs a kóde a opraviť; `AUDIT_REGISTER.md` R-15 (ak eviduje rezy) doplniť H17b;
  `PACKAGE_H17.md` §10 bod 4 ostáva; `SYSTEM/PLAN.md` riadok H17 → „✅ H17b · koniec exportu — PR #?"; **prepis `SYSTEM/STAV.md`** (ďalej: H11c → uzáver bloku v0.18.0);
  odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md`.

## Poistky (STOP → report orchestrátorovi, nepokračuj)
- golden H17 (existujúce prípady) sa po zásahu líši · nová logika nad čistý presun > ~60 riadkov · R8 na dnešnom kóde neplatí (mimo posunov riadkov) ·
  zistíš, že niektorý export dnes píše inú vetu názvu, než skladá R8.3 (potom NEzjednocuj tú vetu a ohlás).

## Testy
- `ruby tests/run_all.rb` · **každá** JS sada zvlášť (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) · `ruby scripts/encoding_guard.rb --repo`.
- Zmeraj diff kódu pluginu (`git diff --stat origin/main...HEAD -- noxun_engine/`).

## Čo NErobíš
- **In-SU runner nespúšťaj** a do SketchUpu nesiahaj — runner a R9 (Michalove exporty P a porovnanie s K) robí orchestrátor.
- **PR neotváraj** — predrecenzia je povinná; vetvu len **pushni**. PR otvoríš až na pokyn orchestrátora.
- Mimo scope: F2/F3 z §14, `push_state`, jadrá výstupov, JS, payload. Nemerguj.
- Commity vecne, po slovensky, selektívne cesty (nie `git add -A`); trailer `Co-Authored-By: Claude <tvoj skutočný model> <noreply@anthropic.com>`.

## Report (posledná správa)
Hlava vetvy (SHA) · commity · diff pluginu (+/−) · počty testov Ruby/JS · tabuľka mutácií · odchýlky a prečo · otvorené otázky.
