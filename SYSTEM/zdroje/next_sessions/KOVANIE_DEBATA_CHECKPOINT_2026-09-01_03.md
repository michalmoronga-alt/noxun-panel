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
- **Zóny:** priestorové väzby vo vnútri korpusu; po ďalšej debate platí, že zóna nie je automaticky owner kovania, ale často jeho priestorový kontext.

Pred implementáciou treba pripraviť samostatný UI mockup s dynamickým show/hide správaním pre Čelá/Kovanie/Zóny.

---

## 3. Owner model — HF assembly

- pre HF top sa vytvorí samostatný parent owner **HF zostava**,
- HF zostava obsahuje horné čelo, dolné čelo a spoločný AVENTOS HF top set,
- spoločné kovanie vlastní zostava, nie jedno konkrétne čelo,
- zovšeobecnenie mechanických ownerov je zatiaľ pripravené dátovo, ale V1 ho použije primárne pre HF top; neskôr sa môže rozšíriť na ďalšie mechanické zostavy.

---

## 4. Zásadné oddelenie OWNER vs SPACE/CONTEXT

Dnešné kovanie je technicky viazané cez `owner_part_key` na výrobný dielec alebo na celý korpus. To nestačí pre zásuvky/výklopy/HF.

Nový koncept musí oddeliť:
- **OWNER** = kto kovanie vlastní,
- **SPACE / CONTEXT** = do akého priestoru sa kovanie musí zmestiť a z akého priestoru sa odvodzujú technické limity.

Príklady:
- zásuvka F1: owner = zásuvka/F1; space = funkčná zóna za F1,
- HF top: owner = HF assembly; space = funkčná zóna celej HF zostavy,
- klasické dvierka: owner = krídlo alebo zostava; space môže byť nepodstatný,
- nohy: owner = korpus; bez funkčnej zóny.

Kovanie teda môže patriť čelu/zostave a zároveň sa validovať voči zóne.

---

## 5. Konštrukčné zóny vs automatické/funkčné zóny

Dnešná `ZoneTree` predstavuje **konštrukčné zóny**. Ich delenie je viazané na fyzické priečky; polica zónu nedelí. Preto sa zásuvkové priestory nesmú bezmyšlienkovite zapisovať ako ďalšie uzly tej istej konštrukčnej logiky.

Zavádza sa pracovný koncept **automatickej / funkčnej zóny**:
- je odvodený priestor, nie fyzická konštrukcia,
- nevytvára priečky ani výrobné dielce,
- má parent konštrukčnú zónu,
- nesie alebo dopočítava svetlú šírku, výšku a hĺbku,
- vzniká na základe funkčného objektu (napr. zásuvkové čelo, HK/HF zostava), nie primárne na základe kovania,
- kovanie/recept túto zónu následne spresňuje, využíva a validuje.

Príklad vysokej skrinky so štyrmi zásuvkami:
- jedna parent konštrukčná zóna,
- štyri automatické/funkčné child priestory F1–F4,
- bez automatického vytvorenia priečok medzi zásuvkami.

Funkčné zóny sa v UI zobrazujú **kontextovo** (voľba C): napr. po výbere zásuvky/HF alebo pri zapnutej vrstve „Funkčné zóny“; inak nezavadzajú.

---

## 6. Parent väzba funkčnej zóny

- Engine automaticky určí parent konštrukčnú zónu podľa geometrického prekryvu/polohy,
- používateľ môže parent zónu ručne prepnúť,
- ak funkčná zóna zasahuje do viacerých konštrukčných zón naraz, je to **konflikt**, nie heuristické „vezmi najväčší prekryv“,
- jedna funkčná zóna zásuvky má mať jedného jednoznačného parenta,
- pri zmene topológie korpusu sa väzba znovu prepočíta a validuje.

Funkčné zóny sú odvodené:
- po zmene výšky alebo poradia čiel sa automaticky prepočítajú a preskladajú podľa novej geometrie,
- nemajú zostať visieť na starých rozmeroch,
- nie sú určené na samostatné ručné modelovanie ako druhá ZoneTree.

---

## 7. Hlavný účel funkčnej zóny pre zásuvky

Funkčná zóna má byť technický vstup pre resolver zásuvkového systému:
- svetlá výška → výškový variant,
- svetlá hĺbka → nominálna dĺžka výsuvu,
- šírka → vstup do výrobného receptu a neskôr load/recommendation policy,
- celý priestor → kolízne a kompatibilitné kontroly.

Pri zásuvkovom čele Engine:
1. identifikuje parent konštrukčnú zónu,
2. vytvorí/dopočíta funkčnú zónu,
3. z nej vypočíta svetlé rozmery,
4. z vybranej systémovej rodiny automaticky vyberie najvyšší kompatibilný výškový variant a najdlhší kompatibilný NL variant,
5. upozorní na konflikty alebo navrhne kompatibilnú náhradu.

---

