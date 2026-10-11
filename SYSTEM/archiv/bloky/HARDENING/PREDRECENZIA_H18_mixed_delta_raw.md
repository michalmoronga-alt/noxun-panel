Bez P1/P2/P3.

Overený pinovaný diff `ba4431aa…29a2f6f…`: textový riadok správne zobrazuje uložený výber, nevytvára zapisujúci ovládač, reaguje na odblokovanie aj zmenu hodnoty a nemení resolver, payload, config ani nákup.

Testy v izolovaných kópiách:

- H18 Ruby: 10 PASS
- H18 JS: 1 402 prípadov, 0 rozchodov
- všetkých 162 JS sád: PASS
- plná Ruby sada: 5 332 PASS, 0 FAIL; 1 zámerný SKIP, pretože archív nemá `.git`
- samostatný encoding guard: PASS
- pôvodný `hardware.js`: regresia zachytila 54 chýbajúcich riadkov

Limit: bez SketchUp/CEF vizuálneho overenia podľa zadania. Worktree zostal čistý; živý commit navyše mení iba dokumentáciu.

VERDIKT: OPRAVA OK
