# Krížový audit V1 — karta A3 · Codex gpt-5.6-sol

Prečítal som celý podklad, zoznamy známych vecí z §5, pravidlá repa, živé workflow dokumenty, architektonické mapy, definície agentov a skillov, dokumentačné guardy aj relevantné JS/CSS/HTML oproti `docs/UI_DIZAJN.md`; auditovaný kód je `main` @ `4da1c3b5`, pracovná vetva navyše obsahuje dokumentačný commit `6d59edef`.

## Os D — dokumenty, pravidlá, skilly a definície agentov

### CS-01 · D · Architektúra je súčasne kontrakt aj kronika
- **Čo:** Živé architektonické dokumenty majú podľa vlastných pravidiel opisovať aktuálny kontrakt, ale veľkú časť tvorí história dávok, review nálezov a zaniknutých riešení. Oddeliť stručný aktuálny kontrakt modulu od generovanej alebo archivovanej histórie; agent pri bežnej zmene potom nemusí rozlišovať, ktorá zo stoviek historických viet ešte platí.
- **Dôkaz:** `docs/architecture/ui-lifecycle.md:5-7` · `docs/architecture/ui-lifecycle.md:3391-3396` · `docs/architecture/ui-lifecycle.md:3500-3507` · `docs/architecture/ui-lifecycle.md:3636-3641` — súbor má 4 102 riadkov a najmenej 182 výskytov značiek `PR #`, `v0.`, audit alebo zánik.
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — priamo znižuje cenu každej UI dávky a dá sa deliť po jednotlivých moduloch bez zásahu do kódu.
- **Overenie nezmeneného výstupu:** Pred presunom vytvoriť zoznam všetkých nadpisov modulov a interných odkazov; po presune spustiť `tests/pure/test_docs_navigacia.rb`, encoding guard a overiť, že každý živý modul má stále presne jeden aktuálny odsek.

### CS-02 · D · Povinné čítanie smeruje na celé monolity
- **Čo:** Tabuľka povinného čítania posiela aj malú UI úpravu do celého `UI_DIZAJN.md` a celého `ui-lifecycle.md`, hoci dokumenty už majú použiteľné modulové nadpisy. Zmeniť router na konkrétne sekcie podľa dotknutého HTML/JS/Ruby modulu a ponechať krátky spoločný „UI minimum“ dokument.
- **Dôkaz:** `CLAUDE.md:8-15` · `docs/architecture/ui-lifecycle.md:1862-1871` · `docs/architecture/ui-lifecycle.md:2375-2377` · `docs/UI_DIZAJN.md:11-54`
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — odstráni stovky kB povinného čítania pri každej UI dávke a dá sa spraviť ako jednodňový dokumentačný rez.
- **Overenie nezmeneného výstupu:** Doplniť tabuľkový guard: každý UI modul uvedený v `docs/ARCHITEKTURA.md` musí mať cieľový nadpis a spoločné minimum; následne spustiť dokumentačné guardy.

### CS-03 · D · Jedno workflow pravidlo sa udržiava v troch vrstvách
- **Čo:** Hranice auditu, predrecenzie, kvót, SketchUp testu a troch review kôl sú opísané v `CLAUDE.md`, znovu v `WORKFLOW.md` a tretíkrát v skilloch. Ponechať normatívne podmienky na jednom mieste; mapa a skilly majú iba odkazovať na stabilné ID pravidla a opisovať svoju procedúru.
- **Dôkaz:** `CLAUDE.md:36-75` · `SYSTEM/WORKFLOW.md:294-307` · `SYSTEM/WORKFLOW.md:313-320` · `.claude/skills/codex-audit/SKILL.md:8-13`
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — zmenší riziko, že agent použije starú hranicu, a zároveň skráti povinný kontext.
- **Overenie nezmeneného výstupu:** Zaviesť guard stabilných ID pravidiel a overiť, že každý odkaz zo skillov a workflow mapy smeruje na existujúce ID; zachovať existujúce workflow testy.

