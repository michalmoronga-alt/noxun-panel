// GHOST-D2 — GHOST PÁSIK pri KRESLENÍ dosky (klient).
//
// Prečo je to test a nie klikanie:
//   1. Pri kreslení je počiatok PEVNÁ kotva (Alt nemá význam), takže
//      kotvové bodky musia zmiznúť a na ich mieste má stáť FÁZA s hodnotou.
//      Regresia by znamenala, že pásik ponúka kotvu, ktorú server ignoruje —
//      alebo že narastie o riadok (vertikálny priestor je vzácny).
//   2. Pásik je JEDINÉ miesto, kde používateľ počas ťahu vidí, čo práve
//      meria. Bez fázy by nevedel, či ťahá dĺžku alebo šírku.
//   3. `ghost_lock_z` sa pri kreslení nesmie poslať NIKDY (skryté pole nie
//      je ochrana — server má vlastný guard subjektu).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));

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
global.NX = { setStatus: function(){} };

// Kostra pásika — 1:1 s `panel.html` (id-čka sú kontrakt HTML <-> JS).
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
  '<span class="gbtxt gbphase" id="gbPhase"></span>' +
  '<span class="gblock" id="gbLockWrap"><input id="gbLockZ" type="text"><span class="unit">mm</span></span>' +
  '<button class="gbinfo" id="gbInfo"></button>';
DOC.body.appendChild(BAR);

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXInsert = require(path.join(JS, 'insert_state.js'));
global.NXInsert = NXInsert;
global.syncInsertOrientation = function(){};
const GB = require(path.join(JS, 'ghost_bar.js'));

function el(id){ return DOC.getElementById(id); }
function placeState(over){
  return Object.assign({
    active: true, type: 'board', subject: 'board', interaction: 'placement',
    anchor: 'fl_bottom', anchor_label: 'ľavá dolná',
    rotation: 0, z_mode: 'free', lock_z: 0,
    orientation: 'leziaca', orientation_label: 'Naležato'
  }, over || {});
}
function drawState(over){
  return Object.assign(placeState(), {
    interaction: 'drawing', phase: 'length', phase_label: 'Dĺžka',
    phase_value: 2400, phase_locked: false
  }, over || {});
}

// --- 1) rozlíšenie interakcie -----------------------------------------------
eq(GB.drawing(placeState()), false, 'umiestňovanie NIE JE kreslenie');
eq(GB.drawing(drawState()), true, 'kreslenie sa rozpozná podľa `interaction`');
eq(GB.drawing({ active: true, subject: 'board' }), false,
   'starší payload bez `interaction` = umiestňovanie (správanie pred D2)');
eq(GB.drawing(null), false, 'prázdny stav nepadne');

// --- 2) UMIESTŇOVANIE ostáva presne také, aké bolo po D1 ---------------------
GB.apply(placeState());
eq(el('gbAnchor').hidden, false, 'umiestňovanie: kotvové bodky sú vidno');
eq(el('gbPhase').hidden, true, 'umiestňovanie: fáza sa nekreslí');
eq(el('gbOri').hidden, false, 'umiestňovanie: umiestnenie je vidno');
eq(el('gbMode').hidden, true, 'doska nemá režim výšky (D1)');

// --- 3) KRESLENIE: kotva preč, fáza na jej mieste ----------------------------
GB.apply(drawState());
eq(el('gbAnchor').hidden, true, 'kreslenie: kotvové bodky sú SKRYTÉ (počiatok je pevný)');
eq(el('gbPhase').hidden, false, 'kreslenie: fáza je vidno');
eq(el('gbPhase').textContent, 'Dĺžka 2400 mm', 'fáza nesie názov aj hodnotu');
eq(el('gbLockWrap').hidden, true, 'kreslenie: pole zámku výšky je skryté');
eq(el('gbMode').hidden, true, 'kreslenie: režim výšky je skrytý');
eq(el('gbOri').hidden, false, 'kreslenie: umiestnenie ostáva (menilo sa pred prvým klikom)');

// --- 4) text fázy vo všetkých stavoch ---------------------------------------
eq(GB.phaseText(drawState({ phase: 'origin' })), 'Počiatok', 'pred klikom počiatku');
eq(GB.phaseText(drawState({ phase: 'width', phase_label: 'Šírka', phase_value: 600 })),
   'Šírka 600 mm', 'druhý ťah');
eq(GB.phaseText(drawState({ phase_value: null })), 'Dĺžka — mm',
   'kým hodnota nie je známa, pásik NEKLAME nulou');
eq(GB.phaseText(drawState({ phase_value: 600.5 })), 'Dĺžka 600,5 mm',
   'desatinné číslo v slovenskom tvare');
eq(GB.phaseText(drawState({ phase_locked: true, phase_value: 800 })),
   'Dĺžka 800 mm (zamknutá)', 'zamknutá fáza to PRIZNÁ (ťah sa preskočí)');
eq(GB.phaseText(drawState({ phase: 'done' })), 'Hotovo', 'obe hodnoty známe');
eq(GB.phaseText(placeState()), '', 'v umiestňovaní fáza neexistuje');
// Popisok fázy má fallback, keby ho server neposlal (staršia verzia payloadu).
eq(GB.phaseText(drawState({ phase_label: '', phase_value: 900 })), 'Dĺžka 900 mm',
   'fallback popisku fázy');

// --- 5) nápoveda „i" je pre kreslenie vlastná --------------------------------
GB.apply(drawState());
const help = String(el('gbInfo').getAttribute('title'));
ok(help.indexOf('počiatok') >= 0, 'nápoveda hovorí o počiatku');
ok(help.indexOf('Enter') >= 0, 'a o meracom poli');
ok(help.indexOf('Alt') < 0, 'Alt v kreslení význam NEMÁ, takže sa nespomína');
GB.apply(placeState());
ok(String(el('gbInfo').getAttribute('title')).indexOf('Alt') >= 0,
   'v umiestňovaní Alt ostáva');

// --- 6) `ghost_lock_z` sa pri kreslení NEPOSIELA -----------------------------
GB.apply(drawState());
SENT.length = 0;
el('gbLockZ').value = '1400';
GB.onLockZ();
eq(SENT.length, 0, 'kreslenie: pole výšky neposiela nič');

// --- 7) koniec session: pásik zmizne celý ------------------------------------
GB.apply({ active: false });
eq(el('ghostBar').hidden, true, 'po konci session pásik zmizne');

console.log('OK ' + n + ' asserts (GHOST-D2 pásik kreslenia)');
