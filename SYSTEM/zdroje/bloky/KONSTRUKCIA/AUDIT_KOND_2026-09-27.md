> Stav: surový výsledok auditu návrhu KON-D (Codex gpt-6-astra, 27.9.2026, 9,7 min) — nálezy sú zapracované v [PACKAGE_KOND_CHLADNICKOVA.md](PACKAGE_KOND_CHLADNICKOVA.md) (Scope IN a sekcia Audit návrhu); nie autorita.

Overené na čistom `main`, commit `4be63120b68dba7f24203093d6e7fb54ea2832ab`. KON-B posudzujem podľa plánovaného kontraktu so schémou 21. **1 BLOCKER, 3 FIX-IN-KOND, 2 NOTE.** Súbory som nemenil; overenie zahŕňalo zdrojový kód a výpočtové sondy v pamäti, nie SketchUp smoke.

1. **BLOCKER — Migrácia môže automaticky prepísať poškodenú knižnicu obsahom zálohy alebo núdzových predvolieb.**  
   Pri poškodenom primári vráti `JsonFileStore` potichu `.bak`. Ak má záloha STD 6, navrhnutá migrácia z nej zapíše nový primár STD 7 — bez rozlíšenia, že pracuje so starším obsahom. Druhý scenár: platný JSON `{std:6, templates:null}` vstúpi do náhrady `build_predefined`, následne dostane chladničkový seed a uloží sa. **Samostatný zoznam seedu teda nezaručuje jeho neprítomnosť v celej núdzovej ceste.** Ide o existujúcu slabinu, ktorú nový bump aktivuje. Pred migračným zápisom treba pod zámkom overiť zdravie a tvar dokumentu; poškodený primár so zálohou ponechať bez zápisu. Doplniť oba regresné scenáre a oddeliť ich od obnovy pri úplne chýbajúcom primári.  
   Dôkaz: `templates.rb:417`, `templates.rb:427`, `json_file_store.rb:126`; existujúca ochrana `json_file_store.rb:62`.

2. **FIX-IN-KOND — Nové dvere bez smeru otvárania dostanú výnimku určenú starým dátam.**  
   Návrh F1/F2 neuvádza `direction`. Chýbajúci smer zostane neprítomný a kontrola ho považuje za legacy: nevznikne upozornenie ani označenie neurčeného smeru. Načítanie šablóny neprechádza vetvou `userAdd`, ktorá toto pri bežne pridaných dverách zabezpečuje. Doplniť obom dverám explicitný stav „neurčený“, následnú voľbu používateľa a príslušné upozornenie do smoke. Stranu pántov automaticky neurčovať. Do zoznamu dotknutých testov patrí aj guard povolených miest pre `unset`.  
   Dôkaz: `fronts.rb:599`, `bom.rb:641`, `form.js:1688`, `test_kova1_cela.rb:595`.

3. **FIX-IN-KOND — „Osadenie ≥ 14“ je nesprávne; návrh tiež mieša dve súradnice delenia.**  
   **719 + 1274 mm je správne.** Rozsah **695–743** však označuje výšku dolného dielca; deliaca hrana meraná od dna niky má pásmo **679–727**, so stredom 703. Pri osadení 14 je hrana 689 a vyhovuje. Nominálny rozsah osadenia pre niku 1964 a požiadavku 1940–1950 je **14–24 mm**, nie ľubovoľné ≥ 14. Navyše pri osadení **24,25 mm** výška ešte prejde toleranciou 0,5 mm, ale delenie už neprejde toleranciou 0,01 mm. Opraviť package/smoke a pridať hraničné prípady 0, 14, 24, 24,25 a 25.  
   Dôkaz: `appliance_catalog.rb:1521`, `appliance_checks.rb:276`, `appliance_checks.rb:385`, `appliance_checks.rb:416`.

