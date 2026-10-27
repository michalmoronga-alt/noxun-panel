// Testy stráže pred príkazom (.claude/hooks/straz.js, P4b, 27.10.2026).
// Je to Claude Code hook, nie kód pluginu: PreToolUse na Bash a PowerShell odmietne commit a push do main,
// `gh pr merge` bez --match-head-commit, merge PR so zástupným číslom PR v pridaných riadkoch a runner in-SU testov
// bez -CloseWhenDone. Zásada testov: KAŽDÝ zákaz má povolený pár (falošné odmietnutie je horšie než prepustenie).
// Zisťovanie vetvy (git) a `gh pr diff` sú stubnuté (opts.branchOf, opts.prDiff); procesové testy bežia aj s prázdnym PATH
// a jeden blok beží nad skutočným dočasným repom.
'use strict';
const assert = require('node:assert');
const cp = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const SCRIPT = path.join(ROOT, '.claude', 'hooks', 'straz.js');
const M = require(SCRIPT);

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'noxun_straz_test_'));
const MAIN = path.join(TMP, 'main_checkout');       // checkout na vetve main
const WT = path.join(TMP, 'worktree');              // worktree na feat/x
const DET = path.join(TMP, 'detached');             // odpojená hlava
const UNK = path.join(TMP, 'neznamy');              // priečinok, kde sa vetva nezistí
const BRANCHES = new Map([[path.resolve(MAIN), 'main'], [path.resolve(WT), 'feat/x'], [path.resolve(DET), 'HEAD']]);
const fw = (p) => p.replace(/\\/g, '/');            // cesta s lomkami (platí v bashi aj PowerShelli)

