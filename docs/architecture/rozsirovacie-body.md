# Rozširovacie body — kde sa plugin rozširuje

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Čo to je:** kontrolný zoznam miest pre päť najčastejších rozšírení — nový typ skrinky, nová rola dielca, nový stĺpec Kusovníka,
> nová sekcia Štúdia a nové pravidlo kovania viazané na typ. Detail každého miesta je v odseku jeho modulu (Grep `^### <súbor>`).
> **Ako sa číta:** tabuľky menujú **súbor a mená** (konštanta, modul, funkcia) — nikdy čísla riadkov. Riadok tabuľky, ktorý začína
> cestou v spätných apostrofoch, stráži `tests/pure/test_h13_rozsirovacie_body.rb`: súbor musí existovať a každé meno z druhého
> stĺpca v ňom musí byť. Premenovanie alebo zrušenie registra bez úpravy tejto kapitoly test zhodí.
> **Údržba:** dávka, ktorá presunie alebo premenuje register z tejto kapitoly, opraví **jej riadok na mieste**. Priebeh prác sem
> nepatrí (KRONIKA). Čísla verzií dát (schémy, seedy, STD) a kedy ich zvýšiť: jediná tabuľka v
> [../../SYSTEM/STANDARD.md](../../SYSTEM/STANDARD.md) §13.

**Spoločné pravidlá všetkých scenárov:**

- **Trieda dávky** sa určuje podľa CLAUDE.md (výrobná/cenová, audit, predrecenzia — hranice s príkladmi tam). Každé zvýšenie schémy
  alebo STD (tabuľka STANDARD §13) robí dávku **audit-povinnou**.
- **Jedna vlastnosť na miesto:** kód sa pýta vlastnosti (visí, stojí na podlahe, má korpus, je čelo), nie mena typu či roly. Nové
  porovnanie mena typu (`== 'upper'`, `when 'dishwasher'`) v Ruby ani v JS guardy H12 nepustia.
- **Seed sa do existujúcich inštalácií dostane len zvýšením jeho verzie** (`SEED_VERSION` + `merge_seed`); projekty si nesú vlastný
  snapshot, ktorý sa obnoví až akciou „Doplniť nové predvoľby" alebo uložením Pravidiel.

## 1 · Nový typ skrinky

Typ = **riadok registra + vlastný kód buildera**, nie desať zoznamov. Register vie, **ktorá** vetva platí; **ako** sa stavia, ostáva
v builderi. Postup: (1) riadok `REGISTRY` so všetkými kľúčmi `KEYS`, (2) predvoľby a polia typu, (3) kód buildera, (4) UI (HTML je
statické), (5) seed šablóny, (6) **pasca závesov nižšie**, (7) verzie dát — vždy `CONFIG_SCHEMA` (starší plugin by neznámy typ sklopil
na dolnú a prestavbou vyrobil inú skrinku bez hlášky), pri nových rolách aj BuildPlan `SCHEMA` a ABS `SEED_VERSION`.

