# PACKAGE H12 · Typy skriniek na jednom mieste + mená rolí (C-01, C-05) — blok 9 HARDENING PO V1

> **Autorita:** triedenie Michala 1.10.2026 (`ROZHODNUTIA_MICHALA_2026-10-01.md`: C-01 = CX-01 · GR-01 · CN-02, C-05 = GR-04 — obe **Teraz**);
> blok 9 (`SYSTEM/PLAN.md`): **bez zmeny výrobných a cenových čísel** (charakterizačné golden testy PRED zásahom). Dôkazy: `CROSS_AUDIT_A1_CODEX_ASTRA.md` CX-01,
> `CROSS_AUDIT_A2_GROK.md` GR-01/GR-04, `CROSS_AUDIT_A4_CLAUDE_NOVY_AGENT.md` CN-02/CN-03, `SYSTEM/archiv/bloky/ROHOVA/FAKTY_Z_KODU_2026-09-27.md` §1.2, §2.6
> (k v0.14.0 — čísla riadkov nižšie sú **prepočítané na dnešný main**).
> **Trieda (§5):** **výrobná/cenová ÁNO** (H12a–H12c) · **audit-povinná ÁNO** (nový modul `core/cabinet_types.rb` + kontrakt registra a payloadu) ·
> **in-SU brána** H12a a H12b · **predrecenzia povinná** H12a–H12c · `codex-po-pr` bez výnimky. **Nový typ sa NEPRIDÁVA.**
> **Verzia:** každá časť = patch podľa mainu pri štarte (dnes `0.17.9`; H11 ho zvýši skôr) + všetky `?v=` + prepis STAV.
> **Stav kódu:** sonda nad `main` **`22088b65`** (v0.17.9, po PR #444).

---

## 0 · Sonda na kóde (headless, 1.10.2026)

Skripty `scratchpad/HARDENING/sonda_h12.rb`, `sonda_h12_b.rb`, `sonda_h12_tpl.rb` (Ruby 3.2 cez `tests/helper.rb`, APPDATA = sandbox) a `sonda_h12_js.js`
(node, `vm` nad `part_card.js`) + Grep nad `noxun_engine/`. Do modelu ani do repa sa nič nezapisovalo.

| # | Tvrdenie o dnešnom kóde | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | `CabinetBuilder::TYPES` = `lower upper dishwasher corner_blind`; `normalize` neznámy/chýbajúci typ **ticho sklopí na `lower`** a výsledok je **identický** s dolnou | `cabinet_builder.rb:71`, `:4367-4370`; sonda: `normalize('tall') == normalize('lower')` → `true` | PRAVDA |
| S2 | Typ určuje podporu (`lower`/`corner_blind` → `legs`, `upper`/`dishwasher` → `none`), preset, `template_id`, auto názov, výšku vloženia (`upper` 1400), otvor čiel (rohová 450 = dverová časť), extra polia (slot 4× `dw_*`, rohová 4× `corner_*`) | sonda S2/S4 | PRAVDA |
| S3 | Plán je deterministický: dolná 6 dielcov + nohy 4, príchyt 1, pánty 2 · horná 6 + pánty 2, **závesy 2** · slot 1 (`false_front`) + 1 referencia · rohová 11 + nohy 6, príchyty 2, pánty 2 | sonda S3 (dva behy = zhodný JSON) | PRAVDA → golden realizovateľný |
| S4 | **Výstupy typ nečítajú** (`validation`, `vepo_export`, `budget`, `production_core`, `cp_export`, `studio_dialog` = 0); `bom.rb` len vlastník spotrebiča `:357` a záznam slotu `:568` | Grep | PRAVDA → VEPO/kusovník sa zmenia **len** cez buildery |
| S5 | **JS mapa mien rolí (`part_card.js:2-16`) sa od Kusovníka (`ProductionCore::ROLE_LABELS`) líši v 9 z 29 rolí:** `top` Vrch/Strop · `divider_v` Priečka zvislá/Zvislá priečka · `divider_h` Priečka vodorovná/Vodorovná priečka · `drawer_front` Zásuvkové čelo/Čelo zásuvky · `free_panel`, `drawer_bottom`, `drawer_back`, `box_side`, `drawer_inner_front` → karta ukáže **surový identifikátor** | `sonda_h12_js.js` | PRAVDA → dokument `outputs.md:524-525` („musí byť zhodná") **neplatí** |
| S6 | `ROLE_LABELS` nemá `cover_panel`, `gola_profile` (rezervované, plán ich nevydáva → fallback surová rola); iné roly mimo `BuildPlan::ROLES` nemá | sonda S14 | PRAVDA |
| S7 | Jediné seed pravidlo kovania s filtrom typu je `zavesenie-hornej-skrinky` (`applies_to.cabinet_type = ["upper"]`, `hardware_rules.rb:316`, filter `:1441-1442`); kontext nesie surové `'cabinet_type' => cfg[:type]` (`construction.rb:1458`); HW `SEED_VERSION` 7 | sonda S7 | PRAVDA → **pasca CN-03** platí |
| S8 | `apply_template_type!`: horná↔dolná prepne, slot aj rohová **zamknuté** (typ ostane), neznámy typ sa prepnúť dá | sonda S8, `actions_templates.rb:226-237` | PRAVDA |
| S9 | `TEMPLATE_TYPE_LABELS` (`HORNÁ`, `DOLNÁ`, `UMÝVAČKA`) = `upcase` z `TEMPLATE_TYPE_WORDS` (Ruby Unicode `upcase`) | sonda S9 | PRAVDA → odvoditeľné bajtovo rovnako |
| S10 | `PartKeys::ZONE_PART_LABELS` = `ROLE_LABELS` (3 roly); `DRAWER_PART_LABELS` = `ROLE_LABELS` s malým prvým písmenom (3 roly) | sonda S12 | PRAVDA → odvoditeľné |
| S11 | `Recipes.role_label` (`drawer_recipes.rb:1154`) je **iný gramatický tvar** (akuzatív/krátky: „policu", „dno") pre vety hlášok | sonda S12 | PRAVDA → mimo C-05 |
| S12 | Seed šablón 10 (dolná 4, horná 1, slot 2, doska 3; rohová žiadna). Schémy: `CONFIG_SCHEMA` 22, BuildPlan `SCHEMA` 7, `TemplateStore::STD` 7, ABS seed 6, HW seed 7 — H12 nemení žiadnu | `sonda_h12_tpl.rb` | PRAVDA |
| S14 | Identifikátor rohovej je definovaný **dvakrát** (`CabinetBuilder::CORNER_TYPE` `:61`, `Construction::CORNER_TYPE` `:581`), lebo `construction.rb` sa načíta pred builderom | `main.rb:493`, `:496` | PRAVDA |
| S15 | `NX.init` nastaví `DEFAULTS` **pred** spracovaním označenia (`loadSelected`/`clearSelected`) → register v tom istom payloade príde včas | `bridge.js:292-332` | PRAVDA (či niečo volá `setType` **pred** `NX.init` — NEOVERENÉ, test v §7) |
| S16 | `ScaleWatch` ide headless so stubom observerov (`test_kona_komin.rb:36-47`); `Bom.collect` len nad fake modelom (`test_h8_std_citanie.rb:75-203`), záznamy dielcov však vznikajú v builderi → **bajty VEPO/kusovníka/rozpočtu zo 4 typov len in-SU** | čítanie kódu | PRAVDA |
| S17 | Goldeny dnes: `kova_golden` (dolná + 1 horná, len plán), `np1` VEPO z ručných riadkov → **slot ani rohová golden nemajú** | `tests/fixtures/*` | PRAVDA → T0 je nová práca |
| S18 | 10 testov pripína zoznamy typov **textom zdroja** (§7 T4); `cabinet_config` je čistá, ale nesie `engine_version` (mení sa bumpom) | Grep, sonda S4 | PRAVDA → golden ho vynechá |

### 0.1 Súpis — kde sa Ruby vetví podľa typu (≈ 75 rozhodovacích miest v 17 súboroch)

Stĺpec **Pýta sa na** = skutočná vlastnosť; **Neznámy typ** = čo dnes miesto spraví s typom mimo registra (`L` = správa sa ako dolná, `ID` = porovnáva/ukladá surový reťazec).

| Súbor:riadok | Čo tam je | Pýta sa na | Neznámy |
|---|---|---|---|
| `core/cabinet_builder.rb:13-67` | `LOWER/UPPER/DISHWASHER/CORNER_DEFAULTS` | predvoľby typu | — |
| `:61` · `construction.rb:581` | `CORNER_TYPE` (2×) | identita rohovej | — |
| `:71` | `TYPES` | členstvo | — |
| `:131`, `:140`, `:3119-3124` | `AUTO_NAME_RE`, `CORNER_AUTO_NAME_RE`, `auto_name?` | auto názov viazaný na typ (rohová) | L |
| `:146`, `:627` | `UPPER_HANG_Z`, `prepare_insert` `home_z` | **visí** (výška vloženia) | L |
| `:1135`, `:2961`, `:3153-3159` | `template_id_for` | id šablóny | L |
| `:1665` | `corner_thicknesses` | rohová zostava | L |
| `:2997`, `:3069-3075` | `construction_preset_for` | preset | L |
| `:3041` / `:3044` | `DW_KEYS` len slot / `CORNER_KEYS` len rohová v `cabinet_config` | extra polia typu | L |
| `:3049` | komín/zapustenie/lišty chrbta mimo slotu | **má korpus** | L |
| `:3133-3144` | `default_name` | auto názov | L |
| `:3195-3201` | `defaults_for` | predvoľby | L |
| `:3206-3221` | `norm_type`, `slot`, `corner` v `normalize` | slot: vlastné rozsahy, polia, invariant čiel; rohová: polia, invariant čiel | L |
| `:3224-3226` | šírka/výška slotu `DW_WIDTH_RANGE`/`DW_HEIGHT_RANGE` | **vlastné limity** | L |
| `:3233`, `:3240` | `floor_height` 0 a `plinth_mode none` pri `upper \|\| slot` | **nestojí na podlahe** | L |
| `:3248-3252` | komín, zapustenie, lišty pri slote 0/predvoľba | má korpus | L |
| `:4228` | `config_to_params` `type \|\| 'lower'` | predvolený typ | ID→L v `normalize` |
| `:4350` | `legacy_plinth` (V0.1 horná bez sokla) | visí | L |
| `core/construction.rb:120-121` | `build_plan` → `appliance_slot_plan` | **builder** (korpus vs slot) | L |
| `:147`, `:559`, `:678`, `:725`, `:742`, `:1771` (`corner?` `:614-616`) | odsadenie políc, otvor, zostava, varovanie, odmietnutie, min. šírka | rohová zostava | L |
| `:550` | `front_opening` slotu | otvor čiel | L |
| `:1426` | `support_type` `upper \|\| dishwasher` → `none` | nestojí na podlahe | L |
| `:1458` | `cabinet_hw_ctx['cabinet_type']` | vstup pravidiel (CN-03) | ID |
| `:1514`, `:1590`, `:1675`, `:1730` | `setback_value`, `back_rails?`, `min_valid_height`, `min_valid_depth` | má korpus / slot | L |
| `core/scale_observer.rb:30-31`, `:489`, `:574` | `MIN_BY_TYPE`, `min_for` | vlastné limity | L |
| `:503` | `clamp_corner_width` | rohová | L |
| `:590`, `:608`, `:657` | výška/hĺbka slotu | slot | L |
| `core/appliance_binding.rb:447`, `:452-455`, `:560`, `:836` | druh vlastníka `slot`/`cabinet` | **vlastník spotrebiča** | L |
| `core/appliance_checks.rb:78` | kontext niky `{}` pri slote | má korpus (vnútro) | L |
| `core/bom.rb:357`, `:568` | vlastník spotrebiča, záznam slotu | vlastník spotrebiča | L |
| `core/direction_check.rb:178` | blenda v slote = symbol sklop | pravidlo čiel slotu | L |
| `core/templates.rb:178`, `:202` | implicitné očakávanie umývačky, súhrn konštrukcie | vlastník spotrebiča / má korpus | L |
| `core/hardware_rules.rb:316`, `:1441-1442` | seed `cabinet_type ['upper']` + filter | visí (CN-03) | ID |
| `core/ghost_tool.rb:1252-1253` (použitie `:186`, `:268`, `:521-522`, `:2827`) | `corner?` vkladania | rohová (prepínač strany D) | L |
| `:1606-1609` | kľúč pamäte zamknutej výšky `@type_key` | identita | ID |
| `ui/panel/actions_cabinet.rb:20-24` | `PARAM_KEYS` (vrátane `dw_*`, `corner_*`) | whitelist (nie vetva) | — |
| `:29-30` | `TEMPLATE_TYPE_WORDS` | slovo typu | — |
| `:61`, `:227` | preflight čiel slotu (rozsah, otvor) | slot | L |
| `:128-131`, `:144`, `:176`, `:284` | preflight rohovej | rohová | L |
| `:485-486` (`:492`, `:564`) | `slot_params?` — bez preflightu tela/chrbta a hrúbky | má korpus | L |
| `:716`, `:738` | ghost rohovej | rohová | L |
| `:763`, `:775` | `apply_template_slot_fields!` (typ a polia zo šablóny) | extra polia | L |
| `:806`, `:1103`, `:1171` | šablóna/čelá/strana rohovej | rohová | L |
| `:1085` | `slot_fronts_refusal` | pravidlo čiel | L |
| `:1120-1125` | `corner_change_refusal` — typ rohovej sa nemení | **typ zamknutý** | ID (want≠have) |
| `ui/panel/actions_templates.rb:220-237` | `TEMPLATE_TYPE_LABELS`, whitelist `%w[lower upper]`, zámok slotu a rohovej | prepínateľný typ šablóny | ID |
| `:254` | druh vlastníka očakávaní | vlastník spotrebiča | L |
| `ui/panel/actions_appliance.rb:94`, `:229`, `:331` | slot ako vlastník | vlastník spotrebiča | L |
| `ui/panel/actions_zones.rb:49` | rohová nedelí zóny | zóny | L |
| `ui/panel/payloads.rb:92`, `:98`, `:970` | `corner_th2`, `corner_preview` | rohová | L |
| `:186`, `:699` | riadky spotrebiča, `slot_payload` | vlastník spotrebiča / slot | L |
| `:2477`, `:2484` | `template_config_from` polia rohovej / komín mimo slotu | extra polia / má korpus | L |
| `ui/panel/sync.rb:40-49` | `defaults:` per typ do JS | predvoľby (zrkadlo) | — |
| `ui/templates_dialog.rb:419-424` | šablóna len na rovnaký typ (+ veta so slovom typu) | identita + slovo | **ID** |
| `:541-542` | šablóna rohovej na rohovú | rohová | L |

### 0.2 Súpis — JS a HTML (≈ 70 miest v 10 súboroch + 2 bloky HTML; 8 vlastných zoznamov typu)

| Súbor:riadok | Čo tam je | Pýta sa na |
|---|---|---|
| `ui/js/core.js:2` | `DEFAULTS = { lower:{}, upper:{} }` pred `NX.init` | bootstrap (nie vetva) |
| `:960` | `frontTypeSymbol` blenda v slote = `down` | pravidlo čiel slotu |
| `:1196`, `:1204` | **`NX_TYPE_LABEL`** + fallback „Dolná" | názov typu |
| `:1598-1608` | **`CAB_TYPES`**, `setType` (neznámy → `lower`) | členstvo |
| `:1639`, `:1673` | `nxSetbackOf`, `nxBackRails` mimo slotu | má korpus |
| `:1812` | `currentCarcass` sokel 0 **len pri `upper`** | visí |
| `:1862-1864` | `CONSTRUCTION_FIELDS` `only:'corner_blind'` | rohová |
| `ui/js/form.js:186`, `:211` | **`TYPE_LIMITS`** (slot 300–1200 / 500–1200), `limitFor` | vlastné limity |
| `:195`, `:385-391` | `CORNER_FIELDS`/`SLOT_FIELDS` validácia len pri svojom type | rohová / slot |
| `:205`, `:292`, `:1130`, `:1138`, `:1145`, `:1170` | lišty, komín, zapustenie, nota chrbta mimo slotu | má korpus |
| `:209` | `cabTypeNow` fallback `lower` | bootstrap |
| `:245`, `:273` | výška slotu = výška linky | slot |
| `:248`, `:302` | sokel 0 **len pri `upper`** (slot sa vráti skôr) | visí |
| `:467-494`, `:559`, `:641`, `:713`, `:723`, `:2929` | strana, hrúbka CR 2, info rohovej | rohová |
| `:626` | `nxFrontDraftData` sokel 0 pri `upper \|\| dishwasher` | nestojí na podlahe |
| `:633` | sokel čela slotu | slot |
| `:980` | odhad dielcov slotu „≈ 1" | builder |
| `:1014-1054` | `applyVisibility`: `SLOT_ONLY/HIDDEN_*`, `plinthGroup`/`fhRow` (`upper \|\| slot`), riadok rohovej, „Delenie zóny" skryté pri rohovej, `nxLegsApplyVisibility(slot ? 'upper' : t)` | slot / nestojí / rohová / zóny |
| `:1545` | `findTemplateFor` typ šablóny | identita (cez `templateType`) |
| `:1648` | `SLOT_NO_LOCK` | builder |
| `:1792-1797` | **`TPL_TYPE_LOCK`** (texty zámku slotu a rohovej) | prepínateľný typ šablóny |
| `:1830`, `:1847` | očakávania pri ukladaní šablóny slotu | vlastník spotrebiča |
| `:2032`, `:2431`, `:2966-2990` | dvere slotu, karta čiel slotu/rohovej, zámok mazania | pravidlo čiel |
| `ui/js/hardware.js:2376` | náhľad nôh: `upper \|\| dishwasher` skryje | nestojí na podlahe |
| `:2468-2469` | **`LEGS_INSERT_TYPES`** = `lower`, `corner_blind` | stojí na podlahe |
| `:2475` | `nxLegsApplyVisibility`: `upper` → zahoď dotaz a skry | nestojí (slot sem chodí ako `'upper'`) |
| `ui/js/insert_state.js:40`, `:46`, `:84` | **`INSERT_TYPES`** (+ `board`), stav, fallback | členstvo |
| `:260-270` | `templateType`/`templatesForType` (neznámy → „dolná") | členstvo |
| `ui/js/preview.js:96`, `:106` | `nxFrontOpeningFor` (otvor len pri rohovej) | otvor čiel |
| `:385`, `:425` | detail slotu, kresba rohovej zostavy | slot / rohová |
| `:492` | `nxCabFloorHeight` `upper \|\| dishwasher` | nestojí na podlahe |
| `ui/js/shell.js:27`, `:97` | `cabType` stav + fallback | bootstrap |
| `:31-40` | **`NX_CTX_LOCK`** (slot nemá Zóny, veta) | zóny |
| `:586` | meta rohovej | rohová |
| `ui/js/templates.js:70-71`, `:232` (Štúdio) | **`TPL_TYPE_WORDS`** + fallback „dolná" | slovo typu |
| `ui/js/rules.js:295-296` (Štúdio) | „na hornú/spodnú skrinku" z `cabinet_type` pravidla | slovo typu |
| `ui/js/bridge.js:330`, `:332`, `:674` | reset na `lower`, `c.type \|\| 'lower'` | bootstrap |
| `ui/js/actions.js:407`, `:449` | strana rohovej vo vklade, kláves D | rohová |
| `ui/panel.html:196-199` | 4 tlačidlá typu (Dolná · Horná · Rohová · Umývačka) | názov + poradie UI |
| `:929-933` | `<select id="tplSaveType">` (Dolná · Horná · Rohová · Umývačka) | názov + poradie UI |

### 0.3 Súpis — mená rolí dielcov

**Zobrazovacie (s diakritikou):**

| Kde | Čo | Konzumenti |
|---|---|---|
| `ui/production_core.rb:1880-1906` `ROLE_LABELS` (27 rolí) + `role_label` `:1908` | **autorita** | Kusovník stĺpec Rola (`rows_with_roles` `:1929`), `studio_dialog.rb:877`, prehľad ABS (`rules_dialog.rb:241-243`) |
| `ui/js/part_card.js:2-16` `roleLabel` | **JS kópia, 9 rozdielov (S5)** | hlavička karty dielca `:33-34`, `:596`, `bridge.js:38` (výber dielca) |
| `ui/panel/payloads.rb:11` `BOARD_ROLE_LABELS` | kópia `free_panel` | `board_payload` → `board_card.js:235`, `:242` |
| `core/part_keys.rb:121-130` `ZONE_PART_LABELS`, `DRAWER_PART_LABELS` | odvodené (S10) | `human_label` (Kovanie, Kontrola) |
| `core/drawer_recipes.rb:1154-1158` `Recipes.role_label` | iný pád (S11) | vety hlášok zásuviek, `actions_hardware.rb:783`, `actions_parts.rb:126`, `payloads.rb:2116` |
| `ui/js/rules.js:289-326` `rdRoleDesc` | vety rozsahu pravidla („na každú policu") | Štúdio → Pravidlá kovania |
| `ui/panel/payloads.rb:1013-1020` `corner_preview_title` | popisy kresby rohovej | Inspector |

**Výrobné (ASCII, idú do kusovníka a VEPO — H12 ich NEMENÍ):** `construction.rb:1856-2078` (Bok lavy, Bok pravy, Dno, Vrch, Vystuha predna/zadna, Chrbat,
Sokel predny), `BACK_RAIL_NAME` `:1584`, `CORNER_NAMES` `:605-608`, `DW_FRONT_NAME` `:286`, zásuvky `:1201-1224`; `zone_tree.rb:527`, `:537`, `:566`; `modules/fronts.rb:374-411`;
mapy `VepoExport::SHORT_NAMES`/`DOOR_*`/`DRAWER*`/`NAME_PAIRS` (`vepo_export.rb:72-110`, kľúče = presné reťazce builderov).
**Vlastnosti rolí** (nie mená — zoznamy §2.6 FAKTY, dnešné miesta): `BuildPlan::ROLES` `build_plan.rb:118`, `AbsRules::EDGE_LABELS` `:71`/`SEED_RULES` `:154`/`SEED_VERSION` `:61`,
`PartFaces::ROLE_AXES` `:152`/`STANDING_ROLES` `:85`, `CabinetBuilder::PART_TAGS` `:480`/`DRAWER_ROLES` `:444`, `Construction::FRONT_MATERIAL_ROLES` `:76`, `Validation::FRONT_ROLES` `:52`,
`HardwareRules::FRONT_ROLES` `:1914`, `CpExport::FRONT_ROLES` `:96`, `RulesDialog::ABS_ROLE_ORDER` `:44`, `part_card.js` `isFront` `:56`, `MANUAL_OWNER_PREFIXES` `payloads.rb:823`,
`CORNER_PREVIEW_ROLES` `payloads.rb:966` → **mimo H12, odovzdať H13 (§14)**.

### 0.4 Tabuľka vlastností typu — odvodená zo súpisu (návrh registra)

| Kľúč | Význam | `lower` | `upper` | `dishwasher` | `corner_blind` | Nahrádza (počet miest) |
|---|---|---|---|---|---|---|
| `id` | identifikátor v configu | lower | upper | dishwasher | corner_blind | `TYPES`, 2× `CORNER_TYPE`, `CAB_TYPES`, `INSERT_TYPES` (5) |
| `label` | názov (hlavička, tlačidlo, select) | Dolná | Horná | Umývačka | Rohová | `NX_TYPE_LABEL` + HTML guard (3) |
| `word` | slovo do viet (malé) | dolná | horná | umývačka | rohová | `TEMPLATE_TYPE_WORDS`, `TPL_TYPE_WORDS`, `TEMPLATE_TYPE_LABELS` (= `upcase`) (4) |
| `auto_name` | vzor auto názvu | `Spodná skrinka %{w}` | `Horná skrinka %{w}` | `Umývačka %{dw} (slot)` | `Rohová skrinka %{w}` | `default_name` (1) |
| `auto_name_typed` | auto názov platí len pri tomto type | false | false | false | true | `auto_name?` (1) |
| `preset` | `construction_preset` | noxun-lower-18 | noxun-upper-18 | noxun-dishwasher | noxun-corner-blind | (1) |
| `template_id` | `template_id` | base-lower-18 | base-upper-18 | dishwasher-slot-18 | corner-blind-18 | (1) |
| `builder` | topológia | `carcass` | `carcass` | `appliance_slot` | `carcass` | build_plan, komín/zapustenie/lišty, vnútro, preflighty tela/chrbta, ≈ 20 JS (≈ 35) |
| `hang_z` | výška vloženia mm (`> 0` = **visí**) | 0.0 | 1400.0 | 0.0 | 0.0 | `home_z`, `legacy_plinth`, JS sokel „len horná", CN-03 guard (6) |
| `on_floor` | stojí na podlahe (podpora nohy/sokel podľa configu) | true | false | false | true | floor/plinth v `normalize`, `support_type`, náhľad nôh, `LEGS_INSERT_TYPES`, riadky Sokel/Nohy (10) |
| `limits` | vlastné rozsahy šírky/výšky (inak korpusové) | — | — | `w [300,1200]`, `h [500,1200]` | — | `DW_*_RANGE` v `normalize`, `MIN_BY_TYPE`, preflight, `TYPE_LIMITS` (5) |
| `appliance_owner` | druh vlastníka spotrebiča | cabinet | cabinet | slot | cabinet | binding, bom, panel, šablóny (12) |
| `fronts` | pravidlo čiel | `free` | `free` | `slot_fixed` | `corner_one_door` | `slot_fronts!`/`corner_fronts!`, odmietnutia, symbol blendy, karta čiel (10) |
| `front_opening` | otvor čiel | `full` | `full` | `slot` | `corner_door` | `front_opening`, `nxFrontOpeningFor` (3) |
| `zones` (+ `zones_reason`) | vnútro | `tree` | `tree` | `none` („slot umývačky zóny nemá") | `shelves_only` | `NX_CTX_LOCK`, `split_refusal`, „Delenie zóny" (3) |
| `template_type` (+ `template_lock` {title, tip}) | prepnutie typu šablóny | switchable | switchable | locked | locked | `apply_template_type!`, `TPL_TYPE_LOCK` (3) |
| `type_locked` | typ sa nemení žiadnou cestou | false | false | false | true | `corner_change_refusal` (1) |
| `assembly` | prídavná zostava | — | — | — | `corner_blind` | `corner?` Ruby + ≈ 15 JS (≈ 30) |
| `ui_order` | poradie v HTML (len guard) | 1 | 2 | 4 | 3 | HTML guard |

**Prečo dve „podlahové" vlastnosti:** dnešný kód má dve rôzne množiny — „len `upper`" (`home_z`, `legacy_plinth`, `core.js:1812`, `form.js:248/302`) a „`upper`
alebo `dishwasher`" (`normalize`, `support_type`, `form.js:626`, náhľad nôh). Jedna vlastnosť by v okrajovom prípade zmenila správanie (napr. `currentCarcass` pri slote) —
`hang_z > 0` reprodukuje prvú, `!on_floor` druhú **presne**.
**Prečo neznámy typ = profil dolnej:** dolná je „neutrálny" profil — všetky predikáty sú pri nej false/predvolené. Každé miesto typu **L** dá s `norm(t)` rovnaký výsledok
ako dnes; miesta **ID** (porovnanie dvoch typov, kľúč pamäte, vstup pravidiel) si ponechajú surový reťazec (R2.4).

---

## 1 · Cieľ

Typ skrinky a jeho vlastnosti („visí", „stojí na podlahe", „má korpus", „je vlastník spotrebiča", „má rohovú zostavu", „typ šablóny sa nedá prepnúť", limity, názvy)
sa čítajú z **jedného registra v Ruby**; Inspector, vkladanie, šablóny aj Štúdio ich dostanú **zo servera**. Ďalší typ (horná rohová, vysoká potravinová — po V1) bude
= **riadok registra + vlastný kód buildera**, nie 10 zoznamov v 6 súboroch; zabudnuté miesto **zhodí test**, nie sklopí typ na dolnú. Mená rolí na zobrazenie budú
**v jednej tabuľke** (karta dielca prestane ukazovať surové `drawer_bottom`). **Pre dnešné štyri typy sa nič nemení:** rovnaký plán, config, VEPO bajtovo, kusovník,
rozpočet, nákup, Inspector a vkladanie.

## 2 · Rez a odhad — **štyri časti, každá ~1 deň (H12d ~½), sekvenčne z čerstvého `main`**

| Časť | Obsah | Kód pluginu | Testy | In-SU | Odhad |
|---|---|---|---|---|---|
| **H12a · register + jadro** | T0 golden PRED zásahom (1. commit) → `core/cabinet_types.rb` → vetvy v `core/` (cabinet_builder, construction, scale_observer, appliance_binding, appliance_checks, bom, direction_check, templates, ghost_tool) + CN-03 guard | ~250–320 | ~500 | **brána** | 1 deň |
| **H12b · panel Ruby + payload** | vetvy v `ui/panel/*` a `templates_dialog.rb` + **aditívne** kľúče payloadu (`cabinet_types` v `NX.init`, `type_word` v zázname šablóny, veta rozsahu pravidla) — JS ich ešte nečíta | ~150–200 | ~250 | **brána** (akcie panela zapisujú do modelu) | ¾ dňa |
| **H12c · JS z dát servera** | `NXTypes` v `core.js`, zrušenie 8 JS zoznamov, ≈ 60 predikátov, Štúdio (`templates.js`, `rules.js`), guard HTML; prepis 10 testov zo zdroja na paritu s fixtúrou | ~250–350 | ~400 | nie (žiadny Ruby) | 1 deň |
| **H12d · mená rolí** | `PartKeys::ROLE_LABELS` + `role_label`, delegácie, `role_label` v payloade karty dielca, zrušenie JS mapy a `BOARD_ROLE_LABELS` | ~80–120 | ~150 | nie | ½ dňa |

Každá časť **sama osebe** dá bajtovo rovnaké výstupy (golden T0 platí po každej). Ak H12c presiahne ~400 riadkov kódu, rozdeliť na **H12c1** (zoznamy a texty) a
**H12c2** (predikáty). H12d je nezávislá (môže ísť skôr, ak by H12a čakala). **Audit návrhu jeden pre celý package** (pred H12a); časť, ktorá zmení kontrakt z §6, ide na deltu.

## 3 · Scope IN

1. **Register** `noxun_engine/core/cabinet_types.rb` (`Noxun::Engine::CabinetTypes`) — §0.4, R1; načítanie v `main.rb` za `build_plan` (pred `hardware_rules`, `:483`)
   a v `tests/helper.rb` za `core/build_plan`.
2. **Napojenie všetkých miest §0.1** (H12a jadro, H12b panel) a **§0.2** (H12c) na register; aliasy `CabinetBuilder::TYPES`, `CabinetBuilder::CORNER_TYPE`,
   `Construction::CORNER_TYPE` = register (testy a cudzí kód ďalej fungujú).
3. `CabinetBuilder::DEFAULTS_BY_TYPE` a `EXTRA_KEYS_BY_TYPE` (jedna mapa namiesto `case`/`if`) + paritný guard s registrom.
4. **CN-03:** guard „typy s `hang_z > 0` = `cabinet_type` seed pravidla závesov" + odsek v `hardware.md`.
5. **Mená rolí** (H12d): jedna tabuľka zobrazovacích mien, odvodené tabuľky, payload karty dielca.
6. Charakterizačné golden (T0), paritné guardy, mutácie, in-SU scenár `run_h12`.
7. Dokumentácia §11 (STANDARD §4.2, `construction.md`, `ARCHITEKTURA.md`, `ui-lifecycle.md`, `outputs.md`, `hardware.md`, `model-a-identita.md`).

## 4 · Scope OUT

- **Nový typ sa nepridáva**; žiadna zmena geometrie, plánu, configu, `CONFIG_SCHEMA`, BuildPlan `SCHEMA`, `TemplateStore::STD`, ABS ani HW `SEED_VERSION`.
- **Výrobné mená dielcov a VEPO skratky** (§0.3) sa nemenia ani nepresúvajú; kusovník a VEPO bajtovo rovnaké.
- Predvoľby (`*_DEFAULTS`), polia `DW_KEYS`/`CORNER_KEYS`, `PARAM_KEYS` a **vlastný kód typov** (`appliance_slot_plan`, `corner_parts`, `slot_fronts!`, `corner_fronts!`,
  `norm_dishwasher`, `norm_corner`, `dw_front_eval`) ostávajú v builderi — register hovorí **ktorá** vetva, nie **ako**.
- Pravidlá kovania filtrované vlastnosťou (`hangs`) namiesto `cabinet_type` — zmena schémy pravidiel (§14 F6). Používateľské pravidlá a snapshoty projektov sa nemenia.
- Generovanie tlačidiel typu a `<select>` v HTML (ostáva statické + guard; 6. typ potrebuje dizajnové rozhodnutie — UI_DIZAJN §5.4).
- `Recipes.role_label`, `rdRoleDesc`, `corner_preview_title`, `EDGE_LABELS` (iné tvary/účel) a všetky **vlastnosti rolí** (§0.3) → H13 mapa.
- Logovanie neznámeho typu (dnes ticho; zmena by bola mimo „bez zmeny správania").

## 5 · Trieda podľa CLAUDE.md

- **Výrobná/cenová: ÁNO (H12a, H12b, H12c).** Nahrádzajú sa vetvy, ktoré rozhodujú o počte a rozmeroch dielcov, nohách, závesoch, sokli a čelách (builder, normalize,
  insert/apply payload z JS). Dôkaz nezmenených čísel = T0 golden + in-SU `run_h12`. **H12d nie** (len texty karty dielca, Kusovník a VEPO bez zmeny).
- **Audit-povinná: ÁNO** — nový modul + nový kontrakt (register a jeho payload pre JS). Jeden audit package pred H12a.
- **In-SU brána: H12a** (buildery, normalize, insert, geometria) a **H12b** (akcie panela apply/insert/šablóna/strana rohovej zapisujú do modelu). H12c a H12d nie
  (odporúčané fotky okien nástrojom H2).
- **Predrecenzia: povinná H12a, H12b, H12c** (výrobná + audit); H12d len ak > 300 riadkov kódu.

### 5.1 Závislosti — overiť proti mainu pred každou časťou

- **H11** (SketchUp 2026.2, minimum 2026) môže meniť `main.rb`/loader — poradie `Sketchup.require` (R1.6) zladiť.
- **H6** (priestor v Inspectore, mockup) a **H7** zasahujú `form.js`, `panel.html`, `production_core.rb` — pri štarte H12c/H12d prepočítať čísla riadkov §0.2/§0.3;
  ak H6 mení `applyVisibility`, predikáty prevziať z jeho verzie.
- **H13** štartuje až po H12 (mapa rozširovacích bodov stavia na registri — §14).

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit H12a; každá ďalšia časť doplní svoje)

- **R0.1** Generátor `tests/fixtures/h12_golden/generate.rb` (spúšťa sa ručne, vzor `kova_golden/generate.rb`) zapíše odtlačky z **nezmeneného** mainu; fixtúry
  a test idú v **prvom commite** spolu, bez zmeny pluginu (dôkaz: test je zelený na starom kóde).
- **R0.2 Prípady (min. 14):** dolná predvolená + 1 dvierka · dolná `plinth_mode front` · dolná `floor_height 0` (podpora `none` z configu) · dolná 800 so zásuvkou ·
  horná + dvierka · horná dvojkrídla · slot 60 · slot 45 · rohová vľavo predvolená · rohová vpravo (`corner_door_w 500`, `cr1 100`) · rohová s policami ·
  **neznámy typ `tall`** · **chýbajúci typ** · `config_to_params` zo starého configu bez `plinth_mode` pre `upper`.
- **R0.3 Headless odtlačok** každej funkcie zo súpisu §0.1, ktorá sa dá volať bez SketchUpu — minimálne: `normalize`, `build_plan` (celý), `cabinet_config(merge_final)`
  **bez `engine_version`**, `support_type`, `cabinet_hw_ctx`, `front_opening`, `min_valid_*`, `default_name`, `template_id_for`, `construction_preset_for`,
  `prepare_insert(nil, …).home_z`, `ScaleWatch` klampy (stub S16), `ApplianceChecks.context`, `Bom.appliance_slot_record`/`note_appliance_owner`, `DirectionCheck.type_symbol`,
  `TemplateStore` súhrny, `Panel.template_config_from`, matice `apply_template_type!`, `corner_change_refusal` a typového guardu `TemplatesDialog` (vrátane neznámeho).
- **R0.4 JS (pred H12c):** odtlačok dnešných JS funkcií §0.2 pre 4 typy + neznámy (`setType`, `nxCabInfo`, `applyVisibility` nad fake DOM, `nxFrontDraftData`,
  `currentCarcass`, `limitFor`, `validateFields`, `templatesForType`, `tplTypeLabel`, `frontTypeSymbol`, `ctxLockedBy`, náhľad nôh, `nxSyncTplSaveType`, `nxFrontOpeningFor`, `rdRoleDesc`).
- **R0.5 In-SU (pred H12a, §8):** `run_h12` v **capture móde na nezmenenom kóde** zapíše `tests/fixtures/h12_golden/insu.json`; v ďalších behoch porovnáva.
- **R0.6 Mená rolí (pred H12d):** `ProductionCore.role_label` pre všetky `BuildPlan::ROLES` + neznámu, `rows_with_roles` nad fixtúrou, `RulesDialog.abs_role_label`,
  `PartKeys.human_label` (vzorky kľúčov), `board_payload['role_label']`, JS `roleLabel` (dnešné, vrátane 9 rozdielov — dokumentačne).

### R1 · Register `CabinetTypes` (H12a)

- **R1.1** `REGISTRY` = zmrazený `Hash` `id => props` v poradí **`lower upper dishwasher corner_blind`** (= dnešné `TYPES`); kľúče a hodnoty presne §0.4
  (`hang_z` 1400.0 = dnešné `UPPER_HANG_Z`; `limits` slotu = dnešné `DW_WIDTH_RANGE`/`DW_HEIGHT_RANGE`; texty `template_lock` a `zones_reason` doslovne z `form.js:1792-1797`
  a `shell.js:32`). `IDS = REGISTRY.keys.freeze`, `FALLBACK = 'lower'`.
- **R1.2 API (čisté, bez IO a SketchUpu):** `known?(t)` · `norm(t)` (známy → sám, inak `FALLBACK`; prijme String/Symbol/nil) · `id_or_default(t)` (nil/prázdny → `FALLBACK`,
  neznámy **ostáva**) · `get(t)` (= `REGISTRY[norm(t)]`) · `prop(t, key)` · `hangs?(t)` (`hang_z > 0`) · `on_floor?(t)` · `carcass?(t)` · `corner?(t)` (`assembly`) ·
  `ids_where(key, value)` · `client_payload` (pole hashov s kľúčmi pre JS, poradie = `IDS`; bez Ruby symbolov a lambd).
- **R1.3 Invarianty (testy T1):** každý typ má všetky kľúče; `id` = kľúč; `FALLBACK` je známy a má **neutrálny profil** (`hang_z 0`, `on_floor true`, `builder carcass`,
  `fronts free`, `zones tree`, `template_type switchable`, `type_locked false`, bez `assembly`, bez `limits`, `appliance_owner cabinet`).
- **R1.4** Aliasy: `CabinetBuilder::TYPES = CabinetTypes::IDS`, `CabinetBuilder::CORNER_TYPE` a `Construction::CORNER_TYPE` = `'corner_blind'` z registra
  (`CabinetTypes.ids_where(:assembly, 'corner_blind').first` alebo konštanta registra `CORNER`), `UPPER_HANG_Z` = `get('upper')[:hang_z]` (testy ho čítajú).
- **R1.5** Predvoľby a polia ostávajú v builderi: `DEFAULTS_BY_TYPE = { 'lower' => LOWER_DEFAULTS, … }` (poradie `IDS`), `defaults_for(t) = DEFAULTS_BY_TYPE[CabinetTypes.norm(t)]`;
  `EXTRA_KEYS_BY_TYPE = { 'dishwasher' => DW_KEYS, 'corner_blind' => CORNER_KEYS }`. Guard: kľúče = `IDS` (resp. podmnožina) — nový typ bez predvolieb zlyhá v teste.
- **R1.6** `main.rb`: `Sketchup.require 'noxun_engine/core/cabinet_types'` hneď za `build_plan` (`:454`); `tests/helper.rb` rovnako. Guard: poradie v `main.rb` (register pred
  `construction`, `hardware_rules`, `cabinet_builder`).

### R2 · Napojenie miest (H12a jadro, H12b panel) — pravidlá

- **R2.1 Jedna vlastnosť na miesto, presná množina.** Každé miesto §0.1 dostane vlastnosť z tabuľky (stĺpec „Pýta sa na"); nová podmienka musí dať **rovnakú
  množinu typov** ako stará — matica v T2 pre `lower`, `upper`, `dishwasher`, `corner_blind`, `tall`, `nil`, `''`.
  Povinné dvojice: **„len `upper`" → `hangs?`**; **„`upper` alebo `dishwasher`/slot" → `!on_floor?`**; **„`!= dishwasher`" → `carcass?`**; **`== CORNER_TYPE` → `corner?`**
  alebo konkrétna vlastnosť (`fronts`, `zones`, `front_opening`, `type_locked`) podľa toho, na čo sa miesto pýta.
- **R2.2 Dátové `case` → register:** `construction_preset_for`, `template_id_for`, `default_name` (formát `auto_name`; `%{w}` = zaokrúhlená šírka, `%{dw}` = `dw_class_label`),
  `auto_name?` (`auto_name_typed`), `defaults_for` (R1.5), `TEMPLATE_TYPE_WORDS` (= `word`), `TEMPLATE_TYPE_LABELS` (= `word.upcase`, len pre `switchable`).
  `AUTO_NAME_RE`/`CORNER_AUTO_NAME_RE` ostávajú (nesú históriu starých tvarov bez diakritiky).
- **R2.3 Konkrétne náhrady (presná sémantika; zvyšok podľa stĺpca „Pýta sa na" §0.1):** `home_z` = `hang_z`; `legacy_plinth` = `hangs?(id_or_default(…))`;
  `normalize` slot vetva/limity = `builder`/`limits`, floor a plinth = `!on_floor?`; `cabinet_config` = `EXTRA_KEYS_BY_TYPE.fetch(type, [])` (**poradie kľúčov rovnaké** —
  dnes najviac jedna z dvoch vetiev) + `carcass?`; `support_type` = `!on_floor? || floor <= 0`; `Construction.corner?` = `CabinetTypes.corner?` (symbol aj string kľúč ako dnes);
  `ScaleWatch.min_for` z `limits` (+ `MIN`; hĺbka slotu 150 = `MIN` — golden); vlastník spotrebiča = `appliance_owner`; symbol blendy = `fronts == 'slot_fixed'`;
  `GhostTool` `corner?` = `CabinetTypes.corner?(@type_key)`, **`@type_key` ostáva surový** (kľúč pamäte výšky — ID).
- **R2.4 Miesta ID (surový reťazec ostáva):** `cabinet_hw_ctx['cabinet_type']` (vstup pravidiel — CN-03), `TemplatesDialog` porovnanie typu šablóny a skrinky
  (`:419-420`, `|| 'lower'` → `id_or_default`), kľúč ghostu, `actions_templates.rb:227` (`have`), `corner_change_refusal` (`want ≠ have` a `type_locked` aspoň jedného).
- **R2.5 Panel (H12b):** `actions_cabinet` (slot preflight, `slot_params?` → `!carcass?`, preflight/šablóna/čelá/strana rohovej, `slot_fronts_refusal`/`corner_fronts_refusal`
  podľa `fronts`), `actions_templates` (whitelist = `ids_where(:template_type, 'switchable')`, zámok = `locked`, vety cez `word`), `actions_appliance` (`appliance_owner`),
  `actions_zones` (`zones == 'shelves_only'` → `CORNER_ZONES_MSG`), `payloads` (`corner?`, `appliance_owner`, `EXTRA_KEYS_BY_TYPE`, `carcass?`), `sync.rb` `defaults:` =
  `DEFAULTS_BY_TYPE` (rohová ďalej cez `corner_insert_defaults(model)`; poradie kľúčov JSON rovnaké), `templates_dialog` (veta cez `word`).
- **R2.6 Aditívne kľúče payloadu (H12b, JS ich zatiaľ ignoruje):** `NX.init` dostane `cabinet_types: CabinetTypes.client_payload`; záznamy knižnice šablón
  (`Panel.template_list` — **všetky cesty** pushu, aj Štúdio) `type_word` (= `word` z `norm(config.type)`; doska bez kľúča); payload Pravidiel kovania pri pravidle
  s `cabinet_type` hotovú vetu rozsahu (dnešné znenie `rules.js:295-298` — „na hornú skrinku" / „na spodnú skrinku", inak ďalej podľa dnešnej logiky).
  Kľúč payloadu je **kontrakt** (audit): názvy kľúčov a ich hodnoty v `client_payload` sa uvedú v odseku `cabinet_types.rb`.

### R3 · JS z dát servera (H12c)

- **R3.1** `core.js`: `NXTypes` = `set(list)` (volá `NX.init` **prvým riadkom** pred `DEFAULTS`), `ids()`, `known(t)`, `norm(t)`, `get(t)`, `has(t, key, value)`, `label(t)`,
  `hangs(t)`, `onFloor(t)`, `carcass(t)`, `corner(t)`. **Pred `NX.init` je register prázdny** a `norm` vracia `'lower'` (jediná zostávajúca konštanta, `FALLBACK`).
- **R3.2 Zrušiť zoznamy:** `CAB_TYPES`, `INSERT_TYPES` (= `NXTypes.ids()` + `'board'`), `NX_TYPE_LABEL`, `TYPE_LIMITS`, `LEGS_INSERT_TYPES`, `NX_CTX_LOCK` (veta zo `zones_reason`),
  `TPL_TYPE_LOCK` (texty z `template_lock`), zoznamy v `templateType`/`templatesForType`; `CONSTRUCTION_FIELDS` `only:'corner_blind'` → predikát vlastnosti (napr. `onlyIf: 'corner'`).
- **R3.3 Predikáty §0.2** podľa R2.1 (rovnaké dvojice); `nxLegsApplyVisibility(t)` dostáva **skutočný typ** a skryje pri `!onFloor(t)` — volajúci prestane posielať `'upper'`
  za slot (`form.js:1054`); `nxLegsInsertDrop` sa volá pre tú istú množinu ako dnes (`upper` aj slot).
- **R3.4 Štúdio:** `templates.js` `tplTypeLabel` → `tp.type_word` (server); `rules.js:295` → veta zo servera. **Bez JS mapy typu.**
- **R3.5 HTML ostáva statické** (`panel.html:196-199`, `:929-933`); guard T3 porovná `data-ins-type`, text tlačidla, `title` neprázdny, `option value`/text s registrom
  (`label`, `ui_order`).
- **R3.6 Výnimky guardu (allowlist s dôvodom):** `core.js:2` a `bridge.js:293` (bootstrap `DEFAULTS`), `FALLBACK` v `NXTypes`, `'board'` vo vkladaní.

### R4 · Mená rolí (H12d)

- **R4.1** `PartKeys::ROLE_LABELS` = **doslovne** dnešné `ProductionCore::ROLE_LABELS` (Kusovník je autorita — `outputs.md:524`), `PartKeys.role_label(role)` = dnešná logika
  (`ROLE_LABELS[r] || (r.empty? ? '' : r)`). `ProductionCore::ROLE_LABELS`/`role_label` = alias/delegácia (konzumenti a testy bez zmeny).
- **R4.2** `ZONE_PART_LABELS` a `DRAWER_PART_LABELS` sa **odvodia** z `ROLE_LABELS` (S10 — bajtovo rovnako); `Panel::BOARD_ROLE_LABELS` zanikne (`role_label`).
- **R4.3** `part_card_payload` dostane `role_label` (`bridge.js:38` `nxTempLabel` číta `sel.role` — či je `sel` vždy payload karty dielca, NEOVERENÉ; implementátor
  overí a doplní kľúč aj tam); `part_card.js` použije `pc.role_label || pc.role`, mapa `roleLabel` zanikne.
  **Viditeľná zmena len v karte dielca** (9 rolí, S5) — Q1.
- **R4.4** Výrobné mená (§0.3) a `Recipes.role_label`, `rdRoleDesc`, `corner_preview_title` sa **nemenia**. Guard: každá rola `BuildPlan::ROLES` okrem rezervovaných
  (`cover_panel`, `gola_profile`) má zobrazovacie meno; v `ui/js` nie je mapa mien rolí.

### R5 · Neznámy typ — explicitne

- Správanie ostáva: config z novšej verzie zastaví `newer_config?` **pred** `normalize`; inak `norm` → `lower` ticho. Jedna funkcia (`CabinetTypes.norm`), jedna konštanta
  (`FALLBACK`), test T1 a veta v STANDARD §4.2 („neznámy typ sa číta ako dolná; config z novšej verzie stopne dopredný guard skôr").

### R6 · Pasca závesov CN-03

- Guard T3c: `CabinetTypes.ids_where` s `hang_z > 0` **=** `applies_to.cabinet_type` seed pravidla `zavesenie-hornej-skrinky` (dnes `['upper']`), a každý `cabinet_type` v seede je
  známy typ. Nový visiaci typ bez úpravy seedu (+ `SEED_VERSION` + „Doplniť nové predvoľby") **zlyhá v teste**. Hláška testu povie, čo urobiť.
- `hardware.md` odsek `hardware_rules`: jedna veta o pravidle viazanom na typ a o guarde (plná mapa v H13). Používateľské pravidlá a snapshoty projektov guard nepokrýva — povedať v odseku.

## 7 · Testy a DoD

- **T0 · Golden PRED zásahom** (R0): `tests/pure/test_h12_golden.rb` + `tests/fixtures/h12_golden/` (headless), `tests/js/test_h12_golden.js` (JS, pred H12c),
  `insu.json` (R0.5), roly (pred H12d). Zelené na starom kóde v 1. commite, **bez regenerácie** v ďalších commitoch (zmena fixtúry = nález).
- **T1 · Register:** R1.3 invarianty, `norm`/`id_or_default`/`known?` (Symbol, String, nil, `''`, `'tall'`), `client_payload` = `tests/fixtures/h12_cabinet_types.json`
  (Ruby test porovná, JS testy z neho plnia `NXTypes` — vzor `slot_front_eval.json`).
- **T2 · Matica predikátov:** pre každé miesto R2.3/R2.5/R3.3 stará množina (zapísaná v teste z §0.1/§0.2) = nová, nad 7 vstupmi (R2.1).
- **T3 · Guardy:** a) **žiadne nové vetvenie podľa mena typu** — sken `noxun_engine/**/*.rb` a `ui/js/*.js` na `(==|!=|===|!==)\s*['"](lower|upper|dishwasher|corner_blind)['"]`,
  opačné poradie, `when 'upper'…`, `%w[…upper…]`, `indexOf('upper')`, `CORNER_TYPE` mimo registra — **allowlist podľa obsahu riadka s dôvodom** (seed dát `templates.rb`
  `lower_base`/`upper_base`/slot seedy, kategória spotrebiča `'dishwasher'` v `appliance_catalog`, `OWNER_MATRIX`, `SLOT_EXPECTS`, `budget_store`, `construction.rb:342`,
  `bom.rb:477`, `payloads.rb:491`, bootstrap R3.6); b) `DEFAULTS_BY_TYPE`/`EXTRA_KEYS_BY_TYPE` ↔ `IDS`; c) CN-03 (R6); d) HTML ↔ register (R3.5); e) poradie
  `main.rb` (R1.6); f) žiadna JS mapa mien rolí, `ROLE_LABELS` pokrýva roly (R4.4); g) `docs/ARCHITEKTURA.md` má riadok `cabinet_types` (existujúci guard).
- **T4 · Prepis existujúcich testov zo zdroja na paritu (nemazať, nahradiť ekvivalentom):** `test_s1e_slot.rb:107-124`, `:169-170`, `:611-622` · `test_roha1_rohova.rb:191-193`,
  `:754-755`, `:921-928` · `test_roha2_vkladanie.rb:199` · `test_uib3_rady.rb:158` · JS `test_s1e_slot.js:54`, `:135-136`, `:340` · `test_roha1_rohova.js:50-71`, `:94-97` ·
  `test_uib3_korpus.js:164`. PR vypíše každý prepísaný assert a jeho náhradu.
- **T5 · Mutácie (každá musí zhodiť aspoň jeden test; min. 14):** M1 `upper hang_z 0` · M2 `dishwasher on_floor true` · M3 `corner_blind on_floor false` · M4 `FALLBACK 'upper'` ·
  M5 `norm` neznámy ponechá · M6 `core.js:1812` cez `!onFloor` (zmení slot) · M7 `limits` slotu 200 · M8 `corner_blind zones tree` · M9 `dishwasher template_type switchable` ·
  M10 `type_locked false` pri rohovej · M11 `appliance_owner cabinet` pri slote · M12 `fronts free` pri slote (symbol blendy) · M13 `corner_blind hang_z 1400` bez úpravy seedu
  (CN-03) · M14 vymenené poradie `EXTRA_KEYS` v `cabinet_config` · M15 JS `NXTypes.set` až po `loadSelected` · M16 (H12d) `role_label` z JS mapy.
- **T6 ·** `ruby tests/run_all.rb` + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + `ruby scripts/encoding_guard.rb --repo`.
- **DoD každej časti:** T0 bez zmeny fixtúr · jej T1–T5 zelené · mutácie v PR · in-SU podľa §8 · dokumentácia §11 · PR s „Predrecenziou" a vetou „čísla bez zmeny — golden
  fixtúry nedotknuté".

## 8 · In-SU — **brána mergu H12a a H12b**

Runner `scripts\run_su_tests.ps1 -CloseWhenDone`, kópia `_dev\ENGINEtests.skp`. Nový scenár **`run_h12`** v `tests/sketchup/su_runner.rb`:
1. **Capture (pred H12a, nezmenený kód):** postaví 6 skriniek (dolná s dvierkami a policou · dolná 800 so zásuvkou a soklom `front` · horná · slot 60 · rohová vľavo ·
   rohová vpravo 500/100) a zapíše: dielce každej skrinky (`part_key`, rola, názov, origin, rozmery definície, materiál — vzor `run_sync` `:2612-2680`), config bez
   `engine_version`, `ProductionCore.fresh_collect` → `Bom.compute` riadky, **VEPO CSV bajty** (`VepoExport.build`, pevný projekt a čas — vzor `su_runner.rb:14651`) + LOG
   bez časovej pečiatky, `ProductionCore.hardware_labeled` (nákup), `budget_payload` (súčty), `control_payload` (počty a kategórie).
2. **Porovnanie (H12a, H12b):** to isté → **bajtovo rovnaké** s `insu.json`; plus existujúce `run_sync`, `run_s1e`, `run_roha1`, `run_roha2`, `run_rohb1` zelené.
3. H12b navyše: apply zmeny šírky na každom type, použitie šablóny rovnakého typu, odmietnutie šablóny iného typu, prepnutie strany rohovej, ghost vloženie hornej
   (Z = 1400) — 1 krok Späť každá akcia.
Ak SketchUp nepôjde, časť **čaká** (nemerguje sa s „neoverené"). PR uvedie hlavu, na ktorej in-SU bežal.

## 9 · Riziká

- **Posun v okrajovom prípade** („len horná" vs „horná alebo slot", neznámy typ) — najvyššie riziko refaktoru; kryje T2 matica + mutácie M5/M6 + golden.
- **Poradie kľúčov** v `cabinet_config`/`defaults` JSON (bajty configu v modeli, golden šablón) — T0 porovnáva JSON reťazec, nie hash.
- **Načítanie** `cabinet_types.rb` po `construction.rb` = pád pluginu pri štarte → guard T3e + in-SU štart.
- **JS pred `NX.init`** (S15 NEOVERENÉ): skorý `setType` padne na `lower` (rovnako ako dnes pri neznámom type); test M15.
- **Štúdio bez `type_word`** pri niektorej ceste pushu šablón → prázdne slovo v dlaždici; mitigácia: jedna funkcia skladá záznam (R2.6) + JS test.
- **Oslabenie guardov** pri prepise T4 — PR vypíše 1:1 náhrady.
- **CN-03** chráni len seed; používateľom upravené pravidlá a projektové snapshoty — veta v `hardware.md`.
- **Kolízia s H6/H7/H11** (§5.1). **Veľké diffy** → štyri časti, každá s vlastným review.
- Zmiešané PC (Lucia): dáta sa nemenia → bez rizika.

## 10 · Smoke checklist pre Michala (po H12c, druhý krát po H12d)

1. Vkladacia karta: **Dolná, Horná, Rohová (vľavo aj vpravo, kláves D), Umývačka 60 a 45** — každú vlož; rozmery, nohy, sokel a výška zavesenia (horná 1400) ako predtým.
2. Inspector nad každou: hlavička typu (Dolná/Horná/Rohová/Umývačka), riadky Sokel a Nohy (horná a umývačka ich nemajú), riadok rohovej, pri umývačke bez Zón.
3. Šablóny: ponuka filtrovaná typom; „Uložiť ako šablónu" z rohovej a umývačky má typ zamknutý; horná ↔ dolná sa prepne; šablóna iného typu sa na skrinku nepoužije.
4. Štúdio → Šablóny: slovo typu na dlaždici; Pravidlá kovania: „Bystrica — na hornú skrinku".
5. Na **kópii poslednej zákazky**: Kusovník, Rozpočet SPOLU, Nákup (horná má 2× závesy) a **VEPO CSV porovnaj s exportom pred aktualizáciou** (rovnaký súbor).
6. (H12d) Karta dielca: názvy rolí ako v stĺpci Rola Kusovníka (napr. „Strop", „Čelo zásuvky"); dno zásuvky už nie je `drawer_bottom`.

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** → T0–T6 zelené → in-SU (H12a, H12b) → **architektúra na mieste:**
`construction.md` nový odsek **`cabinet_types.rb`** (kontrakt registra, kľúče, `client_payload`, neznámy typ, pravidlo „jedna vlastnosť na miesto") + prepísané odseky
`cabinet_builder.rb` (ROH-A1/S1-E vety o `TYPES` → register), `construction.rb`, `ghost_tool.rb`, `scale_observer.rb` · `docs/ARCHITEKTURA.md` riadok `cabinet_types` ·
`ui-lifecycle.md` odsek „JS registre typu skrinky" (`:2105-2108`) a Vkladacia karta (`:855`) → `NXTypes` zo servera (H12c) · `appliances.md` (vlastník spotrebiča) ·
`hardware.md` CN-03 veta (H12a) · `outputs.md:524-525` + `model-a-identita.md` odsek `part_keys` (H12d) → **STANDARD §4.2** (register a neznámy typ; hranica TYP vs ŠABLÓNA
bez zmeny) → **prepis STAV** → **KRONIKA** odsek navrch → **PLAN** riadok H12 s časťami (✅ + PR) → package + surový audit do `SYSTEM/zdroje/bloky/HARDENING/` →
**PR popis:** čo sa mení pre používateľa („nič viditeľné" / H12d karta dielca), trieda, Predrecenzia, mutácie, in-SU hlava, „golden fixtúry nedotknuté". Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | Nový modul `core/cabinet_types.rb`, nie konštanta v `CabinetBuilder` | `construction.rb` sa načíta pred builderom (S14) — inak druhá kópia | nie |
| D2 | Register nesie vlastnosti a texty; **predvoľby, polia a kód typov ostávajú v builderi** (+ paritný guard) | byte-identita a menší diff; register hovorí „ktorá vetva" | **áno** |
| D3 | Dve podlahové vlastnosti (`hang_z`, `on_floor`) namiesto jednej | dve dnešné množiny (§0.4) — jedna by zmenila okrajové správanie | nie |
| D4 | Neznámy typ = profil dolnej cez `norm`; miesta ID si ponechajú surový reťazec | presná dnešná sémantika (§0.1 stĺpec) | nie |
| D5 | HTML tlačidlá a `<select>` statické + guard | 6. typ aj tak potrebuje dizajn (UI_DIZAJN §5.4); generovanie = zmena DOM bez prínosu teraz | **áno** |
| D6 | JS dostane register v `NX.init`, Štúdio hotové slová v payloade (bez JS mapy) | S15; jedna autorita textov = server | nie |
| D7 | Rez na 4 časti (H12a–H12d), audit jeden na package | ~1 deň na časť, každá bajtovo rovnaká | **áno** |
| D8 | Mená rolí do `PartKeys` (core, bez nového modulu), Kusovník je autorita | `outputs.md:524`; `PartKeys` už má `human_label` | krátko (Q1) |
| D9 | CN-03 riešiť guardom, nie zmenou filtra pravidiel | filter vlastnosťou = zmena schémy pravidiel (F6) | nie |
| D10 | Bez logovania neznámeho typu | „bez zmeny správania"; observer by mohol logovať opakovane | nie |
| D11 | `rdRoleDesc`, `Recipes.role_label`, vlastnosti rolí mimo H12 | iné tvary/účel, nie „meno" (C-05); patria do mapy H13 | nie |
| D12 | In-SU golden v capture móde na nezmenenom kóde (1. commit H12a) | jediný dôkaz VEPO bajtov zo 4 typov (S16) | **áno** |

## 13 · Otázky pre Michala (produktové; do odpovede platí návrh)

- **Q1 · Názvy v karte dielca.** Karta dnes píše inak než stĺpec Rola v Kusovníku: „Vrch" vs **„Strop"**, „Priečka zvislá" vs **„Zvislá priečka"**, „Priečka vodorovná" vs
  **„Vodorovná priečka"**, „Zásuvkové čelo" vs **„Čelo zásuvky"**, a pri dielcoch zásuvky a voľnej doske ukazuje technický kód (`drawer_bottom`). **Návrh:** všade
  názvy z Kusovníka (tučné). Kusovník, VEPO ani objednávka sa nemenia — mení sa len text v karte.

## 14 · Nálezy mimo scope a odovzdanie H13

- **F1** `outputs.md:524-525` tvrdí, že JS mapa rolí je zhodná s `ROLE_LABELS` — nie je (S5). *Opraví H12d.*
- **F2** Dva `CORNER_TYPE` (S14). *Zjednotí H12a.*
- **F3** Terminológia: auto názov „**Spodná** skrinka", typ „**Dolná**", pravidlo „na **spodnú** skrinku" — H12 nemení (bajty); návrh do POJMY/H13, rozhodne Michal neskôr.
- **F4** `modules/fronts.rb:381` výrobný názov „**Výklop** N" s diakritikou (ostatné ASCII) — či VEPO import diakritiku v `nazov` prijme, NEOVERENÉ; do zásobníka (H17 R-15).
- **F5** `PLAN.md:228` (STABILITA) „Prepínanie typu HORNÁ/DOLNÁ občas zlyhá" — cesta v UI neexistuje (FAKTY §1.4); navrhnúť uzavretie alebo preformulovanie v H13.
- **F6** Filter pravidiel kovania vlastnosťou (`hangs`, `on_floor`) namiesto `cabinet_type` — odstráni CN-03 úplne, ale mení schému pravidiel a seed → s prvým visiacim novým typom.
- **F7** `part_card.js` `isFront` je JS kópia `FRONT_MATERIAL_ROLES` (vlastnosť roly) — H13 mapa / dávka novej roly.
- **Odovzdanie H13 (B-06 mapa rozširovacích bodov):** (1) **nový typ** = riadok `CabinetTypes::REGISTRY` + `DEFAULTS_BY_TYPE` (+ `EXTRA_KEYS_BY_TYPE`, `PARAM_KEYS`) + kód
  buildera (`Construction.build_plan` vetva / zostava) + HTML tlačidlo a `option` (guard T3d) + seed šablóny (`TemplateStore::STD`) + **CN-03** (seed závesov a
  `SEED_VERSION`, ak `hang_z > 0`) + `CONFIG_SCHEMA` bump (dopredný guard starších PC); (2) **nová rola** = zoznamy §0.3 „Vlastnosti rolí" (mená konštánt, nie riadky)
  + `PartKeys::ROLE_LABELS` + výrobný názov a `VepoExport::SHORT_NAMES`; (3) guardy vzniknuté v H12 (T3a–g) ako „čo ťa zastaví"; (4) tabuľka verzií dát B-07
  (čísla S12). H13 píše **mená konštánt**, nie čísla riadkov (CN-02).

---

## 15 · Audit návrhu (audítor audit-povinných, 1.10.2026) — 0 BLOCKER · 6 FIX → zapracovanie orchestrátorom · MÁ PREDNOSŤ

Surový výstup `AUDIT_H12_raw.md` (implementátor ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package). Audit uzavretý (FIX zapracované).
- **A1 (H12c):** žiadny odvodený zoznam typov sa nesmie vyhodnotiť pri načítaní skriptu (`insert_state.js:40` beží pred `sketchup.ready()` — `boot.js:143`).
  **Členstvo vždy dynamicky pri volaní** (funkcia nad `NXTypes`), alebo explicitná obnova všetkých odvodených zoznamov po doručení registra. Test: načítať
  skripty **pred** doručením registra, potom doručiť a prepnúť všetky typy (Horná, Umývačka, Rohová nesmú skončiť ako `lower`).
- **A2 (H12b):** `id_or_default` **nenahrádza** porovnávanie identity šablón — `templates_dialog.rb:419` zachová dnešnú sémantiku (`type: ''` na dolnej =
  odmietnuté). Normalizácia neznámeho typu je oddelená funkcia. Obojsmerná matica: `''`, chýbajúci typ, `lower`, neznámy neprázdny typ.
- **A3 (H12a):** golden „nákup" musí zachytiť **skutočný objednávkový výstup**: `hardware_expansion` + `HardwareSets.purchase_csv`
  (`production_core.rb:2118`, `:2143`) s pevným časom, neprázdnym mapovaním setov a katalógovými položkami — nie len `hardware_labeled`. Porovnávať po
  každom reze H12a–d.
- **A4 (H12a):** golden VEPO LOG — riadok `Verzia:` (`vepo_export.rb:768`) **vyňať z porovnania** (alebo pripnúť verziu exportnej sondy); baseline sa
  neregeneruje pri bump verzie.
- **A5 (H12d):** H12d zavádza kontrakt `role_label` Ruby↔JS → **audit-povinná, predrecenzia povinná bez ohľadu na veľkosť** (§5 opravený týmto bodom).
- **A6 (H12b–d):** **fotky okien povinné**: pri zmene JS/CSS/HTML `scripts\ui_foto.ps1 -Shoot`, pri zmene Ruby payloadu (nový register, `role_label`)
  najprv `-Record` (nová nahrávka) a potom `-Shoot`; cesty k fotkám do reportu.

**Potvrdenie orchestrátora k §12:** D2 áno (predvoľby ostávajú v builderi) · D5 áno (HTML statické + guard) · D7 áno (rez H12a → H12b → H12c → H12d,
každá samostatný PR, z čerstvého mainu, každá bajtovo rovnaké výstupy) · D12 áno (in-SU golden v prvom commite H12a). **Q1** (názvy v karte dielca
podľa Kusovníka) — otázka pre Michala; do odpovede platí návrh, ale **H12d sa spustí až po H12a–c**, takže Michal stihne odpovedať.
