# PACKAGE NP-4 · Nárezový plán — ceny podľa plánu (blok 2, posledná dávka)

> **Autorita:** rozhodnutia Michala N1–N11 (`SYSTEM/zdroje/bloky/NAREZ/ROZHODNUTIA_MICHALA_2026-09-28.md` — N4 VEPO účtuje celé tabule) a schválený mockup
> (`MOCKUP_NAREZ_2026-09-28.html`, obrazovka **C**, body **O5** prepínač per zákazka predvolene vypnutý, **O6** porez podľa plánu / montáž z odhadu,
> **O10** chýbajúci formát a UNI = cena z odhadu, **O11** neúplný plán = cena z odhadu, export sa nezastaví). Stavia na NP-1 (`SheetLayout`), NP-2 (nastavenia,
> `layout_params` so zdrojom) a **NP-3** (plán vo všetkých 5 volajúcich `budget_payload`, serverová funkcia vety o počte, `blocked`) — pred štartom
> implementácie orchestrátor zladí názvy so zmergovaným NP-3.
> **Trieda:** audit-povinná (`BUDGET_STD` 2 → 3 = zmena schémy) · **cenová dávka** · slepá predrecenzia · **in-SU povinné** (nová akcia panela zapisujúca
> do modelu, jeden krok Späť) · `codex-po-pr`. **Verzia:** patch (po NP-3 v0.15.3 → **v0.15.4**) + `?v=` + prepis STAV.

## 0 · Sonda (main `c59f1272`, 29.9.2026)

