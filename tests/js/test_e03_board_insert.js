// Testy E-03: vkladanie dosky s UNI materialom — ciste funkcie board_card.js
// (buildInsertBoardPayload / sheetIsUni / findSheetIn). Dependency-free Node:
//   node tests/js/test_e03_board_insert.js
// Kontext: UNI material nema hrubkovu identitu — hrubku urcuje DIELEC (M-B1),
// takze vkladacia karta ju musi vediet poslat. Pri REALNOM materiali sa
// thickness do payloadu nedostane vobec (hrubku diktuje katalog, D-45).
// Autorita je server (BoardBuilder.insert_thickness_for) — toto je UX zrkadlo.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { buildInsertBoardPayload, sheetIsUni, findSheetIn } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'board_card.js'));
const { evalDim } = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'expr.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const SHEETS = [
  { id: 'UNI_DOSKA_18', label: 'Doska UNI · UNI', thickness: 18, uni: true, grain: 'none' },
  { id: 'REAL_19', label: 'R 19 mm', thickness: 19, grain: 'length' }
];
const UNI = SHEETS[0], REAL = SHEETS[1];

// --- sheetIsUni: prisne true, ziadne truthy stringy ---------------------------
eq(sheetIsUni(UNI), true, 'UNI zaznam');
eq(sheetIsUni(REAL), false, 'realny zaznam');
eq(sheetIsUni(null), false, 'ziadny material');
eq(sheetIsUni({ uni: 'true' }), false, 'string nie je priznak (zrkadlo Materials.uni?)');

// --- findSheetIn --------------------------------------------------------------
eq(findSheetIn(SHEETS, 'REAL_19'), REAL, 'najde podla id');
eq(findSheetIn(SHEETS, 'NIC'), null, 'nezname id = null');
eq(findSheetIn(null, 'REAL_19'), null, 'prazdny katalog neprepadne');

const FORM = { name: 'Polica', length: '800', width: '300',
               material_id: 'UNI_DOSKA_18', grain_direction: 'none', thickness: '12' };

// --- UNI: hrubka ide do payloadu ---------------------------------------------
(function(){
  const r = buildInsertBoardPayload(FORM, UNI, evalDim);
  eq(r.ok, true, 'UNI payload prejde');
  eq(r.payload.thickness, 12, 'UNI: hrubka z formulara');
  eq(r.payload.length, 800, 'dlzka');
  eq(r.payload.width, 300, 'sirka');
  eq(r.payload.material_id, 'UNI_DOSKA_18', 'material');
})();

// --- UNI: vyraz v hrubke sa vyhodnoti (18-6 = 12) ------------------------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { thickness: '18-6' }), UNI, evalDim);
  eq(r.ok, true, 'vyraz je platny vstup');
  eq(r.payload.thickness, 12, 'vyhodnoteny vyraz, nie surovy string');
})();

// --- UNI: neplatna hrubka = STOP so statusom (nic sa neposiela) -----------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { thickness: 'abc' }), UNI, evalDim);
  eq(r.ok, false, 'nezmysel sa odmietne');
  ok(/hrúbku/.test(r.error), 'hlaska hovori o hrubke');
  eq(r.payload, undefined, 'ziadny payload');
})();

// --- UNI: prazdna hrubka = kluc chyba (server dosadi default roly) --------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { thickness: '  ' }), UNI, evalDim);
  eq(r.ok, true, 'prazdna hrubka nie je chyba');
  eq('thickness' in r.payload, false, 'kluc sa neposiela');
})();

// --- REALNY material: thickness sa do payloadu NEDOSTANE ------------------------
(function(){
  const r = buildInsertBoardPayload(
    Object.assign({}, FORM, { material_id: 'REAL_19', thickness: '99' }), REAL, evalDim);
  eq(r.ok, true, 'payload prejde');
  eq('thickness' in r.payload, false, 'hrubku diktuje katalog (D-45)');
  const bad = buildInsertBoardPayload(
    Object.assign({}, FORM, { material_id: 'REAL_19', thickness: 'abc' }), REAL, evalDim);
  eq(bad.ok, true, 'zamknute pole nesmie blokovat vlozenie ani so smetim v hodnote');
})();

// --- rozmery: povodne spravanie ostava -----------------------------------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { length: '650-' }), UNI, evalDim);
  eq(r.ok, false, 'rozpisany vyraz sa odmietne');
  ok(/rozmery/.test(r.error), 'hlaska hovori o rozmeroch');
  const empty = buildInsertBoardPayload(
    Object.assign({}, FORM, { length: '', width: '' }), UNI, evalDim);
  eq(empty.ok, true, 'prazdne rozmery = defaulty na serveri');
  eq(empty.payload.length, '', 'prazdny retazec ostava');
})();

// --- odolnost: chybajuce polia neurobia "undefined" v payloade ------------------
(function(){
  const r = buildInsertBoardPayload({}, null, evalDim);
  eq(r.ok, true, 'prazdny formular prejde');
  eq(r.payload.name, '', 'nazov je vzdy string');
  eq(r.payload.material_id, '', 'material je vzdy string');
  eq('thickness' in r.payload, false, 'bez materialu ziadna hrubka');
})();

console.log(`OK test_e03_board_insert.js — ${n} kontrol`);
