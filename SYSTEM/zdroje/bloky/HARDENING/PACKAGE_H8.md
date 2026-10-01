# PACKAGE H8 · Dielec z inej verzie štandardu (R-13) — blok 9 HARDENING PO V1

> **Autorita:** rozhodnutie Michala 29.9.2026 k R-13 — **ČÍTAŤ**: Kontrola dostane **ORANGE nález „dielec z inej verzie štandardu"** (variant S), pole `std`
> zo štandardu sa **nevypúšťa** (`SYSTEM/AUDIT_REGISTER.md`, R-13 + sekcia „Stav po previerke 29.9.2026"; podklad `SYSTEM/zdroje/PREVIERKA_REGISTRA_2026-09-29.md`
> sekcia 3). Blok 9 (`SYSTEM/PLAN.md`): **bez zmeny výrobných a cenových čísel**.
> **Trieda (§5):** **audit-povinná** (upresnenie dátového kontraktu čítania `std` v STANDARD + nový aditívny kľúč zberu) · **nie výrobná/cenová** · **slepá
> predrecenzia povinná** (z triedy audit) · **in-SU nie je brána** (odporúčaný beh je súčasť DoD, §8) · `codex-po-pr` bez výnimky.
> **Verzia:** patch podľa mainu pri štarte (dnes `0.17.0` → `0.17.1`, ak H1–H7 nezvýšia skôr) + **všetky `?v=`** + prepis STAV.
> **Stav kódu:** sonda nad `main` **`b2dbb3a7`** (v0.17.0, po PR #432). Pred štartom implementácie orchestrátor overí §5.1 (H3 mení semafor Kontroly).

---

## 0 · Sonda pred auditom (skill `codex-audit`, krok 0) — 1.10.2026

Skript `scratchpad/HARDENING/sonda_h8.rb` (Ruby 3.2 cez `tests/helper.rb` — APPDATA = sandbox; do modelu ani do repa sa nič nezapisovalo) + Grep/`git log` nad `b2dbb3a7`.

| # | Tvrdenie o dnešnom kóde | Dôkaz | Výsledok | Verdikt |
|---|---|---|---|---|
| S1 | `Store::STD = 1` (Integer), nikdy sa nezvýšilo; `Store.get` nemá predvolenú hodnotu (chýbajúci kľúč = `nil`) | `core/store.rb:10, 28-31`; sonda S1/S3 | `1 (Integer)`; `Store.get` pri chýbajúcom `std` = `nil` | PRAVDA |
| S2 | `std` sa píše na **9 miestach**, vždy `Store::STD` cez `Store.write`: skrinka `cabinet_builder.rb:2960` (`write_cabinet_attrs`, build aj rebuild), dedup kópie skrinky `:1042`, dielec `:2330` (`add_part` — jediné miesto `kind: 'part'`), nohy `:2382`, referencia spotrebiča `:2455`, úchytkový profil `:2726`; doska `board_builder.rb:833` (`write_board_attrs`), dedup kópie dosky `:697`; zóna `zones.rb:61` | Grep `std: Store::STD`, `kind: 'part'` | 9 zásahov, iný zápis `kind`/`std` do `NOXUN` neexistuje (Grep `set_attribute(.*kind` = 0) | PRAVDA |
| S3 | `std` **nikde nečíta** žiadna vetva pluginu (všetky ostatné `'std'` v `core/` sú značky SÚBOROV, nie entít) | Grep `'std'`/`std:` v `noxun_engine/` | čítanie `std` entity: 0 | PRAVDA |
| S4 | Entita Engine **bez** `std` nevzniká: zápis je v každom builderi od prvého commitu (`f912bea2`, 15.7.2026, **v0.1.0** — skrinka, dielec, zóna); doska `91cae770` (18.7.), nohy `6164abff` (18.7.), profil `baffb6da` (9.8.), referencia `bc43c974` (20.9.). `delete_attribute` v pluginu neexistuje; `Store.write` preskakuje `nil` hodnoty | `git log -S "std: Store::STD"`, Grep `delete_attribute`; sonda S4 | všetky zápisy od začiatku s `std`; `write(std: nil)` kľúč nezapíše | PRAVDA → **legacy (chýba `std`) = len ručná úprava / cudzí producent / budúci kód** |
| S5 | Iný plugin rodiny Noxun do dictionary `NOXUN` nepíše (V2fable/KOVANIE používajú `NOXUN_CORE`/`NOXUN_KOVANIE`) | Grep `set_attribute('NOXUN'` v `C:\APP DEV\RUBY` mimo ENGINE | 0 zásahov | PRAVDA (plugin `vepo_exporter` v Plugins mimo workspace — NEOVERENÉ, len číta) |
| S6 | Hodnoty, ktoré môžu nastať: dnes **len Integer 1**; `newer` až pri budúcom bumpe `Store::STD` na inom PC (D-48 zdieľanie knižníc); `invalid` len ručnou úpravou; `older` dnes nedosiahnuteľné (STD = 1) | S1–S5 | — | PRAVDA |
| S7 | Čítanie so sentinelom rozlíši „chýba" od uloženej hodnoty — vzor `BudgetStore.read_std` (`budget_store.rb:195-202`, `STD_MISSING` `:84`, stavy `std_state` `:174-180`: len `Integer >= 1` je platný marker) | sonda S3, S10 | sentinel sa vráti pri chýbajúcom kľúči; vzor existuje | PRAVDA |
| S8 | **Najlacnejšie miesto čítania = `Bom.collect`** (`bom.rb:56-317`): jeden prechod top-level `ComponentInstance` — skrinka (`:119`), jej výrobné dielce vo vnorenom cykle (`:227-241`, filter `kind part` + `manufactured` + `sheet`), doska (`:249`, `newer_configs` pred filtrom `manufactured` `:263-269`), samostatný dielec (`:283-299`). Vzor aditívneho kľúča: `newer_configs` (`:62`, `note_newer_config :566`, `newer_address :587` → `[id alebo „bez ID (pid N)", pid]`) | čítanie kódu; sonda S7 | `["CAB-007", 4242]` / `["bez ID (pid 4242)", 4242]` | PRAVDA — **žiadny druhý sken modelu netreba** |
| S9 | Zóny sú **groupy** (`zones.rb:55`), `Bom.collect` číta len `ComponentInstance`; proxy kovania a referencie `Bom` nečíta (nie sú `manufactured sheet`) | `zones.rb:55-64`, `bom.rb:117, 227-230` | — | PRAVDA (súlad s previerkou: „proxy, referencie a zóny netreba") |
| S10 | Existujúca brána **nepokrýva** `std`: `newer_config?` porovnáva `config['config_schema']` (skrinka `cabinet_builder.rb:975`, `CONFIG_SCHEMA = 22` `:367`; doska `board_builder.rb:167`, `BOARD_CONFIG_SCHEMA = 2` `:84`) → RED `newer_config` s exportnou bránou (`validation.rb:1110-1124`, `production_core.rb:1200`). O `std` nevie nič. Budúci plugin s vyšším `STD` pravdepodobne zvýši aj schému → pri tom istom kuse by vznikli **dva nálezy** | čítanie kódu | — | PRAVDA → požiadavka R2.4 (novší config má prednosť) |
| S11 | **Exportné brány nečítajú zoznam nálezov Kontroly** — skladajú sa z konkrétnych kľúčov zberu: `newer_config_stop :1200`, `cut_stop :1248`, `hardware_blockers :1429`, `drawer_stop :1525`, `export_blockers :1545` (`dups/cp/newer/hardware`). ORANGE Kontroly ide len do statusu (`control_suffix :1653`) a do sekcie KONTROLA vo VEPO LOGu (`vepo_export.rb:845-858`) | čítanie kódu, Grep `'items']` v `production_core.rb` (jediný výskyt `:2140` = klik) | — | PRAVDA → nový ORANGE export **nezastaví** |
| S12 | `Validation.run` aj `Bom.compute` **ignorujú neznámy aditívny kľúč** (dnešný stav, dôkaz „čísla sa nemenia") | sonda S5/S6 | `run` bez/so `std_issues`: rovnaké; `compute`: rovnaké (1 riadok) | PRAVDA |
| S13 | UI Kontroly je **generické**: riadok = `message_sk` + `owner_id` + oko/ceruzka (`studio.js:433-483`); počty RED/ORANGE a zelené „skriniek bez nálezu" skladá server (`validation.rb:1885-1897`); ORANGE s `owner_id` skrinky ju vyradí zo zeleného čísla | sonda S8 | `{"orange"=>1, "cabinets"=>2, "clean"=>1}` | PRAVDA → **UI sa nemení** |
| S14 | Klik: `pids_for_problem` (`production_core.rb:574`) má vetvy podľa `owner_pid` (`newer_config_entity :664` — top-level skrinka/doska) a `pid` (`standalone_part_entity :681`); bez nich všeobecná vetva podľa `owner_id + part_key` — pri samostatnom dielci by označila **aj jeho dvojča vnútri skrinky** (`:606-646`) | čítanie kódu; headless vzor stubu `test_ghost_d1_dosky.rb:829-1010` | — | PRAVDA → požiadavka R4 |
| S15 | `Bom.collect` **nemá rescue** — výnimka pri čítaní atribútu by zhodila Kontrolu aj všetky exporty (precedens `provenance_marker`, `bom.rb:1061-1080`) | `awk` nad `:56-317` | 0 × `rescue` | PRAVDA → čítanie musí byť bez výnimky (R1) |
| S16 | Headless sady **nevolajú `Bom.collect`** nad fake modelom (overuje sa zdrojom + in-SU); fixtúry Kontroly kľúč `std` ani nový kľúč nemajú → existujúce testy nový nález **nedostanú** | Grep `collect(` v `tests/pure` | len source-scan (`test_kovh1_adhoc.rb:578-596`, `test_1b3_citanie.rb:121`) | PRAVDA |
| S17 | `docs/architecture/model-a-identita.md` odsek `store.rb` uvádza „`config_schema` je dnes `21`" — kód má **22** (ROH-A1) | `:118` vs `cabinet_builder.rb:367` | zastarané | NÁLEZ → opraví sa pri prepise odseku (§11) |

**Opravené tvrdenia oproti zadaniu:** žiadne nepravdivé. Doplnené: S10 (dvojitý nález pri novšej schéme), S14 (klik na samostatný dielec), S15 (bez výnimky), S17.

---

## 1 · Cieľ

Kontrola v Štúdiu **prizná kus, ktorý nesie inú (alebo žiadnu či poškodenú) značku verzie štandardu Noxun**, než pozná bežiaci plugin — jedným oranžovým
riadkom na skrinku, dosku alebo samostatný dielec, s vetou, čo to znamená a čo s tým. Kusovník, VEPO, nákup, rozpočet, ponuka ani exporty sa **nemenia a
nezastavujú**. Stav „píšem, nečítam" (R-13) zanikne a STANDARD §0/§2.1 bude pravdivý („systém ju označí na revíziu"). Príprava na D-48 (zdieľanie knižníc
medzi dvoma PC zvýši miešanie verzií).

## 2 · Rez a odhad

**Jedna dávka, bez rezu. Veľkosť S:** kód pluginu ~150–200 riadkov (`store.rb` ~35, `bom.rb` ~60, `validation.rb` ~70, `production_core.rb` ~10) + testy
~350 + dokumentácia. Pod hranicou 300 riadkov kódu; žiadny nový ovládací prvok.

## 3 · Scope IN

1. `core/store.rb` — čistá klasifikácia značky entity (R1).
2. `core/bom.rb` — aditívny kľúč zberu `std_issues` v **existujúcom** prechode (R2).
3. `core/validation.rb` — ORANGE kategória `std_version`, texty, `stable_key` (R3).
4. `ui/production_core.rb` — jedna vetva klik-resolvera `pids_for_problem` (R4). Nič iné v tomto súbore.
5. STANDARD §0 + §2.1 (+ riadok v §10), odseky architektúry, register, STAV/KRONIKA/PLAN (§11).
6. Headless testy + mutácie; odporúčaný in-SU scenár `run_h8` (§8).

## 4 · Scope OUT

- **Žiadny zápis do modelu:** `std` sa nedopĺňa, neopravuje ani nemigruje; 9 miest zápisu ostáva bez zmeny; `Store::STD` ostáva **1**.
- Žiadna exportná brána, žiadny RED, žiadne tlačidlo opravy v Kontrole (hromadná prestavba je zápis → iná trieda; Q2).
- Buildery, observery, undo, Inspector (⚠ čip = build warnings vybranej skrinky — iná vec), `studio.js`/`studio.html`/CSS (mimo `?v=`).
- Kontrola `std` na zónach, proxy kovania, referenciách spotrebičov a nevýrobných dielcoch (Bom ich nečíta — S9).
- Guard proti prestavbe kusa s **novšou** značkou `std` (dnes nedosiahnuteľné — F3, zásobník).
- Zmena semaforu/počítadiel (to je H3 · A-03).

## 5 · Trieda podľa CLAUDE.md → **audit ÁNO**

- **Audit-povinná (odporúčanie autora, hraničné):** perzistentný kontrakt sa **nemení** (žiadny nový kľúč v modeli, žiadne číslo schémy/STD), ale dávka
  **zavádza záväzný kontrakt ČÍTANIA** poľa zo STANDARD §2.1 — päť stavov (aktuálny / chýba / starší / novší / neplatný) a ich význam pre Kontrolu —
  a nový aditívny kľúč kontraktu `Bom.collect` (vstup všetkých výstupov). CLAUDE.md: „rozhoduje OBSAH zásahu" → zmena dátového kontraktu. Blok 9 to
  predpokladá („kód · audit"). Previerka 29.9. audit nevyžadovala pri čisto ORANGE variante — rozdiel je lacný (S dávka), preto **áno**.
  Nový modul **nevzniká** (R1–R4 v existujúcich súboroch) → bez nového riadku v `docs/ARCHITEKTURA.md`.
- **Výrobná/cenová: NIE.** Nemení rozmery ani počty dielcov, hrany, kusovník, VEPO CSV, nákupné zoznamy, kovanie ani ceny: `Bom.compute` nový kľúč
  ignoruje (S12), brány nečítajú nálezy Kontroly (S11). Viditeľná zmena je **len** v Kontrole, v počte ORANGE v statuse exportu a v sekcii KONTROLA
  VEPO **LOGu** — a len pri kuse s inou značkou (na modeloch Engine dnes žiadny, S4). Dôkaz: charakterizačné/golden testy bez zmeny fixtúr (§7 T2).
- **Predrecenzia: povinná** (audit-povinná trieda). Kód < 300 riadkov, bez nového UI prvku.
- **In-SU: nie je brána** — dávka nemení builder, observer, undo/operáciu, geometriu ani akciu panela zapisujúcu do modelu (klik v Kontrole mení len výber).
  Zber `Bom.collect` sa však headless nedá spustiť (S16) → odporúčaný beh ako súčasť DoD (§8, rozhodnutie D12).

### 5.1 Závislosti — pred štartom implementácie overiť proti mainu

- **H3 (A-03, semafor Kontroly)** mení vety/počítadlá semaforu (napr. „0 z 7 skriniek bez nálezu"). Ak zmení tvar `counts` alebo pravidlo zeleného čísla,
  R3.5 a testy T1e zladiť (nový ORANGE musí ísť tou istou cestou ako ostatné). Pri zmene kontraktu `counts` → krátka delta auditu.
- **H7** zasahuje `production_core.rb` (nastavenia exportu) — R4 je izolovaná vetva v `pids_for_problem`; overiť len čísla riadkov.
- H4 (texty) môže meniť vzor koncovej vety ORANGE („… sa tým nezastavujú") — prevziať aktuálny.
- **Krok 0 — zladenie s mainom `dda3aa53` (v0.17.5, implementátor 1.10.2026):** H3a (PR #435) zmenila len **zobrazenie** semaforu v `studio.js`
  („0 zo 7 skriniek bez nálezu" z existujúcich `counts.cabinets`/`clean`; „N nálezov v M riadkoch" — riadky zlučuje klient len pre UNI skupinu
  `uni_material`). Tvar `counts` ani pravidlo zeleného čísla v `validation.rb` (`counts`, `cabinet_ids`) sa **nezmenili** → R3.5 platí bez zmeny,
  `std_version` je bežný riadok (1 nález = 1 riadok), delta auditu netreba. H4 koncovú vetu ORANGE nezmenila („Nákup ani výroba sa tým
  nezastavujú." v `hardware_note_item`). H7 ešte nie je v maine; R4 sedí na `pids_for_problem` za vetvou `back_cut`. Verzia dávky **0.17.6**.
  Vykonanie A2: záznam samostatného dielca nesie `id` = pôvodné `cabinet_id` (môže byť prázdne) + `pid`; Kontrola z prázdneho ID skladá adresu
  „bez ID (pid N)". A1 sa podarilo **headless** (skutočný `Bom.collect` nad fake modelom, stub `Bom::Sketchup` len na čas zberu); in-SU ostáva
  povinný pre krok 1 (A3).

## 6 · Požiadavky

### R1 · `Store` — klasifikácia značky (čisté, bez výnimky)

- **R1.1** `STD_MISSING = Object.new.freeze` a `Store.read_std(entity)` → `[:missing | :present | :error, raw]` cez
  `entity.get_attribute(DICT, 'std', STD_MISSING)` (vzor `BudgetStore.read_std`). Objekt bez `get_attribute` → `[:missing, nil]`. **`rescue StandardError` →
  `[:error, nil]`** + `Engine.log_error` (S15: výnimka nesmie zhodiť zber).
- **R1.2** Čistá `Store.std_state_of(presence, raw, current: STD)` → symbol:

  | Stav | Podmienka | Význam |
  |---|---|---|
  | `:current` | `:present`, `Integer`, `== current` | v poriadku — **žiadny nález** |
  | `:legacy` | `:missing` | „predštandardová" entita (STANDARD §0) — na modeloch Engine nevzniká (S4) |
  | `:older` | `:present`, `Integer`, `1 <= raw < current` | staršia verzia štandardu — **dnes nedosiahnuteľné** (STD = 1) |
  | `:newer` | `:present`, `Integer`, `raw > current` | novšia verzia (iné PC s novším pluginom) |
  | `:invalid` | `:error`, alebo hodnota nie je `Integer >= 1` (`0`, záporné, `1.0`, `"1"`, `""`, uložené `nil`, `true`, Hash, Array) | poškodená značka |

  Prísne ako R-14 (F3 auditu R-14): žiadne `.to_i`, žiadny fail-open reťazca na „aktuálny".
- **R1.3** `Store.std_state(entity, current: STD)` = `std_state_of(*read_std(entity), current:)`.
- **R1.4** `Store.write`, `Store.get` a všetky zápisy sa **nemenia**.

### R2 · `Bom.collect` — aditívny kľúč `std_issues`

- **R2.1** Pomocná funkcia `Bom.std_issue(kind, id, owner_pid, ents, pid: nil, name: nil, current: Store::STD)` → `nil`, keď sú všetky `ents` `:current`;
  inak **jeden záznam na top-level objekt**:
  `{ 'kind' => 'cabinet'|'board'|'part', 'id' => String, 'owner_pid' => Integer|nil, 'pid' => Integer|nil, 'name' => String|nil,
     'state' => 'newer'|'invalid'|'older'|'legacy', 'std' => Integer|nil, 'count' => Integer, 'total' => Integer }`.
  `state` = najzávažnejší zo stavov kusov v poradí **newer > invalid > older > legacy**; `std` = najvyššia celočíselná značka medzi `newer`/`older` kusmi
  (inak `nil`); `count` = počet kusov mimo `:current`; `total` = `ents.size`. Funkcia berie objekty s `get_attribute` (headless testovateľná s `NxTest::FakeEntity`).
- **R2.2 Čo sa kontroluje** (žiadny druhý sken modelu, S8):
  - **skrinka** (`when 'cabinet'`): `ents = [inst]` + každý vnorený dielec, ktorý **prejde existujúcimi filtrami** cyklu `:227-241` (`kind part`, `manufactured`,
    `sheet`) — pridá sa v tom istom cykle; `std_issue` sa zavolá **po** cykle; adresa `newer_address(inst, cid)` (`owner_pid` = PID skrinky).
  - **doska** (`when 'board'`): `ents = [inst]`, **pred** filtrom `manufactured` (vzor `newer_configs` `:263-269`); adresa `newer_address(inst, bid)`.
  - **samostatný dielec** (`when 'part'`): `ents = [inst]` **za** existujúcimi filtrami; `id` = jeho `cabinet_id`, `owner_pid` = `nil`, `pid` = `entity_pid(inst)`,
    `name` = `Store.get(inst, 'name')`.
- **R2.3** Návrat `collect` dostane `std_issues: std_issues`. `Bom.compute` ho **ignoruje** (ako ostatné aditívne kľúče); nikto iný okrem `Validation.run` ho nečíta.
- **R2.4 Novší config má prednosť:** keď je skrinka/doska v `newer_configs` (`CabinetBuilder.newer_config?(ccfg)` / `BoardBuilder.newer_config?(bcfg)`),
  `std_issue` sa pre ňu **nevolá** — RED `newer_config` už hovorí „z novšej verzie, aktualizuj plugin" a zastaví exporty; druhý (slabší) riadok by bol šum.
- **R2.5 Výkon:** +1 `get_attribute` na skrinku, dosku a výrobný dielec (~270 volaní pri zákazke 250 dielcov), bez JSON parsovania a bez ďalšieho prechodu.

### R3 · `Validation` — ORANGE `std_version`

- **R3.1** `CAT_STD_VERSION = 'std_version'` (komentár pri konštantách ako ostatné) a `check_std_issues(collected[:std_issues], items)` v `run` hneď za
  `check_newer_configs` (`:259`). `nil`/chýbajúci kľúč = kontrola sa preskočí (vzor `placements:` — legacy volania a headless testy bez zmeny).
- **R3.2 Riadok:** `severity ORANGE`, `category`, `owner_id` = `id`, `owner_pid` (skrinka/doska), `pid` (samostatný dielec), `part_key nil`, `hw_key nil`,
  `message_sk`, `stable_key` = `[CAT_STD_VERSION, kind, id, (pid || owner_pid).to_s].join('|')` — dve kópie so zhodným ID sú dva riadky (vzor `back_cut`).
  Záznam s prázdnym `id` sa preskočí (adresa „bez ID (pid N)" z `newer_address` prázdna nie je).
- **R3.3 Text (server je jediná autorita; `part_key nil` → ceruzka neotvára kartu čela):**
  `"<Subjekt><rozsah>: <veta stavu> <rada> Nákup ani výroba sa tým nezastavujú."`
  - Subjekt: skrinka `Skrinka CAB-004` · doska `Doska BRD-002` · samostatný dielec `Samostatný dielec „Bok ľavý" (zo skrinky CAB-004)`.
  - Rozsah (len skrinka, keď `total > 1`): ` (3 z 14 kusov)`.
  - Veta stavu: **newer** „je z novšej verzie štandardu Noxun (značka 2, tento plugin pozná 1)." · **older** „je zo staršej verzie štandardu Noxun (značka 1,
    aktuálna 2)." · **legacy** „nemá značku verzie štandardu Noxun — kus vznikol mimo tohto pluginu alebo bol ručne upravený." · **invalid** „má poškodenú
    značku verzie štandardu Noxun."
  - Rada: **newer** „Plugin ju číta podľa svojej verzie — aktualizuj plugin, kým s ňou budeš ďalej pracovať." · **older/legacy/invalid** skrinka/doska
    „Skontroluj rozmery a materiál; prestavba (zmeň a vráť rozmer v Inspectore) značku doplní." · samostatný dielec „Skontroluj ho ručne — prestavba ho
    nezasiahne."
  - Príklad: *„Skrinka CAB-004 (3 z 14 kusov): nemá značku verzie štandardu Noxun — kus vznikol mimo tohto pluginu alebo bol ručne upravený. Skontroluj
    rozmery a materiál; prestavba (zmeň a vráť rozmer v Inspectore) značku doplní. Nákup ani výroba sa tým nezastavujú."*
  - Texty sú **návrh — Q1**; koncová veta podľa vzoru `hardware_note_item` (`validation.rb:954`).
- **R3.4 Kde sa ukáže:** sekcia Kontrola v Štúdiu (generický riadok, S13), status exportu (`control_suffix`), sekcia KONTROLA vo VEPO LOGu. **Nie** v Inspectore.
- **R3.5 Počítadlá:** +1 ORANGE na riadok; skrinka s nálezom vypadne zo zeleného „skriniek bez nálezu"; samostatný dielec nesie `owner_id` = `cabinet_id`
  pôvodnej skrinky, takže ju zo zeleného čísla vyradí tiež (vedome, vzor samostatného chrbta `back_cut`). Zoradenie: existujúce `sort_items`.
- **R3.6 Exportné brány: NIE.** `std_issues` ani `CAT_STD_VERSION` sa nesmú objaviť v `newer_config_stop`, `cut_stop`, `hardware_blockers`, `drawer_stop`,
  `export_blockers` (stráži test T1h).

### R4 · Klik na nález (`ProductionCore.pids_for_problem`)

Nová vetva **pred** `oid = …` (vedľa vetvy `CAT_NEWER_CFG` `:591`): pri `CAT_STD_VERSION` s `pid` → `standalone_part_entity(model, pid)`; inak s `owner_pid` →
`newer_config_entity(model, owner_pid)` (top-level skrinka alebo doska, aj „bez ID"). Zhoda → `[pid]`; inak **fail-open** na dnešnú všeobecnú vetvu. Oko
aj ceruzka tak označia **presne ten kus** (samostatný dielec nie aj jeho dvojča v skrinke — S14). Žiadny zápis, žiadny krok Späť.

### R5 · Dokumentácia (súčasť dávky)

- **STANDARD §0** (veta o `std`): doplniť, že verziu obsahu configu nesie `config_schema` a `std` je verzia kontraktu dictionary; **„označí na revíziu" =
  ORANGE `std_version` v Kontrole**, nič sa neprepočítava ani neblokuje; **budúci bump `Store::STD`** musí v tej istej dávke rozhodnúť o staršom stave
  (migrácia alebo vedomé prijatie ORANGE nálezov na starých zákazkách).
- **STANDARD §2.1** pod tabuľkou: odsek „Čítanie `std`" — päť stavov R1.2, čo sa kontroluje (skrinky, dosky, výrobné dielce vnorené aj samostatné; zóny,
  proxy a referencie nie), agregácia na top-level objekt, prednosť RED `newer_config`. **§10** (zoznam validácií): jedna odrážka.

## 7 · Testy a DoD

**T1 · `tests/pure/test_h8_std_citanie.rb`** (nový; štruktúra najbližšej sady `test_r14_budget_std.rb` + stub `test_ghost_d1_dosky.rb:829-1010`):
- **a)** `Store.std_state_of` — celá matica R1.2 vrátane `current: 3` (1, 2 → `:older`; 3 → `:current`; 4 → `:newer`) a každej neplatnej hodnoty.
- **b)** `Store.std_state` nad `NxTest::FakeEntity`: zápis cez `Store.write(std: Store::STD)` → `:current`; bez `std` → `:legacy`; `2` → `:newer`; fake, ktorého
  `get_attribute` vyhodí výnimku → `:invalid` **bez výnimky**; objekt bez `get_attribute` → `:legacy`.
- **c)** `Bom.std_issue`: všetko aktuálne → `nil`; skrinka OK + 2 z 5 dielcov bez `std` → `legacy`, `count 2`, `total 6`; mix `newer 2` + `legacy` → `newer`, `std 2`;
  `invalid` + `legacy` → `invalid`; `older` cez `current:`; samostatný dielec nesie `pid` a `name`, nie `owner_pid`.
- **d)** `Validation.check_std_issues`: `nil`/`[]` → nič; každý stav × druh → ORANGE, kategória, presné vety R3.3 (subjekt, rozsah len pri skrinke s `total > 1`,
  rada podľa stavu, koncová veta), `stable_key` s PID; dve kópie so zhodným ID a rôznym PID → **2** riadky po `dedup`; prázdne `id` → nič.
- **e)** `Validation.run` celý: fixtúra **bez** kľúča = bajtovo ten istý výstup ako dnes; **s** kľúčom = presne +1 ORANGE, RED bez zmeny, `clean` −1 pri
  `placements:`; `with_budget` prenesie počty.
- **f)** Zdroj `bom.rb` (vzor `test_kovh1_adhoc.rb:578`): `std_issue` volané v troch vetvách, preskok pri `newer_config?`, návrat `std_issues: std_issues`,
  počet `grep(Sketchup::ComponentInstance)` v `collect` **nezmenený (2)**.
- **g)** Klik (stub z `test_ghost_d1_dosky.rb`): skrinka podľa `owner_pid`; doska bez ID podľa `owner_pid`; samostatný dielec podľa `pid` — **nie** jeho vnorené
  dvojča; zmiznutý kus → dnešná všeobecná vetva.
