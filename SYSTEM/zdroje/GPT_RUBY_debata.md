# NOXUN Furniture Engine – základná koncepcia

## 1. Zámer projektu

Cieľom je postupne nahradiť krehký systém SketchUp Dynamic Components vlastným parametrickým pluginom postaveným na SketchUp Ruby API.

Nový systém nemá byť iba náhradou Dynamic Components. Má predstavovať interný nábytkársky engine, ktorý bude:

* vytvárať parametrické skrinky,
* upravovať už vložené skrinky,
* vkladať vnútorné vybavenie,
* spravovať materiály, ABS a kovanie,
* generovať výrobné dáta,
* kontrolovať chyby pred výrobou,
* pripravovať výstupy bez závislosti od OpenCutListu a samostatného VEPO exportu.

Základný princíp:

> Skrinka nie je iba SketchUp komponent. Je to dátový objekt, ktorého geometria a výrobné údaje vznikajú z jednej konfigurácie.

---

# 2. Prechod z Dynamic Components na Ruby engine

Dynamic Components sú vhodné pre jednoduché parametrické modely, ale pri súčasnom rozsahu spôsobujú problémy:

* komplikované vnorené formulky,
* slabé a problematické Component Options,
* neprehľadné závislosti medzi master a child komponentmi,
* problémy pri rotácii a kopírovaní,
* deformovanie textúr,
* zložité osi dielcov,
* obmedzené možnosti validácie,
* náročné rozširovanie vnútorného vybavenia a kovania.

Nový systém bude používať:

* štandardné SketchUp komponenty,
* vlastné atribúty a metadata,
* vlastný Ruby rules engine,
* vlastné používateľské rozhranie cez HtmlDialog,
* kontrolované generovanie geometrie,
* deterministickú regeneráciu skrinky.

Dynamic Components nebudú cieľovou architektúrou. Počas prechodu môžu zostať ako existujúca knižnica a referenčný systém.

---

# 3. Odporúčaný spôsob prechodu

Odporúčaný je hybridný postup:

1. existujúce DC komponenty ponechať počas vývoja,
2. vytvoriť nový Ruby engine,
3. začať jedným často používaným typom skrinky,
4. porovnať výstupy s existujúcimi komponentmi,
5. testovať na reálnych zákazkách,
6. postupne nahrádzať iba overené časti systému.

Neodporúča sa okamžité nahradenie celej existujúcej knižnice.

---

# 4. Základné architektonické členenie

NOXUN Furniture Engine bude rozdelený do troch hlavných oblastí.

## 4.1 Parametrické objekty

Objekty, ktoré tvoria samotnú skrinku:

* korpusy,
* čelá,
* vnútorné vybavenie,
* doplnky.

## 4.2 Katalógy

Centrálne zdroje opakovane používaných údajov:

* materiály,
* ABS,
* kovanie,
* 3D assety,
* kusové produkty,
* dĺžkové profily.

## 4.3 Pravidlá

Logika, ktorá rozhoduje, ako sa jednotlivé objekty správajú:

* konštrukčné pravidlá,
* pravidlá čiel,
* pravidlá kovania,
* materiálové pravidlá,
* pravidlá ABS,
* validácia kompatibility,
* výrobné kontroly.

Katalóg a pravidlá musia byť oddelené.

Príklad:

* katalóg kovania obsahuje konkrétny pánt,
* hardware rules engine rozhodne, koľko pántov a akého typu sa použije.

---

# 5. Korpusy

Korpus je hlavný objekt systému.

Korpus vlastní:

* vonkajšie rozmery,
* základnú konštrukciu,
* dielce korpusu,
* vnútorný čistý priestor,
* vnútorné zóny,
* pripájacie body pre čelá,
* pripájacie body pre vnútorné vybavenie,
* predvolené materiály,
* základné pravidlá ABS,
* požiadavky na podopretie a kovanie.

Korpus nemá obsahovať všetky možné detaily celej skrinky.

Nemá byť monolitickým master komponentom s desiatkami kombinácií. Má fungovať ako:

> obálka + základná konštrukcia + vnútorné zóny + pripájacie body.

Odporúča sa kompozícia:

```text
Spodný korpus
+ dvierka
+ dve police
+ AXILO nohy
+ kovanie
```

