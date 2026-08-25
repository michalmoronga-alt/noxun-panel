# 06 · Render M-R — appearance vrstva materiálov

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

Roadmapa M-R má zmeniť dnešný výrobný materiálový systém na použiteľný vizualizačný workflow pre Luciu. Po produktovej diskusii a externom audite SketchUp 2026 sa smer výrazne zjednodušil: **NOXUN nemá vytvárať vlastný PBR/textúrový editor, ak rovnakú prácu už kvalitne robí natívny SketchUp Materials editor.**

Cieľ zostáva:

- textúra v prirodzenej fyzickej mierke bez deformácie podľa rozmeru dielca,
- orientácia textúry podľa výrobného smeru dekoru dielca,
- uloženie vizuálneho vzhľadu materiálu vrátane PBR vlastností,
- jednoduché zdieľanie vzhľadov medzi pracoviskami,
- upratanie starého UI pridávania/editovania materiálov v Studio štýle.

Existujúca **kontrola kresby** je iná doména: vizuálne kontroluje smer dekoru výrobných dielcov. M-R rieši skutočný vzhľad materiálu v SketchUpe/render workflow.

---

# Schválený smer po diskusii

## 1 · Výrobná identita a vzhľad zostávajú oddelené

Výrobný materiál zostáva autoritou pre:

- typ materiálu,
- hrúbku,
- dekor,
- cenu,
- dodávateľa,
- ABS a ďalšie výrobné údaje.

Vzhľad je samostatná väzba:

```text
ProductionMaterial
  appearance_id? ───────┐
                        ↓
Appearance / SKM asset
```

Viac výrobných variantov môže používať rovnaký vzhľad, napríklad:

```text
K009 · 18 DTDL
K009 · 36 DTDL
K009 · pracovná doska
          ↓
     appearance: K009
```

NOXUN UI ich môže používateľovi prezentovať spolu v jednom editore materiálu, ale interná autorita výroby a appearance sa nesmie zlúčiť do jedného neprehľadného objektu.

---

## 2 · SketchUp 2026 natívny Materials editor je authoring UI

SketchUp 2026 už natívne podporuje:

- base texture,
- fyzickú veľkosť textúry / reálny scale,
- opacity/colorize,
- PBR metallic-roughness workflow,
- roughness,
- metalness,
- normal map,
- ambient occlusion,
- PBR bitmapy,
- AI `Generate Textures` ako pomocný authoring workflow.

Preto sa **nemá vytvárať vlastný NOXUN PBR editor** so slider-mi pre roughness, metalness, normal atď., pokiaľ audit neukáže konkrétnu medzeru natívneho editora.

Preferovaný UX:

```text
Studio → Materiál → Vzhľad

[ Upraviť v SketchUpe ]
[ Uložiť vzhľad do NOXUN ]
```

`Upraviť v SketchUpe` má aktivovať/pripraviť príslušný SketchUp material a otvoriť natívny Materials panel.

`Uložiť vzhľad do NOXUN` má explicitne uložiť hotový vzhľad do firemnej appearance knižnice.

Prvá verzia má preferovať **explicitné uloženie**, nie automatické save-on-every-slider-change. `MaterialsObserver` sa pred implementáciou musí auditovať; nesmie sa bez testu predpokladať, že spoľahlivo zachytí každú zmenu PBR/scale vlastnosti.

---

## 3 · `.skm` ako vizuálny balík

Po audite SketchUp 2026 je preferovaný smer, aby `.skm` niesol samotnú vizuálnu definíciu materiálu:

- base texture,
- fyzický scale,
- PBR nastavenia/mapy,
- opacity a ďalšie natívne appearance vlastnosti.

NOXUN nemá bez potreby duplikovať celý SketchUp material/PBR model do vlastného JSON-u.

Pracovný koncept:

```text
NOXUN appearance metadata
  appearance_id
  SKM asset reference
  revision
  grain/reference axis
  source/provenance podľa potreby
          ↓
      appearance.skm
```

`.skm` je kandidát na **autoritatívny vizuálny balík**, zatiaľ čo NOXUN metadata riešia jeho identitu, väzbu na výrobné materiály, verziu a shared-library lifecycle.

Pred implementáciou treba overiť, ktoré PBR vlastnosti a assety sa pri `Material#save_as` / `Materials#load` v podporovanom SketchUp 2026 workflowe skutočne zachovajú. Toto je auditná podmienka, nie predpoklad.

---

# Mierka textúry

Toto je pevná produktová požiadavka:

> Textúra sa nesmie naťahovať/deformovať podľa veľkosti dielca. Musí zachovať svoju prirodzene nastavenú fyzickú mierku.

SketchUp materiál rozlišuje pixelové rozmery obrázka od fyzickej veľkosti textúry v modeli. Preto sa má reálny scale nastavovať v natívnom editori a uložiť spolu s appearance.

