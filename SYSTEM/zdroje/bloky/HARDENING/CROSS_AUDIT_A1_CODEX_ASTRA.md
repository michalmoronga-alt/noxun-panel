# Krížový audit V1 — karta A1 · Codex gpt-6-astra

Prečítal som celý podklad, rozhodnutia bloku, pravidlá repozitára, zoznamy známych vecí z §5 a relevantné kontrakty, zdroje a testy ciest S1–S5; auditovaný checkout `6d59edef` má oproti `4da1c3b5` iba dva nové dokumenty auditu, kód je totožný.

## K — kód

### CX-01 · K · Typ skrinky prihlasovať na jednom mieste

- **Čo:** Nový typ dnes potrebuje minimálne **10 registračných alebo prezentačných miest v 6 súboroch**, ešte pred vlastnou geometriou; zabudnutý zoznam môže typ sklopiť na `lower`. Navrhujem spoločný Ruby register identifikátorov a pomenovaní, z ktorého dostanú údaje Inspector, vkladanie a šablóny; prvý rez nemení konštrukčné výpočty ani osobitné pravidlá jednotlivých typov.
- **Dôkaz:** `noxun_engine/core/cabinet_builder.rb:71` · `noxun_engine/ui/js/core.js:1196` a `:1603` · `noxun_engine/ui/js/insert_state.js:40`, `:262`, `:269` · `noxun_engine/ui/js/templates.js:70` · `noxun_engine/ui/panel/actions_cabinet.rb:29` · `noxun_engine/ui/panel.html:198` a `:932`.
- **Scenár:** S1.
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · áno
- **Návrh zaradenia:** HARDENING — úzky presun členstva a textov sa dá oddeliť od geometrie do približne jednodňových dávok.
- **Overenie nezmeneného výstupu:** Pred zásahom zachytiť všetky štyri dnešné typy cez výber, vkladanie a šablónu; po zásahu porovnať odoslané parametre a uložený config. Zachovať prípady ROH-A1/A2 a S1-E, doplniť paritu celého registra naprieč spotrebiteľmi; BOM a rozpočet musia byť zhodné, VEPO pri pevnom čase bajtovo totožné.

### CX-02 · K · Zásuvkové systémy oddeliť od predpokladu „Atira alebo Quadro“

- **Čo:** Pridanie tretieho systému prekračuje najmenej **4 súbory**: zoznam systémov a predvoľby receptov, whitelist čiel, identitu a výšky setov aj zostavovanie ovládačov zásuvky. Navyše vetva „nie Atira“ dnes znamená výpočet Quadro; navrhujem register podporovaných systémov a explicitné implementácie ich výpočtov, pričom UI dostane dostupné osi z receptového jadra.
- **Dôkaz:** `noxun_engine/core/drawer_recipes.rb:66`, `:71`, `:546`, `:625`, `:1250` · `noxun_engine/modules/fronts.rb:72` · `noxun_engine/core/hardware_sets.rb:419` a `:4427` · `noxun_engine/ui/panel/payloads.rb:1736` a `:1811`. Dnešnú geometriu už pripína golden test `tests/pure/test_kovc1_resolve.rb:309`.
- **Scenár:** S3.
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · V · áno
- **Návrh zaradenia:** PO V1 — robiť pri prvom ďalšom systéme; rez zasahuje výber rozmerov, zámky aj kompatibilitu kitu a nepatrí do rýchleho upratovania.
- **Overenie nezmeneného výstupu:** Zachovať golden výsledky každého vydaného receptu vrátane chýb, hraníc výšky/NL a ručnej výšky boxu. Porovnať aj ponuku osí v Inspectore, nákupné kódy a počty, BOM, rozpočet a VEPO; in-SU overiť prestavbu, prepínanie typu čela, Undo a návrat uložených zámkov.

### CX-03 · K · Oddeliť produktové dáta kovania od mechaniky setov

