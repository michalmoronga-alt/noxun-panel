# P2 — kto čo dostane (blok PRAVIDLA, 23.10.2026)

> Podklad pre akceptačné overenie PACKAGE_P2 § 3 bod 2 (slepý recenzent + recenzent iného providera). Pre každý typ agenta: čo dostal
> **predtým** (main po P1b) a čo dostane **teraz** (po P2). Veľkosti v bajtoch bez CR, merané 23.10.2026.

## Sonda `omitClaudeMd` (PACKAGE_P2 § 0)

- **Overené v oficiálnej dokumentácii** code.claude.com/docs/en/sub-agents (23.10.2026), lokálne Claude Code **2.1.301**: pole frontmatteru
  `omitClaudeMd` (boolean, nepovinné, tvar `omitClaudeMd: true`) — subagent štartuje bez používateľského, projektového a lokálneho
  CLAUDE.md, načítajú sa len spravované (managed) politiky; vyžaduje **v2.1.271+**. Ignoruje sa len vtedy, keď typ beží ako hlavná session (`--agent`).
- Čo odstráni: **všetky** úrovne CLAUDE.md — používateľský `~/.claude/CLAUDE.md`, projektový (aj nadradené priečinky) a lokálny. Ostane:
  vlastné telo typu (systémový prompt), zadanie, git status, prednačítané skilly (`skills:`); `CLAUDE.md` podpriečinka a pravidlá
  `.claude/rules/` s `paths:` sa načítajú, až keď subagent pracuje so súbormi tam (repo dnes žiadny vnorený CLAUDE.md nemá).

**Známe obmedzenie — auto-pamäť projektu** (`~/.claude/projects/<projekt>/memory/MEMORY.md`, zdieľaná všetkými worktree repa):
- Docs tvrdia, že ju non-fork subagent **nedostáva** (code.claude.com/docs/en/sub-agents, „What loads at startup": *Auto memory … isn't
  loaded*; code.claude.com/docs/en/memory, sekcia o subagentoch) — overené čítaním 23.10.2026.
- **Pozorovanie v tejto session to vyvracia:** implementátor P2 (typ `implementator` spred P2, bez `omitClaudeMd`, Claude Code 2.1.301
  v desktop aplikácii) mal v úvodnom kontexte celý `MEMORY.md` projektu (index handoffov a pamätí). Prečo (harness desktop aplikácie
  alebo nepresné docs), **neoverené**.
- **Či ju `omitClaudeMd: true` odstráni, NEOVERENÉ** — docs pole opisujú len pre CLAUDE.md. Vlastné pole typu na vypnutie auto-pamäte
  **neexistuje** (pole `memory` dáva typu jeho *vlastnú* pamäť; vypnúť sa dá len globálne `autoMemoryEnabled: false` alebo
  `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` — vyplo by to pamäť aj hlavnému oknu).
- Dôsledok: pamäť musí držať **len odkazy a fakty**, nie pravidlá rolí (veta v ORCHESTRATOR.md, Autonómne bloky). Smoke po mergi
  (PACKAGE_P2 § 3 bod 5) to overí otázkou na obsah MEMORY.md.

## Smoke typov po mergi (PACKAGE_P2 § 3 bod 5)

