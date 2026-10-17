# PACKAGE U3 · Jadro synchronizácie zdieľanej knižnice (D-48) — blok UPDATE

> **Stav: NÁVRH — čaká audit návrhu (`codex-audit`)** · 17.10.2026 · písané do zásoby, **implementácia až po smoke PASS bloku 9 HARDENING** a po mergi U2.
> **Autorita:** [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) (R3–R7, R13–R19, mockup O1–O8 — záväzné) · smer [RECONCILE_2026-10-17.md](RECONCILE_2026-10-17.md)
> §2/§3 riadok U3 · rozhranie [PACKAGE_U2.md](PACKAGE_U2.md) R1, R4, R5 (`LibraryRegistry` skupiny, `LibraryTransfer`) · koncept [KONCEPT_UPDATE.md](KONCEPT_UPDATE.md) · dôkazy
> [CROSS_AUDIT_A4_CLAUDE_KOD.md](CROSS_AUDIT_A4_CLAUDE_KOD.md) (B7, B9, B11, B13), [CROSS_AUDIT_A2_GROK.md](CROSS_AUDIT_A2_GROK.md) (B1–B5, B7),
> [CROSS_AUDIT_A3_RESERS_WEB.md](CROSS_AUDIT_A3_RESERS_WEB.md) (FIX 1–4, NOTE 2) · súpis [kniznice.md](../../../../docs/architecture/kniznice.md) · z návrhu 6.9.
> ([SYNC_KNIZNICE_NAVRH_2026-09-06.md](../../next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md)) platí len §3 „Čo ostáva".
> **Trieda Ť · audit-povinná (nový modul) · predrecenzia · U3b výrobná/cenová (export test P == K) · R0 sonda Disku pred zmrazením.** Rez **U3a → U3b** (§2), jeden audit.
> **Stav kódu:** sonda nad `main` `a9e8c79d` (v0.18.1, po #474). U2 ešte nie je v kóde — U3 používa jej API **presne podľa PACKAGE_U2 vrátane jeho §15** (§6 R-I).
> **Audit návrhu (Codex astra, 17.10.): 3 BLOCKER · 6 FIX · 1 NOTE — zapracované priamo do §6; mapa nález → požiadavka v §15.**

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 17.10.2026, len čítanie

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | `JsonFileStore.write` píše `<súbor>.tmp-<pid>-<thread>` vedľa cieľa + `rename` → na H: temp súbory (A2 B2) | `json_file_store.rb:79-97`, `:223-225` | PRAVDA → do H: nikdy cez `JsonFileStore` |
| S4 | `LibraryRegistry` = čisté dáta, 12 zdieľaných riadkov, bez skupín; `root` = `Materials.dir` | `library_registry.rb:85-195`, `:234-262` | PRAVDA → skupiny U2 R1 |
| S6 | Vzor zámku: `File.open(lock,'a')` + `flock`, `false` = výnimka | `materials.rb:503-528` | PRAVDA (U3 berie `LOCK_EX \| LOCK_NB`) |
| S7 | `Updater.live_leases` = PID ostatných inštancií, nezistiteľné = `Refused` | `updater.rb:751-787` | PRAVDA → volá U2 |
| S8 | `Updater.check` číta len hlavičku loadera (`newer/same/older`); `source_manifest` = SHA1 + veľkosť celého balíka | `updater.rb:871-889`, `:436-444` | PRAVDA → R-G2 |
| S9 | Vzor manifestu, `safe_relative!`, `refuse_link!`, stropy | `updater.rb:185-186`, `:332-436` | PRAVDA → manifest verzie |
| S10 | Čítanie s limitom žije v UI: vlákno len I/O, poll 0,2 s, deadline 4 s, nezabíja sa, single-flight, testovacie háčiky | `supplier_settings_dialog.rb:354-423`, `:748-765` | PRAVDA (A4 B13) |
| S11 | Guard D-52b pripína text `updater_worker` | `test_d52b_updater_ui.rb:1072` | PRAVDA → D3 |
| S13 | Guard H16 pripína `SHARED` a `WRITE_SITES` — nový súbor = riadok registra | `test_h16_kniznice.rb:44`, `:72`, `:855` | PRAVDA |
| S14 | `LibraryTransfer`, `export_group`, `import_group!`, `LibrarySync` v kóde **nie sú** | Grep `noxun_engine/`, `tests/` | PRAVDA → U3b až po mergi U2 |

---

## 1 · Cieľ (funkčne)

„Motor" zdieľanej knižnice bez okna (okno je U5): **stav Disku** bez zamrznutia SketchUpu · **stav per skupina** (novšia na Disku, lokálne zmeny, synchronizuje sa, iný
plugin) · **odoslanie** zo správcu (R3) s poznámkou ako nová nemenná verzia · **prevzatie** celej skupiny alebo ničoho (záloha a návrat U2) · **zoznam zmien** pre R4 ·
**história 5** a **Vrátiť** (= nová verzia).

**Príklad:** Michal odošle Materiály (verzia 15). Disk Lucii dotiahne ukazovateľ skôr než `.skm` súbory → Aktualizovať povie „Materiály sa na Disku ešte synchronizujú —
skús o chvíľu", **nič sa nezmení**; o minútu prebehne prevzatie a jej stará knižnica ostane ako záloha.

## 2 · Rez a odhad — dve časti, sekvenčne z čerstvého `main`, jeden audit návrhu

| Časť | Obsah | Kód pluginu | Testy | Odhad |
|---|---|---|---|---|
| **U3a · čítacia strana** | `timed_worker.rb` · `library_sync.rb` (mená, stav, správca — čítanie, R18 precheck) · `library_sync_remote.rb` (sken, celistvosť, história, cudzie mená) · `status` · `diff` | ~540 | ~700 | 1¼ dňa |
| **U3b · zápisová strana** | `library_sync_publish.rb` (dvojfázový správca, odoslanie, zametanie, Vrátiť) · `library_sync_take.rb` (staging, tikety, prílohy, `import_group!`, R-J5) | ~520 | ~800 | 1½ dňa |

Spolu ~1060 riadkov (po audite) → delenie ostáva. U3a nič nezapisuje mimo lokálneho stavu; štartuje po **U2a** (skupiny v registri)
a potrebuje `peek_group` (§12 D10, dodá U2b) — v testoch stub s presnými menami; **U3b potrebuje U2a + U2b + U2c v `main`**. **Poistka:** časť nad ~650 → stop, rozhodne orchestrátor.

## 3 · Scope IN

R0 sonda Disku (skript mimo pluginu) · R-A rozloženie koreňa a mená · R-B lokálny stav a zámok · R-C správca · R-D sken a celistvosť · R-E stavy Disku a čítanie s limitom ·
R-F stav per skupina a kontrola pri štarte · R-G verzia pluginu (R14, R18) · R-H odoslanie · R-I použitie API U2 · R-J prevzatie · R-K zálohy (len cez U2) · R-L história a Vrátiť ·
R-M prílohy (rozhranie pre U4) · R-N zoznam zmien pre R4 · R-O register a dokumentácia.

