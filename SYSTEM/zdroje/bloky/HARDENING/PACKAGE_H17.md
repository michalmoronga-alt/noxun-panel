# PACKAGE H17 · Spoločná príprava exportov (C-06, prvý rez R-15) — blok 9 HARDENING PO V1

> **Autorita:** triedenie Michala 1.10.2026 (`ROZHODNUTIA_MICHALA_2026-10-01.md`: **C-06** = CX k R-15 · GR k R-15, **Teraz**); blok 9 (`SYSTEM/PLAN.md`, riadok H17
> „kód · audit · výrobná"); `AUDIT_REGISTER.md` **R-15** („žiadny hromadný presun — vyrezať neutrálny OutputPackage…, dialógy/fokus/statusy ostávajú v UI"); krížový audit
> `CROSS_AUDIT_A1_CODEX_ASTRA.md:66` (R-15 · S4: rez = štyri exportné vstupy; **exportné brány ponechať podľa druhu výstupu — jeden nerozlíšený „export povolený" by správanie
> zmenil**; golden VEPO bajtovo pri pevnom čase, nákupné CSV, rozpočet, obsah XLSX a **presná matica odmietnutí**) a `CROSS_AUDIT_A2_GROK.md:181` (štyri exporty opisujú ten istý
> úvod). `CROSS_AUDIT_A3_CODEX_SOL.md` R-15 ani prípravu exportov nemenuje. **Michalova požiadavka 2A (2.10.2026):** porovnanie s reálnymi exportmi testovacej zákazky z v0.17.24
> (`_dev\h17_baseline\`, §6 R9).
> **Trieda (§5):** **audit-povinná ÁNO** (nový modul `ui/export_prep.rb`) · **výrobná/cenová ÁNO** (mení sa cesta, ktorou vznikajú VEPO, nákup kovania, rozpočet a ponuka) ·
> **predrecenzia povinná** · **in-SU: nie je spúšťač podľa zoznamu, 1 beh runnera + R9 P == K (§00) = DoD a podmienka mergu** (§8) · fotky okien netreba · `codex-po-pr`.
> **Bez viditeľnej zmeny (H17a):** bajty VEPO (CSV aj LOG okrem riadku „Verzia"), CSV kovania, XLSX rozpočtu a ponuky, mená súborov a priečinka, všetky vety, farby, poradie brán,
> otvorenie výberu súboru — **golden T0 PRED zásahom** (neregeneruje sa) **a porovnanie s reálnou zákazkou** (R9). H17b (voliteľná, D9) má jedinú vedomú zmenu: N1.
> **§15 (audit návrhu 2.10.2026: 1 BLOCKER · 6 FIX · 2 NOTE — zapracované) MÁ PREDNOSŤ** pred §1–§14b tam, kde sa líšia; zmeny v texte sú označené „(§15 A?)". **Rez (§00 — H17-0 zrušené):** ~~H17-0 (nástroj
> porovnania + kalibrácia, samostatný PR, plugin bez zmeny)~~ → H17a → H17b (voliteľná).
> **Verzia:** každá časť meniaca plugin = patch podľa mainu pri štarte + všetky `?v=` + prepis STAV (H17-0 bez bumpu). **Stav kódu (zladené 2.10. po H7):** sonda nad `main` **`fe7f5405`** (v0.17.24, po H7a #456,
> H7b #457, H11a #458, H15a/b #459/#460). Riadky = stav k `fe7f5405`. Pôvodná sonda nad `5e0ffb90` (`sonda_h17.rb`) ostáva ako doklad, že H7 poradie úvodu nezmenil.

## §00 · Rozhodnutie Michala 9.10.2026 — H17-0 zrušené, MÁ PREDNOSŤ pred celým textom

**Prečo:** časť H17-0 (nástroj porovnania s „fyzickou ochranou" pracovných priečinkov) sa rozrástla do natívneho kódu, ktorý platforma Codexu 4.10.2026 zastavila
bezpečnostným filtrom; nástroj sa nedokončil a H17a naň čakala od 3.10. Michal 9.10.2026 (chat s orchestrátorom): **„Zahodiť H17-0, spraviť len refaktor."**

- **Zrušené:** H17-0 celé (nástroj `scripts/export_porovnanie*`, testy T9/T9b, mutácie M25/M30/M31, kalibrácie K0/K, izolácia profilu, D12, D13) a pôvodný text R9.
  Rozpracované súbory H17-0 v Codex worktree a v `_dev/h17_root_review/` sa **nepreberajú** do repa ani nepoužívajú.
- **Platí bez zmeny:** H17a podľa §1–§15 (R0–R8, golden T0, matica G2 nad `KINDS`, G3, G4, G5, G6, T1–T6, M1–M24, M26–M29) — audit návrhu §15 (`AUDIT_H17_raw.md`) sa týkal
  refaktoru a jeho FIX body ostávajú záväzné; jeho BLOCKER A1 a NOTE A8 sa týkali len zrušeného nástroja.
- **Nový R9 (nižšie):** porovnanie reálnej zákazky K (main) ↔ P (vetva) ručnými exportmi Michala, porovnanie orchestrátorom v scratchpade — **P == K je podmienka mergu**.
- **Sonda pri prevzatí (krok 0, 9.10.2026, Claude):** `git diff fe7f5405 HEAD` (HEAD = main `2114e1a3`, v0.17.28) — `ui/production_core.rb`, `core/export_settings.rb`,
  `core/vepo_export.rb`, `core/xlsx_writer.rb`, `core/cp_export.rb`, `core/budget.rb` **bez zmeny**; riadky §0 platia. Zmenené: `core/bom.rb` (ŠÍRKA 50 — nohy úzkej skrinky,
  výstup exportov smie zmeniť, cestu nie), `main.rb` a `tests/helper.rb` (+`core/library_registry`, H16 — `MAIN_PARTS` prepočíta implementátor).
- **Trieda bez zmeny:** audit-povinná (nový modul — audit §15 hotový, koncept refaktoru sa nemení → nový audit netreba) · výrobná/cenová · predrecenzia povinná · in-SU runner = DoD.

---

## 0 · Sonda na kóde (krok 0, headless) — *(zladené 2.10. po H7)*

Skripty `scratchpad/HARDENING/sonda_h17_fe7.rb` (výstup `sonda_h17_fe7_out.txt`; strom `fe7f5405` cez `git archive` do scratchpadu) a pôvodný `sonda_h17.rb` nad `5e0ffb90`. Ruby 3.2
cez `tests/helper.rb` (APPDATA = sandbox), spy = modul **prependnutý na singleton** `ProductionCore`, `ExportSettings`, `Bom`, `Budget`, `Validation`, `SheetEstimate`, `SheetLayout`,
`VepoExport`, `HardwareSets`, `XlsxWriter`, `CpExport`; stubované len dátové zdroje (`fresh_collect`, `sheets_map`, `edges_map`, `hardware_expansion`, `hardware_catalog_items`, `vepo_*`),
**`ExportSettings` skutočný v sandboxe** (názov cez `save_project_name`, `expect` cez `NxTest.export_expect`), `DocKey.key` pevný, `UI` stub, `Time.now` zamrazený. Baseline Michala a živý
`%APPDATA%` len **čítané** (R9); snímka katalógov skopírovaná do scratchpadu. Do repa, modelov ani živého `%APPDATA%` sa nič nezapisovalo.

| # | Tvrdenie o kóde `fe7f5405` (`ui/production_core.rb`, ak nie je inak) | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | Štyri exporty: VEPO `do_export` `:1687-1787`, CSV kovania `do_hw_csv` `:1805-1871`, XLSX rozpočtu `do_budget_xlsx` `:3278-3357`, XLSX ponuky `do_cp_xlsx` `:3367-3446`. **Jediné štyri miesta pluginu s `UI.savepanel`/`UI.select_directory`** (`:1735`, `:1854`, `:3332`, `:3427`) | Grep `noxun_engine/**/*.rb` | PRAVDA → strážca R4 b |
| S2 | **Úvod je vo všetkých štyroch textovo zhodný** a po H7 má **sedem krokov**: generácia + `repush` · `flush_blocked` · `ExportSettings.refresh` · **`gate = export_expect_check(model, data[, merge: true])`** + `return status.call(gate[:stop], true) if gate[:stop]` · `fresh_collect` · `newer_config_stop` · `cut_stop` (~25 riadkov × 4; VEPO `:1688-1722`, CSV `:1806-1829`, rozpočet `:3279-3299`, ponuka `:3368-3386`) | čítanie | PRAVDA → spoločná príprava |
| S3 | **Brána `expect` (H7b):** `ProductionCore.export_expect_check` (`:252-254`) → `ExportSettings.expect_check` (`core/export_settings.rb:724-758`) — neplatný tvar → `EXPECT_STALE`; nesúlad názvu (okrem automatický → automatický, ktorý prejde s `:note`) alebo 18 + 36 (len `merge: true` = VEPO) → veta; **vlastný `rescue` → `EXPECT_FAILED`**. Vracia `{ stop, note, project, merge }`; `project` = **normalizovaný** názov (strop 120) | čítanie | PRAVDA |
| S4 | **`gate` sa používa v celom exporte:** `:stop` v úvode; `:project` = názov súboru a obsahu vo **všetkých štyroch** (`:1749`, `:1852`, `:3330`, `:3425` — po H7b už žiadne `project_name(model)` v exporte); `:merge` len VEPO (`:1748`); `:note` na konci vety vo všetkých štyroch (`:1775`, `:1866`, `:3352`, `:3441`) | Grep `gate[` | PRAVDA → kontext nesie `gate` (R2) |
| S5 | `expect_check` **číta** `project_name(model)` — a to môže **zapísať** (prenos názvu sedenia k súboru, `adopt_session_name`, `export_settings.rb:486`) → brána sa musí volať **práve raz** na export; druhé volanie by mohlo vidieť iný stav (`:note`) | čítanie | PRAVDA → R1.2 krok 5, R4 a |
| S6 | Poradie volaní (spy, šťastná cesta, `fe7f5405`): **VEPO** `ES.refresh` → `export_expect_check` → zber → novšia schéma → chrbát → expanzia → kovanie `:kit` → `ES.last_dir` → *picker priečinka* → `Bom.compute` → `budget_payload` → `control_payload` → `build`/`write` → `ES.save_last_dir` → vety názvu; **CSV** … → expanzia → kovanie `:all` → duplicity → `hw_csv_file_name` → `ES.last_dir` → *picker* → `purchase_csv` → `ES.save_last_dir` → vety; **rozpočet** … → `Bom.compute` → expanzia → `budget_payload` → `budget_std_block` → kovanie → duplicity → potvrdenie → *picker* → `XlsxWriter.write` → …; **ponuka** ako rozpočet + `CpExport.specification` pred kovaním a `firewall_hits` pred `write_book` | `sonda_h17_fe7_out.txt` | PRAVDA → G4 |
| S7 | **Každý výpočet najviac raz na export** (zber, `Bom.compute`, expanzia, rozpočet, kontrola, brána `expect`) — duplicita je v **kóde**, nie za behu. *(§15 A2)* **Výnimka:** pri `hw_exp == nil` zopakuje expanziu fallback v `budget_payload` (S25) | spy počty | PRAVDA pre šťastnú cestu; pri `nil` 2 expanzie |
| S8 | `Bom.compute` **nemutuje** `collected`; `budget_payload` bez `smap` == so `smap` == s `estimate` + `layout` (JSON zhodný) | sonda (obe verzie) | PRAVDA → kontext smie podať `smap` všetkým |
| S9 | **Výnimky:** `hardware_expansion` (`:688`), `budget_payload` (`:2241`), `expect_check` → bezpečná hodnota; `layout_for` fail-soft; `sheets_map` → `{}`, `edges_map` → `nil`; **`Bom.compute`, `control_payload`, `SheetEstimate.estimate` rescue nemajú** → `rescue` exportu so štyrmi rôznymi vetami | čítanie | PRAVDA → kontext nepridá ani neuberie `rescue`, `estimate` sa nepodáva (R2) |
| S10 | Pri zamrznutom `Time.now` sú bajty všetkých 4 výstupov deterministické; XLSX = ZIP **STORE**, **bez `docProps` a `sharedStrings`** (len `[Content_Types].xml`, `_rels`, `workbook`, `styles`, `sheet*.xml`) — čas je len v DOS poliach hlavičiek a dátum v titulku/názve; VEPO LOG nesie `Verzia:` a `Dátum:`, CSV kovania čas v 1. riadku | sonda + rozbalenie baseline (R9) | PRAVDA |
| S11 | `ExportSettings.last_dir` je **surová** hodnota (`export_settings.rb:285-290` — komentár: „zjednotenie je H17"); VEPO ju overí (`:1733-1734`), CSV/XLSX ju dajú do `savepanel` priamo — **N1** | čítanie | PRAVDA → H17b |
| S12 | **Zámerné rozdiely** (brány druhu výstupu): `:kit` len VEPO (`:1730`); duplicity CSV/rozpočet/ponuka (+`cp:`); `budget_std_block` + potvrdenie cien len XLSX; vety „nedá sa zostaviť" CSV vs XLSX; „Niet čo exportovať" až po pickeri; `.xlsx`; `repush` pri `plan_prices`; 18 + 36 v `expect` len VEPO | čítanie | PRAVDA → ostávajú v exportoch (D2) |
| S13 | **Koniec exportu je tiež kópia:** `ExportSettings.save_last_dir(…)` 4× a veta `"#{pending_name_note(model)}#{default_name_note(model, project)}#{gate[:note]}"` **4×** (`:1775`, `:1866`, `:3351-3352`, `:3441`) | Grep | PRAVDA → H17b R8.3 |
| S14 | **Textoví strážcovia nad telami `do_*`** (regex na zdroji, `fe7f5405`): `test_1b3_citanie.rb:299`, `:307` · `test_ghost_d1_dosky.rb:1022-1031` (aj počet = 4) · `test_h3_zobrazenie.rb:186` · `test_p0hf_brany.rb:758-770` · `test_st1a_studio.rb:755` (`merge = gate[:merge]`), `:868-873` · `test_st1b_kontrola.rb:93-110` · `test_st1c_nakup.rb:168-196` (+ `project = gate[:project]` `:177-178`, komentár `:184`) · `test_kon0_d143.rb:488-499` · `test_kovc2b_brany.rb:165-178` · `test_r14_budget_std.rb:473-487` · `test_kovh1_adhoc.rb:578-582` (počet = 4) · **nové po H7b:** `test_h7b_nazov_zakazky.rb:382-398` (poradie gen → flush → refresh → `expect` → zber → picker v tele, `merge: true` len VEPO) | Grep | PRAVDA → §0.3, R5 |
| S15 | Stuby exportných testov menia **singleton** `ProductionCore`/`ExportSettings` — spy dokázal, že zachytia aj volanie z iného modulu, ak volá **`ProductionCore.<meno>`** / **`ExportSettings.<meno>`** | sonda | PRAVDA → R2 |
| S16 | **Existujúce goldeny kryjú jadrá a mená, nie bajty výsledku `do_*`:** `test_np1_vepo_charakterizacia.rb` (`VepoExport.build`), `kovh_golden`, `np4_golden`, `h15_golden` (G7 nákup), **`h7_golden`** (mená, nadpisy, bajty `vepo_settings.json`, pomenovanie 4 exportov end-to-end — so stubom `budget_payload`/`control_payload`). Súbeh brán, poradie krokov a **bajty súborov z `do_*`** nekryje nič | čítanie | PRAVDA → golden T0 (R0) |
| S17 | **Harness H7 je znovupoužiteľný:** `test_h7a_golden.rb` `NxH7G` (`with_sandbox`, `with_doc_key`, `with_stubs`, `with_ui`, `with_now`, `run_export`), `NxTest.export_expect(model)` (`tests/helper.rb:355`), `test_h7b_nazov_zakazky.rb` `NxH7B.run` | čítanie | PRAVDA → R0.1 |
| S18 | **Piaty skladateľ** `StudioDialog#push_state` a **šiesta kópia poradia brán VEPO** `layout_block_reasons` (`:2279`) — bez zmeny od pôvodnej sondy | čítanie | PRAVDA → D6, D7 |
| S19 | **Vrstvenie:** `core/` nevolá `ui/`; `production_core.rb` nesmie mať inštančnú premennú (`test_st1a_core.rb:74-82`) | Grep | PRAVDA → D1 |
| S20 | **Načítanie po H11a:** `main.rb` načítava časti cez `AppLifecycle.require_part` (`:491-575`, `export_settings` `:562`, `ui/production_core` `:573`, `ui/studio_dialog` `:574`); **zmrazená kópia zoznamu** `NxH11aLoad::MAIN_PARTS` (95 častí na current main; baseline v0.17.24 mala 94) v `test_h11a_nacitanie.rb:352-356`; `tests/helper.rb` načíta len `core/` (+ `export_settings` `:190`) | čítanie | PRAVDA → R6 |
| S21 | **Pasca tichého prejdenia:** keby nový súbor v teste chýbal, `NameError` padne do `rescue` exportu („Chyba exportu: …") a test „picker sa neotvoril / súbor nevznikol" by prešiel naprázdno | čítanie | PRAVDA → R6, D3 |
| S22 | **In-SU háčiky pickera už existujú:** `st1c_without_savepanel`, `st1c_without_dirpanel` (vrátia `nil`, počítajú), `kovc2b_stub_savepanel!(path)` (vráti pevnú cestu), `h7b_expect(model)` (`su_runner.rb:141-145`, `:15988-16030`, `:23866-23881`); `Materials.test_dir_override` funguje aj v SketchUpe (runner `:413`, `:6014`); `scripts/ui_foto.ps1` je precedens samostatného skriptu nad zámkom runnera (`deploy.lock` + sentinel, `-RubyStartup boot.rb <kópia>`) | čítanie | PRAVDA → R9 |

**Sonda k auditu (§15, `sonda_h17_audit.rb` → `sonda_h17_audit_out.txt`, sandbox `tests/helper.rb`, strom `fe7f5405`, kópia snímky `_dev/h17_baseline/appdata_snapshot/` — nič živé):**

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S23 | `Materials.test_dir_override` nepokryje celý profil: `ENV['APPDATA']` čítajú priamo `dim_series.rb:55`, `direction_check.rb:374`, `edge_check.rb:147`, `grain_check.rb:173`, `updater.rb:795`, `usage_stats.rb:34`, `main.rb:84` (téma), `tools/legacy_cleanup.rb:63` (+ bázy `materials.rb:236`, `abs_rules.rb:208`, `hardware_rules.rb:470`, `supplier_settings.rb:194`, `templates.rb:82`); pri presmerovaní `ENV['APPDATA']` idú do sandboxu aj `Materials.dir`, `ExportSettings.path`, `DimSeries`, `ApplianceCatalog.dir` | Grep; sonda `A1_paths` | PRAVDA → §15 A1 |
| S24 | **Init pluginu nad kópiou Michalovej snímky** (`boot_cutover!` → `:schema2`, `ensure_uni_records!` → `:noop`, `ensure_drawer_uni!` → `:noop`, `ApplianceCatalog.assess!` → `:ok`) **nemení žiadny katalóg**; zapíše len `materials.lock`, `uni_seed.done`, `drawer_uni_seed.done` — tie živý profil má, **snímka ich nemá** (kopírovali sa len `*.json`/`*.json.bak`) | sonda `A1_init` | PRAVDA → P7 doplniť značky |
| S25 | **Fallback expanzie:** `budget_payload` pri `hw_exp == nil` volá `hardware_expansion` **znova** (`production_core.rb:2236`) — sekvencia `nil → nil` aj `nil → platná` = **2** skutočné expanzie, rozpočet vznikne (pri `nil → platná` s platnou expanziou) | sonda `A2_*` | PRAVDA → §15 A2 |
| S26 | **Zamrazený čas ako jeden objekt:** `Time.now.utc` ho prepne (`23:03 +0200` → `21:03 +0000`); s `dup` pri každom volaní ostane `23:03 +0200`; `Time.new(2026,10,2,23,3,0)` má na tomto PC pásmo `+0200` | sonda `A4_*` | PRAVDA → §15 A4 |

### 0.1 Krok × export (`fe7f5405`) — *(zladené 2.10. po H7)*

`Z` = zhodné (kópia) · `R` = zámerný rozdiel · `D` = rozdiel bez dôvodu. **Tučné** = čo H17 preberá do `ExportPrep` a **nesmie zdvojiť**.

| # | Krok | VEPO | CSV kovania | XLSX rozpočtu | XLSX ponuky | Druh |
|---|---|---|---|---|---|---|
| 1 | **generácia okna** → `repush` + „Dáta okna sa medzitým zmenili — skús export znova." | `:1688` | `:1806` | `:3279` | `:3368` | Z |
| 2 | **červené polia** → „V paneli sú neplatné polia (červené) — oprav ich a exportuj znova." | `:1692` | `:1810` | `:3283` | `:3372` | Z |
| 3 | **`ExportSettings.refresh`** | `:1696` | `:1814` | `:3287` | `:3376` | Z |
| 4 | **brána `expect`** `export_expect_check(model, data[, merge: true])` → `gate`; `gate[:stop]` → veta | `:1699` `merge: true` | `:1816` | `:3289` | `:3378` | Z (parameter) |
| 5 | **čerstvý zber celého modelu** `fresh_collect` | `:1716` | `:1818` | `:3291` | `:3380` | Z |
| 6 | **novšia schéma** `newer_config_stop` | `:1717` | `:1824` | `:3295` | `:3382` | Z |
| 7 | **chrbát** `cut_stop` | `:1720` | `:1827` | `:3298` | `:3385` | Z |
| 8 | dáta | expanzia | expanzia | `Bom` → expanzia → rozpočet (bez `smap`) | `Bom` → `smap` → expanzia → rozpočet | Z (tie isté funkcie) |
| 9 | „nedá sa zostaviť / nič" | — | `nil` / prázdne | rozpočet `nil` | rozpočet `nil` | R |
| 10 | `budget_std_block` | — | — | áno | áno | R |
| 11 | `cp`, `spec` | — | — | — | áno | R |
| 12 | `drawer_stop` | `:kit` | `:all` | `:all` | `:all` | R |
| 13 | duplicity → `export_blockers` | — | `dups:` | `dups:` | `dups:` + `cp:` | R |
| 14 | potvrdenie cien počtom | — | — | áno | áno | R |
| 15 | názov = **`gate[:project]`**; 18 + 36 = **`gate[:merge]`** (VEPO) | po pickeri | `hw_csv_file_name` | `BudgetXlsx.file_name(…, now)` | `CpXlsx.file_name(…, now)` | Z (zdroj) / R (meno) |
| 16 | picker + `ExportSettings.last_dir` | overený | surový | surový | surový | **D (N1)** |
| 17 | výpočet po pickeri | `Bom`, `smap`, rozpočet, kontrola | — | — | — | R |
| 18 | zápis | `build` + „Niet čo exportovať" + `write` | `purchase_csv` + BOM | `XlsxWriter.write` | firewall + `write_book` | R |
| 19 | `ExportSettings.save_last_dir` | priečinok | `dirname` | `dirname` | `dirname` | Z |
| 20 | vety názvu `pending_name_note` + `default_name_note` + `gate[:note]` na konci | áno | áno | áno | áno | Z (4 kópie) |
| 21 | `rescue` | „Chyba exportu:" | „Export zlyhal:" | „Export rozpočtu zlyhal:" | „Export cenovej ponuky zlyhal:" | R |

**Záver:** riadky **1–7** = spoločná príprava (H17a) vrátane **jedného** volania brány `expect`; `gate` (riadky 4, 15, 20) žije v kontexte, nie v exporte; riadky R ostávajú
výslovne v exporte v dnešnom poradí; riadky 16, 19, 20 = koniec exportu (H17b). **H17 nevolá nič z H7 inak ani druhýkrát:** `ExportSettings.refresh`, `export_expect_check`,
`hw_csv_file_name`, `export_file_names`, `default_name_note`, `pending_name_note`, `normalize_project_name`, `last_dir`, `save_last_dir` ostávajú tam, kde ich dala H7 — H17 ich len volá z jedného miesta.

### 0.2 Čo by sa bez H17 kopírovalo do nového výstupu

Nový výstup (výkresy, etikety, CNC) by dnes musel opísať riadky 1–7 vrátane brány `expect` (H7b, fail-closed) a novšej schémy a chrbta, a vybrať si poradie a argumenty
`Bom.compute` / `hardware_expansion` / `budget_payload` / `control_payload`. Zabudnutá brána `expect` = súbor pod iným názvom, než okno ukazuje; zabudnutý chrbát (D-143) alebo novšia
schéma (KOV-H1) = ticho neúplný výrobný súbor.

### 0.3 Strážcovia, ktorí sa po H17a rozbijú (prepis R5) — *(zladené 2.10. po H7)*

**Rozbije sa:** `test_ghost_d1_dosky.rb:1022-1031` · `test_kovh1_adhoc.rb:578-582` · `test_st1a_studio.rb:868-873` (gen + `repush` v tele VEPO) · `test_st1b_kontrola.rb:93-110` ·
`test_st1c_nakup.rb:168-196` (gen, flush, `fresh_collect(model)` v tele CSV + komentár) · `test_kon0_d143.rb:488-499` · **`test_h7b_nazov_zakazky.rb:382-398`** (poradie úvodu v tele).
**Podľa mien premenných:** `test_1b3_citanie.rb:307`, `test_kovc2b_brany.rb:165-178`, `test_r14_budget_std.rb:473-487`, `test_st1a_studio.rb:755` (`merge = gate[:merge]`),
`test_st1c_nakup.rb:177-178` (`project = gate[:project]`). **Platí ďalej:** `test_1b3_citanie.rb:299`, `test_h3_zobrazenie.rb:186`, `test_p0hf_brany.rb:758-770`.
Behaviorálne testy H7b (`NxH7B.run` — „generácia prvá", „flush pred `expect`", T-B11 súlad/nesúlad) ostávajú **bez zmeny** a musia prejsť.

---

## 1 · Cieľ

**Pre používateľa sa nemení nič** — štyri exporty dávajú bajtovo rovnaké súbory, rovnaké mená, rovnaké vety a zastavia sa v rovnakých situáciách rovnakou vetou; dôkazom je aj
porovnanie s exportmi Michalovej testovacej zákazky z v0.17.24. **Pod kapotou:** všetky štyri exporty začínajú **jednou spoločnou prípravou** `ExportPrep.start` — overenie okna,
červených polí, čerstvé nastavenia, **jedna** kontrola očakávaného názvu a 18 + 36 (H7b), čerstvý zber celej zákazky, brána novšej verzie a chrbta — a dáta zákazky (overený názov,
kusovník, kovanie, rozpočet, kontrola) berú z **jedného kontextu**, ktorý každý údaj spočíta najviac raz. **Každý export si ponechá svoje brány** v dnešnom poradí. **Nový výstup**
= riadok v `ExportPrep::KINDS` + `ExportPrep.start` — bez toho ho test nepustí.

## 2 · Rez a odhad — dve časti, sekvenčne z čerstvého `main`, každá samostatný PR — *(zladené 2.10. po H7)*

| Časť | Obsah | Kód pluginu (+/−) | Testy a nástroje | In-SU | Odhad |
|---|---|---|---|---|---|
| ~~H17-0 · nástroj porovnania + kalibrácia~~ **ZRUŠENÉ (§00)** | `scripts/export_porovnanie.ps1` + `scripts/export_porovnanie/` (`boot.rb`, `run.rb`, `compare.rb`, manifest) + `tests/pure/test_export_porovnanie.rb`; **behy K0 a K** (R9.5) a ich report v PR. **Plugin bez zmeny → bez bumpu verzie** | 0 | nástroj ~450 (PS ~150, in-SU Ruby ~180, porovnávač ~150) + test ~150 | K0 + K | **¾–1 deň** |
| **H17a · spoločná príprava** | T0 golden PRED zásahom → `ui/export_prep.rb` (`start`, `Context` s `gate`, `KINDS`) + loader + zmrazený zoznam H11a + helper → 4 exporty prepnuté → prepis strážcov + R4 → docs → runner + **beh P** (R9.6) | ~+180 / −120 | ~850 (harness ~300, golden + matica ~350, prepis ~120, strážcovia ~80) | runner + P | **1–1¼ dňa** |
| **H17b · koniec exportu** (voliteľná, D9) | N1, `save_last_dir` a vety názvu (`pending` + `default` + `gate[:note]`) na jednom mieste | ~+50 / −45 | ~150 | runner + P | ½ dňa |

**Poradie bloku (rozhodnutie orchestrátora, §14b):** H16 → H18 → ~~H17-0~~ (zrušené, §00) → H17a → H17b → uzáver. **Poradie commitov H17a (záväzné, §15 A9):** (1) golden T0 + harness, plugin
bez zmeny · (2) `export_prep.rb` + `main.rb` + `MAIN_PARTS` + helper + strážca načítania · (3) prepnutie 4 exportov (T0 **bez regenerácie**) · (4) prepis strážcov + R4 ·
(5) docs a uzáver · runner a **R9 P == K** (§00, ručné exporty) na finálnej hlave. Predrecenzia dostane aj `git diff --color-moved=zebra`.
**Poistky:** zmena fixtúry T0 → STOP · nová logika nad presun > ~60 riadkov → STOP · porovnanie P ≠ K → STOP (nemergovať, R9.6).

## 3 · Scope IN

1. ~~**H17-0:**~~ **ZRUŠENÉ (§00).** ~~launcher, generovaný bootstrap, source/profile/capture/restore helpers, reálny exportný runner, read-only porovnávač a negatívne fixtures podľa R9 a §16–17/§20.5. Žiadny kód pluginu alebo bump. K0/K až po pripnutí nástroja.~~
2. **H17a:** `noxun_engine/ui/export_prep.rb` (R1, R2); úvod 1–7 zo `do_export`, `do_hw_csv`, `do_budget_xlsx`, `do_cp_xlsx` do `ExportPrep.start`; `gate` a dáta exportov z `Context` (R3).
3. Golden T0 (R0), strážcovia R4, prepis §0.3 (R5), načítanie (R6), dokumentácia (R7), **beh P porovnania s baseline** (R9.6). *(§15 A9)* Nástroj R9 (`scripts/export_porovnanie.ps1` +
   `scripts/export_porovnanie/`) a kalibrácie K0/K ~~sú v H17-0~~ — zrušené (§00); R9 = ručné P == K.
4. **H17b:** R8.

## 4 · Scope OUT

- **Brány druhu výstupu a ich texty** (§0.1 R) — v exportoch, poradie bez zmeny; žiadna tabuľka brán (D2).
- **H7 kontrakt:** `ExportSettings` (`expect_check`, normalizácia, `last_dir`…), `ProductionCore.export_expect_check`, mená exportov (`hw_csv_file_name`, `export_file_names`, `BudgetXlsx`/`CpXlsx.file_name`,
  `VepoExport.project_slug`), vety `pending_name_note`/`default_name_note`, `vepo_payload`, echo `push_vepo_bar` v `StudioDialog` — **bez zmeny**, len volané z jedného miesta.
- **Jadrá výstupov** (`VepoExport`, `HardwareSets.purchase_csv`, `BudgetXlsx`, `CpXlsx`, `CpExport`, `XlsxWriter`, `Budget`, `Validation`, `SheetLayout`) a **pomocníci `ProductionCore`**
  (`fresh_collect`, `hardware_expansion`, `budget_payload`, `control_payload`, `layout_for`, brány…) — bez zmeny (presun do jadra = ďalší rez R-15, Po V1).
- `push_state` (D6), `layout_block_reasons` (D7), `StudioDialog` obaly a relay panela, JS, payload; rozsah exportu (F6); zjednotenie viet `rescue` (F7); `run_su_tests.ps1` (R9 je samostatný skript).

## 5 · Trieda podľa CLAUDE.md

- **Audit návrhu: povinný** — nový modul (`ui/export_prep.rb`, odsek v `outputs.md`, riadok routra) a vnútorný kontrakt, cez ktorý idú všetky štyri výrobné a cenové exporty.
  Schéma, `CONFIG_SCHEMA`, BuildPlan `SCHEMA` ani STD sa nemenia. Jeden audit pre package (pred H17a); zmena kontraktu z §6 počas implementácie = delta.
- **Výrobná/cenová: ÁNO** (konzervatívne, vzor H15). Dôkaz nemennosti = golden T0 + matica odmietnutí + **porovnanie s reálnou zákazkou** (R9).
- **Predrecenzia: povinná** H17a aj H17b.
- **In-SU:** buildery, observery, undo, geometria ani akcie panela zapisujúce do modelu sa nemenia → podľa zoznamu **nie je brána**; skutočný `Bom.collect` a exporty nad živým modelom
  headless neoverí nič → **beh `run_su_tests.ps1 -CloseWhenDone` a beh porovnania R9 na finálnej hlave = DoD a podmienka mergu** každej časti (precedens H7a §5).
- **Nový ovládací prvok: nie. Fotky okien: nie** (payload ani JS sa nemení).

### 5.1 Predpoklady — *(zladené 2.10. po H7)*

| # | Predpoklad | Stav na `fe7f5405` |
|---|---|---|
| P1 | H7a: `core/export_settings.rb` (`refresh`, `last_dir`, `save_last_dir`, `project_name`, `merge_18_36`), `pending_name_note` | ✅ #456 |
| P2 | H7b: `expect` povinný fail-closed **v `ProductionCore.do_*`** po `refresh`, pred zberom (`export_expect_check` → `ExportSettings.expect_check`); `gate[:project]`/`[:merge]`/`[:note]` vo všetkých 4; `hw_csv_file_name`, `export_file_names`, `default_name_note`; `push_vepo_bar` v obaloch `StudioDialog`; `su_runner` posiela `expect` (`h7b_expect`) | ✅ #457 — **`expect` je v jadre, H17 ho presúva do `start`** |
| P3 | H15a/b: seed kovania v `core/*_seed.rb` (golden so skutočnou expanziou sa generuje až nad ním) | ✅ #459, #460 |
| P5 | H11a: `AppLifecycle.require_part` + zmrazený `MAIN_PARTS` (current main 95 → H17a 96) | ✅ #458 → R6 |
| P4 | *(§15 A7)* **H16 aj H18 sú merged** pred H17-0; main `c6bba0b9` / v0.17.26 a installed181 sú overené. Pred K a pred H17a overiť **celý** rozsah ich zmien voči `fe7f5405`: (a) telá 4 exportov, `ExportSettings`, `main.rb` (prepočítať §0.1); (b) **každú zmenu, ktorá môže meniť výstup testovacej zákazky** (H18 = závesy — zákazka má 17 ks Sensys v CSV kovania): zoznam s PR a vetou „mení / nemení výstup" ide do reportu K | ✅ source rozsah 11 plugin deltas overený (`P4_SOURCE_RANGE_c6bba0b9.md`); runtime report K čaká |
| P6 | Mapa rozširovacích bodov má scenáre 1–7 (H16 pridala 7) → H17a pridá **8** | ✅ current main po H16/H18 overený; exportný scenár bude 8 |
| P7 | **Baseline R9 a snímka ostávajú nedotknuté.** Overená snímka má 39 súborov vrátane `uni_seed.done` a `drawer_uni_seed.done`; úplný manifest je `appdata_snapshot_SHA256.txt`. Žiadne dopĺňanie živých dát, seedov alebo prepis manifestu. | **overené pri prevzatí; pred/po tvrdá brána** |

Zmena, ktorá mení zámer §6, → STOP a otázka; mechanické posuny riadkov len prepočítať.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit H17a, plugin bez zmeny, zelené na maine)

- **R0.1 Harness** `tests/pure/h17_harness.rb` (nie sada; vzory **`test_h7a_golden.rb` `NxH7G`** — `with_sandbox`, `with_doc_key`, `with_ui`, `with_now` — a `test_h14_studio_sekcie.rb`):
  `FakeModel` (`path`, `title`, `guid`), **čerstvý sandbox `Materials.test_dir_override` pre KAŽDÝ prípad**, `DocKey.key` pevný, `Time.now` zamrazený **len okolo volania exportu**
  — *(§15 A4)* **každé volanie vráti nový objekt** (`FIXED.dup`, `FIXED = Time.new(2026, 10, 1, 14, 5, 0, '+02:00')` — pásmo pripnuté), **nie** vzor `with_now` z H7 (ten istý objekt —
  `Time.now.utc` v `Budget` by ho prepol do UTC, sonda A4: 23:03 +0200 → 21:03 +0000),
  `UI` stub (záznam druhu, štartovacieho priečinka, navrhnutého mena; varianty zrušenia `nil` a `''`); **`expect` cez `NxTest.export_expect(model)`** (ako okno). **Stubujú sa len dátové
  zdroje:** `fresh_collect`, `sheets_map`, `edges_map`, `hardware_catalog_items`, `vepo_*`, `hardware_expansion` (fixtúra; + prípad skutočnej expanzie nad seedom — headless beh
  **NEOVERENÝ**; ak nejde, prípad vypadne a krytie ostáva v R9). **Nestubuje sa** nič, čo H17 mení alebo čo je brána: `do_*`, `ExportPrep`, **`ExportSettings` a `export_expect_check`**
  (názov cez `save_project_name` do sandboxu), `newer_config_stop`, `cut_stop`, `drawer_stop`, `dup_partition`, `export_blockers`, `budget_payload`, `control_payload`, `layout_for`,
  `Bom.compute`, `budget_std_block`, `export_confirm*`, `CpExport`, zapisovače. Spy (prepend) zapisuje volania G4. Každý stub počíta použitie — v šťastnej ceste musí byť **každý** použitý (S21).
- **R0.2 Fixtúra zákazky** `tests/fixtures/h17_golden/fixture.rb`: ≥ 8 dielcov v 2 skrinkách; doska 18 s cenou a doska 18 **bez ceny**; **duplák 36** s väzbou (18 + 36); hrana ABS
  s iným dekorom (D-112); názov skrátený na 20 znakov (D-121); expanzia s nacenenou, nenacenenou a nemapovanou položkou a zdrojom `per_owner`.
- **R0.3 Golden `tests/fixtures/h17_golden/`** (generátor `generate.rb`, len na nezmenenom kóde):
  - **G1 bajty (šťastná cesta):** VEPO × {zadaný názov „Kuchyňa Novák" (uložený model), predvolený „projekt" (neuložený)} × {18 + 36 zapnuté, vypnuté}; CSV kovania × 2 názvy;
    rozpočet × 2 (potvrdený správnym počtom); ponuka × 2; **automatický → automatický názov** (okno ukazovalo „projekt", model sa medzitým uložil → export prejde s `gate[:note]`);
    CSV a rozpočet so skutočnou expanziou. Pre každý: mená súborov a priečinka; **celý text** CSV a LOG (`Engine::VERSION` → `«VERSION»`, práve **1** náhrada); XLSX SHA-256 +
    veľkosť; záverečná veta (dočasná cesta → `«DIR»`), farba, `repush`, volania pickera, uložený `last_dir`.
  - **G2 matica odmietnutí** — každý spúšťač × **každý export z `ExportPrep::KINDS`** *(§15 A5 — test iteruje `KINDS` cez skutočný vstup `ProductionCore.send(KINDS[k])`, nie pevný
    zoznam 4; spoločné spúšťače úvodu pre každý registrovaný export povinne; inventár testovaných exportov == `KINDS`)* (veta, farba, `repush`, picker **0**, zápisy **0**, `last_dir`
    nezmenený, poradie G4): zastaraná generácia · `flush_blocked` ·
    **`expect`** chýba · `{}` · zlý tvar (`merge` nie boolean, neznámy `source`) · iný zadaný názov · zadaný ↔ automatický · iné 18 + 36 (VEPO stojí, CSV/XLSX prejdú) · výnimka v
    `expect_check` (`EXPECT_FAILED`) · novšia skrinka/doska · chrbát (každý kód `Bom::CUT_BLOCKERS`) · expanzia `nil` (receptová položka, výklop, bez oboch) · expanzia prázdna ·
    *(§15 A2)* **sekvencie expanzie `nil → nil` a `nil → platná`** (stub `hardware_expansion` so sekvenciou návratov; dnes `budget_payload` pri `hw_exp == nil` volá expanziu
    **druhýkrát** — `production_core.rb:2236` — rozpočet/ponuka/kontrola VEPO berú výsledok druhého volania; zaznamená sa počet skutočných expanzií) ·
    `drawer_kit_missing` · konflikt stavby · `lift_set_incomplete` · `hinge_set_mismatch` · duplicity blokujúce/neškodné/dosky · rozpočet `nil` · `budget_std` · `assembly_negative` ·
    `consistent: false` · bez ceny bez potvrdenia / zlý počet / správny · picker zrušený (`nil`, `''`) · VEPO bez dielcov · výnimka v `Bom.compute`, `control_payload`,
    `SheetEstimate.estimate` (→ rozpočet `nil`), v zápise (cudzí súbor vo VEPO priečinku, `vepo_export.rb:332`).
  - **G3 súbeh brán:** generácia + flush · flush + `expect` · **`expect` + novšia schéma** · novšia + chrbát · chrbát + kit · `budget_std` + kovanie · rozpočet `nil` + kovanie ·
    expanzia `nil` + kovanie (CSV) · kovanie + duplicity · duplicity + bez ceny · duplicity + `cp`.
  - **G4 poradie krokov (spy):** `ExportSettings.refresh`, `export_expect_check` (**práve 1×**), `fresh_collect`, `newer_config_stop`, `cut_stop`, `hardware_expansion`, `Bom.compute`,
    `budget_payload`, `control_payload`, `budget_std_block`, `CpExport.specification`, `drawer_stop(scope)`, `dup_partition`, `export_confirmations`, `ExportSettings.last_dir`, `UI.*`,
    `VepoExport.build/write`, `HardwareSets.purchase_csv`, `XlsxWriter.write/write_book`, `CpExport.firewall_hits`, `ExportSettings.save_last_dir`, `pending_name_note`, `default_name_note`,
    `repush`, `status`, *(§15 A3)* **`sheets_map` v poradí** (ponuka: `Bom.compute` → `sheets_map` → `hardware_expansion` → `budget_payload`; rozpočet: `sheets_map` až vnútri
    `budget_payload`, teda po expanzii). Ostatné čítania katalógov (`edges_map`, `hardware_catalog_items`, `vepo_*`) len **počtom** (nesmú stúpnuť). *(§15 A4)* + G1 prípad
    „lokálny čas po rozpočte": VEPO LOG `Dátum:` a 1. riadok CSV kovania = zamrazený **lokálny** čas aj po výpočte rozpočtu (`Time.now.utc` ho nesmie posunúť).
  - **G5 parita Kontroly:** počty KONTROLA vo VEPO LOGu == `counts` pushu Štúdia (harness H14 T0b) nad tou istou fixtúrou s rozpočtovým ORANGE.
  - **G6 parita Nárezového plánu:** pre G2 novšia / chrbát / kit: VEPO stojí ⇔ `layout_block_reasons` neprázdne s tými istými dôvodmi.
- **R0.4** Fixtúry, harness a `tests/pure/test_h17_golden.rb` v **1. commite**, zelené na maine; po H17a **neregenerované** (H17b len R8.4 samostatným commitom).

### R1 · Modul `Noxun::Engine::ExportPrep` (`ui/export_prep.rb`, `module_function`) — *(zladené 2.10. po H7)*

- **R1.1 Konštanty:** `KINDS = { vepo: 'do_export', hw_csv: 'do_hw_csv', budget: 'do_budget_xlsx', offer: 'do_cp_xlsx' }.freeze` · `GEN_MSG`, `FLUSH_MSG` (doslovný presun).
- **R1.2 `start(model, data, kind, generation:, status:, repush:) → Context | nil`** — poradie **záväzné** (= dnešné):
  1. `kind` mimo `KINDS` → `ArgumentError` (chyba programu, padne do `rescue` exportu),
  2. generácia → `repush.call`, `status.call(GEN_MSG, true)` → `nil`,
  3. `flush_blocked` → `status.call(FLUSH_MSG, true)` → `nil`,
  4. `ExportSettings.refresh` (výsledok ignorovaný),
  5. **`gate = ProductionCore.export_expect_check(model, data, merge: kind == :vepo)`** — **práve raz** (S5); `gate[:stop]` → `status.call(gate[:stop], true)` → `nil`. Funkcia ostáva v
     `ProductionCore` (H7b); `start` ju **volá**, nekopíruje ani nemení,
  6. `ctx = Context.new(model, kind, gate)`, `ctx.collected`,
  7. `ProductionCore.newer_config_stop(ctx.collected)` → veta → `nil`,
  8. `ProductionCore.cut_stop(ctx.collected)` → veta → `nil`,
  9. → `ctx`.
  **Žiadny `rescue`** (S9). Nevolá picker, nezapisuje súbor (okrem toho, čo už dnes môže zapísať `expect_check` cez prenos názvu — S5), nemení generáciu ani okno.
- **R1.3 Volanie:** `ctx = ExportPrep.start(model, data, :vepo, generation: generation, status: status, repush: repush)` · `return unless ctx` — **prvý príkaz** tela exportu (vnútri
  `def … rescue`). Návratová hodnota `do_*` pri zastavení v úvode je `nil` — **nie je kontrakt**; PR Grepom doloží, že ju nečíta `StudioDialog` (obaly volajú `push_vepo_bar` po návrate
  bez ohľadu na ňu), `panel.rb`, `su_runner.rb` ani test (D10).
- **R1.4 Bez stavu modulu:** žiadne `@`/`@@` na úrovni modulu, žiadna meniteľná konštanta; `Context` žije len počas jedného volania exportu.

### R2 · `ExportPrep::Context` — lenivé dáta jedného exportu — *(zladené 2.10. po H7)*

- **`gate`** (zmrazený Hash z `start`) + čítačky **`project`** = `gate[:project]`, **`merge`** = `gate[:merge]`, **`name_note`** = `gate[:note]` — jediný zdroj názvu a 18 + 36 v exporte
  (dnes `gate[:project]` 4×, `gate[:merge]` 1×, `gate[:note]` 4×).
- **Čítačky s pamäťou vrátane `nil`:** `collected` = `ProductionCore.fresh_collect(model)` · `bom` = `Bom.compute(collected)` · `smap` = `ProductionCore.sheets_map` ·
  `hw_exp` = `ProductionCore.hardware_expansion(model, collected)` · `budget` = `ProductionCore.budget_payload(model, bom, collected, nil, hw_exp, smap)` (bez `estimate`/`layout` — S9, D5) ·
  `control` = `ProductionCore.control_payload(collected, hardware_expansion: hw_exp, budget: budget, sheets: smap)`; atribúty `model`, `kind`.
- *(§15 A2)* **Pamäť `nil` platí pre čítačku, nie pre `budget_payload`:** `ctx.hw_exp` sa vyhodnotí raz (aj keď vráti `nil`), ale `budget` mu podá **ten istý `nil`** a dnešný
  fallback `exp = hw_exp || hardware_expansion(…)` (`production_core.rb:2236`) expanziu **zopakuje** — ako dnes (sonda A2: `nil → nil` aj `nil → platná` = **2** skutočné expanzie,
  rozpočet vznikne). Kontext ho **nesmie obísť** (napr. podať `{}` alebo platnú expanziu z inej cesty) — to by bola zmena správania, nie presun. Testy rozlišujú **počet vyhodnotení
  čítačky** (1) od **počtu skutočných expanzií** (dnešný počet, G2 sekvencie).
- *(§15 A3)* **Poradie prvých čítaní je súčasťou kontraktu exportu**, nie kontextu: ponuka vyhodnotí výslovne `ctx.bom` → `ctx.smap` → `ctx.budget` (dnes `Bom.compute` → `sheets_map` →
  expanzia → `budget_payload`); rozpočet `ctx.bom` → `ctx.hw_exp` → `ctx.budget` (`sheets_map` sa vyhodnotí v argumentoch `budget`, po expanzii — ako dnes vnútri `budget_payload`);
  VEPO `ctx.hw_exp` pred pickerom, po ňom `ctx.bom` → `ctx.smap` → `ctx.control`.
- Volania **cez prijímač modulu** (S15); žiadny `rescue`, čas ani picker; prvé čítanie určuje poradie (VEPO číta `bom`/`budget`/`control` až po pickeri).
- **Čerstvosť:** kontext vzniká len v `start`, nikdy sa nezdieľa s oknom ani medzi exportmi (čerstvý zber = poistka proti prestavbe bez zdvihu generácie — komentár „VEDOMÁ ZMENA (audit #15)").

### R3 · Exporty po H17a — čo ostáva v exporte (v dnešnom poradí) — *(zladené 2.10. po H7)*

| Export | Po `start` (ostáva v tele) |
|---|---|
| VEPO | `drawer_stop(ctx.collected, ctx.hw_exp, scope: :kit)` → `ExportSettings.last_dir` + overenie + `select_directory` → `bom`, `control` z kontextu → `build(project: ctx.project, merge_18_36: ctx.merge, …)` → „Niet čo exportovať" → `write` → `save_last_dir(dir)` → veta + `pending_name_note` + `default_name_note(model, ctx.project)` + `ctx.name_note` |
| CSV kovania | `exp = ctx.hw_exp` → `nil` / prázdne → `drawer_stop(…)` → duplicity → `hw_csv_file_name(ctx.project)` → `savepanel` → CSV + BOM → `save_last_dir` → veta + to isté |
| XLSX rozpočtu | `budget = ctx.budget` → `nil` → `budget_std_block` → kovanie → duplicity → potvrdenie → `BudgetXlsx.file_name(ctx.project, now)` → `savepanel` → `.xlsx` → zápis → `save_last_dir` → `repush` pri `plan_prices` → veta + to isté |
| XLSX ponuky | *(§15 A3)* `ctx.bom` → `ctx.smap` → `budget = ctx.budget` → `nil` → `budget_std_block` → `cp`, `spec(ctx.collected[:records], sheets: ctx.smap, hardware_expansion: ctx.hw_exp, budget:)` → kovanie → duplicity + `cp` → potvrdenie → `CpXlsx.file_name(ctx.project, now)` → `savepanel` → hárky, firewall → zápis → `save_last_dir` → `repush` → veta + to isté |

Každý export si nechá svoj `rescue` (veta + `Engine.log_error(e, 'ProductionCore.do_…')`) a komentáre „prečo" pri bránach; komentáre úvodu (KOV-H1, GHOST-D1, D-143, 1b-6c, audit #15,
H7b §16 B2/§17 C1) sa **presunú** k `start`, nie zmažú.

### R4 · Strážcovia (`tests/pure/test_h17_export_prep.rb`) — *(zladené 2.10. po H7)*

- **a) Jedno miesto úvodu:** v telách exportov z `KINDS` nie je `fresh_collect(`, `newer_config_stop(`, `cut_stop(`, `ExportSettings.refresh`, **`export_expect_check(`**, `GEN_MSG`/`FLUSH_MSG`
  text; v `export_prep.rb` je `export_expect_check(`, `newer_config_stop(` a `cut_stop(` **práve raz**; behaviorálne G4 „`export_expect_check` 1× na export".
- **b) Nový výstup = riadok `KINDS`:** množina funkcií v `noxun_engine/**/*.rb` s `UI.savepanel`/`UI.select_directory` **== hodnoty `KINDS`**; každá volá `ExportPrep.start(` so svojím kľúčom
  pred pickerom. Hláška: „nový výstup: pridaj riadok do ExportPrep::KINDS a začni ExportPrep.start — žiadna kópia úvodu". *(§15 A5)* Textová kontrola volania nestačí (export môže `start`
  zavolať a `nil` ignorovať) — **rešpektovanie odmietnutia dokazuje G2** pre každý riadok `KINDS` (spoločné spúšťače úvodu: picker 0, zápisy 0); strážca b) navyše overí, že množina exportov
  v matici G2 == `KINDS` (nový riadok bez behu matice zhodí test).