## 8. Produktová rada vs konkrétny technický variant

Základné plánované systémové rodiny ostávajú približne:
- Hettich Atira,
- Hettich Quadro,
- Blum TANDEM,
- Blum TANDEMBOX Antaro,
- Blum LEGRABOX.

Knižnica rodín nemusí byť veľká, ale každá rodina má veľa konkrétnych technických variantov podľa výšky, NL, spôsobu otvárania, nosnosti atď.

Rozdelenie:
- **Produktová rada / systém** = napr. Atira,
- **konkrétny technický variant / resolved set** = napr. `Atira H176 · NL520 · Classic · 30 kg`.

Konkrétny technický variant má vlastný kompatibilitný profil, napr.:
- minimálna potrebná svetlá výška funkčnej zóny,
- minimálna potrebná svetlá hĺbka,
- nominal_length,
- side_height / height_class,
- load_capacity_kg,
- opening_mode,
- prípadné min/max width,
- väzbu na immutable výrobný recept a jeho parametre.

Presné hodnoty sa nesmú odhadnúť „+30 / +20“ bez auditu. Treba ich vytiahnuť z technickej dokumentácie a podľa potreby overiť konfigurátormi výrobcov.

---

## 9. Resolved set — UX a technické členenie

Používateľ zvolil variant C:
- navonok sa zásuvkové kovanie správa ako **jeden výsledný resolved set**,
- v detaile je explicitne rozdelená výšková a dĺžková časť + opening mode + nosnosť + komponenty + technické limity.

Príklad:
`Atira H176 · NL520 · Classic · 30 kg`

Detail:
- výšková časť = H176,
- dĺžková časť = NL520,
- opening mode,
- load class,
- konkrétne komponenty,
- technické limity zóny.

---

## 10. Resolver — osová stabilita

Používateľ zvolil A:
- zmena hĺbky prepočíta primárne iba NL,
- zmena svetlej výšky prepočíta primárne iba výškovú os,
- zmena Classic/Tip-On prehodí opening-mode vetvu,
- zmena nosnosti neskôr prehodí load variant,
- ostatné kompatibilné osi sa zachovajú.

Resolver nemá pri malej zmene pôsobiť, že „vymenil celý šuflík“.

---

## 11. Resolver nikdy nemení potichu

Zásadné user rozhodnutie:
- zmena resolved setu alebo jeho osi **nikdy nesmie prebehnúť bez jasnej informácie používateľovi**,
- UI musí ukázať čo sa zmenilo, prečo a čím sa to nahradilo.

Hybridný režim C:
- bežná kompatibilná zmena v rámci toho istého systému sa môže aplikovať spolu s úpravou korpusu, ale následne sa zobrazí jasný diff/súhrn,
- zásadná zmena systému, výrobnej logiky alebo typu kovania vyžaduje návrh a potvrdenie pred aplikáciou.

Pri zmene systému a viacerých osí naraz:
- jeden spoločný prehľad všetkých zmien,
- každá os je rozbaliteľná a môže byť pred potvrdením ručne upravená,
- celé premapovanie sa potvrdí jedným krokom.

---

## 12. Locky / ručné override-y po jednotlivých osiach

Používateľ zvolil A:
- jednotlivé osi sa dajú zamknúť samostatne,
- napr. `🔒 NL470`, ale výška zostáva pod automatikou.

Správanie:
- ak zamknutý variant zostáva kompatibilný, resolver ho nemení; môže iba ukázať odporúčanie lepšieho/väčšieho variantu,
- ak zamknutý variant po zmene geometrie už nie je kompatibilný, Engine zobrazí konflikt a navrhne kompatibilnú náhradu; používateľ musí potvrdiť,
- po potvrdení náhrady nový variant zostane automaticky **zamknutý**,
- pri zmene produktovej rady, kde zamknutá hodnota neexistuje, Engine ukáže konflikt + kompatibilnú náhradu; systém aj lock sa zmenia až po potvrdení,
- pri viacnásobnom konflikte sa použije jeden spoločný diff s možnosťou úpravy každej osi pred jedným potvrdením.

---

## 13. Immutable technické profily a revízie

Používateľ zvolil A:
- technické kompatibilitné limity konkrétneho variantu sú po overení **immutable/versionované** rovnako ako výrobný recept,
- technický profil, recept, kompatibilita a komponenty musia patriť k jednej reprodukovateľnej verzii variantu.

Oprava chyby:
- ak profil ešte nebol použitý v žiadnom projekte, evidentnú chybu možno opraviť priamo,
- po prvom použití/snapshotovaní sa existujúca revízia nemení; oprava vytvorí novú revíziu.

Stavy revízií — používateľ zvolil A:
- `Aktívny`,
- `Deprecated`,
- `Inactive`.

Deprecated variant zostáva zachovaný pre staré projekty/reprodukovateľnosť, ale pri nových projektoch sa už nemá ponúkať ako default.
