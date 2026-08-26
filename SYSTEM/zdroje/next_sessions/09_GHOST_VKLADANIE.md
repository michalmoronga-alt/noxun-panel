# 09 · Ghost vkladanie skriniek / V1-04

> Stav: KONCEPT — neimplementovať priamo · zdroj: PR #210 (23.8.2026) · auditované proti kódu: zatiaľ nie
>
> **Predimplementačný koncept + predbežný audit — nie task package.**
>
> Pravdepodobný kandidát na **prvú funkčnú dávku po uzavretí UI 2.0 a následnom hardeningu**, ak finálny audit nepotvrdí blokujúci problém. Pred implementáciou stále platí povinný postup z [README.md](README.md).

## Kontext a pôvod

Téma vznikla z reálneho dogfoodingu: dnešné vloženie novej skrinky ju položí podľa automatického `Placement.next_x`, takže vo veľkom modeli alebo pri importe miestnosti sa môže objaviť mimo aktuálneho pohľadu a používateľ ju musí hľadať a ručne presúvať.

Pôvodná debata uvažovala o dvoch režimoch:

1. **ghost** — skrinka visí na kurzore a klik ju umiestni,
2. **vložiť k vybranej skrinke** — vľavo/vpravo k existujúcemu korpusu.

Po diskusii sa rozsah zámerne zúžil:

- **teraz sa rieši iba ghost vkladanie,**
- „vložiť vedľa“, snap, persistentné attachmenty a väzby na susednú skrinku sa **odkladajú k zostavám/segmentom**.

Tým sa odstránil hlavný konflikt so súčasným Inspectorom: ghost sa spúšťa z existujúceho režimu vkladania bez potreby držať označenú skrinku ako kotvu.

---

## Schválený produktový kontrakt

### Základný workflow

```text
Inspector — vkladací draft
        ↓
      Vložiť
        ↓
Ghost Placement Tool
        ↓
  pohyb / rotácia / anchor
        ↓
       klik
        ↓
CabinetBuilder vytvorí reálnu CAB
        ↓
tool končí
        ↓
nová CAB sa označí
        ↓
Inspector pokračuje editáciou novej skrinky
```

Po jednom vložení sa režim **ukončí**. Repeat-placement zatiaľ nie.

### Ghost

Ghost je zámerne jednoduchý:

- priehľadný kváder / obrys korpusu,
- presné rozmery z aktuálneho insert draftu,
- jasne čitateľná predná strana,
- viditeľný aktívny anchor,
- žiadne reálne NOXUN entity pred potvrdením.

Ghost **nie je dočasná skrinka v modeli**. Pred kliknutím nesmie dostať ID, zapisovať snapshot, vstupovať do BOM, aktivovať ScaleWatch/dedup ani vytvárať Undo krok.

### Rotácia

- `←` = rotácia o **−90°**,
- `→` = rotácia o **+90°**,
- cyklus 0° / 90° / 180° / 270° okolo lokálnej Z osi.

Aktívny **semantický anchor ostáva tým istým anchorom aj po rotácii** — ghost sa má otáčať okolo neho, nie „odskočiť“ na iný roh.

### Výškový režim

- `↓` = **floor lock** — spodná základňa vloženej skrinky je na globálnom `Z=0`,
- `↑` = **free Z** — výška sa odomkne a ghost sleduje plný SketchUp inference point vrátane Z.

V `floor` režime kurzor/inference určuje horizontálnu polohu, ale Z prepisuje pravidlo podlahy. Vo `free` režime sa zvolený anchor mapuje na plný 3D inference point.

**Otvorené pred implementáciou:** počiatočný Z režim pri aktivácii toolu — najmä rozdiel medzi dolným a horným korpusom. Dnešné hardcoded `UPPER_HANG_Z = 1400` sa v interaktívnej ghost ceste nemá potichu zachovať bez vedomého rozhodnutia.

### Štyri anchory na prednej rovine korpusu

Používateľ chce štyri pracovné body, všetky na **prednej rovine korpusu — nie čiel**:

- ľavý spodný,
- pravý spodný,
- ľavý horný,
- pravý horný.

`TAB` prepína aktívny anchor medzi všetkými štyrmi. Presné poradie cyklu môže byť ergonomicky zvolené pri implementácii; kandidát je kruh `ľavý spodný → pravý spodný → pravý horný → ľavý horný → ...`.

