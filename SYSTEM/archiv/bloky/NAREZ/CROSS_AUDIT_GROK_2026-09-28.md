> Surový výstup krížového auditu bloku (Grok Build `grok-4.7`, len čítanie repa + web, 28.9.2026, beh 10 min 38 s) — bez úprav (odstránené len úvodné stavové vety nástroja); ako sa naloží s nálezmi, uvedie package dávky, ktorá ich rieši.

# Nárezový plán cross audit — Grok grok-4.7 — 2026-09-28

## Nálezy

| # | Závažnosť | Kategória | Tvrdenie | Dôkaz (súbor:riadok alebo URL + dátum) | VERIFIED/UNVERIFIED | § konceptu | Odporúčanie | Prácnosť S/M/L |
|---|---|---|---|---|---|---|---|---|
| 1 | BLOCKER | MISSED CONSTRAINT | Policové FFDH s kerfom len medzi dielcami (N−1) a medzi pásmi je gilotínovo rezateľná horná hranica **pre tie obdĺžniky a tie zámky, ktoré naozaj balí**. Pás cez celú použiteľnú dĺžku je priečny rez. Otočenie `none` vie počet platní znížiť pod to, čo z CSV nareže píla: súbor nemá údaj „smie sa otočiť“, po výmene `width` je dĺžka os dekoru. Nákup podľa otočeného plánu potom podhodí materiál aj porez. | `vepo_export.rb:141-150`; `SYSTEM/VEPO_KONTRAKT.md:17-25`; `SYSTEM/STANDARD.md:374-376`; OpenCutList 2026-09-28, docs nižšie (bez smeru otáča kvôli lepšiemu uloženiu; cieľ je menej platní, nie horná hranica) | VERIFIED | §3, otázka 1 | Nákupný počet rátaj z rozloženia bez ďalšieho otočenia (iba výmena `width` ako VEPO). Otočenie `none` nechaj ako poznámku „ak píla dovolí otočiť, vyjde to z menej“, kým porovnanie s reálnou objednávkou (N5) neukáže, že VEPO tie dielce otáča. V teste „zmestí sa“ znamená výšku pásu aj zvyšnú dĺžku; kľúč triedenia pri `none` je pevný pred uložením. | M |
| 2 | BLOCKER | MISSED CONSTRAINT | Výnimka „každá pracovná doska bez orezu, lebo hrany sú hotové“ nesedí. Hotová hrana je kompakt a PD s postformingom. PD s ABS sa olepuje ako bežná doska, orez potrebuje. Spoločné pravidlo s `oversize` by tie dielce nechalo na plnom formáte a pri zapnutých cenách podhodilo počet platní. Zástena ako formát výrobku bez orezu sedí. | `materials.rb:733-746`; `validation.rb:540-549` | VERIFIED | §2 orez podľa typu | Bez orezu len kompakt, PD postforming a zástena. PD s podtypom ABS a PD bez podtypu orez dostanú. | S |
| 3 | FIX | MISSED CONSTRAINT | Vstup plánu nie je totožný s tým, čo odíde do VEPO. VEPO vyradí aj neznámu ABS a zlú hrúbku, rozmery zaokrúhli na celé mm. Duplák v CSV ostáva 1 kus hrúbky 36; rozvinutie `množstvo × násobič` na zdrojovú dosku je správny **nákup**, nie kópia CSV. `cut_size` je už v dĺžke a šírke riadku. Neznámy smer VEPO neotáča; dnešná kontrola ho otočiť dovolí. | `vepo_export.rb:157-164, 211-219, 240, 348-354`; `SYSTEM/STANDARD.md:1064-1067`; `validation.rb:527-533` | VERIFIED | §2, otázka 2 | Plán vynechá tie isté riadky čo VEPO (aj ABS a hrúbku) a balí rozmery po `.round`. Duplák naďalej rozviň na zdroj. Jedna pravda o neznámom smere = neotáčať, ako VEPO. | S |
| 4 | FIX | MISSED CONSTRAINT | `oversize` s orezom je správna jedna pravda pre dielce, ktoré kontrola už meria. Diera: tolerancia 0,1 mm v kontrole, plán ju nemá; text nálezu by ďalej ukazoval surový formát, hoci rozhodol orez; UNI a chýbajúci formát kontrola mlčí; ten istý model na dvoch počítačoch s iným orezom dá iný RED. Kľúč nálezu meniť netreba. Kerf do jedného dielca nepatrí. Export naďalej nezastavovať. | `validation.rb:46, 341-356, 515-537` | VERIFIED | P4, §4, otázka 3 | Rovnaká funkcia „zmestí sa“ pre plán aj `oversize`, vrátane tolerancie. Veta nálezu nech uvedie použiteľný rozmer po oreze. UNI a záložný formát ostanú bez tohto RED. | M |
| 5 | FIX | MISSED CONSTRAINT | Nová exportná brána netreba. Diera v peniazoch je pád na odhad: počet z neúplného plánu (platne bez dielca, ktorý sa nezmestil) vie byť nižší než odhad aj než realita, a ponuka pre zákazníka neuvidí ani počet, ani dôvod. Prepínač by vyzeral ako úspech. | `budget.rb:207-222, 255-258`; `SYSTEM/STANDARD.md:1541-1545` | VERIFIED | P2, P5, §4, otázka 4 | Pri `incomplete`, UNI a záložnom formáte ostáva množstvo z odhadu, riadok dostane `estimated` a poznámku, že „plán: N“ nie je nákupný počet. Číslo z čiastočného rozloženia do ceny nedávaj. V XLSX rozpočtu nech je veta aj dôvod. | S |
| 6 | FIX | MISSED CONSTRAINT | Prerez a orez patria do globálnych skalárov. Zvýšenie verzie súboru nastavení starý plugin nezastaví: číslo sa uloží a nikde neporovná, neznáme polia sa pri uložení zahodia a po novom štarte sa vrátia predvolené 5 mm a 10 mm. | `supplier_settings.rb:43, 75-81, 130-133, 353-364` | VERIFIED | P3, §4, otázka 5 | Whitelist, predvolené hodnoty a rozsahy. Orez, po ktorom vyjde použiteľná strana ≤ 0, je neúplný plán, nie pád výpočtu. Vo výsledku plánu nech ostanú použité čísla. Porovnanie s najmenšou platňou až pri výpočte. | S |
| 7 | NOTE | GOOD CUSTOM SOLUTION | Prepínač per zákazka bez `BUDGET_STD` 3 nie je bezpečný: starý plugin by kľúč zahodil a cena by potichu spadla na odhad. Globálny prepínač by zmenil všetky zákazky naraz. Porez aj montáž dnes berú jedno množstvo platní; bez rozdelenia prepínač zdvihne aj montáž. | `budget_store.rb:69`; `budget.rb:104, 359-368, 834-842`; `production_core.rb:1958, 2374-2380, 3183, 3261, 3436`; `studio_dialog.rb:1620`; `SYSTEM/STANDARD.md:1560-1561` | VERIFIED | P2, §4–§5, otázka 6 | Nechaj `BUDGET_STD` 3 a reťaz R-14. V package rozdeľ množstvo pre materiál a porez od množstva pre montáž. Plán počítaj v `budget_payload` vedľa odhadu a v `Budget.compute`, keď odhad nedostane. | M |
| 8 | NOTE | CAD PRECEDENT | Id sekcie `cut` nechaj. Nový kód nepomenúvaj `cut_*` (to je rozmer do nárezu). Jedna platňa na šírku sekcie je príliš vysoká, miniatúry sedia. Dve témy menia len výberovú farbu, tmavý režim nie je. Prah „takmer prázdna posledná platňa“ v koncepte chýba. | `studio.js:107`; OpenCutList a CutList Optimizer, 2026-09-28 (obrázok platne, neumiestnené dielce, nie klik v SVG do 3D) | VERIFIED | P1, otázka 7 | Guard testy neaktívnej položky meň v NP-2 naraz. SVG kreslí okno z čísiel, triedy s tokenmi `--nx-*`. Prah poslednej platne (podiel alebo jeden dielec) zapíš do package. Výber v modeli ostáva zo zoznamu, nie z obrázka. | S |
| 9 | NOTE | NO ACTION | Rez NP-1 → NP-2 → NP-3 sedí: jadro a testy, potom obraz, potom peniaze. Zápis do modelu je len prepínač (NP-3). Audit dávaj NP-1 a NP-3. | `sheet_estimate.rb:5-7`; `SYSTEM/STANDARD.md:1588` | VERIFIED | §5, otázka 8 | NP-1 smie sprísniť `oversize` skôr, než je sekcia vidno; veta nálezu nech spomenie orez. Komentár, že fáza 2 vymení vnútro odhadu, po samostatnom module uprav. §12 STANDARD zmeň v NP-1. | S |
| 10 | NOTE | CAD PRECEDENT | OpenCutList, CutList Optimizer, Optimik aj MaxCut minimalizujú odpad a predávajú nižší počet platní ako nákup. Koncept správne drží jednu rezateľnú hornú hranicu a ich kód nepreberá. Pri zhodnom kerfe, oreze a zámku dekoru plán naddimenzuje nákup oproti ich výsledku (bezpečné). Podhodí ho pri otočení `none` alebo pri odpustenom oreze (nálezy 1 a 2). | OpenCutList docs + GPLv3 LICENSE, 2026-09-28; `cutlistoptimizer.com` (cut thickness, orientation matters, unable to fit); `optimik.com` (optimalizácia, odpočet hrany); `maxcutsoftware.com` (optimalizovaný počet do ceny). Licencie: OpenCutList GPLv3 (vzory áno, kód nie); ostatné proprietárne (len vzory) | VERIFIED | otázka 9 | Do cien ide horná hranica z nálezu 1, nie „najlepšie uloženie“. Vzorec kerfu N−1 v zdroji OpenCutList overený nie je (pozri medzeru). | S |

