# PACKAGE U1 · Názov zákazky v .skp — blok UPDATE (D-48)

> **Stav: NÁVRH — čaká audit návrhu (`codex-audit`).** Dátum 17.10.2026. Package sa robí do zásoby — **implementácia až po Michalovom smoke PASS bloku 9 HARDENING**
> (alebo výslovnom „ideme ďalej").
> **Autorita:** [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) **R8** (názov zákazky cestuje v .skp, samostatná dávka bloku), **R9** („18 + 36" a cesty ostávajú
> každému PC), **R14** (rovnaká verzia pluginu na oboch PC) · mockup [MOCKUP_UPDATE_KNIZNICA.html](MOCKUP_UPDATE_KNIZNICA.html) schválený 17.10. — riadok 170: *„Názov zákazky v .skp okno
> nemení — hlavička Štúdia vyzerá ako dnes, len názov ide so zákazkou aj k Lucii"* · [RECONCILE_2026-10-17.md](RECONCILE_2026-10-17.md) §2 riadok „Názov zákazky pri otvorení" a §3 U1 ·
> nálezy **A4 B12**, **A2 B8, B10** · súpis [kniznice.md](../../../../docs/architecture/kniznice.md) **F1**.
> **Predchodca:** [PACKAGE_H7.md](../../../archiv/bloky/HARDENING/PACKAGE_H7.md) (H7a/H7b — `ExportSettings`, kontrola `expect`). H7 D11 vtedy zápis názvu do `.skp` vedome odložil
> (G-02); U1 ho robí teraz.
> **Stav kódu:** sonda nad `main` **`a9e8c79d`** (v0.18.1, po PR #474). Riadky = stav k nemu.

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 17.10.2026

Sonda **čítaním kódu** (worktree `docs/update-start` = `main` + docs). SketchUp sa nespúšťal, do modelu ani do `%APPDATA%` sa nič nezapisovalo. Tvrdenia o správaní SketchUpu,
ktoré čítaním overiť nejde, sú označené **NEOVERENÉ** a overí ich in-SU sonda R0.2 pred implementáciou.

| # | Tvrdenie o dnešnom kóde | Dôkaz | ✓ = PRAVDA |
|---|---|---|---|
| S1 | Názov zákazky žije **len** v `%APPDATA%\NOXUN\Engine\vepo_settings.json`, mapa `project_names`, kľúč = normalizovaná cesta `.skp` (`\`→`/`, `downcase`), neuložený model `guid:<DocKey token>`; „žiadny zápis do modelu, žiadny krok Späť" | `core/export_settings.rb:2-12`, `:320-329`, `:381-383`, `:401-404`, `:450-453` | ✓ |
| S2 | Čítanie `project_name(model)` = záznam pod cestou → kľúče sedenia (most `SESSION_KEY_BRIDGE`, prenos `adopt_session_name` **so zápisom do súboru pri čítaní**) → predvolené (meno súboru, inak `projekt`) | `:461-473`, `:489-529`, `:301-304`, `:22` | ✓ |
| S3 | Zápis `save_project_name` ide cez `update_project_names` → `update` (zámok `Materials.with_catalog_lock`, brána R-38, `JsonFileStore.write`) → `[status, reason]` | `:623-649`, `:365-376`, `:184-211` | ✓ |
| S4 | Pamäť procesu pre prvé uloženie (`SESSION_KEY_BRIDGE`, strop 32), pamäť pokusov `ADOPT_RETRY` (SHA1 primára a `.bak`), stav „čakajúci názov" `name_pending?` — všetko existuje len kvôli tomu, že názov neuloženého modelu nemá kam ísť okrem kľúča sedenia | `:352-353`, `:412-447`, `:543-600` | ✓ |
| S5 | Upratovanie mostu pri výmene dokumentu volá `Engine.document_cleanups` | `core/doc_key.rb:176-180` | ✓ |
| S6 | Okno Štúdia: `do_set_vepo_opts` → brána generácie → `DocKey.foreign?` → `ExportSettings.save_project_name` → `case status` → **vždy** echo `push_vepo_bar`; úspech nedvíha generáciu | `ui/studio_dialog.rb:653-702`, `:708-715` | ✓ |
| S7 | Payload `vepo` skladá **jedna** funkcia: `project` (normalizovaný), `default_project`, `merge_18_36`, `source`, `file`, `export_names`, **`pending`, `notice`** | `ui/production_core.rb:222-235` | ✓ |
| S8 | Exporty: `ExportPrep.start` → `ExportSettings.refresh` → `ProductionCore.export_expect_check` (jediné volanie `expect_check`, raz na export) → kontext nesie overený `:project`; koncová veta `name_suffix` = `pending_name_note` + `default_name_note` + `ctx.name_note` | `ui/export_prep.rb:155-189`, `:209-216`; `ui/production_core.rb:252-255`, `:161-169`, `:196-203` | ✓ |
| S9 | `expect_check` porovnáva `normalize_project_name` oboch strán; tolerancia automatický → automatický (`AUTO_SOURCES`); výsledok `{stop, note, project, merge}` | `core/export_settings.rb:688-761` | ✓ |
| S10 | Okno Štúdia má vlastný `StudioModelWatch` (`onTransactionCommit/Undo/Redo/Abort`) → `on_model_txn` → `@epoch += 1` → `markStale` („Obnoviť" zožltne), ak `@epoch > @pushed_epoch`. **Každý zápis do modelu v operácii by teda tlačidlo rozsvietil** | `ui/studio_dialog.rb:102-125`, `:271-279`, `:312-318`, `:1778` | ✓ |
| S11 | Precedens zápisu na **model** v slovníku `NOXUN`: `Materials.set_project_default` (volajúci drží operáciu), `BudgetStore.write!` (vlastná `start_operation(name, true)` … `commit`, pri chybe `abort`), snapshoty `hardware_rules` / `hardware_sets` (`Store::DICT`) | `core/materials_project.rb:33-41`; `core/budget_store.rb:752-785`; `core/hardware_rules.rb:1148`; `core/hardware_sets.rb:2475` | ✓ |
| S12 | Kľúč `project_name` (ani `job_name`) na modeli dnes **neexistuje** v kóde ani v testoch | Grep `noxun_engine/`, `tests/` | ✓ |
| S13 | Plugin **nemá** `onPreSaveModel` ani iný háčik uloženia; jediný stále nainštalovaný AppObserver je `ScaleWatch::EngineAppObserver` (`onNewModel`/`onOpenModel` → `on_document_replaced` + `model_switched`, `onActivateModel` → `model_switched`); inštalácia `ScaleWatch.install` pri štarte | Grep; `core/scale_observer.rb:46-64`, `:962-1002`; `main.rb:721` | ✓ |
| S14 | Sonda export testu (`tests/sketchup/su_export_probe.rb`) je **jedna pre K aj P** (načítaná z aktuálneho checkoutu) a skladá `expect` cez `ExportSettings.project_name` / `name_source` | `su_export_probe.rb:1-11`, `:119-120`; `scripts/export_test.ps1:152-201` | ✓ → R7 |
| S15 | Export test kopíruje model do priečinka behu (cesta sa líši pre K a P) → záznam podľa cesty sa v teste nikdy nenájde, názov = meno súboru `zakazka` | `export_test.ps1:23`, `:186-204` | ✓ |
| S16 | Golden H7: `names.json` (mená a nadpisy podľa textu názvu), `exports.json` (4 exporty end-to-end), `bytes.json` (bajty `vepo_settings.json` + `.bak` po každom kroku **vrátane zápisov názvu**) | `tests/pure/test_h7a_golden.rb:9-13`, `:189-228`, `:360-363` | ✓ → R0.1 |
| S17 | JS hlavičky: stav `pending` („neuložené k súboru", tooltip `vepo.notice`), bodka exportov ho vylučuje | `ui/js/studio.js:1280-1345`, `:1460` | ✓ |
| S18 | Register knižníc: riadok `export_settings` s poznámkou „nazvy zakaziek (kluc = cesta .skp) …"; skupina mimo knižníc `model` = „cestuje so zakazkou" | `core/library_registry.rb:140-144`, `:224-225` | ✓ |
| S19 | `in-SU` blok ST-1a zapisuje a maže názov cez `ExportSettings.save_project_name` / `update_project_names` | `tests/sketchup/su_runner.rb:144`, `:15850-15880` | ✓ |
| S20 | Názov zákazky ide aj do **obsahu** výstupov (LOG VEPO, 1. riadok CSV kovania, nadpisy hárkov XLSX) — pripnuté T0a | `test_h7a_golden.rb:9-13`; `VEPO_KONTRAKT.md:96-98` | ✓ |
| S21 | **NEOVERENÉ (SketchUp):** (a) atribút zapísaný v `ModelObserver#onPreSaveModel` sa uloží do toho istého súboru; (b) po uložení `model.modified?` = false; (c) priehľadná operácia (`start_operation(name, true, false, true)`) v tom háčiku nevyrobí nový krok Späť a nespadne pri prázdnom zásobníku; (d) háčik pri autosave; (e) `onTransactionCommit` príde **synchrónne** v `commit_operation` | — | **NEOVERENÉ → R0.2** |

---

## 1 · Cieľ (funkčne)

Názov zákazky sa **ukladá do súboru zákazky (.skp)**, nie do pamäte jedného počítača. Keď Michal pošle zákazku Lucii, otvorí ju s **tým istým názvom** a VEPO, CSV kovania,
XLSX rozpočtu aj Cenová ponuka sa u nej pomenujú rovnako ako u Michala. **Okno sa nemení** (mockup r. 170): hlavička Štúdia „Zákazka: Kuchyňa Novák ✎" vyzerá a správa sa ako dnes.

**Príklad:** Michal má rozrobenú „Kuchyňa Novák" (názov zatiaľ na jeho PC podľa cesty). Po aktualizácii pluginu zákazku otvorí — vidí názov ako doteraz, súbor sa **neoznačí ako zmenený**.
Pri najbližšom **Ctrl+S** sa názov sám uloží do súboru. Lucia súbor otvorí → „Zákazka: Kuchyňa Novák", export VEPO do priečinka `kuchyna_novak`. Premenovanie v hlavičke je odteraz
**zmena zákazky**: súbor dostane hviezdičku (neuložené zmeny) a **Ctrl+Z** názov vráti.

„18 + 36 spolu" a posledný priečinok exportu ostávajú nastavením počítača (R9) — bez zmeny.

## 2 · Rez a odhad

**Jeden PR** (U1 je nezávislá od U2–U5; reconcile §3 „U1 kedykoľvek"). Poradie commitov **záväzné** (predrecenzia tak vidí charakterizáciu, novú logiku a odstránenie oddelene):

1. **R0** charakterizácia (plugin bez zmeny, zelené na `main`) + výsledok in-SU sondy R0.2 do PR.
2. Modul `ProjectName` + poradie čítania + zápis do modelu + prepojenie volajúcich (R1–R4, R6).
3. Prevzatie starého názvu pri uložení (R5, observer).
4. Odstránenie mŕtveho mechanizmu kľúča sedenia a čakajúceho názvu (R8).
5. Dokumentácia (R10).

| Časť | Kód pluginu (+/−) | Testy | Poznámka |
|---|---|---|---|
| nový `core/project_name.rb` (časť presun z `ExportSettings`) | ~+220 (presun ~110, nová logika ~110) | nová sada ~350 | |
| `ExportSettings` | ~+15 / −330 | `test_h7a_*` −~450, prepis | odstránenie R8 |
| volajúci (`production_core`, `export_prep`, `studio_dialog`, `doc_key`, `scale_observer`, `main`) | ~+60 / −60 | prepis stubov | |
| `studio.js` (vetva `pending`) | ~−15 | `test_h7b_*` úprava | |
| `su_runner.rb`, `su_export_probe.rb` | ~+60 / −40 | — | |

**Odhad:** nová logika ~110–150 riadkov, celkový diff kódu pluginu ~**+300 / −400**; **1–1½ dňa**. **Poistka:** keď diff kódu pluginu prekročí **~800 riadkov** (súčet + a −) alebo
nová logika ~200, implementátor zastaví a orchestrátor rozhodne o rozdelení **U1a** (commity 1–3 + 5, mechanizmus kľúča sedenia ostane nepoužitý) → **U1b** (commit 4).

## 3 · Scope IN

- Kľúč `project_name` v slovníku `NOXUN` **na modeli** (R1); modul `Noxun::Engine::ProjectName` (R2).
- Čítanie: model → starý záznam podľa cesty (len čítanie) → predvolené (R3).
- Zápis z hlavičky Štúdia = jedna operácia v modeli, bez zožltnutia „Obnoviť", bez zdvihu generácie (R4).
- Prevzatie starého záznamu do modelu **pri uložení**, bez nového kroku Späť (R5) — podmienené sondou R0.2.
- Exporty (`expect`, mená, vety) a payload `vepo` čítajú `ProjectName` (R6); sonda export testu kompatibilná s K aj P (R7).
- Odstránenie zápisov názvu do `vepo_settings.json` a mechanizmu kľúča sedenia (R8); register a docs (R9, R10).

## 4 · Scope OUT

- Akákoľvek zmena vzhľadu okna (mockup r. 170); nové ovládacie prvky.
- „18 + 36" a posledný priečinok (ostávajú v `vepo_settings.json`, R9); brána R-38, tvar súboru, `doc_shape_ok?` bez zmeny.
- **Mazanie** starej mapy `project_names` zo súboru (ostáva, len sa už nezapisuje — D3).
- Zdieľanie knižníc (U2–U5), karta zákazky (G-02 nad rámec názvu), ochrana pred prepísaním VEPO priečinka dvoch zákaziek s rovnakým názvom (G-05, N5 z H7).
- Echo hlavičky po Späť/Znova (dnes „Obnoviť" zožltne a kontrola `expect` export zastaví — D6).
- Zmrazenie či verzia (`std`) kľúča názvu — jednoduchý String bez schémy (D4).

## 5 · Trieda a brány

- **Trieda Ť** (CLAUDE.md, matica WORKFLOW § 2): audit-povinná **a** výrobná/cenová **a** nad 300 riadkov kódu.
- **`codex-audit`: povinný** — mení **dátový kontrakt zákazky** (nový kľúč v `NOXUN` na modeli), **observer/undo lifecycle** (háčik uloženia, zápis v operácii, `on_model_txn`)
  a pridáva **nový modul**. Úzke zadanie (R12): vymenované súbory tohto package. Krok 0 = §0 (sonda S21 sa urobí v R0.2 **pred** implementáciou, výsledok do package ako §16).
- **Výrobná/cenová: áno** — mení vstup exportov (z čoho sa skladá názov v menách súborov VEPO/CSV/XLSX a v ich obsahu, S20). Na zdravom súbore a modeli bez kľúča **bajtovo bez zmeny**.
- **Predrecenzia: povinná** (audit-povinná, výrobná, > 300 riadkov).
- **In-SU: brána mergu** — mení **akciu panela zapisujúcu do modelu** (premenovanie), **undo a operácie** a **observer** (háčik uloženia, `on_model_txn`). Beh `-CloseWhenDone`
  na finálnej hlave; PR uvedie hlavu.
- **Export test: brána mergu** — `scripts\export_test.ps1` musí dať **`P == K`** na predvolenej zákazke (model bez kľúča, S15). Ďalší beh s modelom, ktorý kľúč nesie, je
  **vedomý rozdiel** (K kľúč nepozná) — len ak ho implementátor robí, uvedie ho v PR ako vedomý; brána je prvý beh.
- **Fotky okien:** payload `vepo` stráca `pending`/`notice` (R8) → `ui_foto.ps1 -Record` + hárok do reportu (Kusovník, Nákup, Rozpočet, Ponuka, jedna katalógová sekcia) — hlavička
  musí vyzerať ako na fotke spred dávky.
- **Smoke:** Michal + **Luciino PC** (§10).

## 6 · Požiadavky

### R0 · Pred zásahom

**R0.1 Charakterizácia (1. commit, plugin bez zmeny, zelené na `main`):**
- **T0a** `names.json` a **T0c** `exports.json` (H7) ostávajú — **po U1 zelené bez regenerácie** (názov sa po novom nastaví cez `ProjectName.save` / kľúč modelu, mená a obsah
  výstupov sú funkciou textu názvu).
- **T0b-U1** nový golden `tests/fixtures/u1_golden/bytes.json` (ručný `generate.rb`, vzor H7): sandbox so **starou mapou** (dva záznamy podľa cesty + jeden `guid:` kľúč), potom
  len `save_merge_18_36(false)`, `save_last_dir('D:/Export/VEPO')`, `save_merge_18_36(true)` → bajty primára **aj `.bak`** po každom kroku + `project_name` dvoch modelov s cestou.
  Po U1 **tie isté bajty** (mapa sa skalárnymi zápismi zachová) **a tie isté názvy** (cez čítanie starého záznamu).
- **Starý T0b** (`bytes.json`, kroky so zápisom názvu do súboru) **zaniká** spolu s testom `test_h7a_golden.rb` „T0b" — **vedomá zmena** (zápis názvu už do súboru nejde); PR to uvedie.

**R0.2 In-SU sonda háčika uloženia (pred 2. commitom; jednorazový skript nad kópiou `_dev\ENGINEtests.skp`, slučka runnera, `-CloseWhenDone`, **bez** zmeny pluginu)** — (§15 F4):
ModelObserver s `onPreSaveModel`, ktorý zaznamená `model.path` a v priehľadnej operácii zapíše `NOXUN/project_name_probe` = `model.path`. Scenáre a merané výsledky:
- **P1 bežné uloženie:** úprava geometrie (operácia „X", napr. posun skupiny) → `model.save` → (a) atribút v súbore (zavrieť, znovu otvoriť kópiu) · (b) `modified?` hneď po uložení ·
  (c) **pred zatvorením** `Sketchup.undo` raz → vráti sa „X" aj atribút spolu, **žiadny samostatný krok** „Názov zákazky" v zásobníku; potom `Sketchup.redo` → „X" aj atribút späť.
- **P2 čerstvo otvorený model bez úprav** (prázdny zásobník) → `model.save` → nespadne, (a), (b), (c) bez nového kroku.
- **P3 Save As:** `model.save(<nová cesta>)` → **ktorú cestu vidí `model.path` v callbacku** (stará / nová) a pod ktorou je výsledný súbor; v sandboxovej mape dva rozdielne staré názvy
  („Stará" pod starou cestou, „Nová" pod novou) → ktorý by R5 vybral.
- **P4 autosave (d):** autosave zapnuté s najkratším intervalom (kľúč predvoľby zistí implementátor; NEOVERENÉ) + úprava + čakanie → či háčik beží, či sa mení zásobník Späť a `modified?`.
  Keď sa autosave nedá spustiť automaticky, P4 urobí Michal ručne podľa návodu v PR **pred** výberom variantu A.
- **P5 poradie (e):** `onTransactionCommit` voči návratu `commit_operation` (synchrónne?).
- **P6 vynútená chyba (§15 B1):** callback po `start_operation(…, true, false, true)` vyhodí výnimku **pred** `set_attribute`, zotavenie podľa R5 (bez `abort_operation`) → geometria
  operácie „X" **zachovaná** (porovnať transformáciu a počty), súbor sa uloží, Undo vráti „X".

Výsledok (tabuľka P1–P6) ide do PR a ako §16 do tohto package.
**Rozhodnutie:** variant **A** len keď platí **všetko:** (a) ∧ (b) ∧ (c) bez nového kroku Späť a Undo + Redo vracia a obnovuje „X" spolu s atribútom ∧ P2 nespadne ∧ P3 má zistenú cestu
(R5 Save As podľa nej) ∧ P4 bez škody (alebo Michalovo ručné overenie) ∧ P6 geometria zachovaná. **Nový krok Späť alebo zmena geometrie pri P6 = variant A zakázaný.** Inak R5
variant **C** (§12 D2) a orchestrátor to oznámi Michalovi (mení sa smoke krok 3).

### R1 · Kľúč v modeli (dátový kontrakt)

- Slovník `Store::DICT` (`NOXUN`) **na modeli**, kľúč **`project_name`**, hodnota **String**.
- **Prítomnosť kľúča rozhoduje:** kľúč je → **autorita je model** (aj prázdny `''` = „vedome bez názvu" → predvolené meno súboru; starý záznam sa už **nečíta**); kľúč nie je → R3 krok 2.
- Zapisuje sa **vždy** normalizovaná hodnota `clean_project_name` (orez, strop **120** znakov, orez) — rovnaká funkcia ako dnes (`export_settings.rb:666-668`).
  Hodnota zhodná s predvoleným menom (`default_project_name`) sa zapíše ako `''` (dnešné pravidlo „zhodné s predvoleným = zmazať", `:627-628`) — po premenovaní súboru sa tak názov
  zmení sám, ako dnes.
- **Neplatná hodnota** (nie String, výnimka čítania) = kľúč **akoby nebol** (R3 krok 2) + **jeden** riadok logu na model a sedenie (`ProjectName: neplatny project_name (<trieda>)`);
  neprepisuje sa pri čítaní.
- Pri prvom zápise plugin **nepečiatkuje** `std` ani iný marker (D4).

### R2 · Modul `Noxun::Engine::ProjectName` (`core/project_name.rb`, `module_function`)

- **Načítanie:** `main.rb` za `core/export_settings`, pred `ui/production_core` (`main.rb:563`); `tests/helper.rb` zoznam. Pri načítaní na model ani súbor nesiaha.
- **Presun z `ExportSettings` (bez zmeny správania a textov, bez delegátov — precedens H7 D1):** `DEFAULT_PROJECT_NAME`, `PROJECT_NAME_MAX`, `default_project_name`, `clean_project_name`,
  `normalize_project_name`, `name_source`, `EXPECT_STALE`, `EXPECT_FAILED`, `SOURCES`, `AUTO_SOURCES`, `expect_valid?`, `expect_check`, `expect_mismatch`.
- **Nové verejné:**
  - `MODEL_KEY = 'project_name'`
  - `stored(model) → String | nil` — surová platná hodnota kľúča (nil = kľúč nie je alebo je neplatný; R1).
  - `name(model) → String` — R3 (nahrádza `ExportSettings.project_name`).
  - `origin(model) → 'model' | 'pc' | 'none'` — odkiaľ názov je (pre log, testy a in-SU; **do payloadu nejde**, okno sa nemení — D5).
  - `save(model, name) → [status, reason]`, `status ∈ :ok | :unchanged | :failed` — R4.
  - `adopt_on_save(model) → :adopted | :skipped | :failed` — R5 (nikdy nevyhodí).
  - `own_txn?` — true **len** počas commitu vlastnej operácie (R4.3).
  - `FAILED_REASON = 'zápis do zákazky sa nepodaril'`.
- `expect_check` interne volá `name(model)` namiesto `project_name(model)` **a explicitne `ExportSettings.merge_18_36`** namiesto nekvalifikovaného `merge_18_36`
  (`export_settings.rb:731`; bez toho `NameError` → `EXPECT_FAILED` vo **všetkých 4** exportoch — §15 F2, test T9b); všetko ostatné z `:727-761` bez zmeny.

### R3 · Čítanie názvu (`ProjectName.name`)

1. `stored(model)` nie je nil → `s = clean_project_name(stored)`; prázdne → `default_project_name(model)`; inak `s`.
2. Inak (kľúč nie je) → `ExportSettings.legacy_project_name(model)` (R8.1) — **len čítanie** súboru, nikdy zápis, nikdy zámok; neprázdne → ten.
3. Inak `default_project_name(model)` (meno uloženého súboru, inak `projekt`).

**Čistá funkcia vzhľadom na model** (nič nezapisuje — koniec „zápisu pri čítaní" S2). Neuložený model bez kľúča → krok 3 (stará mapa sa pre `guid:` kľúče **nečíta**: po aktualizácii
pluginu sa SketchUp reštartuje, kľúče sedenia z minulých sedení sú mŕtve — D7).

### R4 · Zápis z hlavičky Štúdia

**R4.1 `ProjectName.save(model, name)`:**
- `model` nil / nemá `set_attribute` → `[:failed, FAILED_REASON]`.
- `value = clean_project_name(name)`; `value = ''` ak sa rovná `default_project_name(model)`.
- **Nemení sa nič** (`stored(model) == value`, alebo kľúč nie je, `value == ''` a R3 krok 2 je prázdny) → `[:unchanged, '']`, **žiadna operácia** (žiadny krok Späť, žiadna hviezdička).
  Poznámka: kľúč nie je + starý záznam „A" + používateľ zmaže pole → `value = ''` **zapíše sa** (inak by sa „A" vrátilo) — test.
- Inak `model.start_operation('Názov zákazky', true)` → `model.set_attribute(Store::DICT, MODEL_KEY, value)` → `commit_operation` (R4.3) → `[:ok, '']`.
  Výnimka → `abort_operation` (vlastný `rescue` pri aborte, vzor `budget_store.rb:776-783`) + `Engine.log_error(e, 'ProjectName.save')` → `[:failed, FAILED_REASON]`.
- Názov operácie „Názov zákazky" = text v ponuke Úpravy → Späť.

**R4.2 `StudioDialog#do_set_vepo_opts`** (`studio_dialog.rb:653-702`): brány generácie a `DocKey.foreign?` **bez zmeny poradia**; vetva `project` volá `ProjectName.save`
a skladá vetu cez `case`: `:ok, :unchanged` → „Názov zákazky: <`ProjectName.name`> · platí pre VEPO, kovanie, rozpočet aj ponuku" (text bez zmeny) · inak **červené** „Názov zákazky sa
nepodarilo uložiť — skús znova" (vetva `:blocked, :unreadable` pre názov **zaniká** — súbor nastavení sa názvu netýka). Vetva `merge` bez zmeny. **Echo `push_vepo_bar` vždy**,
úspech **nedvíha generáciu** (dnešný guard). Komentár nad metódou („Obe hodnoty sú nastavením POČÍTAČA … žiadny zápis do modelu") prepísať pravdivo.

**R4.3 „Obnoviť" po vlastnom zápise nezožltne:** zápis názvu nemení kusovník ani čísla. `ProjectName` drží príznak `OWN_TXN = { active: false }` (konštanta, vzor `LAST_BLOCK`), ktorý
nastaví na `true` tesne pred `commit_operation` a v `ensure` vráti. `StudioDialog.on_model_txn` (`:271-279`) pri **commite** s `ProjectName.own_txn?` epochu **nezdvihne**
(undo, redo, abort sa nefiltrujú — po Ctrl+Z sa názov zmení a „Obnoviť" smie zožltnúť, D6). Ostatné ModelObservery (`EdgeModelWatch`, `GrainModelWatch`, `DirectionModelWatch`,
`PanelModelObserver`) sa **nemenia** (len označia „dirty", lenivý prepočet — neškodné). **Podmienka:** synchrónny `onTransactionCommit` (S21 e, R0.2 P5). Keď R0.2 ukáže asynchrónny callback, príznak
(ani náhradné `@pushed_epoch = @epoch` po commite) nepomôže — filter sa vypustí a zožltnutie po premenovaní sa prizná v docs; rozhodne orchestrátor.

### R5 · Prevzatie starého názvu do modelu (variant A — pri uložení)

- **Kedy:** `ModelObserver#onPreSaveModel(model)` nového observera `ProjectName::SaveWatch` (guard `if defined?(Sketchup::ModelObserver)`, vzor `studio_dialog.rb:102`).
- **Čo:** `adopt_on_save(model)` (§15 B1, F3):
  1. **Mimo transakcie** (všetko, čo môže zlyhať, okrem samotného zápisu): kľúč je (aj neplatný) → `:skipped` · model nie je **zákazka pluginu** (`noxun_job?`: na modeli je slovník
     `NOXUN` **alebo** aspoň jedna entita najvyššej úrovne nesie `NOXUN/kind` `cabinet`/`board` — len prvá úroveň, žiadny hĺbkový prechod) → `:skipped` (do cudzích modelov sa nezapisuje) ·
     `value = ExportSettings.legacy_project_name(model, path: adopt_path(model))`; zhodný s predvoleným → `''`; **prázdny → `''`** (F3: pri prvom uložení sa ustanoví **autorita modelu
     aj pre automatický názov** — druhé PC potom nepoužije svoj historický záznam pre svoju cestu).
  2. **Transakcia** = len `model.start_operation('Názov zákazky', true, false, true)` → `begin set_attribute(Store::DICT, MODEL_KEY, value) rescue StandardError => e; err = e end` →
     **`commit_operation` vždy** (v `ensure`, s príznakom R4.3). **`abort_operation` sa v háčiku NIKDY nevolá** — priehľadná operácia je pripojená k predošlej operácii používateľa
     a abort by zrušil aj ju (SketchUp API `Model#abort_operation`). Zlyhaný `set_attribute` nič nezmenil, commit bez zmeny je neškodný; zlyhaný `commit_operation` sa len zachytí.
  3. **Po transakcii:** logovanie (`ProjectName: nazov prevzaty do zakazky (<cesta>)`, resp. `log_error(err, 'ProjectName.adopt_on_save')`) a návrat `:adopted` / `:failed`.
     Medzi `start_operation` a `commit_operation` nebeží logovanie ani nič iné.

  **Nikdy nevyhodí** z háčika a **nikdy nezastaví ukladanie** používateľa. Testovací šev `ProjectName::FAULT = { adopt: false }` (len pre T5, P6, in-SU 8; v produkcii vždy false — guard).
  `ExportSettings.legacy_project_name(model, path: nil)` dostane voliteľnú cestu (predvolene `model.path`).
- **Kde sa pripája:** `ProjectName.attach_save_watch(model)` — anti-double `remove_observer` → `add_observer`, každý krok vlastný `rescue` (vzor `StudioDialog.attach_stale_observer`
  `:327-345`); volá ho `ScaleWatch.install` pre `Sketchup.active_model` (`scale_observer.rb:57`) a `EngineAppObserver#model_switched` (`:993`) pre nový/otvorený dokument. Jeden
  inštančný observer na celý plugin (`@save_watch ||=`).
- **Prečo nie pri otvorení (A4 B12, A2 B8):** zápis by zákazku označil ako zmenenú a pridal krok Späť bez akcie používateľa. Pri uložení sa súbor zapisuje tak či tak.
- **Mapa sa nemaže** (D3): na tom PC ďalej platí kľúč v modeli (R3 krok 1); keby niekto zákazku otvoril starším pluginom, nájde názov ako doteraz.
- **Save As (§15 F4):** kópia nesie názov **originálu** (R20) → `adopt_path(model)` = cesta, pod ktorou bol dokument otvorený alebo naposledy uložený. Keď R0.2 P3 ukáže, že `model.path`
  v callbacku je **stará** cesta, `adopt_path = model.path`; keď **nová**, `adopt_path` = pamäť poslednej známej cesty (zapamätá ju `model_switched` pri otvorení a `onPostSaveModel` toho
  istého observera; viazaná na DocKey token, upratuje ju `Engine.document_cleanups`). Test T5b: rozdielne staré názvy pod starou a novou cestou → prevezme sa názov **starej**.
  Prvé uloženie neuloženého modelu: cesta nie je → zapíše sa `''` (zákazka pluginu), názov = meno nového súboru.
- **Ak R0.2 variant A zamietne → variant C** (§12 D2): háčik sa nepridáva; kým zákazka kľúč nemá, názov ostáva per PC (ako dnes) a do súboru ide pri prvom **premenovaní**
  v hlavičke. Vzhľad okna sa nemení; smoke krok 3 sa prepíše.

### R6 · Volajúci

- `ProductionCore.vepo_payload` (`production_core.rb:222-235`): `project` = `ProjectName.normalize_project_name(model, ProjectName.name(model))`, `default_project`, `source`
  (`ProjectName.name_source`), `merge_18_36` (`ExportSettings`), `file`, `export_names` — **kľúče a poradie bez zmeny**; `pending` a `notice` **zanikajú** (R8, D8).
- `ProductionCore.export_expect_check` → `ProjectName.expect_check(model, data['expect'], merge:)`; `ExportPrep.start` ďalej volá `ExportSettings.refresh` (18 + 36) **pred** bránou —
  poradie z `export_prep.rb:155-189` bez zmeny; komentár bodu 4 („čítanie názvu ho môže preniesť k súboru (`adopt_session_name`)…") prepísať: brána sa volá raz, čítanie nič nezapisuje.
- `default_name_note` → `ProjectName.name_source`, `ProjectName::DEFAULT_PROJECT_NAME`. `name_suffix` (`export_prep.rb:213-216`) bez `pending_name_note`.
- **Všetky 4 exporty** čítajú názov **jedine** cez kontext brány (`ctx.project`) — bez zmeny.

### R7 · Sonda export testu (kompatibilita K aj P)

`su_export_probe.rb:119-120` (§15 F5) — vetvenie **priamo** podľa `defined?(e::ProjectName)` (modul `ExportSettings` odpovedá na `name` ako každý Ruby modul, takže `respond_to?(:name)`
nič nerozlíši a nekvalifikovaná konštanta na K spadne na `NameError`):
```ruby
if defined?(e::ProjectName)            # P (po U1)
  project = e::ProjectName.name(model).to_s
  source  = e::ProjectName.name_source(model, project)
else                                   # K (main pred U1)
  project = es.project_name(model).to_s
  source  = es.name_source(model, project)
end
expect = { 'project' => project, 'merge' => es.merge_18_36, 'source' => source }
```
Komentár hlavičky (`:8`) doplniť. Overenie **oboch vetiev**: headless test sondy nad fake `Noxun::Engine` bez a s `ProjectName` (T11b) a samotný export test (K aj P dobehnú).

### R8 · Odstránenie zápisu názvu do súboru nastavení

**R8.1 `ExportSettings` po U1** (zostáva PC-only — hlavička „Žiadny zápis do modelu" platí):
- **Ostáva:** súbor, brána R-38, `read` / `refresh` / `write_gate` / `update` / `save` / `written?` / `note_block` / `self_repair` / `log_repair`, `merge_18_36`, `save_merge_18_36`, `last_dir`,
  `save_last_dir`, `PROJECT_NAMES_KEY`, `normalize_project_path`, `project_names` (čítanie mapy), guard v `save` proti zápisu mapy (`:255-266`).
- **Nové:** `legacy_project_name(model) → String` = `clean_project_name(project_names[normalize_project_path(model.path)])` pre uložený model, inak `''`; nikdy nevyhodí (`rescue` → `''`);
  **žiadny zápis, žiadny zámok**. Používa `ProjectName.clean_project_name` (jediná normalizácia).
- **Zaniká:** `SESSION_KEY_PREFIX`, `SESSION_KEY_BRIDGE`, `SESSION_BRIDGE_MAX`, `doc_token`, `project_session_key`, `session_key?`, `remember_/forget_/remembered_session_key`,
  `session_keys_for`, `project_key`, `project_name`, `adopt_session_name`, `ADOPT_RETRY`, `ADOPT_RETRY_MAX`, `adopt_retry_key`, `note_adopt_attempt`, `adopt_signature`, `file_digest`,
  `name_pending?`, `effective_project_name`, `save_project_name`, `update_project_names`, parameter `sign:` v `update` a `rejected` (bez `sign` je `rejected` len `note_block`),
  `require 'digest'`, presunuté funkcie R2. **Žiadne delegáty.**
- `doc_key.rb:176-180`: krok `ExportSettings.forget_session_key` zaniká (zoznam cleanupov má jeden krok menej; komentár v `scale_observer.rb:963-967` prepísať).

**R8.2** `ProductionCore`: `pending_name_note`, `pending_name_notice` zanikajú. **R8.3** `studio.js`: vetva `pending` v `jobView`, `jobHeadHtml` a bodke exportov (`:1287-1288`, `:1307`, `:1334-1335`,
`:1341`, `:1460`) zaniká — **zobrazenie v dosiahnuteľných stavoch je bajtovo rovnaké** (D8). `?v=` = nová VERSION.

### R9 · Register knižníc

`library_registry.rb:140-144` poznámka riadku `export_settings`: „posledný priečinok a 18 + 36 (mení súbory VEPO) — každý PC svoje (Michal 2.10.); stará mapa názvov zákaziek
(kľúč = cesta .skp) len na čítanie — od U1 názov žije v .skp". Skupina `model` (`:224-225`): `where` „.skp, slovník NOXUN na modeli (aj názov zákazky `project_name`)".
Guard `test_h16_kniznice.rb` zelený (writers bez zmeny).

### R10 · Dokumentácia (na mieste)

- `docs/architecture/outputs.md`: **nový odsek `### project_name.rb`** pred `### export_settings.rb` (kontrakt R1, čítanie R3, zápis R4, prevzatie R5, `expect` presunutý) ·
  odsek `### export_settings.rb` (`:1154-1261`) prepísať: mapa názvov len na čítanie, zaniknuté odseky „Čakajúci názov", most kľúča sedenia, „`project_names` (ŠT-1a)" skrátiť na
  históriu jednou vetou s odkazom na KRONIKU · `production_core.rb` (vepo payload, vety).
- `docs/ARCHITEKTURA.md` riadok core (`… export_settings · project_name …`) — guard `test_docs_navigacia.rb`.
- `docs/architecture/model-a-identita.md` (DocKey cleanupy — bez `SESSION_KEY_BRIDGE`) · `docs/architecture/construction.md` odsek `scale_observer` (nový háčik v `model_switched`) ·
  `docs/architecture/ui-lifecycle.md` hlavička Štúdia (bez stavu „neuložené k súboru", zápis = operácia v modeli, `on_model_txn` filter).
- `SYSTEM/STANDARD.md`: **§11.6 Názov zákazky (nový, krátky)** — kľúč, prítomnosť rozhoduje, strop 120, zápis = krok Späť, prevzatie pri uložení, starší plugin kľúč ignoruje ·
  §11.5 veta o `vepo_settings.json` („názvy zákaziek") opraviť · §2.1 bez zmeny (nový kľúč nie je entity layout). §13 bez zmeny (žiadna konštanta verzie).
- `docs/architecture/kniznice.md`: **F1 vyriešené dávkou U1 (PR #?)**, riadok `model` v tabuľke §4.
- **Grep zoznamov** (CLAUDE.md checklist): „žiadny zápis do modelu, žiadny krok Späť" pri názve, „šiestich zapisovateľov" / „šiestimi zapisovateľmi" (ostáva päť), `SESSION_KEY_BRIDGE`,
  `name_pending`, `pending_name_note`, `adopt_session_name`, „neuložené k súboru", `ExportSettings.project_name` — v `docs/`, `SYSTEM/` (okrem archívu) a komentároch kódu.

## 7 · Testy a DoD

**Nová sada `tests/pure/test_u1_nazov_zakazky.rb`** (sandbox `Materials.test_dir_override`, fake model s `path`, `title`, `get/set_attribute`, `start/commit/abort_operation`
a záznamom operácií — vzor `test_budget.rb:110`):

- **T1 Poradie čítania:** kľúč neprázdny → model; kľúč `''` + starý záznam → predvolené (starý **nie**); kľúč nie je + starý → starý; nič → meno súboru / `projekt`; neplatná
  hodnota (Integer, Array, výnimka `get_attribute`) → ako „nie je" + 1 riadok logu na model; 200 znakov v kľúči → 120.
- **T2 `name` nič nezapisuje:** 100× `name` → žiadna operácia, bajty `vepo_settings.json` a `.bak` nezmenené, zámok nevzatý.
- **T3 `save`:** zapíše normalizovanú hodnotu v **jednej** operácii „Názov zákazky"; rovnaká hodnota → `:unchanged` bez operácie; zhodná s predvoleným → `''`; kľúč nie je + starý „A" +
  prázdne pole → zapíše `''` a `name` = meno súboru; výnimka v `set_attribute` → `abort`, `:failed`; `vepo_settings.json` a `.bak` **bajtovo nedotknuté** pri každom zápise názvu.
- **T4 Neuložený model:** `save` → kľúč v modeli; „uloženie" (zmena `path`) → `name` ostáva **bez** zápisu a bez kľúča sedenia (náhrada 1b-6a scenára).
- **T5 `adopt_on_save`:** kľúč nie je + starý → priehľadná operácia (argumenty `true, false, true`), `:adopted`, log **až po** `commit`; kľúč je → `:skipped` bez operácie; starý nie je
  + zákazka pluginu → zapíše `''` (F3); cudzí model (bez NOXUN) → `:skipped` bez operácie; `FAULT` → `commit` zavolaný, **`abort_operation` nikdy** (stub ho zaznamená), `:failed`;
  **T5b** Save As s rozdielnymi starými názvami pod starou a novou cestou → názov starej (R5); **T5c dva PC:** PC1 bez starého záznamu uloží (kľúč `''`), PC2 má pod svojou cestou
  starý „Iný" → `name` na PC2 = meno súboru, nie „Iný"; PC1 so starým „A", PC2 so starým „B" → po uložení na PC1 ukáže PC2 „A";
  výnimka → `abort`, `:failed`, **nevyhodí**; starý zhodný s predvoleným → zapíše `''`.
- **T6 `own_txn?`:** true len počas `commit_operation` (stub commit si ho zapíše), po výnimke false (ensure).
- **T7 `on_model_txn`:** commit s `own_txn?` → epocha bez zmeny; undo/redo/abort → +1; cudzí commit → +1.
- **T8 Okno headless** (`StudioDialog.send(:do_set_vepo_opts, …)`, stuby vzoru `test_h7a_export_settings.rb` T-A8): `:ok`/`:unchanged`/`:failed` → presný text a farba, echo vždy, generácia
  bez zmeny; zastaraná generácia s `project` → veta H7a, **žiadny** zápis do modelu; cudzí dokument → žiadny zápis; `merge` bez zmeny.
- **T9 Exporty:** `expect` z payloadu → export prejde a mená = T0c; kľúč v modeli zmenený po pushi (simulácia Ctrl+Z) → odmietnutie vetou „Okno ukazovalo …"; automatický → automatický
  tolerancia bez zmeny; `name_suffix` bez vety o čakajúcom názve.
- **T9b `merge_18_36` v `expect_check` (F2):** všetky 4 exporty s platným `expect` nad modelom s kľúčom prejdú (žiadne `EXPECT_FAILED`); VEPO s nesúladom 18 + 36 odmietnuté.
- **T10 Payload:** `vepo` = kľúče `project, default_project, merge_18_36, source, file, export_names` v tomto poradí (bez `pending`, `notice`); `project` normalizovaný.
- **T11 Guardy:** v `ui/` a `core/` žiadny výskyt zaniknutých mien (R8.1 zoznam, `pending_name_note`, `project_key`); `ExportSettings` nevolá `set_attribute` ani `start_operation`;
  `ProjectName` neobsahuje `JsonFileStore.write(`; `legacy_project_name` nevolá `update`/`with_catalog_lock`; jediné `set_attribute(` v `project_name.rb` sú v `save` a `adopt_on_save`;
  `main.rb` a `helper.rb` načítanie; `doc_key.rb` bez `ExportSettings`; `su_export_probe.rb` rozlišuje API (R7); **T11b** sonda nad fake modulom bez `ProjectName` (vetva K) aj s ním (vetva P) zloží `expect` bez výnimky; v ceste `adopt_on_save`
  nie je `abort_operation` a medzi `start_operation` a `commit_operation` nie je volanie logu; `FAULT` je v produkcii false.
- **T12 Golden:** T0a, T0c **bez regenerácie** zelené; T0b-U1 zelené.
- **Prepis existujúcich:** `test_h7a_export_settings.rb` (T-A5 most, T-A10, T-A11 a guardy kľúča sedenia **zanikajú**; matica R-A2 pre 18 + 36 a `last_dir` ostáva; zápis názvu
  v matici nahradí T3 „súbor nedotknutý" aj pri poškodenom súbore — názov sa uloží do modelu aj pri `:blocked` súbore nastavení), `test_h7a_golden.rb` (starý T0b preč),
  `test_h7b_nazov_zakazky.rb` (T-B7 kľúče, T-B12 preč), `test_st1a_studio.rb`, `test_doc_key.rb:198`, `test_h17_export_prep.rb` + `h17_harness.rb`, JS `test_h7b_hlavicka.js`
  (vetva `pending` preč, ostatné tri podoby **bajtovo** bez zmeny), `test_h14_studio_sekcie.rb` (3 pôvodné kľúče bez zmeny).

**Mutácie (≥ 12, každá zhodí test):** M1 `name` číta starý záznam aj pri kľúči `''` · M2 `name` zapisuje (adopt pri čítaní) · M3 `save` bez operácie · M4 `save` bez `abort` pri výnimke ·
M5 `:unchanged` otvorí operáciu · M6 zhodný s predvoleným sa zapíše ako text · M7 `adopt_on_save` bez priehľadnosti (`start_operation(name, true)`) · M8 `adopt_on_save` prepíše existujúci
kľúč · M9 `adopt_on_save` vyhodí · M10 `on_model_txn` filtruje aj undo · M11 `own_txn?` bez `ensure` · M12 zápis názvu siahne na `vepo_settings.json` · M13 `expect_check` číta
`legacy_project_name` priamo (obíde model) · M14 strop 120 vypnutý pri zápise · M15 sonda R7 len s `ProjectName` (K spadne) · M16 `adopt_on_save` volá `abort_operation` · M17 log vnútri transakcie · M18 bez zápisu `''` pri prázdnom starom (F3) ·
M19 `expect_check` s nekvalifikovaným `merge_18_36` · M20 Save As berie názov novej cesty.

**DoD:** testy + mutácie (zoznam a výsledok do PR) · headless + **všetky** JS sady (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) · encoding guard · in-SU (§8) ·
export test `P == K` · fotky `-Record` · docs (R10) · §11.

## 8 · In-SU

**Brána mergu** (akcia panela zapisujúca do modelu + undo + observer). Nové scenáre v `su_runner.rb` (blok ST-1a prepísať, S19), nad kópiou `ENGINEtests.skp`:

1. Premenovanie cez `do_set_vepo_opts` → kľúč v modeli, `ProjectName.name` = text, **presne jeden** krok Späť „Názov zákazky", `model.modified?` true, generácia bez zmeny,
   epocha Štúdia bez zmeny (R4.3); `Sketchup.undo` → predošlý názov; `redo` → nový.
2. Rovnaký text znova → žiadny krok Späť.
3. Prázdne pole → kľúč `''`, názov = meno súboru.
4. *(Neuložený model runner nesimuluje — kryje ho headless T4 a smoke krok 4.)*
5. Prevzatie: do sandboxu `vepo_settings.json` vložiť starý záznam pre cestu kópie, kľúč zmazať (`delete_attribute`), `model.save` → kľúč = starý názov, `modified?` po uložení false,
   zásobník Späť bez nového kroku (podľa R0.2); znovuotvorenie kópie (ak runner vie — inak čítanie atribútu a `model.path`) → názov z modelu.
6. Kľúč existuje + starý záznam iný → `model.save` nič nezmení. Model bez kľúča a bez starého záznamu → po `model.save` kľúč `''` (F3).
7. 4 exporty cez `ExportPrep` s `expect` z payloadu (vzor existujúceho SMOKE) → mená podľa kľúča v modeli.
8. **Vynútená chyba (B1):** `ProjectName::FAULT[:adopt] = true`, úprava geometrie (operácia „X") → `model.save` → geometria „X" **zachovaná** (rozmer,
   transformácia), súbor uložený, log chyby, `Sketchup.undo` vráti „X"; `FAULT` späť na false v `ensure` runnera.

Upratovanie: runner pracuje so **skutočným** `%APPDATA%` — vložený starý záznam po sebe zmaže **cez strikné čítanie a zápis mapy v teste** (nie cez plugin — plugin mapu už nezapisuje;
pomocník runnera s `JsonFileStore` pod `Materials.with_catalog_lock`), kľúč v modeli vráti. Beh `scripts\run_su_tests.ps1 -CloseWhenDone` na finálnej hlave; PR uvedie hlavu.

## 9 · Riziká

1. **Háčik uloženia sa správa inak, než predpokladáme** (zápis sa neuloží, zákazka ostane „zmenená", nový krok Späť, pád pri autosave, **chyba zruší úpravu používateľa**) — S21, §15 B1.
   Ochrana: v háčiku **žiadny abort**, chyby a log mimo transakcie (R5), sonda **R0.2 P1–P6 pred** kódom,
   variant C pripravený (D2), háčik nikdy nevyhodí ani nezastaví uloženie.
2. **Kópia zákazky („Uložiť ako") si nesie názov** — dve varianty s rovnakým názvom by VEPO exportovali do priečinka s rovnakým menom (dnes kópia dostane meno súboru). R20 (vedome prijaté), smoke
   krok 6; tvrdá ochrana = G-05.
3. **Starší plugin na druhom PC kľúč ignoruje** → pomenuje podľa svojej mapy alebo súboru. Ochrana: R14 (rovnaká verzia), STAV „Kompatibilita", smoke krok 7.
4. **Golden T0b zaniká** — vedomá zmena; bez náhrady by nič nestrážilo bajty súboru pri 18 + 36. Ochrana: T0b-U1 (R0.1) a T3 „súbor nedotknutý".
5. **Ctrl+Z vráti názov, hlavička to neukáže** do „Obnoviť" — export s `expect` sa zastaví neutrálnou vetou (fail-closed, T9); echo po Späť mimo scope (D6).
6. **Sonda export testu** po zmene API — K alebo P spadne na `NoMethodError`. Ochrana: R7, guard T11, M15.
7. **„Obnoviť" zožltne po premenovaní** pri asynchrónnom `onTransactionCommit` — kozmetické; R4.3 podmienka, R0.2 P5.
8. **Odstránenie mechanizmu kľúča sedenia** zmaže ochranu, ktorá by ešte niečo kryla. Overené: kryla len názov neuloženého modelu (S4) — ten teraz žije v modeli (T4); `DocKey`
   ostáva nezávisle (S5 cleanup DocKey bez zmeny).
9. **Dve inštancie SketchUpu s tým istým súborom** — dnes zdieľali mapu pod zámkom; po U1 má každá svoj model a vyhrá posledné uloženie (štandardné správanie SketchUpu). Priznať v docs.
10. **Veľkosť diffu** (presun + odstránenie) — poistka §2 (rozdelenie U1a/U1b).

## 10 · Smoke checklist pre Michala (funkčne, krok za krokom)

Pred smoke: aktualizovať plugin na **oboch PC** na novú verziu a zavrieť všetky okná SketchUpu.

1. Otvor rozrobenú zákazku, ktorá už mala názov (napr. „Kuchyňa Novák"). Hlavička Štúdia ukáže **ten istý názov ako predtým**. Zavri SketchUp → **neopýta sa** na uloženie
   zmien (otvorením sa nič nezmenilo).
2. Hlavička: klik na názov → „Kuchyňa Novák 2" → Enter. Zelené „Názov zákazky: Kuchyňa Novák 2 · platí pre…"; v titulku okna SketchUpu pribudne hviezdička; tlačidlo **„Obnoviť" nezožltne**.
   Ctrl+Z → v ponuke Úpravy bolo „Späť Názov zákazky"; „Obnoviť" zožltne, klik naň → hlavička „Kuchyňa Novák". Ctrl+Y → späť „Kuchyňa Novák 2".
3. Otvor inú staršiu zákazku s názvom, nič nemeň, **Ctrl+S**, zavri, otvor znova → názov ostal. *(Ak by dávka išla variantom C, tento krok znie: premenuj ju v hlavičke a ulož.)*
4. Nový model (neuložený): zadaj názov „Test U1" → Ctrl+S ako `test_u1.skp` → hlavička „Test U1" (nie „test_u1"). Zavri a otvor → „Test U1".
5. Vyexportuj VEPO, CSV kovania, XLSX rozpočtu a Cenovú ponuku → priečinok a súbory sa volajú podľa názvu v hlavičke, **rovnako ako pred aktualizáciou** pri tom istom názve.
6. „Uložiť ako" `test_u1_kopia.skp` → kópia ukáže „Test U1" (názov ide so zákazkou — R20).
7. **Lucia:** skopíruj `test_u1.skp` (uložený v kroku 4) na jej PC, otvor → hlavička „Test U1", VEPO export do priečinka `test_u1`. Zákazka, ktorú si od aktualizácie neuložil, u nej
   ukáže meno súboru — ulož ju u seba a pošli znova.
8. Prepínač „18 + 36" a posledný priečinok exportu sa správajú ako doteraz (každé PC svoje).

## 11 · Checklist uzáveru

Bump patch (`noxun_engine.rb` + `noxun_engine/main.rb`, dnes 0.18.1 → ďalšia voľná) + **všetky** `?v=` v `ui/*.html` → testy zelené (headless + všetky JS + encoding) → in-SU PASS →
export test `P == K` → fotky `-Record` → odseky architektúry na mieste (R10) + riadok `ARCHITEKTURA.md` → **Grep zoznamov** (R10) → `kniznice.md` F1 ✅ → STANDARD §11.5, §11.6 →
**prepis `SYSTEM/STAV.md`** (aj „Kompatibilita": názov zákazky v .skp — starší plugin ho ignoruje, aktualizovať obe PC) → odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md`
(výrobná dávka: mutácie, počty testov, in-SU hlava, export test, výsledok R0.2) → `SYSTEM/PLAN.md` blok UPDATE riadok U1 **✅ PR #?** → `SYSTEM/DOGFOODING.md` D-48: časť „názov
zákazky" hotová (D-48 ostáva otvorený do uzáveru bloku) → číslo PR samostatným commitom. Implementátor skopíruje surový výstup auditu (`AUDIT_U1_raw.md`) do `SYSTEM/zdroje/bloky/UPDATE/`.

## 12 · Rozhodnutia autora — potvrdené orchestrátorom 17.10.2026

> **Potvrdenie:** D2 áno (variant A, C ako záloha podľa výsledku R0.2) · D8 áno (odstrániť `pending`/`notice` vrátane JS vetvy) · D1, D3–D7, D9–D11 áno ako navrhnuté.


- **D1 Nový modul `ProjectName`** (nie rozšírenie `ExportSettings`): `ExportSettings` ostáva „nastavenia počítača bez zápisu do modelu"; názov je údaj zákazky. Presun `expect_*`
  a normalizácie **bez delegátov** (H7 D1). Cena: prepis volajúcich a testov (R6, §7).
- **D2 Prevzatie pri uložení (variant A)** podľa reconcile („pri prvej zmene/uložení"). **Variant C** (bez háčika; názov ide do súboru až premenovaním v hlavičke) je záloha, keď R0.2
  zlyhá. **Variant B** (zápis pri otvorení) zamietnutý (A4 B12). **Variant „zápis pri prvej ľubovoľnej operácii pluginu"** zamietnutý (47 miest `start_operation`, krehké).
  *Pri variante C* treba drobnú úpravu JS: Enter na nezmenenom názve, ktorý je len v mape PC, zapíše do modelu (dnes „nič") — server to rozlíši cez `ProjectName.origin`; bez zmeny
  vzhľadu. Rozhodne orchestrátor po R0.2, Michalovi sa oznámi (smoke krok 3).
- **D3 Starú mapu nemazať** (len čítať): vratné, starší plugin na tom PC nájde názvy, žiadna zápisová cesta navyše.
- **D4 Bez `std` a bez markera** pri kľúči názvu: jednoduchý String; starší plugin ho ignoruje (pomenuje inak, čísla sa nemenia) — kryje R14. Bump `Store::STD` by zbytočne zablokoval prestavbu.
- **D5 Zdroj názvu (`origin`) nejde do payloadu** — okno sa nemení (mockup r. 170). Tooltip „Model ešte nie je uložený — názov sa pri prvom uložení prenesie na súbor" ostáva pravdivý.
- **D6 Späť/Znova názvu bez echa hlavičky** (len zožltnuté „Obnoviť" + fail-closed `expect`). Echo by znamenalo zásah do undo vetvy observera — mimo scope.
- **D7 Kľúče sedenia v starej mape sa nečítajú** (mŕtve po reštarte pri aktualizácii; D-52 restart latch).
- **D8 Odstrániť `pending`/`notice` aj JS vetvu** (stav sa už nedá dosiahnuť). Alternatíva: nechať kľúče s konštantou `false`/`''` a JS bez zmeny — menší diff, mŕtvy kód; neodporúčam.
- **D9 Zápis názvu = krok Späť „Názov zákazky" a hviezdička** — názov je teraz údaj zákazky (rovnako ako zmena rozpočtu, `BudgetStore.write!`).
- **D10 Jeden PR, poistka U1a/U1b** (§2).
- **D11 Zápis názvu pri poškodenom `vepo_settings.json`** prejde (súbor sa ho netýka) — dnešné `:blocked` pri názve zaniká; 18 + 36 ďalej `:blocked`.

## 13 · Otázky pre Michala — uzavreté

- **Q1 — uzavreté (R20, Michal 17.10.2026):** kópia zákazky („Uložiť ako") **nesie ten istý názov**; riziko rovnakého priečinka VEPO pri exporte oboch variantov
  do toho istého miesta je **vedome prijaté** (tvrdá ochrana = G-05, N2). Iné otvorené otázky: žiadne.

## 14 · Nálezy mimo scope

- **N1:** echo hlavičky Štúdia po Späť/Znova (D6), aj pre rozpočet — zásobník UI. **N2:** G-05 (export do datovaného priečinka) natrvalo vyrieši riziko 2 / R20.
- **N3:** mŕtvu mapu `project_names` v `vepo_settings.json` upratať (s doprednou bránou a `std`), keď na oboch PC nebude plugin starší než U1.
- **N4:** `ProjectName` = jadro budúcej **karty zákazky** (G-02) — ďalšie kľúče na modeli rovnakým kontraktom.

## 15 · Audit návrhu — zapracovanie (Codex `gpt-6-astra`, 17.10.2026) — 1 BLOCKER · 4 FIX · MÁ PREDNOSŤ

Surový výstup: [AUDIT_U1_raw.md](AUDIT_U1_raw.md). Všetky nálezy sú platné (F2 a F5 auditor potvrdil Ruby sondou; B1 vyplýva z dokumentácie `Model#abort_operation`).

| # | Nález | Dispozícia | Kde v package |
|---|---|---|---|
| **B1** BLOCKER | `abort` priehľadnej operácie v háčiku uloženia zruší aj pripojenú úpravu používateľa | v háčiku **nikdy `abort_operation`**: všetko overiteľné mimo transakcie, v transakcii len `set_attribute` so zachytenou chybou, `commit_operation` vždy; logovanie až po transakcii; testovací šev `FAULT`; in-SU vynútená chyba so zachovaním geometrie. `ProjectName.save` (vlastná, nepripojená operácia z hlavičky) `abort` ponecháva | R5 body 1–3, R0.2 P6, T5, T11b, M16–M17, in-SU 8, riziko 1 |
| **F2** FIX | presunutý `expect_check` volá nekvalifikované `merge_18_36` → `NameError` → `EXPECT_FAILED` vo všetkých 4 exportoch | explicitne `ExportSettings.merge_18_36` | R2, T9b, M19 |
| **F3** FIX | bez starého záznamu na odosielajúcom PC sa nič nezapíše; druhé PC potom použije svoj historický názov | pri prvom uložení **zákazky pluginu** bez kľúča sa zapíše aj `''` (autorita modelu pre automatický názov). Spresnenie autora: len zákazky pluginu (`noxun_job?`), aby plugin nezapisoval do každého uloženého `.skp` | R5 bod 1, in-SU 6, T5, T5c (dva PC s rozdielnymi mapami), M18 |
| **F4** FIX | R0.2 nepokrýva podmienky A (nový krok Späť, autosave, Undo + Redo pred zatvorením, `model.path` pri Save As, rozdielne staré názvy) | R0.2 prepísaná na scenáre P1–P6 s tvrdým pravidlom „nový krok Späť alebo zmena geometrie = A zakázané"; Save As berie cestu originálu (`adopt_path`, pamäť poslednej známej cesty, ak callback vidí novú); autosave ručne Michal, ak sa nedá automatizovať | R0.2, R5 Save As, T5b, M20 |
| **F5** FIX | sonda R7 na K spadne (`respond_to?(:name)` je na module vždy true, konštanta neexistuje) | vetvenie priamo podľa `defined?(e::ProjectName)`, test oboch vetiev | R7, T11b |

**Dopad na odhad:** nová logika +~30 riadkov (`noxun_job?`, `adopt_path` s pamäťou cesty, šev `FAULT`), testy +~80; rez a trieda bez zmeny. Výsledok R0.2 sa zapíše ako §16.
