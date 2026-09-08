# Zdieľané knižnice (D-48) — návrh mechanizmu Odoslať / Aktualizovať (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (rozhodnutia v [V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md](V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md) §0)
> + Codex #322 kolá 1–3 (nálezy zapracované, §6) · auditované proti kódu: ČIASTOČNE (store-y a ich zámky/brány vymenované z kódu, tvar súborov je návrh) ·
> **implementácia až PO uzávere V1** ako prvá funkcia; task packages SYNC-1..3 vzniknú po `codex-audit` tohto návrhu (nový modul + zápis do všetkých store-ov).
>
> Pred implementáciou platí postup z [README.md](README.md). Nadväzuje na [05_SHARED_LIBRARY_UPDATE.md](05_SHARED_LIBRARY_UPDATE.md) (revízie knižníc, stránka O plugine).

## 0 · Čo je rozhodnuté (Michal) a čo tento návrh dopĺňa

Rozhodnuté: verzie per katalóg · **Odoslať / Aktualizovať naraz** pre všetky store-y · konflikt sa rieši **ručne** výberom verzie · pri štarte plugin len **oznámi** ·
koreň **`H:\Môj disk\NoxunENGINE data`** (firemný Google Disk, zrkadlený na oboch PC) · oba PC smú zapisovať. Tento dokument dopĺňa **mechanizmus**, ktorý to na
Disku (bez zámku a bez atomického CAS) robí bezpečne, a **záväzný zoznam store-ov**.

## 1 · Store-y, ktoré sa synchronizujú (záväzný zoznam — Codex #322 kolo 3 P1)

| Store (súbor v `%APPDATA%\NOXUN\Engine`) | Modul | Zámok / brána dnes | Sync |
|---|---|---|---|
| `materials.json` (+ `.bak`) | `materials*.rb` | `Materials.with_catalog_lock`, `SCHEMA_*`, assess R-11 | áno |
| `hardware_catalog.json` | `hardware_catalog.rb` | `assess!`, `SCHEMA_CURRENT`, `record_rev` | áno |
| knižnica setov kovania (`hardware_sets*.json`, std) | `hardware_sets.rb` | `assess_library_doc`, std 3 | áno |
| `hardware_taxonomy.json` | `hardware_taxonomy.rb` | `assess!`, flock (R-08 vzor) | áno |
| **`hardware_rules.json`** (globálne defaulty pravidiel kovania) | `hardware_rules.rb` | `rules_rev`, normalizácia | **áno** (produkčné pravidlo) |
| **`abs_rules.json`** (globálne ABS defaulty) | `abs_rules.rb` | normalizácia | **áno** (produkčné pravidlo) |
| **`dim_series.json`** (rozmerové rady) | `dim_series.rb` | — | **áno** (produkčné pravidlo) |
| šablóny (`templates*.json` + náhľady PNG) | `templates.rb`, `template_previews.rb` | `CONFIG_SCHEMA`, `assess_set_defs`, zametanie PNG | áno (JSON + súbory) |
| nastavenia dodávateľa / rozpočtu (`supplier_settings.json`, sadzby, marže) | `supplier_settings.rb`, `budget_store.rb` | revízny zámok | áno |
| spotrebiče (`appliances.json` + priečinky príloh) | S1 (nový) | podľa package S1 | áno (JSON + súbory) |
| vzhľady materiálov (`appearances/*.skm`) | M-R VZHĽAD (nový) | kľúč identity | áno (súbory) |
| `updater_settings.json`, `legacy_cleanup.json`, `usage_stats`, cesty | updater, tools | — | **nie — per PC** |

**Pravidlo:** každý store s **používateľsky editovateľným obsahom, ktorý ovplyvňuje výstupy** (kusovník, ABS, kovanie, ceny), je v zozname; per-PC ostávajú len cesty
a technické markery. **Registry store-ov (SYNC-0, Codex #323 P2):** `JsonFileStore` dnes žiadnu registráciu nemá — každý modul si cestu počíta sám a volá read/write
priamo, takže „guard proti registráciám" by nič neobjavil. Preto najprv **povinný `StoreRegistry`**: každý store sa registruje explicitne (`kľúč`, cesta, **shared / local**,
`current_std` pluginu, `assess_import` hook, zoznam súborových príloh) a `JsonFileStore.read/write` **odmietne neregistrovaný store**; tento zoznam je potom generovaný
z registry (nie udržiavaný ručne) a guard test stráži, že každý modul volajúci `JsonFileStore` je zaregistrovaný.

