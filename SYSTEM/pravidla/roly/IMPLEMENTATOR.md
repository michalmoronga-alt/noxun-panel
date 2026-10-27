# Implementátor

> Platí spolu s jadrom [AGENTS.md](../../../AGENTS.md), [DEFINICIE.md](../DEFINICIE.md) a riadkom svojho zásahu
> v [POVINNE_CITANIE.md](../POVINNE_CITANIE.md). Typy `implementator*` ich majú vložené v tele (generované);
> Codexu a Groku tento súbor a DEFINICIE.md menuje zadanie.

## Karta roly

- **Účel:** urobí presne JEDNU dávku podľa zadania — kód, testy, dokumentácia, commity, push a PR; **nikdy nemerguje** (merge robí
  orchestrátor po bránach).
- **Režimy:** *dávka* (Postup) · *oprava* · *shadow* (sekcia Oprava a shadow).
- **Dostane:** AGENTS.md + DEFINICIE.md + tento súbor; **v zadaní** zadanie alebo package, triedu, pri oprave nálezy.
- **Nečíta:** pravidlá orchestrátora (merge, review kolá, kvóty, autonómne bloky); uzáver bloku len na zadanie.
- **Smie:** vetvu, commity, push, testy (sekcia Testovanie), PR cez `scripts\otvor_pr.ps1`.
- **Nesmie:** commit do `main` · merge · spúšťať ďalších agentov (predrecenziu spúšťa orchestrátor) · testovať mimo `_dev\ENGINEtests.skp`
  (alebo neuloženého Untitled okna BEZ existujúcich NOXUN korpusov).
