// Testy D-100 (JS zrkadlo) — ocistenie nazvu skrinky PRED odoslanim callbacku.
// JS je len UX zrkadlo: co je "automaticky nazov" a co sa naozaj ulozi rozhoduje
// VYHRADNE server (CabinetBuilder.sanitize_name). Tu sa overuje len to, ze panel
// neposiela surovy vstup (medzery, nekonecna dlzka).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { cabNameValue, CAB_NAME_MAX } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

eq(cabNameValue('  Chladničková  '), 'Chladničková', 'okrajove medzery sa orezu');
eq(cabNameValue('Skrinka \t pri   okne'), 'Skrinka pri okne', 'viacnasobne medzery = jedna');
eq(cabNameValue(''), '', 'prazdne pole ostava prazdne (server ho vyhodnoti ako navrat na automaticky nazov)');
eq(cabNameValue('   '), '', 'samotne medzery = prazdne');
eq(cabNameValue(null), '', 'chybajuca hodnota nespadne');
eq(cabNameValue(undefined), '', 'undefined nespadne');
eq(cabNameValue('Spodná skrinka 900'), 'Spodná skrinka 900',
   'automaticky tvar JS NEvyhodnocuje — o tom rozhoduje server');
eq(CAB_NAME_MAX, 80, 'limit dlzky je zrkadlo Ruby NAME_MAX_LEN');
eq(cabNameValue('A'.repeat(200)).length, 80, 'dlhy nazov sa oreze na limit');
eq(cabNameValue('A'.repeat(79) + '   B'), 'A'.repeat(79), 'orez nenecha koncovu medzeru');

console.log(`test_d100_nazvy.js: ${n} testov OK`);
