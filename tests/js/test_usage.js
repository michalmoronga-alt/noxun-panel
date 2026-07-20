// Testy klasifikacie klucov meraca D-25 (usage.js) — dependency-free Node
// (node tests/js/test_usage.js). usage.js exportuje cez module.exports a vetva
// s DOM listenermi v Node spi (rovnaky vzor ako expr.js). Fake uzly pokryvaju:
// id kluce, predok+tag, nazvy inline funkcii BEZ argumentov (ochrana sukromia),
// tab:/sec: kluce, allowlist tried (zrect/ehit/lockbtn/znode...), vylucenie
// inputov z klikov a prazdnej SVG plochy (pan nie je pouzitie prvku).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const usage = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'usage.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.strictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// Fake DOM uzol: tagName, id, type, atributy (vratane class), parentNode.
function elm(tag, opts){
  opts = opts || {};
  return {
    tagName: tag,
    id: opts.id || '',
    type: opts.type,
    parentNode: opts.parent || null,
    _attrs: opts.attrs || {},
    getAttribute(name){
      return Object.prototype.hasOwnProperty.call(this._attrs, name) ? this._attrs[name] : null;
    }
  };
}

// --- fnName: LEN nazov funkcie, argumenty NIKDY (mozu niest identifikatory dat) ---
eq(usage.fnName("splitZone('v')"), 'splitZone', 'fnName jednoduchy');
eq(usage.fnName("  mdOpenSheetForm('biela-lamino-18')  "), 'mdOpenSheetForm', 'fnName orezany');
eq(String(usage.fnName("mdOpenSheetForm('biela-lamino-18')")).indexOf('biela'), -1, 'argument NESMIE preniknut');
eq(usage.fnName('nie je volanie'), null, 'fnName ne-volanie');
eq(usage.fnName(null), null, 'fnName null');

// --- keyFor: id ma prednost; bez id predok-s-id + tag[.typ][:funkcia] ---
eq(usage.keyFor(elm('INPUT', { id: 'width', type: 'text' })), 'width', 'id kluc');
const frontRows = elm('DIV', { id: 'frontRows' });
const frow = elm('DIV', { parent: frontRows, attrs: { class: 'frow' } });
eq(usage.keyFor(elm('INPUT', { type: 'text', parent: frow, attrs: { oninput: 'onField()' } })),
  'frontRows/input.text:onField', 'dynamicky input: predok+tag+typ+funkcia');
eq(usage.keyFor(elm('SELECT', { parent: frow, attrs: { onchange: 'onFrontTypeChange(this); onField()' } })),
  'frontRows/select:onFrontTypeChange', 'dynamicky select: prva funkcia');
eq(usage.keyFor(elm('INPUT', { type: 'checkbox', parent: frow, attrs: { onchange: 'onField()' } })),
  'frontRows/input.checkbox:onField', 'checkbox nesie typ');
eq(usage.keyFor(elm('BUTTON', { attrs: { onclick: 'openRulesDialog()' } })),
  '?/button:openRulesDialog', 'bez id-predka = ?');

// --- clickKey: klikatelne prvky ---
const body = elm('BODY');
const btn = elm('BUTTON', { parent: body, attrs: { onclick: 'openProductionDialog()' } });
eq(usage.clickKey(btn, 'korpus'), '?/button:openProductionDialog', 'klik na button');
// klik na vnoreny span v buttone sa pripise buttonu
const span = elm('SPAN', { parent: btn });
eq(usage.clickKey(span, 'korpus'), '?/button:openProductionDialog', 'klik cez vnoreny span');
// input/select sa na klik NEpocita (tika cez change — ziadne dvojite pocitanie)
eq(usage.clickKey(elm('INPUT', { type: 'radio', parent: body, attrs: { onchange: 'onTypeChange()' } }), 'korpus'),
  null, 'radio klik nepocita');
// neklikatelny div bez vsetkeho = null
eq(usage.clickKey(elm('DIV', { parent: body }), 'korpus'), null, 'plain div nepocita');

// --- tab: a sec: kluce ---
const tabBtn = elm('BUTTON', { id: 'tabZones', attrs: { class: 'cabtab', onclick: "setCabTab('zony')" } });
eq(usage.clickKey(tabBtn, 'zony'), 'tab:zony', 'tab kluc z data-cab-tab');
eq(usage.clickKey(tabBtn, null), 'tab:?', 'tab fallback bez atributu');
const details = elm('DETAILS', { attrs: { 'data-key': 'fronts' } });
eq(usage.clickKey(elm('SUMMARY', { parent: details }), 'korpus'), 'sec:fronts', 'akordeon sekcie');
eq(usage.clickKey(elm('SUMMARY', { parent: elm('DETAILS') }), 'korpus'), '?/summary', 'summary bez data-key');