Dôležitý invariant:

> **Anchor patrí korpusu, nie čelu.** Presahy, hrúbka alebo budúci produktový typ čela nesmú meniť placement referenciu.

### Potvrdenie a zrušenie

- ľavý klik = vytvorenie jednej reálnej skrinky,
- `Esc` = zrušenie placementu bez zápisu do modelu,
- po úspešnom kliku sa nová skrinka označí a Inspector prejde na jej bežnú editáciu,
- vloženie musí byť **jeden zrozumiteľný Undo krok**.

---

## Vedome mimo rozsahu tejto dávky

- vložiť vľavo/vpravo k označenej skrinke,
- snap k NOXUN korpusom,
- persistentné attachment väzby,
- segment/zostava,
- automatická orientácia podľa steny alebo normály plochy,
- repeat-placement viacerých skriniek,
- ďalšie anchor body (zadné rohy, stred),
- vlastný constraint/layout solver.

„Vložiť vedľa“ sa má vrátiť až pri návrhu segmentov, aby nevznikla dočasná ad-hoc logika susednosti, ktorú by bolo treba neskôr zahodiť.

---

# Predbežný audit proti aktuálnemu kódu

Audit prebehol 23. 8. 2026 proti `main` **v0.7.51**. Je zámerne užší než implementačný audit: overuje, či koncept sedí na dnešnú architektúru a kde sú pravdepodobné zásahy/riziká.

## 1 · Dnešný placement je presne zdroj problému

`core/placement.rb` má dnes jedinú politiku: prejde top-level NOXUN owner objekty (`cabinet`, `board`), nájde najpravejší `bounds.max.x` a vráti jeho X + medzeru; prázdny model končí na `0.0`.

To je vhodný **fallback/programmatic placement**, ale nie používateľský placement v reálnom priestore.

**Predbežný záver:** `Placement.next_x` nemusí v prvej dávke zaniknúť. Interaktívny ghost môže používať explicitný transform a staré interné/testovacie cesty môžu zatiaľ zostať na `next_x`.

## 2 · CabinetBuilder dnes explicitný transform pri vložení neprijíma

`CabinetBuilder.build(model, params)` dnes vždy:

1. normalizuje config,
2. vytvorí nové CAB ID,
3. vypočíta `x = next_x(model)`,
4. nastaví Z podľa typu (`lower = 0`, `upper = UPPER_HANG_Z`),
5. vytvorí inštanciu s touto translation transformáciou.

**Predbežný návrh hranice:** builder potrebuje kompatibilnú cestu typu `build(..., transform: ...)` alebo ekvivalentný explicitný placement vstup. Ak explicitný transform chýba, môže zostať dnešný fallback.

Dôležité: nevkladať najprv na `next_x` a potom skrinku druhou operáciou presúvať. Ghost commit má vytvoriť entitu **rovno na finálnom transforme v tej istej operácii**.

## 3 · Panel dnes spája „Vložiť“ a build do jedného okamžitého callbacku

`Panel.handle_insert` dnes robí celý tok naraz:

- parse insert payloadu,
- metadata šablóny,
- kontrola/normalizácia kovania,
- thickness/material preflight,
- `CabinetBuilder.build`,
- select nového korpusu,
- status + `push_selected`,
- až po úspechu pečiatka použitia šablóny.

Ghost potrebuje tento tok **logicky rozdeliť**:

```text
PREPARE
- načítať a validovať draft
- vykonať čisté preflighty
- pripraviť snapshot dát pre placement session
- ZIADNY zápis do modelu

PLACEMENT
- InputPoint + ghost + klávesy
- ZIADNY zápis do modelu

COMMIT
- CabinetBuilder.build na explicitnom transforme
- zmrazenie hardware setov v tej istej operácii
- select novej CAB
- status/push
- template usage stamp až po úspechu
```

**Poistka:** súčasné preflighty sa nemajú duplikovať do Tool triedy. Tool má riešiť polohu, nie výrobné pravidlá.

## 4 · Insert draft už má správnu samostatnú stavovú vrstvu

