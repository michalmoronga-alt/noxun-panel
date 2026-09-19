# SPOTREBIČE — technické listy: zoznam objednávaných modelov a čo z listov potrebujeme (predúloha S1)

> Stav: KONCEPT — neimplementovať priamo · zdroj: predúloha z [V1_DEBATA_2026-09-06_SPOTREBICE.md](V1_DEBATA_2026-09-06_SPOTREBICE.md) §4 · dáta: firemný Disk (tabuľky
> „VYBAVENIE <zákazník>") + objednávky NAY v pošte (6.9.2026, čítané cez konektory) · technické listy: Antigravity outside-in (§3) · **overené 19.9.2026** proti PDF výrobcov + Michalova prax → [SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md](SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md) (dôkazový podklad, **nezáväzný** — čísla vstúpia do záväzného kontraktu až cez package S1 po `codex-audit`) · auditované proti kódu: nie.
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
| Chladnička vstavaná | Whirlpool ART 97101 2 | Hurbanová | Alza · **vyradený zo seedu 19.9.** (list nedostupný, predaj skončil) |
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

**Seed balík — jedna záväzná sada (9 modelov; Codex #322 P2, revízia 19.9.2026):** ★ objednané (6): Whirlpool OMSR58RU1SB · Whirlpool MBNA900B · **Beko** BCNA306E5ZSN · Whirlpool WIO 3O540 PELG ·
Whirlpool WL B1160 BF · Whirlpool WCT3 63F LTK — a **doplnkové neobjednané (3):** Bosch BFL7221B1 (Michalov vzorový zápis) · Bosch HBG774KB1 (prémiová rúra) · Bosch SPV6EMX05E (jediná 45 cm umývačka).
Whirlpool ART 97101 2 **vyradený 19.9.** (list sa nedá získať, predaj skončil — druhá chladnička pribudne, keď bude reálne objednaná). Voľne stojace chladničky/mrazničky a downdraft dosky do seedu nejdú.

## 3 · Technické listy — čo výrobcovia uvádzajú (Antigravity, 5 behov 6.9.2026; surové packety v [SPOTREBICE_TECHLISTY_2026-09_agy_packety.md](SPOTREBICE_TECHLISTY_2026-09_agy_packety.md))

**Stav overenia (19.9.2026): OVERENÉ.** Fable otvoril PDF výrobcov (nie tvrdenie Gemini) a Michal prešiel všetko z praxe — porovnanie riadok po riadku, výkresy a Michalove
doplnenia sú v [SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md](SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md) (**dôkazový podklad, nie kontrakt** — zdrojová vrstva `zdroje/` je nezáväzná,
hodnoty vstúpia do záväzného kontraktu až cez package S1 po `codex-audit`). Tabuľky nižšie majú opravené kľúčové hodnoty; telo Bosch BFL7221B1 je **odvodené, nie overené** (list ho nekótuje);
dve URL surovej rešerše boli zle označené (W20027062 = list varnej dosky, datart doc_4401491 = návod umývačky). RESEARCH GAP = výrobca údaj nedáva alebo bol len v PDF výkrese.

### 3.1 Rúra + mikrovlnka (do vysokej skrinky, často nad sebou)

| Pole | Whirlpool OMSR58RU1SB (rúra) | Whirlpool MBNA900B (mikro) | Bosch BFL7221B1 (mikro) | Bosch HBG774KB1 (rúra) |
|---|---|---|---|---|
| Telo Š×V×H | 548 × 570 (vzadu 525) × 558 | 544 × 348 × 299 | **list nekótuje** (len hĺbka 299; Michalov zápis 550 × 340 = odvodené, neoverené) | V tela 577 (= 595 − 18), H 548; Š tela list nekótuje |
| Čelo Š×V, hrúbka | 595 × 595, 20 | 595 × 381–382, 21 | 594 × 382, 19,5 | 594 × 595, 19,5 |
| Nika Š | 560–568 | 556/560–568 | 560–568 | 560–568 |
| Nika V | 583–585 (stĺp) / 600–601 (pod PD) | 360–363 (stĺp alt. 380 min s kitom AVM 105) | 362–365 (stĺp alt. 380⁺²) | 585⁺¹⁰ (stĺp) / 600⁺⁴ (pod PD) |
| Nika H min | 560 | 300 (alt. 550) | 300 | 550 |
| Presah čela voči telu hore / dole | 20 / 5 podľa výkresu (detail dvierok pripúšťa 25 / 0 — ovplyvní len policu pod rúrou, Michal overí v praxi) | 20 / 13–14 | 6 (nika 362) alebo 3 (365) / 14 | 18 / 0 (telo 577) |
| Medzera pod čelom (výduch) | **min 9** (kóta 9) → min. rozstup čiel 595 + 9 = 604 (Michal rezervuje 605) | — | — | **0** — odvetranie 7,5 je už v rozmere čela, nie presah |
| Odvetranie | výrez zadnej hrany police 35–40 mm po celej šírke; plocha v cm² GAP | vpredu cez čelo; zadná medzera 0 v závesnej skrinke | vetracie štrbiny v čele, chrbát za spotrebičom otvorený | sokel min 200 cm² + medzidno 200 cm² (alebo zadná medzera 35–45); pod PD medzera 5 |
| Iné | korpus odolný 90 °C; zásuvka nie za rúrou; 2 skrutky do bokov + lišta | 4 skrutky do bokov; nie za zatvárateľné dvierka | korpus 90 °C, susedné čelá 65 °C | pyrolýza → lepidlá; PD nad rúrou pri indukcii ≥ 37/38 (kombinácia s doskou sa nerieši — Michal 19.9.); miesto na prípojku 320 × 115 |

**Rúra + mikro nad sebou (Whirlpool):** spoločný predpis **neexistuje** (GAP). Z listov: **pevná polica medzi nimi je povinná** (každý spotrebič má vlastné nosné dno a skrutky do bokov);
zadná hrana medzipolice **nesmie** sedieť na chrbte — musí ostať vetrací komín 35–40 mm; pri 18 mm polici presah čela mikro dole 13–14 mm → medzi čelami vznikne škára ~4–5 mm.
Michalov ručný zápis pre BFL7221B1 (nika 362–365 × 560–568, presah hore 6 / dole 14, čelo 594 × 382 × 20) **sedí s listom Bosch** — dobrý znak pre jeho formát; telo 550 × 340 × 300 je
**odvodené** (list kótuje len hĺbku 299, šírku ani výšku tela nie) — v seede označiť ako odvodené, nie overené.

### 3.2 Vstavaná chladnička (Beko BCNA306E5ZSN · Whirlpool ART 97101 2)

Beko: telo **540 × 1935 × 545**, nika **min 560 × 1940–1950 × min 555**; dvere spotrebiča zhora **1159 · medzera 71 · 629 · spodok 40** (list Beko = **kontrolné pásma** zdola: 669 = spodok + dolné dvere · 71 = pásmo medzery · 1200 = zvyšok;
nábytkové delenie leží VNÚTRI pásma 71 s presahom min 10 mm cez hranu dverí spotrebiča na oboch stranách → vôľa cca 50 mm; OVERENIE §4.1 a §9), **posuvné lišty** (dvere na pántoch skrinky), odvetranie **min 200 cm² dole aj hore +
zadná stena skrinky úplne otvorená** (nie kanál 50); nosnosť dna list nekótuje. Whirlpool ART 97101 2: nika 560–570 × 1940–1950 × 560 len z obchodu (list nedostupný, vyradený zo seedu).
**Dopad na K1 (odsadenia):** Beko nežiada kanál, ale **zadnú stenu skrinky úplne otvorenú** (chrbát za chladničkou vynechať / otvoriť až po stenu kuchyne) — v chladničkovej šablóne je to konštrukčné rozhodnutie Michala (**nefixuje sa, vetranie sa vo V1 nerieši** — rozhodnutie 6.9.); list je len informácia.

### 3.3 Umývačka (Whirlpool WIO 3O540 PELG 60 · Bosch SPV6EMX05E 45)

| Pole | WIO 3O540 PELG | SPV6EMX05E |
|---|---|---|
| Telo Š×V×H | 598 × 820–900 × 555 | 448 × 815–875 × 550 |
| Nika | 600 × 820–900 × min 560 (odp. 570) | 450–458 × 815–875 × min 550 |
| Nábytkové čelo Š | 594 (list W11401540) | 442–448 |
| Nábytkové čelo V | max 720 (list; Michal v praxi 826 + blend 115 nad čelom) | 655–725 |
| Hmotnosť čela | 2–10 kg (list; Michal neráta — pole vypadáva) | list neuvádza |
| Sokel | výrez pri sokli < 90–100 | sokel 90–220; pod 90 alebo čelo > 725 = výrez / zapustenie |
| Iné | bez korpusu (stojí na podlahe medzi skrinkami), ochranný plech pod PD, prípojky vo vedľajšej skrinke | to isté; VarioHinge nemá |

### 3.4 Varná doska (Whirlpool WL B1160 BF) a digestor (Whirlpool WCT3 63F LTK)

- **Doska:** sklo 590 × 510 × 4, vaňa 551 × 50 × 479; **výrez do PD 560 (+2) × 480–492, R ≤ 10**, montážna hĺbka min 50; PD min 12 (28 nad rúrou); odstup od zadnej hrany min 35,
  od vysokej skrinky 100, od prednej hrany PD 35; spodná medzera min 10 nad deliacou doskou, **deliaca doska povinná nad zásuvkami**; digestor nad doskou sa nerieši (Michal 19.9.).
- **Digestor vstavaný:** telo 514 × 334 × 283, skrinka min 600, **výrez do dna 437 × 216** (ETD; v praxi odsadený 20 mm od prednej hrany dna kvôli krycej doske — Michal), výška nad doskou min 500 el. / 650 plyn (nerieši sa), Ø 149, zásuvka v skrinke.

## 4 · Čo z toho engine potrebuje (návrh Fable pre S1 — rozhodne detailná debata)

**Záver 1 — polia sú per kategória, nie univerzálne.** Spoločné: identita (názov/model/výrobca/kategória), **odkazy obchod[]**, **listy[]** (URL alebo súbor), poznámka.
Rozmerové polia podľa kategórie, každé **voliteľné** (neznáme = prázdne, nikdy default):

| Kategória | Rozmery pre engine (mm) | Kontrola vo V1 |
|---|---|---|
| Rúra · mikro | nika Š min–max · V min–max · H min · čelo Š × V × hrúbka · presah hore / dole **voči telu** · **medzera pod čelom (výduch: Whirlpool 9, Bosch 0)** · zadný výrez police (komín) · [pevná polica medzi rúrou a mikro = konštrukčné pravidlo šablóny] | **NIE** (rozhodnutie 6.9.); polia sa len evidujú |
| Chladnička | nika Š · V min–max · H min · **dvere spotrebiča: dolné + spodok, medzera** (z listu = kontrolné pásma; nábytkové delenie engine dopočíta vnútri pásma medzery s presahom min 10 mm cez hranu dverí spotrebiča na oboch stranách; blend = parameter šablóny alebo mimo V1) (zadný kanál a vetranie **len ako poznámka v liste, bez poľa** — rozhodnutie 6.9.) | **ÁNO**: pre každý rozmer niky **`min ≤ vnútro skrinky ≤ max`** (šírka, výška, hĺbka — kde list dáva aj maximum, napr. Beko výška 1940–1950, je príliš veľký otvor rovnako chyba); kde list max nedáva (Beko šírka len min 560, hĺbka len min 555), len jednostranne `≥ min`; kanál/vetranie sa nekontroluje |
| Umývačka | šírka (450/600) · výška min–max · čelo Š · V max · sokel min–max (evidencia) — hmotnosť čela **vypadáva** (Michal neráta) | **ÁNO**: len šírka slotu (450/600); výška čela vs. sokel sa **nekontroluje** (Michal predpísané rozmery obchádza — rozhodnutie 6.9.) |
| Varná doska | vonkajší Š × H · výrez Š × H (+tolerancia) · montážna hĺbka · PD min hrúbka | cena + výrez (poznámka pre PD); kontrola = V1+ |
| Digestor | šírka skrinky min · výrez do dna Š × H (+ odsadenie od prednej hrany ako parameter šablóny, default 20) · Ø odvodu — výška nad doskou **vypadáva** (Michal rieši sám) | len cena (mimo V1 konštrukčne) |

**Záver 2 — kde je to komplikované (zatiaľ neriešiť):** rúra + mikro nad sebou (presahy čiel, škára, medzipolica, komín) · presný algoritmus nábytkového delenia dverí chladničky (pásma + pravidlo 10 mm sú v §3.2, algoritmus rieši package) · plocha vetrania v cm²
(výrobcovia nekonzistentní: Whirlpool kótuje výrez, Bosch/Beko plochu) · umývačka bez korpusu = **slot medzi skrinkami**, nie skrinka
(potvrdzuje koncept 04 §A — vo V1 stačí „umývačka patrí k zákazke + čelo je bežný dielec", slot ako typ korpusu neskôr).

**Záver 3 — seed balík:** **9 modelov** zo seed balíka v §2 (6 objednaných ★ + 3 doplnkové) so zapísanými poľami z §3 — **overené 19.9.2026** (OVERENIE dokument) = prvý obsah knižnice spotrebičov; listy uložiť ako súbory (§3 debaty).

**Záver 4 — formát Michalovho zápisu (§2 debaty) je správny základ:** telo / čelo / nika min–max / presahy / odkazy / cena len v rozpočte. Výrobcovia to členia rovnako
(Bosch: Gerätemaße · Nischenmaße · Überstände · Lüftungsmaße).
