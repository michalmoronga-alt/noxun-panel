# 03 · Kovanie fáza 3

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a cieľ

V1 vízia počíta s treťou fázou kovania, ktorá ide výrazne za dnešné jednoduchšie sety a pravidlá. Diskusia 23. 8. 2026 ukázala, že nejde iba o „inteligentnejší výber závesu alebo výsuvu“.

Cieľový obraz je širší:

> **HW3 = univerzálnejší model ownerov + kusové/dĺžkové/systémové výstupy + automatické pravidlá + odvodené výrobné dielce + voliteľná vizuálna reprezentácia.**

Tento balík má pokryť približne 90–95 % reálne používaného kovania vo workflow NOXUN. Ak sa podarí správne navrhnúť a postupne zaviesť tieto prípady, plugin sa výrazne priblíži kompletnému návrhu vybavenia skríň a presnejšiemu rozpočtu bez ručného dopočítavania.

Implementácia sa má robiť **po malých dávkach**, nie ako jeden veľký rework.

---

## 1 · Základné oddelenie problémov

Kovanie fáza 3 sa nemá zlievať do jednej funkcie. Treba rozlišovať minimálne:

1. **čo existuje v katalógu** — produkty, sety, série, dĺžky, varianty,
2. **čo preferujeme / aké pravidlo platí** — policy/rule,
3. **čo vychádza pre konkrétneho ownera** — evaluation,
4. **čo sa snapshotne do projektu** — reprodukovateľný výsledok,
5. **aké výstupy výsledok vytvorí** — nákup, kusovník, lineárny rez, výrobné dielce, prípadne proxy geometria.

Pracovná mentálna pipeline:

```text
OWNER
  ↓
KONTEXT
rozmery / materiál / hmotnosť / zóna / sokel / typ otvorenia / ...
  ↓
POLICY / RULE
  ↓
EVALUATION
  ↓
SNAPSHOT výsledku
  ↓
OUTPUT
├─ purchase items
├─ linear cut items
├─ manufactured parts
└─ visual representation (voliteľná)
```

Nevytvárať univerzálny programovací jazyk/Rule DSL bez dôkazu, že je potrebný. Pred implementáciou auditovať dnešný `HardwareRules` a radšej ho rozšíriť o konkrétne chýbajúce schopnosti (napr. range/table/richer result), ak to postačí.

---

## 2 · Generic type ≠ konkrétny výrobok

Doménovú potrebu a konkrétny katalógový produkt treba držať oddelene.

Príklady:

```text
generic_type: hinge
→ konkrétny Blum/Hettich záves

generic_type: lift
→ konkrétny Aventos set / kombinácia

generic_type: slide
→ Atira / Quadro / Legrabox variant
```

Konštrukčný model sa nemá natvrdo viazať na jedno SKU výrobcu.

Zároveň samotný `generic_type` nemá niesť celú semantiku. Užitočné sú aj nezávislé osi typu:

- **measurement/evaluation:** `piece | linear | system`,
- **output:** `purchase_only | linear_cut | manufactured_parts | mixed`,
- **representation:** `none | proxy | asset`.

Tieto názvy nie sú schválená schéma — sú pracovná klasifikácia pre audit.

---

## 3 · Owner model sa musí rozšíriť

Kovanie už nemožno chápať hlavne ako položku priradenú čelu.

Reálne ownery:

### Čelo
- záves,
- výklop,
- narážacia úchytková lišta,
- ďalšie prvky odvodené od rozmeru/typu čela.

### Korpus
- nohy,
- rohový mechanizmus / „ľadvinka“,
- niektoré skrinkové sety.

### Zóna / vnútorné členenie
- vešiaková tyč,
- potenciálne ďalšie vnútorné vybavenie.

### Neskôr segment
- možné spoločné lineárne/systémové prvky, ak to prax potvrdí.

Koncepčne musí vedieť hardware/evaluation ukázať na ownera napr. `cabinet`, `front:F2`, `zone:Z3`; presný kontrakt až po audite existujúcej identity vrstvy.

Dôležité: **owner nie je to isté ako všetky vstupy pravidla.** Napr. rohový mechanizmus môže vlastniť korpus, ale evaluation číta aj čelo, smer otvorenia alebo rozmery otvoru.

---

## 4 · Kusové kovanie

Existujúci model je najbližšie tejto kategórii:

- závesy,
- nohy,
- podperky,
- držiaky,
- spojovacie prvky,
- ďalšie položky nakupované na kusy.

Výstup je typicky:

```text
produkt/set
quantity = N ks
```

### Kandidáti na rozšírenie pravidiel

- typ a smer závesu,
- počet závesov podľa čela,
- rodina nôh podľa výšky sokla,
- počet nôh podľa šírky/konštrukcie,
- rohové mechanizmy podľa typu a rozmerov korpusu.

---

## 5 · Dĺžkové kovanie / linear hardware

Toto je veľká nová kategória. `quantity = 1` nestačí — systém musí poznať **reznú dĺžku**.

Kandidáti:

