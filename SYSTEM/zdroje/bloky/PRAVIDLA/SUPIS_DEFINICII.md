# Blok PRAVIDLA — súpis kópií definícií (podklad pre package P1a, 22.10.2026)

> Výstup analytika (Sonnet, len čítanie) nad hlavou `main` a9e8c79d — čísla riadkov platia k tomuto stavu. Rozhodnutie o rozporoch
> R1–R10 zapíše orchestrátor do rámčeka „platí" nižšie po odpovedi Michala; package P1a z neho vychádza.

Skratky: C = CLAUDE.md, W = SYSTEM/WORKFLOW.md, IMP/LAH/STR = `.claude/agents/implementator` / `-lahky` / `-stredny`, PRE = skill `predrecenzia`,
AUD = skill `codex-audit`, PO = skill `codex-po-pr`, USG = skill `usage`, SLP = `.claude/agents/slepy-recenzent.md`, STD = SYSTEM/STANDARD.md.
Referenčné znenie je C. AGENTS.md (len odkaz na C), SYSTEM/README.md, SYSTEM/STAV.md, docs/*.md, scripts/*.ps1, skilly retro a antigravity-outside-in,
typy reserser a agy-reserser definície D1–D8 nenesú.

> **Platí — Michal 23.10.2026 schválil odporúčania orchestrátora ku všetkým rozporom:** R1 podľa CLAUDE.md (nová API plocha = outside-in
> rešerš, nie audit) · R2 podľa CLAUDE.md (široké spúšťače in-SU) · R3 podľa CLAUDE.md (náhradná brána / rozhodne Michal) · R4 ponechať,
> zapísať do obsadenia (náhradník predrecenzie Codex) · R5 ponechať ako „odporúčaná" · R6 300 riadkov vždy bez testov a dokumentácie ·
> R7 eskalácia pri P0 aj P1, bez mena modelu · R8 jeden prah: Codex zostatok pod 10 % · R9 ponechať, zapísať do D8 · R10 zmena seedu =
> príklad výrobnej/cenovej dávky v D1.

## 1 · Kde je ktorá definícia (súbor:riadok | plná / parafráza / odkaz | odchýlka od C)

**D1 výrobná/cenová dávka** (C:67-76)
- C:67-76 plná (kanonická) · W:392 parafráza, zhodné · PRE:20 parafráza + „príklady tamtiež", zhodné
- STD:1787 parafráza — navyše: zmena seedu (`SEED_VERSION`, `SEED_SET_VERSION`) mení kovanie, ABS alebo ceny → „spravidla výrobná/cenová" (v C nie je)
- odkazy: W:96, 222, 307, 313, 379, 395 · IMP/LAH/STR:21 a `description` · PRE:3, 19 · PO:13, 20, 41, 56, 67 · USG:46

**D2 audit-povinná dávka** (C:77-80)
- C:77-80 plná · AUD:8 plná (druhá kópia vrátane N17), zhodné
- AUD:3, 9, 11 parafráza — AUD:9 navyše „nová SketchUp API plocha" (R1)
- IMP/LAH/STR:20-22 parafráza (celý výpočet), zhodné · PRE:3, 19 parafráza — chýba „každé zvýšenie schémy"
- W:207, 373 parafráza (W:373 pridáva sondu) · STD:1785 parafráza (len schéma)
- odkazy: W:40, 70, 96, 222, 379 · PO:13, 41, 56, 67 · USG:45

**D3 triedy Ľ/S/Ť** (C:35-43)
- C:35-43 plná · W:90-110 plná druhá kópia (tabuľka, prednosť s príkladom, reklasifikácia s „(bez testov a dokumentácie)", eskalácia „v dávke Sonnetu")
- IMP/LAH/STR:3 parafráza v `description` · LAH/STR:30-34 reklasifikácia ako W:107 · LAH/STR:44-46 eskalácia „P1 (a P0)" + model „Opus" (R7)
- odkazy: C:12 · W:35-37, 73, 102, 105, 112-114

**D4 povinná predrecenzia** (C:84-87)
- C:84-87 plná · PRE:3, 15-24 plná tabuľka — navyše „iný kód s novou UI interakciou … odporúčaná" (R5), dátumové poznámky
- IMP/LAH/STR:20-25 parafráza (bez náhradného implementátora — pre Claude profily v poriadku) · W:222, 379, 390 · PO:13-15 parafráza
- odkazy: W:78, 102-105, 215, 284-285 · STD:1787

**D5 nový ovládací prvok v UI** (C:74-76, vnorený v D1)
- C:74-76 plná (áno/nie príklady) · PRE:21, W:390 odkaz „príklady v CLAUDE.md"
- zmienky bez príkladov (~10): C:37, 85 · W:95, 222, 379 · IMP/LAH/STR:22 · STR:3 · PO:14 · PRE:3

**D6 spúšťače in-SU + finálna hlava** (C:199-204)
- C:199-204 plná · W:219-220, 281-282, 377 parafráza (W:281 bez „JS zmeny kryjú JS sady") · PLAN.md:110 užšie (R2)
- odkazy: IMP/LAH/STR:16-17 · PRE:31 · PO:35 · C:14

**D7 kvótové prahy** (C:111-121, 137)
- C:111-121, 137 plná (stav „Claude session > 80 %" v C dvakrát: 115-117 a 120-121)
- USG:17, 39, 46, 47 plná · USG:45 „Codex weekly > 85 %" (R8) · PO:18-22, 53-60, 67 plná, zhodné
- AUD:11 „pokračuj s prísnejšou vlastnou kontrolou" (R3) · PRE:33-34, 45-49 vlastná brána Claude weekly + náhrada Codex CLI (R4)
- W:391, 395 plné (W:395 vynecháva P0/P1), ďalšie parafrázy W:209, 212-214, 224, 283, 297, 311, 353-361, 374-375 · IMP/LAH/STR:26
- kód: `.claude/skills/usage/usage.ps1:12, 27, 189-190` (`MinRemaining = 10`)
- prahy shadow (W:111-112) sú iné pravidlo — nemiešať s D7

**D8 pravidlo 3 kôl a delta** (C:56-66, 135)
- C:56-66, 135 plná · PO:37-45, 66-67, 76-87 plná druhá kópia — navyše PO:39-41 „ďalší nezávislý hlas pri cenových miestach", PO:83 (R9), PO:67 výnimka kvóty
- W:307-310, 328-343, 356-361, 382 · PRE:10-12 · SLP:3, 18 parafráza, zhodné · IMP:36-39, LAH/STR:44-46 (navyše „P0")
- odkazy: W:20, 299, 362 · USG:46 · C:113

## 2 · Rozpory (vecné)

| # | Def. | Kde | Rozpor |
|---|---|---|---|
| R1 | D2 | AUD:9 | audit-povinná aj „nová SketchUp API plocha" — C to nemá (antigravity-outside-in:17 ju používa pre rešerš, nie audit) |
| R2 | D6 | PLAN.md:110 | „In-SU povinné pri builderoch/observeroch" — chýba undo/operácie, geometria, akcie panela |
| R3 | D7 | AUD:11 | bez Codexu „ohlás a pokračuj s prísnejšou vlastnou kontrolou" — C: náhradná brána / rozhodne Michal |
| R4 | D7 | PRE:33, 45 | predrecenzia má vlastnú bránu „Claude weekly na dne" a náhradu „lokálny Codex CLI" — v C ani v Náhradníkoch nie je |
| R5 | D4 | PRE:23 | „nová UI interakcia (klávesnica, fokus, prepnutie dokumentu) — odporúčaná" — C takú kategóriu nemá |
| R6 | D3 | C:37-38 | hranica 300 riadkov bez „(bez testov a dokumentácie)"; C:85 a W:107 ho majú |
| R7 | D3 | LAH/STR:45 | eskalácia „P1 (a P0)" + meno modelu; C:40 a W:109 len P1 |
| R8 | D7 | USG:45 | „Codex weekly > 85 %" vs C „zostatok < 10 %" |
| R9 | D8 | PO:83 | „P2/P3 z delty overí orchestrátor sám (bez subagenta a GH kola)" — v C nie je |
| R10 | D1 | STD:1787 | zmena seedu „spravidla výrobná/cenová" — v C nie je |

## 3 · Testy a skripty viazané na text

Žiadny test ani skript nekontroluje samotné znenie D1–D8 (Grep nad `tests/`, `scripts/`, `.github`, `.claude/hooks`). Pri presune sa dotknú:
- `tests/pure/test_agent_definitions.rb:101-106` — každý typ agenta musí byť v `SYSTEM/WORKFLOW.md` v backtickoch; limit `description` 1024 znakov (max dnes 691).
- `tests/pure/test_docs_navigacia.rb:527-545` — relatívne odkazy v CLAUDE.md, WORKFLOW, SYSTEM/README/STAV/PLAN/DOGFOODING/V1_VIZIA, docs/* musia existovať
  (kotvy `#…` sa neoverujú; odkazy v `.claude/skills`, `.claude/agents` a STANDARD.md sa nekontrolujú — tam ručne).
- `tests/pure/test_docs_navigacia.rb:511-525` — CLAUDE.md musí obsahovať `docs/ARCHITEKTURA.md` a nesmie mať nadpis `## …architekt…`.
- `tests/pure/test_docs_navigacia.rb:35, 154-167` — limit 400 znakov na riadok len pre `NX_SYSTEM_LINE_FILES` (DEFINICIE.md pridať, ak sa limit chce).
- `tests/pure/test_encoding_guard.rb` + `scripts/encoding_guard.rb` — nový `.md` UTF-8 bez BOM.

Odkazy tvaru „CLAUDE.md, Git workflow", „definícia v CLAUDE.md", „príklady hraníc … vyššie/nižšie" treba prepísať: W:96, 277, 392, 395 ·
PRE:20-21 · PO:13 · STD:1785 · C:75, 85.

## 4 · Počty (mimo kanonického C, orientačne)

| D | plná v C | ďalšie plné kópie | parafrázy | odkazy / zmienky |
|---|---|---|---|---|
| D1 | 1 | 0 | 3 | ~20 |
| D2 | 1 | 1 | ~11 | ~10 |
| D3 | 1 | 1 | 7 | ~6 |
| D4 | 1 | 1 | ~8 | ~5 |
| D5 | 1 | 0 | 0 | ~12 |
| D6 | 1 | 0 | 4 | 6 |
| D7 | 1 | ~5 | ~8 | ~3 |
| D8 | 1 | 2 | ~9 | ~5 |