Namiesto vytvárania samostatného typu skrinky pre každú kombináciu.

---

# 6. Čelá

Modul sa nemá volať iba „Dvere“, ale širšie „Čelá“.

Čelá môžu zahŕňať:

* jednokrídlové dvierka,
* dvojkrídlové dvierka,
* zásuvkové čelá,
* výklopy,
* posuvné čelá,
* pevné krycie panely,
* falošné čelá,
* rámové čelá,
* bezúchytkové riešenia.

Čelný systém rieši:

* typ čela,
* počet čiel,
* delenie,
* medzery,
* prekrytie korpusu,
* materiál,
* ABS,
* smer otvárania,
* úchytky,
* požiadavky na kovanie.

Geometria čela, spôsob otvárania a konkrétne kovanie majú byť oddelené.

---

# 7. Vnútorné vybavenie

Vnútorné vybavenie je samostatná kategória, pretože priamo ovplyvňuje konštrukciu a vnútorný priestor skrinky.

Príklady:

* police,
* vertikálne priečky,
* horizontálne priečky,
* zásuvkové bloky,
* vešiakové tyče,
* drôtené koše,
* odpadkové systémy,
* botníkové mechanizmy,
* výsuvné police,
* výťahy,
* držiaky spotrebičov.

Každý modul môže mať:

* priestorové požiadavky,
* kompatibilitu s korpusom,
* vlastné dielce,
* vlastné kovanie,
* montážnu polohu,
* pravidlá pre obrábanie.

Vnútorné vybavenie sa vkladá do definovaných vnútorných zón korpusu.

---

# 8. Doplnky

Doplnky nie sú súčasťou základnej konštrukcie korpusu.

Príklady:

* LED profily,
* zásuvky 230 V,
* USB moduly,
* organizéry,
* zrkadlá,
* dekoratívne prvky,
* ventilačné mriežky,
* vešiaky,
* spotrebiče ako referenčné modely.

Doplnky môžu byť:

* výrobné,
* kusovníkové,
* vizualizačné,
* referenčné,
* konštrukčné, ak vyžadujú výrez alebo otvor.

---

# 9. Výrobné objekty a SketchUp štruktúra

Výrobné diely budú štandardné SketchUp komponenty s vlastným NOXUN výrobným označením.

Nebudú závislé od Dynamic Components.

Odporúčaný princíp:

* komponent s výrobným odznakom sa spracuje,
* komponent bez výrobného odznaku sa ignoruje alebo zobrazí v kontrole,
* group sa štandardne nepočíta,
* group slúži pre dekorácie, spotrebiče, pomocné objekty a referenčnú geometriu.

Výrobný stav nemá byť určený iba typom SketchUp entity. Má byť uložený explicitne v metadátach.

Príklad:

```json
{
  "entity_type": "manufactured_part",
  "production_class": "sheet"
}
```

Pred výrobou musí systém upozorniť na:

* komponent bez výrobného zaradenia,
* group s výrobným materiálom,
* výrobný diel bez materiálu,
* neznámy alebo nezaradený materiál.

---

# 10. Výrobné triedy materiálov a objektov

Systém bude pracovať minimálne so štyrmi výrobnými triedami.

## 10.1 Plošný materiál

Meria sa:

* dĺžka,
* šírka,
* hrúbka,
* množstvo,
* materiál,
* ABS.

Príklady:

* DTDL,
* MDF,
* preglejka,
* kompaktná doska,
* pracovná doska,
* sklo,
* plech.

## 10.2 Dĺžkový materiál

Meria sa najmä definovaná výrobná dĺžka.

Príklady:

* Gola profily,
* narážacie úchytky,
* LED profily,
* soklové profily,
* tyče,
* lišty.

Dĺžka nemá byť vždy automaticky odvodená z najdlhšej hrany geometrie. Engine ju má poznať priamo z konfigurácie objektu.

## 10.3 Kusový materiál

Počíta sa:

* produkt,
* kód,
* množstvo.

Príklady:

* pánty,
* nohy,
* úchytky,
* výsuvy,
* podložky,
* spojovací materiál.

## 10.4 Referenčný objekt

Do výroby sa nepočíta.

Príklady:

