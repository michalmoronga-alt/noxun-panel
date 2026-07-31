# GMAIL sonda — reálne objednávané KOVANIE (podklad pre seed katalógu kovania)

**Dátum sondy:** 31. 7. 2026 · **Účet:** noxuninfo@gmail.com (firemný) · **Režim:** iba čítanie
**Účel:** zistiť, aké kovanie sa reálne najviac objednáva → seed katalógu kovania pre Noxun Engine (V0.6 KOVANIE).

---

## 1. Metodika

- **Dotazy:** `objednávka kovanie`, `to:objednavky@vepo-porez.sk` (2 stránky), `Hettich`, `AvanTech OR InnoTech OR Quadro OR Legrabox OR StrongBox OR Atira`, `in:sent objednávka`, `from:demos`.
- **Prezreté:** ~200 vlákien v prehľade (subject + snippet), ~15 kľúčových objednávok prečítaných v plnom znení.
- **Obdobie pokryté objednávkami:** júl 2023 → máj 2026 (3 roky).
- **Hlavný kanál objednávok:** e-maily na `objednavky@vepo-porez.sk` (VEPO s.r.o., Ružomberok). VEPO je medzičlánok — tovar reálne dodáva **Demos Trade** a v objednávkach sa uvádza demosácky **„Kód sortimentu"**. Všetky kódy nižšie sú teda Demos kódy (rovnaká sústava ako CSV katalóg v `DEMOS\`).
- Objednávky sú voľný text / vložené tabuľky z Excelu — položka = názov + kód + počet ks/sady/páry/balenia.
- Limitácia: prílohy (PDF faktúry, CP od VEPO) sa nedali čítať — extrakcia len z tiel mailov. Frekvencie sú preto **dolný odhad**.

**Kľúčový nález č. 1:** mail **„kovania priemyslené balenia" (10. 12. 2024)** — firma si sama zostavila zoznam „kovania, ktoré používame najčastejšie" na naskladnenie vo veľkých baleniach. To je de facto hotový seed zoznam od majiteľov (prevzatý nižšie v sekcii 5).

**Kľúčový nález č. 2:** objednávka **„maxwell kovania" (27. 4. 2026)** má presné počty setu závesu: 28 závesov : 28 podložiek : 28 setov krytiek = **1 : 1 : 1** — potvrdzuje Michalov popis SETU.

---

## 2. TOP kovanie podľa frekvencie výskytu v objednávkach

Frekvencia = počet nezávislých objednávok/mailov, kde sa položka objavila (min. odhad z tiel mailov).

### Závesy (dominancia HETTICH Sensys — potvrdené)

| Položka | Kód (Demos) | Výskyty | Poznámka |
|---|---|---|---|
| HETTICH 9071205 Sensys 8645i 110° TH52, naložený, SiSy | 104717 | 3× | interne označené **„KLASIK"** — základný záves (SiSy = Silent System, tlmenie) |
| HETTICH 9071207 Sensys 8645i 110° TH52, vložený, SiSy | 104719 | 1× (50 ks!) | vložený variant toho istého závesu |
| HETTICH 9071313 Sensys 8675 110° TH52 P2O (k Tip-onu) | 245723 | 3× (8–20 ks) | **bez tlmenia, pre push-to-open** — vždy s TipOn adaptérom |
| HETTICH 9099540 Sensys 8657i TH52 165°, naložený, SiSy | 264246 | 2× (20 ks) | veľký uhol 165° (rohy, výklopné situácie); kupovaný aj cez FP Interier |
| **HETTICH 9071656 podložka 8099 s excentrom D=1,5** | 106412 | **4×** (28–100 ks) | krížová podložka 1,5 mm — **objednáva sa ku KAŽDÉMU závesu** |
| Krytky (misky + ramienka), set | — (bez kódu) | 2× | v objednávke voľným textom; VEPO potvrdilo, že krytky nie sú súčasťou balenia |
| Záves chladničkový HETTICH + platničky | 104454 | 1× | pre vstavanú chladničku, „komplet aj s platničkou" |
| BLUM 71T950A naložený 95°, alu, skrutka (Onyx) | 306329 | 1× (6 ks) | Blum len doplnkovo |
| BLUM 71B7590 naložený 155°, Blumotion, Inserta (Onyx) | 347943 | 2× (2+6 ks) | veľký uhol Blum |
| BLUM CLIP top (kód bez názvu v objednávke) | 306327 | 1× (12 ks) | |

