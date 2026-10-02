# PACKAGE H15 · Dáta kovania oddelené od mechaniky setov (C-03) — blok 9 HARDENING PO V1

> **Autorita:** triedenie Michala 1.10.2026 (`ROZHODNUTIA_MICHALA_2026-10-01.md`: C-03 = CX-03 · GR-07, **Teraz**); blok 9 (`SYSTEM/PLAN.md`, riadok H15
> „kód · audit · výrobná"): **bez zmeny výrobných a cenových čísel**. Dôkazy: `CROSS_AUDIT_A1_CODEX_ASTRA.md` **CX-03** (5 tabuliek v 3 súboroch — taxonómia, katalóg, sety;
> „nezavádzať univerzálny migračný systém"), `CROSS_AUDIT_A2_GROK.md` **GR-07** (3 tabuľky setov von zo súboru expanzie). Riadky auditov sú staršie — nižšie **prepočítané**.
> **Trieda (§5):** **audit ÁNO** (tri nové moduly `*_seed.rb`) · **výrobná/cenová ÁNO** (konzervatívne — presúva sa zdroj nákupných kódov a seed cien) · **predrecenzia**
> H15a aj H15b · **in-SU nie je brána** (odporúčaný 1 beh, §8) · fotky okien netreba · `codex-po-pr` bez výnimky.
> **Bez viditeľnej zmeny:** knižnica setov, katalóg a taxonómia po čerstvej inštalácii aj po upgrade, nákupné CSV, rozpočet kovania a ponuka Pravidiel — **bajtovo rovnaké**
> (golden T0 PRED zásahom). Tvar súborov v `%APPDATA%` ani snapshotu v .skp sa nemení; `HardwareSets::SEED_VERSION` **8**, `HardwareCatalog::SEED_SET_VERSION` **6**
> a `HardwareTaxonomy::SEED_VERSION` **3** menia len súbor, nie hodnotu.
> **Verzia:** každá časť = patch podľa mainu pri štarte (dnes `0.17.15`) + všetky `?v=` + prepis STAV. **Stav kódu:** sonda nad `main` **`108c808c`** (v0.17.15, po PR #451).

---

## 0 · Sonda na kóde (headless, 1.10.2026)

Skripty v `scratchpad/HARDENING/`: `sonda_h15.rb` (fakty a odtlačky výstupov; `H15_ROOT` = repo alebo kópia), `sonda_h15_suite.rb` (celá sada s kontrolou mutácie konštánt,
voliteľne s rekurzívnym zmrazením), `sonda_h15_e2e.rb`, `sonda_h15_str.rb`, `sonda_h15_m3.rb`, `sonda_h15_map.rb` (guard mapy H13), `sonda_h15_ast.rb` (prototyp R5 a) a
**prototyp** `proto_split_h15a.rb`/`proto_split_h15b.rb` + `proto_docs_h15a.rb`/`proto_docs_h15b.rb` nad **kópiou repa** `proto_h15/ENGINE` (bez `.git`, `_dev`, `.claude`).
Výstupy `sonda_h15_main.json`, `sonda_h15_proto*.json`, `suite_*.txt`. Do repa, modelu ani `%APPDATA%` sa nič nezapisovalo.

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | `hardware_sets.rb` = **6 674 r. / 343,6 kB** (LF). **Dáta:** `SEED_VERSION` + história (r. 211–236) · `SEED_SETS` (448–814, **29 setov**) · `SEED_MAPPING` (818–829) · `LEGACY_SEED_SHAPES` (840–982, 12 tvarov) · `MAPPING_MIGRATIONS` (990–992) · `MAPPING_ADDITIONS` (1009–1043, 10 kľúčov) = **~625 r. / ~39 kB (11 %)**, z toho 134 r. doménových komentárov; zvyšok je logika | Grep, `wc` | PRAVDA → obrí súbor **logiky** ostane; H15 rieši dáta |
| S2 | **Produkty v `hardware_sets.rb` nie sú** — manifest je v `hardware_catalog.rb` (`SEED_ROWS` 146, `SEED_ROWS_V2` 60, zoznamy patchov v2–v5) = ~800 r. / ~51 kB = **41 % zo 125 kB**; taxonómia (`SEED_MANUFACTURERS` 7, `SEED_SERIES` 15) ~20 r. | Grep, sonda | PRAVDA → CX-03 ≠ GR-07 → rez H15a/H15b |
| S3 | Dáta setov odkazujú na mechaniku **raz**: `'code' => SKIP_CODE` (platnička 17–20); tri ďalšie bunky „bez kódu" sú už literál `'none'`. Dáta katalógu odkazujú len na vlastné dáta (`SEED_PATCH_V4_ADD = SEED_AVENTOS_V4`) | Grep | PRAVDA → dáta sa dajú načítať **pred** logikou |
| S4 | Pri načítaní sa zo seedu odvodzuje len `CLASS_MAPPING_KEYS` (sety) a `SEED_PRODUCT_LINKS`, `SEED_ITEMS`, `SEED_ITEMS_V2` (katalóg) | Grep, prototyp | PRAVDA → odvodeniny ostávajú v logike |
| S5 | **Seed sa číta aj za behu:** `HardwareSets.flap_set_codes` (SEED_SETS + snapshot) volá `Bom.collect` (`bom.rb:123`); `hardware_catalog_dialog.rb:586` číta `CLASS_MAPPING_KEYS` | Grep | PRAVDA → golden G6 |
| S6 | Konzumenti: Ruby mimo modulov len dialóg (S5); **JS žiadny**; testy: 20 súborov menom seed konštánt setov, 10 `SEED_VERSION`, 10 katalóg/taxonómia | Grep | PRAVDA → mená ostávajú, **žiadny test sa nemení** (S11) |
| S7 | **Merge porovnáva OBSAH, nie odtlačok:** `replace_untouched_seed_sets`/`legacy_seed_shape?` (`Hash ==` normalizovaných tvarov), `migrate_mapping`, katalóg `SEED_MATCH_FIELDS`. Odtlačky sú len nad **súbormi** (`HardwareSets.revision` = SHA1 bajtov — H10, `catalog_revision`). Poradie `SEED_SETS` = poradie setov v súbore, poradie `SEED_MAPPING`/`MAPPING_ADDITIONS` = poradie kľúčov mapovania | `hardware_sets.rb:1882–2067`, sonda | PRAVDA → strážiť poradie a bajty súborov (G2–G4) |
| S8 | **Zmrazenie:** zmrazený len obal (`.freeze`), vnútorné Hash/Array nie, reťazce áno (okrem 8 odvodených `product_url`). Celá sada (**5 160**) obsah žiadnej z 18 konštánt **nemení** (Marshal pred = po) a prejde aj s rekurzívne zmrazenými (**5 160 / 0**) | `sonda_h15_suite.rb`, `sonda_h15_str.rb` | PRAVDA → presun 1:1 bez rozhodovania o zmrazení |
| S9 | Čerstvá inštalácia je **deterministická** (2 sandboxy → `hardware_sets.json` 23 702 B, `hardware_catalog.json` 66 630 B, `hardware_taxonomy.json` 1 412 B zhodné); `JsonFileStore` píše binárne (LF) | `sonda_h15.rb`, `json_file_store.rb:211` | PRAVDA → golden plným textom (fixtúra s CRLF sa normalizuje) |
| S10 | **Prototyp H15a** (dáta pred logikou, `SKIP_CODE` → `'none'`): 32 odtlačkov konštánt, 3 čerstvé súbory, `seed_library`, `global_default_state`, 3 upgrade cesty, `flap_set_codes`, expand+CSV nad seedom, **5 nákupov + rozpočtov kovania** → **0 rozdielov** | `sonda_h15_proto.json` | PRAVDA |
| S11 | **Prototyp H15a+b:** 0 rozdielov; sada **5 155 zelených**, 4 červené + 1 preskočený = artefakty kópie bez `.claude/`. Bez dokumentácie padnú presne **3 strážcovia** (nadpis `### <modul>.rb`, token routra `ARCHITEKTURA.md`, cesta v §13) — po doplnení zelené | `suite_proto_a.txt`, `suite_proto_ab.txt` | PRAVDA |
| S12 | **Mapa H13 po presune prejde ticho:** holé `SEED_VERSION`/`LEGACY_SEED_SHAPES`/`SEED_SET_VERSION` logika ďalej používa; kvalifikované `HardwareSets::LEGACY_SEED_SHAPES` guard overí ako **deklaráciu** (seed `true`, logika `false`) | `sonda_h15_map.rb` | PRAVDA → mapu prepísať aktívne (R6) |
| S13 | Guard „len literály" cez `RubyVM::AbstractSyntaxTree` (CI Ruby 3.2): seed súbory **0 nálezov**, logika tisíce; `frozen_string_literal` → reťazec je `LIT` | `sonda_h15_ast.rb` | PRAVDA → R5 a |
| S14 | Načítanie: `main.rb` len `Sketchup.require` (aj pre .rbe), v `core/` žiadne `require_relative`; precedens rozdelenia `ui/panel.rb` → `ui/panel/actions_*.rb`; helper má vlastný zoznam (`tests/helper.rb:155–159`); inštalátor kopíruje celý priečinok, updater berie manifest stromu | `main.rb:448–488`, `INSTALL_noxun_engine.ps1:101`, `updater.rb:423` | PRAVDA → registrácia = `main.rb` + helper (+ docs) |
| S15 | Precedens JSON `data/recipes` = nemenné balíky so SHA-256 registrom a normalizáciou CRLF; encoding guard `.json` nekontroluje | `drawer_recipes.rb:22–31`, `encoding_guard.rb:38` | PRAVDA → vstup do D1 |
| S16 | H9 `write_gate` a H10a `rules_rev` sú v `hardware_rules.rb`; tri dotknuté súbory naposledy menila H3a (`611fd004`); testy H9/H10 v prototype zelené bez zmeny | `git log`, S11 | PRAVDA → `hardware_rules.rb` sa nemení |
| S17 | Goldeny seed nekryjú celý: `seed_kniznica` (`test_kovh_golden`) = len legacy `SEED_MAPPING` + pevný katalóg; `test_kova_golden` pripína generiká; H12 `insu.json` len v SketchUpe. KOVA prípady kupujú závesy (triedny kľúč), nohy+platničku, príchyt, zavesenie a legacy výsuv — **receptovú zásuvku ani výklop nie** | `sonda_h15_e2e.rb` | PRAVDA → G7 doplní 2 konfigurácie |

### 0.1 Mapa — čo je dáta a čo ostáva (main `108c808c`; veľkosti LF z prototypu)

| Súbor | Do `*_seed.rb` (dáta) | Ostáva (logika, odvodeniny, kontrakty) | Pred → po |
|---|---|---|---|
| `core/hardware_sets.rb` | `SEED_VERSION` + história v2–v8 · `SEED_SETS` · `SEED_MAPPING` · `LEGACY_SEED_SHAPES` · `MAPPING_MIGRATIONS` · `MAPPING_ADDITIONS` (s komentármi) | `CLASS_MAPPING_KEYS`, `SKIP_CODE`, `CLASS_OPTIONS`, `PARAM_OPTIONS`, `SYSTEM_IDENTITY`, `DRAWER_HEIGHT_VARIANTS`, `merge_seed` a spol., zámky, brány, `expand`, `purchase_csv` | 6 674 r. / 343,6 kB → **6 052 r. / 304,2 kB**; seed **640 r. / 40,2 kB** |
| `core/hardware_catalog.rb` | `SEED_SET_VERSION` + história · hlavička manifestu + `SEED_ROWS` · `SEED_PRICE_CHECKED_AT(_V4)` · `SEED_INACTIVE` · `SEED_AVENTOS_V4` · `SEED_PRODUCT_CODES` · `SEED_ROWS_V2` · `SEED_PATCH_V2_ADD` · `LEGACY_SEED_93240` · `SEED_PATCH_V3_ADD` · `SEED_PATCH_V4_ADD` · `SEED_PATCH_V5_ADD` · `SEED_PATCH_V5_CLASSIFY` | `SEED_PRODUCT_LINKS`, `SEED_ITEMS`, `SEED_ITEMS_V2` (odvodené), `SEED_MATCH_FIELDS` (kontrakt patchu v3), komentáre patchov pri metódach | 2 343 r. / 125,2 kB → **1 540 r. / 73,6 kB**; seed **825 r. / 52,3 kB** |
| `core/hardware_taxonomy.rb` | `SEED_VERSION` · komentár seedu v1–v3 + `SEED_MANUFACTURERS` · `SEED_SERIES` | `AXILO_*` (parametre migrácie `migrate_axilo_owner!`), whitelisty, API | 643 → **624 r.**; seed **31 r. / 1,6 kB** |

Dátová časť spolu **~1 500 riadkov / ~94 kB**.

---

## 1 · Cieľ

Predvolené kovanie — sety, mapovania a ich staré tvary, produktový manifest katalógu so zoznamami patchov, výrobcovia a rady — žije v **troch súboroch `*_seed.rb`,
ktoré obsahujú len literály**. Pridať či opraviť predvolený set, kód, cenu alebo radu = zmena v dátovom súbore + verzia seedu **v tom istom súbore** + vedomá
regenerácia goldenu; mechanika (seed-merge, „nedotknutý seed prepíš, upravený nechaj", migrácie, zámky, brány, expanzia, nákup) sa neotvára a ostáva **bez zmeny riadku**.
**Pre používateľa sa nemení nič.** Úprimne: logika `hardware_sets.rb` ostane ~6 050 riadkov a slovníky systémov zásuviek ostávajú v kóde (C-08 Po V1) — mapa ich vymenuje (D7).

## 2 · Rez a odhad — **dve časti, sekvenčne z čerstvého `main`, každá samostatný PR**

| Časť | Obsah | Kód pluginu | Testy | Odhad |
|---|---|---|---|---|
| **H15a · sety (GR-07)** | **T0 golden pre VŠETKY tri moduly** (1. commit, G1–G7) → `core/hardware_sets_seed.rb` → `main.rb` + helper → R5 (sety) → docs §11 | ~+640 / −625 (presun) + 1 r. `main.rb` | ~+500 + fixtúry ~120 kB | ¾–1 deň |
| **H15b · katalóg a taxonómia (zvyšok CX-03)** | `core/hardware_catalog_seed.rb` + `core/hardware_taxonomy_seed.rb` → `main.rb` + helper → R5 na 3 moduly → docs + scenár 6 (D7) | ~+860 / −830 (presun) + 2 r. `main.rb` | ~+80 | ½ dňa |

Každá časť sama dá bajtovo rovnaké výstupy; **T0 z 1. commitu H15a platí bez regenerácie aj po H15b** (zmena fixtúry = nález). ~3 000 riadkov presunu → dve časti,
nech recenzent overuje jednu doménu naraz. **Audit návrhu jeden pre celý package** (pred H15a).

## 3 · Scope IN

1. Tri dátové súbory v `noxun_engine/core/` (R1), ich načítanie (R3); v logike na mieste bloku ukazovateľ (R2).
2. Verzie seedu do dátových súborov + STANDARD §13 (R4).
3. Golden T0 (R0), guard „dáta nie sú v logike" (R5), mutácie (§7), mapa a dokumentácia (R6, §11).

## 4 · Scope OUT

- **Hodnoty, poradie, typy ani zmrazenie dát** (G1 ich pripína) — žiadne zoradenie, deduplikácia ani „upratanie" komentárov.
- **Algoritmy** seed-merge, migrácií, patchov katalógu a taxonómie; žiadny univerzálny migračný systém (CX-03).
- **JSON a iné dátové balíky** (D1), `require_relative`, nové API na čítanie seedu.
- Odvodeniny a kontrakty z tabuľky §0.1 (stĺpec „Ostáva").
- **`HardwareRules::SEED_RULES`** a jeho `LEGACY_SEED_SHAPES` (F1, Q1) — `hardware_rules.rb` sa nemení (S16).
- Existujúce testy — žiadny sa nemení (výnimka `NX_H13_SCENARIOS` pri D7).

## 5 · Trieda podľa CLAUDE.md

- **Výrobná/cenová: ÁNO (konzervatívne).** Výstup sa meniť nemá, ale presúva sa zdroj nákupných kódov a seed cien — chyba presunu zmení nákup a rozpočet bez hlášky.
  Dôkaz nemennosti: T0 G2–G7 (bajty súborov, CSV, rozpočet). Review podľa pravidiel výrobnej dávky (delta len po predrecenzii).
- **Audit-povinná: ÁNO** — tri nové moduly (router, odseky `hardware.md`) a nové poradie načítania. Schéma ani dátový kontrakt sa nemení (`STD`, `CONFIG_SCHEMA`, BuildPlan
  `SCHEMA` bez zmeny; mení sa **cesta** troch seed riadkov §13).
- **Predrecenzia: povinná** H15a aj H15b; recenzent dostane aj `git diff --color-moved=zebra main...HEAD`, aby videl presun ako presun.
- **In-SU: nie je brána** (žiadny builder, observer, undo, geometria ani akcia panela). Odporúčaný beh §8. **Nový ovládací prvok ani fotky: nie.**

### 5.1 Závislosti — overiť proti mainu pred každou časťou

- **H11a** (F-01, načítanie súborov s jednou hláškou): ak skôr zmení načítanie v `main.rb` (obal okolo `Sketchup.require`), nové riadky ho prevezmú a R5 d sa prispôsobí.
- **H16** (C-04 súpis knižníc): knižnice v `%APPDATA%` H15 nemení; ak H16 zmerguje skôr a menuje seed konštanty, prevezme nové súbory.
- Mapa H13 a STANDARD §13 sa menia v H15 (R4, R6) — kolízia len textová. `hardware_rules.rb` (H9/H10a) sa nemení.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit H15a, bez zmeny pluginu)

- **R0.1 Harness** `tests/pure/test_h15_seed_golden.rb` (`NxH15Golden`) + generátor `tests/fixtures/h15_golden/generate.rb` (spúšťa sa **ručne**, test ho nevolá — vzor
  `kovh_golden/generate.rb`). Každý scenár vo **vlastnom sandboxe** (vzor `NxR11.with_sandbox`: `Materials.test_dir_override` + `JsonFileStore.invalidate` +
  `reset_library_state!`/`reset_state!` troch modulov). Text sa porovnáva po normalizácii CRLF→LF. Hláška menuje scenár a konštantu/set/kód.
- **G1 konštanty:** `HardwareSets::` `SEED_VERSION SEED_SETS SEED_MAPPING LEGACY_SEED_SHAPES MAPPING_MIGRATIONS MAPPING_ADDITIONS CLASS_MAPPING_KEYS SKIP_CODE` ·
  `HardwareCatalog::` `SEED_SET_VERSION SEED_ROWS SEED_ITEMS SEED_ROWS_V2 SEED_ITEMS_V2 SEED_PRODUCT_LINKS SEED_INACTIVE SEED_AVENTOS_V4 SEED_PRODUCT_CODES SEED_PATCH_V2_ADD
  LEGACY_SEED_93240 SEED_PATCH_V3_ADD SEED_PATCH_V4_ADD SEED_PATCH_V5_ADD SEED_PATCH_V5_CLASSIFY SEED_PRICE_CHECKED_AT SEED_PRICE_CHECKED_AT_V4 SEED_MATCH_FIELDS` ·
  `HardwareTaxonomy::` `SEED_VERSION SEED_MANUFACTURERS SEED_SERIES AXILO_SERIES AXILO_LEGACY_OWNER AXILO_OWNER` → trieda, veľkosť, `frozen?` obalu a prvého vnútorného
  prvku, **počet nezmrazených reťazcov v hĺbke** (dnes 0, okrem 8 v `SEED_ITEMS` a `SEED_PRODUCT_LINKS`), SHA-256 `inspect` (typy, poradie kľúčov, Float vs Integer) a SHA-256 JSON.
- **G2 čerstvá inštalácia:** plný text troch súborov po `HardwareSets.load` + `HardwareCatalog.items` v prázdnom sandboxe; JSON `seed_library` a `global_default_state`.
- **G3 upgrade setov** — stav knižnice, SHA-256 súboru, `set_id` v poradí, celé mapovanie a plné definície setov odlišných od čerstvého seedu: `v1` (staré závesy, klzák,
  legacy výsuv) · `v4` (pred D-118b: antracit `348777`, Tip-On bez PTOs, starý názov výsuvu) · `v7` nedotknuté nohy (nahradia sa) · `v7` premenované nohy (ruky preč) ·
  migrácia `leg` `nohy-klzak-17` → `nohy-podla-sokla` · **kolízia** (vlastný `prichyt-sokla-axilo` typu `hinge` ostáva, `plinth_clip` sa nedoplní) · **vlastná hodnota**
  `class:slide|classic|metal` (neprepíše sa) · **konflikt taxonómie** (AXILO pod vlastným výrobcom → seed set nezaradený) · aktuálna `seed_version` 8 (nič sa nezapíše).
- **G4 upgrade katalógu a taxonómie** — stav, SHA-256, kódy v poradí, plné položky odlišné od čerstvého seedu: katalóg `v1` (starý 93240) · `v2` (60 riadkov + vlastná cena,
  vlastná `demos_url`, zmazaná seed položka, vypnutá aktivita) · `v4` (bez nôh) · `v5` (bez enrichmentu 367823); taxonómia `v2` (AXILO pod Hettichom) a cudzí vlastník AXILO.
  Vzory: `NxD118.install_v2!` (`test_d118_katalog_seed.rb`), `test_kovb2_katalog.rb`, `test_kovg1a_nohy_data.rb`.
- **G5 projekt:** `merge_project_sets_seed!` nad minimálnym modelom so slovníkom atribútov (vzor `NxD118b::Model`) so snapshotom `v4` (jeden set nedotknutý, jeden upravený)
  → snapshot + status; `class_set_options` pre každý `CLASS_MAPPING_KEYS` nad čerstvou knižnicou (ponuka Pravidiel vrátane rodín Atira biela/antracit).
- **G6 behové:** `flap_set_codes(nil)` (S5).
- **G7 nákup a rozpočet end-to-end** nad čerstvou inštaláciou (sety + katalóg zo súborov G2): KOVA `door_2wings`, `drawer_fixed_locked`, `upper_cabinet`, `auto_w599`,
  `mix_fixed_auto` **+ zásuvka z receptu Atira** (vzor `cfg` v `test_kovc2b_dielce.rb`) **+ výklop HK a HL top** (vzor `cfg` v `test_kove1b_pravidlo.rb`) → surový
  `purchase_csv(exp, project: 'H15', generated_at: '2026-10-01')`, JSON `expand` a sekcia `hardware` z `Budget.compute({ rows: [], edging: [] }, {}, SupplierSettings.seed_supplier,
  hardware_expansion: exp, hardware_catalog: items, now: Time.utc(2026, 10, 1))`. Konfigurácie receptu a výklopu sú **NEOVERENÉ** — implementátor overí, že expanzia
  ide cez triedny kľúč (`class:slide|…|metal`, `class:lift|…`) a nie je prázdna.
- **R0.2** Fixtúry, harness a test idú **v 1. commite spolu**, zelené na starom kóde; generátor sa potom v H15a ani H15b **nespúšťa**.

### R1 · Dátové súbory

- **R1.1** `noxun_engine/core/hardware_sets_seed.rb` (H15a), `hardware_catalog_seed.rb` a `hardware_taxonomy_seed.rb` (H15b); UTF-8 bez BOM, konce riadkov ako repo,
  **`# frozen_string_literal: true` povinne** (G1). Hlavička: len dáta, načíta sa pred logikou, neodkazuje na jej konštanty; zmena seedu = verzia + starý tvar + vedomá regenerácia T0.
- **R1.2 Tvar:** `module Noxun` → `module Engine` → `module <HardwareSets|HardwareCatalog|HardwareTaxonomy>` (odsadenie ako v logike — `nx_h13_scope`) a v ňom **len
  deklarácie konštánt** s literálmi (reťazec, číslo, `nil/true/false`, pole, hash, `%w[]`), `.freeze` a odkaz na konštantu deklarovanú **vyššie v tom istom súbore**.
- **R1.3 Presun 1:1:** bloky §0.1 **doslovne vrátane komentárov a poradia**. **Jediná zmena v dátach:** `'code' => SKIP_CODE` → `'code' => 'none'` s komentárom
  „= `HardwareSets::SKIP_CODE`" (rovnaká hodnota, ten istý zmrazený objekt — S3, G1).

### R2 · Logické súbory

Na mieste každého bloku 1–2 riadky „H15: … je v `<modul>_seed.rb`". **Žiadna metóda sa nemení** — diff logických súborov = zmazané riadky + ukazovatele (T5).

### R3 · Načítanie

`main.rb`: `Sketchup.require 'noxun_engine/core/<modul>_seed'` **tesne pred** `<modul>` s komentárom; `tests/helper.rb`: `core/<modul>_seed` tesne pred `core/<modul>`.
Žiadne `require_relative` (S14). Ak H11a zaviedla obal načítania, použije sa (§5.1).

### R4 · Verzie a STANDARD §13

`SEED_VERSION`/`SEED_SET_VERSION` idú s komentárom histórie do seed súborov (D2), hodnoty bez zmeny. §13.1: tri riadky „seed" dostanú novú cestu; riadok setov v „Kedy
zvýšiť" doplní „(starý tvar do `LEGACY_SEED_SHAPES` v tom istom súbore)". Guard H13 B-07 overí hodnotu aj úplnosť (S11).

### R5 · Guard „dáta nie sú v logike" (`tests/pure/test_h15_seed_data.rb`; H15a sety, H15b tri moduly)

- **a) Dátový súbor = len literály** (AST): uzly `SCOPE BLOCK MODULE COLON2 CDECL LIST ZLIST HASH STR LIT NIL TRUE FALSE CONST BEGIN`, `CALL` len `.freeze` bez argumentov,
  `LIT` len String/Integer/Float, `CONST` v hodnote len meno deklarované vyššie v súbore; pre Ruby 3.3+ aj `INTEGER FLOAT`; bez AST `NxTest.skip!` (vzor `test_guards.rb:239`).
- **b)** Presunuté konštanty sú v plugine deklarované **práve raz**, vo svojom seed súbore.
- **c)** `hardware_sets.rb`, `hardware_catalog.rb`, `hardware_taxonomy.rb` nedeklarujú `SEED_*` ani `LEGACY_SEED_*` okrem allowlistu s dôvodom: `HardwareCatalog::SEED_PRODUCT_LINKS`,
  `SEED_ITEMS`, `SEED_ITEMS_V2` (odvodené pri načítaní), `SEED_MATCH_FIELDS` (kontrakt porovnania patchu v3).
