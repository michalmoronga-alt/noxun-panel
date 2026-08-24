# 04A · Spotrebiče S1 — externý audit výrobcov a podobných aplikácií

> **EXTERNÝ PREDIMPLEMENTAČNÝ AUDIT — NIE TASK PACKAGE.**
>
> Tento dokument dopĺňa [04_SPOTREBICE_S1.md](04_SPOTREBICE_S1.md). Nezavádza automaticky nové V1 požiadavky. Zachytáva montážne pasce z reálnych podkladov výrobcov a vzory z podobných kitchen/CAD aplikácií, ktoré má implementačný audit vedome preveriť.

Audit bol vykonaný 24. 8. 2026. Prioritu majú aktuálne rozhodnutia NOXUN a konkrétny technický list použitého výrobku.

---

# A · Externý audit reálnych montážnych požiadaviek

## 1 · Všeobecný záver: neexistuje jeden univerzálny „rozmer spotrebiča“

Podklady výrobcov opakovane oddeľujú viac typov rozmerov a požiadaviek:

- vonkajší/viditeľný rozmer výrobku,
- rozmery montážneho tela,
- niche / installation opening,
- cut-out rozmer,
- min/max rozsah,
- montážne odstupy,
- ventiláciu,
- niekedy samostatné polohy elektrického/odvodového pripojenia.

To potvrdzuje smer S1: katalóg nemá mať jeden povinný univerzálny `width/height/depth` kontrakt pre všetky kategórie. Kategória môže niesť iba tie technické požiadavky, ktoré výrobca spoľahlivo publikuje.

**Dôležitý invariant:** neznámy údaj nesmie dostať tichý univerzálny default.

---

## 2 · Umývačka — šírka je základ, ale výška je modelový rozsah

Bosch pri integrovaných umývačkách rozlišuje najmä 45 cm a 60 cm šírky a súčasne viac výškových tried. V aktuálnom planning guide uvádza napríklad modely s montážnym rozsahom približne 81,5–87,5 cm a vyššie XXL varianty približne 86,5–92,5 cm podľa konkrétnej rady.

To podporuje náš model:

```text
width_class
+ adjustable/niche height range
+ furniture front
```

Externá pasca: niektoré modely majú osobitné riešenia furniture frontu alebo príslušenstvo pre delené čelo. S1 to nemusí automatizovať, ale dátový model sa nemá uzamknúť na predpoklad, že jediná relevantná vlastnosť čela je jeho šírka.

**Odporúčanie pre S1:**

- zachovať 450/600 ako hlavný návrhový údaj,
- mať voliteľný `niche_height_range`,
- nechať priestor pre budúce model-specific front constraints,
- neotvárať teraz komplexnú mechaniku pántov/delených čiel, ak ju reálny workflow nepotrebuje.

Zdroj:
- Bosch installation tips / integrated dishwashers: https://media3.bosch-home.com/Documents/27195991_15618_BOSCH_BI_Freestanding_2025.pdf

---

## 3 · Vstavaná chladnička — výška/šírka nestačia vždy; hĺbka a ventilácia sú reálne požiadavky

Bosch pre konkrétne vstavané chladiace modely uvádza odporúčanú niche depth 560 mm, minimálne 550 mm, minimálnu vnútornú šírku niky 560 mm a explicitne upozorňuje, že ventilačné otvory nesmú byť blokované.

Pre NOXUN z toho nevyplýva, že každá chladnička musí mať natvrdo tieto hodnoty. Vyplýva z toho:

> **niche W/H/D a ventilation requirements sú vlastnosti konkrétneho produktu, nie všeobecné konštanty typu „fridge“.**

Naše produktové rozhodnutie pre S1 zostáva malé — šírka, výška a delenie čiel sú hlavné — ale snapshot má mať priestor aj na voliteľnú niche depth / ventilation požiadavku, keď ju technický list poskytne a je výrobne relevantná.

Zdroj:
- Bosch built-in refrigerator niche guidance: https://media3.bosch-home.com/Documents/9001556820/en-GB/214854539.html
- Bosch niche width: https://media3.bosch-home.com/Documents/9001556820/en-GB/1174659211.html

---

## 4 · Varná doska — najväčšia skrytá pasca je ventilácia pod doskou

Externé podklady potvrdzujú naše hlavné S1 dáta:

- outer W/D,
- cut-out W/D,
- prípadná montážna hĺbka.

