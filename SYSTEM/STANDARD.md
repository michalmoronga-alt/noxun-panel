# Noxun Component Standard v1.0 (15.7.2026, potvrdený praxou — premenovaný z draftu 24.7.2026)

> Záväzný kontrakt dátového modelu a princípov nového SketchUp plugin systému pre nábytkárstvo na mieru (korpusy, čelá, kovanie, ABS, výstupy).
> Nadväzuje na `archiv/00_VIZIA_povodna.md`, uzamknuté rozhodnutia z `archiv/01_STANDARD_osnova.md`, analýzu `archiv/02_ANALYZA_korpus_dc_vs_ruby.md`,
> VEPO kontrakt `VEPO_KONTRAKT.md` a technické pasce v `docs/DC_PRAVIDLA.md`.
> Štandard bol overený implementáciou V0.1–V0.5 (vrátane krížovej validácie VEPO výstupov s OCL flow 20.7.2026) a z „draftu" sa stal potvrdeným kontraktom.
>
> **Tento dokument hovorí, čo PLATÍ.** Kedy a ktorou dávkou pravidlo vzniklo, patrí do [archiv/KRONIKA.md](archiv/KRONIKA.md) — nie sem.

---

## 0. Účel a záväznosť

**Prečo tento dokument existuje.** Každý doterajší plugin (KOVANIE, DC Control, OCL adaptéry, vepo_exporter) riešil kúsok toho istého problému znova,
lebo neexistoval jeden spoločný kontrakt: čo je skrinka, čo je dielec, aké nesie dáta, v akých jednotkách, ako sa počítajú hrany a kovanie.
Tento štandard je ten kontrakt. Všetky moduly nového systému (generátor korpusov, panel na pripájanie childov, kovania engine, ABS editor, výstupy) sa musia riadiť ním.

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
- **Zóna (slot)** — adresovateľné pole vnútra korpusu: celé vnútro, alebo časť medzi policami/priečkami. Má rozmery, pozíciu, stav (voľná/obsadená), zoznam povolených modulov.
  Vzniká a zaniká delením. **Vizualizácia:** polopriehľadný ghost box na tagu **`Noxun/Zóny`** — vypnutie tagu = neviditeľné;
  geometria zón nikdy nejde do kusovníka (viď sekcia 8, `manufactured: false`).
  (Historický tag `NOXUN_SLOTY` z prvých prototypov bol migrovaný — nové moduly ho nesmú vytvárať.)
- **Modul / child** — funkčný prvok vložený do zóny (čelo, polica, priečka, zásuvkový blok, vnútorné vybavenie, doplnok). Zo zóny dostane rozmery, pridá vlastné pravidlá (škáry, presahy, odsadenia).
- **Dielec** — fyzický kus materiálu na výrobu. Vždy samostatný SketchUp komponent s NOXUN metadátami. Zdroj kusovníka.
- **Virtuálna položka** — kovanie a spotrebný materiál, ktoré sa počítajú do súpisu, ale nemajú výrobnú geometriu. Fyzicky ich zastupuje najviac 1 generický objekt na kategóriu (viď sekcia 6).

---

## 2. Identita a atribúty

### 2.1 Jeden dictionary na entite

Každá NOXUN entita nesie **jediný** attribute dictionary s názvom `NOXUN`. Žiadna dnešná zmes (`NOXUN_CORE` + `NOXUN_KOVANIE` + DC `dynamic_attributes`). Kľúče sú buď ploché skalárne hodnoty (časté čítanie, filtre, marker), alebo zložité štruktúry uložené ako **JSON string** v jednom kľúči.

**Jediná povolená výnimka:** kľúč `scaletool` v dictionary `dynamic_attributes` (V0.2c — obmedzenie scale úchopov na čisté osi X/Y/Z). SketchUp číta tento atribút natívne a inde sa uložiť nedá; žiadny iný zápis mimo `NOXUN` nie je dovolený.

Základný layout (ploché kľúče, čítané často):