- **d)** V `main.rb` aj helperi je každý seed súbor práve raz a **tesne pred** svojím logickým súborom; súbor existuje.
- **e)** Seed súbor otvára len svoj modul (jediný `module` okrem `Noxun`/`Engine`).
- Negatívne testy nad **syntetickými** zdrojmi (vzor H13): `def` v dátach, volanie `map`, odkaz na `SKIP_CODE`, nový `SEED_X =` v logike, zlé poradie v `main.rb`.

### R6 · Mapa rozširovacích bodov

- `rozsirovacie-body.md`, scenár 5: riadok `hardware_sets.rb` → `noxun_engine/core/hardware_sets_seed.rb` s **kvalifikovanými** menami `HardwareSets::SEED_SETS` ·
  `HardwareSets::LEGACY_SEED_SHAPES` · `HardwareSets::SEED_VERSION` · `HardwareSets::MAPPING_ADDITIONS` (H15a); riadok katalógu → `hardware_catalog_seed.rb` ·
  `HardwareCatalog::SEED_ROWS` · `HardwareCatalog::SEED_SET_VERSION` (H15b). Kvalifikované mená guard overí ako deklaráciu (S12).
- **D7 (H15b): scenár „6 · Nový set alebo systém kovania"** — dátové súbory (sety, mapovania, staré tvary, katalóg, taxonómia, verzie) + slovníky, ktoré dnes treba doplniť
  v kóde: `HardwareSets::SYSTEM_IDENTITY`, `HardwareSets::DRAWER_HEIGHT_VARIANTS`, `Recipes::SYSTEMS`, `Recipes::CONSTRUCTION_TO_SYSTEM`, `Fronts::DRAWER_SYSTEMS`,
  `Validation::SYSTEM_LABELS_SK`, `data/recipes/RELEASED.json` (veta: zjednotenie je C-08 Po V1). `NX_H13_SCENARIOS` a `NX_H13_REQUIRED` v `test_h13_rozsirovacie_body.rb`
  doplniť o scenár 6 (`HardwareSets::SEED_SETS`, `HardwareSets::SYSTEM_IDENTITY`, `HardwareCatalog::SEED_ROWS`).

