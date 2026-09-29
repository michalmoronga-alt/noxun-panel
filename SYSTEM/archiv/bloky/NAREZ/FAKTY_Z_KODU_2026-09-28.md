# Blok 2 · Nárezový plán — fakty z kódu (28.9.2026, main `68aef64e`, v0.15.0)

> Stav: **fakty z kódu** (dvaja rešeršéri kódu, len čítanie) — podklad pre koncept, krížový audit a packages, **nie zadanie**. Každé tvrdenie má
> `súbor:riadok`; NEOVERENÉ = rešeršér nevidel v kóde. Časť **A** = vstup a dáta plánu (SheetEstimate, kusovník, smer dekoru, formát platne, Kontrola,
> výkon, invarianty); časť **B** = Štúdio, Rozpočet, nastavenia, kreslenie, výber v modeli, testy UI. Prekryvy (kerf/orez, `oversize`) sú zámerne v oboch.

## Časť A — FAKTY A — vstup a dáta pre Nárezový plán (rešerš kódu)

Repo `C:\APP DEV\RUBY\ENGINE`, main 68aef64e, plugin v0.15.0, 28.9.2026. Len čítanie. Skratka `nx/` = `noxun_engine/`.
Čo som nevidel v kóde ani v dokumentoch, je označené **NEOVERENÉ**.

### 1 · SheetEstimate (D-19) — `nx/core/sheet_estimate.rb`

- Čistý modul bez SketchUp API. `estimate(rows, sheet_sizes: {}, k_min: 1.10, k_max: 1.25, uni_ids: {})` (sheet_estimate.rb:13-15, 39).
- **Aké polia riadku číta:** `material_id` (prázdne → riadok preskočí, :43-44), `length`, `width`, `quantity` (plocha = l × w × q / 1e6; plocha ≤ 0 → preskočí, :45-46),
  voliteľne `material_source {material_id, multiplier}` — započíta sa len úplná väzba s `multiplier.to_i >= 2` (:47-48).
  **Nečíta** `grain_direction`, hrany, hrúbku ani identitu dielca.
- **Duplák:** plocha × multiplier sa pripíše **zdrojovému** `material_id`, duplák vlastný riadok nemá. `quantity` zdroja počíta len vlastné kusy,
  `doubled_m2` je už po × mult, `doubled_quantity` = kusy duplákových dielcov (bez × mult) (:27-35, 48-58). Na obdĺžniky sa **nerozvíja** — pracuje len s plochou.
- **Výstup:** pole hashov (jeden na nákupný materiál), zoradené podľa `material_id` — poradie vstupu nehrá rolu (:61-77).
  Kľúče: `material_id, m2 (3 desatinné), quantity, sheet_size [l,w], sheet_m2, count_min, count_max, fallback`, voliteľne `doubled_m2/doubled_quantity`, `uni: true`.
  `count_min/max = ceil_tenth(m2 × k / sheet_m2)` je **desatinné číslo** (napr. 0,3), nie celý počet platní (:67-68, 83-85).
- **Fallback:** `sheet_size_for` — pár musí byť pole dĺžky 2 s konečnými kladnými číslami, inak `[2800.0, 2070.0]` a `fallback: true` (:13, 88-104).
  Nikdy nedelí nulou. Neplatné alebo obrátené koeficienty → predvolené hodnoty (:108-113).
- **Volajúci (grep, 3 miesta v kóde):**
  1. `nx/ui/studio_dialog.rb:1606-1609` (`push_state`) — jeden výpočet pre Kusovník aj Rozpočet. `sheet_sizes` zo `ProductionCore.sheets_map`, `uni_ids` cez `Materials.uni?`.
     Výsledok ide do payloadu `sheet_estimate` (:1641), do súčtov `plates_min/max` (súčet count_min/max, :1738-1746) a do `budget_payload` (:1620).
  2. `nx/ui/production_core.rb:2374-2386` (`budget_payload`) — keď odhad nedostane, spočíta si ho sám. Takto idú **oba cenové exporty** (volajú s `estimate = nil`, :3183, :3261),
     VEPO export kvôli Kontrole (:1958) aj `price_refresh_targets` (:3433-3436).
  3. `nx/core/budget.rb:104, 834-843` (`estimate_for`) — headless cesta, keď `Budget.compute` hotový odhad nedostane.
- **Čo z výstupu číta rozpočet:** `materials_section` (budget.rb:194-229) — `sheet_size`, `sheet_m2`, `m2`, `fallback` (poznámka + `estimated`), `uni`, `doubled_*`.
  Počet platní je `plates_of = ceil(count_max)` (:255-258). Cena €/m² sa prepočíta na €/platňu z presných rozmerov formátu (`price_per_plate`, :233-250).
  `services_section` (:358-364): porez = súčet platní, montáž = platne × `montaz_m2_per_plate`, lepenie duplákov = súčet `doubled_quantity`.
  `pd_present?` (:393) a `stale_scan` (:562-568) čítajú `material_id`. JS sekcie Platne číta `sheet_size`, `count_min/max`, `uni`, `doubled_*` (nx/ui/js/studio.js:1602-1632).
- **Testy:** `tests/pure/test_sheet_estimate.rb` — 8 testov: :18 m² a rozsah · :32 `ceil_tenth` (F6) · :42 fallback (F4) · :56 poradie vstupu (N10) · :68 koeficienty a prázdny vstup ·
  :81, :97, :109 duplák 2B-1. Ďalej `tests/pure/test_mb1_uni.rb:266-274` (príznak `uni`) a `tests/pure/test_kon0_d143.rb:257-259` (plocha z `cut_size`).

### 2 · Riadky kusovníka — `nx/core/bom.rb`

- **Zber** `Bom.collect(model)` (bom.rb:56-317) je jeden prechod top-level entít (:117). Výrobné záznamy vznikajú z troch zdrojov:
  - vnorené dielce skrinky: `kind part`, `manufactured == true`, `production_class == 'sheet'` (:227-237),
  - dosky: `manufactured == true` (:269-281),
  - samostatné dielce (:283-296).

  Dielce `linear` a `counted` do kusovníka nejdú. Builder ich dnes ani nevydáva (cabinet_builder.rb:2298-2299, 2335; build_plan.rb:57).
- **Záznam** `Bom.record` (:1325-1354) nesie `name, part_key, owner_id, pid, role, length, width, thickness`, `quantity` (najmenej 1), `material_id`,
  `grain_direction` (chýbajúci → `'none'`) a `edges {L1,L2,W1,W2}`.
  Voliteľne nesie `material_source` (len úplný tvar, mult ≥ 2, :1340-1344). Pri platnom `cut_size` pridá `cut_size: true, geo_length, geo_width`, pri poškodenom `cut_invalid: true` (:1345-1352).
