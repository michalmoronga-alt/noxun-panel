# 04 · Spotrebiče S1

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

V1 vízia definuje spotrebiče ako samostatnú produktovú doménu: katalóg, položky projektu, voliteľná väzba na skrinku, kontrola niche a zapojenie do rozpočtu/cenovej ponuky.

Téma potrebuje návrhovú session najmä preto, že rôzne spotrebiče sa na nábytok viažu odlišne. Rúra, chladnička, umývačka, varná doska, digestor a drez nie sú jeden univerzálny „objekt v skrinke“.

## Navrhované oddelenie vrstiev

### 1. Katalógový záznam

Opis konkrétneho výrobku, napríklad:

- značka/model,
- typ,
- fyzické rozmery,
- požadované niche rozmery/rozsahy,
- cena a dátum overenia,
- URL/zdroje,
- prípadné technické parametre relevantné pre nábytok.

### 2. Projektová položka

Konkrétny spotrebič v zákazke:

- stabilná identita,
- referencia/snapshot katalógového výrobku,
- voliteľná väzba na korpus alebo zónu,
- stav výberu (konkrétny model vs. očakávaný typ),
- položka v rozpočte.

### 3. Kontrola kompatibility

Semafor má porovnať požiadavku spotrebiča s navrhnutým priestorom a upozorniť na nesúlad. Má varovať, nie blokovať.

## Kľúčová otázka väzby

Pred kódom treba rozhodnúť, či spotrebič patrí:

- ku korpusu,
- ku konkrétnej zóne,
- k samostatnému „niche/reference“ objektu,
- alebo podporovať viac typov väzby podľa kategórie.

Príklady:

- rúra/mikrovlnka prirodzene smerujú k zóne,
- umývačka môže byť viazaná na modul/pozíciu v zostave,
- varná doska na pracovnú dosku/segment,
- digestor na hornú zostavu alebo samostatnú pozíciu,
- chladnička môže byť vstavaná v korpuse alebo voľne stojaca.

Preto sa nesmie bez diskusie uzamknúť schéma `appliance.cabinet_id` ako jediný model.

## Šablóny

V1 vízia počíta s tým, že šablóna môže niesť **očakávaný typ spotrebiča**.

Treba rozlíšiť:

- „táto šablóna očakáva rúru“ — produkt ešte nie je vybraný,
- „táto konkrétna skrinka obsahuje Bosch XYZ“ — projektový snapshot.

Semafor môže pri chýbajúcom výbere ukázať ORANGE „spotrebič nevybraný“.

## Snapshot a reprodukovateľnosť

Projekt nesmie byť závislý od živého katalógu. Pred implementáciou určiť, ktoré údaje spotrebiča sa pri použití snapshotujú do `.skp` a ktoré zostávajú iba referenciou na katalóg.

Kandidáti na snapshot:

- identita/model,
- relevantné rozmery,
- niche požiadavky,
- cena + checked_at podľa existujúceho cenového kontraktu,
- technické parametre, ktoré ovplyvňujú výrobnú validáciu.

## Rozpočet a ponuka

Spotrebič má byť samostatná obchodná položka so stavom ceny. Treba rozhodnúť:

- zákaznícka cena vs. nákupná cena,
- či sa spotrebič zobrazuje vždy samostatne,
- ako sa správa prepínač „samostatne“ v cenovej ponuke,
- čo sa stane pri spotrebiči bez ceny alebo bez konkrétneho modelu.

## Otvorené otázky

1. Aký minimálny spoločný model pokryje hlavné typy spotrebičov bez veľkého abstraktného frameworku?
2. Korpus vs. zóna vs. segment — aké väzby V1 skutočne potrebuje?
3. Má S1 obsahovať iba dátové/reference objekty, alebo aj jednoduché viewport kubusy?
4. Ako definovať niche rozsah a tolerancie?
5. Ako sa invaliduje kontrola pri zmene rozmerov skrinky/zóny?
6. Ako sa prenáša očakávaný typ spotrebiča v template?
7. Ktoré kategórie sú naozaj V1 a ktoré vedome odložiť?

## Pred implementáciou

Auditovať project-level dáta, templates, zones, BuildPlan warnings/control payload, budget/offer a aktuálny model snapshot autority. Zostavy môžu neskôr ovplyvniť väzbu varnej dosky/digestora, preto treba zosúladiť hranice s [02_ZOSTAVY_SEGMENTY.md](02_ZOSTAVY_SEGMENTY.md).
