# Krížový audit V1 — karta A2 · Grok grok-4.7

Čítal som podklad, rozhodnutia z 1. 10. 2026, otvorené R, zásobník v PLAN, otvorené položky DOGFOODING a Archiwood inšpiráciu; v kóde cesty S1–S5 a UI (`studio.js`, `panel.html`, `production_core.rb`, stavba typu, recepty, sety, kusovník, nárez) a screenshoty `inspector_00`, `inspector_01`, `inspector_02_kovanie`, `studio_01_bom`, `studio_02_ctrl`, `studio_06_cut`.

## K

### GR-01 · K · Profil schopností namiesto mena typu
- **Čo:** Nový typ (horný roh, vysoká potravinová) dnes nie je nový riadok v zozname. To, či skrinka stojí, visí, je slot, je roh a má nohy, je roztrúsené v porovnaniach s konkrétnym menom: horná ide na výšku zavesenia, sokel sa hornej aj umývačke vynuluje, nohy sa hornej schovajú, rohové polia aj vkladací nástroj sa pýtajú výhradne na `corner_blind`. Rez na jeden deň: tabuľka profilu pre dnešné štyri typy a vetvy ju len čítajú. Horný roh a potravinová zostávajú po V1.
- **Dôkaz:** `noxun_engine/core/cabinet_builder.rb:61` · `:627` · `:3233` · `:3240` · `:4350` · `noxun_engine/core/construction.rb:614` · `:1426` · `noxun_engine/core/ghost_tool.rb:1253` · `noxun_engine/ui/js/hardware.js:2468` · `:2474`
- **Scenár:** S1
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — zlacnie ďalší typ a pri nezmenenom profile dnešných štyroch typov ostanú dielce aj čísla tie isté; dá sa odrezať ako jedna tabuľka bez nového typu.
- **Overenie nezmeneného výstupu:** Pred zásahom zmraziť geometriu dolnej, hornej, rohovej a slotu umývačky a zlatý VEPO aj kusovník; po zásahu bajtovo tie isté súbory.

### GR-02 · K · Výškový variant podľa tvaru receptu
- **Čo:** Ďalšia značka zásuvky (Antaro, StrongBox, TANDEM) nie je „priložiť JSON“. Meno systému je uzavretý slovník a tak to má zostať: neznámy systém sa nesmie ticho namapovať. Fyzika výšky je však viazaná na meno `atira`, hoci JSON už buď výškové varianty má, alebo ich mať nesmie. Rovnaká vidlica je v zámkoch výšky, v paneli kovania aj v bielych listinách čela. Triedny kľúč `class:slide|classic|metal` zámerne zdieľa budúca kovová značka s Atirou — ten kľúč sa v tejto dávke nemení, lebo by zmenil uložené mapovanie a nákup. Rez: brány sa pýtajú „recept má `height_variants`“, nie „systém sa volá atira“. Samotná značka ostáva po V1.
- **Dôkaz:** `noxun_engine/core/drawer_recipes.rb:10` · `:66` · `:71` · `:468` · `:1250` · `:1294` · `noxun_engine/core/cabinet_builder.rb:3806` · `:3843` · `noxun_engine/ui/panel/actions_hardware.rb:243` · `:305` · `:332` · `:397` · `noxun_engine/modules/fronts.rb:72` · `noxun_engine/core/hardware_sets.rb:4416` · `:4427` · `:1009` · `noxun_engine/core/hardware_taxonomy.rb:71`
- **Scenár:** S3
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — Atira aj Quadro ostanú na tej istej vetve, ktorú im dnes dáva tvar ich receptu; nová značka, nové kódy a zmena triedneho kľúča sú až produktový krok.
- **Overenie nezmeneného výstupu:** Pred zásahom zlaté testy receptov (výška, box, NL) a nákupný CSV Atira aj Quadro; po zásahu tie isté dielce aj tie isté objednávacie kódy.

