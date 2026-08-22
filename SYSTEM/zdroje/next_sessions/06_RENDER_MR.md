# 06 · Render M-R — appearance vrstva materiálov

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

Roadmapa M-R má zmeniť dnešný výrobný materiálový systém na použiteľný vizualizačný workflow pre Luciu. V otvorených bodoch sú:

- textúry materiálov,
- render/PBR vlastnosti,
- mierka rapportu,
- „Uložiť vzhľad do knižnice“,
- orientácia textúry podľa smeru dekoru,
- nástroj „pixla“ na rýchle prefarbovanie.

Existujúca **kontrola kresby** je iná doména: vizuálne kontroluje smer dekoru výrobných dielcov. M-R rieši skutočný vzhľad materiálu v SketchUpe/render workflow.

## Hlavná návrhová otázka

Treba oddeliť **výrobnú identitu materiálu** od **appearance/render identity**.

Príklad: viac výrobných variantov môže používať rovnaký dekor/vzhľad:

```text
K009 · 18 DTDL
K009 · 36 DTDL
K009 · pracovná doska
          ↓
     appearance: K009 dub ...
```

Nie je však automaticky pravda, že všetky varianty majú identické render vlastnosti. Preto treba vyspecifikovať, čo patrí:

- dekoru,
- materiálovému variantu,
- samostatnému appearance záznamu.

## Kandidát modelu

Na diskusiu, nie schválená schéma:

```text
ProductionMaterial
  appearance_id? ───────┐
                        ↓
Appearance
  texture asset
  real-world scale / rapport
  rotation/orientation policy
  roughness
  normal/bump?
  metallic/specular podľa potreby
  preview
```

Výhoda: výrobný katalóg nemusí niesť renderer-specific detaily a jeden vzhľad sa dá bezpečne zdieľať medzi variantmi.

## Textúrové assety

Treba rozhodnúť:

- kde fyzicky žijú obrázky,
- ako sa referencujú bez absolútnych ciest konkrétneho PC,
- lokálna cache vs. firemný Drive,
- ako sa identifikuje aktualizovaná verzia textúry,
- ako sa ukladajú náhľady,
- či má byť asset content-addressed/hashovaný.

Téma je preto previazaná s [05_SHARED_LIBRARY_UPDATE.md](05_SHARED_LIBRARY_UPDATE.md).

## Mierka a orientácia

Appearance má potrebovať reálnu mierku dekoru/rapportu, aby sa textúra nenaťahovala podľa rozmeru dielca.

Fáza orientácie podľa kresby musí rešpektovať existujúcu výrobnú autoritu:

- efektívny `grain_direction` už existuje v snapshot-e dielca,
- render vrstva má tento údaj **čítať**, nie vytvoriť druhú logiku smeru,
- zmena vizuálnej UV/orientácie nesmie meniť výrobné rozmery ani VEPO orientáciu.

## Nástroj „pixla“

Pred implementáciou treba presne rozhodnúť význam kliku:

### Možnosť A — zmena výrobného materiálu

Klik na dlaždicu materiálu → klik na dielec → cez existujúcu `part_override` cestu sa zmení production material. Render vzhľad sa zmení ako dôsledok.

### Možnosť B — iba appearance override

Klik mení iba vzhľad bez zmeny výrobnej identity.

Pre NOXUN výrobný workflow je možnosť B potenciálne nebezpečná: model by mohol vyzerať ako iný dekor, ale BOM by stále obsahoval pôvodný materiál. Preto sa nesmie implementovať bez veľmi jasného UX/kontraktu. Predbežná preferencia je, aby „pixla“ pri bežnom použití menila **skutočný výrobný materiál** jednou autoritatívnou cestou.

## SketchUp materiály vs. NOXUN katalóg

Treba auditovať, ako mapovať appearance na `Sketchup::Material`:

- jeden SketchUp material per appearance?
- ako pomenovať a deduplikovať,
- ako sa správa otvorenie `.skp` na druhom PC bez lokálneho assetu,
- čo sa stane pri zmene knižničného vzhľadu,
- má projekt snapshotovať appearance alebo vždy používať živú firemnú knižnicu?

Reprodukovateľnosť projektu hovorí v prospech snapshotu alebo aspoň stabilnej referencie s fallbackom.

## Rozsah PBR

PBR vlastnosti treba prispôsobiť reálnemu render pipeline. Ak SketchUp viewport alebo používaný renderer nevie danú vlastnosť využiť, nemá zmysel navrhovať abstraktný materiálový systém „pre všetko“.

Najprv potvrdiť cieľové použitie:

- natívny SketchUp viewport,
- export do renderera,
- budúci MCP/render prompt pipeline,
- prípadne viac rendererov.

## Otvorené otázky

1. Appearance per dekor, per variant alebo samostatná zdieľaná entita?
2. Čo musí byť snapshotované do `.skp`, aby model vyzeral konzistentne aj bez firemnej knižnice?
3. Ako sa rieši orientácia a UV pri otočených/transformovaných komponentoch?
4. Čo presne znamená rapport pre drevodekor, kameň, uni farby?
5. Aký minimálny PBR model má dnes reálnu hodnotu?
6. Má „pixla“ vždy meniť production material, alebo existuje legitímny visual-only režim?
7. Ako sa appearance library synchronizuje medzi PC?
8. Ako sa budú ukladať/importovať Demos obrázky a vlastné textúry?

## Pred implementáciou

Auditovať materiálový katalóg/decor skupiny, grain snapshot, SketchUp material assignment, part overrides, templates/previews, export/render workflow a shared library návrh. Najprv potvrdiť dátovú hranicu `ProductionMaterial ↔ Appearance`, až potom riešiť UI.
