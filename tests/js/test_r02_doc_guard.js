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

// --- 6) ZACHYTENA identita (review #264 P1) --------------------------------
// `nxModelGuid` je mutovatelny global, ktory prepise najblizsi push. Debounced
// edity (auto-apply korpusu, polia karty dosky; 400 ms) preto citaju identitu
// uz pri NAPLANOVANI a zachytenu hodnotu podaju helperu — inak by sa oneskoreny
// zapis opeciatkoval NOVYM dokumentom a guard by ho pustil presne tam, kam nema.
const nxDocGuid = NXShell.nxDocGuid;
eq(typeof nxDocGuid, 'function', 'citac aktualnej identity je exportovany');

nxSetModelGuid('guid-PRI-KLIKU');
const captured = nxDocGuid();          // debounce: snapshot pri naplanovani
eq(captured, 'guid-PRI-KLIKU', 'snapshot vrati identitu z casu naplanovania');
nxSetModelGuid('guid-PO-PREPNUTI');    // medzitym dorazil push z INEHO dokumentu
eq(JSON.parse(nxDocPayload({ cabinet_id: 'CAB-001' }, captured)).model_guid, 'guid-PRI-KLIKU',
   'odlozeny zapis nesie POVODNY dokument, nie ten aktualny');
eq(JSON.parse(nxDocPayload({ cabinet_id: 'CAB-001' })).model_guid, 'guid-PO-PREPNUTI',
   'okamzita cesta bez snapshotu nesie aktualny dokument');

// Prazdny snapshot je PLATNA hodnota — panel bez dobehnuteho NX.init naplanoval
// edit a server ho ma odmietnut; NESMIE sa „opravit" na aktualny guid.
eq(JSON.parse(nxDocPayload({}, '')).model_guid, '', 'prazdny snapshot ostava prazdny');
// null/undefined = „nemam snapshot" -> aktualna identita (okamzite cesty).
eq(JSON.parse(nxDocPayload({}, null)).model_guid, 'guid-PO-PREPNUTI', 'null = aktualna identita');
eq(JSON.parse(nxDocPayload({}, undefined)).model_guid, 'guid-PO-PREPNUTI', 'undefined = aktualna identita');

// --- 7) CENTRALNE ZAHODENIE STAVU PRI ZMENE DOKUMENTU (review #264 kolo 2) --
// `nxSetModelGuid` je jediny detektor zmeny dokumentu na klientovi. Pri
// SKUTOCNEJ zmene hodnoty musi zahodit vsetok rozpracovany stav panela; echo
// push toho isteho dokumentu NESMIE zahodit nic (rozpisana praca musi prezit).
//
// Cleanupy ziju v inych suboroch (form.js, board_card.js, bridge.js, part_card.js)
// a v Node nie su nacitane — `nxDropDocState` ich preto vola cez `typeof`
// a v tomto teste sa overuje, ze volanie NEPADNE a ze sa spusti prave vtedy,
// ked sa guid naozaj zmenil. Zoznam mien strazi pure sada.
const nxDropDocState = NXShell.nxDropDocState;
eq(typeof nxDropDocState, 'function', 'centralne zahodenie stavu je exportovane');
nxDropDocState(); // ziadny z cleanupov nie je v Node definovany — nesmie padnut
n++;

// Zmena hodnoty = drop; rovnaka hodnota = ziadny drop. Merame cez to, ci sa
// identita naozaj prepisala (drop sam o sebe v Node nic viditelne nerobi).
nxSetModelGuid('guid-X');
eq(nxDocGuid(), 'guid-X', 'nova hodnota sa zapise');
nxSetModelGuid('guid-X');
eq(nxDocGuid(), 'guid-X', 'echo push tej istej identity ju nemeni');
nxSetModelGuid('guid-Y');
eq(nxDocGuid(), 'guid-Y', 'prepnutie dokumentu identitu prepise');

