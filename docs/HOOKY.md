# Lokálne hooky (Claude Code)

> Popis hookov repa pre ľudí a agentov. Konfigurácia je v `.claude/settings.json`, skripty v `.claude/hooks/`.
> Pravidlo pre implementátora je jedno: hook po Edit/Write hlási syntax a encoding — pri hláške chybu hneď oprav; vynucuje CI.

## Po každom Edit/Write — `post_edit_check.ps1`

PostToolUse po každom Edit/Write spustí `.claude/hooks/post_edit_check.ps1` — kontrola editovaného súboru:

- `ruby -c` syntax (`.rb`),
- encoding guard (`.rb`, `.js`, `.html`, `.css`, `.md`, `.ps1`): BOM, UTF-8, mojibake, C0/C1/NUL, cyrilické homoglyfy, charset.

**Jediná implementácia encoding guardu je `scripts/encoding_guard.rb`**, ktorú volá aj CI test `tests/pure/test_encoding_guard.rb`
nad celým repom; pravidlá sa menia len tam. Ručne: `ruby scripts/encoding_guard.rb --repo`.

Hook je rýchla spätná väzba: edit už je zapísaný, takže pri hláške chybu hneď oprav. Vynucovanie ostáva na CI.

## Stráž pred príkazom — `straz.js`

PreToolUse na nástroje Bash a PowerShell (`Bash|PowerShell`), v hlavnom okne **aj u subagentov** (implementátor tiež nesmie commitnúť do
`main`). Odmietne päť vecí, ktoré sa nesmú stať ani raz; odmietnutie nesie vecný dôvod po slovensky, čo je zakázané a čo urobiť namiesto toho:

| Zákaz | Odmietne | Povolené zostáva |
|---|---|---|
| Commit do `main` | `git commit` (aj `git -C <dir> commit`, aj za `cd <dir> &&` / `;` / `Set-Location`), keď je v cieľovom priečinku vetva `main` | iná vetva, odpojená hlava, `git commit --help`, text v reťazci / heredoc |
| Push do `main` | `git push` s cieľom `main` (`origin main`, `HEAD:main`, `x:refs/heads/main`, aj `+` / `--force*` / `--dry-run`); `git push` bez refspecu, keď je aktuálna vetva `main` | `git push origin feat/x`, `main:feat/x`, `--tags` |
| Merge bez pripnutej hlavy | `gh pr merge` bez `--match-head-commit` (tvar `<sha>` aj `=<sha>`; hodnota sa neskúma) | `gh pr merge --help`, `gh pr view` |
| Zástupné číslo PR pri merge (G7) | `gh pr merge <N> … --match-head-commit …`, keď `gh pr diff <N>` obsahuje v **pridaných** riadkoch súborov `PLAN.md`, `STAV.md`, `KRONIKA.md`, `DOGFOODING_vyriesene.md` ešte zástupné číslo PR (to dopĺňa `scripts\otvor_pr.ps1`) | merge bez čísla PR sa nekontroluje; zástupné číslo v kontexte, v odstránenom riadku alebo v inom súbore nevadí |
| Runner bez `-CloseWhenDone` | spustenie `scripts\run_su_tests.ps1` (aj `./`, `& …`, `powershell -File …`) bez `-CloseWhenDone` | s `-CloseWhenDone` alebo `-DryRun`, čítanie či `git add` toho súboru |

**Kontrakt:** stráž je rýchla spätná väzba, **posledná brána je CI a ochrana vetvy na GitHube**. Pri akejkoľvek vlastnej chybe (zlý JSON,
chýba `git` alebo `gh`, sieť, timeout, neznámy priečinok) príkaz **pustí** a mlčí; nesúvisiaci príkaz opustí hneď (lacný textový test, bez
spúšťania procesov). Falošné odmietnutie je horšie než prepustenie, preto sa text v úvodzovkách a v telách heredoc / PowerShell here-string
(správa commitu, `--body`, `echo`, `grep "git push origin main"`) za príkaz nepovažuje a posudzuje sa len prvé slovo každého jednoduchého
príkazu; vnútro substitúcií `$( … )`, PowerShell `( … )`, podmienok a blokov `{ … }` sa posudzuje samostatne. Známe medze (prepustí sa): aliasy
gitu, `eval` / `Invoke-Expression`, premenná ako priečinok, vetva po `git switch` / `checkout` v tom istom príkaze, príkaz vnorený hlbšie než
dve úrovne, refspec zložený z textu a substitúcie (`feat/$(…)`), PowerShell `if($x){git push origin main}` / `if ($x){git push origin main}` (bez
medzery pred alebo za zátvorkou) a `$out = git push origin main 2>&1` (priradenie bez zátvoriek). Vetvu zisťuje v cieľovom priečinku príkazu, takže commit a push do `main` odmietne v ľubovoľnom repe (aj `git -C <iné repo>`). Stráž nie je neprekonateľná a nemusí byť: čo prejde, zastaví CI a ochrana vetvy. Michalovo ručné spustenie z terminálu stráž nevidí
(zámer). Codex a Grok hook nemajú, pravidlá pre ne ostávajú v texte ([AGENTS.md](../AGENTS.md)). Formát odmietnutia: JSON
`hookSpecificOutput.permissionDecision: "deny"` s `permissionDecisionReason` na stdout, exit 0 (dôvod výberu je v hlavičke hooku).
Testy: `tests/js/test_straz.js`.

## Hooky hlavného okna (orchestrátor)

Pravidlá, ktoré z nich plynú, sú v [ORCHESTRATOR.md](../SYSTEM/pravidla/roly/ORCHESTRATOR.md); tu je len opis hookov.

### Pripomienka po mergi — `po_merge.js`

PostToolUse na Bash a PowerShell s filtrom `gh pr merge` (hook si príkaz filtruje sám; v settings je len matcher `Bash|PowerShell`, bez poľa `if`). Po `gh pr merge <N>`
vloží hlavnému agentovi vecné konštatovanie v dvoch riadkoch: „PR #N menil plugin: áno/nie" (z `gh pr view`) a „Nasadený je <vetva> <sha>
(<čas>) → inštalácia mainu je potrebná / nie je potrebná". Údaje berie zo značky nasadenia `%TEMP%\noxun_nasadene.txt` (vetva, SHA, či bol
strom čistý, čas; zapisuje ju `INSTALL_noxun_engine.ps1`) a z porovnania kódu pluginu s `origin/main`; chýbajúca značka alebo neznámy stav
= „potrebná". Sama nič nespúšťa, pri chybe mlčí a príkaz nikdy neblokuje. Živé spustenie z Claude Code sa overuje pri reálnom merge.
Testy: `tests/js/test_po_merge.js`.

### Ukazovateľ kontextu — `context_meter.js`

Hook vloží hlavnému agentovi riadok `Kontext orchestrátora: 612k z 1M (61 %).` pri každej správe Michala a po nástroji len pri prechode
do vyššieho pásma (50–95 %); subagentov nechá na pokoji. Čo robiť od 75 % a 90 %, určuje ORCHESTRATOR.md (Ukazovateľ kontextu).
Testy: `tests/js/test_context_meter.js`.
