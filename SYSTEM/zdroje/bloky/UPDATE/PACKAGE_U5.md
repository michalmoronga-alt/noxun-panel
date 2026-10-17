# PACKAGE U5 · Okno O plugine, oznámenie a ikona aktualizácie (D-48) — blok UPDATE

> **Stav: NÁVRH — čaká audit návrhu (`codex-audit`)** · 17.10.2026 · do zásoby, **implementácia až po smoke PASS bloku 9 HARDENING** a po mergi U2, U3 a U4
> (poradie RECONCILE §3: U2 → U3 → U4 → U5; A2 B6: okno až po prílohách).
> **Autorita:** [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) — R3–R7, R13, R14, R16–R19, R21 a mockup **O1–O9** (záväzné) ·
> [MOCKUP_UPDATE_KNIZNICA.html](MOCKUP_UPDATE_KNIZNICA.html) (schválený bez úprav + rámik O9) · smer [RECONCILE_2026-10-17.md](RECONCILE_2026-10-17.md) §2 riadky „U5", §3 ·
> API **presne podľa** [PACKAGE_U2.md](PACKAGE_U2.md) R4.8 a [PACKAGE_U3.md](PACKAGE_U3.md) R-C, R-E, R-F, R-H, R-J, R-K, R-L, R-N · dôkazy
> [CROSS_AUDIT_A4_CLAUDE_KOD.md](CROSS_AUDIT_A4_CLAUDE_KOD.md) B4, B5, B6, B8, B11 · [CROSS_AUDIT_A2_GROK.md](CROSS_AUDIT_A2_GROK.md) B6 · A3 FIX 5 · [PACKAGE_U4.md](PACKAGE_U4.md) R3.2, R4.3 (len texty výsledkov — §6 R-N).
> **§15 (audit návrhu + zladenie s U2/U3/U4 §15; delta audit 17.10. = §15.1) MÁ PREDNOSŤ** pred textom vyššie, kde sa líšia. **Trieda Ť** (nové moduly + > 300 riadkov; výrobná/cenová — §5) · **rez U5a → U5b** (§2) · `codex-audit` · predrecenzia · export test P == K · ui_foto · smoke na oboch PC.
> **Stav kódu:** sonda nad `docs/update-start` `1468dfe2` (kód = `main` `a9e8c79d`, v0.18.1). U2–U4 v kóde ešte nie sú; riadky nižšie platia k tejto hlave.

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 17.10.2026, len čítanie

Cesty relatívne k `noxun_engine/`.

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | „Okná knižníc" (O6) sú **sekcie Štúdia** `mat`, `hw`, `appl`, `rules`, `tpl`, `bset`; okná sú len Inspector, Štúdio, Z-dialog (guard) | `ui/js/studio_sections.js:80-116`; `HtmlDialog.new` len `ui/panel.rb:94`, `ui/studio_dialog.rb:1372`, `tools/mower.rb:409` | PRAVDA → pruh = riadok v sekcii, bariéra = zatvoriť 3 okná |
| S2 | Sekcia `about` = riadok registra s háčikom `enter: 'ssOnAboutEnter'`, kreslí ju `studio_settings.js`, markup `about.js` (`nxAboutHtml(info, updater)` — updater len v Štúdiu) | `studio_sections.js:117-121`; `ui/js/about.js:78-118`; `studio_settings.js:392`, `:504` | PRAVDA |
| S3 | Riadok registra má mechanizmus **badge** pri položke navigácie (`badge` → `navCounts` → `navBadgeHtml`) a **kotvu deep-linku** (`anchor: {fn, phase, miss}`) | `studio_sections.js:16-32`; `ui/js/studio.js:595-608`, `:1249` | PRAVDA → ikona O9 = nový druh badge `upd`; kotva `library` |
| S4 | Server sekcie `about` = `SupplierSettingsDialog`; akcie len z uzavretého whitelistu `SECTION_ACTIONS`; Štúdio ich zapája blokom per modul | `ui/supplier_settings_dialog.rb:50`, `:89-107`; `ui/studio_dialog.rb:1217` (vzor ďalších modulov `:731`, `:960`, `:1056`, `:1107`, `:1142`) | PRAVDA → nový modul `LibrarySyncDialog` so svojím whitelistom a blokom zapojenia |
| S5 | Payload `about` sa skladá pri **každom** pushi Štúdia a zámerne nesiaha na sieť/Disk (kontrola verzie je explicitná akcia) | `supplier_settings_dialog.rb:215-230` | PRAVDA → stav knižnice tiež len explicitnou akciou (sken vo vlákne), do payloadu ide len posledný doručený výsledok |
| S6 | Async vzor: vlákno len I/O, poll 0,2 s, deadline 4 s, token (cesta, `instance_token`, sekvencia), vlákno sa nezabíja, seamy `test_*` | `supplier_settings_dialog.rb:57-58`, `:85`, `:354-463`, `:748-765` | PRAVDA → `TimedWorker` U3 R-E2 + seamy |
| S7 | Bariéra: `close_plugin_dialogs` → poll `dialogs_closed?` (dobehnutý `set_on_closed`) → limit 3 s → akcia; výsledok natívne | `supplier_settings_dialog.rb:330-332`, `:548-589`, `:739-745`; `ui/panel.rb:67-69` | PRAVDA → vzor pre prevzatie (A4 B6) |
| S8 | Počas behu updatera sa okná neotvárajú (`Engine.update_in_progress?` vo vstupoch) | ui-lifecycle.md odsek `updater.rb`, „Bariéra pred swapom" | PRAVDA → rozšíriť o beh prevzatia (R-B5) |
| S9 | `StudioDialog.show(open_section:, anchor:)` existuje; Inspector ho volá cez `openStudio(section, anchor)` → callback `open_studio` | `studio_dialog.rb:136-143`; `ui/js/actions.js:11-17`; `ui/panel.rb:264`, `:328` | PRAVDA → klik z railu = `openStudio('about','library')` |
| S10 | Rail Inspectora: funkčná sekcia končí ikonou `eye` (Viditeľnosť tagov, `#railTagyBox`), pod ňou `railgap` + koliesko + Štúdio; bublina `.railtip`, nie `title` | `ui/panel.html:71-78`; UI_DIZAJN §5.1, §5.13 | PRAVDA → nové tlačidlo `#railUpd` hneď za `#railTagyBox` |
| S11 | Server → Inspector ide pushom `js("… NX.setX(...)")` (vzor `push_tags`, `push_grain_check`) | `ui/panel/sync.rb:168-172`, `:190` | PRAVDA |
| S12 | `UI::Notification` už plugin používa (referencia v `@note` kvôli GC, `Engine.extension`) | `tools/tools.rb:179-188` | PRAVDA → vzor pre O4 |
| S13 | Init pluginu (menu, toolbar, `Tools.install!`) beží v `main.rb` pod `init_allowed?` | `main.rb:605-614`, `:690-716` | PRAVDA → háčik kontroly pri štarte za `Tools.install!` |
| S14 | `Materials.used_material_ids(model)` = Hash `id => [kde]`, prechádza **aktívny model aj globálne šablóny** | `core/materials_catalog.rb:488-500` | PRAVDA → `used_ids` pre `materials` (A4 B5) |
| S15 | Spotrebiče v rozpočte zákazky číta `BudgetStore.appliances(model)` (`read_json` + `normalize_appliance`), položka nesie `catalog_id` | `core/budget_store.rb:248-250`, `:506-507` | PRAVDA → R-D2 |
| S16 | Sprite má `cloud-download`, `download`, `refresh-cw`, `rotate-ccw`, `more-horizontal`, `alert`, `info`; nemá `cloud-upload`, `user`, `clock`; inventár strážený, nová ikona len s novým významom | `ui/js/icons.js`; UI_DIZAJN §4; `tests/pure/test_docs_navigacia.rb` | PRAVDA → R-I |
| S18 | D-15 `NXModal` má typ `custom` (vlastný uzol volajúceho v karte), `danger`, `busyLock`, modal bez polí = fokus na potvrdenie | `ui/js/nx_modal.js:17-21`, `:125`; UI_DIZAJN §5.12 | PRAVDA → modaly U5 sú D-15 s `custom` |
| S19 | `?v=` v `ui/*.html` = VERSION (guard) | UI_DIZAJN §6; `tests/pure/test_guards.rb` | PRAVDA |
| S20 | Hranica UI updatera: „**žiadny auto-check na pozadí**" | ui-lifecycle.md odsek `updater.rb`, „Hranice" | PRAVDA → R21 ju vedome mení (kontrola pri štarte, R-G) — prepísať odsek |

---

## 1 · Cieľ (funkčne)

Michal a Lucia uvidia zdieľanú knižnicu **v Štúdiu → O plugine** (pod aktualizáciou pluginu, O1): box **Zdieľaná knižnica** s riadkom Disku, správcom,
posledným odoslaním a **5 riadkami skupín** (Materiály · Kovanie · Šablóny · Dodávateľ a sadzby · Spotrebiče — O3) so stavom. Správca (Michal) má **Odoslať zmeny (N)**
s nepovinnou poznámkou (O8); obaja **Aktualizovať** — pred prepisom okno R4 povie, čo sa zmení, čo zmizne a **čo používa otvorená zákazka**, že sa zmenia ceny (R17),
a pri vlastných zmenách dá voľbu **prepísať (so zálohou) / tento katalóg preskočiť**. V „⋯": **História a návrat…** (5 verzií, „Vrátiť" len správca, „Vrátiť zálohu"
na každom PC) a raz **„Toto PC je správca knižnice…"** (O2). Pri štarte SketchUpu **oznámenie** (O4), keď je na Disku čo prevziať, a **ikona stiahnutia** pri „O plugine"
v navigácii Štúdia a v lište Inspectora pod okom (O9) — **aj pre novú verziu pluginu** (R21). Na Luciinom PC jantárový **pruh** v sekciách knižníc (O6/R13).

**Príklad:** Lucia ráno → oznámenie „Na Disku sú novšie knižnice: Materiály, Kovanie" → Aktualizovať → okno: „− Lucia biela 18 — **zmizne, používa ju otvorená
zákazka**" · „Zmenia sa ceny…" → „Materiály zatiaľ preskočiť" → okná sa na chvíľu zavrú, prevezme sa Kovanie, hláška a Štúdio sa znova otvorí na O plugine.

## 2 · Rez a odhad

