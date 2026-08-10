// Testy D-105 (JS zrkadlo) — split tlacidlo „Zvyraznit hrany" + rozbalovacie okno
// s tromi stavmi v tabe KONTROLA okna Vyroba.
//
// JS je LEN zobrazenie: stav prepinacov, pocty aj zapnutost nesie SERVER; klient
// si nic neprepocitava, nic si nepamata (okrem toho, ci je okno rozbalene) a do
// Ruby posiela iba identitu + kluc/boolean. O platnosti kluca rozhoduje server.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const P = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'production.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function no(cond, msg){ n++; assert.ok(!cond, msg); }

const ALL_ON = { show_missing: true, show_extra: true, show_taped: true, taped_selected_only: false };
const DEFAULTS = { show_missing: true, show_extra: false, show_taped: false, taped_selected_only: true };
function state(options, counts, extra){
  return Object.assign({ available: true, active: true, options: options, counts: counts }, extra || {});
}

// --- split tlacidlo -----------------------------------------------------------
(function(){
  const on = P.edgeCheckBarHtml(state(DEFAULTS, { missing: 3, extra: 9, taped: 40 }), false);
  ok(on.indexOf('class="ecsplit"') >= 0, 'tlacidlo je jeden vizualny celok (split)');
  ok(on.indexOf('ecbtn ecmain on') >= 0, 'lava polovica nesie zapnuty stav');
  ok(on.indexOf('ecbtn ecmore on') >= 0, 'prava polovica je sucastou toho isteho celku');
  ok(on.indexOf('#i-chevron-down') >= 0, 'prava polovica ma chevron zo spritu (ziadne emoji)');
  ok(on.indexOf('#i-eye-off') >= 0, 'zapnute = ikona eye-off');
  ok(on.indexOf('aria-expanded="false"') >= 0, 'zatvorene okno je aj pre citacku');
  ok(on.indexOf('Zvýrazniť hrany') >= 0, 'novy nazov tlacidla');
  no(on.indexOf('bez olepu</button>') >= 0, 'nazov uz nehovori iba o chybajucom olepe');

  const off = P.edgeCheckBarHtml(state(DEFAULTS, null, { active: false }), false);
  ok(off.indexOf('#i-eye"') >= 0, 'vypnute = ikona eye');
  ok(off.indexOf('class="ecbtn ecmain"') >= 0, 'vypnute tlacidlo nema triedu on');

  const opened = P.edgeCheckBarHtml(state(DEFAULTS, { missing: 3, extra: 9, taped: 40 }), true);
  ok(opened.indexOf('aria-expanded="true"') >= 0, 'otvorene okno je aj pre citacku');
  ok(opened.indexOf('ecmenu open') >= 0, 'otvorene okno ma triedu open');
})();

// --- rozbalovacie okno: tri stavy + zive pocty --------------------------------
(function(){
  const h = P.edgeCheckMenuHtml(state(DEFAULTS, { missing: 3, extra: 9, taped: 40 }), true);
  ['Chýba podľa pravidla', 'Neolepené mimo pravidla', 'Olepené'].forEach(function(label){
    ok(h.indexOf('<span>' + label + '</span>') >= 0, 'riadok „' + label + '" je v okne');
  });
  ['missing', 'extra', 'taped'].forEach(function(s){
    ok(h.indexOf('ecsw ecsw-' + s) >= 0, 'stav ' + s + ' ma farebny stvorcek');
  });
  ok(h.indexOf('<b class="eccnt">3</b>') >= 0, 'zivy pocet cervenej zo servera');
  ok(h.indexOf('<b class="eccnt">9</b>') >= 0, 'zivy pocet oranzovej zo servera');
  ok(h.indexOf('<b class="eccnt">40</b>') >= 0, 'zivy pocet zelenej zo servera');
  ok(h.indexOf('ecopt ecsub') >= 0, '„len vybrané" je ODSADENY podriadeny prepinac');
  ok(h.indexOf('<span>len vybrané</span>') >= 0, 'podriadeny prepinac ma svoj nazov');
  // poradie: podriadeny prepinac patri VYHRADNE zelenej -> hned za nou
  ok(h.indexOf('ecsw-taped') < h.indexOf('ecsub'), '„len vybrané" nasleduje az za zelenou');
  ok(h.indexOf('ecsub') > h.indexOf('ecsw-extra'), '„len vybrané" nepatri oranzovej');
})();

