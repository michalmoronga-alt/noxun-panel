// Testy ukazovateľa kontextu orchestrátora (.claude/hooks/context_meter.js, 26.9.2026).
// Je to Claude Code hook, nie kód pluginu: z transkriptu session (JSONL) prečíta posledné
// usage hlavného agenta a vloží mu riadok „Kontext orchestrátora: 612k z 1M (61 %).".
// Všetko beží nad syntetickými transkriptmi v os.tmpdir() — skutočnú session nečíta.
'use strict';
const assert = require('node:assert');
const cp = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const SCRIPT = path.join(ROOT, '.claude', 'hooks', 'context_meter.js');
const M = require(SCRIPT);

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'noxun_ctx_test_'));
const STATE = path.join(TMP, 'state');
let fileNo = 0;

// Riadok transkriptu: odpoveď hlavného agenta s usage (kontext = súčet 4 polí).
function usageLine(ctx, extra){
  const e = extra || {};
  const cacheRead = Math.max(0, ctx - 1000);
  const obj = {
    type: 'assistant',
    message: {
      model: e.model === undefined ? 'claude-opus-5-5' : e.model,
      usage: { input_tokens: 10, cache_creation_input_tokens: 490, cache_read_input_tokens: cacheRead,
               output_tokens: Math.min(ctx, 1000) - 500 },
    },
    uuid: 'u' + (++fileNo),
  };
  if (ctx === 0) obj.message.usage = { input_tokens: 0, cache_creation_input_tokens: 0, cache_read_input_tokens: 0, output_tokens: 0 };
  if (e.sidechain) obj.isSidechain = true;
  if (e.pad) obj.padding = 'x'.repeat(e.pad);
  return JSON.stringify(obj);
}
const userLine = (text) => JSON.stringify({ type: 'user', message: { role: 'user', content: text } });
const boundaryLine = (post) => JSON.stringify({
  type: 'system', subtype: 'compact_boundary', content: 'Conversation compacted',
  compactMetadata: post === undefined ? { trigger: 'manual', preTokens: 900000 } : { trigger: 'auto', preTokens: 969055, postTokens: post },
});
function transcript(lines, raw){
  const p = path.join(TMP, `t${++fileNo}.jsonl`);
  fs.writeFileSync(p, raw !== undefined ? raw : lines.join('\n') + '\n');
  return p;
}

