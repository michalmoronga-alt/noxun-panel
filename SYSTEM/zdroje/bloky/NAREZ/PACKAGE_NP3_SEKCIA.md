# PACKAGE NP-3 · Nárezový plán — sekcia Štúdia + poznámka v Rozpočte (blok 2)

> **Autorita:** rozhodnutia Michala N1–N11 (`SYSTEM/zdroje/bloky/NAREZ/ROZHODNUTIA_MICHALA_2026-09-28.md`) a **schválený mockup** (`MOCKUP_NAREZ_2026-09-28.html`,
> obrazovky **A, B, C** — body O1–O4, O10, O11); kontrakt výsledku plánu = odsek `sheet_layout.rb` v `docs/architecture/outputs.md` (NP-1, v0.15.1);
> nastavenia a pôvod parametrov = NP-2 (`SupplierSettings.layout_params` so zdrojom `:file | :backup | :seed_fallback | :newer_file`, v0.15.2 — ak merge NP-2
> zmení API, orchestrátor package pred štartom zladí). Dispozície nálezov krížového auditu na konci.
> **Trieda:** UI dávka + napojenie výpočtu na push Štúdia a na poznámku rozpočtu (čísla cien, porezu ani montáže sa **nemenia**) → bez povinného auditu
> (orchestrátor spustí bežný audit návrhu kvôli veľkosti), **slepá predrecenzia povinná** (nový ovládací prvok UI, > 300 riadkov), `codex-po-pr`. In-SU
> netreba (sekcia len číta; výber v modeli ide existujúcou cestou `nx_select`) — ak implementácia siahne na zápis do modelu, zastaviť.
> **Verzia:** patch (po NP-2 v0.15.2 → **v0.15.3**) + všetky `?v=` + prepis `SYSTEM/STAV.md`.

## 0 · Fakty (z `FAKTY_Z_KODU_2026-09-28.md` časť B a NP-1; implementátor pred prácou overí proti mainu s NP-2)

- **Neaktívna položka** `{ id:'cut', ic:'scissors', t:'Nárezový plán', disabled:'fáza 2 — …' }` (`noxun_engine/ui/js/studio.js:107-108`); sekcia = 3 zrkadlá
  + Ruby autorita: `SECTIONS` (`noxun_engine/ui/studio_dialog.rb:52`), `STUDIO_SECTIONS` (`studio.js:64-65`), `NXShell.STUDIO_SECTIONS` (`noxun_engine/ui/js/shell.js:349-353`);
  `SEC_META` (`studio.js:142-177`) pre `cut` záznam nemá. Id **`cut` ostáva** (Codex C13 — kolízia s `cut_*` z D-143 nie je reálna; nový kód sa nepomenúva `cut_*`).
- **Jeden plný push** `push_state(bump:)` (`studio_dialog.rb:1598-1733`): `fresh_collect` → `Bom.compute` → `SheetEstimate` (:1601-1609) → `budget_payload` (:1620)
  → `control_payload` (:1621) → `data` → `NX.setStudio`. Prepnutie sekcie je klientske; bežná úprava modelu len zožltí „Obnoviť". **Nová sekcia berie dáta
  z už hotového zberu** (druhý sken modelu zakázaný, `ui-lifecycle.md:3288-3295`).
- **`ProductionCore.budget_payload`** (`production_core.rb:2374-2388`) volá **5 miest**: push Štúdia (`studio_dialog.rb:1620`), VEPO kontrola (`production_core.rb:1958`),
  XLSX rozpočtu (:3183), XLSX ponuky (:3261), prepočet cien (:3436). Rozpočet: riadok materiálu `mnozstvo = ceil(count_max)` (`budget.rb:252-258`),
  `poznamka` skladá server (:203-211); UI `budNoteHtml` (`budget.js:660-663`) a XLSX (`xlsx_writer.rb:453-458`) poznámku zobrazia; **cenová ponuka poznámku
  nepoužíva** (`cp_export.rb:312-319`) a počty platní nikdy neukáže.
