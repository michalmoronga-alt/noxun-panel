Overený checkout: `main`, `fe7f5405323eed86fedac8decaa733f2b792ad1d`. **1 BLOCKER, 6 FIX-IN-H17a, 2 NOTE.** Ide o audit návrhu; SketchUp ani exportné testy som nespúšťal, súbory som nemenil.

1. **BLOCKER — R9 neizoluje živé dáta počas celého života SketchUpu.**  
   Nastavenie dvoch katalógových override až „pred exportom“ a ich obnovenie v `ensure` nezaručuje sľub, že živé `%APPDATA%` nebude čítané ani menené ([package:299](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:299>)). Inicializácia už vykonáva migráciu materiálov, dopĺňanie UNI a kontrolu katalógu spotrebičov (`noxun_engine/main.rb:619`, `:628`, `:637`, `:650`). Ďalšie úložiská používajú priamo `ENV['APPDATA']`, napríklad `core/usage_stats.rb:33`.

   **Oprava:** izolovať celý profil pred inicializáciou pluginu a ponechať ho izolovaný až do skončenia procesu. Existujúce precedensy presmerujú `APPDATA` prvým príkazom bootstrapu (`scripts/run_su_tests.ps1:194`, `scripts/ui_foto.ps1:214`). Obnovenie živých ciest pri ešte aktívnych observeroch a časovačoch nesmie byť súčasťou R9.

2. **FIX-IN-H17a — S7 a T1 nesprávne sľubujú jedinú expanziu aj pri `nil`.**  
   Dnešný `budget_payload` obsahuje `exp = hw_exp || hardware_expansion(model, collected)` ([production_core.rb:2236](</C:/APP DEV/RUBY/ENGINE/noxun_engine/ui/production_core.rb:2236>)). Ak prvá expanzia vráti `nil` a export pokračuje k rozpočtu, pomocník ju zavolá znova. Memoizovanie `ctx.hw_exp == nil` tomu nezabráni. Tvrdenie S7 ([package:34](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:34>)) preto neplatí všeobecne a požiadavka T1 „nil → 1 volanie“ (:323) odporuje zachovaniu dnešného správania.

   **Oprava:** v H17a zachovať aj tento existujúci fallback a rozlíšiť počet vyhodnotení čítačky kontextu od počtu skutočných expanzií. T0 musí zachytiť sekvencie `nil → nil` aj `nil → platná expanzia`. Odstránenie druhého pokusu by bola samostatná zmena správania, nie čistý presun.

3. **FIX-IN-H17a — Navrhnuté `ctx.budget` mení poradie čítania dát ponuky.**  
   Ponuka dnes vykoná `Bom.compute → sheets_map → hardware_expansion → budget_payload` ([production_core.rb:3388](</C:/APP DEV/RUBY/ENGINE/noxun_engine/ui/production_core.rb:3388>)). R2 vyhodnocuje argumenty `bom, collected, nil, hw_exp, smap`, pričom R3 začína priamo `ctx.budget` ([package:217](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:217>), :229). Výsledkom je `bom → hw_exp → smap`.

   Pri nemenných katalógoch môže výsledok sedieť, ale sľúbené poradie sa nezachová; pri súbežnej zmene katalógu sa môže zmeniť aj načítaná verzia cien. G4 to nemusí odhaliť, pretože čítania katalógov sleduje iba počtom (:187).

   **Oprava:** v ponuke výslovne vyhodnotiť `ctx.bom`, potom `ctx.smap`, až potom `ctx.budget`. Do G4 pridať aj poradie `sheets_map`.

4. **FIX-IN-H17a — Prevzatie `with_now` z H7 môže posunúť zamrazený čas o dve hodiny.**  
   Odporúčaný vzor vracia pri každom `Time.now` **ten istý objekt** (`tests/pure/test_h7a_golden.rb:286–290`). Skutočný rozpočet však volá `Time.now.utc` (`core/budget.rb:123`); Ruby metóda `utc` tento objekt zmení. Čistá Ruby sonda potvrdila premenu `2026-10-02 23:03 +0200` na `21:03 +0000`. VEPO číta čas do LOGu až po rozpočte (`ui/production_core.rb:1741`, `:1760`).

   **Oprava:** R0/R9 musia požadovať nový objekt času pri každom volaní, napríklad `fixed_time.dup`, a pripnúť časové pásmo. Pridať test, že výpočet rozpočtu nezmení nasledujúci lokálny čas exportu. Inak kalibrácia môže chybu harnessu označiť za posun vstupov ([package:305](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:305>), :313).

