# PACKAGE H9 · Ochrana nastavení dodávateľa a globálnych pravidiel pred seedom (R-37) — blok 9 HARDENING PO V1

> **PLATÍ (1.10.2026, po Codex audite návrhu: 0 BLOCKER · 3 FIX · 1 NOTE — zapracované, §15):** rozsah sa rozšíril o **`abs_rules` a `hardware_rules`**
> (rozhodnutie orchestrátora k FIX 3 — prídavok je pod hranicou ~120 riadkov kódu, preto **bez rezu H9a/H9b**, §2); `read_valid` číta zálohu **bez ďalšieho
> fallbacku** (FIX 1); chyby predikátu majú **vlastný typ** a sú fail-closed (FIX 2); T0 charakterizuje aj **nárezový plán a ceny podľa plánu** zo súboru (NOTE 4).
> **Delta audit (pôvodné 4 RESOLVED, nové 2 FIX + 1 NOTE — §15.2):** H9 zavádza **`HardwareRules.write_gate`** — jedinú zápisovú bránu globálnych pravidiel kovania,
> ktorú **musí prevziať H10** (R15); T0d charakterizuje **hrany do VEPO a nákup kovania (CSV)** nad vlastnými zdravými súbormi; pri „aj ako globálnu predvoľbu"
> sa odmieta **len globálny súbor** (projekt sa uloží a prestavia) — R14 + T15.

> *(Odkazy počítajú s umiestnením v `SYSTEM/zdroje/bloky/HARDENING/`.)*
> **Autorita:** [AUDIT_REGISTER.md](../../../AUDIT_REGISTER.md) **R-37** (+ súvisiace **R-11** degraded `.bak`, **R-07** `assess_library_doc`, **R-08**/1b-6c zámok,
> NP-2/NP-4 pôvod a `repaired`) · [PREVIERKA_REGISTRA_2026-09-29.md](../../PREVIERKA_REGISTRA_2026-09-29.md) §1–2 · PLAN blok 9, riadok **H9** ·
> `ROZHODNUTIA_MICHALA_2026-10-01.md` (R-37 po V1 → H9) · surový audit `AUDIT_H9_raw.md`. Cieľ bloku: **pri zdravom súbore sa výrobné ani cenové čísla nemenia.**
> **Trieda:** **audit-povinná** (kontrakt čítania a zápisu troch perzistentných súborov + zdieľané primitívum `JsonFileStore`) · **výrobná/cenová — áno**
> (len pri poškodenom súbore mení zdroj sadzieb, prerezu/orezu, pravidiel ABS hrán a pravidiel kovania: záloha namiesto seedu) · **slepá predrecenzia povinná** ·
> **in-SU nie je brána** (§8) · **schéma sa NEMENÍ** (`STD` všetkých troch súborov bez zmeny) · `codex-po-pr` bez výnimky.
> **Verzia:** patch +1 od mainu v čase dávky (dnes v0.17.0) + všetky `?v=` + prepis STAV. JS/HTML/CSS sa nemení.
> **Stav kódu:** sonda nad `main` `b2dbb3a7`, po audite zopakovaná nad **`c98f0aa3`** (H1 — len dokumentácia, plugin bajtovo rovnaký). Riadky = stav k nim; orientuj sa podľa mien metód.

---

## 0 · Sonda pred auditom (skill `codex-audit`, krok 0) — 1.10.2026

Skripty a výstupy v scratchpade `HARDENING/`: `probe_h9.rb` (dnešné správanie), `probe_h9b.rb` (predikát), `proto_h9.rb` → **`proto_h9v2.rb`** (PROTOTYP návrhu
po audite ako monkeypatch po načítaní helpera — nie implementácia), `run_proto_suite.rb`/`run_proto2_suite.rb` (+`*_suite_out.txt`), `probe_h9c.rb`, `probe_h9d.rb`,
`probe_h9e.rb` (po audite; spúšťajú sa raz nad mainom a raz s `PROTO=1`), po delta audite `proto_h9v3.rb` (+ `write_gate`), `probe_h9f.rb`, `probe_h9g.rb`, `probe_h9h.rb`. Všetko headless cez `tests/helper.rb` (APPDATA = sandbox) + `Materials.test_dir_override`;
repo ani `%APPDATA%\NOXUN` sa nedotkli.

