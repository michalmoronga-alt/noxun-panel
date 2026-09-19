# SPOTREBIČE — overenie technických listov proti výrobcom (19.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: prvé porovnanie Fable 19.9.2026 (PDF výrobcov otvorené a prečítané, nie tvrdenie Gemini) ·
> overuje sa [SPOTREBICE_TECHLISTY_2026-09.md](SPOTREBICE_TECHLISTY_2026-09.md) §3 · **Michal prešiel celé 19.9. večer** (doplnenia z praxe = §9; kľúčové opravy prepísané do §3 a seedu pôvodného dokumentu) ·
> auditované proti kódu: nie. Kópie listov a výkresov: `_dev/techlisty/` (gitignorované, per PC).
>
> Pred implementáciou platí postup z [README.md](README.md).

## 0 · Ako čítať

- ✅ = číslo v §3 sedí s listom výrobcu · ✏️ = list hovorí inak (oprava do §3) · ➕ = list dáva údaj, ktorý §3 označilo GAP · ❓ = list to nekótuje jednoznačne, rozhodne Michal z praxe.
- Dve URL v rešerši boli **zle označené**: „W20027062" nie je umývačka, ale **inštalačný list varnej dosky WL B1160 BF**; „datart doc_4401491" nie je Beko chladnička, ale
  **denný návod umývačky Whirlpool (CS)**. Správne listy sú dohľadané nižšie.

## 1 · Rúra Whirlpool OMSR58RU1SB — inštalačný list W20036783_A + produktový list

| Pole | §3 | List výrobcu | Verdikt |
|---|---|---|---|
| Telo Š×V×H | 548 × 570 (vzadu 525) × 558 | 548 × 570 (vzadu 525) × 558; horná časť 428 hlboká; celková hĺbka 570 | ✅ |
| Čelo Š×V, hrúbka | 595 × 595, 20 | 595 × 595, 20; ovládací panel 97 | ✅ |
| Nika Š | 560–568 | 560–568 | ✅ |
| Nika V | 583–585 stĺp / 600–601 pod PD | 583–585 / 600–601 | ✅ |
| Nika H min | 560 | 560 | ✅ |
| Presah čela voči telu hore / dole | 0 / 9 | výkres kótuje **20 nad telom / 5 pod telom** (595 − 570 = 25) | ✏️ |
| Medzera pod čelom (odvetranie) | — | kóta 9 = **povinná medzera**: čelo pod rúrou začína min. 9 mm nižšie (horúci výduch) → min. rozstup čiel 605 (Michal, §9) | ➕ |
| Odvetranie | výrez zadnej hrany 35–40 | **35** vzadu (v stĺpe nad nikou aj pod PD) | ✏️ 35 |
| Iné | 90 °C, 2 skrutky + lišta | 90 °C, skrutky 2 + 2, lišta ×1, dvierka 89°, vyloženie 460 | ✅ |

## 2 · Mikrovlnky

### 2.1 Whirlpool MBNA900B — výkres (fast.eu) + inštalačný list 400011661025 + produktový list

| Pole | §3 | List | Verdikt |
|---|---|---|---|
| Telo Š×V×H | 540–544 × 348 × 298 | 540 (list) / 544 (výkres) × 348 × 298–299; celkovo 316–319 | ✅ |
| Čelo | 595 × 381–382, 21 | 595 × 381–382, 21; panel 80, dvierka 294 | ✅ |
| Nika | 556/560–568 × 360–363 × min 300 | list: min 556 × min 360 × 300; výkres: 560–568 × 360–363 × 300 | ✅ |
| Alternatíva | 380 s kitom AVM 105 | stĺp: **380 min × 560 min × 550 min** s AVM 105 (4801-310-00222) | ✅ |
| Presah čela hore / dole | 20 / 13–14 | 20 nad telom / 13 (list) – 14 (výkres) pod telom | ✅ |
| Iné | 4 skrutky do bokov | 4 skrutky, 90 °C korpus, dvierka 85°, 2 mm vôľa | ✅ |

### 2.2 Bosch BFL7221B1 — spec list Bosch SK (media3.bsh-group.com)

