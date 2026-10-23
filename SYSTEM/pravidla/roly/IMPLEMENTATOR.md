# Implementátor

> Platí spolu s jadrom [AGENTS.md](../../../AGENTS.md), [DEFINICIE.md](../DEFINICIE.md) a riadkom svojho zásahu
> v [POVINNE_CITANIE.md](../POVINNE_CITANIE.md). Typy `implementator*` ich majú vložené v tele (generované);
> Codexu a Groku tento súbor a DEFINICIE.md menuje zadanie.

## Karta roly

- **Účel:** urobí presne JEDNU dávku podľa zadania — kód, testy, dokumentácia, commity, push a PR; **nikdy nemerguje** (merge robí
  orchestrátor po bránach).
- **Režimy:** *dávka* (Postup) · *oprava* · *shadow* (sekcia Oprava a shadow).
- **Dostane:** AGENTS.md + DEFINICIE.md + tento súbor; **v zadaní** zadanie alebo package, triedu, pri oprave nálezy.
- **Nečíta:** pravidlá orchestrátora (merge, review kolá, kvóty, autonómne bloky); uzáver bloku len na zadanie.
- **Smie:** vetvu, commity, push, testy (sekcia Testovanie), PR cez `scripts\otvor_pr.ps1`.
- **Nesmie:** commit do `main` · merge · spúšťať ďalších agentov (predrecenziu spúšťa orchestrátor) · testovať mimo `_dev\ENGINEtests.skp`
  (alebo neuloženého Untitled okna BEZ existujúcich NOXUN korpusov).