* spotrebiče,
* dekorácie,
* ľudia,
* miestnosť,
* vizualizačné modely,
* pomocná geometria.

Odporúčané interné označenia:

```text
sheet
linear
counted
reference
```

---

# 11. Materiálový katalóg

Materiál nie je iba SketchUp textúra.

Materiálový záznam môže obsahovať:

* interné ID,
* výrobcu,
* dekor,
* názov,
* typ materiálu,
* hrúbku,
* rozmer tabule,
* smer dekoru,
* cenu,
* dodávateľský kód,
* výrobnú triedu,
* SketchUp textúru.

Je potrebné rozlišovať:

## Materiálová rodina

Príklad:

```text
Kronospan K009 PW
```

## Materiálový variant

Príklad:

```text
K009 PW / DTDL / 18 mm
K009 PW / DTDL / 16 mm
```

Aj keď majú rovnaký dekor, ide o dva samostatné výrobné materiály a dva samostatné kusovníky.

Kusovník sa má deliť podľa materiálového variantu a hrúbky.

---

# 12. Výrobný materiál a vizuálny materiál

Výrobný materiál sa má ukladať na úrovni výrobného komponentu.

Materiály aplikované na jednotlivé plochy môžu slúžiť na:

* vizualizáciu,
* orientáciu textúry,
* odlišné povrchy.

Výrobný systém nesmie určovať materiál podľa náhodne namaľovanej plochy.

Odporúčaný princíp:

> Výrobný materiál komponentu je zdroj pravdy. Materiály na plochách sú vizuálna reprezentácia.

---

# 13. Nezaradené a ignorované materiály

Materiály bez definície sa nemajú automaticky počítať.

Nemajú však byť ignorované potichu.

Rozlišujú sa tri stavy:

1. zaradený výrobný materiál,
2. explicitne ignorovaný materiál,
3. nezaradený materiál.

Explicitne ignorovaný materiál je potvrdená dekorácia alebo referenčný materiál.

Nezaradený materiál je materiál, o ktorom používateľ ešte nerozhodol.

Pred finálnym exportom alebo potvrdením výrobných dát má byť stav:

```text
Nezaradené materiály: 0
```

---

# 14. ABS modul

ABS bude samostatný modul.

Dôvodom je, že ABS hrany sú špecifické, často obsahujú výnimky a nedajú sa úplne spoľahlivo riešiť iba automatickými pravidlami.

ABS modul bude slúžiť na:

* rýchle označovanie hrán,
* hromadné priraďovanie,
* manuálne override,
* vizuálnu kontrolu,
* kontrolu chýb,
* kontrolu neoznačených viditeľných hrán,
* kontrolu konfliktov.

Každý plošný diel musí mať jednoznačne definované jednotlivé výrobné hrany.

Interné označenie hrán môže byť:

```text
L1
L2
W1
W2
```

Používateľské rozhranie ich môže zobrazovať ako:

* predná,
* zadná,
* ľavá,
* pravá.

Interný systém musí byť odolný voči otočeniu skrinky v modeli.

---

# 15. ABS vizuálny režim

Plugin bude obsahovať samostatný ABS režim.

Po jeho aktivovaní:

* dielce sa zobrazia s približne 30–50 % opacity,
* ABS hrany sa zobrazia plne a farebne,
* rôzne hrúbky ABS môžu mať rôzne farby,
* neznáme alebo konfliktné hrany sa zvýraznia varovnou farbou,
* kliknutím na hranu bude možné zmeniť ABS.

Príklad farebného rozlíšenia:

* červená – ABS 1 mm,
* modrá – ABS 0,4 mm,
* zelená – ABS 2 mm,
* oranžová – konflikt alebo neurčená hrana,
* sivá – bez ABS.

Farby majú byť používateľsky nastaviteľné.

Režimy zobrazenia:

* všetky ABS hrany,
* iba vybraný typ ABS,
* iba chyby a neurčené hrany,
* iba vybraná skrinka alebo diel.

Master korpus môže definovať základné ABS pravidlá, ale ABS editor bude slúžiť ako finálna kontrolná vrstva.

---

# 16. Katalóg kovania

Katalóg kovania obsahuje konkrétne fyzické produkty.

Príklady:

