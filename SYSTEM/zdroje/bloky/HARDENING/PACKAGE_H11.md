# PACKAGE H11 · minimum SketchUp 2026 (H11b) + príprava na SketchUp 2026.2 (H11a) — blok 9 HARDENING PO V1

> **PLATÍ (1.10.2026, po Codex audite návrhu: 2 BLOCKER · 5 FIX · 2 NOTE — zapracované, §15):** dávka je **rozrezaná** — **H11b (F-02) ide PRVÁ**, samostatne;
> **H11a (F-01) je „príprava na 2026.2"**: **netvrdí, že pád odstraňuje** — F-01 sa uzavrie až izolovaným overením na 2026.2 (quit test §A6 + smoke), dovtedy ostáva
> otvorené v PLAN (riadok **H11c**). Obal načítania stojí na Ruby `require` s absolútnou cestou (nie na návratovej hodnote `Sketchup.require`) a jeho pokračovanie
> **rozhoduje sonda P1** (brána, nie INFO). Jediná podporovaná obnova po chybe súboru = **reštart SketchUpu**.

> *(Odkazy počítajú s umiestnením v `SYSTEM/zdroje/bloky/HARDENING/`.)*
> **Autorita:** triedenie [ROZHODNUTIA_MICHALA_2026-10-01.md](ROZHODNUTIA_MICHALA_2026-10-01.md) **F-01** (RA-02), **F-02** (RA-05; Michal 1.10.: Lucia má tú istú 2026)
> · rešerš [CROSS_AUDIT_A7_RESERS_SKETCHUP_API.md](CROSS_AUDIT_A7_RESERS_SKETCHUP_API.md) · surový audit `AUDIT_H11_raw.md` · PLAN blok 9, riadok **H11**.
> **Stav kódu:** sonda nad `main` **`6723421b`** (po H9). Riadky = stav k nemu; orientuj sa podľa mien metód. **Verzia:** každé PR = patch +1 od mainu v čase dávky + všetky `?v=` + prepis STAV.

---

## 0 · Sonda pred auditom (skill `codex-audit`, krok 0) — 1.10.2026

Skripty v scratchpade `HARDENING/h11_probe/` (`probe_h11_main.rb`, `probe_h11_loader.rb`, `probe_h11_ghost.rb`, `probe_h11_kernel_require.rb`, stuby `stubs/`), kópie repa
`h11_base/`, `h11_proto/` (`git archive 6723421b`; repo ani `%APPDATA%` sa nedotkli). **Živý SketchUp sondovaný NEBOL** (MCP `vbo-sketchup` `ECONNREFUSED`) — preto P1/P2.

| # | Tvrdenie | Príkaz / zdroj | Výsledok | Súbor:riadok |
|---|---|---|---|---|
| S1 | Plugin má **3** `set_on_closed` hooky | `grep` | Inspector, Štúdio, Z-dialóg (ostatné výskyty = komentáre) | `ui/panel.rb:113-123` · `ui/studio_dialog.rb:1357-1377` · `tools/mower.rb:420` |
| S2 | Hook **Inspectora** volá SketchUp API | čítanie + `probe_h11_ghost.rb` | `detach_observer` (2× `remove_observer`) · `HoverEdge.release` (`overlays.remove`, `view.invalidate`) · `GhostTool.cancel_session` → synchrónne `view.lock_inference` (kreslenie), `view.invalidate`, `UI.start_timer(0)`, `Panel.push_ghost` (`execute_script`); **v timeri** `model.tools.pop_tool` · `@dialog = nil` | `panel.rb:113-123`; `ghost_tool.rb:200-224,334-375`; `hover_edge.rb:97-108`; `selection.rb:71-80`; `sync.rb:599-603` |
| S3–S4 | Hook **Štúdia**; Z-dialóg | čítanie | Štúdio: `detach_stale_observer` (`model.remove_observer`) + čisté Ruby resety (`@ready`, `*_full_pending`, tri `on_ui_closed`) + `@dialog = nil`. Z-dialóg: len `@dialog = nil` — bez zmeny | `studio_dialog.rb:348-360`; `materials_dialog.rb:160-167`; `hardware_catalog_dialog.rb:154-159`; `appliance_dialog.rb:372-390` |
| S5 | Ukončenie dnes plugin **nerozpoznáva** | `grep onQuit\|onUnloadExtension\|onExtensionsLoaded` = 0 | AppObservery majú len `onNewModel/onOpenModel/onActivateModel` | `selection.rb:569-600`; `scale_observer.rb:951-990` |
| S6 | Jediný oficiálny signál = **`AppObserver#onQuit`** (SU 6.0) | https://ruby.sketchup.com/Sketchup/AppObserver.html | docs: „called when SketchUp closes", **poradie voči oknám negarantuje**. Komunita (nie oficiálne): `onQuit` až po dialógu „uložiť?", ukončenie sa už zrušiť nedá, model môže byť nedostupný | https://forums.sketchup.com/t/modify-and-save-the-model-when-sketchup-is-closed/233779 · https://forums.sketchup.com/t/get-value-from-webdialog-during-appobserver-onquit/63471 |
| S7 | Pád **#1117** | `gh api …/issues/1117` | otvorený od 24.9.2026, SU 26.2.243: `set_on_closed { pop_tool }` + ukončenie = bugsplat; samotné zatvorenie okna nepadá; pop v AppObserveri pred ukončením nepadá (iné miesto volania — **nie dôkaz poradia**). Trimble Jira SKEXT-5517 | https://github.com/SketchUp/api-issue-tracker/issues/1117 |
| S8 | 2026.2: `on_close` pri ukončení; `Sketchup.require/load` prepúšťa výnimky a `LoadError` | release notes, API docs | do 2026.2 výnimku zachytil, vypísal, pokračoval; `Returns: True if included. False if not` | https://help.sketchup.com/en/current-release-notes · https://ruby.sketchup.com/Sketchup.html |
| S9 | **103** načítaní súborov pluginu, bez rescue | `grep -c` | `main.rb:449-545` = 89 · `panel.rb:358-371` = 14 vnorených | — |
| S10 | **Dôkaz problému** (stub `Sketchup.require`) | `probe_h11_main.rb` | semantika 2026.2: koniec na **33. z 89** (`core/abs_rules`), init sa nespustí · semantika 26.0: všetkých 89 a **init beží nad polovičným pluginom** | `main.rb:547-663` |
| S11 | Init obsahuje **zápisy do %APPDATA%** | čítanie | `boot_cutover!`, `ensure_uni_records!`, `ensure_drawer_uni!`, `ApplianceCatalog.assess!`, legacy cleanup — každý vo vlastnom `begin/rescue` | `main.rb:555-617` |
| S12 | **Ruby `require` s absolútnou cestou** má jednoznačnú semantiku | `probe_h11_kernel_require.rb` (Ruby 3.2.11) | ok → `true`, znova `false` (v `$LOADED_FEATURES`) · `raise` → `RuntimeError`, nie je načítaný, ďalší pokus skúsi znova · syntax → `SyntaxError` · chýbajúci → `LoadError` (oba `ScriptError`). **V SketchUpe 26.0 NEOVERENÉ → P1** | — |
| S13 | Šifrované `.rbe`/`.rbs` sa **nepoužívajú** | `find noxun_engine -name '*.rbe' -o -name '*.rbs'` = 0; inštalátor a aktualizátor kopírujú strom `.rb` | kontrakt sa môže zúžiť (NOTE 8) | `main.rb:447` (komentár o `.rbe`) |
| S14 | Loader **nekontroluje verziu** | `probe_h11_loader.rb` | `24.0.594`, `26.0.429` aj „bez metódy" → zaregistrovaný, lease zapísaný | `noxun_engine.rb:365-384` |
| S15 | Formát verzie | API docs + Ruby | `version_number` = `XXYZZZZZZZ`; `"26.0.429".to_i` = 26, `"abc".to_i` = 0. Živá hodnota NEOVERENÁ (A7: exe 26.0.429) → P2 | https://ruby.sketchup.com/Sketchup.html |
| S16 | **10 čistých verzijných poistiek** | `grep` + Overlay docs | `respond_to?(:enabled?)` 3× · `(:enabled=)` 4× · `(:overlay_id)` 3× — všetky **SketchUp 2023.0** | tabuľka B-R2; https://ruby.sketchup.com/Sketchup/Overlay.html |
| S17 | **Ich odstránenie nič nerozbije** | prototyp `h11_proto`, plná headless sada | **base 5039 / 0 / 1 skip = proto 5039 / 0 / 1** | `h11_*_suite_out.txt` |
| S18 | Ostatné `respond_to?` **nie sú** verzijné poistky | čítanie | `respond_to?(:overlays)`, `defined?(Sketchup::Overlay)` v `available?` = šev headless sady; `persistent_id/lock_inference/folder/…` = duck typing. Texty „vyžaduje SketchUp 2023" testujú JS sady → §14 N1 | `edge_overlay.rb:8-14`; `shell.js:382,410,863`; `studio.js:997` |
| S19 | **Klik po zatvorení Inspectora** | čítanie | `onLButtonDown` → `live_session` (= `GhostTool.session`, rovnaký objekt, `active?`) → `commit_session`. Zneplatnenie session **čistým Ruby** (`cancel!` + uvoľnenie slotu) commit zablokuje; `PlacementSession#cancel!` je čistý Ruby. Esc → `onCancel` → `cancel_session(deferred: true)` → pop cez timer | `ghost_tool.rb:2057-2073,2302-2307,1664-1670,1978-1988` |
| S20 | 8 testov tvrdí doslovný `Sketchup.require '…'`; 2 testy čítajú hooky regexom po prvý `end` na 10 medzerách | `grep` | `test_doc_key.rb:546,548` · `test_nastroje1b_legacy.rb:435` · `test_s1b2_pohlad.rb:804` · `test_sheet_layout.rb:636` · `test_st1a_core.rb:85,86` · `test_st1a_studio.rb:1173` · `test_st4a_nastavenia.rb:65`; hooky: `test_ghost_vkladanie.rb:660-668`, `test_st1a_studio.rb:1102-1106` | — |
| S21 | In-SU: `set_on_closed` je asynchrónny; zatvorenie Inspectora počas ghostu dnes netestuje nikto | čítanie, `grep` = 0 | scenár čaká `SETTLE` | `su_runner.rb:19177-19178,19266-19290` |
| S22 | Runner `-CloseWhenDone` končí `Sketchup.quit`; po celej sade **0xC0000374** pri teardowne; sondy s malým modelom (aj s oknami, prekrytiami, nástrojmi) **exit 0** | čítanie | krátky quit test môže požadovať exit 0 | `run_su_tests.ps1:14-36,185-280` |
| S23 | Inštalátor: cieľ `SketchUp 2026`, inak **najnovší** `SketchUp YYYY` (aj 2024); `NOXUN_INSTALL_DEST` obchádza výber; nemá `param` blok; CI = `ubuntu-latest` | čítanie | na Michalovom PC je plugin len v 2026 | `INSTALL_noxun_engine.ps1:16-45`; `.github/workflows/*.yml:8` |
| S24 | Guardy, ktoré H11 rešpektuje | čítanie | `module Boot` bez `Sketchup.`; `Boot.recover!(` pred `register_extension`; VERSION v hlavičke loadera; nový core súbor = nadpis v mape + riadok routera; mapa ≤ 400 znakov/riadok, `ui-lifecycle.md` ≤ 330 kB (dnes 257), čísla PR len v „## História" | `test_d52a_updater.rb:1545-1570`; `test_docs_navigacia.rb:52-75,264-350` |