`ui/js/insert_state.js` už drží `NXInsert` ako vlastný zdroj pravdy pre typ, šablónu, zámky, materiály a hardware. DOM nie je autorita a karta sa materializuje z tohto stavu.

To je pre Ghost veľká výhoda: netreba vytvárať druhý draft systém.

**Predbežný záver:**

- `NXInsert` = **čo sa vkladá**,
- nový placement/tool state = **kam a ako sa to vloží**,
- `CabinetBuilder` = **vytvor reálnu entitu**.

Tieto tri zodpovednosti sa nemajú miešať.

## 5 · Konflikt Inspector „vybrané = editácia“ po zúžení rozsahu odpadá

Súčasný Inspector odvodzuje režim z výberu: bez výberu ukazuje insert, s označeným korpusom editáciu. To by bol problém pre „vložiť vedľa vybranej skrinky“.

Keďže táto vetva je teraz odložená, **Ghost V1-04 nepotrebuje meniť selection state machine Inspectora**.

Po úspešnom commit-e sa naopak dá využiť dnešný vzor: označiť novú CAB a `push_selected` ju otvorí v Inspectore.

## 6 · Selection/observer cesta je citlivá — treba ju rešpektovať

Panel má existujúci `suspend_selection_sync`, `reselect/select_only` a explicitné refresh cesty. V minulosti už programmatické `clear/add` selection vedeli rozbiť Inspector a okolo ScaleWatch/selection eventov vzniklo viac hardening opráv.

**Predbežný záver:** po ghost commite nepísať nový „ručný“ selection mechanizmus. Znovu použiť existujúcu serverovú cestu a pri implementačnom audite overiť, či commit + následný scale-lock follow-up stále vytvára presne jeden používateľský Undo krok a jeden konzistentný refresh panela.

## 7 · Floor height a štyri anchory treba odvodiť z reálnej geometrie, nie z naivného boxu

`Construction` používa `floor_height` ako reálnu konštrukčnú výšku: napríklad dno dolného korpusu leží na `Z = floor_height`; boky môžu podľa `bottom_mode` začínať ešte vyššie. Zároveň `height` reprezentuje hornú hranicu celej konfigurácie.

Preto treba pred implementáciou presne uzavrieť lokálne súradnice štyroch anchorov na „prednej rovine korpusu“.

Pracovný kandidát pre vonkajšiu rovinu tela je približne:

```text
front-left-bottom  = [0,     0, floor_height]
front-right-bottom = [width, 0, floor_height]
front-left-top     = [0,     0, height]
front-right-top    = [width, 0, height]
```

ale **toto zatiaľ nie je záväzný kontrakt** — treba ho porovnať s BuildPlanom pre `under_sides`, `between_sides`, horný korpus a atypické konštrukčné varianty.

Floor lock je samostatná vec: v režime `↓` má byť **základňa skrinky / lokálny placement origin** na globálnom `Z=0`; anchor na korpuse môže byť preto pri dolnom korpuse vizuálne nad podlahou o `floor_height`. V režime `↑` sa na InputPoint mapuje priamo vybraný anchor vrátane jeho Z offsetu.

Toto je najdôležitejší geometrický bod, ktorý treba uzavrieť pred kódom.

## 8 · Nový SketchUp Tool pravdepodobne bude nová infra vrstva

V auditovaných cestách nie je hotová všeobecná placement-tool vrstva; dnešné vkladanie ide HtmlDialog callback → Builder. Ghost preto pravdepodobne potrebuje novú SketchUp `Tool` implementáciu používajúcu napríklad `Sketchup::InputPoint`, `onMouseMove`, `onKeyDown`, `draw(view)` a commit na klik.

To je **predbežný záver**, nie dôkaz úplného scanu repa. Implementačný audit musí pred vytvorením novej triedy preveriť celý strom a znovupoužiteľné tool/helper kódy.

---

# Pracovný stav PlacementSession

Koncepčne stačí veľmi malý runtime stav:

```text
PlacementSession
- model / model_guid
- prepared insert snapshot
- rotation: 0 | 90 | 180 | 270
- anchor: front_left_bottom | front_right_bottom |
          front_left_top    | front_right_top
- z_mode: floor | free
- current InputPoint
- template usage reference
- prepared hardware snapshot
```