**Pomery:** maxwell 28:28:28 (záves : podložka : krytky = 1:1:1). Ihrisko 50 závesov : 100 podložiek (1:2 — pravdepodobne aj zásoba). Samostatný nákup „platničky na závesy hettich 1,5 — 50 ks" (8/2023) potvrdzuje, že podložka je spotrebná položka skladu.

### Push-to-open k závesom P2O

| Položka | Kód | Výskyty | Poznámka |
|---|---|---|---|
| BLUM 956A1004 TipOn pre záves, dlhý 76 mm, s magnetom | 250831 biely / 250834 čierny / 497007 karbon sada | 3× | pomer cca **2 závesy P2O : 1 TipOn** (na dvierka 2 závesy + 1 tipon) |
| BLUM 956A1201 adaptér priamy pre TipOn 76 mm | 497010 | 1× (6 ks) | |
| BLUM 955.1008 doštička TipOn na nalepenie | 348000 | 1× | protikus |
| „tip on" (Strong/IF magnet, mag. protikus súčasť balenia) | 35000 | 2× (10 ks) | lacnejšia alternatíva; magnetický protikus k zavrtaniu je súčasť |
| IF K-Push dlhý extra silný s magnetom, biely | 499437 | 1× | |

### Šuflíky / výsuvy — systémy podľa frekvencie

**1. HETTICH InnoTech Atira — hlavný systém plechových zásuviek** (7 objednávok, najviac zo všetkých):

| Variant | Kód | Výskyty |
|---|---|---|
| K-InnoTech Atira, čelný, biely, 470/70, 30 kg, SiSy | 357696 | 1× (naskladnenie) |
| K-InnoTech Atira, čelný, biely, 470/70/176 vr. relingu | 357775 | 1× (naskladnenie) |
| K-InnoTech Atira, čelný, antracit, 470/70/176 vr. relingu | 357970 | 1× (3 sady) |
| K-InnoTech Atira, vnútorný, antracit, 420/70 | 358009 | 1× (3 sady) |
| K-InnoTech Atira, vnútorný, antracit, 420/70/144 vr. relingu | 358046 | 1× (2 ks) |
| K-InnoTech Atira, vnútorný, biely, 470/70 | 357819 | 1× (1 set) |
| K-Atira zásuvka 176, 300 mm/30 kg, relingy, biela | 357772 | 1× (4 sady) |

Vzor: prefix **„K-"** = kompletná sada (bočnice + výsuv Quadro so SiSy). Parametre v názve: **čelný/vnútorný · farba (biela/antracit) · hĺbka (300/420/470) · výška 70 · nadstavba relingom (144/176) · 30 kg**. Príslušenstvo Atira objednávané samostatne: priečny reling 2000 (294812), čelo vnútornej zásuvky 2000/70 biela (294940) / antracit profil (294941), príchyt čela 70 biely pár (295276) / antracit (295277), adaptér variabilného relingu (295318), OrgaStore 410 adaptér (294816), 294825/294826.

**2. HETTICH Quadro V6 — skryté celovýsuvy pod drevenú zásuvku** (3 objednávky):

