# PACKAGE NP-2 · Nárezový plán — nastavenia prerezu, orezu a prídavku + Kontrola s orezom (blok 2)

> **Autorita:** rozhodnutia Michala N1–N11 (`SYSTEM/zdroje/bloky/NAREZ/ROZHODNUTIA_MICHALA_2026-09-28.md`) a schválený mockup (`MOCKUP_NAREZ_2026-09-28.html`,
> obrazovky **D** a **E**, body O7, O9, O12); surový krížový audit a rešerš v tom istom priečinku — dispozície nálezov, ktoré rieši NP-2, sú na konci.
> **Stavia na NP-1** (`Noxun::Engine::SheetLayout`, `core/sheet_layout.rb`: `purchase_rect`, `fits_rect?(rect, allow_rotation:)`, parametre `kerf/trim/dup_allowance`)
> — štart implementácie až z čerstvého `main` po mergi NP-1; ak merge NP-1 zmení API, orchestrátor package pred štartom zladí.
> **Trieda:** audit-povinná (zvýšenie verzie súboru nastavení dodávateľa = zmena schémy) → audit návrhu · slepá predrecenzia (nový ovládací prvok v UI) ·
> `codex-po-pr`. In-SU netreba (nastavenia sú globálny súbor, Kontrola len číta — žiadny zápis do modelu, builder, observer ani undo).
> **Verzia:** patch (po NP-1 v0.15.1 → **v0.15.2**) + všetky `?v=` + prepis `SYSTEM/STAV.md`.

## 0 · Sonda pred auditom (main `b0127184`, 29.9.2026)

- **`noxun_engine/core/supplier_settings.rb`:** `STD = 1` (:43) sa zapisuje len v `seed_doc` (:267-269); `normalize` ponechá `std` zo súboru, ak > 0 (:364) —
  **verzia sa nikde neporovnáva** a zápis ju nemení. `SEED_VERSION = 1` (:44) riadi len režimové hodnoty; skaláre sa pri načítaní dopĺňajú vždy (:299-303).
  Skaláre: `SCALAR_DEFAULTS` (:75-81, 5 kľúčov), `SCALAR_RANGES` (:130-133, Float), vlastný riadok v `normalize_supplier` (:385-391 — nie slučka).
  `num` (:652-659) prijme desatinné číslo aj s čiarkou, len konečné. Chyba rozsahu = `"#{key}: hodnota mimo rozsahu #{first}–#{last}"` (:535 — surový kľúč).
  Patch neznámy kľúč **ticho vynechá** a vráti `:ok` (:523-611). Whitelist dokumentu `std/seed_version/active/suppliers`, dodávateľa `id,name,rates,
  standard_rows,mode_values` + 5 skalárov (:364-392) — neznáme kľúče zahodí už čítanie. `patch_active!`: zámok + `reload!` → revízia → validácia všetkého →
  aplikácia → `write` (:503-646). R-11 degradovaný stav: `degraded_write_blocked?` v `write` pod zámkom (:224-258); UI ho ukáže len pri uložení.
- **Vzor doprednej brány = `HardwareRules` KOV-F1** (tá istá kostra): `doc_std_unsupported?` (hardware_rules.rb:543-547), `newer_write_blocked?` pod zámkom
  hneď za degraded (:684-691, :728-746), `std_block_reason` (:550-553), čítanie áno bez zápisu seed-merge (`read_rules` :521-529), **každý zápis pečiatkuje
  `'std' => STD`** (:689). Banner v UI: vzor R-07 `library_state/library_reason` (hardware_catalog_dialog.rb:505-506, hw_sets.js:62, :88).
- **Guardy:** jediné `JsonFileStore.write(` a `write` pod zámkom (test_r08_zamky.rb:445-452); `patch_active_locked!` obsahuje `self.revision(sup)` (:473-475);
  poradie zámok < `degraded_write_blocked?` < zápis (test_r11_degradovana_zaloha.rb:452-462); seed 5 skalárov (test_supplier_settings.rb:55-58); podmnožina
  kľúčov payloadu (test_st4a_nastavenia.rb:171-173); texty „Rozpočet je prepočítaný." a „Nastavenia uložené" pribité (test_st1c_rozpocet.rb:272,
  test_st4a_nastavenia.rb:434/:457, su_runner.rb:18690). Guard zhody zoznamu skalárov Ruby ↔ JS **neexistuje**.
