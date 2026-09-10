// D-122: zoskupenie nesmie zmeniť adresu výberu ani zamlčať iné nálezy.
'use strict';
const assert = require('node:assert/strict');
const listeners = {};
const body = { innerHTML: '' };
const calls = [];
global.window = { sketchup: {
  nx_select: p => calls.push(['select', JSON.parse(p)]),
  replace_uni: p => calls.push(['uni', JSON.parse(p)])
} };
global.sketchup = window.sketchup;
global.document = {
  addEventListener: (name, fn) => { listeners[name] = fn; },
  getElementById: id => id === 'secbody' ? body : null
};
const S = require('../../noxun_engine/ui/js/studio.js');
let n = 0;
const eq = (a, b) => { assert.deepEqual(a, b); n++; };
const ok = a => { assert.ok(a); n++; };
const uni = (owner, key, id) => ({ severity: 'orange', category: 'uni_material',
  owner_id: owner, part_key: key, uni_id: id, stable_key: owner + '|' + key,
  message_sk: 'Materiál neurčený: ' + key });
const a = uni('CAB-001', 'bok_l', 'UNI_BODY');
const b = uni('CAB-002', 'back', 'UNI_BACK');
const red = { severity: 'red', category: 'material', stable_key: 'missing', message_sk: 'Chýba materiál' };
const budget = { severity: 'orange', category: 'budget', message_sk: 'Chýba sadzba' };
const items = [red, a, budget, b];
const snapshot = JSON.stringify(items);

// Rozptýlené UNI riadky vytvoria jednu skupinu, pôvodné indexy ostávajú.
const h = S.ctrlListHtml(S.ctrlRows(items, 'all'), false);
eq((h.match(/id="ctrlUniToggle"/g) || []).length, 1);
ok(h.includes('2 dielce'));
ok(h.includes('aria-expanded="false"'));
ok(h.includes('class="ctrluni-items" hidden'));
ok(h.includes('data-ci="1"'));
ok(h.includes('data-ci="3"'));
ok(h.indexOf('data-ci="0"') < h.indexOf('id="ctrlUniToggle"'));
ok(h.indexOf('data-ci="2"') > h.indexOf('id="ctrlUniItems"'));
ok(h.includes('data-uni="UNI_BACK"'));
eq(JSON.stringify(items), snapshot);
ok(!S.ctrlListHtml(S.ctrlRows(items, 'red'), false).includes('ctrlUniToggle'));
ok(S.ctrlListHtml(S.ctrlRows(items, 'orange'), true).includes('data-ci="3"'));
eq(S.ctrlListHtml([], false), '');
// Prípadná iná závažnosť rovnakej kategórie sa nikdy neschová pod ORANGE.
ok(!S.ctrlListHtml([[Object.assign({}, a, { severity: 'red' }), 0]], false).includes('ctrlUniToggle'));

const push = (control, model = 'DOC-A', gen = 1) => window.NX.setStudio({
  control, counts: { red: 7, orange: 23, clean: 2 }, model_guid: model, gen,
  open_section: 'ctrl', rows: [], sheets: [], vepo: {}
});
const click = matches => listeners.click({ target: { closest: selector => matches[selector] || null } });
const attr = attrs => ({ getAttribute: key => attrs[key] });
push(items);
ok(body.innerHTML.includes('aria-expanded="false"'));
click({ '[data-ctrl-uni]': {} });
ok(body.innerHTML.includes('aria-expanded="true"'));
eq(calls.length, 0); // hlavička nesmie označiť prvý dielec ani volať server.
click({ '[data-sev]': attr({ 'data-sev': 'orange' }) });
ok(body.innerHTML.includes('aria-expanded="true"'));
ok(!body.innerHTML.includes('data-ci="0"'));
click({ '[data-ci]': attr({ 'data-ci': '3' }), 'button.goact': attr({ 'data-act': 'edit' }) });
eq(calls.pop(), ['select', { gen: 1, problem_key: b.stable_key, focus_inspector: true }]);
click({ '[data-ci]': attr({ 'data-ci': '1' }), 'button.goact': attr({ 'data-act': 'uni', 'data-uni': a.uni_id }) });
eq(calls.pop(), ['uni', { uni_id: 'UNI_BODY', gen: 1, model_guid: 'DOC-A' }]);

// Nový payload môže preusporiadať/odobrať deti; klik má stále čerstvý kľúč.
push([b, red], 'DOC-A', 2);
ok(body.innerHTML.includes('1 dielec'));
ok(body.innerHTML.includes('aria-expanded="true"'));
click({ '[data-ci]': attr({ 'data-ci': '0' }) });
eq(calls.pop(), ['select', { gen: 2, problem_key: b.stable_key, focus_inspector: false }]);
ok(body.innerHTML.includes('>23<')); // počty sú serverové, nie počet skupín.
push([red]);
ok(!body.innerHTML.includes('ctrlUniToggle'));
push([a]); // napr. Undo po náhrade posledného UNI.
ok(body.innerHTML.includes('aria-expanded="false"'));
click({ '[data-ctrl-uni]': {} });
push([b], 'DOC-B', 3);
ok(body.innerHTML.includes('aria-expanded="false"'));
ok(!body.innerHTML.includes('UNI_BODY'));
console.log(`test_d122_uni_skupina.js: ${n} testov OK`);