- **c) Bez stavu:** `export_prep.rb` mimo `class Context` bez `@`; `@@` nikde; `Context.new` len v `start`; dva exporty po sebe = dva zbery a dve brány `expect`.
- **d) Načítanie:** `main.rb` `AppLifecycle.require_part 'noxun_engine/ui/export_prep'` hneď za `ui/production_core`, pred `ui/studio_dialog`; `MAIN_PARTS` v `test_h11a_nacitanie.rb` = 96 (current main 95 → H17a 96);
  `tests/helper.rb` ho načíta; súbor pri načítaní nevolá nič mimo definícií.
- **e) Dáta a názov len z kontextu:** v telách exportov z `KINDS` nie je `Bom.compute(`, `hardware_expansion(`, `budget_payload(`, `control_payload(`, `sheets_map`, `gate[` ani
  `project_name(` (názov = `ctx.project`).
- **f) Rozdielne brány ostali** — behaviorálne cez G2, nie textom.

### R5 · Prepis textových strážcov (§0.3)

Každý rozbitý assert sa **nahradí ekvivalentom** (nie zmaže): poradie úvodu (`test_h7b_nazov_zakazky.rb:382-398`, `test_ghost_d1_dosky.rb`, `test_kon0_d143.rb`) → G4 + R4 a
(poradie v `start`, nie v tele); „18 + 36 len VEPO" → G2 (iné 18 + 36: VEPO stojí, ostatné prejdú) + R4 a (`merge: kind == :vepo` v `start`); „štyri exporty majú bránu" → R4 a + G2;
„VEPO kontrola s rozpočtom" → G5; „CSV má gen, flush, čerstvý zber a serverový názov" → G2 + R4 a/e; `merge = gate[:merge]`, `project = gate[:project]` → R4 e + G1 (súbor nesie overený
názov a 18 + 36); komentár „VEDOMÁ ZMENA (audit #15)" → strážca číta komentár pri `ExportPrep.start`. **PR vypíše každý prepísaný assert a jeho náhradu.**

### R6 · Načítanie — *(zladené 2.10. po H11a)*

`main.rb`: `AppLifecycle.require_part 'noxun_engine/ui/export_prep' # H17: spoločná príprava 4 exportov (volá ProductionCore za behu)` hneď za `ui/production_core`; **zmrazená kópia**
`NxH11aLoad::MAIN_PARTS` v `test_h11a_nacitanie.rb` doplnená (current main 95 → H17a 96, poradie). `tests/helper.rb`: `ui/export_prep` na koniec zoznamu (headless) — výnimka z „UI nie je v helperi"
s komentárom (S21). Alternatíva D3: `require` v ~15 testoch — horšia (zabudnutie je tiché).

### R7 · Dokumentácia H17a (na mieste, nie na koniec)

`docs/architecture/outputs.md`: **nový odsek `### export_prep.rb`** za `### production_core.rb` (kontrakt `start` a poradie, `Context` s `gate`, pamäť vrátane `nil`, `KINDS`, tabuľka R3,
ako pridať výstup, strážcovia R4, prečo `ui/`); v odseku `production_core.rb` prepísať odstavce o úvode exportov (`:249`, `:257`, `:286` — „hneď po `fresh_collect`", „vo všetkých štyroch",
„VEPO si preto expanziu…") a odsek **„Názov zákazky v okne a `expect` (H7b)"** (`:467-484` — „brána beží v každom zo štyroch exportov" → „v `ExportPrep.start`, raz na export");
odsek `### export_settings.rb` (`:1083+`) — veta o volajúcom `expect_check`. `docs/ARCHITEKTURA.md`: riadok routra `export_prep.rb` (`ui/export_prep.rb`). `rozsirovacie-body.md`: **scenár 8
„Nový výstup (export)"** — (1) riadok `ExportPrep::KINDS`, (2) `ProductionCore.do_<výstup>`: `ExportPrep.start` → vlastné brány → picker → zápis → `save_last_dir` → vety názvu, (3) obal
v `StudioDialog` + callback + `push_vepo_bar`, (4) `expect` z okna a meno do `export_file_names` (tooltip), (5) prípad v golden H17 a v porovnaní R9, (6) odsek v `outputs.md`; „čo ťa
zastaví" = R4 b. `AUDIT_REGISTER.md` R-15: „prvý rez ✅ H17a (PR #?)". **Grep zoznamov:** „VSETKY STYRI exporty", „štyri exporty", „hneď po `fresh_collect`", „v každom zo štyroch exportov".
`scripts/export_porovnanie.ps1`: hlavička s návodom (vzor `ui_foto.ps1`) + jedna veta v CLAUDE.md sekcii Testovanie **len ak to orchestrátor povolí** (CLAUDE.md mení Michal — D15).

### R8 · H17b — koniec exportu (voliteľná, D9) — *(zladené 2.10. po H7)*

- **R8.1 `ExportPrep.start_dir`** = `ExportSettings.last_dir`, ak `String` ∧ `File.directory?`, inak `nil` — všetky 4 pickery (N1; komentár `export_settings.rb:287` to H17 priamo zveruje).
  Bajty súborov bez zmeny; mení sa len štartovací priečinok, keď uložený neexistuje alebo nie je text (pri nie-texte je dnešné správanie CSV/XLSX **NEOVERENÉ** — `savepanel` môže vyhodiť).
- **R8.2 `ExportPrep.remember_dir(dir)`** → `ExportSettings.save_last_dir(dir)`, výsledok ignorovaný (H7 D5).
- **R8.3 `ExportPrep.name_suffix(ctx)`** = `pending_name_note(model)` + `default_name_note(model, ctx.project)` + `ctx.name_note` — jedno miesto namiesto 4 kópií (S13); farba bez zmeny.
- **R8.4** Golden: prípady N1 (uložený priečinok neexistuje · číslo · objekt) — CSV/XLSX štartovací priečinok `nil`; samostatný commit „vedomá zmena N1"; ostatné bez zmeny. R9 beh P znova.

### R9 · Porovnanie s reálnymi exportmi testovacej zákazky — *(prepísané 9.10.2026, rozhodnutie Michala: H17-0 zrušené)*

**Pôvodný R9 (nástroj `scripts/export_porovnanie.ps1`, kalibrácie K0/K, izolácia profilu) a celá časť H17-0 sú ZRUŠENÉ** (Michal 9.10.2026, §00). Michalova požiadavka 2A
(porovnanie s reálnou zákazkou) ostáva, ale **bez nástroja v repe** — ako jednoduchý krok pred mergom:

- **R9.1 K (pred nasadením vetvy):** Michal v SketchUpe s nainštalovaným `main` (v0.17.28) otvorí testovaciu zákazku (`_dev\h17_baseline\Export v0_17_24\TEST v0 17 24.skp`
  alebo jej kópiu) a urobí 4 exporty do priečinka `_dev\h17_baseline\K_0.17.28\` (VEPO, CSV kovania, XLSX rozpočtu, XLSX ponuky). Model sa medzi K a P **neukladá**.
- **R9.2 P (po in-SU runneri, ktorý nechá nasadenú vetvu):** tie isté 4 exporty z toho istého modelu do `_dev\h17_baseline\P_<verzia>\`.
- **R9.3 Porovnanie (orchestrátor, len čítanie, skript v scratchpade — nie v repe):** CSV a LOG textovo riadok po riadku; povolený rozdiel je **len** riadok `Verzia:` a `Dátum:`
  vo VEPO LOGu, 1. riadok CSV kovania (čas) a dátum v názve XLSX; XLSX = rozbalené `xl/**/*.xml` a `[Content_Types].xml` porovnané bajtovo (dátum v titulku hárku povolený).
  Každý iný rozdiel = **P ≠ K → nemergovať** (najviac 2 pokusy, potom dávka čaká a ide do reportu).
- **R9.4** Baseline v0.17.24 (`SHA_baseline.txt`) sa už **neporovnáva** — medzi v0.17.24 a mainom sú H16, H18, H18b a ŠÍRKA 50 (môžu meniť výstup zákazky); parita refaktoru = **P == K**.

## 7 · Testy a DoD

- **T0 · Golden PRED zásahom** (R0) — zelené na maine, bez regenerácie po H17a (H17b len R8.4).
- **T1 · Kontext:** *(§15 A2)* pamäť čítačky vrátane `nil` — `ctx.hw_exp` sa pri `nil` **vyhodnotí raz** (počet vyhodnotení čítačky), **počet skutočných expanzií = dnešný**
  (`nil → nil` a `nil → platná`: 2 pri ceste cez `budget`, rozpočet z druhého výsledku — S25); `gate` nemenný a z jedného volania; poradie prvých čítaní (ponuka `bom` → `smap` →
  `budget`, §15 A3); výnimka čítačky prejde von; `budget` s `estimate = nil`, `layout = nil`; dva kontexty = dva zbery. *(§15 A4)* Harness: `Time.now` vráti nový objekt; po výpočte
  rozpočtu je `Time.now.strftime('%H:%M %z')` stále zamrazený lokálny čas.
- **T2 · `start`:** každá vetva R1.2 (veta, farba, `repush`, `nil`), poradie, `merge: true` len pri `:vepo`, neznámy `kind` → v exporte „Chyba exportu: …", výnimka v zbere → veta `rescue` exportu.
- **T3 · Strážcovia R4 a–f.** **T4 · Prepis R5** (zoznam v PR). ~~T9~~ zrušené (§00).
- **T5 · Mutácie — každá má test, ktorý ju zhodí** (PR priloží beh každej):

| M | Mutácia | Zhodí |
|---|---|---|
| M1 | `start` bez `repush` pri generácii | G2 |
| M2 | flush pred generáciou | G3 |
| M3 | `refresh` až po bráne `expect` alebo po zbere | G4 |
| M4 | `expect` po zbere · `merge: true` aj pre XLSX · `merge: false` vo VEPO | G2 (iné 18 + 36), G3, G4 |
| M5 | chrbát pred novšou schémou | G3 |
| M6 | `rescue` v `start` alebo v čítačke | G2 (výnimka v zbere, `Bom.compute`, `control_payload`) |
| M7 | pamäť nepamätá `nil` | T1, G2 |
| M8 | `budget` dostane `estimate` spočítaný v kontexte | G2 (výnimka v `SheetEstimate`) |
| M9 | VEPO číta `bom`/`control` pred pickerom | G4 |
| M10 | VEPO kovanie `:all` | G2 |
| M11 | CSV/XLSX kovanie `:kit` | G2 |
| M12 | duplicity aj vo VEPO | G2 |
| M13 | `budget_std_block` v CSV | G2 |
| M14 | kontext uložený v module | T1, R4 c |
| M15 | nová funkcia so `savepanel` bez `start` | R4 b |
| M16 | export volá `Bom.compute` priamo | R4 e |
| M17 | `export_prep` chýba v helperi / v `MAIN_PARTS` | R4 d, T0 |
| M18 | kontext volá `Bom.collect` priamo | R0.1 „každý stub použitý", G1 |
| M19 | „Niet čo exportovať" pred pickerom | G2 |
| M20 | veta generácie bez červenej | G2 |
| M21 | kontext vynechá `budget:` v `control_payload` | G1 (LOG KONTROLA), G5, **R9** |
| M22 | **`export_expect_check` 2× na export** (napr. znova v exporte pre názov) | G4 (počet), R4 a |
| M23 | **export pomenuje súbor cez `ExportSettings.project_name` namiesto `ctx.project`** | R4 e, G1 (názov nad 120 znakov — normalizácia, H7b review #457) |
| M24 | **`ctx.name_note` vynechaný vo vete** (automatický → automatický) | G1 |
| ~~M25~~ | zrušené s nástrojom R9 (§00) | — |
| M26 | *(§15 A2)* kontext „opraví" fallback — `budget` dostane `{}` alebo `ctx.hw_exp` sa pri `nil` prepočíta | G2 sekvencie `nil → nil`, `nil → platná` (počet skutočných expanzií, obsah rozpočtu) |
| M27 | *(§15 A3)* ponuka vyhodnotí `ctx.budget` bez predošlého `ctx.smap` (poradie `bom` → `hw_exp` → `smap`) | G4 (poradie `sheets_map`) |
| M28 | *(§15 A4)* harness/R9 vracia ten istý objekt času | T1 (lokálny čas po rozpočte), G1 (`Dátum:` v LOGu) |
| M29 | *(§15 A5)* **piaty registrovaný export zavolá `start`, ale ignoruje `nil`** (pokračuje k pickeru) | G2 nad `KINDS` (picker > 0 pri spúšťači úvodu), R4 b (inventár G2 == `KINDS`) |
| ~~M30~~ | zrušené s nástrojom R9 (§00) | — |
| ~~M31~~ | zrušené s nástrojom R9 (§00) | — |

- ~~T9b~~ zrušené s nástrojom R9 (§00).
- **T6:** `ruby tests/run_all.rb` + **každá JS sada zvlášť** + `ruby scripts/encoding_guard.rb --repo`.
- **T7 · In-SU** (§8): H17a/H17b → runner + **R9 P == K** (§00).
- ~~DoD H17-0~~ zrušené (§00).
- **DoD H17a/H17b:** T0 bez zmeny fixtúr · T1–T5 zelené · mutácie v PR · runner s hlavou v PR · **R9 P == K** (§00) s výsledkom porovnania v PR · docs §11 · PR s „Predrecenziou" a vetou „bez viditeľnej zmeny — golden H17 nedotknutý, exporty testovacej zákazky zhodné (P == K)".

## 8 · In-SU — nie je spúšťač; runner + R9 P == K (§00) = DoD a podmienka mergu

`scripts\run_su_tests.ps1 -CloseWhenDone` na finálnej hlave (worktree: `_dev\ENGINEtests.skp` skopírovať z hlavného checkoutu; `exit 2` = počkať) — kryje ST-1a/1c, KOV-C2b, R-14, H7b
`expect` nad živým modelom. **R9 (§00):** Michal urobí exporty **K pred** nasadením vetvy (main v0.17.28 nainštalovaný); runner nasadí vetvu a nechá ju nasadenú → Michal urobí
exporty **P** z toho istého neuloženého modelu → orchestrátor porovná (R9.3). SketchUp nikdy nezabíjať.
Pád alebo P ≠ K = nemergovať (najviac 2 pokusy, potom dávka čaká).

## 9 · Riziká

1. **Pamäť `nil`** — dve pravdy v jednom exporte. Ochrana: R2, T1, M7.
2. **Dvojitá brána `expect`** — druhé volanie môže vidieť stav po prenose názvu (iná `:note`) a dvakrát čítať súbor. Ochrana: R1.2 krok 5, R4 a, G4, M22.
3. **Zmena výnimkovej cesty** — S9, R1.2, R2, G2, M6, M8.
4. **Posun poradia** — lenivý kontext, G3, G4, M2–M5, M9.
5. **Stuby testov prestanú zachytávať** / **nenačítaný modul** (tiché prejdenie) — R0.1, R6, M17, M18.
6. **Oslabenie strážcov pri prepise** (vrátane H7b) — R5 1:1 v PR, mutácie, behaviorálne H7b testy bez zmeny.
7. **Golden zakryje rozdiel normalizáciou** — len VERSION a dočasná cesta; čas zamrazený.
8. **Porovnanie R9 zlyhá z cudzieho dôvodu** (model uložený alebo upravený medzi K a P, zmena katalógu, iný názov) — K a P z toho istého neuloženého modelu
   v jednej relácii bez zásahu do katalógov; nevysvetlený rozdiel = nemergovať (§00).
9. **Kolízia s H16/H18** — §5.1 P4, P6.

## 10 · Smoke checklist pre Michala (po H17a; H17b bod 4)

> *(§00)* Porovnanie K ↔ P (R9) robí Michal exportmi a orchestrátor porovnaním **pred mergom**; baseline v0.17.24 sa už neporovnáva (R9.4).

1. Otvor reálnu zákazku a urob všetky 4 exporty (VEPO, Nákup → CSV kovania, Rozpočet → XLSX, Ponuka → XLSX) — mená, počty v správe a sumy ako zvyčajne.
2. Zákazka s riadkom bez ceny: Rozpočet → XLSX zastaví s tou istou vetou ako predtým; druhý klik a potvrdenie súbor vytvorí.
3. V okne výberu klikni **Zrušiť** → „Export zrušený."; VEPO export s otvoreným Inspectorom (rozpísaný rozmer) vyexportuje nový rozmer; prepíš názov v hlavičke a hneď klikni na export —
   ako po H7 (export pod novým názvom, alebo veta, prečo sa nespustil).
4. *(H17b)* Premenuj priečinok, do ktorého si naposledy exportoval → CSV kovania aj XLSX otvoria okno výberu bez chyby, súbor sa uloží.

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** → T0–T6 zelené → runner + R9 P == K (§8, §00) → architektúra na mieste (R7; H17b: odsek `export_prep.rb` o koniec exportu)
→ Grep zoznamov (R7) → `AUDIT_REGISTER.md` R-15 (H17a) → prepis `STAV.md` → odsek navrch „Záznamy dávok" v `KRONIKA.md` (mutácie, počty testov, hlava runnera, **výsledok R9 P voči K** (§00),
zoznam R5) → `PLAN.md` H17 (H17a/H17b, ✅ + PR) → číslo PR samostatným commitom. Implementátor H17a skopíruje package a surový audit do `SYSTEM/zdroje/bloky/HARDENING/` a brief do `briefy/`.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Nový súbor `ui/export_prep.rb`** (`ExportPrep` + `ExportPrep::Context`) — nie `core/`, nie vnútri `production_core.rb` | `core/` nevolá `ui/` (S19); pamäť kontextu by v `production_core.rb` narazila na guard inštančných premenných; jedno miesto pre budúce výstupy, prvý krok R-15. Alternatíva: vnorený modul v `production_core.rb` s pamäťou v Hashi | **áno** |
| D2 | Spoločný je len úvod 1–7; brány druhu výstupu ostávajú výslovne v exporte | CX R-15; rozdielny rozsah a poradie (S12) | **áno** |
| D3 | `tests/helper.rb` načíta `ui/export_prep` | pasca S21 | **áno** |
| D4 | Lenivý kontext (nie `prepare(kind)` vopred) | dnešné poradie a výnimkové cesty | krátko |
| D5 | `budget` bez `estimate`/`layout` | S9; výsledok rovnaký (S8) | nie |
| D6 | `push_state` ostáva samostatný; parita G5 | horúca cesta, iné argumenty a výnimky; ďalší rez R-15 (F4) | **áno** |
| D7 | `layout_block_reasons` ostáva; parita G6 | ďalší rez (F5) | nie |
| D8 | Čítania katalógov sa necachujú (okrem `smap`) | výstup nemenia | nie |
| D9 | **H17b voliteľná** | H17a je celý prvý rez; N1 je jediná zmena správania | **áno** |
| D10 | Návratová hodnota `do_*` nie je kontrakt | dnes ju nikto nečíta | nie |
| D11 | Golden normalizuje len VERSION a dočasnú cestu | iné normalizácie by zakryli rozdiel | nie |
| ~~D12~~ | zrušené (§00) — nástroj porovnania do repa sa nerobí | — | — |
| ~~D13~~ | zrušené (§00) — H17-0 sa nerobí | — | — |
| D14 | *(nové)* **Čas zamrazený na 2026-10-02 23:03** počas exportu (nie porovnanie „okrem dátumu/času") | presnejšie — porovná aj `Dátum:` a 1. riadok CSV; XLSX len bez DOS polí; zamrazenie len okolo volania, zámky bežia na monotónnych hodinách | krátko |
| ~~D15~~ | zrušené (§00) | — | — |

## 13 · Otázky pre Michala (do odpovede platí predvoľba)

- ~~**Q1 · Porovnanie exportov pred a po**~~ — **zodpovedané 2.10.2026:** Michal dodal baseline `_dev\h17_baseline\` (v0.17.24); porovnanie robí agent automaticky (R9).
- **Q2 · Názov testovacej zákazky po znovuotvorení** (F9, nie brána H17): názov „TEST pr v 0,17,24" si plugin zatiaľ pamätá len pre reláciu, v ktorej si ho zadal (model vtedy ešte nebol
  uložený). Keď súbor `TEST v0 17 24.skp` otvoríš znova, hlavička Štúdia pravdepodobne ukáže „TEST v0 17 24 · podľa súboru". *Predvoľba:* nič nemeníme (H7 tak funguje — názov sa
  k súboru prenesie pri najbližšom čítaní po uložení v tej istej relácii); ak to chceš inak, ide to do zásobníka k G-02. Vratné.

## 14 · Nálezy mimo scope

- **F1 · N1** → H17b. **F2** VEPO „Niet čo exportovať" až po výbere priečinka (`:1763-1765`). **F3** XLSX bez kontroly prázdnej zákazky — **NEOVERENÉ**.
- **F4** `push_state` = piaty skladateľ → ďalší rez R-15 (OutputPackage v jadre). **F5** `layout_block_reasons` = šiesta kópia poradia brán VEPO.
- **F6** Rozsah exportu: vždy celý model; výstup „len vybrané skrinky" musí rozsah pridať výslovne. **F7** Štyri vety `rescue` — produktová vec.
- ~~F8~~ zrušené (§00).
- **F9** *(nové)* **Názov zadaný pred prvým uložením sa prenesie k súboru až pri najbližšom čítaní názvu po uložení** (push Štúdia, export) v tej istej relácii; Ctrl+S Štúdio nepushuje —
  ak sa SketchUp zatvorí skôr, názov sa po znovuotvorení stratí (dôkaz: Michalov `vepo_settings.json` 23:04 má „TEST pr v 0,17,24" pod kľúčom sedenia, súbor uložený 23:06; či relácia
  ešte beží, **NEOVERENÉ**). Patrí k H7/G-02 (D-číslo navrhne orchestrátor), H17 to nemení.


### 14b · Rozhodnutia orchestrátora pred auditom (2.10.2026 ~23:50) — text bez zmeny

**Rozhodnutia orchestrátora pred auditom (2.10.2026 ~23:50):** snímka katalógov presunutá do `_dev/h17_baseline/appdata_snapshot/` (gitignored, overené `diff -r`)
— nástroj R9 ju berie odtiaľ, nie zo scratchpadu. **D12 áno** (nástroj porovnania v repe). **D13: nástroj R9 + kalibrácia K na nezmenenom kóde ako samostatný malý PR
„H17-0" PRED H17a** (len `scripts/` + testy nástroja, plugin bez zmeny → bez bumpu verzie; K = dôkaz, že nástroj na dnešnom kóde dá zhodu s baseline alebo
vysvetlený posun vstupov). **D14 áno** (zamrazený čas len počas exportu). Poradie bloku: H16 → H18 → H17-0 → H17a → H17b (voliteľná) → uzáver; H18b čaká na Michala (Q2).

---

## 15 · Audit návrhu — zapracovanie (Codex gpt-6-astra, 2.10.2026) — 1 BLOCKER · 6 FIX-IN-H17a · 2 NOTE · MÁ PREDNOSŤ

Surový výstup `AUDIT_H17_raw.md` (implementátor H17-0 ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package). Čísla riadkov auditu = `_dev/audit_h17/PACKAGE_H17.md` pred
zapracovaním. Tvrdenia A1, A2, A4 overila **sonda `sonda_h17_audit.rb`** (`sonda_h17_audit_out.txt`; sandbox `tests/helper.rb`, strom `fe7f5405`, **kópia** snímky — živý profil ani
baseline sa nemenili; S23–S26); A3, A5–A9 čítaním kódu a package. **Všetky body zapracované; koncept refaktoru (H17a) sa nemení** — mení sa nástroj a protokol R9 (izolácia profilu,
kalibrácia K0/K, hranica porovnania) a spresňujú sa testy kontextu.

| # | Nález | Overenie | Dispozícia a zmena v package |
|---|---|---|---|
| **A1** BLOCKER (H17-0) | R9 izoluje len dva katalógy a len počas exportu; init pluginu a úložiská čítajúce `ENV['APPDATA']` priamo by išli do živého profilu; obnova v `ensure` pri živých observeroch | **potvrdené:** S23 (8 úložísk mimo `test_dir_override` + bázy), S24 (init nad kópiou snímky obsahovo bez zmeny, zapisuje len značky a zámok — v snímke chýbajú); poradie `-RubyStartup` voči načítaniu pluginu **NEOVERENÉ** (MCP bridge offline, SketchUp sa v sonde nespúšťa) | **zapracované:** **R9.2 b** — prvý príkaz `boot.rb` `ENV['APPDATA'] = '<run_*>/AppData'` (vzor `run_su_tests.ps1:194`, `ui_foto.ps1:214`), sandbox = **úplná kópia snímky vrátane `*.done`**, **žiadne obnovovanie** do konca procesu, `test_dir_override` sa nepoužíva · **R9.2 c** — `boot.rb` zapíše, či bol plugin načítaný pred ním; keď áno, init bežal nad živým profilom ako pri každom štarte (S24: obsahovo bez zmeny) · SHA živého `NOXUN\Engine\*.json` pred/po (len čítanie, varovanie v reporte) · **P7** doplniť `uni_seed.done`, `drawer_uni_seed.done` + manifest snímky · **T9b**, **M30** |
| **A2** FIX-IN-H17a | `budget_payload` pri `hw_exp == nil` expanziu zopakuje (`production_core.rb:2236`); S7/T1 „nil → 1 volanie" odporuje zachovaniu správania | **potvrdené:** S25 (`nil → nil` aj `nil → platná` = 2 expanzie; pri `nil → platná` rozpočet z platnej) | **zapracované:** **R2** — pamäť platí pre čítačku, `budget` podá ten istý `nil` a fallback ostáva (zakázané ho obísť) · **T1** rozlišuje vyhodnotenia čítačky (1) od skutočných expanzií (dnešný počet) · **G2** sekvencie `nil → nil`, `nil → platná` · **M26** · S7 platí pre úvod a výpočty mimo tohto fallbacku |
| **A3** FIX-IN-H17a | `ctx.budget` mení poradie čítania v ponuke na `bom → hw_exp → smap`; G4 sleduje katalógy len počtom | **potvrdené čítaním** (`:3388-3391`: `Bom.compute` → `sheets_map` → expanzia → `budget_payload`) | **zapracované:** **R2** (poradie prvých čítaní je kontrakt exportu), **R3** ponuka `ctx.bom` → `ctx.smap` → `ctx.budget` · **G4** `sheets_map` v poradí · **M27** |
| **A4** FIX-IN-H17a (aj H17-0) | Vzor `with_now` z H7 vracia ten istý objekt; `Time.now.utc` v `Budget` ho prepne do UTC — VEPO LOG/CSV by niesli 21:03 | **potvrdené:** S26 (23:03 +0200 → 21:03 +0000; s `dup` bez zmeny) | **zapracované:** **R0.1** a **R9.3** — nový objekt pri každom volaní (`FIXED.dup`), pásmo pripnuté (`+02:00`) · **G4/G1** prípad „lokálny čas po rozpočte" · **T1** · R9 zapíše čas pred/po rozpočte · **M28** |
| **A5** FIX-IN-H17a | Nový export môže `start` zavolať a `nil` ignorovať; G2 je „× 4", nie nad `KINDS`; M15 skúša len chýbajúce volanie | **potvrdené čítaním** (R4 b je textová) | **zapracované:** **G2** iteruje `ExportPrep::KINDS` cez skutočný vstup, spoločné spúšťače úvodu povinne, picker 0 a zápisy 0 · **R4 b** inventár matice G2 == `KINDS` · **M29** |
| **A6** FIX-IN-H17a (H17-0) | T9 nepokrýva LOG časť M25 | **potvrdené čítaním** | **zapracované:** **R9.4** test — zmenený bajt mimo `Verzia`, odstránený `[ORANGE]`, iný počet RED/ORANGE (každý samostatne nezhoda) · **M25** spresnená |
| **A7** FIX-IN-H17a (H17-0) | R9.5 by každý rozdiel K ↔ baseline označil za posun vstupov; chyba nástroja aj H16/H18 dajú ten istý rozdiel; P4 kontroluje len H16 | **potvrdené čítaním** (§14b: pred K zmergujú H16 aj H18; H18 = závesy, zákazka má 17 ks Sensys v CSV) | **zapracované:** **R9.5** — **K0** (plugin `fe7f5405` = verzia baseline) a **K** (main pred H17a); každá odchýlka musí mať **doloženú príčinu** (posun vstupov dôkazom · chyba nástroja → oprava a nový beh · zmergovaná dávka s PR a riadkom), inak „nevysvetlená" a H17-0 nie je hotová; pripnutie commitov nástroja a pluginu, parametrov, SHA modelu, **manifestu celej snímky** a výstupov pre K0/K/P; `P == K` = parita refaktoru, `K0 == baseline` = reprodukcia zákazky · **R9.6** K' pri novej výstupnej dávke pred H17a · **P4** H16 + H18, celý rozsah zmien |
| **A8** NOTE | Baseline priečinok obsahuje aj vstupný model; doslovné porovnanie nesedí, všeobecný filter by skryl súbory navyše | **potvrdené** (`SHA_baseline.txt` = 9 artefaktov, v priečinku aj `TEST v0 17 24.skp`) | **zapracované:** **R9.4** — porovnávaný strom = 9 artefaktov manifestu, jediná výslovná výnimka `--exclude-input <meno>`, žiadne masky; SHA baseline sa overí proti manifestu · testy (model bez výnimky, iný `*.skp`, zlý manifest) · **M31** |
| **A9** NOTE | D13 je už rozhodnuté (H17-0 pred H17a), ale poradie commitov, R9.5 a D13 hovoria inak | **potvrdené** (§14b vs §2, R9.5, D13) | **zapracované:** **§2** tabuľka s H17-0, poradie bloku H16 → H18 → H17-0 → H17a → H17b, poradie commitov H17a bez nástroja · **R9** nadpis, R9.1, R9.5 · **§7** DoD H17-0 · **§8** · **D13** rozhodnuté · **§11** nižšie |

**Doplnenia §3, §5, §11 (§15 A9):** **Scope IN H17-0** = `scripts/export_porovnanie.ps1`, `scripts/export_porovnanie/run.rb` + `compare.rb` (+ šablóna `boot.rb` v skripte), `tests/pure/test_export_porovnanie.rb`
(T9, T9b), report K0/K. **Trieda H17-0:** kód pluginu sa nemení → bez bumpu verzie a `?v=`; nie audit-povinná (nie modul pluginu — audit tohto package ju pokrýva); **predrecenzia
odporúčaná** (bezpečnosť živého profilu, nový in-SU skript); `codex-po-pr` áno; uzáver = KRONIKA (+ STAV „Robí sa"/„Ďalší krok", ak to orchestrátor vyžaduje), PLAN riadok H17 rozdelený na
H17-0/H17a/H17b. **H17a** už nástroj ani K nenesie — R9 v H17a = len beh P nástrojom z mainu.

### 15.1 Čo sa zmenilo v koncepte (pre delta audit)

1. **Nový samostatný PR H17-0 pred H17a** (nástroj R9 + testy + kalibrácie **K0** a **K**); H17a = refaktor + golden + beh **P**. Poradie bloku H16 → H18 → H17-0 → H17a → H17b.
2. **R9 izoluje celý profil procesu SketchUpu** (`ENV['APPDATA']` prvým príkazom `boot.rb`, úplná kópia snímky vrátane značiek `*.done`, bez obnovy do konca procesu); `test_dir_override`
   sa v R9 nepoužíva; poradie `-RubyStartup` voči načítaniu pluginu sa za behu zaznamená (NEOVERENÉ), init nad živým profilom = bežný štart (S24); SHA živého profilu pred/po ako varovanie.
3. **Kalibrácia dvojstupňová:** K0 (presná verzia baseline) a K (main pred H17a); **odchýlka bez doloženej príčiny = nevysvetlená**, nie „posun vstupov"; pripnuté hodnoty pre K0/K/P;
   K' pri novej výstupnej dávke pred H17a.
4. **Porovnávaná množina = manifest baseline** (9 artefaktov) + jediná výslovná výnimka vstupného modelu; LOG negatívne testy.
5. **Kontext:** pamäť platí pre čítačku, **fallback expanzie v `budget_payload` ostáva** (počty skutočných expanzií = dnešné); **poradie prvých čítaní je kontrakt exportu** (ponuka
   `bom` → `smap` → `budget`); zamrazený čas = **nový objekt pri každom volaní**, pripnuté pásmo.
6. **Matica odmietnutí nad `ExportPrep::KINDS`** (rešpektovanie `nil` dokázané správaním pre každý registrovaný export).
7. Nové mutácie **M26–M31**, test **T9b**; S7 spresnené (S25), nové sondy S23–S26; P4 rozšírené o H18 a celý rozsah zmien, P7 o značky a manifest.
8. **Odhad:** **H17-0 ¾–1 deň** (nástroj ~450 riadkov, test ~150, behy K0 + K a ich vysvetlenie; +¼ dňa, ak treba vysvetľovať odchýlky) · **H17a 1–1¼ dňa** (refaktor ~+180/−120,
   testy ~850 vrátane sekvencií `nil`, poradia `sheets_map`, matice nad `KINDS`; beh P) · H17b ½ dňa bez zmeny. Rez H17a → H17b sa nemení.
9. **Na akcie orchestrátora pred H17-0:** doplniť do snímky `uni_seed.done` a `drawer_uni_seed.done` zo živého profilu (len čítanie) a zapísať manifest SHA-256 snímky (P7);
    pripraviť worktree `fe7f5405` pre K0 (`-PluginFrom`).

### 15.2 Čerstvá sonda pri prevzatí Codexom (3.10.2026)

Checkout `fe7f5405323eed86fedac8decaa733f2b792ad1d`; pôvodný package ani baseline sa nemenili. Všetkých 9 exportných artefaktov a 39 súborov snímky je zhodných s manifestmi; obe značky `*.done` už sú prítomné. Headless opakovanie `sonda_h17_audit.rb` cez `tests/helper.rb` s `TEMP`/`TMP` v `_dev/h17_takeover/tmp` a kópiou snímky v sandboxe: `boot_cutover! => :schema2` (iba `materials.lock`), obe UNI volania `:done`, `ApplianceCatalog.assess! => :ok`; obe sekvencie expanzie `nil -> nil` a `nil -> platná` = 2 expanzie; `Time.now` cez `.dup` zachová lokálny čas po `.utc`. Skutočný kód ponuky potvrdzuje `Bom.compute -> sheets_map -> hardware_expansion -> budget_payload`.

Podrobnosti a príkaz: `SONDA_H17_TAKEOVER.md`, surový výstup `sonda_h17_audit_rerun_out.txt`, manifesty `baseline_validation.json`. Sonda sa týka iba vybraných init volaní nad konkrétnou snímkou. Poradie `-RubyStartup` voči automatickému načítaniu pluginu ostáva **NEOVERENÉ** a predmetom delta auditu; SketchUp sa nespúšťal.

