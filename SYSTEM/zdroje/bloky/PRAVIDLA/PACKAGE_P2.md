# Package P2 — roly: karty rolí, typy agentov len so svojimi pravidlami, rola analytik (blok PRAVIDLA, 23.10.2026)

> **Trieda Ť** (mení, čo dostane každý subagent) · profil `implementator` · **len pravidlá, generátor a testy — kód pluginu sa nemení**.
> Vstupy: [ROLY.md](ROLY.md) § 1–3 (šablóna a karty), § 6 (kontext podľa roly) · [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 1 (`omitClaudeMd`),
> § 2.2, § 5 (G4) · [P1b_MAPA_PRESUNU.md](P1b_MAPA_PRESUNU.md) (stĺpec „kto videl → kto uvidí") · `SYSTEM/pravidla/` (AGENTS, DEFINICIE, roly/, POVINNE_CITANIE).

## 0 · Sonda (23.10.2026, hlava main po P1b)

| Tvrdenie | Overenie | Výsledok |
|---|---|---|
| Claude Code podporuje `omitClaudeMd` v type agenta | `claude --version` = 2.1.301; NAVRH § 1 (pole od 2.1.271) | **implementátor overí v docs code.claude.com/docs/en/sub-agents** pred použitím; keď pole nie je, STOP a hlásiť |
| Mod usage-bar číta obsadenie z WORKFLOW | `~/.claude/mods/usage-bar/hooks/register.tsx:39, 749` | áno — `WORKFLOW.md`, sekcia `## 2 · Obsadenie rolí`, stĺpec „Aktuálne" → **obsadenie sa v P2 NEPRESÚVA** (ide do P5 spolu s routerom a úpravou modu) |

## 1 · Cieľ

Každý typ subagenta dostane **len pravidlá svojej roly** (Z-4) a typy sa nerozídu so súbormi rolí (Z-3):
1. **Karty rolí** v `SYSTEM/pravidla/roly/` podľa šablóny ROLY § 1 (účel · režimy · dostane automaticky · dostane v zadaní · nečíta · smie/nesmie ·
   vráti · zastaví sa, keď): nové `RECENZENT.md`, `AUDITOR.md`, `RESERSER.md`, `ANALYTIK.md`; existujúce `ORCHESTRATOR.md` a `IMPLEMENTATOR.md`
   doplniť o chýbajúce kolónky šablóny (len karta navrchu, telo ostáva). **Obsah kariet = dnes platné pravidlá** z tiel typov agentov a skillov
   (presun, nie nové pravidlá); budúce body ROLY § 3 (hodnotenie po úlohe, karta priebehu, režim prevzatie) sa **nepridávajú** — prídu v P4/P5.
2. **Generátor tiel typov** `scripts/generuj_typy_agentov.rb`: telo každého `.claude/agents/<typ>.md` = hlavička typu (ručná, v zdroji
   `SYSTEM/pravidla/typy/<typ>.yml` alebo v hlavičke súboru — vyber čistejšie a zdôvodni) + vložené `AGENTS.md` + súbory podľa ROLY § 6
   (implementátor: DEFINICIE + IMPLEMENTATOR; recenzent: DEFINICIE + RECENZENT + sekcie IMPLEMENTATOR Verzia a Testovanie; rešeršér: len RESERSER;
   analytik: ANALYTIK; obal `agy-reserser`: len jeho súčasné telo — je to obal, nie rola). Výstup je deterministický (rovnaký vstup → rovnaký súbor).
3. **`omitClaudeMd: true`** vo frontmatter všetkých typov (po overení v sonde) — subagent tak nededí most CLAUDE.md (a tým ORCHESTRATOR.md).
4. **Nový typ `analytik`** (`.claude/agents/analytik.md`): profil podľa ROLY § 3.6 a obsadenia (Sonnet, effort medium; Haiku na mechanické výťahy —
   Michal 22.10. schválil, ❓6 v ROLY.md); nástroje len čítanie (`Read, Grep, Glob, Bash`), žiadny zápis mimo výstupu určeného zadaním.
   Do WORKFLOW § 2 (tabuľka Obsadenie rolí) pridať riadok typu `analytik` **v rovnakom tvare** ako ostatné (mod usage-bar a guard
   `test_agent_definitions.rb` ho čítajú).
5. **Zjednotenie výnimky testovania** (ENGINEtests alebo neuložené Untitled okno bez NOXUN korpusov) — vďaka generovaniu ju typy implementátorov
   dostanú z IMPLEMENTATOR.md; ručné odchýlky v telách zmiznú.

## 2 · Stráže a testy

1. **G4** (rozšírenie `tests/pure/test_agent_definitions.rb` alebo nový test): (a) telo každého generovaného typu je zhodné s výstupom generátora
   (spustí generátor do pamäte a porovná) — inak hláška „spusti `ruby scripts/generuj_typy_agentov.rb`"; (b) všetky typy majú `omitClaudeMd: true`;
   (c) žiadny typ okrem obalov neobsahuje text ORCHESTRATOR.md (podpisová veta „Hlavné okno je orchestrátor").
2. G1 stropy (test_pravidla_velkost): nové karty ≤ 14 kB (dočasný strop z P1b), typy agentov bez stropu (sú generované).
3. `test_docs_navigacia`, `test_definicie` (G3) — nové súbory do zoznamov.
4. Headless + `scripts\run_js_tests.ps1` zelené.

## 3 · Hotovo, keď

1. `ruby scripts/generuj_typy_agentov.rb --check` = žiadny rozdiel; G4 zelený.
2. **Overenie „kto čo dostane"** (akceptačný krok, robí slepý recenzent + druhý recenzent iného providera podľa D4): pre každý typ zoznam pravidiel,
   ktoré **predtým dostal** (CLAUDE.md po P1b = AGENTS + ORCHESTRATOR, plus jeho telo) a **teraz dostane**; nič, čo rola potrebuje, nechýba, a nedostane
   pravidlá orchestrátora (merge, kvóty, autonómne bloky). Tabuľku pripraví implementátor ako `SYSTEM/zdroje/bloky/PRAVIDLA/P2_KTO_CO_DOSTANE.md`.
3. Skilly a WORKFLOW, ktoré opisujú telá typov („v definícii typu je…"), sedia s generovaným stavom (Grep).
4. KRONIKA odsek navrch; PLAN riadok P2 `✅ … — PR #?` (číslo doplní `otvor_pr.ps1`); STAV „Robí sa / Ďalší krok".
5. **Smoke po mergi (orchestrátor, nová session):** spustiť jeden typ (napr. `analytik` s otázkou na posledný riadok AGENTS.md a na prvú vetu
   ORCHESTRATOR.md) — prvú musí poznať, druhú nie.

## 4 · Brány

- Audit návrhu: podľa D2 nepovinný. Predrecenzia: povinný akceptačný krok § 3 bod 2 (D4, dvaja recenzenti). Pred PR STOP; PR cez `scripts\otvor_pr.ps1`.
- **Mimo rozsahu:** presun tabuliek obsadenia do `OBSADENIE.md` a úprava modu usage-bar → **P5** (router). `.claude/rules/` → P3.
