> Zadanie orchestrátora (Claude Opus 5.5), 11.10.2026. Rozhodnutie Michala 11.10.2026: „Nástroj export testu" = samostatná dávka bloku 9 PRED uzáverom;
> tlačidlo „Exportovať všetko" zapísať ako D-číslo (zásobník).

# Brief — dávka H19 · nástroj export testu (blok 9 HARDENING) — trieda S, plugin bez zmeny

## Prečo (funkčne)
Pri výrobných dávkach exportov (H17a, H17b) platila brána **R9 „P == K"**: Michal ručne urobil 4 exporty testovacej zákazky na starej verzii (K)
a na novej (P), orchestrátor ich porovnal. Michal to robil ~3× a chce to automaticky. **Nástroj** spraví oba behy sám a vypíše verdikt — Michal nerobí nič.
Prototyp existuje a **11.10. overil H17b** (P == K): `scratchpad\kp\export_kp.ps1`, `scratchpad\kp\export_probe.rb`, `scratchpad\h17_compare.py`
(cesty nižšie) — prečítaj ich, sú to tvoje východiská, nie hotový kód (Python v repe nechceme, porovnávač prepíš do Ruby).

Scratchpad orchestrátora: `C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE--claude-worktrees-noxun-engine-continuation-c26145\c1ba8f81-869d-493c-9299-0fe634e23383\scratchpad\`

## Povinné čítanie
1. `CLAUDE.md` — sekcia **Testovanie** (runner, `-CloseWhenDone`, zámok `deploy.lock` + sentinel `last_run.txt`, `exit 2`, nikdy nezabíjať proces) a Git workflow.
2. `scripts/run_su_tests.ps1` (celý — vzor zámku, sentinelu, bootu cez `-RubyStartup`, izolácie `ENV['APPDATA']`, escapovania ciest, čakania na zánik procesu).
3. `SYSTEM/archiv/bloky/HARDENING/PACKAGE_H17.md` — **§00** a **### R9** (pravidlá porovnania: povolený rozdiel len `Verzia:`/`Dátum:` vo VEPO LOGu,
   čas v 1. riadku CSV kovania, dátum v názve XLSX; XLSX = rozbalené `xl/**/*.xml` + `[Content_Types].xml` bajtovo; žiadne masky — výnimky menovite).
4. Vzor testu nástroja: `tests/pure/test_ui_foto.rb`; harness exportov `tests/pure/h17_harness.rb` (ako sa volajú `ProductionCore.do_*` a `expect`).
5. **NEČÍTAJ** nič z `C:\Users\PC\.codex\worktrees\h17-export-porovnanie\` ani `_dev\h17_root_review\` (zrušené H17-0).

## Čo spraviť
**A. `scripts/export_test.ps1`** (ASCII, PS 5.1):
- Parametre: `-Base <git ref>` (predvolene `origin/main`), `-Model <cesta .skp>` (predvolene `_dev\export_test\zakazka.skp`; keď chýba → jasná hláška, čo
  tam dať), voliteľne `-KeepWork`. **P = aktuálny checkout repa** (to, čo sa testuje), **K = `-Base`** (dočasný `git worktree add --detach` do krátkej cesty
  v `%TEMP%`, po behu `git worktree remove`; nikdy nemeniť checkout používateľa).
- Pod **tým istým zámkom a sentinelom ako runner** (`%TEMP%\noxun_su_tests\deploy.lock`, `last_run.txt`; `exit 2` = iný beh) — beh nesmie kolidovať s in-SU ani ui_foto.
- **Snímka profilu raz na začiatku:** `%APPDATA%\NOXUN` → `%TEMP%\nxkp\<beh>\snap` (len čítanie zdroja; pozor na **MAX_PATH** — prototyp padol na dlhej ceste
  v scratchpade, preto krátky koreň); každý beh K/P dostane **čerstvú kópiu** snímky ako `ENV['APPDATA']` → oba behy majú identické dáta a reálny profil sa nemení.
- Každý beh: deploy (`INSTALL_noxun_engine.ps1` z daného stromu) → kópia modelu **pod rovnakým menom súboru** v oboch behoch (názov zákazky sa odvodí z mena
  súboru) → SketchUp `-RubyStartup boot.rb "<model>"` → sonda → koncový marker → SketchUp sa ukončí **sám** (proces sa nezabíja; čakať na zánik max 120 s).
- Na konci ostane nasadený **P** (ako runner) — vypíš to.
- Výstup: verdikt `EXPORT-TEST: P == K` / `EXPORT-TEST: P != K` + zoznam rozdielov + porovnanie **viet statusu** všetkých 4 exportov (cesty normalizované) + cesta k pracovnému priečinku.
  Exit 0 = zhodné, 1 = rozdiel alebo chyba behu, 2 = zámok.

**B. `tests/sketchup/su_export_probe.rb`** — sonda (z `export_probe.rb`): počká na init pluginu, nahradí `UI.select_directory` / `UI.savepanel` (vráti výstupný
priečinok / `priečinok/<navrhnuté meno>`, zaznamená štartovací priečinok), zloží `expect` zo servera (ako okno: `project_name`, `merge_18_36`, `name_source`),
pri rozpočte a ponuke `confirm_unpriced` podľa `unpriced_count`, zavolá 4× `ProductionCore.do_*` so `status`/`repush` do logu, zapíše marker, model zavrie bez
uloženia a ukončí SketchUp. Chyba ktoréhokoľvek exportu = `FAIL:` riadok (verdikt 1). Over, že funguje na `0.17.31` aj staršej `0.17.30` (API `do_*` sa nemenilo).

**C. `scripts/export_compare.rb`** — porovnávač v Ruby (z `h17_compare.py`, pravidlá R9.3), čisté funkcie + CLI `ruby scripts/export_compare.rb K P [--exclude-input meno]`.
XLSX čítaj bez nových gemov (Ruby 3.2 má `zlib`; ZIP centrálny adresár si prečítaj sám, alebo nájdi, či plugin už nemá čítačku ZIP — Grep `Zip`/`zlib` v `noxun_engine/`).

**D. Testy:** `tests/pure/test_export_compare.rb` — zhodné stromy = zhoda; rozdiel v dielci VEPO CSV, v XML hárku, chýbajúci/nadbytočný súbor, zmena mimo
povoleného riadku LOGu = rozdiel; povolené riadky = zhoda; menovitá výnimka vstupu; strážca, že skript a sonda existujú a sonda volá všetky 4 `do_*`
(vzor `test_ui_foto.rb`). Headless sada + každá JS sada zvlášť zelené.

**E. Overenie naostro (povinné, report):** `scripts\export_test.ps1 -Base origin/main` na čistom maine (K == P, musí vyjsť **zhodné**) s modelom
`C:\APP DEV\RUBY\ENGINE\_dev\h17_baseline\K_0.17.28\TEST projekt v0.17.28.skp` (skopíruj ho do `_dev\export_test\zakazka.skp` svojho worktree — `_dev` je gitignorovaný)
a **negatívna kontrola**: dočasne (necommitnuto) zmeň v P jednu vetu exportu alebo hodnotu → nástroj musí povedať **P != K**; zmenu vráť.
Pozor: nástroj spúšťa SketchUp — v Michalovom otvorenom okne nič nerob; zámok rešpektuj.

**F. Dokumentácia:**
- `CLAUDE.md` sekcia **Testovanie**: nový odsek „**Export test (výrobné dávky exportov, od 11.10.2026)**" — čo robí, príkaz, kedy je brána (dávka, ktorá mení
  VEPO / CSV kovania / XLSX rozpočtu a ponuky alebo ich cestu → `export_test.ps1` musí dať P == K, resp. len vedomé rozdiely uvedené v PR), že nahrádza ručné R9.
- `PACKAGE_H17.md` R9: pripíš na začiatok rámček „**Od 11.10.2026 (H19) robí R9 nástroj `scripts/export_test.ps1`** — ručné exporty sa nerobia."
- `SYSTEM/PLAN.md` blok 9: nový riadok **H19 · nástroj export testu** (✅ + `PR #?`); `SYSTEM/STAV.md` — **VERSION sa nemení** (plugin bez zmeny), ale dávka mení
  stav bloku → aktualizuj „Robí sa" a „Ďalší krok" (H19 hotové; ďalej uzáver bloku v0.18.0); limit 80 riadkov / 12 kB; KRONIKA odsek navrch.
