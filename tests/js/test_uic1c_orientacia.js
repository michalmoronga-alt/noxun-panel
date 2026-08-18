// UI-C1c — ORIENTACIA DOSKY, klientska cast (dependency-free Node,
// `node tests/js/test_uic1c_orientacia.js`). Pokryva to, co v CEF nevidno:
//   1) slovnik + default stavu vkladania (zrkadlo Ruby BoardBuilder::ORIENTATIONS),
//   2) FIX 8 — orientacia sa odvodi z configu sablony EXPLICITNE pri kazdej
//      materializacii; sablona bez pola aj „Bez šablóny" davaju 'leziaca',
//      takze novy vklad NEZDEDI orientaciu predosleho draftu,
//   3) insert payload nesie `orientation` VZDY (server whitelist ju ocakava),
//   4) doskova dlazdica hovori o umiestneni v TOOLTIPE (badge ostava hrubka —
//      vertikalny priestor panela je vzacny).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const ins = require(path.join(JS, 'insert_state.js'));
global.NXInsert = ins;
global.mmLabel = function (v) {
  const n = parseFloat(v);
  if (isNaN(n)) return '';
  const r = Math.round(n * 100) / 100;
  return Math.abs(r - Math.round(r)) < 0.001 ? String(Math.round(r)) : String(r).replace('.', ',');
};
const bc = require(path.join(JS, 'board_card.js'));
const fm = require(path.join(JS, 'form.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// ============ 1) SLOVNIK A STAV =============================================
eq(ins.BOARD_ORIENTATIONS, ['leziaca', 'stojaca', 'na_stenu'], 'slovnik zrkadli Ruby');
eq(ins.DEFAULT_ORIENTATION, 'leziaca', 'default je naležato');
eq(ins.boardOrientation(), 'leziaca', 'cerstvy stav zacina naležato');

eq(ins.setBoardOrientation('stojaca'), true, 'zmena hlasi true (volajuci prekresli)');
eq(ins.boardOrientation(), 'stojaca', 'stav sa zmenil');
eq(ins.setBoardOrientation('stojaca'), false, 'klik na uz zvolenu je no-op');
eq(ins.setBoardOrientation('zavesena'), true, 'neznama hodnota padne na default...');
eq(ins.boardOrientation(), 'leziaca', '...a stav je naležato (slovnik drzi klient)');
eq(ins.setBoardOrientation(undefined), false, 'undefined pri uz nastavenom defaulte nic nemeni');

// ============ 2) FIX 8 — ORIENTACIA PRI KAZDEJ MATERIALIZACII ===============
eq(ins.orientationOf({ orientation: 'na_stenu' }), 'na_stenu', 'sablona s orientaciou');
eq(ins.orientationOf({ orientation: 'stojaca' }), 'stojaca', 'sablona s orientaciou 2');
eq(ins.orientationOf({ thickness: 18 }), 'leziaca', 'sablona BEZ pola = naležato');
eq(ins.orientationOf(null), 'leziaca', '„Bez šablóny" = naležato');
eq(ins.orientationOf({}), 'leziaca', 'prazdny config = naležato');
eq(ins.orientationOf({ orientation: '' }), 'leziaca', 'prazdny retazec = naležato');
eq(ins.orientationOf({ orientation: 'zavesena' }), 'leziaca',
  'hodnota z novsej verzie sa vo VKLADANI degraduje na naležato (server je autorita)');

// Realny sled: vyber stojacej sablony -> prechod na „Bez šablóny" NESMIE
// stojacu orientaciu zdedit (presne tá pasca, ktoru FIX 8 zatvara).
ins.setBoardOrientation(ins.orientationOf({ orientation: 'stojaca' }));
eq(ins.boardOrientation(), 'stojaca', 'sablona nastavila stojacu');
ins.setBoardOrientation(ins.orientationOf(null));
eq(ins.boardOrientation(), 'leziaca', '„Bez šablóny" vratila naležato');

// ============ 3) INSERT PAYLOAD =============================================
const base = { name: 'D', length: '800', width: '600', material_id: 'K009_18', grain_direction: 'length' };
const evalFn = (s) => parseFloat(s);

let r = bc.buildInsertBoardPayload(Object.assign({}, base, { orientation: 'na_stenu' }), null, evalFn);
eq(r.ok, true, 'payload sa poskladal');
eq(r.payload.orientation, 'na_stenu', 'orientacia je v payloade');
eq(r.payload.length, 800, 'rozmery nedotknute');

r = bc.buildInsertBoardPayload(Object.assign({}, base, { orientation: 'leziaca' }), null, evalFn);
eq(r.payload.orientation, 'leziaca', 'default sa posiela EXPLICITNE (nie vynechanim kluca)');
eq(Object.prototype.hasOwnProperty.call(r.payload, 'orientation'), true, 'kluc je v payloade vzdy');

r = bc.buildInsertBoardPayload(base, null, evalFn);
eq(r.payload.orientation, '', 'chybajuca hodnota sa NEDOMYSLA — server dosadi default');

// Chybny rozmer payload zhodi este pred orientaciou (poradie validacii).
r = bc.buildInsertBoardPayload(Object.assign({}, base, { length: 'x', orientation: 'stojaca' }), null,
  (s) => (s === 'x' ? NaN : parseFloat(s)));
eq(r.ok, false, 'neplatny rozmer odmietne cely payload');

// ============ 4) DLAZDICE SABLON ============================================
eq(fm.nxTplOrientationNote({ kind: 'board', config: { orientation: 'stojaca' } }), 'nastojato',
  'doskova dlazdica pozna umiestnenie');
eq(fm.nxTplOrientationNote({ kind: 'board', config: { orientation: 'na_stenu' } }), 'na stenu',
  'zastena ide na stenu');
eq(fm.nxTplOrientationNote({ kind: 'board', config: {} }), '',
  'sablona bez orientacie ziadnu poznamku nema');
eq(fm.nxTplOrientationNote({ kind: 'board', config: { orientation: 'zavesena' } }), '',
  'neznama hodnota sa v UI nepomenuva');
eq(fm.nxTplOrientationNote({ kind: 'cabinet', config: { orientation: 'stojaca' } }), '',
  'korpusova sablona umiestnenie dosky nema');

eq(fm.nxTplTitle({ name: 'Zástena', kind: 'board', config: { orientation: 'na_stenu' } }),
  'Zástena · na stenu — klik = vybrať · dvojklik = vlož hneď', 'tooltip doskovej dlazdice');
eq(fm.nxTplTitle({ name: 'Dolna klasik', kind: 'cabinet', config: { type: 'lower' } }),
  'Dolna klasik — klik = vybrať · dvojklik = vlož hneď', 'tooltip korpusovej dlazdice');

// Badge ostava HRUBKA — orientacia dlazdicu nepredlzuje (vertikalny priestor).
eq(fm.nxTplBadge({ kind: 'board', config: { thickness: 10, orientation: 'na_stenu' } }), '10 mm',
  'badge nesie hrubku, nie orientaciu');

console.log(JSON.stringify({ passed: n, failed: 0 }));
