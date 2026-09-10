// CENY-KOV-B: realny NXModal, obidva povody, oneskorene odpovede a busyLock.
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
let time = 0;
const timers = [];
global.setTimeout = (fn, ms) => { timers.push({ fn, at: time + (ms || 0) }); return timers.length; };
global.clearTimeout = id => { if (timers[id - 1]) timers[id - 1].fn = null; };
function tick(ms){
  time += ms;
  timers.forEach(t => { if (t.fn && t.at <= time){ const fn = t.fn; t.fn = null; fn(); } });
}
const sent = [];
global.sketchup = new Proxy({}, { get: (_t, key) => s => sent.push([key, JSON.parse(s)]) });
global.window.sketchup = global.sketchup;
global.NXModal = require(path.join(JS, 'nx_modal.js'));
global.NX = global.window.NX = {};
global.ST = { model_guid: 'doc-A' };
global.studioSec = 'budget';
const H = require(path.join(JS, 'hw_catalog.js'));
global.studioGoSection = section => { H.hwProductContextChanged(section, ST.model_guid); studioSec = section; };
function item(code, more){ return Object.assign({ item_code: code, name_sk: 'Položka ' + code,
  category: 'OSTATNE', unit: 'ks', supplier: 'Obchod', price_eur_vat: 12.5,
  product_url: 'https://shop.example/' + code }, more); }
function count(action){ return sent.filter(x => x[0] === action).length; }
function last(action){ return sent.filter(x => x[0] === action).at(-1)[1]; }
function origin(section = 'budget'){
  H.hwProductContextChanged('other', 'other'); NXModal.setBusy(false); NXModal.close();
  studioSec = section; ST = { model_guid: 'doc-A' }; tick(100);
}
function request(code){
  const el = mkEl('button'); el.setAttribute('data-action', 'hw-manual-check');
  el.setAttribute('data-code', code); DOC.body.appendChild(el); dispatch(el, 'click');
  return last('hw_manual_prepare');
}
function ready(req, more){ H.MDH.manualReady(Object.assign({}, req, {
  item: item(req.code), row_rev: 'rev-' + req.code, has_url: true, read_only: false
}, more)); }
function result(req, more){ H.MDH.manualResult(Object.assign({}, req, { phase: 'submit', ok: false,
  status: 'invalid', item: item(req.code), row_rev: req.row_rev, has_url: true, read_only: false,
  msg: 'Skontroluj cenu', errors: [{ field: 'price', msg: 'Chyba' }]
}, more)); }
function openAck(req = last('hw_manual_open')){ result(req, { phase: 'open', ok: true, status: 'ok', errors: [] }); }

origin(); let req = request('A'); const opens = count('hw_manual_open');
ready(req, { item: item('A', { price_check_method: 'manual', price_checked_at: '2026-08-01T08:00:00Z' }) });
eq(studioSec, 'budget', 'formular ostava v povodnom Rozpocte');
eq(NXModal.values(), { price: '12.5' }, 'kod, zdroj, dodavatel a jednotka sa nedaju prepisat');
ok(NXModal.spec().note.includes('ručné potvrdenie'));
eq(DOC.activeElement.id, 'nxm_price');
tick(20); eq(count('hw_manual_open'), opens, 'najprv prebehne odlozeny fokus');
tick(5); eq(count('hw_manual_open'), opens + 1);
eq(last('hw_manual_open').row_rev, 'rev-A');
const openReq = last('hw_manual_open');
openAck(openReq); ok(NXModal.isOpen(), 'open ack potvrdi len pokus otvorenia, nie cenu');
NXModal.close();
eq(count('hw_manual_confirm'), 0, 'Cancel po prehliadani nema zapis');
origin(); req = request('A'); ready(req); NXModal.close(); tick(25);
eq(count('hw_manual_open'), opens + 1, 'Cancel pred timerom uz neotvori browser');

// Explicitne potvrdenie 0, busyLock a kazda odpoved patri konkretnemu submite.
origin('hw'); req = request('A'); ready(req); tick(25);
openAck();
DOC.getElementById('nxm_price').value = '';
NXModal.submit(); eq(count('hw_manual_confirm'), 0, 'prazdna cena sa nepotvrdi');
ok(!NXModal.isBusy());
DOC.getElementById('nxm_price').value = '0'; NXModal.submit();
let save = last('hw_manual_confirm');
eq(save.price, '0'); eq(save.code, 'A'); eq(save.row_rev, 'rev-A');
ok(!('price_checked_at' in save) && !('price_check_method' in save));
NXModal.close(); ok(NXModal.isOpen(), 'po submite Cancel nezrusi uz odoslany zapis');
dispatch(DOC.getElementById('nxm_price'), 'keydown', { key: 'Escape' });
ok(NXModal.isOpen(), 'ani Escape');
H.hwItemOpen(item('OTHER'), null, {});
eq(NXModal.spec().title, 'Overiť cenu ručne', 'iny editor nenahradi busy manual formular');
result(Object.assign({}, save, { token: 'wrong' })); ok(NXModal.isBusy(), 'cudzia odpoved neodomkne');
result(save, { status: 'error' });
ok(NXModal.isOpen() && !NXModal.isBusy(), 'vynimka servera odomkne vlastny formular');
eq(NXModal.values().price, '0', 'zlyhanie nestrati draft');
NXModal.submit(); save = last('hw_manual_confirm');
result(save, { ok: true, status: 'ok' }); ok(!NXModal.isOpen());

