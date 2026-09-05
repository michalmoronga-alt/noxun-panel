// GHOST-D1 — GHOST PASIK pre SUBJEKT DOSKA (klient).
//
// Preco su to testy a nie klikanie:
//   1. Pasik ma pre dosku ukazat NIECO INE nez pre skrinku: kabinetove
//      ovladace vysky (`gbMode`, `gbLockWrap`) sa musia SCHOVAT a na ich
//      mieste stat UMIESTNENIE. V CEF sa to overuje tazko a regresia by sa
//      prejavila tym, ze pouzivatel doske ponuka zamok vysky, ktory server
//      aj tak odmietne.
//   2. Karta Dosky ma po ↑ ukazat nove umiestnenie HNED — ale BEZ
//      materializacie a bez resetu karty (rozpisane rozmery, material a
//      sablona musia prezit). To je presne to, co sa da overit len tu.
//   3. `ghost_lock_z` sa pre dosku z JS nesmie poslat NIKDY (skryte pole nie
//      je ochrana — server ma vlastny guard subjektu).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));

// Most do Ruby: zachytavame, co by pasik poslal serveru.
const SENT = [];
global.sketchup = new Proxy({}, {
  get: function(_t, name){
    return function(json){ SENT.push([String(name), JSON.parse(json)]); };
  },
  has: function(){ return true; }
});
global.window.sketchup = global.sketchup;
global.nxDocPayload = function(obj){
  const o = obj || {};
  o.model_guid = 'GUID-1';
  return JSON.stringify(o);
};
const STATUS = [];
global.NX = { setStatus: function(msg, err){ STATUS.push([msg, !!err]); } };

// Kostra pasika — 1:1 s `panel.html` (id-cka su kontrakt medzi HTML a JS).
const BAR = mkEl('div');
BAR.attrs.id = 'ghostBar';
BAR.attrs.class = 'ghostbar';
BAR.hidden = true;
BAR.innerHTML =
  '<span class="gbanchor" id="gbAnchor">' +
  '<span class="gbdot" data-anchor="fl_top"></span><span class="gbdot" data-anchor="fr_top"></span>' +
  '<span class="gbdot" data-anchor="fl_bottom"></span><span class="gbdot" data-anchor="fr_bottom"></span>' +
  '</span>' +
  '<span class="gbtxt" id="gbRot">0°</span><span class="gbtxt" id="gbMode">zámok</span>' +
  '<span class="gbtxt gbori" id="gbOri"></span>' +
  '<span class="gblock" id="gbLockWrap"><input id="gbLockZ" type="text"><span class="unit">mm</span></span>' +
  '<button class="gbinfo" id="gbInfo"></button>';
DOC.body.appendChild(BAR);

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXInsert = require(path.join(JS, 'insert_state.js'));
global.NXInsert = NXInsert;
// Zrkadlo segmentov karty (board_card.js). Testy overuju, ze sa VOLA — a ze
// sa pritom NEVOLA materializacia karty.
let SYNCED = 0;
global.syncInsertOrientation = function(){ SYNCED++; };
const GB = require(path.join(JS, 'ghost_bar.js'));

function el(id){ return DOC.getElementById(id); }
function cabState(over){
  return Object.assign({
    active: true, type: 'lower', subject: 'cabinet', interaction: 'placement',
    anchor: 'fl_bottom', anchor_label: 'ľavá dolná',
    rotation: 0, z_mode: 'locked', lock_z: 0, orientation: '', orientation_label: ''
  }, over || {});
}
function boardState(over){
  return Object.assign({
    active: true, type: 'board', subject: 'board', interaction: 'placement',
    anchor: 'fl_bottom', anchor_label: 'ľavá dolná',
    rotation: 0, z_mode: 'free', lock_z: 0,
    orientation: 'leziaca', orientation_label: 'Naležato'
  }, over || {});
}

// --- 1) subjekt: staršie payloady bez neho su SKRINKA ------------------------
eq(GB.subject({ active: true }), 'cabinet', 'payload bez subjektu = skrinka (spravanie pred GHOST-D1)');
eq(GB.subject(boardState()), 'board', 'doska sa rozpozna');
eq(GB.subject(null), 'cabinet', 'prazdny stav nepadne');

