# Delta 2 — overenie integračného zladenia, Codex `gpt-6.1-sol` (17.10.2026)

Posudzujem návrh a predpísané regresné scenáre; vykonanie testov nebolo predmetom kontroly.

| Položka | Stav a dôvod |
|---|---|
| A U1/2 | **UZAVRETÁ** — T9b má konkrétny scenár pre štyri exporty aj nesúlad 18 + 36. |
| A U2/6 | **UZAVRETÁ** — Exportný žurnál, priebežné kontroly leases a blokovanie zápisov majú príslušné regresné scenáre. |
| A U3/1 | **UZAVRETÁ** — Testy pokrývajú čerstvé zmeny aj povinné odoslanie po aktualizácii pluginu. |
| A U3/2 | **UZAVRETÁ** — Scenár zachová úpravu vykonanú pred aktualizáciou pluginu. |
| A U3/3 | **UZAVRETÁ** — Opačné poradie commitov odmietne starší tiket bez prepísania novšej verzie. |
| A U3/4 | **UZAVRETÁ** — Test pokrýva konflikt správcu doručený po lehote T aj izoláciu cudzieho zdroja. |
| A U3/5 | **UZAVRETÁ** — Scenáre určujú správanie stavu, porovnania aj potvrdenia pri `peek_group :unknown`. |
| A U3/6 | **UZAVRETÁ** — Regresný scenár rozlišuje povolenú distribúciu a všetky uvedené odmietnutia. |
| A U3/7 | **UZAVRETÁ** — Zaseknutý precheck má test časového limitu, voľného zámku a ďalšieho volania. |
| A U3/8 | **UZAVRETÁ** — Obnova evidencie má scenáre dokončeného importu, rollbacku aj nevyriešeného prerušenia. |
| A U3/9 | **UZAVRETÁ** — Test zachová priečinok čakajúci na oneskorený ukazovateľ. |
| A U4/1 | **UZAVRETÁ** — U3 odovzdáva `replacements:` a testy sledujú náhrady až do žurnálu. |
| A U4/4 | **UZAVRETÁ** — Chýbajúci digest existujúcich náhľadov vyvolá varovanie a vyžaduje vedomé prepísanie. |
| A U5/1 | **UZAVRETÁ** — Obnova odovzdáva serverový odtlačok a má scenáre dopadov aj následnej zmeny. |
| A U5/3 | **UZAVRETÁ** — Prepnutie modelu aj zmena použitia záznamov vyvolajú nový plán. |
| A U5/4 | **UZAVRETÁ** — Neznáme použitie aj neznáme porovnanie majú zladené spracovanie a viditeľné upozornenia. |
| A U5/7 | **UZAVRETÁ** — Ručné vyriešenie správcu má konkrétny scenár menu, potvrdenia a obnovenia stavu. |
| B API U2 | **UZAVRETÁ** — R4.8 obsahuje chýbajúce metódy aj čítače obnovy. |
| B Zámok | **UZAVRETÁ** — Jediným parametrom je `entry_key`, pri prílohe odvodený cez `row_for`. |
| B Import | **UZAVRETÁ** — Signatúra aj volanie U3 obsahujú `replacements:`. |
| B Rozhodnutia | **UZAVRETÁ** — Platí jednotný tvar `{action:, seen_fingerprint:}`, zostavený serverom. |
| B Obnova | **UZAVRETÁ** — U5 odovzdáva odtlačok z náhľadu zálohy vrátane dotknutých príloh. |
| B Neznáme použitie | **UZAVRETÁ** — Výpočet rozlišuje mapu, `:unknown` a chýbajúci kľúč. |
| B Neznámy diff | **UZAVRETÁ** — U5 má explicitnú vetvu s varovaním a predvoleným preskočením. |
| B Výsledok konfliktu | **UZAVRETÁ** — `attachment_conflict` znamená neprevzatú skupinu a zodpovedajúcu hlášku. |
| C1 | **UZAVRETÁ** — Návrat obnoví archivované prílohy transakčne, zachová zdrojovú zálohu a odloží súčasné súbory. |
| C2 | **UZAVRETÁ** — Odtlačok zahŕňa lokálne prílohy, ktoré potvrdené rozhodnutie smie prepísať. |
| C3 | **UZAVRETÁ** — Tiché prvotné prijatie digestu ruší výslovné pravidlo aj regresný scenár. |

Nové BLOCKERy: **žiadne zjavné v povolenom rozsahu**.

Verdikt: **Blok je pripravený do zásoby ako návrhový balík s výhradou R0 sond U3/U4; tieto dva balíky zostávajú do výsledkov sond nezmrazené.**