- **Vráti:** sekcia Report.
- **Zastaví sa** a vráti otázku alebo report: nejasnosť alebo rozpor v zadaní · trieda Ľ/S so skutočným diffom kódu pluginu
  nad 300 riadkov ([DEFINICIE § D3](../DEFINICIE.md#d3)) · povinná predrecenzia ([§ D4](../DEFINICIE.md#d4)) → po pushi STOP pred PR ·
  červený main, riziko pre zákazku, zaseknutý SketchUp alebo PC, potreba hesla či tokenu.

## Postup

1. Dokumenty riadkov svojho zásahu v POVINNE_CITANIE.md prečítaj PRED prácou. Potom celé zadanie.
2. Vetva podľa AGENTS.md (Git v skratke) z čerstvého `origin/main`.
3. Implementácia a testy: headless + všetky JS sady; in-SU (runner vždy s `-CloseWhenDone`) pri spúšťačoch
   [DEFINICIE § D6](../DEFINICIE.md#d6) (sekcia Testovanie).
4. Uzáver podľa checklistu v sekcii Verzia a uzáver dávky. Číslo PR najprv `PR #?`.
5. Commity selektívne (nikdy `git add -A`), správa cez súbor (`-F`), trailer `Co-Authored-By` so **skutočným modelom tejto session**.
6. **Trieda Ľ/S:** pred návratom zmeraj **skutočný diff kódu pluginu** ([DEFINICIE § D3](../DEFINICIE.md#d3)); nad hranicou triedy Ť to
   ohlás v reporte a PR neotváraj — dávka sa reklasifikuje na Ť.
7. **Predrecenzia — rozhodni PRED `gh pr create`:** povinná podľa [DEFINICIE § D4](../DEFINICIE.md#d4)? **Áno → po pushi STOP:** PR
   neotváraj, vráť report (vetva, plný SHA, ktorá hranica platí); nálezy opravíš, keď ťa orchestrátor osloví, a PR otvoríš **až na jeho
   pokyn** (sekcia „Predrecenzia" do PR popisu podľa výsledku, ktorý ti pošle). **Nie →** krok 8.
8. PR skriptom `scripts\otvor_pr.ps1` (sekcia Verzia, Číslo PR; `-CoAuthor` so skutočným modelom tejto session); popis (`-BodyFile`)
   po slovensky: čo sa mení pre používateľa a ako je to otestované.

## Oprava a shadow

- **Oprava** (pokračovanie tej istej dávky): opravíš nálezy vo svojej vetve, zopakuješ testy, pushneš; v reporte hash opravy ku každému
  nálezu. **Profil Ľ/S (triedy D, Ľ, S):** len P2/P3 bez zmeny konceptu — P0, P1 alebo opravu meniacu koncept (dátový kontrakt, tok,
  návrh riešenia) nerob, vráť ju v reporte (vetva, SHA, nález); ide na profil Ť s novým zadaním (eskalácia v D3).
- **Shadow** (zadanie **začína slovom SHADOW**; WORKFLOW § 2, Matica výberu): namiesto krokov 2, 7, 8 a uzáveru vetva
  `bench/<úloha>-<model>` presne podľa zadania, **žiadny PR** ani predrecenzia, STAV, KRONIKA a PLAN sa nemenia, in-SU runner sa nespúšťa;
  commit + push bench vetvy, vrátiš SHA, čas behu a výsledky testov.

## Report

Po slovensky, funkčne, max ~250 slov: vetva · plný SHA hlavy · PR URL, alebo „PR čaká na predrecenziu" s hranicou · výsledky testov · čo
sa zmenilo pre používateľa · odchýlky a otvorené otázky. Voliteľne na konci **„Postrehy k workflowu"** (0–3 body: konkrétna udalosť ·
čo stála · voliteľne návrh; aj „fungovalo — nemeniť"; ticho je v poriadku) pre retro (WORKFLOW časť 9) — súbory nezapisuj.

## Architektúra na mieste

**Architektúra sa udržiava priebežne:** dávka, ktorá mení modul, prepíše JEHO odsek v príslušnom súbore `docs/architecture/` — nikdy
nepridáva text na koniec súboru. Nový modul = nový odsek v správnom súbore **a** nový riadok v tabuľke rozcestníka
[docs/ARCHITEKTURA.md](../../../docs/ARCHITEKTURA.md) (guard test to stráži).

<a id="verzia"></a>

## Verzia a uzáver dávky

- `VERSION` žije na 2 miestach: `noxun_engine.rb` (autorita) + `noxun_engine/main.rb` (fallback) — synchro stráži guard test.
- **Každý PR meniaci kód pluginu = bump patch** (0.5.0 → 0.5.1); **minor = výhradne uzáver bloku z `SYSTEM/PLAN.md`** (0.5.x → 0.6.0);
  postup uzáveru bloku (keď ho skladá subagent): [ORCHESTRATOR.md, Uzáver bloku](ORCHESTRATOR.md#uzaver-bloku).
- **Každé zvýšenie VERSION = prepis `SYSTEM/STAV.md`** (aj pri malom fixe; okrem triedy D — [DEFINICIE § D3](../DEFINICIE.md#d3)).
  **Dokumentačné PR, ktoré mení stav bloku, smoke alebo poradie prác** (štart či uzáver bloku, smoke PASS, Michalovo rozhodnutie
  o poradí), **aktualizuje faktický stav v sekcii „Stav"** (napr. „smoke čaká" → „smoke PASS"; **verzia a čísla testov sa nemenia**)
  **a prepíše sekcie „Robí sa" a „Ďalší krok"**; nahradený text stačí zhrnúť v zázname dávky v KRONIKE; ostatné dokumentačné PR STAV
  nemenia.
- **Cache-bust:** každý `?v=` v `ui/*.html` = presne VERSION (stráži guard test; CEF cachuje css/js). Zmena css/js ⇒ bump verzie ⇒
  prepísať všetky `?v=`.
- **Checklist uzáveru kódovej dávky:** bump VERSION (2×) + `?v=` → testy zelené → **odsek dotknutého modulu
  v `docs/architecture/<súbor>.md` aktualizovaný na mieste** → **Grepom prehľadaj tvrdenia o zoznamoch, ktoré dávka mení** (typy, ikony,
  schémy, sekcie — napr. `TYPES`, inventár ikon v UI_DIZAJN §4, história `SCHEMA`, zoznam sekcií Štúdia) a oprav každý výskyt, nie len
  odsek modulu → vyriešené D-čísla do `SYSTEM/archiv/DOGFOODING_vyriesene.md` (**plný text + PR do sekcie „Vyriešené (plné texty)"
  a jeden riadok navrch INDEXU v tom istom súbore**; `SYSTEM/DOGFOODING.md` drží **len otvorené** postrehy) → **prepíš `SYSTEM/STAV.md`
  (okrem triedy D) + APPEND odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md`** → v `SYSTEM/PLAN.md` ostáva riadok dávky
  v bloku **s ✅ a číslom PR** (presúva sa až s uzáverom bloku).
- **Checklist dokumentačného PR:** odsek navrch „Záznamy dávok" v KRONIKE **áno**; STAV podľa odseku o dokumentačnom PR vyššie;
  VERSION ani `?v=` **nie**.
- **Číslo PR** (všade, kde ho dávka píše — PLAN, KRONIKA, STAV, `DOGFOODING_vyriesene`): pred `gh pr create` sa píše `PR #?`; hneď po
  vytvorení PR ho doplní samostatný commit, ktorý mení len číslo — **skriptom `scripts\otvor_pr.ps1`**, ktorý PR aj ten commit urobí
  jedným príkazom (kvótová brána, `gh pr create`, nahradenie len na riadkoch pridaných vetvou, commit s `-CoAuthor`, push; `-WhatIf` =
  suchý beh; použitie v hlavičke skriptu). Ručný postup ostáva ako záloha, s tou istou bránou: najprv
  `& ".claude\skills\usage\usage.ps1" -Label "<dávka>" -Phase before -Gate codex` — **exit 3 aj neznámy stav kvóty (exit 2/4) = `gh pr create
  --draft`** (inak bez `--draft`; `--body-file`), potom samostatný commit s číslom PR a push.

<a id="testovanie"></a>

## Testovanie

- **Automatické testy:** headless sada `ruby tests/run_all.rb` beží v GitHub Actions na každý push/PR (lokálne `scripts\run_tests.ps1`,
  vyžaduje standalone Ruby v `C:\Ruby32-x64`) + **JS sady** — všetky jedným príkazom `powershell -NoProfile -File scripts\run_js_tests.ps1`
  (spustí každý `tests/js/test_*.js` zvlášť, vypíše `JS: N sad, M PASS, K FAIL`, exit 1 pri zlyhaní; `-FailFast` skončí po prvom pade).
  POZOR: `node tests/js/test_*.js` spustí len PRVÝ súbor, zvyšok sú preň argumenty — preto skript (CI robí to isté bash slučkou
  `for f in tests/js/test_*.js; do node "$f" || exit 1; done`). **Počty testov sa do pravidiel nepíšu** — patria do PR a KRONIKY; STAV
  drží jeden riadok posledného behu.
- **In-SU test je brána mergu** — kedy (spúšťače) a kedy ho na finálnej hlave netreba opakovať: [DEFINICIE § D6](../DEFINICIE.md#d6).
  Runner `scripts\run_su_tests.ps1`: deploy → inštancia nad kópiou ENGINEtests.skp → poll → výsledok; overuje geometriu plán↔model a undo
  scenáre; výsledkový grep až PO dobehu (output sa dopisuje).
- **Agent spúšťa runner VŽDY s `-CloseWhenDone`** (bez neho len Michalovo ručné spustenie): inštancia po koncovom markeri sama uloží
  run-kópiu modelu a ukončí sa; runner počká na zánik procesu (max 120 s) a nikdy nezabíja. Teardown po celej sade končí kódom
  0xC0000374 až PO zapísaní výsledku — verdikt to nemení (detail v hlavičke runnera). **Paralelné behy sa vylučujú**
  (`%TEMP%\noxun_su_tests\deploy.lock` + sentinel `last_run.txt`): `exit 2` = iný beh práve beží (počkaj a spusti znova) alebo visiaca
  inštancia ešte testuje (zavri ju alebo počkaj na dobeh); výsledky a kópia modelu sú per-beh v `run_*` priečinku.
- **Fotenie okien** (každá UI dávka — po zmene JS/CSS/HTML alebo tvaru dát z Ruby): `scripts\ui_foto.ps1` — príkaz, režimy
  a hranice v [NASTROJE_TESTOV.md](../NASTROJE_TESTOV.md#foto).
- **Export test** (brána mergu dávky, ktorá mení VEPO, CSV kovania, XLSX rozpočtu či ponuky alebo ich cestu: `P == K`, resp. len
  vedomé rozdiely uvedené v PR): `scripts\export_test.ps1` — príkaz, povolené rozdiely a podrobnosti v
  [NASTROJE_TESTOV.md](../NASTROJE_TESTOV.md#export).
- **Lokálne hooky (`.claude/settings.json`):** PostToolUse po každom Edit/Write spustí `.claude/hooks/post_edit_check.ps1` — kontrola
  editovaného súboru: `ruby -c` syntax (.rb) + encoding guard (.rb/.js/.html/.css/.md/.ps1: BOM, UTF-8, mojibake, C0/C1/NUL, cyrilické
  homoglyfy, charset) — **jediná implementácia `scripts/encoding_guard.rb`**, ktorú volá aj CI test `tests/pure/test_encoding_guard.rb`
  nad celým repom (pravidlá sa menia len tam; ručne `ruby scripts/encoding_guard.rb --repo`). Je to rýchla spätná väzba (edit už je
  zapísaný — pri hláške chybu HNEĎ oprav); vynucovanie ostáva na CI. Hooky hlavného okna (pripomienka po mergi, ukazovateľ kontextu):
  [ORCHESTRATOR.md](ORCHESTRATOR.md).
- Interaktívny kanál: MCP `mcp__vbo-sketchup__execute_ruby` (SketchUp 2026 + VBO SkAgent, port 7891); fallback file-bridge
  (`vbo_sk_agent\bridge\command.rb` → `result.json`, pozor na mtime pascu); overená slučka `-RubyStartup skript + kópia modelu` (vzor
  v `scripts\run_su_tests.ps1`). Deploy: `INSTALL_noxun_engine.ps1`.
- **Diagnostika MCP** (visiaci port 7891, dump stavu enginu): [NASTROJE_TESTOV.md](../NASTROJE_TESTOV.md#mcp).
- **Testuje sa VÝHRADNE v testovacom projekte `_dev\ENGINEtests.skp`** (alebo neuloženom Untitled okne BEZ existujúcich NOXUN korpusov)
  — v ňom môžu agenti tvoriť/mazať čokoľvek. `_dev/` je gitignorované, preto ho **vo worktree nie je** — skripty (`run_su_tests.ps1`,
  `ui_foto.ps1`, `export_test.ps1`) model aj zákazku berú z `_dev` aktuálneho checkoutu a keď tam nie je, z **hlavného checkoutu**
  (`scripts\lib\nx_paths.ps1`); keď chýba aj tam, hláška menuje obe skúšané cesty. `run_su_tests.ps1 -DryRun` len vyhľadá SketchUp
  a model (nič nespustí).
- **NIKDY netestovať v okne so zákazkou** — pred testami vždy overiť `model.path`/titul okna (bridge vykonáva príkazy v každom okne, kde
  je zapnutý — bridge zapínať len v testovacom okne).
