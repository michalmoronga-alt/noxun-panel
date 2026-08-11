# SEED KATALÓG 2026-07 — konsolidovaný podklad pre naplnenie katalógu materiálov a kovania

**Účel:** JEDEN zdrojový dokument pre seed katalógu Noxun Engine (materiály V0.5+, kovanie V0.6). Spája ručný seed od Michala (25. 7.), Gmail sondu objednávok kovania (2023–2026) a Disk sondu zákazkových rozpočtov (2024–2026). Slúži ďalším sessions ako podklad, kým sa katalóg nenaplní — potom sa archivuje.

> **Poznámka (Michal):** Michal doplní údaje o **skladových zásobách**, ktoré mierne zmenia pomery kovania (naskladnené položky sa objednávajú menej často, než sa reálne používajú).
> **Ceny sa evidujú S DPH.** Firma nie je platca DPH (potvrdené v CP 6/2026) — nákupná cena s DPH je pre firmu koncový náklad. Ceny v tomto dokumente sú orientačné z rozpočtov/objednávok; pri seede ich Michal overí.

---

## 1. MATERIÁLY — zlúčený zoznam (ručný seed 25. 7. + Disk frekvencie)

Frekvencia „Disk n/9" = počet zákaziek zo sondy Disku (9 rozpočtov 2024–2026), v ktorých sa dekor vyskytol. „Seed" = Michalov ručný zoznam z archívu zápisníka (`archiv/DOGFOODING_historia.md`, §Seed katalógu). Formáty platní: štandard 2800×2070; MG dekory 2800×2050; PD podľa záznamu.

### 1.1 Jadro (zaradiť určite)

| Výrobca | Dekor (kľúč) | Názov | Typ + hrúbka | DK kód (supplier Demos) | Zdroj / frekvencia |
|---|---|---|---|---|---|
| Kronospan | **500 SM BU** | Biela hladká | **DTDL 18** · DTDL 16 | 18: **142390** · 16: **142483** | **Disk 8/9 — korpusový štandard firmy** (v ručnom seede chýbal!); ABS biela skupinová 23/0,8 = **515069** |
| — (VEPO) | Biela HDF | biely sololit (chrbty) | HDF 2,5 | — (cez VEPO bez kódu) | Disk 8/9; v katalógu už existuje |
| Egger | U750 ST9 | Taupe šedá | DTDL 18 | 175726 | seed + Disk 1× (11 platní naraz) |
| Egger | H3303 ST10 | Dub Hamilton prírodný | DTDL 18 | 175718 | seed + Disk 1× (3) |
| Egger | F800 ST9 | Mramor krištáľový | DTDL 18 + PD 38 | DTDL 514269 · PD 514485 (PD 920 = 514486 — ot. 3) | seed + Disk 1× |
| Egger | H1180 ST37 | Dub Halifax prírodný | DTDL **18,6** | 275848 | seed (test guardu hrúbky) |
| Kronospan | K097 SU BU | Dusk Blue | DTDL 18 | 353854 | seed + Disk 1× (4) |
| Kronospan | 164 PE BU | Antracit | DTDL 18 | 142438 | seed |
| Kronospan | 5981 | Cashmere | **MG** DTDL 18 (2800×2050) · **BS** DTDL 18 | MG 473933 · BS 353840 | seed (MG) + Disk 1× (BS, Z7); ABS „5981 BS/PD" = 356427 — dekor v 2 štruktúrach! |
| Kronospan | 191 MG | Cool grey | DTDL 18 (2800×2050) | 457973 | seed |
| Kronospan | K350 RT BU | Flow betónový | DTDL 18 | 402872 | seed |
| Kronospan | K2738 PW BU | Torro Cremona Oak | DTDL 18 + PD „FP" 38 (4100×900) | DTDL 532848 · PD 532772 | seed + Disk 1× (4) + firemná šablóna rozpočtu |
| Falco | Y121 FS01 | Biela hladká | DTDL 18 | — (bez DK) | seed; Disk: Falco sa reálne kupuje ako „FAL 500 SM …/16" (biela 16) cez VEPO |
| Kastamonu | A860 PS29 | Dub Korona | DTDL 18 | — (bez DK) | seed (formát overiť) |