// --- allowlist tried: delegovane prvky (SVG hit plochy, lockbtn, znode) ---
const preview = elm('svg', { id: 'preview' });
const g = elm('g', { parent: preview });
eq(usage.clickKey(elm('rect', { parent: g, attrs: { class: 'zrect', 'data-zid': 'r1' } }), 'zony'),
  'preview/zrect', 'zona v nahlade');
eq(usage.clickKey(elm('line', { parent: g, attrs: { class: 'divh sel' } }), 'zony'),
  'preview/divh', 'priecka v nahlade');
// prazdna plocha SVG / kotovaci text = ZIADEN tick (pan nie je pouzitie prvku)
eq(usage.clickKey(elm('text', { parent: g }), 'zony'), null, 'kotovaci text nepocita');
eq(usage.clickKey(preview, 'zony'), null, 'prazdna plocha svg nepocita');
const partSvg = elm('svg', { id: 'partSvg' });
eq(usage.clickKey(elm('path', { parent: partSvg, attrs: { class: 'ehit' } }), 'korpus'),
  'partSvg/ehit', 'ABS hrana dielca');
const boardSvg = elm('svg', { id: 'boardSvg' });
eq(usage.clickKey(elm('path', { parent: boardSvg, attrs: { class: 'behit' } }), 'korpus'),
  'boardSvg/behit', 'ABS hrana dosky');
const fieldEditor = elm('DIV', { id: 'fieldEditor' });
eq(usage.clickKey(elm('DIV', { parent: fieldEditor, attrs: { class: 'lockbtn on', 'data-zid': 'r1', 'data-idx': '0' } }), 'zony'),
  'fieldEditor/lockbtn', 'zamok rozmeru pola');
const zoneTree = elm('DIV', { id: 'zoneTree' });
eq(usage.clickKey(elm('DIV', { parent: zoneTree, attrs: { class: 'znode active' } }), 'zony'),
  'zoneTree/znode', 'uzol stromu zon');
// D-23: celo v nahlade — cely <g class="fgrp"> je jeden hit (kridla aj text)
const fgrpG = elm('g', { parent: g, attrs: { class: 'fgrp hov', 'data-front-id': 'F1abc-2-x' } });
eq(usage.clickKey(elm('rect', { parent: fgrpG }), 'cela'), 'preview/fgrp', 'klik na kridlo cela');
eq(usage.clickKey(elm('text', { parent: fgrpG }), 'cela'), 'preview/fgrp', 'klik na text cela = ten isty item');
eq(String(usage.clickKey(elm('rect', { parent: fgrpG }), 'cela')).indexOf('F1abc'), -1, 'data-front-id NESMIE preniknut');

// --- changeKey: len formularove prvky; id ma prednost ---
eq(usage.changeKey(elm('SELECT', { id: 'template' })), 'template', 'select s id');
eq(usage.changeKey(elm('INPUT', { id: 'zonesChk', type: 'checkbox' })), 'zonesChk', 'checkbox s id');
eq(usage.changeKey(elm('DIV', { id: 'idbar' })), null, 'div change nepocita');
const insertKindRow = elm('DIV', { id: 'insertKindRow' });
eq(usage.changeKey(elm('INPUT', { type: 'radio', parent: insertKindRow, attrs: { onchange: 'onInsertKindChange()' } })),
  'insertKindRow/input.radio:onInsertKindChange', 'radio bez id');

// --- ochrana sukromia: data-* hodnoty a argumenty sa NIKDY nedostanu do kluca ---
const hw = elm('DIV', { id: 'hwRows' });
const hwBtn = elm('BUTTON', { parent: hw, attrs: { onclick: "onHwReset(this)", title: 'Vypnut' } });
const hwKey = usage.clickKey(hwBtn, 'korpus');
eq(hwKey, 'hwRows/button:onHwReset', 'kovanie reset');
const zr = elm('rect', { parent: g, attrs: { class: 'zrect', 'data-zid': 'r1-2-3' } });
eq(String(usage.clickKey(zr, 'zony')).indexOf('r1-2-3'), -1, 'data-zid NESMIE preniknut do kluca');

console.log(JSON.stringify({ passed: n, failed: 0 }));
