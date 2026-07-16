Ahoj. Keď poskladám staré konverzácie a pamäť, vzniká z toho pomerne jasný obraz: **SketchUp u teba nie je len kresliaci program, ale jadro výrobného workflow**. Problém nie je nedostatok nápadov ani pluginov. Opakovane sa láme hlavne **štandardizácia komponentov, transformácie, atribúty a exportné formáty**.

## 1. Ako SketchUp reálne používaš

SketchUp Pro používaš na návrh nábytku a interiérov na mieru — kuchyne, vstavané skrine, zostavy, atypické pulty, ambulancie a ďalšie zákazky.

Typický tok práce je:

**zameranie → SketchUp model → dynamické komponenty → OpenCutList → objednávka dielcov/VEPO → prípadne CNC/Vectric**

Vstupy do SketchUpu:

* meranie cez **Bosch GLM 50 C**,
* pôdorysy a miestnosti cez **MagicPlan**,
* súbory zákaziek držané alebo prepájané cez **Google Drive**.

V samotnom modeli preferuješ:

* milimetre,
* každý výrobný dielec ako samostatný komponent,
* správne materiály a orientáciu textúry,
* správne lokálne osi dielcov,
* model použiteľný nielen na vizualizáciu, ale aj na kusovník, cenu, objednávku a výrobu.

To je dôležité: ty nekreslíš „peknú skrinku“. Potrebuješ **digitálny výrobný model skrinky**.

---

## 2. Dynamické komponenty

Dlhodobo smeruješ ku knižnici postavenej približne takto:

**Master korpus → vnorené dielce/moduly → dvere, zásuvky, police, chrbát, kovanie, úchytky**

Parametre, ktoré sme riešili:

* šírka, výška a hĺbka,
* hrúbka materiálu,
* výška sokla,
* presah dvierok vľavo/vpravo,
* počet dverí, políc, priečok a zásuviek,
* vložené alebo naložené dno a strop,
* typ chrbta:

  * bez chrbta,
  * HDF približne 3 mm,
  * pevný chrbát,
* vešiaková tyč,
* úchytky,
* materiály 16/18/36 mm,
* pravidlá pre nožičky **Häfele AXILO**,
* pravidlá počtu závesov podľa výšky dverí.

Dôležitá požiadavka bola, aby sa pri zmene rozmerov:

* nerozťahovala textúra,
* dielce deformovali predvídateľne,
* dvere, korpus a kovanie správali oddelene,
* OpenCutList stále načítal správne rozmery.

Ako vzor ťa zaujal **Melamina PRO** — hlavne nie ako jeden plugin, ale ako ucelená knižnica pripravených dynamických modulov, ktorá má jednotnú logiku.

---

## 3. Pluginy, ktoré sme vytvárali alebo rozpracovávali

### Noxun Mower

Nástroj na manipuláciu s komponentmi:

* otáčanie,
* zarovnanie na `Z = 0`,
* vytvorenie kópie vľavo alebo vpravo,
* zjednodušenie opakovaných transformačných operácií.

**Opakovaný problém:** po rotácii sa kópia neposunula očakávaným smerom alebo vznikla v nesprávnej polohe. Typická príčina je miešanie:

* globálnych osí modelu,
* lokálnych osí komponentu,
* transformácie inštancie,
* bounding boxu po rotácii.

---

### Noxun Snaper

Plugin na „pricvaknutie“ dvoch komponentov k sebe.

Cieľ bol odstrániť ručné posúvanie a zarovnávanie skríň alebo dielcov. Kritická časť je určiť:

* ktorý bod prvého objektu je zdroj,
* ktorý bod druhého objektu je cieľ,
* či sa objekt má iba posunúť alebo aj otočiť,
* podľa ktorých lokálnych osí sa má zarovnať.

Tu sa opäť vracia problém **osí a transformácií**.

---

### Noxun Picker

Knižnica a vkladanie dynamických komponentov:

* výber typu skrinky,
* preset rozmerov,
* zobrazenie detailov,
* náhľad alebo „ghost“ objekt pred vložením,
* rýchle vloženie do projektu,
* následná príprava pre OpenCutList a VEPO.

Navrhovaná architektúra obsahovala:

* Browse,
* Details,
* Preview,
* Placement,
* Presets/Exports,
* JSON katalóg komponentov,
* lazy loading väčšej knižnice.

Najväčšie riziko Pickeru je, že bez pevného štandardu každá skrinka používa trochu iné názvy atribútov. Picker potom nevie spoľahlivo povedať:

> Toto je šírka, toto je výška a toto je hĺbka.

---

### Noxun Sketch