Príklad:

```text
K009.jpg = 2048 × 2048 px
physical size = napr. 1200 × 1200 mm
```

300 mm široký dielec potom zobrazí iba časť rapportu; 1200 mm široký približne celý rapport. Obrázok sa nesmie automaticky stretchovať na každý dielec.

### Dôležitý invariant

Pixelový rozmer JPG/PNG **neurčuje fyzickú mierku**. Ak reálny scale nie je známy, systém ho nemá potichu odhadnúť z pixelov.

Používateľ má k dispozícii veľkú existujúcu JPG/PNG knižnicu takmer ku každému používanému materiálu. Táto knižnica je vhodný základ appearance vrstvy.

---

# Orientácia / grain / UV

Toto zostáva hlavnou technickou úlohou NOXUN M-R.

SketchUp material vie, **ako materiál vyzerá**. NOXUN vie, **ako má byť orientovaný na konkrétnom výrobnom dielci**.

Existujúci výrobný `grain_direction` zostáva autoritou. Render vrstva ho iba číta.

Koncept:

```text
SKM / texture scale + PBR
          ↓
appearance reference axis
          ↓
NOXUN effective grain_direction
          ↓
face-level UV/orientation
```

NOXUN nesmie zaviesť druhú nezávislú logiku smeru dekoru.

Pred implementáciou treba auditovať najmä:

- lokálne osi dielca vs. world/model transformácie,
- otočené skrinky/komponenty,
- horizontálne vs. vertikálne dielce,
- ľavý/pravý bok,
- rebuild a zachovanie UV,
- per-part grain override,
- ktoré konkrétne faces dostávajú appearance,
- `Face#position_material`, `UVHelper` a súvisiace SketchUp 2026 API.

### Invarianty

- zmena rozmeru dielca nesmie deformovať scale textúry,
- otočenie skrinky v modeli nesmie zmeniť výrobný význam grain direction,
- zmena vizuálneho UV nesmie meniť výrobné rozmery, BOM ani VEPO,
- rovnaký appearance sa nemá duplikovať na `VERTICAL/HORIZONTAL` materiály iba kvôli smeru; orientácia má byť face/part-level.

---

# PBR model

Keďže cieľové prostredie je SketchUp 2026, NOXUN nemusí zavádzať renderer-specific termíny typu vlastný `reflection` model.

Ak bude niekedy potrebné appearance metadata rozšíriť nad `.skm`, preferovaný neutrál je **PBR Metallic-Roughness**:

- base color,
- roughness,
- metalness,
- normal,
- ambient occlusion,
- prípadne neskôr height/displacement iba ak ho reálny export/render pipeline potrebuje.

Pre nábytkové materiály bude väčšina povrchového charakteru typicky vyjadrená roughness + normal, nie vlastným renderer-specific `reflection` sliderom.

`Generate Textures` v SketchUp 2026 môže byť užitočný bootstrap pre existujúce JPG/PNG, ale jeho výsledok je iba návrh na vizuálne authoring nastavenie, nie výrobná alebo materiálová pravda.

---

# Shared appearance library

M-R je previazané s [05_SHARED_LIBRARY_UPDATE.md](05_SHARED_LIBRARY_UPDATE.md).

Preferovaný model:

```text
Shared NOXUN library
  appearances/
    ... .skm
    metadata/revision
          ↓
local cache
          ↓
SketchUp model
```

Appearance nesmie používať absolútnu cestu viazanú na jeden PC.

Treba zachovať princíp:

- shared library = distribúcia/firemná knižnica,
- local cache = runtime dostupnosť/offline,
- `.skp` projekt = reprodukovateľný projektový stav podľa budúceho snapshot kontraktu.

Pred implementáciou sa musí rozhodnúť, či projekt snapshotuje celý použitý appearance/SKM, alebo stabilnú referenciu s embedded/fallback SketchUp materialom. Projekt sa nesmie vizuálne rozbiť iba preto, že shared knižnica nie je dostupná.

---

# Preview

SketchUp Ruby API umožňuje pracovať s thumbnailom materiálu. To je kandidát na lacné preview dlaždice v Studio bez vlastného render preview systému.

Pred implementáciou overiť `Material#write_thumbnail` a správanie PBR thumbnailov v SketchUp 2026.

---

# UI rework materiálov

Pri M-R sa má zároveň upratať existujúce staré UI pridávania/editovania materiálov, ktoré UI rework zatiaľ iba preniesol bez zásadného redesignu.

Preferované UX je jeden Studio editor s logickými blokmi:

```text
VÝROBA
- typ
- hrúbka
- dekor
- cena
- dodávateľ
- ...

VZHĽAD
- preview
- stav appearance
- [ Upraviť v SketchUpe ]
- [ Uložiť vzhľad do NOXUN ]
```

