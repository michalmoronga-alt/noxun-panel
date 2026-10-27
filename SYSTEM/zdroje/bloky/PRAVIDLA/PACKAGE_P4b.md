# Package P4b — stráže: hook pred príkazom (commit a push do `main`, merge bez pripnutej hlavy, `PR #?` pri merge, runner bez `-CloseWhenDone`) (blok PRAVIDLA, 27.10.2026)

> **Trieda S** · profil `implementator-stredny` · **len hooky, ich testy, nastavenie Claude Code a dokumentácia — kód pluginu sa nemení**
> (VERSION ani `?v=` nie). Štartuje z čerstvého mainu po mergi P3b (PR #484).
> Vstupy: [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 5 (stráže G5, G7, zásada „hook je rýchla spätná väzba, CI posledná brána"), § 3 (riadky
> „Žiadne commity do `main`", „Merge s `--match-head-commit`", „In-SU runner, `-CloseWhenDone`"), § 8 (P4: „hook test aj na povolený prípad,
> nie len zakázaný") · [RESERS_POROVNANIE.md](RESERS_POROVNANIE.md) Z9, Z10, Z12 · vzor hooku a jeho testov: `.claude/hooks/po_merge.js`,
> `tests/js/test_po_merge.js`, popis hookov `docs/HOOKY.md`.
> P4 je rozdelená: **P4b** (táto) = stráže; **P4c** = prevzatie práce (karta priebehu, `rozpracovane.ps1`, G10, čakanie cez Monitor,
> KRONIKA po súboroch, `session_digest.py`) — vlastný package.

## 1 · Cieľ

Čo sa nesmie stať ani raz, zastaví stroj skôr, než príkaz zbehne. Nový hook **`.claude/hooks/straz.js`** (Node, rovnaký štýl ako
`po_merge.js`: hlavička s kontraktom, `run()` číta stdin JSON, čisté funkcie exportované pre testy, stuby cez `opts`).

**PreToolUse** na nástroje **`Bash` a `PowerShell`** (oba majú príkaz v `tool_input.command`). Platí pre hlavné okno **aj subagentov**
(implementátor tiež nesmie commitnúť do `main`). Odmietnutie = vecný dôvod po slovensky, čo je zakázané a čo urobiť namiesto toho
(nie rozkaz v tvare „ignoruj…"). Formát odmietnutia (JSON `hookSpecificOutput.permissionDecision: "deny"` + `permissionDecisionReason`,
alebo exit 2 so stderr) **over v dokumentácii Claude Code hookov** a zapíš do hlavičky hooku, ktorý z nich si použil a prečo.

**Odmietne:**

1. **Commit do `main`:** `git commit` (aj `git -C <dir> commit`, aj za `cd <dir> &&` / `;` / `Set-Location`), keď je v cieľovom priečinku
   vetva `main` (zisti `git rev-parse --abbrev-ref HEAD` v tom priečinku; stub v testoch). Odpojená hlava (`HEAD`) a iná vetva = povolené.
2. **Push do `main`:** `git push`, ktorého cieľ je `main` — `git push origin main`, `HEAD:main`, `<čokoľvek>:main`, `…:refs/heads/main`,
   s `+` aj `--force*`; a `git push` / `git push origin` bez refspecu, keď je aktuálna vetva `main`. `--dry-run` nič nemení (odmietne tiež).
3. **Merge bez pripnutej hlavy:** `gh pr merge` bez `--match-head-commit` (forma `--match-head-commit <sha>` aj `=<sha>`; hodnota
   s premennou `"$sha"` je platná — obsah sa nekontroluje).
4. **G7 — `PR #?` v hlave PR pri merge:** pri `gh pr merge <N> … --match-head-commit …` hook zistí `gh pr diff <N>` (časový limit pod timeoutom
   hooku) a odmietne, keď **pridané riadky** v súboroch, kde `scripts\otvor_pr.ps1` dopĺňa číslo (`SYSTEM/PLAN.md`, `SYSTEM/STAV.md`,
   `SYSTEM/archiv/KRONIKA.md`, `SYSTEM/archiv/DOGFOODING_vyriesene.md`), ešte obsahujú `PR #?`. Zoznam súborov je v hooku jedna konštanta;
   test overí, že je zhodný so zoznamom v hlavičke `otvor_pr.ps1`. Bez čísla `<N>` (merge aktuálnej vetvy) sa G7 nekontroluje.
5. **Runner bez `-CloseWhenDone`:** spustenie `scripts\run_su_tests.ps1` (aj `./scripts/run_su_tests.ps1`, `& …`, `powershell … -File …`)
   bez prepínača `-CloseWhenDone`; s `-DryRun` je povolené (nič nespúšťa). Michalovo ručné spustenie z terminálu hook nevidí — to je zámer.

**Kontrakt (z NAVRH § 5 a RESERS Z10):** hook je rýchla spätná väzba, **CI a ochrana vetvy na GitHube sú posledná brána** → pri akejkoľvek
vlastnej chybe (zlý JSON, chýba `git`/`gh`, sieť, timeout) príkaz **pustí** (fail-open) a mlčí; nikdy nespadne nahlas. Nesúvisiaci
príkaz opustí hneď (prvý krok je lacný textový test na `git commit` / `git push` / `gh pr merge` / `run_su_tests`, bez spúšťania procesov).
**Falošné odmietnutie je horšie než prepustenie:** text v reťazcoch a heredoc telách (správa commitu, `--body`, `echo`, `grep "git push origin main"`)
sa za príkaz nepovažuje; `git log main`, `git checkout main && git pull`, `git diff main...HEAD`, `git push origin feat/x`, `gh pr view`,
`gh pr merge --help` ostávajú povolené.

**`settings.json`:** nový záznam `PreToolUse` s matcherom `Bash|PowerShell` (príkaz v tvare ako ostatné hooky: `node -e "try{require(…straz.js).run()}catch(e){}"`,
timeout 15 s). **`po_merge.js`** dnes reaguje len na `tool_name === 'Bash'` — merge cez nástroj PowerShell minie; rozšír ho na `PowerShell`
a jeho matcher v `settings.json` na `Bash|PowerShell` (+ test).

## 2 · Text pravidiel (Z-5: čo je vynútené, v texte ostane jednou vetou s odkazom)

1. **`docs/HOOKY.md`:** nová sekcia „Stráž pred príkazom — `straz.js`" (čo odmietne, fail-open, ako ho obísť nejde a prečo to nevadí — CI,
   ochrana vetvy; testy). Opis hooku žije len tu.
2. **`AGENTS.md`** (Zákazy, riadok o `main`) · **`ORCHESTRATOR.md`** (Delegovanie a merge) · **skill `codex-po-pr`** (krok merge) ·
   **`IMPLEMENTATOR.md`** (runner `-CloseWhenDone`): pravidlo ostáva (Codex a Grok hook Claude nemajú), doplní sa len krátka zmienka
   „stráži hook (`docs/HOOKY.md`)". V IMPLEMENTATOR.md sú dnes **dve** zmienky `-CloseWhenDone` (kroky práce a Testovanie) — zjednoť na
   jednu; IMPLEMENTATOR.md (8126 B bez CR) a ORCHESTRATOR.md (9938 B, strop 10 kB) **strop nesmú prekročiť**, cieľ je, aby IMPLEMENTATOR
   po zmene nebol väčší ako dnes (P4c doň pridáva kartu priebehu).
3. **Rozhodnutie Michala 27.10.2026:** do rámčeka „Platí" v [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 9 bod 11: „ORCHESTRATOR.md má vlastný
   strop 10 kB (ostatné roly 8 kB) — potvrdil Michal." V [PACKAGE_P3b.md](PACKAGE_P3b.md) § 4 na konci „Rozhoduje Michal." → „Michal potvrdil
   10 kB (27.10.2026)."
4. **KRONIKA** odsek navrch (P4b; počty testov) · **PLAN** blok 10: riadok P4 rozdeliť na `✅ **P4b** stráže … — PR #?` a `**P4c** prevzatie
   práce — karta priebehu, `rozpracovane.ps1`, G10, čakanie cez Monitor, KRONIKA po súboroch, `session_digest.py`` · **STAV** „Robí sa /
   Ďalší krok": P4b hotová, ďalej P4c; veta „Michal rozhoduje o vlastnom strope 10 kB" zmizne.

## 3 · Testy

1. **`tests/js/test_straz.js`** (beží v `scripts\run_js_tests.ps1` aj v CI na Linuxe): **každý zákaz má povolený pár** — commit na vetve /
   na `main` / na odpojenej hlave; `git -C <main-checkout> commit`; `cd X && git commit`; push na `feat/x` / `origin main` / `HEAD:main` /
   `x:refs/heads/main` / bare push na `main`; `gh pr merge 12 --merge --match-head-commit "$sha"` / bez prepínača / `--help`; G7 s diffom
   s pridaným `PR #?` v PLAN / s `PR #?` len v kontexte (nepridaný riadok) / v inom súbore / `gh` zlyhá (→ povolené); runner s `-CloseWhenDone` /
   s `-DryRun` / bez; heredoc správa commitu obsahujúca `git push origin main` (→ povolené); nástroj PowerShell (`Set-Location`, `;`);
   nesúvisiaci príkaz. Plus procesový test (spawn `node` so stdin JSON): tvar výstupu odmietnutia, prázdny výstup pri povolení,
   zlý JSON → exit 0 bez výstupu.
2. Zhoda zoznamu súborov G7 s hlavičkou `otvor_pr.ps1` (test vyššie alebo `tests/pure/`).
3. `test_po_merge.js` doplnený o PowerShell. G4 (`--check`), encoding guard, headless `ruby tests/run_all.rb` + `scripts\run_js_tests.ps1` zelené.
   In-SU netreba (D6).

## 4 · Hotovo, keď

1. Testy § 3 zelené; v PR popise počty a tabuľka „príkaz → povolené / odmietnuté" (aspoň 15 riadkov z testu).
2. **Živý smoke po mergi** (robí orchestrátor v hlavnom okne, nové nastavenie sa načíta) — len neškodné príkazy, ktoré pri zlyhaní hooku nič
   nezmenia: `git -C "<hlavný checkout na main>" commit --allow-empty --dry-run -m smoke` → odmietnuté · `git push --dry-run origin HEAD:main` →
   odmietnuté · `gh pr merge 999999 --merge` → odmietnuté · `git push --dry-run origin HEAD:refs/heads/smoke-straz` → povolené ·
   `scripts\run_su_tests.ps1 -DryRun` → povolené · `scripts\run_su_tests.ps1 -NeexistujuciPrepinac` → odmietnuté (pri zlyhaní hooku
   PowerShell skončí na neznámom parametri). Výsledok do KRONIKY dokumentačným commitom ďalšej dávky.

## 5 · Brány a výsledok (vyplní implementátor)

- Audit návrhu: nepovinný (D2 — nemení kontrakt ani plugin). Predrecenzia: **akceptačný krok** (hook môže blokovať prácu všetkých agentov) —
  slepý recenzent dostane tento package a `git diff main...HEAD`: falošné odmietnutia, fail-open, pokrytie povolených prípadov.
- Pred PR **STOP** a report orchestrátorovi; PR až na pokyn cez `scripts\otvor_pr.ps1`.
- **Mimo rozsahu:** ochrana vetvy na GitHube (G8 — Michal), hooky iných nástrojov (Codex, Grok), P4c, hodnotenia (P5).
- **Výsledok (implementátor):** …
