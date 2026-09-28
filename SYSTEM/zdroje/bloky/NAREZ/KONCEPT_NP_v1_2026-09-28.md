# Blok 2 · Nárezový plán (primitívny) — pracovný koncept v1 (28.9.2026)

> Stav: **KONCEPT v1 — surový vstup pre krížový audit bloku, nie zadanie.** Záväzné sú len rozhodnutia Michala
> ([ROZHODNUTIA_MICHALA_2026-09-28.md](ROZHODNUTIA_MICHALA_2026-09-28.md), N1–N5) a po schválení mockup; technické požiadavky dostane **package každej dávky**
> s vlastným auditom návrhu. Podklady: návrh 6.9. [../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md](../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md)
> (Codex #322/#323) · fakty [FAKTY_Z_KODU_2026-09-28.md](FAKTY_Z_KODU_2026-09-28.md) (časti A/B, odkazy `súbor:riadok`) · rešerš
> [RESERS_OUTSIDE_IN_2026-09-28.md](RESERS_OUTSIDE_IN_2026-09-28.md). Body označené **(M)** sú „návrh — potvrdí Michal" (mockup).

## 1 · Čo uvidí používateľ

- **P1 · Štúdio → sekcia „Nárezový plán" (dnes neaktívna položka navigácie) ožije.** Pre každý **nákupný materiál** karta: názov a vzorka,
  formát platne, **„N platní (horná hranica)"**, využitie %, pre porovnanie odhad z m² a príznaky (formát chýba v katalógu · materiál neurčený UNI ·
  plán neúplný). Pod kartou **miniatúry platní** (jednoduché SVG): dielce ako obdĺžniky s rozmerom, šípka dekoru, šrafovaný zvyšok, % využitia platne;
  klik na miniatúru → detail jednej platne na šírku sekcie so zoznamom dielcov. **Upozornenie na takmer prázdnu poslednú platňu** (M) — napr.
  „Posledná platňa: 1 dielec 720 × 560 · využitie 8 %" (jantár) — priamo Michalova bolesť (N1). Dielce, ktoré sa nezmestia, ako červený zoznam.
  Klik na dielec v zozname → výber v modeli (tá istá cesta ako riadok Kusovníka — označí všetky rovnaké kusy) (M).
- **P2 · Rozpočet → Materiál:** riadok materiálu dostane v poznámke **„plán: N platní (horná hranica)"** (poznámka ide automaticky aj do XLSX rozpočtu).
  **Prepínač „ceny podľa plánu" per zákazka** v hlavičke sekcie Materiál (vzor: „sčítať do rozpočtu" pri Spotrebičoch), predvolene **vypnutý** = dnešné
  ceny sa pri otvorení starej zákazky nezmenia (návrh 6.9.). Zapnutý: množstvo platní = plán **len** pre materiál s úplným plánom a skutočným formátom
  z katalógu; ostatné ostávajú na odhade s poznámkou prečo. **Porez** (€/platňa) nasleduje počet platní, **montáž** ostáva z odhadu (M) — montáž
  závisí od dielcov, nie od odpadu.
- **P3 · Nastavenia rozpočtu → „Výpočet a upozornenia":** dve polia **Prerez píly 5 mm** a **Orez okraja platne 10 mm** (N3) — globálne pre všetky
  zákazky ako sadzby služieb (sekcia je dnes globálna, fakty B §4).