Zároveň však ukazujú, že pri indukčných doskách môže byť požadovaná aj ventilácia/clearance smerom do skrinky. Aktuálne Bosch inštalačné pokyny pre konkrétny model napríklad vyžadujú pri montáži nad zásuvkou 65 mm medzi povrchom pracovnej dosky a hornou časťou zásuvky; iné modely uvádzajú vlastné minimálne odstupy a požiadavky na prúdenie vzduchu.

To znamená, že NOXUN nemá všeobecne tvrdiť:

> „38 mm doska + náš 20 mm utopený strop = každý indukčný model je automaticky OK.“

Pre väčšinu bežnej praxe to môže fungovať, ale pri konkrétnom výrobku je pravda v jeho technickom liste.

**Odporúčanie:** S1 nech kontroluje hlavne outer + cut-out, ako bolo schválené. Dátový model však nech umožní voliteľné `clearance_below` / `ventilation_requirements`; ak údaj existuje, môže z neho neskôr vzniknúť warning bez prekopania modelu.

Zdroj:
- Bosch induction hob installation / ventilation: https://media3.bosch-home.com/Documents/9001867179_E.pdf
- Bosch cooktop cut-out/minimum thickness example: https://media3.bosch-home.com/Documents/9001096142_E.pdf

---

## 5 · Rúra/mikrovlnka — náš rozdiel visible front vs installation body je správny

Výrobné podklady potvrdzujú, že viditeľné rozmery a niche rozmery sú odlišné datasety. Napríklad Bosch kombi/mikrovlnné modely uvádzajú samostatné appliance dimensions a samostatnú installation niche vrátane ventilačnej plochy v dne skrinky; pri niektorých mikrovlnkách sa zároveň zásadne líši potrebná hĺbka niky podľa typu spotrebiča.

Dôležitá externá pasca: pri niektorých vstavaných spotrebičoch výrobca vyžaduje:

- otvorenú zadnú časť alebo zadný clearance,
- ventilačnú plochu v základni,
- konkrétne miesto pre pripojenie.

To podporuje náš koncept:

```text
VISIBLE FRONT
INSTALLATION BODY / NICHE
OFFSETS
OPTIONAL CLEARANCES / VENTILATION
```

S1 nemusí generovať police ani ventilačné otvory. Má však snapshotovať relevantné model-specific požiadavky, ak sú známe, a nestratiť ich tým, že uloží iba viditeľnú výšku čela.

Zdroj:
- Bosch compact appliance installation example: https://media3.bosch-home.com/Documents/9001686063_C.pdf
- Bosch compact microwave/oven specs: https://media3.bosch-home.com/Documents/specsheet/en-GB/CMG633BS1B.pdf

---

## 6 · Digestor — „komín je vždy presne v strede“ nesmie byť dátový invariant

Naše S1 zjednodušenie môže pre bežný vstavaný digestor používať centrálnu referenciu komína/odvodu. Externý audit však ukázal, že výrobcovia môžu povoľovať alebo vyžadovať odlišné pozície ductworku. Bosch pri konkrétnom modeli napríklad uvádza šablónu s centerline, ale umožňuje posun kruhového odvodu približne o 1/2 palca na jednu alebo druhú stranu.

Preto:

- **centrálny komín je vhodný S1 default/workflow assumption,**
- **nie je to univerzálna pravda katalógového modelu.**

Ak neskôr bude presná poloha odvodu výrobne dôležitá, treba ju niesť ako samostatný model-specific installation datum/reference, nie odvodiť natvrdo zo stredu spotrebiča.

Zdroj:
- Bosch hood installation example: https://media3.bosch-home.com/Documents/8001296854_C.pdf

---

## 7 · Drez — cut-out template je dôležitejší než naivný rozdiel outer/cut-out

BLANCO pri konkrétnych drezoch publikuje samostatné cut-out templates a DXF/planning dáta. Pri undermount modeloch dokonca výslovne odporúča fyzicky overiť rozmer drezu proti šablóne a uvádza tolerancie výrezu.

Pre S1 zostáva správne evidovať:

- outer size,
- cut-out size,
- installation type, ak ho potrebujeme rozlíšiť.

Externý audit však odporúča pripraviť katalóg na to, že neskôr môže existovať aj:

- `cutout_template_ref`,
- DXF/reference asset,
- corner radius/tolerance,
- mounting mode (`topmount`, `undermount`, ...).

Toto nie je povinné pre prvú dávku; je to ochrana pred príliš jednoduchou schémou.

