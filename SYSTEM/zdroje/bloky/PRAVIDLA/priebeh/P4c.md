# Priebeh dávky P4c — prevzatie práce

Zadanie: [PACKAGE_P4c.md](../PACKAGE_P4c.md)
Trieda: S
Vetva: feat/p4c-prevzatie
Základ: 80ef3114 (main po P4b, PR #485)
Stav: aktívna
Ďalší krok: prepísať pravidlá (IMPLEMENTATOR, ORCHESTRATOR, usage, codex-po-pr, uzaver-bloku, ANALYTIK, hlavička KRONIKY), potom záznam KRONIKY, PLAN a STAV.
Robil: Claude · Sonnet 5.5 (implementator-stredny)

## Hotové kroky

- [x] vetva zlúčená s čerstvým `origin/main` (po P4b)
- [x] šablóna karty `SYSTEM/pravidla/sablony/PRIEBEH.md` a táto karta
- [x] `scripts/lib/nx_text.ps1` (To-SafeLine zo `start_okna.ps1`) a `scripts/rozpracovane.ps1`, napojenie na `start_okna.ps1`
- [ ] KRONIKA po súboroch: hotové `otvor_pr.ps1`, `nx_pr.ps1`, `straz.js`, test zhody; ostáva hlavička KRONIKY a skill `uzaver-bloku`
- [ ] pravidlá: `IMPLEMENTATOR.md` (karta, G10, KRONIKA po súboroch), `ORCHESTRATOR.md` a skill `usage` (jedna veta), `codex-po-pr` (čakanie na review)
- [ ] `session_digest.rb`, fixtúra a test hotové; ostáva veta v `ANALYTIK.md` a `ruby scripts/generuj_typy_agentov.rb`
- [ ] testy: guard karty, `rozpracovane.ps1`, `session_digest.rb`, G1 až G4, headless a JS sady
- [ ] záznam KRONIKY `kronika/P4c.md`, PLAN, STAV
- [ ] CI pushnutej hlavy zelené, report, návrh PR popisu

## Otvorené otázky

- žiadne

## Brány

- [x] audit návrhu: nepovinný (nie je D2)
- [ ] testy: headless + JS (in-SU netreba, kód pluginu sa nemení)
- [ ] CI pushnutej hlavy zelené
- [ ] predrecenzia: akceptačný krok, spúšťa orchestrátor po reporte
- [ ] PR · review: až na pokyn orchestrátora cez `scripts\otvor_pr.ps1`
