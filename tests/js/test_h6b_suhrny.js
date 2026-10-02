// H6b (blok 9 HARDENING) · R0 CHARAKTERIZACIA — dependency-free Node:
// node tests/js/test_h6b_suhrny.js
//
// Lista S1 (rozmery v Zonach/Celach/Kovani) a lista S4 Kovania pouzivaju UZ
// EXISTUJUCE cisté funkcie: `metaDims` (cez NXShell.sectorMeta(...).s2),
// `metaMaterials` (.s3) a `nxHwSummary` (preview.js). H6b ich NEMENI — len ich
// znovu pouzije na novych miestach. Tento test ich porovnava s GOLDENOM
// `tests/fixtures/h6b_suhrny.json`, ktory bol vyrobeny jednorazovo nad starym
// kodom (main 0.17.17); fixturu negeneruje novy kod. Zeleny pred aj po H6b.
'use strict';
global.nxDocGuid = () => '';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXShell = require(path.join(JS, 'shell.js'));
const PV = require(path.join(JS, 'preview.js'));
const GOLD = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'h6b_suhrny.json'), 'utf8'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

eq(GOLD.states.length, 9, 'R0: golden ma 9 stavov');
GOLD.states.forEach(function(s){
  const m = NXShell.sectorMeta({ mode: 'cab', ctx: 'korpus', dims: s.dims, materials: s.materials });
  eq(m.s2, s.s2, 'R0 ' + s.id + ': metaDims (S2) sa nezmenil');
  eq(m.s3, s.s3, 'R0 ' + s.id + ': metaMaterials (S3) sa nezmenil');
  eq(PV.nxHwSummary(s.hw), s.hw_summary, 'R0 ' + s.id + ': nxHwSummary sa nezmenil');
});
eq(PV.nxHwSummary(null), GOLD.hw_summary_null, 'R0: nxHwSummary(null) sa nezmenil');

console.log('test_h6b_suhrny: ' + n + ' OK');
