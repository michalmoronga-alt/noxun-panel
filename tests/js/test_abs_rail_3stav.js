// Testy „ABS kontrola v raile: 3-stavove nastavenie" (v0.7.28).
//
// Kontrakt davky: rohovy trojuholnik pri ABS ikone otvara TO ISTE nastavenie,
// ktore ma okno Vyroba pod chevronom — NIE druhu kopiu. Preto je markup aj
// payload v JEDNOM zdielanom module (ui/js/edge_menu.js) a okno Vyroba ho uz
// len vola. Tieto testy stoja presne na tom:
//   1) modul kresli tri stavy + podriadeny prepinac a ZIVE POCTY zo servera,
//   2) rail a okno Vyroba dostanu BAJT-ROVNAKY obsah (lisi sa len obal),
//   3) payload do Ruby je bajt-rovnaky (identita + kluc + STRIKTNY boolean),
//   4) okno Vyroba naozaj deleguje (ziadna druha kopia markupu v production.js).
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const ROOT = path.join(__dirname, '..', '..');
const M = require(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'edge_menu.js'));
const P = require(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'production.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function no(cond, msg){ n++; assert.ok(!cond, msg); }

const DEFAULTS = { show_missing: true, show_extra: false, show_taped: false, taped_selected_only: true };
function state(options, counts, extra){
  return Object.assign({ available: true, active: true, options: options || DEFAULTS, counts: counts }, extra || {});
}

// --- 1) zdielany modul kresli cele 3-stavove nastavenie -----------------------
(function(){
  const st = state(DEFAULTS, { missing: 3, extra: 9, taped: 40 });
  const h = M.menuHtml(st, true, { fn: 'onEdgeMenuOption', id: 'railAbsMenu', cls: 'ecmenu-rail' });
  ['Chýba podľa pravidla', 'Neolepené mimo pravidla', 'Olepené'].forEach(function(label){
    ok(h.indexOf('<span>' + label + '</span>') >= 0, 'riadok „' + label + '" je aj v raile');
  });
  ['missing', 'extra', 'taped'].forEach(function(s){
    ok(h.indexOf('ecsw ecsw-' + s) >= 0, 'stav ' + s + ' ma farebny stvorcek (= farba plosky v modeli)');
  });
  ok(h.indexOf('<b class="eccnt">3</b>') >= 0, 'zivy pocet cervenej je zo SERVERA');
  ok(h.indexOf('<b class="eccnt">40</b>') >= 0, 'zivy pocet zelenej je zo SERVERA');
  ok(h.indexOf('ecopt ecsub') >= 0, '„len vybrané" je ODSADENY podriadeny prepinac');
  ok(h.indexOf('id="railAbsMenu"') >= 0, 'rail ma vlastne id uzla');
  ok(h.indexOf('ecmenu ecmenu-rail open') >= 0, 'rail sa lisi LEN obalom (poloha pri raile) a je otvoreny');
  ok(h.indexOf("onEdgeMenuOption('show_missing', this.checked)") >= 0, 'rail posiela prepnutie vlastnou cestou');
  no(h.indexOf('edgeCheckOption(') >= 0, 'rail NEVOLA handler okna Vyroba');

  const closed = M.menuHtml(st, false, { fn: 'onEdgeMenuOption', id: 'railAbsMenu', cls: 'ecmenu-rail' });
  no(closed.indexOf(' open"') >= 0, 'zatvorene okno nema triedu open');

  const off = M.menuHtml({ available: true, active: false, options: DEFAULTS, counts: null }, true, {});
  ok(off.indexOf('<b class="eccnt">—</b>') >= 0, 'vypnute zvyraznenie neskenuje — pocet je pomlcka');
})();

// --- 2) JEDNO nastavenie: rail a okno Vyroba maju ROVNAKY obsah ---------------
(function(){
  const st = state({ show_missing: true, show_extra: true, show_taped: true, taped_selected_only: false },
                   { missing: 1, extra: 2, taped: 3 });
  const rail = M.menuHtml(st, true, { fn: 'F', id: 'railAbsMenu', cls: 'ecmenu-rail' });
  const prod = P.edgeCheckMenuHtml(st, true);
  // Zhoda sa porovnava na tom, co pouzivatel vidi — riadky, stvorceky, pocty.
  // (Lisia sa len id uzla, doplnkova trieda a meno handlera.)
  const strip = function(h){
    return h.replace(/id="[^"]*"/, '').replace(/ ecmenu-rail/, '').replace(/onchange="[^"]*"/g, '');
  };
  eq(strip(rail), strip(prod), 'rail a okno Vyroba kreslia TO ISTE nastavenie (ziadna druha kopia)');
  eq((prod.match(/ checked onchange/g) || []).length, (rail.match(/ checked onchange/g) || []).length,
     'zaskrtnutia su z JEDNEHO serveroveho stavu');
})();

// --- 3) hint „označ skrinky v modeli" plati na OBOCH miestach ------------------
(function(){
  const empty = state({ show_missing: true, show_extra: false, show_taped: true, taped_selected_only: true },
                      { missing: 2, extra: 0, taped: 0 }, { selection_empty: true });
  ok(M.selectionHint(empty), 'prazdny vyber + „len vybrané" + zelena = hint');
  ok(M.menuHtml(empty, true, {}).indexOf('označ skrinky v modeli') >= 0, 'hint je pri podriadenom prepinaci');
  eq(M.selectionHint(empty), P.edgeCheckSelectionHint(empty), 'okno Vyroba pouziva TO ISTE rozhodnutie');
  no(M.selectionHint(Object.assign({}, empty, { active: false })), 'vypnute = ziadny hint');
})();

// --- 4) payload do Ruby: identita + kluc + STRIKTNY boolean --------------------
(function(){
  eq(M.optionPayload({ model_guid: 'G-1' }, 'show_taped', true),
     { gen: 0, model_guid: 'G-1', key: 'show_taped', value: true },
     'rail posiela identitu dokumentu + kluc + boolean');
  eq(M.optionPayload({ gen: 7, model_guid: 'G-1' }, 'show_taped', 'true').value, false,
     'nebooleovska hodnota sa NEPOSLE ako true (server ju aj tak odmietne)');
  eq(M.optionPayload(null, null, false), { gen: 0, model_guid: '', key: '', value: false },
     'bez dat sa nepada');
  eq(M.optionPayload({ gen: 7, model_guid: 'G-1' }, 'show_extra', true),
     P.edgeCheckOptionPayload({ gen: 7, model_guid: 'G-1' }, 'show_extra', true),
     'okno Vyroba posiela BAJT-ROVNAKY tvar (jedna cesta do Ruby)');
  no(Object.keys(M.optionPayload({ gen: 1 }, 'show_extra', true)).indexOf('options') >= 0,
     'klient NEPOSIELA cely stav prepinacov — meni sa vzdy jeden kluc');
})();

// --- 5) v production.js uz ziadna druha kopia markupu neexistuje ---------------
(function(){
  const src = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'production.js'), 'utf8');
  no(src.indexOf('Chýba podľa pravidla') >= 0, 'nazvy stavov ziju LEN v zdielanom module');
  no(src.indexOf('ecsw ecsw-') >= 0, 'farebne stvorceky kresli LEN zdielany modul');
  ok(src.indexOf('edge_menu.js') >= 0, 'okno Vyroba zdielany modul naozaj pouziva');

  const shell = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), 'utf8');
  ok(shell.indexOf('NXEdgeMenu.menuHtml') >= 0, 'rail kresli okno tym istym modulom');
  no(shell.indexOf('Neolepené mimo pravidla') >= 0, 'rail si nazvy stavov NEVYMYSLA');
  ok(shell.indexOf('sketchup.nx_edge_option') >= 0, 'rail zapisuje cez server (nie do localStorage)');
})();

console.log(`test_abs_rail_3stav.js: ${n} testov OK`);
