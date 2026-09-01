# KOVANIE — checkpoint USER debaty 2026-09-01 · 06

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Nadväzuje na:** `KOVANIE_DEBATA_CHECKPOINT_2026-09-01_05.md`.
> **Účel:** zachytiť záverečné rozhodnutia pred uzavretím architektúry V1 a oddeliť vedome otvorené audit body.

---

## 1. Objednávkový výstup kovania

Používateľ zvolil **A**:
- výsledný nákupný zoznam agreguje rovnaké konkrétne položky podľa SKU/katalógovej identity,
- napr. jedna podložka použitá na viacerých owneroch sa zobrazí ako jeden riadok s celkovým množstvom,
- po rozbalení musí zostať dohľadateľné, z ktorých skriniek/ownerov množstvo vzniklo,
- cieľ: čistý nákupný zoznam bez straty technického pôvodu.

---

## 2. Otvorený audit bod — konkrétne položky mimo setu

TÉMU NEUZATVÁRAŤ bez ďalšieho auditu nad pripravovaným PR.

Potrebujeme podporiť situácie, kde položka:
- patrí ku konkrétnemu korpusu/čelu/ownerovi/zóne,
- ale nie je prirodzenou súčasťou jedného štandardného hardware setu,
- alebo je len doplnkom navyše.

Motivácia:
- nevyrábať množstvo umelých jednoúčelových/abstraktných setov,
- zároveň zachovať pôvod položky v projekte a objednávke,
- používateľ nemá spätne pátrať, odkiaľ sa položka v BOM vzala.

Príklady:
- zámok na dvere,
- výsuvný vešiak v skrini,
- vypínač,
- magnet,
- adaptér,
- doraz,
- iné `Ostatné` kovanie alebo príslušenstvo.

Pracovná hypotéza používateľa:
- niečo v duchu `Ostatné / Pridať konkrétnu položku`,
- položku priradiť ku konkrétnemu ownerovi / čelu / funkčnej alebo konštrukčnej zóne / celej skrinke,
- nemusí byť členom globálneho setu.

Po PR audite pripraviť 2–3 konkrétne UX + dátové varianty a až potom rozhodnúť finálny kontrakt.

---

## 3. Resolver — žiadny kompatibilný set

Používateľ zvolil **A**:
- ak resolver nenájde žiadny kompatibilný set/technický variant pre ownera, nesmie potichu vybrať nekompatibilný set ani automaticky prepnúť na `Ostatné`,
- owner zostane bez resolved setu ako **hard conflict**,
- Engine ukáže presný dôvod, prečo kompatibilný variant neexistuje,
- používateľ dostane možnosť ručného výberu alebo vedomého prechodu na `Ostatné`,
- hard conflict počas návrhu môže existovať, ale finálna kontrola/výrobný výstup zostáva blokovaný podľa už dohodnutých validačných pravidiel.

---

## 4. Stav pred uzavretím V1 architektúry

Za hlavné architektonické rozhodnutia sa považujú uzavreté najmä:
- OWNER vs SPACE/CONTEXT,
- funkčné zóny,
- zásuvkové/výklopné/sklopné mechanické zostavy,
- front type + Classic/Tip-On osi,
- resolved set + technické varianty,
- resolver, locky, diff a hard/soft validácia,
- snapshot/versioning,
- šablóny s/bez kovania,
- katalóg/set UX,
- drawer manufacturing recipes,
- HK/HF model,
- univerzálny hinge-count rule,
- množstvové pravidlá členov setu,
- agregovaný objednávkový výstup.

Vedome otvorené pred implementáciou:
1. audit konkrétnych položiek mimo setu,
2. presné výrobné/technické dáta a limity pre zásuvkové systémy,
3. presné HK/HF technické pravidlá a kompatibilitné tabuľky,
4. finálne prahy univerzálneho výpočtu počtu závesov,
5. UI mockup pred implementáciou nových Čelá/Kovanie/Zóny interakcií.

Mimo V1:
- všeobecná synchronizácia symetrických/rovnakých čiel,
- lineárne kovanie a ďalšie širšie hardware oblasti, pokiaľ nie sú nevyhnutné pre prvú implementáciu.