---

## 1 · Rez a poradie

| Dávka | Obsah | Trieda | Odhad |
|---|---|---|---|
| **H11b (PRVÁ)** | F-02: minimum 2026 v loaderi, 10 poistiek preč, inštalátor ≥ 2026 s funkčným testom, pravidlá | kódová, **nie audit-povinná** (návrh prešiel týmto auditom) | **~0,4 dňa** |
| **H11a** | F-01 príprava: príznak ukončovania, hooky bez API + odložené upratanie, poistka popu, quit test, obal načítania + bootstrap | **audit-povinná** (observer lifecycle, nový modul) | **~1,5 dňa** → voliteľný rez **H11a-1** (ukončovanie, §A2 R1–R6, quit test) / **H11a-2** (načítanie, R7–R9) |
| **H11c (otvorené)** | uzáver F-01: quit test + smoke na 2026.2; kód len ak vyjde poradie B (záložný návrh Z1) | podľa výsledku | po aktualizácii |

---

# ČASŤ I — H11b · minimum SketchUp 2026 (F-02)

## B1 · Cieľ
Starší SketchUp ako 2026 dostane **jednu hlášku** a plugin sa v ňom nenačíta (nič na disku sa nezmení); 10 mŕtvych poistiek preč; pravidlá a inštalátor hovoria 2026.

## B2 · Scope IN / OUT
**IN:** loader (B-R1) · `core/edge_check.rb`, `grain_check.rb`, `direction_check.rb`, `hover_edge.rb` (B-R2) · `INSTALL_noxun_engine.ps1` (B-R3) · `docs/SKETCHUP_PRAVIDLA.md`, odseky
`updater.rb` a overlay modulov (B-R4) · testy. **OUT:** všetko z H11a · texty a vetvy „SketchUp 2023" (§14 N1) · preferencia inštalátora 2026 pred novším ročníkom (vedome ostáva).

## B3 · Trieda
Kódová dávka. **Audit:** nie je povinný (nemení dátový kontrakt, schému, observer ani nepridáva modul; nový boot stav loadera prešiel týmto auditom).
**Výrobná/cenová:** nie. **In-SU:** nie je brána podľa CLAUDE.md (žiadny spúšťač) — **P2 je však povinná** (MCP `execute_ruby` alebo jeden beh runnera; overlay sekcie D-104/K2/KOV-A2b/H3b
ako regresia). **Predrecenzia:** nepovinná (< 300 riadkov, žiadny ovládač); **odporúčaná** — loader je vstup celého pluginu.