| Časť | Obsah | Kód pluginu (odhad) | Testy | Odhad |
|---|---|---|---|---|
| **U5a · box a akcie** | `ui/library_sync_dialog.rb` (server boxu: sken, stav, Odoslať, príprava + potvrdenie Aktualizovať, bariéra, Vrátiť zálohu, správca, O7) · `about.js` box + `studio_settings.js` modaly Odoslať / Aktualizovať (R4) / Správca / Zálohy · CSS · zapojenie v `studio_dialog.rb` · vstupy okien počas behu | ~620 (Ruby ~330, JS ~240, CSS ~50) | ~550 | 2 dni |
| **U5b · oznámenia a história** | História a Vrátiť verziu (správca) · `ui/update_notice.rb` (kontrola pri štarte: knižnica + plugin R21, `UI::Notification` O4, stav ikony) · badge `upd` v navigácii · `#railUpd` v Inspectore · pruh O6 v 6 sekciách | ~430 (Ruby ~170, JS ~200, CSS/HTML ~60) | ~400 | 1½ dňa |

Spolu ~1050 riadkov → nad ~600 → **delenie U5a / U5b** (brief). Jeden audit návrhu pre obe; každá vlastný PR z čerstvého `main`. U5a sama o sebe dáva Michalovi
a Lucii úplnú funkciu (Odoslať, Aktualizovať s R4, záloha a jej vrátenie); U5b pridá upozornenia, históriu a pruh. **Poistka:** U5a nad ~700 riadkov kódu pluginu →
implementátor zastaví a hlási (kandidát na presun: modal Zálohy do U5b, U5a ponúkne „Vrátiť zálohu" len v hláške `:failed_restore_failed`).

**Poradie commitov U5a:** (1) R0 charakterizácia · (2) server `LibrarySyncDialog` + zapojenie + headless testy · (3) box v `about.js` + JS stav · (4) modaly · (5) bariéra
a vstupy · (6) docs. **U5b:** (1) R0b · (2) `UpdateNotice` + háčik v `main.rb` · (3) badge + rail · (4) História · (5) pruh · (6) docs.

## 3 · Scope IN

R0 charakterizácia · R-A box a payload · R-B server, akcie a bariéra · R-C Aktualizovať a okno R4 · R-D použité záznamy otvorenej zákazky · R-E Odoslať (O8) ·
R-F správca a „⋯" (O2) · R-G kontrola pri štarte a oznámenie (O4, R21) · R-H ikona stiahnutia (O9) · R-I ikony a texty · R-J História, Vrátiť, zálohy (O5) ·
R-K pruh v sekciách (O6/R13) · R-L iná verzia pluginu (O7, R14, R18) · R-N texty výsledkov príloh (U4) · R-M dokumentácia.

## 4 · Scope OUT

Logika synchronizácie, Disk, manifest, správca na Disku, stavy skupín, diff (**U3** — U5 ich len zobrazuje) · prevzatie, zálohy, návrat, druhá inštancia, UNI, reset
stavu v pamäti (**U2**) · prílohy a fotky dekorov (**U4**) · názov zákazky v .skp (**U1**) · **„Odovzdať správcu…"** (O2 „neskôr" — položka sa **nekreslí**, UI_DIZAJN §5.15
„ovládač, ktorý by visel neaktívne celý blok, sa skryje") · zmena cesty koreňa v UI (U3 D9) · export lokálnych zmien Lucie správcovi (A4 B4 „neskôr") ·
zmrazenie rozpočtu zákazky (R17 mimo bloku) · párovanie seed spotrebičov (R16) · zmena D-52b aplikovania pluginu (ostáva, R-G len pridáva kontrolu pri štarte) ·
zmena čítacej sekcie Pravidlá na editovateľnú (pruh áno, obsah bez zmeny — §12 D7).

## 5 · Trieda a brány

- **Trieda Ť:** nové moduly (`ui/library_sync_dialog.rb`, `ui/update_notice.rb`) + > 300 riadkov → profil `implementator`.
- **`codex-audit` povinný** (nový modul). Jeden audit pre U5a + U5b, úzko (R12): tento package + PACKAGE_U2 R4.2–R4.8, PACKAGE_U3 R-C, R-E, R-F, R-H, R-J–R-N,
  `supplier_settings_dialog.rb:330-463, :548-589, :739-776`, `studio_sections.js`, `about.js`, `panel.html:60-80`, `tools/tools.rb:179-188`. Sonda §0 = krok 0.
- **Výrobná/cenová: ÁNO** (§12 D1) — nový ovládač „Aktualizovať"/„Vrátiť" prepisuje katalógy s cenami a rozmermi (CLAUDE.md: „nový ovládací prvok… zapisuje katalóg";
  čísla, podľa ktorých sa cenotvorí). Brány výrobnej dávky celé: predrecenzia, **export test `P == K`** (bez kliku na Aktualizovať sa exporty nesmú líšiť).
- **Predrecenzia povinná** (výrobná + nové ovládacie prvky) pre U5a aj U5b.
- **In-SU:** spúšťače (buildery, observery, undo, geometria, akcie panela **zapisujúce do modelu**) sa **nemenia** — Aktualizovať zapisuje do `%APPDATA%`, nie do .skp,
  a operáciu SketchUpu neotvára → **nie je brána**. Bariéru zatvorenia okien headless neoverí → **odporúčaný** in-SU scenár R-B4 (§8), PR uvedie hlavu behu.
- **Fotky okien (`ui_foto`):** povinné — mení sa **tvar payloadu z Ruby** (`about.library`, `upd`) → `-Record` a hneď fotiť; v PR kontaktný hárok (O plugine, Materiály
  s pruhom, Inspector bez výberu). Modaly sú mimo dosahu foto (statický stav) → smoke.
- **Smoke na oboch PC** (R10) — §10; bez neho sa blok neuzatvára.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit každej časti, plugin bez zmeny)

- **R0.1** JS: `nxAboutHtml(info)` bez druhého argumentu (koliesko Inspectora) a s updaterom — snapshot markupu do `tests/js/test_u5_about.js`; po U5 **bajtovo
  rovnaký** pre koliesko (box knižnice sa tam nekreslí — R-A5) a updater časť bez zmeny.
- **R0.2** Ruby: `SupplierSettingsDialog::SECTION_ACTIONS`, `about_info` a `close_plugin_dialogs`/`dialogs_closed?` pripnúť testom (U5 ich nemení — R-B3 volá ich ekvivalent).
- **R0.3 (U5b)** snapshot navigácie Štúdia (`navitem` HTML pri `about`) a railu Inspectora (`panel.html` riadky 71-78) — po U5b sa zmení **len** pridaný prvok.

### R-A · Box „Zdieľaná knižnica" a payload (O1, O3, R6)

- **R-A1 umiestnenie:** v sekcii `about` pod blokom updatera; builder `nxLibraryHtml(lib)` v `about.js`, kreslí ho `nxAboutHtml(info, updater, library)` **len pri treťom
  argumente** (Štúdio). Hostiteľ s `id="aboutLib"` = kotva deep-linku `library` (R-H3).
