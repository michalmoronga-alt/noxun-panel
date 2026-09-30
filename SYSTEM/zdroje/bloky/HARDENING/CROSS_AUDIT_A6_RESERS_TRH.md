# Krížový audit V1 — A6 · Claude Sonnet 5.5 (rešerš trhu)

Prečítané: PODKLAD, ROZHODNUTIA, V1_VIZIA, STAV, PLAN (zásobník Po V1), AUDIT_REGISTER (stav po previerke), DOGFOODING, ARCHIWOOD_INSPIRACIA, koncept 08 (ponuka), NAREZ rešerš Q4/Q3 a zoznam súborov/screenshoty na overenie, čo plugin už má (grep v `noxun_engine/`); web: oficiálne stránky a dokumentácia Cabinet Vision (brožúra Hexagon 2020), Mozaik, OpenCutList, Blum, Hettich, SketchUp, ArchiWood, CutCraft, SketchList, Polyboard/KD Max (cez predajcov), Pohoda. **Dátum overenia všetkých URL nižšie: 1.10.2026.** Položiek: 10 (os N) + 5 (os U) = 15.

Skratky v riadku „Prínos / náročnosť / riziko": V = veľký, S = stredný, N = nízky; riziko = či zásah hrozí zmeniť výrobné alebo cenové čísla.

---

## Os N — nápady po V1 (od najväčšieho prínosu)

### RT-01 · N · Stopa objednávky — plugin vie, čo už odišlo do výroby, a povie, keď sa model potom zmenil
- **Čo:** Pri každom exporte (VEPO CSV, CSV kovania, XLSX rozpočet a ponuka) si plugin zapíše čas a „odtlačok" stavu zákazky (dielce, rozmery, materiály, hrany). Pri tlačidle exportu potom ukáže „naposledy 12.9. 14:32 · od vtedy zmenených 7 dielcov, 2 nové" a Kontrola pridá oranžový nález „zákazka sa zmenila po objednávke". Dnes plugin nevie, čo už bolo objednané — doobjednávka po úprave modelu stojí na pamäti človeka, pri reálnych zákazkách je to drahé miesto. Najlacnejšia verzia: porovnať aktuálny kusovník s posledným uloženým CSV (bez skrytého úložiska).
- **Dôkaz:** Cabinet Vision brožúra Hexagon (2020), modul xCRM „Job revision tracking" a +Label „screen is updated automatically to show exactly which parts and panels have been completed" — https://bynder.hexagon.com/m/14833d38165f3105/original/Hexagon_MI_CABINET_VISION_Brochure_US-Letter_web_EN_2020_fin.pdf (1.10.2026) · Mozaik 13, „Optimizer Runs: save multiple optimizations per job" — https://help.cadmate.com.au/mozaik-version-13 (1.10.2026) · repo: `noxun_engine/ui/production_core.rb:1545-1650` (brány PRED exportom: `export_blockers`, `export_confirmations`), grep `exported_at|last_export|export_hash` v `noxun_engine/` = bez nálezu (1.10.2026).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie (len zápis poznámky o exporte a čítanie; čísla exportu sa nemenia)
- **Návrh zaradenia:** PO V1 — prvá položka po hardeningu; chráni pred presne tým typom chyby, ktorý pri reálnych zákazkách stojí peniaze, ale nie je to cieľ scenárov S1–S6.