## B4 · Požiadavky
- **B-R1 Loader (`noxun_engine.rb`).** `MIN_SKETCHUP_MAJOR = 26`; kontrola **mimo `module Boot`** (S24), vyhodnotená **PRED `Boot.recover!`**: nepodporovaný = žiadna recovery,
  žiadny lease/lock, žiadna registrácia, `Boot.status = :unsupported`, `announce` s novou správou. Major = úvodné celé číslo z `Sketchup.version` (`>= 26` prejde aj 27+).
  **Fail-open:** chýba `Sketchup`/`version`, výnimka, major 0 → podporovaný + riadok logu `verziu SketchUpu sa nepodarilo zistiť` (vzor `generation_matches?`; d52a stuby bez
  `version` prejdú). `Boot.recover!(` ostáva textovo pred `register_extension`; VERSION v hlavičke. Text (návrh): *„Noxun Engine potrebuje SketchUp 2026 alebo novší. Tento
  SketchUp je verzia `<verzia>` — plugin sa v ňom zámerne nenačítal. Otvor SketchUp 2026."*
- **B-R2 Poistky (dôkaz: Overlay docs 2023.0 pre všetky tri metódy + minimum B-R1 + S17):**

| Súbor:riadok | Dnes → po | Prečo bez zmeny na 2026 |
|---|---|---|
| `edge_check.rb:453` · `grain_check.rb:288` · `direction_check.rb:555` | `!@overlay.respond_to?(:enabled?) \|\| @overlay.enabled? == true` → `@overlay.enabled? == true` | `@overlay` je vždy náš `Sketchup::Overlay`; `respond_to?` vždy true; chyba ide do existujúceho `rescue → false` |
| `edge_check.rb:516` · `grain_check.rb:344` · `direction_check.rb:612` · `hover_edge.rb:189` | `ov.enabled = true if ov.respond_to?(:enabled=)` → `ov.enabled = true` | `ov` = práve vytvorený `Sketchup::Overlay`; okolitý `begin/rescue` s logom ostáva |
| `edge_check.rb:603` · `grain_check.rb:428` · `direction_check.rb:705` | `next unless o.respond_to?(:overlay_id) && …` → `next unless o.overlay_id.to_s == OVERLAY_ID` | `OverlaysManager` drží len `Sketchup::Overlay`; okolitý `rescue → log` ostáva; P2 overí reálny zoznam |

  Komentáre pri riadkoch prepísať (minimum 2026). `available?`, `respond_to?(:overlays)`, `defined?(Sketchup::Overlay)` **ostávajú** (S18).
- **B-R3 Inštalátor.** Výber cieľa do funkcie bez spätných lomiek v cestách (vnorené `Join-Path`, aby bežal aj `pwsh` na CI) + `param([switch]$ResolveOnly)`: vypíše
  zvolený cieľ a skončí (0 / 1) **bez kopírovania**. Pravidlá: existuje `SketchUp 2026` → 2026 (vedome prednosť, aj keď existuje novší) · inak najnovší `SketchUp YYYY`
  s **YYYY ≥ 2026** · inak chyba s vetou „Noxun Engine potrebuje SketchUp 2026 alebo novší" · `NOXUN_INSTALL_DEST` = testovacia poistka **bez kontroly ročníka** (zdokumentovať).
- **B-R4 Dokumentácia.** `SKETCHUP_PRAVIDLA.md:35` → CEF 137 (2026.0); `:59` → **minimum SketchUp 2026 (Ruby 3.2, CEF 137); loader staršiu odmietne; API z 2026.1/2026.2 len za
  `respond_to?`**. Odsek `updater.rb` (`ui-lifecycle.md`): boot stav `:unsupported`, poradie gate → recovery. Odseky `edge_check.rb`/`hover_edge.rb` (construction.md) bez verzijných poistiek.
  `ARCHITEKTURA.md` „Reťaz načítania": minimum v loaderi.

## B5 · Testy, mutácie, DoD
- **T-B1 loader subprocess** (`tests/pure/test_h11b_minimum.rb`, harness podľa `test_d52a_updater.rb:280-312`): `Sketchup.version` = `24.0.594`, `25.0.660` → nezaregistrovaný,
  `:unsupported`, hláška s „2026" a verziou, **lease ani lock súbor nevznikol** · `26.0.429`, `26.2.243`, `27.0.1` → zaregistrovaný · bez metódy, `"abc"`, `""`, metóda vyhodí →
  zaregistrovaný + log. **Všetky existujúce d52a testy bez zmeny.**
- **T-B2** v štyroch overlay súboroch nie je `respond_to?(:enabled?)`, `(:enabled=)`, `(:overlay_id)`.
- **T-B3 inštalátor funkčne** (`pwsh`, inak `powershell`; ak nie je ani jeden, `NxTest.skip` s dôvodom — CI `ubuntu-latest` má `pwsh` podľa GitHub runner images, NEOVERENÉ v repe):
  dočasný `APPDATA` s priečinkami `SketchUp YYYY/SketchUp/Plugins` + `-ResolveOnly`: {2024, 2026, 2027} → 2026 · {2024, 2027} → 2027 · {2022, 2024} → exit 1 + veta · {} → exit 1 ·
  `NOXUN_INSTALL_DEST` → presne tá cesta. Existujúci `test_nastroje1b_legacy.rb` zelený.
- **P2 (povinná, SketchUp 26.0):** `Sketchup.version` (zapísať), `model.overlays.to_a.all? { |o| o.respond_to?(:overlay_id) && o.respond_to?(:enabled?) }` so štyrmi zapnutými
  prekrytiami → true; zapnutie/vypnutie všetkých štyroch funguje.
- **Mutácie:** MB1 gate `> 26` (T-B1 26.0.429) · MB2 fail-closed pri neznámej verzii (T-B1 + d52a) · MB3 gate po `recover!` (T-B1 lease) · MB4 gate vo vnútri `module Boot`
  (d52a guard) · MB5 späť `respond_to?(:enabled=)` (T-B2) · MB6 inštalátor bez filtra ≥ 2026 (T-B3 {2022, 2024}) · MB7 `NOXUN_INSTALL_DEST` ignorovaný (T-B3).
- **DoD:** headless + všetky JS sady + encoding guard zelené · P2 zapísaná v PR · mutácie MB1–MB7 · overlay sekcie bez regresie.

