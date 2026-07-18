// Testy evalDim parsera (V0.4.7e) — dependency-free Node (node tests/js/test_expr.js).
// Bezia v CI vedla ruby sady; expr.js exportuje cez module.exports (v CEF vetva spi).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { evalDim, isExprStr, roundDim } = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'expr.js'));

let n = 0;
function eq(input, expected, msg){
  n++;
  const v = evalDim(input);
  if (Number.isNaN(expected)){
    assert.ok(Number.isNaN(v), `${msg || input}: cakam NaN, dostal ${v}`);
  } else {
    assert.ok(Math.abs(v - expected) < 1e-9, `${msg || input}: cakam ${expected}, dostal ${v}`);
  }
}

// --- platne vstupy ---
eq('650', 650);
eq(' 614 ', 614);
eq('650-36', 614);
eq('650 - 36', 614);
eq('3*600+2*18', 1836);
eq('(2070-3*18)/4', 504);
eq('600/3', 200);
eq('2+3*4', 14, 'priorita operatorov');
eq('(2+3)*4', 20);
eq('-36+650', 614, 'unarne minus na zaciatku');
eq('650+-36', 614, 'unarne minus za operatorom');
eq('--5', 5, 'dvojita negacia');
eq('1,5', 1.5, 'desatinna ciarka');
eq('650,5-0,5', 650);
eq('1.5*2', 3);
eq('10/4', 2.5);
eq('((600))', 600);

// --- neplatne vstupy (vsetko NaN, nikdy vynimka) ---
eq('', NaN);
eq('   ', NaN);
eq(null, NaN);
eq(undefined, NaN);
eq('abc', NaN);
eq('650-', NaN, 'nekompletny vyraz');
eq('(650', NaN, 'nezavreta zatvorka');
eq('650)', NaN, 'nespotrebovany zvysok');
eq('1 500', NaN, 'medzera nie je tisicovy oddelovac');
eq('1.500,5', NaN, 'tisicovy oddelovac sa odmieta');
eq('1,500.5', NaN, 'miesane oddelovace');
eq('6..5', NaN);
eq('1e5', NaN, 'exponent nepodporujeme');
eq('650mm', NaN, 'jednotky nepodporujeme');
eq('50%', NaN, 'percenta nepodporujeme');
eq('600/0', NaN, 'delenie nulou');
eq('600/(3-3)', NaN, 'delenie nulou po vypocte');
eq('alert(1)', NaN, 'ziadny kod');
eq('__proto__', NaN);
eq('*600', NaN, 'operator bez laveho operandu');

// --- isExprStr ---
assert.strictEqual(isExprStr('650'), false);
assert.strictEqual(isExprStr('-36'), false, 'unarne minus na zaciatku je este cislo');
assert.strictEqual(isExprStr('650-36'), true);
assert.strictEqual(isExprStr('650+1'), true);
assert.strictEqual(isExprStr('(600)'), true);
assert.strictEqual(isExprStr(''), false);

// --- roundDim ---
assert.strictEqual(roundDim(2.5), 2.5);
assert.strictEqual(roundDim(613.999999), 614);
assert.strictEqual(roundDim(1 / 3), 0.33);

console.log(JSON.stringify({ passed: n + 9, failed: 0 }));