Zdroj:
- BLANCO example cut-out template: https://cdn.blanco.com/assets/hlr-system/TKD/PDF-Dokumente/203985_template_Qutraus_R15_25_U.pdf
- BLANCO product planning/DXF example: https://www.blanco.com/us-en/sinks/precis-f/precis-30-single-silgranit--pdp-99.109/

---

# B · Osobitné kolo — ako spotrebiče riešia podobné aplikácie

Cieľom nie je kopírovať konkurenciu. Hľadáme opakujúce sa produktové vzory a anti-patterny.

## 1 · Winner Flex: najprv nábytková nika, potom konkrétny spotrebič

Winner Flex pri vstavaných spotrebičoch používa veľmi podobný mentálny model ako navrhovaný NOXUN:

1. používateľ vloží nábytkový cabinet/housing s nikou,
2. až potom vyberie integrovaný spotrebič z appliance katalógu,
3. ak spotrebič zatiaľ nie je vybraný, nika môže zostať prázdna,
4. Winner má dokonca generický `Anything` niche placeholder a vie konkrétny appliance doplniť neskôr.

Pri vložení do prázdnej niky Winner filtruje spotrebiče podľa priestoru, ktorý je k dispozícii.

**Použiteľný vzor pre NOXUN:**

```text
NOXUN specialized cabinet / slot / niche
        ↓
expects appliance type
        ↓
konkrétny model môže prísť neskôr
        ↓
filter/validate compatible catalog items
```

To veľmi silno podporuje naše existujúce rozhodnutie „template očakáva typ“ vs. „project snapshot konkrétneho modelu“.

Zdroj:
- Winner Flex — add integrated appliances: https://winnerdesign.support.compusoftgroup.com/hc/en-gb/articles/42832187560849-How-to-add-integrated-appliances-to-a-design
- Winner Flex — empty niche / Anything: https://winnerdesign.support.compusoftgroup.com/hc/en-us/articles/360010083878-Integrating-a-built-in-appliance-into-an-empty-niche

---

## 2 · Winner Flex: generic visual môže existovať aj bez konkrétneho výrobku

Winner podporuje situáciu, keď appliance unit ešte nemá konkrétny produkt alebo supplier image. Pri špecifickom housing môže použiť generický appliance bez kódu; pri `Anything` niche zostane void. Vie tiež vložiť spotrebič bez obrázka a reprezentovať ho symbolom/presentation objectom.

**Použiteľný vzor:** dátová pravda a vizuál nemusia byť to isté.

NOXUN teda môže mať:

- očakávaný typ bez modelu,
- konkrétny model bez 3D assetu,
- jednoduchý generický proxy objekt,
- neskôr presný asset.

Žiadna z týchto vizuálnych vrstiev nesmie meniť výrobné rozmery konkrétneho appliance snapshotu.

Zdroj:
- Winner Flex — add/replace built-in objects: https://winnerdesign.support.compusoftgroup.com/hc/en-gb/articles/360010078158-Adding-or-replacing-built-in-objects-to-appliance-units-already-in-a-plan
- Winner Flex — appliance without image: https://winnerdesign.support.compusoftgroup.com/hc/en-us/articles/13891449675921-How-to-add-an-appliance-without-an-image-to-your-design

---

## 3 · Winner/2020: katalóg a filtrovanie sú hlavný workflow, nie modelovanie geometrie

Winner umožňuje filtrovať appliance katalóg podľa rozmerov a ďalších appliance-specific metadát. 2020 Design Live stavia appliance workflow na manufacturer catalogs a cloud content; výrobcovia ako Bertazzoni alebo Summit priamo publikujú obsah pre 2020 Design vrátane reálnych produktových dát a 3D reprezentácie.

Opakujúci sa pattern:

> **katalógový produkt je samostatná produktová entita s metadátami; 3D je reprezentácia produktu, nie jeho jediný zdroj pravdy.**

To podporuje našu plánovanú hranicu:

```text
CATALOG RECORD
PROJECT SNAPSHOT
BINDING / NICHE
OPTIONAL VISUAL ASSET
```

Zdroj:
- Winner appliance filters: https://winnerdesign.support.compusoftgroup.com/hc/en-gb/articles/16796034681105-How-to-select-appliances
- 2020 Design Live catalogs: https://www.2020spaces.com/wp-content/uploads/2020/07/Brochure_2020DesignLive_EN_US.pdf
- Bertazzoni designer resources / 2020 catalog: https://us.bertazzoni.com/designer-resources

---

