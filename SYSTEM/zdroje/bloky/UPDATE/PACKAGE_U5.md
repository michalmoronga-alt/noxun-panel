# PACKAGE U5 · Okno O plugine, oznámenie a ikona aktualizácie (D-48) — blok UPDATE

> **Stav: NÁVRH — čaká audit návrhu (`codex-audit`)** · 17.10.2026 · do zásoby, **implementácia až po smoke PASS bloku 9 HARDENING** a po mergi U2, U3 a U4
> (poradie RECONCILE §3: U2 → U3 → U4 → U5; A2 B6: okno až po prílohách).
> **Autorita:** [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) — R3–R7, R13, R14, R16–R19, R21 a mockup **O1–O9** (záväzné) ·
> [MOCKUP_UPDATE_KNIZNICA.html](MOCKUP_UPDATE_KNIZNICA.html) (schválený bez úprav + rámik O9) · smer [RECONCILE_2026-10-17.md](RECONCILE_2026-10-17.md) §2 riadky „U5", §3 ·
> API **presne podľa** [PACKAGE_U2.md](PACKAGE_U2.md) R4.8 a [PACKAGE_U3.md](PACKAGE_U3.md) R-C, R-E, R-F, R-H, R-J, R-K, R-L, R-N · dôkazy
> [CROSS_AUDIT_A4_CLAUDE_KOD.md](CROSS_AUDIT_A4_CLAUDE_KOD.md) B4, B5, B6, B8, B11 · [CROSS_AUDIT_A2_GROK.md](CROSS_AUDIT_A2_GROK.md) B6 · A3 FIX 5. **PACKAGE_U4 zatiaľ neexistuje** — U5 od U4 nič nevolá (§6 R-U4).
> **Trieda Ť** (nové moduly + > 300 riadkov; výrobná/cenová — §5) · **rez U5a → U5b** (§2) · `codex-audit` · predrecenzia · export test P == K · ui_foto · smoke na oboch PC.
> **Stav kódu:** sonda nad `docs/update-start` `1468dfe2` (kód = `main` `a9e8c79d`, v0.18.1). U2–U4 v kóde ešte nie sú; riadky nižšie platia k tejto hlave.

---

## 0 · Sonda na kóde (skill `codex-audit`, krok 0) — 17.10.2026, len čítanie

Cesty relatívne k `noxun_engine/`.

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | „Okná knižníc" z O6 nie sú samostatné okná — sú to **sekcie Štúdia** `mat`, `hw`, `appl`, `tpl`, `bset`; plugin má len Inspector, Štúdio a Z-dialog nástrojov (guard počtu a mien okien) | `ui/js/studio_sections.js:80-116`; `HtmlDialog.new` len `ui/panel.rb:94`, `ui/studio_dialog.rb:1372`, `tools/mower.rb:409`; ui-lifecycle.md `### Satelitné okná` | PRAVDA → pruh O6 = riadok v lište sekcie, bariéra = zatvorenie Inspectora, Štúdia a Z-dialogu |
| S2 | Sekcia `about` = riadok registra s háčikom `enter: 'ssOnAboutEnter'`, kreslí ju `studio_settings.js`, markup `about.js` (`nxAboutHtml(info, updater)` — updater len v Štúdiu) | `studio_sections.js:117-121`; `ui/js/about.js:78-118`; `studio_settings.js:392`, `:504` | PRAVDA |
| S3 | Riadok registra má mechanizmus **badge** pri položke navigácie (`badge` → `navCounts` → `navBadgeHtml`) a **kotvu deep-linku** (`anchor: {fn, phase, miss}`) | `studio_sections.js:16-32`; `ui/js/studio.js:595-608`, `:1249` | PRAVDA → ikona O9 = nový druh badge `upd`; kotva `library` |
| S4 | Server sekcie `about` = `SupplierSettingsDialog`; akcie len z uzavretého whitelistu `SECTION_ACTIONS`; Štúdio ich zapája blokom per modul | `ui/supplier_settings_dialog.rb:50`, `:89-107`; `ui/studio_dialog.rb:1217` (vzor ďalších modulov `:731`, `:960`, `:1056`, `:1107`, `:1142`) | PRAVDA → nový modul `LibrarySyncDialog` so svojím whitelistom a blokom zapojenia |
| S5 | Payload `about` sa skladá pri **každom** pushi Štúdia a zámerne nesiaha na sieť/Disk (kontrola verzie je explicitná akcia) | `supplier_settings_dialog.rb:215-230` | PRAVDA → stav knižnice tiež len explicitnou akciou (sken vo vlákne), do payloadu ide len posledný doručený výsledok |
| S6 | Vzor asynchrónneho čítania: vlákno len súborové I/O, poll `UI.start_timer` 0,2 s, deadline 4 s, token (cesta, `StudioDialog.instance_token`, sekvencia), vlákno sa nezabíja, seamy `test_clock/test_spawn/test_schedule/test_notify` | `supplier_settings_dialog.rb:57-58`, `:85`, `:354-463`, `:748-765` | PRAVDA → U5 berie `TimedWorker` z U3 (R-E2) + rovnaké seamy |
| S7 | Bariéra: `close_plugin_dialogs` (Panel, Štúdio, Z-dialog) → poll `dialogs_closed?` (= dobehnutý `set_on_closed`, nie viditeľnosť) → limit 3 s → akcia; výsledok **natívne** (`UI.messagebox` cez `updater_message`) | `supplier_settings_dialog.rb:330-332`, `:548-589`, `:739-745`; `ui/panel.rb:67-69` | PRAVDA → ten istý vzor pre prevzatie (A4 B6) |
| S8 | Počas behu updatera sa okná neotvárajú (`Engine.update_in_progress?` vo vstupoch) | ui-lifecycle.md odsek `updater.rb`, „Bariéra pred swapom" | PRAVDA → rozšíriť o beh prevzatia (R-B5) |
| S9 | `StudioDialog.show(open_section:, anchor:)` existuje; Inspector ho volá cez `openStudio(section, anchor)` → callback `open_studio` | `studio_dialog.rb:136-143`; `ui/js/actions.js:11-17`; `ui/panel.rb:264`, `:328` | PRAVDA → klik z railu = `openStudio('about','library')` |
| S10 | Rail Inspectora: funkčná sekcia končí ikonou `eye` (Viditeľnosť tagov, `#railTagyBox`), pod ňou `railgap` + koliesko + Štúdio; bublina `.railtip`, nie `title` | `ui/panel.html:71-78`; UI_DIZAJN §5.1, §5.13 | PRAVDA → nové tlačidlo `#railUpd` hneď za `#railTagyBox` |
| S11 | Server → Inspector ide pushom `js("… NX.setX(...)")` (vzor `push_tags`, `push_grain_check`) | `ui/panel/sync.rb:168-172`, `:190` | PRAVDA |
| S12 | `UI::Notification` už plugin používa (referencia v `@note` kvôli GC, `Engine.extension`) | `tools/tools.rb:179-188` | PRAVDA → vzor pre O4 |
| S13 | Init pluginu (menu, toolbar, `Tools.install!`) beží v `main.rb` pod `init_allowed?` | `main.rb:605-614`, `:690-716` | PRAVDA → háčik kontroly pri štarte za `Tools.install!` |
| S14 | `Materials.used_material_ids(model)` = Hash `id => [kde]`, prechádza **aktívny model aj globálne šablóny** | `core/materials_catalog.rb:488-500` | PRAVDA → `used_ids` pre `materials` (A4 B5) |
| S15 | Pre spotrebiče **nie je** hotová funkcia „ID použité zákazkou"; zákazka odkazuje `catalog_id` v rozpočte | `core/budget_store.rb:506-507` (A4 B5); `core/appliance_binding.rb:261` | PRAVDA (presné čítanie **NEOVERENÉ** — R-D2) |
| S16 | Ikony v sprite: `cloud-download` (Pridať z Demosu, Aktualizovať plugin), `download` (export súboru), `refresh-cw` (Obnoviť), `rotate-ccw` (Vrátiť…), `more-horizontal` (⋯), `alert`, `info`; **nie je** `cloud-upload`, `user`, `clock` | `ui/js/icons.js` (kľúče); UI_DIZAJN §4 | PRAVDA → §6 R-I |
| S17 | Inventár ikon je úplný a strážený; nová ikona len keď nie je významovo správna existujúca | UI_DIZAJN §4 pätka; `tests/pure/test_docs_navigacia.rb` | PRAVDA |
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

