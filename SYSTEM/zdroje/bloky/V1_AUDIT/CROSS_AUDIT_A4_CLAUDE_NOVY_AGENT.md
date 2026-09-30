# Krížový audit V1 — A4 · Claude Code subagent, Claude Opus 5.5 („nový agent", test zaúčania S6)

Rozsah: celé som prečítal ≈ 0,5 MB. Išlo o `CLAUDE.md`, `.claude/agents/implementator.md`, STAV, PLAN, DOGFOODING, README (SYSTEM), `docs/ARCHITEKTURA.md`, `docs/UI_DIZAJN.md`, VEPO_KONTRAKT, SKETCHUP_PRAVIDLA, podklad a úvod AUDIT_REGISTRA. K tomu som prečítal dotknuté odseky v `construction.md`, `outputs.md`, `model-a-identita.md`, `materials.md`, `ui-lifecycle.md` a v STANDARD §3, §4, §8 a §11. Zvyšok povinného čítania má ≈ 1 MB (celé `ui-lifecycle.md`, `hardware.md`, STANDARD §6–§7). Ten som zmeral cez `wc -c` a prehľadal Grepom. Worktree `orch-v1audit` je na `6d59edef` (= `main` 4da1c3b5 + podklad). Repo som len čítal.

Postup: pre dve vymyslené dávky som išiel doslova podľa tabuľky „Povinné čítanie podľa typu práce" (`CLAUDE.md:12–23`, „platia VŠETKY" `:25`):
- **T1** = „pridaj do Kusovníka v Štúdiu stĺpec Hmotnosť dielca",
- **T2** = „pridaj nový typ skrinky horná rohová".

Na prepočet na tokeny som použil jedno meranie: nástroj Read hlásil pri `PLAN.md` 111 507 B = 55 755 tokenov, teda ≈ 0,5 tokenu na bajt.

---

## Os D — dokumenty a workflow (hlavná os)

### CN-01 · D · Tabuľka povinného čítania posiela na celé obrie súbory — T1 ≈ 1,0 MB, T2 ≈ 1,55 MB
- **Čo:** Ak agent plní tabuľku doslova, pre T1 musí prečítať ≈ 996 kB (≈ 0,5 M tokenov) a pre T2 ≈ 1 553 kB (≈ 0,78 M tokenov). To je 50–78 % kontextového okna ešte pred prvým riadkom kódu. Užitočných bolo ≈ 35–40 kB (≈ 3–4 %). Najdrahší je riadok UI: posiela na celý `ui-lifecycle.md` (541,7 kB), hoci riadok pre Ruby hovorí „odseky dotknutých modulov". Dôsledok: agent buď povinnosť poruší (číta výberovo, ale bez návodu), alebo zahltí kontext. Návrh:
  - pri každom súbore nad ~50 kB písať do tabuľky **odsek alebo kotvu**,
  - riadok UI zmeniť na „UI_DIZAJN §1–§3 + odsek dotknutej sekcie alebo kontextu v ui-lifecycle (Grep podľa nadpisu)",
  - doplniť vetu o rozpočte čítania (napr. ≤ 150 kB na dávku; viac = výťah od orchestrátora).
- **Dôkaz:** `CLAUDE.md:15` (riadok UI bez „odsek") vs `:13` („odseky dotknutých modulov"); tabuľka nameraných kB nižšie; Read: PLAN 111 507 B = 55 755 tokenov.
- **Scenár:** S6 (nepriamo aj S1–S5 — každá ďalšia dávka platí tú istú daň)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie
- **Návrh zaradenia:** HARDENING — čisto dokumentačná zmena na menej ako deň, ktorá zlacní každú ďalšiu dávku.
- **Overenie nezmeneného výstupu:** docs-only. `ruby tests/run_all.rb` zelené (guard `test_docs_navigacia.rb` — odkazy, router) a `git diff --stat` bez `noxun_engine/`.

### CN-02 · D · Chýba mapa „kde sa rozširuje": nový typ skrinky, nová rola dielca, nový stĺpec Kusovníka
- **Čo:** Pri T2 som ani po celom povinnom čítaní nevedel, ktoré miesta treba zmeniť.
  - Zoznam miest, kde sa kód vetví podľa typu, existuje len na dvoch miestach:
    - v **archíve** `SYSTEM/archiv/bloky/ROHOVA/FAKTY_Z_KODU_2026-09-27.md` §1.2 (≈ 25 miest pre typ) a §2.6 (≈ 20 zoznamov rolí) — k v0.14.0, s číslami riadkov, ktoré sa už posunuli;
    - čiastočne v `ui-lifecycle.md` pod nadpisom „Ostatné → CONSTRUCTION_FIELDS".
  - Kód má dnes typ skrinky v 6 JS registroch (`CAB_TYPES`, `INSERT_TYPES`, `NX_TYPE_LABEL`, `TYPE_LIMITS`, `LEGS_INSERT_TYPES`, `templateType`) a v Ruby (`TYPES`, `MIN_BY_TYPE`, `sync.rb DEFAULTS`). Literál `'upper'` je v kóde 32× v 13 súboroch a pri každom výskyte treba rozhodnúť, či platí aj pre „hornú rohovú".
  - Pri T1 docs nespomínajú definíciu stĺpcov `COLS` a `cellValue` v `studio.js` — len `localStorage nx_bom_cols`.

  Návrh: jeden odsek „Rozširovacie body" v `docs/architecture/` s menami konštánt, nie číslami riadkov. Pokryť nový typ, novú rolu, stĺpec Kusovníka, sekciu Štúdia a typ kovania. K tomu guard test, ktorý overí, že registre z odseku v kóde existujú a že Ruby `TYPES` sa zhoduje so všetkými JS registrami.
