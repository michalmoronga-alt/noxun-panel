// Claude Code hook — PRIPOMIENKA PO MERGI (Noxun Engine, P4a, 23.10.2026).
// PostToolUse na Bash: keď príkaz obsahuje `gh pr merge <N>`, hook zistí cez `gh pr view <N>`,
// či je PR naozaj zmergovaný a či menil plugin, prečíta značku nasadenia a vloží agentovi VECNÉ
// konštatovanie (additionalContext) — nie rozkaz, napr.:
//   „PR #478 zmergovaný, menil plugin: nie.
//    Nasadený je feat/x 1a2b3c4 (2026-10-23T14:02:11). Inštalácia mainu je potrebná (nasadený kód
//    pluginu sa líši od mainu).
//    Hodnotenie úlohy pre PR #478 zatiaľ nie je zapísané."
// Pravidlo, ktoré z toho plynie (SYSTEM/pravidla/roly/ORCHESTRATOR.md, Inštalácia mainu):
// main sa inštaluje po mergi, keď PR menil
// plugin (`noxun_engine/`, `noxun_engine.rb`) ALEBO keď je v SketchUpe nasadené niečo iné než main
// (runner in-SU testov, foto okien a export test nasadzujú kód vetvy a po sebe ho nevracajú).
// Nasadený stav hlási `INSTALL_noxun_engine.ps1` značkou %TEMP%\noxun_nasadene.txt (riadky kľúč=hodnota:
// branch, sha, clean, time, by). „Nie je potrebná" len keď značka je čitateľná, strom bol čistý a plugin
// v nasadenom SHA sa zhoduje s `origin/main` po mergi; pri akejkoľvek neistote „potrebná (stav nasadenia
// neznámy)". Záznam hodnotenia úlohy zavedie P5; dovtedy hook len konštatuje.
//
// Kontrakt: hook NIKDY neblokuje ani nezlyhá nahlas — pri akejkoľvek chybe (chýba gh, sieť, zlý
// vstup, PR nie je zmergovaný) nič nevypíše a skončí exit 0. Ne-merge príkaz opustí hneď (prvý krok je
// test `gh pr merge` v príkaze, bez gh a bez čítania súborov). Sieťové volania len pri merge:
// `gh pr view <N> --json files,mergedAt,state` (6 s) a pri PR bez zmeny pluginu s čistou značkou
// `git fetch origin main` (4 s) + `git diff` (2 s). Subagent (vstup má agent_id) — ticho, merge robí
// orchestrátor. Výstup je čisté ASCII (diakritika ako \uXXXX v JSON) — rovnaký formát ako context_meter.js.
// Filter v .claude/settings.json je len matcher „Bash" (pole `if` sa nepoužíva — živo neoverené a môže
// minúť zložený príkaz `sha=$(…) && gh pr merge …`); hook si príkaz filtruje sám.
// Príkaz v .claude/settings.json: node -e "try{require(<projekt>/.claude/hooks/po_merge.js).run()}catch(e){}"
// Testy: tests/js/test_po_merge.js
'use strict';
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { formatOutput } = require('./context_meter.js');

const GH_TIMEOUT_MS = 6000;
const FETCH_TIMEOUT_MS = 4000;
const DIFF_TIMEOUT_MS = 2000;
const STDIN_GUARD_MS = 13000;                    // poistka pod timeoutom hooku v settings.json (15 s)
const PLUGIN_PATHS = [/^noxun_engine\//, /^noxun_engine\.rb$/];
const PLUGIN_GIT_PATHS = ['noxun_engine', 'noxun_engine.rb'];
const GH_FILES_CAP = 100;                        // zoznam `files` o >= 100 položkách berieme ako možno skrátený (gh ho môže orezať)
const MARKER_NAME = 'noxun_nasadene.txt';

// Číslo PR z príkazu s `gh pr merge` (číslo alebo URL pull requestu); null, keď to nie je merge s číslom.
function mergedNumber(command) {
  if (typeof command !== 'string' || !/gh\s+pr\s+merge/.test(command)) return null;   // rýchly odchod
  const m = /(?:^|[\s;&|(])gh\s+pr\s+merge\s+(?:[^\n;&|]*?\s)?(?:https?:\/\/\S+\/pull\/)?(\d+)(?=[\s;&|)]|$)/.exec(command);
  return m ? m[1] : null;
}

function cwdOpt(cwd, base) {
  const opt = Object.assign({ encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] }, base);
  if (cwd && typeof cwd === 'string' && fs.existsSync(cwd)) opt.cwd = cwd;
  return opt;
}

