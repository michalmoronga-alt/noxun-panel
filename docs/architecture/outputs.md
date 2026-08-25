# Výstupy — kontrola, kusovník, VEPO, nákup a rozpočet

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Kontrolný semafor a zdieľané čisté jadro výstupov zákazky. Kontrakt plánu, z ktorého všetky výstupy čítajú, žije v [model-a-identita.md](model-a-identita.md) (`build_plan.rb`,
`part_keys.rb`); UI sekcie Štúdia, ktoré tieto výstupy zobrazujú, sú v [ui-lifecycle.md](ui-lifecycle.md).

### validation.rb

**kontrolný semafor (V0.5-D):** RED = materiál mimo katalógu / hrúbkový drift / nezmestí sa na platňu (s rešpektom smeru dekoru) / ABS páska hrany mimo katalógu (2A-2 `abs_missing`
— len keď volajúci dodá ABS katalóg cez `edges:`) · ORANGE = čelo/voľná doska bez ABS „skontroluj" / vypnuté kovanie (owner_part_key identita) / build warnings. JEDINÝ kanonický
zoznam; deterministický dedup + counts VÝHRADNE zo servera; sekcia KONTROLA v Štúdiu s klik-selectom cez stabilnú identitu a fallbackom na vlastníka; sekcia KONTROLA vo VEPO LOGu;
**RED nikdy neblokuje export**.

### production_core.rb — zdieľané čisté jadro výstupov zákazky (ŠT-1a PR A)

kusovník, súpisy platní/ABS a VEPO export sa sťahovali z okna Výroba do nového okna **Štúdio**; aby obe okná čítali **tie isté čísla**, čistí pomocníci prešli do jedného modulu
`Noxun::Engine::ProductionCore` (`module_function`).

**Od ŠT-1c PR B3, keď okno Výroba zaniklo, je jadro JEDINOU implementáciou** — Štúdio aj rail Inspectora ho volajú priamo.

Sú tam: **VEPO rodina** (`vepo_settings`/`save_vepo_settings` nad `%APPDATA%\NOXUN\Engine\vepo_settings.json`, `vepo_materials` s celou kaskádou rozlíšenia labelov,
`vepo_base_label`, `vepo_disambiguate`/`vepo_disambiguate_variants`, `vepo_group_key`, `vepo_edge_thicknesses`, `default_project_name`), **mapy katalógov** pre `Validation.run`
(`sheets_map` → `{}` pri chybe, `edges_map` → **`nil`** pri chybe, lebo prázdna mapa by falošne označila každú olepenú hranu), identita dokumentu `model_guid` a **výberové
resolvery** klik→entita (`pids_for_problem` vrátane fallbacku na vlastníka pri nepostavenom dielci, `pids_for_duplicate` pre D-103, `refs_for` — od ŠT-2d aj vetvy
`material_key`/`abs_key` s nepovinným `owner_id`, ktoré hľadajú dielce podľa **efektívneho materiálu z BOM** pre „Kde sa používa"; detail v odseku sekcie MATERIÁLY; **od ŠT-3b-2a
`pids_for_override`** — oko pri jantárovom riadku sekcie Pravidlá adresuje dvojicou **(owner_id, part_key)** a **znovupoužíva telo `pids_for_problem`** [prázdny kľúč = celý
korpus]; vetva `rule_ref` v `do_select` je vlastná zámerne — override v kusovníku vlastný riadok mať nemusí, napr. vypnuté kovanie; od ŠT-3b-2b beží **bez `fresh_collect`** — hľadá
podľa identity, takže plný sken modelu aj dedup tik v ňom boli čistá réžia).

**ZÁVÄZNÝ kontrakt modulu: žiadny okenný stav** — `@dialog`, `@generation` ani `@pending_*` sem nepatria (dve okná nad jedným jadrom by si ich prepisovali); stráži to guard test,
ktorý v `production_core.rb` nepripustí ani jednu inštančnú premennú. Do ŠT-1c PR B3 si `ProductionDialog` ponechával **tenké obaly s pôvodnými menami, signatúrami AJ
privátnosťou** (aby bol refactor bez zmeny správania); s oknom zanikli a volajúci — panel, pure testy aj in-SketchUp runner — idú na jadro priamo. Loader (`main.rb`) načítava jadro
**PRED** oknom Štúdio, ktoré ho volá.