Širší nástroj na prípravu výrobných podkladov:

* generovanie scén,
* pohľady na skrinky,
* číslovanie skriniek a dielcov,
* príprava podkladov pre LayOut,
* celkové pohľady,
* okótované výkresy,
* export BOM,
* potenciálne PDF, CSV, XLSX, DXF a QR odkazy.

Riešili sme aj štandard typu:

* skrinka `S-###`,
* dielec `D-###`,
* scény ako `S-###_FRONT`,
* samostatné pohľady alebo rozklady skriniek.

Táto vetva bola ambiciózna, ale narazila na to, že ešte nebol definitívne uzamknutý **štandard komponentu a dielca**.

---

### VEPOexport

Jeden z najpraktickejších pluginov — prevod výstupu z OpenCutListu do formátu použiteľného pre objednávkový systém.

Riešilo sa napríklad:

* prevod OCL CSV do VEPO/PRO100 štruktúry,
* mapovanie olepených hrán na zápisy typu `—` a `=`,
* normalizácia hrúbok:

  * približne 18–19 mm → 18,
  * približne 36–38 mm → 36,
* poradie stĺpcov,
* názvy materiálov,
* formát rozmerov,
* CSV oddeľovače a kódovanie.

Toto je jedna z najhodnotnejších automatizácií, pretože odstraňuje ručné prepisovanie objednávok.

---

### Noxun Tasks

Úlohy alebo poznámky naviazané na SketchUp model:

* stav,
* priorita,
* priradená osoba,
* tagy,
* prepojenie úlohy na objekt,
* možnosť „Prejsť na objekt“.

**Konkrétny problém:** pri viacerých objektoch alebo kópiách vedelo „Prejsť na objekt“ preskočiť iba na prvý nájdený objekt. To naznačuje, že väzba bola pravdepodobne založená na mene, definícii komponentu alebo neunikátnom identifikátore namiesto na persistentnom ID konkrétnej inštancie.

---

## 4. Ďalšie pluginy a smery, ktoré sa objavili

Nie všetky boli reálne implementované. Časť boli návrhy pod zastrešením **Noxun Forge**:

* **CutList+** – rozšírený export kusovníkov,
* **EdgeBand Manager** – evidencia olepenia hrán,
* **Cabinet Builder** – parametrické generovanie korpusov,
* **Door & Drawer Wizard**,
* **Connector Helper** – kovanie a spoje,
* **Material Sync**,
* **Report2Order** – objednávka z reportu,
* **Layout Master**,
* **Assembly Guide Generator**,
* **Parametric Profiles**.

Externé pluginy, ktoré si skúmal alebo porovnával:

* FlexTools,
* CabMaker32,
* CabinetSense,
* SketchThis,
* Profile Builder,
* Component Stringer,
* Eneroth Component Replacer,
* Curic Stretch,
* FredoScale,
* JointPushPull.

---

# 5. Čo sa opakovane kazí

## A. Lokálne osi, rotácie a transformácie

Toto je asi najčastejší technický problém.

Objekt po otočení už nereaguje tak, ako intuitívne očakávaš:

* „vpravo“ podľa obrazovky nie je „vpravo“ podľa lokálnej osi,
* bounding box je po rotácii orientovaný inak,
* vnorená inštancia má ďalšiu transformáciu rodiča,
* Ruby API pracuje s transformačnými maticami, nie s jednoduchým X/Y/Z objektu.

Prejavuje sa to pri:

* kopírovaní doľava/doprava,
* snapovaní,
* ukladaní na zem,
* vkladaní ghost komponentu,
* zarovnávaní dverí a korpusov.

---

## B. Dynamic Components sú krehké

Dynamic Components sú použiteľné, ale ich systém je starý a má množstvo neintuitívnych pravidiel.

Opakované problémy:

* panel **Component Options** niekedy nezobrazí očakávané parametre,
* konkrétny `.skp` komponent funguje inak než jeho kópia,
* atribút je uložený na definícii, ale plugin ho hľadá na inštancii — alebo opačne,
* vnorené komponenty nezdedia hodnoty správne,
* po úprave cez Ruby sa komponent neprekreslí,
* zmena rodiča nerozbehne všetky závislé vzorce,
* názvy atribútov nie sú jednotné,
* používateľské atribúty a interné DC atribúty sa miešajú.

Často teda nepadá samotný vzorec, ale **miesto, na ktorom je atribút uložený, a mechanizmus redraw**.

---

## C. Deformovanie textúr

Pri dynamickom zväčšovaní dielcov sa textúra môže:

* natiahnuť,
* otočiť,
* zmeniť mierku,
* správať inak na jednotlivých vnorených plochách.