## Nenašiel som (RESEARCH GAP)

- Či VEPO pri dielci `none` otáča, a či k hotovému rozmeru pridáva prídavok pred olepením. Kontrakt hovorí len to, že pásku odráta sám. Číslo prídavku ani prepínač otočenia vo verejnom popise VEPO nie je.
- Prídavok na zlepenie dupláku nad dva plné prírezy. Žiadne mm.
- V zdrojáku OpenCutList vetu „na páse je presne N−1 rezov“. Dokumentácia má hrúbku kotúča a orez okolo surovej platne, nie počet rezov.
- Verejné pravidlo, či VEPO orezáva pracovnú dosku s ABS hranou.

## Zdroje (len URL, ktoré si naozaj otvoril)

- https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams
- https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams/sheet-goods
- https://raw.githubusercontent.com/lairdubois/lairdubois-opencutlist-sketchup-extension/master/LICENSE
- https://www.cutlistoptimizer.com/
- https://www.optimik.com/
- https://maxcutsoftware.com/

## Kontrola voči repu

- `noxun_engine/core/vepo_export.rb:141-150` (iba `width` sa vymení), `:157-164` a `:211-219` (neznáma ABS von), `:240` (`.round`), `:348-354` (materiál, rozmer, počet)
- `noxun_engine/core/validation.rb:46` (0,1 mm), `:341-356` (UNI bez oversize), `:515-537` (bez orezu; neznámy smer sa točí)
- `noxun_engine/core/materials.rb:733-746` (bez ABS len kompakt a PD postforming)
- `noxun_engine/core/budget.rb:207-222` (`estimated` len pri záložnom formáte), `:255-258`, `:359-368` (porez aj montáž z jedného počtu), `:104`, `:834-842`
- `noxun_engine/core/supplier_settings.rb:43`, `:353-364` (verzia sa neporovnáva, cudzie polia sa zahodia)
- `noxun_engine/core/budget_store.rb:69` (`BUDGET_STD` 2)
- `noxun_engine/ui/production_core.rb:1958`, `:2374-2380`, `:3183`, `:3261`, `:3436`
- `noxun_engine/ui/studio_dialog.rb:1620`
- `noxun_engine/ui/js/studio.js:107` (id `cut`)
- `noxun_engine/core/sheet_estimate.rb:5-7`
- `SYSTEM/VEPO_KONTRAKT.md:17-25`
- `SYSTEM/STANDARD.md:374-376`, `:1064-1067`, `:1541-1545`, `:1560-1561`, `:1588`
