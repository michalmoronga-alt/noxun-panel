# SPOTREBIČE — technické listy: zoznam objednávaných modelov a čo z listov potrebujeme (predúloha S1)

> Stav: KONCEPT — neimplementovať priamo · zdroj: predúloha z [V1_DEBATA_2026-09-06_SPOTREBICE.md](V1_DEBATA_2026-09-06_SPOTREBICE.md) §4 · dáta: firemný Disk (tabuľky
> „VYBAVENIE <zákazník>") + objednávky NAY v pošte (6.9.2026, čítané cez konektory) · technické listy: Antigravity outside-in (§3, dopĺňa sa) · auditované proti kódu: nie.
>
> Pred implementáciou platí postup z [README.md](README.md).

## 1 · Odkiaľ zoznam vznikol

- **Disk:** tabuľky „VYBAVENIE" per zákazka — Medzihradský (3 verzie 2025–2026), Bella (2025), Trochtová (2025), Hurbanová (2025), Szebellai (bez kuchynských spotrebičov).
  Štruktúra: kategória · názov modelu · odkaz na obchod (NAY / Alza / drezyonline) · cena · poznámky · často **varianty „ALEBO"** (2–3 alternatívy pre zákazníka).
- **Pošta (noxuninfo):** objednávky NAY č. 8842501257 (10.10.2025, 6 spotrebičov) a 7323216251 (13.10.2025, 3 spotrebiče) = reálne kúpené kusy (zákazka Bella);
  staršie faktúry NAY 2023–2024 (PDF prílohy, nečítané).
- Michalov vlastný zápis mikrovlnky Bosch BFL7221B1 (V1 debata 6.9.) = vzor, čo od listu čakáme.

## 2 · Modely podľa kategórie (★ = objednané / opakuje sa, ostatné = ponúkané ako varianta)

| Kategória | Model | Kde | Poznámka |
|---|---|---|---|
| **Rúra** | ★ Whirlpool OMSR58RU1SB (STEAM+) | Bella (objednaná), | 299 € |
| Rúra | Whirlpool WOI9A8PT2SBA (W Collection) | Trochtová | set s mikro na Alze |
| Rúra | Bosch Serie 8 HBG774KB1 (pyrolýza) | Medzihradský | alternatíva Electrolux EOE8P39H |
| Rúra | Bosch HBF153EB0 (Séria 2) | Hurbanová | Alza |
| **Mikrovlnka** | ★ Whirlpool MBNA900B (New Actual) | Bella (objednaná) | 239 € |
| Mikrovlnka | Whirlpool WMD7O4TB | Trochtová | set s rúrou |
| Mikrovlnka | Bosch Serie 8 BFL7221B1 | Medzihradský | Michalov vzorový zápis rozmerov; alternatíva Electrolux LMS4253TBK |
| Mikrovlnka | Bosch BFL623MB3 (Séria 2) | Hurbanová | Alza |
| **Chladnička vstavaná** | ★ Beko Beyond BCNA306E5ZSN | Bella (objednaná) | 639 € |
| Chladnička vstavaná | Whirlpool ART 97101 2 | Hurbanová | Alza |
| Chladnička voľne stojaca | Whirlpool WHSD18A011B2 / Beko B3BLNC305SW (+ mrazničky) | Medzihradský | **mimo S1** (voľne stojace) |
| **Umývačka 60** | ★★ Whirlpool WIO 3O540 PELG (Supreme Clean) | Bella (objednaná), Trochtová | **opakuje sa** |
| Umývačka 60 | Bosch SMD8TCX04E / Gorenje ULTRA16BWIFI / Electrolux EEG68600W | Medzihradský | varianty |
| Umývačka 45 | Bosch SPV6EMX05E | Hurbanová | Alza |
| **Varná doska** | ★ Whirlpool WL B1160 BF (i100, 60) | Bella (objednaná) | 289 € |
| Varná doska | Electrolux EIV63443CT (60) / EIV84550 (78) | Trochtová | |
| Varná doska | Bosch PUG611AA5E | Hurbanová | |
| Varná doska s odsávaním | Bosch PVQ731H26E / Elica NIKOLATESLA FIT BL/A/72 | Medzihradský | **mimo S1** (downdraft) |
| **Digestor** | ★ Whirlpool WCT3 63F LTK | Bella (objednaný) | 255 € |
| Digestor | Elica FOLD BL MAT/A/52 | Hurbanová | |
| Drez / batéria / dávkovač | Blanco, Alveus, Franke, Schock (drezyonline) | Bella, Trochtová, Hurbanová | len cenová položka + výrez PD |

**Záver pre seed:** prioritné modely na technické listy = **Whirlpool rad (OMSR58RU1SB · MBNA900B · WIO 3O540 PELG · WL B1160 BF · BCNA306E5ZSN)** ako reálne kúpená sada,
**Bosch BFL7221B1 + HBG774KB1** (Michalov vzor + prémiová alternatíva), **Whirlpool ART 97101 2** (druhá vstavaná chladnička), **Bosch SPV6EMX05E** (jediná 45 cm umývačka).

## 3 · Technické listy — čo výrobcovia uvádzajú (Antigravity, 5 behov 6.9.2026; surové packety v [SPOTREBICE_TECHLISTY_2026-09_agy_packety.md](SPOTREBICE_TECHLISTY_2026-09_agy_packety.md))

**Stav overenia:** „VERIFIED" je tvrdenie Gemini Flash (stránku/PDF vraj otvoril). Orchestrátor PDF neotváral. **Pred zápisom do seedu overí Michal** aspoň jeden list per
kategória (má ich v tabuľkách VYBAVENIE); čísla nižšie sú podklad na návrh POLÍ, nie ešte výrobná pravda. RESEARCH GAP = výrobca údaj nedáva alebo bol len v PDF výkrese.

### 3.1 Rúra + mikrovlnka (do vysokej skrinky, často nad sebou)

| Pole | Whirlpool OMSR58RU1SB (rúra) | Whirlpool MBNA900B (mikro) | Bosch BFL7221B1 (mikro) | Bosch HBG774KB1 (rúra) |
|---|---|---|---|---|
| Telo Š×V×H | 548 × 570 (vzadu 525) × 558 | 540–544 × 348 × 298 | ~560 × ~360 × ~298 (odvodené) | ~548 × ~580 × ~527 (odvodené) |
| Čelo Š×V, hrúbka | 595 × 595, 20 | 595 × 381–382, 21 | 594 × 382, ~20 | 594 × 595, 21 |
| Nika Š | 560–568 | 556/560–568 | 560–568 | 560–568 |
| Nika V | 583–585 (stĺp) / 600–601 (pod PD) | 360–363 (alt. 380 s kitom AVM 105) | 362–382 | 585–595 |
| Nika H min | 560 | 300 (alt. 550) | 300 | 550 |
| Presah čela hore / dole | 0 / 9 | 20 (nad telom) / 13–14 | 6 (nika 362) alebo 3 (365) / 14 | ~5 / ~5–9 (závisí od V niky) |
| Odvetranie | výrez zadnej hrany police 35–40 mm po celej šírke; plocha v cm² GAP | vpredu cez čelo; zadná medzera 0 v závesnej skrinke | vetracie štrbiny v čele, chrbát za spotrebičom otvorený | sokel min 200 cm² + medzidno 200 cm² (alebo zadná medzera 35–45); pod PD medzera 5 |
| Iné | korpus odolný 90 °C; zásuvka nie za rúrou; 2 skrutky do bokov + lišta | 4 skrutky do bokov; nie za zatvárateľné dvierka | korpus 90 °C, susedné čelá 65 °C | pyrolýza → lepidlá; PD min 20 (28–30 pri indukcii nad rúrou); zásuvková zóna 320 × 115 mimo chrbta |

**Rúra + mikro nad sebou (Whirlpool):** spoločný predpis **neexistuje** (GAP). Z listov: **pevná polica medzi nimi je povinná** (každý spotrebič má vlastné nosné dno a skrutky do bokov);
zadná hrana medzipolice **nesmie** sedieť na chrbte — musí ostať vetrací komín 35–40 mm; pri 18 mm polici presah čela mikro dole 13–14 mm → medzi čelami vznikne škára ~4–5 mm.
Michalov ručný zápis pre BFL7221B1 (nika 362–365 × 560–568, presah hore 6 / dole 14, čelo 594 × 382 × 20, telo 550 × 340 × 300) **sedí s listom Bosch** — dobrý znak pre jeho formát.

### 3.2 Vstavaná chladnička (Beko BCNA306E5ZSN · Whirlpool ART 97101 2)

Obe: telo **540 × 1935 × 545**, nika **560 (–570) × 1940 (–1950) × min 550–560**, 2 nábytkové dvere (delenie podľa styku dverí spotrebiča, pomer ~70/30; presné mm výrobca
**nedáva** — GAP), **posuvné lišty** (dvere na pántoch skrinky), odvetranie **sokel min 200 cm² + horný otvor min 200 cm² + zadný kanál min 50 mm**, dno na >75–80 kg, zásuvka nie za chrbtom.
**Dopad na K1 (odsadenia):** zadný kanál 50 mm = presne prípad „komín" — chladničková šablóna ponesie odsadenie ≥ 50 a vetrací otvor v sokli/strope ako poznámku.

### 3.3 Umývačka (Whirlpool WIO 3O540 PELG 60 · Bosch SPV6EMX05E 45)

| Pole | WIO 3O540 PELG | SPV6EMX05E |
|---|---|---|
| Telo Š×V×H | 598 × 820–900 × 555 | 448 × 815–875 × 550 |
| Nika | 600 × 820–900 × min 560 (odp. 570) | 450–458 × 815–875 × min 550 |
| Nábytkové čelo Š | 592–596 (GAP v texte, šablóna 1:1) | 442–448 |
| Nábytkové čelo V | ~650–720 (GAP) | 655–725 |
| Hmotnosť čela | 3–10 kg (GAP) | 2,5–7,5 kg |
| Sokel | výrez pri sokli < 90–100 | sokel 90–220; pod 90 alebo čelo > 725 = výrez / zapustenie |
| Iné | bez korpusu (stojí na podlahe medzi skrinkami), ochranný plech pod PD, prípojky vo vedľajšej skrinke | to isté; VarioHinge nemá |

### 3.4 Varná doska (Whirlpool WL B1160 BF) a digestor (Whirlpool WCT3 63F LTK)

- **Doska:** sklo 590 × 510 × 4, vaňa 551 × 50 × 479; **výrez do PD 560 (+2) × 480–492, R ≤ 10**, montážna hĺbka min 50; PD min 20 (28 nad rúrou); odstup od zadnej steny 35–45,
  od vysokej skrinky 100, od prednej hrany PD 35; spodná medzera 10–20 nad prepážkou, **deliaca doska povinná nad zásuvkami**; digestor min 750 nad doskou (podľa listu dosky).
- **Digestor vstavaný:** telo 514 × 334 × 283, skrinka min 600, **výrez do dna GAP** (len vo výkrese ETD), výška nad indukciou 500–650 (max 750), Ø 150 (redukcia 120), zásuvka v skrinke.

## 4 · Čo z toho engine potrebuje (návrh Fable pre S1 — rozhodne detailná debata)

**Záver 1 — polia sú per kategória, nie univerzálne.** Spoločné: identita (názov/model/výrobca/kategória), **odkazy obchod[]**, **listy[]** (URL alebo súbor), poznámka.
Rozmerové polia podľa kategórie, každé **voliteľné** (neznáme = prázdne, nikdy default):

| Kategória | Rozmery pre engine (mm) | Kontrola vo V1 |
|---|---|---|
| Rúra · mikro | nika Š min–max · V min–max · H min · čelo Š × V · presah hore / dole · zadný výrez police (komín) · [pevná polica medzi rúrou a mikro = konštrukčné pravidlo šablóny] | **NIE** (rozhodnutie 6.9.); polia sa len evidujú |
| Chladnička | nika Š · V min–max · H min · zadný kanál (→ odsadenie K1) · vetranie sokel/hore cm² (poznámka) · počet dverí + pomer delenia | **ÁNO**: vnútro skrinky ≥ nika, odsadenie ≥ kanál |
| Umývačka | šírka (450/600) · výška min–max · čelo Š min–max · V min–max · hmotnosť čela max · sokel min | **ÁNO**: šírka slotu, výška čela vs. sokel |
| Varná doska | vonkajší Š × H · výrez Š × H (+tolerancia) · montážna hĺbka · PD min hrúbka | cena + výrez (poznámka pre PD); kontrola = V1+ |
| Digestor | šírka skrinky min · výška nad doskou min–max · Ø odvodu | len cena (mimo V1 konštrukčne) |

**Záver 2 — kde je to komplikované (zatiaľ neriešiť):** rúra + mikro nad sebou (presahy čiel, škára, medzipolica, komín) · delenie dverí chladničky v mm · plocha vetrania v cm²
(výrobcovia nekonzistentní: Whirlpool kótuje výrez, Bosch/Beko plochu) · výrezy digestora (len vo výkresoch) · umývačka bez korpusu = **slot medzi skrinkami**, nie skrinka
(potvrdzuje koncept 04 §A — vo V1 stačí „umývačka patrí k zákazke + čelo je bežný dielec", slot ako typ korpusu neskôr).

**Záver 3 — seed balík:** 9 modelov z §2 (★) so zapísanými poľami z §3 **po Michalovom overení** = prvý obsah knižnice spotrebičov; listy uložiť ako súbory (§3 debaty).

**Záver 4 — formát Michalovho zápisu (§2 debaty) je správny základ:** telo / čelo / nika min–max / presahy / odkazy / cena len v rozpočte. Výrobcovia to členia rovnako
(Bosch: Gerätemaße · Nischenmaße · Überstände · Lüftungsmaße).