* Blum Clip Top 110°,
* Blum Aventos,
* Hettich Quadro,
* AXILO,
* výsuvné systémy,
* úchytky,
* montážne podložky.

Záznam môže obsahovať:

* výrobcu,
* produktový kód,
* názov,
* kategóriu,
* rozmery,
* cenu,
* dodávateľa,
* 3D model,
* montážne parametre,
* kompatibilitu.

Kovanie môže mať tri úrovne reprezentácie:

1. iba kusovníkový záznam,
2. zjednodušený 3D model,
3. presný montážny model.

Nie každé kovanie musí byť detailne modelované v SketchUpe.

---

# 17. Hardware Rules Engine

Pravidlá kovania budú oddelené od katalógu kovania.

Rules engine rozhoduje:

* aký typ kovania použiť,
* koľko kusov použiť,
* či sa kovanie zmestí,
* či je kompatibilné s korpusom,
* akú dĺžku výsuvu použiť,
* koľko pántov priradiť,
* aké podložky alebo doplnky pridať.

Príklad:

```text
Výška dvierok do 900 mm
→ 2 pánty

Výška 901–1600 mm
→ 3 pánty

Výška nad 1600 mm
→ 4 pánty
```

Konkrétne kovanie nesmie byť natvrdo vložené do definície korpusu.

Správny princíp:

```text
Spodný korpus
+ dvierka
+ hardware rules engine
→ konkrétne pánty
```

---

# 18. OpenCutList a VEPO export

OpenCutList ani existujúci VEPO export nebudú súčasťou cieľovej architektúry.

Dôvody:

* duplicitné nastavovanie,
* opakovaná kontrola rovnakých údajov,
* závislosť od špecifických pravidiel OCL,
* väčšina funkcií OCL sa nepoužíva,
* ďalšie medzivrstvy komplikujú výrobný tok.

Z OCL sa zachovajú iba užitočné princípy:

* identifikácia výrobných dielcov,
* výrobné rozmery,
* orientácia dielca,
* smer dekoru,
* materiály,
* hrúbky,
* množstvá,
* ABS,
* zoskupenie dielcov podľa materiálu.

VEPO export môže počas prechodného obdobia existovať ako tenký exportný adaptér.

Nemá obsahovať:

* konštrukčnú logiku,
* určovanie materiálu,
* výpočty ABS,
* určovanie výrobných rozmerov.

Má iba previesť už validované interné dáta do požadovaného CSV formátu.

---

# 19. Interný výrobný dátový model

NOXUN Furniture Engine bude vlastniť výrobné dáta priamo.

Príklad záznamu plošného dielca:

```json
{
  "part_id": "CAB-014-SIDE-L",
  "cabinet_id": "CAB-014",
  "role": "side_left",
  "name": "Bok ľavý",
  "quantity": 1,
  "length": 720,
  "width": 560,
  "thickness": 18,
  "material_id": "K009_PW_DTDL_18",
  "grain_direction": "length",
  "edges": {
    "L1": "ABS_K009_1.0",
    "L2": null,
    "W1": "ABS_K009_0.4",
    "W2": "ABS_K009_0.4"
  },
  "production_class": "sheet"
}
```

Geometria, zoznam dielcov a exporty sú rôzne reprezentácie toho istého dátového modelu.

Zásadné pravidlo:

> Žiadny externý plugin ani exportný formát nie je zdrojom pravdy.

---

# 20. Výrobné výstupy

Budúci systém môže poskytovať:

* internú tabuľku dielcov,
* kusovník podľa materiálov,
* kusovník kovania,
* prehľad dĺžkových materiálov,
* univerzálny CSV export,
* dočasný VEPO adaptér,
* XLSX export,
* PDF alebo tlač,
* výrobné štítky,
* neskôr CNC adaptér.

Exportná vrstva bude oddelená od konštrukčnej logiky.

---

# 21. Master korpus – účel

Master korpus bude základný parametrický objekt skrinky.

Jeho úlohou je definovať:

* identitu skrinky,
* vonkajšie rozmery,
* základnú konštrukciu,
* materiálové predvoľby,
* základné ABS pravidlá,
* vnútorný čistý priestor,
* vnútorné zóny,
* rozhranie pre čelá,
* rozhranie pre vnútorné vybavenie,
* požiadavky na podopretie,
* výrobné metadata.

