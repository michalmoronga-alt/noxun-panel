# Blok 8 · K3 ROHOVÁ SKRINKA — rozhodnutia Michala (6.9. a 27.9.2026)

> **Produktové rozhodnutia bloku** — čo a ako má plugin robiť z pohľadu stolára. **Technické požiadavky** (formát dát, verzie configu
> a výrobného plánu, roly dielcov, výrobné brány…) sa zapisujú do **package každej dávky** a prejdú jej auditom návrhu.
> Pôvodná debata: [../../next_sessions/V1_DEBATA_2026-09-05_KONSTRUKCIA.md](../../next_sessions/V1_DEBATA_2026-09-05_KONSTRUKCIA.md) §3
> (špecifikácia z DC „Rohová", ktorú dielňa roky používa). Tento súbor ju **nenahrádza** — dopĺňa rozhodnutia zo štartu bloku.
> Ďalšie súbory priečinka: fakty z kódu [FAKTY_Z_KODU_2026-09-27.md](FAKTY_Z_KODU_2026-09-27.md) · presná geometria DC
> [DC_ROHOVA_GEOMETRIA_2026-09-27.md](DC_ROHOVA_GEOMETRIA_2026-09-27.md) · rešerš precedensov [RESERS_OUTSIDE_IN_2026-09-27.md](RESERS_OUTSIDE_IN_2026-09-27.md) ·
> krížový audit [CROSS_AUDIT_PROMPT_2026-09-28.md](CROSS_AUDIT_PROMPT_2026-09-28.md), [CROSS_AUDIT_CODEX_2026-09-28.md](CROSS_AUDIT_CODEX_2026-09-28.md),
> [CROSS_AUDIT_GROK_2026-09-28.md](CROSS_AUDIT_GROK_2026-09-28.md), auditovaný koncept v1 ako surový vstup
> [KONCEPT_K3_v1_AUDITOVANY_2026-09-28.md](KONCEPT_K3_v1_AUDITOVANY_2026-09-28.md) (nie zadanie) · vyhodnotenie nálezov
> [RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md](RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md). Packages dávok pribudnú s dávkami.

## 1 · Rozhodnutia

| # | Téma | Rozhodnutie | Kedy |
|---|---|---|---|
| R1 | Čo je rohová | **dolná slepá rohová skrinka s CR lištou** — bežná dolná skrinka (dno, strop alebo výstuhy, chrbát, sokel, nohy, police) + **rohová zostava na prednej rovine**; jedna časť skrinky má dvere, zvyšok je **slepý** (schovaný v rohu za susedným radom) | 6.9. |
| R2 | Rohová zostava | **dvere** · **blenda korpusová** (zakrýva slepú časť, **vždy korpusový materiál**) · **výstuha závesov** · **rohová výstuha** · **CR 1** (lišta na prednej rovine vedľa dverí) · **CR 2** (lišta kolmo, vracia sa k susednému radu); rozmery a význam dielcov podľa DC (debata §3) | 6.9. |
| R3 | Parametre | **šírka dverovej časti** · **CR 1** · **CR 2** (každá zvlášť — CR nemusí byť symetrická, dolaďujú sa ňou milimetre v rohu) · **strana dverí vľavo / vpravo** (zrkadlí sa celá rohová zostava); typický rozmer **1100 / dvere 450** | 6.9. |
| R4 | CR lišty vo výstupoch | v kusovníku aj VEPO ako dielce z **čelového materiálu s ABS dookola** (ako čelo) | 6.9. |
| R5 | Kovanie | závesy podľa výšky dverí ako pri bežných dvierkach (vlastník = dvere), úchytka, nohy podľa šírky — **žiadny rohový mechanizmus** | 6.9. |
| R6 | Dverová časť | **len jedny dvierka** (jedno krídlo); vnútri **police cez celú šírku** skrinky (ako DC) — zásuvky ani iné čelá v rohovej nie | 27.9. |
| R7 | Pánty | **voliteľné smerom dverí, predvolene pri rohu**: pri rohu sedia pánty na výstuhe závesov (ako DC), pri vonkajšom boku na boku skrinky | 27.9. |
| R8 | Nočný beh 27./28.9. | príprava bloku (fakty z kódu, koncept, rešerš, krížový audit, mockup) **a jadro rohovej** — rohová sa postaví, ide do kusovníka aj VEPO, zapne sa **typom „Rohová" v existujúcom prepínači typu** (rad tlačidiel typu vo vkladacej karte: Dolná · Horná · Umývačka) s predvolenými rozmermi; **nové ovládače** (šírka dverovej časti, CR lišty, strana dverí) prídu až **po Michalovom schválení mockupu** | 27.9. |
| R9 | Mimo bloku | **horná rohová** (mimo V1) · rohové vybavenie — **LeMans / karusel** (po V1, zásobník) · **kolízia CR 2 so susednou skrinkou** (neskôr, zostavy) | 6.9. |

## 2 · Dávky bloku (po krížovom audite 28.9.)

**ROH-A1 · jadro rohovej** — dáta, stavba oboch strán, výstupy (kusovník, VEPO, ponuka), ochrany (typ sa nesmie zmeniť, jedny dvierka, strana sa
v A1 nemení) · **ROH-A2 · vkladanie a náhľad** — tlačidlo „Rohová" vo vkladacej karte, dvere a pánty v náhľade na správnom mieste (R8 je splnené
až po A2) · **ROH-B · ovládače** — riadky v Inspectore a prepínač strany podľa schváleného mockupu. Rez A1/A2 odporučil krížový audit (Codex Q6).
Každá dávka dostane package v tomto priečinku; audit-povinné dávky prejdú auditom návrhu.

## 3 · Otvorené otázky (odpovie Michal pri schvaľovaní mockupu)

Otázky, nie rozhodnutia — technické riešenie každej dávky určuje jej package po audite návrhu; vyhodnotenie nálezov krížového auditu je v
[RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md](RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md).

1. Predvolené rozmery a konštrukcia rohovej — hĺbka, strop, chrbát ako pri dolnej, alebo ako v DC (dve nadnože, pevný vložený chrbát)?
2. Rozsahy dverovej časti a CR lišiet (audit upozorňuje, že CR pod ~50–75 mm môže naraziť úchytka susedného radu) a medzera dverí pri rohu.
3. Názvy dielcov v kusovníku a VEPO; hrany (ABS) podľa DC?
4. Priečky vo vnútri rohovej — sú potrebné? (R6 hovorí o policiach cez celú šírku; priečka v slepej časti by narazila na blendu.)
5. Polica prechádza výstuhou závesov (DC to rieši výrezom v dielni) — má na to plugin upozorniť?
6. Majú CR lišty ísť s hromadnou „Kresbou čiel" ako dvere?
7. Kde v Inspectore budú riadky rohovej a prepínač strany dverí.

Kým Michal neodpovie, dávky ROH-A1 a ROH-A2 (R8) vychádzajú z DC „Rohová" a z debaty 6.9.; každú takú voľbu ich package aj PR výslovne označí
ako návrh, ktorý Michalova odpoveď môže zmeniť.
