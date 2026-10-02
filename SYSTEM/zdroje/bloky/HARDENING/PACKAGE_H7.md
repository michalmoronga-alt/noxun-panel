# PACKAGE H7 · Názov zákazky na jednom mieste + nastavenia exportu v jadre + ochrana R-38 — blok 9 HARDENING PO V1

> **Autorita:** mockup `MOCKUP_H7_NAZOV_ZAKAZKY.html` schválený 2.10.2026 (`ROZHODNUTIA_H6_H7_2026-10-02.md`: **O1–O9 podľa odporúčania, R-38 v H7 áno**) · `AUDIT_REGISTER.md`
> **R-38** · `PLAN.md` blok 9 riadok **H7** („pred presunom ochrana R-38") · triedenie **A-05** (CU-07, GR-20), **C-07**. Vzory rodiny: `PACKAGE_H9.md` (predikát tvaru, `write_gate`,
> matica, `.bak`), `PACKAGE_H10.md` (dve inštancie SketchUpu, výsledok zápisu cez `case`). Cieľ bloku: **pri zdravom súbore sa výrobné ani cenové čísla nemenia.**
> **Rez (§2):** **H7a · nastavenia exportu v jadre + R-38 (Ruby)** → **H7b · názov zákazky v hlavičke Štúdia (UI)**, každá vlastný PR z čerstvého `main`. Jeden audit návrhu pre oba.
> **§15 (audit návrhu: 1 BLOCKER · 5 FIX · 2 NOTE — zapracované) MÁ PREDNOSŤ** pred textom §1–§14 tam, kde sa líšia; **§16 (delta audit: 2 BLOCKER · 2 FIX · 4 NOTE — zapracované)
> má prednosť pred §15** (ruší protokol potvrdenia a odkladu exportu → bezstavová kontrola `expect`; náprava = premenovanie súboru, nie zmazanie).
> **Trieda (§5):** H7a audit-povinná · **výrobná/cenová áno** (rozsah zmeny len pri poškodenom súbore, brány výrobnej dávky platia celé — §15 A8) · predrecenzia · in-SU nie je brána podľa spúšťačov, **1 beh = DoD pred mergom** (mení sa `su_runner.rb`).
> H7b nový ovládací prvok → predrecenzia · výrobná/cenová nie (golden) · fotky `-Record`. **Schéma sa nemení.** Verzia: patch + všetky `?v=` + STAV (dnes v0.17.15).
> **Stav kódu:** sonda nad `main` **`108c808c`** (po H14b #451). Riadky = stav k nemu.

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 2.10.2026

Skripty `scratchpad/HARDENING/sonda_h7.rb` (dnešné správanie) a `sonda_h7b.rb` (navrhnutý predikát nad dnešnými primitívami H9); výstupy `sonda_h7_out.txt`, `sonda_h7b_out.txt`.
Ruby 3.2 cez `tests/helper.rb` (APPDATA = sandbox, inak skript skončí); `do_set_vepo_opts` headless so stubmi `set_status`/`push_vepo_bar`/`push_state`. Model, repo ani živý `%APPDATA%` sa nemenili.

| # | Tvrdenie o dnešnom kóde (`ui/production_core.rb`, ak nie je uvedené inak) | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | `%APPDATA%\NOXUN\Engine\vepo_settings.json` (`Materials.dir`), objekt s kľúčmi **`project_names`** (mapa kľúč → názov), **`merge_18_36`** (`!= false` = zapnuté), **`last_dir`**; pretty JSON, `.bak` sa točí pri každom zápise | `:21-29`, `:293`, `:523-530`; sonda S1 | PRAVDA |
| S2 | **Jediný zápis** v `update_vepo_settings` (`:80-97`): zámok `Materials.with_catalog_lock` → `reload!` → strikné `vepo_settings_for_write` (`:49-56`, nečitateľný/nie-objekt = výnimka) → blok → `JsonFileStore.write(path, fresh.merge(attrs))`; `rescue` → `false` + log s fázou | sonda S8 | PRAVDA |
| S3 | Zapisovatelia: `save_vepo_settings` (`:108-119`, mapu odmietne) ← `save_merge_18_36` a 4× `last_dir` (`:2066`, `:2146`, `:3622`, `:3713`); `update_project_names` (`:332-339`) ← `save_project_name` (`:493-519`) a **`adopt_session_name` (`:442-471`) — zapisuje pri ČÍTANÍ** `project_name` (payload, echo, 4 exporty) | sonda S3 (`guid:nxdoc-…` → cesta po čítaní) | PRAVDA |
| S4 | Čítanie `vepo_settings` (`:33-40`) lenivé: `read` (nečitateľný primár → ticho `.bak`), nie-objekt/chyba → `{}`; exporty začínajú `refresh_vepo_settings` (`:128-133` = `reload!` primára) | `:1997`, `:2105`, `:3572`, `:3657` | PRAVDA |
| S5 | Kľúč = normalizovaná cesta (`c:/zakazky/kuchyna_novak.skp`), neuložený **`guid:<DocKey token>`**; strop **120**; prázdne alebo rovné predvolenému = zmazanie; predvolené = meno súboru, inak **`projekt`** | `:344-357`, `:403-406`, `:268-271`, `:497-509`; sonda S2 | PRAVDA |
| S6 | `save_project_name` vracia **platný názov** (String), `save_merge_18_36` **hodnotu po zápise** — výsledok zápisu sa zahodí | sonda S1, S5 | PRAVDA (R-38) |
| S7 | Zlyhaný zápis (zámok) → okno **zeleno so starým názvom** „Názov projektu: Povodny. Platí pre všetky exporty."; 18 + 36 vypnuté, zápis zlyhal → zeleno „18+36 spolu: zapnuté…" | sonda S5, S6 | PRAVDA (O8) |
| S8 | **R-38:** nečitateľný primár + dobrá `.bak` → čítanie zo zálohy, zápis z okna **prejde** a prepíše primár obsahom zo zálohy (zeleno) | sonda S4a, S6c | PRAVDA |
| S9 | `[]`/`null` + dobrá `.bak` → čítanie `{}`: názov = meno súboru, **`merge_18_36` = true hoci záloha má false** (VEPO zlúči 18/36 proti nastaveniu), zápisy ticho zlyhajú | sonda S4b, S4g | PRAVDA |
| S10 | `{"project_names":[]}` alebo `{}` + dobrá `.bak` → mapa prázdna, zápis prejde a **dobrá záloha sa zničí** | sonda S4c, S4h | PRAVDA |
| S11 | Bez `.bak`: nečitateľný/nie-objekt → zápisy **natrvalo** zlyhajú (kým sa súbor nezmaže), okno zeleno s predvoleným názvom; objekt so zlým `project_names` → prvý zápis ho opraví | sonda S4d–f | PRAVDA |
| S12 | Predikát `Hash ∧ neprázdny ∧ (bez project_names ∨ project_names je Hash)` nad **dnešnými** `JsonFileStore.degraded?(…, shape:)`/`read_valid`: degradovaný presne pri zlom tvare/nečitateľnom + dobrej `.bak`; zdravé (aj `{"merge_18_36":false}`, `{"project_names":{}}`) nie; chýbajúci primár + dobrá `.bak` nie (obnova); bez dobrej zálohy `InvalidShape` | `sonda_h7b_out.txt`, 16 prípadov | PRAVDA |
| S13 | Plugin **nikdy nezapísal `{}`** — od V0.5 C (`71f89041`) je každý zápis `….merge(attrs)` s neprázdnymi `attrs`, `project_names` vždy objekt | `git show 71f89041`, `:91`, `:337` | PRAVDA |
| S14 | `JsonFileStore.reload!(path)` **nezhodí** cache `….bak\|nofallback`, ktorú plní `read_valid` | sonda H7b | PRAVDA → R-A5 `refresh` |
| S15 | `JsonFileStore.write(…, shape)` nad `{}` + dobrá `.bak` zálohu zachová, bez tvaru ju prepíše | sonda H7b | PRAVDA |
| S16 | Brána generácie `do_set_vepo_opts` (`studio_dialog.rb:636-639`): zastaraný `gen` → `push_state` + červené „Okno sa medzitým prepočítalo…"; **napísaný názov sa stratí** | sonda S6b | PRAVDA |
| S17 | Echo `push_vepo_bar` (`studio_dialog.rb:665-673`) → `NX.setVepoBar` (`studio.js:1151-1167`): `#prjInput` len mimo fokusu, `#mergeChk` vždy; generáciu nedvíha | guard `test_st1a_studio.rb:857-879` | PRAVDA |
| S18 | Mená exportov: VEPO priečinok `VepoExport.project_slug` (`vepo_export.rb:175-179`; prázdne → `projekt`, `con` → `projekt_con`), CSV `<slug>_…` (`:288`), LOG (`:340`); CSV kovania **inline** `"kovanie_#{slug}.csv"` (`:2139`); `BudgetXlsx.file_name` (`xlsx_writer.rb:402-407`, „… - AKT 1.10. 2026"); `CpXlsx.file_name` (`cp_export.rb:627-633`, „… - 1.10.2026"); prázdny → „zakazka" | sonda S7 | PRAVDA |
| S19 | Volajúci mimo modulu: `studio_dialog.rb:649, :653, :667-669, :1664-1666`; `core/doc_key.rb:177`; testy `test_st1a_studio.rb` (~40 volaní + textové guardy nad `production_core.rb`), `test_st1a_core.rb:27-56`, stuby exportov `test_kon0_d143.rb:139`, `test_kovh1_adhoc.rb:181`, `test_np4_ceny.rb:168`, `test_p0hf_brany.rb:192,:722`, `test_r14_budget_std.rb:212`, guardy `test_st1c_nakup.rb:177`, `test_doc_key.rb:198`; `su_runner.rb:15623-15665, :16038-16061` | Grep | PRAVDA |
| S20 | Goldeny H14 pripínajú dnešnú hlavičku/lištu: `g1_nav.json` 15× `secmodel` „zákazka: GOLDEN · v…", `g2/g4/g8` `prjbox`/`vepoBtn`; `push_keys.json` bajty `vepo` (3 kľúče); test „fixtúra sa NEREGENERUJE" | `test_h14_studio_sekcie.rb:12, :165-166` | PRAVDA |
| S21 | Pravidlo troch miest lišty Kusovníka: kód · `UI20_KONTRAKT.md:457-459` (Š5 „[Projekt]") · `mockup_studio.html:421-425, :1320-1321` | `test_st1a_studio.rb:885+` | PRAVDA |

**Upresnenie mockupu:** riadky z v0.17.0 sa posunuli (`renderHead` `studio.js:1240-1248`, `stModel` v `NX.setStudio` `:1130`, `bomToolsHtml` `:1322-1349`, udalosti `:2118-2119, :2130`,
`vepoBtnHtml` `:1367`, `buyRenderTools` `:1293-1301`, `budget.js` XLSX `:488-491`, ponuka `:1329-1331`, payload `studio_dialog.rb:1636, :1664-1666`). Navyše: pri `[]`/`null` dnes VEPO
**zlúči 18 a 36 proti nastaveniu v zálohe** (S9) — R-38 nie je len o názvoch.

---

## 1 · Cieľ

**Pre používateľa (H7b):** názov zákazky je **v hlavičke Štúdia v každej sekcii** („Zákazka: Kuchyňa Novák ✎"), klik = úprava na mieste; pole PROJEKT v Kusovníku zmizne. Kým by sa
exporty pomenovali „projekt", svieti **jantárová bodka** v hlavičke a na štyroch exportoch, tooltip povie presné meno priečinka/súboru, po exporte pribudne jedna veta. Exporty sa pri
rovnakom texte volajú **bajtovo rovnako** ako dnes. **Pod kapotou (H7a):** nastavenia exportu žijú v **module jadra** `ExportSettings`; poškodený súbor s dobrou zálohou sa **číta zo zálohy
a nezapisuje** (nikdy sa ticho neprepíše, záloha sa nezničí); každý zápis vráti výsledok a okno zlyhanie povie **červeno** — názov ostane na pôvodnom.

## 2 · Rez a odhad — dve časti, sekvenčne z čerstvého `main`

| Časť | Obsah | Kód pluginu (+/−) | Testy | In-SU | Odhad |
|---|---|---|---|---|---|
| **H7a · jadro + R-38 (Ruby)** | T0 golden → R-38 ochrana a stavy **na mieste** v `ui/production_core.rb` → **čistý presun** do `core/export_settings.rb` → hlásenia v `do_set_vepo_opts` → docs | ~+430 / −420 (presun ~330 s komentármi; **nová logika ~100**) | ~550 (nová sada + prepojenie ~200 existujúcich) | DoD 1 beh | 1 deň |
| **H7b · hlavička (UI)** | payload `vepo` · hlavička + editor · pole preč · bodky a tooltipy · veta a echo po exporte · texty · CSS · goldeny H14 · ui20 · docs | ~+300 / −70 | ~400 | nie | ¾–1 deň |

**Poradie commitov H7a (záväzné):** (1) T0 golden, plugin bez zmeny · (2) ochrana R-38 + stavy v `ui/production_core.rb` + matica R-A2 · (3) presun bez zmeny správania (testy z (2) len
prepojené) · (4) hlásenia v okne · (5) docs. Predrecenzia tak vidí presun oddelene od zmeny správania. **Poistka:** nová logika > ~150 riadkov → implementátor zastaví, rozhodne orchestrátor.
**(§15) Po audite:** H7a nová logika ~140 riadkov (+ čakajúci názov, obmedzenie pokusov adoptu, brána nad zálohou) → poistka **~180**, odhad **1–1¼ dňa**; H7b ~+360/−70
(+ potvrdenie zápisu a odklad exportu, stav „neuložené k súboru") + rozšírenie testovacej knižnice `minidom.js` (~60), odhad **1–1¼ dňa**. Rez sa nemení.
**(§16) Po delta audite:** H7a ~145 riadkov novej logiky (obsahový podpis namiesto `file_signature`, vyprázdnenie v `refresh`), poistka ~180, odhad **1–1¼ dňa** · H7b **~+320/−70**
(protokol potvrdenia a odkladu zrušený, pribudla bezstavová kontrola `expect` v 4 exportoch a `VEPO_EXPECT`) + `minidom.js` ~70, odhad **1 deň**. Rez sa nemení.

## 3 · Scope IN

**H7a:** `core/export_settings.rb` = celé úložisko z `production_core.rb:21-133, :267-530` + predikát, `write_gate`, stavy, čítanie so zálohou (R-A1–R-A5); volajúci (R-A6); hlásenia (R-A7);
log raz za zmenu stavu; docs (R-A9). **H7b:** R-B1–R-B12.

## 4 · Scope OUT

Tvar súboru, meno, kľúče, kľúč záznamu, strop 120, prenos pri prvom uložení, „projekt" (bez migrácie, bez `std`) · „Uložiť ako"/premenovanie/Lucia (O6 → G-02) · predvyplnenie z mena súboru (O5) ·
hodnotové poškodenie (§14 N2) · banner/Kontrola pri čítaní zo zálohy (Q1) · samooprava nečitateľného súboru **bez** zálohy (dnes stojí, kým sa nezmaže — len sa to povie) ·
„Kovanie → Projekt" („Model: <súbor>" — sady v modeli) · Nárezový plán · spoločná príprava exportov (H17 prevezme skladač mien).

## 5 · Trieda podľa CLAUDE.md

- **Audit návrhu: povinný** — nový modul jadra + zmena kontraktu zápisu perzistentného súboru (brána, stavy). Schéma bez zmeny. Jeden audit pred H7a; zmena kontraktu z §6 = delta.
- **Výrobná/cenová:** **H7a áno** (§15 A8: „len pri poškodení" opisuje rozsah zmeny, nie výnimku z brán — golden T0, predrecenzia, KRONIKA ako výrobná dávka) — pri zlom tvare + dobrej zálohe sa názov **a „18 + 36"** berú zo zálohy (dnes `{}` → meno súboru a zlúčenie — S9) = mení pomenovanie
  aj **členenie VEPO** v tom stave. Zdravý súbor bajtovo bez zmeny (T0). **H7b nie** — mená a obsah exportov sa nemenia (T0a/T0c bez regenerácie); veta po exporte je stavový riadok, tooltip popisný údaj.
- **Predrecenzia: povinná** H7a (audit-povinná, > 300 riadkov) aj H7b (nový ovládací prvok — editor názvu).
- **In-SU:** spúšťače sa nemenia (zápis do `%APPDATA%`, nie do modelu) → podľa zoznamu **nie je brána**; H7a mení `su_runner.rb` → **1 beh `-CloseWhenDone` na finálnej hlave je DoD a podmienka
  mergu H7a** (§8, §15 A8 — package ho fakticky vyžaduje, tak to platí výslovne).
- **Fotky:** H7a nie (payload bez zmeny — `push_keys.json`). **H7b `-Record`** (mení sa payload `vepo`) + hárok do reportu.

**5.1 Závislosti (overiť pri štarte časti):** **H6** — `?v=`, prípadne `studio.html` · **H11a** — môže meniť `studio_dialog.rb` · **H17** — po H7, prevezme `export_file_names`,
`hw_csv_file_name`, `default_name_note` (žiadne druhé kópie) · H14 (zmergované) — hlavička z `renderHead`, H7b mení len jej pravú časť.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit H7a, plugin bez zmeny, zelené na `main`)

- **T0a mená a nadpisy (funkcie)** — `tests/fixtures/h7_golden/names.json` + ručný `generate.rb` (len nad nezmeneným kódom, vzor `h14_golden`). Názvy `Kuchyňa Novák`, `projekt`,
  `Kuchyna_Novak`, `con`, `COM1`, ``, `   `, `a/b:c*?"<>|`, `Žltá skriňa – 2. NP`, 120× `A`, `Ťažká "zákazka"`; `now = Time.new(2026,10,1,14,5)`. Pre každý: `VepoExport.project_slug`,
  prefix CSV, LOG, CSV kovania **presne výraz `:2139`**, 1. riadok `HardwareSets.purchase_csv(min_exp, project:, generated_at: pevný)`, `BudgetXlsx.file_name`, `CpXlsx.file_name`
  + titulky hárkov (najmenší deterministický vstup zvolí implementátor — NEOVERENÉ sondou).
- **T0b bajty súboru:** sekvencia v sandboxe — názov uloženého modelu · názov neuloženého → „uloženie" → čítanie (adopt) · 18 + 36 vypnuté · `last_dir` · zmazanie názvu · 130 znakov ·
  zápis „druhej inštancie" medzi naším čítaním a zápisom (vzor `ST1B_OTHER_INSTANCE`) → bajty primára **aj `.bak`** po každom kroku. Po H7a cez `ExportSettings` **tie isté bajty**.
- **T0c exporty end-to-end:** `do_export`, `do_hw_csv`, `do_budget_xlsx`, `do_cp_xlsx` so stubmi zberu a výberu (vzor `test_p0hf_brany.rb`), **bez stubu názvu a nastavení** (názov cez verejné API
  do sandboxu; zadaný, uložený bez názvu, neuložený): navrhnuté meno, priečinok VEPO a jeho súbory, uložený `last_dir` → `h7_golden/exports.json`.
- **T0d payload:** `test_h14_studio_sekcie.rb` (`push_keys.json`, bajty `vepo`) **bez úpravy zelený po H7a**.

### R-A1 · Modul `Noxun::Engine::ExportSettings` (`core/export_settings.rb`, `module_function`)

- **Konštanty** (presun, hodnoty bez zmeny): `FILE = 'vepo_settings.json'`, `PROJECT_NAMES_KEY`, `PROJECT_NAME_MAX = 120`, `SESSION_KEY_PREFIX = 'guid:'`, `SESSION_KEY_BRIDGE`,
  `SESSION_BRIDGE_MAX = 32`; nové `DEFAULT_PROJECT_NAME = 'projekt'`, `DEGRADED_REASON`, `UNREADABLE_REASON`, `FAILED_REASON` (R-A7), typ `NotObject < IOError` (dnešná správa „… obsah nie je objekt").
- **Verejné:** `path` · `doc_shape_ok?` · `shape_check` · `read` · `refresh` · `write_gate` · `update` · `save` · `written?` · `project_names` · `update_project_names` · `normalize_project_path` ·
  `project_session_key` · `session_key?` · `remember_session_key` · `forget_session_key` · `remembered_session_key` · `session_keys_for` · `project_key` · `effective_project_name` ·
  `default_project_name` · `project_name` · `save_project_name` · `merge_18_36` · `save_merge_18_36` · `last_dir` · `save_last_dir` · **`name_pending?`** (§15 A1); konštanta `ADOPT_RETRY` (§15 A5, obsahový podpis §16 B4); H7b `name_source`, **`expect_mismatch(model, expect, merge:)`** (§16 B2). Interné `read_for_write`, `adopt_session_name`, `doc_token`, `note_block`.
- **`doc_token(model)`** = `model ? DocKey.key(model) : ''`, `rescue StandardError` → `''` — **identické** s `ProductionCore.model_guid` (kľúč `guid:` sa nesmie zmeniť; T0b).
- **`ProductionCore` po H7a nemá** `VEPO_SETTINGS_FILE`, `vepo_settings*`, `update_vepo_settings`, `save_vepo_settings`, `refresh_vepo_settings`, rodinu názvu (`project_*`, `session_*`, `adopt_*`,
  `effective_project_name`, `default_project_name`), `merge_18_36`, `save_merge_18_36` ani ich konštanty — **žiadne delegáty** (D1). `model_guid` ostáva.
- **Načítanie:** `main.rb` `Sketchup.require 'noxun_engine/core/export_settings'` za `core/materials`, pred `ui/production_core` (pri `supplier_settings`); `tests/helper.rb` zoznam. Pri načítaní nesiaha na súbor.

### R-A2 · Predikát tvaru a matica (záväzná)

**`doc_shape_ok?(doc)`** ⇔ `doc.is_a?(Hash)` ∧ `!doc.empty?` ∧ (`!doc.key?('project_names')` ∨ `doc['project_names'].is_a?(Hash)`). Len kontajnery (H9 A2); hodnoty posudzuje dnešná
normalizácia. `shape_check` = `method(:doc_shape_ok?)` — volá ho výhradne `JsonFileStore`.

| Stav súboru | Čítanie (`read`) | Zápis (názov, 18 + 36, `last_dir`, adopt) | Výsledok | `.bak` |
|---|---|---|---|---|
| zdravý | súbor | áno | `:ok` / `:unchanged` | ako dnes |
| chýba primár, `.bak` dobrá | záloha (ako dnes) | áno — **obnova** | `:ok` | ako dnes |
| nečitateľný + dobrá `.bak` | záloha (ako dnes) | **odmietnutý** (dnes prešiel — S8) | `:blocked` + `DEGRADED_REASON` | **nedotknutá** |
| zlý tvar (`[]`, `null`, `"x"`, `42`, `{}`, `project_names` nie objekt) + dobrá `.bak` | **záloha** (dnes `{}` — S9, S10) | **odmietnutý** | `:blocked` | **nedotknutá** (dnes niekedy zničená) |
| nečitateľný / nie-objekt **bez** dobrej `.bak` | predvolené (ako dnes) | odmietnutý (ako dnes) | **`:unreadable` + `UNREADABLE_REASON`** (dnes ticho) | ako dnes |
| objekt so zlým `project_names` alebo `{}` **bez** dobrej `.bak` | **ako dnes** (mapa `{}`, ostatné kľúče zo súboru) | áno — samooprava (ako dnes) | `:ok` | dostane zlý primár (ako dnes) |
| zámok / brána / čítanie / blok zlyhá | — | nie | `:failed` + `FAILED_REASON` | nedotknutá |
| zlyhá samotný zápis (`JsonFileStore.write`, napr. finálne premenovanie) — **(§15 A7)** | — | nie | `:failed` | primár nezmenený (atómová výmena), **`.bak` už môže obsahovať kópiu doterajšieho primára** (vlastnosť primitíva, R-11) |

**(§15 A1)** Degradovaný stav + názov, ktorý čaká na prenos z kľúča sedenia na cestu (prvé uloženie počas poškodenia): názov platí **len do zatvorenia SketchUpu**
(most v pamäti) — `name_pending?` = true, hlásenie R-A7 a stav hlavičky R-B4; po oprave súboru sa prenos zopakuje sám (R-A5).

Obnova (návod v hlásení) — **(§16 B1) premenovať, nie zmazať:** poškodený `vepo_settings.json` premenovať (napr. na `vepo_settings.poskodeny.json` — ostane na ručnú obnovu, plugin ho nečíta)
→ číta sa `.bak`, zápisy povolené (riadok 2). **Dôsledok (sonda H7d L1):** `.bak` je **presne o jeden zápis** za posledným dobrým primárom — stratí sa posledná zmena pred poškodením
(jeden zápis: názov jednej zákazky, 18 + 36 alebo posledný priečinok exportu); viac len vtedy, keď cez poškodený súbor medzitým zapisoval plugin bez brány (H7d L2).

### R-A3 · Čítanie

- **`read`** (lenivé, nikdy nevyhodí; nahrádza `vepo_settings`): `{}` ak `!JsonFileStore.available?(path)`; inak `JsonFileStore.read_valid(path, shape: shape_check)`; pri
  **`InvalidShape`** dnešná cesta `JsonFileStore.read(path)`; nie-objekt → `{}`; iná výnimka → `{}`. S dobrou zálohou záloha, bez nej **dnešné správanie** (S12 stĺpec „lenient").
- **`read_for_write`** (len pod zámkom v `update`) = **dnešné** `vepo_settings_for_write` (`read`, nie-objekt → `raise NotObject`); degradáciu rieši brána pred ním.
- `project_names` = `read['project_names']` ak objekt, inak `{}` · `merge_18_36` = `read['merge_18_36'] != false` · `last_dir` = `read['last_dir']` (surová hodnota ako dnes).

### R-A4 · Brána a jediné dvere zápisu

- **`write_gate → [state, reason]`**, `state ∈ :ok | :degraded`: `reload!(path)` **a `reload!("#{path}.bak")`** (§15 A3 — cache `….bak|nofallback` z `read_valid`) → `JsonFileStore.degraded?(path, shape: shape_check)` → `[:degraded, format(DEGRADED_REASON, path)]`, inak `[:ok, '']`.
  Disk, nie cache; výnimky **nechytá** (volajúci = `:failed`, fail-closed); nezapisuje, neloguje (vzor H9 R15).
- **`update { |fresh| attrs | nil } → [status, reason]`**, `status ∈ :ok | :unchanged | :blocked | :unreadable | :failed` — **jediné** `JsonFileStore.write(` v module:
  ```
  phase = 'lock'
  Materials.with_catalog_lock do
    phase = 'gate';  state, why = write_gate
    next note_block([:blocked, why]) unless state == :ok
    phase = 'read';  fresh = read_for_write   # rescue JSON::ParserError, NotObject -> note_block([:unreadable, …]) — len v tejto fáze
    phase = 'block'; attrs = yield(fresh); next note_block([:unchanged, '']) if attrs.nil?
    phase = 'write'; JsonFileStore.write(path, fresh.merge(attrs), shape_check)   # tretí parameter POZIČNE (pasca Ruby 3, H9 S13)
    note_block([:ok, ''])
  end
  rescue StandardError => e  ->  Engine.log_error(e, "ExportSettings.update(#{phase})"); [:failed, FAILED_REASON]
  ```
  Poradie zámok → brána → strikné čítanie → blok → zápis je záväzné. I/O (EACCES, zdieľanie) vo fáze `read` = `:failed`, nie `:unreadable`.
- **`note_block`:** jeden riadok logu „export settings: zápis odmietnutý — <reason>" **len pri zmene** (`@last_block`; `:ok`/`:unchanged` nuluje). **(§15 A5)** Samotný `note_block` nestačí —
  fallback log `JsonFileStore.read_primary_or_backup` vzniká pri každom novom parsovaní nečitateľného primára (brána ho invaliduje); počet pokusov preto obmedzuje R-A5 (adopt sa opakuje
  len po zmene súborov). **Primitívum `JsonFileStore` sa nemení** (konzumenti `abs_rules`, `hardware_rules`, `supplier_settings`, `materials`, `hardware_sets`, `hardware_catalog`,
  `hardware_taxonomy`, `appliance_catalog`, `dim_series`, `templates`, `updater`, `usage_stats`, `sitemap_cache`, kontroly hrán/kresby/smeru — bez zmeny správania a logov).
- **`save(attrs)`** → `update { attrs }`; kľúč `project_names` (porovnanie `to_s`, review #248) → log + `[:failed, FAILED_REASON]` bez zápisu.
- **`written?(status)`** ⇔ `status == :ok || status == :unchanged` — jediný prevod na „zápis prebehol".
- **Nikdy pravdivosť:** pole je v Ruby vždy pravdivé (H9 F4, H10 P6) — volajúci rozkladá `status, reason = …` a rozhoduje `case`/`==`/`written?` (guard T-A9).

### R-A5 · Názov zákazky a nastavenia

- **Presun bez zmeny správania:** normalizácia cesty, kľúč sedenia (`doc_token`), most `SESSION_KEY_BRIDGE` (spotreba, `equal?`, strop), `project_key`, `effective_project_name`, `default_project_name`,
  `project_name` (adopt, predzámkový fallback), strop 120, mazanie prázdneho/predvoleného.
- **`adopt_session_name`:** most sa zahadzuje **len** pri `written?(status)`; pri `:blocked`/`:unreadable`/`:failed` ostáva a názov ide z fallbacku (mapa z `read` — v degradovanom stave zo zálohy).
  **(§15 A5) Obmedzenie pokusov:** po neúspešnom adopte si modul zapamätá `JsonFileStore.file_signature(path)` (verejná funkcia, primitívum sa nemení) pod kľúčom `[project_key, aliasy]`
  (konštanta `ADOPT_RETRY`, strop 32, bez odkazu na model; zmaže sa pri úspechu a v `forget_session_key`); ďalší pokus (zámok, brána, invalidácia cache) až keď sa podpis zmení —
  oprava/premenovanie súboru, zápis inej inštancie. **(§16 B4) Podpis = obsahová identita** `[SHA1(bajty primára) | '-', SHA1(bajty .bak) | '-']` (nie `file_signature` — mtime + veľkosť
  nerozozná opravu s rovnakou veľkosťou a časom, sonda H7d L4); **`refresh` celé `ADOPT_RETRY` vyprázdni**; kľúč = `[project_key, aliasy.dup.sort.freeze].freeze` (zmrazená kópia, §16 B6). Dovtedy `project_name` vráti názov z fallbacku **bez** zámku (sonda H7c: 100 čítaní → 2 fallback logy namiesto 100).
- **(§15 A1) `name_pending?(model)`** (čistá, bez zápisu): `project_key` je cesta ∧ `read`-mapa pod cestou nemá neprázdny názov ∧ niektorý alias (`session_keys_for`) ho má — názov žije
  len pod kľúčom sedenia a mostom v pamäti, po zatvorení SketchUpu sa stratí (sonda H7c A1: bez opravy po znovuotvorení „A", po odstránení primára v pôvodnom okne prenos prebehne sám; §16 B1: premenovaním, nie zmazaním).
- **`save_project_name(model, name) → [status, reason]`** (dnes String): prázdny `project_key` → `[:failed, FAILED_REASON]` bez zápisu; inak dnešné telo; most: `stored && session_key?(key)` → `remember`
  (ako dnes) · `elsif written?(status)` → `forget`. Platný názov číta volajúci cez `project_name(model)`.
- **`save_merge_18_36(value)`** → `save('merge_18_36' => value == true)` · **`save_last_dir(dir)`** → `save('last_dir' => dir)`; exporty jeho výsledok **ignorujú** (D5, log v `update`).
- **`refresh`** = `reload!(path)` **a** `reload!("#{path}.bak")` → `true`, `rescue` → `false` (S14); exporty ho volajú tam, kde dnes `refresh_vepo_settings`.
- **`document_cleanups`** (`doc_key.rb:176-180`): `ExportSettings.forget_session_key(model) if defined?(ExportSettings)`; log kontext bez zmeny.

### R-A6 · Volajúci po presune

- **Exporty** (`production_core.rb`): `refresh_vepo_settings` → `ExportSettings.refresh` · `project_name(model)` → `ExportSettings.project_name(model)` · `merge_18_36` → `ExportSettings.merge_18_36` ·
  `last_dir` čítanie → `ExportSettings.last_dir` · `save_vepo_settings('last_dir' => …)` → `ExportSettings.save_last_dir(…)` (po 4×). Poradie krokov a texty bez zmeny (T0c).
- **Okno:** payload `studio_dialog.rb:1664-1666` a echo `:667-669` → `ExportSettings` (kľúče a poradie `vepo` bez zmeny — T0d).
- **Testy:** stuby exportov prejdú na `ExportSettings` (`refresh`, `last_dir`, `save_last_dir`, `project_name`, `merge_18_36`) — `with_stubs` musí poznať cieľový modul (alias neexistujúcej metódy
  na `ProductionCore` = `NameError`); `test_st1a_studio.rb`, `test_st1a_core.rb` (volania aj textové guardy nad novým súborom); `test_doc_key.rb:198`; **`su_runner.rb`** (S19; `saved == 'SU TEST PROJEKT'`
  → stav `:ok` + `project_name`).

### R-A7 · Hlásenie v okne (`StudioDialog#do_set_vepo_opts`, H7a)

- Brány bez zmeny poradia (generácia → `DocKey.foreign?` tolerantne). **Zastaraná generácia s kľúčom `project`** → červené „Okno sa medzitým prepočítalo — názov zákazky sa neuložil, zadaj ho znova." (D6); bez `project` dnešná veta.
- **`project`:** `status, why = ExportSettings.save_project_name(…)`; `name = ExportSettings.project_name(model)`; `case status` — `:ok, :unchanged` → „Názov zákazky: <name> · platí pre VEPO, kovanie,
  rozpočet aj ponuku" · `:blocked, :unreadable` → **červené** „Názov zákazky sa neuložil: <why>" · inak **červené** „Názov zákazky sa nepodarilo uložiť — skús znova" (O8).
- **`merge`:** `:ok` → „18 + 36 spolu: zapnuté|vypnuté · platí pre VEPO export" · `:blocked, :unreadable` → červené „Nastavenie 18 + 36 sa neuložilo: <why>" · inak červené „Nastavenie 18 + 36 sa nepodarilo uložiť — skús znova".
- Vety spojené „. ", koniec „."; červená, ak ktorákoľvek zlyhala. **`push_vepo_bar(model)` vždy** (aj pri zlyhaní — pole/hlavička a checkbox ukážu uloženú pravdu, O8). „Nič sa nezmenilo." ako dnes.
  Úspech nedvíha generáciu (guard ostáva).
- **Dôvody:** **(§16 B1)** `DEGRADED_REASON` „nastavenia exportu sú poškodené — číta sa záloha, zápisy sú vypnuté (oprav súbor %s alebo ho premenuj, napr. na vepo_settings.poskodeny.json —
  plugin potom pokračuje zo zálohy; stratí sa posledná zmena uložená pred poškodením)" · `UNREADABLE_REASON` „súbor nastavení exportu sa nedá prečítať (oprav súbor %s alebo ho premenuj
  aj s jeho .bak — plugin potom začne s predvolenými nastaveniami a bez uložených názvov zákaziek)" · `FAILED_REASON` „zápis sa nepodaril (súbor je zamknutý alebo disk nedostupný)".
- Degradovaný stav sa **inde nehlási** (D5, Q1): hlavička ukazuje názov, pod ktorým exporty naozaj odídu. **Výnimka (§15 A1) — čakajúci názov:** keď `name_pending?`, všetky 4 exporty
  pripoja na koniec záverečnej vety (farba bez zmeny) `ProductionCore.pending_name_note(model)` = „ · pozor: názov zákazky sa zatiaľ neuložil k súboru (nastavenia exportu sú poškodené) —
  premenuj poškodený súbor <path> (napr. na vepo_settings.poskodeny.json), plugin potom pokračuje zo zálohy bez poslednej zmeny pred poškodením a názov sa uloží sám;
  inak sa po zatvorení SketchUpu stratí" (§16 B1). Trvalý stav v hlavičke prináša H7b (R-B4); s vetou `default_name_note` (R-B3) sa vylučuje.

### R-A8 · Dve inštancie SketchUpu (zdieľaný `%APPDATA%`)

Zámok a čítanie nanovo (1b-6c) ostávajú, brána beží **pod tým istým zámkom nad diskom**: (a) zápisy do rôznych kľúčov sa nestratia; (b) poškodenie primára druhou inštanciou po našom čítaní →
`:blocked`, bajty nedotknuté; (c) odstránenie (premenovanie) primára → obnova z `.bak`, `:ok`; (d) zámok nedostupný → `:failed`, červené. **Starší plugin** bránu nemá (formát je ten istý) → v STAV, smoke a reporte:
aktualizovať **obe PC** a po aktualizácii zavrieť všetky okná SketchUpu (vzor H9 R9, H10 R1.9).

### R-A9 · Dokumentácia H7a (na mieste)

`outputs.md`: **nový odsek `### export_settings.rb`** pri `supplier_settings.rb` — **presun** textov `project_names` a „JEDNY dvere" z odseku `production_core.rb` (`:462-505`) + predikát, matica, brána,
stavy, `refresh`, hlásenia; odsek `production_core.rb` (`:182`) bez nastavení, s odkazom. `ARCHITEKTURA.md` riadok core `… supplier_settings · export_settings …` (guard `test_docs_navigacia.rb`).
`model-a-identita.md:88, :245` · `materials.md:500` · STANDARD §11.5 posledná odrážka (aj nastavenia exportu). **Grep zoznamov:** „šiesty globálny JSON store", „šiestich zapisovateľov",
„Nechránené (zvyšky)" v R-37, `ProductionCore.project_name` v docs a komentároch.

### R-B1 · Payload a echo `vepo` (H7b)

`vepo` = dnešné 3 kľúče v dnešnom poradí + na koniec `source` (`ExportSettings.name_source(model, project)`), `file` (`model.title`, pri neuloženom prázdne), `export_names` =
`ProductionCore.export_file_names(project, Time.now)` → `{ vepo_dir, hw_csv, budget_xlsx, offer_xlsx }`. Payload aj echo skladá **jedna** funkcia (napr. `ProductionCore.vepo_payload(model)`).
**`name_source`** (čistá): `name == default_project_name(model)` → (`model.path` prázdna ? `'default'` : `'file'`), inak `'set'` (uložený názov sa predvolenému nikdy nerovná — S5). Klient nič neodvodzuje.
**(§15 A1)** + `pending` (`ExportSettings.name_pending?(model)`) a `notice` (veta skladaná serverom, `''` mimo stavu): „Názov zákazky „<názov>" platí len do zatvorenia SketchUpu — nastavenia exportu
sú poškodené (súbor <path>). Premenuj ho (napr. na vepo_settings.poskodeny.json) — plugin potom pokračuje zo zálohy, stratí sa posledná zmena uložená pred poškodením, a názov sa k súboru
uloží sám; inak sa po zatvorení stratí a exporty sa pomenujú podľa súboru." (§16 B1)

### R-B2 · Skladač mien (`ProductionCore`)

`hw_csv_file_name(project)` = presne výraz `:2139`, volá ho `do_hw_csv`. `export_file_names(project, now)` volá **výhradne** `VepoExport.project_slug`, `hw_csv_file_name`, `BudgetXlsx.file_name`,
`CpXlsx.file_name`. T0a/T0c bez regenerácie + test parity.

### R-B3 · Veta po exporte s predvoleným názvom (O4)

`ProductionCore.default_name_note(model, project)` → `' · pomenované predvoleným názvom „projekt" — názov zákazky zadáš v hlavičke Štúdia'` práve pri `name_source == 'default'`, inak `''`.
Na koniec záverečnej vety po zápise súboru: VEPO `:2068` a `:2073`, CSV `:2150`, rozpočet `:3632`, ponuka `:3718`. **Farba sa nemení**, neblokuje, s tým istým `project`, ktorým sa súbor pomenoval.

### R-B4 · Hlavička Štúdia (O1 A, O3, O9)

- `renderHead` (`studio.js:1240`): `h2` + `sechint` bez zmeny + `<span class="jobhd">` = `<span class="joblbl">Zákazka</span>` · `<button type="button" class="jobname src-<source>" id="jobName"
  title="<tooltip>" aria-label="Upraviť názov zákazky — <názov>">` [pri `default` `<i class="jdot" aria-hidden="true">`] `<span class="jobtext">…</span>` + `pencil` zo spritu `</button>` ·
  `file` → `<span class="jobsrc">podľa súboru</span>`, `default` → `<span class="jobsrc warn">zadaj názov</span>` · `<span class="jobver">· v<verzia></span>`. `#stModel` **zaniká** (aj `:1130`).
- **Zadaný** tučne · **podľa súboru** tučne + sivý dovetok · **predvolený** bodka, kurzíva, `--nx-warnchip-fg`. Výška hlavičky bez zmeny (jeden riadok, `.jobname` `max-width` + výpustka).
- **(§15 A1, Q2) Čakajúci názov** (`vepo.pending`): ako zadaný + jantárová bodka + `<span class="jobsrc warn">neuložené k súboru</span>`, tooltip = `vepo.notice` (serverový text). Bodky na
  exportoch **nie** (exporty sa teraz pomenujú správne; varovanie nesie veta po exporte R-A7). Bez nového ovládacieho prvku, bez zmeny dátového tvaru súboru.
- **Tooltip** (texty mockupu; JS z `vepo.source`, `vepo.file`, `ST.version`): `default` „Exporty sa teraz pomenujú „projekt" — model ešte nie je uložený. Klikni a zadaj názov zákazky." ·
  `file` „Názov sa berie z mena súboru <file>.skp. Klikni a zadaj vlastný — súbor sa nepremenuje. · v<ver>" · `set` „Názov zákazky pre VEPO, kovanie, rozpočet aj ponuku. " + (uložený ?
  „Súbor: <file>.skp. Prázdne pole vráti meno súboru." : „Model ešte nie je uložený — názov sa pri prvom uložení prenesie na súbor. Prázdne pole vráti „projekt".") + „ · v<ver>".
- Vo **všetkých 14 sekciách**. CSS len existujúce tokeny (`--nx-warn`, `--nx-warn-fg`, `--nx-warnchip-fg`, `--nx-ink-faint`, `--nx-select`), bodka 50 % (povolená výnimka), žiadny hex (`test_ui01_paleta.rb`).

### R-B5 · Editor na mieste (vzor `bridge.js:72-128`)

- Klik/Enter/medzerník na `#jobName` → `<input id="jobEdit" maxlength="120" aria-label="Názov zákazky" title="Enter uloží, Escape zruší, prázdne pole vráti automatický názov">` s hodnotou =
  zobrazený názov, `focus` + `select`; **zachytí `ST.model_guid`** (R-02).
- **Enter alebo blur** → editor sa **hneď zavrie** a hlavička **optimisticky** ukáže odoslaný text, ktorý sa zapíše do `VEPO_EXPECT` (§16 B2 — pôvodne „doterajší názov, kým nepríde echo"); echo je autorita; `value.trim()` == zobrazený názov → **nič**; inak pri zhode zachyteného guidu s `ST.model_guid` →
  `sendVepoOpts({ project })` so **zachyteným** guidom (jediná cesta zápisu — guard `test_st1a_studio.rb:917`). Stráž Enter + blur.
- **Escape** → zruší; obsluha na **inpute** s `preventDefault` + `stopPropagation` (dokumentová reťaz `nx_esc.js` ani menu VEPO nesmú zavrieť ďalšiu vrstvu).
- **Plný push počas písania:** rovnaký `model_guid` → uzol editora sa **neprepíše** (hodnota, fokus, kurzor — vzor FIX 4 `keepEditor`), prekreslí sa len zvyšok; iný → editor zmizne **bez odoslania**
  (vzor `dropCabRename`). Klik v navigácii = blur = commit.
- ~~**(§15 A2) Potvrdenie zápisu a odklad exportu** (`seq`, `NX.vepoOptsDone`, `vepoSaving`, odložený export)~~ — **nahradené §16 B2 (R-B5b).**

### R-B5b · (§16 B2) Export overí očakávaný názov a 18 + 36 (bezstavovo)

- **Klient:** každé zo 4 exportných volaní (VEPO cez relay panela, `hw_csv_export`, `budget_xlsx`, `cp_xlsx`) pridá do svojho JSON `expect: { project: <text, ktorý používateľ vidí>,
  merge: <stav #mergeChk> }`. Čo používateľ vidí: po commite editora sa v hlavičke **hneď** ukáže odoslaný text (optimisticky; pri prázdnom poli `vepo.default_project`), echo
  `setVepoBar` ho prepíše uloženou pravdou (pri zlyhaní pôvodným názvom — O8). Hodnota je v jednej klientskej premennej `VEPO_EXPECT` (nastaví ju payload/echo, commit editora
  a zmena `#mergeChk`), nie v DOM.
- **Server** (`do_export`, `do_hw_csv`, `do_budget_xlsx`, `do_cp_xlsx`): po bránach generácie a `flush_blocked`, po `ExportSettings.refresh`, **pred** zberom a výberom súboru: ak `data`
  má `expect` → `ExportSettings.expect_mismatch(model, data['expect'], merge: <len VEPO>)` → `nil` alebo veta. Názov: `expect.project` sa normalizuje **ako pri zápise**
  (`to_s.strip[0, 120].strip`, prázdne → `default_project_name(model)`) a porovná s `project_name(model)`. **18 + 36 sa porovnáva len vo VEPO** (inde výstup nemení — zlyhaný zápis
  prepínača nesmie blokovať XLSX). Nesúlad → export sa **nespustí**, červené „Názov zákazky sa neuložil (platí „<uložený>") — export sa nespustil, skontroluj názov a klikni znova." /
  „Nastavenie 18 + 36 sa neuložilo (platí: zapnuté|vypnuté) — export sa nespustil, skontroluj nastavenie a klikni znova."; echo hlavičky dá R-B9. **Nikdy automatické pokračovanie,
  žiadny čakací stav ani timeout.** Bez kľúča `expect` (starý klient) = dnešné správanie.
- **P0-HF bez zmeny:** `expect` ide len so **skutočným** exportným volaním — prvý klik v neozbrojenom stave nič neposiela (len ozbrojí), ozbrojený stav sa nesúladom nezruší (čísla sa
  nezmenili), ďalší klik pošle `expect` znova.
- **Poradie callbackov (overenie §16):** prehliadač pri kliku vystrelí `mousedown` → `blur` editora (commit → `studio_set_vepo_opts`) → `click` (export). Projekt od ŠT-1a stavia na tom,
  že Ruby vybaví callbacky jedného okna v poradí volania (review #193 P2 „change tesne pred click", `studio_dialog.rb:627-632`, test `test_st1a_studio.rb:857-866`); dokumentácia
  SketchUpu callbacky opisuje len ako asynchrónne — **poradie je NEOVERENÉ oficiálne aj sondou v SketchUpe** (MCP bridge offline). **Návrh od poradia nezávisí:** pri obrátenom poradí
  export uvidí starú uloženú hodnotu ≠ `expect` → odmietnutie a klik znova; export pod neuloženým názvom nevznikne v žiadnom poradí. Bežný prípad (jeden klik) overí smoke bod 3.

### R-B6 · Echo `NX.setVepoBar`

Uloží `ST.vepo`, prekreslí hlavičku (ak nie je otvorený editor), obnoví bodku a tooltip 4 exportov **bez straty fokusu** v `#bomSearch` a **bez zatvorenia** rohového nastavenia VEPO (technika na
implementátorovi, test); `#mergeChk` ako dnes.

### R-B7 · Pole PROJEKT zmizne (O2)

Preč `<label class="prjbox">` (`studio.js:1333-1336`), `change` `#prjInput` (`:2119`), Enter-blur (`:2130`), CSS `.prjbox*` (`studio.html:164-174`), vetva `#prjInput` v `setVepoBar`.
Lišta: `[Dielce · Platne · ABS] · [hľadanie] · ⟶ · [VEPO export ▸] · [Stĺpce] · [Obnoviť]`.

### R-B8 · Štyri exporty (O3, O4, O7)

Jedna globálna pomocná funkcia v `studio.js` (napr. `nxJobExport(kind)` → `{ dot, tip }` z `ST.vepo`) pre `vepoBtnHtml`, `buyRenderTools` a `budget.js` (XLSX, ponuka; `typeof`-guard).
Bodka `<i class="xdot" aria-hidden="true">` **len pri `default`**. Tooltip = dnešný `title` + meno zo **servera**: VEPO „ Vytvorí v ňom priečinok <vepo_dir>\" · CSV/XLSX/ponuka „ Súbor <meno>";
pri `default` + „ · názov zákazky zadáš hore v hlavičke". Ozbrojený stav P0-HF (`budArmed`) a `data-bkey` bez zmeny.

### R-B9 · Echo po exporte (D7)

`StudioDialog#do_export`, `#do_hw_csv`, `#do_budget_xlsx`, `#do_cp_xlsx` po návrate (aj pri odmietnutí) zavolajú `push_vepo_bar` — hlavička a bodky sa zladia s názvom z čerstvého súboru; generácia sa nemení.

### R-B10 · Texty (O9)

„projekt" → „zákazka" v texte okna (štítok, tooltipy; Ruby už H7a). Slovo `projekt` v menách súborov ostáva. UI_DIZAJN §1 (bez žargónu, „v0.17.x", tučné len `<b>`).

### R-B11 · Goldeny H14 (fixtúry sa NEREGENERUJÚ)

`test_h14_golden.js` normalizuje **presne štyri fragmenty** na oboch stranách: `secmodel` ↔ `jobhd` (→ `«HLAVICKA»`), `<label class="prjbox">…</label>` (→ prázdno), `title` + `xdot` `#vepoBtn`
(→ `«VEPO»`) a **(§15 A4)** `title` + `xdot` `#hwCsvBtn` (→ `«CSV»`) — nie celú lištu; overí **presný počet** nahradení (sonda: `secmodel` g1 15×; `prjbox` g2 4×, g4 2×, g8 2×; `vepoBtn` g2 4×,
g4 2×, g8 2×; `hwCsvBtn` g2 1×; tlačidlá Rozpočtu a Ponuky v goldenoch nie sú) a bajty mimo nich. `test_h14_studio_sekcie.rb` porovná `vepo` zúžené na 3 pôvodné kľúče; nové pripne T-B7.

### R-B12 · Dokumentácia H7b

`UI_DIZAJN.md` §5.15 (`:1535-1537`, „názov projektu: input v Štúdiu → Kusovník" → editor v hlavičke) · `ui-lifecycle.md` odsek okna ŠTÚDIO (hlavička, editor, echo, `vepo`) a Kusovník (`:1410-1415`),
zmienka v Nákupe, Rozpočte a Ponuke · `outputs.md` `production_core.rb` (`export_file_names`, `hw_csv_file_name`, `default_name_note`, `vepo_payload`) · **`UI20_KONTRAKT.md` Š5** (revízia H7) a
**`mockup_studio.html`** (pravidlo troch miest).

---

## 7 · Testy a DoD

**H7a — `tests/pure/test_h7a_export_settings.rb`** (vzor `test_r37_tvar_suborov.rb`, sandbox `Materials.test_dir_override`) + `tests/fixtures/h7_golden/` (R0).

- **T-A1 Matica R-A2** — každý riadok: `project_name`/`merge_18_36`/`last_dir`, stav + dôvod **každej** zápisovej funkcie (vrátane adopt cez `project_name`), bajty primára **aj `.bak`** pred/po.
  Zlý tvar ≥ 7 vstupov (`[]`, `null`, `"x"`, `42`, `{}`, `{"project_names":[]}`, `{"project_names":"x"}`), s dobrou `.bak` aj bez nej.
- **T-A2 Predikát:** zdravé tvary (`{"merge_18_36":false}`, `{"project_names":{}}`, `{"last_dir":"x"}`) = true; S12 pripnuté.
- **T-A3 Brána:** cache drží starý stav, disk poškodený → `:degraded`; výnimka predikátu → `:failed`, súbory nedotknuté; `JsonFileStore.write` dostane `shape_check`.
- **T-A4 Fázy:** zámok → `:failed` (log `update(lock)`); EACCES pri čítaní → `:failed`; `ParserError`/`NotObject` → `:unreadable`; blok vyhodí → `:failed`; blok `nil` → `:unchanged` bez zápisu a bez otočenia `.bak`.
  **(§15 A7)** zlyhanie finálneho premenovania (stub `File.rename` na cieľ = primár) → `:failed`, primár bajtovo nezmenený, `.bak` == doterajší primár (pripnutá vlastnosť; sonda H7c potvrdila na maine).
- **T-A5 Most a adopt:** testy 1b-6a/1b-6c/R-02b prenesené 1:1 + adopt pri `:blocked` most nezahodí a názov ide zo zálohy; po obnove adopt zapíše a most spotrebuje.
- **T-A6 Dve inštancie (R-A8 a–d).** **T-A7 `refresh`** po rotácii `.bak` druhou inštanciou (do 1 s) vidí novú zálohu. **T-A7b (§15 A3)** primár `[]`, `.bak` „Old/false" prečítaná,
  výmena `.bak` na „New/true" do 1 s, **bez** exportného `refresh` → odmietnutý zápis (`save_merge_18_36`) → echo (`project_name`, `merge_18_36`) = „New/true" (sonda H7c: bez invalidácie „Old/false").
- **T-A8 Okno headless** (`StudioDialog.send(:do_set_vepo_opts, …)`, stuby vzoru sondy S6): `:ok`/`:blocked`/`:unreadable`/`:failed` → presný text a farba, **echo vždy**, zlyhanie nikdy zeleno;
  18 + 36 rovnako; zastaraná generácia s `project` → nová veta, bez zápisu; úspech nedvíha generáciu.
- **T-A9 Guardy:** `ProductionCore` nereaguje na presunuté metódy a nemá ich konštanty · mimo `export_settings.rb` žiadne `vepo_settings`/`VEPO_SETTINGS_FILE` v `ui/` a `core/` · v module **jediné**
  `JsonFileStore.write(` (v `update`, tretí pozičný `shape_check`) · `save`/`update_project_names` volajú `update` · `update` volá `write_gate` pred `read_for_write` pod `with_catalog_lock` ·
  `read` volá `read_valid` · žiadne `if|unless|&&|\|\||?` priamo nad zápisovými funkciami `ExportSettings` v `ui/` a `core/` · `doc_key.rb` a `main.rb`/`helper.rb` (R-A1, R-A5).
- **T-A10 Log (§15 A5):** **syntakticky poškodený** primár + dobrá `.bak` s názvom pod kľúčom sedenia, model „uložený" (adopt potrebný): 100× `project_name` → najviac **1** riadok `note_block`
  a najviac **2** fallback riadky `JsonFileStore` (prvé čítanie + jeden pokus adoptu), zámok vzatý najviac raz; po zmene obsahu súborov (premenovaný primár) jeden nový pokus, ktorý prejde. Aj variant `[]`. **(§16 B4)** oprava obsahom **rovnakej veľkosti s vráteným mtime** (`File.utime`) → nový pokus;
  `refresh` vyprázdni `ADOPT_RETRY`; **(§16 B6)** mutácia poľa aliasov po zapamätaní nezmení uložený kľúč.
- **T-A11 Čakajúci názov (§15 A1):** neuložený model s názvom → poškodenie primára (záloha nesie názov pod kľúčom sedenia) → „uloženie" (cesta) → `project_name` = názov, `name_pending?` = true,
  4 exporty pripoja `pending_name_note`, `do_set_vepo_opts` premenovanie → červené `:blocked` · **znovuotvorenie pred opravou** (nový objekt modelu, prázdny most) → meno súboru (pripnutá priznaná strata,
  zhodná s vetou) · **oprava v pôvodnom okne** (premenovaný primár, §16 B1) → ďalšie čítanie prenos zapíše, `name_pending?` = false, znovuotvorenie → názov ostane. Zdravý súbor → `name_pending?` nikdy true.
- R0 zelené **bez regenerácie**; celá headless sada + všetky JS sady + encoding guard.

**Mutácie H7a (≥ 12, každá zhodí test):** M1 `update` bez `write_gate` · M2 brána bez tvaru · M3 zápis bez `shape_check` · M4–M6 predikát bez `is_a?(Hash)` / bez `project_names` / bez `!empty?` ·
M7 `read` bez `read_valid` · M8 `read` bez fallbacku pri `InvalidShape` (S11 by stratil 18 + 36 vypnuté) · M9 okno rozhoduje pravdivosťou · M10 echo len pri úspechu · M11 `refresh` bez `.bak` ·
M12 adopt zahodí most pri `:blocked` · M13 `:unreadable` → `:failed` · M14 `save` pustí `project_names` · M15 log vždy · M16 `doc_token` bez `rescue` ·
**(§15)** M17 brána bez invalidácie `.bak` (T-A7b) · M18 adopt bez `ADOPT_RETRY` (T-A10) · M19 `ADOPT_RETRY` sa nezmaže po zmene podpisu (T-A10, T-A11 oprava) · **(§16)** M22 podpis cez `file_signature` (T-A10 rovnaká veľkosť a čas) · M23 `refresh` bez vyprázdnenia `ADOPT_RETRY` · M24 kľúč retry drží pôvodné pole aliasov · M20 `name_pending?` vždy false (T-A11) ·
M21 export bez `pending_name_note` (T-A11).

**H7b — `tests/js/test_h7b_hlavicka.js` a `tests/pure/test_h7b_nazov_zakazky.rb`.** **(§15 A6) Interakčné testy editora (T-B2–T-B4, T-B11) bežia nad `tests/js/minidom.js`**
(skutočné parsovanie HTML, bublanie, `activeElement`; repo nemá `package.json` ani `node_modules`, `jsdom` nie je k dispozícii — nič sa neinštaluje), rozšíreným **opt-in** režimom
`minidom.faithful(true)` (ostatných ~50 sád sa nemení): `replaceChild`, `select()`, handlery `on<typ>` v `dispatch`, `focus()` presunie fokus a na predošlom prvku vystrelí `blur`,
pomocník `userClick(el)` = `mousedown` → presun fokusu (blur aktívneho) → `click`, `userKey(el, key)`. **(§16 B8)** `minidom.reset()` vráti režim a `activeElement` do predvoleného stavu — každý test ho volá vo `finally`; guard: po sade je režim vypnutý. Statické značky (T-B1, T-B5–T-B7) smú ísť cez `h14_harness.js`.

- **T-B1** tri podoby hlavičky (markup, bodka len `default`, dovetky, `aria-label`, tooltipy R-B4) v 14 sekciách; `#stModel` neexistuje.
- **T-B2** editor: Enter → presne jedno `studio_set_vepo_opts` so **zachyteným** guidom · blur → odošle · Enter + blur → jedno · Escape → nič a udalosť ďalej nejde · nezmenená hodnota → nič · `maxlength` 120 · iný doc → nič.
- **T-B3** push počas písania (rovnaký doc: uzol, hodnota a fokus ostanú; iný doc: editor zmizne bez odoslania); `setVepoBar` počas písania input nezmení.
- **T-B4** echo obnoví hlavičku a 4 exporty; fokus v `#bomSearch` a otvorené menu VEPO ostanú; `#mergeChk` ako dnes.
- **T-B5** 4 tlačidlá: bodka len `default`; tooltip obsahuje **presne** serverový reťazec (payload s menami, ktoré sa zo slugu odvodiť nedajú); P0-HF a `data-bkey` bez zmeny.
- **T-B6** `#prjInput`/`.prjbox` v lište ani CSS nie sú; poradie R-B7.
- **T-B7 (Ruby)** payload aj echo: 3 pôvodné kľúče v poradí + `source`/`file`/`export_names`; `source` pre neuložený bez názvu, uložený bez názvu, zadaný (aj neuložený); `export_names` == výstupy 4 funkcií.
- **T-B8 (Ruby)** veta po exporte pri `default` na konci, farba bez zmeny; `file`/`set` bez vety (stuby vzoru `test_p0hf_brany.rb`); T0c bez regenerácie.
- **T-B9 (Ruby)** 4 exportné obaly `StudioDialog` volajú `push_vepo_bar` (aj pri odmietnutí), generácia bez zmeny.
- **T-B11 (§16 B2) Export s `expect`** — Ruby (4 exporty, stuby vzoru `test_p0hf_brany.rb`, skutočný sandboxový súbor): zápis názvu zlyhá (stub zámku) → export s `expect` = napísaný
  názov **odmietnutý** pred výberom súboru (picker sa neotvorí, žiadny súbor), červená veta; zápis uspeje → export prejde a **mená súborov bajtovo = T0c**; prekrížené: názov uložený
  + 18 + 36 neuložené → VEPO odmietnutý, CSV/XLSX prejdú; 18 + 36 uložené + názov nie → všetky 4 odmietnuté; obrátené poradie (export pred zápisom) → odmietnutie, druhý pokus po
  zápise prejde; bez `expect` → dnešné správanie. JS (minidom faithful): jeden `userClick` na export z otvoreného editora pošle najprv `studio_set_vepo_opts`, potom export
  s `expect.project` = napísaný text (všetky 4 tlačidlá); P0-HF **neozbrojený** (1. klik bez volania, 2. klik s `expect`) aj **ozbrojený** stav (nesúlad ho nezruší, ďalší klik pošle
  `expect`); po echu zlyhania `expect` = uložený názov.
- **T-B12 (§15 A1)** hlavička pri `vepo.pending`: bodka, „neuložené k súboru", tooltip = `vepo.notice`; exporty bez bodky; payload `pending`/`notice` z T-A11 scenára.
- **T-B10** prepis viazaných testov: `test_st1a_studio.js:290-334`, `test_st1a_studio.rb:724, :974-976` + pravidlo troch miest, `test_stale_obnovit.js:108`; R-B11.

**Mutácie H7b (≥ 8):** bodka aj pri `file` · tooltip zo `slug` v JS · Escape odošle · push s rovnakým docom zruší editor · echo prepíše rozpísaný text · odošle nezmenenú hodnotu · veta aj pri `file` ·
veta prefarbí stav · `#prjInput` ostal · `do_hw_csv` mimo `hw_csv_file_name` · **(§15/§16)** export bez `expect` z nového klienta · `expect` z DOM namiesto `VEPO_EXPECT` · server porovná 18 + 36 aj v XLSX · kontrola `expect` až po výbere súboru ·
iná normalizácia `expect.project` než pri zápise · normalizácia H14 bez `#hwCsvBtn` (počet) · bodka na exportoch pri `pending` · minidom faithful bez resetu medzi testami.

**DoD (každá časť):** testy + mutácie (zoznam a výsledok do PR) · headless + **všetky** JS sady (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) · encoding guard · docs · §11.
**H7a:** in-SU beh (§8). **H7b:** `ui_foto.ps1 -Record` + hárok do reportu (Kusovník, Nákup, Rozpočet, Ponuka, jedna katalógová sekcia).

## 8 · In-SU — nie je brána podľa spúšťačov; H7a jeden beh ako DoD

Zápis ide do `%APPDATA%`, nie do modelu; buildery, observery, undo, geometria ani akcie panela zapisujúce do modelu sa nemenia. H7a mení `su_runner.rb` (ST-1a názov: kľúč, zápis,
`do_set_vepo_opts` bez zdvihu generácie, mazanie; SMOKE 18 + 36: echo, payload) → `scripts\run_su_tests.ps1 -CloseWhenDone` na finálnej hlave, PR uvedie hlavu a výsledok; pád pre H7a = nemergovať.
In-SU pracuje so **skutočným** `%APPDATA%` (kroky po sebe upratujú — zachovať).

## 9 · Riziká

1. **Predikát odmietne zdravý súbor** → „poškodené" a zápisy vypnuté. Ochrana: len kontajnery, `{}` plugin nikdy nezapísal (S13), T-A2, T0b.
2. **Presun zmení kľúč sedenia alebo bajty** → stratené názvy rozpísaných zákaziek. Ochrana: `doc_token` = `model_guid`, T0b, M16.
3. **Pravdivé pole `[status, reason]`** → zlyhanie ako úspech. Ochrana: `case`, T-A9, M9.
4. **Stuby exportov** po presune ticho prestanú zachytávať. Ochrana: R-A6, T0c bez stubu názvu.
5. **Degradovaný stav sa ukáže až pri premenovaní** — hlavička však ukazuje názov, pod ktorým exporty naozaj odídu. Q1.
6. **Starší plugin** na druhom PC/okne bránu nemá (R-A8) — prevádzková podmienka.
7. **Editor vs. plný push** (fokus, dvojité odoslanie, iný dokument) — R-B5, T-B2, T-B3.
8. **Dátum v tooltipe XLSX** je z pushu; po polnoci do ďalšieho pushu nesedí deň (export pomenuje správne); echo po exporte (R-B9) ho obnoví. Priznať v docs.
9. **Normalizácia goldenov H14** môže skryť viac než hlavičku — počet nahradení a bajty mimo (R-B11).
10. Kolízia s H6/H11a/H17 (§5.1).
11. **(§15 A1)** Názov zadaný pred prvým uložením počas poškodeného súboru sa po zatvorení SketchUpu **bez opravy** stratí (dnes by ho zápis prepísal do primára zo zálohy) — priznané
    vetou, stavom hlavičky a testom T-A11; oprava je jeden krok (premenovať súbor — §16 B1; stratí sa posledná zmena pred poškodením), prenos potom prebehne sám.
12. ~~(§15 A2) Odložený export čaká na potvrdenie…~~ **nahradené §16 B2:** export s `expect` je bezstavový — nič nečaká, nesúlad = odmietnutie a klik znova.

## 10 · Smoke checklist pre Michala (po H7b, funkčne)

1. **Uložená zákazka s názvom:** hlavička „Zákazka: <názov> ✎" tučne v každej sekcii; v Kusovníku pole PROJEKT nie je; VEPO, CSV kovania, XLSX rozpočtu a ponuky sa volajú **presne ako pred aktualizáciou**.
2. **Nový neuložený model:** jantárová bodka, „projekt" kurzívou, „zadaj názov"; bodka aj na VEPO, CSV kovania, XLSX rozpočte a Cenovej ponuke; tooltip povie meno. VEPO export → na konci stavu
   „… pomenované predvoleným názvom „projekt" — názov zákazky zadáš v hlavičke Štúdia", farba bez zmeny.
3. Klik na názov → „Test H7" → Enter: hlavička sa zmení, zelené „Názov zákazky: Test H7 · platí pre VEPO, kovanie, rozpočet aj ponuku", bodky zmiznú; Ctrl+S → názov ostane.
   **(§15 A2)** Klik na názov → prepíš → **hneď** klik na „VEPO export" (bez Enter): export prebehne raz a priečinok nesie **nový** názov. (§16 B2: keby sa zápis nepodaril, export sa **nespustí** a okno povie prečo.)
4. Klik → Escape: bez zmeny. Klik → zmaž → Enter: meno súboru so sivým „podľa súboru". Uložená zákazka bez názvu → „podľa súboru", bez bodky.
5. *(voliteľné — ochrana)* Zavri SketchUp, skopíruj bokom `%APPDATA%\NOXUN\Engine\vepo_settings.json` aj `.json.bak`, v Poznámkovom bloku prepíš `vepo_settings.json` na `[]`, spusti SketchUp:
   hlavička ukáže názov zo zálohy; premenovanie → **červené** „Názov zákazky sa neuložil: nastavenia exportu sú poškodené — číta sa záloha…"; premenuj `vepo_settings.json` na `vepo_settings.poskodeny.json` (§16 B1) → premenovanie prejde.
   Na konci vráť skopírované súbory (pri zavretom SketchUpe).
6. Lucia: aktualizovať aj jej PC; po aktualizácii zavrieť všetky okná SketchUpu.

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch (`noxun_engine.rb` + `main.rb`) + **všetky** `?v=` → testy zelené (headless + všetky JS) → odseky na mieste (R-A9 / R-B12) + `ARCHITEKTURA.md` (H7a) → **Grep zoznamov** (R-A9; H7b:
„[Projekt]", `prjInput`, „názov projektu", „zákazka: " v docs a ui20) → **`AUDIT_REGISTER.md` (H7a):** R-38 **✅ dávkou H7a (PR #?)** s rozsahom (zlý tvar/nečitateľný + dobrá záloha = záloha a zápisy
vypnuté; výsledok zápisu sa hlási v okne; cesta → `core/export_settings.rb`), v R-37 „Nechránené (zvyšky)" `vepo_settings.json` preč, riadok tabuľky stavu; **netvrdiť** ochranu hodnôt (N2)
ani bannera (Q1) → STANDARD §11.5 (H7a) → prepis `STAV.md` → odsek navrch „Záznamy dávok" v `KRONIKA.md` (mutácie, počty testov, in-SU hlava) → `PLAN.md` H7 (H7a ✅ + PR; po H7b celý ✅) →
číslo PR samostatným commitom. Implementátor H7a skopíruje package a `AUDIT_H7_raw.md` do `SYSTEM/zdroje/bloky/HARDENING/`.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

- **D1 Modul** `Noxun::Engine::ExportSettings`, `core/export_settings.rb`, odsek v `outputs.md`. **Bez delegátov v `ProductionCore`** (C-07: „okno aj exporty ho budú volať odtiaľ"; delegáty = dve mená
  jednej veci a stuby testov by strážili starú cestu). Cena: mechanický prepis ~6 testov a `su_runner` (R-A6). Mená bez predpony `vepo_`; súbor ostáva `vepo_settings.json`.
- **D2 Predikát** len na kontajneroch vrátane `{}` (S13); hodnoty nie (§14 N2).
- **D3 Zlý tvar bez dobrej zálohy = dnešné správanie** (lenivé čítanie, strikný zápis, samooprava objektu, „zaseknutý" nečitateľný súbor); novinka je len **povedať** `:unreadable`. Samooprava
  à la H9 by menila pravidlo 1b-6c „neprečítateľný súbor zastaví zápis" — mimo R-38.
- **D4 Výsledok `[status, reason]`** pre všetky zápisové funkcie (vzor H9 `write_gate`, H10 `case status`); `save_project_name` už nevracia názov.
- **D5 Kde žije hlásenie:** jadro vracia dôvod (texty dôvodov v `ExportSettings`), **okno Štúdia skladá vetu** (`do_set_vepo_opts`). Zlyhaný `last_dir` po exporte → **len log**.
  **Zmenené (§15 A1):** zlyhaný adopt **nie je len log** — `name_pending?` → veta po exporte (H7a) a stav hlavičky (H7b).
- **D6 Zastaraná generácia s napísaným názvom:** bránu **ponechať** (s editorom nastane len pri skutočnom súbehu — `gen` sa číta pri odoslaní a plný push editor zachová), veta povie, že sa názov
  neuložil. Alternatíva (pre `project` len `DocKey`, bez generácie) — ak audit nájde častejší scenár.
- **D7 Echo hlavičky po každom exporte** (R-B9). **D8 Ruby texty O9 už v H7a** (dnešné „Platí pre všetky exporty" pri 18 + 36 nebolo pravdivé).
- **D9 Goldeny H14 sa neregenerujú** — normalizácia **štyroch** fragmentov s počtom (R-B11, §15 A4). **D10 Rez a poradie commitov** (§2).
- **D11 (§15 A1) Čakajúci názov bez zápisu do modelu a bez nového prvku:** viditeľný stav + návod „premenuj súbor" (§16 B1) + automatický prenos po oprave. Zápis adoptu do degradovaného súboru
  (porušil by R-38) ani uloženie názvu do `.skp` (dátový tvar, G-02) nie. Strata pri zatvorení **pred** opravou je priznaná vo vete aj teste.
- **D12 (§15 A5) Primitívum `JsonFileStore` sa nemení** — pokusy obmedzuje `ExportSettings` podľa podpisu súborov.
- ~~**D13 (§15 A2) Odklad exportu na klientovi s potvrdením zo servera**~~ — **nahradené §16 B2** (bezstavová kontrola `expect` na serveri).

## 13 · Otázky pre Michala (do odpovede platí predvoľba)

- **Q1** Keď je súbor nastavení exportu poškodený a číta sa **zo zálohy**, má to plugin povedať aj bez pokusu o premenovanie (veta pri exporte, nález v Kontrole)? *Predvoľba: nie* — hlavička
  ukazuje názov, pod ktorým exporty naozaj odídu, hláška príde pri premenovaní alebo prepnutí 18 + 36 (rovnako ako pravidlá ABS a kovania v H9). Vratné.
- **Q2 (§15 A1, nový stav po schválení mockupu)** Keď je súbor nastavení poškodený a názov novej zákazky sa pri prvom uložení nedá preniesť k súboru, hlavička ukáže **jantárovú bodku
  a „neuložené k súboru"** s návodom v tooltipe („premenuj súbor … — plugin pokračuje zo zálohy bez poslednej zmeny, názov sa uloží sám; inak sa po zatvorení stratí" — §16 B1) a export pripojí rovnakú vetu. *Predvoľba: áno* (slovník mockupu —
  jantár = upozornenie, dovetok ako „zadaj názov"); pri „nie" ostane len veta po exporte. Vratné; po odpovedi zapísať do mockupu (rámček „platí") a rozhodnutí bloku.

## 14 · Nálezy mimo scope

- **N1:** `last_dir` zlého typu ide v CSV kovania, rozpočte a ponuke rovno do `UI.savepanel` (`:2140`, `:3614`, `:3705`); VEPO kontroluje `is_a?(String) && File.directory?` (`:2032`) → zjednotiť (H17).
- **N2:** hodnotové poškodenie (`merge_18_36: "nie"` = zapnuté, názov nie-reťazec) sa normalizuje ticho. **N3:** súbor nemá `std` — nový kľúč = dávka s doprednou bránou.
- **N4:** názov patrí počítaču (O6) → G-02 (názov v `.skp`, Lucia, „Uložiť ako"). **N5:** dve neuložené zákazky „projekt" + rovnaký posledný priečinok → druhý VEPO nahradí priečinok prvej;
  H7 to zviditeľní (bodka, veta), tvrdá ochrana = G-05. **N6:** `ExportSettings` do súpisu knižníc (H16).

## 15 · Audit návrhu — zapracovanie (audítor audit-povinných, 2.10.2026) — 1 BLOCKER · 5 FIX · 2 NOTE · MÁ PREDNOSŤ

Surový výstup `AUDIT_H7_raw.md` (implementátor H7a ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package). Tvrdenia A1, A3, A5, A7 overila sonda **`sonda_h7c.rb`**
(`sonda_h7c_out.txt`; sandbox cez `tests/helper.rb`, prototyp brány ako monkeypatch — nie implementácia; varianty `PROTO=0` = dnešný main, `PROTO=1` = brána, `GATE_BAK=1`, `THROTTLE=1`).
A4 a A6 overené čítaním (`tests/fixtures/h14_golden/*`, `tests/js/minidom.js`, repo bez `package.json`/`node_modules`, `jsdom` nedostupný).

| # | Nález | Overenie | Dispozícia a zmena v package |
|---|---|---|---|
| **A1** BLOCKER (H7a + H7b) | Zablokovaný adopt pri prvom uložení počas poškodeného súboru: názov žije len pod kľúčom sedenia a v moste, D5 ho nechával len v logu; po znovuotvorení zmizne | **potvrdené:** `PROTO=1` — po „uložení" názov „Customer A", most živý; znovuotvorenie bez opravy → „A" (meno súboru); zmazanie primára v pôvodnom okne → ďalšie čítanie prenos zapíše, znovuotvorenie → „Customer A". Dnešný main (`PROTO=0`) názov nestratí (zápis prepíše primár zo zálohy — práve to R-38 zakazuje) | **zapracované:** `name_pending?` (R-A1, R-A5); veta po 4 exportoch `pending_name_note` (R-A7, **H7a**); payload `pending`/`notice` a stav hlavičky „neuložené k súboru" s jantárovou bodkou (R-B1, R-B4, **H7b**); automatický prenos po oprave súboru (R-A5 + A5); matica R-A2 poznámka; D5 zmenené, **D11**; **Q2** (nový stav po schválení mockupu, predvoľba áno); riziko 11; **T-A11**, **T-B12**, M20, M21. Žiadny nový ovládací prvok, žiadna zmena dátového tvaru, žiadny zápis do modelu |
| **A2** FIX-IN-H7b — *riešenie nahradené §16 B2* | Klik na export hneď po úprave názvu: zápis zlyhá, export prebehne pod starým názvom a jeho zelený stav prekryje chybu | **potvrdené čítaním** (`studio_dialog.rb:627-632` sekvenciu „change tesne pred click" pozná; poradie callbackov je zachované, export nečaká na výsledok) | **zapracované:** R-B5 bod „Potvrdenie zápisu a odklad exportu" — `seq` + `NX.vepoOptsDone({seq, ok})` v každej vetve servera (`ensure`), odklad exportu na klientovi, pri `ok:false` sa nepokračuje; platí aj pre 18 + 36; **D13**; **T-B11** (jeden klik z otvoreného editora, vrátane odmietnutia generáciou); mutácie H7b; smoke bod 3; riziko 12 |
| **A3** FIX-IN-H7a | Brána invaliduje len primár; echo po odmietnutom zápise môže do 1 s čítať starú zálohu z cache `….bak\|nofallback` | **potvrdené:** `PROTO=1` echo „Old/false", `GATE_BAK=1` „New/true" | **zapracované:** `write_gate` invaliduje primár **aj** `.bak` (R-A4); **T-A7b** bez exportného `refresh`; M17 |
| **A4** FIX-IN-H7b | Normalizácia H14 goldenov nepokrýva tooltip/bodku `#hwCsvBtn` (g2 obsahuje lištu Nákupu) | **potvrdené:** `hwCsvBtn` v `g2_dispatch.json` 1×; tlačidlá Rozpočtu a Ponuky v goldenoch nie sú | **zapracované:** R-B11 štyri ohraničené fragmenty s presnými počtami (g1 15× `secmodel`; `prjbox` 4/2/2; `vepoBtn` 4/2/2; `hwCsvBtn` 1×), nie celá lišta; D9; mutácia H7b |
| **A5** FIX-IN-H7a | `note_block` nezabráni opakovanému fallback logu `JsonFileStore` pri syntakticky poškodenom primári (každý pokus adoptu invaliduje cache) | **potvrdené:** `PROTO=1` 100 čítaní → **100** fallback logov; `THROTTLE=1` → **2**, potom 0 | **zapracované bez zmeny primitíva:** obmedzenie pokusov adoptu podľa `JsonFileStore.file_signature` (`ADOPT_RETRY`, R-A5); R-A4 poznámka s menovitým zoznamom nezmenených konzumentov `JsonFileStore`; **D12**; T-A10 prepísaný (syntakticky poškodený primár + názov na prenos, ≤ 1 `note_block`, ≤ 2 fallback, zámok ≤ 1×, po zmene podpisu nový pokus); M18, M19 |
| **A6** FIX-IN-H7b | Harness H14/H12 má prázdne `focus`/`blur`/`dispatchEvent`/`replaceChild` — interakcie editora neoverí | **potvrdené** (`h12_harness.js:41-46`, `h14_harness.js:186`); repo má `tests/js/minidom.js` (parsovanie HTML, bublanie, `activeElement`; `studio.js` a `budget.js` nad ním bežia — `test_st2d_kde.js`), chýba `replaceChild`, `select()`, `on<typ>`, presun fokusu s `blur` | **zapracované:** §7 H7b — interakčné testy nad `minidom.js` s **opt-in** režimom `faithful(true)` (`replaceChild`, `select`, `on<typ>`, `focus()` → `blur` predošlého, `userClick`, `userKey`); ostatné sady bez zmeny; nič sa neinštaluje |
| **A7** NOTE | Matica sľubuje nedotknutú `.bak` pri každej I/O chybe; `JsonFileStore.write` najprv otočí zálohu, potom premenuje primár | **potvrdené na maine:** zlyhané finálne premenovanie → `false`, primár nezmenený, `.bak` == doterajší primár | **zapracované:** R-A2 riadok rozdelený (zlyhanie pred zápisom vs. v zápise) s pravdivou zárukou; **T-A4** doplnený test |
| **A8** NOTE | Rez a D3 primerané, D6 možno ponechať (A2 rieši nadväzujúci export); H7a je výrobná/cenová dávka, „len pri poškodení" je rozsah, nie výnimka; in-SU DoD je fakticky podmienka mergu | súhlas | **zapracované:** hlavička package a §5 — H7a **výrobná/cenová áno** (všetky brány výrobnej dávky); in-SU 1 beh = DoD **a podmienka mergu H7a**; D3 a D6 bez zmeny; rez H7a → H7b bez zmeny |

### 15.1 Čo sa zmenilo v koncepte (pre delta audit)

1. **Nová vlastnosť jadra `ExportSettings.name_pending?`** a **pamäť `ADOPT_RETRY`** (podpis súborov pod kľúčom `[project_key, aliasy]`, strop 32, bez odkazu na model) — adopt sa po neúspechu
   opakuje len po zmene súborov; po oprave súboru prebehne sám (A1, A5).
2. **Zlyhaný adopt už nie je len log:** veta po 4 exportoch (H7a) a stav hlavičky „neuložené k súboru" s `vepo.pending`/`vepo.notice` (H7b) — nový stav hlavičky čaká na **Q2** (predvoľba áno).
3. **`write_gate` invaliduje aj cache zálohy** (A3).
4. ~~**Nový protokol okna:**~~ *(nahradené §16 B2 — bezstavový `expect`)* `seq` v `studio_set_vepo_opts` + `NX.vepoOptsDone({seq, ok})` v každej vetve `do_set_vepo_opts`; klient odkladá export počas zápisu nastavení a pri neúspechu
   nepokračuje (A2) — mení sa tok exportného kliku v Štúdiu (4 tlačidlá).
5. **Goldeny H14:** normalizácia rozšírená o `#hwCsvBtn` (A4). **Testovacia knižnica `minidom.js`:** opt-in verný režim fokusu a udalostí (A6).
6. **Pravdivá záruka matice** pri zlyhaní samotného zápisu (A7). **Trieda H7a = výrobná/cenová áno**, in-SU podmienka mergu (A8).
7. **Primitívum `JsonFileStore` sa nemení** (A5) — zmeny sú len v `ExportSettings`, `ProductionCore` (veta), `StudioDialog` (potvrdenie, echo) a JS Štúdia.
8. **Odhad:** H7a 1–1¼ dňa (nová logika ~140 riadkov, poistka ~180), H7b 1–1¼ dňa (~+360/−70 + `minidom.js` ~60). **Rez sa nemení.**

## 16 · Delta audit — zapracovanie (2.10.2026, 2 BLOCKER · 2 FIX · 4 NOTE; pôvodné A3, A4, A6, A7, A8 RESOLVED, A1, A2, A5 PARTIALLY) — MÁ PREDNOSŤ pred §15

Surový výstup `AUDIT_H7_delta_raw.md` (implementátor H7a ho skopíruje spolu s `AUDIT_H7_raw.md`). Rozhodnutia orchestrátora (2.10.2026) sú záväzné; overenie sondou **`sonda_h7d.rb`**
(`sonda_h7d_out.txt`, sandbox cez `tests/helper.rb`, dnešný main) a čítaním kódu.

| # | Nález delta auditu | Overenie | Dispozícia a zmena |
|---|---|---|---|
| **B1** BLOCKER (H7a/H7b) | Náprava „zmaž `vepo_settings.json`" vráti celý spoločný dokument (názvy všetkých zákaziek, 18 + 36, posledný priečinok) o zápis späť | **potvrdené:** L1 — po každom zápise `.bak` == primár pred týmto zápisom, po poškodení chýba **presne posledný zápis** (`last_dir` D:/Y); L2 — keď cez poškodený súbor zapísal plugin bez brány (dnešný main), rotácia sa preskočila a strata je väčšia; L3 — premenovanie poškodeného súboru: číta sa `.bak`, zápis prejde, `.bak` sa pri chýbajúcom primári neotočí, premenovaný súbor ostane nedotknutý; žiadny modul priečinok `%APPDATA%\NOXUN\Engine` neprechádza (`Dir.glob` len recepty a leases) | **zapracované:** konvencia R-11/H9 ostáva (záloha, zápisy vypnuté); každá veta nápravy (R-A2 obnova, `DEGRADED_REASON`, `UNREADABLE_REASON`, `pending_name_note`, `vepo.notice`, Q2, D11, riziko 11, smoke 5, T-A10, T-A11) radí **premenovať** (napr. `vepo_settings.poskodeny.json`, ostane na ručnú obnovu), **nie zmazať**, a pravdivo povie dôsledok „plugin potom pokračuje zo zálohy; stratí sa posledná zmena uložená pred poškodením" (presne jeden zápis — L1; výnimka L2 v docs). Čakajúci názov sa po premenovaní prenesie sám (A1 ostáva). Bez nového ovládacieho prvku |
| **B2** BLOCKER (H7b) | Skalár `vepoSaving` nechráni export pred viacerými súbežnými zápismi (názov + 18 + 36), staré potvrdenie môže vyčistiť novšie | **potvrdené čítaním** (`studio.js:1771`, `:2118` — nezávislé zápisy) | **zrušený celý protokol §15 A2** (`seq`, `NX.vepoOptsDone`, `vepoSaving`, odložený export — prečiarknuté v R-B5, D13, riziko 12, §15.1 bod 4). **Nahradený R-B5b:** každé exportné volanie nesie `expect {project, merge}`, server v exportnom handleri po `refresh` a pred výberom súboru porovná s uloženou pravdou (`ExportSettings.expect_mismatch`; 18 + 36 len vo VEPO) a pri nesúlade export **nespustí** (červená veta + echo R-B9). Bezstavové — žiadne čakanie, timeout ani automatické pokračovanie; bez `expect` = dnes. **T-B11** prepísaný (zlyhanie/úspech zápisu, prekrížené názov × 18 + 36, obrátené poradie, P0-HF neozbrojený aj ozbrojený, bajty mien = T0c) |
| **B3** FIX-IN-H7b | Stratené potvrdenie zablokuje exporty | — | **odpadá s B2** (nie je čo potvrdzovať) |
| **B4** FIX-IN-H7a | `ADOPT_RETRY` na `mtime + size` nerozozná opravu s rovnakou veľkosťou a časom | **potvrdené:** L4 — obsah rovnakej dĺžky s vráteným mtime: `file_signature` rovnaká, SHA1 rôzne | **zapracované:** podpis = SHA1 bajtov primára a `.bak` (R-A5), `refresh` vyprázdni `ADOPT_RETRY`; T-A10 test opravy s rovnakou veľkosťou a časom; M22, M23 |
| **B5** FIX-IN-H7b | „Posledný klik vyhráva" mení význam P0-HF dvojkroku | — | **odpadá s B2:** `expect` ide len so skutočným exportným volaním, dvojkrok sa nemení; T-B11 pokrýva neozbrojený aj ozbrojený stav |
| **B6** NOTE | Identita dokumentu primeraná; kľúč retry musí byť nemenná kópia aliasov | — | **zapracované:** kľúč `[project_key, aliasy.dup.sort.freeze].freeze` (R-A5); T-A10 mutácia poľa; M24 |
| **B7** NOTE | Invalidácia `.bak` cache nepoškodí iných konzumentov | — | bez zmeny (súhlas) |
| **B8** NOTE | H14 normalizácia + opt-in `minidom` len s nezávislými testami; reset režimu medzi testami | — | **zapracované:** `minidom.reset()` vo `finally` každého testu + guard „po sade vypnuté" (§7 H7b); mutácia H7b. T-B1/T-B5 ostávajú nezávislé |
| **B9** NOTE | Triedenie dávok správne | — | bez zmeny |

**Poradie callbackov (žiadosť orchestrátora):** kód projektu od ŠT-1a predpokladá, že callbacky jedného HtmlDialogu sa v Ruby vybavia v poradí volania — `studio_dialog.rb:627-632`
(review #193 P2: „change tesne pred click … by zaručene spadol") a test `test_st1a_studio.rb:857-866`; VEPO export ide navyše cez relay panela (`handle_export` → `NX.studioRelayExport`
→ `studio_do_export`, `bridge.js:394-410`, payload sa prepošle celý vrátane `expect`), teda ešte o jeden okruh neskôr než zápis názvu. Oficiálne poradie dokumentované nie je a sondou
v SketchUpe overiť nešlo (MCP bridge offline) → **NEOVERENÉ**. **Minimálna alternatíva netreba:** kontrola `expect` je bezpečná v oboch poradiach — pri obrátenom export odmietne
(uložená hodnota ≠ očakávaná) a používateľ klikne znova; zlý názov v súbore nevznikne nikdy. Najhorší dôsledok = jeden klik navyše.

### 16.1 Čo sa zmenilo v koncepte oproti §15 (pre ďalší delta audit)

1. **Zrušené:** protokol potvrdenia zápisu a odloženého exportu (`seq`, `NX.vepoOptsDone`, `vepoSaving`, odklad, „posledný klik vyhráva"), D13, riziko 12.
2. **Nové:** bezstavová kontrola `expect {project, merge}` v 4 exportných handleroch (`ExportSettings.expect_mismatch`, 18 + 36 len VEPO, pred výberom súboru), klientska `VEPO_EXPECT`
   a **optimistické** zobrazenie odoslaného názvu v hlavičke do príchodu echa (R-B5, R-B5b). Bez `expect` = dnešné správanie.
3. **Náprava poškodeného súboru = premenovanie, nie zmazanie,** s pravdivým dôsledkom (presne posledný zápis; L2 výnimka) vo všetkých vetách a v docs.
4. **`ADOPT_RETRY`:** obsahový podpis SHA1 (primár + `.bak`), vyprázdnenie v `refresh`, zmrazený kľúč aliasov.
5. **`minidom.reset()`** a guard režimu.
6. **Q2** ostáva otázkou pre Michala (stav hlavičky „neuložené k súboru", predvolené áno); Q1 bez zmeny.
7. **Odhad:** H7a 1–1¼ dňa (nová logika ~145 riadkov, poistka ~180) · H7b **1 deň** (~+320/−70 + `minidom.js` ~70). **Rez H7a → H7b sa nemení.**

---

## 17 · Druhý delta audit (bežný audit a delta, 2.10.2026) — 1 BLOCKER · 3 FIX · 3 NOTE → zapracovanie orchestrátorom · MÁ PREDNOSŤ PRED §15 A §16

Surový výstup `AUDIT_H7_delta2_raw.md` (implementátor H7a skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` všetky tri surové audity: `AUDIT_H7_raw.md`,
`AUDIT_H7_delta_raw.md`, `AUDIT_H7_delta2_raw.md`). Delta nálezy 3–9 RESOLVED; 1 a 2 PARTIALLY → doriešené nižšie. Body sú presné spresnenia bez zmeny
konceptu §16 → **audit uzavretý** (ďalší delta audit sa nespúšťa; overí predrecenzia a GH review).

- **C1 (BLOCKER, H7b — R-B5b):** `expect` je pre štyri exporty z okien **povinný (fail-closed)**. Handler VEPO (aj cez relay panela), CSV kovania, XLSX rozpočtu
  a XLSX ponuky **odmietne** volanie bez `expect` alebo s neplatným tvarom **pred výberom súboru** — červená veta „Okno je zastarané — zatvor a otvor Štúdio
  a klikni znova" + echo hlavičky. Veta „bez `expect` = dnešné správanie" z §16 **neplatí**. Výnimka len pre výslovne pomenovaného volajúceho mimo UI (ak taký
  v kóde existuje — implementátor ho Grepom vymenuje v PR; ak neexistuje, výnimka nie je). Test: volanie bez `expect` a s `expect: {}` → odmietnuté vo všetkých
  štyroch handleroch vrátane relay. (Cache-bust `?v=` zaručuje nový klient; fail-closed kryje zvyšok.)
- **C2 (FIX, H7b):** porovnanie `expect.project` ↔ uložený názov ide cez **jednu normalizačnú funkciu na OBOCH stranách** (strip + strop 120 znakov, rovnaké
  pravidlo predvoleného názvu), a payload/echo hlavičky posiela klientovi **už normalizovaný** názov. Test: ručne uložený záznam dlhší ako 120 znakov → export prejde
  (žiadny trvalý falošný nesúlad).
- **C3 (FIX, H7a):** `ADOPT_RETRY` sa **nemaže globálne pri `refresh`** (obsahový SHA1 primára a zálohy zmenu spoľahlivo rozpozná). T-A10 doplní sériu
  `refresh → project_name` nad nezmenenými súbormi: najviac jeden pokus o adopt a jeden riadok logu.
- **C4 (FIX, H7a/H7b — texty):** veta nápravy je **podmienená**: „…plugin potom pokračuje zo zálohy; spravidla sa stratí len posledná zmena (ak súbor medzitým
  zapisovala staršia verzia pluginu, záloha môže byť staršia)". Premenovaný súbor plugin nikdy nečíta (potvrdené — číta len presnú cestu).
- **NOTE 5–7:** poradie callbackov nie je potrebné pre bezpečnosť (len pre export na prvý klik) — v PR uviesť ako NEOVERENÉ v SketchUpe; Save As/dve zákazky bez
  trvalého bloku; SHA1 náklad primeraný.

### 17.1 Odchýlky H7b (predrecenzia H7b, rozhodnutie orchestrátora 2.10.2026) — spresnenie §17 C1

- **`expect` nesie aj `source`** (zdroj názvu, ktorý hlavička ukazovala: `set`/`file`/`default`); bez neho alebo s neplatným = fail-closed ako doteraz.
- **Automatický → automatický sa toleruje:** ak očakávaný aj skutočný zdroj ∈ {`default`, `file`} a mená sa líšia (najbežnejšie: nový model → Ctrl+S → export —
  uloženie okno nepushuje), používateľ nič nezadal a niet čo stratiť → export prebehne pod skutočným menom, stav pripojí „ · Zákazka: <meno> (podľa súboru)"
  a echo hlavičky sa urobí. **Observer uloženia sa nepridáva** (observer lifecycle = audit).
- **Zadaný názov na ktorejkoľvek strane + iné meno = odmietnutie neutrálnou pravdivou vetou** „Názov zákazky sa medzitým zmenil — platí „…". Export sa nespustil,
  skontroluj názov a klikni znova." (veta „sa neuložil" ostáva len pri skutočne zlyhanom zápise — hlási ju zápis v okne). 18 + 36 pri VEPO ostáva prísne
  (veta „Nastavenie 18 + 36 sa medzitým zmenilo — platí: …").
- **Výnimka pri overovaní = `EXPECT_FAILED`** (export sa nespustí) — pokryté testom a mutáciou.
- **VEPO používa názov a 18 + 36 overené v bráne** (pred výberom priečinka), nie znova prečítané po ňom (P3 — dve inštancie SketchUpu).

**Potvrdenie orchestrátora k §12 (2.10.2026):** D1 áno (`ExportSettings`, bez delegátov) · D2 áno · D3 áno (bez dobrej zálohy dnešné správanie + povedať) · D4 áno ·
D5 áno (upravené §15/§16) · D6 nahradené §16/§17 (expect) · D7 áno · D8 áno · D9 áno · D10 áno. **Rez H7a → H7b**, každá samostatný PR z čerstvého mainu.
**Trieda:** H7a = audit-povinná + **výrobná/cenová** (predrecenzia povinná, **in-SU 1 beh = podmienka mergu**); H7b = nový ovládací prvok (predrecenzia povinná),
nie výrobná pri parite mien exportov, fotky `-Record`. **Q1** (hlásiť poškodenie aj mimo premenovania) = predvolené NIE. **Q2** (stav hlavičky „neuložené
k súboru") = otázka pre Michala, predvolené ÁNO (vratné) — H7b ho implementuje s predvoľbou, ak Michal neodpovie, a zapíše do mockupu H7 (rámček platí) aj
rozhodnutí bloku ako „predvolené, čaká na potvrdenie".