- **h)** Brány nedotknuté: v `production_core.rb` sa `std_issues` nevyskytuje a `CAT_STD_VERSION` len v `pids_for_problem`; `export_blockers` má dnešnú signatúru.
- **i)** Charakterizácia: `Bom.compute(c.merge(std_issues: [...])) == Bom.compute(c)`; VEPO riadky objednávky zhodné; `VepoExport.log_control` vypíše ORANGE
  riadok (mení sa len LOG).

**T2 · Existujúce sady bez zmeny fixtúr** (dôkaz „čísla sa nemenia"): `test_np4_golden.rb`, `test_ceny_m2_golden.rb`, `test_kova_golden.rb`, `test_kovh_golden.rb`,
`test_np1_vepo_charakterizacia.rb`, `test_validation.rb`, `test_st1b_kontrola.rb`, `test_kovh1_adhoc.rb`, `test_ghost_d1_dosky.rb`, `test_1b3_citanie.rb` (regex
vetvy `pids_for_problem` po `oid =` — nová vetva stojí pred ním) a JS `test_st1b_kontrola.js`, `test_np2_kontrola_klik.js`. Žiadna fixtúra sa nepregeneruje.

**T3 · Mutácie (každá musí zhodiť aspoň jeden test; min. 10):** M1 chýbajúci `std` = `:current` · M2 `"1"`/`1.0` = `:current` (fail-open) · M3 porovnanie
`>=` namiesto `>` (aktuálny = novší) · M4 bez `rescue` v `read_std` · M5 bez preskoku pri `newer_config?` (dvojitý nález) · M6 RED namiesto ORANGE · M7 dielce
sa nezbierajú (len skrinka) · M8 `stable_key` bez PID (kópie sa zlejú) · M9 `std_issues` pridané do `export_blockers` · M10 klik ignoruje `pid` (označí aj dvojča) ·
M11 `state` podľa prvého kusa, nie najzávažnejšieho.

**T4 ·** celá headless sada (`ruby tests/run_all.rb`) + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + encoding guard
(`ruby scripts/encoding_guard.rb --repo`).

**DoD:** T1–T4 zelené · mutácie zapísané v PR · in-SU podľa §8 (alebo priznaná náhrada) · dokumentácia §11 · PR s „Predrecenziou".

## 8 · In-SU — **nie je brána mergu** (odporúčaný beh, súčasť DoD — D12)

Spúšťače z CLAUDE.md sa dávky netýkajú (§5). Jediná vec, ktorú headless nedokáže: **že reálne uložené modely nedajú falošný nález** (typ Integer po
save/reopen, SketchUp `get_attribute` so sentinelom). Scenár `run_h8` v `tests/sketchup/su_runner.rb`, runner `scripts\run_su_tests.ps1 -CloseWhenDone`:
1. **Hneď po otvorení kópie `_dev\ENGINEtests.skp`** (pred stavbou čohokoľvek): `ProductionCore.fresh_collect(model)[:std_issues] == []` — model s kusmi
   z mnohých verzií pluginu, uložený a znovu otvorený = dôkaz nulových falošných poplachov.
2. Postav skrinku, v operácii nastav jednému vnorenému dielcu `std = 2` → 1 záznam `newer`, `count 1`; `abort_operation` → späť `[]`.
3. Doske `delete_attribute('NOXUN', 'std')` → `legacy`; abort → `[]`.
4. `ProductionCore.control_payload` obsahuje ORANGE `std_version`, klik-resolver vráti PID toho kusa.
Zápisy len v kópii testovacieho modelu. Ak je SketchUp obsadený, PR to prizná a krok 1 nahradí smoke bod 1.

## 9 · Riziká

- **Falošné poplachy na reálnych zákazkách — nízke.** Všetkých 9 miest zápisu píše `std: 1` od v0.1.0 (S4), plugin `std` nikde nemaže, iný plugin do `NOXUN`
  nepíše (S5). **KLINIKA (20.8., v0.8.x)** a každá zákazka z Engine by mali mať `std 1` na každom kuse → **žiadny nový riadok**. NEOVERENÉ na samotnom
  súbore (agent netestuje v zákazke) → in-SU krok 1 + smoke bod 1. Lucia (0.16.0) má rovnaké `STD = 1` → miešanie PC dnes nález nevyrobí.
- **Typ po save/reopen** (Integer → Float/String by znamenal `invalid` na každom kuse) — NEOVERENÉ; zachytí in-SU krok 1 okamžite.
- **Budúci bump `Store::STD`:** všetky staršie kusy dostanú ORANGE `older`, kým sa neprestavia → STANDARD §0 (R5) to predpíše rozhodnúť v dávke bumpu.
- **Novšia značka + stará schéma configu** (dnes nedosiahnuteľné): prestavba starším pluginom by značku ticho prepísala na 1 a nález by zmizol → F3.
- **Šum pri cudzích kusoch:** 250 dielcov z iného pluginu = **1 riadok na skrinku** (R2.1), nie 250.
- **Kolízia s H3** (semafor) — §5.1.
- **Pád Kontroly** pri divnom atribúte — vylúčené `rescue` v R1.1 (M4).

## 10 · Smoke checklist pre Michala (po slovensky, funkčne)

1. Otvor **poslednú reálnu zákazku** (napr. KLINIKA) → Štúdio → Kontrola: počty červených a oranžových sú **rovnaké ako pred aktualizáciou** a nikde nie je
   riadok o „verzii štandardu".
2. Na tej istej zákazke: Kusovník, Rozpočet (SPOLU) a VEPO export — **rovnaké čísla** ako predtým (VEPO CSV porovnaj s posledným).
3. Testovacia skrinka (pripraví agent v kópii testovacieho modelu z in-SU behu) s kusom z „inej verzie": v Kontrole je **jeden oranžový riadok** s vetou, čo
   to znamená; klik na oko označí tú skrinku; VEPO export prejde a v LOGu je ten istý riadok.
4. Druhé PC (Lucia): po aktualizácii rovnaká zákazka bez nového riadku.

## 11 · Checklist uzáveru

Bump patch VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** v `ui/*.html` → T1–T4 zelené → **STANDARD** §0, §2.1, §10 (R5) →
**architektúra na mieste:** `docs/architecture/model-a-identita.md` odsek `store.rb` (čítanie `std`, stavy, sentinel; oprava „`config_schema` 21" → 22, S17) ·
`docs/architecture/outputs.md` odseky `validation.rb` (kategória `std_version`), `bom.rb` (kľúč `std_issues`), `production_core.rb` (vetva `pids_for_problem`) →
**AUDIT_REGISTER** R-13 „✅ dávkou H8 (PR #…, v…)" + riadok R-13 v tabuľke „Stav po previerke" → **prepis `SYSTEM/STAV.md`** (nová verzia; veta „R-13 hotové —
Kontrola hlási kus z inej verzie štandardu, čísla bez zmeny") → **KRONIKA** odsek navrch „Záznamy dávok" → **PLAN** riadok H8 ✅ + PR → DOGFOODING bez
zmeny (R-13 nemá D-číslo) → package + surový audit do `SYSTEM/zdroje/bloky/HARDENING/` → **PR popis:** čo sa mení pre používateľa, trieda, sekcia
„Predrecenzia", mutácie, in-SU hlava (alebo priznaná náhrada), „čísla bez zmeny — golden fixtúry nedotknuté". Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora (bezpečnejšia vratná voľba) — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Chýbajúci `std` = nález** (`legacy`, ORANGE) | STANDARD §0 („systém ju označí na revíziu"); na modeloch Engine nevzniká (S4), takže falošné poplachy nehrozia; vrátiť sa dá jedným riadkom | krátko |
| D2 | Neplatná značka prísne (len `Integer >= 1`) | precedens R-14 F3; ORANGE bez brány, takže prísnosť nič nezastaví | nie |
| D3 | Stav `older` existuje v kóde, dnes nedosiahnuteľný | budúci bump `STD` nesmie ticho prejsť ako „aktuálny" | nie |
| D4 | **Jeden riadok na top-level objekt** (skrinka s počtom kusov), nie na dielec | 250 dielcov = 250 riadkov by Kontrolu zahltilo; príčina je spoločná | **áno** |
| D5 | Kontrolujú sa skrinky a dosky vždy, dielce len výrobné (`manufactured sheet`) | to, čo ide do výstupov; bez druhého skenu (S8, S9) | nie |
| D6 | Pri RED `newer_config` sa ORANGE `std_version` pre ten kus nevydá | jeden problém = jeden riadok; RED hovorí viac a blokuje | krátko |
| D7 | ORANGE bez brány a bez tlačidla opravy | rozhodnutie 29.9. (variant S) + blok 9 bez zmeny čísel; tlačidlo = zápis (Q2) | nie |
| D8 | Kód v `store.rb` + `bom.rb` + `validation.rb` + 1 vetva `production_core.rb`; **žiadny nový modul** | najmenší zásah; bez riadku v ARCHITEKTURA | nie |
| D9 | `stable_key` s PID | kópie so zhodným ID = dva riadky (vzor `back_cut`) | nie |
| D10 | Samostatný dielec: `owner_id` = `cabinet_id` pôvodnej skrinky | vzor samostatného chrbta; pomenuje, odkiaľ kus je | nie |
| D11 | Texty s neutrálnym „kus" (bez rodu), bez odkazu na tlačidlo „Prestavať" | existenciu tlačidla som v UI nenašiel (F2) | krátko (Q1) |
| D12 | In-SU beh ako súčasť DoD, hoci nie je brána | jediný dôkaz nulových poplachov na uloženom modeli; lacný | **áno** |
| D13 | UI (`studio.js`) bez zmeny, bez nového JS testu | riadok je generický (S13) | nie |

## 13 · Otázky pre Michala (produktové)

- **Q1 · Text nálezu.** Návrh: *„Skrinka CAB-004 (3 z 14 kusov): nemá značku verzie štandardu Noxun — kus vznikol mimo tohto pluginu alebo bol ručne upravený.
  Skontroluj rozmery a materiál; prestavba (zmeň a vráť rozmer v Inspectore) značku doplní. Nákup ani výroba sa tým nezastavujú."* Je „verzia štandardu Noxun"
  pre dielňu zrozumiteľná, alebo radšej „vznikla v inej verzii pluginu Noxun"? (Do odpovede platí návrh.)
- **Q2 · Tlačidlo opravy.** Má Kontrola pri takom riadku ponúknuť „Prestaviť" (ako pri zastaraných chrbtoch)? **Návrh: teraz nie** — na dnešných zákazkách taký
  kus nevznikne a tlačidlo je zápis do modelu (väčšia dávka s testom v SketchUpe). Vrátiť sa k tomu pri D-48 (zdieľanie knižníc medzi PC).

## 14 · Nálezy mimo scope (návrhy)

- **F1** `docs/architecture/model-a-identita.md:118` — „`config_schema` je dnes 21", kód má 22 (S17). *Opraví sa v H8*, lebo odsek `store.rb` sa prepisuje.
- **F2** Vety `bom.rb:737`, `:785` a `ui/js/core.js:319` odkazujú na tlačidlo „Prestavať" — v `panel.html`/`ui/js` som ho nenašiel (Grep „Prestav"). NEOVERENÉ,
  návrh do H4 (texty).
- **F3** Guard „novšia značka `std` = odmietnuť prestavbu" (vzor R-12 pre `config_schema`) — potrebné až pri prvom bumpe `Store::STD`; do zásobníka po V1.
- **F4** STANDARD §0 tvrdí, že „migračný skript pozná podľa `std`, čo treba dopočítať" — žiadna migrácia `std` nepoužíva (verzovanie nesie `config_schema`);
  veta sa upresní v R5.

---

## 15 · Audit návrhu (Codex, rola audítor audit-povinných, 1.10.2026) — 0 BLOCKER · 4 FIX · 3 NOTE → zapracovanie (orchestrátor)

Surový výstup: `AUDIT_H8_raw.md` (v tom istom priečinku; implementátor ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package).
**Tieto body majú prednosť pred §6–§8 vyššie.**

- **A1 (FIX) · Behaviorálny dôkaz skutočného `Bom.collect`.** T1f (zdroj) a T1i (merge do hotového vstupu) nestačia — zle vložené `next` by vynechalo výrobný
  záznam a testy by ostali zelené. **Požiadavka:** test, ktorý spustí **skutočný `Bom.collect`** nad tými istými entitami s rôznymi `std` (aktuálny / chýba /
  novší / poškodený / výnimka pri čítaní) a overí, že **všetky pôvodné návratové kľúče sú hlboko zhodné** so stavom „všetko aktuálne" a mení sa **len**
  `std_issues`. Pokryť: filtre vnorených dielcov (nevýrobné/nie `sheet`), nevýrobnú dosku, samostatný dielec, chybu čítania `std`, prednosť `newer_config`.
  Najprv skús headless (stuby `Sketchup::ComponentInstance`/model v `tests/helper.rb` alebo vzor `test_ghost_d1_dosky.rb:829-1010`); **ak headless nejde,
  tento test je in-SU scenár a in-SU sa tým stáva bránou mergu H8**. Mutácie (M5, M7 a nová **M12 „`next` pred `records <<` vo vetve dielca"**) musia
  padať na **výsledku zberu**, nie na texte zdroja.
- **A2 (FIX) · Samostatný dielec bez `cabinet_id`.** Nález sa nesmie stratiť: `id` = `cabinet_id`, inak adresa `bez ID (pid N)` (vzor `newer_address`);
  text bez „(zo skrinky …)", keď vlastník nie je známy: *„Samostatný dielec „Bok ľavý": …"*. Test nálezu aj kliku (`pid`). R3.2 „prázdne `id` → preskočiť"
  platí len pre záznamy, ktoré nemajú ani PID.
- **A3 (FIX) · In-SU dôkaz nesmie prejsť naprázdno.** Krok 1 v §8 beží **pred `cleanup`** runnera (výslovne; `su_runner.rb` ~`:170`, `:27821`) a musí vykázať
  **nenulové pokrytie** (počet skontrolovaných uložených skriniek, dosiek a vnorených výrobných dielcov > 0; vypísať čísla do logu). Prázdna vzorka =
  **„NEOVERENÉ"**, nie PASS. **Rozhodnutie orchestrátora: in-SU beh je pre H8 povinný (DoD brána)** — je to jediný dôkaz nulových falošných poplachov po
  save/reopen (A1 + A3 + NOTE A7). Ak SketchUp nepôjde, dávka čaká (nemerguje sa s „neoverené").
- **A4 (FIX) · Veta pri zmiešaných stavoch.** Záznam R2.1 nesie aj rozpis `'states' => { 'newer' => 1, 'legacy' => 2 }`; `count` = počet kusov **s problémom
  značky**. Text: *„Skrinka CAB-004 — značka verzie štandardu Noxun nesedí pri 3 z 14 kusov (1 z novšej verzie, 2 bez značky). <rada podľa najzávažnejšieho>
  Nákup ani výroba sa tým nezastavujú."* Pri jedinom stave rozpis v zátvorke netreba (ostáva veta stavu z R3.3). Test výslednej vety nad zmiešanou agregáciou.
- **A5 (NOTE) · Kópia dosky zmaže nález.** `BoardBuilder.dedup_copies` (`board_builder.rb:674`, `:697`) prepíše `std` na aktuálny pri pridelení nového ID
  (bez prestavby). H8 buildery nemení → **priznať v STANDARD §2.1 (odsek Čítanie `std`) a v §9 Riziká**; F3 v zásobníku rozšíriť na „prestavba **aj dedup
  kópií**" (zápis do `SYSTEM/PLAN.md` zásobník Po V1 jednou vetou).
- **A6 (NOTE) · Zelený počet podľa ID, nie PID.** Existujúci limit `counts` (`validation.rb:292`, `:1891`) — dve skrinky so zhodným ID odpočíta raz, skrinku
  bez ID možno vôbec. H8 semafor **neopravuje**; R3.5 a testy to **priznajú** a zladia sa s H3 (A-03) — T1e overí dnešné správanie, nie ideál.
- **A7 (NOTE) · Trieda potvrdená** (audit áno, výrobná/cenová nie); save/reopen bez reálneho behu = neoverené → pokryté A3.

**Potvrdenia orchestrátora k §12:** D1 áno · D4 áno · D6 áno · D11 áno (Q1 text podľa návrhu, kým Michal neodpovie) · **D12 áno a sprísnené (A3: in-SU
povinné)**. **Q2: bez tlačidla** (návrh platí). Predrecenzia povinná; audit uzavretý (FIX zapracované v package → nový audit netreba).