## B6 · Uzáver H11b
Bump VERSION (2×) + `?v=` → testy → B-R4 na mieste → prepis STAV (minimum 2026; „H11a nasleduje") → KRONIKA → PLAN: riadok **H11b ✅ + PR**, riadky H11a a H11c ostávajú.

## B7 · Smoke H11b (Michal)
1. Spusti SketchUp 2026 → plugin naskočí ako vždy, žiadna nová hláška. 2. Zapni a vypni ABS kontrolu hrán, smer kresby, smer otvárania → kreslia ako predtým.
3. Aktualizácia cez „O plugine" alebo INSTALL prebehne ako vždy (inštalátor vypíše cieľ `SketchUp 2026`).

---

# ČASŤ II — H11a · príprava na SketchUp 2026.2 (F-01)

> **Táto dávka pád #1117 NEodstraňuje a netvrdí to** (BLOCKER 1): na 26.0 sa dá dokázať len to, že pri ohlásenom ukončovaní plugin nesiaha na SketchUp a že sa ručné
> zatvorenie okien nezmenilo. Či to na 2026.2 stačí, rozhodne **quit test (§A6) a smoke na 2026.2** v dávke **H11c**. PR, STAV, KRONIKA aj PLAN to píšu presne takto.

## A1 · Cieľ, scope, trieda
- **Cieľ:** (1) keď SketchUp ohlási ukončovanie (`onQuit`), hooky zatvorenia okien **nevolajú SketchUp API** — len zneplatnia stav v Ruby; ak sa ukáže, že SketchUp beží ďalej,
  odložené upratanie sa dokončí; (2) chyba v ktoromkoľvek súbore pluginu = **jedna hláška**, plugin vypnutý (Q1), rovnako na 26.0 aj 2026.2; (3) **krátky quit test** s vlastným verdiktom.
- **IN:** nový modul `core/app_lifecycle.rb`; `main.rb` (bootstrap, obal 89 súborov, init brána); `panel.rb` (14 súborov, hook, `ensure_dialog`); `studio_dialog.rb` (hook, `ensure_dialog`);
  `ghost_tool.rb` (`invalidate_session!`, poistka `pop_tool`, potvrdenie behu v kliku/Esc); quit test (`run_su_tests.ps1 -QuitProbe` + `tests/sketchup/su_quit_probe.rb`);
  in-SU sekcia `run_h11a_async`; testy; dokumentácia. **OUT:** `onUnloadExtension`/`onExtensionsLoaded` (§14), Z1, `Debug.report`, JS/HTML/CSS.
- **Trieda:** **audit-povinná** (AppObserver, hooky okien, nový modul, fail-closed init) · výrobná/cenová **nie** · **in-SU = brána** · **quit test = samostatná brána
  na 26.0** · **predrecenzia povinná** · pri zmene konceptu oproti tomuto package delta audit.

## A2 · Požiadavky — ukončovanie (H11a-1)

- **R1 Príznak a stopa (`AppLifecycle`, čistý Ruby):** `quitting?` · `mark_quitting!(source)` · `confirm_running!(reason, sync:)` (R4) · `reset_for_tests!` (v pluginu nikto, guard) ·
  `trace(event)` = posledných 50 udalostí v pamäti + volanie `trace_sink`, ak je nastavený (**len test**, v produkcii `nil`, žiadne IO). Udalosti: `on_quit`, `hook:<okno>:<normal|quitting>`,
  `pop:<executed|deferred>`, `deferred:<run|skip>:<label>`, `running:<reason>`.
- **R2 `QuitObserver#onQuit` = LEN Ruby stav** (FIX 4): `mark_quitting!('onQuit')` + `trace('on_quit')` v `begin/rescue` s logom (`puts`). **Žiadne** SketchUp API (model, výber,
  nástroje, prekrytia, pohľad, okná, `visible?`, timery, `messagebox`). Trieda pod `if defined?(Sketchup::AppObserver)` (vzor `edge_overlay.rb:14`).
- **R3 `install!(app: Sketchup, observer: nil)`** (FIX 5): idempotentné — **presne jedna** registrácia aj po opakovanom volaní (`remove_observer` → `add_observer`, referencia sa drží).
  `add_observer` vráti `false` alebo vyhodí → `false` + záznam chyby štartu `quit observer` → init sa **nespustí** (A4 R8). Observer sa dá podať (headless test).
- **R4 Odložené upratanie** (FIX 3): `defer_until_running(label, &blk)` pri `quitting?` uloží blok (čistý Ruby). `confirm_running!(reason, sync:)` pri `quitting?`: príznak preč,
  log + `trace`, bloky spustí — `sync: true` hneď (volá `ensure_dialog`, mimo Tool callbacku), `sync: false` cez `UI.start_timer(0)` (z Tool callbacku sa `pop_tool` volať nesmie);
  každý blok vo vlastnom `rescue` s logom; zoznam sa vyprázdni pred spustením. **Beh potvrdzujú len udalosti, ktoré pri ukončovaní neprídu:** otvorenie okna pluginu
  (`ensure_dialog` NOVÉHO okna Inspectora/Štúdia, `sync: true`) a **používateľský vstup sirotského ghost nástroja** — `onLButtonDown` a `onCancel` s `reason == 0` (Esc), `sync: false`.
  `deactivate`, `onMouseMove`, `resume` beh **nepotvrdzujú**.
- **R5 Hook Inspectora** (`panel.rb:113-123`):

```ruby
@dialog.set_on_closed do
  if AppLifecycle.quitting?        # 2026.2: on_close bezi aj pri ukonceni (pad #1117)
    AppLifecycle.trace('hook:inspector:quitting')
    orphan = GhostTool.invalidate_session!('zatvorený Inspector') if defined?(GhostTool)
    AppLifecycle.defer_until_running('Inspector') do
      detach_observer if @dialog.nil?                 # znovu otvoreny panel uz ma vlastne observery
      HoverEdge.release if defined?(HoverEdge)
      GhostTool.pop_tool(orphan) if orphan            # viazane na INSTANCIU, nie na vrch stacku
    end
  else
    AppLifecycle.trace('hook:inspector:normal')
    detach_observer
    HoverEdge.release if defined?(HoverEdge)
    GhostTool.cancel_session('zatvorený Inspector') if defined?(GhostTool)
  end
  @dialog = nil                    # VZDY — bariera aktualizatora (dialog_closed?) sa nemeni
end
```
  `else` vetva = **dnešné správanie bajtovo**. `ensure_dialog` NOVÉHO okna volá `AppLifecycle.confirm_running!('otvorený Inspector', sync: true)` **pred** vytvorením okna a `attach_observer`.
- **R6 `GhostTool`:** **`invalidate_session!(reason)`** = čistý Ruby (`s.cancel!`, uvoľnenie slotu ako v `cancel_session`), **bez** `view`, timera, `push_state`; vráti sirotský
  nástroj (`@active_tool`, ak je `attached?`). Po ňom `live_session` = `nil` → klik **necommitne** (S19). **`pop_tool(tool)`**: pri `quitting?` → `trace('pop:deferred')`,
  `defer_until_running('ghost pop') { pop_tool(tool) }`, `false` (nástroj sa nedetachuje); inak `trace('pop:executed')` tesne pred `model.tools.pop_tool`. **`Tool#onLButtonDown` a
  `Tool#onCancel(0)`**: ako prvé `AppLifecycle.confirm_running!('klik/Esc v nástroji', sync: false) if AppLifecycle.quitting?`. `cancel_session`, `end_tool`, `deactivate` sa nemenia.
- **R5b Hook Štúdia** (`studio_dialog.rb:1357-1377`): pri `quitting?` → `trace`, `defer_until_running('Štúdio') { detach_stale_observer if @dialog.nil? }`; inak dnešné
  `detach_stale_observer`. Čisté resety a `@dialog = nil` **vždy**. `ensure_dialog` NOVÉHO okna → `confirm_running!(…, sync: true)` pred `attach_stale_observer`.

**Matica (záväzná):**

| Situácia | Inspector | Štúdio | Ghost |
|---|---|---|---|
| ručné zatvorenie | dnes (`normal`) | dnes | ukončí sa, aktívny Výber |
| ukončenie 26.0 | hooky sa nevolajú (S8); `onQuit` len príznak | — | zanikne s procesom (ako dnes) |
| 2026.2, `onQuit` pred `on_close` | zneplatnenie v Ruby, upratanie odložené (nikdy nebeží) | odložené | žiadny pop |
| 2026.2, `on_close` pred `onQuit` (**NEOVERENÉ**) | dnešná cesta; pop v timeri sa odloží len ak timer príde po `onQuit` | dnešná | **nevyriešené** → quit test ho odhalí (`hook:…:normal` pred `on_quit`) → Z1 v H11c |
| `onQuit` bez skutočného ukončenia (**NEOVERENÉ**) | klik **necommitne**; klik / Esc / otvorenie okna potvrdí beh a dokončí upratanie | otvorenie okna dokončí | sirotský nástroj sa popne po potvrdení |

## A3 · Požiadavky — načítanie (H11a-2)

- **R7 `require_part(path, record: nil)`** (BLOCKER 2): načíta **Ruby `require` s absolútnou cestou** `<Plugins>/<path>.rb` (koreň z `__dir__` modulu) — rovnaká semantika
  na 26.0 aj 2026.2 (S12), nezávislá od návratu `Sketchup.require`. Zachytáva **`StandardError, ScriptError`** (nie `Exception`); `true`/`false` (= už načítaný) je úspech;
  výnimka = záznam `{path, class, message, backtrace(6)}` + okamžitý log; nikdy nevyhodí; pokračuje sa ďalším súborom (diagnostika celého rozsahu). **Kontrakt sa zužuje
  (NOTE 8):** plugin sa **nešifruje** — guard test: v `noxun_engine/` nie je `*.rbe`/`*.rbs`; pravidlo v `SKETCHUP_PRAVIDLA.md`. **Brána P1** (§A5): ak SketchUp 26.0 nedá
  semantiku S12, **obal sa odloží** (H11a-2 sa nemerguje), H11a-1 pokračuje.
- **R8 `main.rb`:** (a) **bootstrap s vlastnou chybovou vetvou** (FIX 7): `begin require <abs>/core/app_lifecycle; rescue StandardError, ScriptError` + kontrola sentinelu
  `AppLifecycle::LOADED` (posledný riadok súboru — dôkaz, že sa vykonal celý); pri chybe metóda v `module Engine` hore v `main.rb` (bez `AppLifecycle`) zaloguje, ukáže
  **jednu** hlášku *„Noxun Engine sa nenačítal — chýba alebo je poškodený základný súbor pluginu (core/app_lifecycle.rb). Reštartuj SketchUp; ak to nepomôže, nainštaluj plugin
  znova."* a **zvyšok `main.rb` sa nevykoná** (`if` okolo zoznamu aj initu). (b) 89 riadkov v tom istom poradí a s tými istými komentármi ako
  `AppLifecycle.require_part 'noxun_engine/…'`; `panel.rb:358-371` rovnako (14). (c) Init: `AppLifecycle.failed?` → `announce_failures!`, **žiadny** init (migrácie, menu,
  toolbar, observery); inak **prvý** krok `AppLifecycle.install!` — `false` → chyba štartu, `announce_failures!`, žiadny init (R3); potom dnešný init bez zmeny.
- **R9 Hláška a obnova** (FIX 6): **jediná podporovaná obnova = reštart SketchUpu** (ručný reload sa nepodporuje — `panel.rb` by v require cache zostal bez 14 závislostí).
  Text (návrh): *„Noxun Engine sa nenačítal celý — chyba v súbore `<prvý path>` (spolu N). Plugin je v tomto okne SketchUpu vypnutý, aby nepracoval s chýbajúcimi časťami.
  Podrobnosti sú v Ruby konzole. Reštartuj SketchUp; ak to nepomôže, nainštaluj plugin znova."* `announce_failures!` ukáže hlášku **raz**. Mechanicky upraviť 8 testov zo S20 (prefix).

## A4 · Dokumentácia H11a (na mieste, bez čísel PR v mape)
Nový odsek **`### app_lifecycle.rb`** v `ui-lifecycle.md` (sekcia „Okná — lifecycle", pododdiel „Zatvorenie okna vs. ukončenie SketchUpu" s maticou A2) + riadok Core v
`ARCHITEKTURA.md` + „Reťaz načítania" (bootstrap, obal, fail-closed init, reštart). Odseky na mieste: `ghost_tool.rb` (construction.md — `invalidate_session!`, poistka popu,
potvrdenie behu), „Observery panela". `SKETCHUP_PRAVIDLA.md`: súbory pluginu výhradne cez `AppLifecycle.require_part` (Ruby `require`, bez `.rbe`); `set_on_closed` od 2026.2
beží aj pri ukončení — pri `quitting?` žiadne SketchUp API, len `defer_until_running`.

