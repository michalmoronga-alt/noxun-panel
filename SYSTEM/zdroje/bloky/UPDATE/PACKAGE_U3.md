# PACKAGE U3 · Jadro synchronizácie zdieľanej knižnice (D-48) — blok UPDATE

> **Stav: NÁVRH — čaká audit návrhu (`codex-audit`)** · 17.10.2026 · písané do zásoby, **implementácia až po smoke PASS bloku 9 HARDENING** a po mergi U2.
> **Autorita:** [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) (R3–R7, R13–R19, mockup O1–O8 — záväzné) · smer [RECONCILE_2026-10-17.md](RECONCILE_2026-10-17.md)
> §2/§3 riadok U3 · rozhranie [PACKAGE_U2.md](PACKAGE_U2.md) R1, R4, R5 (`LibraryRegistry` skupiny, `LibraryTransfer`) · koncept [KONCEPT_UPDATE.md](KONCEPT_UPDATE.md) · dôkazy
> [CROSS_AUDIT_A4_CLAUDE_KOD.md](CROSS_AUDIT_A4_CLAUDE_KOD.md) (B7, B9, B11, B13), [CROSS_AUDIT_A2_GROK.md](CROSS_AUDIT_A2_GROK.md) (B1–B5, B7),
> [CROSS_AUDIT_A3_RESERS_WEB.md](CROSS_AUDIT_A3_RESERS_WEB.md) (FIX 1–4, NOTE 2) · súpis [kniznice.md](../../../../docs/architecture/kniznice.md) · z návrhu 6.9.
> ([SYNC_KNIZNICE_NAVRH_2026-09-06.md](../../next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md)) platí len §3 „Čo ostáva".
> **Trieda Ť · audit-povinná (nový modul) · predrecenzia · U3b výrobná/cenová (export test P == K) · R0 sonda Disku pred zmrazením.** Rez **U3a → U3b** (§2), jeden audit.
> **Stav kódu:** sonda nad `main` `a9e8c79d` (v0.18.1, po #474). U2 ešte nie je v kóde — U3 používa jej API **presne podľa PACKAGE_U2** (§6 R-I).

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 17.10.2026, len čítanie

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | `JsonFileStore.write` píše **dočasný súbor vedľa cieľa** `<súbor>.tmp-<pid>-<thread>` a potom `rename` → na zrkadlenom H: by vznikali temp súbory (A2 B2) | `core/json_file_store.rb:79-97`, `:223-225` | PRAVDA → do H: nikdy cez `JsonFileStore` |
| S2 | `.bak` sa točí pri každom zápise → nie je záloha R4 (A4 B7) | `json_file_store.rb:190-209` | PRAVDA → zálohy U2 R4.3 |
| S3 | `JsonFileStore.read` má sekundovú cache podľa (mtime, veľkosť) | `json_file_store.rb:12`, `:28-48` | PRAVDA |
| S4 | `LibraryRegistry` = čisté dáta, `shared` 12 riadkov, **skupiny ani háčiky zatiaľ nemá**; `root` = `Materials.dir` | `core/library_registry.rb:85-195`, `:234-262` | PRAVDA → skupiny dodá U2 R1 |
| S5 | `Materials.dir` = `%APPDATA%\NOXUN\Engine`, testy `test_dir_override` | `core/materials.rb:228-239` | PRAVDA |
| S6 | Vzor zámku: `File.open(lock,'a')` + `flock`, `false` = výnimka | `materials.rb:503-528` | PRAVDA (U3 berie `LOCK_EX \| LOCK_NB`) |
| S7 | `Updater.live_leases(plugins_dir)` = PID ostatných živých inštancií, nezistiteľný stav = `Refused` (fail-closed); lease zapisuje loader | `core/updater.rb:751-787`, `noxun_engine.rb:150-168` | PRAVDA → volá ho U2 `import_group!` |
| S8 | `Updater.check` číta len hlavičku loadera, `newer/same/older` | `updater.rb:871-889`, `:239-263` | PRAVDA → R-G2 (R18) |
| S9 | Vzor manifestu `{rel => {size, sha1}}`, `safe_relative!`, `refuse_link!`, stropy `MAX_FILES`/`MAX_TOTAL_BYTES` | `updater.rb:185-186`, `:332-345`, `:377-391`, `:395-436` | PRAVDA → vzor pre manifest verzie |
| S10 | Čítanie s limitom žije **v UI**: vo vlákne len súborové I/O, poll 0,2 s, deadline 4 s, vlákno sa nezabíja, single-flight na cestu, háčiky `test_clock/test_spawn/test_schedule` | `ui/supplier_settings_dialog.rb:57-58`, `:354-423`, `:748-765` | PRAVDA (A4 B13) |
| S11 | Guard D-52b pripína **text** `updater_worker` regexom | `tests/pure/test_d52b_updater_ui.rb:1072-1073` | PRAVDA → updater sa nepresúva (D3) |
| S12 | SketchUp API len z hlavného vlákna | `docs/SKETCHUP_PRAVIDLA.md` „Sieť a systém" | PRAVDA |
| S13 | Guard `test_h16_kniznice.rb` pripína `SHARED` a `WRITE_SITES` — nový súbor v koreni = riadok registra | `tests/pure/test_h16_kniznice.rb:44`, `:72`, `:234-246`, `:855-856` | PRAVDA |
| S14 | `LibraryTransfer`, `export_group`, `import_group!`, `LibrarySync` v kóde **nie sú** | Grep `noxun_engine/`, `tests/` | PRAVDA → U3b až po mergi U2 |
| S15 | Mená príloh `<uuid>.skm`, `<uuid>/<uuid>_<slug>.<ext>`, `<druh>-<slug>-<sha16>.png` | `kniznice.md` §2; `appliance_catalog.rb:1058-1073` | PRAVDA |

---

## 1 · Cieľ (funkčne)

Pod kapotou vznikne „motor" zdieľanej knižnice — bez okna (okno je U5). Vie: **zistiť stav Disku** (H: chýba / Disk ešte nič nemá alebo sa synchronizuje / v poriadku) bez
zamrznutia SketchUpu · **povedať per skupinu** (Materiály, Kovanie, Šablóny, Dodávateľ a sadzby, Spotrebiče), či je na Disku novšia verzia, či mám lokálne zmeny, či sa verzia
ešte dosťahuje alebo je z inej verzie pluginu · na PC **správcu** (len Michal, R3) **odoslať** zmenené skupiny s poznámkou ako novú nemennú verziu · na každom PC **prevziať**
novšie skupiny celé alebo vôbec (zálohu a návrat robí U2) · pripraviť **zoznam zmien** pre varovanie R4 · ukázať **históriu 5** a **vrátiť** staršiu verziu (= nová verzia).

**Príklad:** Michal odošle Materiály (verzia 15). Disk Lucii dotiahne ukazovateľ skôr než `.skm` súbory → Aktualizovať povie „Materiály sa na Disku ešte synchronizujú —
skús o chvíľu", **nič sa nezmení**; o minútu prebehne prevzatie a jej stará knižnica ostane ako záloha.

## 2 · Rez a odhad — dve časti, sekvenčne z čerstvého `main`, jeden audit návrhu

| Časť | Obsah | Kód pluginu | Testy | Odhad |
|---|---|---|---|---|
| **U3a · čítacia strana** | `core/timed_worker.rb` · `core/library_sync.rb` (mená, cesty, lokálny stav cez U2, správca — čítanie, R18) · `core/library_sync_remote.rb` (sken, stavy Disku, celistvosť, história, cudzie mená) · `status` · `diff` | ~480 | ~600 | 1 deň |
| **U3b · zápisová strana** | `core/library_sync_publish.rb` (založenie správcu, odoslanie, overenie ukazovateľa, zametanie, Vrátiť verziu) · `core/library_sync_take.rb` (staging, prílohy, volanie `import_group!`, výsledok, žurnál) | ~450 | ~650 | 1¼ dňa |

Spolu ~930 riadkov (menej než pôvodne — zálohy, návrat a druhé okno robí U2) → nad ~600 → delenie ostáva. U3a nič nezapisuje mimo lokálneho stavu a môže ísť
aj pred U2 (API U2 v testoch ako stub s presnými menami); **U3b potrebuje U2 v `main`**. **Poistka:** časť nad ~650 riadkov kódu → stop, rozhodne orchestrátor.

## 3 · Scope IN

R0 sonda Disku (skript mimo pluginu) · R-A rozloženie koreňa a mená · R-B lokálny stav a zámok · R-C správca · R-D sken a celistvosť · R-E stavy Disku a čítanie s limitom ·
R-F stav per skupina a kontrola pri štarte · R-G verzia pluginu (R14, R18) · R-H odoslanie · R-I použitie API U2 · R-J prevzatie · R-K zálohy (len cez U2) · R-L história a Vrátiť ·
R-M prílohy (rozhranie pre U4) · R-N zoznam zmien pre R4 · R-O register a dokumentácia.

**Čo z návrhu 6.9. ostáva** (s jedným správcom): nemenné artefakty s jedinečným menom · ukazovateľ zapísaný posledný · prevzatie len celej overenej verzie (§8 bod 1) · JSON +
prílohy ako celok (§8 bod 3 — cez zálohu a návrat U2) · single-flight čítanie bez únikov vlákien (§8 bod 6). **Odpadá:** `parent`/`supersedes`/lineage, konfliktné okno,
rekonštrukcia manifestu, `publish.lock` na Disku, `files/<sha>` naprieč verziami, dvojfázové zametanie, dopredná brána (nahradená R14 `compatible?`).

## 4 · Scope OUT

Okno O plugine, oznámenie pri štarte, bodka, pruh R13, texty varovania R4 (**U5**) · kanonický export/import, zálohy a návrat, druhé okno, UNI značky, reset stavu v pamäti,
skupiny a riadky `library_backups`/`library_sync` v registri (**U2**) · výber príloh per skupina, fotky dekorov, `textures/` (**U4**) · názov zákazky v .skp (**U1**) ·
„Odovzdať správcu…" (O2 „neskôr") · zlučovanie po záznamoch · automatické sťahovanie · zmena cesty koreňa v UI · presun D-52b kontroly verzie na nový primitív (D3, N1).