## 7 · Testy a DoD

- **T0 · Golden PRED zásahom** (R0): zelený na starom kóde v 1. commite H15a, **bez regenerácie** v H15a ani H15b.
- **T1 · Guard R5 a–e** + negatívne testy.
- **T2 · Existujúce testy bez zmeny** — najmä `test_kovh_golden`, `test_kova_golden`, `test_h12_golden`, `test_d118b_sety`, `test_kovd1c_antracit` (surový literál), `test_kovc2a_kanal_sety`
  (úplnosť radov), `test_kove1a_data`, `test_h1a_sety`, `test_d118_katalog_seed`, `test_hardware_catalog`, `test_kovb1_taxonomia`, `test_r37_tvar_suborov`, `test_h10a_globalne_pravidla`,
  `test_r08_zamky`, `test_r11_degradovana_zaloha`, `test_guards` (DupDefs nad znovuotvoreným modulom), `test_incompatible_detail_sk` (AST logiky).
- **T3 · Mutácie** — každá má test, ktorý ju zhodí; PR priloží beh každej (mutácia, ktorú nič nezhodí = doplniť test):

| M | Mutácia | Zhodí |
|---|---|---|
| M1 | prehodené dva sety v `SEED_SETS` | G1, G2 (poradie) |
| M2 | `'357696'` → `'357697'` v legacy výsuve | G1, G2, G7 (CSV) |
| M3 | `17.0` → `17` v pásme nôh | G1 — G2 nie: normalizácia urobí Float a súbor je rovnaký (`sonda_h15_m3.rb`) |
| M4 | zmazaný `.freeze` pri `SEED_SETS` | G1 (zmrazenie obalu) |
| M5 | chýba `# frozen_string_literal: true` v seed súbore | G1 (nezmrazené reťazce) |
| M6 | zmazaný starý tvar `nohy-podla-sokla` z `LEGACY_SEED_SHAPES` | G1, G3 (nohy sa nenahradia) |
| M7 | prehodené kľúče `MAPPING_ADDITIONS` | G1, G2 (poradie mapovania) |
| M8 | `SEED_VERSION = 9` | G1, G2, H13 B-07 |
| M9 | seed súbor v `main.rb` alebo helperi **za** logikou | R5 d (helper: `NameError` pri načítaní) |
| M10 | v dátach ostane `SKIP_CODE` | R5 a; dáta-prvé = `NameError` |
| M11 | do seed súboru sa presunie `SEED_ITEMS = SEED_ROWS.map …` | R5 a |
| M12 | nový `SEED_X = …` v `hardware_sets.rb` | R5 c |
| M13 | `SEED_SET_VERSION` v oboch súboroch | R5 b, H13 B-07 |
| M14 | zo `SEED_INACTIVE` vypadne kód | G1, G2 (katalóg) |
| M15 | prehodené dve rady v `SEED_SERIES` | G1, G2 (taxonómia) |
| M16 | §13 ostane na starej ceste / chýba `### <modul>_seed.rb` | H13 B-07, `test_docs_navigacia` (S11) |
| M17 | `flap_set_codes` číta prázdne pole namiesto `SEED_SETS` | G6 |

