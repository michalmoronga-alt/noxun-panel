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
a technické markery. Nový store v budúcnosti = nový riadok tu (guard test: zoznam store-ov sync vs. `JsonFileStore` registrácie).

## 2 · Rozloženie zdieľaného koreňa

```
<root>/library/<store>/
    r0007.michal-pc.3f9a1c2e.json      ← nemenný artefakt publikácie (verzia . PC . uuid), nikdy sa neprepisuje
    r0007.lucia-ntb.9b02d7aa.json      ← druhý artefakt tej istej verzie = KOLÍZIA (obaja odoslali z r0006)
    r0008.michal-pc.51ee0c4b.json      ← víťaz konfliktu, manifest nesie supersedes: [oba r0007]
    manifest.json                       ← ukazovateľ: { rev: 8, artifact: "r0008.michal-pc.51ee0c4b.json", supersedes: [...], by, at }
    publish.lock                        ← advisory (PC, čas, TTL ~10 min) — pomocný, nie garancia
<root>/library/<store>/files/<id>/…    ← prílohy, náhľady, .skm (názvy podľa id, nikdy podľa názvu produktu)
<root>/plugin/                          ← distribučný priečinok updatera (D-52) — jeden koreň pre oboje
```

## 3 · Mechanizmus (optimistické verzovanie bez CAS)

- **Pracovná kópia ostáva lokálne** v `%APPDATA%`; každý lokálny store si pamätá **základnú verziu** (`base_rev` + id artefaktu, z ktorého vznikol) a či má **lokálne zmeny**
  (hash obsahu vs. hash pri poslednom sync).
- **Odoslať (všetky store-y naraz, per store samostatný výsledok):**
  1. prečítať `manifest.json` + **zoznam artefaktov**; ak existuje `publish.lock` cudzieho PC mladší než TTL → počkať / oznámiť;
  2. `manifest.rev == base_rev` a bez cudzích artefaktov `r(base_rev+1)` → zapísať artefakt `r(base_rev+1).<pc>.<uuid>.json` (temp + rename), potom `manifest.json`
     (temp + rename, **posledný** = pečiatka hotovo) s `supersedes: []`; lokálne `base_rev = rev+1`;
  3. inak **konflikt** (§4).
  Google Disk môže oba zápisy z dvoch PC doručiť krížom — preto artefakty nikdy nezdieľajú názov (**uuid per publikácia** — aj dve inštancie SketchUpu na jednom PC či
  opakovanie po páde pred posunom `base_rev` dostanú nové meno) a manifest je len ukazovateľ.
- **Aktualizovať:** `manifest.rev > base_rev` a bez lokálnych zmien → prevzatie artefaktu (so `.bak`) **cez zápisovú cestu store** (assess, brány std/schema — nikdy kópia
  súboru); s lokálnymi zmenami → konflikt (§4). Artefakt z novšieho pluginu → odmietnutie s hláškou „najprv aktualizuj plugin" (D-52; ten istý koreň).
