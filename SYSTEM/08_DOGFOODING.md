# Dogfooding zápisník (živý dokument)

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú do archívu [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md) (plné texty s PR); tu ostáva jednoriadkový index. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia). Stav k 24.7.: zápisník ČISTÝ — žiadne otvorené blokery ani spomaľovače.

## Blokery (bránia dokončeniu zákazky)

*(momentálne žiadne)*

## Spomaľovače (vysoká priorita)

*(momentálne žiadne)*

## UX drobnosti (nízka priorita)

*(momentálne žiadne)*

## Nápady na zváženie (nerozhodnuté)

- **D-15 · UX vzor: „pridávačky" ako modal** (Michal 19.7.) — všetky akcie „pridať niečo" (šablóna, materiál, …) zjednotiť na modal s formulárom. Napĺňa sa postupne (prvý bol D-14; materiál formulár sa prerobí neskôr).
- **D-26 · Režim Jednoduchý/Rozšírený** (Michal 19.7. večer, debata) — prepínač v UI: jednoduchý = najčastejšie polia, rozšírený = všetko (tvorba šablón, špeciálne zostavy). Rozhodnuté MIESTO samostatného okna Nastavenia (nastavenie ostáva pri svojom poli). *Stav: čaká na dáta z merača D-25 (čo reálne skrývať) — pár týždňov zberu.*
- **D-27 · Rýchle zobraziť/skryť tagy z panela** (Michal 19.7. večer) — mini prepínače priamo v paneli (Čelá 👁 · Chrbát 👁 …) v logike Ghost checkboxu, nech sa nepreklikáva do SketchUp Tags. *Stav: zápis bokom, kandidát na budúcu UX dávku.*
- **D-28 · Textúry materiálov (render)** (Michal 19.7. večer) — katalóg rozšíriť o textúru (obrázok dekoru) + mierku rapportu; builder ich aplikuje pri rebuilde → model pripravený na render (Lucia). Fáza 2: orientácia textúry podľa smeru dekoru dielca. Michal má kompletnú knižnicu textúr; injecting dát príde v dávkach po V1. *Stav: zaradené po V0.6.*

## Návrhy väčších celkov (na rozpracovanie)

- **D-20 · Quick actions — bezpečný move plugin** (Michal 19.7., „pre budúceho Michala a Fable, keď bude základ top 😉") — zlúčiť funkčné pluginy noxun_mower + Snaper do jedného toolbar pluginu (rýchly pohyb, kopírovanie, rotácie, prisunutie na doraz). **Známy poznatok:** mower „rýchla kópia skrinky vedľa" vytvorí kópiu LEN ako geometriu — bez NOXUN identity kabinetu (kópia mimo observer/dedup flow). Pri stavbe quick actions kopírovanie prerobiť tak, aby kópia prešla štandardným dedup tickom (plná identita + config). *Stav: budúcnosť (po V1 / pri zostavách).*
- **D-09 · Snap body pri presúvaní priečok** (1/4, 1/2, 3/4…) v zónovom náhľade. *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*
- **D-16 · Autocomplete dekoru** (Michal 19.7.) — pri výbere materiálu/ABS písať názov z katalógu, návrhy sa dopĺňajú za každým písmenom, → a Enter potvrdí. *Stav: ODLOŽENÉ (Michal 19.7. večer — „nice to have"), v zásobe.*

## Uzáver V0.5 — hardening a slovné sedenia (od 24.7.)

Stabilizácia pred V0.6 = **spoločné prechádzky funkčnosťou v krátkych jasných krokoch**: ujasnenie pojmov a špecifických funkcií naprieč sedeniami, podstatné veci sa dopĺňajú do dokumentácie (štandard/roadmapa/CLAUDE.md). K tomu:

- **Katalóg materiálov (Demos):** Michal pripravil základný zoznam materiálov (dodá dokument); 90 % materiálu/kovania/ABS ide z demos-trade.sk. Otvorená debata: „zadaj kód → plugin načíta dáta" (verejné vyhľadávanie kód→položka aj dekor→celá skupina s cenami; Konfigurátor cenníkov za loginom) + **pracovné dosky v dekorovej skupine** (PD 4100×600/920/38, HPDB hrana š.45, DTDL 36 = 2× zlepená 18). Zaradenie: V0.6.
- **Hardening zoznam:** manuálne overiť redo (Ctrl+Y) po zlúčených transparentných operáciách (pozorovanie zo 17.7.).

## Otvorené otázky (na Michalovo posúdenie pri teste)

*(momentálne žiadne)*

## Trvalé UI/UX pravidlo (Michal 20.7. — platí pre všetku ďalšiu prácu na paneli)

**VERTIKÁLNY priestor panela je vzácny.** Pred umiestnením každého nového tlačidla/poľa/funkcie sa POVINNE zamyslieť, či sa nedá umiestniť inak a rozumnejšie (do existujúceho radu, do rohu náhľadu, ako ikona, kontextovo) — rast do výšky len v krajných prípadoch. Inak panel skončí ako scrollovanie cez 20 tlačidiel a 30 sekcií.

## Vyriešené — index (plné texty v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md))

- **D-42** dekorový katalóg UI (mriežka, kód+dodávateľ, cena „nezadaná", inline bunky, preset-čipy) — PR #74–#76
- **D-41** dekorové skupiny materiál↔ABS (šírka ABS, picker, remap, modal chýbajúcej pásky) — PR #70–#72
- **D-40** panel visel po vložení (DC observer pasca scaletool) — PR #64 · **D-39** zámky vkladacej karty — PR #61 · **D-38** chrbát „pevný 18" preflight — PR #59 · **D-37** hĺbka = celková vrátane chrbta — PR #59 · **D-36** ABS odporúčané k dekoru — PR #67 · **D-35** olep 4 hrán klikom — PR #60 · **D-34** panel po zmazaní skrinky — PR #61 · **D-33/D-32** šablóna aplikuje všetko + serverová kópia — PR #61 · **D-31** skrinka bez chrbta — PR #59 · **D-30** výstuhy default ABS predná — PR #60
- **D-29** dvojradová hlavička + tokeny + ikonový sprite — PR #66 · **D-25** merač používania — PR #50 · **D-24** krídla 1–4 — PR #54 · **D-23** orientácia riadkov čiel — PR #55 · **D-22** odomykateľný limit presahov — PR #54 · **D-21** výrazy v čelách (existovalo) · **D-19** odhad platní — PR #53 · **D-18** čelo „BEZ" — PR #52 · **D-17** sokel plná šírka — PR #45 · **D-14** uložiť šablónu z panela (existovalo)
- **D-13** default zapustenia sokla 40 — PR #45 · **D-12** zoom len Ctrl+koliesko — PR #45 · **D-11** kóty sokla/tela — PR #45 · **D-08** režimové taby — PR #43 · **D-07** medzery/presahy čiel — PR #41 · **D-06** scale maska 120 — PR #38 · **D-05** správa katalógu materiálov — PR #39 · **D-04** ghosty default vypnuté — PR #38 · **D-03** police discoverability — PR #42 · **D-02** debounce náhľadu — PR #38 · **D-01** náhľad rastie s oknom — PR #38
- Smoke test 20.7. (testy 1–11) + **VEPO krížová validácia 26=26** (PR #58) — plný záznam v archíve
