// Claude Code hook — STRÁŽ PRED PRÍKAZOM (Noxun Engine, P4b, 27.10.2026).
// PreToolUse na nástroje Bash a PowerShell (príkaz je v tool_input.command). Platí pre hlavné okno AJ pre
// subagentov (implementátor tiež nesmie commitnúť do main). Odmietne päť vecí, ktoré sa nesmú stať ani raz:
//   1. commit do vetvy main:  `git commit` (aj `git -C <dir> commit`, aj za `cd <dir> &&` / `;` / `Set-Location`),
//      keď je v cieľovom priečinku vetva main (zisťuje `git -C <dir> symbolic-ref -q HEAD` — ako `rev-parse
//      --abbrev-ref HEAD`, ale funguje aj pred prvým commitom a nevráti dvojznačné `heads/main`; odpojená hlava
//      a iná vetva = povolené);
//   2. push do main:  `git push` s cieľom main (`origin main`, `HEAD:main`, `x:main`, `x:refs/heads/main`, aj s `+` a
//      `--force*`, aj `--dry-run`), a `git push` / `git push origin` bez refspecu, keď je aktuálna vetva main; vždy aj
//      `--all` / `--branches` / `--mirror` (posielajú aj lokálny main; `--tags` ostáva povolené);
//   3. `gh pr merge` bez `--match-head-commit` (aj tvar `--match-head-commit=<sha>`; obsah hodnoty sa nekontroluje;
//      `--disable-auto` je zrušenie auto-merge, nie merge → povolené);
//   4. G7: pri `gh pr merge <N> … --match-head-commit …` zistí `gh pr diff <N>` a odmietne, keď PRIDANÉ riadky
//      v súboroch, kde `scripts\otvor_pr.ps1` dopĺňa číslo PR (G7_FILES), ešte obsahujú zástupné číslo PR;
//   5. spustenie `scripts\run_su_tests.ps1` bez `-CloseWhenDone` (s `-DryRun` povolené; abreviácie parametrov
//      ako PowerShell: `-Close…`, `-Dry…`; `:$false` / `:0` prepínač vypína).
//
// Formát odmietnutia (overené v https://code.claude.com/docs/en/hooks, 27.10.2026): exit 0 a na stdout JSON
//   {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}
// `permissionDecisionReason` je dôvod, ktorý uvidí Claude. Zvolená je táto štruktúrovaná cesta (nie exit 2 so stderr):
// dokumentácia ju uvádza ako štruktúrovaný výstup pre exit 0, zhoduje sa s ostatnými hookmi repa (JSON na stdout,
// vždy exit 0, výstup ako čisté ASCII — diakritika ako \uXXXX) a hook tak nikdy nekončí chybovým kódom ani pri vlastnej
// chybe. Dokumentácia zakazuje miešať oba spôsoby v jednom hooku: tento používa výlučne JSON a vždy exit 0.
//
// Kontrakt: hook je RÝCHLA SPÄTNÁ VÄZBA, posledná brána je CI a ochrana vetvy na GitHube. Pri akejkoľvek vlastnej
// chybe (zlý JSON, chýba git/gh, sieť, timeout, neznámy priečinok) príkaz PUSTÍ (fail-open), nič nevypíše a skončí
// exit 0. Falošné odmietnutie je horšie než prepustenie: text v reťazcoch a v telách heredoc / PowerShell
// here-string (správa commitu, --body, echo, grep "git push origin main") sa za príkaz nepovažuje. Príkaz sa rozloží
// na jednoduché príkazy (`;`, `&&`, `||`, `|`, `&`, nový riadok, bashový podshell `( … )`) a posudzuje sa len prvé slovo
// každého z nich (po prefixoch `VAR=x`, `&`, `env`, `time`, `sudo`, v PowerShelli aj `if (…)`, `{`, `}` …).
// Substitúcia `$( … )` (v PowerShelli aj `( … )`) ostáva súčasťou slova (hodnota argumentu, napr.
// `--match-head-commit $(git rev-parse HEAD)`), no jej vnútro sa navyše posúdi samostatne ako príkaz.
// `bash -c "…"` a `powershell -Command "…"` sa rozoberú vnorene (najviac dve úrovne). Nesúvisiaci príkaz opustí hneď
// (lacný textový test, bez spúšťania procesov).
// Známe medze (prepustí sa): aliasy gitu (`git ci`), príkaz vnútri `eval` / `Invoke-Expression`, premenná
// ako priečinok (`cd $d`), po `git switch` / `checkout` / `rebase` v tom istom príkaze sa vetva nepredpovedá,
// príkaz vnorený hlbšie než dve úrovne, `git push origin feat/$(…)` sa posudzuje podľa textu bez substitúcie,
// PowerShell `if($x){git push origin main}` / `if ($x){git push origin main}` (bez medzery pred alebo za zátvorkou) a
// `$out = git push origin main 2>&1` (priradenie bez zátvoriek) sa prepúšťajú; `--disable-auto` sa hľadá v každom slove, takže
// `gh pr merge 12 --merge -b "--disable-auto"` aj `--body --disable-auto` prejdú; vnútri `"$( … )"` v úvodzovkách sa `<<<` stále
// berie ako heredoc, takže pri novom riadku v takej substitúcii sa zvyšok príkazu neposúdi.
//
// Príkaz v .claude/settings.json (PreToolUse, matcher „Bash|PowerShell“, timeout 15 s):
//   node -e "try{require(<projekt>/.claude/hooks/straz.js).run()}catch(e){}"
// Sieťové volanie je len pri merge s číslom PR: `gh pr diff <N>` (8 s); zisťovanie vetvy `git symbolic-ref` (3 s).
// Opis hooku: docs/HOOKY.md · Testy: tests/js/test_straz.js
'use strict';
const cp = require('child_process');
const fs = require('fs');
const path = require('path');

