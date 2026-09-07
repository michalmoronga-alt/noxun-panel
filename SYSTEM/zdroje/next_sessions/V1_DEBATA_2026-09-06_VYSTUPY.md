# V1 debata · bod 6 VÝSTUPY — zvyšok cien (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: zatiaľ nie ·
> rozsah je malý — task package vznikne priamo z tohto checkpointu; **`codex-audit` ÁNO** (Codex #322 kolo 2 P1: `urls[]` je zmena dátového kontraktu katalógov, nie „prípadná").
>
> Pred implementáciou platí postup z [README.md](README.md).

## 0 · Súhrn rozhodnutí (Michal)

| Téma | Rozhodnutie | V1? |
|---|---|---|
| Manuálne overenie ceny na 1 klik | pri položke **bez väzby na Demos** dve akcie: **„cena sedí"** (zapíše dnešný dátum overenia, cena nemenená) a **„zmeniť"** (nová cena + dátum). Klik na URL sám **nič nezapisuje**. | **ÁNO** |
| Viac URL na položke | položka nesie **zoznam odkazov** (obchody sa menia), rýchly preklik; **cena je vždy jedna** | **ÁNO** |
| Prepínač „na faktúru" ×1,2 | **NIE JE POTREBNÝ — vyradiť zo záznamov** (existuje prepínač s DPH / bez DPH) | vyradené |

Tým je zvyšok V1-03 definovaný; bod 6 V1_VIZIA sa odškrtne po implementácii oboch položiek.

## 1 · Rozsah (návrh Fable pre package)

- **Kde:** Štúdio → Materiály (položky bez Demos väzby), Kovanie → katalóg (položky bez Démos väzby), neskôr Spotrebiče (cena žije v rozpočte — tam sa overenie nerobí).
  Vstup = ten istý stavový riadok ceny, ktorý dnes ukazuje `price_checked_at` a vek ceny; „Prepočítať ceny" naďalej preskočí položky bez väzby, ale tie majú vlastné tlačidlá.
- **Dáta:** existujúci `price_checked_at` (žiadne nové pole pre overenie); **zoznam odkazov** = nové pole `urls[]` (existujúca `demos_url` ostáva ako väzba na Demos —
  nezlučovať, väzba ≠ odkaz). Jedna cena, jeden dátum. **Kontrakt (P1):** `urls[]` je **schémová zmena** oboch katalógov — materiály (`SCHEMA_*` bump + `normalize` whitelist
  doplní `urls`: pole reťazcov, len `https`, dedup, strop napr. 10) aj katalóg kovania (`SCHEMA_CURRENT` bump + `assess!`); **dopredná brána** podľa R-11/R-12: starší plugin
  katalóg s vyššou schémou číta **read-only / odmietne zápis**, nikdy `urls` ticho neoreže; migrácia = žiadna (pole chýba = prázdny zoznam). Projektové snapshoty materiálov/kovania
  `urls` nenesú (odkaz nie je výrobný údaj) — potvrdí audit. Pred prvou takou zákazkou obe PC na rovnakej verzii (D-52).
- **Rozpočet / ponuka:** vek ceny ostáva kontextový („N cien starších ako 30 dní"), nič nové.
- **Scope OUT:** DOCX/PDF ponuka (zásobník) · „na faktúru" (vyradené) · automatické sledovanie cien z odkazov (nikdy — Demos fetch ostáva jediná automatika).

## 2 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 6: znenie „ostáva zvyšok V1-03: manuálne 1-klik overenie ceny A viac URL na položke" ponechať; **vyškrtnúť** zmienku o „na faktúru".
- [../../PLAN.md](../../PLAN.md) blok 4 odrážka „Ceny": odstrániť prepínač „na faktúru" (×1,2, štvrtý cenový režim); [../../DOGFOODING.md](../../DOGFOODING.md) skupina V1 DOTIAHNUTIE:
  rovnaká úprava odseku „Vedome odložené z dávky E — ceny".