- UKW7 a ďalšie narážacie úchytkové lišty,
- GOLA / profilové úchytky podľa reálneho použitia,
- vešiakové tyče,
- LED profily,
- LED pásy,
- difúzory,
- ďalšie rezané profily.

Pracovný výsledok:

```text
UKW7
597 mm × 2
897 mm × 1
```

### Dva budúce výstupy

1. **rezací/kusovníkový výstup** — presné dĺžky, ktoré treba narezať,
2. **nákupný výstup** — koľko skladových tyčí/balení treba kúpiť.

Optimalizácia skladových dĺžok (napr. 3000 mm profil → viac rezov + odpad) je samostatný neskorší problém. V prvej fáze stačí, aby dátový kontrakt nestratil `cut_length`.

---

## 6 · Vešiaková tyč — reprezentatívny linear + zone-owner prípad

Vešiaková tyč je vhodný prvý kandidát pre nový model:

```text
owner: zóna / vnútorné pole
→ svetlá šírka zóny
→ ľavé/pravé odsadenie
→ cut_length
→ lineárny výstup
→ jednoduchá proxy geometria
```

Príchytky/držiaky môžu vzniknúť ako kusový nákupný output bez geometrie.

### Geometria

Tu je schválený smer: **jednoduchá proxy geometria je žiaduca už v tej istej fáze**. Dôvod nie je render detail, ale okamžitá vizuálna kontrola vybavenia skrine. Stačí jednoduchý oválny profil natiahnutý na vypočítanú dĺžku.

Nie je potrebné modelovať príchytky.

---

## 7 · LED — prvá fáza zámerne jednoduchá

LED zatiaľ nerozširovať na plnú elektro-doménu.

### V prvej fáze riešiť

- LED profil — lineárny rozmer,
- difúzor — lineárny rozmer,
- samotný LED pás — lineárny rozmer,
- jednoduchú vizuálnu proxy profilu v modeli.

### Vedome teraz neriešiť

- trafo/zdroj,
- wattáž a dimenzovanie,
- kabeláž,
- senzory/vypínače,
- elektrické trasy.

Jedna LED zostava tak môže generovať **viac nákupných/lineárnych outputov**, ale geometricky jej stačí jedna jednoduchá sivá proxy lišta.

### Budúci vizuálny „light proxy“

Neskôr je zaujímavý samostatný kontrolný vizuál svetla: nie fyzikálne presný render, ale jednoduchý V-/kužeľový objem so svetelným prechodom na osobitnej vrstve/tagu. Účel:

- jedným prepínačom vidieť, kde LED je,
- kam približne svieti,
- kde chýba alebo je otočená zle.

Takýto objekt je výhradne vizuálna/control vrstva — nevstupuje do BOM, VEPO ani rozpočtu.

---

## 8 · Vizuálna reprezentácia kovania je samostatná os

Výrobná/nákupná pravda a 3D reprezentácia nie sú to isté.

### `none`
Položka existuje v dátach, ale 3D model nemá význam.

Príklady: držiaky tyče, väčšina spojovacieho kovania.

### `proxy`
Jednoduchá generovaná geometria má vysokú vizuálnu hodnotu a nízku komplexnosť.

Príklady: vešiaková tyč, UKW7, LED profil.

### `asset`
Presný 3D model výrobcu/knižnice.

Príklady do budúcnosti: výsuvy, Aventos, Legrabox, Quadro.

Michal má pripravené/zaobstarateľné kompletné 3D knižnice Hettich/Blum pre konkrétne dĺžky, výšky a komponenty setov. **HW3 nemá teraz generovať detailnú 3D geometriu týchto systémov.** Neskoršie napojenie na hotové assety je samostatná vrstva a nesmie blokovať výrobné výpočty.

---

## 9 · Zásuvkové systémy

### Atira

Aktuálne je podporená základná rodina dĺžok/výšok. Ďalší cieľ:

- správny variant / nominálna dĺžka,
- správna výška bočnice,
- nákupné hardware položky,
- **výpočet dna**,
- **výpočet chrbta**,
- stabilné identity odvodených dielcov,
- BOM / VEPO / materiál / rozpočet.

Detailná 3D geometria výsuvu sa nerieši.

### Quadro

Nový kandidát. Skrytý výsuv + celodrevený zásuvkový box.

Výstup bude kombinovať:

- hardware položky Quadro,
- viac odvodených výrobných dielcov zásuvky.

Je to vhodný test pre architektúru **derived manufactured parts**.

### Legrabox

Pridať najčastejšie používané série/varianty. Architektonicky je bližšie Atire: kovový systém + odvodené výrobné dielce (najmä dno/chrbát podľa konkrétneho systému).

### Detailné 3D modelovanie zásuviek

**Vedome mimo HW3 výrobnej fázy.** Výrobná pravda má prednosť: správne kovanie, rozmery dielcov, BOM, VEPO, nákup a cena. Presné modely sa neskôr môžu vkladať z hotovej knižnice podľa vyhodnoteného variantu.

---

## 10 · Derived manufactured parts

Hardware evaluation môže viesť k výrobným dielcom, ale pravidlo nemá priamo kresliť geometriu.

