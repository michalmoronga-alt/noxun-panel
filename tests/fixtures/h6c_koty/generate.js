// H6c · R0 — generator goldenu popisov kot nahladu. Spusta sa RUCNE a LEN nad
// kodom PRED zasahom H6c (stary mm model); vystup `golden.json` je zoznam <text>
// obsahov per pripad. Test tests/js/test_h6c_koty.js ho porovnava s novym kodom
// po normalizacii „ mm" (O11) a povolenych skratkach R3.
//   node tests/fixtures/h6c_koty/generate.js
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const H = require('../../js/h6c_harness.js');

const ctx = H.makeCtx();
const golden = {};
H.CASES.forEach(c => {
  const svg = H.renderCase(ctx, c, null);
  golden[c.id] = H.texts(svg).map(t => t.text);
});
fs.writeFileSync(path.join(__dirname, 'golden.json'), JSON.stringify(golden, null, 2) + '\n', 'utf8');
console.log('golden.json: ' + Object.keys(golden).length + ' pripadov, ' +
            Object.values(golden).reduce((s, a) => s + a.length, 0) + ' popisov');