// --- 8) SCENARE „prepnutie MEDZI naplanovanim a odoslanim" ------------------
// Zrkadlia vzor, ktory pouzivaju vsetky pending buffery: zachyt identitu pri
// naplanovani, posli ju s payloadom. Ak by sa citala az pri odosielani, kazdy
// z tychto zapisov by pristal v cudzej zakazke.
function pendingScenario(scheduleGuid, switchTo, payload){
  nxSetModelGuid(scheduleGuid);
  const snap = nxDocGuid();          // buffer si zachyti dokument
  nxSetModelGuid(switchTo);          // pouzivatel prepol dokument
  return JSON.parse(nxDocPayload(payload, snap)).model_guid;
}
eq(pendingScenario('doc-A', 'doc-B', { cabinet_id: 'CAB-001' }), 'doc-A',
   'auto-apply korpusu: odlozeny zapis nesie dokument z casu naplanovania');
eq(pendingScenario('doc-A', 'doc-B', { board_id: 'BRD-001', fields: { width: 555 } }), 'doc-A',
   'polia karty dosky: batch nesie dokument z casu naplanovania');
eq(pendingScenario('doc-A', 'doc-B', { cabinet_id: 'CAB-001', name: 'Skrinka' }), 'doc-A',
   'premenovanie: Enter posle dokument z casu otvorenia editora');
eq(pendingScenario('doc-A', 'doc-B', { board_id: 'BRD-001', create_missing_abs: true }), 'doc-A',
   'modal chybajucej ABS: rozhodnutie nesie dokument z casu otvorenia');

// Rovnaky dokument (ziadne prepnutie) = zachyteny aj aktualny su zhodne —
// bezny pripad nesmie skoncit zbytocnym odmietnutim.
eq(pendingScenario('doc-A', 'doc-A', { cabinet_id: 'CAB-001' }), 'doc-A',
   'bez prepnutia sa nic nemeni (ziadne falosne odmietnutie)');

// --- 9) DROP SA SPUSTI PRESNE PRI ZMENE DOKUMENTU (review #264 kolo 3) ------
// `nxDropDocState` hlada cleanupy cez `typeof <meno>` — nedeklarovany
// identifikator sa v CommonJS module rozvija po scope chain az na `globalThis`,
// takze sa daju nainstalovat SKUTOCNE spy funkcie a overit, ze sa drop spusti
// len vtedy, ked sa dokument naozaj zmenil.
let dropped = 0;
global.cancelCabinetEdits = function(){ dropped++; };

nxSetModelGuid('doc-1');
eq(dropped, 1, 'prva zmena dokumentu zahodi rozpracovany stav');
nxSetModelGuid('doc-1');
eq(dropped, 1, 'echo push tej istej identity NEZAHADZUJE rozpisanu pracu');
nxSetModelGuid('doc-2');
eq(dropped, 2, 'prepnutie dokumentu zahodi stav znova');
nxSetModelGuid(undefined);
nxSetModelGuid(null);
eq(dropped, 2, 'payload bez identity nic nezahadzuje (a identitu nemaze)');
eq(nxDocGuid(), 'doc-2', 'identita po chybajucej hodnote drzi');
delete global.cancelCabinetEdits;

// --- 10) PODMIENKA „zachovaj rozpisane riadky ciel" ------------------------
// Zrkadlo pravidla z `bridge.js` (`keepGaps`). Rozhodnutie stoji na TROCH
// veciach a dokument je jednou z nich — `CAB-001` je v kazdej zakazke, takze
// bez neho by sa riadky ciel z jedneho dokumentu zachovali v druhom a prvy
// dalsi edit by ich odoslal s NOVYM guidom (server by ich prijal do zlej
// zakazky). Presne toto je nalez kola 3.
function keepGaps(pushGuid, curGuid, pushCab, curCab, pending){
  return (String(pushGuid) === String(curGuid)) && !!(pushCab && pushCab === curCab) && !!pending;
}
eq(keepGaps('doc-A', 'doc-A', 'CAB-001', 'CAB-001', true), true,
   'echo push toho isteho dokumentu a skrinky: rozpisane riadky PREZIJU');
eq(keepGaps('doc-B', 'doc-A', 'CAB-001', 'CAB-001', true), false,
   'iny dokument s ROVNAKYM cabinet_id: riadky NEPREZIJU');
eq(keepGaps('doc-A', 'doc-A', 'CAB-002', 'CAB-001', true), false,
   'ina skrinka v tom istom dokumente: riadky NEPREZIJU');
eq(keepGaps('doc-A', 'doc-A', 'CAB-001', 'CAB-001', false), false,
   'bez rozpisanych editov niet co zachovavat');

console.log(`OK test_r02_doc_guard.js — ${n} kontrol`);