- **`BudgetStore`** (`noxun_engine/core/budget_store.rb`): 8 dátových kľúčov :37-44, marker `budget_std` :48, `BUDGET_STD = 2` :69 (história :61-68,
  disciplína :55-59); `std_state` :164-170 (`:legacy/:current/:newer/:invalid`), hlášky :78-81; `write!` :729-762 (brána PRED `start_operation`, jedna
  operácia = údaj + `stamp_std`, výnimka → `abort`); vzor boolean kľúča `appliances_included?` :241-243 + `set_appliances_included!` :328-331. Starší plugin
  nový kľúč **nezmaže** (mutácie píšu len svoje kľúče), ale **ignoruje** → cena by ticho išla z odhadu → bump je **významový** (STANDARD dnes hovorí len
  o „tichej strate poľa").
- **`Budget`** (`noxun_engine/core/budget.rb`): `materials_section` :194-231 (`mnozstvo = plates_of(g)` :199, :255-258 `count_max.round(6).ceil`; poznámky :203-211;
  `estimated` len pri fallbacku :222); `services_section` :358-388 — **jeden `plates_total`** (:359) živí porez (:367) aj montáž (:363-364, poznámka :371);
  `normalize_state` :800-816; payload :120-147 (`appliances_included` :138, `budget_std` :146).
- **`ProductionCore`**: `apply_budget_op` :3063-3082 (13 vetiev), `BUDGET_OP_STATUS` :3147-3156, `budget_payload` :2406-2420 (rescue → `nil`), 5 volajúcich
  (`studio_dialog.rb:1620`, `production_core.rb:1958`, :3215, :3293, :3468); brány `do_budget_xlsx` :3191-3262 a `do_cp_xlsx` :3272-3343 (`budget_std_block`
  :3221/:3299 pred `savepanel`). `price_refresh_targets` číta len `stale.items` odhadu — plán sa ho netýka.
- **UI** (`noxun_engine/ui/js/budget.js`): `budSectionHtml` :572-602, vzor checkboxu Spotrebičov :578-585 (`label.bappl`, `stopPropagation`, `data-bud="appl_included"`)
  → obsluha :2208-2235 → `budSend` :1879-1898 (poistka R-14 :1885); `BUD_STD_OFF` :240-242, `budStdDisable` :277-289; `budMaterialRow` :665-676 (bunka množstva :670);
  CSS `.bappl` `studio.html:420-422`, tooltip `.nxtip` :84-95, `.qtag` v produkcii nie je (mockup :405-407).
- **XLSX rozpočtu** (`core/xlsx_writer.rb:360-487`): POČET = `mnozstvo` (:443), MATERIÁL = `nazov · poznamka` (:453-458) — zmena prejde sama. **Cenová ponuka**
  (`core/cp_export.rb`): materiál `[1,'set']` (:293-299), poznámku nečíta (:312-319); zmení sa len **suma** → materiál môže preklopiť cez prah 150 € (:204-211);
  porez ide do „Nábytkovej zostavy" (:150-151), „Montáž a výroba" (:258-262) ostáva z odhadu.
- **Kľúče plán ↔ rozpočet:** duplák s väzbou je v odhade aj v pláne pod zdrojom; katalógový duplák **bez väzby** ostáva v odhade pod vlastným ID, plán ho pripíše
  zdroju s `duplak_link_missing` → riadok rozpočtu bez záznamu v pláne (NP-3 most: veta „plán neúplný — duplák bez väzby").
- **Testy, ktoré sa musia zmeniť:** `tests/pure/test_s1b1_vazba.rb:300` (`BUDGET_STD` 2), `tests/pure/test_st1c_rozpocet.rb:178-179` (13 vetiev → 14),
  `tests/pure/test_r14_budget_std.rb:102-121` (+`set_plan_prices!`, názov :342), `tests/js/test_r14_budget_std.js:157-158, :245-246` (+`plan_prices`, kontrola
  prítomnosti ovládača), in-SU `su_runner.rb` `st1c_budget` :15726-15755 (+ operácia), komentáre „12 operácií" (:15691, :15734, :27830), `R14_KEYS` :8414-8416.

## 1 · Cieľ

V Rozpočte → Materiál prepínač **„ceny podľa plánu"** pre zákazku (predvolene **vypnutý** — staré aj nové zákazky majú dnešné ceny, kým ho človek nezapne).
Zapnutý: množstvo platní materiálu = **počet z nárezového plánu**, ale **len** pre materiál, ktorého plán je spoľahlivý; ostatné ostávajú na dnešnom odhade
a riadok povie prečo; **porez** ide za množstvom materiálov, **montáž** ostáva z odhadu. Exporty sa nezastavujú (O11).

## 2 · Scope IN

### 2.1 Dáta zákazky (BudgetStore) — `BUDGET_STD 3`
- Nový kľúč `budget_plan_prices` (natívny bool; chýba = `false`), čítačka, riadok v `state`, `set_plan_prices!(enabled)` cez `write!` (jeden krok Späť, marker
  v tej istej operácii); `normalize_state` a ozvena v payloade (`plan_prices`); op `plan_prices {enabled}` v `apply_budget_op` + text `BUDGET_OP_STATUS`
  („Ceny podľa plánu zapnuté/vypnuté.").
- `BUDGET_STD = 3` (história v komentári), R-14 brána bez zmeny kontraktu: marker 3 zapíše **prvá mutácia rozpočtu akéhokoľvek druhu** (tak ako pri 2) —
  **starší plugin** (napr. Luciino PC s v0.15.3 a starším) potom zákazku v Rozpočte needituje a nevyrobí XLSX rozpočtu ani ponuky (banner). Priznať v STANDARD,
  PR a reporte (aktualizovať obe PC).

### 2.2 Výpočet (Budget)
- **Cenová spôsobilosť materiálu** (jedna funkcia, testovaná samostatne): prepínač zapnutý **a** plán pre materiál riadku existuje **a** `upper_bound == true`
  **a** zdroj parametrov je spoľahlivý (`:file` alebo `:backup` — nie `:seed_fallback`, `:unreadable`, `:newer_file`) **a** výpočet plánu prebehol (plán nie je
  `nil`). Inak je materiál nespôsobilý s **dôvodom** (poradie a vety zladiť s mockupom C a s funkciou vety NP-3): plán neúplný · formát chýba · materiál
  neurčený (UNI) · duplák bez väzby · nastavenia sa nepodarilo načítať · plán nedostupný.
- Spôsobilý materiál: `mnozstvo = sheets` z plánu, riadok nesie `qty_source: 'plan'`, pôvodný odhad (`estimate_qty`) a v poznámke vetu „cena podľa plánu"
  (mockup — viditeľné aj v XLSX); nespôsobilý: `mnozstvo = plates_of(g)` (dnes), `qty_source: 'estimate'`, poznámka „<dôvod> — cena z odhadu". Pri vypnutom
  prepínači sa riadok **nemení vôbec** (ani poznámka o zdroji — ostáva len veta o pláne z NP-3).
- **Služby (O6):** porez = Σ `mnozstvo` riadkov Materiálu (pôjde za plánom sám); montáž = Σ **odhadu** (`plates_of`) — dva súčty; pri vypnutom prepínači
  rovnaké čísla ako dnes. Poznámky porezu a montáže podľa mockupu C (napr. „porez: 9 platní podľa plánu", „montáž z odhadu 10 platní").
- `Budget.check`: bez nového nálezu (O11 — nespôsobilý materiál nie je chyba).

### 2.3 UI (Rozpočet — mockup C)
- Checkbox **„ceny podľa plánu"** v `<summary>` sekcie Materiál (vzor Spotrebičov :578-585, `stopPropagation`), tooltip `.nxtip` s vetou z mockupu (čo robí,
  že VEPO účtuje celé tabule, že nespôsobilé materiály ostávajú na odhade, že počet VEPO sa môže líšiť); pridať do `BUD_STD_OFF`.
- Značka v bunke množstva: **„podľa plánu"** / **„z odhadu"** (len pri zapnutom prepínači) — nová trieda `.qtag` s tokenmi `--nx-*` (obe témy) → bump `?v=`.

### 2.4 Dokumentácia
- STANDARD §11.3 (desať kľúčov, 13 mutácií, disciplína „kľúč, ktorého **ignorovanie** mení cenu", nový odsek `BUDGET_STD 3`), §11.2 (množstvo z plánu pri
  zapnutom prepínači), §11.4 (plán v cene — podmienky spôsobilosti); `docs/architecture/outputs.md` (budget.rb, budget_store.rb, cp_export.rb, xlsx_writer.rb),
  `docs/architecture/ui-lifecycle.md` (Rozpočet — prepínač), hlavička `core/sheet_layout.rb:23-24`.

## 3 · Scope OUT

Predvolene zapnutý prepínač · globálny prepínač · zmena montáže podľa plánu · nová exportná brána · zmena cenovej ponuky mimo súm · otáčanie v pláne (N8) ·
ručný prepis množstva materiálu.

## 4 · Testy a DoD

1. **Zlatý test:** vypnutý prepínač (aj chýbajúci kľúč) = **rovnaké** čísla, riadky a oba XLSX ako pred dávkou (existujúce testy rozpočtu bez zmeny očakávaní).
2. **Zapnutý:** zmiešaná zákazka (spôsobilý DTD, neúplný materiál, chýbajúci formát, UNI, duplák s väzbou aj bez väzby, `blocked`, `seed_fallback`) → správne
   `mnozstvo`, `qty_source`, dôvody a vety; porez = Σ materiálu, montáž = Σ odhadu; XLSX nesie počet aj vetu; ponuka mení len sumy (prah 150 € preklopenie).
3. **BudgetStore/R-14:** `set_plan_prices!` = 1 operácia = 1 Späť, marker 3; novší marker (4) → mutácia odmietnutá pred operáciou; legacy/2 → prvá mutácia
   zapíše 3; `test_r14` zoznam mutácií +1; `test_s1b1_vazba`, `test_st1c_rozpocet` (14 vetiev).
4. **JS:** checkbox v hlavičke, `budSend` s `plan_prices`, `BUD_STD_OFF` (ovládač musí existovať), značky `.qtag`, tooltip; render pri vypnutom = bez značiek.
5. **In-SU (brána mergu):** `st1c_budget` + operácia `plan_prices` (zápis zmení stav + 1× Späť ho vráti), `R14_KEYS` + `budget_plan_prices`; beh
   `scripts\run_su_tests.ps1 -CloseWhenDone` na hlave pred PR.
6. **Mutácie (jedna na každú novú/zmenenú vetvu, min. 8):** plán aj pre nespôsobilý materiál · montáž z plánu · porez z odhadu · bez kontroly zdroja parametrov ·
   bez kontroly `upper_bound` · marker bez bumpu · prepínač mimo `BUD_STD_OFF` · značka aj pri vypnutom.
7. Celá headless sada + všetky JS sady + in-SU zelené.

## 5 · Riziká

Cena v zákazke sa zmení len po vedomom zapnutí (predvolene vypnuté) · Luciino PC po prvej mutácii rozpočtu v novom plugine zákazku needituje (priznané, report) ·
materiál preklopí v ponuke cez prah 150 € · dve pravdy medzi rozpočtom, XLSX a ponukou (jeden výpočet v `Budget`, 5 volajúcich cez NP-3).

## 6 · Smoke pre Michala

Rozpočet → Materiál: zapni „ceny podľa plánu" → riadky so značkou „podľa plánu"/„z odhadu" a dôvodom, porez sa zmení, montáž nie; Späť prepínač vráti;
XLSX rozpočtu nesie počet a vetu; ponuka zmení len sumu; vypni → dnešné čísla.

## 7 · Checklist uzáveru

Bump VERSION (2×) + `?v=` · headless, JS, **in-SU** · STANDARD §11.2/11.3/11.4 · outputs.md, ui-lifecycle.md · STAV prepis · KRONIKA · PLAN NP-4 ✅ + PR ·
package + surový audit do priečinka bloku. **Po mergi uzáver bloku 2** (release, minor verzia, smoke checklist).

## Nálezy krížového auditu, ktoré rieši NP-4

| Nález | Verdikt | Kde |
|---|---|---|
| C3 · bez exportnej brány len s cenovým kontraktom, ktorý zlyhá bezpečne | berieme — cenová spôsobilosť per materiál, pád na odhad (O11) | §2.2 |
| C10 · porez a montáž z jedného súčtu | berieme — dva súčty (O6) | §2.2 |
| C11 · `BUDGET_STD` 3 | berieme | §2.1 |
| G5 · nespôsobilý materiál na odhade s vetou aj v XLSX | berieme | §2.2 |
| G7 · verzia dát, porez vs. montáž, plán aj v `Budget.compute` | berieme (plán cez NP-3 do všetkých volajúcich) | §2.1, §2.2 |

## Nálezy auditu návrhu (Codex `gpt-6-astra`, 29.9.2026, nad main `c59f1272` + NP-3 `a997efc9`) — zapracované (prednosť pred textom vyššie)

Surový výstup: `AUDIT_NP4_2026-09-29.md` (zo scratchpadu `AUDIT_NP4_raw.md`, bez riadkov s ID relácie). Verdikt: **3 BLOCKER · 2 FIX · 1 NOTE — prijaté.**

| # | Nález | Zapracovanie |
|---|---|---|
| B1 | čakajúca mutácia rozpočtu (fronta `budget.js:1893`) nesie len op + hodnotu, identitu dokumentu doplní až pri odoslaní; `budDocSwitched` (:1868) frontu bez modalu nezruší → `plan_prices(true)` zo zákazky A odíde do zákazky B | **každá** položka fronty nesie identitu dokumentu (a `gen`) z okamihu kliknutia; zmena dokumentu frontu **zruší aj bez modalu**; server odmietne mutáciu s cudzou identitou (existujúci guard); regresný JS test (A → payload B → nič neodíde do B) — oprava platí pre všetky mutácie rozpočtu |
| B2 | poškodený primár + **novšia** záloha: pôvod `newer_file` sa prepíše na `backup` (`supplier_settings.rb:299`) → spôsobilé | kompatibilita verzie nastavení sa nesie **nezávisle** od zdroja `file/backup` (napr. `version_ok`); cenová spôsobilosť vyžaduje `version_ok` **a** zdroj `file`/`backup`; test poškodený primár + záloha `std 3` |
| B3 | `source=file` skryje predvolené hodnoty za **prítomné neplatné** hodnoty (`supplier_settings.rb:590`, napr. `trim_mm="broken"` → 10) | normalizácia zaznamená **neplatné prítomné** skaláre (napr. `repaired: [kľúče]`) oddelene od **chýbajúcich** (legacy súbor bez nových kľúčov = dovolené predvolené hodnoty); `layout_params` to posunie ďalej; pri opravených kľúčoch prerezu/orezu/prídavku je plán pre cenu **nespôsobilý** („nastavenia prerezu a orezu sú poškodené — cena z odhadu") a Kontrola pridá ORANGE (vzor NP-2); test |
| F4 | export stavia rozpočet nanovo — keď plán pri exporte zlyhá, XLSX má odhad, UI ešte ukazuje plán | bez novej brány: poznámka riadku v XLSX nesie dôvod pádu na odhad (už kontrakt), **statusová veta po exporte** vymenuje materiály, ktoré pri exporte išli na odhad, a panel sa po exporte obnoví (push) — test prechodu spoľahlivý plán → chyba pri exporte pre oba XLSX |
| F5 | po Späť ostane checkbox a ceny zapnuté, kým človek neklikne „Obnoviť" (Undo iba označí okno ako neaktuálne) | smoke a dokumentácia: **„Späť, potom Obnoviť"** (existujúci životný cyklus Štúdia sa nemení); in-SU overí stav modelu aj marker po Späť |
| N6 | R-14 návrh správny; NP-3 už ruší `upper_bound` pri vyradeniach, `blocked`, fallbacku/UNI a neviazanom dupláku | potvrdenie — druhá sada cenových kontrol sa nerobí, spôsobilosť stavia na `upper_bound` + zdroj/verzia/oprava nastavení + plán nie nil |

## Doplnenie počas implementácie (implementátor NP-4, 29.9.2026)

Skutočné API zmergovaného NP-3 (`dc9a179f`) sedí s package; overené v kóde a kde sa realizácia líši, platí kód:

- **Plán v rozpočte:** `ProductionCore.layout_for` → `SheetLayout.compute` + `params_source` + `blocked_all`; `budget_payload` si plán spočíta sám, keď ho volajúci
  nedá (všetkých 5 volajúcich). NP-4 k plánu pridáva **`params_version_ok`** a **`params_repaired`** (z `control_layout` ← `SupplierSettings.layout_params`).
  Veta o počte = `SheetLayout.count_phrase`/`budget_note` (NP-3) — ostáva **nezmenená**, veta o cene ide **za ňu** do tej istej poznámky.
- **Cenová spôsobilosť = `SheetLayout.price_basis(plan, material_id, sheets)`** (jedna funkcia, testovaná samostatne) → `{eligible, sheets, reasons, note, tip}`.
  Prepínač nerieši ona, ale `Budget.materials_section(…, plan_prices:)`; obal `Budget.price_basis` je fail-soft **smerom k odhadu**.
  Dôvody navyše oproti §2.2: **„nastavenia uložil novší plugin"** (zdroj `newer_file` alebo `params_version_ok == false` — audit B2) a **„nastavenia prerezu
  a orezu sú poškodené"** (audit B3); **neznámy zdroj aj chýbajúci príznak verzie = „nastavenia sa nepodarilo načítať"** (fail-closed). Poradie vo vete:
  plán nedostupný · duplák bez väzby · nastavenia … · formát chýba · materiál neurčený · plán neúplný („formát chýba, plán neúplný — cena z odhadu" ako mockup).
- **B2:** `layout_params` počíta `version_ok` z pôvodu **pred** `refine_origin` (poškodený primár + záloha `std 3` → zdroj `backup`, `version_ok: false`).
- **B3:** `normalize_supplier` zaznamená neplatné **prítomné** skaláre do odvodeného `repaired_scalars` (chýbajúci kľúč aj `null` nie); `layout_params[:repaired]`
  = kľúče prerezu/orezu/prídavku. Navyše **`read_doc` súbor s opraveným skalárom plánu seed-mergom nezapisuje** — inak by prvé načítanie legacy súboru
  (chýbajúce riadky) neplatnú hodnotu potichu prepísalo predvolenou a dôkaz by zmizol; opraví ho vedomé uloženie v Nastaveniach. Kontrola: ORANGE
  `layout_settings|repaired` (`Validation.check_layout_repaired`).
- **B1 (fronta):** položka fronty `{op, extra, doc, gen}` z okamihu kliknutia a odošle sa **s touto `gen`** (push po mutácii rozpočtu generáciu nedvíha, takže
  bežný ďalší zápis prejde; po zmene modelu/dokumentu ho server odmietne ako zastaraný). `budDocSwitched` vyhodí zápisy iného dokumentu pri **každej**
  zmene (aj bez modalu), `budAfterPush` cudzí zápis neodošle ani cez poistný timer.
- **F4:** `ProductionCore.plan_export_note(budget)` — pri zapnutom prepínači status oboch cenových exportov povie „· z odhadu (nie podľa plánu): A, B, C a N
  ďalšie" a okno sa **obnoví** (`repush` pred statusom). Pri vypnutom sa status ani počet pushov nemení.
- **Služby — vety podľa mockupu C4** (nie príklady z §2.2): porez „platne z Materiálu (N podľa plánu, M z odhadu)" (počty **materiálov**), montáž
  „10 platní × 5,8 m² · z odhadu". Pri vypnutom prepínači ostávajú dnešné poznámky (porez bez poznámky).
- **UI:** checkbox v `<summary>` + tooltip `.nxtip` (`BUD_PLAN_TIP`, s vetou „Po Späť klikni na Obnoviť" — audit F5); `details.bsec` pri hover/fokuse
  tooltipu povolí `overflow: visible` (`:has`), inak by sekcia tooltip orezala. Značka `.qtag` má `title` = serverový `qty_tip` (vzor mockupu).
- **Zlatý test** je charakterizačný odtlačok (vzor KOV-H1): `tests/fixtures/np4_golden/` vygenerované z mainu **pred** zmenou (prvý commit vetvy),
  `tests/pure/test_np4_golden.rb` porovná payload, XLSX rozpočtu a hárok cien ponuky s vypnutým aj chýbajúcim prepínačom.
- **In-SU:** `st1c_plan_prices` (v `st1c_budget`) — zápis cez `do_budget` zapne prepínač aj marker 3, rozpočet má zdroj množstva a porez = Σ Materiálu,
  1× Späť vráti prepínač aj marker; `R14_KEYS` + `budget_plan_prices`.
- **Drobnosti NP-3** (slepá delta #420, 2× P3) v samostatnom commite: tooltip chipu duplákov „2 ks (hotový 820 × 580) = 4 prírezy 840 × 600" a test
  escapovania mena riadku.
- **Predrecenzia (0× P1, 1× P2, 4× P3) — opravené pred PR:** P2 karta Nárezového plánu berie „v rozpočte N" z hotového rozpočtu toho istého pushu
  (`sheet_layout_payload(…, budget)` → `budget_qty`/`budget_src`) a tooltip súhrnu už netvrdí, že rozpočet vždy počíta z odhadu · P3-2 „a 1 ďalší /
  2–4 ďalšie / 5+ ďalších" · P3-3 Nastavenia zvýraznia poškodený skalár a „Uložiť" ho zapíše aj bez úpravy (veta nálezu povie postup) · P3-4 odmietnutie
  čakajúceho zápisu po mutácii, ktorá zdvihla generáciu, je bezpečný smer — len priznané (ui-lifecycle, KRONIKA, PR) · P3-5 in-SU overí montáž =
  Σ odhadu a pri spoľahlivých nastaveniach aspoň jeden materiál podľa plánu (inak INFO riadok).
