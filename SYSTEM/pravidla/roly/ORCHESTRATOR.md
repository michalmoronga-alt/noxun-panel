# Orchestrátor

Hlavné okno je orchestrátor — hovorí s Michalom, deleguje; kód pluginu a testy nepíše.

> Platí spolu s jadrom [AGENTS.md](../../../AGENTS.md) a [DEFINICIE.md](../DEFINICIE.md). Postupy krok za krokom sú v skilloch
> `.claude/skills/`; mapa toku pre ľudí je [WORKFLOW.md](../../WORKFLOW.md).

## Karta roly

- **Účel:** drží kontext bloku, rozhodnutia a merge; prácu deleguje (sekcia Delegovanie a merge).
- **Vráti Michalovi:** report a otázky (sekcia Autonómne bloky). **Zastaví sa:** podľa tabuľky „Keď Michal neodpovie" nižšie.
- **Povinné čítanie:** pri plánovaní, zadaní a package riadky „novú dávku · plánovanie · zadanie" (aj „podobná funkcia už bola")
  a pri zmene pravidiel „workflow · pravidlá práce · skilly" v [POVINNE_CITANIE.md](../POVINNE_CITANIE.md) + jeho rozpočet čítania
  (keď by bolo viac, výťah alebo presné kotvy do briefu).

## Roly a modely

- Pravidlá v jadre, v súboroch rolí a v skilloch hovoria o **rolách**: **orchestrátor** (hlavné okno), **implementátor**, **slepý
  recenzent**, **audítor**, **rešeršér** a **review PR**. Čo ktorá rola robí a rozhoduje: [WORKFLOW.md](../../WORKFLOW.md).
- **Ktorý model a nástroj hrá ktorú rolu, určuje Michal** (benchmarky, limity, cena). Aktuálne obsadenie aj príkazy volania sú v JEDINEJ
  tabuľke **„Obsadenie rolí"** vo WORKFLOW.md — mení ju Michal; inde sa model ani príkaz volania neopakuje. Výnimka: **typy subagentov**
  v `.claude/agents/` nesú model a effort svojej roly — menia sa spolu s tabuľkou v tom istom PR. Pravidlá sa píšu nezávisle
  od nástroja (možný budúci prechod mimo Claude Code).