**Príklad:** Lucia ráno spustí SketchUp → „Na Disku sú novšie knižnice: Materiály, Kovanie" → Otvoriť O plugine → Aktualizovať → okno: „Materiály verzia 14 (16.10. 18:42,
„nový dekor Pietra") · + 3 nové · ~ 12 zmenená cena · − Lucia biela 18 — **zmizne, používa ju otvorená zákazka**" · „Zmenia sa ceny v Materiáloch a Kovaní…" · vyberie
„Materiály zatiaľ preskočiť" → Aktualizovať → okná pluginu sa na chvíľu zavrú, prevezme sa Kovanie, hláška „Kovanie prevzaté · Materiály preskočené" a Štúdio sa znova
otvorí na O plugine s čerstvým stavom.

## 2 · Rez a odhad

| Časť | Obsah | Kód pluginu (odhad) | Testy | Odhad |
|---|---|---|---|---|
| **U5a · box a akcie** | `ui/library_sync_dialog.rb` (server boxu: sken, stav, Odoslať, príprava + potvrdenie Aktualizovať, bariéra, Vrátiť zálohu, správca, O7) · `about.js` box + `studio_settings.js` modaly Odoslať / Aktualizovať (R4) / Správca / Zálohy · CSS · zapojenie v `studio_dialog.rb` · vstupy okien počas behu | ~620 (Ruby ~330, JS ~240, CSS ~50) | ~550 | 2 dni |
| **U5b · oznámenia a história** | História a Vrátiť verziu (správca) · `ui/update_notice.rb` (kontrola pri štarte: knižnica + plugin R21, `UI::Notification` O4, stav ikony) · badge `upd` v navigácii · `#railUpd` v Inspectore · pruh O6 v 5 sekciách | ~430 (Ruby ~170, JS ~200, CSS/HTML ~60) | ~400 | 1½ dňa |

