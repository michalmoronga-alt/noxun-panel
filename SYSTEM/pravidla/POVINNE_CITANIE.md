# Povinné čítanie podľa typu práce

> Platí pre každú rolu podľa druhu práce (rozcestník: [AGENTS.md](../../AGENTS.md)). Cesty v zátvorkách sú od koreňa repa.

**Nájdi riadok svojho zásahu a uvedené dokumenty si prečítaj PRED prácou.** Je to povinnosť, nie odporúčanie: automaticky sa načíta
AGENTS.md (hlavné okno Claude Code cez most `CLAUDE.md` aj ORCHESTRATOR.md; typy agentov majú jadro a súbor svojej roly vložené
v tele, Codexu a Groku ich menuje zadanie) a v Claude Code aj **súbor oblasti** `.claude/rules/<oblasť>.md`, keď agent súbor oblasti
číta (Read) alebo upravuje (Edit, Write). Architektúra, štandard ani pravidlá kódu sa inak nenačítajú. Neprečítaný riadok = zásah naslepo.

Riadok = **Ideš robiť…** → **Pred prácou POVINNE prečítaj**:

- **každú prácu** (platí vždy, pre každú rolu) → [SYSTEM/pravidla/DEFINICIE.md](DEFINICIE.md) — jediné znenie definícií, podľa ktorých sa
  rozhoduje o bránach: výrobná/cenová dávka (D1), audit-povinná dávka (D2), triedy dávok (D3), povinná predrecenzia (D4), nový ovládací
  prvok v UI (D5), in-SU test ako brána mergu (D6)
- **novú dávku · plánovanie · zadanie** → [SYSTEM/STAV.md](../STAV.md) (kde projekt je) → [SYSTEM/PLAN.md](../PLAN.md) (blok, do ktorého
  dávka patrí) → skupinu toho bloku v [SYSTEM/DOGFOODING.md](../DOGFOODING.md) (plné znenia **otvorených** D-čísel) → zadanie dávky
  v priečinku bloku `SYSTEM/zdroje/bloky/<BLOK>/` + Matica výberu v [SYSTEM/WORKFLOW.md](../WORKFLOW.md) § 2 (výber profilu
  implementátora). **Podobná funkcia už bola** → priečinok jej bloku `SYSTEM/archiv/bloky/<BLOK>/` (`ROZHODNUTIA_*`, `FAKTY_Z_KODU_*`,
  `PACKAGE_*`) a záver `SYSTEM/archiv/<BLOK>_ZAVER_*`; bloky spred tejto konvencie (napr. KOVANIE, GHOST, UI 2.0, M-R) → plný text
  v `SYSTEM/archiv/ROADMAP_hotove_etapy.md`, KRONIKA Grepom podľa ID dávky a staršie podklady v `SYSTEM/zdroje/next_sessions/`
  (`KOVANIE_*`, `GHOST_*`, `MR_*`…) a `SYSTEM/zdroje/ui20/`. Keď nevieš, ktorý dokument je autorita na čo: [SYSTEM/README.md](../README.md)
- **bugfix · diagnostiku · „prečo to padá"** → mapa „Kam sa pozrieť" v [SYSTEM/STAV.md](../STAV.md) → odsek dotknutého modulu
  v `docs/architecture/` (cez rozcestník [docs/ARCHITEKTURA.md](../../docs/ARCHITEKTURA.md)) → pri otázke **„prečo je to takto?"** najprv
  priečinok bloku (`SYSTEM/archiv/bloky/<BLOK>/`, `SYSTEM/archiv/<BLOK>_ZAVER_*`), pri bežiacom bloku záznamy dávok `SYSTEM/zdroje/bloky/<BLOK>/kronika/`, potom [SYSTEM/archiv/KRONIKA.md](../archiv/KRONIKA.md)
  a [SYSTEM/archiv/DOGFOODING_vyriesene.md](../archiv/DOGFOODING_vyriesene.md) **len Grepom** podľa ID dávky alebo D-čísla (stovky kB,
  celé sa nečítajú)
