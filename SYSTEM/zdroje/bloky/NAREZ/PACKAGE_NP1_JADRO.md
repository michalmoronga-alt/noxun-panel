# PACKAGE NP-1 · Nárezový plán — jadro výpočtu (blok 2)

> **Autorita:** rozhodnutia Michala N1–N11 v `SYSTEM/zdroje/bloky/NAREZ/ROZHODNUTIA_MICHALA_2026-09-28.md` a schválený mockup; surový krížový audit
> (`CROSS_AUDIT_CODEX/GROK_2026-09-28.md`, koncept v1 inline v `CROSS_AUDIT_PROMPT_2026-09-28.md`) a rešerš sú v tom istom priečinku — **ako NP-1 naloží
> s ich nálezmi, je v sekcii „Nálezy krížového auditu a rešerše, ktoré rieši NP-1" na konci** (samostatné vyhodnotenie auditu v repe nie je — re-rez #416 → #417). Tento package po audite návrhu
> (codex-audit, `gpt-6-astra`, hotový 28.9. — nálezy zapracované, dodatok na konci) implementátor pridá do priečinka bloku ako `PACKAGE_NP1_JADRO.md`.
> **Trieda:** audit-povinná (nový modul + refaktor prípravy riadka VEPO bez zmeny výstupu) → audit návrhu · slepá predrecenzia pred PR · `codex-po-pr`.
> Nie výrobná/cenová (žiadny výstup sa nemení — modul sa v NP-1 nikam nenapája). In-SU netreba (čistý Ruby, žiadny builder/observer/undo/akcia panela).
> **Verzia:** patch (v0.15.0 → **v0.15.1**; ak medzitým pribudne iná patch verzia v maine, nasledujúca voľná) + všetky `?v=` + prepis `SYSTEM/STAV.md`.

## 0 · Sonda pred auditom (overené na main `47e1303e` / docs `2253d2cc`, 28.9.2026)

- `VepoExport.build` (`noxun_engine/core/vepo_export.rb:197-281`) vracia hotové CSV reťazce po skupinách `[label, tag]`; štruktúrované riadky
  existujú len lokálne (:240-241) a nenesú `material_id`, `key` ani `material_source` → **výstup `build` sa ako vstup plánu použiť nedá**.