| # | Tvrdenie | Príkaz | Výsledok | Súbor:riadok |
|---|---|---|---|---|
| S1 | **R-37 platí.** Dobrá `.bak` (porez 21, orez 12) + primár s vlastnými hodnotami prepísaný na `[]`, `{}`, `{"foo":1}`, `null`, `"text"`, `42` → `load` | `probe_h9.rb` §1 | sadzby a prerez/orez = **seed** (porez 17, orez 10, prerez 5), `source :file`, `state ok` (**žiadny banner**), primár prepísaný seedom, **`.bak` = zlý obsah (zničená)** | `supplier_settings.rb:571-573`, `:556-559`, `:261-266` `read_doc`, `:272-276`; `json_file_store.rb:41,136-143` |
| S2 | Tichá zmena cien **aj bez zápisu** | §1 G, I, J | `suppliers:[]` (s `seed_version` 1), `suppliers:"x"`, `[1,2]` → nič sa nezapíše, ale počíta sa so **seedom**, stav `ok`. `suppliers:[]` bez `seed_version` a `[{}]` → zapíše + zničí `.bak` | `normalize:572-573`, `merge_seed:501` |
| S3 | Platný koreň, zlý typ kontajnera | §2 | `rates:"x"`, bez `rates`, `standard_rows:{}` → auto-zápis + `.bak` zničená. `mode_values:[]` → nezapíše, režimy v pamäti preč. `trim_mm:"abc"` → nezapíše (NP-4). **`rounding_step:"abc"` + chýbajúci `olep` → zapíše** | `read_doc:264`, `repaired_scalars:628-635`, `layout_repaired:639-642` |
| S4 | Nečitateľný JSON (R-11) funguje | §1 L | `:backup`, `degraded`, nič sa nezapíše | `degraded_write_blocked?:429-441`, `refine_origin:304-309` |
| S5 | Bez zálohy | §1b | `[]`/`{}`/`null` → seed + auto-zápis, stav `ok` — bez priznania | ako S1 |
| S6 | Uloženie z UI nad `[]` s dobrou `.bak` | §3 | `[true, [], :ok]`, **`.bak` zničená** | `patch_active_locked!:766,892` |
| S7 | `degraded?` dieru nechytá | §5 | `degraded?([])` = false | `json_file_store.rb:91-107` |
| S8 | **Previerka „ostatné stores pri načítaní nezapisujú" — NEPLATÍ celá** | `probe_h9.rb` §4, `probe_h9e.rb` | koreňovo zlý tvar (`[]`, `{}`, `{"std":1,"rules":"x"}`) pri načítaní nezapíše, **ale ticho počíta so seedom** (ABS 27 rolí namiesto zálohy, kovanie 13 seed pravidiel namiesto 5 vlastných) a **uloženie z okna `.bak` zničí**. **`abs_rules` `{"rules":{}}` a `hardware_rules` `{"rules":[]}` bez `seed_version` zapíšu už pri načítaní a `.bak` zničia.** `dim_series.get` nezapisuje nikdy | `abs_rules.rb:243-250,257-266`; `hardware_rules.rb:521-530,568-575`; `dim_series.rb:105` |
| S9 | Novší formát | §2 T | `{"std":3,…}` bez `suppliers` → `:newer_file`, nič sa nezapíše — predikát novší formát posudzovať nesmie | `doc_std_unsupported?:367-369`; `hardware_rules.rb` `doc_std_unsupported?` |
| S10 | Vzor `assess_library_doc` + precedens | čítanie | čistá funkcia nad dokumentom, degraded vo vrstve nad ňou; lokálny precedens „zlý tvar = poškodený": `TemplateStore.migration_source`/`library_doc` (KON-D) | `hardware_sets.rb:1187,1220,1243`; `templates.rb:523-538` |
| S11 | Zámok (1b-6c / R-08) | čítanie | `with_catalog_lock` → `Materials.with_catalog_lock` (sidecar `materials.lock`, reentrantný, `flock` false → `IOError`); `write` = zámok → degraded → (newer) → zápis; poradie stráži R-11 guard | `materials.rb:503-529`; `supplier_settings.rb:407-417`; `abs_rules.rb:344-356`; `hardware_rules.rb:684-695`; `test_r11…:452` |
| S12 | Historické tvary | `git show bf7b6f13` + `probe_h9b.rb` + `git log -S` | dodávateľ: každý zápis od E-a má `suppliers` ≥ 1 Hash s 5 sadzbami; fixtúry `v1_doc`/`v2_doc` bez `standard_rows`/`mode_values`; testy NP-2 aj NP-4 B3 používajú `standard_rows: []` ako legitímny spúšťač seed-merge. **ABS:** `seed_version` sa pečiatkuje od 18.7.2026 (`183da098`), v0.3 (16.7.) ho nemala — ale s neprázdnymi pravidlami. **Kovanie:** pečiatkuje od vzniku (`67cec8b9`) | `test_np2…:73,233`; `test_np4_ceny.rb:132,503` |
| S13 | Ruby 3 pasca | prototyp v1 s `write(path, payload, shape: nil)` | **94 testov padlo** — bezzátvorkový hash s reťazcovými kľúčmi ide do kľúčových argumentov → `ArgumentError` → tichý neúspešný zápis (`dim_series.rb:140`, `updater.rb:839`, `main.rb:114`, `legacy_cleanup.rb:122`, `sitemap_cache.rb:95`, `materials_catalog.rb:1105,1185`) | → R1e pozičný parameter |
| S14 | **FIX 1 potvrdený** | `probe_h9d.rb` | primár `[]` + nečitateľná `.bak` + zdravá `.bak.bak` (porez 99): `read(".bak")` s dnešným fallbackom vráti **obsah `.bak.bak`**. Prototyp v2 (čítanie zálohy bez fallbacku) → `InvalidShape` → `:seed_fallback`/`fallback`, `.bak.bak` sa nikdy nepoužije | `json_file_store.rb:126-134` |
| S15 | **FIX 2 potvrdený a uzavretý** | `probe_h9d.rb` `PROTO=1` | predikát vyhodí `RuntimeError`, `JSON::ParserError`, `Errno::ENOENT`, `Errno::EACCES`, `NoMethodError` → `load` = **`:unreadable`** (Uložiť vypnuté), `patch_active!` false, priamy `JsonFileStore.write` → `ShapeCheckError`, primár aj `.bak` bajtovo nedotknuté | `read_failure_origin:248-250` |
| S16 | **FIX 3 nad prototypom v2** | `probe_h9e.rb` `PROTO=1` | ABS aj kovanie, 5 vstupov (`{"rules":{}}`, `{"rules":[]}`, `[]`, `{}`, `{"std":1,"rules":"x"}`) + dobrá `.bak` → hodnoty **zo zálohy**, pri načítaní sa nič nezapíše, zápis z okna **odmietnutý**, `.bak` nedotknutá. Bez `.bak` → seed v pamäti, **žiadny zápis**. Legitímne prázdne pravidlá s `seed_version` (`{"seed_version":…,"rules":{}}`, kovanie `{"std":3,"seed_version":7,"rules":[]}`) = zdravé, zápis povolený | `proto_h9v2.rb` |
| S17 | **Prototyp v2 nerozbije nič** | `run_proto2_suite.rb` | celá headless sada nad `c98f0aa3` **4911 testov / 0 zlyhaní** s prototypom aj bez neho (vrátane `test_kova_golden`, `test_kovh_golden`, 9 ABS sád, `test_np4_golden`, `test_ceny_m2_golden`) — **bez zmeny testov a fixtúr** | `proto2_suite_out.txt`, `base2_suite_out.txt` |
| S18 | Matica dodávateľa nad prototypom | `probe_h9c.rb` | zlý tvar (9 vstupov) + dobrá `.bak` → záloha, `degraded`, súbory bajtovo nedotknuté aj po pokuse o uloženie; bez `.bak` → `fallback` + Kontrola `seed_fallback`, načítanie nič nezapíše, uloženie opraví; zmazanie primára → `:file`; zdravý súbor bajtovo nedotknutý; novší → `newer`; `rounding:"abc"` + chýbajúci `olep` → nezapíše | `proto_h9.rb` |
| S19 | UI stavy existujú | čítanie | `settings_state` `ok|degraded|newer|fallback|unreadable`; JS blokuje `degraded/newer/unreadable`; Kontrola ORANGE pre `seed_fallback`/`unreadable`; pri `:backup` nič (R-11). ABS a kovanie: degraded len konzola + `write_block_reason` v okne Pravidlá | `supplier_settings.rb:341-349`; `studio_settings.js:650-670`; `validation.rb:620-633`; `materials.md` § `abs_rules.rb` |
| S20 | Parsovanie skalárov | `probe_h9b.rb` | `JSON.parse('null')` = `nil` (json 2.6.3, Ruby 3.2.11). **SketchUp 2026 NEOVERENÉ** — prípadná chyba parsu ide cestou R-11 s rovnakým výsledkom | — |
| S21 | *(delta)* Brána kovania je vlastnosť **súborov**, nie dokumentu | `probe_h9f.rb` (main aj `PROTO=1`) | `hardware_rules.json` = `{"rules":[]}` + dobrá `.bak`: `degraded?(path)` **bez** tvaru = false (main: zápis prejde, záloha sa stratí); **s** tvarom = true → `write` false + veta „Globálne pravidlá kovania sú poškodené…". Dokument, ktorý `read_valid` vráti, je obsah **zálohy** — z neho sa degradácia zistiť nedá | `hardware_rules.rb:684-745` |
| S22 | *(delta)* Vlastný zdravý `hardware_rules.json` mení výstup | `probe_h9f.rb` | spodná skrinka, dvojkrídlové dvierka: kovanie zo seedu 4 položky, s vlastným súborom (vypnuté pánty) 2 položky — charakterizácia nad vlastným súborom má zmysel | `construction.rb:115,216` (`hardware_rules || HardwareRules.load`) |
| S23 | *(delta)* ABS headless | `probe_h9g.rb` | so sandboxovým seed katalógom **bez ABS pre dekor** vráti `AbsRules.resolve_edges` pre každú rolu `nil` hrany — vlastné pravidlo sa vôbec neprejaví. T0d preto potrebuje katalóg s ABS pre zvolený dekor a **predpoklad „vlastný súbor mení výstup oproti seedu"** | `abs_rules.rb:392`; `cabinet_builder.rb:1426` |
| S25 | *(delta)* `write_gate` (R15) v prototype **`proto_h9v3.rb`** | `run_proto3_suite.rb`, `probe_h9h.rb` | celá headless sada **4911 / 0** bez zmeny testov; parita brána ↔ `write` + `write_block_reason` sedí v 6 stavoch (zdravý · zlý tvar + `.bak` · nečitateľný + `.bak` · novší `std` · zlý tvar bez `.bak` · chýbajúci) | `proto3_suite_out.txt` |
| S24 | *(delta)* Uloženie „aj ako globálnu predvoľbu" | čítanie | `handle_save`: kontroly → `rebuild_many` + `set_project_rules` (projekt uložený, skrinky prestavané, operácia zavretá) → **až potom** `HardwareRules.write(rules)`; pri `false` status „Pravidlá uložené do projektu — <`write_block_reason`> — prestavaných N skriniek" | `rules_dialog.rb:638-660` |