const GH_TIMEOUT_MS = 8000;
const GIT_TIMEOUT_MS = 3000;
const STDIN_GUARD_MS = 13000;                    // poistka pod timeoutom hooku v settings.json (15 s)
const PROTECTED_BRANCH = 'main';
// Súbory, v ktorých scripts\otvor_pr.ps1 dopĺňa číslo PR (zhodu s hlavičkou skriptu stráži test). `*` = jeden úsek cesty
// (záznam dávky bloku je samostatný súbor kronika/<DAVKA>.md).
const G7_FILES = ['SYSTEM/PLAN.md', 'SYSTEM/STAV.md', 'SYSTEM/archiv/KRONIKA.md', 'SYSTEM/archiv/DOGFOODING_vyriesene.md',
  'SYSTEM/zdroje/bloky/*/kronika/*.md'];
const G7_PATTERNS = G7_FILES.map((f) => new RegExp('^' + f.split('*').map((s) => s.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('[^/]+') + '$'));
const PLACEHOLDER = 'PR #?';
const RUNNER = 'run_su_tests.ps1';
const WRAPPERS = new Set(['env', 'time', 'command', 'builtin', 'exec', 'nohup', 'sudo', 'nice', '!', '{', '}', 'then', 'do', 'else', 'elif',
  'if', 'while', 'until', '&', 'call']);
const CONTROL = new Set(['if', 'elseif', 'while', 'until', 'foreach', 'for', 'switch']);
const CD_NAMES = new Set(['cd', 'chdir', 'set-location', 'sl', 'pushd', 'push-location']);
const POP_NAMES = new Set(['popd', 'pop-location']);
const BRANCH_CHANGERS = new Set(['switch', 'checkout', 'rebase']);
const PUSH_VALUE_OPTS = new Set(['-o', '--push-option', '--repo', '--receive-pack', '--exec']);
const MERGE_VALUE_OPTS = new Set(['-b', '--body', '-F', '--body-file', '-t', '--subject', '-A', '--author-email', '-R', '--repo', '--match-head-commit']);

const REASONS = {
  commit: () => 'Commit do vetvy main je zakázaný (AGENTS.md, Zákazy: žiadne priame commity do main). Zmena patrí do vlastnej vetvy ' +
    'a cez PR; vytvor ju napr. príkazom git switch -c feat/<popis> a commituj tam. Opis stráže: docs/HOOKY.md.',
  push: () => 'Push do main je zakázaný (AGENTS.md, Zákazy: do main vedie len PR a merge orchestrátora po bránach). Pushni vetvu práce ' +
    '(git push origin HEAD, keď nie si na main) a zmenu pošli cez PR. Opis stráže: docs/HOOKY.md.',
  pin: () => 'gh pr merge bez --match-head-commit je zakázaný: merge musí pripnúť presne tú hlavu, ktorá prešla bránami (ochrana pred ' +
    'pretekom s cudzím pushom). Postup: sha=$(gh pr view <N> --json headRefOid -q .headRefOid) a potom gh pr merge <N> --merge --match-head-commit "$sha" ' +
    '(skill codex-po-pr, krok merge). Opis stráže: docs/HOOKY.md.',
  g7: (d) => 'V PR #' + d.number + ' zostalo v pridaných riadkoch zástupné číslo PR (' + PLACEHOLDER + ') v súbore ' + d.files.join(', ') +
    '. Číslo dopĺňa scripts\\otvor_pr.ps1 samostatným commitom; ak PR vznikol ručne, nahraď zástupné číslo číslom PR, pushni, počkaj ' +
    'na CI a merge zopakuj s novou hlavou. Opis stráže: docs/HOOKY.md.',
  runner: () => 'Runner in-SU testov sa spúšťa vždy s -CloseWhenDone (inak ostane inštancia SketchUpu visieť a blokuje ďalšie behy; ' +
    'IMPLEMENTATOR.md, Testovanie). Spusti napr.: powershell -NoProfile -File scripts\\run_su_tests.ps1 -CloseWhenDone ' +
    '(s -DryRun sa nič nespúšťa a príkaz je povolený). Opis stráže: docs/HOOKY.md.',
};
const deny = (code, data) => ({ code, reason: REASONS[code](data || {}) });

// --- preskočenie $( … ) vnútri úvodzoviek ---------------------------------------------------
// Štandardná správa commitu / popis PR je `-m "$(cat <<'EOF' … "citát"; git push origin main … EOF\n)"`: telo heredoc môže
// mať úvodzovky, bodkočiarky aj zátvorky, preto sa substitúcia preskakuje celá (vrátane vnorených úvodzoviek a heredoc).
function skipHeredocBody(s, from, h) {
  let p = from;
  while (p < s.length) {
    let e = s.indexOf('\n', p);
    if (e < 0) e = s.length;
    let line = s.slice(p, e).replace(/\r$/, '');
    if (h.dash) line = line.replace(/^\t+/, '');
    p = e + 1;
    if (line === h.delim) return p;
  }
  return s.length;
}
function skipDq(s, i) {                           // i = za otváracou "; vráti index za zatváracou "
  while (i < s.length) {
    const c = s[i];
    if (c === '\\' || c === '`') { i += 2; continue; }
    if (c === '"') return i + 1;
    if (c === '$' && s[i + 1] === '(') { i = skipSubst(s, i + 2); continue; }
    i++;
  }
  return s.length;
}
function skipSubst(s, i) {                        // i = za "$("; vráti index za zodpovedajúcou )
  let depth = 1;
  const pend = [];
  while (i < s.length) {
    const c = s[i];
    if (c === '\n') { i++; while (pend.length) i = skipHeredocBody(s, i, pend.shift()); continue; }
    if (c === '\\') { i += 2; continue; }
    if (c === "'") { const j = s.indexOf("'", i + 1); i = j < 0 ? s.length : j + 1; continue; }
    if (c === '"') { i = skipDq(s, i + 1); continue; }
    if (c === '<' && s[i + 1] === '<' && s[i + 2] !== '<') {
      i += 2;
      const dash = s[i] === '-';
      if (dash) i++;
      while (s[i] === ' ' || s[i] === '\t') i++;
      let delim = '';
      if (s[i] === "'" || s[i] === '"') { const qc = s[i++]; while (i < s.length && s[i] !== qc) delim += s[i++]; i++; }
      else while (i < s.length && !/[\s;&|()<>]/.test(s[i])) delim += s[i++];
      pend.push({ delim, dash });
      continue;
    }
    if (c === '$' && s[i + 1] === '(') { i = skipSubst(s, i + 2); continue; }
    if (c === '(') depth++;
    else if (c === ')') { depth--; if (depth === 0) return i + 1; }
    i++;
  }
  return s.length;
}

// --- rozklad príkazu na slová a oddeľovače ------------------------------------------------
// shell: 'bash' | 'powershell'. Výstup: [{t:'w', v, q}] slovo (q = malo úvodzovky) | [{t:'s', v}] oddeľovač.
function tokenize(cmd, shell) {
  const ps = shell === 'powershell';
  const s = String(cmd);
  const n = s.length;
  const out = [];
  const pending = [];                            // čakajúce heredoc (bash)
  let cur = '';
  let has = false;
  let q = false;
  let i = 0;
  let subs = [];                                  // vnútorné texty substitúcií aktuálneho slova (posudzujú sa samostatne)
  const push = () => { if (has) out.push({ t: 'w', v: cur, q, subs }); cur = ''; has = false; q = false; subs = []; };
  const sep = (v) => { push(); out.push({ t: 's', v }); };
  while (i < n) {
    const c = s[i];
    if (c === ' ' || c === '\t' || c === '\r') { push(); i++; continue; }
    if (c === '\n') {
      sep('\n'); i++;
      while (pending.length) i = skipHeredocBody(s, i, pending.shift());
      continue;
    }
    // pokračovanie riadka: \ + nový riadok (bash), ` + nový riadok (PowerShell)
    if ((ps ? c === '`' : c === '\\') && (s[i + 1] === '\n' || (s[i + 1] === '\r' && s[i + 2] === '\n'))) { i += s[i + 1] === '\r' ? 3 : 2; continue; }
    if (c === '#' && !has) { while (i < n && s[i] !== '\n') i++; continue; }
    if (ps && c === '@' && !has && (s[i + 1] === "'" || s[i + 1] === '"')) {   // PowerShell here-string
      const re = /@(['"])[ \t]*\r?\n/y;
      re.lastIndex = i;
      const m = re.exec(s);
      if (m) {
        const close = new RegExp('\\r?\\n[ \\t]*' + m[1] + '@').exec(s.slice(re.lastIndex));
        cur += close ? s.slice(re.lastIndex, re.lastIndex + close.index) : s.slice(re.lastIndex);
        has = true; q = true;
        i = close ? re.lastIndex + close.index + close[0].length : n;
        continue;
      }
    }
    if (c === "'") {
      has = true; q = true; i++;
      if (!ps) {
        let j = s.indexOf("'", i);
        if (j < 0) j = n;
        cur += s.slice(i, j); i = j + 1;
      } else {
        while (i < n) {
          if (s[i] === "'") { if (s[i + 1] === "'") { cur += "'"; i += 2; continue; } i++; break; }
          cur += s[i++];
        }
      }
      continue;
    }
    if (c === '"') {
      has = true; q = true; i++;
      while (i < n) {
        const ch = s[i];
        if (ch === '$' && s[i + 1] === '(') { const j = skipSubst(s, i + 2); cur += s.slice(i, j); subs.push(s.slice(i + 2, s[j - 1] === ')' ? j - 1 : j)); i = j; continue; }
        if (!ps && ch === '`') { const j = s.indexOf('`', i + 1); const e = j < 0 ? n : j + 1; cur += s.slice(i, e); i = e; continue; }
        if (ps) {
          if (ch === '`' && i + 1 < n) { cur += s[i + 1]; i += 2; continue; }
          if (ch === '"') { if (s[i + 1] === '"') { cur += '"'; i += 2; continue; } i++; break; }
        } else {
          if (ch === '\\' && i + 1 < n && '"\\$`\n'.indexOf(s[i + 1]) >= 0) { if (s[i + 1] !== '\n') cur += s[i + 1]; i += 2; continue; }
          if (ch === '"') { i++; break; }
        }
        cur += ch; i++;
      }
      continue;
    }
    if (ps && c === '`' && i + 1 < n) { cur += s[i + 1]; has = true; i += 2; continue; }
    if (!ps && c === '\\') {
      const d = s[i + 1];
      if (d !== undefined && ' \t"\'$\\;&|()<>#'.indexOf(d) >= 0) { cur += d; has = true; i += 2; continue; }
      cur += c; has = true; i++; continue;           // \ pred beznym znakom ostava (cesty Windows)
    }
    if (c === ';') { sep(';'); i++; continue; }
    if (c === '|') { if (s[i + 1] === '|') { sep('||'); i += 2; } else { sep('|'); i++; } continue; }
    if (c === '&') {
      if (s[i + 1] === '&') { sep('&&'); i += 2; continue; }
      if (/[<>]$/.test(cur)) { cur += c; has = true; i++; continue; }          // 2>&1 (aj v PowerShelli)
      if (ps) { push(); out.push({ t: 'w', v: '&', q: false }); i++; continue; }
      if (s[i + 1] === '>') { cur += c; has = true; i++; continue; }           // &>
      sep('&'); i++; continue;
    }
    if (ps && c === '{' && !has) { out.push({ t: 'w', v: '{', q: false, subs: [] }); i++; continue; }   // blok { … } (nie @{ } ani ${x})
    if (ps && c === '}' && (cur.match(/\{/g) || []).length <= (cur.match(/\}/g) || []).length) {
      push(); out.push({ t: 'w', v: '}', q: false, subs: [] }); i++; continue;
    }
    if (c === '(') {
      // Substitúcia `$( … )` (aj PowerShell `( … )` a `@( … )`) je hodnota argumentu, nie samostatný príkaz:
      // `--match-head-commit $(git rev-parse HEAD)` je platné pripnutie. Ostane súčasťou slova, no jej vnútro sa
      // navyše posúdi samostatne (segment() → nested()), aby `out=$(git push origin main)` neprešlo.
      if (ps || cur.endsWith('$')) { const j = skipSubst(s, i + 1); cur += s.slice(i, j); subs.push(s.slice(i + 1, s[j - 1] === ')' ? j - 1 : j)); has = true; i = j; continue; }
      sep('('); i++; continue;                                                 // podshell v bashi
    }
    if (c === ')') { sep(')'); i++; continue; }
    if (!ps && c === '<' && s[i + 1] === '<' && s[i + 2] === '<') {          // here-string <<< slovo: samostatný operátor, nie heredoc
      push(); out.push({ t: 'w', v: '<<<', q: false, subs: [] }); i += 3; continue;
    }
    if (!ps && c === '<' && s[i + 1] === '<') {                              // heredoc
      i += 2;
      const dash = s[i] === '-';
      if (dash) i++;
      while (s[i] === ' ' || s[i] === '\t') i++;
      let delim = '';
      if (s[i] === "'" || s[i] === '"') {
        const qc = s[i++];
        while (i < n && s[i] !== qc) delim += s[i++];
        i++;
      } else {
        while (i < n && !/[\s;&|()<>]/.test(s[i])) delim += s[i++];
      }
      pending.push({ delim, dash });
      continue;
    }
    cur += c; has = true; i++;
  }
  push();
  return out;
}

// --- pomocné ------------------------------------------------------------------------------
function baseName(p) { return String(p).replace(/\\/g, '/').split('/').pop().toLowerCase(); }
function cmdName(p) { return baseName(p).replace(/\.(exe|cmd|bat)$/, ''); }

// Slová bez presmerovaní (`> log`, `2>&1`, `>>f`, `< in`).
function stripRedirects(words) {
  const res = [];
  for (let k = 0; k < words.length; k++) {
    const w = words[k];
    if (!w.q && /^(\d*|&)(>>?|<{1,3})/.test(w.v)) {
      if (/^(\d*|&)(>>?|<{1,3})&?$/.test(w.v)) k++;   // samotný operátor: cieľ je ďalšie slovo
      continue;
    }
    res.push(w);
  }
  return res;
}

// Priečinok z cesty: null = neznámy (premenná, ~, prázdny základ pri relatívnej ceste).
function resolveDir(base, p) {
  if (typeof p !== 'string' || /[$%~()]/.test(p) || p === '-') return null;
  let x = p;
  if (process.platform === 'win32') {
    const m = /^\/([a-zA-Z])(?:\/(.*))?$/.exec(x);
    if (m) x = m[1].toUpperCase() + ':/' + (m[2] || '');
  }
  if (x === '') return base || null;
  if (path.isAbsolute(x)) return path.resolve(x);
  return base ? path.resolve(base, x) : null;
}

// Cieľ `cd` / `Set-Location` / `pushd`: reťazec, alebo null (neznámy / bez cieľa).
function cdTarget(args, shell) {
  for (let k = 0; k < args.length; k++) {
    const v = args[k].v;
    if (shell === 'powershell' && /^-(path|literalpath|pspath|lp)$/i.test(v)) return k + 1 < args.length ? args[k + 1].v : null;
    if (!args[k].q && v.length > 1 && v[0] === '-') continue;   // -P, --, -PassThru (nie '-')
    return v;
  }
  return null;
}

function defaultBranchOf(dir) {
  try {
    if (!dir) return null;
    const out = cp.execFileSync('git', ['-C', dir, 'symbolic-ref', '-q', 'HEAD'],
      { encoding: 'utf8', windowsHide: true, timeout: GIT_TIMEOUT_MS, stdio: ['ignore', 'pipe', 'ignore'] });
    const ref = String(out).trim();
    return ref.startsWith('refs/heads/') ? ref.slice('refs/heads/'.length) : null;   // odpojená hlava: exit 1 → null
  } catch (_) {
    return null;
  }
}

function defaultPrDiff(arg, repo, dir) {
  try {
    const args = ['pr', 'diff', arg];
    if (repo) args.push('--repo', repo);
    const opt = { encoding: 'utf8', windowsHide: true, timeout: GH_TIMEOUT_MS, maxBuffer: 64 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] };
    if (dir && fs.existsSync(dir)) opt.cwd = dir;
    return cp.execFileSync('gh', args, opt);
  } catch (_) {
    return null;
  }
}

function branchOf(st, dir) {
  if (!dir) return null;
  if (!st.cache.has(dir)) {
    let b = null;
    try { b = (st.opts.branchOf || defaultBranchOf)(dir); } catch (_) { b = null; }
    st.cache.set(dir, typeof b === 'string' && b ? b : null);
  }
  return st.cache.get(dir);
}

function isG7File(p) { return G7_PATTERNS.some((re) => re.test(p)); }

// Pridané riadky s PLACEHOLDER v súboroch G7_FILES → zoznam súborov (unikátny, v poradí výskytu).
function placeholderFiles(diffText) {
  const files = [];
  let cur = null;
  for (const line of String(diffText).split('\n')) {
    const m = /^diff --git a\/.* b\/(.*?)\r?$/.exec(line);
    if (m) { cur = m[1].replace(/\\/g, '/'); continue; }
    if (cur && isG7File(cur) && line[0] === '+' && !line.startsWith('+++') && line.indexOf(PLACEHOLDER) >= 0 && files.indexOf(cur) < 0) files.push(cur);
  }
  return files;
}

// Parametre skriptu: je prepínač `name` zapnutý? (PowerShell skracuje názov na jednoznačný začiatok.)
function switchOn(args, name) {
  let on = false;
  for (const a of args) {
    if (a.q) continue;
    const m = /^-([a-z]+)(?::(.*))?$/i.exec(a.v);
    if (!m || !name.toLowerCase().startsWith(m[1].toLowerCase())) continue;
    on = !(m[2] !== undefined && /^\$?(false|0)$/i.test(m[2]));
  }
  return on;
}

// --- posudzovanie jednoduchého príkazu -----------------------------------------------------
function runnerSeg(args) {
  const a = stripRedirects(args);
  if (switchOn(a, 'DryRun') || switchOn(a, 'CloseWhenDone')) return null;
  return deny('runner');
}

function gitSeg(words, st) {
  let dir = st.cwd;
  let i = 1;
  while (i < words.length) {
    const w = words[i].v;
    if (w === '-C') { dir = resolveDir(dir, i + 1 < words.length ? words[i + 1].v : null); i += 2; }
    else if (w === '-c') i += 2;
    else if (/^--(git-dir|work-tree)$/.test(w)) { dir = null; i += 2; }
    else if (/^--(namespace|super-prefix|config-env)$/.test(w)) i += 2;
    else if (/^--(git-dir|work-tree)=/.test(w)) { dir = null; i++; }
    else if (w.length > 1 && w[0] === '-') i++;
    else break;
  }
  if (i >= words.length) return null;
  const sub = words[i].v;
  const args = words.slice(i + 1);
  if (BRANCH_CHANGERS.has(sub)) { st.branchChanged = true; return null; }
  if (sub === 'commit') {
    if (st.branchChanged || args.some((a) => a.v === '--help')) return null;
    return branchOf(st, dir) === PROTECTED_BRANCH ? deny('commit') : null;
  }
  if (sub !== 'push') return null;
  const pos = [];                                // pozičné argumenty (slová): repozitár a refspecy
  let tags = false;
  let follow = false;
  for (let k = 0; k < args.length; k++) {
    const v = args[k].v;
    if (v === '--') { for (k++; k < args.length; k++) pos.push(args[k]); break; }
    // --all / --branches / --mirror posielajú aj lokálnu vetvu main: odmietnuté vždy, bez ohľadu na aktuálnu vetvu
    // (v tomto repe lokálny main existuje vždy; zisťovať jeho existenciu by znamenalo ďalší proces a cieľ aj tak nie je jeden refspec)
    if (v === '--all' || v === '--branches' || v === '--mirror') return deny('push');
    if (v === '--tags') tags = true;
    else if (v === '--follow-tags') follow = true;
    if (!args[k].q && v.length > 1 && v[0] === '-') { if (PUSH_VALUE_OPTS.has(v)) k++; continue; }
    pos.push(args[k]);
  }
  const refspecs = pos.slice(1);
  const current = () => (st.branchChanged ? null : branchOf(st, dir));
  if (refspecs.length === 0) {
    if (tags && !follow) return null;
    return current() === PROTECTED_BRANCH ? deny('push') : null;
  }
  for (const w of refspecs) {
    // refspec je celý jedna substitúcia (`$(git branch --show-current)`): cieľ sa nedá zistiť → ako bare push, podľa aktuálnej vetvy
    if (w.subs && w.subs.length === 1 && /^\$?\([\s\S]*\)$/.test(w.v)) { if (current() === PROTECTED_BRANCH) return deny('push'); continue; }
    const spec = w.v.replace(/^\+/, '');
    const colon = spec.indexOf(':');
    let dest = (colon >= 0 ? spec.slice(colon + 1) : spec).replace(/^refs\/heads\//, '');
    if (colon < 0 && dest === 'HEAD') dest = current() || '';
    if (dest === PROTECTED_BRANCH) return deny('push');
  }
  return null;
}

function ghSeg(words, st) {
  let rest = words.slice(1);
  let repo = null;
  while (rest.length && /^(-R|--repo)(=|$)/.test(rest[0].v)) {
    if (rest[0].v.indexOf('=') > 0) { repo = rest[0].v.split('=').slice(1).join('='); rest = rest.slice(1); }
    else { repo = rest[1] ? rest[1].v : null; rest = rest.slice(2); }
  }
  if (!(rest.length >= 2 && rest[0].v === 'pr' && rest[1].v === 'merge')) return null;
  const args = stripRedirects(rest.slice(2));
  if (args.some((a) => a.v === '--help' || a.v === '-h')) return null;
  if (args.some((a) => a.v === '--disable-auto')) return null;     // zrušenie auto-merge, nie merge
  let pinned = false;
  let target = null;
  for (let k = 0; k < args.length; k++) {
    const v = args[k].v;
    if (v === '--match-head-commit') { if (k + 1 < args.length && args[k + 1].v !== '') pinned = true; k++; continue; }
    if (v.startsWith('--match-head-commit=')) { if (v.length > '--match-head-commit='.length) pinned = true; continue; }
    if (/^(-R|--repo)=/.test(v)) { repo = v.split('=').slice(1).join('='); continue; }
    if (v.length > 1 && v[0] === '-') {
      if (MERGE_VALUE_OPTS.has(v)) { if (v === '-R' || v === '--repo') repo = k + 1 < args.length ? args[k + 1].v : repo; k++; }
      continue;
    }
    if (target === null) target = v;
  }
  if (!pinned) return deny('pin');
  if (target !== null && (/^\d+$/.test(target) || /\/pull\/\d+/.test(target))) {
    const number = /^\d+$/.test(target) ? target : /\/pull\/(\d+)/.exec(target)[1];
    const text = (st.opts.prDiff || defaultPrDiff)(target, repo, st.cwd);
    if (typeof text === 'string' && text) {
      const files = placeholderFiles(text);
      if (files.length) return deny('g7', { number, files });
    }
  }
  return null;
}

function nested(inner, shell, st) {
  if (st.depth >= 2 || typeof inner !== 'string') return null;
  const child = Object.assign({}, st, { dirStack: [], depth: st.depth + 1 });
  return walk(tokenize(inner, shell), shell, child);
}

function segment(words0, shell, st) {
  // vnútro substitúcií `$( … )` a PowerShell `( … )` v ľubovoľnom slove sa posúdi ako samostatný príkaz
  for (const w of words0) {
    for (const inner of w.subs || []) {
      const r = nested(inner, shell, st);
      if (r) return r;
    }
  }
  const words = words0.slice();
  let control = false;                           // PowerShell: za if/while/foreach… ide podmienka ( … ), nie príkaz
  while (words.length) {
    const f = words[0];
    if (!f.q && /^[A-Za-z_][A-Za-z0-9_]*=/.test(f.v)) words.shift();
    else if (!f.q && shell === 'powershell' && CONTROL.has(f.v.toLowerCase())) { words.shift(); control = true; }
    else if (!f.q && WRAPPERS.has(f.v.toLowerCase())) { words.shift(); control = false; }
    else if (control && f.v[0] === '(') { words.shift(); control = false; }
    else break;
  }
  while (words.length && words[words.length - 1].v === '}' && !words[words.length - 1].q) words.pop();   // koniec bloku { … }
  if (!words.length) return null;
  const first = words[0].v;
  const name = cmdName(first);
  const args = stripRedirects(words.slice(1));
  if (CD_NAMES.has(name)) {
    if (name === 'pushd' || name === 'push-location') st.dirStack.push(st.cwd);
    const t = cdTarget(args, shell);
    st.cwd = t === null ? null : resolveDir(st.cwd, t);
    return null;
  }
  if (POP_NAMES.has(name)) { st.cwd = st.dirStack.length ? st.dirStack.pop() : null; return null; }
  if (name === 'git') return gitSeg(stripRedirects(words), st);
  if (name === 'gh') return ghSeg(stripRedirects(words), st);
  if (baseName(first) === RUNNER) return runnerSeg(args);
  if (name === 'powershell' || name === 'pwsh') {
    for (let k = 0; k < args.length; k++) {
      const a = args[k].v;
      const al = a.toLowerCase();
      if (al === '-file' || al === '-f') {
        return k + 1 < args.length && baseName(args[k + 1].v) === RUNNER ? runnerSeg(args.slice(k + 2)) : null;
      }
      if (al === '-command' || al === '-c') return nested(args.slice(k + 1).map((x) => x.v).join(' '), 'powershell', st);
      if (a[0] !== '-' && baseName(a) === RUNNER) return runnerSeg(args.slice(k + 1));
    }
    return null;
  }
  if (name === 'bash' || name === 'sh' || name === 'zsh' || name === 'dash') {
    const k = args.findIndex((x) => /^-[a-z]*c[a-z]*$/.test(x.v));
    return k >= 0 && k + 1 < args.length ? nested(args[k + 1].v, 'bash', st) : null;
  }
  return null;
}

function walk(items, shell, st) {
  let words = [];
  const scopes = [];
  const flush = () => {
    if (!words.length) return null;
    const w = words;
    words = [];
    return segment(w, shell, st);
  };
  for (const it of items) {
    if (it.t === 'w' && !it.q && (it.v === '{' || it.v === '}')) { const r = flush(); if (r) return r; continue; }   // hranica bloku
    if (it.t === 'w') { words.push(it); continue; }
    const r = flush();
    if (r) return r;
    if (it.v === '(') scopes.push(st.cwd);
    else if (it.v === ')' && scopes.length) st.cwd = scopes.pop();
  }
  return flush();
}

// Lacný predfilter: textový test bez spúšťania procesov.
function looksRelevant(c) {
  return (/\bgit(\.exe)?\b/i.test(c) && /\b(commit|push)\b/.test(c)) || (/\bgh(\.exe)?\b/i.test(c) && /\bmerge\b/.test(c)) || /run_su_tests/i.test(c);
}

// Príkaz → { code, reason } alebo null. opts (testy): branchOf(dir) → vetva|null · prDiff(arg, repo, dir) → text|null.
function analyze(command, toolName, cwd, opts) {
  if (typeof command !== 'string' || !looksRelevant(command)) return null;
  const shell = toolName === 'PowerShell' ? 'powershell' : 'bash';
  const st = { cwd: cwd && typeof cwd === 'string' ? path.resolve(cwd) : null, dirStack: [], cache: new Map(), opts: opts || {}, depth: 0, branchChanged: false };
  return walk(tokenize(command, shell), shell, st);
}

// Vstup hooku → { code, reason } alebo null (povolené). Nikdy nevyhodí výnimku (fail-open).
function decide(input, opts) {
  try {
    if (!input || typeof input !== 'object' || input.hook_event_name !== 'PreToolUse') return null;
    if (input.tool_name !== 'Bash' && input.tool_name !== 'PowerShell') return null;
    const command = input.tool_input && input.tool_input.command;
    return analyze(command, input.tool_name, input.cwd, opts);
  } catch (_) {
    return null;
  }
}

function formatDeny(reason) {
  const s = JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason } });
  let ascii = '';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    ascii += c < 0x7f ? s[i] : '\\u' + c.toString(16).padStart(4, '0');
  }
  return ascii;
}

// Surový stdin hooku → text na stdout ('' = povolené). Nikdy nevyhodí výnimku.
function handle(raw, opts) {
  try {
    let s = String(raw == null ? '' : raw);
    if (s.charCodeAt(0) === 0xfeff) s = s.slice(1);
    const r = decide(JSON.parse(s), opts);
    return r ? formatDeny(r.reason) : '';
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
  tokenize, stripRedirects, resolveDir, placeholderFiles, switchOn, looksRelevant, analyze, decide, formatDeny, handle, run,
  G7_FILES, PLACEHOLDER, PROTECTED_BRANCH,
};

if (require.main === module) run();
