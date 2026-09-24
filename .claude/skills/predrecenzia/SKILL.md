---
name: predrecenzia
description: Slepá predrecenzia diffu vetvy PRED `gh pr create` — nezávislý Opus subagent bez kontextu orchestrátora hľadá chyby skôr, než ich nájde GitHub Codex. Povinná pre dávky audit-povinné (kontrakt, schéma, migrácia, observer/undo lifecycle, nový modul) a výrobné/cenové; odporúčaná pri iných kódových dávkach s väčším diffom alebo novou UI interakciou. Vráti číslované nálezy P1/P2/P3 a verdikt; P1/P2 sa opravia pred otvorením PR.
---

# Slepá predrecenzia pred PR

**Prečo (Michal 25.9.2026, retrospektíva bloku S1):** GH Codex kolo stojí 10–25 min a pri audit-povinných a výrobných/cenových
dávkach sa po KAŽDEJ oprave opakuje celé — delta-verifikácia tam nestačí (CLAUDE.md, Git workflow). PR #389 (D-140, výška osadenia
chladničky) preto potreboval **3 plné kolá na 6 drobných P2** (Escape z tlačidla, jednostranná väzba, fokus po zatvorení…), ktoré by
jedna slepá recenzia pred PR chytila naraz. Druhý dôvod: subagent si kód číta sám, takže orchestrátorovi nezaberá kontext — pri dlhých
blokoch je to poistka proti kompresii kontextu.

## Kedy

| Dávka | Predrecenzia |
|---|---|
| audit-povinná (kontrakt, schéma, migrácia, observer/undo lifecycle, nový modul — tá istá trieda ako `codex-audit`) | **povinná** |
| výrobná alebo cenová (kusovník, VEPO, nákup, ceny, cenová ponuka) | **povinná** |
| iný kód s väčším diffom alebo novou UI interakciou (klávesnica, fokus, popover, prepnutie dokumentu, prekreslenie) | odporúčaná |
| docs-only, len zmena verzie | nie |

Predrecenzia **nenahrádza** `codex-audit` (ten je PRED implementáciou a posudzuje návrh) ani `codex-po-pr` (GH review ostáva
povinné pre každý PR). Je to lacnejšie kolo navyše medzi hotovým kódom a prvým GH kolom.

## Postup

1. **Vetva je hotová:** testy zelené (headless + všetky JS sady; in-SU pri builderoch, observeroch a undo), docs na mieste, všetko commitnuté.
2. **Kvóta PRED spustením** (subagent míňa Claude kvótu, orientačne 200–350 k tokenov na beh; skill `usage`, bod 4):
   `& ".claude\skills\usage\usage.ps1" -Label "predrecenzia <dávka>" -Phase before -Gate claude` — **exit 3** (Claude weekly na dne) =
   subagenta nespúšťaj a použi náhradu z bodu 7; keď je Claude session nad 80 % a reset je ďaleko, povedz to Michalovi pred štartom.
3. **Spusti subagenta:** Agent tool — `subagent_type: general-purpose`, `model: opus`, `run_in_background: true`, prompt podľa vzoru
   nižšie. **Slepý** = dostane len ZADANIE (čo sa má zmeniť pre používateľa a kľúčové rozhodnutia z briefu) a rozsah diffu — nie výsledky
   auditu, nie vlastné hodnotenie orchestrátora, nie zoznam „na čo si dať pozor". Medzitým orchestrátor pripravuje PR popis.
4. **Po výsledku** zapíš spotrebu: `& ".claude\skills\usage\usage.ps1" -Label "predrecenzia <dávka>" -Phase after` (ten istý Label).
5. **Nálezy:** P1/P2 oprav pred PR (commit `predrecenzia: …`, testy znova). P3 zváž — oprav, alebo v PR uveď, prečo nie. Oprava, ktorá
   mení koncept riešenia → späť k briefu; pri audit-povinnej dávke aj k auditu.
6. **PR popis** má sekciu **„Predrecenzia"**: počty P1/P2/P3 a čo sa opravilo (pri „bez nálezov" jedna veta; pri náhrade aj prečo).
7. **Náhrada pri nedostatku Claude kvóty = lokálny Codex CLI s modelom Sol** (výslovne — predvolený model v `~/.codex/config.toml`
   je Astra, ktorá míňa viac Codex kvóty). Najprv Codex brána `& ".claude\skills\usage\usage.ps1" -Label "predrecenzia <dávka>" -Phase before -Gate codex`
   (exit 3 = ani náhradu nespúšťaj, predrecenzia sa odloží po resete a PR to prizná), potom cez **PowerShell tool** s tým istým promptom:
   `$prompt = Get-Content -Raw '<prompt-file>'; node "<companion>" task --background --model gpt-5.6-sol $prompt`.
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
