# Noxun Engine — pravidlá práce v repe

SketchUp Ruby plugin — parametrický nábytkársky systém (korpusy, zóny, čelá, materiály/ABS, kovanie, výstupy).
GitHub: https://github.com/michalmoronga-alt/noxun-panel

## Povinné čítanie podľa typu práce

**Nájdi riadok svojho zásahu a uvedené dokumenty si prečítaj PRED prácou.** Je to povinnosť, nie odporúčanie: automaticky sa načíta LEN tento súbor — architektúra, štandard ani pravidlá kódu nie. Neprečítaný riadok = zásah naslepo.

| Ideš robiť… | Pred prácou POVINNE prečítaj |
|---|---|
| **novú dávku · plánovanie · zadanie** | [SYSTEM/STAV.md](SYSTEM/STAV.md) (kde projekt je) → [SYSTEM/PLAN.md](SYSTEM/PLAN.md) (blok, do ktorého dávka patrí) → skupinu toho bloku v [SYSTEM/DOGFOODING.md](SYSTEM/DOGFOODING.md) (plné znenia D-čísel) |
| **zmenu Ruby kódu — core / modules** | [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) — odseky **dotknutých modulov** (nájdeš ich Grepom podľa mena súboru) + dotknuté § [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) |
| **buildery · observery · undo · geometriu** | ARCHITEKTURA (`construction`, `cabinet_builder`, `board_builder`, `zone_tree`, `scale_observer`) + [docs/SKETCHUP_PRAVIDLA.md](docs/SKETCHUP_PRAVIDLA.md) + STANDARD §3, §4, §9. **In-SketchUp testy sú tu POVINNÉ** (`scripts\run_su_tests.ps1`) — headless sada geometriu ani undo neoverí |
| **UI — panel, HTML, JS, CSS, satelitné okná** | [docs/UI_DIZAJN.md](docs/UI_DIZAJN.md) (pri KAŽDEJ UI práci) + ARCHITEKTURA sekcia „UI — Inspector + satelity" + **cache-bust pravidlo** nižšie (`?v=` = presne VERSION) + trvalé pravidlo **„vertikálny priestor panela je vzácny"** ([SYSTEM/PLAN.md](SYSTEM/PLAN.md), sekcia Trvalé UI/UX pravidlo) |
| **materiály · ABS · katalóg · Demos** | ARCHITEKTURA — `materials`, `materials_*` split, `materials_migration`, `materials_health`, `abs_rules`, `demos/` + [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) **§7 Materiály a ABS** |
| **kovanie — pravidlá, sety, katalóg** | ARCHITEKTURA — `hardware_rules`, `hardware_catalog` + [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) **§6 Kovanie** |
| **výstupy — VEPO, kusovník, nákup, CSV/XLSX** | [SYSTEM/VEPO_KONTRAKT.md](SYSTEM/VEPO_KONTRAKT.md) + ARCHITEKTURA (`build_plan`, `part_keys`, `validation`) + STANDARD §8 a §11 |
| **bugfix · diagnostiku · „prečo to padá"** | mapa „Kam sa pozrieť" v [SYSTEM/STAV.md](SYSTEM/STAV.md) → odsek dotknutého modulu v ARCHITEKTURE → pri otázke **„prečo je to takto?"** [SYSTEM/archiv/KRONIKA.md](SYSTEM/archiv/KRONIKA.md) a [SYSTEM/archiv/DOGFOODING_vyriesene.md](SYSTEM/archiv/DOGFOODING_vyriesene.md) |
| **testy — novú sadu alebo úpravu** | sekcia **Testovanie** nižšie + vzory v `tests/pure/`, `tests/js/`, `tests/sketchup/` (nová sada = štruktúra najbližšej existujúcej, nie vlastný formát) |
| **code review · audit návrhu** | [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) (kontrakt, proti ktorému sa posudzuje) + ARCHITEKTURA odseky dotknutých modulov + skill `codex-audit` |
| **dynamické komponenty (DC)** | [docs/DC_PRAVIDLA.md](docs/DC_PRAVIDLA.md) — vždy a bez výnimky (draho zaplatené pasce) |

Keď zásah spadá do viacerých riadkov, platia VŠETKY. **Architektúra sa udržiava priebežne:** dávka, ktorá mení modul, prepíše JEHO odsek v [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) — nikdy nepridáva text na koniec súboru.

## Git workflow (záväzné od 16.7.2026, revízia RETRO 12.8.2026)