### GR-03 · K · Súpis knižníc pred zdieľaním dvoch počítačov
- **Čo:** Pred spoločným diskom knižníc nikde nie je jeden zoznam, čo knižnica je: súbor, zámok, revízia, prílohy vedľa JSON a či sa vôbec zdieľa. Šablóny si priečinok berú priamo z údajov Windows a obchádzajú spoločný priečinok materiálov. Vedľa JSON žijú vzhľady materiálov, náhľady šablón a prílohy spotrebičov, každý so svojím režimom zámku. Rez: jeden súpis, riadok po riadku, so značkou „zdieľať / len tento počítač“ pri štatistike používania, aktualizátore, téme a prepínačoch kresby. Súpis nič nekopíruje a nerieši revízie ani tvar dodávateľa.
- **Dôkaz:** `noxun_engine/core/templates.rb:81` · `noxun_engine/ui/production_core.rb:280` · `noxun_engine/core/hardware_sets.rb:236`
- **Scenár:** S2
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — ďalšia knižnica pribudne ako riadok súpisu a formát súborov ani čísla zákazky sa nemenia. Samotné zdieľanie na Disku je až funkcia po V1.
- **Overenie nezmeneného výstupu:** Pred zásahom odtlačok každého JSON knižnice a zoznam príloh; po zásahu tie isté bajty, súpis je len čítanie.

### GR-04 · K · Jedna tabuľka mien rolí
- **Čo:** Nový dielec musí dostať meno v pláne, slovenské meno v okne a pravidlo olepu, inak pásku nedostane a treba zdvihnúť seed. Slovenské mená rolí žijú v súbore okna, výrobné mená dielcov sú v stavbe a sú zámerne bez diakritiky (`Bok lavy`). Tie výrobné mená číta kusovník aj pomenovanie riadku VEPO, preto sa v tejto dávke neprekladajú. Rez: zobrazovacie mená (stĺpec Rola a mená rohovej zostavy) sa čítajú z jednej tabuľky. Pravidlá hrán a bump seedu ostanú pri dávke, ktorá rolu naozaj pridá.
- **Dôkaz:** `noxun_engine/core/build_plan.rb:118` · `noxun_engine/ui/production_core.rb:1802` · `:1813` · `:1835` · `noxun_engine/core/abs_rules.rb:61` · `:71` · `noxun_engine/core/construction.rb:605` · `:1856` · `noxun_engine/core/bom.rb:1636`
- **Scenár:** S1
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — nové slovenské meno role je jeden riadok a výrobný reťazec dielca ostáva, takže VEPO ani kusovník nezmenia písmená.
- **Overenie nezmeneného výstupu:** Pred zásahom zmraziť texty `role_label` pre každú dnešnú rolu a zlatý stĺpec mien vo VEPO; po zásahu tie isté reťazce.

### GR-05 · K · Stĺpec kusovníka ako jedna špecifikácia
- **Čo:** Nový stĺpec (hmotnosť dielca, názov skrinky) je dnes osobitná vetva v kreslení bunky a čísla žijú na ruby riadku pod inými menami, ako sú hlavičky. Rola je zámerne len doplnok vedľa riadku, lebo kľúč zoskupenia ju nesmie dostať — inak by sa zmenil kusovník aj VEPO. Rez: jeden popis stĺpca (kľúč, hlavička, pole riadku, či ide do VEPO alebo do tabuľky). Nový stĺpec má predvolene „nikam neexportovať“. Dnešné stĺpce ostanú zapnuté tak ako teraz.
- **Dôkaz:** `noxun_engine/ui/js/studio.js:75` · `:287` · `noxun_engine/ui/production_core.rb:1804` · `noxun_engine/core/bom.rb:1666` · `_dev/v1audit_shots/studio_01_bom.png`
- **Scenár:** S5
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — päť dnešných stĺpcov aj skryté dva ostanú a do VEPO nejde žiadne nové pole, kým ho niekto výslovne neoznačí.
- **Overenie nezmeneného výstupu:** Pred zásahom zmraziť hlavičky a bunky pohľadu Dielce a zlatý VEPO; po zásahu tie isté bunky aj tie isté bajty exportu.