### CS-04 · D · Guardy strážia tvar, nie rast živých dokumentov
- **Čo:** Guard obmedzuje veľkosť iba `STAV.md`; pri architektonických dokumentoch kontroluje zoznam súborov, dĺžku jednotlivého riadka a odkazy. Pridať rozumný limit aktuálneho kontraktu na modul alebo kontrolu zakázaných historických markerov mimo explicitnej sekcie, inak sa po vyčistení monolity opäť nafúknu.
- **Dôkaz:** `tests/pure/test_docs_navigacia.rb:3-15` · `tests/pure/test_docs_navigacia.rb:35-44` · `tests/pure/test_docs_navigacia.rb:303-322`
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie
- **Návrh zaradenia:** HARDENING — je to malá poistka potrebná v tej istej dávke ako rozdelenie dokumentácie.
- **Overenie nezmeneného výstupu:** Charakterizačne spustiť nový guard najprv v reportovacom režime; po vyčistení ho prepnúť na tvrdú bránu spolu s existujúcou sadou `test_docs_navigacia.rb`.

### CS-05 · D · Obsadenie agentov má dve pravdy bez kontroly zhody
- **Čo:** Model a effort sú uvedené v tabuľke rolí aj vo frontmatteri agentov, ale guard kontroluje iba platnosť hodnoty a výskyt mena typu vo `WORKFLOW.md`. Pri budúcej zmene modelu môže jedna strana zostať stará; guard má parsovať tabuľku a porovnať konkrétny model/effort.
- **Dôkaz:** `SYSTEM/WORKFLOW.md:31-49` · `.claude/agents/reserser.md:2-6` · `.claude/agents/agy-reserser.md:2-6` · `tests/pure/test_agent_definitions.rb:6-10` · `tests/pure/test_agent_definitions.rb:72-81` · `tests/pure/test_agent_definitions.rb:101-105`
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — lacno zabráni spusteniu drahej úlohy na inom modeli, než Michal rozhodol.
- **Overenie nezmeneného výstupu:** Rozšíriť `test_agent_definitions.rb` o mapu `typ → model, effort` a pridať negatívny fixture s úmyselne rozdielnym modelom.

### CS-06 · D · UI dizajn mieša normu s realizačným denníkom
- **Čo:** Design system obsahuje živé tokeny a princípy, ale aj detailný priebeh už dokončených dávok, staré premostenia a poznámky o zaniknutých oknách. Rozdeliť ho na krátku normu komponentov a samostatný katalóg aktuálnych vzorov; históriu presunúť do archívu.
- **Dôkaz:** `docs/UI_DIZAJN.md:3-7` · `docs/UI_DIZAJN.md:377-408` · `docs/UI_DIZAJN.md:1369-1400` · `docs/UI_DIZAJN.md:1411-1437`
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** HARDENING — každá UI úprava tento dokument číta povinne; rez okamžite znižuje cenu práce.
- **Overenie nezmeneného výstupu:** Zachovať všetky tokeny, komponentové pravidlá a kotvy používané testami; spustiť `test_ui01_paleta.rb`, testy inventára ikon a `test_docs_navigacia.rb`.

### CS-07 · D · Zaniknuté okná zostávajú v živej mape
- **Čo:** Živý dokument má samostatné odseky pre okná, ktoré už neexistujú, alebo pre moduly pomenované ako dialóg, hoci dnes dialógom nie sú. Aktuálna mapa má opisovať dnešný vstup a staré okno iba jednou vetou s odkazom do archívu.
- **Dôkaz:** `docs/architecture/ui-lifecycle.md:3372-3396` · `docs/architecture/ui-lifecycle.md:3500-3507` · `docs/architecture/ui-lifecycle.md:3636-3641`
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — nový agent nebude hľadať neexistujúce UI cesty; ide o bezpečný dokumentačný rez.
- **Overenie nezmeneného výstupu:** Porovnať zoznam živých HTML/HtmlDialog vstupov z kódu so zoznamom okien v dokumente a pridať guard, že zaniknutý súbor nesmie mať živý modulový nadpis.