// `gh pr view` → objekt z JSON alebo null (chyba, timeout, neplatný JSON).
function runGhView(number, cwd) {
  try {
    const out = cp.execFileSync('gh', ['pr', 'view', number, '--json', 'files,mergedAt,state'], cwdOpt(cwd, { timeout: GH_TIMEOUT_MS }));
    const j = JSON.parse(out);
    return j && typeof j === 'object' ? j : null;
  } catch (_) {
    return null;
  }
}

function isPluginFile(p) {
  return typeof p === 'string' && PLUGIN_PATHS.some((re) => re.test(p.replace(/\\/g, '/')));
}

// Značka nasadenia → { branch, sha, clean, time } alebo null (chýba / nečitateľná / bez kľúčov).
function readMarker(file) {
  try {
    let t = fs.readFileSync(file, 'utf8');
    if (t.charCodeAt(0) === 0xfeff) t = t.slice(1);
    const o = {};
    for (const line of t.split(/\r?\n/)) {
      const m = /^([a-z]+)=(.*)$/.exec(line);
      if (m) o[m[1]] = m[2].trim();
    }
    return o.sha !== undefined && o.clean !== undefined ? o : null;
  } catch (_) {
    return null;
  }
}

// Zhoduje sa plugin v nasadenom SHA s `origin/main` po mergi? 'same' | 'differs' | 'unknown'.
function runPluginDiff(sha, cwd) {
  if (!/^[0-9a-f]{7,40}$/i.test(sha)) return 'unknown';
  try {
    cp.execFileSync('git', ['fetch', 'origin', 'main', '--quiet'], cwdOpt(cwd, { timeout: FETCH_TIMEOUT_MS }));
  } catch (_) {
    return 'unknown';
  }
  try {
    cp.execFileSync('git', ['diff', '--quiet', sha, 'origin/main', '--'].concat(PLUGIN_GIT_PATHS), cwdOpt(cwd, { timeout: DIFF_TIMEOUT_MS }));
    return 'same';
  } catch (e) {
    return e && e.status === 1 ? 'differs' : 'unknown';
  }
}

// Druhý riadok: stav nasadenia + záver o inštalácii mainu.
function deployLine(changeReason, marker, pluginDiff) {   // changeReason: null | 'plugin' | 'incomplete'
  const dep = marker
    ? 'Nasadený je ' + (marker.branch || '?') + ' ' + (marker.sha ? marker.sha.slice(0, 7) : '?') + ' (' + (marker.time || '?') + '). '
    : 'Stav nasadenia nie je zaznamenaný (značka ' + MARKER_NAME + ' chýba). ';
  if (changeReason === 'plugin') return dep + 'Inštalácia mainu je potrebná (PR menil plugin).';
  if (changeReason === 'incomplete') return dep + 'Inštalácia mainu je potrebná (zoznam súborov PR je neúplný).';
  if (!marker || !marker.sha) return dep + 'Inštalácia mainu je potrebná (stav nasadenia neznámy).';
  if (marker.clean !== 'yes') return dep + 'Inštalácia mainu je potrebná (nasadený strom nebol čistý alebo je to neznáme).';
  const d = pluginDiff(marker.sha);
  if (d === 'same') return dep + 'Inštalácia mainu nie je potrebná (nasadený kód pluginu je rovnaký ako na maine).';
  if (d === 'differs') return dep + 'Inštalácia mainu je potrebná (nasadený kód pluginu sa líši od mainu).';
  return dep + 'Inštalácia mainu je potrebná (stav nasadenia neznámy).';
}