// Konflikt zahodi povodnu cenu, obnovi zdroj/rev a nikdy sam nepotvrdi znova.
origin(); req = request('A'); ready(req); tick(25);
const originalOpen = last('hw_manual_open');
openAck(originalOpen);
DOC.getElementById('nxm_price').value = '88'; NXModal.submit(); save = last('hw_manual_confirm');
const savedCount = count('hw_manual_confirm');
result(save, { status: 'conflict', row_rev: 'fresh', item: item('A', { price_eur_vat: 7, product_url: 'https://shop.example/new' }) });
eq(NXModal.values().price, '7'); tick(25);
eq(last('hw_manual_open').row_rev, 'fresh');
eq(count('hw_manual_confirm'), savedCount, 'konflikt cenu automaticky neprehra');
result(originalOpen, { phase: 'open', status: 'error' });
ok(NXModal.isOpen(), 'stara open odpoved nemoze zavriet obnoveny formular');
openAck(originalOpen); NXModal.submit();
eq(count('hw_manual_confirm'), savedCount, 'stary success ack neodomkne obnoveny formular');
openAck();
NXModal.submit(); eq(last('hw_manual_confirm').row_rev, 'fresh');
eq(last('hw_manual_confirm').price, '7');
result(last('hw_manual_confirm'), { ok: true, status: 'ok' });

// Dva povody a vsetky oneskorene vstupy: ziadny cudzi web ani modal.
origin(); const a = request('A'); const b = request('B'); let beforeOpen = count('hw_manual_open');
ready(a); ok(!NXModal.isOpen()); ready(b); eq(NXModal.spec().sub, 'B · Položka B');
origin(); req = request('A'); studioGoSection('bom'); studioGoSection('budget'); ready(req); tick(25);
eq(count('hw_manual_open'), beforeOpen); ok(!NXModal.isOpen());
origin(); req = request('A'); H.hwProductContextChanged('budget', 'doc-B'); ST = { model_guid: 'doc-B' }; ready(req);
ok(!NXModal.isOpen());
origin(); req = request('A'); NXModal.open({ title: 'Iný', fields: [] }); NXModal.close(); ready(req);
ok(!NXModal.isOpen(), 'aj uz zatvoreny iny formular zrusi pending prepare');
origin(); req = request('A'); ready(req); studioGoSection('bom'); tick(25);
ok(!NXModal.isOpen()); eq(count('hw_manual_open'), beforeOpen, 'odchod zrusi aj pending browser');
origin(); req = request('A'); ready(req); tick(25); openAck(); NXModal.submit(); save = last('hw_manual_confirm');
H.hwProductContextChanged('budget', 'doc-B'); ST = { model_guid: 'doc-B' };
NXModal.open({ title: 'Nový dokument', fields: [{ key: 'x', label: 'X' }] });
result(save, { ok: true, status: 'ok' }); eq(NXModal.spec().title, 'Nový dokument');

origin(); req = request('NO-URL'); ready(req, { has_url: false });
eq(last('hw_product_prepare').code, 'NO-URL', 'chybajuci URL ide do existujuceho presneho editora');
ok(!NXModal.isOpen());
origin(); req = request('A'); ready(req, { read_only: true, reason: 'novšia verzia' }); ok(!NXModal.isOpen());
origin(); req = request('D'); ready(req, { item: item('D', { demos_url: 'https://www.demos-trade.sk/p/' }) });
ok(!NXModal.isOpen(), 'Demos viazany produkt nema manual formular');
origin(); req = request('A'); ready(req); tick(25);
result(last('hw_manual_open'), { phase: 'open', status: 'conflict' });
ok(!NXModal.isOpen(), 'odmietnute otvorenie nedovoli potvrdit staru cenu');

// Dispatch otvorenia nie je ack: rychly Enter pred oneskorenou chybou nesmie zapisat cenu.
origin(); req = request('A'); ready(req); tick(25);
const pendingOpen = last('hw_manual_open'); const beforeAck = count('hw_manual_confirm');
NXModal.submit(); eq(count('hw_manual_confirm'), beforeAck, 'submit medzi dispatch a ack sa neodosle');
ok(NXModal.isOpen() && !NXModal.isBusy(), 'pred cenovym zapisom sa stale da zrusit');
result(pendingOpen, { phase: 'open', status: 'error' });
ok(!NXModal.isOpen(), 'oneskorena open chyba sa spracuje este pred submitom');
eq(count('hw_manual_confirm'), beforeAck);
openAck(pendingOpen); ok(!NXModal.isOpen(), 'stary ack neozivi zatvoreny formular');
origin(); req = request('A'); ready(req); tick(25);
openAck(pendingOpen); NXModal.submit();
eq(count('hw_manual_confirm'), beforeAck, 'ack predchadzajuceho formulara neodblokuje novy');
openAck(); ok(NXModal.isOpen(), 'spravny ack len odblokuje potvrdenie');
NXModal.submit(); eq(count('hw_manual_confirm'), beforeAck + 1, 'po success ack moze pouzivatel potvrdit cenu');
result(last('hw_manual_confirm'), { ok: true, status: 'ok' });
console.log(`OK ${n} kontrol (CENY-KOV-B manualny formular)`);