- Vyraďovanie a príprava riadka sú inline v slučke `build` :204-221 v tomto poradí: `validate_row` (:348-354 — prázdny materiál, dĺžka/šírka ≤ 0,
  počet < 1) → `oriented` (:143-151 — len `'width'` prehodí dĺžku↔šírku aj hrany L↔W a nastaví `'length'`; `merge` zachová `material_source`) →
  `finished_dimensions` (:157-165 — hrana s `abs_id` mimo `edge_thicknesses` = „neznáma ABS <id>") → `commercial_thickness` (:127-133 — hrúbka ≤ 0).
  Rozmery do CSV = `.round` až po orientácii (:240-241; Integer, polovica od nuly). Duplák ostáva vo VEPO **jeden** riadok duplákového materiálu.
- `Validation.exportable_row?` (`validation.rb:397-407`) sa od VEPO líši (bez katalógu ABS neoveruje) — **nepoužiť**.
- `row['key']` (`bom.rb:1666-1676`) = `[dmm(l), dmm(w), dmm(t), material_id, [L1,L2,W1,W2], grain, [src, mult] | nil]`, `dmm` = Integer v desatinách mm
  → **žiadny Float**, `JSON.generate(row['key'])` je deterministický. Kľúč už putuje do JS a späť (`studio.js:1693` → `production_core.rb:793-796`).
- `ProductionCore.sheets_map` (`production_core.rb:546-553`) = `{material_id => celý normalizovaný záznam}` (`type`, `sheet_size` len keď je platný,
  `uni`, `source_material_id`, `source_multiplier`); `Materials.uni?(rec)` (`materials.rb:763-765`); `Materials.canonical_type(type)` (:1202-1205)
  vráti kľúč `TYPE_REGISTRY` (DTDL MDF HDF PD ZASTENA KOMPAKT) alebo orezaný text („iný" typ). `format_in_identity?` je tá istá množina PD/ZASTENA/KOMPAKT,
  ale iný význam — **nespájať** s politikou orezu.
- `Validation::DIM_TOL = 0.1` (`validation.rb:46`, verejná); `fit_one` (:536-538) = `a <= sl + DIM_TOL && b <= sw + DIM_TOL`; `fits_on_sheet?` pri
  `none` a neznámej hodnote skúša **obe otočenia** — v rozpore s N8, preto ho plán **nepoužije** (Kontrolu zladí NP-2).
- `SheetEstimate.sheet_size_for` (`sheet_estimate.rb:88-104`) = pár s konečnými kladnými číslami, inak `[2800.0, 2070.0]` + `fallback`; stráž dupláku
  `multiplier.to_i >= 2` (:48); hlavička :5-7 („fáza 2 vymení len vnútro výpočtu") po NP-1 neplatí.
- Načítanie: `noxun_engine/main.rb` — bom :503, vepo_export :505, sheet_estimate :506, validation :508, budget :517; `tests/helper.rb` :121-192
  (bom :175 … validation :178, budget :186). Všeobecný guard zoznamu nie je — bodový vzor `tests/pure/test_st1a_core.rb:84-90`.
- Docs guardy: `tests/pure/test_docs_navigacia.rb` (nadpis modulu :262-273, token v tabuľke `docs/ARCHITEKTURA.md` :275-283, jedinečné meno :245-260,
  riadok ≤ 400 znakov :187). STANDARD: §3.3 :375-376 (výmena „výhradne" `VepoExport.oriented` + zrkadlovo `fits_on_sheet?`), §7.1 :928/:948/:961
  (`sheet_size`), §11.1 :1520 („exportéry neobsahujú výpočty rozmerov"), §11.2 :1522-1534 (výstupy), §12 :1586-1588 (nesting mimo scope v1).

## 1 · Cieľ

Čistý Ruby modul **`Noxun::Engine::SheetLayout`** (`noxun_engine/core/sheet_layout.rb` — meno bez `cut_`, ktoré znamená rozmer do nárezu z D-143), ktorý
z agregovaných riadkov kusovníka, záznamov katalógu a troch parametrov vypočíta **per nákupný materiál** deterministické pásové (gilotínové) rozloženie
dielcov na platne: počet platní, využitie, polohy, zvyšky a príznaky. K tomu **jedna spoločná funkcia „zmestí sa na platňu"** (v NP-2 ju prevezme Kontrola
`oversize`) a **jedna spoločná príprava riadka s VEPO** (vytiahnutá z `VepoExport.build` bez zmeny výstupu). V NP-1 sa modul **nikam nenapája**
(Štúdio, rozpočet a exporty sa nemenia).

## 2 · Scope IN

### 2.1 Jedna príprava riadka s VEPO (refaktor bez zmeny správania)
- Z `VepoExport.build` vytiahnuť verejnú funkciu (pracovne `VepoExport.prepare_row(raw, edge_thicknesses)`) presne s krokmi :205-221 **v nezmenenom
  poradí** + zaokrúhlenie rozmerov :240-241. Vracia buď pripravený riadok (orientovaný riadok vrátane `material_source`, zaokrúhlené rozmery `[l, w]`
  Integer, obchodná hrúbka, hrany), alebo dôvod vyradenia s **presne dnešným textom chyby** (poradie iterácie hrán rozhoduje o texte „neznáma ABS <id>").
- `build` ju volá; **VEPO CSV aj LOG musia ostať bajtovo zhodné**. **Najprv charakterizačné testy (audit F3), až potom extrakcia:** nový test uzamkne
  na dnešnom `build` **presné bajty CSV, celý LOG a zoradené `errors`** pre: súbežné chyby na jednom riadku, dve neznáme ABS pri orientácii `width`,
  zlomkové rozmery (…,5), duplák, oba režimy `merge_18_36`; commit testov ide **pred** commit extrakcie a po extrakcii prejde bez zmeny očakávaní
  (existujúce `tests/pure/test_vepo_export.rb`, `test_d112_d113_vepo.rb`, `test_d121b_vepo_kontrakt.rb`, `test_kon0_d143.rb` tiež bez zmeny; `:154` kontroluje
  len slová, preto nestačí sám).

### 2.2 Vstup plánu (tri kroky, C8)
- `SheetLayout.compute(rows, sheets:, edge_thicknesses:, params: {})` — `rows` = `Bom.compute` riadky, `sheets` = celý `sheets_map` (formát, UNI, typ
  v jednom prechode), `edge_thicknesses` = **tá istá mapa, akú dostane VEPO** (`ProductionCore.vepo_edge_thicknesses` — napojenie až v NP-3).
- **(a) prijatie riadka** = `prepare_row` (G3: rovnaké vyradenia ako VEPO). Vyradený riadok s materiálom sa **započíta** do `rejected_rows` toho
  nákupného materiálu (pri dupláku zdrojového) — **počítajú sa RIADKY, nie kusy** (audit F6: riadok s počtom 0 alebo záporným by súčet kusov nezvýšil
  alebo rušil); riadok bez materiálu do `rejected_without_material`. Každý vyradený riadok robí materiál neúplným (C3).
- **Ochrana vstupu plánu (audit F4)** — pred `prepare_row` a okolo neho, **bez zmeny správania VEPO**: riadok, ktorý nie je Hash, nekonečné/NaN rozmery
  alebo hrúbka, hrany mimo očakávaného tvaru → vyradený s dôvodom `invalid_row` (výnimky z `prepare_row` pre takýto riadok plán zachytí a riadok vyradí,
  nikdy nepadne celý výpočet); **rozmer ≤ 0 po zaokrúhlení** (napr. dĺžka 0,1 → 0 mm, ktorú VEPO dnes prijme) → vyradený s dôvodom `zero_after_rounding`.
- **Hrúbka vs. nákupný materiál (audit B1):** jeden `material_id` nezaručuje jednu nákupnú hrúbku (BOM drží rôzne hrúbky oddelene, VEPO prijme obe).
  Obchodná hrúbka riadku (`prepare_row`) sa porovná s hrúbkou záznamu nákupného materiálu (`sheets[material_id]['thickness']`, ak ju záznam má); pri
  dupláku sa porovnáva **zdroj** (vrstvy majú hrúbku zdroja). Nesúlad → riadok sa nerozkladá, materiál dostane `thickness_conflict` (neúplný). Záznam bez
  hrúbky = bez kontroly (priznané).
- **Väzba dupláku katalóg × snapshot (audit B2):** keď záznam materiálu riadku je v katalógu **duplák** (`source_material_id` + `source_multiplier`), ale riadok
  nemá úplný `material_source` (`Bom.record` neúplnú väzbu zahodí), plán väzbu **nedomýšľa**: riadok sa nerozkladá a **zdrojový materiál z katalógu** (ak je
  známy, inak materiál riadku) dostane `duplak_link_missing` (neúplný).
- **(b) VEPO podoba** = zaokrúhlené orientované rozmery z `prepare_row`: `l` beží po dĺžke platne (`sheet_size[0]`, smer kresby), `w` po šírke.
  **Žiadne ďalšie otáčanie** (N8) — ani pri `none`.
- **(c) nákupné obdĺžniky:** bežný riadok → `quantity` obdĺžnikov `l × w` materiálu riadku; riadok s úplným `material_source` a `multiplier >= 2`
  (stráž ako `sheet_estimate.rb:48`) → `quantity × multiplier` obdĺžnikov **zdrojového** materiálu s rozmerom **`(l + 2p) × (w + 2p)`**, kde `p` = prídavok
  dupláku (N7, C1; prídavok sa pripočíta **po** zaokrúhlení, lebo VEPO dostane zaokrúhlený hotový rozmer). Identita obdĺžnika = riadok (`key`) + poradové
  číslo výskytu `n` (od 1); kanonický text riadku = `JSON.generate(row['key'])`.

### 2.3 Parametre a formát
- `params`: `kerf` (prerez, predvolene **5.0**), `trim` (orez okraja na každej hrane, predvolene **10.0**), `dup_allowance` (prídavok dupláku na stranu,
  predvolene **10.0**) — predvolené hodnoty ako konštanty modulu (NP-2 ich nahradí nastaveniami). Neplatný parameter (nečíselný, nekonečný, záporný)
  → výpočet **nepadne**: každý materiál dostane príznak `invalid_params` a žiadne rozloženie; `upper_bound` false.
- Formát = `SheetEstimate.sheet_size_for` nad záznamom (jedna pravda o fallbacku): chýbajúci/neplatný → `[2800.0, 2070.0]` + `fallback`; UNI (`Materials.uni?`)
  → `uni`. Poradie dvojice `sheet_size` sa nenormalizuje — **`sheet_size[0]` je dĺžka platne a smer jej kresby** (nové pravidlo do STANDARD §7.1).
- **Orez podľa typu (N6, N9):** `Materials.canonical_type(rec['type'])` ∈ `NO_TRIM_TYPES = %w[PD KOMPAKT ZASTENA]` → orez 0; všetko ostatné (DTDL, MDF, HDF,
  „iný", neznámy záznam) → orez `trim`. Vlastná konštanta modulu, nie `format_in_identity?`.
- **Neplatné výrobné dáta (audit F5):** agregácia stratí príznak `cut_invalid` (poškodený `cut_size` → geometrické rozmery), hoci skutočný export zastaví
  samostatná brána. Vstup `compute` preto dostane voliteľné **`blocked:`** — `{ all: '<dôvod>' }` alebo `{ material_ids => '<dôvod>' }`; dotknuté materiály
  (pri `all` všetky) dostanú `blocked` s dôvodom a `upper_bound` false (rozloženie sa smie spočítať, len nie ako spoľahlivé). **Kto a z čoho `blocked`
  skladá** (register `Bom::CUT_BLOCKERS`, `newer_config_stop` a pod.), určí package NP-3/NP-4 — v NP-1 len kontrakt a testy.

### 2.4 Algoritmus (C6 — formálne, bez otáčania)
- Použiteľná plocha `Lu = L − 2·t`, `Wu = W − 2·t` (t = orez materiálu). Keď `Lu <= DIM_TOL` alebo `Wu <= DIM_TOL` → všetky obdĺžniky materiálu nezaradené
  s dôvodom `no_usable_area` (G6: neúplný plán, nie pád).
- **Spoločná príprava nákupného obdĺžnika (audit F7)** — verejná funkcia modulu (pracovne `SheetLayout.purchase_rect(hash, sheets:, edge_thicknesses:,
  params:)`), ktorá z hashu tvaru riadku **alebo** záznamu kusovníka (`length, width, thickness, quantity, material_id, edges, grain_direction,
  material_source`) urobí celú rozhodujúcu prípravu: prijatie (`prepare_row` + ochrana vstupu), zaokrúhlenie, voľbu nákupného materiálu (zdroj dupláku),
  prídavok dupláku, kontrolu hrúbky a väzby dupláku, formát a orez podľa typu → `{ok, material_id, l, w, usable [Lu, Wu], trim, grain, reason}`. `compute`
  ju používa pre každý riadok; **Kontrola v NP-2 ju zavolá nad záznamom** — nesmie opakovať žiadny z týchto krokov sama. **Geometria sa vracia aj pri
  `ok: false` z dôvodov, ktoré nesúvisia s rozmermi** (neznáma ABS, `thickness_conflict`, `duplak_link_missing` — pri chýbajúcej väzbe geometria vrstvy bez
  prídavku a materiál riadku), aby Kontrola vedela vyhodnotiť „zmestí sa" aj pri súbežnej chybe ABS či hrúbky (`tests/pure/test_validation.rb:164-171`
  čaká 2 RED); **bez geometrie** len `invalid_row` a `zero_after_rounding` (doplnené orchestrátorom 29.9. po sonde pre NP-2).
- **„Zmestí sa na prázdnu platňu"** = `l <= Lu + DIM_TOL && w <= Wu + DIM_TOL` (tolerancia `Validation::DIM_TOL`, jedna konštanta) — verejná funkcia
  (pracovne `SheetLayout.fits_rect?(rect, allow_rotation:)`); pri `allow_rotation: true` skúša aj výmenu `l`↔`w`. **Plán volá vždy `allow_rotation: false`
  (N8)**; Kontrola v NP-2 volá `allow_rotation: (grain == 'none')` — dnešný výrobný kontrakt otáča dielce bez smeru (Codex review #416, P2).
  Dôvody nezaradenia v pláne: **`oversize`** = nezmestí sa ani otočený (ak je bez smeru) — to isté hlási Kontrola; **`needs_rotation`** = dielec bez smeru,
  ktorý sa zmestí len otočený — plán ho kvôli N8 nezaradí (materiál neúplný), Kontrola ho **nehlási**.
- Radenie obdĺžnikov: `w` zostupne, `l` zostupne, kanonický text riadku vzostupne, `n` vzostupne (úplne určené — nezávisí od poradia vstupu).
- Platňa má pásy `{y, h, used_l, count}` a výšku `used_h`. Pás je pruh cez celú `Lu`, výška pásu = `w` prvého (najvyššieho) obdĺžnika.
- Umiestnenie obdĺžnika `r` (first-fit): **(1)** platne v poradí, v nich pásy v poradí — prvý pás, kde `r.w <= h + DIM_TOL` a
  `used_l + (count > 0 ? k : 0) + r.l <= Lu + DIM_TOL`; `x = used_l + (count > 0 ? k : 0)`, `y` pásu. **(2)** inak **prvá platňa v poradí**, kde sa zmestí
  nový pás: `used_h + (má pásy ? k : 0) + r.w <= Wu + DIM_TOL`; nový pás na `y = used_h + (má pásy ? k : 0)`, `x = 0` (nie len posledná platňa — postreh
  mockupu). **(3)** inak nová platňa, pás na `y = 0`. Kerf len **medzi** dielcami v páse a **medzi** pásmi (N − 1), nikdy pri orezanom okraji (rešerš Q1 · 3).
- Rozloženie je **gilotínovo rezateľné** (pozdĺžne rezy medzi pásmi cez celú dĺžku → priečne rezy v páse → dorez nižších dielcov). Volá sa **„rozloženie
  heuristiky"**, nie minimum (C6).
- **Najväčší zvyšok platne:** kandidáti = spodok `[0, used_h + k, Lu, Wu − used_h − k]` (ak kladný), koniec každého pásu `[used_l + k, y, Lu − used_l − k, h]`
  (ak kladný) **a nad každým nižším dielcom v páse `[x, y + w + k, l, h − w − k]`** (ak kladný — audit F9 a Codex review #416: pri pásoch s vysokým
  a nízkym dielcom je práve tento odrezok najväčší, napr. dielce `100 × 2000` + `2600 × 100` → zvyšok `2600 × 1895`, nie `70 × 2000`); vyhráva najväčšia
  plocha, pri zhode menšie `y`, potom menšie `x`. Súradnice v použiteľnej ploche (po oreze). Ide o najväčší **samostatný** obdĺžnik z týchto kandidátov —
  susedné odrezky sa nezlučujú (priznané v kontrakte).

### 2.5 Výsledok (kontrakt; kompaktný tvar zvolí implementátor, obsah je záväzný)
- Poradie materiálov podľa `material_id`. Pre každý nákupný materiál: `material_id`, `sheet_size [L, W]`, `usable [Lu, Wu]`, `trim` (použitý), `fallback`, `uni`,
  `invalid_params`, **`sheets`** (počet platní), `utilization` (plocha zaradených / (`sheets` × L × W); pri 0 platniach **chýba**), `placed_count`,
  **`rejected_rows`** (počet vyradených RIADKOV) s ich dôvodmi, `thickness_conflict`, `duplak_link_missing`, `blocked` (dôvod alebo `nil`), `doubled_pieces`
  (počet prírezov z duplákov), zoznam **zdrojových riadkov** (`key`, `names`, `l`, `w`, `count`, `doubled`), **platne** (poradie, umiestnenia `[odkaz na
  zdrojový riadok, n, x, y]`, využitie platne v % z celej plochy platne, najväčší zvyšok alebo `nil`), **nezaradené** (`[odkaz, n, dôvod]`, dôvod
  `oversize` | `needs_rotation` | `no_usable_area`) a **`upper_bound`** = `true` **len** keď `!fallback && !uni && !invalid_params && !blocked &&
  !thickness_conflict && !duplak_link_missing && nezaradené.empty? && rejected_rows == 0` (C2, audit B1/B2/F5/F6).
- Na vrchnej úrovni použité `params` a `rejected_without_material`. Výpočet **nikdy nevyhodí výnimku** pre dátový problém (neplatný riadok, formát, parametre).
- Slovník pre UI (NP-3) aj rozpočet (NP-4): „N platní (horná hranica)" smie povedať len výsledok s `upper_bound`; neúplný = „N platní pre zaradené dielce —
  celkový počet neznámy"; `fallback`/`uni` = „orientačne N platní pri formáte …" (texty nie sú súčasťou modulu).

### 2.6 Dokumentácia a štandard
- **STANDARD:** §3.3 :375-376 — plán orientuje cez tú istú prípravu riadka ako VEPO (výmenu robí stále len `VepoExport.oriented`); §7.1 za :961 —
  „`sheet_size[0]` = dĺžka platne = smer kresby dekoru platne"; **§11** — nová krátka podkapitola „Nárezový plán (výpočet, nie exportér)" s kontraktom
  (vstup = VEPO príprava, bez otáčania, orez podľa typu, prídavok dupláku, `upper_bound`, UNI/fallback orientačne) a výslovne, že §11.1 („exportéry
  nepočítajú rozmery") sa naň nevzťahuje, lebo **nič neexportuje**; **§12** :1586-1588 — nesting vyňať z „mimo scope v1" (primitívny plán je vo V1,
  optimalizácia ostáva mimo).
- `sheet_estimate.rb` hlavička :5-7 prepísať (fáza 2 = samostatný modul `SheetLayout`, odhad ostáva ako porovnanie a predvolená cena).
- `docs/architecture/outputs.md` — nový odsek `### sheet_layout.rb` (vedľa `sheet_estimate.rb`), `docs/ARCHITEKTURA.md` — riadok v tabuľke Core;
  `vepo_export.rb` odsek doplniť o `prepare_row`. Zastaraný komentár kontraktu `build` :185-187 (chýba `shortened`, `display_labels`) opraviť.
- Načítanie: `main.rb` za `validation` (:508) a pred `budget` (:517); `tests/helper.rb` do zoznamu; bodový guard poradia podľa `test_st1a_core.rb:84-90`.

## 3 · Scope OUT (vedome nerobí)

Nastavenia prerezu, orezu a prídavku (NP-2) · zmena Kontroly `oversize` (NP-2) · sekcia Štúdia, payload a kreslenie (NP-3) · rozpočet a XLSX (NP-3, NP-4) ·
otáčanie dielcov (N8, neskôr po porovnaní s VEPO) · optimalizácia (viac heuristík, hľadanie poradia) · akákoľvek zmena VEPO CSV, LOGu alebo Kontroly.

## 4 · Testy a DoD

Nová sada `tests/pure/test_sheet_layout.rb` (+ charakterizačné VEPO testy **pred** extrakciou, §2.1). **Testy funkcie `fits_rect?` (desatinné vstupy,
tolerancia) sú oddelené od testov `compute` (vstup po zaokrúhlení na celé mm)** — audit F8.
1. **Presné očakávané rozloženia (golden) nad `compute`:** (a) DTD 2800 × 2070, orez 10, prerez 5: 9 × 720 × 560 = 1 platňa, pásy po 3 (x = 0 / 725 / 1450;
   y = 0 / 565 / 1130); 10. kus → 2 platne · (b) hranica po zaokrúhlení: `2780 × 2050` sa zmestí, `2781 × 100` nie (`oversize`); `2780,4` sa zaokrúhli na 2780
   a zmestí sa (dokumentuje poradie zaokrúhlenie → kontrola) · (c) dva dielce `l1 + 5 + l2 = 2780` v jednom páse, o 1 mm viac → nový pás · (d) duplák
   `600 × 400`, `quantity` 2, `multiplier` 2 → 4 obdĺžniky `620 × 420` zdrojového materiálu, duplákový materiál v pláne nie je · (e) pracovná doska
   4100 × 600 bez orezu: `2400 × 600` sa zmestí · (f) first-fit do skoršej platne (pás aj nový pás na prvej platni, kde je miesto) · (g) najväčší zvyšok:
   dielce `100 × 2000` + `2600 × 100` na 2800 × 2070 → zvyšok `2600 × 1895` (audit F9).
2. **Testy `fits_rect?`:** tolerancia 0,1 mm na oboch osiach · `allow_rotation` true/false · `needs_rotation` vs. `oversize` (dielec bez smeru `2000 × 2500`
   v pláne nezaradený `needs_rotation`, pri `allow_rotation: true` sa zmestí; `2900 × 2100` `oversize` v oboch).
3. **Vlastnosti nad `compute`:** nezávislosť od poradia vstupu (permutácie) · dolná hranica `sheets >= ceil(Σ plocha zaradených / ((Lu + DIM_TOL) × (Wu + DIM_TOL)))`
   (zosúladené s toleranciou — audit F8) · `sheets <= placed_count` · žiadne prekryvy, všetko v použiteľnej ploche s toleranciou, medzery ≥ prerez medzi
   susedmi v páse a medzi pásmi · `width` sa prehodí raz (ako VEPO), nič iné sa neotáča · orez tak veľký, že nič neostane → `no_usable_area`, `sheets` 0,
   `utilization` chýba · neplatné parametre → `invalid_params`, bez výnimky · UNI a fallback → `upper_bound` false.
4. **Neúplnosť a ochrana vstupu:** vyradený riadok (neznáma ABS, hrúbka ≤ 0, bez materiálu) → `rejected_rows` / `rejected_without_material` · **zdravý riadok
   + chybný riadok s počtom 0** → `rejected_rows` 1 a `upper_bound` false (audit F6) · riadok nie Hash, NaN/nekonečný rozmer či hrúbka, zlé hrany → `invalid_row`
   bez výnimky; dĺžka 0,1 → `zero_after_rounding` (audit F4) · dve hrúbky pri jednom nákupnom materiáli → `thickness_conflict` (audit B1) · katalógový
   duplák bez väzby v riadku → `duplak_link_missing` na zdrojovom materiáli, žiadne domyslenie (audit B2) · `blocked: {all:}` aj per materiál → `blocked`,
   `upper_bound` false (audit F5) · `prepare_row` = rovnaké vyradenia a texty ako `build`.
5. **Výkon:** syntetická deterministická zákazka ~2000 obdĺžnikov v 5 materiáloch — výpočet pod 1 s headless (čas vypísať do výstupu testu).
6. **Mutácie (min. 8, zapísať do PR):** prerez aj pred prvým dielcom pásu · bez prerezu medzi pásmi · prídavok dupláku len raz / vôbec · nový pás len na
   poslednej platni · bez tolerancie · orez aj pri PD · vyradené riadky ignorované v `upper_bound` · radenie bez úplného kľúča · zvyšok bez kandidátov nad
   dielcami · plán s otáčaním pri `none`.
7. VEPO sady bez zmeny očakávaní (vrátane nových charakterizačných); celá headless sada a všetky JS sady zelené.

## 5 · Riziká

Refaktor `build` zmení text alebo poradie chýb (zlaté vzorky to chytia) · plán a VEPO sa rozídu v prijatí riadka (jedna funkcia + test zhody) · plávajúca
čiarka na hraniciach (jedna tolerancia) · meno modulu a výsledku zamenené s `cut_*` z D-143 (meno `SheetLayout`).

## 6 · Smoke pre Michala

NP-1 nemá viditeľnú zmenu (modul nie je napojený) — smoke prichádza s NP-3. V PR len stručne: „výpočet existuje, plugin sa nemení".

## 7 · Checklist uzáveru

Bump VERSION (2×) + všetky `?v=` · headless + všetky JS sady zelené · odseky `docs/architecture/outputs.md` (nový `sheet_layout.rb`, doplnený `vepo_export.rb`)
+ riadok `docs/ARCHITEKTURA.md` · STANDARD §3.3, §7.1, §11, §12 · prepis `SYSTEM/STAV.md` · odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md` ·
PLAN blok 2: riadok NP-1 s ✅ a číslom PR · tento package do `SYSTEM/zdroje/bloky/NAREZ/PACKAGE_NP1_JADRO.md` (s dodatkom nálezov auditu).

## Nálezy auditu návrhu (Codex `gpt-6-astra`, 28.9.2026) — zapracované

Surový výstup: `AUDIT_NP1_2026-09-28.md` (implementátor ho pridá do priečinka bloku zo scratchpadu `AUDIT_NP1_raw.md`, bez riadkov s ID relácie).
Verdikt: **2 BLOCKER · 7 FIX · 0 NOTE — všetky prijaté.**

| # | Nález | Kde je zapracovaný |
|---|---|---|
| B1 | jeden `material_id` nezaručuje jednu nákupnú hrúbku (18 a 36 mm na jednej platni) | §2.2 „Hrúbka vs. nákupný materiál", `thickness_conflict`, §4.4 |
| B2 | chýbajúca väzba dupláku sa potichu zmení na obyčajnú platňu | §2.2 „Väzba dupláku katalóg × snapshot", `duplak_link_missing`, §4.4 |
| F3 | testy nedokazujú bajtovú nemennosť celého LOGu ani poradie chýb | §2.1 — charakterizačné testy **pred** extrakciou |
| F4 | NaN/nekonečno/`nil`/zlé hrany vyhodia výnimku; 0,1 mm prejde ako 0 | §2.2 „Ochrana vstupu plánu", `invalid_row`, `zero_after_rounding`, §4.4 |
| F5 | poškodený `cut_size` stratí príznak v agregácii | §2.3 vstup `blocked:`, §4.4 (kto `blocked` skladá — NP-3/NP-4) |
| F6 | počet vyradených kusov nestačí (počet 0, záporné) | §2.2 (a) `rejected_rows` = riadky, §2.5, §4.4 |
| F7 | `fits?` nezdieľa celú prípravu pre Kontrolu | §2.4 `purchase_rect` + `fits_rect?(allow_rotation:)` |
| F8 | hraničné testy odporujú zaokrúhleniu a tolerancii | §4 — oddelené testy `fits_rect?`, hranice po zaokrúhlení, dolná hranica s toleranciou |
| F9 | najväčší zvyšok vynecháva odrezky pod nižšími dielcami | §2.4 kandidáti nad nižšími dielcami, §4.1 (g) |

**Z Codex review PR #416 (mockup) navyše:** Kontrola pri dielci bez smeru ďalej otáča, plán nie (`fits_rect?(allow_rotation:)`, dôvod `needs_rotation`) ·
najväčší zvyšok aj nad nižším dielcom (= F9) · texty nesľubujú, že VEPO použije rovnako alebo menej platní (kontrakt §2.5 hovorí len o rozložení Noxunu).

## Nálezy krížového auditu a rešerše, ktoré rieši NP-1

Surové výstupy: `CROSS_AUDIT_CODEX_2026-09-28.md` (C…), `CROSS_AUDIT_GROK_2026-09-28.md` (G…), `RESERS_OUTSIDE_IN_2026-09-28.md` (Q…).

| Nález | Verdikt | Kde v tomto package |
|---|---|---|
| C1 · prídavok dupláku (N7) chýba | berieme | §2.2 (c) — každá vrstva `(l + 2p) × (w + 2p)` |
| C2 · počet bez nezaradených / pri fallbacku a UNI nie je horná hranica | berieme | §2.5 `upper_bound` |
| C6 · formálny popis heuristiky, nie „minimum" | berieme | §2.4 |
| C7 · vstup cez `Bom.compute` | potvrdenie | §2.2 |
| C8 · tri kroky vstupu, neznámy smer neotáčať | berieme (N8 — neotáča sa nič) | §2.2 (a)–(c) |
| C9 · jedna pravda „zmestí sa" pre plán aj Kontrolu | berieme | §2.4 `purchase_rect` + `fits_rect?` (Kontrola v NP-2) |
| C14 · zoznam nezaradených, politika otáčania a orezu | berieme | §2.3, §2.4, §2.5 |
| G1 · otáčanie môže podhodnotiť počet | berieme (N8) | §2.2 (b) |
| G3 · rovnaké vyradenia a zaokrúhlenie ako VEPO; vyradený riadok = neúplný plán | berieme | §2.1, §2.2 (a), §2.5 `rejected_rows` |
| G6 · orez, po ktorom nič neostane, nesmie zhodiť výpočet | berieme | §2.4 `no_usable_area`, §2.3 `invalid_params` |
| Q1 · 3 · prerez len medzi dielcami, dielec presne na použiteľnú šírku sa zmestí | berieme | §2.4, §4.1 (c) |
| Q1 · 5 · JS knižnice nedávajú gilotínové rozloženie | neberieme knižnice | výpočet v Ruby |
| Q4 · formát 2800 × 2070 aj pre HDF, duplák = plné prírezy | potvrdenie | §2.3 |

Ostatné nálezy rieši NP-2 (C4, G4 — nastavenia, Kontrola), NP-3 (C12, C13, G8 — sekcia) a NP-4 (C3, C10, C11, G5, G7 — ceny; vyradené riadky
a neúplný plán = cena z odhadu podľa O11); C5 rozhodol Michal (N10), G2 Michal zamietol (N9).

## Doplnenie počas implementácie (29.9.2026)

**Pokyn orchestrátora (po sonde pre NP-2) — zapracované v NP-1:**
- `purchase_rect` vracia **geometriu** (`l`, `w`, `usable`, `trim`, `grain`) aj pri `ok: false`, keď dôvod s rozmermi nesúvisí — VEPO odmietnutie
  (neznáma ABS, chybná hrúbka, počet), `thickness_conflict`, `duplak_link_missing` (tam vrstva **bez** prídavku na **materiáli riadku**). Nevracia ju
  pri `invalid_row`, `zero_after_rounding`, nekladnom rozmere a bez materiálu. Dôvod: Kontrola `oversize` v NP-2 musí hodnotiť nadrozmer aj pri súbežnej
  chybe ABS či hrúbky (`tests/pure/test_validation.rb:164-171` čaká 2 RED). `compute` sa nemení; plán pripisuje riadok cez nový kľúč
  `plan_material_id` (pri dupláku vždy zdroj), `material_id` je materiál geometrie.
- Kontrola otáča **všetko okrem `length`/`width`** (dnešné `fits_on_sheet?`: prázdny aj neznámy smer = obe polohy) — namiesto `grain == 'none'` z §2.4
  platí verejná `SheetLayout.rotation_allowed?(grain)`; plán z nej odvodzuje `needs_rotation` vs. `oversize`. `fits_rect?(allow_rotation: true)` skúša obe polohy.
- Zaokrúhlenie rozmerov má jedinú definíciu `VepoExport.rounded_dims` (volá ju `prepare_row` aj geometria odmietnutého riadka; bajty CSV bez zmeny).

**Výklad implementátora (kompaktný tvar zvolený podľa §2.5):**
- Hrúbka (B1): obe strany cez `VepoExport.commercial_thickness` (18,6 aj 19 na zázname 18 = tá istá platňa); vrstvy dupláku sa nekontrolujú („vrstvy
  majú hrúbku zdroja"); záznam bez hrúbky = bez kontroly.
- Parametre: platné len reálne konečné čísla ≥ 0 (reťazec „5" je nečíselný); chýbajúci kľúč alebo `nil` = predvolená hodnota; kľúče String aj Symbol.
- `utilization` materiálu aj platne v **percentách** (1 desatinné miesto); súradnice a zvyšok zaokrúhlené na 0,001 mm.
- Riadky s `thickness_conflict` / `duplak_link_missing` nie sú v `rejected_rows` (tie počítajú len prijatie riadka), ale v zozname `conflicts`
  a v príznakoch — `upper_bound` ich vylučuje oboma cestami.
- `blocked` zasiahne materiál aj cez materiál jeho riadku (duplákový `material_id` zablokuje zdroj); prázdny dôvod = text `blocked`.
