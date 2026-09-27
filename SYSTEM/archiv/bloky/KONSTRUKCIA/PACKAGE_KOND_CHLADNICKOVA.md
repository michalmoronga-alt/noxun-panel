# Package KON-D — vstavaná šablóna „Chladničková"

> **Blok 7 · KONŠTRUKCIA K1+K2**, štvrtá (posledná) dávka. **Package v2** (27.9.2026) — zapracovaný audit návrhu (NOT SOUND: 1 BLOCKER · 3 FIX ·
> 2 NOTE — všetko v Scope IN, prehľad v sekcii „Audit návrhu KON-D" na konci). Autorita počas dávky: tento package.
> Podklady v `SYSTEM/zdroje/bloky/KONSTRUKCIA/`: [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md) (M7, M9, M10),
> [VSTUPY_PRE_PACKAGES_2026-09-27.md](VSTUPY_PRE_PACKAGES_2026-09-27.md) (KON-D), schválený mockup
> [MOCKUP_KONSTRUKCIA_2026-09-27.html](MOCKUP_KONSTRUKCIA_2026-09-27.html) (sekcia E — E1, E2; rozmery podľa banneru: 560, bez chrbta), fakty z kódu
> KON-D (main `4be63120`, v tomto package), krížový audit (Codex FIX 11, Grok 1, 2), packages KON-A a KON-B, audit návrhu
> [AUDIT_KOND_2026-09-27.md](AUDIT_KOND_2026-09-27.md).
> **Trieda:** **audit-povinná** (knižnica šablón `STD` 6 → 7) → `codex-audit` hotový · predrecenzia pred PR · in-SU scenár vkladu · GH Codex review.
> Nie je výrobná (nemení dielce existujúcich skriniek ani výstupy). Štartuje z mainu **po mergi KON-B**. Verzia v0.13.3 → **v0.13.4**.

## Cieľ (z pohľadu stolára)

- V Štúdiu (Šablóny) aj pri vkladaní (Inspector → Šablóna → Všetky šablóny) pribudne šablóna **„Chladničková"**: vysoká skriňa **600 × 2100 × 560**,
  sokel 100, **komín 50** (dno a strop 510, boky 560), **bez chrbta**, **očakáva chladničku**, dve dvierka nad sebou (M7 — tak ju Michal v praxi vyrába).
- Pri komíne sa **nika chladničky meria z hĺbky boku** (M9, KON-A) → 560.
- Na dlaždici šablóny je vidno komín („komín vzadu 50", mockup E2) a v tooltipe veta o vetraní.
- Knižnica šablón sa pri prechode na novú verziu **nikdy nezapíše zo zálohy ani z núdzových predvolieb** (audit BLOCKER 1 — chráni vlastné šablóny).

## Scope IN

### 1 · Seed šablóny

1. **Obsah** (vzor `lower_base`, `templates.rb:747–756`, + výslovné hodnoty): `type 'lower'`, `width 600`, `height 2100`, `depth 560`, `thickness 18`,
   `floor_height 100`, `bottom_mode 'under_sides'`, `top_mode 'full'`, **`back_mode 'none'`**, `back_thickness 3` (pamätaná hodnota), `plinth_mode`
   a `plinth_recess` ako `lower_base`, výstuhy ako `lower_base`, **`back_setback 50`**, **`top_front_setback 0`** a **`back_rail_height 100` výslovne**
   (pravidlo KON-A/KON-B: nové šablóny zapisujú predvoľby výslovne — inak by použitie na skrinku so zapustením zapustenie ponechalo),
   **`appliance_expects ['fridge']`**, `zone_tree` bez políc (`ZoneTree.default_tree(0)`), čelá bod 1.2.
2. **Čelá — dve dvierka nad sebou** (mockup E „podľa odporúčania S1-F"): F1 (dolné) `mode fixed`, **výška 719**, `locked`; F2 (horné) `auto`
   (= 2000 − 2 − 2 − 3 − 719 = **1274**), `wings auto` (pri šírke 600 = 1 krídlo). **Smer otvárania oboch dvierok výslovne „neurčený"** (audit FIX 2 —
   chýbajúci `direction` by Kontrola brala ako staré dáta bez upozornenia, `fronts.rb:599`, `bom.rb:641`; načítanie šablóny neprechádza vetvou `userAdd`,
   `form.js:1688`) → Kontrola vyzve zvoliť stranu pántov; stranu **automaticky neurčovať**; guard povolených miest pre `unset` (`test_kova1_cela.rb:595`)
   sa zladí. **Odvodenie delenia:** jediná chladnička v katalógu (Beko BCNA306E5ZSN, `appliance_catalog.rb:1517–1538`) má pásmo deliacej hrany
   (S1-F, `appliance_checks.rb:386–422`) **679–727 mm od dna niky, stred 703**; spodná hrana F1 = sokel 100 + medzera 2, dno niky 118 → F1 = 703 + 16 =
   **719** (výška F1 v pásme 695–743 pri osadení 0). Čísla sú **návrh na potvrdenie Michalom pri smoke** (mockup: „— návrh").
3. **Meno „Chladničková"** (s diakritikou ako „Umývačka 60"); porovnanie mien je presné (`templates.rb:110, 638`).
4. **`config_schema` = aktuálny `CabinetBuilder::CONFIG_SCHEMA`** v čase zápisu seedu (po KON-B 21; vzor `slot_base`, `templates.rb:726`; audit: správne) —
   bez neho by starší plugin seed prijal, neznámy komín zahodil a postavil dno 560. Prijatý dôsledok: plugin s nižšou schémou seed odmietne.

### 2 · Knižnica šablón `STD` 6 → 7 (vzor S1-E `missing_slot_seed`)

1. Seed v **samostatnom zozname** (napr. `build_predefined_fridge` — **nie** v `build_predefined`, ktorý slúži ako núdzová náhrada, `templates.rb:96/101/104/427`);
   čistá inštalácia (primár aj `.bak` chýbajú) ho zapíše spolu s ostatnými (`:421`).
2. **Jednorazový krok migrácie** `old_std < 7` → pridá seed, **len ak v knižnici nie je korpusová šablóna s rovnakým menom** (vzor `:634–640`);
   **zmazaný seed sa neobnoví** (krok beží len pri prechode značky `std`); vlastná rovnomenná šablóna sa **neprepíše**.
3. **Migrácia zapisuje len nad zdravým primárom** (audit **BLOCKER 1**, existujúca slabina, ktorú bump aktivuje): pod zámkom pred zápisom overiť, že
   **primárny súbor** sa prečítal (nie tichá náhrada zo `.bak`, `json_file_store.rb:126`) a má tvar `{std, templates: Array}`. Keď je primár poškodený
   a číta sa záloha, alebo `templates` nie je pole (napr. `{std: 6, templates: null}` → dnes núdzová náhrada `build_predefined` + seed + zápis) →
   **migrácia nezapisuje** (knižnica ostáva, ako je, seed sa nepridá, kým primár nie je zdravý; existujúca ochrana `json_file_store.rb:62`). Čistá
   inštalácia (primár aj záloha chýbajú) ostáva samostatnou cestou. Regresné testy oboch scenárov.
4. Dôsledok bumpu (existujúci mechanizmus, `:367–384`): plugin so `STD` 6 prepne knižnicu 7 do režimu len na čítanie (nedá sa ukladať, premenovať,
   mazať, meniť náhľady ani pečiatky posledného použitia) — **aktualizovať obe PC** (precedens STD 6). Čerstvá knižnica: **10 šablón, z toho 7 korpusových**.

### 3 · Dlaždice šablón

1. **Súhrn konštrukcie** — čistá funkcia na serveri (bez nového perzistovaného kľúča, vzor `appliance_expects_summary`, `templates.rb:167–176`) s presným
   kontraktom **účinných** hodnôt (audit FIX 4): „komín vzadu N" len pri `back_setback > 0` · „zap. N" len pri `top_front_setback > 0` **a** strope ≠ „Bez
   stropu" · „z líšt H" **len pri `back_mode 'rails'`** (aj pri predvolenej výške 100; uložená výška pri inom chrbte sa neukazuje) · sloty umývačky nikdy
   (texty ako `setbackMetaTexts`, `form.js:787–792`).
2. **Štúdio → Šablóny** (`TemplatesDialog.tile_row` `templates_dialog.rb:132–144` + `tplTileHtml` `templates.js:229–272`): riadok `.stplmeta` so súhrnom
   **len keď je neprázdny** (mockup E2) — ostatné dlaždice sa nemenia; vzor riadku „očakáva chladničku" (`stplexp`); `TILE_CONFIG_KEYS` ostáva orezaný.
3. **Vkladanie** (dlaždica v Inspectore, `form.js:930–940`): odvodený súhrn sa **výslovne pridá do `Panel.template_list`** (`payloads.rb:2472` — úprava
   `tile_row` sa do Inspectora nedostane) a zobrazí v tooltipe `nxTplTitle` (`form.js:891–896`) popri existujúcom texte kovania — dlaždica nenarastie.
4. **Veta o vetraní:** „Vetracie otvory v sokli a hore rieši stolár podľa montážneho listu spotrebiča." — v tooltipe dlaždice (Štúdio aj vkladanie)
   **pri každej šablóne, ktorá očakáva chladničku** (odvodené z `appliance_expects`, nie nový kľúč; UI_DIZAJN: pomocný text do tooltipu).

### 4 · Dokumentácia

STANDARD (knižnica šablón `STD` 7, seed „Chladničková", migrácia len nad zdravým primárom, súhrn na dlaždici) · odsek `TemplateStore` v `docs/architecture/`
(kde žije) · `ui-lifecycle.md` (dlaždice) · POJMY (Chladničková — rozmery, komín, vetranie, osadenie 14–24) · package + surový audit do priečinka bloku.

## Scope OUT

vetracie otvory a výrezy v modeli · výška osadenia chladničky v šablóne (žije len na priradenom spotrebiči) · priradenie konkrétneho modelu ·
šablóny Rúrová a Drezová (M12) · tlačidlo „Použiť odporúčané delenie" · premenovanie vložených skriniek (auto-meno „Spodná skrinka 600") ·
bokorys (D-145) · zmena rozmerov (rozhodnutie Michala) · automatická aktualizácia seedu v existujúcich knižniciach po neskoršej zmene (bod Riziká).

## Známe dôsledky (nie chyby — do smoke a KRONIKY)

- **Výška niky:** vnútro 2100 − 100 − 18 − 18 = **1964**; Beko z katalógu chce 1940–1950 → po priradení **ORANGE „výška niky"**, kým sa nenastaví
  **výška osadenia 14–24 mm** (existujúci tok D-140; audit FIX 3 — pri 24,25 výška ešte prejde toleranciou 0,5 mm, ale delenie čiel už nie; pri osadení
  14 je deliaca hrana 689, v pásme). Hĺbka sedí (560 ≥ 555, M9), šírka tiež (564 ≥ 560).
- Po vložení **ORANGE „očakáva chladničku, ale nemá priradenú"** (S1-C) a upozornenie na **neurčený smer otvárania** dvierok — kým sa nevyrieši.
- Sokel: predvoľba `lower_base` = nohy (4 ks + príchytka sokla podľa pravidiel), soklová doska sa nemodeluje.
- **Zámky vkladania (D-39)** môžu prepísať rozmery šablóny (existujúce správanie); pri zamknutej šírke nad 600 dá `wings auto` viac fyzických dvierok
  (napr. 800 → 4) a kontrola delenia počet krídel nekontroluje (audit NOTE 5). Hrúbka korpusu sa pri nezamknutej hrúbke berie z materiálu projektu.

## Dáta a kontrakt → audit ÁNO (hotový)

knižnica šablón `STD` 7 · nový seed a krok migrácie · migrácia len nad zdravým primárom · `config_schema` seedu · súhrn na dlaždici (odvodený, bez nového kľúča).

## Testy a DoD

- **Headless:** seed — obsah (všetky kľúče vrátane výslovných 0/100, `config_schema`, `appliance_expects`, čelá, smer „neurčený") · stavba zo seedu:
  dno a strop 510, boky 560, žiadny chrbát, vnútro 510, **nika 560**, **2 fyzické dvierka** 719 + 1274 (predpoklady: bez zámkov vkladania, hrúbka 18) ·
  **osadenie 0 / 14 / 24 / 24,25 / 25** — verdikt výšky niky aj delenia čiel (audit FIX 3) · migrácia 6 → 7: seed pridaný; **nepridaný**, keď existuje
  korpusová šablóna „Chladničková"; **neobnovený** po zmazaní; čistá inštalácia ho má; núdzová náhrada `build_predefined` ho nemá · **zdravie primára**:
  poškodený primár + záloha STD 6 → **žiadny zápis**; `{std: 6, templates: null}` → **žiadny zápis** (audit BLOCKER 1) · `STD` 7 read-only pre `STD` 6 ·
  súhrn dlaždice — skutočné payloady **oboch ciest** (`tile_row`, `template_list`) vrátane neaktívnych uložených hodnôt (lišty 100 pri inom chrbte,
  zapustenie pri „Bez stropu", slot) · R-12: seed s vyššou schémou odmietnutý starším pluginom · **použitie seedu na existujúcu skrinku so zapustením**:
  zapustenie → 0, väzby spotrebiča, osadenie a zjednotenie očakávaní zachované (audit NOTE 5). Zladiť testy, ktoré pripínajú `STD` 6 a počty seedov
  (fakty KON-D §7: `test_s1e_slot.rb:498`, `test_s1c_expects.rb:382`, `test_d139_celo_slotu.rb:246`, `test_materials_abs_persistence.rb`,
  `test_uic1a_sablony.rb`, `test_st3c_tpl.rb:298/302`, `test_uic1c_orientacia.js:96–97`, `test_kova1_cela.rb:595`).
- **JS:** riadok súhrnu na dlaždici Štúdia len pri neprázdnom súhrne; tooltip vkladania (súhrn + veta o vetraní pri chladničke + zachovaný text kovania).
- **In-SU** (sekcia `run_kond`, `-CloseWhenDone`, len `_dev\ENGINEtests.skp`; runner má čerstvú knižnicu v izolovanom APPDATA): vloženie zo seedu
  „Chladničková" → plán ↔ model 1:1, dno 510, boky 560, bez chrbta, 2 fyzické dvierka; jeden krok Späť.
- **Mutačné overenie** (min. 4): seed bez `config_schema` · migrácia prepíše vlastnú rovnomennú šablónu · seed v `build_predefined` · chýba výslovné
  `top_front_setback 0` · migrácia zapíše nad zálohou.
- Headless + každá JS sada zvlášť zelené; počty do PR a KRONIKY.

## Riziká

seed prepíše alebo obnoví, čo nemal (test migrácie) · zápis knižnice zo zálohy (test zdravia primára) · starší plugin postaví seed bez komína (pečiatka
schémy — test R-12) · knižnica len na čítanie na druhom PC (aktualizovať obe) · delenie čiel sedí len pre chladničky ~194 cm (návrh na potvrdenie) ·
**neskoršia zmena seedu sa do existujúcich knižníc sama nedostane** (audit NOTE 6): ak Michal po smoke zmení delenie, buď si šablónu upraví ručne na
každom PC, alebo ďalšia dávka pridá migráciu `STD` 8, ktorá obnoví **len nedotknutý** seed (precedens D-139 — porovnanie celého záznamu, nie mena).

## Smoke pre Michala (po mergi, v0.13.4)

1. Štúdio → Šablóny: dlaždica **„Chladničková"** — „dolná · 600 × 2100 × 560", „očakáva chladničku", **„komín vzadu 50"**; tooltip s vetou o vetraní.
2. Vlož ju (Inspector → Šablóna → Všetky šablóny): dno a strop 510, boky 560, **bez chrbta**, dve dvierka (dolné 719, horné 1274); Kontrola: „očakáva
   chladničku" a „neurčený smer otvárania" — zvoľ stranu pántov.
3. Priraď chladničku Beko: nika hĺbka 560 sedí; výška hlási oranžovú, kým nenastavíš **výšku osadenia 14–24 mm** — **potvrď, či delenie čiel 719/1274
   sedí na vašu prax** (ak nie, povedz iné čísla — upravia sa v šablóne).
4. Aktualizuj plugin aj u Lucie (knižnica šablón 7).

## Checklist uzáveru

VERSION 0.13.4 (2×) + všetky `?v=` · testy · docs (bod 4) · PLAN blok 7: riadok KON-D s ✅ a `PR #?` · **STAV prepis** (v0.13.4, Chladničková,
STD 7 — aktualizovať obe PC) · KRONIKA · package + surový audit v priečinku bloku. **Po mergi nasleduje uzáver bloku 7** (release, v0.14.0).

---

## Audit návrhu KON-D (Codex gpt-6-astra, 27.9.2026 ~12:00, 9,7 min, +5 % weekly) — **NOT SOUND: 1 BLOCKER · 3 FIX · 2 NOTE**

Surový výsledok: [AUDIT_KOND_2026-09-27.md](AUDIT_KOND_2026-09-27.md). Všetko zapracované vyššie (v1 → v2):

- **BLOCKER 1 — migrácia nad zálohou alebo núdzovými predvoľbami:** pri poškodenom primári `JsonFileStore` potichu vráti `.bak` a migrácia by z neho
  zapísala nový primár STD 7; `{std: 6, templates: null}` by sa uložilo ako núdzové predvoľby + seed → **migrácia zapisuje len nad zdravým primárom** (2.3).
- **FIX 2 — dvierka bez smeru otvárania** by dostali výnimku starých dát → smer výslovne „neurčený", Kontrola vyzve (1.2).
- **FIX 3 — osadenie „≥ 14" je nesprávne** a pásma sa miešali → osadenie **14–24**, pásmo deliacej hrany 679–727 (stred 703) vs. výška F1 695–743,
  hraničné testy 0/14/24/24,25/25 (1.2, Známe dôsledky, Testy).
- **FIX 4 — kontrakt súhrnu na dlaždici** (účinné hodnoty, „z líšt" len pri `rails`, zapustenie nie pri „Bez stropu", sloty) + súhrn aj do
  `Panel.template_list` pre vkladanie (3.1, 3.3).
- **NOTE 5 — predpoklady základného scenára** (zámky vkladania, počet fyzických dvierok, materiál) a použitie na existujúcu skrinku so zapustením (Testy).
- **NOTE 6 — neskoršia zmena seedu** sa do existujúcich knižníc nedostane → postup v Rizikách.
- **Odpovede:** pečiatka aktuálnej schémy (21 po KON-B) správna · migrácia pod zámkom správna, mená presné (NFC/NFD sa nezjednocuje) · čelá 719/auto
  správne pre uvedené predpoklady, iný model potrebuje vlastné posúdenie · veta o vetraní do tooltipu + „podľa montážneho listu spotrebiča" · čerstvá
  knižnica 10 šablón (7 korpusových).