### CS-08 · D · Operatívny skill obsahuje rýchlo starnúce lokálne fakty
- **Čo:** Audit skill mieša trvalý postup s konkrétnou verziou CLI, starou cestou desktopovej binárky, dátumom PATH opravy a interným spôsobom zabíjania brokera. Presunúť detekciu prostredia do jedného skriptu a v skille ponechať iba výsledok kontroly a obnovovací postup.
- **Dôkaz:** `.claude/skills/codex-audit/SKILL.md:8-13` · `.claude/skills/codex-audit/SKILL.md:24-33` · `CLAUDE.md:88-96`
- **Scenár:** S6
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — znižuje pravdepodobnosť, že agent nasleduje starú cestu alebo verziu, bez zmeny produktového kódu.
- **Overenie nezmeneného výstupu:** Test skriptu nad stavmi „aktuálny CLI“, „starý CLI“, „runtime chýba“; skill musí pre každý stav vrátiť rovnaké rozhodnutie ako dnešný postup.

## Os U — nekonzistencie UI voči `docs/UI_DIZAJN.md`

### CS-09 · U · Mazacie akcie používajú Unicode glyf namiesto ikony
- **Čo:** Editory setov a pravidiel vykresľujú odoberacie tlačidlá znakom `×`, hoci design system prikazuje sprite ikonu alebo čistý text. Nahradiť glyf ikonou `trash`/`x` zo spritu a doplniť `aria-label` tam, kde je tlačidlo iba ikonové.
- **Dôkaz:** `docs/UI_DIZAJN.md:15-16` · `docs/UI_DIZAJN.md:530-533` · `noxun_engine/ui/js/hw_sets.js:969-974` · `noxun_engine/ui/js/hw_sets.js:1037-1041` · `noxun_engine/ui/js/rules.js:148-150` · `noxun_engine/ui/js/rules.js:595-600`
- **Scenár:** -
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — je to malá, dátovo neutrálna konzistencia ovládania.

### CS-10 · U · Nové UI stále pridáva trvalé `.hint` bloky
- **Čo:** Pravidlá kovania zobrazujú dlhé pomocné vysvetlenia ako stále riadky, hoci design system vyžaduje tooltip a zakazuje pridávať `.hint` do nového UI. Premiestniť všeobecné vysvetlenie do informačnej ikony; viditeľný ponechať iba aktuálny chybový stav poškodených dát.
- **Dôkaz:** `docs/UI_DIZAJN.md:45-52` · `noxun_engine/ui/js/rules.js:606-614`
- **Scenár:** -
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — šetrí vertikálny priestor bez zmeny dát alebo výpočtov.

### CS-11 · U · Nedostupná primárna akcia používa HTML `disabled`
- **Čo:** Potvrdenie importu z Demosu je vyradené z klávesnicového poradia cez `disabled`; design system vyžaduje fokusovateľné `aria-disabled` s vysvetlením dôvodu. Zjednotiť stav s ostatnými nedostupnými akciami a blokovať aktiváciu v delegovanom handleri.
- **Dôkaz:** `docs/UI_DIZAJN.md:29-33` · `noxun_engine/ui/studio.html:924-931`
- **Scenár:** -
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — malá prístupnostná oprava bez dopadu na výrobné alebo cenové dáta.

## Doplnky k známym

- **R-32:** Nový merateľný fakt: `docs/architecture/ui-lifecycle.md` má 4 102 riadkov a najmenej 182 historických markerov; problém teda nie je iba päť prázdnych a štyri kostrové odseky. Súčasný guard navyše neobmedzuje veľkosť ani podiel histórie v živej architektúre (`tests/pure/test_docs_navigacia.rb:35-44`).
- **R-27:** Bez novej položky — známe nepresné texty Pravidiel neopakujem; CS-10 rieši iba rozpor spôsobu zobrazenia pomocného textu s design systémom.

## Čo som nestihol / neistoty

- Auditovaný produktový stav je `main` @ `4da1c3b5`; HEAD worktree je `6d59edef`, ktorý pridáva iba podklady tohto auditu.
- Nevykonal som vizuálny audit screenshotov — karta A3 požaduje porovnanie zdrojov JS/CSS/HTML, nie používateľský screenshotový audit A5.
- Pri rozdelení veľkých dokumentov treba pred zásahom zmerať odkazy na konkrétne nadpisy aj mimo dokumentačných guardov; dnešný test kontroluje existenciu súboru, nie existenciu fragmentu za `#`.
- Repo zostalo iba čítané; nič som nezmenil ani nevytvoril.