## A5 · Testy, mutácie, DoD

**P1 — BRÁNA H11a-2 (in-SU, SketchUp 26.0, temp `%TEMP%\noxun_h11_<rand>`, NIKDY Plugins):** `AppLifecycle.require_part` nad `ok.rb`, `ok.rb` znova, `raise.rb`, `syntax.rb`,
chýbajúcim súborom, s `record:` vlastným poľom → presne S12 (ok true → false; raise/syntax/chýbajúci = záznam správnej triedy; globálny zoznam nezmenený). **FAIL ktoréhokoľvek
bodu = H11a-2 sa odkladá** (nie INFO). Do PR sa navyše zapíše surové správanie `Sketchup.require` pre tie isté súbory (len dokumentácia).

**T0 — charakterizácia PRED zásahom:** T0a headless `cancel_session('zatvorený Inspector')` nad fake modelom → synchrónne `view.invalidate` (+ `lock_inference` pri kreslení),
`UI.start_timer(0)`, v timeri `tools.pop_tool` 1× (vzor `probe_h11_ghost.rb`) · T0b = in-SU **Q1** na hlave mainu pred zmenou.

**Headless (`tests/pure/test_h11a_lifecycle.rb`, `test_h11a_nacitanie.rb`):**
- **T1** príznak, `trace` (strop 50, sink volaný len keď je nastavený), `reset_for_tests!` len v definícii.
- **T2** `invalidate_session!`: fake session `cancelled`, slot `nil`, fake view/tools **0 volaní**, vráti sirotský nástroj · `pop_tool` pri `quitting?` → 0× `tools.pop_tool`, odložený
  blok; `confirm_running!(sync: true)` → 1× pop · `sync: false` → cez stub `UI.start_timer`.
- **T3** `install!` s fake `app`: 3× `install!` → **1** registrovaný observer · `add_observer` → `false` → `install!` false + chyba štartu · `add_observer` vyhodí → to isté.
- **T4** `require_part` nad reálnymi súbormi v temp: `RuntimeError`, `NameError`, `SyntaxError`, `LoadError` → záznam, log, nevyhodí · ok/už načítaný → úspech · `Interrupt` prejde ·
  `record:` nezašpiní globálny zoznam · `announce_failures!` 2× → 1 messagebox; text obsahuje prvú cestu, počet, „Reštartuj SketchUp".
