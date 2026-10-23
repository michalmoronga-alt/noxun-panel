# Blok PRAVIDLA — porovnanie rešerší (17.10.2026, orchestrátor)

Zdroje: [RESERS_GROK.md](RESERS_GROK.md) (Grok Build `grok-4.7`, 5 min) · [RESERS_CODEX.md](RESERS_CODEX.md) (Codex `gpt-6.1-sol`, effort medium, ~5 min).
Antigravity (`agy`) **nedobehol** — v headless režime chcel spustiť príkaz, povolenie nebolo kde potvrdiť, výstup prázdny (ochrana sa nevypínala).
Je to **údaj, nie rozhodnutie**; zhody oboch zdrojov sú silnejší signál než tvrdenie jedného. Kľúčové tvrdenia o Claude Code treba pred
návrhom štruktúry overiť krátkou sondou na lokálnej verzii (2.1.299).

## Zhoda oboch (silný signál)

| # | Zistenie | Čo to znamená pre nás |
|---|---|---|
| Z1 | AGENTS.md je otvorený štandard (Agentic AI Foundation / Linux Foundation); číta ho Codex, Antigravity, Grok, Cursor; Claude Code od v2.1.277 | univerzálny základ je reálny |
| Z2 | Claude Code **nenačíta AGENTS.md, kým v ceste existuje CLAUDE.md**; odporúčané prepojenie na Windows = tenký `CLAUDE.md` s riadkom `@AGENTS.md` (symlink na Windows zlyháva) | premenovanie nestačí — CLAUDE.md ostane ako jednoriadkový most |
| Z3 | **Import nešetrí kontext** — `@súbor` sa rozbalí hneď na štarte | rozsekanie CLAUDE.md na importy nič neušetrí; šetrí len načítanie podľa cesty, úlohy alebo roly |
| Z4 | **Codex oreže celú reťaz AGENTS.md na 32 KiB** (predvolene) | dnešný CLAUDE.md (35 kB) by Codex review a audit nevidel celý — spodok by vypadol |
| Z5 | Pravidlá podľa cesty: Claude `.claude/rules/*.md` s `paths:` · Codex a GH review vnorené AGENTS.md v podpriečinku · Antigravity `trigger: glob` | pravidlá UI, materiálov, kovania… môžu žiť pri svojom kóde a načítať sa len pri práci s ním |
| Z6 | Skilly (otvorený formát SKILL.md): na štarte len popis (~100 tokenov), telo až pri zhode; odporúčanie < 500 riadkov / ~5 000 tokenov; **popis musí povedať KEDY** — inak sa telo neotvorí | postupy (merge, audit, retro…) patria do skillov; kvalita popisu rozhoduje |
| Z7 | Claude subagent dostane CLAUDE.md/AGENTS.md hlavnej session (okrem vstavaných Explore a Plan); vlastný typ ho môže vypnúť `omitClaudeMd` | roly môžu dostať len svoje pravidlá — implementátor nemusí čítať merge brány |
| Z8 | Anthropic: cieľ **< 200 riadkov** na CLAUDE.md; dlhší súbor sa drží horšie (nie je odseknutý) · xAI: krátke konkrétne vety sa držia spoľahlivejšie | jadro by malo mať ~150–200 riadkov, dnes ~200 hustých riadkov s ~35 kB |
| Z9 | **Text pravidlo nevynúti, hook a CI áno**; strojom kontrolovať to, čo sa nesmie stať ani raz (formát, verzie, testy, chránené súbory) | časť pravidiel presunúť do hookov/CI a z textu vyškrtnúť |
| Z10 | Grok hooky sú **fail-open** (pád hooku príkaz pustí); Codex hook beží až po schválení odtlačku | bezpečnostné brány nestavať len na hookoch — posledná brána CI |
| Z11 | RAG/MCP nie je náhrada pravidiel — agent môže pravidlo „nenájsť"; povinné minimum ostáva statické | potvrdzuje odporúčanie nerobiť databázu pravidiel |
| Z12 | Hook a inštrukčný súbor = kód s právami používateľa → zmeny cez review; tajomstvá nikdy do AGENTS.md/skillov | bezpečnostný rámec bloku |

## Len jeden zdroj (overiť pred použitím)

- **Grok:** Gemini CLI pre jednotlivcov **skončil 18.6.2026**, nástupca Antigravity CLI číta AGENTS.md aj GEMINI.md · Antigravity strop 24 kB/súbor a 20 000 tokenov na vždy zapnuté pravidlá (Codex to potvrdzuje, ale našiel aj staršie 12 000 znakov) · Claude Code `/doctor prompt-audit` (od v2.1.283) hľadá spory, mŕtve príkazy a zastarané vety v pravidlách · CI príklad `cloudposse/atmos` (strop 40 kB CLAUDE.md, 25 kB agenti) · text vložený hookom v tvare rozkazu môže Claude vyhodnotiť ako injection a neposlúchnuť · GH review Codexu číta sekciu `## Code Review Rules`.
- **Codex:** `wshobson/agents` — rozpočty 150/200 riadkov, prekročenie len **warning** · OpenAI interne ~100-riadkový rozcestník + upratovacie PR · pri teste hooku skúšať aj povolený prípad, nie len zakázaný · textové „read-only" v role nie je technický sandbox.

## Rozpory a medzery

- Strop Antigravity: 24 kB (oba) vs. staršie 12 000 znakov (Codex) — verzia dokumentácie; nás sa týka len okrajovo.
- Dedenie AGENTS.md subagentmi Codexu, Antigravity a Groka: **NEOVERENÉ** u oboch.
- „ID pravidiel, archív histórie, jedno pravidlo = jeden domov" ako bežná prax veľkých projektov: **NEOVERENÉ** u oboch — sú to rozumné vlastné zásady, nie štandard.
- Skúsenosť (blog, Grok): strop veľkosti sám nestačí — súbor narastie znova, keď sa doň vracia história → treba aj pravidlo „história do archívu".

## Kostra cieľovej štruktúry (návrh na debatu, nie rozhodnutie)

1. `AGENTS.md` — jadro pre všetky nástroje a roly, ≤ ~200 riadkov a hlboko pod 32 KiB: čo je projekt, jazyk, zákazy, príkazy testov, rozcestník.
2. `CLAUDE.md` — jeden riadok `@AGENTS.md` (+ len to, čo je špecifické pre Claude Code).
3. Pravidlá podľa miesta — `.claude/rules/*.md` s `paths:` a/alebo vnorené `AGENTS.md` (UI, materiály, kovanie, výstupy, testy).
4. Pravidlá podľa roly — v definícii typu agenta (`.claude/agents/`), jadro sa im prípadne vypne (`omitClaudeMd`).
5. Postupy — skilly s presným „kedy".
6. Vynucovanie — hooky a CI testy (vrátane stropu veľkosti súborov pravidiel); čo je vynútené, z textu zmizne.
7. História „prečo" — výhradne archív; v pravidle len platné znenie.

## Ďalší krok

Inventúra pravidiel (nová session): každé pravidlo → kde žije dnes · ktorá rola ho potrebuje · duplicity a rozpory · dá sa vynútiť strojom? ·
cieľové miesto podľa kostry vyššie. Pred ňou krátka sonda na lokálnom Claude Code (Z2, Z3, Z7, `/doctor prompt-audit`).