try {
  // --- usage → kontext -------------------------------------------------------------
  eq(M.usageContext({ input_tokens: 2, cache_read_input_tokens: 342429, cache_creation_input_tokens: 3894, output_tokens: 3503 }),
     349828, 'kontext = input + cache_read + cache_creation + output');
  eq(M.usageContext({ input_tokens: 5, output_tokens: -3, cache_read_input_tokens: 'x' }), 5,
     'chybajuce, zaporne a necislene polia sa nepocitaju');
  eq(M.usageContext(null), 0, 'bez usage = 0');

  // --- posledné usage hlavného agenta ------------------------------------------------
  let t = transcript([userLine('ahoj'), usageLine(300000), userLine('dalej'), usageLine(612000),
                      usageLine(50000, { sidechain: true }), userLine('koniec')]);
  eq(M.lastUsage(t), { ctx: 612000, model: 'claude-opus-5-5', compacted: false },
     'posledne usage hlavneho agenta; neskorsi sidechain (subagent) sa ignoruje');
  t = transcript([usageLine(612000), usageLine(0, { model: '<synthetic>' }), usageLine(0)]);
  eq(M.lastUsage(t).ctx, 612000, 'synteticka sprava (hlaska limitu) a nulove usage sa preskakuju');
  t = transcript([usageLine(612000), usageLine(5000, { model: '<synthetic>' })]);
  eq(M.lastUsage(t).ctx, 612000, 'synteticka sprava sa preskoci aj s nenulovym usage');
  t = transcript(null, usageLine(420000) + '\n' + usageLine(990000).slice(0, 80));
  eq(M.lastUsage(t).ctx, 420000, 'rozpisany posledny riadok (bez konca) sa preskoci');
  t = transcript([userLine('len otazka')]);
  eq(M.lastUsage(t), null, 'transkript bez odpovede = null');
  t = transcript(null, '');
  eq(M.lastUsage(t), null, 'prazdny transkript = null');

  // Useknutý prvý riadok chvosta: kus začína presne na „{" platného JSON, ktorý je v súbore
  // len koncom poškodeného riadka. Hook ho nesmie vziať — správne je 1234 z celého súboru.
  const tail = usageLine(990000);
  t = transcript(null, usageLine(1234) + '\n' + 'POSKODENE' + tail + '\n');
  eq(M.lastUsage(t, Buffer.byteLength(tail + '\n')).ctx, 1234,
     'prvy (mozno useknuty) riadok kusa sa neberie, kym kus nepokryva cely subor');
  t = transcript([usageLine(777000, { pad: 20000 }), userLine('x')]);
  eq(M.lastUsage(t, 256).ctx, 777000, 'dlhy riadok nad velkost kusa sa najde po zvacseni kusa');

  // Hranica kompresie za posledným usage → stav po kompresii (postTokens), model spred nej.
  t = transcript([usageLine(969000), boundaryLine(18041), userLine('suhrn')]);
  eq(M.lastUsage(t), { ctx: 18041, model: 'claude-opus-5-5', compacted: true },
     'hned po kompresii plati postTokens, nie stary stav 969k');
  t = transcript([usageLine(969000), boundaryLine(18041), usageLine(100676)]);
  eq(M.lastUsage(t), { ctx: 100676, model: 'claude-opus-5-5', compacted: false },
     'prva odpoved po kompresii ma prednost pred odhadom z hranice');
  t = transcript([usageLine(897000), boundaryLine(undefined)]);
  eq(M.lastUsage(t), null, 'hranica kompresie bez postTokens = stav nepoznam (ticho)');

  // --- veľkosť okna ------------------------------------------------------------------
  eq(M.windowFor('claude-opus-5-5', 1000, undefined), 1000000, 'opus-5-5 = 1M');
  eq(M.windowFor('claude-opus-5', 1000, undefined), 1000000, 'opus-5 = 1M');
  eq(M.windowFor('claude-fable-5-1', 1000, undefined), 1000000, 'fable-5 = 1M');
  eq(M.windowFor('claude-sonnet-5', 1000, undefined), 1000000, 'sonnet-5 = 1M');
  eq(M.windowFor('claude-opus-4-7', 1000, undefined), 1000000, 'opus-4-7 = 1M');
  eq(M.windowFor('claude-opus-4-8', 1000, undefined), 1000000, 'opus-4-8 = 1M (native_1m v tabulke modelov Claude Code)');
  eq(M.windowFor('claude-opus-4-6', 1000, undefined), 200000, 'opus-4-6 = 200k (1M len cez [1m])');
  eq(M.windowFor('us.anthropic.claude-opus-4-7-v1:0', 1000, undefined), 1000000, 'ID s prefixom poskytovatela');
  eq(M.windowFor('claude-sonnet-4-5-20250929', 1000, undefined), 200000, 'neznamy model = 200k (opatrne)');
  eq(M.windowFor('', 1000, undefined), 200000, 'bez modelu = 200k');
  eq(M.windowFor('claude-sonnet-4-5[1m]', 1000, undefined), 1000000, 'model s [1m] = 1M');
  eq(M.windowFor('claude-sonnet-4-5', 250000, undefined), 1000000, 'kontext nad odhadnutym oknom = 1M');
  eq(M.windowFor('claude-opus-5-5', 1000, '60000'), 60000, 'env NOXUN_CTX_WINDOW ma prednost');
  eq(M.windowFor('claude-sonnet-4-5', 250000, ' 60000 '), 60000, 'env sa berie doslovne (aj ked ho kontext prekroci)');
  eq(M.windowFor('claude-opus-5-5', 1000, ''), 1000000, 'prazdny env sa ignoruje');
  eq(M.windowFor('claude-opus-5-5', 1000, 'abc'), 1000000, 'necislo v env sa ignoruje');
  eq(M.windowFor('claude-opus-5-5', 1000, '0'), 1000000, 'nula v env sa ignoruje');

  // --- text riadku ---------------------------------------------------------------------
  eq(M.fmtTokens(612000), '612k', '612k');
  eq(M.fmtTokens(18041), '18k', '18k');
  eq(M.fmtTokens(200000), '200k', '200k');
  eq(M.fmtTokens(1000000), '1M', '1M');
  eq(M.fmtTokens(999600), '1M', 'zaokruhlenie na 1000k sa pise ako 1M');
  eq(M.fmtTokens(1250000), '1.25M', '1.25M');
  eq(M.messageFor(612000, 1000000), { pct: 61, line: 'Kontext orchestrátora: 612k z 1M (61 %).' },
     'zakladny riadok bez rady');
  let msg = M.messageFor(740000, 1000000).line;
  ok(!/repa\/pam/.test(msg), 'pod 75 % bez rady');
  msg = M.messageFor(760000, 1000000).line;
  ok(msg.startsWith('Kontext orchestrátora: 760k z 1M (76 %). ') && /repa\/pamäte/.test(msg) && /deleguj subagentom/.test(msg) &&
     !/compact/.test(msg), 'od 75 %: zapisat stav do repa/pamate a citanie delegovat');
  msg = M.messageFor(905000, 1000000).line;
  ok(/Kompresia je blízko/.test(msg) && /navrhni Michalovi \/compact na hranici dávky/.test(msg),
     'od 90 %: kompresia blizko, navrhnut Michalovi /compact na hranici davky');

  // --- pásma ---------------------------------------------------------------------------
  eq([0, 49, 50, 59, 60, 74, 75, 84, 85, 94, 95, 130].map(M.bandOf), [0, 0, 50, 50, 60, 70, 75, 80, 85, 90, 95, 95],
     'pasma 50/60/70/75/80/85/90/95');

  const OPTS = { stateDir: STATE, env: {} };
  const inp = (ev, file, extra) => Object.assign({ hook_event_name: ev, transcript_path: file, session_id: 'S1' }, extra || {});
  const at = (ctx) => transcript([userLine('x'), usageLine(ctx)]);
  const ups = (ctx, extra) => M.decide(inp('UserPromptSubmit', at(ctx), extra), OPTS);
  const ptu = (ctx, extra) => M.decide(inp('PostToolUse', at(ctx), extra), OPTS);

  eq(ups(300000).line, 'Kontext orchestrátora: 300k z 1M (30 %).', 'UserPromptSubmit hlasi vzdy (aj pod 50 %)');
  eq(ptu(310000), null, 'PostToolUse pod 50 % mlci');
  eq(ptu(520000).line, 'Kontext orchestrátora: 520k z 1M (52 %).', 'PostToolUse pri prechode do pasma 50');
  eq(ptu(540000), null, 'v tom istom pasme uz ticho');
  eq(ptu(610000).band, 60, 'prechod do pasma 60');
  eq(ups(615000).band, 60, 'UserPromptSubmit hlasi aj bez zmeny pasma');
  eq(ptu(700000).band, 70, 'prechod do pasma 70');
  const jump = ptu(910000);
  ok(jump && jump.band === 90 && /compact/.test(jump.line), 'skok cez viac pasiem = jedno hlasenie s radou');
  eq(ptu(100000), null, 'pokles (kompresia) je ticho…');
  eq(M.readBand(M.stateFile(STATE, 'S1')), 0, '…a pasmo sa resetne');
  eq(ptu(505000).band, 50, 'po resete sa pasmo 50 hlasi znova');
  eq(ups(780000).band, 75, 'UserPromptSubmit zapise pasmo…');
  eq(ptu(790000), null, '…ktore uz PostToolUse nezopakuje');
  eq(M.decide(inp('PostToolUse', at(520000), { session_id: 'S2' }), OPTS).band, 50, 'stav pasma je per session');

  // Subagent (agent_id) a iné udalosti → ticho.
  eq(ups(620000, { agent_id: 'a1b2', agent_type: 'general-purpose' }), null, 'subagent: UserPromptSubmit ticho');
  eq(ptu(990000, { session_id: 'S3', agent_id: 'a1b2' }), null, 'subagent: PostToolUse ticho');
  eq(M.decide(inp('Stop', at(620000)), OPTS), null, 'ina udalost = ticho');
  eq(M.decide(inp('UserPromptSubmit', path.join(TMP, 'neexistuje.jsonl')), OPTS), null, 'chybajuci transkript = ticho');
  eq(M.decide(null, OPTS), null, 'bez vstupu = ticho');

  // --- tvar výstupu ------------------------------------------------------------------
  const out = M.formatOutput({ event: 'PostToolUse', line: 'Kontext orchestrátora: 612k z 1M (61 %).' });
  eq(JSON.parse(out), { hookSpecificOutput: { hookEventName: 'PostToolUse', additionalContext: 'Kontext orchestrátora: 612k z 1M (61 %).' } },
     'JSON s hookSpecificOutput.hookEventName + additionalContext');
  ok(/^[\x20-\x7e]+$/.test(out), 'vystup je ciste ASCII (diakritika ako \\u escape) — shell ho neprekoduje');
  eq(M.formatOutput(null), '', 'ticho = prazdny vystup');
  const upsRaw = JSON.stringify(inp('UserPromptSubmit', at(612000), { session_id: 'H1' }));
  eq(JSON.parse(M.handle(upsRaw, OPTS)).hookSpecificOutput.hookEventName, 'UserPromptSubmit', 'handle: platny vstup');
  eq(JSON.parse(M.handle(String.fromCharCode(0xfeff) + upsRaw, OPTS)).hookSpecificOutput.additionalContext,
     'Kontext orchestrátora: 612k z 1M (61 %).', 'handle: vstup s BOM');
  eq(M.handle('toto nie je json', OPTS), '', 'handle: zly vstup = ticho');
  eq(M.handle('', OPTS), '', 'handle: prazdny vstup = ticho');

  // --- skript ako proces (stdin → stdout, vždy exit 0) -----------------------------------
  const env = Object.assign({}, process.env, { TMP, TEMP: TMP, TMPDIR: TMP });
  delete env.NOXUN_CTX_WINDOW;
  delete env.CLAUDE_PROJECT_DIR;
  const spawn = (input, args, extra) => cp.spawnSync(process.execPath, args || [SCRIPT],
    Object.assign({ input, env, encoding: 'utf8', timeout: 20000 }, extra || {}));
  for (const [bad, label] of [['nie je json {', 'zly JSON'], ['', 'prazdny stdin'],
    [JSON.stringify({ hook_event_name: 'UserPromptSubmit', transcript_path: path.join(TMP, 'nie.jsonl'), session_id: 'x' }), 'chybajuci transkript'],
    [JSON.stringify({ hook_event_name: 'UserPromptSubmit', transcript_path: 42 }), 'zly typ cesty']]) {
    const r = spawn(bad);
    eq([r.status, r.stdout, r.stderr], [0, '', ''], `proces: ${label} = prazdny stdout, exit 0`);
  }
  const good = spawn(JSON.stringify(inp('UserPromptSubmit', at(612000), { session_id: 'P1' })));
  eq(good.status, 0, 'proces: exit 0');
  eq(JSON.parse(good.stdout).hookSpecificOutput.additionalContext, 'Kontext orchestrátora: 612k z 1M (61 %).',
     'proces: stdout nesie riadok');

  // --- zápis v .claude/settings.json ---------------------------------------------------
  const settings = JSON.parse(fs.readFileSync(path.join(ROOT, '.claude', 'settings.json'), 'utf8'));
  const ptuHooks = settings.hooks.PostToolUse;
  const editWrite = ptuHooks.find((h) => h.matcher === 'Edit|Write');
  ok(editWrite && /post_edit_check\.ps1/.test(editWrite.hooks[0].command), 'povodny hook Edit|Write ostal');
  const all = ptuHooks.find((h) => h.matcher === '*');
  const upsEntry = (settings.hooks.UserPromptSubmit || [])[0];
  ok(all && upsEntry, 'PostToolUse (*) aj UserPromptSubmit su zapisane');
  const cmd = all.hooks[0].command;
  eq(upsEntry.hooks[0].command, cmd, 'obe udalosti volaju ten isty prikaz');
  ok(/context_meter\.js/.test(cmd) && /^node -e "[^"\s$`]+"$/.test(cmd),
     'prikaz je node -e bez $, medzier a vnutornych uvodzoviek (Git Bash, PowerShell aj cmd)');
  ok(all.hooks[0].timeout <= 10 && upsEntry.hooks[0].timeout <= 10, 'kratky timeout');
  const viaShell = (dir) => cp.spawnSync(cmd, [], {
    shell: true, cwd: TMP, input: JSON.stringify(inp('UserPromptSubmit', at(612000), { session_id: 'P2' })),
    env: Object.assign({}, env, { CLAUDE_PROJECT_DIR: dir }), encoding: 'utf8', timeout: 20000 });
  const sh = viaShell(ROOT);
  eq(sh.status, 0, 'prikaz zo settings.json cez shell: exit 0');
  eq(JSON.parse(sh.stdout).hookSpecificOutput.hookEventName, 'UserPromptSubmit', 'prikaz zo settings.json najde skript a vrati JSON');
  const noHook = viaShell(TMP);
  eq([noHook.status, noHook.stdout], [0, ''], 'bez skriptu (stara vetva) prikaz ticho skonci exit 0');
} finally {
  fs.rmSync(TMP, { recursive: true, force: true });
}

console.log(`OK test_context_meter.js — ${n} kontrol`);
