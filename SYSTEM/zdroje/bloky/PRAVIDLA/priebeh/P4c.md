# Priebeh dávky P4c — prevzatie práce

Zadanie: [PACKAGE_P4c.md](../PACKAGE_P4c.md)
Trieda: S
Vetva: feat/p4c-prevzatie
Základ: 80ef3114 (main po P4b, PR #485)
Stav: aktívna
Ďalší krok: napísať skripty `lib/nx_text.ps1` a `rozpracovane.ps1` a napojiť ich na `start_okna.ps1`.
Robil: Claude · Sonnet 5.5 (implementator-stredny)

## Hotové kroky

- [x] vetva zlúčená s čerstvým `origin/main` (po P4b)
- [x] šablóna karty `SYSTEM/pravidla/sablony/PRIEBEH.md` a táto karta
- [ ] `scripts/lib/nx_text.ps1` (To-SafeLine zo `start_okna.ps1`) a `scripts/rozpracovane.ps1`, napojenie na `start_okna.ps1`
- [ ] KRONIKA po súboroch: `otvor_pr.ps1`, `nx_pr.ps1`, `straz.js`, test zhody, hlavička KRONIKY, skill `uzaver-bloku`
- [ ] pravidlá: `IMPLEMENTATOR.md` (karta, G10, KRONIKA po súboroch), `ORCHESTRATOR.md` a skill `usage` (jedna veta), `codex-po-pr` (čakanie na review)
- [ ] `scripts/session_digest.rb`, fixtúra a test, veta v `ANALYTIK.md`, `ruby scripts/generuj_typy_agentov.rb`
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
