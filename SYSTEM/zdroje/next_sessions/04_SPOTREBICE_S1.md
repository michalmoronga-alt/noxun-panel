# 04 · Spotrebiče S1

> Stav: KONCEPT — neimplementovať priamo · zdroj: PR #210 (23.8.2026) · auditované proti kódu: zatiaľ nie
>
> Pred implementáciou platí postup z [README.md](README.md).

## Kontext a cieľ

V1 vízia počíta so spotrebičmi ako samostatnou produktovou doménou: katalóg, projektové položky, väzba na nábytok/priestor, základná kontrola kompatibility a zapojenie do rozpočtu/cenovej ponuky.

Po produktovej diskusii sa ukázalo, že netreba jeden univerzálny model „spotrebič v skrinke“. Rôzne kategórie zasahujú do nábytku odlišne:

- umývačka nemá vlastný korpus, ale má nábytkové čelo a môže vyžadovať doplnkový diel,
- vstavaná chladnička je pevne viazaná na špecializovaný chladničkový korpus,
- varná doska je viazaná na pracovnú dosku a zároveň na typický korpus pod ňou,
- digestor je viazaný na špecializovaný horný korpus s výrezom a kapotážou,
- drez nie je spotrebič v úzkom zmysle, ale workflowovo patrí do rovnakej domény vybavenia a cenovej ponuky,
- rúra/mikrovlnka sú viazané na spotrebičový korpus a ich viditeľné čelo a montážne telo nemusia mať rovnaké referenčné rozmery.

Cieľ S1 je preto **malý, praktický dátový a validačný základ**, nie veľký appliance framework.

---

## Základné vrstvy

### 1 · Katalógový záznam

Opis konkrétneho výrobku, napríklad:

- značka/model,
- kategória,
- fyzické rozmery,
- viditeľné rozmery relevantné pre nábytok,
- montážne/niche rozmery alebo rozsahy,
- prípadné cutout rozmery,
- cena a dátum overenia,
- URL/zdroje,
- technické údaje, ktoré reálne ovplyvňujú výrobu alebo kontrolu.

Nie každá kategória potrebuje rovnaké polia. Neznámy údaj sa nemá potichu nahradiť univerzálnym defaultom.

### 2 · Projektová položka

Konkrétny prvok vybavenia v zákazke:

- stabilná identita,
- referencia/snapshot katalógového výrobku,
- stav výberu: očakávaný typ vs. konkrétny model,
- väzba podľa kategórie na slot/korpus/zónu/pracovnú dosku,
- samostatná obchodná položka v rozpočte/cenovej ponuke.

### 3 · Kontrola kompatibility

Kontrola má porovnať požiadavky konkrétneho výrobku s navrhnutým nábytkom/priestorom. Má **varovať, nie blokovať**.

Typické výsledky:

- OK,
- spotrebič/model ešte nevybraný,
- chýba údaj výrobcu,
- výrez alebo niche nesedí,
- montážny clearance je nedostatočný.

---

# Kategórie pre S1

## A · Umývačka

Umývačka nemá klasický NOXUN korpus. Produktovo ju treba chápať ako samostatný **dishwasher slot / appliance modul**.

Typické vstupy:

- šírka — najmä 450 alebo 600 mm,
- nastaviteľný rozsah výšky spotrebiča, napr. 800–850 mm,
- výška cieľovej línie pod pracovnou doskou.

Slot môže vlastniť normálne NOXUN výrobné dielce:

- nábytkové čelo umývačky,
- voliteľnú hornú výškovú výplň,
- podľa konkrétneho riešenia prípadne ďalší doplnkový diel / vnútorný šuflík alebo kubus.

**Potvrdené:** čelo umývačky je normálny výrobný dielec a má ísť cez materiály, ABS, kusovník, VEPO aj cenu; owner však nie je klasický cabinet, ale appliance/dishwasher slot.

Výška spotrebiča je z pohľadu S1 menej kritická než šírka; treba ju mať ako údaj a rozsah, ale netreba z nej zatiaľ robiť komplikovaný solver.

---

## B · Vstavaná chladnička

