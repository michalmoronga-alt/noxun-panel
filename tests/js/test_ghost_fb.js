// GHOST-FB4 — GHOST PASIK vkladacej karty (klient).
//
// Preco su to testy a nie klikanie:
//   1. Pasik NESMIE byt trvalou castou panela — vertikalny priestor je vzacny.
//      Ze po konci session naozaj zmizne, sa v CEF overuje tazko a regresia by
//      sa prejavila az tym, ze v paneli trvalo visi mrtvy riadok.
//   2. Validacia rucne zadanej vysky musi byt ZRKADLOM Ruby
//      (`GhostTool::Calc.lock_z_value`): necislo ani hodnota mimo rozsahu
//      nesmie odist na server a pole sa musi vratit na poslednu PLATNU
//      hodnotu — nikdy nespadnut na 0 (to by ticho polozilo skrinku na zem).
//   3. Payload pola nesie identitu DOKUMENTU (R-02) — bez nej by pole
//      prestavovalo ghost v cudzej zakazke.
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
// Identita dokumentu — v paneli ju dodava shell.js (nxDocPayload).
global.nxDocPayload = function(obj, guid){
  const o = obj || {};
  o.model_guid = (guid === undefined || guid === null) ? 'GUID-1' : String(guid);
  return JSON.stringify(o);
};
// Status panela (bridge.js) — pri neplatnej hodnote sa musi ozvat.
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
  '<span class="gblock" id="gbLockWrap"><input id="gbLockZ" type="text"><span class="unit">mm</span></span>';
DOC.body.appendChild(BAR);

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const GB = require(path.join(JS, 'ghost_bar.js'));

function state(over){
  return Object.assign({
    active: true, type: 'lower', anchor: 'fl_bottom', anchor_label: 'ľavá dolná',
    rotation: 0, z_mode: 'locked', lock_z: 0
  }, over || {});
}
function el(id){ return DOC.getElementById(id); }
function activeDot(){
  const d = el('gbAnchor').querySelectorAll('.gbdot').filter(function(x){
    return String(x.attrs.class || '').split(/\s+/).indexOf('on') >= 0;
  });
  return d.length === 1 ? d[0].getAttribute('data-anchor') : ('POCET=' + d.length);
}

// --- 1) ciste popisky --------------------------------------------------------
eq(GB.rotLabel(0), '0°', 'nulova rotacia');
eq(GB.rotLabel(90), '90°', 'stvrtina');
eq(GB.rotLabel(270), '270°', 'tri stvrtiny');
eq(GB.rotLabel(-90), '270°', 'zaporny uhol sa normalizuje (pasik nikdy neukaze -90°)');
eq(GB.rotLabel(360), '0°', 'plny kruh je nula');
eq(GB.rotLabel('x'), '0°', 'nezmysel nepadne, ukaze nulu');
eq(GB.modeLabel('locked'), 'zámok výšky', 'rezim zamku');
eq(GB.modeLabel('free'), 'voľná výška', 'volna vyska');
eq(GB.anchorLabel('fr_top'), 'pravá horná', 'nazov kotvy');
eq(GB.anchorLabel('nieco'), 'ľavá dolná', 'neznama kotva spadne na prvu, nie na prazdno');

// --- 2) validacia vysky = ZRKADLO Ruby --------------------------------------
eq(GB.LOCK_MIN, 0, 'dolna hranica sedi s Ruby');
eq(GB.LOCK_MAX, 3000, 'horna hranica sedi s Ruby');
eq(GB.lockValue('20'), 20, 'cele cislo');
eq(GB.lockValue('1400,5'), 1400.5, 'ciarka je desatinny oddelovac');
eq(GB.lockValue(' 850 '), 850, 'medzery okolo nevadia');
eq(GB.lockValue('0'), 0, 'nula je platna (dolna skrinka na zemi)');
eq(GB.lockValue('3000'), 3000, 'horna hranica je platna');
['', '   ', 'abc', '12abc', '-1', '3001', '1e3', null, undefined].forEach(function(bad){
  eq(GB.lockValue(bad), null, 'neplatny vstup ' + JSON.stringify(bad) + ' musi vratit null');
});
eq(GB.mm(1400), '1400', 'cele mm bez desatinnej nuly');
eq(GB.mm(20.5), '20,5', 'desatinne mm slovenskou ciarkou');

