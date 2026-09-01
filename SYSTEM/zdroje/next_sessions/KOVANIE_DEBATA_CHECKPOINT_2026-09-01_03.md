# KOVANIE — checkpoint USER debaty 2026-09-01 · 03

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Nadväzuje na:** `KOVANIE_DEBATA_CHECKPOINT_2026-09-01_02.md`.
> **Účel:** zachytiť ďalšie rozhodnutia po kompresii kontextu.

---

## 1. AVENTOS HF top — mechanizmus / Power Factor

- po zadaní geometrie, materiálu a typu otvárania Engine automaticky vyberie odporúčaný kompatibilný HF top mechanizmus podľa vypočítaného Power Factoru,
- používateľ môže ručne zvoliť iba inú **kompatibilnú** variantu,
- v bežnom Inspectore sa má zobrazovať najmä **výsledný mechanizmus**,
- Power Factor a ďalšie technické čísla majú byť dostupné až v rozbalenom detaile/diagnostike.

---

## 2. UI/UX princíp pre blok čelá / kovanie / zóny

Používateľ výslovne považuje UI/UX tejto témy za kľúčové.

Zásady:
- UI má vždy ponúkať iba témy a logické sekcie relevantné pre aktuálne zvolený variant,
- nerelevantné polia/sekcie sa nemajú zobrazovať iba preto, že existujú v dátovom modeli,
- funkcie treba logicky rozdeliť medzi okná/sekcie Inspectora: **Čelá / Kovanie / Zóny**,
- UI má byť kontextové a progresívne: po výbere typu čela sa zobrazia iba nastavenia, ktoré pre tento typ dávajú zmysel,
- jedna vlastnosť má mať jednu autoritatívnu editačnú sekciu; v iných sekciách môže byť iba read-only zhrnutie/link, aby sa nastavenia neduplikovali,
- preferovať grafické voľby/piktogramy tam, kde to zrýchli výber, a technické detaily schovávať do rozbaliteľného detailu.

Pracovná hranica zodpovedností:
- **Čelá:** zámer a geometria čela — typ, smer, spôsob otvárania, rozdelenie HF, rozmery a vizuálne preview,
- **Kovanie:** konkrétny systém/set — kompatibilita, výrobca/rada, mechanizmus, nosnosť, členovia setu, technická validácia,
- **Zóny:** priestorové/owner väzby vo vnútri korpusu — čo patrí do ktorej zóny a ktoré kovanie/doplnky zóna vlastní.

Pred implementáciou treba pripraviť samostatný UI mockup s dynamickým show/hide správaním pre Čelá/Kovanie/Zóny.
