# PACKAGE H10 · Dve okná SketchUpu neprepíšu pravidlá kovania a rozmerové rady (R-35) — blok 9 HARDENING PO V1

> **Autorita:** `SYSTEM/AUDIT_REGISTER.md` R-35 (P2, „platí", PO V1 — Michal 30.9.2026) + riadok R-35 v tabuľke „Stav po previerke 29.9.2026"; podklad
> `SYSTEM/zdroje/PREVIERKA_REGISTRA_2026-09-29.md` (riadok R-35, poradie bod 2). Súvisí R-08 (zámok, ✅ #258) a R-11 (degradovaný súbor). Blok 9 (`SYSTEM/PLAN.md`):
> **bez zmeny výrobných a cenových čísel** — pri jednom okne sa pravidlá aj rady uložia bajtovo rovnako; mení sa len správanie pri súbehu.
> **REZ AKTÍVNY (§2, po audite):** **H10a · pravidlá kovania** (R1) → **H10b · rozmerové rady** (R2), každá vlastný PR z čerstvého `main`.
> **Trieda (§5):** obe **audit-povinné** (audit tohto package pokrýva obe — §15) · **nie výrobná/cenová** · **predrecenzia povinná** pri oboch · **in-SU = brána
> len H10a** · `codex-po-pr` bez výnimky.
> **Verzia:** každá časť patch podľa mainu pri štarte (dnes `0.17.0`) + **všetky `?v=`** (H10a `rules.js`, H10b `settings.js`) + prepis STAV.
> **Stav kódu:** sondy nad `main` **`b2dbb3a7`** (v0.17.0). Pred štartom overiť §5.1 (H9 mení `json_file_store.rb`).

---

## 0 · Sondy (skill `codex-audit`, krok 0) — 1.10.2026

Skripty v `scratchpad/HARDENING/`: `sonda_h10.rb`, `sonda_h10b.rb` (jadro), `sonda_h10c.rb` (dnešný `RulesDialog.handle_save` headless nad fake modelom),
`sonda_h10_js.js` (skutočný `rules.js` upravený **len v pamäti** cez `Module._compile`); výstupy `sonda_h10_out.txt`, `sonda_h10c_out.txt`, `sonda_h10_js_out.txt`.
Ruby beží cez `tests/helper.rb` (APPDATA = sandbox, skript sa bez neho zastaví). Do modelu, repa ani živého `%APPDATA%` sa nič nezapísalo.

### 0.1 Vzor, ktorý už existuje (sety + nastavenia dodávateľa)

| # | Tvrdenie | Dôkaz | Výsledok |
|---|---|---|---|
| V1 | **Sety:** `HardwareSets.revision` = SHA1 **surových bajtov** súboru (12 znakov) | `hardware_sets.rb:2085-2093`; sonda S1a | PRAVDA |
| V2 | Payload berie knižnicu aj revíziu z JEDNÉHO stavu pod zámkom (`load_with_revision`, poučenie R-08 audit #4) | `hardware_sets.rb:2103-2113`, `hardware_catalog_dialog.rb:492-502`; S1b | PRAVDA |
| V3 | Porovnanie **pod zámkom po `reload!`**: `next [:conflict, nil] if revision && revision != self.revision` | `hardware_sets.rb:2138-2146, 2259-2262, 2296-2299` | PRAVDA |
| V4 | Prázdna revízia `''` = **konflikt** (fail-closed); `nil` = kontrola sa preskočí (len interné volania); UI posiela vždy `.to_s` | S1c–S1g; `hardware_catalog_dialog.rb:780, 859, 1077` | PRAVDA |
| V5 | Klient revíziu **pripína** pri otvorení editora (R-41); po konflikte server pošle čerstvú (`resync_sets`): set → draft + „Obnoviť", mazanie → „obnovené, skús znova", mapovanie → draft zahodený | `hw_sets.js:1310-1314, 2443-2451, 750-753`; `hardware_catalog_dialog.rb:476-480, 794-801, 864-866, 1070-1087` | PRAVDA |
| V6 | **Dodávateľ:** `revision(sup)` = SHA1 **obsahu**; `patch_active!` porovná pod zámkom; `''` aj zastaraná = `:conflict`; okno: lacná kontrola + zámok končia `reject_stale`; pin `SS_BASE_REV` pri fokuse | `supplier_settings.rb:711-715, 752-771`; `supplier_settings_dialog.rb:243-293`; `studio_settings.js:20-32, 753-757`; S2a–S2c | PRAVDA |
| V7 | Pravidlá už majú **obsahový** odtlačok `rules_rev` (SHA1 kanonického JSON) — dnes LEN pre **projektové** pravidlá formulára | `hardware_rules.rb:2269-2293`; `rules_dialog.rb:114-141, 596-609` | PRAVDA |

### 0.2 Cesty zápisu `hardware_rules.json` a `dim_series.json`

| # | Tvrdenie | Dôkaz | Výsledok |
|---|---|---|---|
| W1 | Do `hardware_rules.json` zapisuje JEDINÉ miesto `HardwareRules.write` (pod zámkom; brány degradovaný → novší `std`). Volajú ho **3** cesty: `ensure_seeded`, `persist_seed_merge!` (obe pod zámkom, čerstvé čítanie, len dopĺňajú seed) a **`RulesDialog.handle_save` pri „aj ako globálnu predvoľbu"** — ÚPLNÁ NÁHRADA bez revízie | `hardware_rules.rb:663-672, 568-580, 684-695`; `rules_dialog.rb:644-657` | PRAVDA |
| W2 | Vloženie/stavba skrinky globál **neprepisuje** (`ensure_project_rules!` → len seed cesty W1) | `hardware_rules.rb:500-511, 781-795` | PRAVDA |
| W3 | Guardy `baseline_valid?` + `rules_rev` + `model_guid` chránia LEN projekt; pri projekte **so snapshotom** sa globál pred zápisom nekontroluje vôbec | `rules_dialog.rb:429-434, 542-610` | PRAVDA |
| W4 | „Načítať globálne" (`push_global`) plní formulár globálom bez revízie globálu | `rules_dialog.rb:485-488`; `rules.js:315-328` | PRAVDA |
| W5 | `rdApplyState` pri pushi s nezmenenými pravidlami prepíše celé `RD_META`; pri zmenených volá `rdSetState` (aj po uložení LEN do projektu, Späť, prepnutí dokumentu) | `rules.js:1298-1320`; `after_model_write` `rules_dialog.rb:1015-1023` | PRAVDA → pin mimo `RD_META` a mimo projektovej obnovy (R1.7) |
| W6 | Do `dim_series.json` zapisuje JEDINÉ miesto `DimSeries.set`; volá ho LEN `Panel.handle_set_dim_series`. Rady nemajú seed ani seed-merge | `dim_series.rb:105-111, 135-146`; `actions_settings.rb:35-53` | PRAVDA |
| W7 | Panel dostane rady LEN pri otvorení (`push_init`) a po vlastnom uložení / zmene témy; editor sa plní z tohto stavu a „Uložiť rady" posiela **všetkých 5 kľúčov** | `panel.rb:131`, `sync.rb:83`, `actions_settings.rb:57-75`; `settings.js:217-235, 252-267, 303-309` | PRAVDA |
| W8 | Guard R-08: v `hardware_rules.rb` aj `dim_series.rb` je **práve jeden** `JsonFileStore.write(`, v `write`/`set` pod zámkom | `test_r08_zamky.rb:434-454` | PRAVDA → nové metódy zapisujú cez `write`/`set` |
| W9 | `Materials.with_catalog_lock` je reentrantný | S8a | PRAVDA |
| W10 | R-11 test volá `handle_set_dim_series` bez pôvodných hodnôt a čaká dôvod degradácie | `test_r11_degradovana_zaloha.rb:433-445` | PRAVDA → poradie brán R2.2 |

### 0.3 Reprodukcia a vlastnosti revízie

| # | Tvrdenie | Príkaz | Výsledok |
|---|---|---|---|
| P1 | **Strata pravidiel:** A a B z tej istej knižnice; A vypne nohy, B vypne závesy; oba `write` → `true` | S3 | zmena A **zanikla bez slova** |
| P2 | **Strata radov:** B drží rady z otvorenia; A pridá 700 do šírok; B zmení len hĺbky (posiela 5 kľúčov) | S4 | 700 **zaniklo bez slova** |
| P3 | Identický prepis nemení `rules_rev` ani SHA bajtov | S5a | rovnaké |
| P4 | Seed-merge pri `load` mení **bajty**, nie obsahový `rules_rev`; `rules_rev(read_rules.first)` (bez zápisu) = `rules_rev(load)` | S5b, S5c | `e390be8ee002` = `e390be8ee002` |
| P5 | Poškodený primár bez `.bak` / chýbajúci súbor: `read_rules` vyhodí `ParserError`/`ENOENT`, `load` dá `SEED_RULES`; `rules_rev(SEED)` = `rules_rev(normalize(SEED))`; zápis prejde (samooprava R-11) | S6a–S6c, S5d | PRAVDA |
| P6 | `if :conflict` je v Ruby pravdivé | S7 | nová metóda, nie `write` |
| P7 | Cena `rules_rev(load)` 0,5 ms (cache) / 0,9 ms (disk) | S8b, S8c | zanedbateľné |
| P8 | `JsonFileStore.read` do 1 s vracia cache aj po cudzom zápise | S9; `json_file_store.rb:12-34` | pod zámkom a v predkontrole vždy `reload!` |

### 0.4 Sondy po audite (BLOCKER 1, FIX 2, FIX 4)

| # | Tvrdenie | Príkaz | Výsledok |
|---|---|---|---|
| J1 | **BLOCKER potvrdený:** pin pri KAŽDOM `rdSetState` (pôvodný návrh) → scenár A otvorí s G0 · B uloží G1 · A uloží len projekt · A „aj ako globálnu" pošle **G1** = bez konfliktu | `sonda_h10_js.js` variant A | „BEZ KONFLIKTU — G1 by sa ticho prepísal"; to isté po **Späť** |
| J2 | **Oprava funguje:** pin len pri prvom naplnení, pri zdroji `global` a na `RD.setGlobalRev` (R1.7) → ten istý scenár pošle **G0** → konflikt; aj po Späť | variant B | „KONFLIKT (správne)" v oboch |
| J3 | Variant B: projekt bez snapshotu (formulár **zobrazuje** globál) — push s G1 formulár prekreslí a pin smie ísť na G1; `RD.setGlobalRev('G1')` + pokojný push s G2 pin nechá G1 | variant B | správne |
| H1 | **FIX 2 potvrdený — závislosť od cache:** projekt bez snapshotu, B zapíše G1, A uloží „aj ako globálnu": **(a)** cache ešte drží G0 → dnes `baseline_valid?` prejde, projekt aj globál sa zapíšu → **G1 od B ticho zanikne**; **(b)** cache už vidí G1 → `baseline_valid?` zlyhá → deštruktívne echo, „formulár je načítaný nanovo" | `sonda_h10c.rb` F2a/F2b | (a) ops `[start, commit]`, globál nohy=`true`; (b) ops `[]`, hláška nanovo |
| H2 | **`handle_save` beží headless** nad fake modelom (`path`, `get/set_attribute`, `start/commit/abort_operation`) so stubmi `Panel.job_cabinets_split/job_cabinets/detached_skipped_tail` a `after_model_write`; `CabinetBuilder.rebuild_many(model, [], …)` otvorí aj zavrie operáciu | F4 | ops `[[:start, "NOXUN: pravidla kovania"], [:commit]]`, `after_model_write` 1× |
| H3 | **FIX 4 — deterministický súbeh je realizovateľný headless:** jednorazový hook pred globálnym zápisom (po prestavbe) zapíše cudzí globál; dnes ho `write` ticho prepíše | F4 | hook vystrelil, status „+ globálna predvoľba" |
| H4 | `push_section_echo` volá `Bom.collect(model)` — nad fake modelom zlyhá do `rescue` (echo sa nepošle); headless test echa preto overuje **hlášku a absenciu operácie**, prekreslenie formulára JS testom | F2b | echo(force) nezachytené, hláška áno |

**Opravené/upresnené tvrdenia oproti registru:** (1) revízia pravidiel je **obsahová** (`rules_rev`), nie SHA súboru (P4, D1). (2) Pri radoch nestačí „po kľúčoch bez
revízie" — ten istý rad by sa prebíjal ďalej (P2); zápis po kľúčoch **s pôvodnou hodnotou kľúča** (D7). (3) Seed cesty (W1) revíziu nepotrebujú (R-08).
(4) **Audit:** pin globálu sa nesmie posunúť projektovou obnovou formulára (J1/J2) a projekt bez snapshotu dnes závisí od cache (H1).

---

## 1 · Cieľ

Keď sú otvorené dve okná SketchUpu (dve zákazky) a v oboch sa menia **globálne predvoľby pravidiel kovania** („aj ako globálnu predvoľbu", alebo zákazka bez
vlastných pravidiel, ktorá ich preberá z globálu) alebo **rozmerové rady** (koliesko Inspectora), prvá zmena už **nezanikne bez slova**: druhé okno dostane jasnú
hlášku, nič neprepíše a rozpísané pravidlá **ostanú vo formulári**; rady menené v **rôznych** riadkoch sa zlúčia bez hlášky. Pri práci v jednom okne sa nič nemení.

## 2 · Rez a odhad — **REZ AKTÍVNY**

Po zapracovaní auditu narástla časť pravidiel (rozdelenie `baseline_valid?`, rozlíšená predkontrola so 6 výsledkami, súbeh po prestavbe, pravidlá pinu):
odhad spolu **~470–550 riadkov kódu pluginu s komentármi** (> ~400) → **rez:**

| Časť | Obsah | Kód pluginu | Testy | In-SU | Odhad |
|---|---|---|---|---|---|
| **H10a · pravidlá kovania** | R1 (`hardware_rules.rb` ~80, `rules_dialog.rb` ~170, `rules.js` ~40) | ~300–360 | ~450 | **brána** | ~1 deň |
| **H10b · rozmerové rady** | R2 (`dim_series.rb` ~60, `actions_settings.rb` ~40, `settings.js` ~50) | ~140–170 | ~250 | nie | ~½ dňa |

Poradie **H10a → H10b** (pravidlá menia nákup nových zákaziek — vyššie riziko). Časti nemajú spoločný kód; H10b štartuje z čerstvého `main` po mergi H10a.
Audit tohto package platí pre obe (FIX zapracované, §15) — nový audit len ak implementácia zmení kontrakt z §6.

## 3 · Scope IN

**H10a:** `core/hardware_rules.rb` (`library_check`, `library_revision`, `save_library!`, spoločná brána zápisu — R1.1–R1.2) · `ui/rules_dialog.rb` (`global_rev`
v payloade a pri „Načítať globálne", `baseline_state`, predkontrola, výsledok po prestavbe — R1.3–R1.6) · `ui/js/rules.js` (pin `RD_GLOBAL_REV`, `RD.setGlobalRev` —
R1.7) · testy, in-SU `run_h10a`, dokumentácia R3.
**H10b:** `core/dim_series.rb` (`update!`, `LABELS`, oprava komentára F1) · `ui/panel/actions_settings.rb` · `ui/js/settings.js` (pin `NXDIM_BASE`, `NXDim.changes`) ·
testy, dokumentácia R3.

## 4 · Scope OUT

- Formát súborov (`hardware_rules.json` `std` = 3, `dim_series.json` `std` = 1) — revízia sa počíta, neukladá; žiadna migrácia ani schéma.
- Seed cesty a `HardwareRules.write` / `DimSeries.set` ako interné API — správanie bez zmeny (D9; `write` len zdieľa čistú bránu, R1.1).
- Projektové `rules_rev`, `model_guid`, `rev_conflict_status`, sety, ABS pravidlá, dodávateľ — bez zmeny.
- **Staré procesy pluginu** (okno spustené pred aktualizáciou) — zapisujú bez revízie; rieši prevádzková podmienka (R1.9, §10), nie kód.
- Ochrana **novšieho formátu** rozmerových radov (neznáme kľúče, vyšší `std`) — dnešné obmedzenie, H10b ho len prizná (R2.7).
- F2, F3, F7 (§14). Nový ovládací prvok — žiadny.

## 5 · Trieda podľa CLAUDE.md

- **Audit-povinná: ÁNO (obe časti).** Mení sa UI kontrakt zápisu dvoch perzistentných globálnych súborov (`global_rev`, `base`, návratové kontrakty
  `save_library!`/`update!`, fail-closed pre starý DOM). Schéma sa nemení (D11), nový modul nevzniká.
- **Výrobná/cenová: NIE (hraničné).** Výpočet kovania ani obsah uložených pravidiel/radov sa pri jednom okne nemení (C1/C2 bajtovo); globál platí len pre
  **nové** projekty (STANDARD §6); v konflikte sa nezapíše nič a povie sa to. Príklady hraníc B-09 (H1, PR #433, ak je zmergované): nie vzorec, rozmer, počet,
  `row_key` ani export. **Golden sady** (`test_kova_golden.rb`, `test_kovh_golden.rb`) dokazujú len nezmenené výpočty — **nový ukladací tok dokazujú výhradne testy
  §7 (T-A1 až T-A6, T-B1 až T-B3) a in-SU** (audit NOTE 7).
- **Predrecenzia: povinná** pri oboch (audit-povinná trieda). Nový ovládací prvok: nie.
- **In-SU:** **H10a áno — brána** (`handle_save` = akcia `save_rules` zapisujúca do modelu, mení sa jej Ruby PRED aj PO operácii; Späť a prestavbu headless
  neoverí). **H10b nie** (model sa nemení).

### 5.1 Závislosti — pred štartom implementácie overiť proti mainu

- **H9 (R-37)** mení `supplier_settings.rb` a pravdepodobne `json_file_store.rb` — ak zmení `read/reload!/write/degraded?`, zladiť R1.1/R1.2/R2.2 (pri zmene
  kontraktu krátka delta auditu).
- **H4 (texty)** — prevziať štýl hlášok. **H1 (PR #433)** — príklady hraníc triedy. **H7** — bez prieniku.

## 6 · Požiadavky

### R1 · Globálne pravidlá kovania (H10a)

- **R1.1 Čítanie s rozlíšeným výsledkom** (FIX 3). `HardwareRules.library_check(fresh: true)` → `{ state:, rev:, reason: }`, **bez zápisu** (žiadne
  `ensure_seeded` ani `persist_seed_merge!`); `fresh: true` = najprv `JsonFileStore.reload!(path)`:
  - `:ok` — čitateľné, zapisovateľné; `rev = rules_rev(read_rules.first)`; poškodený primár **bez** `.bak` alebo chýbajúci súbor = `rules_rev(SEED_RULES)` (P5, samooprava ostáva).
  - `:blocked` — čitateľné, ale zápis zakázaný: degradovaný súbor (číta sa `.bak`) alebo novší `std`; `rev` z prečítaného obsahu, `reason` = presne veta, ktorú
    by dal `write_block_reason`.
  - `:unreadable` — iná chyba čítania (práva, zdieľanie, disk); `rev = nil`.
  Brány sú **jedna autorita**: čistá funkcia (napr. `write_gate_reason(doc)`), ktorú volajú `degraded_write_blocked?`/`newer_write_blocked?` (správanie `write`
  vrátane logu bez zmeny) aj `library_check`; test parity. `library_revision` = `library_check(fresh: false)[:rev] || ''` (payload, smie ísť cez 1 s cache).
- **R1.2 `save_library!(rules, revision)`** → `[status, rev]`, `status` ∈ `:ok | :conflict | :blocked | :unreadable | :write_failed`. Pod `with_catalog_lock`:
  `library_check(fresh: true)` → `:unreadable` → `[:unreadable, nil]` · `:blocked` → `[:blocked, nil]` · `revision` prázdna alebo ≠ `rev` → `[:conflict, rev]` ·
  inak `write(rules)` (reentrantne, W8/W9) → `[:ok, nový rev]` alebo `[:write_failed, nil]`. `rescue` (aj nezískaný zámok) → `[:write_failed, nil]`. `rev` sa vracia
  **len** pri `:ok`/`:conflict` a vždy neprázdny.
- **R1.3 Rozdelenie `baseline_valid?`** (FIX 2) na `baseline_state(model)`:
  - `:document` — `model_guid(model) != @baseline_guid` (identita dokumentu — **bez zmeny**, deštruktívne echo ako dnes).
  - `:inherits_global` — projekt **nemá** snapshot a `@baseline_source == 'global'` (formulár bol naplnený globálom). Obsah sa **neporovnáva cez cache**
    `HardwareRules.load`; rozhodne čerstvá predkontrola R1.4 (deterministicky pri oboch časovaniach cache, H1).
  - `:changed` / `:ok` — ostatné prípady presne ako dnes (`project || load` vs `@baseline_rules`; zmena = deštruktívne echo).
  `@baseline_source` sa nastavuje v `rules_payload` spolu s ostatnými baseline (len pri úspešnom zostavení). `DocKey.foreign?` a projektový `rules_rev` ostávajú.
- **R1.4 Predkontrola** — za `rules_problems`, **pred** `Panel.job_cabinets_split`/`rebuild_many`; beží, keď `also_global` **alebo** `:inherits_global`.
  `c = library_check(fresh: true)`; poradie (D10 aj tu): 

  | # | Podmienka | Výsledok | Zapíše sa | Pin |
  |---|---|---|---|---|
  | 1 | `c.state == :unreadable` (brány sa nedajú vyhodnotiť) | **H-READ** (červená) | nič | bez zmeny |
  | 2 | `c.state == :blocked` a **nie** `:inherits_global` (teda `also_global`) | pokračuje sa; globál sa nezapíše, za uložením dnešná veta `reason` (nie konflikt, nie ponuka prepisu) — `global_rev` sa tu nepotrebuje | projekt | bez zmeny |
  | 3 | payload **nemá kľúč** `global_rev` (starý DOM nad novým Ruby) | **H-OLD** | nič | bez zmeny |
  | 4 | pin `''` (formulár otvorený, keď sa globál nedal prečítať) | **H-UNK** | nič, formulár ostáva | `c.rev` |
  | 5 | pin ≠ `c.rev` a `:inherits_global` (aj pri `:blocked` — obsah je čitateľný) | **H-INH** | nič, formulár ostáva | `c.rev` |
  | 6 | pin ≠ `c.rev`, `also_global`, `c.state == :ok` | **H-PRE** | nič, formulár ostáva | `c.rev` |
  | 7 | inak | pokračuje sa | projekt (+ globál podľa R1.5) | — |

  „Formulár ostáva" = žiadne `push_section_echo`, žiadna operácia, žiadny krok Späť; pin sa obnoví skriptom `RD.setGlobalRev(c.rev)` (len neprázdny).
  Pri `:inherits_global` + `:blocked` + zhode pinu sa projekt uloží a globál (ak `also_global`) nie — s vetou `reason`.
- **R1.5 Po prestavbe** (projekt uložený, operácia zavretá — `cabinet_builder.rb:853-868`), ak `also_global` a riadok 2 neplatil:
  `status, rev = save_library!(rules, data['global_rev'].to_s)`, vyhodnotenie **`case status`** (nikdy pravdivosť):
  `:ok` → „ + globálna predvoľba", `RD.setGlobalRev(rev)` · `:conflict` (súbeh) → status **červený H-RACE**, `RD.setGlobalRev(rev)` · `:blocked` → dnešná veta
  `write_block_reason` · `:unreadable` → červené „…globálne predvoľby sa nepodarilo prečítať, neprepísali sa" · `:write_failed` → dnešné „(globálny zápis zlyhal!)".
  Pri `:blocked`/`:unreadable`/`:write_failed` sa pin **nemení** a prepis sa **neponúka**. `RD.setGlobalRev` ide **pred** `after_model_write` (poradie je aj tak
  irelevantné — R1.7; JS test oboch poradí).
- **R1.6 Payload a „Načítať globálne":** `rules_payload` pridá `'global_rev' => project ? HardwareRules.library_revision : HardwareRules.rules_rev(rules)` (pri
  zdroji `global` ten istý objekt ako `rules`) a `@baseline_source`. `push_global`: `lib = HardwareRules.load` → `RD.setRules(lib, 'global')` + `RD.setGlobalRev(rules_rev(lib))`
  v jednom skripte s guardom `if (window.RD && RD.setGlobalRev)`; signatúra `RD.setRules` sa nemení.
- **R1.7 Pin klienta — posúva sa LEN keď klient globál naozaj načíta/zobrazí** (BLOCKER 1). `RD_GLOBAL_REV` (mimo `RD_META`, štart `null`):
  - **posunie sa:** (a) **prvé naplnenie** sekcie v tomto okne Štúdia (`RD_GLOBAL_REV === null`) · (b) naplnenie, ktoré **zobrazuje globál** (`d.source === 'global'`)
    · (c) `RD.setGlobalRev(rev)` zo servera: „Načítať globálne", obnova po H-PRE/H-INH/H-UNK/H-RACE, vlastné úspešné uloženie globálu. Prázdne `rev` sa ignoruje.
  - **neposunie sa:** `rdSetState` so zdrojom `project` (uloženie LEN do projektu, Späť/Znova, prepnutie dokumentu, Doplniť nové predvolené), vetva `rdApplyState`
    s nezmenenými pravidlami, `RD.setRules`.
  - `rdSaveRules` posiela `global_rev: RD_GLOBAL_REV === null ? '' : RD_GLOBAL_REV` **vždy** (kľúč prítomný = nový DOM). Node export: getter `rdGlobalRev()`.
  - Dôkaz: J1 (pôvodný návrh zlyhá) vs J2 (tento návrh) — regresný test T-A5.
- **R1.8 Texty** (návrh — Q1; server je jediná autorita):
  - **H-PRE:** „Globálne predvoľby pravidiel medzitým zmenilo iné okno SketchUpu — nič sa neuložilo (projekt ani globálne). Tvoje úpravy ostali vo formulári. Ak chceš
    globálne predvoľby prepísať týmto formulárom, klikni Uložiť znova; inak odškrtni „aj ako globálnu predvoľbu" a ulož len do projektu."
  - **H-INH:** „Tento projekt ešte nemá vlastné pravidlá a preberá globálne predvoľby — tie medzitým zmenilo iné okno SketchUpu. Nič sa neuložilo, tvoje úpravy
    ostali vo formulári. Klikni Uložiť znova, ak ich chceš uložiť tak, ako sú (zmenu z druhého okna uvidíš cez Načítať globálne)."
  - **H-UNK:** „Pri otvorení Štúdia sa globálne predvoľby nedali prečítať, takže nevieme, či ich medzitým niekto nezmenil — nič sa neuložilo. Tvoje úpravy ostali
    vo formulári; klikni Uložiť znova, ak chceš pokračovať."
  - **H-READ:** „Globálne predvoľby pravidiel sa nepodarilo prečítať (disk/práva) — nič sa neuložilo. Skús to znova; ak to pretrváva, skontroluj priečinok nastavení."
  - **H-OLD:** „Okno je z predošlej verzie pluginu (chýba mu údaj o verzii globálnych predvolieb) — nič sa neuložilo. Zavri a otvor Štúdio znova a ulož."
  - **H-RACE:** „Pravidlá uložené do projektu — prestavaných N skriniek. Globálnu predvoľbu medzitým zmenilo iné okno SketchUpu, preto sa NEPREPÍSALA; ak ju chceš
    prepísať, klikni Uložiť znova."
- **R1.9 Hranice ochrany:** chráni zmenu, ktorá prišla **počas** otvoreného Štúdia; okno otvorené až **po** cudzej zmene ju pri vedomom „aj ako globálnu" prepíše (F7).
  Chráni len procesy s H10 — **starý proces** (spustený pred aktualizáciou) zapíše bez revízie a zámok ho len zoradí (NOTE 5) → prevádzková podmienka: po aktualizácii
  zavrieť **všetky** okná SketchUpu na PC (§10, R3). Lucia má vlastné `%APPDATA%` — prenos `.skp` medzi PC tento súbeh nevytvára.

### R2 · Rozmerové rady (H10b) — zápis po kľúčoch s pôvodnou hodnotou kľúča

- **R2.1 `DimSeries.update!(changes, base)`** → `[status, series, keys]`, `status` ∈ `:ok | :conflict | :stale_client | :blocked | :write_failed`.
- **R2.2 Pod `with_catalog_lock`, v poradí:** (1) `degraded_write_blocked?` → `[:blocked, nil, []]` (W10); (2) `changes` nie je Hash alebo menený kľúč nemá
  v `base` pole → `[:stale_client, nil, []]`; (3) `JsonFileStore.reload!`, `current = get`; menené kľúče s `normalize_list(base[k]) != current[k]` → `[:conflict,
  current, tie_kľúče]`, **nič sa nezapíše** (ani nekonfliktné kľúče); (4) `merged = normalize(current.merge(changes ∩ KEYS))`; `merged == current` → `[:ok, current, []]`
  bez zápisu; inak `set(merged)` (jediný `JsonFileStore.write(` ostáva v `set`) → `[:ok, merged, zmenené]` / `[:write_failed, nil, []]`; `rescue` → `:write_failed`.
- **R2.3** `DimSeries.set` bez zmeny (interné, testy); `LABELS` = Šírky · Výšky · Hĺbky · Sokle · Výšky čiel (`panel.html:1037-1041`).
- **R2.4 `Panel.handle_set_dim_series`:** `update!(data['series'], data['base'])`; **vždy** `push_ui_settings(refill_editor: true)` (dnes aj pri zlyhaní); status:
  `:ok` → „Rozmerové rady uložené." / bez kľúčov „Rozmerové rady sa nezmenili." · `:conflict` → červené **H-DIM** „Rozmerové rady (Šírky) medzitým zmenilo iné okno
  SketchUpu — nič sa neuložilo. Editor ukazuje aktuálne uložené rady, zmenu zadaj znova." · `:stale_client` → „Okno je z predošlej verzie pluginu — rozmerové rady
  sa neuložili. Zavri a otvor panel znova." · `:blocked` → `write_block_reason` · `:write_failed` → dnešná veta. Rozpis editora sa pri konflikte stratí (D8).
- **R2.5 `settings.js`:** `NXDIM_BASE` sa pripína v `nxFillSeriesEditor` (otvorenie kolieska aj `refill_editor`), push témy ho nemení. Čistá
  `NXDim.changes(texts, base)` → `{ series, base, keys }` (zmena = `normalizeList(parseText(text))` ≠ `normalizeList(base[k])`). Bez zmien → bez callbacku,
  polia z pinu, `NX.setStatus('Rozmerové rady sa nezmenili.')`. „Predvolené" mení len polia.
- **R2.6 Prečo:** panel drží rady od otvorenia (W7) — celková revízia by hlásila konflikt pri každej zmene iného radu; po kľúčoch bez pôvodnej hodnoty by ticho strácalo
  zmenu toho istého radu (P2).
- **R2.7 Platnosť zlúčenia (NOTE 6):** platí pre **dnešných 5 normalizovaných kľúčov** (`KEYS`). `[]` = vypnutý rad (platná hodnota, zlúči sa a zapíše);
  chýbajúci/neplatný kľúč v súbore sa číta ako predvolený (pôvodná hodnota klienta = predvolená → zhoda); neznámy kľúč od klienta sa ignoruje; neznámy kľúč
  v súbore `normalize` pri zápise **zahodí** a `set` zapíše `std: 1` — **ochrana novšieho formátu radov neexistuje** (dnešné obmedzenie, nie regresia H10;
  dokumentácia ju nesmie sľubovať; budúci kľúč = vlastná dávka s bránou `std`).

### R3 · Dokumentácia

- **STANDARD §6** (`STANDARD.md:702-704`, H10a): jedna veta — zápis globálnej knižnice z okna nesie revíziu obsahu; súbežná zmena = nič sa neprepíše, okno to povie.
- **Prevádzková podmienka** (R1.9) do odsekov `hardware_rules.rb` (H10a) a `dim_series.rb` (H10b) + do smoke checklistu a reportu dávky.
- Odsek `dim_series.rb`: hranice zlúčenia R2.7.

## 7 · Testy a DoD

**C · Charakterizácia PRED zásahom** (prvý commit vetvy, zelená na `main`): **C1 (H10a)** jedno okno — `write` dá bajty X; po zásahu `save_library!(…, rev)` dá **X**.
**C2 (H10b)** `set(plné rady s jednou zmenou)` = Y; po zásahu `update!({k => …}, {k => pôvodné})` = **Y**. **C3** golden `test_kova_golden.rb`, `test_kovh_golden.rb`
**bez zmeny fixtúr** (dokazujú len nezmenené výpočty — NOTE 7).

**H10a — `tests/pure/test_h10a_globalne_pravidla.rb`** (štruktúra `test_r08_zamky.rb`: `with_files`, `with_other_instance` `:89-103`, `with_broken_lock`;
harness `handle_save` podľa H2: fake model, stuby `Panel`, `after_model_write`, sink cez `RulesDialog.dispatch`):
- **T-A1 jadro:** `library_check` — `:ok`/`rev` = `rules_rev(load)` bez zápisu (mtime) aj nad starším `seed_version`; poškodený bez `.bak` a chýbajúci = `rules_rev(SEED)`;
  degradovaný a novší `std` → `:blocked` s vetou zhodnou s `write_block_reason`; nečitateľný (stub `JsonFileStore.read` → `Errno::EACCES`) → `:unreadable`, `rev nil`;
  **parita brány** `write` ↔ `library_check`. `save_library!`: dva klienti s `rev0` → A `:ok`, B `[:conflict, rev_A]`, súbor = A; `''` → `:conflict`; cudzí zápis tesne
  pred zámkom → `:conflict`; degradovaný + zlá revízia → `:blocked` (nie konflikt); nezískaný zámok → `[:write_failed, nil]`.
- **T-A2 predkontrola (FIX 3)** — každý riadok tabuľky R1.4: presná hláška, `ops == []` (žiadna operácia) tam, kde sa nič nezapisuje, snapshot nedotknutý, globál
  bajtovo nedotknutý, `RD.setGlobalRev` **prítomné len** v riadkoch 4–6 (s neprázdnou hodnotou) a **chýba** v 1–3; riadok 2 (degradovaný alebo novší `std` +
  `also_global`) uloží projekt a hlási `reason`, **nie** H-PRE ani H-OLD (aj bez kľúča `global_rev`).
- **T-A3 projekt bez snapshotu (FIX 2), oba časovania cache:** (a) cache zohriata pred cudzím zápisom (stav H1a), (b) po `reload!` (H1b) → **v oboch** H-INH, `ops == []`,
  **žiadny** `RD.setSection(…, true)`, snapshot sa nezapísal, globál = B; druhé uloženie s obnoveným pinom → projekt uložený (a pri `also_global` globál = formulár).
  Kontrola identity: iný dokument (`@baseline_guid`) → naďalej deštruktívne echo (dnešná hláška).
- **T-A4 súbeh po prestavbe (FIX 4):** jednorazový hook (obal `HardwareRules.save_library!` alebo prvé `with_catalog_lock` po `rebuild_many`) zapíše cudzí globál
  → status **červený H-RACE**, cudzí globál **bajtovo zachovaný**, nový projektový snapshot = formulár, `ops == [start, commit]`, zachytené `RD.setGlobalRev(<rev cudzieho>)`,
  `after_model_write` 1×, nasledujúci `rules_payload` nesie `global_rev` = rev cudzieho.
- **T-A5 zdroj `rules_dialog.rb`:** `baseline_state` pred `DocKey.foreign?`/`rules_rev`; predkontrola za `rules_problems` a pred `rebuild_many`; `save_library!` za
  `rebuild_many`; `case`/`==`, nie pravdivosť; `rules_dialog.rb` nevolá `HardwareRules.write(`; `handle_save` obsahuje `HardwareRules.write_block_reason` (R-11 guard
  `test_r11_degradovana_zaloha.rb:484-490`); R-08 guard „revízia AŽ POD zámkom" (`test_r08_zamky.rb:456-480`) rozšírený o `save_library!`.
- **T-A6 JS `tests/js/test_h10a_pin.js`** (setup `test_st3b_rules.js:49-71`, scenáre zo `sonda_h10_js.js`): **regresia BLOCKER** — A-G0 / B-G1 / A uloží len projekt
  (push so zmenenými pravidlami a G1) / A „aj ako globálnu" → odchádza **G0**; to isté po Späť a po prepnutí dokumentu; zdroj `global` → pin ide s obsahom;
  `RD.setRules` pin nemení; `RD.setGlobalRev('')` ignorované; poradie `setGlobalRev(F)` → push so zmenenými projektovými pravidlami aj opačne → odchádza **F**;
  `rdSaveRules` posiela kľúč `global_rev` vždy (`''` pred prvým naplnením).

**H10b — `tests/pure/test_h10b_rady.rb` + `tests/js/test_h10b_rady.js`:**
- **T-B1 dva klienti:** rôzne kľúče sa zlúčia (700 aj nové hĺbky); ten istý kľúč → `[:conflict, current, ['sirka']]`, súbor **bajtovo** nezmenený (aj s nekonfliktným
  kľúčom v požiadavke); bez skutočnej zmeny → bez zápisu (mtime); chýbajúce `base`/`changes` nie Hash → `:stale_client`; degradovaný + payload bez `base` → `:blocked`.
- **T-B2 akceptácia R2.7:** vyprázdnený rad `[]` sa zapíše a zlúči · chýbajúci kľúč v súbore = predvolený (zhoda s pôvodnou hodnotou klienta) · neznámy kľúč od
  klienta sa ignoruje · neznámy kľúč v súbore sa pri zápise zahodí (test **potvrdzuje dnešné obmedzenie**, nesľubuje ochranu).
- **T-B3** `handle_set_dim_series` (stub `test_r11_degradovana_zaloha.rb:180-200`): každá vetva → text + `refill_editor: true`; JS `NXDim.changes` (nič/poradie/duplicity/
  „Predvolené"/pin vs. push témy); guard: `actions_settings.rb` nevolá `DimSeries.set(`; R-08 guard rozšírený o `update!`.

**T-E · Existujúce sady zelené:** `test_r08_zamky.rb` (guard „jediný zápis" bez zmeny; hlavičku „PRIZNANÝ ZVYŠOK R-35" prepísať), `test_r11_degradovana_zaloha.rb`
(bez zmeny), `test_uib3_rady.rb`, `test_hardware_rules.rb`, `test_st3b_rules.rb`, `test_d134_rozsah_zapisov.rb`, `test_supplier_settings.rb`, JS `test_st3b_rules.js`
(signatúra `setRules` sa nemení), `test_uib3_korpus.js`. Žiadna fixtúra sa nepregeneruje.

**Mutácie (každá musí zhodiť aspoň jeden test; H10a min. 12, H10b min. 6):**
H10a — M1 revízia pred zámkom · M2 bez `reload!` · M3 `''` = zhoda · M4 revízia pred bránou · M5 bez predkontroly · M6 pravdivosť namiesto `case` · M7 bez
`setGlobalRev` po úspechu · M8 pokojný push posunie pin · **M9 pin pri `rdSetState` so zdrojom `project` (BLOCKER)** · **M10 `:inherits_global` cez cachovaný `load`
(FIX 2)** · **M11 `:unreadable` = konflikt s obnovou pinu (FIX 3)** · **M12 `:blocked` dá H-PRE namiesto vety (FIX 3)** · **M13 H-RACE bez obnovy pinu (FIX 4)** ·
M14 `setGlobalRev('')` prijaté.
H10b — M15 bez kontroly `base` · M16 zápis všetkých 5 kľúčov · M17 konflikt zapíše nekonfliktné kľúče · M18 chýbajúce `base` = povolenie · M19 `nxFillSeriesEditor`
nepripne · M20 `NXDim.changes` vráti všetky kľúče.

**Beh:** `ruby tests/run_all.rb` + každá JS sada zvlášť + `ruby scripts/encoding_guard.rb --repo`.
**DoD (každá časť):** C + svoje testy zelené · mutácie v PR · H10a in-SU `run_h10a` PASS na hlave · dokumentácia §11 · PR so sekciou „Predrecenzia".

## 8 · In-SU — **brána mergu H10a** (H10b in-SU nemá)

Scenár `run_h10a` v `tests/sketchup/su_runner.rb` (`scripts\run_su_tests.ps1 -CloseWhenDone`, kópia `_dev\ENGINEtests.skp`). **Celý pod `Materials.test_dir_override = tmp`**
(vzor KOV-I `su_runner.rb:26501-26515`; overiť `HardwareRules.path` v `tmp`, inak FAIL a koniec) — dnes žiadny in-SU scenár `also_global: true` nepoužíva.
1. Skrinka + `push_state` (vzor `st3b_catch_all` `:17799-17835`) → `global_rev` z payloadu.
2. **H-PRE:** cudzí globál na disk → `dispatch('save_rules', {also_global: true, global_rev: pin})` → H-PRE; snapshot a kovanie skrinky nezmenené, globál = cudzí,
   **žiadny krok Späť** (marker vo vlastnej operácii, prvé `Sketchup.undo` ho zmaže — vzor `su_runner.rb:4256`, `:5177-5194`), skript `RD.setGlobalRev`.
3. **Druhé uloženie** s obnoveným pinom → projekt + prestavba, globál = formulár; jedno `Sketchup.undo` vráti snapshot, globál ostane.
4. **H-RACE (FIX 4):** jednorazový obal `HardwareRules.save_library!` zapíše cudzí globál → červený H-RACE; cudzí globál bajtovo zachovaný; projektový snapshot nový
   a **počet kovania skrinky zodpovedá novým pravidlám**; **jedno** `Sketchup.undo` vráti snapshot **aj** počet kovania; globál po Späť stále cudzí; zachytené
   `RD.setGlobalRev(<rev cudzieho>)` a ďalší `rules_payload` nesie ten istý `global_rev`.
5. Jedno okno bez súbehu, `also_global: true` → súbor bajtovo `{std, seed_version, rules: normalize_rules(rules)}`.
Upratanie: obal a `test_dir_override` späť, `cleanup(model)`. Ak SketchUp nepôjde, H10a čaká. (Projekt bez snapshotu kryje headless T-A3 — testovací model snapshot má.)

## 9 · Riziká

- **Falošný konflikt pravidiel** — len pri reálnej zmene obsahu (P3/P4); nový seed po aktualizácii je skutočná zmena → hláška pravdivá.
- **Starý proces bez H10** (okno spustené pred aktualizáciou) zapíše globál aj rady bez revízie — **prevádzková podmienka**: po aktualizácii zavrieť **všetky** okná
  SketchUpu na PC (R1.9; NOTE 5). „Starý klient" v kóde = starý DOM nad novým Ruby (H-OLD, `:stale_client`), nie starý proces.
- **Okno otvorené po cudzej zmene** globál pri vedomom „aj ako globálnu" prepíše (nie súbeh) — R1.9, F7.
- **Súbeh predkontrola ↔ zámok** → projekt uložený, globál nie, červené H-RACE, pin obnovený — T-A4 + in-SU krok 4.
- **Rady:** zlúčenie platí len pre 5 dnešných kľúčov; novší formát radov nie je chránený (R2.7). Rozpis editora sa pri konflikte stratí (D8).
- **Iný zapisovateľ mimo zámku** (ručný editor, antivírus) — TOCTOU priznané pri R-11. **Kolízia s H9** — §5.1. **In-SU bez izolácie** — tvrdá podmienka §8.

## 10 · Smoke checklist pre Michala (dve okná SketchUpu)

**Pred smoke:** po aktualizácii **zavri všetky okná SketchUpu** a otvor ich znova (staré okno by zapisovalo bez ochrany). Skopíruj `%APPDATA%\NOXUN\Engine\
hardware_rules.json` a `dim_series.json` bokom a po smoke ich vráť. Dva testovacie modely, nie zákazka.
1. **Pravidlá (H10a):** v oboch oknách Štúdio → Pravidlá. V A zmeň počet (napr. nohy), zaškrtni „aj ako globálnu predvoľbu", Uložiť. V B zmeň niečo iné, zaškrtni,
   Uložiť → **červená hláška**, úpravy v B **ostali vo formulári**, skrinky sa neprestavali, Späť nemá nový krok. Druhé Uložiť v B → uložené (vedomé prepísanie).
2. **Uloženie len do projektu nepotvrdí cudzí globál (H10a):** zatvor a otvor Štúdio v A aj B. V B ulož globál. V A ulož **bez** zaškrtnutia, potom **so**
   zaškrtnutím → **červená hláška** (A cudziu zmenu nevidelo).
3. **Nový prázdny model (H10a):** v A nový model → Štúdio → Pravidlá (ukazuje globálne predvoľby), uprav číslo; v B ulož globál; v A Uložiť → **červená hláška,
   úpravy ostali**; druhé Uložiť → uložené.
4. **Rady — rôzne riadky (H10b):** v A do Šírok pridaj 700 → Uložiť; v B (panel otvorený predtým) zmeň Hĺbky → Uložiť → editor v B ukazuje aj 700.
5. **Rady — ten istý riadok (H10b):** A zmení Sokle, B (bez zatvorenia panela) zmení Sokle → **červená hláška**, editor ukáže sokle z A.
6. **Jedno okno:** bežné uloženie pravidiel aj radov ako doteraz; reálna zákazka (len otvoriť) — Kusovník, Nákup, Rozpočet s rovnakými číslami.

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch VERSION (2×) + **všetky `?v=`** → testy + (H10a) in-SU → **architektúra na mieste:** H10a — `docs/architecture/hardware.md` odsek `hardware_rules.rb`
(„Priznaný zvyšok" `:305-310`, odtlačok `:387-405`: globálna revízia, `baseline_state`, predkontrola, pin, prevádzková podmienka) + veta v `hardware_taxonomy.rb`
(`:581-583`) · `docs/architecture/ui-lifecycle.md` sekcia Pravidlá (`:2781-2790`, pravidlá pinu R1.7) · **STANDARD §6** (R3). H10b — `docs/architecture/model-a-identita.md`
odsek `dim_series.rb` („Priznaný zvyšok" `:254-257` + R2.7 + prevádzková podmienka) · `ui-lifecycle.md` odsek **`actions_settings.rb` (dnes prázdny, `:2351-2353`)**
+ koliesko UI-B3 (pin `NXDIM_BASE`). → **AUDIT_REGISTER** R-35: po H10a „čiastočne ✅ (pravidlá) — H10a PR #…", po H10b „✅ dávkami H10a/H10b" + riadok v tabuľke
„Stav po previerke" → **prepis `SYSTEM/STAV.md`** (`STAV.md:19, :45` „pred uzáverom V1 … R-35" zladiť) → **KRONIKA** → **PLAN** riadok H10 (H10a ✅ PR, H10b ✅ PR;
zmienka R-35 `PLAN.md:169`) → DOGFOODING bez zmeny → package + surový audit (`AUDIT_H10_raw.md`) do `SYSTEM/zdroje/bloky/HARDENING/` (s H10a) → PR popis.
Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | Revízia pravidiel = **obsahový** `rules_rev`, nie SHA bajtov | V7; P4 (seed-merge mení bajty, nie obsah); audit NOTE 7 potvrdil | nie (audit OK) |
| D2 | Nová `save_library!` → `[status, rev]`; `write` bez zmeny správania | P6; R-08 guard (W8) | nie |
| D3 | **Pin globálu sa posúva len pri prvom naplnení, pri zobrazení globálu a na pokyn servera** (R1.7) | BLOCKER 1; J1/J2 | **áno** |
| D4 | Predkontrola pred prestavbou (nič, formulár ostáva) + kontrola pod zámkom po prestavbe (H-RACE) | konflikt nemá zničiť platné úpravy ani pridať krok Späť | **áno (Q1)** |
| D5 | Po H-PRE/H-INH/H-UNK/H-RACE server pin obnoví → druhé Uložiť = vedomé prepísanie; pri chybe čítania/bráne **nie** | vzor V5; FIX 3 | krátko (Q1) |
| D6 | Prázdna/chýbajúca revízia aj `base` = fail-closed; chýbajúci kľúč = starý DOM (H-OLD), prázdny = neznámy základ (H-UNK) | V4, V6; FIX 3 | nie |
| D7 | Rady: po kľúčoch s pôvodnou hodnotou kľúča, len pre 5 dnešných kľúčov | W7, P2; NOTE 6 | **áno (Q2)** |
| D8 | Konflikt radov = nič + editor z uloženého stavu; rozpis sa stratí | existujúci `refill_editor`, vzor `SS.saved()` | krátko |
| D9 | `DimSeries.set` a `HardwareRules.write` ostávajú interné; UI ich nevolá | testy R-08/R-11/UI-B3, seed cesty | nie |
| D10 | Poradie: nečitateľné → brána (degradovaný/novší) → starý DOM → neznámy základ → konflikt → zápis — v predkontrole aj pod zámkom (rady: brána → starý DOM → konflikt); pri radoch bez sľubu ochrany novšieho formátu | FIX 3; W10; NOTE 6 | nie |
| D11 | Formát súborov bez zmeny → žiadna schéma | revízia sa počíta | nie |
| D12 | In-SU brána len H10a, izolované `test_dir_override` | `handle_save` zapisuje do modelu | nie |
| D13 | Žiadny nový ovládací prvok; hlášky v existujúcom statuse | UI_DIZAJN §2 `--nx-err` | nie |
| D14 | `baseline_valid?` → `baseline_state`; projekt bez snapshotu so zdrojom `global` rozhoduje čerstvá predkontrola (H-INH), nie cachovaný `load` + deštruktívne echo | FIX 2; H1 | **áno** |
| D15 | **Rez H10a → H10b**, audit platí pre obe | > ~400 riadkov po audite | **áno** |

## 13 · Otázky pre Michala (produktové; do odpovede platí návrh)

- **Q1 · Pravidlá pri cudzej zmene globálnych predvolieb.** Návrh: **neuloží sa nič** (ani projekt), úpravy ostanú vo formulári, hláška povie čo sa stalo; druhé
  Uložiť vedome pokračuje. Platí aj pre zákazku bez vlastných pravidiel, ktorá preberá globálne (dnes sa jej formulár v takom prípade niekedy zahodí, niekedy uloží
  a cudzia zmena zanikne — podľa toho, ako rýchlo klikneš). Alternatíva: uložiť projekt hneď a globál vynechať.
- **Q2 · Rozmerové rady.** Návrh: rôzne riadky z dvoch okien sa zlúčia bez hlášky; ten istý riadok → hláška a zmenu treba zadať znova.
- **Info (nie otázka):** po každej aktualizácii pluginu zavrieť **všetky** okná SketchUpu na PC — staré okno by ochranu obišlo.

## 14 · Nálezy mimo scope

- **F1** `dim_series.rb:164-165` — komentár o seed-merge je kópia z pravidiel (W6). *Opraví H10b.*
- **F2** Panel v druhom okne ukazuje v šípkach staré rady až do uloženia/otvorenia panela (W7) — nie strata dát; zásobník.
- **F3** Uloženie s „(globálny zápis zlyhal!)" alebo dôvodom brány je zelený status (`rules_dialog.rb:659`) — H4 alebo zásobník (nová vetva H-RACE/nečitateľné je červená).
- **F4** `ui-lifecycle.md:2351-2353` odsek `actions_settings.rb` prázdny (R-32) — *napíše H10b.*
- **F5** `STAV.md:19, :45` uvádzajú R-35 „pred uzáverom V1" — zladí prepis STAV.
- **F6** `hardware.md:581` (taxonómia) odkazuje na R-35 ako „úplnú náhradu" — upresní H10a.
- **F7** Sekcia Pravidlá neukazuje, že globál sa líši od projektu — okno otvorené po cudzej zmene ju môže vedome prepísať bez toho, aby ju videlo; zásobník po V1.
- **F8 (nový, H1a sondy)** Dnes, **bez** H10, projekt bez snapshotu v 1 s okne cache ticho prepíše cudzí globál pri „aj ako globálnu" — H10a to opraví (T-A3a).

## 15 · Audit návrhu — zapracovanie (Codex, rola audítor audit-povinných, 1.10.2026: 1 BLOCKER · 3 FIX · 3 NOTE)

Surový výstup `AUDIT_H10_raw.md` (implementátor H10a ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/`).

| Nález | Čo sa zmenilo | Kde |
|---|---|---|
| **1 BLOCKER** — pin globálu pri každom `rdSetState` potvrdí nevidený globál po uložení len do projektu / Späť | Pin sa posúva **len** pri prvom naplnení, pri zobrazení globálu (`source: 'global'`) a na `RD.setGlobalRev` (Načítať globálne, obnova po konflikte, vlastné úspešné uloženie globálu); projektová obnova, Späť, prepnutie dokumentu ho nemenia. Sonda nad skutočným `rules.js` v pamäti: pôvodný návrh scenár A-G0/B-G1/A-projekt/A-globál **prepustí**, nový skončí **konfliktom** (J1/J2). Regresia T-A6, mutácia M9 | §0.4 J1–J3, R1.7, T-A6, D3 |
| **2 FIX** — projekt bez snapshotu: `baseline_valid?` + `force: true` zahodí rozpis pred predkontrolou, výsledok závisí od cache | `baseline_valid?` → `baseline_state`; nový stav `:inherits_global` rozhodne **čerstvá** predkontrola (H-INH, formulár ostáva); identita dokumentu (`:document`) a ostatné vetvy bez zmeny. Sonda H1 potvrdila oba časovania (a dnešnú tichú stratu v okne cache, F8). Testy T-A3a/b, mutácia M10 | §0.4 H1, R1.3–R1.4, T-A3, D14, F8 |
| **3 FIX** — predkontrola mieša poškodenie / nekompatibilitu / chybu čítania s konfliktom | `library_check` → `:ok / :blocked / :unreadable` + `reason` (jedna autorita brán s `write`, test parity); tabuľka R1.4 s poradím D10; pri chybe/bráne **žiadna obnova pinu a žiadna ponuka prepisu**; nové hlášky H-READ, H-UNK; prázdny pin ≠ starý DOM | R1.1, R1.2, R1.4, R1.8, T-A1/T-A2, M11/M12, D6, D10 |
| **4 FIX** — H-RACE bez integračného pokrytia | Deterministický hook medzi predkontrolou a `save_library!` — headless (T-A4, uskutočniteľnosť H2/H3) aj in-SU krok 4: červený H-RACE, cudzí globál zachovaný, nový snapshot, jedno Späť vráti snapshot aj kovanie, správny pin po ďalšom pushi (JS poradia v T-A6), mutácia M13 | §0.4 H2–H3, R1.5, T-A4, §8 krok 4 |
| **5 NOTE** — „starý klient" = starý DOM nad novým Ruby; staré procesy obídu ochranu | Definícia v R1.9/§9; prevádzková podmienka (reštart všetkých okien na PC) v R1.9, R3, §9, §10, §13 info; Lucia — vlastné `%APPDATA%` | R1.9, R3, §9, §10, §13 |
| **6 NOTE** — per-key merge len pre 5 normalizovaných kľúčov, novší formát nechránený | R2.7 (hranice), akceptácia T-B2 (vyprázdnený rad, chýbajúci kľúč, neznámy kľúč od klienta aj v súbore), D10 bez sľubu ochrany, dokumentácia R3 | R2.7, T-B2, D10, R3 |
| **7 NOTE** — golden testy nedokazujú nový tok | Formulácia v §5 a C3: golden = nezmenené výpočty; nový tok = T-A1…T-A6, T-B1…T-B3 + in-SU | §5, §7 C3 |

**Rozsah po audite:** > ~400 riadkov kódu → **rez H10a / H10b aktivovaný** (§2, D15). Nový audit netreba, pokiaľ implementácia nezmení kontrakt §6.

---

## Potvrdenie orchestrátora (1.10.2026 ~04:15)

- Audit návrhu (audítor audit-povinných): 1 BLOCKER · 3 FIX · 3 NOTE → zapracované (§15). **Delta audit (rola bežný audit a delta): všetkých 7 bodov RESOLVED,
  žiadne nové nálezy** (`AUDIT_H10_delta_raw.md`). Audit uzavretý.
- **Rez H10a (pravidlá, in-SU brána) → H10b (rady, headless) potvrdený.** Každá dávka: predrecenzia povinná, vlastný PR, vlastný patch bump.
- D1, D4, D5, D7, D8 potvrdené. **Q1/Q2 platí návrh** (konflikt pravidiel = neuloží sa nič; rôzne rady sa zlúčia, ten istý rad = hláška), kým Michal neodpovie —
  v PR a reporte označiť ako vratnú voľbu.
- Implementátor skopíruje package + `AUDIT_H10_raw.md` + `AUDIT_H10_delta_raw.md` do `SYSTEM/zdroje/bloky/HARDENING/` v PR H10a.

## Zladenie s H9 (orchestrátor, 1.10.2026 ~03:05) — MÁ PREDNOSŤ pred R1.1–R1.4

H9 (ide pred H10) zavádza **jedinú zápisovú bránu** `HardwareRules.write_gate → [state, reason]` (`state` ∈ `:ok | :degraded | :newer`; čerstvá —
`reload!`, potom `degraded?(path, shape:)` nad súbormi, potom `:newer` nad surovým primárom; výnimky I/O a `ShapeCheckError` sa nechytajú) —
`PACKAGE_H9.md` §15.2 / R15. **H10 ju musí použiť:** `library_check` mapuje `:ok` → `:ok`, `:degraded`/`:newer` → `:blocked` (s vetou `reason`),
výnimka → `:unreadable`. Navrhnutá `write_gate_reason(doc)` **odpadá**. Pred štartom H10a over v maine skutočnú signatúru z H9 a uprav package/testy
(zmena je mechanická, koncept H10 sa nemení → nový audit netreba; ak by sa líšil koncept, zastaviť a vrátiť orchestrátorovi).
