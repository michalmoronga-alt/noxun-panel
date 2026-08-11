# Dogfooding — archív histórie zápisníka

> **ARCHÍV (založený 11.8.2026, dávka U2).** Uzavreté a historické sekcie presunuté zo živého zápisníka [../08_DOGFOODING.md](../08_DOGFOODING.md): priebežné stavy zápisníka, schválená 2A migračná mapa, hardening a slovné sedenia V0.5, priebeh testovania seedu a zodpovedané otázky pre Michala. Texty sú pôvodné, upravené sú výhradne relatívne cesty odkazov.
> Plné texty vyriešených D-čísel sú vedľa v [DOGFOODING_vyriesene.md](DOGFOODING_vyriesene.md), história dávok a etáp v [KRONIKA.md](KRONIKA.md); živý zápisník drží už len otvorené postrehy.

## Priebežné stavy zápisníka (19.7. – 11.8.2026)

*(Pôvodná hlavička živého zápisníka — datované odseky „Stav k…", ktoré rástli s každou dávkou.)*

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú do archívu [DOGFOODING_vyriesene.md](DOGFOODING_vyriesene.md) (plné texty s PR); tu ostáva jednoriadkový index. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia). Stav k 24.7.: zápisník ČISTÝ — žiadne otvorené blokery ani spomaľovače.
>
> **Stav k 11.8. — uzáver pracovnej série okolo zákazky KLINIKA (v0.5.49 → v0.5.60, PR #144–#154).** Vyriešené a v archíve: **D-90** (úchytkový profil UKW-7 vrátane opravy zrkadlového vykreslenia), **D-91** + **D-92** (Katalóg kovania z hlavičky panela, rozpis „čo sa reálne kúpi"), **D-97** + **D-98** (hint neznámeho typu, „Dekor u dodávateľa" pre kompakty), **D-100** (živé názvy skriniek + premenovanie), **D-88** + **D-102** (farba ABS na hranách v modeli, „podľa pravidla" povie čo vybralo), **D-103** (tichá duplicita pri násobení kópií `*4`), **D-104** + **D-105** (kontrola hrán v modeli — tri stavy s prepínačmi). Testy: **1163 headless · 29 JS sád · 302 in-SketchUp scenárov**.
>
> **Vyriešené po uzávere série (11.8.):** **D-93** ručný zámok nominálnej dĺžky výsuvu (PR #156, **v0.5.61**) — dĺžka sa vyberá v riadku kovania a drží aj pri zmene hĺbky skrinky; plný text v archíve.
>
> **Otvorené D-čísla (stav k 11.8.):** **D-94** traceability súpisu kovania (rozklik položky na skrinky a čelá; dáta `sources` už existujú) · **D-95** režim krížovej kontroly „diel po diele" (D-104/D-105 sú jeho vizuálny základ; chýba odškrtávanie so stavom v zákazke, rozmery a kovanie) · **D-96** úchytkový profil z ikoniek pri čelách do vlastnej sekcie „Úchytky" · **D-99** nereprodukovaný zobrazovací glitch pri premenovaní dielca (sleduje sa) · **D-101** panel sa po Späť/Znova neobnoví sám (nie je regresia — plugin nemá undo sync pre nič; vlastná malá dávka s auditom a in-SU behom). K nim ďalej bežia staršie otvorené body nižšie v sekciách (D-77, D-84, D-85, D-86, D-89a a nápady na zváženie).
>
> **Stav k 6.8.:** **dávka E KOMPLET** (PR #137–#140, v0.5.45 → **v0.5.48**) — zákazka má peňažnú vrstvu: **rozpočet** (sadzby zo syntézy reálnych rozpočtov, cenové režimy, upozornenia a overridy, XLSX v Luciinom formáte), **cenová ponuka** (zákaznícky pohľad, „Nábytková zostava" ako automatický zvyšok, firewall na interné pojmy) a **„Prepočítať ceny"** (hromadné obnovenie cien viazaných na Demos). Zo zápisníka sa vyriešil **D-61** (ceny za celé tabule) → archív. Vedome odložené kúsky sú nižšie v „Nápady na zváženie". Zo smoke testu V1 ostával v tej chvíli otvorený jediný nález — **D-77**. *(Stav platí k uzáveru dávky E, PRED testom na reálnej zákazke — aktuálny prehľad otvorených bodov je v odseku nižšie.)*
>
> **Stav k 10.8.:** Z reálnej zákazky prišiel **D-103 — tichá dátová chyba: násobenie kópií (`*4`) vyrobilo jednu dosku DVAKRÁT na tom istom mieste** (dvojitý dielec v kusovníku, VEPO aj rozpočte). Príčina je nájdená živou reprodukciou a **vyriešená** (PR #151, v0.5.57, plný text v archíve). K záverečnej kontrole olepov na KLINIKE pribudla **D-104 — „Zvýrazniť hrany bez olepu"** (v0.5.58) a hneď po nej **D-105 — prepínače kontroly hrán** (v0.5.59): z jedného červeného stavu sú **tri** (chýba podľa pravidla · neolepené mimo pravidla · olepené), každý s vlastným prepínačom a živým počtom, zelená navyše len na tom, čo je v modeli označené. Obe sú **základom** väčšieho režimu **D-95**, ktorý ostáva otvorený.
>
> **Stav k 9.8.:** Michal testuje **kovanie** na reálnej zákazke. Dva nálezy sú vyriešené hneď (**D-91** Katalóg kovania z hlavičky panela, **D-92** „čo sa reálne kúpi" v sekcii Kovanie — obe v archíve); štyri ostávajú otvorené: **D-93** ručný override NL výsuvu (spomaľovač — automat z hĺbky nesedí s tým, čo sa reálne kupuje), **D-94** traceability v súpise kovania, **D-95** režim krížovej kontroly „diel po diele" (cieľ: KLINIKA ako prvý referenčný projekt čisto z pluginu) a **D-96** úchytkový profil do vlastnej sekcie „Úchytky". Z tej istej práce so zákazkou pribudli a hneď sa aj vyriešili dva materiálové nálezy — **D-98** (kompaktná doska sa nedala oceniť, lebo Egger vedie kompakt dekoru F800 pod vlastným číslom F8001) a **D-97** (preklep v type dosky prešiel bez hlesnutia) — obe v archíve, PR #148.
>
> **Test dávky E na reálnej zákazke beží** (Michal 6.8.) — jediná chyba testu, **E-03** (doska s UNI materiálom sa nedala vložiť s vlastnou hrúbkou), je opravená hotfixom **PR #142, v0.5.49** (plný text v archíve, D-číslo nedostala). Zvyšok postrehov z testu je zapísaný nižšie ako **D-84 až D-89**: dve UX drobnosti (D-84, D-86), dva spomaľovače (D-85 vyhľadávanie v selectoch materiálov, D-89 orientácia hrán pri olepení) a dva nápady na zváženie (D-87 smer štruktúry v modeli, D-88 farba hrany podľa ABS). **D-88 je od 9.8. vyriešená** (PR #150) — spolu s ňou aj časť (b) postrehu D-89 ako **D-102**.
>
> **Stav k 4.8.:** **dávka H KOMPLET** (PR #131–#135, v0.5.44) — všetkých osem riešiteľných nálezov smoke testu V1 z 3.8. (fiktívna zákazka, 12 skriniek + 4 dosky — kovanie checklist **6/6** vrátane „Z Demosu" a CSV exportu, semafor ČISTÝ po nahradení UNI reálnymi dekormi) je vyriešených a v archíve: D-75, D-76, D-78, D-79, D-80, D-81, D-82, D-83. Otvorený ostáva jediný nález testu — **D-77** (preradený do plošného UI reworku). Zápisník je opäť **bez otvorených blokerov aj spomaľovačov**; väčšie celky drží vízia uzatvorenia V1: [../10_V1_VIZIA.md](../10_V1_VIZIA.md).

## Uzáver V0.5 — hardening a slovné sedenia (od 24.7.)

Stabilizácia pred V0.6 = **spoločné prechádzky funkčnosťou v krátkych jasných krokoch**: ujasnenie pojmov a špecifických funkcií naprieč sedeniami, podstatné veci sa dopĺňajú do dokumentácie (glosár + poznatky: [../09_POJMY.md](../09_POJMY.md)). Plán sedení: ① vkladanie+korpus · ② zóny+čelá · ③ materiály+ABS+dekory (aj otvorené otázky z 09_POJMY) · ④ kovanie · ⑤ Výroba+VEPO+semafor. K tomu:

- **Katalóg materiálov (Demos):** Michalov zoznam (25.7.) spracovaný do seed podkladu nižšie; 90 % materiálu/kovania/ABS ide z demos-trade.sk. Otvorená debata V0.6: „zadaj kód → plugin načíta dáta" (verejné vyhľadávanie kód→položka aj dekor→celá skupina s cenami; Konfigurátor cenníkov za loginom) + **pracovné dosky v dekorovej skupine** (otázky 1–3 v 09_POJMY).
- **Hardening zoznam:** jediný otvorený bod tohto zoznamu (manuálne overenie redo Ctrl+Y po zlúčených transparentných operáciách) žije ďalej v zápisníku [../08_DOGFOODING.md](../08_DOGFOODING.md), skupina STABILITA.
- **Priebeh testovania seedu (27.7.):** beží — nové D-43 (duplák), D-44 (výber výrobcu/typu), D-45 (bloker 18,6). Funguje: zmena formátu platne podľa postupu (MG Cashmere → 2800×2050 ✓).

### Seed katalógu — ZRUŠENÝ ako krok (Michal 10.8.); podklad ostáva v [../zdroje/SEED_KATALOG_2026-07.md](../zdroje/SEED_KATALOG_2026-07.md)

Pôvodná tabuľka z 25.7. (12 dekorov na ručný batch) je zlúčená a rozšírená v konsolidovanom SEED_KATALOG dokumente (§1.1 jadro s Disk frekvenciami + §1.2 druhá vlna z reálnych zákaziek). Vkladať sa malo cez **„Pridať z Demosu"** (M-A — rodina s kódmi/cenami/fotkou z 1 URL), nie ručným batchom; Falco/Kastamonu (bez DK, cez VEPO) ručne. Zaradenie bolo „posledný materiálový krok pred dávkou D" (rozhodnuté 2.8.). **Prekonané 10.8.:** hromadné naplnenie katalógu sa **robiť nebude** — katalóg si narastie **sám prácou na zákazkách** (každá pridá presne tie dekory, ktoré sa reálne kupujú). Skutočný problém nie je objem dát, ale **NÁJSŤ materiál aj v malom zozname** — teda UX výberov (D-85 zdieľaný combobox, UI 2.0). Dokument ostáva ako podklad a zdroj kódov, nie ako naplánovaná dávka.

## 2A migračná mapa — ✅ SCHVÁLENÁ, kanonický podklad pre 2A-2 (Michal 30.7.: „mapa OK — Pracovná doska zmaž, Halifax zlúč")

| Dnes (kľúč skupiny) | Po migrácii: výrobca · číslo · názov | Štruktúra variantov | Poznámka |
|---|---|---|---|
| K009 PW (Kronospan) | Kronospan · **K009** | PW | dosky 16+18 aj obe pásky |
| Biela HDF (Kronospan) | Kronospan · **Biela HDF** | — | vlastný kľúč bez čísla/štruktúry |
| W1000 ST9 Biela (Egger) | Egger · **W1000** · Biela | ST9 | |
| U750 ST9 Taupe šedá (Egger) | Egger · **U750** · Taupe šedá | ST9 | |
| H1180 ST37 Dub Halifax prírodný (Egger) | Egger · **H1180** · Dub Halifax prírodný | ST37 | |
| 5981 MG Cashmere (Kronospan) | Kronospan · **5981** · Cashmere | MG | |
| Biela korpus (vlastný) | vlastný · **Biela korpus** | — | |
| UNI (vlastný) | vlastný · **UNI** | — | |
| „Halifax Tabakový PD␣" (DTDL 38, 4200×600!) | **ZLÚČIŤ** do skupiny **Halifax Tabakový** ako variant **typ PD, 38 mm, 4200×600** | — | trailing space preč; typ DTDL→PD (bola obchádzka pred D-44) |
| „Halifax Tabakový␣" (len ABS 1,0) | vlastný · **Halifax Tabakový** | — | trailing space preč; skupina spoločná s PD variantom vyššie |
| Pracovna doska (len osirotená ABS páska) | **ZMAZAŤ — SCHVÁLENÉ** (testovací zvyšok bez dosky) | — | jediné zmazané ID migrácie |

*(ID záznamov sa NEmenia — s výnimkou schváleného zmazania vyššie ostanú modely platné; menia sa len skupinové polia. Legacy „univerzálne" pásky bez šírky dostanú `universal` až keď ich tak označíš — default = neznáma štruktúra.)*

## Otvorené otázky (na Michalovo posúdenie pri teste) — zodpovedané cutoverom 2A-4b

- **Cutover katalógu na SCHEMA 2 (2A-4b) — čo uvidíš po merge + INSTALL + reštarte SketchUpu:**
  1. Pri prvom štarte sa katalóg materiálov **sám jednorazovo zmigruje** (žiadne okno nevyskočí — priebeh je v Ruby konzole ako `[NOXUN::Engine] materialy: katalog zmigrovany...`). Zmigrujú sa len skupinové polia — **ID záznamov sa nemenia**, existujúce projekty bežia ďalej; zmaže sa jedine schválená osirotená páska „Pracovna doska".
  2. **Záloha:** pôvodný katalóg je bajtovo odložený v `%APPDATA%\NOXUN\Engine\materials.pre-schema-2.json` (nikdy sa neprepisuje). Ak by bolo treba späť: okno Materiály → červený pás → tlačidlo **„Obnoviť predmigračnú zálohu"** (aktuálny súbor sa odloží bokom, nič sa nemaže; najbližší štart migráciu preskočí, aby si mal čas na opravu — ďalší už migruje normálne).
  3. V okne Materiály uvidíš žltý pás **„3 pásky nemajú štruktúru ani príznak univerzálna"** — to sú Halifax Tabakový / Biela korpus / UNI (jednofarebné bez štruktúry). Otvor ich skupiny a na páskach zapni **prepínač „univerzálna"** (ikona glóbusu pri páske) — picker ich potom začne vyberať; kým to nespravíš, tie dekory hlásia ORANGE „bez ABS" a pásku vyberieš ručne.
  4. Dlaždice katalógu sú po novom **skupiny: výrobca · číslo · názov** (rovnaké číslo u dvoch výrobcov = dve dlaždice) a detail je členený podľa štruktúry povrchu; batch „Nový dekor" má polia číslo + názov + štruktúra pri variante.
