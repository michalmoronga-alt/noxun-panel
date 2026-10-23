# Blok PRAVIDLA — prieskum sessions 6.–17.10.2026 (surový výstup)

> **Údaj, nie rozhodnutie.** Analytik Claude Sonnet 5.5 (subagent, 18.10.2026, ~306 k tokenov, 6 min) prešiel výťahy 18 sessions
> (skript zhustil záznamy z ~100 MB na 317 kB: správy Michala, texty agenta, volania nástrojov, chyby, subagenti) a 7 retro záznamov
> 27.9.–2.10. Výťahy sú lokálne (scratchpad session 217e20d9), nie v gite. Spracovanie do návrhu: [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 7.
> Skratky sessions = prvých 8 znakov ID (`5cfc` = 5cfc98d1…). Čo vo výťahoch nebolo: texty chýb vnútri subagentov, čas čakania na Codex,
> náklady v EUR.

## 1. Prehľad sessions

| Dátum | Session | Čo sa robilo | Rola / model | Výsledok |
|---|---|---|---|---|
| 6.10. | 298c | PR #464 tabuľka náhradníkov (docs) | orchestrátor Opus, docs písal sám; slepá delta ×2 | hotové; kolo 1 2×P2, delta 2×P2 + 2×P3 |
| 7.–8.10. | 5cfc | matica agentov (#465), prihlásenie Groku, šírka 50 mm (#466), benchmark U002 | orchestrátor Opus; implementátori Sonnet, Opus, Grok; 6 slepých recenzentov | hotové (v0.17.28); 3 GH kolá na #465 (2× P1), 2 pokusy s Astrou na limite, 2× Claude limit |
| 9.10. | 5fc8, 325b | ten istý prompt otvorený 2× zbytočne | – | zbytočné |
| 9.10. | 980c | H17a ExportPrep (#467) | orchestrátor Opus (29 správ omylom na starom modeli); implementátor Opus | hotové (v0.17.29); CI na Linuxe spadlo (golden test, `sort_by`) |
| 10.10. | 2b7c, 7ae9 | slepá predrecenzia a delta H11c (práca Codexu) | slepý recenzent Opus | hotové, ale H11c sa nikdy nezmergovala — zbytočná práca |
| 10.10. | 9759 | Open Code Review + Grok proti 10 starým PR; #468 | orchestrátor Opus; Grok ×20; 3× Opus general-purpose | hotové; Grok chytil 5 z 18 nálezov Codexu; #468 6×P2 |
| 10.10. | e416 | #469 oprava jednej vety | samostatná Opus session | hotové, 0 nálezov, ~16 min |
| 11.10. | c1ba | H11c overenie, Q1 (#470), H17b (#471), H19 export test (#472), uzáver HARDENING (#473) | orchestrátor Opus; implementátori Ľ, S, Ť | hotové v0.18.0; #470, #471, #473 čisté v kole 1 |
| 11.10. | 318f | #474 oprava komentára | samostatná Opus session | hotové, 0 nálezov, 24 min — celý rituál pre komentár |
| 13.–15.10. | 166c, fbac, 6ced | otázky (agy model, reinštalácia PC, brožúra) | Sonnet / Opus | hotové, lacné |
| 15.–16.10. | 97fe, 5196 | smoke HARDENING (67 správ Michala, 25 h, cez bridge) | orchestrátor Opus bez subagentov | rozpracované (~31/94); našlo reálne výrobné chyby (S9, S15) |
| 16.–17.10. | 16e6 | plánovanie bloku UPDATE: koncept, mockup, krížový audit, 5 packages | orchestrátor Opus; 5 packages Opus general-purpose; Codex, Grok | hotové do zásoby; limit Claude aj Codexu, PC sa vypol |
| 17.10. | e6d8 | retro, rešerš AGENTS.md, zadanie bloku PRAVIDLA | orchestrátor Opus; Grok, Codex SOL, agy | rešerš hotová, agy zlyhal |

## 2. Čo musí ktorý agent zvládať

**Orchestrátor (Opus):** čítať STAV/PLAN/package · písať zadania do repa · kvótová brána pred drahými krokmi (7 sessions) · in-SU runner
s `-CloseWhenDone` · merge `--match-head-commit` + inštalácia · handoff do pamäte (5 sessions) · Codex cez companion, Grok cez bridge ·
review thready cez GraphQL · riadiť smoke cez bridge (overiť model, zapísať postreh, odlíšiť chybu od omylu) · vedieť, kedy sa pýtať Michala.
Použité pravidlá: kvóty, `codex-po-pr`, `predrecenzia`, `codex-audit`, číslo PR, brief v repe, paralelná príprava N+1, uzáver čerstvým
subagentom, pravidlo 3 kôl. **Nepoužité / nekonzistentné:** retro (0 záznamov v 18 sessions), inštalácia mainu po docs PR (1 z 4),
ukazovateľ kontextu (nikde).

**Implementátor Ť (Opus):** golden testy, mutácie, schéma 22→23, in-SU PASS, pokračovanie po limite cez SendMessage (raz nepushnutý commit vo worktree).
**Implementátor S (Sonnet high):** H19 — 244 správ, 14 chýb nástrojov, výsledok 2×P2.
**Implementátor Ľ (Sonnet medium):** Q1 a uzáver bloku — obe čisté v kole 1.
**Slepý recenzent (Opus):** lacný (0,1–10 k out); 1× porušil „len čítaj" (`git fetch`); predrecenzia šírky 50 našla 5×P3, nezávislý Codex 3 reálne P2.
**Audítor Codex:** Astra len s úzkym zadaním; sol na krížový audit, deltu a štíhle audity.
**Rešeršér / Grok / agy:** rešerš za ~5 min so zdrojmi; agy v neobsluhovanom režime nevie schváliť vlastný príkaz.
**Review PR (GH Codex):** 👍 neznamená, že kód prešiel na Linuxe (#467).

## 3. Opakujúce sa problémy

| # | Problém | Výskyty | Odkaz |
|---|---|---|---|
| 1 | pravidlá na viacerých miestach → review nachádza zabudnuté kópie | #464 delta 4 miesta; #465 2×P1; #468 6×P2; STAV nad 12 kB | 298c, 5cfc, 9759, 980c |
| 2 | Codex limit — Astra so širokým zadaním minie celé okno | 3 zlyhané pokusy; 2 úzke audity → okno 79 %; GH review na limite | 5cfc, 16e6 |
| 3 | Claude session limit prerušil prácu | 3 incidenty (16.10. naraz 2 sessions + 2 subagenti) | 5cfc, 980c, 5196, 16e6 |
| 4 | auto-režim / bezpečnostný filter zastavil krok | 4× (schtasks, commit čísla PR, prepis nastavení, čítanie natívneho kódu) | 5cfc, c1ba, 5196, 980c |
| 5 | shell / cesta / kódovanie | ~10× (eval, \u escape, medzera v ceste, dlhá cesta, sleep, /tmp, exit 255) | c1ba, 16e6, 9759, 5196, 980c, 298c |
| 6 | číslo PR ako samostatný commit | 9 z 11 PR; 1× blokované, 1× súhlas Michala | c1ba, retro 2.10. |
| 7 | KRONIKA / STAV konfliktné body | #469 vs #468; #407 vs #406 | e416, retro 27.9. |
| 8 | retro sa nezapisuje | 0 záznamov po 2.10. (15 dní, ~14 PR) | e6d8 |
| 9 | rola hlavného okna nebola jasná — agent začal implementovať | 2× | 980c, 5cfc |
| 10 | test v SU a Linux CI sa rozchádzajú | #467 | 980c |
| 11 | duplicitné sessions | 3 identické prompty | 5fc8, 325b, 980c |
| 12 | hlučný smoke checklist | 94 bodov, Michal vyradil 7 („načo mi slúži test starého stavu?") | 5196 |
| 13 | budíky v session (`sleep`, cron) sa strácajú | cron nespustený; `sleep 17460` pretrhnutý výpadkom | 5cfc, 16e6 |
| 14 | disk: `_dev` 3,7 GB, worktrees 0,93 GB | – | fbac |
| 15 | práca nad vetvou, ktorá sa nezmergovala | H11c: 2 sessions slepej kontroly | 2b7c, 7ae9 |

## 4. Odovzdávanie práce

**Fungovalo:** handoff v pamäti s doplnkami · brief a package v repe od štartu · SendMessage na pôvodného implementátora aj po limite ·
zápisník smoke v repe · Codex → Claude cez `_dev\*PRE_CLAUDE*.md` · nová session našla stav zo STAV/PLAN · rovnaké zadanie v súbore pre dvoch providerov.
**Stratilo sa:** session 16e6 dostala len slovo „UPDATE", v PLAN nič — pýtala sa Michala a hľadala staré dokumenty · smoke zápisník len
v lokálnej vetve bez pushu · Codex handoffy v gitignored `_dev` a `.codex` vo worktree (závisia od PC) · úloha 2 od Michala (5cfc) ostala nezadaná.

## 5. Ekonomika

| Session | Out tokeny | Cache read | Úmernosť |
|---|---|---|---|
| 16e6 | 432 k | 112 M | 5 packages do zásoby; hodnota až pri implementácii |
| 5196 | 258 k | 116 M | úmerné (našlo výrobné chyby S9, S15); lacnejšie, keby overovacie body robil agent skriptom |
| 5cfc | 222 k | 69 M | benchmark + 2 PR |
| 980c | 218 k | 57 M | H17a |
| c1ba | 184 k | 54 M | 5 PR, uzáver bloku |
| 9759 | 150 k | 41 M | experiment, prešiel plným review |

- Trivialita: 318f a e416 — po ~7 M cache read a ~25 k out za jeden komentár / vetu, 0 nálezov.
- Docs PR písané orchestrátorom (#464, #468) mali ísť na `implementator-lahky`.
- Astra so širokým zadaním = najhorší pomer (100 % okna, 17 bodov týždňa, bez výsledku).
- Drahý pohľad chýbal: predrecenzia Opus na kóde od Opusu nenašla 3 P2 (našiel Codex); úzky Codex sol dal 4 vážne nálezy, ktoré ostatní prehliadli.

## 6. Hodnotenie modelov (len z dát)

- **Opus 5.5:** spoľahlivý orchestrátor a implementátor Ť; pasce: slepé miesta na vlastnom kóde, platformové rozdiely (Linux).
- **Sonnet 5.5:** Ľ a S fungujú (#470, #473 čisté; #472 2×P2); na ťažkej dávke (U002) skóre 3 vs. 4; dobrý ako tenký obal.
- **Haiku:** `claude-code-guide` tvrdil nesprávne, že effort sa pri volaní nedá nastaviť → skončilo vo WORKFLOW, oprava #469.
- **Codex Astra:** hlboké audity len pri úzkom zadaní; široké zadanie zjedlo okno.
- **Codex sol:** audit šírky 50 za ~5 min (1 BLOCKER + 4 FIX), krížový audit za 8 % okna — najlepší pomer cena / nález.
- **GH Codex review:** kolo 1 čisté pri 6 z 11 PR; najviac nálezov pri pravidlách a výrobnom kóde; nechytá platformové rozdiely.
- **Grok 4.7:** shadow šírky 50 — 1. miesto v slepom hodnotení Codexu; rešerš ~5 min; ako recenzent 5 z 18 nálezov (presný, nízka úplnosť);
  nestabilné prihlásenie, bridge nevypíše spotrebu. Michal: „research + implementácia áno, audity nie, bench 7/10".
- **agy:** 17.10. zlyhal v neobsluhovanom režime.

## 7. Návrhy analytika (zoradené podľa prínosu)

1. Zmenšiť a rozdeliť pravidlá (jadro AGENTS.md, rola v definícii roly, WORKFLOW ako mapa, história do archívu).
2. Retro hook po merge + povinný riadok „Postrehy" (odstrániť „voliteľné").
3. Pravidlo pre veľkosť Codex zadaní (súbory + riadky, predvolene sol, zastaviť pri > 30 % okna).
4. Skript na doplnenie čísla PR namiesto ručného commitu.
5. KRONIKA bez konfliktov (záznam dávky ako samostatný súbor, zlúčenie pri uzávere bloku).
6. Pomocné skripty (JS testy jedným príkazom, runner berie model z hlavného checkoutu, `gh` obal s `--body-file`).
7. Rýchla trieda pre komentár alebo vetu (bez STAV, Sonnet) — rozhodne Michal.
8. Predvolená rola hlavného okna = orchestrátor (prvá veta pravidiel orchestrátora).
9. Skorá kontrola CI vetvy pred predrecenziou; v testoch zakázať závislosť na poradí.
10. Smoke: Michal najprv škrtne nerelevantné body, overiteľné body robí agent cez bridge.
11. Experimenty a benchmarky s ľahkou bránou (CI + 1 slepý pohľad).
12. Zadanie novej session vždy s cestou k dokumentu so zámerom a pushnutou vetvou.
13. Budíky cez Monitor / plánovač, nie `sleep`.
14. Upratanie `_dev` a worktrees pri uzávere bloku.
15. Pred kontrolou prevzatej vetvy overiť, či je dávka ešte relevantná.
