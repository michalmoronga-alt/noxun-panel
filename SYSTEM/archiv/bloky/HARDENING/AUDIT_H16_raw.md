**0 BLOCKER · 7 FIX-IN-H16 · 3 NOTE.** Overený checkout: `main`, `5e0ffb90`, v0.17.18. Bez zmien súborov a git operácií. Výsledky autorovho prototypu som nereprodukoval; ide o audit návrhu proti aktuálnym zdrojom.

1. **FIX-IN-H16 — Nové úložisko môže prejsť všetkými navrhnutými guardmi.**  
   Tvrdenie „nový súbor … zhodí test“ v `_dev/audit_h16/PACKAGE_H16.md:98` nie je návrhom zabezpečené. Napríklad nová používateľská akcia v už registrovanom `dim_series.rb`, zapisujúca cez `JsonFileStore.write(File.join(Materials.dir, "#{name}.json"), data)`, nepridá rozpoznateľný literál ani nového zapisovateľa. Existujúci zápis je v `noxun_engine/core/dim_series.rb:229`. T4/T5 podľa package `:207–212` takú zmenu nezachytia; T6 prehráva iba pripravený prvý beh (`:235`). R5 navyše nevyžaduje doplnenie vykonávaného scenára, hoci sa naň odvoláva obrana v `:277`. Podobne T9 pokrýva iba vybrané formy `localStorage`, nie nové `sessionStorage` či IndexedDB.

   **Oprava:** doplniť mutácie dynamického úložiska v existujúcom zapisovateľovi, zápisu cez pomocníka a novej JS perzistencie. Nepokryté zápisové miesta musia vyžadovať explicitné zaradenie alebo zdôvodnenú výnimku; samotná príslušnosť celého súboru nestačí.

2. **FIX-IN-H16 — Chýbajú existujúce staging súbory v prílohách a cache.**  
   Package `:55` a `:79–80` uvádza pre náhľady iba `tmp/`. Reálny `noxun_engine/core/template_previews.rb:272` však vytvára **`<finálny-náhľad>.png.new` vedľa finálneho PNG**; riadok `:339` výslovne upratuje pozostatok po páde. `noxun_engine/core/demos/image_cache.rb:83` navyše vytvára `<obrázok>.tmp<pid>`, ktorý súpis tiež neuvádza.

   D-48 by pri preberaní priečinka podľa registra mohol `.png.new` považovať za zdieľanú prílohu. T6 túto chybu maskuje povolením ľubovoľného dieťaťa známeho priečinka (`PACKAGE_H16.md:235`).

   **Oprava:** doplniť oba vzory do príslušných riadkov a otestovať rozlíšenie finálnej prílohy, staging súboru a neznámeho obsahu.

3. **FIX-IN-H16 — Inventár nesprávne označuje zamknuté zápisy ako „bez zámku“.**  
   S7 a riadky značiek/záloh (`PACKAGE_H16.md:30`, `:72–76`) nezodpovedajú produkčným volacím cestám:

   - UNI markery sa zapisujú pod `Materials.with_catalog_lock`: `materials_catalog.rb:1078–1093`, `:1151–1173`.
   - Predmigračná záloha vzniká pod tým istým zámkom: `materials_migration.rb:166–176`, následné volanie zapisovača na `:597`.
   - Forenzné kópie vznikajú pod zámkom pri posúdení alebo obnove: `materials_health.rb:237–273`, `:446–476`.
   - `migration_hold.json` má zmiešaný režim: zápis pod zámkom (`materials_health.rb:446–460`), spotrebovanie/mazanie bez neho (`:422–424`).

   **Oprava:** zaznamenať skutočný režim vrátane toho, že zámok drží volajúci. Runtime oprava zámkov môže zostať D-48; nesprávne fakty registra nie.

4. **FIX-IN-H16 — Nesprávny, ale existujúci zámok prejde testami.**  
   Mutácia `hardware_catalog.lock → materials.lock` pri položke `hardware_catalog` splní T1, pretože zámok existuje v `LOCKS`. T2 overuje cesty zámkov samostatne, nie ich priradenie ku knižnici. T8 porovnáva iba `file/kind/sync` (`PACKAGE_H16.md:227–239`). M9 skúša len neexistujúci názov (`:256`).

   Katalóg pritom reálne zamyká vlastný súbor (`noxun_engine/core/hardware_catalog.rb:131–148`) a vedome sa vyhýba vnáraniu materiálového zámku (`:432–435`). D-48 má zámok preberať z registra.

   **Oprava:** strážiť väzbu **úložisko → konkrétny zámok**, pridať mutáciu na iný platný zámok a rozšíriť porovnanie dokumentácie aj o zámky a verzie.