**Z návrhu 6.9. ostáva:** nemenné artefakty, ukazovateľ posledný, prevzatie len celej overenej verzie, single-flight čítanie. **Odpadá:** lineage, konfliktné okno,
`publish.lock`, `files/<sha>`, dopredná brána (nahradená `import_allowed?` / `export_allowed?`).

## 4 · Scope OUT

Okno O plugine, oznámenie pri štarte, bodka, pruh R13, texty varovania R4 (**U5**) · kanonický export/import, zálohy a návrat, druhé okno, UNI značky, reset stavu v pamäti,
skupiny a riadky `library_backups`/`library_sync` v registri (**U2**) · výber príloh per skupina, fotky dekorov, `textures/` (**U4**) · názov zákazky v .skp (**U1**) ·
„Odovzdať správcu…" (O2 „neskôr") · zlučovanie po záznamoch · automatické sťahovanie · zmena cesty koreňa v UI · presun D-52b kontroly verzie na nový primitív (D3, N1).

## 5 · Trieda a brány

- **Trieda Ť:** nový modul. **Audit návrhu** jeden pre U3a + U3b (R12, úzko) — vykonaný 17.10., zapracovanie §15; delta audit na §15. Sonda = §0.
- **Výrobná/cenová:** **U3a nie** (len číta). **U3b áno** (orchestrátor 17.10.: zapisuje katalógy, z ktorých sa počítajú ceny a rozmery) — brány výrobnej dávky celé;
  **export test P == K** (dávka sama čísla nemení).
- **Predrecenzia:** povinná pre U3a aj U3b.
- **In-SU:** spúšťače sa nemenia → **nie je brána** (§8). Fotky okien: nie.
- **R0 sonda Disku:** podmienka **zmrazenia package** (výsledok do §16, prípadná úprava [R0] požiadaviek ako delta audit); nie brána mergu.

## 6 · Požiadavky

### R0 · Empirická sonda Google Disku na oboch PC (A3 NOTE 2) — pred zmrazením package

