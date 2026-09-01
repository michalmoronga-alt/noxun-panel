# KOVANIE — checkpoint USER debaty 2026-09-01 · 02

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Nadväzuje na:** `KOVANIE_DEBATA_CHECKPOINT_2026-09-01.md`.
> **Účel:** zachytiť rozhodnutia po prvom checkpointe a umožniť bezpečne pokračovať po kompresii kontextu.

---

## 1. D-109 — nohy a pomer príchytov sokla — ROZHODNUTÉ

- šírka skrinky `< 1000 mm` → **4 nohy / klzáky**,
- šírka skrinky `>= 1000 mm` → **6 nôh / klzákov**,
- pravidlo platí rovnako pre **AXILO aj 17 mm klzáky**,
- príchyt sokla = **1 ks na každé začaté 4 nohy**,
- pomer sa počíta **samostatne per skrinka**, nie súčtom cez susedné skrinky.

Príklad:
- 4 nohy → 1 príchyt,
- 6 nôh → 2 príchyty.

---

## 2. D-111 — výber setu nôh podľa výšky sokla — ROZHODNUTÉ

- systém má podľa nastavenej výšky sokla **automaticky zvoliť predvolený kompatibilný set nôh**,
- používateľ môže set na konkrétnej skrinke manuálne prepísať,
- aktuálne zvolený set má byť viditeľný **pri vložení skrinky aj následne v Inspectore korpusu pri sokli/nohách**,
- výber nemá byť schovaný iba v projektových predvoľbách.

---

## 3. D-110 — katalóg kovania / položky a sety — ROZHODNUTÉ

### 3.1 Modaly

Použiť samostatný modal nad zatmaveným pozadím pre:
- Pridať položku,
- Upraviť položku,
- Pridať set,
- Upraviť set.

Editácia sa otvorí plne predvyplnená; klasifikácia je editovateľná, chránená identita/kód ostáva chránená tam, kde to vyžaduje dnešný systém.

### 3.2 Vstupné cesty položky

Na vrchu formulára:
1. **Démos vyhľadávanie**,
2. **URL**.

Nie sú to samostatné režimy formulára, iba vstupné cesty.

Démos URL:
- automaticky rozpoznať,
- skúsiť parse/prefill,
- pri chybe vždy umožniť manuálne doplnenie.

Cudzia URL:
- neparsovať automaticky,
- uložiť ako zdroj/reference,
- údaje vyplniť ručne.

### 3.3 Auto-klasifikácia z Démosu

- parser má skúsiť navrhnúť aj klasifikáciu,
- výrobca/brand môže prísť explicitne,
- rada/kategória/opening mode sa môžu inferovať z názvu/breadcrumb/parametrov,
- explicitný TIP-ON/PTO/PTOs/Push-to-open signál má prednosť pred neurčitým „s tlmením“,
- pri nízkej istote pole radšej nechať prázdne,
- neznámu produktovú radu **nevytvárať potichu**; iba navrhnúť `+ Vytvoriť`,
- predvyplnené polia sa uložia jedným Save, bez povinného potvrdenia každého poľa.

### 3.4 Poradie formulára položky

`Démos / URL`
→ `Kód → Názov → Cena → MJ`
→ `Kategória → Výrobca → Produktová rada`
→ `Dodávateľ → Poznámka → URL`

### 3.5 Katalóg

Hierarchia:
`Kategória → Výrobca → Produktová rada`

- skupiny zbaliteľné,
- textové hľadanie + quick filtre,
- filtre minimálne: kategória / výrobca / produktová rada / Klasické-TipOn,
- search automaticky otvorí iba vetvy so zhodou,
- po pridaní položky automaticky otvoriť správnu vetvu a zvýrazniť nový záznam.

---

## 4. Sety — klasifikácia, defaulty, snapshoty — ROZHODNUTÉ

### 4.1 Povinná klasifikácia setu

Minimálne osi:
- typ použitia / typ čela,
- spôsob otvárania: Klasické / Tip-On / Ostatné,
- konštrukcia zásuvky, ak relevantná: drevený box / kovové bočnice / ostatné,
- výrobca,
- produktová rada.