- **Kreslenie:** Štúdio dnes SVG nemá; vzor reťazcového SVG + `viewBox` v `preview.js:869-957`; farby **cez CSS triedy s tokenmi `--nx-*`** (téma-bezpečné,
  vzor `panel.css:2137`), farba dekoru cez `rgbHex` (`studio.js:180-220`). Dve témy (NOXUN/Lucia), tmavý režim nie je. Telo sekcie ≈ 828 px, vertikálny priestor
  je vzácny (`SYSTEM/PLAN.md` trvalé pravidlo).
- **Výber v modeli:** `sketchup.nx_select(JSON{gen, parts_key, focus_inspector})` (`studio.js:1691-1695`) → `ProductionCore.do_select` vetva `parts_key`
  (`production_core.rb:793-807`) = **všetky rovnaké kusy riadku** (O3). Klient posiela identitu (kľúč riadku), nikdy pids.
- **Guardy, ktoré sa zmenia** (zoznam z faktov B §1): `test_st1a_studio.rb:41-60, :1060-1066` („práve 1 `disabled:`"), `test_st1a_studio.js:45, :203-206, :213-218`,
  `test_uid3_klikatelnost.js:100-101, :114`, `test_st1b_kontrola.rb:336`, `su_runner.rb:16322`, zrkadlá v `test_s1a2_sekcia.rb`, `test_st1c_rozpocet.rb`, `test_st3a_hw.rb`,
  `test_st3b_rules.rb`, `test_st3c_tpl.rb`, `test_st2a_mat.rb`, `test_st1c_ponuka.rb`, `test_uid3_klikatelnost.rb`, `test_stale_obnovit.rb:158-185` (počet `refreshBtnHtml`).
  Docs: `ui-lifecycle.md:2381-2384, 2428-2429` (+ „DVANÁSŤ sekcií" je zastarané), `docs/UI_DIZAJN.md:1398-1402`, `SYSTEM/zdroje/ui20/UI20_KONTRAKT.md:575`,
  `SYSTEM/STAV.md:16`.

## 1 · Cieľ

Štúdio → **Nárezový plán** ožije podľa schváleného mockupu (A, B) a Rozpočet → Materiál dostane v poznámke riadku **„plán: …"** (mockup C, vypnutý stav);
**ceny, porez ani montáž sa v NP-3 nemenia** (prepínač „ceny podľa plánu" = NP-4). Výpočet je **jeden** — ten istý výsledok vidí sekcia, poznámka v Rozpočte
aj XLSX rozpočtu.

## 2 · Scope IN

### 2.1 Jeden výpočet plánu na zber (server)
- Nová funkcia v `ProductionCore` (pracovne `layout_for(collected, bom, smap, edges)`): `SheetLayout.compute(bom[:rows], sheets: smap, edge_thicknesses: <z edges_map
  ako v NP-2 — chyba katalógu ABS nezhodí výpočet>, params: SupplierSettings.layout_params[:params], blocked: <pozri nižšie>)` + pripojí `params_source`.
- **`blocked`** (kontrakt NP-1, audit F5): `{'all' => dôvod}`, keď by nad **tým istým zberom** zastavil VEPO export `cut_stop` (poškodený rozmer do nárezu, D-143)
  alebo `newer_config_stop` (skrinka z novšieho pluginu) — volá sa tá istá funkcia ako v exporte (jedna pravda), nie kópia podmienok.
- Volá sa **raz na push Štúdia** a **v `budget_payload`** (ak jej plán nepríde, spočíta si ho sám — vzor odhadu) → všetkých 5 volajúcich má ten istý plán.
  Čas výpočtu ide do existujúceho merania pushu.

### 2.2 Payload sekcie (C12 — veľkosť a čas)
- Kľúč payloadu napr. `sheet_layout`: pre každý materiál súhrn (názov z katalógu, vzorka `rgb`, formát, `sheets`, `utilization`, príznaky, `upper_bound`, `params`,
  odhad z m² na porovnanie `count_min–count_max` zo `SheetEstimate`) + **kompaktné** rozloženie (celé čísla, polia, nie objekty; mená riadkov raz v `rows`).
- **Limit:** syntetická zákazka ~2000 obdĺžnikov → JSON celého `sheet_layout` ≤ **250 kB** a výpočet + serializácia ≤ **150 ms** headless (test vypíše čísla); ak limit
  nevyjde, detail platne (polohy) sa posiela až na požiadanie cez lazy PULL kanál (vzor `appl_card`/`tpl_preview`, `studio_dialog.rb:1679-1696`) so strážou generácie.

### 2.3 Sekcia Štúdia (mockup A, B)
- `cut` živá sekcia (nav bez `disabled`, `SEC_META`, zrkadlá Ruby/JS/shell, `REFRESH_STATUS`, `renderTools`/`renderBody`, vlastný súbor `ui/js/sheet_layout.js`
  načítaný za `studio.js` so `?v=`; guardy z §0 upraviť na „žiadna neaktívna položka").
- **Lišta:** „Obnoviť" (zdieľaný `refreshBtnHtml`) + chip „prerez 5 · orez 10 · duplák +10" (hodnoty z `params`, desatinná čiarka) → preklik do Nastavení rozpočtu;
  pri `params_source = :seed_fallback` chip jantárový s vetou „nastavenia sa nepodarilo načítať — predvolené hodnoty".
- **Súhrnný riadok** a **karty materiálov** (zbaliteľné, stav v `localStorage` s try/catch): vzorka, názov, formát, **veta o počte podľa príznakov** (jediné miesto
  skladania vety, zdieľané s poznámkou v Rozpočte — pozri 2.4): `upper_bound` → „N platní (horná hranica)"; neúplný (nezaradené, vyradené riadky, konflikty,
  `blocked`) → „N platní pre zaradené dielce — celkový počet neznámy"; `fallback`/`uni` → „orientačne N platní pri formáte L × W"; kombinácie spolu (mockup);
  využitie %, „odhad z m²: X–Y", chipy (formát chýba · materiál neurčený · plán neúplný · bez orezu · duplák s počtom prírezov podľa násobku).
- **Malé platne** (mriežka SVG ~150–170 px): obdĺžniky dielcov, šípka kresby (po dĺžke platne), šrafovaný najväčší zvyšok, % využitia platne; farby cez CSS triedy
  s tokenmi (obe témy). **Upozornenie na poslednú platňu (O2):** materiál s ≥ 2 platňami, posledná platňa s využitím **pod 20 %** alebo s **najviac 2 dielcami** →
  jantárový riadok „Posledná platňa: N dielec(e) — <názov> <l × w> · využitie X %" + tooltip s radou; bez zvyšku veta „bez využiteľného zvyšku".
- **Nezaradené a vyradené** (červený zoznam pri karte): dôvody ľudsky — `oversize` „nezmestí sa ani otočený — hlási aj Kontrola", `needs_rotation`
  „nezmestí sa bez otočenia (plán neotáča)", `no_usable_area`, vyradené riadky s textom VEPO, konflikty hrúbky a väzby dupláku; **duplák = jeden hotový dielec**
  s počtom a rozmerom prírezov zvlášť.
- **Detail platne (B)** po kliku na malú platňu v tom istom okne (tlačidlo späť): platňa na šírku sekcie, tenký šrafovaný orez, dielce s krátkym názvom a rozmerom,
  šípka, zvyšok s rozmerom, pod ňou kompaktný zoznam dielcov platne s ikonou „oka" → `nx_select` s `parts_key` (O3, všetky rovnaké kusy) a vlastnou statusovou vetou.
- Text „VEPO optimalizuje sám a jeho počet sa môže líšiť" v tooltipe súhrnu (Codex #416 — žiadny sľub počtu VEPO).

### 2.4 Poznámka v Rozpočte a XLSX (mockup C, vypnutý stav)
- `Budget` dostane plán (cez `budget_payload`) a k `poznamka` riadku materiálu pripojí **tú istú vetu o počte** ako karta (jedna funkcia na serveri, ktorú
  použije aj payload sekcie — klient vetu neskladá, len zobrazí). Poznámka ide automaticky do XLSX rozpočtu; **množstvo, cena, porez ani montáž sa nemenia**
  (test: sumy rozpočtu a oba XLSX bez zmeny čísel oproti mainu).

### 2.5 Dokumentácia
- `docs/architecture/ui-lifecycle.md` — nový odsek sekcie Nárezový plán + oprava počtu sekcií; `docs/architecture/outputs.md` — napojenie `sheet_layout.rb`
  (push, `budget_payload`, `blocked`) a veta o poznámke v odseku rozpočtu; `docs/UI_DIZAJN.md` a `UI20_KONTRAKT.md` — žiadna neaktívna položka; STANDARD §11.4
  — plán v poznámke rozpočtu (nie v ponuke); STAV (sekcie: štrnásť živých).

## 3 · Scope OUT

Prepínač „ceny podľa plánu", porez podľa plánu (NP-4) · export/tlač plánu · klik v SVG ako výber (mimo zoznamu) · zmena Kontroly · otáčanie (N8) · ručné
presúvanie dielcov · sklad zvyškov.

## 4 · Testy a DoD

1. **Headless:** push Štúdia obsahuje `sheet_layout` z toho istého zberu (bez druhého skenu — guard) · `budget_payload` vo všetkých 5 volajúcich nesie ten istý
   plán a tú istú poznámku · `blocked` pri `cut_stop` / `newer_config_stop` → `upper_bound` false a veta „celkový počet neznámy" · veta o počte pre každú
   kombináciu príznakov (jedna funkcia) · rozpočet a XLSX bez zmeny čísel · limit veľkosti a času na syntetickej zákazke · `params_source :seed_fallback` → jantárový stav.
2. **JS:** navigácia bez neaktívnej položky, zrkadlá sekcií · render kariet, malých platní, súhrnu · upozornenie poslednej platne (hranice 19,9 % / 20 %, 2 / 3 dielce,
   len pri ≥ 2 platniach) · nezaradené s dôvodmi a duplák raz · detail platne a späť · klik na oko volá `nx_select` s `parts_key` a `gen` · chip parametrov
   a preklik · zbalenie karty prežije re-render · obe témy bez hex farieb v SVG (guard).
3. Guardy zo §0 upravené, `test_stale_obnovit` s novým počtom `refreshBtnHtml`, `?v=` pre nový JS súbor.
4. **Mutácie (min. 6):** poznámka mimo jednej funkcie · plán len v pushi, nie v `budget_payload` · prah 20 % → 30 % · upozornenie aj pri 1 platni · `blocked` ignorovaný ·
   výber s pids namiesto kľúča.
5. Celá headless sada + všetky JS sady zelené.

## 5 · Riziká

Payload a čas pri veľkej zákazke (limit + lazy PULL) · dve pravdy (sekcia vs. rozpočet vs. XLSX) — jedna funkcia vety a jeden výpočet · vertikálny priestor
(zbaľovanie, mriežka) · guardy navigácie (veľa testov naraz).

## 6 · Smoke pre Michala

Otvor Štúdio → Nárezový plán: karty materiálov, počty a malé platne; klik na platňu → detail, oko označí dielce v modeli; materiál s jedným dielcom na
poslednej platni → jantárové upozornenie; zmena orezu v Nastaveniach rozpočtu → plán sa po uložení prepočíta; Rozpočet → Materiál má poznámku „plán: …",
ceny sa nezmenili; XLSX rozpočtu nesie poznámku.

## 7 · Checklist uzáveru

Bump VERSION (2×) + všetky `?v=` · testy · docs (ui-lifecycle, outputs, UI_DIZAJN, UI20_KONTRAKT, STANDARD §11.4) · STAV prepis · KRONIKA · PLAN NP-3 ✅ + PR ·
package (+ surový audit, ak bol) do priečinka bloku.

## Nálezy krížového auditu, ktoré rieši NP-3

| Nález | Verdikt | Kde |
|---|---|---|
| C12 · celé rozloženie v každom pushi | berieme — kompaktný tvar, limit veľkosti a času, lazy PULL ako záloha | §2.2 |
| C13 · id `cut` | berieme — ostáva `cut` | §2.3 |
| G8 · miniatúry, prah poslednej platne, výber zo zoznamu | berieme (prah 20 % — O2) | §2.3 |
| C2 · „horná hranica" len pri úplnom pláne | berieme — jedna funkcia vety | §2.3, §2.4 |
| Codex #416 · sľub počtu VEPO, spojené stavy, duplák raz | berieme | §2.3 |

## Nálezy auditu návrhu (Codex `gpt-5.6-sol`, 29.9.2026) — zapracované (majú prednosť pred textom vyššie)

Surový výstup: `AUDIT_NP3_2026-09-29.md` (zo scratchpadu `AUDIT_NP3_raw.md`, bez riadkov s ID relácie). Verdikt: **4 BLOCKER · 8 FIX · 2 NOTE — prijaté.**

| # | Nález | Zapracovanie |
|---|---|---|
| B1 | `blocked` nekopíruje všetky brány VEPO — chýba `drawer_stop(scope: :kit)` (`drawer_stale` = v `.skp` chýbajú dielce) | §2.1: `blocked` = **všetky** brány, ktoré zastavia VEPO nad tým istým zberom (`newer_config_stop`, `cut_stop`, `drawer_stop(scope: :kit)` s tou istou expanziou `hw_exp`) — cez štruktúrované dôvody (F5) |
| B2 | výber nemá vykonateľnú identitu — plán drží kľúč riadku ako JSON text, `refs_for` porovnáva natívne pole; `rejected`/`conflicts` kľúč zahodia | `SheetLayout` (úprava modulu NP-1 v tejto dávke): `rows[].key` = **natívne pole** `Bom.row_key` (text len na radenie), `rejected` a `conflicts` nesú natívny kľúč; payload posiela natívny `parts_key` pre každý vyberateľný riadok (karta, detail aj červený zoznam); test ide až cez Ruby `do_select` → `refs_for` |
| B3 | duplák bez väzby: odhad ho drží pod ID dupláku, plán pod zdrojom → poznámka sa nespojí s riadkom rozpočtu | explicitný most: poznámka pre riadok rozpočtu sa hľadá podľa **materiálu riadku rozpočtu**; keď plán pre ten materiál nemá výsledok a materiál je katalógový duplák bez väzby → veta „plán neúplný — duplák bez väzby na zdrojový materiál"; `conflicts` nesú `row_material_id`; test so zmiešanou zákazkou |
| B4 | globálna neúplnosť zmizne (dielce bez materiálu len na vrchnej úrovni) | výsledok plánu a payload nesú **globálny stav** (`rejected_without_material`, `blocked all`); sekcia ukáže **banner nad kartami** („N dielcov bez materiálu — nie sú v pláne") aj pri prázdnom zozname materiálov; počty per materiál ostávajú |
| F5 | `cut_stop`/`newer_config_stop` vracajú vetu „Export sa NEVYKONAL" | rozdeliť: **štruktúrovaný dôvod** (funkcia bez exportného textu) + exportné formátovanie nad ním; plán aj export čítajú ten istý dôvod |
| F6 | generačná stráž lazy detailu nestačí | **lazy PULL sa nerobí** — detail je v plnom payloade (sonda auditu: 2000 obdĺžnikov = 83 kB, 23 ms); §2.2 fallback vypadá |
| F7 | chyba plánu nesmie zhodiť rozpočet, oba XLSX ani prepočet cien | výpočet plánu **fail-soft** s vlastným rescue: pri chybe `plan: nil` + veta „plán nedostupný" v poznámke; čísla rozpočtu nedotknuté; test s vyvolanou výnimkou v `SheetLayout.compute` |
| F8 | `params_source` len v karte → dve pravdy | pri `:seed_fallback` (a `:newer_file`, ak NP-2 také hodnoty dá) je veta **„orientačne N platní — nastavenia prerezu a orezu sa nepodarilo načítať"** (serverová funkcia vety; nikdy „horná hranica"); NP-4 to berie ako cenovo nespôsobilé |
| F9 | limit nemeria push | test meria **celý** `data.to_json` pushu (veľkosť, čas) na syntetickej zákazke a JS test render sekcie (čas, počet SVG uzlov) |
| F10 | celočíselná kompresia stratí desatiny | súradnice a rozmery v payloade na **0,1 mm** (Float s jedným desatinným miestom alebo celé desatiny s mierkou 10 uvedenou v payloade) |
| F11 | zbalenie: prvé otvorenie a DOM | predvolene otvorené: karty s problémom (neúplný, upozornenie, nezaradené) a prvá karta; ostatné zbalené; **zbalená karta SVG nevytvára**; stav v `localStorage` |
| F12 | guard „bez hexu" nedokazuje tému | guard: SVG sekcie len cez triedy s `var(--nx-*)`, bez `rgb()/hsl()`/pomenovaných farieb a inline `fill/stroke`, **výnimka** len pre vzorku farby dekoru (`rgbHex`); JS test renderu pre obe témy |
| N13, N14 | cenový šev vhodný; výkon realistický | potvrdenie |

## Doplnenie počas implementácie (implementátor NP-3, 29.9.2026)

Skutočné API NP-1/NP-2 sa od pracovných názvov package líši takto (platí kód):

- **Výpočet plánu:** `ProductionCore.layout_for(collected, bom, smap, hw_exp)` — parametre berie z `control_layout(edges_map)` (tie isté ako Kontrola,
  zdroj `SupplierSettings.layout_params` aj s pôvodom); výsledok nesie `params_source` a `blocked_all`. `budget_payload` dostal 7. parameter `layout`.
- **Štruktúrované dôvody (F5):** `newer_config_reasons`, `cut_blockers` (existoval) a `drawer_reasons(scope:)`; `newer_config_stop` a `drawer_stop` ich len
  formátujú (`export_blocked_status`) — bajty exportných hlášok sa nezmenili. `layout_block_reasons` ich spája v poradí VEPO exportu.
- **Pôvod parametrov:** NP-2 po Codex #419 pridal aj `:unreadable` — plán ho berie ako `:seed_fallback` (predvolené hodnoty → „orientačne …", jantárový chip).
  `:newer_file` a `:backup` nesú skutočné hodnoty, plán ich neoznačuje.
- **Veta a poznámka:** `SheetLayout.count_phrase(mat, unreliable:)` + `SheetLayout.budget_note(plan, material_id, sheets)` (+ `incomplete?`, `orientational?`,
  `unreliable_source?`); `Budget.compute/payload_for(sheet_layout:)`, fail-soft `Budget.layout_note`.
- **SheetLayout výsledok:** `rows` navyše `multiplier` a `grain` (dôvod „s kresbou sa neotáča" a počet hotových kusov dupláku); `rejected`/`conflicts`
  navyše `key` a `row_material_id` (B2, B3).
- **Payload sekcie:** `ProductionCore.sheet_layout_payload(plan, bom, smap, estimate)`; kľúč pushu `sheet_layout`. Súradnice ako Float na 0,1 mm (F10).
- **Oko:** `nx_select` s `parts_key` (natívny kľúč) a `origin: 'cut'` → `do_select` len vymení vetu statusu (`cut_select_status`).
- **„Existujúce meranie pushu"** neexistuje (audit F9) — meranie je v testoch (`test_np3_sekcia.rb` payload a čas, `test_np3_sekcia.js` render); push nič nemeria.
- **Chip parametrov** nesie texty mockupu („prerez 5 mm · orez 10 mm · duplák +10 mm"); pri predvolených hodnotách navyše „— nastavenia sa nepodarilo
  načítať, predvolené hodnoty".
- **Dielce bez materiálu (B4):** banner „N dielcov bez materiálu — nie sú v pláne" s menami; oko pri nich nie je.