- **Rozmery sú HOTOVÉ, vrátane ABS** („prod = HOTOVY rozmer dielca (s nalepenym ABS)", build_plan.rb:64-67; STANDARD.md:1318).
  Plugin ABS nikdy neodpočítava — robí to VEPO podľa kódov hrán (vepo_export.rb:5-10; VEPO_KONTRAKT.md:106-108).
  **Výnimka D-143:** keď snapshot nesie platný `cut_size`, `length/width` sú **rozmer do nárezu** (väčší než v modeli).
  Jediné miesto čítania je `Bom.cut_dims` (bom.rb:1378-1392). Hmotnosť sa počíta z geometrie (outputs.md:575-580).
- **Kde vzniká `cut_size`:**
  - `Construction.back_part` pre chrbát v drážke: `{length: w, width: (h − s) − Δ}`, kde Δ je pokles pod výstuhy D-144 (construction.rb:1987-2011); pri komíne `{w, h − s}` (:2035),
  - builder ho zapíše **len neolepenému** dielcu (cabinet_builder.rb:2306-2322, 2346-2352),
  - validácia `BuildPlan.validate_cut_size!` vyžaduje hodnotu ≥ geometria (build_plan.rb:547-560).

  Poškodený `cut_size` → geometria + RED + zastavenie všetkých 4 exportov (bom.rb:1360-1368; STANDARD.md:1320-1330).
- **Agregácia** `Bom.compute → rows` (bom.rb:1605-1657): riadky sa **zlučujú naprieč skrinkami aj doskami** podľa `row_key`
  `[dĺžka, šírka, hrúbka v 0,1 mm, material_id, hrany L1..W2, grain_direction, [zdroj, mult] | nil]` (:1666-1675).
  Rola, názov, `part_key` ani vlastník v kľúči nie sú (STANDARD.md:1452).
  Riadok nesie: `key` (**pole**, nie reťazec), `length, width, thickness, material_id, edges, grain_direction`, `quantity` (súčet), `names, free_names`,
  `kde [{owner_id, quantity}]`, `refs [{pid, owner_id}]` (jeden na **záznam**, nie na kus) a `material_source` (:1623-1650).
  **Nenesie `part_key`, `role`, `cut_size` ani `geo_*`.** Rolu dopĺňa len Štúdio textom `role_label` (production_core.rb:1846-1853).
- **Triedenie** `[material_id, -length, -width]` (bom.rb:1653): pri zhode (iné hrany alebo smer) nie je poradie úplne určené.
- **Množstvo:** dielec skrinky má vždy 1 (deskriptor bez `quantity`, build_plan.rb:57, 475). Doska má 1–999 (board_builder.rb:48, 1096-1101).
- **Výrobné rozmery do VEPO:** `Bom.record/cut_dims` → `aggregate_rows` → `VepoExport.build(bom[:rows])` → `oriented` → `finished_dimensions`
  (len kontrola ABS, žiadna aritmetika) → do CSV `round` na celé mm (vepo_export.rb:157-165, 197-242).
  VEPO vyradí riadok bez materiálu, s nekladným rozmerom alebo s počtom < 1 (:348-354).

### 3 · Smer dekoru a orientácia

- **Hodnoty** `grain_direction`: `length | width | none` (STANDARD.md:373; materials.rb:192; board_builder.rb:49).
- **Skrinka (K1/D-108):** efektívny smer = ručný zásah (`GRAIN_OVERRIDES = length|width`, cabinet_builder.rb:153, 3656-3659), inak `grain` materiálu.
  Materiál s `grain 'none'` (UNI, jednofarebný, mimo katalógu) ručný zásah **ignoruje** a výsledok je `none` (:1482-1488; STANDARD.md:1147-1149).
  Výsledok sa zapíše do snapshotu a výstupy čítajú **len snapshot** (STANDARD.md:1150).
- **Doska:** jej vlastná hodnota vyhrá aj nad materiálom bez smeru, inak platí `grain` materiálu (board_builder.rb:956-961).
  Používateľ ju smie meniť pri každom materiáli (nx/ui/js/board_card.js:490-506).
  → O otáčaní musí rozhodovať **snapshot dielca**, nie vlastnosť materiálu.
- **`VepoExport.oriented`** (vepo_export.rb:141-150): len pri `'width'` vymení `length↔width` spolu s dvojicami hrán L↔W a nastaví `'length'`.
  `length`, `none` aj neznámu hodnotu nechá bez zmeny.
- **`Validation.fits_on_sheet?`** (validation.rb:527-538): `width` → `fit_one(w, l)`, `length` → `fit_one(l, w)`, všetko ostatné (`none` aj neznáma hodnota) → obe otočenia.
  Tolerancia je `DIM_TOL = 0.1` mm (:46), **bez kerfu a orezu**. Vetva `when PANEL_ROLE` je mŕtva obrana (:529).
- ⚠ **Nesúlad pri neznámej hodnote:** VEPO dielec neotočí (ako `length`), Kontrola ho otočiť dovolí (ako `none`).
  `Bom.record` doplní len chýbajúcu hodnotu; poškodená hodnota prejde ďalej (bom.rb:1335).
- **Otáčanie sa robí raz** — VEPO a zrkadlovo Kontrola, nikde inde. Dvojité otočenie by dielec objednalo v pôvodnej orientácii (STANDARD.md:374-376; cabinet_builder.rb:1472-1476).
  `cut_size` sa uplatní ešte **pred** otočením (test_kon0_d143.rb:275-281).
- **Kde žije „materiál má smer":** pole `grain` záznamu dosky (`length|width|none`; pri normalizácii je default `'none'`, materials.rb:625).
  - UI: „Po dĺžke / Po šírke / Bez smeru" (nx/ui/js/proj_materials.js:1079).
  - Predvolené hodnoty: UNI seed `none` (materials_catalog.rb:925), import z Demosu `length` (materials_demos_create.rb:140), nový dekor `length` (materials_decor.rb:598, 706).
  - Duplák smer kopíruje zo zdroja (materials_catalog.rb:249-258).

  Výstupy katalógový `grain` **nečítajú** — je to len predvoľba pre dielce (grep: čítajú ho iba buildery a vzhľad).
- **Ktorá strana platne je dĺžka:** `sheet_size[0]`. Že kresba platne beží po nej, je **implicitný predpoklad kódu** („dlzka pozdlz dekoru = pozdlz dlzky platne",
  validation.rb:512-514; vepo_export.rb:141-142). STANDARD ani materials.md to ako pravidlo nevyslovujú (**NEOVERENÉ**).
  Poradie dvojice sa pri zápise nevynucuje: `normalize_pair` (materials.rb:906-911) a validácia kontroluje len rozsah 500–5000 mm (materials_catalog.rb:301-307).
- Čo znamená materiál s `grain: 'width'` voči platni, nie je nikde definované. Dielce ho zdedia ako „kresba po šírke dielca", čo spustí VEPO swap. Či sa v praxi používa: **NEOVERENÉ**.

### 4 · Formát platne `sheet_size` a typy materiálov

- Pole záznamu dosky v globálnom katalógu `%APPDATA%\NOXUN\Engine\materials.json` (materials.rb:2-3), tvar `[dĺžka, šírka]` v mm Float (STANDARD.md:946-948).
  Je **voliteľné**: chýbajúci alebo neplatný pár sa neuloží a server nikdy neuloží neoverený default (materials.rb:627, 634-638, 906-920). Rozsah pri zápise je 500–5000 mm (materials.rb:122).
- **Typy** (TYPE_REGISTRY, materials.rb:138-161):
  - DTDL, MDF, HDF — `format_hint` 2800×2070,
  - ZASTENA — `format_hint` 4100×640, formát je súčasťou identity,
  - PD a KOMPAKT — bez `format_hint`, formát je súčasťou identity (nové varianty ho musia mať),
  - všetko ostatné je voľný typ „iný" bez návrhu formátu.

  `format_hint` je len predvyplnenie formulára, nie uložený default (:163-169). Typ sklo ani masív neexistuje.
- **UNI** seed (6 záznamov) má `sheet_size [2800, 2070]` ako pracovný default, `grain none` a `uni: true` (materials_catalog.rb:911-933).
  V odhade preto **nemá `fallback`, ale `uni`** (orientačný počet, sheet_estimate.rb:36-38, 75).
  Predvolený chrbát je UNI `HDF_WHITE_3` (typ DTDL), predvolené zásuvky `UNI_ZASUVKA_16` (materials.rb:183-188).
- **Duplák:** `source_material_id` + `source_multiplier` 2–3. Formát, smer a farbu kopíruje zo zdroja a synchronizuje ich (STANDARD.md:1051-1066; materials_catalog.rb:249-258).
  Nemá cenu ani kód — kupuje sa zdroj.
- **Cenová jednotka:** doska `price_per_m2` (€/m² s DPH; voliteľné, chýbajúca cena ≠ 0) (materials.rb:626, 633; STANDARD.md:1019-1050). ABS `price_per_bm` (materials.rb:850).
  Rozpočet nakupuje **všetky dosky po platniach** (MJ `PLATŇA`) a cenu platne počíta z €/m² × plocha formátu (budget.rb:194-250).
  Pole `per` pri materiáloch **neexistuje** — `per` majú len členovia setov kovania (`unit|owner`, budúce `length`; hardware_sets.rb:23-25, 1278).
  Dĺžkové ani kusové materiály v kusovníku dosiek nie sú.
- **Fallback** (chýbajúci formát):
  - odhad počíta s 2800×2070 a nastaví `fallback` (sheet_estimate.rb:88-95),
  - rozpočet pridá poznámku „formát platne nie je v katalógu — odhad podľa 2800×2070" a `estimated` (budget.rb:207, 222),
  - Kontrola `oversize` pri takom materiáli **mlčí** (validation.rb:516-519; materials.rb:635-637).
- ⚠ PD, KOMPAKT a ZASTENA majú dlhé úzke formáty (4100×600/640/920). Starý záznam PD bez formátu by padol na fallback 2800×2070, čo je pre pracovnú dosku zlý rozmer.
  Doska smie mať až 5000×3000 mm (board_builder.rb:47).

### 5 · Kontrola a výrobné brány

- **Nález „nezmestí sa na platňu" už existuje:** RED kategória `oversize` (`CAT_OVERSIZE`, validation.rb:59).
  `check_oversize` beží nad každým **záznamom** (nie riadkom), a to len keď je materiál v katalógu, nie je UNI a má platný formát (:328-360, 515-525).
  Kľúč nálezu je `oversize|owner_id|part_key` (:1681-1690).
- **`oversize` dnes NEZASTAVÍ žiadny export** — v `production_core.rb` ho nič nečíta (grep). Platí zásada „RED nikdy neblokuje export" s vymenovanými výnimkami
  (validation.rb:26-27; outputs.md:23-25). VEPO k statusu len pripojí súhrn Kontroly (`control_suffix`, production_core.rb:1639, 1984).
- **Ako fungujú brány.** Každý export má poradie: kontrola generácie a flushu → `fresh_collect` → brány → až potom výber súboru. Brány sú:
  - `newer_config_stop` (production_core.rb:1200-1203) a `cut_stop` (D-143, register `Bom::CUT_BLOCKERS`, :1215-1243) — všetky 4 exporty,
  - `drawer_stop(scope:)` nad registrom `BuildPlan.hw_blockers`, `hardware_issues` a expanziou kovania (:1421-1529) — `:kit` pre VEPO, `:all` pre nákup, rozpočet a ponuku,
  - `export_blockers(dups:, cp:, …)` (:1531-1557) — tvrdé dôvody; `cp:` platí len pre ponuku,
  - **len pre cenové exporty** `budget_std_block(budget)` (:1567-1572) — číta príznak z payloadu rozpočtu a volá sa výhradne v `do_budget_xlsx` (:3189-3190) a `do_cp_xlsx` (:3267-3268),
  - potvrditeľná vetva `export_confirmations` pre riadky bez ceny (:1583).

  Hláška `export_blocked_status` (:1610) musí povedať, že súbor nevznikol, prečo a kde to opraviť.
- **Nový RED, ktorý zastaví len cenové exporty — dostupné vzory:**
  - (a) RED riadok Kontroly musí vzniknúť v `Validation.run` (z `collected` + `sheets`). Rozpočtové položky cez `Validation.with_budget` sú **vždy ORANGE**
    a nič nezastavia (validation.rb:284-318; budget.rb:680-718). Vzor, ako v `run` z `collected[:records]` postaviť riadky cez `Bom.aggregate_rows`, je `check_name_lengths`
    (validation.rb:233; outputs.md:50-67).
  - (b) Brána = nová funkcia `*_stop` volaná v `do_budget_xlsx` a `do_cp_xlsx` pred výberom súboru (vzor `budget_std_block`).
    Zoznam dôvodov musí byť jeden, spoločný s Kontrolou (vzor `CUT_BLOCKERS`, outputs.md:223-231). Nákupný CSV kovania ani VEPO by ju nevolali.

### 6 · Výkon a veľkosť

- Najväčšia známa zákazka je KLINIKA s 254 dielcami (STAV.md:18). **V repe k nej fixtúra nie je:** `tests/fixtures/` má len plány po skrinkách (kova_golden, kovh_golden…)
  a `_dev/` (gitignore) obsahuje len `ENGINEtests.skp`. Golden plán pre veľkú zákazku treba zostaviť (napr. z headless plánov ako `NxKon0.plan` v test_kon0_d143.rb) — **NEOVERENÉ**, koľko práce to je.
- **Cena výpočtu:** `Bom.collect` je jeden prechod modelom. `compute` a odhad sú lineárne nad záznamami a riadkami (bom.rb:1605-1657; sheet_estimate.rb:42-77).
  `push_state` Štúdia trval pri 6 skrinkách **~5 ms** (KRONIKA.md:3928). In-SU runner meranie len vypíše, bez prahu (su_runner.rb:15499-15516).
  Policová heuristika nad ~254 obdĺžnikmi by mala byť zanedbateľná oproti prechodu modelom — odhad, **NEOVERENÉ meraním**.
- **Kedy sa počíta:** Štúdio sa pri zmene modelu **neprepočítava** — observer len zvýši epochu a označí okno ako neaktuálne (Obnoviť zožltne) (studio_dialog.rb:98-117, 266, 307-313).
  Plný prepočet nastane:
  - pri otvorení a Obnoviť,
  - pri prepnutí dokumentu (:233-253),
  - cez `refresh_if_open` z katalógov, nastavení a pravidiel (:223-229),
  - po **každej mutácii rozpočtu** (`budget_repush_proc`, :1220-1227).

  Každý export počíta všetko znova z čerstvého zberu (production_core.rb:1932, 2025, 3169, 3250) vrátane odhadu v `budget_payload` (:2376).

### 7 · Architektúra a štandard — invarianty pre nový modul

- **Čistý modul bez SketchUp API**, testovateľný headless (vzor `SheetEstimate`, `Budget` budget.rb:4-7, `Validation` validation.rb:2-6).
  Nový modul potrebuje nový odsek v `docs/architecture/outputs.md`, riadok v tabuľke `docs/ARCHITEKTURA.md:60-61` (stráži `tests/pure/test_docs_navigacia.rb`)
  a zaradenie do poradia načítania v `nx/main.rb:506` aj `tests/helper.rb:177`.
- **Čítanie nikdy nezapisuje:** `fresh_collect` je čisté čítanie — žiadny zápis, operácia ani krok Späť (outputs.md:186-190; guard `tests/pure/test_1b3_citanie.rb`).
  `ProductionCore` nesmie mať okenný stav (outputs.md:177-179).
- **Jednotky:** mm ako Float, jeden svet (STANDARD.md:343-348).
- **Otočenie kvôli kresbe robí len výstup a len raz**; snapshot je autorita smeru (STANDARD.md:374-376, 1150). `cut_size` sa uplatní pred otočením (STANDARD.md:1320-1326; outputs.md:578).
- **Duplák:** nakupuje sa zdroj, duplák nikdy nie je samostatná platňa; `doubled_m2` sa už znova nenásobí (budget.rb:17-20; sheet_estimate.rb:27-35).
- **Peniaze:**
  - neznáma cena sa nikdy nenahradí nulou a chýbajúci formát sa nikdy netvári ako istý (budget.rb:21-25),
  - jedna autorita čísel je payload rozpočtu, klient si nič neprepočítava (STANDARD.md:1538-1540),
  - cenová ponuka nesmie ukázať počty platní ani interné pojmy (STANDARD.md:1541-1545).
- **Determinizmus:** výsledok nezávisí od poradia vstupu (sheet_estimate.rb:22-23; test N10).
- **Brána:** vyhodnotí sa pred výberom súboru a jeden register slúži Kontrole aj bráne (outputs.md:200-231). **Formát platne a UNI sa čítajú zo živého katalógu** (`sheets_map`, production_core.rb:546-553),
  smer a rozmery zo snapshotu.
- **Schéma rozpočtu:** `BUDGET_STD` je dnes **2** (budget_store.rb:69). Každé nové pole, ktorého strata by pokazila cenu, znamená zvýšenie verzie a doprednú bránu (STANDARD.md:1553-1562).
  Marker zapíše **prvá** mutácia rozpočtu akéhokoľvek druhu (STANDARD.md:1563-1571).
- **STANDARD §12 zaraďuje „nesting / nárezové plány" medzi veci mimo rozsahu štandardu v1** (STANDARD.md:1586-1588) — nový blok to musí zmeniť.
- Audit návrhu je povinný (nový modul; pri NP-2 aj zmena schémy) (ENGINE CLAUDE.md, sekcia Git workflow).

### 8 · Čo návrh `NAREZ_PLAN_NAVRH_2026-09-06.md` predpokladá inak, než je dnes v kóde

1. **Identita dielcov (§8 bod 2 „`<part_key>#<n>`"):** riadky kusovníka `part_key` nenesú a zlučujú dielce naprieč skrinkami (bom.rb:1623-1675).
   `part_key` je jedinečný len v rámci vlastníka (STANDARD.md:106-114), `pid` sa po prestavbe mení. Identitu treba odvodiť z `row['key']` (vzor stabilného kľúča `name_long`)
   alebo z `collected[:records]` ako `owner_id + part_key`. (Stabilný kľúč `name_long` je v outputs.md:60-62.)
2. **`grain_direction` (§1):** „dielec bez smeru = materiál bez smeru" platí len pre skrinku. Pri doske rozhoduje snapshot dosky nezávisle od materiálu (board_builder.rb:956-961).
   Neznáma hodnota nemá určené pravidlo (VEPO a Kontrola sa rozchádzajú, §3).
3. **`cut_size` (D-143, v0.13.1 — pribudol po 6.9.):** riadky ho už majú zapracovaný v `length/width` (chrbát v drážke je v kusovníku väčší). Plán nemusí nič robiť navyše,
   ale nesmie siahnuť na `geo_*`. Tvrdenie „rozmery = výrobné rozmery BOM" platí, lenže **BOM sú hotové rozmery s ABS**, nie rozmery do nárezu (§2).
4. **Kerf a orez (§1 „parametre projektu (Nastavenia rozpočtu)" vs NP-2 „nové polia `BudgetStore`"):** „Nastavenia rozpočtu" (sekcia `bset`) sú **globálne `SupplierSettings`**
   v `%APPDATA%`, nie projekt (supplier_settings.rb:1-10; production_core.rb:3146-3149). `BudgetStore` je naopak per zákazka na modeli. Návrh si tu protirečí.
   Kerf ani orez dnes v kóde nie sú (grep; jediná zmienka je komentár sheet_estimate.rb:6).
5. **RED „plán neúplný" vs existujúci `oversize`:** Kontrola `oversize` nepočíta s orezom ani kerfom a nič nezastaví (§5). Dielec 2795×2065 na 2800×2070 by v Kontrole prešiel,
   ale v pláne s orezom 10 mm by bol RED. Tá istá príčina by sa hlásila dvakrát s rôznymi pravidlami a bránami.
6. **UNI:** návrh ho nerieši. UNI má pracovný formát bez `fallback` (§4) a Kontrola ho z `oversize` vynecháva. Plán pre UNI by mal byť len orientačný, podobne ako pri fallbacku (§8 bod 5 návrhu kryje len fallback).
7. **„Dĺžkové materiály (`per:'length'`)" (§5 mimo rozsahu):** materiály pole `per` nemajú a lineárne dielce do kusovníka nechodia (§4, §2) — bod je bezpredmetný.
8. **Novšie dielce nemenia kontrakt plánu, len obsah riadkov:**
   - rohová K3: blenda, výstuha závesov, CR 1/CR 2 z materiálu čiel, rohová výstuha — obyčajné obdĺžniky (construction.rb:76, 583-607, 701-704),
   - police rohovej majú výrez, ktorý robí dielňa — v kusovníku je celý obdĺžnik (construction.rb:732),
   - chrbát z líšt K2 (`back_mode 'rails'`): lišty z korpusového materiálu sa zlúčia s výstuhami (construction.rb:2047-2063; STANDARD.md:1338-1341),
   - chladničková bez chrbta (`none`) nemá dielec chrbta (construction.rb:1988).
9. **Kontrakt D-19** v hlavičke počítal s tým, že fáza 2 **vymení vnútro `estimate()`** pri rovnakom kontrakte (sheet_estimate.rb:5-7; DOGFOODING_vyriesene.md:1390).
   Návrh namiesto toho pridáva samostatný modul vedľa odhadu — komentár kontraktu by zastaral.
10. **„KLINIKA pod sekundu"** sa headless nedá overiť, lebo fixtúra neexistuje (§6). Sekcia „Nárezový plán" je v navigácii stále neaktívna (nx/ui/js/studio.js:107; STAV.md:16) — sedí.

### Otázky a riziká pre koncept

1. **Identita obdĺžnika:** stavať plán z agregovaných riadkov (`row['key']` + poradové číslo) alebo zo záznamov (`owner_id + part_key`)? Riadky nemajú `part_key` a pri dvoch skrinkách so spoločným ID sa kľúč opakuje.
2. **Hotové rozmery s ABS vs rozmer do nárezu:** VEPO si ABS odpočíta samo a prípadný prídavok na frézovanie pred olepením je **NEOVERENÝ**. Nie je potvrdené, že plán z hotových rozmerov je vždy horná hranica.
3. **Kerf a orez:** globálne nastavenie (SupplierSettings, bez zmeny schémy zákazky) alebo per zákazka (`BudgetStore` → zvýšenie `BUDGET_STD` na 3 a starší plugin zastaví cenové exporty)? Treba rozhodnúť pred NP-2.
4. **Jedna pravda o „nezmestí sa":** zjednotiť `oversize` (bez orezu, bez brány) s RED plánu (s orezom, brána na ceny) — inak jeden dielec dostane dva rôzne verdikty.
   Ďalšia otázka: má RED zastaviť cenové exporty aj vtedy, keď cena ide z odhadu m² (ten plochu dielca obsahuje)?
5. **Orientácia platne:** kresba po `sheet_size[0]` je len nevyslovený predpoklad a poradie dvojice sa nevynucuje. Pri `grain` materiálu `'width'` je význam nejasný — treba pravidlo do STANDARD.
6. **UNI a PD bez formátu:** UNI má pracovný 2800×2070 bez príznaku fallback a starý záznam PD bez formátu padne na DTD formát. Plán musí tieto prípady označiť ako orientačné, nie ako RED.
7. **Duplák:** stačí `quantity × multiplier` obdĺžnikov v hotovom rozmere, alebo sa kusy na lepenie režú s prídavkom? **NEOVERENÉ** (robí VEPO).
8. **Kedy počítať:** v každom plnom `push_state` (aj po každej mutácii rozpočtu) a znova v každom cenovom exporte (jedna autorita čísel), alebo len na požiadanie v sekcii?
   Pri „ceny podľa plánu" musí plán počítať aj `budget_payload` v exportoch.

---

## Časť B — FAKTY B — Nárezový plán: UI Štúdia, rozpočet, nastavenia (rešerš kódu)

Repo `C:\APP DEV\RUBY\ENGINE`, main @ 68aef64e, v0.15.0, stav 28.9.2026. Cesty relatívne k repu (`nx/` = `noxun_engine/`). Len čítanie.

### 0 · Overenie predpokladov návrhu NAREZ_PLAN_NAVRH_2026-09-06 voči dnešnému kódu

- **§1 „kerf/orez = parametre projektu (Nastavenia rozpočtu)" vs §6 NP-2 „nové polia `BudgetStore`" si PROTIREČIA.** Sekcia *Nastavenia rozpočtu* je GLOBÁLNA
  (`%APPDATA%\NOXUN\Engine\supplier_settings.json`, hint „globálne pre všetky zákazky, do zákazky sa nemrazia" `nx/ui/js/studio.js:174-175`,
  `nx/core/supplier_settings.rb:1-11`); per zákazka je len `BudgetStore` (`nx/core/budget_store.rb:1-13`). Treba rozhodnúť (sekcia 4).
- **§4 „vedľa odhadu rozsahu (count_min–count_max)" v Rozpočte — rozsah v Rozpočte NIE JE.** Rozpočet ukazuje celé číslo `ceil(count_max)` ako množstvo
  (`nx/core/budget.rb:252-258`, `nx/ui/js/budget.js:670`); rozsah „X,X – Y,Y" je len v Kusovníku → pohľad Platne (`nx/ui/js/studio.js:1616`, súčty 1561, 1645-1647).
- **„Koeficient prerezu 10–25 %" nie je nastavenie** — konštanty `K_MIN=1.10`/`K_MAX=1.25` (`nx/core/sheet_estimate.rb:14-15`); `estimate(k_min:, k_max:)` (39)
  nikto s parametrom nevolá (`nx/ui/studio_dialog.rb:1606`, `nx/ui/production_core.rb:2376`, `nx/core/budget.rb:842`).
- `SheetEstimate` kontrakt D-19 (dupláky do zdroja, fallback 2800×2070, `uni`) platí bez zmeny (`nx/core/sheet_estimate.rb:27-78`). Materiálové riadky nemajú ručný
  prepis (overridy len `service:|std:` — `budget_store.rb:118`, `budget.rb:385`), takže prepínač „ceny podľa plánu" by bol PRVÁ cesta, ako zmeniť počet platní.
- STANDARD §12 stále píše „nesting / nárezové plány" ako mimo scope V1 (`SYSTEM/STANDARD.md:1588`) — kolízia s PLAN/V1_VIZIA (`SYSTEM/PLAN.md:219-222`).

### 1 · Štúdio a jeho sekcie

**Neaktívna položka dnes:** `{ id:'cut', ic:'scissors', t:'Nárezový plán', disabled:'fáza 2 — nárezový plán zatiaľ neexistuje' }` (`nx/ui/js/studio.js:107-108`);
tooltip = `t + ' — ' + disabled` a `aria-disabled` (`studio.js:1162-1165`); klik → červený status s tým istým textom (`onNav`, `studio.js:1884-1887`).
Ikona `scissors` v spritu existuje (`nx/ui/js/icons.js:113`). `SEC_META` pre `cut` nemá záznam (`studio.js:142-177`). Mockup: placeholder „Fáza 2"
(`SYSTEM/zdroje/ui20/mockup_studio.html:1777`), kontrakt Š „jediná aria-disabled položka" (`SYSTEM/zdroje/ui20/UI20_KONTRAKT.md:575-576`).

**Registrácia sekcie = 3 zrkadlá + Ruby autorita:** `SECTIONS = %w[bom ctrl buy budget offer mat hw appl rules tpl sup bset about]` (`nx/ui/studio_dialog.rb:52`,
autorita whitelistu, spotreba deep-linku 1750-1754); JS `STUDIO_SECTIONS` (`studio.js:64-65`); `NXShell.STUDIO_SECTIONS` pre deep-link z Inspectora (`nx/ui/js/shell.js:349-353`).

**Payload — kde a kedy:** JEDEN plný push `push_state(bump:)` nesie VŠETKY sekcie (`studio_dialog.rb:1598-1733`); zber `fresh_collect` → `Bom.compute` → `SheetEstimate`
(1601-1609) → `budget_payload` (1620) → `control_payload` (1621) → `data` (1623-1702) → `NX.setStudio(...)` (1711). Prepnutie sekcie je čisto klientske, na server nejde
(`studio_dialog.rb:1592-1593`, `docs/architecture/ui-lifecycle.md:2921-2922`). **Plný push chodí:** `ready` pri otvorení (`studio_dialog.rb:1385-1389`), „Obnoviť"
(`do_refresh_bom` 603-609), prepnutie dokumentu (233-257), po mutácii rozpočtu `bump:false` (1220-1231), po zmene katalógu/sadzieb/pravidiel/šablón
(`refresh_if_open` volajú `materials_dialog.rb:1040,1946`, `hardware_catalog_dialog.rb:255,685`, `rules_dialog.rb:1028`, `supplier_settings_dialog.rb:797`,
`templates_dialog.rb:490`, `panel/actions_appliance.rb:298,427`). **Bežná úprava v Inspectore push NEROBÍ** — len `StudioModelWatch` → `NX.markStale()` (jantárové
„Obnoviť", `studio_dialog.rb:97-117, 266-313`; `ui-lifecycle.md:2843-2875`). Pozn.: komentár „plný push pri každej zmene modelu" (`nx/ui/js/studio_settings.js:9-12`) je nepresný.
Pravidlo: nová sekcia berie dáta z UŽ hotového zberu, druhý sken modelu je zakázaný (`ui-lifecycle.md:3288-3295`). Lazy PULL kanál má precedens
(`appl_card`, `tpl_preview` — `studio_dialog.rb:1679-1683, 1693-1696`).

**Render v JS:** `NX.setStudio` (`studio.js:961-1083`: `ST = data`, `staleFlag=false`, deep-link + kotva, `render()`); `render` = nav/head/tools/body (1145-1150);
`renderTools` a `renderBody` rozbočujú podľa `studioSec` — jednoduché sekcie kreslí `studio.js` do `innerHTML` (Kontrola 1255-1267/1461, Nákup 1272-1284/1462),
zložité svoj súbor načítaný ZA `studio.js` volaný cez `typeof xxxRenderBody === 'function'` (Rozpočet 1197-1201/1401-1405, Nastavenia 1247-1251/1456-1460).
Prepnutie sekcie: `studioGoSection` (1899-1929; leave-hooky len pri modáloch/dlhých behoch). „Obnoviť" = zdieľaný `refreshBtnHtml` (200-205) + `REFRESH_STATUS[sekcia]`
(1700-1714) → `refresh_bom`. Guard poradia skriptov/`?v=`: `studio.html:1046-1137` (všetko `?v=0.15.0`), `tests/pure/test_st4a_nastavenia.rb:230-245`.

**Guard testy, ktoré dnešný stav PRIBÍJAJÚ (pri živej sekcii `cut` sa musia zmeniť):**
`tests/pure/test_st1a_studio.rb:41-60` (Ruby = JS zrkadlo) a `:1060-1066` („PRÁVE 1 `disabled:` a znie ‚fáza 2'") · `tests/js/test_st1a_studio.js:45` (presný zoznam),
`:203-206` (CUT disabled), `:213-218` (každá položka = sekcia/premostenie/dôvod + ikona) · `tests/js/test_uid3_klikatelnost.js:100-101,114` (`studioSection('cut') === null`) ·
`tests/pure/test_st1b_kontrola.rb:336` (presný reťazec SECTIONS) · `tests/sketchup/su_runner.rb:16322` (presný zoznam) · zrkadlá v `test_s1a2_sekcia.rb:54-61`,
`test_st1c_rozpocet.rb:71-74`, `test_st3a_hw.rb:59-61`, `test_st3b_rules.rb:46-48`, `test_st3c_tpl.rb:46-49`, `test_st2a_mat.rb:52-54`, `test_st1c_ponuka.rb:44-46`,
`test_uid3_klikatelnost.rb:252-253` · `tests/pure/test_stale_obnovit.rb:158-185` (presne 3 volania `refreshBtnHtml` v studio.js + 2 v budget.js — „5 miest").

**Súbory, ktorých sa dotkne nová sekcia:** `nx/ui/studio_dialog.rb` (SECTIONS, kľúč payloadu v `push_state`, príp. callback) · `nx/ui/js/studio.js` (STUDIO_SECTIONS,
NAV bez `disabled`, SEC_META, renderTools/renderBody vetva, REFRESH_STATUS, module.exports) · `nx/ui/js/shell.js:349` · `nx/ui/studio.html` (CSS sekcie + `<script ?v=>`
ak vlastný súbor) · nový `nx/ui/js/<sekcia>.js` (voliteľne) · všetky guard testy vyššie · docs: `ui-lifecycle.md:2381-2384, 2428-2429` (+ nový odsek sekcie),
`docs/UI_DIZAJN.md:1398-1402`, `UI20_KONTRAKT.md:575`, `SYSTEM/STAV.md:16`, `docs/ARCHITEKTURA.md` (riadok nového modulu). Pozn.: `ui-lifecycle.md:2381` píše
„DVANÁSŤ sekcií" bez `appl` — dnes ich je 13.

### 2 · Rozpočet — materiál po celých tabuliach (D-61)

**Výpočet (server, `nx/core/budget.rb`):** sekcia `materials` (názov „Materiál", 63-68) = jeden riadok na NÁKUPNÝ materiál z `sheet_estimate` (194-231):
`mnozstvo = plates_of = ceil(round(count_max,6))` (255-258), `cena_mj = price_per_plate = price_per_m2 × PRESNÁ plocha formátu` (238-250), `mj = 'PLATŇA'`,
`spolu = mnozstvo × cena_mj` (`base_row` 755-775). `poznamka` skladá server: „X m² · formát L×W · formát platne nie je v katalógu… · materiál neurčený (UNI)… ·
vrátane N ks duplákov" (203-211); príznaky `estimated` (fallback), `uni`, `m2`, `price_per_m2`, `cp_nazov` (219-227). **count_min sa v rozpočte nepoužíva vôbec.**
**Odvodené služby idú z tých istých riadkov:** `porez = Σ mnozstvo materiálov` (€/platňa), `montaz = Σ platní × montaz_m2_per_plate × sadzba` (358-388) — zmena počtu
platní (plán) ich pohne automaticky. Payload rozpočtu vzniká v `ProductionCore.budget_payload` (`production_core.rb:2374-2388`; ak estimate nepríde, spočíta si ho sám)
a volá sa na **5 miestach**: push Štúdia (`studio_dialog.rb:1620`), VEPO (kontrola do LOGu, `production_core.rb:1958`), XLSX rozpočtu (3183), XLSX ponuky (3261),
ciele prepočtu cien (3436) — plán musí ísť do všetkých, inak dve pravdy.

**UI (`nx/ui/js/budget.js`):** tabuľka Materiál: stĺpce `Materiál · Množstvo · MJ · € / MJ · Overená · Medzisúčet` (609-612); riadok `budMaterialRow` (665-676):
bunka Materiál = `nazov` + „ · poznamka" drobným (`budNoteHtml` 660-663), Množstvo = celé číslo, € / MJ = cena za tabuľu + „(x €/m²)", Overená = vek ceny.
Sekcia je `<details>` s medzisúčtom v `<summary>` (572-602), predvolene otvorená (195). **Precedens prepínača per zákazka v hlavičke sekcie:** checkbox
„sčítať do rozpočtu" v `<summary>` Spotrebičov (`data-bud="appl_included"`, 578-585 → `budSend` 2219-2220).
Lišta Rozpočtu je plná (DPH, režim, Prepočítať ceny, Obnoviť, XLSX, Nastavenia — 435-460) a pri 1060 px sa už raz lámala (komentár 449-452).

**XLSX rozpočtu** (`nx/core/xlsx_writer.rb:360-481`): stĺpce `MATERIÁL · KÓD · MJ · POČET · CENA za 1 MJ · SPOLU` (361); bunka MATERIÁL = `nazov · poznamka`
(`item_name` 453-458) → poznámka plánu by sa do XLSX dostala automaticky. **Cenová ponuka** (`nx/core/cp_export.rb`): materiál ide ako `1 set` (293-300), MJ PLATŇA→`set`
(61-64), `platň` je v blockliste firewallu (110-116), poznámka sa nepoužíva (`item_label` = `cp_nazov`/`nazov`, 312-319); samostatný riadok len ak suma ≥ prah 150 €,
inak zvyšok „Nábytková zostava" (137-184, 194-220); montáž = pevný riadok „Montáž a výroba" (57, 254-265). Plán teda ovplyvní ponuku len SUMOU.

**Kde je dnes odhad vidieť v Štúdiu:** Kusovník → Platne, stĺpec „Odhad platní" `count_min – count_max` + príznak UNI/fallback (`studio.js:1600-1651`), súčet
„odhad A – B platní · orientačný rozsah (prerez 10–25 %), NIE nárezový plán" (1644-1647); súčtový riadok Dielce (1553-1562). Totals skladá server (`studio_dialog.rb:1738-1747`).

### 3 · BudgetStore (per zákazka, `nx/core/budget_store.rb`)

- **`BUDGET_STD = 2`** (69; 1 = E-a, 2 = S1-B1 väzba spotrebiča, 61-68); marker kľúč `budget_std` (48). Disciplína bumpu: pri KAŽDOM rozšírení whitelistu o pole,
  ktorého tichá strata poškodí cenu/objednávku (55-59; `SYSTEM/STANDARD.md:1549-1571`).
- **Uzavreté whitelisty:** kľúče `budget_mode/overrides/std_multipliers/viz_m2/custom_items/appliances/appliances_included/cp_overrides` (37-44); `state` (199-213);
  `numeric_map` len `ROW_KEY_RE` (666-676, 118); `CP_KEY_RE` (130); položky cez `build_custom`/`build_appliance`. Neznáme pole starší plugin pri zápise zahodí.
- **`write!`** (729-762) = jediný choke point: dopredný guard `std_block_reason(std_state)` PRED `start_operation` (732-737) → `start_operation(name, true)` → blok →
  `stamp_std` (792-794) → `commit_operation`; výnimka = `abort_operation`. Údaj + marker = JEDEN krok Späť. `write_attr` mimo `write!` hodí výnimku (687-696);
  režim `in_operation:` pre cudziu operáciu (772-787). Stavy `:legacy/:current/:newer/:invalid` (156-170), hlášky (78-81).
- **R-14 dopredná brána:** novší/poškodený marker → odmietnu sa VŠETKY mutácie (13 vstupov v teste `tests/pure/test_r14_budget_std.rb:102-121, 342-355`) aj oba cenové
  exporty (`ProductionCore.budget_std_block` 1567-1573, volané 3189-3190 a 3267-3268); čítanie/VEPO nie. UI: banner + vypnutie ovládačov zo zoznamu `BUD_STD_OFF`
  (`budget.js:240-289`), poistka v `budSend` (1885).
- **Nové pole (napr. „ceny podľa plánu", príp. kerf/orez per zákazka) = reťaz:** `KEY_*` + čítanie v `state` + mutačná metóda s validáciou PRED `write!` (vzor
  `set_appliances_included!` 328-331) → `apply_budget_op` nový `op` (`production_core.rb:3031-3050`) + text `BUDGET_OP_STATUS` (3115-3124) → `Budget.normalize_state`
  (`budget.rb:800-812`) → `data-bud` akcia v `budget.js` + zápis do `BUD_STD_OFF` → **bump `BUDGET_STD` 2→3** + STANDARD §11.3 + testy (`test_r14` zoznam mutácií,
  in-SU `st1c_budget` „N operácií × 1 Späť" `su_runner.rb:15726-15780`). Dôsledok bumpu (priznané pri v2, `STANDARD.md:1569-1571`): marker 3 zapíše PRVÁ mutácia
  rozpočtu akéhokoľvek druhu → starší plugin (napr. druhý PC) zákazku v Rozpočte needituje a nevyrobí XLSX ani ponuku. Guardy servera: `gen` + `model_guid` (`do_budget` 2983-2994).

### 4 · Nastavenia — kde môžu žiť kerf a orez

**Sekcia „Nastavenia rozpočtu" (`bset`) = GLOBÁLNA**, nie per zákazka. Store `SupplierSettings` → `%APPDATA%\NOXUN\Engine\supplier_settings.json` + `.bak`
(`supplier_settings.rb:1-11, 139-151`), payload bez modelu (`supplier_settings_dialog.rb:120-150`). Obsah dnes: **sadzby služieb** `olep` €/bm · `porez` €/platňa ·
`duplaky` €/ks · `pd_opracovanie` € fix · `montaz` €/m² (+ režimové hodnoty €/€€/€€€) (`supplier_settings.rb:57-64`, popisky `supplier_settings_dialog.rb:69-75`);
**8 štandardných riadkov** vrátane `doprava_zakaznik`/`doprava_vseobecna` (87-104); **skaláre** `abs_reserve_pct`, `montaz_m2_per_plate`, `rounding_step`, `stale_days`,
`cp_highlight_threshold` (75-81, rozsahy 119-133). UI: tabuľky „Sadzby služieb", „Štandardné riadky", fieldset **„Výpočet a upozornenia"** so skalármi
(`studio_settings.js:141-187`), patch skalára `scalar:<kľúč>` je generický (`ssBuildPatch` 553-584). Uloženie → `patch_active!` (validate-all, R-08 zámok
`materials.lock` + revízia pod zámkom, `supplier_settings.rb:503-648`) → plný push Štúdia `bump:true` (`supplier_settings_dialog.rb:243-274`).
R-11: poškodený primár s platnou `.bak` → číta sa záloha, zápis odmietnutý s dôvodom (`supplier_settings.rb:216-258`). Architektúra na viac dodávateľov, V1 = jeden aktívny (20).
**Sekcia „Dodávateľ / Demos" (`sup`) nemá ani jedno editovateľné pole** — len stav a preklik (`studio_settings.js:189-243`; `ui-lifecycle.md:3639-3642`).

- **Variant A — globálne (dodávateľ/píla):** 2 nové skaláre (`SCALAR_DEFAULTS`, `SCALAR_RANGES`, `normalize_supplier` 370-393) + 2 riadky `SS_SCALARS` vo fieldsete
  „Výpočet a upozornenia". Sedí s domovým faktom „sadzby porezu/olepu ako dáta per dodávateľ" (`SYSTEM/POJMY.md:194-197`) a so zásadou „do zákazky sa nemrazia"
  (`STANDARD.md:1545`). Bez `BUDGET_STD` bumpu. **Pasca:** súbor NEMÁ doprednú bránu — `STD=1` sa uloží, ale nikde neporovná (`supplier_settings.rb:43, 364`),
  a `normalize` je whitelist (353-358): starší plugin na TOM ISTOM PC pri uložení sadzieb kerf/orez zahodí a po upgrade ich seed-merge vráti na default (286-303).
  Validácia „orez < polovica menšieho rozmeru" sa pri uložení nedá urobiť proti všetkým formátom (formát je per materiál v katalógu) — len pri výpočte plánu.
  Plán by sa prepočítal pri každej zmene (pohyblivý obraz, ako sadzby) — „snapshot v pláne" = len čísla v payloade.
- **Variant B — per zákazka (`BudgetStore`):** nové kľúče + bump `BUDGET_STD` + celá reťaz zo sekcie 3; zmena = krok Späť; cestuje so `.skp`. Mimo sekcie `bset`
  (tá je globálna) — UI by musel byť v Rozpočte alebo v novej sekcii.
- **Variant C — hybrid (precedens pravidiel kovania):** globálna predvoľba v %APPDATA% + projektový snapshot v `NOXUN` dict, zapisovaný v operácii
  (`ui-lifecycle.md:2398-2401`). Prepínač „ceny podľa plánu" je prirodzene per zákazka (vzor `budget_appliances_included`).

### 5 · Kreslenie, tokeny a pravidlá

**Studio dnes nekreslí žiadne SVG** — `studio.html` nenačítava `preview.js` (`nx/ui/studio.html:1046-1137`), SVG sú len ikony zo spritu (`<use href="#i-…">`).
Inspector kreslí SVG ako **reťazce** `S.push('<rect …>')` → `svg.innerHTML` (`nx/ui/js/preview.js:869-957`), scéna v mm cez `viewBox` + fit/zoom
(`applyViewBox`/`viewMapping`/`clientToScene` 275-289), klik cez delegáciu (956). Farby v `preview.js` sú **hex zrkadlá tokenov** a tému zámerne NEsledujú
(1-72; `docs/UI_DIZAJN.md:106-110, 233`). Karta dielca/dosky: obdĺžnik v pevnom `viewBox 300×200` so škálou, béžová výplň `#faf6ee`, popisky hrán, rozmer v strede
(`nx/ui/js/part_card.js:322-365`, `nx/ui/js/board_card.js:364-404`) — najbližší vzor „dielec ako obdĺžnik". Precedens **SVG štýlovaného CSS triedami s tokenmi**
(téma-bezpečné): `#preview rect.fprofband { fill: var(--nx-border-strong) }` (`nx/ui/css/panel.css:2137`), `.tpltile svg rect` (1556). Vizuálny jazyk smeru kresby
= šrafovanie (ikona `grain`, `UI_DIZAJN.md:313-316`). Znovupoužiteľné JS pomocníky Štúdia: `esc`, `num`(desatinná čiarka), `ico`, `rgbHex` (farba dekoru z `[r,g,b]`,
bezpečná do `style`) (`studio.js:180-220`); CSS `.bomtab`, `.totrow`, `.cellsw`, `.estfb` (jantár fallback), `.wtagchip`, `.hwbanner`/`.hwbanner-stop` (`studio.html:191-227, 311-321`).

**UI_DIZAJN (prečítaný):** tokeny `--nx-*`, nikdy hex (`UI_DIZAJN.md:58-61, 53-54`); **tmavý režim NEEXISTUJE** — sú dve témy NOXUN/Lucia a prepínajú VÝHRADNE
výberovú rodinu (201-233), `panel.css` nemá `prefers-color-scheme`; farba = význam (zelená akcia, teal výber, červená chyba, jantár upozornenie — 17-21);
rádius 6 px, 8 px väčšie plochy (22-26); písmo Segoe UI 13 px, hinty 10,5 px (237-241); výstup nevyzerá ako vstup (27-28); klikateľné len to, čo niekam vedie,
nedostupné = `aria-disabled` s dôvodom (29-33); overlay nie nový riadok (45-47); pomocný text do tooltipu, `.hint` sa nepridáva (48-52); náhľad nikdy nepočíta dáta,
kóty decentné (601-610); Štúdio 1060×640 obsahu, telo sekcie ≈ 828 px (1356-1387); aria-disabled len pre sľub najbližšej dávky (1403-1415); zobrazovacie voľby
v `localStorage` (1419-1421); `?v=` = VERSION (1623-1630). Semafor Kontroly používa `--nx-state-*` (`studio.html:259-261`) napriek „rezervované" (`UI_DIZAJN.md:188-197`).
**Trvalé pravidlo:** „VERTIKÁLNY priestor panela je vzácny… rast do výšky len v krajných prípadoch" (`SYSTEM/PLAN.md:680-682`; `UI_DIZAJN.md:13-14`).
Pri ~828 px šírke má jedna platňa 2800×2070 na plnú šírku ~610 px výšky — viac platní sa zmestí len ako mriežka miniatúr (odvodené, NEOVERENÉ mockupom).

### 6 · Výber v modeli zo zoznamu (D-94 a Kusovník)

Reťaz klik → model: JS `sketchup.nx_select(JSON{gen, <adresa>, focus_inspector})` (`studio.js:1691-1695` Kusovník `parts_key`; `1753-1761` D-94 `source_ref:
{cabinet_id, owner_part_key}` vždy s `focus_inspector:true`) → `StudioDialog.handle_select` → ak panel žije `Panel.js("NX.studioRelay(...)")` = flush rozpísaných
editov (`studio_dialog.rb:1501-1508`, `nx/ui/js/bridge.js:374-383`) → `studio_do_select` (`nx/ui/panel.rb:267`) → `StudioDialog.do_select` (369-374) →
`ProductionCore.do_select` (`production_core.rb:2084-2218`): guard `gen` (2085-2091) a `flush_blocked` (2092-2094); vetva `source_ref` (2154-2166) → `pids_for_source`
→ `pids_for_problem(owner_id + part_key)` (760-772); vetva `parts_key` → `refs_for` = všetky `pid` agregovaného BOM riadku (793-807); výber pod
`Panel.suspend_selection_sync`, `Panel.push_selected(dedup:false)`, `bring_to_front` len ak Inspector žije — nikdy ho neotvára (2181-2187); vlastná statusová veta
(2209-2214, 2265-2284). Klient posiela IDENTITU, nikdy pids z DOM (`studio.js:1747-1752`). **Pozor:** BOM riadok je agregát rovnakých dielcov naprieč skrinkami
(kľúč = výrobné parametre, `nx/core/bom.rb:1620-1651, 1666-1676`, `refs` = pid+owner_id per záznam) → `parts_key` označí VŠETKY rovnaké kusy; presný jeden kus
zvládne `source_ref`-typ adresa (owner_id + part_key). Pre samostatné dosky (`part_key` `board/…`) cestu `pids_for_problem` NEOVERENÉ.

### 7 · Kontrola a „cenový export zastavený"

Kontrola: semafor RED/ORANGE ako filtre + zelený info chip (`studio.js:364-381`), riadok bodka · text · miesto · akcie (427-468), zoznam a filter (1475-1493),
badge navigácie z `counts` (475-488); klik = `nx_select` s `problem_key`, ceruzka + Inspector; nález bez entity vedie deep-linkom do sekcie (`ROUTE_SECTIONS`
`production_core.rb:2293-2316`); rozpočtový nález → sekcia Rozpočet (`studio.js:1989-1995`). **Rozpočtové nálezy sú VŽDY ORANGE** (`Validation.budget_item`
`nx/core/validation.rb:293-318`, `Budget.check` `budget.rb:680-718`) → RED „plán neúplný" potrebuje vlastnú cestu. **Existuje RED `oversize`** „nezmestí sa na formát
platne" — bez orezu, s rešpektom smeru dekoru (`validation.rb:59, 515-538`, `DIM_TOL 0.1` 44-45).
**Nález Kontroly export NIKDY neblokuje** („RED neblokuje VEPO ani nič iné", `production_core.rb:1371-1373, 1638`); blokujú len výslovné brány v exporte:
`newer_config_stop`, `cut_stop` (D-143), `budget_std_block`, `drawer_stop`, `export_blockers` (tvrdé) a potvrditeľná „riadky bez ceny" (`do_budget_xlsx` 3168-3206,
`do_cp_xlsx` 3249-3293; texty `export_blocked_status` 1610-1612, `export_confirm_status` 1616-1619). UI vzory zastavenia: trvalý banner `.hwbanner` R-14
(`budget.js:268-272`) + vypnuté ovládače (277-289); červený banner „zastavené VŠETKY exporty" v Nákupe (`studio.js:626-633`, CSS `studio.html:318-321`);
jantárové chipy nad súčtom vedú do Kontroly (`budget.js:132-155, 485-503`); XLSX priznáva riadky bez ceny (`xlsx_writer.rb:475-480`).
Pozor na meno: `cut_stop`/`cut_issues`/`CUT_BLOCKERS` = D-143 „rozmer do nárezu" chrbta (`production_core.rb:1205-1243`) — kolízia s id sekcie `cut`.

### 8 · Testy UI — vzory

JS (Node, CI spúšťa každý `tests/js/test_*.js` zvlášť — `.github/workflows/tests.yml:22`): čisté funkcie cez `require(studio.js)` so stubom `window/document`
(`tests/js/test_st1b_kontrola.js:17-22`, `test_st1a_studio.js`, `test_d94_povod.js` — `source_ref` namiesto pids); render v SPOLOČNOM scope `studio.js`+`budget.js`
cez `vm` nad `tests/js/minidom.js` (`test_st1c_rozpocet.js`, `test_r14_budget_std.js`); nastavenia `test_st4a_settings.js`, `test_budget_ui.js` (patch len zmenených polí);
jantár „Obnoviť" `test_stale_obnovit.js`. Headless Ruby (`tests/run_all.rb` načíta `tests/pure/test_*.rb`): payload/rozpočet `test_budget.rb`, `test_st1c_rozpocet.rb`,
`test_sheet_estimate.rb`, `test_cp_export.rb`; marker a brány s fake modelom počítajúcim operácie `test_r14_budget_std.rb` (202-239, 282-355); nastavenia
`test_supplier_settings.rb`, `test_r08_zamky.rb`, `test_r11_degradovana_zaloha.rb`, `test_st4a_nastavenia.rb`; stale `test_stale_obnovit.rb`.
In-SU (brána mergu pri zápise do modelu): `tests/sketchup/su_runner.rb` — `st1c_bud_op` „zápis zmení stav + 1× Späť ho vráti" (15710-15724), `st1c_budget` 12 operácií,
gen/guid guardy, XLSX guard bez dialógu (15726+), `run_r14` (8437), `run_stale` (12827), `run_st1b` (15350); runner `scripts/run_su_tests.ps1 -CloseWhenDone`.

### Otázky/riziká pre koncept a mockup

1. **Kde žijú kerf/orez** — globálne pri dodávateľovi (A, bez bumpu, ale bez doprednej brány súboru) vs. per zákazka (B, bump `BUDGET_STD` 3 zablokuje starší
   plugin na druhom PC pri prvej úprave rozpočtu) vs. hybrid (C). Návrh §1 a §6 si tu protirečia.
2. **Čo presne ukáže Rozpočet** — dnes tam nie je rozsah min–max, len `ceil(count_max)`; „plán: N" ako text v poznámke (automaticky aj do XLSX) alebo nový stĺpec
   (tabuľka má 6 stĺpcov pri ~828 px). Prepínač „ceny podľa plánu" do `<summary>` sekcie Materiál (precedens Spotrebiče), nie do preplnenej lišty.
3. **Prepínač pohne aj porezom a montážou** (Σ platní) — chceme montáž (5,8 m²/platňa, `POJMY.md:274`) počítať z hornej hranice plánu?
4. **Výkon a „dve pravdy":** plán v `push_state` pobeží pri každej mutácii rozpočtu (dnes push ~3 ms, `ui-lifecycle.md:3204`) a musí ísť do všetkých 5 volaní
   `budget_payload`, inak XLSX/ponuka ≠ obrazovka. Alternatíva: lazy PULL len pre obrázok, počty v pushi.
5. **RED „plán neúplný" blokujúci cenové exporty je nové správanie** — dnes oversize dielec (RED) export nezastaví; navyše vznikne druhý RED k tomu istému dielcu
   (existujúci `oversize` bez orezu vs. plán s orezom) — zjednotiť/deduplikovať?
6. **Klik na kus v pláne** — označiť všetky rovnaké kusy (`parts_key`, hotové) alebo presne jeden (`owner_id + part_key`, identita `<part_key>#<n>` z návrhu §8.2)?
7. **Rozloženie obrázka** vs. vertikálny priestor — mriežka miniatúr platní + detail po kliku? Farby cez CSS triedy s tokenmi (téma-bezpečné) namiesto hex zrkadiel preview.js.
8. **Guard/doc dlh:** ~10 testov a 5 dokumentov pribíja „Nárezový plán = jediná neaktívna položka"; STANDARD §12 ho má mimo scope V1; meno `cut` koliduje s D-143 `cut_*`.
