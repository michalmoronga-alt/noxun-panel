# 07 · Konštrukcia V1 — odsadenia, chrbty, špeciálne korpusy a produktové typy čiel

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

V1 vízia obsahuje viac konštrukčných smerov, ktoré sa nemajú zlúčiť do jedného obrovského „advanced construction“ formulára bez dátového návrhu:

- **V1-01** — per-dielec konštrukčné odsadenia a rozdielne hĺbky dielcov,
- varianty **chrbta** a zadnej konštrukcie,
- niekoľko **špeciálnych korpusov** s vlastnou geometriou,
- **V1-07** — nové produktové typy čiel: lakované, frézované, sklo/Al rám a všeobecnejšie „čelo ako produkt s dodávateľom“.

Zásobník V0.4.8 navyše obsahuje rohové spoje dna/stropu per strana, chrbát s poldrážkou, „bez dielca“ varianty, per-dielec hrúbky a ďalšie odsadenia. Tie sa majú pred implementáciou znovu prejsť proti reálnym zákazkám a aktuálnemu builderu.

---

# A · V1-01 — minimálny jazyk konštrukčných odsadení

## Produktový problém

Najčastejšie dnes chýba možnosť mať rozdielnu hĺbku jednotlivých výrobných dielcov bez potreby vytvárať úplne nový typ skrinky.

Typický reálny príklad:

```text
bok = 560 mm
dno = 500 mm
```

Takýto presah/odsadenie sa používa často a má byť normálnou konštrukčnou voľbou, nie ručným hackom geometrie.

Ďalšie reálne použitia:

- bok ustúpený alebo predĺžený oproti dnu/stropu,
- dno/strop s iným predným alebo zadným odsadením,
- technický priestor alebo vzduchový kanál,
- atypická nika,
- spotrebičový korpus, ktorého rozdiel voči bežnému korpusu je primárne v takýchto odsadeniach.

## Hranica návrhu

Cieľom **nie je** generický CAD editor so šiestimi XYZ offsetmi pre každý diel.

Prvá verzia má pomenovať iba niekoľko opakovaných výrobných vzťahov, pravdepodobne hlavne:

- `front setback / overhang`,
- `back setback / overhang`,
- rozdiel hĺbky medzi bokom a dnom/stropom,
- prípadne explicitný variant „bez dielca“ ako samostatná konštrukčná voľba.

Konkrétny názov a znamienková konvencia sa má určiť až po audite existujúcej lokálnej geometrie a Builder osi.

## Otázka autority

Treba rozhodnúť, či je odsadenie:

- súčasť cabinet construction config,
- `part_override` konkrétneho `part_key`,
- alebo kombinácia defaultu v config + per-part override.

Pracovná preferencia:

- opakovaný konštrukčný typ má patriť do **cabinet/template construction configu**,
- jednorazová výnimka na konkrétnom diele môže byť **per-part override** cez stabilný `part_key`.

To umožní šablónovať reálne typy skriniek bez toho, aby sa každá odchýlka menila na nový hardcoded cabinet class.

## Konštrukčné warnings

Nové možnosti musia mať validačné pravidlá. Príklady:

- odsadenie vytvorí nulový/degenerovaný dielec,
- konflikt s chrbtom/poldrážkou,
- vnútorné zóny zasahujú do technického priestoru,
- diel prestane podopierať očakávané rozhranie,
- rozdiel hĺbky je mimo konštrukčne rozumného rozsahu.

Semafor má upozorniť, nie potichu upravovať vstup.

---

# B · Varianty chrbta

Dnešný systém už pokrýva klasický pevný chrbát, vrátane variantu vloženého do poldrážky/drážky podľa existujúcej konštrukcie.

Treba pridať ďalší praktický typ:

## Chrbát ako dve úzke zadné výstuhy/pásy

Namiesto plného chrbta:

```text
horný pás ~100 mm
spodný pás ~100 mm
```

Ide o dva samostatné výrobné dielce, jeden hore a jeden dole.

Pred implementáciou treba auditovať:

- presné role/`part_key` oboch pásov,
- či šírka/výška pásu je default 100 mm alebo parameter,
- z čoho sa odvodzuje ich poloha,
- či patria do rovnakého material/ABS workflow ako ostatné plošné dielce,
- interakciu s vnútornými zónami a montážnym kovaním,
- či ide o `back_type` variant alebo všeobecnejší construction preset.

Dôležité: plný chrbát, poldrážkový chrbát a dva pásy sa nemajú modelovať ako magické offsety jedného dielca. Sú to **odlišné konštrukčné varianty zadnej časti korpusu**.

---

# C · Špeciálne korpusy

Po produktovej diskusii sa ukazuje, že V1 bude potrebovať minimálne niekoľko špecializovaných korpusov, ale nie všetky musia byť samostatný nový geometrický engine.

## 1. Rohový korpus

Rohový korpus je skutočne geometricky odlišný od bežného pravouhlého korpusu a treba ho viesť ako samostatnú konštrukčnú tému.

Pred implementáciou treba samostatne rozhodnúť:

- ktoré rohové typy V1 reálne potrebuje,
- ich semantické rozmery,
- dielce a stabilné `part_key`,
- väzbu na rohové dvere/čelá,
- zóny/interiér,
- kovanie rohového mechanizmu,
- BuildPlan/BOM/VEPO.

Nemá sa automaticky zahrnúť do prvej malej dávky per-part offsetov.

## 2. Spotrebičový korpus

Spotrebičový korpus je pravdepodobne z veľkej časti **bežný korpus + správne odsadenia/sloty/police**, nie úplne nový geometrický typ.

Tento smer treba zosúladiť so `04_SPOTREBICE_S1.md` a `04A_SPOTREBICE_EXTERNY_AUDIT.md`.