- **T5 subprocess `main.rb` nad dočasným stromom** (skutočný `main.rb` + `core/app_lifecycle.rb`, 89 maličkých stub súborov podľa zoznamu, stub `sketchup.rb` s `UI`,
  `file_loaded?`): (a) `core/abs_rules` vyhodí → všetkých 89 skúsených, **1** messagebox, init nebeží (žiadny log `boot_cutover`, `UI.menu` nevolané) · (b) syntax chyba → to isté ·
  (c) všetko ok → init beží, 0 messageboxov · (d) **bootstrap chýba** · (e) **bootstrap má syntax chybu** · (f) bootstrap bez sentinelu → v (d)–(f) 1 hláška o základnom súbore,
  **0** častí skúsených, init nebeží · (g) stub `Sketchup.add_observer` → `false` → hláška, init nebeží.
- **T6 statika:** každá cesta `require_part` existuje; v `noxun_engine/` nie je `Sketchup.require 'noxun_engine/`; zoznam 89 + 14 ciest a poradie = zmrazená kópia z `6723421b`;
  žiadne `*.rbe`/`*.rbs`.
- **T7 text:** hook Inspectora — v `quitting?` vetve len `trace`, `invalidate_session!`, `defer_until_running`; žiadny `pop_tool` v žiadnom `set_on_closed` mimo odloženého bloku;
  `@dialog = nil` mimo podmienky; Štúdio obdobne; telo `onQuit` bez `active_model`, `tools`, `overlays`, `selection`, `visible?`, `start_timer`, `messagebox`, `File`;
  `ensure_dialog` oboch okien volá `confirm_running!` pred vytvorením okna; `onLButtonDown` a `onCancel` volajú `confirm_running!` ako prvé; `install!` je prvý krok initu.
- **JS:** bez zmeny; spustiť všetky sady + encoding guard.

**In-SU `run_h11a_async` (BRÁNA; kópia ENGINEtests.skp, `-CloseWhenDone`):** východisko = Inspector + Štúdio otvorené, doska označená + `HoverEdge.show(model, 'L1')`, ghost visí
(`Panel.handle_insert(pg(model, GHOST_PARAMS))`), sonda undo stacku.
- **Q1 ručné zatvorenie (T0b):** zatvor obe → session `nil`, nástroj nie je `attached?`, aktívny `SelectionTool`/21022, overlay hrany preč, oba `@observer_model` `nil`, `dialog_closed?`.
- **Q2 ohlásené ukončovanie:** `mark_quitting!` → zatvor obe → `dialog_closed?`; session **zneplatnená** (`GhostTool.session` `nil`), nástroj **attached** (bez popu), overlay
  registrovaný, oba `@observer_model` nastavené, stopa `hook:inspector:quitting`, `hook:studio:quitting`.
- **Q3 klik po zatvorení** (z Q2): `tool.onLButtonDown` na položiteľnom bode → **0 nových skriniek, sonda undo stacku na vrchu**, `quitting?` false; po `SETTLE`: aktívny Výber,
  overlay preč, `@observer_model` `nil`.
- **Q4 Esc** (z Q2): `tool.onCancel(0, view)` → po `SETTLE` to isté ako Q3.
- **Q5 znovuotvorenie** (z Q2): `Panel.show` → v tom istom kroku sirota popnutá, overlay preč, nový panel má `@observer_model == model`, `quitting?` false; nový ghost sa zavesí a
  zruší normálne. To isté pre Štúdio.
- **Q6 timer po `onQuit`:** ghost visí, `mark_quitting!`, `GhostTool.end_tool(deferred: true)` → po `SETTLE` nástroj attached, stopa `pop:deferred`; `confirm_running!(…, sync: true)` → popnutý.
- **Q7** plugin načítaný celý: `AppLifecycle.failures.empty?`, observer zaregistrovaný. **Q8 = P1.** Regresie: celá sada vrátane D-52b async (bariéra), GHOST, overlay sekcií.

**Mutácie (každá zhodí aspoň jeden test; výsledok do PR):** M1 hook bez `quitting?` vetvy (T7, Q2) · M2 `quitting?` vetva bez `invalidate_session!` (Q3: klik commitne) ·
M3 odložený blok bez `if @dialog.nil?` (Q5: nový panel bez observera) · M4 `pop_tool` bez poistky (T2, Q6) · M5 `pop_tool` pri `quitting?` bez odloženia (Q4: sirota ostane) ·
M6 `confirm_running!` z `onMouseMove` (T7) · M7 `onQuit` číta `active_model` (T7) · M8 `install!` 2× registruje (T3) · M9 init beží pri `install!` false (T5g) ·
M10 `require_part` chytá len `StandardError` (T4) · M11 init beží pri chybách (T5a) · M12 bootstrap bez vlastnej vetvy (T5d/e) · M13 messagebox pri každej chybe (T4) ·
M14 `@dialog = nil` vo vnútri podmienky (T7, D-52b).

**DoD:** P1 PASS (alebo odklad H11a-2) · T0 zelené pred aj po · headless + JS + encoding guard · in-SU Q1–Q8 PASS · **quit test PASS na 26.0** · mutácie · predrecenzia bez P1/P2.

## A6 · Quit test — samostatný verdikt (FIX 4)
`scripts\run_su_tests.ps1 -QuitProbe` (zdieľa deploy lock a `run_*` priečinok; implikuje zatvorenie) načíta namiesto runnera krátky `tests/sketchup/su_quit_probe.rb`:
kópia ENGINEtests.skp → Inspector + Štúdio otvorené → ghost visí → `AppLifecycle.trace_sink` = append do `quit_trace.txt` v `run_*` → uloženie run-kópie (vzor `NoxunSuClose`) →
`Sketchup.quit`. Počas ukončovania sa zapisuje **len Ruby stav** (udalosti R1). PowerShell po zániku procesu (max 120 s, nikdy nezabíja) vyhodnotí:
- **PASS** = exit kód **0** · presne **1×** `on_quit` · **0×** `pop:executed` po `on_quit` · každý `hook:*` po `on_quit` má režim `quitting` · **žiadny** `hook:*:normal` medzi
  uložením kópie a `on_quit` (= poradie B). Na 26.0 sa `hook:*` neočakáva (S8) — ak príde, musí byť `quitting`.
- **FAIL** = iný exit kód **vrátane 0xC0000374** · proces nezanikol do 120 s · porušené pravidlo vyššie. Skript vráti 0/1 a vypíše `QUIT-TEST: PASS|FAIL` + stopu.
Celá regresná sada ostáva vo svojom dnešnom režime teardownu (S22).

## A7 · Riziká H11a
1. **Poradie B na 2026.2** (`on_close` pred `onQuit`) je mimo dosahu 26.0 — preto H11c. **Z1 (záložný návrh):** hook nástroj nikdy nepopne, len zneplatní session; nástroj sa ukončí
   sám pri najbližšom používateľskom vstupe (vzor `finish_self_soon`) — mení dnešné správanie (ghost zmizne až po pohybe/kliku), preto len ak quit test na 2026.2 zlyhá.