### RT-02 · N · Export po častiach — dávky objednávky (len vybrané skrinky / len čelá / „etapa")
- **Čo:** VEPO export, nákup aj rozpočet dnes vždy berú celý model. Dielňa často objedná korpusy hneď a čelá až po výbere dekoru alebo zameraní, alebo doobjedná jednu zabudnutú skrinku. Navrhujem výber rozsahu pri exporte: označené skrinky · len korpusy · len čelá · „etapa" (pomenovaná skupina skriniek). V spojení s RT-01 plugin pozná aj „zvyšok zákazky, čo ešte nebolo objednané".
- **Dôkaz:** Mozaik 13 (Enterprise) „Optimizer Runs: save multiple optimizations per job to break larger jobs into smaller runs" — https://help.cadmate.com.au/mozaik-version-13 (1.10.2026) · vzor „fázy výroby" v praxi malých dielní — https://joinerycore.com/blog/woodworking-shop-software.html (vendor blog, 1.10.2026) · repo: `noxun_engine/core/bom.rb` a `ui/production_core.rb` nefiltrujú výber ani viditeľnosť (grep `visible|hidden` bez relevantného nálezu, 1.10.2026); v Kusovníku je len pole PROJEKT (screenshot `studio_01_bom.png`).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · áno (rozsah VEPO exportu = výrobné čísla; nutný golden: export celej zákazky bajtovo nezmenený, podmnožina = presný podrad riadkov)
- **Návrh zaradenia:** PO V1 — rozhoduje výrobné čísla, preto nie do hardeningu; robiť spolu s RT-01.

### RT-03 · N · Varianty ponuky „Čo ak" a voliteľné položky
- **Čo:** V Rozpočte tlačidlo „Porovnať s…": vyber náhradný dekor / materiál čiel alebo zapni-vypni voliteľnú položku (LED, pracovná doska) a plugin cez ten istý výpočet ako Rozpočet ukáže rozdiel („+312 € s DPH") bez zmeny modelu. Uložený variant sa dá do ponuky dať ako voliteľný riadok mimo SPOLU. Dnes Lucia musí model prestavať a porovnať ceny z hlavy; ponuka pozná len „samostatne / v zostave".
- **Dôkaz:** Mozaik Manufacturing, funkcia „What If Analysis … compare pricing scenarios" — https://www.mozaiksoftware.com/mozaik-products/mozaik-manufacturing (1.10.2026) · Cabinet Vision xBidding „makes it easy to discuss design changes with customers without having to recalculate bids from scratch" a +Catalog Editor „option up-charges" — brožúra Hexagon (URL v RT-01, 1.10.2026) · repo: screenshot `studio_05_offer.png` (žiadne voliteľné riadky), `noxun_engine/core/cp_export.rb:1-40` (kontrakt 5: do CP smie len riadok zo súčtu rozpočtu).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · V · áno (nová cenová cesta; musí zdieľať existujúci výpočet, golden: variant „bez zmeny" = rozpočet na cent)
- **Návrh zaradenia:** PO V1 — až po Karte zákazky (RT-04); overiť s Luciou, koľko variantov reálne robí (koncept 08 výslovne nechce „automatizovať všetko").

### RT-04 · N · Karta zákazky — klient, číslo ponuky, platnosť, termíny, stav, poznámka
- **Čo:** Malá karta „O zákazke" v záhlaví Štúdia (namiesto textu „zákazka: Bez názvu"): klient, adresa, číslo ponuky (automatický formát napr. 2026-014), dátum a platnosť ponuky, termín dodania, stav (Návrh → Ponuka → Objednané → Vo výrobe → Namontované) a voľná poznámka. Hodnoty idú do ponuky (číslo, platnosť) a do názvov exportov. Bez nej by budúci PDF generátor ponuky musel vymýšľať vlastné polia — placeholder v Štúdiu už dnes sľubuje „platnosť a poznámku".
- **Dôkaz:** Mozaik V14 „Invoice or Quote number field with formatting options", „Room Notes" — https://help.cadmate.com.au/version-14/mozaik-version-14 (reseller zrkadlo release notes, 1.10.2026) · Mozaik 13 „Job Notes" — https://help.cadmate.com.au/mozaik-version-13 (1.10.2026) · Mozaik Enterprise „job dashboards" — https://www.mozaiksoftware.com/mozaik-products (1.10.2026) · Cabinet Vision xCRM „Manage jobs by customer" (brožúra, URL v RT-01) · repo: screenshot `studio_05_offer.png` (záhlavie, placeholder DOCX/PDF so slovami „platnosťou, poznámkou"); grep `quote_no|cislo_ponuky|customer` v `noxun_engine/` nájde len `customer_supplied` spotrebičov (1.10.2026).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** PO V1 — prerekvizita pre DOCX/PDF ponuku (koncept 08), RT-01 a RT-03; dáta patria do NOXUN slovníka zákazky.