Master korpus nemá riešiť:

* všetky typy čiel,
* všetky systémy zásuviek,
* konkrétne pánty,
* všetky možné doplnky,
* všetku logiku celej skrinky.

---

# 22. Master korpus – základné nastavenia

## 22.1 Identita

* názov skrinky,
* interné ID,
* typ korpusu,
* kategória,
* projektová značka,
* poznámka.

Príklady typov:

* spodný,
* horný,
* vysoký,
* závesný,
* šatníkový,
* otvorený,
* rohový,
* vlastný.

## 22.2 Rozmery

* šírka,
* výška korpusu,
* hĺbka,
* výška od podlahy,
* výška sokla,
* odsadenie od steny.

Musí byť jasne rozlíšené:

* výška korpusu,
* celková výška s nohami,
* výška čela,
* výška pracovnej dosky.

## 22.3 Konštrukčný systém

* spôsob uloženia dna,
* spôsob uloženia vrchu,
* hrúbka bokov,
* hrúbka dna,
* hrúbka vrchu,
* typ chrbta,
* konštrukčné odsadenia,
* presahy.

Odporúča sa používanie konštrukčných predvolieb:

* NOXUN spodný korpus 18 mm,
* NOXUN horný korpus 18 mm,
* šatníkový korpus 18 mm,
* korpus 16 mm.

Každá predvoľba môže mať pokročilý override.

---

# 23. Master korpus – základné dielce

## 23.1 Boky

Nastavenia:

* zapnutý alebo vypnutý,
* hrúbka,
* materiál,
* výška,
* hĺbka,
* odsadenia,
* presahy,
* ABS,
* smer dekoru.

## 23.2 Dno

Možnosti:

* medzi bokmi,
* pod bokmi,
* nad soklom,
* dvojité dno,
* bez dna.

Nastavenia:

* poloha,
* hrúbka,
* materiál,
* predné odsadenie,
* zadné odsadenie,
* ABS.

## 23.3 Vrch

Možnosti:

* plný vrch,
* predná priečka,
* zadná priečka,
* dve priečky,
* bez vrchu.

Nastavenia:

* hrúbka,
* materiál,
* rozmery priečok,
* odsadenia,
* ABS.

## 23.4 Chrbát

Možnosti:

* vložený medzi boky,
* naložený zozadu,
* v drážke,
* delený,
* bez chrbta.

Nastavenia:

* hrúbka,
* materiál,
* zadné odsadenie,
* horné a spodné odsadenie,
* presahy,
* výrezy.

---

# 24. Vnútorný priestor a zóny

Master korpus musí vypočítať:

* čistú vnútornú šírku,
* čistú vnútornú výšku,
* čistú vnútornú hĺbku,
* prednú montážnu rovinu,
* zadnú montážnu rovinu.

Tieto údaje používajú ďalšie moduly.

Príklad:

```text
available_width: 764 mm
available_height: 680 mm
available_depth: 520 mm
```

Korpus môže obsahovať vnútorné zóny.

Zóna má:

* polohu,
* šírku,
* výšku,
* hĺbku,
* povolené moduly.

Priečka môže vytvárať nové zóny.

Zóny umožnia kombinácie:

* zásuvka hore,
* dvierka dole,
* spotrebič v strede,
* samostatná policová časť.

---

# 25. Police a priečky

Police je vhodné riešiť ako samostatné vnútorné moduly.

Nastavenia police:

* počet,
* hrúbka,
* materiál,
* hĺbka,
* predné odsadenie,
* zadné odsadenie,
* výšková pozícia,
* spôsob uloženia,
* ABS.

Režimy rozloženia:

* rovnomerne,
* manuálne,
* podľa otvorovej rady,
* podľa zóny.

Priečky môžu byť:

* vertikálne,
* horizontálne,
* pevné,
* vyberateľné.

Priečka vytvára nový vnútorný priestor alebo zónu.

---

# 26. Podopretie, nohy a sokel

Master korpus definuje základnú požiadavku na podopretie.

Možnosti:

* AXILO nohy,
* klasické plastové nohy,
* plný sokel,
* závesný korpus,
* bez podopretia.

Nastavenia:

* výška,
* predné odsadenie,
* bočné odsadenie,
* počet podpier,
* automatické alebo manuálne rozloženie.

Konkrétny produkt a množstvo môže vybrať hardware rules engine.

---

# 27. Rozhranie pre čelá

Master korpus definuje:

* čelnú rovinu,
* čistý čelný otvor,
* prekrytie bokov,
* horné a spodné prekrytie,
* medzery,
* zakázané zóny.

Samostatný modul čiel následne rozhodne o konkrétnom riešení:

* jedno dvierko,
* dve dvierka,
* zásuvkové čelá,
* výklop,
* kombinované čelá.

---

# 28. Materiálové dedenie

Odporúčaný princíp:

```text
projektový default
→ skrinka dedí
→ modul dedí
→ konkrétny diel môže mať override
```

Príklad:

* projekt: K009 PW / 18 mm,
* korpus: zdedí,
* police: zdedia,
* konkrétna polica: manuálny override na inú hrúbku alebo dekor.

Master korpus môže definovať:

* predvolený materiál korpusu,
* materiál chrbta,
* materiál políc,
* materiál priečok.

---

# 29. Výrobná orientácia

Každý diel musí mať stabilne definované:

* výrobnú dĺžku,
* výrobnú šírku,
* hrúbku,
* smer dekoru,
* lokálne výrobné osi.

Výrobné rozmery nesmú závisieť od otočenia skrinky v miestnosti.

Master korpus môže obsahovať pravidlá:

* boky – dekor po výške,
* dno – dekor po šírke,
* police – dekor po šírke,
* čelá – podľa vlastného modulu.

---

# 30. Regenerácia geometrie

Odporúčaný princíp:

1. načítať konfiguráciu,
2. validovať ju,
3. odstrániť alebo nahradiť generované child dielce,
4. deterministicky ich vytvoriť znova,
5. zachovať podporované override a moduly,
6. uložiť výslednú konfiguráciu.

Pre V1 sú vhodné dva režimy:

## Plne parametrický režim

Geometria je riadená enginom. Ručné geometrické úpravy sa pri regenerácii prepíšu.

## Odpojený režim

Skrinka sa zmení na bežnú SketchUp geometriu a engine ju ďalej neregeneruje.

Komplikovaný režim čiastočných geometrických override nie je potrebný vo V1.

---

# 31. Kopírovanie a identita

Každá skrinka má:

* vlastné `cabinet_id`,
* spoločné alebo vlastné `template_id`,
* vlastné ID dielcov.

Pri kopírovaní má nová skrinka štandardne dostať nové `cabinet_id`.

Môže však ďalej odkazovať na rovnaký typ alebo šablónu.

Systém musí rozlišovať:

* konkrétnu skrinku v projekte,
* typ skrinky,
* definíciu komponentu,
* konkrétnu inštanciu,
* konkrétny výrobný diel.

---

# 32. Validácia

Plugin musí kontrolovať minimálne:

* neplatné rozmery,
* záporný vnútorný priestor,
* nesúlad hrúbky materiálu a geometrie,
* chýbajúci materiál,
* nezaradený materiál,
* chýbajúce ABS,
* konflikt ABS,
* neplatný chrbát,
* kolízie dielcov,
* nekompatibilné kovanie,
* nedostatočnú hĺbku pre výsuv,
* príliš veľké alebo malé čelo,
* komponent bez výrobného zaradenia.

Validácia nemá iba vypísať chybu. Pri vhodných prípadoch má ponúknuť opravu.

Príklad:

```text
Zvolený výsuv 500 mm sa nezmestí.

Možnosti:
a) použiť výsuv 450 mm,
b) zväčšiť hĺbku korpusu,
c) odstrániť výsuv.
```

---

# 33. Používateľské rozhranie pluginu

Navrhované hlavné oblasti:

* Projekt,
* Model,
* Výroba,
* Materiály,
* Kovanie,
* Nastavenia.

Možné rozloženie:

## Ľavý panel

* štruktúra modelu,
* skrinky,
* dielce,
* skupiny,
* kovanie,
* viditeľnosť,
* stav validácie.

## Stred

* SketchUp 3D model,
* označený diel,
* základné informácie,
* výrobné údaje.

## Spodná časť

