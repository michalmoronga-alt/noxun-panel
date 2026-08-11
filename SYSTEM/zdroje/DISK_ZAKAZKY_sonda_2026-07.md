# DISK sonda — zákazkové rozpočty: materiály a kovanie (podklad pre seed katalógu)

**Dátum sondy:** 31. 7. 2026 · **Zdroj:** firemný Google Disk (konektor, iba čítanie) · **Spracoval:** agent
**Účel:** z reálnych rozpočtov objednaných zákaziek zistiť, ktoré materiály (dekory, typy, hrúbky, DK kódy) a kovanie sa reálne používajú a v akých počtoch → seed katalógu Noxun Engine.

---

## 1. Metodika

- **Dotazy:** `title contains 'Rozpočet'/'Rozpocet'` a `title contains 'Cenová ponuka'/'CP'` (obe vrátili 30+ súborov už na 1. stránke; XLSX, ODT, PDF, DOCX + .skp modely).
- **Spracované v plnom znení: 10 dokumentov** — 8 XLSX rozpočtov (najnovšia verzia každej zákazky), 1 PDF rozpočet (9/2024), 1 CP (DOCX, vzorka — CP majú len špecifikáciu + súhrnné ceny, granulárne položky sú v rozpočtoch). Navyše 1 XLSX so šablónou rozpočtu (nulové počty, kompletný rozpis položiek — viď §6).
- **Obdobie pokryté:** september 2024 → júl 2026.
- **Formát rozpočtov:** jednotný hárok `MATERIÁL | DEMOS KÓD | MJ | POČET | CENA za MJ | SPOLU` — položky = plošný materiál s DK kódmi, ABS, externé služby VEPO (porez/olep/dupláky), kovanie s DK kódmi, doplnky, réžia.
- **Anonymizácia:** názvy súborov na Disku obsahujú mená klientov — v tomto dokumente zákazky označujem Z1–Z9 podľa typu. Osobné údaje sa neprenášajú.
- **Limitácia:** 2 rozpočty z r. 2025 (ODT — kuchyňa, chodba+kúpeľňa) sa nepodarilo dekódovať (poškodený prenos base64); stránka 2+ výsledkov vyhľadávania (staršie 2023–2024 verzie tých istých zákaziek) nebola čítaná. Frekvencie sú preto dolný odhad, vzorka je ale konzistentná.

### Spracované zákazky

