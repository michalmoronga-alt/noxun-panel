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
- **Reálny sortiment (prieskum 29.7., plné dáta: [zdroje/DEMOS_PD_prieskum_2026-07.md](zdroje/DEMOS_PD_prieskum_2026-07.md)):** šírky 600/635/650/900/920/1200 (+ zásteny 640), hrúbka 38 dominuje + **nové línie 20 mm (ABS rovná hrana, Egger 7/2026) a kompakt 12 mm** — šírka a hrúbka sú atribúty variantu, nie typy. **Tri podtypy hranovej úpravy: postforming / ABS rovná hrana (páska 1,5) / kompakt (monolitická)** — riadi ABS logiku prednej hrany. **PD existuje len pre „veľké" dekory** (drevo/kameň/betón) — uni a lesklé MG dekory PD spravidla nemajú.
- Pri spotrebičoch pod PD (umývačka, rúra) treba spodok prelepiť hliníkovou páskou (ochrana proti pare) — poznámka z Demos popisu.

### Dosky (DTDL)

- **DTDL 36 = 2× zlepená doska 18** (výrobný postup — napr. pre hrubé korpusové/pohľadové prvky). Demos predáva aj hotovú DTDL 38 (a rad hrúbok 8–38).
- **Dekorové číslovanie AJ štruktúry povrchu sú PER VÝROBCA:** Egger (U750 ST9, H3303 ST10, F800 ST9, H1180 ST37), Kronospan (K097 SU BU, 164 PE BU, 5981 MG, K350 RT BU, K2738 PW BU), Falco (Y121 FS01), Kastamonu (A860 PS29). „ST9" a pod. = kód štruktúry (embosovania) povrchu.
- **Formáty platní sa líšia aj v rámci výrobcu:** Egger 2800×2070; Kronospan 2800×2070 aj **2800×2050** (napr. MG dekory). Formát je vlastnosť materiálu (pole z D-19) — vplýva na odhad platní a semafor „nezmestí sa".
- **Hrúbka nie je vždy 18,0:** Egger H1180 Dub Halifax = **18,6 mm** (hlboká synchrónna štruktúra). Guardy hrúbok a semafor s tým musia rátať.
- **Rovnaký dekor existuje ako DTDL aj PD s INOU štruktúrou povrchu:** Kronospan K2738 Torro Cremona Oak = DTDL „PW BU" (DK 532848) + PD „FP" (DK 532772). → otvorená otázka kľúča skupiny (nižšie).

### Zásteny

- **Zástena** = doska medzi PD a hornými skrinkami; **hrúbka zvyčajne 10–12 mm**, dĺžky ako pracovné dosky (4100) (Michal 29.7.).
- **Obojstranné dekory:** zástena máva občas KAŽDÚ stranu úplne iný dekor (šetrenie výroby — na stenu sa lepí nepohľadovou stranou, pohľadová ostáva von). Dátový dôsledok: variant môže niesť dva dekory (líce/rub) — doriešiť pri PD/zástena modeli vo V0.6.
- **Potvrdené prieskumom (29.7., 102 položiek):** konzistentný vzor 4100×640, hrúbka **9,2 (Egger) / 10 (Kronospan)**, dva dekory VŽDY v názve — obojstranný dekor je štandard sortimentu, nie výnimka. Demos príklad: „Zástena K551/K552 4100/640/10".

### ABS hrany

