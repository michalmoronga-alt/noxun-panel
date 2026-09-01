# KOVANIE — technical audit checkpoint 2026-09-01 #10 — VENDOR RESEARCH MATRIX

> Working research checkpoint. NOT implementation spec.
> Zdroj: nezávislý research subagent (Round 2 Orchestrator), 1.9.2026 — oficiálne katalógy Hettich/Blum + Démos Trade.
> Tagy dôveryhodnosti: VERIFIED OFFICIAL · VERIFIED SECONDARY · USER-CONFIRMED NOXUN · INFERRED · UNCONFIRMED.
> POZOR: pri konflikte OFFICIAL vs USER-CONFIRMED sa produkčné rozhodnutie neprepisuje automaticky — rozdiel je vyznačený (viď „Korekcie voči checkpointu #08“).

**Primárne zdroje:**
- **[DEMOS]** Démos Trade katalóg, kapitola Výsuvy (všetkých 5 systémov): https://www.demos-trade.cz/content/uploadedFiles/salesSupportTranslation/32945.pdf → VERIFIED SECONDARY
- **[HETTICH-TuI]** Hettich technický katalóg, s. 512 (InnoTech Atira plánovanie/rezanie): https://catalog.hettich.com/General/TuI/en_DE/catalogs/TuI_en_DE/pdf/save/bk_518.pdf → VERIFIED OFFICIAL
- **[HETTICH-PLAN]** Hettich planning sheets `InnoTech_Atira_20190123_de_{1..48}.pdf`, `Quadro_20190122_de_10.pdf` (hettich.com/fileadmin/Media_Center/Planning/) → VERIFIED OFFICIAL
- **[HETTICH-MTA]** Hettich montážne návody: EB23 hta.hettich.com/.../930256200.pdf, EB20 .../930256000.pdf, 4D .../918608201_QV64D_Sisy.pdf → VERIFIED OFFICIAL
- **[BLUM-MA513]** Blum montáž MA-513 TANDEMBOX intivo/antaro (mirror lignoshop): https://www.lignoshop.de/out/media/montage_tbx_intivo_antaro.pdf → VERIFIED OFFICIAL
- **[BLUM-TD066]** Blum TANDEMBOX antaro objednávkový katalóg TD-066 (2013): buschhaus-shop.de/.../Blum_box_antaro_Bestellkatalog_04_2013-k.pdf → VERIFIED OFFICIAL (staršia edícia)
- **[BLUM-KA140]** Blum Katalog 2020/21 s. 413, TANDEM plus BLUMOTION 560H/566H: https://www.lignoshop.de/out/media/blum-tandem-vollauszug-blumotion.pdf → VERIFIED OFFICIAL
- **[BLUM-TIPON]** Blum planning TANDEM Vollauszug TIP-ON: https://d2.blum.com/services/BEC003/me74854939_ep_dok_bau_$sde_$aof_$v1.pdf → VERIFIED OFFICIAL

## 1. Hettich InnoTech Atira (kovové dvojstenné bočnice, Quadro výsuvy)

| Pole | Hodnota | Tag |
|---|---|---|
| Vendor vstupná šírka | **LB** = svetlá vnútorná šírka korpusu; KB = šírka korpusu; KD = hrúbka boku; EB = Einbaubreite | OFFICIAL [HETTICH-TuI] |
| KD↔EB mapovanie | **KD 16 → EB 12.5 · KD 18 → EB 10.5 · KD 19 → EB 9.5** (+ konštanta A = 23/21/20) | VERIFIED OFFICIAL [HETTICH-TuI s.512] |
| Šírka dna BB | **LB − 2×EB − 51.5** (drevený aj oceľový chrbát) | VERIFIED OFFICIAL |
| Dĺžka dna BL | **NL + 10** (drevený chrbát) · **NL − 3** (oceľový chrbát) | OFFICIAL (NL+10); NL−3 SECONDARY [DEMOS s.2.134] |
| Šírka dreveného chrbta RB | **LB − 2×EB − 63** | VERIFIED OFFICIAL |
| Výšky dreveného chrbta (DTD) | H54→**53** · H70→**65.5** · H144→**144** · H176→**176**; custom reling: rez chrbta **X = D − 48** | SECONDARY (53/65.5/144/176) [DEMOS]; X=D−48 OFFICIAL |
| Výškové varianty (systémové) | **54, 70, 144, 176 mm** (zarga len 54 a 70; 144/176 = zarga 70 + reling / TopSide / DesignSide; oceľové chrbty 57/70/144/176) | VERIFIED SECONDARY [DEMOS s.2.113] |
| Min. Platzbedarf, plnovýsuv Silent System | H54: **84** · H70: **105** · H144 (reling/TopSide): **189** (DesignSide 191) · H176: **221** (TopSide) / 223 (DesignSide) | VERIFIED OFFICIAL [HETTICH-PLAN] |
| — Push to open (P2O) | H54: 90 · H70: **106** · H144: **190** · H176: **222** | VERIFIED OFFICIAL |
| — Push to open Silent (P2Os) | H54: 89 · H70: **108** · H144: **192** · H176: **224** | VERIFIED OFFICIAL |
| — čiastočný výsuv (25 kg) | H54: 81 · H70: 97 · H144: 181 · H176: 213 | VERIFIED OFFICIAL |
| NL rad | **260 / 300 / 350 / 420 / 470 / 520 / 620** | VERIFIED OFFICIAL |
| Nosnostné triedy | Quadro **V6 = 30 kg**, **V6+ = 50 kg**, Quadro 25 = 25 kg, P2Os aj 10 kg (len NL 260–350). Per NL: **260 = len 30 · 300–520 = 30/50 · 620 = len 50**. **Atira 60 kg NEEXISTUJE** (60+ = ArciTech/Actro) | VERIFIED OFFICIAL + [DEMOS] |
| Min. hĺbka korpusu | **NL + 15** pre NL ≥ 300; **NL 260 → 279** (SiSy), ale **260 → 305 s P2O** | VERIFIED OFFICIAL |
| Hrúbka dna | **16 mm** DTD (rezné tabuľky aj detail kótované na 16); bez drážky — dno sadá na prírubu zargy; iné hrúbky UNCONFIRMED | OFFICIAL detail |
| Opening mode vs geometria | SiSy / P2O / P2Os = **len úroveň výsuvu — rezné rozmery boxu IDENTICKÉ**. Rozdiely: Platzbedarf +1–3 mm, NL/load pokrytie, P2O synchronizačná tyč pri šírke > 600 (rez: EB 9.5→LW−64, EB 10.5→LW−66, EB 12.5→LW−70), P2Os pridáva zadnú jednotku | VERIFIED SECONDARY [DEMOS s.2.115/2.129/2.180] |
| Vnútorná zásuvka | čelný alu profil H70 rez **LB−2×EB−57.5**; H144 predný reling **LB−2×EB−90.5**; deliaci **LB−2×EB−40.6**; Platzbedarf vnútornej H70 = 114–120 | SECONDARY/OFFICIAL |
| Vyrábané dielce | dno + drevený chrbát (DTD). Kupované: zargy, výsuvy, držiaky chrbta, predné upevnenia, reling/TopSide/DesignSide, oceľový chrbát (voliteľný) | SECONDARY |

## 2. Hettich Quadro V6 (drevená zásuvka, skrytý výsuv)

| Pole | Hodnota | Tag |
|---|---|---|
| Varianty meniace geometriu | **EB 20** (bočnice ≤ 16 mm): **SKW = LB − 40** · **EB 23** (bočnice ≤ 19 mm): **SKW = LB − 46** · **Quadro 4D V6** (predné spojky, 4D nastavenie): bočnice ≤15 mm → LB − 40; =16 mm → LB − 42 | VERIFIED OFFICIAL [HETTICH-MTA] |
| Dĺžka zásuvky | **Aufschiebemontáž (slide-on): dĺžka = NL**; **plug-on/spojkové verzie: NL − 10** (varovanie na EB20/EB23 plug-on listoch) | VERIFIED OFFICIAL |
| Min. hĺbka korpusu | **NL + 13** — rovnaké pre SiSy aj P2O | VERIFIED OFFICIAL |
| Odsadenie dna | **12–13 mm** (explicitne 4D list; EB20/23 výkresy 12) | VERIFIED OFFICIAL |
| NL rad | V6 SiSy (EB20): **280–600** (280/300/320/350/380/400/420/450/480/500/520/550/580/600); V6 EB23 od **250**; 4D: 250–600; V6 P2O (Démos sklad): 300–500; Quadro 25: 300–500 | OFFICIAL/SECONDARY |
| Nosnosti | **V6 = 30 kg** (EN 15338 L3), **V6+ = 50 kg**, Quadro 25 = 25 kg, 4D aj 10 kg (250–350) | VERIFIED OFFICIAL/SECONDARY |
| Opening modes | SiSy integrované; P2O bez tlmenia; P2Os kombinovateľné so 4D; **geometria boxu identická**; P2O sync tyč: EB20 → LW−88, 4D → LW−92, EB23 → LW−94 | VERIFIED SECONDARY [DEMOS s.2.174/180] |
| „V6 5D“ / „V6 YOU“ | **Nenájdené.** Aktuálna generácia = **„Quadro 4D V6“**; „YOU“ patrí k AvanTech YOU (iný systém). LB−42 sedí na Quadro 4D so 16 mm bočnicami | korekcia researchu |

## 3. Blum TANDEMBOX antaro (kovové bočnice)

| Pole | Hodnota | Tag |
|---|---|---|
| Vendor vstupná šírka | **LW** = Lichte Korpusweite (svetlá vnútorná šírka) | OFFICIAL |
| Šírka dna | **LW − 75** | VERIFIED OFFICIAL [BLUM-MA513, TD066] |
| Dĺžka dna | **NL − 24** (drevený chrbát) · **NL − 22** (oceľový) | VERIFIED OFFICIAL |
| Šírka dreveného chrbta | **LW − 87** | VERIFIED OFFICIAL |
| Výšky chrbta (16 mm DTD) | N **69** · M **84** · K **116** · C **167** · D **199** | OFFICIAL N/M/K/D; C=167 SECONDARY [DEMOS s.2.6] |
| Oceľový chrbát (kupovaný) | šírka **LW − 28** | VERIFIED OFFICIAL [TD066 s.93] |
| Výškové varianty | **N / M / K / C / D**; profily bočníc: N=68, M=83, K=115, **C a D = zarga 83 + reling** (C jeden, D dvojitý; galéria = kupovaná) | OFFICIAL + SECONDARY |
| Min. Platzbedarf | N **82.5** · M **98.5** · K **130.5** · D **224**; C: Démos 192 (oficiálna hodnota nezachytená — viď Konflikty) | OFFICIAL N/M/K/D; C SECONDARY |
| NL rad | **270–650** (270/300/350/400/450/500/550/600/650); N len 400–550 (Démos sklad) | VERIFIED SECONDARY (sedí s TD066 2013) |
| Nosnosti | **30 a 65 kg**; per NL: 270–400 = len 30, 450–600 = 30/65, 650 = len 65 | VERIFIED SECONDARY |
| Min. hĺbka korpusu | **NL + 3** | VERIFIED OFFICIAL |
| Hrúbka dna | **16 mm** DTD (všetky tabuľky „für 16 mm Spanplatten“) | VERIFIED OFFICIAL |
| BLUMOTION vs TIP-ON BLUMOTION | **žiadna zmena geometrie boxu**; TOB = iný výsuv + trigger modul T60 (výber podľa NL + hmotnostnej triedy) + sync tyč; vnútorné čelo rez **LW − 132**, priečny reling **LW − 122** | OFFICIAL + SECONDARY |
| Vyrábané dielce | dno + drevený chrbát (vnútorné čelá = kovové, kupované) | OFFICIAL |

## 4. StrongBox / StrongMax (privátna značka Démos Trade)

| Pole | StrongBox | StrongMax (16) | Tag |
|---|---|---|---|
| Konštrukcia | dvojstenná kovová bočnica | úzka 13 mm dvojstenná | SECONDARY |
| Výšky | **86 / 140 / 204** (204 s 1–2 relingami) | **89 / 121 / 185** | VERIFIED SECONDARY [DEMOS s.2.76–2.88] |
| Min. Platzbedarf | **105 / 165 / 225** | **111 / 143 / 207** (= H + 22) | VERIFIED SECONDARY |
| NL rad | **270–550** (270/300/350/400/450/500/550) | **300–550** | VERIFIED SECONDARY |
| Nosnosť | **35 kg** | **40 kg**, 50k cyklov | VERIFIED SECONDARY |
| Šírka dna | **LW − 75** | **LW − 21** | VERIFIED SECONDARY |
| Šírka chrbta | **LW − 89** | **LW − 42** | VERIFIED SECONDARY |
| Dĺžka dna | **NL − 7** | **NL − 20** | VERIFIED SECONDARY |
| Hĺbka vnútornej | NL − 26 | NL − 27 | VERIFIED SECONDARY |
| Min. vnútorná hĺbka korpusu | **NL + 10** | **NL + 8** | VERIFIED SECONDARY |
| Hrúbka dna/chrbta | v katalógu neuvedená (UNCONFIRMED, pravdepodobne 16) | **16 mm povinná** | SECONDARY [kovanilevne.cz] |
| Vstupná šírka | oba **LW = vnútorná šírka korpusu** (bez EB/KD kompenzácie) | | VERIFIED SECONDARY |
| Push-to-open | **v katalógu NEPONÚKANÉ** pre StrongBox/StrongMax (len integrované tlmenie); push len StrongRide 2D bočné (nie box systém) | | VERIFIED SECONDARY [DEMOS s.2.74] |
| Novšia generácia | **StrongMax 18** (18 mm dno/chrbát!): výšky **89/185/249**, NL do 650, 40 kg — vzorce UNCONFIRMED | | VERIFIED SECONDARY [vseprotruhlare.cz] |
| OEM výrobca | **UNCONFIRMED** — „Strong“ = privátna značka Démosu | | UNCONFIRMED |

## 5. Blum TANDEM (drevená zásuvka, skrytý výsuv)

| Pole | Hodnota | Tag |
|---|---|---|
| Vonkajšia šírka zásuvky | **SKW = LW − 42** (+0.0/−1.5) — rovnaké pre 560H BLUMOTION aj TIP-ON | VERIFIED OFFICIAL [BLUM-KA140 s.413, BLUM-TIPON s.15] |
| Dĺžka zásuvky | **SKL = NL − 10** | VERIFIED OFFICIAL |
| Vnútorná zásuvka | ISKL = SKL + X (X = hrúbka čela), výrez X + 19 | VERIFIED OFFICIAL |
| Hrúbka bočníc | **11–16 mm** (štandardný program) | VERIFIED OFFICIAL |
| Variant 17–19 mm | **EXISTUJE: „TANDEM 19 mm“** (17–19 mm bočnice, 30 a 50 kg, NL 250–750) — iný program; SKW vzorec UNCONFIRMED (follow-up) | VERIFIED OFFICIAL existencia [blum.com] |
| Odsadenie dna | **12–15 mm** (560H/566H BLUMOTION spojka) · **11–13 mm** (561H Aufsteck TIP-ON) — viď Konflikty | VERIFIED OFFICIAL |
| Min. hĺbka korpusu | **NL + 3** (+12 so stabilizátorom; +2 s POSISTOP) | VERIFIED OFFICIAL |
| Zvislý priestor | min 27.5 mm pod dnom, min 7 mm hore | VERIFIED OFFICIAL |
| NL rady | 550H čiastočný 30 kg: 270–550 (TIP-ON 270–650) · **560H plný 30 kg: 250–600** (250/270/300/320/350/380/400/420/450/480/500/520/550/600) · **566H plný 50 kg: 450–750** | OFFICIAL/SECONDARY |
| Nosnosti | **30 kg (550H/560H), 50 kg (566H)**; s TIP-ON klesá na ~20 kg; EU-metrická 60 kg trieda neexistuje (569H ~60 kg = US inch program) | OFFICIAL; ~20 kg SECONDARY; 569H INFERRED |
| BLUMOTION vs TIP-ON | **bez zmeny geometrie boxu**; TIP-ON pridáva sync tyč (rez **LW − 31** T57 vlnová; starší T55 **LW − 277**) + vŕtanie háku/triggera | VERIFIED OFFICIAL/SECONDARY |
| Opracovanie | zadné hákové výrezy (10 mm, ø6), vŕtanie spojky vpredu — šablóny T65.1000.02 | VERIFIED OFFICIAL |

---

## Verifikácia claimov z checkpointu #08 (korekcie!)

**Atira:**
- KD↔EB mapovanie — **POTVRDENÉ OFFICIAL**.
- BL = NL + 10 — **POTVRDENÉ** (len drevený chrbát; oceľový = NL − 3).
- BB = LB − 2·EB − 51.5 — **POTVRDENÉ**. RB = LB − 2·EB − 63 — **POTVRDENÉ**.
- H70 chrbát 65.5 ✓ · H144 = 144 ✓ · H176 = 176 ✓. **Chýbal variant H54** (chrbát 53; Démos skladuje len NL 470).
- **KOREKCIA min. výšok: H70 „~92“ z #08 NESEDÍ — oficiálne 105 (SiSy) / 106 (P2O) / 108 (P2Os); 97 čiastočný výsuv.** H144 „~192“ ✓ (189–192 podľa módu). H176 „~224“ ✓ (221–224 podľa módu). Pred implementáciou použiť OFICIÁLNE hodnoty per opening mode.
- NL rad — POTVRDENÝ; 620 = len 50 kg ✓; 470/520 = 30/50 ✓; **doplnok: 260 = len 30 kg**; P2Os 10 kg len 260–350.
- Min. hĺbka **NL + 15** (NL≥300); 260 → 279 SiSy / **305 P2O**. Žiadna Atira 60 kg — POTVRDENÉ.
- Opening mode nemení geometriu boxu — POTVRDENÉ.

**Quadro:**
- SKW = LB − 46 (V6 EB23) — **POTVRDENÉ OFFICIAL**. Min. hĺbka NL + 13 — **POTVRDENÉ**. Odsadenie dna 12–13 — **POTVRDENÉ**.
- Dĺžka zásuvky = NL — **POTVRDENÉ pre slide-on montáž**; spojkové varianty = NL − 10 (pri zavedení spojok treba vetvu mounting).
- „V6 5D / V6 YOU: LB − 42, NL − 10“ — **KOREKCIA**: generácia sa volá **Quadro 4D V6**; LB − 42 platí len pri 16 mm bočniciach (≤15 → LB − 40); NL − 10 = spojková montáž (pre 4D INFERRED). „V6 YOU“ ako produkt neexistuje.

## Family verdict (výpočtové rodiny)

**METAL_BOX_DRAWER (Atira, antaro, StrongBox, StrongMax) — ÁNO, jedna rodina s per-systémovými parametrami + JEDNA štrukturálna vetva:**

Spoločná štruktúra vzorcov (všetky štyri):
`bottom_width = W_vstup − c_bw` · `rear_width = W_vstup − c_rw` · `bottom_length = NL + c_bl` · `rear_height = konštanta(výškový variant)` · `min_depth = NL + c_d` · `min_height = konštanta(variant, opening_mode)`
Parametre: antaro (75 / 87 / −24|−22 / +3) · StrongBox (75 / 89 / −7 / +10) · StrongMax (21 / 42 / −20 / +8) · Atira (2EB+51.5 / 2EB+63 / +10|−3 / +15).
Opening mode **nikdy nemení geometriu boxu** — vyberá hardware SKU, min-height konštantu, NL/load dostupnosť a prípadnú sync tyč (extra rezná položka).

Skutočné štrukturálne rozdiely, ktoré recept-schéma musí uniesť od prvého dňa:
1. **EB indirekcia Atiry** (`W_eff = LB − 2×EB`, EB = f(KD); Blum/Strong: EB ≡ 0),
2. **diskriminátor typu chrbta** (drevený/oceľový mení dĺžku dna),
3. **matica dostupnosti (NL × výška × nosnosť × opening)**,
4. **opening-mode extra dielce** (sync tyč s vlastným vzorcom rezu).

**WOOD_DRAWER_UNDERMOUNT (Quadro V6, TANDEM) — ÁNO, rovnaká rodina, takmer identická štruktúra:**
`SKW = W_vstup − c_w` · `SKL = NL + c_l` · `odsadenie dna = c_r` · `min_depth = NL + c_d`.
Konštanty závisia od **runner sub-variantu a montážnej techniky** → kľúč receptu = (systém, runner_variant, mounting), nie len systém. Limity hrúbky bočníc (11–16 / ≤16 / ≤19 / 17–19) sú validačné parametre.

**Verdikt rozšíriteľnosti:** dátovo riadený recept (konštanty + matica dostupnosti + voliteľné extra dielce) robí pridanie ďalšieho systému skutočne lacným — LEGRABOX, ArciTech, AvanTech YOU, Metabox, GTV Modernbox publikujú dáta v rovnakom tvare.

## Konflikty nájdené researchom

1. **antaro D min. Platzbedarf: 224 (Blum TD-066 2013) vs 228 (Démos)** — Démos pravdepodobne pridáva vôľu/novšia edícia; 224 = oficiálne minimum, 228 = bezpečná hodnota.
2. **TANDEM odsadenie dna: 12–15 (560H/566H spojka) vs 11–13 (561H Aufsteck TIP-ON)** — iná montážna technika; držať per variant.
3. **TANDEM TIP-ON sync tyč: LW − 31 (T57 vlnová) vs LW − 277 (Démos, starší T55)** — dve generácie synchronizácie, obe reálne.
4. **Atira NL 260 min. hĺbka: 279 (SiSy) vs 305 (P2O)** — nie chyba, P2O mechanizmus pri najkratšej NL.
5. **Démos Atira tabuľky značia 18 aj 19 mm boky ako „EB 10,5“** — v rozpore s oficiálnym KD19→EB9.5; takmer isto typo/skladové zjednodušenie Démosu. Platí oficiálne mapovanie.
6. **StrongMax generácie:** „StrongMax (16)“ H89/121/185, NL 300–550 vs „StrongMax 18“ H89/185/249, NL do 650, 18 mm — pôvodný zoznam výšok v SEED miešal dve generácie.

## ADDENDUM — poznatky mimo matice (follow-up toho istého research agenta, s doplneným kontextom projektu)

### Pasce / gotchas

- **Atira EB nie je nastavenie — je to iný SKU výsuvu.** EB 12.5/10.5/9.5 sú fyzicky odlišné výsuvy (iné objednávacie čísla). Recipe schéma má držať EB pri **SKU výsuvu**, nie pri korpuse — inak nákup vygeneruje zlý diel. [vysoká istota]
- **Démos reálne skladuje len EB 10.5** — pri prechode na 16/19 mm korpus bude EB 12.5/9.5 pravdepodobne „na objednávku“ (lead time). [stredná — overiť pri prvej objednávke mimo 18 mm]
- **Atira NL 260 je špeciálny prípad trikrát:** len 30 kg · min. hĺbka 279 SiSy vs **305 s P2O (+45 mm!)** · P2Os 10 kg trieda len 260–350. **Resolver musí počítať min. hĺbku podľa opening módu**, nie z jednej konštanty. [vysoká istota]
- **Atira H54 existuje, ale prakticky nežije** (Démos skladuje jedinú NL 470) — neponúkať resolverom, pokiaľ nebude explicitne chcená. [vysoká]
- **Quadro: dĺžka zásuvky závisí od MONTÁŽNEJ TECHNIKY** — nasunutie (slide-on) = NL (+ hákový zárez), spojky = NL − 10. Démos predáva nové 4D sady **so spojkami** a čelné uchytenie sa objednáva zvlášť („nově neobsahuje čelní uchycení“). Recept V1 musí explicitne fixovať `mounting: slide_on`. [vysoká]
- **Quadro citlivosť na hrúbku bočnice 16 mm:** 4D list pri =16 mm obmedzuje stranové nastavenie a varuje pri vnútornej šírke; pri EB23 slide-on so 16 mm bočnicami pred výrobou overiť analogickú výhradu. [stredná]
- **Číselníky:** Hettich 7-miestne kódy konzistentné naprieč zdrojmi; Démos má vlastné 6-miestne a mapovanie Démos↔Hettich vedie len pri niektorých kapitolách (Quadro áno, Atira komplety nie) — Atira komplety pôjdu len cez Démos kódy. [vysoká]
- **„InnoTech“ (staré, oblé) vs „InnoTech Atira“** sa v katalógu miešajú na jednej strane (P2O adaptér typ B vs A) — pri strojovom spracovaní nikdy nematchovať substringom „InnoTech“. [vysoká]
- **Hodnota „~92 mm pre H70“ z Noxun podkladu vyzerá ako pamäť zo starého InnoTech alebo výška otvoru bez výsuvu** — oficiálna Atira = 105/106/108. Ak 92 žije v existujúcich dátach, je to latentná výrobná chyba. [vysoká]

### Príslušenstvo, ktoré neskôr uhryzne (spúšťače)

- **Sync P2O:** povinná pri šírke zásuvky > 600 mm (odporúčaná pri 2 zásuvkách za spoločným čelom). Ďalší krátený diel s vlastným vzorcom (LW−64/−66/−70 podľa EB; drevené LW−88/−92/−94) + adaptér **typ A vs B podľa výsuvu**. Trigger resolvera: `width > 600 && opening == P2O`. [vysoká]
- **TANDEM stabilizácia (ZST…):** trigger široká zásuvka (Démos: korpus 1400, kráti sa); Blum: **+12 mm k min. hĺbke** (POSISTOP +2). Min-hĺbka musí byť funkcia (NL, príslušenstvo). [vysoká]
- **StrongMax podpery dna (predné+zadné):** „odporúčané pre širšie zásuvky“ bez číselného prahu — treba interné pravidlo (napr. >600). Extra SKU. [vysoká, prah nedefinovaný]
- **Vnútorné zásuvky = všade iný svet:** Atira iný reling (stredový nepoužiteľný — explicitné varovanie), vlastné čelné profily, vyšší Platzbedarf (114–120); antaro čelný plech LW−132 + Querreling LW−122, vyššie min. výšky. V1: do dát flag `inner_supported: false`, nech to nikto nezapne bez receptu. [vysoká]
- **Atira TopSide/DesignSide menia Platzbedarf o 0–2 mm oproti relingu** (DesignSide vlastné adaptéry per NL) — resolver výšky musí poznať nadstavbu PRED výberom variantu (V1: Noxun profil = reling, fixné). [vysoká]
- **TIP-ON znižuje nosnosť TANDEM na ~20 kg**; antaro TOB modul sa vyberá podľa **celkovej hmotnosti zásuvky vrátane obsahu** (pásma do 10/10–20/15–40/35–65 kg) — os opening NIE JE úplne ortogonálna k nosnosti; matica dostupnosti musí niesť aj interakciu opening×load. [vysoká]
- Krytky s logom výrobcu vs Démos bezlogové „s možností potisku“ — marketingový detail. [nízka dôležitosť]

### Použiteľné nad rámec V1 (data packs budúcnosti)

- **Hettich planning sheets — predvídateľné URL:** `hettich.com/fileadmin/Media_Center/Planning/<Program>_<YYYYMMDD>_de_<N>.pdf` — 1 list = 1 kombinácia (výška × výsuv × opening), štruktúrovaný „Ausschreibungstext“ (NL + Platzbedarf + nosnosť); ľahko strojovo parsovateľné (overené: Atira 48 listov, Quadro). Skúsiť aj ArciTech, AvanTech YOU, Sensys, výklopy. [vysoká pre vzor]
- **Hettich TuI katalóg po stranách bez auth:** `catalog.hettich.com/General/TuI/en_DE/catalogs/TuI_en_DE/pdf/save/bk_<N>.pdf` (bk_518 = strana 512, offset +6). [vysoká]
- **HTA montážne PDF často pomenované číslom artikla:** `hta.hettich.com/fileadmin/Hettich_Technical_Assistant/PDFs/<artnr>.pdf` — z artikla sa dá uhádnuť URL montážky. [vysoká]
- **Blum:** `d2.blum.com/services/BEC003/...` funguje bez loginu, ale názvy hashovité (loviť searchom); KA katalógy v mirroroch predajcov; na produkčné overenie oficiálne e-services po registrácii (blum.cz). [vysoká]
- **Démos PDF kapitola Výsuvy obsahuje recipe-shaped dáta aj pre ArciTech** (bočnice 78/94/126, 7 výšok chrbtov, NL 270–650, 10/40/60/80 kg, Actro) **a LEGRABOX** + KingSlide, GTV, FGV. [vysoká]
- **ArciTech: mechanický Push to open NEEXISTUJE** — len P2O Silent / Easys (elektrika) — availability osi opening platí aj na úrovni celého programu. [vysoká]
- **Quadro 25 ↔ V6 zámennosť:** Hettich garantuje výmenu čiastočného za plnovýsuv bez zmeny rozmerov korpusu, zásuvky aj vŕtania — lacný upgrade path, argument pre fixnú geometriu receptu. [vysoká, oficiálny text]

### Spoľahlivosť zdrojov — pred produkciou over

- **Démos PDF 32945 bez viditeľného roku (~2021)** — geometria sedí s oficiálnymi zdrojmi, ale SKU/skladovosť možno zastaralé → pred nákupným modulom overiť Démos24Plus. [vysoká v geometriu, nízka v SKU]
- **Blum TD-066 z 2013** — geometria antaro nezmenená (MA-513 zhodné), NL sortiment a farby áno; min. výška C nepotvrdená oficiálne (jediná diera antaro). [stredná]
- **Strong = 100 % závislé od Démosu** (privátna značka, OEM neznámy) — jediná autorita bude aktuálny Démos montážny návod. [stredná]
- **PDF text-extrakcia rozhadzuje párovanie hodnôt** (LW−87 vs −75 pri antaro rozhodnuté z vizuálu výkresu) — pri automatickom ingeste katalógov do recipe dát prikladať render výkresu ako evidence, inak hrozí tichá zámena dno↔záda. [vysoká — zažité v tomto rešerši]
- **Najsilnejšie overené (bezpečné pre V1):** Atira vzorce + EB mapa + Platzbedarf séria (2× oficiálne) · Quadro V6 EB23 SKW/hĺbka/offset (oficiálne MTA) · antaro dno/záda (oficiálny výkres MA-513). **Najslabšie:** Strong čokoľvek · TANDEM 19 mm · antaro C výška.

## PDF FOLLOW-UP LIST (manuálne dohľadať v oficiálnych PDF)

1. **TANDEM 19 mm** (17–19 mm bočnice, 30/50 kg, NL 250–750): presný SKW a SKL vzorec + odsadenie dna (Blum KA kapitola „TANDEM 19“).
2. **TANDEMBOX antaro výška C**: oficiálny min. Platzbedarf (očak. ~191–192) a potvrdenie chrbta 167 v aktuálnej edícii TD-066/KA.
3. **antaro**: publikuje Blum rezné tabuľky pre iné hrúbky dna než 16 mm a mení sa vzorec šírky chrbta?
4. **antaro TIP-ON BLUMOTION**: mení modul T60 min. hĺbku korpusu oproti NL + 3?
5. **Atira**: oficiálne podporované hrúbky dna/chrbta iné než 16 mm (TuI processing notes).
6. **Quadro 4D V6**: explicitne vytlačená dĺžka zásuvky (potvrdiť NL − 10 so 4D spojkami) — zatiaľ INFERRED.
7. **StrongBox**: povinná hrúbka dna/chrbta (16?) — montážny návod na Démos24Plus.
8. **StrongMax 18**: vzorce šírky/dĺžky dna a chrbta pre 18 mm materiál — montážny návod Démos24Plus.
