// CENY-KOV-A: skutocny NXModal + jeho odlozeny fokus a delegovany klik.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mkEl, DOC, dispatch } = require('./minidom.js');
const JS = path.join(__dirname, '../../noxun_engine/ui/js');
let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }
['nxModalRoot', 'status', 'hwList'].forEach(id => {
  const el = mkEl('div'); el.id = id; DOC.body.appendChild(el);
});
const timers = [];
global.setTimeout = fn => { timers.push(fn); return timers.length; };
global.clearTimeout = id => { timers[id - 1] = null; };
function flush(){ const list = timers.splice(0); list.forEach(fn => { if (fn) fn(); }); }
const sent = [];
global.sketchup = new Proxy({}, { get: (_t, key) => s => sent.push([key, JSON.parse(s)]) });
global.window.sketchup = global.sketchup;
global.NXModal = require(path.join(JS, 'nx_modal.js'));
global.NX = global.window.NX = {};
global.ST = { model_guid: 'doc-A' };
global.studioSec = 'budget';
const H = require(path.join(JS, 'hw_catalog.js'));
global.studioGoSection = section => {
  H.hwProductContextChanged(section, ST.model_guid);
  global.studioSec = section;
};
const ctx = { categories: ['OSTATNE'], units: ['ks'], taxonomy: {
  manufacturers: ['Blum'], series: [], read_only: false, write_blocked: false
} };
function item(code, more){ return Object.assign({ item_code: code, name_sk: 'Položka ' + code,
  category: 'OSTATNE', unit: 'ks', row_rev: 'rev-' + code, price_eur_vat: 12 }, more); }
function count(action){ return sent.filter(x => x[0] === action).length; }
function last(action){ return sent.filter(x => x[0] === action).at(-1)[1]; }
function request(code){
  const el = mkEl('button'); el.setAttribute('data-action', 'hw-product');
  el.setAttribute('data-code', code); DOC.body.appendChild(el);
  dispatch(el, 'click'); return last('hw_product_prepare');
}
function ready(req, more){
  H.MDH.productReady(Object.assign({}, req, { item: item(req.code), row_rev: 'fresh-' + req.code,
    has_url: false, read_only: false, context: ctx }, more));
}
function close(){ NXModal.setBusy(false); NXModal.close(); flush(); }
function origin(){ close(); studioSec = 'budget'; ST = { model_guid: 'doc-A' }; }

// Položka v tomto procese nikdy nebola v katalógovom strome: rozhoduje reply.
origin();
let req = request('OUTSIDE');
ready(req);
eq(studioSec, 'hw', 'chyba odkaz -> existujuci editor v katalogu');
ok(NXModal.isOpen());
eq(DOC.activeElement.id, 'nxm_product_url', 'URL ma fokus hned');
flush();
eq(DOC.activeElement.id, 'nxm_product_url', '20 ms fokus ho neprepise menom');
eq(NXModal.values().name, 'Položka OUTSIDE');
eq(NXModal.values().unit, 'ks', 'enumy prisli s konkretnej polozkou');
const before = count('hw_patch');
close();
eq(count('hw_patch'), before, 'zrusenie neposiela zapis');

// Iba URL delta, spravna identita, odmietnutie drzi draft a konflikt preberie rev.
origin(); req = request('OUTSIDE'); ready(req);
DOC.getElementById('nxm_product_url').value = 'https://shop.example/p';
NXModal.submit();
eq(last('hw_patch').code, 'OUTSIDE');
eq(last('hw_patch').row_rev, 'fresh-OUTSIDE');
eq(last('hw_patch').patch, { product_url: 'https://shop.example/p' });
NXModal.close();
ok(NXModal.isOpen(), 'prebiehajuci edit ma busyLock');
H.MDH.itemResult(false, 'Neplatný odkaz', [{ field: 'product_url', msg: 'Chyba' }], 'patch', last('hw_patch').token);
eq(NXModal.values().product_url, 'https://shop.example/p', 'odmietnutie nestrati draft');
H.hwApplyState({ catalog: { items: [item('OUTSIDE', { row_rev: 'new-rev', product_url: 'https://other.example/p' })], state: 'ok' } });
NXModal.submit();
H.MDH.itemResult(false, 'Položka sa medzitým zmenila', [], 'patch', last('hw_patch').token);
flush();
eq(NXModal.values().product_url, 'https://other.example/p', 'konflikt vedome preberie cerstvy stav');
eq(DOC.activeElement.id, 'nxm_product_url', 'rebase drzi URL fokus');
DOC.getElementById('nxm_product_url').value = 'https://third.example/p';
NXModal.submit();
eq(last('hw_patch').row_rev, 'new-rev');
H.MDH.itemResult(true, 'Uložené', [], 'patch', last('hw_patch').token);
ok(!NXModal.isOpen());

