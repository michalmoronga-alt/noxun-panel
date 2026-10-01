# PACKAGE H3 · Zavádzajúce údaje v okne (blok 9 HARDENING PO V1)

> **Autorita:** Michalovo triedenie krížového auditu V1 (1.10.2026) — `SYSTEM/zdroje/bloky/HARDENING/ROZHODNUTIA_MICHALA_2026-10-01.md` (PR #432, v čase
> písania ešte na vetve `docs/v1-audit-start`), položky **A-01 · A-02 · A-03 · A-04 · A-06 · A-07** (A-05 je v H7). Návrh auditu = schválený smer; presné
> texty určuje tento package. Plné znenia a dôkazy: `CROSS_AUDIT_A5_CLAUDE_STOLAR_UX.md` (CU-01, CU-05, CU-08, CU-09, CU-15), `CROSS_AUDIT_A2_GROK.md` (GR-19),
> `TRIEDENIE_krizovy_audit_v1.html`; fotky `_dev/v1audit_shots/studio_01_bom*`, `studio_02_ctrl*`, `studio_03_buy*`, `studio_05_offer*`, `studio_13_bset*`.
> **Záväzok bloku:** výrobné a cenové čísla sa **nemenia** — mení sa len to, čo okno Štúdia ukazuje. XLSX ponuky, CSV kovania, VEPO a výpočty ostávajú
> bajtovo rovnaké (dôkaz = existujúce zlaté testy bez pregenerovania, §7).
> **Odporúčaný rez:** **H3a** (A-01, A-02, A-03, A-04, A-07 — zobrazenie) → z čerstvého `main` **H3b** (A-06 — log po novom súbore). Dôvod v §2.
> **Stav kódu:** sonda nad `main` **`4da1c3b5`** (v0.17.0).

---

## 0 · Sonda na kóde (1.10.2026, bez zápisu do modelu aj repa)

Skripty a surové výstupy: scratchpad `HARDENING/sonda_h3.rb` (+`sonda_h3_out.txt`) a `sonda_h3.js` (+`sonda_h3_js_out.txt`). Ruby cez `tests/helper.rb`
(APPDATA = sandbox), JS nad reálnymi `studio.js`/`budget.js`. **In-SU sonda nebola možná** — MCP most SkAgent (port 7891) v tejto session hlásil
ECONNREFUSED; tvrdenia o správaní SketchUpu sú označené NEOVERENÉ.

