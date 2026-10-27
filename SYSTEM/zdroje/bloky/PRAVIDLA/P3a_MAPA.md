# P3a — mapa presunu (blok PRAVIDLA, 26.10.2026)

> Každá veta odstránená z `SYSTEM/pravidla/POVINNE_CITANIE.md` (**PC**) a z `SYSTEM/pravidla/roly/IMPLEMENTATOR.md` (**IM**, § Verzia a § Testovanie)
> a jej nový domov. Súbory oblastí sú `.claude/rules/<názov>.md` (**R:názov**). Zadanie: [PACKAGE_P3a.md](PACKAGE_P3a.md).
> Smer „kto uvidí": R:* sa načíta len pri práci so súbormi oblasti (Claude Code) — rola, ktorej sa oblasť netýka, ho nedostane.

## A · POVINNE_CITANIE.md

| Pôvodná veta (PC) | Nový domov |
|---|---|
| úvod: „automaticky sa načíta len AGENTS.md …; architektúra, štandard ani pravidlá kódu sa nenačítajú" | PC úvod (prepísaný: + súbor oblasti sa načíta sám pri Read/Write/Edit) |
| riadok **každú prácu** (DEFINICIE) | PC — ostáva |
| riadok **novú dávku · plánovanie · zadanie** | PC — ostáva |
| riadok **zmenu Ruby kódu — core / modules** (ARCHITEKTURA → odseky modulov, STANDARD Grepom) | R:kod |
| riadok **buildery · observery · undo · geometriu** (odseky construction/cabinet_builder/board_builder/zone_tree/scale_observer, SKETCHUP_PRAVIDLA, STANDARD §3 §4 §9) | R:konstrukcia |
| veta „**In-SU test je tu brána mergu** (spúšťače D6; runner IMPLEMENTATOR#testovanie)" | R:konstrukcia |
| riadok **UI** — UI_DIZAJN §1–§3 (+ §4/§5.x), odsek ui-lifecycle (príklady nadpisov), UI20_KONTRAKT, „vertikálny priestor panela je vzácny" | R:ui |
| veta o **cache-bust pravidle** (`?v=` = presne VERSION) | R:ui (Cache-bust) |
| veta „Po zmene UI nafoť okná (`scripts\ui_foto.ps1`, NASTROJE_TESTOV#foto)" | R:ui (Fotenie okien) |
| riadok **materiály · ABS · katalóg · Demos** (odseky materials*, abs_rules, demos; STANDARD §7) | R:materialy |
| riadok **kovanie** (hardware_rules/catalog/sets; STANDARD §6) | R:kovanie |
| riadok **výstupy** (VEPO_KONTRAKT, validation, production_core, outputs.md, build_plan/part_keys, STANDARD §8 §11) | R:vystupy |
| veta „Po zmene exportu **export test** (NASTROJE_TESTOV#export)" | R:vystupy (Export test je brána mergu) |
| riadok **bugfix · diagnostiku** | PC — ostáva |
| riadok **testy — novú sadu alebo úpravu** (IMPLEMENTATOR#testovanie + vzory v `tests/`) | R:testy |
| riadok **code review · audit návrhu** | PC — ostáva (odkaz „export test `P == K`" teraz ukazuje aj na R:vystupy) |
| riadok **dynamické komponenty (DC)** — „vždy a bez výnimky" | R:dc (paths = súbory s `dynamic_attributes`) + PC tabuľka (práca s DC mimo súborov → DC_PRAVIDLA vždy) |
| riadok **workflow · pravidlá práce · skilly** | PC — ostáva |
| „Keď zásah spadá do viacerých riadkov, platia VŠETKY" · „súbor nad ~50 kB" · „rozpočet čítania ≤ 150 kB" | PC — ostáva (záver) |
| *(nové)* tabuľka oblastí + veta pre Codex/Grok („prečítaj si súbor oblasti sám") | PC sekcia „Pravidlá oblastí" |

## B · IMPLEMENTATOR.md — § Verzia a uzáver dávky

| Pôvodná veta (IM) | Nový domov |
|---|---|
| `VERSION` žije na 2 miestach, synchro stráži guard | IM § Verzia — ostáva (skrátená) |
| bump patch / minor = uzáver bloku (+ príklad čísel, „keď ho skladá subagent") | IM § Verzia — ostáva (bez príkladu čísel); postup uzáveru → ORCHESTRATOR#uzaver-bloku |
| „Každé zvýšenie VERSION = prepis STAV (okrem D)" | IM § Verzia — ostáva |
| „Dokumentačné PR, ktoré mení stav bloku …, aktualizuje faktický stav; prepíše Robí sa a Ďalší krok; ostatné STAV nemenia; nahradený text → KRONIKA" | **STAV.md, hlavička „Údržba"** (overené: obsahuje celé pravidlo); IM odkazuje |
| **Cache-bust:** `?v=` v `ui/*.html` = presne VERSION, zmena css/js ⇒ bump ⇒ prepísať všetky `?v=` | R:ui (Cache-bust); IM checklist: „každý `?v=` (pravidlo: R:ui)" |
| Checklist uzáveru kódovej dávky (bump, testy, odsek modulu, Grep zoznamov, DOGFOODING_vyriesene, STAV, KRONIKA, PLAN ✅) | IM § Verzia — ostáva |
| Checklist dokumentačného PR | IM § Verzia — ostáva |
| Číslo PR: `PR #?`, samostatný commit, kvótová brána, `--body-file` | IM § Verzia (stručne) + **hlavička `scripts\otvor_pr.ps1`** |
| ručný postup čísla PR (`usage.ps1 -Label … -Phase before -Gate codex`, exit 3 / 2 / 4 = `--draft`) | hlavička `scripts\otvor_pr.ps1` („Rucny postup ostava ako zaloha") + skill `usage`; IM ponecháva len pravidlo exit 3 aj 2/4 = draft |

## C · IMPLEMENTATOR.md — § Testovanie

| Pôvodná veta (IM) | Nový domov |
|---|---|
| Automatické testy: headless v CI + `scripts\run_tests.ps1` + Ruby `C:\Ruby32-x64` | R:testy (príkazy v AGENTS.md § Testy ostávajú) |
| JS sady `run_js_tests.ps1` (výpis, `-FailFast`), pasca `node tests/js/test_*.js`, CI slučka | R:testy |
| „Počty testov sa do pravidiel nepíšu" | IM § Testovanie (jadro; R:testy len o riadku v STAV) |
| In-SU test je brána mergu (D6) | IM § Testovanie — ostáva (odkaz D6) |
| Runner: deploy → inštancia → poll → výsledok, overuje geometriu a undo; výsledkový grep až PO dobehu | IM (grep po dobehu) + R:testy (postup) |
| `-CloseWhenDone` VŽDY; inštancia sa sama ukončí; runner nikdy nezabíja; teardown 0xC0000374 | IM (VŽDY `-CloseWhenDone`) + R:testy (podrobnosti) |
| paralelné behy sa vylučujú; zámok `deploy.lock`, sentinel `last_run.txt`; `exit 2` | IM (vylučujú sa, `exit 2` = počkaj) + R:testy (zámok a sentinel) |
| Fotenie okien (každá UI dávka) | R:ui (Fotenie okien) → NASTROJE_TESTOV#foto; IM jedna veta s odkazom |
| Export test (brána mergu `P == K`; vymedzenie spúšťačov „mení VEPO, CSV kovania, XLSX rozpočtu či ponuky alebo ich cestu") | IM § Testovanie (brána, spúšťače a `P == K` v tele implementátora) · R:vystupy → NASTROJE_TESTOV#export (podrobnosti) |
| Lokálne hooky — `post_edit_check.ps1`, encoding guard, `scripts/encoding_guard.rb`, CI test | **`docs/HOOKY.md`**; IM jedna veta („pri hláške chybu hneď oprav; vynucuje CI") |
| Hooky hlavného okna (pripomienka po mergi, ukazovateľ kontextu) | ORCHESTRATOR.md (nemenené; v `docs/HOOKY.md` odkaz, popis v P3b) |
| Interaktívny kanál MCP `execute_ruby`, file-bridge, mtime pasca, overená slučka, deploy `INSTALL_noxun_engine.ps1` | NASTROJE_TESTOV#mcp (sekcia premenovaná „Interaktívny kanál a diagnostika MCP") |
| Diagnostika MCP (`skagent_doctor.ps1`, `Debug.report`) | NASTROJE_TESTOV#mcp — ostáva |
| `_dev/` gitignorované; skripty berú model z `_dev` checkoutu alebo hlavného checkoutu; `-DryRun` | R:testy |
| Testuje sa VÝHRADNE v ENGINEtests / Untitled bez NOXUN korpusov; NIKDY v okne so zákazkou (overiť `model.path`, bridge len v testovacom okne; vrátane vety „v ňom môžu agenti tvoriť/mazať čokoľvek") | IM § Testovanie — ostáva (celé) |

## Odchýlky od package P3a

| Odchýlka | Dôvod |
|---|---|
| `drawer_recipes.rb` je v `kovanie.md`, nie v `konstrukcia.md` | odsek `drawer_recipes.rb` žije v `docs/architecture/hardware.md`, nie v construction.md (package: „over") |
| `konstrukcia.md` navyše (po predrecenzii aj súbory so `Sketchup::*Observer`, `add_observer` alebo `start_operation`: `budget_store`, `materials_apply_appearance`, `materials_native_appearance`, `template_previews`, `main.rb`, dialógy hardware/materials/rules/studio, `ui/panel/selection.rb`; POVINNE_CITANIE má vetu „observer alebo operácia inde → prečítaj sám"): `ghost_tool`, `tags`, `edge_check`, `grain_check`, `direction_check`, `hover_edge`, `edge_overlay`, `app_lifecycle`, `appliance_binding`, `appliance_checks`, `tools/**`, `ui/panel/actions_*.rb` | všetko sú odseky construction.md alebo observer/undo lifecycle a akcie panela zapisujúce do modelu (spúšťače D6); package vymenoval kratší zoznam |
| `materialy.md` navyše `appearance_mapping.rb`; `kovanie.md` navyše `ui/rules_dialog.rb`; `vystupy.md` navyše `hardware_sets.rb` a `ui/studio_dialog.rb` (CSV kovania `purchase_csv`, `do_hw_csv`, XLSX exporty; po predrecenzii), `price_refresh.rb`, `supplier_settings.rb`, `tests/sketchup/su_export_probe.rb` | odseky v príslušnom súbore `docs/architecture/` (materials.md, hardware.md/STANDARD §6, outputs.md); sonda exportu patrí k export testu |
| `dc.md` vznikol (Grep `dynamic_attributes` nájde `board_builder.rb`, `cabinet_builder.rb`, `tools/mower.rb`); jeho `paths:` majú len tieto 3 súbory + `docs/DC_PRAVIDLA.md` | PC tabuľka dopĺňa vetu, že práca s DC inde vyžaduje DC_PRAVIDLA stále — „vždy a bez výnimky" sa tým nestratilo |
| `kod.md` neobsahuje `docs/SKETCHUP_PRAVIDLA.md` | pôvodný riadok „zmenu Ruby kódu" ho nemenoval; ostáva v R:konstrukcia |
| cache-bust v IM checkliste je odkaz na R:ui v backtickoch, nie markdown odkaz | bajtový strop IM 8 kB |
| príklad čísel verzií „(0.5.0 → 0.5.1)", „(0.5.x → 0.6.0)" vypustený z IM | ilustrácia, nie pravidlo |
| opravy odkazov (package § 1 bod 6): `AGENTS.md` (Rozcestník + Testy), `SYSTEM/README.md` (riadok POVINNE_CITANIE), `NASTROJE_TESTOV.md` (hlavička), `RECENZENT.md` (číta aj súbor oblasti), skill `predrecenzia` (vzor promptu), `docs/ARCHITEKTURA.md`, `docs/UI_DIZAJN.md` (cache-bust) | odkazy ukazovali na presunuté vety alebo ich nezahŕňali; `WORKFLOW.md` a ostatné skilly sa nemenili (odkazy „IMPLEMENTATOR.md · Testovanie" ostávajú platné) |
| `docs/HOOKY.md` pridané do kontroly odkazov v `test_docs_navigacia.rb` a `.claude/rules/*.md` do kontroly odkazov a do `NX_DEF_SCAN` | nové súbory pravidiel patria pod existujúce stráže |
