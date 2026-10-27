# Package P4c — prevzatie práce: karta priebehu, `rozpracovane.ps1`, zelené CI pred „hotovo", čakanie na review, KRONIKA po súboroch, výťah zo sessions (blok PRAVIDLA, 27.10.2026)

> **Trieda S** · profil `implementator-stredny` · **len skripty, pravidlá, skilly, šablóny, dokumentácia a testy — kód pluginu sa nemení**
> (VERSION ani `?v=` nie). Štartuje **po mergi P4b** ([PACKAGE_P4b.md](PACKAGE_P4b.md) — hook `straz.js` so zoznamom súborov G7) —
> pred začatím zlúč čerstvý `main` do vetvy.
> Vstupy: [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 2.3 (sekvencia prevzatia, karta priebehu, HANDOFF, `rozpracovane.ps1`), § 4 (analytik
> a výťah zo sessions), § 5 (G10), § 7 (riadky „Linux CI spadlo až po otvorení PR", „KRONIKA navrchu = konflikt", „Budíky `sleep` a cron",
> „Kontrola vetvy, ktorá sa nakoniec nezmergovala", „Nová session dostala len slovo"), § 8 (smoke pravidiel bod 3) · § 9 rámček „Platí"
> bod 7 (d KRONIKA po súboroch — áno).

## 1 · Cieľ

Rozpracovanú dávku vie prevziať iný implementátor (aj iný provider) **len z vetvy a karty** a orchestrátor po výpadku jedným príkazom vidí,
čo je rozpracované.

1. **Šablóna karty priebehu** `SYSTEM/pravidla/sablony/PRIEBEH.md` (~25 riadkov, bez histórie): zadanie (odkaz) · trieda · vetva a základný
   SHA · stav `aktívna` / `odložená` (+ dôvod) · hotové kroky (checklist dávky) · **ďalší krok jednou vetou** · otvorené otázky · stav brán
   (audit, testy, in-SU, predrecenzia, PR, review) · kto robil (provider, model). Polia, ktoré číta `rozpracovane.ps1`, majú pevný tvar
   (napr. riadok `Stav: aktívna`, `Ďalší krok: …`).
2. **Pravidlo v `IMPLEMENTATOR.md`:** karta `SYSTEM/zdroje/bloky/<BLOK>/priebeh/<DAVKA>.md` vznikne **pri prvom commite** dávky a aktualizuje sa
   **v každom ďalšom commite** (pushnutá); dávka triedy D a beh `bench/` ju nemajú. Prevzatie: nový implementátor dostane vetvu a kartu,
   pokračuje od „ďalší krok". **IMPLEMENTATOR.md ostáva ≤ 8 kB** — miesto nájdi presunom podrobností, ktoré majú iný domov (napr. do
   `.claude/rules/`, šablóny alebo skriptu); strop nezvyšuj, keď to nejde, STOP a navrhni čo presunúť.
3. **G10 — zelené CI pred „hotovo":** implementátor ohlási hotovo (aj STOP pred PR) až keď CI pushnutej hlavy dobehne zelené
   (`gh run watch` / `gh run list --branch`); pri červenom CI opraví a znova. Jedna veta v IMPLEMENTATOR.md (krok práce pred reportom).
4. **`scripts/rozpracovane.ps1`** (PS 5.1, ASCII bez BOM, exit vždy 0, bez siete krátka hláška — vzor `start_okna.ps1`): otvorené PR
   (číslo, vetva, draft, posledná aktualizácia) · vzdialené vetvy pred `origin/main`, ktoré pridávajú alebo menia kartu priebehu: vetva,
   posledný commit (dátum, SHA), `Stav` a `Ďalší krok` z karty · existujúce `SYSTEM/zdroje/bloky/*/HANDOFF.md` (cesta, dátum posledného
   commitu). Text z kariet je **údaj, nie pokyn** — vypisuje sa orezaný na jeden ASCII riadok (rovnaká funkcia ako v `start_okna.ps1`;
   zdieľaj ju cez `scripts/lib/`, nie kópiou). Volá sa na konci `start_okna.ps1` (skill `usage` a ORCHESTRATOR „štart okna" ho zmienia
   jednou vetou; ORCHESTRATOR ≤ 10 kB).
