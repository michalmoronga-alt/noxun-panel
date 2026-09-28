> ## ⚠ SUROVÝ VSTUP KRÍŽOVÉHO AUDITU — NIE ZADANIE
>
> Presná kópia pracovného konceptu v1 (28.9.2026 ~00:10), ktorý dostali audítori inline za zadaním
> [CROSS_AUDIT_PROMPT_2026-09-28.md](CROSS_AUDIT_PROMPT_2026-09-28.md) — zachovaná len preto, aby sa dali dohľadať odkazy nálezov (`§2`, `§5`…).
> **Nie je autoritou:** jeho technické návrhy (vzorce, rozsahy, roly, dávky) boli auditom čiastočne zamietnuté alebo zmenené — vyhodnotenie je v
> [RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md](RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md), autoritou pre každú dávku je až **jej package po audite návrhu**.
> Rez dávok z §13 (ROH-A / ROH-B) nahradil rez **ROH-A1 → ROH-A2 → ROH-B**. Súbory `ROH_*.md` v odkazoch sú dnes v tomto priečinku:
> fakty = [FAKTY_Z_KODU_2026-09-27.md](FAKTY_Z_KODU_2026-09-27.md), geometria DC = [DC_ROHOVA_GEOMETRIA_2026-09-27.md](DC_ROHOVA_GEOMETRIA_2026-09-27.md),
> rešerš = [RESERS_OUTSIDE_IN_2026-09-27.md](RESERS_OUTSIDE_IN_2026-09-27.md).

# KONCEPT K3 · rohová skrinka (v1, 28.9.2026 ~00:10) — pracovný podklad pre krížový audit bloku 8

> **Charakter:** NÁVRH orchestrátora na audit, nie zadanie dávky. Technické požiadavky pôjdu po reconcile do package dávky ROH-A (s vlastným
> auditom návrhu). Produktové rozhodnutia: `SYSTEM/zdroje/bloky/ROHOVA/ROZHODNUTIA_MICHALA_2026-09-27.md` (R1–R9, vetva `docs/blok8-rohova`).
> **Podklady:** fakty z kódu (main `44a9d2d4`, v0.14.0) `ROH_fakty_z_kodu.md` · presné meranie DC „Rohová" `ROH_dc_rohova_geometria.md`
> (sonda v samostatnom SketchUpe, vzorce DC overené redraw experimentmi) · rešerš precedensov `ROH_resers_outside_in.md`.

## 1 · Čo chceme (skrátene z R1–R9)

Dolná **slepá rohová skrinka s CR lištou** = bežná dolná skrinka + **rohová zostava** (blenda korpusová · výstuha závesov · rohová výstuha ·
CR 1 · CR 2) + **jedny dvierka v dverovej časti**. Parametre: šírka dverovej časti, CR 1, CR 2, strana dverí L/P (zrkadlí celú zostavu).
CR lišty z čelového materiálu s ABS dookola; závesy podľa výšky dverí (vlastník dvere), úchytka, nohy — žiadny rohový mechanizmus.
Pánty voliteľné smerom dverí, **predvolene pri rohu** (R7). Noc: dávka **ROH-A jadro** bez nových ovládačov (R8).

## 2 · Referenčná geometria (DC, „dvere vľavo", šírka W 1100, dverová časť D 450, cr1 = cr2 = 80, medzera P 4 = 2 + 2)

Súradnice DC = súradnice enginu (X šírka zľava, **+Y dozadu, čelná rovina korpusu Y = 0, čelá v −Y**, Z výška). `t` = hrúbka korpusu (18),
`th` = hrúbka čelového materiálu (18 / 18,6 / 19), `s` = sokel, `gC` = medzera dverí **na strane rohu** (DC P/2 = 2), `z_lo..z_hi` = svetlá výška
korpusu (`interior_dims`), dvere a CR = výška čela (`front_opening` mínus medzery hore/dole).