| # | Tvrdenie | Kde | Výsledok | Verdikt |
|---|---|---|---|---|
| S1 | **A-01:** súčet „odhad X – Y platní" **sčíta server**, nie JS: `totals_payload` sčíta `count_min/max` cez **všetky** položky odhadu (všetky materiály, aj nákup pre dupláky) | `ui/studio_dialog.rb:1750-1759`; JS len vypíše: `studio.js:1590-1599` (pohľad Dielce), `studio.js:1679-1687` (pohľad Platne) | grep: `plates_min/max` čítajú len tieto dve miesta — **nejdú do CSV, XLSX, VEPO ani Rozpočtu** | PRAVDA s opravou zadania („JS sčíta") — oprava je len zobrazenie |
| S3 | Test pripína kľúče `totals` a zakazuje JS sčítavať (`reduce(`, `+= x.m2`, `+= x.quantity`) | `tests/pure/test_st1a_studio.rb:796-805` | — | PRAVDA — pasca pre A-03/A-04 (§6) |
| S4 | Preklik do sekcie existuje: `data-nav` na ľubovoľnom prvku → `onNav` → `studioGoSection`; položka `cut` nemá `disabled` | `studio.js:2002-2003`, `1923-1932`, `110-111` | — | PRAVDA — žiadny nový mechanizmus |
| S5 | **A-02:** stĺpec „Cena" v ponuke = **suma riadku** (`item_row` berie `amount` = `spolu` rozpočtu); poradie Položka · Cena · Množstvo · MJ · V ponuke | `budget.js:1435-1448`; `core/cp_export.rb:246-250`, `194-217` | JS sonda J5: „Atira 171,56 € 4 set" | PRAVDA |
| S6 | Nulové riadky ponuky sú dvoch druhov: **fixné** Zameranie/Vizualizácie (`kind: 'fixed'`, vždy 0,0) a **informačné** „dodáva zákazník" (`kind: 'info'`, 0,0) | `cp_export.rb:254-270`, `226-240` | — | PRAVDA — **pasca:** „v cene" pri spotrebiči, ktorý kupuje zákazník, by klamalo (R-A02-3) |
| S7 | XLSX ponuky skladá Ruby (`CpExport.price_sheet`, hlavičky `PRICE_HEADERS` POLOŽKA · CENA (€) · MNOŽSTVO · MJ) — `budget.js` ho neovplyvní | `cp_export.rb:551`, `576-593` | — | PRAVDA — zmena okna XLSX nemení |
| S8 | Rámik „po V1 — vedomý placeholder" + CSS `.bwire`; pripínajú ho dva testy | `budget.js:1428-1433` (volanie 1372, export 2483), `ui/studio.html:555-560`; `tests/js/test_st1c_ponuka.js:191`, `tests/pure/test_st1c_ponuka.rb:96-98` | J6 | PRAVDA |
| S9 | **A-03:** celkový počet skriniek **už je v payloade** — `Validation.counts` vracia `cabinets` aj `clean`, `with_budget` ich prenesie | `core/validation.rb:1885-1897`, `322-325` | Ruby S7: `{"orange"=>1, "cabinets"=>7, "clean"=>6}`; S8: po `with_budget` `cabinets 7` ostáva | PRAVDA — **oprava CU-09** („počet treba doplniť"): payload sa nemení |
| S10 | Semafor ukazuje „0 skriniek bez nálezu" bez menovateľa; oranžový chip počíta nálezy, zoznam ich D-122 zlučuje (UNI skupina) | `studio.js:370-387`, `402-425` | J1: „0 blokuje výrobu 10 skontroluj pred objednávkou 0 skriniek bez nálezu" | PRAVDA |
| S11 | Lišta píše „Vypnuté — v modeli nie je nič nakreslené." vždy, keď sú vypnuté hrany — aj pri zapnutom smere otvárania | `studio.js:796-810`, `821-822`, `862-865`, `896-899` | J2: „Vypnuté — v modeli nie je nič nakreslené. · 0 krídel · 1 bez smeru (legacy)" | PRAVDA |
| S12 | **A-04:** nadpis skupiny v Nákupe = surový kód `r.category`; SK popisok existuje (`HardwareCatalog.category_label`, pri neznámom kóde vráti kód) | `studio.js:707`; `core/hardware_catalog.rb:75-85`, `702-704` | Ruby S1: `["Závesy","Výsuvy","Nohy a montáž","Spojovací materiál","XYZ"]`; J4: „ZAVESY … SPOJOVACI_MATERIAL" | PRAVDA — JS test má vo fixtúre už „Závesy" (`test_st1c_nakup.js:36-41`), preto chybu neodhalil |
| S14 | CSV kovania počíta nákup **nanovo** (`do_hw_csv` → `hardware_expansion`) a píše surový kód kategórie aj `params_label` (stĺpec „rozmer") | `ui/production_core.rb:2029-2050`; `core/hardware_sets.rb:2470-2497` | — | PRAVDA — obohatenie payloadu Štúdia CSV nezmení, **ak nemutuje** `hw_exp` |
| S15 | `params_label` („rez 597 mm") má troch konzumentov: Štúdio, CSV („rozmer") a vety Kontroly | `hardware_rules.rb:1834-1840`; `hardware_sets.rb:2497`, `2555`; `validation.rb:1680` | Ruby S4: len dĺžkový príznak, inak `nil` | PRAVDA — **pasca:** `params_label` sa meniť NESMIE → nové pole `params_text` |
| S16 | Slovník parametrov už existuje: `HardwareSets.param_label` (height → „výška sokla", front_height → „výška čela"; neznámy → „parameter „x"“), `class_label` (dvierka, klasické, Tip-On …), `fmt_mm`, idiom „NL 470 mm" | `hardware_sets.rb:440-443`, `1062-1065`, `390-401`, `6088-6092`, `2720-2724`, `5776-5778` | Ruby S2/S3/S5 | PRAVDA — `PARAM_OPTIONS` je zároveň ponuka editora pásiem → **nerozširovať** |
| S17 | Kľúče params generík: `use_type`/`opening_mode` (závesy), `nominal_length`, `front_height` (výsuvy), `height` (nohy), `cut_length_mm`+`profile` (úchytkový profil), výklop `use_type`/`lift_system`/`opening_mode`/`rod_count`/`rod_extension`/`lift_class`/`arm_class` | `hardware_rules.rb:1810-1816`, `1485`, `1805`, `259`, `1827`, `1517-1519`, `1649-1690` | — | PRAVDA (výklopové kľúče NEOVERENÉ na reálnej zákazke) |
| S18 | Stĺpec „Kde" skladá JS z `breakdown` bez zlučovania (dve zásuvky tej istej skrinky = dva záznamy), zápis „CAB-003×1" oproti Kusovníku „CAB-001 ×1"; `breakdown` (`owner_pid`) používa klik-select | `studio.js:775-778`, `295`; `core/bom.rb:1733-1757`; `production_core.rb:799` | J4: „CAB-003×1, CAB-003×1" | PRAVDA — zlúčenie musí robiť server (S3), `breakdown` ostáva |
| S19 | **A-07:** hlavičky sú natvrdo `Položka · Sadzba · € · €€ · €€€`, bunky režimov idú podľa `SS_STATE.modes`; prázdna bunka nemá sivé číslo | `studio_settings.js:113-141` | — | PRAVDA (hlavičky a bunky majú dnes dva zdroje poradia) |
| S20 | Výpočet: `SupplierSettings.rate` = hodnota režimu ‖ základ ‖ **seed**; `row_rate` = hodnota režimu ‖ základ; Rozpočet ich volá | `supplier_settings.rb:686-696`; `budget.rb:549`, `590` | Ruby S9: porez 17/17/17; S9b: základ chýba v súbore → počíta sa **17 zo seedu**, hoci bunka Základ je prázdna. Payload nastavení (`supplier_settings_dialog.rb:132-149`) nesie `modes` a `mode_labels`, nie platné sadzby; uloženie posiela len rozpísané polia (`studio_settings.js:867-887`) | PRAVDA — **pasca:** sivé číslo musí prísť zo servera (`rate`), nie z bunky Základ |
| S23 | **A-06:** `on_model_changed` (z `EngineAppObserver` pri New/Open/Activate) → `disable!` → `remove_overlay(@model STARÝ, ov)` → `model.overlays.remove` → výnimka ide do `Engine.log_error` (Ruby konzola) | `direction_check.rb:656-664`, `624-638`, `674-680`; `scale_observer.rb:964-997`; `main.rb:27-31` | — | PRAVDA (tok) |
| S24 | Ten istý tok majú `EdgeCheck` a `GrainCheck`; `HoverEdge` výnimku ticho zahodí | `edge_check.rb:580-585`, `grain_check.rb:405-410`, `hover_edge.rb:205-210` | — | PRAVDA — pri zapnutých hranách/kresbe by log hlásil to isté; in-SU testy prepnutie simulujú len na **živom** modeli (`su_runner.rb:21852`, `12509`) |
| S26 | Príčina „invalid overlay": ktoré volanie padá (`overlays` zatvoreného modelu vs `remove` zneplatneného overlayu) a či ho rozlíši `Sketchup::Model#valid?` / `Sketchup::Overlay#valid?` | — | text chyby z orchestrátorovej sondy 1.10. | **NEOVERENÉ** — prvý krok H3b (§6.6) |
| S27 | Zlaté testy, ktoré dokážu „čísla sa nezmenili": `np4_golden` (payload Rozpočtu, XLSX rozpočtu, hárok cien ponuky), `kovh_golden` (nákup kovania + CSV bajtovo), `test_np1_vepo_charakterizacia.rb` (VEPO), `kova_golden` | `tests/fixtures/*`, `tests/pure/test_np4_golden.rb`, `test_kovh_golden.rb` | — | PRAVDA — pokrývajú všetky výstupy H3 |

**Záver sondy:** všetky zmeny H3a sú zobrazenie; payload dostane len **aditívne** kľúče (`category_label`, `params_text`, `where`, `label` pri
nemapovaných, `effective` v nastaveniach), ktoré sa nikam neukladajú a čítajú ich len okná Štúdia. `plates_min/max`, `params_label`, `breakdown`,
`counts` a všetko, z čoho sa robia exporty, ostáva nedotknuté.

---

## 1 · Cieľ

Okno Štúdia nesmie ukazovať číslo alebo slovo, podľa ktorého stolár urobí chybu: Kusovník prestane sčítavať platne rôznych materiálov a pošle na
Nárezový plán; Cenová ponuka sa číta zľava doprava ako faktúra (množstvo · MJ · suma) a nulové služby píše „v cene"; Kontrola povie „0 zo 7 skriniek"
a „10 nálezov v 5 riadkoch" a o prázdnom modeli hovorí len vtedy, keď je naozaj všetko vypnuté; Nákup kovania hovorí po slovensky; Nastavenia rozpočtu
ukážu v prázdnej bunke sadzbu, ktorá naozaj platí. Po otvorení nového súboru Ruby konzola nehlási falošnú chybu.

## 2 · Rez a odhad veľkosti

Riadky **kódu pluginu** (bez testov, dokumentácie a mechanického `?v=`):

| Súbor | A-01 | A-02 | A-03 | A-04 | A-07 | A-06 |
|---|---|---|---|---|---|---|
| `ui/js/studio.js` | ~12 | — | ~40 | ~20 | — | — |
| `ui/js/budget.js` | — | ~15 (−10 rámik) | — | — | — | — |
| `ui/js/studio_settings.js` | — | — | — | — | ~25 | — |
| `ui/studio.html` (CSS) | ~4 | −6 | — | — | — | — |
| `ui/production_core.rb` | — | — | — | ~35 | — | — |
| `core/hardware_sets.rb` (`params_text`) | — | — | — | ~40 | — | — |
| `ui/studio_dialog.rb` | — | — | — | 1 | — | — |
| `ui/supplier_settings_dialog.rb` | — | — | — | — | ~12 | — |
| `core/direction_check.rb`, `edge_check.rb`, `grain_check.rb` | — | — | — | — | — | ~25 |
| **Spolu** | | | | | | **H3a ~205 · H3b ~25** |

**Odporúčanie: rez H3a → H3b** (spolu ~230 riadkov, < 1 deň). Nie kvôli veľkosti, ale kvôli **bránam**: H3a je čisté zobrazenie (bez in-SU, bez auditu),
H3b mení tok, ktorý spúšťa observer pri výmene dokumentu (in-SU brána, audit podľa §5). Spolu by in-SU a prípadný audit zdržali päť UI opráv. Keď
orchestrátor rez nechce, spojená dávka má triedu H3a + H3b dokopy (in-SU áno).

## 3 · Scope IN

**H3a (v0.17.1)**
- **A-01** Kusovník: zo súčtového riadku (pohľad Dielce aj Platne) zmizne súčet platní cez materiály; namiesto neho preklik do Nárezového plánu.
- **A-02** Cenová ponuka v Štúdiu: poradie stĺpcov, „v cene" pri nulovej fixnej službe, preč rámik DOCX/PDF, veta poznámky.
- **A-03** Kontrola: zelený chip s menovateľom, oranžový chip s počtom riadkov, veta lišty o prázdnom modeli len pri všetkých kresbách vypnutých.
- **A-04** Nákup kovania: slovenské nadpisy kategórií, ľudské parametre generík, zlúčený stĺpec „Kde", slovenský typ pri nemapovaných položkách.
- **A-07** Nastavenia rozpočtu: sivá platná sadzba v prázdnej bunke režimu, hlavičky „Základ · € nízky · €€ štandard · €€€ vysoký", upravená nápoveda.
- Dokumentácia: odseky dotknutých modulov (§11).

**H3b (v0.17.2)**
- **A-06** Vypnutie prekrytia (smer otvárania, kontrola hrán, smer kresby) po výmene dokumentu nezapisuje falošnú chybu; živý dokument sa správa ako dnes.

## 4 · Scope OUT

- **XLSX cenovej ponuky** (poradie stĺpcov, 0 € pri Zameraní) — nemení sa (Michal: zmena XLSX = po V1).
- **CSV kovania** — kategória ostáva kódom (`ZAVESY`), stĺpec „rozmer" ostáva `params_label`, „MIMO KATALÓGU" ostáva.
- **Výpočty:** rozpočet, sadzby, odhad platní, nákup kovania, Kontrola (počty, poradie, dedup), VEPO — bez zmeny. `BUDGET_STD`, `CONFIG_SCHEMA`, STD ani schéma
  súboru nastavení sa nezvyšujú.
- `totals.plates_min/max` ostávajú v payloade (§12 D2); stĺpec „Odhad platní" po materiáloch v pohľade Platne ostáva.
- Žargón „(legacy)", „poradie určuje server", veľké písmená, jednotky (`BM`, `PLATŇA`), formát čísel naprieč sekciami → **H4** (D-04, D-07).
- Segment €/€€/€€€ v Rozpočte (tooltip) — nemení sa. Stĺpec „kde" pri nemapovaných („CAB-2 · front-1") — nemení sa.
- Spoločný základ prekrytí (F-03, Po V1) — H3b opravuje minimálne v každom module zvlášť.

## 5 · Trieda dávky (CLAUDE.md)

| Otázka | H3a | H3b |
|---|---|---|
| **Výrobná/cenová** (mení kusovník, nákupné zoznamy, kovanie, ceny) | **ÁNO — konzervatívne:** mení, ako okno ukazuje súčty Kusovníka, Nákup kovania a sumy ponuky; čísla nie (dôkaz §7). Zhodné s predpokladom PLAN | nie |
| **Audit-povinná** (kontrakt, schéma, migrácia, observer/undo lifecycle, nový modul) | **nie** — žiadny bump schémy, žiadna migrácia, žiadny observer/undo, nové funkcie v existujúcich moduloch; aditívne kľúče payloadu okna sa neukladajú a nie sú kontraktom STANDARD (§11.3 platí: server počíta, klient zobrazuje) | **hraničné — rozhodne orchestrátor podľa sondy §6.6:** ak oprava ostane **stráž v `remove_overlay`** (nemení poradie ani volanie `attach/detach` observerov, `on_model_changed` ani `restore!`), audit netreba; ak sonda vynúti zmenu toku `disable!`/`on_model_changed` (napr. nový režim „len zabudni") → **audit-povinná** |
| **Predrecenzia** | **povinná** (výrobná/cenová + nový ovládací prvok: preklik v Kusovníku) | povinná len ak audit-povinná |
| **In-SU brána** | **nie** (§8) | **áno** (§8) |
| **Nový ovládací prvok** | áno — tlačidlo-odkaz „Nárezový plán" v súčtovom riadku Kusovníka (2 pohľady) | nie |
| `codex-po-pr` | povinné | povinné |

## 6 · Požiadavky

Spoločné: čísla s desatinnou čiarkou (existujúce `num`, `budFmtEur`, `HardwareSets.fmt_mm`), € s dvomi desatinnými a medzerou tisícov (`budFmtEur`).
Žiadny unicode glyf ani emoji v ovládaní (UI_DIZAJN §1) — ikony zo spritu. **`studio.js` nesmie obsahovať `reduce(` ani `+= x.quantity` / `+= x.m2`**
(guard S3). Texty sa escapujú ako dnes (`esc`, `bEsc`, `textContent`).

### 6.1 A-01 · Kusovník bez súčtu platní (H3a)

- **R-A01-1 (pohľad Dielce, `totalRow`):** ľavá časť bez zmeny (`Spolu N dielcov · X m² · M materiálov`, pri filtri počítadlo). Pravá časť:
  `<span class="tmuted">ABS spolu {bm} bm · platne na objednávku: </span>` + tlačidlo
  `<button type="button" class="linkbtn" data-nav="cut" title="Koľko platní objednať, počíta Nárezový plán po materiáloch — súčet cez rôzne materiály sa objednať nedá.">{ico('scissors')}Nárezový plán</button>`.
  Text „odhad … platní" zo súčtového riadku **zmizne**.
- **R-A01-2 (pohľad Platne, `sheetsTable`):** súčtový riadok `Spolu <b>{m2} m² dielcov</b>` + vpravo
  `<span class="tmuted">odhad v stĺpci je orientačný (prerez 10–25 %) · platne na objednávku: </span>` + to isté tlačidlo. Stĺpec „Odhad platní"
  po materiáloch aj hint o dupláku ostávajú.
- **R-A01-3:** klik ide **existujúcou** cestou `data-nav` → `onNav('cut')` → `studioGoSection('cut')` (S4) — žiadny nový listener ani server.
- **R-A01-4 (CSS `studio.html`):** `.totrow .linkbtn` = vzhľad odkazu ako `.npwarn .linkbtn` (bez rámu a pozadia, `color: var(--nx-select)`, podčiarknutie,
  `font: inherit`, `cursor: pointer`) + `.totrow .linkbtn .ic { width: 12px; height: 12px; }`, `display: inline-flex; gap: 3px`. Žiadna nová farba.
- **R-A01-5:** `totals` v payloade sa nemení (§12 D2).

### 6.2 A-02 · Tabuľka Cenovej ponuky (H3a, len okno)

- **R-A02-1 (`budCpTableHtml`):** hlavička `Položka · Množstvo · MJ · Spolu · V ponuke`; „Spolu" má `class="bnum"` a
  `title="Suma za celý riadok, nie cena za kus"`. Bunky v tomto poradí; „Množstvo" ako dnes (`budFmtNum(r.mnozstvo, 0)`).
- **R-A02-2 („v cene"):** bunka Spolu = `v cene` (trieda `bfnt`) **len** ak `r.kind === 'fixed'` a `Number(r.cena)` je konečné číslo s `|cena| < 0,005`.
  Inak `budSub(r.cena, d)` ako dnes (DPH prepínač platí).
- **R-A02-3 (okraje):** `kind: 'info'` (dodáva zákazník) ostáva **„0,00 €"** — nie je to naša služba „v cene"; `kind: 'assembly'` s nulou = „0,00 €";
  `cena` `null`/nečíslo = „—" (STANDARD §11.3: neznáma cena nikdy nie je 0 ani „v cene"); fixná nenulová (Montáž, Réžia, Doprava) = suma.
- **R-A02-4 (súčet):** riadok `SPOLU`: `<td>SPOLU</td><td></td><td></td><td class="bnum">{suma}</td><td></td>`.
- **R-A02-5 (rámik):** `budOfferWireHtml` sa odstráni celý (volanie v `budOfferHtml`, funkcia, export pre testy) aj CSS `.bwire` v `studio.html`.
  DOCX/PDF ostáva v zásobníku Po V1.
- **R-A02-6 (poznámka `bnote`):** veta „Zameranie a Vizualizácie sú v ponuke vždy 0 € (náklad je rozpustený v zostave)." → „Zameranie a Vizualizácie sú
  v ponuke vždy „v cene" (náklad je rozpustený v zostave; v XLSX ponuky majú 0 €)." Zvyšok vety bez zmeny.

### 6.3 A-03 · Kontrola: semafor a veta lišty (H3a)

- **R-A03-1 (zelený chip):** číslo = `counts.clean` (server). Text:
  - `counts.cabinets` ≥ 1 → `{z|zo} {cabinets} {skrinky|skriniek} bez nálezu` — „skrinky" len pri `cabinets === 1`. Príklad: **„0 zo 7 skriniek bez nálezu"**,
    „3 z 5 skriniek bez nálezu", „1 z 1 skrinky bez nálezu".
  - `counts.cabinets === 0` → číslo `0`, text „skriniek v modeli".
  - `counts.clean == null` → „— skriniek bez nálezu" (dnešný tvar starého payloadu); `clean` bez `cabinets` → „{clean} skriniek bez nálezu" (dnešný tvar).
  - tooltip: „Skrinky, ktoré v zozname nálezov nefigurujú — z celkového počtu skriniek v modeli (počíta server)."
- **R-A03-2 (predložka z/zo — čistá funkcia `skZo(n)`, exportovaná pre test):** „zo" keď sa číslovka vyslovuje na s/z/š/ž, inak „z":
  1–9: zo pri 4, 6, 7 · 10–19: zo pri 14, 16, 17 · 20–99: zo pri desiatkach 4, 6, 7 (40–49, 60–79) · 100–999: zo pri stovkách 1, 4, 6, 7
  (100–199, 400–499, 600–799) · ≥ 1000: „z" (priznaný limit, zákazka taký počet skriniek nemá).
- **R-A03-3 (oranžový chip):** číslo = `counts.orange` (server). Text = `{nález|nálezy|nálezov}` (1 / 2–4 / 0 a 5+) + ak je známy počet riadkov
  `M` a `M < N`: ` v {M} {riadku|riadkoch}` (1 / inak) + ` · skontroluj pred objednávkou`. Príklad: **„10 nálezov v 5 riadkoch · skontroluj pred objednávkou"**,
  „3 nálezy · skontroluj pred objednávkou".
- **R-A03-4 (počet riadkov `M`):** počet **oranžových riadkov**, ktoré zoznam vykreslí bez filtra: oranžové nálezy mimo UNI skupiny + 1, ak existuje aspoň
  jeden nález UNI skupiny (D-122). Predikát UNI skupiny (`category === 'uni_material' && severity === 'orange'`) sa vytiahne do **jednej** funkcie,
  ktorú používa `ctrlListHtml` aj počítadlo (parita testom). Počíta sa filtrom a dĺžkou poľa (nie `reduce`/`+=` — S3). Je to **zobrazovací počet riadkov**,
  nie údaj o dátach — dokumentovať ako vedomú výnimku k „všetky čísla sú serverové" (§12 D7).
- **R-A03-5:** `semaforHtml(counts, filter, list)` — tretí argument voliteľný (`ST.control` z `ctrlSection`); bez neho sa „v M riadkoch" nepíše
  (staré testy ostanú platné). Červený chip bez zmeny.
- **R-A03-6 (veta lišty, `edgeCheckBarHtml`):** text `.ecinfo` sa skladá z častí spojených ` · ` **bez úvodného oddeľovača**:
  - hrany zapnuté → `edgeCheckText(st)` (bez zmeny);
  - kresba zapnutá → `<span class="gcinfo">{grainCheckText}</span>`; smer otvárania zapnutý → `<span class="dcinfo">{directionCheckText}</span>`;
  - **žiadna časť** (všetky tri vypnuté alebo nedostupné) → „Vypnuté — v modeli nie je nič nakreslené."
  `edgeCheckText` sa nemení (test D-104 platí). Nedostupné hrany (`ecoff`) bez zmeny. Príklad: len smer otvárania → „0 krídel · 1 bez smeru (legacy)".

### 6.4 A-04 · Nákup kovania po slovensky (H3a)

**Server (jadro, nie okno — vzor `hardware_labeled`, test `test_st1c_nakup.rb:126` zakazuje popisky v `studio_dialog.rb`):**
- **R-A04-1 `ProductionCore.hardware_sets_labeled(exp)`** → `nil` pri ne-Hash; inak **nová** kópia `exp.merge('rows' => …, 'unmapped' => …)`:
  riadok dostane `'category_label' => HardwareCatalog.category_label(r['category'])` (pri `missing: true` nie); nemapovaná položka
  `'label' => HardwareRules.label_for(u['generic_type'])`. **Vstup sa nemutuje** (test hlbokou zhodou pred/po). `studio_dialog.rb:1646`:
  `hardware_sets: ProductionCore.hardware_sets_labeled(hw_exp)`; ostatní konzumenti `hw_exp` (plán, rozpočet, Kontrola, spotrebiče) ho dostávajú ako dnes.
- **R-A04-2 `HardwareSets.params_text(params)`** (v sekcii „slovník parametrov", vedľa `param_label`) → `String` alebo `nil`. Časti v pevnom poradí,
  spojené ` · `, kľúč bez použiteľnej hodnoty sa vynechá:
  1. `use_type` → `class_label` s malým prvým písmenom („dvierka", „zásuvka", „výklop", „sklopné"); `other` vynechať
  2. `opening_mode` → `classic` „klasické otváranie", `tipon` „Tip-On", `other` vynechať
  3. `drawer_construction` → `class_label` s malým prvým písmenom; `other` vynechať
  4. `lift_system` → `class_label` („HK top (veko)")
  5. `nominal_length` → „NL {fmt_mm} mm"
  6. `front_height` → „{param_label} {fmt_mm} mm" = „výška čela 150 mm"
  7. `height` → „výška sokla 100 mm" (`param_label`)
  8. `cut_length_mm` → `HardwareRules.params_label(params)` („rez 597 mm"); `profile` vynechať (dnes sa tiež neukazuje)
  9. výklop (návrh textu, vratný): `rod_count` „stabilizačné tyče {n}", `rod_extension` 1 → „s predĺžením tyče" (0 vynechať), `lift_class` „mechanizmus {v}",
     `arm_class` „ramená {v}"
  10. neznámy kľúč → `"#{param_label(k)} #{v}"` (existujúci idiom „parameter „x" 5"), zoradené podľa kľúča — nič sa nestratí
  Neznáma hodnota triedneho kľúča → surová hodnota (`class_label` fallback). Prázdny výsledok → `nil`.
  Príklady: `{nominal_length: 470, front_height: 150}` → „NL 470 mm · výška čela 150 mm"; `{use_type: 'door', opening_mode: 'classic'}` →
  „dvierka · klasické otváranie"; `{height: 100}` → „výška sokla 100 mm"; `{cut_length_mm: 597, profile: 'UKW'}` → „rez 597 mm"; `{}` → `nil`.
  `params_label` sa **nemení** (S15).
- **R-A04-3 `hardware_labeled`** navyše pridá `'params_text'` (R-A04-2) a `'where'` = zlúčený pôvod: `breakdown` zoskupený podľa
  (`owner_id`, `source == 'manual'`, `manual_note`) v poradí prvého výskytu, `quantity` sčítané →
  `[{ 'owner_id', 'quantity', 'manual' => bool, 'manual_note' => String|nil }]`. `label`, `params_label` a `breakdown` bez zmeny (klik-select).

**Klient (`buySection`):**
- **R-A04-4 nadpis:** `r.missing ? 'Mimo katalógu' : (r.category_label || r.category || '—')` — starý payload bez `category_label` ukáže kód ako dnes.
- **R-A04-5 parametre:** `g.params_text` ‖ `g.params_label` ‖ dnešný surový fallback (starý payload) ‖ „—".
- **R-A04-6 Kde:** ak `g.where` je pole → `{owner_id} ×{quantity}` + ` (ručne)` pri `manual`, tooltip `manual_note` (ako dnes), oddelené `, `;
  inak dnešná cesta cez `breakdown`, ale so zápisom ` ×` (medzera pred ×, ako Kusovník). Príklad: **„CAB-003 ×2"**, „CAB-2 ×2 (ručne)".
- **R-A04-7 nemapované:** prvý stĺpec `u.label || u.generic_type`.
- CSV kovania, `hwSourcesHtml`, `hwMissWhere` a súčty sa nemenia.

### 6.5 A-07 · Nastavenia rozpočtu ukazujú platnú sadzbu (H3a)

- **R-A07-1 (server):** `SupplierSettingsDialog.settings_payload` pridá `'effective' => { 'rates' => { key => { mode => SupplierSettings.rate(sup, key, mode) } },
  'rows' => { row_key => { mode => SupplierSettings.row_rate(sup, row, mode) } } }` pre `RATE_KEYS`, `standard_rows(sup)` a `MODES`. Iba čítanie —
  revízia ani súbor sa nemenia (test).
- **R-A07-2 (sivé číslo):** v `ssModeCells` pri **prázdnej** uloženej hodnote režimu (`mv[mode]` `null`/chýba) dostane pole
  `placeholder = ssNumText(effective…[mode])` a `title = "Prázdne — platí základ ({číslo})"`. Hodnota poľa ostáva prázdna (`''`) → uloženie ju nepošle
  (S20). Vyplnená bunka placeholder nemá. Pri rozpísanom Základe ukazuje sivé číslo **uloženú** platnú sadzbu až do Uložiť (priznané v nápovede).
- **R-A07-3 (hlavičky):** obe tabuľky: `Položka · Základ · {sym} {label} × modes · (jednotka)`; `{sym}` z malej mapy `nizky → €`, `standard → €€`,
  `vysoky → €€€` (rovnaké symboly ako segment Rozpočtu), `{label}` = `mode_labels[mode]` s malým písmenom → **„€ nízky · €€ štandard · €€€ vysoký"**.
  Hlavičky idú **v poradí `SS_STATE.modes`** (rovnako ako bunky); neznámy režim = jeho `mode_label` alebo kľúč.
- **R-A07-4 (nápoveda fieldsetu Sadzby služieb):** „Automatické služby — množstvo počíta engine z dát zákazky (bm olepu, počet platní, kusy duplákov,
  m² montáže). Stĺpce € nízky · €€ štandard · €€€ vysoký sú sadzby pre cenový režim zákazky; v prázdnej bunke platí základ — ukazuje ho sivé číslo."
- **R-A07-5:** CSS: ak placeholder v `.ssgrid input` nemá dosť kontrastu, `::placeholder { color: var(--nx-ink-muted); }` (existujúci token).

### 6.6 A-06 · Log po otvorení nového súboru (H3b)

- **R-A06-0 (povinná in-SU sonda PRED kódom, výsledok do PR):** v neuloženom okne alebo `ENGINEtests.skp` (nikdy zákazka) zapnúť Smer otvárania
  (aj hrany a kresbu), zapamätať `m_old = Sketchup.active_model`, `ov` = overlay modulu; spustiť `Sketchup.file_new` (Windows SDI); zistiť:
  (a) ktorý riadok zapíše chybu a jej triedu/text; (b) `m_old.valid?` (ak metóda existuje); (c) `ov.valid?` (ak existuje); (d) či `m_old.overlays`
  samo padá; (e) či padá aj `detach_observer` (`remove_observer`). Jednorazový skript v scratchpade (vzor `-RubyStartup`), nie v repe.
- **R-A06-1 (funkčná požiadavka):** keď dokument, ktorému overlay patril, **už nie je otvorený** (SketchUp ho zavrel aj s prekrytiami), vypnutie iba
  zabudne referencie (`@overlay`, `@model`, cache) — nič neodregistrováva a **nezapisuje chybu**. Keď dokument žije (vypnutie tlačidlom, macOS prepnutie
  okien, `restore!`), overlay sa z modelu odstráni ako dnes a skutočná chyba sa **ďalej zapíše** cez `Engine.log_error`.
- **R-A06-2 (preferovaná implementácia, podľa sondy):** v `remove_overlay` (a ak sonda ukáže, aj v `detach_observer`) stráž „dokument je otvorený" —
  `model.valid?`, ak ho API má a po `file_new` vráti `false`; inak „overlay je v modeli zaregistrovaný" (`model.overlays.to_a.include?(overlay)`, pričom
  výnimka tohto čítania = zatvorený dokument → tichý návrat). Rovnaká úprava v **`DirectionCheck`, `EdgeCheck`, `GrainCheck`** (S24); `HoverEdge` bez zmeny.
  Poradie a volania `attach/detach_observer`, `on_model_changed`, `restore!`, `enable!` sa **nemenia** (inak audit, §5).
- **R-A06-3 (zákaz):** žiadne plošné `rescue` bez logu, žiadne porovnávanie textu výnimky („invalid overlay") ako jediný rozlišovač.
- **Výsledok sondy R-A06-0 (H3b, 1.10.2026, SketchUp 2026, kópia ENGINEtests.skp, slučka `-RubyStartup`):** po `Sketchup.file_new` je nový model **ten istý
  Ruby objekt** (`equal?` true), `Model#valid?` ostáva **true** (b), `Overlay#valid?` všetkých troch overlayov je **false** (c), `m_old.overlays` ani `to_a` nepadá
  (overlay v ňom už nie je) (d), `remove_observer` vráti false bez výnimky (e). Pri samotnom `file_new` sa **nič nezapíše** — `on_model_changed` pre zhodný objekt
  skončí skôr a modul drží zneplatnený overlay. Chyba (a) vznikne až **pri otvorení Štúdia**: `restore!` → `enable!` → `disable!` → `remove_overlay` →
  `model.overlays.remove` = RuntimeError „invalid overlay" (`direction_check.rb:677`, `grain_check.rb:407`; `edge_check.rb:582` pri ďalšom kliku na hrany —
  Štúdio hrany neobnovuje). Rozlišovač = **`Overlay#valid?`** (R-A06-2, variant „stráž v `remove_overlay`"); tok sa nemení, audit netreba.

## 7 · Testy a DoD

**7.1 Charakterizácia PRED zásahom (prvý commit vetvy, bez zmeny kódu pluginu):**
1. Existujúce zlaté testy ostávajú **bez pregenerovania a bez úpravy fixtúr**: `test_np4_golden.rb` (payload Rozpočtu vrátane `cp_preview`, XLSX rozpočtu,
   **hárok cien XLSX ponuky**), `test_kovh_golden.rb` (**nákup kovania + CSV bajtovo**), `test_np1_vepo_charakterizacia.rb` (**VEPO**), `test_kova_golden.rb`,
   `test_ceny_m2_golden.rb`. Akákoľvek ich zmena = nález, nie šum.
2. Nový `tests/pure/test_h3_charakterizacia.rb` (commit „charakterizácia pred H3"): pripne dnešný `totals_payload` pre vzorový BOM + odhad
   (`plates_min/max` = súčet), `Validation.counts` s `cabinets/clean`, `settings_payload` (kľúče a `revision`) a výstup `hardware_labeled` pre prípady
   `kovh_golden` (kľúče `label`, `params_label`, `breakdown`). Po zásahu musí ostať zelený s jediným dovoleným rozdielom = **nové aditívne kľúče**
   (`params_text`, `where`, `effective`), ktoré test pred porovnaním vyberie a overí zvlášť.

**7.2 Nové testy H3a:**
- `tests/pure/test_h3_zobrazenie.rb`: `params_text` (matica R-A04-2 vrátane neznámeho kľúča, neznámej triedy, `other`, `nil`, prázdneho hash, výklopu);
  `where` (dve pravidlové položky CAB-003 → jedna ×2; ručná + pravidlová tej istej skrinky → dve; rôzne `manual_note` → oddelené; poradie prvého výskytu);
  `hardware_sets_labeled` (kategórie, `missing` bez popisku, neznámy kód → kód, `nil` → `nil`, **vstup nezmutovaný** — `Marshal.dump` pred/po, **CSV z toho
  istého `exp` bajtovo rovnaké pred a po volaní**); `effective` (= `rate`/`row_rate` pre každý kľúč a režim; základ chýba v súbore → seed 17, S20;
  revízia nastavení nezmenená); zdroj `studio_dialog.rb` volá `hardware_sets_labeled(hw_exp)`.
- `tests/js/test_h3_zobrazenie.js`: `skZo` (1, 2, 4, 5, 6, 7, 8, 10, 14, 16, 17, 18, 20, 40, 47, 60, 70, 79, 80, 100, 150, 200, 400, 700, 1000); zelený chip
  (7 → „zo 7 skriniek", 1 → „z 1 skrinky", 0 skriniek, bez `cabinets`, `clean` null); oranžový (6 UNI + 3 rozpočet + 1 iný → „10 nálezov v 5 riadkoch";
  bez UNI → bez „v … riadkoch"; 1 → „1 nález"; bez `list`; **parita**: `M` = počet oranžových riadkov najvyššej úrovne z `ctrlListHtml`); lišta
  (všetko vypnuté → veta; len smer otvárania → bez vety a bez úvodného „ · "; len kresba; hrany + smer; nedostupné → `ecoff`); Nákup (surové `ZAVESY` +
  `category_label` → „Závesy" a žiadne „ZAVESY"; `missing` → „Mimo katalógu"; starý payload → kód; `params_text`; starý payload → fallback; `where` →
  „CAB-003 ×2", ručné „(ručne)" + tooltip; nemapované `label`); Ponuka (poradie hlavičky; „4 · set · 171,56 €"; fixná 0 → „v cene"; fixná nenulová → suma;
  info 0 → „0,00 €"; assembly 0 → „0,00 €"; `null` → „—"; SPOLU v 4. stĺpci; žiadne „vedomý placeholder" ani `bwire`; veta „v cene" v poznámke);
  Kusovník cez `NX.setStudio` sandbox (vzor `test_st1c_ponuka.js`): v súčtovom riadku Dielce aj Platne nie je „platní", je tlačidlo `data-nav="cut"`
  s ikonou `scissors`, klik prepne sekciu na `cut`; stĺpec „Odhad platní" v Platne ostáva; Nastavenia (minidom, vzor `test_st4a_settings.js`):
  placeholder = `effective`, vyplnená bunka bez placeholdera, hlavičky v poradí `modes`, **`ssBuildPatch` bez písania = žiadna zmena**, nápoveda.
- **Vedomé úpravy existujúcich testov:** `test_st1c_nakup.js` (fixtúra na reálny tvar `category: 'ZAVESY'` + `category_label`; „MIMO KATALÓGU" → „Mimo
  katalógu"; „CAB-2×2 (ručne)" → „CAB-2 ×2 (ručne)"; fallback „angle 110" ostáva pre starý payload), `test_st1c_ponuka.js:191` a
  `test_st1c_ponuka.rb:96-98` (rámik → `refute`). Overiť bez zmeny: `test_st1b_kontrola.js` (obsahuje „skriniek bez nálezu" aj „>17<"),
  `test_d104`, `test_d105`, `test_k2_smer_kresby.js`, `test_kova2b_smer_overlay.js`, `test_st1b_kontrola.js:142`, `test_st1a_studio.rb:796-805`, `test_st4a_*`.

**7.3 Mutácie H3a (každá musí zhodiť aspoň jeden test):** M1 súčtový riadok stále píše „platní" · M2 odkaz bez `data-nav` · M3 fixná 0 → „0,00 €" ·
M4 „v cene" aj pri `info` · M5 „v cene" pri `null` · M6 staré poradie stĺpcov · M7 zelený chip bez menovateľa · M8 `skZo(7)` = „z" · M9 `M` počíta aj červené
alebo bez UNI zlúčenia · M10 veta „Vypnuté…" pri zapnutom smere otvárania · M11 úvodné „ · " pri vypnutých hranách · M12 nadpis = surový kód ·
M13 `hardware_sets_labeled` mutuje vstup · M14 zmena `params_label` namiesto nového poľa (zhodí `kovh_golden` CSV) · M15 `where` zlúči ručnú s pravidlovou ·
M16 placeholder z bunky Základ namiesto `effective` (S20) · M17 placeholder zapísaný ako hodnota (patch nie je prázdny) · M18 hlavičky mimo poradia `modes`.

**7.4 H3b:** `tests/pure/test_h3b_overlay_novy_subor.rb` pre **každý** z troch modulov: stub „zatvorený dokument" (podľa sondy — `valid?` false a/alebo
`overlays`/`remove` hodí `RuntimeError`) + stav modulu (`@overlay`, `@model`) → `on_model_changed(novy)`: **žiadny `Engine.log_error`** (dočasne
presmerovaný zapisovač), `active?` false, `@overlay` nil; stub „živý dokument": `remove` zavolané **presne raz**; živý dokument s chybou `remove` →
`log_error` **áno** (skutočná chyba sa nezamlčí). Mutácie: stráž odstránená → log sa objaví; stráž preskočí aj živý model → overlay ostane (headless + in-SU
`run_d104` krok 8, `run_kova2b` krok 12).

**7.5 DoD (obe dávky):** celá headless sada `ruby tests/run_all.rb`, **každá** JS sada zvlášť (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`),
encoding guard; zlaté testy §7.1 bez zmeny fixtúr; PR popis uvedie zoznam „čo sa nezmenilo" (XLSX ponuky, CSV kovania, VEPO, Rozpočet).

## 8 · In-SU test

- **H3a — nie je brána.** Spúšťače (buildery, observery, undo/operácie, geometria, akcie panela zapisujúce do modelu) sa nemenia: zmeny sú v JS a
  v čisto čítacom obohatení payloadu (`hardware_sets_labeled`, `params_text`, `effective`). Voliteľne jeden beh `run_su_tests.ps1 -CloseWhenDone`
  ako dymová kontrola, ak je SketchUp voľný.
- **H3b — áno, brána mergu.** Mení kód, ktorý spúšťa `EngineAppObserver` pri výmene dokumentu; skutočné zatvorenie dokumentu headless neoverí.
  Postup: (1) sonda R-A06-0 (jednorazový skript, výsledok do PR); (2) celý runner `scripts\run_su_tests.ps1 -CloseWhenDone` (regresia `run_d104`,
  `run_k2`, `run_kova2b`); (3) jednorazové overenie opravy tým istým skriptom ako sonda (pred opravou chyba v konzole, po oprave nie). Scenár s `file_new`
  **nepridávať do celej sady** — vymenil by dokument runnera uprostred behu. PR uvedie hlavu, na ktorej in-SU bežal.

## 9 · Riziká

- **Okno a XLSX ponuky sa líšia** (poradie stĺpcov, „v cene" vs 0 €) — vedome prijaté (Michal: XLSX po V1); poznámka pod tabuľkou to hovorí.
- **Okno a CSV kovania hovoria inak** (Závesy vs `ZAVESY`) — CSV ide dodávateľovi a má ostať bajtovo rovnaké; zjednotenie CSV = samostatné rozhodnutie.
- **Mutácia `hw_exp`** by potichu zmenila ďalších konzumentov v tom istom pushi → povinná nemutujúca kópia + test (M13).
- **Guard S3** (`reduce(`, `+=` v `studio.js`) — počítadlo riadkov a zlúčenie „Kde" ho nesmú obísť (zlúčenie je na serveri).
- **Sivé číslo ako hodnota:** placeholder môže pôsobiť ako uložené číslo → sivá farba + tooltip + nápoveda; test, že uloženie nič nepošle (M17).
- **Dlhší text oranžového chipu** sa v úzkom okne zalomí (chip o ~14 px vyšší) — smoke pri najmenšej šírke okna Štúdia.
- **Nevyužité `plates_min/max`** v payloade — riziko, že ich niekto znova zobrazí; zapísať do odseku `studio_dialog.rb` (ui-lifecycle), odstránenie pri H14.
- **Výklopové texty** (`rod_count`, `lift_class`, …) nie sú overené na reálnej zákazke — návrh, vratný; neznámy kľúč sa nestratí (fallback).
- **H3b:** príčina NEOVERENÁ (S26) — ak `valid?` neexistuje alebo nerozlíši, platí záložná stráž R-A06-2; ak ani tá nestačí a treba meniť tok →
  audit (§5). Riziko zamlčania skutočnej chyby kryje test „živý dokument s chybou = log".

## 10 · Smoke checklist pre Michala (po H3a a H3b)

Otvor zákazku (alebo ukážkovú kuchyňu) a porovnaj s tým, čo si videl pred aktualizáciou:
1. **Kusovník** — spodný súčtový riadok už nepíše „odhad 2,2 – 2,4 platní"; je tam odkaz **Nárezový plán** s nožnicami → klik otvorí Nárezový plán.
   To isté v pohľade **Platne** (stĺpec „Odhad platní" po materiáloch ostal).
2. **Cenová ponuka** — stĺpce **Položka · Množstvo · MJ · Spolu**; riadok Atira „4 · set · 171,56 €" (suma za 4 kusy). Zameranie a Vizualizácie píšu
   **„v cene"**; spotrebič „dodáva zákazník" ostáva 0,00 €. Veľký prerušovaný rámik „po V1" zmizol. **Exportuj XLSX ponuky** — vyzerá presne ako doteraz.
3. **Kontrola** — zelený chip „0 zo 7 skriniek bez nálezu" (7 = počet skriniek v modeli); oranžový „10 nálezov v 5 riadkoch · skontroluj pred objednávkou"
   (5 = riadky v zozname). Vypni všetky tri kresby → „Vypnuté — v modeli nie je nič nakreslené."; zapni len **Smer otvárania** → táto veta zmizne, ostane
   počet krídel.
4. **Nákup kovania** — nadpisy **Závesy, Výsuvy, Nohy a montáž, Spojovací materiál**; parametre napr. „NL 470 mm · výška čela 150 mm", „dvierka · klasické
   otváranie", „výška sokla 100 mm"; stĺpec Kde „CAB-003 ×2". **Exportuj CSV kovania** — rovnaké ako doteraz (kategória ostáva veľkými písmenami).
5. **Nastavenia rozpočtu** — prázdne bunky režimov ukazujú sivé číslo (napr. Porez 17); hlavičky **Základ · € nízky · €€ štandard · €€€ vysoký**. Klikni
   Uložiť bez zmeny — nič sa nezmení; Rozpočet má rovnaké sumy.
6. **Sumy sa nezmenili:** Rozpočet SPOLU, suma ponuky a SPOLU nákupu kovania sú rovnaké ako pred aktualizáciou.
7. **(H3b)** Zapni Smer otvárania (aj Zvýrazniť hrany), daj **Súbor → Nový**, otvor Štúdio, pozri **Okno → Ruby konzola**: žiadny riadok
   „DirectionCheck.remove_overlay" (ani EdgeCheck/GrainCheck). Prepínače v novom súbore fungujú — klikni aj **Zvýrazniť hrany** (Štúdio ich samo neobnovuje,
   chyba hrán sa doteraz ukázala až pri tomto kliku) a skontroluj konzolu znova.

## 11 · Checklist uzáveru

**H3a (PR, v0.17.1):** bump `VERSION` 0.17.0 → **0.17.1** (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky** `?v=` v `ui/*.html` · headless + každá
JS sada + encoding guard zelené · zlaté testy bez zmeny fixtúr · **architektúra na mieste** (prepis odsekov, nie append): `docs/architecture/ui-lifecycle.md`
— odsek `studio_dialog.rb … okno ŠTÚDIO` (súčtový riadok, `totals` nevyužité `plates_*`, preklik), **Sekcia KONTROLA** (Š8 menovateľ a počet riadkov
ako vedomá zobrazovacia výnimka, Š10 skladanie vety), **Sekcia NÁKUP KOVANIA** (`category_label`, `params_text`, `where`), **Sekcia CENOVÁ PONUKA**
(poradie, „v cene", rámik preč), `supplier_settings_dialog.rb` (+ klient `studio_settings.js`: `effective`, placeholder, hlavičky); `docs/architecture/outputs.md`
— `production_core.rb` (`hardware_sets_labeled`, rozšírený `hardware_labeled`); `docs/architecture/hardware.md` — `hardware_sets.rb` (`params_text`
v slovníku parametrov) · **prepis `SYSTEM/STAV.md`** (v0.17.1) · odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md` · `SYSTEM/PLAN.md` riadok **H3**
(resp. H3a) ✅ + `PR #?` → číslo samostatným commitom · package do `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H3.md` · D-čísla: **žiadne** (položky sú
ID triedenia A-01…A-07; ich stav nesie PLAN) · PR popis: čo vidí stolár, sekcia „Predrecenzia", zoznam nezmenených výstupov, „in-SU nie je brána (§8)".

**H3b (PR, v0.17.2):** bump **0.17.2** + `?v=` · testy · `docs/architecture/construction.md` odseky `direction_check.rb`, `edge_check.rb`, `grain_check.rb`
(stráž zatvoreného dokumentu, prečo nie plošný rescue) · STAV · KRONIKA · PLAN riadok H3 (H3b) ✅ + PR · PR: výsledok sondy R-A06-0, hlava in-SU behu.

## 12 · Rozhodnutia autora (bezpečnejšia vratná voľba) — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | Rez **H3a → H3b** | rôzne brány (in-SU, možný audit) — UI opravy nečakajú na SketchUp | **áno** |
| D2 | `totals.plates_min/max` **ostávajú** v payloade, len sa nezobrazia | payload bajtovo rovnaký, test `test_st1a` bez zmeny; odstránenie pri H14 (sekcie Štúdia) | krátko |
| D6 | Menovateľ zeleného chipu z `counts.cabinets` (už v payloade) + funkcia `skZo` | bez zmeny servera; správna slovenčina „zo 7" / „z 5" | nie |
| D7 | Počet riadkov oranžového chipu počíta klient zo **zdieľaného** predikátu UNI skupiny | zlučovanie riadkov (D-122) žije len v klientovi; je to počet riadkov, nie údaj — zapísať ako výnimku k Š8 | **áno** |
| D10 | Parametre ako nové pole `params_text` na serveri; slovník z `HardwareSets` (`param_label`, `class_label`, `fmt_mm`); **„výška čela 150 mm"** namiesto návrhu „čelo 150" | `params_label` ide do CSV a Kontroly (S15); jeden slovník s editorom pásiem a náhľadom setu | krátko |
| D12 | V okne „Mimo katalógu" namiesto „MIMO KATALÓGU"; nemapované dostanú slovenský typ | jeden štýl nadpisov skupín; CSV nezmenené | krátko |
| D13 | Sivé číslo = serverové `effective` (`rate`/`row_rate`), `placeholder`, nie hodnota; „Sadzba" → „Základ" | S20 (seed fallback); uloženie nič nepošle | nie |

Ďalšie voľby bez potreby potvrdenia sú priamo v požiadavkách: preklik cez existujúci `data-nav` s ikonou (R-A01-3, UI_DIZAJN §1), „v cene" len pri fixnej nule (R-A02-2/3), rámik preč aj s CSS (R-A02-5), červený chip a `edgeCheckText` bez zmeny (R-A03-5/6), zlúčenie „Kde" na serveri (R-A04-3, guard S3), H3b minimálne v troch moduloch bez zjednotenia F-03 a bez zamlčania chýb živého dokumentu (R-A06-1/2/3).

## 13 · Otázky pre Michala

Žiadne — všetko vyššie je zobrazenie a vratné; produktový smer schválil Michal triedením 1.10.2026.

---

## Potvrdenie orchestrátora (1.10.2026 ~02:30)

- **D1 rez H3a → H3b: ÁNO.** H3a = A-01, A-02, A-03, A-04, A-07 (výrobná/cenová len zobrazením → predrecenzia povinná; audit nie; in-SU nie). H3b = A-06
  (in-SU brána; ak oprava presiahne stráž v `remove_overlay` a zmení postup `disable!`/`on_model_changed`, **zastaviť a vrátiť orchestrátorovi** — audit).
  V PLAN bloku 9 sa riadok H3 rozdelí na H3a/H3b (urobí implementátor H3a).
- **D2, D6, D10, D12, D13: potvrdené.** **D7: potvrdené** — počet riadkov počíta klient zo zdieľaného predikátu; zapísať ako výnimku k Š8 v odseku Kontroly
  (`ui-lifecycle.md`) a do PR.
- Verzia: H3a bump patch podľa mainu pri štarte (predpoklad 0.17.0 → 0.17.1; H1/H2 plugin nemenia), H3b ďalší patch.
