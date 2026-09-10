// CENY-KOV-A: skutočný render Rozpočtu a všetky vstupy navigácie v jednom scope.
// Chráni nielen oranžovú ikonu, ale aj zrušenie oneskorenej požiadavky z Rozpočtu.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { mkEl, DOC } = require('./minidom.js');
let n = 0;
function ok(value, msg){ n++; assert.ok(value, msg); }
function eq(value, expected, msg){ n++; assert.deepStrictEqual(value, expected, msg); }
['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel'].forEach(id => {
  const el = mkEl('div'); el.attrs.id = id; DOC.body.appendChild(el);
});
const ctx = {
  console, document: DOC, setTimeout, clearTimeout,
  localStorage: { getItem(){ return null; }, setItem(){} },
  sketchup: new Proxy({}, { get(){ return function(){}; }, has(){ return true; } })
};
ctx.window = ctx;
vm.createContext(ctx);
for (const file of ['studio.js', 'budget.js']){
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../../noxun_engine/ui/js', file), 'utf8'), ctx,
    { filename: file });
}
const row = { kod: 'K"<1', nazov: 'Noha <AXILO>', mnozstvo: 2, mj: 'ks', cena_mj: 4.5, spolu: 9,
              product_link: true };
let html = ctx.budHardwareRow(row, 1);
ok(html.includes('data-action="hw-product"'), 'katalogovy riadok ma spolocny preklik');
ok(html.includes('data-code="K&quot;&lt;1"'), 'identita je escapovana');
ok(html.includes('aria-label="Otvoriť produkt · Noha &lt;AXILO&gt;"'), 'citacka pozna akciu aj polozku');
ok(!html.includes('is-missing'), 'platny odkaz nie je oranzovy');
ok(html.includes('#i-external-link'), 'ikona pouziva existujuci SVG sprite');
ok(html.includes('9,00') || html.includes('9.00'), 'sucet zostava zachovany');
html = ctx.budHardwareRow(Object.assign({}, row, { product_link: false, price_missing: true }), 1);
ok(html.includes('hw-product-link is-missing'), 'chybajuci odkaz je oranzovy');
ok(html.includes('Chýba odkaz — doplniť odkaz produktu'), 'tooltip vysvetli doplnenie');
ok(html.includes('chýba cena'), 'odkaz nezakryje chybajucu cenu');
ok(!ctx.budHardwareRow(Object.assign({}, row, { free: true }), 1).includes('data-action="hw-product"'),
  'volna polozka nema katalogovy editor');
const noRecord = Object.assign({}, row); delete noRecord.product_link;
ok(!ctx.budHardwareRow(noRecord, 1).includes('data-action="hw-product"'), 'zmazany katalogovy kod nema falosnu akciu');

function payload(guid, section){
  const out = { version: 'test', gen: 1, model_guid: guid, model_title: 'Test',
    rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null, summary: {},
    sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {}, control: [],
    counts: { red: 0, orange: 0, clean: 0, cabinets: 0 },
    vepo: { project: 'test', default_project: 'test' }, budget: null };
  if (section) out.open_section = section;
  return out;
}
const changed = [];
ctx.hwProductContextChanged = function(section, guid){
  changed.push({ section, guid, beforeSection: ctx.studioSec, beforeGuid: ctx.ST && ctx.ST.model_guid });
};
ctx.NX.setStudio(payload('A', 'budget'));
changed.length = 0;
ctx.studioGoSection('bom');
eq(changed.length, 1, 'odchod z Rozpoctu zrusi poziadavku');
eq(changed[0], { section: 'bom', guid: 'A', beforeSection: 'budget', beforeGuid: 'A' },
  'hook prebehne pred prechodom');
changed.length = 0;
ctx.studioGoSection('bom');
ctx.studioGoSection('not-a-section');
eq(changed.length, 0, 'rovnaka/neplatna sekcia zbytocne nerusi poziadavku');
ctx.NX.setStudio(payload('A', 'budget'));
eq(changed.length, 1, 'deep-link tiez zrusi poziadavku z povodnej sekcie');
eq(changed[0].beforeSection, 'bom', 'deep-link hook prebehne pred zmenou');
changed.length = 0;
ctx.NX.setStudio(payload('A'));
eq(changed.length, 0, 'obycajny refresh rovnakeho dokumentu formular nerusi');
ctx.NX.setStudio(payload('B'));
eq(changed.length, 1, 'zmena dokumentu zrusi poziadavku aj bez navigacie');
eq(changed[0].beforeGuid, 'A', 'hook vidi povodny dokument');
eq(changed[0].guid, 'B', 'hook dostane cielovy dokument');
changed.length = 0;
ctx.NX.setStudio(null);
eq(changed.length, 1, 'zrusenie modeloveho payloadu je tiez zmena kontextu');
console.log('CENY-KOV-A budget links: ' + n + ' checks PASS');