## 2 · Rozloženie zdieľaného koreňa

```
<root>/library/<store>/
    r0007.michal-pc.3f9a1c2e.json      ← nemenný artefakt publikácie (verzia . PC . uuid), nikdy sa neprepisuje;
                                      vnútri: { std, parent: "r0006.lucia-ntb.…", supersedes: [...], assets: { "<id>": "sha1…" }, data }
                                      (`supersedes` žije V KAŽDOM artefakte — manifest ho len zrkadlí; Codex #323 kolo 2 P1)
    r0007.lucia-ntb.9b02d7aa.json      ← druhý artefakt tej istej verzie = KOLÍZIA (obaja odoslali z r0006)
    r0008.michal-pc.51ee0c4b.json      ← víťaz konfliktu, manifest nesie supersedes: [oba r0007]
    manifest.json                       ← ukazovateľ: { rev: 8, artifact: "r0008.michal-pc.51ee0c4b.json", supersedes: [...], by, at }
    publish.lock                        ← advisory (PC, čas, TTL ~10 min) — pomocný, nie garancia
<root>/library/<store>/files/<sha1>.<ext>  ← prílohy, náhľady, .skm ako OBSAHOVO ADRESOVANÉ súbory (Codex #323 P1): názov = digest obsahu,
                                          nikdy sa neprepisujú; artefakt nesie mapu id → digest, takže každý kandidát konfliktu obnoví PRESNE svoje súbory
<root>/plugin/                          ← distribučný priečinok updatera (D-52) — jeden koreň pre oboje
```

## 3 · Mechanizmus (optimistické verzovanie bez CAS)

- **Pracovná kópia ostáva lokálne** v `%APPDATA%`; každý lokálny store si pamätá **základný artefakt** (`base_artifact` = id, z neho `base_rev`) a či má **lokálne zmeny**
  (hash obsahu vs. hash pri poslednom sync). Každý artefakt nesie **`parent`** (id základného artefaktu, z ktorého publikácia vyšla) — vzniká **lineage** (reťaz predkov).
- **Odoslať (všetky store-y naraz, per store samostatný výsledok):**
  1. prečítať `manifest.json` + **zoznam artefaktov**; ak existuje `publish.lock` cudzieho PC mladší než TTL → počkať / oznámiť;
  2. `manifest.artifact == base_artifact` a bez cudzích artefaktov `r(base_rev+1)` → zapísať artefakt `r(base_rev+1).<pc>.<uuid>.json` (temp + rename; vnútri `std`
     store-u, `parent = base_artifact`, digesty príloh — súbory sa nahrajú **pred** artefaktom), potom `manifest.json` (temp + rename, **posledný** = pečiatka hotovo) s
     zrkadlom `supersedes` artefaktu (bežná publikácia `[]`); lokálne `base_artifact = nový`;
  3. inak **konflikt** (§4).
  Google Disk môže oba zápisy z dvoch PC doručiť krížom — preto artefakty nikdy nezdieľajú názov (**uuid per publikácia** — aj dve inštancie SketchUpu na jednom PC či
  opakovanie po páde pred posunom `base_rev` dostanú nové meno) a manifest je len ukazovateľ.
