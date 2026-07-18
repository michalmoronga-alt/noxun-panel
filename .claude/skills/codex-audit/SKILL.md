---
name: codex-audit
description: Nezávislý Codex audit návrhu PRED implementáciou (devil's advocate). Povinný pred každou dávkou/iteráciou. Odošle návrh do lokálneho Codex CLI, počká na dobehnutie a vráti číslované nálezy BLOCKER/FIX/NOTE.
---

# Codex audit návrhu (devil's advocate)

Povinný krok pred implementáciou každej dávky/iterácie (pravidlo z 18.7.2026). Beží cez Michalov lokálny Codex CLI (ChatGPT účet — nemíňa Claude limity); model `gpt-5.6-sol`, effort `high` sú nastavené v `~/.codex/config.toml` — **netreba nič flagovať**. Proces sa osvedčil: pred+po Codex chytil dokopy 5+ blockerov a 5 reálnych bugov.

## Postup

1. **Nájdi companion runtime** (cesta sa mení s verziou pluginu) — Glob:
   `C:\Users\PC\.claude\plugins\cache\openai-codex\codex\*\scripts\codex-companion.mjs`
   (fallback: `C:\Users\PC\.claude\plugins\marketplaces\openai-codex\plugins\codex\scripts\codex-companion.mjs`).
2. **Zostav adversarial prompt** (vzor nižšie) a ulož do scratchpad súboru v UTF-8. NIE inline shell argument — slovenčina a úvodzovky sa rozsypú.
3. **Odošli úlohu** (Bash tool):
   `node "<companion>" task "$(cat '<prompt-file>')"` → výstup obsahuje **task-id**.
   (Alternatíva, ak priame volanie zlyhá: Agent `codex:codex-rescue` ako čistý forwarder — má spraviť LEN toto jedno volanie a vrátiť task-id; výsledok si ťahá hlavný agent sám.)
4. **Počkaj na dobehnutie:** opakovane `node "<companion>" status <task-id>` — úloha beží, kým je v tabuľke `| running |`. Typicky 3–10 min pri effort high. Čakanie rieš cez Monitor tool (načítať cez ToolSearch) alebo background sleep + jednorazový check; **nikdy nereťaziť** kontrolný grep s ďalšími príkazmi (race na dopisujúci sa output).
5. **Vytiahni výsledok:** `node "<companion>" result <task-id>`.
6. **Spracuj nálezy:** BLOCKER = zastav, vyrieš v návrhu pred kódom; FIX-IN-X = zapracuj do plánu iterácie; NOTE = zváž/zapíš. Michalovi zhrň po slovensky: počty nálezov + čo sa v návrhu mení.

## Vzor promptu

```
You are an adversarial design reviewer (devil's advocate) for the SketchUp Ruby
plugin Noxun Engine (repo root: C:\APP DEV\RUBY\ENGINE). READ the actual files
before judging — do not trust the summary.

DESIGN UNDER REVIEW:
<celý návrh: čo sa mení, prečo, ktoré súbory/moduly, dátové zmeny>

CONTEXT FILES TO READ FIRST:
<zoznam kľúčových súborov + CLAUDE.md, SYSTEM/01_STANDARD_draft.md>

RULES:
- Actively try to break the design: hidden regressions, undo/observer
  interactions, data-contract violations (BuildPlan SCHEMA, NOXUN dict,
  mm Float), UI guard gaps (HTML disabled is not protection), Windows/CEF
  pitfalls (cache-bust, encoding).
- Numbered findings, each labeled BLOCKER / FIX-IN-<iteration> / NOTE,
  with file:line references.
- Do NOT change any files. Output findings only, most severe first.
```
