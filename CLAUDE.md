# Noxun Engine — pravidlá práce v repe

SketchUp Ruby plugin — parametrický nábytkársky systém (korpusy, zóny, čelá, materiály/ABS, kovanie, výstupy).
GitHub: https://github.com/michalmoronga-alt/noxun-panel

## Povinné čítanie podľa typu práce

**Nájdi riadok svojho zásahu a uvedené dokumenty si prečítaj PRED prácou.** Je to povinnosť, nie odporúčanie: automaticky sa načíta LEN tento súbor — architektúra, štandard ani pravidlá kódu nie. Neprečítaný riadok = zásah naslepo.

| Ideš robiť… | Pred prácou POVINNE prečítaj |
|---|---|
| **novú dávku · plánovanie · zadanie** | [SYSTEM/STAV.md](SYSTEM/STAV.md) (kde projekt je) → [SYSTEM/PLAN.md](SYSTEM/PLAN.md) (blok, do ktorého dávka patrí) → skupinu toho bloku v [SYSTEM/DOGFOODING.md](SYSTEM/DOGFOODING.md) (plné znenia **otvorených** D-čísel) → zadanie dávky v priečinku bloku `SYSTEM/zdroje/bloky/<BLOK>/`. Keď nevieš, ktorý dokument je autorita na čo: [SYSTEM/README.md](SYSTEM/README.md) |
| **zmenu Ruby kódu — core / modules** | rozcestník [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) → odseky **dotknutých modulov** v `docs/architecture/` (nájdeš ich Grepom podľa mena súboru) + dotknuté § [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) |
| **buildery · observery · undo · geometriu** | [docs/architecture/construction.md](docs/architecture/construction.md) (`construction`, `cabinet_builder`, `board_builder`, `zone_tree`, `scale_observer`) + [docs/SKETCHUP_PRAVIDLA.md](docs/SKETCHUP_PRAVIDLA.md) + STANDARD §3, §4, §9. **In-SU test je tu brána mergu** (spúšťače a runner: sekcia **Testovanie**) — headless sada geometriu ani undo neoverí |
| **UI — panel, HTML, JS, CSS, satelitné okná** | [docs/UI_DIZAJN.md](docs/UI_DIZAJN.md) (pri KAŽDEJ UI práci) + [docs/architecture/ui-lifecycle.md](docs/architecture/ui-lifecycle.md) + **cache-bust pravidlo** nižšie (`?v=` = presne VERSION) + trvalé pravidlo **„vertikálny priestor panela je vzácny"** ([SYSTEM/PLAN.md](SYSTEM/PLAN.md), sekcia Trvalé UI/UX pravidlo) |
| **materiály · ABS · katalóg · Demos** | [docs/architecture/materials.md](docs/architecture/materials.md) — `materials`, `materials_*` split, `materials_migration`, `materials_health`, `abs_rules`, `demos/` + [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) **§7 Materiály a ABS** |
| **kovanie — pravidlá, sety, katalóg** | [docs/architecture/hardware.md](docs/architecture/hardware.md) — `hardware_rules`, `hardware_catalog`, `hardware_sets` + [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) **§6 Kovanie** |
| **výstupy — VEPO, kusovník, nákup, CSV/XLSX** | [SYSTEM/VEPO_KONTRAKT.md](SYSTEM/VEPO_KONTRAKT.md) + [docs/architecture/outputs.md](docs/architecture/outputs.md) (`validation`, `production_core`) + [docs/architecture/model-a-identita.md](docs/architecture/model-a-identita.md) (`build_plan`, `part_keys`) + STANDARD §8 a §11 |
| **bugfix · diagnostiku · „prečo to padá"** | mapa „Kam sa pozrieť" v [SYSTEM/STAV.md](SYSTEM/STAV.md) → odsek dotknutého modulu v `docs/architecture/` (cez rozcestník [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md)) → pri otázke **„prečo je to takto?"** [SYSTEM/archiv/KRONIKA.md](SYSTEM/archiv/KRONIKA.md) a [SYSTEM/archiv/DOGFOODING_vyriesene.md](SYSTEM/archiv/DOGFOODING_vyriesene.md) |
| **testy — novú sadu alebo úpravu** | sekcia **Testovanie** nižšie + vzory v `tests/pure/`, `tests/js/`, `tests/sketchup/` (nová sada = štruktúra najbližšej existujúcej, nie vlastný formát) |
| **code review · audit návrhu** | [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) (kontrakt, proti ktorému sa posudzuje) + odseky dotknutých modulov v `docs/architecture/` + skill `codex-audit` |
| **dynamické komponenty (DC)** | [docs/DC_PRAVIDLA.md](docs/DC_PRAVIDLA.md) — vždy a bez výnimky (draho zaplatené pasce) |
| **workflow · pravidlá práce · skilly** | [SYSTEM/WORKFLOW.md](SYSTEM/WORKFLOW.md) (roly a ich obsadenie, diagramy blok · dávka · review, brány, hranice) + záznam „prečo" [WORKFLOW_ROZHODNUTIA_2026-09-26.md](SYSTEM/zdroje/next_sessions/WORKFLOW_ROZHODNUTIA_2026-09-26.md) |

