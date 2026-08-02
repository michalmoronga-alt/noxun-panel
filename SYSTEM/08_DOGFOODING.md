# Dogfooding zápisník (živý dokument)

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú do archívu [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md) (plné texty s PR); tu ostáva jednoriadkový index. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia). Stav k 24.7.: zápisník ČISTÝ — žiadne otvorené blokery ani spomaľovače.

## Blokery (bránia dokončeniu zákazky)

*(momentálne žiadne — D-67/D-68 vyriešené PR #109)*

## Spomaľovače (vysoká priorita)

*(momentálne žiadne — D-70 vyriešené PR #111)*

## UX drobnosti (nízka priorita)

- **D-61 · Ceny za KUS/tabuľu, nie €/m²** (Michal 1.8.) — plošné materiály sa kupujú po celých tabuliach (1,2 platne = kupujem 2); €/m² len interná jednotka. *UI: cena za tabuľu primárne (m²×formát), m² sekundárne; ABS €/bm OK. VÄZBA NA DÁVKU E: sumár musí rátať celé kusy.*

## Nápady na zváženie (nerozhodnuté)

- **D-48 · Zdieľaná knižnica pre 2 PC (Michal + Lucia)** (Michal 31.7. večer) — obe pracoviská majú zobrazovať ROVNAKÉ šablóny aj materiály (spolupráca, posúvanie projektov). Jednotný zdroj = **firemný Google Disk** (sú tam všetky firemné veci). Dotýka sa: katalóg materiálov, šablóny korpusov, pravidlá kovania (dnes všetko v lokálnom %APPDATA%). *Stav: na návrhovú dávku — sync/zdieľanie cez G-Disk priečinok.*
- **D-50 · OCL inšpirácia UI/UX** (Michal 31.7. večer) — pár detailov z OCL flow prevziať; najprv slovné prebratie (sedenie), potom zapracovanie. *Stav: čaká na sedenie.*
- **D-51 · Štandard veľkostí okien a tlačidiel** (Michal 31.7. večer) — zjednotiť šírky, rozmery a rozmiestnenie naprieč oknami (panel, Materiály, Výroba, Pravidlá, Šablóny) — dohodnúť konkrétne hodnoty do UI_DIZAJN.md **pred prvým testovaním Lucie („skúška ohňom")**. *Stav: na UI dávku pred nasadením u Lucie.*
- **D-52 · Tlačidlo „Aktualizovať" (auto-update pluginu)** (Michal 31.7. večer) — jednoklikový update na najnovšiu verziu, distribučný kanál možno G-Disk; hlavne pre Luciu (nech Michal nemusí posielať súbory). *Stav: na návrhovú dávku (spolu s D-48 kanálom).*
- **D-53 · UNI materiál — modelovanie bez záväzku** (Michal 31.7. večer) — pri modelovaní bez jasných materiálov zvoliť **UNI**: univerzálny materiál použiteľný všade, bez ceny/kódov; hrúbka/dekor neobmedzujú prácu a konkrétne materiály sa navolia **aj na konci** projektu. *Stav: **VYRIEŠENÉ KOMPLET** — PR #103 (M-B1: 5 UNI materiálov, hrúbku určuje dielec, semafor, zákazy) + PR #114 (M-B2: sekcia „Pracovné (UNI)" + badge, „Nahradiť UNI…" hromadná zámena s rozpisom dopadu a 1 undo). Presunúť do archívu pri najbližšom uzávere.*

- **D-15 · UX vzor: „pridávačky" ako modal** (Michal 19.7.) — všetky akcie „pridať niečo" (šablóna, materiál, …) zjednotiť na modal s formulárom. Napĺňa sa postupne (prvý bol D-14; materiál formulár sa prerobí neskôr).
- **D-26 · Režim Jednoduchý/Rozšírený** (Michal 19.7. večer, debata) — prepínač v UI: jednoduchý = najčastejšie polia, rozšírený = všetko (tvorba šablón, špeciálne zostavy). Rozhodnuté MIESTO samostatného okna Nastavenia (nastavenie ostáva pri svojom poli). *Stav: čaká na dáta z merača D-25 (čo reálne skrývať) — pár týždňov zberu.*
- **D-27 · Rýchle zobraziť/skryť tagy z panela** (Michal 19.7. večer) — mini prepínače priamo v paneli (Čelá 👁 · Chrbát 👁 …) v logike Ghost checkboxu, nech sa nepreklikáva do SketchUp Tags. *Stav: zápis bokom, kandidát na budúcu UX dávku.*
- **D-28 · Textúry materiálov (render)** (Michal 19.7. večer) — *Stav: **ZLÚČENÉ do dávky M-R** (roadmapa „Materiály — dokončenie", 2.8.): texture_path + render vlastnosti + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 orientácia podľa smeru dekoru. Zaradenie: po dávke D, pred UI 2.0 (Luciina priorita).*

## Návrhy väčších celkov (na rozpracovanie)

- **D-69 · Jednotný editor materiálov** (Michal 1.8. neskoro večer, smoke F8100/zástena) — editor variantov nie je prispôsobený novému systému: niektoré údaje server vyžaduje, ale používateľ ich nemá kde zadať/skontrolovať (formát, URL, dodávateľ, kód, stav väzby). Odporúčanie: JEDNO spoločné modálne okno pre pridanie z Demosu / ručné pridanie / editáciu / dopĺňanie / opravy — rovnaké polia bez ohľadu na vstupný bod. *Zaradenie: UI 2.0 dávka (OCL smer, D-50) — spája sa s D-15 („pridávačky ako modal“) a D-51 (štandard okien); akútne diery kryjú D-67/D-68 (M-A3c) a D-60/D-62 (M-A3b).*
- **D-20 · Quick actions — bezpečný move plugin** (Michal 19.7., „pre budúceho Michala a Fable, keď bude základ top 😉") — zlúčiť funkčné pluginy noxun_mower + Snaper do jedného toolbar pluginu (rýchly pohyb, kopírovanie, rotácie, prisunutie na doraz). **Známy poznatok:** mower „rýchla kópia skrinky vedľa" vytvorí kópiu LEN ako geometriu — bez NOXUN identity kabinetu (kópia mimo observer/dedup flow). Pri stavbe quick actions kopírovanie prerobiť tak, aby kópia prešla štandardným dedup tickom (plná identita + config). *Stav: budúcnosť (po V1 / pri zostavách).*
- **D-09 · Snap body pri presúvaní priečok** (1/4, 1/2, 3/4…) v zónovom náhľade. *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-16 · Autocomplete dekoru** (Michal 19.7.) — pri výbere materiálu/ABS písať názov z katalógu, návrhy sa dopĺňajú za každým písmenom, → a Enter potvrdí. *Stav: ODLOŽENÉ (Michal 19.7. večer — „nice to have"), v zásobe.*

## Uzáver V0.5 — hardening a slovné sedenia (od 24.7.)

Stabilizácia pred V0.6 = **spoločné prechádzky funkčnosťou v krátkych jasných krokoch**: ujasnenie pojmov a špecifických funkcií naprieč sedeniami, podstatné veci sa dopĺňajú do dokumentácie (glosár + poznatky: [09_POJMY.md](09_POJMY.md)). Plán sedení: ① vkladanie+korpus · ② zóny+čelá · ③ materiály+ABS+dekory (aj otvorené otázky z 09_POJMY) · ④ kovanie · ⑤ Výroba+VEPO+semafor. K tomu:

- **Katalóg materiálov (Demos):** Michalov zoznam (25.7.) spracovaný do seed podkladu nižšie; 90 % materiálu/kovania/ABS ide z demos-trade.sk. Otvorená debata V0.6: „zadaj kód → plugin načíta dáta" (verejné vyhľadávanie kód→položka aj dekor→celá skupina s cenami; Konfigurátor cenníkov za loginom) + **pracovné dosky v dekorovej skupine** (otázky 1–3 v 09_POJMY).
- **Hardening zoznam:** manuálne overiť redo (Ctrl+Y) po zlúčených transparentných operáciách (pozorovanie zo 17.7.).
- **Priebeh testovania seedu (27.7.):** beží — nové D-43 (duplák), D-44 (výber výrobcu/typu), D-45 (bloker 18,6). Funguje: zmena formátu platne podľa postupu (MG Cashmere → 2800×2050 ✓).

### Seed katalógu — PREKONANÉ, kanonický podklad je [zdroje/SEED_KATALOG_2026-07.md](zdroje/SEED_KATALOG_2026-07.md)

Pôvodná tabuľka z 25.7. (12 dekorov na ručný batch) je zlúčená a rozšírená v konsolidovanom SEED_KATALOG dokumente (§1.1 jadro s Disk frekvenciami + §1.2 druhá vlna z reálnych zákaziek). Vkladať sa bude cez **„Pridať z Demosu"** (M-A — rodina s kódmi/cenami/fotkou z 1 URL), nie ručným batchom; Falco/Kastamonu (bez DK, cez VEPO) ručne. **Zaradenie: posledný materiálový krok pred dávkou D** (rozhodnuté 2.8., roadmapa „Materiály — dokončenie").

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

## Otvorené otázky (na Michalovo posúdenie pri teste)

- **Cutover katalógu na SCHEMA 2 (2A-4b) — čo uvidíš po merge + INSTALL + reštarte SketchUpu:**
  1. Pri prvom štarte sa katalóg materiálov **sám jednorazovo zmigruje** (žiadne okno nevyskočí — priebeh je v Ruby konzole ako `[NOXUN::Engine] materialy: katalog zmigrovany...`). Zmigrujú sa len skupinové polia — **ID záznamov sa nemenia**, existujúce projekty bežia ďalej; zmaže sa jedine schválená osirotená páska „Pracovna doska".
  2. **Záloha:** pôvodný katalóg je bajtovo odložený v `%APPDATA%\NOXUN\Engine\materials.pre-schema-2.json` (nikdy sa neprepisuje). Ak by bolo treba späť: okno Materiály → červený pás → tlačidlo **„Obnoviť predmigračnú zálohu"** (aktuálny súbor sa odloží bokom, nič sa nemaže; najbližší štart migráciu preskočí, aby si mal čas na opravu — ďalší už migruje normálne).
  3. V okne Materiály uvidíš žltý pás **„3 pásky nemajú štruktúru ani príznak univerzálna"** — to sú Halifax Tabakový / Biela korpus / UNI (jednofarebné bez štruktúry). Otvor ich skupiny a na páskach zapni **prepínač „univerzálna"** (ikona glóbusu pri páske) — picker ich potom začne vyberať; kým to nespravíš, tie dekory hlásia ORANGE „bez ABS" a pásku vyberieš ručne.
  4. Dlaždice katalógu sú po novom **skupiny: výrobca · číslo · názov** (rovnaké číslo u dvoch výrobcov = dve dlaždice) a detail je členený podľa štruktúry povrchu; batch „Nový dekor" má polia číslo + názov + štruktúra pri variante.

## Trvalé UI/UX pravidlo (Michal 20.7. — platí pre všetku ďalšiu prácu na paneli)

**VERTIKÁLNY priestor panela je vzácny.** Pred umiestnením každého nového tlačidla/poľa/funkcie sa POVINNE zamyslieť, či sa nedá umiestniť inak a rozumnejšie (do existujúceho radu, do rohu náhľadu, ako ikona, kontextovo) — rast do výšky len v krajných prípadoch. Inak panel skončí ako scrollovanie cez 20 tlačidiel a 30 sekcií.

## Vyriešené — index (plné texty v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md))

- **D-74** zhody našeptávača ťažko čitateľné (bez diakritiky/formátovania) + chýbala kontrola linku (Michal 2.8.) — labely formátované (VEĽKÉ kódy, kapitalizácia, rozmery „23/0,8" / „2800×2070 · 8 mm"; diakritika technicky nejde — slug ju nemá, plné názvy dá až fetch rodiny), tlačidlo „Otvoriť na Demose" pri každej zhode so server sanitize — PR #121; **Michal 2.8.: „funguje výborne"**
- **D-73** dve kompakty rôznych šírok hlásili „ten istý variant" (Michal 2.8., smoke F206 — 4100×920 vs 4100×650) — kompakt má šírok veľa ako PD; formát platne pridaný do identity variantu cez registrový flag (dedup, ID token, povinnosť pri zakladaní, nemennosť pri edite automaticky) — PR #120
- **D-72** protiťahová (jednostranná) zástena sa nedala založiť z Demosu (Michal 2.8., smoke F206 — „zástena neuvádza oba dekory") — parameter nesie len líce, rub je protiťah; single je po novom legálny na hlavičke rodiny, verify aj lookupe, variant vzniká bez back polí; prísnosť na 3+ časti/prázdne líce ostáva — PR #119
- **D-49b** create-time/hrúbková automatika dupláku — ZAVRETÉ bez implementácie (Michal 2.8.: pôvodný zámer bol „pri vkladaní 18-ky do katalógu sa 36-ka vytvorí sama"; selectová ponuka z D-49 vyhodnotená ako lepšia — „funguje ešte lepšie")
- **D-49** duplák automaticky — selecty tela/dielca/dosky ponúkajú „×2 → 36 (duplák)" pri každej reálnej DTDL/MDF doske; výber duplák dovytvorí (idempotentne, guardy UNI/kupovaná 36-ka/reťazenie; duplák už nededí demos väzbu ani uni flag); vklad dosky a projektové predvoľby virtuály nevidia; Michal potvrdil 2.8. „funguje bez výhrad" — PR #116
- **D-66** zástena priamo z Demosu — rub sa číta z PARAMETROV stránky (živé overenie vyvrátilo „rub je len v adrese"); rodina ju ponúka ako dosku, založí sa s rubom (identita, ID s R-tokenom, dedup), „Aktualizovať z Demosu" na zástene funguje; bez auto-návrhu pásky — PR #115
- **D-53** UNI dotiahnuté: sekcia „Pracovné (UNI)" + badge; „Nahradiť UNI…" — hromadná zámena UNI za reálny dekor s rozpisom dopadu pred potvrdením (skrinky/dosky/predvoľby/hrúbky/ABS), odtlačok plánu proti súbežným zmenám, 1 undo — PR #114
- **D-71** URL väzba sa dá ručne pridať/upraviť/zmazať v edit formulári variantu (ceruzka; server sanitize — len demos-trade.sk; zmena/zmazanie ruší dátum overenia ceny; UNI pole nemá; zlá adresa nezatvára formulár). Vedomé zúženie: batch „ručne…" URL pole nemá — väzba sa dopĺňa editom po vytvorení — PR #112
- **D-70** „Aktualizovať z Demosu“ číta uloženú väzbu — variant s demos_url sa fetchuje priamo (žiadne „viac kandidátov“ pri čelných hranách, funguje aj bez sitemap cache); hľadanie len pre nezviazané; zastaraná väzba = jasná hláška; základ „Prepočítať ceny“ dávky E — PR #111
- **D-67** výber typu/výrobcu z ponuky nereagoval (CEF datalist bug) — vlastný suggest dropdown s mousedown potvrdením, šípkami/Enter/Escape a diakriticky necitlivým filtrom; aj inline editor výrobcu — PR #109
- **D-68** formát platne pre dopísané hrúbky (zástena 9,2 už nie je slepá ulička) — pruh „Formát výnimiek" per hrúbka; nová gramatika: čiarka bez medzery = desatinná (9,2 = 9,2 mm; koniec tichého rozpadu 9,20 → 9+20), položky oddeľuje čiarka s medzerou/bodkočiarka; inline `20/4100x600` ostáva — PR #109
- **D-59** rodina informatívne označuje „už v katalógu“ podľa kódu (sivý riadok, checkbox aktívny — kolízia kódov nesmie zamykať; auto-návrh pásky ich preskakuje) — PR #108
- **D-60 + D-56** URL väzba viditeľná: ikona v riadku variantu s dátumom overenia ceny + „Otvoriť u dodávateľa“ (URL výhradne zo servera, čerstvý sanitize — audit) + badge na dlaždici skupiny — PR #108
- **D-62** fotka dekoru aj v hlavičke detailu skupiny — PR #108
- **D-63** názvy dlaždíc dvojriadkovo (clamp) + plný názov v tooltipe — PR #108
- **D-55** pás „pridávam do existujúcej skupiny“ výrazný (plný akcent); zvyšok zúžený po audite (filter článkov = PR #106) — PR #108
- **D-64** ABS pásky tretích strán (Rehau…) padali na kontrole výrobcu — pásky sa overujú dekorom v adrese (mimo koncových rozmerov) + rozmermi; brand check len dosky — PR #106
- **D-65** slug prefixy zo sitemap analýzy 48k: dtd-laminovana→DTDL, mdfl/mdfs→MDF, kd-in/kd-ex→KOMPAKT, pracovni-deska→PD, absl/abs-→ABS; jedna autorita klasifikácie + filter článkov bez číslic; mdfd (dyhovaná) vedome mimo — PR #106
- **D-58** ABS z Demosu dedí štruktúru povrchu z rodiny (stránky pások ju neuvádzajú; „Štruktúra hrán“ výrobcu pásky sa vedome nečíta) — PR #106
- **D-57** upratanie knižnice materiálov (1.8. večer: katalóg 27/23→13/12 — UNI sada pod fallback ID, staré textové skupiny zmazané, pravidlo „len UNI + Demos-kompatibilné“; šablóny všetky dedia; záloha materials.pred-upratanim-20260801) — jednorazová akcia, bez PR
- **D-43** duplák 36 = 2×18 (väzba na zdroj + násobič, všetko ostatné derivované; väzba vo výrobnom snapshote; odhad platní prelieva plochu do zdroja; katalóg SCHEMA 3 lazy; batch čip vedome odložený) — PR #94
- **D-47** hlavička panela — tlačidlo Materiály vedľa Výroby (rovnako široké), 3 taby rovnako široké s ikonami, pod 400 px akcie icon-only — PR 2A-4b (TBD)
- **D-46** projektová predvoľba korpusu s inou hrúbkou (potvrdzovacia lišta namiesto tvrdého stopu — dediace skrinky prevezmú hrúbku v 1 kroku Späť) — PR #86
- **D-44** rýchle zadávanie materiálov (našepkávač výrobcu/typu, formát platne rovno v dávke „Nový dekor", nezadaný formát sa neukladá) — PR #84
- **D-45** slučka hrúbka ↔ materiál pri 18,6 (materiál prevezme hrúbku · hrúbka si doberie materiál · vklad sa prispôsobí) — PR #83
- **D-42** dekorový katalóg UI (mriežka, kód+dodávateľ, cena „nezadaná", inline bunky, preset-čipy) — PR #74–#76
- **D-41** dekorové skupiny materiál↔ABS (šírka ABS, picker, remap, modal chýbajúcej pásky) — PR #70–#72
- **D-40** panel visel po vložení (DC observer pasca scaletool) — PR #64 · **D-39** zámky vkladacej karty — PR #61 · **D-38** chrbát „pevný 18" preflight — PR #59 · **D-37** hĺbka = celková vrátane chrbta — PR #59 · **D-36** ABS odporúčané k dekoru — PR #67 · **D-35** olep 4 hrán klikom — PR #60 · **D-34** panel po zmazaní skrinky — PR #61 · **D-33/D-32** šablóna aplikuje všetko + serverová kópia — PR #61 · **D-31** skrinka bez chrbta — PR #59 · **D-30** výstuhy default ABS predná — PR #60
- **D-29** dvojradová hlavička + tokeny + ikonový sprite — PR #66 · **D-25** merač používania — PR #50 · **D-24** krídla 1–4 — PR #54 · **D-23** orientácia riadkov čiel — PR #55 · **D-22** odomykateľný limit presahov — PR #54 · **D-21** výrazy v čelách (existovalo) · **D-19** odhad platní — PR #53 · **D-18** čelo „BEZ" — PR #52 · **D-17** sokel plná šírka — PR #45 · **D-14** uložiť šablónu z panela (existovalo)
- **D-13** default zapustenia sokla 40 — PR #45 · **D-12** zoom len Ctrl+koliesko — PR #45 · **D-11** kóty sokla/tela — PR #45 · **D-08** režimové taby — PR #43 · **D-07** medzery/presahy čiel — PR #41 · **D-06** scale maska 120 — PR #38 · **D-05** správa katalógu materiálov — PR #39 · **D-04** ghosty default vypnuté — PR #38 · **D-03** police discoverability — PR #42 · **D-02** debounce náhľadu — PR #38 · **D-01** náhľad rastie s oknom — PR #38
- Smoke test 20.7. (testy 1–11) + **VEPO krížová validácia 26=26** (PR #58) — plný záznam v archíve
