# K3 · rohová skrinka — fakty z kódu pred debatou a krížovým auditom

- **Dátum:** 27.9.2026 · **repo:** `C:\APP DEV\RUBY\ENGINE` · **vetva:** `main` · **HEAD:** `44a9d2d4ed14772e0f1cf5c3b6f649c993be4732` (plugin **v0.14.0**, `noxun_engine.rb:9`)
- **Charakter:** READ-ONLY FAKTY, NIE NÁVRH. V repe sa nič nemenilo. Čo nie je overené čítaním kódu, je označené **NEOVERENÉ**. Grepy vynechali `SYSTEM/archiv/` a `.claude/worktrees/` (kópie repa).
- **Zadanie bloku:** `SYSTEM/zdroje/next_sessions/V1_DEBATA_2026-09-05_KONSTRUKCIA.md` §3 (r. 48–71) · `SYSTEM/PLAN.md:271–276`, `:683` · `SYSTEM/V1_VIZIA.md:16–20` · `SYSTEM/zdroje/next_sessions/07_KONSTRUKCIA_V1.md:119–133` (§C.1). Cesty sú relatívne ku koreňu repa; `súbor:riadok` = stav na HEAD vyššie.
- **Prečítané:** `CLAUDE.md`, `docs/ARCHITEKTURA.md`, `docs/architecture/construction.md` (construction, cabinet_builder, ghost_tool, placement, zone_tree, fronts, part_faces, scale_observer), `model-a-identita.md` (part_keys, build_plan), `outputs.md` (bom, vepo_export), `materials.md` (D-131, MR-3), `SYSTEM/STANDARD.md` §2.4, §3.2–3.4, §4, §5.3, §10, §12, `VEPO_KONTRAKT.md`, `POJMY.md`, `ARCHIWOOD_INSPIRACIA.md` (o rohových nič), `STAV.md`, `DOGFOODING.md`, vzor `SYSTEM/archiv/bloky/KONSTRUKCIA/FAKTY_Z_KODU_2026-09-26.md` + kód nižšie.
- **Kontrakty na HEAD** (`STAV.md:24–27`): `CONFIG_SCHEMA` **21** (`cabinet_builder.rb:305`) · BuildPlan `SCHEMA` **6** (`build_plan.rb:98`) · ABS `SEED_VERSION` **5** (`abs_rules.rb:57`) · `TemplateStore::STD` **7** (`templates.rb:73`) · `PartKeys::SCHEMA` 1 (`part_keys.rb:9`) · seed pravidiel kovania 7 (`hardware_rules.rb:93`).