Vstavaná chladnička je vždy viazaná na špecializovaný **chladničkový korpus**, ktorý už má NOXUN ako vlastný typ/šablónu.

Relevantné údaje:

- šírka spotrebiča / požadovanej niky,
- celková výška spotrebiča / niky,
- počet nábytkových dverí,
- výškové delenie dverí.

Štandardná šírka je prevažne okolo 600 mm; atypické širšie varianty existujú, ale nemajú riadiť návrh celej S1 architektúry.

Konkrétny model chladničky môže ovplyvniť:

- výšku chladničkového korpusu,
- výškové delenie čiel,
- prípadnú hornú blendu alebo doplnenie do cieľovej línie zostavy.

**Vedome mimo S1:** systém uchytenia dverí spotrebiča (door-on-door vs. posuvné uchytenie) a voľne stojace chladničky.

---

## C · Varná doska

Varná doska má dve relevantné väzby:

1. **pracovná doska** — výrez a vonkajší rozmer,
2. **hob cabinet pod ňou** — špecializovaný NOXUN korpus.

Relevantné dáta pre S1:

- vonkajšia šírka a hĺbka,
- šírka a hĺbka výrezu,
- prípadne montážna hĺbka, ak je spoľahlivo známa.

Klasický korpus pod varnou doskou už existuje v knižnici. Je špecifický tým, že jeho vrchný diel/strop je približne 20 mm pod hornou líniou bokov, čím vzniká priestor pre telo bežnej sklokeramickej alebo indukčnej dosky.

Pri klasickej 38 mm pracovnej doske sa bežné sklokeramické/indukčné dosky zvyčajne zmestia bez ďalšieho zásahu do korpusu.

Hlavné S1 kontroly:

- celkový vonkajší rozmer,
- rozmer výrezu,
- základná kompatibilita s pracovnou doskou a pozíciou,
- existencia/správny typ korpusu pod doskou.

**Vedome mimo S1:**

- detailné špecifiká plynových dosiek s väčšou montážnou hĺbkou,
- varné dosky s integrovaným odsávaním/downdraftom. Tie sú zriedkavé a zásadne menia vnútro skrinky; pravdepodobne sa budú riešiť osobitne alebo vôbec automatizovať nebudú.

---

## D · Vstavaný digestor

Vstavaný digestor je viazaný na typický **digestorový horný korpus**.

Relevantné dáta:

- celková šírka, výška a hĺbka,
- rozmery montážneho výrezu,
- základná referencia komína/odvodu; pre prvú verziu možno predpokladať typické centrálne umiestnenie bez komplikovaného parametrického modelu.

Digestorový korpus je špecifický tým, že okrem bežnej skrinky obsahuje výrobné dielce navyše:

- kapotáž/kryt digestora,
- kryt komína, typicky niekoľko jednoduchých dielcov.

S1 nemá z ľubovoľného digestora autonómne „vynájsť“ celú skrinku. Správna hranica je:

```text
digestorový NOXUN template/korpus
+ parametre konkrétneho spotrebiča
→ výsledný BuildPlan korpusu
```

Budúca kontrola môže porovnávať stredovú os varnej dosky a digestora, ale **nie je súčasťou S1**. Je vhodnejšia až po stabilizácii priestorových referencií/segmentov.

---

## E · Drez a jednoduché príslušenstvo

Drez nie je elektrický spotrebič, ale pre NOXUN patrí do rovnakej praktickej domény **vybavenia kuchyne a cenovej ponuky**.

Relevantné údaje:

- vonkajší rozmer,
- rozmery výrezu do pracovnej dosky,
- väzba na pracovnú dosku,
- väzba na existujúci drezový korpus.

Drezový korpus už existuje v knižnici a jeho konštrukčná odlišnosť (napr. otočené horné výstuhy/priečky kvôli priestoru pre drez) má zostať vlastnosťou jeho NOXUN šablóny, nie pravidlom samotného drezu.

Batéria, dávkovač mydla a podobné príslušenstvo môžu byť v prvej fáze iba samostatné obchodné položky v rozpočte/cenovej ponuke. Netreba kvôli nim riešiť geometriu, otvory ani validačný framework.

