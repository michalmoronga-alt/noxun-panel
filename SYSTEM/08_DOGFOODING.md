# Dogfooding zápisník (živý dokument)

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú do archívu [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md) (plné texty s PR); tu ostáva jednoriadkový index. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia). Stav k 24.7.: zápisník ČISTÝ — žiadne otvorené blokery ani spomaľovače.

## Blokery (bránia dokončeniu zákazky)

*(momentálne žiadne — D-45 vyriešené PR #83)*

## Spomaľovače (vysoká priorita)

*(momentálne žiadne)*

## UX drobnosti (nízka priorita)

- **D-46 · Previazanie hrúbky a materiálu — PROJEKTOVÁ PREDVOĽBA** (Michal 30.7., test Halifax na v0.5.3; presná cesta potvrdená screenshotom) — okno Materiály projektu → Predvoľby → Korpus → Halifax 18,6 = tvrdý abort „má nekompatibilnú hrúbku pre: CAB-001. Nastav ho priamo tým skrinkám (prevezmú hrúbku) alebo im najprv zmeň hrúbku korpusu." — ručné preklikávanie per skrinka. (D-45 túto vetvu VEDOME blokol — dediacim skrinkám sa hrúbka nesmie meniť TICHO; korpusový select, vklad aj šablóny už previazané sú.) *Návrh riešenia: namiesto abortu POTVRDZOVACÍ flow (vzor allow_duplicate_code): „N dediacich skriniek prevezme hrúbku 18,6 mm — ulož znova pre potvrdenie" → druhé uloženie = predvoľba + rebuild všetkých dediacich skriniek s prevzatou hrúbkou v 1 undo kroku (per-skrinka body/back preflight + ABS remap ako pri priamej zmene; skrinky s blokujúcimi per-dielec overridmi sa vymenujú a dávka sa odmietne celá). Sekundárne (hypotéza z debaty, nižšia priorita): karta dielca pri materiáli inej hrúbky ponúkne „Zmeniť materiál celej skrinky?". Stav: na okamžitú opravnú dávku (v0.5.4).*
- **D-47 · Materiály — vlastný vstup v hlavičke + konzistencia tabov** (Michal 30.7.) — materiály si čoraz viac pýtajú osobitnú sekciu s tlačidlom v hornom paneli (dnes sú na spodku poradia pri úpravách); hlavička panela je nekonzistentná: rôzne šírky tlačidiel, ikonu má len Výroba (Korpus·Zóny·Čelá bez ikon). *Stav: zaradiť do najbližšej UI dávky — prirodzený blok = 2A-4 (UI štruktúry variantov), kde sa hlavička aj tak otvorí.*

## Nápady na zváženie (nerozhodnuté)

- **D-15 · UX vzor: „pridávačky" ako modal** (Michal 19.7.) — všetky akcie „pridať niečo" (šablóna, materiál, …) zjednotiť na modal s formulárom. Napĺňa sa postupne (prvý bol D-14; materiál formulár sa prerobí neskôr).
- **D-26 · Režim Jednoduchý/Rozšírený** (Michal 19.7. večer, debata) — prepínač v UI: jednoduchý = najčastejšie polia, rozšírený = všetko (tvorba šablón, špeciálne zostavy). Rozhodnuté MIESTO samostatného okna Nastavenia (nastavenie ostáva pri svojom poli). *Stav: čaká na dáta z merača D-25 (čo reálne skrývať) — pár týždňov zberu.*
- **D-27 · Rýchle zobraziť/skryť tagy z panela** (Michal 19.7. večer) — mini prepínače priamo v paneli (Čelá 👁 · Chrbát 👁 …) v logike Ghost checkboxu, nech sa nepreklikáva do SketchUp Tags. *Stav: zápis bokom, kandidát na budúcu UX dávku.*
- **D-28 · Textúry materiálov (render)** (Michal 19.7. večer) — katalóg rozšíriť o textúru (obrázok dekoru) + mierku rapportu; builder ich aplikuje pri rebuilde → model pripravený na render (Lucia). Fáza 2: orientácia textúry podľa smeru dekoru dielca. Michal má kompletnú knižnicu textúr; injecting dát príde v dávkach po V1. *Stav: zaradené po V0.6.*

## Návrhy väčších celkov (na rozpracovanie)

- **D-43 · Zdvojené dosky (duplák 36 = 2× 18)** (Michal 27.7.) — **(a) overené v kóde (Fable 27.7.):** logika „36 = 2×18" dnes NEEXISTUJE nikde — kusovník aj odhad platní (`sheet_estimate.rb`) zoskupujú podľa `material_id`, takže dielec 36 spotrebuje 1× svoju plochu z platne varianty „36"; VEPO merge 18+36 je len spoločný SÚBOR (dielec ide 1× s hrúbkou 36 — zhodné so starou linkou). Dôsledok: ak sa duplák lepí z 2×18, interný odhad platní podhodnocuje spotrebu 18-tky. **(b) návrh modelu:** variant 36 označený ako „zdvojený z 18" (odkaz na zdrojový variant + multiplikátor ×2, BEZ vlastného DK kódu — kupuje sa 18-ka) → odhad platní pripočíta 2× plochu do skupiny 18; pri pridaní 18 varianty auto-ponúknuť vytvorenie zdvojenej 36 (Halifax: 18,6 → 37,2). **Dôležité (Codex P2):** vzťah `source_material_id` + multiplikátor musí byť súčasťou výrobného SNAPSHOTU na entite/BOM kontraktu (štandard 8.3 — autorita je snapshot), nie len katalógu — inak sa odhad nedá reprodukovať na inom stroji či po zmene katalógu. *Stav: na návrhovú dávku (sedenie ③ / V0.6).*
- **D-20 · Quick actions — bezpečný move plugin** (Michal 19.7., „pre budúceho Michala a Fable, keď bude základ top 😉") — zlúčiť funkčné pluginy noxun_mower + Snaper do jedného toolbar pluginu (rýchly pohyb, kopírovanie, rotácie, prisunutie na doraz). **Známy poznatok:** mower „rýchla kópia skrinky vedľa" vytvorí kópiu LEN ako geometriu — bez NOXUN identity kabinetu (kópia mimo observer/dedup flow). Pri stavbe quick actions kopírovanie prerobiť tak, aby kópia prešla štandardným dedup tickom (plná identita + config). *Stav: budúcnosť (po V1 / pri zostavách).*
- **D-09 · Snap body pri presúvaní priečok** (1/4, 1/2, 3/4…) v zónovom náhľade. *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-16 · Autocomplete dekoru** (Michal 19.7.) — pri výbere materiálu/ABS písať názov z katalógu, návrhy sa dopĺňajú za každým písmenom, → a Enter potvrdí. *Stav: ODLOŽENÉ (Michal 19.7. večer — „nice to have"), v zásobe.*

## Uzáver V0.5 — hardening a slovné sedenia (od 24.7.)

Stabilizácia pred V0.6 = **spoločné prechádzky funkčnosťou v krátkych jasných krokoch**: ujasnenie pojmov a špecifických funkcií naprieč sedeniami, podstatné veci sa dopĺňajú do dokumentácie (glosár + poznatky: [09_POJMY.md](09_POJMY.md)). Plán sedení: ① vkladanie+korpus · ② zóny+čelá · ③ materiály+ABS+dekory (aj otvorené otázky z 09_POJMY) · ④ kovanie · ⑤ Výroba+VEPO+semafor. K tomu:

- **Katalóg materiálov (Demos):** Michalov zoznam (25.7.) spracovaný do seed podkladu nižšie; 90 % materiálu/kovania/ABS ide z demos-trade.sk. Otvorená debata V0.6: „zadaj kód → plugin načíta dáta" (verejné vyhľadávanie kód→položka aj dekor→celá skupina s cenami; Konfigurátor cenníkov za loginom) + **pracovné dosky v dekorovej skupine** (otázky 1–3 v 09_POJMY).
- **Hardening zoznam:** manuálne overiť redo (Ctrl+Y) po zlúčených transparentných operáciách (pozorovanie zo 17.7.).
- **Priebeh testovania seedu (27.7.):** beží — nové D-43 (duplák), D-44 (výber výrobcu/typu), D-45 (bloker 18,6). Funguje: zmena formátu platne podľa postupu (MG Cashmere → 2800×2050 ✓).

### Seed katalógu — podklad na ručné vloženie (zoznam Michal 25.7., jednorazová sekcia)

**Odporúčaný postup:** vkladať RUČNE cez batch „Nový dekor" (preset-čipy) — zároveň otestuje D-42 UI na reálnych dátach (18,6 mm; PD 38). Demos import (V0.6) potom záznamy len obohatí — DK kódy už budú sedieť. Ku každému dekoru vlož aspoň ABS 22/1,0 (nech funguje picker a olep); ABS kódy doplníme po vyriešení mapovania (09_POJMY otázka 2). **Formát platne (od D-44, PR #84):** zadávaš ho rovno v dávke — pod čipmi dosiek je pruh `dĺžka × šírka` pre zapnuté čipy (DTDL/MDF/HDF predvyplnené 2800×2070, PD prázdne zámerne). Prepíš tam: obe MG dekory → **2800×2050**, PD 38 → **4100×600**. Ak formát nevyplníš, záznam ostane bez neho a odhad platní to viditeľne označí ako núdzový (semafor „nezmestí sa" mlčí) — dodatočne sa dopĺňa ceruzkou pri variante.

| Výrobca | Dekor (kľúč) | Názov | Doskové varianty | DK kód (code; supplier = Demos) | Poznámka |
|---|---|---|---|---|---|
| Egger | U750 ST9 | Taupe šedá | DTDL 18 | 175726 | |
| Egger | H3303 ST10 | Dub Hamilton prírodný | DTDL 18 | 175718 | |
| Egger | F800 ST9 | Mramor krištáľový | DTDL 18 + PD 38 | DTDL 514269 · PD 514485 | PD 920 (514486) čaká na otázku 3; overené na webe — skupina má aj 8 ABS pások |
| Egger | H1180 ST37 | Dub Halifax prírodný | DTDL **18,6** | 275848 | test guardu hrúbky |
| Kronospan | K097 SU BU | Dusk Blue | DTDL 18 | 353854 | |
| Kronospan | 164 PE BU | Antracit | DTDL 18 | 142438 | |
| Kronospan | 5981 MG | Cashmere | DTDL 18 | 473933 | formát **2800×2050** |
| Kronospan | 191 MG | Cool grey | DTDL 18 | 457973 | formát **2800×2050** |
| Kronospan | K350 RT BU | Flow betónový | DTDL 18 | 402872 | |
| Kronospan | K2738 PW BU | Torro Cremona Oak | DTDL 18 | 532848 | PD 38 „FP" (532772) — otázka 1 (kľúč skupiny) |
| Falco | Y121 FS01 | Biela hladká | DTDL 18 | — (bez DK) | dodávateľ? |
| Kastamonu | A860 PS29 | Dub Korona | DTDL 18 | — (bez DK) | formát overiť |

## Otvorené otázky (na Michalovo posúdenie pri teste)

### 2A migračná mapa (z tvojho ŽIVÉHO katalógu 30.7. — odklepni/uprav v chate)

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
| Pracovna doska (len osirotená ABS páska) | **NAVRHUJEM ZMAZAŤ** (testovací zvyšok bez dosky) | — | alebo povedz, kam patrí |

*(ID záznamov sa NEmenia — modely ostanú platné; menia sa len skupinové polia. Legacy „univerzálne" pásky bez šírky dostanú `universal` až keď ich tak označíš — default = neznáma štruktúra.)*

## Trvalé UI/UX pravidlo (Michal 20.7. — platí pre všetku ďalšiu prácu na paneli)

**VERTIKÁLNY priestor panela je vzácny.** Pred umiestnením každého nového tlačidla/poľa/funkcie sa POVINNE zamyslieť, či sa nedá umiestniť inak a rozumnejšie (do existujúceho radu, do rohu náhľadu, ako ikona, kontextovo) — rast do výšky len v krajných prípadoch. Inak panel skončí ako scrollovanie cez 20 tlačidiel a 30 sekcií.

## Vyriešené — index (plné texty v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md))

- **D-44** rýchle zadávanie materiálov (našepkávač výrobcu/typu, formát platne rovno v dávke „Nový dekor", nezadaný formát sa neukladá) — PR #84
- **D-45** slučka hrúbka ↔ materiál pri 18,6 (materiál prevezme hrúbku · hrúbka si doberie materiál · vklad sa prispôsobí) — PR #83
- **D-42** dekorový katalóg UI (mriežka, kód+dodávateľ, cena „nezadaná", inline bunky, preset-čipy) — PR #74–#76
- **D-41** dekorové skupiny materiál↔ABS (šírka ABS, picker, remap, modal chýbajúcej pásky) — PR #70–#72
- **D-40** panel visel po vložení (DC observer pasca scaletool) — PR #64 · **D-39** zámky vkladacej karty — PR #61 · **D-38** chrbát „pevný 18" preflight — PR #59 · **D-37** hĺbka = celková vrátane chrbta — PR #59 · **D-36** ABS odporúčané k dekoru — PR #67 · **D-35** olep 4 hrán klikom — PR #60 · **D-34** panel po zmazaní skrinky — PR #61 · **D-33/D-32** šablóna aplikuje všetko + serverová kópia — PR #61 · **D-31** skrinka bez chrbta — PR #59 · **D-30** výstuhy default ABS predná — PR #60
- **D-29** dvojradová hlavička + tokeny + ikonový sprite — PR #66 · **D-25** merač používania — PR #50 · **D-24** krídla 1–4 — PR #54 · **D-23** orientácia riadkov čiel — PR #55 · **D-22** odomykateľný limit presahov — PR #54 · **D-21** výrazy v čelách (existovalo) · **D-19** odhad platní — PR #53 · **D-18** čelo „BEZ" — PR #52 · **D-17** sokel plná šírka — PR #45 · **D-14** uložiť šablónu z panela (existovalo)
- **D-13** default zapustenia sokla 40 — PR #45 · **D-12** zoom len Ctrl+koliesko — PR #45 · **D-11** kóty sokla/tela — PR #45 · **D-08** režimové taby — PR #43 · **D-07** medzery/presahy čiel — PR #41 · **D-06** scale maska 120 — PR #38 · **D-05** správa katalógu materiálov — PR #39 · **D-04** ghosty default vypnuté — PR #38 · **D-03** police discoverability — PR #42 · **D-02** debounce náhľadu — PR #38 · **D-01** náhľad rastie s oknom — PR #38
- Smoke test 20.7. (testy 1–11) + **VEPO krížová validácia 26=26** (PR #58) — plný záznam v archíve