- **UI:** `SS_SCALARS` (studio_settings.js:141-149) = trojice `[kľúč, popis, jednotka]`; `ssRenderScalars` (:151-159) → `ssInput('scalar:'+kľúč, …)`
  (:82-88, `type=text`); `ssParse` (:75-80) mení prvú čiarku na bodku; `ssBuildPatch` (:553-584) — nečíslo → chyba, **rozsah klient nekontroluje**; `.bad`
  len pri nečísle (:733). Tooltip „?" v Štúdiu **neexistuje** (`.nxtip` len pod `html.nx-inspector`, panel.css:279-297). Uloženie: `handle_save` (supplier_settings_dialog.rb:243-274)
  → `refresh_studio(bump: true)` (:794-801) → `StudioDialog.refresh_if_open` → nový `control_payload` — **Kontrola sa po uložení prepočíta sama**.
- **Kontrola:** `Validation.run(collected, sheets: {}, edges: nil, hardware_expansion: nil, placements: nil, identities: nil)` (validation.rb:213-214) nad
  `collected[:records]`; `check_record` (:328-361): materiál mimo katalógu → RED `material` bez oversize; UNI → ORANGE a `return`; inak drift + oversize.
  `check_oversize` (:515-525) číta `sheet_size` (chýba/neplatný → ticho), `length/width/grain_direction`, do textu `name/owner_id/material_id`; nečíta
  `material_source`, hrúbku, hrany. `fits_on_sheet?` (:527-534): `width` → výmena, `length` → bez, **všetko ostatné vrátane prázdneho → obe polohy**;
  `≤ + DIM_TOL` (0,1). Kľúč `oversize|owner_id|part_key` (:1681-1691). **Volajúci `Validation.run` sú dvaja** (guard test_1b3_citanie.rb:127-135):
  `ProductionCore.control_payload` (production_core.rb:2359-2368 — Štúdio aj VEPO LOG) a klik na nález (:2119-2123) — **musia dostať tie isté parametre**,
  inak nález po kliku „zmizne" (:2124-2127). `edges_map` (:559-566) má tie isté kľúče ako `vepo_edge_thicknesses` (:232-234); `edges: nil` = ABS sa nekontroluje.
  Testy: test_validation.rb:76-93, :95-104, :155-162, **:164-171 (drift aj oversize = 2 RED)**, :203-208 (bez formátu nič); test_k1_smer_dekoru.rb:311-312
  a test_kon0_d143.rb:268-272 volajú `fits_on_sheet?` priamo. In-SU test na oversize nie je.
- **Duplák:** záznam nesie `material_source` len pri úplnej väzbe (bom.rb:1338-1344); katalógový duplák = kópia zdroja vrátane `type` a `sheet_size`
  (materials_catalog.rb:149-158), vzniká len z DTDL/MDF (:111-121) → orez platí vždy. Dnes jeden nález na záznam, hotový rozmer bez prídavku.