### 3D proxy

Pre drez môže mať jednoduchý vizuálny proxy model veľkú UX hodnotu, aby bolo na prvý pohľad jasné, že v návrhu je drez. Nie je to však podmienka úspechu S1; môže ísť o neskoršiu malú vizuálnu dávku s jedným alebo dvoma univerzálnymi modelmi.

---

## F · Rúra a mikrovlnka

Rúra a mikrovlnka sú viazané na špecializovaný **spotrebičový korpus**, podobne ako vstavaná chladnička.

Pre S1 treba odlíšiť dve referencie výrobku:

```text
VISIBLE FRONT
W × H

INSTALLATION BODY / NICHE
W × H × D
+ poloha/offset voči viditeľnému čelu
```

Dôvod: telo spotrebiča a jeho viditeľné čelo sa pri rôznych modeloch nemusia nachádzať voči sebe rovnako. Preto nestačí poznať iba výšku/šírku predného panelu.

Relevantné dáta:

- vonkajší rozmer viditeľného čela spotrebiča,
- rozmery tela alebo požadovanej niky, ak sú spoľahlivo známe,
- poloha tela voči čelu,
- spodná montážna/odvetrávacia medzera, ak ju výrobca uvádza,
- typ `oven` / `microwave` a konkrétny model.

### Pevné police

V neskoršej fáze by bolo užitočné vedieť odvodiť alebo aspoň kontrolovať výšku pevnej police pod a nad spotrebičom. To je však komplikovanejšie práve kvôli rozdielom medzi telom a viditeľným čelom jednotlivých modelov.

Pre S1:

- spotrebič hlavne kontroluje existujúci priestor/korpus,
- nepresúva automaticky pevné police,
- dátový model si však nemá zavrieť cestu k budúcim referenciám typu `bottom_support_z` / `top_clearance_z`.

### Odvetrávacia medzera

Ak technický list uvádza povinnú spodnú medzeru/clearance, má byť súčasťou projektového snapshotu a validácie. Ak údaj nie je známy, systém ho nemá potichu nahrádzať univerzálnym defaultom.

Možný budúci stav kontroly:

- `OK — spodná medzera 10 mm`,
- `WARN — výrobca požaduje min. 10 mm`,
- `UNKNOWN — požadovaná medzera nie je známa`.

Spotrebičový korpus môže mať viac appliance slotov (napr. rúra + mikrovlnka), preto sa schéma nesmie uzamknúť na predpoklad „jedna skrinka = jeden spotrebič“.

---

# Šablóny a očakávaný typ

V1 má rozlišovať:

- **template očakáva typ** — napr. `expects: oven`, produkt ešte nie je vybraný,
- **projektová skrinka/slot obsahuje konkrétny model** — napr. Bosch XYZ so snapshotom relevantných dát.

To umožní navrhnúť kuchyňu ešte pred výberom konkrétnych spotrebičov.

Kontrola môže pri nevybranom modeli ukázať napríklad ORANGE/WARN stav „spotrebič nevybraný“, ale nesmie blokovať návrh.

---

# Snapshot a reprodukovateľnosť

Projekt nesmie byť závislý od živého katalógu. Pri použití konkrétneho výrobku treba snapshotovať minimálne tie údaje, ktoré ovplyvňujú výrobu, kontrolu alebo cenu:

- identita/model,
- relevantné fyzické rozmery,
- niche/cutout požiadavky,
- dôležité offsety/clearances,
- cena + `checked_at` podľa cenového kontraktu,
- ďalšie technické parametre použité v validácii.

Živý katalóg môže byť zdrojom aktualizácií, ale starší projekt musí zostať reprodukovateľný zo svojho snapshotu.

---

# Rozpočet a cenová ponuka

Každý konkrétny prvok vybavenia môže byť samostatná obchodná položka so stavom ceny.

Treba neskôr zosúladiť s dokumentom ponúk/cien najmä:

- nákupná vs. zákaznícka cena,
- stav ceny a dátum overenia,
- čo sa zobrazí pri očakávanom type bez konkrétneho modelu,
- či sa príslušenstvo (batéria, dávkovač a pod.) zobrazuje ako samostatná položka.

S1 nemá kvôli cenovej ponuke zavádzať samostatnú paralelnú cenovú logiku.

---

# 3D reprezentácia

S1 je primárne:

> **dáta + väzba + výrobná/rozmerová kontrola + cena.**

Detailné 3D modely konkrétnych spotrebičov nie sú podmienkou S1.

Neskôr môže existovať samostatná appearance/asset vrstva, kde konkrétny katalógový model odkazuje na `asset_id`. Pre jednoduché prvky, ako drez, môže byť užitočný univerzálny proxy model skôr.

---

# Potvrdené hranice S1

S1 má pokryť hlavne:

- umývačku,
- vstavanú chladničku,
- klasickú varnú dosku,
- vstavaný digestor,
- drez ako súvisiace vybavenie,
- rúru a mikrovlnku,
- základný katalóg/snapshot,
- väzbu na príslušný NOXUN slot/korpus/pracovnú dosku,
- jednoduchú kompatibilitu a warningy,
- zapojenie do rozpočtu/cenovej ponuky.

Vedome odložiť:

- voľne stojace chladničky,
- door-on-door vs. sliding systém chladničiek,
- detailné špecifiká plynových varných dosiek,
- varné dosky s integrovaným odsávaním,
- automatické riešenie potrubia digestora,
- automatické centrovanie digestor ↔ varná doska,
- automatické generovanie/posúvanie všetkých pevných políc podľa rúry/mikrovlnky,
- komplexnú sanitárnu logiku batérií/dávkovačov,
- detailné 3D modely konkrétnych produktov.

---

# Hlavný architektonický princíp

> **Konkrétny prvok vybavenia nemá generovať celý nábytkový modul od nuly. Väčšinou sa viaže na špecializovaný NOXUN template/slot/korpus a dodáva mu produktové rozmery, referencie alebo validačné požiadavky.**

To drží výrobné pravidlá v Furniture Engine a produktové dáta v appliance/equipment vrstve.

Rovnako sa netreba snažiť uzamknúť všetko na jedno `appliance.cabinet_id`. Binding môže byť podľa kategórie napríklad:

- appliance slot,
- cabinet,
- zone,
- worktop/reference,
- neskôr segmentová/priestorová referencia.

Presný technický kontrakt sa má rozhodnúť až po audite aktuálneho modelu ownerov, zones, templates a BuildPlanu.

---

## Otvorené otázky pred implementáciou

1. Aký najmenší spoločný projektový kontrakt pokryje rôzne bindingy bez veľkého abstraktného frameworku?
2. Ako reprezentovať appliance/equipment slot a jeho owner identitu, najmä pri umývačke a viacerých spotrebičoch v jednom korpuse?
3. Ktoré rozmery jednotlivých kategórií sa dajú spoľahlivo čítať z technických listov a ktoré musia zostať voliteľné/unknown?
4. Ako sa napoja spotrebičové parametre na existujúce špecializované šablóny korpusov bez duplicity konštrukčnej logiky?
5. Ako sa invaliduje kontrola po zmene rozmerov skrinky, zóny alebo pracovnej dosky?
6. Aký presný snapshot je potrebný pre reprodukovateľnosť a cenový kontrakt?
7. Ktoré jednoduché proxy modely majú reálnu UX hodnotu a patria do malej následnej dávky?

## Pred implementáciou

Auditovať aktuálne:

- project-level dáta a snapshot autoritu,
- templates a špecializované korpusy (chladnička, varná doska, drez, digestor, spotrebičová skriňa),
- zones/slot model,
- BuildPlan warnings/control payload,
- materiály a derived parts pre appliance-owned dielce,
- budget/offer,
- prípadné existujúce appliance alebo product reference pokusy.

Zostavy/segmenty môžu neskôr ovplyvniť väzbu varnej dosky, digestora a priestorové kontroly. S1 sa však nemá segmentmi zablokovať; neskoršia integrácia má byť možná cez rozšíriteľný binding/reference model.