Pracovná hypotéza:

> Ak V1-01 vie korektne modelovať rozdielne hĺbky/odsadenia a korpus má stabilné appliance sloty/zóny, veľká časť spotrebičových skríň môže zostať nad existujúcim cabinet builderom.

Výnimky sa majú riešiť až podľa reálnej potreby konkrétneho spotrebiča.

## 3. Digestorový korpus

Digestorový korpus je odlišnejší a má pravdepodobne zostať špecializovanou šablónou/konštrukčným typom.

Okrem základného korpusu obsahuje ďalšie výrobné dielce:

- kapotáž/kryt digestora,
- kryt komína,
- montážny výrez a priestor pre telo spotrebiča.

Koncept musí zostať zosúladený so Spotrebiče S1: konkrétny digestor dodáva parametre, ale **nábytkovú konštrukciu vlastní NOXUN template/korpus**.

---

# D · V1-07 — typy čiel ako produkt

Lakované, frézované a Al/sklo čelá nie sú iba iný sheet material.

Môžu mať:

- cenu za m²/kus,
- dodávateľa,
- objednávkový kód/vzor,
- odlišný výrobný alebo objednávkový výstup,
- vlastnú hrúbku a hmotnostné vlastnosti,
- iné pravidlá ABS alebo žiadne klasické ABS,
- vlastnú vizuálnu geometriu.

Preto treba rozhodnúť, či `front` zostáva výrobným dielcom sheet triedy alebo môže referovať **externý/front product**.

Možný mentálny model:

```text
Front module
├─ geometry/size
├─ appearance/material intent
└─ production source
   ├─ sheet-made
   ├─ lacquered MDF
   ├─ milled MDF
   └─ aluminium/glass product
```

Toto nie je schéma, iba oddelenie osí.

## Minimálny V1 rozsah čiel

Namiesto veľkej knižnice typov má prvá verzia pokryť približne **3–4 praktické produktové typy**.

Najmä:

- klasické plošné čelo,
- aspoň 2–3 základné typy frézovaných dvierok s vnútorným výfrezom/profilom,
- aspoň 1 typ dvierok s hliníkovým rámom a sklom.

Tu vzniká samostatná geometrická výzva: pri frézovanom alebo Al/sklo čele nestačí iba zmeniť obchodný typ. Aspoň základná 3D reprezentácia musí zodpovedať reálnemu vzhľadu čela.

Pred implementáciou treba rozhodnúť, či:

- sa frézované čelá generujú parametricky,
- alebo sa prvé typy riešia stabilnými šablónami/assetmi,
- Al rám + sklo je parametrická zostava rámových profilov a výplne alebo jednoduchší produktový proxy model.

Pre V1 netreba univerzálny profilový editor.

## Výklop `flap`

Otvorená rola `flap` zo STANDARD/UI-C3 patrí konštrukčne k typu čela, ale jej plná funkcia sa pretína s kovaním fáza 3.

Treba oddeliť:

- **rola/kinematický typ čela** (`door` / `drawer_front` / `flap`),
- **výrobný typ produktu čela** (`sheet` / lak / fréza / Al rám),
- **kovanie** (hinge/lift atď.).

Tieto osi sa nesmú zliať do jedného enumu.

---

# Pracovné rozdelenie budúcich dávok

Toto nie je implementačné poradie, iba produktové členenie:

### K1 · Depth/offset construction
- rozdiel hĺbky bok vs. dno/strop,
- minimum front/back setback/overhang parametrov,
- template + per-part override hranica.

### K2 · Back variants
- plný chrbát,
- poldrážka/drážka podľa aktuálneho systému,
- dva zadné pásy.

### K3 · Special cabinets
- rohový korpus ako samostatný návrh,
- digestorový korpus,
- preveriť, či spotrebičový korpus už pokryje K1 + appliance slots.

### K4 · Front products
- 3–4 praktické V1 typy,
- frézované čelá,
- Al rám + sklo,
- BOM/rozpočet/objednávka + základná geometria.

---

## Otvorené otázky pred implementáciou

1. Aký minimálny počet front/back depth parametrov pokryje reálne atypy bez generického CAD editora?
2. Ktoré nastavenia patria cabinet configu a ktoré per-part override?
3. Ako sa konštrukčné override prenášajú do template?
4. Čo sa stane s override, ak konkrétny `part_key` po zmene konštrukcie zanikne?
5. Ako majú interiérové zóny rešpektovať technické odsadenia?
6. Presná semantika chrbta z dvoch pásov — role, rozmery, pozícia, material/ABS.
7. Ktoré rohové korpusy sú naozaj potrebné vo V1?
8. Je digestorový korpus samostatný builder/type alebo špecializovaná template nad všeobecným builderom?
9. Potrebuje V1-07 nový production class alebo nový `front product` model?
10. Ako sa externé čelo dostane do BOM/rozpočtu/objednávky bez predstierania, že je bežná DTDL doska?
11. Ako parametrizovať 2–3 frézované typy a jeden Al/sklo typ bez budovania univerzálneho front CADu?
12. Ako kombinovať rolu `flap` s produktovým typom a kovaním bez krížového enum chaosu?

## Pred implementáciou

Auditovať cabinet config/builder, `part_overrides`, PartKeys lifecycle, zones/interior geometry, BuildPlan, edge rules, VEPO/BOM, back construction a front builder. Zároveň načítať `04_SPOTREBICE_S1.md` + `04A_SPOTREBICE_EXTERNY_AUDIT.md` pre spotrebičové/digestorové korpusy a `03_KOVANIE_FAZA3.md` pre rohové mechanizmy/flap hardware.

Najprv porovnať tento koncept s reálnym kódom a aktuálnymi šablónami. Až potom rozdeliť K1–K4 na samostatné task packages.