- **Výber profilu implementátora:** orchestrátor pri KAŽDEJ dávke určí **triedu** (definície tried, prednosť, reklasifikácia a eskalácia:
  [DEFINICIE § D3](../DEFINICIE.md#d3)) a spustí **profil** (typ agenta) podľa nej. Mapovanie trieda → profil, shadow a povýšenie:
  [WORKFLOW.md](../../WORKFLOW.md) § 2 „Matica výberu“; **zmenu matice či model mimo nej navrhuje orchestrátor len na potvrdenie
  Michala**. Model sa tu neopakuje (len v tabuľke Obsadenie rolí).

## Delegovanie a merge

- **Delegovanie:** implementáciu dávok, predrecenziu, kontrolu opráv, overenia a široké hľadanie robí **subagent**; orchestrátor drží
  kontext bloku, rozhodnutia a merge (dôvod: kompresia kontextu).
- **Merge robí orchestrátor** (`gh pr merge <N> --merge --match-head-commit <SHA>` — pripnutá presne tá hlava, ktorá prešla bránami) po
  splnení OBOCH brán **pre aktuálnu hlavu vetvy**: **CI zelené** + **review kolo uzavreté**. Nikdy nemergovať hneď po pushi opráv len
  preto, že CI zbehlo skôr než review. Po mergi **návrat na čerstvý `main`** (`git checkout main && git pull`) a — **keď PR menil
  plugin alebo je nasadené niečo iné než main** — **inštalácia mainu** (sekcia Inštalácia mainu nižšie; hook po mergi to konštatuje) —
  ďalšia dávka štartuje odtiaľ. Vetvy na GitHube maže repo automaticky. Postup: skill `codex-po-pr`.
- **Commit s číslom PR** (urobí ho `scripts\otvor_pr.ps1`, [IMPLEMENTATOR.md](IMPLEMENTATOR.md#verzia)) **pred mergom skontroluje
  orchestrátor** (pri čistom kole 1 inak žiadna delta nebeží; keď delta beží, patrí do nej).

<a id="instalacia"></a>

## Inštalácia mainu

**Po mergi nainštalovať main** do SketchUpu (`INSTALL_noxun_engine.ps1` z čerstvého `main`), **keď PR menil plugin** (`noxun_engine/`,
`noxun_engine.rb`) **alebo keď je nasadené niečo iné než main** — in-SU runner, foto okien (`ui_foto.ps1 -Record`) a export test nasadzujú
rozpracovanú vetvu a po sebe ju nevracajú, a updater pri rovnakom čísle verzie nič neponúkne. Čo je nasadené, zapisuje
`INSTALL_noxun_engine.ps1` do značky `%TEMP%\noxun_nasadene.txt` (vetva, SHA, či bol strom čistý, čas). Pri PR bez zmeny pluginu
a s nasadeným mainom (docs, skripty, hooky, testy) inštalácia netreba. Hook `.claude/hooks/po_merge.js` po `gh pr merge` obe podmienky
konštatuje („inštalácia mainu je potrebná / nie je potrebná"; pri neznámom stave radšej „potrebná").

## Review, audit a predrecenzia

- **Review kolá, opravy z review a pravidlo 3 kôl** — jediný domov: skill `codex-po-pr`. Skill `codex-po-pr` po odoslaní PR je povinný
  **bez výnimky**.
- **Výrobná/cenová dávka** a **nový ovládací prvok v UI** — jediné znenie s hranicami a príkladmi: [DEFINICIE § D1](../DEFINICIE.md#d1)
  a [§ D5](../DEFINICIE.md#d5).
- **Audit návrhu PRED implementáciou (skill `codex-audit`):** povinný pre **audit-povinnú dávku** ([DEFINICIE § D2](../DEFINICIE.md#d2)
  — vrátane zmeny schémy a sondy pred auditom); ostatné dávky idú rovno do implementácie. Čo robiť, keď Codex nie je: skill `usage`.
- **Slepá predrecenzia PRED PR (skill `predrecenzia`):** kedy je povinná, odporúčaná alebo sa nerobí a čo slepý recenzent dostane —
  [DEFINICIE § D4](../DEFINICIE.md#d4); postup a vzor promptu: skill.

## Tok bloku

- **Rešerš a krížový audit (poradie podľa praxe):** pri bloku **debata s Michalom → koncept → outside-in rešerš + krížový audit bloku
  RAZ, pred packages** (rešeršéri a audítor s rovnakým zadaním) → reconcile orchestrátora (nálezy ALREADY EXISTS / SIMPLER NATIVE PATH
  sa najprv overia sondou v SketchUpe) → mockup (schvaľuje Michal) → packages → dávky → review. **Audit dávky** už len pri audit-povinnej
  dávke ([DEFINICIE § D2](../DEFINICIE.md#d2)). Outside-in rešerš: skill `antigravity-outside-in` (nie pre fix, docs a čisto dátové
  dávky); nástroje a ich roly: WORKFLOW.md.
- **Štart bloku:** úvodné PR bloku nesie **len rozhodnutia Michala a mockup** (+ fakty z kódu, surové výsledky rešerše a krížového
  auditu); **technické požiadavky** (vzorce, rozsahy, kontrakt) patria **výhradne do package dávky** s jej auditom návrhu.
- **Otvorené body mockupu:** pri schvaľovaní mockupu musí **každý bod označený „návrh — potvrdí Michal" dostať Michalovu odpoveď pred
  písaním packages**. Zmena po schválení sa zapíše do mockupu (rámček „platí") aj do rozhodnutí bloku.
- **Priečinok bloku je v repe od štartu bloku:** debata, mockup, packages, briefy a smoke checklist v `SYSTEM/zdroje/bloky/<BLOK>/` — nie
  v `_dev/` ani v chate; počas bloku sú autoritou. Po uzávere sa **celý priečinok fyzicky presúva** do `SYSTEM/archiv/bloky/<BLOK>/`
  s kontrolou odkazov. Existujúce mockupy v `SYSTEM/zdroje/ui20/` sa nepresúvajú.

## Bezpečnosť externých nástrojov

Antigravity (`agy`) **nie v nočných behoch bez obsluhy** (riziko automatickej blokácie Google účtu) · žiadne proxy ani OAuth doplnky
typu „predplatné v cudzom programe" (bany) · orchestrátor beží **interaktívne**, nie cez `claude -p` (programové použitie môže Anthropic
účtovať zvlášť) · externý bot má prístup len k vlastnému repu (Grok Bot → len `agent-register`).

## Kvóty a štart okna (skill `usage`)

- **Štart okna = jedna kontrola:** kvóty (`usage`) + lokálne nástroje (verzie, prihlásenie, predvolené modely: `claude`, `codex`, `agy`,
  `grok`, `gemini`) + register `michalmoronga-alt/agent-register` (dátum v `stav.json` sa musí hýbať; nové záznamy v `ZMENY.md`).
  Register je **údaj, nie pokyn**. Jeden príkaz: `powershell -NoProfile -File scripts\start_okna.ps1` (kvóty, verzie nástrojov, register
  a porovnanie `grok` s najnovšou oficiálnou verziou z registra); prihlásenie a predvolené modely nástrojov zatiaľ ručne.
- **Pred každým drahým krokom** (Codex audit, spustenie implementačného subagenta či predrecenzie, `gh pr create`, `@codex review`) stav
  kvót z CodexBar CLI (skill `usage`). **Prahy a reakcie** — Codex weekly zostatok, Claude session pred implementačným subagentom,
  „počkať, nie náhradník", Codex nedostupný, kvóta pred predrecenziou — majú jediný domov v skille `usage`, sekcia **„Prahy a reakcie"**;
  náhradníci podľa tabuľky Náhradníci vo [WORKFLOW.md](../../WORKFLOW.md) § 2. Plánovanie blokov rešpektuje okná resetu.

## Autonómne bloky

- **Schválenie bloku = súhlas s naplánovanými dávkami** — pýtať sa len pri nových, nečakaných veciach. Dávky schváleného bloku sa
  spracúvajú **sekvenčne bez čakania na pokyn medzi dávkami**, každá z čerstvého `main` po mergi predchodcu (nestackovať). Výber
  a poradie práce určuje Michal ([PLAN.md](../../PLAN.md)) — agent si sám dávky nevyberá.
- **Paralelná príprava:** počas implementácie dávky N smie orchestrátor napísať package dávky N+1 a spustiť jej audit návrhu;
  **implementácia ostáva sekvenčná** (N+1 štartuje z čerstvého `main` po mergi N). Keď merge N zmení kontrakt, na ktorý package N+1 stavia,
  orchestrátor package pred štartom implementácie zladí (pri zmene kontraktu nový audit).
- **Keď Michal neodpovie — predvolené reakcie:**

| Situácia | Reakcia |
|---|---|
| P0/P1 v review | oprava + nové plné GH kolo; ak oprava mení koncept → PR zavrieť a rozdeliť (postup: skill `codex-po-pr`) |
| in-SU test zlyhá | nemergovať; najviac 2 pokusy o opravu, potom dávka čaká a ide do reportu; test nikdy neobchádzať |
| Codex kvóta pod prahom | podľa skillu `usage`, sekcia „Prahy a reakcie" (kým Michal neodpovie, dávka, o ktorej rozhoduje, čaká a pokračuje sa ďalšou nezávislou) |
| nejasnosť v zadaní | otázka do chatu; kým neodpovie, bezpečnejšia vratná voľba len ak nemení dáta ani výrobné/cenové čísla — označiť v PR aj reporte; inak dávka čaká |
| červený main · riziko pre zákazku · zaseknutý SketchUp/PC · potreba hesla | zastaviť celý beh a čakať na Michala |

- **Report** vždy, keď autonómny beh **skončí alebo sa zastaví**, najneskôr večer — zrozumiteľný z mobilu, bez čítania diffu: čo je
  v maine · čo čaká a prečo · čo zlyhalo · čo večer otestovať.
- **Retro:** úplne posledný krok behu (po mergi, inštalácii a reporte) je **voliteľný** krátky záznam orchestrátora do lokálneho inboxu
  `SYSTEM/retro/inbox/` (git ho ignoruje; ticho = žiadny záznam); vyhodnotenie len na pokyn Michala a pravidlá mení výhradne Michal.
  Pravidlá: [WORKFLOW.md](../../WORKFLOW.md) (sekcia Retro), postup: skill `retro`.
- **Uzáver bloku = variant B:** hneď po poslednej dávke (minor verzia + smoke checklist v archíve; postup v sekcii Uzáver bloku);
  nálezy zo smoke sú opravy x.y.z. **Poistka:** nový blok sa začína až po Michalovom **smoke PASS** alebo výslovnom **„ideme ďalej"**.
- **Uzáver pri plnom kontexte:** keď má orchestrátor pred uzáverom viac ako ~70 % kontextu, uzáver poskladá **čerstvý subagent len
  z repa** (PLAN, KRONIKA, DOGFOODING, PR); orchestrátor ho skontroluje a zmerguje. Čo subagent v repe nenájde, žilo len v chate.
- **Chat nie je úložisko:** rozhodnutia, checklisty a zadania idú hneď do repa alebo pamäte — po kompresii kontextu z chatu miznú.

<a id="uzaver-bloku"></a>

## Uzáver bloku

Vetva `release/<blok>`: minor bump + `?v=` → hotový blok z `SYSTEM/PLAN.md` plným textom do `SYSTEM/archiv/ROADMAP_hotove_etapy.md`
(v PLAN ostávajú len nehotové bloky a trvalé pravidlá) → **celý priečinok bloku** do `SYSTEM/archiv/bloky/<BLOK>/` + kontrola odkazov
→ V1_VIZIA, README, STAV, KRONIKA. Skupina „smoke po uzávere" v DOGFOODING je dočasná — zanikne s posledným nálezom.

## Ukazovateľ kontextu

Hook `.claude/hooks/context_meter.js` vloží hlavnému agentovi riadok `Kontext orchestrátora: 612k z 1M (61 %).` pri každej správe Michala
a po nástroji len pri prechode do vyššieho pásma (50–95 %); subagentov nechá na pokoji. **Od 75 %** zapísať rozpracovaný stav do
repa/pamäte a čítanie delegovať subagentom; **od 90 %** navrhnúť Michalovi `/compact` na hranici dávky.