Set má jednu jasnú klasifikáciu Klasické alebo Tip-On. Jednotlivé komponenty môžu byť zdieľané medzi setmi.

### 4.2 Výrobca a produktová rada

- rada patrí presne jednému výrobcovi,
- kontrolované zoznamy, nie free text,
- `+ Vytvoriť výrobcu` / `+ Vytvoriť produktovú radu`,
- logo výrobcu je vítané ako vizuálna pomôcka, textový názov ostáva.

### 4.3 Poradie tvorby setu

1. Typ čela / použitia
2. Spôsob otvárania
3. Konštrukcia zásuvky (ak relevantná)
4. Výrobca
5. Produktová rada
6. Názov setu
7. Členovia setu

Názov systém navrhne z klasifikácie, používateľ ho môže voľne upraviť.

### 4.4 Default sety

Hierarchia:
`globálny firemný default → project override → concrete front override`

Po výbere typu čela + spôsobu otvárania sa automaticky vyberie kompatibilný default set; používateľ ho môže prepísať.

### 4.5 Snapshot/versioning setov

- existujúce projekty ostávajú zmrazené na pôvodnom snapshote/verzii,
- editácia globálneho setu nesmie spätne meniť staré projekty,
- pri otvorení starého projektu môže UI nenápadne ukázať **„Dostupná novšia verzia setu“** + ručný update,
- bez automatického upgradu a bez promptu pri každom otvorení.

---

## 5. Výrobné recepty zásuviek — ROZHODNUTÉ

### 5.1 Oddelená knižnica receptov

- vzorce neukladať priamo do produktovej rady,
- samostatná knižnica výrobných receptov,
- konkrétny systém/rada na recept odkazuje,
- viac systémov môže zdieľať rovnaký recept a líšiť sa parametrami/konštantami.

Príklad: Hettich Quadro a Blum TANDEM môžu používať rovnakú výpočtovú rodinu, ak audit potvrdí spoločnú matematiku.

### 5.2 UI umiestnenie

Studio → širší blok **Technické nastavenia**:
- Dodávateľ / Démos,
- Výrobné recepty,
- prípadne ďalšie technické knižnice neskôr.

UI umiestnenie môže byť spoločné, dátový store receptov má zostať oddelený od supplier settings.

### 5.3 Immutable kontrakt

Po overení:
- samotný recept je **nemenný**,
- parametrová sada konkrétneho systému je tiež **nemenná**,
- existujúce záznamy sa spätne neprepisujú,
- zmena technickej logiky znamená nový recept/variant/verziu,
- starý variant môže byť označený neaktívny/deprecated, ale ostáva dostupný kvôli reprodukovateľnosti,
- UI existujúce overené recepty/parametre zobrazuje read-only; pribúdať môžu nové.

### 5.4 V1 kandidáti zásuviek

Predbežný scope, finálne potvrdiť auditom používateľovho disku/Gmailu na PC:
- Hettich Atira,
- Hettich Quadro,
- Blum TANDEM,
- Blum TANDEMBOX Antaro,
- Blum LEGRABOX.

Audit má potvrdiť reálnu frekvenciu, varianty, nominálne dĺžky, kódy, Tip-On/classic a parametre.

---

## 6. Zásuvky — konštrukcia, internal, atyp — ROZHODNUTÉ

### 6.1 Konštrukcia zásuvky

Pri type čela Zásuvka:
- Drevený box / skrytý výsuv,
- Kovové bočnice,
- Ostatné / atyp.

Kategória vyberá rodinu logiky, ale neurčuje natvrdo počet výrobných dielcov. Konkrétny systém/recept určuje výsledné dielce a vzorce.

### 6.2 Ostatné / atyp

- manuálny ľubovoľný set/kovanie + množstvo,
- bez automatického generovania výrobných dielcov zásuvky,
- mimo V1 automatiky.

### 6.3 Internal drawer

Rezervovať vlastnosť:
`drawer_variant = standard | internal`

- `standard` plne automatizovať vo V1,
- `internal` evidovať už teraz,
- plnú automatiku vnútorného čela/setu odložiť,
- internal drawer nie je `Ostatné`; ostáva normálnym variantom systémov Atira/Legrabox/etc.