- **Čo:** Nová produktová rada vyžaduje úpravu minimálne **5 dátových tabuliek v 3 Ruby súboroch**: výrobcu/rady, produktov, setov a mapovacích predvolieb; v rovnakých súboroch sa nachádza normalizácia, zápis aj expanzia. Navrhujem presunúť dnešné dátové konštanty do samostatných seed súborov po moduloch, vrátane historických tvarov potrebných na rozpoznanie používateľských úprav; migračný algoritmus a poradie načítania zostanú zachované.
- **Dôkaz:** `noxun_engine/core/hardware_taxonomy.rb:69` a `:71` · `noxun_engine/core/hardware_catalog.rb:1189` a `:1838` · `noxun_engine/core/hardware_sets.rb:448`, `:840`, `:1009`. Dôležité závislosti: taxonómia pred seedovaním setov na `hardware_sets.rb:1741`, ochrana upravených setov na `:1813` a `:1839`, postupné katalógové patche na `hardware_catalog.rb:2077`.
- **Scenár:** S3.
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · áno
- **Návrh zaradenia:** HARDENING — mechanické oddelenie dát po jednom module zmenší rozsah budúcich produktových zmien; nezavádzať pritom nový univerzálny migračný systém.
- **Overenie nezmeneného výstupu:** Pred presunom pripnúť serializovaný obsah konštánt aj výsledky čistej inštalácie a podporovaných upgrade ciest. Overiť vlastný premenovaný set, zmenený člen, vlastnú cenu a konflikt taxonómie; existujúce projektové snapshoty, nákup, rozpočet a VEPO musia zostať zhodné.

### CX-04 · K · Jedna cesta prepnutia sekcie Štúdia

- **Čo:** Odchod a vstup do sekcie sú implementované **dvakrát v jednom súbore**: pri prijatom odkaze a pri kliknutí v navigácii. Nová sekcia s modalom alebo rozbehnutou požiadavkou musí doplniť obe vetvy; navrhujem jednu funkciu pre prechod medzi sekciami, ktorá zachová dnešné poradie rušenia požiadaviek, zatvárania a vstupných akcií.
- **Dôkaz:** `noxun_engine/ui/js/studio.js:1025` — kontextové zmeny, odchodové funkcie a vstup do „O plugine“; rovnaká postupnosť v `noxun_engine/ui/js/studio.js:1938`. Spracovanie kotvy nasleduje samostatne na `:1065`, preto sa nemá bez rozlíšenia zlúčiť s obyčajným kliknutím.
- **Scenár:** S5.
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — lokálny rez bez zmeny dát a výpočtov, vhodný do jednodňovej dávky.
- **Overenie nezmeneného výstupu:** Charakterizačný JS test musí pre navigáciu aj prijatý odkaz porovnať poradie a počet volaní odchodových/vstupných funkcií, zatvorenie modalu a spotrebovanie kotvy. Overiť aj prechod na tú istú sekciu a zmenu dokumentu; výrobné payloady zostávajú nedotknuté.

### CX-05 · K · Zjednotiť evidenciu sekcií Štúdia

- **Čo:** Nová sekcia sa prihlasuje minimálne na **5 miestach v 3 súboroch**: Ruby whitelist, dva JS whitelisty, navigácia a metadáta nadpisu. Navrhujem jeden deklaratívny zoznam identifikátorov a prezentačných údajov, z ktorého vzniknú tieto pohľady; samotné renderovanie a serverové oprávnenia jednotlivých akcií zostanú explicitné.
- **Dôkaz:** `noxun_engine/ui/studio_dialog.rb:55` · `noxun_engine/ui/js/shell.js:350` · `noxun_engine/ui/js/studio.js:64`, `:93`, `:145`. Existujúca ochrana parity už je v `tests/pure/test_st1a_studio.rb:41`; problém je opakovaná údržba, nie absencia všetkých testov.
- **Scenár:** S5.
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** HARDENING — obmedziť na zoznam, poradie a texty; nezavádzať automatické registrovanie callbackov ani meniť načítavanie dát sekcií.
- **Overenie nezmeneného výstupu:** Porovnať všetkých 14 identifikátorov, poradie skupín, nadpisy, ikony a platné/neplatné odkazy z Inspectora. Dnešný test parity upraviť na výsledný kontrakt namiesto regexu nad konkrétnym zápisom konštánt; výpočty a exporty sa nemenia.

## N — nápady po V1

### CX-06 · N · Porovnanie zákazky s odovzdanou verziou

