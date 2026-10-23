// Testy pripomienky po mergi (.claude/hooks/po_merge.js, P4a, 23.10.2026).
// Je to Claude Code hook, nie kód pluginu: PostToolUse na Bash — keď príkaz obsahuje
// `gh pr merge <N>`, vloží agentovi konštatovanie: či PR menil plugin, čo je nasadené v SketchUpe
// (značka %TEMP%\noxun_nasadene.txt z INSTALL_noxun_engine.ps1) a či je inštalácia mainu potrebná.
// `gh` a `git diff` sú stubnuté (opts.runGh, opts.pluginDiff); procesové testy bežia bez `gh` v PATH.
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
  // značka nasadenia v dočasnom súbore (null = súbor neexistuje)
  let markerNo = 0;
  const SHA = 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678';
  const marker = (o) => {
    const p = path.join(TMP, `marker_${++markerNo}.txt`);
    if (o !== null) {
      const m = Object.assign({ branch: 'main', sha: SHA, clean: 'yes', time: '2026-10-23T09:00:00', by: 'INSTALL_noxun_engine.ps1' }, o || {});
      fs.writeFileSync(p, Object.keys(m).map((k) => `${k}=${m[k]}`).join('\n') + '\n');
    }
    return p;
  };
  // stub git diff: počíta volania
  const diffStub = (result) => { const f = (sha, cwd) => { f.calls.push([sha, cwd]); return result; }; f.calls = []; return f; };
  const run = (command, v, o, extra) => M.decide(inp(command, extra), Object.assign({ runGh: stub(v) }, o || {}));

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

  // --- značka nasadenia: čítanie --------------------------------------------------------
  eq(M.readMarker(marker({}))?.sha, SHA, 'znacka sa precita');
  eq(M.readMarker(marker(null)), null, 'chybajuca znacka = null');
  const garbage = path.join(TMP, 'garbage.txt'); fs.writeFileSync(garbage, 'nieco ine\nbez klucov\n');
  eq(M.readMarker(garbage), null, 'znacka bez klucov = null');
  const bom = path.join(TMP, 'bom.txt'); fs.writeFileSync(bom, '﻿branch=x\nsha=abc\nclean=yes\n');
  eq(M.readMarker(bom)?.sha, 'abc', 'znacka s BOM');

  // --- povolený prípad: merge → kontext (dva riadky podľa značky) ---------------------------
  // (a) PR menil plugin → potrebná (aj keď je nasadený main a čistý)
  let g = stub(view(['SYSTEM/STAV.md', 'noxun_engine/ui/js/shell.js']));
  let d = diffStub('same');
  let msg = M.decide(inp('gh pr merge 123 --merge --match-head-commit X'), { runGh: g, markerPath: marker({}), pluginDiff: d });
  let lines = msg.split('\n');
  eq(lines[0], 'PR #123 zmergovaný, menil plugin: áno.', 'riadok 1: plugin áno');
  ok(lines[1].startsWith('Nasadený je main a1b2c3d (2026-10-23T09:00:00). '), `riadok 2: nasadeny stav (${lines[1]})`);
  ok(lines[1].includes('Inštalácia mainu je potrebná (PR menil plugin).'), 'PR menil plugin = potrebná');
  eq(lines[2], 'Hodnotenie úlohy pre PR #123 zatiaľ nie je zapísané.', 'riadok 3');
  eq(g.calls, [['123', TMP]], 'gh pr view dostal cislo PR a cwd z hooku');
  eq(d.calls.length, 0, 'pri zmene pluginu sa git diff ani nevola');
  // (b) main nasadený (plugin zhodný s origin/main) → nie je potrebná
  d = diffStub('same');
  msg = run('gh pr merge 124 --merge', view(['SYSTEM/PLAN.md', 'tests/pure/test_x.rb']), { markerPath: marker({}), pluginDiff: d });
  lines = msg.split('\n');
  eq(lines[0], 'PR #124 zmergovaný, menil plugin: nie.', 'riadok 1: plugin nie');
  ok(lines[1].includes('Inštalácia mainu nie je potrebná'), `main nasadeny = nie je potrebna (${lines[1]})`);
  eq(d.calls, [[SHA, TMP]], 'git diff dostal SHA zo znacky a cwd');
  // (c) nasadená vetva (plugin sa líši od mainu) → potrebná
  msg = run('gh pr merge 125 --merge', view(['SYSTEM/PLAN.md']), { markerPath: marker({ branch: 'feat/x' }), pluginDiff: diffStub('differs') });
  ok(msg.includes('Nasadený je feat/x a1b2c3d') && msg.includes('Inštalácia mainu je potrebná (nasadený kód pluginu sa líši od mainu).'), `vetva nasadena = potrebna (${msg})`);
  // (d) značka chýba → potrebná
  d = diffStub('same');
  msg = run('gh pr merge 126 --merge', view(['SYSTEM/PLAN.md']), { markerPath: marker(null), pluginDiff: d });
  ok(msg.includes('Stav nasadenia nie je zaznamenaný') && msg.includes('Inštalácia mainu je potrebná (stav nasadenia neznámy).'), `bez znacky = potrebna (${msg})`);
  eq(d.calls.length, 0, 'bez znacky sa git diff nevola');
  // (e) špinavý strom pri nasadení → potrebná
  msg = run('gh pr merge 127 --merge', view(['SYSTEM/PLAN.md']), { markerPath: marker({ clean: 'no' }), pluginDiff: diffStub('same') });
  ok(msg.includes('Inštalácia mainu je potrebná (nasadený strom nebol čistý'), `spinavy strom = potrebna (${msg})`);
  msg = run('gh pr merge 127 --merge', view(['SYSTEM/PLAN.md']), { markerPath: marker({ clean: 'unknown' }), pluginDiff: diffStub('same') });
  ok(msg.includes('je potrebná'), 'clean=unknown = potrebna');
  // (f) neznámy SHA / chyba git diff / prázdny sha → potrebná (stav neznámy)
  msg = run('gh pr merge 128 --merge', view(['SYSTEM/PLAN.md']), { markerPath: marker({}), pluginDiff: diffStub('unknown') });
  ok(msg.includes('Inštalácia mainu je potrebná (stav nasadenia neznámy).'), `diff unknown = potrebna (${msg})`);
  msg = run('gh pr merge 128 --merge', view(['SYSTEM/PLAN.md']), { markerPath: marker({ sha: '' }), pluginDiff: diffStub('same') });
  ok(msg.includes('Inštalácia mainu je potrebná (stav nasadenia neznámy).'), 'prazdny sha = potrebna');
  msg = run('gh pr merge 128 --merge', view(['SYSTEM/PLAN.md']), { markerPath: marker({}), pluginDiff: () => { throw new Error('boom'); } });
  ok(msg.includes('je potrebná (stav nasadenia neznámy)'), 'vynimka v git diff = potrebna (stav neznamy)');
  // (g) noxun_engine.rb je plugin
  msg = run('gh pr merge 129 --merge', view(['noxun_engine.rb']), { markerPath: marker({}), pluginDiff: diffStub('same') });
  ok(msg.includes('menil plugin: áno') && msg.includes('je potrebná'), 'noxun_engine.rb je plugin');
  // (h) veľký zoznam súborov
  const many = Array.from({ length: M.GH_FILES_CAP }, (_, i) => `docs/f${i}.md`);
  msg = run('gh pr merge 130 --merge', view(many), { markerPath: marker({}), pluginDiff: diffStub('same') });
  ok(msg.includes('môže byť neúplný') && msg.includes('overiť ručne') && msg.includes('je potrebná'), `velky zoznam bez pluginu = neuplny, potrebna (${msg})`);
  ok(msg.includes('Inštalácia mainu je potrebná (zoznam súborov PR je neúplný).') && !msg.includes('(PR menil plugin)'),
    `dovod v 2. riadku je neuplny zoznam, nie zmena pluginu (${msg})`);
  msg = run('gh pr merge 131 --merge', view(many.concat(['noxun_engine/main.rb'])), { markerPath: marker({}), pluginDiff: diffStub('same') });
  ok(msg.includes('menil plugin: áno'), 'velky zoznam s pluginom = ano');

  // --- zakázaný prípad: nič (a gh sa ani nevolá) --------------------------------------
  const silent = (input, label) => {
    const s = stub(view(['noxun_engine/main.rb']));
    eq(M.decide(input, { runGh: s, markerPath: marker({}) }), null, `${label}: ticho`);
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
  const mk = marker({});
  eq(run('gh pr merge 123 --merge', view(['noxun_engine/main.rb'], { mergedAt: null }), { markerPath: mk }), null, 'mergedAt null (auto-merge ceka)');
  eq(run('gh pr merge 123 --merge', view(['noxun_engine/main.rb'], { state: 'OPEN' }), { markerPath: mk }), null, 'stav OPEN');
  eq(run('gh pr merge 123 --merge', null, { markerPath: mk }), null, 'gh zlyhal (null)');
  eq(run('gh pr merge 123 --merge', {}, { markerPath: mk }), null, 'prazdna odpoved');
  ok(run('gh pr merge 123 --merge', { state: 'MERGED', mergedAt: 'x' }, { markerPath: mk, pluginDiff: diffStub('same') }).includes('menil plugin: nie'), 'bez files = bez pluginu (nie)');

  // --- tvar výstupu --------------------------------------------------------------------
  const raw = JSON.stringify(inp('gh pr merge 123 --merge'));
  const hopts = () => ({ runGh: stub(view(['noxun_engine/main.rb'])), markerPath: marker({}) });
  const out = M.handle(raw, hopts());
  const parsed = JSON.parse(out);
  eq(parsed.hookSpecificOutput.hookEventName, 'PostToolUse', 'hookEventName');
  ok(parsed.hookSpecificOutput.additionalContext.startsWith('PR #123 zmergovaný, menil plugin: áno.\n'), 'additionalContext nesie konstatovanie');
  ok(/^[\x20-\x7e]+$/.test(out), 'vystup je ciste ASCII (diakritika ako \\u escape)');
  ok(!/pripomen|musis|nezabudni|ihned/i.test(parsed.hookSpecificOutput.additionalContext), 'konstatovanie, nie rozkaz');
  eq(JSON.parse(M.handle(String.fromCharCode(0xfeff) + raw, hopts())).hookSpecificOutput.additionalContext.split('\n')[0],
    'PR #123 zmergovaný, menil plugin: áno.', 'vstup s BOM');
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

  // --- skutočný git diff (runPluginDiff) nad dočasným repom s bare origin ---------------
  // Cesta: fetch origin main + git diff --quiet <sha> origin/main -- noxun_engine noxun_engine.rb
  const gitOk = cp.spawnSync('git', ['--version'], { encoding: 'utf8' }).status === 0;
  if (gitOk) {
    const git = (cwd, ...a) => {
      const r = cp.spawnSync('git', ['-C', cwd, '-c', 'user.name=T', '-c', 'user.email=t@e.x', '-c', 'commit.gpgsign=false', ...a], { encoding: 'utf8' });
      assert.strictEqual(r.status, 0, `git ${a.join(' ')}: ${r.stderr}`);
      return r.stdout.trim();
    };
    const origin = path.join(TMP, 'origin.git');
    const work = path.join(TMP, 'work');
    fs.mkdirSync(work);
    cp.spawnSync('git', ['init', '-q', '--bare', origin]);
    cp.spawnSync('git', ['init', '-q', '-b', 'main', work]);
    git(work, 'remote', 'add', 'origin', origin);
    fs.mkdirSync(path.join(work, 'noxun_engine'));
    fs.writeFileSync(path.join(work, 'noxun_engine', 'main.rb'), 'v1\n');
    fs.writeFileSync(path.join(work, 'noxun_engine.rb'), 'loader\n');
    fs.writeFileSync(path.join(work, 'README.md'), 'r1\n');
    git(work, 'add', '-A'); git(work, 'commit', '-q', '-m', 'v1'); git(work, 'push', '-q', 'origin', 'main');
    const sha1 = git(work, 'rev-parse', 'HEAD');
    // main sa posunie len o docs -> plugin v sha1 == origin/main
    fs.writeFileSync(path.join(work, 'README.md'), 'r2\n');
    git(work, 'commit', '-q', '-am', 'docs'); git(work, 'push', '-q', 'origin', 'main');
    eq(M.runPluginDiff(sha1, work), 'same', 'runPluginDiff: docs-only posun maina = plugin rovnaky');
    // main sa posunie o zmenu pluginu -> sha1 sa lisi
    fs.writeFileSync(path.join(work, 'noxun_engine', 'main.rb'), 'v2\n');
    git(work, 'commit', '-q', '-am', 'plugin'); git(work, 'push', '-q', 'origin', 'main');
    eq(M.runPluginDiff(sha1, work), 'differs', 'runPluginDiff: zmena pluginu na maine = lisi sa');
    eq(M.runPluginDiff(git(work, 'rev-parse', 'HEAD'), work), 'same', 'runPluginDiff: nasadeny HEAD maina = rovnaky');
    eq(M.runPluginDiff('0123456789abcdef0123456789abcdef01234567', work), 'unknown', 'runPluginDiff: neznamy SHA = unknown');
    eq(M.runPluginDiff('nie-je-sha; rm -rf', work), 'unknown', 'runPluginDiff: neplatny SHA = unknown (bez volania gitu)');
    eq(M.runPluginDiff(sha1, path.join(TMP, 'nie_je_repo_priecinok')), 'unknown', 'runPluginDiff: zly cwd = unknown');
  }

  // --- zápis v .claude/settings.json ---------------------------------------------------
  const settings = JSON.parse(fs.readFileSync(path.join(ROOT, '.claude', 'settings.json'), 'utf8'));
  const entry = settings.hooks.PostToolUse.find((h) => h.matcher === 'Bash');
  ok(entry && entry.hooks.length === 1, 'PostToolUse s matcherom Bash je zapisany');
  const h = entry.hooks[0];
  eq(h.type, 'command', 'typ command');
  ok(!('if' in h), 'pole if sa nepouziva (zivo neoverene, moze minut zlozeny prikaz) - hook filtruje sam');
  ok(h.timeout > 12 && h.timeout <= 15, `timeout (${h.timeout} s) krátky, ale nad súčtom timeoutov gh+fetch+diff (12 s)`);
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