### GR-06 · K · Nová sekcia Štúdia na jednom mieste
- **Čo:** Nová sekcia sa dnes zapisuje trikrát (zoznam v Ruby, ten istý v dvoch JS súboroch) a telo okna je reťaz podmienok. Testy majú celý zoznam vlepený ako text. Každé obnovenie zámerne posiela dáta všetkých sekcií naraz, aby prepnutie sekcie nečakalo na server — to ostáva. Rez: stavitelia obsahu sa registrujú, jeden spoločný push ich všetkých stále zavolá a testy porovnávajú zoznam s ruby konštantou.
- **Dôkaz:** `noxun_engine/ui/studio_dialog.rb:43` · `:55` · `:1595` · `:1601` · `noxun_engine/ui/js/studio.js:62` · `:1455` · `noxun_engine/ui/js/shell.js:350` · `tests/pure/test_st1b_kontrola.rb:336`
- **Scenár:** S5
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — pribudne miesto, kam sekciu registrovať, a zákazka sa stále počíta celá v jednom odoslaní, takže čísla ostanú.
- **Overenie nezmeneného výstupu:** Pred zásahom odtlačok payloadu všetkých štrnástich sekcií na pevnej zákazke; po zásahu ten istý payload.

### GR-07 · K · Predvoľby setov von zo súboru expanzie
- **Čo:** Predvolené sety, staré tvary a dopĺňané mapovania (vrátene pásiem Atira) sedia vnútri súboru, ktorý zároveň rozbaľuje nákup a drží zámok. Nová značka by sa seedovala v tom istom súbore ako nákupná logika. Rez: čistý presun týchto troch tabuliek do vlastného súboru, ktorý sa načíta rovnako; pravidlá „nedotknutý seed prepíš, upravený nechaj“ ostávajú.
- **Dôkaz:** `noxun_engine/core/hardware_sets.rb:236` · `:448` · `:840` · `:1009` · `:1043`
- **Scenár:** S3
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** HARDENING — presun bez zmeny viet, takže knižnica setov aj nákup ostanú; značku to ešte nepridá.
- **Overenie nezmeneného výstupu:** Pred zásahom zlatý `hardware_sets.json` po seedovaní prázdnej knižnice a zlatý nákup; po presune tie isté sety aj tie isté kódy.

## N

### GR-08 · N · Vložiť vedľa suseda s rovnakou linkou
- **Čo:** Ďalšia spodná skrinka v rade dnes začína od prázdnej karty alebo od šablóny. Vedľa seba sa skrinky ukladajú s pevnou medzerou 50 mm, ale výšku, hĺbku a materiál suseda si karta neprevezme. Návrh: pred zápisom do modelu ukázať prevzaté čísla a medzeru a zapísať ich až po potvrdení.
- **Dôkaz:** `noxun_engine/core/cabinet_builder.rb:145` · `:568` · `noxun_engine/ui/panel.rb:133`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — je to nový spôsob vkladania; kým používateľ nepotvrdí, v modeli nič nepribudne, no kritérium stvrdnutia (lacnejšia budúca zmena bez novej funkcie) to nespĺňa.

### GR-09 · N · Niekoľko rovnakých skriniek naraz
- **Čo:** Štyri rovnaké spodné skrinky sa dnes vkladajú po jednej. Kópia v paneli je presná kópia jednej označenej skrinky, nie rad. Návrh: zadať počet a smer a pred zápisom vidieť rad s tou istou medzerou 50 mm.
- **Dôkaz:** `noxun_engine/ui/panel.rb:133` · `noxun_engine/core/cabinet_builder.rb:145` · `noxun_engine/core/bom.rb:1283`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — nová funkcia vkladania; strážca „dva kusy na jednom mieste“ už duplicitu chytí, ale rad ako jeden krok je až po V1.

### GR-10 · N · Ľavá a pravá skrinka zrkadlom
- **Čo:** Drezová vľavo a vpravo sa dnes kreslí znova alebo sa vezme presná kópia, ktorá stranu nezmení. Zrkadlenie existuje len pri rohovej (výmena hrán L1 a L2 na dielcoch, ktoré sa zrkadlením posúvajú). Pri bežnej skrinke by tá istá výmena hrán zmenila olep, a tým aj VEPO.
- **Dôkaz:** `noxun_engine/ui/panel.rb:133` · `noxun_engine/core/construction.rb:590` · `:598`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · áno
- **Návrh zaradenia:** PO V1 — mení výrobné hrany, preto to nie je stvrdnutie; patrí k tomu vlastný zlatý VEPO zrkadlenej skrinky, keď sa bude robiť.

