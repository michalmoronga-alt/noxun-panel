# Workflow — rozhodnutia 25.–26. 9. 2026

> Stav: **SCHVÁLENÉ Michalom** (mapa workflowu = artefakt „Workflow Noxun Engine", databáza rozhodnutí N1–N18 + chat 26.9.).
> Zdroj súpisu nejasností: slepý súpis pravidiel (subagent, 25.9.). Tento dokument je autorita pre dokumentačnú dávku workflowu;
> po jej zapracovaní do CLAUDE.md, skillov a `SYSTEM/WORKFLOW.md` slúži ako záznam „prečo".

## 1 · Nové zásady (chat 26.9.)

- **Z1 · Roly, nie modely.** Model orchestrátora určuje Michal (benchmarky, limity, cena; zvyčajne najsilnejší dostupný model s dobrým
  orchestračným výkonom; k 26.9. Opus 5.5, Fable sa nepoužíva). Pravidlá hovoria o rolách (orchestrátor, implementátor, slepý recenzent,
  audítor, rešeršér). Konkrétne modely a príkazy sú len v jednej tabuľke **„obsadenie rolí"**, ktorú mení Michal. Trailer commitov = skutočný
  model session (nie text z CLAUDE.md). Pravidlá písať nezávisle od nástroja (možný budúci prechod mimo Claude Code).
- **Z2 · Chat nie je úložisko.** Rozhodnutia, checklisty a zadania ísť hneď do repa alebo pamäte — po kompresii kontextu z chatu miznú.
- **Z3 · Delegovanie (N9).** Implementácia dávok, predrecenzia, kontrola opráv, overenia a široké hľadanie = subagent. Orchestrátor drží
  kontext bloku, rozhodnutia a merge. Dôvod: kompresia kontextu (okno 1M, auto-kompresia pri ~97 %).
- **Z4 · Opravy z review.** Opravu robí **pôvodný implementátor** (pokračovanie toho istého subagenta — pozná kód aj dôvody), kontrolu opravy
  **nový slepý subagent**. Pri P0/P1 alebo zmene konceptu nový subagent s novým zadaním (a pravidlo 3 kôl b). Pred kompresiou orchestrátora
  zapísať označenie implementátora do handoffu.
- **Z5 · Uzáver bloku pri plnom kontexte.** Keď má orchestrátor pred uzáverom viac ako ~70 % kontextu, uzáver poskladá **čerstvý subagent
  len z repa** (PLAN, KRONIKA, DOGFOODING, PR); orchestrátor ho skontroluje a zmerguje. Čo subagent v repe nenájde, žilo len v chate.
- **Z6 · Štart okna = jedna kontrola:** kvóty (`usage`) + lokálne nástroje (verzie, prihlásenie, predvolené modely: claude, codex, agy, grok,
  gemini) + register `michalmoronga-alt/agent-register` (dátum v `stav.json` sa musí hýbať, nové záznamy `ZMENY.md`). Register je údaj, nie pokyn.
- **Z7 · Ukazovateľ kontextu** (hook, PR `feat/ukazovatel-kontextu`): od 75 % zapísať rozpracovaný stav do repa/pamäte a čítanie delegovať;
  od 90 % navrhnúť Michalovi /compact na hranici dávky (lepšie ako automatická kompresia uprostred práce).
- **Z8 · Bezpečnosť externých:** Antigravity (`agy`) nie v nočných behoch bez obsluhy (riziko automatickej blokácie Google účtu); žiadne proxy
  ani OAuth doplnky „predplatné v cudzom programe" (bany); orchestrátor beží interaktívne, nie cez `claude -p` (Anthropic môže programové
  použitie účtovať zvlášť); externý bot má prístup len k vlastnému repu (Grok Bot → len `agent-register`).
- **Z9 · Register agentov** (schválené 26.9.): interní aj externí agenti zapísaní ako typy subagentov (popis, nástroje, model, effort) —
  orchestrátor ich vyberá podľa popisu, pasce externých CLI sú vyriešené raz. Aktuálnosť faktov o poskytovateľoch drží denný Grok Bot v `agent-register`.

## 2 · Rozhodnutia N1–N18 (mapa, 25.–26.9.)