- **Dôkaz:** `archiv/bloky/ROHOVA/FAKTY_Z_KODU_2026-09-27.md:39–44`; `ui-lifecycle.md:4085–4092`; `core.js:1196`, `:1603`; `insert_state.js:40`; `form.js:186`; `hardware.js:2468`; `scale_observer.rb:30`; `cabinet_builder.rb:71`; `studio.js:78–88`, `:287–303`; `grep "'upper'"` = 32 výskytov v 13 súboroch.
- **Scenár:** S6 (+ S1, S5)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — skráti S1 (rohová K3 zasiahla 22 súborov, S1-E 48) aj S5 a kód nemení.
- **Overenie nezmeneného výstupu:** docs + nový guard test; `noxun_engine/` bez zmeny, headless aj JS sady zelené.

### CN-03 · D · Pravidlá kovania a ABS viazané na typ skrinky nie sú v žiadnom povinnom dokumente — T2 by vynechal závesy na stenu
- **Čo:** Seed pravidlo `zavesenie-hornej-skrinky` („Bystrica", 2 ks na hornú skrinku) sa filtruje cez `cabinet_type: ['upper']`. Nový typ „horná rohová" by bez úpravy seedu, zvýšenia `SEED_VERSION` a „Doplniť nové predvoľby" v existujúcich projektoch **nedostal závesné kovanie**. V nákupe aj v cene by ticho chýbala položka. `hardware.md` (208 kB, povinný pre kovanie) typ skrinky ani rohovú nespomína ani raz, takže pravidlo som našiel až v kóde. Rovnako funguje ABS predvoľba novej roly (ABS `SEED_VERSION`), ktorá je opísaná len pri ROH-A1 v `materials.md`. Návrh:
  - v `hardware.md` odsek „Pravidlá viazané na typ skrinky a podporu" (rule_id · filter · čo sa stane pri novom type),
  - odkaz naň z mapy CN-02,
  - do riadku „kovanie" v CLAUDE.md doplniť spúšťač „aj nový typ skrinky alebo nová rola".
- **Dôkaz:** `hardware_rules.rb:313–317`, `:1308–1309`; `grep corner|rohov docs/architecture/hardware.md` = 0 zhôd; `materials.md:548–556`. Archív to vedel už pred K3 (`FAKTY_Z_KODU…:41`, „Bystrica len `upper`"), ale nepreniklo to do živých dokumentov.
- **Scenár:** S6 (+ S1)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie (zmena je dokumentačná; chráni budúcu výrobnú dávku S1)
- **Návrh zaradenia:** HARDENING — lacné a bez toho je S1 „horná rohová" výrobné riziko.
- **Overenie nezmeneného výstupu:** docs-only (`git diff --stat` bez `noxun_engine/`).

### CN-04 · D · Chýba jeden zoznam schém a verzií dát
- **Čo:** Pri T2 rozhoduje o povinnom audite návrhu zvýšenie schémy (`CLAUDE.md:59–62`), lenže čísla sú v 5+ dokumentoch:
  - `CONFIG_SCHEMA` 22 (STAV, STANDARD §2.5),
  - BuildPlan `SCHEMA` 7 (`model-a-identita.md`),
  - ABS `SEED_VERSION` 6 (`materials.md`, STANDARD §7.5),
  - `SEED_VERSION` pravidiel kovania,
  - `TemplateStore::STD` 7 (STANDARD §4.4),
  - `BOARD_CONFIG_SCHEMA`, `BUDGET_STD` 3, katalóg `SCHEMA` 12, `PartKeys::SCHEMA`,
  - aktivačné konštanty `DRAWER_/HINGE_/LIFT_/BACK_CUT_ACTIVATION_SCHEMA`.

  Zoznam zmien `CONFIG_SCHEMA` v STANDARD §2.5 je neúplný a mimo poradia (5, 7, 6, 10, 11, 14, 17 … 22; chýbajú 8, 9, 12, 13, 15, 16). Sekcia „Kompatibilita" v STAV drží len časť. Návrh: jedna tabuľka „Schémy a verzie dát" (konštanta · súbor · aktuálna hodnota · čo vyžaduje zvýšenie · ktorú bránu stráži) na jednom mieste. Guard test by hodnoty čítal z kódu, aby tabuľka nemohla zastarať.
- **Dôkaz:** `STANDARD.md:214–283` (poradie odrážok); `model-a-identita.md:151`; `STAV.md:25–30`; `cabinet_builder.rb:367`.
- **Scenár:** S6 (+ S1; S2 — zdieľané knižnice budú potrebovať verzie per katalóg)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie
- **Návrh zaradenia:** HARDENING — rozhoduje o audit-povinnosti každej dávky, ktorá mení kontrakt.
- **Overenie nezmeneného výstupu:** docs + guard, ktorý číta konštanty; kód bez zmeny.

### CN-05 · D · STAV.md (vstupný bod) po dokumentačnom PR zastará a protirečí PLANu
- **Čo:** STAV hovorí:
  - „smoke čaká",
  - „Robí sa: Smoke bloku CENY",
  - „Pred uzáverom V1 ostávajú R-13 → R-37 → R-35 (PLAN blok 4)".

  PLAN aj AUDIT_REGISTER hovoria smoke PASS 30.9. a R-13/R-37/R-35 **po V1**. Nový agent číta STAV ako prvý, takže dostane zlý obraz projektu. Príčinou je pravidlo „Dokumentačné PR STAV nemenia" (STAV sa prepisuje len so zvýšením VERSION). Každý dokumentačný PR s Michalovým rozhodnutím tak nechá STAV pozadu až do ďalšej kódovej dávky. Návrh: dokumentačný PR, ktorý mení stav bloku alebo poradie, smie (a musí) prepísať sekcie „Robí sa" a „Ďalší krok". Alebo guard test: blok, ktorý má v PLAN „smoke PASS", nesmie mať v STAV „smoke čaká".
- **Dôkaz:** `STAV.md:9`, `:19–20`, `:35–46` vs `PLAN.md:39`, `:230–232`, `:635–638`; `AUDIT_REGISTER.md:23`; pravidlo v `CLAUDE.md:140`, `STAV.md:5`, `README.md:100`; commit `7b3f9d71` (#431, smoke PASS, dokumentačný PR).
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie
- **Návrh zaradenia:** HARDENING — mení pravidlo workflowu (rozhodne Michal); samotná úprava je niekoľko viet.
- **Overenie nezmeneného výstupu:** docs-only.

### CN-06 · D · PLAN.md má 86 % textu z hotových blokov a zadaní; trvalé pravidlá sú na konci
- **Čo:** Riadok „novú dávku" posiela do PLAN (111,5 kB ≈ 56 k tokenov).
  - **Hotové:** 1b/1d/1e ≈ 22,8 kB, blok 4 ≈ 58 kB (z toho zadania NÁSTROJE-1, GHOST-D1 a GHOST-D2 ≈ 48 kB), blok 6 ≈ 15 kB (D-52) — spolu ≈ 96 kB.
  - **Živé:** ≈ 11–14 kB (zásobník 5,2 · trvalé pravidlá 2,8 · blok 3).
  - **Prečo to tam ostalo:** README hovorí „Hotový blok nesmie zostať v PLAN". Bloky 1b/1d/1e/4/6 sa však nikdy formálne neuzavreli a guard kontroluje len nadpisy.
  - **Zastarané:** nadpis 1b „(… pred blokom KOVANIE)" a veta „revízia sa ešte NEKONALA", hoci je všetko hotové.
  - **Duplicity v zásobníku:** horná rohová `:654` a `:657`; D-48 na `:529`, `:649–650` (2× v jednej odrážke) a `:655`.
  - **Úžitok pre T1/T2:** T1 z PLANu nepotreboval nič, T2 ≈ 3 kB (zásobník + „Hranica TYP vs ŠABLÓNA" úplne na konci súboru).

  Návrh: formálne uzavrieť 1b/1d/1e a hotové časti blokov 4 a 6 a presunúť ich do archívu (ROADMAP_hotove_etapy); v PLAN ostane ≈ 15 kB. Pridať strop veľkosti PLAN strážený guardom, ako má STAV.
- **Dôkaz:** `PLAN.md:42–45`, `:278–523`, `:531–630`, `:633–664`, `:677–687`; `README.md:72–75`; namerané bajty.
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — presun textu, žiadne nové pravidlo.
- **Overenie nezmeneného výstupu:** docs-only; `test_docs_navigacia.rb` (odkazy, nadpisy PLANu) zelený.

### CN-07 · D · Záväzný kontrakt Kusovníka (UI20_KONTRAKT) nie je v tabuľke — T1 by ho zmenil bez vedomia
- **Čo:** Predvolené aj voliteľné stĺpce Kusovníka určuje `SYSTEM/zdroje/ui20/UI20_KONTRAKT.md` (Š2). Mockup Štúdia je tam „záväzná vizuálna referencia" a README ho vyhlasuje za jediný trvalo záväzný súbor vo vrstve `zdroje/`. Riadok UI v tabuľke ho nemenuje, takže T1 by pridal stĺpec bez úpravy kontraktu a bez Michalovho rozhodnutia. Kontrakt je navyše sčasti zastaraný: `:357` „hmotnosť zatiaľ „—" do fázy 3". Návrh: platné časti „ŠTÚDIO KONCEPT" (Š1–Š19 + §7 odchýlky) preniesť do odsekov sekcií v ui-lifecycle (alebo do UI_DIZAJN) a UI20 archivovať; dovtedy ho aspoň doplniť do riadku UI.
- **Dôkaz:** `UI20_KONTRAKT.md:425`, `:439–440`, `:357`; `README.md:41–45`; `CLAUDE.md:15`.
- **Scenár:** S6 (+ S5)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** HARDENING — hneď aspoň odkaz v tabuľke; presun textu môže počkať, ak nebude čas.
- **Overenie nezmeneného výstupu:** docs-only.

### CN-08 · D · Nadpisy nezodpovedajú produktu — Kusovník nemá vlastný odsek
- **Čo:** Grep podľa mena modulu funguje, Grep podľa funkcie produktu („Kusovník", „stĺpec") nie. Konkrétne:
  - **ui-lifecycle.md:**
    - Kontrola, Nákup, Spotrebiče, Rozpočet, Ponuka a Nárezový plán majú vlastný nadpis.
    - **Kusovník, Materiály, Kovanie a Pravidlá** sú v jednom 61 kB odseku „studio_dialog.rb + … (ŠT-1a)", ktorý začína históriou („PREMOSTENIA ZANIKLI", „PRODUCTION_BRIDGES … ZANIKLI").
    - Registre typu rohovej sú pod „Ostatné → CONSTRUCTION_FIELDS".
    - Nadpis „ZÁMOK ODOSLANIA OPEN.busy (review #2)" (19 kB) je pomenovaný podľa kola review.
    - Formát hmotnosti pre T1 (`nxCabWeight`) je v 31 kB odseku Inspectora „Obsah Korpusu", nie v Štúdiu.
  - **outputs.md:** „## Bez vlastného odseku" stojí nad `bom.rb` a 9 ďalšími modulmi, ktoré vlastný odsek majú. Odsek `bom.rb` začína vetou „správanie je popísané v odsekoch, ktoré ho volajú".
  - **UI_DIZAJN:** „§4 Ikony" obsahuje aj Rozpočet, D-92, D-102, D-105 a combobox; §5.12 stojí za §5.13.
  - **STANDARD:** „§3 Jednotky" začína odsekom o referenciách v pláne.

  Návrh: jeden nadpis pre každú zo 14 sekcií Štúdia; v `outputs.md` zrušiť zavádzajúci H2; v UI_DIZAJN presunúť E-b/D-xx pod §5.
- **Dôkaz:** `ui-lifecycle.md:2375–2391`, `:684–692`, `:4077–4092`; `outputs.md:622–626`; `UI_DIZAJN.md:245–499`, `:1313`, `:1448`; `STANDARD.md:336–341`.
- **Scenár:** S6 (+ S5)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** HARDENING — štrukturálny presun bez zmeny obsahu, strážený existujúcim guardom.
- **Overenie nezmeneného výstupu:** docs-only. `test_docs_navigacia.rb` (`nx_arch_headings` — každý modul má `### <modul>`) musí ostať zelený, preto nadradený nadpis `studio_dialog.rb` ostáva.

### CN-09 · D · Zastarané a protirečivé vety, na ktoré T1 a T2 narazia (overené proti kódu)
- **Čo:** Deväť viet v platných dokumentoch klame alebo si odporuje. Nový agent nevie, ktorej veriť, a overuje v kóde:
  1. `construction.md:540` „`TYPES` = lower upper dishwasher" vs `:242` a `cabinet_builder.rb:71` (4 typy vrátane `corner_blind`).
  2. `UI_DIZAJN.md:700` „Hmotnosť („—" …, príde s kovaním fáza 3)" vs `panel.html:327` a `ui-lifecycle.md:686` (riadok od KOV-W v0.9.47 ukazuje kg). To isté `UI20_KONTRAKT.md:357`.
  3. `UI_DIZAJN.md:195–197` „semaforové tokeny sa nikde nepoužívajú" vs `studio.html:283–293` (Kontrola ich používa).
  4. `UI_DIZAJN.md:1096–1100` „výklop zatiaľ NEvyberateľný … AVENTOS ručne": text v kóde neexistuje a výklop je vyberateľný od KOV-A1/E.
  5. `UI_DIZAJN.md:336` „inventár ikon je úplný k v0.7.28", hoci ikony pribúdali ďalej (napr. `cab-corner`, ROH-B2).
  6. `model-a-identita.md:151` hovorí BuildPlan `SCHEMA` 7, ale `:197` a `:208` „`SCHEMA` ostáva **5**" (história v prítomnom čase). Zoznam zmien je v poradí 6→7, 2→3, 4→5, 3→4, 5→6.
  7. `VEPO_KONTRAKT.md:55` (skratky rohovej) a `STANDARD.md:426` (rozsahy) majú stále „návrh, potvrdí Michal", hoci blok ROHOVÁ má smoke PASS 28.9.
  8. `ARCHITEKTURA.md:16` „Architektúra (v0.5.32)"; `CLAUDE.md:15` a `UI_DIZAJN.md:3` hovoria o „satelitných oknách", ktoré zanikli v ŠT-4a.
  9. `outputs.md:632` „hmotnosť ostáva z geometrie" vs `materials.md:484` „hrúbka do hmotnosti ide z katalógu, nie z deskriptora". Obe platia, ale v inom kontexte (snapshot vs plán). Bez vysvetlenia pôsobia ako rozpor presne v T1.

  Návrh: jedna dokumentačná dávka „rozpory" + do checklistu uzáveru dávky bod „prehľadaj Grepom tvrdenia o zoznamoch, ktoré dávka mení (typy, ikony, schémy)".
- **Dôkaz:** riadky uvedené v zozname.
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — pol dňa, nič sa nepočíta.
- **Overenie nezmeneného výstupu:** docs-only.

### CN-10 · D · Trvalé pravidlá sú na viacerých miestach a každé tvrdí inú „autoritu"
- **Čo:**
  - **„Vertikálny priestor je vzácny"** je na 5 miestach:
    - `CLAUDE.md:15` posiela do PLAN (koniec 111 kB súboru),
    - `ARCHITEKTURA.md:104` tvrdí „plné znenie je v ui-lifecycle, sekcia Ostatné" — tam je jedna veta,
    - ďalej UI_DIZAJN §1 a `V1_VIZIA.md:61`.
  - Autoritu teda určujú dve miesta rôzne: README (r. 24) a CLAUDE.md hovoria PLAN, ARCHITEKTURA hovorí ui-lifecycle.
  - **„Hranica TYP vs ŠABLÓNA vs PARAMETER"**, kľúčová pre T2, žije len na konci PLANu (za ≈ 108 kB hotových blokov). Nie je v STANDARD §4.2, kde sa typy definujú, ani v `construction.md`; `POJMY.md:104` na ňu len odkazuje.

  Návrh: autoritou pre vertikálny priestor nech je UI_DIZAJN §1 a ostatné miesta len odkaz; TYP/ŠABLÓNA/PARAMETER presunúť do STANDARD §4.2; riadok UI v CLAUDE.md nech ukazuje na UI_DIZAJN §1.
- **Dôkaz:** `CLAUDE.md:15`; `ARCHITEKTURA.md:104`; `ui-lifecycle.md:4094–4096`; `UI_DIZAJN.md:13`; `PLAN.md:677–687`; `POJMY.md:104`; `README.md:24`.
- **Scenár:** S6 (+ S1)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — súčasť presunu z CN-06.
- **Overenie nezmeneného výstupu:** docs-only.

### CN-11 · D · Pri bežnom rozšírení sa nedá jednoznačne určiť trieda dávky (predrecenzia, golden testy)
- **Čo:** T1 je čisto zobrazovací stĺpec bez zmeny zoskupovania riadkov a exportov. Nový agent pri ňom nevie rozhodnúť dve veci:
  - „Výrobná/cenová dávka = mení … **kusovník**" — je nový stĺpec zmenou kusovníka?
  - Predrecenzia je povinná „s **novým ovládacím prvkom v UI**" — je nový checkbox v existujúcom menu „Stĺpce" nový ovládací prvok?

  Od odpovede pritom závisí predrecenzia, golden testy aj počet kôl review. Návrh: k definíciám doplniť 3–4 príklady hraníc, napr. „nový čítací stĺpec bez zmeny `row_key` a exportov = nie výrobná". Precedens už existuje: `rows_with_roles`, obohatenie riadku bez zmeny kľúča.
- **Dôkaz:** `CLAUDE.md:58`, `:66–70`; `outputs.md:512–514`.
- **Scenár:** S6 (+ S5)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — mení pravidlo, rozhodne Michal; text sú dve vety.
- **Overenie nezmeneného výstupu:** docs-only.

### CN-12 · D · Otázka „prečo" a „ako sa to robilo naposledy" vedie do 966 kB KRONIKY namiesto do priečinka bloku
- **Čo:** Riadok bugfix/„prečo" a README:17 posielajú do `archiv/KRONIKA.md` (966 kB, 4 471 riadkov) a `DOGFOODING_vyriesene.md` (303 kB). Oba sa dajú prehľadať len Grepom. Pre T2 bol najcennejší predchádzajúci blok `archiv/bloky/ROHOVA/` (ROZHODNUTIA, FAKTY_Z_KODU, PACKAGE_ROHA1–B2 + `archiv/ROHOVA_ZAVER`; 402 kB bez mockupu ≈ 239 kB). Žiadny riadok tabuľky naň neposiela. Návrh:
  - riadok „novú dávku" doplniť o „podobná funkcia už bola → `archiv/bloky/<BLOK>/ROZHODNUTIA_*`, `PACKAGE_*` a `archiv/<BLOK>_ZAVER_*`",
  - riadok „prečo": najprv priečinok bloku, KRONIKA len Grepom podľa ID dávky.
- **Dôkaz:** `CLAUDE.md:19`; `SYSTEM/README.md:17`; `wc -c`/`wc -l` KRONIKA, DOGFOODING_vyriesene a `archiv/bloky/ROHOVA/*`.
- **Scenár:** S6 (+ S1)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — dve vety v tabuľke a README.
- **Overenie nezmeneného výstupu:** docs-only.

### CN-13 · D · Vzor testov v SketchUpe je jeden súbor s 1,5 MB
- **Čo:** Riadok „testy" káže robiť novú sadu podľa „najbližšej existujúcej" v `tests/sketchup/`. Tam je `su_runner.rb`: 1 507 689 B, 27 949 riadkov a 114 sekcií `run_*` (rohová `run_roha1` … `run_rohb2` od riadku 6190). Prečítať sa nedá a T2, ktorý má test v SketchUpe povinný, musí dopísať ďalšiu sekciu do toho istého súboru. Návrh: runner rozdeliť na súbory podľa blokov (`tests/sketchup/suites/<blok>.rb`), ktoré jadro runnera načíta; správanie sa nemení.
- **Dôkaz:** `CLAUDE.md:20`; `wc -c` a `wc -l tests/sketchup/su_runner.rb`; `grep -c "def run_"` = 114.
- **Scenár:** S6 (+ S1)
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** PO V1 — runner je brána mergu a zásah doň počas HARDENINGu ohrozuje bránu. Ideálne spolu so zásobníkovou položkou N4 („runner po teste vráti pôvodnú verziu"), aby sa do runnera siahalo raz.
- **Overenie nezmeneného výstupu:** beh `scripts\run_su_tests.ps1 -CloseWhenDone` pred a po rozdelení musí mať rovnaký zoznam sekcií a rovnaký počet PASS/FAIL assertov (porovnanie výsledkových súborov `run_*`).

### CN-14 · D · CLAUDE.md sa načíta každému subagentovi a ~40 % z neho sú pravidlá len pre orchestrátora
- **Čo:** 25,7 kB sa načíta každému agentovi, ale implementátor tri sekcie nepoužije:
  - Git workflow (merge, kolá review, pravidlo 3 kôl, rešerš, štart bloku, mockup, externé nástroje) ≈ 6,4 kB,
  - Kvóty ≈ 1,3 kB,
  - Autonómne bloky ≈ 3,1 kB.

  `implementator.md:10` sám hovorí, že pravidlá jeho roly sú v ňom. Každý subagent tak platí ≈ 5 k tokenov navyše a číta pravidlá, ktoré sa ho netýkajú (ďalšie miesto na omyl). Návrh: orchestrátorské sekcie presunúť do WORKFLOW.md alebo skillov. V CLAUDE.md nechať tabuľku čítania, verziu a uzáver dávky, testovanie a jednu vetu s odkazom.
- **Dôkaz:** veľkosti sekcií `CLAUDE.md` (merané), `.claude/agents/implementator.md:9–10`.
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** PO V1 — zmena workflowu, o ktorej rozhoduje Michal. Úspora je trvalá, ale nie kritická.
- **Overenie nezmeneného výstupu:** docs-only; guard `test_docs_navigacia.rb` (CLAUDE.md musí odkazovať na ARCHITEKTURA) zelený.

---

## Namerané kB — T1 a T2

Veľkosti sú `wc -c` na `6d59edef` a odseky merané po nadpisoch v bajtoch. Stĺpec „užitočné" je môj odhad textu, ktorý naozaj posunul prácu.

### T1 · „stĺpec Hmotnosť dielca v Kusovníku Štúdia"

Platné riadky tabuľky: **novú dávku · zmenu Ruby kódu · UI · výstupy**; materiály len nepriamo (hustota).

| Riadok tabuľky | Dokument (časť) | kB | Užitočné pre T1 |
|---|---|---:|---|
| (auto) | `CLAUDE.md` | 25,7 | tabuľka, uzáver, testy ≈ 9 |
| (typ agenta) | `.claude/agents/implementator.md` | 3,9 | postup ≈ 2 |
| novú dávku | `SYSTEM/STAV.md` | 9,2 | ≈ 0,5 (a zastaraný — CN-05) |
| novú dávku | `SYSTEM/PLAN.md` | 111,5 | ≈ 0,4 (len trvalé UI pravidlo) |
| novú dávku | `SYSTEM/DOGFOODING.md` | 12,8 | 0 |
| novú dávku (voliteľne) | `SYSTEM/README.md` | 8,1 | ≈ 1 (UI20 je záväzný) |
| Ruby core | `docs/ARCHITEKTURA.md` | 10,4 | ≈ 1 |
| Ruby core + výstupy | `outputs.md` — `bom.rb` | 19,4 | ≈ 2 (`weight_totals`, `cut_dims`) |
| výstupy | `outputs.md` — `validation.rb` + `production_core.rb` | 87,6 | ≈ 0,5 (`rows_with_roles`) |
| výstupy | `model-a-identita.md` — `build_plan` + `part_keys` | 11,7 | 0 |
| výstupy | `SYSTEM/VEPO_KONTRAKT.md` | 14,2 | ≈ 0,3 (Kusovník ≠ VEPO) |
| Ruby core + výstupy | STANDARD §8 + §11 | 31,2 | ≈ 1,5 |
| UI | `docs/UI_DIZAJN.md` | 116,8 | ≈ 9 (§1, D-51 „7 stĺpcov", vzory Štúdia) |
| UI | `docs/architecture/ui-lifecycle.md` (celý) | 541,7 | ≈ 13 (Kusovník 12, Hmotnosť v Inspectore 1,3) |
| **Spolu doslovne** | | **996,0** (≈ 0,50 M tokenov) | **≈ 40 (≈ 4 %)** |
| Spolu „po odsekoch" | ui-lifecycle len odsek Štúdia (61,3) | **515,6** | |
| mimo tabuľky (Grep) | `materials.md` KOV-W 1,6 · `UI20_KONTRAKT.md` Š2 (súbor 50,3) · kód `studio.js:78–88`, `:287–303` | — | nutné |

**Čo som ani po prečítaní nevedel a hľadal v kóde:**
1. kde sa definujú stĺpce (`COLS`, `cellValue`, `activeCols` v `studio.js`) a kto dodáva polia riadku (`ProductionCore.rows_with_roles` — našiel som ho Grepom v 66 kB odseku);
2. či už existuje výpočet hmotnosti: áno — `Materials.weight_kg`, `Bom.weight_totals`, formát `nxCabWeight`. Opísané je to v štyroch dokumentoch (`materials.md`, `construction.md`, `outputs.md`, odsek Inspectora v `ui-lifecycle.md`), ale v žiadnom odseku o Kusovníku;
3. hmotnosť na kus alebo × ks a „≈" pri UNI v riadku — rozhodnutie pre Michala, dokumenty ho nemajú;
4. či je T1 výrobná dávka a či treba predrecenziu (CN-11);
5. že stĺpce viaže záväzný UI20_KONTRAKT Š2 (CN-07) a že šírka okna 1060 px je navrhnutá na 7 stĺpcov (`UI_DIZAJN.md:1389`), čo stráži guard `test_uib1_kostra.rb`.

**Kde som sa stratil:**
- Kusovník nemá v ui-lifecycle vlastný nadpis (CN-08).
- „Bez vlastného odseku" nad `bom.rb`.
- Dve protichodné vety o tom, odkiaľ ide hrúbka do hmotnosti (CN-09 bod 9).

### T2 · „nový typ skrinky horná rohová"

Platné riadky: **novú dávku · Ruby core · buildery/geometria · UI · kovanie · materiály/ABS · výstupy · testy** (8 z 12 riadkov). DC len podmienečne, lebo zdrojom geometrie rohovej bol DC „Rohová".

| Riadok tabuľky | Dokument (časť) | kB | Užitočné pre T2 |
|---|---|---:|---|
| (auto) + (typ agenta) | `CLAUDE.md` + `implementator.md` | 29,6 | ≈ 11 |
| novú dávku | STAV + PLAN + DOGFOODING | 133,5 | ≈ 2,5 (schéma 22, zásobník, TYP vs ŠABLÓNA) |
| Ruby core | `ARCHITEKTURA.md` | 10,4 | ≈ 1 |
| buildery | `construction.md` — construction, cabinet_builder, board_builder, zone_tree, scale_observer | 112,0 | ≈ 6 (ROH-A1, slot ako vzor) |
| buildery | `docs/SKETCHUP_PRAVIDLA.md` | 5,4 | ≈ 1 |
| buildery | STANDARD §3 + §4 + §9 | 18,4 | ≈ 4 (§4.2, §4.4) |
| Ruby core (dotknuté odseky) | `ghost_tool` + `fronts` + `part_faces` (construction) · `build_plan` + `part_keys` + `templates` (model-a-identita) | 67,1 | ≈ 3 |
| Ruby core (dotknuté §) | STANDARD §2.4–2.5 + §5 | 31,9 | ≈ 2 (schéma 22, roly) |
| UI | `UI_DIZAJN.md` | 116,8 | ≈ 4 (§5.4 „päť typov sa zmestí", §5.3 riadok rohovej) |
| UI | `ui-lifecycle.md` (celý) | 541,7 | ≈ 6 (registre ROH-A1 1,8 + roztrúsené odseky ROH-A2/B1/B2) |
| kovanie | `hardware.md` + STANDARD §6 | 250,0 | **0** — pravidlo „Bystrica len upper" v nich nie je (CN-03) |
| materiály/ABS | `materials.md` + STANDARD §7 | 103,9 | ≈ 2 (ABS seed rohovej) |
| výstupy | VEPO_KONTRAKT + `outputs.md` (validation, production_core) + STANDARD §8 + §11 | 132,9 | ≈ 1 (skratky VEPO) |
| testy | sekcia Testovanie v CLAUDE.md · vzor `tests/sketchup/su_runner.rb` (1 507,7 kB) | — | nečitateľné, len Grep (CN-13) |
| **Spolu doslovne** | | **1 553,5** (≈ 0,78 M tokenov) | **≈ 45 (≈ 3 %)** |
| Spolu „po odsekoch" | ui-lifecycle len dotknuté odseky (143,7), `hardware.md` len `hardware_rules` (55,5), materials len `abs_rules` + KOV-W (10,5) | **≈ 942** | |
| mimo tabuľky | `archiv/bloky/ROHOVA/FAKTY_Z_KODU_2026-09-27.md` (48,7; najcennejšie §1.2 a §2.6 ≈ 8) · kód: `grep corner_blind` (22 súborov), `grep "'upper'"` (32/13) | — | nutné |

**Čo som ani po prečítaní nevedel a hľadal v kóde alebo v archíve:**
1. úplný zoznam miest, kadiaľ ide nový typ (CN-02) — v živých dokumentoch nie je;
2. ktoré vetvy `'upper'` sa týkajú hornej rohovej. Najvážnejšie je seed pravidlo závesov na stenu (CN-03);
3. ktoré schémy a seedy zvýšiť (`CONFIG_SCHEMA` 23, BuildPlan `SCHEMA` pri nových rolách, ABS a kovacie `SEED_VERSION`, `TemplateStore::STD` pri seede šablóny) — CN-04;
4. či je horná rohová nový TYP, alebo variant `corner_blind` s podporou „na stenu". Hranicu má len koniec PLANu (CN-10) a pri rohovej platí „typ existujúcej rohovej sa nemení žiadnou cestou" (`STANDARD.md:434`) — rozhodnutie pre Michala;
5. šiesty typ v rade vkladacej karty: UI_DIZAJN §5.4 hovorí, že pri 470 px sa zmestí „päť typov s textom do ~9 znakov" a dnes ich je päť. Dokument nehovorí, čo so šiestym, a „Horná rohová" má 12 znakov;
6. výška zavesenia pri vkladaní a pamäť zámku výšky podľa typu (`ghost_tool.rb`) — v `construction.md` je to len nepriamo.

**Kde som sa stratil:**
- `hardware.md` (208 kB) neobsahuje ani slovo o type skrinky.
- Registre typu sú na konci ui-lifecycle pod „Ostatné".
- `construction.md` si protirečí v zozname typov (CN-09 bod 1).
- Najlepší podklad (FAKTY_Z_KODU) je v archíve, kam tabuľka neposiela (CN-12).

---

## Doplnky k známym

- **R-32** (odseky architektúry sú prázdne alebo len kostry; agent musí čítať kód), nový fakt:
  - chýba aj popis tabuľky Kusovníka — `COLS`, `cellValue`, `activeCols` v `studio.js`; `ui-lifecycle.md:2446` spomína len `nx_bom_cols`;
  - odsek `bom.rb` začína vetou „správanie je popísané v odsekoch, ktoré ho volajú" (`outputs.md:626`);
  - `usage_stats` je stále „zatiaľ nezdokumentované" (`ui-lifecycle.md:4100`).
- **R-33** (hygiena — XLSX/CSV Kusovníka nemá vlastníka v PLANe) platí ďalej: PLAN ani DOGFOODING položku nemajú, hoci `UI20_KONTRAKT.md:445–448` sľubuje „vlastnú dávku".
- **PLAN zásobník — „Horná rohová … ako nové TYPY builderov"** (`PLAN.md:654`, `:657` — položka je tam dvakrát), nový fakt:
  - seed pravidlo `zavesenie-hornej-skrinky` filtruje len `upper` (`hardware_rules.rb:313–317`) a `'upper'` je v kóde 32× v 13 súboroch;
  - mapa FAKTY_Z_KODU je k v0.14.0 (pred `corner_blind`), takže pred blokom treba nový „fakty z kódu" prechod. Týka sa aj „vysokej/potravinovej veže".
- **PLAN zásobník — „Runner testov v SketchUpe po teste sám vráti pôvodnú verziu" (N4):** pri tom istom zásahu zvážiť rozdelenie `su_runner.rb` (CN-13), aby sa do brány mergu siahalo raz.

## Čo som nestihol / neistoty

- Celé `ui-lifecycle.md`, `hardware.md`, `construction.md`, STANDARD §6–§7 ani KRONIKU som neprečítal. Zmeral som ich (`wc -c`, odseky po nadpisoch) a prehľadal Grepom. Hodnoty v stĺpci „užitočné" sú môj odhad.
- Prepočet na tokeny vychádza z jediného merania (PLAN, ≈ 0,5 tokenu/B); pri kóde a angličtine bude pomer iný.
- WORKFLOW.md ani skilly som podľa tabuľky nečítal, lebo T1/T2 nemenia workflow. Implementátor sa ich dotkne len cez `usage` a predrecenziu.
- Rozsah T2 závisí od Michalovho rozhodnutia, či je horná rohová nový TYP, alebo variant rohovej. Merania rátajú s novým typom.
- Os A3 (dokumenty) sa s touto kartou prekrýva pri veľkosti ui-lifecycle a PLANu. Tu uvádzam len merania a dôsledky zo scenára S6.