- **R-A2 hlavička boxu:** nadpis „Zdieľaná knižnica" · vpravo ikonové tlačidlo **Obnoviť stav knižnice** (`refresh-cw`, `aria-label` + `title`) · **„⋯"** (`more-horizontal`;
  bez položiek sa nekreslí — §1). Riadky `.inforow` (text, nie polia): **Disk** (cesta koreňa + stav slovom), **Správca** (meno PC + „(toto PC)" / „nikto" / veta konfliktu),
  **Posledné odoslanie** (dátum, čas, poznámka v úvodzovkách; na PC bez správcu aj „z <PC>").
- **R-A3 tabuľka** (`table.libtbl`, vlastná trieda — UI_DIZAJN §5.15, žiadna zdieľaná flex trieda na `<tr>`): stĺpce **Katalóg · Na Disku · U mňa · Stav**; 5 riadkov v poradí
  `LibraryRegistry.groups` (U2 R1.2). „Na Disku" = `verzia · dátum`, „U mňa" = `local_version` + „ · upravená" pri lokálnych zmenách. **Stav = chip** podľa `state` z U3 R-F1:

  `current` → `ok` „aktuálne" · `newer` → `new` „novšia na Disku" · `local_changes` → `loc` „neodoslané zmeny" (správca) / „vlastné zmeny" (ostatní) ·
  `newer_and_local` → `new` + `loc` · `never_taken` → `new` „ešte neprevzaté" · `not_on_disk` → `loc` (správca) / `wait` „na Disku ešte nie je" · `syncing` → `wait`
  „na Disku sa ešte synchronizuje" · `broken` → `err` „verzia na Disku je poškodená" · `plugin_newer_on_disk`/`plugin_older_on_disk` → `err` „iná verzia pluginu" (R-L) ·
  `pending` → `err` „prevzatie sa prerušilo" · `blocked` → `err` „zablokované po prerušenom prevzatí" · `disk_behind` → `wait` „Disk ešte dobieha" · `unknown` → `wait`
  „stav sa overí pri akcii" · `foreign_publisher` → `err` „verzia od iného PC" · `head_conflict` → `err` „dve verzie s rovnakým číslom".
  Chip `new` je výberová rodina (teal), `loc` jantár (`--nx-warn-bg-soft` / `--nx-warnchip-fg` / `--nx-warnchip-border`), `err` stavové `--nx-err-*`, `wait` `--nx-surface-sunken`.
  **Žiadny nový token** (§1 „Žiadna vizuálna zmena bez zámeru").
- **R-A4 akcie pod tabuľkou:** **Odoslať zmeny (N)** (`primary`, ikona `cloud-upload`, len správca — R-E) · **Aktualizovať** (`ghostbtn`, `cloud-download`) · vpravo stavová
  veta `#libNote` (napr. „Aktualizovať netreba — na Disku nie je nič novšie." / „Odosiela len správca (MICHAL-PC)."). Nedostupné tlačidlo = `aria-disabled` + `title`
  s dôvodom (D-78), **nikdy** `disabled`; klik pri `aria-disabled` napíše dôvod do `#libNote` a nič neodošle (§1).
- **R-A5 koliesko Inspectora box nekreslí** (Š19 „jeden obsah, dva vstupy" platí pre logo/verziu; tlačidlá zapisujú → len Štúdio, rovnaký dôvod ako updater). Odsek `about.js`.
- **R-A6 payload:** `about_info` dostane kľúč `library` = **posledný doručený** výsledok skenu (`LibrarySyncDialog.last_payload`), nikdy nový sken (S5). Tvar:
  `{ 'state' => 'idle'|'checking'|'ready'|'busy', 'busy_op' => nil|'send'|'take'|'revert'|'restore'|'claim', 'disk' => U3 R-E1, 'disk_text', 'root',
  'admin' => {'state' => U3 R-C2, 'pc_name', 'self' => bool, 'candidates', 'activate_after'}, 'last' => {'at','note','by_pc'}|nil, 'plugin' => {'current','disk','import_allowed','export_allowed','reason'},
  'groups' => [{'key','label','state','disk_version','disk_at','note','local_version','local_changed' => bool,'can_send','can_take','reason'}],
  'send_count', 'can_send', 'can_take', 'send_reason', 'take_reason', 'foreign' => [mená], 'checked_at' }`. Texty chipov a viet skladá **klient** z kódov
  (vzor `nxUpdaterText`); vety výsledkov U2 R4.7 skladá **server** (prenáša bez úprav — U2 R4.7).

### R-B · Server boxu `Noxun::Engine::LibrarySyncDialog` (`ui/library_sync_dialog.rb`) a bariéra

- **R-B1 whitelist** `SECTION_ACTIONS = %w[lib_scan lib_send lib_take_prepare lib_take_commit lib_take_cancel lib_backups lib_backup_preview lib_backup_restore
  lib_claim_admin lib_resolve_admin lib_history lib_revert_prepare lib_revert]` (posledné tri U5b); zapojenie v `studio_dialog.rb` blokom vzoru `:1217`; `dispatch`/`with_client`/`js`/`set_status` **vzor S4** (vlastný sink,
  `ensure`). Volania mimo whitelistu → „Neznáma akcia knižnice."
- **R-B2 sken (`lib_scan`)**: volá ho háčik vstupu `ssOnAboutEnter` (spolu s `updater_check`), tlačidlo Obnoviť a dobeh každej akcie. Vo vlákne **len** `LibrarySync`
  sken z U3 (R-D1/R-F2 cez `TimedWorker.start('lib_scan:<root>')`, single-flight), poll `UI.start_timer` 0,2 s, deadline 4 s (U3 R-E3) → po `:done` na hlavnom vlákne
  `LibrarySync.status(scan, local:)` (U3 R-F1; `local` z `LibraryTransfer.peek_group` — **bez bariéry**; `export_group` sa v skene nevolá, U2 §15.0) → `last_payload` → `push_library` (`js("SS.library(<json>)")`).
  `:timeout` → `disk: 'timeout'`, veta „Disk neodpovedal do 4 s — je pripojený?". **Token** (root, `StudioDialog.instance_token`, sekvencia) — neskorá/cudzia odpoveď
  sa zahodí (vzor S6). Seamy `test_clock/test_spawn/test_schedule/test_notify` (vzor S6).
- **R-B3 bariéra (A4 B6, U2 §15.0)** pre každú akciu, ktorá **zapisuje alebo exportuje knižnice** (`lib_take_commit`, `lib_backup_restore`, `lib_revert`, **`lib_send`** — `export_group`
  vyžaduje zatvorené okná; pred zatvorením okien **R-B7**): `@lib_inflight = op` → zapamätať, ktoré okná
  boli otvorené → `close_plugin_dialogs` (Panel, Štúdio, Z-dialog — vzor S7) → poll `dialogs_closed?` (limit `LIB_BARRIER_S = 3.0`; po ňom zrušenie „Aktualizácia sa
  nespustila — okná pluginu sa nepodarilo zavrieť… Na disku sa nič nezmenilo.") → operácia U3/U2 **na hlavnom vlákne** → výsledok **natívne** (`UI.messagebox`,
  seam `test_notify`) → **znova otvoriť** okná, ktoré boli otvorené (Štúdio `show(open_section: 'about', anchor: 'library')`, Inspector `Panel.show`) → `lib_scan`.
  Dôvod zatvorenia: rozpísané hodnoty a revízie v JS sekcií (`save_library!`/`row_rev`, `SS` baseline) by po prevzatí uložili starý obsah (U2 §9 R9); zatvorené okno
  sa otvorí z čerstvých dát po `after_import!` (U2 R4.2 krok 6). **Spoločné primitívum:** `close_plugin_dialogs`/`dialogs_closed?` sa presunú zo `SupplierSettingsDialog`
  do `Engine.close_plugin_dialogs!`/`Engine.plugin_dialogs_closed?` (`main.rb` alebo `app_lifecycle.rb`) a updater ich volá odtiaľ — **bez zmeny správania** (R0.2, guard D-52b
  text — §12 D3).
- **R-B4 vstupy počas behu:** `Engine.update_in_progress?` vráti `true` aj pri `LibrarySyncDialog.barrier_active?` (fáza zatvorených okien; pri Odoslať končí po `publish_prepare`) (jedna podmienka pre toolbar, `Panel.show`, `Panel.show_insert`,
  `StudioDialog.show`, menu) s hláškou „Prebieha aktualizácia knižnice — okná sa otvoria samy." Príznak uvoľňuje jediné miesto `lib_done!` (vzor `updater_done!`),
  ktoré aj znova otvorí okná (R-B3). Opätovné otvorenie z `lib_done!` ide **mimo** tejto brány (príznak sa zhodí pred `show`).
- **R-B5 single-flight a zámok:** druhá akcia počas `@lib_inflight` → „Iná akcia knižnice práve beží." bez zásahu. Medziprocesový zámok drží U3 (`library_sync.lock`,
  `:busy` R-B2 U3) — veta prenesená bez úprav.
- **R-B6 hlavné vlákno:** `LibraryTransfer.*`, `LibrarySync.status/diff/take_commit/publish_prepare/publish_finish/claim_admin!` a všetky `Sketchup.*`/`UI.*` **len**
  na hlavnom vlákne, zápisové kroky synchrónne bez `UI.start_timer` medzi nimi (U2 §15.0 c); vo vláknach len telá z U3 (`Remote.*`, `take_prepare`, `publish_run`, precheck U3 R-G2)
  — guard nad zdrojom (vzor U3 R-E4).
- **R-B7 utíšenie rozbehnutých akcií (audit 2).** Zatvorené okno nestačí — pred prvým zápisom: **(a)** `PriceRefresh.running?` → zrušenie s vetou „Beží prepočet cien — počkaj, kým
  dobehne" (okná sa nezatvárajú); **(b)** bežiace Demos behy → `MaterialsDialog.cancel_demos_on_leave` (`ui/materials_dialog.rb:179-188`; `demos_bump_session` zneplatní neskoré emity);
  **(c)** **epocha knižníc** `Engine.library_epoch` sa zdvihne pri vstupe do bariéry; každý asynchrónny zapisovateľ knižníc si ju odloží pri štarte a pred zápisom porovná — inak zápis
  zahodí s logom. Inventár zapisovateľov (`UI.start_timer`/vlákno + zápis store-u; kandidáti `ui/materials_dialog.rb`, `core/demos/*.rb`, `core/hardware_catalog.rb`, `price_refresh.rb`)
  urobí implementátor Grepom do `LibrarySyncDialog::QUIESCE` (súbor → zrušenie); **guard:** každý súbor so `start_timer`, ktorý volá zápis store-u knižnice, je v zozname;
  **(d)** neskoré odpovede do Štúdia zahodí nový `StudioDialog.instance_token` a revízie sekcií (`row_rev`, `revision`) z čerstvého payloadu. **Test:** odložený Demos emit a odložený
  zápis ceny so starou epochou po prevzatí aj po znovuotvorení okien **nič nezapíšu** a nenaplnia nové okno.

### R-C · Aktualizovať a okno R4 (R4, R6, R16, R17, A4 B5/B8)

- **R-C1 klik** (len keď `can_take`): modal **„Aktualizovať knižnicu z Disku"** (D-15, `size: 'md'`, `busyLock: true`) otvorený hneď vo fáze „Pripravujem verziu z Disku…"
  (potvrdenie `aria-disabled`) → server `lib_take_prepare` → `LibrarySync.take_prepare(groups:)` vo vlákne (U3 R-J1; deadline 120 s, poll 0,25 s) — `groups` = skupiny
  so stavom `newer`, `newer_and_local`, `never_taken` (nie `pending`/`blocked` — R-C7) → na hlavnom vlákne per skupina `LibrarySync.diff(g, ticket, used_ids:)` (U3 R-N1; `used_ids` R-D;
  výsledok `'documents' => :unknown` → vetva R-C2 „neznámy diff") → `SS.libTake(plan)`.
- **R-C2 plán** `{ 'ticket_id', 'groups' => [{'key','label','version','at','note','local_changed','state' (syncing/broken → len informácia, neprevezme sa),'diff' =>
  {entry_key => {added:[{id,label}], changed:[{id,label,fields}], removed:[{id,label,used,where}]}} | 'unknown', 'price_changed' => bool, 'attachment_conflicts' => [{rel,label}],
  'used_unknown' => [entry_key], 'dependents' => [labels]}] }` (zladené s U3 R-N1, §15.1). `used` v JSON = `true` · `false` · `null` (zámerne neoverované) · `"unknown"` (R-D3).
  **Vetva neznámeho diffu** (`'diff' => 'unknown'` z U3 `'documents' => :unknown`): v okne namiesto zoznamu jantárová veta „Nepodarilo sa porovnať s tvojou knižnicou — prevzatím sa prepíše
  celá a zmiznuté záznamy sa nedajú vypísať", veta R17 sa ukáže (`price_changed` true) a skupina sa správa ako **s lokálnymi zmenami**: voľba R-C4, predvolené preskočiť (U3 R-J2 ju bez `:overwrite`
  neprevezme). Tiket drží server
  (`@lib_ticket = {id, ticket, dlg, model_guid, used_sha, seen}`, `seen = {g => seen_fingerprint z diffu}`); klient posiela späť len `ticket_id` a per skupina `{action}`; server zloží
  **jediný tvar rozhodnutí U3 R-J2** `decisions = {g => {action: :take | :overwrite | :skip, seen_fingerprint: seen[g]}}` (klient `seen_fingerprint` neposiela ani nemení). **Väzba na zákazku (audit 3):**
  pri potvrdení server znova zistí `Panel.model_guid` aktívneho modelu (`ui/panel/sync.rb:325`) a SHA `used_ids` — nezhoda → nič sa nezapisuje, plán sa **zostaví znova** nad tým istým
  tiketom a okno povie „Otvorená zákazka sa medzitým zmenila — prehľad je obnovený, skontroluj a potvrď znova".
- **R-C2b konflikt povinnej prílohy (U4 §15.2):** `diff` skupiny nesie `attachment_conflicts: [{rel, label}]` (§12 D14) → riadok „Vzhľad/list <label> sa líši od verzie správcu —
  prevzatím sa nahradí, tvoj súbor ostane v zálohe" a skupina dostane voľbu R-C4 ako pri lokálnych zmenách (bez `:overwrite` vráti U3 výsledok skupiny `attachment_conflict`).
- **R-C3 telo okna** (`custom`, poradie podľa mockupu): veta „Na Disku sú novšie: Materiály (verzia 14 z 16.10. 18:42) a Kovanie (verzia 9)." + poznámka odoslania (O8)
  pod menom skupiny · pri skupine s lokálnymi zmenami jantárová veta (`--nx-modalwarn-fg`) „V Materiáloch máš vlastné zmeny, ktoré na Disku nie sú. Prevzatím sa prepíšu."
  · **„Čo sa zmení v <skupina>"**: „+ N nové (prvé 3 mená, …)" · „~ N zmenená cena" / „~ N zmenené" · **„− <meno> — zmizne"**; zmiznutý záznam s `used` = červený
  tučný riadok s dovetkom „**používa ho otvorená zákazka**" (+ kde, ak `used_ids` nesie miesto) — **vždy vypísaný celý**, nezbalený (A4 B5: nič sa nemaže bez zoznamu).
  Zoznam dlhší ako 8 riadkov per skupina sa zbalí na „… a ďalších N" **okrem** riadkov s `used`. · **Veta R17** (keď niektorá skupina `price_changed`): „Zmenia sa ceny
  v <skupiny> — najbližší rozpočet pôjde podľa nového cenníka." · prvé pripojenie (`never_taken`, R16): „Tvoja knižnica sa nahradí Michalovou; doterajšia ostane ako záloha."
- **R-C4 voľba per skupina s lokálnymi zmenami** (segmentový prepínač `.segrow` — §1 „jedna voľba z N", nie rádiá): **„Prepísať — moja verzia sa uloží ako záloha
  (dá sa vrátiť v História)"** (`:overwrite`) / **„<Skupina> zatiaľ preskočiť — pošli zmeny správcovi"** (`:skip`). **Predvolená = preskočiť** (vedomá odchýlka od mockupu — §12 D4).
  Skupina bez lokálnych zmien = `:take` bez voľby. Preskočenie skupiny, od ktorej iná prevzatá závisí (`LibraryRegistry.dependents`, U2 R1.3) → jantárová veta
  „Šablóny odkazujú na Materiály — kým Materiály preskočíš, niektoré šablóny môžu ukazovať na záznamy, ktoré u teba nie sú." (A4 B8; varovanie, nie blokovanie — U2 R4.2).
- **R-C5 potvrdenie** „Aktualizovať" (`primary`; pri všetkých `:skip` `aria-disabled` „Nie je čo prevziať") → `lib_take_commit {ticket_id, actions: {g => 'take'|'overwrite'|'skip'}}` → server zloží `decisions` (R-C2, tvar U3 R-J2) → bariéra R-B3 →
  `LibrarySync.take_commit(ticket, decisions:, plugins_dir: Engine.plugin_dir)` (U3 R-J2) → natívna hláška: riadok per skupina z R-J4 (`taken` „prevzaté (verzia N)",
  `skipped` „preskočené", `skipped_changed` „preskočené — medzitým si ich zmenila", `syncing`, `broken`, `plugin_mismatch`, kódy U2 vetou U2) + pri
  `:failed_restore_failed` veta „Otvor O plugine → ⋯ → Zálohy a vráť zálohu <dátum>." + pri `:other_instance*` „Zavri ostatné okná SketchUpu a skús znova." + `stale_ticket`
  „Na Disku je medzitým novšia verzia — klikni Aktualizovať znova" + `attachment_conflict` (U3 R-J4, veta R-N) + `:dialogs_open`/`:busy_snapshot` (U2) vetou U2. Výsledok s `'refresh'` → Štúdio sa
  otvára z čerstvého `push_state` (R-B3).
- **R-C6 zrušenie** (Zrušiť, Esc, krížik vo fáze plánu) → `lib_take_cancel` → U3 staging sa zahodí (`take_prepare` tiket; upratanie U3 R-J4). Vo fáze prípravy je okno
  zamknuté (`busyLock`) do odpovede servera v **každej** vetve vrátane výnimky (§5.12).
- **R-C7 `pending` a `blocked` (U3 R-J5 c, U2 §15.1; audit 5):** Aktualizovať pre skupinu **nie je** ponuka (U3 ho vypína) — riadok má chip `err` a namiesto toho tlačidlo
  **„Vrátiť zálohu…"** (`rotate-ccw`), ktoré otvorí R-J1 vyfiltrované na skupinu s **najnovšou zálohou prevzatia** navrchu; `#libNote`: „Prevzatie <skupiny> sa prerušilo — vráť zálohu.
  Kým to neurobíš, výpočty a exporty s touto knižnicou sú zastavené." Aktualizovať ostatných skupín beží. **Test:** `pending` je jediná problémová skupina → Aktualizovať `aria-disabled`
  („Nie je čo prevziať"), „Vrátiť zálohu…" prítomné a funkčné.

### R-D · Použité záznamy otvorenej zákazky (`used_ids` pre U3 R-N1, A4 B5)

- **R-D1** `LibrarySyncDialog.used_ids(model)` (hlavné vlákno, len čítanie, žiadna operácia) → `{ entry_key => {id => [kde]} }`:
  `materials` ← `Materials.used_material_ids(model)` (S14; zahŕňa aj globálne šablóny — dovetok „používa ho otvorená zákazka alebo šablóna");
- **R-D2 (audit 4)** `appliances` ← `BudgetStore.appliances(model)` (`core/budget_store.rb:248-250`; položky normalizuje `normalize_appliance`, `catalog_id` `:506-507`) →
  `{catalog_id => ["rozpočet: <nazov>"]}` pre každú položku s neprázdnym `catalog_id`. Len čítanie modelu (`read_json`), žiadna operácia. Kovanie, šablóny, dodávateľ: bez `used`
  (kovanie chráni snapshot — A4 D; šablóny a sadzby zákazka neodkazuje ID) — okno to povie vetou „Pri Kovaní sa použitie v zákazke neoveruje (zákazka má vlastnú kópiu)".
  Žiadny model → `{}`. **Test:** odstránený spotrebič, ktorý má rozpočet zákazky → `used` a červený riadok v R4.
- **R-D3** zlyhanie `used_ids` (celé aj jednej knižnice) → `{entry_key => :unknown}` + log (tvar zladený s U3 R-N1: hodnota je `Hash{id => [kde]}` alebo `:unknown`; U3 vráti zmiznutým záznamom
  `used: :unknown`; zoznam `used_unknown` v pláne R-C2 skladá U5 server zo svojho `used_ids`); okno pri tej skupine **viditeľne** povie „Nepodarilo sa zistiť, čo z <skupina> používa
  otvorená zákazka — skontroluj zmiznuté záznamy" (jantár; nikdy tichá prázdna množina). Test pre materiály aj spotrebiče.

### R-E · Odoslať s poznámkou (O8, R3, R18)

- **R-E1 tlačidlo** kreslené len pri `admin.self` (inde sa nekreslí — Lucia ho nevidí, mockup). Text „Odoslať zmeny (N)" (N = skupiny `local_changes`/`not_on_disk`/nový plugin);
  pri skupine `unknown` „Odoslať…" bez čísla (výber robí U3 R-H1 z čerstvého exportu). `aria-disabled` s dôvodom pri N = 0 bez `unknown` („Všetko je rovnaké ako na Disku"),
  `admin.state` ≠ `self` (R-F), R18 (`send_reason` U3 R-G2), stave Disku ≠ `ok`/`empty`.
- **R-E2 modal** „Odoslať knižnicu na Disk" (D-15, `memoryKey: 'lib:send'`): veta „Odošlú sa zmenené: Materiály (verzia 15) a Šablóny (verzia 7). Ostatné sú rovnaké
  ako na Disku." · pole **„Poznámka pre Luciu (nepovinná)"** (`text`, max 200 znakov — U3 R-A5; klientsky orez + serverová kontrola) · Zrušiť / **Odoslať** (`primary`).
- **R-E3 beh (U3 R-G2, R-H1; U2 §15.0):** `lib_send {note}` → precheck distribúcie vo `TimedWorker` (limit 60 s, U3 R-G2; modal „Overujem verziu pluginu na Disku…") → odmietnutie
  = veta v modale → inak potvrdenie „Okná pluginu sa na chvíľu zavrú" → R-B7 + bariéra R-B3 → `LibrarySync.publish_prepare(groups:, note:, precheck:)` (hlavné vlákno, synchrónne) →
  okná sa znova otvoria (bariéra končí) → `publish_run(ticket)` vo vlákne (180 s; box „Odosielam…", `busy_op: 'send'`) → `publish_finish` → výsledok per skupina do `#libNote`
  (`sent` · `failed` „odoslanie neprešlo, skús znova" · `skipped`; R-N) → `lib_scan`. Rozpísané neuložené hodnoty v sekciách sa neodosielajú (veta v potvrdení).

### R-F · Správca a ponuka „⋯" (O2, R3, R19, U3 R-C)

- **R-F1 „Toto PC je správca knižnice…"** kreslí sa **len** pri `admin.state == none` a Disku `ok`/`empty` (mockup: kým nikto; Lucia ponuku „stať sa správcom" po založení
  nevidí). Potvrdenie D-15 bez polí: „Toto PC (<COMPUTERNAME>) bude jediné, ktoré smie odosielať knižnicu na Disk. Druhé PC bude len aktualizovať. Potvrdí sa po 15 minútach,
  keď sa Disk zosynchronizuje." → `lib_claim_admin` → `LibrarySync.claim_admin!` (U3 R-C3 krok 1, hlavné vlákno — §12 D5) → `lib_scan`.
- **R-F1b čakanie na aktiváciu (U3 R-C3 krok 2):** `admin.state == claiming` → riadok Správca „<toto PC> — potvrdí sa najskôr o HH:MM" (z `activate_after`); Odoslať `aria-disabled`
  s tou istou vetou. Prvý sken po `activate_after` (vstup do O plugine, Obnoviť, štart) zavolá `LibrarySync.activate_admin!` **automaticky** (hlavné vlákno; používateľ ho už potvrdil)
  → `self`, alebo `conflict` (iný kandidát). Bez otvoreného Štúdia sa aktivácia odloží na najbližší sken — nič sa nedeje na pozadí.
- **R-F2** „Odovzdať správcu…" sa **nekreslí** (Scope OUT).
- **R-F3 dvaja správcovia (R19; audit 7):** veta v riadku Správca (jantár): „Na Disku sú zapísaní dvaja správcovia (<PC A>, <PC B>) — odosielanie je vypnuté na oboch PC.
  Vyrieš v ⋯." Aktualizovať ide ďalej (len od doterajšieho zdroja — U3 R-C4). **Ručná akcia v „⋯" na oboch PC:** pre každého kandidáta položka **„Ponechať správcu: <PC>…"**
  → potvrdenie D-15 bez polí: „Správcom ostane <PC>. Druhé PC prestane byť správcom; odosielanie sa zapne po potvrdení (15 min)." → `lib_resolve_admin {pc_id}` →
  `LibrarySync.resolve_admin!(keep_pc_id)` (**API pre U3 — §12 D13**) → `lib_scan`. Ponechané PC prejde cez `claiming` → `self` (R-F1b). `mismatch` → „Toto PC nie je potvrdené ako
  správca — odosielanie vypnuté."
- **R-F4 ďalšie položky „⋯":** **„História a návrat…"** (U5b; `rotate-ccw`) · **„Zálohy pred prepisom…"** (U5a; `rotate-ccw`, len keď `LibraryTransfer.backups` nie je prázdne).
  Ponuka je overlay pod spúšťačom, Escape zavrie len ju (§1).

### R-G · Kontrola pri štarte a oznámenie (O4, R7, R21, A3 FIX 5) — U5b

- **R-G1 modul `Noxun::Engine::UpdateNotice`** (`ui/update_notice.rb`): stav `{ 'libs' => [labels skupín newer/newer_and_local/never_taken], 'plugin' => 'x.y.z'|nil,
  'admin' => {'state','pc_name'}|nil, 'blocked' => [group keys], 'checked_at' }`; `ensure_checked!` (R-K2); `start!` (raz na proces), `state`, `apply_library(payload)` (volá ho aj `LibrarySyncDialog` po každom skene a akcii — jedna pravda pre ikonu),
  `apply_plugin(state, available)` (volá ho aj `SupplierSettingsDialog.deliver_updater_check` — 1 riadok), `broadcast!` (push do Štúdia a Inspectora, R-H).
- **R-G2 háčik** v `main.rb` za `Tools.install!` (S13): `UI.start_timer(8, false) { UpdateNotice.start! }` — oneskorenie, aby kontrola nebrzdila otvorenie modelu.
  `start!` spustí **dva** behy cez `TimedWorker` (U3 R-E2): sken knižnice (`LibrarySync.startup_check` — U3 R-F2, beží až po `recover_pending!` z bootu, nič nesťahuje) a **kontrolu pluginu**
  `Updater.check(Updater.source_dir, VERSION)` (prázdna cesta = preskočiť). Deadline 4 s každý; timeout alebo chyba = **ticho** (žiadne oznámenie, ikona sa nekreslí;
  stav ostáva viditeľný v O plugine pri otvorení — A3 FIX 5). Nič nezapisuje, okno neotvára.
- **R-G3 oznámenie** (`UI::Notification`, referencia v `@note` — S12), keď `libs` alebo `plugin` nie je prázdne: text „Na Disku sú novšie knižnice: Materiály, Kovanie."
  / „Na Disku je nová verzia pluginu v0.19.1." / oboje v jednej vete. Tlačidlá **„Otvoriť O plugine"** (`on_accept` → **len** `StudioDialog.show(open_section: 'about',
  anchor: 'library')`) a **„Neskôr"** (`on_dismiss` → nič). Raz na proces SketchUpu. Chýbajúce `UI::Notification`/`Engine.extension` → bez oznámenia (ikona ostáva).
- **R-G4 hranica updatera sa mení vedome (S20):** „žiadny auto-check na pozadí" → „jedna kontrola verzie pri štarte, len na zobrazenie (R21); aplikovanie ostáva výhradne
  klikom". Prepísať v odseku `updater.rb` ui-lifecycle.md.

### R-H · Ikona stiahnutia (O9, R21) — U5b

- **R-H1 jedna pravda** = `UpdateNotice.state`; ikona svieti, keď `libs` **alebo** `plugin` nie je prázdne; inak sa **nekreslí vôbec** (O9 „rail neberie miesto").
  Tooltip skladá klient: „Na Disku je novšia knižnica: Materiály, Kovanie" · „Na Disku je plugin v0.19.1" · oboje oddelené „ · ".
- **R-H2 navigácia Štúdia:** riadok `about` v `studio_sections.js` dostane `badge: 'upd'`; `navCounts`/`navBadgeHtml` (S3) rozšíriť o druh `upd` → ikona `cloud-download`
  (`.nbadge.upd`, výberová rodina — teal, §1 „stav"), `aria-label` = tooltip. Payload Štúdia nesie `upd` (z `UpdateNotice.state`, cez `push_state`); zmena stavu →
  `broadcast!` → `js("NX.setUpd(...)")` prekreslí len navigáciu. **Nahrádza bodku z O4** (O9).
- **R-H3 kotva** `about` riadku: `anchor: { fn: 'aboutOpenAnchor', phase: 'after', miss: '' }` — po vykreslení posunie `#aboutLib` do pohľadu (pri kotve `plugin` na blok
  updatera). Jedna kotva pre oba vstupy (rail, oznámenie).
- **R-H4 rail Inspectora:** `<button id="railUpd" class="railbtn fn upd" hidden>` hneď za `#railTagyBox` (S10), ikona `cloud-download`, bublina `.railtip` (nie `title`),
  `aria-label` „Aktualizácia na Disku — otvoriť O plugine", `data-nx-usage="rail:aktualizacia"`. Klik → `openStudio('about', 'library')` (S9). `NX.setUpd(st)` (push
  `Panel.push_upd` vzoru `push_tags`, S11; aj v `push_init`) nastaví len `hidden`, text bubliny a `aria-label` — **kostra sa neprekresľuje** (§5.1). Štýl: výberová
  rodina (`--nx-select`, `--nx-select-bg`) — jediné rozsvietené tlačidlo funkčnej sekcie s významom „čaká na teba". Vertikálny priestor: v obsahu panela nepribúda riadok.

### R-I · Ikony a texty (UI_DIZAJN §1, §4)

- **Existujúce:** `cloud-download` (Aktualizovať knižnicu, ikona O9 — ten istý význam „stiahni nové zo zdroja" ako Aktualizovať plugin), `refresh-cw` (Obnoviť stav), `more-horizontal`
  (⋯), `rotate-ccw` (História a návrat…, Vrátiť, Vrátiť zálohu — §1 „Vrátiť…"), `alert` (veta O7/R19), `info`.
- **Nová ikona: `cloud-upload`** (Lucide, pár k `cloud-download`) — Odoslať zmeny; riadok do inventára §4 (guard S16). **Bez** `user`, `clock`, `disk` z mockupu —
  položky ponuky a riadky `.inforow` sú text (§12 D6).
- Texty bez žargónu (§1): „Disk", „správca", „verzia", „záloha"; nie „head", „manifest", „seed", „sync". Verzia „v0.19.0" (malé v).

### R-J · História, Vrátiť verziu, zálohy (O5, R5, U3 R-K/R-L, U2 R4.3)

- **R-J1 (U5a) modal „Zálohy pred prepisom"** (D-15, `custom`): zoznam `LibraryTransfer.backups` (najnovšia navrchu, max 5 na skupinu — U2 §12 D4): skupina · dátum · dôvod ·
  verzia pluginu · **„Vrátiť zálohu"** (`rotate-ccw`). Záloha z inej verzie pluginu alebo `:broken` → `aria-disabled` s dôvodom. Klik → `lib_backup_preview {backup_id}`
  → `peek = LibraryTransfer.backup_peek(id)` + `LibrarySync.diff_documents(g, peek['documents'], used_ids:, attachment_rels: peek['attachment_rels'])` (**API — §12 D15**, U2 R4.8) → **to isté okno
  dopadov ako R-C3** (zoznam pridaných/zmenených/zmiznutých, `used` červeno, veta R17 pri `price_changed`, R-D3) s nadpisom „Vrátiť <skupina> na stav z <dátum>?" a vetou „Súčasný stav sa najprv
  uloží ako ďalšia záloha." (audit 1); server si odloží `seen_fingerprint` z `diff_documents` k `backup_id` (ako pri tikete R-C2) → potvrdenie (s väzbou na zákazku R-C2) →
  `lib_backup_restore {backup_id}` → bariéra R-B3 → **`LibraryTransfer.restore_backup!(id, plugins_dir: Engine.plugin_dir, seen_fingerprint: <odložený>)`** (jediná signatúra U2 R4.8; zladené
  17.10. — bez `seen_fingerprint:` sa nevolá nikdy) pod zámkom U3 (R-K) → `:changed` = veta U2 „Knižnica sa od zobrazenia zmenila — otvor okno znova" bez zápisu; inak natívna veta U2 → `lib_scan`.
  Návrat vráti aj prílohy archivované pri prevzatí (U2 15.11 C1). `entry` U3 sa nemení (U3 R-K) → skupina ukáže „vlastné zmeny".
- **R-J2 (U5b) modal „História knižnice — <skupina>"**: výber skupiny segmentom (5), tabuľka **Verzia · Kedy · Poznámka · PC · Plugin** (U3 R-L1/R-D5; PC a plugin = U3 N4)
  · aktuálna verzia označená „aktuálna" · pri ostatných **„Vrátiť"** (`rotate-ccw`) **len pri `admin.self`**; inde sa nekreslí. Veta pod tabuľkou: „Vrátenie odošle obsah
  zvolenej verzie ako novú verziu N+1 — Lucia ju dostane bežným Aktualizovať." Pod ňou „Tvoje zálohy pred prepisom" = R-J1 (jeden zoznam, nie dva).
- **R-J3 Vrátiť verziu (audit 1)** → `lib_revert_prepare {group, version_id}` → `LibrarySync.revert_prepare(g, version_id)` vo vlákne (overenie + staging ako R-C1; **API — §12 D15**)
  → `diff(g, ticket, used_ids:)` → **okno dopadov R-C3** pre verziu K (nadpis „Vrátiť <skupina> na verziu K z <dátum>?") + pole poznámky (predvyplnené „Návrat na verziu K z <dátum>",
  U3 R-L2) → potvrdenie (väzba na zákazku R-C2) → `lib_revert {ticket_id, note}` (server doplní `seen_fingerprint` z diffu odloženého pri tikete — R-C2) → R-B7 + bariéra R-B3 → `LibrarySync.revert!(g, ticket, note:, seen_fingerprint:)`
  → natívna veta → `lib_scan`.

### R-K · Pruh v sekciách knižníc (O6, R13) — U5b

- **R-K1** sekcie `mat`, `hw`, `tpl`, `appl`, `bset` (S1) **a `rules`** (edituje pravidlá kovania a ukazuje ABS pravidlá zo zdieľaných skupín — zámer R13, §12 D7): **jeden jantárový riadok** navrchu tela sekcie (`.libbar`: `--nx-warn-bg-soft`, `--nx-warnchip-fg`,
  `--nx-warnchip-border`, ikona `alert`): „Knižnicu spravuje <PC správcu> — tvoje zmeny tu sa pri Aktualizovať prepíšu. Pošli ich správcovi." **Kreslí sa len** pri
  `admin.state ∈ {other, mismatch}` (existuje správca a nie je to toto PC; §12 D7). Na PC správcu ani bez správcu sa nekreslí.
- **R-K2** jedna funkcia `nxLibBarHtml(upd)` (v `about.js` alebo `studio_settings.js`) volaná z kreslenia tela týchto 6 sekcií cez register — vlastnosť riadku
  `libbar: true` v `studio_sections.js` (nie vetva podľa id; guard H14a). **Dáta (audit 6):** jediný zdroj = `UpdateNotice.state['admin']` (R-G1), ktorý plní **štartovací sken**
  aj každý sken `LibrarySyncDialog`; payload Štúdia ho nesie v `upd` od prvého `push_state`. `StudioDialog.show` volá `UpdateNotice.ensure_checked!` (sken vo vlákne, ak ešte
  neprebehol alebo je starší ako 10 min) a jeho výsledok `broadcast!` → `NX.setUpd` **prekreslí pruh otvorenej sekcie** (len uzol `.libbar`, nie telo). Kým stav nie je známy,
  pruh sa nekreslí. **Test:** štart → priamo Materiály (bez O plugine) → po doručení skenu pruh je.
- **R-K4 zablokovaná skupina (U2 §15.1):** pri `blocked`/`pending` skupiny ukáže sekcia tej skupiny **červený** riadok (`--nx-err-*`) „Knižnica <skupina> je po prerušenom
  prevzatí zablokovaná — výpočty a exporty čakajú. Otvor O plugine a vráť zálohu." s odkazom (`button`, deep-link `openStudio('about','library')`). Ten istý uzol ako `.libbar` (má prednosť).
- **R-K3** pruh je **stavová veta** (§1 — nie tooltip), jeden riadok, dlhý text výpustka + plný text v `title`. Úpravy v sekciách ostávajú povolené (R13 „ostáva").

### R-L · Iná verzia pluginu (O7, R14, R18)

- **R-L1** keď U3 vráti pre aspoň jednu skupinu `plugin_newer_on_disk` (autorita `LibraryTransfer.import_allowed?`/`export_allowed?` — U2 R5; `compatible?` sa nezavádza): jantárová veta v boxe (nad tabuľkou, `.warnline`, `alert`): „Knižnica na Disku je z **v0.19.1**,
  máš **v0.19.0** — najprv aktualizuj plugin (box vyššie). Odoslať aj Aktualizovať čakajú." Obe tlačidlá `aria-disabled` s rovnakým dôvodom.
- **R-L2** `plugin_older_on_disk`: „Knižnica na Disku je zo staršieho pluginu (v0.18.9) — správca ju po aktualizácii pluginu odošle znova." (Aktualizovať čaká, U3 R-G1.)
- **R-L3** Odoslať odmietnuté podľa R18 (`send_reason` U3 R-G2: novší plugin na Disku / správcova verzia ešte nie je v distribúcii / distribúcia nečitateľná) — veta
  v `title` a `#libNote`, text zo servera (U3).

### R-N · Výsledky príloh z U4 (len texty; U4 R3.2, R4.3, D9)

- **Odoslať:** `attachments_skipped` z packetu skupiny (U4 R3.2) → dovetok riadku výsledku „odoslané bez N fotiek (u teba chýbajú)". Packet vzniká v U3 `publish_prepare` —
  výsledok per skupina ho nesie podľa U3 R-H3 (§12 D12).
- **Aktualizovať (zladené s U4 §15.2/§15.7):** prevzatá skupina (`taken`) konflikt príloh **nehlási** — ponechanie rozdielneho vzhľadu či listu neexistuje (buď skupina neprejde, alebo sa pri
  Prepísať nahradí a pôvodný ide do zálohy, čo okno R4 už povedalo). Počty príloh sa neukazujú; dovetok „ponechané tvoje" **zaniká**.
- `:missing_attachments` (U2 R4.7, U4 R3.2) → veta U2 bez úprav. Výsledok skupiny `attachment_conflict` (U3 R-J4, U4 §15.2; skupina sa **neprevzala**, `entry` sa neposunul) → „<Skupina> sa neprevzala:
  vzhľad/list <label> sa líši od verzie správcu. Aktualizuj znova a zvoľ Prepísať (tvoj súbor ostane v zálohe)."
- **Test (audit 1, U4 §15.2):** konflikt prílohy v pláne → skupina má voľbu R-C4; bez `:overwrite` veta vyššie.

### R-M · Dokumentácia (na mieste)

- ui-lifecycle.md: odseky **`### Sekcia O PLUGINE v Štúdiu (`about`)`** a **`### ui/js/about.js`** prepísať (box, tretí argument, koliesko bez boxu) · **nový odsek
  `### library_sync_dialog.rb`** (akcie, sken, bariéra, vstupy počas behu, tikety) · **nový odsek `### update_notice.rb`** (U5b) · odsek **`updater.rb`** — hranica R-G4
  a presun `close_plugin_dialogs` (R-B3) · `### Satelitné okná` — veta „bariéra zatvára Inspector, Štúdio a Z-dialog pred aktualizáciou pluginu **aj knižnice**".
- UI_DIZAJN: §4 inventár (`cloud-upload`; `cloud-download` aj „Aktualizovať knižnicu, ikona aktualizácie v navigácii a raile") · §5.1 rail (nové tlačidlo pod okom) ·
  §5.15 (pruh knižnice, badge `upd`). docs/ARCHITEKTURA.md: riadky nových modulov (guard). kniznice.md: F-riadky „UI = U5" na mieste.

## 7 · Testy a DoD

**Headless Ruby** (`tests/pure/test_u5a_library_ui.rb`, `test_u5b_update_notice.rb`; stub `LibrarySync`/`LibraryTransfer` **s presnými menami U2/U3**, seamy S6):

| Oblasť | Prípady (každý s mutáciou — odstránená kontrola → test padne) |
|---|---|
| whitelist | neznáma akcia odmietnutá; `lib_*` zapojené v `studio_dialog.rb` |
| sken | token: neskorá odpoveď iného okna/cesty zahodená; single-flight; timeout → `disk: 'timeout'`; `about_info['library']` nikdy nespustí sken |
| bariéra | zápisová akcia nezačne, kým `dialogs_closed?` nie je `true`; limit 3 s → zrušenie bez volania U3; okná otvorené pred akciou sa po nej otvoria (Štúdio na `about`/`library`); `update_in_progress?` počas behu `true`, po `lib_done!` `false` aj pri výnimke |
| tiket | `lib_take_commit` s cudzím/starým `ticket_id` alebo z iného okna → odmietnutie bez zápisu; tiket sa spotrebuje |
| rozhodnutia | skupina s lokálnymi zmenami bez voľby → `:skip`; `:overwrite` len z klienta; neznámy kľúč skupiny zahodený |
| used_ids | materiál použitý v modeli → `used` v pláne; výnimka → `{}` + veta R-D3 |
| výsledky | každý kód U3 R-J4 a U2 R4.7 má riadok hlášky; `:failed_restore_failed` menuje zálohu; `:other_instance` → veta o oknách |
| správca | claim len pri `none` + `ok/empty`; Odoslať nekreslené/odmietnuté pri `other`, `mismatch`, `conflict`, `none` |
| vlákna | guard nad zdrojom: telá `TimedWorker.start`/`Thread` v `library_sync_dialog.rb` a `update_notice.rb` bez `Sketchup.`, `UI.`, `LibraryTransfer.` |
| štart | `start!` raz na proces; timeout/chyba → bez oznámenia; `on_accept` volá len `StudioDialog.show(open_section: 'about', anchor: 'library')` |
| **delta 17.10.** | pomenované regresné testy so scenárom a očakávaním v **§15.1** (U5/1, U5/3, U5/4, U5/7, B: `seen_fingerprint`, `diff` `'unknown'`, `used` trojstav, výsledok konfliktu prílohy) |
| §15 | R-B7 utíšenie (odložený emit/zápis so starou epochou nič nezapíše); väzba plánu na zákazku (iný `model_guid`/`used_ids` → nový plán, žiadny zápis); `pending`/`blocked` len „Vrátiť zálohu"; dopady pred Vrátiť zálohu a Vrátiť verziu (R17, `used`); spotrebič z rozpočtu `used`; `used` `:unknown` viditeľné; pruh po priamom otvorení sekcie; `claiming` → aktivácia po `activate_after`; `resolve_admin!` z „⋯" |

**JS** (`tests/js/test_u5_about.js`, `test_u5_rail_nav.js`): R0.1 snapshot · chip pre každý `state` · `aria-disabled` (nikdy `disabled`) s dôvodom · Odoslať sa nekreslí mimo správcu ·
„⋯" bez položiek sa nekreslí · R4: `used` riadok nikdy nezbalený, veta R17 len pri `price_changed`, predvolená voľba preskočiť, všetko `:skip` → potvrdenie `aria-disabled`,
varovanie závislostí · badge `upd` a `#railUpd` skryté pri prázdnom stave · tooltip oboch druhov · XSS (`nxAboutEsc` nad poznámkou O8 a menami záznamov) · pruh len pri `other/mismatch`.

**Guardy:** inventár ikon (`cloud-upload`), register sekcií (H14a: `badge`, `libbar`, kotva), počet okien (bez zmeny), `?v=` = VERSION, UI_DIZAJN §1 (rádiusy, žiadny hex).
**DoD:** `ruby tests/run_all.rb` zelené · každá JS sada zvlášť · `ruby scripts/encoding_guard.rb --repo` · **export test `P == K`** · ui_foto `-Record` + hárok v PR ·
PR uvedie skutočný diff kódu pluginu (poistka §2) a výsledok in-SU R-B4, ak bežal.

## 8 · In-SU

**Nie je brána** (§5). **Odporúčané** (U5a, jeden beh `scripts\run_su_tests.ps1 -CloseWhenDone`): scenár `run_u5a_barrier` nad kópiou ENGINEtests.skp so **sandboxom
`Materials.test_dir_override` a TEMP „Diskom"** (nikdy reálne H: ani `%APPDATA%`) — otvorí Inspector + Štúdio, spustí bariéru so stubom prevzatia, overí `dialog_closed?` oboch,
volanie stubu až po zatvorení, znovuotvorenie Štúdia na `about` a uvoľnenie `update_in_progress?`. PR uvedie hlavu behu.

## 9 · Riziká

| # | Riziko | Dopad | Opatrenie |
|---|---|---|---|
| 1 | Prepis zmení čísla otvorenej zákazky (A4 D) | iná cena/hrúbka pri prepočte | R4 zoznam s `used`, veta R17, predvolené preskočiť, záloha U2 |
| 2 | Okno knižnice uloží starý obsah po prevzatí (A4 B6) | prevzaté dáta prepísané | bariéra R-B3 + znovuotvorenie z čerstvých dát |
| 3 | Bariéra sa zasekne (okno sa nezavrie) | Aktualizovať nespustené | limit 3 s, zrušenie bez zápisu, veta; vzor overený updaterom |
| 4 | Visiaci H: pri štarte | brzdenie SketchUpu | vlákno, oneskorenie 8 s, ticho pri timeoute |
| 5 | `claim_admin!` zapisuje na H: na hlavnom vlákne | krátke zamrznutie | malý lokálny zápis do zrkadla, prijaté (§12 D5) |
| 6 | Ikona O9 svieti „falošne" (napr. `never_taken` u Michala pred prvým odoslaním) | zbytočné upozornenie | `never_taken` sa počíta len keď na Disku verzia je; u správcu sa `not_on_disk` neráta |
| 7 | API U2/U3/U4 sa pri implementácii zmení | rozpor mien | U5 štartuje až po mergi U4; zmena mien = zladenie package pred štartom |
| 8 | Dlhý zoznam zmien v R4 | neprehľadné okno | zbaľovanie > 8 okrem `used`, karta `md` so scrollom tela |

## 10 · Smoke checklist pre Michala (oba PC, po U5a; body 9–12 po U5b)

1. **Tvoje PC:** Štúdio → O plugine → pod aktualizáciou pluginu box **Zdieľaná knižnica**: Disk „pripojený", Správca „nikto", 5 riadkov.
2. „⋯" → **Toto PC je správca knižnice…** → potvrď → Správca „<tvoje PC> — potvrdí sa najskôr o HH:MM"; po 15 min Obnoviť → „(toto PC)" a **Odoslať zmeny (5)**.
3. Odoslať → poznámka „prvé odoslanie" → Odoslať → všetky riadky „aktuálne", Posledné odoslanie s dátumom a poznámkou.
4. **Luciino PC:** O plugine → Správca „<tvoje PC>", riadky „ešte neprevzaté", **žiadne** Odoslať ani „Toto PC je správca".
5. Aktualizovať → okno povie, že jej knižnica sa nahradí tvojou a ostane záloha; skontroluj, či vidíš zoznam zmien a pri materiáloch, ktoré má otvorená zákazka, červené
   „používa ho otvorená zákazka". Pre Materiály zvoľ **preskočiť**, potvrď → okná sa zavrú, hláška „Kovanie prevzaté … Materiály preskočené", Štúdio sa otvorí na O plugine.
6. Znova Aktualizovať → Materiály **Prepísať** → po hláške: Materiály „aktuálne", v Materiáloch tvoje dekory **s fotkami a vzhľadmi**.
7. „⋯" → Zálohy pred prepisom → je tam jej záloha Materiálov; **nevracaj** (len pozri).
8. **Tvoje PC:** zmeň cenu jednej dosky → riadok Materiály „neodoslané zmeny", Odoslať zmeny (1) → odošli s poznámkou → na Luciinom PC Obnoviť stav → „novšia na Disku" + poznámka.
9. **Luciino PC:** zatvor a spusti SketchUp → do ~10 s oznámenie „Na Disku sú novšie knižnice: Materiály" → Otvoriť O plugine → Štúdio otvorené rovno na boxe.
10. Pri „O plugine" v navigácii a v lište Inspectora pod okom **ikona stiahnutia**; po Aktualizovať zmizne. Klik na ikonu v Inspectore otvorí Štúdio na boxe.
11. **Luciino PC:** Štúdio → Materiály (aj Kovanie, Šablóny, Spotrebiče, Pravidlá, Nastavenia rozpočtu) → jantárový pruh „Knižnicu spravuje <tvoje PC>…". Na tvojom PC pruh nie je.
12. **Tvoje PC:** ⋯ → História a návrat… → Materiály → pri predošlej verzii **Vrátiť** → na Luciinom PC Aktualizovať → cena dosky je späť.
13. **Hrúbka (U2 §15.7):** na tvojom PC zmeň hrúbku dosky použitej v testovacej zákazke, odošli; na Luciinom PC prevezmi a otvor tú zákazku → Kontrola ju ukáže ako neaktuálnu.
14. Hláška „nepodarilo sa", zaseknuté okno alebo chýbajúce okno po aktualizácii → nahlás (napíš, na ktorom PC a ktorý krok).

## 11 · Checklist uzáveru (U5a aj U5b zvlášť)

Bump **patch** (`noxun_engine.rb` + `main.rb`) + všetky `?v=` · testy zelené (§7) · export test **P == K** v PR · ui_foto hárok v PR · odseky R-M na mieste + **Grep tvrdení
o zoznamoch**: inventár ikon §4, `SECTION_ACTIONS` v komentároch, zoznam účastníkov bariéry („Ďalšie účastníky bariéry"), zoznam vstupov s `update_in_progress?`,
druhy `badge` v hlavičke `studio_sections.js`, rail §5.1 · `SYSTEM/STAV.md` prepis · KRONIKA navrch · PLAN riadok U5a/U5b ✅ + `PR #?` → commit s číslom ·
**DOGFOODING D-48 → `DOGFOODING_vyriesene.md`** (plný text + PR + riadok navrch INDEXU) **až s U5b** (U5a ho nechá otvorený) · predrecenzia v PR popise.
**Po U5b nasleduje uzáver bloku UPDATE** (minor, `release/UPDATE`, smoke §10 na oboch PC).

## 12 · Rozhodnutia — potvrdené orchestrátorom 17.10.2026

- **D1 výrobná/cenová áno** (ako U2 D1, U3b D1): nový ovládač prepisuje katalógy s cenami; dôkaz = export test P == K.
- **D2 rez U5a / U5b** (U5a = úplná funkcia vrátane zálohy, U5b = upozornenia, história, pruh); jeden audit.
- **D3 ✅ presun `close_plugin_dialogs`/`dialogs_closed?` do `Engine`** — jedna bariéra pre updater aj knižnicu; implementátor pred presunom overí guardy
  `test_d52b_updater_ui.rb` (pripínajú text `updater_worker`, U3 S11); ak pripínajú aj tieto metódy, ostane delegácia zo `SupplierSettingsDialog`.
- **D4 ✅ predvolená voľba R4 = preskočiť — VEDOMÁ ODCHÝLKA od mockupu** (mockup ukazuje zvolené „Prepísať"). Dôvod: prepis mení čísla otvorenej zákazky a nechýbajúci
  klik nesmie potichu prepísať vlastné zmeny; prepísať je jeden klik. Orchestrátor odchýlku oznámi Michalovi; zápis do rozhodnutí bloku a rámik „platí" v mockupe.
- **D5 ✅ `claim_admin!` na hlavnom vlákne** (zápis jedného malého súboru do zrkadleného H: je lokálny).
- **D6 bez ikon `user`, `clock`, `disk`** z mockupu (UI_DIZAJN §4 — nová ikona len s novým významom); položky „⋯" `rotate-ccw` alebo text. Jediná nová ikona `cloud-upload`.
- **D7 ✅ pruh len pri `other`/`mismatch`** (pri `none` nikto nespravuje) **a aj v sekcii Pravidlá** (edituje pravidlá kovania a ukazuje ABS pravidlá zo zdieľaných skupín — zámer R13).
- **D8 `used_ids`** len pre materiály a spotrebiče (R-D2); kovanie chráni snapshot (A4 D).
- **D9 kontrola pluginu pri štarte** (R21) mení zapísanú hranicu updatera „žiadny auto-check" — len zobrazenie, aplikovanie ostáva klikom.
- **D10 znovuotvorenie okien po bariére** — Štúdio na `about`/`library`, Inspector len ak bol otvorený; hláška natívne pred znovuotvorením (vzor updatera).
- **D11 ✅ mená údajov PC** podľa U2 R4.5 (`pc_id`, `drive_root`, `admin`) — zladí PACKAGE_U3; U5 ich priamo nečíta (berie `admin`/`root` zo `status` U3).
- **D12 ✅ `attachments_skipped`** nesie výsledok odoslania per skupina U3 R-H3 (zladí PACKAGE_U3) — U5 z neho skladá vetu R-N.

- **D13 ✅ požiadavka na U3 — `LibrarySync.resolve_admin!(keep_pc_id)`** (audit 7, R19): hlavné vlákno, zámok R-B2; len pri `admin_state == conflict` a `keep_pc_id` ∈ kandidáti
  najvyššieho `seq`; zapíše **nového kandidáta** `admin-<seq+1>-<r8>.json` `{ std:1, kind:"noxun_library_admin", seq: seq+1, pc_id: keep_pc_id, pc_name, at, resolves: [pc_id oboch] }`
  (smie ho zapísať ktorékoľvek z dvoch PC) → `update_sync_meta!('admin' => keep_pc_id == pc_id)` → `[:ok, admin_state]` | `[:not_conflict | :unknown_pc | :disk, veta]`. Aktivácia
  ponechaného PC ide bežným R-C3 krok 2 (lehota T od `at` nového kandidáta); kandidát s `resolves` ruší konflikt nižšieho `seq`; PC, ktoré nie je ponechané a má lokálne `admin == true`,
  si ho pri najbližšom `status` zhodí (`update_sync_meta!('admin' => false)`). `status['admin']` nesie `candidates: [{pc_id, pc_name, seq}]` a `activate_after` (UTC) pre R-F1b/R-F3.
- **D14 ✅ požiadavka na U3/U4 — `diff` nesie `attachment_conflicts: [{rel, label}]`** (povinné prílohy s iným obsahom pod rovnakým menom; porovnanie SHA stagingu a lokálneho
  súboru, len čítanie) — R-C2b; inak sa konflikt prejaví až výsledkom `attachment_conflict`.
- **D15 ✅ požiadavky pre okno dopadov pred Vrátiť (audit 1):** U2 `LibraryTransfer.backup_peek(backup_id)` → `[:ok, {'group','documents' => {entry_key => doc},'fingerprints'}]` |
  `[:broken | :missing, veta]` (len čítanie zálohy, overené SHA, bez zápisu) · U3 `LibrarySync.diff_documents(g, documents, used_ids:)` (tvar ako `diff`, vrátane `seen_fingerprint`)
  · U3 `LibrarySync.revert_prepare(g, version_id)` (vlákno; overenie + staging ako `take_prepare`) a `revert!(g, ticket, note:, seen_fingerprint:)` namiesto `revert!(g, version_id, note:)`.
  `restore_backup!(id, plugins_dir:, seen_fingerprint:)` — nesúlad lokálneho odtlačku → `:changed` bez zápisu (U2).

## 13 · Otázky pre Michala

**Žiadne** — uzavreté rozhodnutiami orchestrátora 17.10. (§12); odchýlku D4 Michalovi oznámi orchestrátor.

## 14 · Nálezy mimo scope

- **N1:** mockup kreslí položky správcu podľa PC (`onlyL`/`onlyM`); package podľa `admin.state` (R-F1).
- **N2:** kontrola pluginu v O plugine (`supplier_settings_dialog.rb:380-404`) a `UpdateNotice` majú dva behy toho istého `Updater.check` — po U5b zjednotiť na `TimedWorker` (U3 N1).
- **N3:** `Debug.report` (F10) + `UpdateNotice.state` a `LibrarySyncDialog.last_payload` — porovnanie PC Michal/Lucia pri smoke.
- **N4:** export lokálnych zmien Lucie správcovi (A4 B4 „neskôr") — prirodzený ďalší krok po bloku (napr. „Poslať správcovi" v pruhu O6).
- **N5:** `used_material_ids` zahŕňa aj globálne šablóny — vhodný kandidát na rozlíšenie „zákazka" vs. „šablóna" pre presnejšiu vetu R4.

## 15 · Audit návrhu — zapracovanie (Codex `gpt-6-astra`, 17.10.2026; [AUDIT_U5_raw.md](AUDIT_U5_raw.md)) · MÁ PREDNOSŤ

| # | Nález | Verdikt | Zapracovanie |
|---|---|---|---|
| 1 | BLOCKER Vrátiť verziu a Vrátiť zálohu obchádzajú R4/R17 | platný | **R-J1**, **R-J3** — to isté okno dopadov ako R-C3 nad konkrétnou verziou/zálohou; API **D15** |
| 2 | BLOCKER zatvorenie okien nie je bariéra rozbehnutých akcií | platný | **R-B7** (prepočet cien, Demos, epocha knižníc, inventár `QUIESCE` + guard, token okna) a test oneskoreného callbacku |
| 3 | FIX plán nie je viazaný na otvorenú zákazku | platný | **R-C2** `model_guid` + SHA `used_ids` pri potvrdení, nový plán pri zmene |
| 4 | FIX spotrebiče potichu bez „používa zákazka" | platný | **R-D2** `BudgetStore.appliances(model)` (`budget_store.rb:248-250`, `:506-507`), **R-D3** `:unknown` viditeľné v R4, test |
| 5 | FIX `pending` odporúča nevykonateľné Aktualizovať | platný | **R-C7** — pri `pending`/`blocked` len „Vrátiť zálohu…", test s jedinou problémovou skupinou |
| 6 | FIX pruh nemá dáta pri priamom otvorení sekcie | platný | **R-K2** `UpdateNotice.state['admin']` zo štartovacieho skenu + `ensure_checked!` pri otvorení Štúdia + prekreslenie pruhu; **R-G1** |
| 7 | FIX konflikt správcov bez ručnej akcie | platný | **R-F3** „Ponechať správcu: <PC>…" v „⋯"; API **D13** |

**Zladenie s §15 U2/U3/U4 (Z):** Z1 nové stavy riadkov `blocked`, `disk_behind`, `unknown`, `foreign_publisher` (R-A3) · Z2 sken cez `peek_group` bez bariéry (R-B2) · Z3 Odoslať
cez precheck a bariéru, lebo `export_group` vyžaduje zatvorené okná (R-E3, R-B3, R-B4) · Z4 správca v dvoch krokoch — `claiming` a automatická aktivácia po lehote (R-F1, R-F1b) ·
Z5 `stale_ticket`, `:dialogs_open`, `:busy_snapshot`, `'refresh'` vo výsledkoch (R-C5) · Z6 `decisions` s `seen_fingerprint` (R-C2) · Z7 `pending`/`blocked` a červený pruh sekcie
(R-C7, R-K4) · Z8 `attachment_conflict` a voľba prepísať (R-C2b, R-N, D14) · Z9 `import_allowed?`/`export_allowed?` namiesto `compatible?` (R-A6, R-L1) · Z10 smoke hrúbky U2 §15.7 (§10 bod 13).
**Rozsah:** +~120 riadkov kódu (R-B7, okno dopadov pred Vrátiť, `claiming`, `resolve_admin`, R-K2/R-K4) → U5a ~720, U5b ~470; poistka U5a sa zdvíha na ~780, nad ňu presun
Zálohy (R-J1) do U5b. Delta audit na R-B7 a D13/D15 pred U5a odporúčam (rozhodne orchestrátor).

**15.1 Integračné zladenie (delta 17.10.)** — [AUDIT_DELTA_raw.md](AUDIT_DELTA_raw.md) A (U5/1, U5/3, U5/4, U5/7 CIASTOCNE), B (obnova bez odtlačku, `:unknown`, neznámy diff, výsledok konfliktu prílohy),
C1/C2 (dopad na okno); mapa [INTEGRACIA_2026-10-17.md](INTEGRACIA_2026-10-17.md). R1–R21 a O1–O9 bez zmeny (D4 „predvolené preskočiť" platí), nová funkcia nepribúda. **Má prednosť pred §6 a §15 tabuľkou.**
Mená a signatúry U2 = PACKAGE_U2 **R4.8**, U3 = PACKAGE_U3 R-I/R-J/R-N po §15.1.

- **B (úpravy priamo v §6):** **R-J1** volá `restore_backup!(id, plugins_dir:, seen_fingerprint:)` vždy s odtlačkom z `diff_documents(…, attachment_rels: peek['attachment_rels'])`, ktorý drží server; **R-C2**
  jediný tvar plánu vrátane vetvy `'diff' => 'unknown'` (skupina ako s lokálnymi zmenami, veta R17, voľba R-C4) a `used` ∈ `true/false/null/"unknown"`; **R-C2/R-C5/R-J3** — `seen_fingerprint`
  drží server pri tikete, klient posiela len akciu; server zloží jediný tvar `decisions = {g => {action:, seen_fingerprint:}}` (U3 R-J2); **R-D3** `{entry_key => :unknown}` v tvare U3 R-N1;
  **R-N** prevzatá skupina konflikt príloh nehlási, `attachment_conflict` = skupina sa neprevzala (U4 §15.2/§15.7).
- **C1/C2 v okne:** okno dopadov pred „Vrátiť zálohu" chráni aj prílohy archivované v zálohe (zmena po zobrazení → `:changed`, veta „otvor okno znova"); návrat ich vráti (U2 15.11 C1) —
  v okne bez novej vety (veta „Súčasný stav sa najprv uloží ako ďalšia záloha" platí aj pre prílohy).
- **Regresné testy** (`tests/pure/test_u5a_library_ui.rb`, JS `tests/js/test_u5_about.js`; stuby U2/U3 s presnými menami R4.8; každý s mutáciou):

| Nález | Test | Scenár | Očakávanie |
|---|---|---|---|
| U5/1 | `test_restore_backup_passes_seen_fingerprint` | `lib_backup_preview` (stub `backup_peek` s `attachment_rels: ['template_previews/x.png']`, `diff_documents` vráti seen F) → `lib_backup_restore {backup_id}` | stub `restore_backup!` dostal `seen_fingerprint: F` a `plugins_dir:`; **mutácia** (volanie bez `seen_fingerprint:`) → test padne |
| U5/1 | `test_restore_backup_changed_after_preview` | po náhľade stub `restore_backup!` vráti `[:changed, veta]` | natívna veta U2 bez úprav, žiadny ďalší zápis, okná sa znova otvoria, `lib_scan` |
| U5/1 | `test_restore_backup_impact_window` | záloha, v ktorej chýba materiál „Lucia biela 18" použitý v modeli, `price_changed` true | okno dopadov: červený riadok „používa ho otvorená zákazka", veta R17, nadpis „Vrátiť Materiály na stav z …?" |
| U5/3 | `test_plan_rebuilt_when_model_switched` | plán nad modelom A (`Panel.model_guid` GA, `used_sha` S1) → stub prepne na model B (GB) → `lib_take_commit` | `take_commit` sa **nezavolá**, nový plán (`SS.libTake`) s vetou „Otvorená zákazka sa medzitým zmenila…", tiket ten istý |
| U5/3 | `test_plan_rebuilt_when_usage_changed` | ten istý model, `used_ids` po pláne pribudne použitie zmiznutého materiálu (SHA S2) | ako vyššie; nový plán ukáže riadok „používa ho otvorená zákazka" |
| U5/4 | `test_used_unknown_visible_materials_and_appliances` | `Materials.used_material_ids` a `BudgetStore.appliances` vyhodia výnimku | `used_ids` = `{'materials' => :unknown, 'appliances' => :unknown}` + log; plán: zmiznuté záznamy `used: "unknown"`, jantárová veta R-D3 pri oboch skupinách; nikdy prázdna množina |
| U5/4 | `test_diff_unknown_branch` (JS + Ruby) | stub `diff` vráti `'documents' => :unknown` pre Materiály bez lokálnych zmien | plán `'diff' => 'unknown'`, veta „Nepodarilo sa porovnať…", veta R17, voľba R-C4 s predvoleným preskočiť; potvrdenie bez zmeny voľby → `decisions['materials'][:action] == :skip` |
| U5/7 | `test_resolve_admin_from_menu` | `status['admin']` = `conflict`, kandidáti A, B (rovnaké `seq`) | „⋯" na oboch PC má „Ponechať správcu: A…" a „Ponechať správcu: B…"; klik A na PC B → potvrdenie → `lib_resolve_admin {pc_id: A}` → stub `resolve_admin!('A')` zavolaný **raz** → `lib_scan`; Odoslať na B sa nekreslí; mimo `conflict` položky nie sú |
| B | `test_attachment_conflict_result_text` | výsledok skupiny `attachment_conflict` `[{rel, label: 'Dub Halifax'}]`; iná skupina `taken` s `attachments.replaced: 2` | veta „Materiály sa neprevzali: vzhľad/list Dub Halifax sa líši…"; pri `taken` žiadny dovetok o prílohách |

- **Rez:** U5a +~15 riadkov (server drží `seen`, vetva `'unknown'`, `used` trojstav) → **~735**; poistka U5a ~780 platí. U5b bez zmeny (~470).