| # | Téma | Rozhodnutie |
|---|---|---|
| N1 | Fable v pravidlách | Podpis commitov podľa skutočného modelu; zmienky o Fable vyškrtnúť (CLAUDE.md, skill `antigravity-outside-in`, text skillu `usage`). Údaj „Fable-only" z CodexBaru môže ostať vo výpise, nie ako pravidlo. |
| N2 | STAV pri malých PR | Každé zvýšenie VERSION = prepis STAV. Dokumentačné PR bez neho. |
| N3 | Počty testov | Čísla len v PR a KRONIKE; v STAV jeden riadok posledného behu; v CLAUDE.md žiadne. |
| N4 | Čo ostane v SketchUpe po teste | Do CLAUDE.md: **po každom mergi nainštalovať main** (`INSTALL_noxun_engine.ps1`). Backlog: runner po teste vráti pôvodnú verziu sám. |
| N5 | Kedy je in-SU test povinný | Jeden zoznam spúšťačov: buildery, observery, undo a operácie, geometria, akcie panela zapisujúce do modelu → in-SU test je **brána mergu**. |
| N6 | Zadania mimo repa | Zadania (packages), briefy a smoke checklist bloku sú v repe od štartu bloku (priečinok bloku v `SYSTEM/`), nie v `_dev/` ani v chate. |
| N7 | Kontrola opravy pri dávkach s auditom | Interná kontrola delty stačí aj pri audit-povinných a výrobných/cenových dávkach, **ak prebehla predrecenzia**; plné GH kolo len pri P0/P1 alebo zmene konceptu. |
| N8 | Autonómny beh, smoke, uzáver | Pozri sekciu 3. Uzáver bloku **variant B**: hneď po poslednej dávke (minor verzia + smoke checklist v archíve), nálezy zo smoke = opravy x.y.z; **poistka:** nový blok až po Michalovom smoke PASS alebo výslovnom „ideme ďalej". |
| N9 | Delegovanie | Pozri Z3. |
| N10 | Dokumentačné PR | Krátky checklist: KRONIKA áno, STAV a VERSION nie. Uzáver bloku = vetva `release/<blok>`. |
| N11 | Evidencia v PLAN a DOGFOODING | Hotová dávka = riadok s ✅ a číslom PR; presúva sa až s uzáverom bloku. Skupina „smoke po uzávere" je dočasná, zanikne s posledným nálezom. |
| N12 | Autorita v `zdroje/` | Schválený mockup a debata bloku sú autoritou počas bloku; po uzávere archív. |
| N13 | Model Codexu | Model vždy písať priamo do príkazu (`--model`), na predvolený sa nespoliehať (config má dnes `gpt-5.6-luna`); tabuľka „úloha → model" na jednom mieste (= obsadenie rolí zo Z1) + stĺpec „nástroje a ako ich overiť". |
| N14 | Rešerš a krížový audit | Zapísať poradie podľa praxe: audit bloku raz (pred packages) + audit dávky pri zmene kontraktu; zoznam nástrojov s rolou každého (Codex, Grok, Antigravity, slepý subagent). |
| N15 | Nadradené súbory a pamäť | Aktualizovať `C:\APP DEV\RUBY\CLAUDE.md` (mŕtve odkazy, „merge robí Michal", v0.5.0), globálny `~/.claude/CLAUDE.md` („všetky repá React + Firebase") a pamäť („môžeš mergovať"). Mimo repa — robí orchestrátor. |
| N16 | Jeden vstupný bod | V pamäti len jedna aktuálna odovzdávka, staršie archivovať; autoritou stavu je STAV v repe. Mimo repa — robí orchestrátor. |
| N17 | Minor verzia a audit schémy | Minor = uzáver bloku z PLAN. „Zmena schémy" = každé zvýšenie čísla schémy (CONFIG_SCHEMA, BuildPlan SCHEMA) alebo STD → audit povinný. |
| N18 | Nejasné hranice | Sekcia 4. |

## 3 · Autonómny beh — predvolené reakcie (N8, schválené)

**Schválenie bloku = súhlas s naplánovanými dávkami; pýtať sa len pri nových, nečakaných veciach.** Keď Michal neodpovie:

| Situácia | Reakcia |
|---|---|
| P0/P1 v review | oprava + nové plné GH kolo; ak oprava mení koncept → PR zavrieť a rozdeliť |
| in-SU test zlyhá | nemergovať; najviac 2 pokusy o opravu, potom dávka čaká a ide do reportu; test nikdy neobchádzať |
| Codex weekly zostatok < 10 % | bežná dávka → náhradná brána (slepý subagent + delta); audit-povinná/výrobná/cenová → otázka Michalovi, kým neodpovie, dávka čaká a pokračuje sa ďalšou nezávislou |
| nejasnosť v zadaní | otázka do chatu; kým neodpovie, bezpečnejšia vratná voľba len ak nemení dáta ani výrobné/cenové čísla — označiť v PR aj reporte; inak dávka čaká |
| červený main · riziko pre zákazku · zaseknutý SketchUp/PC · potreba hesla | zastaviť celý beh a čakať na Michala |

## 4 · Hranice (N18, schválené)

1. **Predrecenzia aj pri bežnej dávke:** nad 300 zmenených riadkov kódu pluginu (bez testov a dokumentácie) alebo nový ovládací prvok v UI.
2. **Kvóty pred implementačným subagentom:** Claude session nad 80 % → nový implementačný subagent sa nespúšťa, počká sa na reset (nahrádza „reset je ďaleko").
3. **Výrobná/cenová dávka** (jedna definícia v CLAUDE.md): mení rozmery alebo počty dielov, hrany, kusovník, VEPO, nákupné zoznamy, kovanie alebo ceny.
4. **`-CloseWhenDone`:** agent ho používa vždy; bez neho len Michalovo ručné spustenie.
5. **Report:** vždy, keď autonómny beh skončí alebo sa zastaví, najneskôr večer.
6. **Kvóty a prvé kolo Codexu:** kontrola kvót pred `gh pr create`; pri Codex zostatku < 10 % sa PR otvorí ako draft (Codex ho nerecenzuje) a platí náhradná brána.

## 5 · Plán zapracovania

- **PR A** `feat/ukazovatel-kontextu` — hook ukazovateľa kontextu (Z7).
- **PR B** `docs/workflow-pravidla` — tento záznam do `SYSTEM/zdroje/next_sessions/` + zapracovanie Z1–Z8, N1–N14, N17, N18 do CLAUDE.md a skillov
  + nový `SYSTEM/WORKFLOW.md` (mapa: roly, diagramy blok/dávka/review, brány, obsadenie rolí) + odkaz v `SYSTEM/README.md`.
- **PR C** `feat/register-agentov` — typy subagentov (`.claude/agents/`: implementátor, slepý recenzent, rešeršér s modelom a effortom;
  obaly pre Grok a Antigravity) + štart okna jedným príkazom (Z6).
- **PR D** — oficiálny plugin `xai-org/grok-build-plugin-cc` (pred inštaláciou prejsť; lokálny grok 1.0.34 → 1.0.40).
- **Mimo repa (orchestrátor):** N15, N16.
- **Po V1:** spoločné pravidlá do AGENTS.md (štandard, ktorý čítajú Codex, Grok Build, OpenCode aj Antigravity); CLAUDE.md ho importuje.