4. **FIX-IN-KOND — Súhrn potrebuje presný kontrakt účinných hodnôt a prenosu do oboch UI.**  
   „Len nenulové/nepredvolené“ nestačí: samotná Chladničková ponesie `back_rail_height:100`, hoci nemá chrbát. **„Z líšt 100“ zobrazovať iba pri `back_mode:'rails'`, aj keď je 100 predvolená výška.** Zapustenie nezobrazovať pri `top_mode:'none'`; rešpektovať aj vylúčenie slotov. Súčasne explicitne doplniť odvodený údaj do `Panel.template_list`: úprava samotného `tile_row` ho do Inspectora neprenesie. Zachovať orezaný `TILE_CONFIG_KEYS` a existujúci tooltip kovania. Testovať skutočné payloady oboch ciest vrátane neaktívnych uložených hodnôt.  
   Dôkaz: `form.js:787`, `payloads.rb:2472`, `templates_dialog.rb:132`, `test_st3c_tpl.rb:298`.

5. **NOTE — Základný smoke potrebuje určené zámky a materiál; dva riadky čiel nemusia znamenať dve dvere.**  
   Nezamknutá hrúbka pri vložení prevezme hrúbku reálneho materiálu projektu, aj keď seed uvádza 18. Pri zamknutej šírke 800 vytvorí `wings:auto` **štyri fyzické dvere**; kontrola delenia pritom stále uzná dvojicu riadkov, pretože počet krídel nekontroluje. D-39 je vedome prijaté správanie, ale DoD má počítať fyzické dielce a uviesť predpoklady základného scenára. Doplniť aj použitie na existujúcu skrinku so zapustením: overiť jeho vynulovanie a zachovanie väzieb spotrebiča, osadenia a zjednotenie očakávaní.  
   Dôkaz: `actions_cabinet.rb:378`, `fronts.rb:437`, `appliance_checks.rb:130`, `templates_dialog.rb:534`, `templates_dialog.rb:563`.

6. **NOTE — Prípadná úprava delenia po smoke sa existujúcim knižniciam sama nerozšíri.**  
   Po dosiahnutí STD 7 už zmena hodnoty v generátore seedu nezmení uložené šablóny. Michal a Lucia tak môžu mať rozdielne predvoľby aj pri rovnakej verzii pluginu. Ak smoke zmení distribuovaný seed, treba určiť postup aktualizácie existujúcich knižníc; precedentom je ďalšia markerová migrácia s porovnaním **celého nedotknutého seedu**, nie prepis podľa mena.  
   Dôkaz: `templates.rb:387`, `templates.rb:649`.

Odpovede na otázky auditu:

1. **Pečiatka:** aktuálna schéma **21 po KON-B je správna**; konzervatívne odmietne aj plugin 20. R-12 kontroluje uložený záznam pri vložení aj aplikovaní; STD 7 samostatne obmedzuje zápisy knižnice.
2. **Migrácia a mená:** zdravá migrácia pod existujúcim zámkom je správna; presné `(kind, name)` chráni menovca, NFC/NFD sa nezjednocuje. Neobnovenie zmazaného seedu platí pri zachovanom STD 7, nie pri obnove staršieho snapshotu; zostáva nález 1.
3. **Čelá:** 719/auto je správne pre uvedené predpoklady; iný model nemení pevné F1 automaticky a potrebuje nové posúdenie vlastného pásma — podobná celková výška nestačí.
4. **Tooltip:** veta o vetraní patrí do tooltipu; doplnil by som „podľa montážneho listu spotrebiča“. Viditeľný konštrukčný súhrn v Štúdiu je primeraný.
5. **Ďalšie cesty:** čerstvá knižnica bude mať **10 šablón, z toho 7 korpusových**; náhľad je iba schéma. Starší STD 6 blokuje aj nové náhľady a pečiatky posledného použitia. Apply zachováva väzby cieľa; potrebuje uvedený integračný scenár.

**Verdikt: NOT SOUND.**


Codex session ID: 01a0e265-0657-7371-b8a4-18cde49e74fc
Resume in Codex: codex resume 01a0e265-0657-7371-b8a4-18cde49e74fc