| Pole | §3 | List | Verdikt |
|---|---|---|---|
| Rozmer spotrebiča V×Š×H | ~360 × ~560 × ~298 (odvodené telo) | **382 × 594 × 318** celkovo; hĺbka tela 299 + čelo 19,5; šírku/výšku tela list nekótuje | ✏️ list dáva len celok |
| Čelo | 594 × 382, ~20 | 594 × 382, **19,5** | ✅ |
| Nika | 560–568 × 362–382 × min 300 | **560⁺⁸ × 362–365 × ≥ 300**; stĺp alternatíva **380⁺² × 560⁺⁸ × ≥ 550** (35 vzadu, zadná stena voľná) | ✅ (textová tabuľka listu píše 362–382 = obe niky spolu) |
| Presah hore / dole | 6 (362) alebo 3 (365) / 14 | 6 pri 362, 3 pri 365 / 14 | ✅ |
| Iné | — | bočná vôľa 16 od steny; šírka skrinky 600 | ➕ |

**Michalov zápis (debata §2) sedí:** nika 362–365 × 560–568, presah 6 / 14, čelo 594 × 382 × 20 (list 19,5), hĺbka tela 300 (list 299). Formát zápisu je potvrdený.

## 3 · Rúra Bosch HBG774KB1 — spec list Bosch SK

| Pole | §3 | List | Verdikt |
|---|---|---|---|
| Rozmer spotrebiča | ~548 × ~580 × ~527 (odvodené) | **595 × 594 × 548** (V×Š×H); telo výška 577, čelo 19,5, ovládač max 45 | ✏️ |
| Nika stĺp | 585–595 × 560–568 × 550 | **585⁺¹⁰ × 560⁺⁸ × min 550**, 35 vzadu | ✅ |
| Nika pod PD | — | **min 600⁺⁴ × 560⁺⁸ × min 550**; medzera 20 pod PD; miesto na prípojku 320 × 115 (nie zásuvková zóna) | ✏️ „zásuvková zóna 320 × 115" = miesto na prípojku |
| Odvetranie | sokel 200 cm² + medzidno 200 cm² (alebo 35–45) | dva spotrebiče nad sebou: otvor na prívod vzduchu **≥ 200 cm²** (A) v sokli; 35 vzadu | ✅ |
| Hrúbka PD nad rúrou | min 20 (28–30 pri indukcii) | tabuľka listu: **indukčný ≥ 37 nasadený / ≥ 38 v rovine**, celopovrchový indukčný ≥ 47/48, plynový ≥ 30/38, elektrický ≥ 27/30 | ✏️ dôležité pre PD |
| Presah čela / medzera pod čelom | ~5 / ~5–9 | 18 hore · 7,5 dole = odvetranie **už v rozmere čela** → čelo pod rúrou začína na 0; telo 577 = 595 − 18 (Michal, §9) | ➕ |

## 4 · Chladničky

### 4.1 Beko BCNA306E5ZSN — oficiálny inštalačný list (chassis K54306, kópia na ManualsLib; beko.com priamy download blokuje)

| Pole | §3 | List | Verdikt |
|---|---|---|---|
| Telo Š×V×H | 540 × 1935 × 545 | 540 × 1935 × 545 | ✅ |
| Nika | 560 (–570) × 1940 (–1950) × min 550–560 | **min 560 × 1940–1950 × min 555** | ✏️ hĺbka min 555 |
| Dvere spotrebiča | delenie GAP (pomer ~70/30) | zhora: **horné dvere 1159 · medzera 71 · dolné dvere 629 · spodok 40** (spolu 1899 + 32 horný držiak = 1935 ± zaokrúhlenie); nábytkové dvere: 2 mm škáry, posuvné lišty (X < 10 mm) | ➕ GAP vyplnený |
| Odvetranie | sokel 200 cm² + horný otvor 200 cm² + zadný kanál 50 | **min 200 cm² dole aj hore**; **zadná stena skrinky úplne otvorená** ku stene kuchyne (nie kanál 50) | ✏️ |
| Dno na 75–80 kg | — | list nekótuje (bolo z Gemini); Michal bez odpovede → poznámka v šablóne, nie pole | ✏️ |

### 4.2 Whirlpool ART 97101 2 — planeo.sk (výrobca list nedáva na stiahnutie)