**PR B dávky ŠT-1a sem doplnil aj TELÁ akcií** — `fresh_collect`, `hardware_expansion`, `control_suffix` a hlavne `do_export`/`do_select`: obe okná robia presne to isté, len s
vlastným stavom, takže okno odovzdáva svoj kontext **explicitne** (`generation:` — token guardu B4 · `status:` — lambda do TOHO okna · `repush:` — „obnov, ak žiješ"). Dva takmer
rovnaké exporty by sa časom rozišli a rozdiel by sa ukázal až na výrobnom výstupe.

**Pozor — `fresh_collect` NIE JE úplne read-only:** volá `CabinetBuilder.dedup_copies` / `BoardBuilder.dedup_copies`, ktoré pri nájdenej kópii so zdieľaným ID otvoria **reálnu
operáciu** (a teda krok Späť). Je to **prevzaté správanie okna Výroba** — dedup tik musí bežať pred zberom, inak BOM zlieva vlastníkov a klik-select je nejednoznačný (GH #48 P2).
Bežná zákazka bez čerstvých kópií nevyrobí nič; keď kópie sú, undo krok patrí dedupu, nie výberu (in-SketchUp `run_st1a` overuje, že klik sám o sebe žiadny krok nepridá).
`do_select` navyše pozná príznak **`focus_inspector`** (ceruzka riadku Kusovníka, Š3): po výbere zdvihne Inspector cez `Panel.bring_to_front` — **nikdy ho neotvára**, výber sa tým
nemení a do modelu sa nezapisuje nič.

**`project_names` (ŠT-1a, audit #1):** názov projektu je od tejto dávky **serverový údaj** — mapa v `vepo_settings.json` (nastavenie POČÍTAČA, žiadny zápis do modelu, žiadny krok
Späť).

**Kľúčom je NORMALIZOVANÁ CESTA súboru, nie `model.guid`** — SketchUp guid **mení po každom uložení** modelu, takže na guid kľúči by sa názov po Ctrl+S ticho stratil a v súbore by
rástli mŕtve záznamy (nález review P1). Normalizácia je `\`→`/` + `downcase` (Windows nerozlišuje ani veľkosť písmen, ani smer lomítka).

**Neuložený model cestu nemá** a dostane náhradný kľúč `guid:<guid>`, ktorý platí len v rámci sedenia; čítanie naň padá ako na záložku (pomenoval som Untitled a potom ho uložil) a
**prvý zápis s platnou cestou ho zmigruje** — záznam sadne na cestu a guid kľúč sa zmaže. Prázdna hodnota **aj hodnota zhodná s defaultom zmaže záznam**, takže sa pomenovanie vráti
na názov `.skp` a premenovanie súboru sa v okne prejaví samo. Číta ho **všetky štyri exporty** (VEPO, CSV kovania, XLSX rozpočtu, XLSX cenovej ponuky) — z DOM sa `project`
**prestal posielať**, inak by dve okná mali dve pravdy a tá istá zákazka by sa v dvoch výstupoch volala inak. `merge_18_36` ostáva globálny a číta sa rovnakou cestou.

**`materials_meta`/`edges_meta` (audit #4)** sú kontrakt skupín Kusovníka: per `material_id` (resp. `abs_id`) label, katalógová farba ako **pole `[r,g,b]`** (nie CSS reťazec —
prevod robí klient, ktorý farbu kreslí), hrúbka a príznak UNI; materiál mimo katalógu sa pomenuje **svojím ID** a farbu nedostane (radšej žiadna vzorka než náhodná).

**`rows_with_roles`** dopĺňa voliteľný stĺpec „Rola" **read-only obohatením** — záznamy sa zoskupia TÝM ISTÝM `Bom.row_key`, akým vznikli riadky, pretože pridať rolu do kľúča
agregácie by zmenilo kusovník **aj VEPO** (a párovanie beží cez Ruby hash: kľúč riadku je POLE, v JSON by sa už nespárovalo). SK názvy rolí sú `ROLE_LABELS` — jedna autorita, JS
žiadny preklad enumu nemá.

**ŠT-1b sem pridala celý zvyšok KONTROLY: `control_payload`** (Validation.run nad čerstvým zberom **+ zlúčenie s upozorneniami rozpočtu cez `Validation.with_budget`**) je **jediné
miesto, kde vzniká číslo semaforu** — číta ho sekcia Kontrola v Štúdiu, badge navigácie **aj `do_export`** (status aj sekcia KONTROLA vo VEPO LOGu; do review #1 mal export vlastný
`Validation.run` **bez** rozpočtových nálezov a hlásil preto iné číslo než semafor), takže žiadne z týchto miest nemôže ukázať vlastné číslo; s ním sem prešli aj `budget_payload` a
`hardware_catalog_items` (rozpočet sa počíta kvôli svojim ORANGE nálezom, hotový odhad platní sa mu odovzdáva, aby nevznikol druhý výpočet).

**`replace_uni`** (skratka „Nahradiť UNI…" → `MaterialsDialog.request_replace_uni`) a **zdieľané telá prepínačov** `edge_check_guard` (dostupnosť Overlay API + `identity_guard`) ·
`identity_guard` (generácia okna + dokument — zdieľa ho aj kresba, ktorá si dostupnosť overuje **vlastnú** a hlási ju vetou o kresbe, nie o hranách) · `do_edge_check` ·
`do_edge_check_option` · `do_grain_check` + texty statusov (`edge_check_status`, `EDGE_OPTION_LABELS`/`edge_check_option_status`, `grain_check_status`, `grain_part_plural`). Okno
odovzdáva svoj stav **explicitne** — okrem `generation:`/`status:`/`repush:` aj **`echo:`** (malý push stavu prepínača do TOHO okna) a pri kresbe `grain_echo:`; guard tak nemá
**žiadny okenný stav** a obe okná sú nad ním len obaly.

Názvy stavov majú **jediný zdroj** `ProductionCore::EDGE_OPTION_LABELS` — rail Inspectora aj `js/edge_menu.js` ich čítajú odtiaľ (do ŠT-1c PR B3 sa rail pýtal cez tenký obal okna
Výroba).

**ŠT-1c PR A sem pridala dve veci zo zaniknutého tabu Kovanie:** `hardware_labeled` (generika kovania obohatená o SERVEROVÉ texty `label` — `HardwareRules.label_for` — a
`params_label` — „rez 597 mm", D-90; obohatenie zmizlo z `push_state` okna Výroba, aby dva klienty nemohli mať dve pravdy o tom, ako sa položka volá) a **telo `do_hw_csv`**
(nákupný CSV zoznam; rovnaký tvar ako `do_export` — `generation:`/`status:`/`repush:` — takže okno je nad ním len obal).

**VEDOMÁ ZMENA (audit #15):** CSV kovania dostalo **generačný guard**, ktorý predtým nemalo — je to nákupný dokument a nesmie vzniknúť z okna so zastaranými dátami (ostatné tri
exporty ho majú odjakživa); odmietnutie nie je tiché, okno sa obnoví a povie to.

**ŠT-1c PR B1 sem presunula CELÝ ROZPOČET — a s ním JEDINÚ cestu, ktorá zapisuje do modelu:** `do_budget` (12 operácií cez `apply_budget_op` → `BudgetStore`, jedna mutácia =
**jeden krok Späť**), oba XLSX exporty (`do_budget_xlsx`, `do_cp_xlsx` + `cp_warnings`/`cp_status`/`fmt_eur`), `budget_open_url` (adresa sa **dohľadáva v modeli** podľa ID položky
a znova sanitizuje — z klienta nechodí), `open_budget_settings` a celý beh **prepočtu cien** (`do_price_refresh` + `price_refresh_reject`/`_emit`/`_targets`/`_cancel`/`_status`).

Tvar odovzdania stavu je ten istý ako všade inde, len bohatší: okrem `generation:`/`status:`/`repush:` aj **`result:`** (echo `NX.budgetResult(op, ok)` **PRED** čerstvým payloadom
— odmietnutý zápis nesmie zavrieť rozpísaný draft, GH #138 P2) a pri prepočte cien **`emit:`** (fázové okno), **`alive:`** (beh visí na TEJ ISTEJ inštancii okna) a **`after:`**
(refresh ciest po dobehnutí — ceny sa menia globálne, takže čerstvé čísla dostanú katalóg materiálov, panel aj katalóg kovania; piaty prijímateľ — okno Výroba, ktoré potrebovalo
čerstvé `counts` pre svoj ⚠ chip — zanikol s oknom v ŠT-1c PR B3). Guard mutácie je zámerne **tolerantný na prázdny `model_guid`** (starší cachovaný DOM), ale nezhodné ID odmieta.

Kontrakt stráži `tests/pure/test_st1a_core.rb`, `tests/pure/test_st1a_studio.rb`, `tests/pure/test_st1b_kontrola.rb`, `tests/pure/test_st1c_nakup.rb` a
`tests/pure/test_st1c_rozpocet.rb`.

## Bez vlastného odseku

### bom.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Zber modelu a agregácia riadkov kusovníka (`Bom.collect`, `Bom.compute`, `Bom.row_key`); správanie je popísané v odsekoch, ktoré ho volajú.

### sheet_estimate.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Odhad počtu platní (2B-1/D-43) — zmienky v odseku `production_core.rb` a v sekcii Kusovník v [ui-lifecycle.md](ui-lifecycle.md).

### budget.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### budget_store.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### price_refresh.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Beh prepočtu cien voči Demosu — zmienky v odseku `production_core.rb`.

### supplier_settings.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Globálne nastavenia dodávateľa (sadzby, režimy €/€€/€€€, prah veku cien); UI je v [ui-lifecycle.md](ui-lifecycle.md), odsek o sekciách `sup`/`bset`/`about`.

### vepo_export.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### cp_export.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### xlsx_writer.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_
