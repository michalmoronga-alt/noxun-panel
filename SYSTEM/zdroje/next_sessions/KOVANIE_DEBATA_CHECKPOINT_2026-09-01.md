# KOVANIE — checkpoint USER debaty 2026-09-01

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Účel:** zachovať rozhodnutia z hlasovej debaty s Michalom a umožniť bezpečne nadviazať aj po kompresii kontextu.
> **Súvisiace podklady:** `SYSTEM/PLAN.md` blok KOVANIE, `SYSTEM/DOGFOODING.md` D-109/D-110/D-111, `SYSTEM/POJMY.md` Kovanie — sety, `SYSTEM/zdroje/next_sessions/03_KOVANIE_FAZA3.md`.

---

## 0. Ako tento checkpoint používať

Pri pokračovaní debaty najprv načítať tento súbor. Rozlišovať:

- **ROZHODNUTÉ** — Michal explicitne potvrdil,
- **SMER / ODPORÚČANIE** — návrh z debaty, ktorý dáva architektonický zmysel,
- **ODLOŽENÉ** — zámerne mimo aktuálnej implementácie,
- **ĎALŠÍ BOD** — miesto, kde má debata pokračovať.

Debata má pokračovať po jednom uzatvárateľnom bode. Nemiešať viac tém naraz. Michal diktuje hlasom; pri nejasnom prepise sa radšej opýtať.

---

# 1. ČELÁ — NOVÁ KLASIFIKÁCIA

## 1.1 Typ čela — ROZHODNUTÉ

Typ čela má byť samostatná doménová voľba. Aktuálne cieľové typy:

1. **Dvierka**
2. **Zásuvkové čelo**
3. **Výklop**
4. **Sklop**
5. **Blenda / pevné čelo**

Poznámky:

- `Výklop` a `Sklop` sú samostatné typy, nie jeden typ + smer hore/dole.
- `Blenda` je pevné čelo, ktoré sa neotvára.
- Engine už konceptuálne pozná roly `front_door`, `drawer_front`, `flap`, `false_front`; implementácia/UI sa má zosúladiť s týmto novým používateľským modelom.

## 1.2 Spôsob otvárania — ROZHODNUTÉ

Pre všetky pohyblivé čelá pribudne nezávislá os:

- **Klasické**
- **Tip-On / Push-to-open**

Význam:

### Klasické
Všetko, čo sa otvára **ťahom**. Patrí sem napr.:

- klasická úchytka,
- GOLA profil,
- narážacia úchytka,
- frézované madlo,
- iný spôsob uchopenia, pri ktorom sa základná logika kovania nemení.

Pri dvierkach „klasické“ typicky znamená tlmený záves.

### Tip-On
Otvorenie zatlačením. Pri dvierkach sa oproti klasike mení minimálne:

- záves na P2O variant bez integrovaného tlmenia,
- dopĺňa sa Tip-On piestik / adaptér podľa systému.

Rovnaká os `klasické / Tip-On` platí aj pre:

- zásuvky,
- výklopy,
- sklopy.

Dôležité: spôsob otvárania **nie je typ úchytky**. GOLA vs. klasická úchytka sa nemá miešať do tejto osi.

## 1.3 Blenda — ROZHODNUTÉ

Pri `Blenda / pevné čelo`:

- nemá smer otvárania,
- nemá `Klasické / Tip-On`,
- negeneruje závesy ani výsuv,
- zostáva normálnym výrobným dielom pre materiál, ABS, rozmery, BOM atď.

---

# 2. SMER OTVÁRANIA DVIEROK

## 2.1 Default — ROZHODNUTÉ

Pri klasických dvierkach sa smer má **automaticky prednastaviť** a používateľ ho môže zmeniť.

- pri dvojkrídle: automaticky `ľavé + pravé`,
- pri jednom krídle: engine sa má pokúsiť odvodiť smer z kontextu skrinky,
- ak kontext nestačí: použiť pevný fallback default.

Smer nemá byť zbytočne manuálna povinnosť pri každom novom čele.

## 2.2 Vizuálna kontrola — ROZHODNUTÉ

Všetky čiary, ktoré znázorňujú otváranie, majú byť **prerušované**:

- vo veľkom viewport overlay,
- v malých náhľadoch / ikonách v Inspectore.

Pre blendu použiť **plné `X`** ako symbol fixného čela.