| Položka | Kód | Výskyty |
|---|---|---|
| Quadro V6 450 EB23 celovýsuv P2O Ľ / P | 315830 / 315831 | 1× (3+3 ks) |
| spojka Quadro 25 / Quadro V6 L / P | 104547 / 104548 | 1× (5+5 ks) |
| K-HETTICH set Quadro V6 450 + príchyty P2O komplet | 317644 | 1× |
| K-HETTICH Quadro V6 skrytý celovýsuv 450 mm/30 kg, sada pre 18 mm | 317642 | 1× (3 ks) |

Dĺžka vždy **450 mm**, nosnosť 30 kg, P2O verzia.

**3. BLUM Legrabox — prémiové zákazky, karbon čierna** (5 objednávok):

| Položka | Kód | Výskyty |
|---|---|---|
| K-BLUM Legrabox M 450 mm/40 kg, Blumotion/TOB, karbon čierna CS-M | 499013 | 1× (4 sety) |
| K-BLUM Legrabox K 450 mm/40 kg, Tip-on, karbon čierna CS-M, vnútorná | 499307 | 1× |
| bočnica Legrabox F 500 mm karbon čierna (770F5002S) | 491339 | 1× (3 ks) |
| výsuv Legrabox 450 mm/40 kg TOB (750.4501S) | 349906 | 1× (1 pár) |
| čelný plech vnút. zásuvky (ZV7.1043C01) / čelný reling vnút. (ZR7.1080U) | 491360 / 491359 | 2× / 1× |
| sada modulov Legrabox/Movento TOB-L5 (T60L7570) + synchro hriadeľ (T60.1125W) + synchro adaptér (T60.000D) | 275347 / 282277 / 275348 | 1× |

Dĺžka najčastejšie **450 mm**, výšky M/K/F, vždy karbon čierna CS-M, TOB (Tip-on Blumotion).

**4. StrongBox — lacný kovový šuflík (ekonomická línia)** (4 objednávky): H86/270 biely (179252, 2 sety), H140/500 biela (179264, 2), K-StrongBox H140/350 s hranatým relingom (402578, 3+1), H140/270 s relingom (402576), príborník StrongIn 804×474 (501014). Výšky H86/H140, biela.

**5. BLUM Tandem — čiastočný/celovýsuv pod drevo, Tip-on** (1 veľká objednávka 2023): celovýsuv 550 (13497, 4 páry) + 500 (13496), čelné kovanie L/P (13469/13470), pastorok T55.000R (12226), hriadeľ T55.889W (12227), Tip-on adaptér T55.7150S (12229), synchro hriadeľ T57.1142S (471902).

**AvanTech YOU sa v objednávkach NEOBJAVIL ani raz** — firma jazdí na staršom InnoTech Atira.

### Výklopy (BLUM Aventos)

| Položka | Kód | Výskyty | Poznámka |
|---|---|---|---|
| BLUM 22F2800 Aventos HF Top silný, skrutky | 507336 | 1× (set) | VEPO upozornilo: **krytky nie sú v balení** — objednať zvlášť |
| BLUM 22K2700T Aventos HK top silný, Tip-on | 347827 | 1× (pár) | + „HK TOP komplet aj s čiernymi krytkami" pri alu dvierkach 2× |
| Aventos HL set (10/2023): HL stredný + ramená 450–580 + čelný príchyt 20S4200 + krytky 20L8020 + stabilizačná tyč 20Q1061UA | 23792 + 197611 + 13781 + 461804 + 13799 | 1× | kompletná anatómia setu HL v jednej objednávke |
| IF K12 244 plynokvapalinová vzpera 120 N automatická | 282474 | 1× (6 ks) | lacná alternatíva výklopu |

### Nohy, rektifikácia

| Položka | Kód | Výskyty | Poznámka |
|---|---|---|---|
| AXILO (Häfele 637.76.355) noha 150 mm + podložka | 367823 | 2× | naskladnenie 100 ks + 12 ks; aj 60 mm (100 ks) a platničky (200 ks) |
| Strong Big rektifikačná noha 100 mm | 146993 | 1× (40 ks) | |
| rektifikáty čierne / Závesné kovanie Bystrica biele (rektifikát) | 93240 | 3× (50–100 ks) | „Bystrica" = závesné kovanie hornej skrinky, sivá/čierna/biela |
| STRONG klzák s rektifikáciou 17 mm čierny | 82744 | 1× (24 ks) | |
| Centrálna noha stolová hranatá 60×60 H-710 čierna (aj BELL II zdvojená) | — | 2× (8+5 ks) | stolové podnože |

