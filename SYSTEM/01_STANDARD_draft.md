# Noxun Component Standard v1.0-draft (15.7.2026)

> Záväzný kontrakt dátového modelu a princípov nového SketchUp plugin systému pre nábytkárstvo na mieru (korpusy, čelá, kovanie, ABS, výstupy). Nadväzuje na `00_VIZIA.md`, uzamknuté rozhodnutia z `01_STANDARD_osnova.md`, analýzu `02_ANALYZA_korpus_dc_vs_ruby.md`, VEPO kontrakt `03_VYSTUP_vepo_kontrakt.md` a technické pasce v `docs/DC_PRAVIDLA.md`. Draft = pripravené na revíziu a prototypové overenie; po potvrdení sa premenuje na `01_STANDARD.md`.

---

## 0. Účel a záväznosť

**Prečo tento dokument existuje.** Každý doterajší plugin (KOVANIE, DC Control, OCL adaptéry, vepo_exporter) riešil kúsok toho istého problému znova, lebo neexistoval jeden spoločný kontrakt: čo je skrinka, čo je dielec, aké nesie dáta, v akých jednotkách, ako sa počítajú hrany a kovanie. Tento štandard je ten kontrakt. Všetky moduly nového systému (generátor korpusov, panel na pripájanie childov, kovania engine, ABS editor, výstupy) sa musia riadiť ním.

**Čo je záväzné.** Sekcie 1–11 sú kontrakt: dátový model, identita, jednotky, hierarchia, výrobné triedy. Kto ich poruší, rozbije interoperabilitu modulov. Sekcia 12 „Otvorené body" sú veci zámerne nechané na prototyp/V1 — tie sa NErozhodujú od stola, overia sa v SketchUpe cez SkAgent na reálnych dielcoch.

**Verzia štandardu na komponente.** Každá NOXUN entita nesie `NOXUN/std` = číslo verzie štandardu (v1 = `1`). Keď sa štandard posunie, migračný skript pozná podľa `std`, čo treba dopočítať alebo prepísať. Bez tohto poľa je entita „predštandardová" a systém ju označí na revíziu.

```json
{ "std": 1 }
```

---

## 1. Pojmy a hierarchia

Systém pracuje so **stromom priestorov a objektov**. Zhora nadol:

```
ZOSTAVA            kuchyňa / rad skriniek (voľné zoskupenie korpusov v projekte)
└─ KORPUS          skrinka; cabinet_id; nesie konfiguráciu; generuje sa Ruby
   ├─ DIELCE korpusu   boky, dno, vrch, chrbát (fyzické kusy)
   ├─ ROZHRANIA        čelná rovina, čelný otvor, podopretie (dáta, nie geometria)
   └─ ZÓNA (SLOT)      adresovateľný vnútorný priestor; ghost na tagu Noxun/Zóny
      ├─ MODUL / CHILD funkčný prvok v zóne:
      │                 čelo · polica · priečka · zásuvkový blok ·
      │                 vnútorné vybavenie (tyč, kôš, výsuv) · doplnok (LED, zásuvka 230V)
      │   ├─ DIELEC            fyzický kus materiálu = vždy samostatný komponent
      │   └─ VIRTUÁLNA POLOŽKA kovanie / spojovací materiál (bez vlastnej geometrie,
      │                        alebo 1 generický fyzický objekt na kategóriu)
      └─ priečka / polica ROZDELÍ zónu → vzniknú nové ZÓNY (rekurzívne)
```

Definície pojmov:

- **Zostava** — logické zoskupenie korpusov (kuchynský rad). Vo V1 len organizačná úroveň, bez vlastnej geometrie.
- **Korpus** — skrinka. Nositeľ konfigurácie. Nie monolitický „master so všetkými variantmi", ale **obálka + konštrukcia + zóny + rozhrania** (viď sekcia 4).
- **Zóna (slot)** — adresovateľné pole vnútra korpusu: celé vnútro, alebo časť medzi policami/priečkami. Má rozmery, pozíciu, stav (voľná/obsadená), zoznam povolených modulov. Vzniká a zaniká delením. **Vizualizácia:** polopriehľadný ghost box na tagu **`Noxun/Zóny`** — vypnutie tagu = neviditeľné; geometria zón nikdy nejde do kusovníka (viď sekcia 8, `manufactured: false`). (Historický tag `NOXUN_SLOTY` z prvých prototypov bol migrovaný — nové moduly ho nesmú vytvárať.)
- **Modul / child** — funkčný prvok vložený do zóny (čelo, polica, priečka, zásuvkový blok, vnútorné vybavenie, doplnok). Zo zóny dostane rozmery, pridá vlastné pravidlá (škáry, presahy, odsadenia).
- **Dielec** — fyzický kus materiálu na výrobu. Vždy samostatný SketchUp komponent s NOXUN metadátami. Zdroj kusovníka.
- **Virtuálna položka** — kovanie a spotrebný materiál, ktoré sa počítajú do súpisu, ale nemajú výrobnú geometriu. Fyzicky ich zastupuje najviac 1 generický objekt na kategóriu (viď sekcia 6).

