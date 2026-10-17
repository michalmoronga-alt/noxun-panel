# PACKAGE U2 · Prevzatie a export per knižnica (SYNC-0 + háčiky) — blok UPDATE (D-48)

> **Stav: NÁVRH — audit návrhu prebehol (Codex astra: 3 BLOCKER · 3 FIX · 1 NOTE), zapracovanie v §15 — §15 MÁ PREDNOSŤ pred §1–§14; čaká delta audit.** Dátum 17.10.2026. Package do zásoby — **implementácia až po smoke PASS bloku 9 HARDENING**
> (alebo Michalovom „ideme ďalej") a po mergi predchodcu podľa poradia RECONCILE §3 (U1 kedykoľvek · **U2 → U3 → U4 → U5**).
> **Autorita:** [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) (R1–R17, mockup O1–O8 — záväzné) · [RECONCILE_2026-10-17.md](RECONCILE_2026-10-17.md)
> §2 riadky „U2" a §3 · [CROSS_AUDIT_A4_CLAUDE_KOD.md](CROSS_AUDIT_A4_CLAUDE_KOD.md) **B1, B2, B3, B6, B7, B8, B14** · [CROSS_AUDIT_A2_GROK.md](CROSS_AUDIT_A2_GROK.md) B4, B5, B9 ·
> súpis [../../../../docs/architecture/kniznice.md](../../../../docs/architecture/kniznice.md) (F3–F5, F12, F13) · [rozsirovacie-body.md](../../../../docs/architecture/rozsirovacie-body.md) scenár 7.
> **Trieda:** **Ť** (audit-povinná — kontrakt perzistencie, nový modul, nové `STD`) · **výrobná/cenová áno + export test `P == K`** (§12 D1) · **rez U2a / U2b / U2c** (§15.8 prednosť pred §2) · schéma súborov knižníc sa nemení.
> **Stav kódu:** sonda nad `docs/update-start` `4f2ecdd3` (kód = `main` po #474, plugin **v0.18.1**). Riadky = stav k nemu; pri štarte dávky ich implementátor overí znova.

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 17.10.2026

Len čítanie kódu (Grep/Read), bez spustenia a bez zápisu do modelu či `%APPDATA%`. Cesty relatívne k `noxun_engine/`.

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | Register je čisté dáta; `JsonFileStore` neregistrovaný súbor **neodmieta** — vynútenie a háčiky ostali na SYNC-0 | `core/library_registry.rb:10-14`; `core/json_file_store.rb:79-95` (žiadna kontrola cesty) | PRAVDA |
| S2 | Zdieľaná množina = 12 riadkov (`materials appearances abs_rules hardware_rules hardware_catalog hardware_taxonomy hardware_sets templates template_previews supplier_settings appliances appliance_files`), pripnutá testom | `library_registry.rb:87-135`; `tests/pure/test_h16_kniznice.rb:44-45, :853-858` | PRAVDA |
| S3 | Riadok registra nemá pole skupiny ani závislosti; `KINDS` už pozná `backup`, `SYNCS` = shared/local | `library_registry.rb:44-46, :75-82` | PRAVDA |
| S4 | Guard T5 padne na zapisovateľa bez zápisu aj na zápis mimo súpisu; T5b drží `WRITE_SITES` | `test_h16_kniznice.rb:72-106, :220-245` | PRAVDA |
| S5 | **B1:** `Materials.write` → `write_unlocked` → `prepare_appearance_write!` berie `appearance` vždy z **disku** (`copy_appearance!(rec, old)`), nie z payloadu | `core/materials.rb:309-314, :337`; `core/materials_appearance.rb:182-216, :160-165` | PRAVDA |
| S6 | `write_unlocked` pečiatkuje `std`, `schema` = max(payload, obsah, disk) a odmietne pri `catalog_read_only?` | `materials.rb:329-334, :342-343, :367-369` | PRAVDA |
| S7 | **B2:** čítanie samo zapisuje (seed-merge, normalizácia, migrácia) | `materials.rb:265-266`, `abs_rules.rb:231-239, :282-296`, `hardware_rules.rb:544-551`, `hardware_catalog.rb:184-191`, `templates.rb:105-107, :461-465`, `supplier_settings.rb:228-230`, `hardware_taxonomy.rb:470-484` | PRAVDA |
| S8 | Bežné zápisy pečiatkujú/normalizujú: `abs_rules.rb:376`, `hardware_rules.rb:764-765`, `hardware_sets.rb:1517-1519`, `supplier_settings.rb:443`, `templates.rb:664`, `hardware_catalog.rb:600-603`, `appliance_catalog.rb:935-941`; všetci volajúci chytajú `StandardError` → `false` | uvedené riadky | PRAVDA |
| S9 | Každý store má **čisté posúdenie dokumentu** použiteľné ako brána importu (stĺpec „Brána“ v R3.4) | `materials_health.rb:287-321`, `abs_rules.rb:266-272`, `hardware_rules.rb:604-623`, `hardware_catalog.rb:250-258`, `hardware_taxonomy.rb:160-180`, `hardware_sets.rb:690+`, `templates.rb:535-540`, `supplier_settings.rb:286-298, :398`, `appliance_catalog.rb:348-362` | PRAVDA |
| S10 | **B6:** stav v pamäti modulov (posúdenie, návrhy cien, log príznaky) — zoznam v R3.3 | `materials_health.rb:199-223`, `hardware_catalog.rb:144-230`, `hardware_taxonomy.rb:109-137`, `hardware_sets.rb:590-620`, `appliance_catalog.rb:265-328` | PRAVDA |
| S11 | Resety sú dnes „test-only" a **dva nulujú aj zámkový čítač**: `HardwareCatalog.reset_state!` → `@lock_depth = 0` (`hardware_catalog.rb:226-231`), `ApplianceCatalog.reset_state!` → `@lock_held = false` (`appliance_catalog.rb:323-328`) — volanie pod zámkom by rozbilo reentranciu | uvedené riadky | PRAVDA → R4.3 |
| S12 | Zámky: `Materials` a `ApplianceCatalog` kontrolujú `flock` (`materials.rb:503-530`, `appliance_catalog.rb:225-245`); `HardwareCatalog.with_lock` nie (`hardware_catalog.rb:128`); `TemplateStore.with_lock` výnimku prehltne → `false` (`templates.rb:636-653`) | uvedené riadky | PRAVDA (F3) |
| S13 | **B14:** značky UNI zapisujú `write_uni_marker` / `write_drawer_uni_marker` (`materials_catalog.rb:1104-1108, :1184-1188`); bez značky `ensure_uni_records!` / `ensure_drawer_uni!` UNI záznamy pri štarte doplnia (`:1071-1098`, `:1142-1182`) | uvedené riadky | PRAVDA |
| S14 | **B7:** `.bak` sa prepíše každým ďalším zápisom (`json_file_store.rb:84, :190-199`) — nie je to záloha R4 | uvedené riadky | PRAVDA |
| S15 | Druhá inštancia: `Updater.live_leases(plugins_dir)` existuje, je fail-closed (`Refused` pri chýbajúcom priečinku) | `updater.rb:751-760`, použitie `:924, :970` | PRAVDA |
| S16 | Hromadné „Prepočítať ceny" beží asynchrónne, `PriceRefresh.running?` existuje | `price_refresh.rb:119, :160-171` | PRAVDA |
| S17 | Verzia pluginu: `Engine::VERSION = '0.18.1'` (`noxun_engine.rb:9`), fallback v `main.rb:9` | uvedené riadky | PRAVDA |
| S18 | Cesta vzhľadu `appearances/<uuid>.skm` (`materials_appearance.rb:109-112`); príloha spotrebiča = `record_dir(id)` + `item['file']` overené `ATTACH_FILE_RE` (`appliance_catalog.rb:203-219, :407-419`) | uvedené riadky | PRAVDA (presné skladanie cesty prílohy z `rec`/`item` **NEOVERENÉ** — implementátor vezme existujúci resolver `:1281` / `:1381`) |
| S19 | Šablóny odkazujú `material_id`, sety (`hardware_sets`, `hardware_set_defs`); spotrebiče len **kategóriou** (`ApplianceCatalog::CATEGORIES`), nie `catalog_id` | `templates.rb:127-157, :179-187` | PRAVDA → závislosť šablóny → {materiály, kovanie}, nie → spotrebiče |
| S20 | Poradie načítania: `json_file_store` (`main.rb:499`) **pred** `materials` (`:501`) a `library_registry` (`:502`); `price_refresh` `:569`; testy `tests/helper.rb:129-132` | uvedené riadky | PRAVDA → vynútenie číta register lenivo (R2) |
| S21 | Všetky volania `JsonFileStore.write` v plugine (22) píšu na cesty registra | Grep `JsonFileStore.write` | PRAVDA (testy 31× — zápis do koreňa mimo registra **NEOVERENÝ**, R0.3) |

**Upresnenie A4:** `HardwareTaxonomy.state` sa prepočíta pri každom volaní (`hardware_taxonomy.rb:109-111`) — reset tam rieši len log, nie zastaraný verdikt.

---

## 1 · Cieľ (funkčne)

Používateľ v U2 **nič nové nevidí** — dávka postaví „motor" pod tlačidlá Odoslať / Aktualizovať, ktoré pridá U5. Po U2 plugin vie:

- **vziať knižnicu presne tak, ako je** (napr. Materiály vrátane vzhľadov, ABS pravidiel a značiek), bez toho, aby ju pri tom sám prepečiatkoval
  — aby Michalova a Luciina knižnica pri rovnakom obsahu vyzerali **bajtovo rovnako** a plugin nehlásil falošné „lokálne zmeny";
- **prevziať celú skupinu** z Michalovho PC (Materiály · Kovanie · Šablóny · Dodávateľ a sadzby · Spotrebiče — mockup O3) **naraz alebo vôbec**:
  pred prepisom urobí **pomenovanú zálohu** (dá sa vrátiť), skontroluje, že dokument je zdravý a z **rovnakej verzie pluginu** (R14), že vzhľady,
  na ktoré ukazuje, už ležia na disku, a že nebeží druhé okno SketchUpu ani hromadné prepočítanie cien; po prevzatí okamžite **zabudne starý stav**
  v pamäti a knižnicu znova posúdi;
- **nedovolí** zapísať do priečinka knižníc súbor, ktorý nie je v súpise — aby Odoslať nikdy neposlalo cudzí ani zabudnutý súbor.

**Príklad:** Lucia klikne Aktualizovať → po prevzatí Materiálov má **Michalov** vzhľad „Dub Halifax" (bežný zápis by nechal jej starý — B1), jej
pôvodné Materiály sú v zálohe a UNI dosky, ktoré Michal zmazal, sa **nevrátia** (B14).

## 2 · Rez a odhad

| Časť | Obsah | Kód pluginu (+) | Testy | Odhad |
|---|---|---|---|---|
| **U2a · rámec + Materiály** | R1 register (skupiny, závislosti, 2 nové riadky) · R2 vynútenie v `JsonFileStore` · R4 `LibraryTransfer` (export/import skupiny, brány, záloha, návrat, stav synchronizácie, verzia) · R3 kontrakt store-u pre **Materiály** (`materials` + gate `appearances`) a **AbsRules** · R6 značky UNI | ~430 | ~550 | 1½ dňa |
| **U2b · ostatné skupiny** | R3 pre `HardwareTaxonomy`, `HardwareCatalog`, `HardwareSets`, `HardwareRules`, `TemplateStore`, `SupplierSettings`, `ApplianceCatalog` (+ gate príloh spotrebičov) · zapojenie skupín `hardware`, `templates`, `supplier`, `appliances` | ~280 | ~400 | 1 deň |

Spolu **~710 riadkov** kódu pluginu (> 600) → **rozdelenie U2a / U2b je návrh tohto package** (brief). Každá časť vlastný PR z čerstvého `main`, **jeden audit návrhu
pre obe** (vzor H7a/H7b); U2b nemení rámec z U2a — ak by musela, delta audit. **Poistka:** U2a nad ~500 riadkov kódu pluginu → implementátor zastaví a hlási.

**Poradie commitov U2a (záväzné):** (1) R0 charakterizácia, plugin bez zmeny · (2) R1 register + guard · (3) R2 vynútenie · (4) R3/R6 Materiály + AbsRules · (5) R4 `LibraryTransfer` · (6) docs.
**U2b:** (1) R0b charakterizácia ďalších store-ov · (2) R3 per store (jeden commit na store) · (3) zapojenie skupín + testy · (4) docs.

## 3 · Scope IN

- Register: skupiny, závislosti, riadky `library_backups`, `library_sync`, `library_import_pending` (R1, R4.9) · vynútenie v `JsonFileStore.write` (R2).
- Kontrakt store-u v 9 moduloch: `export_document`, `import_check`/`import_document!`, `after_import!`, `attachment_refs` (R3).
- Nový modul `core/library_transfer.rb`: snímok a prevzatie skupiny, záloha a návrat, žurnál a obnova po páde, stav synchronizácie, verzia podľa R18, odtlačok (R4, R5) · značky UNI (R6).
- Dokumentácia (R7).

## 4 · Scope OUT

- **Disk**, manifest, priečinok verzie, ukazovateľ, história 5, návrat na verziu z Disku, správca, zámok odosielania, **zisťovanie lokálnych zmien** (porovnanie odtlačkov),
  časový limit čítania H: — **U3** (U2 dáva len kanonické bajty, odtlačok a úschovu stavu).
- **Prílohy ako súbory** (kopírovanie `.skm`, náhľadov, listov, fotiek dekorov), zmena `sync` u `textures/` a jeho zaradenie do skupiny Materiály — **U4**.
  U2 len **overí prítomnosť** príloh, na ktoré prevzatý dokument ukazuje (B1: `.skm` pred JSON).
- **UI** — okno O plugine, varovanie R4 so zoznamom zmien a použitých záznamov (B5), pruh R13/O6, zatvorenie okien knižníc pred prevzatím (bariéra), oznámenie pri štarte — **U5**.
- Párovanie seed spotrebičov (R16 — netreba). Zmrazenie rozpočtu zákazky (R17 — mimo bloku). Názov zákazky v .skp (U1).
- Zmena bežných zápisových ciest store-ov (`Materials.write`, `AbsRules.write`, …) — ostávajú **bajtovo bez zmeny** (R0); import ide vlastnou cestou.
- Jednotné zámkové primitívum (F3) a oprava `TemplateStore.with_lock` / `HardwareCatalog.with_lock` — nová cesta sa ich slabinám **vyhne** (R4.4), oprava = §14.

## 5 · Trieda a brány

- **Trieda Ť** (CLAUDE.md, Výber profilu): audit-povinná + > 300 riadkov → profil `implementator`.
- **`codex-audit` povinný** — nový modul, zmena kontraktu perzistencie (vynútenie zápisu, nová importná cesta obchádzajúca bežné zápisy), **nové `STD`** (`LibraryTransfer::SYNC_STD`,
  `LibraryTransfer::BACKUP_STD` → zmena schémy podľa §13). Jeden audit pre U2a+U2b; sonda §0 je krok 0. Audit `gpt-6-astra` **úzko** (R12): vymenované súbory §0.
- **Predrecenzia povinná** obe časti. **Výrobná/cenová: ÁNO** (orchestrátor 17.10., §12 D1) — import zapisuje katalógy, z ktorých sa počítajú ceny a rozmery; platia celé brány výrobnej dávky.
- **In-SU:** spúšťače (buildery, observery, undo, geometria, akcie panela do modelu) sa **nemenia** → **nie je brána**; §8.
- **Export test — brána mergu U2a aj U2b:** `scripts\export_test.ps1` musí dať **`P == K`** (dôkaz, že dávka sama čísla nemení; povolené len rozdiely PACKAGE_H17 R9.3). **Fotky okien:** nie.
- **Smoke:** U2 nemá funkčný smoke pre Michala (nič neuvidí); §10 = krátka kontrola „nič sa nerozbilo" + plný smoke až po U5.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit, plugin bez zmeny, zelené na `main`)

- **R0.1 golden prvého behu H16** (`tests/fixtures/h16_golden/`) — po U2 **bez regenerácie** zelený (nové riadky registra nevznikajú pri prvom behu; ak by vznikali, STOP).
- **R0.2 bežné zápisy bez zmeny:** pre každý store sekvencia „seed → bežná úprava cez verejné API → `load`" v sandboxe → SHA bajtov súboru po každom kroku do
  `tests/fixtures/u2_golden/writes.json` (ručný `generate.rb`, vzor `h14_golden`). Po U2a aj U2b **tie isté bajty**.
- **R0.3 súpis cieľov zápisu v testoch:** inštrumentovaný beh celej headless sady s `JsonFileStore.write` obaleným záznamom cesty (len v R0, nie commitnutý obal)
  → zoznam ciest **v koreni** (`Materials.dir`), ktoré nie sú v registri. Výsledok do PR; každý nález = úprava testu (sandbox mimo koreňa) **pred** R2. NEOVERENÉ sondou.
- **R0.4 dôkaz B1 a B2 dnes:** test, ktorý ukáže, že `Materials.write` s iným `appearance` v payloade nechá na disku pôvodný (`materials_appearance.rb:197-199`) a že
  `AbsRules.rules` nad súborom so starším `seed_version` súbor prepíše. **Tieto testy po U2 ostávajú zelené** (bežné cesty sa nemenia) — import ich obchádza (R3).

### R1 · Register: skupiny, závislosti, nové riadky (`core/library_registry.rb`)

- **R1.1 `group`** (String) na **každom** `sync: shared` riadku; `nil` na lokálnych. Priradenie (O3, záväzné):
  `materials` ← `materials`, `appearances`, `abs_rules` · `hardware` ← `hardware_taxonomy`, `hardware_catalog`, `hardware_sets`, `hardware_rules` · `templates` ← `templates`,
  `template_previews` · `supplier` ← `supplier_settings` · `appliances` ← `appliances`, `appliance_files`. (`textures` ostáva `local` bez skupiny — zaradí ho **U4**, §12 D3.)
- **R1.2 `GROUPS`** (zmrazené pole, poradie = riadky mockupu): `{'key', 'label', 'members', 'depends_on'}`:
  `materials` „Materiály" · `hardware` „Kovanie" · `templates` „Šablóny" `depends_on: %w[materials hardware]` · `supplier` „Dodávateľ a sadzby" · `appliances` „Spotrebiče".
  `members` = **poradie prevzatia** v skupine: `materials`: `appearances`, `materials`, `abs_rules` · `hardware`: `hardware_taxonomy`, `hardware_catalog`, `hardware_sets`,
  `hardware_rules` · `templates`: `template_previews`, `templates` · `supplier`: `supplier_settings` · `appliances`: `appliance_files`, `appliances` (prílohy pred dokumentom).
- **R1.3 API (bez IO):** `groups` · `group(key)` (neznámy = `nil`) · `group_of(entry_key)` · `members(group_key)` (riadky v poradí) · `library_members(group_key)` (len `kind: library`)
  · `depends_on(group_key)` · `dependents(group_key)` (opačný smer, pre varovanie U5 „preskočením Materiálov ostanú Šablóny s odkazmi…") · `registered?(abs_path)` (R2).
- **R1.4 nové riadky (lokálne, nikdy sa neprenášajú):**
  - `library_backups` · `file: 'library_backups/'` · `kind: backup` · `sync: local` · `lock: 'materials.lock'`, `lock_mode: 'module'` · `children: %w[*/backup.json */files/**]`
    · `transient: %w[*.partial/**]` · `versions: %w[LibraryTransfer::BACKUP_STD]` · `writers: core/library_transfer.rb` · note „pomenované zálohy pred prevzatím (R4)".
  - `library_sync` · `file: 'library_sync.json'` · `kind: setting` · `sync: local` · `lock: 'materials.lock'`, `lock_mode: 'module'` · `bak: true` · `versions: %w[LibraryTransfer::SYNC_STD]`
    · `writers: core/library_transfer.rb` · note „lokálny stav synchronizácie per skupina (obsah plní U3)".
- **R1.5 guard** `test_h16_kniznice.rb`: tvar (`group` povinný práve pri `shared`; každý člen `GROUPS` existuje, je `shared` a patrí práve jednej skupine; `depends_on` bez cyklu
  a len na existujúce skupiny; prílohy skupiny = skupina ich knižnice), `SHARED` **bez zmeny** (pripnutá množina), riadky §3 kniznice.md, `WRITE_SITES` pre nový modul,
  verzie ↔ STANDARD §13.1 (T7). Negatívy: člen bez skupiny, dva členy, cyklus.

### R2 · Vynútenie registra v `JsonFileStore.write` (SYNC-0)

- **Pred akýmkoľvek IO** `write` overí cieľ: ak `File.expand_path(path)` leží **v koreni** `LibraryRegistry.root` (porovnanie po normalizácii lomiek a **bez ohľadu na veľkosť
  písmen** — Windows) a `LibraryRegistry.registered?(path)` je `false` → `raise JsonFileStore::UnregisteredPath` (dedí zo `StandardError`, **nie** z `ParserError` ani
  `SystemCallError`). Mimo koreňa (testové sandboxy mimo `Materials.dir`, budúce cesty) sa nič nemení.
- **`registered?(abs_path)`:** relatívna cesta (POSIX lomky) sa rovná `file` niektorého riadku bez globu **alebo** spĺňa glob riadku (`File.fnmatch` s `FNM_EXTGLOB | FNM_PATHNAME`)
  **alebo** leží v priečinku riadku (`file` končí `/`) a spĺňa jeho `children`. Dočasné mená (`transient`) **nie** — `JsonFileStore` píše dočasný súbor sám, cieľ je vždy finálny.
- **Lenivé čítanie registra:** `json_file_store` sa načíta pred registrom (S20) → kontrola sa pýta `Engine::LibraryRegistry` až pri volaní. Keď **nie je definovaný**,
  ale `Engine::Materials` áno a cieľ je v `Materials.dir` → **odmietnuť** (fail-closed); keď nie je ani `Materials`, kontrola sa preskočí (izolované testy primitíva).
- **Volajúci:** všetci dnes chytajú `StandardError` a vracajú `false`/`nil` (S8) — správanie pri chybe sa nemení; nová výnimka sa zaloguje ich existujúcim `log_error`.
- **Guard:** test so zápisom `cudzi.json` do sandboxu koreňa (odmietnutý, nič nevzniklo ani `.tmp-*`), registrovaný súbor (prejde), cesta mimo koreňa (prejde),
  veľké písmená v ceste (odmietnutá aj prijatá podľa obsahu, nie podľa písmen), priečinok príloh mimo `children` (odmietnutý).

### R3 · Kontrakt store-u (9 modulov; U2a: Materials, AbsRules · U2b: ostatné)

Každý zdieľaný store typu `library` dostane **tri verejné metódy** (`module_function`). Bežné metódy (`load`, `write`, `save_*`, seed, merge) sa **nemenia**.

**R3.1 `export_document` → `[:ok, doc]` | `[kód, správa]`**
1. **Usadenie:** zavolá **dnešnú bežnú čítaciu cestu** store-u (tú, ktorú volá okno — napr. `Materials.load`, `AbsRules.rules`, `HardwareRules.load_state`, `HardwareCatalog.assess!`
   + `load`, `HardwareTaxonomy.load`, `HardwareSets.load`, `TemplateStore.load`, `SupplierSettings.load_with_origin`, `ApplianceCatalog.assess!`). Tá smie zapísať seed-merge či
   normalizáciu **ako dnes** — zámer: odoslaný dokument je už „usadený" a prijímajúce PC s rovnakou verziou ho pri prvom čítaní neprepíše (B3, §9 R5).
2. **Stav:** store musí byť `:ok` (nie degradovaný, len na čítanie, z novšej verzie, zo seed fallbacku). Inak `[:not_ok, dôvod store-u]` — Odoslať z poškodenej knižnice nikdy.
3. **Čítanie pod zámkom store-u** (`lock` riadku): `JSON.parse(File.binread(path))` **priamo z primára** — bez cache, bez `.bak`, bez seedu, bez normalizácie. **Zdravý primár je
   podmienka (A1 S2):** primár chýba a `.bak` existuje, primár sa neparsuje alebo `JsonFileStore.degraded?(path[, shape:])` → `[:not_ok, „najprv obnov knižnicu"]` — tichý fallback
   zo zálohy sa **nikdy** neodošle; chýba primár aj `.bak` (prvé založenie) → `[:missing, …]`.
4. Dokument prejde **tou istou bránou ako import** (R3.2 krok 2); neprejde → `[:invalid, dôvod]`.
- Výsledok je **presne obsah súboru** (aj `std`, `schema`, `seed_version`, neznáme top-level kľúče). Kanonické bajty a odtlačok robí `LibraryTransfer` (R4.6).

**R3.2 `import_document!(doc)` → `[:ok, nil]` | `[kód, správa]`** (volá ho **len** `LibraryTransfer`; nikdy okno)
1. **Pod zámkom store-u** (rovnaký `lock` ako jeho bežný zápis; Materials a AbsRules = `Materials.with_catalog_lock`).
2. **Brána dokumentu** (čisté funkcie zo S9 — žiadna nová kópia pravidiel): `doc` je Hash; posúdenie store-u vráti „zdravé"; **dopredná brána**: `std`, `schema`, `seed_version`
   (kde ich store má) ≤ konštantám tejto verzie (tabuľka R3.4). Inak `[:invalid, dôvod]` / `[:newer, dôvod]`. **Nič sa nezapíše.**
3. **Lokálny súbor z novšej verzie** (napr. Lucia sa vrátila na starší plugin) → `[:local_newer, …]`, nezapisuje sa. Ostatné lokálne stavy (degradovaný, poškodený, chýbajúci,
   len na čítanie z dôvodu zdravia) import **nezastavia** — prevzatie je oprava; dáta chráni pomenovaná záloha (R4.3), ktorú urobí `LibraryTransfer` pred volaním.
4. **Prílohy:** pri `materials` každý `appearance.id` v `sheets`/`edges` má na disku `Materials.appearance_file(id)` (súbor, veľkosť > 0); pri `appliances` každá položka
   `attachments` existuje (cesta cez resolver S18). Chýba → `[:missing_attachments, [relatívne cesty]]`, nezapisuje sa (B1: „`.skm` pred JSON"; dodá ich U3/U4).
5. **Zápis:** `JsonFileStore.write(path, doc[, shape_check])` — **presne `doc`**, bez `merge`, bez `normalize`, bez pečiatky `std`/`schema`/`seed_version`, **bez** `prepare_appearance_write!`
   a **bez** brán bežného zápisu (`catalog_read_only?`, `degraded_write_blocked?`, revízie okien). `shape_check` sa odovzdá tam, kde ho store má (zachová dobrú `.bak`).
   Výnimka → `[:write_failed, správa]`.
- **Nezapisuje:** značky, seed, migračné značky, prílohy, stav synchronizácie. Nevolá `after_import!` (robí to `LibraryTransfer` po celej skupine — R4.2).

**R3.3 `after_import!` → stav store-u** (volá sa **mimo** zámku store-u)
- Nová produkčná metóda `reset_after_import!` = vynuluje **len** stav posúdenia a logovacie príznaky, **nikdy** zámkové čítače (S11): Materials `@catalog_state*` (a `@cutover_issue`
  — význam NEOVERENÝ, implementátor overí `materials_health.rb:56-64`), HardwareCatalog `@state*`, `@price_proposals`, `@create_proposals` (návrhy cien patria k starému obsahu),
  HardwareTaxonomy `@state*`, HardwareSets `reset_library_state!` (bez `@owner*` — patria modelu), ApplianceCatalog `@state*`, AbsRules/HardwareRules/SupplierSettings
  `@shape_logged`, `@write_block_reason`, TemplateStore `@unhealthy_logged`. Existujúce `reset_state!` (test-only) sa nemenia.
- Potom `JsonFileStore.reload!(path)` + **nové posúdenie** (`assess_catalog!`, `assess!`, `library_assess!`, `state`) + **usadenie** bežnou čítacou cestou (R3.1 krok 1).
- Vráti `[stav, dôvod]` po posúdení. Iný stav než `:ok` → `LibraryTransfer` obnoví zálohu (R4.2 krok 7).

**R3.4 Tabuľka store-ov** (brána = S9; dopredná brána = konštanty)

| Riadok | Modul | Brána dokumentu | Dopredná brána | Zámok | Pozn. |
|---|---|---|---|---|---|
| `materials` | `Materials` | `assess_catalog_schema(doc) == :ok` | `schema ≤ SCHEMA_CURRENT`, `std ≤ STD` | `materials.lock` | + prílohy `appearances`; po skupine značky UNI (R6) |
| `abs_rules` | `AbsRules` | `doc_shape_ok?` | `std ≤ STD`, `seed_version ≤ SEED_VERSION` | `materials.lock` | `doc_shape_ok?` novší `std` prepúšťa — dopredná brána je povinná |
| `hardware_taxonomy` | `HardwareTaxonomy` | `assess_doc(doc)` = `:ok` | `schema ≤ SCHEMA_CURRENT`, `seed_version ≤ SEED_VERSION` | `materials.lock` | |
| `hardware_catalog` | `HardwareCatalog` | `stored_document_issue(doc).nil?` | `schema ≤ SCHEMA_CURRENT`, `seed_version ≤ SEED_SET_VERSION` | `hardware_catalog.lock` | nevnárať s `materials.lock` (F4) |
| `hardware_sets` | `HardwareSets` | `assess_library_doc(doc)` = `:ok` | `std ∈ STD_SUPPORTED`, `seed_version ≤ SEED_VERSION` | `materials.lock` | |
| `hardware_rules` | `HardwareRules` | `doc_shape_ok?` ∧ `!doc_std_unsupported?` | `seed_version ≤ SEED_VERSION` | `materials.lock` | zápis **bez** `normalize_rules` |
| `templates` | `TemplateStore` | `library_doc`-tvar (`templates` je Array) | `std ≤ STD` (Integer) | `templates.json.lock` | zámok **s kontrolou `flock`** (R4.4) |
| `supplier_settings` | `SupplierSettings` | `doc_shape_ok?` ∧ `!doc_std_unsupported?` | `seed_version ≤ SEED_VERSION` | `materials.lock` | zápis **bez** `normalize` |
| `appliances` | `ApplianceCatalog` | `stored_document_issue(doc).nil?` | `seed_version ≤ SEED_VERSION` | `appliances.json.lock` | + prílohy `appliance_files` |

### R4 · Nový modul `Noxun::Engine::LibraryTransfer` (`core/library_transfer.rb`, `module_function`)

Načítanie v `main.rb` za `core/price_refresh` (S20) + `tests/helper.rb`; pri načítaní nesiaha na disk. **Žiadne UI, žiadna sieť, žiadny Disk** (H: je výhradne U3).

**R4.1 `export_group(group_key)` → `[:ok, packet]` | `[kód, správa]`**
- `packet = {'group', 'plugin_version' => Engine::VERSION, 'documents' => {entry_key => doc}, 'attachment_refs' => {entry_key => [rel. cesty]}, 'fingerprints' => {entry_key => sha256}}`.
- Členy v poradí `GROUPS`; každý `export_document` (R3.1). Prvý neúspech = celý výsledok neúspech s menom člena (Odoslať skupinu „naraz alebo vôbec").
- **Konzistentný snímok (A1 S3):** usadenie (R3.1 krok 1) všetkých členov → **1. prechod** čítania surových bajtov každého člena pod jeho zámkom, **postupne** (zámky sa nevnárajú,
  F4) → **2. prechod** rovnako → SHA-256 každého člena sa v oboch prechodoch musí zhodovať (každý súbor bol nemenný v spoločnom okne medzi koncom 1. a začiatkom 2. prechodu =
  jedna revízia skupiny). Nezhoda → opakovať najviac 3×, potom `[:busy_snapshot, „knižnica sa práve mení — skús o chvíľu"]`. Do packetu ide obsah 1. prechodu.

**R4.2 `import_group!(group_key, packet, plugins_dir:, reason:)` → `[:ok, result]` | `[kód, správa, detail]`**
1. **Predpoklady (nič sa nezapisuje):** `packet['group'] == group_key`; **`import_allowed?(packet['plugin_version'])`** inak `:version_mismatch` (R5/R18);
   `documents` obsahuje **práve** knižnice skupiny; `Updater.live_leases(plugins_dir)` prázdne, inak `:other_instance` (`Refused` = `:other_instance_unknown`, fail-closed — S15);
   `PriceRefresh.running?` → `:busy` (S16).
2. **Brány všetkých dokumentov naraz** (R3.2 kroky 2–4 ako čistá kontrola `import_check(doc)` každého store-u — nová verejná metóda bez zápisu, ktorú `import_document!`
   pod zámkom volá znova). Prvý neúspech → celé prevzatie odmietnuté **pred** zálohou.
3. **Pomenovaná záloha** skupiny (R4.3). Zlyhá → `:backup_failed`, nič sa neprepíše.
4. **Prevzatie** členov v poradí `GROUPS` (prílohové riadky sa preskočia — prílohy už ležia, overil krok 2): `import_document!`.
5. **Zlyhanie uprostred** (napr. druhý dokument) → **automatický návrat** zo zálohy z kroku 3 pre **všetky** dokumenty skupiny (`restore_backup!` bez novej zálohy) → `[:failed_restored, …]`;
   keď zlyhá aj návrat → `[:failed_restore_failed, …]` + log s ID zálohy (stav je v zálohe, ručná obnova cez U5).
6. **Po skupine:** pri `materials` značky UNI (R6). Potom `after_import!` každej knižnice skupiny (R3.3).
7. Stav po posúdení iný než `:ok` → návrat zo zálohy ako v kroku 5 (`[:unhealthy_restored, dôvod]`) — prevzatý dokument, s ktorým by plugin nevedel pracovať, neostane.
8. **Výsledok** `{'backup_id', 'fingerprints' => {entry_key => sha256 po usadení}}` — odtlačky **po** `after_import!` (A4 B3: „uložiť po prvom načítaní prevzatej verzie"; U3 ich
   zapíše ako východisko lokálnych zmien). Rozdiel oproti `packet['fingerprints']` sa **zaloguje** (znamená, že usadenie niečo zmenilo — §9 R5).
- **Predpoklad volajúceho (U5):** okná knižníc sú zatvorené (bariéra vzoru `supplier_settings_dialog.rb:565-588`) — U2 to neoveruje, len dokumentuje v odseku modulu.
- **Závislosti (B8)** U2 **nevynucuje** — preskočenie Materiálov pri prevzatí Šablón je dovolené; varovanie skladá U5 z `LibraryRegistry.dependents`.

**R4.3 Pomenovaná záloha (B7, R4 „jej verzia sa odloží ako záloha", O5 „Vrátiť zálohu")**
- `create_backup!(group_key, reason:)` → `[:ok, backup_id]`. Priečinok `library_backups/<group>-<YYYYMMDD-HHMMSS>-<4 hex>/`: najprv `<id>.partial/`, na konci rename (finálne meno vidí
  len hotová záloha; `.partial` po páde uprace najbližšie `create_backup!`). Obsah: `files/<rel. cesta>` = **bajtová kópia** primára každej knižnice skupiny **aj jej `.bak`**, ak existuje
  (degradovaný stav sa tak nestratí), + `backup.json` `{'std' => BACKUP_STD, 'group', 'created_at' (UTC ISO), 'plugin_version', 'reason', 'files' => {rel => sha256}}`.
  **Prílohy sa nezálohujú** — pri prevzatí len pribúdajú (A4 B9), nikdy sa nemažú.
- `backups(group_key = nil)` → zoznam `{id, group, created_at, reason, plugin_version}` zoradený od najnovšej; poškodená `backup.json` = položka so stavom `:broken` (nezmizne potichu).
- `restore_backup!(backup_id, plugins_dir:)` → rovnaké predpoklady ako R4.2 krok 1 (bez verzie: záloha z inej verzie pluginu → `:version_mismatch`), **najprv nová záloha** súčasného stavu
  (`reason: 'pred návratom zálohy'`), overenie SHA každého súboru zálohy, zápis bajtov **atomicky** (tmp + rename v rovnakom priečinku, vzor `Materials.deploy_bytes`
  `materials_health.rb:335`) pod zámkom knižnice, potom R6 a `after_import!` ako pri prevzatí.
- **Udržiavanie:** po úspešnej zálohe ostane **5 najnovších na skupinu** (§12 D4); mazanie len vlastných priečinkov podľa vzoru mena (nikdy výpis koreňa — F13).
- Celá záloha drží `materials.lock` (súbor riadku); kópie súborov iných zámkov (`hardware_catalog.json`, `templates.json`, `appliances.json`) sa robia **mimo** `materials.lock`
  pod ich vlastným zámkom, postupne (F4).

**R4.4 Zámky** — `LibraryTransfer` berie zámok **cez metódu riadku registra** (`LibraryRegistry::LOCKS` → modul), ale pre `templates.json.lock` a `hardware_catalog.lock`
použije vlastný obal, ktorý **skontroluje návratovú hodnotu `flock`** a výnimku **neprehltne** (S12) — ich dnešné `with_lock` sa nemení (§14).
Reentrancia: obal nesmie nastaviť `@lock_held`/`@lock_depth` modulu; `import_document!` týchto dvoch store-ov preto beží **vo vnútri** obalu a sám zámok neberie (dokumentovať).
- **Verejné `with_store_lock(entry_key) { … }`** (pre U3, PACKAGE_U3 §12 D6): zámok riadku registra (`lock`) pre knižnicu **aj prílohový riadok** (`appearances` → `materials.lock`,
  `appliance_files` → `appliances.json.lock`, `template_previews` → `templates.json.lock`); neznámy kľúč alebo riadok bez zámku → `ArgumentError`; nezískaný zámok → `IOError`
  (nikdy blok bez zámku). U3 v ňom ukladá prílohy **pred** `import_group!`. Vnorenie dvoch rôznych zámkov (F4) → `IOError`.

**R4.5 Lokálny stav synchronizácie (B7, obálka pre U3)**
- `sync_state` → `{'std' => SYNC_STD, 'meta' => Hash, 'groups' => {group_key => Hash}}` (chýbajúci súbor = prázdne `meta` aj `groups`; zlý tvar s dobrou `.bak` = čítanie zo zálohy, zápisy vypnuté — vzor R-37
  `read_valid` + `degraded?` so `shape_check`).
- `update_sync_state!(group_key, entry)` → `true`/`false`: pod `materials.lock`, `reload!`, brána degradovaného súboru, zapíše `entry` (Hash) **celý** pre skupinu; obsah `entry`
  (prevzatá verzia, odtlačky, …) **definuje U3** — U2 overí len, že `group_key` je v `GROUPS` a `entry` je Hash serializovateľný do JSON. `meta` nemení.
- `update_sync_meta!(attrs)` → `true`/`false`: údaje **tohto PC** oddelene od skupín — kľúče `pc_id` (String), `drive_root` (String), `admin` (true/false); iný kľúč alebo typ → `false`
  bez zápisu; zlúči `attrs` do `meta` (chýbajúci kľúč ostane), ten istý zámok a brány ako `update_sync_state!`, `groups` nemení. Význam hodnôt (ako vzniká `pc_id`, kedy `admin`) **definuje U3**.

**R4.8 API pre U3/U5 (súhrn):** `export_group` · `import_group!` · `create_backup!` · `backups` · `restore_backup!` · `sync_state` · `update_sync_state!` · `update_sync_meta!` ·
`with_store_lock` · **`peek_group`** · **`backup_peek`** · **`local_fingerprint`** (15.10; `restore_backup!` s `seen_fingerprint:`) · **`import_done`** · **`ack_import_done!`** (15.9; `import_group!` s voliteľnými `tag:` a `replacements:`) · `import_allowed?` · `export_allowed?` · `compare_versions` · `recover_pending!` · `canonical_bytes` · `fingerprint`; z registra `groups` · `members` · `depends_on` · `dependents`. Nič iné U3/U5 z U2 nevolá.

**R4.6 Kanonické bajty a odtlačok**
- `canonical_bytes(doc)` = `JSON.generate` nad kópiou s **rekurzívne zoradenými kľúčmi** Hash-ov (polia v pôvodnom poradí), UTF-8, bez medzier. `fingerprint(doc)` = SHA-256 hex.
- Rovnosť platí len pri **rovnakej verzii pluginu a Ruby** (R14, R10 — obe PC SketchUp 2026); formát desatinných čísel je formát `JSON.generate` danej verzie (§9 R7).

**R4.9 Obnova po páde procesu uprostred prevzatia (A1 S1)**
- Nový riadok registra `library_import_pending` · `file: 'library_import.pending.json'` · `kind: marker` · `sync: local` · `lock: 'materials.lock'`, `lock_mode: 'module'` · `bak: true` ·
  `writers: core/library_transfer.rb`. Obsah `{'pid', 'exe', 'group', 'backup_id', 'started_at'}`.
- `import_group!` / `restore_backup!` ho zapíšu **po** úspešnej zálohe a **pred** prvým zápisom knižnice; zmažú ho až po `after_import!` a značkách UNI (úspech) alebo po úspešnom
  návrate zo zálohy. Pri `:failed_restore_failed` **ostáva**. Žurnál živého procesu na začiatku importu → `:busy`.
- **`recover_pending!(plugins_dir)`** — `main.rb` ho volá v boot bloku **ako prvé, pred `Materials.boot_cutover!`** (`main.rb:614-621`), teda pred prvým čítaním knižníc; vlastný
  `begin/rescue`. Žurnál + proces `pid` nežije (`Updater.lease_alive?`, `updater.rb:717`) → **návrat** zo zálohy `backup_id` (`restore_backup!` bez kontroly leases; R6 a `after_import!`
  platia), zmazanie žurnálu, `last_recovery` pre U5 („Prevzatie sa prerušilo — knižnica vrátená na stav pred ním"). Dokončenie sa **nerobí** (packet sa neukladá). Návrat zlyhá →
  žurnál ostáva, `pending_issue` (veta s ID zálohy) — U5 ju ukáže červeno a ponúkne len „Vrátiť zálohu".

**R4.10 Odvodené výpočty po prevzatí (A1 S4)** — sonda: `core/budget.rb`, `sheet_estimate.rb`, `sheet_layout.rb`, `bom.rb` **nedržia stav v module** (žiadna `@` premenná;
`BudgetStore` len `@in_write`); Štúdio počíta odhad platní, plán aj rozpočet nanovo v každom `push_state` (`ui/studio_dialog.rb:1647-1723`). Zneplatniť treba len **zobrazenie**:
`import_group!`/`restore_backup!` vrátia `'refresh' => true` a **U5 povinne** zavolá `push_state(bump: true)` otvorených okien (nová generácia zahodí akcie zo starých dát).
**Guard:** tieto štyri súbory bez stavových `@` premenných (nová cache = vlastné zneplatnenie + úprava guardu). Zákazky na prestavbu = §14 N5; **S4 ostáva čiastočne otvorené** (§15 A7).

**R4.7 Kódy výsledkov** (Symboly; vyhodnocovať cez `case`, nie pravdivosť): `:ok :not_ok :missing :invalid :newer :local_newer :missing_attachments :version_mismatch :other_instance
:other_instance_unknown :busy :backup_failed :write_failed :failed_restored :failed_restore_failed :unhealthy_restored :unknown_group :broken :busy_snapshot`. Každý s **jednou slovenskou vetou**
(funkčne, bez cesty v texte okrem `:failed_restore_failed`, kde menuje ID zálohy) — U5 ich zobrazí bez úprav.

### R5 · Verzia pluginu podľa R18 (dve brány, A1 S5)

- `import_allowed?(v)` = `v == Engine::VERSION` (**Aktualizovať** len pri rovnakej verzii; volá R4.2 krok 1, U3, U5 veta O7).
- `export_allowed?(disk_v)` = `disk_v.nil?` ∨ `compare_versions(disk_v, Engine::VERSION) <= 0` (**Odoslať** blokuje len knižnica na Disku z **novšieho** pluginu).
  Druhú podmienku R18 (správcova verzia pluginu ešte nie je na Disku pre druhé PC) posudzuje **U3** nad distribúciou D-52 — U2 dáva len `compare_versions(a, b)` (−1/0/1, číselne po
  segmentoch `x.y.z`, neplatný reťazec → `ArgumentError`). Tieto tri metódy sú **jediná** autorita; `compatible?` sa nezavádza. Test: `0.18.1`/`0.18.10`/`0.19.0`, rovnosť, `nil`, neplatný.
- STANDARD nový odsek **§13.4 „Zdieľanie knižníc"** (3 vety: R18 dve brány; dopredné brány store-ov ostávajú poistkou; dôvod A4 B3).

### R6 · Značky UNI po prevzatí Materiálov (B14)

- Po úspešnom `import_document!` skupiny `materials` (a pri `restore_backup!` Materiálov) **pod `materials.lock`** zapísať `write_uni_marker` aj `write_drawer_uni_marker` (S13) —
  **vždy**, bez ohľadu na to, či prevzatý katalóg UNI záznamy má. Význam: obsah UNI určuje správca; seed ich na prijímajúcom PC nikdy nedoplní. Značky sa **neprenášajú** (`local`).

### R7 · Dokumentácia (na mieste, nie na koniec súboru)

- kniznice.md: odsek `library_registry.rb` (skupiny, API, vynútenie; prepísať „Čo register nerobí"), **nový odsek `library_transfer.rb`**, riadky §3 nových riadkov registra, F5/F12 „rieši U2" (T8).
- model-a-identita.md `json_file_store.rb` (R2); odseky dotknutých store-ov (materials, hardware, templates, supplier_settings, appliances) — jedna veta o R3 a o tom, že bežné zápisy sa nemenia.
- ARCHITEKTURA.md riadok `library_transfer.rb` (guard) · rozsirovacie-body.md scenár 7 („nový zdieľaný store = `group` + R3 + riadok R3.4") · STANDARD §13.1 `SYNC_STD`, `BACKUP_STD` = 1 (Schéma áno), §13.4 (R5).

## 7 · Testy a DoD

**Nové sady** (vzor `tests/pure/test_h16_kniznice.rb`, `test_r37_tvar_suborov.rb`; sandbox cez `Materials.test_dir_override` a `ApplianceCatalog.test_dir_override`):

- `tests/pure/test_u2_register.rb` — R1 (tvar, skupiny, závislosti, negatívy) + R2 (odmietnutie, prejdenie, písmená, mimo koreňa, bez `.tmp-*` po odmietnutí).
- `tests/pure/test_u2_store_kontrakt.rb` — pre **každý** store (U2a dva, U2b sedem): (a) `export → import → export` = rovnaké kanonické bajty; (b) **import nepečiatkuje** — dokument so
  `seed_version` nižším o 1 (v rozsahu brány) sa zapíše s ním, `std`/`schema` bez zmeny, neznámy top-level kľúč prežije; (c) dopredná brána (`std+1`, `schema+1`, `seed_version+1`)
  → `:newer`, súbor bez zmeny (SHA); (d) zlý tvar / duplicitné ID / nekonzistentný duplák → `:invalid`, bez zmeny; (e) lokálny novší súbor → `:local_newer`; (f) degradovaný lokálny
  súbor (zlý primár + dobrá `.bak`) → import prejde; (g) `after_import!` vynuluje stav (napr. HardwareCatalog `:read_only` pred importom → `:ok` po ňom; `@price_proposals` prázdne)
  a **nenuluje zámkový čítač** (volanie počas držaného zámku inej vetvy testu → reentrancia ostane funkčná); (h) export z `:degraded`/`:read_only` → `:not_ok`.
- **B1 regresia (U2a, kľúčová):** katalóg A s `appearance` X na skupine; import katalógu B s `appearance` Y (súbor `.skm` Y pripravený) → na disku **Y**; bez súboru Y → `:missing_attachments`
  a na disku A bez zmeny. Rovnaký vstup cez `Materials.write` → X (R0.4 ostáva zelený).
- `tests/pure/test_u2_transfer.rb` — R4: verzia (`'0.18.1'` vs `'0.18.2'` → `:version_mismatch` pred akýmkoľvek zápisom), druhá inštancia (stub `Updater.live_leases` → `[1234]`,
  `Refused`), `PriceRefresh.running?` → `:busy`; **všetko-alebo-nič** (zlyhanie zápisu 2. dokumentu skupiny cez stub → oba dokumenty bajtovo pôvodné, `:failed_restored`);
  `:unhealthy_restored`; záloha (obsah, SHA, `.bak` degradovaného, `.partial` po simulovanom páde uprace ďalší beh, 5 najnovších); `restore_backup!` (nová záloha pred návratom,
  overenie SHA — poškodený súbor zálohy → odmietnutie bez zápisu); značky UNI po Materiáloch (zmazaný UNI záznam po `ensure_uni_records!` nepribudne); `sync_state` (tvar, degradovaný
  súbor, neznáma skupina); `update_sync_meta!` (zlúčenie, zlý kľúč/typ → `false` bez zápisu, `groups` nedotknuté a naopak `update_sync_state!` nemení `meta`); `with_store_lock`
  (prílohové riadky dostanú zámok svojej knižnice, neznámy kľúč → `ArgumentError`, stub `flock` → `false` = `IOError` a blok sa nevykoná, vnorenie dvoch zámkov → `IOError`);
  kanonické bajty (poradie kľúčov nemení odtlačok, poradie poľa áno); **S2** export pri chýbajúcom primári s `.bak` a pri degradovanom → `:not_ok`; **S3** stub zápisu medzi
  prechodmi → opakovanie, trvalá zmena → `:busy_snapshot`; **S1** podproces prevzatia ukončený `exit!` po 1. dokumente skupiny (vzor `tests/h16_first_use.rb`) → nový proces
  `recover_pending!` → oba súbory bajtovo pôvodné, žurnál preč, `last_recovery`; žurnál živého `pid` ostane; zlyhaný návrat → `pending_issue`; **S4** guard R4.10.
- **Zdrojové guardy:** `import_document!` žiadneho store-u nevolá `normalize*`, `merge_seed*`, `persist_seed_merge!`, `prepare_appearance_write!`, `write_unlocked`, `write_list` ani bežné
  `write` (Grep tela metódy, vzor `test_h10b_rady.rb:462`); okná (`ui/`) nevolajú `import_document!` ani `import_group!` (do U5).
- **H16 sada** zelená s novými riadkami a `WRITE_SITES` (`core/library_transfer.rb` — počet podľa implementácie, dôvod „zálohy library_backups/ a library_sync.json");
  `test_h13_rozsirovacie_body.rb` (nové `STD` v §13.1).

**DoD:** `ruby tests/run_all.rb` zelené · JS sady každá zvlášť (nemenia sa, len potvrdiť) · R0 goldeny bez regenerácie · `ruby scripts/encoding_guard.rb --repo` · **export test `P == K`**
· PR uvedie počty testov, výsledok R0.3, export testu a skutočný diff kódu pluginu (poistka §2).

## 8 · In-SU

Nie je brána (S-spúšťače sa nemenia — CLAUDE.md, Testovanie). **Odporúčaný jeden beh** `scripts\run_su_tests.ps1 -CloseWhenDone` na finálnej hlave **U2a** ako DoD: vynútenie
registra (R2) beží v SketchUpe pri každom zápise knižníc; beh potvrdí, že žiadny zápis v in-SU scenároch (materiály, vzhľady, šablóny, kovanie) neskončí `UnregisteredPath`.
PR uvedie hlavu behu. U2b bez behu (len nové cesty bez volajúceho).

## 9 · Riziká

| # | Riziko | Dopad | Opatrenie |
|---|---|---|---|
| R1 | Vynútenie (R2) odmietne zápis, ktorý dnes prechádza | knižnica sa prestane ukladať | R0.3 pred R2; H16 T4/T6; in-SU beh U2a; export test |
| R2 | Import obíde brány bežného zápisu | strata dát po prvom bežnom zápise | brány S9 + dopredná brána + návrat pri ne-`:ok` |
| R3 | Pád alebo zlyhanie uprostred skupiny | zmes z dvoch PC | záloha pred zápisom, žurnál a obnova pri štarte (R4.9), `:failed_restore_failed` |
| R4 | Reset stavu pod zámkom (S11) | zablokovaný SketchUp | `reset_after_import!` bez zámkových čítačov; test (g) |
| R5 | Usadenie na prijímajúcom PC prepíše prevzatý dokument | falošné „lokálne zmeny“ | export usadzuje; R14; odtlačky po `after_import!` |
| R6 | Súbežná úprava počas exportu | nesúdržný snímok | dva prechody s porovnaním (R4.1), `:busy_snapshot` |
| R7 | Kanonické bajty závislé od Ruby/JSON (`Float`) | falošný rozdiel | R14 + R10; formát čísel sa vedome nenormalizuje |
| R8 | `PriceRefresh` / kontrola ceny dobehne po prevzatí | stará cena prepíše prevzatú | `:busy`; revízie riadkov (`base_rev`); `@price_proposals` vymazané |
| R9 | Otvorené okno uloží starý obsah po prevzatí (B6) | prepis prevzatých dát | bariéra v U5; revízie `save_library!`/`row_rev` |

## 10 · Smoke checklist pre Michala

U2 nemá viditeľnú funkciu — plný smoke až v U5. Po mergi U2a aj U2b: v Štúdiu ulož zmenu v Materiáloch, Kovaní, Šablónach a Nastaveniach rozpočtu
a otvor Spotrebiče → všetko sa uloží a ostane ako predtým. Hláška „nepodarilo sa uložiť" kdekoľvek → nahlás (kontrola súpisu zastavila zápis, ktorý mal prejsť).

## 11 · Checklist uzáveru (každá časť zvlášť)

- Bump **patch** v `noxun_engine.rb` aj `main.rb` (VERSION 2×); `?v=` v `ui/*.html` = VERSION (guard), hoci sa css/js nemení.
- Testy zelené (§7 DoD); R0 goldeny bez regenerácie.
- Odseky architektúry na mieste (R7) + **Grep tvrdení o zoznamoch**, ktoré dávka mení: `KINDS`/riadky súpisu, `WRITE_SITES`, „Čo register nerobí", zoznam volajúcich `degraded?`
  v odseku `json_file_store`, STANDARD §13.1 (nové `STD`), rozcestník ARCHITEKTURA.md.
- `SYSTEM/STAV.md` prepísať (verzia, posledný beh testov, „Robí sa" / „Ďalší krok" = U2b resp. U3) · KRONIKA odsek navrch „Záznamy dávok" (U2a/U2b, PR, predrecenzia, audit) ·
  `SYSTEM/PLAN.md` riadok dávky v bloku UPDATE s ✅ a číslom PR (`PR #?` → samostatný commit s číslom).
- **DOGFOODING D-48 ostáva otvorené** (uzavrie U5); do D-48 sa nič nepresúva. Predrecenzia v PR popise.

## 12 · Rozhodnutia — potvrdené orchestrátorom 17.10.2026

- **D1 · Výrobná/cenová ÁNO** (orchestrátor rozhodol inak než návrh autora): import zapisuje katalógy, z ktorých sa počítajú ceny a rozmery → brány výrobnej dávky + **export test `P == K`** (§5).
- **D2 · Dopredná brána aj v store-och** (✅) — store kontroluje formát, U3 verziu pluginu; poistka proti dokumentu, ktorý by brány tvaru prepustili (AbsRules novší `std`).
- **D3 · `textures/` bez skupiny v U2** (✅) — skupinu Materiály a `sync: shared` jej dá **U4** spolu s kopírovaním fotiek (R15).
- **D4 · 5 lokálnych záloh na skupinu** (✅) — U5 ukáže najnovšiu a „ďalšie…".
- **D5 · Logická súdržnosť skupiny** sa nad rámec brán store-ov nekontroluje (dnes vie vzniknúť aj ručne, ORANGE); rieši ju jeden správca + „naraz alebo vôbec".
- **D6 · Import povolený nad degradovaným/poškodeným lokálnym súborom** (✅), okrem súboru z novšej verzie; záloha berie aj `.bak`.
- **D7 · Rez U2a/U2b** s jedným auditom (rámec ide s Materiálmi — B1 má test v 1. PR). **Riadky `library_backups/` a `library_sync.json` sú v U2a** (U3 ich len plní).
- **D8 · `reason` zálohy** = voľný text volajúceho, bez prekladu.
- **D9 · Vynútenie platí pre celý koreň** (✅), nie len pre zdieľané súbory.

## 13 · Otázky pre Michala

**Žiadne** — R1–R17 a O1–O8 pokrývajú U2.

## 14 · Nálezy mimo scope

- **N1 · F3 zámky:** `HardwareCatalog.with_lock` nekontroluje `flock` (`hardware_catalog.rb:128`), `TemplateStore.with_lock` prehltne výnimku a vráti `false` (`templates.rb:651-653`) —
  bežné zápisy by na súborovom systéme bez zámkov bežali bez ochrany. U2 sa im vyhne (R4.4); oprava bežných ciest = samostatná fix dávka (mení správanie okien → vlastná predrecenzia).
- **N2 · `reset_state!` HardwareCatalog/ApplianceCatalog** nulujú zámkový čítač (S11) — komentár „nikdy pod zámkom".
- **N3 · `Materials.write` ignoruje `appearance` z payloadu** (B1, zámer pre okná) — povedať to v komentári `materials.rb:309`.
- **N5 · Zákazky na prestavbu po prevzatí** (A1 S4: hrúbka, ABS) — označiť ako neaktuálne; návrh do U5/Kontroly (ceny kryje R17).
- **N4 · F10 `Debug.report`** — `fingerprint` per skupina = porovnanie Michal vs. Lucia; návrh do U3.

## 15 · Audit návrhu — zapracovanie (Codex `gpt-6-astra`, 17.10.2026; [AUDIT_U2_raw.md](AUDIT_U2_raw.md)) · MÁ PREDNOSŤ

**15.0 Princíp „nikto iný nezapisuje" (smer orchestrátora, základ A1 a A6).** `export_group`, `import_group!`, `restore_backup!` aj `rollback!` bežia len keď: (a) **žiadna iná živá
inštancia SketchUpu** — `Updater.live_leases` prázdne na začiatku **a znova tesne pred prvým zápisom** (po zápise žurnálu, vzor neskorej kontroly `updater.rb:970`), inak odmietnuť
(`:other_instance`); (b) **okná knižníc sú zatvorené** — `LibraryTransfer::LIBRARY_DIALOGS` (Štúdio, Inspector a satelitné okná knižníc podľa `ui-lifecycle.md` „Satelitné okná";
presný zoznam NEOVERENÝ, implementátor ho uvedie v PR) a každý odpovie `dialog_closed?` (`ui/studio_dialog.rb:184`, `ui/panel.rb:67`; okno bez metódy ju dostane v U2c — fail-closed:
bez odpovede = otvorené) → inak `:dialogs_open` (bariéru, ktorá ich zatvorí, robí U5); (c) celá operácia beží **synchrónne na hlavnom vlákne** bez `UI.start_timer` a bez
čakania na sieť (`PriceRefresh.running?` → `:busy`; asynchrónne callbacky Demosu sa nemôžu vložiť medzi kroky). Tým v procese ani mimo neho nie je zapisovateľ, ktorý rešpektuje
zámky — postupné čítanie pod zámkami je jedna revízia skupiny a **A→B→A nenastane**. Dva prechody so SHA (R4.1) ostávajú ako lacná poistka. Priznaný zvyšok: zapisovateľ mimo
pluginu (ručný editor, antivírus) — rovnako ako `json_file_store` (vedome sa nerieši).

| Nález | Verdikt | Zapracovanie |
|---|---|---|
| **A1 BLOCKER** nedokončený import neblokuje používanie; druhá inštancia | platný | **15.1** |
| **A2 BLOCKER** návrat neobnoví neprítomné súbory ani značky; normalizácia po návrate | platný | **15.2** |
| **A3 BLOCKER** usadenie pred kontrolou primára (šablóny `migrate!` z `.bak`, `templates.rb:478`) | platný | **15.3** |
| **A4 FIX** opakovateľný návrat so zachovaným `backup_id` | platný | **15.4** |
| **A5 FIX** rotácia zmaže cieľ obnovy | platný | **15.5** |
| **A6 FIX** dva odtlačky nedokazujú interval (A→B→A); konzistencia zálohy | platný v pôvodnom návrhu, **vyriešený odstránením súbežných zapisovateľov** (15.0) | **15.6** |
| **A7 NOTE** S4 len čiastočne; S5 uzavreté | platný | **15.7** |

**15.1 Blokovanie pri nevyriešenom žurnáli (A1).** `LibraryTransfer.pending_block(entry_key = nil)` → `nil` | veta (žurnál existuje a nie je to bežiaca operácia tohto procesu;
čítanie `File.exist?` + obsah, cache max 1 s ako `JsonFileStore`). Kým platí, pre **knižnice skupiny zo žurnálu**: (1) **zápisy odmietnuté** — brána v `import_document!` a v bežnej
zápisovej ceste každého store-u skupiny (jeden riadok pred zápisom pod zámkom, vzor `degraded_write_blocked?`; zahŕňa seed, seed-merge, `migrate!`, `boot_cutover!`, UNI doplnenie);
(2) **výpočty a exporty odmietnuté s vetou** „Knižnica <skupina> je po prerušenom prevzatí zablokovaná — otvor O plugine": spoločný vstup exportov (`ExportPrep`) a výpočet rozpočtu
(`ProductionCore.do_budget*`) vrátia chybu namiesto výsledku; stavba/prestavba skrinky cez akcie panela sa odmietne v ich spoločnom dispečeri (presné miesto NEOVERENÉ — ak je to
Ruby spúšťač zo zoznamu CLAUDE.md, **in-SU beh je brána tej časti**). Čítanie pre zobrazenie v oknách ostáva (U5 ukáže červený pruh). **Druhá inštancia pri štarte:** `recover_pending!`
so živým vlastníkom → `:owner_alive`, nič neobnovuje a boot blok **preskočí** `Materials.boot_cutover!`, `ensure_uni_records!`, `ensure_drawer_uni!` (`main.rb:614-660`); blok trvá, kým
žurnál nezmizne. **Testy:** druhý proces so žurnálom a živým vlastníkom (stub `lease_alive?`) → SHA súborov skupiny bez zmeny, `do_budget`/export vrátia vetu; zlyhaný návrat → blok trvá
aj po reštarte; po úspešnom `recover_pending!` blok zmizne.

**15.2 Úplný stav v zálohe a presný návrat (A2).** `backup.json` `files` nesie pre **každú** cestu skupiny — primár, `.bak` každej knižnice a pri `materials` aj `uni_seed.done`,
`drawer_uni_seed.done` — buď `{'state' => 'present', 'sha256'}` (bajty v `files/`), alebo `{'state' => 'absent'}`. Návrat: `present` → atomický zápis bajtov, `absent` → zmazanie
súboru, ak medzitým vznikol. Po návrate len `reset_after_import!` + `reload!` + posúdenie — **bez usadenia** (žiadne `load`, seed-merge ani `migrate!`) a **bez R6** (značky sa vrátia
podľa zálohy). R6 platí len pre úspešné prevzatie. **Testy:** pôvodne chýbajúci primár s `.bak`, degradovaný primár, chýbajúce značky UNI → po vynútenom zlyhaní 2. člena sú všetky
súbory a značky bajtovo (aj neprítomnosťou) ako pred importom a SHA sa po `reset_after_import!` nezmení.

**15.3 Kontrola primára pred usadením (A3).** `export_document` krok 0 — **pred** akoukoľvek čítacou cestou s vedľajšími zápismi: primár existuje, parsuje sa a nie je degradovaný
(`JsonFileStore.degraded?` s tvarom, kde ho store má); inak `[:not_ok, …]` / `[:missing, …]` (chýba aj `.bak`) **bez volania** `load`. Usadenie (R3.1 krok 1) až potom; kontrola R3.1
krok 3 sa po usadení opakuje. **Regresný test:** šablóny — chýbajúci primár + platná `.bak` so starším `std` → `:not_ok`, primár **nevznikne**; rovnako Materiály a Spotrebiče.

**15.4 Opakovateľný návrat `rollback!(backup_id)` (A4).** Interná metóda: **bez novej zálohy a bez nového žurnálu**; žurnál nesie `phase` (`importing` → pred 1. zápisom návratu
`rolling_back`) a **pôvodné** `backup_id` až do konca. Návrat podľa 15.2 je idempotentný → pád počas neho = `recover_pending!` ho zopakuje z toho istého `backup_id`. Použitie: R4.2
kroky 5 a 7, `recover_pending!`. Verejné `restore_backup!(target)` (O5): nová záloha B → žurnál `{phase: importing, backup_id: B}` → zápis cieľa podľa 15.2 → pri páde alebo zlyhaní
`rollback!(B)`. **Testy:** pád (podproces `exit!`) v `importing` aj v `rolling_back` → po štarte skupina = stav zálohy; dvojitý `recover_pending!` = rovnaký výsledok.

**15.5 Rotácia po transakcii (A5).** Mazanie nad 5 na skupinu beží až **po zmazaní žurnálu** a nikdy neodstráni zálohu odkazovanú žurnálom ani cieľ práve bežiaceho `restore_backup!`.
**Test:** plná história 5, návrat k najstaršej → prebehne, potom ostane 5 najnovších.

**15.6 Snímok skupiny (A6).** R4.1 a záloha (R4.3) čítajú členov postupne pod ich zámkami **za podmienok 15.0**; dva prechody so SHA ostávajú poistkou (nezhoda = niekto zapisuje
napriek 15.0 → `:busy_snapshot`). Tvrdenie „spoločné okno" v R4.1 sa nahrádza: konzistenciu zaručuje 15.0, nie porovnanie. **Testy:** okno knižnice otvorené (stub `dialog_closed?` →
`false`) → `:dialogs_open` pred čítaním; druhá inštancia → `:other_instance`; operácia nevolá `UI.start_timer` (zdrojový guard).

**15.7 S4 (A7).** Zobrazenie (R4.10) uzavreté; **označenie zákaziek na prestavbu po zmene hrúbky alebo ABS je čiastočne otvorené** — uzavretie podmienkou smoke/in-SU U5 (prevzatie
Materiálov so zmenenou hrúbkou nad existujúcou zákazkou → Kontrola ju ukáže ako neaktuálnu). R17 (ceny) sa nemení. S5 uzavreté (R5).

**15.8 Rez po audite (prednosť pred §2).** Odhad rastie o ~170 riadkov (žurnál a blokovanie, presný návrat, `rollback!`, podmienky 15.0) na **~880**:
**U2a · register a store-y Materiály** (R1, R2, R3 pre Materials a AbsRules, R6, 15.3) ~320 · **U2b · transakcia** (`LibraryTransfer`: R4, R5, 15.0–15.6, brány blokovania v store-och
skupiny Materiály, `main.rb` boot) ~400 · **U2c · ostatné store-y** (R3 pre 7 modulov + ich brána 15.1 + `dialog_closed?` chýbajúcim oknám) ~300. Každá časť vlastný PR, delta audit
na 15.0–15.6 pred U2b. Export test `P == K` platí pre všetky tri; in-SU podľa 15.1 (dispečer stavby).

**15.9 Požiadavky U3 a U4 na U2 (po ich auditoch, 17.10.2026)** — mená záväzné podľa [PACKAGE_U3.md](PACKAGE_U3.md) §12 D10/D11, R-J5 a [PACKAGE_U4.md](PACKAGE_U4.md) §15.1.

- **(1) `peek_group(group_key)`** (U3 D10) → `[:ok, {'documents' => {entry_key => doc}, 'fingerprints' => {entry_key => sha256}}]` | `[:unknown, veta]`. Len čítanie: **bez bariéry**
  15.0 (smie pri otvorených oknách), bez čakania na zámok (`LOCK_SH | LOCK_NB`, obsadený → `:unknown`), **bez akéhokoľvek zápisu** (žiadne `load`, seed, seed-merge, `migrate!`,
  UNI, zmena stavu modulov), bez `Sketchup`, primár **bez fallbacku na `.bak`**. `:ok` len keď každý primár skupiny existuje, parsuje sa, nie je degradovaný (kontrola 15.3)
  a je **usadený** = rovnaký, aký by vrátil `export_document` (čisté posúdenie: brána R3.2 krok 2 prejde a store-ová predikcia usadenia nehlási potrebu zápisu — `seed_version`/`std`/
  `schema` = konštanty tejto verzie, pri šablónach `std == STD`; ak store čistú predikciu nemá, `:unknown`). Inak (chýba, poškodený, pred migráciou, `pending_block`) `:unknown`.
  Odtlačok = `fingerprint` (R4.6); prílohy sa nečítajú.
- **(2) Doklad dokončenia** (U3 D11, R-J5): `import_group!(…, tag: nil)`; s `tag` zapíše po úspechu skupiny (po `after_import!` a R6, **pred** zmazaním žurnálu) trvalý záznam
  `library_import.done.json` = `{tag => {'tag', 'group', 'fingerprints', 'finished_at'}}` (nový riadok registra `library_import_done`, `kind: marker`, `sync: local`, `materials.lock`,
  `bak: true`, writer `core/library_transfer.rb`). `import_done(tag)` → Hash | `nil`; `ack_import_done!(tag)` záznam zmaže (`true`/`false`). Žurnál si drží `tag`; `recover_pending!`
  vo fáze po zápise dokladu (prvok `phase: 'done'`) len zmaže žurnál — doklad ostáva do `ack`. Bez `tag` sa nič nezapisuje (spätná kompatibilita).
- **(3) Náhrady príloh** (U4 15.1): `import_group!(…, replacements: [])` — položky `{rel, new, old, old_sha256, new_sha256}` sa zapíšu do žurnálu pod `'attachments'` **v tom istom
  zápise** ako `backup_id` (pred prvým premenovaním aj prvým zápisom knižnice; podmienky 15.0 platia). Vykonanie medzi R4.2 krokmi 3 a 4 pod `with_store_lock(row)` každej položky
  cez `LibraryAttachments.apply_replacement!(item)` (dodá U4; `:ok | :failed`, nikdy výnimku); `:failed` → návrat. `rollback!` (15.4) a `recover_pending!` volajú
  `revert_replacement!(item)` — idempotentne podľa stavu súborov; `failed > 0` = návrat zlyhal → žurnál, `pending_issue` a `pending_block` ostávajú. **Úspech:** fáza `committing` →
  `archive_replacement!(item, "library_backups/<backup_id>")` (pôvodný súbor do zálohy prevzatia, `backup.json` `attachments: {rel => sha256}`) → doklad (2) → zmazanie žurnálu.
  Pád v `committing` → `recover_pending!` **nevracia**, len dokončí presuny. Bez `replacements` sa správanie U2 nemení.
- **Testy** (`test_u2_transfer.rb`): `peek_group` — zdravá usadená skupina = odtlačky `export_group`; chýbajúci primár s `.bak`, degradovaný, starší `seed_version`, obsadený zámok,
  `pending_block` → `:unknown`; po volaní SHA všetkých súborov a stav modulov bez zmeny (aj pri otvorenom okne). Doklad — `tag` → `import_done` vráti odtlačky po usadení; pád
  (`exit!`) po zápise dokladu pred zmazaním žurnálu → `recover_pending!` zmaže žurnál, doklad ostane; `ack_import_done!` ho zmaže; bez `tag` súbor nevznikne. Náhrady — pád medzi
  každými dvoma krokmi (žurnál, `cieľ→old`, `new→cieľ`, 1. dokument, archivácia) → po `recover_pending!` cieľ pôvodný (`importing`/`rolling_back`) alebo nový s `old` v zálohe
  (`committing`); stub zlyhania 2. náhrady → návrat aj 1.; zmazaný `old` → `failed`, žurnál a blok ostávajú; dvojitý `recover_pending!` = rovnaký výsledok.
- **Rez:** (1)–(3) patria do **U2b** (+~90 riadkov → ~490; poistka U2b ~550). `LibraryAttachments` je modul U4 — U2b ho v testoch stubuje presnými menami a volá len ak `replacements` nie je prázdne.

**15.10 Požiadavky U5 na U2 — okno dopadov pred „Vrátiť zálohu"** ([PACKAGE_U5.md](PACKAGE_U5.md) §12 D15, R-J1; mená záväzné).

- **`backup_peek(backup_id)`** → `[:ok, {'group', 'documents' => {entry_key => doc}, 'fingerprints' => {entry_key => sha256}}]` | `[:broken | :missing, veta]`. Len čítanie zálohy
  (`library_backups/<id>/`): `backup.json` + `files/` knižníc skupiny, **overené SHA** podľa `backup.json` (nesúlad alebo nečitateľný súbor → `:broken`; neznáme ID alebo `.partial` →
  `:missing`); knižnica so stavom `absent` (15.2) v `documents` chýba. Bez zápisu, bez bariéry 15.0, bez zámku na čakanie, bez `Sketchup`. Odtlačky = `fingerprint` (R4.6).
- **`local_fingerprint(group_key)`** → String (SHA-256 kanonických bajtov `{rel => sha256 surových bajtov primára | 'absent'}` knižníc skupiny) — čítanie bez zápisu, funguje aj nad
  poškodeným primárom. **Jediná** definícia „lokálneho stavu, ktorý okno ukázalo"; `LibrarySync.diff_documents` (U3) vracia `seen_fingerprint` práve z nej.
- **`restore_backup!(backup_id, plugins_dir:, seen_fingerprint: nil)`** — po podmienkach 15.0 a **pod zámkami** (pred novou zálohou) porovná `local_fingerprint(group)` so
  `seen_fingerprint`; nesúlad → **`[:changed, „Knižnica sa od zobrazenia zmenila — otvor okno znova"]` bez akéhokoľvek zápisu** (ani záloha, ani žurnál). `nil` = bez kontroly
  (interné volania; U5 ho posiela vždy). Kód `:changed` pribúda do R4.7.
- **Testy** (`test_u2_transfer.rb`): `backup_peek` — zdravá záloha = dokumenty a odtlačky zhodné s pôvodnými súbormi; zmenený bajt v `files/` → `:broken`; neznáme ID a `.partial` →
  `:missing`; po volaní SHA koreňa bez zmeny. `local_fingerprint` — zmena jedného primára ho zmení, `.bak` ani prílohy nie; chýbajúci primár = `absent`. `restore_backup!` —
  zhodný `seen_fingerprint` → prebehne; zápis do knižnice medzi `local_fingerprint` a volaním → `:changed`, žiadna nová záloha ani žurnál (výpis `library_backups/` bez zmeny).
- **Rez:** U2b (+~40 riadkov).