### GR-11 · N · V kusovníku názov skrinky, nielen CAB-002
- **Čo:** Stĺpec Skrinka ukazuje identifikátor a počet kusov. Názov, ktorý je na karte skrinky, sa do bunky nedostane, lebo pripojenie dielca nesie len vlastníka a množstvo. V zákazke s viacerými spodnými skrinkami sa „CAB-002 ×1“ nedá prečítať bez skoku do modelu. Návrh: názov ako zobrazovací doplnok, bez zmeny kľúča riadku a bez exportu.
- **Dôkaz:** `noxun_engine/core/bom.rb:1645` · `noxun_engine/ui/js/studio.js:293` · `_dev/v1audit_shots/studio_01_bom.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — čitateľnosť pre dielňu; výrobu nespúšťa, ale je to nový údaj v okne, nie lacnejšia cesta pre budúci stĺpec (tú rieši GR-05).

### GR-12 · N · Čo sa zmenilo od posledného VEPO
- **Čo:** Po zmene v modeli okno vie povedať len „čísla môžu byť neaktuálne“. Nepovie, ktorá skrinka zmenila rozmer alebo materiál oproti poslednému exportu. Pri živej zákazke sa tak ľahko odreže stará verzia. Návrh: pred exportom zoznam odlišných dielcov, bez zápisu do súborov.
- **Dôkaz:** `noxun_engine/ui/js/studio.js:55`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — nové porovnanie nad už hotovým exportom; samo nič neprepočíta inak, ale nie je to úprava existujúcej cesty bez novej funkcie.

### GR-13 · N · Susedné spodné skrinky na jednej výške linky
- **Čo:** Kontrola neskúma suseda. Dve spodné skrinky vedľa seba môžu mať inú výšku alebo hĺbku a pracovná doska na ne nesadne. Umiestnenie v milimetroch sa už zbiera kvôli sieti „dva kusy na jednom mieste“. Návrh: nález Kontroly, keď sa susedia v rade líšia výškou linky alebo hĺbkou. Geometriu to nemení. Nie je to stráž kolízií.
- **Dôkaz:** `noxun_engine/core/bom.rb:1290` · `noxun_engine/core/cabinet_builder.rb:145`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — nový nález nad číslami, ktoré už v zákazke sú; dielce sa ním neprestavajú.

### GR-14 · N · Hmotnosť celej zákazky v Štúdiu
- **Čo:** Karta skrinky ukazuje hmotnosť dielcov (na snímke približne 25,4 kg) a pri neznámom materiáli povie, že ide o odhad. Štúdio hmotnosť zákazky ani ťažký dielec neukáže nikde, hoci súčet už existuje. Návrh: jedno číslo zákazky a najťažšie dielce, s rovnakým priznaním odhadu ako na karte.
- **Dôkaz:** `noxun_engine/core/bom.rb:1689` · `noxun_engine/ui/panel.html:327` · `_dev/v1audit_shots/inspector_01_korpus.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — odvodený údaj pre nosenie a dopravu; do VEPO nepatrí, kým ho niekto nepožiada ako stĺpec (GR-05).

### GR-15 · N · Kusovník v poradí na stene
- **Čo:** Dielce sú zoskupené podľa materiálu, čo je správne pre pílu. Montáž ide po stene zľava doprava a to poradie okno nemá, hoci pôvod skrinky v milimetroch už v umiestnení je. Návrh: pohľad „ako idú skrinky po stene“, bez zmeny zoskupenia pre VEPO.
- **Dôkaz:** `noxun_engine/core/bom.rb:1304` · `:1650` · `noxun_engine/ui/js/studio.js:273` · `_dev/v1audit_shots/studio_01_bom.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — nový pohľad na dáta, ktoré už zber zbiera; výkresy ani štítky to nenahrádza.

### GR-16 · N · Odrezky medzi zákazkami
- **Čo:** Nárez ukáže najväčší zvyšok na platni (susedné odrezky sa zámerne nespájajú) a po zatvorení zákazky ho zahodí. Ďalšia zákazka ten kus už nevidí. Návrh: sklad odrezkov na tomto počítači, z ktorého sa dá kus vybrať do ďalšieho nárezu. Dnešný výpočet platní bežiacej zákazky ostáva horná hranica, kým používateľ odrezok vedome nepoužije.
- **Dôkaz:** `noxun_engine/core/sheet_layout.rb:777` · `noxun_engine/ui/js/sheet_layout.js:441` · `_dev/v1audit_shots/studio_06_cut.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** PO V1 — nová knižnica kusov; kým sa odrezok do zákazky nepotiahne, počet platní sa nemení.

