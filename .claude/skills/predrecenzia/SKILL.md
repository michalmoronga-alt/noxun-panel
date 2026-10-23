---
name: predrecenzia
description: Slepá predrecenzia diffu vetvy PRED `gh pr create` — nezávislý slepý recenzent (subagent bez kontextu orchestrátora) hľadá chyby skôr, než ich nájde GitHub Codex. Kedy je povinná, určuje SYSTEM/pravidla/DEFINICIE.md § D4 (audit-povinné, výrobné/cenové, veľké a UI dávky, náhradný implementátor). Vráti číslované nálezy P1/P2/P3 a verdikt; P1/P2 sa opravia pred otvorením PR.
---

# Slepá predrecenzia pred PR

**Prečo (Michal 25.9.2026, retrospektíva bloku S1):** GH Codex kolo stojí 10–25 min a pri audit-povinných a výrobných/cenových
dávkach sa po oprave opakovalo celé. PR #389 (D-140, výška osadenia chladničky) preto potreboval **3 plné kolá na 6 drobných P2**
(Escape z tlačidla, jednostranná väzba, fokus po zatvorení…), ktoré by jedna slepá recenzia pred PR chytila naraz. Od 26.9.2026 platí aj
opačný smer: dávka, ktorá prešla predrecenziou, smie po drobných nálezoch GH kola ísť cez internú deltu namiesto nového plného kola
(skill `codex-po-pr`). Druhý dôvod: subagent si kód číta sám, takže orchestrátorovi nezaberá kontext — pri dlhých blokoch je to
poistka proti kompresii kontextu.

## Kedy

Kedy je predrecenzia **povinná**, kedy **odporúčaná** a kedy sa **nerobí** (vrátane druhého recenzenta iného providera pri Ť a recenzenta
Claude pri kóde náhradného implementátora): jediné znenie je `SYSTEM/pravidla/DEFINICIE.md` § D4 (história hraníc: N18 26.9.2026,
náhradný implementátor 6.10.2026). Audit návrhu (`codex-audit`) posudzuje návrh PRED implementáciou a GH review (`codex-po-pr`) ostáva
povinné pre každý PR — predrecenzia je lacnejšie kolo navyše medzi hotovým kódom a prvým GH kolom.

## Postup

1. **Vetva je hotová:** testy zelené (headless + všetky JS sady; in-SU podľa `SYSTEM/pravidla/DEFINICIE.md` § D6), docs na mieste, všetko commitnuté.
2. **Kvóta PRED spustením** (subagent míňa Claude kvótu, orientačne 200–350 k tokenov na beh):
   `& ".claude\skills\usage\usage.ps1" -Label "predrecenzia <dávka>" -Phase before -Gate claude` — **exit 3** = subagenta nespúšťaj;
   prah a náhrada: skill `usage`, sekcia „Prahy a reakcie" (riadok Predrecenzia), postup náhrady bod 7.
3. **Spusti slepého recenzenta:** Agent tool — `subagent_type: slepy-recenzent` (typ z `.claude/agents/`: model, effort a nástroje len na čítanie
   sú v jeho definícii podľa roly **slepý recenzent** v tabuľke Obsadenie rolí, `SYSTEM/WORKFLOW.md`), `run_in_background: true`; prompt podľa vzoru
   nižšie. Keď typ v session ešte nie je (nový priečinok agentov sa načíta až v novej session), `subagent_type: general-purpose` s **`model:` výslovne**
   podľa tabuľky — bez neho subagent beží na predvolenom modeli. **Slepý** = dostane len ZADANIE (čo sa má zmeniť pre používateľa
   a kľúčové rozhodnutia z briefu) a rozsah diffu — nie výsledky auditu, nie vlastné hodnotenie orchestrátora, nie zoznam „na čo si dať pozor".
   Medzitým orchestrátor pripravuje PR popis.
   **Druhý recenzent pri dávke Ť** (kedy: `SYSTEM/pravidla/DEFINICIE.md` § D4): **implementátor Claude** → druhým recenzentom je Codex, model roly
   **bežný audit a delta** z tabuľky Obsadenie rolí, spustený cez companion `task --background --model <model>` (postup ako v bode 7) alebo subagent
   `codex:codex-rescue` — model vždy výslovne; **rovnaké zadanie a rovnaký rozsah diffu** ako prvý recenzent, beží súbežne. **Implementátor iného
   providera** (napr. náhradník Codex) → iným providerom je už povinný Claude recenzent, druhý sa nepridáva. Pred druhým recenzentom Codex brána
   `-Gate codex`; reakcia na exit 3: skill `usage`, Prahy a reakcie (riadok Druhý recenzent pri Ť).
