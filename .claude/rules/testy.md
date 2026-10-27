---
paths:
  - "tests/**"
  - "scripts/run_*.ps1"
  - "scripts/lib/**"
---

# Oblasť: testy — písanie a spúšťanie sád

> Načíta sa samo pri práci s testami a ich runnermi ([POVINNE_CITANIE.md](../../SYSTEM/pravidla/POVINNE_CITANIE.md)).

**Nová sada alebo úprava:** vzory v `tests/pure/`, `tests/js/`, `tests/sketchup/` — štruktúra najbližšej existujúcej sady, nie vlastný formát.
Brány testovania všeobecne: [IMPLEMENTATOR.md, sekcia Testovanie](../../SYSTEM/pravidla/roly/IMPLEMENTATOR.md#testovanie).

**Headless a JS sady**

- Headless `ruby tests/run_all.rb` beží v GitHub Actions na každý push/PR; lokálne `scripts\run_tests.ps1` (standalone Ruby
  v `C:\Ruby32-x64`).
- Všetky JS sady jedným príkazom `powershell -NoProfile -File scripts\run_js_tests.ps1` — spustí každý `tests/js/test_*.js` zvlášť,
  vypíše `JS: N sad, M PASS, K FAIL`, exit 1 pri zlyhaní; `-FailFast` skončí po prvom pade.
  **Pasca:** `node tests/js/test_*.js` spustí len PRVÝ súbor, zvyšok sú preň argumenty; CI robí bash slučku
  `for f in tests/js/test_*.js; do node "$f" || exit 1; done`.
- STAV drží jeden riadok posledného behu; počty testov každého behu patria do PR a KRONIKY.

**In-SU runner `scripts\run_su_tests.ps1`** (pravidlá — `-CloseWhenDone` vždy, brána mergu, paralelné behy — sú v IMPLEMENTATOR.md)

- Postup: deploy → inštancia nad kópiou ENGINEtests.skp → poll → výsledok; overuje geometriu plán↔model a undo scenáre.
- `-CloseWhenDone`: inštancia po koncovom markeri sama uloží run-kópiu modelu a ukončí sa; runner počká na zánik procesu (max 120 s)
  a nikdy nezabíja. Teardown po celej sade končí kódom 0xC0000374 až PO zapísaní výsledku — verdikt to nemení.
- Zámok: `%TEMP%\noxun_su_tests\deploy.lock` + sentinel `last_run.txt`. `exit 2` je buď iný beh, alebo visiaca inštancia, ktorá ešte
  testuje (zavri ju alebo počkaj na dobeh). Výsledky a kópia modelu sú per-beh v `run_*` priečinku.
- `_dev/` je gitignorované, vo worktree ho nie je: skripty (`run_su_tests.ps1`, `ui_foto.ps1`, `export_test.ps1`) berú model
  z `_dev` aktuálneho checkoutu, a keď tam nie je, z **hlavného checkoutu** (`scripts\lib\nx_paths.ps1`); keď chýba aj tam,
  hláška menuje obe skúšané cesty. `run_su_tests.ps1 -DryRun` len vyhľadá SketchUp a model (nič nespustí).
- Interaktívny kanál (MCP `execute_ruby`, file-bridge) a diagnostika:
  [NASTROJE_TESTOV.md, Diagnostika MCP](../../SYSTEM/pravidla/NASTROJE_TESTOV.md#mcp).