// --- 2) SKRINKA: pasik ostava presne taky, aky bol ---------------------------
GB.apply(cabState());
eq(el('gbMode').hidden, false, 'skrinka: rezim vysky je vidno');
eq(el('gbLockWrap').hidden, false, 'skrinka: pole zamku je vidno');
eq(el('gbOri').hidden, true, 'skrinka: umiestnenie sa NEKRESLI');
eq(el('gbMode').textContent, 'zámok výšky', 'skrinka: popisok rezimu');
ok(String(el('gbInfo').getAttribute('title')).indexOf('zámok výšky') >= 0,
   'skrinka: napoveda hovori o zamku vysky');

// --- 3) DOSKA: ovladace vysky prec, umiestnenie na ich mieste ----------------
GB.apply(boardState());
eq(el('gbMode').hidden, true, 'doska: rezim vysky je SKRYTY');
eq(el('gbLockWrap').hidden, true, 'doska: pole zamku je SKRYTE');
eq(el('gbOri').hidden, false, 'doska: umiestnenie je vidno');
eq(el('gbOri').textContent, 'Naležato', 'doska: popisok umiestnenia zo servera');
ok(String(el('gbInfo').getAttribute('title')).indexOf('umiestnenie') >= 0,
   'doska: napoveda hovori o umiestneni, nie o zamku vysky');
ok(String(el('gbInfo').getAttribute('title')).indexOf('zámok výšky') < 0,
   'doska: napoveda zamok vysky NESPOMINA');
// Kotva a rotacia su spolocne — kresli ich rovnaky kod ako pri skrinke.
GB.apply(boardState({ anchor: 'fr_top', anchor_label: 'pravá horná', rotation: 90 }));
eq(el('gbRot').textContent, '90°', 'doska: rotacia sa kresli rovnako');
ok(String(el('gbAnchor').getAttribute('aria-label')).indexOf('pravá horná') >= 0,
   'doska: kotva sa kresli rovnako');

// Popisok umiestnenia: server posle `orientation_label`, klient ma fallback.
eq(GB.oriLabel({ orientation: 'stojaca' }), 'Nastojato', 'fallback popisku bez servera');
eq(GB.oriLabel({ orientation: 'na_stenu' }), 'Na stenu', 'fallback popisku — na stenu');
eq(GB.oriLabel({ orientation: 'zavesena' }), '',
   'neznama hodnota (config z novsej verzie) NEKLAME — pasik radsej mlci');

// --- 4) synchronizacia s kartou: BEZ materializacie a resetu -----------------
// Karta zacina naležato a ma rozpisany draft (rozmery, material, sablona).
NXInsert.setBoardOrientation('leziaca');
NXInsert.setTemplateName('board', 'Pracovná doska');
const beforeTpl = NXInsert.templateName('board');
SYNCED = 0;
GB.apply(boardState({ orientation: 'stojaca', orientation_label: 'Nastojato' }));
eq(NXInsert.boardOrientation(), 'stojaca', '↑ v modeli prestavi umiestnenie aj v karte');
eq(SYNCED, 1, 'segmenty karty sa prekreslili PRESNE RAZ');
eq(NXInsert.templateName('board'), beforeTpl, 'sablona karty prezila (ziadny reset)');
// Opakovany push s tou istou hodnotou uz kartu nehybe (ziadny zbytocny render).
SYNCED = 0;
GB.apply(boardState({ orientation: 'stojaca', orientation_label: 'Nastojato' }));
eq(SYNCED, 0, 'nezmenene umiestnenie kartu neprekresluje');
eq(GB.syncCard({ orientation: '' }), false, 'prazdna hodnota sa nesynchronizuje');

// --- 5) `ghost_lock_z` sa pre dosku NEPOSIELA NIKDY --------------------------
GB.apply(boardState());
SENT.length = 0;
el('gbLockZ').value = '1400';
GB.onLockZ();
eq(SENT.length, 0, 'doska: pole vysky neposiela nic (skryte pole nie je ochrana)');

// Po prepnuti spat na skrinku pole zase funguje — subjekt je jediny rozlisovac.
GB.apply(cabState({ lock_z: 0 }));
SENT.length = 0;
el('gbLockZ').value = '1400';
GB.onLockZ();
eq(SENT.length, 1, 'skrinka: pole vysky posiela dalej');
eq(SENT[0][0], 'ghost_lock_z', 'a je to ten isty callback ako pred GHOST-D1');
eq(SENT[0][1].lock_z, 1400, 's hodnotou z pola');

// --- 6) koniec session: pasik zmizne celý ------------------------------------
GB.apply({ active: false });
eq(el('ghostBar').hidden, true, 'po konci session pasik zmizne (vertikalny priestor je vzacny)');

console.log('OK ' + n + ' asserts (GHOST-D1 pasik dosky)');