- **Čo:** Pri odovzdaní výroby alebo ponuky uložiť nemennú revíziu vydaných dát a neskôr ukázať rozdiel: pridané či odstránené dielce, zmenené rozmery, materiál, ABS, kovanie a cena. Dielňa tak zistí napríklad „po objednaní sa zmenili dve čelá“, pričom rozlíši zmenu návrhu od samotnej zmeny katalógových cien.
- **Dôkaz:** `noxun_engine/core/vepo_export.rb:321` a `:352` — opakovaný export nahrádza predchádzajúci cieľ a pomocnú starú verziu odstráni; `noxun_engine/ui/production_core.rb:3505` a `:3519` — cenový export zostavuje čerstvý stav; `SYSTEM/STANDARD.md:1611` — rozpočet zámerne nie je zmrazený výrobný snapshot.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · V · áno
- **Návrh zaradenia:** PO V1 — nová funkcia potrebuje pravidlá identity revízie a odovzdania; nenahrádza dnešný živý rozpočet ani neobnovuje vyradené odškrtávanie dielcov D-95.

## Doplnky k známym

- **D-48 + R-08/R-11/R-35/R-37 · S2:** Prenos knižníc nemá jeden spoločný zápisový bod. Už štyri základné úložiská používajú **štyri zámkové súbory**: materiály `materials.rb:495`, katalóg kovania `hardware_catalog.rb:131`, šablóny `templates.rb:651`, spotrebiče `appliance_catalog.rb:199`; k nim patria samostatné súbory vzhľadov a príloh (`materials_appearance.rb:111`, `template_previews.rb:54`, `appliance_catalog.rb:203`). Navyše `reload!` nie je garantované čisté zrušenie cache: materiály aj šablóny následne volajú `load` (`materials.rb:589`, `templates.rb:676`), pričom šablónové `load` predvolene spúšťa migráciu (`templates.rb:100`). **Spresnenie riešenia:** pre schválené Odoslať/Aktualizovať vytvoriť explicitný zoznam prenosných knižníc s prílohami a oddelenými operáciami overenia, publikovania a invalidácie cache; nespoliehať sa na kopírovanie celého priečinka ani na univerzálne `reload!`. Pred publikovaním overiť celý prijatý balík a definovať obnovu pri prerušení. Zaradenie **PO V1 v rámci D-48**; testovať zmiešané verzie, neplatnú jednu knižnicu, chýbajúcu prílohu, súbežnú lokálnu úpravu a nezmenené výrobné výstupy po prenose totožných dát.

- **R-15 · S4:** Konkrétny rozsah rezu tvoria **štyri exportné vstupy a jeden skladateľ payloadu Štúdia**: `production_core.rb:1921`, `:2029`, `:3495`, `:3580` a `studio_dialog.rb:1622`. Výpočtový pomocník už existuje (`production_core.rb:2447`), preto nový export nemá dostať ďalšiu kópiu jeho skladania. **Spresnenie riešenia:** najprv charakterizovať dnešné vstupy a výsledky, potom oddeliť zostavenie dát od UI; exportné brány ponechať podľa druhu výstupu — VEPO používa `scope: :kit` (`:1960`), cenové exporty úplnú kontrolu kovania a kompatibilitu rozpočtu (`:3525`, `:3532`), ponuka navyše kontrolu svojho súčtu (`:3627`). Jeden nerozlíšený „export povolený“ príznak by správanie zmenil. Do **HARDENING** zaradiť iba jednotlivé rezy s golden dôkazom: VEPO bajtovo pri pevnom čase, nákupné CSV, BOM, rozpočet, obsah XLSX a presná matica odmietnutí; celkové presťahovanie modulu nie je jednodňová dávka.

## Čo som nestihol / neistoty

- Ide o statický audit; nespúšťal som SketchUp ani testy zapisujúce súbory. Navrhnuté golden a in-SU overenia sú podmienky budúcich zásahov, nie deklarovaný PASS.
- Počty miest sú doložené minimá konkrétnych ciest; nezahŕňajú všetky testy, dokumentáciu a novú doménovú logiku.
- Pri stĺpci kusovníka už existuje `COLS`, spoločné renderovanie a testy hodnôt buniek; samotné doplnenie stĺpca neodôvodňuje ďalší veľký refaktor.
- Repo zostalo bez zmien.
