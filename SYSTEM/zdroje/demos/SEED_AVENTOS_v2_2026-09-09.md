# SEED v2 — AVENTOS HK top / HL top (9.9.2026) — SCHVÁLENÝ MICHALOM 9.9.2026

> Nahrádza `SEED_AVENTOS_2026-09-08.md`. Ceny **s DPH** (Démos `price_with_vat`, stav 9.9.2026), MJ z Démosu, LF/KH z produktových stránok Démos,
> **hmotnostné limity HL top z Blum katalógu 2024/25** (publications.blum.com, str. 40 — verejný zdroj, e-services netreba).
> Zber: `harvest_aventos.py` (8.9.) + `harvest_aventos2.py` (9.9., doplnky cez „súvisiaci sortiment" každého mechanizmu) → `aventos_doplnky_2026-09-09.json`.
> Rozhodnutia Michala 8.–9.9. sú zapracované (bez adaptéra · Tip-On jednotka podľa farby · tyč vždy · od KB 1100 2× tyč + predĺženie · len skrutky · HL bez Tip-On).

## A · HK top — mechanizmy (skrutky do DTD; kategória VYKLOPY)

| kód | názov (Démos) | MJ | cena s DPH | LF | URL |
|---|---|---|---|---|---|
| 347810 | BLUM 22K2300 Aventos HK Top výklop slabý | sada | 71,45 | 420–1610 | https://www.demos-trade.sk/blum-22k2300-aventos-hk-top-vyklop-slaby/ |
| 347811 | BLUM 22K2500 Aventos HK Top výklop stredný | sada | 71,45 | 930–2800 | https://www.demos-trade.sk/blum-22k2500-aventos-hk-top-vyklop-stredny/ |
| 347812 | BLUM 22K2700 Aventos HK Top výklop silný | sada | 71,80 | 1730–5200 | https://www.demos-trade.sk/blum-22k2700-aventos-hk-top-vyklop-silny/ |
| 347813 | BLUM 22K2900 Aventos HK Top výklop najsilnejší | sada | 84,00 | 3200–9000 | https://www.demos-trade.sk/blum-22k2900-aventos-hk-top-vyklop-najsilnejsi/ |
| 347814 | BLUM 22K2300T Aventos HK Top výklop slabý, Tip-on | sada | 76,68 | 420–1610 | https://www.demos-trade.sk/blum-22k2300t-aventos-hk-top-vyklop-slaby-tip-on/ |
| 347826 | BLUM 22K2500T Aventos HK Top výklop stredný, Tip-on | sada | 76,68 | 930–2800 | https://www.demos-trade.sk/blum-22k2500t-aventos-hk-top-vyklop-stredny-tip-on/ |
| 347827 | BLUM 22K2700T Aventos HK Top výklop silný, Tip-on | sada | 81,56 | 1730–5200 | https://www.demos-trade.sk/blum-22k2700t-aventos-hk-top-vyklop-silny-tip-on/ |
| 347828 | BLUM 22K2900T Aventos HK Top výklop najsilnejší, Tip-on | sada | 93,77 | 3200–9000 | https://www.demos-trade.sk/blum-22k2900t-aventos-hk-top-vyklop-najsilnejsi-tip-on/ |

LF = výška korpusu (mm) × hmotnosť čela (kg) vrátane **dvojnásobnej** hmotnosti úchytky (Démos/Blum) → v pluginu `handle_allowance_kg` 0,5. Pri prekryve tried = najslabšia, ktorá LF pokrýva.

## B · HK top — krytky 22K8000 (bez Servo-Drive)

| kód | názov (Démos) | MJ | cena s DPH | URL |
|---|---|---|---|---|
| 347834 | BLUM 22K8000 Aventos HK Top krytky bez S-D, biela | sada | 11,26 | https://www.demos-trade.sk/blum-22k8000-aventos-hk-top-krytky-bez-s-d-biela/ |
| 347833 | BLUM 22K8000 Aventos HK Top krytky bez S-D, svetlo šedá | sada | 10,28 | https://www.demos-trade.sk/blum-22k8000-aventos-hk-top-krytky-bez-s-d-svetlo-seda/ |
| 347835 | BLUM 22K8000 Aventos HK Top krytky bez S-D, tmavo šedá | sada | 11,26 | https://www.demos-trade.sk/blum-22k8000-aventos-hk-top-krytky-bez-s-d-tmavo-seda/ |

Čierne krytky pre HK top v sivom (nie Eclipse) programe Démos **nemá** — čierna = len celý mechanizmus „Eclipse čierna" (mimo seedu).

## C · Čelný príchyt (HK aj HL)

| kód | názov (Démos) | MJ | cena s DPH | URL |
|---|---|---|---|---|
| 13781 | BLUM 20S4200 Aventos HK/HS/HL Top čelný príchyt | pár | 4,40 | https://www.demos-trade.sk/blum-20s4200-aventos-hk-hs-hl-top-celny-prichyt/ |

Mimo seedu: Onyx čierny (559539), alu (13782), Expando (23789), Expando T pre tenké materiály (559543).

## D · Tip-On jednotka pre HK top (bez adaptéra — zavŕtava sa; `per: owner`, farba podľa čela)

| kód | názov (Démos) | MJ | cena s DPH | farba | URL |
|---|---|---|---|---|---|
| 250831 | BLUM 956A1004 Tip-on pre závesy, 76mm, magnet, komplet, biela | ks | 6,93 | biela (predvolená) | https://www.demos-trade.sk/blum-956a1004-tip-on-pre-zavesy-76mm-magnet-komplet-biela/ |
| 250833 | BLUM 956A1004 Tip-on pre závesy, 76mm, magnet, komplet, šedá | ks | 6,93 | šedá | https://www.demos-trade.sk/blum-956a1004-tip-on-pre-zavesy-76mm-magnet-komplet-seda/ |
| 497007 | BLUM 956A1004 Tip-on pre závesy, 76mm, magnet, sada, čierna CS | sada | 6,93 | čierna | https://www.demos-trade.sk/blum-956a1004-tip-on-pre-zavesy-76mm-magnet-sada-cierna-cs/ |

Pozor na MJ: biela/šedá = **ks**, čierna = **sada** (Démos). Adaptéry 956A1201 (250841/250842/497010) sa **nevkladajú** (rozhodnutie 8.9.).

## E · HL top — mechanizmy a ramená (skrutky; **len klasický, HL top Tip-On neexistuje** — Michal 9.9., Démos ho nemá)

| kód | názov (Démos) | MJ | cena s DPH | KH | hmotnosť čela (Blum 2024) | URL |
|---|---|---|---|---|---|---|
| 507351 | BLUM 22L2200 Aventos HL Top výklop slabý, skrutky | sada | 80,91 | 300–389 | podľa ramien (1,50–10,00 kg) | https://www.demos-trade.sk/blum-22l2200-aventos-hl-top-vyklop-slaby-skrutky/ |
| 507352 | BLUM 22L2500 Aventos HL Top výklop silný, skrutky | sada | 86,81 | 390–580 | podľa ramien (2,00–14,00 kg) | https://www.demos-trade.sk/blum-22l2500-aventos-hl-top-vyklop-silny-skrutky/ |
| 507355 | BLUM 22L3200 Aventos HL Top ramená - 300-339mm | sada | 56,89 | 300–339 | **1,50–9,00 kg** | https://www.demos-trade.sk/blum-22l3200-aventos-hl-top-ramena-300-339mm/ |
| 507356 | BLUM 22L3500 Aventos HL Top ramená - 340-389mm | sada | 58,07 | 340–389 | **1,75–10,00 kg** | https://www.demos-trade.sk/blum-22l3500-aventos-hl-top-ramena-340-389mm/ |
| 507357 | BLUM 22L3800 Aventos HL Top ramená - 390-540mm | sada | 59,84 | 390–540 | **2,00–12,25 kg** | https://www.demos-trade.sk/blum-22l3800-aventos-hl-top-ramena-390-540mm/ |
| 507358 | BLUM 22L3900 Aventos HL Top ramená - 480-580mm | sada | 66,34 | 480–580 | **2,50–14,00 kg** | https://www.demos-trade.sk/blum-22l3900-aventos-hl-top-ramena-480-580mm/ |

Zdroj hmotností: Blum Catalogue and technical manual 2024–2025, str. 40 (https://publications.blum.com/2024/catalogue/en/40/); potvrdené aj cabinetparts.com (22L2200 „3.3 to 22 lbs" = 1,5–10 kg; 22L2500 „4.4 to 30.9 lbs" = 2–14 kg).
Prekryv KH 480–540: 22L3800 nesie do 12,25 kg, 22L3900 do 14,00 kg → **pravidlo: v prekryve najslabšie ramená, ktoré hmotnosť pokrývajú** (rovnaká logika ako LF triedy HK).

## F · HL top — stabilizačná tyč (VŽDY v sete; od šírky korpusu KB ≥ 1100 mm 2× tyč + predĺženie)

| kód | názov (Démos) | MJ | cena s DPH | URL |
|---|---|---|---|---|
| 507365 | BLUM 22Q1076U Aventos HL Top stabilizačná tyč (1076 mm) | ks | 15,59 | https://www.demos-trade.sk/blum-22q1076u-aventos-hl-top-stabilizacna-tyc/ |
| 507366 | BLUM 22Q080Z Aventos HL Top predlžovací diel stabilizačnej tyče | ks | 14,19 | https://www.demos-trade.sk/blum-22q080z-aventos-hl-top-predlzovaci-diel-stabilizacnej-tyce/ |

Blum katalóg udáva spojku od vnútornej šírky LW ≥ 1190 mm (KB ≥ 1228 mm); Michalov prah **KB 1100** je prísnejší a platí. Delenie jednej tyče na viac úzkych skriniek = téma „Dĺžkové" (mimo V1).

## G · HL top — krytky 22.8000 (bez Servo-Drive)

| kód | názov (Démos) | MJ | cena s DPH | URL |
|---|---|---|---|---|
| 507343 | BLUM 22.8000 Aventos HF/HL/HS Top krytky bez S-D, biela | sada | 12,73 | https://www.demos-trade.sk/blum-22-8000-aventos-hf-hl-hs-top-krytky-bez-s-d-biela/ |
| 507344 | BLUM 22.8000 Aventos HF/HL/HS Top krytky bez S-D, svetlo šedá | sada | 11,66 | https://www.demos-trade.sk/blum-22-8000-aventos-hf-hl-hs-top-krytky-bez-s-d-svetlo-seda/ |
| 507345 | BLUM 22.8000 Aventos HF/HL/HS Top krytky bez S-D, tmavo šedá | sada | 12,73 | https://www.demos-trade.sk/blum-22-8000-aventos-hf-hl-hs-top-krytky-bez-s-d-tmavo-seda/ |

## Zloženie setov (návrh pre package E — farba = dva sety na kľúč, tmavý sa vyberá ako override čela)

| set | kľúč | položky |
|---|---|---|
| `vyklop-hk-klasik` (biela, predvolený) | `class:lift\|classic\|hk_top` | mechanizmus 22K2x00 podľa LF (1 sada) + príchyt 13781 (1 pár) + krytky HK biela 347834 (1 sada) |
| `vyklop-hk-klasik-tmavy` | — (override) | to isté, krytky tmavo šedá 347835 |
| `vyklop-hk-tipon` (biela, predvolený) | `class:lift\|tipon\|hk_top` | mechanizmus 22K2x00T podľa LF (1 sada) + Tip-On jednotka 250831 (1 ks, `per: owner`, bez adaptéra) + príchyt 13781 + krytky HK biela 347834 |
| `vyklop-hk-tipon-tmavy` | — (override) | to isté, krytky tmavo šedá 347835 + Tip-On čierna 497007 (MJ sada) |
| `vyklop-hl-klasik` (biela, predvolený) | `class:lift\|classic\|hl_top` | mechanizmus 22L2200/22L2500 podľa KH (1 sada) + ramená 22L3x00 podľa KH + hmotnosti (1 sada) + tyč 507365 (1 ks; KB ≥ 1100: 2 ks + 507366 1 ks) + príchyt 13781 (1 pár) + krytky HL biela 507343 (1 sada) |
| `vyklop-hl-klasik-tmavy` | — (override) | to isté, krytky tmavo šedá 507345 |
| HL top + Tip-On | `class:lift\|tipon\|hl_top` | **NEZAKLADÁ SA** — HL top Tip-On neexistuje → RED `lift_combo_unsupported` |

Svetlo šedé krytky (347833 / 507344) a šedá Tip-On (250833) ostávajú v katalógu ako položky, set pre ne nevzniká (Michal 9.9.: šedú neriešime).

Mimo seedu (vedome): euroskrutkové varianty 22K2x10 / 22L2x10 · Eclipse čierne mechanizmy a ramená · krytky pre Servo-Drive 23K8000 / 23.8000 · Servo-Drive 23.A000 · príchyty alu / Onyx / Expando · rodina HF · Tip-On adaptéry 956A1201.

## Otázky na Michala — ZODPOVEDANÉ 9.9.2026 (1: biela | tmavá = tmavo šedá, šedú neriešime · 2: ručná voľba, jedna pre krytky aj Tip-On · 3: ORANGE · 4: OK)

1. **Farba krytiek:** predvolene biela; ponúknuť v karte čela aj svetlo/tmavo šedú (HK 347833/347835, HL 507344/507345)? Alebo vždy biela a farby nechať na ručný override setu?
2. **Farba Tip-On jednotky:** máme biela / šedá / čierna. Odvodiť automaticky z farby čela (tmavé čelo → čierna) alebo ručná voľba pri čele (predvolene biela)? Automatika by potrebovala pravidlo „ktorý dekor je tmavý", to v katalógu materiálov dnes nie je.
3. **Spodné limity hmotnosti:** Blum udáva aj minimum (HK LF 420, HL 1,5 kg). Príliš ľahké čelo = RED (mechanizmus by čelo vyhadzoval / neostalo by dole) alebo len ORANGE varovanie? Návrh: **ORANGE** (dá sa doladiť nastavením pružiny), audit to preverí.
4. HL mechanizmus 22L2200 vs 22L2500 má prah KH 389/390 a ramená 22L3500 vs 22L3800 tiež 389/390 — hranica sedí s Démosom aj Blumom, hraničný test KH 389 → 22L2200 + 22L3500, KH 390 → 22L2500 + 22L3800.

_Ceny overené 9.9.2026 (Démos LBX API)._