Smer/otváranie sa má dať kontrolovať podobným režimom ako smer dekoru — vizuálny overlay, nie geometrická zmena modelu.

---

# 3. INSPECTOR — UI ČIEL A OTVÁRANIA

## 3.1 Samostatná sekcia — ROZHODNUTÉ

V Inspectore, sekcii Čelá, vznikne osobitná vizuálna časť pre konfiguráciu čela/otvárania. Vertikálneho priestoru je tam dosť a tento obsah tam prirodzene patrí.

Michalova predstava:

1. klikne na konkrétne čelo,
2. v prvom riadku zvolí **typ čela** cez väčšie grafické piktogramy + názvy,
3. ďalšie riadky sa zobrazujú **kontextovo podľa zvoleného typu**,
4. následne sa vyberie smer / spôsob otvárania / zásuvková konštrukcia podľa relevancie.

Neuprednostňovať obyčajné dropdowny tam, kde grafická voľba zlepší orientáciu.

## 3.2 Mockup pred implementáciou — ROZHODNUTÉ

Pred implementáciou spraviť nový/odvodený mockup.

Nemusí vzniknúť celý Inspector od nuly. Je možné použiť staršie mockupy a doplniť len relevantnú časť.

Mockup musí ukázať minimálne:

- typ čela,
- smer otvárania,
- klasické / Tip-On,
- zásuvkovú konštrukciu,
- štandardnú / vnútornú zásuvku,
- výber kompatibilného setu,
- ako sa polia dynamicky objavujú/skryjú,
- ako sa rovnaká klasifikácia prejaví pri zakladaní setu a v katalógu.

Mockup má byť UX brána pred zásahom do dátového modelu a implementácie.

---

# 4. DEFAULT HARDWARE SETY

## 4.1 Automatický výber — ROZHODNUTÉ

Po voľbe typu čela + spôsobu otvárania engine:

1. automaticky vyberie predvolený kompatibilný set,
2. používateľ ho môže zmeniť na iný kompatibilný set.

Cieľ: minimum klikania pri bežnej práci.

## 4.2 Hierarchia defaultov — ROZHODNUTÉ

Defaulty majú byť primárne **globálne firemné**.

Predpokladaná priorita:

`globálny default → projektový override → override konkrétneho čela`

Príklady budúcich globálnych defaultov:

- dvierka + klasické,
- dvierka + Tip-On,
- zásuvka + klasické,
- zásuvka + Tip-On,
- výklop + klasické,
- výklop + Tip-On,
- sklop + klasické,
- sklop + Tip-On.

---

# 5. ZÁSUVKY — KONŠTRUKČNÁ KLASIFIKÁCIA

## 5.1 Konštrukcia zásuvky — ROZHODNUTÉ

Pri `Typ čela = zásuvka` bude ďalšia povinná klasifikačná os:

1. **Drevený box / skrytý výsuv**
2. **Kovové bočnice**
3. **Ostatné / atyp**

Táto klasifikácia slúži súčasne na:

- filtrovanie dostupných setov,
- orientáciu v katalógu,
- výber rodiny výpočtu zásuvky.

Dôležité architektonické pravidlo:

**Konštrukčná kategória nemá natvrdo určovať presný počet výrobných dielcov.**

Napr. `drevený box` vyberá rodinu výpočtu, ale konkrétny systém/set určuje konkrétne vzorce a výsledné derived manufactured parts. Nezakódovať všeobecne „drevený = vždy 5 dielov“ alebo „kovový = vždy 2 diely“.

## 5.2 Ostatné — ROZHODNUTÉ

`Ostatné` slúži pre atypické/málo používané systémy, napr. guľôčkové výsuvy.

Správanie:

- používateľ môže ručne priradiť ľubovoľný set/kovanie,
- môže zadať množstvo,
- engine **negeneruje automaticky zásuvkové výrobné dielce**,
- netreba pre každý exotický systém vytvárať osobitnú výpočtovú logiku.

Michal zvolil variant: **ručné priradenie voľného setu + množstvo, bez automatického výpočtu výplní/dielcov**.

---

# 6. VNÚTORNÉ ZÁSUVKY

## 6.1 Dátový háčik teraz, automatika neskôr — ROZHODNUTÉ

Vnútorné zásuvky sú približne 2–5 % použitia. Zvyčajne ide o variant existujúceho zásuvkového systému; základný výpočet boxu sa zásadne nemení, mení/dopĺňa sa najmä čelná časť setu (napr. Al profil + príchyty/konektory).