- **P4 · Kontrola:** existujúci RED nález „nezmestí sa na formát platne" (`oversize`) počíta **s orezom** — jedna pravda s plánom (dielec 2795 mm
  z platne 2800 s orezom 10 mm sa nevyrobí). Kontrola naďalej export nezastavuje (dnešná zásada „RED neblokuje export").
- **P5 · Cenová ponuka:** počty platní nikdy neukazuje (ako dnes) — pri zapnutom prepínači sa zmení len suma materiálu a porezu.
- **P6 · Nemení sa:** VEPO CSV, kusovník, nákup kovania, odhad z m² (ostáva ako porovnanie aj ako predvolená cena). Objednáva človek (N2).

## 2 · Vstup plánu

- **Zdroj = agregované riadky kusovníka `Bom.compute`** — tie isté, z ktorých vzniká VEPO CSV aj odhad (fakty A §1–§2); plán neskenuje model druhý raz.
  Rozmery sú **hotové vrátane ABS** (VEPO si ABS odpočíta samo) a obsahujú `cut_size` z D-143 → plán z nich je konzervatívny. Riadky, ktoré VEPO
  vyradí (bez materiálu, nekladný rozmer, počet < 1), plán tiež vynechá.
- **Orientácia = presne pravidlo VEPO** (`VepoExport.oriented`, raz): `width` → výmena dĺžky a šírky; `length`, `none` aj neznáma hodnota bez výmeny.
  Po normalizácii sa **`length` a neznáma hodnota neotáčajú** (ako VEPO), **`none` sa smie otočiť** podľa pevného pravidla (§3). Smer rozhoduje
  **snapshot dielca**, nie vlastnosť materiálu (pri doske jej vlastná hodnota). Kresba platne beží po **`sheet_size[0]`** — dnes implicitný predpoklad
  kódu, koncept ho navrhuje vysloviť v STANDARD.
- **Formát** zo živého katalógu (`sheets_map`, ako odhad). **Chýbajúci formát (fallback 2800 × 2070) a UNI** (pracovný formát) → plán sa spočíta,
  ale je **orientačný** a na cenu sa nepoužije.
- **Duplák:** riadok s `material_source.multiplier` 2–3 sa rozvinie na `množstvo × multiplier` obdĺžnikov hotového rozmeru **zdrojového** materiálu;
  duplák nikdy nie je vlastná platňa (rešerš Q4 · 7 potvrdzuje 2 plné prírezy).
- **Orez podľa typu materiálu (M):** DTDL, MDF, HDF a „iný" s orezom na každej hrane; **pracovná doska, kompakt a zástena** (formát je súčasťou identity,
  hrany sú hotové) **bez orezu**.
- **Identita obdĺžnika:** kľúč riadku kusovníka + poradové číslo výskytu (`<kľúč>#<n>`, n od 1) — deterministické; riadky `part_key` nenesú a
  zlučujú rovnaké dielce naprieč skrinkami (fakty A §2), preto výber v modeli ide cez riadok (všetky rovnaké kusy).

## 3 · Algoritmus (čisté Ruby, bez SketchUp API, headless testovateľný)

- Použiteľná plocha = `(L − 2·orez) × (W − 2·orez)`, kde `L = sheet_size[0]` (smer kresby platne).
- **Policová heuristika FFDH** (first-fit decreasing height): dielce deterministicky zoradené (výška pásu ↓, dĺžka ↓, kľúč riadku, n); pás cez celú
  použiteľnú dĺžku, dielce v páse zľava doprava; dielec ide do **prvého** pásu (v poradí platní a pásov), kde sa zmestí; inak nový pás na aktuálnej
  platni; inak nová platňa. **Kerf len medzi dielcami a medzi pásmi** (N dielcov v páse = N − 1 rezov), nie pri orezanom okraji (rešerš Q1 · 3) —
  dielec presne na použiteľnú šírku sa zmestí.
- **Otáčanie `none`:** najprv dlhšia strana pozdĺž dĺžky platne; ak sa nezmestí do skúšaného pásu, druhá orientácia; berie sa prvá, ktorá sa zmestí —
  žiadne hľadanie najlepšej.
- **Nezmestí sa ani na prázdnu použiteľnú plochu** → dielec nezaradený, materiál `incomplete` (počet platní bez neho).
- **Výstup per nákupný materiál:** `sheets` (horná hranica podľa tohto rozloženia), využitie (plocha dielcov / plocha celých platní; pri 0 platniach
  chýba), rozloženie per platňa (identita, x, y, rozmer, otočený), najväčší zvyšok per platňa (pravý koniec pásu alebo spodok platne), príznaky
  (`fallback`, `uni`, `incomplete`, bez orezu), použité parametre (formát, kerf, orez). Nezávisí od poradia vstupu.
- **Vlastnosti na testy:** determinizmus · `sheets ≥ ceil(Σ plocha / použiteľná plocha)` nad zaradenými dielcami · `sheets ≤ počet zaradených dielcov` ·
  hraničný dielec = použiteľná šírka/dĺžka · duplák × 2/× 3 · `length` sa neotočí, `none` podľa pravidla · kerf mení počet na hrane · golden fixtúry
  (presný počet aj polohy) · syntetická veľká fixtúra (KLINIKA fixtúru repo nemá) s časovým limitom.

## 4 · Napojenie

- **Kde sa počíta:** všade, kde dnes `SheetEstimate` — plný push Štúdia a `ProductionCore.budget_payload` (5 volajúcich: Štúdio, VEPO kontrola, XLSX
  rozpočtu, XLSX ponuky, prepočet cien) — jedna autorita čísel, klient nič neprepočítava. Štúdio sa pri zmene modelu neprepočítava (jantárové Obnoviť) —
  plán zdedí to isté správanie.