### RT-05 · N · Výstupy výrobcov kovania ako nezávislá kontrola receptov zásuviek (a neskôr BXF)
- **Čo:** Pred ďalším zásuvkovým systémom (Antaro, TANDEM — scenár S3) aj spätne pre Atira/Quadro: vziať výstup konfigurátora výrobcu pre 5–10 typických zásuviek (rezné rozmery dna a zadnej steny, zoznam dielov, vŕtanie) a uložiť ako „zlaté vzorky", s ktorými test porovná náš recept. Je to zdroj pravdy nezávislý od nášho katalógu a OCL-tokov — pri reálnych objednávkach zásuviek najlacnejšia poistka. Blum konfigurátor ich dáva zdarma (PDF/Excel zoznam dielov, rezné rozmery zásuvkových dielcov, BXF pre vŕtacie stroje); formát BXF môže byť neskôr aj našim výstupom (CNC/vŕtanie, dnes v zásobníku).
- **Dôkaz:** Blum Cabinet Configurator — „integrated collision check", „real-time weight calculations", výstupy „cutting lists", „BXF files (compatible with drilling/insertion machines)", „component parts lists exportable to distributor web shops" — https://blum.com/ap/en/services/planning-construction-product-selection/dynaplan (1.10.2026) · Blum Product Configurator — „drilling positions, cutting dimensions for drawer components", „complete and checked parts lists" PDF a Excel — https://www.blum.com/us/en/services/e-services/onlineproductconfigurator/ (1.10.2026) · Blum CAD/CAM Data Service — „CAM machining macros", „WOP formats" — https://www.blum.com/eu/en/services/industrial-production/cad-cam-dataservice/ (1.10.2026) · Hettich InnoTech Atira katalóg s tabuľkami rozmerov (dno, zadná stena) a zmienkou online konfigurátora — https://www.hettich.com/fileadmin/Media_Center/Catalogue/InnoTech_Atira_2023_en_UK.pdf (**NEOVERENÉ v detaile** — dokument som nečítal, údaj je z výsledku vyhľadávania; dostupnosť Hettich konfigurátora v SR neoverená) · repo: `noxun_engine/core/drawer_recipes.rb:1-50` (recepty Atira, Quadro V6; `antaro_sisy_v1` len pripravený), `tests/pure/test_kovc1_recepty.rb`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie (len testovacie dáta a porovnanie; kód sa nemení)
- **Návrh zaradenia:** HARDENING — spĺňa všetky 4 podmienky: zmenšuje riziko scenára S3, nemení výrobné čísla (len golden fixtúry), ~0,5–1 deň (Michal vygeneruje vzorky v konfigurátore, agent pridá test), bez UI. BXF ako výstup = samostatne PO V1.

### RT-06 · N · Prehľad skriniek ako štvrtý pohľad v Kusovníku
- **Čo:** Vedľa „Dielce | Platne | ABS" pohľad „Skrinky": riadok na skrinku (ID, názov, typ, šírka×výška×hĺbka, materiál korpusu a čiel, počet dielcov, m², hmotnosť, počet nálezov Kontroly); klik označí skrinku v modeli a otvorí Inspector. Dnes je zákazka v Štúdiu len po materiáloch a dielcoch — pri 254 dielcoch nie je zrejmé „ktorá skrinka je ktorá a čo s ňou nie je v poriadku"; skrinka je len text „CAB-001 ×1" v stĺpci. Cena na skrinku (D-106) sa tu môže doplniť neskôr. Nepridáva sa nová sekcia ani riadok do panela.
- **Dôkaz:** OpenCutList Outliner (stromový prehľad štruktúry modelu) — https://docs.opencutlist.org/features/outliner a https://docs.opencutlist.org/whats-new/in-version-7.0 (1.10.2026) · Cabinet Vision xBidding „Breakout bids by room" (brožúra, URL v RT-01) · repo: screenshot `studio_01_bom.png` (tri pohľady, skrinka len ako text), `noxun_engine/ui/js/studio.js:95-141` (navigácia 14 sekcií bez prehľadu skriniek).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie (len čítanie)
- **Návrh zaradenia:** PO V1 — nezávislé od ostatných; dobrý kandidát na prvú malú dávku po hardeningu.