- **Žiadne priame commity do `main`.** Každá zmena: **vetva → commity → PR → Codex review → merge po splnení brán** (nižšie).
- **Merge robí Claude** (`gh pr merge <N> --merge --match-head-commit <SHA>` — pripnutá presne tá hlava, ktorá prešla bránami) po splnení OBOCH brán **pre aktuálnu hlavu vetvy**: **CI zelené** + **review kolo uzavreté**. Po KAŽDOM fix pushi beží nové review kolo — nikdy nemergovať hneď po pushi opráv len preto, že CI zbehlo skôr než Codex. Po mergi **návrat na čerstvý `main`** (`git checkout main && git pull`) — ďalšia dávka štartuje odtiaľ. Michalov merge klik odpadá (rozhodnutie RETRO 12.8.); vetvy na GitHube maže repo automaticky. Detailný postup: skill `codex-po-pr`.
- Vetvy pomenúvať `feat/<krátky-popis>`, `fix/<popis>`, `docs/<popis>` (napr. `feat/v03-materialy`).
- PR popis po slovensky: čo sa mení z pohľadu používateľa + ako testované (SkAgent/MCP výsledky). Malé PR > obrie PR — deliť po celkoch.
- Commit messages: vecné, slovensky/anglicky konzistentne s históriou, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Paralelné úlohy: každá vo vlastnej vetve (agenti: worktree izolácia), konflikty rieši integrácia pred PR.
- **Codex kontrolné body (risk-based od 12.8.):** skill `codex-audit` PRED implementáciou je povinný **LEN** pre dávky meniace **dátový kontrakt, schému, migráciu, observer/undo lifecycle** alebo pridávajúce **nový modul** — rozhoduje OBSAH zásahu, nie žáner dávky (aj „fix" observera je audit-povinný). Fix, docs a UI dávky, ktoré sa žiadnej z vymenovaných oblastí nedotýkajú, idú rovno do implementácie (v prostredí bez Codex CLI krok neblokuje — ohlás a pokračuj). Skill `codex-po-pr` PO odoslaní PR je povinný **bez výnimky**. **Pravidlo 3 kôl:** ak review ide do 3. kola opráv, PR bol zle narezaný — zavrieť a rozdeliť, nie iterovať (lekcia PR #93). Oba skilly v `.claude/skills/`.
- **Autonómne bloky (od 12.8.):** Michal ráno odsúhlasí blok dávok; tie sa spracúvajú **sekvenčne bez čakania na pokyn medzi dávkami** — každá štartuje z čerstvého `main` po mergi predchodcu (nestackovať). Na konci bloku **denný report** (zrozumiteľný z mobilu, bez čítania diffu): čo je v maine · čo čaká a prečo · čo zlyhalo · čo večer otestovať. Výber a poradie práce určuje Michal (PLAN.md) — agent si sám dávky nevyberá.

## Verzia a uzáver dávky (od v0.5.0)

- `VERSION` žije na 2 miestach: `noxun_engine.rb` (autorita) + `noxun_engine/main.rb` (fallback) — synchro stráži guard test.
- **Každý PR meniaci kód pluginu = bump patch** (0.5.0 → 0.5.1); **uzáver etapy (bloku v `SYSTEM/PLAN.md`) = bump minor** (0.5.x → 0.6.0).
- **Cache-bust:** každý `?v=` v `ui/*.html` = presne VERSION (stráži guard test; CEF cachuje css/js). Zmena css/js ⇒ bump verzie ⇒ prepísať všetky `?v=`.
- **Checklist uzáveru dávky:** bump VERSION (2×) + `?v=` → testy zelené → **odsek dotknutého modulu v `docs/ARCHITEKTURA.md` aktualizovaný na mieste** → vyriešené D-čísla do `SYSTEM/archiv/DOGFOODING_vyriesene.md` (plný text + PR) → zápisník `SYSTEM/DOGFOODING.md` (jednoriadkový index) → **prepíš `SYSTEM/STAV.md` + APPEND odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md` + aktualizuj blok v `SYSTEM/PLAN.md`** → README pri uzávere etapy.

## Špecifikácia a kontext (všetko v tomto repe)

- **Záväzný štandard dát:** [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) (dictionary NOXUN, mm Float, roly, regenerate pattern)
- **Architektúra modulov (core / modules / ui) + kľúčové invarianty:** [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) — JEDINÉ miesto, kde architektúra žije; číta sa pri práci na kóde podľa tabuľky vyššie
- **Kde projekt je (čítaj ako prvé):** [SYSTEM/STAV.md](SYSTEM/STAV.md) · plán a bloky prác: [SYSTEM/PLAN.md](SYSTEM/PLAN.md) · história dávok: [SYSTEM/archiv/KRONIKA.md](SYSTEM/archiv/KRONIKA.md) · dogfooding zápisník: [SYSTEM/DOGFOODING.md](SYSTEM/DOGFOODING.md) · UI vízia: [SYSTEM/UI_VIZIA.md](SYSTEM/UI_VIZIA.md)
- **Glosár pojmov + stolárske poznatky:** [SYSTEM/POJMY.md](SYSTEM/POJMY.md) — jednotný jazyk sedení a fakty domény (postforming, formáty, hrúbky, ABS obchodné hodnoty); trvalé poznatky z hlásení zapisovať SEM
- **Historické dokumenty (uzavreté rozhodnutia, plné texty hotových etáp a vyriešených postrehov):** [SYSTEM/archiv/](SYSTEM/archiv/)
- **Pravidlá SketchUp kódu:** [docs/SKETCHUP_PRAVIDLA.md](docs/SKETCHUP_PRAVIDLA.md) · DC pasce: [docs/DC_PRAVIDLA.md](docs/DC_PRAVIDLA.md) · UI dizajn: [docs/UI_DIZAJN.md](docs/UI_DIZAJN.md) — kompletné a samostatné v tomto repe. (Nadradený `..\CLAUDE.md` existuje len v Michalovom lokálnom workspace `C:\APP DEV\RUBY` — mapa ostatných pluginov; pre prácu v tomto repe nie je potrebný.)

## Testovanie (záväzné pravidlá)

- **Automatické testy (V0.3.4+):** headless sada `ruby tests/run_all.rb` beží v GitHub Actions na každý push/PR (1664 testov k PR #209; lokálne `scripts\run_tests.ps1`, vyžaduje standalone Ruby v `C:\Ruby32-x64`) + **JS sady** (55 sád k v0.7.44) — spúšťať KAŽDÚ zvlášť, bash: `for f in tests/js/test_*.js; do node "$f" || exit 1; done` (POZOR: `node tests/js/test_*.js` spustí len PRVÝ súbor, zvyšok sú preň argumenty; CI ich spúšťa všetky — lokálne tiež všetky, nie len test_expr). In-SketchUp runner `scripts\run_su_tests.ps1` (deploy → inštancia nad kópiou ENGINEtests.skp → poll → výsledok; ~140 scenárov; výsledkový grep až PO dobehu — output sa dopisuje) — spúšťať pri zmenách builderov/observerov; overuje geometriu plán↔model a undo scenáre.
- **Lokálne hooky (od 24.7., `.claude/settings.json`):** PostToolUse po každom Edit/Write spustí `.claude/hooks/post_edit_check.ps1` — kontrola editovaného súboru: `ruby -c` syntax (.rb) + encoding guard UTF-8/BOM/mojibake (.rb/.js/.html/.css/.md/.ps1, rovnaká logika ako `tests/pure/test_encoding_guard.rb`). Je to rýchla spätná väzba (edit už je zapísaný — pri hláške chybu HNEĎ oprav); vynucovanie ostáva na CI.
- Interaktívny kanál: MCP `mcp__vbo-sketchup__execute_ruby` (SketchUp 2026 + VBO SkAgent, port 7891); fallback file-bridge (`vbo_sk_agent\bridge\command.rb` → `result.json`, pozor na mtime pascu); overená slučka `-RubyStartup skript + kópia modelu` (vzor v `scripts\run_su_tests.ps1`). Deploy: `INSTALL_noxun_engine.ps1`.
- **Diagnostika MCP (V0.4.7+):** pri visiacom/zamrznutom porte 7891 spusti `scripts\skagent_doctor.ps1` — zistí držiteľa portu a `/health`, `-Kill` odstráni zamrznutý bridge (živú zákazku ani cez `-Force` nezabije). Dump stavu enginu pre bugcatch: `Noxun::Engine::Debug.report` cez `execute_ruby` (model + výber + stav panela ako read-only JSON, nikdy nezapisuje).
- **Testuje sa VÝHRADNE v testovacom projekte `_dev\ENGINEtests.skp`** (alebo neuloženom Untitled okne BEZ existujúcich NOXUN korpusov) — v ňom môžu agenti tvoriť/mazať čokoľvek. `_dev/` je gitignorované.
- **NIKDY netestovať v okne so zákazkou** — pred testami vždy overiť `model.path`/titul okna (bridge vykonáva príkazy v každom okne, kde je zapnutý — bridge zapínať len v testovacom okne).