2. **Zaseknutý príznak** — ohraničený R4: klik necommitne, beh potvrdí klik/Esc/okno. Smoke krok 7 overí na 26.0, že `onQuit` pri zrušenom ukončení nepríde.
3. **Fail-closed** vypne celý plugin vrátane aktualizátora → obnova reštartom, inak reinštaláciou (Q1). Zmierňujú T6, CI, Q7.
4. **Ruby `require` namiesto `Sketchup.require`** — odklon od konvencie rodiny Noxun (dôvod: jednoznačná semantika na oboch verziách; šifrovanie sa nepoužíva). P1 ho overí v SketchUpe.
5. 103 mechanických riadkov stráži T6; 8 textových testov len prefix; messagebox pri štarte má precedens `Boot.announce`; limity mapy S24.

## A8 · Uzáver H11a
Bump + `?v=` → testy (+ P1, quit test 26.0) → A4 na mieste → **prepis STAV: „pripravené na 2026.2 — NEOVERENÉ do H11c"** → KRONIKA → PLAN: **H11a ✅ (príprava) + PR**,
riadok **H11c · overenie F-01 na 2026.2 (quit test + smoke)** ostáva otvorený. PR popis: čo sa zmenilo pre používateľa, P1, quit test 26.0, mutácie, predrecenzia, hlava in-SU.

## A9 · Smoke H11a (Michal, funkčne)
1. Štart SketchUpu 2026 → plugin naskočí, žiadna hláška. 2. Inspector → **Vložiť skrinku** → skrinka visí → zavri Inspector krížikom → skrinka z kurzora zmizne, kurzor = Výber.
3. To isté zatvorením **logom v toolbare**. 4. Hrana pod kurzorom v karte dielca → zavri Inspector → zvýraznenie zmizne. 5. Štúdio zavri a otvor → sekcie fungujú.
6. Otvorený Inspector aj Štúdio + skrinka na kurzore → **Súbor → Koniec** → bez chybového okna; nový štart normálny.
7. **Zrušené ukončenie:** zmeň niečo v modeli → **Súbor → Koniec** → v otázke „uložiť?" klikni **Zrušiť** → otvor Ruby konzolu: **nesmie** tam byť riadok „ukončovanie SketchUpu (onQuit)";
   potom Vložiť + zatvorenie Inspectora funguje ako v kroku 2.

## H11c · Overenie F-01 na 2026.2 (otvorené, po aktualizácii)
Aktualizácia ročníka 2026 sa zrejme inštaluje na miesto 26.0 (**NEOVERENÉ**) → urobiť v deň bez rozrobenej zákazky, Lucia v rovnakom čase (Q3), alebo na inom PC/VM.
Potom: quit test (§A6) **PASS na 2026.2** + smoke A9 krok 6 + in-SU scenáre D-40 (DC 1.8.5). PASS = F-01 uzavreté (register/PLAN/STAV); FAIL s `hook:*:normal` pred `on_quit` → Z1.

---

## 12 · Rozhodnutia autora

- **AR1** Ukončovanie len cez `onQuit` (jediný oficiálny signál, S6); `onQuit` mení len Ruby stav (FIX 4).
- **AR2** Pri ukončovaní hooky **oddeľujú** čisté zneplatnenie v Ruby (hneď) od SketchUp upratovania (odložené, dokončí sa po potvrdenom behu) — FIX 3.
- **AR3** Beh potvrdzujú len udalosti, ktoré pri ukončovaní neprídu (otvorenie okna, klik/Esc v sirotskom nástroji); `onMouseMove`/`deactivate` nie.
- **AR4** Vlastný `QuitObserver` v novom module, registrácia je **podmienkou** zapnutia UI (FIX 5); `scale_observer.rb` sa nemení.
- **AR5** Obal načítania cez **Ruby `require` s absolútnou cestou** — nezávisí od návratu `Sketchup.require` (BLOCKER 2); kontrakt bez `.rbe` (NOTE 8); P1 je brána.
- **AR6** Fail-closed init + načítať aj zvyšok kvôli diagnostike; obnova = reštart (FIX 6); bootstrap má vlastnú vetvu (FIX 7).
- **AR7** H11b samostatne a prvá; minimum v loaderi pred recovery, fail-open pri neznámej verzii; inštalátor ≥ 2026 a vedome prednosť 2026.
- **Zamietnuté:** jeden `begin/rescue` okolo zoznamu (na 26.0 by nezabral, na 2026.2 by skončil pri prvom súbore); odložiť celý hook do timera (rozbije bariéru D-52b);
  reload po oprave súboru (vlastný kontrakt pokusu — nepotrebný, keď stačí reštart); Z1 hneď (mení správanie bez dôkazu).

## 13 · Otázky pre Michala (produktové — dávky idú s predvoľbou)
- **Q1** Chyba v niektorom súbore pluginu: **vypnúť plugin v tom okne celý + jedna hláška, obnova reštartom** *(predvoľba; audit NOTE 9: opodstatnené zápismi pri štarte)*, alebo zapnúť čiastočne?
- **Q2** SketchUp starší ako 2026: **nenačítať + hláška** *(predvoľba)*, alebo načítať s varovaním? (Plugin je u teba len v 2026.)
- **Q3** Kedy aktualizuješ na 2026.2 (a Lucia)? Od toho závisí H11c.

## 14 · Nálezy mimo scope (návrhy)
- **N1** Nedosiahnuteľné texty „vyžaduje SketchUp 2023" a vetvy `available?` (S18) — preformulovať/odstrániť so stubmi a úpravou JS testov (`test_d104_kontrola_hran.js:66-68`,
  `test_k2_smer_kresby.js:91,126`, `test_kova2b_smer_overlay.js:139,168`, `test_st1b_kontrola.rb:241`).
- **N2** `onUnloadExtension` — vypnutie v Extension Manageri nechá bežať observery, prekrytia a okná. **N3** `onExtensionsLoaded` — odložiť ťažký boot.
- **N4** `Debug.report` doplniť o `AppLifecycle.failures`, `quitting?` a stopu (R1). **N5** `materials.md:301` veta o SU 2024 je bezpredmetná.
- **N6** F-05 `HtmlDialog#hide` až po minime 2026.1 a výsledku H11c. **N7** `ScaleWatch.sdi?` → `Sketchup.mdi?` (2026.2). **N8** D-40 po 2026.2 (súčasť H11c).
- **N9** Pád 0xC0000374 pri teardowne po celej sade (S22) — H11 ho nerieši. **N10** Inštalátor: keď príde SketchUp 2027, rozhodnúť, či má prednosť pred 2026.

## 15 · Audit návrhu — zapracovanie (Codex, 1.10.2026: 2 BLOCKER · 5 FIX · 2 NOTE)