### GR-17 · N · Z dielca skok na platňu
- **Čo:** Kusovník povie rozmer a materiál, nárez povie, na ktorej platni dielce ležia. Medzi riadkom a obrázkom platne nie je spoj. V dielni sa dielec hľadá prechodom medzi sekciami. Návrh: z riadku otvoriť tú platňu a na nej dielec zvýrazniť.
- **Dôkaz:** `noxun_engine/ui/js/studio.js:287` · `noxun_engine/ui/js/sheet_layout.js:428` · `noxun_engine/core/sheet_layout.rb:768`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** PO V1 — prepojenie dvoch pohľadov, ktoré sa už počítajú; rozloženie na platni nemení.

### GR-18 · N · Rozpracované zákazky na tomto počítači
- **Čo:** Názvy zákaziek sú mapa „cesta súboru → názov projektu“ v nastavení exportu. Nikde nie je zoznam, čo je rozrobené: cesta, názov, kedy sa súbor naposledy otvoril, či kontrola svieti červeno. Návrh: miestny zoznam na tomto počítači. Knižnice medzi počítačmi nerieši.
- **Dôkaz:** `noxun_engine/ui/production_core.rb:280` · `:403` · `:414`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** PO V1 — nový prehľad nad názvami, ktoré už nastavenie drží; súbory zákaziek nikam nekopíruje.

## U

### GR-19 · U · Veta v Kontrole tvrdí, že v modeli nič nie je
- **Čo:** Keď je zvýraznenie hrán vypnuté, lišta vždy povie „Vypnuté — v modeli nie je nič nakreslené.“ Hneď za tým pripíše počty smeru otvárania, ak je ten prepínač zapnutý. Na snímke je Smer otvárania zapnutý a veta o prázdnom modeli sedí v tej istej lište. Veta o prázdne má platiť len keď sú vypnuté všetky tri kresby; stav každej kresby ostáva pri svojom tlačidle.
- **Dôkaz:** `noxun_engine/ui/js/studio.js:796` · `:821` · `:860` · `:896` · `_dev/v1audit_shots/studio_02_ctrl.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie
- **Návrh zaradenia:** PO V1 — opraví klamlivú vetu a nič nepočíta, ale nezlacnie žiadny scenár S1–S5, takže to nie je stvrdnutie.

### GR-20 · U · Automatický názov „projekt“ vyzerá ako vyplnený
- **Čo:** Pri neuloženom modeli server vráti názov `projekt` a pole ho ukáže ako zadanú hodnotu, nie ako sivú nápovedu. Všetky štyri exporty pod týmto menom naozaj pomenujú priečinok. Na snímke je v poli „projekt“, kým okno modelu je bez názvu. Návrh: keď názov stále je ten automatický, pole ho ukáže ako nepotvrdený a tlačidlo VEPO povie, ako sa priečinok bude volať. Samotné slovo `projekt` ostáva, lebo jeho zmena by premenovala súbory.
- **Dôkaz:** `noxun_engine/ui/production_core.rb:268` · `:280` · `:414` · `noxun_engine/ui/js/studio.js:1349` · `_dev/v1audit_shots/studio_01_bom.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** PO V1 — len vzhľad poľa; premenovanie predvoleného slova by zmenilo súbory, preto v tejto položke nie je.