// --- stav prepinacov je zo SERVERA -------------------------------------------
(function(){
  const def = P.edgeCheckMenuHtml(state(DEFAULTS, { missing: 0, extra: 0, taped: 0 }), true);
  // default: zaskrtnuta je cervena a „len vybrané"; oranzova a zelena nie
  eq((def.match(/ checked onchange/g) || []).length, 2, 'default ma zaskrtnute presne dva prepinace');
  ok(def.indexOf("edgeCheckOption('show_missing', this.checked)") >= 0, 'kluc prepinaca je v handleri');

  const all = P.edgeCheckMenuHtml(state(ALL_ON, { missing: 1, extra: 2, taped: 3 }), true);
  eq((all.match(/ checked onchange/g) || []).length, 3, 'vsetky tri stavy zapnute, „len vybrané" vypnute');

  const off = P.edgeCheckMenuHtml({ available: true, active: false, options: DEFAULTS, counts: null }, true);
  ok(off.indexOf('<b class="eccnt">—</b>') >= 0, 'vypnute zvyraznenie neskenuje — pocet je pomlcka');
})();

// --- prazdny vyber pri „len vybrané" -----------------------------------------
(function(){
  const empty = state({ show_missing: true, show_extra: false, show_taped: true, taped_selected_only: true },
                      { missing: 2, extra: 0, taped: 0 }, { selection_empty: true });
  ok(P.edgeCheckSelectionHint(empty), 'prazdny vyber + „len vybrané" + zelena = hint');
  ok(P.edgeCheckMenuHtml(empty, true).indexOf('označ skrinky v modeli') >= 0,
     'hint je pri podriadenom prepinaci (ziadne tiche zobrazenie vsetkeho)');
  ok(P.edgeCheckText(empty).indexOf('označ skrinky v modeli') >= 0, 'hint je aj v texte vedla tlacidla');

  const withSel = Object.assign({}, empty, { selection_empty: false, counts: { missing: 2, extra: 0, taped: 12 } });
  no(P.edgeCheckSelectionHint(withSel), 'ked je nieco oznacene, hint je prec');
  no(P.edgeCheckSelectionHint(Object.assign({}, empty, { active: false })), 'vypnute = ziadny hint');
  no(P.edgeCheckSelectionHint(Object.assign({}, empty,
       { options: { show_taped: false, taped_selected_only: true } })), 'zelena vypnuta = ziadny hint');
  no(P.edgeCheckSelectionHint(Object.assign({}, empty,
       { options: { show_taped: true, taped_selected_only: false } })), 'bez filtra = ziadny hint');
})();

// --- text vedla tlacidla ------------------------------------------------------
eq(P.edgeCheckText(state(ALL_ON, { missing: 1, extra: 2, taped: 30 })),
   '1 hrana bez olepu · 2 mimo pravidla · 30 olepených',
   'text zhrna LEN zapnute stavy, cisla su zo servera');
eq(P.edgeCheckText(state(DEFAULTS, { missing: 0, extra: 5, taped: 40 })),
   'Všetky hrany podľa pravidla sú olepené.',
   'ciel zakazky: nula cervenych pri zapnutej iba cervenej');
eq(P.edgeCheckText(state({ show_missing: false, show_extra: false, show_taped: false,
                           taped_selected_only: true }, { missing: 4, extra: 4, taped: 4 })),
   'Žiadny stav nie je zapnutý — otvor nastavenie (▾).',
   'vsetko vypnute = povie, kde to zapnut (nie tiche prazdno)');
ok(P.edgeCheckText(state(DEFAULTS, { missing: 3 }, { unresolved: 2 })).indexOf('2 sa nedá zvýrazniť') >= 0,
   'nezvyraznitelne hrany sa priznaju aj v novom texte');

// --- payload do Ruby ----------------------------------------------------------
eq(P.edgeCheckOptionPayload({ gen: 7, model_guid: 'G-1' }, 'show_taped', true),
   { gen: 7, model_guid: 'G-1', key: 'show_taped', value: true },
   'posiela sa identita + kluc + boolean');
eq(P.edgeCheckOptionPayload({ gen: 7, model_guid: 'G-1' }, 'show_taped', 'true').value, false,
   'nebooleovska hodnota sa NEPOSLE ako true (server ju aj tak odmietne)');
eq(P.edgeCheckOptionPayload(null, null, false), { gen: 0, model_guid: '', key: '', value: false },
   'bez dat sa nepada');
ok(Object.keys(P.edgeCheckOptionPayload({ gen: 1 }, 'show_extra', true)).indexOf('options') < 0,
   'klient NEPOSIELA cely stav prepinacov — meni sa vzdy jeden kluc');

console.log(`test_d105_prepinace_hran.js: ${n} testov OK`);
