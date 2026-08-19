// Testy UI-D3: KLIKATELNOST — ciste funkcie warnpanelu (N5) a deep-linku do
// okna Vyroba („Štúdio"). Bez DOM: overuje sa, CO panel vykresli a CO odosle.
//
// Preco to je test a nie klikanie: riadok warnpanelu nesie kluce dielcov, ktore
// oko oznaci v modeli — zla konvencia (napr. „ziadny part_key" prelozeny na
// prazdny retazec namiesto prazdneho pola) by oznacila nieco ine, nez o com
// nalez hovori, a v modeli by to vyzeralo ako nahoda.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const NXShell = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- 1) riadky warnpanelu ----------------------------------------------------

eq(NXShell.warnRows(null), [], 'bez upozorneni sa nekresli nic');
eq(NXShell.warnRows([]), [], 'prazdne pole = prazdny panel');

const CAB_LEVEL = NXShell.warnRows([
  { code: 'rail_depth_clamped', severity: 'warn', message: 'Výstuha orezaná na 500 mm.', part_key: null }
]);
eq(CAB_LEVEL.length, 1, 'jeden nalez = jeden riadok');
eq(CAB_LEVEL[0].text, 'Výstuha orezaná na 500 mm.', 'text je serverova sprava, panel ju neprepisuje');
eq(CAB_LEVEL[0].keys, [],
   'korpusova uroven (part_key nil) = PRAZDNE kluce, teda „označ celú skrinku" ' +
   '— rovnaka konvencia ako box Skrinka v Kovani');
eq(/skrinku/.test(CAB_LEVEL[0].tip), true, 'tooltip povie, co sa oznaci');

const PART_LEVEL = NXShell.warnRows([
  { code: 'front_profile_missing', message: 'Čelo F1 bez profilu.', part_key: 'front:1' }
]);
eq(PART_LEVEL[0].keys, ['front:1'], 'part_key ide do klucov nedotknuty (nesklada sa, neseka)');
eq(/dielec/.test(PART_LEVEL[0].tip), true, 'tooltip rozlisi dielec od skrinky');

// part_key sa NIKDY neupravuje — nesie ':' aj '/' a kazda „normalizacia" by
// z neho spravila kluc ineho dielca (lekcia PartKeys.segment).
eq(NXShell.warnRows([{ message: 'x', part_key: 'zone:Z1.2/shelf:3' }])[0].keys,
   ['zone:Z1.2/shelf:3'], 'zlozeny kluc prejde bez zmeny');

// Prazdny/chybajuci text = riadok bez informacie: oko by slubilo skok a
// nepovedalo preco. Taky nalez sa nekresli.
eq(NXShell.warnRows([{ code: 'x', part_key: 'front:1' }]).length, 0, 'nalez bez textu sa zahodi');
eq(NXShell.warnRows([{ message: '', part_key: 'front:1' }]).length, 0, 'prazdny text sa zahodi');
eq(NXShell.warnRows([null, undefined, { message: 'ok' }]).length, 1, 'dier v poli sa test nezlaka');

// Poradie je poradie servera — je to zoznam nalezov, nie rebricek.
eq(NXShell.warnRows([{ message: 'a' }, { message: 'b' }]).map(r => r.text), ['a', 'b'],
   'poradie zo servera ostava');

// --- 2) deep-link do okna Vyroba --------------------------------------------

eq(NXShell.STUDIO_TABS, ['rows', 'sheets', 'edging', 'hardware', 'budget', 'control'],
   'zoznam tabov je ZRKADLO ProductionDialog::TABS');

eq(NXShell.studioTab('control'), 'control', 'platny tab prejde');
eq(NXShell.studioTab('rows'), 'rows', 'kusovnik prejde');
eq(NXShell.studioTab('kontrola'), null, 'slovensky preklep nie je meno tabu');
eq(NXShell.studioTab(''), null, 'prazdna hodnota = bez deep-linku');
eq(NXShell.studioTab(null), null, 'chybajuca hodnota = bez deep-linku');
eq(NXShell.studioTab(undefined), null, 'rail Štúdio (bez argumentu) tab NEPREPINA');
eq(NXShell.studioTab('__proto__'), null, 'zoznam sa pyta indexOf, nie vlastnosti objektu');

eq(NXShell.studioLink('control'), { tab: 'control' }, 'payload nesie iba meno tabu');
eq(NXShell.studioLink(), { tab: null }, 'bez tabu ide `null` — server vtedy tab nemeni');
eq(NXShell.studioLink('nieco'), { tab: null }, 'nezname meno sa z panela vobec nedostane von');

console.log(`test_uid3_klikatelnost: ${n} kontrol OK`);