Preto sa zavádza budúca vlastnosť:

`drawer_variant = standard | internal`

### V1 smer

- `standard` = plná automatika,
- `internal` = klasifikácia pripravená, ale plná automatika vnútorného čela/setu je odložená,
- `internal` nepatrí pod `Ostatné`, pretože technologicky ide o normálnu Atira/Legrabox/... zásuvku, iba s iným prevedením čela.

Nezakladať teraz druhý kompletný výpočtový systém pre vnútorné zásuvky.

---

# 7. SETY — POVINNÁ KLASIFIKÁCIA

## 7.1 Metadata setu — ROZHODNUTÉ

Pri vytváraní setu bude klasifikácia povinná. Má slúžiť súčasne na:

- filtrovanie v Inspectore,
- automatický výber defaultu,
- triedenie a orientáciu v katalógu,
- výpočtovú logiku tam, kde je relevantná.

Minimálne osi:

1. **Typ čela / použitia**
   - dvierka,
   - zásuvka,
   - výklop,
   - sklop,
   - blenda,
   - ostatné.

2. **Spôsob otvárania**
   - klasické,
   - Tip-On,
   - ostatné.

3. **Konštrukcia zásuvky** — iba pri zásuvke
   - drevený box,
   - kovové bočnice,
   - ostatné.

4. **Výrobca**

5. **Produktová rada**

`Ostatné` je vedomá poistka proti tomu, aby sme kvôli exotike rozširovali doménový model.

## 7.2 Set má jednu klasifikáciu Klasické/Tip-On — ROZHODNUTÉ

Nerobiť multi-kompatibilitu celého setu pre `klasické + Tip-On`.

- jednotlivé komponenty katalógu môžu byť spoločné medzi viacerými setmi,
- kompletný set má mať jednu jasnú klasifikáciu,
- napr. platnička/krytka môže byť rovnaká, ale výsledný klasický a P2O set sa líšia.

---

# 8. VÝROBCA A PRODUKTOVÁ RADA

## 8.1 Povinné kontrolované hodnoty — ROZHODNUTÉ

Set má niesť:

- **Výrobcu**
- **Produktovú radu**

Príklady:

- Hettich → Quadro / Atira / AvanTech
- Blum → Legrabox / ...

Produktová rada je vždy naviazaná na konkrétneho výrobcu.

## 8.2 Žiadny voľný text pre klasifikačné hodnoty — ROZHODNUTÉ

Použiť výberové zoznamy, nie voľné textové polia, aby nevznikali duplicity typu:

`Blum / BLUM / blum / Blim`

V dropdown/list výbere má byť na konci možnosť:

`+ Vytvoriť výrobcu`

resp.

`+ Vytvoriť produktovú radu`

Nová hodnota sa následne uloží centrálne a používa konzistentne.

## 8.3 Ostatné — ROZHODNUTÉ

Výrobca má mať možnosť `Ostatné` pre atypické systémy.

Netreba kvôli každej jednorazovej položke vytvárať nového výrobcu/radu.

## 8.4 Ikony/logá výrobcov — SMER

Ak je to praktické, v UI použiť malé ikony/logá výrobcov, napr. Blum/Hettich, ale vždy spolu s textovým názvom.

Logo je vizuálna pomôcka, nie identita dát.

Toto overiť v mockupe.

---

# 9. PORADIE PRI ZAKLADANÍ SETU

## 9.1 Poradie — ROZHODNUTÉ

Michal upravil pôvodný návrh. Formulár má ísť od doménovej potreby ku konkrétnemu výrobku:

1. **Typ čela / použitia**
2. **Spôsob otvárania**
3. **Konštrukcia zásuvky** — iba ak relevantné
4. **Výrobca**
5. **Produktová rada**
6. **Názov setu**
7. **Členovia setu**

Formulár má byť kontextový: nerelevantné polia sa nezobrazujú.

## 9.2 Názov setu — ROZHODNUTÉ

Použiť kombináciu:

- systém automaticky navrhne názov podľa klasifikácie,
- názov zostane ručne upraviteľný.

Príklad automatického návrhu:

`Hettich · Quadro · Drevený box · Klasické`

Používateľ ho môže zjednodušiť napr. na:

`Quadro V6 Silent`

---

