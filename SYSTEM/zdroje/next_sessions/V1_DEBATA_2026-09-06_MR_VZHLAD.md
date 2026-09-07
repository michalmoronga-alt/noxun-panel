# V1 debata · bod 7b M-R VZHĽAD — textúry, mierka, PBR, orientácia, .skm (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: ČIASTOČNE (API SketchUp 26.0.429
> overené probe cez MCP: `Material#save_as`/`write_thumbnail`, `Materials#load`, `Texture#size=`, PBR polia, `Face#position_material`; builder maľuje inštanciu + ABS plochy) ·
> **NAHRÁDZA package „M-R FOTO"** v [../../PLAN.md](../../PLAN.md) blok 5 (Demos fotka ako textúra) — Michal 6.9.: „celkovo by som to prekopal". Task packages MR-1..MR-3 vzniknú
> z tohto checkpointu po `codex-audit` (MR-1 kontrakt katalógu, MR-3 buildery).
>
> Pred implementáciou platí postup z [README.md](README.md). Nadväzuje na koncept [06_RENDER_MR.md](06_RENDER_MR.md) — tento dokument ho **rozhoduje** pre V1.

## 0 · Rozhodnutia (Michal 6.9.)

| Téma | Rozhodnutie | V1? |
|---|---|---|
| M-R ostáva vo V1 | áno, poradie je jedno (plugin je v pilotnej fáze, knižnice sa rozširujú až po V1) — návrh Fable: **prvá dávka po KOVANÍ** | **ÁNO** |
| Zdroj textúr | **ručne** z Michalovej knižnice `E:\NOXUN\.MATERIÁLY` (98 položiek, podpriečinky EGGER · KRONO SPAN · KASTAMONAU · DLAŽBA · TAPETY …, rozlíšenia 280 px až 1600 px) — **žiadna Demos automatika** (malý Demos obrázok ostáva len na dlaždici, kým ho nenahradí náhľad z .skm) | ÁNO |
| Rozsah | **plošne**: všetky materiály katalógu — dosky (korpus, čelo, PD, zástena…) **aj ABS hrany aj dosky (boards)**; hrany bez orientácie (vždy rovnaká). „Celý projekt s textúrami a dosky bez by bola polovičná práca" | ÁNO |
| Orientácia podľa smeru dekoru | **patrí do tohto bloku** („spraviť celé naraz a poriadne, nekúskovať") | ÁNO |
| Mierka | jedna na materiál, nastavuje sa „od oka" v editore materiálov SketchUpu | ÁNO |
| Priehľadnosť · metalness · roughness (PBR) | nastavuje sa **v editore SketchUpu**, plugin nič vlastné needituje; ukladá sa s materiálom a **na oboch PC je rovnaké** | ÁNO (zadarmo cez .skm) |
| Uloženie vzhľadu | **vždy ručne klikom „Uložiť vzhľad"**, nikdy automaticky pri zmene v SketchUpe | ÁNO |
| Render | Lucia používa **Thea**, aktuálne sa renderuje **cez AI** (screenshot → AI úprava) → rozhoduje vzhľad **viewportu** SketchUpu: textúra + mierka + orientácia; PBR posuvníky = bonus, externý renderer ich nemusí čítať | info |
| Zdieľanie .skm medzi PC | po V1 (SYNC-3 súbory do `H:\Môj disk\NoxunENGINE data`), dovtedy model nesie textúry v sebe | po V1 |

## 1 · Čo SketchUp 2026 vie natívne (overené 6.9. probe cez SkAgent, model nebol potrebný)

| Potreba | API | Poznámka |
|---|---|---|
| textúra na materiáli | `Material#texture=` (cesta / ImageRep) | súbor sa vloží do modelu (.skp ho nesie ďalej) |
| mierka | `Texture#size=`, čítanie `width/height` (palce) | jedna na materiál |
| priehľadnosť | `Material#alpha=` | |
| PBR | `metallic_factor=`, `roughness_factor=`, `normal_texture=` + `normal_scale`, `ao_texture=` + `ao_strength`, `*_enabled`, `workflow` | celá sada v 26.0 |
| **kontajner vzhľadu** | **`Material#save_as(path.skm)`** + **`Materials#load(path.skm)`** | SketchUpov formát .skm nesie textúru aj všetky nastavenia — plugin nevymýšľa vlastný formát |
| náhľad | `Material#write_thumbnail` | dlaždica v Štúdiu |
| natočenie textúry | `Face#position_material`, `texture_positioned?`, `get_UVHelper` | volá sa **per plocha** |
| export textúry z modelu | `Texture#write`, `TextureWriter` | pre prípad „vzhľad vznikol v modeli" |

## 2 · Ako to funguje z pohľadu používateľa

1. Štúdio → Materiály, skupina: **„Priradiť textúru…"** (súborový dialóg do `E:\NOXUN\.MATERIÁLY`) → plugin nasadí textúru na SketchUp materiál skupiny (materiály sa už dnes volajú
   podľa `material_id`; ABS pásky `NOXUN_ABS_<abs_id>`).