- **T4:** `ruby tests/run_all.rb` + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + `ruby scripts/encoding_guard.rb --repo`.
- **T5 · Dôkaz presunu:** PR uvedie `git diff --stat` a zhrnie `git diff --color-moved=zebra --color-moved-ws=allow-indentation-change main...HEAD -- noxun_engine/core`:
  „v logike len zmazané riadky + N ukazovateľov; v dátach len presunuté riadky + hlavička a obal modulu + 1 zmena `SKIP_CODE`".
- **DoD každej časti:** T0 bez zmeny fixtúr · T1–T5 zelené · mutácie v PR · dokumentácia §11 · PR s „Predrecenziou" a vetou „bez zmeny výstupov — golden fixtúry nedotknuté".

## 8 · In-SU — nie je brána, odporúčaný jeden beh pri H15a

Jediné riziko, ktoré headless sada nevidí, je **`Sketchup.require` nového súboru v SketchUpe** (helper má vlastný zoznam). Preto odporúčaný `scripts\run_su_tests.ps1
-CloseWhenDone` na finálnej hlave H15a: overí načítanie pluginu a `run_h12` porovná nákup, rozpočet a kusovník 6 skriniek bajtovo s `insu.json`. H15b pridáva dva
súbory tým istým vzorom — beh netreba. Bez runnera PR to prizná; po mergi orchestrátor pri inštalácii mainu overí štart pluginu a Štúdio → Kovanie.