**Opravené tvrdenia oproti zadaniu a registru:** register (R-37, posledná veta) tvrdí, že `abs_rules`, `hardware_rules` a `dim_series` pri načítaní nezapisujú —
**neplatí** pre prázdny kontajner bez `seed_version` (S8); navyše oba súbory pravidiel pri koreňovo zlom tvare **ticho počítajú so seedom** a uloženie z okna zničí
zálohu. R-37 nie je len o zničenej záloze — tichá zmena čísel nastáva aj bez zápisu (S2, S8).

---

## 1 · Cieľ

Poškodený, ale parsovateľný súbor **nastavení dodávateľa, pravidiel ABS hrán alebo globálnych pravidiel kovania** sa už **nikdy ticho nenahradí predvolenými
hodnotami** a **nezničí poslednú dobrú zálohu** — ani pri načítaní, ani pri uložení z okna. Keď je súbor rozbitý a záloha dobrá, počíta sa **so zálohou** a zápisy
sú vypnuté (pri nastaveniach dodávateľa existujúci červený banner); keď dobrá záloha nie je, platí dnešné priznané „predvolené" a prvé vedomé uloženie súbor opraví.
Pri zdravom súbore sa nemení nič (ani bajt súboru, ani číslo v Rozpočte, nárezovom pláne, hranách či nákupe kovania).

## 2 · Rez — jedna dávka, **bez rezu H9a/H9b**

Odhad (z prototypu v2, čisté riadky kódu bez komentárov): `json_file_store.rb` ~32 · `supplier_settings.rb` ~19 · `abs_rules.rb` ~19 · `hardware_rules.rb` ~32
(vrátane `write_gate`, R15) → **~100 riadkov kódu** (s komentármi v štýle repa ~220 riadkov diffu), testy ~700 riadkov (+ golden fixtúra T0d), dokumentácia
4 odseky. Pod hranicou orchestrátora ~120 riadkov kódu → ABS a kovanie idú do H9. **Poistka:** ak implementácia prekročí ~120 riadkov kódu pluginu (bez komentárov, testov a dokumentácie), implementátor sa zastaví a
orchestrátor aktivuje rez **H9a** (`JsonFileStore` + `supplier_settings`) → **H9b** (`abs_rules` + `hardware_rules`); uzáver H9a potom ochranu ABS/kovania netvrdí.

## 3 · Scope IN

1. `JsonFileStore`: voliteľný predikát tvaru v `json_state`/`degraded?`, `read(…, fallback:)`, nové `read_valid`, typy `InvalidShape` a `ShapeCheckError`,
   pozičný parameter `write` + ochrana zálohy (R1).
2. `SupplierSettings`: predikát (R2), čítanie (R3), pôvod a brána (R4, R5), NP-4 na všetky skaláre (R6).
3. `AbsRules` a `HardwareRules`: predikát, čítanie cez `read_valid`, brána zápisu a ochrana zálohy s predikátom (R12, R13); **`HardwareRules.write_gate`** —
   jediná zápisová brána globálnych pravidiel kovania, autorita aj pre H10 (R15).
4. Testy (charakterizácia pred zásahom vrátane plánu, matice, mutácie), architektúra, STANDARD §11.5, register R-37 ✅ + oprava tvrdenia.

## 4 · Scope OUT

`vepo_settings.json` (R-38 → H7) · `dim_series` (pri načítaní nezapisuje; strata zálohy pri uložení z panela nad zlým tvarom → §14 N6) · knižnica setov
`hardware_sets` (má vlastnú maticu R-07) · hodnotové poškodenie sadzieb (§14 N2) · chýbajúca dopredná brána `std` v `abs_rules` (§14 N1) · nové UI stavy,
texty, ovládacie prvky, JS · „Obnoviť zo zálohy" (Q2) · ORANGE v Kontrole pri čítaní zo zálohy (Q1) · `TemplateStore` KON-D na spoločné primitívum (§14 N5) ·
zmena `STD`, migrácia · R-35 (H10).

## 5 · Trieda dávky — zdôvodnenie

- **Audit-povinná: ÁNO** — kontrakt `load`/`write` troch perzistentných súborov a API zdieľaného `JsonFileStore` (~20 volajúcich). Nie zmena schémy (`STD`
  bez zmeny, súbory sa zapisujú bajtovo rovnako), nie nový modul.
- **Výrobná/cenová: ÁNO.** Pri zdravom súbore nemení nič (T0, golden). Pri poškodenom súbore mení zdroj **sadzieb a prerezu/orezu** (Rozpočet, plán) aj
  **pravidiel ABS hrán** (hrany v kusovníku a VEPO) a **pravidiel kovania** (nákup) — záloha namiesto seedu.
- **Predrecenzia: povinná. In-SU: nie** (§8). Golden `test_np4_golden`, `test_ceny_m2_golden` (berú `seed_supplier`), `test_kova_golden`, `test_kovh_golden`
  ostávajú zelené bez zmeny fixtúr, ale cestu cez súbor dokazuje T0.

## 6 · Požiadavky

### R1 · `JsonFileStore` — voliteľný predikát tvaru (spoločné primitívum; prevezme H7)

- **R1a Dva typy chýb.** `InvalidShape < JSON::ParserError` = dokument sa parsuje, ale nemá očakávaný tvar (správa sa ako poškodený obsah → zapisovateľný
  fallback). `ShapeCheckError < StandardError` (**nie** `ParserError`, **nie** `SystemCallError`) = zlyhal **predikát** — o súbore nehovorí nič.
- **R1b `shape_ok?(shape, doc)`** — jediné miesto, kde sa predikát volá: vráti `true/false`; **akákoľvek** výnimka predikátu (aj `JSON::ParserError`,
  `Errno::ENOENT`) sa zabalí do `ShapeCheckError` a vyletí (FIX 2).
- **R1c `json_state(path, shape: nil)`**: parsovanie v bloku s rescue **len** `JSON::ParserError` → `:corrupt` a `Errno::ENOENT` → `:missing`; predikát sa volá
  **mimo** tohto bloku (cez `shape_ok?`), `false` → `:corrupt`. Žiadne `rescue StandardError` (R-11 guard `test_r11…:473`).
- **R1d `degraded?(path, shape: nil)`** = primár `:corrupt` (s tvarom) ∧ `.bak` `:ok` (s tvarom). Z disku, bez cache, bez rescue (R-11 kontrakt).
- **R1e `read(path, copy: true, fallback: true)`** — `fallback: false` číta súbor **bez** ďalšej zálohy (cache pod vlastným kľúčom). `read` už kľúčový parameter
  má, prídavok je bezpečný. **`write(path, payload, shape = nil)` — parameter POZIČNÝ, nikdy kľúčový** (S13); `write` invaliduje cache primára **aj `.bak`**.
- **R1f `read_valid(path, shape:, copy: true)`** = `v = read(path, copy:)` (dnešný fallback pri nečitateľnom primári ostáva); ak `shape_ok?` → `v`; inak ak `.bak`
  existuje → `read(bak, copy:, fallback: false)` — **bez ďalšieho fallbacku** (FIX 1; `JSON::ParserError`/`Errno::ENOENT` zálohy = záloha nepoužiteľná) a ak
  prejde tvarom → záloha; inak **`raise InvalidShape`**. Iné I/O chyby a `ShapeCheckError` prebublajú. Nezapisuje, **neloguje**.