2. Mierku, priehľadnosť, PBR doladí používateľ **v paneli materiálov SketchUpu** (žiadne vlastné UI).
3. **„Uložiť vzhľad"** → `save_as` do `<knižnica vzhľadov>/<material_id>.skm` + `write_thumbnail` → dlaždica; záznam katalógu dostane `appearance` (odkaz + kľúč identity, dátum).
   **„Odstrániť vzhľad"** = zloží textúru na farbu (párová cesta). Knižnica vzhľadov: `%APPDATA%\NOXUN\Engine\appearances\` (po V1 zdieľaný koreň).
4. Pri stavbe/prestavbe: materiál sa nájde podľa mena a **neprepisuje**; z .skm sa načíta len keď v modeli chýba alebo sa zmenil kľúč; bez súboru (druhé PC) **drží, čo v modeli je**;
   **farba sa na textúrovaný materiál nenastavuje** (existujúci bezpodmienečný `mt.color=` v `ensure_su_material` sa guarduje).
5. Smer dekoru: builder maľuje **dve dekorové plochy** dielca samostatne a nastaví polohu textúry podľa `grain_direction` (dáta: `PartFaces` osi + K1/D-108 override + smer materiálu);
   ABS plochy dostanú textúru pásky bez natáčania.

## 3 · Čo si robíme sami (nie je natívne)

- **Orientácia per dielec** — dnes `inst.material =` na celý komponent (`cabinet_builder.rb`, `board_builder.rb`); pre natočenie treba maľovať aj 2 dekorové plochy per dielec
  (`paint_edge_faces` vzor) + `position_material` s otočením 0/90°; merať výkon na KLINIKE (254 dielcov → 508 plôch), jeden Undo krok (v operácii buildera).
- **Kľúč identity vzhľadu** (hash .skm / veľkosť + dátum) na SU materiáli a pravidlo „drž bez súboru" (z pôvodného package M-R FOTO ostáva).
- **Kolízia mien pri `Materials#load`** do modelu, kde materiál rovnakého mena už je (SketchUp môže vytvoriť `name1`) — **probe v package**; riešenie: načítať, preniesť textúru
  a nastavenia na existujúci materiál (alebo nahradiť objekt a premaľovať), nikdy nenechať duplikát.
- **Zástena rub** (`back_decor`) = druhý materiál? — rozhodnúť v package (dnes zástena = jeden SU materiál).

## 4 · Rezy (bez odhadu času — Michal)

| Rez | Obsah | Audit |
|---|---|---|
| **MR-1 jadro** | kontrakt `appearance` v katalógu (odkaz .skm + kľúč + dátum; STANDARD §7.1 — mŕtve pole `texture` nahradiť týmto), `ensure_su_material` + `ensure_su_edge_material` čítajú .skm cez `Materials#load` s kľúčom, guard farby, „drž bez súboru", odstránenie; headless + in-SU (rebuild bez extra Undo, BOM/VEPO bajtovo nezmenené) | **ÁNO** (kontrakt + dotyk builderov) |
| **MR-2 UI** | Štúdio → Materiály: Priradiť textúru · Uložiť vzhľad · Odstrániť vzhľad · náhľad (`write_thumbnail`) na dlaždici · stav (má / nemá vzhľad, dátum) — aj pre ABS pásky a UNI? (UNI = bez vzhľadu, farba) | NIE (nad MR-1), `codex-po-pr` |
| **MR-3 orientácia** | dekorové plochy per dielec + `position_material` podľa smeru dekoru; ABS bez natáčania; výkon KLINIKA; in-SU povinné | **ÁNO** (buildery) |

MR-2 ‖ MR-3 po MR-1. Demos fotka (pôvodný package) **vypadáva**; `image_url` ostáva len pre dlaždicu.

## 5 · Riziká

veľkosť .skp (textúry v súbore; 20 dekorov × ~0,3–1 MB — merať na KLINIKE) · výkon maľovania plôch · kolízia mien pri load · Thea/AI render číta len viewport → PBR len bonus ·
ručné textúry v knižnici majú rôzne rozlíšenia (280 px náhľady sú nepoužiteľné — používateľ vyberá, plugin neposudzuje) · mierka od oka = smoke Michal s reálnou doskou.

## 6 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../PLAN.md](../../PLAN.md) blok 5: package „M-R FOTO" **nahradiť** odkazom sem + rezy MR-1..MR-3; D-28 (knižnica vzhľadov + PBR) = **splnené týmto blokom** okrem zdieľania (po V1).
- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 7: „quick-win render (Demos fotka)" → „vzhľad materiálu z knižnice textúr (.skm), orientácia podľa dekoru"; „plná appearance vrstva" v Mimo V1 zúžiť na pixlu + zdieľanie.
- [../../STANDARD.md](../../STANDARD.md) §7.1: pole `texture` → `appearance` (v MR-1).
