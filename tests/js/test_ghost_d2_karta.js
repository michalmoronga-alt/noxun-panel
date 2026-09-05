// GHOST-D2 — TLAČIDLO „Nakresliť" a ZÁMKY FÁZ v payloade (klient).
//
// Prečo je to test a nie klikanie:
//   1. `NXInsert.boardLocks` je SÚKROMNÝ stav klienta („NIKDY do Ruby") —
//      do servera smie ísť len ČÍSELNÝ snapshot `locksFlat('board')`.
//      Regresia (poslať celý objekt, alebo Boolean „je zamknuté") by
//      znamenala, že zamknutá fáza dostane nezmysel a doska vznikne s inými
//      rozmermi, než používateľ zamkol.
//   2. Zámok z toho, že pole MÁ hodnotu, NEEXISTUJE — polia sú vždy
//      predvyplnené 800 × 600, takže „má hodnotu" by zamklo obe fázy vždy.
//   3. Kreslenie ide VLASTNÝM callbackom (`draw_board`), nie `insert_board`.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXInsert = require(path.join(JS, 'insert_state.js'));

// `board_card.js` číta `el()` a `MATERIALS` z CEF prostredia — v Node ich
// dodáme rovnako ako ostatné sady (payload builder je čistá funkcia).
global.el = function(){ return null; };
global.MATERIALS = { sheets: [] };
const BC = require(path.join(JS, 'board_card.js'));

// --- 1) `locksFlat('board')` vracia HODNOTY, nie príznaky --------------------
NXInsert.clearLock('length', 'board');
NXInsert.clearLock('width', 'board');
eq(NXInsert.locksFlat('board'), {}, 'bez zámkov je mapa PRÁZDNA');
NXInsert.setLock('length', 800, 'board');
eq(NXInsert.locksFlat('board'), { length: 800 }, 'zamknutá dĺžka ide ako ČÍSLO');
ok(!Object.prototype.hasOwnProperty.call(NXInsert.locksFlat('board'), 'width'),
   'nezamknutý kľúč v mape CHÝBA (žiadny `false`)');
NXInsert.setLock('width', 600, 'board');
eq(NXInsert.locksFlat('board'), { length: 800, width: 600 }, 'obe zamknuté');

// Doskový a korpusový sklad sú oddelené — meno `width` je v oboch, ale
// znamená inú veličinu.
NXInsert.setLock('width', 950, 'cabinet');
eq(NXInsert.locksFlat('board').width, 600, 'korpusový zámok doskový neprepíše');

// --- 2) payload `draw_board` nesie ČÍSELNÝ snapshot --------------------------
const base = { name: '', length: 800, width: 600, material_id: 'K009', orientation: 'leziaca' };
let p = BC.buildDrawBoardPayload(Object.assign({}, base), NXInsert.locksFlat('board'));
eq(p.locks, { length: 800, width: 600 }, 'zámky idú SAMOSTATNÝM poľom');
eq(p.length, 800, 'ostatné polia payloadu ostávajú');
eq(p.orientation, 'leziaca');

// --- 3) SÚKROMNÝ tvar zámkov sa do Ruby NEDOSTANE ---------------------------
// Toto je presne to, čo `NXInsert.boardLocks` drží interne.
p = BC.buildDrawBoardPayload({}, { length: { locked: true, value: 800 } });
eq(p.locks, {}, 'vnútorný objekt {locked, value} sa ZAHODÍ (nie je to číslo)');
p = BC.buildDrawBoardPayload({}, { length: true, width: false });
eq(p.locks, {}, 'Boolean „je zamknuté" sa ZAHODÍ — zámok je HODNOTA');
p = BC.buildDrawBoardPayload({}, { length: '800' });
eq(p.locks, {}, 'text sa ZAHODÍ (server ho odmieta tiež)');
p = BC.buildDrawBoardPayload({}, { length: NaN, width: Infinity });
eq(p.locks, {}, 'NaN ani Infinity sa neposielajú');

// --- 4) cudzie kľúče sa neprenášajú -----------------------------------------
p = BC.buildDrawBoardPayload({}, { length: 800, thickness: 25, height: 700, evil: 1 });
eq(p.locks, { length: 800 }, 'whitelist klienta je length/width (server ho zopakuje)');

// --- 5) prázdne / chýbajúce zámky ------------------------------------------
p = BC.buildDrawBoardPayload({}, null);
eq(p.locks, {}, 'chýbajúce zámky = prázdna mapa, nie `undefined`');
p = BC.buildDrawBoardPayload(null, { width: 450 });
eq(p.locks, { width: 450 }, 'prázdny payload nepadne');

// --- 6) kreslenie ide VLASTNÝM callbackom -----------------------------------
const fs = require('node:fs');
const cardSrc = fs.readFileSync(path.join(JS, 'board_card.js'), 'utf8');
ok(cardSrc.indexOf('sketchup.draw_board(nxDocPayload(payload))') >= 0,
   'drawBoard() volá `draw_board`, nie `insert_board`');
ok(cardSrc.indexOf('sketchup.insert_board(nxDocPayload(res.payload))') >= 0,
   'insertBoard() ostal na `insert_board` (D1 sa nemení)');
ok(cardSrc.indexOf("NXInsert.locksFlat('board')") >= 0,
   'zámky idú cez existujúci `locksFlat`, nie cez vlastný prevod');

const htmlSrc = fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'panel.html'), 'utf8');
ok(htmlSrc.indexOf('id="insertDrawBoard" onclick="drawBoard()"') >= 0,
   'karta má tlačidlo „Nakresliť"');
const rowStart = htmlSrc.indexOf('<div id="insertGoRow">');
const row = htmlSrc.slice(rowStart, htmlSrc.indexOf('</div>', rowStart));
ok(row.indexOf('insertGoBoard') >= 0 && row.indexOf('insertDrawBoard') >= 0,
   'obe doskové tlačidlá stoja v JEDNOM riadku (pásik ani karta nerastú o riadok)');

const cssSrc = fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'css', 'panel.css'), 'utf8');
ok(cssSrc.indexOf('body:not([data-insert-kind="board"]) #insertDrawBoard { display: none; }') >= 0,
   'pri korpuse „Nakresliť" nie je');

console.log('OK ' + n + ' asserts (GHOST-D2 karta a zámky)');
