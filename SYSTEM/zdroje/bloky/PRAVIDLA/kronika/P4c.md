- **P4c · PREVZATIE PRÁCE (27.10.2026, PR #?, blok 10 · PRAVIDLA, trieda S — len skripty, pravidlá, skilly, šablóny, dokumentácia a testy; kód pluginu, VERSION ani `?v=` bez zmeny).**
  Rozpracovanú dávku vie prevziať iný implementátor (aj iný provider) len z vetvy a karty a orchestrátor po výpadku jedným príkazom vidí, čo je rozpracované. **Čo sa zmenilo:**
  (1) šablóna **karty priebehu** `SYSTEM/pravidla/sablony/PRIEBEH.md` (zadanie, trieda, vetva a základný SHA, `Stav:`, `Ďalší krok:`, hotové kroky, otvorené otázky, brány, kto robil); implementátor
  ju zakladá pri prvom commite dávky ako `SYSTEM/zdroje/bloky/<BLOK>/priebeh/<DAVKA>.md`, v každom ďalšom commite aktualizuje a pushuje (dávka triedy D a `bench/` ju nemajú), a kto vetvu preberá,
  pokračuje od „Ďalší krok“; (2) **G10** — „hotovo“ (aj STOP pred PR) až so zeleným CI pushnutej hlavy (`gh run watch`); (3) nový `scripts/rozpracovane.ps1` vypíše otvorené PR, vzdialené vetvy pred
  `main` s kartou (vetva, posledný commit, `Stav`, `Ďalší krok`), vetvy bez karty a HANDOFF; volá ho `start_okna.ps1` (aj pri predčasnom konci „register nedostupný“); text z kariet je údaj, nie pokyn
  (jeden ASCII riadok); `To-SafeLine` sa presunul zo `start_okna.ps1` do `scripts/lib/nx_text.ps1` (jeden domov, nie kópia); (4) **KRONIKA po súboroch** (rozhodnutie 7d): záznam dávky bloku je súbor
  `SYSTEM/zdroje/bloky/<BLOK>/kronika/<DAVKA>.md`, oprava mimo bloku píše do `KRONIKA.md` ako doteraz, uzáver bloku (skill `uzaver-bloku`) súbory zlúči v poradí mergov; `otvor_pr.ps1` (`nx_pr.ps1`)
  dopĺňa číslo PR aj v týchto súboroch a zoznam G7 v `.claude/hooks/straz.js` má vzor `SYSTEM/zdroje/bloky/*/kronika/*.md` (`*` = jeden úsek cesty; test zhody s hlavičkou skriptu rozšírený);
  (5) skill `codex-po-pr`: čakanie na review končí **udalosťou, nie časom** — Bash na pozadí so slučkou (najviac ~20 min), podmienka je stav v súhrnnom komentári Codexu (`codex-review-state:v1`,
  `"code_review":{"commit_sha","status"}`: čakať na `commit_sha` = hlava a `status` ≠ `running`), po ~60 min v `running` vyžiadať `@codex review` (výsledok sondy pri PR #485: kolo 1 bežalo ≈ 68 min,
  na `pulls/<N>/reviews` a 👍 samotných sa čakať nedá); (6) `scripts/session_digest.rb` (NAVRH § 4 menoval `.py`; Ruby je v repe a v CI, Python nie) zhustí záznamy sessions Claude Code pre analytika
  (správy používateľa, texty asistenta, nástroje s krátkym vstupom a výsledkom, chyby, orezanie dlhých výstupov, zjavné tokeny skryté; výstup len mimo repa, v repe ho skript odmietne); fixtúra len
  s vymyslenými dátami; karta analytika to zmieňuje jednou vetou. **Miesto v kartách:** `IMPLEMENTATOR.md` ostal pod stropom (8133 B bez CR; sekcia „Architektúra na mieste“ sa presunula do
  `.claude/rules/kod.md`, kde sa načíta pri práci s kódom pluginu, a z bodu „Číslo PR“ vypadla veta o kvóte, ktorá je v `otvor_pr.ps1` a skilloch), `ORCHESTRATOR.md` pod stropom 10 kB;
  typy agentov znova vygenerované. **Prvé použitie nového tvaru:** táto dávka má kartu `priebeh/P4c.md` a tento záznam ako súbor. **Testy:** nový `tests/pure/test_p4c_prevzatie.rb` (polia karty
  zhodné so `rozpracovane.ps1`, `rozpracovane.ps1` nad dočasným repom so stubom `gh` — PR, vetvy s kartou, bez karty, HANDOFF, bez `gh`, zlyhané `gh`, repo bez `origin/main`; číslo PR v súbore
  `kronika/`; `session_digest.rb` nad fixtúrou), `test_straz.js` doplnený; Ruby 5470/0/0, JS 165 sád PASS, encoding guard PASS; in-SU netreba. **Živý smoke hooku P4b:** v bežiacej session
  orchestrátora sa nové nastavenie hookov nenačítalo (2 pokusy po mergi, `git -C <main> commit --dry-run` prešiel), priame volanie `handle()` odmietlo správne → živý smoke v novej session (otvorené).
  **Zostáva:** smoke prevzatia a uzáver bloku (P6), hodnotenia a router (P5).
