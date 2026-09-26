# K1+K2 + D-143 — syntéza a reconcile krížového auditu (27.9.2026)

> **Stav: rozhodnutia orchestrátora** nad packetmi [CROSS_AUDIT_GROK_2026-09-27.md](CROSS_AUDIT_GROK_2026-09-27.md) (9 nálezov) a
> [CROSS_AUDIT_CODEX_2026-09-27.md](CROSS_AUDIT_CODEX_2026-09-27.md) (2 BLOCKER · 11 FIX · 3 NOTE) · zadanie [CROSS_AUDIT_PROMPT_2026-09-27.md](CROSS_AUDIT_PROMPT_2026-09-27.md) ·
> auditovaný návrh [KONCEPT_K1K2_2026-09-26.md](KONCEPT_K1K2_2026-09-26.md) (zmeny z tohto súboru sú v ňom zapracované ako **v2**, §11) · otázky na Michala v §4.
> Gemini nebežal (Michal 26.9.). **Sondy v SketchUpe netreba** — žiadny nález nie je ALREADY EXISTS / SIMPLER NATIVE PATH k API SketchUpu.

## 1 · Súhrn

**Zhoda oboch audítorov:** návrh A pre D-143 (oddelený rozmer do nárezu, `prod = box` sa nerozvoľňuje) je správna cesta s doloženým precedensom
(OpenCutList: hrubý vs. hotový rozmer, prídavky na dielci; GPL — vzor áno, kód nie) · výber NL „najväčšia s `min_depth ≤ svetlá hĺbka`" je správny
v rámci tabuľky konkrétneho systému (Blum TANDEMBOX/LEGRABOX/MOVENTO NL+3, Hettich AvanTech YOU NL+3, Quadro V6 NL+13) · **komín X nie je voľný
vetrací kanál** — pri naloženom chrbte je voľná šachta `X − bt` (HDF 3 → 47 mm, pevný 18 → 32 mm; výrobcovia chladničiek chcú ≥ 38–40 mm
a prierez 200 cm² v sokli a hore) · **navrhnutá Chladničková 580 × komín 50 by mala vnútro 530 mm**, vstavané chladničky chcú niku ≥ 550
(odporúčane 560) — pravidlo M9 „nika po posunutý chrbát" ostáva, meniť treba rozmery šablóny · pri drážke skáče vnútro pri malom X (bez komína
chrbát 10 mm pred zadnou hranou, s komínom za zadnými hranami dna a stropu).

**Blokujúce (Codex, oba prijaté):** **B1** D-143 potrebuje zvýšenie `CONFIG_SCHEMA` už v KON-0 — starší plugin by nové pole ignoroval a vydal
564 × 684 · **B2** `R = d − X` nie je spoločný zadný doraz pri `X = 0` (naložený chrbát skracuje telo o `bt`) — vzorec v koncepte bol zlý.

**Nový výrobný nález z auditu (Codex FIX 6):** vložený chrbát alebo chrbát v drážke + **výstuhy na výšku** — chrbát dnes prechádza zadnou výstuhou
(pri výstuhe 100 a hrúbke 18 až o 82 mm) a v kusovníku je **vyšší, než sa zmestí**. Zapisuje sa ako **D-144** a rieši sa v KON-A (tá istá geometria chrbta).

## 2 · Nálezy → rozhodnutie

