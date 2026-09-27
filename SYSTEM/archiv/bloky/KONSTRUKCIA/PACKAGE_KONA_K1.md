# Package KON-A · K1 — komín vzadu, zapustený strop vpredu, oprava D-144

> **Blok 7 · KONŠTRUKCIA K1+K2**, druhá dávka. **Package v2** (27.9.2026) — zapracovaný audit návrhu (NOT SOUND: 1 BLOCKER · 5 FIX · 2 NOTE —
> všetko vyriešené v Scope IN, prehľad v sekcii „Audit návrhu KON-A" na konci). Autorita počas dávky: tento package.
> Podklady v `SYSTEM/zdroje/bloky/KONSTRUKCIA/`: [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md) (M1–M3, M9–M11),
> [VSTUPY_PRE_PACKAGES_2026-09-27.md](VSTUPY_PRE_PACKAGES_2026-09-27.md) (KON-A), schválený mockup
> [MOCKUP_KONSTRUKCIA_2026-09-27.html](MOCKUP_KONSTRUKCIA_2026-09-27.html) (sekcia A; sekcia B — bokorys — zamietnutá), fakty z kódu
> [FAKTY_Z_KODU_2026-09-26.md](FAKTY_Z_KODU_2026-09-26.md) §1–§3, §9–§14, krížový audit (Codex B2, FIX 5–7, 9, 10, 13; Grok 2, 3, 9),
> audit návrhu [AUDIT_KONA_2026-09-27.md](AUDIT_KONA_2026-09-27.md).
> **Trieda:** výrobná + **audit-povinná** (`CONFIG_SCHEMA` 19 → 20, geometria dielcov, register výrobnej brány) → `codex-audit` hotový ·
> predrecenzia pred PR · **in-SU test je brána mergu** · GH Codex review. Verzia v0.13.1 → **v0.13.2**.

Značky: `d` celková hĺbka vrátane chrbta (D-37) · `w` šírka · `h` výška · `t` hrúbka korpusu · `bt` hrúbka chrbta · `s` výška sokla/nôh ·
**`X` komín** (`back_setback`) · **`Y` zapustenie stropu** (`top_front_setback`) · **`R` zadný doraz** dna, stropu a zadnej výstuhy ·
`cd` = dnešná `Construction.carcass_depth` · os **+Y ide dozadu**, čelná rovina Y = 0 (STANDARD §3.2). Riadky kódu = main `50efa1fc`.

## Cieľ (z pohľadu stolára)

- **Komín vzadu X** (M1, M2): dno, strop a zadná výstuha končia o X skôr ako boky; chrbát sa posunie dopredu na ich zadné hrany a za ním vznikne
  vzduchový kanál (bežne 50 mm). Skrinka drží zadanú celkovú hĺbku; boky majú plnú hĺbku.
- **Zapustenie stropu Y** (M3): plný strop alebo predná výstuha začína o Y za prednou hranou boku; dno sa neposúva; dolná aj horná skrinka.
- **Nika spotrebiča pri komíne** (M9) sa meria z hĺbky boku.
- **D-144:** vložený chrbát a chrbát v drážke pri výstuhách **na výšku** končí pod výstuhami (dnes nimi prechádza a v kusovníku je vyšší, než sa zmestí).
- **Pri X = 0 a Y = 0 sa nemení nič** — golden plány bajtovo rovnaké, žiadne nové odmietnutie — okrem opravy D-144.

## Scope IN

### 1 · Dáta a kontrakt

1. **Polia `back_setback` (X) a `top_front_setback` (Y):** Float mm, ≥ 0, predvolene 0 pre `lower` aj `upper`. **Prísne parsovanie** (audit FIX 5 —
   vzor `plinth_recess` s `.to_f` nestačí: `"50oops"` → 50, `NaN` ostane `NaN`): platné je len konečné číslo (Numeric alebo reťazec, ktorý je celý
   číslom); čokoľvek iné → 0; potom klamp **0–300**. Slot umývačky ich ignoruje (jeho plán konštrukčné polia nečíta) a nezapisujú sa mu.
2. **Zápis do configu** (`CabinetBuilder.cabinet_config`, `cabinet_builder.rb:2786`): ploché kľúče **len keď je hodnota > 0** (vzor S1-E
   „zapisovať len keď treba", `DW_KEYS` r. 2860) — config existujúcich skriniek sa pri prestavbe nemení; vnorené odvodené objekty `top`/`back` bez
   zmeny. V normalizovaných parametroch vždy číslo (chýbajúci kľúč = 0).
3. **Uzavretá reťaz whitelistov** (FAKTY §1): `normalize` (`:2991`) · `cabinet_config` · `config_to_params` (`:3845`, chýbajúci kľúč → 0.0; ide cez
   neho **všetkých 15 volaní** — prestavba, absorpcia mierky, kópie, dedup kópií, „Nahradiť UNI", hromadné zmeny…) · `Panel::PARAM_KEYS`
   (`actions_cabinet.rb:15`) · JS `CONSTRUCTION_FIELDS` (`core.js:1599`) + HTML · `Panel.template_config_from` — **nové šablóny zapisujú X aj Y
   výslovne, aj 0** (Codex FIX 7) · `TemplatesDialog.merge_template` — kľúč v šablóne = hodnota šablóny (aj 0); **kľúč chýba (stará šablóna) =
   zachová hodnotu cieľa** (vzor D-13 `plinth_recess`, M10) · JS `DEFAULTS`/`LIMITS` (`form.js:149`).
4. **JS mimo `CONSTRUCTION_FIELDS`** — tri samostatné zoznamy polí, ktoré sa samé nerozšíria (audit FIX 2, FIX 3): DOM most `currentCarcass`
   (`core.js:1582`) a `pvGeom` (`preview.js:385`) — výpočty výstuh, hĺbky a odhadu inak bežia bez X/Y (príklad auditu: `d` 260, X 50, Y 70 → limit
   flat výstuhy 60 mm, starý most ponechá 100); **ochrana výrazov** `bindExprFields` (`boot.js:63`) — bez pripojenia môže debounce pri písaní `50-20`
   odoslať medzistav `50-2` (komín 48).
5. **Riedky config v JS** (Codex FIX 9): zápis configu do formulára (`writeConstruction`, `core.js:1615`; `setNum` `core.js:1519` chýbajúcu hodnotu
   ignoruje) musí pri chýbajúcom kľúči nastaviť predvoľbu 0 — inak pole ukáže komín predchádzajúcej označenej skrinky a „Aplikuj" ho ticho zapíše inej.
6. **Guard parity konštrukčných polí** (dnes len pre polia slotu, `test_s1e_slot.rb`): `normalize` ↔ `PARAM_KEYS` ↔ `CONSTRUCTION_FIELDS` ↔
   `template_config_from` ↔ `currentCarcass` ↔ `bindExprFields` + hodnotový round-trip `cabinet_config` → `config_to_params` → `normalize` pre X a Y
   (0 aj > 0).
7. **`CONFIG_SCHEMA` 19 → 20** (`cabinet_builder.rb:280`) + `HISTORIA` (K1 komín a zapustenie, D-144) — dopredná a exportná brána R-12 zastaví
   starší plugin (overené auditom: schéma 19 odmietne prestavbu schémy 20 a zastaví všetky štyri exporty pred výberom súboru). Nová aktivačná
   konštanta D-144 **= 20** (vzor `BACK_CUT_ACTIVATION_SCHEMA` `:315`). BuildPlan `SCHEMA`, `PartKeys::SCHEMA` a ABS `SEED_VERSION` **bez zmeny**
   (žiadna nová rola, kľúč plánu ani pravidlo olepu).

### 2 · Geometria (`construction.rb` — jediná autorita; JS zrkadlá v bode 6.8)

1. **Dva pomocníky na jednom mieste** (audit B2): **zadný doraz `R`** = `X = 0` → dnešná `carcass_depth` (`d − bt` pri `overlay`, inak `d`,
   `:1242`); `X > 0` → `d − X`. **Hĺbka bokov** = `X = 0` → `carcass_depth`; `X > 0` → **`d` vo všetkých režimoch chrbta**. `carcass_depth` ostáva
   (D-37 pri X = 0); jej doterajší čitatelia — boky (`:1384`), dno (`:1401`), strop (`:1415`), výstuhy (`:1432`), `rail_geometry` (`:1263`),
   nohy (`cabinet_builder.rb:2461`) — prejdú na správneho pomocníka.
2. **Dielce pri X > 0** (pri X = 0 sa všetko rovná dnešku okrem D-144):

| Dielec | Pri komíne X > 0 |
|---|---|
| Boky | hĺbka **`d`** (pri `overlay` teda o `bt` dlhšie ako dnes) |
| Dno | hĺbka **`R`** |
| Strop plný | origin `y = Y`, hĺbka **`R − Y`** |
| Výstuhy (`two_rails`) | predná origin `y = Y`; zadná končí na `R` (flat origin `R − rd`, upright `R − t`) |
| Chrbát `overlay` | **medzi bokmi**, naložený na zadné hrany dna a stropu: box `[w − 2t, bt, h − s]`, origin `[t, R, s]` |
| Chrbát `groove` | geometria ako `overlay` pri komíne (M2 — drážka len v bokoch); `cut_size = {w, h − s}` (pravidlo KON-0) |
| Chrbát `inset` | zadná plocha v rovine `R`: origin `[t, R − bt, z_lo]`, výška podľa bodu 2.4 |
| Chrbát `none` | žiadny dielec (D-31) |

   **Zapustenie Y platí aj pri X = 0** (plný strop a predná výstuha od `Y`, doraz `R` = dnešná `carcass_depth`); pri strope „Bez stropu" nemá význam.
   Užší naložený chrbát aj dlhšie boky idú do výstupov cez existujúce snapshoty a `Bom.cut_dims` — nový exportný vzorec netreba (overené auditom).
3. **Vnútorná hĺbka** `interior_dims.back_front_y` (`:1354`, jediná autorita, FAKTY §3): `overlay` **R** · `groove` X = 0 → `d − 10 − bt`, X > 0 → **R** ·
   `inset` **R − bt** · `none` **R**. Pri X = 0 hodnoty = dnes. Konzumenti (zóny, police, priečky, recepty zásuviek a NL výsuvu, chipy osí, legacy
   výsuv, HL výklop, „Vnút. hĺbka") sa zmenia automaticky — **vedomá výrobná zmena** (M10), bez nových prahov.
4. **D-144** (`back_z_hi`, `:1467`): horná hrana chrbta `inset`/`groove` pri `two_rails` = **nižšia z dnešnej (`h − offset − t`) a spodnej hrany
   výstuh (`interior.z_hi`)** — mení sa len pri výstuhách na výšku vyšších než hrúbka korpusu; platí pri každom X. **Chrbát v drážke pri D-144 (X = 0):**
   `cut_size.width = (h − s) − Δ`, **`Δ = max(occupy − t, 0)`** (`occupy` = použitá výška výstuhy z `rail_geometry`) — do nárezu klesne o ten istý rozdiel
   ako horná hrana v modeli; `length` ostáva `w` (VSTUPY: „do nárezu sleduje hornú hranu pod výstuhami"; potvrdené auditom). Príklad: dolná 720,
   sokel 100, `t` 18, výstuhy na výšku 100 → model dnes 564 × 584, po oprave **564 × 502**; do nárezu dnes 600 × 620, po oprave **600 × 538**.
   Pri X > 0 stojí chrbát v drážke **za** výstuhami (končia na `R`) → plná výška `h − s`, D-144 sa ho netýka.
5. **Nohy (proxy)** (`draw_legs`, `cabinet_builder.rb:2458`): zadný rad aj voľba „jeden/dva rady" podľa hĺbky dna **`R`** (dnes `carcass_depth`);
   pri X = 0 bez zmeny (Grok 9).
6. **Box niky chladničky:** bez zmeny, **neorezáva sa** (ukazuje celý požadovaný priestor).

### 3 · Nika spotrebiča (M9)

Jeden pomocník **hĺbky niky**: `X > 0` → **hĺbka boku `d`**; `X = 0` → `back_front_y` (dnešné meranie po chrbát). Čítajú ho **obaja** dnešní
čitatelia: `ApplianceChecks.context` (kontrola niky, `appliance_checks.rb:88`) a `Panel.appliance_interior` (ponuka „zmestí sa", `payloads.rb:669`)
— rovnaké číslo na oboch miestach. Platí pre všetky druhy s osou hĺbky (chladnička, rúra, mikrovlnka); vetranie tým overené nie je.

### 4 · Validácia (odmietnutie prestavby zrozumiteľnou vetou; model sa nezmení; zrkadlo v paneli 6.6)

1. **Minimum nenulového komína podľa účinného režimu chrbta** (M10): `overlay` **X ≥ bt** · `groove` **X ≥ 10 + bt** · `inset`, `none` bez minima
   (skrytá hrúbka chrbta pri `none` sa nepočíta). Veta napr. „Komín pri chrbte v drážke musí byť 0 alebo aspoň 13 mm (drážka 10 + chrbát 3)."
2. **Minimum vnútra pri komíne** (audit **BLOCKER 1**): pri **X > 0** musí ostať `back_front_y ≥ SHELF_FRONT_INSET + ZoneTree::MIN_FIELD`
   (= **40 mm**, najmenšia polica, akú systém pozná) — inak odmietnutie („Pri komíne 150 mm ostane vnútro len 11 mm — police sa nezmestia; zmenši
   komín alebo zväčši hĺbku."). Dôvod: úspešný plán dnes nezaručuje zachovanie dielcov — pri vnútre ≤ 20 mm `ZoneTree.add_shelves` police
   **vynechá len s ORANGE** (`zone_tree.rb:550`, `validation.rb:1663`) a export ich nezastaví; sonda auditu (`d` 161, X 150, bez chrbta, bez stropu)
   to potvrdila. Pri X = 0 ostáva dnešné `back_front_y ≤ 10` („Hĺbka je príliš malá", `:1548`) bez zmeny.
3. **Plný strop:** `R − Y ≥ 60` (mockup A) — inak odmietnutie („Zapustenie 70 mm nenechá strop — ostalo by z neho 40 mm.").
4. **Výstuhy v intervale Y … R** (audit FIX 5 bloku, Grok 4) — **platí len pri X > 0 alebo Y > 0** (audit **FIX 4**: pri X = Y = 0 by pravidlo odmietlo
   dnes platnú skrinku `d` 150, `t` 50, `bt` 50, overlay, upright); pri X = Y = 0 ostáva dnešná logika `rail_geometry` bez zmeny: flat limit
   **`(R − Y)/2 − 10`** — väčšia hĺbka pásu sa oreže s upozornením `rail_depth_clamped` (ako dnes); **ak by orezaná hodnota klesla pod 20 mm →
   odmietnutie** (dnes vyhrá minimum 20 a výstuhy sa môžu prekryť); upright: **`Y + 2t + 20 ≤ R`**, inak odmietnutie (hrúbku orezať nemožno).
5. **Pri X = Y = 0 žiadne nové odmietnutie** — body 1–4 sa pri nulových hodnotách neuplatnia (bod 3 pri Y = 0 v rozsahoch `normalize` nezasiahne:
   `R` ≥ 100); implementátor to dokáže testom (golden plány + existujúce matice bez zmeny + sonda hraničných configov z auditu).
6. Semafor **bez nových prahov** (M10): dôsledky hlási existujúca Kontrola (NL výsuvu, HL výklop, nika, orezanie výstuh).

### 5 · Mierka (Scale) — config-aware minimum hĺbky (Codex FIX 10, Grok 9)

`Construction.min_valid_depth(cfg)` **tým istým vzorom ako `min_valid_height`** (`:1299` — sonda cez celý `build_plan`, žiadny druhý vzorec) —
sonda tak dedí aj pravidlá 4.1–4.4 vrátane minima vnútra 4.2 (audit BLOCKER 1: samotný úspech plánu bez neho nestačil). `ScaleWatch.absorb`
(`scale_observer.rb:475`) klampuje hĺbku na prísnejšie z `MIN['depth']` a `min_valid_depth` (vzor `clamp_height` `:561`) a keď hĺbku zdvihne kvôli
konštrukcii, dá **nemodálnu hlášku** (`notify_user`, napr. „Hĺbka skrinky CAB-004 je pri komíne 100 mm najmenej 160 mm — nastavená na 160." —
naložený chrbát, plný strop). Jeden krok Späť (transparentná operácia ako dnes). Flat výstuhy sa pri menšej hĺbke orežú s upozornením (4.4). Tichá
odmietacia cesta rejectu (`construction.md`) sa pri hĺbke týmto nedosiahne; pre iné príčiny ostáva mimo dávky. Sondovať stačí pri zmenšení hĺbky.

### 6 · UI — Inspector, kontext Korpus, sektor Nastavenia (schválený mockup, sekcia A; bez nových skupín)

1. **Strop:** riadok **„Zapustenie vpredu __ mm"** hneď pod Konštrukciou (`panel.html:438`); pri „Bez stropu" skrytý, hodnota sa pamätá (vzor
   `backThRow`); platí pre plný strop aj dve výstuhy (A1).
2. **Chrbát:** riadok **„Komín vzadu __ mm"** hneď pod Konštrukciou (`:489`) pre každý režim chrbta (A4); tooltip: čo je komín, minimum podľa režimu
   a **voľný kanál** podľa režimu — `overlay`/`groove` `X − bt`, `inset` `X`, pri „Bez chrbta" sa kanál neukazuje (Codex #13).
3. **Skupina Boky zaniká** (A2 — dnes len text „pribudnú v ďalšej verzii", `:479–484`).
4. **Šedá veta pod Chrbtom** (`:505`) → tooltip „?" pri Konštrukcii (A6, pravidlo D-130a).
5. **Súhrn v zbalenej hlavičke** skupiny len pri nenulovej hodnote: Strop „zap. 30", Chrbát „komín 50" (A7, vzor meta skupín Čelá).
6. **„Vnút. hĺbka"** podľa posunutého chrbta (A8); neplatný komín/zapustenie/výstuhy/vnútro → pole červené + stavová veta, tá istá, akou by server
   odmietol — zrkadlo validácie bodu 4 vzorom `cabinetHeightError` (`form.js:200`).
7. **Slot umývačky:** riadky skryté.
8. **JS zrkadlá v tej istej dávke** (Codex FIX 9): `nxCarcassDepth` (`core.js:1545`) → pomocníky `R` a hĺbky bokov · `nxRailGeom` (limit s `Y` a `R`,
   nové odmietnutia len pri X > 0 alebo Y > 0) · samostatný vzorec „Vnút. hĺbka" v `updateAvailable` (`form.js:561`) · `LIMITS` · zrkadlo validácie
   (6.6) · mosty `currentCarcass` a `pvGeom` (bod 1.4) · **`nxDraftStats`** (`preview.js:492`, odhad vo vkladaní — audit NOTE 7): všetky spotreby
   hĺbky (dno a strop do `R`, strop od `Y`, police a priečky podľa vnútra) a užší naložený chrbát pri komíne. **Hodnotové testy parity Ruby ↔ JS**
   na spoločných prípadoch (vzor `test_interior_height.js` + Ruby strana) **a integračný test formulár → kontext → výpočet** (parita nad ručne
   vytvorenými objektmi chybu mosta nezachytí — audit FIX 2).
9. **Vklad zo šablóny** prenesie X a Y do novej skrinky (cez `CONSTRUCTION_FIELDS` alebo serverové dosadenie z uloženého záznamu, vzor
   `apply_template_slot_fields!`) — test.
10. Bokorys ani iné kreslenie v náhľade **nie** (M11, D-145).

### 7 · D-144 — skrinky postavené pred opravou

1. **Zastaraná skrinka:** chrbát `inset`/`groove` + strop `two_rails` + výstuhy `upright` + `config_schema < 20`. Režimy čítať rovnako ako
   `config_to_params` (`back_mode || legacy back.mode`, `top_mode || legacy_top`, `rails_orientation || 'flat'`); výrobné rozmery sa pri kontrole
   **nepočítajú** (vzor KON-0 `Bom.back_stale?`, `bom.rb:1411`). Predikát je **konzervatívny** (audit: prijateľné) — pri výstuhe na výšku nižšej alebo
   rovnej hrúbke korpusu je poplach falošný a prestavba ho zruší; **veta preto hovorí „treba prestavbu", netvrdí preukázanú kolíziu**.
2. **Ten istý register výrobnej brány ako D-143** (`Bom::CUT_BLOCKERS`, `bom.rb:1362`): nový kód nálezu (+ záznam v `CUT_BLOCKER_TEXTS`,
   `production_core.rb:1215`) → **RED v Kontrole + tvrdý stop všetkých štyroch exportov** (`ProductionCore.cut_stop`: VEPO, nákupný CSV, rozpočet XLSX,
   ponuka XLSX) s príznakom `rebuild_stale` → existujúca akcia **„Prestaviť zastarané skrinky"** (`rebuild_many`). **Výber kandidátov** hromadnej
   prestavby (`back_stale_entry`, `production_core.rb:1249`) sa dnes pýta len `Bom.back_stale?` (D-143) — spoločný predikát musí zahrnúť **D-143 alebo
   D-144** (audit NOTE 8); test hromadnej prestavby ide **cez tento skutočný výber**. Skrinky s odpojenými dielcami vymenuje a nechá blokované (ako KON-0).
   Veta napr. „Skrinka CAB-012 má vložený chrbát alebo chrbát v drážke spolu s výstuhami na výšku zo staršej verzie — treba ju prestaviť (chrbát
   môže prechádzať zadnou výstuhou). Kontrola → Prestaviť zastarané skrinky; dovtedy výrobné exporty stoja."
3. **Texty KON-0** (audit FIX 6): nález D-143 (`bom.rb:1425`) dnes v zátvorke odporúča plný rozmer `w × (h − s)` — pri skrinke, ktorú zasiahne aj
   D-144, by odporučil 600 × 620 namiesto 600 × 538 → rozmer v texte počítať **tým istým pravidlom ako builder** (alebo ho pri D-144 vynechať).
   Hláška po hromadnej prestavbe (`back_stale_done_msg`, `production_core.rb:1305`) dnes vždy hovorí o chrbte v drážke „v plnom rozmere" → všeobecná
   veta o prestavaných zastaraných skrinkách (D-143 aj D-144).
4. **Samostatný (odpojený) chrbát:** bez značky pôvodu → ORANGE ako pri KON-0 (bez zmeny). **Priznaný zvyšok** (audit: prijateľné — nová značka by
   pôvod existujúceho kusu aj tak neobnovila): samostatný chrbát so značkou KON-0, postavený vo v0.13.1 pri tejto kombinácii, sa nerozozná — Michal
   samostatné chrbty ani túto kombináciu nepoužíva (27.9.2026).

### 8 · Dokumentácia

STANDARD §2 (config — nové polia, prísne parsovanie, zápis len > 0, `CONFIG_SCHEMA` 20), §3 (geometria: `R`, hĺbka bokov, D-37 pri komíne, D-144,
minimum vnútra pri komíne), §8.2 (`cut_size` pri D-144) · `docs/architecture/construction.md` (odseky `construction`, `cabinet_builder`,
`scale_observer` — na mieste) · `ui-lifecycle.md` (riadky Inspectora, mosty `currentCarcass`/`pvGeom`, `bindExprFields`) · `outputs.md` (D-144
v registri brány, spoločný výber kandidátov) · `model-a-identita.md` (`config_schema` — oprava zastaraného „dnes 7") · POJMY (komín vzadu, voľný
kanál, zapustenie stropu) · tento package + surový audit do `SYSTEM/zdroje/bloky/KONSTRUKCIA/`.

## Scope OUT

chrbát z líšt (KON-B) · šablóna Chladničková a riadok „komín" na dlaždici šablóny (mockup E2 → KON-D) · bokorys a iný náhľad (D-145) · vetranie
a výrezy · kontrola kolízií dielcov · per-bok odsadenia · geometrická drážka · zjednotenie Vrch/Strop · tichá odmietacia cesta mierky pre iné príčiny ·
tabuľky výsuvov per systém · slot umývačky · zmena správania `shelf_skipped_shallow_zone` pri X = 0 (v rozsahoch `normalize` nenastane).

## Dáta a kontrakt → audit ÁNO (hotový)

config (2 polia, prísne parsovanie, zápis len > 0) · `CONFIG_SCHEMA` 20 · aktivačná schéma D-144 = 20 · register výrobnej brány (nový kód + spoločný
výber kandidátov) · geometria dielcov (výrobná zmena) · `cut_size` pri D-144 · STANDARD §2, §3, §8.2.

## Testy a DoD

- **Headless:**
  - **golden plány** (`kova_golden`, `kovh_golden`, `kovc1_golden` …) bajtovo rovnaké pri X = Y = 0; kombinácia D-144 dostane **nový golden** (ak ju
    niektorý existujúci má, zmena výslovne v PR).
  - nová sada `tests/pure/test_kona_*.rb` (prefix `kon`, nie „K1/K2" — kolízia s `test_k1_smer_dekoru`): matica X ∈ {0, minimum, 50} × chrbát
    {overlay, inset, groove, none} × strop {plný, **bez stropu**, dve výstuhy naplocho, dve výstuhy na výšku} × dno {na dne, medzi bokmi} × Y ∈ {0, 30} —
    box, origin a `prod` každého dielca, `back_front_y`, `cut_size`; čísla príkladov z bodov 2.4 a Smoke.
  - validácia: minimum komína podľa režimu (hranica −1 / 0 / +1 mm), **minimum vnútra 40 pri komíne** (príklad auditu `d` 161, X 150 → odmietnutie;
    police nikdy nevypadnú), `R − Y` < 60, výstuhy flat pod 20 → odmietnutie, orezanie s upozornením, upright prekryv — aj vety; **pri X = Y = 0 žiadne
    nové odmietnutie** (hraničný config auditu `d` 150, `t` 50, `bt` 50, overlay, upright prejde ako dnes).
  - **parsovanie** X/Y: `"50oops"`, `"50-20"`, `NaN`, `Infinity`, objekt, záporné, > 300 — v `normalize` aj pri načítaní šablóny.
  - nika: X > 0 → `d` (chladnička aj rúra), X = 0 → dnešok; `ApplianceChecks` a `appliance_interior` vrátia rovnaké číslo.
  - whitelisty: guard parity + round-trip (config skrinky s X = 0 nové kľúče nemá; `template_config_from` zapíše 0; `merge_template` so starou
    šablónou zachová cieľ, s novou šablónou 0 prepíše na 0).
  - mierka: `min_valid_depth` (komín, zapustenie, výstuhy, minimum vnútra), klamp v `absorb`, hláška.
  - D-144: predikát (aj starý vnorený zápis), register brány × **každý zo štyroch exportov** (nulové volanie výberu súboru aj zápisu), spoločný výber
    kandidátov (D-143 alebo D-144), texty nálezu a hlášky po prestavbe, po prestavbe OK.
  - konzumenti: automatická NL sa pri komíne skráti; zamknutá NL, ktorá sa nezmestí → RED (existujúce); HL výklop hornej pri malej rezerve → RED.
- **JS:** parita `R`, hĺbky bokov, výstuh, „Vnút. hĺbka", `nxDraftStats` a zrkadla validácie; **integračný test formulár → `currentCarcass`/`pvGeom`
  → výpočet** (príklad auditu `d` 260, X 50, Y 70 → limit flat výstuhy 60); riedky config (prepnutie zo skrinky s komínom na skrinku bez kľúča → 0);
  **výrazy** v poliach X/Y (písanie `50-20` s prestávkou, Enter, opustenie poľa → 30, nikdy medzistav); riadky Strop/Chrbát (skrytie pri „Bez stropu"
  a pri slote); súhrn v hlavičke.
- **In-SU** (nová sekcia `run_kona`, `scripts\run_su_tests.ps1 -CloseWhenDone`, len `_dev\ENGINEtests.skp`): plán ↔ model 1:1 pre maticu (vzor
  `run_sync_back`/`run_sync_rails`) · jeden krok Späť · mierka hĺbky skrinky s komínom pod minimum → klamp + jeden krok Späť · uloženie a znovuotvorenie ·
  D-144 stará skrinka (schéma 19) → zastaraná → hromadná prestavba **cez skutočný výber kandidátov** → OK, jeden krok Späť · šablóna s komínom → na inú
  skrinku → komín prenesený; stará šablóna → komín cieľa ostane · kópia skrinky nesie komín.
- **Mutačné overenie** (min. 6 musí padať): `back_front_y` ignoruje X · boky ostanú `carcass_depth` pri X > 0 · `config_to_params` zahodí
  `back_setback` · `merge_template` so starou šablónou prepíše na 0 · D-144 bez „nižšej z dvoch" · nika pri X > 0 z `back_front_y` · chýba minimum
  vnútra pri komíne · výber kandidátov len podľa D-143 · JS riedky config nechá starú hodnotu · most `currentCarcass` bez X/Y.
- Headless + **každá** JS sada zvlášť zelené; počty do PR a KRONIKY.

## Riziká

tichá strata poľa na niektorej ceste (guard + round-trip, tri JS zoznamy mimo `CONSTRUCTION_FIELDS`) · komín mení výrobu nepriamo (police, priečky,
NL výsuvov, HL, nika) — vedomé, overiť testami · naložený chrbát pri komíne = **užší chrbát (`w − 2t`) a dlhšie boky (`d`)** — iný kusovník ·
zastarané skrinky D-144 blokujú export (zámer; Michal kombináciu nepoužíva) · druhé PC so starším pluginom zákazku neprestaví ani nevyexportuje
(schéma 20 — **aktualizovať obe PC**) · rozchod JS a Ruby čísel · klamp mierky.

## Smoke pre Michala (po mergi, v0.13.2)

1. Dolná 600 × 720 × 510 s naloženým chrbtom HDF 3: **Komín vzadu 50** → „Vnút. hĺbka" 460; kusovník: boky 510, dno a strop 460, chrbát
   **564 × 620** (medzi bokmi); zbalená hlavička Chrbát „komín 50".
2. Komín 2 pri HDF 3 → pole červené a veta; nič sa nepostaví.
3. Horná 600 × 720 × 320 v drážke: komín 12 → odmietnutie; **13** → vnútro 307 ako bez komína; do nárezu chrbát 600 × 720.
4. Strop „Zapustenie vpredu 30" (plný) → strop začína 30 mm za prednou hranou, dno nie; pri „Dve výstuhy" sa posunie predná výstuha; pri „Bez
   stropu" riadok zmizne.
5. Chladnička v skrinke 600 × 2100 × 560 bez chrbta, komín 50: kontrola niky meria **560** (hĺbka boku), dno 510.
6. Potiahni hĺbku skrinky s komínom 100 pod minimum → zastaví sa na najmenšej platnej hĺbke + hláška; jedno Späť vráti všetko.
7. Ulož skrinku s komínom ako šablónu a použi ju na inú → komín ide; stará šablóna na skrinku s komínom → komín ostane.
8. Do poľa Komín napíš `50-20` → ostane 30.
9. Aktualizuj plugin aj u Lucie (schéma 20).

## Checklist uzáveru

VERSION 0.13.2 (2×) + všetky `?v=` · testy (headless, JS, in-SU) · docs na mieste (bod 8) · D-144 plným textom do `archiv/DOGFOODING_vyriesene.md`
+ riadok INDEXU, z DOGFOODING preč · PLAN blok 7: riadky KON-A a D-144 s ✅ a `PR #?` · **STAV prepis** (v0.13.2, komín a zapustenie, D-144,
schéma 20 — aktualizovať obe PC) · KRONIKA · package + surový audit v priečinku bloku.

---

## Audit návrhu KON-A (Codex gpt-6-astra, 27.9.2026 ~08:10, 11,5 min, +5 % weekly) — **NOT SOUND: 1 BLOCKER · 5 FIX · 2 NOTE**

Surový výsledok: [AUDIT_KONA_2026-09-27.md](AUDIT_KONA_2026-09-27.md). Všetko zapracované vyššie (v1 → v2):

- **BLOCKER 1 — úspešný plán nezaručuje zachovanie dielcov:** pri vnútre ≤ 20 mm `ZoneTree` police vynechá len s ORANGE a export ich nezastaví
  (sonda: `d` 161, X 150, bez chrbta a stropu → plán bez police, bez výnimky); `min_valid_depth` postavený na úspechu plánu by takú hĺbku prijal. →
  **nové minimum vnútra pri komíne 40 mm** (4.2), mierka ho dedí cez sondu (5), matica testov doplnená o „bez stropu".
- **FIX 2 — JS mosty `currentCarcass` a `pvGeom`** majú vlastné zoznamy polí → výslovne doplnené + integračný test formulár → výpočet (1.4, 6.8).
- **FIX 3 — `bindExprFields`** (ochrana výrazov pri písaní) → X/Y pripojené + test písania (1.4, Testy).
- **FIX 4 — upright pravidlo pri X = Y = 0** by odmietlo dnes platnú skrinku (`d` 150, `t` 50, `bt` 50) → nové podmienky výstuh len pri X > 0 alebo
  Y > 0 (4.4, 4.5).
- **FIX 5 — parsovanie** (`.to_f` z `"50oops"` spraví 50, `NaN` prejde) → prísne parsovanie konečného čísla (1.1) + testy neplatných vstupov.
- **FIX 6 — texty KON-0** by pri D-144 odporučili zlý rozmer a hláška po prestavbe hovorí len o drážke → texty podľa pravidla buildera (7.3).
- **NOTE 7 — `nxDraftStats`** používa celkovú hĺbku aj pre police a priečky → všetky spotreby hĺbky (6.8); výrobu neriadi.
- **NOTE 8 — výber kandidátov hromadnej prestavby** pozná len D-143 → spoločný predikát D-143 alebo D-144 + `CUT_BLOCKER_TEXTS` (7.2).
- **Odpovede na otázky:** D-144 `cut_size` áno s `Δ = max(occupy − t, 0)` · predikát bez rozmerov prijateľný, veta nesmie tvrdiť kolíziu · samostatný
  chrbát z v0.13.1 = priznaný zvyšok · 60 mm a 0–300 OK · upright pri nulách → FIX 4 · mierka: klamp s hláškou OK po oprave minima · nika z hĺbky boku
  aj pre rúru a mikrovlnku áno · zápis len > 0 a nezmenené `top`/`back` áno · `config_to_params` má **15 volaní**, nie 18.