Spolu ~1050 riadkov → nad ~600 → **delenie U5a / U5b** (brief). Jeden audit návrhu pre obe; každá vlastný PR z čerstvého `main`. U5a sama o sebe dáva Michalovi
a Lucii úplnú funkciu (Odoslať, Aktualizovať s R4, záloha a jej vrátenie); U5b pridá upozornenia, históriu a pruh. **Poistka:** U5a nad ~700 riadkov kódu pluginu →
implementátor zastaví a hlási (kandidát na presun: modal Zálohy do U5b, U5a ponúkne „Vrátiť zálohu" len v hláške `:failed_restore_failed`).

**Poradie commitov U5a:** (1) R0 charakterizácia · (2) server `LibrarySyncDialog` + zapojenie + headless testy · (3) box v `about.js` + JS stav · (4) modaly · (5) bariéra
a vstupy · (6) docs. **U5b:** (1) R0b · (2) `UpdateNotice` + háčik v `main.rb` · (3) badge + rail · (4) História · (5) pruh · (6) docs.

## 3 · Scope IN

R0 charakterizácia · R-A box a payload · R-B server, akcie a bariéra · R-C Aktualizovať a okno R4 · R-D použité záznamy otvorenej zákazky · R-E Odoslať (O8) ·
R-F správca a „⋯" (O2) · R-G kontrola pri štarte a oznámenie (O4, R21) · R-H ikona stiahnutia (O9) · R-I ikony a texty · R-J História, Vrátiť, zálohy (O5) ·
R-K pruh v sekciách (O6/R13) · R-L iná verzia pluginu (O7, R14, R18) · R-M dokumentácia.

## 4 · Scope OUT

Logika synchronizácie, Disk, manifest, správca na Disku, stavy skupín, diff (**U3** — U5 ich len zobrazuje) · prevzatie, zálohy, návrat, druhá inštancia, UNI, reset
stavu v pamäti (**U2**) · prílohy a fotky dekorov (**U4**) · názov zákazky v .skp (**U1**) · **„Odovzdať správcu…"** (O2 „neskôr" — položka sa **nekreslí**, UI_DIZAJN §5.15
„ovládač, ktorý by visel neaktívne celý blok, sa skryje") · zmena cesty koreňa v UI (U3 D9) · export lokálnych zmien Lucie správcovi (A4 B4 „neskôr") ·
zmrazenie rozpočtu zákazky (R17 mimo bloku) · párovanie seed spotrebičov (R16) · zmena D-52b aplikovania pluginu (ostáva, R-G len pridáva kontrolu pri štarte) ·
pruh v sekcii Pravidlá (O6 ho nemenuje — §12 D7).

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

  | `state` (U3) | Chip (trieda, text) |
  |---|---|
  | `current` | `ok` „aktuálne" |
  | `newer` | `new` „novšia na Disku" |
  | `local_changes` | správca: `loc` „neodoslané zmeny" · ostatní: `loc` „vlastné zmeny" |
  | `newer_and_local` | `new` + `loc` (oba) |
  | `never_taken` | `new` „ešte neprevzaté" |
  | `not_on_disk` | správca: `loc` „na Disku ešte nie je" · ostatní: `wait` „na Disku ešte nie je" |
  | `syncing` | `wait` „na Disku sa ešte synchronizuje" |
  | `broken` | `err` „verzia na Disku je poškodená" |
  | `plugin_newer_on_disk` / `plugin_older_on_disk` | `err` „iná verzia pluginu" (veta R-L) |
  | `pending` | `err` „prevzatie sa prerušilo" |
  | `head_conflict` | `err` „dve verzie s rovnakým číslom" |

  Chip `new` je výberová rodina (teal), `loc` jantár (`--nx-warn-bg-soft` / `--nx-warnchip-fg` / `--nx-warnchip-border`), `err` stavové `--nx-err-*`, `wait` `--nx-surface-sunken`.
  **Žiadny nový token** (§1 „Žiadna vizuálna zmena bez zámeru").
- **R-A4 akcie pod tabuľkou:** **Odoslať zmeny (N)** (`primary`, ikona `cloud-upload`, len správca — R-E) · **Aktualizovať** (`ghostbtn`, `cloud-download`) · vpravo stavová
  veta `#libNote` (napr. „Aktualizovať netreba — na Disku nie je nič novšie." / „Odosiela len správca (MICHAL-PC)."). Nedostupné tlačidlo = `aria-disabled` + `title`
  s dôvodom (D-78), **nikdy** `disabled`; klik pri `aria-disabled` napíše dôvod do `#libNote` a nič neodošle (§1).
- **R-A5 koliesko Inspectora box nekreslí** (Š19 „jeden obsah, dva vstupy" platí pre logo/verziu; tlačidlá zapisujú → len Štúdio, rovnaký dôvod ako updater). Odsek `about.js`.
- **R-A6 payload:** `about_info` dostane kľúč `library` = **posledný doručený** výsledok skenu (`LibrarySyncDialog.last_payload`), nikdy nový sken (S5). Tvar:
  `{ 'state' => 'idle'|'checking'|'ready'|'busy', 'busy_op' => nil|'send'|'take'|'revert'|'restore'|'claim', 'disk' => U3 R-E1, 'disk_text', 'root',
  'admin' => {'state' => U3 R-C2, 'pc_name', 'self' => bool}, 'last' => {'at','note','by_pc'}|nil, 'plugin' => {'current','disk','compatible' => bool,'reason'},
  'groups' => [{'key','label','state','disk_version','disk_at','note','local_version','local_changed' => bool,'can_send','can_take','reason'}],
  'send_count', 'can_send', 'can_take', 'send_reason', 'take_reason', 'foreign' => [mená], 'checked_at' }`. Texty chipov a viet skladá **klient** z kódov
  (vzor `nxUpdaterText`); vety výsledkov U2 R4.7 skladá **server** (prenáša bez úprav — U2 R4.7).

### R-B · Server boxu `Noxun::Engine::LibrarySyncDialog` (`ui/library_sync_dialog.rb`) a bariéra

- **R-B1 whitelist** `SECTION_ACTIONS = %w[lib_scan lib_send lib_take_prepare lib_take_commit lib_take_cancel lib_backups lib_backup_restore lib_claim_admin
  lib_history lib_revert]` (posledné dve U5b); zapojenie v `studio_dialog.rb` blokom vzoru `:1217`; `dispatch`/`with_client`/`js`/`set_status` **vzor S4** (vlastný sink,
  `ensure`). Volania mimo whitelistu → „Neznáma akcia knižnice."
- **R-B2 sken (`lib_scan`)**: volá ho háčik vstupu `ssOnAboutEnter` (spolu s `updater_check`), tlačidlo Obnoviť a dobeh každej akcie. Vo vlákne **len** `LibrarySync`
  sken z U3 (R-D1/R-F2 cez `TimedWorker.start('lib_scan:<root>')`, single-flight), poll `UI.start_timer` 0,2 s, deadline 4 s (U3 R-E3) → po `:done` na hlavnom vlákne
  `LibrarySync.status(scan, local:)` (U3 R-F1; `local` z `LibraryTransfer.export_group` per skupina) → `last_payload` → `push_library` (`js("SS.library(<json>)")`).
  `:timeout` → `disk: 'timeout'`, veta „Disk neodpovedal do 4 s — je pripojený?". **Token** (root, `StudioDialog.instance_token`, sekvencia) — neskorá/cudzia odpoveď
  sa zahodí (vzor S6). Seamy `test_clock/test_spawn/test_schedule/test_notify` (vzor S6).
- **R-B3 bariéra (A4 B6)** pre každú akciu, ktorá **zapisuje knižnice** (`lib_take_commit`, `lib_backup_restore`, `lib_revert`): `@lib_inflight = op` → zapamätať, ktoré okná
  boli otvorené → `close_plugin_dialogs` (Panel, Štúdio, Z-dialog — vzor S7) → poll `dialogs_closed?` (limit `LIB_BARRIER_S = 3.0`; po ňom zrušenie „Aktualizácia sa
  nespustila — okná pluginu sa nepodarilo zavrieť… Na disku sa nič nezmenilo.") → operácia U3/U2 **na hlavnom vlákne** → výsledok **natívne** (`UI.messagebox`,
  seam `test_notify`) → **znova otvoriť** okná, ktoré boli otvorené (Štúdio `show(open_section: 'about', anchor: 'library')`, Inspector `Panel.show`) → `lib_scan`.
  Dôvod zatvorenia: rozpísané hodnoty a revízie v JS sekcií (`save_library!`/`row_rev`, `SS` baseline) by po prevzatí uložili starý obsah (U2 §9 R9); zatvorené okno
  sa otvorí z čerstvých dát po `after_import!` (U2 R4.2 krok 6). **Spoločné primitívum:** `close_plugin_dialogs`/`dialogs_closed?` sa presunú zo `SupplierSettingsDialog`
  do `Engine.close_plugin_dialogs!`/`Engine.plugin_dialogs_closed?` (`main.rb` alebo `app_lifecycle.rb`) a updater ich volá odtiaľ — **bez zmeny správania** (R0.2, guard D-52b
  text — §12 D3).
- **R-B4 vstupy počas behu:** `Engine.update_in_progress?` vráti `true` aj pri `LibrarySyncDialog.inflight?` (jedna podmienka pre toolbar, `Panel.show`, `Panel.show_insert`,
  `StudioDialog.show`, menu) s hláškou „Prebieha aktualizácia knižnice — okná sa otvoria samy." Príznak uvoľňuje jediné miesto `lib_done!` (vzor `updater_done!`),
  ktoré aj znova otvorí okná (R-B3). Opätovné otvorenie z `lib_done!` ide **mimo** tejto brány (príznak sa zhodí pred `show`).
- **R-B5 single-flight a zámok:** druhá akcia počas `@lib_inflight` → „Iná akcia knižnice práve beží." bez zásahu. Medziprocesový zámok drží U3 (`library_sync.lock`,
  `:busy` R-B2 U3) — veta prenesená bez úprav.
- **R-B6 hlavné vlákno:** `LibraryTransfer.*`, `LibrarySync.status/diff/take_commit/publish_prepare/publish_finish/claim_admin!` a všetky `Sketchup.*`/`UI.*` **len**
  na hlavnom vlákne; vo vláknach len telá z U3 (`Remote.*`, `take_prepare`, `publish_run`) — guard nad zdrojom (vzor U3 R-E4).

### R-C · Aktualizovať a okno R4 (R4, R6, R16, R17, A4 B5/B8)

- **R-C1 klik** (len keď `can_take`): modal **„Aktualizovať knižnicu z Disku"** (D-15, `size: 'md'`, `busyLock: true`) otvorený hneď vo fáze „Pripravujem verziu z Disku…"
  (potvrdenie `aria-disabled`) → server `lib_take_prepare` → `LibrarySync.take_prepare(groups:)` vo vlákne (U3 R-J1; deadline 120 s, poll 0,25 s) — `groups` = skupiny
  so stavom `newer`, `newer_and_local`, `never_taken` → na hlavnom vlákne per skupina `LibrarySync.diff(g, ticket, used_ids:)` (U3 R-N1; `used_ids` R-D) → `SS.libTake(plan)`.
- **R-C2 plán** `{ 'ticket_id', 'groups' => [{'key','label','version','at','note','local_changed','state' (syncing/broken → len informácia, neprevezme sa),'diff' =>
  {entry_key => {added:[{id,label}], changed:[{id,label,fields}], removed:[{id,label,used}]}}, 'price_changed' => bool, 'dependents' => [labels]}] }`. Tiket drží server
  (`@lib_ticket = {id, ticket, dlg}`); klient posiela späť len `ticket_id` (vzor dokladu S6 — aplikuje sa len to, čo človek videl).
- **R-C3 telo okna** (`custom`, poradie podľa mockupu): veta „Na Disku sú novšie: Materiály (verzia 14 z 16.10. 18:42) a Kovanie (verzia 9)." + poznámka odoslania (O8)
  pod menom skupiny · pri skupine s lokálnymi zmenami jantárová veta (`--nx-modalwarn-fg`) „V Materiáloch máš vlastné zmeny, ktoré na Disku nie sú. Prevzatím sa prepíšu."
  · **„Čo sa zmení v <skupina>"**: „+ N nové (prvé 3 mená, …)" · „~ N zmenená cena" / „~ N zmenené" · **„− <meno> — zmizne"**; zmiznutý záznam s `used` = červený
  tučný riadok s dovetkom „**používa ho otvorená zákazka**" (+ kde, ak `used_ids` nesie miesto) — **vždy vypísaný celý**, nezbalený (A4 B5: nič sa nemaže bez zoznamu).
  Zoznam dlhší ako 8 riadkov per skupina sa zbalí na „… a ďalších N" **okrem** riadkov s `used`. · **Veta R17** (keď niektorá skupina `price_changed`): „Zmenia sa ceny
  v <skupiny> — najbližší rozpočet pôjde podľa nového cenníka." · prvé pripojenie (`never_taken`, R16): „Tvoja knižnica sa nahradí Michalovou; doterajšia ostane ako záloha."
- **R-C4 voľba per skupina s lokálnymi zmenami** (segmentový prepínač `.segrow` — §1 „jedna voľba z N", nie rádiá): **„Prepísať — moja verzia sa uloží ako záloha
  (dá sa vrátiť v História)"** (`:overwrite`) / **„<Skupina> zatiaľ preskočiť — pošli zmeny správcovi"** (`:skip`). **Predvolená = preskočiť** (bezpečnejšia — §12 D4).
  Skupina bez lokálnych zmien = `:take` bez voľby. Preskočenie skupiny, od ktorej iná prevzatá závisí (`LibraryRegistry.dependents`, U2 R1.3) → jantárová veta
  „Šablóny odkazujú na Materiály — kým Materiály preskočíš, niektoré šablóny môžu ukazovať na záznamy, ktoré u teba nie sú." (A4 B8; varovanie, nie blokovanie — U2 R4.2).
- **R-C5 potvrdenie** „Aktualizovať" (`primary`; pri všetkých `:skip` `aria-disabled` „Nie je čo prevziať") → `lib_take_commit {ticket_id, decisions}` → bariéra R-B3 →
  `LibrarySync.take_commit(ticket, decisions:, plugins_dir: Engine.plugin_dir)` (U3 R-J2) → natívna hláška: riadok per skupina z R-J4 (`taken` „prevzaté (verzia N)",
  `skipped` „preskočené", `skipped_changed` „preskočené — medzitým si ich zmenila", `syncing`, `broken`, `plugin_mismatch`, kódy U2 vetou U2) + pri
  `:failed_restore_failed` veta „Otvor O plugine → ⋯ → História a vráť zálohu <dátum>." + pri `:other_instance*` „Zavri ostatné okná SketchUpu a skús znova."
- **R-C6 zrušenie** (Zrušiť, Esc, krížik vo fáze plánu) → `lib_take_cancel` → U3 staging sa zahodí (`take_prepare` tiket; upratanie U3 R-J4). Vo fáze prípravy je okno
  zamknuté (`busyLock`) do odpovede servera v **každej** vetve vrátane výnimky (§5.12).
- **R-C7 stav `pending`** (U3 R-J5) → chip `err` + veta v `#libNote` „Prevzatie sa prerušilo — klikni Aktualizovať znova alebo vráť zálohu (⋯ → História)."

### R-D · Použité záznamy otvorenej zákazky (`used_ids` pre U3 R-N1, A4 B5)

- **R-D1** `LibrarySyncDialog.used_ids(model)` (hlavné vlákno, len čítanie, žiadna operácia) → `{ entry_key => {id => [kde]} }`:
  `materials` ← `Materials.used_material_ids(model)` (S14; zahŕňa aj globálne šablóny — dovetok „používa ho otvorená zákazka alebo šablóna");
- **R-D2** `appliances` ← `catalog_id` položiek spotrebičov v rozpočte zákazky (`BudgetStore`, S15) — implementátor pred písaním **sondou** overí čítaciu funkciu
  (bez zápisu); nenájdená → `appliances` bez `used` + poznámka v PR. Kovanie, šablóny, dodávateľ: bez `used` (kovanie a spotrebiče v zákazke chráni snapshot — A4 D;
  šablóny a sadzby zákazka neodkazuje ID). Žiadny model (prázdne okno) → `{}`.
- **R-D3** zlyhanie `used_ids` → `{}` + log; okno vtedy povie „Nepodarilo sa zistiť, čo používa otvorená zákazka" (nikdy tichá prázdna množina).

### R-E · Odoslať s poznámkou (O8, R3, R18)

- **R-E1 tlačidlo** kreslené len pri `admin.self` (inde sa nekreslí — Lucia ho nevidí, mockup). `aria-disabled` s dôvodom pri `send_count == 0` („Všetko je rovnaké ako
  na Disku"), `admin.state == conflict` (R19 veta R-F3), R18 (`send_reason` z U3 R-G2), stave Disku ≠ `ok`/`empty`.
- **R-E2 modal** „Odoslať knižnicu na Disk" (D-15, `memoryKey: 'lib:send'`): veta „Odošlú sa zmenené: Materiály (verzia 15) a Šablóny (verzia 7). Ostatné sú rovnaké
  ako na Disku." · pole **„Poznámka pre Luciu (nepovinná)"** (`text`, max 200 znakov — U3 R-A5; klientsky orez + serverová kontrola) · Zrušiť / **Odoslať** (`primary`).
- **R-E3 beh:** `lib_send {note}` → `LibrarySync.publish_prepare(groups: <predvolené U3 R-H1>, note:)` (hlavné vlákno) → `publish_run(ticket)` vo vlákne (deadline 180 s)
  → `publish_finish` → modal sa zatvorí až po odpovedi servera (§5.12), výsledok per skupina do `#libNote` (`sent` · `failed` „odoslanie neprešlo, skús znova" · `skipped`)
  → `lib_scan`. **Bez bariéry** (odoslanie knižnice nemení). Neuložené rozpísané hodnoty v sekciách sa neodosielajú — odosiela sa uložený stav (veta v `title` tlačidla).

### R-F · Správca a ponuka „⋯" (O2, R3, R19, U3 R-C)

- **R-F1 „Toto PC je správca knižnice…"** kreslí sa **len** pri `admin.state == none` a Disku `ok`/`empty` (mockup: kým nikto; Lucia ponuku „stať sa správcom" po založení
  nevidí). Potvrdenie D-15 bez polí: „Toto PC (<COMPUTERNAME>) bude jediné, ktoré smie odosielať knižnicu na Disk. Druhé PC bude len aktualizovať." → `lib_claim_admin`
  → `LibrarySync.claim_admin!` (U3 R-C3; zápis na H: — §12 D5) → `lib_scan`. Výsledok `conflict` → veta R-F3.
- **R-F2** „Odovzdať správcu…" sa **nekreslí** (Scope OUT).
- **R-F3 dvaja správcovia (R19):** veta v riadku Správca (jantár): „Na Disku sú zapísaní dvaja správcovia — odosielanie je vypnuté na oboch PC. Ozvi sa Michalovi
  (ručné riešenie)." Aktualizovať ide ďalej. `mismatch` (Disk menuje toto PC, lokálne nie / naopak) → „Toto PC nie je potvrdené ako správca — odosielanie vypnuté."
- **R-F4 ďalšie položky „⋯":** **„História a návrat…"** (U5b; `rotate-ccw`) · **„Zálohy pred prepisom…"** (U5a; `rotate-ccw`, len keď `LibraryTransfer.backups` nie je prázdne).
  Ponuka je overlay pod spúšťačom, Escape zavrie len ju (§1).

### R-G · Kontrola pri štarte a oznámenie (O4, R7, R21, A3 FIX 5) — U5b

- **R-G1 modul `Noxun::Engine::UpdateNotice`** (`ui/update_notice.rb`): stav `{ 'libs' => [labels skupín newer/newer_and_local/never_taken], 'plugin' => 'x.y.z'|nil,
  'checked_at' }`; `start!` (raz na proces), `state`, `apply_library(payload)` (volá ho aj `LibrarySyncDialog` po každom skene a akcii — jedna pravda pre ikonu),
  `apply_plugin(state, available)` (volá ho aj `SupplierSettingsDialog.deliver_updater_check` — 1 riadok), `broadcast!` (push do Štúdia a Inspectora, R-H).
- **R-G2 háčik** v `main.rb` za `Tools.install!` (S13): `UI.start_timer(8, false) { UpdateNotice.start! }` — oneskorenie, aby kontrola nebrzdila otvorenie modelu.
  `start!` spustí **dva** behy cez `TimedWorker` (U3 R-E2): sken knižnice (`LibrarySync.startup_check` — U3 R-F2, nič nesťahuje) a **kontrolu pluginu**
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
- **Nová ikona: `cloud-upload`** (Lucide, pár k `cloud-download`) — Odoslať zmeny; riadok do inventára §4 (guard S17). **Bez** `user`, `clock`, `disk` z mockupu —
  položky ponuky a riadky `.inforow` sú text (§12 D6).
- Texty bez žargónu (§1): „Disk", „správca", „verzia", „záloha"; nie „head", „manifest", „seed", „sync". Verzia „v0.19.0" (malé v).

### R-J · História, Vrátiť verziu, zálohy (O5, R5, U3 R-K/R-L, U2 R4.3)

- **R-J1 (U5a) modal „Zálohy pred prepisom"** (D-15, `custom`): zoznam `LibraryTransfer.backups` (najnovšia navrchu, max 5 na skupinu — U2 §12 D4): skupina · dátum · dôvod ·
  verzia pluginu · **„Vrátiť zálohu"** (`rotate-ccw`). Záloha z inej verzie pluginu alebo `:broken` → `aria-disabled` s dôvodom. Klik → potvrdenie D-15 bez polí
  (`danger: false`): „Vrátiť <skupina> na stav z <dátum>? Súčasný stav sa najprv uloží ako ďalšia záloha." → `lib_backup_restore {backup_id}` → bariéra R-B3 →
  `LibraryTransfer.restore_backup!(id, plugins_dir:)` pod zámkom U3 (R-K) → natívna veta U2 → `lib_scan`. `entry` U3 sa nemení (U3 R-K) → skupina ukáže „vlastné zmeny".
- **R-J2 (U5b) modal „História knižnice — <skupina>"**: výber skupiny segmentom (5), tabuľka **Verzia · Kedy · Poznámka · PC · Plugin** (U3 R-L1/R-D5; PC a plugin = U3 N4)
  · aktuálna verzia označená „aktuálna" · pri ostatných **„Vrátiť"** (`rotate-ccw`) **len pri `admin.self`**; inde sa nekreslí. Veta pod tabuľkou: „Vrátenie odošle obsah
  zvolenej verzie ako novú verziu N+1 — Lucia ju dostane bežným Aktualizovať." Pod ňou „Tvoje zálohy pred prepisom" = R-J1 (jeden zoznam, nie dva).
- **R-J3 Vrátiť verziu** → potvrdenie s poznámkou (predvyplnená „Návrat na verziu K z <dátum>", U3 R-L2) → `lib_revert {group, version_id, note}` → bariéra R-B3 (lokálne
  prevzatie) → `LibrarySync.revert!` (U3 R-L2; vlákno/hlavné vlákno podľa U3) → natívna veta → `lib_scan`.

### R-K · Pruh v sekciách knižníc (O6, R13) — U5b

- **R-K1** sekcie `mat`, `hw`, `tpl`, `appl`, `bset` (S1): **jeden jantárový riadok** navrchu tela sekcie (`.libbar`: `--nx-warn-bg-soft`, `--nx-warnchip-fg`,
  `--nx-warnchip-border`, ikona `alert`): „Knižnicu spravuje <PC správcu> — tvoje zmeny tu sa pri Aktualizovať prepíšu. Pošli ich správcovi." **Kreslí sa len** pri
  `admin.state ∈ {other, mismatch}` (existuje správca a nie je to toto PC; §12 D7). Na PC správcu ani bez správcu sa nekreslí.
- **R-K2** jedna funkcia `nxLibBarHtml(upd)` (v `about.js` alebo `studio_settings.js`) volaná z kreslenia tela týchto 5 sekcií cez register — vlastnosť riadku
  `libbar: true` v `studio_sections.js` (nie vetva podľa id; guard H14a). Dáta = `admin` z `last_payload`/`UpdateNotice` v payloade Štúdia (bez nového skenu).
- **R-K3** pruh je **stavová veta** (§1 — nie tooltip), jeden riadok, dlhý text výpustka + plný text v `title`. Úpravy v sekciách ostávajú povolené (R13 „ostáva").

### R-L · Iná verzia pluginu (O7, R14, R18)

- **R-L1** keď U3 vráti pre aspoň jednu skupinu `plugin_newer_on_disk`: jantárová veta v boxe (nad tabuľkou, `.warnline`, `alert`): „Knižnica na Disku je z **v0.19.1**,
  máš **v0.19.0** — najprv aktualizuj plugin (box vyššie). Odoslať aj Aktualizovať čakajú." Obe tlačidlá `aria-disabled` s rovnakým dôvodom.
- **R-L2** `plugin_older_on_disk`: „Knižnica na Disku je zo staršieho pluginu (v0.18.9) — správca ju po aktualizácii pluginu odošle znova." (Aktualizovať čaká, U3 R-G1.)
- **R-L3** Odoslať odmietnuté podľa R18 (`send_reason` U3 R-G2: novší plugin na Disku / správcova verzia ešte nie je v distribúcii / distribúcia nečitateľná) — veta
  v `title` a `#libNote`, text zo servera (U3).

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
| 4 | Visiaci H: počas skenu pri štarte | brzdenie SketchUpu | sken len vo vlákne, oneskorenie 8 s, ticho pri timeoute |
| 5 | `claim_admin!` zapisuje na H: na hlavnom vlákne | krátke zamrznutie | §12 D5 (vlákno v U3 alebo prijaté) |
| 6 | Ikona O9 svieti „falošne" (napr. `never_taken` u Michala pred prvým odoslaním) | zbytočné upozornenie | `never_taken` sa počíta len keď na Disku verzia je; u správcu sa `not_on_disk` neráta |
| 7 | API U2/U3/U4 sa pri implementácii zmení | rozpor mien | U5 štartuje až po mergi U4; zmena mien = zladenie package pred štartom |
| 8 | Dlhý zoznam zmien v R4 | neprehľadné okno | zbaľovanie > 8 okrem `used`, karta `md` so scrollom tela |

## 10 · Smoke checklist pre Michala (oba PC, po U5a; body 9–12 po U5b)

1. **Tvoje PC:** Štúdio → O plugine → pod aktualizáciou pluginu box **Zdieľaná knižnica**: Disk „pripojený", Správca „nikto", 5 riadkov.
2. „⋯" → **Toto PC je správca knižnice…** → potvrď → Správca „<tvoje PC> (toto PC)"; tlačidlo **Odoslať zmeny (5)**.
3. Odoslať → poznámka „prvé odoslanie" → Odoslať → všetky riadky „aktuálne", Posledné odoslanie s dátumom a poznámkou.
4. **Luciino PC:** O plugine → Správca „<tvoje PC>", riadky „ešte neprevzaté", **žiadne** Odoslať ani „Toto PC je správca".
5. Aktualizovať → okno povie, že jej knižnica sa nahradí tvojou a ostane záloha; skontroluj, či vidíš zoznam zmien a pri materiáloch, ktoré má otvorená zákazka, červené
   „používa ho otvorená zákazka". Pre Materiály zvoľ **preskočiť**, potvrď → okná sa zavrú, hláška „Kovanie prevzaté … Materiály preskočené", Štúdio sa otvorí na O plugine.
6. Znova Aktualizovať → Materiály **Prepísať** → po hláške: Materiály „aktuálne", v Materiáloch tvoje dekory **s fotkami a vzhľadmi**.
7. „⋯" → Zálohy pred prepisom → je tam jej záloha Materiálov; **nevracaj** (len pozri).
8. **Tvoje PC:** zmeň cenu jednej dosky → riadok Materiály „neodoslané zmeny", Odoslať zmeny (1) → odošli s poznámkou → na Luciinom PC Obnoviť stav → „novšia na Disku" + poznámka.
9. **Luciino PC:** zatvor a spusti SketchUp → do ~10 s oznámenie „Na Disku sú novšie knižnice: Materiály" → Otvoriť O plugine → Štúdio otvorené rovno na boxe.
10. Pri „O plugine" v navigácii a v lište Inspectora pod okom **ikona stiahnutia**; po Aktualizovať zmizne. Klik na ikonu v Inspectore otvorí Štúdio na boxe.
11. **Luciino PC:** Štúdio → Materiály (aj Kovanie, Šablóny, Spotrebiče, Nastavenia rozpočtu) → jantárový pruh „Knižnicu spravuje <tvoje PC>…". Na tvojom PC pruh nie je.
12. **Tvoje PC:** ⋯ → História a návrat… → Materiály → pri predošlej verzii **Vrátiť** → na Luciinom PC Aktualizovať → cena dosky je späť.
13. Hláška „nepodarilo sa", zaseknuté okno alebo chýbajúce okno po aktualizácii → nahlás (napíš, na ktorom PC a ktorý krok).

## 11 · Checklist uzáveru (U5a aj U5b zvlášť)

Bump **patch** (`noxun_engine.rb` + `main.rb`) + všetky `?v=` · testy zelené (§7) · export test **P == K** v PR · ui_foto hárok v PR · odseky R-M na mieste + **Grep tvrdení
o zoznamoch**: inventár ikon §4, `SECTION_ACTIONS` v komentároch, zoznam účastníkov bariéry („Ďalšie účastníky bariéry"), zoznam vstupov s `update_in_progress?`,
druhy `badge` v hlavičke `studio_sections.js`, rail §5.1 · `SYSTEM/STAV.md` prepis · KRONIKA navrch · PLAN riadok U5a/U5b ✅ + `PR #?` → commit s číslom ·
**DOGFOODING D-48 → `DOGFOODING_vyriesene.md`** (plný text + PR + riadok navrch INDEXU) **až s U5b** (U5a ho nechá otvorený) · predrecenzia v PR popise.
**Po U5b nasleduje uzáver bloku UPDATE** (minor, `release/UPDATE`, smoke §10 na oboch PC).

## 12 · Rozhodnutia autora na potvrdenie orchestrátorom

- **D1 výrobná/cenová áno** (konzistentne s U2 D1 a U3b D1): nový ovládač prepisuje katalógy s cenami; dôkaz = export test P == K.
- **D2 rez U5a / U5b** (U5a = úplná funkcia vrátane zálohy, U5b = upozornenia, história, pruh); jeden audit.
- **D3 presun `close_plugin_dialogs`/`dialogs_closed?` do `Engine`** — jedna bariéra pre updater aj knižnicu; guard D-52b pripína text `updater_worker` (U3 S11), nie
  tieto metódy — implementátor overí guardy `test_d52b_updater_ui.rb` pred presunom; ak pripínajú, ostane delegácia zo `SupplierSettingsDialog`.
- **D4 predvolená voľba R4 = preskočiť** (mockup kreslí „Prepísať" ako prvú voľbu bez predvoľby; preskočiť je bezpečnejšie pre zákazky).
- **D5 `claim_admin!` na hlavnom vlákne** (U3 R-C3 neurčuje vlákno; zápis jedného malého súboru na zrkadlený H: je lokálny) — alternatíva: U3 dá `claim_admin_run` do `TimedWorker`.
  Odporúčam doplniť do PACKAGE_U3 pred U3b.
- **D6 bez ikon `user`, `clock`, `disk`** z mockupu — mockup kreslí ikony pri položkách „⋯" a riadku Disk; UI_DIZAJN §4 pripúšťa novú ikonu len s významom, ktorý nemá
  existujúca. Položky ponuky dostanú `rotate-ccw` (história/návrat) a text bez ikony (správca). Jediná nová ikona `cloud-upload`.
- **D7 pruh len pri `other`/`mismatch`** (R13 „PC, ktoré nie je správca" — pri `none` nikto nespravuje, pruh by klamal). Sekcia **Pravidlá** (ABS pravidlá len na čítanie,
  pravidlá kovania patria skupine Kovanie) pruh **nedostane** — O6 ju nemenuje („O6 doslova"); pravidlá kovania sa pritom prevzatím Kovania prepíšu.
- **D8 `used_ids`** len pre materiály a spotrebiče (R-D2); kovanie chráni snapshot (A4 D).
- **D9 kontrola pluginu pri štarte** (R21 bez nej nejde) mení zapísanú hranicu updatera „žiadny auto-check" — len zobrazenie, aplikovanie ostáva klikom.
- **D10 znovuotvorenie okien po bariére** — Štúdio na `about`/`library`, Inspector len ak bol otvorený; hláška natívne pred znovuotvorením (vzor updatera — v zatvorenom okne by sa nedala ukázať).
- **D11 nesúlad mien `meta` medzi U2 a U3:** U2 R4.5 `update_sync_meta!` pozná kľúče `pc_id`, `drive_root`, `admin`; PACKAGE_U3 R-B1 píše `pc_id`, `root`, `admin_claimed`.
  U5 `meta` priamo nečíta (berie `admin`/`root` zo `status` U3) — zladiť v PACKAGE_U3 pred U3b (mimo U5).

## 13 · Otázky pre Michala

**Žiadne nevyhnutné.** Ak orchestrátor nepotvrdí D4 alebo D7: „Má byť pri vlastných zmenách predvolené Preskočiť alebo Prepísať?" · „Pruh aj v sekcii Pravidlá?"

## 14 · Nálezy mimo scope

- **N1:** mockup O2 kreslí „Toto PC je správca" ako `onlyL` a „Odovzdať správcu" ako `onlyM` — ilustrácia stavu po založení; package kreslí podľa `admin.state` (R-F1), nie podľa PC.
- **N2:** kontrola pluginu v O plugine (`supplier_settings_dialog.rb:380-404`) a `UpdateNotice` majú dva behy toho istého `Updater.check` — po U5b zjednotiť na `TimedWorker` (U3 N1).
- **N3:** `Debug.report` (F10) + `UpdateNotice.state` a `LibrarySyncDialog.last_payload` — porovnanie PC Michal/Lucia pri smoke.
- **N4:** export lokálnych zmien Lucie správcovi (A4 B4 „neskôr") — prirodzený ďalší krok po bloku (napr. „Poslať správcovi" v pruhu O6).
- **N5:** `used_material_ids` zahŕňa aj globálne šablóny — vhodný kandidát na rozlíšenie „zákazka" vs. „šablóna" pre presnejšiu vetu R4.
