// Testy V0.6 M-A2: ciste funkcie modalu "Pridat z Demosu" (demos_add.js)
// + dlazdicove/delete helpery (proj_materials.js). Bez DOM.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const add = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'demos_add.js'));
const md = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let passed = 0, failed = 0;
function eq(a, b, msg){
  try { assert.deepStrictEqual(a, b); passed++; }
  catch (e) { failed++; console.error('FAIL:', msg, '\n  expected:', JSON.stringify(b), '\n  actual:  ', JSON.stringify(a)); }
}
function ok(cond, msg){
  if (cond) passed++;
  else { failed++; console.error('FAIL:', msg); }
}

// --- nxdaSections ------------------------------------------------------------

const ITEMS = [
  { iid: 'i0', kind: 'sheet', type: 'PD', name: 'PD 38', thickness_hint: 38 },
  { iid: 'i1', kind: 'sheet', type: 'DTDL', name: 'DTDL 18', thickness_hint: 18 },
  { iid: 'i2', kind: 'edge', name: 'ABS 23x1', width_hint: 23, thickness_hint: 1 },
  { iid: 'i3', kind: 'edge', name: 'ABS 43x1', width_hint: 43, thickness_hint: 1 },
  { iid: 'i4', kind: 'edge', name: 'ABS 43x2', width_hint: 43, thickness_hint: 2 },
  { iid: 'i5', kind: 'other', name: 'Lišta', reason: 'mimo podporovaných typov' }
];

const secs = add.nxdaSections(ITEMS);
eq([secs.sheets.length, secs.edges.length, secs.others.length], [2, 3, 1], 'sections rozdelia druhy');
eq(add.nxdaSections(null), { sheets: [], edges: [], others: [] }, 'sections zvladnu null');

// --- nxdaAutoEdgeSuggest -------------------------------------------------------

eq(add.nxdaAutoEdgeSuggest(ITEMS, {}, 'i1'), 'i2', 'doska 18 -> najmensia 1mm paska >= 20 (23x1)');
eq(add.nxdaAutoEdgeSuggest(ITEMS, {}, 'i0'), 'i3', 'doska 38 -> 43x1 (23 nestaci, 43x2 nie je 1mm)');
eq(add.nxdaAutoEdgeSuggest(ITEMS, { i2: false }, 'i1'), 'i3',
   'vedome odskrtnuta 23x1 sa NIKDY nenavrhne znova — dalsia v poradi');
eq(add.nxdaAutoEdgeSuggest(ITEMS, { i2: true }, 'i1'), null,
   'uz zaskrtnuta paska sa nenavrhuje (nie je undefined)');
eq(add.nxdaAutoEdgeSuggest(ITEMS, {}, 'i5'), null, 'non-sheet nevracia navrh');
eq(add.nxdaAutoEdgeSuggest([{ iid: 's', kind: 'sheet' }], {}, 's'), null, 'bez thickness_hint ziadny navrh');

// --- vyber ----------------------------------------------------------------------

eq(add.nxdaSelectedIids({ i1: true, i2: false, i3: true }), ['i1', 'i3'], 'selected = len true, sorted');
eq(add.nxdaEdgeOnly(ITEMS, { i2: true, i3: true }), true, 'edge-only vyber');
eq(add.nxdaEdgeOnly(ITEMS, { i1: true, i2: true }), false, 'doska vo vybere = nie edge-only');
eq(add.nxdaEdgeOnly(ITEMS, {}), false, 'prazdny vyber nie je edge-only');

// --- price label + session -------------------------------------------------------

eq(add.nxdaPriceLabel(118.42, 'ks'), '118,42 € / ks', 'cena s jednotkou');
eq(add.nxdaPriceLabel(0.5, null), '0,50 €', 'cena bez jednotky');
eq(add.nxdaPriceLabel(null, 'ks'), '—', 'chybajuca cena');
eq(add.nxdaPriceLabel('abc', 'ks'), '—', 'necislo');

eq(add.nxdaSessionCheck(5, 5), 'ok', 'rovnaka session');
eq(add.nxdaSessionCheck(5, 6), 'new', 'novsia preberie');
eq(add.nxdaSessionCheck(5, 4), 'stale', 'starsia sa zahodi');

// --- proj_materials: mdImageSrc ---------------------------------------------------

eq(md.mdImageSrc('C:\\Users\\PC\\AppData\\Roaming\\NOXUN\\Engine\\textures\\ab_1.jpg'),
   'file:///C:/Users/PC/AppData/Roaming/NOXUN/Engine/textures/ab_1.jpg',
   'backslash -> slash + file:///');
ok(md.mdImageSrc('C:\\APP DEV\\x.jpg').indexOf('APP%20DEV') >= 0, 'medzera v ceste sa enkoduje');
eq(md.mdImageSrc(''), '', 'prazdna cesta = prazdny src');
eq(md.mdImageSrc(null), '', 'null cesta = prazdny src');

// --- proj_materials: mdDeleteSummary ----------------------------------------------

const sum = md.mdDeleteSummary({ kind: 'sheet', code: '275848', supplier: 'Demos',
  price: 18.99, demos_url: 'https://www.demos-trade.sk/x/', used: [], used_count: 0,
  protected: false, duplak_deps: [] });
ok(sum.lines.some(function(l){ return l.indexOf('275848') >= 0 && l.indexOf('Demos') >= 0; }), 'kod + dodavatel v rozpise');
ok(sum.lines.some(function(l){ return l.indexOf('18.99') >= 0 && l.indexOf('€/m²') >= 0; }), 'cena s jednotkou sheet');
ok(sum.lines.some(function(l){ return l.indexOf('Demos') >= 0 && l.indexOf('väzbu') >= 0; }), 'upozornenie na URL vazbu');
eq([sum.warn, sum.block], [null, null], 'bez pouzitia/ochran ziadne warny');

const sum2 = md.mdDeleteSummary({ kind: 'edge', price: 0.52, used: ['CAB-1', 'CAB-2'], used_count: 5,
  protected: false, duplak_deps: [] });
ok(sum2.warn && sum2.warn.indexOf('5×') >= 0 && sum2.warn.indexOf('CAB-1') >= 0, 'pouzitie v modeli vo warne');
ok(sum2.lines.some(function(l){ return l.indexOf('€/bm') >= 0; }), 'edge jednotka €/bm');

const sum3 = md.mdDeleteSummary({ kind: 'sheet', protected: true, used: [], used_count: 0, duplak_deps: [] });
ok(sum3.block && sum3.block.indexOf('predvoľba') >= 0, 'protected blokuje');
const sum4 = md.mdDeleteSummary({ kind: 'sheet', protected: false, used: [], used_count: 0,
  duplak_deps: ['X_36'] });
ok(sum4.block && sum4.block.indexOf('duplák') >= 0 && sum4.block.indexOf('X_36') >= 0, 'duplak zavislost blokuje');

console.log(JSON.stringify({ passed: passed, failed: failed }));
process.exit(failed ? 1 : 0);
