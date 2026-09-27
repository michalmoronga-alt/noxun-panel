---
name: retro
description: Retro záznamy k workflowu (pokus 27.9.–11.10.2026) — ZÁPIS krátkeho postrehu do lokálneho inboxu SYSTEM/retro/inbox/ ako úplne posledný krok behu orchestrátora (po mergi, inštalácii a reporte; ticho = žiadny záznam) a VYHODNOTENIE inboxu na pokyn Michala („vyhodnoť retro") čerstvým subagentom — najviac 3 návrhy zmien s dôkazmi, rozhoduje Michal. Retro nikdy nemení pravidlá samo.
---

# Retro — zápis a vyhodnotenie

**Prečo (Michal 27.9.2026, hodnotenie bloku 7):** pravidlá workflowu sa doteraz menili z pamäte na konci bloku a varovania v pamäti agenta
zapadali. Pokus: postrehy sa zapíšu **hneď po behu ako konkrétne udalosti** s cenou, opakovanie sa spočíta a Michal rozhoduje nad dôkazmi.
Pravidlá pokusu: `SYSTEM/WORKFLOW.md` (časť 9 · Retro); formát záznamu: `SYSTEM/retro/README.md`; prvé vyhodnotenie:
`SYSTEM/archiv/retro/VYHODNOTENIE_2026-09-27_blok7.md`. **Pokus končí 11.10.2026** — potom sa vyhodnotí aj on sám (bod C).

## A · Zápis (orchestrátor, úplne posledný krok behu)

1. **Až keď je všetko ostatné hotové:** posledný merge, inštalácia mainu, report Michalovi. Retro nikdy nezdržiava prácu ani report.
2. **Rozhodni, či je čo zapísať.** Prejdi beh: čo stálo čas, kolo review alebo kvótu navyše · čo zachránilo prácu · postrehy subagentov
   zo sekcií „Postrehy k workflowu" v ich reportoch. Nič konkrétne → **žiadny záznam** (ticho je platný výsledok) a skonči.
3. **Pozri inbox** `SYSTEM/retro/inbox/` v hlavnom checkoute (priečinok vytvor, keď chýba; git ho ignoruje). Pri rovnakom postrehu nepíš nový
   bod — k existujúcemu pripíš `znova <dátum>`.
4. **Zapíš** `inbox/<YYYY-MM-DD>_<téma>.md` podľa formátu v `SYSTEM/retro/README.md`: najviac ~10 riadkov, každý bod = udalosť · čo to
   stálo · voliteľne návrh; aj pozitívne („fungovalo — nemeniť"). Žiadne všeobecné rady, žiadne písanie nasilu.
5. **Necommituj a neotváraj PR** — inbox je lokálny. Do pamäte agenta workflowové varovania nepíš (pamäť = fakty o Michalovi a projekte).

## B · Vyhodnotenie (len na pokyn Michala — „vyhodnoť retro")

1. **Čerstvý subagent** (Agent tool, typ `general-purpose` s `model:` výslovne podľa roly **slepý recenzent** v tabuľke Obsadenie rolí,
   `SYSTEM/WORKFLOW.md`; len číta, nič nemení) — kontext orchestrátora nedostane, len úlohu nižšie. Orchestrátor mu pošle **obsah súborov
   inboxu** (subagent vo worktree inbox nevidí — je git-ignorovaný) a cesty k pravidlám.
2. **Zadanie subagentovi:** prečítaj záznamy inboxu, `CLAUDE.md`, `SYSTEM/WORKFLOW.md` a skilly, ktorých sa postrehy týkajú. Zoskup postrehy
   podľa témy, spočítaj opakovania („znova"), over, či už pravidlo neexistuje. Vráť po slovensky, funkčne (Michal nie je programátor):
   - **najviac 3 návrhy zmien**, každý: čo sa zmení v práci · dôkaz (udalosti, dátumy, počet opakovaní, cena) · kde by pravidlo žilo;
   - **zahodiť** — postrehy bez dôkazu, jednorazové alebo už pokryté pravidlom;
   - **sledovať** — raz videné, zatiaľ bez návrhu.
3. **Michal rozhodne** o každom návrhu (áno / nie / upraviť). Bez jeho odpovede sa nič nemení.
4. **Po rozhodnutí** (orchestrátor):
   - prijaté zmeny → **dokumentačné PR** do pravidiel (CLAUDE.md = záväzné znenie, WORKFLOW.md = mapa, skill = postup; každé pravidlo
     na jednom mieste) cez implementátora podľa bežného workflowu;
   - spracované záznamy zhrnie do `SYSTEM/archiv/retro/VYHODNOTENIE_<YYYY-MM-DD>.md` (vzor: prvé vyhodnotenie — beh, čo fungovalo,
     problémy, tabuľka návrhov s rozhodnutím Michala) v tom istom PR a spracované súbory z inboxu odstráni.

## C · Koniec pokusu (11.10.2026)

Pri vyhodnotení k 11.10.2026 subagent navyše zhrnie samotný pokus: koľko záznamov vzniklo, koľko návrhov Michal prijal, koľko to stálo
(čas orchestrátora, kvóta subagentov) a či niektorý prijatý návrh už ušetril kolo či čas. Michal rozhodne: **ponechať, upraviť alebo zrušiť**.
Pri zrušení sa pravidlá pokusu (WORKFLOW.md časť 9, veta v CLAUDE.md, sekcia v typoch agentov, tento skill) odstránia dokumentačným PR;
archív vyhodnotení ostáva.
