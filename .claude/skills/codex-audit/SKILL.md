---
name: codex-audit
description: Nezávislý Codex audit návrhu PRED implementáciou (devil's advocate). Povinný pred každou dávkou/iteráciou, ak je Codex CLI dostupný. Odošle návrh do lokálneho Codex CLI, počká na dobehnutie a vráti číslované nálezy BLOCKER/FIX/NOTE.
---

# Codex audit návrhu (devil's advocate)

Povinný krok pred implementáciou každej dávky/iterácie (pravidlo z 18.7.2026). Beží cez Michalov lokálny Codex CLI (ChatGPT účet — nemíňa Claude limity); model `gpt-5.6-sol`, effort `high` sú nastavené v `~/.codex/config.toml` — **netreba nič flagovať**. Proces sa osvedčil: pred+po Codex chytil dokopy 5+ blockerov a 5 reálnych bugov.

**Dostupnosť:** skill vyžaduje nainštalovaný Codex plugin (companion runtime). Ak runtime v kroku 1 nenájdeš (iný checkout/prostredie než Michalovo lokálne PC, napr. cloud sandbox), krok NEblokuje — výslovne ohlás, že adversarial audit treba spustiť na Michalovom lokálnom prostredí, a pokračuj s o to prísnejšou vlastnou kontrolou návrhu.

## Postup

1. **Nájdi companion runtime** (Glob v home adresári; cesta sa mení s verziou pluginu):
   `~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs`
   (fallback: `~/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs`).
2. **Zostav adversarial prompt** (vzor nižšie) a ulož do scratchpad súboru v UTF-8. NIE inline shell argument — slovenčina a úvodzovky sa rozsypú. Do promptu dosaď skutočný repo root aktuálneho checkoutu (napr. výstup `git rev-parse --show-toplevel`). **Prompt drž ŠTÍHLY** (5–6 files-to-read, „known facts" sekcia namiesto ďalších súborov) — obrí rozsah predlžuje beh a zvyšuje riziko stallu.
3. **Odošli úlohu — VŽDY cez PowerShell tool a VŽDY s `--background`** (bez neho volanie blokuje do konca behu a vytimeoutuje; companion navyše interne volá `taskkill /PID`, ktorý Git Bash MSYS manglingom rozbije):
   `$prompt = Get-Content -Raw '<prompt-file>'; node "<companion>" task --background $prompt` → výstup obsahuje **task-id**.
4. **Počkaj na dobehnutie:** opakovane `node "<companion>" status <task-id>` — úloha beží, kým je `| running |`. Typicky 3–10 min pri effort high. Čakanie rieš cez background sleep + jednorazový check; **nikdy nereťaziť** kontrolný grep s ďalšími príkazmi.
   **STALL GUARD (povinný):** status vypisuje cestu `Log:` — pri každom checku over `tail` logu. Ak sa log **>15 min nehýbe** (alebo Elapsed presiahne ~25 min), task je zaseknutý: `cancel <task-id>` (PowerShell!), over/dobi PID z chybovej hlášky a **1× retry** s ešte štíhlejším promptom. Ak stalne aj retry, pokračuj bez auditu — výslovne to ohlás a audit nech sa spustí neskôr lokálne.
5. **Vytiahni výsledok:** `node "<companion>" result <task-id>`.
6. **Spracuj nálezy:** BLOCKER = zastav, vyrieš v návrhu pred kódom; FIX-IN-X = zapracuj do plánu iterácie; NOTE = zváž/zapíš. Michalovi zhrň po slovensky: počty nálezov + čo sa v návrhu mení.

## Vzor promptu

```
You are an adversarial design reviewer (devil's advocate) for the SketchUp Ruby
plugin Noxun Engine (repo root: <REPO_ROOT — dosaď skutočnú cestu checkoutu>).
READ the actual files before judging — do not trust the summary.

DESIGN UNDER REVIEW:
<celý návrh: čo sa mení, prečo, ktoré súbory/moduly, dátové zmeny>

CONTEXT FILES TO READ FIRST:
<zoznam kľúčových súborov + CLAUDE.md, SYSTEM/01_STANDARD.md>

RULES:
- Actively try to break the design: hidden regressions, undo/observer
  interactions, data-contract violations (BuildPlan SCHEMA, NOXUN dict,
  mm Float), UI guard gaps (HTML disabled is not protection), Windows/CEF
  pitfalls (cache-bust, encoding).
- Numbered findings, each labeled BLOCKER / FIX-IN-<iteration> / NOTE,
  with file:line references.
- Do NOT change any files. Output findings only, most severe first.
```
