// NP-2 (predrecenzia P2-2): klik na nález Kontroly `layout_settings`
// („nastavenia prerezu a orezu sa nepodarilo načítať") — nález NEMÁ entitu
// v modeli, takže klik na riadok aj na tlačidlo `data-act="bset"` musí prepnúť
// sekciu na Nastavenia rozpočtu a na server nesmie odísť NIČ (`nx_select`).
// Vzor simulácie kliku: tests/js/test_d122_uni_skupina.js.
'use strict';
const assert = require('node:assert/strict');
const listeners = {};
const body = { innerHTML: '' };
const calls = [];
global.window = { sketchup: {
  nx_select: p => calls.push(['select', JSON.parse(p)])
} };
global.sketchup = window.sketchup;
global.document = {
  addEventListener: (name, fn) => { listeners[name] = fn; },
  getElementById: id => id === 'secbody' ? body : null
};
const S = require('../../noxun_engine/ui/js/studio.js');
let n = 0;
const eq = (a, b, m) => { assert.deepEqual(a, b, m); n++; };

const lset = { severity: 'orange', category: 'layout_settings', owner_id: null, part_key: null,
               hw_key: null, stable_key: 'layout_settings|seed_fallback',
               message_sk: 'Nastavenia prerezu a orezu sa nepodarilo načítať' };
const over = { severity: 'red', category: 'oversize', owner_id: 'CAB-1', part_key: 'bok',
               stable_key: 'oversize|CAB-1|bok', message_sk: 'Dielec sa nezmestí' };

const push = control => window.NX.setStudio({
  control, counts: { red: 1, orange: 1 }, model_guid: 'DOC-A', gen: 3,
  open_section: 'ctrl', rows: [], sheets: [], vepo: {}
});
const click = matches => listeners.click({ target: { closest: selector => matches[selector] || null } });
const attr = attrs => ({ getAttribute: key => attrs[key] });

// 1) klik na RIADOK
push([over, lset]);
eq(S.studioActiveSection(), 'ctrl', 'začína sa v Kontrole');
click({ '[data-ci]': attr({ 'data-ci': '1' }) });
eq(S.studioActiveSection(), 'bset', 'klik na riadok prepne na Nastavenia rozpočtu');
eq(calls.length, 0, 'a na server nejde nič (v modeli nie je čo označiť)');

// 2) klik na TLAČIDLO data-act="bset"
S.setStudioSection('ctrl');
click({ '[data-ci]': attr({ 'data-ci': '1' }), 'button.goact': attr({ 'data-act': 'bset' }) });
eq(S.studioActiveSection(), 'bset', 'tlačidlo vedie do Nastavení rozpočtu');
eq(calls.length, 0, 'ani tlačidlo nevolá nx_select');

// 3) bežný nález ide ďalej na server (kontrola, že test meria vetvu, nie ticho)
S.setStudioSection('ctrl');
click({ '[data-ci]': attr({ 'data-ci': '0' }) });
eq(calls.pop(), ['select', { gen: 3, problem_key: over.stable_key, focus_inspector: false }]);
eq(S.studioActiveSection(), 'ctrl', 'bežný nález sekciu nemení');

console.log(`OK — test_np2_kontrola_klik.js: ${n} testov preslo`);
