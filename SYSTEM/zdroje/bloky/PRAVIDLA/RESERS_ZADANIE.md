# Blok PRAVIDLA — zadanie rešerše (17.10.2026)

**Účel:** podklad pre prestavbu pravidiel pre agentov (CLAUDE.md → univerzálny AGENTS.md, jasné pravidlá podľa rolí, menej kontextu,
ochrana proti „pretekaniu" súborov). Rešerš je **údaj, nie rozhodnutie** — rozhoduje Michal po inventúre pravidiel.

## Situácia (bez citlivých údajov)

- Jeden vývojár bez programátorského vzdelania, kód píšu AI agenti (Claude Code ako orchestrátor + subagenti; Codex na review a audit;
  občas Gemini/Antigravity CLI a Grok Build na rešerš). Windows, SketchUp Ruby plugin, GitHub PR workflow s bránami.
- Pravidlá dnes: `CLAUDE.md` 35 kB (načítava sa pri každej správe každej roly), `WORKFLOW.md` 37 kB, 6 typov agentov (~23 kB),
  7 skillov (~50 kB), k tomu architektúra a štandard (stovky kB, čítajú sa po odsekoch podľa tabuľky v CLAUDE.md).
- Problém: dokumentácia je vedená dobre, ale **rastie** — nové pravidlá sa dopisujú s dátumom, nič sa nezlučuje ani neruší; súbory
  „pretekajú", roly dostávajú pravidlá, ktoré pre ne neplatia, malé pravidlá zapadnú (napr. voliteľný retro záznam sa prestal robiť).

## Otázky

**A · Formát a podpora nástrojov**
1. AGENTS.md: aktuálny stav štandardu (kto ho spravuje, špecifikácia). Ktoré nástroje ho čítajú natívne — **Claude Code, OpenAI Codex
   (CLI aj GitHub review), Gemini CLI / Google Antigravity, Grok Build (xAI)** — a ako (koreň, vnorené súbory v podpriečinkoch, poradie,
   limity veľkosti, importy `@súbor`). Ako ho odporúča používať Claude Code (import z CLAUDE.md, symlink, iné)?
2. Pravidlá viazané na cestu alebo typ súboru (path-scoped rules): ktoré z nástrojov vyššie ich podporujú a akou syntaxou
   (napr. `.claude/rules/` s `paths:`, vnorené AGENTS.md, Cursor rules s globmi)?
3. Agent Skills ako otvorený formát (SKILL.md): ktoré nástroje ich čítajú, ako sa načítavajú (len popis vs. celé telo), odporúčaná veľkosť.
4. Pravidlá pre subagentov / roly: ako nástroje odovzdávajú kontext subagentom (dedia CLAUDE.md/AGENTS.md? vlastný systémový prompt?).

**B · Prax proti rastu a zahlteniu**
5. Oficiálne odporúčania (Anthropic, OpenAI, Google, xAI) k „context engineering" pre pamäťové súbory: odporúčaná veľkosť, čo tam patrí
   a nepatrí, postupné načítavanie (progressive disclosure).
6. Ako veľké open-source projekty a tímy bránia rastu AGENTS.md/CLAUDE.md: limity veľkosti v CI, jedno pravidlo = jeden domov,
   ID pravidiel, pravidelné upratovanie, presun histórie do archívu. Konkrétne príklady repozitárov.
7. Hooky a CI namiesto textových pravidiel: ktoré pravidlá sa oplatí vynucovať strojom (Claude Code hooks — PreToolUse, PostToolUse,
   Stop, SubagentStop, UserPromptSubmit; Codex hooks/ekvivalent), skúsenosti, pasce (spomalenie, falošné blokovanie).
8. RAG / MCP server s dokumentáciou vs. statické súbory: kedy sa oplatí, riziká (agent pravidlo „nenájde"), skúsenosti.

**C · Bezpečnosť**
9. Riziká zdieľaných inštrukčných súborov a hookov (prompt injection cez súbory v repe, hooky spúšťajúce príkazy, tajomstvá v AGENTS.md),
   odporúčané opatrenia.

## Formát odpovede

- Po slovensky, ku každej otázke krátka odpoveď + **URL zdroja, dátum zdroja, dátum overenia**.
- Čo oficiálny zdroj nepotvrdí: **NEOVERENÉ**. Rozlíšiť oficiálnu dokumentáciu od blogov a fór.
- Na konci: 3–5 najsilnejších zistení pre náš prípad (funkčne, nie technicky).