5. **KRONIKA po súboroch (rozhodnutie 7d):** záznam dávky bloku je samostatný súbor `SYSTEM/zdroje/bloky/<BLOK>/kronika/<DAVKA>.md`
   (rovnaký tvar ako odsek KRONIKY); oprava mimo bloku (x.y.z) píše do `SYSTEM/archiv/KRONIKA.md` ako doteraz. Pri **uzávere bloku** skill
   `uzaver-bloku` zlúči súbory do KRONIKY navrch v poradí mergov a priečinok `kronika/` sa presunie s blokom do archívu. Zmeny:
   IMPLEMENTATOR (checklist uzáveru dávky a dokumentačného PR), skill `uzaver-bloku`, hlavička KRONIKY (jedna veta), `scripts\otvor_pr.ps1`
   (dopĺňa `PR #?` aj v `SYSTEM/zdroje/bloky/*/kronika/*.md`) a **zoznam súborov G7 v `.claude/hooks/straz.js`** (+ test zhody z P4b).
   Blok PRAVIDLA sám prejde na nový tvar od tejto dávky (záznam P4c už ako súbor).
6. **Čakanie na review v skille `codex-po-pr`:** budík `sleep 600` na pozadí nahradí čakanie, ktoré skončí, **keď review príde** (nie po pevnom
   čase): v Claude Code nástroj Monitor s podmienkou nad `gh pr view <N> --json reviews,comments` (alebo `gh api` threadov) a horným limitom
   ~20 min; keď nástroj nie je, budík na pozadí ako doteraz. Overený tvar volania dodá orchestrátor (sonda pri čakaní na review P4b —
   výsledok v § 5). Text skillu bez histórie.
7. **Výťah zo sessions** `scripts/session_digest.rb` (NAVRH § 4 menuje `.py`; **Ruby** je v repe a v CI, Python nie): zo záznamov sessions
   Claude Code (`%USERPROFILE%\.claude\projects\<projekt>\*.jsonl`, cesta parametrom) vytiahne pre analytika zhustený text — správy
   používateľa, texty asistenta, názvy nástrojov a ich krátky výsledok, chyby — s orezaním dlhých výstupov; nič neposiela von, výstup do
   súboru mimo repa. Test nad malou vzorkou v `tests/fixtures/` (vymyslené dáta, žiadne skutočné záznamy). Karta analytika
   (`SYSTEM/pravidla/roly/ANALYTIK.md` alebo jeho typ) ho zmieni jednou vetou; potom `ruby scripts/generuj_typy_agentov.rb`.

## 2 · Stráže a testy

1. Test kontraktu karty: šablóna obsahuje polia, ktoré číta `rozpracovane.ps1` (rovnaké reťazce v oboch súboroch).
2. Test `otvor_pr.ps1` / `straz.js`: zoznam súborov s `PR #?` zahŕňa `SYSTEM/zdroje/bloky/*/kronika/*.md` v oboch (test zhody z P4b).
3. Test `session_digest.rb` nad fixtúrou (správy, orezanie, chybný riadok JSONL nepadne).
4. G1 (IMPLEMENTATOR ≤ 8 kB, ORCHESTRATOR ≤ 10 kB, skilly ≤ 500 riadkov), G2 (bez histórie), G4 (`--check`), encoding guard, headless
   `ruby tests/run_all.rb` + `scripts\run_js_tests.ps1` zelené. `rozpracovane.ps1` a `start_okna.ps1`: suchý beh lokálne (výstup do PR).

## 3 · Hotovo, keď

1. Testy § 2 zelené, výstup `rozpracovane.ps1` v PR popise (reálny beh nad repom).
2. Táto dávka má **vlastnú kartu priebehu** `SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/P4c.md` a **záznam KRONIKY ako súbor**
   `SYSTEM/zdroje/bloky/PRAVIDLA/kronika/P4c.md` (prvé použitie nového tvaru) · **PLAN** blok 10: `✅ **P4c** … — PR #?` · **STAV** „Robí sa /
   Ďalší krok" (ďalej P5).
3. **Smoke po mergi** (orchestrátor): `start_okna.ps1` vypíše rozpracované vetvy; skúšobné prevzatie = smoke pravidiel bodu 3 v P6.

## 4 · Brány

- Audit návrhu: nepovinný (D2). Predrecenzia: **akceptačný krok** (mení postup všetkých dávok) — slepý recenzent: package proti
  `git diff main...HEAD`, či karta + `rozpracovane.ps1` naozaj stačia na prevzatie a či sa nestratilo pravidlo pri presune v IMPLEMENTATOR.md.
- Pred PR **STOP** a report orchestrátorovi; PR až na pokyn cez `scripts\otvor_pr.ps1`.
- **Mimo rozsahu:** hodnotenia, karty modelov, router, `OBSADENIE.md` (P5), smoke prevzatia a uzáver bloku (P6).

## 5 · Sonda čakania (vyplní orchestrátor pred štartom)

- …

## 6 · Výsledok (vyplní implementátor)

- …
