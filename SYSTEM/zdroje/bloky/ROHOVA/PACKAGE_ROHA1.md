# Package ROH-A1 · jadro rohovej skrinky (K3)

> **Blok 8 · K3 ROHOVÁ SKRINKA**, prvá kódová dávka. **Package v2** (28.9.2026 ~00:45) — zapracovaný krížový audit bloku (triáž v sekcii
> „Reconcile", plné vyhodnotenie v [RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md](RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md)) **a audit návrhu ROH-A1**
> (1 BLOCKER · 3 FIX · 1 NOTE — všetko v Scope IN, prehľad v sekcii „Audit návrhu ROH-A1" na konci). Autorita počas dávky: tento package. Podklady v `SYSTEM/zdroje/bloky/ROHOVA/`: [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md)
> (R1–R9), [DC_ROHOVA_GEOMETRIA_2026-09-27.md](DC_ROHOVA_GEOMETRIA_2026-09-27.md) (presné polohy dielcov DC), [FAKTY_Z_KODU_2026-09-27.md](FAKTY_Z_KODU_2026-09-27.md)
> (`súbor:riadok` na main `44a9d2d4`), [CROSS_AUDIT_CODEX_2026-09-28.md](CROSS_AUDIT_CODEX_2026-09-28.md), [CROSS_AUDIT_GROK_2026-09-28.md](CROSS_AUDIT_GROK_2026-09-28.md),
> [RESERS_OUTSIDE_IN_2026-09-27.md](RESERS_OUTSIDE_IN_2026-09-27.md). Implementátor pridá tento package (a audit návrhu) do priečinka bloku vo svojom PR.
> **Trieda:** výrobná (nové dielce v kusovníku/VEPO, kovanie) + **audit-povinná** (nový typ, `CONFIG_SCHEMA` 21 → 22, BuildPlan `SCHEMA` 6 → 7,
> ABS `SEED_VERSION` 5 → 6, klamp šírky v observeri mierky) → `codex-audit` pred kódom · predrecenzia pred PR · **in-SU test je brána mergu** ·
> GH Codex review. Verzia v0.14.0 → **v0.14.1**.

## Značky

`W` šírka, `d` hĺbka (celková, D-37), `h` výška, `t` hrúbka korpusu, `s` sokel (`floor_height`), **`D` dverová časť** (`corner_door_w`),
**`c1`**, **`c2`** (`corner_cr1`, `corner_cr2`), **`gC`** = medzera dverí **na strane rohu** (`gap_right` pri `corner_side left`, `gap_left` pri `right`),
**`th1`**, **`th2`** = účinná hrúbka materiálu CR 1 a CR 2 (bod 2), `z_lo..z_hi` = svetlá výška korpusu (`Construction.interior_dims`),
**obrys riadku dverí** `zf0 = s + gap_bottom`, `hf = (h − s) − gap_top − gap_bottom` (jediný auto riadok = otvor mínus medzery hore/dole).
Osi enginu: X zľava, **+Y dozadu, čelná rovina korpusu Y = 0, čelá v −Y**, Z hore.

## Cieľ (z pohľadu stolára)

- Plugin vie postaviť **dolnú slepú rohovú skrinku** (typ „Rohová") presne ako DC „Rohová": dvere v dverovej časti, **blenda korpusová** cez slepú časť,
  **výstuha závesov**, **CR 1** vedľa dverí, **CR 2** kolmo dopredu a **rohová výstuha** za ňou — **dvere vľavo aj vpravo** (zrkadlo).
- Rohová ide do **kusovníka, VEPO, nákupu a ponuky** so správnymi rozmermi, materiálom (CR z čelového, zvyšok z korpusu), hranami (podľa DC) a kovaním
  ako dolná (závesy podľa výšky dverí, nohy podľa šírky).
- **Ochrany:** rohová nikdy ticho nezmení typ, vždy má jedny dvierka, vnútri len police, strana sa v A1 nedá zmeniť žiadnou cestou (príde s prepínačom v ROH-B).
- **Bez nových ovládačov** (R8): vkladanie tlačidlom „Rohová" a náhľad robí **ROH-A2**, riadky rohovej v Inspectore **ROH-B**. A1 sa overuje testami.

## Reconcile — triáž krížového auditu (Codex C#, Grok G#)

| Nález | Rozhodnutie | Kde |
|---|---|---|
| C1 / G2 BLOCKER — jedna `th`, hrúbka čelového až po pláne, CR 2 v osi X | **prijaté:** účinné hrúbky CR 1/CR 2 **pred plánom** (vzor `drawer_thicknesses`), geometria z nich, zrkadlo, validácia aj klamp z tých istých čísel | bod 2, 3, 8 |
| C2 BLOCKER / G7 — priečky pretínajú blendu, polica výstuhu závesov | **priečky v rohovej zakázané** (R6: vnútri police cez celú šírku); polica ostáva ako DC + **ORANGE** „výrez robí dielňa" (návrh, potvrdí Michal) | bod 5 |
| C3 BLOCKER — záporná medzera pri rohu prekryje dvere a CR 1 (sonda: dvere do x 460, CR 1 od 440) | **`gC` 1–20 mm** v stavbe aj v odmietnutí akcií čiel; ostatné medzery ako dnes | bod 4, 8 |
| G1 BLOCKER — neznámy typ sa v paneli sklopí na dolnú a každý zápis ho pošle späť | **JS registre typu v A1** (`CAB_TYPES`, `setType`, `NX_TYPE_LABEL`, `INSERT_TYPES`, `TYPE_LIMITS`, typ šablóny) + serverová poistka proti zmene typu | bod 7, 9 |
| C4 — plytký korpus + komín + vložený chrbát: výstuha 80 prejde chrbtom | **`back_front_y ≥ 80`** vo `validate!` → dedí `min_valid_depth` | bod 8 |
| C5 — šablóna zmení `corner_side`, overridy hrán ostanú | **zmena strany existujúcej rohovej sa v A1 odmieta** (šablóna, apply); ROH-B prinesie prepínač s premapovaním | bod 7 |
| C6 — polia bez ovládačov sa pri Apply vrátia na defaulty | polia rohovej **nie sú** v JS `CONSTRUCTION_FIELDS` (bez DOM by išli ako `null`); server ich drží z configu (`handle_apply` kopíruje len prítomné kľúče, `actions_cabinet.rb:760`) | bod 1, 9 |
| C7 — výška dverí/CR pri pevnom riadku a UKW | riadok dverí **vždy `auto`**; CR 1/CR 2 majú **obrys riadku** (nie narezaný panel pri UKW) | bod 3, 4 |
| G3 — dverová časť > 600 dá `wings auto` dve krídla (sonda: 700 → 2) | **krídla vždy 1**; odmietnutie v `handle_apply_fronts` aj `handle_apply_all`; šablóna nesmie podstrčiť iné čelo | bod 4 |
| G4 / C Q4 — osi a hrany | CR 1 a blenda `AXES_FRONT`; CR 2, výstuha závesov, rohová výstuha `AXES_UPRIGHT`; **žiadna** do `STANDING_ROLES`; výstuha závesov ABS **L2** (zadná), rohová výstuha **L1 + W1 + W2** | bod 6 |
| G5 — CR 2 o `gC` kratšia než rohová výstuha; rozmer CR 1 ≠ zadané `c1` | **vedome ako DC** (CR 2 má pri voľnej hrane polovičnú medzeru ako čelo — medzera k dverám susedného radu); výsledné rozmery ukáže ROH-B | bod 3 |
| G6 — `c1` min 30 je pod praxou (~76 mm) | rozsah **CR 1 a CR 2 50–250** (návrh, potvrdí Michal v mockupe) | bod 1 |
| G8 — guard smeru bez allowlistu | predvolený smer pri rohu **len keď kľúč `direction` chýba** (nová rohová), funkciou bez literálu pri kľúči; **nový test pripína jedinú výnimku R7**; `unset`/`left`/`right` sa nemenia | bod 4 |
| G9 / C Q5 — klamp šírky ručným vzorcom by sa rozišiel | **`min_valid_width` sondou cez celý plán** (vzor `min_valid_depth`) s účinnými hrúbkami; nemodálna veta; jeden transparentný rebuild | bod 8 |
| C8 — značky pántov v náhľade vždy vľavo | **ROH-A2** (náhľad) | — |
| C9 — overiť montáž závesu na výstuhe | smoke v dielni pri prvej rohovej (Sensys 9071205 + podložka D1,5 zo setu KLASIK: prekrytie `t − gC` = 16) | smoke |
| C10 — nika spotrebiča v rohovej | **bez zmeny** (väzby dnes prijmú každý korpus; blokovať netreba) | — |
| C11 — CR 1 a CR 2 sa pri rovnakom rozmere zlúčia | správne (agregácia podľa rozmeru); test nevyžaduje vždy dva riadky | testy |
| G10 — obálka prisunutia nevidí CR 2 | **bez zmeny** (R9); poznámka do mockupu | — |
| C Q6 — rez A1/A2 | **prijaté**: A1 = kontrakt, stavba, výstupy, ochrany, klamp; A2 = tlačidlo typu, náhľad, preflight otvoru | — |

## Scope IN

### 1 · Typ a dáta (kontrakt)

1. **`TYPES` += `corner_blind`** (`cabinet_builder.rb:55`). `norm_type` ho prijme (dnes neznámy → `lower`, `:4054–4057`).
2. **`CORNER_DEFAULTS`** = `LOWER_DEFAULTS` + `type: 'corner_blind'`, **`width: 1100.0`**, čelá = **jeden riadok `door`** (bod 4), polia rohovej nižšie.
   Konštrukcia (hĺbka 510, dno, strop, chrbát, sokel) **ako dolná** (DC mal dve nadnože a pevný vložený chrbát — potvrdí Michal v mockupe; zmena predvolieb
   je lacná a nemení kontrakt).
3. **Nové polia configu** (zapisujú sa **len pri `type corner_blind`**, vždy všetky štyri — vzor polí slotu pri `dishwasher`, `cabinet_config :2907`):

| Pole | Typ | Default | Rozsah (clamp v `normalize`) | Význam |
|---|---|---|---|---|
| `corner_side` | enum | `left` | `left` · `right` (iné → `left`) | strana **dverovej časti** spredu; roh je na opačnej strane |
| `corner_door_w` | Float mm | 450 | 250 – 800 | dverová časť od vonkajšej plochy boku po os medzery dvere ↔ CR 1 (DC „Šírka dverí") |
| `corner_cr1` | Float mm | 80 | 50 – 250 | CR 1: od hranice dverovej časti po líce CR 2 |
| `corner_cr2` | Float mm | 80 | 50 – 250 | CR 2: od líca dverí (roviny CR 1) po čelo rohovej výstuhy |

   **Prísne parsovanie** ako `back_setback` (`norm_setback`, vzor KON-A): nečíselné / nekonečné → predvolená hodnota poľa (nie `0`); rozsahy sú **návrh**
   (potvrdí Michal v mockupe ROH-B — zmena rozsahu = len clamp, kontrakt sa nemení).
4. **Reťaz whitelistov** (fakty §1.2, §2.6): `normalize`, `cabinet_config`, `config_to_params` (18 volaní — prenos pri prestavbe, kópii, scale, šablóne),
   `Panel::PARAM_KEYS` (server; **nie** JS `CONSTRUCTION_FIELDS` — C6), `Panel.template_config_from` (výslovne všetky štyri), `TemplatesDialog.merge_template`
   (kľúč chýba = zachovaj cieľ; **iná strana = odmietnutie**, bod 7), `sync.rb DEFAULTS` (predvoľby typu pre JS — využije A2).
5. **`CONFIG_SCHEMA` 21 → 22** + `HISTORIA` (typ `corner_blind`, štyri polia) — dopredný guard R-12 zastaví prestavbu aj exporty na staršom plugine.
   **BuildPlan `SCHEMA` 6 → 7** (päť nových rolí, precedens 3 → 4 a 5 → 6) · **ABS `SEED_VERSION` 5 → 6** (bod 6). Testy, ktoré čísla pripínajú
   (fakty §11: `test_konb_listy.rb:274–289`, `test_kond_chladnickova.rb:124`, `test_kon0_d143.rb:221`, …), sa zladia. `STD` šablón sa **nemení**.
6. **Vetvenia podľa typu** — prejsť **každé** miesto z faktov §1.2 a rozhodnúť výslovne (nie pádom do dolnej vetvy): podpora nohy/sokel a `home_z` 0
   ako dolná · auto názov **„Rohová skrinka W"** (+ `AUTO_NAME_RE`, aby sa pri zmene šírky premenoval) · `template_id_for` `corner-blind-18` ·
   `construction_preset_for` `noxun-corner-blind` · `defaults_for` → `CORNER_DEFAULTS` · `TEMPLATE_TYPE_WORDS` „rohová" · Bystrica/závesné kovanie hornej nie ·
   `MIN_BY_TYPE` scale nie (klamp sondou, bod 8) · `appliance_*` bez zmeny (C10).

### 2 · Účinné hrúbky CR pred plánom (C1 / G2)

1. **`corner_thicknesses(cfg, eff)`** vedľa `drawer_thicknesses` (`cabinet_builder.rb:1549`): pre kľúče `cabinet/cr:1` a `cabinet/cr:2` reťaz
   **override dielca (`part_overrides[key]['material_id']`) → kanál `front` (`eff['front']`) → UNI/neznámy materiál = 18.0** cez `sheet_thickness`.
   Výsledok ide do **toho istého** `part_thicknesses:` ako zásuvky (`:1048`) a z neho počíta `Construction` (bod 3). **Jeden výpočet** pre stavbu, validáciu,
   zrkadlo aj sondu šírky (bod 8) — žiadny druhý vzorec hrúbky.
   **Audit A1 FIX 2 — rovnaký materiálový kontext dostanú VŠETKY pomocné plány**, nielen hlavná stavba: `plan_parts_by_key` (`cabinet_builder.rb:2088`,
   premapovanie ručných ABS pri zmene dekoru `:1916` — dnes volá plánovač bez `part_thicknesses` a pri chybe vráti prázdnu mapu), sondy
   `min_valid_height` / `min_valid_depth` (`construction.rb:1485`, `:1525`) a nová `min_valid_width` vrátane volaní z `ScaleWatch`. Test: **D 450, c1 80,
   t 18, CR 2 hrúbky 16, W 582** — skutočná stavba prejde, pomocné plány tiež (s náhradnou hrúbkou 18 by potrebovali W 584).
2. CR 1 a CR 2 **nie sú** vo vetve `materialized_part` pre čelá (hrúbka v Y, `:2690–2703`) — dostávajú skutočnú hrúbku už v pláne (vzor zásuviek).
   Do `thickness_ok_for?` (`:1498–1515`) pribudnú s **toleranciou čiel** (katalóg 18,6/19 aj ďalšie čelové hrúbky nezhodí stavbu).
3. Dvere sa materializujú **ako dnes**. Rozdielne hrúbky dverí a CR 1 (rôzne overridy) = kozmetický rozdiel líc, povolený.

### 3 · Geometria (`construction.rb`, nová vetva pre `corner_blind`; JS zrkadlá robí A2)

Dvere vľavo (`corner_side left`); **dvere vpravo = zrkadlo `x' = W − x − box[0]`** pre päť dielcov zostavy **a otvor čiel** — korpus (boky, dno,
strop/výstuhy, chrbát, lišty, sokel, police) je symetrický a **nemení sa**. Kľúče ani roly sa zrkadlením nemenia.

| Dielec | `part_key` | Rola | box `[X, Y, Z]` | origin (dvere vľavo) | `prod` (dĺžka × šírka × hrúbka) |
|---|---|---|---|---|---|
| blenda korpusová | `cabinet/corner_panel` | `corner_blind_panel` | `[W − t − D, t, z_hi − z_lo]` | `[D, 0, z_lo]` | výška × šírka × `t` |
| výstuha závesov | `cabinet/hinge_rail` | `hinge_rail` | `[t, 80, z_hi − z_lo]` | `[D − t, 0, z_lo]` | výška × 80 × `t` |
| CR 1 | `cabinet/cr:1` | `cr_front` | `[c1 − gC, th1, hf]` | `[D + gC, −th1, zf0]` | `hf` × `c1 − gC` × `th1` |
| CR 2 | `cabinet/cr:2` | `cr_side` | `[th2, c2 − gC + th1, hf]` | `[D + c1, −(c2 − gC + th1), zf0]` | `hf` × `c2 − gC + th1` × `th2` |
| rohová výstuha | `cabinet/corner_rail` | `corner_rail` | `[t, c2 + th1, h − s]` | `[D + c1 + th2, −(c2 + th1), s]` | `h − s` × `c2 + th1` × `t` |

- **Overené na DC** (W 1100, t 18, D 450, c1 = c2 = 80, gC 2, th 18, s 150, h 862): blenda 632 × 18 × 676 @ x 450 · výstuha závesov 18 × 80 × 676 @ x 432 ·
  CR 1 78 × 18 × 707 @ x 452 · CR 2 18 × 96 × 707 @ x 530 · rohová výstuha 18 × 98 × 712 @ x 548, y −98; zrkadlo pri W 1100: blenda 18–650, výstuha
  závesov 650–668, CR 1 570–648, CR 2 552–570, rohová výstuha 534–552, dvere 652–1098 — **zhodné so sondou DC** (S3). Rozdiel oproti DC: čelá bez
  1 mm vzduchovej škáry pred korpusom (konvencia enginu `−th … 0`).
- `z_lo`, `z_hi` z `interior_dims` (dno pod/medzi bokmi, plný strop / spodok výstuh / bez stropu) — blenda a výstuha závesov stoja **medzi dnom a stropom**;
  zapustenie stropu a komín ich nemenia. Rohová výstuha `s … h` (od spodku korpusu po vrch, DC).
- **Otvor čiel:** `Construction.front_opening` pre `corner_blind` = `{x0: side == left ? 0 : W − D, w: D, z0: s, h: h − s}` (sonda: dvere 2–448 / 652–1098).
- **Materiálové signály:** blenda, výstuha závesov, rohová výstuha `:korpus`; CR 1, CR 2 `:front` + `FRONT_MATERIAL_ROLES` (bod 6).
- Názvy v builderi (ASCII ako ostatné): **„Blenda rohova"**, **„Vystuha zavesov"**, **„Vystuha rohova"**, **„CR lista 1"**, **„CR lista 2"** (návrh, potvrdí Michal).

### 4 · Čelá: jedny dvierka (R6) a smer pántov (R7)

1. **Invariant rohovej:** presne **jeden riadok `type door`, `mode auto`, `wings '1'`** (krídla nikdy `auto` — sonda: pri otvore 700 by boli 2).
   `normalize` ho vynúti ako poslednú obranu — **zachová ID riadku, `direction`, profil, zámky a nadväzujúce overridy** (vzor slotu `:3201` sa nekopíruje:
   prepisuje ID na F1). Chýbajú čelá → vznikne `F1`. Viac riadkov / iný typ → ostane prvý riadok `door` (inak nový `F1`).
2. **Odmietnutie s vetou** „Rohová skrinka má v dverovej časti jedny dvierka (jedno krídlo na celú výšku)." v `handle_apply_fronts` (`actions_cabinet.rb:777`)
   aj `handle_apply_all` (`:858`, vzor `slot_fronts_refusal`) pri pokuse zmeniť počet riadkov, typ, krídla alebo režim; **šablóna** rohovej s porušeným
   invariantom sa **odmietne**, nie ticho oreže. Povolené ostáva: smer, úchytkový profil, medzery (v rozsahu `gC`), materiál, dekor, kovanie čela.
3. **Medzera pri rohu `gC` = 1–20 mm** (C3): mimo rozsahu → odmietnutie v stavbe (`validate!`) aj v akciách čiel s vetou „Medzera dverí pri rohu musí byť
   1–20 mm."; vonkajšia medzera, hore a dole ako dnes (vrátane presahov).
4. **Smer pántov (R7, výnimka z O1):** keď riadok dverí rohovej **nemá kľúč `direction`** (nová rohová — rohová nemá legacy dáta), `normalize` doplní
   **stranu pri rohu**: `corner_side left` → `right`, `right` → `left`. Hodnoty `unset` (používateľ zvolil „Neurčené" → RED), `left`, `right` sa **nemenia**.
   Jediné miesto heuristiky = jedna funkcia (mapa strany bez literálu pri kľúči `direction` — sonda: guard `test_kova1_cela.rb:574` ju nechytí);
   **nový test pripne**, že je to jediná heuristika smeru v plugine a volá sa len v tejto vetve (výnimka R7, Michal 27.9.2026).
5. CR 1/CR 2 majú **obrys riadku dverí** (`zf0`, `hf`) — pri úchytkovom profile UKW je narezaný panel dverí nižší, CR nie (DC).

### 5 · Interiér (C2 / G7)

1. **Priečky v rohovej zakázané:** strom zón rohovej = **jediná listová zóna** (police cez celú šírku, R6). Delenie zóny (`v` aj `h`) v akciách zón
   (`actions_zones.rb`) → odmietnutie „Rohová skrinka má vnútri len police cez celú šírku (bez priečok)." + invariant vo `validate!` (šablóna ani config
   ho neobídu). Počet a nastavenie políc ostáva.
2. **Predné odsadenie políc rohovej = `max(20, t)`** (audit A1 **BLOCKER 1**): blenda zaberá `y ∈ [0, t]`, dnešné odsadenie 20 (`zone_tree.rb:25`, `:562`)
   by pri korpuse hrubšom ako 20 mm (rozsah 6–50, `cabinet_builder.rb:374`) prerazilo blendu v celej slepej časti (sonda audítora: W 1100, D 450,
   t 25 → prienik 625 × 5 mm). Pri `t ≤ 20` (DC, bežná prax 18) sa nemení nič; pri hrubšom korpuse polica začne za blendou (plytšia o `t − 20`).
   Platí len pre `corner_blind`, obe strany; test t 18 / 25 / 36 vľavo aj vpravo (polica nepretína blendu).
3. **Polica × výstuha závesov:** polica ide ako v DC cez celú šírku a pretína výstuhu závesov (`t` × `80 − odsadenie`). **Kontrola ORANGE**
   `corner_shelf_notch` pri rohovej s policami: „Polica prechádza výstuhou závesov — výrez {t} × {80 − odsadenie} mm robí dielňa." (návrh — potvrdí Michal,
   otázka §3 bod 5; kusovník a VEPO ostávajú obdĺžnik).

### 6 · Roly a výstupy (≈ 20 uzavretých zoznamov, fakty §2.6)

| Rola | Osi (`PartFaces`) | Kanál | ABS seed 6 | Tag | `ROLE_LABELS` | VEPO skratka (návrh) |
|---|---|---|---|---|---|---|
| `corner_blind_panel` | `AXES_FRONT` | korpus | `{}` (DC bez ABS) | Korpus | Blenda korpusová | „Blenda roh" |
| `hinge_rail` | `AXES_UPRIGHT` | korpus | `L2` 1,0 (zadná hrana, viditeľná zvnútra) | Korpus | Výstuha závesov | „Vyst zav" |
| `corner_rail` | `AXES_UPRIGHT` | korpus | `L1` + `W1` + `W2` 1,0 (predná + vrch + spodok) | Korpus | Rohová výstuha | „Vyst roh" |
| `cr_front` | `AXES_FRONT` | **čelový** | dookola 1,0 | Čelá | CR lišta 1 | „CR 1" |
| `cr_side` | `AXES_UPRIGHT` | **čelový** | dookola 1,0 | Čelá | CR lišta 2 | „CR 2" |

- **Žiadna** nová rola do `STANDING_ROLES` (obracajú L1/L2). Mapy hrán sú **symetrické v X** → zrkadlo nemení fyzicky olepené hrany (ručné overridy ľavej/pravej
  hrany rieši ROH-B pri prepínači strany).
- **`AbsRules.edge_sides`** (`abs_rules.rb:462`, vlastný uzavretý zoznam 4 rolí čiel — audit A1 **FIX 4**): `cr_front` a `corner_blind_panel` dostanú
  **čelnú mapu** (L1 vľavo, W2 hore), inak karta dielca (`part_card.js:313`, `:353`) kreslí, popisuje a kliká hrany ako pri ležiacom dielci; test súladu
  fyzickej hrany, popisku a ručného výberu ABS. Stojace roly (`hinge_rail`, `corner_rail`, `cr_side`) sa správajú ako bok (dnešná mapa bokov).
- Zoznamy: `BuildPlan::ROLES` · `AbsRules::EDGE_LABELS` / `SEED_RULES` / `SEED_VERSION` (merge dopĺňa chýbajúce roly, vlastné hodnoty nemení) ·
  `PartFaces::ROLE_AXES` · `CabinetBuilder::PART_TAGS` · `Construction::FRONT_MATERIAL_ROLES` (+ pripnutá kópia v `test_kovw_hmotnost.rb`) ·
  `thickness_ok_for?` · `Validation::FRONT_ROLES` (CR bez ABS → ORANGE) · `CpExport::FRONT_ROLES` (CR v kategórii „dvierka") · `ProductionCore::ROLE_LABELS` ·
  `part_card.js` `roleLabel` / `isFront` (CR: výber čelových materiálov) · `RulesDialog::ABS_ROLE_ORDER` · `rules.js rdRoleDesc` · `VepoExport::SHORT_NAMES`.
  **Nie** do `HardwareRules::FRONT_ROLES` (len výška čela pre výsuvy).
- Kusovník: bežná agregácia (rozmer + materiál + hrany) — CR 1 a CR 2 pri zhodnom rozmere v jednom riadku je **správne** (C11).
- VEPO: celý názov riadku ≤ 20 znakov vrátane značiek skriniek (`vepo_export.rb:64`); smer dekoru CR stojaci (dĺžka = výška) ako dvere.

### 7 · Ochrany (typ a strana)

1. **Zmena typu z/na `corner_blind`** v `handle_apply` / `handle_apply_all` → odmietnutie „Typ rohovej skrinky sa nedá zmeniť." (poistka; panel po bode 9
   typ neposiela zle). `apply_template_type!` (`actions_templates.rb:220–233`) — rohová **skorý návrat** ako slot (typ šablóny zamknutý). Šablóna iného typu
   sa na rohovú nepoužije (už dnes `templates_dialog.rb:419`).
2. **Zmena `corner_side` existujúcej rohovej** (apply s iným `corner_side`, šablóna s inou stranou) → odmietnutie „Strana dverí rohovej sa zatiaľ nedá zmeniť —
   príde s prepínačom strany." (C5). **Vloženie** novej rohovej zo šablóny ľubovoľnej strany je v poriadku (nová skrinka nemá overridy).
3. **Kópie** (panel „Vložiť kópiu" `actions_cabinet.rb:669`, Mower `tools/mower.rb:207`, natívna kópia + dedup `cabinet_builder.rb:932`) prenesú polia rohovej
   cez `config_to_params` — overiť testom.
4. **Vloženie zo šablóny** (audit A1 **FIX 3**): serverová cesta vkladania prenáša zo šablóny len polia slotu a očakávania spotrebičov
   (`apply_template_slot_fields!`, `actions_cabinet.rb:489`, `:539`) a formulár polia rohovej neposiela → šablóna „vpravo / 600 / 120 / 90" by skončila na
   „vľavo / 450 / 80 / 80". Polia rohovej sa **načítajú a zvalidujú zo záznamu vybranej šablóny na serveri** pred vytvorením ghostu (vzor polí slotu,
   jedna cesta pre oba typy). Test celej cesty **uložiť šablónu → vložiť**: obe strany a nepredvolené rozmery.
5. **Preflight čiel na serveri** (audit A1 **NOTE 5** — rohová v otvorenom `.skp` je editovateľná v Inspectore aj bez tlačidla vkladania): panelový
   preflight (`actions_cabinet.rb:34–75`, `:55`) počíta otvor **pre každý typ** cez `Construction.front_opening` — pri rohovej s poľami z **uloženého
   configu označenej skrinky** a so **živou šírkou** z požiadavky (pravá strana posúva `x0 = W − D`). JS kresba náhľadu z otvoru ostáva **ROH-A2**.

### 8 · Validácia, minimá, scale

1. **`validate!` pre `corner_blind`** (vety po slovensky, bez tichého orezania): `gC` 1–20 · **`D + c1 + th2 + t ≤ W − t`** (rohová zostava pred slepou
   časťou) · **`back_front_y ≥ 80`** (výstuha závesov pred chrbtom/lištami/komínom, C4) · invariant čiel (bod 4) · invariant zón (bod 5).
2. **`min_valid_depth`** výstuhu dedí automaticky (sonda cez celý plán) — overiť testom (komín 85 + vložený chrbát 18 → hĺbka zdvihnutá).
3. **`Construction.min_valid_width(cfg, part_thicknesses:)`** — **sonda cez celý plán** (vzor `min_valid_depth` `:1501`, polením), **s účinnými hrúbkami**
   z bodu 2; pre iné typy ostáva dnešné správanie (bez zmeny). **`ScaleWatch`**: klamp šírky rohovej **pred** skúšaním hĺbky/výšky (`scale_observer.rb:493–509`),
   nemodálna veta (vzor `clamp_depth` / `depth_clamp_message`), jeden transparentný rebuild (`:524`), refresh bez deduplikácie (`:543`); `flush_pending!`
   sa zvnútra absorpcie nevolá.
4. Pri zmene šírky rastie len slepá časť (dverová časť a CR sú absolútne) — pri dverách vpravo je zostava viazaná na **pravý** okraj.

### 9 · JS (len registre typu a rolí — žiadny nový ovládač)

`core.js` `CAB_TYPES` / `setType` (neznámy typ už nesmie sklopiť rohovú na dolnú, G1), `NX_TYPE_LABEL` „Rohová" · `form.js` `TYPE_LIMITS` (rohová: ako dolná
+ min. šírka z `DEFAULTS`) · `insert_state.js` `INSERT_TYPES` (zoznam) a mapa typu šablóny (`:256–267` — rohová šablóna nesmie padnúť do „dolnej") ·
`templates.js` štítky typu · `part_card.js` · `rules.js`. **Nie:** tlačidlo vo vkladacej karte, `applyVisibility` vkladania, náhľad, preflight otvoru, náhľad
nôh (`hardware.js:2458`), zámok typu v modale šablóny v UI — to je **ROH-A2**. Polia rohovej **nie sú** v `CONSTRUCTION_FIELDS` (C6).

### 10 · Dokumentácia

STANDARD (typ `corner_blind` a polia v §4, roly v §3, ABS seed §7; **oprava** „rohové korpusy mimo scope V1" `:403`, `:1550`) · VEPO_KONTRAKT (skratky) ·
POJMY (rohová slepá skrinka, dverová časť, slepá časť, blenda korpusová, výstuha závesov, rohová výstuha, CR lišta 1/2) · `docs/architecture/` odseky
`cabinet_builder`, `construction`, `scale_observer` (construction.md), `build_plan`/`part_keys` (model-a-identita.md), `validation`/`vepo_export`/`cp_export`
(outputs.md), `abs_rules` (materials.md), JS registre (ui-lifecycle.md) — **prepísať odsek na mieste**. STAV (v0.14.1), KRONIKA, PLAN (riadok ROH-A1 ✅ + PR).

## Scope OUT

- **ROH-A2:** tlačidlo „Rohová" a ikona vo vkladacej karte, `applyVisibility` vkladania, predvoľby vkladania, **JS** strana otvoru čiel (`form.js:404`,
  odpoveď preflightu z A1 použiť v kresbe), JS čitatelia plnej šírky (`preview.js:79/125/543/885/1072/1138/1386`, `nxFrontsResolve :445`), značky pántov podľa
  smeru (`preview.js:1184`), náhľad nôh, zámok typu v modale šablóny.
- **ROH-B:** riadky Inspectora (dverová časť, CR 1, CR 2), prepínač strany (zrkadlí `gap_left/right`, smer pántov a ručné overridy hrán podľa osí),
  kresba rohovej zostavy v náhľade, skrytie ovládačov štruktúry čiel a delenia zón pri rohovej.
- **Blok OUT:** horná rohová, LeMans, kolízie so susedným radom, sokel okolo rohu, geometria výrezu police, CR v „Kresbe čiel" (D-131), nika spotrebiča.

## Testy a DoD

- **Headless** `tests/pure/test_roha1_rohova.rb` (vzor `test_s1e_slot.rb` + `test_konb_listy.rb`): typ vo všetkých registroch (Ruby + parita JS) ·
  predvoľby a clamp polí, prísne parsovanie, zápis len pri rohovej, round-trip `cabinet_config → config_to_params → normalize` · **geometria plánu oboch
  strán presne podľa tabuľky bodu 3** (DC čísla aj W 900/1300, D 300/600, c1/c2 50/120, gC 1/10) · **hrúbky 18 / 18,6 / 19** cez kanál čiel, override
  dielca CR 2 a UNI · odmietnutia (gC 0/−10/25, fit, hĺbka pri komíne + vloženom chrbte, čelá 2 riadky / zásuvka / krídla 2 / fixed, delenie zón) ·
  smer (chýba → pri rohu obe strany; `unset`, `left`, `right` nezmenené) + **pin výnimky R7** · zmena typu a strany odmietnutá (apply, šablóna), šablóna
  rovnakej strany prejde · `handle_apply` bez polí rohovej ich zachová (D 500 ostane 500) · roly vo všetkých zoznamoch + seed ABS 6 (merge do starého
  úložiska) · kusovník a VEPO názvy ≤ 20 · ORANGE polica × výstuha · `min_valid_width` (obe strany, th 19) · nohy 6 pri 1100, závesy dverí (referenčný prípad 2) ·
  čísla schém (22 / 7 / 6) · **golden plány dolnej a hornej sa nepohnú** (neregenerovať) · **audit A1:** polica × blenda pri t 18 / 25 / 36 obe strany
  (odsadenie `max(20, t)`), pomocné plány s hrúbkou CR 2 = 16 pri W 582 (ABS remap aj sondy), šablóna **uložiť → vložiť** (vpravo / 600 / 120 / 90
  ostane), `edge_sides` čelná mapa pre CR 1 a blendu, preflight otvoru pre rohovú (živá šírka, obe strany) a pre ostatné typy bez zmeny.
- **JS** `tests/js/test_roha1_rohova.js`: `CAB_TYPES`/`INSERT_TYPES`/`NX_TYPE_LABEL`/`TYPE_LIMITS` parita, `setType('corner_blind')` drží typ, `collectConstruction`
  bez polí rohovej, `roleLabel`/`isFront`/`rdRoleDesc` nových rolí. Každú JS sadu spúšťať zvlášť (CLAUDE.md).
- **In-SU** `run_roha1` v `tests/sketchup/su_runner.rb` (vzor `run_konb`/`run_kond`, runner **`-CloseWhenDone`**): stavba oboch strán plán ↔ model 1:1
  (`run_sync`: počet, kľúče, origin, rozmery) pre DC prípad + 4 kombinácie (W, D, c1/c2, gC, hrúbka čelového 19 cez kanál aj override) · prestavba drží
  polia · Späť (vloženie = 1 krok, prestavba = 1 krok, odmietnutie = 0 krokov) · odmietnutia (čelá, zóny, typ, strana cez šablónu) · tri kópie (panel,
  Mower, natívna + dedup) · **scale šírky**: rast slepej časti (obe strany), zmenšenie pod minimum → klamp + nemodálna veta; Scale → hneď Mower/Snaper →
  Späť/Znova bez ďalšieho kroku časovača · uloženie a znovu načítanie configu (ak runner vie) · kusovník/VEPO/nákup: názvy, rozmery, nohy 6, závesy.
- **Mutácie** (min. 6, zapísať do PR): hrúbka CR 2 z placeholdera namiesto sondy · zrkadlo bez `− box[0]` · smer R7 aj pri `unset` · delenie zóny povolené ·
  zmena strany cez šablónu povolená · CR mimo `FRONT_MATERIAL_ROLES` · nová rola bez bumpu seedu ABS.
- `for f in tests/js/test_*.js; do node "$f" || exit 1; done` + `ruby tests/run_all.rb` zelené; encoding guard.

## Riziká

- **Rozsah** (~40–50 súborov ako S1-E) — držať sa rezu A1, UI nechať A2/B. **Reťaz hrúbok** (bod 2) je jediný zdroj pravdy — dve cesty = škára v rohu.
- **Vetvenia podľa typu** — pád do dolnej vetvy je tichý; každé miesto z faktov §1.2 rozhodnúť výslovne (PR vymenuje).
- **Starší plugin:** schéma 22 → neprestaví ani nevyexportuje (R-12); **aktualizovať obe PC** pred prvou rohovou.
- **Nočný beh:** in-SU runner nasadzuje vetvu do Plugins; Michalov SketchUp nechať na pokoji (runner má vlastnú inštanciu).

## Smoke pre Michala

A1 nemá tlačidlo vkladania (príde s **ROH-A2**) — smoke rohovej sa robí **spolu s A2**. Rohová v otvorenom modeli je v A1 editovateľná bežnými
riadkami Inspectora a chránená serverom (preflight otvoru, odmietnutia); jej náhľad kreslí dvere ešte cez celú šírku (opraví A2). Pri prvej rohovej v dielni: záves Sensys 9071205 + podložka
D1,5 na výstuhe závesov, prekrytie 16 mm, dvere sa otvoria bez dotyku CR 1 (medzera 4 mm) (C9).

## Checklist uzáveru

Bump **v0.14.1** (2×) + všetky `?v=` → testy (headless, všetky JS sady, **in-SU**) → odseky architektúry na mieste → STANDARD/VEPO_KONTRAKT/POJMY →
**STAV prepis** (v0.14.1; smoke bloku 7 PASS 27.9., delenie čiel potvrdené — prepíše dnešný riadok 35) + KRONIKA navrch + PLAN riadok ROH-A1 ✅ `PR #?` →
po `gh pr create` samostatný commit s číslom PR. Package + audit návrhu do `SYSTEM/zdroje/bloky/ROHOVA/`.

## Sonda pred auditom (krok 0, 28.9.2026 ~01:40, worktree `orch-rohova` = main `44a9d2d4` + docs)

Skript `probe_roha1.rb` (headless nad reálnymi modulmi, bez zápisu do modelu):

| Tvrdenie | Výsledok |
|---|---|
| `Fronts.resolve_layout` s otvorom `{x0 0, w 450, z0 150, h 712}`, medzery L2/P2/H5/D0 | dvere **x 2, šírka 446, z 150, výška 707, 1 krídlo** — zhodné s DC |
| to isté, otvor `x0 650` (dvere vpravo) | **x 652**, šírka 446 |
| `wings auto` pri otvore 700 | **2 krídla** → invariant `wings '1'` je nutný (G3) |
| `gap_right −10` | otvor 458, dvere **končia na x 460** → CR 1 od 440 = prekrytie (C3 potvrdený) |
| neznámy typ v `normalize` | `corner_blind` → **`lower`** (G1 potvrdený) |
| schémy dnes | CONFIG 21 · BuildPlan 6 · ABS seed 5 |
| záporný origin v `validate_part!` | `validate_triplet!(…'origin'…, positive: false)` (`build_plan.rb:454`) — povolené |
| guard smeru na vzore R7 (mapa strany + zápis len pri chýbajúcom kľúči) | regex fallbacku aj literálu **nechytí** (false/false) |
| `handle_apply` kopíruje len prítomné kľúče | `params[k] = data[k] if data.key?(k)` (`actions_cabinet.rb:760`) |
| `min_valid_depth` | sonda polením cez celý `build_plan` (`construction.rb:1501–1531`) — vzor pre `min_valid_width` |

## Audit návrhu ROH-A1 (Codex `gpt-6-astra`, task `task-mukdp9fr-afl95s`, 28.9.2026 ~00:15–00:40, +8 % Codex weekly)

Surový výstup: [AUDIT_ROHA1_2026-09-28.md](AUDIT_ROHA1_2026-09-28.md). **1 BLOCKER · 3 FIX · 1 NOTE — všetko zapracované do v2:**

| # | Nález | Zapracovanie |
|---|---|---|
| 1 BLOCKER | polica od `y = 20` prerazí blendu pri korpuse hrubšom ako 20 mm (t 25 → 625 × 5 mm) | bod 5.2 — predné odsadenie políc rohovej `max(20, t)`; test t 18 / 25 / 36 |
| 2 FIX | pomocné plány (`plan_parts_by_key`, sondy výšky/hĺbky, `ScaleWatch`) bez účinných hrúbok CR | bod 2 — rovnaký materiálový kontext všade; test CR 2 16 mm pri W 582 |
| 3 FIX | vloženie zo šablóny stratí štyri polia rohovej | bod 7.4 — polia zo záznamu šablóny na serveri; test uložiť → vložiť |
| 4 FIX | `AbsRules.edge_sides` — CR 1 a blenda by v karte dielca mali mapu ležiaceho dielca | bod 6 — čelná mapa + test súladu hrany, popisku a výberu |
| 5 NOTE | rohová v otvorenom `.skp` je editovateľná aj bez tlačidla; preflight počíta otvor len pre slot | bod 7.5 — serverový preflight otvoru pre každý typ presunutý do A1 |
