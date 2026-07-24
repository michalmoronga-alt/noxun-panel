# Noxun Engine — pravidlá práce v repe

SketchUp Ruby plugin — parametrický nábytkársky systém (korpusy, zóny, čelá, materiály/ABS, kovanie, výstupy).
GitHub: https://github.com/michalmoronga-alt/noxun-panel

## Git workflow (záväzné od 16.7.2026)

- **Žiadne priame commity do `main`.** Každá zmena: **vetva → commity → PR → Codex auto-review → merge robí Michal** po kontrole.
- Vetvy pomenúvať `feat/<krátky-popis>`, `fix/<popis>`, `docs/<popis>` (napr. `feat/v03-materialy`).
- PR popis po slovensky: čo sa mení z pohľadu používateľa + ako testované (SkAgent/MCP výsledky). Malé PR > obrie PR — deliť po celkoch.
- Commit messages: vecné, slovensky/anglicky konzistentne s históriou, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Paralelné úlohy: každá vo vlastnej vetve (agenti: worktree izolácia), konflikty rieši integrácia pred PR.
- **Codex kontrolné body:** PRED implementáciou dávky = skill `codex-audit` (adversarial audit návrhu cez Codex CLI — povinný na Michalovom lokálnom prostredí; v prostredí bez Codex CLI/companion runtime krok NEblokuje — ohlás, že audit treba spustiť lokálne, a pokračuj); PO odoslaní PR = skill `codex-po-pr` (budík ~10 min → review thready → oprava → reply s hashom → „môžeš mergovať"). Oba v `.claude/skills/`.

## Verzia a uzáver dávky (od v0.5.0)

- `VERSION` žije na 2 miestach: `noxun_engine.rb` (autorita) + `noxun_engine/main.rb` (fallback) — synchro stráži guard test.
- **Každý PR meniaci kód pluginu = bump patch** (0.5.0 → 0.5.1); **uzáver etapy roadmapy = bump minor** (0.5.x → 0.6.0).
- **Cache-bust:** každý `?v=` v `ui/*.html` = presne VERSION (stráži guard test; CEF cachuje css/js). Zmena css/js ⇒ bump verzie ⇒ prepísať všetky `?v=`.
- **Checklist uzáveru dávky:** bump VERSION (2×) + `?v=` → testy zelené → zápisník `SYSTEM/08_DOGFOODING.md` (vyriešené D-čísla do archívu, index s PR) → roadmapa („Kde sme" + kompaktný riadok) → README pri uzávere etapy.

## Špecifikácia a kontext (všetko v tomto repe)

- **Záväzný štandard dát:** [SYSTEM/01_STANDARD.md](SYSTEM/01_STANDARD.md) (dictionary NOXUN, mm Float, roly, regenerate pattern)
- **Roadmapa a backlog postrehov:** [SYSTEM/04_ROADMAP.md](SYSTEM/04_ROADMAP.md) · dogfooding zápisník: [SYSTEM/08_DOGFOODING.md](SYSTEM/08_DOGFOODING.md) · UI vízia: [SYSTEM/07_UI_VIZIA.md](SYSTEM/07_UI_VIZIA.md)
- **Historické dokumenty (uzavreté rozhodnutia, plné texty hotových etáp a vyriešených postrehov):** [SYSTEM/archiv/](SYSTEM/archiv/)
- **Pravidlá SketchUp kódu:** [docs/SKETCHUP_PRAVIDLA.md](docs/SKETCHUP_PRAVIDLA.md) · DC pasce: [docs/DC_PRAVIDLA.md](docs/DC_PRAVIDLA.md) · UI dizajn: [docs/UI_DIZAJN.md](docs/UI_DIZAJN.md) — kompletné a samostatné v tomto repe. (Nadradený `..\CLAUDE.md` existuje len v Michalovom lokálnom workspace `C:\APP DEV\RUBY` — mapa ostatných pluginov; pre prácu v tomto repe nie je potrebný.)

## Testovanie (záväzné pravidlá)

- **Automatické testy (V0.3.4+):** headless sada `ruby tests/run_all.rb` beží v GitHub Actions na každý push/PR (372 testov k v0.5.0; lokálne `scripts\run_tests.ps1`, vyžaduje standalone Ruby v `C:\Ruby32-x64`) + **7 JS sád** `node tests/js/test_*.js` (200 testov; CI ich spúšťa všetky — lokálne tiež spúšťať všetky, nie len test_expr). In-SketchUp runner `scripts\run_su_tests.ps1` (deploy → inštancia nad kópiou ENGINEtests.skp → poll → výsledok; ~140 scenárov; výsledkový grep až PO dobehu — output sa dopisuje) — spúšťať pri zmenách builderov/observerov; overuje geometriu plán↔model a undo scenáre.
- **Lokálne hooky (od 24.7., `.claude/settings.json`):** PostToolUse po každom Edit/Write spustí `.claude/hooks/post_edit_check.ps1` — kontrola editovaného súboru: `ruby -c` syntax (.rb) + encoding guard UTF-8/BOM/mojibake (.rb/.js/.html/.css/.md/.ps1, rovnaká logika ako `tests/pure/test_encoding_guard.rb`). Je to rýchla spätná väzba (edit už je zapísaný — pri hláške chybu HNEĎ oprav); vynucovanie ostáva na CI.
- Interaktívny kanál: MCP `mcp__vbo-sketchup__execute_ruby` (SketchUp 2026 + VBO SkAgent, port 7891); fallback file-bridge (`vbo_sk_agent\bridge\command.rb` → `result.json`, pozor na mtime pascu); overená slučka `-RubyStartup skript + kópia modelu` (vzor v `scripts\run_su_tests.ps1`). Deploy: `INSTALL_noxun_engine.ps1`.
- **Diagnostika MCP (V0.4.7+):** pri visiacom/zamrznutom porte 7891 spusti `scripts\skagent_doctor.ps1` — zistí držiteľa portu a `/health`, `-Kill` odstráni zamrznutý bridge (živú zákazku ani cez `-Force` nezabije). Dump stavu enginu pre bugcatch: `Noxun::Engine::Debug.report` cez `execute_ruby` (model + výber + stav panela ako read-only JSON, nikdy nezapisuje).
- **Testuje sa VÝHRADNE v testovacom projekte `_dev\ENGINEtests.skp`** (alebo neuloženom Untitled okne BEZ existujúcich NOXUN korpusov) — v ňom môžu agenti tvoriť/mazať čokoľvek. `_dev/` je gitignorované.
- **NIKDY netestovať v okne so zákazkou** — pred testami vždy overiť `model.path`/titul okna (bridge vykonáva príkazy v každom okne, kde je zapnutý — bridge zapínať len v testovacom okne).

## Architektúra (v0.5.0)

Reťaz: `noxun_engine.rb` (loader, autorita VERSION) → `noxun_engine\main.rb` (requires, menu, logger) → core → modules → ui.

### Core (`noxun_engine/core/`)

- **units** — JEDINÉ miesto mm↔Length konverzií.
- **ids** — identifikátory entít (CAB-xxx, BRD-xxx).
- **store** — prístup k `NOXUN` dictionary.
- **part_keys** — stabilná identita dielcov + `valid?` (aj `board/` prefix).
- **build_plan** — **ZÁVÄZNÝ kontrakt plánu** (SCHEMA 2, MIN_DIM, validátor, `warnings[]`, hardware string-keyed s GENERIC_TYPES/limitmi/referenčnou integritou ownera). Geometria, kusovník aj VEPO čítajú TEN ISTÝ plán.
- **json_file_store** — atomický JSON zápis + `.bak` + cache.
- **materials** — katalóg materiálov a dedenie projekt→skrinka→dielec (projektové defaulty v NOXUN dict na MODELI).
  - CRUD katalógu (V0.4.7): server-generované ID (transliterácia, kolízie -2/-3), hrúbka existujúceho materiálu NEMENNÁ (= nový variant), delete guard (PROTECTED_SHEET_IDS + scan použitia v modeli/overridoch/dielcoch/doskách/šablónach).
  - **D-41 dekorové skupiny (V0.5-E):** dekor = strážený kľúč väzby materiál↔ABS (trim, near-match guard aj bez medzier, dekor/typ/šírka pri edite NEMENNÉ, `rename_decor` atomicky celú skupinu — ID sa nemenia, zákaz duplicitných variant identít, `catalog_revision` baseline guard okna). ABS s voliteľnou šírkou (variant = dekor+šírka+hrúbka, ID `..._22X10`); **deterministický picker** `abs_for_decor(decor, th, part_thickness)`: najmenšia šírka ≥ hrúbka+2 → univerzálna bez šírky → nil (**nikdy užšia**; tie-break abs_id; buildery odovzdávajú katalógovú hrúbku sheetu — čelá 18/19). `add_decor_batch` (parse-all-validate-all, tolerančný dedup 0,01, 1 atomický zápis; **D-42:** štruktúrované `sheet_variants[{type,thickness}]`/`edge_variants` — typ per variant, strict Float parsovanie).
  - **D-42 dodávateľské polia (V0.5-F):** `code` + `supplier` voliteľné na doske aj ABS (merge-safe, trim, prázdne = kľúč preč; duplicitný pár kód+dodávateľ vyžaduje `allow_duplicate_code` — aj pri patchi LEN dodávateľa). **Cena nil = „nezadaná" ≠ 0** (`normalize_price` — nečíslo sa odmieta, kľúč sa neukladá; batch/ensure cenu neuvádzajú). **`patch_record`** — bezpečný inline patch (PATCHABLE whitelist — identita sa patchom nikdy nemení, merge s čerstvým záznamom pred validáciou, `record_rev` baseline per RIADOK → `:conflict` pri cudzej zmene). `set_decor_manufacturer` (výrobca = vlastnosť dekoru, atomicky skupina). `model_decor_usage` (read-only scan part/board snapshotov BEZ šablón, ráta kusy s quantity — pás „Použité v projekte").
  - **Remap ABS:** `remap_edges` + `CabinetBuilder.remap_part_edge_overrides!` — ručné ABS zladené s dekorom nasledujú materiál pri KAŽDEJ zmene (dielec cez old_overrides snapshot / korpus / projektová predvoľba; kontrast a vedomé „bez ABS" nedotknuté). `ensure_edge_for_sheet` dovytvorí 1,0 pásku len zo štandardov AUTO_WIDTHS s presahom (katalógový zápis MIMO undo — vedomý kontrakt).
- **abs_rules** — pravidlové ABS defaulty podľa roly (free_panel aj rail_front/rail_back = 1 pozdĺžna 1,0 mm).
- **validation** — **kontrolný semafor (V0.5-D):** RED = materiál mimo katalógu / hrúbkový drift / nezmestí sa na platňu (s rešpektom smeru dekoru) · ORANGE = čelo/voľná doska bez ABS „skontroluj" / vypnuté kovanie (owner_part_key identita) / build warnings. JEDINÝ kanonický zoznam; deterministický dedup + counts VÝHRADNE zo servera; KONTROLA tab v okne Výroba s klik-selectom cez stabilnú identitu a fallbackom na vlastníka; sekcia KONTROLA vo VEPO LOGu; **RED nikdy neblokuje export**.
- **hardware_rules** — pravidlá kovania (V0.4): Ruby vzory `fixed`/`bands`/`fit_series` parametrizované JSON pravidlami; **projektový snapshot na modeli** (kľúč `hardware_rules` — rebuild reprodukovateľný z .skp; globál `%APPDATA%` len default nových projektov + seed-merge); `hardware_overrides` v configu korpusu s identitou (owner_part_key, generic_type, rule_id).
- **construction** — plánovač cfg→BuildPlan (kovanie sa vyhodnocuje po vyradení degenerovaných dielcov; `support_type`).
- **cabinet_builder** — regenerate; vizuál nôh ako **proxy** (kind hardware, production_class none, manufactured false — zdroj pravdy súpisu je VÝHRADNE `config.hardware[]` korpusu).
- **board_builder** — samostatná doska (V0.4.7): `kind: board`, id BRD-xxx, rola `free_panel`, config = superset dielca korpusu (kusovník/VEPO majú jeden svet); materiál snapshot z katalógu, hrúbka VŽDY z materiálu; manufactured true + production_class sheet na inštancii.
- **placement** — top-level umiestňovanie · **zone_tree** · **zones** — ghost boxy (predvolene VYPNUTÉ, klik na zóny cez 2D náhľad).
- **scale_observer** (ScaleWatch) — absorpcia scale pre kind {cabinet, board}: doska mapuje lokálne osi X→length/Y→width, Z sa zahadzuje (hrúbku riadi materiál); shear guard; scale maska `scaletool`=120 aj na definícii = čisté osi. `EngineAppObserver` notifikuje dialógy viazané na model (File>New/Open/Activate).
- **templates** — šablóny korpusov (%APPDATA% + .bak).

### Modules (`noxun_engine/modules/`)

- **shelves** — police v zónach · **fronts** — čelá fixed/auto s lockmi, „bez čela", krídla 1–4.

### UI — Inspector + satelity (`noxun_engine/ui/`, V0.4.5+)

- `panel.rb` (centrálne callbacky) + `ui/panel/*.rb` domény + `ui/js/*.js` moduly + `panel.css`.
- **Dizajn:** tokeny `--nx-*` (farby VÝHRADNE cez tokeny; `--nx-state-*` rezervované pre semafor, nemiešať s ABS/status významami) · `ui/js/icons.js` inline SVG sprite (Lucide subset + vlastné + firemné logo `#i-logo`; licencie v THIRD_PARTY_NOTICES.md) · **žiadne emoji v UI chrome — vždy sprite ikony** · pravidlá: `docs/UI_DIZAJN.md` — **čítať pri KAŽDEJ UI práci**.
- **Inspector:** kontextový obsah podľa výberu (body class `mode-insert/cab/part/board`). D-29 sticky dvojradová hlavička — rad 1 logo+identita+⚠ chip tlačidlo, rad 2 taby Korpus·Zóny·Čelá + Výroba vpravo (z-index pod modalom 60); pätička s verziou (z Ruby); ⛶ fit ako overlay v rohu náhľadu. Náhľad so zoom/pan/fit v `preview.js` (výška rastie s oknom panela, debounce prekreslenia 500 ms). Karta zóny pod náhľadom; karta dielca s omrvinkou ‹CAB›; karta Doska v `board_card.js` s guardom oneskorených zápisov (echo board_id).
- **D-08 režimové taby** Korpus·Zóny·Čelá: `data-cab-tab` atribút na body (atribút, NIE class — prežije setUiMode); tab prepína náhľad AJ sekcie cez CSS; pamätá sa cez zmeny výberu (`setCabTab` v preview.js); Korpus = kótovaný obrys; dielec vynúti zónový náhľad bez zmeny tabu; jednozónová skrinka auto-ukáže kartu Zóna (D-03).
- **Výrazy v rozmerových poliach:** `expr.js` parser bez eval (`650-36` + Enter, živý náhľad `= 614`, šípky ±1/±10); surový výraz neopúšťa JS; auto-apply s identity guardom (snapshot cabinet/board id).
- **Satelitné okná:** `rules_dialog.rb` (pravidlá kovania; baseline guard + refresh pri prepnutí modelu) · `materials_dialog.rb` (**D-42:** okno 640×560; katalóg = mriežka dlaždíc podľa výrobcu + pás „Použité v projekte" — refresh výhradne pri prepnutí modelu, `push_state` plný vs `push_catalog` echo BEZ scanu modelu; hľadanie názov/výrobca/kód/dodávateľ; klik na dlaždicu → detail dekoru s editovateľnými bunkami kód/cena/dodávateľ — patch protokol s `row_rev`, dirty bunka si baseline drží aj cez refresh, re-render neprepíše aktívny input, prázdna bunka pole VYMAŽE; batch „Nový dekor" cez preset-čipy + zapamätaná posledná sada (localStorage len UX); predvoľby projektu v `<details>` s `model_guid` guardom; guard hrúbok/typu; živý sync `NX.setMaterials` bez resetu formulára) · `templates_dialog.rb` (správa šablón, typový guard serverovo).
- **D-41 modal chýbajúcej ABS** (`absModal` v paneli): zmena materiálu/bulk olep na dekor bez použiteľnej 1,0 pásky → „Vytvoriť a pokračovať / Bez ABS / Zrušiť". JS `absUsableExists` je len UX zrkadlo — **autorita je server** (flag `create_missing_abs`, kontroly PRED katalógovým zápisom); part callbacky nesú `cabinet_id` identity guard.
- Jediný zoznam polí = `CONSTRUCTION_FIELDS` v core.js ↔ `Panel::PARAM_KEYS` (nové pole na 1+1 mieste).

**Trvalé UI pravidlo (Michal 20.7.2026): VERTIKÁLNY priestor panela je vzácny** — pred každým novým tlačidlom/poľom/riadkom POVINNE zvážiť umiestnenie do existujúceho radu, rohu náhľadu, ikony či kontextu; rast do výšky len v krajných prípadoch.

### Kľúčové invarianty

- Dáta na inštancii v `NOXUN` dictionary (config = JSON string, mm Float).
- Rebuild = 1 undo operácia s `@rebuilding` guardom; observer reakcie na krok používateľa = transparentné operácie (absorpcia scale, dedup kópie, ghost presuny).
- Recyklácia definícií podľa mena; žiadne DC vzorce.
- Plán musí prejsť `BuildPlan.validate!`.
- Kovanie sa NIKDY nečíta z geometrie (proxy) — ale z `config.hardware[]`.
- Zásahy do modelu z dialógov vždy cez guardy (baseline/typ/hrúbka) — HTML disabled nie je ochrana.
- Autorita výrobného záznamu = snapshot na entite (štandard 8.3).