Telo 540 × 1935 × 545; nika **560–570 × 1940–1950 × 560**; posuvné lišty. ✅ so §3 — ale list nedostupný ani Michalovi a predaj skončil → **vyradený zo seedu** (§9).

## 5 · Umývačky

### 5.1 Whirlpool WIO 3O540 PELG — inštalačný list W11401540_E (spoločný pre 60 aj 45 cm)

| Pole | §3 | List | Verdikt |
|---|---|---|---|
| Telo Š×V | 598 × 820–900 | 598 (60) / 448 (45) × 820–900 | ✅ |
| Nika | 600 × 820–900 × min 560 | **min 600 (450) × 820–900 × min 560** | ✅ |
| Nábytkové čelo Š | 592–596 (GAP) | **594** (60) / 444 (45) | ➕ |
| Nábytkové čelo V | ~650–720 (GAP) | **max 720** (min list nedáva) | ➕ |
| Hmotnosť čela | 3–10 kg | **2–10 kg** (60) / 2–7,5 kg (45) | ✏️ |
| Sokel | výrez pri sokli < 90–100 | list nekótuje; lišta k = 585 (60) / 435 (45); prax = vlastný sokel pod čelom 826 + blend 115 (§9) | ➕ |
| Iné | — | prípojky ~1300 el. / ~1500 voda a odpad; odpad 400–800 nad podlahou, Ø min 25 | ➕ |

### 5.2 Bosch SPV6EMX05E — spec list Bosch DE

Telo 448 × 815–875 × 550; nika **450 × 815–875 × min 550**; čelo **655–725**; sokel **min 90 / max 220**; nastavenie výšky max 60; hĺbka s otvorenými dverami 1150. ✅ so §3 (hmotnosť čela list neuvádza; Michal ju nikdy neráta → pole **vypadáva**).

## 6 · Varná doska Whirlpool WL B1160 BF — inštalačný list W20027062 + produktový list

| Pole | §3 | List | Verdikt |
|---|---|---|---|
| Sklo / vaňa | 590 × 510 × 4 / 551 × 50 × 479 | 590 × 510 × 4 / 551 × 479 × 50 | ✅ |
| Výrez do PD | 560 (+2) × 480–492, R ≤ 10 | **560⁺⁰⁄⁺² × min 480 – max 492, R max 10** | ✅ |
| Odstupy | zadná stena 35–45, vysoká skrinka 100, predná hrana 35 | min 35 od zadnej hrany, **min 100** od bočnej steny/vysokej skrinky, **min 400** nad doskou k hornej skrinke (digestor podľa jeho listu) | ✏️ 35 (nie 35–45) |
| Hrúbka PD | min 20 (28 nad rúrou) | **min 12** bežne, **min 28 nad rúrou**; produktový list „minimálna výška výklenku 28" | ✏️ |
| Spodná medzera | 10–20, deliaca doska nad zásuvkami | **min 10** nad deliacou doskou, deliaca doska povinná (min 20 od zadnej steny); pri rúre A-A: min 45 / 550 | ✅ |
| Digestor nad doskou | min 750 (podľa listu dosky) | list dosky odkazuje na návod digestora; Michal: **nerieši sa**, výšku digestora si rieši sám | ✏️ |

## 7 · Digestor Whirlpool WCT3 63F LTK — výkres ETD 859991672930

| Pole | §3 | List | Verdikt |
|---|---|---|---|
| Telo | 514 × 334 × 283 | 514 × 334 (min 307) × 283; telo 493 × 260; výstup 19 | ✅ |
| Výrez do dna skrinky | GAP | **437 × 216**, 44 od výrezu k hrane spotrebiča; svetlá 381 | ➕ GAP vyplnený |
| Výška nad doskou | 500–650 (max 750) | **min 500 elektrická / min 650 plyn** (všeobecný návod LIB uvádza 45 / 50 cm — ETD je produktovo presnejší) | ✏️ |
| Odvod | Ø 150 (redukcia 120) | **Ø 149**, stred 93 od zadnej steny | ✅ |

## 8 · Čo z toho plynie pre S1 (návrh, rozhodne Michal)

