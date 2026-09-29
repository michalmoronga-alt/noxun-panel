> Surový výstup krížového auditu bloku (Codex `gpt-5.6-sol`, s prístupom k repu, 28.9.2026, beh ~17 min) — bez úprav (odstránený len riadok s ID relácie); ako sa naloží s nálezmi, uvedie package dávky, ktorá ich rieši. Odkazy na `KONCEPT_NP_v1_2026-09-28.md` smerujú na koncept v1 vložený celý za čiarou v `CROSS_AUDIT_PROMPT_2026-09-28.md` (samostatný súbor v repe nie je; čísla riadkov sa môžu líšiť).

# Nárezový plán cross audit — Codex / gpt-5.6-sol — 28. 9. 2026

**Verdikt: NOT SOUND — 5 BLOCKER, 6 FIX, 3 NOTE.** Najväčšie riziko je podhodnotenie objednávky: aktuálne N7 vyžaduje prídavok dupláku, ktorý koncept nepočíta, a neúplný plán sa stále označuje ako „horná hranica“.

## Nálezy

| # | Závažnosť | Kategória | Tvrdenie | Dôkaz (súbor:riadok alebo URL + dátum) | Stav | § konceptu | Odporúčanie | Prácnosť |
|---|---|---|---|---|---|---|---|---|
| 1 | BLOCKER | MISSED CONSTRAINT | Aktuálne rozhodnutie N7 prikazuje obe vrstvy dupláku zväčšiť o +10 mm na každej strane. Koncept ich rozkladá v hotovom rozmere; pri hraničnom rozložení tak podhodnotí počet platní aj cenu. | `ROZHODNUTIA_MICHALA_2026-09-28.md:20`; `KONCEPT_NP_v1_2026-09-28.md:40-41`; `sheet_estimate.rb:47-54` | VERIFIED | §2, Q1–Q2 | NP‑1 musí rozmery vrstvy zväčšiť pred orientáciou a fitom; kontrakt má výslovne potvrdiť výsledok `L+20 × W+20` a pokryť hraničnými testami. | M |
| 2 | BLOCKER | MISSED CONSTRAINT | Počet bez nezaradených dielcov nie je horná hranica celej zákazky. To isté platí pre fallback a UNI — ide len o výsledok hypotetického formátu. | `KONCEPT_NP_v1_2026-09-28.md:11-20,38-39,56-59`; [OpenCutList – unplaced parts](https://docs.opencutlist.org/whats-new/in/version-6.0) (28. 9. 2026) | VERIFIED | §1, §3, Q1, Q4 | Pri `incomplete`, `fallback` alebo `uni` nikdy nepísať „N platní — horná hranica“, ale „N platní pre zaradené dielce; celkový počet neznámy“. | S |
| 3 | BLOCKER | MISSED CONSTRAINT | „Bez exportnej brány“ je bezpečné iba s fail-closed cenovým kontraktom. `incomplete` dnes pokrýva len nezmestiteľný dielec; VEPO môže odmietnuť aj hrúbku alebo neznámu ABS. Chybný počet by cez spoločný rozpočet prešiel do oboch XLSX. | `vepo_export.rb:197-220`; `budget.rb:96-112`; `production_core.rb:2374-2387,3159-3205,3240-3289` | VERIFIED | §4, Q4 | Server musí per materiál odvodiť cenovú spôsobilosť: reálny formát, nie UNI, platné nastavenia, nula preskočených/odmietnutých/nezaradených kusov. Ak to nevie dokázať, oba cenové exporty zastaviť. | M |
| 4 | BLOCKER | MISSED CONSTRAINT | Whitelist nestačí. `SupplierSettings.normalize` zachová vyššie `std`, ale vyhodí neznáme polia; následný zápis ich starším pluginom potichu zničí. | `supplier_settings.rb:43-45,216-229,353-392` | VERIFIED | §4, Q5 | Zvýšiť STD a pridať doprednú read/write bránu obdobnú `BudgetStore`. Samotný bump bez odmietnutia zápisu problém nerieši. | M |
| 5 | BLOCKER | MISSED CONSTRAINT | Poradie NP‑1 → NP‑2 → NP‑3 je rozumné, ale „uzáver hneď po NP‑3“ vynecháva záväznú N5 skúšku na reálnej objednávke VEPO. | `ROZHODNUTIA_MICHALA_2026-09-28.md:18`; `KONCEPT_NP_v1_2026-09-28.md:78-86` | VERIFIED | §5, Q8 | Zachovať tri dávky, ale blok uzavrieť až po N5 smoke: rovnaké dielce, reálny formát, objednaný počet a vysvetlené odchýlky. | S |
| 6 | FIX | GOOD CUSTOM SOLUTION | Policové FFDH vie vytvoriť realizovateľné gilotínové rozloženie, nie však optimum. Koncept neurčuje výšku pásu pri druhej orientácii `none` ani bezpečný skalárny tie-breaker; surový `Bom.row_key` obsahuje vnorené pole alebo `nil`. | `KONCEPT_NP_v1_2026-09-28.md:49-62`; `bom.rb:1663-1675`; [OpenCutList – guillotine layouts](https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams) (28. 9. 2026) | VERIFIED | §3, Q1 | Formalizovať orientáciu pred radením, výšku pásu, všetky kerf nerovnosti, toleranciu a kanonický textový tie-breaker. Výsledok volať „rozloženie heuristiky“, nie minimum. | M |
| 7 | NOTE | GOOD CUSTOM SOLUTION | Pre obyčajné dielce je vstup cez `Bom.compute` správny: `cut_size` má jednu autoritu a hotový rozmer s ABS je voči fyzickému prírezu konzervatívny. Druhý sken modelu netreba. | `bom.rb:1378-1399`; `vepo_export.rb:153-165`; `docs/architecture/outputs.md:575-579` | VERIFIED | §2, Q1–Q2 | Túto cestu zachovať; N7 aplikovať až ako pomenovanú nákupnú transformáciu dupláku. | S |
| 8 | FIX | MISSED CONSTRAINT | Tvrdenie „presne to, čo ide do VEPO“ nie je úplné: VEPO má ďalšie odmietnutia, duplák ostáva vo VEPO jeden 36/54 mm diel, zatiaľ čo plán ho rozvinie na zdrojové vrstvy, a dnešná Kontrola otáča aj neznámy smer dekoru. | `vepo_export.rb:126-165,197-220`; `STANDARD.md:1051-1067`; `validation.rb:527-533` | VERIFIED | §2, Q2–Q3 | Pomenovať tri kroky: prijatie riadka, VEPO reprezentácia, nákupné obdĺžniky. Len `none` smie rotovať; neznámy smer musí ostať fixný. | M |
| 9 | FIX | MISSED CONSTRAINT | `oversize` potrebuje tú istú funkciu použiteľného formátu ako plán. N6 sa dá mapovať na existujúce typy, ale chýba správanie pri `2×orez ≥ rozmer platne`, neplatnom kerfe a zmene globálneho nastavenia. | `validation.rb:512-537`; `materials.rb:122-160`; `supplier_settings_dialog.rb:236-273,787-800` | VERIFIED | §2, §4, Q3, Q5 | Jedna čistá autorita pre typ materiálu, formát, orez a toleranciu; neplatný výsledok označiť ako neúplný a cenovo nespôsobilý. Otestovať refresh po uložení nastavení. | M |
| 10 | FIX | MISSED CONSTRAINT | Rozpočet dnes používa jeden `plates_total` súčasne pre porez aj montáž. Ak sa jednoducho nahradia materiálové počty plánom, zmení sa aj montáž napriek zámeru P2. | `budget.rb:350-371` | VERIFIED | §1 P2, Q6 | Prenášať oddelene počet pre materiál/porez a pôvodný odhad pre montáž; testovať zmiešanú zákazku, kde len niektoré materiály používajú plán. | M |
| 11 | NOTE | ALREADY EXISTS | `BUDGET_STD` 3 je správna a najjednoduchšia bezpečná cesta. Prepínač ovplyvňuje cenu a jeho strata v staršom plugine nesmie prejsť potichu. | `budget_store.rb:45-69,154-180,729-793`; `STANDARD.md:1549-1571` | VERIFIED | §4, Q6 | Použiť existujúci R‑14 marker, jednu Undo operáciu a existujúce brány oboch cenových exportov; aktualizácia druhého PC je nutná. | S |
| 12 | FIX | MISSED CONSTRAINT | Štúdio posiela plný payload pri každom pushi a prepnutie sekcie je lokálne. Všetky pozície SVG preto zaťažia aj používateľa, ktorý nárez neotvorí; Ruby časový limit to nemeria. | `studio_dialog.rb:1589-1623` | VERIFIED | §1, §4, Q7 | NP‑2 musí mať limit veľkosti JSON, čas serializácie a DOM/SVG test veľkej zákazky. Overiť obe témy, výšku okna a scroll; detail načítať kompaktne alebo generačne strážene až na požiadanie. | M |
| 13 | NOTE | NO ACTION | Kolízia ID `cut` s D‑143 `cut_*` nie je reálna: ide o ID sekcie v JS/Ruby whiteliste verzus výrobné dátové kľúče. `cut` je už rezervovaný v navigácii. | `studio.js:62-65,93-108`; `studio_dialog.rb:52`; `test_st1a_studio.rb:39-48` | VERIFIED | Q7 | Bez premenovania; iba doplniť `cut` do Ruby/JS zrkadiel a aktualizovať konkrétne guard testy. | S |
| 14 | FIX | CAD PRECEDENT | Precedensy explicitnejšie oddeľujú kerf/trim, rotáciu, nezaradené kusy a rozmery prírezu: OpenCutList (GPLv3 — vzory áno, kód nie), CutList Optimizer, Optimik a MaxCut (proprietárne — iba vzory). MaxCut navyše viaže cenu na nový výsledok optimalizácie. | [OpenCutList](https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams/sheet-goods), [licencia](https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension/blob/master/LICENSE), [CutList Optimizer](https://www.cutlistoptimizer.com/), [Optimik](https://www.optimik.com/Files/Help/ImportExportPrint.pdf), [MaxCut trim](https://knowledge.maxcutsoftware.com/help/override-global-sheet-trim), [MaxCut rotácia](https://knowledge.maxcutsoftware.com/help/understanding-panel-rotation-settings-in-maxcut), [MaxCut cena](https://knowledge.maxcutsoftware.com/help/setting-material-cost-slash-price) — všetko otvorené 28. 9. 2026 | VERIFIED | Q9 | Prevziať iba vzory správania: samostatný zoznam nezaradených, zrozumiteľnú politiku rotácie/orezu a označenie „počet tohto úplného rozloženia“. Plánovú cenu použiť iba pri úplnom reálnom formáte. | M |

## Nenašiel som (RESEARCH GAP)

- Nenašiel som verejný kontrakt VEPO pre presnú definíciu orezu, kerfu pri obvodovom reze, povolené rotácie ani prepočet jeho optimalizácie.
- Nenašiel som verejný zdroj potvrdzujúci presne pravidlo `N−1` kerfov pri všetkých výrobných postupoch; musí byť pomenované ako konvencia Noxunu a overené N5.
- Okrem N7 som nenašiel potvrdené prídavky na prefrézovanie, vady dekoru alebo párovanie kresby. Nesmú sa vymyslieť ani univerzalizovať.
- V repe zatiaľ nie je reálna N5 fixtúra ani zmeraný limit veľkosti/renderu payloadu.

## Zdroje

- [https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams/sheet-goods](https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams/sheet-goods)
- [https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams](https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams)
- [https://docs.opencutlist.org/whats-new/in/version-6.0](https://docs.opencutlist.org/whats-new/in/version-6.0)
- [https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension/blob/master/LICENSE](https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension/blob/master/LICENSE)
- [https://www.cutlistoptimizer.com/](https://www.cutlistoptimizer.com/)
- [https://www.optimik.com/Files/Help/ImportExportPrint.pdf](https://www.optimik.com/Files/Help/ImportExportPrint.pdf)
- [https://knowledge.maxcutsoftware.com/help/override-global-sheet-trim](https://knowledge.maxcutsoftware.com/help/override-global-sheet-trim)
- [https://knowledge.maxcutsoftware.com/help/understanding-panel-rotation-settings-in-maxcut](https://knowledge.maxcutsoftware.com/help/understanding-panel-rotation-settings-in-maxcut)
- [https://knowledge.maxcutsoftware.com/help/setting-a-minimum-size-for-input-panels](https://knowledge.maxcutsoftware.com/help/setting-a-minimum-size-for-input-panels)
- [https://knowledge.maxcutsoftware.com/help/setting-material-cost-slash-price](https://knowledge.maxcutsoftware.com/help/setting-material-cost-slash-price)

## Kontrola voči repu ← súbor:riadok

- Produkčný kód, `STANDARD` a architektúra zodpovedajú `main 68aef64e`; dokumentačný HEAD je `de88281f`.
- Koncept bol auditovaný pri SHA‑256 `CE2DBF7…D0BD`.
- Rozhodnutia sa počas behu externe zmenili: N6/N7 sú necommitnuté, SHA‑256 `8CB833E4…E0C`. Ak Grok bežal pred touto zmenou, jeho audit môže oprávnene N7 neobsahovať.
- Overené autority: `sheet_estimate.rb:39-94`, `bom.rb:1378-1399,1605-1675`, `vepo_export.rb:126-220`, `validation.rb:512-537`.
- Overené cenové a kompatibilitné cesty: `budget.rb:96-112,194-230,350-388`, `budget_store.rb:45-180,729-793`, `supplier_settings.rb:43-45,216-229,353-392`.
- Audit nič v repe nezmenil; existujúce externé zmeny v `SYSTEM/PLAN.md`, `SYSTEM/DOGFOODING.md` a rozhodnutiach ostali nedotknuté.