---

## 7. Nosnosť zásuvkových výsuvov — PRIPRAVIŤ DÁTOVO, AUTOMATIKA NESKÔR

- konkrétny variant setu má niesť `load_capacity_kg`, napr. 30 / 50 / 60 kg,
- jedna produktová rada môže mať viac nosnostných variantov,
- V1 nemusí robiť automatické rozhodovanie,
- neskoršia policy vyhodnotí riziko podľa geometrie/objemu zásuvky a praktických hraníc + dokumentácie výrobcu,
- nejde o presný výpočet hmotnosti budúceho obsahu,
- pri rizikovej zásuvke Engine:
  - upozorní,
  - navrhne kompatibilný silnejší set,
  - ponúkne one-click prepnutie,
  - **nikdy ho neprepne automaticky bez vedomia používateľa**.

---

## 8. V1 výklopy — scope

Primárne automatizovať:
- Blum AVENTOS HK top,
- Blum AVENTOS HF top,
- `Ostatné` ako manuálne riešenie pre plynové/lacné/málo používané varianty.

---

## 9. AVENTOS HF top — ROZHODNUTÉ

### 9.1 Model zostavy

- používateľ vyberie **jedno existujúce čelo** a zvolí HF top,
- Engine ho chápe ako vstup pre jednu nadradenú HF zostavu,
- HF zostava vlastní dve previazané výrobné čelá: horné + dolné,
- obe sú normálne výrobné dielce s materiálom/ABS/rozmermi/hmotnosťou,
- z pohľadu kovania tvoria jednu mechanickú zostavu.

### 9.2 Rozdelenie čela

- default návrh **50/50**,
- asymetria je povolená iba v dokumentáciou kompatibilnom rozsahu,
- HF recept navrhne správnu medzeru medzi čelami podľa technickej dokumentácie,
- používateľ môže medzeru upraviť iba v povolenom rozsahu,
- všeobecná project front-gap nemá prebiť technickú požiadavku HF systému.

### 9.3 Preview pred zásahom do modelu

- počas konfigurácie sa pôvodné jedno čelo **iba virtuálne rozdelí**,
- žiadna modelová geometria sa nemení, kým používateľ nepotvrdí,
- po potvrdení sa vytvoria dve reálne výrobné čelá,
- Cancel = návrat bez zásahu do modelu.

### 9.4 Deliaca čiara — UX priorita

Preferované:
- drag deliacej čiary vo viewporte + presná číselná hodnota v Inspectore.

V1 fallback, ak by drag vyžadoval neprimerane veľký nový interaction framework:
- číselná hodnota v Inspectore + živý viewport preview.

Implementáciu V1 neblokovať kvôli dragu.

### 9.5 Validácia

Engine musí kontrolovať:
- rozmery korpusu/zostavy,
- povolené rozdelenie čiel,
- materiál/hmotnosť,
- ďalšie oficiálne systémové limity.

Ak HF konfigurácia nie je kompatibilná:
- nesmie sa tváriť ako platný HF top,
- automatický HF výpočet/set sa zakáže,
- používateľ môže pokračovať cez `Ostatné / manuálne kovanie`,
- UI presne vypíše prekročený limit.

### 9.6 Výber mechanizmu / Power Factor

- Engine z geometrie, materiálu a hmotnosti zostavy vypočíta potrebnú hodnotu podľa oficiálneho HF receptu,
- automaticky vyberie **odporúčaný kompatibilný HF top mechanizmus/silu**,
- používateľ môže ručne zvoliť iba inú **kompatibilnú** variantu,
- nekompatibilný mechanizmus nesmie byť potvrdený ako validný HF top.

---

## 10. ĎALŠÍ BOD DEBATY

Pokračovať v HF top po automatickom výbere mechanizmu.

Najbližšie otvorené otázky:
- či používateľ vôbec potrebuje v bežnom Inspectore vidieť vypočítaný Power Factor/LF, alebo stačí výsledný mechanizmus + detail po rozbalení,
- následne počet/stredové závesy a ďalšie odvodené členy HF setu,
- potom HK top.

Držať workflow: **jedna otázka naraz**.
