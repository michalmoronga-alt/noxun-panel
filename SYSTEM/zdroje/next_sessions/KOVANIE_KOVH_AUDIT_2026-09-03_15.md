# KOV-H — Codex audit návrhu pred implementáciou (3.9.2026, checkpoint #15)

> Stav: KONCEPT / audit checkpoint — nie implementačný spec. Codex CLI task `task-mtk2rx32-zxoqp4` (gpt-5.6-sol, 21 min) nad package KOV-H v PLAN.md + FINAL §9 + mockup scéna 2.
> Verdikt: **4 BLOCKER + 9 FIX + 1 NOTE; rez H1/H2 odporučený.** Všetky blockery rozhodnuté orchestrátorom technicky (nižšie); package KOV-H1/KOV-H2 v PLAN.md je autorita dávky.

## BLOCKERY + rozhodnutie orchestrátora

1. **Priamy zápis configu bez rebuildu obchádza jediný serializer (`cabinet_config`), ktorý stampuje `config_schema`** — položka by ostala pod schémou 2 a starší rebuild by ju ticho zmazal.
   → **ROZHODNUTÉ: ŽIADNY nový zápisový kanál.** `hardware_manual` je ďalšie pole configu, ktoré panel posiela v `collectAll()` ako `hardware_overrides` → existujúca cesta
   `apply_all` → `normalize` → `rebuild` (1 krok Späť, guardy dokumentu/skrinky, R-12, `push_selected(dedup: false)`) → `cabinet_config` stampuje schému. Cena = prestavba
   geometrie pri pridaní položky (stovky ms) — vedome prijaté; optimalizácia „zápis bez rebuildu" je kandidát do registra, nie súčasť H. Tým padá aj FIX 11.
2. **Snapshot ceny + agregácia podľa kódu = nesprávny rozpočet** (dve ceny na jednom riadku). → **ROZHODNUTÉ:** katalógová ad-hoc položka (`source: 'catalog'`) sa oceňuje
   **ŽIVOU cenou z katalógu** ako každý iný riadok (agregácia podľa kódu ostáva, prepočet cien platí); v configu sa drží len `code` + snapshot `name`/`unit` pre zobrazenie,
   keď kód z katalógu zmizne. **Voľná položka (`source: 'free'`)** má vlastný riadok (kľúč `free:<cabinet_id>:<id>`), cenu a MJ zo snapshotu (`price_eur_vat`, zadané
   používateľom) a nikdy nie je `missing`. Koncept „cena z času pridania" pre katalógové položky ZANIKÁ (nahrádza ho živý katalóg).
3. **R-12 chráni len prestavbu — starší plugin by exportoval schema-3 zákazku BEZ ad-hoc kovania** (neúplný nákup/rozpočet/CP). → **ROZHODNUTÉ:** rozšíriť R-12 o exportnú
   bránu: `Bom.collect` nesie aditívny kľúč `newer_configs` (ID skriniek s `config_schema > CONFIG_SCHEMA`); `ProductionCore.export_blockers` pri neprázdnom zozname zastaví
   **nákupný CSV, rozpočet XLSX a CP XLSX** (hláška menuje skrinky a žiada aktualizáciu pluginu); VEPO sa neblokuje (dielce nezávisia od kovania). Platí všeobecne (aj bez
   ad-hoc položiek) — hardening do H1.
4. **„Vlastník musí existovať" odporuje „položka po zániku vlastníka ostáva ORANGE".** → **ROZHODNUTÉ:** existencia `owner_part_key` sa kontroluje STRIKTNE len pri add/edit
   (server odmietne neexistujúci kľúč v aktuálnom pláne — normalize dostane príznak `strict_owners` z panelovej cesty, nie z rebuildu); `normalize`/rebuild kľúč zachovajú
   nedotknutý; `Bom.collect` spojí položku s vnorenými dielcami a chýbajúceho vlastníka označí `owner_missing: true` → Validation ORANGE „bez vlastníka", položka v nákupe ostáva.

## FIX-IN-KOVH (prijaté; H1 = dáta, H2 = UI)

5. Vlastník „zóna" nemá identitu — H2 modal ponúka len **skrinku (nil), čelá a konkrétne zónové dielce** (police/priečky); logická zóna sa neponúka (bez `owner_zone_id`).
6. `missing` flag ničí snapshot — riešené rozhodnutím 2: voľné položky nikdy `missing`; katalógová položka s kódom mimo katalógu = `catalog_missing: true` (názov/MJ zo snapshotu,
   cena nil → „bez ceny" ORANGE ako dnes), CP riadok sa nepreskočí.
7. `source: 'manual'` koliduje s D-93 — ad-hoc kanál nesie **`origin: 'adhoc'`** na riadku aj zdroji; nikdy nejde cez `note_manual`.
8. Rozpočet: riadky prenášajú `origin`; voľné položky (bez kódu) sú mimo stale-scan katalógu (nemajú čo porovnávať); katalógové ad-hoc = bežné riadky.
9. Šablóna cez CEF quick-insert (`NXInsert.HARDWARE_KEYS`, insert-state) musí `hardware_manual` preniesť — JS pass-through BEZ defaultov (vzor A1), súčasť H1.
10. Nové ID položiek LEN pri vzniku novej skrinky: `CabinetBuilder.rekey_hardware_manual` volaný v kopírovacej ceste (`copy` + `dedup_copies`), nikdy v `normalize`/rebuilde
    (normalize len doplní chýbajúce/kolidujúce ID v rámci skrinky).
11. Observer protokol D-100 — riešené rozhodnutím 1 (cesta `apply_all`).
12. `source: 'catalog'` snapshot sa NEVERÍ klientovi: server pri normalizácii katalógovej položky doplní `name`/`unit` z katalógu podľa kódu; klientovi sa verí len kód, množstvo,
    vlastník a poznámka; kód mimo katalógu pri ADD sa odmietne (použi voľnú položku). Pole ceny sa volá **`price_eur_vat`** (len voľné položky).
13. Nákupný CSV **bez nového stĺpca** — pôvod žije v sekcii Nákup Štúdia (rozklik zdrojov, D-94) a v `sources`; CSV pri prázdnom `hardware_manual` bajtovo identický
    (golden test); voľná položka v CSV = riadok s prázdnym kódom a názvom zo snapshotu.

## NOTE

14. Rez **H1 · dátový kontrakt** (config + CONFIG_SCHEMA 3 + R-12 exportná brána + Bom/expanzia/ceny/validácia + šablóny/kópie + JS pass-through + golden + in-SU) /
    **H2 · Inspector UI** (riadok „+ Pridať konkrétnu položku", D-15 modal, chip „ručná", úprava/zmazanie cez apply, zobrazenie pôvodu v Nákupe) — prijaté.
