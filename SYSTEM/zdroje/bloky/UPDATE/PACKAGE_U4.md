# PACKAGE U4 · Prílohy a fotky dekorov v zdieľanej knižnici (D-48) — blok UPDATE

> **Stav: NÁVRH — čaká audit návrhu (`codex-audit`).** Dátum 17.10.2026. Package do zásoby — **implementácia až po smoke PASS bloku 9 HARDENING**
> (alebo Michalovom „ideme ďalej") a po mergi **U2a, U2b, U3a, U3b** (poradie RECONCILE §3: U2 → U3 → **U4** → U5; A2 B6 — okno až po prílohách).
> **Autorita:** [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) **R8, R15** (fotky dekorov cez Disk, len tie, na ktoré katalóg odkazuje), R5, R14, R16 ·
> mockup O3 (skupina Materiály „+ ABS pravidlá, vzhľady, fotky dekorov", Šablóny „+ náhľady", Spotrebiče „+ listy") · [RECONCILE_2026-10-17.md](RECONCILE_2026-10-17.md) §2 riadky
> „Prílohy spotrebičov", „Fotky dekorov", „Mená súborov", §3 riadok U4 · [CROSS_AUDIT_A4_CLAUDE_KOD.md](CROSS_AUDIT_A4_CLAUDE_KOD.md) **B1, B9**, A6 ·
> [CROSS_AUDIT_A2_GROK.md](CROSS_AUDIT_A2_GROK.md) A6, B6, C · [CROSS_AUDIT_A3_RESERS_WEB.md](CROSS_AUDIT_A3_RESERS_WEB.md) FIX 1, **FIX 4** ·
> rozhrania [PACKAGE_U2.md](PACKAGE_U2.md) (R1.2 `GROUPS`, R3.2 krok 4, R4.1 `export_group`, R4.2 `import_group!`, R4.4 `with_store_lock`, R4.5 `update_sync_state!`, R4.8) ·
> [PACKAGE_U3.md](PACKAGE_U3.md) (R-A2/R-A5 manifest a mená na Disku, R-B1 `entry`, R-F1 `status`, R-H1 odoslanie, R-J3 prevzatie, **R-M** `place_attachment`) ·
> súpis [../../../../docs/architecture/kniznice.md](../../../../docs/architecture/kniznice.md) **F2**.
> **Audit návrhu (Codex `gpt-6-astra`, 17.10.) zapracovaný v §15 — §15 MÁ PREDNOSŤ pred §1–§14** ([AUDIT_U4_raw.md](AUDIT_U4_raw.md)).
> **Trieda Ť** · audit-povinná (zmena dátového kontraktu zdieľania — pripnutá zdieľaná množina a riadok registra; nový modul) · predrecenzia · **nie výrobná/cenová** (§12 D1) ·
> in-SU nie je brána · bez rezu (odhad ~300 riadkov kódu pluginu).
> **Stav kódu:** sonda nad `docs/update-start` `1468dfe2` (kód = `main` `a9e8c79d`, plugin **v0.18.1**). U2/U3 v kóde ešte nie sú — U4 ich API používa **presne podľa ich packages**;
> pri štarte dávky implementátor overí riadky znova a mená API proti zmergovanému kódu U2/U3.

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 17.10.2026, len čítanie

Cesty relatívne k `noxun_engine/`. Bez spustenia, bez zápisu do modelu či `%APPDATA%`.

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | Meno fotky dekoru = `<sha1(čistá URL)[0,10]>_<basename cesty URL>` v `Materials.dir/textures/`; deterministické z URL → na oboch PC rovnaké | `core/demos/image_cache.rb:27-29`, `:33-38` | PRAVDA |
| S2 | URL prejde `sanitize_image_url` (https, allowlist host, cesta `/content/images/product/`, prípona `.jpg/.jpeg/.png` po dekódovaní, bez query); `URI.parse` surovú diakritiku nepustí → basename je **ASCII**, môže však niesť `%XX` a veľké písmená prípony | `core/demos/client.rb:64-81`, `:86-97` | PRAVDA (`URI.parse` s ne-ASCII = výnimka → `nil`, štandard Ruby 3.2 — NEOVERENÉ behom) |
| S3 | Fotka sa stiahne **raz** pri založení skupiny z Demosu; celá skupina dosiek nesie **tú istú** `image_url` | `core/demos/family.rb:431-433`, `:459` | PRAVDA |
| S4 | `local_for` vráti cestu len pre **platný** obrázok (JPEG/PNG magic); okno Materiály posiela dlaždici výhradne lokálny súbor, inak farbu | `image_cache.rb:45-56`; `ui/materials_dialog.rb:320-324` | PRAVDA → F2 |
| S5 | `image_url` nesie normalizácia záznamu (dosky aj ABS — spoločná `normalize`), marker schémy 6 | `core/materials.rb:679`, `:1008-1013`, `:416` | PRAVDA |
| S6 | Zápis fotky = `.tmp<pid>` + `FileUtils.mv` **bez zámku**, strop 3 MB, kontrola magic | `image_cache.rb:20-21`, `:77-95` | PRAVDA → `lock_mode: mixed` (R2.1) |
| S7 | Register: `textures` = `kind: cache`, `sync: local`, **bez zámku**, `children: ??????????_*`, `transient: *.tmp[0-9]*` | `core/library_registry.rb:169-171` | PRAVDA |
| S8 | Vzhľad `appearances/<uuid>.skm`: nové UUID pri každom publikovaní, existujúci súbor = chyba „Revízia vzhľadu už existuje" → **nemenný**; režim `color` súbor nemá | `core/materials_appearance.rb:109-112`, `:123-125`, `:138-140` | PRAVDA |
| S9 | Náhľad šablóny `template_previews/<kind>-<slug>-<sha1("kind:name")[0,16]>.png`: identita z **druhu a mena**, slug ASCII; pri novom uložení šablóny sa **prepíše pod tým istým menom** (`replace`), pri uložení bez náhľadu sa zmaže, pri premenovaní presunie | `core/template_previews.rb:23-27`, `:60-83`, `:89-101`, `:255-294`, `:329-350`; `core/templates.rb:401-411` | PRAVDA (A4 B9 „kopírovať podľa obsahu") |
| S10 | Záznam šablóny = `{name, kind, config}` **bez časovej pečiatky** → prepis náhľadu pri nezmenenej konfigurácii nemusí zmeniť bajty `templates.json` | `templates.rb:723-728` | PRAVDA → R5 (zmena len prílohy) |
| S11 | Náhľad sa do okna posiela len cez `data_uri` (PNG magic, ≤ 64 kB); `valid_file?` existuje | `template_previews.rb:48-51`, `:121-135`, `:143` | PRAVDA |
| S12 | List spotrebiča `appliances/<id>/<uuid>_<slug>.<ext>`: UUID prílohy, ASCII slug, nemenné meno; snapshot zákazky na súbor **odkazuje** (nesmie zmiznúť); zmazanie prílohy v katalógu súbor maže | `core/appliance_catalog.rb:210-219`, `:1058-1066`, `:1072-1076`, `:1343-1345`, `:1381-1386`, `:1176` | PRAVDA (A4 B9) |
| S13 | `Updater.safe_relative!` odmietne prázdnu, absolútnu, `\`, `.`/`..` segment — **znakovú sadu nekontroluje** | `core/updater.rb:377-389` | PRAVDA → R4.2 |
| S14 | Guard pripína `SHARED` (12 kľúčov) — zmena = rozhodnutie Michala; triedenie mien kontroluje `transient` **pred** `children`; tvar: priečinok musí mať `children`, `attachments` ↔ `of`, `mixed` vyžaduje zámok z `LOCKS` | `tests/pure/test_h16_kniznice.rb:43-45`, `:308-312`, `:523-540`, `:781`, `:855-856` | PRAVDA |
| S15 | `WRITE_SITES` pripína počet zápisových miest per súbor (`image_cache.rb` = 4) — nový zapisovateľ = nový riadok | `test_h16_kniznice.rb:72-106` | PRAVDA |
| S16 | U2 overuje pri importe **len** `.skm` (Materiály) a prílohy spotrebičov; `attachment_refs(doc)` má len pri Materiáloch a Spotrebičoch; `textures` nechá bez skupiny (D3) | PACKAGE_U2 R3.2 krok 4, §3, §12 D3 | PRAVDA (package) |
| S17 | U3 dáva na Disk prílohy pod menom z obsahu `a/<sha256[0,24]>.<ext>` (ASCII), lokálne meno nesie v manifeste `local` overené `safe_relative!` a `children`; `place_attachment(staged, local_rel, sha256, policy:)` s politikou **z U4**, upratanie `.d48old-*` **rieši U4**; prílohy sa do `group_fingerprint` nerátajú | PACKAGE_U3 R-A2, R-A5, R-M1–R-M3 | PRAVDA (package) |
| S18 | Migrácia mien netreba: všetky štyri druhy majú mená odvodené z nemennej identity (URL, UUID, druh+meno) — premenovanie by identitu **rozbilo** | S1, S8, S9, S12 | PRAVDA (A4 B9); stav reálnych priečinkov overí R0 |

---

## 1 · Cieľ (funkčne)

Po U4 cestuje s knižnicou aj to, čo nie je JSON: **vzhľady materiálov** (`.skm`), **fotky dekorov** (dlaždice v okne Materiály), **náhľady šablón** a **technické listy
spotrebičov**. Lucia po Aktualizovať uvidí v Materiáloch **fotky namiesto farieb** (F2), pri šablónach Michalove náhľady a pri spotrebičoch otvorí ten istý PDF list.

Pravidlá, ktoré používateľ pocíti:
- **Nič sa nezmaže.** Súbor, ktorý už Lucia má, ostane (zákazka môže na list spotrebiča odkazovať — A4 B9). Pribúdajú len nové.
- **Náhľad šablóny vyhrá Michalov** (Michal ho pri novom uložení šablóny prefotil — rovnaké meno, nový obsah).
- **Fotka dekoru je „pekná, nie nutná":** keď ju Michal sám nemá (Demos ju vtedy nedal), knižnica sa aj tak odošle, len bez fotky — Lucia uvidí farbu ako dnes.
- **Vzhľad `.skm` je nutný:** bez neho by Lucia mala materiál bez Michalovho vzhľadu (A4 B1) → Odoslať takú skupinu Michalovi odmietne s vetou, ktorý vzhľad chýba.
- **Zmena len prílohy sa ráta ako zmena:** Michal prefotí náhľad šablóny bez zmeny jej nastavení → riadok Šablóny ukáže „zmenené" a Odoslať ho pošle.

**Príklad:** Michal založí z Demosu skupinu „Dub Halifax" (fotka sa stiahne), odošle Materiály. Lucia klikne Aktualizovať → fotka `3f2a9c01de_h1180-st37.jpg` pribudne do jej
`textures\`, dlaždica ukáže dub. Mala by už rovnakú fotku (sama si kedysi založila tú istú skupinu) → jej súbor ostane, nič sa nekopíruje.

## 2 · Rez a odhad

| Časť | Obsah | Kód pluginu (+) | Testy | Odhad |
|---|---|---|---|---|
| **U4** (jeden PR) | R0 inventár príloh (skript mimo pluginu) · R1 nový modul `core/library_attachments.rb` (riadky, politiky, bezpečné mená, výber odkazovaných príloh, odtlačok príloh, žurnál náhrad) · R2 register `textures` → zdieľané v skupine Materiály · R3 odkazy príloh per store (fotky v Materiáloch, náhľady v Šablónach) + brána odosielateľa · R4 zapojenie do U3 (politika, overenie, žurnál, upratanie) · R5 zmena len prílohy = lokálna zmena správcu · R6 docs | ~300 | ~450 | 1 deň |

Bez rezu: časti sú previazané (register ↔ výber ↔ politika). **Poistka:** nad ~400 riadkov kódu pluginu → implementátor zastaví a hlási (orchestrátor rozhodne o reze
U4a „register + výber + brána" / U4b „zapojenie do U3 + R5").

**Poradie commitov (záväzné):** (1) R0 skript + charakterizačné testy (plugin bez zmeny) · (2) R1 modul + testy · (3) R2 register + guard H16 · (4) R3 odkazy per store + brána ·
(5) R4/R5 zapojenie do U3 · (6) docs a uzáver.

## 3 · Scope IN

- `scripts/sonda_prilohy_d48.rb` + `.ps1` — read-only inventár príloh na oboch PC (R0).
- **Nový modul** `core/library_attachments.rb` (`Noxun::Engine::LibraryAttachments`, `module_function`, bez `Sketchup`/`UI`).
- `core/library_registry.rb`: riadok `textures` (druh, zdieľanie, skupina, zámok, `of`, `transient`), `materials.attachments` += `textures`, `GROUPS['materials'].members` += `textures`.
- `Materials.attachment_refs(doc)` (U2) rozšíriť o fotky dekorov; nové `TemplateStore.attachment_refs(doc)` (náhľady); brána povinných príloh v `LibraryTransfer.export_group`.
- Zapojenie do U3: `place_attachment` s politikou a validátorom z U4, overenie odtlačku po uložení, žurnál náhrad a jeho dokončenie/návrat po `import_group!`, upratanie, `attachments_digest`
  v `entry` a stav `local_changes` správcu pri zmene len príloh.
- Guard `test_h16_kniznice.rb` (`SHARED` +1 podľa R15, `WRITE_SITES`), dokumentácia (kniznice.md §2/§3/F2, odseky `library_attachments`, `image_cache`, `template_previews`).

## 4 · Scope OUT

- **Mechanika Disku** (manifest, mená `a/<sha>`, kopírovanie do outboxu a stagingu, overenie celistvosti, história, zametanie) — **U3** (U4 len dodá, *ktoré* súbory a *ako* ich uložiť).
- Kanonický export/import dokumentov, zálohy JSON, brána `.skm` pri importe (U2 R3.2 krok 4) — **U2** (U4 ju nemení).
- **UI** — texty výsledkov („Odoslané bez 3 fotiek", „chýba vzhľad …"), riadky skupín, varovanie R4 — **U5** (U4 dodá kódy a počty).
- **Dotiahnutie chýbajúcej fotky z Demosu** po prevzatí (A4 A6 „doplnok", RECONCILE) — mimo bloku, §14 N1.
- Zálohovanie príloh (U2 R4.3: prílohy sa nezálohujú — len pribúdajú) · mazanie sirôt (súbor, na ktorý už nič neodkazuje) — nikdy (A4 B9) · premenovanie existujúcich súborov (S18).
- Zmena `children` vzorov existujúcich riadkov (§12 D5) · zámok pri bežnom zápise fotky z Demosu (§12 D4).

## 5 · Trieda a brány

- **Trieda Ť** (CLAUDE.md, Výber profilu): **audit-povinná** — mení dátový kontrakt zdieľania (pripnutá zdieľaná množina, riadok registra a jeho zámok, tvar `entry` U3) a pridáva
  **nový modul** → profil `implementator`.
- **`codex-audit` povinný** (R12: `gpt-6-astra` **úzko** — tento package + PACKAGE_U2 R1/R3.2/R4.1/R4.4 + PACKAGE_U3 R-A5/R-B1/R-F1/R-J3/R-M, súbory zo §0). Sonda §0 = krok 0.
  Nové `STD` nevzniká (manifest je U3 `FORMAT_STD`; `entry` je obsah U3 v obálke U2 `SYNC_STD` — §12 D6).
- **Predrecenzia povinná** (audit-povinná dávka).
- **Výrobná/cenová: NIE** (§12 D1) — prílohy nemenia rozmery, počty, hrany, kusovník, VEPO, nákup, kovanie ani ceny; dokumenty knižníc sa nemenia. **Export test** preto nie je brána;
  odporúčaný ako lacný dôkaz (`P == K`), keď orchestrátor rozhodne inak.
- **In-SU:** spúšťače (buildery, observery, undo, geometria, akcie panela do modelu) sa nemenia → **nie je brána** (§8). **Fotky okien:** nie (UI sa nemení).
- **Smoke:** viditeľný až s U5 (§10).

## 6 · Požiadavky

### R0 · Inventár príloh a charakterizácia PRED zásahom (1. commit, plugin bez zmeny)

- **R0.1 skript** `scripts/sonda_prilohy_d48.rb` (standalone Ruby `C:\Ruby32-x64`, **bez** `require` pluginu, len čítanie) + spúšťač `.ps1 [-Root <cesta>]` (predvolene `%APPDATA%\NOXUN\Engine`).
  Číta `materials.json`, `templates.json`, `appliances.json` a priečinky `appearances/`, `textures/`, `template_previews/`, `appliances/`; vypíše do `%TEMP%\noxun_sonda_prilohy\<čas>.txt`:
  per druh počet a súčet veľkostí · **odkazované a chýbajúce** · **neplatné** (fotka bez magic, náhľad > 64 kB, prázdny `.skm`) · **mená mimo pravidla R1.3** (znaky, dĺžka) · siroty (len počet)
  · najdlhšia relatívna cesta a dĺžka absolútnej cesty koreňa. Odvodenie mena fotky a náhľadu skript **reimplementuje** z S1/S9 (a test R0.3 overí zhodu s pluginom).
- **R0.2 beh na Michalovom aj Luciinom PC** pred zmrazením package (výsledok do §16). **Rozhoduje:** (a) či treba **migráciu** — očakávanie podľa S18 nie; keď sa nájdu mená mimo R1.3,
  riešenie je **vynechanie** takej prílohy pri odoslaní s hlásením (R3.4), nie premenovanie; (b) objem fotiek pre riziko §9 R4 (história 5 × fotky na Disku).
- **R0.3 charakterizačné testy** (`tests/pure/test_u4_prilohy.rb`, časť „pred"): odvodenie mena fotky (S1) a náhľadu (S9) pre vzorové vstupy (ASCII, `%C4%8D`, veľká prípona `.JPG`,
  dlhé meno) — **zelené na `main` pred zásahom** a po U4 bez zmeny; `Materials.write` s `image_url` zachová URL; `TemplatePreviews.replace` prepíše pod tým istým menom.

### R1 · Nový modul `Noxun::Engine::LibraryAttachments` (`core/library_attachments.rb`)

Načítanie v `main.rb` za `core/library_transfer` (U2) a pred `core/library_sync*` (U3); `tests/helper.rb`. Pri načítaní nesiaha na disk. Čisté funkcie + malé súborové operácie v `Materials.dir`.

- **R1.1 `POLICIES`** (zmrazené, jediná autorita; kľúč = riadok registra druhu `attachments`):

| Riadok | Knižnica | Povinná pri odoslaní | Politika pri prevzatí | Validátor obsahu | Dôvod |
|---|---|---|---|---|---|
| `appearances` | `materials` | **áno** | `:keep_local` | veľkosť > 0 | nemenné UUID (S8); iný obsah pod tým istým UUID = anomália → ponechať + hlásiť `conflict` |
| `textures` | `materials` | nie | `:keep_valid` | `DemosImageCache.valid_image_file?` | obe PC majú fotku tej istej URL; náhrada len keď lokálna nie je platný obrázok (fragment) |
| `template_previews` | `templates` | nie | `:replace` | `TemplatePreviews.valid_file?` | rovnaké meno, nový obsah = Michal prefotil (S9) |
| `appliance_files` | `appliances` | **áno** | `:keep_local` | veľkosť > 0 | nemenné UUID; snapshot zákazky odkazuje (S12) — nikdy neprepisovať |

  Guard: každý riadok `kind: attachments` so `sync: shared` má práve jeden záznam v `POLICIES` a naopak.
- **R1.2 `row_for(rel)`** *(dočasné mená → §15.3)* → kľúč riadku podľa prvého segmentu a `children` riadku (`File.fnmatch` s príznakmi guardu H16 — `FNM_PATHNAME | FNM_EXTGLOB | FNM_DOTMATCH`);
  meno, ktoré spĺňa `transient` riadku, **nie je** príloha (`nil`). Neznáme = `nil`.
- **R1.3 `safe_local?(rel)`** *(limit dĺžky → §15.5)* (A3 FIX 4 pre **lokálne** mená; mená na Disku sú ASCII z obsahu už v U3 R-A2): `Updater.safe_relative!` prejde (S13) **a** `row_for(rel)` nie je `nil`
  **a** každý segment len `[A-Za-z0-9._%~()+,;=@!$&'-]` (bez medzery, bez znakov zakázaných vo Windows `<>:"|?*`, bez koncovej bodky) **a** `rel.length ≤ 160`
  **a** segment nie je rezervované meno Windows (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`, bez ohľadu na príponu a písmená). Vráti `true/false`, nikdy výnimku.
- **R1.4 `refs_for(entry_key, doc)`** → `{ 'required' => [rel], 'optional' => [rel], 'skipped' => [{rel, reason}] }` (relatívne k `Materials.dir`, POSIX lomky, bez duplicít, zoradené):
  - `materials`: `required` = `appearances/<id>.skm` pre každý `appearance` s `mode == 'native'` v `sheets`/`edges` (logika U2 `Materials.attachment_refs` — **zdieľa sa, nekopíruje**);
    `optional` = `textures/<meno>` z `DemosImageCache.path_for(r['image_url'])` pre každý záznam `sheets`/`edges` s neprázdnou `image_url`, **len ak** súbor existuje a je platný;
    neexistuje / neplatný → `skipped` `reason: 'missing'` / `'invalid'`.
  - `templates`: `optional` = `TemplatePreviews.path_for(TemplateStore.normalize_kind(t['kind']), t['name'])` pre každý záznam, len ak `valid_file?`; inak nič (šablóna bez náhľadu je bežná).
  - `appliances`: `required` = prílohy záznamov cez existujúci resolver (S12, U2 `ApplianceCatalog.attachment_refs`).
  - Každá cesta prejde `safe_local?`; neprejde → `skipped` `reason: 'unsafe_name'` (aj pri `required` — R3.4 rozhodne o odmietnutí).
- **R1.5 `digest(refs_with_sha)`** → SHA-256 hex nad `"<rel>\0<sha256 obsahu>\n"` zoradenými podľa `rel` (`required` + `optional`, bez `skipped`). Prázdna množina = digest prázdneho reťazca.
  `file_sha256(abs)` = streamovaný SHA-256 (bloky 64 kB).
- **R1.6 Žurnál náhrad** *(NAHRADENÉ §15.1 — vlastný žurnál nevzniká)*: `place(staged_abs, rel, sha256)` (volá U3 R-M1 namiesto vlastnej politiky — R4.1) → `{ 'rel', 'action' => 'placed'|'same'|'kept'|'replaced'|'conflict',
  'old' => <abs .d48old-…> | nil }`. `commit_replaced!(journal)` → zmaže `old` súbory žurnálu (len `.d48old-*` vlastných mien). `rollback_replaced!(journal)` → pre každé `replaced`:
  ak `old` existuje, finálne meno sa vymení späť (`rename` nového na `<cieľ>.d48new-<r8>`, `old` → cieľ, `.d48new-*` zmazať); `placed` súbory **ostávajú** (len pribúdajú). Obe vracajú
  počty a nikdy nevyhodia výnimku (chyba = log + počet `failed`).
- **R1.7 `sweep!(now:)`** *(vzory → §15.3; podmienka → §15.1)* — zmaže `*.d48-*`, `*.d48old-*`, `*.d48new-*` staršie ako 24 h **len** v priečinkoch riadkov z `POLICIES` (výpis priečinka riadku, nie koreňa — F13), a len keď
  `LibraryTransfer.sync_state` nemá žiadnu skupinu s `pending` (U3 R-J5 — prerušené prevzatie si dočasné súbory nechá na ručné rozhodnutie). Volá ho U3 `take_prepare` (R4.4).

### R2 · Register: fotky dekorov sú zdieľaná príloha Materiálov (R15, U2 §12 D3)

- **R2.1 riadok `textures`** *(`transient` vzory → §15.3)* (`library_registry.rb:169-171`): `kind: 'attachments'` (bolo `cache`), `sync: 'shared'` (bolo `local`), `of: 'materials'`, `lock: 'materials.lock'`,
  `lock_mode: 'mixed'` (D-48 ukladá pod zámkom, sťahovanie z Demosu bez neho — S6, §12 D4), `children` **bez zmeny** (`??????????_*` — §12 D5), `transient` += `*.d48-*`, `*.d48old-*`,
  `*.d48new-*` (U3 R-M3 pridá prvé dve ostatným prílohovým riadkom; U4 doplní `*.d48new-*` **všetkým** prílohovým riadkom), `writers` += `core/library_attachments.rb` (U3 súbor, ktorý
  volá `place`, tiež — podľa skutočnej implementácie), `note` „fotky dekorov `<sha10>_<meno>`; zdieľajú sa len odkazované (R15); sťahovanie z Demosu bez zámku".
- **R2.2** riadok `materials`: `attachments: %w[appearances textures]`. `GROUPS['materials']['members']` (U2 R1.2) = `appearances`, `textures`, `materials`, `abs_rules` (prílohy pred dokumentom).
- **R2.3 guard** `test_h16_kniznice.rb`: `SHARED` += `textures` s komentárom „R15 Michal 17.10.2026" (S14 — rozhodnutie Michala je v repe); `WRITE_SITES` riadok
  `core/library_attachments.rb` (počet podľa implementácie, dôvod „D-48 prílohy: uloženie, náhrada, návrat, upratanie") a úprava riadku súboru U3, ktorý prílohy ukladá; test triedenia
  (`:781`) doplniť o `textures/0123456789_a.jpg.d48old-1a2b3c4d` → `:transient`. Golden prvého behu H16 sa **nemení** (fotky pri prvom behu nevznikajú) — ak by sa menil, STOP.
- **R2.4** pravidlo kniznice.md §1 („Len tento PC = … cache") ostáva pravdivé: `textures` prestáva byť cache v súpise; `DemosImageCache` ostáva lokálna cache *mechanizmom* sťahovania.

### R3 · Odkazy príloh per store a brána odosielateľa

- **R3.1** `Materials.attachment_refs(doc)` (U2) a `ApplianceCatalog.attachment_refs(doc)` (U2) + nové `TemplateStore.attachment_refs(doc)` vracajú **zoznam rel. ciest** (tvar U2 packetu
  `attachment_refs => {entry_key => [rel]}` sa **nemení**) = `required + optional` z `LibraryAttachments.refs_for` (R1.4). Logika výberu žije **len** v `refs_for`; store-y delegujú.
- **R3.2** `LibraryTransfer.export_group` (U2 R4.1) — po exportoch dokumentov: `refs_for` každej knižnice skupiny; **ktorákoľvek `required` v `skipped`** (chýba, neplatná, nebezpečné meno) →
  celá skupina `[:missing_attachments, [rel…]]` (kód už existuje v U2 R4.7; veta „V knižnici chýba príloha, na ktorú katalóg odkazuje: …"). `optional` v `skipped` skupinu **nezastaví** —
  packet dostane navyše kľúč `'attachments_skipped' => {entry_key => [{rel, reason}]}` (U5 z neho zloží vetu „bez N fotiek") a `'attachments_digest'` (R1.5) nad tým, čo ide.
- **R3.3** Prevzatie: brána U2 R3.2 krok 4 sa **nemení** (vyžaduje len `.skm` a prílohy spotrebičov). Fotka ani náhľad prevzatie **nikdy** nezastavia.
- **R3.4** Mená mimo R1.3 (ak ich R0 nájde): `optional` → vynechané s `reason: 'unsafe_name'` · `required` → skupina sa neodošle (R3.2), Michal dostane meno súboru; **žiadne automatické
  premenovanie** (S18).

### R4 · Zapojenie do U3 (prevzatie a odoslanie)

- **R4.1 uloženie prílohy** *(náhrada a konflikt → §15.1, §15.2)* (U3 R-M1): `place_attachment(staged, local_rel, sha256, policy:)` sa nahradí volaním `LibraryAttachments.place(staged, local_rel, sha256)` **pod**
  `LibraryTransfer.with_store_lock(row_for(local_rel))` (U2 R4.4; pre `textures` to po R2.1 vráti `materials.lock`). Postup `place`:
  1. `safe_local?` a `row_for` — neprejde → výnimka `ArgumentError` (U3 manifest to mal odmietnuť skôr ako `broken`; tu je to poistka).
  2. Cieľ chýba → kópia do `<cieľ>.d48-<r8>` → **SHA-256 kópie = `sha256` manifestu** (inak zmazať kópiu, `IOError`) → `File.rename` → `placed`.
  3. Cieľ existuje, SHA rovnaké → `same`.
  4. Cieľ existuje, SHA iné → podľa `POLICIES`: `:keep_local` → `kept` (pri `appearances` a `appliance_files` `conflict` + log s oboma SHA) · `:keep_valid` → validátor lokálneho súboru
     prejde → `kept`, neprejde → ako `:replace` · `:replace` → kópia `.d48-<r8>` overená SHA → `rename` cieľa na `<cieľ>.d48old-<r8>` → `rename` kópie na cieľ → `replaced` s `old`.
  5. Po kroku 2/4 overenie: finálny súbor má `sha256` manifestu (alebo je `kept`/`conflict`). „Pred `import_group!` musia byť prílohy na disku a overené odtlačkom" = tento krok.
- **R4.2 poradie v U3 R-J3** *(NAHRADENÉ §15.1)* (per skupina): (2) prílohy cez R4.1 → žurnál skupiny · (3) `import_group!` · (4) `:ok` → `commit_replaced!(žurnál)`; **iný kód** (vrátane `:failed_restored`,
  `:unhealthy_restored`, `:missing_attachments`) → `rollback_replaced!(žurnál)` — náhľady sa vrátia k JSON, ktorý U2 obnovil zo zálohy; `:failed_restore_failed` → žurnál sa **nechá**
  (súbory `.d48old-*` ostanú, `pending` ostáva — U3 R-J3) a `sweep!` ich nezmaže, kým je `pending`.
- **R4.3 výsledok skupiny** (U3 R-J4) dostane `attachments: {placed, same, kept, replaced, conflict}` (počty) — U5 ich ukáže len pri `conflict > 0` („N vzhľadov sa líši od Michalových —
  ponechané tvoje").
- **R4.4** `take_prepare` (U3 R-J1) volá na začiatku `LibraryAttachments.sweep!(now:)`.
- **R4.5 odoslanie** (U3 R-H1): do outboxu ide `required + optional` z packetu (tvar U2 sa nemení); `attachments_skipped` a `attachments_digest` z packetu prejdú do tiketu. Manifest U3 R-A5
  sa **nemení** (prílohy už nesie s `of`, `local`, `size`, `sha256`).

### R5 · Zmena len prílohy je lokálna zmena správcu (S10)

- **R5.1** `entry` (U3 R-B1) dostane kľúč `attachments_digest` (String | nil): pri **odoslaní** = `packet['attachments_digest']`; pri **prevzatí** = `digest` nad `attachments` manifestu
  prevzatej verzie (`local`, `sha256`) — teda to, čo bolo na Disku, nie lokálne `kept` obsahy.
- **R5.2** *(doplnené §15.4)* `status` (U3 R-F1) **len pri `admin_state == self`**: `local_changes` aj keď sa `group_fingerprint` zhoduje, ale aktuálny `attachments_digest` z `export_group` ≠ `entry.attachments_digest`;
  `reason` „zmenené prílohy" (napr. prefotený náhľad, dotiahnutá fotka). **Na PC bez správcu sa prílohy do lokálnych zmien nerátajú** (Lucia má vlastné staré fotky a náhľady — nesmie
  dostať falošné varovanie R4). `entry` bez `attachments_digest` (verzia odoslaná pred U4) → na správcu `local_changes` „prílohy ešte neboli odoslané" — prvé odoslanie po U4 ich doplní.
- **R5.3** Zametanie a história U3 sa nemenia; `group_fingerprint` (U3 R-A5) prílohy **naďalej neráta** (S17).

### R6 · Dokumentácia (na mieste, nie na koniec súboru)

- kniznice.md: riadok `textures/` presunúť z §3 do **§2** (prílohy, zdieľa áno, `materials.lock` · zmiešaný, popis „len odkazované fotky, R15"); **F2** prepísať na „vyriešené U4: fotky
  idú ako prílohy verzie Materiálov; chýbajúca fotka u správcu = odošle sa bez nej"; nový odsek `### library_attachments.rb` (politiky, výber, mená, žurnál, upratanie); veta v odseku
  `library_registry.rb` o `mixed` prílohách. Tabuľky stráži H16 T8.
- materials.md `### image_cache.rb`: veta „súbory v `textures/` sú od U4 zdieľané prílohy Materiálov; zápis z Demosu bez zámku, D-48 pod `materials.lock`"; model-a-identita.md / odsek
  `template_previews` (podľa rozcestníka): „pri D-48 prevzatí sa náhľad nahradí Michalovým, starý sa vráti pri neúspechu".
- ARCHITEKTURA.md rozcestník: riadok `library_attachments.rb` (guard). rozsirovacie-body.md scenár 7: „nový prílohový riadok = záznam v `LibraryAttachments::POLICIES`".
- PACKAGE_U3 sa neprepisuje (je archív zadania); zmena tvaru `entry` a `place` sa zapíše do odseku `library_sync*.rb` v kniznice.md.

## 7 · Testy a DoD

**Nové sady** (vzor `test_h16_kniznice.rb`, `test_u3b_library_sync.rb`; sandbox `Materials.test_dir_override` + `ApplianceCatalog.test_dir_override`; fake „Disk" a staging z U3):

- `tests/pure/test_u4_prilohy.rb`:
  - R0.3 charakterizácia (zelená pred aj po).
  - `POLICIES` ↔ register (každý zdieľaný prílohový riadok práve raz; mutácia: chýbajúci riadok → test padne).
  - `row_for` / `safe_local?`: platné mená všetkých štyroch druhov; `textures/0123456789_x.JPG` áno; `textures/..\x`, `textures/a b.jpg`, `textures/0123456789_x:y.jpg`,
    `template_previews/CON.png`, dĺžka 161 znakov, dočasné `.d48old-` meno → nie.
  - `refs_for`: Materiály s `appearance` `native` (súbor je → `required`; chýba → `skipped`), `color` (nič); fotka platná → `optional`, fragment bez magic → `skipped invalid`,
    chýba → `skipped missing`; dve dosky s tou istou URL → jedna cesta; šablóna s náhľadom / bez; spotrebič s listom.
  - `digest`: poradie nemení, zmena obsahu áno, `skipped` sa neráta.
  - `place`: `placed` (SHA kópie overený; podvrhnutá kópia → `IOError`, cieľ nevznikne, `.d48-*` zmazaný) · `same` · `kept` · `conflict` (appearances, appliance_files — cieľ **bajtovo bez
    zmeny**) · `:keep_valid` s neplatnou lokálnou fotkou → `replaced` · `:replace` náhľadu → `replaced` + `old` existuje.
  - `commit_replaced!` zmaže len `old`; `rollback_replaced!` vráti pôvodný obsah (SHA), `placed` ostanú; chyba pri návrate → počet `failed`, bez výnimky.
  - `sweep!`: staré `.d48*` zmazané, mladšie ostanú, pri `pending` nič; nič mimo priečinkov riadkov (súbor `cudzi.d48old-1` v koreni ostane).
  - **Nikdy nemaže finálne meno** (zdrojový guard: v `library_attachments.rb` mazanie len na cestách s `.d48`; vzor `test_h10b_rady.rb:462`).
- Rozšírenie `test_u2_transfer.rb`: `export_group('materials')` s chýbajúcim `.skm` → `:missing_attachments` s menom; s chýbajúcou fotkou → `:ok` + `attachments_skipped`; `attachments_digest`
  v packete; tvar `attachment_refs` bez zmeny.
- Rozšírenie `test_u3b_library_sync.rb` (koncový scenár „dve PC"): A má fotku a náhľad → odošle → B prevezme → B má fotku (SHA) a náhľad → A prefotí náhľad bez zmeny šablóny → A `local_changes`
  „zmenené prílohy", B `current` (nie `local_changes`) → A odošle → B prevezme → náhľad nahradený, `old` zmazaný → simulované zlyhanie `import_group!` (stub `:failed_restored`) → náhľad B
  vrátený na pôvodný (SHA) → B má vlastnú platnú fotku s iným obsahom → `kept`, súbor bez zmeny → list spotrebiča, na ktorý odkazuje snapshot, ostane aj keď ho A z katalógu zmazal.
- H16 sada (SHARED, WRITE_SITES, triedenie, tvar `mixed` prílohy), `test_h13_rozsirovacie_body.rb`, rozcestník ARCHITEKTURA (guard).

**DoD:** `ruby tests/run_all.rb` zelené · JS sady každá zvlášť (nemenia sa) · `ruby scripts/encoding_guard.rb --repo` · R0 na oboch PC v §16 · PR uvedie počty testov, výsledok R0
a skutočný diff kódu pluginu (poistka §2).

## 8 · In-SU

Nie je brána (spúšťače sa nemenia). Pohľad na fotky a náhľady v skutočných oknách po prevzatí = smoke U5 na oboch PC.

## 9 · Riziká

| # | Riziko | Dopad | Opatrenie |
|---|---|---|---|
| R1 | Prepísanie súboru, na ktorý odkazuje zákazka | zákazka neotvorí list spotrebiča | `appliance_files` a `appearances` nikdy `:replace`; finálne mená sa nikdy nemažú (guard); test so snapshotom |
| R2 | Pád medzi náhradou náhľadov a koncom `import_group!` | Luciine staré šablóny s Michalovými náhľadmi | žurnál + `rollback_replaced!`; pri `pending` sa `.d48old-*` nemažú; dopad len kozmetický (náhľad) |
| R3 | Fotka sťahovaná z Demosu bez zámku súbežne s D-48 uložením | dva zápisy toho istého mena | oba atómové `rename` platného obrázka tej istej URL; výsledok vždy platný obrázok (§12 D4) |
| R4 | Objem fotiek na Disku (história 5 × všetky fotky) a čas odoslania | pomalé odoslanie, plný Disk | fotky ≤ 3 MB (S6), skupina zdieľa jednu fotku (S3); R0 zmeria objem; stropy U3 (500 MB/verzia) |
| R5 | Falošné „lokálne zmeny" z príloh na PC bez správcu | Lucia dostane zbytočné varovanie R4 | R5.2 — prílohy sa rátajú len správcovi |
| R6 | Meno prílohy, ktoré Windows na druhom PC nevytvorí (dĺžka cesty iného používateľa, znak) | prevzatie skupiny padne | `safe_local?` u odosielateľa (R1.3, strop 160 znakov relatívne); R0 zmeria najdlhšiu cestu oboch PC |
| R7 | API U2/U3 sa pri implementácii zmení | U4 nesedí | U4 štartuje po mergi U3b; mená sa overia pri štarte; zmena = zladenie package (delta audit len pri zmene kontraktu) |
| R8 | Michal zmaže náhľad šablóny (uloženie bez náhľadu) — Lucia si starý nechá | Lucia vidí náhľad, ktorý Michal zrušil | vedome (prílohy len pribúdajú); §12 D3 |

## 10 · Smoke checklist pre Michala

U4 nemá okno — **plný smoke je v U5** (tieto body sa do neho prenesú). Od teba treba **R0 pred implementáciou** a krátku kontrolu po inštalácii:

1. **R0 (pred implementáciou, 1 minúta na PC):** na svojom PC spusti `scripts\sonda_prilohy_d48.ps1`, potom to isté na Luciinom. Súbor z `%TEMP%\noxun_sonda_prilohy\` z oboch PC pošli
   do okna. Nič sa nemení, len sa spočítajú fotky, náhľady, vzhľady a listy.
2. **Po inštalácii U4:** otvor Štúdio → **Materiály** → dlaždice s fotkami vyzerajú ako predtým; založ z Demosu jednu novú skupinu → fotka sa ukáže.
3. **Šablóny:** ulož šablónu zo skrinky → náhľad je v zozname. **Spotrebiče:** otvor list spotrebiča → otvorí sa.
4. Pre U5 (na neskôr, na oboch PC): po Aktualizovať má Lucia pri Michalových dekoroch **fotky**, pri šablónach Michalove náhľady a otvorí listy spotrebičov; jej vlastné staré fotky nezmizli.

## 11 · Checklist uzáveru

- Bump **patch** v `noxun_engine.rb` aj `main.rb` (VERSION 2×); všetky `?v=` v `ui/*.html` = VERSION (guard), hoci sa css/js nemení.
- Testy zelené (§7 DoD); R0 v §16.
- Odseky architektúry na mieste (R6) + **Grep tvrdení o zoznamoch**, ktoré dávka mení: `SHARED` a „zdieľaná množina" (kniznice.md, `test_h16_kniznice.rb`, STANDARD §13 ak menuje), riadky §2/§3 kniznice.md,
  `KINDS`/`cache` zmienky o `textures`, F2, `WRITE_SITES`, `GROUPS['materials']`, rozcestník ARCHITEKTURA.md, scenár 7.
- `SYSTEM/STAV.md` prepísať (verzia, posledný beh testov, „Robí sa" / „Ďalší krok" = U5) · KRONIKA odsek navrch „Záznamy dávok" (U4, PR, predrecenzia, audit, R0) · `SYSTEM/PLAN.md` riadok U4
  v bloku UPDATE s ✅ a číslom PR (`PR #?` → samostatný commit s číslom).
- **DOGFOODING D-48 ostáva otvorené** (uzavrie U5). Predrecenzia v PR popise.

## 12 · Rozhodnutia autora na potvrdenie orchestrátorom

- **D1 · Nie výrobná/cenová** — prílohy nevstupujú do rozmerov, počtov, hrán, kusovníka, VEPO, nákupu, kovania ani cien; dokumenty knižníc U4 nemení. Brány výrobnej dávky (export test) teda nie;
  ak orchestrátor zaradí U4 ako výrobnú kvôli zásahu do cesty prevzatia (U3b je výrobná), pridá sa export test `P == K` (lacný, U4 čísla nemení).
- **D2 · Audit-povinná** aj bez nového `STD`: mení pripnutú zdieľanú množinu (R15), riadok registra (druh, zámok), tvar `entry` U3 a pridáva nový modul.
- **D3 · Prílohy len pribúdajú aj pri náhľadoch:** Michalom zmazaný alebo premenovaný náhľad ostane u Lucie ako sirota (bez šablóny sa nezobrazí; pri rovnakom mene neskôr nahradený). Mazanie sirôt
  by vyžadovalo „zoznam zmazaných" — nenavrhujem (A4 B9, R4 bez potichu mazaných vecí).
- **D4 · `lock_mode: mixed` pre `textures`** namiesto zámku v `DemosImageCache.store` (callback sťahovania beží mimo kontroly zámkov; pridanie zámku mení správanie zakladania skupín z Demosu).
- **D5 · `children` fotiek bez zmeny** (`??????????_*`): sprísnenie na prípony by s `FNM` bez `CASEFOLD` odmietlo `.JPG`; bezpečnosť mien drží `safe_local?` (R1.3).
- **D6 · `attachments_digest` v `entry`** je obsah U3 v obálke U2 `SYNC_STD` — `SYNC_STD` sa nezvyšuje (nový voliteľný kľúč, chýbajúci = R5.2 „ešte neodoslané"). Ak audit povie, že voliteľný kľúč = zmena schémy,
  `SYNC_STD` 1 → 2 so zápisom do STANDARD §13.1.
- **D7 · Politika vzhľadov `:keep_local`** *(upravené §15.2 — konflikt povinnej prílohy zastaví skupinu)* (nie `:replace`): rovnaké UUID s iným obsahom nemá vzniknúť (S8); keď vznikne, je to poškodenie, nie Michalova zmena — ponechať a nahlásiť `conflict`.
- **D8 · Zmena len prílohy sa ráta len správcovi** (R5.2) — Lucia nemá dôvod dostať varovanie R4 za vlastné staršie fotky.
- **D9 · Fotka, ktorú správca nemá, sa neodosiela a neblokuje** (R15 „len fotky, na ktoré katalóg odkazuje" — odkazovaná, ale u správcu chýbajúca fotka sa nedá poslať); U5 povie počet.
- **D10 · `place` nahrádza politiku z U3 R-M1** (jedno miesto pravdy); U3 `place_attachment` ostane tenký obal (alebo zanikne) — rozhodne implementátor podľa zmergovaného U3, testy U3 ostanú zelené.

## 13 · Otázky pre Michala

**Žiadne** — R8, R15 a O3 pokrývajú U4 (ktoré prílohy, cez Disk, v ktorej skupine). Vedomé správanie D3/D9 sa ukáže v smoke U5; keď ho Michal bude chcieť inak, je to x.y.z.

## 14 · Nálezy mimo scope

- **N1 · Dotiahnutie chýbajúcej fotky z Demosu** (A4 A6 „doplnok"): po prevzatí, keď fotka chýba aj na Disku, môže okno Materiály zavolať `DemosImageCache.ensure(url)` na pozadí
  (`image_cache.rb:61-71`). Mimo bloku — x.y.z alebo zásobník.
- **N2 · Fotka sa nikdy neobnoví:** `local_for` vráti existujúci platný súbor a nesťahuje znova (`image_cache.rb:64-66`) — keď Demos zmení obrázok pod tou istou URL, ostáva starý. Pri D-48 to znamená
  `kept` aj pri rozdielnom obsahu (vedome).
- **N3 · `Materials.write` ignoruje `appearance` z payloadu** (U2 N3) — po U4 sa týka aj tvrdenia „vzhľad cestuje", komentár pri `materials.rb:309`.
- **N4 · Siroty príloh** (náhľady premenovaných šablón, listy zmazaných spotrebičov) rastú na oboch PC; R0 ich spočíta — upratanie by potrebovalo výslovné rozhodnutie Michala.

## 15 · Audit návrhu — zapracovanie (Codex `gpt-6-astra`, 17.10.2026; [AUDIT_U4_raw.md](AUDIT_U4_raw.md)) · MÁ PREDNOSŤ

Naviazané na PACKAGE_U2 **§15** (žurnál `library_import.pending.json`, `rollback!(backup_id)`, `recover_pending!`, `pending_block`, podmienky 15.0 „nikto iný nezapisuje"). **Druhý
mechanizmus obnovy U4 nezavádza** — náhrada prílohy je súčasť transakcie `import_group!` a jej žurnálu.

| Nález | Verdikt | Zapracovanie |
|---|---|---|
| **1 BLOCKER** obnova nepokrýva chybu ani pád počas výmeny prílohy | platný | **15.1** |
| **2 BLOCKER** konflikt povinnej prílohy dovolí prevziať katalóg s cudzím obsahom | platný | **15.2** |
| **3 FIX** `sweep!` môže zmazať skutočnú fotku `…d48-old.jpg` | platný (`image_cache.rb:36` berie basename URL bez obmedzenia) | **15.3** |
| **4 FIX** potlačenie falošných zmien skryje Luciino prefotenie náhľadu | platný | **15.4** |
| **5 NOTE** limit 160 znakov nedokazuje použiteľnosť na druhom PC | platný | **15.5** |

**15.1 Náhrada prílohy v žurnáli U2 (nález 1).** Pred `import_group!` (U3 R-J3 krok 2) sa robí **len to, čo nič neničí**: `placed` (nový súbor cez `.d48-<r8>` + overený SHA +
`rename` na voľné meno), `same`, `kept`. Každá **náhrada** existujúceho súboru (`:replace` náhľadov, `:keep_valid` s neplatnou fotkou, `:overwrite` konfliktu podľa 15.2) sa **nevykoná**:
`place` pripraví vedľa cieľa overenú kópiu `<cieľ>.d48new-<r8>` a vráti položku `{rel, new, old: "<cieľ>.d48old-<r8>", old_sha256, new_sha256}`. Zoznam ide do
`import_group!(…, replacements: [...])` — **nový voliteľný parameter U2 R4.2** (predvolene `[]`; bez neho sa správanie U2 nemení):
- **Žurnál:** položky sa zapíšu do `library_import.pending.json` pod kľúč `'attachments'` **v tom istom zápise** ako `backup_id` (U2 R4.9), teda **pred prvým premenovaním** aj pred prvým
  zápisom knižnice. Podmienky U2 15.0 (iná inštancia, otvorené okná, hlavné vlákno) platia aj pre prílohy.
- **Vykonanie** (U2 R4.2 medzi krokmi 3 a 4, pod `with_store_lock(row)` každej položky, postupne): `rename(cieľ → old)` → `rename(new → cieľ)` → SHA cieľa = `new_sha256`, inak zlyhanie
  transakcie → návrat.
- **Návrat `rollback!(backup_id)`** (U2 15.4) sa rozšíri o prílohy žurnálu, **idempotentne podľa stavu súborov** (pád medzi ľubovoľnými dvoma premenovaniami): cieľ má `old_sha256` → hotovo
  (zvyšky `new`/`old` zmazať) · `old` existuje s `old_sha256` → cieľ (ak je) premenovať na `new`, `old` → cieľ · inak → položka `failed`. **`failed > 0` = návrat zlyhal** → žurnál ostáva,
  `pending_issue` a blokovanie skupiny (U2 15.1) trvajú, `.d48old-*`/`.d48new-*` sa nemažú. Volá sa pri `:failed_restored`, `:unhealthy_restored`, zlyhaní ktorejkoľvek prílohy aj
  z `recover_pending!` po reštarte (fáza `rolling_back` platí aj pre prílohy).
- **Dokončenie pri úspechu:** žurnál prepne fázu na `committing`; každý `old` sa **presunie do zálohy tohto prevzatia** `library_backups/<backup_id>/attachments/<rel>` (U2 R4.3; `backup.json`
  dostane `attachments: {rel => sha256}`) — nič sa nemaže, pôvodný súbor ostáva dohľadateľný; rotácia 5 záloh (U2 15.5) ho odstráni spolu so zálohou. Potom zmazanie žurnálu. Pád
  v `committing` → `recover_pending!` **nevracia**, len dokončí presuny.
- Prílohy `placed` pred transakciou ostávajú aj pri neúspechu (len pribúdajú). Zvyšky `.d48-*` po páde pred transakciou zmaže `sweep!` (15.3), kým žurnál neexistuje.
- `commit_replaced!`, `rollback_replaced!` a vlastný žurnál z R1.6 **zanikajú**; `LibraryAttachments` dodá U2 idempotentné `apply_replacement!(item)`, `revert_replacement!(item)`,
  `archive_replacement!(item, backup_dir)` → `:ok | :failed`, nikdy výnimku.
- **Testy:** pád (`exit!` v podprocese) **medzi každými dvoma krokmi** — po zápise žurnálu, po `cieľ→old`, po `new→cieľ`, po 1. dokumente, počas presunu do zálohy → po `recover_pending!`
  je cieľ bajtovo pôvodný (`importing`/`rolling_back`) resp. nový s `old` v zálohe (`committing`); stub zlyhania 2. premenovania → návrat obnoví aj 1. položku; zmazaný `old` → `failed`,
  žurnál ostáva, `pending_block` hlási skupinu; dvojitý `recover_pending!` = rovnaký výsledok.

**15.2 Konflikt povinnej prílohy zastaví skupinu (nález 2).** `appearances` a `appliance_files` s **iným obsahom** pod rovnakým menom: bez rozhodnutia → skupina sa **neimportuje**
(`import_group!` sa nevolá), `entry` sa **neposúva**, súbor ostáva → výsledok `:attachment_conflict` so zoznamom (`rel`, popis záznamu) — veta U5 „Vzhľad/list … sa líši od verzie správcu —
prevzatím sa nahradí, tvoj súbor ostane v zálohe". Pri **`decisions[g] = :overwrite`** (to isté rozhodnutie ako varovanie R4) sa konflikt rieši **náhradou podľa 15.1** (pôvodný súbor do zálohy
prevzatia; snapshot zákazky ukazuje na to isté meno, teraz s obsahom správcu). Rozdielna **platná** fotka dekoru ostáva výnimkou (`kept`, bez zastavenia). `POLICIES`: `appearances`,
`appliance_files` = **`:block`** (namiesto `:keep_local`). **Testy:** konflikt bez `:overwrite` → žiadny zápis knižníc, `entry` bez zmeny, súbor bajtovo pôvodný; s `:overwrite` → obsah
správcu, pôvodný v `library_backups/<id>/attachments/`.

**15.3 Dočasné mená presnou koncovkou (nález 3).** Jediná autorita `LibraryAttachments::TEMP_RE = /\.d48(?:old|new)?-[0-9a-f]{8}\z/` (koniec mena; 8 hex = `SecureRandom.hex(4)`).
`row_for`, `sweep!`, zdrojový guard mazania aj triedenie H16 ju používajú; `transient` vzory prílohových riadkov = presné globy (`*.d48-` + 8× `[0-9a-f]`, rovnako `d48old`, `d48new`),
nie `*.d48-*`. Mazanie v `library_attachments.rb` len pre cestu spĺňajúcu `TEMP_RE` alebo súbor v priečinku zálohy. **Negatívny test:** finálna fotka `0123456789_decor.d48-old.jpg`
(aj `…_x.d48old-abc.png`) → `row_for` = `textures`, triedenie `:final`, `sweep!` ju **nezmaže** ani po 24 h; `a.png.d48old-0a1b2c3d` → dočasné. Rovnako zladiť vzory, ktoré pridáva U3 R-M3.

**15.4 Luciino prefotenie náhľadu (nález 4).** `entry` (U3 R-B1) dostane okrem `attachments_digest` (R5.1) aj **`local_replace_digest`** = `digest` (R1.5) nad **skutočnými lokálnymi bajtmi**
príloh s politikou `:replace` (`template_previews`), na ktoré ukazuje prevzatý dokument — počíta sa **po** úspešnom prevzatí (15.1) a pri odoslaní. `status` na PC **bez správcu**: aktuálny
≠ uložený → `local_changes` „zmenený náhľad šablóny" → varovanie R4 (prepísať — pôvodný do zálohy podľa 15.1 — alebo preskočiť). Fotky (`:keep_valid`) a povinné prílohy sa nerátajú —
ponechaná rozdielna fotka varovanie nevyvolá (fotku používateľ neprefotí, sťahuje sa raz — S3). `entry` bez kľúča (pred U4) → prvý `status` ho doplní bez varovania. **Testy:** B prevezme →
`current`; B prefotí náhľad bez zmeny šablóny → `local_changes`; `:overwrite` → náhľad správcu, Luciin v zálohe; B s rozdielnou platnou fotkou → `current`.

**15.5 Dĺžka ciest overená na oboch PC (nález 5).** R0 dostane **prijímacie kritérium**: skript vypíše `len(Materials.dir)` PC a pre najdlhšiu finálnu relatívnu cestu každého druhu
absolútnu dĺžku **finálnu aj dočasnú** (+16 znakov `.d48old-xxxxxxxx`) a **zápisom overí** (vytvorenie, `rename`, zmazanie) cestu rovnakej absolútnej dĺžky v `%TEMP%\noxun_sonda_prilohy\`
(standalone Ruby 3.2; zhoda s Ruby SketchUpu 2026 NEOVERENÁ — pri neistote tá istá sonda raz cez `execute_ruby` v testovacom okne). Limit R1.3 = `min(160, 259 − 17 − max(len(Materials.dir)
oboch PC))`, zapíše sa do §16. Dovtedy je prenositeľnosť mien **podmienená** (package nezmrazený).

**15.6 Dopad na rozsah.** Kód pluginu +~60 (prílohy v žurnáli, `rollback!` a `recover_pending!` U2, `:block`, `local_replace_digest`) → **~360**; poistka §2 (400) platí. U4 teraz mení aj
**transakciu U2** → odporúčaný **delta audit len na 15.1** (rozhodne orchestrátor); predrecenzia dostane aj PACKAGE_U2 §15. Trieda a brány (§5) bez zmeny.

## 16 · Výsledok inventára R0

*(doplní sa po behu `scripts\sonda_prilohy_d48.ps1` na oboch PC; dovtedy package nie je zmrazený — rozhodnutie „migrácia netreba" je predbežné podľa S18)*
