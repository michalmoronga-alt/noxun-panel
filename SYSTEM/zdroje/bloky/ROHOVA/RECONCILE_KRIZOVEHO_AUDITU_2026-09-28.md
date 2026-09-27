# Blok 8 · K3 — vyhodnotenie krížového auditu (reconcile orchestrátora, 28.9.2026)

> **Čo to je:** rozhodnutie orchestrátora o **každom** náleze krížového auditu bloku (Codex `C#` — [CROSS_AUDIT_CODEX_2026-09-28.md](CROSS_AUDIT_CODEX_2026-09-28.md),
> Grok `G#` — [CROSS_AUDIT_GROK_2026-09-28.md](CROSS_AUDIT_GROK_2026-09-28.md)) nad pracovným konceptom v1
> ([KONCEPT_K3_v1_AUDITOVANY_2026-09-28.md](KONCEPT_K3_v1_AUDITOVANY_2026-09-28.md) — surový vstup auditu, nie zadanie).
> **Čo to nie je:** zadanie dávky. Technické riešenie (vzorce, rozsahy, kontrakt) určuje **package dávky po vlastnom audite návrhu**; produktové
> otázky rozhoduje Michal ([ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md) §3). Pri rozdielnych odporúčaniach audítorov
> rozhoduje package ROH-A1 a jeho audit.

## BLOCKERy (všetky sa riešia pred implementáciou)

| Nález | Podstata | Rozhodnutie | Kde |
|---|---|---|---|
| **C1 / G2** | hrúbka čelového materiálu (18,6/19, rôzne overridy) sa dnes dopĺňa až po pláne a len do jednej osi — CR 2 a rohová výstuha by nesedeli | **prijaté** — hrúbky CR sa musia poznať pred stavbou, jedným výpočtom pre stavbu, kontroly aj zrkadlo | package ROH-A1 |
| **C2** | priečky zóny by prechádzali blendou korpusovou | **prijaté** — riešenie (zákaz priečok v rohovej alebo iná geometria) navrhne package ROH-A1; či sú priečky v rohovej potrebné, je otázka pre Michala (§3 bod 4) | package ROH-A1 + Michal |
| **C3** | záporná medzera dverí pri rohu prekryje dvere a CR 1 | **prijaté** — medzera pri rohu musí mať rozsah platný v stavbe aj v úpravách čiel | package ROH-A1 |
| **G1** | panel neznámy typ sklopí na dolnú a zápis ho pošle späť → rohová by sa pri prvej úprave zmenila na dolnú | **prijaté** — typ musia poznať aj registre panela v tej istej dávke ako stavba; zmena typu sa odmietne ako poistka | package ROH-A1 |
| **G2** | (spolu s C1) CR 2 má hrúbku v inej osi než čelá | **prijaté** | package ROH-A1 |

## FIXy

| Nález | Rozhodnutie | Kde |
|---|---|---|
| C4 — plytký korpus s komínom: výstuha závesov (80 mm) by prešla chrbtom | prijaté — kontrola hĺbky vrátane minima hĺbky | ROH-A1 |
| C5 — šablóna by zmenila stranu dverí a ručné hrany by ostali na nesprávnej strane | prijaté — kým nie je prepínač strany (ROH-B), strana existujúcej rohovej sa nemení žiadnou cestou | ROH-A1, ROH-B |
| C6 — polia bez ovládačov by sa pri úprave vrátili na predvolené | prijaté — polia rohovej nesmú prísť z panela, kým nemajú ovládač | ROH-A1 |
| C7 — výška dverí a CR pri pevnom riadku a úchytkovom profile | prijaté — jedny dvierka na celú výšku; CR podľa obrysu dverí | ROH-A1 |
| C8 — značky pántov v náhľade vždy vľavo | prijaté | ROH-A2 |
| C9 — overiť montáž závesu na výstuhe závesov | prijaté — overenie v dielni pri prvej rohovej (smoke) | smoke |
| G3 — široká dverová časť by dala dve krídla | prijaté — jedny dvierka (R6) platia pre všetky cesty úprav čiel | ROH-A1 |
| G4 — osi a hrany nových dielcov | prijaté — hrany podľa DC v osiach, ktoré zrkadlo nemení | ROH-A1 |
| G5 — CR 2 kratšia o polovicu medzery než rohová výstuha; rozmer CR 1 ≠ zadané číslo | čiastočne — tvar ostáva **ako v DC** (polovičná medzera pri voľnej hrane CR 2 je zámer DC); výsledné rozmery ukáže ROH-B | ROH-A1, ROH-B |
| G6 — minimum CR 30 mm je pod praxou (~76 mm) | prijaté ako otázka — rozsah CR navrhne package, potvrdí Michal (§3 bod 2) | ROH-A1 + Michal |
| G7 — polica prechádza výstuhou závesov, priečky blendou | prijaté — priečky pozri C2; upozornenie na výrez police je otázka pre Michala (§3 bod 5) | ROH-A1 + Michal |
| G8 — výnimka z pravidla „smer pántov sa nedopĺňa sám" (R7) | prijaté — výnimka len pre novú rohovú a len jedným miestom, pripnutá testom | ROH-A1 |
| G9 — klamp šírky pri zmene mierkou ručným vzorcom | prijaté — minimum šírky zo sondy cez celý plán | ROH-A1 |

## NOTE (bez zmeny návrhu)

C10 nika spotrebiča v rohovej — bez zmeny (väzby sa neblokujú) · C11 CR 1 a CR 2 sa pri rovnakom rozmere zlúčia v kusovníku — správne ·
C12–C14 precedensy CabBuilder, CabWriter, Mozaik, PolyBoard — topológia potvrdená, len vzory (proprietárne) · G10 obálka prisunutia nevidí CR 2 —
bez zmeny (R9, poznámka do mockupu) · G11 typ, filler v skrinke a zrkadlo v pláne — potvrdené.

## Rez dávok (C Q6)

Prijatý: **ROH-A1** jadro (dáta, stavba, výstupy, ochrany) → **ROH-A2** vkladanie a náhľad → **ROH-B** ovládače po schválení mockupu.