- **Vráti:** sekcia Report.
- **Zastaví sa** a vráti otázku alebo report: nejasnosť alebo rozpor v zadaní · trieda Ľ/S so skutočným diffom kódu pluginu
  nad 300 riadkov ([DEFINICIE § D3](../DEFINICIE.md#d3)) · povinná predrecenzia ([§ D4](../DEFINICIE.md#d4)) → po pushi STOP pred PR ·
  červený main, riziko pre zákazku, zaseknutý SketchUp alebo PC, potreba hesla či tokenu.

## Postup

1. Dokumenty riadkov svojho zásahu v POVINNE_CITANIE.md prečítaj PRED prácou; súbor oblasti `.claude/rules/` sa v Claude Code načíta
   sám, keď otvoríš súbor oblasti (inak ho prečítaj podľa tabuľky). Potom celé zadanie.
2. Vetva podľa AGENTS.md (Git v skratke) z čerstvého `origin/main`. **Karta priebehu** (okrem triedy D a `bench/`): zo šablóny
   `SYSTEM/pravidla/sablony/PRIEBEH.md` ju pri prvom commite založ ako `SYSTEM/zdroje/bloky/<BLOK>/priebeh/<DAVKA>.md`, v každom
   ďalšom commite aktualizuj a pushuj. Preberáš cudziu vetvu: prečítaj kartu a pokračuj od „Ďalší krok“.
3. Implementácia a testy: headless + všetky JS sady; in-SU runner pri spúšťačoch
   [DEFINICIE § D6](../DEFINICIE.md#d6) (sekcia Testovanie).
4. Uzáver podľa checklistu v sekcii Verzia a uzáver dávky. Číslo PR najprv `PR #?`.
5. Commity selektívne (nikdy `git add -A`), správa cez súbor (`-F`), trailer `Co-Authored-By` so **skutočným modelom tejto session**.
   Pred každým „hotovo“ (aj STOP pred PR) počkaj na zelené CI pushnutej hlavy (`gh run watch`); červené oprav a znova.
6. **Trieda Ľ/S:** pred návratom zmeraj **skutočný diff kódu pluginu** ([DEFINICIE § D3](../DEFINICIE.md#d3)); nad hranicou triedy Ť to
   ohlás v reporte a PR neotváraj — dávka sa reklasifikuje na Ť.
7. **Predrecenzia — rozhodni PRED `gh pr create`:** povinná podľa [DEFINICIE § D4](../DEFINICIE.md#d4)? **Áno → po pushi STOP:** PR
   neotváraj, vráť report (vetva, plný SHA, ktorá hranica platí); nálezy opravíš, keď ťa orchestrátor osloví, a PR otvoríš **až na jeho
   pokyn** (sekcia „Predrecenzia" do PR popisu podľa výsledku, ktorý ti pošle). **Nie →** krok 8.
8. PR skriptom `scripts\otvor_pr.ps1` (sekcia Verzia, Číslo PR; `-CoAuthor` so skutočným modelom tejto session); popis (`-BodyFile`)
   po slovensky: čo sa mení pre používateľa a ako je to otestované.

## Oprava a shadow

- **Oprava** (pokračovanie tej istej dávky): opravíš nálezy vo svojej vetve, zopakuješ testy, pushneš; v reporte hash opravy ku každému
  nálezu. **Profil Ľ/S (triedy D, Ľ, S):** len P2/P3 bez zmeny konceptu — P0, P1 alebo opravu meniacu koncept (dátový kontrakt, tok,
  návrh riešenia) nerob, vráť ju v reporte (vetva, SHA, nález); ide na profil Ť s novým zadaním (eskalácia v D3).
- **Shadow** (zadanie **začína slovom SHADOW**; WORKFLOW § 2, Matica výberu): namiesto krokov 2, 7, 8 a uzáveru vetva
  `bench/<úloha>-<model>` presne podľa zadania, **žiadny PR** ani predrecenzia, STAV, KRONIKA a PLAN sa nemenia, in-SU runner sa nespúšťa;
  commit + push bench vetvy, vrátiš SHA, čas behu a výsledky testov.

## Report

Po slovensky, funkčne, max ~250 slov: vetva · plný SHA hlavy · PR URL, alebo „PR čaká na predrecenziu" s hranicou · výsledky testov · čo
sa zmenilo pre používateľa · odchýlky a otvorené otázky. Voliteľne na konci **„Postrehy k workflowu"** (0–3 body: konkrétna udalosť ·
čo stála · voliteľne návrh; aj „fungovalo — nemeniť"; ticho je v poriadku) pre retro (WORKFLOW časť 9) — súbory nezapisuj.

<a id="verzia"></a>

## Verzia a uzáver dávky

- `VERSION` žije na 2 miestach: `noxun_engine.rb` (autorita) + `noxun_engine/main.rb` (fallback); synchro stráži guard test.
  **Každý PR meniaci kód pluginu = bump patch**; **minor = výhradne uzáver bloku** (skill `uzaver-bloku`).
- **Každé zvýšenie VERSION = prepis `SYSTEM/STAV.md`** (okrem triedy D — [DEFINICIE § D3](../DEFINICIE.md#d3)); čo robí STAV pri
  dokumentačnom PR, určuje hlavička „Údržba" v [STAV.md](../../STAV.md).
- **Checklist uzáveru kódovej dávky:** bump VERSION (2×) + každý `?v=` v `ui/*.html` (pravidlo: `.claude/rules/ui.md`) → testy zelené →
  **odsek dotknutého modulu v `docs/architecture/<súbor>.md` aktualizovaný na mieste** → **Grepom prehľadaj tvrdenia o zoznamoch,
  ktoré dávka mení** (typy, ikony, schémy, sekcie — napr. `TYPES`, inventár ikon v UI_DIZAJN §4, história `SCHEMA`, zoznam sekcií
  Štúdia) a oprav každý výskyt → vyriešené D-čísla do `SYSTEM/archiv/DOGFOODING_vyriesene.md` (**plný text + PR do sekcie
  „Vyriešené (plné texty)" a jeden riadok navrch INDEXU v tom istom súbore**; `SYSTEM/DOGFOODING.md` drží **len otvorené**) → **prepíš `SYSTEM/STAV.md`
  (okrem triedy D) + záznam dávky: dávka bloku = súbor `SYSTEM/zdroje/bloky/<BLOK>/kronika/<DAVKA>.md`, oprava mimo bloku = odsek navrch
  „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md`** → v `SYSTEM/PLAN.md` ostáva riadok dávky
  v bloku **s ✅ a číslom PR** (presúva sa až s uzáverom bloku).
- **Checklist dokumentačného PR:** záznam dávky (súbor alebo odsek KRONIKY) **áno**; STAV podľa hlavičky „Údržba"; VERSION ani `?v=` **nie**.
- **Číslo PR** (PLAN, KRONIKA, STAV, `DOGFOODING_vyriesene`): pred `gh pr create` sa píše `PR #?`; číslo doplní `scripts\otvor_pr.ps1`
  (PR aj samostatný commit s číslom; `-CoAuthor` povinný).

<a id="testovanie"></a>

## Testovanie

- **Headless a JS sady:** príkazy sú v [AGENTS.md](../../../AGENTS.md#testy); písanie a spúšťanie sád, pasca `node tests/js/test_*.js`:
  `.claude/rules/testy.md`. Počty testov patria do PR a KRONIKY, nie do pravidiel.
- **In-SU test je brána mergu** pri spúšťačoch [DEFINICIE § D6](../DEFINICIE.md#d6) (tam aj výnimka pre finálnu hlavu).
  Runner `scripts\run_su_tests.ps1` spúšťaj **VŽDY s `-CloseWhenDone`**. Paralelné behy sa vylučujú: `exit 2` = iný beh beží alebo
  visí inštancia — počkaj. Výsledkový grep až PO dobehu. Zámok, `_dev` vo worktree a `-DryRun`: `.claude/rules/testy.md`.
- **Export test je brána mergu** dávky, ktorá mení VEPO, CSV kovania, XLSX rozpočtu či ponuky alebo ich cestu: musí dať `P == K`, resp. len
  vedomé rozdiely uvedené v PR (`scripts\export_test.ps1`, `.claude/rules/vystupy.md`). **Fotenie okien** pri UI dávke: `.claude/rules/ui.md`.
  Diagnostika MCP a interaktívny kanál: [NASTROJE_TESTOV.md](../NASTROJE_TESTOV.md#mcp).
- **Lokálne hooky** ([docs/HOOKY.md](../../../docs/HOOKY.md)): hlásenie po Edit/Write oprav hneď; hook pred príkazom
  odmietne commit a push do `main` a runner bez `-CloseWhenDone`.
- **Testuje sa VÝHRADNE v `_dev\ENGINEtests.skp`** (alebo neuloženom Untitled okne BEZ existujúcich NOXUN korpusov; v ňom môžu agenti
  tvoriť/mazať čokoľvek) — **NIKDY v okne so zákazkou**: pred testami over `model.path` / titul okna; bridge len v testovacom okne.