- **Detekcia kolízie — len nad najvyššou neprekonanou verziou (Codex #322 kolo 3 P1):** klient vezme `R = max(rev artefaktov)`; ak pre `R` existujú **≥ 2 artefakty**
  (bez ohľadu na meno PC), je to kolízia; ak `manifest.rev == R` a `manifest.artifact` je jeden z nich a **ostatné sú v `manifest.supersedes`** (alebo v `supersedes` niektorej
  vyššej verzie), kolízia je **vyriešená** a nehlási sa. Artefakty verzií `< manifest.rev` sú **prekonané** a ignorujú sa (uprace ich zametanie, ktoré necháva posledné N verzií).
- **Štart pluginu:** porovná `manifest.rev` vs. `base_rev` per store a **oznámi** („Materiály: zdieľaná rev. 43, moja 42 ↑"); nič nesťahuje. Všetky čítania zo zdieľaného
  koreňa s **časovým limitom** (vzor updater check: vlákno + deadline; Disk v režime „stream" môže zaseknúť).

## 4 · Konflikt (ručne, per store)

Okno: store · kto/kedy zapísal cudzí artefakt · koľko mám lokálnych zmien · pri kolízii oba artefakty. Výber: **prepísať zdieľaný mojou verziou** (publikuje `r(R+1)` s
`supersedes: [všetky artefakty R]`) · **zahodiť moje zmeny a prevziať** (cudzí artefakt cez store API; pri kolízii vybrať ktorý) · zrušiť. Nič potichu, žiadne zlučovanie
po záznamoch (verzia = celý store; zlučovanie až keby konflikty boli časté).

## 5 · Riziká

1. Disk doručí dva manifesty krížom → Disk vyrobí konfliktnú kópiu súboru `manifest (1).json`; klient berie **artefakty ako pravdu**, manifest len ako ukazovateľ; cudzie kópie
   manifestu ohlási a ponúkne „obnoviť manifest z artefaktov" (víťaz = najvyššia verzia s jediným artefaktom, inak konflikt §4).
2. Rozdielne verzie pluginu → brány R-11/R-12 odmietnu novší artefakt → hláška na updater (rovnaký koreň).
3. Rozpísaný súbor počas synchronizácie → temp + rename (existujúci vzor `JsonFileStore`).
4. Zákazka s materiálom, ktorý druhé PC nemá → snapshot na skrinke je autorita, „chýba v katalógu" ako dnes pri kovaní.
5. Disk v režime „stream" → čítania s deadline; odporúčať „zrkadliť".
6. Rast priečinka artefaktov → zametanie prekonaných verzií (necháva posledné N = 5 + všetky v `supersedes` aktuálneho manifestu).

## 6 · Rezy (po V1; audit = `codex-audit` tohto návrhu pred SYNC-1)

| Rez | Obsah | Audit |
|---|---|---|
| **SYNC-1 jadro** | čistý modul (bez `Sketchup.*`): manifest + artefakty (uuid), detekcia kolízie nad najvyššou verziou + `supersedes`, `base_rev` + lokálne zmeny per store, Odoslať/Aktualizovať cez store API každého z 11 store-ov (§1), advisory lock, čítanie s deadline; headless testy s mutáciami (kolízia z jedného PC, opakovanie po páde, prekonaná kolízia sa nehlási, novší plugin odmietnutý) | **ÁNO** (nový modul, zápis do všetkých store-ov) |
| **SYNC-2 UI** | O plugine: riadky per store, tlačidlá Odoslať / Aktualizovať, konfliktný modal (D-15), oznámenie pri štarte (asynchrónne s deadline) | NIE (nad kontraktom SYNC-1), in-SU smoke na oboch PC |
| **SYNC-3 súbory** | prílohy spotrebičov, náhľady šablón, `.skm` do `<root>/library/<store>/files/`, relatívne cesty, migrácia existujúcich, zametanie sirôt | ÁNO (migrácia) |

Smoke na oboch PC s reálnym Diskom: naschvál vyrobená kolízia (obaja odošlú z tej istej verzie) → obaja ju vidia → vyriešenie → **už sa nehlási** · odpojený Disk → hláška, nič
nezamrzne · novší plugin na jednom PC → odmietnutie s odkazom na updater.

## 7 · Nálezy Codex #322 zapracované

kolo 1 P1: Disk nedáva CAS, „prečítaj pred zápisom" nezavrie TOCTOU → nemenné artefakty + manifest posledný · kolo 2 P1: meno PC nestačí → uuid per publikácia, detekcia nezávislá
od PC · kolo 3 P1: vyriešené kolízie sa hlásili donekonečna → detekcia len nad najvyššou verziou + `supersedes` v manifeste · kolo 3 P1: produkčné store-y (`hardware_rules`,
`abs_rules`, `dim_series`) chýbali → záväzný zoznam §1 s guardom.
