# PACKAGE H16 · Súpis knižníc pred zdieľaním medzi PC (C-04, príprava D-48) — blok 9 HARDENING PO V1

> **Autorita:** triedenie Michala 1.10.2026 (`ROZHODNUTIA_MICHALA_2026-10-01.md`: C-04 = GR-03 · CX k D-48, **Teraz**); blok 9 (`SYSTEM/PLAN.md`, riadok H16
> „kód · audit"). Dôkazy: `CROSS_AUDIT_A2_GROK.md` **GR-03** (súpis riadok po riadku, „zdieľať / len tento počítač", šablóny obchádzajú spoločný priečinok,
> súpis nič nekopíruje), `CROSS_AUDIT_A1_CODEX_ASTRA.md` (D-48: štyri zámkové súbory, prílohy, „explicitný zoznam prenosných knižníc s prílohami").
> Návrh D-48, na ktorý H16 nadväzuje: `SYSTEM/zdroje/next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md` (§1 **záväzný zoznam store-ov**, §6 rez **SYNC-0
> „StoreRegistry"**) a rozhodnutia Michala `V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md` §0.
> **Trieda (§5):** **audit ÁNO** (nový modul `core/library_registry.rb` + kontrakt súpisu, ktorý D-48 prevezme) · **výrobná/cenová NIE** · **predrecenzia povinná** ·
> **in-SU nie je brána** (1 beh odporúčaný, §8) · fotky okien netreba · `codex-po-pr` bez výnimky.
> **Bez viditeľnej zmeny:** cesty, názvy a obsah súborov v `%APPDATA%\NOXUN\Engine`, zámky, zálohy, okná aj exporty ostávajú **bajtovo rovnaké** (golden T0 PRED zásahom).
> **Verzia:** patch podľa mainu pri štarte (dnes `0.17.18`) + všetky `?v=` + prepis STAV. **Stav kódu:** sonda nad `main` **`5e0ffb90`** (v0.17.18, po PR #454).

---

## 0 · Sonda na kóde (headless, 2.10.2026)

Skripty v `scratchpad/HARDENING/`: `sonda_h16.rb` (cesty modulov, override, prvý beh, sken koreňa a literálov → `sonda_h16_out.txt`), `sonda_h16_scan.rb`
(literály, konštanty priečinkov, zapisovatelia → `sonda_h16_scan_out.txt`) a **prototyp** nad kópiou repa `proto_h16/ENGINE` (`git archive main`): register,
`tests/pure/test_h16_kniznice.rb`, R2; behy `proto_h16/suite_base.txt`, `proto_h16/suite_proto*.txt`, `sonda_h16_proto_out.txt`. Prototyp je pomôcka, autorita je package.
Do repa, modelu ani živého `%APPDATA%` sa nič nezapisovalo (sandbox `tests/helper.rb`).

| # | Tvrdenie o dnešnom kóde | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | V koreni `%APPDATA%\NOXUN\Engine` je **30 položiek súpisu** (§0.1) + **6 zámkových súborov** + `.bak` každého súboru zapisovaného cez `JsonFileStore.write` + dočasné mená; mimo koreňa **8 skupín** (§0.2). **Hranica súpisu (§15 A9):** súpis = čo zapisuje **plugin**; cudzí súbor v koreni (nástroj agentov `agent_register_videne.txt`) je skupina `dev_tools` a D-48 ho ignoruje. Iné perzistentné miesto plugin nemá: log ide do Ruby konzoly (`main.rb:18-31`), `write_default` sa nepoužíva, veľkosť okien si pamätá SketchUp (`preferences_key`) | sonda S1–S5, Grep `APPDATA`, `File.*write`, `flock`, `write_default`, `localStorage` | PRAVDA |
| S2 | **Šablóny a štatistika si koreň počítajú samy:** `TemplateStore.dir` (`templates.rb:81-84`) a `UsageStats.dir` (`usage_stats.rb:33-36`) berú `ENV['APPDATA']` priamo; od nich závisí `TemplateUsage` (`:952`), `TemplatePreviews` (`template_previews.rb:54-60`) a tri zámky. **7 ciest z 33 nenasleduje `Materials.test_dir_override`**; všetky ostatné moduly delegujú na `Materials.dir` (vzor R-08) | sonda S2/S4 | PRAVDA → GR-03 „šablóny si priečinok určujú inak" |
| S3 | V produkcii je výsledok rovnaký: `Materials.dir` bez override = `ENV['APPDATA'] \|\| Dir.tmpdir` + `NOXUN/Engine` (`materials.rb:233-238`) a override nastavujú **len testy** (Grep `test_dir_override =` v `noxun_engine/` a `scripts/` = len definícia setterov) | Grep | PRAVDA |
| S4 | Daň: in-SU **KOV-I** prepisuje `TemplateStore.dir` ručne (`su_runner.rb:27317-27322`, `:27477`); **KOV-B1** nastaví override, tvrdí „sandbox aktívny", no šablónu píše do koreňa podľa `ENV` (`:21367-21372`, `:21494-21523`) — runner `ENV` presmeruje na sandbox behu (`run_su_tests.ps1:156-178`), živé dáta nie sú v hre | čítanie | PRAVDA |
| S5 | **Prototyp R2** (2 metódy delegujú na `Materials.dir` vzorom `AbsRules.dir`): headless sada **5179 / 0 / 1 skip = main**; všetkých **33 ciest** nasleduje override | `suite_base.txt`, `suite_proto.txt`, `sonda_h16_proto_out.txt` | PRAVDA → R2 |
| S6 | **Prvý beh v sandboxe** (20 krokov: všetky knižnice, značky UNI, prepínače, rady, aktualizácie, štatistika, legacy marker) vyrobí **25 súborov** (z toho 6 zámkov); druhý zápis rád a aktualizácií pridá 2× `.bak` = **27**. Dva behy s novým `ENV` koreňom a resetom pamäte dajú tú istú množinu; bajty sa líšia len pri `appliances.json` (pečiatky seedu) a `legacy_cleanup.json` (cesta Plugins + čas); časovo závislé sú aj `*.done` (`done_at`) a `usage_stats.json` (dátum). **Pozor:** `HardwareCatalog` a `ApplianceCatalog` si pamätajú stav — druhý beh v tom istom procese bez `reset_state!` ich súbory nevyrobí | `sonda_h16_out.txt` S3, sonda determinizmu | PRAVDA → bežec v samostatnom procese (§15 A5) |
| S7 | **Zámky** (stĺpec Zámok §0.1, **opravené §15 A3**): spoločný `materials.lock` chráni **16 položiek** — 11 berie zámok sám, pri značkách UNI, predmigračnej a forenzných zálohách ho **drží volajúci** (`materials_catalog.rb:1078-1093`, `:1151-1173`, `materials_migration.rb:166-176`, `materials_health.rb:237-273`, `:446-476`), `migration_hold.json` je **zmiešaný** (zápis pod zámkom volajúceho, mazanie bez neho `:422-424`); **5 vlastných** zámkov (náhľady drží `TemplateStore`); `demos_throttle.lock` zamyká sám seba; **bez zámku** len téma, 3 prepínače a cache Demosu. Sonda `sonda_h16_locks.rb`: zámok držaný v okamihu zápisu sedí pri všetkých 19 súboroch prvého behu. Návrat `flock` kontrolujú len `Materials` (`materials.rb:519`) a `ApplianceCatalog` (`:235`); `TemplateStore.with_lock` výnimku prehltne a vráti `false` (`templates.rb:631-649`) | čítanie | PRAVDA → §14 F3/F4 |
| S8 | **Verzie:** 26 konštánt tabuľky STANDARD §13.1 „Súbory na počítači" (`STANDARD.md:1789-1818`) patrí **1:1** 18 položkám súpisu; bez verzie sú `vepo_settings.json` (H7 N3), cache Demosu, prílohy, značky a zálohy | porovnanie | PRAVDA → T7 |
| S9 | **Prílohy:** `appearances/<uuid>.skm` (nemenné, odkaz `appearance.id` v `materials.json`, `materials_appearance.rb:109-112`); `template_previews/<druh>-<slug>-<sha16>.png` (meno z druhu a mena → **rovnaké na oboch PC**); `appliances/<uuid>/<uuid>_<slug>.<ext>` (v zázname **relatívne** meno, V1 debata §0) | čítanie | PRAVDA |
| S10 | **Údaje viazané na tento PC:** `vepo_settings.json` mieša `project_names` (kľúč = normalizovaná **cesta .skp** alebo `guid:` sedenia), `last_dir` (cesta) a `merge_18_36` (mení zoskupenie súborov VEPO, `vepo_export.rb:253`); `updater_settings.json` = cesta k distribúcii; `legacy_cleanup.json` = kľúč cesta `Plugins` | `production_core.rb:21-133`, `:344` | PRAVDA → Q2, §14 F1 |
| S11 | **Obrázky dekorov** (`textures/`) sa sťahujú **len pri založení skupiny** z Demosu (`demos/family.rb:459`); okno Materiály číta len lokálny súbor (`materials_dialog.rb:322`) → na druhom PC po zdieľaní katalógu dlaždice bez fotky (farba) | čítanie | PRAVDA → §14 F2 |
| S12 | **Mimo koreňa** 8 skupín §0.2 (s `dev_tools` — §15 A9); `localStorage` má **10 kľúčov/prefixov** v 7 JS súboroch: `nxsec_*`, `nx_bom_cols`, `nx_bom_groups`, `nx_studio_nav`, `nx_budget_vat`, `nx_hw_shelfpins_open`, `nx_np_closed`, `nx_recent_decor`, `nx_recent_abs`, `noxun.tpl.with_hardware` | Grep, sonda S5 | PRAVDA |
| S13 | Statický sken: **31 Ruby súborov** so zápisovým primitívom; všetky literály mien úložísk sa dajú zaradiť (§0.1–0.2) bez šumu — vzory v §6 R6 | `sonda_h16_scan_out.txt` | PRAVDA |
| S14 | **Prototyp registra + 6 guardov** (`proto_h16`): zelené; nad **dnešnými** `templates.rb`/`usage_stats.rb` padnú presne 2 testy (parita ciest: šablóny, náhľady, použitie, štatistika a ich zámky; „jediný koreň": 2 metódy) = negatívny dôkaz; celá sada s registrom **5183 / 2** — padajú len docs guardy (chýba odsek `### library_registry.rb` a riadok routra) | `suite_proto2.txt` | PRAVDA → T2–T6 sú uskutočniteľné |
| S15 | **Záväzný zoznam SYNC §1 vs kód:** §1 menuje `hardware_sets*.json` (existuje jeden súbor), „nastavenia rozpočtu (`budget_store.rb`)" (rozpočet zákazky žije v modeli, globálne sadzby sú `supplier_settings.json`); **vynecháva** `vepo_settings.json`, `template_usage.json`, tému, prepínače, cache, značky a zálohy; `dim_series` je v §1 **per PC**, hoci Michal 6.9. menoval „aj rozmerové rady" | `SYNC_KNIZNICE_NAVRH_2026-09-06.md:15-36`, `V1_DEBATA…:14` | PRAVDA → D4, Q1 |
| S16 | `scripts/ui_foto.ps1:196-198` drží **vlastný implicitný zoznam** „čo z koreňa kopírovať do nahrávky" (bez `*.lock`, `*.bak`, `updater_settings*`, `ui_theme*`, `usage_stats*`) — tretí neoficiálny súpis | čítanie | PRAVDA → §14 F8 |

### 0.1 Súpis — koreň `%APPDATA%\NOXUN\Engine` (hodnoty = dnešný kód; `Zdieľa` = návrh pre D-48)

Druh: **K** knižnica (používateľ ju upravuje) · **P** prílohy knižnice · **N** nastavenie tohto PC · **C** cache · **Z** technická značka · **B** technická záloha.

| # | Súbor | Druh | Zdieľa | Kto ho počíta / zapisuje | Zámok | Verzia (§13) | `.bak` | Poznámka |
|---|---|---|---|---|---|---|---|---|
| 1 | `materials.json` | K | **áno** | `Materials.path` · `materials.rb`, `materials_catalog.rb`, `materials_health.rb` | `materials.lock` | `STD`, `SCHEMA_CURRENT` | áno | prílohy #2 |
| 2 | `appearances/` | P | **áno** | `Materials.appearance_file` · `materials_appearance.rb`, `materials_native_appearance.rb` | `materials.lock` | — (descriptor `version: 1` v #1) | — | `<uuid>.skm`; dočasné `*.skm.staging` |
| 3 | `abs_rules.json` | K | **áno** | `AbsRules.path` · `abs_rules.rb` | `materials.lock` | `STD`, `SEED_VERSION` | áno | |
| 4 | `hardware_rules.json` | K | **áno** | `HardwareRules.path` · `hardware_rules.rb` | `materials.lock` | `STD`, `SEED_VERSION` | áno | |
| 5 | `hardware_catalog.json` | K | **áno** | `HardwareCatalog.path` · `hardware_catalog.rb` | **`hardware_catalog.lock`** | `SCHEMA_CURRENT`, `SEED_SET_VERSION` | áno | vlastný zámok |
| 6 | `hardware_taxonomy.json` | K | **áno** | `HardwareTaxonomy.path` · `hardware_taxonomy.rb` | `materials.lock` | `SCHEMA_CURRENT`, `SEED_VERSION` | áno | |
| 7 | `hardware_sets.json` | K | **áno** | `HardwareSets.path` · `hardware_sets.rb` | `materials.lock` | `STD`, `SEED_VERSION` | áno | |
| 8 | `templates.json` | K | **áno** | `TemplateStore.path` · `templates.rb` | **`templates.json.lock`** | `STD` | áno | prílohy #9 |
| 9 | `template_previews/` | P | **áno** | `TemplatePreviews.dir` · `template_previews.rb` | `templates.json.lock` (drží volajúci) | — | — | `<druh>-<slug>-<sha16>.png`; dočasné `*.png.new` (`:272`), `tmp/capture-*.png` |
| 10 | `supplier_settings.json` | K | **áno** | `SupplierSettings.path` · `supplier_settings.rb` | `materials.lock` | `STD`, `SEED_VERSION` | áno | aj Nastavenia rozpočtu |
| 11 | `appliances.json` | K | **áno** | `ApplianceCatalog.path` · `appliance_catalog.rb` | **`appliances.json.lock`** | `STD`, `SEED_VERSION` | áno | prílohy #12 |
| 12 | `appliances/` | P | **áno** | `ApplianceCatalog.attachments_root` · `appliance_catalog.rb` | `appliances.json.lock` | — | — | `<uuid>/<uuid>_<slug>.<ext>`; dočasné `<uuid>/<uuid>.tmp` |
| 13 | `dim_series.json` | N | nie (Q1) | `DimSeries.path` · `dim_series.rb` | `materials.lock` | `STD` | áno | SYNC §1: per PC |
| 14 | `vepo_settings.json` | N | nie (Q2) | `ProductionCore.vepo_settings_path` (po H7 `ExportSettings.path`) · `ui/production_core.rb` (po H7 `core/export_settings.rb`) | `materials.lock` | — | áno | **zmiešaný** (S10); ovplyvňuje VEPO |
| 15 | `template_usage.json` | N | nie | `TemplateUsage.path` · `templates.rb` | `template_usage.json.lock` | `TemplateUsage::STD` | áno | „naposledy použité" tohto PC |
| 16 | `ui_theme.json` | N | nie | `Engine.ui_theme_path` · `main.rb` | — | `UI_THEME_STD` | áno | téma Michal/Lucia |
| 17 | `edge_check.json` | N | nie | `EdgeCheck.settings_path` · `edge_check.rb` | — | `SETTINGS_STD` | áno | |
| 18 | `grain_check.json` | N | nie | `GrainCheck.settings_path` · `grain_check.rb` | — | `SETTINGS_STD` | áno | |
| 19 | `direction_check.json` | N | nie | `DirectionCheck.settings_path` · `direction_check.rb` | — | `SETTINGS_STD` | áno | |
| 20 | `updater_settings.json` | N | nie | `Updater.path` · `updater.rb` | `materials.lock` | `STD` | áno | cesta k distribúcii |
| 21 | `usage_stats.json` | N | nie | `UsageStats.path` · `usage_stats.rb` | `usage_stats.json.lock` | `SCHEMA` | áno | merač panela |
| 22 | `demos_sitemap.json` | C | nie | `DemosSitemapCache.path` · `demos/sitemap_cache.rb` | — | — | áno | dá sa stiahnuť znova |
| 23 | `textures/` | C | nie (§14 F2) | `DemosImageCache.dir` · `demos/image_cache.rb` | — | — | — | `<sha10>_<meno>`; dočasné `*.tmp<pid>` (`image_cache.rb:83`) |
| 24 | `legacy_cleanup.json` | Z | nie | `Tools::LegacyCleanup.path` · `tools/legacy_cleanup.rb` | `materials.lock` | `STD` | áno | kľúč = cesta Plugins |
| 25 | `migration_hold.json` | Z | nie | `Materials.migration_hold_path` · `materials_health.rb` | `materials.lock` (zmiešaný: mazanie bez zámku) | — | — | jednorazová |
| 26 | `uni_seed.done` | Z | nie | `Materials.uni_marker_path` · `materials_catalog.rb` | `materials.lock` (drží volajúci) | — | áno | §14 F5 |
| 27 | `drawer_uni_seed.done` | Z | nie | `Materials.drawer_uni_marker_path` · `materials_catalog.rb` | `materials.lock` (drží volajúci) | — | áno | §14 F5 |
| 28 | `demos_throttle.lock` | Z | nie | `Demos.throttle_path` · `demos/client.rb` | (sám flock) | — | — | čas posledného dopytu |
| 29 | `materials.pre-schema-2.json` | B | nie | `Materials.pre_schema2_backup_path` · `materials.rb` | `materials.lock` (drží volajúci) | — | — | predmigračná záloha |
| 30 | `materials.{corrupted,rolledback,json.bak.pre-rollback}-*.json` | B | nie | `materials_health.rb` (`timestamped_free_path`) | `materials.lock` (drží volajúci) | — | — | forenzné kópie |

**Spolu:** 12 zdieľaných (9 knižníc + 3 priečinky príloh) · 18 len pre tento PC (9 nastavení, 2 cache, 5 značiek, 2 zálohy). Zámkové súbory: `materials.lock`,
`hardware_catalog.lock`, `templates.json.lock`, `template_usage.json.lock`, `appliances.json.lock`, `usage_stats.json.lock`. Dočasné: `*.tmp-<pid>-<tid>`
(`JsonFileStore`), `*.tmp-<pid>` (#29), `*.skm.staging` (#2), `*.png.new` a `tmp/` (#9), `<uuid>.tmp` (#12), `*.tmp<pid>` (#23) — **§15 A2**.

### 0.2 Mimo koreňa (D-48 sa ich netýka — do súpisu kvôli úplnosti)

| Skupina | Kde | Kto | Prečo nie D-48 |
|---|---|---|---|
| `plugin_install` | `Plugins\` (`noxun_engine.update.json`, `.update.lock`, `noxun_engine.leases\`, `.new`/`.old`) | `core/updater.rb`, `noxun_engine.rb`, `tools/legacy_cleanup.rb` | inštalácia — rieši Updater D-52 |
| `plugin_data` | `noxun_engine\data\recipes\` (`RELEASED.json`, `*_v1.json`) | `core/drawer_recipes.rb` (len číta) | príde s aktualizáciou pluginu |
| `exports` | priečinok/súbor, ktorý vybral používateľ (VEPO, CSV, XLSX) | `core/vepo_export.rb`, `core/xlsx_writer.rb`, `ui/production_core.rb` | výstup zákazky, nie knižnica |
| `temp` | `Dir.mktmpdir`, `Sketchup.temp_dir` (`preview.png`, `working.skm.staging`, miniatúra prílohy) | `ui/materials_appearance_dialog.rb`, `ui/appliance_dialog.rb` | po použití zaniká |
| `ui_memory` | `localStorage` okien (CEF profil SketchUpu) — 10 kľúčov S12 | `boot.js`, `budget.js`, `form.js`, `hardware.js`, `nx_combo.js`, `sheet_layout.js`, `studio.js` (+ `shell.js` skladá `nxsec_*`) | pamäť okna tohto PC (zbalenia, stĺpce, posledné dekory) |
| `dialog_prefs` | SketchUp `preferences_key` (Inspector, Štúdio, Mower) | SketchUp | veľkosť a poloha okien |
| `model` | `.skp`, slovník `NOXUN` na modeli (snapshoty pravidiel a setov kovania, rozpočet, projektové materiály) | buildery, `budget_store.rb`, `materials_project.rb`, `hardware_rules.rb`, `hardware_sets.rb` | cestuje so zákazkou |
| `dev_tools` | **v koreni** `agent_register_videne.txt` (§15 A9) | `scripts/start_okna.ps1:24`, `:198` (nástroj agentov, nie plugin) | nie je súčasť pluginu; D-48 súbory mimo registra ignoruje |

---

## 1 · Cieľ

Na jednom mieste — v kóde aj v dokumentácii — je **súpis všetkého, čo plugin ukladá mimo zákazky**: súbor, druh, či sa pri D-48 zdieľa alebo je len pre tento
počítač, zámok, verzia, prílohy a kto ho zapisuje. Všetko leží v **jednom koreni** (aj šablóny). Nový súbor knižnice alebo nové miesto zápisu bez riadku súpisu
**zhodí test**, takže D-48 postaví Odoslať / Aktualizovať na hotovom zozname a nič sa nezabudne preniesť. **Pre používateľa sa nemení nič.**

## 2 · Rez a odhad — **jedna dávka**

| Obsah | Kód pluginu (+/−) | Testy | In-SU | Odhad |
|---|---|---|---|---|
| T0 golden (1. commit) → `core/library_registry.rb` → `main.rb` + `tests/helper.rb` → R2 (2 metódy) → guardy T1–T11 → `docs/architecture/kniznice.md` + router + §13 + mapa + D-48 | ~+200 / −2 (register ~180, R2 +6, require 2) | ~+600 + bežec `tests/h16_first_use.rb` ~90 + fixtúra ~3 kB (§15) | odporúčaný 1 beh | ¾–1 deň |

Rez netreba: kód je dáta + 2 riadky správania, ktoré je produkčne totožné (S3, S5); spolu < 300 riadkov kódu pluginu. **Poradie commitov:** (1) T0 + bežec prvého behu na starom
kóde · (2) register + `main.rb`/helper + T1, T2b, T4–T7, T9–T11 (zelené ešte so starým koreňom) + `kniznice.md` s odsekom `### library_registry.rb` a riadky routra
(inak padnú docs guardy — S14) · (3) R2 + T2, T3 (pred R2 padajú — S14) · (4) tabuľky `kniznice.md` + T8, §13, mapa, D-48 · (5) uzáver.

## 3 · Scope IN

1. **Register** `noxun_engine/core/library_registry.rb` (R1) — riadky §0.1, mimo koreňa §0.2, zámky, primitívum.
2. **Jediný koreň** (R2): `TemplateStore.dir` a `UsageStats.dir` delegujú na `Materials.dir` (vzor R-08).
3. **Guardy** T1–T11 (§7) — statické + **bežec prvého behu v samostatnom procese** `tests/h16_first_use.rb` (golden T0, cesty, zámky — §15 A5).
4. **Dokumentácia** (R3–R5): nový súbor mapy `docs/architecture/kniznice.md`, router, STANDARD §13 veta, scenár v mape rozširovacích bodov, stav D-48.

## 4 · Scope OUT

- **Žiadne kopírovanie, synchronizácia, inventár na disku ani UI** — to je D-48 (SYNC-1..3).
- **`JsonFileStore` neodmieta neregistrovaný súbor** a register nemá háčiky (`assess_import`, dopredná brána) — vynútenie je SYNC-0/1 pri D-48 (mení správanie).
- Zmena **ciest, mien, formátov, zámkov, záloh** a klasifikácie mimo §0.1; rozdelenie `vepo_settings.json` (Q2, D-48); oprava zámkov bez kontroly `flock` (§14 F3).
- `su_runner.rb` (monkeypatch KOV-I ostáva — po R2 je zbytočný, nie škodlivý; §14 F7), `scripts/ui_foto.ps1` (§14 F8), H9 N5 (`TemplateStore` lokálna kópia „zlý tvar").
- Seed súbory H15 (`*_seed.rb`) — sú to dáta v kóde pluginu, nie úložiská.

## 5 · Trieda podľa CLAUDE.md

- **Výrobná/cenová: NIE.** Nemení sa vzorec, rozmer, počet, hrana, kusovník, VEPO, nákup, kovanie ani cena; súbory knižníc ostávajú bajtovo rovnaké (T0).
- **Audit-povinná: ÁNO** — nový modul (nový riadok routra) a jeho kontrakt (kľúče riadka, klasifikácia, nadväznosť na SYNC-0). Schéma ani STD sa nemení.
- **Predrecenzia: povinná** (audit-povinná trieda).
- **In-SU: nie je brána** — žiadny builder, observer, undo, geometria ani akcia panela zapisujúca do modelu. **Odporúčaný 1 beh** `run_su_tests.ps1 -CloseWhenDone`:
  R2 mení, kam zapisujú scenáre KOV-B1 a KOV-I pri `test_dir_override` (S4); bez behu to PR prizná.
- **Nový ovládací prvok: NIE.** **Fotky okien: netreba** (žiadny JS/CSS/HTML).

### 5.1 Závislosti — overiť proti mainu pri štarte (implementátor ide po H7 a H15)

- **H7a:** `vepo_settings.json` → `ExportSettings.path`, zapisovateľ `core/export_settings.rb`; `ui/production_core.rb` ostane zapisovateľom CSV (`exports`).
  Riadok #14 podľa mainu pri štarte (T2/T5 nepustia zastaraný stav); ak H7 pridá `std`, doplní sa `versions`.
- **H15a/b:** `core/hardware_*_seed.rb` bez zápisu a mien súborov — T4/T5 ich nesmú hlásiť (overiť). Mapa dostane od H15b scenár 6 → H16 berie **ďalší voľný**
  a doplní `NX_H13_SCENARIOS`; ak strop `rozsirovacie-body.md` (20 kB) nestačí, zvýš ho ~1,3× s komentárom (vzor H13).
- **H11a** (spôsob načítania v `main.rb`) — `require` registra rovnakým vzorom ako susedia. **H17** (po H16) — nový zapisovateľ či súbor = riadok súpisu.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit, bez zmeny pluginu)

- **R0.1 (§15 A5) Bežec v samostatnom procese** `tests/h16_first_use.rb` (nie `test_*` — `run_all` ho nenačíta): `require_relative 'helper'` dá **čerstvý sandbox
  `APPDATA` a čistú pamäť modulov** (žiadny reset, žiadne prepínanie `ENV`, cudzie `test_dir_override` z iných sád — napr. `ApplianceCatalog` zo `test_s1a1` — doň
  nedosiahnu). Spúšťa ho test cez `IO.popen([RbConfig.ruby, bežec])` (vzor `test_d52a_updater.rb:308`), **dvakrát** (opakovateľnosť); výstup JSON na stdout.
  Bežec: **prvý beh** (S6; `UsageStats.record({…})` so **zátvorkami** — pasca Ruby 3) → druhý zápis rád a aktualizácií; počas behu špeh `File#flock` +
  `JsonFileStore.write` zapíše **zámok držaný v okamihu zápisu** (vzor `sonda_h16_locks.rb`). Generátor fixtúry `tests/fixtures/h16_golden/generate.rb` volá ten istý bežec. Fixtúra = **zoradený zoznam súborov** + **SHA-256** deterministických (knižnice #1, #3–#8,
  #10, rady a aktualizácie aj s `.bak`, 3 prepínače, `template_usage.json`); ostatné (S6) len existencia; plus mapa **súbor → držaný zámok** (T2b). Po zavedení registra bežec vráti aj cesty resolverov bez override (T11) a s override (T2).
- **R0.2** Test `tests/pure/test_h16_kniznice.rb` s T0 zelený na starom kóde v 1. commite; fixtúra sa v dávke **neregeneruje** (zmena = nález → STOP).
- **R0.3** Platí len headless (`NxTest.skip! … unless NxTest.headless?` — v SketchUpe `RbConfig.ruby` nie je samostatný interpreter, vzor `test_d52a_updater.rb:77`).

### R1 · Register `Noxun::Engine::LibraryRegistry` (`core/library_registry.rb`)

- **R1.1 Čisté dáta**, UTF-8 bez BOM, bez IO, bez SketchUp API, bez čítania súborov pri načítaní; všetko **hlboko zmrazené**. `main.rb`: `Sketchup.require
  'noxun_engine/core/library_registry'` hneď za `core/materials` (koreň sa pýta až pri volaní); `tests/helper.rb` zoznam rovnako.
- **R1.2 Riadok `ENTRIES`** (Hash so **String** kľúčmi, poradie = §0.1): `key` (jedinečný, `snake_case`) · `file` (relatívne ku koreňu; priečinok končí `/`;
  forenzné #30 ako glob `File.fnmatch` s `FNM_EXTGLOB`) · `kind` ∈ `KINDS = %w[library attachments setting cache marker backup]` · `sync` ∈ `%w[shared local]` ·
  `resolver` (`'Modul.metóda'` vracajúca absolútnu cestu, alebo `nil` pre #2 a #30) · `lock` (meno z `LOCKS` alebo `nil`) · **`lock_mode`** ∈ `%w[module caller mixed self none]` (**§15 A3**: modul berie zámok sám · drží ho volajúci · zmiešaný · súbor zamyká sám seba · bez zámku; `lock` povinný práve pri `module`/`caller`/`mixed`) · `versions` (mená **v zápise §13.1**,
  napr. `'LegacyCleanup::STD'`, `'Engine::UI_THEME_STD'`) · `bak` (true = zapisuje sa cez `JsonFileStore.write`) · `of` (prílohy → kľúč knižnice) ·
  `attachments` (knižnica → kľúče príloh; obojsmerne) · **`children`** (priečinky: vzory **finálnych** súborov — §0.1 Poznámka) · `transient` (vzory dočasných mien vrátane `*.png.new`, `*.tmp<pid>` — **§15 A2**) · `writers` (**cesty od koreňa repa**, napr.
  `noxun_engine/core/materials.rb`, `noxun_engine.rb`) · `outputs` (true = obsah mení kusovník, VEPO, kovanie alebo ceny) · `note` (krátka SK veta).
- **R1.3** `LOCKS = { 'materials.lock' => 'Materials.catalog_lock_path', 'hardware_catalog.lock' => 'HardwareCatalog.lock_path', 'templates.json.lock' =>
  'TemplateStore.lock_path', 'template_usage.json.lock' => 'TemplateUsage.lock_path', 'appliances.json.lock' => 'ApplianceCatalog.lock_path',
  'usage_stats.json.lock' => 'UsageStats.lock_path' }` · `OUTSIDE` = 8 skupín §0.2 (aj `dev_tools`, §15 A9) (`key`, `where`, `names` — literály a kľúče `localStorage`, `writers`,
  `reason`); `writers` tu znamená **súbory so zápisovým primitívom na disk** (Ruby) a pri `ui_memory` JS súbory s `localStorage` — `plugin_data`, `dialog_prefs`
  a `model` majú `writers: []` (čítanie, SketchUp, `set_attribute` nie sú zápis súboru) · `PRIMITIVES = %w[noxun_engine/core/json_file_store.rb]`.
- **R1.4 API:** `root` (= `Materials.dir` pri volaní) · `entries` · `keys` · `get(key)` (String/Symbol; neznámy → `nil`) · `shared` (riadky `sync == 'shared'`) ·
  `path(key)` (`File.join(root, file)` bez lomky na konci; glob → `nil`). Nič iné — žiadne čítanie disku.
- **R1.5 Komentár modulu** povie: súpis je **autorita klasifikácie** pre D-48 (SYNC-0 ho rozšíri o vynútenie a háčiky); zmena `sync` = rozhodnutie Michala;
  nové úložisko = riadok + scenár mapy (R5).

### R2 · Jediný koreň

- **R2.1** `TemplateStore.dir` (`templates.rb:81-84`) a `UsageStats.dir` (`usage_stats.rb:33-36`): prvý riadok `return Materials.dir if defined?(Materials) &&
  Materials.respond_to?(:dir)`, `ENV` fallback ostáva (presne `AbsRules.dir`, `abs_rules.rb:205-210`). Komentáre: hlavička `templates.rb:2` bez zmeny, hlavička
  `usage_stats.rb:6-8` (sandbox „cez ENV") → „koreň = `Materials.dir` (R-08), testy cez `ENV` sandbox aj `test_dir_override`".
- **R2.2** Iné metódy sa nemenia; `TemplateUsage`, `TemplatePreviews` a zámky nasledujú automaticky (S5).

### R3 · Dokumentácia súpisu — nový súbor mapy `docs/architecture/kniznice.md`

- Úvod (čo, ako čítať, údržba — vzor `rozsirovacie-body.md`) · `## 1 · Pravidlá` (jediný koreň; čo znamená „zdieľa"; per PC len cesty, značky a osobné
  nastavenia; `.bak`/`.lock`/dočasné sa nikdy nekopírujú) · `### library_registry.rb` (kľúče riadka, API, guardy, **ako pridať úložisko**) · `## 2 · Knižnice —
  zdieľajú sa pri D-48` · `## 3 · Tento počítač` · `## 4 · Mimo koreňa` · `## 5 · Čo zdieľanie narazí (podklad D-48)` = §14 F1–F5 ako fakty.
- Tabuľky §2–§3: **prvá bunka `` `súbor` ``**, stĺpce Druh · Zdieľa (áno/nie) · Zámok · Verzia · Čo to je; §4 prvá bunka `` `kľúč` ``. **Bez čísel riadkov a PR.**
  Strop `NX_ARCH_MAX_BYTES['kniznice.md'] = 20 * 1024`, `NX_ARCH_FILES` + riadok „Kde čo nájdeš" v routri.
- Router `docs/ARCHITEKTURA.md`: riadok Core `library_registry` → `kniznice.md`; v odseku `### json_file_store.rb` (`model-a-identita.md:240`) zoznam „materiály,
  šablóny, …" nahradiť odkazom na súpis (zoznam by zastaral).

### R4 · STANDARD §13

- Pod nadpis tabuľky „Súbory na počítači" jedna veta: „Ktoré súbory sa zdieľajú medzi PC, ich zámky a prílohy: súpis `docs/architecture/kniznice.md`
  (autorita `LibraryRegistry`)." Hodnoty tabuľky sa nemenia.

### R5 · Mapa rozširovacích bodov — scenár „Nové úložisko na počítači"

- Krátky scenár (≤ 1,2 kB): (1) riadok `LibraryRegistry::ENTRIES` so `sync` (rozhodnutie Michala), zámkom, verziou, zapisovateľmi; (2) cesta cez `Materials.dir`;
  (3) verzia do STANDARD §13.1; (4) riadok v `kniznice.md`; (5) **krok v bežci prvého behu**, ak súbor vzniká bez UI, a počet v `NX_H16_WRITE_SITES` (§15 A1).
  **(§15 A6) H13 guard chce ≥ 4 strážené riadky na scenár** (`test_h13_rozsirovacie_body.rb:183-185`) — tabuľka: `noxun_engine/core/library_registry.rb` |
  `LibraryRegistry::ENTRIES` · `LibraryRegistry::LOCKS` · `LibraryRegistry::OUTSIDE` · `noxun_engine/core/materials.rb` | `Materials.dir` · `Materials.with_catalog_lock` ·
  `noxun_engine/core/json_file_store.rb` | `JsonFileStore.write` · `JsonFileStore.degraded?` · `tests/pure/test_h16_kniznice.rb` | `NX_H16_WRITE_SITES` ·
  `tests/h16_first_use.rb` | `UsageStats.record` (6 riadkov, každý je naozajstný krok). Doplniť `NX_H13_SCENARIOS` a `NX_H13_REQUIRED` (`LibraryRegistry::ENTRIES`, `Materials.dir`).

### R6 · Guardy (vzory overené prototypom S14)

- **R6.1 Literály** (`noxun_engine.rb` + `noxun_engine/**/*.rb`, mimo komentárov): reťazec `/\A[\w.\-]+\.(?:json|lock|done|skm|png|jpe?g|lease|bak|tmp|staging)\z/`;
  hodnota konštanty `DIR_NAME`/`ATTACH_ROOT`/`TMP_NAME`/`LEASES_DIR`; literál v `File.join(dir|Materials.dir|TemplateStore.dir, '…'`; prefix `timestamped_free_path('…')`.
  Každý musí byť `file`/`lock`/`transient`/glob riadku alebo `names` skupiny `OUTSIDE`.
- **R6.2 Zapisovatelia:** súbor so zápisovým primitívom (`JsonFileStore.write(`, `File.binwrite|write|rename|delete(`, `File.open(` s `'w'`/`'a'`/`File::CREAT`,
  `FileUtils.mkdir_p|cp|mv|rm_f|rm_rf|copy`, `deploy_bytes(`, `.save_as(`, `write_image(`, `write_thumbnail(`) ∈ `writers` riadkov ∪ `OUTSIDE` ∪ `PRIMITIVES` —
  a **naopak** (zapisovateľ v súpise, ktorý už nezapisuje = zastaraný riadok).
- **R6.2b Zápisové miesta (§15 A1):** v teste `NX_H16_WRITE_SITES = { 'noxun_engine/core/dim_series.rb' => [1, 'dim_series.json'], … }` — pre **každý** Ruby súbor so
  zápisom **počet riadkov so zápisovým primitívom** (vzor R6.2, mimo komentárov) a **dôvod** (čo tie zápisy píšu, alebo výnimka: export, temp, inštalácia).
  Iný počet = test padne: „<súbor>: N zápisových miest, súpis pozná M — nové miesto zaraď (riadok `LibraryRegistry`/`OUTSIDE` alebo výnimka s dôvodom) a uprav
  počet". Zachytí **nové dynamické úložisko v už známom súbore** aj zápis cez pomocníka (počíta sa v súbore volania `JsonFileStore.write(`/`deploy_bytes(`).
  Nie je to parser: refaktor, ktorý počet zachová, test nehýbe; počty z mainu pri štarte (dnes 31 súborov, `sonda_h16_scan_out.txt` (2)).
- **R6.3 Jediný koreň:** metóda `*dir` s `ENV['APPDATA']` v tele musí obsahovať `Materials.dir`; výnimka **len** `Materials.dir`.
- **R6.4 JS pamäť:** literálové kľúče v `ui/js/*.js` pri `localStorage.(get|set|remove)Item(`, `lsGet(`/`lsSet(`, `*_KEY = '…'`, `RECENT_KEYS` a prefix `secKey`
  ⊂ `OUTSIDE['ui_memory'].names`; JS súbor, ktorý volá `localStorage`, je v jej `writers`. **(§15 A1)** Každý výskyt `sessionStorage`, `indexedDB`, `document.cookie`,
  `openDatabase`, `caches.open`, `navigator.storage` v `ui/**/*.{js,html}` = chyba (dnes 0) — nová perzistencia okna sa musí zaradiť.
- Každý guard je **čistá funkcia nad textom/dátami** a má **negatívny test nad syntetickým zdrojom** (vzor H13); hláška menuje súbor:riadok a radu „doplň riadok
  `LibraryRegistry` (sync rozhodne Michal) alebo `OUTSIDE` s dôvodom".

### R7 · D-48 v plánovacích dokumentoch

- `SYSTEM/DOGFOODING.md` D-48 „Stav": doplniť „príprava hotová — súpis `docs/architecture/kniznice.md` (H16); záväzný zoznam SYNC §1 nahrádza register".
- `SYSTEM/PLAN.md` zásobník D-48: „príprava = blok 9 · H16 ✅ (PR #…)". `SYNC_KNIZNICE_NAVRH` (zdroje) sa **neprepisuje**.

## 7 · Testy a DoD (`tests/pure/test_h16_kniznice.rb`)

- **T0 · Golden prvého behu** (R0, bežec v samostatnom procese — §15 A5) — zelený pred aj po, bez regenerácie; **dva behy bežca dajú tú istú množinu
  súborov a tie isté deterministické SHA** (opakovateľnosť). Bez SketchUpu (`skip!` v SketchUpe — tam `RbConfig.ruby` nie je samostatný interpreter).
- **T1 · Tvar registra:** kľúče a súbory jedinečné; `kind`/`sync`/`lock_mode` z množín; `lock` ∈ `LOCKS` práve pri `module`/`caller`/`mixed`; priečinok má `children`; `of`↔`attachments` obojsmerne a `of` ukazuje na `library`;
  každá `library` má ≥ 1 `versions` a `bak`; `writers` existujú; `outputs` ∧ `local` ⇒ neprázdna `note`; register aj vnorené polia zmrazené; `get` (neznámy, `nil`, Symbol).
- **T2 · Parita ciest** (v bežci — §15 A5): s `Materials.test_dir_override = tmp` každý `resolver` == `File.join(tmp, file)` a každý `LOCKS` resolver == `File.join(tmp, meno)`.
  Resolver nedostupný headless smie byť **len** `Engine.ui_theme_path` (`main.rb`) → statická kontrola `UI_THEME_FILE = 'ui_theme.json'` a delegácie `ui_theme_dir`;
  `ProductionCore` si test načíta sám (vzor `test_1b6b_hlavicky.rb:26`; po H7 `ExportSettings` je v `helper.rb`). Iný „nedostupný" resolver = chyba testu, nie preskočenie.
- **T2b · Väzba úložisko → zámok (§15 A4):** pre každý súbor, ktorý bežec zapíše cez `JsonFileStore.write` (19 riadkov, S7), sa **držaný zámok** rovná `lock` riadku
  (`none` ⇔ prázdny); riadky mimo prvého behu (`appearances`, `template_previews`, `appliance_files`, `vepo_settings`, `ui_theme`, `migration_hold`, zálohy, cache)
  nesú `lock_mode` z čítania kódu a T8 ich drží v docs.
- **T3 · Jediný koreň** (R6.3) + negatív (syntetická metóda s vlastným `ENV`).
- **T4 · Literály** (R6.1) + negatív (`FILE = 'presets.json'` v syntetickom module).
- **T5 · Zapisovatelia** (R6.2) + negatívy (nový súbor so `File.binwrite`; zapisovateľ v súpise bez primitívu).
- **T5b · Zápisové miesta** (R6.2b, §15 A1) + negatívy nad syntetickým zdrojom: druhý `JsonFileStore.write(File.join(Materials.dir, "#{name}.json"), …)` v známom súbore;
  nový pomocník s `deploy_bytes(` v inom súbore; zmenšený počet (zmazaný zápis).
- **T6 · Žiadny neznámy súbor po prvom behu:** po behu bežca každý súbor v koreni spadá pod riadok (súbor, `.bak` pri `bak`, **`children` priečinka**, glob,
  `transient`) alebo `LOCKS` — ľubovoľné dieťa známeho priečinka **nestačí** (§15 A2); súborov ≥ 25 (beh nesmie potichu nič nevyrobiť — S6); negatív `presets.json`.
- **T6b · Triedenie mien (§15 A2)** — čistá funkcia `classify(rel)` → `:final | :transient | :unknown` nad syntetickými menami: `template_previews/cabinet-dolna-<16 hex>.png`
  (final), `…png.new` a `template_previews/tmp/capture-1-2-ab.png` (transient), `template_previews/x.txt` (unknown); `textures/<10 hex>_a.jpg` / `…jpg.tmp1234`;
  `appearances/<uuid>.skm` / `…skm.staging`; `appliances/<uuid>/<uuid>_list.pdf` / `appliances/<uuid>/<uuid>.tmp`. D-48 smie preniesť **len** `:final`.
- **T7 · Verzie ↔ STANDARD §13.1:** mená `versions` všetkých riadkov = **presne** konštanty tabuľky „Súbory na počítači" (bijekcia); každá je Integer v kóde
  (`Engine::UI_THEME_STD` staticky); negatívy (riadok tabuľky bez riadku súpisu a naopak).
- **T8 · Docs ↔ register:** `kniznice.md` §2–§3 = (`file`, `kind`, `sync`, **`lock`, `lock_mode`, `versions`** — §15 A4) všetkých riadkov, §4 = kľúče `OUTSIDE`; negatív (iné `sync` v riadku docs).
- **T9 · JS pamäť** (R6.4) + negatívy (`lsSet('nx_foo', …)`; `sessionStorage.setItem(…)`; `indexedDB.open(…)` — §15 A1).
- **T10 · Zdieľaná množina pripnutá:** `shared` = `materials appearances abs_rules hardware_rules hardware_catalog hardware_taxonomy hardware_sets templates
  template_previews supplier_settings appliances appliance_files` — hláška „zmena zdieľania = rozhodnutie Michala (D-48)"; `library` ⇒ `shared`.
- **T11 · Produkčné cesty bez zmeny** (v bežci): bez override každý resolver == `File.join(ENV['APPDATA'], 'NOXUN', 'Engine', file)` — na starom aj novom kóde.
- **Mutácie (PR priloží beh každej; mutácia, ktorú nič nezhodí = doplniť test):**

| M | Mutácia | Zhodí |
|---|---|---|
| M1 | zmazaný riadok `hardware_taxonomy` | T4, T6, T7, T8 |
| M2 | nový `FILE = 'presets.json'` v module | T4 |
| M3 | `File.binwrite` v `ui/rules_dialog.rb` | T5 |
| M4 | zapisovateľ v súpise bez primitívu | T5 |
| M5 | vrátené R2 v `templates.rb` | T2, T3 |
| M6 | nová metóda `*_dir` s vlastným `ENV` | T3 |
| M7 | `TemplateStore::FILE = 'sablony.json'` | T2, T0, T11 |
| M8 | `dim_series` → `shared` | T10 |
| M9 | `lock: 'material.lock'` | T1 |
| M10 | `versions` s neexistujúcou konštantou | T7 |
| M11 | riadok §13.1 bez riadku súpisu | T7 |
| M12 | `kniznice.md` riadok so zlým `sync` | T8 |
| M13 | `lsSet('nx_foo', 1)` v `studio.js` | T9 |
| M14 | `appearances` bez `of` | T1 |
| M15 | register nezmrazený (`ENTRIES` bez `freeze` vnorených) | T1 |
| M16 | `vepo_settings` bez `note` | T1 |
| M17 | `hardware_catalog` s iným platným zámkom `materials.lock` (§15 A4) | T2b, T8 |
| M18 | druhý zápis `JsonFileStore.write(File.join(Materials.dir, "#{name}.json"), …)` v `dim_series.rb` (§15 A1) | T5b |
| M19 | nový zápis cez pomocníka `deploy_bytes(` v `materials_catalog.rb` (§15 A1) | T5b |
| M20 | `sessionStorage.setItem('nx_x', 1)` v `studio.js` (§15 A1) | T9 |
| M21 | `template_previews` bez vzoru `*.png.new` v `transient` (§15 A2) | T6b |
| M22 | `uni_seed` s `lock_mode: 'none'` (§15 A3) | T1, T2b |
| M23 | bežec spustený v tom istom procese po `test_s1a1` (override spotrebičov ostane) (§15 A5) | T0 v plnej sade (spotrebiče mimo koreňa) |

- **T12 (celé):** `ruby tests/run_all.rb` + **každá JS sada zvlášť** + `ruby scripts/encoding_guard.rb --repo`.
- **DoD:** T0 bez zmeny fixtúry · T1–T11 zelené · mutácie v PR · docs R3–R5 · PR s „Predrecenziou" a vetou „bez viditeľnej zmeny — golden prvého behu nedotknutý".

## 8 · In-SU — nie je brána, 1 beh odporúčaný

Spúšťače z CLAUDE.md sa nemenia. Odporúčaný beh `scripts\run_su_tests.ps1 -CloseWhenDone` na finálnej hlave (R2 presunie zápisy KOV-B1 do jeho `test_dir_override`
— v runneri je `ENV` už sandbox, takže živé dáta nie sú v hre, S4). Bez behu PR uvedie, že sa nespúšťal a prečo.

## 9 · Riziká

1. **R2 zmení cestu** — produkčne nie (S3, T11, T0); rozdiel len pod override v testoch (S5: sada zelená).
2. **Guard so šumom** → falošné hlásenia blokujú budúce dávky. Ochrana: vzory overené na celom pluginu (S13, S14), `OUTSIDE.names` s dôvodom, hláška s radou.
   **Falošne negatívny** guard (meno mimo vzoru, interpolácia) chytí T6, ak dávka pridá krok prvého behu (scenár R5).
3. **Pamäť modulov a cudzie override** (S6, §15 A5) → bežec v samostatnom procese (čerstvý helper); poradie testov v sade výsledok nemení.
4. **Kolízia s H7/H15/H11a** (§5.1). **Dva zoznamy** (register + `kniznice.md` + §13.1) → bijekčné guardy T7, T8.
5. Súpis **tvrdí klasifikáciu**, ktorú ešte potvrdí Michal (Q1, Q2) — zmena je jeden riadok + T10.

## 10 · Smoke pre Michala

1. Po aktualizácii: Štúdio → Šablóny (náhľady, vloženie zo šablóny), Materiály, Kovanie, Spotrebiče, O plugine — všetko ako predtým.
2. Priečinok `%APPDATA%\NOXUN\Engine` (cesta je v O plugine): **žiadny nový súbor** ani priečinok.
3. **Prečítaj si súpis** (`docs/architecture/kniznice.md`, časti 2 a 3): sedí, čo sa má s Luciou zdieľať a čo ostane každému? (Q1, Q2.)

## 11 · Checklist uzáveru

Bump patch `VERSION` (2×) + **všetky `?v=`** → T0–T12 → architektúra (R3, router, `NX_ARCH_FILES` + strop, odsek `json_file_store.rb`, R5) → **Grep tvrdení
o zozname súborov v `%APPDATA%`** (`docs/architecture/*.md`, STANDARD, STAV „Kompatibilita") a oprava každého, ktorý súpis vyvracia → R4 → R7 → **prepis STAV** →
**KRONIKA** navrch → PLAN H16 ✅ + `PR #?` → package + surový audit do `SYSTEM/zdroje/bloky/HARDENING/` → PR popis („nič viditeľné", trieda, Predrecenzia,
mutácie, in-SU beh alebo dôvod). Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Register v kóde** + zrkadlo `kniznice.md` strážené bijekciou — **nie** len docs + guard | záväzný návrh D-48 (SYNC §1, §6 SYNC-0, Codex #323 P2) chce register **v kóde** a „zoznam z registry, nie ručne"; docs-only súpis by D-48 prepisoval do kódu → dva zoznamy. Register nesie len **nové** fakty (zdieľanie, zámok, prílohy, verzie, zapisovatelia), cesty berie z modulov (`resolver`) | **áno** |
| D2 | **R2 v H16** (jediný koreň) | C-04 to menuje; vzor R-08 (produkcia bajtovo rovnaká, S3, S5); inak výnimka v T2/T3. Alternatíva: vynechať → výnimka s dôvodom a §14 | **áno** |
| D3 | Súpis = **len údaje**: žiadne vynútenie v `JsonFileStore`, háčiky, inventár disku ani UI | C-04 „bez kopírovania dát"; vynútenie mení správanie → SYNC-0/1 s vlastným auditom | nie |
| D4 | Klasifikácia = SYNC §1 + doplnené chýbajúce položky ako `local`; `dim_series` a `vepo_settings` `local` s poznámkou (Q1, Q2) | SYNC §1 je záväzný zoznam (S15); zmena = jeden riadok + T10 | krátko |
| D5 | Nový súbor mapy `kniznice.md` (nie odsek v `model-a-identita.md`) | D-48 a Michal majú jednu stránku; `model-a-identita.md` má 73 z 90 kB | nie |
| D6 | `writers` = súbory (cesty od koreňa repa), nie metódy | stabilné pri refaktore; presnosť dopĺňa T4 (mená) a T6 (beh) | nie |
| D7 | Jedna dávka | < 300 riadkov kódu, správanie produkčne totožné | nie |
| D8 | `localStorage` a `preferences_key` v `OUTSIDE` (pamäť okna, per PC) | úplnosť „čo plugin ukladá"; nové kľúče stráži T9 | nie |
| D9 | Scenár v mape rozširovacích bodov | „zabudnutý krok zhodí test" — agent nájde postup tam, kde hľadá | krátko |

## 13 · Otázky pre Michala (implementácia nečaká; platí predvolená voľba, zmena = jeden riadok)

- **Q1 · Rozmerové rady** (ponuka šírok, výšok, hĺbok pri poliach Inspectora). 6.9. si povedal „zdieľať aj rozmerové rady"; návrh zdieľania potom určil, že sú
  **osobné** (každý má iné zvyky). **Predvolené: každý PC svoje.** Ak chceš, aby Lucia mala tvoje rady, budú sa zdieľať ako katalógy.
- **Q2 · „Zlúčiť 18 + 36" pri VEPO.** Prepínač mení, či VEPO dá dosky 18 a 36 mm do jedného súboru. Žije v súbore spolu s **názvami zákaziek** a posledným priečinkom
  exportu (tie sú viazané na tento PC). **Predvolené: každý PC svoje.** Ak má VEPO u teba aj u Lucie vyzerať rovnako, D-48 ho zo súboru vyčlení a bude sa zdieľať.

## 14 · Nálezy mimo scope — odovzdanie D-48 (do `kniznice.md` §5 ako fakty)

- **F1 · Názov zákazky necestuje so zákazkou:** `project_names` má kľúč **cestu .skp** (`production_core.rb:344`) v súbore tohto PC → Lucia pri otvorení tvojej
  zákazky názov nevidí (VEPO a exporty dostanú meno súboru). Súvisí E-01/G-02 (karta zákazky); H7 to nemení.
- **F2 · Obrázky dekorov** sa sťahujú len pri založení skupiny (S11) → po zdieľaní katalógu druhé PC ukáže farby; D-48: zdieľať `textures/` alebo dotiahnuť pri zobrazení.
- **F3 · Zámky nie sú jednotné:** návrat `flock` nekontroluje `TemplateStore`, `TemplateUsage`, `UsageStats`, `HardwareCatalog`; `TemplateStore.with_lock` výnimku
  prehltne (S7) — pri `%APPDATA%` na sieťovom disku by sekcia bežala bez zámku. D-48 import: `lock` z registra + jednotné primitívum.
- **F4 · Poradie zámkov:** `hardware_catalog.lock` a `materials.lock` sa nesmú vnárať (`hardware_catalog.rb:433`) → D-48 Aktualizovať berie knižnice **postupne**, nie naraz pod jedným zámkom.
- **F5 · Značky UNI (opravené §15 A7):** `uni_seed.done` a `drawer_uni_seed.done` nesú aj význam **„používateľ seed vedome zmazal — nevracaj ho"**
  (`materials_catalog.rb:1112-1117`), no žijú per PC. Keď príde katalóg bez UNI záznamu na PC **bez** značky (napr. Lucia na staršom plugine, ktorý `drawer_uni_seed.done`
  ešte nemá, a potom aktualizuje), ďalší štart záznam **doplní späť** (`:1142-1143`, `:1168-1173`). **Požiadavka pre D-48:** import musí zachovať úmyselné odstránenie
  (riešenie navrhne D-48; zo súpisu nevyplýva automatické zdieľanie značiek).
- **F6 · H9 N5:** `TemplateStore.migration_source`/`library_doc` má lokálnu kópiu „zlý tvar = poškodený" → spoločné primitívum pri D-48.
- **F7 · KOV-I** prepisuje `TemplateStore.dir` ručne (`su_runner.rb:27317-27322`) — po R2 zbytočné; upratať s najbližšou in-SU dávkou. **KOV-B1** hláška „sandbox aktívny" platí po R2 pravdivo.
- **F8 · `ui_foto.ps1:196-198`** má vlastný zoznam „čo kopírovať" → pri D-48 alebo ďalšej úprave nástroja brať druhy z registra.
- **F9 · SYNC §1 nepresnosti** (S15) — D-48 package odkáže na register namiesto tabuľky §1.
- **F10 · Nápad pre D-48:** `Debug.report` (len čítanie) doplniť o inventár knižníc (existuje, veľkosť, `std`) — porovnanie stavu Michal vs Lucia jedným príkazom ešte pred Odoslať / Aktualizovať.
- **F11 · Téma a prepínače kontroly bez zámku** — dve okná SketchUpu: posledný zápis vyhrá; prijateľné (osobné nastavenie).
- **F12 · `versions` nie je kompatibilitná brána (§15 A8):** zoznam ukazuje na STANDARD §13.1, ale `current_std` z neho odvodiť nejde — sety majú značky obsahu
  (§13.2, `HardwareSets::STD_SUPPORTED`, `hardware_sets.rb:157-159`, `:1318-1322`, zápis `std` podľa obsahu `:3116-3120`), materiály a kovanie lazy schému (§13.3).
  SYNC-0 potrebuje skutočné pravidlá kompatibility (funkcie `assess`/brány store-ov), nie len čísla.
- **F13 · Cudzie súbory v koreni (§15 A9):** `scripts/start_okna.ps1` píše `agent_register_videne.txt` priamo do `%APPDATA%\NOXUN\Engine` → D-48 Odoslať/Aktualizovať
  vyberá súbory **podľa registra**, nikdy výpisom priečinka.

---

## 15 · Audit návrhu — zapracovanie (Codex gpt-6-astra, 2.10.2026) — 0 BLOCKER · 7 FIX · 3 NOTE · **MÁ PREDNOSŤ**

Surový výstup `AUDIT_H16_raw.md` (implementátor ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package). Tvrdenia som pred rozhodnutím overil sondou
(sandbox `tests/helper.rb`, nie živý `%APPDATA%`): `sonda_h16_locks.rb` → `sonda_h16_locks_out.txt` (zámok držaný pri každom zápise prvého behu) a prototyp bežca
`proto_h16/ENGINE/tests/h16_first_use.rb` (dva behy v samostatných procesoch: 27 súborov, rovnaká množina, SHA sa líšia len pri `appliances.json`, `legacy_cleanup.json`,
`*.done`; všetky cesty nasledujú override; väzba zámkov = §0.1). Všetky FIX zapracované do §0–§14.

| # | Nález | Overenie | Zmena v package |
|---|---|---|---|
| **A1** FIX | Nové úložisko v už známom zapisovateľovi (`JsonFileStore.write(File.join(Materials.dir, "#{name}.json"), …)`), zápis cez pomocníka ani nová JS perzistencia (`sessionStorage`, IndexedDB) guardy neprejdú | **potvrdené** — T4 hľadá literály, T5 len príslušnosť súboru | **R6.2b + T5b:** `NX_H16_WRITE_SITES` = počet zápisových riadkov **na súbor** + dôvod (allowlist, nie parser; refaktor so zachovaným počtom ho nehýbe) · **R6.4 + T9:** zákaz `sessionStorage`/`indexedDB`/`document.cookie`/`openDatabase`/`caches.open`/`navigator.storage` bez zaradenia · **R5 (5):** nové úložisko = krok v bežci + počet · **M18–M20** |
| **A2** FIX | Chýbajú staging mená `<náhľad>.png.new` (`template_previews.rb:272`, upratovanie `:339`) a `<obrázok>.tmp<pid>` (`image_cache.rb:83`); T6 púšťal ľubovoľné dieťa známeho priečinka | **potvrdené** čítaním | §0.1 riadky #2, #9, #12, #23 a „Dočasné" · **R1.2** pole `children` (vzory finálnych súborov) + `transient` · **T6** len `children`/`transient` · **T6b** `classify` → `:final/:transient/:unknown`, D-48 prenáša len `:final` · **M21** |
| **A3** FIX | Značky UNI, predmigračná a forenzné zálohy nie sú „bez zámku" — `materials.lock` drží volajúci; `migration_hold.json` zmiešaný | **potvrdené:** `materials_catalog.rb:1078-1093`, `:1151-1173`; `materials_migration.rb:166-176`; `materials_health.rb:237-273`, `:446-476`, mazanie `:422-424`; sonda: UNI značky zapísané pod `materials.lock` | **S7** prepísané (16 položiek pod `materials.lock`) · §0.1 stĺpec Zámok #9, #25–#30 · **R1.2** `lock_mode` ∈ `module caller mixed self none` · **T1** pravidlá `lock`↔`lock_mode` · **M22** |
| **A4** FIX | Iný, ale platný zámok (`hardware_catalog` → `materials.lock`) T1 prejde; T8 neporovnáva zámky | **potvrdené** | **T2b** väzba súbor → **držaný** zámok v bežci (19 zápisov prvého behu) · **T8** porovnáva aj `lock`, `lock_mode`, `versions` · **M17** |
| **A5** FIX | Nezávislosť od poradia neplatí: `ApplianceCatalog.test_dir_override` (má prednosť, `appliance_catalog.rb:188-192`) nechá `test_s1a1` nastavený (`:1045-1047`); reset po návrate chýba | **potvrdené** (`test_s1a1_appliance_catalog.rb:20`, `:1045-1047`); prototyp prešiel len vďaka abecednému poradiu | **najjednoduchšie spoľahlivé riešenie:** **bežec v samostatnom procese** (`tests/h16_first_use.rb`, čerstvý helper = čerstvý sandbox a pamäť, `IO.popen` vzor `test_d52a_updater.rb:308`), **dva behy** = opakovateľnosť; T0, T2, T2b, T6, T11 bežia v ňom · **R0.1** prepísané (žiadny reset ani prepínanie `ENV`) · §9 riziko 3 · **M23** |
| **A6** FIX | Nový scenár mapy narazí na H13 guard (≥ 4 strážené riadky na scenár) | **potvrdené** `test_h13_rozsirovacie_body.rb:183-185` | **R5:** 6 naozajstných riadkov (`library_registry.rb`, `materials.rb`, `json_file_store.rb`, `test_h16_kniznice.rb`, `h16_first_use.rb`) + `NX_H13_REQUIRED` |
| **A7** FIX | F5 podceňuje značky UNI — nesú „používateľ seed vedome zmazal" | **potvrdené** `materials_catalog.rb:1112-1117`, `:1142-1143`, `:1168-1173` | **§14 F5** prepísaný: požiadavka pre D-48 „import zachová úmyselné odstránenie"; značky ostávajú `local` |
| **A8** NOTE | `versions` nie je kompatibilitná brána (značky obsahu setov §13.2) | súhlas | **§14 F12** odovzdanie SYNC-0: `current_std` sa z `versions` neodvodí |
| **A9** NOTE | `scripts/start_okna.ps1:24`, `:198` píše `agent_register_videne.txt` do koreňa | **potvrdené** | **S1** hranica súpisu · §0.2 skupina **`dev_tools`** (8 skupín) · **§14 F13** D-48 vyberá podľa registra, nie výpisom priečinka |
| **A10** NOTE | R2, rozsah, trieda, register v kóde, nový súbor mapy, Q1/Q2 obhájiteľné | súhlas | bez zmeny; Q1/Q2 ostávajú s predvoľbou |

**Koncept bez zmeny** (register v kóde, jediný koreň R2, súpis len údaje, jedna dávka, trieda audit áno / výrobná nie / in-SU odporúčaný). Spresnené: zámok ako
režim (`lock_mode`) a väzba overená behom, finálne vs. dočasné mená v priečinkoch, počty zápisových miest, bežec v samostatnom procese. **Nový odhad: ¾–1 deň**
(kód pluginu ~+200, testy ~+600 vrátane bežca ~90 riadkov; mutácie M1–M23).

**Potvrdenie orchestrátora (2.10.2026):** audit H16 uzavretý (0 BLOCKER, FIX zapracované v §15, koncept bez zmeny — delta audit sa nespúšťa, overí predrecenzia
a GH review). §12: D1 áno (register v kóde `core/library_registry.rb` — dôvod SYNC-0) · D2 áno (R2 v H16) · D3–D9 áno. Jedna dávka, z čerstvého mainu
**po H7a/H7b a H15a/H15b** (§5.1 overiť pred štartom). Q1 (rady) a Q2 (18 + 36) = predvolené „každý PC svoje", otázky idú Michalovi v reporte.
