1. **FIX-IN-H8 — Testy nedokazujú zachovanie výrobných čísel cez zmenený zber.**  
   T1f kontroluje text zdroja; T1i pridáva `std_issues` do už pripraveného vstupu. Nesprávne vložené `next` v `Bom.collect` môže vynechať výrobný záznam a oba testy zostanú zelené. Existujúce golden testy túto medzeru nezatvárajú: napríklad NP4 skladá riadky ručne. Doplniť behaviorálny test **skutočného `Bom.collect`** nad rovnakými entitami s rôznymi `std`: všetky pôvodné návratové kľúče musia zostať zhodné, meniť sa smie iba `std_issues`. Pokryť aj filtre vnorených dielcov, nevýrobné dosky, samostatné dielce, chybu čítania `std` a prednosť `newer_config`. Mutácie musia overovať výsledok zberu, nie iba prítomnosť riadka v zdroji.  
   Referencie: [PACKAGE_H8.md:184](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:184>), [bom.rb:227](<C:/APP DEV/RUBY/ENGINE/noxun_engine/core/bom.rb:227>), [test_np4_golden.rb:60](<C:/APP DEV/RUBY/ENGINE/tests/pure/test_np4_golden.rb:60>).

2. **FIX-IN-H8 — Samostatný dielec bez `cabinet_id` stratí nález napriek platnému PID.**  
   R2.2 použije ako `id` jeho `cabinet_id`; R3.2 prázdne ID zahodí. Existujúci collector však taký výrobný dielec normálne zahrnie do `records`. Poškodený alebo cudzí kus tak môže mať `std = 2` či chýbajúci marker, dostať sa do výstupov a zostať bez upozornenia H8. Pre samostatné dielce treba zachovať nález podľa PID aj bez pôvodného vlastníka; text nemá tvrdiť neznámu príslušnosť ku skrinke. Doplniť test nálezu aj kliknutia.  
   Referencie: [PACKAGE_H8.md:125](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:125>), [PACKAGE_H8.md:138](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:138>), [bom.rb:283](<C:/APP DEV/RUBY/ENGINE/noxun_engine/core/bom.rb:283>).

3. **FIX-IN-H8 — Dôkaz kompatibility uložených zákaziek môže prejsť naprázdno.**  
   Samotné `std_issues == []` nepreukazuje, že sa skontroloval jediný uložený kus. Spúšťací skript pripúšťa prázdny `ENGINEtests.skp`; runner navyše pred scenármi zavolá `cleanup`, ktorý vymaže skrinky a dosky. Package síce požaduje kontrolu hneď po otvorení, ale treba výslovne určiť volanie **pred `cleanup`** a požadovať nenulové pokrytie uložených skriniek, dosiek a vnorených dielcov. Prázdna vstupná vzorka musí znamenať „neoverené“, nie PASS save/reopen.  
   Referencie: [PACKAGE_H8.md:210](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:210>), [run_su_tests.ps1:45](<C:/APP DEV/RUBY/ENGINE/scripts/run_su_tests.ps1:45>), [su_runner.rb:27821](<C:/APP DEV/RUBY/ENGINE/tests/sketchup/su_runner.rb:27821>), [su_runner.rb:170](<C:/APP DEV/RUBY/ENGINE/tests/sketchup/su_runner.rb:170>).

4. **FIX-IN-H8 — Agregovaná veta nesprávne priradí víťazný stav všetkým problémovým kusom.**  
   `count` zahŕňa všetky neaktuálne kusy, ale text opisuje iba najzávažnejší stav. Skrinka s jedným `newer` dielcom a dvoma dielcami bez značky preto dostane „3 z 14 kusov … z novšej verzie“, hoci novší je iba jeden. Zachovať jeden riadok, ale počet označiť ako počet kusov s problémom značky a víťazný stav uviesť ako najzávažnejší zistený problém; prípadne vypísať rozdelenie stavov. Testovať výslednú vetu nad zmiešanou agregáciou.  
   Referencie: [PACKAGE_H8.md:119](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:119>), [PACKAGE_H8.md:142](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:142>).

5. **NOTE — Nález nemusí prežiť kopírovanie; pri doske zanikne aj bez prestavby.**  
   `BoardBuilder.dedup_copies` ponecháva geometriu a výrobný config, ale bezpodmienečne prepíše `std` na aktuálnu hodnotu. Kópia dosky s chýbajúcou, poškodenou alebo novšou značkou tak môže stratiť upozornenie iba pridelením nového ID. F3 opisuje len prestavbu, preto nezachytáva celý problém. Pri zachovaní zákazu zmien builderov túto hranicu explicitne priznať a budúci návrh ochrany rozšíriť aj na dedup kópií.  
   Referencie: [board_builder.rb:674](<C:/APP DEV/RUBY/ENGINE/noxun_engine/core/board_builder.rb:674>), [board_builder.rb:697](<C:/APP DEV/RUBY/ENGINE/noxun_engine/core/board_builder.rb:697>), [PACKAGE_H8.md:279](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:279>).

6. **NOTE — R3.5 sľubuje presnejší zelený počet, než dnešná implementácia poskytuje.**  
   `counts` počíta problémových vlastníkov podľa unikátnych ID, nie PID. Dve problémové skrinky s rovnakým ID dostanú dva nové riadky, ale od zeleného počtu sa odpočíta iba jedna; skrinka bez ID sa nemusí odpočítať vôbec. Ide o existujúci limit, nie dôvod rozširovať H8 o opravu semaforu. R3.5 a testy ho však musia priznať a zosúladiť s H3.  
   Referencie: [PACKAGE_H8.md:153](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:153>), [validation.rb:292](<C:/APP DEV/RUBY/ENGINE/noxun_engine/core/validation.rb:292>), [validation.rb:1891](<C:/APP DEV/RUBY/ENGINE/noxun_engine/core/validation.rb:1891>).

7. **NOTE — Navrhnutá trieda dávky zodpovedá pravidlám repozitára.**  
   Audit áno, výrobná/cenová nie a in-SU nie je automatickou bránou podľa existujúceho zoznamu spúšťačov. To však nenahrádza chýbajúci dôkaz kompatibility: bez reálneho behu alebo dokončeného náhradného smoke musí zostať save/reopen označené ako neoverené.  
   Referencie: [PACKAGE_H8.md:73](<C:/APP DEV/RUBY/ENGINE/_dev/audit_h8/PACKAGE_H8.md:73>), [CLAUDE.md:171](<C:/APP DEV/RUBY/ENGINE/CLAUDE.md:171>).


Codex session ID: 01a0f4b2-1881-7a12-a8ee-22cd01321c5c
Resume in Codex: codex resume 01a0f4b2-1881-7a12-a8ee-22cd01321c5c
