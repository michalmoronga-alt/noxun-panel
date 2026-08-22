# 02 · Zostavy / segmenty

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

`STANDARD.md` už pozná pojem **ZOSTAVA** ako logické zoskupenie korpusov, ale vo V1 zatiaľ bez vlastnej geometrie. Roadmapa zároveň plánuje funkcie, ktoré tento pojem nevyhnutne konkretizujú: pripájanie a zarovnávanie korpusov, spoločný sokel, pracovná doska cez segment, horné krycie dosky, pilastre/obklady a ďalšie krycie prvky.

Téma bola rozpracovaná v strategickej diskusii 23. 8. 2026. Michal doplnil reálny workflow a bolesti: segment má byť nielen skupina geometrie, ale užitočný scope pre pravidlá, rozmery a spoločné/viazané diely; zároveň musí zostať pochopiteľný a nesmie vytvoriť druhý „Master Component“ plný skrytej automatiky.

Ide pravdepodobne o jednu z najväčších zostávajúcich dátovo-architektonických tém V1. Preto sa nemá riešiť sériou lokálnych snap helperov bez spoločného modelu.

## Uzavreté smerovanie z diskusie

### 1 · Segment je explicitná entita

Preferovaný smer je **explicitný segment so stabilnou identitou**, nie iba connected-component odvodený zo susedností.

```text
SEG-001 · Kuchyňa — hlavná stena
├─ CAB-001
├─ CAB-002
├─ CAB-003
├─ WORKTOP-01
├─ PLINTH-01
└─ PILASTER-01
```

Segment drží členstvo, poradie, lokálnu orientáciu, prípadné scoped pravidlá a môže vlastniť spoločné alebo naviazané prvky. Korpus zostáva autoritou vlastnej konštrukcie/configu.

### 2 · Membership a attachment sú dve rozdielne veci

- **membership** = objekt patrí do segmentu,
- **attachment/dependency** = objekt je priestorovo alebo semanticky naviazaný na inú entitu/referenciu.

Skrinka sa teda nemá automaticky vyradiť zo segmentu len preto, že ju používateľ posunie. Geometrická odchýlka môže vytvoriť warning, nie tichú zmenu identity alebo členstva.

### 3 · Segment nie je parametrická mega-skrinka

Segment nesmie vlastniť kompletné rozmery a config všetkých členov. Nemá byť novou verziou Dynamic Components mastera. Má byť nadradený scope/vzťahová vrstva: členstvo, pravidlá, alignment, shared parts a dependency graph.

## Scope dedenia — projekt → miestnosť → segment → skrinka → dielec

Michal chce, aby **segment a neskôr miestnosť** mohli niesť vlastné pravidlá materiálov a kovania. Príklad:

```text
PROJECT
  korpus = biely
  čelá = biele

ROOM Spálňa
  ↓
SEG-01
  čelá = hnedé

SEG-03
  korpus = sivý
```

Preferovaný model je hierarchické dedenie:

```text
PROJECT
  ↓
ROOM
  ↓
SEGMENT
  ↓
CABINET
  ↓
PART
```

Dôležité pravidlá:

- scope neurčuje ľubovoľný interný config; potrebuje **whitelist dediteľných politík**,
- kandidáti: korpus/čelá/chrbát/police, vybrané hardware family/profile, prípadne ďalšie bezpečné projektové defaulty,
- lokálny override na skrinke/dielci musí mať vyššiu prioritu,
- UI musí vedieť vysvetliť **zdroj efektívnej hodnoty**: Projekt / Miestnosť / Segment / Skrinka / Dielec.

Pri zmene segmentového pravidla má systém pred zápisom ukázať impact preview, napr.:

> Zmena ovplyvní 7 skriniek. 2 skrinky majú vlastný override a zostanú nezmenené.

Až potvrdenie vykoná zmenu, ideálne ako jeden Undo krok. Michal tento smer potvrdil.

### Profily vs. scope

Na ďalšiu diskusiu je otvorené, či vzniknú znovupoužiteľné **profily pravidiel** (napr. „Spálňa orech“, „Sivé korpusy“) oddelené od scope. Konceptuálne:

- **scope** = kde pravidlo platí,
- **profile** = aká sada pravidiel sa používa.

To môže znížiť chaos oproti ad-hoc „skupinám“, ale zatiaľ to nie je uzavreté rozhodnutie.

## Rozmery a alignment segmentu

Michal chce, aby segment vedel niesť aj rozmerové pravidlá — napr. výšku sokla 100 mm, výšku horných skriniek, prípadne cieľovú šírku celej zostavy. Tu treba rozlišovať najmenej tri typy správania.

### A · Defaults

Bezpečný príklad:

- výška sokla,
- hĺbka spodných,
- výška horných,
- hĺbka horných.

Otvorené je, či zmena defaultu živým dedením upraví existujúce skrinky alebo iba nové. Toto sa vedome **neuzavrelo**.

### B · Alignment policies

Semantické pravidlá sú vhodnejšie než surové X/Y/Z:

- spoločná čelná rovina,
- spoločná zadná rovina,
- spoločná horná hrana,
- spoločná spodná hrana,
- požadované/voliteľné zarovnanie.

Používateľ nemá pracovať s interným X/Y/Z; segment však pravdepodobne potrebuje vlastný lokálny súradnicový systém:

```text
local X = smer zostavy
local Y = hĺbka
local Z = výška
```

### C · Cieľový rozmer segmentu

Napr. „segment má mať 3280 mm“ už predstavuje layout/solver problém. Engine musí vedieť, **kam rozdiel patrí**: filler, vybrané skrinky, rozdelenie, medzera, pilaster. Automatické tiché rozťahovanie je nevhodné.

Toto patrí až do neskoršej vrstvy.

## Semantické referencie namiesto jedného `segment.height`

Po diskusii sa ukázalo, že jednoduché `segment.width/height/depth` nestačí ako riadiaca pravda. Segment môže obsahovať spodné, horné aj vysoké skrinky a jeho bbox výška nemá význam pre pracovnú dosku.

Treba rozlišovať:

- **geometrické bounds** — informačné,
- **semantické referencie** — použiteľné pre väzby.

Kandidáti referencií:

- floor,
- front_plane,
- back_plane,
- base_top,
- upper_bottom,
- upper_top,
- left_boundary,
- right_boundary.

Konkrétny zoznam nesmie byť uzavretý od stola; má vzniknúť z prvých reálnych use-caseov.

## Viazané a spoločné diely

Michal explicitne preferuje, aby aspoň časť segmentových dielov bola **živá**. Zároveň je nutné zabrániť „magickým“ väzbám a nepredvídateľným rebuildom.

Navrhované tri kategórie:

### A · Generované diely

Geometria je deterministicky odvodená zo segmentu:

- pracovná doska,
- spoločný sokel,
- horná krycia doska.

### B · Anchored diely

Používateľ vloží diel, ale jeho poloha/rozmer je explicitne naviazaný na semantickú referenciu:

```text
PIL-01
owner: SEG-01
anchor: CAB-003.right_outer_side
```

Pilaster môže napr. sledovať pravú hranu poslednej skrinky, hornú referenciu segmentu a vlastnú šírku držať lokálne.

### C · Free member

Diel patrí do segmentu, ale Engine neriadi jeho geometriu. Dnešná sloboda samostatných dosiek sa musí zachovať.

## Živé väzby — bezpečnostná filozofia

Príklad: tri spodné skrinky majú hornú rovinu 720 mm a pracovná doska je na nich naviazaná. Ak jedna skrinka zmení výšku na 740 mm, systém **nemá slepo posunúť celú pracovnú dosku na 740 mm**.

Preferované správanie:

> ⚠ Skrinky pod pracovnou doskou už nemajú spoločnú hornú rovinu.
> CAB-01 720 · CAB-02 740 · CAB-03 720

Teda živé objekty sa majú viazať na explicitné semantic anchors/constraints a pri rozbití invariantov majú vytvoriť zrozumiteľný stav/warning, nie nečakanú dominovú zmenu.

## Dependency graph a explainability

Treba oddeliť dva paralelné modely:

### Scope inheritance

```text
PROJECT → ROOM → SEGMENT → CABINET → PART
```

### Dependency graph

```text
SEG-01
├─ WORKTOP-01
├─ PLINTH-01
└─ PILASTER-01 → anchor CAB-003.right
```

Tieto dva modely sa nemajú zlievať.

Každý živý/naviazaný objekt musí vedieť používateľovi vysvetliť:

- kto je jeho owner,
- na čo je naviazaný,
- ktoré parametre sleduje,
- čo je vlastný override,
- či sú väzby aktuálne platné.

Opačne musí parent vedieť ukázať, **ktoré objekty na ňom závisia**. Delete/odpojenie potrebuje bezpečný flow typu: zmazať aj závislé / odpojiť / zrušiť.

## Inteligentné návrhy a vkladanie

Engine môže z geometrie a členstva časom zistiť, kde dáva zmysel:

- krycí bok,
- pilaster,
- pracovná doska,
- sokel,
- filler.

Návrh však nesmie znamenať okamžitú tvorbu. Preferovaný UX smer je **ghost preview → rozmery/väzba → potvrdenie**.

Automatické návrhy patria až nad stabilný segment core a dependency model.

## Miestnosť / BIM-lite — vedome po V1

Michal dnes reálne vytvára geometriu miestnosti cez **MagicPlan**: meria laserovým metrom, exportuje SketchUp súbor a v projekte ho vloží, 10× zväčší a posunie približne o 20 mm hore. Export obsahuje okrem stien aj dvere, okná, zásuvky, vodovodné prípojky a ďalšie prvky.

To vytvára veľmi silný kandidát na neskoršiu vrstvu **Room / Spatial Intelligence**, ale aktuálne je to scope creep a nemá vstúpiť do V1 implementácie segmentov.

Možný budúci model:

```text
PROJECT
└─ ROOM
   ├─ walls
   ├─ openings/windows/doors
   ├─ electrical points
   ├─ water points
   └─ SEGMENT...
```

Potenciálne kontroly:

- zásuvka zasahuje do priečky,
- zásuvka skončí za zásuvkovým blokom,
- spotrebič nemá vhodnú elektrickú prípojku,
- drez/umývačka nemá vhodnú vodu,
- skrinka koliduje s oknom/dverami,
- montážne odstupy,
- automatický údaj m² navrhovaného priestoru do rozpočtu.

Dôležitá myšlienka: NOXUN by nemusel geometriu miestnosti vytvárať; MagicPlan už robí meranie/modelovanie. Budúci modul by mohol fungovať ako **adapter + semantic parser nad importom**. Pred akýmkoľvek návrhom treba auditovať stabilitu štruktúry MagicPlan SketchUp exportu, jednotky, identifikáciu objektov a aktualizáciu opakovaného zamerania.

Room má byť nadradený organizačný/konfiguračný scope nad segmentmi, nie geometrický master. Prípadný FLOOR je ešte vyššia a zatiaľ nepotrebná úroveň.

## Potenciál vnútorných podskupín / runs

Diskusia ukázala možný neskorší model:

```text
ROOM Spálňa
└─ SEG-01 Hlavná stena
   ├─ spodné skrinky
   ├─ horné skrinky
   └─ vysoké skrinky
```

Samostatnú entitu `RUN` zatiaľ **nevytvárať**. Dátový návrh segmentu by však nemal budúcu vnútornú podštruktúru znemožniť.

## Navrhované postupné dozrievanie

Nie je to implementačný plán; ide o bezpečné vrstvenie konceptu:

1. **Segment Core** — identita, názov, membership, poradie, lokálna orientácia; bez automatickej geometrie.
2. **Scoped settings** — pár bezpečných materiálových/hardware pravidiel + impact preview.
3. **Attachments medzi skrinkami** — explicitné semantic väzby a jednoduché zarovnanie/reflow.
4. **Prvý živý segmentový diel** — pracovná doska ako proof-of-concept.
5. **Anchored parts** — pilastre, fillers, krycie panely.
6. **Intelligent suggestions** — až nad stabilným základom.
7. **Sector review** — plošná kontrola naviazaná na segment, až keď je segmentová identita a scope stabilný.

## Kľúčové invarianty

- Korpus zostáva samostatnou autoritatívnou NOXUN entitou.
- Segment je explicitná logická/priestorová jednotka, nie parametrická mega-skrinka.
- Membership ≠ attachment ≠ scope inheritance.
- Spoločné prvky potrebujú jednoznačného vlastníka a stabilnú identitu.
- Živé väzby musia byť viditeľné, vysvetliteľné a zrušiteľné.
- Rozbitý constraint má vytvoriť warning/stav, nie tichú dominovú zmenu.
- Scope zmena musí mať impact preview pri masovom zásahu.
- Rebuild jedného korpusu nesmie svojvoľne rozbiť členstvo zostavy.
- Undo musí vrátiť logickú aj geometrickú zmenu ako zrozumiteľný krok.
- Budúci Room/MagicPlan smer nesmie nafúknuť V1 segment scope.

## Otvorené otázky

1. Môže korpus patriť do viacerých segmentov, alebo presne do jedného segmentu v rámci room?
2. Ako sa správa kopírovanie celého segmentu a jeho dependency graphu?
3. Ako sa správa ručný posun člena, ktorý má explicitný attachment?
4. Ktoré scoped hodnoty sú živé dedenie a ktoré iba default pre nové objekty?
5. Ako presne sa majú propagovať rozmerové pravidlá segmentu (najmä sokel/výška/hĺbka)? — **vedome otvorené**.
6. Aký minimálny set semantic anchors stačí pre prvé use-casy?
7. Kto presne vlastní generované spoločné dielce v dátovom kontrakte (`segment-owned part` vs. top-level entita s `segment_id`)?
8. Ako sa identifikujú a editujú spoje pracovnej dosky/sokla pri dlhých alebo zalomených zostavách?
9. Potrebujeme neskôr explicitnú vnútornú entitu RUN, alebo stačia skupiny/filtre nad členmi segmentu?
10. Ako sa má správať segment pri broken alignment: iba warning, ponuka opravy, alebo voliteľný live constraint?

## Pred implementáciou

Povinne auditovať `STANDARD` hierarchiu/identity, dnešný board model, cabinet builder/rebuild, copy/dedup observer, transformácie, Undo operácie, templates, dnešné projektové/material inheritance cesty, planned quick actions a Studio/Inspector UX. Až potom vytvoriť návrh dátového kontraktu zostavy.

Osobitne: dokument zachytáva produktové smerovanie z rozhovoru, **nie overenú implementačnú pravdu o aktuálnej codebase**. Neisté body (najmä ownership shared parts, scope propagation, attachment lifecycle a budúci Room import) musia byť potvrdené auditom a prípadne ďalšou konverzáciou s Michalom.
