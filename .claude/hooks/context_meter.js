// Claude Code hook — UKAZOVATEĽ KONTEXTU orchestrátora (Noxun Engine, 26.9.2026).
// Hlavný agent nevidí, ako je zaplnené jeho kontextové okno, a kompresia ho zaskočí.
// Hook prečíta posledné `usage` hlavného agenta z transkriptu session a vloží mu
// jeden riadok (additionalContext), napr. „Kontext orchestrátora: 612k z 1M (61 %)."
//   UserPromptSubmit — vždy (pri každej správe Michala), keď je známe aspoň jedno usage;
//   PostToolUse      — len pri PRECHODE do vyššieho pásma (50/60/70/75/80/85/90/95 %);
//                      pokles (po kompresii) pásmo ticho resetne. Stav pásma je per
//                      session v os.tmpdir()/noxun_ctx/<session_id>.json a zapisuje ho aj
//                      UserPromptSubmit — nahlásené pásmo sa po nástroji už neopakuje;
//   subagent (vstup má agent_id) — ticho: subagent má vlastné okno, no hook dostáva
//                      cestu k transkriptu HLAVNEJ session.
// Overené naživo (26.9.2026): Claude Code zapisuje transkript s oneskorením — PostToolUse vidí
// usage o jednu odpoveď staršie (rozdiel rádovo tisícky tokenov) a v úplne novej session prvý
// nástroj ani prvá správa ešte žiadne usage nevidia (hook vtedy mlčí).
// Kontrakt: hook NIKDY nezlyhá nahlas — pri akejkoľvek chybe nič nevypíše a skončí exit 0.
// Príkaz v .claude/settings.json: node -e "try{require(<projekt>/.claude/hooks/context_meter.js).run()}catch(e){}"
// — bez $, medzier a vnútorných úvodzoviek, takže beží rovnako v Git Bash (tam ho Claude Code
// na Windows spúšťa), PowerShell aj cmd; a bez štartu PowerShellu (~0,4 s), lebo PostToolUse
// beží po KAŽDOM nástroji. Výstup je čisté ASCII (diakritika ako \uXXXX v JSON), aby ho
// neprekódoval žiadny shell ani kódová stránka konzoly.
// Testy: tests/js/test_context_meter.js
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const ONE_M = 1000000;
const DEFAULT_WINDOW = 200000;                  // neznámy model: opatrný predpoklad
// Natívne 1M modely (ID z transkriptu, aj s prefixom poskytovateľa, napr. „us.anthropic.").
// opus-4-8 podľa tabuľky modelov v Claude Code (native_1m) — na ňom beží `claude -p` na tomto PC;
// transkript nesie ID bez „[1m]", preto ho treba poznať po mene. opus-4-6/sonnet-4-6 majú 200k.
const NATIVE_1M = /(?:^|[^a-z0-9])claude-(?:opus-4-7|opus-4-8|opus-5|fable-5|sonnet-5)(?![0-9])/i;
const BANDS = [50, 60, 70, 75, 80, 85, 90, 95];
const FIRST_CHUNK = 512 * 1024;                  // chvost transkriptu: 512 kB, potom ×4 …
const MAX_CHUNK = 16 * 1024 * 1024;              // … najviac 16 MB (transkript má desiatky MB)
const STDIN_GUARD_MS = 3000;                     // poistka pod timeoutom hooku (5 s)

// Kontext = všetko, čo išlo do modelu, + jeho vlastný výstup (ten je v ďalšom kole vstupom).
function usageContext(u) {
  if (!u || typeof u !== 'object') return 0;
  const num = (v) => (typeof v === 'number' && Number.isFinite(v) && v > 0 ? v : 0);
  return num(u.input_tokens) + num(u.cache_read_input_tokens) +
         num(u.cache_creation_input_tokens) + num(u.output_tokens);
}

// Posledné usage HLAVNÉHO agenta z chvosta transkriptu (JSONL) → { ctx, model, compacted } | null.
// Číta od konca po kusoch; prvý riadok kusa môže byť useknutý, preto sa berie len vtedy,
// keď kus pokrýva celý súbor. Preskakuje vedľajšie vetvy (isSidechain), syntetické správy
// (model <synthetic> a nulové usage — napr. hláška limitu) a nečitateľné riadky.
// Keď je ZA posledným usage hranica kompresie (system/compact_boundary), platí jej
// compactMetadata.postTokens (stav po kompresii, kým nepríde prvá nová odpoveď) — inak by
// hook hneď po /compact hlásil starý, predkompresný stav. Model sa berie z usage pred ňou.
function lastUsage(file, firstChunk) {
  const fd = fs.openSync(file, 'r');
  try {
    const size = fs.fstatSync(fd).size;
    if (!size) return null;
    for (let chunk = firstChunk || FIRST_CHUNK; ; chunk *= 4) {
      const len = Math.min(chunk, size);
      const buf = Buffer.alloc(len);
      fs.readSync(fd, buf, 0, len, size - len);
      const lines = buf.toString('utf8').split('\n');
      let post;                                  // undefined = hranica kompresie zatiaľ nenájdená
      for (let i = lines.length - 1; i >= (len < size ? 1 : 0); i--) {
        const l = lines[i];
        const boundary = l.includes('"compact_boundary"');
        if (!boundary && !(l.includes('"usage"') && l.includes('"assistant"'))) continue;
        let o;
        try { o = JSON.parse(l); } catch (_) { continue; }
        if (!o || typeof o !== 'object' || o.isSidechain) continue;
        if (o.type === 'system' && o.subtype === 'compact_boundary') {
          if (post === undefined) {
            const p = o.compactMetadata && o.compactMetadata.postTokens;
            post = typeof p === 'number' && Number.isFinite(p) && p >= 0 ? p : null;
          }
          continue;
        }
        if (o.type !== 'assistant' || !o.message || !o.message.usage) continue;
        const model = typeof o.message.model === 'string' ? o.message.model : '';
        if (model === '<synthetic>') continue;
        const ctx = usageContext(o.message.usage);
        if (ctx <= 0) continue;
        if (post === undefined) return { ctx, model, compacted: false };
        return post === null ? null : { ctx: post, model, compacted: true };
      }
      if (len >= size || chunk >= MAX_CHUNK) {
        return typeof post === 'number' ? { ctx: post, model: '', compacted: true } : null;
      }
    }
  } finally {
    fs.closeSync(fd);
  }
}