Pre nábytok je to zásadné, pretože smer dekoru nie je iba vizuálna vec. Ovplyvňuje aj výrobu a výpis dielcov.

---

## D. OpenCutList je citlivý na disciplínu modelu

OpenCutList funguje dobre, ale iba keď model dodržiava pravidlá:

* dielce sú komponenty, nie náhodné skupiny,
* lokálne osi sú správne,
* rozmery komponentu zodpovedajú výrobným rozmerom,
* materiál je priradený konzistentne,
* vnorenie komponentov nie je chaotické,
* hrúbka dielca je správne rozpoznateľná,
* názvy a tagy sa používajú jednotne.

Keď sa pokazí orientácia osi, OCL môže zameniť:

* dĺžku,
* šírku,
* hrúbku,
* smer dekoru,
* hrany určené na olepenie.

---

## E. Olepenie hrán

Hrany sa riešili opakovane:

* ako ich evidovať na komponentoch,
* ako ich zobraziť ikonou alebo piktogramom,
* ako ich preniesť cez OpenCutList,
* ako ich premapovať do VEPO,
* ako rozlíšiť prednú, zadnú, ľavú a pravú hranu po rotácii dielca.

Toto je typický príklad problému, ktorý vyzerá jednoducho, ale závisí od troch vecí naraz:

**geometria + orientácia dielca + dátová schéma exportu.**

---

## F. CSV, VEPO a starší softvér

Exporty pravidelne narážajú na:

* čiarku verzus bodkočiarku,
* UTF-8 verzus Windows kódovanie,
* desatinnú čiarku,
* presné poradie stĺpcov,
* špecifické pomenovanie hrán,
* hrúbky, ktoré nie sú presne 18 alebo 36 mm,
* staré verzie Vectric Aspire,
* obmedzené podporované formáty.

Tu nejde primárne o „AI nevie napísať export“. Problém je, že cieľové programy často očakávajú **nezdokumentovaný alebo veľmi presný legacy formát**.

---

## G. UI pluginov a HtmlDialog

Opakovane sa riešili:

* toolbary a ikony,
* načítanie ikon z nesprávnej cesty,
* HtmlDialog,
* komunikácia JavaScript ↔ Ruby,
* obnovovanie dát v paneli,
* zatvorenie a znovuotvorenie dialógu,
* rozdiely medzi SketchUp 2022 a novšími verziami.

UI sa často začne rozrastať skôr, než je uzamknuté dátové jadro pluginu. Potom každá zmena v komponentoch vyžaduje prerábať aj panel.

---

# 6. Hlavná systémová mucha

Najväčší problém nie je konkrétny bug.

Je to, že vznikalo viac pluginov, ale neexistoval jeden úplne uzamknutý **Noxun Component Standard**, ktorý by všetky používali.

Chýbal alebo nebol definitívne dokončený jeden spoločný kontrakt:

* čo je skrinka,
* čo je výrobný dielec,
* kde sú uložené atribúty,
* ako sa volajú,
* ktoré osi sú šírka/výška/hĺbka,
* ako sa označuje smer dekoru,
* ako sa ukladajú hrany,
* ako sa identifikuje konkrétna inštancia,
* ako sa verzujú komponenty,
* ako sa vykoná redraw,
* čo presne očakáva OpenCutList,
* čo presne očakáva VEPO.

Bez tohto štandardu každý plugin čiastočne rieši ten istý problém znova.

**Picker nevie spoľahlivo meniť rozmery.
Snaper nevie spoľahlivo určiť orientáciu.
Mower nevie, čo používateľ myslí slovom doprava.
Tasks nevie jednoznačne nájsť konkrétnu inštanciu.
VEPOexport musí opravovať nejednotné dáta na konci.**

---

# 7. Môj aktuálny verdikt

Tvoj SketchUp ekosystém má tri silné, reálne hodnotné piliere:

a) **knižnica dynamických komponentov**,
b) **OpenCutList → VEPO výrobný export**,
c) **rýchle manipulačné nástroje pre každodennú prácu**.

Najviac času sa však strácalo pokusmi robiť naraz:

* komplexný Cabinet Builder,
* Picker,
* automatické výkresy,
* úlohy,
* exporty,
* snapovanie,
* univerzálne dynamické komponenty.

Správne poradie by bolo:

**štandard komponentu → jeden referenčný korpus → OCL validácia → VEPO export → manipulačné nástroje → knižnica → automatické výkresy.**

Inak povedané: najprv jedna „nudná“, dokonale definovaná skrinka. Až potom celá inteligentná továreň. 🪚