## 9 · Riziká

- **Tichá zmena dát pri presune** (preklep, vypadnutý riadok, poradie) → G1–G7, M1–M8. **Poradie načítania** → R5 d, M9, §8.
- **Rozmrazenie** — dnes nikto dáta nemení (S8), presun však nemá meniť správanie → G1, M4–M5.
- **Mapa a §13 zastarajú ticho** (S12) → R6 s kvalifikovanými menami; §13 stráži guard. **Kolízia s H11a** → §5.1.
- **Čiastočné načítanie** (dáta sa načítajú, logika spadne) → `defined?(HardwareSets)` je `true` bez metód — tá istá trieda rizika ako dnes pri páde v strede súboru; rieši H11a.
- **Zmiešané PC (Lucia):** `%APPDATA%` ani zákazky sa nemenia → bez rizika.

## 10 · Smoke checklist pre Michala (po H15b)

1. Štúdio → **Kovanie (sety)**: rovnaké sety (Atira biela/antracit, výklopy HK/HL, nohy podľa sokla, príchyt sokla).
2. Štúdio → **Pravidlá**: zásuvky ponúkajú Atiru bielu aj antracit, závesy klasik a Tip-On — predvoľby ako predtým.
3. Rozpracovaná zákazka: **Nákup kovania** a **Rozpočet → Kovanie** — rovnaké kódy, počty, ceny a súčet.
4. **Katalóg kovania**: strom výrobcov (Häfele → AXILO, Hettich, Blum…) a ceny ako predtým.
5. Nová skrinka so zásuvkou a výklopom: kovanie sa naplní ako doteraz (žiadny červený „chýba kit").

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch `VERSION` (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** → T0–T5 → **architektúra na mieste:** `hardware.md` nové odseky **`### hardware_sets_seed.rb`**
(H15a), **`### hardware_catalog_seed.rb`** a **`### hardware_taxonomy_seed.rb`** (H15b) — čo tam žije, „len literály", poradie načítania, ako sa seed mení, guard R5; v odsekoch
`hardware_sets.rb`/`hardware_catalog.rb`/`hardware_taxonomy.rb` jedna veta, kde sú dáta (história seedu ostáva), a oprava vety „`LEGACY_SEED_SHAPES` v `hardware_sets.rb`"
(odsek taxonómie, F5) · router `docs/ARCHITEKTURA.md` · STANDARD §13 (R4) · mapa (R6, D7) → **Grep** tvrdení „seed je v `hardware_sets.rb`" v `docs/` a `SYSTEM/` →
**prepis STAV** → **KRONIKA** navrch → **PLAN** riadok H15 s časťami (✅ + PR) → package + surový audit do `SYSTEM/zdroje/bloky/HARDENING/` → **PR popis:** „bez zmeny
výstupov", trieda, Predrecenzia, mutácie, T5, in-SU (§8). Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Ruby dátové moduly `*_seed.rb`, nie JSON** | presun 1:1 bez transformácie (literály, typy, poradie, zmrazenie — S8, S10); 186 riadkov doménových komentárov ostáva pri dátach (JSON ich nemá); encoding guard a hook `ruby -c` kryjú `.rb`, `.json` nie (S15); žiadna nová IO cesta ani zlyhanie čítania pri štarte; konvencia `Sketchup.require` (.rbe). Konzument mimo Ruby neexistuje (S6). JSON precedens `data/recipes` má iný účel (nemenné balíky so SHA registrom) | **áno** |
| D2 | **Verzia seedu ide s dátami** (`SEED_VERSION`, `SEED_SET_VERSION` + história) | zmena seedu = jeden súbor (dáta + starý tvar + verzia); §13 sa prepíše, guard to vynúti (S11). Alternatíva: verzia v logike — každá zmena seedu otvára dva súbory | **áno** |
| D3 | **Dáta sa načítajú PRED logikou**, `SKIP_CODE` → `'none'` (1×) | dáta nezávisia od mechaniky (S3, R5 a), odvodeniny (S4) sa nepresúvajú; tri bunky už `'none'` majú. Alternatíva: dáta po logike — 100 % doslovné, ale `CLASS_MAPPING_KEYS` by šiel do dát a dáta by záviseli od logiky | **áno** |
| D4 | Odvodeniny a `SEED_MATCH_FIELDS` ostávajú v logike | transformácie a pravidlá, nie dáta; R5 c ich allowlistuje s dôvodom | nie |
| D5 | Taxonómia má vlastný 31-riadkový seed súbor | jednotný vzor „seed modulu kovania = `<modul>_seed.rb`" drží R5 jednoduchý; `AXILO_*` ostávajú pri migrácii | krátko |
| D6 | Rez H15a (sety + T0 všetkých troch) → H15b; audit jeden na package | ~3 000 riadkov presunu; každá časť bajtovo rovnaká; T0 platí cez obe | **áno** |
| D7 | Scenár 6 mapy „Nový set alebo systém kovania" v H15b | cieľ C-03 (lacnejšia nová značka); mapa poctivo vymenuje aj slovníky, ktoré ostávajú v kóde (C-08); ~40 r. docs + 1 r. testu | **áno** |
| D8 | In-SU odporúčaný 1× pri H15a, nie brána | spúšťače sa nemenia; nové riziko je len `Sketchup.require` (§8) | krátko |
| D9 | Bez rekurzívneho zmrazenia | presun nemení správanie; sonda ukázala, že by nič nerozbilo (S8) — samostatná drobnosť, ak vôbec | nie |

## 13 · Otázky pre Michala (produktové; do odpovede platí návrh)

- **Q1 · Predvolené pravidlá kovania tým istým vzorom?** Vlastné predvolené dáta majú aj „Pravidlá kovania" (koľko závesov, nôh a príchytov podľa rozmerov, ~210 riadkov).
  **Návrh:** teraz nie — súbor pravidiel práve prešiel ochranou dvoch okien (H9/H10a); H15 ostáva pri setoch, katalógu a výrobcoch, pravidlá do zásobníka Po V1. Ak chceš, pridá sa H15c.

## 14 · Nálezy mimo scope

- **F1** `HardwareRules::SEED_RULES` + jeho `LEGACY_SEED_SHAPES` (~210 r.) — kandidát na rovnaký vzor (Q1); mapa H13 ho menuje v scenároch 1 a 5.
- **F2** Slovník systémov zásuviek je na **6 miestach v 5 súboroch** (`Recipes::SYSTEMS`, `Recipes::CONSTRUCTION_TO_SYSTEM` — `metal` → `atira` napevno, `Fronts::DRAWER_SYSTEMS`,
  `HardwareSets::SYSTEM_IDENTITY`, `Validation::SYSTEM_LABELS_SK`, menovka v `drawer_recipes.rb`) — nová kovová značka ich musí doplniť všetky; zjednotenie = **C-08 Po V1** (D7 ich vymenuje).
- **F3** Predpoklad zadania „produkty sú v `hardware_sets.rb`" neplatí — sú v `hardware_catalog.rb` (S2); pokrýva H15b.
- **F4** Golden `seed_kniznica` pokrýva len legacy `SEED_MAPPING`; triedne mapovania, katalóg a rozpočet kryje až T0 (S17).
- **F5** `hardware.md` (odsek taxonómie) odkazuje na „`LEGACY_SEED_SHAPES` v `hardware_sets.rb`" — po H15a zastará; opraví §11.

---

## 15 · Audit návrhu (audítor audit-povinných, 1.10.2026) — 0 BLOCKER · 2 FIX · 1 NOTE → zapracovanie orchestrátorom (2.10.2026) · MÁ PREDNOSŤ

Surový výstup `AUDIT_H15_raw.md` (implementátor H15a ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package). Audit uzavretý (FIX zapracované, koncept bez zmeny).

- **A1 (H15a, k R0 G7) — golden nákupu nesmie pripnúť neúplný nákup.** Podmienky „triedny kľúč + neprázdna expanzia" nestačia: výklop HK bez hmotnosti čela
  vydá len príslušenstvo (`13781`, `347834`) bez mechanizmu, s `lift_class_missing` a `lift_set_incomplete`, a podmienky by splnil. **Pred generovaním T0:**
  každá konfigurácia G7 dostane **explicitné materiály** (`materials:` ako `test_kove1b_pravidlo.rb` — hmotnosť čela sa bez nich nedopočíta,
  `construction.rb` výpočet hmotnosti), a harness pred zápisom fixtúry **overí a test potom drží**: (1) v riadkoch je očakávaný **mechanizmus/kit**
  (zásuvka Atira = kit výsuvu; HK = mechanizmus; **HL = mechanizmus + ramená + požadované tyče**), (2) **žiadny** blokujúci konflikt
  (`*_missing`, `*_incomplete`, nemapovaný triedny kľúč) a (3) žiadna chýbajúca katalógová položka. Nesplnená podmienka = harness odmietne zapísať golden
  (nie tichá fixtúra). Mutácia navyše: odober materiály z HK konfigurácie → test G7 padne.
- **A2 (H15b, k R5 c) — allowlist nesmie dovoliť vrátiť produktové dáta do logiky.** Výnimky `HardwareCatalog::SEED_ITEMS`, `SEED_ITEMS_V2`,
  `SEED_PRODUCT_LINKS` ostávajú v logike len ako **odvodeniny**: guard (AST) overí, že výraz hodnoty každej z nich **odkazuje na príslušnú seed konštantu
  z `hardware_catalog_seed.rb`** a neobsahuje String/Integer/Float literál produktu (kód, cenu, názov). Negatívny test nad syntetickým zdrojom: nahradenie
  odvodenia ekvivalentným literálom (napr. pole hashov s kódom a cenou) **musí guard zhodiť**, aj keď golden ostane rovnaký. `SEED_MATCH_FIELDS` ostáva
  allowlistovaný ako kontrakt porovnania (zoznam mien polí, nie produktové dáta).
- **A3 (NOTE):** audítor simuloval presun v pamäti na `108c808c` — 120 konštánt (poradie, rekurzívne zmrazenie), merge starých aj upravených setov a 7 nákupných
  goldenov vrátane surového CSV bez zmeny; merge porovnáva obsah (`hardware_sets.rb` seed-merge). Trieda **audit áno / výrobná-cenová áno / in-SU odporúčaný** potvrdená.

**Potvrdenie orchestrátora k §12 (2.10.2026):** D1 áno (Ruby `*_seed.rb`, nie JSON) · D2 áno (verzia seedu s dátami) · D3 áno (dáta pred logikou, `SKIP_CODE` → `'none'`)
· D6 áno (rez H15a → H15b, každá samostatný PR z čerstvého mainu, T0 z 1. commitu H15a platí bez regenerácie cez obe) · D7 áno (scenár 6 mapy v H15b) · D5, D8 áno.
**Q1 (predvolené pravidlá kovania tým istým vzorom):** Michal neodpovedal → platí návrh **nie** (zásobník Po V1, F1). **H11a** ide v bloku pred H15 — ak zmení
načítanie v `main.rb`, implementátor H15a prevezme jeho tvar (§5.1).