| Dielec | Materiál | X (dvere vľavo) | Y | Z | ABS (DC) |
|---|---|---|---|---|---|
| dvere (1 krídlo) | čelový | `gL … D − gC` (2–448) | čelo `−th … 0` | čelo | dookola |
| **blenda korpusová** | korpus | `D … W − t` (450–1082) | `0 … t` | `z_lo … z_hi` | **žiadne** |
| **výstuha závesov** | korpus | `D − t … D` (432–450) | `0 … 80` (hĺbka **80 pevne**) | `z_lo … z_hi` | len **zadná** hrana (Y 80) |
| **CR 1** | čelový | `D + gC … D + cr1` (452–530) | `−th … 0` | ako dvere | dookola |
| **CR 2** | čelový | `D + cr1 … D + cr1 + th` (530–548) | `−(cr2 − gC + th) … 0` (96) | ako dvere | dookola |
| **rohová výstuha** | korpus | `D + cr1 + th … D + cr1 + th + t` (548–566) | `−(cr2 + th) … 0` (98) | `s … h` (712) | predná + vrch + spodok |

- **Dvere prekrývajú výstuhu závesov o 16 mm** ako bok → pre dvere je výstuha „pravý bok"; svetlý otvor dverovej časti 18–432 (414 mm).
- **CR 2 a rohová výstuha trčia ~96–98 mm pred čelnú rovinu korpusu** (78–80 mm pred líce dverí) — ležia v rovine líca susedného kolmého radu;
  `cr1` posúva túto rovinu do šírky, `cr2` odstup susednej skrinky do hĺbky (výklad sondy, susedný rad v DC nie je).
- Pri zmene šírky rastie **len slepá časť** (blenda); rohová zostava je viazaná na dverový okraj. **Zrkadlenie = `X' = W − X − šírka dielca`**
  (DC to robí preklopením inštancie — v engine je ľavotočivá matica neplatný stav, preto zrkadlenie v pláne).
- DC nemá sokel, nohy, pánty ani úchytku; police (predvolene 0) idú **cez celú šírku vrátane slepej časti** a **pretínajú výstuhu závesov**
  (x 432–450, y 20–80) — dielňa to rieši výrezom. Rozdiel enginu voči DC: čelá bez 1 mm vzduchovej škáry pred korpusom (konvencia enginu).

## 3 · Návrh: nový typ korpusu `corner_blind` (nie prepínač na `lower`)