## 5 · Trieda a brány

- **Trieda Ť:** nový modul (audit-povinné). **Audit návrhu povinný**, jeden pre U3a + U3b (R12: `gpt-6-astra`, úzko — tento package + PACKAGE_U2 R1/R4/R5, `json_file_store.rb`,
  `library_registry.rb`, `updater.rb:185-436, :751-787, :871-889`, `supplier_settings_dialog.rb:354-423, :748-765`). Sonda pred auditom = §0.
- **Výrobná/cenová:** **U3a nie** (len číta). **U3b áno** (orchestrátor 17.10.: zapisuje katalógy, z ktorých sa počítajú ceny a rozmery) — brány výrobnej dávky celé;
  **export test** `scripts\export_test.ps1` **P == K** ako dôkaz, že dávka sama čísla nemení (bez Odoslať/Aktualizovať sa exporty nesmú líšiť).
- **Predrecenzia:** povinná pre U3a aj U3b.
- **In-SU:** spúšťače sa nemenia → **nie je brána**. Fotky okien: nie.
- **R0 sonda Disku:** podmienka **zmrazenia package** (výsledok do §15, prípadná úprava [R0] požiadaviek ako delta audit); nie brána mergu.

## 6 · Požiadavky

### R0 · Empirická sonda Google Disku na oboch PC (A3 NOTE 2) — pred zmrazením package

