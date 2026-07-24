# UI vízia — „NOXUN Furniture Engine" mockup (Michal, 16.7.2026)

> Michal dodal mockup celoobrazovkového UI ako **základné smerovanie** („páči sa mi, nie doslovne — kopec užitočných detailov a UI/UX prvkov"). Tu je rozpis prvkov + syntéza s dilemou 05 (v archíve). Screenshot: hlavné taby PROJEKT · MODEL · VÝROBA · MATERIÁLY · KOVANIE · NASTAVENIA.
>
> **Stav k 24.7.2026 (v0.5.0):** HOTOVÉ z tabuľky — ABS editor (V0.3+, per-hrana s 2D náhľadom), materiálový katalóg (D-42 mriežka dlaždíc; taby podľa výrobnej triedy nahradené sekciami podľa výrobcu), kusovníky + podľa materiálu (okno Výroba V0.5), KONTROLA karta (semafor V0.5-D), VEPO CSV export. OTVORENÉ — strom štruktúry modelu so stavmi, info karta dielca v okne Výroba, rýchle akcie, plná lišta exportov (XLSX/PDF/kovanie), „Použiť na podobné" (vráti sa s kovaním V0.6+). Syntéza s dilemou platí: Inspector pri kreslení + veľké okno Výroba na kontrolu/výstupy.

## Prvky mockupu, ktoré PREBERÁME (a kedy)

| Prvok | Detail | Etapa |
|---|---|---|
| **Strom štruktúry modelu so stavmi** | Kuchyňa → skrinky → dielce; ikony: ✓ OK, číslo (počet), ⚠ warning, oko (skrytý); search + filter | V0.5 (Výroba okno) |
| **Info karta dielca** | typ (Plošný), materiál, rozmer, **ABS per hrana** (Predná 1.0 / Zadná bez / Ľavá 1.0 / Pravá 1.0), otočenie dekoru ↔, počet v modeli, **„Označiť v modeli"** (obojsmerná navigácia) | V0.3 (dáta) + V0.5 (karta) |
| **ABS EDITOR** | 2D dielec s očíslovanými farebnými hranami 1–4, per-hrana dropdown (ABS K009 1.0 / ABS K009 2.0 / Bez ABS), **„Použiť na podobné diely (N)"** — hromadná aplikácia | **V0.3 — priamy vzor UI** |
| **Materiálový katalóg s tabmi podľa výrobnej triedy** | Plošné / Dĺžkové / Kusové / Referenčné (= presne production_class zo štandardu!); karty s náhľadom, rozmerom tabule | **V0.3 — priamy vzor UI** |
| **Kusovník (zoskupené dielce)** | stĺpce: diel, rozmer, hrúbka, materiál, **ABS kompakt „P:1 / L:2 / R:2"**, počet, skrinka; prepínač „Podľa skriniek"; súčtový riadok (dielcov, kusov, m²) | V0.5 |
| **Kusovník podľa materiálu** | vrátane dĺžkových (bm/mm) a kusových položiek | V0.5 |
| **KONTROLA MODELU karta** | Chyby 0 🔴 / Upozornenia 2 🟡 / Informácie 5 🔵 + „Najčastejšie upozornenia" (2 dielce bez ABS na viditeľných hranách, 1 komponent bez materiálu) + detail | V0.5 (semafor) |
| **Rýchle akcie** | Aktualizovať dáta, Skontrolovať model, Kontrola ABS, Priraď materiály, Priraď kovanie | V0.5 |
| **Lišta exportov vždy viditeľná** | XLSX tabuľka · CSV univerzál · **VEPO CSV** · kovania XLSX · Tlač/PDF | V0.5 |
| Hlavné taby ako mentálny model | MODEL (návrh) / VÝROBA (kusovníky+kontrola) / MATERIÁLY / KOVANIE / NASTAVENIA | priebežne |

## Syntéza s dilemou 05 (dva panely vs. jedno veľké okno)

Mockup je „štúdiový" celoobrazovkový režim — pri kreslení v SketchUpe nepraktický (zakryje model), ale **presne správny pre výstupnú/kontrolnú fázu**. Syntéza:

- **Pri navrhovaní:** kompaktný Inspector (dnešný panel → per-dielec akordeóny zo SYSTEM/06) + neskôr Vkladač. Malé okná popri modeli.
- **Pri kontrole/výstupoch:** VEĽKÉ OKNO „Výroba" v štýle mockupu (strom + kusovníky + kontrola + exporty + materiály/ABS editor) — otvára sa na záver práce; persona: aj manželka (ponuky). ✅ Toto rieši dilemu pre tretí pilier.
- MATERIÁLY/KOVANIE katalógy: sekcie veľkého okna (správa katalógu sa nerobí popri kreslení).

## Poznámka k 2D/3D náhľadu (Michalov bod zo 16.7.)

Náhľad v paneli sa osvedčil → v neskorších verziách **povýšiť na „otvárací náhľad"** (hlavný vizuál panela) so zobrazovaním zvoleného elementu: dvere, nastavenia korpusu, dielec s hranami (ABS editor je vlastne ten istý koncept pre dielec). Zapísané v backlogu.