- **code review · audit návrhu** → dotknuté § [SYSTEM/STANDARD.md](../STANDARD.md) (kontrakt, proti ktorému sa posudzuje; Grep podľa
  nadpisu) + odseky dotknutých modulov v `docs/architecture/` + skill `codex-audit` + pri review diffu pravidlá, proti ktorým sa kontroluje
  uzáver dávky: [IMPLEMENTATOR.md, Verzia a uzáver dávky](roly/IMPLEMENTATOR.md#verzia) (checklist uzáveru, číslo PR) a
  [Testovanie](roly/IMPLEMENTATOR.md#testovanie) (export test `P == K` — `.claude/rules/vystupy.md`, hlava in-SU behu)
- **workflow · pravidlá práce · skilly** → [SYSTEM/WORKFLOW.md](../WORKFLOW.md) (roly a ich obsadenie, diagramy blok · dávka · review,
  brány, hranice) + záznam „prečo" [WORKFLOW_ROZHODNUTIA_2026-09-26.md](../zdroje/next_sessions/WORKFLOW_ROZHODNUTIA_2026-09-26.md)

## Pravidlá oblastí (`.claude/rules/`)

Každý súbor oblasti nesie povinné čítanie pre prácu so svojimi súbormi (architektúra, štandard, normy) a pravidlá, ktoré platia len tam.
V Claude Code sa načíta sám, keď agent otvorí súbor oblasti. **Codex, Grok a iný harness ho automaticky nedostanú — prečítaj si súbor
oblasti sám podľa tabuľky.** Ak prácu so súbormi oblasti ešte len plánuješ (zadanie, review, audit), prečítaj ho tiež.

| Ideš robiť… | Súbor | Načíta sa pri práci so súbormi |
|---|---|---|
| zmenu Ruby kódu — core / modules | `.claude/rules/kod.md` | všetky `noxun_engine/**/*.rb`, `noxun_engine.rb` |
| buildery · observery · undo · geometriu | `.claude/rules/konstrukcia.md` | buildery, zóny, observery, nástroje (`tools/`), `modules/`, `data/recipes/`, akcie panela a dialógy so `start_operation`; práca s observerom alebo operáciou (`start_operation`) inde → súbor si prečítaj sám |
| UI — Inspector, Štúdio, HTML, JS, CSS | `.claude/rules/ui.md` | `noxun_engine/ui/**`, `tests/js/**`, fotenie okien (`scripts/ui_foto*`) |
| materiály · ABS · katalóg · Demos | `.claude/rules/materialy.md` | `core/materials*.rb`, `abs_rules.rb`, `appearance_mapping.rb`, `core/demos/`, dialógy materiálov |
| kovanie — pravidlá, sety, katalóg | `.claude/rules/kovanie.md` | `core/hardware_*.rb`, `drawer_recipes.rb`, dialógy kovania a pravidiel |
| výstupy — VEPO, kusovník, nákup, CSV/XLSX | `.claude/rules/vystupy.md` | VEPO, BOM, CP, XLSX, CSV kovania, validácia, plán a kľúče dielcov, rozpočet, `sheet_*`, `production_core`, `export_prep`, `studio_dialog`, export test; generátor exportu inde → súbor si prečítaj sám |
| testy — novú sadu alebo úpravu | `.claude/rules/testy.md` | `tests/**`, `scripts/run_*.ps1`, `scripts/lib/**` |
| dynamické komponenty (DC) | `.claude/rules/dc.md` | `board_builder.rb`, `cabinet_builder.rb`, `tools/mower.rb`, `docs/DC_PRAVIDLA.md`; práca s DC inde → [docs/DC_PRAVIDLA.md](../../docs/DC_PRAVIDLA.md) vždy |

Presné cesty (`paths:`) sú v hlavičke každého súboru. Keď zásah spadá do viacerých riadkov alebo oblastí, platia VŠETKY.
**Súbor nad ~50 kB sa nečíta celý** — len kapitola alebo odsek, ktorý riadok menuje (Grep podľa nadpisu alebo mena modulu).
**Rozpočet čítania:** povinné čítanie jednej dávky je orientačne **≤ 150 kB**; keď by bolo viac, orchestrátor dá do briefu výťah alebo
presné kotvy.