### 1.2 Dekory z reálnych zákaziek 2024–2026 (druhá vlna seedu)

| Výrobca | Dekor | Názov | Typ + hrúbka | DK kód | Frekvencia |
|---|---|---|---|---|---|
| Egger | F206 ST9 | Pietra Grigia čierna | DTDL 18 · PD 38 (4100×600) · kompakt KD-IN 12 · zástena 9,2 | 396087 · 398117 · 472100 · 399163 | **Disk 2/9** — celá dekorová rodina (testovací prípad pre PD v skupine) |
| Egger | H1344 ST32 | Dub Sherman koňakovo hnedý | DTDL **18,6** | 396066 (ABS 0,8 = 398905) | Disk 1× |
| Egger | H3317 ST28 | Dub Cuneo hnedý | DTDL **22,6** | 522021 (ABS 0,8 = 514401 · 43/2 = 514404) | Disk 1× |
| Egger | W1100 ST30 | Alpská biela LESK | DTDL 18 | 307952 (ABS 392486) | Disk 1× |
| Egger | U636 ST9 | Fjordská zelená | DTDL 18 | 413744 | Disk 1× |
| Egger | F243 ST76 | Mramor Candela svetlo šedý | DTDL 18 | 514270 | Disk 1× (4) |
| Kronospan | K686 PD BU | Powder Pink | DTDL 18 | 532804 | Disk 1× (3) |
| Kronospan | K540 PN BU | Grey Albus | DTDL 18 | 495040 | Disk 1× |
| Kronospan | 6299 BS BU | Cobalt Grey | DTDL 18 | 353850 | Disk 2× (v Z9/2024 chybne pomenovaný „Betón K540") |
| Kronospan | 4298 SU BU | Light Atelier | DTDL 18 | 353858 | Disk 1× |
| Kronospan | 8921 BS BU | Ferrara Oak | DTDL 18 | — (v rozpočte bez kódu) | Disk 1× — ale **19 platní** (najväčší objem sondy) |
| Kronospan | K551 SU | Calacatta Olympus | kompakt SLIM 12 (4100×650) · PD 38 (4100×635) | 495130 · 495404 (ABS 42/1 mramor = 510705) | Disk 1× |
| — | PV FOLI | Preglejka breza biela | preglejka 18 (2500×1250) | 167777 | Disk 1× (5, CNC diely) |
| — | AL06/AL06 | MDF LAM Brushed Bronze | MDF 18,7 (2800×1300) | 501560 | Disk 1× |

**Mimo DTDL sveta (nákupné set-položky, nie platne):** externé dvierka Trachea / Svet dvierok „TVAR" / SALU (hliníkové rámy, šatníky) — 4 zákazky; obkladové panely a lamely flexipanely.sk (Marble Calacatta, Wave Gold, HARD/SMOOTH Rock, Classic White) — 4 zákazky.

---

## 2. KOVANIE — TOP zoznam s kódmi a setmi (Gmail sonda + Disk doplnky)

Kódy = Demos „Kód sortimentu" (objednávané cez VEPO). **SET** = položky, ktoré idú vždy spolu v pevnom pomere. Frekvencie: Gmail = počet objednávok 2023–2026; Disk = zákazky ⁄ kusy z 9 rozpočtov.

### 2.1 Závesy (jadro — Hettich Sensys)

| # | Položka | Kód | Frekvencia | SET |
|---|---|---|---|---|
| 1 | HETTICH Sensys 8645i 110° TH52, naložený, SiSy — **„KLASIK"** | **104717** | Gmail 3× · Disk 7/9, ~212 ks | **SET ZÁVES 1:1:1:1 = 104717 + 106412 + 105408 + 105425** (záves + platnička + krytka misky + krytka ramienka — potvrdil Michal, debata 2.8.; Disk potvrdzuje pomer v každej zákazke; na 1 dvierka 2 sety) |
| 2 | HETTICH Sensys 8645i 110° vložený, SiSy | 104719 | Gmail 1× (50 ks) | do setu namiesto naloženého |
| 3 | HETTICH Sensys 8675 110° **P2O** (k tip-onu, bez tlmenia) | **245723** | Gmail 3× · Disk 6/9, ~66 ks | **SET P2O** = 2× záves + 2× podložka + 2× krytky + **1× TipOn** na dvierka |
| 4 | HETTICH Sensys 8657i 165°, naložený, SiSy | 264246 | Gmail 2× · Disk 1× | set ako KLASIK |
| 5 | **podložka 8099 s excentrom D=1,5** | **106412** | Gmail 4× · Disk 8/9, ~254 ks | 1 : 1 ku KAŽDÉMU závesu (automaticky) |
| 6 | **krytky: miska + ramienko** | **105408** (miska) + **105425** (ramienko) — doplnil Michal, debata 2.8. | Disk 8/9, ~213 ks | 1 : 1 ku každému závesu (automaticky) |
| 7 | BLUM 956A1004 TipOn 76 mm s magnetom | 250831 biely · 250834 čierny | Gmail 3× · Disk 5/9 | 1 na dvierka s P2O; lacná alt.: Strong tip-on 35000 |
| 8 | Záves chladničkový HETTICH + platničky | 104454 | Gmail 1× · Disk 3/9 (15 ks) | komplet s platničkou |
| 9 | Sensys uhlový W90 TH52 (9088021) | 104802 | Disk 1× (2) | rohové skrinky |

### 2.2 Zásuvky (poradie podľa reálneho nasadenia)

| # | Systém / položka | Kód | Frekvencia | SET |
|---|---|---|---|---|
| 10 | **K-InnoTech Atira čelný biely 420/70, 30 kg SiSy** | **357695** | Disk: Z1 30 sád! | **K-sada = kompletný SET** (bočnice + Quadro výsuv SiSy) |
| 11 | K-InnoTech Atira čelný biely 470/70 · 420/70/176 · 470/70/176 (reling) | 357696 · 357774 · 357775 | Gmail 2× · Disk 2/9 | vyššie šuflíky = sada „vr. relingu" |
| 12 | K-Atira zásuvka 176, 620 mm/50 kg, relingy | 357783 | Disk 1× (6) | vysoká nosnosť |
| 13 | K-InnoTech Atira vnútorný (biely 470/70 · antracit 420/70) | 357819 · 358009 | Gmail + Disk | + čelo profilu 2000 (294940 biela / 294941 antracit) + príchyt páru (295276 / 295277) |
| 14 | **StrongMax 16** zásuvky H89/H185/H249 × 350–550, biela/šedá/čierna | 502957 · 502972 · 502973 · 502986 · 502988 · 502993 · 502995 · 503020 · 334973 | **Disk 3/9, ~40 sád — v Gmail sonde CHÝBA (nástup 2025+)** | K-sada = SET |
| 15 | StrongMax 18 249/450 | 482262 | Disk 1× (5) | |
| 16 | StrongBox H86–H204 × 270–550 (relingové varianty) | 179252 · 179254 · 179263 · 179264 · 402576 · 402578 · 402593 · 402596 | Gmail 4× · Disk 5/9, ~19 | ekonomická línia; K- varianty s relingami |
| 17 | **K-Quadro V6 skrytý celovýsuv** 350/450/500 (+550), 30 kg, P2O | 343031 (350) · **317642** (450) · 317645 (500) · 317644 | Gmail 3× · Disk 5/10, ~15 | K-set s príchytmi = SET; alt. pár výsuvov (315830/315831) + spojky (104547/104548) |
| 18 | K-BLUM Legrabox M/K 450, 40 kg, TOB, karbon čierna CS-M | 499013 · 499307 (vnútorná) | Gmail 5 obj. (prémium) | vnútorná vyššia + čelný plech 491360 + reling 491359 |
| 19 | Rohový výsuv LEMANS (Quatro) · potravinová Space Tower | 37025 · 260822 | Disk po 1× | set |

### 2.3 Výklopy

| # | Položka | Kód | Frekvencia | SET |
|---|---|---|---|---|
| 20 | **BLUM Aventos HL Top „set" (ramená + krytky + montážne prísl.)** | v rozpočtoch SET à 180 €; anatómia z Gmail: HL 23792 + ramená 197611 + príchyt 13781 + krytky 461804 + stab. tyč 13799 | Disk 2/9, **8 setov** (Z1 7!) · Gmail 1× | **SET — krytky VŽDY zvlášť od hlavného balenia** |
| 21 | BLUM Aventos HK Top silný (± Tip-on) | 347812 · 347827 + krytky 347834 + príchyt 13781 | Gmail 1× · Disk 1× | krytky zvlášť |
| 22 | BLUM Aventos HF Top silný | 507336 | Gmail 1× | krytky zvlášť |
| 23 | KES horný výklop Maxi „D" · IF K12 244 vzpera 120 N | 135043 · 282474 | Disk 1×/1× · Gmail 1× | lacné alternatívy výklopu |

### 2.4 Nohy, montáž, spojovací materiál

| # | Položka | Kód | Frekvencia | Poznámka |
|---|---|---|---|---|
| 24 | **STRONG klzák s rektifikáciou 17 mm** („nohy 17 mm") | **82744** (variant 272212) | Disk **8/9, ~166 ks** · Gmail 1× | najpoužívanejšia „noha" — sokel na klzákoch |
| 25 | **Noha AXILO 150 mm + podložka** (Häfele 637.76.355) | **367823** (+ 60 mm variant, platničky) | Disk 6/9, ~124 ks · Gmail 2× (naskladnenie 100 ks) | 4 ks na spodnú skrinku |
| 26 | „Bystrica" — **rektifikačný uholník na uchytenie skrinky do steny** (NIE noha — oprava Michal, debata 2.8.) | 93240 | Gmail 3× (50–100 ks) | 2 ks na hornú skrinku; krytka zatiaľ mimo setu |
| 27 | Strong Big rektifikačná noha 100 mm | 146993 | Gmail 1× (40) | |
| 28 | Skrutka SPAX 3,5×16 (bal 1000) | 360281 | Gmail **6×** — najčastejšia položka | montáž kovania |
| 29 | PZ 3,5×30 / 3,5×35 · konfirmát 5/50 · podperka policová 7/5 | 228922 / 228924 · 11090 · 306125 | Gmail 4×/3×/2×/3× | korpusová montáž; podperky 4/policu |
| 30 | podnože: GRENADA (488856) · BELL II centrálna · MILADESIGN G5 · Industry · TENTE kolieska (154145) | | Disk | stoly/atypy |

### 2.5 Úchytky, profily, ostatné (samostatná kategória s roztečou)

- **TULIP** (dominantný): Ramara (366460/366466/366467), Resina 256–1184 (500454, 500458, 399517, 399520, 399522, 500461), Sophia 596 (494268), Marina (203825/203826), Cub 320 (494766), vešiak Kara L (35572, 355727, 355730 — Disk 3/9).
- Quatro LM: TECHNO AL 320 (190890), TEO 256 (19187), knopky COMO BIG/BELT VIEFE, profil ukw7 (19164). INTEREX: VARADERO zlatá (494760). datof: DHT-920 F1/F41.
- Úchytkové profily: Lucata 3000 (284334), Paolo II (276820), Juvio II čierny (466365), UKW 5 biely (nabytkar), LED úchytkový LUCERA (359426).
- Posuv: TERNO Magic2 1100/1800 (368393/368394, profil 412696) · TopLine XL (398010 + 398033 + 398053).
- Šatník: StrongWire tyč (15512) + držiak (314029), LE MANS, TurnMotion II (315044), systém ZERO (INTEREX).
- LED (v 6/9 zákaziek): profily Lucera 2000/4000 (359333/359334/359426/359427), Begton 12 (285044), Groove 10 (269800/130634/353543), Surface 10 (252277), Corner (252278), krycia lišta C 20 m (404412/416710); schéma profil + pás bm + trafo.
- Elektro: TAOBOX (Qua 28141), SLIDE BOX (28313), výsuvná zásuvka STRONG (508881), Qi nabíjačka (397998).

### 2.6 Pomery pre automatiku (overené v oboch sondách)

- **Dvierka klasik:** 2× (záves 104717 + platnička 106412 + krytky 105408 + 105425) — SET 1:1:1:1.
- **Dvierka P2O:** 2× (245723 + platnička + krytky) + 1× TipOn 250831 na dvierka.
- **Zásuvka:** 1× K-sada (Atira/StrongMax/StrongBox/Legrabox) — vnútorná +čelo/príchyty; drevený šuflík: pár Quadro V6 + spojky (alebo K-set).
- **Výklop:** 1× set Aventos + krytky zvlášť.
- **Spodná skrinka:** 4× klzák 17 mm ALEBO 4× AXILO; **horná skrinka:** 2× Bystrica; police: 4 podperky/policu.
- **VEPO služby na zákazku:** olep 0,90 €/bm, porez 17 €/platňa, dupláky 50 €/fix, opracovanie PD 100 €/fix (ceny s DPH — orientačné z rozpočtov 2026).

---

## 3. OTVORENÉ DIERY (doplniť priebežne)

1. ~~Kód krytiek Sensys~~ — **VYRIEŠENÉ (debata 2.8.):** miska **105408** + ramienko **105425** (doplnil Michal; súčasť SET ZÁVES 1:1:1:1).
2. **Skladové zásoby (Michal)** — naskladnené položky (AXILO 100 ks, podložky, SPAX…) skresľujú frekvencie objednávok; Michal dodá stavy → upravia sa pomery kovania.
3. **Falco a Kastamonu** — zdroj/kódy (Y121, A860; „FAL 500 SM 16" cez VEPO) — nejasný dodávateľ a či majú DK kódy.
4. **ABS mapovanie dekor↔kód** (POJMY ot. 2) — z Disku už máme reálne kódy: 515069 (skupinová biela), 356427 (Cashmere BS/PD), 398905, 514401/514404, 392486, 510705, 495215; doplniť pri Demos importe (V0.6 „zadaj kód").
5. **Pracovné dosky v dekorovej skupine** (POJMY ot. 1/3) — testovacie rodiny z praxe: F206 (DTDL+PD+kompakt+zástena), K2738 (DTDL+PD FP), K551 (kompakt+PD), F800 (DTDL+PD 600/920).
6. **StrongMax 16/18** — nastupujúci systém (3 zákazky 2025–2026, v Gmail objednávkach chýba) — potvrdiť zaradenie do V0.6 katalógu popri Atire.
7. **AvanTech YOU** — nikde sa nevyskytol; V0.6 stavať na InnoTech Atira (+ StrongMax), nie AvanTech.
8. **Neprečítané zdroje:** 2 ODT rozpočty 2025 (kuchyňa; chodba+kúpeľňa+schody), prílohy VEPO v mailoch (PDF faktúry/CP), stránka 2+ vyhľadávania Disku (2023–2024).
9. **Ceny** — všetky orientačné; evidencia s DPH (firma neplatca). Pri seede zadať aktuálne nákupné ceny, alebo nechať „nezadané".
10. **Externé dvierka a panely** (Trachea, Svet dvierok, SALU, flexipanely.sk) — ako ich zachytiť v katalógu (nákupný set / služba?), zatiaľ mimo štandardu platní.
11. **Kolízie kódov v starých rozpočtoch** — 353850 („Betón K540" vs 6299 BS), 142438 (Antracit vs preklep pri 500 SM) — pri importe brať Demos ako autoritu.

---

## 4. Zdrojové dokumenty

- [GMAIL_KOVANIE_sonda_2026-07.md](GMAIL_KOVANIE_sonda_2026-07.md) — objednávky kovania z firemného Gmailu (2023–2026), sety, dodávatelia (VEPO/Demos), naskladňovací zoznam 12/2024.
- [DISK_ZAKAZKY_sonda_2026-07.md](DISK_ZAKAZKY_sonda_2026-07.md) — 9 zákazkových rozpočtov + CP + firemná šablóna rozpočtu z Google Disku (2024–2026), frekvencie materiálov aj kovania, ceny, VEPO služby.
- [../archiv/DOGFOODING_historia.md](../archiv/DOGFOODING_historia.md) — sekcia „Seed katalógu" (ručný zoznam Michal 25. 7.) + 2A migračná mapa existujúceho katalógu. *(Obe sekcie boli do 11.8.2026 v živom zápisníku DOGFOODING.md.)*
