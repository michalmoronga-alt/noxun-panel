// NASTROJE-1 (Codex #293 kolo 1, P2): handshake pred kopiou nastrojom.
//
// Kopia spustena z TOOLBARU ide MIMO JS, takze rozpisana zmena v karte (auto-apply
// ma 400 ms debounce) by ostala vo formulari a kopia by vznikla zo STAREHO configu.
// Ruby si preto vypyta flush a CAKA. Kontrakt, ktory sa tu overuje:
//   * server dostane odpoved v KAZDEJ vetve (inak by cakal do timeoutu),
//   * cervene pole / rozpisany vyraz = 'invalid' (kopia sa ODMIETNE),
//   * niet co flushnut = 'nothing' (server kopiruje hned),
//   * rozpisane edity = `apply_all` s `native_op` (kopia bezi az po nom).
//
// Funkcia sa NEKOPIRUJE — cita sa PRIAMO zo `form.js` a spusta v sandboxe
// s podstrcenymi zavislostami (zrkadlo by mohlo od zdroja odbehnut).
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const FORM = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'form.js');
const src = fs.readFileSync(FORM, 'utf8');

function extract(re, what){
  const m = src.match(re);
  assert.ok(m, `${what} sa vo form.js nenasla`);
  return m[0];
}

const FLUSH_FOR_NATIVE = extract(/function nxFlushForNative\(token, op\)\{[\s\S]*?\n  \}/, 'nxFlushForNative');
const FLUSH_EDITS = extract(/function flushCabinetEdits\(cabSnapshot, guidSnapshot, nativeOp\)\{[\s\S]*?\n  \}/,
                            'flushCabinetEdits');

// Sandbox: vsetky volne premenne funkcie su podstrcene zavislosti.
// POZOR: meno, ktore deklaruje SAM testovany zdroj, sa NEsmie prebit stubom —
// `var x = deps.x` bezi az po hoistingu deklaracie funkcie a zahodil by ju.
const DEPS = ['selectedCabId', 'applyTimer', 'applyPendingGuid', 'document', 'window', 'sketchup',
              'NX', 'isExprInput', 'isExprStr', 'validateFields', 'collectAll', 'nxDocPayload',
              'nxNativeFlushDone', 'cancelCabinetEdits', 'flushCabinetEdits'];