### GR-21 · U · Rovnaký olep na štyroch hranách ako jedna značka
- **Čo:** Stĺpec ABS pri dvierkach opakuje `L1:0,8 · L2:0,8 · W1:0,8 · W2:0,8` na každom riadku. Kódy hrán sa nesmú preložiť na prednú a zadnú, lebo ten istý kód je pri inej role iná fyzická hrana. Návrh: keď sú všetky štyri hrúbky zhodné, v bunke jedna značka („0,8 dookola“) a plné L1–W2 ostanú v už existujúcom titulku.
- **Dôkaz:** `noxun_engine/ui/js/studio.js:314` · `:331` · `_dev/v1audit_shots/studio_01_bom.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** PO V1 — kratšia bunka, páska v dátach aj vo VEPO ostáva po kódoch.

### GR-22 · U · Nápoveda gesta pod náhľadom
- **Čo:** Pod náhľadom je stále riadok „Ctrl+koliesko = zoom · ťahaj plochu = posun pohľadu“. Vety o zónach a čelách sa podľa pohľadu schovajú, tento riadok nie. Na karte korpusu aj kovania zaberá výšku, ktorá v paneli chýba nižšie. Návrh: gestá dať do titulku náhľadu.
- **Dôkaz:** `noxun_engine/ui/panel.html:120` · `_dev/v1audit_shots/inspector_01_korpus.png` · `_dev/v1audit_shots/inspector_02_kovanie.png`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** PO V1 — uvoľní jeden riadok výšky a nič nepočíta; scenár S1–S5 tým nezlacnie.

### GR-23 · U · Rozpočet a jeho nastavenia majú istú ikonu eura
- **Čo:** V navigácii majú Rozpočet aj Nastavenia rozpočtu ikonu eura. Pri zbalenej lište ostanú len ikony, takže dve položky vyzerajú rovnako. Ikona ozubeného kolesa pre nastavenia v okne už je, používa ju prechod z nálezu Kontroly.
- **Dôkaz:** `noxun_engine/ui/js/studio.js:103` · `:140` · `:459` · `noxun_engine/ui/studio.html:22`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** PO V1 — zámena dvoch sekcií pri zbalenej lište; čísla rozpočtu sa kresbou ikony nemenia.

## Doplnky k známym

**R-15.** Štyri exporty opisujú ten istý úvod (zhoda generácie, červené polia, čerstvé nastavenie, čerstvý zber, novšia schéma, brána chrbta) a až potom sa rozídu: VEPO `production_core.rb:1921`, CSV kovania `:2029`, rozpočet `:3495`, cenová ponuka `:3580`. Spoločná príprava exportu je menší prvý rez než celý balík výstupu. Slovenské mená rolí sú v tom istom súbore okna (`:1813`), kým meno, ktoré ide do riadku VEPO, je výrobné meno zo stavby (`construction.rb:1856`, číta ho `VepoExport.row_name` podľa `bom.rb:1636`). Nový výstup si môže vziať nesprávny slovník.

**R-38.** V `vepo_settings.json` nie sú len prepínače VEPO. Je tam aj mapa názvov zákaziek a posledný priečinok, z ktorých čerpajú všetky štyri exporty (`production_core.rb:280`). Dávka, ktorá súboru doplní ochranu pri pokazenej revízii, je vhodná chvíľa presunúť úložisko do jadra bez zmeny tvaru JSON.

## Čo som nestihol / neistoty

Snímky `studio_03` až `studio_05`, `studio_07` až `studio_14`, zóny a čelá v paneli a dlhé varianty som neotvoril. Súbory pravidiel kovania, katalógu a payloadov som nečítal riadok po riadku. Metódu `VepoExport.row_name` som neotvoril — väzbu mena dielca na VEPO opieram o komentár v kusovníku a o screenshot stĺpca Dielec. Názov `projekt` som sledoval po funkciu, ktorá ho exportom vracia, nie po skutočný názov priečinka na disku. Šablóny bez diakritiky (`Dolna klasik`, `Drezova`) sú v jadre, nie v UI, preto nie sú položkou U. Cestu „nahraď dekor a ukáž rozdiel ceny ešte pred zápisom“ som nenašiel ako konkrétnu funkciu, tak som ju do karty nedal. Testy som nespúšťal.
