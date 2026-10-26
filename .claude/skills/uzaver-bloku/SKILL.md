---
name: uzaver-bloku
description: Uzáver bloku (variant B) krok za krokom — vetva release/<blok>, minor bump, blok do archívu, presun priečinka bloku, záverečný dokument so smoke checklistom, V1_VIZIA, README, STAV, KRONIKA, a upratanie po uzávere (zoznam kandidátov, maže sa len so súhlasom Michala). Použi hneď po poslednej dávke bloku; pri plnom kontexte orchestrátora uzáver skladá čerstvý subagent len z repa. Vedenie smoke po uzávere je skill smoke.
---

# Uzáver bloku

Uzáver ide **hneď po poslednej dávke bloku** (variant B): minor verzia, smoke checklist v archíve, smoke robí Michal až potom. **Poistka:**
nový blok sa začína až po Michalovom **smoke PASS** alebo výslovnom **„ideme ďalej"**; nálezy zo smoke sú opravy x.y.z (skill `smoke`).
Záložný orchestrátor uzáver bloku nemerguje (ORCHESTRATOR.md, Karta roly).

## Kto skladá

- **Orchestrátor**, keď má kontextu pod ~70 %.
- **Čerstvý subagent len z repa** (PLAN, KRONIKA, DOGFOODING, PR), keď má orchestrátor pred uzáverom viac ako ~70 % kontextu; orchestrátor
  výsledok skontroluje a zmerguje. Čo subagent v repe nenájde, žilo len v chate — orchestrátor to doplní do zadania.

## Postup (vetva `release/<blok>`)

1. **Minor bump** — `VERSION` 2× + všetky `?v=` v `ui/*.html` ([IMPLEMENTATOR.md](../../../SYSTEM/pravidla/roly/IMPLEMENTATOR.md#verzia)). Uzáver
   je dokumentačná dávka s verziou: kód pluginu sa nemení.
2. **Hotový blok z `SYSTEM/PLAN.md` plným textom** do `SYSTEM/archiv/ROADMAP_hotove_etapy.md`. V PLAN ostávajú len nehotové bloky a trvalé
   pravidlá; riadky dávok bloku (s ✅ a číslom PR) odchádzajú spolu s blokom.
3. **Celý priečinok bloku** `SYSTEM/zdroje/bloky/<BLOK>/` → `SYSTEM/archiv/bloky/<BLOK>/` (`git mv`) + **kontrola odkazov**: Grep na starú
   cestu v `SYSTEM/`, `docs/`, `.claude/` a v komentároch testov; odkazy z presunutých dokumentov na `zdroje/` prepíš na nové úrovne.
   Mockupy v `SYSTEM/zdroje/ui20/` sa nepresúvajú.
4. **Záverečný dokument** `SYSTEM/archiv/<BLOK>_ZAVER_<dátum>.md` (vzor: `SYSTEM/archiv/HARDENING_ZAVER_2026-10-11.md`): výsledok pre stolára,
   dávky, overenie, aktualizácia pluginu, priznané limity, otvorené body a **smoke checklist bloku** (krok 5).
5. **Zostavenie smoke checklistu** do záverečného dokumentu (sekcia „Smoke checklist bloku"): zlúč sekcie „Smoke" zo všetkých packages
   bloku a čakajúce D-čísla, odstráň duplicity, body zoraď **po skupinách s ID** a na konci doplň tabuľku „zdroj → čísla bodov" na kontrolu
   úplnosti. Formát skupín a bodov: skill `smoke`.
6. **V1_VIZIA, README, STAV, KRONIKA** — aktualizuj podľa checklistu uzáveru dávky v IMPLEMENTATOR.md (STAV sa prepisuje, KRONIKA dostane odsek
   navrch). Skupina „smoke po uzávere" v `SYSTEM/DOGFOODING.md` je dočasná — založ ju s prvým nálezom a zanikne s posledným.
7. PR, review a merge ako pri dokumentačnej dávke (skill `codex-po-pr`; číslo PR doplní `scripts\otvor_pr.ps1`).

## Upratanie po uzávere

Po mergi uzáveru sa nahromadené súbory lokálne upratujú — `_dev` môže mať niekoľko GB, worktrees okolo 1 GB a dlhé cesty worktrees robia
chyby „cesta príliš dlhá". **Nič sa nemaže samo a nič bez súhlasu Michala.**

1. **Orchestrátor vypíše zoznam kandidátov s veľkosťou** (najväčšie hore), nič nemaže:
   - veľké run kópie a dočasné modely v `_dev` (kópie modelov z behov testov a fotenia, zálohy inštalácií, surové výstupy auditov, logy),
   - worktrees zmergovaných vetiev (`git worktree list`, vetva je zmergovaná do `main`).
2. **Nikdy sa nenavrhujú:** `_dev\ENGINEtests.skp`, Michalove zákazky a smoke modely (modely, ktoré sa použijú v smoke bloku, ostávajú do
   smoke PASS).
3. **Maže sa až po súhlase Michala**, položku po položke alebo podľa skupín, ktoré Michal výslovne potvrdí.
4. **Worktree len cez `git worktree remove <cesta>` a `git worktree prune`** — nikdy mazaním priečinka.