// --- 3) render stavu ---------------------------------------------------------
ok(BAR.hidden === true, 'vychodisko: pasik je skryty');
GB.apply(state());
ok(BAR.hidden === false, 'so ZIVOU session je pasik viditelny');
eq(activeDot(), 'fl_bottom', 'aktivna kotva svieti (a prave jedna)');
eq(el('gbRot').textContent, '0°', 'otocenie');
eq(el('gbMode').textContent, 'zámok výšky', 'rezim vysky');
eq(el('gbLockZ').value, '0', 'pole nesie locknutu vysku');

GB.apply(state({ anchor: 'fr_top', anchor_label: 'pravá horná', rotation: 90,
                 z_mode: 'free', lock_z: 1400 }));
eq(activeDot(), 'fr_top', 'prepnuta kotva svieti (stara zhasla)');
eq(el('gbRot').textContent, '90°', 'otocenie po sipke');
eq(el('gbMode').textContent, 'voľná výška', 'rezim po ↑');
eq(el('gbLockZ').value, '1400', 'pole drzi vysku aj vo volnom rezime');
eq(el('gbLockWrap').attrs.class, 'gblock dim', 'vo volnej vyske je pole stlmene, nie vypnute');
ok(!el('gbLockZ').hasAttribute('disabled'), 'pole ostava pouzitelne (vzor D-78)');

GB.apply(state({ z_mode: 'locked', lock_z: 20 }));
eq(el('gbLockWrap').attrs.class, 'gblock', 'v zamku je pole plne aktivne');
eq(el('gbLockZ').value, '20', 'rucne prestavena vyska');

// --- 4) koniec session pasik SCHOVA -----------------------------------------
GB.apply({ active: false });
ok(BAR.hidden === true, 'po vlozeni/Esc pasik zmizne');
GB.apply(null);
ok(BAR.hidden === true, 'prazdny push pasik tiez schova');

// --- 5) pole vysky -> Ruby ---------------------------------------------------
GB.apply(state({ lock_z: 0 }));
SENT.length = 0;
STATUS.length = 0;
el('gbLockZ').value = '20';
GB.onLockZ();
eq(SENT.length, 1, 'platna hodnota odide na server');
eq(SENT[0][0], 'ghost_lock_z', 'ide spravnym kanalom');
eq(SENT[0][1].lock_z, 20, 'server dostane cislo v mm');
eq(SENT[0][1].model_guid, 'GUID-1', 'payload nesie identitu dokumentu (R-02)');

// Necitatelna hodnota sa NEODOSIELA a pole sa vrati na poslednu PLATNU.
SENT.length = 0;
el('gbLockZ').value = 'dvadsať';
GB.onLockZ();
eq(SENT.length, 0, 'necislo sa na server nesmie dostat');
eq(el('gbLockZ').value, '0', 'pole sa vratilo na poslednu platnu hodnotu, nie na prazdno');
eq(STATUS.length, 1, 'pouzivatel dostal vysvetlenie');
ok(STATUS[0][1] === true, 'a je to chybovy status');

// Hodnota mimo rozsahu — ta ista cesta.
SENT.length = 0;
el('gbLockZ').value = '5000';
GB.onLockZ();
eq(SENT.length, 0, '5 m nie je vyska skrinky');
eq(el('gbLockZ').value, '0', 'pole drzi platnu hodnotu');

// Rovnaka hodnota = ziadny zbytocny round-trip.
SENT.length = 0;
el('gbLockZ').value = '0';
GB.onLockZ();
eq(SENT.length, 0, 'nezmenena hodnota sa neposiela');

// Bez beziacej session (pasik schovany) sa nic neposiela ani nepada —
// oneskorena udalost pola by hovorila o niecom, co uz skoncilo.
GB.apply({ active: false });
SENT.length = 0;
el('gbLockZ').value = '400';
GB.onLockZ();
eq(SENT.length, 0, 'po konci session sa uz nic neposiela');

console.log('OK ' + n + ' asserts (GHOST-FB pasik)');