## 4 · Cabinet Vision: useful idea + anti-pattern pre NOXUN

Cabinet Vision pracuje so spotrebičovou nikou a vie do nej vložiť appliance object. Externý tutorial ukazuje aj fixed shelf naviazanú na otvor, čo je zaujímavá budúca referencia pre rúry/mikrovlnky.

Zároveň tutorial uvádza, že appliance model môže byť automaticky resized tak, aby vyplnil otvor.

**Toto NOXUN pri konkrétnom reálnom produkte nesmie kopírovať.**

Konkrétny Bosch/Siemens/... model má nemenné technické rozmery. Ak sa nezmestí:

- nika/korpus sa má upraviť,
- alebo sa má zvoliť iný spotrebič,
- alebo má vzniknúť warning.

Automaticky stretchovať konkrétny appliance asset podľa niky by vytváral vizuálne klamstvo.

Výnimka: generický placeholder bez konkrétneho modelu môže byť parametricky natiahnuteľný, pretože nereprezentuje konkrétny výrobok.

Zdroj:
- Cabinet Vision microwave cabinet workflow: https://planitcanada.ca/blog/awesome-resources/custom-built-in-microwave-cabinet-creation-with-cabinet-vision/

---

## 5 · 2020 Design: appliance specs treba riešiť skoro, ale NOXUN ich nemusí vyžadovať na začiatku

Materiály 2020 Design upozorňujú, že appliance dimensions a installation requirements sa model od modelu líšia a pri návrhu treba overiť aj utility/plumbing access. To je správna profesionálna prax, ale NOXUN má inú produktovú prioritu: zákazník často ešte konkrétny model nemá vybraný.

Preto je správny kompromis:

- návrh môže začať s `expected appliance type`,
- konkrétny model sa doplní neskôr,
- pred výrobným/finálnym checkpointom musí byť možné odhaliť, že model chýba alebo niche nie je overená.

Toto je vhodnejšie než blokovať návrh od prvého kroku.

---

# C · Čo po externom audite meniť / nemeniť

## Koncept S1 sa zásadne nemení

Externý audit skôr potvrdzuje existujúce hranice:

- špecializovaný NOXUN korpus/slot/nika zostáva autorita nábytku,
- konkrétny spotrebič je samostatný katalógový/project snapshot,
- template môže niesť iba očakávaný typ,
- spotrebič môže byť zatiaľ bez 3D assetu,
- validácia varuje, neblokuje,
- presné výrobné rozmery konkrétneho modelu sa nesmú deformovať podľa geometrie niky.

## Doplniť ako dátové „escape hatches“, nie povinný scope

Pri finálnom návrhu schémy preveriť, či je lacné ponechať voliteľné polia/referencie pre:

- `niche_depth`,
- `niche_height_range`,
- `clearance_below` / generic installation clearances,
- ventilation requirement/reference,
- appliance body ↔ visible-front offsets,
- duct/reference position pri digestore,
- sink mounting mode / cut-out template reference.

Tieto polia nemusia byť v S1 UI ani povinné pre každý produkt. Dôležité je neuzamknúť schému tak, že ich neskôr nebude možné pridať bez prekopania domény.

## Vedome neotvárať teraz

- elektrické/plumbing routovanie,
- automatický návrh ventilácie korpusov,
- automatické presúvanie pevných políc,
- presnú geometriu všetkých spotrebičov,
- downdraft hob systém,
- free-standing appliances,
- detailné front-hinge systémy chladničiek/umývačiek,
- globálny appliance constraint solver.

---

# D · Povinné body pre budúci implementačný audit

Pred task package pre Spotrebiče S1:

1. znovu načítať [04_SPOTREBICE_S1.md](04_SPOTREBICE_S1.md) aj tento externý audit;
2. auditovať aktuálne templates/zones/BuildPlan/budget/project snapshot kontrakty;
3. vybrať 1–2 reálne technické listy z každej podporovanej kategórie a overiť, že navrhovaný katalóg vie bez straty uložiť relevantné rozmery;
4. potvrdiť, ktoré voliteľné installation údaje patria už do S1 schémy a ktoré zostanú budúcim rozšírením;
5. otestovať workflow `expected type → konkrétny model neskôr`;
6. zabezpečiť, že konkrétny appliance model/asset sa nikdy nedeformuje len preto, aby vyplnil existujúcu niku;
7. oddeliť produktové dáta, projektový snapshot, binding a optional visual asset;
8. až potom vytvoriť implementačný task package.
