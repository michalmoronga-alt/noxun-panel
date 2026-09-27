# Retro — vyhodnotenie 27.9.2026 · blok 7 KONŠTRUKCIA K1+K2 (prvý záznam pokusu)

> Stav: **spracované** — hodnotenie orchestrátora po uzávere bloku 7 (v0.14.0) a rozhodnutia Michala z 27.9.2026. Prijaté body sú zapracované
> v pravidlách workflowu (CLAUDE.md, `SYSTEM/WORKFLOW.md`, skill `codex-audit`) — tento súbor je záznam „prečo", nie autorita.

## Beh

Blok 7 za jeden deň od debaty po uzáver: PR #400 (podklady), #401 KON-0, #402 KON-A, #403 KON-B, #404 KON-D, #405 uzáver; zavreté PR #398 a #399
(pravidlo 3 kôl). Testy 4549 → 4643 headless, 131 → 134 JS sád, 3111 → 3172 in-SU (stále 0 FAIL). Codex weekly 16 % → 32 %; Claude session raz
na 80 % (čakanie na reset 24 min).

## Čo fungovalo — nemeniť

- **Audit návrhu pred kódom** — každá väčšia dávka mala skutočný BLOCKER vyriešený ešte na papieri (KON-0 samostatné chrbty, KON-A miznúce police
  pri veľkom komíne, KON-D zápis knižnice šablón zo zálohy). KON-B, KON-D a uzáver potom prešli GH review na prvý raz bez nálezov.
- **Package ako jediná autorita dávky** + surový audit v priečinku bloku — implementátor mal všetko na jednom mieste, reporty priznávali odchýlky.
- **Slepá predrecenzia** — v 4 dávkach 0× P1/P2, len P3; lacná (~3 % session).
- **Delta namiesto nového GH kola** pri P2 (KON-A) — ušetrené kolo.
- **Opravy robí pôvodný implementátor** (2–6 min) · **fakty z kódu cez Explore pred písaním package** (presné riadky, šetrí kontext orchestrátora) ·
  auto-fix monitor + budíky · in-SU runner s `-CloseWhenDone` · pravidlo „Claude session > 80 %" · priebežný handoff (po `/compact` bez otázok).

## Problémy (konkrétne udalosti)

1. **Štart bloku stál ~3 hodiny:** PR #398 a #399 niesli technické vzorce v úvodnom dokumente bloku → každé Codex kolo P1 → zavreté podľa pravidla 3 kôl.
2. **Chyby v packages, ktoré mohol chytiť orchestrátor sám:** „pri komíne 0 sa nič nemení" neplatilo (pravidlo výstuh by odmietlo platnú skrinku) ·
   „nečíselné → 0" s odkazom na vzor `.to_f`, ktorý to nerobí · osadenie chladničky „≥ 14" namiesto „14–24". Príčina: tvrdenia z úvahy, nie zo sondy.
3. **In-SU nebežal na finálnej hlave** (KON-A, B, D — neskoršie commity len JS, texty, docs) — v poriadku podľa pravidiel, ale bol to zakaždým úsudok.
4. Drobnosti nástrojov: Python heredoc v Git Bash pokazil spätné lomky (2×) · `cd` do worktree implementátora (neškodné, ale riziko gitu v zlom checkoute) ·
   hook kódovania hlási legitímne veľké slovenské písmená (slovo „pamäť" veľkými) ako mojibake (samostatná úloha).
5. **Tempo Codexu** — 16 % týždenného limitu za deň („nevydrží do resetu").
6. **Otvorený bod mockupu** („delenie čiel — návrh, potvrdí Michal") sa neuzavrel pri schvaľovaní → otázka prišla až po implementácii; neskoršia zmena
   seedu sa do existujúcich knižníc sama nedostane.

## Návrhy a rozhodnutia Michala (27.9.2026)

| # | Návrh | Rozhodnutie |
|---|---|---|
| 1 | Úvodné PR bloku = len rozhodnutia Michala a mockup (+ fakty, surové audity); technické požiadavky výhradne v packages s auditom návrhu | **áno** |
| 2 | Sonda pred auditom — orchestrátor overí kľúčové tvrdenia package krátkou sondou na kóde pred `codex-audit` | **áno** |
| 3 | Pri schvaľovaní mockupu musí každé „návrh — potvrdí Michal" dostať odpoveď pred packages; zmeny po schválení do mockupu aj ROZHODNUTÍ | **áno** |
| 4 | Jasné pravidlo: in-SU netreba opakovať na hlave, ktorej neskoršie commity nemenia Ruby spúšťače (len JS, texty, docs, testy); PR uvedie hlavu behu | **áno** |
| 5 | Rozpočet Codexu na blok (model auditora podľa triedy, strop) | nie |
| 6 | Paralelná príprava — počas implementácie dávky N package a audit dávky N+1; implementácia ostáva sekvenčná | **áno** |
| 7 | Skorší smoke po prvej výrobnej dávke | nie |

**Nový pokus (Michal):** retro záznamy po každom behu — lokálny inbox, vyhodnotenie na pokyn Michala, pokus do 11.10.2026 (pravidlá v `SYSTEM/WORKFLOW.md`).