- `SYSTEM/DOGFOODING.md`, skupina **Po V1 — zásobník**: nový **D-154 · Tlačidlo „Exportovať všetko"** (Michal 11.10.2026, pri dávke H19) — jeden klik v Štúdiu,
  raz vybraný priečinok, do podpriečinka zákazky (napr. „KLINIKA 11.10.2026") padnú naraz VEPO, CSV kovania, XLSX rozpočtu aj ponuky; nová funkcia exportov
  → mockup na schválenie a plná výrobná brána; po uzávere bloku.
- Ak sa nástroje pluginu niekde v docs vymenúvajú (Grep `ui_foto.ps1` v `docs/` a `SYSTEM/WORKFLOW.md`), doplň export test na tom istom mieste.

## Hranice
- **Plugin (`noxun_engine/`) sa nemení**, VERSION ani `?v=` nie. Ak by si zistil, že to bez zmeny pluginu nejde → STOP a report.
- Zmeraj riadky nového kódu nástroja (PS + Ruby bez testov); nad ~400 ohlás.
- Vetva `feat/h19-export-test` z čerstvého `origin/main` (`915bbf0f`, v0.17.31). Commity vecne, selektívne cesty; trailer `Co-Authored-By: Claude <tvoj skutočný model> <noreply@anthropic.com>`.
- **PR otvor** (nie draft) až keď je E hotové, s výsledkom E v popise; potom samostatný commit s číslom PR namiesto `PR #?`. Nemerguj.
  Ak ti auto režim zablokuje commit/push/PR, **neobchádzaj** to — zastav sa a ohlás presne, čo zostalo.

## Report
PR, hlava, testy, výstup E (pozitív aj negatív), riadky nástroja, odchýlky.