| Ozn. | Typ zákazky | Dátum rozpočtu | Objem (SPOLU) |
|---|---|---|---|
| Z1 | klinika — recepcia + zázemie (komerčná, najväčšia) | 29. 7. 2026 | 16 200 € |
| Z2 | poschodie RD (šatníky, kúpeľňa, práčovňa, TV steny) | 17. 1. 2026 | 18 800 € |
| Z3 | detská izba (+ CP písacie stoly 6/2026) | 15. 6. 2026 | 1 172 € (+1 170 €) |
| Z4 | menšia zákazka (skrinky s Trachea dvierkami) | 14. 6. 2026 | 1 202 € |
| Z5 | detské ihrisko / škôlka (komerčná, veľkosériová) | 22. 3. 2026 | 10 100 € |
| Z6 | kozmetický salón (komerčná) | 1. 5. 2026 | 4 480 € |
| Z7 | chodba + kúpeľňa + schody RD | 30. 4. 2026 | 5 620 € |
| Z8 | spálňa | 12. 8. 2025 | 4 250 € |
| Z9 | kuchyňa + kúpeľňa (PDF) | 7. 9. 2024 | 9 100 € (+„daň" → 10 920 €) |

---

## 2. TOP materiály (frekvencia = počet zákaziek, v ktorých sa dekor objavil)

### 2.1 Štandard každej zákazky (korpusy)

| Materiál | DK kód | Frekvencia | Kusy spolu | Poznámka |
|---|---|---|---|---|
| **DTDL 500 SM BU Biela 2800/2070/18** (Kronospan) | **142390** | **8/9** | ~44 platní | korpusový štandard; v rozpočtoch často len „DTDL 500SM / VEPO" bez kódu |
| **DTDL 500 SM BU Biela 2800/2070/16** | **142483** | 6/9 | ~10 platní | tenší variant; zapisovaný aj ako „FAL 500 SM …/16" (Falco doska v rovnakom dekóre, cez VEPO) |
| **HDF biely 2800/2070/2,5** | — (VEPO) | 8/9 | ~32 ks | chrbty; vždy bez DK kódu |
| ABS 22/1 (k dekóru korpusu/čiel) | podľa dekoru | 9/9 | stovky bm | základná páska všade |
| ABS 42/2 | podľa dekoru | 7/9 | ~100 bm/zák. | na dupláky a hrubé čelá |

### 2.2 Dekory čiel a viditeľných častí (podľa zákaziek)

| Výrobca | Dekor | Názov | Typ + hrúbka | DK kód | Výskyt |
|---|---|---|---|---|---|
| Egger | F206 ST9 | Pietra Grigia čierna | DTDL 18 · PD 38 (4100/600) · kompakt KD-IN 12 (4100/650) · zástena 9,2 (F206/F221) | 396087 · 398117 · 472100 · 399163 | **2 zákazky (Z8, Z9)** — celá rodina výrobkov |
| Kronospan | K2738 PW BU | Torro Cremona Oak | DTDL 18 · PD FP 38 (4100/900) | 532848 · (PD bez kódu v rozpočte; seed uvádza 532772) | Z1 (4 platne) + šablóna |
| Kronospan | 5981 | Cashmere | **BS** DTDL 18 (Z7) · **MG** DTDL 18 (šablóna/seed) | BS 353840 · MG 473933 | 1 zákazka + šablóna; ABS „5981 BS/5981 PD" = 356427 |
| Egger | U750 ST9 | Taupe šedá | DTDL 18 | 175726 | Z2 — **11 platní** (najväčší jednorazový odber dekoru) |
| Egger | H3303 ST10 | Dub Hamilton prírodný | DTDL 18 | (v rozpočte cez VEPO bez kódu; seed 175718) | Z4 (3 platne) |
| Kronospan | K097 SU BU | Dusk Blue | DTDL 18 | 353854 | Z5 (4 platne) |
| Kronospan | 8921 BS BU | Ferrara Oak | DTDL 18 | — (bez kódu v rozpočte) | Z5 — **19 platní** (najväčší objem sondy) |
| Kronospan | 6299 BS BU | Cobalt Grey | DTDL 18 | 353850 | Z3 (2) + Z9 (2, tam ako „Betón K540" — viď §5 kolízie) |
| Kronospan | K540 PN BU | Grey Albus | DTDL 18 | 495040 | Z3 (1) |
| Kronospan | 4298 SU BU | Light Atelier | DTDL 18 | 353858 | Z8 (2) |
| Kronospan | K686 PD BU | Powder Pink | DTDL 18 | 532804 | Z1 (3) |
| Egger | W1100 ST30 | Alpská biela LESK | DTDL 18 | 307952 (ABS 392486) | Z1 (1) |
| Egger | U636 ST9 | Fjordská zelená | DTDL 18 | 413744 | Z1 (1) |
| Egger | F243 ST76 | Mramor Candela svetlo šedý | DTDL 18 | 514270 | Z2 (4) |
| Egger | F800 ST9 | Mramor krištáľový | DTDL 18 | 514269 | Z2 (1) |
| Egger | H1344 ST32 | Dub Sherman koňakovo hnedý | DTDL **18,6** | 396066 (ABS 398905 23/0,8) | Z7 (2) |
| Egger | H3317 ST28 | Dub Cuneo hnedý | DTDL **22,6** | 522021 (ABS 0,8 = 514401 · ABS 43/2 = 514404) | Z9 (4) |
| Kronospan | K551 SU | Calacatta Olympus | kompakt SLIM LINE 12 (4100/650) · PD ABS 38 (4100/635) | 495130 · 495404 (ABS mramor hrana 42/1 = 510705) | Z1 |
| — | PV FOLI | Preglejka breza fóliovaná biela 2500/1250/18 | preglejka | 167777 | Z5 (5) — CNC frézované diely |
| — | AL06/AL06 | MDF LAM Brushed Bronze 2800/1300/18,7 | MDF obojstranný | 501560 | Z2 (1) |

**Poznatky k materiálom:**
- **Hrúbky v praxi:** 18 (dominantná), 16 (korpus ekonomy/Falco), 2,5 (HDF), 38 (PD), 12 (kompakt KD-IN), 9,2 (zástena), 18,6 a 22,6 (Egger „hrubšie" dekory — potvrdzuje D-45 guard hrúbok), 18,7 (MDF AL06).
- **ABS s DK kódmi z rozpočtov:** biela skupinová páska **515069** „Biela hladká W960/W980/101/110/500/8100/8685 SM 23/0,8" — jedna páska oficiálne pokrýva celú skupinu bielych dekorov (podklad k otázke mapovania ABS, POJMY ot. 2). Ďalej 356427 (Cashmere BS/PD), 398905, 514401/514404, 392486, 510705, 495215.
- **Externé dvierka** (nie z DTDL): Trachea (Z4, Z9 — sety 130–230 €), Svet dvierok „TVAR" supermat (Z2, 741 €), SALU šatníkové/hliníkové rámy (Z2 614 €, Z7 222 €). Do katalógu raz ako nákupná položka-set.
- **Flexipanely.sk** (obkladové panely/lamely: Marble Calacatta, Wave Gold, HARD Rock White, LAMELY Classic White) — 4 zákazky; kupujú sa na ks + doprava.

---

## 3. TOP kovanie (frekvencia = počet zákaziek; kusy = súčet cez zákazky)

### 3.1 Závesy Hettich Sensys — jadro systému

| Položka | DK kód | Zákazky | Kusy | Poznámka |
|---|---|---|---|---|
| Sensys 8645i 110° TH52 naložený SiSy „KLASIK" | 104717 | **7/9** | **~212** | Z5 sama 110 ks; položka je v KAŽDOM rozpočte (aj s počtom 0) |
| Sensys 8675 110° TH52 **P2O** (k tip-onu) | 245723 | 6/9 | ~66 | bez tlmenia, push-to-open |
| **Podložka 8099 s excentrom D=1,5** | 106412 | 8/9 | ~254 | **presne = súčet všetkých závesov zákazky (1 : 1)** — potvrdené napr. Z6: 20+8 závesov = 28 podložiek |
| **Krytky (misky + ramienka), set** | — (bez kódu) | 8/9 | ~213 | tiež 1 : 1 k závesom (výnimka Z5: 50 na 110) |
| BLUM 956A1004 TipOn 76 mm s magnetom, biely | 250831 | 5/9 | ~21 | pomer P2O záves : TipOn ≈ 2–4 : 1 |
| Záves chladničkový + platničky | 104454 | 3/9 | 15 | Z2 až 10 ks |
| Sensys 8657i 165° naložený SiSy | 264246 | 1/9 | 5 | Z9 |
| Sensys 9088021 TH52 W90 (uhlový) | 104802 | 1/9 | 2 | Z9 |
| podložky doplnkové: euroskrutka D1,5 / D=0 | 119240 / 106406 | 1/9 | 5 / 2 | Z9 |

### 3.2 Zásuvkové systémy — poradie podľa nasadenia

| Systém | Kódy z rozpočtov | Zákazky | Sady | Poznámka |
|---|---|---|---|---|
| **HETTICH InnoTech Atira** (K-sady) | 357695 (čelný biely **420/70**!) · 357774 (420/70/176) · 357783 (zásuvka 176, **620 mm/50 kg**) · 357775 (470/70/176) · 357819 (vnútorný 470/70) | 2/9 | **42** | Z1 sama 39 sád (30× 420/70); dopĺňa Gmail sondu o hĺbku 420 a nosnosť 50 kg |
| **StrongMax 16/18** — NOVÉ oproti Gmail sonde | 16: 502957 (H185/500 šedá) · 502972/502973 (H89) · 502986/502988 (H185) · 502993/502995 (H249) · 503020 (H185/450 čierna) · 334973 (89/450) · 18: 482262 (249/450) | **3/9** | **~40** | ekonomická náhrada Atiry od 2025/2026: výšky H89/H185/H249, hĺbky 350–550, biela/šedá/čierna |
| **StrongBox** | 179254 (H86/350) · 179263 (H140/450) · 179264 (H140/500) · 402578 (H140/350 reling) · 402593/402596 (H204/400 a 550, 2 relingy) | 5/9 | ~19 | drobné zásuvky, kúpeľne |
| **Quadro V6 skryté celovýsuvy** (K-sety s príchytmi) | 317642 (450/18 mm) · 317645 (500) · 343031 (350) · CP: „V6 550/450" 6× | 5/10 | ~15 | pod drevené šuflíky; dĺžky 350–550 |
| BLUM Antaro | 254431 (M 500 vnútorná biela) · 254680 (D 500 biela) | 1/9 | 8 | len Z9 (2024) — dnes už nahradené |
| Rohový výsuv LEMANS (Quatro) | 37025 | 1/9 | 1 set | Z9 |
| Potravinová skrinka Space Tower | 260822 | 1/9 | 1 | Z9 |

### 3.3 Výklopy

| Položka | DK kód | Zákazky | Ks |
|---|---|---|---|
| **BLUM Aventos HL Top set** („vr. ramien, krytiek a montážneho príslušenstva", à 180 €) | — (set) | 2/9 | **8** (Z1 má 7!) |
| BLUM Aventos HK top silný + krytky + čelný príchyt | 347812 + 347834 + 13781 | 1/9 | 2 |
| KES horný výklop Maxi „D" | 135043 | 1/9 | 2 |
| IF K12 244 plynokvapalinová vzpera 120 N | 282474 | 1/9 | 4 |
| výklop plynový (generický) | — | 1/9 | 1 |

### 3.4 Nohy, klzáky, kolieska

| Položka | DK kód | Zákazky | Ks | Poznámka |
|---|---|---|---|---|
| **STRONG klzák s rektifikáciou 17 mm** („nohy 17 mm") | 82744 (Z9 variant 272212) | **8/9** | **~166** | najrozšírenejšia „noha" vôbec — sokel na klzákoch |
| **Noha AXILO 150 mm + podložka** (Häfele 637.76.355) | 367823 | 6/9 | ~124 | Z1 50 ks; AXILO 60 mm tiež (Z2, 12 ks) |
| Centrálna noha BELL II zdvojená H-710 čierna | — (VEPO) | 1/9 | 111 | Z5 (stolíky) |
| Nábytková podnož GRENADA čierna | 488856 | 1/9 | 14 | Z5 |
| Noha 710/60×60 (stolová) | Quatro 9098 | 1/9 | 6 | |
| TENTE koliesko otočné 1470, 50 mm | 154145 | 1/9 | 4 | |
| stolové podnože: MILADESIGN G5 (219102/219115/219127), Industry (Quatro 9102, tvojregal.sk) | | 3/10 | | šablóna + Z3 + Z9 |

### 3.5 Úchytky, vešiaky, profily

- **TULIP:** Resina 832/960 čierna matná (500461, 399520), Cub 320 champagne (494766), vešiak Kara L biela/čierna (35572, 355727, 355730 — 3 zákazky, 13 ks) — potvrdzuje dominanciu TULIP z Gmail sondy.
- **Quatro (LM):** TECHNO AL 320 čierna (190890) · TEO 256 čierna (19187) · knopky COMO BIG VIEFE D41 (19509/19512) · BELT VIEFE · úchytkový profil ukw7 (19164).
- **INTEREX:** VARADERO 320/128 zlatá brúsená (494760) · madlo HOME zlaté · dekoratívne lišty.
- **datof:** DHT-920 F1 čierna / F41 biela (à 36 €!) — dizajnové kusy Z1.
- Úchytkové profily: Paolo II 2900 elox (276820), Juvio II 2900 čierny (466365), UKW 5 biely (nabytkar), + Gmail: Lucata.
- Posuvné systémy: TERNO Magic2/1100 s tlmením (368393) + podlahový profil (412696) — Z2; TopLine XL sada+tlmenie+vedenie (398010, 398033, 398053) — Z2.
- Šatník: StrongWire tyč oválna (15512) + držiaky (314029), systém ZERO INTEREX (stojky+tyče+úchyty, béžová/čierna), otočný stojan ROYAL (29521).

### 3.6 LED a elektro (v 6/9 zákazkách!)

- Profily StrongLumio/TM: **Lucera narážací** 2000/4000 (359333, 359334, 359426, 359427) — 4 zákazky; Begton 12 (285044) — 2; Surface 10 (252277), Groove 10 (130634), LED Corner (252278); krycia lišta C mliečna 20 m (404412) — 2.
- LED pás na bm + trafo + vypínač + „robota LED" — pravidelná schéma: profil ks + pás bm + trafo ks.
- Zásuvkové elementy: TAOBOX 2×230+USB (Qua 28141), SLIDE BOX USB (28313), VERTIKAL FAT nerez (INTEREX), Qi nabíjačka pod dosku (397998).
- Drezy/batérie (4 zákazky, drezyonline.sk): Alveus (Kombino 50, Meryll 30, Azeta II, Siros, dávkovač Pear), Blanco (Etagon 700-U, Catris-S, Lato), Franke (Urban UBG 610-56), kielle.

---

## 4. Externé služby VEPO (v každom rozpočte — konštanty firmy)

| Služba | MJ | Cena | Výskyt |
|---|---|---|---|
| Olepovanie ABS hrán | bm | 0,90 € | 9/9 |
| Porez | platňa | 17,00 € | 9/9 |
| Lepenie duplákov | fix | 50 € (Z7: 150 €, Z8: 100 €) | 7/9 |
| Opracovanie pracovnej dosky | fix | 100 € (často 0) | 4/9 |
| Frézovaný spoj PD | fix | 50 € | Z9 |
| Montáž (interná kalkulácia) | m² | 12–15 €/m², cez „platňa = 5,8 m²" | 9/9 |

---

## 5. Ceny a DPH

- **Firma NIE JE platca DPH** — explicitne v CP 6/2026: „Nie sme platcami DPH, a preto všetky ceny… sú konečné a neobsahujú DPH." Nákupné ceny materiálu/kovania sú pre firmu vždy koncové **s DPH dodávateľa** (neodpočítava sa) → podporuje pravidlo katalógu „ceny sa evidujú s DPH".
- Rozpočet Z9 (2024) má na konci „SPOLU 9 100 € **+ daň** 10 920 €" (+20 % na celok) — interné navýšenie na finálnu cenu, položkové ceny sú bez tohto navýšenia.
- **Orientačné nákupné jednotkové ceny** (naprieč rozpočtami stabilné): DTDL biela 18 = 49–60 €/platňa · DTDL dekor 18 = 60–160 €/platňa · HDF = 20–35 €/ks · ABS 22/1 = 0,4–1,25 €/bm · ABS 42/2 = 2,5–4 €/bm · záves 104717 = 4 € · P2O 245723 = 3,3–3,5 € · podložka = 1 € · krytky set = 1 € · TipOn = 7 € · Atira K-sada = 43–77 € · StrongMax = 14–54 € · StrongBox = 18–35 € · Quadro V6 set = 30–36 € · Aventos HL set = 180 € · AXILO = 1–2 € · klzák 17 = 0,4–0,5 €.
- **Kolízie kódov (pozor pri seede):** Z9 „Betón K540" má kód 353850, ktorý inde (Z3) patrí dekóru 6299 BS Cobalt Grey (K540 PN má 495040) — v starom rozpočte je preklep názvu. Z8 „500 SM 18 mm" uvádza 142438 (patrí 164 PE Antracit; správne 142390) — preklep kódu. DK kódy v rozpočtoch treba brať ako indíciu, autorita je Demos.

## 6. Šablóna rozpočtu (roster položiek firmy)

Jeden XLSX na Disku (pôvodne rozpočet inej zákazky) je prepísaný na **šablónu novej zákazky** — všetky počty 0, ale kompletný zoznam „default" položiek s cenami: 500 SM 18+16, K2738 PW + PD FP Torro Cremona 4100/900/38, MDFL 5981 MG Cashmere, HDF, VEPO služby, závesy (104717, 245723, 104454, 106412, krytky, TipOn), Atira 357774/357695, Quadro V6 350 (343031), AXILO, klzák, MILADESIGN podnože, TAOBOX, LED sekcia, réžia. Toto je de facto firemný checklist rozpočtovania — dobrý základ pre poradie položiek v katalógu.

## 7. Poznámky a limity

1. CP dokumenty majú štruktúrovanú sekciu ŠPECIFIKÁCIA (KORPUSY / CHRBTY / DVIERKA / ÚCHYTKY / VÝSUVY / NOHY) — presne zodpovedá rolám v Engine; granulárne položky ale nesú len rozpočty.
2. Vzorka 9 zákaziek; 2 ODT rozpočty (2025) ostávajú neprečítané — kuchynské dáta za 2025 chýbajú (čiastočne kryté Z9/2024 a Z7/2026).
3. Frekvencie kovania sedia s Gmail sondou (Sensys+podložka+krytky, Atira, TipOn, AXILO, TULIP); **nové oproti Gmail sonde:** StrongMax 16/18 (nástup 2025+), Atira hĺbka 420 + zásuvka 620/50 kg, Aventos HL ako SET položka à 180 €, KES Maxi D, LEMANS, Space Tower, GRENADA/BELL II podnože, TopLine XL, Antaro (historicky).
4. Dodávatelia doplnení z rozpočtov: **Quatro LM** (úchytky, knopky, nohy, koše, LEMANS, TAOBOX — reálny dodávateľ, nie len marketing), **INTEREX**, **datof**, **flexipanely.sk**, **drezyonline.sk**, **tvojregal.sk**, SALU, Svet dvierok, Trachea (cez VEPO), aqaglass, IKEA, OBI.