| Kľúč | Typ | Význam |
|---|---|---|
| `std` | Integer | verzia štandardu (v1 = 1) |
| `kind` | String | vrstva v hierarchii: `cabinet` / `zone` / `module` / `part` / `hardware` / `reference` / `board` (V0.4.7 — samostatná doska, viď 8.3) |
| `id` | String | identita entity (napr. `CAB-014`, `CAB-014-SIDE-L`) |
| `part_id` | String | identifikátor aktuálne vygenerovanej geometrie dielca |
| `part_key` | String | stabilná identita dielca v rámci korpusu; cudzí kľúč pre override/kovanie/výstupy |
| `part_key_schema` | Integer | verzia schémy `part_key` (aktuálne `1`) |
| `cabinet_id` | String | na ktorý korpus entita patrí (samostatná doska `kind: board` ho **nemá** — je top-level) |
| `template_id` | String | typ/šablóna (napr. `base-lower-18`) |
| `role` | String | rola dielca/modulu (viď 2.4) |
| `manufactured` | Bool | ide do výroby? (explicitne, nie podľa typu entity) |
| `production_class` | String | `sheet` / `linear` / `counted` / `reference` / `none` (viď sekcia 8) |
| `name` | String | ľudský názov dielca („Bok ľavý") — kusovník a VEPO čítajú názov odtiaľto, nie z `config` |
| `role_key` | String | kompatibilitný alias `part_key` — buildery korpusu ho zapisujú s rovnakou hodnotou (doska ho nepíše), čítacia cesta ho berie ako fallback pre staršie modely a jeho meno nesie aj legacy UI protokol; kanonická identita je `part_key` |
| `config` | JSON string | celá konfigurácia entity (rozmery, konštrukcia, zóny, hrany, materiál…) |

Zložité veci (rozmery + konštrukcia korpusu, zoznam hrán dielca, delenie čiel) žijú v `config` ako JSON string. Dôvod: SketchUp dictionary je plochý kľúč→hodnota; JSON je jediný spoľahlivý spôsob, ako niesť vnorenú štruktúru bez desiatok kľúčov.

### 2.2 Autorita = inštancia

Dáta konkrétnej skrinky sú na **inštancii**. Definícia komponentu môže niesť len **template defaulty** (východiskové hodnoty šablóny). Poučenie z DC praxe: zdieľané definície dverí v Master.skp mali na definícii zastarané hodnoty, ktoré prepisovali realitu. Preto: **číta sa inštancia, definícia je len fallback pre nový vklad.**

### 2.3 Identita a väzby

Štyri úrovne identity:

- **`cabinet_id`** — konkrétna skrinka v projekte (`CAB-014`). Unikátna. **Kópia skrinky dostane nové `cabinet_id`.**
- **`template_id`** — typ/šablóna, z ktorej skrinka vznikla (`base-lower-18`). Zdieľaný medzi skrinkami rovnakého typu.
- **`part_key`** — stabilná identita konkrétneho dielca **v rámci korpusu**, napr. `cabinet/side:left`, `zone:Zabc123/shelf:1`, `front:F2/wing:left`. Neodvodzuje sa z aktuálneho poradia ani z cesty zóny. Je cudzím kľúčom pre `part_overrides`, kovanie a budúce výstupy.
- **`part_id`** — identifikátor aktuálne vygenerovanej geometrie. Formát zostáva `<cabinet_id>-<ROLA>[-<SPRESNENIE>]`, napr. `CAB-014-SIDE-L`. Pri prečíslovaní čiel alebo zmene cesty zóny sa môže zmeniť, preto nie je trvalým cudzím kľúčom.

**Väzba na konkrétny dielec = `cabinet_id` + `part_key`.** `role` určuje kategóriu dielca a používa sa na pravidlá či hromadný výber podobných dielcov. Názov, renderovací suffix ani runtime handle nie sú dátová identita.

**Owner-scope pravidlo (V0.4.7):** `part_key` je stabilná identita dielca **v rámci vlastníka**.
Vlastníkom je korpus (`cabinet_id` + `part_key`, prefixy `cabinet/`, `zone:`, `front:`) alebo samostatná doska (`id` dosky + konštantný `part_key` `board/main`, prefix `board/`).
Unikátnosť naprieč modelom dáva vždy dvojica vlastník + kľúč — preto sa konštantný `board/main` nikdy nevaliduje v spoločnom pláne viacerých dosiek.

- **`persistentId`** používame len na **navigáciu v rámci session** („prejdi na objekt", zvýrazni v modeli) — stabilný počas života entity, ale rebuildom zaniká. Nikdy nie ako trvalý cudzí kľúč v dátach.
- **Názvy komponentov** nie sú identita ani rola. Poučenie: `_name` „Pbok" vs. definícia „Lbok#1" — parsovanie názvov je zdroj chýb.

### 2.4 Roly ako explicitný atribút

Rola dielca/modulu je **explicitná hodnota** v `NOXUN/role`, nikdy sa neodvodzuje z názvu. Slovník rolí (rozšíriteľný):

```
side_left · side_right · bottom · top · back · shelf · divider_v · divider_h ·
front_door · drawer_front · flap · cover_panel · false_front · rail_front · rail_back · plinth ·
gola_profile · hinge · slide · leg · handle · shelf_pin · connector · free_panel
```

`free_panel` = voľná samostatná doska (V0.4.7, `kind: board`). Plánované roly dosiek (pribudnú **až s implementáciou** ich správania, vzor „rola pilaster do štandardu pri implementácii"): `cover_side` (pilaster), `cover_top`, `filler` (výplň), `worktop` (pracovná doska), `plinth_board` (soklová doska/lišta — môže byť `production_class: linear`).

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
    "config_schema": 1,
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
    "back":   { "mode": "groove", "thickness": 3.0 },
    "support":{ "type": "axilo", "height": 100.0 },
    "available_width": 764.0, "available_height": 680.0, "available_depth": 520.0,
    "front_plane": 0.0,
    "zones": ["CAB-014-Z1"]
  }
}
```

**`config_schema` — verzia kontraktu configu korpusu (záväzné od v0.9.3, R-12).** Config korpusu je **uzavretý whitelist** (`CabinetBuilder.normalize` + `cabinet_config`), takže zákazka uložená novším pluginom by pri prestavbe ticho prišla o polia, ktorým staršia verzia nerozumie. Preto:

- **Marker je povinný v každom uloženom configu korpusu** a zapisuje sa **v jedinom zápisovom bode** (`cabinet_config`, cez ktorý ide vklad aj prestavba) — vždy ako **aktuálna** hodnota `CabinetBuilder::CONFIG_SCHEMA`, nikdy sa nepreberá zo vstupných params (klientsky payload nie je autorita). Chýbajúci marker = legacy config (0) a je platný.
- **Dopredný guard:** uložené číslo **vyššie** než `CONFIG_SCHEMA` odmieta **PRESTAVBU** (a odvodené objekty: kópia skrinky, uloženie ako šablóna). Čítanie, výber, kusovník, VEPO ani exporty sa neblokujú — model z novšej verzie sa ďalej číta.
- **Šablóna nesie ten istý marker** (`template_config_from`) — jej config je rovnako uzavretý whitelist, takže staršia verzia šablónu z novšej odmietne použiť aj vložiť.
- **Disciplína bumpu:** číslo sa zvýši pri **každom rozšírení whitelistu configu o pole, ktorého tichá strata by poškodila výrobu** (nové konštrukčné pole, nový typ čela, nová rola). Čisto odvodené alebo kozmetické pole bump nevyžaduje. `plan_schema` (tvar tranzientného plánu) ani `part_key_schema` (kľúče dielcov) kompatibilitu configu **nevyjadrujú** a nenahrádzajú ho.

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
    "shelves": 1,
    "allowed_modules": ["shelf", "divider_v", "divider_h", "drawer_block", "front_door"],
    "modules": []
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
    "gap_top": 2.0, "gap_bottom": 2.0,
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

**Všetky NOXUN dáta (JSON aj atribúty) sú v milimetroch ako Float.** Žiadne palce, žiadne cm, žiadny SketchUp `Length` v uložených dátach.
SketchUp interne počíta v palcoch — prevod na `Length` sa deje **len na jedinom mieste v kóde**, na hranici, keď Ruby kreslí geometriu
(`mm → Length` pri stavaní, `Length → mm` pri prípadnom čítaní bboxu). Uhly sú v **stupňoch** (Float).

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
- `grain_direction`: `"length"` / `"width"` / `"none"` — smer dekoru vzhľadom na výrobný rozmer dielca (nie vzhľadom na os modelu). Explicitný atribút, nie odvodený z natočenia textúry ani z pomeru rozmerov (štvorcový dielec je nerozhodnuteľný).
- **Rotácia dielca kvôli kresbe je vec VÝSTUPU, nie modelu** (K1). Snapshot dielca nesie **geometrické** rozmery + `grain_direction`;
  výmenu `dĺžka ↔ šírka` **spolu s výmenou dvojíc hrán** `L↔W` robí výhradne export do VEPO (`VepoExport.oriented`) a zrkadlovo kontrola nárezu (`Validation.fits_on_sheet?`).
  Rovnaká výmena sa **nikdy nesmie zopakovať** na inom mieste reťazca — dvojitý swap by dielec objednal v pôvodnej orientácii.
  Bežné metre ABS sú voči otočeniu **invariantné** (tá istá fyzická hrana), a to je zároveň krížová kontrola, či niekde druhý swap nevznikol.

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
- **Chrbát:** vložený medzi boky ↔ naložený zozadu ↔ v drážke (`groove`) ↔ delený ↔ bez chrbta.

### 4.5 Čistý priestor a rozhrania

Korpus **vypočíta a nesie** (v `config`, ako cache — zdroj pravdy zostáva rozmerový config):

- **Čistý vnútorný priestor:** `available_width`, `available_height`, `available_depth` — používajú ich zóny a moduly.
- **Rozhranie pre čelá:** `front_plane` (čelná rovina), čistý čelný otvor, prekrytie bokov/hore/dole, medzery, zakázané zóny. Korpus definuje **priestor pre čelo**; konkrétny typ čela rieši modul čiel (sekcia 5).
- **Rozhranie pre podopretie:** typ (AXILO nohy / plastové nohy / plný sokel / závesný / bez), výška, odsadenia. Konkrétny produkt a počet vyberie kovania engine (sekcia 6).

---

## 5. Zóny a moduly

### 5.1 Zóna (slot)

Zóna je dátová štruktúra: rozmery (svetlé), pozícia v korpuse, stav (`free`/`occupied`), zoznam povolených modulov. Vloženie modulu = zápis do konfigurácie + rebuild — nie ručné modelovanie. Presne ArchiWood/CabMaker princíp (ktorý DC nepoužíva).

> **Entity `kind: module` neexistujú.** Police žijú ako počet `shelves` priamo na zóne a čelá ako config `fronts` na korpuse.
> Config ghost zóny preto nesie aj kľúč `shelves`, `state` sa odvodzuje z počtu políc a `modules` je vždy prázdne pole.
> Pole `modules` sa naplní až vtedy, keď skutočné moduly (zásuvkové bloky) vzniknú — dovtedy je to rezervované miesto v kontrakte, nie chýbajúce dáta.

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

Čelá nie sú len „dvere". Zahŕňajú: jednokrídlové/dvojkrídlové dvierka, zásuvkové čelá, výklopy, posuvné čelá, pevné krycie panely, falošné čelá, rámové a bezúchytkové riešenia.
Čelný modul rieši: typ, počet, delenie, medzery, prekrytie korpusu, materiál, ABS, smer otvárania, úchytky, požiadavky na kovanie.
**Geometria čela, spôsob otvárania a konkrétne kovanie sú oddelené.**

**Delenie na výšku: FIXNÉ + AUTO s lockmi** (Blum-konfigurátor princíp). Jedno čelo zamknem na fixnú výšku, ostatné sa dopočítajú automaticky zo zvyšku po odčítaní zamknutých + škár. Kanonický config (tak ho ukladá `Fronts.normalize_config` — pole sa volá **`items`**, poradie odspodu, F1 dole):

```json
{
  "split_axis": "height",
  "gap": 3.0, "gap_top": 2.0, "gap_bottom": 2.0, "gap_sides": 2.0,
  "items": [
    { "id": "F1", "type": "drawer_front", "mode": "fixed", "height": 140.0, "locked": true, "wings": 1 },
    { "id": "F2", "type": "door", "mode": "auto", "height": null, "locked": false, "wings": "auto" },
    { "id": "F3", "type": "door", "mode": "auto", "height": null, "locked": false, "wings": "auto" }
  ]
}
```

`auto` čelá si rovnomerne rozdelia zvyšnú výšku; `wings: "auto"` = 2 krídla nad 600 mm šírky otvoru.
**Škáry sú konfigurovateľné** (`gap` medzi čelami, `gap_top`/`gap_bottom`/`gap_sides` po obvode).
Prekrytie korpusu (`overlay`) ani odlišná škára medzi krídlami (`gap_between`) v konfigurácii čiel **nie sú** — prekrytie určuje typ pántu, preto patria k budúcej práci na kovaní (viď 6.2; zaradenie určí PLAN).

`items[].type` nadobúda `door` · `drawer_front` · `none` (D-18 „Bez čela"): riadok `none` drží výšku v rade presne ako čelo (fixed/auto/lock, rovnaká matematika),
ale panel sa negeneruje = otvorená nika v rade čiel.
Medzery voči susedom ostávajú ako pri skutočnom čele (reálny otvor je opticky väčší o susedné škáry — vedomé rozhodnutie); `wings` je pre `none` neutrálne 1.
Bez dielca nevzniká kovanie ani položka kusovníka/VEPO.
**POZOR:** štruktúrovaný `items[].type: "none"` ≠ legacy STRING config `fronts: "none"` (V0.1/V0.2 — znamená žiadne čelá, normalizuje sa na prázdne `items`).

---

## 6. Kovanie

### 6.1 Katalóg oddelený od pravidiel

Dve nezávislé vrstvy (GPT debata sekcie 16–17):

- **Katalóg kovania** — konkrétne fyzické produkty (Blum Clip Top 110°, Hettich Quadro, AXILO…). Záznam: výrobca, kód, názov, kategória, rozmery, cena, dodávateľ, kompatibilita, prípadne 3D. Prevezme sa z KOVANIE (CatalogStore, search, Demos import).
- **Pravidlá kovania (rules engine)** — rozhodujú, **aký typ a koľko kusov**. Konkrétne kovanie **nikdy natvrdo v definícii korpusu.**

### 6.2 Two-phase: generický flag → katalógový kód

**Fáza 1 — generický flag z pravidiel.** Pri stavbe/prestavbe korpusu plánovač pridelí generické položky (`hinge`, `slide`, `leg`…) s množstvom z pravidiel v JSON;
vykonateľná podoba pravidiel je `core/hardware_rules.rb`. Žiadny univerzálny výpočtový jazyk — malý katalóg Ruby **vzorov (`kind`)** parametrizovaných JSON pravidlami:
`fixed` (pevný počet), `bands` (pásma podľa vstupu, max vrátane), `fit_series` (najväčšia hodnota radu ≤ vstup − rezerva; výsledok v `params.nominal_length`).
Príklad (počet závesov podľa výšky krídla):

```json
{
  "rule_id": "zavesy-podla-vysky",
  "enabled": true,
  "applies_to": { "role": "front_door" },
  "output": "hinge",
  "kind": "bands",
  "input": "height",
  "bands": [
    { "max": 900,  "quantity": 2 },
    { "max": 1400, "quantity": 3 },
    { "max": 1900, "quantity": 4 },
    { "max": null, "quantity": 5 }
  ]
}
```

Pravidlá sú **JSON dáta editovateľné cez sekciu Pravidlá v Štúdiu** (nie ručne v súbore). Michal si počty závesov / výnimky mení bez programovania.

**Tvar pravidla je KONTRAKT pri ULOŽENÍ (ŠT-3b-2c1).** Zapísať sa smú len pravidlá, ktoré vedia rozhodnúť pre **každý** rozmer:

- pravidlo `kind: "bands"` so `enabled != false` musí mať **neprázdne pásma a medzi nimi pásmo „všetko nad" (`max: null`)** — bez neho rozmer nad posledným pásmom nespadne do žiadneho a položka pre takú skrinku nevznikne;
- pravidlo `kind: "fit_series"` so `enabled != false` musí mať **neprázdny rad `series`** — automat nemá z čoho vybrať (dôsledok: ručný zámok NL nad prázdnym radom už nemá ako vzniknúť);
- **vypnuté pravidlo sa nekontroluje** (negeneruje nič) a **neznámy `kind`** z novšej verzie uloženie **neblokuje** (forward-compat: neznáme kľúče sa zachovávajú).

Bránu drží **jedna čistá funkcia `HardwareRules.rules_problems`**, volaná **výhradne v zapisovacej ceste** (`RulesDialog.handle_save`, až PO `normalize_rules` — validuje sa presne to, čo sa zapíše).
**Čítacie cesty ostávajú nedotknuté:** `normalize_rules`, `load`, `project_rules`, `evaluate`, seed-merge ani `ensure_project_rules!` validáciu nevolajú —
starší (deravý) snapshot v .skp sa **musí dať načítať a postaviť**, len sa nedá znova uložiť bez opravy.
Klientska `rdValidate` je zrkadlo tých istých kritérií; zhodu stráži spoločná fixtúra `tests/fixtures/rules_validation_parity.json` (číta ju Ruby aj JS sada).
Nekompletný tvar **nie je tichý** — kusovník hlási `hardware_rule_skipped` a Kontrola ORANGE;
brána existuje preto, že odmietnuť ho **raz pri uložení** je lacnejšie než ho riešiť na každej skrinke zákazky.
**Žiadne automatické doplnenie catch-all** — plugin nedomýšľa počty za stolára.

**Zdroje pravidiel a reprodukovateľnosť:** rebuild číta výhradne **projektový snapshot** pravidiel (`NOXUN` dict na modeli, kľúč `hardware_rules`) —
stavba je reprodukovateľná zo samotného .skp (iné PC, zmeny globálu, kópie skriniek) a undo vracia pravidlá aj geometriu naraz.
Globálna knižnica `%APPDATA%\NOXUN\Engine\hardware_rules.json` je len default pre nové projekty (so seed-merge novej verzie seedov podľa `rule_id`).

**Položka kovania v pláne** (BuildPlan schema 2, string kľúče kvôli JSON round-trip): `owner_part_key` (nil = korpus; inak musí existovať v parts), `generic_type` (slovník),
`quantity` (1–999), `rule_id`, `variant_id` (nil vo fáze 1), `production_class: "counted"`, `manufactured: true`, `params` (napr. výška nohy, NL výsuvu),
`source` (`rule`/`manual`), `rule_quantity`. Voliteľne `rule_nominal_length` (viď nižšie).
**Ručné zásahy** žijú v configu korpusu ako `hardware_overrides` — identita zásahu = trojica **(owner_part_key, generic_type, rule_id)**;
`quantity` prepíše počet, `disabled` položku vyradí, `nominal_length` prepíše dĺžku; šablóny korpusov zásahy zachovávajú.

**Ručná nominálna dĺžka výsuvu (D-93, V0.5.61).** Pole `nominal_length` v zázname `hardware_overrides` (Float mm > 0) je **zámok**: samotná **existencia platného poľa** znamená „drží sa ručná hodnota", žiadny ďalší príznak neexistuje. Pravidlá kontraktu:

- **Polia záznamu sú nezávislé** — jeden záznam môže niesť `quantity`, `disabled` aj `nominal_length` naraz. Zápisové cesty pracujú **po poliach** (nastav/zruš jedno pole), záznam zaniká až keď je prázdny; `disabled` naďalej víťazí nad všetkým, ale ostatné polia už **nezahadzuje**.
- Položka po zámku nesie `params.nominal_length` = ručná hodnota, `source: "manual"` a **`rule_nominal_length`** = hodnota, ktorú by dal automat. Kľúč existuje **len** pri ručnej dĺžke; `null` = automat nevie (do svetlej hĺbky sa nezmestí žiadna dĺžka radu).
- **Pravidlo `fit_series` emituje položku aj vtedy, keď automat nevyberie nič**, pokiaľ zámok existuje — inak by ručná dĺžka pri zmenšení hĺbky ticho zmizla. Nezmestiteľná ručná dĺžka = ORANGE build warning `hardware_manual_no_fit` (nikdy neblokuje).
- **Zapisovať sa smie len hodnota z aktuálneho radu pravidla** (presná zhoda, projektový snapshot). Už uložená hodnota mimo radu (rad sa medzitým upravil) sa **nikdy nemaže** — zobrazí sa ako „(mimo radu)" a odomknúť sa dá vždy.
- **Nákupný CSV kontrakt sa nemení.** Znamienko ručného zásahu žije v UI: nákupný riadok nesie `manual_quantity` + hotový slovenský text `manual_note`,
  breakdown v kusovníku `rule_nominal_length` + `manual_note`.

**Fáza 2 — mapovanie na konkrétny katalógový kód.** Na konci projektu (alebo raz v nastaveniach) sa flag `hinge` namapuje na konkrétny kód (`Blum 71B3550`). **Mapovanie sa ukladá a nabudúce prebehne automaticky.**

**Prekrytie čiel (`overlay`) určí typ pántu — dnes neimplementované, pribudne s budúcou prácou na kovaní (zaradenie do bloku určí PLAN).** Dovtedy ho konfigurácia čiel nenesie (5.3): prekrytie korpusu je dôsledok zvoleného kovania,
nie samostatné nastavenie čela, a rovnakou cestou príde aj odlišná škára medzi krídlami (`gap_between`).

### 6.3 Fyzická reprezentácia: 1 generický objekt + virtuálne varianty

- V modeli je **najviac 1 generický fyzický objekt na kategóriu** (`hinge`, `slide`, `leg`) — slúži na vizuál, pozíciu a ako základ budúcich vylepšení.
- Na generický objekt sa viaže **ľubovoľne veľa virtuálnych variantov** (konkrétni výrobcovia/kódy) — **čisto dátovo** v katalógu, bez ďalšej geometrie.
- Skrutky/spojky = čisto virtuálne (žiadna geometria).

**Generický objekt = vizuálna PROXY:** entita nesie `kind: hardware`, ale `production_class: "none"` a `manufactured: false` (+ `config.proxy: true`).
**Zdroj pravdy súpisu kovania je výhradne `config.hardware[]` korpusu** — závesy a výsuvy geometriu nemajú vôbec, takže počty musia mať jeden domov;
keby proxy niesla `counted/true`, kusovník iterujúci entity by kategórie s vizuálom započítal druhýkrát.
(Príklad `counted/true` entity v 8.2 je **rezervovaný tvar** pre samostatné hardware entity bez proxy vzťahu — proxy ňou nikdy nie je.
Dnes ju **nič nevytvára a zberná cesta `Bom.collect` ju nepozná** (zbiera top-level `cabinet` a `board`, kovanie berie výhradne z `config.hardware[]`),
takže kým sa zber nedoplní, taká entita by sa do výstupov nedostala.)

**Vŕtanie a presné pozície kovania sú MIMO scope V1** — riešia sa len počty, typy a kódy.

---

## 7. Materiály a ABS

### 7.1 Materiálový katalóg — rodina vs. variant

Materiál nie je SketchUp textúra. Je to katalógový záznam. Rozlišujeme (SCHEMA 2 — dávka 2A, 30.7.2026):

- **Skupina (dekor)** — **identita skupiny = výrobca + číslo dekoru** (Kronospan·K009, Egger·H1180); `decor_name` („Dub Halifax prírodný") je len ZOBRAZOVACIA vlastnosť skupiny —
  jej oprava/preklad identitu nemení. Interná kotva skupiny je stabilné **`group_id`** — nesú ho dosky AJ ABS pásky
  (výrobca je len na skupine; samotné číslo nestačí — rovnaké číslo dvoch výrobcov sú dve rôzne skupiny).
  Pre vlastné/neznačkové materiály je „číslo" ľubovoľný názov („Biela korpus").
- **Variant** — samostatný výrobný materiál a samostatný kusovník. **Identita variantu dosky = skupina + typ + hrúbka + štruktúra povrchu**
  (`structure` — ST9, PW, FP, MG…; voliteľná, trimovaná, porovnávaná case-insensitive s normalizovanými medzerami).
  **Pre typ PD navyše formát** (`sheet_size` ako usporiadaná dvojica dĺžka×šírka) — F800 PD 38 4100×600 a 4100×920 sú dva varianty.
  `K009/DTDL/18/PW` a `K009/DTDL/16/PW` sú dva varianty; `5981/DTDL/18/MG` a `5981/DTDL/18/BS` tiež (rovnaké rozmery, iný povrch).
- **Typ** — dvojvrstvový: **kanonické typy** (DTDL · MDF · HDF · PD · Zástena · Kompakt) žijú v Ruby registri s parametrami
  (default formát, ponuka hrúbok, hranová logika, kandidát pre telo korpusu) + **„iný"** = voľný string s generickým správaním. Identita typu je case-insensitive.
  **Kompaktná doska = výhradne kanonický typ `Kompakt`** (nikdy „PD s podtypom kompakt" — jedno kódovanie); PD podtypy hranovej úpravy sú len **postforming | ABS rovná hrana**.

Záznam variantu:

```json
{
  "material_id": "K009_PW_DTDL_18",
  "group_id": "GRP-A1B2C3",
  "manufacturer": "Kronospan",
  "decor": "K009",
  "decor_name": "",
  "structure": "PW",
  "type": "DTDL",
  "thickness": 18.0,
  "grain": "length",
  "price_per_m2": 12.50,
  "sheet_size": [2800.0, 2070.0],
  "texture": "K009_PW.jpg",
  "production_class": "sheet",
  "code": "K009 PW 18",
  "supplier": "Demos"
}
```

Kusovník podľa materiálov sa delí podľa **material_id (variant) + hrúbka**.

**Nemennosť ID a migrácia (2A):** `material_id`/`abs_id` sú **opaque a navždy nemenné** (modely sa viažu výhradne na ne — snapshot na entite drží ID, štandard 8.3);
legacy ID s vloženou štruktúrou v texte sa NEparsujú. Nové ID zahŕňajú skupinu+štruktúru (+formát pri PD) len pre čitateľnosť.
Migrácia na SCHEMA 2 beží raz: **nemenná záloha** `materials.pre-schema-2.json` (mimo bežného `.bak`, ktorý sa prepisuje) → transformácia podľa **explicitnej mapy**
(heuristika len fallback s reportom) → atomický zápis so schema markerom.
**Čo i len jedna nerozhodnuteľná položka = atomický NO-OP celej migrácie** (katalóg sa NEnahradí ani čiastočne — žiadny hybridný stav; report vypíše, čo treba rozhodnúť);
mutácie zo starých okien server po migrácii odmieta (`catalog_schema` v payloade).

**Daňový základ cien (ZMENA 31.7.2026, Michal — ruší rozhodnutie z 29.7.):**
katalóg eviduje ceny **S DPH, presne ako ich zobrazuje Demos** (90 % zdrojov);
výsledný výpočet/ponuka má **prepínač „s DPH / bez DPH"** (÷ aktuálna sadzba
1,23 na zobrazenie). Zdroj bez DPH (historický VEPO cenník) sa pri vstupe
prepočíta ×1,23. Ceny sú **pohyblivá cache** — katalóg drží väzbu na produkt
(kód + URL) a „poslednú známu cenu + dátum overenia"; autorita pre ponuku je
„Prepočítať ceny" (živý fetch, dávka E). Existujúce ručne zadané ceny
testovacieho katalógu sa pri seede 2.0 preveria/nahradia — tax-basis marker sa
nezavádza (jednotný základ = s DPH).

**Boot cutover (2A-4b):** migráciu spúšťa **každý štart SketchUpu** (`Materials.boot_cutover!` z main.rb vo vlastnom chránenom bloku — zlyhanie nikdy nezhodí inicializáciu;
žiadny modálny dialóg, výsledok ide do logu a stav ukazuje sekcia Materiály v Štúdiu).
Poradie: jednorazový **hold flag** `migration_hold.json` (zapisuje ho rollback `restore_pre_schema2!`) sa skonzumuje a migrácia sa RAZ preskočí (ďalší štart už migruje normálne) →
posúdenie katalógu (obnova primáru z `.bak`; poškodený/hybridný/novší katalóg = **read-only režim** mutácií do opravy) →
marker < 2 = ostrá migrácia (`:undecidable` = katalóg beží ďalej legacy dual-mode, mutácie sa NEzamykajú).
Čerstvá inštalácia sa **seeduje natívne v SCHEMA 2** (nikdy nemigruje).

**Dodávateľské polia (D-42):** `code` (dodávateľský/katalógový kód) a `supplier`
(jeden **preferovaný** dodávateľ — vedomé rozhodnutie, žiadne pole ponúk) sú
**voliteľné** na doske aj ABS. Nie sú súčasťou variant identity ani interného ID
(modely sa viažu výhradne cez `material_id`/`abs_id`); kľúč sa ukladá len keď má
hodnotu (trim; prázdna hodnota pole odstráni). Duplicitný pár kód+dodávateľ v tom
istom druhu záznamu sa nezapíše potichu — vyžaduje explicitné potvrdenie. Kód je
hľadateľný (dekor nájde zhoda kódu ktoréhokoľvek jeho variantu). `manufacturer`
(výrobca dekoru) je **vlastnosť skupiny** — mení sa atomicky pre celý dekor, nie
per variant.

**Cena (D-42):** chýbajúci kľúč `price_per_m2`/`price_per_bm` = **„nezadaná"** —
odlišný stav od explicitnej `0.0`. Hromadné vytváranie cenu neukladá (doplní sa
v katalógu); nečíselný vstup sa odmieta (nikdy tichá 0 z `to_f`). Cenová ponuka
má na nezadané ceny upozorniť, nie ich rátať ako nulu.

**Duplák (D-43, dávka 2B-1 — SCHEMA 3):** variant dosky „zdvojený zo zdroja"
(36 = 2× zlepená 18). Vlastné vstupy sú **výhradne** `source_material_id`
(doska TEJ ISTEJ skupiny, sama nesmie byť duplák — žiadne reťazenie) a
`source_multiplier` (Integer 2–3); **všetko ostatné sa KOPÍRUJE zo zdroja**
(typ, štruktúra, grain, farba, formát platne; hrúbka = násobič × hrúbka
zdroja) a na dupláku je **nemenné** — edit zdroja propaguje zdieľané
editovateľné polia (formát non-PD, grain, farba) na jeho dupláky v jednom
atomickom zápise. Duplák **nenesie nákupné polia** (`code`/`supplier`/cena) —
kupuje sa zdroj; kupovaná hotová doska väčšej hrúbky s vlastným DK kódom je
bežný variant, nie duplák. Zdroj dupláku sa nesmie zmazať (guard pod zámkom).
Väzba je súčasťou **výrobného snapshotu** na dielci/doske
(`config.material_source = {material_id, multiplier}` — zapisujú buildery,
validuje `BuildPlan.validate_material_source!` tesne pred zápisom; rebuild na
stroji s katalógom bez dupláku vazbu z predošlého snapshotu zachová). Odhad
platní prelieva plochu dupláku ×násobič do **zdrojového** materiálu
(`doubled_m2`/`doubled_quantity` na zdrojovom riadku; duplák vlastný riadok
nákupu nemá); kusovník a VEPO ostávajú bez zmeny (dielec 1× s hrúbkou 36).
**Marker SCHEMA 3 sa dvíha LAZY** — prvým zápisom katalógu s duplák záznamom;
staršie verzie pluginu katalóg s marker 3 čítajú, ale mutácie odmietnu
(write backstop + assess read-only), inak by väzby ticho zahodili.

**Zástena — obojstranný dekor (dávka 2B-2 — SCHEMA 4):** variant kanonického
typu `Zástena` nesie voliteľný **rub** (`back_decor` = číslo dekoru rubovej
strany + voliteľná `back_structure`) — obojstranný dekor je štandard sortimentu
(Demos „Zástena K551/K552"), výrobca rubu = výrobca skupiny. Rub je **súčasť
identity variantu** (K551/K552 a K551/K553 sú dve položky) a po vyplnení je
nemenný; ukladá sa ako normalizovaný text BEZ väzby na inú skupinu (rub sa
výrobne nepoužíva — model, kusovník aj VEPO idú cez primárny variant; rub je
objednávková informácia a ide do VEPO labelu). Štruktúra rubu bez čísla rubu
sa odmieta; back polia na inom type než zástena tiež. **Formát platne je
súčasťou identity aj pre zástenu** (4100×640 a 4200×640 koexistujú) — riadi to
register flag `format_in_identity` (PD + Zástena, jeden helper na všetkých
identity miestach; nové varianty týchto typov formát VYŽADUJÚ). **First-fill:**
PRÁZDNE identity pole (formát/rub) na existujúcom zázname sa smie doplniť
jednorazovo (s duplicitnou kontrolou novej identity) — legacy záznamy spred
2B-2 sa inak nedajú skompletizovať; vyplnené hodnoty sú nemenné. **Marker
SCHEMA 4 sa dvíha LAZY** prvým zápisom záznamu s rubom (centrálne v zápisovej
ceste podľa OBSAHU — rovnako marker 3 pri duplák väzbe).

**Dekorová skupina (D-41 → SCHEMA 2 v 2A):** dosky a ABS pásky viaže do skupiny
**`group_id`** (stabilný interný identifikátor; obchodná identita skupiny = výrobca +
číslo dekoru + názov). Pravidlá:

- Väzba beží cez `group_id` — nikdy cez textovú zhodu názvov; polia skupiny
  (`manufacturer`, `decor`, `decor_name`) sa menia **atomicky pre celú skupinu**.
- **Kanonické identity helpery:** `group_identity_key` / `sheet_identity_key` /
  `edge_identity_key` sú JEDINÁ normalizácia (trim, case-insensitive, zrazené viacnásobné
  medzery, hrúbky round(2)) používaná create/edit/batch/rename/migráciou — žiadne lokálne
  porovnávania s vlastnou toleranciou.
- **Near-match guard:** nová skupina, ktorá sa od existujúcej líši len veľkosťou písmen
  alebo medzerami, sa odmietne s návrhom presného tvaru (preklep nesmie rozbiť skupinu).
- **Identita variantu je pri edite nemenná** (typ, hrúbka, štruktúra; **pri PD aj formát**)
  — iná hodnota = nový variant, žiadne in-place zmeny identity polí. (Formát NEPD typov
  identitou nie je a ostáva editovateľný ceruzkou ako doteraz.)
- **Duplicitné variant identity sú zakázané** (sheet: skupina+typ+hrúbka+štruktúra, PD
  +formát; ABS: skupina+šírka+hrúbka+štruktúra) — create, rename aj migrácia ich odmietnu.

### 7.2 Materiálové dedenie

```
projektový default → skrinka dedí → modul dedí → konkrétny dielec override
```

Napr.: projekt `K009_PW_DTDL_18` → korpus zdedí → police zdedia → jedna polica ručný override na iný dekor/hrúbku.

#### `part_overrides` — vrstva ručných zásahov na dielci korpusu (ZÁVÄZNÝ TVAR)

Žije v configu **korpusu** pod `part_overrides`, kľúčom je `part_key` (2.3). Doska (`kind: board`) túto vrstvu **nemá** — jej config je priamo zdroj pravdy (8.3).

```json
"part_overrides": {
  "front:F1/wing:single": {
    "material_id": "K009_PW_DTDL_18",
    "grain_direction": "width",
    "edges": { "L1": "ABS_K009_10", "L2": null }
  }
}
```

- **Povolené kľúče záznamu:** `material_id` · `grain_direction` · `edges` · `edge_warnings` (interné, sticky dôvody remapu ABS). Čokoľvek iné sa pri normalizácii configu **zahodí** — vrstva je uzavretý enum, nie voľný priestor.
- **Chýbajúci kľúč = DEDENIE**, nikdy „prázdna hodnota". Preto sú staré modely bez `grain_direction` platné a ich otvorenie **nesmie nič zapísať, nič prestavať a nesmie vyrobiť krok Späť**.
- **`grain_direction` (K1 / D-108, v0.7.23):** povolené hodnoty overridu sú **len `"length"` a `"width"`**. `"none"` sa nenastavuje — „bez smeru" je vlastnosť materiálu, nie rozhodnutie o dielci. **Neznáma hodnota sa odmietne** (zápisová cesta vráti chybu, čítacia ju zahodí) — nikdy tichý fallback, výrobné dáta by klamali o tom, čo používateľ zvolil.
- **Efektívny smer = `override || materiál`, s jedinou výnimkou:** keď materiál dielca smer **nemá** (`grain: "none"` — jednofarebný dekor, UNI, materiál mimo katalógu),
  override sa **IGNORUJE** (výsledok `"none"`), ale **NEMAŽE sa**. Otáčať kresbu, ktorá neexistuje, by bola lož;
  zmazanie by pri dočasnej zmene materiálu zahodilo rozhodnutie používateľa. Po návrate dekorového materiálu override znovu platí.
- **Výsledok sa materializuje RAZ** — pri stavbe do snapshotu dielca (8.2/8.3). Výstupy (kusovník, VEPO, kontrola nárezu, ABS) čítajú **výhradne snapshot**, nikdy živý katalóg ani `part_overrides`; preto odpojený dielec aj stará zákazka nesú presne to, s čím sa objednávali.

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
"edges": { "L1": "ABS_K009_10", "L2": null, "W1": "ABS_K009_10", "W2": "ABS_K009_10" }
```

- Hodnota strany = `null` (bez hrany) alebo **ABS variant ID** (opaque, navždy nemenné —
  legacy formáty `ABS_K009_10`, `ABS_U702_ST9_22X10` ostávajú platné bez parsovania).
- **Obchodné hrúbky ABS (2A):** povolené sú reálne hodnoty **{0,4 · 0,8 · 1,0 · 1,2 ·
  1,5 · 2,0} mm** (koniec nominálov 1/2-only). Pravidlá rolí ostávajú NOMINÁLNE
  („jednotka"/„dvojka"); **resolver obchodnej hrúbky** ich prekladá na dostupné pásky
  skupiny: jednotka = 0,8 → 1,0 → 1,2 (podľa toho, čo dekor má — lesklé MG majú len 1,0);
  dvojka = 2,0 (→ 1,5 s viditeľným upozornením). **0,4 sa nikdy nevyberá automaticky.**
  **Remap 0,4 (2A-3):** pri zmene materiálu sa ručná 0,4 páska **nikdy nenahrádza
  automaticky** — hrana ide na „bez ABS" a hlási sa ako stratená s dôvodom
  `abs_04_manual` (používateľ vyberie novú pásku vedome).
- **Šírka pásky (D-41):** voliteľné pole `width` (mm, 10–200); auto-šírky {23, 43}.
  Výber šírky (deterministický, tie-break `abs_id`): najmenšia šírka ≥ hrúbka dielca +
  2 mm → univerzálna → žiadna (**nikdy užšia páska než dielec**).
- **Štruktúra povrchu (2A):** `structure` je súčasť identity ABS variantu (5981 má DVE
  rôzne 23/1 pásky — MG vs UM/AF). Picker pásky **NIKDY neprechádza cez štruktúry
  automaticky**: presná zhoda NEPRÁZDNEJ štruktúry s doskou (**dve prázdne štruktúry sa
  ako presná zhoda NIKDY nepočítajú** — prázdna = neznáma, nie „rovnaká") → páska
  s explicitným príznakom **`universal: true`** (vedomé „pasuje na všetko"; jediná cesta
  pre pásky bez štruktúry) → žiadna páska + upozornenie semaforu.
- **Nominálne defaulty rolí:** pravidlá rolí žiadajú TRIEDU („jednotka"/„dvojka"), nie
  konkrétnu hodnotu — všade, kde staršie znenie tohto dokumentu uvádza „1,0 mm" ako
  default (vrátane kontraktu voľnej dosky §8.x), sa tým odteraz myslí trieda „jednotka"
  rozriešená resolverom na dostupnú pásku skupiny. `ensure_edge_for_sheet` (dovytvorenie
  chýbajúcej pásky) tvorí zo štandardných šírok AUTO_WIDTHS {23, 43} a hrúbku volí
  rovnakým resolverom (0,8 → 1,0 → 1,2; nikdy 0,4). Pri doske **bez štruktúry** dostáva
  dovytvorená páska **`universal: true`** (v skupine bez štruktúr je to jediná cesta k jej
  použiteľnosti — „vedomosť" príznaku nesie modal potvrdený používateľom); doska so
  štruktúrou štruktúru dedí a universal sa nenastavuje (2A-3b).
- Identita ABS variantu (skupina+šírka+hrúbka+štruktúra) je pri edite nemenná.
  Pre VEPO je šírka nepodstatná (hotové rozmery) — význam má pre kusovník a cenovú ponuku.
- **Dodávateľské polia a cena (D-42):** ABS páska nesie voliteľné `code` + `supplier`
  a cenu `price_per_bm` s rovnakou sémantikou ako doska (7.1): chýbajúca cena =
  „nezadaná" ≠ 0; kód+dodávateľ nie sú identita variantu; duplicitný pár vyžaduje
  potvrdenie. ABS nemá výrobcu (výrobca je vlastnosť dekorovej skupiny cez dosky).
- `L1`/`L2` = dvojica pozdĺžnych strán, `W1`/`W2` = dvojica priečnych.
- **UI ich prekladá** na predná/zadná/ľavá/pravá. Interný systém je odolný voči otočeniu skrinky — hrany sa držia per strana, súhrnné kódy (`—`/`=`) sa **dopočítajú až pri exporte** (VEPO nevie povedať KTORÁ strana, kusovník a CNC to potrebujú presne).

**Pravidlové defaulty podľa roly dielca** + výnimky + ručný override:

- Čelo: hranovanie dookola. Polica: len predná. Chrbát v drážke: nič.
- Výnimky pravidlami: hrúbka < prah → nič; rola v zozname výnimiek → nič.
- Ručný override per dielec vždy víťazí.

Vykonateľná podoba pravidiel ABS (defaulty rolí, resolver obchodnej hrúbky, picker šírky): [`core/abs_rules.rb`](../noxun_engine/core/abs_rules.rb).

> **Priradenie strán L1/L2/W1/W2 na plochy kvádra dielca sa NIKDY neodvodzuje z hodnôt rozmerov** (dva rovnaké rozmery sú nerozhodnuteľné) — je to explicitný údaj deskriptora
> `axes: { length:, width:, thickness: }`, ktorý zapisuje ten, kto box stavia. Keď osi chýbajú alebo nesedia s rozmermi, mapovanie sa **neháda** (radšej žiadna farba než farba na zlej hrane).
> **Vedomá legacy výnimka (D-104):** deskriptor s osami žije len v pláne, na entite uložený nie je — kontrola olepov nad **už postavenou** zákazkou preto osi odvodí
> z **ROLY** dielca a overí ich proti skutočnému kvádru; platí **výhradne jednoznačná zhoda** (nula alebo dve zhody = `nil` a dielec sa nezvýrazní), takže to nie je
> zakázané hádanie z hodnôt rozmerov. Vykonateľná podoba kontraktu: [`noxun_engine/core/part_faces.rb`](../noxun_engine/core/part_faces.rb).

### 7.6 ABS vizuálny režim (samostatný modul)

Samostatný režim na vizuálnu kontrolu hrán:

- Dielce polopriehľadné (~30–50 % opacity), ABS hrany plné a **farebne podľa hrúbky** (napr. 1,0 mm červená, 2,0 mm zelená, bez ABS sivá).
- **Konfliktné / neurčené hrany oranžové.**
- Klik na hranu = zmena ABS. Farby používateľsky nastaviteľné.
- Filtre: všetky hrany / iba vybraný typ / iba chyby / iba vybraná skrinka. Master korpus dá základné pravidlá, ABS editor je finálna kontrolná vrstva.

---

## 8. Výrobné triedy a dátový model dielca

### 8.1 Výrobné triedy

Výrobný stav je **explicitne v metadátach** (`production_class` + `manufactured`), nie podľa typu SketchUp entity. **Group sa štandardne nepočíta** (dekorácie, spotrebiče, pomocná geometria).

| Trieda | Čo meria | Príklady |
|---|---|---|
| `sheet` | dĺžka × šírka × hrúbka + ABS | DTDL, MDF, preglejka, kompakt, sklo, plech |
| `linear` | **výrobná dĺžka z KONFIGURÁCIE** (nie z najdlhšej hrany geometrie) | Gola profily, LED, soklové lišty, tyče |
| `counted` | kus (produkt + kód + množstvo) | pánty, nohy, výsuvy, úchytky, spojky |
| `reference` | nepočíta sa | spotrebiče, dekorácie, miestnosť, vizuál |
| `none` | pomocná/servisná geometria enginu — nikdy sa nepočíta ani nereportuje | ghost boxy zón (`kind: zone`) |

**Kritické pri `linear`:** dĺžka sa berie z `config.length`, ktoré nastavil engine — nie automaticky z najdlhšej hrany bboxu.

### 8.2 Plný dátový model dielca (sheet)

Podľa sekcie 2.1: **ploché kľúče = identita, názov a filtre; všetko rozmerové a výrobné žije v `config` (JSON string)** — tak to ukladá aj engine (`NOXUN/config`). Exportéry čítajú rozmery VÝHRADNE z `config`; názov dielca z plochého kľúča `name`.

> **Vykonateľná podoba kontraktu:** tvar plánu stavby — deskriptor dielca, `warnings[]`, `hardware[]`, verzia schémy a validátor — je záväzne definovaný v kóde:
> [`noxun_engine/core/build_plan.rb`](../noxun_engine/core/build_plan.rb) (`BuildPlan.validate!` beží pri každom pláne).
> Pri rozpore detailov platí kód + jeho testy (`tests/pure/test_build_plan.rb`); tento dokument drží princípy.

```json
{
  "std": 1,
  "kind": "part",
  "id": "CAB-014-SIDE-L",
  "part_id": "CAB-014-SIDE-L",
  "part_key_schema": 1,
  "part_key": "cabinet/side:left",
  "role_key": "cabinet/side:left",
  "cabinet_id": "CAB-014",
  "template_id": "base-lower-18",
  "role": "side_left",
  "name": "Bok ľavý",
  "manufactured": true,
  "production_class": "sheet",
  "config": {
    "quantity": 1,
    "length": 720.0,
    "width": 560.0,
    "thickness": 18.0,
    "material_id": "K009_PW_DTDL_18",
    "grain_direction": "length",
    "edges": {
      "L1": "ABS_K009_10",
      "L2": null,
      "W1": "ABS_K009_10",
      "W2": "ABS_K009_10"
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

### 8.3 Samostatná doska (`kind: board`) — V0.4.7

Samostatný výrobný dielec **bez korpusu** (krycia doska, blenda, výplň, atypický prírez).
Top-level ComponentInstance s vlastnou definíciou (`NOXUN Doska BRD-001`), identita `BRD-001` (sekvencia ako CAB), `part_key` konštantne `board/main` (owner-scope, viď 2.3).
Na rozdiel od korpusu (`reference`/`manufactured: false` — kontajner) je doska **priamo výrobná položka**: `manufactured: true`, `production_class: sheet`.

```json
{
  "std": 1,
  "kind": "board",
  "id": "BRD-001",
  "part_id": "BRD-001",
  "part_key_schema": 1,
  "part_key": "board/main",
  "role": "free_panel",
  "name": "Krycia doska ľavá",
  "manufactured": true,
  "production_class": "sheet",
  "config": {
    "engine_version": "0.5.0",
    "name": "Krycia doska ľavá",
    "role": "free_panel",
    "quantity": 1,
    "length": 720.0,
    "width": 580.0,
    "thickness": 18.0,
    "material_id": "K009_PW_DTDL_18",
    "grain_direction": "length",
    "edges": { "L1": "ABS_K009_10", "L2": null, "W1": null, "W2": null },
    "orientation": "leziaca"
  }
}
```

Záväzné princípy dosky:

- **Config dosky = superset configu dielca korpusu** — rovnaké výrobné polia (`quantity`/`length`/`width`/`thickness`/`material_id`/`grain_direction`/`edges`), navyše `engine_version`/`name`/`role` pre round-trip editácie a `orientation` pre umiestnenie (nižšie). Výstupy čítajú názov a rolu z **plochých** kľúčov (2.1), nie z configu.
- **`orientation` je údaj UMIESTNENIA, nie výrobný údaj** (UI-C1c). Enum: `"leziaca"` (default) · `"stojaca"` · `"na_stenu"`.
  **Chýbajúci alebo prázdny kľúč = `"leziaca"`** (dosky vložené pred zavedením poľa sú platné a nemenia sa);
  **explicitná neznáma hodnota je CHYBA** — builder ju odmietne rovnako ako neznámu rolu, žiadna tichá preklasifikácia
  (config z novšej verzie nesmie stratiť význam v staršom plugine).
  Realizuje sa **výhradne transformáciou inštancie** — geometria v definícii ostáva ležiaca (dĺžka X, šírka Y, hrúbka Z), takže
  **výrobné rozmery, `edges`, `grain_direction`, osi deskriptora ani agregácia kusovníka a VEPO sa orientáciou NEMENIA**
  (je to ten istý invariant ako 3.3 „rotácia nemení výrobné dáta"); do agregačného kľúča kusovníka pole **nepatrí**.
  Zmena orientácie je **delta** nad súčasnou transformáciou (`T × O_old⁻¹ × O_new`), takže ručné otočenie používateľa prežije
  a pole eviduje **len pluginom aplikovanú** orientáciu.
  `"na_stenu"` má zhodnú maticu ako `"stojaca"` — je to údaj umiestnenia so sémantikou (zadná plocha pri stene; budúce prisatie/elevácia),
  rozlišuje sa **poľom, nikdy bounding boxom**.
- **Autoritatívny výrobný záznam pre výstupy (V0.5) je snapshot na entite** — pri dielcoch korpusu ho builder zapisuje z plánu po `resolve_part` (finálny materiál/ABS), pri doskách ho zapisuje `BoardBuilder` priamo. `BuildPlan` je **plán stavby korpusu** (medzikrok) — dosky v ňom nie sú; per-dielec kontrakt (`BuildPlan.validate_part!`) je však spoločný validátor oboch.
- **Kusovník V0.5 zbiera entity `manufactured: true` jednotne** (`kind: part` aj `kind: board`) a agreguje **výhradne podľa výrobných polí** (`material_id` + rozmery + `edges` + `grain_direction`); `quantity` sa sčítava. `id`, `part_key`, `name` ani `engine_version` do agregačného kľúča nepatria.
- **Materiál dosky je snapshot** — vždy konkrétny **katalógový** záznam (predvyplnený z projektového defaultu pri vložení, žiadne živé dedenie) a **hrúbka sa riadi materiálom** (nie je voľný rozmer). Legacy výnimka „neznámy materiál smie prejsť" platí len pre staré korpusy, na dosky sa neprenáša.
- **Hrany**: `edges` je vždy kompletná mapa L1/L2/W1/W2; kľúč s `null` = vedome bez ABS. Default pri vložení: pravidlo roly `free_panel` (seed: 1 pozdĺžna hrana **triedy jednotka** — viď 7.5; rozhodnuté 26.8.2026). Doska nemá override vrstvu (`part_overrides`) — config na entite je priamo zdroj pravdy.
- **Pole `attachment` (väzba dosky na vlastníka) v configu NIE JE** — absencia poľa = voľná doska (`mode: free`). Pribudne aditívne s prvou inteligentnou rolou
  (`cover_side`…) a už teraz preň platí: vlastník sa odkazuje výhradne cez `id` (+ `part_key`), **nikdy `persistentId`**; po zmazaní vlastníka doska prežíva a degraduje na voľnú.

---

## 9. Regenerácia a životný cyklus

### 9.1 Regenerate pattern

1. načítaj konfiguráciu, 2. validuj ju, 3. odstráň generované child dielce, 4. deterministicky ich vytvor znova, 5. zachovaj podporované override a moduly, 6. ulož výslednú konfiguráciu. Celé v **jednej Undo operácii** (`start_operation` … `commit_operation`) — žiadne kumulatívne chyby, žiadny `$dc_observers`.

### 9.2 Dva režimy (V1)

- **Plne parametrický** — geometriu riadi engine; ručné geometrické úpravy sa pri regenerácii prepíšu. `config.mode = "parametric"`.
- **Odpojený** — skrinka sa zmení na bežnú SketchUp geometriu, engine ju ďalej neregeneruje. `config.mode = "detached"`. Dielce ostávajú čitateľné pre kusovník, ale strácajú parametrickosť.

Čiastočné geometrické override (parametrický korpus s ručne upraveným jedným dielcom) **nie sú vo V1** — zbytočná komplexita.

### 9.3 Kópia, rotácia, save/reopen

- **Kópia skrinky** → nové `cabinet_id`; `template_id` a `part_key` môžu zostať, pretože kľúč je scoped korpusom. Nové `part_id` sa odvodia z nového `cabinet_id`. Kópia sa dá upraviť nezávisle od originálu.
- **Kópia dosky** (`kind: board`) → nové `id` (BRD-xxx), rovnaký princíp — `part_key` `board/main` zostáva (owner-scope). Sekvenčné id (CAB aj BRD) je **unikátne medzi živými entitami**: berie sa max existujúcich + 1, po zmazaní entity s najvyšším číslom sa číslo môže použiť znova (vedomé, platí od V0.1).
- **Rotácia** v modeli **nemení** výrobné dáta (rozmery, hrany, dekor) — viď 3.3.
- **Save/reopen** — dáta žijú v `NOXUN` dictionary na inštancii, prežijú uloženie a znovuotvorenie. `persistentId` je stabilný v rámci modelu; väzby sú aj tak logické (2.3), takže reopen nič nerozbije.
- **Rebuild mení `persistentId` dielcov** → nikdy naň neviazať trvalé cudzie kľúče (kovanie, markery). Väzba na konkrétny kus = `cabinet_id` + `part_key`; väzba na kategóriu = `role`.

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
- **Rozpočet zákazky** — materiál, ABS, kovanie, **služby** (olepovanie, porez, lepenie duplákov, opracovanie PD, montáž — množstvá počíta engine z kusovníka
  a odhadu platní, ceny berie zo sadzieb dodávateľa), štandardné koncové riadky s násobkom, vlastné položky, spotrebiče a zaokrúhlenie konečnej sumy.
- **Cenová ponuka pre zákazníka** — pohľad NAD rozpočtom, nie druhý výpočet.
- **VEPO CSV** — presne podľa `VEPO_KONTRAKT.md` (stĺpce `nazov;dlzka;hrana_pozdlz;sirka;hrana_naprieč;hrubka;pocet_ks;material`, oddeľovač `;`, úvodzovky, `—`/`=` kódy hrán dopočítané z L1/L2/W1/W2, normalizácia hrúbok 18/36, slug názvy súborov `<projekt>_<material>_<hrubka>.csv`). Priamo z dielcov, **bez OCL medzikroku**.

### 11.3 Peniaze — jeden výpočet, dva pohľady

- **Autorita výpočtu je rozpočet.** Je to čistá funkcia (BOM + katalógy + stav zákazky + nastavenia dodávateľa → payload); UI ju len zobrazuje a export ju číta 1:1 —
  **žiadny klient si nič neprepočítava.** Vykonateľná podoba: [`core/budget.rb`](../noxun_engine/core/budget.rb) + sadzby a režimy [`core/supplier_settings.rb`](../noxun_engine/core/supplier_settings.rb).
- **Cenová ponuka je VIEW nad hotovým payloadom rozpočtu** — jej súčet sa **na cent rovná** súčtu rozpočtu (dorovnávací riadok „nábytková zostava" je automatický zvyšok).
  Proti interným pojmom (sadzby, €/bm, počty platní, nákupné kódy, `material_id`) stojí **trojvrstvová obrana**: do dokumentu idú len whitelistované polia
  a `clean_label` odstráni kódy a ID-podobné tokeny; hotový hárok ešte prejde blocklistom, ale ten nález **hlási a neblokuje** (rovnaký kontrakt ako KONTROLA pri VEPO).
  Ručne napísaný text s interným pojmom teda do súboru prejde a **ohlási sa v statuse okna — trvalý záznam o ňom nevzniká**.
  Vykonateľná podoba: [`core/cp_export.rb`](../noxun_engine/core/cp_export.rb).
- **Sadzby sa do zákazky NEMRAZIA** — rozpočet je pohyblivý obraz cien, nie výrobný snapshot. V modeli žijú len veci per zákazka (režim, overridy, násobky, vlastné položky); sadzby sú globálne nastavenie dodávateľa.
- **DPH sa nepripočítava.** Firma je neplatca, katalógové ceny sú konečné a prepočet „bez DPH" je len zobrazenie, nikdy základ výpočtu.
- **Neznáma cena sa NIKDY nenahradí nulou** — riadok ju prizná, medzisúčet je len zo známych cien a súhrn nahlas povie, že nie je úplný.

---

## 12. Otvorené body

Zámerne nerozhodnuté — overia sa na prototype/V1 v SketchUpe (SkAgent), nie od stola:

1. **Presné origin konvencie pre všetky typy modulov** (❓ osnova 3). Korpus, dielec a rotačné čelo sú určené (sekcia 3.2); originy zásuvkových blokov, priečok a doplnkov overiť na prototype.
2. **Správanie pri zmene rozmeru korpusu s obsadenými zónami** (❓ osnova 5): auto-prepočet detí, kedy resize zakázať/limitovať (princíp `LARGEST/SMALLEST` — min/max rozmery pre kovanie).
3. **Spájanie a zarovnávanie korpusov v zostave** (Michal, 15.7.2026): default = zarovnanie **čelných hrán** (hĺbky korpusov môžu byť rozdielne); voliteľne zarovnanie **zadných hrán**.
   Koncept jednoduchých **pripájacích bodov (kotiev)** na korpuse — vrátane špeciálnych situácií: rohová skrinka sa nepája priamo na rohový styk
   (potrebný dištančný/rohový princíp — viď foto reálnej kuchyne). Existujúca logika prisúvania v `snaper` (compute_gap v lokálnom ráme cieľa) je kandidát na prevzatie.
   Rieši sa na reálnych zostavách — postrehy budú jasnejšie z klikania.

### Mimo scope štandardu v1 (nie „otvorené" — zámerne vynechané)

Vŕtacie pozície a CNC rastre kovania • nesting / nárezové plány • automatické výkresy • cloud • rohové a atypické korpusy • šikmé/zakrivené dielce • kompletný kuchynský CAD.
K týmto sa systém dostane, až keď jadro (štandard → referenčný korpus → childy → kovania → výstupy) stojí a je overené.
