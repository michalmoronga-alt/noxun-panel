> Stav: surový výsledok auditu návrhu KON-B (Codex gpt-6-astra, 27.9.2026, 7,5 min) — nálezy sú zapracované v [PACKAGE_KONB_K2.md](PACKAGE_KONB_K2.md) (Scope IN a sekcia Audit návrhu); nie autorita.

Audit nad čistým `main 4be63120`. **0 BLOCKER, 3 FIX-IN-KONB, 2 NOTE.** Súbory som nemenil; závery vychádzajú zo zdrojov a sond Ruby/JS v pamäti.

1. **FIX-IN-KONB — Sesterské roly samy nezaručia zjednotenie olepu.**  
   „Použiť na podobné“ prenáša **riedky override**, nie výsledné hrany. Chýbajúci override vráti cieľ na **jeho vlastné pravidlo**. Ak dolná lišta používa `{L1}` a horná má upravené pravidlo `{L2}`, rozšírenie výberu na obe roly ich nezjednotí. Pri čiastočnom override zostávajú ostatné hrany závislé od pravidla cieľa. Pozri `actions_parts.rb:842`, `abs_rules.rb:327`.
   
   **Doplniť kontrakt:** či akcia prenáša rozhodnutie „podľa pravidla“, alebo zjednocuje účinný olep. Druhé vyžaduje viac než rozšírenie filtra rolí. Testovať rozdielne pravidlá aj čiastočné overrides; upraviť tiež text „rovnaká rola“ v `panel.html:809`. Materiál ani smer dekoru automaticky neprenášať.

2. **FIX-IN-KONB — Mutačný test stojacej dolnej lišty má nesprávny očakávaný výsledok.**  
   Odobratie `back_rail_bottom` zo `STANDING_ROLES` **nevytvorí dva riadky BOM**. Obe lišty naďalej nesú rovnaké `{L1}`; zmení sa iba fyzická plocha dolnej lišty, ktorú L1 označuje. Sonda potvrdila **1 riadok, 2 ks v oboch prípadoch**, pričom L1 prešla z hornej plochy na spodnú. Pozri `part_faces.rb:115`, `bom.rb:1666`.
   
   **Oprava DoD:** mutant musí zlyhať na polohe olepenej plochy, 2D karte a kontrole/hoveri. Počet riadkov nie je dôkaz správneho umiestnenia pásky.

3. **FIX-IN-KONB — Skryté neplatné H môže zablokovať ostatné režimy chrbta.**  
   Pridanie H do `LIMITS` a skrytie jeho riadku nestačí: `form.js:288` validuje aj skryté polia. Scenár **Z líšt → H=999 → Bez chrbta** nechá neviditeľné pole neplatné a zablokuje aplikovanie. Overené nad skutočnou validáciou s plánovaným limitom pridaným v pamäti.
   
   **Doplniť:** H validovať iba pri aktívnom `rails`, pri skrytí odstrániť chybové označenie a tooltip. Testovať odchod z neplatného H do ostatných režimov aj do slotu umývačky.

4. **NOTE — Prevzatie pomocníkov KON-A vyžaduje výnimku z nulových guardov.**  
   Kontrola výšky líšt musí fungovať aj pri **X=Y=0**, kde dnes predčasne končia `core.js:1613` a `form.js:256`. Označovanie chyby dnes pozná iba X/Y. Navyše `preview.js:412` pri nulách nedoplní `innerD`, takže odhad vnútorných dielcov používa celú D.
   
   Package tieto funkcie menuje; pripnúť konkrétny integračný test **rails bez komína + polica/priečka + červené H**, aby implementácia neprevzala aj staré výnimky.

5. **NOTE — Ochrana schémou 21 neplatí pre samostatne prenesený dielec.**  
   Celú skrinku chráni existujúca exportná brána, ale samostatný `part` prechádza cez `bom.rb:283` bez kontroly schémy. Starý plugin môže takú lištu vyexportovať pod názvom **„Lista chrbta“**, pretože novú skratku nepozná (`vepo_export.rb:446`).
   
   Ide o existujúcu hranicu ochrany, nie dôvod otvárať všeobecnú migráciu. Výslovne uviesť aktualizáciu oboch PC **pred prvou výrobou s lištami**.

Odpovede na otázky auditu:

1. **Spoločný názov:** áno; skratka aj uvedené kombinácie VEPO prešli sondou, po rozdelení však oba riadky zostanú pomenované „Chrb HD“.
2. **Prvá korpusová stojacia rola:** áno; nenašiel som ďalší runtime predpoklad „stojace = zásuvka“ — materiálové a hrúbkové vetvy používajú vlastné zoznamy.
3. **Zlúčenie s výstuhami naplocho:** áno, pri zhode celého `row_key`; rozdielne ABS, grain alebo `material_source` musia riadky ponechať oddelené.
4. **H 20–300, podmienka a riedky zápis:** áno; nové šablóny musia výslovne niesť 100, staré bez kľúča zachovať H cieľa, s opravou validácie z nálezu 3.
5. **Sesterské „Použiť na podobné“:** áno pre olepy, ale až po spresnení prenosovej sémantiky z nálezu 1.
6. **Ďalšie medzery:** vyššie uvedené; whitelisty, kópie, šablóny, preflighty a spotrebitelia osí sú návrhom pokryté; `BuildPlan::BACK_MODES` nerozširovať mechanicky — patrí provenance dielca `back`, nie enumu konfigurácie (`build_plan.rb:510`).

**NOT SOUND**


Codex session ID: 01a0e249-4ca0-7500-8f5b-f314d6efc85e
Resume in Codex: codex resume 01a0e249-4ca0-7500-8f5b-f314d6efc85e