- **R1g `preserve_valid_backup(path, shape = nil)`**: keď sa primár parsuje, **neprejde** tvarom a `.bak` tvarom **prejde** → `.bak` sa nemení (rozšírenie invariantu
  „poškodený primár nesmie prepísať poslednú platnú zálohu"); inak ako dnes. `ShapeCheckError` sa tu nechytá → zápis zlyhá pred `rename` (súbory nedotknuté).
- **R1h** Bez predikátu je správanie všetkých metód **bajtovo rovnaké** ako dnes.

### R2 · `SupplierSettings.doc_shape_ok?(doc)` — očakávaný tvar

`true` práve vtedy, keď: (1) `doc` je Hash, **a** (2) `doc_std_unsupported?(doc)` → **true hneď** (novší formát posudzuje NP-2), **inak** (3) `suppliers` je
**neprázdne** Array a každý prvok je Hash s **`rates` ako neprázdnym Hash**, **a** (4) `standard_rows`, ak kľúč existuje, je Array (aj prázdne — S12), `mode_values`,
ak existuje, je Hash. Chýbajúce skaláre, `std`, `seed_version`, `active`, `id`, `name`, `standard_rows`, `mode_values` = legacy, dovolené. Čísla posudzuje NP-4.

### R3 · Čítanie dodávateľa

`read_doc` cez `JsonFileStore.read_valid(path, shape: <predikát>, copy: true)`. `disk_std` a `newer_write_blocked?` ostávajú na **surovom** `read` (verzia primára).

### R4 · Pôvod a stav (bez nového stavu, bez zmeny JS a textov)

`InvalidShape` → `read_failure_origin` → **`:seed_fallback`** (dedí z `ParserError`). `ShapeCheckError` → **`:unreadable`** (Uložiť vypnuté — fail-closed).
`degraded_now?` aj `degraded_write_blocked?` volajú `degraded?(path, shape: …)` → zlý tvar + dobrá `.bak` = `:backup`/`degraded`. Texty `degraded_reason`
a `FALLBACK_REASON` sedia bez úpravy.

### R5 · Zápis dodávateľa

`JsonFileStore.write(path, normalize(doc).merge('std' => STD), <predikát>)`; poradie zámok → degraded (s tvarom) → newer → zápis nezmenené.

### R6 · NP-4 brána auto-zápisu na všetky opravené skaláre

`read_doc` nezapíše seed-merge, keď **ktorýkoľvek** dodávateľ má neprázdne `repaired_scalars` (dnes len prerez/orez/prídavok). UI zvýrazňuje všetkých 8 skalárov.

### R7 · Matica dodávateľa (záväzná, T1–T5)

| Stav súboru | Rozpočet a plán počítajú | Banner | Kontrola | Zápis pri načítaní | „Uložiť" | `.bak` |
|---|---|---|---|---|---|---|
| zdravý | súbor | — | — | aditívny seed-merge ako dnes | áno | ako dnes |
| zlý tvar + `.bak` dobrého tvaru | **záloha** | `degraded` | nič (ako R-11) | **nie** | **vypnuté** | **nedotknutá** |
| zlý tvar, `.bak` chýba / zlá / nečitateľná | predvolené | `fallback` | ORANGE `seed_fallback`, plán „orientačne" | **nie** | áno → oprava | dostane zlý primár |
| predikát vyhodí | predvolené | `unreadable` | ORANGE `unreadable` | nie | vypnuté | nedotknutá |
| nečitateľný JSON (R-11) · novší `std` | bez zmeny | bez zmeny | bez zmeny | bez zmeny | bez zmeny | bez zmeny |

Obnova (dnešná R-11 cesta): **zmazať primár** → číta sa `.bak` (stav pred posledným uložením), zápisy povolené.

### R8 · Log

Len pri **zmene** stavu. `read_valid` nič neloguje. V `abs_rules`/`hardware_rules` sa `InvalidShape` chytí **v `read_rules`** (nie v `rules`/`load_state` rescue,
ktorý loguje pri každom volaní — horúca cesta generovania dielcov) a zaloguje sa raz za zmenu stavu.

### R9 · Lucia / druhé PC

Formát ani `STD` sa nemenia — súbory sú medzi verziami zameniteľné. Starší plugin ochranu nemá → v STAV a smoke **aktualizovať obe PC** (ochrana, nie kompatibilita).

### R10 · Prevzatie v H7

H7 (`vepo_settings.json`, R-38) použije tie isté primitíva s predikátom `->(d) { d.is_a?(Hash) }`. H9 `production_core.rb` **nemení**.

### R11 · Dokumentácia (prepísať odseky na mieste)

`model-a-identita.md` § `json_file_store.rb` (predikát, `InvalidShape`/`ShapeCheckError`, `read_valid`, `fallback:`, pozičný parameter + pasca Ruby 3, invariant
zálohy) · `outputs.md` § `supplier_settings.rb` (R2, R7, R6) · `materials.md` § `abs_rules.rb` a `hardware.md` § `hardware_rules.rb` (R12/R13, matica R14
vrátane priebehu „aj ako globálnu", **R15 `write_gate`** ako jediná zápisová brána a autorita pre H10) ·
`SYSTEM/STANDARD.md` §11.5 jedna odrážka (súbor zlého tvaru = poškodený; záloha, inak predvolené s priznaním; zdravý sa nemení).

### R12 · `AbsRules` (FIX 3)

- **Predikát:** Hash, **a** (`std` > `STD` → true — dopredná brána tu nie je, správanie novšieho súboru sa nemení, §14 N1) **inak** `rules` je Hash **a**
  (neprázdny **alebo** kľúč `seed_version` existuje). Prázdne pravidlá sú platné len v súbore, ktorý zapísal plugin (pečiatka od 18.7.2026, S12).
- `read_rules` cez `read_valid(path, shape:, copy: false)`; `rescue InvalidShape` → `[seed, nil, false]` (nič sa nezapíše) + log raz. `degraded_write_blocked?`
  → `degraded?(path, shape:)`; `write` → `JsonFileStore.write(…, <predikát>)`. `persist_seed_merge!` (čítanie po úspešnom zápise) bez zmeny.

### R13 · `HardwareRules` (FIX 3)

- **Predikát:** Hash, **a** (`doc_std_unsupported?` → true) **inak** `rules` je Array **a** (neprázdne **alebo** `seed_version` existuje — vymazanie všetkých
  pravidiel v okne je legitímne, pečiatka je od vzniku modulu).
- `read_rules` cez `read_valid`; `rescue InvalidShape` → `[seed, false, false]` + log raz. `library_std_unsupported?`, `library_doc_std`, `library_seed_version`
  čítajú **tým istým** pomocníkom (`read_valid`, ich dnešné rescue fallbacky ostávajú) — inak by pri zlom primári hlásili iný stav než pravidlá, ktoré sa
  naozaj použijú. Zápisová brána = **R15** (`write_gate`); `JsonFileStore.write(…, <predikát>)` ako R12.

### R14 · Matica ABS a kovania (záväzná, T13, T15)

| Stav `abs_rules.json` / `hardware_rules.json` | Pravidlá pri stavbe a nákupe | Zápis pri načítaní | Zápis do **globálneho súboru** | `.bak` |
|---|---|---|---|---|
| zdravý (aj legitímne prázdne s `seed_version`) | súbor | aditívny seed-merge ako dnes | áno | ako dnes |
| zlý tvar (`[]`, `{}`, nesprávny typ `rules`, prázdne bez `seed_version`) + dobrá `.bak` | **záloha** | **nie** | **odmietnutý** (`write` false + `write_block_reason`) | **nedotknutá** |
| zlý tvar bez dobrej `.bak` | seed (ako dnes pri koreňovo zlom tvare) | **nie** (dnes pri prázdnom bez `seed_version` áno) | áno → oprava | dostane zlý primár |

**Uloženie v sekcii Pravidlá (NOTE 3 delta auditu, S24):** odmietnutie sa týka **výhradne globálneho súboru**. Pri uložení **len do projektu** sa nič nemení. Pri
**„aj ako globálnu predvoľbu"** nad degradovaným `hardware_rules.json` prebehne najprv **ako dnes** zápis do projektu: snapshot pravidiel v modeli, prestavba
skriniek zákazky, jeden krok Späť — a **až potom** sa odmietne globálny zápis; status „Pravidlá uložené do projektu — Globálne pravidlá kovania sú poškodené — číta sa
záloha, zápisy sú vypnuté (oprav alebo zmaž súbor …) — prestavaných N skriniek". Globálny primár aj `.bak` ostanú bajtovo nedotknuté. H9 kód okna **nemení**
(H10 R1.4 riadok 2 na tomto priebehu stavia).

### R15 · `HardwareRules.write_gate` — jediná zápisová brána globálnych pravidiel kovania (autorita pre H9 aj H10; delta FIX 1)

- **Signatúra:** `HardwareRules.write_gate → [state, reason]`, `state ∈ :ok | :degraded | :newer` (Symbol), `reason` = String (`''` pri `:ok`). Bez parametrov.
- **Vždy čerstvá, nad súbormi (nie nad dokumentom):** (0) `JsonFileStore.reload!(path)`; (1) **`:degraded`** ⇔ `JsonFileStore.degraded?(path, shape: <predikát R13>)`
  — primár nečitateľný **alebo zlého tvaru** a `.bak` čitateľná a dobrého tvaru (číta disk, bez cache); (2) inak **`:newer`** ⇔ `doc_std_unsupported?` nad
  **surovým primárom** `JsonFileStore.read(path, copy: false)` po `reload!` (chyba čítania primára = nie novší, ako dnes); (3) inak **`:ok`**. Poradie je záväzné.
- **`reason`:** presne dnešné vety — `:degraded` → „Globálne pravidlá kovania sú poškodené — číta sa záloha, zápisy sú vypnuté (oprav alebo zmaž súbor …)",
  `:newer` → `std_block_reason('Globálna knižnica')`.
- **Výnimky sa NEchytajú** (I/O z `degraded?`, `JsonFileStore::ShapeCheckError`) — rozhoduje volajúci: `write` → `false` (fail-closed, ako dnes), H10
  `library_check` → `:unreadable`. Funkcia nezapisuje, neloguje a nesiaha na model.
- **`write`:** pod `with_catalog_lock` rozhoduje **výhradne** `write_gate`: `degraded_write_blocked?` ≡ `write_gate.first == :degraded`,
  `newer_write_blocked?` ≡ `write_gate.first == :newer` (mená ostávajú — R-11 štrukturálny guard bez úpravy; každá si bránu vyhodnotí sama, zápisová cesta nie je
  horúca); nastavenie `@write_block_reason` a log pri zmene stavu ako dnes. Iná cesta k rozhodnutiu „smiem zapísať globálny súbor pravidiel" nesmie existovať.
- **Zakázané** (pre H9 aj H10): rozhodovať o zápise **len z prečítaného dokumentu** (napr. čistá `write_gate_reason(doc)`) — dokument z `read_valid` je pri
  degradácii obsah **zálohy** a degradáciu neprezradí (S21).
- **Predkontrola mimo zámku** (H10 `library_check`) smie bránu volať bez zámku (len číta); pred **zápisom** ju vždy znova vyhodnotí `write` pod zámkom.

## 7 · Testy a DoD

Nová sada **`tests/pure/test_r37_tvar_suborov.rb`** (štruktúra `test_r11_degradovana_zaloha.rb`, sandbox `Materials.test_dir_override`, headless).

- **T0 Charakterizácia — commit PRED zásahom, zelený na maine aj po:**
  - **T0a dodávateľ:** zdravý vlastný súbor (patch všetkých 5 sadzieb, 8 skalárov vrátane prerez 4 / orez 15 / prídavok 8, riadok, režim) → `active`,
    `layout_params`, `settings_state`, `revision` = očakávania; po `load` bajty primára aj `.bak` nezmenené. Legacy formát 1 (tvar E-a) → doplní 5/10/10 a zapíše
    ako dnes. Fixtúry `v1_doc`/`v2_doc` → ako dnes.
  - **T0b plán a ceny podľa plánu (NOTE 4):** nad `NxNp4Golden.mixed_rows`/`SHEETS` (alebo ich kópiou) s parametrami **z `SS.layout_params` po načítaní zdravého
    súboru** (nie `seed_supplier`, nie `params: {}`): `SheetLayout.compute(…, params: lp[:params])` + `params_source`/`params_version_ok`/`params_repaired` presne
    ako `ProductionCore.layout_for`, potom `Budget.compute(…, SS.active, sheet_layout: plan)` s `plan_prices` **vypnutým aj zapnutým**. Overí sa (1) **zhoda** so
    vstupom zostaveným priamo z tých istých hodnôt v pamäti a (2) **pripnuté čísla zachytené na maine v commite T0** (počty platní na materiál, riadok porezu,
    `qty_source` riadkov Materiálu, SPOLU) — po zásahu bez zmeny.
  - **T0c ABS a kovanie — načítanie:** zdravé vlastné `abs_rules.json` (rola s neštandardnými hranami) a `hardware_rules.json` (podmnožina pravidiel), aj
    legitímne prázdne s `seed_version` → `AbsRules.load`/`HardwareRules.load_state` = očakávania, bajty bez zmeny.
  - **T0d ABS a kovanie — výrobné výstupy end-to-end (delta FIX 2):** deterministické **vlastné** (nie seed) zdravé súbory v sandboxe — `abs_rules.json`
    (napr. `side_left`/`side_right` so všetkými hranami 2,0) a `hardware_rules.json` (napr. vypnuté pánty alebo zmenené množstvo). Nad 3 konfiguráciami z
    `NxKovaGolden::CASES` (`door_2wings`, `drawer_fixed_locked`, `none_row_in_stack`) cez `CabinetBuilder.normalize` → `Construction.build_plan(cfg)`
    (`hardware_rules: nil` = pravidlá zo súboru, `construction.rb:216`):
    (1) **nákup kovania:** `plan[:hardware]` → `HardwareSets.expand(…)` → `HardwareSets.purchase_csv(exp, project: 'H9', generated_at: <pevný>)` — bajty CSV;
    (2) **hrany do VEPO:** pre dielce plánu `AbsRules.resolve_edges(role, decor, hrúbka, sheet:)` nad katalógom **s ABS pre zvolený dekor** (vzor ABS testov,
    napr. `test_abs_width_picker.rb`) → riadky kusovníka s hranami → VEPO CSV (vzor `test_d121b_vepo_kontrakt.rb`/`test_d112_d113_vepo.rb`) — bajty CSV.
    **Predpoklad testu:** výstup s vlastnými súbormi sa **líši** od výstupu so seedom (S22 kovanie áno; S23 — bez ABS v katalógu sa ABS neprejaví, test by nič
    nedokazoval). Odtlačok sa nahrá **na maine v commite T0** do novej fixtúry `tests/fixtures/h9_golden/` (ručný `generate.rb`, vzor `kova_golden`), po zásahu
    **bajtovo rovnaký**. Presnú skladbu riadkov kusovníka pre VEPO prevezme implementátor zo vzorových testov (NEOVERENÉ sondou).
- **T1 Dodávateľ — zlý tvar + dobrá `.bak`** (min. 16 vstupov z R2) → záloha, `:backup`, `degraded`; primár aj `.bak` **bajtovo nedotknuté** po `load`,
  `layout_params` aj `patch_active!` (`[false, [degraded_reason], :write_failed]`).
- **T2** Bez dobrej `.bak` (chýba / zlý tvar / nečitateľná) → `:seed_fallback`, `fallback`, Kontrola ORANGE, plán „orientačne"; `load` nezapíše; uloženie opraví.
- **T3** Chýbajúci primár + `.bak` zlého tvaru → `:seed_fallback`, `ensure_seeded` nič nezapíše. **T4** Obnova zmazaním primára. **T5** Novší `std` 3 bez
  `suppliers` (aj s dobrou `.bak`) → `:newer_file`. **T6** R-11 bez zmeny (`test_r11…` bez úpravy).
- **T7 `JsonFileStore`:** tabuľka `json_state`/`degraded?` s tvarom aj bez neho; `read_valid` (primár ok · zlý primár + dobrá `.bak` · oba zlé → `InvalidShape`,
  ktorý `is_a?(JSON::ParserError)`) **+ FIX 1: primár `[]` + nečitateľná `.bak` + zdravá `.bak.bak` → `InvalidShape`, dodávateľ `:seed_fallback`, hodnota z `.bak.bak`
  sa nikdy nepoužije**; `read(…, fallback: false)`; `write` s predikátom: dobrá `.bak` ostane, bez dobrej `.bak` sa zálohuje, bez predikátu bajtovo ako dnes;
  po `write` je cache `.bak` neplatná.
- **T8 Pasca Ruby 3:** guard `def write(path, payload, shape = nil)` bez kľúčových parametrov; funkčne `test_uib3_rady.rb` (`DimSeries.set`).
- **T9 Fail-closed predikátu (FIX 2), parametrizovaný** výnimkami `RuntimeError`, `JSON::ParserError`, `Errno::ENOENT`, `Errno::EACCES`, `NoMethodError`:
  dodávateľ `load` = `:unreadable`, `patch_active!` false; `AbsRules.write`/`HardwareRules.write` false; priamy `JsonFileStore.write` → `ShapeCheckError`;
  `json_state`/`degraded?` → `ShapeCheckError` (nie `:corrupt`/`:missing`); primár aj `.bak` vždy bajtovo nedotknuté.
- **T10 R6:** `rounding_step:"abc"` + chýbajúci `olep` → `load` nezapíše, payload nesie `repaired_scalars: ['rounding_step']`, vedomé uloženie opraví.
- **T11 Štrukturálne guardy:** `read_doc`/`AbsRules.read_rules`/`HardwareRules.read_rules` volajú `read_valid`; brány odovzdávajú predikát; `write` odovzdá predikát;
  `disk_std` a oba `newer_write_blocked?` `read_valid` **nevolajú**; predikát sa volá len cez `shape_ok?`; R-11 guardy zelené.
- **T12 Bez zmeny fixtúr a existujúcich testov:** celá headless sada (S17: 4911/0 nad prototypom) — menovite `test_supplier_settings`, `test_np2…`, `test_np4_ceny`,
  `test_np4_golden`, `test_ceny_m2_golden`, `test_kova_golden`, `test_kovh_golden`, ABS sady (`test_abs_*`, `test_materials_abs_persistence`, `test_kovd5_abs_zasuvky`,
  `test_d88_abs_farby`), `test_r08_zamky`, `test_r11…`, `test_uib3_rady`; všetky JS sady (JS sa nemení).
- **T13 ABS a kovanie (FIX 3) — matica R14:** 5 vstupov (`{"rules":{}}`, `{"rules":[]}`, `[]`, `{}`, `{"std":1,"rules":"x"}`) + dobrá `.bak` → hodnoty zo zálohy,
  primár aj `.bak` bajtovo nedotknuté po načítaní aj po pokuse o zápis (false + `write_block_reason`); bez `.bak` → seed, **žiadny zápis pri načítaní**, vedomé
  uloženie opraví; legitímne prázdne s `seed_version` → zdravé; `HardwareRules.library_std_unsupported?` pri zlom primári + novšej `.bak` = true (zhodne s `load_state`).
- **T14 Log raz:** 100× `AbsRules.rules` nad zlým tvarom bez zálohy → najviac jeden riadok logu.
- **T15 Uloženie „aj ako globálnu predvoľbu" nad degradovaným kovaním (delta NOTE 3)** — headless nad skutočným `RulesDialog` (načítanie vzor `test_st3b_rules.rb`),
  falošný model s `start/commit/abort_operation` a atribútmi (vzor `test_d134_rozsah_zapisov.rb` + `NxTest::FakeEntity`), skutočné `CabinetBuilder.rebuild_many`
  s prázdnym zoznamom (stub `Panel.job_cabinets_split` → `[[], []]`), stub statusu a `after_model_write`; payload s baseline z `rules_payload`. Pre `[]` aj
  `{"rules":[]}` bez `seed_version` (+ dobrá `.bak`) a `also_global: true`: snapshot projektu = nové pravidlá · operácie `[[:start, …], [:commit]]` · status obsahuje
  „Pravidlá uložené do projektu" **a** vetu degradácie, **neobsahuje** „+ globálna predvoľba" · globálny primár aj `.bak` bajtovo nedotknuté. Kontrola: zdravý
  súbor → „+ globálna predvoľba" a globál zapísaný. Ak by sa stub ukázal neúnosný, rovnaký scenár ako krok in-SU v `su_runner.rb` (vtedy beh pred mergom; brána
  mergu podľa §8 to nie je — kód okna sa nemení).
- **T16 Parita brány kovania (delta FIX 1):** pre stavy súboru zdravý · zlý tvar + dobrá `.bak` · nečitateľný + dobrá `.bak` · novší `std` · zlý tvar bez `.bak` ·
  chýbajúci: `write_gate` (stav a veta) ↔ výsledok `HardwareRules.write` a `write_block_reason` (zápis prejde **práve** pri `:ok`); predikát vyhodí →
  `write_gate` vyhodí, `write` false. Guard: v tele `write` medzi zámkom a `JsonFileStore.write` rozhoduje len `write_gate` (cez dve pomenované metódy);
  `write_gate` volá `reload!` pred `degraded?`.

**Mutácie (min. 8; každá musí zhodiť aspoň jeden test):** M1 `read_doc` späť na `read` · M2 predikát dodávateľa bez neprázdnych `suppliers` · M3 bez kontroly
`rates` · M4 bez výnimky pre novší `std` · M5 brána dodávateľa bez predikátu · M6 `preserve_valid_backup` ignoruje predikát · M7 `preserve_valid_backup` preskočí
zálohu vždy pri zlom primári · M8 R6 späť na `layout_repaired` · M9 `InvalidShape < StandardError` · M10 `read_valid` číta `.bak` **s** fallbackom (FIX 1) ·
M11 `write` s kľúčovým `shape:` · M12 `shape_ok?` bez balenia výnimiek (FIX 2) · M13 `ShapeCheckError < JSON::ParserError` · M14 predikát ABS bez podmienky
`seed_version` · M15 predikát kovania bez podmienky `seed_version` · M16 `AbsRules.read_rules` späť na `read` · M17 brána kovania bez predikátu ·
M18 `write_gate` rozhoduje len z dokumentu `read_valid` · M19 `write_gate` bez `reload!` · M20 `newer_write_blocked?` mimo `write_gate` (vlastné čítanie) ·
M21 vlastné súbory T0d nahradené seedom (predpoklad „líši sa od seedu" musí zlyhať).

**DoD:** T0 (a–d, s fixtúrou `h9_golden`) commitnutý pred zásahom · T1–T16 + mutácie (zoznam a výsledok do PR) · headless + všetky JS sady zelené · encoding guard · R11 dokumentácia · §11.

## 8 · In-SU test — **nie je brána mergu**

Dávka nemení buildery, observery, undo/operácie, geometriu ani akcie panela zapisujúce do modelu. ABS a kovanie mení **len zdroj pravidiel pri poškodenom
súbore**; kód stavby sa nemení a jej vstup pri zdravom súbore je bajtovo rovnaký (T0c, T0d — hrany do VEPO a nákup kovania nad vlastnými súbormi, golden
kovania). Kód okna Pravidlá sa nemení; priebeh „aj ako globálnu predvoľbu" pri degradovanom súbore kryje headless T15 (záložne krok in-SU). Globálne JSON súbory
overí headless sada úplne (S17).

## 9 · Riziká

1. **Predikát omylom odmietne zdravý súbor** → s dobrou `.bak` „degraded" (stará záloha, zápisy vypnuté), bez nej predvolené a uloženie prepíše. Ochrana:
   predikáty len na kontajneroch, ktoré každá verzia zapisuje (S12); legitímne prázdne pravidlá s `seed_version` povolené; T0/T0c; R1g zdravý primár pri prepise zálohuje.
2. **Pasca Ruby 3 v `write`** (S13) — R1e pozičný + guard T8.
3. **Cache:** `read_valid` sa skladá nad `read`, záloha je pod vlastným kľúčom a `write` ju invaliduje; surové čítania ostávajú, kde potrebujú primár.
4. **Záloha = stav pred posledným uložením** — v stave „degraded" sa počíta so staršími hodnotami (banner pri dodávateľovi; pri ABS a kovaní len konzola a odmietnutie
   zápisu v okne Pravidlá — Q1/§14 N3).
5. **Viditeľná zmena:** rozbitý súbor bez zálohy sa dnes ticho „opraví" seedom; po H9 dodávateľ ukáže `fallback` + ORANGE, ABS/kovanie počítajú so seedom bez
   zápisu, kým sa vedome neuloží. Zámerné.
6. **Výrobný dopad v poškodenom stave:** hrany a nákup kovania sa riadia zálohou namiesto seedu — správnejšie, ale iné čísla než dnes (len v tom stave).
7. **Novší plugin s iným tvarom** — výnimky v predikátoch; T5, T13. **TOCTOU** voči zapisovateľom mimo zámku — zvyšok R-11 N6. **Starší plugin** bez ochrany (R9).
8. **Prekročenie odhadu** → rez H9a/H9b (§2).

## 10 · Smoke checklist pre Michala (po aktualizácii, funkčne)

1. Známa zákazka: **Rozpočet SPOLU, sadzby a prerez/orez v Nastaveniach rozpočtu, hrany v Kusovníku a nákup kovania sú rovnaké ako pred aktualizáciou**; žiadny banner.
2. Ulož drobnú zmenu v Nastaveniach rozpočtu aj v okne Pravidlá (ABS alebo kovanie) a vráť ju — uloží sa bez hlášky.
3. *(voliteľné — ochrana naživo)* Zavri SketchUp, v `%APPDATA%\NOXUN\Engine\` **skopíruj bokom** `supplier_settings.json` a `supplier_settings.json.bak`,
   prepíš obsah `supplier_settings.json` v Poznámkovom bloku na `[]`, ulož, spusti SketchUp → Nastavenia rozpočtu: **červený banner „poškodené — číta sa záloha"**,
   sadzby sú tvoje (stav pred posledným uložením), nie predvolené (porez 17 €, orez 10 mm); „Uložiť" vypnuté; Rozpočet počíta s tvojimi sadzbami.
4. Pokračovanie 3: zmaž `supplier_settings.json` (záloha ostane) → **Načítať nanovo** → banner zmizne, hodnoty tvoje; drobná zmena sa uloží. Na konci vráť
   skopírované súbory späť (pri zavretom SketchUpe).
5. Lucia: aktualizovať aj jej PC.

## 11 · Checklist uzáveru

Bump patch (`noxun_engine.rb` + `main.rb`) + všetky `?v=` → testy zelené (headless + všetky JS) → odseky `json_file_store.rb`, `supplier_settings.rb`, `abs_rules.rb`,
`hardware_rules.rb` prepísané na mieste (odsek `hardware_rules.rb` menuje **`write_gate` ako jedinú zápisovú bránu globálnej knižnice** a jej stavy — R15,
autorita pre H10) + STANDARD §11.5 → **`AUDIT_REGISTER.md`:** R-37 **✅ dávkou H9 (PR #?)** s presným rozsahom (chránené: nastavenia
dodávateľa, pravidlá ABS, globálne pravidlá kovania; `dim_series` pri načítaní nezapisuje a tvarom chránený **nie je**), **oprava vety** „`abs_rules`,
`hardware_rules` a `dim_series` pri načítaní nezapisujú" (S8) a riadok tabuľky „Stav po previerke"; zvyšky §14 ako nové záznamy podľa rozhodnutia orchestrátora.
**Uzáver netvrdí ochranu, ktorú dávka nedodá** (dim_series, vepo_settings, hodnotové poškodenie) → prepis `SYSTEM/STAV.md` → odsek navrch „Záznamy dávok"
v `KRONIKA.md` (mutácie, počty testov) → `PLAN.md` riadok H9 ✅ + PR → číslo PR samostatným commitom. Ak sa aktivoval rez (§2), H9a uzatvára len dodávateľa.

## 12 · Rozhodnutia autora (na potvrdenie)

- **A1 Zlý tvar = tá istá trieda ako nečitateľný JSON** — celá cesta R-11/NP-2, žiadny nový stav, text ani JS.
- **A2 Predikáty len na kontajneroch** (R2, R12, R13); čísla ostávajú na normalizácii. Asymetria pri dodávateľovi (`rates` neprázdne vs. `standard_rows` aj
  prázdne) podľa S12. Pri pravidlách je prázdny kontajner platný len so `seed_version`.
- **A3 Spoločné primitívum v `JsonFileStore`, opt-in** — jedna definícia pre H9 aj H7; ostatní volajúci bez zmeny.
- **A4 Ochrana zálohy len pri dobrej záloze** (R1g) namiesto „nezapisovať `.bak` pri normalizačnom zápise" (zhoršilo by R-11 obnovu po bežnom seed-merge).
- **A5 R6 v rozsahu.** **A6 Fail-closed predikátu cez vlastný typ** `ShapeCheckError` (FIX 2). **A7 `STD` bez zmeny.**
- **A8 ABS a kovanie v H9** (rozhodnutie orchestrátora k FIX 3; ~100 riadkov kódu spolu vrátane `write_gate` ≤ ~120) s poistkou rezu H9a/H9b.
- **A9 Záloha sa číta bez ďalšieho fallbacku** (FIX 1) cez `read(…, fallback: false)` — s cache (horúca cesta ABS pri generovaní dielcov), nie priamym
  parsovaním pri každom volaní.
- **A10 Kovanie: `library_*` provenienčné čítania cez ten istý pomocník** (R13) — konzistencia s pravidlami, ktoré sa naozaj použijú.
- **A11 `write_gate` je autorita H9 aj H10** (delta FIX 1; R15) — brána nad **súbormi** po `reload!`, tri stavy, výnimky propaguje. Dve dnešné metódy ostávajú
  ako tenké dotazy (bránu vyhodnotia dvakrát pod tým istým zámkom) — zachová R-11 guard bez úpravy; jedno vyhodnotenie s uložením medzivýsledku by bolo
  krehkejšie. Brána sa zavádza len pre kovanie (H10a); dodávateľ a ABS majú bránu na jednom mieste (`degraded_write_blocked?` s tvarom) a H10 ich nepoužíva.
- **A12 T0d ako nová golden fixtúra** `tests/fixtures/h9_golden/` (nie zmena existujúcich) — existujúce golden kovania stoja na seede a cestu cez súbor nedokážu.

## 13 · Otázky pre Michala (produktové — dávka ide s predvoľbou „nie")

- **Q1** Keď sa sadzby (alebo pravidlá ABS/kovania) čítajú zo **zálohy**, má to oznámiť aj **Kontrola** oranžovým nálezom? *Predvoľba: nie (ako dnes pri R-11).*
- **Q2** Tlačidlo **„Obnoviť zo zálohy"** v banneri namiesto návodu „oprav alebo zmaž súbor"? *Predvoľba: nie v H9.*

## 14 · Nálezy mimo scope (návrhy)

- **N1:** `abs_rules` nemá doprednú bránu `std` — súbor z novšieho pluginu sa dá prepísať (S16: `{"std":3,…}` uloženie povolené). Kandidát vzoru KOV-F1.
- **N2:** hodnotové poškodenie sadzby (`porez: "abc"`, záporné) → normalizácia ju zahodí, seed-merge doplní 17 € a auto-zápis rotuje `.bak`; v UI bez priznania.
- **N3:** Kontrola pri čítaní zo zálohy nehlási (Q1); ABS a kovanie nemajú banner degradovaného stavu mimo okna Pravidlá.
- **N4:** pri `:seed_fallback` hovorí ORANGE Kontroly len o prereze/oreze, nie o predvolených sadzbách.
- **N5:** `TemplateStore.migration_source`/`library_doc` (KON-D) — lokálna kópia „zlý tvar = poškodený"; po H9 na spoločné primitívum (H16, D-48).
- **N6:** `dim_series` — uloženie radov z panela nad súborom zlého tvaru (`[]`) skopíruje zlý primár do `.bak` a dobrú zálohu zničí (pri načítaní nezapisuje).
  Rady sú len ponuka (nie výrobné) — kandidát na rovnaký predikát.
- **N7:** `standard_rows: []` sa ticho doplní seedom a zapíše — tolerované (A2).

## 15 · Audit návrhu — zapracovanie (Codex, 1.10.2026: 0 BLOCKER · 3 FIX · 1 NOTE)

| Nález | Overenie | Zmena v package |
|---|---|---|
| **FIX 1** `read_valid` cez `read("….bak")` padá na `.bak.bak` → staršie dáta so stavom `ok` | **potvrdené** sondou S14 (vráti porez 99 z `.bak.bak`) | R1e `read(…, fallback: false)`, R1f záloha bez ďalšieho fallbacku, `write` invaliduje cache `.bak`; T7 prípad `[]` + nečitateľná `.bak` + zdravá `.bak.bak`; M10; A9 |
| **FIX 2** výnimka predikátu typu `ParserError`/`ENOENT` sa zamení za poškodený/chýbajúci súbor → zapisovateľný `:seed_fallback` | **potvrdené** a v prototype v2 uzavreté (S15, 5 typov výnimiek) | R1a `InvalidShape` vs. `ShapeCheckError`, R1b `shape_ok?`, R1c predikát mimo rescue bloku, R1g, R4; T9 parametrizovaný; M12, M13; A6 |
| **FIX 3** ABS/kovanie: prázdne `rules` bez `seed_version` prepíšu dobrú `.bak`; §4 ich vylučoval, register tvrdí opak | **potvrdené** (S8) + nové: koreňovo zlý tvar ticho počíta so seedom a uloženie z okna zálohu zničí | rozhodnutie orchestrátora → **v H9** (§2 ~90 riadkov kódu, bez rezu; poistka H9a/H9b); §1, §3, §4, §5; R12–R14; T0c, T13, T14; M14–M17; §8, §9; §11 oprava registra a zákaz tvrdiť nedodanú ochranu; A8, A10; §14 N1, N6 |
| **NOTE 4** T0 neoveruje nárezový plán so súborovými parametrami | **potvrdené** — golden používa `seed_supplier` a `params: {}` (`test_np4_golden.rb:85-86,106`) | **T0b**: `SheetLayout.compute` s `SS.layout_params` zo zdravého súboru + `Budget.compute` s `plan_prices` vypnutým aj zapnutým, zhoda + pripnuté čísla z mainu |

### 15.2 · Delta audit — zapracovanie (1.10.2026: pôvodné 4 RESOLVED · nové 2 FIX + 1 NOTE)

| Nález | Overenie | Zmena v package |
|---|---|---|
| **FIX 1** H9 a H10 nemajú zjednotený kontrakt zápisovej brány `hardware_rules`; čistá `write_gate_reason(doc)` z H10 by degradáciu z dokumentu nezistila a obišla H9 bránu | **potvrdené** S21 (`{"rules":[]}` + dobrá `.bak`: bez tvaru brána pustí, dokument z `read_valid` je obsah zálohy) | **R15 `HardwareRules.write_gate`** — signatúra, stavy, poradie, vety, výnimky, zákaz rozhodovať len z dokumentu; §3; T16; M18–M20; A11; §11 odsek `hardware_rules.rb`; prenos do H10 nižšie |
| **FIX 2** golden pre zdravé vlastné ABS a kovanie nepokrýva výrobné výstupy | **potvrdené** S22 (vlastné pravidlá kovania menia nákup), S23 (ABS sa bez ABS v katalógu neprejaví) | **T0d** — hrany do VEPO a nákupný CSV kovania nad vlastnými zdravými súbormi, odtlačok z mainu (`tests/fixtures/h9_golden/`), predpoklad „líši sa od seedu"; M21; A12; §8 |
| **NOTE 3** „aj ako globálnu predvoľbu" najprv uloží projekt a prestavia, až potom odmietne globál | **potvrdené** S24 (`rules_dialog.rb:638-660`) | R14 — stĺpec „zápis do globálneho súboru" + odsek: odmietnutý je **len globálny súbor**, projekt a prestavba ako dnes; **T15** (headless priebeh, záložne in-SU krok); §8 |

**Pre H10 — čo musí prevziať z H9 (orchestrátor prenesie do `PACKAGE_H10.md`; tento package H10 nemení):**

1. **R1.1 `library_check(fresh:)`:** stav **výhradne** z `HardwareRules.write_gate` (R15) — `:ok` → `:ok`; `:degraded` alebo `:newer` → **`:blocked`** s `reason`
   z brány; **akákoľvek výnimka** brány (I/O, `JsonFileStore::ShapeCheckError`) → **`:unreadable`**. Pri `fresh: true` brána sama robí `reload!` (H10 ho nemusí
   volať zvlášť). `rev` z `read_rules` — od H9 číta cez `read_valid` (pri degradácii obsah zálohy; pri zlom tvare bez dobrej zálohy `SEED_RULES` → `rules_rev(SEED_RULES)`,
   zhodne s „samooprava ostáva"). Navrhovaná čistá `write_gate_reason(doc)` **odpadá** (FIX 1); parita `write` ↔ `library_check` je daná tým, že obe volajú `write_gate`.
2. **R1.2 `save_library!`:** pod `with_catalog_lock` `library_check(fresh: true)` a potom `write(rules)` — `write` bránu **vyhodnotí znova** (R15), takže
   súbeh medzi predkontrolou a zápisom nemôže zapísať do degradovaného súboru.
3. **R1.4 riadok 2 a R1.5 `:blocked`:** priebeh „projekt uložený a prestavaný, globál odmietnutý s vetou brány" je **dnešné správanie** a H9 ho len pomenúva (R14,
   T15) — H10 naň stavia bez zmeny.
4. **`JsonFileStore` od H9:** `read(path, copy:, fallback:)`; `write(path, payload, shape = nil)` — **tretí parameter pozičný, nikdy kľúčový** (pasca Ruby 3,
   S13); `degraded?(path, shape: nil)`; `read_valid`; typy `InvalidShape < JSON::ParserError` a `ShapeCheckError < StandardError`. `rescue` v H10 nesmie
   `ShapeCheckError` zamieňať za poškodený súbor.
5. **H10b `dim_series`:** H9 tvar pre rady **nezavádza** (§14 N6) — brána ostáva `JsonFileStore.degraded?(path)` bez tvaru; ak H10b chce tvar, je to rozšírenie mimo H9.
6. **Poradie:** H10 štartuje až z mainu po mergi H9; pri odchýlke implementácie H9 od R15 orchestrátor package H10 zladí (krátka delta audit).

---

## Potvrdenie orchestrátora (1.10.2026 ~03:05)

- Audit návrhu: 0 BLOCKER · 3 FIX · 1 NOTE → §15; delta audit: 4/4 RESOLVED + 2 FIX + 1 NOTE → §15.2. FIX-y zapracované, BLOCKER nebol → **audit uzavretý**.
- **Bez rezu** (odhad ~100 riadkov kódu); poistka §2 (nad ~120 riadkov → rez H9a/H9b) platí.
- **R15 `HardwareRules.write_gate → [state, reason]` je záväzná autorita** aj pre H10 (`library_check` ju preberá; `write_gate_reason(doc)` z H10 odpadá).
- Q1/Q2 platí predvoľba „nie" (bez oranžového nálezu v Kontrole, bez tlačidla „Obnoviť zo zálohy"), kým Michal neodpovie — v PR a reporte ako vratná voľba.
- Trieda: audit-povinná + výrobná/cenová (konzervatívne) → predrecenzia povinná; in-SU nie je brána. Implementátor skopíruje package + `AUDIT_H9_raw.md`
  + `AUDIT_H9_delta_raw.md` do `SYSTEM/zdroje/bloky/HARDENING/`.
