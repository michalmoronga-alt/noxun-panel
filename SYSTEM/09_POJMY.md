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
| **Proxy kovania** | vizuál (nohy, úchytkový profil) v modeli; NIE je zdroj pravdy — súpis číta VÝHRADNE `config.hardware[]` |
| **Úchytkový profil (UKW)** | hliníkový profil nasunutý na hranu čela namiesto úchytky (UKW-7 = 19,181 × 37,419 mm, tyče 3000/3500 mm, 7 farieb). Čelo sa kvôli nemu **skracuje o 36 mm**, riadok čiel si výšku drží — profil je jeho súčasť. Rez = šírka krídla, každé krídlo má vlastný kus. Dnes vždy **horná** hrana; dolná (častá v praxi) a bočné sú v backlogu. Hrana sa **olepuje normálne** — profil sa nasúva na hotový olep |
| **Set kovania** | mapovacie pravidlo: generický typ z pravidiel (záves, noha, výsuv…) → zoznam Demos kódov s pomermi (per jednotka / per vlastník / rad podľa NL); **NIE je položka katalógu**; definície globálne + snapshot v modeli (dávka D) |
| **Šablóna vs TYP vs parameter** | tri úrovne konfigurácie — hranica definovaná v [04_ROADMAP.md](04_ROADMAP.md) |

## Stolárske poznatky (doména)

### Pracovné dosky (PD)