// Ulozeny odkaz -> iba open; read-only nebrani citaniu.
origin(); req = request('LINK');
let opens = count('hw_product_open');
ready(req, { has_url: true, read_only: true });
eq(count('hw_product_open'), opens + 1);
eq(last('hw_product_open'), { code: 'LINK', model_guid: 'doc-A' }, 'klient neposiela URL');
eq(studioSec, 'budget');
ok(!NXModal.isOpen());
req = request('NO-LINK'); ready(req, { read_only: true, reason: 'novšia verzia' });
ok(!NXModal.isOpen(), 'read-only bez odkazu nesmie otvorit edit');

// Dva rychle kliky: oneskorena odpoved A neotvori web ani editor B.
origin(); const a = request('A'); const b = request('B'); opens = count('hw_product_open');
ready(a, { has_url: true });
eq(count('hw_product_open'), opens);
ready(b); eq(NXModal.values().name, 'Položka B'); close();
origin(); req = request('A');
H.hwProductContextChanged('hw', ST.model_guid); studioSec = 'hw';
H.hwProductContextChanged('budget', ST.model_guid); studioSec = 'budget';
ready(req, { has_url: true }); eq(count('hw_product_open'), opens, 'odchod-navrat neozivi request');
origin(); req = request('A');
H.hwProductContextChanged('budget', 'doc-B'); ST = { model_guid: 'doc-B' };
ready(req); ok(!NXModal.isOpen(), 'zmena dokumentu zahodi odpoved');
origin(); req = request('A');
NXModal.open({ title: 'Iný formulár', fields: [{ key: 'name', label: 'Meno' }] });
NXModal.close();
ready(req); ok(!NXModal.isOpen(), 'aj uz zatvoreny iny formular zrusi povodny zamer');

// Odlozeny fokus stareho modalu nikdy nepreskoci do uz zatvoreneho okna.
H.hwItemOpen(item('X'), null, { initialFocus: 'product_url' });
NXModal.close();
NXModal.open({ title: 'Druhý', fields: [{ key: 'other', label: 'Iné' }] });
flush(); eq(DOC.activeElement.id, 'nxm_other'); close();

// Jedna autorita zdroja: vazbu z Demosu nahradi len vedomy manualny flow.
const prop = { pid: 'p', code: 'D', name_sk: 'Demos', unit: 'ks', price_vat: 1 };
const d = H.hwItemDraftFromProposal({ product_url: 'https://old.example/p' }, prop);
eq(d.product_url, '', 'vyber noveho Demos produktu vycisti stary rucny odkaz');
ok(!H.hwDemosDirty(prop, d));
d.product_url = 'https://manual.example/p';
ok(H.hwDemosDirty(prop, d), 'vlastny odkaz po proposale ide manualnou cestou');
const bound = item('BOUND', { demos_url: 'https://www.demos-trade.sk/p/' });
H.hwItemOpen(bound, null, {});
ok(DOC.getElementById('nxm_product_url').hasAttribute('disabled'));
eq(H.hwItemPatch(H.hwItemDraftOf(bound), NXModal.values()), {}, 'zobrazenie Demos URL nie je URL patch');
close();
console.log(`OK ${n} kontrol (CENY-KOV-A odkazy a modal)`);
