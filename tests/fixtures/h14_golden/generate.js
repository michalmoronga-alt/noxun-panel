// H14 · T0 (R0.2) — GENERATOR GOLDEN CHARAKTERIZACIE sekcii Studia.
//
// PRECO: H14 presuva zoznamy sekcii Studia (navigacia, hlavicka, hlaska
// „Obnoviť", filter deep-linku Inspectora, prepinanie) na register
// `NXStudioSections`. Zavazok: pre pouzivatela sa NEMENI NIC. Golden subory
// su odtlacok NEZMENENEHO kodu (1. commit H14a) — `tests/js/test_h14_golden.js`
// porovnava cerstvy vypocet s nimi (G1–G10, popis v `tests/js/h14_harness.js`).
//
// SPUSTA SA RUCNE (test ho NEVOLA — inak by charakterizacia „dokazovala" samu
// seba):  node tests/fixtures/h14_golden/generate.js
//
// Prepisuje `g*.json` v tomto priecinku. Regenerovat sa smie IBA na nezmenenom
// kode; v H14a ani H14b nikdy — rozdiel je NALEZ, nie sum.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const H = require('../../js/h14_harness.js');

const out = H.golden();
Object.keys(out).forEach(function(k){
  fs.writeFileSync(path.join(__dirname, k + '.json'), H.serialize(out[k]));
});
console.log('OK: ' + Object.keys(out).length + ' golden suborov v ' + __dirname);