---

## 2. Identita a atribúty

### 2.1 Jeden dictionary na entite

Každá NOXUN entita nesie **jediný** attribute dictionary s názvom `NOXUN`. Žiadna dnešná zmes (`NOXUN_CORE` + `NOXUN_KOVANIE` + DC `dynamic_attributes`). Kľúče sú buď ploché skalárne hodnoty (časté čítanie, filtre, marker), alebo zložité štruktúry uložené ako **JSON string** v jednom kľúči.

Základný layout (ploché kľúče, čítané často):

| Kľúč | Typ | Význam |
|---|---|---|
| `std` | Integer | verzia štandardu (v1 = 1) |
| `kind` | String | vrstva v hierarchii: `cabinet` / `zone` / `module` / `part` / `hardware` / `reference` |
| `id` | String | identita entity (napr. `CAB-014`, `CAB-014-SIDE-L`) |
| `cabinet_id` | String | na ktorý korpus entita patrí |
| `template_id` | String | typ/šablóna (napr. `base-lower-18`) |
| `role` | String | rola dielca/modulu (viď 2.4) |
| `manufactured` | Bool | ide do výroby? (explicitne, nie podľa typu entity) |
| `production_class` | String | `sheet` / `linear` / `counted` / `reference` / `none` (viď sekcia 8) |
| `config` | JSON string | celá konfigurácia entity (rozmery, konštrukcia, zóny, hrany, materiál…) |

Zložité veci (rozmery + konštrukcia korpusu, zoznam hrán dielca, delenie čiel) žijú v `config` ako JSON string. Dôvod: SketchUp dictionary je plochý kľúč→hodnota; JSON je jediný spoľahlivý spôsob, ako niesť vnorenú štruktúru bez desiatok kľúčov.

### 2.2 Autorita = inštancia

Dáta konkrétnej skrinky sú na **inštancii**. Definícia komponentu môže niesť len **template defaulty** (východiskové hodnoty šablóny). Poučenie z DC praxe: zdieľané definície dverí v Master.skp mali na definícii zastarané hodnoty, ktoré prepisovali realitu. Preto: **číta sa inštancia, definícia je len fallback pre nový vklad.**

### 2.3 Identita a väzby

Tri úrovne identity (GPT debata sekcia 31):

- **`cabinet_id`** — konkrétna skrinka v projekte (`CAB-014`). Unikátna. **Kópia skrinky dostane nové `cabinet_id`.**
- **`template_id`** — typ/šablóna, z ktorej skrinka vznikla (`base-lower-18`). Zdieľaný medzi skrinkami rovnakého typu.
- **`part_id`** — dielec. Formát `<cabinet_id>-<ROLA>[-<SPRESNENIE>]`, napr. `CAB-014-SIDE-L`, `CAB-014-SHELF-2`.

**Väzby medzi entitami sa držia cez logické ID + rolu, NIE cez názvy a NIE cez runtime handle dielca.** Kovanie sa neviaže na konkrétny dielec-dvere, ale na `cabinet_id` + `role: front_door`. Dôvod: pri regenerácii (sekcia 9) sa dielce zmažú a postavia nanovo — ich `persistentId` sa zmení. Logické ID prežije rebuild, `persistentId` nie.