| Nález | Rozhodnutie | Kam |
|---|---|---|
| Codex B1 — D-143 bez bumpu schémy: starý `Bom.record` vydá 564 × 684; odpojený dielec neprechádza kontrolou schémy korpusu | **Berieme.** KON-0 zvyšuje `CONFIG_SCHEMA` 18 → **19** (dopredná a exportná brána R-12 zastaví starší plugin). K1 → **20**, K2 → **21** (čísla podľa poradia mergov). **Odpojený dielec s rozmerom do nárezu:** starší plugin ho nevie zastaviť → výslovné rozhodnutie v package KON-0 (návrh: nový plugin pri odpojení chrbát so `cut_size` odmietne, alebo priznaný zvyšok + obe PC naraz) | KON-0 · §7 konceptu |
| Codex B2 — `R = d − X` pri `X = 0` a naloženom chrbte (strop 490 namiesto 487) | **Berieme.** Doraz dna/stropu: pri `X = 0` dnešné `carcass_depth` (`d − bt` pri `overlay`, inak `d`); pri `X > 0` `d − X`. Zapustenie `Y` sa odpočítava od dorazu. Hĺbka bokov sa od dorazu oddeľuje | koncept §1, §2 |
| Codex FIX 3 — `cut_size` musí niesť oba rozmerové páry, kontrolovať väčší polotovar voči formátu platne, nezapočítať odrezok do hmotnosti, uplatniť pred otočením podľa dekoru | **Berieme** do KON-0 | KON-0 |
| Codex FIX 4 — ABS na zväčšenom chrbte by skončil na odpade | **Berieme:** rozmer do nárezu **len keď chrbát nemá účinné ABS**; s ručným olepením ostáva rozmer geometrie a Kontrola to prizná (ORANGE s dôvodom); override nezmizne | KON-0 |
| Codex FIX 5 — `back_front_y > 10` nestačí (výstuhy sa prekryjú, noha presahuje dno) | **Berieme:** výstuhy kontrolovať v intervale `Y … doraz`, upright cez dve hrúbky; nezmestiteľné minimum **odmietnuť** (clamp len tam, kde výsledok ostane platný); nohy podľa dorazu dna | KON-A |
| Codex FIX 6 — `back_z_hi ≠ interior.z_hi`; inset/groove + upright výstuhy = kolízia | **Berieme** ako **D-144** (výrobná chyba dnešného stavu); horná lišta K2 viazaná na `interior.z_hi` | KON-A (D-144) · KON-B |
| Codex FIX 7 — vynechaný default vs. „zachovaj cieľ" pri šablónach | **Berieme:** config smie vynechávať predvoľby, **nové šablóny zapisujú explicitne 0 / 0 / 100**; zachovanie cieľa len pri skutočnej absencii kľúča v legacy šablóne | KON-A · KON-B |
| Codex FIX 8 + Grok 6 — jedna rola s variantom nevie dať opačné olepenie | **Berieme:** dve roly `back_rail_top` / `back_rail_bottom`, obe ABS `L1`, len dolná v `STANDING_ROLES`; `NAME_PAIRS` → „Chrb HD"; zlúčiť len skutočne zhodné výrobné kusy (iný materiál/ABS override = iný riadok) | KON-B |
| Codex FIX 9 — JS zrkadlá a predvoľby sa nedajú odložiť do KON-C; `setNum` pri riedkom configu nechá hodnotu predchádzajúcej skrinky | **Berieme:** predvoľby a parita Ruby/JS patria do A a B; guard = hodnotový round-trip `cabinet_config` → `config_to_params` → formulár; KON-C len bokorys | KON-A · KON-B |
| Codex FIX 10 + Grok 9 — scale: tichá odmietacia cesta, statické minimum 150 | **Berieme:** config-aware minimum hĺbky podľa tých istých pravidiel + jeden krok Späť overený in-SU; hláška pri odmietnutí | KON-A |
| Codex FIX 11 — nová šablóna sa do knižnice STD 6 sama nedoseje | **Berieme:** STD 6 → 7 + jednorazový seed; neprepísať rovnomennú vlastnú šablónu ani neobnoviť zmazaný seed; seed nesie `config_schema` | KON-D (audit-povinná — STD) |
| Codex FIX 12 — dnešný golden D-143 nepotvrdí | **Berieme:** geometrické goldeny ostávajú; nový reťazový test snapshot → kusovník → formát platne → VEPO → cena (dekor, poškodený námer, reopen, starý config) | KON-0 |
| Codex FIX 13 + Grok 1, 2 — X nie je voľný kanál; Chladničková 580/50 = vnútro 530 | **Berieme:** v UI a bokoryse rozlíšiť „komín X" a „voľný kanál" **podľa režimu** (§5: `overlay`/`groove` `X − bt`, `inset`/`rails` `X`, `none` bez kanála); **rozmery Chladničkovej rozhodne Michal** (§4); kontrola niky vetranie nepotvrdzuje (vetranie ostáva mimo V1, na šablóne veta o otvoroch v sokli a hore) | KON-A · KON-D · §4 |
| Grok 3 + Codex Q7 — groove: skok vnútra pri malom X | **Berieme, spresnené review PR #398 (§5):** minimum **podľa účinného režimu chrbta** — `groove` `X ≥ 10 + bt` (HDF 3 → 13 mm), `overlay` `X ≥ bt`, `inset`/`rails`/`none` bez minima (skrytá hrúbka chrbta sa nepočíta); inak odmietnuť s vetou | KON-A |
| Grok 4 — pri prekryve výstuh odmietnuť, nie tichý clamp | **Berieme** (súhlasí s FIX 5) | KON-A |
| Grok 5 — lišty na celej výške môžu zhodiť výsuv o celý stupeň 50 mm | **Berieme ako vedomý dôsledok M5** — ukáže mockup a PR popis; bez zmeny návrhu | KON-B · mockup |
| Grok 7 + Codex Q3 — plný rozmer HDF nie je doložená norma (prax +~15 mm oproti svetlosti); plocha +12 %; karta má ukázať oba rozmery; prestavba starej zákazky zmení cenu | **M8 ostáva** (rozhodnutie dielne). Karta dielca ukáže „do nárezu 600 × 720 · v modeli 564 × 684"; PR a KRONIKA priznajú vyššiu plochu a zmenu po prestavbe | KON-0 · mockup |
| Codex Q7 — `cut` koliduje s dnešným booleanom v `vepo_export.rb:413` | **Berieme:** pole sa volá **`cut_size: {length, width}`**; poškodený námer zastaví výrobný výstup, chýbajúce pole = geometria | KON-0 |
| Codex Q7 — nikový box neorezávať | **Berieme:** box niky ostáva celý (ukazuje požadovaný priestor) | KON-A |
| Codex NOTE 14, 16 · Grok 4 (precedensy Mozaik `BkRecess`, PolyBoard Recess/Groove, OCL oversizes) | **NO ACTION** — precedens potvrdzuje smer, cudziu referenčnú rovinu nepreberáme; bokorys je vlastné UI riešenie | — |
| Codex NOTE 15 (tabuľky NL per systém) | **NO ACTION** v tomto bloku — správnosť seedových tabuliek výsuvov je mimo rozsahu | — |
| Oprava faktov (Codex Q7): predné odsadenie políc je **20 mm, nie 25** (`zone_tree.rb:25`) | opravené v tomto súbore; FAKTY ostávajú ako dobový podklad | — |

