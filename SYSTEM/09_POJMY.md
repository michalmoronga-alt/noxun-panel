# Pojmy a stolárske poznatky (živý dokument)

> Založené 25.7.2026 pri uzávere V0.5 pre **slovné sedenia**. Dve časti: **pojmy systému** (ako veci voláme v engine — jednotný jazyk naprieč sedeniami) a **stolárske poznatky** (fakty domény, ktoré ovplyvňujú dátový model a výrobu). Dopĺňa sa priebežne — každé sedenie a každé Michalovo hlásenie sem pridá, čo je trvalé.

## Pojmy systému (glosár — štartová sada, dopĺňa sa pri sedeniach)

| Pojem | Význam |
|---|---|
| **Korpus** | skrinka; `kind: cabinet`, identita CAB-xxx; nesie konfiguráciu (JSON v NOXUN dict), geometriu generuje Ruby (regenerate) |
| **Doska** | samostatný výrobný dielec mimo korpusu (krycia doska, blenda, výplň); `kind: board`, BRD-xxx, rola `free_panel` |
| **Zóna** | adresovateľný vnútorný priestor korpusu; vzniká delením priečkami (strom zón); klik cez 2D náhľad |
| **Čelo** | predný panel v rade čiel (dvierka/zásuvkové čelo/výplň/„bez čela" = nika); výška fixed alebo auto s 🔒 lockmi, kladie sa odspodu |
| **Dielec** | fyzický kus materiálu na výrobu; stabilná identita `part_key` (prežije rebuild) |
| **Rola** | funkcia dielca — určuje ABS defaulty a pravidlá kovania. **Kanonické hodnoty** (BuildPlan::ROLES, štandard §2.4): `side_left`/`side_right` (boky), `bottom` (dno), `top` (strop), `back` (chrbát), `shelf` (polica), `divider_v`/`divider_h` (priečky), `front_door` (dvierka), `drawer_front` (zásuvkové čelo), `flap`, `cover_panel`, `false_front`, `rail_front`/`rail_back` (výstuhy), `plinth` (sokel), `gola_profile`, `free_panel` (voľná doska). Do configov/pravidiel VŽDY kanonický identifikátor, nie slovenský názov |
| **Dekor** | kľúč dekorovej skupiny materiál↔ABS (napr. „F800 ST9") — viaže dosky a pásky rovnakého vzoru; strážený (immutable pri edite, rename atomicky) |
| **Variant** | konkrétny záznam v dekorovej skupine: doska = typ+hrúbka (DTDL 18, PD 38…), ABS = šírka+hrúbka (22/1,0) |
| **Snapshot** | výrobný záznam materiálu/ABS uložený NA entite (autorita — štandard 8.3); katalóg je len zdroj pri výbere |
| **BuildPlan** | záväzný kontrakt plánu stavby (SCHEMA 2) — geometria, kusovník aj VEPO čítajú TEN ISTÝ plán |
| **Semafor** | kontrolný zoznam RED/ORANGE v okne Výroba (RED nikdy neblokuje export) |
| **Proxy kovania** | vizuál (nohy) v modeli; NIE je zdroj pravdy — súpis číta VÝHRADNE `config.hardware[]` |
| **Šablóna vs TYP vs parameter** | tri úrovne konfigurácie — hranica definovaná v [04_ROADMAP.md](04_ROADMAP.md) |

## Stolárske poznatky (doména)

### Pracovné dosky (PD)

- **Postforming** = laminát plynulo prechádza z plochy cez zaoblenú hranu pod dosku (uzavreté UV lakom); skladba: laminát 0,6 + nosič DTD + protiťahový papier.
- **PD šírky 600: postforming LEN z prednej pozdĺžnej hrany. Šírky 900/920/1100: postforming na OBOCH pozdĺžnych hranách** (Michal 25.7.). Dôsledok pre ABS logiku: postforming hrany sa NEolepujú.
- **Rezané konce PD** sa lepia hranou š.45 (Demos „HPDB š.45" — laminátová hrana; pribalená len k objednávke CELEJ dosky).
- Štandard PD: hrúbka 38, dĺžka 4100 (Demos: 4100/600 a 4100/920).
- Pri spotrebičoch pod PD (umývačka, rúra) treba spodok prelepiť hliníkovou páskou (ochrana proti pare) — poznámka z Demos popisu.

### Dosky (DTDL)

- **DTDL 36 = 2× zlepená doska 18** (výrobný postup — napr. pre hrubé korpusové/pohľadové prvky). Demos predáva aj hotovú DTDL 38 (a rad hrúbok 8–38).
- **Dekorové číslovanie AJ štruktúry povrchu sú PER VÝROBCA:** Egger (U750 ST9, H3303 ST10, F800 ST9, H1180 ST37), Kronospan (K097 SU BU, 164 PE BU, 5981 MG, K350 RT BU, K2738 PW BU), Falco (Y121 FS01), Kastamonu (A860 PS29). „ST9" a pod. = kód štruktúry (embosovania) povrchu.
- **Formáty platní sa líšia aj v rámci výrobcu:** Egger 2800×2070; Kronospan 2800×2070 aj **2800×2050** (napr. MG dekory). Formát je vlastnosť materiálu (pole z D-19) — vplýva na odhad platní a semafor „nezmestí sa".
- **Hrúbka nie je vždy 18,0:** Egger H1180 Dub Halifax = **18,6 mm** (hlboká synchrónna štruktúra). Guardy hrúbok a semafor s tým musia rátať.
- **Rovnaký dekor existuje ako DTDL aj PD s INOU štruktúrou povrchu:** Kronospan K2738 Torro Cremona Oak = DTDL „PW BU" (DK 532848) + PD „FP" (DK 532772). → otvorená otázka kľúča skupiny (nižšie).

### ABS hrany

- **Demos reálne šírky: 23 / 28 / 43 / 54 / 100 (Jumbo); hrúbky 0,8 / 1 / 1,5 / 2 mm** (existuje aj skutočná 1,0 — podľa dodávateľa/dekoru).
- **Pravidlá použitia (Michal 29.7.):** pred objednávkou sa reálne rieši len „jednotka" vs „dvojka" — **„jednotka" (0,8–1,0)** = menej namáhané hrany, korpusy (najčastejšia) · **„dvojka" (2,0)** = silno namáhané hrany: stolové a pracovné dosky, duplované dielce, stropy skriniek. **1,5 sa takmer nepoužíva** (často nie je skladom), ale môže existovať ako variant — niekedy výhodná cena/dostupnosť.
- **Šírky v praxi:** takmer sa neriešia — hlavná je **23**; **28** na hrubšie materiály (20 mm+).
- **Hĺbka odfrezovania sa u nás NErieši** — to spracúva VEPO; na našej strane ide len o výber hrúbky pásky a priradenie kódu.
- ABS sa objednáva na metre (bal. 25/75 m).

### Demos (hlavný dodávateľ ~90 % materiálu)

- **DK kód** = Demos kód sortimentu → presne D-42 pole `code` (+ `supplier` = Demos). 1 kód = 1 položka.
- Verejné vyhľadávanie `demos-trade.sk/vyhledavani?q=<kód|dekor>` funguje bez loginu a vracia ceny bez/s DPH; detail má štruktúrovanú tabuľku parametrov; „Súvisiaci sortiment" = hotová dekorová skupina. Konfigurátor cenníkov (hromadný export) je za loginom na Démos24Plus.
- Falco a Kastamonu položky v Michalovom zozname sú bez DK — iný zdroj/doplniť (sedenie ③).

## Otvorené otázky (na slovné sedenia)

1. **Kľúč dekorovej skupiny naprieč typmi:** K2738 „PW BU" (DTDL) vs „FP" (PD) — jedna skupina „K2738 Torro Cremona Oak"? Dnes je dekor jeden string; ak má PD inú štruktúru, kľúč bez štruktúry? (sedenie ③)
2. ~~ABS obchodné vs nominálne hodnoty~~ — **ROZHODNUTÉ (sedenie ③, 29.7.):** katalóg prechádza na **reálne obchodné hrúbky** (0,8 / 1 / 1,5 / 2 — guard V0.3.3 sa uvoľní na tieto hodnoty) a auto-šírky 22→**23** (+43). UI môže „jednotku" ukazovať s obchodným aliasom. Realizácia v dávke 2A (V0.6); prieskum dostupných ABS per dekor zo seedu beží (subagent 29.7.).
3. **PD varianty rovnakej hrúbky s rôznou šírkou** (F800: PD 38×600 DK 514485 + PD 38×920 DK 514486): identita variantu = typ+hrúbka → dve šírky sa nezmestia. Model potrebuje šírku/formát v identite PD variantu (V0.6 bod „PD v dekorovej skupine").
4. **Hrúbka 18,6** (Halifax) v hrúbkových guardoch, dedení a semafore — overiť, či nikde nie je natvrdo 18/19.
