# Previerka registra auditu proti aktuálnemu kódu (29.9.2026, main 2a1ff94c, v0.16.0)

> Read-only subagent na pokyn Michala (29.9.2026) — **ktoré nálezy [AUDIT_REGISTER.md](../AUDIT_REGISTER.md) z 29.8. ešte platia** po ~170 PR.
> **Nezáväzný podklad s dôkazmi** — verdikty a poradie pred/po V1 platia podľa sekcie „Stav po previerke 29.9.2026" v registri (po Codex review #424).
> Len čítanie kódu (SketchUp ani testy sa nespúšťali). Kritérium „pred V1" = pravidlo bloku 1d: výrobné/cenové riziko, strata dát používateľa
> alebo blokovanie V1 rozsahu (po review #424 spresnené — plné znenie kritéria v registri, sekcia „Stav po previerke 29.9.2026"). Riadky kódu k 2a1ff94c — pri práci sa orientovať podľa mien metód.

## 1 · Verdikty

| R | Verdikt | Dôkaz (dnes) | Pred/po V1 | Veľk. | Funkčný dopad |
|---|---|---|---|---|---|
| R-05 | platí | `hardware_sets.rb` `PER_KINDS = %w[unit owner]` | po V1 (rozhodnuté pri uzávere KOVANIA) | M | set nevie „1 ks na N nôh"; nákup sedí vďaka pravidlu príchytu podľa šírky |
| R-09 | platí | `seed_version` sa zapisuje vždy ako konštanta (`hardware_sets.rb`, `hardware_rules.rb`) | po V1 | S | po návrate na starší plugin a späť sa zmazané predvolené sety/pravidlá vrátia |
| R-10 | platí | `hw_sets.js` `hwsSlug`; server berie `set_id` od klienta | po V1 | S | identitu nového setu určuje okno |
| R-13 | platí | `std` sa píše na 9 miestach, nečíta nikde (sekcia 3) | **Michal 29.9.: robiť** | S | dielec z inej verzie štandardu Kontrola neoznačí |
| R-15 | platí | `production_core.rb` 3803 r. (august 1834); `OutputPackage` neexistuje | po V1 | L | bez priameho dopadu; zmeny exportov sú drahšie |
| R-16 | platí | `budget.rb` `sheet_label`/`abs_label` bez výrobcu; `cp_export.rb` | hraničné (XLSX má kód a dodávateľa) — rozhoduje Michal | M | dva rovnaké dekory od dvoch výrobcov majú v rozpočte rovnaký názov riadku |
| R-17 | platí | `validation.rb` — množina `cabinet_id` z placements | po V1 | M | zelené číslo „čistých skriniek" je nadsadené pri spoločnom/chýbajúcom ID |
| R-18 | platí | `budget.js` `sent=true` pred frontou; párovanie výsledku len podľa mena operácie | po V1 (hlásená strata neuložených hodnôt — červený status) | S | pri súbehu úpravy bunky a ⋯ editora sa rozpísané hodnoty môžu stratiť |
| R-19 (zvyšok) | platí | `production_core.rb` — tá istá veta dvakrát, bez druhu | po V1 | S | upozornenie na spoločné ID nerozlišuje skrinku a dosku |
| R-20 | platí | `production_core.rb` `materials_meta`; `studio.js` `m.label \|\| s.mid` | po V1 | S | materiál kupovaný len pre dupláky sa v Platniach ukáže ako holé ID |
| R-21 | platí | `studio.js` súčty Platní/ABS ignorujú filter | po V1 | S | pri filtri súčet ukazuje celú zákazku bez označenia |
| R-22 | platí | `production_core.rb` — hlásenie firewall až po `write_book`, komentár klame | po V1 | S | upozornenie na interné pojmy v ponuke príde až po uložení |
| R-23 (2)+(3) | platí | Tab-trap 3× (`form.js`, `settings.js`, `md_appearance.js`); 10 ručných modálov | po V1 | M | klávesnica v ručných modáloch je riešená kópiami |
| R-24 | platí, zhoršené | 14 kópií HTML-escapera, 3 css-escapery, 4 NFD normalizácie; surové U+0300/U+036F v `hw_sets.js` | po V1 | S | hľadanie/escapovanie sa správa rôzne |
| R-25 | čiastočne | PR #350 (ČELÁ-B2, v0.10.8) — cesta skrinky ide cez `nxCabinetAction` s `validateFields`; pri vybranej doske `nxCabinetAction` skončí a relay ide na `studio_do_select` bez kontroly `#boardCard .bad` (`bridge.js`) | po V1 | S | klik na riadok Štúdia zahodí rozpísanú neplatnú zmenu dosky |
| R-26 | platí, zdvojené | `grain_check.rb` `restore!` nerozposiela stav; rovnako `direction_check.rb` | po V1 | S | po otvorení Štúdia prepínač v Inspectore ukazuje „vypnuté", hoci kresba beží |
| R-27 | čiastočne | (a) „1,0 mm" a (b) „pravidlo sa neuplatní" platia; (c) hint „Rozpočet mení model" zanikol | po V1 | S | texty v Pravidlách sú nepresné |
| R-28 | platí | `bom.rb` filtruje len existenciu dielca; core má `HardwareRules.override_orphan_kind` (D-132), používa ho len panel | po V1 | S | neúčinný ručný zásah kovania sa v Pravidlách kreslí ako aktívny |
| R-29 | platí | `studio.js` nemá `scrollTop` | po V1 | S | prepnutie sekcie Štúdia vráti zoznam na začiatok |
| R-30 | platí, spúšťač zanikol | rozhodnutie malo padnúť pri D-95, tá je od 6.9. vyradená | po V1 | S (rozhodnutie) | jantárové riadky sa po zápise z Inspectora neobnovia samy |
| R-31 | platí | `production_core.rb` — kľúč = cesta .skp; `project_name` pri čítaní aj zapisuje | po V1 | L | názov zákazky je viazaný na cestu a počítač |
| R-32 | čiastočne | z 18 stubov ostalo 5 prázdnych (`model-a-identita.md` debug · `ui-lifecycle.md` actions_settings, actions_usage, usage_stats · `outputs.md` kontrakt `estimate`) + 4 kostrové | po V1 | S | agent musí pri zásahu čítať kód |
| R-33 | platí (docs) / neisté (testy) | D-87 bez vlastného nadpisu v `DOGFOODING_vyriesene.md` | po V1 | S | používateľ nič nepocíti |
| R-35 | platí | `hardware_rules.rb` a `dim_series.rb` — úplná náhrada bez revízie | **PRED V1** (tichá strata uložených dát) | S/M | pri dvoch oknách SketchUpu sa prvá zmena pravidiel/radov ticho stratí |
| R-36 | platí (len macOS) | `scale_observer.rb` erase bez dokumentu | po V1 | M | na macOS môžu ostať neupratané zóny |
| R-37 | platí, zúžené | hlavne `supplier_settings.rb` — prázdne `{}`/`[]` → seed → auto-zápis; `json_file_store.rb` uloží zlý obsah do `.bak` | **PRED V1** | S | pokazený, ale platný JSON nastavení dodávateľa sa ticho nahradí predvolenými sadzbami a prerezom/orezom a zničí dobrú zálohu |
| R-38 | platí | `production_core.rb` vepo_settings bez degraded guardu, výsledok zápisu ignorovaný | hraničné (len pri poškodenom súbore, bez výrobného/cenového čísla) — rozhoduje Michal | S | poškodený súbor VEPO nastavení sa môže ticho prepísať staršou zálohou |
| R-39 | platí (brána správne otvorená) | smer dvierok žiadny výstup nespotrebúva; číta ho len Kontrola RED | — | S (docs) | dnes bez dopadu; znenie registra zastarané (sekcia 4) |
| R-40 | platí | ručné kovanie ide cez prestavbu (`actions_cabinet.rb`) | po V1 | S/M | pridanie ručnej položky kovania prestaví celú skrinku |

## 2 · Pred V1

Kritérium: výrobné/cenové riziko · **tichá strata uložených dát pri bežnej práci** · pri poškodenom súbore len tichá strata, ktorá mení výrobné alebo cenové
čísla · blokovanie V1 rozsahu (hlásená strata neuložených hodnôt = po V1).

1. **R-37** (S) — strata dát (zničená záloha) a tichá zmena cien aj prerezu/orezu (rozpočet, Kontrola, nárezový plán). Nízka pravdepodobnosť (ručne alebo cudzím nástrojom upravený súbor).
2. **R-35** (S/M) — pri dvoch otvorených oknách SketchUpu sa prvá zmena globálnych pravidiel kovania alebo rozmerových radov ticho stratí (pravidlá kovania menia nákup). *Pôvodne tu bola ako hraničná — opravené po Codex review #424.*
3. **R-13** (S) — rozhodnutie Michala 29.9.2026 (čítať).

Hraničné: **R-38** (len pri poškodenom súbore VEPO nastavení; názvy zákaziek a zlúčenie 18/36 menia pomenovanie a členenie výstupu, nie rozmery, počty ani ceny) ·
**R-16** (XLSX rozlíši kód a dodávateľ). **R-18** je po V1 (hlásená strata neuložených hodnôt).
O zaradení pred V1 rozhoduje Michal.

## 3 · R-13 — podklad pre dávku

- `Store::STD = 1` sa od začiatku nezvýšilo; verzovanie prevzali `CONFIG_SCHEMA`, BuildPlan `SCHEMA` a markery súborov.
- **Zápis (9 miest cez `Store.write`):** `cabinet_builder.rb` (dedup kópie, part, hardware nohy, reference/telo spotrebiča, hardware proxy, cabinet) ·
  `board_builder.rb` (dedup, board) · `zones.rb` (zóna).
- **Návrh čítania:** čistý klasifikátor stavu (`current` / `legacy` = kľúč chýba / `newer` / `invalid`) v existujúcom prechode `Bom.collect`
  (skrinka, vnorený dielec, doska, odpojený dielec) → aditívny kľúč zberu podľa vzoru `newer_configs` → ORANGE kategória vo `Validation.run`
  bez exportnej brány, s `owner_pid` kvôli kliknutiu. Proxy kovania, referencie a zóny netreba.
- **Kontrakt:** perzistentný sa nemení (žiadny nový kľúč ani schéma); STANDARD §2.1 pole už predpisuje a „predštandardovú" entitu má systém
  „označiť na revíziu" — dávka len doimplementuje znenie a doplní vetu o štyroch stavoch. Audit podľa CLAUDE.md nie je povinný; ak by `newer`
  alebo `legacy` malo blokovať export alebo byť RED, ide o spresnenie kontraktu → krátky audit.
- Prakticky nález vznikne len pri cudzích, ručne kopírovaných alebo predštandardových entitách (novší plugin chytá R-12).

## 4 · Postrehy k registru (zapracované v tom istom PR)

- R-25 čiastočne (#350 chráni cestu skrinky, nie dosky) · R-27c zanikla · R-32 z veľkej časti hotová.
- **R-39:** D-95 je vyradená — spúšťač brány preformulovať na „prvý výstup, ktorý použije smer dvierok (vŕtanie, CNC)". Register tvrdí „žiadny default
  smeru", hoci od ROHOVEJ platí schválená výnimka R7 (nová rohová dostane smer pri rohu, `STANDARD.md`); v rozpore je len znenie, nie brána.
- **R-30:** spúšťač (D-95) zanikol — rozhodnutie (ručný refresh so žltým indikátorom áno/nie) môže Michal urobiť rovno.
- **R-40:** podmienka čiastočne splnená — S1-C pridal úzku cestu zápisu configu bez prestavby pre očakávaný spotrebič (`actions_appliance.rb`);
  pri R-40 zvážiť zjednotenie namiesto tretej cesty.