**Kľúčové zistenia v skratke:**
1. **Rohová v kóde neexistuje v žiadnej podobe** (grep `corner|rohov|cr1|cr2|hinge_rail|cr_front|cr_side` = 0 zhôd v kóde; „Rohová 900" je len vzorka ručného názvu v `tests/pure/test_d100_nazvy.rb:43`). `TYPES` je uzavretý zoznam `lower upper dishwasher` (`cabinet_builder.rb:55`), neznámy typ sa **ticho sklopí na `lower`** (`:4054–4057`). Posledný nový typ (S1-E slot, PR #381) sa dotkol **48 súborov** a dnes je vetva `dishwasher` v 25 súboroch pluginu; zoznam typov presne pripína 7 testov (§11).
2. **Plochu čiel na časť šírky obmedziť dátovo vieme**: `Construction.front_opening(cfg)` vracia `{x0, w, z0, h}` (`construction.rb:539–551`) a `Fronts.resolve_layout` ho rešpektuje (`fronts.rb:161`, `:211`) — dnes ho využíva len slot. **Plnú šírku natvrdo predpokladajú** panelový preflight (otvor len pre slot, `actions_cabinet.rb:55`), JS kresba čiel a značiek kovania (`preview.js:886`, `:1140`) a draft resolver (`preview.js:445–472`). Čelá sa delia **len na výšku** (`'split_axis' => 'height'`, `fronts.rb:517`); zvislé stĺpce čiel ani „slepá časť bez čiel" ako pojem neexistujú.
3. **Zrkadlenie transformáciou inštancie je v engine neplatný stav:** vklad ho odmietne (`rigid_matrix?` = determinant +1, `cabinet_builder.rb:725–741`, veta `:703–706`), ghost ho nevie vyrobiť (rotácia len okolo Z, `ghost_tool.rb:699–711`), nástroje ho odmietnu vetou o „mierke alebo skosení" (`tools/tools.rb:25–26`, `:96–109`), cache `ScaleWatch` si ho nezapamätá (`scale_observer.rb:737–756`); prestavba ho však ticho ponechá (`cabinet_builder.rb:836`) a „Použiť vzhľad" ho prijme (`materials_apply_appearance.rb:296–306`). Dielce sú osové kvádre s čistou transláciou (`add_part` `:2144–2154`) → zrkadlenie v pláne = prepočet X originov.
4. **Dielec z čelového materiálu mimo 4 rolí čiel je pasca:** katalógovú hrúbku 18,6/19 toleruje `thickness_ok_for?` len rolám `front_door drawer_front flap false_front` a zásuvkám (`cabinet_builder.rb:1498–1515`), inak `validate_material_thickness!` **zhodí stavbu** (`:1472–1486`); `materialized_part` (`:2690–2703`) prepisuje hrúbku len týmto rolám a **predpokladá hrúbku v osi Y a origin Y = −th** — CR 2 (rovina YZ, hrúbka v X) by dostal zlú geometriu. Rola `cover_panel` je v `BuildPlan::ROLES` rezervovaná, pozná ju však len `CpExport` a `HardwareRules::FRONT_ROLES`.
5. **Nová rola prechádza ~20 uzavretými zoznamami** (§2.6), **nový typ ~25 miestami** (§1.2); ABS default dostane nová rola na existujúcom PC len s bumpom `SEED_VERSION` (`abs_rules.rb:263–277`, inak dielec bez pásky); čísla schém sú v testoch pripnuté (§11).
6. **Závesy sú položka ČELA, nie „na ktorom dielci sedia":** vlastník `front:F#/wing:*`, počet podľa výšky dverí (≤ 849 → 2) a +1 nad šírku krídla 600 (`hardware_rules.rb:280–303`, `:1733–1741`, `:1755–1768`); proxy geometriu majú len nohy a úchytkové profily (`cabinet_builder.rb:2234–2260`, `:1092`). Strana pántov je trojstav `direction`; guard zakazuje v Ruby aj JS akýkoľvek default či natvrdo zapísanú stranu (`tests/pure/test_kova1_cela.rb:574–593`).
7. **Nohy pri šírke 1100 = 6 ks** (`max 999 → 4`, inak 6; `hardware_rules.rb:252–260`), príchyt sokla 2 ks len pri `support legs` a sokli ≥ 55 (`:266–273`). Pravidlá korpusu filtrujú len `support`, `cabinet_type`, `floor_height_min` (`:1300–1316`) → nový typ dostane nohy ako dolná (`construction.rb:1202–1205`), Bystricu nie; **náhľad nôh vo vkladaní beží len pre `lower`** (`hardware.js:2458`).
8. **Interiér nemá rolu ani kontrolu pre rohové výstuhy:** police idú cez celú šírku medzi bokmi od `y = 20` (`zone_tree.rb:25`, `:547–567`), `divider_v` má vždy plnú hĺbku zóny (`:521–533`); dielec typu „výstuha závesov" (hĺbka 80) ani „blenda korpusová" (vnútorná čelná doska) neexistuje a **kolízie dielcov engine nekontroluje** (STANDARD ich len menuje, `STANDARD.md:1461`).
9. **Absorpcia scale ŠÍRKY nie je config-aware** (`MIN` 200 / `MIN_BY_TYPE`, `scale_observer.rb:490`, `:550–562`) na rozdiel od výšky (`:571–588`) a hĺbky (`:592–605`) — zúženie pod minimum konštrukcie skončí výnimkou prestavby a tichým návratom (construction.md:426–429).
10. **Rozpory v dokumentoch:** STANDARD hovorí „rohové korpusy mimo scope V1" (`STANDARD.md:403`, `:1550`); PLAN zdôvodňuje rohovú ako TYP „L-pôdorys, 2 čelné roviny" (`PLAN.md:683`), K3 je však pravouhlý korpus s rohovou zostavou. **Inspector nemá prepínač typu označenej skrinky** (`core.js:1520–1523`) — `panel.html:896` zo zadania je `<select id="tplSaveType">` modalu „Uložiť ako šablónu"; postreh „Prepínanie typu HORNÁ/DOLNÁ … občas zlyhá" žije len v `PLAN.md:228` (blok 3, bez D-čísla, z éry pred UI-C1b).

---

## 1 · Typy korpusu a precedens `dishwasher`

### 1.1 Typy dnes

| | Dolná `lower` | Horná `upper` | Slot `dishwasher` |
|---|---|---|---|
| Predvoľby | `LOWER_DEFAULTS` `cabinet_builder.rb:13–21` (600×720×510, sokel 100, dno pod bokmi, naložený HDF 3, lišty 100) | `UPPER_DEFAULTS` `:25–32` (320 hĺbka, sokel 0, dno medzi, drážka) | `DISHWASHER_DEFAULTS` `:44–50` (600×880×560, trieda 600, telo 820, sokel čela 100) |
| Plán | `build_plan` | `build_plan` | vlastná vetva `appliance_slot_plan` (`construction.rb:116–118`, `:339`) |
| Podpora | nohy / sokel | `none` (`construction.rb:1203`) | `none` vždy |
| `floor_height`, `plinth_mode` | zo vstupu | vynútené 0 / `none` (`cabinet_builder.rb:3078`, `:3085`) | vynútené 0 / `none` |
| Auto názov | „Spodná skrinka W" | „Horná skrinka W" | „Umývačka 60 (slot)" (`:2988–2999`; vzor `AUTO_NAME_RE` `:89`) |
| `template_id` / preset | `base-lower-18` / `noxun-lower-18` | `base-upper-18` / `noxun-upper-18` | `dishwasher-slot-18` / `noxun-dishwasher` (`:3006–3012`, `:2932–2939`) — neznámy typ padne na dolnú vetvu |
| Výška vkladu `home_z` | 0 | 1400 `UPPER_HANG_Z` (`:560`, `:93`) | 0 |

„Vysoká" ani „rohová" typ nemajú — vysoká skrinka je `lower` s väčšou výškou (šablóna Chladničková, `templates.rb:843–876`).

### 1.2 Kde sa dnes vetví podľa typu (miesta, ktorými by šiel nový typ)

- **Ruby jadro:** `cabinet_builder.rb` — `TYPES` `:55`, predvoľby `:13–50`, `AUTO_NAME_RE` `:89`, `prepare_insert` `home_z` `:560`, `write_cabinet_attrs` `:2827`, `cabinet_config` `:2859`, `:2863`, `:2907` (polia slotu len pri `dishwasher`), `:2912` (komín/lišty mimo slotu), `construction_preset_for` `:2932`, `default_name` `:2988`, `template_id_for` `:3006`, `defaults_for` `:3047–3053`, `normalize` `:3057–3097`, `config_to_params` `:3919` (`'type' => cfg['type'] || 'lower'`), `legacy_plinth` `:4036–4040`, `norm_type` `:4054–4057`. `construction.rb` — `:116–118`, `:540`, `:1203`, `:1235` (`cabinet_type` v kontexte kovania), `:1291`, `:1367`, `:1448`, `:1502`. `scale_observer.rb:30–31` (`MIN_BY_TYPE`), `:489`, `:576`, `:593`. `appliance_binding.rb:50`, `:66`, `:447`, `:452–455`, `:560`, `:836`. `appliance_checks.rb:78`. `bom.rb:328`, `:448`, `:539`. `direction_check.rb:178`. `templates.rb:178`, `:202`, `:787`, `:878`, `:906`, `:917`. `hardware_rules.rb:315–317` (Bystrica len `upper`). `ghost_tool.rb:1543–1547` (pamäť výšky zámku per typ).
- **Ruby panel:** `actions_cabinet.rb:15–18` (`PARAM_KEYS` obsahuje `type`), `:23–24` (`TEMPLATE_TYPE_WORDS`), `:40`, `:55`, `:91`, `:307`, `:546`, `:814`; `actions_templates.rb:220–233` (`apply_template_type!` — whitelist `%w[lower upper]`, slot typ nemení), `:250`; `actions_appliance.rb:94`, `:229`, `:331`; `payloads.rb:171–183`, `:684`, `:2329`; `sync.rb:40–46` (`DEFAULTS` per typ do JS); `templates_dialog.rb:419–424` (šablóna iného typu sa na skrinku nepoužije).
- **JS:** `core.js:887` (symbol blendy slotu), `:1122` `NX_TYPE_LABEL`, `:1527–1531` `CAB_TYPES`/`setType` (neznámy → `lower`), `:1563`, `:1597`, `:1736`; `form.js:176` `TYPE_LIMITS`, `:192`, `:232`, `:235`, `:260`, `:279`, `:289`, `:329`, `:409`, `:415–419` (preflight posiela typ a otvor slotu), `:693–700`, `:725–755` (`applyVisibility`, `SLOT_ONLY_ROWS`/`SLOT_HIDDEN_ROWS`/`SLOT_HIDDEN_GAPS`), `:765`, `:828`, `:836`, `:843`, `:868`, `:1342`, `:1479–1490` (modal šablóny, zámok typu pri slote); `insert_state.js:39` `INSERT_TYPES`, `:83`, `:256–267` (`templateType`/`templatesForType` — **neznámy typ šablóny → „dolná"**); `preview.js:341`, `:382`; `shell.js:25–33` (`NX_CTX_LOCK` — slot nemá Zóny); `templates.js:70`, `:232`; `hardware.js:2376`, `:2458`, `:2467`; `rules.js:272–275`; `bridge.js:667–672`.
- **HTML:** `panel.html:190–195` (vkladacia karta: Dolná · Horná · **Umývačka** `:193` · Doska), `:280–288` a `:306–310` (riadky slotu), `:893–900` (`tplSaveType` + tooltip zámku pri slote).

### 1.3 Precedens S1-E (PR #381, merge `aa1cec5f`) — dotknuté súbory (48)

- **Jadro:** `cabinet_builder.rb` (+379 r.), `construction.rb` (+153), `build_plan.rb` (+70, kľúč `references`), `templates.rb` (STD 5, seedy), `validation.rb` (+64, `dw_body_fit`/`dw_height_fit`), `bom.rb` (+30), `scale_observer.rb` (`MIN_BY_TYPE`), `placement.rb` + `tools/mower.rb` + `tools/snaper.rb` (nominálna obálka `envelope`), `board_builder.rb` (`BOARD_CONFIG_SCHEMA` 2), `modules/fronts.rb` (otvor `opening:`), VERSION v `noxun_engine.rb` + `main.rb`.
- **Panel Ruby:** `actions_cabinet.rb` (+142), `actions_templates.rb`, `payloads.rb`, `sync.rb`, `templates_dialog.rb`.
- **UI:** `form.js` (+184), `preview.js` (+156, `drawSlotBase`/`drawSlotDetail`), `shell.js`, `bridge.js`, `core.js`, `insert_state.js`, `templates.js`, `hardware.js`, `panel.html` (+100), `panel.css`, `studio.html` (len `?v=`).
- **Testy:** nové `tests/pure/test_s1e_slot.rb` (dnes 738 r.) a `tests/js/test_s1e_slot.js` (484 r.); úpravy `test_ghost_d1_dosky.rb`, `test_materials_abs_persistence.rb`, `test_s1e0_min_vyska.rb`, `test_uic1a_sablony.rb`, `test_uic1c_orientacia.rb`; in-SU `su_runner.rb` (+257, `run_s1e` `:3702`).
- **Dokumentácia:** STANDARD (§4.2, §5.3), POJMY, PLAN, STAV, KRONIKA, `docs/architecture/` appliances, construction, model-a-identita, outputs, ui-lifecycle.
- Po S1-E typ ďalej rástol: D-138 (čelo „Dv myčka", `construction.rb` `DW_FRONT_NAME`), D-139 (odvodené čelo, schéma 17), S1-B1/B2/C/F (väzby spotrebičov).

### 1.4 Zmena typu označenej skrinky

- **V UI neexistuje:** typ označenej skrinky je len zrkadlo jej configu (`bridge.js:667–672` → `setType(t)`); `setType` volá už len vkladanie (`form.js:1292`) a reset výberu (`bridge.js:330–332`); komentár `core.js:1520–1523` („typ korpusu už nedržia rádiá… pri označenej skrinke je to zrkadlo JEJ typu").
- **Server by typ prijal:** `handle_apply` / `handle_apply_all` kopírujú `PARAM_KEYS` vrátane `type` (`actions_cabinet.rb:759–761`, `:867–869`) nad `existing_params` = `config_to_params` (`payloads.rb:2294–2296`) → `normalize` s predvoľbami nového typu (`cabinet_builder.rb:3057–3058`). Zachová sa všetko, čo config nesie; vynútené sa zmení `floor_height`/`plinth_mode` (horná, slot), polia slotu a komín pri slote, `template_id`, preset a auto názov. `part_key` nezávisí od typu; override zaniknutého dielca ostáva dormantný (§2.4).
- **Šablóny:** použitie šablóny iného typu na skrinku server odmietne (`templates_dialog.rb:419–424`); modal „Uložiť ako šablónu" smie prepnúť TYP ŠABLÓNY len `lower ↔ upper`, slot nikdy (`actions_templates.rb:223–233`; guard `tests/pure/test_uib3_rady.rb:158`).
- **Postreh „Prepínanie typu HORNÁ/DOLNÁ na označenom korpuse občas zlyhá"** — `PLAN.md:228` (blok 3 STABILITA, „odložené, rieši sa s knižnicou/editorom typov"), zapísaný pri U1 (commit `71068f09`), keď typ prepínali rádiá. Cesta, ktorou by sa dal dnes zopakovať, v UI nie je — **NEOVERENÉ**, či je postreh ešte aktuálny.

---

## 2 · Geometria, BuildPlan, roly a identita

### 2.1 Osi (STANDARD.md:339–353)

X = šírka (zľava doprava), **Y = hĺbka, +Y ide dozadu**, Z = výška. Origin korpusu = ľavý-predný-dolný roh, **čelná rovina Y = 0**, čelá v zápornom Y. `d` = celková hĺbka vrátane chrbta (D-37), `t` hrúbka, `s` sokel, `R` = zadný doraz `back_stop` (`construction.rb:1305–1308`; bez komína `carcass_depth` = `d − bt` pri naloženom, inak `d`), `Y` = zapustenie stropu.

### 2.2 Dielce dnešnej dolnej/hornej (Construction)

| Dielec — `part_key` · rola · názov | `box [X,Y,Z]` | `origin` | Kód |
|---|---|---|---|
| Boky `cabinet/side:left\|right` · `side_left/right` · „Bok lavy/pravy" | `[t, side_depth, h − z0]` (z0 = s+t pri `under_sides`, inak 0) | `[0 \| w−t, 0, z0]` | `construction.rb:1583–1600` |
| Dno `cabinet/bottom` · „Dno" | `[w \| w−2t, R, t]` | `[0 \| t, 0, s]` | `:1602–1615` |
| Vrch plný `cabinet/top` · „Vrch" | `[w−2t, R−Y, t]` | `[t, Y, h−t]` | `:1617–1633` |
| Výstuhy `cabinet/rail:front\|back` · „Vystuha predna/zadna" | flat `[w−2t, rd, t]`, upright `[w−2t, t, rd]` | F `[t, Y, z_b]`, B `[t, R−rd \| R−t, z_b]` | `:1644–1681`, `rail_geometry` `:1407–1442` |
| Chrbát `cabinet/back` · „Chrbat" | overlay `[w, bt, h−s]`; inset/groove `[w−2t, bt, z_hi−z_lo]` (+ `cut_size` pri drážke) | overlay `[0, d−bt, s]`; inset `[t, d−bt, z_lo]`; groove `[t, d−10−bt, z_lo]`; komín `setback_back_part` | `:1720–1778` |
| Lišty chrbta `cabinet/back_rail:bottom\|top` · „Lista chrbta" | `[w−2t, t, H]` | `[t, R−t, z_lo \| z_hi−H]` | `:1780–1797` |
| Sokel `cabinet/plinth:front` · „Sokel predny" | `[w \| w−2t, t, s]` | `[0 \| t, recess, 0]` | `:1799–1815` |
| Priečka `zone:<uzol>/divider_v:<i>` · „Priecka zvisla" | `[t, hĺbka zóny, výška zóny]` | `[pos, y0, z0]` | `zone_tree.rb:521–533` |
| Polica `zone:<uzol>/shelf:<i>` · „Polica N" | `[šírka zóny, hĺbka − 20, t]` | `[x0, y0 + 20, z]` | `zone_tree.rb:547–567` |
| Čelá `front:<id>/wing:*`, `/panel`, `/flap`, `/blind` | `[šírka, 18, výška]` | `[x, −18, z]` (hrúbku a Y prepíše `materialized_part`) | `fronts.rb:365–438` |

- **Vnútro** `interior_dims` (`construction.rb:1539–1574`): `z_lo = s + t`; `z_hi` = `h − t` (plný) · spodok výstuh · `h` (bez stropu); `back_front_y` per režim chrbta (lišty `R − t`, komín `R`/`R − bt`). Strom zón stojí na boxe `x ∈ [t, w−t]`, `y ∈ [0, back_front_y]` (`:137–138`).
- **Odmietnutia** `validate!` (`:1835–1858`): šírka ≤ 2t + 10, vety komína/zapustenia/líšt, `back_front_y ≤ 10`, sokel ≥ výška, vnútro ≤ 10, výstuhy bez rezervy 20.
- **Proxy a referencie:** nohy `render_hardware` (`cabinet_builder.rb:2234–2260`, rady podľa `back_stop`, `:2505–2531`), úchytkový profil `render_front_profile` (`:1092`), referencie spotrebičov `render_references` (`:2288+`).

### 2.3 BuildPlan (`build_plan.rb`)

- **`SCHEMA` = 6** (`:98`; história `:14–35`: 4 = roly zásuviek, 5 = `plinth_clip`, 6 = roly líšt chrbta). Precedens: nová rola = bump („plán, ktorý ju môže niesť, už nie je plánom predošlej schémy", `docs/architecture/model-a-identita.md:177–184`). Aditívne voliteľné kľúče (`references`, `hardware_conflicts`, `cut_size`) bump nemali.
- **`ROLES`** (`:113–119`): `side_left side_right bottom top back shelf divider_v divider_h front_door drawer_front flap cover_panel false_front rail_front rail_back plinth gola_profile free_panel drawer_bottom drawer_back box_side drawer_inner_front back_rail_top back_rail_bottom`. `cover_panel` a `gola_profile` sú rezervované (plán ich nevydáva — grep).
- **`validate_part!`** (`:434–472`): rola zo `ROLES` (`:443`), `material` ∈ `korpus front concrete drawer` (`:450`), `box` kladný, **`origin` smie byť záporný** (`:454`), `axes` permutácia, `back_mode` len rola `back` (`BACK_MODES` `:521`), `cut_size` ≥ geometria a **nezávislý od roly** (`:541–558`). `REFERENCE_ROLES` = `appliance_body appliance_niche` (`:155`).

### 2.4 Identita (`PartKeys`) a ručné zásahy

- `SCHEMA 1` (`part_keys.rb:9`), `cabinet(kind, variant)` → `cabinet/<kind>[:<variant>]` (`:13–16`), `front(id, kind, variant)` (`:22–25`), `valid?` = prefix `cabinet/|zone:|front:|board/` (`:45–47`), `segment` `[A-Za-z0-9_.-]` (`:183–186`). Aditívne kľúče `SCHEMA` nebumpujú (KOV-A1 `/flap`, `/blind`; KOV-C2b; KON-B — model-a-identita.md:129–138, `:177–179`).
- `human_label` (`:89–120`) pozná len čelá, zásuvky a zóny; kľúč `cabinet/…` vráti surový. `MANUAL_OWNER_PREFIXES = %w[front: zone:]` (`payloads.rb:808`) — vlastníkom ad-hoc kovania smie byť len čelo alebo zóna.
- **`part_overrides`** (`{part_key => {material_id, grain_direction, edges, edge_warnings}}`, STANDARD §7.2): `norm_overrides` existenciu dielca nekontroluje (`cabinet_builder.rb:3337+`), `PartKeys.migrate_overrides` **zachová kľúče neexistujúcich dielcov** (`part_keys.rb:52–72`) → zaniknutý dielec má override **dormantný** a po návrate znova platí (model-a-identita.md:126–128). Pri prepnutí typu čela ostávajú overridy pod starým kľúčom (`:131–133`). Kovanie: `override_orphan_kind` `disabled · invalid · dormant` (`hardware_rules.rb:1960–2005`).
- **Kľúče nezávisia od rozmerov ani polohy** — zrkadlenie v pláne by `part_key` nemenilo; override hrany `L1` by však po prepnutí L/P mohol fyzicky ukazovať na inú hranu (§5).

### 2.5 Materiál per rola

- **`Construction.material_channel(role, mat_sym)`** (`construction.rb:76–84`) je jediné miesto pravdy: `FRONT_MATERIAL_ROLES = %w[front_door drawer_front flap false_front]` (`:73`) → čelový kanál · `back` → kanál chrbta · roly zásuviek / `:drawer` → zásuvky · signál `:front` → čelo · inak korpus. Volá ho `CabinetBuilder.base_material_for` (`cabinet_builder.rb:1880–1887`) aj anotácia hmotnosti.
- Čelový materiál dnes berú **dvierka, zásuvkové čelo, výklop/sklop a blenda**; iná rola len cez signál deskriptora `material: :front` (vzor `cover_panel`, komentár `construction.rb:69–72`).
- **`material_source` NIE JE čelo/korpus** — je to väzba duplák → zdrojový materiál (2B-1, D-43; `material_source_for` `:1440–1447`, zápis do snapshotu `add_part` `:2192–2193`).

### 2.6 Uzavreté zoznamy rolí (každá nová rola musí prejsť všetkými)

| Zoznam | Kde | Čo chýbajúca rola spôsobí |
|---|---|---|
| `BuildPlan::ROLES` | `build_plan.rb:113–119` | plán neprejde validáciou |
| `AbsRules::EDGE_LABELS` / `SEED_RULES` / `SEED_VERSION` | `abs_rules.rb:67–103`, `:140–171`, `:57` | popisy „Hrana 1–4"; bez pravidla a bez bumpu seedu **bez pásky** |
| `AbsRules.edge_sides` (natvrdo 4 roly čiel) | `abs_rules.rb:462–468` | 2D karta dielca kreslí hrany ako ležiaci dielec |
| `PartFaces::ROLE_AXES`, `STANDING_ROLES` | `part_faces.rb:152–167`, `:85` | stará zákazka: Kontrola olepov/hover nezvýrazní; mapa L1/L2 |
| `CabinetBuilder::PART_TAGS` | `cabinet_builder.rb:418–437` | tag `Noxun/Korpus` (7 riadkov tagov je pevných, `tags.rb:40–48`, `:64–73`) |
| `Construction::FRONT_MATERIAL_ROLES` | `construction.rb:73` | kanál podľa signálu deskriptora |
| `thickness_ok_for?` (roly čiel + zásuvky) | `cabinet_builder.rb:1498–1515` | 18,6/19 mm čelový materiál = výnimka stavby |
| `materialized_part` (4 roly čiel) | `cabinet_builder.rb:2690–2703` | hrúbka ostane 18, geometria nesedí s materiálom |
| `Validation::FRONT_ROLES` | `validation.rb:50`, `:502`, `:555` | žiadne ORANGE „čelo bez ABS"; hrúbka presnou zhodou |
| `ProductionCore::ROLE_LABELS` | `production_core.rb:1799–1821` | stĺpec Rola ukáže surový identifikátor |
| `part_card.js` `roleLabel`, `isFront` | `part_card.js:2–12`, `:52–53` | karta dielca: surová rola; čelový materiál v pickeri neaktívny |
| `RulesDialog::ABS_ROLE_ORDER` | `rules_dialog.rb:44–47` | rola sa pripojí na koniec prehľadu ABS |
| `CpExport::FRONT_ROLES` | `cp_export.rb:94`, `:373–384` | v cenovej ponuke „vnútorné korpusy" namiesto „dvierka" |
| `HardwareRules::FRONT_ROLES` | `hardware_rules.rb:1781` | len parameter výšky pre výsuvy |
| `VepoExport::SHORT_NAMES` / `NAME_PAIRS` | `vepo_export.rb:72–83`, `:99–100` | názov ide do VEPO celý (limit 20 znakov) |
| `PartKeys.human_label`, `MANUAL_OWNER_PREFIXES` | `part_keys.rb:89–120`, `payloads.rb:808` | Kovanie/Kontrola ukážu surový kľúč; nedá sa zvoliť ako vlastník |
| `rules.js` `rdRoleDesc` | `rules.js:267–298` | popis pravidla = surová rola |
| `prune_profile_overrides` mapa typ→rola | `cabinet_builder.rb:3893` | len pre čelá s profilom |
| `MaterialsReplaceUni` hrúbka čela | `materials_replace_uni.rb:193`, `:425` | len rola `front_door` |
| Test `legacy_base_material` (pripnutá kópia kanálov) | `tests/pure/test_kovw_hmotnost.rb:162–171`, `:442–455` | rola pridaná do `FRONT_MATERIAL_ROLES` rozbije paritu |

### 2.7 Pasca „dielec z čelového materiálu, ktorý nie je čelo"

- `resolve_part` → `validate_material_thickness!` (`cabinet_builder.rb:1343`, `:1472–1486`) porovná hrúbku deskriptora s katalógom cez `thickness_ok_for?` — pre rolu mimo čiel/zásuviek **presná zhoda** (`:1511–1513`). Deskriptor s placeholderom 18 a materiálom 18,6 → výnimka „Materiál … má 18,6 mm, ale dielec … potrebuje 18 mm".
- `materialized_part` (`:2690–2703`) pre 4 roly čiel prepíše `box[1]`, `origin[1] = −th`, `prod.thickness` — **hrúbka je vždy os Y a dielec lícuje s rovinou Y = 0 spredu**. CR 1 v čelnej rovine tomu zodpovedá; CR 2 (hrúbka v X) a rohová výstuha nie.
- Kontrola hrúbky vo výstupoch stojí na tom istom pravidle (`validation.rb:487–508`).

---

## 3 · Čelá a zóny

### 3.1 Čelný otvor a obmedzenie šírky

- **`Construction.front_opening(cfg)`** (`construction.rb:539–551`) = jediná autorita „kde začínajú a kam siahajú čelá": korpus `{x0: 0, w: width, z0: floor_height, h: height − floor_height}`, slot vlastný. `build_plan` ho posiela do `Fronts.layout(..., opening:)` (`:146`; slot `:346`).
- `Fronts.resolve_layout` (`fronts.rb:147–212`): `opening_w = op[:w] − gap_left − gap_right` (`:161`), prvé čelo začína na `x = op[:x0] + gap_left` (`:211`); `normalize_opening` vyžaduje úplný a konečný otvor (`:217–229`). **Otvor užší než skrinka a posunutý v X je teda v jadre podporený** (dnes ho nevyužíva žiadna skrinka, len slot mení `z0`/`h`).
- **Kto predpokladá plnú šírku:** panelový preflight čiel počíta otvor len pre slot (`actions_cabinet.rb:34–75`, `:55`; JS posiela typ a pole slotu `form.js:405–420`) — precedens S1-E FIX E8 (construction.md:173–175); JS kresba čiel `ow = W − gapLeft − gapRight` od `x = gapLeft` (`preview.js:876–943`, `:886`), značky kovania (`:1140`), draft resolver čiel (`nxFrontsResolve` `:445–472`) a rozsah čiel pre scénu (`nxFrontsExtent` `:132`).

### 3.2 Delenie

- **Čelá sa delia len na výšku** (`'split_axis' => 'height'`, `fronts.rb:517`, `:886`): riadky odspodu, `fixed`/`auto` so zámkami (`:162–207`). Na šírku existujú len **krídla dvierok** 1–4 s rovnakou šírkou (`resolve_wings` `:440–452`, auto 2 krídla nad 600 mm otvoru `AUTO_TWO_ABOVE` `:28`). Riadok `none` = nika bez dielca **cez celú šírku otvoru** (`:366`). Stĺpce čiel ani čiastočne „slepý" riadok neexistujú.
- **Zóny** sa delia `v` (stĺpce) aj `h` (riadky), najviac 3 úrovne (`zone_tree.rb:33`, `:264–310`); čelá však so zónami viazané nie sú (čelo = celý otvor).

### 3.3 Blenda ako čelo

Typ riadku `blind` → rola **`false_front`**, kľúč `front:F#/blind`, suffix `BLIND-#`, názov „Blenda N" (`fronts.rb:383–386`); panelová matematika ako zásuvkové čelo (1 panel cez celý otvor); materiál čelový (`construction.rb:73`); ABS 4 hrany 1,0 (`abs_rules.rb:140+`, seed 3); tag Čelá; stĺpec Rola „Blenda" (`production_core.rb:1811`); VEPO „Blenda N" bez skratky (`VEPO_KONTRAKT.md`, sekcia Názov); v ponuke „dvierka" (`cp_export.rb:94`); pánty nemá (`direction_slots` `fronts.rb:249–263` → `[]`), smie mať úchytkový profil (`hardware_rules.rb:337–339`); `human_label` „F2 · blenda" (`part_keys.rb:162–167`). POJMY.md:14. **D-131 „Kresba čiel"** zbiera kľúče fyzických čiel výhradne cez `Fronts.panels_for` z `front_items` (outputs.md:508–515) — dielec, ktorý nie je riadkom čiel, by hromadná kresba nezasiahla.

### 3.4 Smer otvárania

`direction` = strana pántov, trojstav: kľúč chýba = legacy · `unset` = RED „neurčené" · `left`/`right` (`fronts.rb:47–55`, STANDARD §5.3). Aplikovateľnosť určuje výhradne `Fronts.direction_slots` nad efektívnym `wings_n` (`fronts.rb:249–263`). Guardy: žiadny default ani natvrdo zapísaná strana v Ruby/JS (`test_kova1_cela.rb:574–593`), literál `unset` len na allowliste (`:595–620`), `DIRECTION_UNSET` smie použiť len `fronts.rb` a `templates.rb` (`:630`). Úchytkový profil s hranou `free` ide oproti pántom a bez smeru sa odmietne (`fronts.rb:303–325`).

### 3.5 Medzery (config čiel, per skrinka)

| Pole | Default | Rozsah | Kód |
|---|---|---|---|
| `gap` (medzi riadkami aj krídlami) | 3 | 0–50 | `fronts.rb:21`, `:458–463` |
| `gap_top`, `gap_bottom` | 2 | ±100 (odomknuté ±2000) | `:22`, `:464–470` |
| `gap_left`, `gap_right` (D-119, legacy `gap_sides`) | 2 | ±100 / ±2000 | `:521–522`, `:532–542` |
| `edge_limit_off` | false | bool | `:525` |

Šírka dverí: 1 krídlo = `opening_w`, 2 krídla `(opening_w − gap)/2`, 3–4 `(opening_w − (n−1)·gap)/n` (`fronts.rb:388–413`). Výška auto riadku = `(h_otvoru − gap_top − gap_bottom − (n−1)·gap − Σfixed)/n_auto` (`:162–167`). Delenie „medzery P na polovicu medzi dvere a CR 1" v engine neexistuje. Úchytkový profil UKW-7: skrátenie panela 36 mm, register `front_profiles.rb` (construction.md:887–898), hrany `top/bottom/free` (dvierka) a `top/bottom/left/right`.

### 3.6 Aritmetika tabuľky DC vs. dnešné vzorce (kontrola súčtov z debaty, DC neotvorené)

Dvere 446 = 450 − 2 (L) − 4/2 (P/2) → zodpovedá otvoru šírky 450 s `gap_left` 2 a `gap_right` 2 · blenda korpusová 632 = 1100 − 450 − 18 (od hrany dverovej zóny po vnútornú plochu boku) · 676 = 712 − 2·18 = `avail_h` pri plnom strope a dne pod bokmi, ak výška − sokel = 712 · výška rohovej výstuhy 712 = `front_opening[:h]` · dvere 707 = 712 − 5 (H) − 0 (D) · CR 1 78 = 80 − 2 · CR 2 96 = 80 − 2 + 18. Konkrétna výška a sokel DC: **NEOVERENÉ**.

---

## 4 · Interiér

- **Police** (`shelves.rb:17–38`, `zone_tree.rb:547–567`): rovnomerne v listovej zóne, max 6 (`Shelves::MAX`), šírka = šírka zóny (strom stojí na `x ∈ [t, w−t]`), hĺbka = hĺbka zóny − 20 (`SHELF_FRONT_INSET` `zone_tree.rb:25`), predná hrana na `y = 20`. Zóna ≤ 20 mm hĺbky → ORANGE `shelf_skipped_shallow_zone`.
- **Priečky:** `divider_v` (stĺpce) a `divider_h` vždy na **plnú hĺbku a výšku/šírku zóny** (`zone_tree.rb:521–545`); materiál korpus, ABS L1.
- **Výstuhy stropu:** `top_mode two_rails` + `rails_orientation flat|upright`, `rail_depth`, `rails_top_offset` (D-80, jediná autorita `rail_geometry` `construction.rb:1407–1442`, orezanie s warningom `:1817–1833`). KON-A: komín `back_setback` a zapustenie `top_front_setback` (`:1262–1340`, polia `SETBACK_KEYS` `cabinet_builder.rb:354`); KON-B: chrbát z líšt `back_mode rails` + `back_rail_height` (`:359`, `construction.rb:1354–1384`).
- **Zvislá priečka ako rola áno** (`divider_v`, len plná hĺbka zóny); **zvislá predná výstuha / stĺpik, vnútorná čelná doska ani výstuha mimo korpusu ako rola neexistujú** (`ROLES` §2.3). „Predná výstuha" = vodorovná `rail_front` pod stropom.
- **Kolízie dielcov** sa nekontrolujú (STANDARD.md:1461 v zozname kontrol; `validation.rb` rieši len kolízie identít `:666+`). Polica od `y = 20` by pretínala vnútorný dielec hlbší než 20 mm (napr. výstuha závesov 80); blenda hrúbky 18 pri `y ∈ [0, 18]` policu nepretína — fakt z čísel.
- Nika spotrebiča, recepty zásuviek a kovanie čítajú `back_front_y`/`clear_depth`; `clear_width` zásuvky = listová zóna pretínajúca riadok čela (`Construction.context_for` `:1094–1136`).

---

## 5 · Zrkadlenie L/P

### 5.1 Pojem strany dnes
Na úrovni skrinky žiadny (nie je pole „ľavá/pravá", „hand" ani „mirror" — grep). Stranu nesie len **čelo** (`direction` = pánty, profil `profile_edge`) a **schéma medzier** (`gap_left`/`gap_right`). Nástroje otáčajú o 90° (ghost `rotation_index` 0..3, `Tools::Mower.rotate`), nič nezrkadlí.

### 5.2 Zrkadlenie v pláne (fakty o mechanike)
- Dielec = osový kváder nakreslený `draw_box` a vložený **čistou transláciou** (`cabinet_builder.rb:2144–2154`); rotácia ani zrkadlo per dielec neexistuje. Zrkadlová poloha = prepočet `x' = w − x − box[0]`, `box` sa nemení.
- Mapa hrán je v lokálnych osiach (`part_faces.rb:75–80`): pri `AXES_FRONT` je `L1` = min X = „Ľavá", `L2` = „Pravá" (`abs_rules.rb:75–80`); pri ležiacich `W1/W2` = ľavá/pravá. Pri ABS dookola je to jedno; ručný override jednej hrany by po prepnutí L/P fyzicky ukazoval na opačnú hranu (kľúč sa nemení).
- Agregačný kľúč kusovníka nenesie polohu ani rolu (`bom.rb:1666–1676`) → rovnaké dielce ľavej a pravej skrinky sa zlúčia.

### 5.3 Zrkadlenie transformáciou inštancie

| Cesta | Čo spraví so zrkadlenou (ľavotočivou) maticou | Kód |
|---|---|---|
| `commit_insert` (vklad, ghost, kópia nástrojom) | **odmietne** — `rigid_matrix?`: jednotkové kolmé osi, determinant **+1**, veta „…zrkadlenie nie sú povolené" | `cabinet_builder.rb:597–598`, `:697–706`, `:725–741` |
| Ghost | nevie ju vyrobiť — matica len z rotácie okolo Z | `ghost_tool.rb:699–711`, construction.md:683–687 |
| `Tools.settle!` (Mower/Snaper) | **odmietne**, veta hovorí len o „mierke alebo skosení" | `tools/tools.rb:25–26`, `:96–109` |
| `ScaleWatch` detekcia | dĺžky stĺpcov = 1 → **nie je scale**, ide vetva presun/rotácia | `scale_observer.rb:455–468`, `:374–381` |
| `ScaleWatch.remember_transform` | **nezapamätá** (cache drží poslednú rigidnú = pred prevrátením) | `:737–756` |
| `reject_scale` | obnoví poslednú rigidnú polohu (teda nezrkadlenú) | `:700–705` |
| Absorpcia scale zrkadlenej skrinky | `clean_transform` = `Transformation.axes` z normalizovaných osí → prestavba s ňou; zachovanie ľavotočivosti **NEOVERENÉ** | `:691–693`, `:512`, `:524` |
| `rebuild` / `rebuild_in_operation` | rigiditu **nekontroluje**, transformáciu nemení (len ak príde `transform:`) | `cabinet_builder.rb:757–780`, `:836` |
| „Použiť vzhľad" (MR-3B) | **prijme** (\|det\| = 1) | `materials_apply_appearance.rb:296–306`; materials.md:282, `:302` |
| Kontrola olepov / hover | počíta v lokálnych osiach, „zrkadlená či otočená inštancia si smer von zachová" | `part_faces.rb:190–194` |

DC „Rohová" riešila L/P prevrátením komponentu (debata r. 63); pravidlo DC „nikdy Flip Along na animovanom komponente" (`docs/DC_PRAVIDLA.md:22`, STANDARD.md:351).

---

## 6 · Kovanie

| Pravidlo (seed) | Filter | Výpočet | Kód |
|---|---|---|---|
| `nohy-zakladne` | `cabinet`, `support legs\|plinth` | šírka < 1000 → 4, inak **6** (1100 → 6) | `hardware_rules.rb:252–260` |
| `prichyt-sokla` | `cabinet`, `support legs`, sokel ≥ 55 | < 1000 → 1, inak 2 | `:266–273` |
| `zavesy-podla-vysky` | rola `front_door` | výška ≤ 849 → 2 … 2800 → 7, `finite` (RED nad tabuľkou), +1 nad šírku 600, ORANGE nad 800, hmotnostné pásma len varujú | `:280–303` |
| `vysuvy-nl-podla-hlbky` | `drawer_front` | NL z `available_depth` | `:307–311` |
| `zavesenie-hornej-skrinky` | `cabinet`, `cabinet_type upper` | 2 ks | `:315–317` |
| `podperky-policove` | `shelf` | 4/policu | `:319–321` |
| úchytkové profily | `front_door`, `drawer_front`, `flap up/down`, `false_front` | dĺžka rezu = šírka panela | `:325–339` |
| výklopy / sklop | `flap` | trieda / závesy | `:340–413` |

- **Od typu závisí len** `support` (`Construction.support_type` `construction.rb:1202–1205`: `upper`, `dishwasher`, sokel 0 → `none`) a `cabinet_type` (`:1235`, filter `hardware_rules.rb:1307–1309`). Filtre korpusu: `support`, `cabinet_type`, `floor_height_min` (`:1300–1316`); filtre dielca: `role` + `flap_dir` (`:1292–1296`).
- **Závesy:** vlastník = kľúč krídla, `hinge_params` nesie len `use_type door` + `opening_mode` (`:1810–1816`); vstup `height` = `prod.length` čela (`:1755–1768`). Na ktorom dielci korpusu záves sedí, sa **nemodeluje**; proxy geometriu majú len nohy (`cabinet_builder.rb:2234–2260`) a úchytkové profily.
- **Úchytka:** automat pozná len úchytkový profil (D-90); kusová úchytka je ad-hoc `hardware_manual` s vlastníkom `front:` (`payloads.rb:808`); predvolené mapovanie `handle` je vedome bez setu (`hardware_sets.rb:816–818`).
- Nový typ s podporou nohy/sokel dostane nohy a príchyty ako dolná; horné závesné kovanie nie. Náhľad nôh vo vkladacej karte zahodí odpoveď pre iný typ než `lower` (`hardware.js:2458`).

---

## 7 · Výstupy

- **Kusovník:** riadok = agregácia podľa `[dĺžka, šírka, hrúbka, material_id, hrany L1..W2, grain, väzba duplák]` (`bom.rb:1666–1676`) — bez roly, názvu a polohy; plné názvy z buildera; stĺpec Rola z `ROLE_LABELS` read-only (`production_core.rb:1799–1851`, outputs.md:485–489). Rozmer do nárezu jediným čítaním `Bom.cut_dims` (`bom.rb:1378`); `cut_size` je v pláne nezávislý od roly, výrobné nálezy `cut_issues_for` sú len pre chrbát (`bom.rb:1533+`).
- **VEPO:** limit **20 znakov** na celý názov riadku vrátane skriniek (`vepo_export.rb:64`); skratky na PRESNÉ reťazce builderov (`SHORT_NAMES` `:72–81`), dvojice `Bok LP`, `Vyst PZ` (`NAME_PAIRS` `:99–100`), neznámy názov ide bez zmeny (`short_name` `:449–474`); čísla na konci tokenu sa zlučujú (`Polica 1 2 3`); orez po hranici tokenu + ORANGE `name_long` (outputs.md:857–871). Rotácia dekoru len tu (`oriented` `:135`).
- **ABS:** pravidlá per rola (`abs_rules.rb:140–171`): čelá vrátane blendy **dookola** 1,0; boky, dno, vrch, police, priečky, výstuhy `L1`; chrbát a sokel nič; lišty chrbta `L1`. Nová rola bez pravidla = bez pásky; existujúce PC ju dostanú len s bumpom `SEED_VERSION` (`merge_seed_roles` `:263–277` dopĺňa chýbajúce roly, vlastné hodnoty nemení). Popisy `EDGE_LABELS` (`:67–103`), fallback „Hrana 1–4" (`:104`). Kontrola: ORANGE „čelo bez ABS" len pre `Validation::FRONT_ROLES` (`validation.rb:552–563`).
- **Smer dekoru:** `effective_grain(sheet, override)` (`cabinet_builder.rb:1412–1418`) — materiál `length|width|none`, override len `length|width`; smer je vzhľadom na `prod.length`: čelá a boky majú dĺžku = výška (dekor zvislo), dno/vrch/police dĺžku = šírka. D-108 (per-dielec smer, incident blenda vs. dvere) a D-131 hromadná „Kresba čiel" (len riadky čiel).
- **Cenová ponuka:** kategória podľa roly (`CpExport.material_category` `cp_export.rb:373–384`): `FRONT_ROLES` → „dvierka", `back` → „chrbty", inak „vnútorné korpusy".
- **Kontrola per typ:** nika spotrebiča `ApplianceChecks.context` (slot vracia `{}`, `appliance_checks.rb:74–95`), slot `dw_body_fit`/`dw_height_fit` (`validation.rb:1042–1067`, záznam `Bom.appliance_slot_record` `bom.rb:538`), `APPL_NICHE_OWNERS` (`validation.rb:1110`); ostatné kontroly sú per rola alebo per výrobný záznam, nie per typ.

---

## 8 · Šablóny a vkladanie

- **Seedy** (`templates.rb`): „Dolna klasik", „Drezova", „Varna doska", „Horna klasik" (`:798–808`, bez `config_schema`); „Umývačka 60/45" (`:831–841`, s `config_schema`); **„Chladničková"** (`:843–876`: `lower_base` 600 × 2100 × 560, komín 50, bez chrbta, zapustenie 0 a lišty 100 výslovne, `appliance_expects ['fridge']`, dvierka F1 719 pevné + F2 auto so smerom `DIRECTION_UNSET`, `config_schema` = `CabinetBuilder::CONFIG_SCHEMA`). Dosadenie do existujúcej knižnice je markerové: `migrate!` krok `old_std < 7` (`:482–510`, história STD `:13–40`); čerstvá inštalácia zapíše všetky seedy (`:485–487`).
- **Whitelist šablóny** `Panel.template_config_from` (`payloads.rb:2303–2357`): typ, rozmery, režimy, výstuhy, strom zón, čelá, polia slotu, komín a lišty výslovne, očakávania, nastavené materiály, voliteľne kovanie a marker `config_schema`. Použitie šablóny `merge_template` (`templates_dialog.rb:531–586`): „chýbajúci kľúč = zachovaj hodnotu cieľa" pre `plinth_recess`, komín, lišty, názov, ručné kovanie, materiály; väzby na spotrebič vždy z cieľa.
- **Vkladacia karta:** 4 tlačidlá typu v jednom rade (`panel.html:190–195`), `onInsertType` (`form.js:892–899`); ponuka šablón filtrovaná typom — neznámy typ šablóny padne do „dolnej" (`insert_state.js:256–267`); predvoľby typu zo servera `DEFAULTS` (`sync.rb:40–46`). D-141 (zásobník): tlačidlo „Umývačka" sa má neskôr premenovať na „Spotrebič" (`DOGFOODING.md:55–57`).
- **Ghost:** `prepare_insert` zmrazí config + `home_z` (`cabinet_builder.rb:558–562`); obálka ghostu `[0..w] × [0..d] × [0..h]`, zelená predná stena Y = 0 (`ghost_tool.rb:580–586`, `:1106`, `:73`); pamäť zamknutej výšky per typ (`:1543–1547`); commit len cez `commit_insert` (rigidná matica, §5.3). Nič z ghostu sa nevetví podľa typu okrem `home_z`.
- **Umiestnenie:** `Placement.next_x` a nástroje merajú **nominálnu obálku** z configu (`placement.rb:16–28`, `CabinetBuilder.envelope` `:2463–2503`) — presahujúce čelo ani proxy doraz neposúvajú; dielec pred čelnou rovinou (záporné Y) by sa správal rovnako.

---

## 9 · Inspector a náhľad

- **Základné → Rozmery** (`panel.html:255–352`): šírka, výška, hĺbka, sokel (`fhRow`), 3 riadky slotu (`:280–288`, skryté), hrúbka; informačný stĺpec vrátane výstupov slotu (`:306–310`); riadok Nohy (`:323–331`) a Spotrebič (`applRows` `:334`, kreslí server). Viditeľnosť per typ má **jednu autoritu `applyVisibility(t)`** (`form.js:732–755`) so zoznamami `SLOT_ONLY_ROWS`/`SLOT_HIDDEN_ROWS`/`SLOT_HIDDEN_GAPS` (`:725–730`); kontexty railu per typ `NX_CTX_LOCK` (`shell.js:31–39`).
- **Nastavenia → Korpus** (`panel.html:438–535`): skupiny **Strop**, **Dno & podstavec**, **Chrbát**; skupina Boky zanikla (`:490`). Riadky konštrukcie sú podmienené (`twoRailsGroup`, `backSetbackRow`, `backRailRow`).
- **Trvalé pravidlo:** „VERTIKÁLNY priestor panela je vzácny" (`PLAN.md:676–678`) — nový riadok len keď sa nedá do existujúceho radu, rohu náhľadu, ikony alebo kontextu.
- **Náhľad** je 2D čelný pohľad `rx(x)`, `ry(z)` (`preview.js:747–818`): `drawCarcass` kreslí obrys, boky, dno, strop/výstuhy a podstavec cez celú šírku (`:607–632`); čelá `renderFrontsPreview` s X počítaným v JS od `gapLeft` cez celú šírku (`:876–943`, `:886`); hĺbka len náznakom skosenia a kótou (`renderCabOutline` `:998–1013`, `pvDepthSkew` `:103`). **Precedensy pre iný typ:** slot má vlastný podklad `drawSlotBase` namiesto `drawCarcass` a detail `drawSlotDetail` (`:639–688`, ui-lifecycle.md:806–811); kontrolnú geometriu chladničky počíta server a JS ju len kreslí (`params['preview']` `payloads.rb:179`, `pvApplianceRefs` `preview.js:371–374`). Dielec kolmý na čelo (CR 2, rohová výstuha) by sa v čelnom pohľade ukázal len ako 18 mm pás. D-145: bokorys v rohu náhľadu Michal zamietol, 3D náhľad je v zásobníku (`DOGFOODING.md:52–54`).

---

## 10 · Observer mierky

- `ScaleWatch.absorb` (`scale_observer.rb:475–535`): faktory lokálnych osí X/Y/Z → **šírka, hĺbka, výška**; všetko ostatné ide nezmenené cez `config_to_params` (`:493`) — absolútne hodnoty (komín, lišty, pevné čelá, zamknuté polia zón) ostávajú, auto polia sa prepočítajú. Prestavba je transparentná (1 krok Späť so Scale).
- Klampy: šírka len `MIN` 200 / `MIN_BY_TYPE` (`:490`, `:550–562`); výška config-aware cez `Construction.min_valid_height` (`:571–588`), slot vlastný `clamp_slot_height` (`:619–628`); hĺbka pri zmenšení config-aware cez `min_valid_depth` + nemodálna veta (`:592–617`). Typové minimá existujú len pre `dishwasher` (`:30–31`, guard `test_s1e_slot.rb`).
- Neplatná prestavba → `abort_safely` zruší aj Scale, `reject_scale` sa nespustí a hlášku používateľ nedostane (construction.md:426–429).

---

## 11 · Testy

- **In-SU (brána mergu pri builderoch, geometrii, undo):** runner `scripts/run_su_tests.ps1` (`-CloseWhenDone`), sada `tests/sketchup/su_runner.rb` (26 973 r.). `run_sync` (`:2612`) overuje plán ↔ model 1:1: počet, množinu `part_key`, **origin a rozmery definície každého dielca** a meno definície (`:2649–2678`). Vzory posledných blokov: `run_s1e` (`:3702`), `run_kon0` (`:5391`), `run_kona` (`:5627`, 68 kombinácií), `run_konb` (`:5847`, 48 kombinácií), `run_kond` (`:6059`); poradie behu `:26857–26880`.
- **Headless vzor nového typu:** `tests/pure/test_s1e_slot.rb` (R1–R12, E1–E12: TYPES, podpora, plán, otvor, invariant čela, referencie, schéma, dopredný guard, round-trip, šablóny, seed, Kontrola, kusovník, payload, parita JS) + `tests/js/test_s1e_slot.js`; vzor novej roly `tests/pure/test_konb_listy.rb` (guard parity poľa `:211`, ABS/tag/labely `:412`, seed merge `:463`, kusovník `:491`, VEPO `:533`) + `tests/js/test_konb_listy.js` + fixtúra `tests/fixtures/konb_cases.json`; vzor nových rolí čiel `tests/pure/test_kova1_cela.rb:456–560` (allowlisty). Golden plány `tests/pure/test_kova_golden.rb` + `tests/fixtures/kova_golden/`, `kovh_golden` — dolná/horná sa nesmú pohnúť.
- **Guardy a testy, ktoré pripínajú zoznamy alebo čísla (nový typ / rola / bump ich musí upraviť):**

| Čo | Kde |
|---|---|
| `TYPES == %w[lower upper dishwasher]` | `tests/pure/test_s1e_slot.rb:122–124` |
| JS `CAB_TYPES` a `INSERT_TYPES` = Ruby `TYPES` (+ board) | `test_s1e_slot.rb:611–622`; `tests/js/test_s1e_slot.js:53`, `:466` |
| `NX_TYPE_LABEL` | `tests/js/test_s1e_slot.js:339`, `tests/js/test_uib3_korpus.js:164` |
| whitelist typu šablóny `%w[lower upper]` | `tests/pure/test_uib3_rady.rb:158` |
| `CONFIG_SCHEMA == 21` | `test_konb_listy.rb:274`, `:282`; `test_kond_chladnickova.rb:124` |
| BuildPlan `SCHEMA == 6` | `test_konb_listy.rb:283`, `:287`; `test_kon0_d143.rb:221` |
| ABS `SEED_VERSION == 5` | `test_konb_listy.rb:289` |
| `TemplateStore::STD == 7` | `test_kond_chladnickova.rb:201–323` |
| kanál materiálu per rola (pripnutá kópia) | `test_kovw_hmotnost.rb:162–171`, `:442–464` |
| stojace roly / mapa hrán korpusu | `test_kovd5_abs_zasuvky.rb:269`, `:311`, `:341` |
| žiadny default smeru, `unset` len na allowliste | `test_kova1_cela.rb:574–632` |
| tagy podľa `PART_TAGS` | `test_d27_tagy.rb:46–48` |
| `MIN` Ruby ↔ scale ↔ JS, `MIN_BY_TYPE` ↔ `DW_*` | `test_s1e0_min_vyska.rb`, `test_s1e_slot.rb:156–192` |

---

## 12 · Existujúce stopy „rohovej" a DC súbory

- **Kód:** žiadny identifikátor rohovej skrinky (`corner`, `rohov…` v kóde = rohy kvádrov a symbolov, `appearance_mapping.rb`, `ghost_tool.rb`, `direction_check.rb`). `LeMans` len v prieskumoch (`SYSTEM/zdroje/DISK_ZAKAZKY_sonda_2026-07.md:103`, `SEED_KATALOG_2026-07.md:87`). Rola `cover_panel` a `gola_profile` sú rezervované bez implementácie (§2.3).
- **Dokumenty (mimo archívu):** `PLAN.md:271–276`, `:652–656`, `:683`; `V1_VIZIA.md:16–20`, `:41`; `STAV.md:19`, `:42`; `STANDARD.md:403` a `:1550` („rohové a atypické korpusy mimo scope v1" — rozpor s rozhodnutím 6.9.), `:1544–1545` (rohová skrinka sa nepája priamo na rohový styk); `zdroje/next_sessions/V1_DEBATA_2026-09-05_KONSTRUKCIA.md` §0 a §3; `07_KONSTRUKCIA_V1.md:119–133`. `POJMY.md` pojmy „rohová", „CR lišta", „výstuha závesov" nemá (blenda `:14`). `ARCHIWOOD_INSPIRACIA.md` o rohových nič.
- **DC „Rohová":** `C:\APP DEV\RUBY\COMPONENTS V2\1 Nové Dynamicke\Rohová.skp` (203 911 B, 5.10.2025) + `Rohová.png` (3,1 MB). V repe žiadny súbor DC; netrackované screenshoty `_dev/screens/ROHOVA dyn/` (gitignore `.gitignore:3`): `skr roh korpus.png`, `SKR roh bez dv.png`, `SKR roh-s dv.png`. Na nich: dvere vľavo, CR 1 a CR 2 v tvare „L" z čelového materiálu, strop dve výstuhy naplocho, nohy. Či je na obrázkoch vidno blendu korpusovú v slepej časti: **NEOVERENÉ** (pravá časť pôsobí otvorene).

---

## Otázky, na ktoré kód odpoveď nedáva (vstup do debaty, nie návrh)

1. **Nový `type` vs. prepínač na `lower`:** kód nepozná „variant typu"; typ riadi predvoľby, podporu, auto názov, šablóny, kontexty a náhľad (§1.2). Prepínač na `lower` by musel prejsť whitelistami konštrukčných polí (vzor KON-A/KON-B, `CONSTRUCTION_FIELDS` `core.js:1757–1779`, `PARAM_KEYS`, `normalize`, `cabinet_config`, `config_to_params`, `template_config_from`, `merge_template`).
2. **Model čiel:** dverová zóna ako `front_opening` so `x0`/`w` je v jadre možná; nevie to preflight, náhľad ani draft (§3.1). Slepá časť čelá nemá — riadok `none` ide cez celý otvor.
3. **Roly rohových dielcov:** 5 dielcov nemá ekvivalent (§4); tri sú z korpusu (výstuha závesov, blenda korpusová, rohová výstuha), dva z čelového materiálu (CR 1 v rovine čiel, CR 2 kolmo). Pasca hrúbky a `materialized_part` (§2.7).
4. **Zrkadlenie:** v pláne (prepočet X) vs. transformácia (dnes odmietaná na 4 miestach, §5.3). Strana pántov dverí vs. L/P a guard „žiadny default smeru" (§3.4).
5. **Závesy „na výstuhe závesov":** kovanie miesto montáže nepozná (§6) — rozhodnúť, či je to len geometria, alebo údaj.
6. **Kolízie:** polica cez celú šírku vs. výstuha závesov hĺbky 80 (§4) — engine to nezistí.
7. **Min. šírka a scale:** absorpcia šírky nie je config-aware (§10).
8. **Bumpy a brány:** `CONFIG_SCHEMA` 21 → 22 (nový typ/polia), BuildPlan 6 → 7 pri nových rolách (precedens 4 a 6), ABS `SEED_VERSION` 5 → 6 pri nových rolách s olepom; prípadná šablóna = `STD` 8. Aktualizovať obe PC (STAV.md:24–27).
