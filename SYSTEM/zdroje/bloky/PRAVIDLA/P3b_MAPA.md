# P3b — mapa presunu (blok PRAVIDLA, 26.10.2026)

> Každá veta odstránená z `SYSTEM/pravidla/roly/ORCHESTRATOR.md` (**OR**), `SYSTEM/WORKFLOW.md` (**WF**), skillu `antigravity-outside-in`
> (**AOI**) a obalu `agy-reserser` (**OBAL**, zdroj `SYSTEM/pravidla/typy/agy-reserser.md`) a jej nový domov. Skilly: **US** = `uzaver-bloku`,
> **SM** = `smoke`, **UQ** = `usage`; **HK** = `docs/HOOKY.md`. Zadanie: [PACKAGE_P3b.md](PACKAGE_P3b.md).

## A · ORCHESTRATOR.md

| Pôvodná veta / sekcia (OR) | Nový domov |
|---|---|
| sekcia **Uzáver bloku**: vetva `release/<blok>`, minor bump + `?v=`, hotový blok z PLAN plným textom do `ROADMAP_hotove_etapy.md`, celý priečinok bloku do `archiv/bloky/<BLOK>/` + kontrola odkazov, V1_VIZIA, README, STAV, KRONIKA | US, Postup, kroky 1–3 a 6 |
| „Skupina „smoke po uzávere" v DOGFOODING je dočasná — zanikne s posledným nálezom" | US krok 6 · SM (Nálezy a ukončenie) |
| Autonómne bloky: „Uzáver bloku = variant B: hneď po poslednej dávke (minor verzia + smoke checklist v archíve; postup v sekcii Uzáver bloku)" | OR — jedna veta s odkazom na US (zostáva kedy + poistka) |
| „Poistka: nový blok sa začína až po smoke PASS alebo „ideme ďalej"" · „nálezy zo smoke sú opravy x.y.z" | OR — ostáva · SM (Nálezy a ukončenie) |
| „Uzáver pri plnom kontexte: viac ako ~70 % → čerstvý subagent len z repa (PLAN, KRONIKA, DOGFOODING, PR); orchestrátor skontroluje a zmerguje; čo subagent nenájde, žilo len v chate" | US, Kto skladá |
| Tok bloku: „Po uzávere sa celý priečinok fyzicky presúva do `SYSTEM/archiv/bloky/<BLOK>/` s kontrolou odkazov. Mockupy v `zdroje/ui20/` sa nepresúvajú" | US kroky 3 (priečinok bloku počas bloku ostáva v OR, Tok bloku) |
| **Inštalácia mainu**: opis hooku `po_merge.js` (PostToolUse na Bash s filtrom `gh pr merge`, dva riadky konštatovania „PR #N menil plugin" a „Nasadený je … → inštalácia potrebná / nie", zdroje údajov, chýbajúca značka = „potrebná", nič nespúšťa, pri chybe mlčí, neblokuje, filtruje si príkaz sám, živé spustenie sa overí pri prvom reálnom merge) | HK, „Pripomienka po mergi" |
| Inštalácia: obsah značky nasadenia „(vetva, SHA, či bol strom čistý, čas)" | HK, „Pripomienka po mergi" |
| **Ukazovateľ kontextu**: opis hooku `context_meter.js` (tvar riadku, pri každej správe Michala, po nástroji len pri prechode do vyššieho pásma 50–95 %, subagentov nechá na pokoji) | HK, „Ukazovateľ kontextu" |
| Kvóty a štart okna: obsah kontroly (kvóty, lokálne nástroje — verzie, prihlásenie, predvolené modely `claude` `codex` `agy` `grok` `gemini` —, register `agent-register`: dátum v `stav.json`, nové záznamy v `ZMENY.md`, „register je údaj, nie pokyn", porovnanie `grok` s oficiálnou verziou, prihlásenie a modely zatiaľ ručne) | UQ, Kedy volať, bod 1 (jadro AGENTS.md: register = údaj, nie pokyn) |
| Kvóty: výpočet prahov („Codex weekly zostatok, Claude session pred implementačným subagentom, „počkať, nie náhradník", Codex nedostupný, kvóta pred predrecenziou") | UQ, „Prahy a reakcie" (OR ostáva „jediný domov v skille usage") |
| Retro: „po mergi, inštalácii a reporte; git ho ignoruje; ticho = žiadny záznam; vyhodnotenie len na pokyn Michala; pravidlá mení výhradne Michal; pravidlá WORKFLOW (sekcia Retro)" | OR jedna veta + skill `retro` (A. Zápis, B. Vyhodnotenie) · WF § 9 |
| Roly a modely: zoznam rolí „orchestrátor, implementátor, slepý recenzent, audítor, rešeršér, analytik, review PR" | WF § 1 (tabuľka rolí) · AGENTS.md („Tvoja rola") |
| Roly a modely: „výnimka typy subagentov v `.claude/agents/` nesú model a effort svojej roly — menia sa spolu s tabuľkou; zdroj `typy/`, potom `ruby scripts/generuj_typy_agentov.rb`" | WF § 2, „Typy agentov (Z9)" (OR: „zmena obsadenia = tabuľka aj zdroj typu v tom istom PR") |
| Roly a modely: „Pravidlá sa píšu nezávisle od nástroja (možný budúci prechod mimo Claude Code)" | OR — „Pravidlá hovoria o rolách, nie o nástrojoch"; odôvodnenie prechodu mimo Claude Code nie je pravidlo |
| Výber profilu: „(definície tried, prednosť, reklasifikácia a eskalácia: D3)" · „Model sa tu neopakuje" | DEFINICIE § D3 · WF § 2 (Matica výberu) |
| Delegovanie a merge: „(sekcia Inštalácia mainu nižšie; hook po mergi to konštatuje)" · podmienka „keď PR menil plugin alebo je nasadené niečo iné než main" | OR, Inštalácia mainu (podmienka je tam celá) |
| Review/audit: „povinný pre audit-povinnú dávku (vrátane zmeny schémy a sondy pred auditom); ostatné dávky idú rovno do implementácie" · „postup a vzor promptu: skill" · samostatný odrážok D1/D5 | OR — zlúčené do dvoch odrážok s odkazmi na D2, D4, D1, D5 (znenie je v DEFINICIE) |
| Tok bloku: „Audit dávky už len pri audit-povinnej dávke (D2)" · „nástroje a ich roly: WORKFLOW.md" | OR, Review, audit a predrecenzia (D2) · WF § 1 |
| Tok bloku: „Otvorené body mockupu — pri schvaľovaní mockupu musí každý bod … dostať odpoveď pred písaním packages" | OR — ostáva (skrátené, význam rovnaký) |
| Kvóty: „stav kvót z CodexBar CLI" | OR — „stav kvót (skill `usage`)" |
| Paralelná príprava (slová „napísať", „štartuje", „orchestrátor package … zladí") | OR — ostáva, prepísané kratšie |

## B · WORKFLOW.md (§ 3–§ 8, § 10; § 2 a § 9 bez zmeny)

| Pôvodná veta / odsek (WF) | Nový domov |
|---|---|
| § 3 pod diagramom: „Schválenie bloku = súhlas s naplánovanými dávkami — autonómny beh sa pýta len pri nových veciach; predvolené reakcie sú v ORCHESTRATOR.md" | OR, Autonómne bloky (WF len odkaz) |
| § 3: „Rešerš a krížový audit bloku beží raz, pred packages: rešeršéri a audítor … reconcile orchestrátor; audit dávky už len pri zmene kontraktu" | OR, Tok bloku · DEFINICIE § D2 (vzor S1_CROSS_AUDIT ostáva v odkaze) |
| § 3: „Priečinok bloku … drží od štartu debatu, mockup, packages, briefy a smoke checklist … pri uzávere sa presúva do `archiv/bloky/<BLOK>/` s kontrolou odkazov (mockupy v `zdroje/ui20/` sa nepresúvajú)" | OR, Tok bloku · US krok 3 |
| § 3: „Uzáver ide hneď po poslednej dávke (variant B); ďalší blok až po smoke PASS alebo „ideme ďalej"" | WF — ostáva (skrátené) · OR, Autonómne bloky · US |
| § 3: odsek „Od 27.9.2026 (retro bloku 7 …)": body mockupu „návrh — potvrdí Michal", úvodné PR bloku, paralelná príprava N+1 | OR, Tok bloku a Autonómne bloky (pravidlá); dátum a pôvod → archív retro `VYHODNOTENIE_2026-09-27_blok7.md` |
| § 3 diagram: nadpis Uzáver bloku, uzol Uzáver (smoke checklist, upratanie), uzol Smoke | WF — doplnené odkazy na US a SM (diagram ostáva) |
| § 4: „Sonda pred auditom — audit má chytať chyby návrhu, nie tvrdenia z úvahy" | DEFINICIE § D2 · skill `codex-audit` krok 0 |
| § 4: „Paralelná príprava: package a audit návrhu N+1 smú bežať počas implementácie N; mapa sa pre N+1 začína až po mergi N …" | OR, Autonómne bloky |
| § 4: „In-SU na finálnej hlave" | DEFINICIE § D6 · IMPLEMENTATOR (Testovanie) — WF má len odkaz |
| § 4: „Kvóta Codexu (`-Gate codex`) … dlhý blok môže medzitým kvótu minúť" | UQ, Kedy volať (body 2 a 3) |
| § 4: „PR otvára implementátor … subagent ďalších subagentov nespúšťa …" | IMPLEMENTATOR, Karta roly (Nesmie) a Postup, krok 7 |
| § 4: „Číslo PR je všade, kde ho dávka píše … `PR #?` … `scripts\otvor_pr.ps1` … pred mergom skontroluje orchestrátor (pri čistom kole 1 inak žiadna delta nebeží)" | IMPLEMENTATOR, Verzia a uzáver dávky (Číslo PR) · OR, Delegovanie a merge (commit s číslom PR) |
| § 4: „Dokumentačné PR: Verzia, `?v=` ani predrecenzia sa pri nich nerobia (výnimka: dávka náhradného implementátora …); STAV len vtedy, keď PR mení stav bloku, smoke alebo poradie prác — faktický stav v „Stav", prepíše „Robí sa" a „Ďalší krok"" | IMPLEMENTATOR, Verzia (checklist dokumentačného PR) · DEFINICIE § D4 · hlavička „Údržba" v STAV.md; tok dokumentačného PR (vetva → KRONIKA → testy → kvóta → PR → číslo → review → merge) ostáva ako mapa |
| § 5: „trieda D: P2/P3 opraví implementátor a kontrolu opravy urobí orchestrátor sám …" | DEFINICIE § D3 (trieda D) |
| § 6: bunka „docs a verzia na mieste" (rozpis STAV pri dokumentačnom PR) | IMPLEMENTATOR (Verzia) · STAV.md „Údržba"; stĺpec „Kde" doplnený o `.claude/rules/ui.md` (cache-bust) |
| § 6: stĺpec „Kde je pravidlo" — nové/opravené domovy | testovať len v ENGINEtests → AGENTS.md (Zákazy); in-SU → + `.claude/rules/konstrukcia.md`; **nový riadok** export test → `.claude/rules/vystupy.md`, NASTROJE_TESTOV; **nový riadok** uzáver bloku → US; smoke PASS → + SM |
| § 8: „Chat nie je úložisko (Z2)" a „Delegovanie (Z3)" — opis | OR, Autonómne bloky a Delegovanie a merge |
| § 8: „Ukazovateľ kontextu (Z7, hook z PR #392; … od 75 % … od 90 % …)" | OR, Ukazovateľ kontextu (prahy) · HK (hook) |
| § 8: „Uzáver bloku pri viac ako ~70 % skladá čerstvý subagent len z repa …" | US, Kto skladá |
| § 8: „Pred kompresiou zapísať do handoffu označenie implementátora rozrobenej dávky (Z4)" | **ostáva vo WF** — jediný domov (odchýlka 2) |
| § 10: „Grok ako implementátor — … od 6.10.2026 … schválil Michal 7.10.2026" (dátumy) | WF § 2 (Matica výberu) · história → KRONIKA |
| § 10: „Spoločné pravidlá v `AGENTS.md` … hotové v bloku PRAVIDLA (dávka P1b)" | história → KRONIKA (P1b); AGENTS.md sa opisuje sám |
| Hlavička „Údržba": zoznam miest, kde žije pravidlo | WF — doplnený súbor oblasti `.claude/rules/` |

## C · Skill `antigravity-outside-in`

| Pôvodná veta (AOI) | Nový domov |
|---|---|
| krok 1: doslovný blok OBMEDZENIE NÁSTROJOV (v kódovom bloku) | `scripts/agy/obmedzenie.txt` (jediný domov); krok 1 hovorí, že blok sa do promptu nepíše, príkaz behu ho pridá sám |
| krok 1: „Vzor: `scratchpad/ag_outside_in_kovcd.md` z 3.9. (pilot KOV-C/D) a `ag_outside_in_sweep.md` (jednorazový sweep architektúry)" | história → KRONIKA (súbory boli v scratchpade jednej session) |
| krok 2: príkaz behu používal premennú `OBM` bez definície | príkaz teraz načíta `OBM="$(tr -d '\r' < "$S/obmedzenie.txt")"` (CR z checkoutu s CRLF) a pri chýbajúcom alebo prázdnom súbore sa nespustí (`exit=setup-fail`) |
| „Čo rieši (Michal 3.9.2026)" | história → KRONIKA; v skille „Čo rieši" bez dátumu |
| „Miesto v poradí (rozhodnutie N14, 26.9.2026)" | história → KRONIKA; v skille „rozhodnutie N14" |
| „rozhodnutie Z8, 26.9.2026" | história → KRONIKA; v skille „rozhodnutie Z8" |
| krok 5 Ekonomika: „pilot 3.9.: dva behy ≈ 2,2 % 5-hodinového limitu" · „3.9.: dva paralelné Codex audity ho vyčerpali" | história → KRONIKA; v skille „dva behy ≈ 2 % limitu", „dva paralelné audity ho vyčerpajú" |
| krok 6 „Kusovanie (Michal 3.9.)" | história → KRONIKA; v skille „Kusovanie" |
| Pasce: „(overené 22.–23.10.2026, agy 1.4.5)" | história → KRONIKA |
| Pasce, lieky: „(2) blok OBMEDZENIE NÁSTROJOV na začiatku promptu" | ostáva, doplnená cesta `scripts/agy/obmedzenie.txt` |
| Pasce o prázdnom výstupe (vysvetlenie, lieky, platné akcie, chyba #640) | **ostáva v skille** — jediný domov diagnostiky |

## D · Obal `agy-reserser` (zdroj `typy/agy-reserser.md`, typ pregenerovaný)

| Pôvodná veta (OBAL) | Nový domov |
|---|---|
| krok 3: `OBM='OBMEDZENIE NÁSTROJOV: …'` (doslovný text) | `scripts/agy/obmedzenie.txt`; príkaz: `OBM="$(tr -d '\r' < "$S/obmedzenie.txt")"`, pri chýbajúcom alebo prázdnom súbore `SETUP-ZLYHAL` (agy sa nespustí) |
| Pasce: „Hláška „a tool required the "command" / "read_file" permission" … alebo prázdny packet = stráž chýba v priečinku behu … alebo sa nenačítala — nahlás, nič nemeň (config je zdieľaný s IDE)" | AOI, Pasce (Prázdny výstup s exit 0) — obal ponecháva odrážku s odkazom a „nahlás, nič nemeň" |
| krok 4 (meranie packetu, čo vrátiť, `len_web.log`, #640) | **ostáva v obale** — vykonateľný krok |

## E · Ostatné súbory

| Zmena | Dôvod |
|---|---|
| `IMPLEMENTATOR.md` § Verzia: „([ORCHESTRATOR.md, Uzáver bloku](ORCHESTRATOR.md#uzaver-bloku))" → „(skill `uzaver-bloku`)" | kotva v OR zanikla; kratší odkaz drží IMPLEMENTATOR pod 8 kB (8170 → 8126 B) |
| `docs/HOOKY.md`: sekcia „Hooky hlavného okna" má opis `po_merge.js` a `context_meter.js` | domov pre presunuté opisy (HK) |
| `usage` skill, Kedy volať, bod 1: obsah kontroly štartu okna | domov pre presunutý obsah (UQ); odkaz na ORCHESTRATOR.md zrušený |
| `SYSTEM/README.md`: riadok `pravidla/roly/` — uzáver bloku → poistka + skilly | odkaz na nový domov |
| `tests/pure/test_pravidla_velkost.rb`: roly 8 kB (ORCHESTRATOR vlastný riadok 10 kB), `.claude/skills/*/SKILL.md` ≤ 500 riadkov, G2 pre tri skilly | package § 2 bod 1–2 |
| `tests/pure/test_agy_obmedzenie.rb`: stráž jedného domova bloku a čítanie zo súboru | package § 2 bod 3 |

## F · Odchýlky od package

1. **ORCHESTRATOR.md má 9938 B, nie ≤ 8 kB — platí vlastný strop 10 kB** (package § 1 bod 3). Do 8192 B by sa muselo vypustiť ≈ 1,7 kB; všetky zvyšné
   sekcie nesú pravidlo, ktoré nemá iný domov: Karta roly — „Režimy" (záložný režim) 380 B + „Dostane automaticky" 299 B + „Povinné čítanie" 348 B
   (spolu 1027 B) · Bezpečnosť externých nástrojov 439 B · Inštalácia mainu (odôvodnenie podmienok) 660 B · tabuľka „Keď Michal neodpovie" ≈ 1,5 kB.
   Ostatné roly sú pod 8 kB. Výnimku z 8 kB predkladá orchestrátor Michalovi.
2. **WF § 8 „Pred kompresiou zapísať do handoffu označenie implementátora rozrobenej dávky (Z4)" ostáva vo WORKFLOW.md** — v žiadnej roli ani skille toto pravidlo
   nie je; presun do ORCHESTRATOR.md by pridal ≈ 150 B (strop 10 kB to unesie), rozhodnutie nechávam na Michala / P5.
3. **AOI krok 1 a 2 boli vnútorne nezhodné** (blok sa mal písať do súboru s promptom, ale príkaz ho prefixoval znova cez `$OBM`); po zmene sa blok do súboru
   promptu nepíše vôbec (rovnako ako v obale).
4. **Podmienka stráže OBM:** test hľadá doslovný text vetou (`OBMEDZENIE NÁSTROJOV:` + `nepoužívaj` …), nie samotnú frázu s dvojbodkou — `PACKAGE_P3b.md`
   a táto mapa ju spomínajú bez doslovného textu bloku; test nescanuje `.claude/worktrees/` (cudzie checkouty v hlavnom checkoute).
5. **Smoke SM a mapa uzáveru US:** nové skilly nepridávajú pravidlá mimo § 1 package; kroky „zostavenie smoke checklistu" a „upratanie" sú jediné nové, formát bodov
   checklistu (skupiny A, B, C … s ID, značky `[model]` a `[záloha]`) je prevzatý z reálneho checklistu bloku HARDENING.
6. **Zdroje histórie z AOI** (dátumy, čísla verzií, výsledky pilotu) sú zapísané v KRONIKE, odsek P3b.
7. **Opravy z predrecenzie:** SM — body overiteľné agentom zadáva orchestrátor subagentovi (nie robí sám, OR Delegovanie); US — uzáver je dávka triedy Ľ
   (dokumentácia a verzia, bez predrecenzie podľa D4) a po mergi sa inštaluje main; US Upratanie — smoke modely sa nenavrhujú nikdy; SM úvod — testovací model
   v `_dev`, nie zákazka; OBM sa číta cez `tr -d '\r'` (checkout s CRLF); OR Retro dostalo „(pravidlá: WORKFLOW § 9)" (9938 B, strop 10240).

## G · Veľkosti (bajty bez CR)

| Súbor | Pred | Po | Strop |
|---|---|---|---|
| `SYSTEM/pravidla/roly/ORCHESTRATOR.md` | 13902 | 9938 | 10240 (vlastný riadok, odchýlka 1) |
| `SYSTEM/pravidla/roly/IMPLEMENTATOR.md` | 8170 | 8126 | 8192 |
| `SYSTEM/WORKFLOW.md` | 36692 | 34179 | — |
| `.claude/skills/uzaver-bloku/SKILL.md` | — | 4042 (47 r) | 500 riadkov |
| `.claude/skills/smoke/SKILL.md` | — | 4485 (52 r) | 500 riadkov |
| `.claude/skills/antigravity-outside-in/SKILL.md` | 9010 | 8753 | 500 riadkov |
| `SYSTEM/pravidla/typy/agy-reserser.md` (telo obalu) | 5083 | 4776 | — |
| `.claude/agents/agy-reserser.md` (vygenerovaný typ) | — | 4956 | — |
| `docs/HOOKY.md` | 1166 | 2313 | — |
| `scripts/agy/obmedzenie.txt` | — | 286 | — |
