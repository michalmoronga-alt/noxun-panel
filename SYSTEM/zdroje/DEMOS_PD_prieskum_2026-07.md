# Demos PD prieskum — pracovné dosky a zásteny (29.7.2026)

> Dátový podklad pre PD/zástena model (dávka 2A, V0.6). Zisťované subagentom živým prehliadaním demos-trade.sk (kategória „Pracovné dosky a zásteny", 533 položiek — počty z server-side facetov). Sesterský podklad: [DEMOS_ABS_prieskum_2026-07.md](DEMOS_ABS_prieskum_2026-07.md).

## PD per náš dekor

| Dekor | Má PD? | Formáty (D/Š/H) | Kódy | Cena s DPH | Dostupnosť |
|---|---|---|---|---|---|
| Egger F800 ST9 Mramor krištáľový | ÁNO | 4100/600/38 · 4100/920/38 | 514485 · 514486 | 143,33 · 252,39 € | Skladom |
| Kronospan K2738 Torro Cremona Oak | ÁNO — PD má štruktúru **FP** (DTDL/ABS = PW!) | 4100/635/38 · 4100/900/38 | 545293 · 532772 | 129,03 · 269,59 € | Skladom |
| Egger H3303 ST10 Dub Hamilton | ÁNO | 4100/600/38 · 4100/920/38 | 180799 · 181652 | 130,76 · 230,26 € | Skladom |
| Egger H1180 ST37 Dub Halifax | ÁNO (ABS hrana 1,5) | 4100/650/38 · 4100/920/38 · 4100/1200/38 | 277977 (920) | 538,34 € (920) | Skladom |
| Kronospan K350 RT Flow betónový | ÁNO | 4100/635/38 · 4100/900/38 · 4100/1200/38 | 495407 · 495426 · 528552 | 178,58 · 321,76 · 575,28 € | Skladom/obj. |
| Egger U750 ST9 Taupe šedá | **NIE** (32/32 overené) | — | — | — | — |
| Kronospan K097 SU Dusk Blue | **NIE** (14/14) | — | — | — | — |
| Kronospan 164 PE Antracit | **NIE** (17/17) | — | — | — | — |
| Kronospan 5981 Cashmere (MG/BS/UM) | **NIE** (28/28) | — | — | — | — |
| Kronospan 191 Cool grey | **NIE** (24/24) | — | — | — | — |

**Vzor:** PD existuje len pre podmnožinu „veľkých" dekorov (drevo, kameň/mramor, betón). **Uni a lesklé (MG) dekory PD spravidla NEMAJÚ** (Uni = len 41 z 511 položiek kategórie).

## Reálne šírky/hrúbky/dĺžky sortimentu (facety, 533 položiek)

- **Šírky (D×Š, počet):** 4100×600 — 117 · 4100×640 — 97 (*takmer výhradne zásteny*) · 4100×920 — 89 · 4100×900 — 73 · 4100×635 — 59 · 4100×1200 — 53 · 4100×650 — 17 · 4200×640/900 — 12+12 · 3020×1200 — 4.
- **Hrúbky:** 38 — 372 (dominuje) · 9,2 — 63 (zásteny Egger) · **20 — 41 (nová Egger tenká línia, od 3.7.2026)** · 10 — 36 (zásteny Kronospan) · 38,8 — 11 (Getacore solid surface 38,3) · 16 — 8 · 9,6 — 2. Mimo kategórie: kompaktné 12 mm (KD-IN).
- **Dĺžky:** 4100 ~95 %+, 4200 okrajovo, 3020 výnimočne.
- **Značky:** Egger 257 · Kronospan 238 · Arpa 18 (HPL/kompakt) · Pfleiderer 18 · Fenix 6 · SM'art 4 · Getacore mimo facetu.

## Typy PD (hranová úprava = podtyp!)

1. **Postforming** (282) — laminát cez zaoblenú hranu, 38 mm; predná hrana sa NEolepuje.
2. **ABS rovná hrana** (150) — samostatná **1,5 mm ABS páska** na rovnej hrane; 38 mm + nová **20 mm** línia (PerfectSense Ambiance ~318–347 €; rovná hrana F661/F662/F836 ~220 €).
3. **Kompaktné 12 mm** (KD-IN) — farebné/čierne jadro, monolitická hrana bez olepovania (~528–793 €).

## Zásteny (potvrdenie Michalovho doplnku)

- Konzistentný vzor: **4100×640**, hrúbka **9,2 (Egger) / 10 (Kronospan)**, cena ~122–220 € s DPH, 102 položiek.
- **VŽDY dva dekory v názve = líce/rub** (napr. „Zástena H1180 ST37/W908 ST37 4100/640/9,2" · „Zástena K350 RT/K351 RT 4100/640/10") — obojstranný dekor je štandard sortimentu, presne ako hlásil Michal.

## Dizajnové dopady (dávka 2A / V0.6)

- Šírka/formát PD = atribút variantu (potvrdené — šírok je 6+ a pribúdajú); hrúbka nie je len 38 (20/12 nové línie).
- Typ PD potrebuje **podtyp hranovej úpravy** (postforming / ABS rovná hrana / kompakt) — riadi ABS logiku prednej hrany.
- Kronospan štruktúrny kód sa medzi DTDL a PD LÍŠI (PW vs FP) — potvrdené s kódmi; kľúč skupiny bez štruktúry (rozhodnuté 29.7.) to rieši.
- Zástena = samostatný typ s dvoma dekormi (líce/rub) a hrúbkami 9,2–12.
- Sprievodné položky viazané na dekor: TL lišta 4,1 m · HPDB š.45 koncová hrana.
- Poznámka k metóde: `/vyhledavani` je v robots.txt disallowed pre boty — budúci „zadaj kód" lookup v plugine číta PRODUKTOVÉ stránky/detail (povolené), nie hromadný crawl; overiť pri implementácii V0.6-B.
