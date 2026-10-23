# Povinné čítanie podľa typu práce

> Platí pre každú rolu podľa druhu práce (rozcestník: [AGENTS.md](../../AGENTS.md)). Cesty v zátvorkách sú od koreňa repa.

**Nájdi riadok svojho zásahu a uvedené dokumenty si prečítaj PRED prácou.** Je to povinnosť, nie odporúčanie: automaticky sa načíta
len AGENTS.md (hlavné okno Claude Code cez most `CLAUDE.md` aj ORCHESTRATOR.md; typy agentov majú jadro a súbor svojej roly vložené
v tele, Codexu a Groku ich menuje zadanie) — architektúra, štandard ani pravidlá kódu sa nenačítajú. Neprečítaný riadok = zásah naslepo.

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
- **zmenu Ruby kódu — core / modules** → rozcestník [docs/ARCHITEKTURA.md](../../docs/ARCHITEKTURA.md) → odseky **dotknutých modulov**
  v `docs/architecture/` (Grep `^### <súbor>`; súbory mapy majú 47–257 kB, celé sa nečítajú) + dotknuté § [SYSTEM/STANDARD.md](../STANDARD.md)
  (Grep `^## <číslo>.` / `^### <číslo>`; celý má 170 kB)
- **buildery · observery · undo · geometriu** → odseky `construction`, `cabinet_builder`, `board_builder`, `zone_tree`, `scale_observer`
  v [docs/architecture/construction.md](../../docs/architecture/construction.md) (Grep `^### <modul>`; celý má 174 kB)
  + [docs/SKETCHUP_PRAVIDLA.md](../../docs/SKETCHUP_PRAVIDLA.md) + STANDARD §3, §4, §9. **In-SU test je tu brána mergu** (spúšťače:
  [DEFINICIE § D6](DEFINICIE.md#d6); runner: [IMPLEMENTATOR.md, sekcia **Testovanie**](roly/IMPLEMENTATOR.md#testovanie))
- **UI — Inspector, Štúdio, HTML, JS, CSS** → [docs/UI_DIZAJN.md](../../docs/UI_DIZAJN.md) **§1–§3** (norma, pri KAŽDEJ UI práci; pri ikone
  či komponente aj dotknutý §4 / §5.x) + **odsek dotknutej UI sekcie alebo modulu** v
  [docs/architecture/ui-lifecycle.md](../../docs/architecture/ui-lifecycle.md) (Grep podľa nadpisu; celý má ~257 kB) — napr. sekcia Štúdia
  `^### Sekcia ROZPOČET`, kontext Inspectora `^### Kontext Čelá`, `^### Satelitné okná` a súbor dialógu (`^### <súbor>_dialog.rb`),
  `^### D-15 modal`, `^### Paleta a téma`, `^### Veľkosť okna pri otvorení` + pri zmene stĺpcov alebo sekcií Štúdia **záväzný kontrakt
  Kusovníka** [SYSTEM/zdroje/ui20/UI20_KONTRAKT.md](../zdroje/ui20/UI20_KONTRAKT.md) (Š2 stĺpce) + **cache-bust pravidlo**
  ([IMPLEMENTATOR.md, Verzia a uzáver dávky](roly/IMPLEMENTATOR.md#verzia); `?v=` = presne VERSION) + trvalé pravidlo **„vertikálny
  priestor panela je vzácny"** (autorita UI_DIZAJN §1). Po zmene UI nafoť okná (`scripts\ui_foto.ps1`,
  [IMPLEMENTATOR.md, sekcia **Testovanie**](roly/IMPLEMENTATOR.md#testovanie))
- **materiály · ABS · katalóg · Demos** → odseky `materials`, `materials_*` split, `materials_migration`, `materials_health`, `abs_rules`,
  `demos/` v [docs/architecture/materials.md](../../docs/architecture/materials.md) (Grep `^### <modul>`; celý má 72 kB)
  + [SYSTEM/STANDARD.md](../STANDARD.md) **§7 Materiály a ABS**
- **kovanie — pravidlá, sety, katalóg** → odseky `hardware_rules`, `hardware_catalog`, `hardware_sets` v
  [docs/architecture/hardware.md](../../docs/architecture/hardware.md) (Grep `^### <modul>`; celý má 208 kB) + [SYSTEM/STANDARD.md](../STANDARD.md)
  **§6 Kovanie** (42 kB — dotknuté §6.x)
- **výstupy — VEPO, kusovník, nákup, CSV/XLSX** → [SYSTEM/VEPO_KONTRAKT.md](../VEPO_KONTRAKT.md) + odseky `validation`, `production_core`
  a dotknutého výstupu v [docs/architecture/outputs.md](../../docs/architecture/outputs.md) (Grep `^### <modul>`; celý má 163 kB) + odseky
  `build_plan`, `part_keys` v [docs/architecture/model-a-identita.md](../../docs/architecture/model-a-identita.md) + STANDARD §8 a §11.
  Po zmene exportu **export test** `scripts\export_test.ps1` ([IMPLEMENTATOR.md, sekcia **Testovanie**](roly/IMPLEMENTATOR.md#testovanie))
- **bugfix · diagnostiku · „prečo to padá"** → mapa „Kam sa pozrieť" v [SYSTEM/STAV.md](../STAV.md) → odsek dotknutého modulu
  v `docs/architecture/` (cez rozcestník [docs/ARCHITEKTURA.md](../../docs/ARCHITEKTURA.md)) → pri otázke **„prečo je to takto?"** najprv
  priečinok bloku (`SYSTEM/archiv/bloky/<BLOK>/`, `SYSTEM/archiv/<BLOK>_ZAVER_*`), potom [SYSTEM/archiv/KRONIKA.md](../archiv/KRONIKA.md)
  a [SYSTEM/archiv/DOGFOODING_vyriesene.md](../archiv/DOGFOODING_vyriesene.md) **len Grepom** podľa ID dávky alebo D-čísla (stovky kB,
  celé sa nečítajú)
- **testy — novú sadu alebo úpravu** → [IMPLEMENTATOR.md, sekcia **Testovanie**](roly/IMPLEMENTATOR.md#testovanie) + vzory v `tests/pure/`,
  `tests/js/`, `tests/sketchup/` (nová sada = štruktúra najbližšej existujúcej, nie vlastný formát)
- **code review · audit návrhu** → dotknuté § [SYSTEM/STANDARD.md](../STANDARD.md) (kontrakt, proti ktorému sa posudzuje; Grep podľa
  nadpisu) + odseky dotknutých modulov v `docs/architecture/` + skill `codex-audit` + pri review diffu pravidlá, proti ktorým sa kontroluje
  uzáver dávky: [IMPLEMENTATOR.md, Verzia a uzáver dávky](roly/IMPLEMENTATOR.md#verzia) (checklist uzáveru, číslo PR) a
  [Testovanie](roly/IMPLEMENTATOR.md#testovanie) (export test `P == K`, hlava in-SU behu)
- **dynamické komponenty (DC)** → [docs/DC_PRAVIDLA.md](../../docs/DC_PRAVIDLA.md) — vždy a bez výnimky (draho zaplatené pasce)
- **workflow · pravidlá práce · skilly** → [SYSTEM/WORKFLOW.md](../WORKFLOW.md) (roly a ich obsadenie, diagramy blok · dávka · review,
  brány, hranice) + záznam „prečo" [WORKFLOW_ROZHODNUTIA_2026-09-26.md](../zdroje/next_sessions/WORKFLOW_ROZHODNUTIA_2026-09-26.md)

Keď zásah spadá do viacerých riadkov, platia VŠETKY. **Súbor nad ~50 kB sa nečíta celý** — len kapitola alebo odsek, ktorý riadok menuje
(Grep podľa nadpisu alebo mena modulu). **Rozpočet čítania:** povinné čítanie jednej dávky je orientačne **≤ 150 kB**; keď by bolo viac,
orchestrátor dá do briefu výťah alebo presné kotvy.