- **Prečo typ:** iná množina dielcov a parametre, ktoré inde nedávajú zmysel (PLAN r. 683 — „TYP = iná topológia"); typ riadi predvoľby,
  auto názov („Rohová skrinka 1100"), filter šablón, štítok v Inspectore, kontexty a náhľad. Prepínač na `lower` by musel rovnako prejsť
  whitelistami konštrukčných polí a navyše by „dolná" s rohovou zostavou zavádzala v UI aj šablónach. Horná rohová (mimo V1) by bola vlastný typ.
- **Typ sa správa ako `lower`** všade, kde nejde o rohovú zostavu: podpora nohy/sokel, `home_z` 0, konštrukčné polia (dno, strop, výstuhy,
  chrbát, komín, zapustenie, lišty chrbta), pravidlá kovania korpusu (`cabinet_type` filter — nohy ako dolná, závesné kovanie hornej nie).
  Implementácia musí prejsť **všetkými ~25 vetveniami podľa typu** (fakty §1.2) — kde je dnes `== 'lower'` alebo „neznámy → lower", treba
  rozhodnúť výslovne (nie spoliehať sa na pád do dolnej vetvy).
- **Zmena typu označenej skrinky v UI neexistuje** (fakty §1.4) — rohová vzniká len vložením (tlačidlo typu vo vkladacej karte) alebo zo šablóny
  typu `corner_blind`; server typ cez `handle_apply` prijme — **prepnutie iného typu na rohovú a späť** (cez API / šablónu) treba buď odmietnuť, alebo
  definovať (návrh: odmietnuť zmenu typu z/na `corner_blind` v `handle_apply*` s hláškou; šablóna iného typu sa na skrinku nepoužije už dnes).

## 4 · Config a dátový kontrakt

| Pole | Default | Rozsah (návrh) | Poznámka |
|---|---|---|---|
| `type` | `corner_blind` | — | `TYPES` += `corner_blind` |
| `corner_side` | `left` | `left` · `right` | strana **dverovej časti** pri pohľade spredu; roh je na opačnej strane |
| `corner_door_w` | 450 | 250 – 800 | šírka dverovej časti od vonkajšej plochy boku po os medzery dvere ↔ CR 1 (ako DC „Šírka dverí") |
| `corner_cr1` | 80 | 30 – 250 | CR 1 do šírky (od hranice dverovej časti po lice CR 2) |
| `corner_cr2` | 80 | 30 – 250 | CR 2 do hĺbky (od líca dverí po čelo rohovej výstuhy) |
| ostatné | ako `lower`, **šírka 1100** | ako `lower` | hĺbka, výška, sokel, dno, strop, chrbát podľa predvolieb dolnej (návrh; DC mal dve nadnože a pevný vložený chrbát — potvrdí Michal) |

- Polia rohovej sa zapisujú **len pri `type corner_blind`** (vzor polí slotu pri `dishwasher`); všetky uzavreté whitelisty konštrukčných polí
  (`normalize`, `cabinet_config`, `config_to_params`, `PARAM_KEYS`, JS `CONSTRUCTION_FIELDS`, `template_config_from`, `merge_template`, JS zrkadlá).
- **Odmietnutia stavby** (`validate!`, vety po slovensky): dverová časť mimo rozsahu; `D − t` ≤ `t` + min. svetlý otvor (návrh 150);
  `D + cr1 + th + t > W − t` (rohová zostava sa nezmestí pred slepú časť); `cr1 ≤ gC` (CR 1 by mala nulovú šírku); `cr2 − gC + th ≤ 0`.
- **Schémy:** `CONFIG_SCHEMA` 21 → **22** (nový typ + polia; dopredný guard R-12 zastaví starší plugin) · BuildPlan `SCHEMA` 6 → **7** (5 nových rolí) ·
  ABS `SEED_VERSION` 5 → **6** (pravidlá nových rolí) · `STD` šablón sa **nemení** (žiadna vstavaná šablóna). Legacy migrácia netreba (nový typ).

## 5 · Dielce, roly, materiály, výstupy

| Dielec | `part_key` (návrh) | Rola (návrh) | Kanál materiálu | ABS (seed 6) | Tag | Názov builder → VEPO (návrh) |
|---|---|---|---|---|---|---|
| blenda korpusová | `cabinet/corner_panel` | `corner_blind_panel` | korpus | žiadne | Korpus | „Blenda rohova" → „Blenda roh" |
| výstuha závesov | `cabinet/hinge_rail` | `hinge_rail` | korpus | 1 dlhá hrana = **zadná** | Korpus | „Vystuha zavesov" → „Vyst zav" |
| rohová výstuha | `cabinet/corner_rail` | `corner_rail` | korpus | predná dlhá + obe krátke | Korpus | „Vystuha rohova" → „Vyst roh" |
| CR 1 | `cabinet/cr:1` | `cr_front` | **čelový** | dookola 1,0 | Čelá | „CR lista 1" → „CR 1" |
| CR 2 | `cabinet/cr:2` | `cr_side` | **čelový** | dookola 1,0 | Čelá | „CR lista 2" → „CR 2" |

- **Kľúče nezávisia od strany** (zrkadlenie ich nemení). **Všetky mapy ABS sú symetrické v X** (žiadne, dookola, predná/zadná dlhá hrana
  stojaceho dielca, krátke hrany) → prepnutie L/P fyzicky nemení olepené hrany. Ručný override jednej hrany (L1/L2 pri dielcoch s hrúbkou v Y)
  by po prepnutí strany ukazoval na opačnú hranu — rieši ROH-B (prepínač strany), v ROH-A strana nemá ovládač.
- **Čelový materiál pre CR 1/CR 2 (pasca, fakty §2.7):** roly musia do `FRONT_MATERIAL_ROLES`, `thickness_ok_for?` (tolerancia 18,6/19),
  `materialized_part` (CR 1 hrúbka v **Y** ako dvere; **CR 2 hrúbka v X** — dnes neexistujúca vetva; poloha tak, aby **líce CR 2 smerom k dverám**
  ostalo na `D + cr1` a hrúbka rástla do slepej časti; rohová výstuha sa posúva o skutočnú `th`). `Validation::FRONT_ROLES` (ORANGE „čelo bez ABS"),
  `CpExport::FRONT_ROLES` (kategória „dvierka"), `part_card.js isFront`, `ROLE_LABELS`, `EDGE_LABELS`, `PartFaces::ROLE_AXES/STANDING_ROLES`,
  `PART_TAGS`, `RulesDialog::ABS_ROLE_ORDER`, `human_label`, `rdRoleDesc`, `SHORT_NAMES` — celý zoznam fakty §2.6 (~20 miest).
- **Smer dekoru:** CR 1/CR 2 stojace (dĺžka = výška) → dekor zvislo ako dvere; hromadná „Kresba čiel" (D-131) ich **nezasiahne** (nie sú riadky čiel) —
  otvorená otázka pre Michala (§11). Per-dielec override smeru funguje ako dnes.
- **Kusovník/VEPO:** nové roly idú bežnou agregáciou (rozmer + materiál + hrany); CR 1 a CR 2 majú rôzne rozmery → dva riadky.

## 6 · Čelá: dverová časť ako otvor

- `Construction.front_opening` pre `corner_blind`: `{x0: side == left ? 0 : W − D, w: D, z0: s, h: h − s}` — jadro (`Fronts.resolve_layout`)
  otvor užší ako skrinka už podporuje (fakty §3.1). **Plnú šírku natvrdo predpokladá** panelový preflight (`actions_cabinet.rb:55`), JS kresba čiel
  (`preview.js:886`, značky kovania `:1140`), draft resolver (`nxFrontsResolve`) a rozsah čiel (`nxFrontsExtent`) — všetky musia brať otvor zo servera.
- **Čelá rohovej = presne jeden riadok `door`, 1 krídlo** (R6). `normalize` to vynúti (posledná obrana); akcie panela, ktoré menia štruktúru čiel
  (pridať/odobrať riadok, zmeniť typ riadku, počet krídel), rohovú **odmietnu s hláškou** „Rohová skrinka má v dverovej časti jedny dvierka."
  Povolené ostáva: smer, úchytkový profil, medzery, materiál, smer dekoru, kovanie čela.
- **Medzery:** `gap_left`/`gap_right` fronts ostávajú; **medzera na strane rohu `gC`** = `gap_right` pri dverách vľavo, `gap_left` pri dverách vpravo —
  riadi aj CR 1 a CR 2 (DC: P/2 uberá dverám aj CR 1). Hore/dole ako dnes (CR 1/CR 2 majú výšku a Z ako dvere).
- **Smer pántov (R7):** nová rohová dostane dvere so smerom **pri rohu** (`right` pri dverách vľavo, `left` pri dverách vpravo). Guard
  `test_kova1_cela.rb:574–593` zakazuje v kóde predvolenú stranu — **vedomá výnimka na allowliste** pre jednu funkciu rohovej (rozhodnutie R7,
  nie tichý default: smer je vidno v súhrne čela a Kontrola ho berie ako určený). Používateľ smie zmeniť na vonkajší bok (pánty na boku).
  Prepnutie strany L/P (ROH-B) smer **zrkadlí** (pri rohu ostane pri rohu) — spolu s `gap_left`↔`gap_right`.
- Úchytkový profil UKW na dverách funguje ako dnes (hrana `free` oproti pántom).

## 7 · Interiér

- Strom zón stojí na celom vnútri (`x ∈ [t, W − t]`) → **police cez celú šírku vrátane slepej časti** (R6, ako DC). Polica od `y = 20`
  **pretína výstuhu závesov** (18 × 60 mm) — engine kolízie nekontroluje; návrh: **ako DC — výrez robí dielňa**, v kusovníku plný obdĺžnik
  (otvorené pre Michala, §11). Blenda (`y ∈ [0, t]`) policu nepretína.
- Priečky v zónach povolené ako dnes. Recepty zásuviek sa rohovej netýkajú (žiadne zásuvkové čelo). Nika spotrebiča — rohová nemá.

## 8 · Kovanie

- Bez nového pravidla: **závesy** podľa výšky dverí (rola `front_door`, 707 → 2 ks), **nohy** podľa šírky (1100 → 6 ks), príchyty sokla, podperky
  políc, úchytkový profil — ako dolná. Na ktorom dielci závesy sedia, engine nemodeluje (R5; pri rohu na výstuhe závesov).
- **Rešerš (Hettich W90, Blum blind corner):** špeciálne uhlové závesy sú pre dvere zavesené na **paneli v rovine dverí**; tu je výstuha závesov
  kolmá ako bok → bežný záves s prekrytím 16 mm (prax DC). Bez zmeny, informácia pre Michala.
- Náhľad nôh vo vkladacej karte beží dnes len pre `lower` (`hardware.js:2458`) → rozšíriť na `corner_blind`.

## 9 · Kontrola, ponuka, rozpočet

- Nové roly v `Validation::FRONT_ROLES` (CR 1, CR 2 → ORANGE bez ABS), hrúbka čelového materiálu podľa tolerancie čiel.
- Bez nových kontrol kolízií (sused v rohu, polica × výstuha, sokel okolo CR 2) — mimo V1 / zostavy.
- Ponuka: CR lišty v kategórii „dvierka" (čelový materiál), korpusové dielce rohovej vo „vnútorných korpusoch".

## 10 · Vkladanie, šablóny, Inspector, náhľad

- **ROH-A (bez nových ovládačov, R8):** tlačidlo **„Rohová"** v rade typov vkladacej karty (Dolná · Horná · **Rohová** · Umývačka · Doska; ikona),
  `DEFAULTS` typu zo servera (`sync.rb`), `applyVisibility` ako dolná, `NX_TYPE_LABEL` „Rohová", `CAB_TYPES`/`INSERT_TYPES`, filter šablón
  podľa typu (neznámy typ dnes padne do „dolnej" — `insert_state.js:256–267`), modal „Uložiť ako šablónu" má typ rohovej **zamknutý**
  (vzor slotu), `apply_template_type!` rohovú nepreklopí. **Náhľad** kreslí dvere v dverovej časti (otvor zo servera, vzor slotu `params['preview']`);
  slepá časť v ROH-A bez kresby rohovej zostavy. Ghost: obálka `[0..W] × [0..d] × [0..h]` — CR 2 a rohová výstuha trčia pred ňu (nominálna obálka
  ako dnes pri presahujúcich čelách).
- **ROH-B (po schválení mockupu):** riadky Inspectora (dverová časť, CR 1, CR 2, strana dverí), prepínač strany (zrkadlí smer, medzery, overridy hrán),
  kresba rohovej zostavy v náhľade, skrytie ovládačov štruktúry čiel pri rohovej, prípadne polia rohovej vo vkladacej karte.

## 11 · Observer mierky, Undo

- Absorpcia scale: šírka mení len `width` (dverová časť a CR absolútne → rastie slepá časť, **presne ako DC**). **Absorpcia šírky dnes nie je
  config-aware** (fakty §10: zúženie pod minimum → výnimka prestavby a tichý návrat); pre rohovú je minimum veľké (`D + cr1 + th + 2t`) →
  návrh: config-aware klamp šírky pre `corner_blind` (vzor `min_valid_depth` + nemodálna veta). Výška/hĺbka ako dolná.
- Vloženie = 1 krok Späť; prestavba zachová polia rohovej (`config_to_params`); kópia nástrojom (Mower) a „Vložiť kópiu" cez `config_to_params`.

## 12 · Kompatibilita

Starší plugin (schéma 21) rohovú neprestaví ani nevyexportuje (R-12); pri čítaní by typ sklopil na `lower` (`norm_type`) — čítanie kusovníka ide
zo snapshotu dielcov. **Aktualizovať obe PC pred prvou rohovou.** Golden plány dolnej/hornej sa nesmú pohnúť.

## 13 · Dávky

- **ROH-A · jadro rohovej** (audit-povinná: nový typ, schéma 22, BuildPlan 7, ABS seed 6, observer klamp; výrobná: nové dielce do kusovníka/VEPO):
  §3–§11 okrem ROH-B. In-SU brána: geometria plán ↔ model pre obe strany (strana cez config v teste), viac šírok, dverová časť 300/450/600,
  CR 50/80/120, hrúbka čelového 18/18,6/19, prestavba zachová polia, Späť, scale šírky (rast slepej časti, klamp), kusovník/VEPO názvy, závesy 2,
  nohy 6, smer pri rohu. Headless: typ vo všetkých zoznamoch, pripnuté zoznamy a čísla schém, parity JS↔Ruby, seed ABS merge.
- **ROH-B · ovládače a strana** (UI + prepínač strany = zápis do modelu → in-SU): podľa schváleného mockupu.
- **Scope OUT bloku:** horná rohová, LeMans/karusel, kolízie so susedom, sokel okolo rohu, výrez police, kresba čiel pre CR (ak Michal nepovie inak).

## 14 · Otázky pre audit

1. Typ `corner_blind` vs. konštrukčný prepínač na `lower` — skryté náklady, ktoré návrh prehliada?
2. `materialized_part` a hrúbka čelového materiálu v osi X (CR 2) — bezpečný spôsob bez rozbitia čiel; `axes`/`PartFaces` pre dva nové stojace
   dielce z čelového materiálu; zarovnanie pri `th` ≠ 18.
3. Otvor čiel užší ako skrinka — všetci čitatelia plnej šírky (preflight, JS náhľad, draft, rozsah čiel, kovanie čiel, `direction_check`, Kontrola)?
4. Vynútený jediný riadok `door` — kde všade sa dá štruktúra čiel zmeniť (akcie panela, šablóny, „Použiť na podobné", pravidlá, Nahradiť UNI, D-131)?
5. Výnimka z guardu „žiadny default smeru" (R7) — ako ju ohraničiť, aby neotvorila tichý default inde.
6. Dielce pred čelnou rovinou (Y < 0, korpusový materiál) — dôsledky pre `envelope`, `Placement`, Snaper, ghost, `PartFaces`, Kontrolu olepov, D-37.
7. Config-aware klamp šírky pri scale — riziko pre observer/Undo lifecycle (R-01/R-04, `flush_pending!`).
8. Rozdelenie ROH-A — je to jedna dávka, alebo rez (napr. A1 dáta+stavba+výstupy, A2 vkladanie+náhľad)?
9. Precedensy v CAD (blind corner s fillerom) — čo návrh prehliada (výrobne, kovanie, zrkadlenie dekoru a hrán)?

## 15 · Otvorené otázky pre Michala (pôjdu do mockupu ROH-B ako „návrh — potvrdí Michal")

Predvolené rozmery a konštrukcia (šírka 1100, hĺbka ako dolná 510, strop/chrbát ako dolná vs. DC dve nadnože + pevný vložený) · rozsahy
dverovej časti a CR · názvy dielcov v kusovníku a VEPO (§5) · ABS podľa DC (blenda bez ABS, výstuha závesov len zadná, rohová výstuha predná + krátke) ·
polica × výstuha závesov (výrez v dielni?) · CR lišty a „Kresba čiel" (majú ísť s dverami?) · kde v Inspectore riadky rohovej a prepínač strany.