- **Aktualizovať:** `manifest.artifact != base_artifact` a bez lokálnych zmien → prevzatie artefaktu (so `.bak`) **cez zápisovú cestu store**; s lokálnymi zmenami →
  konflikt (§4). **Dopredná brána je v SYNC vrstve, nie v store-och (Codex #323 P1):** `HardwareRules.write` / `AbsRules.write` prepisujú dokument aktuálnym `std`,
  `DimSeries.set` / `SupplierSettings.write` normalizujú cez uzavretý whitelist bez odmietnutia novšieho `std` — polia z novšieho pluginu by ticho zmizli. Preto sync **pred**
  volaním store porovná `std` v artefakte s `current_std` z registry (§1): novší → **odmietnutie** s hláškou „najprv aktualizuj plugin" (D-52; ten istý koreň), nikdy zápis;
  rovný alebo starší → store API (assess pre poškodené dáta ostáva).
- **Detekcia kolízie — podľa lineage, nie podľa čísla verzie (Codex #322 kolo 3 + #323 kolo 1 P1):** klient prečíta **všetky artefakty** a zostaví **reťaz predkov**
  aktuálneho `manifest.artifact` (cez `parent`) spolu so všetkými id v `supersedes` každého článku reťaze = **pokryté** artefakty. **Každý artefakt mimo pokrytia je nevyriešená
  odbočka = kolízia** — bez ohľadu na verziu a meno PC: dva artefakty tej istej `R` z rôznych publikácií, **aj oneskorený artefakt nižšej verzie** (PC B publikovalo `r0007`,
  Disk ho doručil až po tom, čo PC A z vlastného `r0007` urobilo `r0008` — `r0008` z B nevyšlo ani ho neprekonalo, preto sa B nesmie ticho stratiť). Kolízia je vyriešená až keď
  novšia publikácia uvedie odbočku v **`supersedes` v samom artefakte** (manifest sa prepíše ďalšou bežnou publikáciou — keby `supersedes` žilo len v ňom, vyriešená odbočka by sa
po `r0009` znova hlásila; preto reťaz predkov číta `supersedes` z každého článku). Prekonané (pokryté) artefakty uprace zametanie (necháva posledné N verzií + všetko v `supersedes` aktuálnej reťaze).
- **Štart pluginu:** per store porovná **identitu artefaktov** (`manifest.artifact` vs. `base_artifact`, nie len čísla verzií) **a spustí tú istú detekciu kolízie** (§3 vyššie —
  Codex #323 P1: po súbežnej publikácii môže mať klient `manifest.rev == base_rev` a pritom existujú dva artefakty tej verzie); **oznámi** („Materiály: zdieľaná rev. 43, moja 42 ↑"
  / „Materiály: KOLÍZIA — 2 publikácie rev. 43"); nič nesťahuje. Všetky čítania zo zdieľaného koreňa s **časovým limitom** (vzor updater check: vlákno + deadline; Disk v režime
  „stream" môže zaseknúť).

## 4 · Konflikt (ručne, per store)

Okno: store · kto/kedy zapísal cudzí artefakt · koľko mám lokálnych zmien · pri kolízii všetky kandidátske artefakty (s obnovením ich vlastných súborov podľa digestov).
Výber: **prepísať zdieľaný mojou verziou** alebo **zahodiť moje a prevziať vybraný kandidát** — **obe cesty publikujú `r(R+1)`** s vybraným obsahom a `supersedes:
[všetky konkurenčné artefakty]` (Codex #323 P1: samotné lokálne prevzatie by odbočku nevyriešilo a kolízia by sa hlásila donekonečna) · zrušiť. Nič potichu, žiadne
zlučovanie po záznamoch (verzia = celý store; zlučovanie až keby konflikty boli časté).

## 5 · Riziká

1. Disk doručí dva manifesty krížom → Disk vyrobí konfliktnú kópiu súboru `manifest (1).json`; klient berie **artefakty ako pravdu**, manifest len ako ukazovateľ; cudzie kópie
   manifestu ohlási a ponúkne „obnoviť manifest z artefaktov" — kandidát je jednoznačný **len keď jeho reťaz predkov + `supersedes` pokrýva každý viditeľný artefakt**
(Codex #323 kolo 2 P1: „najvyššia verzia s jediným artefaktom" nestačí — `r0008` z A by skryl oneskorený `r0007` z B); inak konflikt §4.
2. Rozdielne verzie pluginu → brány R-11/R-12 odmietnu novší artefakt → hláška na updater (rovnaký koreň).
3. Rozpísaný súbor počas synchronizácie → temp + rename (existujúci vzor `JsonFileStore`).
4. Zákazka s materiálom, ktorý druhé PC nemá → snapshot na skrinke je autorita, „chýba v katalógu" ako dnes pri kovaní.
5. Disk v režime „stream" → čítania s deadline; odporúčať „zrkadliť".
6. Rast priečinka artefaktov → zametanie prekonaných verzií (necháva posledné N = 5 + všetky v `supersedes` aktuálneho manifestu).

## 6 · Rezy (po V1; audit = `codex-audit` tohto návrhu pred SYNC-1)

| Rez | Obsah | Audit |
|---|---|---|
| **SYNC-0 registry** | `StoreRegistry` (§1): explicitná registrácia každého store (shared / local, `current_std`, `assess_import`, prílohy), `JsonFileStore` odmietne neregistrovaný store, guard test nad volajúcimi modulmi; bez zmeny správania store-ov | **ÁNO** (kontrakt perzistencie) |
| **SYNC-1 jadro** | čistý modul (bez `Sketchup.*`): manifest + artefakty (uuid, `parent`, `std`, digesty príloh), **lineage detekcia** (§3) aj pri štarte, `base_artifact` + lokálne zmeny per store, **dopredná brána v sync vrstve** pred store API každého registrovaného store, konflikt = vždy publikácia `R+1`, advisory lock, čítanie s deadline; headless testy s mutáciami (kolízia z jedného PC, opakovanie po páde, vyriešená kolízia sa nehlási, **oneskorený artefakt nižšej verzie = kolízia**, prevzatie kandidáta publikuje `R+1`, novší `std` odmietnutý PRED store API, kandidát obnoví svoje súbory podľa digestov) | **ÁNO** (nový modul, zápis do všetkých store-ov) |
| **SYNC-2 UI** | O plugine: riadky per store, tlačidlá Odoslať / Aktualizovať, konfliktný modal (D-15), oznámenie pri štarte (asynchrónne s deadline) | NIE (nad kontraktom SYNC-1), in-SU smoke na oboch PC |
| **SYNC-3 súbory** | prílohy spotrebičov, náhľady šablón, `.skm` ako **obsahovo adresované** súbory `files/<sha1>.<ext>` + mapa id → digest v artefakte, migrácia existujúcich (stabilné cesty → digesty), zametanie súborov **dvojfázovo** (Codex #323 kolo 2 P1: Disk doručuje súbory a artefakty v ľubovoľnom poradí a súbory idú
  pred artefaktom, takže „digest bez viditeľného artefaktu" môže byť práve prichádzajúca publikácia): súbor bez odkazu sa najprv **označí** (tombstone so značkou času,
  publikovaný v ďalšom artefakte) a zmaže sa až po **ochrannej lehote** (default 14 dní) a stále bez odkazu; rovnaká lehota platí pre prekonané artefakty | ÁNO (migrácia) |

Smoke na oboch PC s reálnym Diskom: naschvál vyrobená kolízia (obaja odošlú z tej istej verzie) → obaja ju vidia → vyriešenie → **už sa nehlási** · odpojený Disk → hláška, nič
nezamrzne · novší plugin na jednom PC → odmietnutie s odkazom na updater.

## 7 · Nálezy Codex #322 zapracované

#322 kolo 1 P1: Disk nedáva CAS, „prečítaj pred zápisom" nezavrie TOCTOU → nemenné artefakty + manifest posledný · #322 kolo 2 P1: meno PC nestačí → uuid per publikácia ·
#322 kolo 3 P1: vyriešené kolízie sa hlásili donekonečna → `supersedes` · #322 kolo 3 P1: produkčné store-y chýbali → záväzný zoznam §1 · **#323 kolo 1:** štart porovnáva
identitu artefaktov a robí detekciu (P1) · prevzatie kandidáta publikuje `R+1` so `supersedes` (P1) · dopredná brána v sync vrstve pred store API — store-y ju nemajú (P1) ·
oneskorený artefakt nižšej verzie = kolízia → lineage cez `parent` namiesto čísla verzie (P1) · súbory obsahovo adresované s digestmi v artefakte (P1) · `StoreRegistry` ako
SYNC-0, nie guard nad neexistujúcimi registráciami (P2) · **#323 kolo 2 P1:** `supersedes` v každom artefakte, manifest len zrkadlí · rekonštrukcia manifestu cez pokrytie
lineage, nie „najvyššia verzia" · zametanie súborov dvojfázovo s ochrannou lehotou (súbory idú pred artefaktom, Disk mimo poradia).