- **Docs na prepis:** `docs/architecture/outputs.md` odsek `validation.rb` (:12-140) a `supplier_settings.rb` (:795-821 — dnes „zatiaľ nezdokumentované");
  `docs/architecture/ui-lifecycle.md` odsek `supplier_settings_dialog.rb` (:3588-3656); STANDARD súbor nastavení dodávateľa nepopisuje (zmienky §11.3
  :1538-1545), vzor formulácie brány R-14 (:1557-1562); §3.3 :375 menuje `fits_on_sheet?` ako zrkadlo VEPO výmeny.

## 1 · Cieľ

(1) V **Nastaveniach rozpočtu → Výpočet a upozornenia** tri nové globálne hodnoty (N3, O7, O12): **Prerez píly (hrúbka kotúča)** 5 mm (0–10), **Orez okraja
platne** 10 mm (0–50), **Prídavok dupláku na stranu** 10 mm (0–30); desatinné hodnoty s čiarkou aj bodkou; tooltip „?" pri každej. (2) Súbor nastavení
dodávateľa dostane **verziu 2 a doprednú bránu** (C4). (3) **Kontrola „nezmestí sa na formát platne"** počíta s orezom podľa typu materiálu a s prídavkom
dupláku cez spoločnú prípravu NP-1 (O9, C9, G4); dielec bez smeru dekoru ďalej skúša obe polohy. Nárezový plán sa v UI ešte neukazuje (NP-3).

## 2 · Scope IN

### 2.1 Nastavenia (server)
- Skaláre **`kerf_mm`** (5.0; 0–10), **`trim_mm`** (10.0; 0–50), **`dup_allowance_mm`** (10.0; 0–30) — na troch miestach (`SCALAR_DEFAULTS`, `SCALAR_RANGES`,
  `normalize_supplier`). `SEED_VERSION` sa nemení (skaláre sa dopĺňajú vždy). Hodnoty sú Float, desatinné povolené (`num`).
- **Chyba rozsahu ľudsky** pre tieto tri (a ideálne všetky skaláre): „Prerez píly: hodnota mimo rozsahu 0–10 mm" (nie surový kľúč, desatinná čiarka).
- **Neznámy kľúč v patchi** — dnes ticho `:ok`; pre tri nové kľúče pridať test, že sa naozaj uložia (ochrana pred zabudnutým `SCALAR_RANGES`).
- Jedna **funkcia pre volajúcich**: `SupplierSettings.layout_params` (pracovný názov) → `{kerf:, trim:, dup_allowance:}` pre `SheetLayout` zo živého aktívneho
  dodávateľa; pri chybe čítania predvolené hodnoty **a príznak**, že ide o predvolené (Kontrola/plán ich použijú, UI to v NP-3 povie).

### 2.2 Verzia súboru a dopredná brána (C4) — vzor `HardwareRules` KOV-F1
- `STD = 2`; **každý zápis pečiatkuje `std = STD`** (inak starý súbor ostane navždy 1 a budúca brána nemá čo porovnať).
- `std > STD` (súbor z novšieho pluginu): **čítanie áno** (známe polia), **žiadny zápis ani zápis seed-merge**; `patch_active!` a `write` vrátia dôvod
  (`std_block_reason`, „Nastavenia uložil novší plugin (verzia X) — tento ich nemôže meniť; aktualizuj plugin."). Poradie v `write`: zámok → degraded (R-11)
  → **novší** → zápis (guard R-11 ostane zelený).
- **Payload** nastavení nesie stav (`settings_state`: `ok | degraded | newer`, dôvod) — UI v sekcii Nastavenia rozpočtu ukáže **banner** (vzor hw_sets
  `library_state`) a vypne „Uložiť" pri `newer` aj `degraded` (dnes sa degraded ukáže až pri pokuse o uloženie — zjednotiť).
- **Priznaný limit** (do STANDARD, outputs.md a PR): plugin **v0.15.0 a starší** bránu nemá — keď na tom istom `%APPDATA%` (dve verzie SketchUpu, downgrade)
  uloží nastavenia, nové kľúče zahodí a nechá `std 2`; novší plugin potom doplní predvolené 5/10/10 bez varovania. Detektor sa nerobí (predvolené = Michalove
  hodnoty; Lucia má vlastný `%APPDATA%`).

### 2.3 Nastavenia (UI) — mockup D
- `SS_SCALARS` doplniť o tri riadky **medzi „m² na platňu" a „Zaokrúhlenie"** (poradie z mockupu D), `inputmode="decimal"`.
- **Klientská kontrola rozsahu** (okrem dnešného „nečíslo"): pole mimo rozsahu zčervená (`.bad`) a „Uložiť" povie dôvod ľudsky; server ostáva autorita.
- **Tooltip „?"** pri troch nových riadkoch (texty z mockupu D — prerez: „šírka rezu kotúča… počíta sa medzi dielcami a medzi pásmi, nie pri okraji; platí
  pre všetky zákazky"; orez: „…pracovná doska, kompakt a zástena sa neorezávajú"; prídavok: „každá vrstva dupláku (2 aj 3 vrstvy)…"). Štúdio tooltip dnes nemá
  → nový malý prvok (CSS v `studio.html`, rovnaký vzhľad ako `.nxtip` Inspectora; žiadne `title` s dlhým textom).
- **Guard zhody** zoznamu skalárov Ruby (`SCALAR_DEFAULTS`) ↔ JS (`SS_SCALARS`) — nový test.
- Prerez v NP-2 **nič nepoužije** (plán sa zobrazí až v NP-3) — tooltip to nesmie zamlčať („použije ho nárezový plán").

### 2.4 Kontrola „nezmestí sa" (O9)
- `Validation.run` dostane nový kwarg (pracovne **`layout:`** = `{params:, edge_thicknesses:}`); **obaja volajúci** v `ProductionCore` (control_payload aj klik
  na nález) ho posielajú z tej istej funkcie (jedna pravda; guard test_1b3 upraviť na nový tvar, počet volaní ostáva 2). `edge_thicknesses` = `vepo_edge_thicknesses`
  (alebo odvodené z `edges`); **`edges: nil` nesmie vypnúť oversize**.
- `check_oversize` pre každý záznam s katalógovým materiálom, ktorý nie je UNI a má platný formát (dnešné podmienky ostávajú): `SheetLayout.purchase_rect(record,
  sheets:, edge_thicknesses:, params:)` → keď vráti geometriu (aj pri `ok:false` kvôli ABS/hrúbke/väzbe dupláku — kontrakt NP-1), `fits_rect?(rect,
  allow_rotation: SheetLayout.rotation_allowed?(grain))` (NP-1: otáča sa všetko okrem `length`/`width` — dnešné správanie: prázdny aj neznámy smer = obe polohy). Bez geometrie (`invalid_row`, `zero_after_rounding`)
  → oversize sa nehlási (iné nálezy to pokryjú). **Kľúč nálezu sa nemení**; **jeden nález na záznam** (duplák = jeden hotový dielec).
- **Text nálezu:** „<názov> <l> × <w> mm sa nezmestí na platňu <L> × <W> mm **po oreze <t> mm (použiteľná plocha <Lu> × <Wu> mm)**" — časť o oreze len pri
  `t > 0`; pri dupláku doplniť „(duplák — N prírezov <l+2p> × <w+2p> mm)". Rozmery s desatinnou čiarkou len keď treba.
- **Priznané zmeny výsledku:** dielce s dĺžkou medzi použiteľnou dĺžkou a formátom (napr. 2781–2800 mm pri oreze 10) a dupláky nad (použiteľná − 2 × prídavok)
  sú odteraz **RED** — fyzicky ich VEPO nevyrobí; dva PC s iným orezom dajú pre ten istý model iný nález; zaokrúhlenie ako vo VEPO posúva hranicu o < 0,5 mm.
- `Validation.fits_on_sheet?` ostáva ako **tenký obal** nad `SheetLayout.fits_rect?` s orezom 0 (priame testy test_k1 a test_kon0 bez zmeny); STANDARD §3.3
  :375 doplniť, že Kontrola aj plán idú cez spoločnú prípravu NP-1.

### 2.5 Dokumentácia
- STANDARD: nová krátka podkapitola **„Nastavenia dodávateľa (globálny súbor)"** — skaláre vrátane troch nových, verzia 2, dopredná brána, priznaný limit
  v0.15.0; §10 (Kontrola) — `oversize` s orezom podľa typu a prídavkom dupláku, otáčanie len pri dielci bez smeru; §3.3 zmienka.
- `docs/architecture/outputs.md` — odsek `validation.rb` (oversize) a **nový obsah odseku `supplier_settings.rb`** (dnes „zatiaľ nezdokumentované");
  `docs/architecture/ui-lifecycle.md` — odsek `supplier_settings_dialog.rb` (nové polia, banner, tooltip).

## 3 · Scope OUT

Nárezový plán v Štúdiu a poznámka v Rozpočte (NP-3) · ceny podľa plánu (NP-4) · otáčanie v pláne (N8) · detektor „starší plugin zahodil polia" · nové texty
po uložení (ostávajú „Nastavenia uložené" / „Rozpočet je prepočítaný.") · nastavenia per zákazka · brána pri R-11 v iných súboroch.

## 4 · Testy a DoD

1. **Nastavenia (headless):** predvolené 5/10/10 po čistom seede aj po upgrade súboru std 1 (skaláre doplnené, pri prvom zápise std 2) · desatinné s čiarkou
   aj bodkou · hranice rozsahov (0, max, max + 0,01, záporné, `Infinity`, text) · tri kľúče sa naozaj uložia · ľudská chyba rozsahu · `layout_params` ·
   **dopredná brána:** súbor std 3 → čítanie áno, `patch_active!` odmietnutý s dôvodom, seed-merge nezapíše, súbor na disku bajtovo nezmenený · poradie
   zámok < degraded < novší < zápis (guard) · payload `settings_state` pre ok/degraded/newer.
2. **UI (JS):** tri riadky na správnom mieste · `inputmode` · klientská kontrola rozsahu a `.bad` · tooltip sa vykreslí · banner a vypnuté „Uložiť" pri `newer`
   a `degraded` · guard zhody Ruby ↔ JS zoznamu skalárov.
3. **Kontrola (headless):** dielec 2785 × 500 na DTD 2800 × 2070 pri oreze 10 → RED s textom „po oreze 10 mm (použiteľná plocha 2780 × 2050 mm)"; pri oreze 0 bez
   nálezu · pracovná doska 4100 × 600 s dielcom 2400 × 600 → bez nálezu (bez orezu) · duplák 2765 × 580 → RED (vrstva 2785 × 600), jeden nález, text s prírezmi ·
   dielec bez smeru 2000 × 2500 → bez nálezu (otočí sa), s `grain 'length'` → RED · súbežná chyba ABS/drift + oversize → oba nálezy (test_validation.rb:164 ostáva
   zelený) · UNI a chýbajúci formát → bez nálezu · kľúč nálezu nezmenený · obaja volajúci `Validation.run` dávajú rovnaký výsledok (klik na nález nájde nález).
4. **Mutácie (min. 6):** zápis bez pečiatky std · brána len pri zápise, nie pri seed-merge · orez aj pri PD · bez prídavku dupláku v Kontrole · `allow_rotation` pri
   `length` · jeden z dvoch volajúcich bez `layout:` · klient bez kontroly rozsahu.
5. Celá headless sada a všetky JS sady zelené.

## 5 · Riziká

Nové RED v existujúcich zákazkách (hraničné dielce, dupláky) — priznať v PR a KRONIKE ako zámer (fyzicky nevyrobiteľné) · rozdielne nastavenia na dvoch PC ·
brána zablokuje uloženie, ak by súbor omylom mal vyššiu verziu (hláška musí povedať prečo a čo robiť).

## 6 · Smoke pre Michala

Nastavenia rozpočtu → tri nové polia s „?", uloženie 4,4 mm prerezu, hodnota mimo rozsahu zčervená · Kontrola: bok 2790 mm v DTD → červený nález s použiteľnou
plochou; orez 0 → nález zmizne; pracovná doska 600 široká bez nálezu · duplák 36 dlhý 2770 → červený nález s prírezmi.

## 7 · Checklist uzáveru

Bump VERSION (2×) + všetky `?v=` · headless + všetky JS sady · STANDARD (nastavenia dodávateľa, §10, §3.3) · outputs.md (`validation.rb`, `supplier_settings.rb`) ·
ui-lifecycle.md (`supplier_settings_dialog.rb`) · prepis STAV · KRONIKA navrch · PLAN NP-2 ✅ + PR · package + surový audit do priečinka bloku.

## Nálezy krížového auditu a rešerše, ktoré rieši NP-2

| Nález | Verdikt | Kde |
|---|---|---|
| C4 · nové nastavenia zahodí starší plugin | berieme — verzia 2 + dopredná brána; v0.15.0 priznaný limit | §2.2 |
| C9 · jedna pravda „zmestí sa" pre plán aj Kontrolu | berieme — Kontrola cez `purchase_rect` + `fits_rect?` z NP-1 | §2.4 |
| G4 · Kontrola a plán jednou funkciou, veta s použiteľným rozmerom, UNI/fallback bez nálezu | berieme; iný orez na dvoch PC = iný nález (priznané) | §2.4 |
| G6 · nastavenia s rozsahmi | berieme | §2.1, §2.3 |
| Q4 · 1–2 · prerez 4,4 bežný (4–5), orez 10–15 | Michal: 5 a 10 (N3), rozsahy 0–10 / 0–50, desatinné | §2.1 |
| Codex #416 (mockup) · desatinný prerez; Kontrola pri dielci bez smeru otáča | berieme | §2.1, §2.3, §2.4 |

## Nálezy auditu návrhu (Codex `gpt-6-astra`, 29.9.2026) — zapracované (majú prednosť pred textom vyššie)

Surový výstup: `AUDIT_NP2_2026-09-29.md` (implementátor ho pridá do priečinka bloku zo scratchpadu `AUDIT_NP2_raw.md`, bez riadkov s ID relácie).
Verdikt: **2 BLOCKER · 2 FIX · 2 NOTE — všetky prijaté.**

| # | Nález | Zapracovanie |
|---|---|---|
| B1 | Preskočenie záznamu bez geometrie (`invalid_row`, `zero_after_rounding`) odstráni jediný RED — dnes `3000 × 0` a `3000 × 0,4` majú len `oversize` | §2.4 mení sa: záznam, pre ktorý `purchase_rect` nevráti geometriu, dostane **nový RED nález „neplatný výrobný rozmer"** (kategória napr. `invalid_dims`, kľúč `invalid_dims\|owner_id\|part_key`, text: „<názov>: výrobný rozmer <l> × <w> mm je neplatný (nula alebo nečíslo po zaokrúhlení na celé mm) — dielec sa nedá objednať"); regresný test cez `Bom.record → Validation.run` (3000 × 0, 3000 × 0,4, NaN) |
| B2 | Náhradné (seed) nastavenia pri chybe čítania potichu zmenia výrobný verdikt (orez 50 → 10) | §2.1 mení sa: čítanie nastavení **zachová pôvod** — `layout_params` vráti `{params:, source: :file \| :backup \| :seed_fallback \| :newer_file}` (`load` dnes chybu pohltí — pridať príznak pôvodu do načítaného dokumentu, nie rescue v `layout_params`); pri `:seed_fallback` Kontrola pridá **ORANGE nález** „Nastavenia prerezu a orezu sa nepodarilo načítať — Kontrola počíta s predvolenými 5 / 10 / 10 mm" (jeden nález, bez dielca) a Nastavenia rozpočtu ukážu banner; test s poškodeným súborom bez zálohy |
| F3 | Priame `vepo_edge_thicknesses` pri chybe katalógu ABS zhodí celú Kontrolu | §2.4 mení sa: hrúbky ABS sa odvodia z **už načítanej** mapy `edges_map` (tá chybu zachytí → `nil`); pri `nil` Kontrola pokračuje rozmerovými kontrolami (geometriu `purchase_rect` vráti aj pri „neznámej ABS"); test s vyvolanou chybou čítania katalógu ABS (nie len `edges: nil`) |
| F4 | Dopredná brána s 1 s cache nemusí vidieť novší súbor uložený medzičasom | §2.2 mení sa: verzia sa pri `write` číta **čerstvo priamo pod zámkom** (bez cache `JsonFileStore`); test „nahriata cache → novší súbor na disku → priame `write`" = odmietnuté |
| N5 | RED „nezmestí sa" nedokazuje nevyrobiteľnosť — kontrola porovnáva hotový rozmer s ABS, VEPO si ABS odpočíta (2782 mm s 2 mm ABS na oboch koncoch = doska 2778) | priznať: text nálezu hovorí „hotový rozmer vrátane ABS", STANDARD a outputs.md uvedú, že kontrola je opatrná (ABS neodpočítava — prípadný prídavok na prefrézovanie nie je známy); hraničný test s ABS dokumentuje správanie |
| N6 | Limit starších verzií zahŕňa aj v0.15.1 (NP-1 bránu nemá) | priznaný limit = „verzie pred NP-2, teda **v0.15.1 a staršie**" (STANDARD, outputs.md, PR) |

## Doplnenie počas implementácie (29.9.2026)

**Skutočné API NP-1 (platí pred pracovnými názvami vyššie):**
- `SheetLayout.purchase_rect(hash, sheets:, edge_thicknesses:, params:)` vracia geometriu (`l`, `w`, `usable`, `trim`, `grain`, `sheet_size`,
  `fallback`, `uni`) aj pri `ok: false`, keď dôvod s rozmermi nesúvisí; „bez geometrie" = chýba `l`/`w`/`usable` (nielen `invalid_row`
  a `zero_after_rounding` — aj VEPO odmietnutie **nekladného** rozmeru, napr. `3000 × 0` dáva dôvod `vepo` bez geometrie). Kontrola preto
  nerozhoduje podľa dôvodu, ale podľa **prítomnosti geometrie** (`rect_geometry?`); dôvod `invalid_params` sa nehlási vôbec (parametre
  z nastavení ho nemôžu vyvolať).
- Otáčanie: `SheetLayout.rotation_allowed?(rect['grain'])` (všetko okrem `length`/`width`), nie `grain == 'none'`.
- NP-1 geometria odmietnutia nenesla `doubled`/`multiplier` — **doplnené** v `with_geometry` (veta o prírezoch dupláku aj pri súbežnej chybe ABS);
  `compute` sa nemení.

**Tvar a mená (pracovné názvy → implementácia):**
- `layout:` kwarg `Validation.run` = `{params: {'kerf','trim','dup_allowance'}, source:, edge_thicknesses:}`; **bez `layout:`** (legacy volania,
  headless testy) = orez 0 a prídavok 0 — správanie pred NP-2, existujúce testy Kontroly bez zmeny.
- `SupplierSettings.layout_params` → `{params:, source:}`, `source` ∈ `:file | :backup | :newer_file | :seed_fallback`. Pôvod sa určuje
  v `load_with_origin` (čítanie), `:backup` až v `active_with_source` (`JsonFileStore.degraded?` číta disk, `load` beží pri každom výpočte).
- Payload sekcie: `settings_state` = `{state: ok | degraded | newer | fallback, reason}` (+ `scalar_ranges` pre klientsku kontrolu rozsahu).
  Pri `fallback` sa „Uložiť" **nevypína** (prvý zápis súbor opraví, revízia chráni cudziu zmenu) — banner je jantárový.
- ORANGE nález fallbacku: kategória **`layout_settings`**, `stable_key` `layout_settings|seed_fallback`, bez vlastníka; klik vedie do sekcie
  Nastavenia rozpočtu (klient, vzor rozpočtového nálezu).
- Text `oversize`: „Dielec „X“ (CAB-1) L × W mm (hotový rozmer vrátane ABS) sa nezmestí na platňu 2800 × 2070 mm po oreze 10 mm
  (použiteľná plocha 2780 × 2050 mm) — duplák: 2 prírezy 2785 × 600 mm (materiál DTD)." — pri 2–4 vrstvách „prírezy", inak „prírezov".
- Chyba rozsahu menuje pole popisom zo `SCALAR_LABELS` pre **všetky** skaláre (test `test_cp_export.rb` upravený z kľúča na popis).

**Nad rámec package (nutné pre regresiu B1):** Kontrola názvov (`name_check_records`) vynechá záznam s nečíselným rozmerom — `Bom.dmm` pri
NaN vyhodí `FloatDomainError` a zhodila by celú Kontrolu skôr, než by `invalid_dims` vznikol (dnes sa to v praxi nestane — JSON NaN nenesie —,
ale regresný test NaN to vyžaduje).