Keď zásah spadá do viacerých riadkov, platia VŠETKY. **Architektúra sa udržiava priebežne:** dávka, ktorá mení modul, prepíše JEHO odsek v príslušnom súbore `docs/architecture/` — nikdy nepridáva text na koniec súboru. Nový modul = nový odsek v správnom súbore **a** nový riadok v tabuľke rozcestníka [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) (guard test to stráži).

## Roly a modely

- Pravidlá v tomto súbore a v skilloch hovoria o **rolách**: **orchestrátor** (hlavné okno), **implementátor**, **slepý recenzent**,
  **audítor**, **rešeršér** a **review PR**. Čo ktorá rola robí a rozhoduje: [SYSTEM/WORKFLOW.md](SYSTEM/WORKFLOW.md).
- **Ktorý model a nástroj hrá ktorú rolu, určuje Michal** (benchmarky, limity, cena). Aktuálne obsadenie aj príkazy volania sú v JEDINEJ
  tabuľke **„Obsadenie rolí"** vo WORKFLOW.md — mení ju Michal; inde sa model ani príkaz volania neopakuje. Pravidlá sa píšu nezávisle
  od nástroja (možný budúci prechod mimo Claude Code).

## Git workflow (záväzné od 16.7.2026, revízie RETRO 12.8. a WORKFLOW 26.9.2026)

- **Žiadne priame commity do `main`.** Každá zmena: **vetva → commity → PR → review → merge po splnení brán** (nižšie). Vetvy
  `feat/<krátky-popis>`, `fix/<popis>`, `docs/<popis>`; **uzáver bloku `release/<blok>`**. Paralelné úlohy: každá vo vlastnej vetve
  (agenti: worktree izolácia), konflikty rieši integrácia pred PR.
- **Delegovanie:** implementáciu dávok, predrecenziu, kontrolu opráv, overenia a široké hľadanie robí **subagent**; orchestrátor drží
  kontext bloku, rozhodnutia a merge (dôvod: kompresia kontextu).
- **Merge robí orchestrátor** (`gh pr merge <N> --merge --match-head-commit <SHA>` — pripnutá presne tá hlava, ktorá prešla bránami) po
  splnení OBOCH brán **pre aktuálnu hlavu vetvy**: **CI zelené** + **review kolo uzavreté**. Nikdy nemergovať hneď po pushi opráv len
  preto, že CI zbehlo skôr než review. Po mergi **návrat na čerstvý `main`** (`git checkout main && git pull`) a **inštalácia mainu**
  (sekcia Verzia a uzáver) — ďalšia dávka štartuje odtiaľ. Vetvy na GitHube maže repo automaticky. Postup: skill `codex-po-pr`.
