# Package P3a — pravidlá oblastí: `.claude/rules/` s `paths:` (blok PRAVIDLA, 26.10.2026)

> **Trieda S** · profil `implementator-stredny` · **len pravidlá, dokumentácia a testy — kód pluginu sa nemení** (VERSION ani `?v=` nie).
> Dávka P3 z [PLAN.md](../../../PLAN.md) je rozdelená na dve PR: **P3a oblasti** (toto) a **P3b postupy** (skilly `uzaver-bloku` a `smoke`,
> ORCHESTRATOR.md pod strop, WORKFLOW ako mapa, nálezy hliadky) — P3b štartuje z čerstvého mainu po mergi P3a.
> Vstupy: [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 1 (riadok `.claude/rules/`), § 3 (inventúra: riadky „Povinné čítanie", „In-SU runner",
> „Fotenie okien, export test", „Lokálne hooky", „Verzia 2×"), § 5 (G1, G2) · [ROLY.md](ROLY.md) § 6 (Codex/Grok dostanú súbor oblasti
> menovaný v zadaní) · [P2_KTO_CO_DOSTANE.md](P2_KTO_CO_DOSTANE.md) (čo dnes dostane každý typ).

## 0 · Sonda (implementátor, pred prvou zmenou)

| Tvrdenie | Ako overiť | Keď neplatí |
|---|---|---|
| Claude Code načíta `.claude/rules/*.md` s frontmatterom `paths:` (zoznam globov) **až keď agent číta alebo upravuje zodpovedajúci súbor**; súbor bez `paths:` sa načíta vždy | oficiálne docs code.claude.com/docs/en/memory (sekcia o `.claude/rules/` a path-specific rules), lokálne `claude --version` (2.1.310) | STOP, hlásiť |
| Platí aj pre subagentov s `omitClaudeMd: true` | docs code.claude.com/docs/en/sub-agents („What loads at startup" / omitClaudeMd) — P2_KTO_CO_DOSTANE to tvrdí z 23.10. | STOP, hlásiť |
| Tvar globov (`**`, `{a,b}`), relatívne od koreňa repa | tie isté docs | prispôsobiť tvar globov, zapísať do § 5 nižšie |

Výsledok sondy (s URL a dátumom overenia) zapíš do tohto package do § 5 a commitni s prvou zmenou.

## 1 · Cieľ

Povinné čítanie podľa oblasti sa **načíta samo**, keď agent pracuje so súbormi oblasti — nečíta ho rola, ktorej sa netýka (NAVRH § 3, prvý riadok).
Jedno pravidlo = jeden domov: riadok oblasti sa z `POVINNE_CITANIE.md` **presúva** (nekopíruje) do súboru oblasti.

1. **Súbory oblastí** `.claude/rules/<oblasť>.md`, každý s frontmatterom `paths:` a ≤ 6 kB. Obsah = doterajší riadok oblasti z
   [POVINNE_CITANIE.md](../../../pravidla/POVINNE_CITANIE.md) (čo pred prácou prečítať) + pravidlá, ktoré platia **len** pre túto oblasť
   (tabuľka nižšie). Odkazy v súboroch oblastí sú relatívne od `.claude/rules/` (alebo cesty v backtickoch od koreňa — vyber jedno, jednotne).
   Návrh rozdelenia (globy over Globom — každý musí trafiť aspoň jeden súbor; uprav podľa skutočného stromu a zdôvodni v § 5):

| Súbor | `paths:` (návrh) | Obsah (odkiaľ) |
|---|---|---|
| `kod.md` | `noxun_engine/**/*.rb`, `noxun_engine.rb` | riadok „zmenu Ruby kódu — core / modules" (ARCHITEKTURA rozcestník → odseky modulov, STANDARD Grepom) |
| `konstrukcia.md` | `noxun_engine/core/` buildery a lifecycle: `construction.rb`, `cabinet_builder.rb`, `board_builder.rb`, `zone_tree.rb`, `zones.rb`, `scale_observer.rb`, `placement.rb`, `cabinet_types.rb`, `drawer_recipes.rb`, `front_profiles.rb`, `part_faces.rb` + `noxun_engine/modules/**` + `noxun_engine/data/recipes/**` (over v docs/architecture/construction.md, čo k oblasti patrí) | riadok „buildery · observery · undo · geometriu" vrátane vety „In-SU test je tu brána mergu" s odkazom na D6 |
| `ui.md` | `noxun_engine/ui/**`, `tests/js/**`, `scripts/ui_foto.ps1`, `scripts/ui_foto/**` | riadok „UI — Inspector, Štúdio…" + **cache-bust** (`?v=` = presne VERSION, zmena css/js ⇒ bump) z IMPLEMENTATOR.md § Verzia + fotenie okien (kedy, odkaz na NASTROJE_TESTOV#foto) z IMPLEMENTATOR.md § Testovanie |
| `materialy.md` | `noxun_engine/core/materials*.rb`, `noxun_engine/core/abs_rules.rb`, `noxun_engine/core/demos/**`, `noxun_engine/ui/materials*_dialog.rb` | riadok „materiály · ABS · katalóg · Demos" |
| `kovanie.md` | `noxun_engine/core/hardware_*.rb`, `noxun_engine/ui/hardware_catalog_dialog.rb` | riadok „kovanie — pravidlá, sety, katalóg" |
| `vystupy.md` | `vepo_export.rb`, `bom.rb`, `cp_export.rb`, `xlsx_writer.rb`, `validation.rb`, `build_plan.rb`, `part_keys.rb`, `budget*.rb`, `sheet_*.rb`, `export_settings.rb` v `noxun_engine/core/` + `noxun_engine/ui/production_core.rb`, `noxun_engine/ui/export_prep.rb`, `scripts/export_test.ps1`, `scripts/export_compare.rb` (over v docs/architecture/outputs.md) | riadok „výstupy — VEPO…" + export test (brána `P == K`, odkaz na NASTROJE_TESTOV#export) |
| `testy.md` | `tests/**`, `scripts/run_*.ps1`, `scripts/lib/**` | riadok „testy — novú sadu alebo úpravu" + podrobnosti z IMPLEMENTATOR.md § Testovanie, ktoré sa týkajú písania a spúšťania sád (JS sady a pasca `node tests/js/test_*.js`, CI slučka, `_dev` vo worktree a hlavný checkout, `-DryRun`, zámok `exit 2`) |
| `dc.md` | len keď Grep `dynamic_attributes` nájde súbory pluginu; inak riadok DC ostáva v POVINNE_CITANIE (platí vždy) | riadok „dynamické komponenty (DC)" |

2. **`POVINNE_CITANIE.md` = rozcestník** (≤ 6 kB): ostávajú riadky, ktoré nemajú cestu — **každú prácu** (DEFINICIE), **novú dávku · plánovanie ·
   zadanie**, **bugfix · diagnostiku**, **code review · audit návrhu**, **workflow · pravidlá práce · skilly** (+ DC, ak nemá súbor) — plus
   **tabuľka oblastí**: oblasť → súbor `.claude/rules/<oblasť>.md` → kedy sa načíta (zhrnutie `paths:` slovami). Veta pre nástroje mimo Claude Code
   (Codex, Grok, iný harness): **súbor oblasti si prečítaj sám podľa tabuľky** — automaticky sa im nenačíta (ROLY § 6). Pravidlá „viac riadkov =
   platia všetky", „súbor nad ~50 kB sa nečíta celý" a rozpočet čítania ostávajú.
3. **`IMPLEMENTATOR.md` ≤ 8 kB** (dnes 12 kB) bez straty pravidla:
   - § Testovanie: ostane **krátky zoznam brán** (každá jeden riadok s odkazom): headless + JS príkazy sú v AGENTS.md (Testy) — neopakovať ·
     in-SU = brána mergu (D6) + **runner VŽDY s `-CloseWhenDone`** + paralelné behy sa vylučujú (`exit 2` = počkaj) · fotenie okien pri UI dávke →
     `ui.md` · export test pri výstupoch → `vystupy.md` · **testuje sa len v ENGINEtests / neuloženom Untitled bez NOXUN korpusov, NIKDY v okne so
     zákazkou (overiť `model.path`, bridge len v testovacom okne)**. Podrobnosti → `testy.md` alebo `NASTROJE_TESTOV.md` (interaktívny kanál MCP
     a file-bridge → NASTROJE_TESTOV#mcp).
   - **Lokálne hooky** (popis `post_edit_check.ps1` a encoding guardu) → nový `docs/HOOKY.md` (popis pre ľudí a agentov; v P3b doň pribudnú hooky
     hlavného okna z ORCHESTRATOR.md). V IMPLEMENTATOR.md ostane jedna veta: hook po Edit/Write hlási syntax a encoding — pri hláške chybu hneď
     oprav; vynucuje CI.
   - § Verzia: cache-bust → `ui.md` (guard ho stráži; v IMPLEMENTATOR ostane len krok checklistu „`?v=`"); veta o dokumentačnom PR a STAV →
     skrátiť na odkaz na hlavičku „Údržba" v `SYSTEM/STAV.md`, kde je to isté pravidlo (over, že tam je celé; čo chýba, doplň **tam**); ručný postup
     čísla PR → hlavička `scripts\otvor_pr.ps1` (v IMPLEMENTATOR ostane: `PR #?` pred PR, číslo doplní `otvor_pr.ps1`, kvótová brána exit 3 aj
     2/4 = draft).
   - Kotvy `#verzia` a `#testovanie` **ostávajú** (vkladá ich generátor do typu `slepy-recenzent`, odkazujú na ne iné súbory).
4. **AGENTS.md:** v Rozcestníku jedna krátka položka „pravidlá oblastí `.claude/rules/` — načítajú sa samé pri práci so súbormi oblasti; mimo
   Claude Code podľa tabuľky v POVINNE_CITANIE" (AGENTS.md ostáva ≤ 12 kB / 150 riadkov).
5. **Typy agentov:** `ruby scripts/generuj_typy_agentov.rb` (IMPLEMENTATOR.md sa zmenil). Generátor súbory oblastí **nevkladá** — Claude typy
   ich dostanú automaticky podľa ciest (sonda § 0).
6. **Odkazy:** Grep na odkazy, ktoré ukazovali na presunuté vety (`POVINNE_CITANIE`, `IMPLEMENTATOR.md#testovanie`, „cache-bust",
   „Lokálne hooky", `NASTROJE_TESTOV`) v `AGENTS.md`, `SYSTEM/pravidla/`, `SYSTEM/WORKFLOW.md`, skilloch a `docs/` — každý musí viesť na nové miesto.

## 2 · Stráže a testy (`tests/pure/`)

1. **G1** (`test_pravidla_velkost.rb`): nový strop `.claude/rules/*.md` ≤ 6 kB; `SYSTEM/pravidla/roly/IMPLEMENTATOR.md` ≤ 8 kB (samostatný riadok;
   strop všetkých rolí 14 kB ostáva do P3b, ktorá ho zníži na 8 kB); `POVINNE_CITANIE.md` 8 → 6 kB. Komentár pri stropoch prepísať (bez histórie).
2. **G2:** do `NX_PRAV_HISTORY_SCAN` pridať `.claude/rules/**/*.md`.
3. **Nová stráž oblastí** (do toho istého testu alebo `test_pravidla_oblasti.rb`): (a) každý `.claude/rules/*.md` začína frontmatterom s neprázdnym
   `paths:` (súbor bez `paths:` by sa načítal každej role vždy); (b) každý glob trafí aspoň jeden súbor v repe (preklep = mŕtve pravidlo);
   (c) POVINNE_CITANIE menuje každý súbor oblasti (Codex a Grok ho inak nenájdu); (d) **vlastné správanie** — negatívny aj pozitívny prípad
   v dočasnom priečinku (vzor: test G2 „guard chytí históriu a nechytí platné znenie").
4. `test_docs_navigacia`, `test_definicie` (G3), `test_agent_definitions` (G4), encoding guard — nové súbory do zoznamov, ak to vyžadujú.
5. Headless `ruby tests/run_all.rb` + `powershell -NoProfile -File scripts\run_js_tests.ps1` zelené; `ruby scripts/generuj_typy_agentov.rb --check` bez rozdielu.
   In-SU test netreba (D6 — plugin sa nemení).

## 3 · Hotovo, keď

1. **Mapa presunu** `SYSTEM/zdroje/bloky/PRAVIDLA/P3a_MAPA.md`: každá veta odstránená z `POVINNE_CITANIE.md` a z `IMPLEMENTATOR.md` (§ Testovanie,
   § Verzia) → kde je teraz (súbor + sekcia); žiadna bez nového miesta. Pod tým zoznam odchýlok od tohto package s dôvodom.
2. Veľkosti po zmene (bajty bez CR) v PR popise: každý súbor oblasti, POVINNE_CITANIE, IMPLEMENTATOR, AGENTS, telá typov.
3. Stráže § 2 zelené, `--check` bez rozdielu.
4. **KRONIKA** odsek navrch „Záznamy dávok": P3a + **smoke typov po P2 PASS** (výsledok je v
   [P2_KTO_CO_DOSTANE.md](P2_KTO_CO_DOSTANE.md), sekcia „Smoke typov po mergi" — už v tejto vetve) · **PLAN** blok 10: riadok P3 rozdeliť na
   `✅ **P3a** pravidlá oblastí (.claude/rules/ s paths:, POVINNE_CITANIE rozcestník, IMPLEMENTATOR ≤ 8 kB) — PR #?` a `**P3b** postupy — skilly
   uzaver-bloku a smoke, ORCHESTRATOR ≤ 8 kB, WORKFLOW mapa bez kópií pravidiel, nálezy hliadky P-2026-10-23-2 a -3` · **STAV** „Robí sa / Ďalší krok"
   podľa checklistu dokumentačného PR (verzia a testy sa nemenia).
5. **Smoke po mergi (orchestrátor, nová session — pravidlá sa objavia až v novej session):** typ `analytik` dostane pokyn prečítať nástrojom Read
   prvé 3 riadky `noxun_engine/ui/panel.rb` a potom bez ďalšieho nástroja povedať, či sa mu v kontexte objavil súbor `.claude/rules/ui.md`
   (citovať prvú vetu) a či vidí `vystupy.md` (nesmie). Výsledok do KRONIKY v P3b.

## 4 · Brány

- Audit návrhu: nepovinný (D2 — žiadny kontrakt ani schéma). Predrecenzia: **akceptačný krok** — slepý recenzent overí mapu presunu (§ 3 bod 1)
  proti `git diff main...HEAD`: nič sa nestratilo, nič orchestrátorovo nepribudlo implementátorovi, žiadny súbor oblasti bez `paths:`.
- Pred PR **STOP** a report orchestrátorovi (predrecenzia); PR až na pokyn cez `scripts\otvor_pr.ps1`.
- **Mimo rozsahu (P3b):** ORCHESTRATOR.md, skilly `uzaver-bloku` a `smoke`, WORKFLOW.md (okrem opravy odkazov podľa § 1 bod 6), `agy-reserser`
  a skill `antigravity-outside-in`, strop všetkých rolí 8 kB.

## 5 · Výsledok sondy a odchýlky (vyplní implementátor)