### Úchytky (TULIP — jednoznačne dominantná značka)

| Rad | Kódy z objednávok | Výskyty |
|---|---|---|
| TULIP Ramara (296/796/896, čierna brúsená) | 366460 / 366466 / 366467 | 3× |
| TULIP Resina (256/448/480/672/1184, čierna matná) | 500454 / 500458 / 399517 / 399522 | 2× |
| TULIP Sophia 596 čierna matná | 494268 | 1× |
| TULIP Marina (320/480, brúsený nerez) | 203825 / 203826 | 2× |
| TULIP úchytový profil Lucata 3000 hliník | 284334 (+ 494662) | 2× |
| LED lišta úchytková TM-profil LUCERA narážací 4000 + tesnenie | 359426 | 1× (5 ks) |

### Spojovací a montážny materiál (v takmer každej objednávke)

| Položka | Kód | Výskyty |
|---|---|---|
| **Skrutka SPAX 3,5×16** záp. hl. (bal 1000 ks) | 360281 | **6×** — najčastejšia položka sondy vôbec (montáž kovania) |
| Skrutka PZ ZH 3,5×30 biely Zn (bal 1000) | 228922 | 4× |
| Skrutka PZ ZH 3,5×35 biely Zn (bal 1000) | 228924 | 3× |
| Konfirmát 5/50 Zn biely (bal 2400) | 11090 | 2× |
| Podperka policová s návlekom 7/5 Zn biela | 306125 | 3× (1000–2000 ks) |
| Skrutky PZ 3,5×25 / 5×100/60 / 6×50 | 228921 / 11135 / 11305 | po 1× |
| Hmoždinky (univerzál TXPP 10×50, stena 10×60, pórobetón GBH 10×55) | 229050 / 92702 / 229047 | 1× |
| Uholník spojovací kov. s krytkou biely | 279271 | 1× |

### Šatník a ostatné

- STRONG držiak šatňovej tyče oválnej 15 mm chróm (314029, 50 ks) + StrongWire tyč oválna 15/30/3000 (15512, 3 ks) — 1×
- TULIP vešiak Kara L (35572) — 1×; rohové otočné LE MANS (+ samostatná tyč), TurnMotion II otočná antracit (KES, 315044) — po 1×
- TERNO Magic2/1800 posuvné kovanie pre drevené dvere s tlmením (368394, 2 sety) — 1×
- LED: StrongLumio profil Groove 10 4050 (269800 / čierny 353543) — 4×, krycia lišta C naklápacia mliečna 20 m (404412) / čierna (416710) — 4×
- STRONG el. zásuvka výsuvná 4×230 V + USB + HDMI (508881) — 1×
- MILADESIGN (kódy 219102, 219115, 219121, 471899) — stolové podnože, 1×

---

## 3. Identifikované SETY (vzory „objednáva sa vždy spolu")

### SET A — Záves na dvierka (potvrdený vzorec, ~90 % prípadov)
Na **1 záves**:
| # | Položka | Kód | Pomer |
|---|---|---|---|
| 1 | HETTICH Sensys 8645i 110° TH52 naložený SiSy (alebo vložený 104719 / 165° 264246) | 104717 | 1 |
| 2 | podložka HETTICH 8099 s excentrom D=1,5 | 106412 | 1 (miestami ×2) |
| 3 | krytky (miska + ramienko), set | bez kódu | 1 |

Na 1 dvierka idú typicky 2 závesy (t. j. dvierka = 2× SET A).