function run(fnSrc, deps, call){
  const declared = /function\s+(\w+)\s*\(/.exec(fnSrc)[1];
  const pre = DEPS.filter(function(nm){ return nm !== declared; })
                  .map(function(nm){
                    return `var ${nm} = deps.${nm === 'sketchup' ? 'window.sketchup' : nm};`;
                  }).join('\n');
  const factory = new Function('deps', `
    ${pre}
    var cabEditsInFlight = false;
    ${fnSrc}
    return ${call};
  `);
  return factory(deps);
}

function env(opts){
  const calls = [];
  const deps = {
    calls: calls,
    selectedCabId: 'cab' in opts ? opts.cab : 'CAB-001',
    applyTimer: 'timer' in opts ? opts.timer : null,
    applyPendingGuid: 'G1',
    document: { activeElement: opts.active || null },
    window: { sketchup: { apply_all: function(p){ calls.push(['apply_all', p]); } } },
    NX: { setStatus: function(m, bad){ calls.push(['status', m, !!bad]); } },
    isExprInput: function(e){ return !!(e && e.expr); },
    isExprStr: function(v){ return /[-+*/]/.test(String(v == null ? '' : v)); },
    validateFields: function(){ return opts.valid !== false; },
    collectAll: function(){ return { width: 700 }; },
    nxDocPayload: function(p){ return JSON.stringify(p); },
    nxNativeFlushDone: function(t, r){ calls.push(['done', t, r]); },
    cancelCabinetEdits: function(){ calls.push(['cancel']); },
    flushCabinetEdits: function(cab, g, op){ calls.push(['flush', cab, g, op]); }
  };
  return deps;
}

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- nxFlushForNative --------------------------------------------------------

// 1) Ziadna skrinka = niet co flushnut.
let d = env({ cab: null });
run(FLUSH_FOR_NATIVE, d, "nxFlushForNative('t1', { kind: 'copy', dir: 'right' })");
eq(d.calls, [['done', 't1', 'nothing']], 'bez vyberu sa odpoveda nothing');

// 2) Bez rozpisanych editov (ziadny timer) = nothing.
d = env({ timer: null });
run(FLUSH_FOR_NATIVE, d, "nxFlushForNative('t2', { kind: 'copy', dir: 'left' })");
eq(d.calls, [['done', 't2', 'nothing']], 'bez beziaceho timera sa odpoveda nothing');

// 3) Rozpisane edity = flush s `native_op` a ZIADNA priama odpoved.
d = env({ timer: 42 });
run(FLUSH_FOR_NATIVE, d, "nxFlushForNative('t3', { kind: 'copy', dir: 'right' })");
eq(d.calls.map(function(c){ return c[0]; }), ['cancel', 'flush'],
   'rozpisane edity sa najprv zrusia z timera a odosielaju sa hned');
eq(d.calls[1][3], { kind: 'copy', dir: 'right', token: 't3' }, 'native_op nesie druh, smer aj token');
eq(d.calls[1][1], 'CAB-001', 'apply ide na prave oznacenu skrinku');
eq(d.calls[1][2], 'G1', 'a nesie dokument z casu naplanovania editov (R-02)');

// 4) Cervene polia = invalid + hlaska (kopia sa odmietne).
d = env({ timer: 42, valid: false });
run(FLUSH_FOR_NATIVE, d, "nxFlushForNative('t4', { kind: 'copy', dir: 'right' })");
eq(d.calls.map(function(c){ return c[0]; }), ['status', 'done'], 'neplatne polia hlasi aj pouzivatelovi');
eq(d.calls[1], ['done', 't4', 'invalid'], 'a serveru odpoveda invalid');
eq(d.calls[0][2], true, 'hlaska je chybova');

// 5) Rozpisany VYRAZ v poli = invalid (medzistav '650-3' ma inu hodnotu).
d = env({ timer: 42, active: { expr: true, value: '650-36' } });
run(FLUSH_FOR_NATIVE, d, "nxFlushForNative('t5', { kind: 'copy', dir: 'right' })");
eq(d.calls[d.calls.length - 1], ['done', 't5', 'invalid'], 'rozpisany vyraz kopiu odmietne');

// 6) Chybajuci `op` nezhodi handshake (default `copy`).
d = env({ timer: 7 });
run(FLUSH_FOR_NATIVE, d, "nxFlushForNative('t6')");
eq(d.calls[1][3], { kind: 'copy', dir: '', token: 't6' }, 'bez op sa doplni bezpecny default');

// --- flushCabinetEdits: odpoved v KAZDEJ predcasnej vetve ---------------------

const OP = { kind: 'copy', dir: 'right', token: 'tx' };

d = env({ timer: 42, active: { expr: true, value: '650-36' } });
run(FLUSH_EDITS, d, "flushCabinetEdits('CAB-001', 'G1', " + JSON.stringify(OP) + ")");
eq(d.calls, [['done', 'tx', 'invalid']], 'rozpisany vyraz: server nesmie ostat bez odpovede');

d = env({ cab: null });
run(FLUSH_EDITS, d, "flushCabinetEdits(null, 'G1', " + JSON.stringify(OP) + ")");
eq(d.calls, [['done', 'tx', 'nothing']], 'zruseny vyber: server nesmie ostat bez odpovede');

d = env({ valid: false });
run(FLUSH_EDITS, d, "flushCabinetEdits('CAB-001', 'G1', " + JSON.stringify(OP) + ")");
eq(d.calls.map(function(c){ return c[0]; }), ['status', 'done'], 'neplatne polia: hlaska + odpoved');
eq(d.calls[1], ['done', 'tx', 'invalid'], 'a odpoved je invalid');

// Uspesna cesta: apply_all nesie `native_op` a ZIADNA priama odpoved sa neposiela.
d = env({});
run(FLUSH_EDITS, d, "flushCabinetEdits('CAB-001', 'G1', " + JSON.stringify(OP) + ")");
eq(d.calls.length, 1, 'uspesny flush posiela LEN apply_all');
eq(d.calls[0][0], 'apply_all', 'a je to apply_all');
eq(JSON.parse(d.calls[0][1]).native_op, OP, 'payload nesie native_op s tokenom');

// Bez `nativeOp` sa spravanie nemeni (bezny auto-apply).
d = env({});
run(FLUSH_EDITS, d, "flushCabinetEdits('CAB-001', 'G1')");
eq(JSON.parse(d.calls[0][1]).native_op, undefined, 'bezny auto-apply native_op nenesie');

console.log(`test_nastroje1_flush.js: ${n} testov OK`);