- **Postforming** = laminát plynulo prechádza z plochy cez zaoblenú hranu pod dosku (uzavreté UV lakom); skladba: laminát 0,6 + nosič DTD + protiťahový papier.
- **PD úzke šírky (600, 635, 650): postforming LEN z prednej pozdĺžnej hrany. Široké šírky 900/920/1100: postforming na OBOCH pozdĺžnych hranách** (Michal 25.7.; 635/650 doplnené 2.8. — reálne formáty zo seed podkladu patria k úzkym). Dôsledok pre ABS logiku: postforming hrany sa NEolepujú.
- **Rezané konce PD** sa lepia hranou š.45 (Demos „HPDB š.45" — laminátová hrana; pribalená len k objednávke CELEJ dosky).
- **Reálny sortiment (prieskum 29.7., plné dáta: [zdroje/DEMOS_PD_prieskum_2026-07.md](zdroje/DEMOS_PD_prieskum_2026-07.md)):** šírky 600/635/650/900/920/1200 (+ zásteny 640), hrúbka 38 dominuje + **nové línie 20 mm (ABS rovná hrana, Egger 7/2026) a kompakt 12 mm** — šírka a hrúbka sú atribúty variantu, nie typy. **Podtypy hranovej úpravy PD: postforming / ABS rovná hrana (páska 1,5)** — riadi ABS logiku prednej hrany. (Kompaktné dosky 12 mm s monolitickou hranou = samostatný kanonický TYP `Kompakt`, nie PD podtyp — rozhodnuté pri 2A-0.) **PD existuje len pre „veľké" dekory** (drevo/kameň/betón) — uni a lesklé MG dekory PD spravidla nemajú.
- Pri spotrebičoch pod PD (umývačka, rúra) treba spodok prelepiť hliníkovou páskou (ochrana proti pare) — poznámka z Demos popisu.

### Hustota a hmotnosť materiálu

- **Hustota je vlastnosť TYPU, nie záznamu (Michal 2.8.):** DTDL má v ~90 % prípadov rovnakú hustotu/hmotnosť; podstatný rozdiel je **MDF vs DTDL** — hmotnosť ČELA rozhoduje pri výpočte **výklopov** (sila piestov, hlavný dôvod) a **závesov**. Inde sa hmotnostná logika nepotrebuje. Realizácia: register kanonických typov nesie default hustotu (kg/m³) — dávka M-C; spotrebuje ju kovanie (dávka D, hmotnostné tabuľky). Per-záznam override až keď ho prax vypýta.

### Dosky (DTDL)

- **DTDL 36 = 2× zlepená doska 18** (výrobný postup — napr. pre hrubé korpusové/pohľadové prvky). Demos predáva aj hotovú DTDL 38 (a rad hrúbok 8–38).
- **Dekorové číslovanie AJ štruktúry povrchu sú PER VÝROBCA:** Egger (U750 ST9, H3303 ST10, F800 ST9, H1180 ST37), Kronospan (K097 SU BU, 164 PE BU, 5981 MG, K350 RT BU, K2738 PW BU), Falco (Y121 FS01), Kastamonu (A860 PS29). „ST9" a pod. = kód štruktúry (embosovania) povrchu.
- **Formáty platní sa líšia aj v rámci výrobcu:** Egger 2800×2070; Kronospan 2800×2070 aj **2800×2050** (napr. MG dekory). Formát je vlastnosť materiálu (pole z D-19) — vplýva na odhad platní a semafor „nezmestí sa".
- **Hrúbka nie je vždy 18,0:** Egger H1180 Dub Halifax = **18,6 mm** (hlboká synchrónna štruktúra). Guardy hrúbok a semafor s tým musia rátať. **Prax (Michal 30.7.):** ~95 % korpusov je 18 mm; občas 19 mm; 18,6 je rarita (Halifax prakticky jediný) — výnimka, ktorá stolárom komplikuje život → preto obojsmerné previazanie hrúbka↔materiál (D-45/D-46).
- **Rovnaký dekor existuje ako DTDL aj PD s INOU štruktúrou povrchu:** Kronospan K2738 Torro Cremona Oak = DTDL „PW BU" (DK 532848) + PD „FP" (DK 532772). → otvorená otázka kľúča skupiny (nižšie).

### Zásteny

- **Zástena** = doska medzi PD a hornými skrinkami; **hrúbka 9,2–12 mm** (9,2 = dominantný Egger štandard — 63 položiek; 10 = Kronospan; do 12 podľa Michala), dĺžky ako pracovné dosky (4100).
- **Obojstranné dekory:** zástena máva občas KAŽDÚ stranu úplne iný dekor (šetrenie výroby — na stenu sa lepí nepohľadovou stranou, pohľadová ostáva von). Dátový dôsledok: variant môže niesť dva dekory (líce/rub) — doriešiť pri PD/zástena modeli vo V0.6.
- **Potvrdené prieskumom (29.7., 102 položiek):** konzistentný vzor 4100×640, hrúbka **9,2 (Egger) / 10 (Kronospan)**, dva dekory v názve — obojstranný dekor je štandard sortimentu. Demos príklad: „Zástena K551/K552 4100/640/10".
- **Existuje aj PROTIŤAHOVÁ (jednostranná) zástena (D-72, live overenie 2.8.):** dekor len na pohľadovej strane, rub = protiťahový papier — „Číslo dekoru" na stránke nesie JEDNU hodnotu (napr. „F206", title „Zástena F206 PM/ protiťah SM"). „Dva dekory VŽDY" teda neplatí — dátovo je to zástena variant BEZ back polí.

### ABS hrany

- **Demos reálne šírky: 23 / 28 / 43 / 54 / 100 (Jumbo); hrúbky 0,8 / 1 / 1,5 / 2 mm** (existuje aj skutočná 1,0 — podľa dodávateľa/dekoru).
- **Pravidlá použitia (Michal 29.7.):** pred objednávkou sa reálne rieši len „jednotka" vs „dvojka" — **„jednotka" (0,8–1,0)** = menej namáhané hrany, korpusy (najčastejšia) · **„dvojka" (2,0)** = silno namáhané hrany: stolové a pracovné dosky, duplované dielce, stropy skriniek. **1,5 sa takmer nepoužíva** (často nie je skladom), ale môže existovať ako variant — niekedy výhodná cena/dostupnosť.
- **Šírky v praxi:** takmer sa neriešia — hlavná je **23**; **28** na hrubšie materiály (20 mm+).
- **Hĺbka odfrezovania sa u nás NErieši** — to spracúva VEPO; na našej strane ide len o výber hrúbky pásky a priradenie kódu.
- ABS sa objednáva na metre (bal. 25/75 m).
- **Prieskum Demos per dekor (29.7., plné tabuľky s kódmi: [zdroje/DEMOS_ABS_prieskum_2026-07.md](zdroje/DEMOS_ABS_prieskum_2026-07.md)):** bežné dekory majú 23+43 v 0,8 aj 2,0 takmer vždy skladom (default model „jednotka+dvojka" platí) — ALE **lesklé MG dekory majú JEDINÚ hrúbku 1 mm** (0,8 ani 2 neexistujú → pravidlá potrebujú fallback „najbližšia hrúbka, ktorú dekor má"), **Halifax má dvojku len ako 22/2** (nie 23), existuje aj mikro-hrana 22/0,4 a Raukantex 1,2. Guard hrúbok ABS → povoliť {0,4 · 0,8 · 1,0 · 1,2 · 1,5 · 2,0} — **potvrdené (Michal 29.7.):** mikro-hrana 0,4 sa takmer nepoužíva, ale zaradí sa rovno („nech máme pokryté spektrum") — šum vo výbere vyrieši inteligentné UI/UX zobrazovanie (odporúčané hore, exotika zbalená). Dvojka je ~1,4–1,8× drahšia než 0,8. **Falco a Kastamonu:** iní dodávatelia, zatiaľ sa neriešia — pár dekorov a cien sa vyplní ručne (mimo Demos flow).

### Dodávatelia a zdroje cien (29.7. — mail research + Disk prieskum)

- ⚠️ **STRATEGICKÁ ZMENA (Michal 29.7.): na VEPO sa NEVIAZAŤ.** Spolupráca s VEPO sa pravdepodobne bude ukončovať (zmena vedenia) — objednávky sa budú postupne presmerúvať na EN DANIELI; z VEPO možno len časť materiálu alebo nič. **Dizajnový princíp: katalóg aj výstupy sú supplier-agnostické** — `supplier` per variant (D-42 model to už vie), sadzby služieb (porez/olep) ako dáta per dodávateľ, a popri VEPO CSV exporte počítať s **exportom výrobného zadania pre EN DANIELI** (textová gramatika `<n> ks – A × B – ABS: …` — zdokumentovaná v internom podklade). VEPO cenník na Disku ostáva dobrý zdroj HISTORICKÝCH cien pre seed.

- **VEPO CSV je UNIVERZÁLNY výmenný formát, nie formát jedného dodávateľa (Michal 4.8.):** je to štandardný tvar objednávky **porezu a olepu** — rovnaký formát vie prijať aj iný spracovateľ a rovnaký formát generuje napr. program **PRO 100**. „VEPO" je teda len zaužívaný NÁZOV formátu, nie väzba na firmu. Dôsledok pre nás: aj keby spolupráca s VEPO skončila (bod vyššie), export sa nezahadzuje — mení sa len príjemca súboru; supplier-agnostické výstupy sú tým skôr potvrdené než ohrozené.

- **VEPO** (Ružomberok) = plošný materiál + porez + olep + kovanie; objednávky cez webformulár, CP s parsovateľnou tabuľkou. **Na firemnom Disku existuje `Cenník_Vepo_19` (XLSX, verzie 07/2024 a 10/2024)** — Egger/Kronospan/Getalit/Pfleiderer DTD + Velvet MDF fronty + ABS hrany; stĺpce značka/kategória/názov/MJ/cenníková vs. individuálna cena → **primárny zdroj nákupných cien pre seed katalógu** (čítať cez download+openpyxl, nie plain read). Sadzby služieb (porez/olep/lepenie) = vstup kalkulácie ponuky; konkrétne hodnoty v internom podklade mimo repa.
- **EN DANIELI** (Lipt. Mikuláš, od 04/2026) = alternatívny porez/olep/kovanie; POZOR: ceny uvádza s DPH (VEPO bez DPH).
- ~~Kanonický daňový základ cien bez DPH~~ — **ZMENENÉ (Michal 31.7. večer): ceny sa evidujú a počítajú S DPH, presne ako ich zobrazuje Demos.** Vo výslednom výpočte (sumár/ponuka) je jednoduchý **prepínač „s DPH / bez DPH"** (÷1,23 na zobrazenie). Zdroj bez DPH (historický VEPO cenník) sa pri vstupe prepočíta ×1,23. Dôvod: 90 % cien ide z Demosu s DPH — dvojitý prevod bol šum.
- **Ceny sú POHYBLIVÉ — nefixujú sa do katalógu (Michal 31.7. večer):** katalóg drží **väzbu na produkt** (DK kód + URL) a len „poslednú známu cenu + dátum overenia" (cache). Autorita ceny pre ponuku = tlačidlo **„Prepočítať ceny"** v zákazke: prejde všetky použité materiály/ABS/kovanie, natiahne čerstvé ceny z produktových stránok (1 stránka = celá dekorová skupina; Crawl-delay 3 s) a ukáže zmeny pred zápisom. Mechanika fetchu = dávka B; tlačidlo v zákazkovom sumári = dávka E.
- **Kovanie sa objednáva v SETOCH (Michal 31.7. večer — vstup pre dávku D):** závesy = **Hettich** (nie Blum), ~90 % **naložené 110° s tlmením + podložka 1,5 mm + krytky** — jeden funkčný záves = SADA kódov. Mapovanie flag→kód (dávka D) preto mapuje generický flag na **zoznam položiek s počtami** (záves ×1, podložka ×1, krytky ×1), nie na 1 kód. Základné sety šuflíkov zmapuje Gmail sonda (1–2 sety od hlavných kovaní vložiť na testy). **Finálna anatómia setov = sekcia „Kovanie — sety" nižšie (debata 2.8.).**
- **Falco a Kastamonu dosky sa kupujú cez VEPO** (nie Demos) — rieši otvorený bod seedu; `supplier` pole per variant.
- **AREDO** (od 05/2026) = lakované dvierka, má konfigurátor + SketchUp knižnice — kandidát na integráciu čiel po V1.
- Vizuálna knižnica dekorov (JPG per výrobca) žije na Disku v `NOXUN PROJEKTY/METERIÁLY` — pripravený zdroj pre D-28 textúry/render.

### Kovanie — sety (debata s Michalom 2.8.2026 — závery pre dávku D)

- **Set = mapovacie pravidlo, NIE položka katalógu:** generický typ z pravidiel kovania → zoznam Demos kódov s pomermi. Katalóg kovania drží len reálne objednávateľné položky (1 kód = 1 položka); set sa na ne odkazuje kódmi.
- **SET ZÁVES „KLASIK"** (Sensys 8645i 110° naložený): záves **104717** + platnička **106412** (podložka 8099 s excentrom) + krytka misky **105408** + krytka ramienka **105425** — pomer **1:1:1:1 na 1 ZÁVES**; počet závesov na dvierka určuje PRAVIDLO (bands podľa výšky: 2/3/4/5 — dva sú typický prípad z Disk sondy, NIE kontrakt), expanzia setu násobí členov množstvom z pravidla (GH #125 P2). Kódy krytiek doplnil Michal pri debate (dovtedy „otvorená diera č. 1" seed podkladu).
- **SET P2O** (Sensys 8675 k tip-onu, bez tlmenia): záves **245723** + platnička + krytky (1:1:1:1) + **1× TipOn 250831 na DVIERKA** — člen setu viazaný na VLASTNÍKA (čelo), nie na jednotku závesu. Strong tip-on 35000 = samostatný lacnejší set.
- **Výsuvy: dĺžku vyberá SYSTÉM automaticky** (Michal 2.8.) — pravidlo `fit_series` už dnes počíta `nominal_length` zo svetlej hĺbky; set výsuvu je preto **RAD**: mapa NL → kód (Atira biela H70: 420 → 357695, 470 → 357696…), nie jeden pevný kód. **Séria seed pravidla sa v D1 zladí s reálnym produktovým radom Atira** (napr. 420/470/520/620 — dnešná generická séria hodnotu 420 nikdy nevyprodukuje, kľúč mapy by bol nedosiahnuteľný; GH #125 P2); NL bez kľúča v mape = ORANGE nemapované, susedný kód sa NIKDY neberie — staré projekty so starou sériou diery UVIDIA (aktualizácia pravidla = vedomá akcia).
- **Zásuvka = 1× K-sada** (jeden kód = kompletný set bočníc + výsuvu); vnútorná zásuvka navyše čelo profilu + príchyty; drevený šuflík = pár Quadro V6 + spojky.
- **Výklop = 1× set Aventos + krytky VŽDY zvlášť** (samostatný kód ako člen setu). **Realizácia ODLOŽENÁ za D1** (GH #125 P2): pravidlá dnes výklopy negenerujú (žiadny lift generic_type, čelá flap bez pravidla) — set by nemal čo mapovať; anatómia je zaznamenaná pre budúci výklopový model (tam sa napojí aj density/hmotnostný kontrakt).
- **Nohy: 4× klzák 17 mm (82744) ALEBO 4× AXILO (367823)** na spodnú skrinku — dva alternatívne sety, vyberá predvoľba.
- **„Bystrica" NIE je noha — je to rektifikačný uholník na uchytenie skrinky do steny** (Michal 2.8., oprava klasifikácie zo sond): 2 ks na hornú skrinku; krytka sa do setu zatiaľ nedáva. Vyžaduje nový generický typ zavesenia na stenu + pravidlo 2×/horná skrinka.
- **Police: 4× podperka (306125) na policu** — pravidlo + set pribudnú v D.
- **Úchytky sa zatiaľ neriešia** (Michal 2.8.) — pravidlo handle sa v D nezavádza; rozteč/vŕtanie je téma na neskôr.
- **Spojovací materiál (SPAX, konfirmáty) mimo automatiky** — kupuje sa po baleniach na sklad; keď prax vypýta, doplní sa JSON pravidlom bez zmeny kódu.
- **Balenia a zaokrúhľovanie:** D počíta čisté kusy; zaokrúhlenie nahor na balenia rieši E pri cenách (veľkosť balenia = vlastnosť položky katalógu).
- **Nemapovaný typ = ORANGE** „kovanie bez kódov" v semafore + v súpise viditeľné ako nenacenené; **nikdy neblokuje** (rovnaká filozofia ako materiály).
- **Reprodukovateľnosť zákazky:** definície setov žijú globálne (%APPDATA%), ale model nesie **snapshot** mapovania aj použitých setov (vzor hardware_rules) — zmena globálnych setov nesmie ticho zmeniť starú zákazku. Rovnaký kontrakt platí pre budúce hmotnostné tabuľky: **density vstupy sa pri použití zmrazia do modelu** (živý register typov je len default).

### Demos (hlavný dodávateľ ~90 % materiálu)

- **DK kód** = Demos kód sortimentu → presne D-42 pole `code` (+ `supplier` = Demos). 1 kód = 1 položka.
- Verejné vyhľadávanie `demos-trade.sk/vyhledavani?q=<kód|dekor>` funguje bez loginu a vracia ceny bez/s DPH; detail má štruktúrovanú tabuľku parametrov; „Súvisiaci sortiment" = hotová dekorová skupina. Konfigurátor cenníkov (hromadný export) je za loginom na Démos24Plus.
- **Prieskum pre V0.6-B (31.7., živé overenie):** robots.txt zakazuje LEN `/vyhledavani` (+ Request-rate 300/1m, Crawl-delay 3 s) a zverejňuje **sitemap so VŠETKÝMI produktovými URL** (`/content/sitemaps/domain_8_sitemap.xml` → `.8.xml`). Slug produktu = čitateľná identita: `pracovna-doska-h3303-st10-dub-hamilton-prirodny-4100-600-38`, `dtdl-p2-esa-u12188-sd-svetlo-seda-2800-2100-19` (typ+dekor+štruktúra+názov+formát+hrúbka; DK kód v slugu NIE je). **Produktová stránka obsahuje všetko:** Kód sortimentu, cena bez/s DPH, cena za m² bez DPH, značka, jednotka/balenie, štruktúrovaná tabuľka parametrov (číslo dekoru, formát, hrúbka, štruktúra, typ PD postforming/…) a **„Súvisiaci sortiment" s kódmi a cenami CELEJ dekorovej skupiny** (DTDL 18/10, PD 920, LAM, ABSB 43/2, HPDB š.45, spojky, tesniace lišty — overené na H3303: DTDL 175718 sedí so seedom). → **Lookup flow V0.6-B: sitemap cache → match slugu podľa IDENTITY variantu → fetch produktu (delay 3 s) → parse kód+cena+skupina; 1 fetch naplní celý dekor.** „Zadaj kód" je sekundárne (kód nie je v slugu — rieši paste URL / postupne budovaná mapa kód→URL z fetchov).

### Výstupy zákazky (Disk prieskum 29.7. — vzory z reálnych CP/Rozpočtov)

- **Dva paralelné dokumenty z jedných dát:** interný **Rozpočet** (granulárny — dodávateľské ceny a kódy per položka, XLSX; pri dome delený po zónach) vs klientská **Cenová ponuka** (lump-sum rollup ~6–9 riadkov: nábytková zostava / výsuvy / montáž / doprava + špecifikačná tabuľka „z čoho" s konkrétnymi produktmi BEZ cien + master šablóna VOP/zmluvných bodov/financovania). Revízie sa nikdy neprepisujú — nové dátumované súbory „AKT. DD.MM.RRRR".
- **Montáž sa kalkuluje vzorcom: počet platní × 5,8 m² × sadzba/m²** — z počtu NAKÚPENÝCH platní (5,8 = plocha 2800×2070), nie z plochy dielcov. **Pozor (Codex P2):** náš D-19 dáva ODHAD ako rozsah min–max v desatinách (vedome nie nárezový plán) — nie je to priamo počet kúpených platní; pre montážnu kalkuláciu vo V0.6-E treba definovať pravidlo (napr. horný odhad zaokrúhlený na celé platne NAHOR, prepísateľný reálnym nákupom).
- **VEPO CSV je konečný produkt pipeline** — nesting/nárez robí dodávateľ; vizuálny nárezový plán u nás neexistuje (potvrdzuje D-19 rozsah).
- Revízie modelov: **písmená** (A,B,…K,L,M) = dizajnové; **čísla** (1,2,3) = produkčné vo `Výroba/`. Kovanie sa občas drží v samostatnom .skp.
- Plná anatómia CP šablóny (sekcie 1–9) v internom podklade mimo repa.

## Otvorené otázky (na slovné sedenia)

1. ~~Kľúč dekorovej skupiny naprieč typmi~~ — **ROZHODNUTÉ (sedenie ③, 29.7.):** kľúč skupiny = **výrobca + číslo dekoru** (K2738, F800); **štruktúra povrchu (ST9, PW BU, FP, MG…) sa presúva na VARIANT — a stáva sa SÚČASŤOU IDENTITY/unikátnosti variantu** (Codex P2: dnešná ABS identita dekor+šírka+hrúbka nestačí — 5981 má DVE rôzne 23/1 pásky: MG 374929 vs UM/AF 492080; bez štruktúry v identite by sa odmietli ako duplicita). U Eggera sa prakticky nič nemení, u Kronospanu to spája DTDL+PD do jednej skupiny a rozlišuje povrchy pod jedným číslom. Realizácia v dávke 2A vrátane **migračného kontraktu** (štandard §identita variantov + migrácia seedu).
2. ~~ABS obchodné vs nominálne hodnoty~~ — **ROZHODNUTÉ (sedenie ③, 29.7.):** katalóg prechádza na **reálne obchodné hrúbky — plné spektrum {0,4 · 0,8 · 1 · 1,2 · 1,5 · 2}** (guard V0.3.3 sa uvoľní; 0,4 mikro-hrana a 1,2 Raukantex zaradené rovno — potvrdil Michal, šum rieši UI zobrazovanie) a auto-šírky 22→**23** (+43). UI môže „jednotku" ukazovať s obchodným aliasom. Realizácia v dávke 2A (V0.6); prieskum per dekor hotový ([zdroje/DEMOS_ABS_prieskum_2026-07.md](zdroje/DEMOS_ABS_prieskum_2026-07.md)).
3. ~~PD varianty rovnakej hrúbky s rôznou šírkou~~ — **ROZHODNUTÉ (sedenie ③, 29.7.):** PD sa **NErámcuje na pevné šírkové typy** („PD 600/PD 920" nebudú typy) — šírok je veľa a závisia od výrobcu a typu (600, 650, 920, 950, 1200…). **Šírka/formát = atribút variantu**: identita PD variantu = typ „PD" + hrúbka + formát. D-44 pickery: typ zostáva krátky zoznam (DTDL, PD, HDF…), formát je samostatné pole. Prieskum reálnych PD šírok: [zdroje/DEMOS_PD_prieskum_2026-07.md](zdroje/DEMOS_PD_prieskum_2026-07.md).
5. **Dvojvrstvové typy — ROZHODNUTÉ (Michal 30.7.):** typ = **fixný zoznam KANONICKÝCH typov s parametrami** (DTDL · MDF · HDF · PD · Zástena · Kompakt — Ruby register: default formát, ponuka bežných hrúbok napr. DTDL 18/19/36 · HDF 3 · PD 38/20 · zástena 9,2/10, hranová logika/PD podtyp, kandidát pre telo korpusu) + **„Iný…"** ako voľný text s generickým správaním (exotika bez zmeny kódu). Výber typu zo zoznamu rovno predvyplní základné parametre. Existujúce záznamy sa mapujú case-insensitive; nezmapované = „iný". Realizácia: 2A (register = rozšírenie TYPE_FORMAT_HINTS z D-44).
4. ~~Hrúbka 18,6 (Halifax) v hrúbkových guardoch, dedení a semafore~~ — **VYRIEŠENÉ (D-45, PR #83, 29.7.):** natvrdo 18/19 bolo v builderi (`thickness_ok_for?`), v kontrolnom semafore aj na dvoch miestach v JS — všade nahradené **katalógovou hrúbkou materiálu** (čelá) a **rozsahom 6–50 mm** (`CabinetBuilder::THICKNESS_RANGE`, jediná konštanta pre clamp aj guardy). Hrúbka a materiál sa už neblokujú: materiál prevezme hrúbku, hrúbka si doberie materiál, vklad sa prispôsobí predvoľbe. Plný text v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md).

## Poznatky zo smoke testu M-A/M-B1 (1.8.2026 večer)

- **Výrobca ABS pásky ≠ výrobca dosky.** Pásky k dekorom (najmä Kronospan) vyrába tretia strana — preto ABS záznam výrobcu nenesie (7.5) a overovanie pások podľa brandu stránky je chybné (D-64).
- **Kronospan „PD“ v názve = kód povrchovej štruktúry** (ako MG/SU/BS), NIE pracovná doska. Typ položky určuje slug adresy.
- **Demos slugy majú viac tvarov pre jeden typ:** `dtdl-` aj `dtd-laminovana-`; `mdf-` aj `mdfl` (lakovaná). Kompletný zoznam prefixov treba ťahať zo sitemap cache (D-65).
- **Ceny plošných materiálov: nakupujú sa celé tabule** — 1,2 platne = 2 ks; €/m² je len počítacia jednotka (D-61 — **vyriešené dávkou E**: rozpočet ráta plošný materiál po celých tabuliach s cenou za tabuľu).