## 3 · Čo sa mení v dávkach

- **KON-0 · D-143** — `cut_size` + `CONFIG_SCHEMA` 19 + ABS výnimka + reťazový test + rozhodnutie o odpojenom dielci; audit-povinná, výrobná.
- **KON-A · K1** — doraz dna/stropu (B2), minimum komína podľa účinného režimu chrbta, výstuhy: orezanie s upozornením len keď výsledok ostane platný, inak odmietnutie, nohy podľa dorazu, config-aware scale,
  explicitné predvoľby v šablónach, JS parita v tej istej dávke, **D-144** (inset/groove + upright výstuhy); `CONFIG_SCHEMA` 20.
- **KON-B · K2** — dve roly lišty (dolná stojaca), jeden riadok len pri zhodných kusoch, horná lišta na `interior.z_hi`, JS parita; `CONFIG_SCHEMA` 21, BuildPlan 6, ABS seed 5.
- **KON-C** — len bokorys v rohu náhľadu (+ „voľný kanál").
- **KON-D** — Chladničková: STD 6 → 7 + jednorazový seed (audit-povinná), rozmery podľa Michala.

## 4 · Otázky na Michala (ráno, spolu s mockupom)

1. **Rozmery Chladničkovej:** aby vstavaná chladnička mala niku 560 a komín 50, celková hĺbka vychádza **610** (vnútro 560, voľný kanál 47 mm pri HDF 3).
   Súhlasíš s 600 × 2100 × 610, alebo robíte chladničkové skrine inak (iná hĺbka, iný komín, iná výška)?
2. **D-144** (nová stará chyba): používaš niekde vložený chrbát alebo chrbát v drážke spolu s **výstuhami na výšku**? Ak áno, oprava ide skôr.
3. **Minimálny komín podľa typu chrbta:** pri chrbte **v drážke** aspoň 10 mm + hrúbka chrbta (HDF 3 → 13 mm, pevný 18 → 28 mm), pri **naloženom** aspoň hrúbka chrbta (aby netrčal za boky), pri vloženom, lištách a bez chrbta bez minima — v poriadku?
4. **Po KON-0 musí mať aj Lucia hneď novú verziu** — inak jej plugin zákazky z tvojho PC neprestaví ani nevyexportuje (to je zámer, chráni pred malým chrbtom).

## 5 · Review PR #398 — GH Codex kolo 1 (27.9.2026)

| Nález | Rozhodnutie | Kam |
|---|---|---|
| **P1** — zvýšenie schémy nechráni pred **starými snapshotmi v novom plugine**: skrinka s chrbtom v drážke postavená pred KON-0 vydá ďalej 564 × 684, kým sa neprestaví, a nič to neprizná | **Berieme:** KON-0 pridá kontrolu **zastaraného chrbta v drážke** (skrinka s `groove` bez `cut_size` / pod aktivačnou schémou, vzor `*_ACTIVATION_SCHEMA`) → Kontrola s výzvou „prestav skrinku" + **zastavenie výrobných exportov**, kým sa neprestaví; tvar brány a hromadnú prestavbu rozhodne audit KON-0 | koncept §11 · KON-0 |
| P2 — `cut_size` chýba v autoritatívnom kontrakte (STANDARD §8.2 definuje `length`/`width` ako výrobné rozmery) | **Berieme:** KON-0 zapíše `cut_size` do STANDARD §8.2 (rozdiel voči rozmeru dielca, fallback, poškodený údaj) | koncept §11 · KON-0 |
| P2 — voľný kanál `X − bt` platí len pre `overlay` a `groove` pri komíne | **Berieme:** kanál podľa režimu — `overlay`/`groove` `X − bt`, `inset`/`rails` `X`, `none` bez ohraničeného kanála | koncept §1 · KON-A · KON-C |
| P2 — minimum `10 + bt` nezávisle od režimu (skrytá hrúbka pri `rails`/`none` by blokovala platný komín) | **Berieme:** minimum podľa účinného režimu (tabuľka §2, riadok Grok 3) | koncept §1 · KON-A |

Kolo vrátilo P1 → oprava v tomto PR a **nové plné GH kolo** (`@codex review`) podľa `codex-po-pr`.

## 6 · Review PR #398 — GH Codex kolo 2 (27.9.2026)

| Nález | Rozhodnutie | Kam |
|---|---|---|
| **P1** — oprava D-144 len v builderi nechá staré skrinky (`inset`/`groove` + výstuhy na výšku) s kolidujúcim chrbtom v snapshote | **Berieme:** KON-A pridá kontrolu zastaraných skriniek podľa **aktivačnej schémy 20** pre túto kombináciu → Kontrola s výzvou prestaviť + zastavené výrobné exporty, kým sa neprestavia | koncept §11 · KON-A |
| P2 — zastaranosť „`groove` bez `cut_size`" by navždy blokovala prestavaný chrbát s ručným olepením (ten `cut_size` zámerne nemá) | **Berieme:** zastaranosť sa určuje **aktivačnou schémou** (`groove` a `config_schema < 19`), nie prítomnosťou `cut_size` | koncept §4 · KON-0 |
| P2 — odsek Validácia v §1 ešte uvádzal `X < bt` pre `overlay` aj `groove` | **Berieme:** odsek uvádza minimum podľa režimu (`groove` `10 + bt`) | koncept §1 |
| P2 — clamp výstuh `rd ≤ R/2 − 10` ignoruje `Y` a orientáciu (upright zaberá `t`) | **Berieme:** flat `rd ≤ (R − Y)/2 − 10`, upright `Y + 2t + 20 ≤ R`, pri nesplnení odmietnutie | koncept §1, §2 |

Kolo 2 vrátilo P1 → oprava a **3. plné GH kolo**. Aby tretie kolo nenarážalo na rozpory medzi pôvodným textom a dodatkom, **v2 je zapracovaná
priamo do §1–§8 konceptu** (§11 je už len prehľad zmien). Pravidlo 3 kôl: ak 3. kolo vráti P0/P1 alebo zmenu konceptu, PR sa zavrie a rozdelí.

**Slepá kontrola dokumentov pred 3. kolom** (nový slepý recenzent, 27.9.; 2× P2 + 4× P3, všetko opravené): minimum komína podľa režimu aj v §3
a v otázke pre Michala (§4 ot. 3) · jednotné pravidlo výstuh — flat orezanie s upozornením `rail_depth_clamped` a odmietnutie len pod minimom 20 mm,
upright odmietnutie; to isté pri absorpcii mierky (koncept §1, §2) · D-144 v tabuľke §1 (inset, groove bez komína) a výnimka z „pri X = 0 sa nič
nemení" · odkaz na STANDARD opravený na §7.2 („výstupy čítajú výhradne snapshot") a §11.1 · trieda KON-D (nie výrobná) a in-SU podľa spúšťačov
v PLAN · minimum plného stropu určí audit KON-A · M8 a D-143 formulované ako „plný rozmer skrinky `w × (h − s)`" (pri komíne sa líši od naloženého).
