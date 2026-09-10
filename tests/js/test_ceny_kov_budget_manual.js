'use strict';
// Skutocny render Rozpoctu: rucna kontrola, datum, amber warning a Demos cesta.
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { DOC } = require('./minidom.js');
const ctx = { console, document: DOC, setTimeout, clearTimeout };
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../noxun_engine/ui/js/budget.js'), 'utf8'), ctx);
let n = 0;
function ok(v, msg){ n++; assert.ok(v, msg); }
function eq(v, expected, msg){ n++; assert.strictEqual(v, expected, msg); }
const stale = { state: 'manual', manual_check: true, product_link: true, kind: 'hardware', id: 'K"1', label: 'Noha <test>' };
const row = { kod: stale.id, nazov: stale.label, mnozstvo: 3, mj: 'BAL', cena_mj: 12.5,
  spolu: 37.5, product_link: true, price_check: stale };
let h = ctx.budHardwareRow(row, 1);
ok(h.includes('data-action="hw-product"'), 'preklik ostava samostatny');
ok(h.includes('data-action="hw-manual-check"'), 'explicitne potvrdenie ma inu akciu');
ok(h.includes('is-pending'), 'neoverena manualna cena je oranzova');
ok(h.includes('data-code="K&quot;1"'), 'identita je escapovana');
ok(h.includes('Noha &lt;test&gt;'), 'nazov je escapovany');
ok(h.includes('37,50'), 'nova akcia nemeni medzisucet');
ok(h.includes('#i-clipboard-check'), 'kontrola pouziva SVG sprite');
ok(!h.includes('ručne 10.09.2026'), 'neoverena cena nema falosny datum');

const fresh = Object.assign({}, stale, { state: 'fresh', checked_at: '2026-09-10T12:00:00Z' });
h = ctx.budHardwareRow(Object.assign({}, row, { price_check: fresh }), 1);
ok(!h.includes('is-pending'), 'fresh cena neupozornuje');
ok(h.includes('ručne 10.09.2026'), 'povod a datum su viditelne aj v cerstvom riadku');
ok(h.includes('Overiť cenu'), 'aj fresh cenu mozno vedome overit znova');
h = ctx.budHardwareRow(Object.assign({}, row, { price_missing: true }), 1);
ok(h.includes('chýba cena'), 'overenie nezakryje chybajucu cenu');
h = ctx.budHardwareRow(Object.assign({}, row, { price_check: undefined }), 1);
ok(!h.includes('hw-manual-check'), 'Demos alebo volny riadok nema manualny vstup');

eq(ctx.budStaleLabel({ counts: { stale: 0, manual_hardware: 1, attention: 1 } }), '1 cena na kontrolu', 'manualna bez datumu upozornuje');
eq(ctx.budStaleLabel({ counts: { stale: 2, manual_hardware: 2, attention: 3 } }), '3 ceny na kontrolu', 'serverovy pocet bez dvojiteho scitania');
eq(ctx.budStaleLabel({ counts: { stale: 0, manual_hardware: 0, attention: 0 } }), null, 'po potvrdeni chip zmizne');
eq(ctx.budStaleLabel({ stale_days: 30, counts: { stale: 2 } }), '2 ceny staršie ako 30 dní', 'povodny Demos payload ostava funkcny');
h = ctx.budStaleActionHtml(stale);
ok(h.includes('hw-product') && h.includes('hw-manual-check'), 'manualny zoznam ma obe samostatne akcie');
ok(!h.includes('refresh_one'), 'manualny URL nikdy nespusti parser');
h = ctx.budStaleActionHtml(Object.assign({}, stale, { demos_url: 'https://www.demos-trade.sk/p/' }));
ok(h.includes('hw-product') && h.includes('refresh_one'), 'Demos zoznam ma preklik a svoju povodnu aktualizaciu');
ok(!h.includes('hw-manual-check'), 'Demos cena nema rucnu certifikaciu');
h = ctx.budStaleActionHtml({ kind: 'sheet', id: 'S', state: 'manual' });
ok(h.includes('over v katalógu ručne') && !h.includes('hw-manual-check'), 'manualne materialy nie su v B rozsahu');
ctx.BUD_STALE_OPEN = true;
h = ctx.budStaleListHtml({ stale: { items: [Object.assign({}, stale, { state: 'stale', age_days: 30 })] } });
ok(h.includes('ručne overené pred 30 dňami'), 'stary manualny povod sa cita priamo v zozname');
const manualBudget = { stale: { counts: { manual_hardware: 1, attention: 1 }, items: [stale] } };
h = ctx.budPriceBtnHtml(manualBudget, false);
ok(h.includes('Skontrolovať ceny') && h.includes('bstalebtn'), 'manual-only tlacidlo ponuka realnu kontrolu');
let status = '';
ctx.budBudget = () => manualBudget;
ctx.budRerender = () => {};
ctx.NX = { setStatus(s){ status = s; } };
ctx.BUD_STALE_OPEN = false;
ctx.budPrStart();
eq(ctx.BUD_STALE_OPEN, true, 'klik pri manual-only otvori zoznam');
eq(ctx.BUD_PR, null, 'manual-only nevytvori prazdny Demos beh');
ok(status.includes('Overiť cenu'), 'status ukaze vykonatelny dalsi krok');
console.log('CENY-KOV-B budget manual: ' + n + ' checks PASS');
