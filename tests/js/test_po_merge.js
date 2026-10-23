// Testy pripomienky po mergi (.claude/hooks/po_merge.js, P4a, 23.10.2026).
// Je to Claude Code hook, nie kód pluginu: PostToolUse na Bash — keď príkaz obsahuje
// `gh pr merge <N>`, vloží agentovi konštatovanie, či PR menil plugin (treba inštalovať main).
// `gh` je stubnutý (opts.runGh); procesové testy bežia bez `gh` v PATH — hook musí mlčať, exit 0.
'use strict';
const assert = require('node:assert');
const cp = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const SCRIPT = path.join(ROOT, '.claude', 'hooks', 'po_merge.js');
const M = require(SCRIPT);

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'noxun_pomerge_test_'));
try {
  const inp = (command, extra) => Object.assign({
    hook_event_name: 'PostToolUse', tool_name: 'Bash', tool_input: { command }, cwd: TMP,
  }, extra || {});
  const view = (paths, extra) => Object.assign({
    state: 'MERGED', mergedAt: '2026-10-23T10:00:00Z', files: paths.map((p) => ({ path: p })),
  }, extra || {});
  // stub gh: vráti pripravený objekt a počíta volania
  const stub = (obj) => { const f = (number, cwd) => { f.calls.push([number, cwd]); return obj; }; f.calls = []; return f; };

  // --- číslo PR z príkazu -------------------------------------------------------------
  eq(M.mergedNumber('gh pr merge 123 --merge --match-head-commit abc'), '123', 'zakladny merge');
  eq(M.mergedNumber('sha=$(git rev-parse HEAD) && gh pr merge 478 --merge --match-head-commit "$sha"'), '478', 'zlozeny prikaz');
  eq(M.mergedNumber('gh pr merge --merge 99'), '99', 'prepinac pred cislom');
  eq(M.mergedNumber('gh pr merge https://github.com/o/r/pull/77 --merge'), '77', 'URL pull requestu');
  eq(M.mergedNumber('cd x; gh  pr  merge 5'), '5', 'viac medzier, za bodkociarkou');
  eq(M.mergedNumber('gh pr view 123'), null, 'gh pr view = nie merge');
  eq(M.mergedNumber('git merge feature-1'), null, 'git merge = nie merge');
  eq(M.mergedNumber('gh pr merge --merge'), null, 'merge bez cisla = ticho');
  eq(M.mergedNumber(''), null, 'prazdny prikaz');
  eq(M.mergedNumber(undefined), null, 'chybajuci prikaz');
  eq(M.mergedNumber(42), null, 'zly typ');

  // --- ktoré cesty sú plugin ----------------------------------------------------------
  for (const p of ['noxun_engine.rb', 'noxun_engine/main.rb', 'noxun_engine/ui/panel.html', 'noxun_engine\\core\\x.rb']) {
    ok(M.isPluginFile(p), `plugin: ${p}`);
  }
  for (const p of ['CLAUDE.md', 'scripts/run_su_tests.ps1', 'tests/js/test_po_merge.js', 'SYSTEM/STAV.md', 'docs/architecture/noxun_engine/x.md',
    'scripts/noxun_engine_x.rb', '.claude/hooks/po_merge.js', 'INSTALL_noxun_engine.ps1']) {
    ok(!M.isPluginFile(p), `nie plugin: ${p}`);
  }

  // --- povolený prípad: merge → kontext ---------------------------------------------
  let g = stub(view(['SYSTEM/STAV.md', 'noxun_engine/ui/js/shell.js']));
  let line = M.decide(inp('gh pr merge 123 --merge --match-head-commit X'), { runGh: g });
  eq(line, 'PR #123 zmergovaný. Zmenené súbory pluginu: áno — inštalácia mainu je potrebná (INSTALL_noxun_engine.ps1 z čerstvého main).'
    + ' Hodnotenie úlohy pre PR #123 zatiaľ nie je zapísané.', 'plugin sa menil → inštalácia je potrebná');
  eq(g.calls, [['123', TMP]], 'gh pr view dostal cislo PR a cwd z hooku');
  line = M.decide(inp('gh pr merge 124 --merge'), { runGh: stub(view(['SYSTEM/PLAN.md', 'tests/pure/test_x.rb'])) });
  ok(line.startsWith('PR #124 zmergovaný. Zmenené súbory pluginu: nie — inštalácia mainu nie je potrebná.'), `docs/testy → nie je potrebná: ${line}`);
  line = M.decide(inp('gh pr merge 125 --merge'), { runGh: stub(view(['noxun_engine.rb'])) });
  ok(line.includes('áno') && line.includes('je potrebná'), 'noxun_engine.rb je plugin');
  const many = Array.from({ length: M.GH_FILES_CAP }, (_, i) => `docs/f${i}.md`);
  line = M.decide(inp('gh pr merge 126 --merge'), { runGh: stub(view(many)) });
  ok(line.includes('môže byť neúplný') && line.includes('overiť ručne'), `velky zoznam bez pluginu = neuplny: ${line}`);
  line = M.decide(inp('gh pr merge 127 --merge'), { runGh: stub(view(many.concat(['noxun_engine/main.rb']))) });
  ok(line.includes('áno'), 'velky zoznam s pluginom = ano');

  // --- zakázaný prípad: nič (a gh sa ani nevolá) --------------------------------------
  const silent = (input, label) => {
    const s = stub(view(['noxun_engine/main.rb']));
    eq(M.decide(input, { runGh: s }), null, `${label}: ticho`);
    eq(s.calls.length, 0, `${label}: gh sa nevolal`);
  };
  silent(inp('gh pr view 123'), 'gh pr view');
  silent(inp('git merge feature'), 'git merge');
  silent(inp(''), 'prazdny prikaz');
  silent(inp('ls -la'), 'bezny prikaz');
  silent({ hook_event_name: 'PostToolUse', tool_name: 'Bash', tool_input: {} }, 'bez command');
  silent(inp('gh pr merge 123', { tool_name: 'Edit' }), 'ina nastroj');
  silent(inp('gh pr merge 123', { hook_event_name: 'PreToolUse' }), 'ina udalost');
  silent(inp('gh pr merge 123', { agent_id: 'a1b2' }), 'subagent');
  eq(M.decide(null, {}), null, 'bez vstupu');
  eq(M.decide('x', {}), null, 'zly vstup');

  // --- PR nie je zmergovaný / gh zlyhal → ticho --------------------------------------
  eq(M.decide(inp('gh pr merge 123 --merge'), { runGh: stub(view(['noxun_engine/main.rb'], { mergedAt: null })) }), null, 'mergedAt null (auto-merge ceka)');
  eq(M.decide(inp('gh pr merge 123 --merge'), { runGh: stub(view(['noxun_engine/main.rb'], { state: 'OPEN' })) }), null, 'stav OPEN');
  eq(M.decide(inp('gh pr merge 123 --merge'), { runGh: stub(null) }), null, 'gh zlyhal (null)');
  eq(M.decide(inp('gh pr merge 123 --merge'), { runGh: stub({}) }), null, 'prazdna odpoved');
  eq(M.decide(inp('gh pr merge 123 --merge'), { runGh: stub({ state: 'MERGED', mergedAt: 'x' }) }).includes('nie'), true, 'bez files = bez pluginu (nie)');

  // --- tvar výstupu --------------------------------------------------------------------
  const raw = JSON.stringify(inp('gh pr merge 123 --merge'));
  const out = M.handle(raw, { runGh: stub(view(['noxun_engine/main.rb'])) });
  const parsed = JSON.parse(out);
  eq(parsed.hookSpecificOutput.hookEventName, 'PostToolUse', 'hookEventName');
  ok(parsed.hookSpecificOutput.additionalContext.startsWith('PR #123 zmergovaný.'), 'additionalContext nesie konstatovanie');
  ok(/^[\x20-\x7e]+$/.test(out), 'vystup je ciste ASCII (diakritika ako \\u escape)');
  ok(!/pripomen|musis|nezabudni|ihned|treba/i.test(parsed.hookSpecificOutput.additionalContext.replace('je potrebná', '')),
    'konstatovanie, nie rozkaz');
  eq(M.handle(String.fromCharCode(0xfeff) + raw, { runGh: stub(view(['noxun_engine/main.rb'])) }) === out, true, 'vstup s BOM');
  eq(M.handle('toto nie je json', {}), '', 'zly vstup = ticho');
  eq(M.handle('', {}), '', 'prazdny vstup = ticho');
  eq(M.handle(JSON.stringify(inp('gh pr merge 1')), { runGh: () => { throw new Error('boom'); } }), '', 'vynimka v gh = ticho');

  // --- skript ako proces (stdin → stdout, vždy exit 0, bez gh v PATH) -------------------
  const emptyBin = path.join(TMP, 'prazdny_bin');
  fs.mkdirSync(emptyBin);
  const env = {};
  for (const k of Object.keys(process.env)) if (!/^path$/i.test(k)) env[k] = process.env[k];
  env.PATH = emptyBin;
  delete env.CLAUDE_PROJECT_DIR;
  const spawn = (input) => cp.spawnSync(process.execPath, [SCRIPT], { input, env, encoding: 'utf8', timeout: 20000 });
  for (const [bad, label] of [['nie je json {', 'zly JSON'], ['', 'prazdny stdin'],
    [JSON.stringify(inp('git status')), 'ne-merge prikaz'],
    [JSON.stringify(inp('gh pr merge 123 --merge')), 'merge bez gh v PATH']]) {
    const r = spawn(bad);
    eq([r.status, r.stdout, r.stderr], [0, '', ''], `proces: ${label} = prazdny stdout, exit 0`);
  }
  // rýchly odchod: ne-merge príkaz nesmie volať gh ani čakať (kontrola času, nie presná)
  const t0 = Date.now();
  spawn(JSON.stringify(inp('npm test')));
  ok(Date.now() - t0 < 5000, 'ne-merge prikaz skonci rychlo');

  // --- zápis v .claude/settings.json ---------------------------------------------------
  const settings = JSON.parse(fs.readFileSync(path.join(ROOT, '.claude', 'settings.json'), 'utf8'));
  const entry = settings.hooks.PostToolUse.find((h) => h.matcher === 'Bash');
  ok(entry && entry.hooks.length === 1, 'PostToolUse s matcherom Bash je zapisany');
  const h = entry.hooks[0];
  eq(h.type, 'command', 'typ command');
  eq(h.if, 'Bash(gh pr merge *)', 'filter if: len gh pr merge');
  ok(h.timeout > 8 && h.timeout <= 15, `timeout (${h.timeout} s) krátky, ale nad timeoutom gh (8 s)`);
  ok(/po_merge\.js/.test(h.command) && /^node -e "[^"\s$`]+"$/.test(h.command),
    'prikaz je node -e bez $, medzier a vnutornych uvodzoviek (Git Bash, PowerShell aj cmd)');
  const viaShell = (dir, command) => cp.spawnSync(h.command, [], {
    shell: true, cwd: TMP, input: JSON.stringify(inp(command)),
    env: Object.assign({}, env, { CLAUDE_PROJECT_DIR: dir, PATH: process.env.PATH }), encoding: 'utf8', timeout: 20000 });
  const sh = viaShell(ROOT, 'git status');
  eq([sh.status, sh.stdout], [0, ''], 'prikaz zo settings.json cez shell: ne-merge = ticho, exit 0');
  const noHook = viaShell(TMP, 'gh pr merge 1');
  eq([noHook.status, noHook.stdout], [0, ''], 'bez skriptu (stara vetva) prikaz ticho skonci exit 0');
  // povodne hooky ostali
  ok(settings.hooks.PostToolUse.some((x) => x.matcher === 'Edit|Write'), 'hook Edit|Write ostal');
  ok(settings.hooks.PostToolUse.some((x) => x.matcher === '*'), 'ukazovatel kontextu ostal');
} finally {
  fs.rmSync(TMP, { recursive: true, force: true });
}

console.log(`OK test_po_merge.js — ${n} kontrol`);
