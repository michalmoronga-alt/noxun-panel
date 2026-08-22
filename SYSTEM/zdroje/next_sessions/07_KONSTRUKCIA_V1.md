# 07 · Konštrukcia V1 — odsadenia a produktové typy čiel

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

V1 vízia obsahuje dva väčšie konštrukčné smery:

- **V1-01** — per-dielec odsadenia vpredu/vzadu pre strop/dno/boky a špeciálne situácie typu chladničkový/vzduchový komín,
- **V1-07** — nové produktové typy čiel: lakované, frézované, sklo/Al rám a všeobecnejšie „čelo ako produkt s dodávateľom“.

Zásobník V0.4.8 navyše obsahuje rohové spoje dna/stropu per strana, chrbát s poldrážkou, „bez dielca“ varianty, per-dielec hrúbky a ďalšie odsadenia.

Tieto veci sa nemajú zlúčiť do jedného obrovského „advanced construction“ formulára bez dátového návrhu.

## V1-01 — per-dielec konštrukčné odsadenia

### Produktový problém

Dnešný korpus pokrýva bežnú konštrukciu. Reálna výroba však potrebuje výnimky, napríklad:

- bok ustúpený kvôli vzduchovému kanálu,
- vrch/dno s iným predným alebo zadným odsadením,
- chladničkový komín,
- atypická nika,
- krytie alebo kolízia s technológiou.

Cieľom je umožniť výnimku **na konkrétnom výrobnom dielci** bez rozbitia základného cabinet buildera.

### Otázka autority

Treba rozhodnúť, či je odsadenie:

- súčasť cabinet construction config,
- `part_override` konkrétneho `part_key`,
- alebo kombinácia defaultu v config + per-part override.

Pre šablónovanie je dôležité, aby opakovaný typ skrinky vedel niesť konštrukčné nastavenie. Zároveň musí zostať stabilná väzba cez `part_key`.

### Rozsah parametrov

Nepredpokladať automaticky šesť offsetov XYZ pre každý diel. Najprv z reálnych zákaziek určiť minimálny jazyk, napríklad:

- front setback,
- back setback,
- prípadne side/top/bottom podľa role,
- „bez dielca“ ako samostatná konštrukčná voľba, nie magický offset.

Čím všeobecnejší geometrický editor, tým vyššie riziko nevalidovateľných kombinácií.

## Konštrukčné warnings

Nové možnosti musia mať vlastné validačné pravidlá. Príklady:

- odsadenie vytvorí nulový/degenerovaný dielec,
- konflikt s drážkovým chrbtom,
- vnútorné zóny zasahujú do technického priestoru,
- diel prestane podopierať očakávané rozhranie.

Semafor má upozorniť, nie potichu upravovať vstup.

## V1-07 — typy čiel ako produkt

Lakované, frézované a Al/sklo čelá nie sú iba iný sheet material.

Môžu mať:

- cenu za m²/kus,
- dodávateľa,
- objednávkový kód/vzor,
- konštrukciu z viacerých zložiek,
- odlišné výrobné/objednávkové výstupy,
- vlastné hrúbky a hmotnostné vlastnosti,
- iné pravidlá ABS (často žiadne klasické ABS).

Preto treba rozhodnúť, či `front` zostáva výrobným dielcom sheet triedy alebo môže referovať **externý front product**.

Možný smer:

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

Toto je iba mentálny model, nie schéma.

## Výklop `flap`

Otvorená rola `flap` zo STANDARD/UI-C3 patrí konštrukčne k typu čela, ale jej plná funkcia sa pretína s kovaním fáza 3. Treba oddeliť:

- **rola/kinematický typ čela** (door/drawer_front/flap),
- **výrobný typ produktu čela** (sheet/lak/fréza/Al rám),
- **kovanie** (hinge/lift atď.).

Tieto osi sa nesmú zliať do jedného enumu.

## Otvorené otázky

1. Aký minimálny počet konštrukčných parametrov pokryje reálne atypy bez generického CAD editora?
2. Ktoré nastavenia patria cabinet configu a ktoré per-part override?
3. Ako sa konštrukčné override prenášajú do template?
4. Čo sa stane s override, ak konkrétny `part_key` po zmene konštrukcie zanikne?
5. Ako má interiér/zóny rešpektovať technické odsadenia?
6. Potrebuje V1-07 nový production class alebo nový „front product“ model?
7. Ako sa externé čelo dostane do BOM/rozpočtu/objednávky bez predstierania, že je bežná DTDL doska?
8. Ako kombinovať rolu `flap` s produktovým typom a kovaním bez krížového enum chaosu?

## Pred implementáciou

Auditovať cabinet config/builder, `part_overrides`, PartKeys lifecycle, zones/interior geometry, BuildPlan, edge rules, VEPO/BOM a front builder. V1-01 a V1-07 pravdepodobne rozdeliť do samostatných dávok po spoločnej koncepčnej session.