**Skript mimo pluginu:** `scripts/sonda_disk_d48.rb` (standalone Ruby `C:\Ruby32-x64`, bez `require` pluginu) + spúšťač `scripts/sonda_disk_d48.ps1`. Pracuje **len** v
`H:\Môj disk\NoxunENGINE data\_sonda\<beh>\` (nikdy v `library\`), na konci po sebe uprace. Výstup `%TEMP%\noxun_sonda_disk\<beh>_<role>.csv` + `_summary.txt`.
Roly `-Role writer` (Michal) / `-Role reader` (Lucia), spojené menom behu. Časy = monotónne v rámci PC (hodiny PC sa neporovnávajú).

| Test | Writer robí | Reader meria (poll 0,5 s, max 15 min) |
|---|---|---|
| T1 poradie | priečinok `v000001-<rand>/`: 40 súborov (1 KB JSON, 20× 200 KB PNG, 5× 3 MB, 1× 25 MB) → `manifest.json` → `head-000001-<rand>.json` | čas objavenia a čas **plnej veľkosti + správneho SHA256** každého súboru; prišiel head/manifest pred dátami? |
| T2 rozpísaný súbor | 50 MB písaných 30 s priamo pod finálnym menom | 0 B / čiastočný obsah / `EACCES`/`EBUSY` / nič |
| T3 temp+rename | `x.json.tmp` → `rename` → `x.json` | vidno `.tmp`? obe? len výsledok? |
| T4 súbežný zápis | obaja v tej istej sekunde iný obsah do `clash.json` | presné **mená konfliktných kópií** a kde ležia |
| T5 prepis | 3× prepis `ptr.json` za 2 s | ktorá verzia dorazí, vznikne kópia? |
| T6 mazanie | zmaže starý priečinok verzie počas čítania | chyby čítania, oneskorenie |
| T7 offline | pozastaví synchronizáciu, zapíše T1, po 5 min obnoví | oneskorenie a poradie |
| T8 mená | ASCII aj diakritika, cesta 200+ znakov | doručenie a meno |
| T9 prázdny koreň | — | `File.directory?` koreňa a `library\` počas prvej synchronizácie |
| T10 latencia | — | `Dir.children` + `File.stat` nad 200 súbormi |

**Od výsledku závisí [R0]:** čakanie „ešte sa synchronizuje" (R-D) · regex cudzích mien (R-A3) · `EACCES/EBUSY` = synchronizuje sa (R-D4) · priamy zápis pod finálnym menom
(R-H5) · limity (R-E3) · zametanie počas čítania (R-H7). **Nezávisí:** tvar manifestu, nemennosť verzií, správca, R14/R18, zámky, zálohy. Správanie mimo predpokladov → delta audit.

### R-A · Rozloženie zdieľaného koreňa a mená (A2 B2, A3 FIX 2/4, R5, R11)

- **R-A1 koreň:** per-PC hodnota `drive_root` v meta `sync_state` (R-B1; v texte `<root>`), predvolená `H:/Môj disk/NoxunENGINE data` (R11). Knižnica = `<root>/library/`. Distribúcia D-52 ostáva svojou cestou.
- **R-A2 rozloženie** (jediné mená, ktoré motor zapisuje a uznáva, všetko ASCII; `<skupina>` = kľúče `LibraryRegistry::GROUPS` z U2 R1.2):

```
<root>/library/
  admin-<NNNNNN>-<r8>.json          správca (R-C), nemenný; platí najvyššie NNNNNN
  <skupina>/                         materials | hardware | templates | supplier | appliances
    v<NNNNNN>-<r8>/                  nemenný priečinok verzie
      d/<entry_key>.json             LibraryTransfer.canonical_bytes(doc) z export_group
      a/<sha256[0,24]>.<ext>         príloha, meno z obsahu (ext = [a-z0-9]{1,8} z lokálneho mena, inak 'bin')
      manifest.json                  posledný v priečinku
    head-<NNNNNN>-<r8>.json          ukazovateľ, posledný zo všetkého; nikdy sa neprepisuje