### RT-07 · N · Odhad hodín práce ako kontrolný údaj vedľa montáže v €/m²
- **Čo:** Informačný riadok v Rozpočte „odhad hodín: dielňa ≈ 62 h, montáž ≈ 14 h → montáž za 382,80 € vychádza na 27 €/h". Hodiny sa skladajú z editovateľnej tabuľky minút (na dielec, na čelo/zásuvku, na skrinku, na m² montáže) v Nastaveniach rozpočtu a **nepočítajú sa do ceny**. Dnes je montáž platne × m²/platňu × sadzba, takže chýba spätná väzba, či cena pokrýva reálnu prácu; dáva základ na kalibráciu sadzby po zákazke.
- **Dôkaz:** Cabinet Vision xBidding „Labor per part & assembly", „Custom labor costing" (brožúra, URL v RT-01, 1.10.2026) · „materials and labor are tracked against each project to calculate per-job margins" — https://joinerycore.com/blog/woodworking-shop-software.html (vendor blog, 1.10.2026) · Microvellum „Estimating … material, hardware, labor, overhead" — https://www.microvellum.com/ (súhrn stránky, 1.10.2026) · repo: `noxun_engine/core/budget.rb:515-538` (montáž z odhadu platní), screenshot `studio_04_budget.png` („23,20 M2 × 16,50 €").
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie (len informačný; nesmie zasiahnuť cenu ani ponuku)
- **Návrh zaradenia:** PO V1 — neistota: sadzby a kostra ponuky vychádzajú z Michalovej praxe (kostra z 39 reálnych dokumentov, `cp_export.rb`), hodiny by boli len kontrola; VYRADIŤ?, ak Michal rentabilitu sleduje inde.

### RT-08 · N · Zákaznícke pohľady — uloženie 3–5 pohľadov ako PNG jedným klikom (alebo 3D odkaz)
- **Čo:** Pojmenované pohľady zákazky (pohľad na linku, pôdorys zhora, detail) sa uložia ako PNG do priečinka zákazky pre vloženie do ponuky; plugin si ich pamätá ako kamery zákazky. Alternatíva: „Zdieľať 3D odkaz" cez SketchUp — zákazník model otáča a meria. Nič sa neskrýva ani nemení v modeli (lekcia D-107), len sa nastaví kamera a zapíše obrázok. Zrýchľuje ručné vkladanie obrázkov, ktoré koncept 08 pripúšťa ako dostatočné.
- **Dôkaz:** SketchUp Help „Sharing a Model" — Share Link, „View Model", len pre modely uložené v Trimble Connect — https://help.sketchup.com/en/sharing-model (1.10.2026) · Mozaik V14 „Batch rendering for multiple images" — https://help.cadmate.com.au/version-14/mozaik-version-14 (1.10.2026) · SketchList 3D „Adobe PDF 3D Report" — https://sketchlist.com/features/ (1.10.2026) · Polyboard „One click 3D renders for client presentations" — https://wooddesigner.org/polyboard-software-tools/ (predajca, nie výrobca, 1.10.2026) · repo: `SYSTEM/zdroje/next_sessions/08_PONUKA_DOKUMENTY_CENY.md` (sekcia Vizualizácie).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** PO V1 — VYRADIŤ?, ak Lucia nepotvrdí, že obrázky do ponuky dnes robí dlho (otvorená otázka 1 konceptu 08). Odkaz na 3D model vyžaduje Trimble Connect účet — riziko úniku detailov zákazky, treba rozhodnúť.