### SET B — Záves push-to-open (bez tlmenia)
Na **1 dvierka**: 2× Sensys 8675 P2O (245723) + 2× podložka 106412 + 2× krytky + **1× TipOn** BLUM 956A1004 (250831/250834) alebo Strong tip-on 35000 (+ doštička/protikus).

### SET C — Šuflík InnoTech Atira (hlavný systém)
1 zásuvka = **1 položka „K-…" sada** (obsahuje bočnice + Quadro výsuv SiSy) + podľa typu:
- čelný šuflík: nič navyše (čelo z DTD vlastné),
- vnútorný šuflík: + čelo vnútornej zásuvky (profil 2000, reže sa: 294940 biela / 294941 antracit) + príchyt čela pár (295276 biela / 295277 antracit),
- vyšší šuflík: sada „vr. relingu" (…/144, …/176) alebo + priečny reling 2000 (294812).
Matica variantov: biela/antracit × hĺbka 420/470 (300 zriedka) × výška 70 / 70+144 / 70+176.

### SET D — Drevený šuflík na skrytých výsuvoch Quadro V6
1 zásuvka = pár výsuvov Quadro V6 450 P2O (Ľ 315830 + P 315831) + pár spojok (L 104547 + P 104548); alternatívne 1 položka K-set 317642/317644 (sada aj s príchytmi).

### SET E — Legrabox (prémium, karbon čierna)
1 zásuvka = K-BLUM Legrabox M/K 450 mm 40 kg TOB CS-M (499013 / 499307 vnútorná); vnútorná vyššia + čelný plech (491360) + čelný reling (491359). Tip-on mechanika pre viac zásuviek: sada modulov T60 + synchro hriadeľ + adaptéry.

