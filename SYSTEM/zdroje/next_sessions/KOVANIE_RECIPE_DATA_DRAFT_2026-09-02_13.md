# KOVANIE — draft dát receptov Atira + Quadro V6 EB23 (2026-09-02, checkpoint #13)

> Stav: KONCEPT / dátový draft pre KOV-C data packy (`noxun_engine/data/recipes/*.json`) — nie implementačný spec. Hodnoty len s tagom
> OFFICIAL/SECONDARY/USER z checkpointu #10 a #11; UNCONFIRMED sa do packu NEZAPISUJE. Kódy K-sád z checkpointu #12 (✓ = reálne objednané).

## 0. Schéma packu (návrh — KOV-C C1 ju finalizuje a validuje pri načítaní)

```json
{ "recipe_version": 1, "system": "atira", "family": "metal_box_drawer", "vendor": "Hettich",
  "runner_variants": { "eb_by_kd": { "16": 12.5, "18": 10.5, "19": 9.5 }, "orderable": { "10.5": true, "12.5": false, "9.5": false } },
  "pins": { "mounting": "slide_on", "rear_type": "wooden" },
  "formulas": { "bottom_width": "LB - 2*EB - 51.5", "rear_width": "LB - 2*EB - 63", "bottom_length": "NL + 10" },
  "thickness_supported_mm": [16],
  "height_variants": { "H70": {...}, "H144": {...}, "H176": {...} },
  "nl_series": [260,300,350,420,470,520,620],
  "availability": { "loads_by_nl": {...}, "openings_by_nl": { "260": ["sisy"], "300": ["sisy"], "350": ["sisy"], "420": ["sisy"], "470": ["sisy"], "520": ["sisy"], "620": ["sisy","p2o"] } },
  "min_depth": { "sisy": {...}, "p2o": {...} },
  "extras": { "sync_shaft": { "trigger": "width_gte_600_and_opening_eq[p2o]", "cut_formula_by_eb": {"9.5":"LW-64","10.5":"LW-66","12.5":"LW-70"} } },
  "inner_supported": false }
```
Vzorce sa NEinterpretujú ako jazyk — každý vzorec = pomenovaná konštanta v kóde (`c_bw`, `c_rw`, `c_bl`…), pack nesie hodnoty. Formula-string je len dokumentácia.

## 1. Hettich InnoTech Atira (METAL_BOX_DRAWER) — Noxun profil: KD 18 → EB 10.5, drevený chrbát, dno+chrbát 16 mm

