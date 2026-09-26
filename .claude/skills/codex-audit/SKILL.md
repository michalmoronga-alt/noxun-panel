---
name: codex-audit
description: Nezávislý Codex audit návrhu PRED implementáciou (devil's advocate). Risk-based od 12.8.2026 — povinný LEN pre dávky meniace dátový kontrakt, schému (každé zvýšenie CONFIG_SCHEMA, BuildPlan SCHEMA alebo STD), migráciu, observer/undo lifecycle alebo pridávajúce nový modul (ak je Codex CLI dostupný). Model sa zadáva vždy výslovne (--model podľa tabuľky Obsadenie rolí). Odošle návrh do lokálneho Codex CLI, počká na dobehnutie a vráti číslované nálezy BLOCKER/FIX/NOTE.
---

# Codex audit návrhu (devil's advocate)

**Risk-based pravidlo (RETRO 12.8.2026 — nahrádza „povinný vždy" z 18.7.):** audit je povinný **LEN** pre dávky meniace **dátový kontrakt, schému, migráciu, observer/undo lifecycle** alebo pridávajúce **nový modul**. **Zmena schémy = každé zvýšenie čísla schémy (`CONFIG_SCHEMA`, BuildPlan `SCHEMA`) alebo STD** (rozhodnutie N17, 26.9.2026 — S1-E0 zvýšil schému configu bez auditu). Fix dávky, docs a UI úpravy idú rovno do implementácie — poistkou ostáva `codex-po-pr`, ktorý je povinný pre každý PR (dáta z histórie: ~23 % PR malo reálny nález). Beží cez Michalov lokálny Codex CLI (ChatGPT účet — nemíňa Claude limity); effort sa riadi `~/.codex/config.toml`.
**Model — vždy výslovne v príkaze (rozhodnutie N13, 26.9.2026):** každé volanie má `--model <model roly>`; na predvolený model z `~/.codex/config.toml` sa **nespoliehaj** (26.9.2026 je tam `gpt-5.6-luna`, ktorý nie je model žiadnej roly). Ktorý model: tabuľka **Obsadenie rolí** v `SYSTEM/WORKFLOW.md` — rola **audítor audit-povinných** pre audit-povinnú triedu (kontrakt, schéma, migrácia, observer/undo lifecycle, nový modul, nová SketchUp API plocha) a ako tretí hlas pri sporných nálezoch; rola **bežný audit a delta** pre bežné audity, delta verifikácie po opravách, opakované kolá a UI dávky. Audítor audit-povinných ukrajuje z Codex limitu viac — nie na rutinu.
**Verzia CLI:** novšie modely vyžadujú aktuálny Codex CLI (13.9.2026: model audítora audit-povinných ≥ 0.154) — `codex --version` musí hlásiť npm balík z `%APPDATA%\npm`, nie desktop-app binárku `…\Programs\OpenAI\Codex\bin\codex.exe` (0.144, PATH bol 13.9. preusporiadaný). Companion spúšťa `codex app-server` z PATH a drží ho ako broker; po upgrade CLI treba starý broker (`node …app-server-broker.mjs` + `codex app-server`) zastaviť, inak beží stará verzia ďalej. V okne otvorenom pred zmenou PATH: `$env:Path = "$env:APPDATA\npm;" + $env:Path` pred volaním companiona. GH PR review model je na strane Codex cloudu. Proces sa osvedčil: pred+po Codex chytil dokopy 5+ blockerov a 5 reálnych bugov.
**Kvóta (od 13.9.2026, skill `usage`):** brána je súčasťou krokov 3 a 5 nižšie. **Exit 3 = Codex weekly ZOSTATOK pod 10 % (t. j. > 90 % použitých) → audit neposielaj**; exit 2/4 neblokujú (rozhodni ručne). Výnimka: audit-povinná dávka (kontrakt/schéma/migrácia/observer/nový modul) alebo P0/P1 → spýtaj sa Michala, môže audit povoliť aj pod prahom.

**Dostupnosť:** skill vyžaduje nainštalovaný Codex plugin (companion runtime). Ak runtime v kroku 1 nenájdeš (iný checkout/prostredie než Michalovo lokálne PC, napr. cloud sandbox), krok NEblokuje — výslovne ohlás, že adversarial audit treba spustiť na Michalovom lokálnom prostredí, a pokračuj s o to prísnejšou vlastnou kontrolou návrhu.

## Postup

1. **Nájdi companion runtime** (Glob v home adresári; cesta sa mení s verziou pluginu):
   `~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs`
   (fallback: `~/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs`).
2. **Zostav adversarial prompt** (vzor nižšie) a ulož do scratchpad súboru v UTF-8. NIE inline shell argument — slovenčina a úvodzovky sa rozsypú. Do promptu dosaď skutočný repo root aktuálneho checkoutu (napr. výstup `git rev-parse --show-toplevel`). **Prompt drž ŠTÍHLY** (5–6 files-to-read, „known facts" sekcia namiesto ďalších súborov) — obrí rozsah predlžuje beh a zvyšuje riziko stallu.
3. **Kvótová brána + odoslanie.** Najprv `& ".claude\skills\usage\usage.ps1" -Label "audit <dávka>" -Phase before -Gate codex` — exit 3 = audit neposielaj (viď Kvóta vyššie; ohlás a pokračuj s prísnejšou vlastnou kontrolou, alebo odlož po resete). Potom **odošli úlohu — VŽDY cez PowerShell tool a VŽDY s `--background`** (bez neho volanie blokuje do konca behu a vytimeoutuje; companion navyše interne volá `taskkill /PID`, ktorý Git Bash MSYS manglingom rozbije):
   `$prompt = Get-Content -Raw '<prompt-file>'; node "<companion>" task --background --model <model roly> $prompt` → výstup obsahuje **task-id**. `--model` ide PRED prompt a nevynecháva sa nikdy (model roly podľa tabuľky Obsadenie rolí).
   POZOR: `task --help` neexistuje — spustí skutočný task.
4. **Počkaj na dobehnutie:** opakovane `node "<companion>" status <task-id>` — úloha beží, kým je `| running |`. Typicky 3–10 min pri effort high. Čakanie rieš cez background sleep + jednorazový check; **nikdy nereťaziť** kontrolný grep s ďalšími príkazmi.
   **STALL GUARD (povinný):** status vypisuje cestu `Log:` — pri každom checku over `tail` logu. Ak sa log **>15 min nehýbe** (alebo Elapsed presiahne ~25 min), task je zaseknutý: `cancel <task-id>` (PowerShell!), over/dobi PID z chybovej hlášky a **1× retry** s ešte štíhlejším promptom. Ak stalne aj retry, pokračuj bez auditu — výslovne to ohlás a audit nech sa spustí neskôr lokálne.
5. **Vytiahni výsledok:** `node "<companion>" result <task-id>` a zapíš spotrebu: `& ".claude\skills\usage\usage.ps1" -Label "audit <dávka>" -Phase after` (ten istý Label ako v kroku 3).
6. **Spracuj nálezy:** BLOCKER = zastav, vyrieš v návrhu pred kódom; FIX-IN-X = zapracuj do plánu iterácie; NOTE = zváž/zapíš. Michalovi zhrň po slovensky: počty nálezov + čo sa v návrhu mení.

## Vzor promptu

```
You are an adversarial design reviewer (devil's advocate) for the SketchUp Ruby
plugin Noxun Engine (repo root: <REPO_ROOT — dosaď skutočnú cestu checkoutu>).
READ the actual files before judging — do not trust the summary.

DESIGN UNDER REVIEW:
<celý návrh: čo sa mení, prečo, ktoré súbory/moduly, dátové zmeny>

CONTEXT FILES TO READ FIRST:
<zoznam kľúčových súborov + CLAUDE.md, SYSTEM/STANDARD.md>

RULES:
- Actively try to break the design: hidden regressions, undo/observer
  interactions, data-contract violations (BuildPlan SCHEMA, NOXUN dict,
  mm Float), UI guard gaps (HTML disabled is not protection), Windows/CEF
  pitfalls (cache-bust, encoding).
- Numbered findings, each labeled BLOCKER / FIX-IN-<iteration> / NOTE,
  with file:line references.
- Do NOT change any files. Output findings only, most severe first.
```
