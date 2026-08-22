# 02 · Zostavy / segmenty

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

`STANDARD.md` už pozná pojem **ZOSTAVA** ako logické zoskupenie korpusov, ale vo V1 zatiaľ bez vlastnej geometrie. Roadmapa zároveň plánuje funkcie, ktoré tento pojem nevyhnutne konkretizujú: pripájanie a zarovnávanie korpusov, spoločný sokel, pracovná doska cez segment, horné krycie dosky, pilastre/obklady a ďalšie krycie prvky.

Ide pravdepodobne o jednu z najväčších zostávajúcich dátovo-architektonických tém V1. Preto sa nemá riešiť sériou lokálnych snap helperov bez spoločného modelu.

## Hlavná otázka

Treba rozhodnúť, čo je zostava/segment v dátovom modeli.

### Variant A — explicitná entita

```text
SEG-001 · Kuchynská linka
├─ CAB-001
├─ CAB-002
├─ CAB-003
├─ pilaster
├─ worktop
└─ plinth
```

Segment má identitu, členstvo, prípadné vlastné nastavenia a môže vlastniť spoločné prvky.

### Variant B — odvodená sieť väzieb

```text
CAB-001 connected_to CAB-002
CAB-002 connected_to CAB-003
```

„Segment“ vzniká až ako connected component z väzieb medzi skriňami.

Oba prístupy majú iné dôsledky pre snapshoty, Undo, migrácie, šablóny, výstupy a budúcu kontrolu sektoru.

## Produktový cieľ

Používateľ má vedieť rýchlo poskladať reálny rad skriniek a potom nad ním vykonávať operácie na úrovni celku:

- pripojiť/zarovnať korpus k susedovi,
- vložiť korpus medzi existujúce,
- presúvať logický segment,
- vytvoriť pracovnú dosku nad označeným segmentom,
- vytvoriť spoločnú soklovú lištu,
- vytvoriť krycí bok/pilaster/hornú dosku,
- izolovať alebo kontrolovať segment,
- regenerovať spoločné prvky po zmene členov.

## Kľúčové invarianty na diskusiu

- Korpus zostáva samostatnou autoritatívnou NOXUN entitou.
- Segment nesmie znejasniť vlastníctvo výrobných dielcov.
- Spoločné prvky potrebujú jednoznačného vlastníka a stabilnú identitu.
- Pripájanie nesmie vytvárať skryté väzby, ktoré používateľ nevie zrušiť alebo pochopiť.
- Rebuild jedného korpusu nesmie svojvoľne rozbiť členstvo zostavy.
- Undo musí vrátiť logickú aj geometrickú zmenu ako zrozumiteľný krok.

## Attachment model

Pred implementáciou treba navrhnúť spoločný jazyk pripájania. Kandidáti:

- ľavá/pravá čelná hrana,
- ľavá/pravá zadná hrana,
- referenčná čelná rovina,
- výškové zarovnanie,
- medzera/offset,
- typ spojenia (pevné členstvo vs. iba jednorazové prisunutie).

Treba zabrániť tomu, aby každý budúci nástroj (snap, worktop, sokel, pilaster) používal vlastné ad-hoc pravidlá susedstva.

## Spoločné prvky segmentu

Osobitne vyspecifikovať:

- pracovná doska — jedna doska, viac dosiek, spoje, presahy,
- sokel — po ktorých hranách vedie, čo robí pri odskočení korpusu,
- horná krycia doska,
- krycie boky/pilastre,
- obklady/zástena,
- budúce lineárne prvky.

Otázka vlastníctva je zásadná: vlastní ich segment, konkrétny korpus alebo samostatná top-level entita referujúca segment?

## Súvislosti

Téma sa priamo viaže na:

- budúcu plošnú kontrolu **per sektor/zostava**,
- quick move/snaper nástroje,
- bezpečné kopírovanie NOXUN skriniek,
- pracovné dosky a krycie prvky,
- budúce rohové/špeciálne typy korpusov.

## Otvorené otázky

1. Je segment explicitná entita alebo odvodená skupina väzieb?
2. Môže korpus patriť do viacerých segmentov?
3. Ako sa správa kopírovanie celého segmentu?
4. Čo sa stane, keď používateľ ručne posunie jeden člen mimo radu?
5. Má byť členstvo automaticky zrušené, iba označené ako rozpojené alebo sa má geometria vrátiť?
6. Kto vlastní generované spoločné dielce?
7. Ako sa identifikujú spoje pracovnej dosky a sokla?
8. Aký minimálny model stačí pre V1 bez toho, aby sa uzavrela cesta k neskorším komplexným zostavám?

## Pred implementáciou

Povinne auditovať `STANDARD` hierarchiu/identity, dnešný board model, cabinet builder/rebuild, copy/dedup observer, transformácie, Undo operácie, templates a plánované quick actions. Až potom vytvoriť návrh dátového kontraktu zostavy.