| Pole | Hodnota | Tag |
|---|---|---|
| EB podľa KD | 16→12.5 · **18→10.5** · 19→9.5 (Démos skladuje EB 10.5; 12.5/9.5 na objednávku) | OFFICIAL (#10) · USER (profil) |
| šírka dna | `LB − 2·EB − 51.5` → pri KD 18: `LB − 72.5` | OFFICIAL |
| šírka chrbta (drevený) | `LB − 2·EB − 63` → `LB − 84` (rovnaké pre H70/H144/H176) | OFFICIAL + USER |
| dĺžka dna | `NL + 10` (drevený chrbát; oceľový by bol NL − 3 — mimo profilu) | OFFICIAL |
| výška chrbta | H70 = **65.5** (výrobne 65) · H144 = **144** · H176 = **176** (H54 = 53 existuje, V1 neponúka) | SECONDARY (Démos) + USER |
| min. svetlá výška niky | H70: **105 / 106** · H144: **189 / 190** · H176: **221 / 222** (SiSy / P2O) — NIE 92!; hodnoty P2Os (108/192/224) sú v #10, ale **P2Os je pre Noxun NESCHVÁLENÝ** (Michal 5.9.2026) | OFFICIAL (#10, korekcia #11) |
| relingy | H70: 0 · H144: 1+1 · H176: 1+1 (súčasť K-sady …/176 resp. „relingy") | USER (#09) |
| NL rad | 260 · 300 · 350 · 420 · 470 · 520 · 620 | OFFICIAL |
| nosnosť per NL | 260 → [30] · 300–520 → [30, 50] · 620 → [50]; **žiadna 60 kg**; (P2Os 10 kg trieda vyhodená — NESCHVÁLENÝ typ) | OFFICIAL |
| min. hĺbka korpusu | NL ≥ 300: `NL + 15` · **NL 260: 279 (SiSy) / 305 (P2O)** | OFFICIAL |
| hrúbka dna/chrbta | 16 mm (bez drážky — dno sadá na prírubu zargy); iné UNCONFIRMED → `thickness_supported = [16]` | OFFICIAL detail + USER |
| opening | SiSy · P2O — geometria boxu identická; mení kit kód, min. výšku, dostupnosť. **P2Os (Push to open Silent) NEschválený pre Noxun** — Michal 5.9.2026: len 2 typy otvárania pre výsuvy aj závesy | OFFICIAL + rozhodnutie |
| sync tyč (P2O) | povinná pri šírke ≥ 600 (inkluzívne): rez EB 10.5 → `LW − 66` (dĺžková položka — R-06a ORANGE; chýbanie = blocker KOV-D) | SECONDARY |
| vnútorná zásuvka | `inner_supported: false` (V1 len klasifikácia; doplnky = profil 2000 + príchyt — dĺžkové/pomerové) | USER + #12 |
| vyrábané dielce | presne 2: dno + drevený chrbát; ABS: dno bez, chrbát horná dlhá hrana 1,0 | USER (#09, #11) |

**Kit kódy Atira biela (K-sada = bočnice + výsuv), per (výška × NL × opening × load) — z #12:**

| výška | NL 350 | NL 420 | NL 470 | NL 520 | NL 620 |
|---|---|---|---|---|---|
| H70 SiSy 30 | 357694 š | **357695 ✓** | **357696 ✓** | — | 357716 (PTO 50) š |
| H144 relingy | — | — | 357736 š | — | **357755 ✓** (620/50 PTO) |
| H176 relingy | 357773 š · 341609 š | **357774 ✓** | **357775 ✓** · 357781 ✓ (50 kg) | 357777 š · 357782 (50) š | **357783 ✓** (620/50) · 357795 ✓ (50 PTO) |
| antracit | 357887 ✓ (350/70) | 357969 ✓ (420/70/176) | 348777 ✓ (470/70) · 357970 ✓ (470/70/176) · 341626 ✓ | — | — |

Chýbajúce kombinácie (napr. H144 NL 420/520) = **ORANGE `nl_missing`** ako dnes — nikdy tichá zámena; doplní sa pri seede z Démosu.

## 2. Hettich Quadro V6 EB23 (WOOD_DRAWER_UNDERMOUNT) — Noxun profil: EB23, slide-on, 16 mm (18 valid), 30 kg

| Pole | Hodnota | Tag |
|---|---|---|
| vnútorná šírka boxu | `SKW = LB − 46` (EB23; EB20 by bolo LB−40, 4D LB−40/−42 — mimo profilu, pole `runner_variant` drží) | OFFICIAL |
| dĺžka boxu | `= NL` (slide-on/nasunutie); spojková montáž `NL − 10` — pin `mounting: slide_on`, Démos 4D sady sú SO spojkami (pozor pri seede) | OFFICIAL + addendum #10 |
| min. hĺbka korpusu | `NL + 13` (SiSy aj P2O) | OFFICIAL |
| odsadenie dna | 12 (oficiálne 12–13) | OFFICIAL + USER default |
| výška boxu | `available_height − 40` (Noxun clearance, recept parameter; ručný override) | USER (#09) |
| dielce (5) | boky 2× `NL × box_h` · dno `SKW × NL` · vnútorné čelo a chrbát `SKW × (box_h − t − 12)` (16 mm: 130 → 102) | USER (#08 Excel) |
| NL rad | EB23 od 250; V6 SiSy 280–600 (280/300/320/350/380/400/420/450/480/500/520/550/580/600); P2O sklad 300–500 | OFFICIAL/SECONDARY |
| nosnosť | 30 kg (V6+ 50 existuje — mimo V1) | OFFICIAL + USER |
| hrúbka bočníc | ≤ 19 mm (EB23); Noxun 16 default, 18 valid → `thickness_supported = [16, 18]`; overiť 16 mm výhradu 4D listu (netýka sa EB23 slide-on) | OFFICIAL + USER |
| opening | SiSy · P2O — geometria identická; P2O sync tyč EB23 `LW − 94` pri šírke > 600 | SECONDARY |
| ABS | boky + vnútorné čelo + chrbát: horná dlhá hrana 1,0; dno bez | USER (#11) |

**Kit kódy Quadro V6 (K-set = pár + príchyty) — z #12:** SiSy: 350 → 317640 š · 400 → **317641 ✓** · 450 → **317642 ✓** · 500 → **317643 ✓** · 550 → 367919 š ·
P2O: 350 → **343031 ✓** · 400 → **343033 ✓** · 450 → **317644 ✓**. Komponentová alternatíva (mimo V1 automatiky, ad-hoc): pár 315830/315831 + spojky 104547/104548.

## 3. Čo NEzapisovať (UNCONFIRMED / mimo V1)

Atira iné hrúbky dna · Quadro 4D dĺžka so spojkami · StrongBox/StrongMax vzorce (len SECONDARY, 2 generácie) · TANDEM 19 mm · antaro výška C · akékoľvek nosnosti 60 kg pre Atira.
Pri každom doplnení dát: tag zdroja do packu (`source` pole) a riadok do checkpointu #10.
