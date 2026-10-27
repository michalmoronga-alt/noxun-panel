# Priebeh dávky P4c — prevzatie práce

Zadanie: [PACKAGE_P4c.md](../PACKAGE_P4c.md)
Trieda: S
Vetva: feat/p4c-prevzatie
Základ: 93cae30d44cfb6f1cf5886d45f4aeef880593790 (main, z ktorého vznikla vetva s packageom; do vetvy zlúčený main 80ef311455f90f74d75fae4b7b20ac74a5f59e15 po P4b)
Stav: aktívna
Ďalší krok: počkať na zelené CI pushnutej hlavy po oprave z predrecenzie a vrátiť report orchestrátorovi (STOP pred PR).
Robil: Claude · Sonnet 5.5 (implementator-stredny)

## Hotové kroky

- [x] vetva zlúčená s čerstvým `origin/main` (po P4b)
- [x] šablóna karty `SYSTEM/pravidla/sablony/PRIEBEH.md` a táto karta
- [x] `scripts/lib/nx_text.ps1` (To-SafeLine zo `start_okna.ps1`) a `scripts/rozpracovane.ps1`, napojenie na `start_okna.ps1`
- [x] KRONIKA po súboroch: `otvor_pr.ps1`, `nx_pr.ps1`, `straz.js` (+ test zhody), hlavička KRONIKY, skill `uzaver-bloku`
- [x] pravidlá: `IMPLEMENTATOR.md` (karta, G10, KRONIKA po súboroch; Architektúra na mieste presunutá do `.claude/rules/kod.md`), `ORCHESTRATOR.md` a skill `usage` (jedna veta), `codex-po-pr` (čakanie na review)
- [x] `scripts/session_digest.rb`, fixtúra a test, veta v `ANALYTIK.md`, typy agentov vygenerované
- [x] testy: guard karty, `rozpracovane.ps1`, `session_digest.rb`, headless 5470/0/0 a JS 165 sád PASS
- [x] záznam KRONIKY `kronika/P4c.md`, PLAN, STAV
- [x] predrecenzia (hlava 9a187aff): opravené P2 1–3 a P3 4–10 (G10 s run-id, sha hlavy PR zo `gh pr view`, karta mimo bloku, stav `v review`, zastarané tvrdenia o KRONIKE, stráž `session_digest.rb`, § 6 packageu)
- [ ] CI pushnutej hlavy zelené, report, návrh PR popisu

## Otvorené otázky

- žiadne

## Brány

- [x] audit návrhu: nepovinný (nie je D2)
- [x] testy: guard karty, `rozpracovane.ps1`, `session_digest.rb`, headless 5470/0/0 a JS 165 sád PASS
- [ ] CI pushnutej hlavy zelené
- [ ] predrecenzia: akceptačný krok, spúšťa orchestrátor po reporte
- [ ] PR · review: až na pokyn orchestrátora cez `scripts\otvor_pr.ps1`