Nie je to nový projektový dátový model. Session zaniká klikom, Escape alebo zrušením toolu.

## Kritický multi-model guard

Session musí byť viazaná na model/dokument, v ktorom vznikla. Ak sa počas placementu prepne dokument alebo sa pôvodný model stane neplatným, tool **nesmie vložiť CAB do nového aktívneho modelu**.

Toto je obzvlášť dôležité, pretože NOXUN ID sa medzi dokumentmi opakujú a súčasný Inspector už preto používa `model_guid` identity guardy.

---

# Povinné body finálneho auditu pred implementáciou

1. **Presný lokálny envelope a anchor súradnice** pre lower/upper a všetky podporované bottom/top varianty.
2. **Počiatočný Z režim** pri spustení (`lower` vs `upper`).
3. Builder API: explicitný transform bez rozbitia existujúcich call-siteov a testov.
4. Rozdelenie `handle_insert` na prepare/commit bez duplikácie D-45/D-76 preflight logiky.
5. Hardware freeze ostáva až v reálnom commit-e a v tom istom Undo kroku.
6. Template usage sa pečiatkuje až po úspešnom kliku; Escape nesmie meniť usage.
7. Tool lifecycle: Escape, prepnúť SketchUp tool, zatvoriť Inspector, New/Open/Activate model.
8. `InputPoint` inference + viewport redraw bez zápisu do modelu.
9. Selection/ScaleWatch/StudioModelWatch reakcie po úspešnom commite — bez extra Undo kroku alebo falošného medzistavu.
10. Kompatibilita s aktuálnou podporovanou verziou SketchUpu a klávesovými kódmi šípok/TAB/Escape na Windows.

---

# Kandidátska testovacia matica

Minimálne scenáre, ktoré by mal budúci task package požadovať:

### Čistý Tool / transform math

- 4 rotácie × 4 anchory,
- anchor zostane na inference bode po rotácii,
- TAB cykluje všetky 4 anchory,
- floor/free Z prechod nemení X/Y neočakávane,
- Escape v každom stave session zanechá nulový modelový zápis.

### In-SketchUp

- pred klikom nevznikne žiadna NOXUN entita,
- klik vytvorí presne jednu CAB na očakávanom mieste,
- jeden `Ctrl+Z` vloženie celé vráti,
- nová CAB je po commite označená a Inspector ju zobrazí,
- lower + upper,
- template s materiálmi/kovaním,
- zámky vkladacej karty,
- template usage iba po úspešnom commite,
- floor mode na Z=0,
- free mode na bode s nenulovým Z,
- prepnutie dokumentu počas toolu = bezpečný cancel/no-op, nikdy cross-document insert.

### Regresie

- staré programmatické `CabinetBuilder.build` call-sitey stále fungujú cez fallback placement,
- `insert_copy` sa nezmení bez samostatného rozhodnutia,
- board placement sa touto dávkou nemení,
- ScaleWatch/dedup nevytvorí druhú CAB ani extra Undo krok.

---

# Predbežné hodnotenie

**Produktová hodnota: vysoká.** Funkcia odstraňuje opakovanú manuálnu činnosť pri každom vložení skrinky.

**Architektonické riziko: stredné, ale dobre ohraničené.** Najväčšie riziko nie je kreslenie ghostu, ale lifecycle SketchUp Toolu, explicitný transform Buildera a observer/Undo interakcie.

**Scope je zdravý:** žiadne segmenty, susednosti ani dependency graph. Pri dobre urobenom audite je Ghost V1-04 vhodný kandidát na skorú samostatnú dávku po hardeningu.

---

## ⚠ Pred implementáciou

Tento dokument zachytáva **schválenú používateľskú predstavu a predbežný audit**, nie hotové implementačné zadanie.

Pri vzniku dokumentu mal model GPT-5.6 Sol k dispozícii aktuálny konverzačný kontext, `STAV/PLAN/V1_VIZIA`, súčasný `Placement`, `CabinetBuilder`, insert handler, `NXInsert`, Inspector mode/selection vrstvy a časť `Construction`. Nebol vykonaný úplný call-graph audit všetkých SketchUp Tool/helper/test ciest.

Pred prvým commitom musí vzniknúť samostatný read-only audit aktuálneho `main` po hardeningu a až z neho konkrétny task package.