1. **Polia z §4 pôvodného dokumentu držia** — všetky kategórie majú telo / čelo / niku min–max / presahy; výrobcovia to členia rovnako (Bosch aj Whirlpool).
2. **Nové údaje do seedu:** výrez digestora 437 × 216 · delenie dverí chladničky 1159 / 71 / 629 / 40 · čelo umývačky 594 × max 720, 2–10 kg · PD nad rúrou Bosch ≥ 37/38 pri indukcii.
3. **Presahy čela rúry** výrobcovia kótujú voči telu, nie voči nike — do seedu **presah voči telu** + niku min–max + **medzera pod čelom** (Whirlpool 9, Bosch 0); presah voči nike si engine dopočíta (čelo − nika). Vyriešené 19.9. (§9).
4. Poznámky vetrania ostávajú textom v liste (rozhodnutie 6.9.), ale Beko „zadná stena úplne otvorená" je iný predpis ako „kanál 50" — do poznámky presne.

## 9 · Michalove doplnenia z praxe (19.9.2026 večer — prejdené celé)

Zdroj: interaktívna stránka porovnania (súkromný artefakt, Michalove poznámky v jej databáze) + screenshoty zo SketchUpu v `_dev/techlisty/*_Michal_*.png`.

- **Rúra Whirlpool:** kóta 9 = **povinná medzera pod čelom** (horúci výduch) — dvierka pod rúrou začínajú min. 9 mm nižšie; výška čela 595 + 9 = **min. rozstup medzi čelami 605**.
  Poloha čela voči telu (0 / 5 v detaile) ovplyvní len výšku police pod rúrou — Michal overí v praxi, z listu to jednoznačne nejde.
- **Rúra Bosch:** kóta 7,5 = odvetranie **už v rozmere čela** → čelo pod rúrou začína na 0; telo 577 = 595 − 18. Kombinácia s varnou doskou sa **nerieši** (nikdy tak nedáva);
  hrúbka PD nad rúrou nanajvýš poznámka bokom.
- **Mikro Whirlpool:** čelo 382, telo 544 × 348 × 299; kontrola 14 + 348 + 20 = 382. **Mikro Bosch:** sedí všetko.
- **Chladnička Beko — kontrolná geometria:** **box 1940 × 560 × 555 + čelná plocha viazaná zdola**: dolné nábytkové dvere **669** (= 629 + 40) · medzera **71** · horné **1200** (zvyšok do 1940).
  Cieľ: delenie sa má **matematicky odvodiť z listu**. Pravidlo: hrana nábytkových dverí min. **10 mm od dverí spotrebiča** (horná hrana dolných aj dolná hrana horných) → pri medzere 71
  vôľa posunu cca 50 mm. **Blend** hore/dole („ďalšie dno" napr. o 30 mm vyššie) pri lícovaní so susednými skrinkami — ideálne parameter šablóny, ak komplikuje → mimo V1.
  Nosnosť dna: bez odpovede → poznámka v šablóne.
- **Whirlpool ART 97101 2:** list nedostupný ani Michalovi, predaj skončil → **vyradený zo seedu (ostáva 9 modelov)**.
- **Umývačka Whirlpool:** „sedí, doladíme v priebehu". Prax (screeny): korpusy 815 + nohy 100 = 930, **čelo umývačky 826** (viac než list max 720), nad ním **blend 115**, pod ním vlastný sokel
  → výška čela ani sokel sa nekontrolujú (potvrdzuje rozhodnutie 6.9.). **Umývačka Bosch:** hmotnosť čela nikdy neráta → pole **vypadáva**.
- **Varná doska:** digestor nad doskou **neriešiť** (rieši si sám).
- **Digestor:** výrez do dna zvyčajne **20 mm od prednej hrany dna** (priestor na kryciu dosku) → odsadenie = parameter šablóny (default 20); výška nad doskou vypadáva.
- **Otázka 1 (presahy):** zapisovať voči telu + medzera pod čelom + nika min–max; presah voči nike engine dopočíta.

## 10 · Ďalší krok

Detailná debata polí S1 nad §8 + §9 (povinné / rozsah / voliteľné per kategória, kontrolná geometria chladničky, parametre šablón: blend, odsadenie výrezu) → Antigravity outside-in
(nový modul = povinný) → mockup → package + `codex-audit`.
