# Implementátor

> Platí spolu s jadrom [AGENTS.md](../../../AGENTS.md), [DEFINICIE.md](../DEFINICIE.md) a riadkom svojho zásahu
> v [POVINNE_CITANIE.md](../POVINNE_CITANIE.md). Postup krok za krokom (vetva, predrecenzia, PR, report) je v type agenta
> `.claude/agents/implementator*.md`, resp. v zadaní od orchestrátora.

## Karta roly

- **Účel:** urobí presne JEDNU dávku podľa zadania — kód, testy, dokumentácia, commity, push a PR; **nikdy nemerguje** (merge robí
  orchestrátor po bránach).
- **Režimy:** *dávka* · *oprava* (pokračovanie tej istej dávky po predrecenzii či review: opraví nálezy vo svojej vetve, zopakuje testy,
  pushne a ku každému nálezu uvedie hash opravy) · *shadow* (zadanie začína slovom SHADOW: benchmark bez PR, nikdy sa nemerguje).
- **Nesmie:** commit do `main` · merge · spúšťať ďalších agentov (predrecenziu spúšťa orchestrátor) · testovať mimo `_dev\ENGINEtests.skp`.
- **Zastaví sa** a vráti otázku alebo report: nejasnosť alebo rozpor v zadaní · trieda Ľ/S so skutočným diffom kódu pluginu nad 300
  riadkov ([DEFINICIE § D3](../DEFINICIE.md#d3)) · povinná predrecenzia ([§ D4](../DEFINICIE.md#d4)) → po pushi STOP pred PR · červený
  main, riziko pre zákazku, zaseknutý SketchUp alebo PC, potreba hesla či tokenu.

## Architektúra na mieste

**Architektúra sa udržiava priebežne:** dávka, ktorá mení modul, prepíše JEHO odsek v príslušnom súbore `docs/architecture/` — nikdy
nepridáva text na koniec súboru. Nový modul = nový odsek v správnom súbore **a** nový riadok v tabuľke rozcestníka
[docs/ARCHITEKTURA.md](../../../docs/ARCHITEKTURA.md) (guard test to stráži).

<a id="verzia"></a>

## Verzia a uzáver dávky

- `VERSION` žije na 2 miestach: `noxun_engine.rb` (autorita) + `noxun_engine/main.rb` (fallback) — synchro stráži guard test.
- **Každý PR meniaci kód pluginu = bump patch** (0.5.0 → 0.5.1); **minor = výhradne uzáver bloku z `SYSTEM/PLAN.md`** (0.5.x → 0.6.0).
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
- **Checklist dokumentačného PR:** odsek navrch „Záznamy dávok" v KRONIKE **áno**; keď PR mení stav bloku, smoke alebo poradie prác,
  STAV **aktualizuje faktický stav v sekcii „Stav"** (verzia a čísla testov sa nemenia) **a prepíše „Robí sa" a „Ďalší krok"**; VERSION
  ani `?v=` **nie**.
- **Číslo PR** (všade, kde ho dávka píše — PLAN, KRONIKA, STAV, `DOGFOODING_vyriesene`): pred `gh pr create` sa píše `PR #?`; hneď po
  vytvorení PR ho doplní samostatný commit, ktorý mení len číslo — **skriptom `scripts\otvor_pr.ps1`**, ktorý PR aj ten commit urobí
  jedným príkazom (kvótová brána, `gh pr create`, nahradenie len na riadkoch pridaných vetvou, commit s `-CoAuthor`, push; `-WhatIf` =
  suchý beh; použitie v hlavičke skriptu). Ručný postup (`gh pr create`, potom samostatný commit s číslom) ostáva ako záloha.

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
- **Fotenie okien (UI dávky):** `powershell -NoProfile -File scripts\ui_foto.ps1` nafotí Inspector (bez výberu + kontexty Korpus, Zóny,
  Čelá, Kovanie) a všetkých 14 sekcií Štúdia z **nahrávky reálnych dát pluginu** prehranej v aktuálnom UI checkoutu (headless Chrome,
  aj pri zamknutej obrazovke) + verzie na celú výšku + kontaktný hárok `index.html`. **Každá UI dávka:** po zmene JS/CSS/HTML `-Shoot`
  (predvolený, nad poslednou **úspešnou** nahrávkou — so značkou `NAHRAVKA_OK.txt`; staršie nahrávky bez značky len cez
  `-Rec <priečinok>`; keď úspešná nahrávka ešte nie je, začni `-Record`); po zmene **tvaru dát z Ruby** (payload okna) `-Record` — nová
  nahrávka v SketchUpe overenou slučkou runnera nad kópiou ENGINEtests.skp, zdieľa jeho zámok (`exit 2` = iný beh beží), inštancia sa
  zavrie sama — a hneď fotí. `-Only studio_cut,panel_cela` = podmnožina. Fotky idú do `%TEMP%\noxun_ui_foto\shots_<čas>_<PID>\` →
  **report orchestrátorovi → Michal; do gitu nie**. **Hranice:** statický stav (bez modálov, hoveru a rozbalených ponúk), Chrome nie CEF
  (písmo a rozbaľovačky sa môžu líšiť), svetlá téma; fotka s červeným pásom = prehranie nahrávky v novom UI zlyhalo (karta v hárku
  CHYBA) — nová nahrávka alebo oprava UI, nie tichá fotka.
- **Export test (výrobné dávky exportov):** `powershell -NoProfile -File scripts\export_test.ps1 [-Base <ref>] [-Model <.skp>] [-KeepWork]`
  sám urobí 4 exporty Štúdia (VEPO, CSV kovania, XLSX rozpočtu, XLSX ponuky) nad kópiou testovacej zákazky **raz na `-Base` (K,
  predvolene `origin/main`) a raz na aktuálnom checkoute (P)** a vypíše `EXPORT-TEST: P == K` / `P != K` + zoznam rozdielov a porovnanie
  viet statusu; exit 0 = zhodné, 1 = rozdiel alebo chyba behu, 2 = zamok (iný beh). Model predvolene `_dev\export_test\zakazka.skp`
  (gitignorované; názov zákazky sa odvodí z mena súboru, preto ho nemeň). Beží pod zámkom `deploy.lock` ako runner a foto okien (nesmie
  kolidovať), profil `%APPDATA%\NOXUN` sa len skopíruje (K aj P dostanú rovnakú čerstvú kópiu, reálny sa nemení), SketchUp sa ukončí sám
  (proces sa nezabíja), na konci ostane nasadený P. **Brána mergu:** dávka, ktorá mení VEPO, CSV kovania, XLSX rozpočtu či ponuky alebo
  ich cestu (`ExportPrep`, `do_*`, zapisovače, `Bom`/rozpočet vo vstupe exportov), musí dať `P == K`, resp. len **vedomé rozdiely uvedené
  v PR**. Povolené rozdiely: riadky `Verzia:`/`Dátum:` vo VEPO LOGu, čas v 1. riadku CSV kovania, dátum v názve; všetko ostatné (aj XLSX
  bajt po bajte po rozbalení) je rozdiel. **Nahrádza ručné exporty R9** — Michal ich už nerobí. Sonda `tests/sketchup/su_export_probe.rb`
  volá `ProductionCore.do_*`; nový export dostane riadok v `ExportPrep::KINDS` aj v sonde (guard `test_export_compare.rb`).
- **Lokálne hooky (`.claude/settings.json`):** PostToolUse po každom Edit/Write spustí `.claude/hooks/post_edit_check.ps1` — kontrola
  editovaného súboru: `ruby -c` syntax (.rb) + encoding guard (.rb/.js/.html/.css/.md/.ps1: BOM, UTF-8, mojibake, C0/C1/NUL, cyrilické
  homoglyfy, charset) — **jediná implementácia `scripts/encoding_guard.rb`**, ktorú volá aj CI test `tests/pure/test_encoding_guard.rb`
  nad celým repom (pravidlá sa menia len tam; ručne `ruby scripts/encoding_guard.rb --repo`). Je to rýchla spätná väzba (edit už je
  zapísaný — pri hláške chybu HNEĎ oprav); vynucovanie ostáva na CI. **Pripomienka po mergi** (`.claude/hooks/po_merge.js`, PostToolUse
  na Bash s filtrom `gh pr merge`): po `gh pr merge <N>` vloží hlavnému agentovi vecné konštatovanie v dvoch riadkoch: „PR #N menil
  plugin: áno/nie" (z `gh pr view`) a „Nasadený je <vetva> <sha> (<čas>) → inštalácia mainu je potrebná / nie je potrebná" (zo značky
  nasadenia a porovnania pluginu s `origin/main`; chýbajúca značka alebo neznámy stav = „potrebná"). Sama nič nespúšťa, pri chybe mlčí
  a príkaz nikdy neblokuje. Filtruje si príkaz sám (v settings je len matcher Bash, bez poľa `if`); živé spustenie z Claude Code sa overí
  pri prvom reálnom merge. Ukazovateľ kontextu: [ORCHESTRATOR.md](ORCHESTRATOR.md).
- Interaktívny kanál: MCP `mcp__vbo-sketchup__execute_ruby` (SketchUp 2026 + VBO SkAgent, port 7891); fallback file-bridge
  (`vbo_sk_agent\bridge\command.rb` → `result.json`, pozor na mtime pascu); overená slučka `-RubyStartup skript + kópia modelu` (vzor
  v `scripts\run_su_tests.ps1`). Deploy: `INSTALL_noxun_engine.ps1`.
- **Diagnostika MCP:** pri visiacom/zamrznutom porte 7891 spusti `scripts\skagent_doctor.ps1` — zistí držiteľa portu a `/health`, `-Kill`
  odstráni zamrznutý bridge (živú zákazku ani cez `-Force` nezabije). Dump stavu enginu pre bugcatch: `Noxun::Engine::Debug.report` cez
  `execute_ruby` (model + výber + stav panela ako read-only JSON, nikdy nezapisuje).
- **Testuje sa VÝHRADNE v testovacom projekte `_dev\ENGINEtests.skp`** (alebo neuloženom Untitled okne BEZ existujúcich NOXUN korpusov)
  — v ňom môžu agenti tvoriť/mazať čokoľvek. `_dev/` je gitignorované, preto ho **vo worktree nie je** — skripty (`run_su_tests.ps1`,
  `ui_foto.ps1`, `export_test.ps1`) model aj zákazku berú z `_dev` aktuálneho checkoutu a keď tam nie je, z **hlavného checkoutu**
  (`scripts\lib\nx_paths.ps1`); keď chýba aj tam, hláška menuje obe skúšané cesty. `run_su_tests.ps1 -DryRun` len vyhľadá SketchUp
  a model (nič nespustí).
- **NIKDY netestovať v okne so zákazkou** — pred testami vždy overiť `model.path`/titul okna (bridge vykonáva príkazy v každom okne, kde
  je zapnutý — bridge zapínať len v testovacom okne).