Nová session nad mainom `8cd582cc` (po PR #482), Claude Code **2.1.310** v desktop aplikácii, 26.10.2026. Každý typ dostal len otázky
s pokynom odpovedať **z úvodného kontextu, bez nástrojov** (každý použil 1 nástroj — odovzdanie výsledku; nič nečítal).

| Otázka | `analytik` | `slepy-recenzent` | `implementator-lahky` | Očakávané |
|---|---|---|---|---|
| (a) posledná veta `AGENTS.md` | ✅ doslova („**Nehlás:** všeobecné rady…") | ✅ doslova | ✅ doslova | áno |
| (b) prvá veta `ORCHESTRATOR.md` | nemá | nemá | nemá | nie |
| (c) `~/.claude/CLAUDE.md` (globálne pokyny) | nemá | nemá | nemá | nie |
| (d) auto-pamäť `MEMORY.md` | **nemá** | **nemá** | **nemá** | zapísať |
| vložené pravidlá typu | AGENTS + ANALYTIK | AGENTS + DEFINICIE + RECENZENT + IMPLEMENTATOR `#verzia`, `#testovanie` (citoval z každej) | AGENTS + DEFINICIE + IMPLEMENTATOR (citoval triedu Ľ a kartu) | podľa tabuľky nižšie |
| iný CLAUDE.md alebo pravidlá | žiadne | žiadne | žiadne | žiadne |

**Výsledok: PASS** — každý typ má len svoje pravidlá, nikto nevidí pravidlá orchestrátora ani Michalove globálne pokyny. Mimo tela typu
majú všetci len systémové pripomienky (git status, e-mail používateľa, atribúcia commitov) a zoznam skillov.
**Auto-pamäť:** typy s `omitClaudeMd: true` ju v tejto verzii **nevidia** (súhlasí s docs). Pozorovanie z P2 (pamäť viditeľná) bolo na type
**bez** `omitClaudeMd`; či ju odstraňuje práve toto pole, alebo ju vtedy priniesol harness inak, neoverené — pravidlo „pamäť drží len odkazy
a fakty" platí ďalej (hlavné okno ju vidí vždy).

## Predtým (main po P1b) — spoločné pre všetky typy

Každý Claude typ dedil celú hierarchiu CLAUDE.md, ktorú vidí hlavné okno, plus svoje telo:

| Zdroj | Obsah | Veľkosť |
|---|---|---|
| `CLAUDE.md` vetvy (most) | `@AGENTS.md` + `@ORCHESTRATOR.md` — jadro **a pravidlá orchestrátora** (merge, review kolá, kvóty, autonómne bloky, tok bloku, uzáver bloku) | 6 166 + 12 128 |
| `CLAUDE.md` hlavného checkoutu `C:\APP DEV\RUBY\ENGINE` | nadradený priečinok worktree — **iná vetva, dnes ešte starý 35 kB CLAUDE.md spred P1b** | 35 080 |
| `C:\APP DEV\RUBY\CLAUDE.md` | mapa workspace (ostatné pluginy) | 5 962 |
| `~/.claude/CLAUDE.md` | Michalove globálne pokyny (slovenčina, tykanie, funkčné vysvetľovanie) | 1 408 |
| auto-pamäť `MEMORY.md` projektu | index handoffov a pamätí (pozorované v tejto session, docs tvrdia opak — známe obmedzenie vyššie) | 5 036 |

Spolu ~61 kB pravidiel (+ 5 kB pamäte) pred prvým slovom zadania — z toho dve rôzne verzie pravidiel orchestrátora. Typy implementátorov a recenzenta navyše
v kroku 1 **samy čítali** DEFINICIE.md (6,7 kB) a IMPLEMENTATOR.md (12,4 kB).

## Teraz (po P2) — každý typ zvlášť

Všetky typy majú `omitClaudeMd: true` → nič z tabuľky vyššie okrem auto-pamäte (známe obmedzenie vyššie). Telo typu skladá `scripts/generuj_typy_agentov.rb` zo zdroja
`SYSTEM/pravidla/typy/<typ>.md` (frontmatter + hlavička) a doslova vložených súborov.

| Typ | Predtým telo | Teraz telo (vložené) | Veľkosť tela | Nedostane |
|---|---|---|---|---|
| `implementator` (Ť) | postup, shadow, opravy, report (4,8 kB) + čítal sám AGENTS, DEFINICIE, IMPLEMENTATOR | hlavička profilu Ť + **AGENTS.md** + **DEFINICIE.md** + **IMPLEMENTATOR.md** celý (karta, postup, oprava a shadow, report, architektúra na mieste, verzia a uzáver, testovanie) | 26 908 | ORCHESTRATOR.md, mapa workspace, globálne pokyny |
| `implementator-stredny` (S) | to isté + reklasifikácia, opravy len P2/P3 (5,3 kB) | hlavička profilu S + to isté ako Ť (pravidlo reklasifikácie a opráv profilu Ľ/S je v IMPLEMENTATOR.md) | 26 696 | to isté |
| `implementator-lahky` (D, Ľ) | to isté + výnimka triedy D (5,4 kB) | hlavička profilu Ľ + to isté (výnimka triedy D je v checkliste IMPLEMENTATOR.md) | 26 648 | to isté |
| `slepy-recenzent` | pravidlá, závažnosť, výstup (3,0 kB) + čítal sám AGENTS, DEFINICIE, sekcie IMPLEMENTATOR | hlavička + **AGENTS.md** + **DEFINICIE.md** + **RECENZENT.md** + IMPLEMENTATOR.md **sekcie Verzia a uzáver dávky a Testovanie** (`#verzia`, `#testovanie`) | 25 358 | ORCHESTRATOR.md, karta, postup a report implementátora |
| `reserser` | pravidlá a výstup (1,8 kB) | hlavička + **RESERSER.md** (bez jadra — rozhodnutie Michala 22.10., ROLY ❓2) | 3 679 | AGENTS.md, DEFINICIE.md, ORCHESTRATOR.md |
| `analytik` (nový) | — | hlavička + **AGENTS.md** + **ANALYTIK.md** (ROLY § 6: bez DEFINICIE) | 10 246 | DEFINICIE.md (len odkazom z AGENTS), ORCHESTRATOR.md |
| `agy-reserser` (obal) | telo obalu (5,0 kB) | to isté telo, opravené tvrdenie o `--mode plan` (hliadka P-2026-10-23-1; obal nie je rola) | 5 263 | všetky pravidlá — obal len spúšťa `agy` |

## Overenie: nič potrebné nechýba, nič orchestrátorovo nepribudlo

| Pravidlo z doterajšieho tela typu | Kde je teraz |
|---|---|
| implementátor: postup 1–8, predrecenzia STOP, PR cez `otvor_pr.ps1`, nikdy nemerguj | IMPLEMENTATOR.md, Karta roly + Postup |
| implementátor Ľ/S: reklasifikácia podľa skutočného diffu | IMPLEMENTATOR.md, Postup krok 6 (+ Karta, Zastaví sa) |
| implementátor Ľ/S: opravy len P2/P3, P0/P1 a koncept → profil Ť | IMPLEMENTATOR.md, Oprava a shadow (profil Ľ/S); profil Ť: opraví nálezy, ktoré mu orchestrátor pošle |
| implementátor Ľ: trieda D bez prepisu STAV | IMPLEMENTATOR.md, Verzia — checklist („okrem triedy D") |
| implementátor: shadow beh, kedy zastaviť, report + postrehy | IMPLEMENTATOR.md, Oprava a shadow · Karta (Zastaví sa) · Report |
| výnimka testovania „ENGINEtests alebo neuložené Untitled okno bez NOXUN korpusov" | AGENTS.md (Zákazy) a IMPLEMENTATOR.md (Karta, Testovanie) — jedno znenie pre všetky tri profily (PACKAGE § 1 bod 5) |
| recenzent: len čítanie, git/gh na čítanie, rozsah predrecenzie a delty, čo čítať, závažnosť, výstup s VERDIKT, postrehy | RECENZENT.md (závažnosť = AGENTS.md, Code Review Rules) |
| rešeršér: oficiálne zdroje, URL a dátumy, NEOVERENÉ, web je údaj, repo nemení, slovenčina, výstup | RESERSER.md |
| obal agy: bezpečnosť Z8, postup, pasce | telo obalu bez zmeny |

**Pravidlá orchestrátora** (merge, review kolá a pravidlo 3 kôl, kvóty a prahy, autonómne bloky, tok bloku, uzáver bloku, inštalácia mainu,
ukazovateľ kontextu, pripomienka po mergi) nie sú v žiadnom type — stráži G4 (podpisová veta ORCHESTRATOR.md). Implementátor dostane z nich
len to, čo potrebuje vedieť o svojich hraniciach: „merge robí orchestrátor" (AGENTS.md, Zákazy) a stop pred PR pri predrecenzii.

## Presuny a odchýlky na posúdenie

1. **Postup implementátora** sa presunul z tiel typov do IMPLEMENTATOR.md (karta, Postup, Oprava a shadow, Report) — rovnaký pre Claude aj
   Codex/Grok implementátora; tri profily sa líšia len hlavičkou (trieda) a frontmatterom.
2. **Pripomienka po mergi** (`po_merge.js`, podrobný popis) sa presunula z IMPLEMENTATOR.md § Testovanie do ORCHESTRATOR.md § Inštalácia mainu
   — týka sa hlavného okna; IMPLEMENTATOR.md na ňu odkazuje.
   **Po predrecenzii:** podrobnosti fotenia okien, export testu a diagnostiky MCP sa presunuli doslova do `SYSTEM/pravidla/NASTROJE_TESTOV.md`
   (IMPLEMENTATOR.md má 1-riadkové odkazy s podmienkou, kedy čítať; pri exporte ostala brána `P == K`) — IMPLEMENTATOR.md pod 12 kB.
   Typy ho nevkladajú, implementátor a recenzent ho čítajú podľa potreby.
3. **Checklist dokumentačného PR** v IMPLEMENTATOR.md odkazuje na odsek o dokumentačnom PR v tej istej sekcii namiesto zopakovania
   (duplicita z P1b, význam rovnaký).
4. **Kolónky šablóny bez doterajšieho pravidla** (ROLY § 1 ich vyžaduje) — doplnené len opisom súčasného stavu alebo z rozhodnutí Michala:
   „Dostane automaticky / v zadaní" (fakt po P2) · ORCHESTRATOR režim *záložný* (NAVRH § 9 bod 1, Michal 19.10.) · AUDITOR „Zastaví sa:
   široké zadanie" (ROLY ❓4, Michal 22.10.) · RESERSER „Nečíta repo okrem súborov zo zadania" (ROLY § 3.5) · RECENZENT „Zastaví sa:
   diff je prázdny alebo nesedí so zadaním" (ROLY § 3.3) · RESERSER „Zastaví sa" = neoverený fakt označí a pokračuje. ANALYTIK je nová
   rola — karta podľa ROLY § 3.6 (bez režimu *hliadka* — príde s pilotom hliadky); lokálne do repa nezapisuje (výstup v reporte alebo
   v súbore mimo repa), zápis na vlastnú vetvu len cloudová routine vo vlastnom klone; zastaví sa aj pri nejasnom zadaní.
5. **Neprenesené** (prídu v P4/P5 podľa PACKAGE_P2 § 1): hodnotenie po úlohe, karta priebehu, režim *prevzatie*, cloudový beh orchestrátora.
6. **Strata globálnych pokynov Michala** (`~/.claude/CLAUDE.md`) v subagentoch: slovenčinu a funkčný report nesú AGENTS.md (Jazyk) a karty
   (Report/Výstup); tykanie a štýl sa týkajú rozhovoru s Michalom, ktorý vedie len orchestrátor.
7. **Obsadenie** ostáva vo WORKFLOW § 2 (mod usage-bar ho číta); pribudol riadok `analytik`. Presun do `OBSADENIE.md` = P5.