```

  `NNNNNN` = číslo verzie skupiny, `<r8>` = `SecureRandom.hex(4)` per odoslanie (jedinečnosť pri opakovaní po páde).
- **R-A3 cudzie mená [R0]:** čo nesedí s `\Ahead-(\d{6})-([0-9a-f]{8})\.json\z`, `\Av(\d{6})-([0-9a-f]{8})\z`, `\Aadmin-(\d{6})-([0-9a-f]{8})\.json\z` (vnútri verzie len položky
  manifestu + `manifest.json`), je **cudzie**: nečíta sa ako pravda, nemaže sa, vráti sa ako `foreign: [mená]`. Konfliktná kópia `head-000015-ab12cd34 (1).json` nie je ukazovateľ.
- **R-A4 žiadne dočasné súbory v `<root>`** (S1): do `<root>` nikdy `JsonFileStore`, `*.tmp*`, `.bak`, zámky ani staging — tie žijú v `Materials.dir`.
- **R-A5 manifest** `{ std:1, kind:"noxun_library_version", group, version, id, plugin (= packet['plugin_version']), created_at (UTC), by_pc, by_pc_id, note, reverted_from, base,
  documents:{ entry_key => {file:"d/<key>.json", size, sha256 (= fingerprint)} }, attachments:{ "a/…" => {of: entry_key, local: rel, size, sha256} }, group_fingerprint }`.
  Ukazovateľ `{ std:1, kind:"noxun_library_head", group, version, id, manifest_sha256, plugin, created_at, note }`. `note` ≤ 200 znakov, riadiace znaky → medzera (O8).
  `local` = cesta voči `Materials.dir` overená `safe_relative!` (S9) **a** vzorom `children` prílohového riadku (`LibraryRegistry.members`). `group_fingerprint` = SHA256 nad
  `"<entry_key>\0<fingerprint>\n"` zoradenými podľa kľúča (prílohy sa nerátajú — len pribúdajú). Stropy: 5000 súborov, 500 MB na verziu.

### R-B · Lokálny stav a zámok (A2 B3, A4 B7)

- **R-B1 lokálny stav = `LibraryTransfer.sync_state` / `update_sync_state!(group_key, entry)`** (U2 R4.5; súbor `library_sync.json` a jeho riadok registra pridáva **U2**). U3 definuje obsah:
  `entry = { version, id, fingerprint (group_fingerprint po prevzatí/odoslaní — pri prevzatí z `result['fingerprints']` po usadení), plugin, at, origin: take|publish|revert,
  clean, clean_checked_plugin, pending: {target_id, started_at} | nil, attachments_digest }` — pole `attachments_digest` je **rezervované pre U4** (význam, plnenie
  a vplyv na `status`: [PACKAGE_U4.md](PACKAGE_U4.md) R5.1–R5.2); U3 ho len prenáša. Údaje PC cez `LibraryTransfer.update_sync_meta!` (U2 R4.5): `pc_id` (UUID vzniknutý raz),
  `drive_root` (R-A1), `admin` (true = toto PC sa vyhlásilo za správcu, R-C3). Degradovaný stav (U2) = Odoslať aj Aktualizovať odmietnuté s dôvodom.
- **R-B2 zámok operácie** `library_sync.lock` (`Materials.dir`, nový záznam `LibraryRegistry::LOCKS` — pridáva U3): `flock(LOCK_EX | LOCK_NB)`; obsadený → `:busy` „Iné okno práve odosiela
  alebo aktualizuje knižnicu". Drží sa počas celej operácie vrátane vlákna. **Vonkajší** voči zámkom U2 (`materials.lock` a ďalšie berie `LibraryTransfer` vnútri, postupne — F4).
- **R-B3** `pc_name` = `ENV['COMPUTERNAME']` (len zobrazenie). Strata stavu = nové `pc_id` → PC prestane byť správcom (bezpečné zlyhanie).

### R-C · Správca (R3, R19, O2, A2 B1, A4 B11)

- **R-C1** `library/admin-<NNNNNN>-<r8>.json` = `{ std:1, kind:"noxun_library_admin", seq, pc_id, pc_name, at }`; platí najvyššie `seq`. **Dva rôzne `pc_id` s rovnakým najvyšším
  `seq` → `conflict`: Odoslať (aj Vrátiť verziu) vypnuté na oboch PC s vetou o dvoch správcoch, riešenie ručne v „⋯" (U5); Aktualizovať ide ďalej (R19).**
- **R-C2 `admin_state`** ∈ `none` · `self` (Disk menuje toto `pc_id` **a** lokálne `admin == true`) · `other` · `mismatch` · `conflict`. **Odoslať a Vrátiť verziu len pri `self`**;
  `none` → vypnuté na oboch (O2). Správcom sa **nikdy** nestáva „prvý, kto odošle".
- **R-C3 `claim_admin!`** (U3b; U5 po potvrdení): len pri stave Disku `ok`/`empty` a `admin_state == none`; zapíše `admin-000001-<r8>.json` + `update_sync_meta!('admin' => true)`; po zápise znova
  prečíta adresár → iný súbor s rovnakým `seq` → `conflict`. „Odovzdať správcu" = `seq+1` neskôr (mimo).

### R-D · Sken Disku a celistvosť verzie (A3 FIX 1)

- **R-D1 `Remote.scan(root, group_keys)`** — **len súborové I/O**, vo vlákne (R-E). Vráti `{ disk, admin, groups:{ g => {heads, current, history, foreign} } }`. Žiadne
  `Sketchup.*`, `UI.*`, zápis, volanie `LibraryTransfer` ani `JsonFileStore` (guard nad zdrojom).
- **R-D2** aktuálna verzia = najvyššie `NNNNNN` platného ukazovateľa; dva platné s rovnakým číslom a iným `id` → `head_conflict` (nič sa nepreberá, Odoslať vypnuté).
- **R-D3 `verify_version`:** ukazovateľ parsuje → priečinok `id` je → `manifest.json` parsuje, SHA256 = `manifest_sha256`, `group/version/id` sedia → každá položka `documents`
  a `attachments` má presne `size` a `sha256` → `group_fingerprint` sedí. **Ktorékoľvek zlyhanie = `syncing`** („verzia N sa ešte synchronizuje"), nikdy čiastočné prevzatie.
  Zlá cesta, stropy, zlé `kind/std` = `broken` („verzia N je poškodená — požiadaj správcu o nové odoslanie").
- **R-D4 [R0]** `EACCES/EBUSY` pri čítaní súboru verzie = `syncing`; iné I/O chyby = `error` s triedou chyby.
- **R-D5 história** = ≤ 5 najnovších platných ukazovateľov (číslo, dátum, poznámka, plugin, `reverted_from`); celistvosť len na požiadanie.

### R-E · Stavy Disku a čítanie s časovým limitom (A3 FIX 3, A2 B7, A4 B13)

- **R-E1 `disk` ∈** `no_drive` („Disk H: nie je pripojený") · `no_root` („Priečinok NoxunENGINE data chýba alebo sa ešte synchronizuje") · `empty` (`library/` bez ukazovateľov —
  „Na Disku ešte nie je knižnica") · `ok` · `timeout` · `error`. `empty`/`no_root` pri skupine, ktorú toto PC už prevzalo, = **`missing_known`** („Disk neukazuje knižnicu, ktorú
  už máš — synchronizácia možno beží; nič sa nemení"). Prázdny koreň **nikdy** neznamená zmazanú knižnicu.
- **R-E2 `core/timed_worker.rb`** (`Noxun::Engine::TimedWorker`, bez `UI`): `start(key) { blok }` → `{box, started_at, reused}`; **single-flight na kľúč** (živý beh sa zdieľa,
  dobehnutý zahodí — sémantika S10); `state(entry, deadline:, now:)` → `:running | :done | :timeout`; vlákno sa nezabíja; výnimka → `box['error']`; injektovateľné `clock`, `spawn`.
  Poll cez `UI.start_timer` robí volajúci (U5). D-52b updater sa nemení (D3).
- **R-E3 [R0] limity:** sken 4 s, overenie + staging 120 s, odoslanie 180 s.
- **R-E4** vo vlákne len `Remote.*` a kopírovanie H: ↔ staging; `LibraryTransfer.*`, lokálny stav a zámky store-ov **na hlavnom vlákne** (A4 B6). Guard: telá
  `TimedWorker.start` v `library_sync*.rb` volajú len povolené metódy.

### R-F · Stav per skupina a kontrola pri štarte (R6, R7, O4)

- **R-F1 `status(scan, local:)`** — hlavné vlákno; `local` = `fingerprints` z `export_group` per skupina. `state` ∈ `current` · `newer` · `local_changes` (lokálny `group_fingerprint`
  ≠ `entry.fingerprint`) · `newer_and_local` · `syncing` · `broken` · `plugin_newer_on_disk` / `plugin_older_on_disk` · `not_on_disk` · `never_taken` (prvé pripojenie, R16) ·
  `pending` (R-J5) · `head_conflict`; + `disk_version`, `local_version`, `note`, `can_send`, `can_take`, `reason`.
- **R-F2 `startup_check`** = sken vo vlákne + `status` → skupiny `newer`/`newer_and_local`/`never_taken` pre O4 a príznak bodky. **Nič nesťahuje ani nezapisuje.**
- **R-F3 zmena verzie pluginu:** keď `entry.plugin ≠ Engine::VERSION` a `entry.clean` (posledné vyhodnotenie pod starou verziou bez lokálnych zmien), stav sa **prebázuje**
  (nový odtlačok = `fingerprint`, seedové migrácie nie sú zmeny používateľa); inak `local_changes`. `clean` sa aktualizuje pri každom `status` (zápis len pri zmene) — D4.

### R-G · Verzia pluginu (R14, R18, O7)

- **R-G1 Aktualizovať** len keď `LibraryTransfer.compatible?(head.plugin)` (U2 R5 — jediná autorita); Disk novší → `plugin_newer_on_disk` („najprv aktualizuj plugin"); starší →
  `plugin_older_on_disk` („správca ju po aktualizácii pluginu odošle znova").
- **R-G2 Odoslať (R18)** odmietne, keď (a) ktorýkoľvek aktuálny ukazovateľ je z **novšieho** pluginu, alebo (b) `Updater.check(Updater.source_dir, VERSION)` vráti `older` (správcova
  verzia ešte nie je na Disku pre druhé PC). Distribúcia nečitateľná → odmietnutie s dôvodom „nedá sa overiť aktualizácia pluginu na Disku" (fail-closed; §12 D2).
  Odoslanie z novšieho pluginu než na Disku je povolené (R18).

### R-H · Odoslanie (U3b; A2 B3, O8)

- **R-H1 `publish_prepare(groups:, note:)`** (hlavné vlákno): `admin_state == self`, R-G2, zámok R-B2 → per skupina `LibraryTransfer.export_group(g)` (neúspech = skupina `failed`
  s vetou U2 R4.7) → `canonical_bytes` dokumentov + prílohy podľa `attachment_refs` do outboxu `Materials.dir/library_outbox/<id>/` (tvar verzie) → tiket. Predvolené skupiny =
  `local_changes` a `not_on_disk`; nezmenená (= `entry.fingerprint` = aktuálna verzia na Disku) sa neodosiela.
- **R-H2 `publish_run(ticket)`** (vlákno): `N` = max(najvyšší viditeľný ukazovateľ, `entry.version`) + 1 → `v<N>-<r8>/` → `d/*`, `a/*` → `manifest.json` → **čítanie späť**
  (veľkosť + SHA256) → `head-<N>-<r8>.json` posledný → znova zoznam ukazovateľov.
- **R-H3 výsledok per skupina:** `sent` · `failed` (zvyšok na Disku bez ukazovateľa = neviditeľný) · `skipped`; pri `sent` aj `attachments_skipped`
  (`{entry_key => [{rel, reason}]}` z packetu — prílohy, ktoré U4 nepreniesol; U5 z neho skladá vetu „bez N fotiek“).
- **R-H4 (A2 B3):** po zápise iný ukazovateľ s číslom ≥ N a iným `id` → `failed` „odoslanie neprešlo, skús znova"; lokálne ostáva neodoslaná zmena (D5).
- **R-H5 [R0]** zápis na H: priamo pod finálnym menom v jedinečnom priečinku (čiastočný súbor odhalí manifest).
- **R-H6 `publish_finish`** (hlavné vlákno): pre `sent` `update_sync_state!(g, …origin: publish, fingerprint: z tiketu)` → zámok uvoľniť → outbox zmazať.
- **R-H7 zametanie (R5):** správca po úspechu zmaže verzie a ukazovatele s číslom **< N−4** a priečinky `v*` bez ukazovateľa staršie ako 24 h; len vlastné mená (R-A3); zlyhanie =
  úspech s poznámkou; nikdy verziu, ktorú drží tiket Vrátiť. **[R0]** T6.

### R-I · API U2, ktoré U3 používa (presne podľa PACKAGE_U2)

| U3 potrebuje | API U2 | Pozn. |
|---|---|---|
| skupiny, poradie, závislosti | `LibraryRegistry.groups`, `members(g)`, `library_members(g)`, `depends_on`, `dependents` (R1.2–R1.3) | `members` = poradie prevzatia, prílohy pred dokumentom |
| obsah na odoslanie a lokálny odtlačok | `LibraryTransfer.export_group(g)` → `[:ok, packet]` (R4.1) | `packet['documents']`, `['attachment_refs']`, `['fingerprints']`, `['plugin_version']` |
| bajty na Disk, odtlačok | `canonical_bytes(doc)`, `fingerprint(doc)` (R4.6) | `group_fingerprint` skladá U3 (R-A5) |
| prevzatie celej skupiny | `import_group!(g, packet, plugins_dir:, reason:)` (R4.2) | brány, záloha, návrat, druhé okno, UNI, `after_import!`; kódy R4.7 |
| zálohy | `create_backup!`, `backups(g)`, `restore_backup!(id, plugins_dir:)` (R4.3) | U3 vlastné zálohy **nerobí** |
| lokálny stav | `sync_state`, `update_sync_state!(g, entry)` (R4.5) | obsah `entry` R-B1 |
| verzia | `compatible?(plugin_version)` (R5) | R-G1 |

**Doplnené v U2** (§12 D6): (a) `update_sync_meta!` pre údaje PC (`pc_id`, `drive_root`, `admin`); (b) predpoklad R4.2 krok 2 „prílohy už ležia" — U3 ich uloží
pred `import_group!` (R-M), ale riadky prílohy majú v registri `lock` (`materials.lock`, `appliances.json.lock`, `templates.json.lock` drží volajúci) → U3 potrebuje
**verejný obal zámku** `LibraryTransfer.with_store_lock(entry_key)` (dnes R4.4 interný) alebo `place_attachments!` v U2.

### R-J · Prevzatie (U3b; R4, R6)

- **R-J1 `take_prepare(groups:)`** (vlákno): `verify_version` → kópia celej verzie do `Materials.dir/library_staging/<id>/` → **opätovné overenie stagingu** (Disk mohol súbor
  vymeniť) → tiket. Neúspešná skupina = `syncing`/`broken`, ostatné pokračujú.
- **R-J2 `take_commit(ticket, decisions:, plugins_dir:)`** (hlavné vlákno): zámok R-B2 · R-G1 · `decisions = { g => :take | :overwrite | :skip }`: skupina s lokálnymi zmenami
  bez `:overwrite` sa preskočí (R4); lokálny `fingerprint` sa prepočíta znova (`export_group`) — zmena od `status` bez `:overwrite` → `skipped_changed`. Vráti aj
  `dependents_skipped` z `LibraryRegistry.dependents` (text U5).
- **R-J3 poradie per skupina** (v poradí `GROUPS`): (1) `pending` do stavu · (2) prílohy R-M · (3) packet = `{group, plugin_version: manifest.plugin, documents: JSON.parse(staged d/*),
  attachment_refs, fingerprints}` → `import_group!(g, packet, plugins_dir:, reason: 'prevzatie verzie N')` · (4) `:ok` → `update_sync_state!` (`fingerprint` z `result['fingerprints']`
  po usadení, `pending: nil`); iný kód → výsledok so slovenskou vetou U2, `pending: nil` okrem `:failed_restore_failed` (ostáva, U5 ponúkne „Vrátiť zálohu").
  `:other_instance` / `:other_instance_unknown` na prvej skupine → zvyšok sa nespúšťa („Zavri ostatné okná SketchUpu").
- **R-J4 výsledok per skupina:** `taken` · `skipped` · `skipped_changed` · `syncing` · `broken` · `plugin_mismatch` · + kódy U2 R4.7 bez prekladu. Staging sa zmaže po dobehu;
  zvyšky staršie ako 24 h zmaže najbližšie `take_prepare`.
- **R-J5** `pending` pri štarte → stav `pending` („Prevzatie sa prerušilo — Aktualizuj znova alebo vráť zálohu"); nič automaticky.

### R-K · Zálohy (O5) — len cez U2

U3 vlastné zálohy nerobí. „Vrátiť zálohu" = `restore_backup!(id, plugins_dir:)` pod zámkom R-B2; `entry` sa **nemení** (východisko ostáva poslednou prevzatou verziou → správne
`local_changes`). Zoznam = `backups(g)`. Riadok `library_backups/` pridáva U2 (R1.4).

### R-L · História a Vrátiť verziu (R5, O5)

- **R-L1** `history(g)` = R-D5; Vrátiť len pri `admin_state == self`.
- **R-L2 `revert!(g, version_id, note:)`:** `verify_version` + R-G1 (iný plugin → „verzia je z iného pluginu") → prevzatie verzie lokálne cestou R-J (záloha a návrat U2) →
  odoslanie **bajtov tej verzie bez nového exportu** ako `N+1` s `reverted_from` a poznámkou „Návrat na verziu K z <dátum>". Zlyhanie odoslania → lokálne K, stav `local_changes`.
- **R-L3** stará verzia sa nemení ani nemaže.

### R-M · Prílohy len pribúdajú (A4 B9, rozhranie pre U4)

- **R-M1 uloženie prílohy** = `LibraryAttachments.place(staged, local_rel, sha256)` pod `LibraryTransfer.with_store_lock` — **politiku, overenie, žurnál náhrad
  a upratanie definuje U4** ([PACKAGE_U4.md](PACKAGE_U4.md) R4.1, R1.6, D10). U3 len volá `place` pre každú prílohu manifestu pred `import_group!` a výsledok prenesie.
  Do U4 platí len: chýbajúci cieľ sa doplní, existujúci sa nemení. **Nikdy nič nemaže.**
- **R-M2** prílohy idú **pred** `import_group!` (U2 R4.2 krok 2 ich overuje — `:missing_attachments`).
- **R-M3** dočasné mená príloh registruje **U4** ([PACKAGE_U4.md](PACKAGE_U4.md)); U3 žiadne nepridáva.

### R-N · Zoznam zmien pre varovanie R4 (A4 B5, R17) — nad výstupom `export_group`, bez nového API U2

- **R-N1 `diff(g, ticket, used_ids: {})`** (hlavné vlákno): lokálne `packet['documents']` z `export_group` vs. dokumenty zo stagingu tiketu (tie isté bajty, ktoré sa importujú).
  Per knižnica `{ added:[{id,label}], changed:[{id,label,fields}], removed:[{id,label,used}] }`; `used = used_ids[entry_key].include?(id)` — množinu použitých ID otvorenej zákazky
  dodá U5 (potrebuje model; napr. `Materials.used_material_ids`), U3 ju len prenesie do výsledku.
- **R-N2 tabuľka záznamov** v U3 (`LibrarySync::RECORDS`): per `entry_key` cesta k poľu záznamov, kľúč identity a popisu (napr. `materials` → pole položiek, `id`, `name`);
  `fields` = mená najvyššej úrovne s odlišným `canonical_bytes`. Pole cien (`price*`, sadzby) sa označí `price_changed: true` pre vetu R17. Tvary dokumentov overí implementátor
  sondou na kóde pred písaním tabuľky; store bez stabilného ID → len počet zmien (§12 D7).

### R-O · Register, verzie a dokumentácia

- **R-O1** U3 pridá do registra len: `LOCKS['library_sync.lock']`, riadky `library_staging/` a `library_outbox/` (lokálne, celé `transient`); dočasné mená príloh registruje U4. Riadky
  `library_backups/` a `library_sync.json` pridáva **U2**; `SHARED` sa nemení. `WRITE_SITES` doplniť.
- **R-O2** `LibrarySync::FORMAT_STD = 1` (manifest, ukazovateľ, správca) → STANDARD §13.1.
- **R-O3** odseky `### library_sync.rb` (+ `_remote`, `_publish`, `_take`) a `### timed_worker.rb` v `kniznice.md` na mieste + riadky rozcestníka `docs/ARCHITEKTURA.md`.
  Načítanie `main.rb` za `core/library_transfer` (U2) a `core/updater`; `tests/helper.rb`.
- **R-O4 čistota:** `library_sync*.rb`, `timed_worker.rb` bez `Sketchup.`, `UI.`, `::UI`, `Sketchup::` (guard nad zdrojom).

## 7 · Testy a DoD

**Headless** (`tests/pure/test_u3a_library_sync.rb`, `test_u3b_library_sync.rb`; Disk = TEMP sandbox, `Materials.test_dir_override`; U3a so stubom API U2 s presnými menami,
U3b so skutočnou U2):

| Oblasť | Prípady (každý s mutáciou: odstránená kontrola → test padne) |
|---|---|
| mená | `head-…(1).json`, `HEAD-…`, `v000015-xyz`, `manifest (1).json` ignorované a hlásené, nikdy zmazané |
| celistvosť | chýbajúci/skrátený/iný súbor, iný SHA manifestu, ukazovateľ pred priečinkom → `syncing`; `..`/absolútna cesta/strop → `broken`; `EACCES` → `syncing` |
| stavy Disku | `no_drive`, `no_root`, `empty`, `missing_known`, `ok`, `timeout` (fake spawn), `error` |
| timed worker | single-flight, dobehnutý zahodený, nezabíja sa, výnimka → `error` |
| správca | `none` → Odoslať vypnuté na oboch; `self`; `other`; `mismatch`; `conflict` → Odoslať vypnuté, Aktualizovať ide (R19); claim pri `syncing` odmietnutý |
| R14/R18 | Aktualizovať pri inom pluginu odmietnuté (dva dôvody); Odoslať pri novšom na Disku odmietnuté, pri novšom lokálne povolené; `Updater.check` `older` → odmietnuté; nečitateľná distribúcia → odmietnuté |
| odoslanie | ukazovateľ až po čítaní späť; zlyhanie kopírovania → bez ukazovateľa, stav nezmenený; súbežný ukazovateľ → `failed`; nezmenená skupina `skipped`; zametanie necháva 5, nemaže cudzie |
| zámok | druhá operácia počas prvej → `:busy`; uvoľnený po chybe |
| prevzatie | staging overený znova (súbor vymenený medzi kópiou a overením); prílohy pred `import_group!`; príloha sa nikdy nezmaže; lokálne zmeny bez `:overwrite` → `skipped`; zmena po `status` → `skipped_changed`; kódy U2 (`:failed_restored`, `:failed_restore_failed` → `pending` ostáva, `:other_instance` zastaví zvyšok) prenesené bez zmeny |
| Vrátiť | verzia K → lokálne K + Disk N+1 s `reverted_from`; K z iného pluginu odmietnuté |
| lokálne zmeny | po prevzatí `current`; po úprave `local_changes`; prebázovanie len pri `clean` (R-F3) |
| diff | pridané/zmenené/zmiznuté, `used` z `used_ids`, `price_changed` |
| guardy | čistota (R-O4); telá vlákien (R-E4); žiadny `JsonFileStore`/`.tmp` nad `<root>`; register (S13) |

**Koncový scenár („dve PC" = dva sandboxy `Materials.dir` + jeden „Disk"):** A claim → odošle všetko (v1) → B `never_taken` → prevezme → `current` → A zmení Materiály, odošle (v2)
s poznámkou → B `newer` + poznámka → B zmení Materiály → `newer_and_local` → `:skip` (Kovanie prevzaté) → `:overwrite` → záloha U2 + prevzatie → A Vrátiť v1 → B dostane v3 = v1.
**DoD:** Ruby a všetky JS sady zelené (každá zvlášť), encoding guard, R0 v §15 pred implementáciou; **U3b: export test P == K**.

## 8 · In-SU

Nie je brána (spúšťače sa nemenia — §5). Overenie na reálnom Disku a dvoch PC = smoke U5.

## 9 · Riziká

1. **Disk doručí inak, než predpokladáme [R0]** → manifest + SHA256 nezávisí od poradia; najhorší dôsledok = dlhšie `syncing`.
2. **Prepis mení čísla zákazky** (A4 D, R17) → diff s `used`, záloha a návrat U2, odmietnutie druhého okna; rozhodnutie a texty U5.
3. **Prehliadnuté lokálne zmeny po aktualizácii pluginu** (R-F3) → úprava medzi posledným `status` a aktualizáciou sa vstrebe do východiska (D4).
4. **Zaseknuté vlákno nad H:** drží `library_sync.lock` do dobehu → `:busy` v tom okne do reštartu.
5. **Dvaja správcovia** → Odoslať vypnuté na oboch, ručne (R19).
6. **API U2 sa pri implementácii zmení** → U3b štartuje až po mergi U2; zmena mien = zladenie package pred U3b.
7. **Veľkosť príloh** (U4) → stropy na verziu, história 5 = až 5× na Disku; R0 T1 zmeria čas.
8. **Cesta s diakritikou** (`Môj disk`) → R0 T8 + testy s UTF-8 cestou.

## 10 · Smoke checklist pre Michala

U3 nemá okno — uvidíš ju až v U5. Od teba treba **R0 sondu** (pred implementáciou) a krátku kontrolu po inštalácii:

1. **Sonda (R0):** na svojom PC `scripts\sonda_disk_d48.ps1 -Role writer -Beh test1`, na Luciinom `… -Role reader -Beh test1` (do minúty po sebe); nechaj dobehnúť (≤ 20 min).
   CSV a `_summary.txt` z `%TEMP%\noxun_sonda_disk\` oboch PC pošli do okna (alebo nechaj v `_sonda\` na Disku).
2. Pri T4 skript povie „TERAZ" na oboch PC — Enter naraz (± 2 s). Pri T7 ťa požiada pozastaviť synchronizáciu Disku a po 5 min ju obnoviť.
3. **Po inštalácii U3a/U3b:** SketchUp sa spustí ako doteraz, O plugine vyzerá rovnako, v Materiáloch nič nepribudlo ani nezmizlo, v `%APPDATA%\NOXUN\Engine` nepribudol súbor.

## 11 · Checklist uzáveru (U3a aj U3b zvlášť)

Bump patch (`noxun_engine.rb` + `main.rb`) + všetky `?v=` · testy zelené · **U3b export test P == K v PR** · odseky `kniznice.md` na mieste + rozcestník + tabuľka časti 3 ·
STANDARD §13.1 · Grep tvrdení o zoznamoch (LOCKS, súbory koreňa, „SYNC-0..3" v komentároch registra) · STAV prepis · KRONIKA navrch · PLAN riadok U3a/U3b ✅ + PR ·
D-48 v DOGFOODING ostáva otvorený (zatvorí U5) · PR popis: predrecenzia, odkaz na R0.

## 12 · Rozhodnutia autora na potvrdenie orchestrátorom

- **D1 trieda:** potvrdené orchestrátorom 17.10. — U3a nie výrobná/cenová, **U3b áno** + export test P == K.
- **D2 R18 fail-closed** — **potvrdené orchestrátorom 17.10.:** keď sa distribúcia pluginu na Disku nedá prečítať, Odoslať sa odmietne (R18 „verzia nie je na Disku" sa nedá overiť).
- **D3 časový limit v core** — potvrdené: nový `TimedWorker`, updater D-52b ostáva (N1).
- **D4 prebázovanie po aktualizácii pluginu** (R-F3) — jednoduchšia cesta so zostatkovým rizikom; presnejšia by potrebovala od U2 `canonicalize` bez zápisu (nové API — nenavrhujem).
- **D5 súbežný ukazovateľ** na jednom PC nenastane (R-B2), dva PC zakazuje R3 → stačí `failed` + `head_conflict`.
- **D6 čo chýba v U2** (vyriešiť v PACKAGE_U2 pred U3b): **(a)** `update_sync_state!` prijíma len `group_key ∈ GROUPS` — údaje PC (`pc_id`, `drive_root`,
  `admin`) → U2 dopĺňa `update_sync_meta!` (R4.5); **(b)** verejný `LibraryTransfer.with_store_lock(entry_key)`
  (R4.4 je dnes interný) na ukladanie príloh pod zámkom ich riadku pred `import_group!`. Riadky `library_backups/` a `library_sync.json` pridáva U2 (potvrdené); U3 len `library_sync.lock`,
  `library_staging/`, `library_outbox/`.
- **D7 diff** (R-N) je celý v U3 nad `export_group` a stagingom; tabuľka `RECORDS` sa opiera o tvary dokumentov — implementátor ich pred písaním overí sondou; store bez stabilného ID
  dostane len počet zmien.
- **D8 rozloženie verzie** = priečinok s kópiou dokumentov a príloh pod menami z obsahu (A4 SIMPLER); duplikácia príloh medzi verziami prijateľná.
- **D9 koreň** = per-PC hodnota s predvoľbou R11, bez UI na zmenu.

## 13 · Otázky pre Michala

**Uzavreté 17.10.2026 — R18** (výklad R14: Aktualizovať len pri rovnakej verzii; Odoslať blokuje novší plugin na Disku alebo správcova verzia ešte nie je na Disku — R-G2)
**a R19** (dvaja správcovia: Odoslať vypnuté na oboch, riešenie ručne v „⋯", Aktualizovať ide ďalej — R-C1). Ďalšie otázky žiadne.

## 14 · Nálezy mimo scope

- **N1:** kontrola verzie pluginu v O plugine (`supplier_settings_dialog.rb:354-423`) môže neskôr použiť `TimedWorker` — jeden vzor namiesto dvoch (refaktor, guard D-52b).
- **N2:** zavádzač zapisuje lease bez `exe` (`noxun_engine.rb:161-168`) na rozdiel od `Updater.write_lease!` (`updater.rb:628-639`) — zjednotenie pre D-52.
- **N3:** F10 `Debug.report` po U3 môže pridať `LibrarySync.status` — porovnanie Michal vs. Lucia jedným príkazom.
- **N4:** nápad do U5: v histórii ukazovať aj PC a verziu pluginu odoslania (údaje nesie ukazovateľ).

## 15 · Výsledok sondy R0

*(doplní sa po behu na oboch PC; dovtedy package nie je zmrazený — požiadavky [R0] sú predbežné)*
