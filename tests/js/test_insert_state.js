// Testy stavu vkladacej karty D-32/D-33/D-39 (insert_state.js) — dependency-free
// Node (node tests/js/test_insert_state.js). Modul je cisty (bez DOM), exportuje
// cez module.exports (rovnaky vzor ako expr.js/usage.js). Pokryva: prechodovy
// automat rezimov (reset LEN pri skutocnom prechode do insert — audit B2), zamky
// poli (whitelist, hodnoty, roundtrip Ruby<->JS — audit B5), skladanie zdroja
// karty (sablona NAD defaultmi — D-32/D-33), zamok prebije sablonu (D-39),
// materialy zo sablony (audit F6) a IMUTABILITU sablony (audit N11 — deep freeze).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const ins = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'insert_state.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function deepFreeze(o){
  Object.freeze(o);
  Object.keys(o).forEach(function(k){
    if (o[k] && typeof o[k] === 'object' && !Object.isFrozen(o[k])) deepFreeze(o[k]);
  });
  return o;
}

// --- needsReset: reset LEN pri skutocnom prechode do insert (audit B2) ---
eq(ins.needsReset(null, 'insert'), true, 'boot -> insert resetuje');
eq(ins.needsReset('cab', 'insert'), true, 'cab -> insert resetuje');
eq(ins.needsReset('part', 'insert'), true, 'part -> insert resetuje');
eq(ins.needsReset('board', 'insert'), true, 'board -> insert resetuje');
eq(ins.needsReset('insert', 'insert'), false, 'insert -> insert NEresetuje (rozpisane upravy preziju)');
eq(ins.needsReset('insert', 'cab'), false, 'insert -> cab neresetuje');
eq(ins.needsReset('cab', 'part'), false, 'cab -> part neresetuje');

// --- trackMode: pamata rezim a hlasi reset ---
ins.state.lastMode = null;
eq(ins.trackMode('insert'), true, 'trackMode: prvy vstup do insert');
eq(ins.trackMode('insert'), false, 'trackMode: insert sync bez resetu');
eq(ins.trackMode('cab'), false, 'trackMode: odchod na cab');
eq(ins.trackMode('insert'), true, 'trackMode: navrat cab -> insert');
eq(ins.trackMode('board'), false, 'trackMode: odchod na board');
eq(ins.trackMode('insert'), true, 'trackMode: navrat board -> insert');
eq(ins.state.lastMode, 'insert', 'trackMode: lastMode aktualny');

// --- zamky: whitelist poli + platne hodnoty (D-39) ---
ins.setLocksFlat({});
eq(ins.setLock('width', 950), true, 'setLock sirka 950');
eq(ins.isLocked('width'), true, 'isLocked po setLock');
eq(ins.setLock('bogus', 100), false, 'setLock mimo whitelistu odmietnuty');
eq(ins.setLock('height', 'abc'), false, 'setLock s nezmyslom odmietnuty');
eq(ins.isLocked('height'), false, 'neplatny setLock nezamkol');
eq(ins.setLock('floor_height', '150'), true, 'setLock cislo v stringu (JSON z Ruby)');
eq(ins.updateLockValue('depth', 500), false, 'updateLockValue na odomknutom = false');
eq(ins.updateLockValue('width', 900), true, 'updateLockValue na zamknutom');
eq(ins.locksFlat(), { width: 900, floor_height: 150 }, 'locksFlat = ploche zamknute polia');
ins.clearLock('floor_height');
eq(ins.locksFlat(), { width: 900 }, 'clearLock odstranil zamok');

// --- serializacia Ruby <-> JS (audit B5): roundtrip + sanitizacia ---
ins.setLocksFlat({ width: 950, floor_height: 150, bogus: 9, height: 'x' });
eq(ins.locksFlat(), { width: 950, floor_height: 150 }, 'setLocksFlat: whitelist + cisla, zvysok zahodeny');
eq(ins.state.locks.width, { locked: true, value: 950 }, 'vnutorny tvar {locked, value} (audit B1)');
ins.setLocksFlat(null);
eq(ins.locksFlat(), {}, 'setLocksFlat(null) = ziadne zamky');

// --- composeSource: sablona NAD defaultmi = plny obraz karty (D-32/D-33) ---
const DEFAULTS = { type: 'lower', width: 600, height: 720, depth: 510, thickness: 18,
                   floor_height: 100, plinth_recess: 40, fronts: 'none' };
const TPL = deepFreeze({ type: 'lower', width: 450, height: 900,
                         material_id: 'K009_PW_DTDL_18', front_material_id: 'FRONT_W_18',
                         fronts: { gap: 3, items: [{ id: 'F1', type: 'door' }] },
                         zone_tree: { id: 'Z1', shelves: 2, children: [] } });
const src = ins.composeSource(DEFAULTS, TPL);
eq(src.width, 450, 'compose: sablona prebije default');
eq(src.depth, 510, 'compose: chybajuci kluc sablony = default (ziadne zvysky karty)');
eq(src.plinth_recess, 40, 'compose: legacy sablona bez plinth_recess dostane default');
eq(src.material_id, 'K009_PW_DTDL_18', 'compose: material sablony sa nesie (audit F6)');
src.width = 111; // mutacia vysledku...
eq(TPL.width, 450, 'compose: ...sa NEDOTKNE sablony (novy objekt)');
eq(DEFAULTS.width, 600, 'compose: ...ani defaultov');

// --- applyLocks: zamok prebije sablonu aj defaulty (D-39, poradie F7) ---
ins.setLocksFlat({ height: 950 });
const src2 = ins.applyLocks(ins.composeSource(DEFAULTS, TPL));
eq(src2.height, 950, 'zamknuta vyska prebila sablonu (900 -> 950)');
eq(src2.width, 450, 'nezamknute pole ostava zo sablony');
eq(TPL.height, 900, 'applyLocks nemutuje sablonu (bezi na compose kopii)');

// --- materialsOf: sablonove materialy / prazdne = null (dedenie z projektu) ---
eq(ins.materialsOf({}), { material_id: null, front_material_id: null, back_material_id: null },
  'bez sablony ziadne materialy (dedenie)');
eq(ins.materialsOf({ material_id: 'K009', front_material_id: '', back_material_id: null }),
  { material_id: 'K009', front_material_id: null, back_material_id: null },
  'prazdny string = null (dedenie), hodnota sa nesie');
ins.setMaterials(TPL);
eq(ins.state.materials.material_id, 'K009_PW_DTDL_18', 'setMaterials do stavu karty');
ins.setMaterials(null);
eq(ins.state.materials, { material_id: null, front_material_id: null, back_material_id: null },
  'setMaterials(null) = cisty draft');

// --- N11: cela cesta compose+locks+materials NAD ZAMRAZENOU sablonou nehodi
//     vynimku a sablona ostava byte-identicka (JS strana imutability) ---
const tplJson = JSON.stringify(TPL);
ins.setLocksFlat({ width: 950, thickness: 18 });
const full = ins.applyLocks(ins.composeSource(DEFAULTS, TPL));
ins.setMaterials(full);
eq(JSON.stringify(TPL), tplJson, 'sablona po celom insert toku byte-nezmenena');
eq(full.width, 950, 'zamok v plnom toku aplikovany');

console.log(JSON.stringify({ passed: n, failed: 0 }));