5. **FIX-IN-H17a — R4 dovolí nový export, ktorý ignoruje odmietnutie prípravy.**  
   R4 b vyžaduje registráciu v `KINDS` a volanie `start` pred pickerom ([package:238](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:238>)). Nový handler však môže `start` zavolať, ignorovať vrátené `nil` a pokračovať k exportu. Predpísaná G2 zostáva „× 4 exporty“ (:176); nie je požadovaná rovnosť inventára behaviorálne testovaných exportov s `KINDS`. M15 skúša iba úplne chýbajúce volanie `start` (:345).

   **Oprava:** pre každý registrovaný export povinne spustiť spoločnú maticu odmietnutí cez jeho skutočný vstup a overiť nulový počet pickerov a zápisov. Pridať mutáciu „piaty registrovaný export zavolá `start`, ale ignoruje `nil`“.

6. **FIX-IN-H17a — T9 nepokrýva LOG časť deklarovanej mutácie M25.**  
   Testy porovnávača skúšajú zmenu CSV a obsahu XLSX, ale pri LOGu iba zmenu `Verzia` a dva výskyty `Verzia` ([package:311](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:311>)). Porovnávač, ktorý skontroluje jediný riadok verzie a ostatný LOG ignoruje, týmito prípadmi prejde. Tvrdenie M25 (:355) preto nie je podložené predpísanými testami.

   **Oprava:** pridať negatívne prípady zmeneného bajtu mimo verzie, odstráneného upozornenia a zmeneného počtu RED/ORANGE. Každý musí samostatne zhodiť porovnanie.

7. **FIX-IN-H17a — Rozdiel kalibrácie oproti baseline nemožno automaticky označiť za zmenu vstupov.**  
   R9.5 takto klasifikuje každý rozdiel a následne prijíma K ako referenciu ([package:313](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:313>)). Rovnaký rozdiel však vytvorí chyba harnessu, napríklad bod 4, alebo zmena pluginu pred kalibráciou. Posledný dodatok navyše umiestňuje pred K **H16 aj H18** (:445), zatiaľ čo P4 kontroluje iba H16 a úzky rozsah súborov (:152).

   **Oprava:** nevysvetlená odchýlka musí zostať nevysvetlenou odchýlkou. Pred prijatím K konkrétne doložiť jej príčinu; pripnúť verziu nástroja, parametre a SHA modelu aj celej vstupnej snímky pre K/P. Protokol `P == K` je vhodný na dôkaz parity refaktoru, sám však nepotvrdzuje správnosť reprodukcie pôvodnej zákazky.

8. **NOTE — Presná množina porovnávaných súborov potrebuje explicitnú hranicu.**  
   Baseline priečinok obsahuje aj `TEST v0 17 24.skp`, zatiaľ čo `SHA_baseline.txt:1–9` eviduje deväť exportných artefaktov. Doslovné porovnanie celého priečinka podľa R9.4 preto nemôže sedieť ([package:281](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:281>), :308).

   Definovať presnú výnimku vstupného modelu a porovnávaný exportný strom. Nepoužiť všeobecné filtrovanie, ktoré by skrylo neočakávané výstupné súbory.

9. **NOTE — D13 už nie je otvorené rozhodnutie; záväzné časti balíka sú navzájom nezladené.**  
   Dodatok schvaľuje samostatné **H17-0** pred H17a ([package:443](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h17/PACKAGE_H17.md:443>)). Hlavné poradie commitov (:114), R9.5 (:313) a D13 (:413) stále umiestňujú nástroj a K dovnútra H17a. Aktualizovať ich vrátane predpokladov po H18.

   Samotné oddelenie H17a/H17b, umiestnenie do `ui/`, načítanie cez helper a rozšírenie H11a zoznamu sú primerané. Zostávajúce brány podľa druhu exportu netreba zjednocovať; hlavné riziká sú vyššie uvedené rozpory v zachovaní správania a dôkaze parity.