- **`persistentId`** používame len na **navigáciu v rámci session** („prejdi na objekt", zvýrazni v modeli) — stabilný počas života entity, ale rebuildom zaniká. Nikdy nie ako trvalý cudzí kľúč v dátach.
- **Názvy komponentov** nie sú identita ani rola. Poučenie: `_name` „Pbok" vs. definícia „Lbok#1" — parsovanie názvov je zdroj chýb.

### 2.4 Roly ako explicitný atribút

Rola dielca/modulu je **explicitná hodnota** v `NOXUN/role`, nikdy sa neodvodzuje z názvu. Slovník rolí (rozšíriteľný):

```
side_left · side_right · bottom · top · back · shelf · divider_v · divider_h ·
front_door · drawer_front · flap · cover_panel · false_front · rail · plinth ·
gola_profile · hinge · slide · leg · handle · shelf_pin · connector
```

### 2.5 JSON príklady per vrstva

**Korpus** (`kind: cabinet`):

```json
{
  "std": 1,
  "kind": "cabinet",
  "id": "CAB-014",
  "cabinet_id": "CAB-014",
  "template_id": "base-lower-18",
  "role": "cabinet",
  "manufactured": false,
  "config": {
    "type": "lower",
    "name": "Spodná skrinka 800",
    "construction_preset": "noxun-lower-18",
    "mode": "parametric",
    "width": 800.0, "height": 720.0, "depth": 560.0,
    "floor_height": 100.0,
    "material_id": "K009_PW_DTDL_18",
    "back_material_id": "HDF_WHITE_3",
    "sides":  { "thickness": 18.0, "construction": "sides_wrap" },
    "bottom": { "mode": "between_sides", "thickness": 18.0 },
    "top":    { "mode": "two_rails", "thickness": 18.0 },
    "back":   { "mode": "grooved", "thickness": 3.0 },
    "support":{ "type": "axilo", "height": 100.0 },
    "available_width": 764.0, "available_height": 680.0, "available_depth": 520.0,
    "front_plane": 0.0,
    "zones": ["CAB-014-Z1"]
  }
}
```

**Zóna** (`kind: zone`; nevýrobná — ghost):

```json
{
  "std": 1,
  "kind": "zone",
  "id": "CAB-014-Z1",
  "cabinet_id": "CAB-014",
  "role": "zone",
  "manufactured": false,
  "config": {
    "parent_zone": null,
    "position": [0.0, 0.0, 0.0],
    "width": 764.0, "height": 680.0, "depth": 520.0,
    "state": "occupied",
    "allowed_modules": ["shelf", "divider_h", "drawer_block", "front_door"],
    "modules": ["CAB-014-M1"]
  }
}
```

**Modul** (`kind: module`; napr. dvojkrídlové dvierka):

```json
{
  "std": 1,
  "kind": "module",
  "id": "CAB-014-M1",
  "cabinet_id": "CAB-014",
  "role": "front_door",
  "template_id": "door-2wing",
  "manufactured": false,
  "config": {
    "zone_id": "CAB-014-Z1",
    "wings": 2,
    "overlay": "full",
    "gap_top": 2.0, "gap_bottom": 2.0, "gap_between": 3.0,
    "handle": "gola",
    "opening": "left_right",
    "parts": ["CAB-014-DOOR-L", "CAB-014-DOOR-R"],
    "hardware": ["CAB-014-HINGE"]
  }
}
```

**Dielec** — plný JSON v sekcii 8 (kde je pri výrobných triedach).

---

## 3. Jednotky, osi, orientácia

### 3.1 Jednotky — mm ako Float, jeden svet

**Všetky NOXUN dáta (JSON aj atribúty) sú v milimetroch ako Float.** Žiadne palce, žiadne cm, žiadny SketchUp `Length` v uložených dátach. SketchUp interne počíta v palcoch — prevod na `Length` sa deje **len na jedinom mieste v kóde**, na hranici, keď Ruby kreslí geometriu (`mm → Length` pri stavaní, `Length → mm` pri prípadnom čítaní bboxu). Uhly sú v **stupňoch** (Float).

Toto je zásadný rozdiel oproti DC svetu, kde bežali tri jednotkové svety naraz (uložené palce / vzorce cm / zobrazenie mm) a spôsobovali chyby ako `18 → 457 mm`. Nový systém má **jeden svet: mm Float.**

### 3.2 Osi a origin

Lokálne osi komponentu:

- **X = šírka** (doľava–doprava)
- **Y = hĺbka** (dopredu–dozadu; +Y ide dozadu do skrinky)
- **Z = výška** (nahor)

Origin konvencie:

- **Korpus:** origin = ľavý-predný-dolný roh korpusu. Čelná (montážna) rovina = `Y = 0`, hĺbka rastie do `+Y`. Čelá sadajú **pred** rovinu (do záporného Y) o hrúbku + škáru — sedí s DC praxou, kde dvierka boli pred korpusom.
- **Dielec:** origin = ľavý-predný-dolný roh dielca (min X, min Y, min Z).
- **Dvierka / rotačné čelo:** origin **na hrane pántu** — rotácia je vždy okolo lokálneho počiatku (DC pravidlo). Rotačný komponent baliť do izolovanej skupiny (nikdy Flip Along na animovanom komponente).

> Presné originy pre všetky typy modulov sú v sekcii 12 (overiť na prototype).

### 3.3 Výrobná orientácia nezávislá od rotácie

Toto je invariant a jeden z hlavných dôvodov existencie štandardu:

- **Výrobné rozmery** dielca (`length`, `width`, `thickness`), **hrany** (L1/L2/W1/W2) a **smer dekoru** (`grain_direction`) sa určujú z **konfigurácie dielca**, nikdy z bounding boxu a nikdy z otočenia skrinky v miestnosti.
- Keď používateľ otočí skrinku o 90° v pôdoryse, kusovník, hrany a dekor sa **nesmú zmeniť**. Rotácia je vec umiestnenia v modeli, nie výrobných dát.
- `grain_direction`: `"length"` / `"width"` / `"none"` — smer dekoru vzhľadom na výrobný rozmer dielca (nie vzhľadom na os modelu). Explicitný atribút, nie odvodený z natočenia textúry.

Poučenie: v OCL sa opakovane zamieňala šírka s hrúbkou pri rotovaných dielcoch. Keď rozmery kladie Ruby z konfigurácie, tento problém nevzniká.

---

## 4. Korpus

### 4.1 Korpus nie je monolit

Korpus = **obálka + konštrukcia + zóny + rozhrania.** Nie master komponent s desiatkami predmodelovaných kombinácií (to bol dnešný DC model). Skladá sa kompozíciou: spodný korpus + dvierka + police + nohy + kovanie — nie samostatný typ pre každú kombináciu.

### 4.2 Typy korpusov na štart

**V1: DOLNÁ a HORNÁ skrinka.** Pokryjú 60–70 % potrieb. Ostatné (vysoká, spotrebičová, drezová, rohová…) sa **odvodia** od týchto dvoch neskôr. Rohové a atypické korpusy sú mimo scope V1 (sekcia 12 / mimo scope).

### 4.3 Geometriu generuje Ruby (regenerate pattern)

**Rozhodnuté a prakticky overené (analýza `02`, 3 živé experimenty cez SkAgent).** Korpus = `funkcia(konfigurácia) → geometria`. Konfigurácia žije v `NOXUN/config` (mm, JSON). Pri zmene plugin v **jednej Undo operácii** zmaže vnútro a deterministicky postaví nanovo. **Žiadne DC vzorce v novom systéme.** Dva režimy životného cyklu — parametrický a odpojený — sú v sekcii 9.

### 4.4 Konštrukčné predvoľby s override

Korpus nesie konštrukciu ako dáta, s pomenovanými predvoľbami:

- `noxun-lower-18` (spodný 18 mm), `noxun-upper-18` (horný 18 mm), `noxun-16` (16 mm)…
- Každá predvoľba nastaví hrúbky, spôsob uloženia dna/vrchu, typ chrbta, odsadenia.
- **Každé pole má pokročilý override** — predvoľba je štart, nie väzenie.

Konštrukčné varianty (ArchiWood vzor, dnešné `f_dno`/`f_strop`):

- **Dno/vrch:** medzi bokmi ↔ pod/nad bokmi; naložené ↔ vložené; dvojité dno; bez dna.
- **Boky:** obaľujú dno/vrch ↔ sú obalené (`sides_wrap` / `wrapped`).
- **Vrch:** plný ↔ predná/zadná priečka ↔ dve priečky (`two_rails`) ↔ bez vrchu.
- **Chrbát:** vložený medzi boky ↔ naložený zozadu ↔ v drážke (`grooved`) ↔ delený ↔ bez chrbta.

### 4.5 Čistý priestor a rozhrania

Korpus **vypočíta a nesie** (v `config`, ako cache — zdroj pravdy zostáva rozmerový config):

- **Čistý vnútorný priestor:** `available_width`, `available_height`, `available_depth` — používajú ich zóny a moduly.
- **Rozhranie pre čelá:** `front_plane` (čelná rovina), čistý čelný otvor, prekrytie bokov/hore/dole, medzery, zakázané zóny. Korpus definuje **priestor pre čelo**; konkrétny typ čela rieši modul čiel (sekcia 5).
- **Rozhranie pre podopretie:** typ (AXILO nohy / plastové nohy / plný sokel / závesný / bez), výška, odsadenia. Konkrétny produkt a počet vyberie kovania engine (sekcia 6).

---

## 5. Zóny a moduly

### 5.1 Zóna (slot)

Zóna je dátová štruktúra: rozmery (svetlé), pozícia v korpuse, stav (`free`/`occupied`), zoznam povolených modulov. Vloženie modulu = zápis do konfigurácie + rebuild — nie ručné modelovanie. Presne ArchiWood/CabMaker princíp (ktorý DC nepoužíva).

**Delenie:** priečka alebo polica rozdelí zónu na nové zóny — **rekurzívne**, vzniká strom priestorov. Napr. horizontálna priečka rozdelí zónu na hornú a dolnú; každá je ďalej deliteľná.

**Ghost vizualizácia:** zóny sú polopriehľadné boxy na tagu `Noxun/Zóny` (vypnutie tagu = neviditeľné), každá listová zóna ako samostatná top-level skupina (klikateľná 1 klikom). `manufactured: false` — nikdy v kusovníku.

### 5.2 Povolené moduly

Zóna nesie `allowed_modules` — čo do nej smie. Modul pri vklade dostane rozmery zo zóny a pridá vlastné pravidlá: škáry, presahy, max hĺbka výsuvu, odsadenie od chrbta („inteligentné defaulty"). Kategórie modulov:

- **Čelá** (samostatná kategória — viď 5.3)
- **Police** — počet, hrúbka, materiál, hĺbka, odsadenia, spôsob uloženia, ABS; režim rozloženia rovnomerne/manuálne/podľa zóny.
- **Priečky** — vertikálne/horizontálne, pevné/vyberateľné; vytvárajú nové zóny.
- **Zásuvkové bloky** — zostava čelo + bočnice + dno + výsuv.
- **Vnútorné vybavenie** — vešiakové tyče, drôtené koše, odpadkové systémy, výsuvné police, botníky…
- **Doplnky** — LED profily, zásuvky 230 V, USB, organizéry, ventilačné mriežky; môžu byť výrobné, kusovníkové, vizualizačné alebo konštrukčné (ak vyžadujú výrez).

### 5.3 Čelá — samostatná kategória s lockmi

Čelá nie sú len „dvere". Zahŕňajú: jednokrídlové/dvojkrídlové dvierka, zásuvkové čelá, výklopy, posuvné čelá, pevné krycie panely, falošné čelá, rámové a bezúchytkové riešenia. Čelný modul rieši: typ, počet, delenie, medzery, prekrytie korpusu, materiál, ABS, smer otvárania, úchytky, požiadavky na kovanie. **Geometria čela, spôsob otvárania a konkrétne kovanie sú oddelené.**

**Delenie na výšku: FIXNÉ + AUTO s lockmi** (Blum-konfigurátor princíp). Jedno čelo zamknem na fixnú výšku, ostatné sa dopočítajú automaticky z zvyšku po odčítaní zamknutých + škár:

```json
{
  "split_axis": "height",
  "gap": 3.0,
  "fronts": [
    { "id": "F1", "mode": "fixed", "height": 140.0, "locked": true },
    { "id": "F2", "mode": "auto" },
    { "id": "F3", "mode": "auto" },
    { "id": "F4", "mode": "fixed", "height": 280.0, "locked": true }
  ]
}
```

`auto` čelá si rovnomerne rozdelia zvyšnú výšku. **Škáry a prekrytia sú konfigurovateľné** (`gap_top`, `gap_bottom`, `gap_between`, `overlay`).

---

## 6. Kovanie

### 6.1 Katalóg oddelený od pravidiel

Dve nezávislé vrstvy (GPT debata sekcie 16–17):

- **Katalóg kovania** — konkrétne fyzické produkty (Blum Clip Top 110°, Hettich Quadro, AXILO…). Záznam: výrobca, kód, názov, kategória, rozmery, cena, dodávateľ, kompatibilita, prípadne 3D. Prevezme sa z KOVANIE (CatalogStore, search, Demos import).
- **Pravidlá kovania (rules engine)** — rozhodujú, **aký typ a koľko kusov**. Konkrétne kovanie **nikdy natvrdo v definícii korpusu.**

### 6.2 Two-phase: generický flag → katalógový kód

**Fáza 1 — generický flag z pravidiel.** Pri vklade/zmene modulu systém pridelí generický flag (`hinge`, `slide`, `leg`…) s množstvom z pravidiel v JSON. Príklad pravidla (počet pántov podľa výšky dvierok):

```json
{
  "rule_id": "hinge-count-by-height",
  "applies_to": "front_door",
  "output": "hinge",
  "bands": [
    { "max_height": 900,  "quantity": 2 },
    { "max_height": 1600, "quantity": 3 },
    { "max_height": null, "quantity": 4 }
  ]
}
```

Pravidlá sú **JSON súbory v knižnici pravidiel, editovateľné cez jednoduchý panel** (nie ručne v súbore). Michal si počty závesov / výnimky mení bez programovania.

**Fáza 2 — mapovanie na konkrétny katalógový kód.** Na konci projektu (alebo raz v nastaveniach) sa flag `hinge` namapuje na konkrétny kód (`Blum 71B3550`). **Mapovanie sa ukladá a nabudúce prebehne automaticky.**

### 6.3 Fyzická reprezentácia: 1 generický objekt + virtuálne varianty

- V modeli je **najviac 1 generický fyzický objekt na kategóriu** (`hinge`, `slide`, `leg`) — slúži na vizuál, pozíciu a ako základ budúcich vylepšení.
- Na generický objekt sa viaže **ľubovoľne veľa virtuálnych variantov** (konkrétni výrobcovia/kódy) — **čisto dátovo** v katalógu, bez ďalšej geometrie.
- Skrutky/spojky = čisto virtuálne (žiadna geometria).

**Vŕtanie a presné pozície kovania sú MIMO scope V1** — riešia sa len počty, typy a kódy.

---

## 7. Materiály a ABS

### 7.1 Materiálový katalóg — rodina vs. variant

Materiál nie je SketchUp textúra. Je to katalógový záznam. Rozlišujeme:

- **Rodina** — napr. „Kronospan K009 PW".
- **Variant** — **dekor + typ materiálu + hrúbka = samostatný výrobný materiál a samostatný kusovník.** `K009 PW / DTDL / 18 mm` a `K009 PW / DTDL / 16 mm` sú dva rôzne varianty, hoci majú rovnaký dekor.

Záznam variantu:

```json
{
  "material_id": "K009_PW_DTDL_18",
  "family": "Kronospan K009 PW",
  "manufacturer": "Kronospan",
  "decor": "K009 PW",
  "type": "DTDL",
  "thickness": 18.0,
  "grain": "length",
  "price_per_m2": 12.50,
  "sheet_size": [2800.0, 2070.0],
  "texture": "K009_PW.jpg",
  "production_class": "sheet"
}
```

Kusovník podľa materiálov sa delí podľa **material_id (variant) + hrúbka**.

### 7.2 Materiálové dedenie

```
projektový default → skrinka dedí → modul dedí → konkrétny dielec override
```

Napr.: projekt `K009_PW_DTDL_18` → korpus zdedí → police zdedia → jedna polica ručný override na iný dekor/hrúbku.

### 7.3 Výrobný materiál = zdroj pravdy; plochy = vizuál

Výrobný materiál sa ukladá **na úrovni výrobného komponentu** (`material_id`). Materiály namaľované na jednotlivé plochy slúžia len na **vizualizáciu a orientáciu textúry**. Výrobný systém **nikdy** neurčuje materiál podľa náhodne namaľovanej plochy.

### 7.4 Tri stavy materiálu

1. **Zaradený** výrobný materiál.
2. **Explicitne ignorovaný** — potvrdená dekorácia / referenčný materiál.
3. **Nezaradený** — používateľ ešte nerozhodol.

Nezaradené sa **nesmú ignorovať potichu.** Pred exportom musí platiť:

```
Nezaradené materiály: 0
```

### 7.5 ABS hrany — per strana L1/L2/W1/W2

Každý plošný dielec nesie hrany **per strana** ako dáta (nezávislé od vizuálnej textúry):

```json
"edges": { "L1": "ABS_K009_1.0", "L2": null, "W1": "ABS_K009_0.4", "W2": "ABS_K009_0.4" }
```

- Hodnota strany = `null` (bez hrany) alebo **ABS variant ID** (`ABS_K009_1.0` = dekor + hrúbka ABS).
- `L1`/`L2` = dvojica pozdĺžnych strán, `W1`/`W2` = dvojica priečnych.
- **UI ich prekladá** na predná/zadná/ľavá/pravá. Interný systém je odolný voči otočeniu skrinky — hrany sa držia per strana, súhrnné kódy (`—`/`=`) sa **dopočítajú až pri exporte** (VEPO nevie povedať KTORÁ strana, kusovník a CNC to potrebujú presne).

**Pravidlové defaulty podľa roly dielca** + výnimky + ručný override:

- Čelo: hranovanie dookola. Polica: len predná. Chrbát v drážke: nič.
- Výnimky pravidlami: hrúbka < prah → nič; rola v zozname výnimiek → nič.
- Ručný override per dielec vždy víťazí.

> Presné mapovanie strán L1/L2/W1/W2 pri rôznych rotáciách dielca je otvorený bod — sekcia 12.

### 7.6 ABS vizuálny režim (samostatný modul)

Samostatný režim na vizuálnu kontrolu hrán:

- Dielce polopriehľadné (~30–50 % opacity), ABS hrany plné a **farebne podľa hrúbky** (napr. 1,0 mm červená, 0,4 mm modrá, 2,0 mm zelená, bez ABS sivá).
- **Konfliktné / neurčené hrany oranžové.**
- Klik na hranu = zmena ABS. Farby používateľsky nastaviteľné.
- Filtre: všetky hrany / iba vybraný typ / iba chyby / iba vybraná skrinka. Master korpus dá základné pravidlá, ABS editor je finálna kontrolná vrstva.

---

## 8. Výrobné triedy a dátový model dielca

### 8.1 Štyri výrobné triedy

Výrobný stav je **explicitne v metadátach** (`production_class` + `manufactured`), nie podľa typu SketchUp entity. **Group sa štandardne nepočíta** (dekorácie, spotrebiče, pomocná geometria).

| Trieda | Čo meria | Príklady |
|---|---|---|
| `sheet` | dĺžka × šírka × hrúbka + ABS | DTDL, MDF, preglejka, kompakt, sklo, plech |
| `linear` | **výrobná dĺžka z KONFIGURÁCIE** (nie z najdlhšej hrany geometrie) | Gola profily, LED, soklové lišty, tyče |
| `counted` | kus (produkt + kód + množstvo) | pánty, nohy, výsuvy, úchytky, spojky |
| `reference` | nepočíta sa | spotrebiče, dekorácie, miestnosť, vizuál |

**Kritické pri `linear`:** dĺžka sa berie z `config.length`, ktoré nastavil engine — nie automaticky z najdlhšej hrany bboxu.

### 8.2 Plný dátový model dielca (sheet)

Podľa sekcie 2.1: **ploché kľúče = identita a filtre; všetko rozmerové a výrobné žije v `config` (JSON string)** — tak to ukladá aj engine (`NOXUN/config`). Exportéry čítajú rozmery VÝHRADNE z `config`.

```json
{
  "std": 1,
  "kind": "part",
  "id": "CAB-014-SIDE-L",
  "part_id": "CAB-014-SIDE-L",
  "cabinet_id": "CAB-014",
  "template_id": "base-lower-18",
  "role": "side_left",
  "manufactured": true,
  "production_class": "sheet",
  "config": {
    "name": "Bok ľavý",
    "quantity": 1,
    "length": 720.0,
    "width": 560.0,
    "thickness": 18.0,
    "material_id": "K009_PW_DTDL_18",
    "grain_direction": "length",
    "edges": {
      "L1": "ABS_K009_1.0",
      "L2": null,
      "W1": "ABS_K009_0.4",
      "W2": "ABS_K009_0.4"
    }
  }
}
```

- `length`/`width`/`thickness` = **reálne** výrobné rozmery v mm Float. **Obchodná hrúbka** (18/36) sa **dopočíta pri exporte** podľa VEPO kontraktu (18.0–19.1 → 18; 36.0–38.1 → 36) — v modeli držíme reálne.
- `quantity` — počet identických kusov.

**Linear dielec:**

```json
{
  "std": 1, "kind": "part", "id": "CAB-014-GOLA-TOP",
  "part_id": "CAB-014-GOLA-TOP", "cabinet_id": "CAB-014",
  "role": "gola_profile",
  "manufactured": true, "production_class": "linear",
  "config": { "name": "Gola horná", "quantity": 1, "length": 764.0, "material_id": "GOLA_C_ALU" }
}
```

**Counted položka (kovanie):**

```json
{
  "std": 1, "kind": "hardware", "id": "CAB-014-HINGE",
  "part_id": "CAB-014-HINGE", "cabinet_id": "CAB-014",
  "role": "hinge",
  "manufactured": true, "production_class": "counted",
  "config": { "name": "Pánt", "generic_type": "hinge", "quantity": 6,
              "variant_id": "blum_clip_top_110", "catalog_code": "71B3550" }
}
```

**Reference objekt:**

```json
{
  "std": 1, "kind": "reference", "id": "REF-DW-01",
  "role": "appliance",
  "manufactured": false, "production_class": "reference",
  "config": { "name": "Umývačka 60" }
}
```

Geometria, kusovník aj exporty sú **rôzne reprezentácie toho istého dátového modelu** — nie samostatné pravdy.

---

## 9. Regenerácia a životný cyklus

### 9.1 Regenerate pattern

1. načítaj konfiguráciu, 2. validuj ju, 3. odstráň generované child dielce, 4. deterministicky ich vytvor znova, 5. zachovaj podporované override a moduly, 6. ulož výslednú konfiguráciu. Celé v **jednej Undo operácii** (`start_operation` … `commit_operation`) — žiadne kumulatívne chyby, žiadny `$dc_observers`.

### 9.2 Dva režimy (V1)

- **Plne parametrický** — geometriu riadi engine; ručné geometrické úpravy sa pri regenerácii prepíšu. `config.mode = "parametric"`.
- **Odpojený** — skrinka sa zmení na bežnú SketchUp geometriu, engine ju ďalej neregeneruje. `config.mode = "detached"`. Dielce ostávajú čitateľné pre kusovník, ale strácajú parametrickosť.

Čiastočné geometrické override (parametrický korpus s ručne upraveným jedným dielcom) **nie sú vo V1** — zbytočná komplexita.

### 9.3 Kópia, rotácia, save/reopen

- **Kópia skrinky** → nové `cabinet_id`; `template_id` môže zostať. Nové `part_id` sa odvodia z nového `cabinet_id`. Kópia sa dá upraviť nezávisle od originálu.
- **Rotácia** v modeli **nemení** výrobné dáta (rozmery, hrany, dekor) — viď 3.3.
- **Save/reopen** — dáta žijú v `NOXUN` dictionary na inštancii, prežijú uloženie a znovuotvorenie. `persistentId` je stabilný v rámci modelu; väzby sú aj tak logické (2.3), takže reopen nič nerozbije.
- **Rebuild mení `persistentId` dielcov** → nikdy naň neviazať trvalé cudzie kľúče (kovanie, markery). Väzba = `cabinet_id` + `role`.

> Správanie pri zmene rozmeru korpusu s obsadenými zónami (auto-prepočet detí, kedy resize limitovať) — sekcia 12.

---

## 10. Validácia (semafor)

Pred odovzdaním systém kontroluje minimálne (GPT debata sekcia 32):

- neplatné rozmery; záporný vnútorný priestor
- nesúlad hrúbky materiálu a geometrie
- chýbajúci materiál; **nezaradený materiál** (musí byť 0)
- chýbajúce ABS; konflikt ABS
- neplatný chrbát; kolízie dielcov
- nekompatibilné kovanie; nedostatočná hĺbka pre výsuv
- príliš veľké/malé čelo
- komponent bez výrobného zaradenia; group s výrobným materiálom; výrobný diel bez materiálu

**Semafor** — stav modelu na jeden pohľad (zelená = pripravené, žltá = varovania, červená = blokujúce chyby). Validácia **neiba vypíše chybu, ale ponúkne opravu:**

```
Zvolený výsuv 500 mm sa nezmestí.
Možnosti:
  a) použiť výsuv 450 mm
  b) zväčšiť hĺbku korpusu
  c) odstrániť výsuv
```

---

## 11. Výstupy

### 11.1 Interný dátový model = jediný zdroj pravdy

Žiadny externý plugin ani formát (OCL, VEPO) nie je zdroj pravdy. NOXUN Furniture Engine vlastní výrobné dáta priamo. **Exportéry sú tenké adaptéry** nad už validovanými internými dátami — neobsahujú konštrukčnú logiku, určovanie materiálu, výpočty ABS ani rozmerov. Len prevedú hotové dáta do cieľového formátu.

### 11.2 Zoznam výstupov (V1)

- **Interný kusovník dielov** — všetky `manufactured: true` dielce.
- **Kusovník podľa materiálov** — delený podľa `material_id` + hrúbka, plocha v **m²**.
- **Súpis ABS** — podľa ABS variantu, dĺžka v **bm**.
- **Súpis kovania** — podľa katalógového kódu, počet **ks** (z flagov → mapovanie fáza 2).
- **Celkový sumár** — kusovník + m² + bm + ks + súčet cien materiálu/ABS/kovania.
- **VEPO CSV** — presne podľa `03_VYSTUP_vepo_kontrakt.md` (stĺpce `nazov;dlzka;hrana_pozdlz;sirka;hrana_naprieč;hrubka;pocet_ks;material`, oddeľovač `;`, úvodzovky, `—`/`=` kódy hrán dopočítané z L1/L2/W1/W2, normalizácia hrúbok 18/36, slug názvy súborov `<projekt>_<material>_<hrubka>.csv`). Priamo z dielcov, **bez OCL medzikroku**.

**Žiadne marže, žiadne DPH, žiadna cena práce** — možno neskôr. Cenotvorba je len súčet materiálu/ABS/kovania.

> Prechodná poistka: OCL zostáva nainštalovaný len na **krížovú validáciu** prvých zákaziek (porovnať náš kusovník s OCL výstupom); po zhode sa odstaví. Nie je to prispôsobovanie sa OCL, je to test správnosti.

---

## 12. Otvorené body

Zámerne nerozhodnuté — overia sa na prototype/V1 v SketchUpe (SkAgent), nie od stola:

1. **Presné mapovanie hrán L1/L2/W1/W2 pri rotácii dielca** (❓ osnova 7). Princíp je uzamknutý: hrany per strana, nezávislé od rotácie skrinky. Otvorený je konkrétny algoritmus priradenia strán pri natočených/zrkadlených dielcoch — otestovať na reálnych dielcoch skôr, než sa uzamkne.
2. **Detailná schéma pravidiel** kovania a ABS (formát `bands`/výnimiek). Princíp (JSON v knižnici pravidiel + editačný panel, two-phase) je uzamknutý; presná štruktúra polí sa doladí pri stavbe panela.
3. **Presné origin konvencie pre všetky typy modulov** (❓ osnova 3). Korpus, dielec a rotačné čelo sú určené (sekcia 3.2); originy zásuvkových blokov, priečok a doplnkov overiť na prototype.
4. **Správanie pri zmene rozmeru korpusu s obsadenými zónami** (❓ osnova 5): auto-prepočet detí, kedy resize zakázať/limitovať (princíp `LARGEST/SMALLEST` — min/max rozmery pre kovanie).
5. **Ghost zón** — vizuálne demo v SketchUpe (🔶 osnova 1) potvrdí opacity, farby, správanie prepínača tagu `Noxun/Zóny`. (Potvrdené V0.2b/c — ghosty fungujú, tag migrovaný z NOXUN_SLOTY.)
6. **C2 migračný most** — existujúce DC childy (napr. Atira šuflíky) dočasne ako čierne skrinky (scale+redraw). Ich vnútorné `parent!` vzorce mimo pôvodnej skrinky nebežia — rozmery im dáva zóna (Ruby). Rozsah a trvanie mosta sa spresní pri prvej vlne childov.
7. **Spájanie a zarovnávanie korpusov v zostave** (Michal, 15.7.2026): default = zarovnanie **čelných hrán** (hĺbky korpusov môžu byť rozdielne); voliteľne zarovnanie **zadných hrán**. Koncept jednoduchých **pripájacích bodov (kotiev)** na korpuse — vrátane špeciálnych situácií: rohová skrinka sa nepája priamo na rohový styk (potrebný dištančný/rohový princíp — viď foto reálnej kuchyne). Existujúca logika prisúvania v `snaper` (compute_gap v lokálnom ráme cieľa) je kandidát na prevzatie. Rieši sa PO V0 na reálnych zostavách — postrehy budú jasnejšie z klikania.

### Mimo scope štandardu v1 (nie „otvorené" — zámerne vynechané)

Vŕtacie pozície a CNC rastre kovania • nesting / nárezové plány • cena práce • automatické výkresy • cloud • rohové a atypické korpusy • šikmé/zakrivené dielce • kompletný kuchynský CAD. K týmto sa systém dostane, až keď jadro (štandard → referenčný korpus → childy → kovania → výstupy) stojí a je overené.