// Veľkosť okna: env NOXUN_CTX_WINDOW (kladné číslo) má prednosť a berie sa doslovne; inak
// model s „[1m]" alebo natívne 1M model → 1M; inak 200k. Keď kontext automaticky odhadnuté
// okno prekročí, odhad bol zlý → 1M.
function windowFor(model, ctx, envValue) {
  if (envValue != null && String(envValue).trim() !== '') {
    const w = Number(String(envValue).trim());
    if (Number.isFinite(w) && w >= 1) return Math.floor(w);
  }
  const m = String(model || '');
  let win = /\[1m\]/i.test(m) || NATIVE_1M.test(m) ? ONE_M : DEFAULT_WINDOW;
  if (ctx > win) win = ONE_M;
  return win;
}

function fmtTokens(n) {
  const k = Math.round(n / 1000);
  if (k < 1000) return k + 'k';
  return (n / ONE_M).toFixed(2).replace(/\.?0+$/, '') + 'M';
}

function percent(ctx, win) { return Math.round((ctx / win) * 100); }

function bandOf(pct) {
  let b = 0;
  for (const x of BANDS) if (pct >= x) b = x;
  return b;
}

function messageFor(ctx, win) {
  const pct = percent(ctx, win);
  let line = `Kontext orchestrátora: ${fmtTokens(ctx)} z ${fmtTokens(win)} (${pct} %).`;
  if (pct >= 90) {
    line += ' Kompresia je blízko (auto pri ~97 %) — teraz zapíš rozpracovaný stav do repa/pamäte' +
            ' a navrhni Michalovi /compact na hranici dávky.';
  } else if (pct >= 75) {
    line += ' Zapíš rozpracované rozhodnutia a checklisty do repa/pamäte; ďalšie čítanie a kontroly' +
            ' deleguj subagentom.';
  }
  return { pct, line };
}

function defaultStateDir() { return path.join(os.tmpdir(), 'noxun_ctx'); }

function stateFile(dir, sessionId) {
  const id = String(sessionId || 'nosession').replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 120);
  return path.join(dir, id + '.json');
}

function readBand(file) {
  try {
    const b = JSON.parse(fs.readFileSync(file, 'utf8')).band;
    return typeof b === 'number' && Number.isFinite(b) ? b : 0;
  } catch (_) {
    return 0;                                    // prvý beh session
  }
}

function writeBand(file, band, pct) {
  try {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify({ band, pct, at: new Date().toISOString() }));
  } catch (_) { /* bez stavu sa najhoršie pásmo nahlási znova */ }
}

// Rozhodnutie pre jeden vstup hooku → { event, line, pct, band } | null (= ticho).
// opts: { env, stateDir, firstChunk } — len pre testy; hook beží s predvolenými.
// Súbežné PostToolUse (paralelné nástroje) môžu to isté pásmo výnimočne nahlásiť dvakrát —
// neškodné; zámok by stál viac než jeden riadok navyše.
function decide(input, opts) {
  const o = opts || {};
  if (!input || typeof input !== 'object' || input.agent_id) return null;
  const ev = input.hook_event_name;
  if (ev !== 'UserPromptSubmit' && ev !== 'PostToolUse') return null;
  if (typeof input.transcript_path !== 'string' || !input.transcript_path) return null;
  let u;
  try { u = lastUsage(input.transcript_path, o.firstChunk); } catch (_) { return null; }
  if (!u) return null;
  const env = o.env || process.env;
  const win = windowFor(u.model, u.ctx, env.NOXUN_CTX_WINDOW);
  const { pct, line } = messageFor(u.ctx, win);
  const band = bandOf(pct);
  const sf = stateFile(o.stateDir || defaultStateDir(), input.session_id);
  const prev = readBand(sf);
  if (band !== prev) writeBand(sf, band, pct);
  if (ev === 'UserPromptSubmit' || band > prev) return { event: ev, line, pct, band };
  return null;
}

// JSON výstup hooku; znaky mimo ASCII ako \uXXXX (JSON.parse ich vráti späť).
function formatOutput(r) {
  if (!r) return '';
  const out = { hookSpecificOutput: { hookEventName: r.event, additionalContext: r.line } };
  const s = JSON.stringify(out);
  let ascii = '';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    ascii += c < 0x7f ? s[i] : '\\u' + c.toString(16).padStart(4, '0');
  }
  return ascii;
}

// Surový stdin hooku → text na stdout ('' = ticho). Nikdy nevyhodí výnimku.
function handle(raw, opts) {
  try {
    let s = String(raw == null ? '' : raw);
    if (s.charCodeAt(0) === 0xfeff) s = s.slice(1);          // BOM na začiatku stdin
    const input = JSON.parse(s);
    return formatOutput(decide(input, opts));
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
  ONE_M, DEFAULT_WINDOW, BANDS, NATIVE_1M,
  usageContext, lastUsage, windowFor, fmtTokens, percent, bandOf, messageFor,
  defaultStateDir, stateFile, readBand, writeBand, decide, formatOutput, handle, run,
};

if (require.main === module) run();