Pracovný princíp:

```text
hardware/system evaluation
→ hardware outputs
→ manufactured-part descriptors
→ BuildPlan materializuje výrobnú pravdu
```

Pri zásuvkách treba pred implementáciou uzavrieť:

- owner týchto dielcov,
- stabilné `part_key`,
- cestu do BuildPlan/BOM/VEPO,
- snapshot vstupov/vzorcov,
- template reprodukovateľnosť.

Pracovný smer identity je viazať dielce na konkrétnu zásuvku/front/owner (`drawer:F2/bottom`, `drawer:F2/back` alebo ekvivalent), nie iba všeobecne na celý cabinet.

Fáza A = výrobný snapshot a výstupy. Fáza B = prípadná geometria neskôr.

---

## 11 · Aventos / tabuľkové pravidlá

Výklopy sú reprezentatívny prípad, kde jednoduché `if` pravidlá pravdepodobne nestačia.

Pracovný reťazec:

```text
čelo
→ rozmery + materiál + density snapshot
→ hmotnosť
→ výrobné rozsahy/tabuľka
→ konkrétny set/kombinácia
→ vysvetlenie
```

Výrobné tabuľky (napr. Blum) je vhodné držať ako dáta/data pack, nie natvrdo ako desiatky Ruby podmienok, ak audit potvrdí túto potrebu.

Rule/evaluation výsledok má niesť aj **explainability**: systém má vedieť povedať, prečo vybral konkrétny set.

---

## 12 · AUTO vs MANUAL

Automatika navrhuje, používateľ rozhoduje.

Potrebné stavy:

- `AUTO` — výsledok pravidla,
- `MANUAL` — používateľ vynútil konkrétny produkt/set/variant,
- `MANUAL ⚠` — manuálna voľba ostáva zachovaná, ale po zmene rozmerov/čela už neleží v odporúčanom rozsahu.

Engine nemá manuálnu voľbu potichu prepísať naspäť na AUTO.

Návrat na pravidlo musí odstrániť celý relevantný override bez zvyškov starého manuálneho stavu.

---

## 13 · „Použiť na podobné“

Pri hardvéri sa nemá bezhlavo kopírovať celý vypočítaný override/result blob.

Preferovaný význam:

> preniesť voľbu rodiny/policy a každý cieľ znovu vyhodnotiť podľa vlastných rozmerov.

Príklad: „Použiť rovnaký systém výsuvu = Atira“ je bezpečnejšie než kopírovať `NL=500`, ak druhá zásuvka potrebuje inú nominálnu dĺžku.

Presný rozsah tejto funkcie až po audite owner modelu a existujúcich podobnostných operácií.

---

## 14 · Reprezentatívne prípady pre návrh architektúry

HW3 sa má implementovať postupne. Pred veľkým rozšírením je užitočné overiť architektúru na typovo rozdielnych prípadoch:

1. **vešiaková tyč** — zone owner + linear output + proxy geometria,
2. **Aventos** — komplexnejšie range/table vyhodnotenie + explainability,
3. **Atira alebo Quadro** — hardware + derived manufactured parts.

Ak spoločný kontrakt unesie tieto prípady bez ad-hoc hackov, je dobrý základ pre väčšinu zvyšku.

Pracovné produktové členenie dávok môže byť napr.:

- **HW3-A** owner/output kontrakt,
- **HW3-B** jednoduché lineárne prvky (UKW7, tyč, LED),
- **HW3-C** drawer systems,
- **HW3-D** inteligentné/tabuľkové kovanie,
- **HW3-E** asset library neskôr.

Toto **nie je záväzný implementačný plán ani poradie**. Poradie sa má prispôsobiť reálnej zákazke a výsledku auditu.

---

## Otvorené auditné otázky

1. Do akej miery dnešný `HardwareRules` už unesie piece/linear/system výsledky a kde treba nový kontrakt?
2. Ako generalizovať owner identity bez rozbitia dnešných front/cabinet setov a snapshotov?
3. Ako lineárne položky reprezentovať v nákupe, rozpočte a budúcom rezacom kusovníku?
4. Ktoré vstupy/výrobné tabuľky snapshotovať do projektu pre reprodukovateľnosť?
5. Presný owner a `part_key` odvodených zásuvkových dielcov.
6. Formát výrobca-specific data packov (Blum/Hettich) a ich verzovanie.
7. Ako zachovať dnešné hardware sety/templates pri bohatšom výsledku evaluácie?
8. Ako proxy geometria vzniká a obnovuje sa bez toho, aby sa stala autoritou výrobných dát?

Tieto body neblokujú pokračovanie produktovej diskusie; majú sa uzavrieť čerstvým code auditom pred príslušnou implementačnou dávkou.

## Pred implementáciou

Auditovať dnešný hardware catalog, `HardwareRules`, hardware sets, owner model, BuildPlan hardware payload, templates, rozpočet/nákup, existujúcu UKW proxy geometriu a aktuálne H-dávky. Až potom rozhodnúť, ktoré časti sú rozšírenie dnešného kontraktu a ktoré vyžadujú novú dátovú vrstvu.