| Súbor | Mená | Čo tam urobiť |
|---|---|---|
| `noxun_engine/core/cabinet_types.rb` | `CabinetTypes::REGISTRY` · `KEYS` · `IDS` · `FALLBACK` · `client_payload` | riadok typu so všetkými vlastnosťami (`hang_z`, `on_floor`, `builder`, `fronts`, `zones`, `ui_order`…) |
| `noxun_engine/core/cabinet_builder.rb` | `DEFAULTS_BY_TYPE` · `EXTRA_KEYS_BY_TYPE` · `normalize` · `cabinet_config` · `CONFIG_SCHEMA` | predvoľby `*_DEFAULTS`, vlastné polia typu, whitelist configu, bump schémy |
| `noxun_engine/core/construction.rb` | `Construction.build_plan` · `appliance_slot_plan` · `corner_parts` · `cabinet_hw_ctx` | kód topológie (nový `builder` alebo zostava); kontext pravidiel kovania nesie surový typ |
| `noxun_engine/ui/panel/actions_cabinet.rb` | `PARAM_KEYS` · `TEMPLATE_TYPE_WORDS` | nové polia z panela (whitelist); slovo typu je odvodené z registra |
| `noxun_engine/ui/panel/sync.rb` | `DEFAULTS_BY_TYPE` · `corner_insert_defaults` | predvoľby do JS idú z buildera (typ s vlastným výpočtom ako rohová) |
| `noxun_engine/ui/panel.html` | `data-ins-type` · `tplSaveType` | tlačidlo vkladacej karty a `option` modalu „Uložiť ako šablónu" (statické, guard ich porovná s registrom) |
| `noxun_engine/ui/js/core.js` | `NXTypes` · `CONSTRUCTION_FIELDS` · `onlyIf` | JS register netreba meniť; pole konštrukcie len pre nový typ = `onlyIf` predikát |
| `noxun_engine/ui/js/form.js` | `SLOT_FIELDS` · `CORNER_FIELDS` · `applyVisibility` | vlastné polia typu vo formulári (validácia len pri svojom type) |
| `noxun_engine/core/templates.rb` | `TemplateStore` · `build_predefined` · `migrate!` · `missing_slot_seed` · `STD` | seed šablóny; existujúcej knižnici ju doplní len migrácia pri bumpe `TemplateStore::STD` |
| `noxun_engine/core/appliance_binding.rb` | `OWNER_MATRIX` | len ak typ vlastní spotrebič (`appliance_owner`) |
| `noxun_engine/ui/rules_dialog.rb` | `TYPE_SCOPE_PHRASES` · `type_scope_desc` | veta rozsahu pravidla („na hornú skrinku") pozná len hornú a dolnú — pravidlo s novým typom vetu nedostane |

**Mimo registra ostáva (overené Grepom po H12):** predvoľby a polia typu, kód buildera (`appliance_slot_plan`, `corner_parts`,
`slot_fronts!`, `corner_fronts!`), statické HTML tlačidlá a `option`, seed šablón, vety rozsahu `TYPE_SCOPE_PHRASES`, matica vlastníkov
spotrebiča `OWNER_MATRIX`, seed pravidiel kovania a **slovo „Spodná" v auto názve dolnej** (terminológia — rozhodne Michal). Ikona typu
patrí do inventára UI_DIZAJN §4 a rad typov vkladacej karty má podľa UI_DIZAJN §5.4 miesto na päť typov s textom do ~9 znakov — dnes
ich je päť (štyri typy + Doska), šiesty typ potrebuje rozhodnutie o rozložení.

> **⚠ Pasca závesov (CN-03).** Jediné seed pravidlo kovania s filtrom typu je **`zavesenie-hornej-skrinky`** („Bystrica", 2 ks)
> s `applies_to.cabinet_type = ['upper']`. Nový **visiaci** typ (`hang_z > 0`, napr. horná rohová) by bez úpravy **nemal závesné kovanie
> v nákupe ani v cene** — bez hlášky. Postup: doplniť id do `cabinet_type` seed pravidla, zvýšiť `HardwareRules::SEED_VERSION`
> (inak `merge_seed` existujúcu knižnicu nedoplní) a v existujúcich projektoch „Doplniť nové predvoľby". Guard: každý visiaci typ
> registra musí byť v `cabinet_type` pravidla závesov, alebo v zozname výnimiek s dôvodom (`NX_H13_HANG_EXCEPTIONS` v teste);
> pravidlo závesov nesmie platiť na typ, ktorý nevisí. Používateľské pravidlá a snapshoty projektov guard nevidí.

| Súbor | Mená | Čo stráži |
|---|---|---|
| `noxun_engine/core/hardware_rules.rb` | `SEED_RULES` · `zavesenie-hornej-skrinky` · `applies_to` · `cabinet_type` · `SEED_VERSION` · `merge_seed` | seed pravidla závesov a jeho verzia |
| `tests/pure/test_h13_rozsirovacie_body.rb` | `NX_H13_HANG_EXCEPTIONS` · `nx_h13_hang_problems` | pasca závesov (visiace typy = filter pravidla závesov) |
| `tests/pure/test_h12a_register.rb` | `H12a T1` · `H12a T2` · `H12a T3a` · `H12a T3b` · `H12a T3e` | register (kľúče, neutrálny profil), presné množiny predikátov, žiadne vetvenie podľa mena v Ruby, predvoľby = `IDS`, poradie načítania |
| `tests/pure/test_h12b_panel.rb` | `H12b R2.5` · `H12b R2.6` | panel Ruby z registra, `cabinet_types` v `NX.init` |
| `tests/pure/test_h12c_js.rb` | `H12c T3a` · `H12c T3d` | žiadne vetvenie podľa mena v JS, HTML tlačidlá a `option` = register |
| `tests/fixtures/h12_cabinet_types.json` | `hang_z` · `ui_order` | zmluva `client_payload` — nový typ ju mení (a s ňou JS sady) |

## 2 · Nová rola dielca

Rola je **vlastnosť dielca v pláne** (`BuildPlan::ROLES`) a zoznamy jej vlastností sú dnes rozdelené po moduloch (ktorá rola je čelo,
ktorá stojí, ktorá je zásuvka, ako sa volá). Výrobný názov dielca (ASCII, ide do kusovníka a VEPO) je **iný** údaj než zobrazovacie meno
roly. Verzie: BuildPlan `SCHEMA` (nová rola v pláne), `CONFIG_SCHEMA` (ak ju nesie nové pole configu), ABS `SEED_VERSION` (predvolené
hrany novej roly — inak sa na existujúcich PC postaví **bez pásky**). Dávka je výrobná (mení kusovník a VEPO).

| Súbor | Mená | Čo tam urobiť |
|---|---|---|
| `noxun_engine/core/build_plan.rb` | `BuildPlan::ROLES` · `SCHEMA` | rola v pláne; rezervované roly (`cover_panel`, `gola_profile`) plán nevydáva |
| `noxun_engine/core/construction.rb` | `FRONT_MATERIAL_ROLES` · `CORNER_NAMES` | kde dielec vzniká a jeho výrobný názov; čelo = materiálový kanál čiel |
| `noxun_engine/core/abs_rules.rb` | `EDGE_LABELS` · `SEED_RULES` · `SEED_VERSION` · `STANDING_ROLES` | mená hrán a predvolené ABS novej roly (bump seedu) |
| `noxun_engine/core/part_faces.rb` | `ROLE_AXES` · `STANDING_ROLES` | osi dielca (dĺžka/šírka, smer dekoru) |
| `noxun_engine/core/cabinet_builder.rb` | `PART_TAGS` · `DRAWER_ROLES` | tag vrstvy a príslušnosť k zásuvke |
| `noxun_engine/core/validation.rb` | `FRONT_ROLES` | Kontrola čiel |
| `noxun_engine/core/hardware_rules.rb` | `FRONT_ROLES` | ktoré čelá nesú kovanie |
| `noxun_engine/core/cp_export.rb` | `FRONT_ROLES` | cenová ponuka — čo je čelo |
| `noxun_engine/core/vepo_export.rb` | `VepoExport::SHORT_NAMES` · `NAME_PAIRS` | skratka výrobného názvu pre VEPO (kľúč = presný reťazec buildera) |
| `noxun_engine/core/part_keys.rb` | `ZONE_PART_LABELS` · `DRAWER_PART_LABELS` | mená dielcov zóny a zásuvky v Kovaní a Kontrole |
| `noxun_engine/ui/production_core.rb` | `ROLE_LABELS` · `role_label` | zobrazovacie meno (stĺpec Rola v Kusovníku — autorita mien) |
| `noxun_engine/core/drawer_recipes.rb` | `Recipes` · `role_label` | iný gramatický tvar do viet hlášok zásuviek |
| `noxun_engine/ui/rules_dialog.rb` | `ABS_ROLE_ORDER` | poradie rolí v prehľade ABS sekcie Pravidlá |
| `noxun_engine/ui/panel/payloads.rb` | `BOARD_ROLE_LABELS` · `MANUAL_OWNER_PREFIXES` · `CORNER_PREVIEW_ROLES` | karta dosky, ručné zásahy, kresba rohovej |
| `noxun_engine/ui/js/part_card.js` | `roleLabel` · `isFront` | JS kópia mien a „je čelo" v karte dielca (mená zjednotí H12d) |
| `noxun_engine/ui/js/rules.js` | `rdRoleDesc` | veta rozsahu pravidla kovania podľa roly |
| `tests/pure/test_roha1_rohova.rb` | `BuildPlan::ROLES` · `EDGE_LABELS` · `ROLE_AXES` · `role_label` | vzor testu pre nové roly (každá rola vo všetkých zoznamoch) |

## 3 · Nový stĺpec Kusovníka

Kontrakt stĺpcov je **UI20_KONTRAKT Š2** ([../../SYSTEM/zdroje/ui20/UI20_KONTRAKT.md](../../SYSTEM/zdroje/ui20/UI20_KONTRAKT.md)).
Trieda dávky podľa CLAUDE.md: **popisný čítací stĺpec** bez zmeny `row_key`, zoskupenia a exportov (vzor stĺpca Rola cez
`rows_with_roles`) **nie je výrobný**; stĺpec s číslom, podľa ktorého sa objednáva alebo cenotvorí, zmena `row_key`, zoskupenia či obsahu
exportu **je výrobný/cenový**. Voľba stĺpca je per počítač (`localStorage`), ďalší stĺpec v menu „Stĺpce" nie je nový ovládací prvok.

| Súbor | Mená | Čo tam urobiť |
|---|---|---|
| `noxun_engine/ui/js/studio.js` | `COLS` · `cellValue` · `activeCols` · `colCls` · `PARTS_FIXED_COLS` · `nx_bom_cols` | definícia stĺpca, hodnota bunky, pevné rozloženie len pri predvolených stĺpcoch |
| `noxun_engine/ui/production_core.rb` | `rows_with_roles` · `row_roles` | doplnenie údaja do riadku bez zmeny zoskupenia |
| `noxun_engine/core/bom.rb` | `aggregate_rows` · `row_key` | zoskupenie riadkov — zmena = výrobná dávka |
| `noxun_engine/core/vepo_export.rb` | `VepoExport` | VEPO export (stĺpce exportu = výrobná dávka, kontrakt VEPO_KONTRAKT) |
| `tests/js/test_st1a_studio.js` | `COLS` | stĺpce a bunky tabuľky Dielce |

XLSX a CSV kusovníka dnes **neexistujú** (UI20_KONTRAKT Š5) — stĺpec sa do nich nepropaguje, kým nevzniknú.

## 4 · Nová sekcia Štúdia

Autorita zoznamu sekcií je Ruby whitelist; JS má zrkadlá (zjednotí ich dávka H14). Nová sekcia potrebuje ikonu v inventári
UI_DIZAJN §4, fotku v `scripts/ui_foto/shots.json` a `?v=` = VERSION pri novom skripte.

| Súbor | Mená | Čo tam urobiť |
|---|---|---|
| `noxun_engine/ui/studio_dialog.rb` | `StudioDialog::SECTIONS` · `push_state` | id sekcie (autorita) a jej dáta v pushi okna |
| `noxun_engine/ui/js/studio.js` | `STUDIO_SECTIONS` · `NAV` · `studioGoSection` | zrkadlo zoznamu, položka navigácie (skupina, ikona, text) |
| `noxun_engine/ui/js/shell.js` | `STUDIO_SECTIONS` | druhé zrkadlo (otváranie sekcie z Inspectora) |
| `noxun_engine/ui/js/studio_settings.js` | `SS_SECTIONS` | len sekcia skupiny Nastavenia |
| `noxun_engine/ui/production_core.rb` | `ROUTE_SECTIONS` | len ak nález Kontroly vedie do sekcie |
| `noxun_engine/ui/studio.html` | `studio.js` | nový skript sekcie s `?v=` |
| `scripts/ui_foto/shots.json` | `studio_bom` | fotka sekcie pre UI PR |
| `tests/pure/test_st4a_nastavenia.rb` | `STUDIO_SECTIONS` · `StudioDialog::SECTIONS` | JS zrkadlá = Ruby autorita |
| `tests/pure/test_ui_foto.rb` | `StudioDialog::SECTIONS` | fotky = všetky sekcie |

## 5 · Nové pravidlo kovania viazané na typ skrinky

Pravidlo kovania filtruje skrinku cez `applies_to` (`role: cabinet` + `cabinet_type`, `support`, `floor_height_min`, `flap_dir`).
Kontext skrinky skladá `cabinet_hw_ctx` a typ v ňom je **surový identifikátor** (nie normalizovaný). Dávka je **výrobná/cenová**
(mení nákup a cenu). Nové seed pravidlo = bump `HardwareRules::SEED_VERSION`; nový kľúč filtra, ktorý starší plugin nepozná,
mení formát pravidiel (`HardwareRules::STD`, dopredná brána — audit). Pravidlo viazané na vlastnosť typu namiesto zoznamu typov
(napr. „visí") by pascu CN-03 odstránilo, ale mení schému pravidiel — patrí k prvému novému visiacemu typu.

| Súbor | Mená | Čo tam urobiť |
|---|---|---|
| `noxun_engine/core/hardware_rules.rb` | `SEED_RULES` · `SEED_VERSION` · `STD` · `merge_seed` · `floor_height_ok?` · `evaluate` · `LEGACY_SEED_SHAPES` | seed pravidlo, filter, migrácia seedu (nedotknuté nahradiť, upravené nechať) |
| `noxun_engine/core/construction.rb` | `cabinet_hw_ctx` | kľúče kontextu skrinky (typ, podpora, výška sokla) |
| `noxun_engine/core/hardware_sets.rb` | `SEED_VERSION` · `LEGACY_SEED_SHAPES` | set (generický typ → kódy katalógu) pre novú položku |
| `noxun_engine/core/hardware_catalog.rb` | `SEED_SET_VERSION` | nové kódy v katalógu kovania |
| `noxun_engine/ui/rules_dialog.rb` | `TYPE_SCOPE_PHRASES` · `type_scope_list` | veta rozsahu pravidla v sekcii Pravidlá (server) |
| `noxun_engine/ui/js/rules.js` | `rdRoleDesc` | zobrazenie vety (typ sem prichádza hotovou vetou zo servera) |
| `tests/pure/test_h12b_panel.rb` | `type_scope` | veta rozsahu pravidla viazaného na typ |
| `tests/pure/test_hardware_sets.rb` | `zavesenie-hornej-skrinky` | seed pravidiel a jeho doplnenie do existujúcej knižnice |

Pravidlo s typom **sa týka aj pasce v scenári 1**: keď nové pravidlo platí na „všetky visiace" typy, guard závesov je vzor, ako ho
strážiť (množina typov z vlastnosti registra = filter pravidla).

## História

Kapitola vznikla dávkou H13 bloku 9 · HARDENING (krížový audit V1, B-06/CN-02, CN-03) ako náhrada súpisu, ktorý žil len v archíve
rohovej skrinky (`SYSTEM/archiv/bloky/ROHOVA/FAKTY_Z_KODU_2026-09-27.md` §1.2 a §2.6, s číslami riadkov k v0.14.0) a v package H12 §0.