* kusovník,
* zoskupené dielce,
* kusovník podľa materiálov,
* filtre,
* exporty.

## Pravý panel

* materiály,
* výrobné triedy,
* ABS editor,
* kontrola modelu,
* rýchle priradenie.

---

# 34. Návrh kariet master korpusu

```text
MASTER KORPUS

[Základ]
- názov
- ID
- typ
- rozmery

[Konštrukcia]
- boky
- dno
- vrch
- chrbát
- priečky

[Vnútro]
- čistý priestor
- zóny
- police
- priečky

[Materiály]
- korpus
- chrbát
- dedenie
- override

[ABS]
- základné pravidlá
- kontrola
- spustenie ABS režimu

[Podopretie]
- nohy
- sokel
- závesný systém

[Pokročilé]
- odsadenia
- presahy
- regenerácia
- kopírovanie
- odpojenie od enginu
```

---

# 35. Rozsah prvej verzie

Prvá verzia má overiť celý základný pracovný tok.

## V1 má obsahovať

* jeden základný master korpus,
* nastaviteľnú šírku, výšku a hĺbku,
* boky,
* dno,
* vrch,
* chrbát,
* jeden konštrukčný systém,
* police,
* jednoduché dvierka,
* materiál korpusu,
* materiál chrbta,
* základný materiálový katalóg,
* plošné materiály,
* dĺžkové materiály,
* kusové položky,
* referenčné objekty,
* základné ABS pravidlá,
* ABS editor,
* ABS vizuálny režim,
* AXILO alebo jednoduché nohy,
* základné pravidlá pántov,
* interný zoznam dielcov,
* kusovník podľa materiálu,
* kusovník kovania,
* validáciu,
* kopírovanie,
* rotáciu,
* regeneráciu,
* odpojenie od enginu,
* uloženie a opätovné otvorenie modelu.

## V1 nemá obsahovať

* všetky typy nábytku,
* rohové korpusy,
* šikmé a zakrivené dielce,
* kompletný kuchynský CAD,
* všetky zásuvkové systémy,
* komplexné CNC,
* univerzálny editor všetkých pravidiel,
* detailné modelovanie každého kovania,
* cenotvorbu,
* optimalizáciu formátovania,
* plnú náhradu všetkých súčasných pluginov naraz.

---

# 36. Testovací pracovný cyklus V1

V1 musí spoľahlivo zvládnuť:

```text
vložiť skrinku
→ nastaviť rozmery
→ pridať police
→ pridať čelá
→ priradiť materiály
→ priradiť a skontrolovať ABS
→ priradiť kovanie
→ skopírovať skrinku
→ otočiť skrinku
→ upraviť kópiu nezávisle
→ skontrolovať kusovník
→ uložiť model
→ znovu otvoriť model
→ regenerovať skrinku bez poškodenia dát
```

---

# 37. Kľúčové architektonické pravidlá

1. Dynamic Components nie sú budúcim jadrom systému.

2. Výrobné diely sú štandardné SketchUp komponenty s NOXUN metadátami.

3. Skrinka je dátový objekt. Geometria je jej generovaná reprezentácia.

4. Výrobné dáta vznikajú priamo v NOXUN Furniture Engine.

5. OCL, VEPO ani iný externý nástroj nie sú zdrojom pravdy.

6. Exportéry iba prevádzajú hotové validované dáta.

7. Katalógy, pravidlá, geometria a exporty musia byť oddelené vrstvy.

8. Konkrétne kovanie nesmie byť natvrdo vložené do definície korpusu.

9. Materiálový variant zahŕňa dekor, typ materiálu a hrúbku.

10. Výrobný materiál sa určuje na úrovni komponentu, nie z náhodne namaľovaných plôch.

11. Nezaradené materiály sa nesmú ignorovať potichu.

12. ABS bude mať samostatný editor a kontrolný režim.

13. Výrobné rozmery a hrany nesmú závisieť od otočenia skrinky v modeli.

14. Master korpus má definovať obálku, základnú konštrukciu, zóny a rozhrania.

15. Nové funkcie sa majú pridávať ako samostatné moduly, nie ako ďalšie vetvy jedného obrovského master objektu.

16. V1 má overiť malý, kompletný a spoľahlivý pracovný cyklus.