### RT-09 · N · Export ponuky do fakturačného programu (Pohoda XML) — NEOVERENÉ použitie
- **Čo:** Ak dielňa účtuje v Pohode, ponuku z pluginu by bolo možné poslať ako doklad „Ponuka" (XML), aby ju Lucia neprepisovala do fakturácie (ďalej zálohová faktúra). Pohoda takýto import oficiálne podporuje. Či dielňa Pohodu používa, neviem — bez potvrdenia ide len o otázku pre Michala a Luciu: „Kam prepisujete ponuku po odoslaní?"
- **Dôkaz:** Pohoda — zoznam dokladov pre XML import obsahuje „Ponuky" (schéma `offer.xsd`), objednávky aj faktúry s odpočtom zálohy — https://www.stormware.sk/pohoda/xml/dokladyimport/ (1.10.2026) · Cabinet Vision „Export bid data for third party software" (brožúra, URL v RT-01) · **NEOVERENÉ:** že dielňa používa Pohodu.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie (export z hotovej ponuky, čísla ponuky sa nemenia)
- **Návrh zaradenia:** VYRADIŤ? kým nepotvrdí použitie; ak áno, PO V1 po Karte zákazky (RT-04) — číslo ponuky a klient musia byť v dátach.

### RT-10 · N · Nákupný zoznam kovania priamo do e-shopu dodávateľa — NEOVERENÉ
- **Čo:** Dnes Nákup kovania dáva „CSV pre objednávku". Blum vo svojom konfigurátore ponúka zoznam dielov exportovateľný do e-shopov distribútorov a priame odoslanie objednávky. Ak by Démos24Plus vedel import košíka zo súboru (kód + počet), stačilo by upraviť formát CSV a objednávka kovania by sa skladala jedným klikom. Import na Démos24Plus som oficiálne nenašiel — je to otázka na obchodného zástupcu Demosu, nie hotový nápad.
- **Dôkaz:** Blum Cabinet Configurator „component parts lists exportable to distributor web shops", „direct order submission to selected distributors' online platforms" — https://blum.com/ap/en/services/planning-construction-product-selection/dynaplan (1.10.2026) · Démos trade uvádza portál Démos24Plus (nákup z mobilu/tabletu), o importe košíka zo súboru stránka nehovorí — https://www.demos-trade.eu/ (1.10.2026) · repo: screenshot `studio_03_buy.png` („CSV kovania … CSV pre objednávku"). **NEOVERENÉ:** existencia importu košíka na Démos24Plus.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie (len formát výstupu nákupu)
- **Návrh zaradenia:** VYRADIŤ? kým Demos neodpovie; ak áno, PO V1 (malá dávka formátu CSV).

---

## Os U — UI/UX drobnosti a vzory

### RT-11 · U · Štetec dekoru — priradenie materiálu klikom na skrinku alebo dielec
- **Čo:** Nástroj v SketchUpe ako „vedro s farbou", ale pre materiály Noxun: vyberieš dekor, klik na skrinku/dielec/čelo ho priradí (režim „len tento / všetky rovnaké"), šípky ←/→ listujú knižnicu dekorov, pipeta prevezme dekor z objektu. Plugin tak zostane „nastav raz" aj pri rýchlych úpravách dekoru čiel, kde dnes treba označiť objekt a ísť do panela. Zápis musí ísť existujúcou materiálovou cestou (hrany ABS a cena sa nesmú obísť).
- **Dôkaz:** OpenCutList Smart Paint Tool — režim 1/∞, výber materiálu šípkami, „Sample Tool", aj hrany a dyha — https://docs.opencutlist.org/features/smart-paint-tool (1.10.2026) · verzia 7.0 „Improved Smart Paint by adding scrolling of materials" — https://docs.opencutlist.org/whats-new/in-version-7.0 (1.10.2026) · repo: grep `paint|štetec|pipeta` v `noxun_engine/` nenájde žiadny nástroj na priradenie dekoru klikom (len `appearance_*`, 1.10.2026); nástroje v `noxun_engine/tools/` (snaper, mower) dávajú vzor.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · áno (mení priradenie materiálu, teda kusovník a cenu — musí ísť cez existujúcu zapisovaciu cestu a in-SU test)
- **Návrh zaradenia:** PO V1 — UI drobnosť, ktorá ale zapisuje do modelu, preto nie do hardeningu.