| # | Nález | Zmena |
|---|---|---|
| 1 | BLOCKER: ochrana závisí od neovereného poradia; F-01 nesmie byť uzavreté na 26.0 | Rez §1; H11a = „príprava" (úvod ČASTI II, A8); uzáver F-01 až **H11c** (quit test PASS na 2026.2 + smoke); matica A2 priznáva poradie B ako nevyriešené; Z1 v A7 |
| 2 | BLOCKER: P1 povoľovala zahodiť detekciu na 26.0 | R7 — obal cez **Ruby `require`** (S12), nie návrat `Sketchup.require`; **P1 = brána** H11a-2 (FAIL → odklad, žiadne INFO); Q8 = P1 |
| 3 | FIX: zaseknutý príznak → klik commitne, Esc nevráti nástroj | R4 (`defer_until_running`/`confirm_running!`), R5, R5b, R6 (`invalidate_session!`, pop viazaný na inštanciu, potvrdenie behu klik/Esc/okno); Q3–Q6; smoke A9 krok 7; M2, M3, M5, M6 |
| 4 | FIX: Q7 robil API volania v `onQuit` a tolerovať 0xC0000374 | R2 (len Ruby stav), R1 `trace`/`trace_sink`; samostatný quit test **A6** s exit 0, stopou `on_quit`/hooky/pop; 0xC0000374 = FAIL; M7 |
| 5 | FIX: neúspešná registrácia observera nezastaví UI | R3 + R8c (registrácia = podmienka initu); T3 (3× install → 1 registrácia, `false`, výnimka), T5g; M8, M9; doručenie dokazuje quit test (1× `on_quit`) |
| 6 | FIX: sľúbený reload nefunguje | R9: jediná obnova = **reštart** (text hlášky, A4, `SKETCHUP_PRAVIDLA.md`); reload v zamietnutých (§12) |
| 7 | FIX: bootstrap bez chybovej vetvy | R8a (vlastná vetva + sentinel `LOADED`, hláška bez `AppLifecycle`); T5d–f; M12 |
| 8 | NOTE: `.rbe` vs. evidencia `.rb` | S13 (v repe 0 `.rbe`); kontrakt zúžený v R7 + guard T6 + pravidlo A4 |
| 9 | NOTE: trieda, Q1/Q2 a rozsah poistiek OK; inštalátor testovať funkčne | B-R3 `-ResolveOnly` + **T-B3** (vetvy 2026/novší/staršie/`NOXUN_INSTALL_DEST`); prednosť 2026 vedome (N10); Q1 predvoľba s odkazom na NOTE 9 |

---

## 16 · Delta audit (rola bežný audit a delta, 1.10.2026) — zapracovanie orchestrátorom · MÁ PREDNOSŤ

Výsledok delty: pôvodné 1–4, 6–9 RESOLVED, 5 PARTIAL; nové **0 BLOCKER · 4 FIX · 2 NOTE** (`AUDIT_H11_delta_raw.md`). Audit uzavretý po zapracovaní:
- **D1 (FIX, observer idempotentne):** `install!` — ak držaná referencia už bola úspešne pridaná, **vráť sa bez novej registrácie**; ak `remove_observer`
  vráti `false` alebo vyhodí výnimku pri preregistrácii, **zastav aktiváciu** (fail-closed, jedna hláška). Test: remove → false / výnimka; opakovaný
  `install!` = presne jedna registrácia (počítadlo doručení `onQuit` = 1).
- **D2 (FIX, syntax `main.rb`):** kontrakt sa **zužuje** na „ktorýkoľvek vnútorný súbor načítaný z validného `main.rb`"; chyba samotného `main.rb`
  ostáva v réžii SketchUpu (zapísať do dokumentácie a hlášky/komentára; žiadny nový entrypoint v tejto dávke).
- **D3 (FIX, quit test I/O):** trace sink počas ukončovania je **priznaná testovacia výnimka** (len v teste, nie v produkcii); zapisuje cez **vopred
  otvorený handle**, každá chyba sinku je úplne izolovaná (`rescue` bez vplyvu na tok); guard kontroluje, že produkčný `onQuit` nemá I/O.
- **D4 (FIX, `-ResolveOnly`):** resolve režim **nemá vedľajšie účinky** — cieľ len vypočíta, nevytvára adresár ani pri `NOXUN_INSTALL_DEST`
  (`New-Item` až mimo resolve vetvy); test s neexistujúcim override cieľom (adresár po behu neexistuje).
- **N5:** P1 zaznamená presný kľúč `$LOADED_FEATURES` a potvrdí, že updater/restart vždy začína v novom procese (dnes áno — reštart povinný).
- **N6 (H11b):** na kontrolu minima použi oficiálne číselné `Sketchup.version_number` (major = `version_number / 100_000_000` podľa dokumentácie —
  over sondou na 26.0.429), pri chybe fail-open (načítať); stringový major len ako fallback, ak by číselné API zlyhalo — dôvod do komentára.

**Potvrdenie orchestrátora:** rez **H11b → H11a (príprava) → H11c (otvorené do 2026.2)** platí. H11b smie ísť s predvolenou **Q2** (SketchUp < 2026 →
plugin sa nenačíta, jedna hláška; vratné, nemení dáta). **H11a čaká na Michalovu odpoveď Q1** (pri chybe súboru vypnúť celý plugin — predvoľba podľa
auditu NOTE 9) — ak neodpovie, H11a ide s predvoľbou, v PR označiť. Implementátor skopíruje package + `AUDIT_H11_raw.md` + `AUDIT_H11_delta_raw.md`
do `SYSTEM/zdroje/bloky/HARDENING/`.

---

## 17 · Výsledok H11a na 26.0 — rozhodnutie orchestrátora (2.10.2026) · MÁ PREDNOSŤ PRED ČASŤOU II

**Výsledok (SketchUp 26.0.429, quit test §A6 na implementácii H11a-1+2):** `Sketchup.quit` aj Súbor > Koniec (`send_action` 57665): stopa `hook:studio` · `hook:inspector` (pri `Sketchup.quit` niekedy aj `pop:executed` z timera) · **až potom** `on_quit`, exit kód **0**. SketchUp zatvára okná pluginu **pred** `AppObserver#onQuit`
(**poradie B**) — predpoklad S8 („na 26.0 sa hooky pri ukončení nevolajú") neplatí a príznak z `onQuit` by hooky pri ukončení nezachytil; H11a-1 by teda cieľ
nedosiahol. Brána P1 (Ruby `require` s absolútnou cestou) **PASS**; surové `Sketchup.require` na 26.0 pri raise aj syntax chybe vráti `true` (prehltne).

**Rozhodnutie orchestrátora — variant (b):**
- **H11a = len načítanie (H11a-2):** `core/app_lifecycle.rb` (`require_part`, `failures`, `announce_failures!`, sentinel `LOADED`), bootstrap v `main.rb`, 91 + 14
  súborov cez `require_part`, fail-closed init `Engine.init_allowed?` (Q1 — celý plugin vypnutý, jedna hláška, obnova reštartom). Kód H11a-1 (príznak z
  `onQuit`, `QuitObserver`, `install!`, stráže v hookoch okien, `invalidate_session!`, poistka `pop_tool`, potvrdenie behu) sa **nemerguje** — vrátený z vetvy.
  Ostáva **testovací nástroj quit testu** (`run_su_tests.ps1 -QuitProbe [-QuitMenu]`, `tests/sketchup/su_quit_probe.rb` s vlastnou inštrumentáciou) pre H11c.
- **H11c = záložný návrh Z1 + vlastný audit** (keď bude SketchUp 2026.2, Michal dá vedieť): hook nástroj nikdy nepopne, len zneplatní session; ghost sa ukončí sám
  pri najbližšom používateľskom vstupe (vzor `finish_self_soon`) — mení dnešné správanie, preto audit a mockup správania; poradie B je **potvrdené už na 26.0**.
  F-01 ostáva otvorené (AUDIT_REGISTER R-42).