4. **Po výsledku** zapíš spotrebu: `& ".claude\skills\usage\usage.ps1" -Label "predrecenzia <dávka>" -Phase after` (ten istý Label).
5. **Nálezy:** P1/P2 oprav pred PR (commit `predrecenzia: …`, testy znova) — pri dvoch recenzentoch sa opravuje **každý P1/P2 od ktoréhokoľvek**
   z nich (verdikty sa spájajú, nie priemerujú). P3 zváž — oprav, alebo v PR uveď, prečo nie. Oprava, ktorá
   mení koncept riešenia → späť k briefu; pri audit-povinnej dávke aj k auditu.
6. **PR popis** má sekciu **„Predrecenzia"**: počty P1/P2/P3 a čo sa opravilo (pri „bez nálezov" jedna veta; pri náhrade aj prečo).
7. **Postup náhrady pri nedostatku Claude kvóty** (kedy: skill `usage`, Prahy a reakcie) — lokálny Codex CLI, model vždy výslovne cez
   `--model` (na predvolený model z `~/.codex/config.toml` sa nespolieha, rozhodnutie N13). Najprv Codex brána
   `& ".claude\skills\usage\usage.ps1" -Label "predrecenzia <dávka>" -Phase before -Gate codex` (exit 3 = ani náhradu nespúšťaj — reakcia
   podľa skillu `usage`), potom cez **PowerShell tool** s tým istým promptom:
   `$prompt = Get-Content -Raw '<prompt-file>'; node "<companion>" task --background --model <model roly bežný audit a delta> $prompt`.
   Nájdenie companionu, čakanie so stall guardom a vytiahnutie výsledku: skill `codex-audit`, kroky 1 a 4–5.

**Závažnosť:** **P1** = chybné výrobné dáta alebo ceny, strata či poškodenie dát, pád, zápis do cudzieho dokumentu · **P2** = zlé správanie
v reálnom postupe používateľa (vrátane nesúladu Inspector ↔ Kontrola a chýbajúceho testu novej vetvy) · **P3** = kozmetika, docs, drobnosť.

## Vzor promptu

```
You are a blind pre-PR reviewer for the SketchUp Ruby plugin Noxun Engine
(repo: <REPO_ROOT>, branch <BRANCH>). Read-only: do NOT modify files, commit or push.

SCOPE: `git diff main...HEAD` — only this diff and the code it calls or is called from.

INTENT OF THE CHANGE (from the brief):
<2–6 sentences: what should change for the user, key decisions and constraints>

READ FIRST: CLAUDE.md (workflow + testing rules), the docs/architecture sections of
the touched modules (find them via docs/ARCHITEKTURA.md), relevant SYSTEM/STANDARD.md
sections.

HUNT FOR (actively try to break it):
- correctness bugs and unhandled edge cases in the new branches,
- undo / observer / operation issues (one Ctrl+Z per user action, no empty undo steps,
  abort on failure, root edit context before rebuilds),
- data-contract violations (config schema bump, persisted keys, copies and templates),
- UI state bugs: focus and keyboard, re-render of the panel, document switch,
  stale DOM identity, the `[hidden]` vs author `display` CSS trap,
- mismatches between Inspector and Kontrola (Validation) for the same data,
- new branches without a test; docs statements that contradict the code.

OUTPUT: numbered findings, each
`P1|P2|P3 — file:line — one-sentence problem — concrete reproduction`,
then a final line `VERDIKT: PR OK` or `VERDIKT: OPRAVIŤ PRED PR`.
Severity: P1 = wrong production data or prices, data loss, crash, write into a foreign
document; P2 = wrong behaviour in a realistic user flow; P3 = polish/docs.
Report only real, reproducible problems in this diff. Be concise.
```