### RT-12 · U · Poznámka k skrinke a k zákazke, ktorá sa ukáže vo výstupoch
- **Čo:** Jedno krátke textové pole „Poznámka" na skrinke (napr. „zmerať na mieste", „kráti sa o 2 mm pri spotrebiči", „dodá zákazník") zobrazené v Kusovníku, Kontrole a v exportoch pre dielňu/montáž. Dnes poznámku nemá skrinka (len ručné položky majú `note`), takže dôležité veci ostávajú v hlave alebo na papieri.
- **Dôkaz:** Mozaik V14 „Room Notes" — https://help.cadmate.com.au/version-14/mozaik-version-14 (1.10.2026) · Mozaik 13 „Job Notes … for variable usage throughout projects" — https://help.cadmate.com.au/mozaik-version-13 (1.10.2026) · repo: `noxun_engine/core/cabinet_builder.rb:3992, 4024` (`note` len pri ručných položkách), grep `note` v `ui/panel.html` bez poznámky skrinky (1.10.2026).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie (text sa do výrobných čísel nedostane; VEPO názvy sa nemenia)
- **Návrh zaradenia:** PO V1 — malá dávka; dáva zmysel spolu s RT-04 (poznámka na úrovni zákazky).

### RT-13 · U · „Exportovať všetko" — balík zákazky do jedného datovaného priečinka
- **Čo:** Jedno tlačidlo v Štúdiu, ktoré spustí všetky exporty (VEPO CSV, CSV kovania, XLSX rozpočet, XLSX ponuka) do priečinka `…\<zákazka>\2026-10-01_1432\` a na konci ukáže krátky súhrn (počet dielcov, m², suma, nálezy Kontroly). Dnes sú štyri tlačidlá v štyroch sekciách. Každý export si drží vlastné brány (tvrdé blokovanie, potvrdenie chýbajúcich cien); balík sa pri prvej tvrdej bráne zastaví a povie, ktorá to je. Dátovaný priečinok je zároveň „záznam, čo odišlo" (RT-01).
- **Dôkaz:** Cabinet Vision xReporting „report groups containing multiple reports that can be printed with a single click" (brožúra Hexagon, URL v RT-01, 1.10.2026) · ArchiWood „one-click report" už je v ARCHIWOOD_INSPIRACIA §7 — nový je detail „skupina reportov + dátovaný priečinok + zastavenie na bráne" · repo: screenshoty `studio_01_bom.png`, `studio_03_buy.png`, `studio_04_budget.png`, `studio_05_offer.png` (4 samostatné exporty).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie (spúšťa existujúce exportéry bez zásahu do ich výpočtov)
- **Návrh zaradenia:** PO V1 — spolu s RT-01.

### RT-14 · U · Kontextové menu SketchUpu pre Noxun skrinku (pravý klik v modeli)
- **Čo:** Pravý klik na skrinku v modeli ponúkne „Noxun: Otvoriť v Inspectore · Zobraziť v Kusovníku · Označiť rovnaké (rovnaká šablóna) · Vložiť kópiu". Dnes sa k funkciám chodí cez toolbar a panel; pravý klik je miesto, kam používateľ prirodzene siaha. Iba čítanie a označovanie — žiadne zápisy do modelu z menu (lekcia D-103/D-105 pre toolbar platí aj tu).
- **Dôkaz:** SketchUp Ruby API `UI.add_context_menu_handler` (od SketchUp 6.0; varovanie, že pomalý handler spomalí menu) — https://ruby.sketchup.com/UI.html (1.10.2026) · repo: grep `add_context_menu_handler` v `noxun_engine/` a `noxun_engine.rb` = 0 nálezov (1.10.2026); toolbar v `noxun_engine/main.rb:198-221`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** PO V1 — handler smie len zistiť `noxun_type` na vybranom objekte (bez prechádzania modelu), inak spomalí každé menu.

### RT-15 · U · Logistický súhrn zákazky pre dopravu a montáž
- **Čo:** Jeden riadok v hlavičke Kusovníka alebo pri riadku „Doprava" v Rozpočte: „najťažšia skrinka 48 kg (CAB-004) · najdlhší dielec 2 780 mm · spolu ≈ 420 kg". Hmotnosť skrinky už Inspector počíta (≈ 25,4 kg); súhrn odpovie na otázky „pôjdu dvaja montéri", „vojde to do dodávky", „treba výťah". Čisto informačný údaj.
- **Dôkaz:** Blum Cabinet Configurator „real-time weight calculations" — https://blum.com/ap/en/services/planning-construction-product-selection/dynaplan (1.10.2026) · repo: `noxun_engine/ui/panel.html:327` (`infWeight` — hmotnosť výrobných dielcov skrinky), screenshot `inspector_01_korpus.png`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** N · N · nie
- **Návrh zaradenia:** PO V1 — VYRADIŤ?, ak nikto nepotvrdí, že to potrebuje; slabší dôkaz než ostatné položky.

---

## Doplnky k známym

- **PLAN zásobník „výkresy a etikety" (+ ARCHIWOOD_INSPIRACIA §7):** Cabinet Vision delí definovateľné listy na tri druhy — **montážny list** (na skrinku), **pohľad na stenu** (elevation) a **list dielca** (brožúra Hexagon, xReporting „user definable assembly / elevation / part sheets", 1.10.2026) — užitočné rozdelenie na scope budúceho bloku výkresov (S4). OpenCutList 7.0 pridal QR kódy do návrhára etikiet a tlačidlo „Print Labels" v zozname dielcov (https://docs.opencutlist.org/whats-new/in-version-7.0, 1.10.2026). Poznámka: VEPO nálepky sú ich vlastné (max 20 znakov, VEPO_KONTRAKT), vlastné etikety dávajú zmysel až pre výrobu/montáž v dielni.
- **PLAN zásobník „Interact pre čelá":** Mozaik V14 zobrazuje „door swings … on all face types" (2D výkresy) — https://help.cadmate.com.au/version-14/mozaik-version-14 (1.10.2026). Lacnejší prvý krok než 3D interakcia: oblúky otvárania v 2D pôdoryse/pohľade z dát, ktoré už máme (origin čiel na hrane pántu).
- **D-147 (pásy nárezového plánu):** OpenCutList Cutting Diagram 7.0 rozlišuje typy „One, Guillotine, Rectangle, Nesting" a módy rezu „exact / non-exact (extra úroveň oddelenia) / homogeneous" — https://docs.opencutlist.org/features/parts/parts-list/packing (1.10.2026). „Non-exact" je presne slovník pre vnáranie menších dielcov nad seba v páse; treba overiť, či píla VEPO takú extra úroveň rezu zvláda.
- **D-106 (predbežná cena skrinky):** KD Max počíta ponuku „based on panel area" z vopred daných cien materiálu — https://cabinetsbycomputer.com.au/kd-max-features/ (predajca, 1.10.2026); Cabinet Vision má „price by part" a „part pricing matrices" (brožúra, xBidding). Dôsledok: „≈ X €" na skrinku môže byť plocha dielcov × kalibrované €/m² podľa typu skrinky z vlastných ponúk, bez plného rozpočtu.
- **NAREZ_ZAVER „sklad zvyškov" (mimo bloku):** OpenCutList berie zoznam zvyškov („panel offcuts … considered first") — https://docs.opencutlist.org/features/parts/parts-list/cutting-diagrams/sheet-goods (1.10.2026); Cabinet Vision xOptimizer má „Offcut manager" (brožúra); Mozaik má režimy „Use Up Remnants First / Use If Helps Optimization / Don't Use" a Remnant Library (výsledok vyhľadávania, oficiálna stránka 403 — NEOVERENÉ v detaile). Naša rešerš Q4 (RESERS_OUTSIDE_IN_2026-09-28, #6) hovorí, že zvyšky patria zákazníkovi a VEPO ich vie vrátiť; nízka priorita, ak sa vôbec rieši, tak ako ručný zoznam zvyškov a tri režimy použitia.
- **PLAN zásobník „Injecting dát do knižníc v dávkach" + D-48 (scenár S2/S3):** Hettich dodáva dátové balíky kovania cez knižničné správcovské nástroje partnerských programov (TopSolid Store, Vectorworks library download manager, CAD+T launcher, Microvellum Knowledge Network) — https://www.hettich.com/en-us/services/hettich-cad/cad-data-packages (1.10.2026). Vzor „knižnica kovania = verzovaný balík na stiahnutie" sedí na plánovaný Odoslať/Aktualizovať pre D-48; Blum má podobné „CAD/CAM Data Service" (URL v RT-05).
- **Koncept 02 „zostavy" a „Miestnosť/BIM-lite" (MagicPlan):** ArchiWood uvádza „space recognition to suggest appropriate modules for gaps" — https://archiwood.github.io/ (1.10.2026); Cabinet Vision Solid Standard má „auto-fill walls and rooms with cabinets" (výsledok vyhľadávania, oficiálna stránka neodpovedala — NEOVERENÉ). Nový fakt: prvý krok nemusí byť plná zostava, stačí „Vyplniť úsek" — zadaj dĺžku steny a plugin navrhne kombináciu šírok zo šablón + výplňový panel.
- **PLAN zásobník „dĺžkové materiály naplno" (sokel/lišty):** Profile Builder je „Follow Me" s knižnicou profilov a dráh a parametrickými zostavami (https://fatpencilstudio.com/blog/draft-profile-builder/ a výsledky vyhľadávania, 1.10.2026 — **NEOVERENÉ** z oficiálneho zdroja, stránka Extension Warehouse neponúkla text). Model „profil + dráha + materiál → zoznam dĺžok" by mohol byť vzor pre súvislý sokel/lištu naprieč viacerými skrinkami.

---

## Čo som nestihol / neistoty

- **Oficiálne stránky Cabinet Vision (in.cabinetvision.com, hexagon.com) a Mozaik support (mozaik.support.cyncly.com) neodpovedali (403/timeout)** — Cabinet Vision čerpám z oficiálnej brožúry Hexagon z roku 2020 (staršia, moduly sa mohli zmeniť), Mozaik V13/V14 zo zrkadla release notes u predajcu (cadmate) a z oficiálnej stránky mozaiksoftware.com.
- **imos, SWOOD, TopSolid Wood, Pytha, Microvellum a Polyboard** som prešiel len cez výsledky vyhľadávania a súhrny stránok (Polyboard a KD Max cez predajcov): sú to enterprise CAM/ERP riešenia a pre malú dielňu z nich vyplynuli len vzory vyššie (Microvellum/imos „work order", Polyboard „quote layout"); nerobil som hlbší rozbor a nezapisujem ich ako samostatné položky.
- **Pohoda (RT-09) a Démos24Plus (RT-10):** nevedno, či dielňa Pohodu používa ani či Démos24Plus vie import košíka zo súboru — otázky pre Michala/Luciu, nie hotové nápady.
- **Cabinet Pro, KCD Software, CabinetSense, GKWare Cab Maker, CutList Plus fx:** spomenuté len v prehľadoch (Woodshop News, SketchUp fórum); funkcie neoverené z oficiálnych stránok, nepoužité ako dôkaz.
- **Hettich online konfigurátor** (RT-05): zmienka je len v katalógu Atira; jeho dostupnosť a výstupy pre SK trh som neoveril — pre kontrolu recept Atira je istejší Blum (overený) alebo vzorce z katalógu.
