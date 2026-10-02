// H6c — citatelne koty v nahlade Inspectora (D-02, blok 9 HARDENING).
//   node tests/js/test_h6c_koty.js
//
// T0 golden popisov (tests/fixtures/h6c_koty/golden.json, vygenerovany nad
//    STARYM kodom): ziadna kota nesmie pribudnut ani zmiznut; po normalizacii
//    „ mm" (O11) a povolenych skratkach (R3) je kazdy popis rovnaky.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const H = require('./h6c_harness.js');

let n = 0;
function eq(actual, expected, msg){ n++; assert.deepStrictEqual(H.plain(actual), H.plain(expected), msg); }
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const GOLDEN = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'h6c_koty', 'golden.json'), 'utf8'));

// ============ T0 · golden popisov ===========================================
// Povolene skratky R3: dlhy popis -> kratky (len cislo) a popis cela v 3 stupnoch.
// Volitelne (R3): popis zony a cislo pasma chladnicky sa nekresli, ked sa nezmesti.
function norm(t){ return t.replace(/ mm$/, ''); }
function variants(g){
  const out = [g];
  let m;
  if ((m = /^(?:Š|V|H|sokel|telo) (\d+)$/.exec(g))) out.push(m[1]);
  if ((m = /^(F\d+) · .*?(\d+)$/.exec(g))) { out.push(m[1] + ' · ' + m[2]); out.push(m[1]); }
  return out;
}
const OPTIONAL = { zones_4: /^\d+×\d+$/, cab_fridge: /^(40|629|71|1200)$/ };
{
  const ctx = H.makeCtx();
  H.CASES.forEach(c => {
    const got = H.texts(H.renderCase(ctx, c, { w: 404, h: 323 })).map(t => norm(t.text));
    const pool = got.slice();
    GOLDEN[c.id].map(norm).forEach(g => {
      const i = pool.findIndex(x => variants(g).indexOf(x) >= 0);
      if (i >= 0) { pool.splice(i, 1); n++; return; }
      ok(OPTIONAL[c.id] && OPTIONAL[c.id].test(g), `T0 ${c.id}: popis „${g}" zmizol (nasiel som: ${JSON.stringify(got)})`);
    });
    eq(pool, [], `T0 ${c.id}: pribudol nepovoleny popis`);
  });
}

console.log('test_h6c_koty: ' + n + ' kontrol OK');
