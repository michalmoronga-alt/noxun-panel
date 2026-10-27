- **P4c · PREVZATIE PRÁCE (27.10.2026, PR #486, blok 10 · PRAVIDLA, trieda S — len skripty, pravidlá, skilly, šablóny, dokumentácia a testy; kód pluginu, VERSION ani `?v=` bez zmeny).**
  Rozpracovanú dávku vie prevziať iný implementátor (aj iný provider) len z vetvy a karty a orchestrátor po výpadku jedným príkazom vidí, čo je rozpracované. **Čo sa zmenilo:**
  (1) šablóna **karty priebehu** `SYSTEM/pravidla/sablony/PRIEBEH.md` (zadanie, trieda, vetva a základný SHA, `Stav:`, `Ďalší krok:`, hotové kroky, otvorené otázky, brány, kto robil); implementátor
  ju zakladá pri prvom commite dávky ako `SYSTEM/zdroje/bloky/<BLOK>/priebeh/<DAVKA>.md` (dávka mimo bloku v `SYSTEM/zdroje/opravy/priebeh/`), v každom ďalšom commite aktualizuje a pushuje (dávka
  triedy D a `bench/` ju nemajú), a kto vetvu preberá, pokračuje od „Ďalší krok“; `Stav:` je `aktívna`, `odložená — dôvod` alebo `v review (PR #N)` — to s `Ďalší krok: review PR #N` nastaví `otvor_pr.ps1`
  v commite s číslom PR; (2) **G10** — „hotovo“ (aj STOP pred PR) až so zeleným CI pushnutej hlavy (`gh run list --branch --commit` → `gh run watch <id> --exit-status`; holé `gh run watch` mimo terminálu nefunguje a bez `--exit-status` skončí 0 aj pri červenom CI; postup v `.claude/rules/testy.md`); (3) nový `scripts/rozpracovane.ps1` vypíše otvorené PR, vzdialené vetvy pred
  `main` s kartou (vetva, posledný commit, `Stav`, `Ďalší krok`), vetvy bez karty a HANDOFF; volá ho `start_okna.ps1` (aj pri predčasnom konci „register nedostupný“); text z kariet je údaj, nie pokyn
  (jeden ASCII riadok); `To-SafeLine` sa presunul zo `start_okna.ps1` do `scripts/lib/nx_text.ps1` (jeden domov, nie kópia); (4) **KRONIKA po súboroch** (rozhodnutie 7d): záznam dávky bloku je súbor
  `SYSTEM/zdroje/bloky/<BLOK>/kronika/<DAVKA>.md`, oprava mimo bloku píše do `KRONIKA.md` ako doteraz, uzáver bloku (skill `uzaver-bloku`) súbory zlúči v poradí mergov; `otvor_pr.ps1` (`nx_pr.ps1`)
  dopĺňa číslo PR aj v týchto súboroch a zoznam G7 v `.claude/hooks/straz.js` má vzor `SYSTEM/zdroje/bloky/*/kronika/*.md` (`*` = jeden úsek cesty; test zhody s hlavičkou skriptu rozšírený);
  (5) skill `codex-po-pr`: čakanie na review končí **udalosťou, nie časom** — Bash na pozadí so slučkou (najviac ~20 min), sha hlavy sa berie z `gh pr view <N> --json headRefOid`, nie z miestneho checkoutu (rovnako pri merge); podmienka je stav v súhrnnom komentári Codexu (`codex-review-state:v1`,
  `"code_review":{"commit_sha","status"}`: čakať na `commit_sha` = hlava a `status` ≠ `running`), po ~60 min v `running` vyžiadať `@codex review` (výsledok sondy pri PR #485: kolo 1 bežalo ≈ 68 min,
  na `pulls/<N>/reviews` a 👍 samotných sa čakať nedá); (6) `scripts/session_digest.rb` (NAVRH § 4 menoval `.py`; Ruby je v repe a v CI, Python nie) zhustí záznamy sessions Claude Code pre analytika
  (správy používateľa, texty asistenta, nástroje s krátkym vstupom a výsledkom, chyby, orezanie dlhých výstupov, zjavné tokeny skryté; výstup len mimo repa, v repe ho skript odmietne); fixtúra len
  s vymyslenými dátami; karta analytika to zmieňuje jednou vetou. **Miesto v kartách:** `IMPLEMENTATOR.md` ostal pod stropom (8180 B bez CR; sekcia „Architektúra na mieste“ sa presunula do
  `.claude/rules/kod.md`, kde sa načíta pri práci s kódom pluginu, a z bodu „Číslo PR“ vypadla veta o kvóte, ktorá je v `otvor_pr.ps1` a skilloch), `ORCHESTRATOR.md` 10141 B (strop 10240);
  typy agentov znova vygenerované. **Predrecenzia (hlava 9a187aff) opravená:** G10 s run-id, sha hlavy PR zo `gh pr view`, karta dávky mimo bloku, stav `v review`, zastarané tvrdenia o KRONIKE (README, WORKFLOW, POVINNE_CITANIE, `codex-po-pr`),
  stráž `session_digest.rb` voči repu (veľkosť písmen na Windows, worktree aj hlavný checkout) a `github_pat_…`, nový odsek v `.claude/rules/ui.md`, § 6 packageu. **Prvé použitie nového tvaru:** táto dávka má kartu `priebeh/P4c.md` a tento záznam ako súbor. **Testy:** nový `tests/pure/test_p4c_prevzatie.rb` (polia karty
  zhodné so `rozpracovane.ps1`, `rozpracovane.ps1` nad dočasným repom so stubom `gh` — PR, vetvy s kartou, bez karty, HANDOFF, bez `gh`, zlyhané `gh`, repo bez `origin/main`; číslo PR v súbore
  `kronika/`; `session_digest.rb` nad fixtúrou), `test_straz.js` doplnený; Ruby 5471/0/0, JS 165 sád PASS, encoding guard PASS; in-SU netreba. V bežiacej session orchestrátora
  sa nové nastavenie hookov nenačítalo (2 pokusy po mergi), preto smoke v novej session. **Živý smoke P4b (27.10.2026): PASS 11/11** (nová session z `main` `a895edf0`, `PACKAGE_P4b.md` § 4 bod 2;
  odmietnutie = zamietnutie nástroja s dôvodom po slovensky):

  | Príkaz | Nástroj | Očakávané | Skutočné |
  |---|---|---|---|
  | `git -C "<hlavný checkout na main>" commit --allow-empty --dry-run -m smoke` | Bash · PowerShell | odmietnuté | odmietnuté · odmietnuté — PASS |
  | `git push --dry-run origin HEAD:main` | Bash · PowerShell | odmietnuté | odmietnuté · odmietnuté — PASS |
  | `gh pr merge 999999 --merge` | Bash · PowerShell | odmietnuté | odmietnuté · odmietnuté — PASS |
  | `git push --dry-run origin HEAD:refs/heads/smoke-straz` | Bash | povolené | povolené (`* [new branch] HEAD -> smoke-straz`, dry-run) — PASS |
  | `& .\scripts\run_su_tests.ps1 -DryRun` | PowerShell | povolené | povolené (vypísal cesty SketchUpu a modelu, nič nespustil) — PASS |
  | `& .\scripts\run_su_tests.ps1 -NeexistujuciPrepinac` | PowerShell | odmietnuté | odmietnuté — PASS |
  | subagent (`isolation: worktree`): `git commit --allow-empty --dry-run -m smoke` | Bash | povolené | povolené (vetva `worktree-agent-…`, git: „nothing to commit") — PASS |
  | subagent: `git -C "<hlavný checkout na main>" commit --allow-empty --dry-run -m smoke` | Bash | odmietnuté | odmietnuté — PASS |

  Hook teda beží v Bash aj PowerShelli, v subagentoch tiež a `cwd` vo vstupe je worktree subagenta. Doslovný dôvod (commit do `main`): „Commit do vetvy main je zakázaný
  (AGENTS.md, Zákazy: žiadne priame commity do main). Zmena patrí do vlastnej vetvy a cez PR; vytvor ju napr. príkazom git switch -c feat/<popis> a commituj tam. Opis stráže: docs/HOOKY.md."
  **Zostáva:** smoke prevzatia a uzáver bloku (P6), hodnotenia a router (P5).