- **Demos reálne šírky: 23 / 28 / 43 / 54 / 100 (Jumbo); hrúbky 0,8 / 1 / 1,5 / 2 mm** (existuje aj skutočná 1,0 — podľa dodávateľa/dekoru).
- **Pravidlá použitia (Michal 29.7.):** pred objednávkou sa reálne rieši len „jednotka" vs „dvojka" — **„jednotka" (0,8–1,0)** = menej namáhané hrany, korpusy (najčastejšia) · **„dvojka" (2,0)** = silno namáhané hrany: stolové a pracovné dosky, duplované dielce, stropy skriniek. **1,5 sa takmer nepoužíva** (často nie je skladom), ale môže existovať ako variant — niekedy výhodná cena/dostupnosť.
- **Šírky v praxi:** takmer sa neriešia — hlavná je **23**; **28** na hrubšie materiály (20 mm+).
- **Hĺbka odfrezovania sa u nás NErieši** — to spracúva VEPO; na našej strane ide len o výber hrúbky pásky a priradenie kódu.
- ABS sa objednáva na metre (bal. 25/75 m).
- **Prieskum Demos per dekor (29.7., plné tabuľky s kódmi: [zdroje/DEMOS_ABS_prieskum_2026-07.md](zdroje/DEMOS_ABS_prieskum_2026-07.md)):** bežné dekory majú 23+43 v 0,8 aj 2,0 takmer vždy skladom (default model „jednotka+dvojka" platí) — ALE **lesklé MG dekory majú JEDINÚ hrúbku 1 mm** (0,8 ani 2 neexistujú → pravidlá potrebujú fallback „najbližšia hrúbka, ktorú dekor má"), **Halifax má dvojku len ako 22/2** (nie 23), existuje aj mikro-hrana 22/0,4 a Raukantex 1,2. Guard hrúbok ABS → povoliť {0,4 · 0,8 · 1,0 · 1,2 · 1,5 · 2,0} — **potvrdené (Michal 29.7.):** mikro-hrana 0,4 sa takmer nepoužíva, ale zaradí sa rovno („nech máme pokryté spektrum") — šum vo výbere vyrieši inteligentné UI/UX zobrazovanie (odporúčané hore, exotika zbalená). Dvojka je ~1,4–1,8× drahšia než 0,8. **Falco a Kastamonu:** iní dodávatelia, zatiaľ sa neriešia — pár dekorov a cien sa vyplní ručne (mimo Demos flow).

### Dodávatelia a zdroje cien (29.7. — mail research + Disk prieskum)

- ⚠️ **STRATEGICKÁ ZMENA (Michal 29.7.): na VEPO sa NEVIAZAŤ.** Spolupráca s VEPO sa pravdepodobne bude ukončovať (zmena vedenia) — objednávky sa budú postupne presmerúvať na EN DANIELI; z VEPO možno len časť materiálu alebo nič. **Dizajnový princíp: katalóg aj výstupy sú supplier-agnostické** — `supplier` per variant (D-42 model to už vie), sadzby služieb (porez/olep) ako dáta per dodávateľ, a popri VEPO CSV exporte počítať s **exportom výrobného zadania pre EN DANIELI** (textová gramatika `<n> ks – A × B – ABS: …` — zdokumentovaná v internom podklade). VEPO cenník na Disku ostáva dobrý zdroj HISTORICKÝCH cien pre seed.

- **VEPO** (Ružomberok) = plošný materiál + porez + olep + kovanie; objednávky cez webformulár, CP s parsovateľnou tabuľkou. **Na firemnom Disku existuje `Cenník_Vepo_19` (XLSX, verzie 07/2024 a 10/2024)** — Egger/Kronospan/Getalit/Pfleiderer DTD + Velvet MDF fronty + ABS hrany; stĺpce značka/kategória/názov/MJ/cenníková vs. individuálna cena → **primárny zdroj nákupných cien pre seed katalógu** (čítať cez download+openpyxl, nie plain read). Sadzby služieb (porez/olep/lepenie) = vstup kalkulácie ponuky; konkrétne hodnoty v internom podklade mimo repa.
- **EN DANIELI** (Lipt. Mikuláš, od 04/2026) = alternatívny porez/olep/kovanie; POZOR: ceny uvádza s DPH (VEPO bez DPH) — pri porovnávaní vždy zjednotiť režim.
- **Falco a Kastamonu dosky sa kupujú cez VEPO** (nie Demos) — rieši otvorený bod seedu; `supplier` pole per variant.
- **AREDO** (od 05/2026) = lakované dvierka, má konfigurátor + SketchUp knižnice — kandidát na integráciu čiel po V1.
- Vizuálna knižnica dekorov (JPG per výrobca) žije na Disku v `NOXUN PROJEKTY/METERIÁLY` — pripravený zdroj pre D-28 textúry/render.

### Demos (hlavný dodávateľ ~90 % materiálu)

- **DK kód** = Demos kód sortimentu → presne D-42 pole `code` (+ `supplier` = Demos). 1 kód = 1 položka.
- Verejné vyhľadávanie `demos-trade.sk/vyhledavani?q=<kód|dekor>` funguje bez loginu a vracia ceny bez/s DPH; detail má štruktúrovanú tabuľku parametrov; „Súvisiaci sortiment" = hotová dekorová skupina. Konfigurátor cenníkov (hromadný export) je za loginom na Démos24Plus.
- Falco a Kastamonu položky v Michalovom zozname sú bez DK — iný zdroj/doplniť (sedenie ③).

### Výstupy zákazky (Disk prieskum 29.7. — vzory z reálnych CP/Rozpočtov)

- **Dva paralelné dokumenty z jedných dát:** interný **Rozpočet** (granulárny — dodávateľské ceny a kódy per položka, XLSX; pri dome delený po zónach) vs klientská **Cenová ponuka** (lump-sum rollup ~6–9 riadkov: nábytková zostava / výsuvy / montáž / doprava + špecifikačná tabuľka „z čoho" s konkrétnymi produktmi BEZ cien + master šablóna VOP/zmluvných bodov/financovania). Revízie sa nikdy neprepisujú — nové dátumované súbory „AKT. DD.MM.RRRR".
- **Montáž sa kalkuluje vzorcom: počet platní × 5,8 m² × sadzba/m²** — z počtu NAKÚPENÝCH platní (5,8 = plocha 2800×2070), nie z plochy dielcov → náš odhad platní (D-19) je priamy vstup montážnej kalkulácie.
- **VEPO CSV je konečný produkt pipeline** — nesting/nárez robí dodávateľ; vizuálny nárezový plán u nás neexistuje (potvrdzuje D-19 rozsah).
- Revízie modelov: **písmená** (A,B,…K,L,M) = dizajnové; **čísla** (1,2,3) = produkčné vo `Výroba/`. Kovanie sa občas drží v samostatnom .skp.
- Plná anatómia CP šablóny (sekcie 1–9) v internom podklade mimo repa.

## Otvorené otázky (na slovné sedenia)

1. ~~Kľúč dekorovej skupiny naprieč typmi~~ — **ROZHODNUTÉ (sedenie ③, 29.7.):** kľúč skupiny = **výrobca + číslo dekoru** (K2738, F800); **štruktúra povrchu (ST9, PW BU, FP, MG…) sa presúva na VARIANT**. U Eggera sa prakticky nič nemení, u Kronospanu to spája DTDL+PD do jednej skupiny a rieši aj viacero povrchov pod jedným číslom (5981 MG vs BS/PD). Realizácia v dávke 2A (malá migrácia názvov seedu).
2. ~~ABS obchodné vs nominálne hodnoty~~ — **ROZHODNUTÉ (sedenie ③, 29.7.):** katalóg prechádza na **reálne obchodné hrúbky** (0,8 / 1 / 1,5 / 2 — guard V0.3.3 sa uvoľní na tieto hodnoty) a auto-šírky 22→**23** (+43). UI môže „jednotku" ukazovať s obchodným aliasom. Realizácia v dávke 2A (V0.6); prieskum dostupných ABS per dekor zo seedu beží (subagent 29.7.).
3. ~~PD varianty rovnakej hrúbky s rôznou šírkou~~ — **ROZHODNUTÉ (sedenie ③, 29.7.):** PD sa **NErámcuje na pevné šírkové typy** („PD 600/PD 920" nebudú typy) — šírok je veľa a závisia od výrobcu a typu (600, 650, 920, 950, 1200…). **Šírka/formát = atribút variantu**: identita PD variantu = typ „PD" + hrúbka + formát. D-44 pickery: typ zostáva krátky zoznam (DTDL, PD, HDF…), formát je samostatné pole. Prieskum reálnych PD šírok na Demose beží (subagent 29.7.).
4. **Hrúbka 18,6** (Halifax) v hrúbkových guardoch, dedení a semafore — overiť, či nikde nie je natvrdo 18/19.