const ROWS = [];                                    // [nástroj, príkaz, cwd, očakávaný kód alebo null] pre tabuľku PR
try {
  const state = { branchCalls: [], diffCalls: [], diff: null };
  const opts = {
    branchOf: (dir) => { state.branchCalls.push(dir); return BRANCHES.has(path.resolve(dir)) ? BRANCHES.get(path.resolve(dir)) : null; },
    prDiff: (arg, repo, dir) => { state.diffCalls.push([arg, repo, dir]); if (state.diff instanceof Error) throw state.diff; return state.diff; },
  };
  const input = (command, tool, cwd, extra) => Object.assign({
    hook_event_name: 'PreToolUse', tool_name: tool || 'Bash', tool_input: { command }, cwd: cwd || WT,
  }, extra || {});
  // kód odmietnutia ('commit' | 'push' | 'pin' | 'g7' | 'runner') alebo null = povolené
  const code = (command, tool, cwd) => { const r = M.decide(input(command, tool, cwd), opts); return r ? r.code : null; };
  const check = (expected, command, tool, cwd, label) => {
    const t = tool || 'Bash';
    eq(code(command, t, cwd), expected, `${t}: ${label || command.split('\n')[0]}`);
    ROWS.push([t, command.split('\n')[0], cwd, expected]);
  };
  const deny = (c, cmd, tool, cwd) => check(c, cmd, tool, cwd);
  const allow = (cmd, tool, cwd, label) => check(null, cmd, tool, cwd, label);

  // --- 1. commit do main ----------------------------------------------------------------------
  allow('git commit -m "feat: x"', 'Bash', WT);                                  // vetva feat/x
  deny('commit', 'git commit -m "feat: x"', 'Bash', MAIN);                       // vetva main
  allow('git commit -m "x"', 'Bash', DET);                                       // odpojená hlava
  allow('git commit -m "x"', 'Bash', UNK);                                       // vetva neznáma = prepustiť
  deny('commit', `git -C ${fw(MAIN)} commit -m x`, 'Bash', WT);                  // -C na main checkout
  allow(`git -C ${fw(WT)} commit -m x`, 'Bash', MAIN);                           // -C na worktree, aj keď cwd je main
  deny('commit', `cd ${fw(MAIN)} && git commit -m x`, 'Bash', WT);
  deny('commit', `cd ${fw(MAIN)}; git commit -m x`, 'Bash', WT);
  allow(`cd ${fw(WT)} && git commit -m x`, 'Bash', MAIN);
  allow(`cd ${fw(MAIN)} && git status && cd ${fw(WT)} && git commit -m x`, 'Bash', WT, 'cd tam a naspat');
  allow(`(cd ${fw(MAIN)} && git status); git commit -m x`, 'Bash', WT);          // cd v podshelle sa nevracia von
  deny('commit', `(cd ${fw(MAIN)} && git commit -m x)`, 'Bash', WT);
  deny('commit', 'git commit --amend --no-edit', 'Bash', MAIN);
  deny('commit', 'git commit --allow-empty --dry-run -m smoke', 'Bash', MAIN);
  deny('commit', 'git -c user.name=T -c user.email=t@e.x commit -m x', 'Bash', MAIN);
  deny('commit', 'GIT_AUTHOR_NAME=x git commit -m x', 'Bash', MAIN);
  deny('commit', 'git add -A && git commit -m x', 'Bash', MAIN);
  deny('commit', 'git commit -F - <<\'EOF\'\nsprava\nEOF', 'Bash', MAIN);
  deny('commit', 'time git commit -m x', 'Bash', MAIN);
  deny('commit', `git --no-pager -C ${fw(MAIN)} commit -m x`, 'Bash', WT);
  allow('git commit --help', 'Bash', MAIN);
  allow('git commit-tree abc', 'Bash', MAIN);
  allow('git switch -c feat/a && git commit -m x', 'Bash', MAIN, 'switch -c a hned commit (vetva sa zmeni)');
  allow('git status && git log main --oneline', 'Bash', MAIN);
  allow('git add -A', 'Bash', MAIN);
  allow('git diff main...HEAD', 'Bash', MAIN);
  allow('git checkout main && git pull', 'Bash', WT);
  allow('git branch -d feat/x', 'Bash', MAIN);
  // text v reťazcoch, heredoc a echo sa za príkaz nepovažuje
  allow('echo git commit -m x', 'Bash', MAIN);
  allow('echo "cd x && git commit"', 'Bash', MAIN);
  allow('grep "git commit" SYSTEM/pravidla/roly/IMPLEMENTATOR.md', 'Bash', MAIN);
  allow('git commit -m "docs: git push origin main je zakazane"', 'Bash', WT);
  allow('cat <<\'EOF\'\ngit commit -m x\nEOF', 'Bash', MAIN);
  allow('git commit -F - <<\'EOF\'\nsprava\ngit push origin main\nEOF', 'Bash', WT, 'heredoc sprava s git push origin main (vetva feat/x)');
  allow('# git commit -m x', 'Bash', MAIN, 'komentar');
  // štandardná správa commitu / popis PR: -m "$(cat <<'EOF' … EOF)" s úvodzovkami, bodkočiarkou a zátvorkami v tele
  const MSG = '"$(cat <<\'EOF\'\nfix: "citat"; git push origin main (a) && git commit -m y\n\nCo-Authored-By: X <x@e.x>\nEOF\n)"';
  allow(`git commit -m ${MSG}`, 'Bash', WT, 'sprava commitu $(cat <<EOF) s uvodzovkami a git push origin main v tele');
  deny('commit', `git commit -m ${MSG}`, 'Bash', MAIN);
  allow(`git add -A && git commit -m ${MSG} && git push origin feat/x`, 'Bash', WT, 'add && commit s $(cat <<EOF) && push na feat/x');
  allow(`gh pr create --title "x" --body ${MSG}`, 'Bash', MAIN, 'popis PR $(cat <<EOF) s git commit v tele');
  allow('git commit -m "a `date` b; git push origin main"', 'Bash', WT, 'spatne apostrofy v uvodzovkach');
  deny('push', `git commit -m ${MSG} && git push origin main`, 'Bash', WT);
  deny('commit', `echo ${MSG}; git commit -m x`, 'Bash', MAIN);
  // PowerShell
  deny('commit', `Set-Location ${fw(MAIN)}; git commit -m x`, 'PowerShell', WT);
  deny('commit', `Set-Location -Path "${MAIN}"; git commit -m x`, 'PowerShell', WT);
  deny('commit', `cd '${MAIN}'; git commit -m x`, 'PowerShell', WT);
  deny('commit', `& git -C "${MAIN}" commit -m x`, 'PowerShell', WT);
  deny('commit', `git.exe -C ${fw(MAIN)} commit -m x`, 'PowerShell', WT);
  allow(`Set-Location ${fw(WT)}; git commit -m x`, 'PowerShell', MAIN);
  allow('git commit -m @\'\ngit push origin main\n\'@', 'PowerShell', WT, 'PowerShell here-string s git push origin main (feat/x)');
  deny('commit', 'git commit -m @\'\nsprava\n\'@', 'PowerShell', MAIN);
  allow('Write-Host "git commit"', 'PowerShell', MAIN);
  allow('git status; git log -3', 'PowerShell', MAIN);

  // príkazy vnútri substitúcií, podmienok a blokov (vnútro $( … ) a ( … ) sa posudzuje ako príkaz)
  deny('push', 'if ($LASTEXITCODE -eq 0) { git push origin main }', 'PowerShell', WT);
  deny('push', 'if ($ok) {git push origin main}', 'PowerShell', WT);
  deny('commit', 'if (Test-Path x) { git commit -m x }', 'PowerShell', MAIN);
  deny('commit', 'if ($a) { git status } else { git commit -m x }', 'PowerShell', MAIN);
  deny('runner', 'if ($ok) { scripts/run_su_tests.ps1 }', 'PowerShell', WT);
  deny('push', '(git push origin main)', 'PowerShell', WT);
  deny('push', '$out = (git push origin main 2>&1)', 'PowerShell', WT);
  deny('push', 'foreach ($b in 1,2) { git push origin main }', 'PowerShell', WT);
  deny('push', 'out=$(git push origin main 2>&1); echo "$out"', 'Bash', WT);
  deny('commit', 'echo $(git commit -m x)', 'Bash', MAIN);
  deny('commit', 'echo "$(git commit -m x)"', 'Bash', MAIN);
  deny('commit', `x=$(cd ${fw(MAIN)} && git commit -m x)`, 'Bash', WT);
  deny('push', 'git push origin $(git branch --show-current)', 'Bash', MAIN);       // refspec = substitucia: podla aktualnej vetvy
  deny('push', 'git push origin (git branch --show-current)', 'PowerShell', MAIN);
  allow('git push origin $(git branch --show-current)', 'Bash', WT);
  allow('if ($LASTEXITCODE -eq 0) { git push origin feat/x }', 'PowerShell', MAIN);
  allow('if (Test-Path x) { git commit -m x }', 'PowerShell', WT);
  allow('if ($ok) { scripts/run_su_tests.ps1 -CloseWhenDone }', 'PowerShell', WT);
  allow('(git status)', 'PowerShell', MAIN);
  allow('$sha = (git rev-parse HEAD); git commit -m x', 'PowerShell', WT);
  allow('out=$(git status 2>&1); git commit -m x', 'Bash', WT);
  allow('echo $(git status)', 'Bash', MAIN);
  allow('foreach ($b in 1,2) { git push origin $b }', 'PowerShell', MAIN);
  allow('git push origin feat/$(date +%s)', 'Bash', MAIN);
  allow('$h = @{a=1}; git commit -m "${x}"', 'PowerShell', WT);

  // here-string <<< nie je heredoc: riadky za nim sa nezahodia
  deny('pin', 'cat <<< "hello"\ngh pr merge 12 --merge', 'Bash', WT);
  deny('commit', 'cat <<< "hello"\ngit commit -m x', 'Bash', MAIN);
  deny('commit', 'git commit -m x <<< "y"', 'Bash', MAIN);
  deny('push', 'grep a <<< "$x"; git push origin main', 'Bash', WT);
  deny('pin', 'cat <<< "hello"\ngh pr merge 12 --merge', 'PowerShell', WT);                // v PowerShelli <<< nič nerozbije
  allow('cat <<< "hello"\ngh pr merge 12 --merge --match-head-commit "$sha"', 'Bash', WT);
  allow('git commit -m x <<< "y"', 'Bash', WT);
  deny('commit', 'cat <<EOF\ntelo\nEOF\ncat <<< "a"\ngit commit -m x', 'Bash', MAIN);        // skutočný heredoc popri <<<
  allow('cat <<EOF\ngit commit -m x\nEOF', 'Bash', MAIN);

  // --- 2. push do main --------------------------------------------------------------------------
  allow('git push origin feat/x', 'Bash', MAIN);
  allow('git push -u origin feat/x', 'Bash', WT);
  allow('git push origin HEAD', 'Bash', WT);
  deny('push', 'git push origin HEAD', 'Bash', MAIN);                            // HEAD = main
  deny('push', 'git push origin main', 'Bash', WT);
  deny('push', 'git push origin HEAD:main', 'Bash', WT);
  deny('push', 'git push origin feat/x:main', 'Bash', WT);
  deny('push', 'git push origin x:refs/heads/main', 'Bash', WT);
  deny('push', 'git push origin refs/heads/main', 'Bash', WT);
  deny('push', 'git push --force origin main', 'Bash', WT);
  deny('push', 'git push -f origin +main', 'Bash', WT);
  deny('push', 'git push --force-with-lease origin HEAD:main', 'Bash', WT);
  deny('push', 'git push --dry-run origin HEAD:main', 'Bash', WT);
  deny('push', 'git push origin :main', 'Bash', WT);
  deny('push', 'git push origin --delete main', 'Bash', WT);
  deny('push', 'git push origin main > out.log 2>&1', 'Bash', WT);
  deny('push', `git -C ${fw(WT)} push origin main`, 'Bash', MAIN);
  deny('push', 'git add -A && git push origin main', 'Bash', WT);
  deny('push', 'git push', 'Bash', MAIN);                                        // bare push na main
  deny('push', 'git push origin', 'Bash', MAIN);
  deny('push', 'git push -u origin', 'Bash', MAIN);
  deny('push', 'git push > out.log', 'Bash', MAIN);
  deny('push', 'git push origin main', 'PowerShell', WT);
  deny('push', 'git push origin 2>&1', 'PowerShell', MAIN);                      // 2>&1 nie je refspec
  deny('push', 'git push -u origin 2>&1 | Select-Object -Last 3', 'PowerShell', MAIN);
  deny('push', 'git push origin main 2>&1', 'PowerShell', WT);
  allow('git push origin 2>&1', 'PowerShell', WT);
  allow('git push origin feat/x 2>&1 | Select-Object -Last 3', 'PowerShell', MAIN);
  allow('git push', 'Bash', WT);                                                 // bare push na feat/x
  allow('git push origin', 'Bash', WT);
  allow('git push', 'Bash', DET);
  allow('git push', 'Bash', UNK);
  allow('git push --tags', 'Bash', MAIN);                                        // len tagy
  allow('git push origin main:feat/x', 'Bash', WT);                              // main je len zdroj
  allow('git push origin feat/main', 'Bash', WT);
  allow('git push origin feat/x:main-backup', 'Bash', WT);
  allow('git push --dry-run origin HEAD:refs/heads/smoke-straz', 'Bash', WT);
  allow('git push origin --delete feat/x', 'Bash', MAIN);
  allow('git push -o ci.skip origin feat/x', 'Bash', MAIN);
  allow(`git -C ${fw(WT)} push`, 'Bash', MAIN);
  allow('git push origin feat/x 2>&1', 'Bash', MAIN);
  allow('grep "git push origin main" SYSTEM/pravidla/roly/ORCHESTRATOR.md', 'Bash', WT);
  allow('echo "git push origin main"', 'Bash', MAIN);
  allow('git pull origin main', 'Bash', WT);
  allow('git fetch origin main', 'Bash', WT);
  allow('git log origin/main..HEAD', 'Bash', WT);
  allow('git push origin feat/x', 'PowerShell', MAIN);
  // --all / --mirror posielajú aj lokálny main
  deny('push', 'git push --all origin', 'Bash', WT);
  deny('push', 'git push origin --all', 'Bash', WT);
  deny('push', 'git push --mirror origin', 'Bash', WT);
  deny('push', 'git push --branches origin', 'Bash', DET);
  deny('push', 'git push --all origin', 'PowerShell', WT);
  deny('push', 'git push --dry-run --mirror origin', 'Bash', UNK);
  allow('git push --tags origin', 'Bash', WT);
  allow('git push origin feat/x -- --all', 'Bash', WT, 'za -- je --all pozicny argument (refspec), nie prepinac');

  // --- 3. merge bez pripnutej hlavy -------------------------------------------------------------
  state.diff = '';
  deny('pin', 'gh pr merge 12 --merge', 'Bash');
  deny('pin', 'gh pr merge 12 --auto --squash', 'Bash');
  deny('pin', 'gh pr merge --merge', 'Bash');
  deny('pin', 'gh pr merge 12 --merge --match-head-commit', 'Bash', WT);         // chýba hodnota
  deny('pin', 'gh pr merge 12 --merge --match-head-commit=', 'Bash');
  deny('pin', 'gh pr merge 12 --body "--match-head-commit x"', 'Bash');          // len text v hodnote
  deny('pin', 'gh pr merge 12 --merge', 'PowerShell');
  deny('pin', 'gh  pr  merge 12', 'Bash');
  deny('pin', 'cd x; gh pr merge 12 --merge', 'Bash');
  allow('gh pr merge 12 --merge --match-head-commit "$sha"', 'Bash');
  allow('gh pr merge 12 --merge --match-head-commit abc123', 'Bash');
  allow('gh pr merge 12 --merge --match-head-commit=abc123', 'Bash');
  allow('sha=$(git rev-parse HEAD) && gh pr merge 12 --merge --match-head-commit "$sha"', 'Bash');
  allow('$sha = git rev-parse HEAD; gh pr merge 12 --merge --match-head-commit $sha', 'PowerShell');
  allow('gh pr merge --merge --match-head-commit abc', 'Bash', WT, 'merge aktualnej vetvy (bez cisla)');
  allow('gh pr merge 12 --merge --match-head-commit $(git rev-parse HEAD)', 'Bash', WT, 'hodnota je substitucia bez uvodzoviek');
  allow('gh pr merge 12 --merge --match-head-commit=$(git rev-parse HEAD)', 'Bash', WT, 'tvar =$(…)');
  allow('gh pr merge 12 --merge --match-head-commit "$(git rev-parse HEAD)"', 'Bash', WT, 'substitucia v uvodzovkach');
  allow('gh pr merge 12 --merge --match-head-commit (git rev-parse HEAD)', 'PowerShell', WT, 'PowerShell: (…) ako hodnota');
  allow('gh pr merge 12 --merge --match-head-commit $(git rev-parse HEAD)', 'PowerShell', WT, 'PowerShell: $(…) ako hodnota');
  allow('gh pr merge 12 --disable-auto', 'Bash', WT, 'zrusenie auto-merge nie je merge');
  allow('gh pr merge --disable-auto 12', 'PowerShell', WT);
  allow('gh pr merge 12 --disable-auto', 'Bash', WT, 'G7 sa pri --disable-auto nekontroluje');
  deny('pin', 'gh pr merge 12 --auto --disable-auto-x', 'Bash');
  allow('gh pr merge --help', 'Bash');
  allow('gh pr merge 12 --help', 'Bash');
  allow('gh pr view 12', 'Bash');
  allow('gh pr create --title "x"', 'Bash');
  allow('gh pr merge-queue', 'Bash');
  allow('git merge feat/x', 'Bash', WT);
  allow('echo "gh pr merge 12"', 'Bash');
  allow('gh pr checks 12', 'PowerShell');

  // --- 4. G7: zástupné číslo PR v pridaných riadkoch ---------------------------------------------
  const diff = (file, lines) => `diff --git a/${file} b/${file}\nindex 111..222 100644\n--- a/${file}\n+++ b/${file}\n@@ -1,3 +1,4 @@\n${lines.join('\n')}\n`;
  const PH = 'PR #?';
  const MERGE12 = 'gh pr merge 12 --merge --match-head-commit "$sha"';
  state.diffCalls.length = 0;
  state.diff = diff('SYSTEM/PLAN.md', [' stary riadok', `+- ✅ dávka — ${PH}`, ' dalsi']);
  deny('g7', MERGE12, 'Bash');
  eq(state.diffCalls, [['12', null, path.resolve(WT)]], 'gh pr diff dostal cislo PR a cwd');
  const r = M.decide(input(MERGE12), opts);
  ok(r.reason.includes('PR #12') && r.reason.includes('SYSTEM/PLAN.md') && r.reason.includes('otvor_pr.ps1'), `dovod G7 nazve PR a subor (${r.reason})`);
  deny('g7', MERGE12, 'PowerShell');
  state.diff = diff('SYSTEM/archiv/KRONIKA.md', [`+odsek ${PH}`]) + diff('SYSTEM/STAV.md', [`+riadok ${PH}`]);
  deny('g7', MERGE12, 'Bash');
  ok(M.decide(input(MERGE12), opts).reason.includes('SYSTEM/archiv/KRONIKA.md, SYSTEM/STAV.md'), 'G7: obidva subory v dovode');
  state.diff = diff('SYSTEM/archiv/DOGFOODING_vyriesene.md', [`+D-1 vyrieseny — ${PH}`]);
  deny('g7', MERGE12, 'Bash');
  state.diff = diff('SYSTEM/PLAN.md', [` kontext s ${PH}`, '+riadok s cislom PR #484']);                // PR # ? len v kontexte
  allow(MERGE12, 'Bash', WT, 'G7: zastupne cislo len v kontexte (nepridany riadok)');
  state.diff = diff('SYSTEM/PLAN.md', [`-stary riadok ${PH}`, '+novy riadok PR #484']);                   // odstránený riadok
  allow(MERGE12, 'Bash', WT, 'G7: zastupne cislo v odstranenom riadku');
  state.diff = diff('docs/HOOKY.md', [`+pravidlo: ${PH} sa dopĺňa skriptom`]);                          // iný súbor
  allow(MERGE12, 'Bash', WT, 'G7: zastupne cislo v inom subore');
  state.diff = diff('SYSTEM/PLAN.md', ['+riadok bez zastupneho cisla']);
  allow(MERGE12, 'Bash', WT, 'G7: ciste');
  state.diff = null;
  allow(MERGE12, 'Bash', WT, 'G7: gh pr diff zlyhal (null) = prepustit');
  state.diff = new Error('boom');
  allow(MERGE12, 'Bash', WT, 'G7: vynimka v gh pr diff = prepustit');
  state.diff = '';
  allow(MERGE12, 'Bash', WT, 'G7: prazdny diff = prepustit');
  state.diff = diff('SYSTEM/PLAN.md', [`+x ${PH}`]);
  state.diffCalls.length = 0;
  allow('gh pr merge --merge --match-head-commit abc', 'Bash', WT, 'G7: bez cisla PR sa nekontroluje');
  eq(state.diffCalls.length, 0, 'bez cisla PR sa gh pr diff nevola');
  allow('gh pr merge 12 --disable-auto', 'Bash', WT, 'G7: --disable-auto s pridanym zastupnym cislom v diffe');
  eq(state.diffCalls.length, 0, '--disable-auto nevola gh pr diff');
  allow('gh pr merge --merge --match-head-commit $sha 2>&1', 'PowerShell', WT, 'PowerShell: bez cisla PR a s 2>&1');
  eq(state.diffCalls.length, 0, 'PowerShell: 2>&1 nie je cislo PR (gh pr diff 1 sa nevola)');
  eq(code('gh pr merge 12 --merge', 'Bash'), 'pin', 'bez pripnutia je dovod pin, nie g7');
  eq(state.diffCalls.length, 0, 'pri odmietnuti pin sa gh pr diff nevola');
  deny('g7', 'gh pr merge https://github.com/o/r/pull/77 --merge --match-head-commit abc', 'Bash');
  eq(state.diffCalls.pop()[0], 'https://github.com/o/r/pull/77', 'URL sa podstrci do gh pr diff');
  deny('g7', 'gh pr merge 12 --repo o/r --merge --match-head-commit abc', 'Bash');
  eq(state.diffCalls.pop(), ['12', 'o/r', path.resolve(WT)], '--repo sa podstrci do gh pr diff');
  deny('g7', 'gh pr merge --merge 12 --match-head-commit abc', 'Bash');
  state.diff = null;

  // --- 5. runner bez -CloseWhenDone ------------------------------------------------------------
  allow('scripts\\run_su_tests.ps1 -CloseWhenDone', 'PowerShell');
  allow('.\\scripts\\run_su_tests.ps1 -CloseWhenDone', 'PowerShell');
  allow('./scripts/run_su_tests.ps1 -DryRun', 'Bash');
  allow('& .\\scripts\\run_su_tests.ps1 -CloseWhenDone', 'PowerShell');
  allow('powershell -NoProfile -File scripts\\run_su_tests.ps1 -CloseWhenDone', 'Bash');
  allow('powershell -NoProfile -ExecutionPolicy Bypass -File "C:\\APP DEV\\RUBY\\ENGINE\\scripts\\run_su_tests.ps1" -CloseWhenDone', 'Bash');
  allow('powershell -NoProfile -File scripts\\run_su_tests.ps1 -DryRun', 'Bash');
  allow('pwsh -File scripts/run_su_tests.ps1 -DryRun -CloseWhenDone', 'Bash');
  allow('powershell -NoProfile -Command "& \'scripts\\run_su_tests.ps1\' -CloseWhenDone"', 'Bash');
  allow('scripts\\run_su_tests.ps1 -Close', 'PowerShell', WT, 'skratka -Close');
  deny('runner', 'scripts\\run_su_tests.ps1', 'PowerShell');
  deny('runner', '.\\scripts\\run_su_tests.ps1', 'PowerShell');
  deny('runner', '& .\\scripts\\run_su_tests.ps1', 'PowerShell');
  deny('runner', '& "C:\\APP DEV\\RUBY\\ENGINE\\scripts\\run_su_tests.ps1"', 'PowerShell');
  deny('runner', './scripts/run_su_tests.ps1', 'Bash');
  deny('runner', 'powershell -NoProfile -File scripts\\run_su_tests.ps1', 'Bash');
  deny('runner', 'powershell -NoProfile -File scripts/run_su_tests.ps1 -QuitProbe', 'Bash');
  deny('runner', 'powershell -NoProfile -File scripts\\run_su_tests.ps1 -NeexistujuciPrepinac', 'Bash');
  deny('runner', 'powershell.exe -File scripts\\run_su_tests.ps1 -CloseWhenDone:$false', 'Bash');
  deny('runner', 'pwsh -NoProfile -File scripts/run_su_tests.ps1', 'PowerShell');
  deny('runner', 'powershell -NoProfile -Command "& \'scripts\\run_su_tests.ps1\'"', 'Bash');
  deny('runner', 'cd scripts; ./run_su_tests.ps1', 'Bash');
  deny('runner', 'Start-Sleep 1; scripts\\run_su_tests.ps1 -QuitMenu', 'PowerShell');
  deny('runner', 'powershell -NoProfile -File scripts\\run_su_tests.ps1 2>&1', 'Bash');
  allow('cat scripts/run_su_tests.ps1', 'Bash');
  allow('Get-Content scripts\\run_su_tests.ps1', 'PowerShell');
  allow('git add scripts/run_su_tests.ps1', 'Bash', WT);
  allow('grep -n CloseWhenDone scripts/run_su_tests.ps1', 'Bash');
  allow('echo "run_su_tests.ps1 bez prepinaca"', 'Bash');
  allow('powershell -NoProfile -File scripts\\run_js_tests.ps1', 'Bash');
  allow('powershell -NoProfile -Command "Get-Content scripts\\run_su_tests.ps1"', 'Bash');
  allow('ruby tests/pure/test_run_su_tests.rb', 'Bash');

  // --- nesúvisiace príkazy, iný nástroj a udalosť, zlý vstup (a vetva sa nezisťuje) -----------------
  state.branchCalls.length = 0; state.diffCalls.length = 0;
  for (const c of ['ls -la', 'npm test', 'ruby tests/run_all.rb', 'git status', 'git log -3', '', 'powershell -NoProfile -File scripts\\run_js_tests.ps1']) {
    allow(c, 'Bash', MAIN);
  }
  eq(state.branchCalls.length, 0, 'nesuvisiace prikazy nezistuju vetvu');
  eq(state.diffCalls.length, 0, 'nesuvisiace prikazy nevolaju gh');
  eq(M.decide(input('git commit -m x', 'Edit', MAIN), opts), null, 'iny nastroj');
  eq(M.decide(input('git commit -m x', 'Bash', MAIN, { hook_event_name: 'PostToolUse' }), opts), null, 'ina udalost');
  eq(M.decide({ hook_event_name: 'PreToolUse', tool_name: 'Bash', tool_input: {}, cwd: MAIN }, opts), null, 'bez command');
  eq(M.decide({ hook_event_name: 'PreToolUse', tool_name: 'Bash', tool_input: { command: 42 }, cwd: MAIN }, opts), null, 'command nie je text');
  eq(M.decide(null, opts), null, 'bez vstupu');
  eq(M.decide('x', opts), null, 'zly vstup');
  eq(M.decide(input('git commit -m x', 'Bash', MAIN, { agent_id: 'a1b2' }), opts).code, 'commit', 'subagent (agent_id) je tiez strazeny');
  eq(M.decide(input('git commit -m x', 'Bash', undefined, { cwd: undefined }), opts), null, 'bez cwd = vetva neznama = prepustit');
  eq(M.decide(input('git commit -m x'), { branchOf: () => { throw new Error('boom'); } }), null, 'vynimka v zistovani vetvy = prepustit');

  // --- tokenizér (jednotlivo) ------------------------------------------------------------------------
  const words = (c, sh) => M.tokenize(c, sh || 'bash').map((t) => (t.t === 'w' ? t.v : '<' + t.v + '>'));
  eq(words('git commit -m "a b" \'c d\''), ['git', 'commit', '-m', 'a b', 'c d'], 'uvodzovky');
  eq(words('a && b || c; d | e'), ['a', '<&&>', 'b', '<||>', 'c', '<;>', 'd', '<|>', 'e'], 'oddelovace');
  eq(words('sha=$(git rev-parse HEAD) && x'), ['sha=$(git rev-parse HEAD)', '<&&>', 'x'], 'substitucia $(…) je cast slova');
  eq(words('a --m $(git rev-parse HEAD) b'), ['a', '--m', '$(git rev-parse HEAD)', 'b'], 'substitucia ako hodnota');
  eq(words('a --m=$(f "x y" $(g)) b'), ['a', '--m=$(f "x y" $(g))', 'b'], 'vnorena substitucia s uvodzovkami');
  eq(words('if ($a) {git push}', 'powershell'), ['if', '($a)', '{', 'git', 'push', '}'], 'PowerShell: blok { … } sa rozdeli');
  eq(words('$h = @{a=1}; "${x}" stash@{0}', 'powershell'), ['$h', '=', '@{a=1}', '<;>', '${x}', 'stash@{0}'], 'PowerShell: @{ } a ${ } ostavaju slovom');
  eq(M.tokenize('x=$(git status) y', 'bash')[0].subs, ['git status'], 'vnutro substitucie sa zapamata');
  eq(words('(cd x && y); z'), ['<(>', 'cd', 'x', '<&&>', 'y', '<)>', '<;>', 'z'], 'bash: podshell ( … ) ostava oddelovac');
  eq(words('a --m (git rev-parse HEAD) b', 'powershell'), ['a', '--m', '(git rev-parse HEAD)', 'b'], 'PowerShell: ( … ) je vyraz');
  eq(words('a --m $(git rev-parse HEAD) 2>&1', 'powershell'), ['a', '--m', '$(git rev-parse HEAD)', '2>&1'], 'PowerShell: $(…) a 2>&1');
  eq(words('git commit -F - <<\'EOF\'\nbody git push origin main\nEOF\ngit status'), ['git', 'commit', '-F', '-', '<\n>', 'git', 'status'], 'heredoc telo sa vynecha');
  eq(words('cat <<< "a b"\nx'), ['cat', '<<<', 'a b', '<\n>', 'x'], 'here-string <<<');
  eq(words('cat <<EOF\nx y\nEOF\nz'), ['cat', '<\n>', 'z'], 'heredoc ostava heredoc');
  eq(M.stripRedirects(M.tokenize('a <<< "b c" d', 'bash').filter((t) => t.t === 'w')).map((t) => t.v), ['a', 'd'], 'stripRedirects: <<< aj s cielom');
  eq(words('echo a # komentar\nb'), ['echo', 'a', '<\n>', 'b'], 'komentar');
  eq(words('echo a#b'), ['echo', 'a#b'], '# uprostred slova nie je komentar');
  eq(words('git commit -m "a \\" b"'), ['git', 'commit', '-m', 'a " b'], 'bash: \\" v uvodzovkach');
  eq(words('git commit -m "it\'\'s"', 'powershell'), ['git', 'commit', '-m', "it''s"], 'PowerShell: apostrof v dvojitych uvodzovkach');
  eq(words("echo 'it''s'", 'powershell'), ['echo', "it's"], 'PowerShell: \'\' v jednoduchych');
  eq(words('& "C:\\x y\\git.exe" status', 'powershell'), ['&', 'C:\\x y\\git.exe', 'status'], 'PowerShell: & a cesta s medzerou');
  eq(words('git commit -m @\'\na; b && c\n\'@ ; git status', 'powershell'), ['git', 'commit', '-m', 'a; b && c', '<;>', 'git', 'status'], 'PowerShell here-string');
  eq(words('cd C:\\APP\\ DEV'), ['cd', 'C:\\APP DEV'], 'bash: \\ + medzera, cesta Windows');
  eq(words('git add a \\\n  b'), ['git', 'add', 'a', 'b'], 'bash: pokracovanie riadka');
  eq(words('x 2>&1 | y'), ['x', '2>&1', '<|>', 'y'], 'presmerovanie 2>&1');

  // --- pomocné ---------------------------------------------------------------------------------------------
  eq(M.stripRedirects(M.tokenize('a > f b 2>&1 c >>g d < in', 'bash').filter((t) => t.t === 'w')).map((t) => t.v), ['a', 'b', 'c', 'd'], 'stripRedirects');
  eq(M.resolveDir(null, 'relativna'), null, 'resolveDir: relativna bez zakladu');
  eq(M.resolveDir(WT, '$HOME'), null, 'resolveDir: premenna');
  eq(M.resolveDir(WT, '~'), null, 'resolveDir: ~');
  eq(M.resolveDir(WT, '..'), path.resolve(TMP), 'resolveDir: ..');
  if (process.platform === 'win32') eq(M.resolveDir(null, '/c/temp'), path.resolve('C:/temp'), 'resolveDir: /c/temp na Windows');
  eq(M.placeholderFiles(`diff --git a/SYSTEM/PLAN.md b/SYSTEM/PLAN.md\n+++ b/SYSTEM/PLAN.md\n+x ${PH}\n`), ['SYSTEM/PLAN.md'], 'placeholderFiles');
  ok(M.looksRelevant('git commit -m x') && M.looksRelevant('git -C d push') && M.looksRelevant('gh pr merge 1') && M.looksRelevant('x run_su_tests.ps1'), 'looksRelevant: ano');
  ok(!M.looksRelevant('ls') && !M.looksRelevant('git status') && !M.looksRelevant('gh pr view 1') && !M.looksRelevant('echo commit'), 'looksRelevant: nie');

  // --- zhoda zoznamu súborov G7 s hlavičkou scripts\otvor_pr.ps1 -----------------------------------------------
  const head = fs.readFileSync(path.join(ROOT, 'scripts', 'otvor_pr.ps1'), 'utf8').replace(/\r/g, '');
  const m5 = /#\s+5\.[\s\S]*?(?=\n#\s+6\.)/.exec(head);
  ok(m5, 'otvor_pr.ps1: hlavicka ma krok 5');
  const listed = (m5[0].match(/SYSTEM\/[A-Za-z_\/]+\.md/g) || []).sort();
  eq(listed, M.G7_FILES.slice().sort(), 'zoznam suborov G7 je zhodny so zoznamom v hlavicke otvor_pr.ps1');

  // --- tvar výstupu a skript ako proces ---------------------------------------------------------------------------
  const raw = JSON.stringify(input('git push origin main', 'Bash', WT));
  const outDeny = M.handle(raw, opts);
  const parsed = JSON.parse(outDeny);
  eq(Object.keys(parsed), ['hookSpecificOutput'], 'vystup: jediny kluc hookSpecificOutput');
  eq(parsed.hookSpecificOutput.hookEventName, 'PreToolUse', 'hookEventName');
  eq(parsed.hookSpecificOutput.permissionDecision, 'deny', 'permissionDecision');
  ok(parsed.hookSpecificOutput.permissionDecisionReason.includes('Push do main je zakázaný'), 'permissionDecisionReason s diakritikou po parse');
  ok(/^[\x20-\x7e]+$/.test(outDeny), 'vystup je ciste ASCII (diakritika ako \\u escape)');
  const REASON_CMDS = { commit: ['git commit -m x', MAIN], push: ['git push origin main', WT], pin: ['gh pr merge 1', WT], runner: ['scripts\\run_su_tests.ps1', WT] };
  for (const c of Object.keys(REASON_CMDS)) {
    const reason = JSON.parse(M.handle(JSON.stringify(input(REASON_CMDS[c][0], 'PowerShell', REASON_CMDS[c][1])), opts)).hookSpecificOutput.permissionDecisionReason;
    ok(reason.length > 40 && /docs\/HOOKY\.md/.test(reason) && !/ignoruj|ignore/i.test(reason), `dovod ${c}: vecny, odkaz na opis, nie rozkaz „ignoruj“`);
  }
  eq(M.handle(JSON.stringify(input('git status', 'Bash', MAIN)), opts), '', 'povolene = prazdny vystup');
  eq(M.handle(String.fromCharCode(0xfeff) + raw, opts) === outDeny, true, 'vstup s BOM');
  eq(M.handle('toto nie je json', opts), '', 'zly vstup = ticho');
  eq(M.handle('', opts), '', 'prazdny vstup = ticho');
  eq(M.handle(undefined, opts), '', 'undefined = ticho');

  // procesy: bez gh a gitu v PATH (fail-open), exit 0, nič na stderr
  const emptyBin = path.join(TMP, 'prazdny_bin');
  fs.mkdirSync(emptyBin);
  const env = {};
  for (const k of Object.keys(process.env)) if (!/^path$/i.test(k)) env[k] = process.env[k];
  env.PATH = emptyBin;
  delete env.CLAUDE_PROJECT_DIR;
  const spawn = (inputText, e) => cp.spawnSync(process.execPath, [SCRIPT], { input: inputText, env: e || env, encoding: 'utf8', timeout: 20000 });
  for (const [bad, label] of [['nie je json {', 'zly JSON'], ['', 'prazdny stdin'], ['null', 'JSON null'], ['[]', 'JSON pole'],
    [JSON.stringify(input('git status', 'Bash', TMP)), 'nesuvisiaci prikaz'],
    [JSON.stringify(input('git commit -m x', 'Bash', TMP)), 'commit bez gitu v PATH (vetva neznama)'],
    [JSON.stringify(input('git push', 'Bash', TMP)), 'bare push bez gitu v PATH'],
    [JSON.stringify(input('gh pr merge 5 --merge --match-head-commit abc', 'Bash', TMP)), 'merge bez gh v PATH (G7 prepusti)'],
    [JSON.stringify(input('git commit -m x', 'Bash', path.join(TMP, 'nie_je_priecinok'))), 'neexistujuci cwd']]) {
    const p = spawn(bad);
    eq([p.status, p.stdout, p.stderr], [0, '', ''], `proces: ${label} = prazdny stdout, exit 0`);
  }
  const pd = spawn(JSON.stringify(input('git push origin main', 'Bash', WT)));
  eq([pd.status, pd.stderr], [0, ''], 'proces: odmietnutie = exit 0, bez stderr');
  eq(JSON.parse(pd.stdout).hookSpecificOutput.permissionDecision, 'deny', 'proces: odmietnutie je JSON deny na stdout');
  const pr = spawn(JSON.stringify(input('scripts\\run_su_tests.ps1', 'PowerShell', WT)));
  eq(JSON.parse(pr.stdout).hookSpecificOutput.permissionDecision, 'deny', 'proces: runner bez -CloseWhenDone = deny');
  const pm = spawn(JSON.stringify(input('gh pr merge 5 --merge', 'PowerShell', WT)));
  eq(JSON.parse(pm.stdout).hookSpecificOutput.permissionDecision, 'deny', 'proces: merge bez pripnutia = deny');
  const t0 = Date.now();
  spawn(JSON.stringify(input('npm test', 'Bash', WT)));
  ok(Date.now() - t0 < 5000, 'nesuvisiaci prikaz skonci rychlo');

  // --- skutočný git nad dočasným repom (zisťovanie vetvy bez stubu) -----------------------------------------------
  const gitOk = cp.spawnSync('git', ['--version'], { encoding: 'utf8' }).status === 0;
  if (gitOk) {
    const git = (cwd, ...a) => {
      const g = cp.spawnSync('git', ['-C', cwd, '-c', 'user.name=T', '-c', 'user.email=t@e.x', '-c', 'commit.gpgsign=false', ...a], { encoding: 'utf8' });
      assert.strictEqual(g.status, 0, `git ${a.join(' ')}: ${g.stderr}`);
      return g.stdout.trim();
    };
    const repo = path.join(TMP, 'repo');
    fs.mkdirSync(repo);
    cp.spawnSync('git', ['init', '-q', '-b', 'main', repo]);
    const real = (command, cwd, tool) => {
      const p = cp.spawnSync(process.execPath, [SCRIPT], { input: JSON.stringify(input(command, tool || 'Bash', cwd)), encoding: 'utf8', timeout: 20000 });
      return p.status === 0 && p.stdout ? JSON.parse(p.stdout).hookSpecificOutput.permissionDecision : p.stdout;
    };
    const elsewhere = path.join(TMP, 'inde');
    fs.mkdirSync(elsewhere);
    eq(real('git commit --allow-empty -m x', repo), 'deny', 'skutocny git: prvy commit na main (bez commitov) = deny');
    eq(real(`git -C ${fw(repo)} commit -m x`, elsewhere), 'deny', 'skutocny git: git -C na main = deny');
    eq(real('git push', repo), 'deny', 'skutocny git: bare push na main = deny');
    eq(real('git commit --allow-empty -m x', repo, 'PowerShell'), 'deny', 'skutocny git: PowerShell');
    git(repo, 'commit', '-q', '--allow-empty', '-m', 'zaklad');
    eq(real('git commit -m x', repo), 'deny', 'skutocny git: main s commitom = deny');
    git(repo, 'switch', '-q', '-c', 'feat/a');
    eq(real('git commit -m x', repo), '', 'skutocny git: feat/a = povolene');
    eq(real('git push', repo), '', 'skutocny git: bare push na feat/a = povolene');
    eq(real(`git -C ${fw(repo)} commit -m x`, elsewhere), '', 'skutocny git: git -C na feat/a = povolene');
    eq(real('git push origin HEAD:main', repo), 'deny', 'skutocny git: HEAD:main aj z feat/a = deny');
    git(repo, 'checkout', '-q', '--detach');
    eq(real('git commit -m x', repo), '', 'skutocny git: odpojena hlava = povolene');
    eq(real('git push', repo), '', 'skutocny git: bare push na odpojenej hlave = povolene');
  }

  // --- zápis v .claude/settings.json ------------------------------------------------------------------------------------
  const settings = JSON.parse(fs.readFileSync(path.join(ROOT, '.claude', 'settings.json'), 'utf8'));
  const pre = (settings.hooks.PreToolUse || []).find((x) => x.matcher === 'Bash|PowerShell');
  ok(pre && pre.hooks.length === 1, 'PreToolUse s matcherom Bash|PowerShell je zapisany');
  const h = pre.hooks[0];
  eq(h.type, 'command', 'typ command');
  ok(!('if' in h), 'pole if sa nepouziva (zivo neoverene) - hook filtruje sam');
  ok(h.timeout > 12 && h.timeout <= 15, `timeout (${h.timeout} s) pod limitom, nad gh pr diff (8 s) + git (3 s)`);
  ok(/straz\.js/.test(h.command) && /^node -e "[^"\s$`]+"$/.test(h.command),
    'prikaz je node -e bez $, medzier a vnutornych uvodzoviek (Git Bash, PowerShell aj cmd)');
  const viaShell = (dir, command, cwd) => cp.spawnSync(h.command, [], {
    shell: true, cwd: TMP, input: JSON.stringify(input(command, 'Bash', cwd || WT)),
    env: Object.assign({}, env, { CLAUDE_PROJECT_DIR: dir, PATH: process.env.PATH }), encoding: 'utf8', timeout: 20000 });
  const sh = viaShell(ROOT, 'git status');
  eq([sh.status, sh.stdout], [0, ''], 'prikaz zo settings.json cez shell: povoleny prikaz = ticho, exit 0');
  const shd = viaShell(ROOT, 'git push origin main');
  eq(shd.status, 0, 'prikaz zo settings.json cez shell: exit 0 aj pri odmietnuti');
  eq(JSON.parse(shd.stdout).hookSpecificOutput.permissionDecision, 'deny', 'prikaz zo settings.json cez shell: odmietnutie');
  const noHook = viaShell(TMP, 'git push origin main');
  eq([noHook.status, noHook.stdout], [0, ''], 'bez skriptu (stara vetva) prikaz ticho skonci exit 0');
  const po = settings.hooks.PostToolUse.find((x) => /po_merge\.js/.test(JSON.stringify(x)));
  eq(po.matcher, 'Bash|PowerShell', 'po_merge.js reaguje aj na PowerShell (matcher)');
  ok(settings.hooks.PostToolUse.some((x) => x.matcher === 'Edit|Write') && settings.hooks.PostToolUse.some((x) => x.matcher === '*'), 'povodne hooky ostali');

  if (process.env.STRAZ_TABLE) {
    for (const [tool, cmd, , exp] of ROWS) console.log(`| ${tool} | \`${cmd.replace(/\|/g, '\\|')}\` | ${exp ? 'odmietnuté (' + exp + ')' : 'povolené'} |`);
  }
} finally {
  fs.rmSync(TMP, { recursive: true, force: true });
}

console.log(`OK test_straz.js — ${n} kontrol`);
