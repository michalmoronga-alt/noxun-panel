// Claude Code hook — PRIPOMIENKA PO MERGI (Noxun Engine, P4a, 23.10.2026).
// PostToolUse na Bash: keď príkaz obsahuje `gh pr merge <N>`, hook zistí cez `gh pr view <N>`,
// či je PR naozaj zmergovaný a či menil plugin, a vloží agentovi VECNÉ konštatovanie
// (additionalContext) — nie rozkaz, napr.:
//   „PR #478 zmergovaný. Zmenené súbory pluginu: nie — inštalácia mainu nie je potrebná.
//    Hodnotenie úlohy pre PR #478 zatiaľ nie je zapísané."
// Pravidlo, ktoré z toho plynie (CLAUDE.md, Verzia a uzáver): main sa inštaluje po mergi LEN keď PR
// mení plugin (`noxun_engine/`, `noxun_engine.rb`). Záznam hodnotenia úlohy zavedie P5; dovtedy hook
// len konštatuje.
//
// Kontrakt: hook NIKDY neblokuje ani nezlyhá nahlas — pri akejkoľvek chybe (chýba gh, sieť, zlý
// vstup, PR nie je zmergovaný) nič nevypíše a skončí exit 0. Ne-merge príkaz opustí hneď (jeden
// podreťazec, bez volania gh). Jediné sieťové volanie: `gh pr view <N> --json files,mergedAt,state`
// s timeoutom 8 s. Subagent (vstup má agent_id) — ticho, merge robí orchestrátor.
// Výstup je čisté ASCII (diakritika ako \uXXXX v JSON) — rovnaký formát ako context_meter.js.
// Filter v .claude/settings.json: matcher „Bash" + `if: Bash(gh pr merge *)`; `if` je podľa dokumentácie
// Claude Code best-effort, preto hook filtruje sám.
// Príkaz v .claude/settings.json: node -e "try{require(<projekt>/.claude/hooks/po_merge.js).run()}catch(e){}"
// Testy: tests/js/test_po_merge.js
'use strict';
const cp = require('child_process');
const fs = require('fs');
const { formatOutput } = require('./context_meter.js');

const GH_TIMEOUT_MS = 8000;
const STDIN_GUARD_MS = 10000;                    // poistka pod timeoutom hooku v settings.json (12 s)
const PLUGIN_PATHS = [/^noxun_engine\//, /^noxun_engine\.rb$/];
const GH_FILES_CAP = 100;                        // zoznam `files` o >= 100 položkách berieme ako možno skrátený (gh ho môže orezať)

// Číslo PR z príkazu s `gh pr merge` (číslo alebo URL pull requestu); null, keď to nie je merge s číslom.
function mergedNumber(command) {
  if (typeof command !== 'string' || !command.includes('merge')) return null;   // rýchly odchod (bez regexu a bez gh)
  const m = /(?:^|[\s;&|(])gh\s+pr\s+merge\s+(?:[^\n;&|]*?\s)?(?:https?:\/\/\S+\/pull\/)?(\d+)(?=[\s;&|)]|$)/.exec(command);
  return m ? m[1] : null;
}

// `gh pr view` → objekt z JSON alebo null (chyba, timeout, neplatný JSON).
function runGhView(number, cwd) {
  try {
    const opt = { encoding: 'utf8', timeout: GH_TIMEOUT_MS, windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] };
    if (cwd && typeof cwd === 'string' && fs.existsSync(cwd)) opt.cwd = cwd;
    const out = cp.execFileSync('gh', ['pr', 'view', number, '--json', 'files,mergedAt,state'], opt);
    const j = JSON.parse(out);
    return j && typeof j === 'object' ? j : null;
  } catch (_) {
    return null;
  }
}

function isPluginFile(p) {
  return typeof p === 'string' && PLUGIN_PATHS.some((re) => re.test(p.replace(/\\/g, '/')));
}

// Riadok konštatovania; null, keď PR nie je zmergovaný alebo údaje chýbajú.
function messageFor(number, view) {
  if (!view || !view.mergedAt || view.state !== 'MERGED') return null;
  const files = Array.isArray(view.files) ? view.files.map((f) => (f && f.path) || '') : [];
  const plugin = files.filter(isPluginFile);
  let part;
  if (plugin.length > 0) {
    part = 'Zmenené súbory pluginu: áno — inštalácia mainu je potrebná (INSTALL_noxun_engine.ps1 z čerstvého main).';
  } else if (files.length >= GH_FILES_CAP) {
    part = 'Zmenené súbory pluginu: v prvých ' + files.length + ' súboroch nie, zoznam môže byť neúplný — zmenu pluginu overiť ručne.';
  } else {
    part = 'Zmenené súbory pluginu: nie — inštalácia mainu nie je potrebná.';
  }
  return 'PR #' + number + ' zmergovaný. ' + part + ' Hodnotenie úlohy pre PR #' + number + ' zatiaľ nie je zapísané.';
}

// input: objekt hooku → riadok kontextu alebo null. opts.runGh (test): (number, cwd) → objekt | null.
function decide(input, opts) {
  const o = opts || {};
  if (!input || typeof input !== 'object' || input.agent_id) return null;
  if (input.hook_event_name !== 'PostToolUse' || input.tool_name !== 'Bash') return null;
  const command = input.tool_input && input.tool_input.command;
  const number = mergedNumber(command);
  if (!number) return null;
  const view = (o.runGh || runGhView)(number, input.cwd);
  return messageFor(number, view);
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

module.exports = { mergedNumber, runGhView, isPluginFile, messageFor, decide, handle, run, GH_FILES_CAP };

if (require.main === module) run();