# 10. KATALÓG — DÔSLEDKY NOVEJ KLASIFIKÁCIE

## 10.1 Nová klasifikácia má byť použitá naprieč systémom — ROZHODNUTÉ

Nové metadata nemajú existovať iba v editore setu. Majú zlepšiť:

- orientáciu v katalógu,
- zoskupovanie setov,
- filtrovanie pri výbere,
- kompatibilné možnosti v Inspectore,
- automatické defaulty.

Cieľ: jedna doménová pravda použitá na viacerých miestach UI/logiky.

## 10.2 Katalóg nezahltiť jednorazovými atypmi — SMER

Michal nechce zapĺňať centrálny katalóg drobnými jednorazovými exotickými položkami.

Budúci možný model:

- **projektová/ad-hoc položka** iba v konkrétnom projekte/rozpočte,
- nemusí sa ukladať do hlavného katalógu,
- môže mať názov, cenu, množstvo, poznámku,
- neskôr môže dostať voliteľnú väzbu na konkrétny `cabinet / front / zone`.

Výhoda vo výrobe: pri atypickom komponente je hneď jasné, kam patrí.

**Zatiaľ neimplementovať. Prax ukáže potrebu.**

---

# 11. ARCHITEKTONICKÝ PRINCÍP Z DEBATY

Z aktuálnych rozhodnutí vzniká približná rozhodovacia hierarchia:

```text
ČELO
↓
TYP ČELA
(dvierka / zásuvka / výklop / sklop / blenda)
↓
SPÔSOB OTVÁRANIA
(klasické / Tip-On)
↓
[ak zásuvka]
KONŠTRUKCIA
(drevený box / kovové bočnice / ostatné)
↓
[ak zásuvka]
VARIANT
(standard / internal)
↓
VÝROBCA
↓
PRODUKTOVÁ RADA
↓
KOMPATIBILNÉ SETY
↓
GLOBÁLNY DEFAULT
→ projektový override
→ per-front override
↓
EVALUATION / OUTPUT
```

Toto nie je schválený technický kontrakt ani názvy fieldov. Je to pracovná doménová mapa pre mockup + následný návrh dátového modelu.

---

# 12. VECI Z PREDCHÁDZAJÚCEJ DEBATY, KTORÉ TENTO CHECKPOINT NERIEŠIL

Tieto body sú stále relevantné, ale v dnešnom kole neboli ďalej rozobraté:

- D-109 — pomer člena setu `1 ks na každé začaté N kusov člena X` / per skrinka,
- nohy od šírky 1000 mm a pravidlá 4/6 nôh,
- D-110 — redizajn katalógu a editora setu,
- D-111 — umiestnenie/UX výberu setu podľa výšky sokla,
- poradie polí pri pridávaní jednotlivého kovania,
- živý náhľad expanzie setu,
- výpočty výplní zásuviek,
- výklopy/AVENTOS tabuľkové pravidlá,
- dĺžkové kovanie — odložené po V1 podľa predchádzajúcej debaty.

---

# 13. KDE POKRAČOVAŤ

**Najbližší bod debaty:** `ČLENOVIA SETU A SPÔSOB ICH PRIDÁVANIA`.

Kontext pôvodného problému:

Dnešný editor má tri málo zrozumiteľné cesty:

- `+ člen (kód)` — pevná položka,
- `+ rad podľa NL` — kód podľa nominálnej dĺžky výsuvu,
- `+ pásma podľa parametra` — kód/počet podľa inej hodnoty.

Predbežný návrh z predchádzajúcej debaty bol nahradiť ich jedným:

`+ Pridať člena`

A potom pri členovi riešiť napr.:

**Ako sa určí kód?**
- pevný kód,
- podľa dĺžky výsuvu,
- podľa parametra.

**Koľko?**
- na 1 kus kovania,
- na skrinku/ownera,
- pomer D-109.

TOTO EŠTE NIE JE V DNEŠNEJ DEBATE UZAVRETÉ. Tu nadviazať.

---

# 14. Pracovná zásada pre ďalšie kolá

Po každom väčšom uzatvorenom bloku aktualizovať tento checkpoint namiesto spoliehania sa iba na chatový kontext. Keď bude USER-debata hotová, checkpoint sa nemá stať implementačným spec automaticky — Orchestrator z neho má vytvoriť samostatný implementačný package po audite kódu a mockupe.
