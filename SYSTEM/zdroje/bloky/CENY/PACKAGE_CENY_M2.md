# PACKAGE CENY-M2 · Rozpočet — vek ručných cien, odkaz a „Overiť cenu", materiál bez formátu podľa skutočných m² (C12)

> **PLATÍ (30.9.2026, počas PR #428): Q2 rozhodnutá — Michal C14 „áno, aj bežná doska podľa skutočnej plochy dielcov (bez odpadu)" → platí vetva
> R1a** (`Budget.area_priced_type?` = každý typ; UNI a duplák ostávajú na odhade), NP-4 golden pregenerovaný (NOF 180,84 → 32,76 €, SPOLU 3394 → 3246 €),
> golden B podľa S22/E4 (NOF → 47,74 €, SPOLU → 2070 €). **Q1 bez odpovede — porez a montáž bez zmeny.** Text nižšie opisuje pôvodný stav s obmedzeným R1
> tam, kde to R1a výslovne nemení; pri rozpore platí tento rámček a [ROZHODNUTIA_MICHALA_2026-09-29.md](ROZHODNUTIA_MICHALA_2026-09-29.md) (C14).

> **Autorita:** rozhodnutia Michala C1–C13 (`SYSTEM/zdroje/bloky/CENY/ROZHODNUTIA_MICHALA_2026-09-29.md` — **C6** Rozpočet ukazuje vek ručných cien a počíta ich
> „na kontrolu", UNI a duplák bez akcií · **C11** mockup schválený, O1–O9 podľa návrhu · **C12** materiál bez formátu v Rozpočte podľa skutočných m² dielcov),
> schválený mockup `MOCKUP_CENY_2026-09-30.html` — **obrazovka D** (D1–D4 + „Na vedomie") a karty **O1, O2, O5, O9, O10** (odporúčanie = schválené znenie),
> fakty `FAKTY_Z_KODU_2026-09-29.md` (pasca 5: stav `manual` materiálov je zamknutý testami). Stavia na package **CENY-M1** (scratchpad verzia s delta auditom):
> **R10** `Materials.manual_price_state` (jediná autorita stavu ručnej ceny), **R11a** `Materials.display_m2`, **R15** akcie `mat_manual_*`, **R19/R20/R23** formulár
> „Overiť cenu" a jeho životný cyklus, **R24** (čo M1 v Rozpočte nemenil). Vzor v Rozpočte: CENY-KOV-B (`core/budget.rb` `manual_hardware_freshness`,
> `ui/js/budget.js` `budHardwareLink`/`budManualCheckHtml`, `ui/js/hw_catalog.js` `hwManualRequest` v sekcii `budget`).
> **Kde sa package a vzor kovania rozchádzajú, platí package** (O9 overenie aj bez odkazu, O5 texty stavu, O1 ikona aj pri Demos materiáloch).
> **Trieda:** **audit-povinná** (mení sa dátový kontrakt payloadu Rozpočtu — riadok Materiálu už nie je vždy „celé platne", STANDARD §11.2/§11.3; blok navyše
> predpisuje Codex audit každej dávky — C9) · **cenová dávka** (mení sumy zákaziek s materiálom bez formátu) · **slepá predrecenzia povinná** (cenová + nové
> ovládacie prvky UI + > 300 riadkov) · **in-SU nie je brána** (§8) · `codex-po-pr` bez výnimky.
> **Verzia:** patch (po M1b v0.16.2 → **v0.16.3**) + všetky `?v=` + prepis STAV. **M2 je posledná dávka bloku** — hneď po jej mergi uzáver bloku `release/ceny`
> (minor **v0.17.0**, §11).
> **Stav kódu:** sonda nad `main` **`bb2c3411`** (v0.16.1 = po CENY-M1a; M1b v maine **ešte nie je** — worktree M1b bez commitov). Požiadavky označené **[M1b]**
> stavajú na API z package M1, ktoré v maine zatiaľ neexistuje (S14) — **pred štartom implementácie ich orchestrátor overí proti mainu po mergi M1b** (mená,
> tvar návratových hodnôt, kontextová kontrola klienta) a package zladí; pri zmene kontraktu nový audit.
> **Audit návrhu (Codex gpt-6-astra, 30.9.2026, surový výstup `AUDIT_CENY_M2_2026-09-30.md`): 1 BLOCKER + 2 FIX + 1 NOTE — zapracované:** BLOCKER → testy, golden,
> texty, riziká, smoke a uzáver zosúladené s obmedzeným **R1** (bežná doska bez formátu ostáva na dnešnom odhade; **NP-4 golden sa nemení**; cenová zmena sa
> overuje na **fixtúre so sklom**; nový **R1a** = vetva „Q2 = všetky typy") · FIX-2 → **R10** (`manual_hardware` len `kind == 'hardware'`, `manual_pending` jedným
> priechodom; sonda S21) · FIX-3 → **R1** (`Materials.type_registry_entry(...).nil?`, nie `TYPE_REGISTRY.key?`; sonda S20) · NOTE-4 → **§5, §9, §10, §11**
> (starší plugin na druhom PC vyexportuje sklo za starú cenu — vedome prijaté prevádzkové riziko + povinná veta „aktualizovať obe PC pred porovnávaním alebo
> posielaním ponúk").

---

## 0 · Sonda pred auditom (skill `codex-audit`, krok 0) — 30.9.2026

Skripty a surové výstupy: scratchpad `CENY/sonda_m2.rb` (+`_out.txt`), `sonda_m2b.rb`, `sonda_m2c.rb`, `sonda_m2d.rb`, `sonda_m2e.rb` (po audite), `sonda_m2.js` (+`_js_out.txt`). Beh nad **snapshotom
`main bb2c3411`** exportovaným cez `git archive` do scratchpadu (`CENY/m2snap/`) — repo ani živý katalóg sa nedotkli; Ruby cez `tests/helper.rb` (APPDATA = sandbox),
JS nad reálnym `budget.js`/`sheet_layout.js` s `tests/js/minidom.js`. Do modelu ani do repa sa nič nezapisovalo.

| # | Tvrdenie o dnešnom kóde | Skript · test | Čo vrátil | Verdikt |
|---|---|---|---|---|
| S1 | `Budget.freshness_item('sheet'/'edge', …)` pri zázname **bez `demos_url`** vráti napevno `manual` — ručné overenie (`price_check_method`, dátum) ignoruje, `checked_at` len prepustí, `age_days` nil; **to isté UNI aj duplák** | sonda_m2.rb P1a–d | sklo overené pred 12 dňami → `state "manual"`, `checked_at` prepustený, `age_days nil`; ABS, UNI aj duplák → `manual` | PRAVDA — **pasca O2:** UNI (a neviazaný duplák) sú dnes v zozname ako „ručná položka" → R9 ich vyradí |
| S2 | `stale_scan` skenuje LEN materiály odhadu, pásky zákazky a použité kovanie; `items` vynechá `fresh`; `counts` = `stale/unverified/manual/fresh/manual_hardware/attention`; `attention` = staré + nevyriešené ručné **kovanie** — ručné materiály nepočíta | P2a/P2b | 1 Demos stará doska + 6× `manual` (vrátane UNI) → `{"stale"=>1, "manual"=>6, "manual_hardware"=>0, "attention"=>1}` | PRAVDA |
| S3 | Materiál **bez formátu** (nie UNI) sa dnes počíta ako fiktívna platňa 2800 × 2070: `mnozstvo = ceil(count_max)`, MJ `PLATŇA`, `cena_mj = round2(€/m² × 5,796)`, `estimated: true`, poznámka „… odhad podľa 2800×2070" | P3 | sklo 0,9 m² à 41,5 €/m² → `["PLATŇA", 1, 240.53, 240.53, …, true]`; DTD bez formátu 1,53 m² (s duplákom) → 1 × 180,84 €; bez ceny → `price_missing` | PRAVDA — C12 to mení pri **skle** (typ mimo registra); DTD bez formátu ostáva (R1) |
| S4 | Skutočná plocha dielcov je v odhade: `g['m2']` = Σ dĺžka × šírka × ks / 10⁶ **vrátane duplákov × násobok**, **bez prerezu** (koeficienty len v `count_min/max`), **zaokrúhlená na 3 desatinné** | P4a, P13a–c | SK4 `0.9`, NOF `1.53` (z toho `doubled_m2 0.48`); 1869 × 500 → `0.935` → `.round(2)` = `0.94`, priamo `0.9345.round(2)` = `0.93` | PRAVDA — **pasca dvojitého zaokrúhlenia** → R2 (`m2_exact`) |
| S5 | Služby: porez = Σ `mnozstvo.to_i` riadkov Materiálu, montáž = Σ (`estimate_qty` ‖ `mnozstvo`).to_i | P5, P5b (simulácia riadku skla v m²) | dnes porez 7 / montáž 40,6; pri `mnozstvo = 0.9` → porez **6**, montáž **34,8** | PRAVDA — **pasca:** riadok v m² by potichu zmenil služby → R5 |
| S6 | NP-4 zapnuté: materiál bez formátu je nespôsobilý (`no_format`), riadok `qty_source: 'estimate'`, poznámka „… plán: orientačne 1 platňa pri formáte 2800 × 2070 · formát chýba — cena z odhadu", suma = vypnutý prepínač | P6a–c | `[false, ["no_format"], "formát chýba — cena z odhadu"]`, riadok `["PLATŇA", 1, "estimate", 1, 180.84, …]` | PRAVDA |
| S7 | Karta Nárezového plánu berie „v rozpočte N" z `mnozstvo` riadku Rozpočtu (`budget_qty`) a zdroj z `qty_source` (`budget_src`) | P7, sonda_m2.js J7 | `[1, nil, 1, true]`; pri `budget_qty 0.9` karta napíše „v rozpočte dnes 0.9" | PRAVDA — **pasca:** m² by sa ukázali ako počet platní → R7 |
| S8 | XLSX rozpočtu zapíše `mj`/`mnozstvo`/`cena_mj`/`spolu` 1:1, číselný formát `#,##0.00` (`S_NUM = 3`) | P8a/b | `["PLATŇA", 1.0, 240.53, 240.53]`, styl 3 | PRAVDA — množstvo musí mať 2 desatinné (inak XLSX ukáže 0,94 × cena ≠ súčet) → R2 |
| S9 | Cenová ponuka: materiál vždy `[1, 'set']`, mení sa len suma; `MJ_LABELS['M2'] = 'set'`; sklo 240,53 € je dnes **samostatný riadok** (prah 150 €), po C12 (37,35 €) **spadne do „Nábytkovej zostavy"** | P8c–e, sonda_m2b.rb | dnes `separate [H18, SK4]`, po simulácii C12 `separate [H18]`, zostava 151,83 → 188,36 €, súčet 1502 → 1298 € | PRAVDA — dôsledok pomenovaný v §9 |
| S10 | `PriceRefresh.targets_from_budget` berie len položky s `demos_url`; `manual_from_budget` = bez Demosu a nie `fresh` — dnes vrátane UNI | P9a/b | targets `[["sheet","H18"]]`; manual 6 položiek vrátane UNI | PRAVDA |
| S11 | `budget.js`: `budMaterialRow` ukáže množstvo s **0 desatinnými** a „(€/m²)" vždy; `budFreshCell` ručného materiálu = „—"; `budStaleActionHtml` = „bez Demos väzby — over v katalógu ručne"; `budStaleLabel`/`budPriceBtnHtml` sa rozhodujú len podľa `manual_hardware` | sonda_m2.js J1–J6 | 0,9 m² → „1"; „—"; veta „over v katalógu ručne"; pri 6 ručných materiáloch bez Demos starých čip **nie je** (`null`), tlačidlo „Prepočítať ceny" | PRAVDA — všetko mení M2 |
| S12 | Vzor kovania: `hwManualRequest` pustí ručné overenie zo sekcií `hw` **aj** `budget` (formulár ostane v Rozpočte) | J8 | `true` | PRAVDA — vzor pre R18 |
| S13 | Platný formát: `SheetEstimate.sheet_size_for` aj `Materials.normalize_pair` prijmú **akúkoľvek kladnú dvojicu** (300 × 200 nie je fallback); `SHEET_SIZE_RANGE` 500–5000 platí len vo validátoroch zápisu | P10a–d | `[[300.0, 200.0], false]`, `[300.0, 200.0]`, `500.0..5000.0` | PRAVDA — M2 berie za jedinú pravdu `fallback` odhadu (R1); rozdiel voči M1b R11 krok 5 = §9 |
| S14 | API M1b v maine **nie je**: `Materials.manual_price_state`, `Materials.display_m2`, akcie `mat_manual_*`, klientske `mdManual*`; `MD_CLIENT_SCHEMA = 11`; z M1a existuje `manual_product_record?`, `sanitize_product_url`, `mat_product_open` | P11a–f, J9 | `false, false, true, true`, SCHEMA 11, `["mat_product_open"]`, `[]` | PRAVDA — [M1b] závislosti (§5.1) |
| S15 | Zlatý test NP-4 (`tests/fixtures/np4_golden`) obsahuje **DTD bez formátu** `NOF` (31,2 €/m², 1,05 m²): dnes 1 platňa 180,84 €, SPOLU 3394 €; porez 9; `stale` 6× `manual` vrátane UNI a duplákového záznamu `W36`, `attention 0` | P12a–f | vo vetve „všetky typy" by bolo 1,05 × 31,2 = **32,76 €**, raw 3393,29 → 3245,21, SPOLU **3394 → 3246 €** | PRAVDA — `NOF.type == 'DTDL'` (register) → pri obmedzenom **R1 sa NP-4 golden číselne nemení** (zlatý test A, §7 bod 3); zmenil by sa len vo vetve **R1a** |
| S16 | C12 nepridáva do dát zákazky žiadny kľúč: `BUDGET_STD = 3`, stav zákazky = 10 kľúčov (`mode … plan_prices, std`) — payload Rozpočtu sa počíta živo, neukladá sa | sonda_m2c.rb | `3`, zoznam kľúčov bez zmeny | PRAVDA — **bez bumpu `BUDGET_STD`**, R-14 brána netreba (§5) |
| S17 | Každý zápis katalógu materiálov obnoví Štúdio: `after_catalog_change` → `StudioDialog.refresh_if_open(bump: false)` (Rozpočet sa po potvrdení ceny prepočíta sám) | sonda_m2c.rb | `true` | PRAVDA — R18 nepotrebuje vlastný push |
| S18 | `BUD_STD_OFF` (vypnuté ovládače pri nekompatibilných dátach rozpočtu) je kľúčovaný `data-bud`; tlačidlá kovania s `data-action` v ňom nie sú | `budget.js:240`, sonda_m2c.rb | zoznam bez `hw-*` | PRAVDA — nové `data-action` tlačidlá M2 ostanú zapnuté (zapisujú katalóg, nie zákazku — ako „Prepočítať ceny") |
| S19 | Zaokrúhlenie €/m² na centy: `Float#round(2)` a `BigDecimal half_up` sa zhodujú na hraniciach pol centa (1,005 · 31,005 · 2,675 · 0,125) | sonda_m2d.rb | `1.01, 31.01, 2.68, 0.13` oboma | PRAVDA — R3 použije jednu funkciu M1b (`display_m2`) |
| S20 | *(po audite, FIX-3)* Register typov má normalizáciu `Materials.type_registry_entry(type)` = `TYPE_REGISTRY[identity_norm(type)]` (strip, zlúčenie medzier, veľké písmená); holé `TYPE_REGISTRY.key?` ju obchádza. **Diakritiku `identity_norm` nezlučuje.** | sonda_m2e.rb E1 | `DTDL`, `dtdl`, `" DTDL "`, `"Dtdl\t"`, `hdf`, `"kompakt "` → v registri (`entry.nil? == false`), hoci `key?` pri malých písmenách/medzerách vráti `false`; `SKLO`, `sklo`, `Zrkadlo`, `""`, `nil` → mimo registra; **`Zástena`/`ZÁSTENA` → mimo registra** | PRAVDA — R1 použije `type_registry_entry`; diakritika zástena = §9 |
| S21 | *(po audite, FIX-2)* `counts['manual_hardware']` (`budget.rb:674`) počíta **všetky** položky s `manual_check` ≠ `fresh` **bez filtra druhu** | sonda_m2e.rb E2 | zdrojový riadok bez `kind`; nad zmiešanými položkami (1 kovanie + doska + ABS s `manual_check`) vráti **3** | PRAVDA — **pasca:** po R9 by `manual_hardware` rátal aj materiály a `manual_pending = manual_hardware + manual_materials` by bol dvojnásobný → R10 |
| S22 | *(po audite, BLOCKER)* Čísla fixtúry B pri obmedzenom R1: mení sa len sklo (typ mimo registra), DTD bez formátu `NOF` ostáva platňou | sonda_m2e.rb E3/E4 | sklo 240,53 → **37,35**, medzisúčet Materiálu 889,91 → **686,73**, raw 2406,14 → **2202,96**, SPOLU 2407 → **2203** (zaokr. 0,04); vetva R1a navyše NOF 180,84 → 47,74, medzisúčet → 553,63, SPOLU → 2070 | PRAVDA — golden B §7 bod 3 |

**Opravené tvrdenia oproti zadaniu/FAKTY:** žiadne nepravdivé; doplnené pasce S1 (UNI/duplák v zozname), S4 (dvojité zaokrúhlenie), S5 (služby), S7 (karta plánu), S9 (ponuka),
po audite S20 (normalizácia typu) a S21 (`manual_hardware` bez filtra druhu).

---

## 1 · Cieľ

**Rozpočet → Materiál a ABS hrany** preberie ručné overenie z CENY-M1b: položka bez Demos väzby ukazuje v stĺpci „Overená" svoj stav („ručne 18.9." / „ručne 45 dní" /
„neoverená") a ten je zároveň tlačidlom **„Overiť cenu"** — ten istý formulár ako v Štúdiu, ale ostáva sa v Rozpočte. Čip **„N cien na kontrolu"** počíta aj ručné
materiály a pásky použité v zákazke (nikdy neoverené, staršie ako prah, bez ceny; UNI a duplák nie), zoznam pod ním má pri nich odkaz a „Overiť cenu". Pred názvom
materiálu a pásky je ikona odkazu (Demos otvorí Demos, ručná obchod, chýbajúca vedie na doplnenie). A **materiál bez formátu, ktorý nie je bežná doska** (sklo na
mieru — typ mimo registra typov) sa počíta podľa **skutočných m² dielcov** × cena za m², nie ako fiktívna platňa 2800 × 2070. **Bežná doska bez formátu**
(DTDL, MDF, HDF, PD, ZASTENA, KOMPAKT) ostáva do Michalovej odpovede na Q2 na dnešnom odhade platní.

## 2 · Rez dávky — odhad veľkosti a odporúčanie

Odhad zmenených riadkov **kódu pluginu** (bez testov, dokumentácie a mechanického `?v=`). Referencia: CENY-KOV-B mal v Rozpočte ~95 riadkov.

| Súbor | C12 (plocha) | stav a akcie | spolu |
|---|---|---|---|
| `core/budget.rb` (area vetva + `area_priced_type?`, služby, `freshness_item`, `stale_scan` s filtrom druhu, polia riadkov) | ~50 | ~70 | ~120 |
| `core/sheet_estimate.rb` (`m2_exact`) | ~3 | — | ~3 |
| `ui/production_core.rb` (`budget_src 'area'`) | ~3 | — | ~3 |
| `ui/materials_dialog.rb` (sekcia `budget` v `mat_manual_*`, ak M1b sekcie whitelistuje) | — | ~0–5 | ~5 |
| `ui/js/budget.js` (riadok v m², ikona, „Overená", čip, zoznam, tooltip ponuky) | ~15 | ~155 | ~170 |
| `ui/js/proj_materials.js` (delegované kliky `mat-*`, kontext `budget`, preklik do Materiálov) | — | ~55 | ~55 |
| `ui/js/sheet_layout.js` (karta „v rozpočte … m² podľa plochy") | ~6 | — | ~6 |
| `ui/studio.html` (CSS `.bver`, drobnosti) | — | ~20 | ~20 |
| **Spolu** | **~75** | **~305** | **~380** |

**Odporúčanie: bez rezu** (~380 < 700; po audite +~10 riadkov za `area_priced_type?` a filter druhu v počtoch). Obe časti sa dotýkajú tých istých riadkov Rozpočtu
(`materials_section`, `budMaterialRow`) a zlatých testov — rez by znamenal dvakrát zasahovať do golden a dve kolá review. **Voliteľný rez**, ak orchestrátor chce menšie
PR: **M2a · C12** (Ruby ~75 + golden B; čisto cenová) → z čerstvého `main` **M2b · stav a akcie** (~305; UI, bez zmeny súm). Požiadavky sú označené **[C12]** / **[STAV]**.

## 3 · Scope IN

- **[C12] Výpočet:** materiál bez platného formátu, **ktorého typ nie je v registri typov** (nie UNI, nie duplák, záznam v katalógu existuje — R1) = riadok v **m²**
  (skutočná plocha dielcov × cena za m²); služby, NP-4, karta plánu, XLSX a ponuka dôsledne podľa §6.1. Vetva „Q2 = všetky typy" je pripravená ako jedna funkcia (R1a).
- **[STAV] Server:** stav ručnej ceny materiálu/ABS z `Materials.manual_price_state` [M1b] do `stale.items` aj do riadkov; nové počty `manual_materials`, `manual_pending`;
  UNI a duplák mimo scanu; polia riadkov `product_link` / `demos_link` / `price_check`.
- **[STAV] UI Rozpočtu:** ikona odkazu pred názvom (Materiál aj ABS, aj Demos), stĺpec „Overená" = stav + „Overiť cenu", čip „N cien na kontrolu" a „Skontrolovať
  ceny" aj pre ručné materiály, zoznam s odkazom a „Overiť cenu", tooltip čipu v Cenovej ponuke.
- **[STAV] Formulár „Overiť cenu" z Rozpočtu:** znovupoužitie M1b (akcie `mat_manual_*` + modal) so `section: 'budget'`.
- **Dokumentácia:** STANDARD §11.2–§11.4, `docs/architecture/outputs.md`, `ui-lifecycle.md`, `docs/UI_DIZAJN.md` §E-b, STAV, KRONIKA, PLAN, DOGFOODING.

## 4 · Scope OUT

- Katalóg materiálov a Štúdio → Materiály (všetko je M1a/M1b; M2 v nich mení len kontext klienta `mdManual*` a pridáva preklik z Rozpočtu). **Schéma katalógu sa nemení.**
- Kovanie v Rozpočte (vrátane formátu dátumu „ručne 10.09.2026" — §13 F2), kovanie v katalógu.
- Kusovník (súčty, „odhad platní" pri skle ostáva orientačný — §13 F3), VEPO, Nákup kovania, Kontrola (žiadny nový nález — O2).
- Minimálna fakturačná plocha kusa skla, prerez/odpad pri materiáli za m², nález „doska bez formátu" (§13 F1, F4).
- Porez a montáž pri materiáli bez formátu — **nemenia sa** (D5; Q1 „bez zmeny").
- **Bežná doska bez formátu** (typ v registri: DTDL, MDF, HDF, PD, ZASTENA, KOMPAKT) — ostáva na dnešnom odhade platní 2800 × 2070 (R1; Q2 do Michalovej odpovede).
- Nárezový plán materiálu bez formátu — plán ostáva orientačný pri 2800 × 2070 (NP-1/NP-3), mení sa len veta karty o Rozpočte.

## 5 · Dotknuté dáta a kontrakt → **audit ÁNO**

- **Payload Rozpočtu (kontrakt STANDARD §11.2/§11.3, `docs/architecture/outputs.md` budget.rb)** — mení sa **význam** riadku Materiálu: dnes „celé platne × cena
  za platňu" pre každý riadok, po M2 pri materiáli bez formátu mimo registra typov (R1) **`mj: 'M2'`, `mnozstvo` = m², `cena_mj` = €/m²** a nový kľúč `qty_basis: 'area'`. Aditívne kľúče:
  riadky Materiál/ABS `product_link`, `demos_link`, `price_check`, area riadky `estimate_qty` (vždy); `stale.items[]` ručných materiálov `manual_check`,
  `product_link`, `price_missing`, `price_check_method`; `stale.counts.manual_materials`, `stale.counts.manual_pending`. Konzumenti (všetci v tomto pluginu, jedna
  verzia s klientom): `budget.js`, `xlsx_writer.rb` (bez zmeny), `cp_export.rb` (bez zmeny), `production_core.rb` (`sheet_layout_payload`, `plan_export_note`),
  `services_section`, `price_refresh.rb`, `Validation.with_budget` (bez zmeny).
- **`BUDGET_STD` sa nezvyšuje** (S16): M2 nepridáva do dát zákazky žiadny kľúč; payload sa počíta živo z katalógu a nikde sa neukladá. **Dopredná brána (vzor R-14)
  netreba** (v súlade so STANDARD §11.3 — bump je len pri poli, ktorého strata alebo ignorovanie poškodí cenu; tu žiadne nové pole nie je). **Vedome prijaté
  prevádzkové riziko (audit NOTE-4):** starší plugin (≤ v0.16.2) na druhom PC tú istú zákazku so sklom stále ocení fiktívnou platňou a **vyexportuje XLSX
  rozpočtu aj ponuky so starou cenou** (sklo 240,53 € namiesto 37,35 €) — žiadna brána to nezachytí, lebo dáta zákazky sa nezmenili (nie je to poškodenie dát).
  **Povinná veta do STAV, PR popisu, reportu aj smoke:** „Aktualizuj plugin na oboch PC pred porovnávaním alebo posielaním ponúk — starší plugin počíta sklo
  bez formátu po starom." (M1b to kvôli schéme 12 vyžaduje aj tak.)
- **Katalóg materiálov:** schéma sa nemení; M2 nič nové nezapisuje (zápisy robia výhradne akcie M1b).
- **Model:** žiadna `start_operation`, observer, undo, builder ani geometria.
- **Audit-povinnosť:** zmena dátového kontraktu payloadu (C12) → `codex-audit` áno (model roly „audítor audit-povinných" podľa WORKFLOW); aj bez toho ho blok predpisuje (C9).

### 5.1 Závislosti na M1b — pred implementáciou overiť proti mainu po M1b

| Čo M2 potrebuje | Podľa package M1 | Overiť |
|---|---|---|
| `Materials.manual_price_state(rec, stale_days:, now:)` → `nil` (Demos/UNI/duplák) alebo `{'state' => 'fresh'\|'stale'\|'never', 'checked_at', 'age_days'}`; platné overenie nevyžaduje odkaz; cena konečná ≥ 0 | R10 | meno, kľúče, `never` pri chýbajúcej cene |
| `Materials.display_m2(value)` — jediné zaokrúhlenie €/m² na centy (half-up) | R11a | meno a návratový typ (Float/BigDecimal/String → M2 berie `.to_f`) |
| akcie `mat_manual_prepare` / `mat_manual_open` / `mat_manual_confirm` s poľom `section` (echo) a model guardom | R15 | či server sekcie whitelistuje (ak áno, pridať `budget`) |
| klientska požiadavka na formulár (meno napr. `mdManualRequest(kind, id, trigger)`), jej kontextová kontrola sekcie, `mdManualContextChanged` volané zo `studioGoSection` | R20, R23 | meno funkcie; kontrola musí pustiť `mat` aj `budget` (vzor `hwManualRequest`) |
| `mdManualTip(rec)` + formát dátumu (`mdDateLabel`) — texty O5 | R19 | meno a vstup (kvôli parity testu R17) |
| `Materials.manual_product_record?`, `Materials.sanitize_product_url`, akcia `mat_product_open`, `mdOpenSheetForm/mdOpenEdgeForm(id, {focus: 'product_url'})`, `matOpenAnchor` | M1a (v maine) | bez zmeny |

## 6 · Požiadavky

### 6.1 [C12] Materiál bez formátu podľa skutočnej plochy

- **R1 Kto ide „podľa plochy".** `Budget.area_priced?(g, rec)` (čistá funkcia) = `g['fallback'] == true` ∧ `rec.is_a?(Hash) && !rec.empty?` (záznam v katalógu
  existuje) ∧ `g['uni'] != true` ∧ `!Materials.uni?(rec)` ∧ `!Materials.duplak?(rec)` ∧ **`area_priced_type?(rec)`**. Jediná pravda o platnom formáte je
  **`SheetEstimate.sheet_size_for`** (príznak `fallback` odhadu) — tá istá, ktorú číta odhad, plán aj Kontrola (S13). **Rozhodnutie orchestrátora 30.9. (Michal spí,
  Q2 otvorená):** kým Michal neodpovie, platí **bezpečnejšia vratná varianta** — „podľa plochy" ide len materiál, ktorého typ **nie je** v registri typov (dnes
  DTDL, MDF, HDF, PD, ZASTENA, KOMPAKT — bežné dosky; napr. SKLO áno) → ceny bežnej dosky bez formátu sa oproti dnešku **nemenia**. Podmienka typu je **jedna
  pomenovaná funkcia** `Budget.area_priced_type?(rec)` = **`Materials.type_registry_entry(rec['type']).nil?`** — existujúca normalizácia registra (strip, zlúčenie
  medzier, veľké písmená — S20), **nie** holé `TYPE_REGISTRY.key?` (audit FIX-3: `dtdl` alebo `" DTDL "` by inak išli podľa plochy). Test pripne rovnaký
  výsledok (`false` = doska ostáva platňou) pre `DTDL`, `dtdl`, `" DTDL "`, `"Dtdl\t"`, `MDF`, `hdf`, `PD`, `ZASTENA`, `KOMPAKT` a `true` pre `SKLO`, `sklo`,
  `Zrkadlo`, prázdny a chýbajúci typ; **`Zástena` s diakritikou** normalizácia nezlučuje (S20) → `true` — pripnúť ako vedomý stav (§9). Ostatné riadky idú
  **dnešnou vetvou bez zmeny** (zlatý test A = NP-4 golden, §7 bod 3). UNI bez formátu, chýbajúci záznam a **bežná doska bez formátu** ostávajú na dnešnom odhade
  (test: DTDL bez formátu = `PLATŇA`, `plates_of`, dnešná poznámka „… odhad podľa 2800×2070", NP-3/NP-4 vety ako dnes).
- **R1a Vetva „Q2 = všetky typy" (ak Michal odpovie inak).** Zmení sa **jedna funkcia**: `Budget.area_priced_type?(rec)` vráti `true` pre každý typ (register sa
  prestane pýtať). Nič iné v kóde. Testy a golden, ktoré sa vtedy **vedome** menia: R1 matica (DTDL/MDF/… bez formátu → area) · golden B (NOF 180,84 → **47,74 €**,
  medzisúčet Materiálu → **553,63 €**, SPOLU → **2070 €** — S22) · **NP-4 golden** `tests/fixtures/np4_golden/*.json` sa pregeneruje generátorom (NOF 1,05 m² ×
  31,20 = **32,76 €**, `mix_file` SPOLU **3394 → 3246 €** — S15) a hlavička `test_np4_golden.rb` to povie · `test_budget.rb:156` (BEZCENY = DTDL bez formátu → area
  riadok) · `test_np4_ceny.rb:347` (NOF pri zapnutom prepínači → area, bez `qty_source`) · `test_np3_sekcia.rb:213–227` (NOF bez vety plánu) · mutácia **M21**
  sa obráti · texty §9 (riziko „doska bez formátu zlacnie"), §10 (smoke bod 5) a F1 sa prepnú. Poistka pred PR: `grep` na `area_priced_type?` = jediné miesto s podmienkou typu.
- **R2 Množstvo.** `SheetEstimate.estimate` pridá do výstupu aditívny kľúč **`'m2_exact'`** = nezaokrúhlená plocha materiálu (tá istá suma ako `m2`, vrátane
  duplákov × násobok — S4). Area riadok: `mnozstvo = [num(g['m2_exact'] || g['m2']).round(2), 0.01].max` — **2 desatinné** (zhoda s XLSX `#,##0.00` a s ABS, S8),
  bez dvojitého zaokrúhlenia (S4: 1869 × 500 → 0,93, nie 0,94), minimum 0,01 m² (drobný dielec sa nesmie oceniť nulou). Fallback na `m2` len pre volajúcich
  s vlastným odhadom (testy).
- **R3 Cena za MJ.** `cena_mj = Materials.display_m2(price_per_m2).to_f` **[M1b R11a]** — tá istá funkcia, ktorou M1b ukazuje €/m² v bunke aj vo formulári „za m²"
  (S19); `nil` cena → `price_missing` ako dnes (O2 — nikdy nula). `spolu = (mnozstvo × cena_mj).round(2)` cez `base_row` — na obrazovke aj v XLSX platí
  „množstvo × €/MJ = medzisúčet" na cent (rovnaký princíp ako cena platne: jednotková cena sa zaokrúhli pred násobením).
- **R4 Tvar area riadku.** `mj: MJ_M2` ('M2'), `mnozstvo` (R2), `cena_mj` (R3), `qty_basis: 'area'`, `estimate_qty: plates_of(g)` (**vždy**, aj pri vypnutom prepínači —
  číta ho R5), `estimated: false` (množstvo nie je odhad), `m2` (ako dnes), `price_per_m2` (surová hodnota katalógu), `material_id`, `cp_nazov`, kľúč
  `material:<mid>` **bez zmeny** (nesie `cp_overrides` zákazky). **Poznámka:** `"formát platne nie je v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)"`
  (+ dnešná veta duplákov „vrátane N ks duplákov (X m²)", ak sú) — **bez** vety „X m² · formát …", **bez** vety plánu NP-3 a **bez** NP-4 (`price_basis`,
  `qty_source`, `qty_tip`, veta o cene) — plán sa ceny tohto riadku netýka (D6).
- **R5 Služby sa nemenia (D5).** `services_section`: porez = Σ `(r['qty_basis'] == 'area' ? r['estimate_qty'] : r['mnozstvo']).to_i`; montáž už číta `estimate_qty`.
  Porez aj montáž dávajú **presne dnešné čísla** (S5 simulácia bez tejto požiadavky: porez 7 → 6, montáž 40,6 → 34,8). Poznámka porezu pri zapnutom prepínači
  počíta area riadky medzi „z odhadu" (pravdivé — porez ich berie z odhadu platní). Ak Michal v Q1 rozhodne inak, mení sa **len** tento riadok.
- **R6 NP-4.** Area riadok nevstupuje do `price_basis` (R4), `plan_export_note` ho nevymenuje (nemá `qty_source`) — bez zmeny kódu, test. `BUD_PLAN_TIP` (`budget.js`)
  doplní vetu: „Materiál bez formátu platne sa počíta podľa skutočnej plochy dielcov — plán ho nemení."
- **R7 Karta Nárezového plánu.** `ProductionCore.layout_material_payload`: `budget_src = 'area'`, keď riadok Rozpočtu má `qty_basis == 'area'` (inak dnešné
  `qty_source`); `sheet_layout.js` `npBudgetNote`: `'area'` → „v rozpočte 0,90 m² podľa plochy" (číslo s čiarkou, 2 desatinné). Ostatné vety bez zmeny (S7).
- **R8 XLSX a Cenová ponuka — bez zmeny kódu, s testom.** XLSX riadok: MJ „M2", POČET = `mnozstvo`, CENA za 1 MJ = `cena_mj`, SPOLU = `spolu`, názov nesie poznámku R4.
  Ponuka: materiál `1 set`, mení sa len suma a zvyšok „Nábytkovej zostavy"; riadok môže **klesnúť pod prah 150 €** a z návrhu samostatných riadkov vypadnúť, ak ho
  zákazka nemá zaradený ručne (`cp_overrides`) — S9. Poznámka ani „€/m²" sa do ponuky nedostanú (firewall bez zmeny).

### 6.2 [STAV] Stav ručnej ceny materiálu a ABS v Rozpočte (server)

- **R9 `Budget.freshness_item` pre `sheet`/`edge`.** (a) `Materials.uni?(rec)` alebo `Materials.duplak?(rec)` → **`nil`** (položka vypadne zo scanu aj zo zoznamu —
  O2 „UNI a duplák nie"; S1); (b) neprázdna `demos_url` → **dnešná vetva bajtovo** (`unverified`/`stale`/`fresh`); (c) inak nová
  `manual_material_freshness(kind, id, label, rec, stale_days, ref)` nad **`Materials.manual_price_state(rec, stale_days:, now: ref)` [M1b R10]** — jediná autorita,
  Rozpočet stav **nepočíta** sám. Mapovanie: `fresh` → `fresh`, `stale` → `stale`, `never` → **`manual`** (slovník kovania: `manual` + `manual_check` = „treba
  ručne overiť"). Výstup: `{'kind', 'id', 'label', 'manual_check' => true, 'state', 'checked_at' (len pri platnom overení), 'age_days', 'price_check_method'
  ('manual' | nil), 'demos_url' => nil, 'product_link' => !!Materials.sanitize_product_url(rec['product_url']), 'price_missing' => cena nie je konečné číslo ≥ 0}`.
  **Odkaz sa nevyžaduje** (O9 — odchýlka od kovania). Kovanie (`manual_hardware_freshness`) bez zmeny.
- **R10 `stale_scan` (audit FIX-2).** `nil` položky sa zahodia (už `compact!`). Dnešný `counts['manual_hardware']` počíta **každú** položku s `manual_check` bez
  filtra druhu (S21) — po R9 by rátal aj dosky/ABS. Preto: **`manual_hardware`** = položky `kind == 'hardware'` s `manual_check` a stavom ≠ `fresh` (dnešné čísla pri
  zákazkách bez ručných materiálov sa nemenia); **`manual_materials`** = `kind` ∈ {`sheet`, `edge`} s tým istým predikátom; **`manual_pending`** = **jeden priechod**
  cez všetky nevyriešené ručné položky (`manual_check` ∧ ≠ `fresh`) — **nie** súčet dvoch počtov (poistka proti dvojnásobku; test tvrdí
  `manual_pending == manual_hardware + manual_materials` ako dôsledok, nie ako výpočet). Vzorec `attention` (staré ∪ nevyriešené ručné, bez dvojitého započítania)
  **bez zmeny** — materiály doň vstúpia samé cez `manual_check`. Triedenie a vynechanie `fresh` bez zmeny. Položka **bez ceny** je `manual` → „na kontrolu" (O2).
  Testy: len ručný materiál (hardware 0, materials 1, pending 1, attention 1) · len ručné kovanie (dnešné čísla KOV-B) · zmiešané materiál + ABS + kovanie
  (napr. 1 + 1 + 1 → hardware 1, materials 2, pending 3) · stará ručná cena materiálu sa v `attention` neráta dvakrát.
- **R11 Polia riadkov.** `materials_section(…, stale_days: 30, now: nil)` a `abs_section(…, stale_days: 30, now: nil)` (volá ich `compute` s `price_days`/`price_ref`
  — tá istá funkcia a čas ako scan, vzor CENY-KOV-B): pri **Demos** zázname `row['demos_link'] = true`; pri **ručnom** zázname (`Materials.manual_product_record?`)
  `row['product_link']` (bool) a `row['price_check']` = výstup R9 (aj `fresh` — riadok ukáže dátum); UNI, duplák a chýbajúci záznam nič. Zlatý test A pripúšťa
  v riadkoch **len** tieto tri kľúče (§7 bod 3).
- **R12 Prepočet cien (`PriceRefresh`) bez zmeny kódu.** Test: `targets_from_budget` vráti len Demos položky (ručný `product_url` sa nikdy nesťahuje ani pri Demos
  hoste); `manual_from_budget` vráti nevyriešené ručné materiály/ABS/kovanie, **bez UNI** a bez čerstvo overených.
- **R13 Kontrola rozpočtu (`Budget.check`) bez zmeny** — chýbajúca cena ostáva nálezom „Materiál: N riadkov bez ceny…" (O2); neoverená cena nálezom nie je.

### 6.3 [STAV] UI — Rozpočet → Materiál a ABS hrany (mockup D)

- **R14 Ikona odkazu pred názvom** (`budMatLinkHtml(r, kind)` — čistá funkcia; D4, O1): `r.demos_link` → sivá ikona, `data-action="mat-link" data-src="demos"`,
  `title` „Otvoriť produkt (Demos)"; `r.product_link === true` → sivá, `data-src="product"`, „Otvoriť produkt v prehliadači"; `r.product_link === false` →
  `is-missing` (jantár), `data-src="missing"`, „Chýba odkaz — doplniť odkaz na produkt"; inak (UNI, duplák, bez záznamu) nič. Kresba a farby = `.hw-product-link`
  (`#i-external-link`, vzor kovania); `data-kind` (`sheet`/`edge`), `data-id` escapované; `aria-label` „Otvoriť produkt · <názov>" / „Doplniť odkaz na produkt · <názov>".
  Riadok nepribudne (vertikálny priestor).
- **R15 Obsluha klikov `mat-*`** — delegovaný listener v `ui/js/proj_materials.js` (vlastník akcií materiálov; vzor `hw-product`/`hw-manual-check` v `hw_catalog.js`):
  `demos` → `sketchup.open_demos_url({kind, id})`; `product` → `sketchup.mat_product_open({kind, id})` (server číta čerstvý záznam, URL od klienta nechodí — M1a R7);
  `missing` → `mdProductFromBudget(kind, id)`: `MD_RO` → status „Katalóg je len na čítanie — úpravy sú vypnuté."; záznam v `MD_CATALOG` chýba → status „Položka sa
  v katalógu nenašla — obnov okno."; inak `matOpenAnchor(id)` → `studioGoSection('mat')` → `mdOpenSheetForm(id, {focus: 'product_url'})` / `mdOpenEdgeForm` (vzor
  `hwProductReady` → `studioGoSection('hw')`). **Nič nezapisuje.**
- **R16 Stĺpec „Overená" pri riadku s `price_check`** (`budMatCheckHtml(r)`; D3, O5): tlačidlo `.bver` `data-action="mat-manual-check" data-kind data-id`, text
  `fresh` → „ručne 18.9." (sivé; deň a mesiac z dátumovej časti `checked_at`, bez núl), `stale` → „ručne 45 dní" (jantár; plurál 1 deň / 2–4 dni / 5+ dní),
  `manual` → „neoverená" (jantár) — jantár = trieda `is-pending`; `title` = R17; `aria-label` „Overiť cenu · <názov> · <text stavu>". Riadky s Demos a UNI:
  `budFreshCell` ako dnes (Demos „—" / „38 dní" / „?"). Platí pre `budMaterialRow` aj ABS (`budSimpleRow`).
- **R17 Texty O5** — čistá `budMatTip(pc)` (dva riadky, `\n`): `fresh` „Cena ručne overená 18.9.2026 (pred 12 dňami)" (vek 0 „(dnes)", 1 „(pred 1 dňom)") ·
  `stale` „Ručne overená 16.8.2026 — pred 45 dňami, na kontrolu" · `manual` s cenou „Cena nebola nikdy ručne overená — na kontrolu" · `manual` s
  `price_missing` „Cena chýba a nebola nikdy overená — na kontrolu"; druhý riadok „Overiť cenu — otvorí obchod a formulár" / pri `product_link === false`
  „Overiť cenu — bez odkazu otvorí len formulár". **Parity test** s `mdManualTip` [M1b R19] nad tou istou maticou stavov (dve kópie textu, jeden test — vzor
  parity sanitizérov M1a).
- **R18 „Overiť cenu" z Rozpočtu** (riadok R16 aj zoznam R21) → tok M1b so **`section: 'budget'`** [M1b R15/R20]: klientska kontrola kontextu pustí `mat` aj `budget`
  (vzor `hwManualRequest`, S12), formulár **ostáva v Rozpočte** (sekcia sa neprepína), s odkazom otvorí obchod, **bez odkazu len formulár** (O9); odchod z Rozpočtu,
  zmena modelu alebo cudzí token ho zavrie/ignoruje (M1b R23 `mdManualContextChanged`); po `ok` server obnoví Štúdio (S17) → riadok zosivie, čip klesne. Read-only
  katalóg a Demos väzba (položka sa medzitým napojila) → status z odpovede prepare. Tlačidlá **nie sú** v `BUD_STD_OFF` — zapisujú katalóg, nie zákazku (S18).
- **R19 Area riadok v tabuľke** (`budMaterialRow`, `r.qty_basis === 'area'`): množstvo `budFmtNum(r.mnozstvo, 2)` („0,90"), MJ **zobrazená „m²"** (dáta ostávajú `M2` —
  D4), „€ / MJ" = `budSub(r.cena_mj)` **bez** zátvorky „(…/m²)", žiadna `.qtag`, poznámka zo servera. Ostatné riadky bez zmeny (S11 — dnes by 0,9 m² ukázal ako „1").
- **R20 Čip a hlavné tlačidlo** (D1): `budStaleLabel` sa rozhoduje podľa **`counts.manual_pending`** (> 0 → „N cien na kontrolu", N = `attention`; inak dnešné „N cien
  starších ako X dní"); `budPriceBtnHtml` a `budPrStart`: „len ručné" = `manual_pending > 0 && !budPrTargets(b).length` → „Skontrolovať ceny" otvorí zoznam so
  statusom „Vyber položku a klikni na Overiť cenu. Ručné odkazy sa automaticky nesťahujú." Demos beh bez zmeny. Fixtúry testov KOV-B dostanú `manual_pending`.
- **R21 Zoznam cien na kontrolu** (`budStaleActionHtml`, D2): `sheet`/`edge` s `manual_check` → ikona R14 (z `product_link`) + tlačidlo „Overiť cenu" s textom
  (`bact hw-manual-check`, `is-pending` keď ≠ `fresh`, `data-action="mat-manual-check"`); `sheet`/`edge` s `demos_url` → ikona R14 (Demos) + dnešné obnovenie;
  veta „bez Demos väzby — over v katalógu ručne" **zaniká**. Texty veku dnešné („ručne overené pred 45 dňami" / „vyžaduje ručné overenie").
- **R22 Čip v Cenovej ponuke** (`budOfferChipHtml`): pri `manual_pending > 0` tooltip „Ceny na kontrolu skontroluješ v Rozpočte — Demos ceny tlačidlom „Prepočítať
  ceny", ručné cez „Overiť cenu"."; inak dnešný text.
- **R23 CSS** (`ui/studio.html`, tokeny `--nx-*`, obe témy): `.bver` (malé tlačidlo s ikonou `#i-clipboard-check` a textom v bunke, `is-pending` =
  `--nx-warn-bg-soft` / `--nx-warnchip-*`), rozostup ikony pred názvom; bump `?v=`. Vzor: mockup `.bver`, UI_DIZAJN §E-b.

### 6.4 Dokumentácia

- **R24** STANDARD **§11.2** (Rozpočet: materiál bez formátu **mimo registra typov** = skutočná plocha × €/m², MJ M2; bežná doska bez formátu = odhad platní ako
  doteraz), **§11.3** (vek ručných cien materiálov/ABS v Rozpočte, počty `manual_*`, `BUDGET_STD` sa nemení — prečo, a priznané riziko staršieho pluginu na druhom
  PC), **§11.4** (materiál podľa plochy nie je v cene podľa plánu). `docs/architecture/outputs.md` — prepísať **na mieste** odseky `budget.rb`
  (nový odsek C12; odsek „Ručná čerstvosť kovania" prepísať na spoločnú čerstvosť kovania **a** materiálov/ABS), `sheet_estimate.rb` (doplniť kontrakt `estimate`
  vrátane `m2_exact` — dnes „nezdokumentovaný"), `price_refresh.rb`, `production_core.rb` (`budget_src 'area'`). `ui-lifecycle.md` — sekcia Rozpočet (ikony,
  „Overená", čip, zoznam, akcie `mat-*` z Rozpočtu), odsek `materials_dialog.rb` (formulár „Overiť cenu" aj zo sekcie `budget`), karta Nárezového plánu.
  `docs/UI_DIZAJN.md` §E-b (`.bver`, ikona pred názvom).

## 7 · Testy a DoD

1. **`tests/pure/test_ceny_m2_area.rb` [C12]:** matica R1 (sklo bez formátu → area; **DTDL bez formátu → dnešný odhad** — `PLATŇA`, `plates_of`, `cena_mj =
   round2(€/m² × 5,796)`, dnešná poznámka, pri zapnutom prepínači dnešné `qty_source 'estimate'` a veta „formát chýba — cena z odhadu"; UNI bez formátu, duplákový
   záznam bez formátu, chýbajúci záznam, formát 300 × 200 = platňa, platný formát); **normalizácia typu** R1 (`DTDL`/`dtdl`/`" DTDL "`/`"Dtdl\t"` → rovnaký výsledok
   „platňa", `SKLO`/`sklo`/prázdny → area, `Zástena` pripnutá); R2 (0,9 · sklo s duplákom — plocha × násobok · hranica 1869 × 500 → 0,93 · drobný dielec → 0,01); R3 (hranice pol centa 1,005 · 2,675 ·
   31,005 · 31,0386… — `cena_mj == Materials.display_m2`, `spolu == round2(qty × cena_mj)`); R4 (tvar riadku, poznámka presne, žiadne NP-3/NP-4 polia);
   **R5 služby pred/po rovnaké** (porez, montáž, poznámky; aj pri zapnutom prepínači); R6 (`plan_export_note` bez area riadku); R7 (`budget_src 'area'`,
   `budget_qty` = m²); R8 (XLSX riadok MJ/POČET/CENA/SPOLU; CP: suma, zvyšok zostavy, **preklopenie cez prah** podľa sondy S9 — 240,53 → 37,35 €, samostatný
   riadok zanikne, s `cp_overrides 'samostatne'` ostane); chýbajúca cena → `price_missing`, Kontrola „Materiál: 1 riadok bez ceny".
2. **`tests/pure/test_ceny_m2_stale.rb` [STAV]:** R9 nad reálnym `manual_price_state` [M1b] — deň 29/30, prah z nastavení (45), nikdy, poškodený a budúci dátum, bez
   ceny, 0 € = platná, **bez odkazu = fresh** (O9), UNI/duplák → `nil`, Demos bajtovo ako dnes; R10 počty — **len materiál**, **len kovanie** (dnešné čísla
   KOV-B), **zmiešané materiál + ABS + kovanie** (`manual_hardware` len kovanie, `manual_pending` jedným priechodom = súčet ako dôsledok), `attention` bez
   dvojitého započítania pri starej ručnej cene; R11 `row.price_check` == položka scanu (tá istá funkcia a `ref`), `demos_link`/`product_link`; R12 targets
   a `manual_from_budget`; **integrácia:** sandbox katalóg → `Materials.confirm_manual_price` [M1b R11] → `Budget.compute` ukáže `fresh` a čip zmizne; zmena ceny
   bunkou [M1b R13] → späť `manual` (vzor `test_ceny_kov_budget_manual.rb` integrácie).
3. **Zlaté testy Rozpočtu** (audit BLOCKER — NP-4 golden sa číselne **nemení**):
   - **A — NP-4 golden = zákazky bez materiálu „podľa plochy".** Fixtúry `tests/fixtures/np4_golden/*.json` sa **nepregenerujú a nemenia** — ich `NOF` je
     `type: 'DTDL'` (`test_np4_golden.rb:44`), teda register → ostáva platňou (R1). `test_np4_golden.rb` dostane len rozšírenú normalizáciu pred porovnaním:
     z riadkov sa odstránia aditívne kľúče `product_link`, `demos_link`, `price_check` a blok `stale` sa vyberie a overí **zvlášť** proti vymenovaným očakávaniam
     (UNI `UNI` a duplákový záznam `W36` vypadnú; `H18`, `NOF`, `PD`, `W18` = `manual` + `manual_check`; `counts.manual_hardware 0`, `manual_materials 4`,
     `manual_pending 4`, `attention 4`). **Všetko ostatné** — sumy, riadky vrátane `NOF` (1 × 180,84 €), poznámky, Kontrola, náhľad ponuky, XLSX rozpočtu aj harok
     ponuky — sa musí **bajtovo zhodovať** s dnešnými fixtúrami pre všetky tri prípady (`mix_file` SPOLU **3394 €** ostáva). Hlavička testu doplní vetu, prečo
     sa `stale` porovnáva zvlášť (CENY-M2). Dôkaz, že **zákazky bez skla majú rovnaké čísla** a bežná doska bez formátu sa nezmenila.
   - **B — samostatná fixtúra so sklom** (`tests/pure/test_ceny_m2_golden.rb` + `tests/fixtures/ceny_m2_golden/pre_glass.json`): generátor `generate_pre.rb` spustí
     implementátor **raz nad čerstvým mainom po M1b PRED prvou zmenou kódu** a výstup commitne samostatným commitom („golden pred M2"). Obsah = fixtúra sondy
     `sonda_m2.rb`: **sklo `SK4` (typ `SKLO`, mimo registra) 0,9 m² à 41,50 €**, sklo bez ceny `NOP`, **DTD bez formátu `NOF` s duplákom** (register), UNI, `H18`
     (Demos), `H25` (ručná s formátom), ABS Demos aj ručná. Diff čerstvého výsledku proti odtlačku je **obmedzený na vymenované cesty** (riadky `SK4` a `NOP`,
     medzisúčet Materiálu, `totals`, riadok zaokrúhlenia, `cp_preview` sumy a zaradenie, bunky XLSX týchto riadkov/medzisúčtu/SPOLU, `stale`, aditívne kľúče)
     a čísla sú **presné** (S22): sklo 0,90 × 41,50 = **37,35 €** (dnes 240,53), **`NOF` bez zmeny 1 × 180,84 €**, medzisúčet Materiálu **889,91 → 686,73 €**, raw
     **2406,14 → 2202,96**, SPOLU **2407 → 2203 €** (zaokrúhlenie 0,04), porez **7** a montáž **40,6** bez zmeny; v ponuke sklo vypadne zo samostatných riadkov
     (S9). Čísla sú zo sondy nad `bb2c3411` — generátor ich potvrdí nad mainom po M1b.
   - **Vetva R1a** (len ak Michal odpovie „všetky typy"): golden B dostane očakávania S22/E4 a NP-4 fixtúry sa pregenerujú (R1a).
4. **`tests/js/test_ceny_m2_budget.js` [C12+STAV]:** R14 (tri stavy ikony + UNI bez ikony, escapovanie, `data-*`), R15 (stub `sketchup`, `studioGoSection`,
   `matOpenAnchor`, `mdOpenSheetForm`: demos/product/missing, read-only, chýbajúci záznam; ABS → `mdOpenEdgeForm`), R16/R17 (presné reťazce O5, vek 0/1/12/45,
   plurál, `is-pending`, aria-label), **parity R17 vs `mdManualTip`**, R18 (klik → požiadavka so `section: 'budget'`, bez odkazu bez `mat_manual_open`, odchod
   z Rozpočtu zavrie, cudzí token), R19 („0,90", „m²", bez „(…/m²)"), R20 (čip „N cien na kontrolu" pri samých ručných materiáloch, „Skontrolovať ceny", `budPrStart`
   otvorí zoznam), R21 (zoznam: odkaz + „Overiť cenu", Demos: odkaz + obnovenie, veta „over v katalógu ručne" zmizla), R22, R6 (`BUD_PLAN_TIP`), R7 (karta „v rozpočte
   0,90 m² podľa plochy").
5. **Existujúce testy na vedomú úpravu:** `test_np4_golden.rb` — **len normalizácia** (bod 3 A, fixtúry bez zmeny) · `tests/js/test_budget_ui.js:369–371` a
   `tests/js/test_ceny_kov_budget_manual.js:38–53` (ručný materiál má „Overiť cenu", fixtúry doplnia `manual_pending`) · `tests/js/test_np3_sekcia.js` (nový prípad
   `area`). **Bez zmeny ostávajú** (DTDL je v registri — R1): `test_budget.rb:156` (BEZCENY = DTDL bez formátu, fallback + `estimated`), `test_np4_ceny.rb:283/347`
   (NOF „formát chýba — cena z odhadu"), `test_np3_sekcia.rb:213–227` (NOF s vetou plánu) — slúžia ako regresia „bežná doska bez formátu sa nezmenila".
   `test_budget.rb:443–446` (ABS a BEZCENY `manual`) a `test_ceny_kov_budget_manual.rb:129` (hardvérový záznam bez `price_per_m2` → `never` → `manual`; počty
   `manual_hardware` len z kovania) ostávajú zelené — overiť.
6. **Mutácie (každá musí zhodiť aspoň jeden test; min. 16):** M1 area aj pre UNI · M2 area sa pri skle nepoužije (fiktívna platňa ostane) · M3 množstvo z `m2` 3-desatinného
   (dvojité zaokrúhlenie) · M4 množstvo bez zaokrúhlenia na 2 des. · M5 `cena_mj` bez zaokrúhlenia (surová €/m²) · M6 porez z `mnozstvo.to_i` area riadku · M7 montáž
   bez area riadku · M8 area riadok dostane NP-4 vetu „cena z odhadu" · M9 `freshness_item` ignoruje ručné overenie (vždy `manual`) · M10 UNI/duplák ostanú v scane ·
   M11 `manual_pending` bez materiálov (čip ich nepočíta) · M12 „Overiť cenu" vyžaduje odkaz (O9) · M13 ikona Demos riadku volá `mat_product_open` · M14 chýbajúci
   odkaz neprepne do Materiálov / bez fokusu · M15 formulár z Rozpočtu prepne sekciu na Materiály · M16 karta plánu ignoruje `area` · M17 `targets_from_budget` vezme
   ručný materiál · M18 zmena textu O5 v jednej kópii (parity) · **M19** `area_priced_type?` cez holé `TYPE_REGISTRY.key?` (`dtdl` bez formátu pôjde podľa plochy) ·
   **M20** `manual_hardware` bez filtra druhu / `manual_pending` ako súčet (dvojnásobok pri zmiešanej zákazke) · **M21** area aj pre DTDL bez formátu (vetva R1a
   bez rozhodnutia — zhodí NP-4 golden A aj test R1).
7. **Celá headless sada** (`ruby tests/run_all.rb`) + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + encoding guard.

## 8 · In-SU test — **nie je brána mergu**

Spúšťače z CLAUDE.md: buildery, observery, undo a operácie, geometria, akcie panela zapisujúce do modelu. M2 **nezapisuje nič** — Rozpočet je čistý výpočet nad
katalógom; jediné zápisy (potvrdenie ceny) robia akcie M1b do globálneho katalógu (JsonFileStore, bez `start_operation`, bez Späť), ktoré M1b pokrylo headless.
In-SU `mr3b_budget` a `st1c_budget` čítajú Rozpočet nad **živým** katalógom testovacieho SketchUpu — zmena C12 ich môže posunúť len pri materiáli bez formátu
mimo registra typov (sklo) a nové počty `manual_*` len pri ručných materiáloch (porovnávajú relatívne stavy, nie absolútne sumy — overiť pri prvom behu). **Odporúčanie (nie brána):** ak je SketchUp voľný, pred PR jeden beh
`scripts\run_su_tests.ps1 -CloseWhenDone` ako dymová kontrola; PR uvedie hlavu.

## 9 · Riziká

- **Cenová zmena zákaziek (zámer C12, obmedzené R1).** Zmení sa **len zákazka**, ktorá používa materiál **bez platného formátu, ktorého typ nie je v registri typov**
  (sklo, zrkadlo a pod.; nie UNI, nie duplák) **a má cenu**: medzisúčet Materiálu, SPOLU, zaokrúhlenie, XLSX rozpočtu, suma ponuky a zvyšok „Nábytkovej zostavy".
  Príklad: sklo 0,9 m² à 41,50 € — **240,53 → 37,35 €**. **Bežná doska bez formátu** (DTDL/MDF/HDF/PD/ZASTENA/KOMPAKT) a všetky ostatné zákazky: čísla
  **identické** (zlatý test A = NP-4 golden bez zmeny; golden B pripína `NOF`). Materiál bez ceny: suma sa nemení (ďalej „chýba cena").
- **Vetva Q2 = „všetky typy" (R1a):** keby Michal rozhodol, bežná doska bez formátu by sa počítala bez odpadu (DTD 1,05 m²: 180,84 → 32,76 €) — podhodnotenie
  ponuky; preto je do odpovede predvolená obmedzená varianta. Zmierňuje (ak R1a): poznámka „… (bez odpadu)", nález **F1**.
- **Typ s diakritikou (S20):** `identity_norm` nezlučuje diakritiku — záznam s typom „Zástena" (nie `ZASTENA`) bez formátu by išiel podľa plochy. Prakticky zriedkavé
  (zástena má formát v identite, UI ponúka kľúče registra), test to pripne ako vedomý stav; zjednotenie typov s diakritikou = nález **F6**.
- **Ponuka:** samostatný riadok skla, ktorý dnes existoval len vďaka fiktívnej platni, môže po M2 spadnúť do zostavy (S9) — ručné zaradenie (`cp_overrides`) platí ďalej.
- **Dve PC, dve verzie — vedome prijaté prevádzkové riziko (audit NOTE-4):** starší plugin (≤ v0.16.2) na druhom PC tú istú zákazku ocení fiktívnou platňou
  a **vyexportuje XLSX rozpočtu aj ponuky so starou cenou skla** (240,53 € namiesto 37,35 €); `BUDGET_STD` sa nemení (§5), takže **žiadna brána to nezachytí**.
  Opatrenie: povinná veta v STAV, PR, reporte aj smoke — „Aktualizuj plugin na oboch PC pred porovnávaním alebo posielaním ponúk — starší plugin počíta sklo bez
  formátu po starom." Alternatíva (odmietnutá): bump `BUDGET_STD` bez nového poľa — porušil by disciplínu §11.3 a zablokoval by staršiemu pluginu aj zákazky bez skla.
- **Čip naskočí pri každom ručnom materiáli zákazky** (neoverený = na kontrolu, O2). V Michalovom katalógu je bez Demosu 5 záznamov (FAKTY §3) — malý šum; katalóg
  bez Demosu (seed) by mal na kontrolu všetko — zámer O2.
- **API M1b (S14):** mená a tvar sa môžu líšiť od package M1 — §5.1 overiť pred štartom; rozdiel v kontrakte = nový audit.
- **Definícia platného formátu (S13):** M2 berie `fallback` odhadu (kladná dvojica), M1b pri „za platňu" vyžaduje rozsah 500–5000. Ručne upravený JSON s formátom
  300 × 200: Rozpočet ho počíta po platniach, formulár M1b „za platňu" odmietne — okrajový prípad (UI taký formát zapísať nedovolí), zapísať do `outputs.md`.
- **Životný cyklus formulára z Rozpočtu:** odchod zo sekcie, prepnutie zákazky, neskorá odpoveď — pokrýva M1b R23 + test R18; formulár Rozpočtu sa nesmie
  prepnúť do Materiálov (M15).

## 10 · Smoke checklist pre Michala (po slovensky, funkčne) — v0.16.3

Najprv aktualizuj plugin na **oboch** PC — **aktualizuj ho pred porovnávaním alebo posielaním ponúk: starší plugin počíta sklo bez formátu po starom**
(ako celú platňu) a jeho XLSX by niesol inú sumu.
1. Otvor zákazku, kde je **sklo bez formátu** (napr. sklenené police): Rozpočet → Materiál — riadok skla má množstvo v **m²** (napr. 0,90 m²), cenu za m² a medzisúčet
   = m² × cena; poznámka „formát platne nie je v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)". Predtým tu bola 1 celá platňa 2800 × 2070.
2. Porez a montáž sú **rovnaké** ako pred aktualizáciou.
3. XLSX rozpočtu: riadok skla MJ „M2", počet 0,90, cena za m², súčet sedí. Cenová ponuka: zmení sa len suma; ak bolo sklo samostatným riadkom len kvôli platni a je
   lacnejšie ako 150 €, presunie sa do zostavy.
4. Zákazka **bez skla** — súčet rovnaký ako predtým. **Doska (DTD/MDF) bez formátu** v katalógu sa počíta **ako doteraz** (celé platne 2800 × 2070) — mení sa
   len sklo a iné materiály, ktoré nie sú bežná doska.
5. Doska/páska **bez Demosu** v zákazke: stĺpec „Overená" ukazuje jantárové „neoverená"; čip hore „N cien na kontrolu" ju počíta. UNI v čipe nie je.
6. Klik na „neoverená" → otvorí sa formulár „Overiť cenu" (ten istý ako v Štúdiu), Rozpočet ostane otvorený; s odkazom sa otvorí aj obchod, **sklo bez odkazu len
   formulár**. Potvrď → riadok zosivie na „ručne 30.9.", čip klesne.
7. Rozbaľ čip: položka bez Demosu má ikonu odkazu a „Overiť cenu", Demos položka ikonu a obnovenie. Keď ostanú na kontrolu len ručné ceny, tlačidlo sa volá
   **„Skontrolovať ceny"** a otvorí tento zoznam.
8. Ikona pred názvom materiálu/pásky: pri Demos otvorí Demos, pri ručnej s odkazom obchod; **jantárová** (odkaz chýba) prepne do Štúdia → Materiály a otvorí úpravu
   s kurzorom v poli „Odkaz na produkt".
9. Zapni „ceny podľa plánu": sklo ostane podľa plochy (bez značky „z odhadu"); v Nárezovom pláne karta skla píše „v rozpočte 0,90 m² podľa plochy".
10. Kovanie v Rozpočte vyzerá ako predtým.

## 11 · Checklist uzáveru

**Dávka CENY-M2 (PR):** bump VERSION **0.16.3** (`noxun_engine.rb` + `noxun_engine/main.rb`) + všetky `?v=` · headless + každá JS sada zelené · STANDARD §11.2–§11.4 ·
`outputs.md`, `ui-lifecycle.md`, `UI_DIZAJN.md` odseky na mieste · **prepis STAV** (v0.16.3; „sklo a iný materiál bez formátu mimo bežných dosiek sa v Rozpočte
počíta podľa m²; bežná doska bez formátu ako doteraz" + **povinná veta** „Aktualizuj plugin na oboch PC pred porovnávaním alebo posielaním ponúk — starší plugin
počíta sklo bez formátu po starom.") · KRONIKA odsek navrch · PLAN riadok **CENY-M2** ✅ + PR · DOGFOODING „V1 DOTIAHNUTIE" — položka „manuálne overenie ceny materiálov/ABS … jeden
odkaz" je **vyriešená** → plný text + PR do `SYSTEM/archiv/DOGFOODING_vyriesene.md` (sekcia plných textov + riadok navrch indexu; bez D-čísla, názov „V1-03 zvyšok —
ceny materiálov/ABS (CENY-M1a/M1b/M2)") a zo skupiny v `DOGFOODING.md` zmizne · package + surový audit M2 do `SYSTEM/zdroje/bloky/CENY/` · PR popis: čo sa mení pre
používateľa, sekcia „Predrecenzia", zlaté testy (**NP-4 golden fixtúry bez zmeny**, len normalizácia; golden B sklo s presnými číslami), stav Q1/Q2 (ktorá
vetva R1/R1a je v kóde), in-SU „nie je brána (§8)", povinná veta o oboch PC.

**Uzáver bloku CENY (vetva `release/ceny`, hneď po mergi M2 — variant B):** minor **v0.17.0** + `?v=` · blok CENY z `SYSTEM/PLAN.md` plným textom (C1–C13, dávky
M1a/M1b/M2 s PR a verziami, **smoke checklist celého bloku** = §10 M1 + §10 M2) do `SYSTEM/archiv/ROADMAP_hotove_etapy.md`; v PLAN ostane „Poradie pred uzáverom V1"
s ďalším krokom **R-13** · celý priečinok `SYSTEM/zdroje/bloky/CENY/` → `SYSTEM/archiv/bloky/CENY/` + kontrola odkazov (PLAN, DOGFOODING, STAV, KRONIKA, README,
mockup, packages) · **V1_VIZIA** bod 6: zvyšok V1-03 hotový (materiály/ABS) · README (mapa `SYSTEM/`) · STAV (v0.17.0, smoke čaká) · KRONIKA · skupina „smoke po
uzávere" v DOGFOODING (dočasná). **Poistka:** nový blok (R-13) až po Michalovom smoke PASS alebo „ideme ďalej".

## 12 · Rozhodnutia autora package (bezpečnejšia vratná voľba) — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | „Bez formátu" = `fallback` odhadu (`SheetEstimate.sheet_size_for`) ∧ záznam existuje ∧ nie UNI ∧ nie duplák; **do odpovede na Q2 len typy mimo registra** — `Materials.type_registry_entry(type).nil?` (bežná doska ostáva na odhade; vetva R1a pripravená) | jedna pravda o formáte (S13) aj o registri (S20); UNI ostáva odhad (zadanie) | **áno** (Q2 pre Michala) |
| D2 | Množstvo = `round2(m2_exact)`, min. 0,01; `SheetEstimate` dostane aditívny `m2_exact` | 2 desatinné = XLSX a ABS (S8); bez dvojitého zaokrúhlenia (S4); nulu nepripustiť | áno |
| D3 | `cena_mj` area riadku = `Materials.display_m2` (centy half-up), súčet = množstvo × €/MJ | „množstvo × €/MJ = medzisúčet" na obrazovke aj v XLSX; tá istá €/m² ako v Štúdiu | nie |
| D4 | MJ v dátach `M2` (enum, XLSX, ponuka), v tabuľke Rozpočtu zobrazená „m²" | O10 „MJ m²" v UI; Luciine hárky a montáž používajú `M2` | krátko |
| D5 | Porez a montáž sa **nemenia** (area riadok nesie `estimate_qty`) | C12 hovorí len o riadku materiálu; zmena služieb je ďalšia cenová zmena bez rozhodnutia | **áno** (Q1 pre Michala) |
| D6 | Area riadok bez vety plánu NP-3 a bez NP-4 (`price_basis`) | cena nezávisí od platní; veta „orientačne 1 platňa" pri riadku v m² mätie; karta plánu ostáva | áno |
| D7 | Poznámka „formát platne nie je v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)" | mockup D; „(bez odpadu)" pri skle pravdivé a pri vetve R1a varovanie | krátko |
| D8 | UNI a duplák **vypadnú** zo scanu cien (aj zo zoznamu, kde dnes stoja ako „ručná položka") | O2 „UNI a duplák nie"; dnešný stav je mätúci (S1) | nie |
| D9 | Slovník stavov: R10 `never` → `manual` + `manual_check` (ako kovanie); `manual_hardware` **len kovanie**, nové `counts.manual_materials` a `counts.manual_pending` (jeden priechod); klient číta `manual_pending` | jeden slovník pre kovanie aj materiály; bez dvojnásobku (S21, audit FIX-2); `manual_hardware` ostáva s dnešným významom | nie |
| D10 | Bez bumpu `BUDGET_STD` aj schémy katalógu, bez R-14 brány; starší plugin na druhom PC = **vedome prijaté prevádzkové riziko** + povinná veta (§9) | nový kľúč do zákazky nepribúda (S16), STANDARD §11.3; bump bez poľa by zablokoval aj zákazky bez skla | **áno** |
| D11 | Ikona odkazu otvára cez existujúce akcie (`open_demos_url`, `mat_product_open`); chýbajúci odkaz → Materiály + formulár s fokusom | žiadna nová serverová akcia; vzor kovania | nie |
| D12 | „Overiť cenu" z Rozpočtu = tok M1b so `section: 'budget'`, formulár ostáva v Rozpočte | vzor CENY-KOV-B (S12) | nie |
| D13 | Texty O5 v `budget.js` ako kópia + parity test s `mdManualTip` (nie zdieľaný súbor) | `budget.js` a `proj_materials.js` bežia v Node testoch oddelene; nový zdieľaný súbor = zbytočná réžia | nie |
| D14 | Tlačidlá `mat-*` nie sú v `BUD_STD_OFF` | zapisujú katalóg, nie zákazku (ako „Prepočítať ceny", S18) | nie |
| D15 | Bez rezu (~380 riadkov) | pod hranicou 700; spoločné riadky a spoločné zlaté testy | **áno** (orchestrátor) |
| D16 | NP-4 golden fixtúry sa **nepregenerujú**; test len odstráni aditívne kľúče riadkov a `stale` overí zvlášť | audit BLOCKER — dôkaz „bežná doska a zákazky bez skla bez zmeny čísel" musí stáť na nezmenených fixtúrach | nie |

## 13 · Otázky pre Michala (produktové — mockup ani C1–C13 ich nepokrývajú)

*(Stav 30.9. ráno: Michal spí; M2 do jeho odpovede drží Q1 „nemeniť" a Q2 alternatívu — obe nemenia dnešné čísla mimo skla. Odpoveď pred štartom implementácie.)*

- **Q1 · Porez a montáž pri skle na mieru.** Dnes Rozpočet pri skle bez formátu účtuje aj **porez 1 platne** a **montáž 5,8 m²** (fiktívna platňa). C12 rieši len
  cenu materiálu. **Návrh (predvolené v M2): nemeniť** — porez aj montáž ostanú, ako sú. Alternatíva: sklo bez porezu (reže ho sklenár), montáž ostáva. Ak Michal
  zvolí alternatívu, mení sa jeden riadok (R5) a golden B.
- **Q2 · Doska bez formátu — ROZHODNUTÉ 30.9.2026 (C14): „áno, všetky typy" → vetva R1a implementovaná v PR #428.** C12 doslovne platí pre **každý** materiál bez formátu — aj DTD/MDF, ktorej v katalógu formát len chýba; tá sa potom počíta podľa
  plochy dielcov **bez odpadu** (napr. 1,05 m² DTD: 180,84 € → 32,76 €). **Predvolené v M2 do Michalovej odpovede (orchestrátor 30.9.): alternatíva nižšie** —
  nemení dnešné ceny bežnej dosky (podhodnotenie bez odpadu je horšie ako dnešný opatrný odhad). Pôvodný návrh autora: „áno, všetky" (C12 doslovne).
  Alternatíva: podľa plochy len materiál, ktorý nie je bežná doska (typy mimo DTDL/MDF/HDF/PD/KOMPAKT/ZÁSTENA — napr. sklo); bežná doska bez formátu ostane na
  odhade 2800 × 2070. *Ak Michal odpovie „všetky typy": vetva **R1a** — mení sa jedna funkcia (`area_priced_type?`), golden B, NP-4 golden fixtúry a tri
  vymenované testy; zoznam je v R1a.*

## 14 · Nálezy mimo scope (návrhy D-čísel)

- **F1** — Kontrola alebo Štúdio → Materiály by mohli upozorniť na **bežnú dosku bez formátu** (DTDL/MDF/HDF/PD) — dnes (a po M2 s obmedzeným R1) ju Rozpočet
  ticho oceňuje fiktívnou platňou 2800 × 2070; vo vetve R1a by sa počítala bez odpadu. Nález dnes neexistuje.
- **F2** — Formát dátumu ručného overenia v Rozpočte je pri kovaní „ručne 10.09.2026", pri materiáloch (O5) „ručne 18.9." — zjednotiť (kovanie mimo bloku, C6).
- **F3** — Kusovník (súčty, odhad platní) a karta Nárezového plánu ďalej ukazujú pri skle bez formátu **orientačný počet platní** 2800 × 2070 — pre sklo nemá zmysel.
- **F4** — Sklenári často účtujú **minimálnu plochu kusa** (napr. 0,25 m²) a prípočet za opracovanie hrán — Rozpočet ich nepozná (C12 = skutočná plocha).
- **F5** — `manual_from_budget` (`price_refresh.rb`) nemá produkčného volajúceho (len testy) — preveriť, či je potrebné.
- **F6** — `Materials.identity_norm` nezlučuje diakritiku: typ „Zástena"/„ZÁSTENA" nie je v registri (`ZASTENA`), hoci je to tá istá doska (S20) — zjednotiť
  normalizáciu typu (dotýka sa aj identity variantov, `format_in_identity?`, návrhov formátu).
