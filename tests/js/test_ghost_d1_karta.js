// GHOST-D1 — KARTA DOSKY Z NOVŠEJ VERZIE je READ-ONLY (klient).
//
// Preco je to test a nie klikanie (Codex #298 P2):
//   STANDARD 8.3 slubuje, ze doska z novsieho pluginu sa ZOBRAZI, ale
//   NEUPRAVI — a povie preco. Zapisove cesty su chranene serverom
//   (`guarded_board`), takze bez tejto vrstvy by karta vyzerala normalne,
//   pouzivatel by pisal do poli a kazdy pokus by skoncil cervenou hlaskou.
//   Regresia by sa navyse prejavila az u zakaznika s novsou zakazkou.
//
// Kontrakt: o zamku rozhoduje VYHRADNE server (`newer_config`), text posiela
// tiez server (`newer_config_note`) — klient si neodvodzuje ani jedno.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));

// Kostra karty dosky — 1:1 s `panel.html` (id-cka su kontrakt HTML <-> JS).
const CARD = mkEl('fieldset');
CARD.attrs.id = 'boardCard';
CARD.innerHTML =
  '<div class="pchead" id="bcHead"></div>' +
  '<div class="bcnewer" id="bcNewer"></div>' +
  '<div class="row"><input id="bc_name" type="text"></div>' +
  '<div class="row"><input id="bc_length" type="text"></div>' +
  '<div class="row"><input id="bc_width" type="text"></div>' +
  '<div class="row"><select id="bc_material"></select>' +
  '<button type="button" id="bcMatLink"></button></div>' +
  '<div class="row"><input id="bc_thickness" type="text"></div>' +
  '<div class="row"><select id="bc_grain"></select></div>' +
  '<div class="segrow" id="boardOriRow">' +
  '<button type="button" data-bc-ori="leziaca"></button>' +
  '<button type="button" data-bc-ori="stojaca"></button>' +
  '<button type="button" data-bc-ori="na_stenu"></button></div>' +
  '<div id="boardEdgeRows"><select id="bc_edge_L1"></select></div>';
DOC.body.appendChild(CARD);

// `el` zije v core.js; v Node ho dodame rovnako, ako ho v CEF vidi board_card.js.
global.el = function(id){ return DOC.getElementById(id); };

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const BC = require(path.join(JS, 'board_card.js'));

function controls(){
  return DOC.getElementById('boardCard').querySelectorAll('input, select, textarea, button')
            .filter(function(x){ return x.attrs.id !== 'bcNewer'; });
}
function allDisabled(){ return controls().every(function(x){ return x.disabled === true; }); }
function noneDisabled(){ return controls().every(function(x){ return x.disabled === false; }); }

// --- 1) BEZNA doska: karta je normalne editovatelna --------------------------
eq(BC.applyBoardReadOnly({ board_id: 'BRD-001' }), false, 'bez priznaku sa nic nezamyka');
ok(noneDisabled(), 'vsetky ovladace ostavaju zive');
eq(DOC.getElementById('bcNewer').hidden, true, 'upozornenie sa nekresli');
eq(DOC.getElementById('bcNewer').textContent, '', 'a nema ani text');

// --- 2) Doska z NOVSEJ verzie: cela karta stichne + povie PRECO --------------
const NOTE = 'Doska je z novšej verzie Noxun — tento plugin jej nastavenia nepozná celé, ' +
             'preto sa nedá upraviť. Aktualizuj plugin.';
eq(BC.applyBoardReadOnly({ board_id: 'BRD-002', newer_config: true, newer_config_note: NOTE }),
   true, 'priznak zo servera zamkne kartu');
ok(allDisabled(), 'nazov, rozmery, material, hrubka, smer, umiestnenie aj hrany su ZAMKNUTE');
eq(DOC.getElementById('bcNewer').hidden, false, 'upozornenie je vidno');
eq(DOC.getElementById('bcNewer').textContent, NOTE, 'a nesie PRESNE text zo servera');
ok(DOC.getElementById('bc_name').getAttribute('aria-disabled') === 'true',
   'zamknute pole to prizna aj citackam obrazovky');
// Ziadne emoji ani ikony v texte — jazyk je slovencina, symboly patria do sprite.
ok(!/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u.test(NOTE), 'hlaska je bez emoji');

// Konkretne ovladace, na ktorych zalezi najviac (zapis do modelu aj do KATALOGU).
['bc_name', 'bc_length', 'bc_width', 'bc_material', 'bc_thickness', 'bc_grain',
 'bcMatLink', 'bc_edge_L1'].forEach(function(id){
  eq(DOC.getElementById(id).disabled, true, id + ' je zamknuty');
});
eq(DOC.getElementById('boardOriRow').querySelectorAll('button')
      .every(function(b){ return b.disabled === true; }), true,
   'aj segmenty umiestnenia (menia transformaciu instancie)');

// --- 3) Zamok sa PUSTI, ked pride bezna doska --------------------------------
eq(BC.applyBoardReadOnly({ board_id: 'BRD-003' }), false, 'nasledujuci vyber odomkne');
ok(noneDisabled(), 'karta je zase pouzitelna');
eq(DOC.getElementById('bcNewer').hidden, true, 'a upozornenie zmizlo');
ok(!DOC.getElementById('bc_name').getAttribute('aria-disabled'),
   'priznak pre citacky sa odstranil');

// --- 4) Klient si zamok NEODVODZUJE ------------------------------------------
// Iba `newer_config === true` zamyka: chybajuci kluc, `false` ani „truthy"
// retazec nesmu kartu umlcat (server je jedina autorita, zrkadlo Materials.uni?).
eq(BC.applyBoardReadOnly({ newer_config: false }), false, 'false nezamyka');
eq(BC.applyBoardReadOnly({}), false, 'chybajuci kluc nezamyka');
eq(BC.applyBoardReadOnly(null), false, 'prazdna karta nepadne');
ok(noneDisabled(), 'a nic z toho ovladace nezamklo');

console.log('OK ' + n + ' asserts (GHOST-D1 read-only karta dosky)');