- **Prerez a orez:** 2 skaláre v globálnom `SupplierSettings` (fakty B §4, variant A). Otvorené pre audit: stačí whitelist + default, alebo treba
  zvýšiť STD súboru a doplniť doprednú bránu (dnes STD uložený, ale neporovnávaný — starší plugin na tom istom PC by skaláre pri uložení zahodil)?
- **Rozpočet:** prepínač per zákazka = nový kľúč `BudgetStore` → **`BUDGET_STD` 3** + reťaz R-14 (dôsledok: po prvej mutácii rozpočtu v novom
  plugine starší plugin zákazku v Rozpočte needituje ani nevyexportuje — Luciino PC treba aktualizovať ako pri iných zvýšeniach).
- **Kontrola:** `oversize` s orezom podľa typu materiálu (jedna pravda s plánom). **Bez novej exportnej brány** — odklon od návrhu 6.9. §4
  (RED „plán neúplný" blokujúci cenové exporty): neúplný alebo orientačný plán sa do ceny nedostane nikdy, lebo cena materiálu padne na odhad
  a riadok to povie; nálezy Kontroly dnes exporty nezastavujú (fakty A §5, B §7).
- **STANDARD:** §12 dnes nárezové plány vylučuje z rozsahu v1 → zmeniť; nové pravidlo „kresba platne po `sheet_size[0]`"; kontrakt výsledku plánu.

## 5 · Rezy dávok (návrh)

| Dávka | Obsah | Trieda |
|---|---|---|
| **NP-1 · jadro** | modul plánu (čistý) + kontrakt výsledku + testy; skaláre prerez/orez v `SupplierSettings` + 2 riadky v Nastaveniach rozpočtu; `oversize` s orezom; STANDARD §12 a pravidlo formátu | audit ÁNO (nový modul, kontrakt nastavení) · predrecenzia |
| **NP-2 · sekcia** | Štúdio → Nárezový plán (payload, SVG, detail platne, upozornenie poslednej platne, zoznam nezaradených, výber v modeli); poznámka „plán: N platní" v Rozpočte a XLSX | UI dávka · predrecenzia (nový ovládací prvok) |
| **NP-3 · ceny podľa plánu** | prepínač per zákazka (`BUDGET_STD` 3, R-14), množstvo a porez podľa plánu s pádom na odhad, všetkých 5 volajúcich | audit ÁNO (schéma) · cenová dávka · predrecenzia · in-SU (zápis do modelu) |

Uzáver bloku 2 (minor verzia) hneď po NP-3; blok 2 tým nemá otvorenú položku.

## 6 · Scope OUT

Optimalizácia na minimum odpadu (viac heuristík, hľadanie poradia) · export alebo tlač plánu pre pílu, poradie rezov · ručné presúvanie dielcov ·
sklad a evidencia zvyškov · ABS v pláne · klik priamo do SVG ako výber v 3D (bez precedensu, rešerš Q3 · 4) · polovičné platne.

## 7 · Otázky pre krížový audit

1. Je FFDH s pravidlami §3 korektná a **realizovateľná** horná hranica (gilotínovo rezateľné rozloženie)? Kde môže reálna potreba prekročiť plán
   (hotové rozmery s ABS, prídavky pri duplákoch, prefrézovanie pred olepením, orez PD)?
2. Sedí vstup plánu presne s tým, čo ide do VEPO (filtre riadkov, orientácia, neznámy smer, `cut_size`, duplák, UNI, fallback, PD/KOMPAKT/ZASTENA)?
3. `oversize` s orezom — riziká zmeny existujúceho RED nálezu (kľúče, testy, materiály bez orezu, závislosť Kontroly od globálneho nastavenia)?
4. Odklon „bez novej exportnej brány" — je bezpečný pre peniaze? Kedy by neúplný alebo orientačný plán mohol presiaknuť do ceny, XLSX alebo ponuky?
5. Prerez/orez v `SupplierSettings` — stačí whitelist, alebo STD + dopredná brána? Validácia rozsahov (orez voči najmenšiemu formátu sa dá overiť až pri výpočte).
6. Prepínač per zákazka a `BUDGET_STD` 3 — existuje jednoduchšia cesta bez zvýšenia schémy? Väzba porezu a montáže, 5 volajúcich `budget_payload`.
7. UI: id sekcie (`cut` koliduje s `cut_*` z D-143), ~10 guard testov, veľkosť payloadu rozloženia, kreslenie cez CSS tokeny (dve témy), vertikálny priestor.
8. Je rez NP-1 → NP-2 → NP-3 správny (veľkosť PR, poradie, audit-povinnosť, in-SU brána)?
