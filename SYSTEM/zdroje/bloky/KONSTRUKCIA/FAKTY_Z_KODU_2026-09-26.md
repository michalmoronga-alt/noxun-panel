# K1 + K2 — fakty z kódu pred debatou a krížovým auditom

- **Dátum:** 26.9.2026 · **repo:** `C:\APP DEV\RUBY\ENGINE` · **vetva:** `main` · **HEAD:** `0f468e545be5d77c612048ba47ba29842bd8b5f9` (plugin v0.13.0)
- **Charakter:** READ-ONLY FAKTY, NIE NÁVRH. Nič v repe sa nemenilo. Čo nie je overené čítaním kódu, je označené **NEOVERENÉ**.
- **Zadanie bloku:** `SYSTEM/zdroje/next_sessions/V1_DEBATA_2026-09-05_KONSTRUKCIA.md` §1 (K1, r. 25–37) a §2 (K2, r. 39–46); starší koncept `SYSTEM/zdroje/next_sessions/07_KONSTRUKCIA_V1.md` (A/B, r. 20–111). Všetky cesty v súbore sú relatívne ku koreňu repa; `súbor:riadok` = stav na HEAD vyššie.
- **Prečítané:** `CLAUDE.md`, `docs/ARCHITEKTURA.md`, `docs/architecture/construction.md` (celé), `model-a-identita.md` (časti), `SYSTEM/STANDARD.md` §2.3–2.5, §3, §4, §7.2, §7.5, §8, §9, §10, `VEPO_KONTRAKT.md`, `UI_DIZAJN.md` §1, `PLAN.md` (K1–K3, trvalé UI pravidlo) + kód nižšie.

**Kľúčové zistenia v skratke:** (1) odsadenie ani chrbát z líšt dnes v kóde neexistuje v žiadnej podobe — polia treba pridať do ~8 uzavretých whitelistov naraz; (2) jediná autorita vnútornej hĺbky je `Construction.interior_dims[:back_front_y]` a číta ju 10+ konzumentov vrátane výberu NL výsuvu a kontroly niky spotrebičov — komín ich zmení všetky naraz (výrobná zmena); (3) ABS pravidlá sú **per rola**, takže horná a dolná lišta s rôznou viditeľnou hranou potrebujú dve roly alebo inú mapu hrán — a to ovplyvní aj agregáciu kusovníka; (4) náhľad Inspectora je len čelný pohľad, hĺbkové veci (komín, zapustenie, lišty vzadu) v ňom dnes nie je kde nakresliť; (5) názvy „K1/K2" už v teste nesú iné funkcie (smer dekoru/kresby).

---

## 1 · Config korpusu — dnešné konštrukčné polia

**Žiadne pole odsadenia, komína, zapustenia ani chrbta z líšt dnes neexistuje.** Grep identifikátorov `*offset*|*recess*|*setback*` v `construction.rb` a `cabinet_builder.rb` nájde len `rails_top_offset` (D-80), `plinth_recess` (sokel), konštantu `GROOVE_OFFSET` (10 mm), `mount_offset` (výška osadenia chladničky) a `bottom_offset` receptu zásuvky — nič z toho neposúva dno, strop ani chrbát v hĺbke (debata to konštatuje v r. 27–28). Chrbát má 4 režimy, vrch 3, dno 2.

| Pole | Default dolná / horná / slot | Povolené, clamp | `normalize` | Pozn. |
|---|---|---|---|---|
| `type` | `lower` / `upper` / `dishwasher` | `TYPES` (cabinet_builder.rb:52); neznámy → `lower` (3918–3921) | 2948 | typ „vysoká" **neexistuje** (grep `tall` = 0) — vysoká = `lower` s väčšou výškou |
| `width` | 600 / 600 / 600 | 200–3000 (slot 300–1200) | 2949–2950 | `MIN` 308 |
| `height` | 720 / 720 / 880 (výška linky) | 80–3000 (slot 500–1200) | 2951–2952 | S1-E0 schéma 15 |
| `depth` | **510** / **320** / 560 | 150–2000 | 2953 | **CELKOVÁ hĺbka vrátane chrbta** (D-37, construction.rb:1236–1241) |
| `thickness` | 18 | 6–50 (`THICKNESS_RANGE` 311) | 2954 | hrúbka korpusu = bokov, dna, vrchu, výstuh, políc |
| `floor_height` | 100 / **0 vynútené** / 0 vynútené | 0–500 | 2958 | výška sokla/nôh (D-79 nohy podľa nej) |
| `bottom_mode` | `under_sides` / `between_sides` / – | `between_sides · under_sides` | 2959 | |
| `top_mode` | `full` | `full · two_rails · none` | 2960 | UI „Strop" |
| `back_mode` | `overlay` / `groove` / `none` (slot ho ignoruje) | `overlay · inset · groove · none` (D-31) | 2961 | neznáma hodnota → default typu (`enum_val` 3923–3926) |
| `back_thickness` | 3.0 | 1–50 | 2963 | ≤0 → 3.0 (`Construction.back_thickness` 1378–1381); UI select len **3 / 18** (panel.html:500–503) |
| `plinth_mode` | `none` / vynútené `none` | `none · front` | 2964 | |
| `plinth_recess` | 40 | 0–300 | 2965 | `config_to_params` fallback **50.0** (3799) — legacy odchýlka od defaultu |
| `rail_depth` | 100 | 20–400 | 2967 | D-80, len pri `two_rails` |
| `rails_orientation` | `flat` | `flat · upright` | 2968 | D-80 |
| `rails_top_offset` | 0 | 0–500 | 2969 | D-80 (zníženie pod varnú dosku) |

Defaulty: `LOWER_DEFAULTS` 13–19, `UPPER_DEFAULTS` 23–29, `DISHWASHER_DEFAULTS` 41–48 (cabinet_builder.rb). JS ich dostáva zo servera ako `DEFAULTS` (form.js:186–199 komentár, `setDefaults` 618–621).
Odvodené vnorené objekty v `cabinet_config` (2769–2775): `sides {construction: 'sides_wrap'}`, `bottom {mode}`, `top {mode, rail_depth, orientation, top_offset}`, `back {mode, thickness}`, `support` (`support_descriptor` 2822–2828 nad `Construction.support_type` 1199–1203). `construction_preset` (2812–2818) je len informačný reťazec (`noxun-lower-18` / `noxun-upper-18` / `noxun-dishwasher`).
**Výstuhy v interiéri (D-80)** = `top_mode two_rails` + tri polia vyššie + `Construction.rail_geometry` (1263–1280). **Sokel/nohy (D-79)** = `floor_height` + `plinth_mode` + `support_type`; kód nôh vyberá set pásmami podľa výšky sokla (kovanie, nie config).

