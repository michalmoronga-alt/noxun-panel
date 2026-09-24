// D-139 — VYSKA CELA SLOTU UMYVACKY JE ODVODENA (`node tests/js/test_d139_celo_slotu.js`).
// JS zrkadlo `nxSlotFrontEval` (core.js) musi dat TO ISTE cislo aj TU ISTU
// stranu rady ako Ruby `CabinetBuilder.dw_front_eval` — obe sady citaju
// spolocnu fixturu `tests/fixtures/slot_front_eval.json` (Astra B2 FIX 3:
// jeden vzorec bez spolocnej validacie nestaci).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const FIX = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'slot_front_eval.json'), 'utf8'));
const C = require(path.join(JS, 'core.js'));

function sideOf(err){
  if (err == null) return null;
  if (err.indexOf('najmenej') >= 0) return 'low';
  if (err.indexOf('najviac') >= 0) return 'high';
  return 'unknown';
}

ok(FIX.cases.length >= 8, 'fixtura je podozrivo kratka');
FIX.cases.forEach(c => {
  const ev = C.nxSlotFrontEval(c.height, c.bottom, c.gap_top);
  ok(Math.abs(ev.value - c.value) < 0.001, `${c.case}: cislo ${ev.value} vs ${c.value}`);
  eq(sideOf(ev.error), c.side, `${c.case}: strana rady`);
});

eq(C.NX_SLOT_FRONT_RANGE, [300, 1200], 'rozsah je zrkadlo `DW_RANGES[:dw_front_height]`');
const low = C.nxSlotFrontEval(500, 300, 2).error;
ok(low.indexOf('zvýš výšku linky alebo zníž sokel') >= 0, 'pod minimom rada zvysit linku');
const high = C.nxSlotFrontEval(1200, 0, -2).error;
ok(high.indexOf('zníž výšku linky, zvýš sokel alebo medzeru hore') >= 0, 'nad maximom rada OPACNA');
eq(C.nxSlotFrontEval('880', '100', '2').value, 778, 'retazce z formulara sa citaju ako cisla');

console.log(`test_d139_celo_slotu.js OK (${n} kontrol)`);
