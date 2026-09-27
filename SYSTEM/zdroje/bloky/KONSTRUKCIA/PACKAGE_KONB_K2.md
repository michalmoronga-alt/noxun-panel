# Package KON-B · K2 — chrbát z dvoch líšt

> **Blok 7 · KONŠTRUKCIA K1+K2**, tretia dávka. **Package v2** (27.9.2026) — zapracovaný audit návrhu (0 BLOCKER · 3 FIX · 2 NOTE — všetko v Scope IN,
> prehľad v sekcii „Audit návrhu KON-B" na konci). Autorita počas dávky: tento package.
> Podklady v `SYSTEM/zdroje/bloky/KONSTRUKCIA/`: [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md) (M4–M6, M10, M11),
> [VSTUPY_PRE_PACKAGES_2026-09-27.md](VSTUPY_PRE_PACKAGES_2026-09-27.md) (KON-B), schválený mockup
> [MOCKUP_KONSTRUKCIA_2026-09-27.html](MOCKUP_KONSTRUKCIA_2026-09-27.html) (sekcia A — A3, A5, A7; sekcia D — D1, D2), fakty z kódu
> [FAKTY_Z_KODU_2026-09-26.md](FAKTY_Z_KODU_2026-09-26.md) §4–§6, §9 + fakty KON-B (main `4be63120`, v tomto package), krížový audit (Codex FIX 8,
> Grok 5, 6), package KON-A [PACKAGE_KONA_K1.md](PACKAGE_KONA_K1.md) (komín a jeho pomocníky už sú v maine), audit návrhu
> [AUDIT_KONB_2026-09-27.md](AUDIT_KONB_2026-09-27.md).
> **Trieda:** výrobná + **audit-povinná** (`CONFIG_SCHEMA` 20 → 21, BuildPlan `SCHEMA` 5 → 6, ABS `SEED_VERSION` 4 → 5, nové roly) → `codex-audit`
> pred kódom · predrecenzia pred PR · **in-SU test je brána mergu** · GH Codex review. Verzia v0.13.2 → **v0.13.3**.

Značky ako v KON-A: `d`, `w`, `h`, `t`, `bt`, `s`, **`X` komín**, **`R` zadný doraz** (`Construction.back_stop`), **`H` výška líšt**
(`back_rail_height`). Riadky kódu = main `4be63120`.

## Cieľ (z pohľadu stolára)

- Nový typ chrbta **„Z líšt"** (M4): namiesto dosky chrbta **dve vodorovné lišty z korpusovej dosky** medzi bokmi — **dolná** stojí na dne, **horná**
  je pod stropom (alebo pod výstuhami, pri „Bez stropu" po vrch bokov); výška lišty `H` (predvolene **100**), hrúbka = hrúbka korpusu, zadná plocha
  v zadnom doraze (pri komíne posunutá o komín).
- **Vnútro končí pred lištami v celej výške** skrinky (M5) — police, priečky a zásuvky sú o hrúbku lišty kratšie.
- **Kusovník a VEPO** (M6): obe lišty = **jeden riadok, 2 ks**, VEPO názov **„Chrb HD"**, páska na **jednej dlhej hrane** (hrana viditeľná zvnútra —
  kus sa pri montáži len otočí). Ak má skrinka aj výstuhy **rovnakého výrobného rozmeru a materiálu**, zlúčia sa s nimi do jedného riadku
  („Vyst PZ/Chrb HD", mockup D2).
- Materiál chrbta (HDF) sa pri lištách **nepoužije** — lišty sú z korpusu.

## Scope IN

### 1 · Dáta a kontrakt

1. **Nová hodnota `back_mode: 'rails'`** (UI „Z líšt"): `normalize` (`enum_val %w[overlay inset groove none]`, `cabinet_builder.rb:3057` — dnes
   neznáma hodnota ticho spadne na predvolený chrbát typu) · `config_to_params` a `cabinet_config` (plochý aj vnorený `back: {mode:}`) ju prenesú bez zmeny.
2. **Nové pole `back_rail_height` (H):** Float mm, predvolene **100**, **prísne parsovanie** ako `back_setback` (`norm_setback`, `:4057`), klamp
   **20–300** (20 = minimum výstuhy D-80). Zápis do configu **len keď H ≠ 100** (vzor KON-A „len keď sa líši od predvoľby") → config existujúcich
   skriniek sa nemení; v normalizovaných parametroch vždy číslo. Hodnota sa pri inom type chrbta **pamätá** (vzor `back_thickness` pri „Bez chrbta").
3. **Reťaz whitelistov presne ako `back_setback` v KON-A** (fakty KON-B §10): `SETBACK_KEYS`-vzor / `normalize` / `cabinet_config` / `config_to_params` /
   `Panel::PARAM_KEYS` / JS `CONSTRUCTION_FIELDS` (`dflt: 100`, riedky config → 100) / `currentCarcass` / `pvGeom` → `pvSetbackDepths` /
   `bindExprFields` / `LIMITS` / `DEFAULTS` (`sync.rb:40`) / `template_config_from` (**výslovne aj 100**) / `merge_template` (kľúč chýba = stará šablóna
   → **zachová H cieľa**) / `panel.html` / `cabinet_payload` — a **guard parity** KON-A (`test_kona_komin.rb:205`) rozšírený o H.
4. **Dve nové roly** `back_rail_top` a `back_rail_bottom` (Codex FIX 8 — mapa hrán rozlišuje rolu, nie variant): kľúče `cabinet/back_rail:top` a
   `cabinet/back_rail:bottom` (`PartKeys.cabinet`, `part_keys.rb:13` — `valid?` prejde), osi `PartFaces::AXES_WALL`, materiál `:korpus`,
   **spoločný názov v builderi „Lista chrbta"** pre obe (review PR #398 kolo 3 — kusovník v Štúdiu spája surové názvy riadku `studio.js:283`, dve mená
   by dali „… / …"; M6 jeden názov).
5. **`BuildPlan::SCHEMA` 5 → 6** (`build_plan.rb:95`; precedens: nové roly dielcov zásuviek = 3 → 4) + `ROLES` (`:108`) — plán s novými rolami už nie je
   plánom schémy 5. **`CONFIG_SCHEMA` 20 → 21** + `HISTORIA` (`back_mode 'rails'`, `back_rail_height`) — dopredná a exportná brána R-12 zastaví starší
   plugin (ten by `rails` ticho zmenil na predvolený chrbát a do kusovníka dal dosku chrbta). **ABS `SEED_VERSION` 4 → 5** (bod 5.1). Testy, ktoré
   čísla pripínajú (fakty KON-B §6, §11: 7× BuildPlan 5, `test_kovd5_abs_zasuvky.rb:341` seed 4, `test_kona_komin.rb:631–644`), sa zladia.
   **`BuildPlan::BACK_MODES`** (`build_plan.rb:510–527`) sa **nerozširuje** — je to značka pôvodu dielca s rolou `back` (KON-0), nie zoznam hodnôt
   configu; lišty značku nenesú (audit, odpoveď 6).

### 2 · Geometria (`construction.rb`; JS zrkadlá v bode 6)

1. **Dva dielce namiesto chrbta** (nová vetva, `build_plan` dnes pripája len jeden `bk`, `:129–130`; `back_part` `:1672` a `setback_back_part`
   `:1702` pri `rails` dnes postavia naložený chrbát — musia vrátiť nič):

| Dielec | box `[X, Y, Z]` | origin | `prod` |
|---|---|---|---|
| `back_rail_bottom` | `[w − 2t, t, H]` | `[t, R − t, z_lo]` | `{length: w − 2t, width: H, thickness: t}` |
| `back_rail_top` | `[w − 2t, t, H]` | `[t, R − t, z_hi − H]` | rovnaký |

   `z_lo`/`z_hi` = `interior_dims` (`:1499`, `:1503–1508`): horná lišta pod plným stropom (`h − t`), pod výstuhami (spodná hrana výstuh — pri výstuhách
   na výšku stojí tesne pod zadnou výstuhou v tej istej rovine `[R − t, R]`), pri „Bez stropu" po vrch bokov (`h`). `R` = `back_stop` (`:1300`; pri
   `rails` a X = 0 = `d`, lebo `carcass_depth` skracuje len `overlay`), hĺbka bokov `side_depth` (`:1308`) = `d`.
2. **Vnútro** (`interior_dims.back_front_y`, `:1509–1524` — dnes by `rails` padol do vetvy `overlay`): **`R − t`** pri X = 0 aj X > 0. Konzumenti
   (zóny, police, priečky, NL výsuvu, HL, „Vnút. hĺbka", nika pri X = 0) sa zmenia automaticky — vedomá výrobná zmena (M5).
3. **Komín** (KON-A) platí aj pre lišty: minimum komína pri `rails` **žiadne** (M10, `min_back_setback` `:1333` už vracia 0), voľný kanál = **X**
   (zadná plocha líšt v rovine `R`).
4. Nohy, box niky, D-143/D-144 brány: bez zmeny (`stored_back_mode` vráti `rails`, predikáty zastaranosti ho neoznačia — overené).

### 3 · Validácia

1. **Lišty sa musia zmestiť:** `2H + 20 ≤ avail_h` (vnútorná výška) — inak odmietnutie vetou „Dve lišty po 100 mm sa do vnútra 180 mm nezmestia —
   zmenši výšku líšt alebo zväčši skrinku." (mockup). Mierka (`min_valid_height`, `min_valid_depth` — sonda cez `build_plan`) pravidlo zdedí.
2. Ostatné pravidlá KON-A (minimum vnútra pri komíne, strop ≥ 60, výstuhy) platia bez zmeny; pri `rails` sa vnútro ráta `R − t`.

### 4 · Hrany (ABS) a jeden riadok kusovníka

1. **Obe roly majú pravidlo olepu `{L1}`**; **`back_rail_bottom` pribudne do `PartFaces::STANDING_ROLES`** (`part_faces.rb:78`) → pri `AXES_WALL`
   je `L1` horná plocha (`STANDING_EDGE_FACES`), pri hornej lište (nestojacej) `L1` = spodná plocha — páska je vždy na hrane **viditeľnej zvnútra**
   a obe lišty majú **rovnakú mapu hrán** → rovnaký agregačný kľúč kusovníka (`Bom.row_key`, `bom.rb:1666–1676` — kľúč obsahuje len výrobné parametre:
   rozmer, hrúbka, materiál, hrany, smer dekoru, zdroj materiálu; rolu ani názov nie). **Vedomá zmena invariantu** „korpusová rola nesmie byť stojacá"
   (`test_kovd5_abs_zasuvky.rb:306–320`, hlavička `part_faces.rb:28–37`) → výnimka pre dolnú lištu chrbta, test aj text sa prepíšu.
2. **Seed pravidiel olepu** (`abs_rules.rb:129–156`): `back_rail_top: {'L1' => 1.0}`, `back_rail_bottom: {'L1' => 1.0}`; **`SEED_VERSION` 5** —
   `merge_seed_roles` (`:248–262`) na existujúcom PC doplní len chýbajúce roly a vlastné pravidlá neprepíše (bez bumpu by lišty ostali **bez pásky**).
3. **Kto rolu pozná** (fakty KON-B §4, §7): `PartFaces::ROLE_AXES` (`:145` — bez neho Kontrola olepov, hover hrán, smer dekoru a „Použiť vzhľad" dielec
   nevedia čítať) · `AbsRules::EDGE_LABELS` (horná lišta ako `back`: L1 Dolná · L2 Horná · W1 Ľavá · W2 Pravá; dolná ako `drawer_back`: L1 Horná · L2 Dolná)
   · `CabinetBuilder::PART_TAGS` → tag **Chrbát** (skrýva sa spolu s chrbtami; `tags.rb:66`) · `ProductionCore::ROLE_LABELS` („Lišta chrbta horná/dolná")
   · `part_card.js roleLabel` · `RulesDialog::ABS_ROLE_ORDER` (hneď za `back`) · `material_channel` = korpus (predvolené, overené) · `CpExport` = vnútorné
   korpusy (predvolené) · `thickness_ok_for?` presná zhoda s `t` (predvolené, správne).
4. **„Použiť na podobné"** ostáva **bez zmeny** (len rovnaká rola, `actions_parts.rb:684–715`) — audit FIX 1: akcia prenáša riedky override, nie
   výsledné hrany, takže rozšírenie na sesterskú rolu by olep nezjednotilo (chýbajúci override vráti lištu na jej vlastné pravidlo). Ručný zásah na jednej
   lište = **dva riadky kusovníka** — výrobne správne (kusy sa líšia); do smoke.
5. **Zlúčenie s výstuhami:** kľúč neobsahuje orientáciu, takže lišty 564 × 100 × 18 s páskou `L1` sa zlúčia s **výstuhami na výšku aj naplocho**
   rovnakého rozmeru a materiálu (predvolená „Dolná klasik" s výstuhami 100 + lišty 100 → **1 riadok 4 ks**). Je to v súlade s M6 („výrobne ten istý kus"),
   len širšie než jeho text (M6 menuje výstuhy na výšku) — zapísať do STANDARD a smoke.

### 5 · Výstupy

1. **VEPO** (`vepo_export.rb`): `SHORT_NAMES['Lista chrbta'] = 'Chrb HD'` (`:72–80`); `NAME_PAIRS` bez zmeny. Výsledky: len lišty → „Chrb HD s15";
   s výstuhami → „Vyst PZ/Chrb HD s12" (18 znakov, do 20 sa zmestí); dve skrinky → „Vyst PZ/Chrb HD +2". Hrana: `—` v stĺpci pozdĺž (páska na jednej
   z dvoch dlhých hrán). `VEPO_KONTRAKT.md` — tabuľka názvov.
2. **Kusovník v Štúdiu:** názov „Lista chrbta" (pri zlúčení „Vystuha predna / Vystuha zadna / Lista chrbta"), stĺpec Rola „Lišta chrbta horná · Lišta
   chrbta dolná".
3. Hmotnosť, plocha skrinky (`cabinet_stats`), cenová ponuka: automaticky ako korpusové dielce.

### 6 · UI a JS (schválený mockup, sekcia A)

1. **Chrbát → Konštrukcia:** piata voľba **„Z líšt"** v poradí Naložený · Vložený · V drážke · Z líšt · Bez chrbta (A3).
2. **„Výška líšt __ mm"** na mieste riadku „Hrúbka chrbta" — nikdy nie sú naraz (A5; `toggleBackTh`, `form.js:750`): pri lištách hrúbka chrbta skrytá
   a výška viditeľná, pri „Bez chrbta" obe skryté (hodnoty sa pamätajú). **H sa validuje len pri aktívnom `rails`** (audit FIX 3 — `form.js:288` dnes
   validuje aj skryté polia: Z líšt → H 999 → Bez chrbta by neviditeľné neplatné pole zablokovalo „Aplikuj"); pri skrytí riadku sa zruší červené
   označenie aj tooltip chyby. Platí aj pri prepnutí na slot umývačky.
3. Súhrn v zbalenej hlavičke Chrbát: „z líšt 100 · komín 50" (A7; výška len pri lištách).
4. **„Vnút. hĺbka"** = `R − t` (`nxInteriorDepth`, `core.js:1589` — vetva pre `rails`; `updateAvailable` `form.js:607`); zrkadlo validácie 3.1 v
   `nxSetbackError`/`cabinetSetbackError` (tá istá veta ako server); tooltip komína: voľný kanál pri lištách = X (`backSetbackTipText`, `form.js:771`).
   **Pozor na skoré návraty KON-A pri X = Y = 0** (audit NOTE 4): `nxSetbackError` (`core.js:1613`), `cabinetSetbackError` (`form.js:256`) a
   `pvSetbackDepths` (`preview.js:412`) dnes pri nulách končia hneď — kontrola líšt a vnútro `d − t` (aj pre odhad políc a priečok) musia fungovať
   **aj bez komína**; označovanie chyby musí poznať aj pole H.
5. **Materiál chrbta** v sekcii Materiály pri lištách: „(nepoužije sa — chrbát z líšt je z korpusu)" (mockup A, vzor pri „Bez chrbta").
6. **`nxDraftStats`** (`preview.js:523`): pri lištách 2 × `(W − 2t) × H` z korpusu namiesto dosky chrbta; police a priečky podľa vnútra `R − t` aj pri X = 0.
7. Hodnotové testy parity Ruby ↔ JS + integračný test formulár → výpočet (vzor KON-A).

### 7 · Materiál chrbta pri lištách = ako „Bez chrbta"

`Panel.back_preflight` (`actions_cabinet.rb:161`), hrúbková brána projektového chrbta v `MaterialsDialog` (`materials_dialog.rb:1275`) a
`MaterialsReplaceUni` (`materials_replace_uni.rb:222`) — výnimka dnes len pre `none`, pri `rails` sa správajú rovnako (lišty nepotrebujú HDF).
Ručný materiál/ABS na `cabinet/back` pri prepnutí na lišty **čaká dormantný** (existujúci mechanizmus `PartKeys.migrate_overrides`) a po návrate
sa obnoví — prijaté.

### 8 · Dokumentácia

STANDARD §2 (config: `rails`, `back_rail_height`, `CONFIG_SCHEMA` 21), §3 (geometria líšt, vnútro `R − t`), §7 (roly, ABS seed 5, stojacia dolná
lišta), §8 (zlúčenie s výstuhami); `docs/architecture/construction.md`, `materials.md` (ABS seed, stojacie roly), `outputs.md` (VEPO názov, zlúčenie),
`model-a-identita.md` (roly, BuildPlan 6), `ui-lifecycle.md` (riadok Výška líšt); `VEPO_KONTRAKT.md`; POJMY (chrbát z líšt, „Chrb HD"); package +
surový audit do priečinka bloku.

## Scope OUT

„Použiť na podobné" pre obe lišty naraz (audit FIX 1 — vyžaduje novú sémantiku prenosu olepu) · rôzne výšky hornej a dolnej lišty · lišty v strede · iná hrúbka alebo materiál lišty než korpus (ručný override na karte dielca ostáva možný) ·
spoj líšt (skrutky, kolíky) · vnútro len v pásme líšt (M5 = celá výška) · šablóna Chladničková (KON-D) · bokorys (D-145) · slot umývačky.

## Dáta a kontrakt → audit ÁNO

`back_mode 'rails'` · `back_rail_height` · `CONFIG_SCHEMA` 21 · BuildPlan `SCHEMA` 6 + `ROLES` · ABS `SEED_VERSION` 5 · `STANDING_ROLES` (zmena
invariantu) · `ROLE_AXES`, `PART_TAGS`, `EDGE_LABELS` · VEPO `SHORT_NAMES` · STANDARD §2, §3, §7, §8.

## Otázky pre audit

1. Spoločný názov „Lista chrbta" → „Chrb HD" (rozdelený riadok po ručnom zásahu na jednej lište by tiež niesol „Chrb HD") vs. dva názvy s párom.
2. Dolná lišta ako prvá **korpusová stojacia rola** — čo ešte predpokladá, že stojace sú len dielce zásuvky?
3. Zlúčenie líšt aj s výstuhami **naplocho** (1 riadok 4 ks) — správne podľa výrobných parametrov?
4. Rozsah H 20–300, pravidlo `2H + 20 ≤ avail_h`, zápis len pri H ≠ 100.
5. „Použiť na podobné" so sesterskými rolami — áno/nie.
6. Čo prehliadame: ďalšie zoznamy rolí či `back_mode`, kópie, šablóny, hromadné zmeny, Kontrola olepov, smer dekoru, „Použiť vzhľad", náhľad.

## Testy a DoD

- **Headless:** golden plány ostatných režimov chrbta **bajtovo rovnaké** (BuildPlan `schema` 6 len tam, kde ho fixtúra nesie) · nová sada
  `tests/pure/test_konb_listy.rb`: geometria líšt × strop {plný, bez stropu, výstuhy naplocho, na výšku} × dno {na dne, medzi bokmi} × X {0, 50} × H
  {20, 100, 150} (box, origin, `prod`, `back_front_y`); validácia `2H + 20`; parsovanie H; whitelisty + round-trip + guard parity; `SEED_VERSION` 5
  merge (nové roly doplnené, vlastné pravidlá zachované); **kusovník: skrinka s lištami → 1 riadok, 2 ks, hrany `L1`, názov „Lista chrbta"; s výstuhami
  100 → 1 riadok, 4 ks; ručný materiál na jednej lište → 2 riadky** (oba „Chrb HD"); VEPO názvy („Chrb HD s…", „Vyst PZ/Chrb HD s…", dve skrinky); preflighty pri lištách
  ako pri „Bez chrbta"; `STANDING_ROLES` a invariant; staršia schéma (dopredná brána).
- **JS:** parita vnútra a odhadu, riadky Výška líšt/Hrúbka chrbta pri každom type chrbta, súhrn v hlavičke, zrkadlo validácie, riedky config (H → 100),
  výrazy v poli H; **integračný test „lišty bez komína + polica a priečka + červené H"** (audit NOTE 4 — kontrola aj odhad pri X = Y = 0); **neplatné H
  → prepnutie na Naložený, Bez chrbta a slot → „Aplikuj" nie je blokované a chybové označenie zmizne** (audit FIX 3).
- **In-SU** (nová sekcia `run_konb`, `-CloseWhenDone`, len `_dev\ENGINEtests.skp`): plán ↔ model 1:1 pre maticu · jeden krok Späť · prepnutie
  naložený → z líšt → naložený (dormantný override chrbta sa vráti) · uloženie a znovuotvorenie · kópia · šablóna · **Kontrola olepov** (páska na
  správnej ploche oboch líšt) · kusovník z modelu (1 riadok, 2 ks).
- **Mutačné overenie** (min. 5): `back_front_y` pri lištách bez `− t` · dolná lišta nie je stojacia — **zlyhá na polohe olepenej plochy** (model,
  Kontrola olepov/hover, 2D karta), **nie na počte riadkov** (audit FIX 2: mapa hrán ostáva `{L1}`, kusovník dá 1 riadok aj tak) · chýba seed bump ·
  `rails` padne na predvolený chrbát · chýba výnimka preflightu · chýba `ROLE_AXES` · H sa validuje aj skryté.
- Headless + každá JS sada zvlášť zelené; počty do PR a KRONIKY.

## Riziká

lišty bez pásky na existujúcich PC (seed bump — test) · dva riadky namiesto jedného (mapa hrán, ručný zásah) · starší plugin zmení lišty na dosku
chrbta (schéma 21 — **aktualizovať obe PC pred prvou výrobou s lištami**; samostatne prenesenú lištu schéma nechráni a starší plugin by ju vo VEPO
vydal pod plným názvom „Lista chrbta" — existujúca hranica ochrany, audit NOTE 5) · zlúčenie s výstuhami prekvapí dielňu („Vyst PZ/Chrb HD", 4 ks) · vnútro o `t` kratšie → iné NL výsuvov.

## Smoke pre Michala (po mergi, v0.13.3)

1. Dolná 600 × 720 × 510, Chrbát **„Z líšt"**, výška 100 → v modeli dve lišty 564 × 100 × 18 (dole na dne, hore pod stropom); „Vnút. hĺbka" 492;
   kusovník **1 riadok, 2 ks „Lista chrbta"**, VEPO **„Chrb HD s…"**, páska na jednej dlhej hrane.
2. Tá istá skrinka so stropom „Dve výstuhy" (100) → kusovník 1 riadok **4 ks**, VEPO „Vyst PZ/Chrb HD s…".
3. Výška líšt 290 pri dolnej skrinke 720 (vnútro 584) → pole červené a veta „Dve lišty po 290 mm sa do vnútra 584 mm nezmestia"; nič sa nepostaví.
4. Prepni späť na „Naložený" → chrbát HDF sa vráti (aj s ručným materiálom, ak bol).
5. Kontrola olepov: páska na hornej hrane dolnej lišty a na dolnej hrane hornej lišty.
6. Komín 50 + lišty → lišty posunuté o 50 dopredu, vnútro 442.
6a. Ručne zmeň materiál len jednej lišty → kusovník 2 riadky (správne — kusy sa líšia).
6b. „Z líšt" → výška 999 → prepni na „Bez chrbta" → „Aplikuj" funguje (skryté pole neblokuje).
7. Aktualizuj plugin aj u Lucie (schéma 21).

## Checklist uzáveru

VERSION 0.13.3 (2×) + všetky `?v=` · testy (headless, JS, in-SU) · docs (bod 8) · PLAN blok 7: riadok KON-B s ✅ a `PR #?` · **STAV prepis**
(v0.13.3, chrbát z líšt, schéma 21, BuildPlan 6, ABS seed 5 — aktualizovať obe PC) · KRONIKA · package + surový audit v priečinku bloku.

---

## Audit návrhu KON-B (Codex gpt-6-astra, 27.9.2026 ~11:00, 7,5 min, +4 % weekly) — **NOT SOUND: 0 BLOCKER · 3 FIX · 2 NOTE**

Surový výsledok: [AUDIT_KONB_2026-09-27.md](AUDIT_KONB_2026-09-27.md). Všetko zapracované vyššie (v1 → v2):

- **FIX 1 — „Použiť na podobné" so sesterskými rolami** olep nezjednotí (prenáša riedky override, chýbajúci override vráti lištu na jej pravidlo) →
  rozšírenie **vypustené** (4.4, Scope OUT); ručný zásah na jednej lište = dva riadky.
- **FIX 2 — mutant „dolná lišta nie je stojacia"** netvorí dva riadky (mapa hrán ostáva `{L1}`) → mutačný test na polohe olepenej plochy (DoD).
- **FIX 3 — skryté neplatné H** by blokovalo „Aplikuj" pri iných typoch chrbta → H sa validuje len pri `rails`, skrytie ruší chybu (6.2, testy).
- **NOTE 4 — skoré návraty pomocníkov KON-A pri X = Y = 0** → kontrola líšt a vnútro `d − t` aj bez komína + integračný test (6.4, 6.6, testy).
- **NOTE 5 — samostatne prenesená lišta** a starší plugin → aktualizovať obe PC pred prvou výrobou s lištami (Riziká).
- **Odpovede:** spoločný názov áno (po rozdelení oba riadky „Chrb HD") · prvá korpusová stojacia rola áno — iný predpoklad „stojace = zásuvka" sa
  nenašiel · zlúčenie s výstuhami naplocho áno pri zhode celého kľúča · H 20–300, `2H + 20`, zápis len ≠ 100 áno (nové šablóny výslovne 100) ·
  „Použiť na podobné" → FIX 1 · `BuildPlan::BACK_MODES` nerozširovať (1.5).