**Skript mimo pluginu:** `scripts/sonda_disk_d48.rb` (standalone Ruby `C:\Ruby32-x64`, bez `require` pluginu) + spúšťač `scripts/sonda_disk_d48.ps1`. Pracuje **len** v
`H:\Môj disk\NoxunENGINE data\_sonda\<beh>\` (nikdy v `library\`), na konci po sebe uprace. Výstup `%TEMP%\noxun_sonda_disk\<beh>_<role>.csv` + `_summary.txt`.
Roly `-Role writer` (Michal) / `-Role reader` (Lucia); časy monotónne v rámci PC.

| Test | Writer robí | Reader meria (poll 0,5 s, max 15 min) |
|---|---|---|
| T1 poradie | `v000001-<rand>/` 40 súborov (1 KB–25 MB) → `manifest.json` → `head-…json` | objavenie a **plná veľkosť + SHA256** každého súboru; head pred dátami? |
| T2 rozpísaný súbor | 50 MB za 30 s pod finálnym menom | 0 B / čiastočný / `EACCES`/`EBUSY` / nič |
| T3 temp+rename | `x.json.tmp` → `rename` → `x.json` | vidno `.tmp`? obe? len výsledok? |
| T4 súbežný zápis | obaja v tej istej sekunde iný obsah do `clash.json` | presné **mená konfliktných kópií** a kde ležia |
| T5 prepis | 3× prepis `ptr.json` za 2 s | ktorá verzia dorazí, vznikne kópia? |
| T6 mazanie | zmaže starý priečinok verzie počas čítania | chyby čítania, oneskorenie |
| T7 offline | pozastaví synchronizáciu, zapíše T1, po 5 min obnoví | oneskorenie a poradie |
| T8 mená | ASCII aj diakritika, cesta 200+ znakov | doručenie a meno |
| T9/T10 | — | koreň počas prvej synchronizácie; `Dir.children` + `stat` nad 200 súbormi; **lehota T pre R-C3** |

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
- **R-A3 cudzie mená [R0]:** čo nesedí presne s `head-<6 číslic>-<8 hex>.json`, `v<6>-<8 hex>`, `admin-<6>-<8 hex>.json`, `admin-act-<6>-<8 hex>.json`
  (vnútri verzie len položky manifestu), je **cudzie**: nečíta sa ako pravda, nemaže sa, vráti sa ako `foreign`; konfliktné kópie `head-…`/`admin…` blokujú (R-D2).
- **R-A4 žiadne dočasné súbory v `<root>`** (S1): do `<root>` nikdy `JsonFileStore`, `*.tmp*`, `.bak`, zámky ani staging — tie žijú v `Materials.dir`.
- **R-A5 manifest** `{ std:1, kind:"noxun_library_version", group, version, id, plugin (= packet['plugin_version']), created_at (UTC), by_pc, by_pc_id, note, reverted_from, base,
  documents:{ entry_key => {file:"d/<key>.json", size, sha256 (= fingerprint)} }, attachments:{ "a/…" => {of: entry_key, local: rel, size, sha256} }, group_fingerprint }`.
  Ukazovateľ `{ std:1, kind:"noxun_library_head", group, version, id, manifest_sha256, plugin, created_at, note }`. `note` ≤ 200 znakov, riadiace znaky → medzera (O8).
  `local` = cesta voči `Materials.dir` overená `safe_relative!` (S9) **a** vzorom `children` prílohového riadku (`LibraryRegistry.members`). `group_fingerprint` = SHA256 nad
  `"<entry_key>\0<fingerprint>\n"` zoradenými podľa kľúča (prílohy sa nerátajú — len pribúdajú). Stropy: 5000 súborov, 500 MB na verziu.

### R-B · Lokálny stav a zámok (A2 B3, A4 B7)

- **R-B1 lokálny stav = `LibraryTransfer.sync_state` / `update_sync_state!(group_key, entry)`** (U2 R4.5; súbor `library_sync.json` a jeho riadok registra pridáva **U2**). U3 definuje obsah:
  `entry = { version, id, fingerprint (group_fingerprint po prevzatí/odoslaní — pri prevzatí z `result['fingerprints']` po usadení), plugin, at, origin: take|publish|revert,
  publisher_pc_id (R-C4), pending: {target_id, target_version, before_fingerprint, started_at} | nil, attachments_digest }` — pole `attachments_digest` je **rezervované pre U4** (význam, plnenie
  a vplyv na `status`: [PACKAGE_U4.md](PACKAGE_U4.md) R5.1–R5.2); U3 ho len prenáša. Údaje PC cez `LibraryTransfer.update_sync_meta!` (U2 R4.5): `pc_id` (UUID vzniknutý raz),
  `drive_root` (R-A1), `admin` (true = toto PC sa vyhlásilo za správcu, R-C3). Degradovaný stav (U2) = Odoslať aj Aktualizovať odmietnuté s dôvodom.
- **R-B2 zámok operácie** `library_sync.lock` (`Materials.dir`, nový záznam `LibraryRegistry::LOCKS` — pridáva U3): `flock(LOCK_EX | LOCK_NB)`; obsadený → `:busy` „Iné okno práve odosiela
  alebo aktualizuje knižnicu". Drží sa počas celej operácie vrátane vlákna. **Vonkajší** voči zámkom U2 (`materials.lock` a ďalšie berie `LibraryTransfer` vnútri, postupne — F4).
- **R-B3** `pc_name` = `ENV['COMPUTERNAME']` (len zobrazenie). Strata stavu = nové `pc_id` → PC prestane byť správcom (bezpečné zlyhanie).

### R-C · Správca (R3, R19, O2, A2 B1, A4 B11)

- **R-C1** `library/admin-<NNNNNN>-<r8>.json` = `{ std:1, kind:"noxun_library_admin", seq, pc_id, pc_name, at }` (kandidát) a `library/admin-act-<NNNNNN>-<r8>.json`
  `{ …, activated_at }` (aktivácia, R-C3); platí najvyššie `seq`. **Dva rôzne `pc_id` s rovnakým najvyšším
  `seq` → `conflict`: Odoslať (aj Vrátiť verziu) vypnuté na oboch PC s vetou o dvoch správcoch, riešenie ručne v „⋯" (U5); Aktualizovať ide ďalej (R19).**
- **R-C2 `admin_state`** ∈ `none` · `claiming` (vlastný kandidát, aktivácia ešte nie) · `self` (Disk má **aktiváciu** tohto `pc_id` a žiadny iný kandidát/aktiváciu **a** lokálne `admin == true`) · `other` · `mismatch` · `conflict`. **Odoslať a Vrátiť verziu len pri `self`**;
  `none` → vypnuté na oboch (O2). Správcom sa **nikdy** nestáva „prvý, kto odošle".
- **R-C3 dvojfázový `claim_admin!`** (U3b; U5 po potvrdení; audit 4): (1) len keď Disk `ok`/`empty` **a sken ukazuje 0 kandidátov aj 0 aktivácií** → zapíše kandidáta
  + `update_sync_meta!('admin' => true)` → `claiming`; (2) `activate_admin!` smie bežať najskôr po **čakacej lehote T = 15 min [R0]** (podľa nameranej latencie T1/T7) a len keď
  nový sken stále ukazuje **jediného kandidáta = toto PC**; potom zapíše aktiváciu. Iný kandidát kedykoľvek → `conflict` (R19). Odoslať až pri `self`. „Odovzdať správcu" = `seq+1` (mimo).
- **R-C4 prijímanie publikácií (audit 4):** ukazovateľ nesie `by_pc_id`; čitateľ berie do úvahy **len ukazovatele aktivovaného správcu**. Prvé prevzatie zapíše `entry.publisher_pc_id`.
  Pri `conflict` (R19): Odoslať vypnuté na oboch; **Aktualizovať pokračuje len z ukazovateľov `entry.publisher_pc_id`** (doterajší zdroj tohto PC); skupina bez neho (`never_taken`)
  čaká na ručné vyriešenie. Ukazovatele cudzieho `pc_id` = `foreign_publisher` (hlásené, nikdy prevzaté, nikdy mazané). PC, ktoré je samo kandidátom v konflikte, neprijíma nič od druhého.
- **R-C5 `resolve_admin!(keep_pc_id)`** (U5 D13, R19 ručné riešenie v „⋯"): hlavné vlákno, zámok R-B2; len pri `conflict` a `keep_pc_id` ∈ kandidáti najvyššieho `seq`
  (smie ktorékoľvek z dvoch PC) → nový kandidát `admin-<seq+1>-<r8>.json` s `resolves: [pc_id oboch]` → `update_sync_meta!('admin' => keep_pc_id == pc_id)` → `[:ok, admin_state]`
  | `[:not_conflict | :unknown_pc | :disk, veta]`. Aktivácia ponechaného PC = R-C3 krok 2 (lehota T od `at` nového kandidáta); kandidát s `resolves` ruší konflikt nižšieho `seq`;
  neponechané PC s `admin == true` si ho pri `status` zhodí. `status['admin']` nesie `candidates: [{pc_id, pc_name, seq}]` a `activate_after` (UTC).

### R-D · Sken Disku a celistvosť verzie (A3 FIX 1)

- **R-D1 `Remote.scan(root, group_keys)`** — **len súborové I/O**, vo vlákne (R-E). Vráti `{ disk, admin, groups:{ g => {heads, current, history, foreign} } }`. Žiadne
  `Sketchup.*`, `UI.*`, zápis, volanie `LibraryTransfer` ani `JsonFileStore` (guard nad zdrojom).
- **R-D2** aktuálna verzia = najvyššie `NNNNNN` platného ukazovateľa; dva platné s rovnakým číslom a iným `id` → `head_conflict` (nič sa nepreberá, Odoslať vypnuté).
  **Cudzie meno začínajúce `head-` alebo `admin`** (konfliktná kópia ukazovateľa či správcu) = **záväzný blok** `head_conflict` / `conflict` danej skupiny/koreňa, nie len hlásenie (audit 4).
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
  dobehnutý zahodí — S10); `state(entry, deadline:, now:)` → `:running | :done | :timeout`; vlákno sa nezabíja; injektovateľné `clock`, `spawn`; poll robí U5 (D3).
- **R-E3 [R0] limity:** sken 4 s, distribúcia 60 s, staging 120 s, odoslanie 180 s.
- **R-E4** vo vlákne len `Remote.*` a kopírovanie H: ↔ staging; `LibraryTransfer.*`, lokálny stav a zámky store-ov **na hlavnom vlákne** (A4 B6). Guard: telá
  `TimedWorker.start` v `library_sync*.rb` volajú len povolené metódy.

### R-F · Stav per skupina a kontrola pri štarte (R6, R7, O4)

- **R-F1 `status(scan, local:)`** — hlavné vlákno; `local` = výsledok **`LibraryTransfer.peek_group(g)`** (bez bariéry, bez zápisu — §12 D10; `export_group` sa v `status` **nevolá**,
  vyžaduje zatvorené okná — U2 §15.0, audit 5). `:unknown` z `peek_group` → stav `unknown` („stav sa overí pri Aktualizovať/Odoslať"), **nikdy `current`**. `state` ∈ `current` · `newer` ·
  `local_changes` (lokálny `group_fingerprint` ≠ `entry.fingerprint` a ≠ odtlačok aktuálnej verzie na Disku) · `newer_and_local` · `syncing` · `broken` · `plugin_newer_on_disk` / `plugin_older_on_disk` · `not_on_disk` · `never_taken` (prvé pripojenie, R16) ·
  `pending` (R-J5) · `blocked` (`LibraryTransfer.pending_block` — U2 §15.1) · `disk_behind` (Disk ukazuje nižšiu verziu, než toto PC prevzalo — „synchronizácia beží"; nič sa nepreberá,
  audit 3) · `unknown` · `head_conflict` · `foreign_publisher`; + `disk_version`, `local_version`, `note`, `can_send`, `can_take`, `reason`.
- **R-F2 `startup_check`** = (beží až po `LibraryTransfer.recover_pending!` pri boote — R-J5) sken vo vlákne + `status` → skupiny `newer`/`newer_and_local`/`never_taken` pre O4 a príznak bodky. **Nič nesťahuje ani nezapisuje.**
- **R-F3 zmena verzie pluginu (audit 2 — bez prebázovania):** keď `entry.plugin ≠ Engine::VERSION`, lokálny odtlačok sa **nesmie** vyhlásiť za východisko. Platí len:
  lokálny `group_fingerprint` = odtlačok aktuálnej verzie na Disku (už odoslanej novým pluginom) → `current` a `entry` sa zarovná; inak **konzervatívne `local_changes`** s dôvodom
  „po aktualizácii pluginu sa vlastné zmeny nedajú odlíšiť" → prevzatie len cez varovanie R4 (záloha U2). Polia `clean*` zanikajú.

### R-G · Verzia pluginu (R14, R18, O7)

- **R-G1 Aktualizovať** len keď `LibraryTransfer.import_allowed?(head.plugin)` (U2 R5 — jediná autorita); Disk novší → `plugin_newer_on_disk` („najprv aktualizuj plugin"); starší →
  `plugin_older_on_disk` („správca ju po aktualizácii pluginu odošle znova").
- **R-G2 Odoslať (R18)** odmietne, keď (a) `LibraryTransfer.export_allowed?(head.plugin)` je `false` pre ktorýkoľvek aktuálny ukazovateľ (Disk z **novšieho**
  pluginu — U2 R5), alebo (b, druhá podmienka R18 — posudzuje U3; audit 6) distribúcia **nedokazuje** dostupnosť správcovej verzie: povolené len keď
  `Updater.check(Updater.source_dir, VERSION)['state'] == 'same'` **a** `Updater.source_manifest(Updater.source_dir) == Updater.source_manifest(plugins_dir)` (balík na Disku je
  bajtovo ten, ktorý beží — úplný a tej istej verzie); `newer`/`older`/nezhoda manifestu → „aktualizácia pluginu na Disku nie je tvoja verzia alebo ešte nie je celá".
  Nečitateľná → odmietnutie (fail-closed; §12 D2). **Kontrola beží vo `TimedWorker` (limit 60 s [R0]) pred exportom; hlavné vlákno len vyhodnotí výsledok** (audit 7).
  Odoslanie z novšieho pluginu než na Disku je povolené (R18).

### R-H · Odoslanie (U3b; A2 B3, O8)

- **R-H1 `publish_prepare(groups:, note:, precheck:)`** (hlavné vlákno, synchrónne podľa U2 §15.0 — volajúci U5 zatvoril okná): `admin_state == self`, výsledok R-G2 z `precheck`
  (worker), zámok R-B2 → per skupina `LibraryTransfer.export_group(g)` (kódy U2 vrátane `:dialogs_open`, `:other_instance`, `:busy_snapshot` = skupina `failed` s vetou U2) →
  `canonical_bytes` + prílohy do outboxu `Materials.dir/library_outbox/<id>/` → tiket. **Výber skupín (audit 1):** odošle sa skupina, ktorej **čerstvý** `group_fingerprint` z
  `export_group` ≠ odtlačok aktuálnej verzie na Disku, **alebo** `head.plugin ≠ Engine::VERSION` (nová verzia pluginu = povinné nové odoslanie, inak by ju R-G1 odmietlo),
  alebo skupina na Disku nie je. `entry.fingerprint` sa na výber **nepoužíva**.
- **R-H2 `publish_run(ticket)`** (vlákno): `N` = max(najvyšší viditeľný ukazovateľ, `entry.version`) + 1 → `v<N>-<r8>/` → `d/*`, `a/*` → `manifest.json` → **čítanie späť**
  (veľkosť + SHA256) → `head-<N>-<r8>.json` posledný → znova zoznam ukazovateľov.
- **R-H3 výsledok per skupina:** `sent` · `failed` (zvyšok na Disku bez ukazovateľa = neviditeľný) · `skipped`; pri `sent` aj `attachments_skipped`
  (`{entry_key => [{rel, reason}]}` z packetu — prílohy, ktoré U4 nepreniesol; U5 z neho skladá vetu „bez N fotiek“).
- **R-H4 (A2 B3):** po zápise iný ukazovateľ s číslom ≥ N a iným `id` (alebo konfliktná kópia) → `failed` „odoslanie neprešlo" + `head_conflict` (R-D2) — nič sa neopakuje automaticky.
- **R-H5 [R0]** zápis na H: priamo pod finálnym menom v jedinečnom priečinku (čiastočný súbor odhalí manifest).
- **R-H6 `publish_finish`** (hlavné vlákno): pre `sent` `update_sync_state!(g, …origin: publish, fingerprint: z tiketu)`; pre `failed` zápis `id` do lokálneho záznamu
  **nepublikovaných pokusov** `library_outbox/failed.json` (pre R-H7) → zámok uvoľniť → outbox zmazať.
- **R-H7 zametanie (R5, audit 9):** ponechá **5 najnovších skutočných publikácií** (priečinok + platný ukazovateľ aktivovaného správcu); zmaže len (a) staršie publikácie — vždy
  **ukazovateľ aj priečinok spolu**, a (b) priečinky `v*`, ktorých `id` je v `failed.json` tohto PC (preukázateľne nepublikované). Priečinok bez ukazovateľa, ktorý nie je v `failed.json`,
  sa **nikdy nemaže** (ukazovateľ môže doraziť neskôr). Žiadne kritérium veku ani hodín. Zlyhanie = úspech s poznámkou; nikdy verziu, ktorú drží tiket Vrátiť. **[R0]** T6.

### R-I · API U2, ktoré U3 používa (presne podľa PACKAGE_U2)

| U3 potrebuje | API U2 | Pozn. |
|---|---|---|
| skupiny, poradie, závislosti | `LibraryRegistry.groups`, `members(g)`, `library_members(g)`, `depends_on`, `dependents` (R1.2–R1.3) | `members` = poradie prevzatia, prílohy pred dokumentom |
| obsah na odoslanie a lokálny odtlačok | `LibraryTransfer.export_group(g)` → `[:ok, packet]` (R4.1) | `packet['documents']`, `['attachment_refs']`, `['fingerprints']`, `['plugin_version']` |
| bajty na Disk, odtlačok | `canonical_bytes(doc)`, `fingerprint(doc)` (R4.6) | `group_fingerprint` skladá U3 (R-A5) |
| prevzatie celej skupiny | `import_group!(g, packet, plugins_dir:, reason:)` (R4.2) | brány, záloha, návrat, druhé okno, UNI, `after_import!`; kódy R4.7 |
| zálohy | `create_backup!`, `backups(g)`, `restore_backup!(id, plugins_dir:)` (R4.3) | U3 vlastné zálohy **nerobí** |
| lokálny stav | `sync_state`, `update_sync_state!(g, entry)` (R4.5) | obsah `entry` R-B1 |
| verzia | `import_allowed?(v)`, `export_allowed?(disk_v)`, `compare_versions(a, b)` (R5) | R-G1, R-G2 |
| obnova po páde | `recover_pending!(plugins_dir)` (R4.9; volá `main.rb` pri boote pred `Materials.boot_cutover!`; žurnál `library_import.pending.json`, `last_recovery`, `pending_issue`) | R-J5 |
| zneplatnenie zobrazenia | výsledok `import_group!`/`restore_backup!` s `'refresh' => true` (R4.10) | R-J4 (U3 prenesie, `push_state` robí U5) |
| podmienky operácií | U2 §15.0: bez inej inštancie, okná knižníc zatvorené (`:dialogs_open`), synchrónne na hlavnom vlákne | U3 volá `export_group`/`import_group!`/`restore_backup!` len synchrónne; bariéru okien robí U5 |
| blok po prerušení | `pending_block(entry_key = nil)` (U2 §15.1) | R-F1 `blocked`, R-J2 |
| čítanie stavu bez bariéry | **`peek_group(g)` — požiadavka §12 D10** | R-F1, R-N1 |
| doklad dokončenia | **`import_group!(…, tag:)`, `import_done(tag)`, `ack_import_done!(tag)` — požiadavka §12 D11** | R-J5 |
| lokálny stav pre rozhodnutie | `local_fingerprint(group_key)` (U2 15.10) | `seen_fingerprint` v R-J2, R-L2, R-N1, R-N3; `restore_backup!` |
| náhľad zálohy | `backup_peek(backup_id)` → `[:ok, {group, documents, fingerprints}]` \| `[:broken \| :missing, veta]`; `restore_backup!(…, seen_fingerprint:)` (U5 D15) | R-K, R-N3 |
| **U3 → U5 (požiadavky U5 §12)** | `resolve_admin!` (D13), `diff` s `attachment_conflicts` (D14), `diff_documents`, `revert_prepare`, `revert!(g, ticket, note:, seen_fingerprint:)` (D15) | R-C5, R-N1, R-N3, R-L2 |

**Doplnené v U2** (§12 D6): (a) `update_sync_meta!` pre údaje PC (`pc_id`, `drive_root`, `admin`); (b) predpoklad R4.2 krok 2 „prílohy už ležia" — U3 ich uloží
pred `import_group!` (R-M), ale riadky prílohy majú v registri `lock` (`materials.lock`, `appliances.json.lock`, `templates.json.lock` drží volajúci) → U3 potrebuje
**verejný obal zámku** `LibraryTransfer.with_store_lock(entry_key)` (dnes R4.4 interný) alebo `place_attachments!` v U2.

### R-J · Prevzatie (U3b; R4, R6)

- **R-J1 `take_prepare(groups:)`** (vlákno): `verify_version` → kópia celej verzie do `Materials.dir/library_staging/<id>/` → **opätovné overenie stagingu** (Disk mohol súbor
  vymeniť) → tiket. Neúspešná skupina = `syncing`/`broken`, ostatné pokračujú.
- **R-J2 `take_commit(ticket, decisions:, plugins_dir:)`** (hlavné vlákno, synchrónne — U2 §15.0): zámok R-B2 · R-G1 · `pending_block` → `blocked` · **zastaraný tiket (audit 3):**
  pod zámkom sa odmietne (`stale_ticket`, nezávisle od `:overwrite`), keď `ticket.version ≤ entry.version` alebo tiket nie je **posledný pripravený** v tomto procese (sekvencia
  tiketov); cesta dozadu existuje len cez Vrátiť (R-L2). `decisions = { g => {action: :take | :overwrite | :skip, seen_fingerprint:} }`: `LibraryTransfer.local_fingerprint(g)`
  (U2 15.10 — jediná definícia lokálneho stavu) **≠ `seen_fingerprint`** (hodnota z `diff`, nad ktorou používateľ rozhodol) → `skipped_changed` **aj pri `:overwrite`**; lokálne zmeny bez `:overwrite` → `skipped` (R4). Vráti aj
  `dependents_skipped` z `LibraryRegistry.dependents` (text U5).
- **R-J3 poradie per skupina** (v poradí `GROUPS`): (1) `pending = {target_id, target_version, before_fingerprint, started_at}` do stavu · (2) prílohy R-M · (3) packet = `{group, plugin_version: manifest.plugin, documents: JSON.parse(staged d/*),
  attachment_refs, fingerprints}` → `import_group!(g, packet, plugins_dir:, reason: 'prevzatie verzie N', tag: target_id)` · (4) `:ok` → `update_sync_state!` (`fingerprint` z `result['fingerprints']`
  po usadení, `publisher_pc_id`, `pending: nil`) → `ack_import_done!(target_id)`; iný kód → výsledok so slovenskou vetou U2, `pending: nil` okrem `:failed_restore_failed` (ostáva, U5 ponúkne „Vrátiť zálohu").
  `:other_instance` / `:other_instance_unknown` na prvej skupine → zvyšok sa nespúšťa („Zavri ostatné okná SketchUpu").
- **R-J4 výsledok per skupina:** `taken` · `skipped` · `skipped_changed` · `syncing` · `broken` · `plugin_mismatch` · + kódy U2 R4.7 bez prekladu; `'refresh'` z U2 sa prenesie (U5). Staging sa zmaže po dobehu;
  zvyšky staršie ako 24 h zmaže najbližšie `take_prepare`.
- **R-J5 (A1 S1) prerušené prevzatie:** `version`/`id`/`fingerprint` prevzatej verzie sa do `entry` zapíšu **až po `:ok` celej skupiny** (R-J3 krok 4), nikdy po jednom store-e.
  Pád počas `import_group!` rieši pri štarte **`LibraryTransfer.recover_pending!`** (U2 R4.9, žurnál `library_import.pending.json`, volá ho `main.rb` pred `Materials.boot_cutover!`,
  teda pred `startup_check`). U3 potom pri `entry.pending` (audit 8 — všetky tri intervaly): **(a)** `import_done(target_id)` existuje (U2 dokončila, pád pred zápisom U3) →
  dopíše `entry` z jeho `fingerprints` a `ack_import_done!`; **(b)** `last_recovery` alebo `peek_group` = `before_fingerprint` (pád pred importom alebo obnovené) → `pending: nil`;
  **(c)** `pending_issue` alebo nič z toho → stav `pending` („Prevzatie sa prerušilo — vráť zálohu"), Aktualizovať skupiny vypnuté (U2 `pending_block` zároveň blokuje výpočty). Polovičná skupina sa nikdy nepoužije bez pokusu o návrat.

### R-K · Zálohy (O5) — len cez U2

U3 vlastné zálohy nerobí. „Vrátiť zálohu" = okno dopadov z `backup_peek(id)` + `diff_documents` (R-N3) → `restore_backup!(id, plugins_dir:, seen_fingerprint:)` pod zámkom R-B2
(nesúlad → `:changed` bez zápisu, U2); `entry` sa **nemení** (východisko ostáva poslednou prevzatou verziou → správne
`local_changes`). Zoznam = `backups(g)`. Riadok `library_backups/` pridáva U2 (R1.4).

### R-L · História a Vrátiť verziu (R5, O5)

- **R-L1** `history(g)` = R-D5; Vrátiť len pri `admin_state == self`.
- **R-L2 dvojfázové Vrátiť (U5 D15):** `revert_prepare(g, version_id)` vo vlákne = `verify_version` + staging ako R-J1 → tiket (okno dopadov: `diff` nad tiketom, R-N1, `seen_fingerprint` z `local_fingerprint`);
  `revert!(g, ticket, note:, seen_fingerprint:)` (hlavné vlákno): R-G1 (iný plugin → „verzia je z iného pluginu") · `local_fingerprint(g)` ≠ `seen_fingerprint` → `skipped_changed` ·
  tiket nie je posledný pripravený → `stale_ticket` (výnimka z R-J2 „verzia ≤ entry.version" — návrat dozadu je tu zámerný) → prevzatie lokálne cestou R-J3 (záloha a návrat U2) →
  odoslanie **bajtov tej verzie bez nového exportu** ako `N+1` s `reverted_from` a poznámkou „Návrat na verziu K z <dátum>". Zlyhanie odoslania → lokálne K, stav `local_changes`.
  Stará verzia sa nemení ani nemaže.

### R-M · Prílohy len pribúdajú (A4 B9, rozhranie pre U4)

- **R-M1 uloženie prílohy** = `LibraryAttachments.place(staged, local_rel, sha256)` pod `LibraryTransfer.with_store_lock` — **politiku, overenie, žurnál náhrad
  a upratanie definuje U4** ([PACKAGE_U4.md](PACKAGE_U4.md) R4.1, R1.6, D10). U3 len volá `place` pre každú prílohu manifestu pred `import_group!` a výsledok prenesie.
  Do U4 platí len: chýbajúci cieľ sa doplní, existujúci sa nemení. **Nikdy nič nemaže.**
- **R-M2** prílohy idú **pred** `import_group!` (U2 R4.2 krok 2 ich overuje — `:missing_attachments`).
- **R-M3** dočasné mená príloh registruje **U4** ([PACKAGE_U4.md](PACKAGE_U4.md)); U3 žiadne nepridáva.

### R-N · Zoznam zmien pre varovanie R4 (A4 B5, R17) — nad `peek_group`, overené `export_group` pri commite

- **R-N1 `diff(g, ticket, used_ids: {})`** (hlavné vlákno, pred rozhodnutím R4 pri otvorenom okne): lokálne dokumenty z `peek_group(g)` vs. dokumenty zo stagingu tiketu
  (tie isté bajty, ktoré sa importujú); výsledok nesie `seen_fingerprint` = `LibraryTransfer.local_fingerprint(g)` v okamihu diffu (pre R-J2) a **`attachment_conflicts: [{rel, label}]`** (U5 D14, U4 §15.2: povinná príloha
  tiketu, ktorej lokálny súbor pod rovnakým menom má iné SHA — len čítanie). `peek_group` `:unknown` → `diff: :unknown` (U5 ukáže všeobecné varovanie R4).
  Per knižnica `{ added:[{id,label}], changed:[{id,label,fields}], removed:[{id,label,used}] }`; `used = used_ids[entry_key].include?(id)` — množinu použitých ID otvorenej zákazky
  dodá U5 (potrebuje model; napr. `Materials.used_material_ids`), U3 ju len prenesie do výsledku.
- **R-N2 tabuľka záznamov** v U3 (`LibrarySync::RECORDS`): per `entry_key` cesta k poľu záznamov, kľúč identity a popisu (napr. `materials` → pole položiek, `id`, `name`);
  `fields` = mená najvyššej úrovne s odlišným `canonical_bytes`. Pole cien (`price*`, sadzby) sa označí `price_changed: true` pre vetu R17. Tvary dokumentov overí implementátor
  sondou na kóde pred písaním tabuľky; store bez stabilného ID → len počet zmien (§12 D7).
- **R-N3 `diff_documents(g, documents, used_ids:)`** (U5 D15): rovnaký výpočet a tvar ako `diff` (vrátane `seen_fingerprint` = `local_fingerprint(g)`, bez `attachment_conflicts`) nad ľubovoľnými cieľovými
  dokumentmi — pre okno dopadov pred „Vrátiť zálohu" (dokumenty z U2 `backup_peek`).

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
| stavy Disku, worker, zámok | `no_drive`, `no_root`, `empty`, `missing_known`, `ok`, `timeout`, `error`; single-flight, vlákno sa nezabíja; druhá operácia → `:busy` |
| správca | `none` → Odoslať vypnuté; `claiming` → Odoslať vypnuté; aktivácia pred lehotou T / pri druhom kandidátovi odmietnutá; dva kandidáti doručení oneskorene → `conflict`, Odoslať vypnuté na oboch, Aktualizovať len od `publisher_pc_id`; ukazovateľ cudzieho `pc_id` nikdy neprevzatý; konfliktná kópia `head-…` blokuje |
| R14/R18 | Aktualizovať pri inom pluginu odmietnuté (dva dôvody); Odoslať pri novšom na Disku odmietnuté; distribúcia `newer`, `older`, `same` s iným manifestom, nečitateľná → odmietnuté; `same` + zhodný manifest → povolené; precheck nikdy na hlavnom vlákne (fake worker) |
| odoslanie | ukazovateľ až po čítaní späť; zlyhanie kopírovania → bez ukazovateľa, stav nezmenený; súbežný ukazovateľ → `failed`; úprava po odoslaní A → B sa odošle (audit 1); po zmene VERSION sa odošlú všetky skupiny; zametanie necháva 5 publikácií, nemaže priečinok bez ukazovateľa mimo `failed.json` |
| prevzatie | staging overený znova (súbor vymenený medzi kópiou a overením); prílohy pred `import_group!`; príloha sa nikdy nezmaže; lokálne zmeny bez `:overwrite` → `skipped`; zmena po `status` → `skipped_changed`; kódy U2 (`:failed_restored`, `:failed_restore_failed` → `pending` ostáva, `:other_instance` zastaví zvyšok) prenesené bez zmeny |
| prerušenie (A1 S1, audit 8) | pád pred importom, počas importu, **po úspechu U2 a pred `update_sync_state!`** → po „štarte" (a)/(b)/(c) R-J5; zlyhaná obnova → `pending` |
| zastaraný tiket (audit 3) | tikety N a N+1, commit N po N+1 → `stale_ticket` aj s `:overwrite`; lokálna zmena po rozhodnutí → `skipped_changed` aj s `:overwrite`; Disk nižší než prevzatý → `disk_behind` |
| bez bariéry (audit 5) | `status` nevolá `export_group`; `peek_group :unknown` → `unknown`, nikdy `current`; `:dialogs_open` z U2 prenesené |
| Vrátiť | `revert_prepare` + `revert!` → lokálne K + Disk N+1 s `reverted_from`; K z iného pluginu odmietnuté; zmena po náhľade (`local_fingerprint`) → `skipped_changed`; starší tiket → `stale_ticket` |
| U5 API | `resolve_admin!`: mimo konfliktu `:not_conflict`, cudzí `pc_id` `:unknown_pc`, ponechané PC prejde `claiming` → `self` po T, druhé si `admin` zhodí; `diff` s `attachment_conflicts` (rovnaké meno, iné SHA); `diff_documents` = tvar `diff` |
| lokálne zmeny | po prevzatí `current`; po úprave `local_changes`; po zmene VERSION úprava pred aktualizáciou ostane `local_changes` (audit 2) |
| diff | pridané/zmenené/zmiznuté, `used` z `used_ids`, `price_changed` |
| guardy | čistota (R-O4); telá vlákien (R-E4); žiadny `JsonFileStore`/`.tmp` nad `<root>`; register (S13) |

**Koncový scenár („dve PC" = dva sandboxy `Materials.dir` + jeden „Disk"):** A claim → odošle všetko (v1) → B `never_taken` → prevezme → `current` → A zmení Materiály, odošle (v2)
s poznámkou → B `newer` + poznámka → B zmení Materiály → `newer_and_local` → `:skip` (Kovanie prevzaté) → `:overwrite` → záloha U2 + prevzatie → A Vrátiť v1 → B dostane v3 = v1.
**DoD:** Ruby a všetky JS sady zelené (každá zvlášť), encoding guard, R0 v §16 pred implementáciou; **U3b: export test P == K**.
**Akceptačná brána uzáveru bloku (A1 S6 — nie U3a/U3b, až po U4 a U5):** na dvoch skutočných PC cez skutočný Disk: odoslanie (vrátane príloh) → prevzatie na druhom PC
→ Vrátiť staršiu verziu → druhé PC ju prevezme: knižnice, prílohy a lokálny stav (`entry`, zálohy) sedia s verziou; postup = §10 bod 4.

## 8 · In-SU

Nie je brána; reálny Disk a dve PC = smoke U5 a akceptácia bloku (§7).

## 9 · Riziká

1. **Disk doručí inak [R0]** → manifest + SHA256 nezávisí od poradia; najhorší dôsledok = dlhšie `syncing`.
2. **Prepis mení čísla zákazky** (R17) → diff s `used`, záloha a návrat U2; texty U5.
3. **Po aktualizácii pluginu varovanie R4 aj bez úprav** (R-F3 konzervatívne) → zmizne, keď správca odošle novou verziou a odtlačky sa zhodnú; cena = jedno zbytočné varovanie.
4. **Zaseknuté vlákno nad H:** drží `library_sync.lock` do dobehu → `:busy` v tom okne do reštartu.
5. **Dvaja správcovia** (oneskorená synchronizácia dlhšia než T) → `conflict`, Odoslať vypnuté, cudzie publikácie sa neprijímajú (R-C3, R-C4, R19).
6. **API U2 sa zmení** (vrátane D10, D11) → U3b až po mergi U2a–c; zladenie package pred U3b.
7. **Veľkosť príloh a diakritika v ceste** → stropy, R0 T1/T8, testy s UTF-8 cestou.

## 10 · Smoke checklist pre Michala

U3 nemá okno (uvidíš ju v U5). Od teba treba **R0 sondu** a krátku kontrolu po inštalácii:

1. **Sonda (R0):** na svojom PC `scripts\sonda_disk_d48.ps1 -Role writer -Beh test1`, na Luciinom `… -Role reader -Beh test1` (do minúty po sebe); nechaj dobehnúť (≤ 20 min).
   CSV a `_summary.txt` z `%TEMP%\noxun_sonda_disk\` oboch PC pošli do okna (alebo nechaj v `_sonda\` na Disku).
2. Pri T4 skript povie „TERAZ" na oboch PC — Enter naraz (± 2 s). Pri T7 ťa požiada pozastaviť synchronizáciu Disku a po 5 min ju obnoviť.
3. **Po inštalácii U3a/U3b:** SketchUp sa spustí ako doteraz, O plugine vyzerá rovnako, v Materiáloch nič nepribudlo ani nezmizlo, v `%APPDATA%\NOXUN\Engine` nepribudol súbor.
4. **Akceptácia bloku (po U4 a U5, A1 S6):** odošli Materiály s novým dekorom a fotkou → na Luciinom PC Aktualizovať → dekor aj fotka sú tam → v Histórii vráť predošlú verziu
   → Lucia Aktualizovať → dekor zmizol, fotka na disku ostala, O plugine u oboch ukazuje rovnakú verziu. Až potom uzáver bloku.

## 11 · Checklist uzáveru (U3a aj U3b zvlášť)

Bump patch (2×) + `?v=` · testy zelené · **U3b export test P == K** · odseky `kniznice.md` + rozcestník + tabuľka časti 3 · STANDARD §13.1 · Grep zoznamov (LOCKS,
súbory koreňa) · STAV · KRONIKA · PLAN ✅ + PR · D-48 ostáva otvorený (zatvorí U5) · PR: predrecenzia, odkaz na R0.

## 12 · Rozhodnutia autora na potvrdenie orchestrátorom

- **D1 trieda:** potvrdené orchestrátorom 17.10. — U3a nie výrobná/cenová, **U3b áno** + export test P == K.
- **D2 R18 fail-closed** — **potvrdené orchestrátorom 17.10.:** keď sa distribúcia pluginu na Disku nedá prečítať, Odoslať sa odmietne (R18 „verzia nie je na Disku" sa nedá overiť).
- **D3 časový limit v core** — potvrdené: nový `TimedWorker`, updater D-52b ostáva (N1).
- **D4 (audit 2)** prebázovanie zrušené — po zmene VERSION konzervatívne `local_changes`, kým sa odtlačok nezhodne s Diskom (R-F3).
- **D5 (audit 4)** dva odosielajúce PC **môžu** nastať (oneskorená synchronizácia) → dvojfázový správca R-C3, prijímanie len od aktivovaného/`publisher_pc_id` R-C4, konfliktné kópie blokujú.
- **D6 čo chýba v U2** (vyriešiť v PACKAGE_U2 pred U3b): **(a)** `update_sync_state!` prijíma len `group_key ∈ GROUPS` — údaje PC (`pc_id`, `drive_root`,
  `admin`) → U2 dopĺňa `update_sync_meta!` (R4.5); **(b)** verejný `LibraryTransfer.with_store_lock(entry_key)`
  (R4.4 je dnes interný) na ukladanie príloh pod zámkom ich riadku pred `import_group!`. Riadky `library_backups/` a `library_sync.json` pridáva U2 (potvrdené); U3 len `library_sync.lock`,
  `library_staging/`, `library_outbox/`.
- **D7 diff** (R-N) je celý v U3 nad `export_group` a stagingom; tabuľka `RECORDS` sa opiera o tvary dokumentov — implementátor ich pred písaním overí sondou; store bez stabilného ID
  dostane len počet zmien.
- **D8 rozloženie verzie** = priečinok s kópiou dokumentov a príloh pod menami z obsahu (A4 SIMPLER); duplikácia príloh medzi verziami prijateľná.
- **D9 koreň** = per-PC hodnota s predvoľbou R11, bez UI na zmenu.
- **D10 požiadavka na U2 — `LibraryTransfer.peek_group(group_key)`** (audit 5): čisto na čítanie, **bez bariéry** (smie bežať pri otvorených oknách a v O plugine), bez zámku na
  čakanie (zámok `LOCK_SH | LOCK_NB`, obsadený → `:unknown`), **bez akéhokoľvek zápisu** (žiadne seed, seed-merge, `migrate!`, `.bak`, UNI, cache stav modulov sa nemení), bez
  `Sketchup`. Pre každú knižnicu skupiny číta primár zo disku **bez fallbacku na `.bak`**. Výsledok `[:ok, {'documents' => {entry_key => doc}, 'fingerprints' => {entry_key => sha256}}]`
  **len keď** primár existuje, parsuje sa, nie je degradovaný a je usadený (dokument je presne ten, ktorý by `export_group` vrátil bez zmeny — inak by sa odtlačky líšili);
  inak `[:unknown, veta]` (napr. chýba, poškodený, pred migráciou, `pending_block`, zámok obsadený). Odtlačok = `fingerprint(doc)` rovnako ako R4.6. Prílohy sa nečítajú.
- **D11 požiadavka na U2 — doklad dokončenia prevzatia** (audit 8): `import_group!(…, tag: String)` po úspechu (pred zmazaním žurnálu) zapíše trvalý záznam
  `{tag, group, fingerprints, finished_at}` (napr. `library_import.done.json`, riadok registra `marker`/`local`); `import_done(tag)` → Hash | nil; `ack_import_done!(tag)` ho zmaže.
  U3 ho používa len v R-J5 (a). Bez `tag:` sa nič nezapisuje (spätná kompatibilita).

## 13 · Otázky pre Michala

**Uzavreté 17.10.2026 — R18** (výklad R14: Aktualizovať len pri rovnakej verzii; Odoslať blokuje novší plugin na Disku alebo správcova verzia ešte nie je na Disku — R-G2)
**a R19** (dvaja správcovia: Odoslať vypnuté na oboch, riešenie ručne v „⋯", Aktualizovať ide ďalej — R-C1). Ďalšie otázky žiadne.

## 14 · Nálezy mimo scope

- **N1:** kontrola verzie pluginu v O plugine (`supplier_settings_dialog.rb:354-423`) môže neskôr použiť `TimedWorker` — jeden vzor namiesto dvoch (refaktor, guard D-52b).
- **N2:** loader píše lease bez `exe` (`noxun_engine.rb:161-168`) — zjednotenie s `Updater.write_lease!` pre D-52.
- **N3:** `Debug.report` + `LibrarySync.status` (porovnanie Michal vs. Lucia); **N4:** história v U5 aj s PC a verziou pluginu.

## 15 · Audit návrhu — zapracovanie (Codex `gpt-6-astra`, 17.10.2026; [AUDIT_U3_raw.md](AUDIT_U3_raw.md))

| # | Nález | Verdikt | Zapracovanie |
|---|---|---|---|
| 1 | BLOCKER nezmenená skupina sa porovnáva so starým `entry` | platný | **R-H1** výber podľa čerstvého exportu vs. Disk + povinné odoslanie po zmene VERSION |
| 2 | BLOCKER prebázovanie skryje zmeny | platný | **R-F3** bez prebázovania, konzervatívne `local_changes`; D4 |
| 3 | BLOCKER starý tiket prepíše novšiu verziu | platný | **R-J2** `stale_ticket` pod zámkom, `seen_fingerprint`; **R-F1** `disk_behind` |
| 4 | FIX dvaja správcovia pri oneskorení | platný | **R-C3** dvojfázový claim s lehotou T [R0], **R-C4** prijímanie len od aktivovaného správcu/`publisher_pc_id`, **R-D2** konfliktné kópie blokujú; R19 |
| 5 | FIX stav a diff cez `export_group` s bariérou | platný | **R-F1**, **R-N1** cez `peek_group` (**D10** požiadavka na U2), `:unknown` ≠ `current`; export len v commite |
| 6 | FIX R18 nepreukazuje dostupnosť verzie | platný | **R-G2** `same` + zhodný manifest balíka na Disku a bežiaceho pluginu |
| 7 | FIX kontrola distribúcie bez limitu | platný | **R-G2** precheck vo `TimedWorker`, **R-H1** len vyhodnotí |
| 8 | FIX pád medzi U2 a zápisom U3 | platný | **R-J5** (a)/(b)/(c), **D11** doklad `tag` od U2, `before_fingerprint` v `pending` |
| 9 | FIX zametanie maže priečinok bez ukazovateľa | platný | **R-H7** 5 skutočných publikácií, mazanie len s ukazovateľom alebo z `failed.json`, bez veku |
| 10 | NOTE S1–S5 nie všetky uzavreté | platný ako stav | S1–S3 = návrh U2 §15 (dôkaz až implementáciou U2b); S4 čiastočne do smoke U5 (U2 §15.7); S5 v U3 opravené bodmi 1 a 6; R0 nedokazuje budúce poradie — návrh od poradia nezávisí (R-D3), mená konfliktov blokujú konzervatívne (R-D2) |
| 11 | (U5 §12 D13–D15) API pre okno | doplnené | **R-C5** `resolve_admin!`, **R-N1** `attachment_conflicts`, **R-N3** `diff_documents`, **R-L2** `revert_prepare`/`revert!`, **R-K** `backup_peek` + `seen_fingerprint`; všetky `seen_fingerprint` z U2 `local_fingerprint` (15.10) |

## 16 · Výsledok sondy R0

*(doplní sa po behu na oboch PC; dovtedy package nie je zmrazený — požiadavky [R0] sú predbežné)*