// Text konštatovania; null, keď PR nie je zmergovaný alebo údaje chýbajú.
// ctx: { marker, pluginDiff(sha) } — vstupy pre druhý riadok (v testoch podstrčené).
function messageFor(number, view, ctx) {
  if (!view || !view.mergedAt || view.state !== 'MERGED') return null;
  const c = ctx || {};
  const files = Array.isArray(view.files) ? view.files.map((f) => (f && f.path) || '') : [];
  const pluginChanged = files.some(isPluginFile);
  let first;
  if (pluginChanged) first = 'PR #' + number + ' zmergovaný, menil plugin: áno.';
  else if (files.length >= GH_FILES_CAP) first = 'PR #' + number + ' zmergovaný, menil plugin: v prvých ' + files.length + ' súboroch nie, zoznam môže byť neúplný — overiť ručne.';
  else first = 'PR #' + number + ' zmergovaný, menil plugin: nie.';
  // Zoznam súborov možno skrátený = berieme ako možnú zmenu pluginu (radšej inštalovať).
  const changeReason = pluginChanged ? 'plugin' : (files.length >= GH_FILES_CAP ? 'incomplete' : null);
  let second;
  try {
    second = deployLine(changeReason, c.marker || null, c.pluginDiff || (() => 'unknown'));
  } catch (_) {
    second = 'Inštalácia mainu je potrebná (stav nasadenia neznámy).';
  }
  return first + '\n' + second + '\nHodnotenie úlohy pre PR #' + number + ' zatiaľ nie je zapísané.';
}

// input: objekt hooku → text kontextu alebo null.
// opts (testy): runGh(number, cwd) → objekt | null · markerPath · pluginDiff(sha, cwd) → 'same'|'differs'|'unknown'.
function decide(input, opts) {
  const o = opts || {};
  if (!input || typeof input !== 'object' || input.agent_id) return null;
  if (input.hook_event_name !== 'PostToolUse' || input.tool_name !== 'Bash') return null;
  const command = input.tool_input && input.tool_input.command;
  const number = mergedNumber(command);
  if (!number) return null;
  const view = (o.runGh || runGhView)(number, input.cwd);
  if (!view || !view.mergedAt || view.state !== 'MERGED') return null;
  const marker = readMarker(o.markerPath || process.env.NOXUN_DEPLOY_MARKER || path.join(os.tmpdir(), MARKER_NAME));
  const diff = o.pluginDiff || runPluginDiff;
  return messageFor(number, view, { marker, pluginDiff: (sha) => diff(sha, input.cwd) });
}

// Surový stdin hooku → text na stdout ('' = ticho). Nikdy nevyhodí výnimku.
function handle(raw, opts) {
  try {
    let s = String(raw == null ? '' : raw);
    if (s.charCodeAt(0) === 0xfeff) s = s.slice(1);
    const line = decide(JSON.parse(s), opts);
    return line ? formatOutput({ event: 'PostToolUse', line }) : '';
  } catch (_) {
    return '';
  }
}

// Vstupný bod hooku: stdin → handle → stdout, vždy exit 0.
function run() {
  try {
    process.on('uncaughtException', () => process.exit(0));
    process.stdout.on('error', () => { /* Claude Code už nečíta — ticho */ });
    const guard = setTimeout(() => process.exit(0), STDIN_GUARD_MS);
    if (guard.unref) guard.unref();
    let raw = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (d) => { raw += d; });
    process.stdin.on('error', () => { process.exitCode = 0; });
    process.stdin.on('end', () => {
      const out = handle(raw);
      if (out) process.stdout.write(out);
      process.exitCode = 0;
    });
  } catch (_) {
    process.exitCode = 0;
  }
}

module.exports = {
  mergedNumber, runGhView, isPluginFile, readMarker, runPluginDiff, deployLine, messageFor, decide, handle, run,
  GH_FILES_CAP, MARKER_NAME,
};

if (require.main === module) run();