**Uzavreté whitelisty, cez ktoré musí prejsť KAŽDÉ nové konštrukčné pole** (chýbajúce miesto = tichá strata pri prestavbe; precedens GH #126 P1, D-13):
1. `CabinetBuilder.normalize` (2935–3007) — čo tu nie je, zo vstupu nevznikne.
2. `CabinetBuilder.cabinet_config` (2730–2808) — jediný zápis configu na entitu (`write_cabinet_attrs` 2719–2728).
3. `CabinetBuilder.config_to_params` (3789–3843) — **18 volaní** v 11 súboroch (prestavba, absorpcia scale, kópia nástrojom, „Nahradiť UNI", pravidlá…); fallback pre legacy config bez kľúča.
4. `Panel::PARAM_KEYS` (actions_cabinet.rb:15–18) — apply whitelist (`handle_apply` 757–760, `handle_apply_all` 866–868).
5. JS `CONSTRUCTION_FIELDS` (core.js:1599–1612) — zber formulára (`collectConstruction` form.js:4–17) aj zápis šablóny do formulára (`writeConstruction` core.js:1615, `materializeInsertCard` form.js:1057–1101). Komentár core.js:1597 a actions_cabinet.rb:8–9 výslovne: „nové pole = pridať TU + HTML + PARAM_KEYS".
6. `Panel.template_config_from` (payloads.rb:2300–2343) — šablóna je vlastný whitelist.
7. `TemplatesDialog.merge_template` (templates_dialog.rb:526–569) — aplikovanie šablóny na existujúcu skrinku.
8. JS zrkadlá výpočtu: `nxCarcassDepth`/`nxRailGeom`/`nxInteriorZ` (core.js:1534–1593) a **druhá, samostatná kópia vzorca hĺbky** v `updateAvailable` (form.js:561–573); `LIMITS` (form.js:149–157).
Guard parity existuje len pre polia slotu (`tests/pure/test_s1e_slot.rb:624` PARAM_KEYS ↔ CONSTRUCTION_FIELDS).

**`CONFIG_SCHEMA` = 18** (cabinet_builder.rb:271; história 99–270, posledné: 16 = S1-E slot, 17 = D-139, 18 = D-140 `mount_offset`).
- **Zápis markera:** výhradne `cabinet_config` (2738), vždy aktuálna hodnota, nikdy z params. Config-only zápisy (`write_config_keys!`) marker **nemenia** (construction.md:507–512; `older_config?` 3202–3204).
- **Dopredný guard R-12:** `guard_newer_config!` (808–813) číta RAW uložený config; `newer_config?` je **ostro väčšie** (842–844); chýbajúci/nečitateľný marker = 0 = legacy, prechádza (`config_schema_of` 828–838). Odmieta prestavbu, použitie a vklad šablóny (templates_dialog.rb:390–395, actions_cabinet.rb:481), „Vložiť kópiu", kópiu nástrojom, „Uložiť ako šablónu"; `dedup_copies` novšiu kópiu preskočí (construction.md:231–234).
- **Exportná brána:** `Bom.collect → newer_configs → ProductionCore.newer_config_stop` (production_core.rb:1161–1177) — beží vo **všetkých štyroch** exportoch vrátane VEPO (komentár 1785–1790).
- **Migrácie pri bumpe:** žiadny generický migračný mechanizmus podľa `config_schema` neexistuje. Posledné bumpy 15/17/18 boli „bez migrácie" (chýbajúci kľúč = doterajšie správanie). Existujúce migrácie sú úzke: `migrate_legacy_part_keys` (3848–3859, podľa `part_key_schema`), `Fronts.migrate_legacy_config` pod `engine_version` 0.3.1 (3868–3872), V0.1 vnorené hashe `legacy_*` (3882–3904).
- **Aktivačné konštanty** `DRAWER_ACTIVATION_SCHEMA` 5, `HINGE_ACTIVATION_SCHEMA` 9, `LIFT_ACTIVATION_SCHEMA` 11 (277/285/296) sa pri ďalších bumpoch nehýbu (guard test `test_s1e0_min_vyska.rb:219`).
- **Disciplína bumpu** (STANDARD §2.5 r. 210–212): nové konštrukčné pole / nová hodnota enumu / nová rola = bump; čísla sekvenčne podľa poradia mergov; dôvod do komentára `HISTORIA`.

---

## 2 · Geometria — lokálne osi, polohy a hĺbky dielcov

**Osi** (STANDARD §3.2 r. 316–330): X šírka (zľava doprava), **Y hĺbka, +Y ide DOZADU**, Z výška. Origin korpusu = ľavý-predný-dolný roh; **čelná (predná) rovina je Y = 0**; čelá ležia v zápornom Y. `d` = `cfg[:depth]` = celková hĺbka **vrátane chrbta** (D-37). Konštrukčná hĺbka `carcass_depth(cfg)` = `d − bt` pri `overlay`, inak `d` (construction.rb:1242–1244; JS zrkadlo core.js:1545–1550). `t` = hrúbka, `s` = `floor_height`, `h` = výška, `bt` = hrúbka chrbta.

| Dielec (`part_key`, rola, názov) | `box [X,Y,Z]` | `origin` | Kód |
|---|---|---|---|
| Boky `cabinet/side:left` / `:right` (`side_left/right`, „Bok lavy/pravy") | `[t, cd, h−z0]`, **z0 = s+t** pri `under_sides`, **0** pri `between_sides` | `[0 alebo w−t, 0, z0]` | construction.rb:1384–1398 |
| Dno `cabinet/bottom` („Dno") | `under_sides [w, cd, t]` · `between_sides [w−2t, cd, t]` | `[0 alebo t, 0, s]` | 1401–1412 |
| Vrch plný `cabinet/top` („**Vrch**") | `[w−2t, cd, t]` | `[t, 0, h−t]` | 1415–1427 |
| Vrch `none` | — | — | 1418–1419 |
| Výstuha predná `cabinet/rail:front` (`rail_front`) flat | `[w−2t, rd, t]` | `[t, 0, z_bottom]` | 1450–1453 |
| Výstuha zadná `cabinet/rail:back` (`rail_back`) flat | `[w−2t, rd, t]` | `[t, cd−rd, z_bottom]` | 1454–1457 |
| Výstuhy upright (F / B) | `[w−2t, t, rd]` | `[t, 0 alebo cd−t, z_bottom]` | 1440–1448 |
| Chrbát `overlay` `cabinet/back` („Chrbat") | `[w, bt, h−s]` — **celá šírka, od spodku dna po vrch** | `[0, d−bt, s]` (za skráteným telom) | 1492–1495 |
| Chrbát `inset` | `[w−2t, bt, z_hi−z_lo]` | `[t, d−bt, z_lo]` (na dne, pod vrchom) | 1481–1485 |
| Chrbát `groove` | `[w−2t, bt, z_hi−z_lo]` | `[t, d−10−bt, z_lo]` | 1486–1491 |
| Chrbát `none` | žiadny dielec (D-31) | | 1476 |
| Sokel `cabinet/plinth:front` („Sokel predny") | `[w alebo w−2t, t, s]` | `[0 alebo t, recess, 0]` | 1500–1515 |

- **Výstuhy (D-80) — jediná autorita `rail_geometry`** (1263–1280): `head = h − (s+t) − 20`; flat hĺbka ≤ `cd/2 − 10`, upright výška ≤ `head`; minimum 20; odsadenie ≤ `head − occupy`; `z_bottom = h − off − occupy` = strop vnútra. Orezanie **nikdy ticho** — warning `rail_depth_clamped` / `rail_offset_clamped` (1518–1534).
- **Horná hrana chrbta** `back_z_hi` (1467–1470): pri `two_rails` = `h − rails_top_offset − t` (chrbát beží ZA výstuhami, o výšku upright výstuhy sa neskracuje — vedome konzervatívne, D-80), inak `interior[:z_hi]`.
- **Drážka nie je modelovaná ako drážka** — `groove` je len poloha 10 mm pred zadnou hranou (`GROOVE_OFFSET` 19); chrbát má šírku `w−2t` a výšku medzi dnom a vrchom, **bez prídavku hĺbky drážky** do bokov/dna/vrchu (1486–1491; grep `groove` nič iné nenájde). Či to sedí s dielňou: **NEOVERENÉ** (otázka na Michala, dôležitá pri „kolízii komína s drážkou").
- **Kde je predná hrana:** všetky dielce korpusu začínajú na Y = 0 (dno, vrch, boky, predná výstuha). Zadná hrana bokov = `cd`; zadná hrana dna/vrchu = `cd`.
- **Čo by K1 menilo v kóde** (fakt o dotknutých funkciách, nie návrh): (a) komín — `bottom_part`, `top_parts` (full), `rail_parts` (poloha `rail_back`), `back_part` (Y chrbta vo všetkých režimoch), `interior_dims` (`back_front_y`), sémantika `carcass_depth` pri `overlay`, `draw_legs`; (b) zapustenie vpredu — `top_parts` (origin Y), `rail_parts` (origin `rail_front`), clamp `cd/2 − 10` v `rail_geometry`. **K2** — nová vetva `back_part` (dva deskriptory), `interior_dims.back_front_y` pre nový režim, `back_z_hi`.
- **Pozor na D-37 pri komíne s `overlay`:** dnes sú boky/dno/vrch skrátené o `bt`, lebo chrbát zaberá zadných `bt` z celkovej `d`. Pri komíne chrbát nie je vzadu, takže otázka „sú boky `d` alebo `d − bt`" je otvorená (§ Otvorené body).

---

## 3 · Vnútorná hĺbka — výpočet a všetci konzumenti

**Autorita:** `Construction.interior_dims(cfg)` (construction.rb:1354–1376) → `{z_lo = s+t, z_hi, avail_h, back_front_y, back_thickness}`. `back_front_y` = vzdialenosť od čelnej roviny po **prednú plochu chrbta**: `none` d · `inset` d−bt · `groove` d−10−bt · `overlay` d−bt. Plán ju vydá ako `available.depth` (216–220) a `merge_final` ju uloží do configu ako `available_depth` (cabinet_builder.rb:2914–2916). `validate!` odmietne `back_front_y ≤ 10` („Hlbka je prilis mala.", 1539).

| # | Konzument | Kde | Čo číta | Keby sa chrbát posunul dopredu o X (komín) |
|---|---|---|---|---|
| 1 | Strom zón | construction.rb:134–136 (`zbox y1 = back_front_y`) → `ZoneTree.compute` | hĺbka všetkých zón, `zones[].depth` v configu, ghost boxy | zóny kratšie o X; zóny sa delia len v X a Z, takže **zámky polí nepadnú** |
| 2 | Police | zone_tree.rb:547–567 (`sd = y1 − y0 − 20`, `SHELF_FRONT_INSET` 25) | hĺbka zóny | **police kratšie o X — mení sa kusovník aj VEPO**; zóna ≤ 20 mm → warning `shelf_skipped_shallow_zone` |
| 3 | Priečky | zone_tree.rb:521–541 (plná hĺbka zóny) | hĺbka zóny | priečky kratšie o X (výrobná zmena) |
| 4 | Recepty zásuviek | `context_for` 1091–1130 (`clear_depth` 1124) → `Recipes.resolve` drawer_recipes.rb:507–647 | svetlá hĺbka | automatická **NL sa ticho skráti** (606–612: najväčšia NL s `min_depth ≤ clear_d`) → iné dielce boxu aj iný výsuv v nákupe; **zamknutá NL** sa neprispôsobí → RED `nl_lock_invalid` (598–604); nič sa nezmestí → RED `drawer_no_fit`. RED zásuvky zastavia nákup, rozpočet a ponuku (`BUILD_BLOCKERS`, production_core.rb:1267–1293) |
| 5 | Chipy osí zásuvky v Inspectore | `drawer_contexts` 1052–1069 → `CabinetBuilder.drawer_axis_contexts` | ten istý `ctx` | ponuka NL/výšok sa zúži |
| 6 | Legacy pravidlo výsuvu | `hw_ctx['available_depth']` construction.rb:197 → pravidlo `vysuvy-nl-podla-hlbky` hardware_rules.rb:307–311 (`fit_series`, rad 260…620, vôľa 10) | `available_depth` | NL starých (neklasifikovaných) zásuviek sa skráti |
| 7 | Výklop AVENTOS HL top | eligibility `depth_min` 264 (hardware_rules.rb:384–388, kontrola 1587–1607) | `available_depth` | napr. horná 320 v drážke má 307; komín > 43 mm → RED `lift_dimension_unsupported` |
| 8 | Kontrola niky spotrebiča (S1-F) | `ApplianceChecks.context` appliance_checks.rb:74–95 (`depth = back_front_y`, r. 88) → `niche_verdict` 160–208; osi `fridge` Š/V/H, `oven` a `microwave` **Š/H** (47–49) | vnútorná hĺbka | komín zníži porovnávanú hĺbku → môže vzniknúť ORANGE clash hĺbky (validation.rb:1181–1192) pre chladničku aj rúru/mikrovlnku |
| 9 | Ponuka modelov „zmestí sa" v riadku Spotrebič | `Panel.appliance_interior` payloads.rb:660–672 (použité 172–174, `fits` 540) | vnútorná hĺbka | niektoré modely sa začnú ponúkať ako „nezmestí sa" |
| 10 | Box niky chladničky (referencia) | construction.rb:455–482 (origin `y = 0`, hĺbka = `depth_min` z listu) | **nečíta chrbát** | box sa kreslí od čelnej roviny dozadu bez ohľadu na chrbát → pri komíne môže vizuálne prechádzať posunutým chrbtom; nahlási to až Kontrola (#8) |
| 11 | Inspector „Vnút. hĺbka" | označená skrinka: `available_depth` z configu (bridge.js:732, payloads.rb:105); vkladanie: **vlastný JS vzorec** form.js:566–573 | `back_front_y` / vlastná kópia | JS kópiu treba zladiť, inak návrh ukáže iné číslo než stavba |
| 12 | Nohy (proxy vizuál) | `draw_legs` cabinet_builder.rb:2402–2426 (zadný rad na `carcass_depth − 60`) | `carcass_depth`, nie interiér | pri X > ~35 mm by zadný rad nôh stál mimo skráteného dna (len vizuál; počet nôh = šírka) |
| 13 | Výstuhy D-80 | `rail_geometry` clamp `cd/2 − 10` (1271) | `carcass_depth` | nečíta interiér; pri komíne treba rozhodnúť polohu `rail_back` |
| 14 | Závesy, nohy (počet), príchyt sokla, závesné kovanie hornej | hardware_rules.rb:252–321 | výška čela / šírka / typ | **nečítajú hĺbku** — bez vplyvu |
| 15 | Kontext kovania `depth` | `cabinet_hw_ctx` 1219–1234 (`'depth' => cfg[:depth]`, celková) | celková hĺbka | žiadne seed pravidlo ho nečíta |

**K2 (lišty):** debata hovorí „vnútorná hĺbka sa nemení, rovnako ako dnešné horné výstuhy" (r. 41). Fakt z kódu: dnešné horné výstuhy `back_front_y` nemenia, ale zaberajú výšku (`z_hi`). Lišty chrbta by stáli **vzadu v celej šírke** v pásme dole a hore; ak by `back_front_y` ostalo `d` (ako pri `none`), priečky (plná hĺbka zóny), police aj spodná zásuvka s NL podľa `d` by do líšt geometricky zasahovali. Ak `d − t`, zmenší sa hĺbka zón aj NL v celej výške. **Rozhodnutie chýba** (§ Otvorené body).

---

## 4 · ABS a hrany

- **Pravidlá (seed, per ROLA)** abs_rules.rb:129–156: boky `L1` (predná) · **dno/vrch `L1` (predná)** · police a priečky `L1` · výstuhy `L1` (dlhá hrana, D-30) · **chrbát `{}`** · sokel `{}` · čelá dookola · dielce zásuvky (dno nič, ostatné L1 = horná). Hodnota je trieda „jednotka" (1,0), resolver obchodnej hrúbky ju prekladá (STANDARD §7.5 r. 1094–1098).
- **Popisy hrán** (`EDGE_LABELS` 61–92): dno/vrch `L1 Predná · L2 Zadná · W1 Ľavá · W2 Pravá`; boky `L1 Predná · L2 Zadná · W1 Dolná · W2 Horná`; chrbát `L1 Dolná · L2 Horná`; výstuhy neutrálne „Pozdĺžna 1/2".
- **Mapa hrana → plocha kvádra** (part_faces.rb): osi deskriptora `AXES_*` (50–60); **`L1` = MIN osi šírky, `L2` = MAX** (`EDGE_FACES` 69–70); výnimka `STANDING_EDGE_FACES` (L1 = MAX = horná) platí LEN pre `STANDING_ROLES` = dielce zásuvky (73–78). `ROLE_AXES` (145–160) — kandidáti osí per rola na čítanie už postavenej zákazky (D-104). 2D karta dielca: `AbsRules.edge_sides` (447–453, default `EDGE_SIDES_LYING` L1 dole).
- **Vyhodnotenie:** `CabinetBuilder.resolve_part` (1268–1328) → `AbsRules.resolve_edges` (abs_rules.rb:353) → `part_overrides[part_key].edges` vyhráva; výsledok sa materializuje do snapshotu dielca (`add_part` 2078–2122). Zlyhanie pickera = warning na dielec.
- **Seed-merge:** nová rola sa do existujúceho `%APPDATA%\NOXUN\Engine\abs_rules.json` dostane **len s bumpom `SEED_VERSION`** (dnes 4, abs_rules.rb:36–51) — lekcia KOV-A1/C2a: bez bumpu by sa dielec postavil **bez olepu**. Pravidlá sú per počítač, nie per zákazka.
- **K1 komín:** zadné hrany dna a vrchu (`L2`) ani zadná hrana boku (`L2`) dnes pásku nemajú a pravidlo sa meniť nemusí (debata r. 36–37: „hrana ostáva neviditeľná"). Ručné overridy hrán na `cabinet/bottom|top` prežijú (kľúč sa nemení). **K1 zapustenie:** predná hrana vrchu (`L1`) ostáva olepená pravidlom — či je zapustená hrana viditeľná a má pásku mať: **NEOVERENÉ** (Michal).
- **K2 lišty:** stojace v rovine XZ (`AXES_WALL` = dĺžka X, šírka Z, hrúbka Y, ako chrbát) → pri default mape **L1 = spodná plocha, L2 = horná**. Horná lišta má viditeľnú spodnú hranu (= `L1`), dolná lišta hornú hranu (= `L2`). Keďže pravidlá sú per rola, **jedna rola s variantom top/bottom nevie dať dvom lištám rôznu hranu**: buď dve roly (`back_rail_top` s `{L1}`, `back_rail_bottom` s `{L2}`), alebo dolná lišta v `STANDING_ROLES` (L1 = horná) a obe `{L1}`.
- **Dôsledok pre kusovník:** agregačný kľúč riadku obsahuje mapu hrán `L1..W2` (bom.rb:1378–1388). Lišty s pásom na `L1` vs `L2` a rovnakým rozmerom = **dva riadky**; s pásom na rovnakom kóde = **jeden riadok, 2 ks**. VEPO dostane v oboch prípadoch kód `—` na pozdĺžnej dvojici (VEPO_KONTRAKT r. 20–24).
- **Kontrola olepov (`EdgeCheck`)** klasifikuje missing/extra podľa pravidla roly — nové roly bez pravidla by sa správali ako rola bez ABS.

---

## 5 · Roly, identita dielcov, overridy, BuildPlan

**Dnešné kľúče korpusu** (construction.rb, zone_tree.rb, fronts.rb):
`cabinet/side:left` · `cabinet/side:right` · `cabinet/bottom` · `cabinet/top` · `cabinet/rail:front` · `cabinet/rail:back` · `cabinet/back` · `cabinet/plinth:front` · `zone:<uzol>/shelf:<i>` · `zone:<uzol>/divider_v:<i>` · `zone:<uzol>/divider_h:<i>` · čelá `front:<id>/wing:single|left|right|p1..p4`, `/panel`, `/flap`, `/blind` · dielce zásuvky `front:<id>/drawer_bottom|drawer_back|drawer_inner_front`, `/box_side:left|right`. Suffixy (meno definície + `part_id`): `SIDE-L/R`, `BOTTOM`, `TOP`, `TOP-RAIL-F/B`, `BACK`, `PLINTH`…

- **API `PartKeys`** (part_keys.rb): `SCHEMA = 1` (9); `cabinet(kind, variant)` → `cabinet/<kind>[:<variant>]` (13–16); `valid?` = prefix `cabinet/|zone:|front:|board/` (45–47) — napr. `cabinet/back_rail:top` by bol syntakticky platný; `segment` povoľuje `[A-Za-z0-9_.-]` (183–186). `human_label` pozná len čelá, zásuvky a zóny; **kľúč `cabinet/…` vráti surový** (89–119).
- **`part_overrides`** = `{ part_key => {material_id, grain_direction, edges, edge_warnings} }` (STANDARD §7.2 r. 1036–1056; `norm_overrides` cabinet_builder.rb:3209–3255 existenciu dielca nekontroluje). `PartKeys.migrate_overrides` (52–72) **zachová kľúče neexistujúcich dielcov** → pri zániku dielca je override **dormantný** a po návrate dielca znovu platí (model-a-identita.md:126–132). Zoznamy ručných zásahov robia join s reálnymi dielcami. Pri prepnutí chrbta na lišty by override `cabinet/back` čakal dormantný, bez UI riadku.
- **Druhy osirotenia** existujú len pre **kovanie**: `hardware_overrides` → `disabled · invalid · dormant` (hardware_rules.rb:1944–1970; D-132 `dormant` = zámok osi, ktorý nikto nečíta) + riadok `part_material` pre materiál dielca zásuvky v konflikte (payloads.rb:1952–1970). `hardware_manual` s neexistujúcim vlastníkom = ORANGE `owner_missing` (bom.rb:584–598), no **vlastníkom ad-hoc položky smie byť len `front:` alebo `zone:` dielec** (`MANUAL_OWNER_PREFIXES` payloads.rb:800–805) — boky, dno, vrch, chrbát vlastníkom byť nemôžu.
- **BuildPlan `SCHEMA` = 5** (build_plan.rb:89; história 14–32). `ROLES` = uzavretý slovník (102–107; `validate_part!` odmietne neznámu rolu 431). **Precedens:** nové roly dielcov zásuviek = bump 3 → 4 („plán, ktorý ich môže niesť, už nie je plánom schémy 3", model-a-identita.md:162–167). Aditívne voliteľné kľúče plánu bez bumpu (`references`, `hardware_conflicts`, hmotnosť). `plan_schema` sa ukladá do configu (2747, 2901), ale **nikto ho nečíta ako bránu** (grep).
- **K1:** žiadna nová rola ani kľúč, len iné rozmery → `PartKeys`/BuildPlan bez zmeny (fakt: kľúče nezávisia od rozmerov, test `test_construction.rb:388`). **K2:** nové roly by podľa precedensu znamenali BuildPlan 5 → 6 (rozhodne audit); `PartKeys::SCHEMA` sa pri aditívnych kľúčoch nebumpuje (precedens KOV-A1, KOV-C2b).
- **Kde všade žijú zoznamy rolí** (každá nová rola musí prejsť všetkými): `BuildPlan::ROLES` · `AbsRules::EDGE_LABELS` + `SEED_RULES` + `SEED_VERSION` · `PartFaces::ROLE_AXES` · `CabinetBuilder::PART_TAGS` (355–371; chýbajúca rola → tag `Noxun/Korpus`, chrbát má `Noxun/Chrbát`) · `Construction.material_channel` (75–83; `back` → kanál chrbta, neznáma rola → kanál korpusu) · `ProductionCore::ROLE_LABELS` (production_core.rb:1663–1682) · `roleLabel` v part_card.js:2–11 · `RulesDialog::ABS_ROLE_ORDER` (rules_dialog.rb:43–46; neznáma rola sa pripojí na koniec) · `CpExport.material_category` (cp_export.rb:373–384; `back` → „chrbty", inak „vnútorné korpusy") · `VepoExport::SHORT_NAMES`/`NAME_PAIRS`.

---

## 6 · Výstupy — názvy v kusovníku a VEPO

Kusovník Štúdia nesie **plný názov** z deskriptora (plochý kľúč `name` na entite, `add_part` 2112–2120); VEPO skracuje (`VepoExport.short_name` vepo_export.rb:446–471), **neznámy názov ide bez zmeny**. Limit **20 znakov** na celý riadok vrátane skriniek (`NAME_MAX` 64; kontrakt v1.2), orez po hranici tokenu + ORANGE `name_long` v Kontrole.

| Dielec | Názov v kusovníku | VEPO token | Pár v riadku |
|---|---|---|---|
| boky | `Bok lavy` / `Bok pravy` | `Bok L` / `Bok P` | `Bok LP` (NAME_PAIRS 96–97) |
| dno | `Dno` | `Dno` (bez skratky) | — |
| vrch plný | **`Vrch`** | `Vrch` | — (`Dno/Vrch`, ak sa zlejú) |
| výstuhy (top) | `Vystuha predna` / `Vystuha zadna` | `Vyst P` / `Vyst Z` | `Vyst PZ` |
| chrbát | `Chrbat` | `Chrbat` | — |
| sokel | `Sokel predny` | `Sokel` | — |
| police / priečky | `Polica N` / `Priecka zvisla` / `vodorovna` | `Polica N` / `Priecka Z` / `V` | číslované tokeny sa zlúčia (`Polica 1 2 3`) |

- **Nekonzistencia pomenovania vrchu:** dielec sa volá „Vrch" (construction.rb:1423, VEPO), rola v stĺpci „Rola" kusovníka je „Strop" (production_core.rb:1665), skupina v Inspectore „Strop" (panel.html:436), karta dielca „Vrch" (part_card.js:3).
- **Ako by sa dali pomenovať lišty chrbta (fakty o obmedzeniach, výber je na Michalovi):** kľúč `SHORT_NAMES` musí byť presný reťazec z buildera; token by mal byť krátky (dnes 5–7 znakov), aby sa zmestili aj skrinky (`s1 s2`); dvojica by potrebovala vlastný `NAME_PAIRS` záznam (ako `Vyst PZ`), inak `Token1/Token2`. Tokeny končiace číslom sa zlučujú (`merge_numbered`), takže tvar `Lista 1`/`Lista 2` by dal `Lista 1 2`. „Vyst Z" dnes znamená **hornú zadnú výstuhu** — podobný názov pre lištu chrbta by v dielni kolidoval. Návrh z debaty: roly `back_rail_top`/`back_rail_bottom`, `PartKeys.cabinet('back_rail','top'|'bottom')` (debata r. 45).
- Rola lišty v cenovej ponuke padne do „vnútorné korpusy" (nie „chrbty") — cp_export.rb:380–383.

---

## 7 · Kovanie — závislosť od chrbta, vrchu a hĺbky

- **Žiadne pravidlo ani set nečíta `back_mode`, `top_mode`, výstuhy ani roly bok/dno/vrch/chrbát** (grep v `hardware_rules.rb`, `hardware_sets.rb`, `hardware_taxonomy.rb`, `hardware_catalog.rb` = 0 zhôd). Filtre `applies_to` sú: rola `cabinet` + `support`/`cabinet_type`/`floor_height_min`, čelá, police (hardware_rules.rb:246–414).
- Seed pravidlá: **nohy** 4/6 podľa šírky (252–259) · **príchyt sokla** podľa šírky, len `support legs` a sokel ≥ min (266–273) · **závesy** podľa výšky dvierok (280–303) · **legacy výsuv** podľa `available_depth` (307–311) · **závesné kovanie hornej skrinky** „Bystrica" 2 ks (315–317) · **podperky** 4/policu (319–321) · úchytkové profily (325–339) · **výklop AVENTOS** s eligibility vrátane `depth_min` 264 pre HL (350–388) · sklop = závesy (393–413).
- **Hĺbkovo závislé** sú teda len: legacy výsuv, HL top a recepty zásuviek (§3 #4–#7). Kontextové kľúče pravidiel: `CONTEXT_KEYS` (211–212).
- **K1** mení kovanie **nepriamo** cez `available_depth` / `clear_depth` (NL výsuvov, HL eligibility). **K2**: debata „žiadne nové pravidlo" (r. 46); v kóde nie je nič, čo by od chrbta záviselo. Počet podperiek sa nemení (police ostávajú). Recepty zásuviek (`data/recipes/*.json`) sú nemenné; hĺbku berú výhradne z `ctx[:clear_depth]`.

---

## 8 · Typy skriniek a kde K1/K2 dávajú zmysel

| | Dolná `lower` | Horná `upper` | Slot umývačky `dishwasher` |
|---|---|---|---|
| Hĺbka / sokel | 510 / 100 | 320 / **0 vynútené** | 560 / 0 vynútené |
| Dno | pod bokmi | medzi bokmi | — |
| Chrbát | naložený HDF 3 | **v drážke** HDF 3 | — |
| Plán | `build_plan` | `build_plan` | **vlastná vetva `appliance_slot_plan`** (construction.rb:116–117, 336–390) — žiadne boky, dno, vrch, chrbát, zóny; 1 dielec = čelo + referencia tela |
| Podpora | nohy / sokel | `none` | `none` vždy |

- **Vysoká skrinka** (chladničková, rúrová) je dnes `lower` s väčšou výškou — žiadny vlastný typ. Chladnička v skrinke (S1-F) = väzba `appliance_refs[]` na `lower`.
- **Slot umývačky: K1/K2 sa ho netýkajú** — jeho plán konštrukčné polia vôbec nečíta; polia sa však do jeho configu ukladajú (`cabinet_config` ich píše vždy, 2760–2767). Či sú skupiny S4 „Strop/Dno/Boky/Chrbát" pri slote v Inspectore skryté: **NEOVERENÉ** (skryté sú riadky `SLOT_HIDDEN_ROWS` form.js:632, kontext Zóny `NX_CTX_LOCK` shell.js:31–33).
- **Seed šablóny** (templates.rb:680–688): „Dolna klasik" (dve výstuhy naplocho), „**Drezova**" (výstuhy na výšku), „Varna doska" (výstuhy −20), „Horna klasik" (drážka) + 2 sloty. Chladničková šablóna neexistuje (debata ju plánuje s komínom, r. 31).
- **Kde K1/K2 fyzicky majú kam sadnúť (fakty):** K1a komín mení len dno/vrch/výstuhy/chrbát — funguje na `lower` aj `upper`; pri `upper` s drážkou a HL výklopom je rezerva do `depth_min` 264 len ~43 mm (§3 #7). K1b zapustenie sa týka vrchu `full` a výstuh `two_rails`; pri vrchu `none` nemá čo posunúť. K2 lišty sa kombinujú s každým dnom a vrchom (debata r. 43 výslovne s „dve výstuhy"). Kde to dáva zmysel produktovo, rozhoduje Michal.

---

## 9 · UI — kde sú konštrukčné nastavenia a náhľad

- **Inspector, kontext KORPUS, sektor S4 „Nastavenia"** (panel.html:428–507), exkluzívne akordeóny `details[data-s4="korpus"]`:
  - **Strop** (435–456): `top_mode` select (Plný panel / Dve výstuhy / Bez stropu) + skupina `twoRailsGroup` (orientácia, odsadenie od vrchu, hĺbka/výška pásu) zobrazovaná len pri dvoch výstuhách (`toggleTwoRails` form.js:699).
  - **Dno & podstavec** (458–477): `bottom_mode` + sokel (`plinth_mode`, `plinth_recess` s `toggleRecess`).
  - **Boky** (479–484): **len text** „Per-bok nastavenia (rohové spoje, odsadenia) pribudnú v ďalšej verzii." — `.hint`, ktorý sa podľa UI_DIZAJN §1 (r. 48–52) v novom UI už nepridáva.
  - **Chrbát** (486–507): `back_mode` select (Naložený zozadu / Vložený medzi boky / V drážke / Bez chrbta), `back_thickness` select **HDF 3 / Pevný 18** (riadok sa skrýva pri „Bez chrbta" — `toggleBackTh` form.js:702, hodnota sa zachováva), `.hint` o celkovej hĺbke.
  - Základné (S2) „Rozmery" (panel.html:255–317): šírka, výška, hĺbka, sokel, hrúbka; informačný stĺpec „Vnút. šírka / **Vnút. hĺbka** / Úložná výška / Dielcov / Materiál / Hmotnosť". Vo vkladaní je „Vnút. hĺbka" skrytá (komentár 299–301).
- **Náhľad (preview.js)** je v kontexte Korpus **čelný rez** (ui-lifecycle.md:831): `drawCarcass` (571–594) kreslí obrys, boky, dno, vrch/výstuhy (podľa `nxRailGeom`) a podstavec; hĺbka je len **náznak skosenej hornej plochy** s kótou „H 510" (`renderCabOutline` 962–976, `pvDepthSkew` 103–106). **Chrbát sa nekreslí vôbec.** Komín, zapustenie vpredu ani lišty chrbta by v tejto projekcii neboli vidieť — treba rozhodnúť formu (bokorys/rez, kóta, text). Odhad dielcov/plochy vo vkladaní `nxDraftStats` (485–518) počíta chrbát ako 1 dielec `W × výška tela` a dno/vrch na celú hĺbku.
- **JS zrkadlá, ktoré by sa hýbali:** `nxCarcassDepth` (core.js:1545–1550, dnes len pre clamp výstuh), `nxInteriorZ`/`nxRailGeom`, samostatný vzorec „Vnút. hĺbka" (form.js:566–573), `cabinetHeightError` (form.js:200–226, červené polia pred apply), `LIMITS` (form.js:149–157). Paritu výšky a `nxCarcassDepth` stráži `tests/js/test_interior_height.js` (D-37 r. 33–38); vzorec „Vnút. hĺbka" v `updateAvailable` hodnotovým testom stráženy nie je (`tests/js/test_uib3_korpus.js:182` overuje len existenciu výstupov).
- **Trvalé pravidlo** (PLAN.md:672–674, UI_DIZAJN §1 r. 13–14, 45–52): vertikálny priestor je vzácny; pred novým riadkom zvážiť existujúci rad, roh náhľadu, ikonu; rozbaľovacie veci sú overlay; vysvetlenie do tooltipu, nie trvalý `.hint`. Existujúci vzor bez rastu panela: podmienená podskupina (`twoRailsGroup`), skrytý riadok (`backThRow`).

---

## 10 · Šablóny (STD 6)

- Knižnica `TemplateStore` (`STD = 6`, templates.rb:66) ukladá `config` záznamu **bez whitelistu** (`normalize_list` 574–590, `record` 609–613) — whitelist je pri **ukladaní**: `Panel.template_config_from` (payloads.rb:2300–2343) menovite skopíruje type, rozmery, `bottom/top/back_mode`, `back_thickness`, sokel, 3 polia výstuh, `zone_tree`, `fronts`, polia slotu, `appliance_expects`, nastavené materiály, voliteľne kovanie a **marker `config_schema`** (2308). **Nové polia sa do šablóny NEprenesú automaticky** — musia pribudnúť do tohto zoznamu.
- **Vklad zo šablóny:** JS zapíše config šablóny do formulára cez `CONSTRUCTION_FIELDS` a pošle payload; čo formulár nepozná, vypadne. Pre takéto polia existuje serverový vzor — dosadenie z ULOŽENÉHO záznamu (`apply_template_slot_fields!` actions_cabinet.rb:538–563 pre `dw_*`). R-12 brána novšej šablóny (actions_cabinet.rb:481).
- **Použitie šablóny na existujúcu skrinku:** `merge_template` (templates_dialog.rb:526–569) = `tpl_config.dup` + zachované `part_overrides`, `hardware_overrides`, vlastnícke sety, väzby a únia očakávaní. Pre **legacy šablónu bez kľúča** platí vzor „chýbajúci kľúč = zachovaj hodnotu CIEĽA" len pri `plinth_recess` (D-13), `name`, `hardware_manual` a materiáloch. Nové konštrukčné pole bez takejto vetvy by pri použití starej šablóny spadlo na default `normalize` (napr. komín na 0) — **ticho**. Strom zón sa berie zo šablóny celý (prepis delenia).
- Seed šablóny dolná/horná marker `config_schema` **nenesú** (lower_base/upper_base 747–767; nesú ho len sloty 720–727).
- Debata chce „jedna hodnota per skrinka (šablónovateľné)" (r. 12) → treba prejsť body 5–7 zo zoznamu whitelistov v §1.

---

## 11 · Kontrola (semafor) a odmietnutia — dnešné konštrukčné nálezy

- **Tvrdé odmietnutie prestavby (výnimka → status, model sa nezmení):** `Construction.validate!` (1536–1552) — šírka ≤ 2t+10, **`back_front_y ≤ 10` („Hlbka je prilis mala.")**, sokel ≥ výška, `avail_h ≤ 10` (`MIN_AVAIL_H` 33), pri dvoch výstuhách vnútro < 20 (`MIN_INTERIOR_H` 28); `compute_zone_tree!` s hláškou D-80 „Vnútorná výška sa znížila (výstuhy)…" (1179–1184); `ZoneTree.validate_shelves!/validate_split!`; `validate_material_thickness!` (cabinet_builder.rb:1406–1418).
- **Klampy normalize** (tiché, ale v panele zrkadlené červeným poľom): MIN 200/80/150, horné 3000/3000/2000 (2949–2953; `LIMITS` form.js:149); `min_valid_height` pre absorpciu (1299–1329).
- **Panel pred apply:** `cabinetHeightError` (form.js:200–226) — zrkadlo `validate!` (vnútro ≤ 10, rezerva výstuh).
- **ORANGE „stavba" v Kontrole** = uložené `plan[:warnings]` (`Validation.check_build` validation.rb:1604–1629; `BUILD_INFO_ONLY` 1602 sa nehlási): `rail_depth_clamped`, `rail_offset_clamped` (construction.rb:1518–1534), `part_skipped_degenerate` (153–159), `shelf_skipped_shallow_zone` (zone_tree.rb:552), `weight_density_unknown`, `drawer_sync_recommended`, `hardware_*`, D-90 profil.
- **RED z kovania/zásuviek** (`drawer_no_fit`, `nl_lock_invalid`, `box_lock_invalid`, `lift_dimension_unsupported`…) — `box_lock_invalid` je zámok výšky dreveného boxu zásuvky (drawer_recipes.rb:571–574), nie konštrukcia korpusu.
- **Kontrola RED podľa roly:** `check_thickness` (validation.rb:478–499, pravidlo zdieľané s `thickness_ok_for?` cabinet_builder.rb:1432–1449 — mimo čiel a zásuviek **presná zhoda** hrúbky materiálu a dielca); `check_abs` ORANGE len pre čelá a voľné dosky (543–553).
- **Kde by prirodzene pribudli nové nálezy (vzory, nie návrh):** (a) nemožná kombinácia → `validate!` s vetou ako D-80 + zrkadlo v paneli; (b) orezaná hodnota → clamp + warning (vzor `rail_offset_clamped`), „semafor má upozorniť, nie potichu upravovať vstup" (07_KONSTRUKCIA r. 71–81); (c) degenerovaný dielec → dnes automaticky `part_skipped_degenerate` a dielec z kusovníka zmizne; (d) kolízia komína s drážkou/výstuhami — dnes žiadna kontrola kolízií dielcov neexistuje (STANDARD §10 ju len menuje, r. 1373).

---

## 12 · Observer mierky (Scale)

- `ScaleWatch.absorb` (scale_observer.rb:475–525): faktory lokálnych osí; nová hĺbka `= stará × sy` zaokrúhlená, klamp `MIN['depth']` 150 (`clamp_min` 540–545) — **nie je config-aware** (na rozdiel od výšky: `clamp_height` 561–575 cez `Construction.min_valid_height`). Parametre idú cez **`config_to_params(cfg)`** (493) → `CabinetBuilder.rebuild(..., transparent: true)` = jeden krok Späť spolu so Scale.
- **S komínom:** X je absolútna hodnota, ťahanie hĺbky by menilo len prednú časť dna/vrchu (ak `config_to_params` pole prenesie — inak by ho absorpcia **zahodila**, vzor GH #126 P1). Keď nová hĺbka nechá vnútro ≤ 10 mm, `validate!` vyhodí výnimku → `abort_safely` zruší aj transparentne pripojený Scale; `reject_scale` (658–686) má messagebox, no podľa charakterizácie **hlášku používateľ nedostane** — v čase záchrany už transformácia nie je zväčšená (construction.md:372–375). Model ostane korektný.
- **S lištami (K2):** hĺbka lištu nemení (dĺžka = šírka korpusu); zmena šírky/výšky ju prepočíta.

---

## 13 · Testy — kde sú a kam by patrili nové

- **Headless konštrukcia:** `tests/pure/test_construction.rb` (630 r.; golden dolná/horná 73–183, matica dno × vrch × chrbát × sokel 203, `interior_dims` 249–276, D-37 405–433, D-31 434–460, D-80 461–630) · `test_builder_config.rb` (normalize, config_to_params, cabinet_config, resolve_part, D-30 výstuhy 366) · `test_build_plan.rb` (validátor, matica 218, `plan_schema 5` 260) · `test_s1e0_min_vyska.rb` (16 kombinácií dno × vrch × chrbát 250, parita `MIN` Ruby↔scale↔JS 116–150) · `test_part_keys.rb` · `test_abs_rail_3stav.rb` · `test_kovd5_abs_zasuvky.rb` (zdrojový guard mapy hrán) · `test_d121*_vepo*.rb`, `test_vepo_export.rb` (názvy VEPO) · `test_insert_templates.rb` · `test_s1f_chladnicka.rb` (nika).
- **Golden charakterizácia plánov:** `tests/pure/test_kova_golden.rb` + `tests/fixtures/kova_golden/*.json` (15 konfigurácií, porovnáva `parts` box/origin/prod/axes, hardware, warnings) — **pri defaultných hodnotách K1/K2 musia ostať bajtovo rovnaké**; podobne `kovh_golden`, `kovc1_golden.json`.
- **JS:** `tests/js/test_interior_height.js` (zrkadlo výšky vnútra), `test_s1e0_min_vyska.js`, `test_s1f_preview.js`; spúšťať každý súbor zvlášť (CLAUDE.md).
- **In-SU (brána mergu pri builderoch/geometrii/undo):** `tests/sketchup/su_runner.rb` — `run_sync` 2612 (plán ↔ model 1:1: počet, `part_key`, origin a box každého dielca), `run_sync_back` 3323 (D-37 hĺbka, D-31 none, D-38 pevný 18), `run_sync_rails` 3417 (D-80), `run_s1e0` 3508 (absorpcia scale, jedno Späť), `run_char` 17828 (undo/scale charakterizácia); poradie behu 26057–26060. Runner `scripts\run_su_tests.ps1 -CloseWhenDone`.
- **Kam nové:** headless — nový súbor podľa vzoru `test_construction.rb` (+ rozšírenie matíc v `test_build_plan.rb:218` a `test_s1e0_min_vyska.rb:250`); in-SU — nová sekcia vedľa `run_sync_back`/`run_sync_rails` a riadok v poradí 26057+.
- **Kolízia mien:** „K1/K2" už nesú iné funkcie — `test_k1_smer_dekoru.rb`, `test_k2_smer_kresby.rb` (+ `.js`), in-SU `run_k1` 12559 a `run_k2` 12945 (smer dekoru D-108 a smer kresby D-87). Nové sady treba pomenovať inak.

---

## 14 · Riziká a pasce (čo sa môže pokaziť vo výrobe)

1. **Tichá strata poľa na niektorej z ~8 ciest** (§1) → pri prestavbe, absorpcii scale, kópii, šablóne či apply komín zmizne a dno/vrch sa narežú na plnú hĺbku. Najzradnejšie: `config_to_params` (18 volaní) a `merge_template` (legacy šablóna).
2. **Staršie PC:** bez bumpu `CONFIG_SCHEMA` by starší plugin pole zahodil (`normalize` whitelist) a neznámu hodnotu `back_mode` sklopil na default typu (`enum_val`) — z líšt by bol plný chrbát v kusovníku. Bump + existujúce brány to riešia; **obe PC treba aktualizovať** pred prvou takou zákazkou (vzor STAV r. 21–23).
3. **Komín mení existujúcu výrobu mimo samotných dielcov:** kratšie police a priečky, **iná NL výsuvov** (iné dielce boxu, iný výsuv v nákupe), zamknuté NL → RED a **zastavený nákup/rozpočet/ponuka**, HL výklop hornej → RED, kontrola niky → nové ORANGE. Pri default 0 sa nesmie zmeniť nič (golden testy).
4. **Default musí byť neutrálny:** keď sa nové kľúče budú zapisovať do každého configu (`cabinet_config` dnes píše konštrukčné polia vždy), zmení sa obsah configu každej skrinky pri najbližšej prestavbe; S1-E zvolil pre typové polia „zapisovať len keď treba" (2799–2806). Rozhodnutie formy zápisu je technické.
5. **D-37 pri komíne s naloženým chrbtom** — nejasné, či boky ostanú `d − bt` alebo `d`; zlá voľba = celková hĺbka skrinky iná, než zadal používateľ (kolízia so stenou/linkou).
6. **Drážka nie je modelovaná** — komín s chrbtom „v drážke" nemá geometrickú drážku, len posun 10 mm; hrozí nesúlad s dielňou (šírka chrbta bez prídavku drážky už dnes).
7. **ABS líšt:** bez bumpu `SEED_VERSION` sa nová rola na existujúcich PC nedoplní → lišty bez pásky; jedna rola pre obe lišty nevie dať rôznu hranu; voľba mapy hrán rozhodne, či budú v kusovníku 1 alebo 2 riadky.
8. **Chrbtové preflighty počítajú s „má chrbát = back_mode ≠ none":** `back_preflight` (actions_cabinet.rb:160–204) by pri režime líšt hľadal materiál chrbta hrúbky `back_thickness`, `MaterialsDialog` (materials_dialog.rb:1273–1275) by hrúbkou blokoval zmenu projektového chrbta, `MaterialsReplaceUni` (materials_replace_uni.rb:222–231) by prepisoval `back_thickness`. Výnimka dnes existuje len pre `none`.
9. **VEPO názvy:** nový názov bez skratky ide celý → pri 20-znakovom limite sa riadok oreže a skrinky vypadnú; podobnosť s „Vyst Z" (horná zadná výstuha) mätie v dielni.
10. **Vnútorná hĺbka v režime líšt** — ak ostane `d`, priečky/police/zásuvky zasahujú do líšt (kolízia v modeli aj vo výrobe); ak `d − t`, mení sa hĺbka zón v celej výške.
11. **JS zrkadlá hĺbky** — `nxCarcassDepth` (core.js:1545, zrkadlo `carcass_depth`, testované) a samostatná kópia vnútornej hĺbky v `updateAvailable` (form.js:566–573, netestovaná hodnotovo); ak sa pri K1/K2 nezladia s Ruby, návrh vo vkladaní ukáže iné čísla než stavba.
12. **Scale:** hĺbkový klamp nie je config-aware; neplatný výsledok sa vráti **bez hlášky** (§12).
13. **Nohy (proxy):** zadný rad môže vizuálne stáť mimo skráteného dna — počet ani kódy sa nemenia, ale model klame o polohe.
14. **Box niky chladničky** je kreslený od čelnej roviny nezávisle od chrbta — pri komíne vizuálne prechádza chrbtom; Kontrola hlási až podľa definície „hĺbky niky" (§ Otvorené body).
15. **Dormantné overridy:** ručný materiál/ABS na `cabinet/back` pri prepnutí na lišty čaká bez viditeľného riadku a po návrate sa sám obnoví.
16. **Dokumentačné nezrovnalosti:** `docs/architecture/model-a-identita.md:118` uvádza `config_schema` „dnes 7" (skutočnosť 18); Vrch/Strop v názvoch (§6).

---

## Otvorené body pre debatu a audit

### A · Rozhoduje Michal (funkčne, stolársky)

1. **Komín a chrbát:** s ktorými chrbtami sa komín kombinuje (naložený · vložený · drážka · bez · lišty)? Ako presne chrbát sedí — „naložený na zadné hrany dna a stropu" (teda medzi bokmi) alebo vložený medzi dno a strop? Pri naloženom: sú boky na plnú hĺbku `d` (nič za nimi nie je) alebo ostávajú o hrúbku chrbta kratšie?
2. **Komín pri vrchu „dve výstuhy":** posúva sa zadná výstuha o X spolu s chrbtom? Pri vrchu „bez stropu"?
3. **Komín pri drážke:** počíta sa drážka od zadnej hrany dna/stropu alebo boku? A je dnešné modelovanie drážky (len posun 10 mm, chrbát bez prídavku do drážky) správne pre dielňu?
4. **Hĺbka niky spotrebičov pri komíne:** merať po posunutý chrbát (dnešná logika) alebo po zadnú hranu boku/stenu? Týka sa chladničky aj rúry a mikrovlnky.
5. **Zapustený strop:** týka sa aj výstuh (obe, alebo len prednej)? Pri výstuhách na výšku? Má predná hrana zapusteného stropu mať ABS? Dáva zmysel pri hornej skrinke?
6. **Rozsahy a predvoľby:** X a Y — rozumné minimum/maximum, predvoľba 0; kde ich zadávať v Inspectore (Chrbát / Boky / Strop) pri pravidle vertikálneho priestoru; či ide o jednu hodnotu pre dno aj strop (debata: áno).
7. **Lišty chrbta:** jedna výška pre obe lišty? Presná poloha (dolná na dne, horná pod stropom/stropnou výstuhou)? Hrúbka vždy = korpus a materiál vždy korpusový, alebo sa dá zmeniť na karte dielca? Pri komíne stoja lišty na posunutej rovine?
8. **Vnútorná hĺbka pri lištách:** končia police, priečky a zásuvky pred lištami v celej výške, alebo len v pásme líšt (dnes sa hĺbka zóny ráta jedným číslom pre celú výšku)?
9. **Názvy:** lišty v kusovníku a VEPO (krátky token + pár), tag v modeli (Chrbát vs Korpus), kategória v cenovej ponuke (chrbty vs vnútorné korpusy); zjednotiť „Vrch" vs „Strop"?
10. **Stará šablóna na skrinke s komínom:** zachovať komín cieľa (ako pri zapustení sokla D-13), alebo vrátiť na 0?
11. **Náhľad:** ako má používateľ komín, zapustenie a lišty vidieť (bokorys, kóta, text v existujúcom riadku)?
12. **Semafor:** čo je chyba, ktorá stavbu odmietne, a čo len ORANGE upozornenie (príliš veľký X/Y, lišty vyššie než vnútro…)?

### B · Rozhodne audit (technicky, `codex-audit` + krížový audit)

1. Mená polí, jednotky, znamienko, klampy, hodnota enumu `back_mode` pre lišty a pole výšky lišty; forma zápisu do configu (vždy vs. len nenulové) s ohľadom na golden testy a obsah configu existujúcich skriniek.
2. `CONFIG_SCHEMA` 18 → 19 (a 20, ak K1 a K2 pôjdu v dvoch PR — čísla podľa poradia mergov), `HISTORIA`, bez migrácie pri neutrálnych defaultoch; dopredné a exportné brány sú existujúce.
3. Sémantika `carcass_depth` (D-37) a `interior_dims.back_front_y` pre každý režim chrbta × komín; `back_z_hi`; poloha `rail_back` a clamp `cd/2 − 10` v `rail_geometry` pri X a Y; nové kľúče `interior` len aditívne.
4. Roly líšt (dve roly vs. rola + `STANDING_ROLES`), BuildPlan `SCHEMA` 5 → 6 podľa precedensu, `AbsRules` seed + `SEED_VERSION` 5, `PartFaces::ROLE_AXES`, `PART_TAGS`, `ROLE_LABELS`, `roleLabel`, `ABS_ROLE_ORDER`, `CpExport`, `VepoExport::SHORT_NAMES/NAME_PAIRS`, `material_channel`.
5. Celá reťaz whitelistov z §1 (vrátane JS `CONSTRUCTION_FIELDS`, `DEFAULTS`, `LIMITS`, dvoch JS kópií hĺbky) + guard parity (dnes len pre polia slotu).
6. Vetva pre lišty v `back_preflight`, `MaterialsDialog` (hrúbková brána projektového chrbta), `MaterialsReplaceUni`; správanie výberu materiálu chrbta v Inspectore pri lištách.
7. Absorpcia scale: config-aware klamp hĺbky (analógia `min_valid_height`) vs. vedomé prijatie tichého návratu.
8. Nové kontroly: `validate!` vety + zrkadlo v paneli, plan warnings pre klampy, prípadne kolízia dielcov (dnes neexistuje žiadna).
9. Dopady na kovanie cez `available_depth`/`clear_depth` (NL, HL) — vedomá výrobná zmena, správanie zamknutých NL.
10. Poloha zadného radu nôh (proxy) a box niky voči chrbtu.
11. In-SU scenáre plán ↔ model (vzor `run_sync_back`/`run_sync_rails`): komín × každý chrbát × vrch, zapustenie × vrch, lišty × dno × vrch, Späť, absorpcia scale, šablóna tam a späť; pomenovanie sád mimo „K1/K2".
12. Rozsah dávok: audit-povinné (schéma + nová rola) **a** výrobné (rozmery, počty, hrany, kusovník, VEPO, kovanie) → predrecenzia povinná, in-SU test je brána mergu (CLAUDE.md, sekcie Git workflow a Testovanie).
