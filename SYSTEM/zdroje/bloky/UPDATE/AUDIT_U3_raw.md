# Audit návrhu U3 — Codex `gpt-6-astra` (17.10.2026, úzke zadanie)

1. **BLOCKER — Podmienka „nezmenená skupina“ preskočí skutočné úpravy aj potrebné opätovné odoslanie.** [PACKAGE_U3.md:195](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:195>)  
   Po odoslaní A zostane `entry.fingerprint = A` aj na Disku A. Správca upraví obsah na B, ale predpísané porovnanie stále vyhodnotí A = A a odoslanie preskočí. Navyše nezmenené dokumenty po aktualizácii pluginu zostanú pod starou verziou, ktorú R-G1 odmieta prevziať. Porovnávať treba **čerstvý exportovaný obsah a verziu pluginu**; zmena verzie musí umožniť nové publikovanie.

2. **BLOCKER — Prebázovanie vie skryť používateľove zmeny pred varovaním R4.** [PACKAGE_U3.md:181](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:181>)  
   Posledný `status` uloží `clean: true`; Lucia potom zmení cenu, zavrie SketchUp bez ďalšieho vyhodnotenia a aktualizuje plugin. R-F3 nový odtlačok vrátane jej úpravy označí za východisko. Nasledujúce prevzatie ju môže prepísať bez upozornenia na vlastné zmeny. Historické `clean` nedokazuje čistotu pred aktualizáciou. Bez overiteľného rozlíšenia migrácie a používateľovej úpravy musí zostať stav konzervatívne zmenený.

3. **BLOCKER — Starý tiket môže prepísať už prevzatú novšiu verziu.** [PACKAGE_U3.md:228](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:228>)  
   Príprava tiketu prebieha mimo zámku; commit nekontroluje jeho cieľ proti aktuálnemu `entry.version/id`. Pripravené tikety N a N+1 možno dokončiť opačne. Pri pôvodnom rozhodnutí `:overwrite` ani zmenený lokálny odtlačok starší commit nezastaví. Pod zámkom treba odmietnuť zastaraný tiket nezávisle od `:overwrite`; návrat dozadu smie ísť iba explicitnou cestou Vrátiť. Doplniť aj stav pre neprázdny Disk ukazujúci staršiu hlavu než už prevzatú.

4. **FIX — Lokálny sken nepotvrdzuje jediného správcu.** [PACKAGE_U3.md:145](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:145>)  
   Pri oneskorenej synchronizácii môžu obe PC vykonať `claim_admin!`, opätovne vidieť iba vlastný súbor a začať publikovať. Predpoklad D5, že dva odosielajúce PC nenastanú, preto neplatí. Navyše konfliktné kópie ukazovateľov sa iba hlásia ako `foreign`, bez záväzného blokovania. Definovať aktiváciu správcu a bezpečné spracovanie už vzniknutých publikácií pri neskorom konflikte; samotný opakovaný listing R19 nezaručí.

5. **FIX — Zisťovanie stavu a diff nerešpektujú nové podmienky API U2.** [PACKAGE_U3.md:177](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:177>), [PACKAGE_U2.md:388](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U2.md:388>)  
   U3 získava lokálne odtlačky a diff cez `export_group`. U2 však export odmieta pri otvorenom Štúdiu, Inspectore, ďalšej inštancii alebo bežiacom prepočte cien. V otvorenom O plugine teda nemožno predpokladať úspešný export. Doplniť použiteľný kontrakt čítania alebo presnú bariéru volajúceho a spracovanie odmietnutí; tento problém nesmie skončiť falošným stavom „aktuálne“.

6. **FIX — R-G2 nepreukazuje dostupnosť správcovej verzie podľa R18.** [PACKAGE_U3.md:188](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:188>), [updater.rb:871](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/noxun_engine/core/updater.rb:871>)  
   `Updater.check` číta iba verziu loadera. Výsledok `newer` návrh povolí, hoci dostupná distribúcia B nepreukazuje dostupnosť správcovej verzie A. Ani `same` nepreukazuje úplnosť distribúcie. Brána potrebuje dôkaz dostupnosti konkrétnej požadovanej verzie, nie iba neprítomnosť výsledku `older`.

7. **FIX — Kontrola distribúcie obchádza časový limit.** [PACKAGE_U3.md:195](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:195>), [updater.rb:874](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/noxun_engine/core/updater.rb:874>)  
   `publish_prepare` vykonáva R-G2 na hlavnom vlákne; volané `Updater.check` priamo pristupuje na Disk. Zaseknuté čítanie tak môže zmraziť SketchUp ešte pred limitovaným odosielaním. Aj túto kontrolu presunúť do limitovaného pracovníka; hlavné vlákno má vyhodnotiť jeho výsledok.

8. **FIX — Chýba obnova pádu medzi úspechom U2 a zápisom stavu U3.** [PACKAGE_U3.md:233](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:233>)  
   U2 dokončí import a odstráni žurnál, potom proces padne pred `update_sync_state!`. Obsah je nový, ale evidencia obsahuje starú verziu a `pending`. U2 už nemá čo obnovovať; R-J5 rieši iba `last_recovery` alebo `pending_issue`. Doplniť trvalý doklad dokončenia a jednoznačnú obnovu tohto intervalu aj pádu pred samotným importom.

9. **FIX — Zametanie zamieňa neprítomný ukazovateľ za nepublikovanú verziu.** [PACKAGE_U3.md:205](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:205>)  
   Pri opätovnej synchronizácii môže starý priečinok doraziť pred svojím ukazovateľom. Podmienka „bez ukazovateľa a starší ako 24 h“ ho zmaže napriek existujúcej publikácii; posun hodín riziko zväčší. Samotný vek a lokálna absencia nestačia na dôkaz osirelosti. Uchovávať päť skutočných publikácií, nie iba číselné pásmo, a mazať iba preukázateľne nepublikované zvyšky.

10. **NOTE — S1–S5 nemožno označiť všetky za uzavreté.** [PACKAGE_U2.md:439](<C:/APP DEV/RUBY/ENGINE/.claude/worktrees/wonderful-wilson-10d11d/SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U2.md:439>)  
    S1–S3 sú pokryté návrhom U2 §15, ešte nie implementačným dôkazom. S4 výslovne zostáva čiastočne otvorené do overenia označenia zákazky na prestavbu v U5. S5 má oddelené brány, ale ich použitie v U3 zostáva chybné podľa bodov 1 a 6. R0 môže odhaliť problémy; úspešná sonda nedokazuje budúce poradie doručovania ani názvy konfliktov.