5. **FIX-IN-H16 — R0 nezabezpečuje deklarovanú nezávislosť od poradia testov.**  
   Reset v `PACKAGE_H16.md:148–153` neodstraňuje samostatný `ApplianceCatalog.test_dir_override`. Ten má prednosť pred `Materials.dir` (`noxun_engine/core/appliance_catalog.rb:188–192`). Existujúca sada nastavuje vlastný koreň (`tests/pure/test_s1a1_appliance_catalog.rb:20`) a posledný test ho v `ensure` ponechá nastavený (`:1045–1047`).

   Pri poradí **S1-A1 → H16** spotrebiče nepôjdu do čerstvého ENV koreňa; samotný `reset_state!` to neopraví. Tvrdenie package `:278` je preto nepravdivé. R0 navyše predpisuje návrat ENV, ale nie vyčistenie pamäte modulov po návrate.

   **Oprava:** uložiť, vyčistiť a obnoviť oba override mechanizmy, invalidovať/resetovať stav aj v `ensure`, alebo golden spúšťať v samostatnom procese. Pridať kontrolu obráteného poradia a opakovaného behu.

6. **FIX-IN-H16 — Nový scenár narazí na existujúci H13 guard.**  
   R5 predpisuje tabuľku s dvoma zdrojovými riadkami a doplnenie `NX_H13_SCENARIOS` (`PACKAGE_H16.md:201–203`). Existujúci test však vyžaduje **najmenej štyri kontrolované riadky v každom scenári** (`tests/pure/test_h13_rozsirovacie_body.rb:183–185`).

   **Oprava:** doplniť zmysluplné kontrolované riadky alebo navrhnúť odôvodnenú výnimku pre tento scenár. Súčasné zadanie túto kolíziu nerieši.

7. **FIX-IN-H16 — F5 musí zachytiť význam markerov pri úmyselnom zmazaní seedu.**  
   Package `:324` odôvodňuje „riziko malé“ idempotenciou podľa ID/dekoru. Marker však uchováva aj informáciu **„používateľ seed vedome zmazal, nevracaj ho“**, výslovne zdokumentovanú v `noxun_engine/core/materials_catalog.rb:1112–1117`. Po prenose takého katalógu na PC bez markeru sa chýbajúci záznam môže znova doplniť (`:1142–1143`, `:1168–1173`).

   **Oprava v H16:** opraviť odovzdávaný fakt a zaznamenať požiadavku, aby import zachoval úmyselné odstránenie. Implementácia riešenia patrí D-48; automatické zdieľanie markerov z toho nevyplýva.

8. **NOTE — `versions` nie je budúca kompatibilitná brána.**  
   Obmedzenie na STANDARD §13.1 (`PACKAGE_H16.md:163`, `:237`) vynechá obsahové markery setov z §13.2. `HardwareSets` podporuje `std` až po `STD_LIFT_FORMS = 6` (`hardware_sets.rb:157–159`), kontroluje `STD_SUPPORTED` (`:1318–1322`) a verziu zapisuje podľa obsahu (`:3116–3120`). Samotné `STD = 1` ani seed verzia túto informáciu nenahrádzajú.

   Pre H16 je taký zoznam odkazov prípustný. Do odovzdania SYNC-0 však treba výslovne uviesť, že z `versions` nemožno odvodiť `current_std`; import potrebuje skutočné pravidlá kompatibility.

9. **NOTE — Fyzický koreň obsahuje aj nezaradený stav vývojového nástroja.**  
   `scripts/start_okna.ps1:24` počíta `%APPDATA%\NOXUN\Engine\agent_register_videne.txt` a na `:198` ho zapisuje. Nie je to knižnica distribuovaného pluginu, preto nejde o chýbajúcu shared položku. Tvrdenie o úplnom obsahu koreňa (`PACKAGE_H16.md:24`) však potrebuje hranicu: explicitne zaznamenať tento lokálny súbor nástroja alebo vylúčenie nástrojov zo súpisu.

10. **NOTE — R2, rozsah dávky a základné rozhodnutia sú obhájiteľné.**  
    Bez override sú výpočty koreňa totožné (`materials.rb:233–237`, `templates.rb:81–84`, `usage_stats.rb:33–36`). Materials sa načíta skôr v produkcii aj helperi; konkrétnu regresiu KOV-B1/KOV-I som nenašiel. Trieda **audit áno, výrobná/cenová nie, in-SU odporúčaný** zodpovedá spúšťačom v `CLAUDE.md:184–189`.

    Register má využitie už ako dátový podklad guardov; nový architektonický súbor a jeden PR sú primerané. Q1 má oporu v neskoršom explicitnom `dim_series = per PC` v `SYNC_KNIZNICE_NAVRH_2026-09-06.md:140`. Q2 správne ponecháva zmiešaný VEPO súbor lokálny (`production_core.rb:60–64`); prípadná spoločná voľba vyžaduje oddelenie nastavenia, nie zmenu celého súboru na `shared`. F1–F4 môžu zostať implementačnými úlohami D-48, pokiaľ H16 presne zaznamená ich obmedzenia.