- **Review kolá (delta-verifikácia):** kolo 1 = vždy plné GH Codex review. Ak vráti **LEN P2/P3**, nové GH kolo sa nevyžaduje: fix push
  + reply s hashom v threadoch + **interná delta** (nový slepý subagent overí výhradne fix commity) → merge. Platí **aj pre audit-povinné
  a výrobné/cenové dávky, ak prešli predrecenziou**. Nové PLNÉ GH kolo (`@codex review`) len pri **P0/P1** alebo oprave, ktorá **mení
  koncept** — a pri audit-povinnej či výrobnej/cenovej dávke bez predrecenzie.
- **Opravy z review:** opravu robí **pôvodný implementátor** (pokračovanie toho istého subagenta — pozná kód aj dôvody), kontrolu opravy
  **nový slepý subagent**. Pri P0/P1 alebo zmene konceptu **nový subagent s novým zadaním** (a pravidlo 3 kôl b). Označenie implementátora
  sa zapíše do handoffu skôr, než sa kontext orchestrátora skomprimuje.
- **Pravidlo 3 kôl:** počítajú sa GH kolá review, ktoré vrátili nálezy. Keď nálezy vráti aj **3. kolo**: **(a) len P2/P3 bez zmeny
  konceptu** → **vedomá výnimka** (oprava na mieste + slepá delta fix commitov, **bez 4. GH kola**, zápis do PR a KRONIKY); **(b) P0/P1
  alebo oprava mení koncept** (dátový kontrakt, tok, návrh riešenia) → PR bol zle narezaný — **zavrieť a rozdeliť**, nie iterovať; platí
  aj vtedy, keď to nájde slepá delta. Detail a precedensy: skill `codex-po-pr`.
- **Výrobná/cenová dávka (jediná definícia):** dávka, ktorá mení **rozmery alebo počty dielov, hrany, kusovník, VEPO, nákupné zoznamy,
  kovanie alebo ceny**.
- **Audit návrhu PRED implementáciou (skill `codex-audit`, risk-based od 12.8.):** povinný **LEN** pre dávky meniace **dátový kontrakt,
  schému, migráciu, observer/undo lifecycle** alebo pridávajúce **nový modul** — rozhoduje OBSAH zásahu, nie žáner dávky (aj „fix"
  observera je audit-povinný). **Zmena schémy = každé zvýšenie `CONFIG_SCHEMA`, BuildPlan `SCHEMA` alebo STD.** Ostatné fix, docs a UI
  dávky idú rovno do implementácie (v prostredí bez Codex CLI krok neblokuje — ohlás a pokračuj). Skill `codex-po-pr` po odoslaní PR je
  povinný **bez výnimky**. Skilly sú v `.claude/skills/`.