### SET F — Výklop Aventos
1 výklop = hlavný set (HF Top 507336 / HK Top 347827 / HL 23792+ramená 197611) + čelné príchyty + **krytky VŽDY zvlášť** (HL krytky 461804; „čierne krytky" pri HK) + pri HL stabilizačná tyč (13799).

### SET G — Skrinka (montážna réžia, z naskladnenia)
Spodná skrinka: 4× noha AXILO (150/100 mm) + úchytka + SPAX 3,5×16 na kovanie + konfirmáty/PZ skrutky na korpus + podperky políc 4/policu. Horná skrinka: 2× závesné kovanie Bystrica (+ krytka).

---

## 4. Dodávatelia kovania

| Dodávateľ | Rola | Poznámka |
|---|---|---|
| **VEPO s.r.o.** (objednavky@vepo-porez.sk, obchod.vepo-porez.sk) | **hlavný kanál ~90 %** objednávok kovania + porez/olep | medzičlánok na Demos; občas vlastný sklad („vepo — 100 ks" pri AXILO); posiela CP na potvrdenie, FA na rôzne subjekty |
| **Demos Trade** | reálny zdroj tovaru (kódy sortimentu) | priamy kontakt len marketingový; ceny vyjednané cez VEPO „pri veľkých odberoch" |
| **FP Interier / Karkama s.r.o.** (fpinterier.sk) | e-shop kovania — doplnkové nákupy | objednávky 9/2025 a 2/2026; Hettich Sensys 8657i |
| **KNN.sk** | e-shop — doplnkové nákupy (FA 2025, 2026) | Atira reling; marketingové maily |
| **Nábytkár s.r.o.** | CP na kovania podľa Demos kódov; profil UKW 5 | tabuľka kovaní posielaná v exceli (1/2025) |
| Quatro LM (Blum akcia), Karkama | marketing/výnimočne | |

---

## 5. Odporúčaný SEED zoznam pre katalóg kovania (V0.6)

Založený na naskladňovacom maile 12/2024 (vlastný výber firmy) + frekvenciách zo sondy. Kódy = Demos.

**Závesy + P2O (jadro):**
1. `104717` — HETTICH Sensys 8645i 110° TH52, naložený, SiSy — *záves KLASIK*
2. `104719` — HETTICH Sensys 8645i 110° TH52, vložený, SiSy
3. `245723` — HETTICH Sensys 8675 110° TH52 P2O (k tip-onu)
4. `264246` — HETTICH Sensys 8657i 165° TH52, naložený, SiSy
5. `106412` — HETTICH podložka 8099 s excentrom 1,5 mm — *automaticky 1:1 k závesu*
6. *(bez kódu)* — krytky závesu (miska + ramienko) — *automaticky 1:1 k závesu*
7. `104454` — záves chladničkový HETTICH + platničky
8. `250831` / `250834` — BLUM 956A1004 TipOn pre záves 76 mm s magnetom (biely/čierny) — *1 na dvierka s P2O*

**Šuflíky:**
9. `357696` — K-InnoTech Atira, čelný, biely, 470/70, 30 kg, SiSy
10. `357775` — K-InnoTech Atira, čelný, biely, 470/70/176 vr. relingu, 30 kg
11. `357970` / `358009` — antracit varianty (čelný 470/70/176, vnútorný 420/70)
12. `294940`+`295276` (biela) / `294941`+`295277` (antracit) — čelo vnútornej zásuvky 2000/70 + príchyt páru — *pre vnútorné šuflíky*
13. `317642` — K-Quadro V6 skrytý celovýsuv 450/30 kg sada pre 18 mm (alt. pár 315830/315831 + spojky 104547/104548)
14. `499013` — K-BLUM Legrabox M 450/40 kg TOB karbon čierna CS-M (prémium)
15. `402578` — K-StrongBox H140/350 reling hranatý, biela (ekonomická)

**Výklopy:**
16. `507336` — BLUM Aventos HF Top silný (krytky zvlášť!)
17. `347827` — BLUM Aventos HK Top silný Tip-on

**Nohy + montáž:**
18. `367823` — noha AXILO 150 mm + podložka (Häfele) · platničky AXILO
19. `93240` — závesné kovanie Bystrica (rektifikát) biele/čierne
20. `360281` — skrutka SPAX 3,5×16 (bal 1000) · `228922`/`228924` — PZ 3,5×30/35 · `11090` — konfirmát 5/50 · `306125` — podperka policová 7/5

*(Úchytky TULIP odporúčam ako samostatnú kategóriu s variabilnou roztečou — rady Ramara/Resina/Sophia/Marina + profil Lucata.)*

---

## 6. Čo sa nepodarilo zistiť / na doplnenie od Michala

1. **Kód krytiek k Sensys závesom** — v objednávkach vždy len voľný text „krytky (misky + ramienka) set"; presný Demos kód treba doplniť (miska = krytka misky 8645i, ramienko = krytka ramena).
2. **Prílohy** — sumáre kovania od VEPO a CP (PDF/XLS) sa nedali otvoriť; tam môžu byť ďalšie počty (napr. presný pomer podložiek 1× vs 2× na záves — ihrisko malo 1:2).
3. **AvanTech YOU** sa neobjavil — potvrdiť, že V0.6 katalóg má stáť na InnoTech Atira (nie AvanTech), alebo či sa plánuje prechod.
4. **Výšky Atira** — v objednávkach len 70 (+nadstavby 144/176); výšky bočníc 144/176 samostatne sa neobjednávali. Hĺbky reálne: 300/420/470 (Quadro/Legrabox 450, Tandem 500/550).
5. **Tip-on 35000 vs BLUM TipOn** — kedy sa používa ktorý (Strong 35000 vyzerá ako lacná alternatíva; 10 ks na 20 P2O závesov = 1 na dvierka).
6. Rozlíšenie „naložený vs vložený" pri seedovaní — vložený (104719) sa objednal len raz, ale v počte 50 ks; frekvencia v ks je porovnateľná s naloženým.
7. Miera nákupov mimo VEPO (FP Interier, KNN) — z mailov vidno len jednotky objednávok, sumy nie.
