// R-02 — identita DOKUMENTU v zapisovych payloadoch panela (nxDocPayload).
//
// Co sa tu strazi:
//   1) helper VZDY doplni `model_guid` a vrati RETAZEC (callback HtmlDialogu
//      berie string, nie objekt),
//   2) ostatne kluce payloadu ostanu nedotknute (echo cabinet_id / board_id
//      sa nesmie stratit — server overuje OBE identity),
//   3) pred prvym pushom je guid PRAZDNY (okno bez dobehnuteho NX.init) —
//      server taky payload odmietne, klient si ziadny fallback nevymysla,
//      a po pushi nesie payload presne to, co server poslal,
//   4) `nxSetModelGuid` NEMAZE platnu identitu, ked volajuci hodnotu neposlal
//      (starsi push / vnoreny objekt bez tohto pola).
//
// shell.js exportuje ciste jadro; DOM cast sa v Node nikdy nevola — rovnaky
// vzor ako test_uib1_kostra.js. Spustenie: node tests/js/test_r02_doc_guard.js
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const NXShell = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'));

const nxDocPayload = NXShell.nxDocPayload;
const nxSetModelGuid = NXShell.nxSetModelGuid;

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.strictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function deq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- 1) tvar vystupu -------------------------------------------------------
eq(typeof nxDocPayload, 'function', 'helper je exportovany');
eq(typeof nxDocPayload({}), 'string', 'vystup je RETAZEC (callback berie string)');

// --- 2) pred prvym pushom je guid prazdny ----------------------------------
// Panel bez dobehnuteho NX.init nesmie predstierat identitu — server taky
// payload ODMIETNE (prisny guard `foreign_document?`).
deq(JSON.parse(nxDocPayload({ cabinet_id: 'CAB-001' })),
    { cabinet_id: 'CAB-001', model_guid: '' },
    'pred pushom prazdny guid, echo identity ostava');

// --- 3) po pushi nesie payload presne to, co poslal server ------------------
nxSetModelGuid('guid-A');
deq(JSON.parse(nxDocPayload({ board_id: 'BRD-003', orientation: 'stojaca' })),
    { board_id: 'BRD-003', orientation: 'stojaca', model_guid: 'guid-A' },
    'guid sa doplni, ostatne kluce ostanu');

// Prepnutie dokumentu — dalsi payload uz nesie NOVU identitu.
nxSetModelGuid('guid-B');
eq(JSON.parse(nxDocPayload({})).model_guid, 'guid-B', 'novy push prepise identitu');

// Vnorene hodnoty aj null/false sa prenesu bez zmeny (payloady kovania nesu
// `owner_part_key: null`, karta dosky `abs_id: null` = bez ABS).
deq(JSON.parse(nxDocPayload({ owner_part_key: null, disabled: false,
                              fields: { width: 555 } })),
    { owner_part_key: null, disabled: false, fields: { width: 555 }, model_guid: 'guid-B' },
    'null/false/vnorene objekty prezili');

// --- 4) chybajuca hodnota NEMAZE platnu identitu ---------------------------
nxSetModelGuid(undefined);
eq(JSON.parse(nxDocPayload({})).model_guid, 'guid-B', 'undefined identitu nemaze');
nxSetModelGuid(null);
eq(JSON.parse(nxDocPayload({})).model_guid, 'guid-B', 'null identitu nemaze');

// Prazdny retazec je PLATNA hodnota (server posle prazdny guid, ked dokument
// guid nema) — vtedy sa identita naozaj vynuluje a zapisy sa odmietnu.
nxSetModelGuid('');
eq(JSON.parse(nxDocPayload({})).model_guid, '', 'prazdny retazec je platna hodnota');

// --- 5) volanie bez argumentu neprehodi vynimku ----------------------------
nxSetModelGuid('guid-C');
deq(JSON.parse(nxDocPayload()), { model_guid: 'guid-C' }, 'volanie bez argumentu je bezpecne');

console.log(`OK test_r02_doc_guard.js — ${n} kontrol`);
