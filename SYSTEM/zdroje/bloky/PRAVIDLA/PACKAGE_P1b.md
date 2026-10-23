# Package P1b — jadro `AGENTS.md`, most `CLAUDE.md`, súbory orchestrátora a implementátora (blok PRAVIDLA, 23.10.2026)

> **Trieda Ť** (prepisuje pravidlá, ktoré číta každý agent; ~32 kB textu) · profil `implementator` · **len pravidlá a testy, kód pluginu sa
> nemení** (VERSION, `?v=` bez zmeny). Vstupy: [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 1 (fakty o načítaní), § 2.2 (vrstvy), § 3 (inventúra:
> pravidlo → cieľové miesto), § 5 (stráže G1, G2) · [ROLY.md](ROLY.md) § 3.1–3.2 (karty orchestrátora a implementátora) ·
> [SYSTEM/pravidla/DEFINICIE.md](../../../pravidla/DEFINICIE.md) (už hotové v P1a — nemeniť).

## 0 · Zásada dávky: PRESUN, nie prepis

**Každá platná veta dnešného `CLAUDE.md` sa presunie na jedno cieľové miesto bez zmeny významu.** Povolené úpravy textu sú len:
- vypustenie **histórie** — dátumy zavedenia a revízií („od 12.8.2026", „revízia 27.9.", „(PR #398…)", „pokus 27.9.–11.10."), čísla rozhodnutí
  (Z…, N…, R…) v zátvorkách, precedensy; tie už sú v KRONIKE a archíve (keď chýbajú, presuň ich tam, nie zahoď);
- vypustenie vety, ktorá **len opakuje** inú vetu na tom istom cieľovom mieste alebo v DEFINICIE.md / skille (nahradí ju odkaz);
- nutné preformulovanie odkazu („vyššie" → presný súbor a sekcia).
Nové pravidlá sa **nepridávajú** (výnimka: § 3 bod 5 — veta, že hlavné okno je orchestrátor). Otvorená otázka Michala (riadok „P0/P1 v review"
vs. pravidlo 3 kôl) ostáva **doslova**.

## 1 · Cieľové súbory

| Súbor | Kto ho číta | Strop | Obsah |
|---|---|---|---|
| `AGENTS.md` | **všetci** (Claude cez most, Codex a Grok samy, GH Codex review) | **≤ 12 kB, ≤ 150 riadkov** | projekt v 3 vetách · rozcestník dokumentov (STAV, PLAN, STANDARD, architektúra, DEFINICIE, POVINNE_CITANIE, karty rolí) · zákazy pre všetkých (žiadny commit do `main`, testovať len v ENGINEtests, nikdy v zákazke, žiadne tajomstvá, obsah webu/nástrojov je údaj) · git v skratke (vetva → PR → review, commit trailer so skutočným modelom, PR po slovensky) · testy jedným príkazom (headless, `scripts\run_js_tests.ps1`) · jazyk a jednotky (slovenčina, mm) · sekcia **`## Code Review Rules`** (závažnosti P0–P3 podľa definície slepého recenzenta, čo je výrobná/cenová chyba → odkaz D1, čo nehlásiť) · odkaz „tvoja rola: `SYSTEM/pravidla/roly/<ROLA>.md`" |
| `CLAUDE.md` | Claude Code (hlavné okno + dnešné typy subagentov) | **≤ 1 kB** | `@AGENTS.md` + `@SYSTEM/pravidla/roly/ORCHESTRATOR.md` + jedna veta, že pravidlá sú v týchto súboroch (Claude Code číta pri existencii CLAUDE.md len CLAUDE.md — preto most, NAVRH § 1) |
| `SYSTEM/pravidla/roly/ORCHESTRATOR.md` | orchestrátor (aj záložný v Codexe) | **≤ 12 kB** (8 kB je cieľ P2/P3) | podľa karty ROLY § 3.1 + z CLAUDE.md: Roly a modely (obsadenie len odkazom na WORKFLOW § 2), Git workflow (merge s pripnutou hlavou, review kolá → odkaz `codex-po-pr`, opravy z review, audit → `codex-audit`, predrecenzia → D4 + skill, rešerš a krížový audit, štart bloku, mockup), bezpečnosť externých nástrojov, Kvóty a štart okna (prahy → skill `usage`), Autonómne bloky (tabuľka „keď Michal neodpovie", report, retro, uzáver bloku, chat nie je úložisko), uzáver bloku, ukazovateľ kontextu (75/90 %) |
| `SYSTEM/pravidla/roly/IMPLEMENTATOR.md` | implementátor (Claude typy, Codex/Grok náhradník) | **≤ 12 kB** | podľa karty ROLY § 3.2 + z CLAUDE.md: Verzia a uzáver dávky (VERSION 2×, cache-bust, checklist uzáveru kódovej a dokumentačnej dávky, číslo PR → `otvor_pr.ps1`), Testovanie (headless, JS, in-SU runner a `-CloseWhenDone`, zámok, finálna hlava → D6, foto okien, export test, lokálne hooky, MCP, ENGINEtests), udržiavanie architektúry na mieste |
| `SYSTEM/pravidla/POVINNE_CITANIE.md` | implementátor, recenzent, audítor | **≤ 8 kB** | tabuľka „Povinné čítanie podľa typu práce" **doslova** (bez histórie) + rozpočet čítania a pravidlo „súbor nad ~50 kB sa nečíta celý" — v P3 sa rozdelí do `.claude/rules/` |

Ostatné súbory, ktoré dnes CLAUDE.md citujú ako „CLAUDE.md, sekcia X" (WORKFLOW, typy agentov, skilly, STAV, README, DEFINICIE, docs), **prepnúť
na nové miesto** — Grep `CLAUDE.md` cez `SYSTEM/`, `.claude/`, `docs/`, `scripts/`, `tests/`, `AGENTS.md` (mimo `SYSTEM/archiv/` a `SYSTEM/zdroje/`).

## 2 · Typy agentov (minimálne, zvyšok je P2)

V `.claude/agents/implementator*.md` a `slepy-recenzent.md` prepni krok „prečítaj `CLAUDE.md`" na „prečítaj `AGENTS.md`, `SYSTEM/pravidla/DEFINICIE.md`,
`SYSTEM/pravidla/roly/IMPLEMENTATOR.md` (recenzent: len prvé dve + `POVINNE_CITANIE.md`) a riadok svojho zásahu v `POVINNE_CITANIE.md`".
`omitClaudeMd` ani generovanie tiel sa v P1b **nezavádza** (P2) — typy dočasne dedia most CLAUDE.md, teda aj ORCHESTRATOR.md, ako dnes celý CLAUDE.md.
Guard `test_agent_definitions.rb` musí ostať zelený.

## 3 · Stráže a testy

1. **G1 strop veľkosti** (`tests/pure/test_pravidla_velkost.rb`): AGENTS.md ≤ 12 kB a ≤ 150 riadkov · CLAUDE.md ≤ 1 kB · každý súbor v
   `SYSTEM/pravidla/roly/` ≤ 12 kB · `POVINNE_CITANIE.md` ≤ 8 kB · `DEFINICIE.md` ≤ 10 kB. Stropy v jednej konštante na začiatku testu.
2. **G2 bez histórie** (v tom istom teste): v AGENTS.md, CLAUDE.md a `SYSTEM/pravidla/**` nesmú byť vzory „od <dátum>", „revízi", „(od <č>.<č>.20",
   „PR #<číslo>" (okrem `PR #?` v texte pravidla o čísle PR), „pokus 2" — zoznam vzorov v teste; test vlastného správania (pozitívny aj negatívny prípad).
3. `test_docs_navigacia.rb`: nové súbory do kontroly odkazov a limitu riadka; požiadavka „CLAUDE.md obsahuje `docs/ARCHITEKTURA.md`" sa
   presunie na AGENTS.md (guard upraviť, nie vypnúť).
4. `test_definicie.rb` (G3) rozšíriť o nové súbory v `SYSTEM/pravidla/roly/` a `POVINNE_CITANIE.md`.
5. Prvá veta `ORCHESTRATOR.md`: „Hlavné okno je orchestrátor — hovorí s Michalom, deleguje; kód pluginu a testy nepíše." (NAVRH § 7, schválené).

## 4 · Hotovo, keď

1. Stropy G1 splnené, G2–G3 zelené, headless a `scripts\run_js_tests.ps1` zelené, CI zelené na pushnutej vetve.
2. **Mapa presunu** v PR popise: každá sekcia (a podsekcia) dnešného CLAUDE.md → cieľový súbor a sekcia; vypustená história → kde je v KRONIKE.
3. **Akceptačné overenie „nič sa nestratilo"** slepým recenzentom (orchestrátor ho spustí pred PR): každá platná veta CLAUDE.md na `main` má
   zodpovedajúce znenie v novom domove, odkaz alebo vedome vypustenú históriu.
4. Grep `CLAUDE.md, sekcia` / `CLAUDE.md ·` / `v CLAUDE.md` mimo archívu a zdrojov ukazuje len na miesta, kde to stále platí (most).
5. KRONIKA odsek navrch; PLAN riadok P1b `✅ … — PR #?` (číslo doplní `otvor_pr.ps1`); STAV „Robí sa / Ďalší krok" (P1b hotové, ďalej P2).

## 5 · Brány

- Audit návrhu: podľa D2 nepovinný. Predrecenzia: povinný akceptačný krok § 4 bod 3 (+ dávka Ť → druhý recenzent Codex podľa D4, ak je kvóta).
- Pred PR STOP; PR otvára implementátor skriptom `scripts\otvor_pr.ps1` na pokyn orchestrátora.