Interná architektúra môže držať ProductionMaterial a Appearance oddelene, ale používateľ nemusí prepínať medzi dvoma samostatnými „aplikáciami“.

PBR editácia samotná zostáva v natívnom SketchUp Materials paneli.

---

# Nástroj „pixla“

Pred implementáciou treba presne rozhodnúť význam kliku.

### Preferovaný bežný režim

Klik na materiál → klik na dielec → zmena **skutočného výrobného materiálu** existujúcou autoritatívnou cestou. Appearance sa zmení ako dôsledok novej production identity.

Visual-only override je potenciálne nebezpečný, pretože model by mohol vyzerať ako iný dekor než BOM/VEPO. Preto sa nesmie pridať bez jasného samostatného UX a dôvodu.

---

# Produktové delenie M-R

Toto nie je implementačné poradie, iba rozdelenie scope:

### M-R1 · Appearance link + natívny SketchUp authoring
- väzba ProductionMaterial ↔ Appearance,
- SKM save/load,
- base JPG/PNG,
- reálny scale,
- preview.

### M-R2 · Deterministická orientácia
- grain_direction → UV/orientation,
- rebuild/transform invariants.

### M-R3 · Materials UI cleanup
- Studio editor výroba + vzhľad,
- odstránenie starého UI dlhu.

### M-R4 · PBR workflow
- využitie natívnych SketchUp 2026 PBR vlastností,
- voliteľné normal/AO/roughness mapy,
- Generate Textures ako pomocník.

### M-R5 · Shared appearance library
- revision/cache/sync podľa D-48.

### M-R6 · Renderer/export integrácie
- až podľa reálneho render pipeline; appearance model sa nemá predčasne viazať na V-Ray/Enscape/iný renderer.

---

# Odhad náročnosti

Po rozhodnutí použiť natívny SketchUp 2026 Materials editor sa scope výrazne zmenšil.

- base JPG/PNG + SKM save/load: **nízka až stredná**,
- real-world scale: **nízka**, ak ho spoľahlivo prenesie SKM,
- PBR authoring: **nízka**, pretože ho robí SketchUp,
- nový Materials UI shell: **stredná**,
- shared appearance library: **stredná**, využíva D-48,
- deterministická orientácia/UV podľa výrobnej semantiky: **stredná až vyššia** a hlavná technická neznáma.

Celá M-R vrstva je preto skôr **stredne veľký balík**, nie samostatný render engine. Najväčšia hodnota za najmenej práce je base texture + správny scale + správna orientácia; detailné PBR mapy môžu pribúdať postupne.

---

# Externé zistenia použité pri koncepte

Pri diskusii boli overené oficiálne SketchUp zdroje pre verziu 2026 / aktuálnu Ruby API:

- natívny Materials editor a PBR editing,
- `Sketchup::Material` / `Sketchup::Texture`,
- fyzická texture width/height,
- `.skm` save/load,
- `Materials#current=`,
- otvorenie Materials inspectoru,
- face-level UV/`Face#position_material` / `UVHelper`,
- `Material#write_thumbnail`,
- `MaterialsObserver`,
- `Generate Textures`.

Externé PBR knižnice potvrdzujú bežný princíp ukladať pri textúre aj **real-world physical scale**. Tento pattern je vhodný aj pre NOXUN.

Pred task package treba všetky kritické API body znovu overiť proti aktuálnemu SketchUp 2026 Ruby API a urobiť malý proof-of-concept najmä pre SKM PBR round-trip a deterministické UV.

---

## Otvorené auditné otázky pred implementáciou

1. Zachová `Material#save_as` → `Materials#load` v SketchUp 2026 všetky potrebné PBR vlastnosti a mapy bez straty?
2. Aký minimálny metadata wrapper potrebuje NOXUN okolo `.skm` — `appearance_id`, revision, grain/reference axis, source?
3. Ako presne mapovať effective `grain_direction` na UV pri všetkých typoch dielcov a transformáciách?
4. Má projekt embedovať/snapshotovať použitý SKM, alebo stačí stabilná referencia + embedded SketchUp material fallback?
5. Aké sú dnešné write/read cesty materiálov a ktoré staré UI/store vrstvy treba pri reworku odstrániť alebo zjednotiť?
6. Je `MaterialsObserver` dostatočný iba na dirty indikáciu, alebo zostane prvá verzia striktne explicit-save?
7. Ako sa appearance revízia prejaví v už otvorenom projekte — automaticky, na vyžiadanie, alebo iba pri novom priradení?

## Pred implementáciou

Auditovať aktuálny materiálový katalóg/decor skupiny, grain snapshot, SketchUp material assignment, part overrides, templates/previews, shared library návrh a existujúce UI pridávania/editovania materiálov. Urobiť read-only code audit a malý SketchUp 2026 technický proof-of-concept pre SKM/PBR/scale/UV. Až potom vytvoriť samostatný task package.