- **Slepá predrecenzia PRED PR (skill `predrecenzia`):** **povinná** pri dávke **audit-povinnej** (tá istá trieda ako `codex-audit`),
  **výrobnej/cenovej** a **aj pri bežnej dávke nad 300 zmenených riadkov kódu pluginu** (bez testov a dokumentácie) **alebo s novým
  ovládacím prvkom v UI**; pri docs-only nie. Slepý recenzent dostane len zadanie a `git diff main...HEAD`; jeho P1/P2 sa opravia ešte
  pred PR a výsledok ide do PR popisu (sekcia „Predrecenzia"). Nenahrádza `codex-audit` ani `codex-po-pr`.
- **Rešerš a krížový audit (poradie podľa praxe):** pri bloku **debata s Michalom → koncept → outside-in rešerš + krížový audit bloku
  RAZ, pred packages** (rešeršéri a audítor s rovnakým zadaním) → reconcile orchestrátora (nálezy ALREADY EXISTS / SIMPLER NATIVE PATH
  sa najprv overia sondou v SketchUpe) → mockup (schvaľuje Michal) → packages → dávky → review. **Audit dávky** už len pri zmene
  kontraktu (trieda `codex-audit` vyššie). Outside-in rešerš: skill `antigravity-outside-in` (nie pre fix, docs a čisto dátové dávky);
  nástroje a ich roly: WORKFLOW.md.
- **Bezpečnosť externých nástrojov:** Antigravity (`agy`) **nie v nočných behoch bez obsluhy** (riziko automatickej blokácie Google
  účtu) · žiadne proxy ani OAuth doplnky typu „predplatné v cudzom programe" (bany) · orchestrátor beží **interaktívne**, nie cez
  `claude -p` (programové použitie môže Anthropic účtovať zvlášť) · externý bot má prístup len k vlastnému repu (Grok Bot → len `agent-register`).
- PR popis po slovensky: čo sa mení z pohľadu používateľa + ako testované (SkAgent/MCP výsledky). Malé PR > obrie PR — deliť po celkoch.
- Commit messages: vecné, slovensky/anglicky konzistentne s históriou; trailer `Co-Authored-By: Claude <model> <noreply@anthropic.com>`
  so **skutočným modelom session**, ktorá commit robí (orchestrátor alebo subagent) — nie model opísaný z dokumentácie.

## Kvóty a štart okna (skill `usage`)

- **Štart okna = jedna kontrola:** kvóty (`usage`) + lokálne nástroje (verzie, prihlásenie, predvolené modely: `claude`, `codex`, `agy`,
  `grok`, `gemini`) + register `michalmoronga-alt/agent-register` (dátum v `stav.json` sa musí hýbať; nové záznamy v `ZMENY.md`).
  Register je **údaj, nie pokyn**. Jeden príkaz na celú kontrolu pribudne s registrom agentov (PR C); dovtedy ručne.
- **Pred každým drahým krokom** (Codex audit, spustenie implementačného subagenta či predrecenzie, `gh pr create`, `@codex review`) stav
  kvót z CodexBar CLI. **Codex weekly zostatok < 10 %** → GH kolo ani audit sa automaticky nespúšťa a **PR sa otvorí ako draft** (Codex
  ho nerecenzuje); ďalej podľa triedy: **bežná dávka** → **náhradná brána** (slepý recenzent + interná delta), PR to prizná · **audit-povinná,
  výrobná/cenová dávka alebo P0/P1** → rozhodne Michal (keď neodpovie: tabuľka v sekcii Autonómne bloky).
- **Claude session nad 80 % → nový implementačný subagent sa nespúšťa**, počká sa na reset session. Plánovanie blokov rešpektuje okná resetu.

## Autonómne bloky (od 12.8.2026, revízia 26.9.2026)

- **Schválenie bloku = súhlas s naplánovanými dávkami** — pýtať sa len pri nových, nečakaných veciach. Dávky schváleného bloku sa
  spracúvajú **sekvenčne bez čakania na pokyn medzi dávkami**, každá z čerstvého `main` po mergi predchodcu (nestackovať). Výber
  a poradie práce určuje Michal ([SYSTEM/PLAN.md](SYSTEM/PLAN.md)) — agent si sám dávky nevyberá.
- **Keď Michal neodpovie — predvolené reakcie:**

| Situácia | Reakcia |
|---|---|
| P0/P1 v review | oprava + nové plné GH kolo; ak oprava mení koncept → PR zavrieť a rozdeliť |
| in-SU test zlyhá | nemergovať; najviac 2 pokusy o opravu, potom dávka čaká a ide do reportu; test nikdy neobchádzať |
| Codex weekly zostatok < 10 % | bežná dávka → náhradná brána (slepý subagent + delta); audit-povinná/výrobná/cenová → otázka Michalovi, kým neodpovie, dávka čaká a pokračuje sa ďalšou nezávislou |
| nejasnosť v zadaní | otázka do chatu; kým neodpovie, bezpečnejšia vratná voľba len ak nemení dáta ani výrobné/cenové čísla — označiť v PR aj reporte; inak dávka čaká |
| červený main · riziko pre zákazku · zaseknutý SketchUp/PC · potreba hesla | zastaviť celý beh a čakať na Michala |

- **Report** vždy, keď autonómny beh **skončí alebo sa zastaví**, najneskôr večer — zrozumiteľný z mobilu, bez čítania diffu: čo je
  v maine · čo čaká a prečo · čo zlyhalo · čo večer otestovať.
- **Uzáver bloku = variant B:** hneď po poslednej dávke (minor verzia + smoke checklist v archíve; postup v sekcii Verzia a uzáver);
  nálezy zo smoke sú opravy x.y.z. **Poistka:** nový blok sa začína až po Michalovom **smoke PASS** alebo výslovnom **„ideme ďalej"**.
- **Uzáver pri plnom kontexte:** keď má orchestrátor pred uzáverom viac ako ~70 % kontextu, uzáver poskladá **čerstvý subagent len
  z repa** (PLAN, KRONIKA, DOGFOODING, PR); orchestrátor ho skontroluje a zmerguje. Čo subagent v repe nenájde, žilo len v chate.
- **Chat nie je úložisko:** rozhodnutia, checklisty a zadania idú hneď do repa alebo pamäte — po kompresii kontextu z chatu miznú.

## Verzia a uzáver dávky (od v0.5.0, revízia 26.9.2026)

- `VERSION` žije na 2 miestach: `noxun_engine.rb` (autorita) + `noxun_engine/main.rb` (fallback) — synchro stráži guard test.
- **Každý PR meniaci kód pluginu = bump patch** (0.5.0 → 0.5.1); **minor = výhradne uzáver bloku z `SYSTEM/PLAN.md`** (0.5.x → 0.6.0).
- **Každé zvýšenie VERSION = prepis `SYSTEM/STAV.md`** (aj pri malom fixe); dokumentačné PR STAV nemenia.
- **Cache-bust:** každý `?v=` v `ui/*.html` = presne VERSION (stráži guard test; CEF cachuje css/js). Zmena css/js ⇒ bump verzie ⇒ prepísať všetky `?v=`.
- **Checklist uzáveru kódovej dávky:** bump VERSION (2×) + `?v=` → testy zelené → **odsek dotknutého modulu v `docs/architecture/<súbor>.md`
  aktualizovaný na mieste** → vyriešené D-čísla do `SYSTEM/archiv/DOGFOODING_vyriesene.md` (**plný text + PR do sekcie „Vyriešené (plné
  texty)" a jeden riadok navrch INDEXU v tom istom súbore**; `SYSTEM/DOGFOODING.md` drží **len otvorené** postrehy) → **prepíš
  `SYSTEM/STAV.md` + APPEND odsek navrch „Záznamy dávok" v `SYSTEM/archiv/KRONIKA.md`** → v `SYSTEM/PLAN.md` ostáva riadok dávky v bloku
  **s ✅ a číslom PR** (presúva sa až s uzáverom bloku).
- **Checklist dokumentačného PR:** odsek navrch „Záznamy dávok" v KRONIKE **áno**; STAV, VERSION ani `?v=` **nie**.
- **Číslo PR v PLAN a KRONIKE:** pred `gh pr create` sa píše `PR #?`; hneď po vytvorení PR ho doplní samostatný commit, ktorý mení len
  číslo (patrí do internej delta-kontroly).
- **Uzáver bloku (vetva `release/<blok>`):** minor bump + `?v=` → hotový blok z `SYSTEM/PLAN.md` plným textom do
  `SYSTEM/archiv/ROADMAP_hotove_etapy.md` (v PLAN ostávajú len nehotové bloky a trvalé pravidlá) → **celý priečinok bloku** do
  `SYSTEM/archiv/bloky/<BLOK>/` + kontrola odkazov → V1_VIZIA, README, STAV, KRONIKA. Skupina „smoke po uzávere" v DOGFOODING je
  dočasná — zanikne s posledným nálezom.
- **Priečinok bloku je v repe od štartu bloku:** debata, mockup, packages, briefy a smoke checklist v `SYSTEM/zdroje/bloky/<BLOK>/` — nie
  v `_dev/` ani v chate; počas bloku sú autoritou. Po uzávere sa **celý priečinok fyzicky presúva** do `SYSTEM/archiv/bloky/<BLOK>/`
  s kontrolou odkazov. Existujúce mockupy v `SYSTEM/zdroje/ui20/` sa nepresúvajú.
- **Po KAŽDOM mergi nainštalovať main** do SketchUpu (`INSTALL_noxun_engine.ps1` z čerstvého `main`) — in-SU runner nasadzuje
  rozpracovanú vetvu a updater pri rovnakom čísle verzie nič neponúkne.

## Špecifikácia a kontext (všetko v tomto repe)

- **Záväzný štandard dát:** [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) (dictionary NOXUN, mm Float, roly, regenerate pattern)
- **Architektúra modulov (core / modules / ui) + kľúčové invarianty:** rozcestník [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) + mapa v `docs/architecture/` ([model-a-identita](docs/architecture/model-a-identita.md) · [construction](docs/architecture/construction.md) · [materials](docs/architecture/materials.md) · [hardware](docs/architecture/hardware.md) · [outputs](docs/architecture/outputs.md) · [ui-lifecycle](docs/architecture/ui-lifecycle.md)) — JEDINÉ miesto, kde architektúra žije; číta sa pri práci na kóde podľa tabuľky vyššie
- **Mapa autorít priečinka `SYSTEM/`** (ktorý dokument je autorita na čo, poradie čítania, vrstvy živé / zdroje / archiv): [SYSTEM/README.md](SYSTEM/README.md)
- **Mapa workflowu** (roly a ich obsadenie, diagramy blok · dávka · review, brány, hranice): [SYSTEM/WORKFLOW.md](SYSTEM/WORKFLOW.md)
- **Kde projekt je (čítaj ako prvé):** [SYSTEM/STAV.md](SYSTEM/STAV.md) · plán a bloky prác: [SYSTEM/PLAN.md](SYSTEM/PLAN.md) · história dávok: [SYSTEM/archiv/KRONIKA.md](SYSTEM/archiv/KRONIKA.md) · dogfooding zápisník (len otvorené postrehy): [SYSTEM/DOGFOODING.md](SYSTEM/DOGFOODING.md) · cieľ V1: [SYSTEM/V1_VIZIA.md](SYSTEM/V1_VIZIA.md) *(pôvodná UI vízia zo 16.7. je od 26.8. v archíve: [SYSTEM/archiv/UI_VIZIA_2026-07.md](SYSTEM/archiv/UI_VIZIA_2026-07.md) — prekonaná Inspectorom a Štúdiom)*
- **Glosár pojmov + stolárske poznatky:** [SYSTEM/POJMY.md](SYSTEM/POJMY.md) — jednotný jazyk sedení a fakty domény (postforming, formáty, hrúbky, ABS obchodné hodnoty); trvalé poznatky z hlásení zapisovať SEM
- **Historické dokumenty (uzavreté rozhodnutia, plné texty hotových etáp a vyriešených postrehov):** [SYSTEM/archiv/](SYSTEM/archiv/)
- **Pravidlá SketchUp kódu:** [docs/SKETCHUP_PRAVIDLA.md](docs/SKETCHUP_PRAVIDLA.md) · DC pasce: [docs/DC_PRAVIDLA.md](docs/DC_PRAVIDLA.md) · UI dizajn: [docs/UI_DIZAJN.md](docs/UI_DIZAJN.md) — kompletné a samostatné v tomto repe. (Nadradený `..\CLAUDE.md` existuje len v Michalovom lokálnom workspace `C:\APP DEV\RUBY` — mapa ostatných pluginov; pre prácu v tomto repe nie je potrebný.)

## Testovanie (záväzné pravidlá)

- **Automatické testy:** headless sada `ruby tests/run_all.rb` beží v GitHub Actions na každý push/PR (lokálne `scripts\run_tests.ps1`,
  vyžaduje standalone Ruby v `C:\Ruby32-x64`) + **JS sady** — spúšťať KAŽDÚ zvlášť, bash: `for f in tests/js/test_*.js; do node "$f" || exit 1; done`
  (POZOR: `node tests/js/test_*.js` spustí len PRVÝ súbor, zvyšok sú preň argumenty; CI ich spúšťa všetky — lokálne tiež všetky, nie len
  test_expr). **Počty testov sa sem nepíšu** — patria do PR a KRONIKY; STAV drží jeden riadok posledného behu.
- **In-SU test je brána mergu**, keď dávka mení **buildery, observery, undo a operácie, geometriu alebo akcie panela zapisujúce do
  modelu** (jediný zoznam spúšťačov; headless sada geometriu ani undo neoverí). Runner `scripts\run_su_tests.ps1`: deploy → inštancia nad
  kópiou ENGINEtests.skp → poll → výsledok; overuje geometriu plán↔model a undo scenáre; výsledkový grep až PO dobehu (output sa dopisuje).
- **Agent spúšťa runner VŽDY s `-CloseWhenDone`** (bez neho len Michalovo ručné spustenie): inštancia po koncovom markeri sama uloží
  run-kópiu modelu a ukončí sa; runner počká na zánik procesu (max 120 s) a nikdy nezabíja. Teardown po celej sade končí kódom
  0xC0000374 až PO zapísaní výsledku — verdikt to nemení (detail v hlavičke runnera). **Paralelné behy sa vylučujú**
  (`%TEMP%\noxun_su_tests\deploy.lock` + sentinel `last_run.txt`): `exit 2` = iný beh práve beží (počkaj a spusti znova) alebo visiaca
  inštancia ešte testuje (zavri ju alebo počkaj na dobeh); výsledky a kópia modelu sú per-beh v `run_*` priečinku.
- **Lokálne hooky (od 24.7., `.claude/settings.json`):** PostToolUse po každom Edit/Write spustí `.claude/hooks/post_edit_check.ps1` — kontrola editovaného súboru: `ruby -c` syntax (.rb) + encoding guard UTF-8/BOM/mojibake/cyrilické homoglyfy (.rb/.js/.html/.css/.md/.ps1, rovnaká logika ako `tests/pure/test_encoding_guard.rb`). Je to rýchla spätná väzba (edit už je zapísaný — pri hláške chybu HNEĎ oprav); vynucovanie ostáva na CI.
  **Ukazovateľ kontextu** (od 26.9.2026, `.claude/hooks/context_meter.js`): hlavnému agentovi vloží riadok `Kontext orchestrátora: 612k z 1M (61 %).` pri každej správe Michala
  a po nástroji len pri prechode do vyššieho pásma (50–95 %); subagentov nechá na pokoji. **Od 75 %** zapísať rozpracovaný stav do repa/pamäte a čítanie delegovať
  subagentom; **od 90 %** navrhnúť Michalovi `/compact` na hranici dávky.
- Interaktívny kanál: MCP `mcp__vbo-sketchup__execute_ruby` (SketchUp 2026 + VBO SkAgent, port 7891); fallback file-bridge (`vbo_sk_agent\bridge\command.rb` → `result.json`, pozor na mtime pascu); overená slučka `-RubyStartup skript + kópia modelu` (vzor v `scripts\run_su_tests.ps1`). Deploy: `INSTALL_noxun_engine.ps1`.
- **Diagnostika MCP (V0.4.7+):** pri visiacom/zamrznutom porte 7891 spusti `scripts\skagent_doctor.ps1` — zistí držiteľa portu a `/health`, `-Kill` odstráni zamrznutý bridge (živú zákazku ani cez `-Force` nezabije). Dump stavu enginu pre bugcatch: `Noxun::Engine::Debug.report` cez `execute_ruby` (model + výber + stav panela ako read-only JSON, nikdy nezapisuje).
- **Testuje sa VÝHRADNE v testovacom projekte `_dev\ENGINEtests.skp`** (alebo neuloženom Untitled okne BEZ existujúcich NOXUN korpusov) — v ňom môžu agenti tvoriť/mazať čokoľvek. `_dev/` je gitignorované.
- **NIKDY netestovať v okne so zákazkou** — pred testami vždy overiť `model.path`/titul okna (bridge vykonáva príkazy v každom okne, kde je zapnutý — bridge zapínať len v testovacom okne).
