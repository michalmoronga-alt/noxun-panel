// CENY-M1b — rucne overenie ceny dosky a ABS bez Demosu (Štúdio → Materiály).
//
// Co tato sada strazi (package CENY-M1 §7 bod 4):
//   O5   texty stavu (tooltip ikony, vek 0/1/12, stara, nikdy, bez ceny,
//        s odkazom / bez odkazu) a stav ikony (siva / jantarova);
//   R21  zobrazenie €/m² na 2 desatinne — bunka (bodka), formular variantu,
//        editor „Upraviť…" (ciarka); ABS €/bm presne;
//   R22  veta o rucnom overeni pod odkazom vo formulari variantu;
//   R20  ciste funkcie prepoctu, rozdielu a poznamky (platna ↔ m², bez
//        formatu, 0 €, percenta) + tok modalu: prepare → ready → open ack →
//        submit → vysledok; O9 bez prehliadaca; `browserPending` (M18);
//        cudzi token (M19); neuspesne otvorenie potvrdenie NEBLOKUJE (M21);
//        odchod zo sekcie; zmena dokumentu; konflikt = novy formular; Enter;
//        Esc = nic sa nezapise; payload bez server-owned poli;
//   R20b 10× prepnutie jednotky bez pisania = bitovo ta ista cena (M24);
//        napisana cena → prepnutie → potvrdenie posle ZAMER;
//   R1   MD_CLIENT_SCHEMA = 12.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mkEl, DOC, dispatch } = require('./minidom.js');

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
['nxModalRoot', 'status'].forEach(function(id){ const e = mkEl('div'); e.id = id; DOC.body.appendChild(e); });
// Polia formularov variantu (ms_/me_) sa vytvoria na poziadanie — kazde vo
// vlastnom `.row` (vzor studio.html), aby `closest('.row')` fungoval.
const origGet = DOC.getElementById;
DOC.getElementById = function(id){
  const hit = origGet.call(DOC, id);
  if (hit || !/^(ms_|me_|mdSheetForm$|mdEdgeForm$|mdDecorForm$)/.test(id)) return hit;
  const row = mkEl('div'); row.className = 'row';
  const e = mkEl(/_hint$|_warn$|Form$/.test(id) ? 'div' : 'input'); e.id = id;
  row.appendChild(e); DOC.body.appendChild(row);
  return e;
};

let time = 0;
const timers = [];
global.setTimeout = function(fn, ms){ timers.push({ fn: fn, at: time + (ms || 0) }); return timers.length; };
global.clearTimeout = function(id){ if (timers[id - 1]) timers[id - 1].fn = null; };
function tick(ms){
  time += ms;
  timers.forEach(function(t){ if (t.fn && t.at <= time){ const fn = t.fn; t.fn = null; fn(); } });
}
const SENT = [];
global.sketchup = new Proxy({}, { get: function(_t, key){ return function(s){ SENT.push([key, JSON.parse(s)]); }; } });
global.window.sketchup = global.sketchup;
const NXModal = require(path.join(JS, 'nx_modal.js'));
global.window.NXModal = NXModal;
require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
global.studioSec = 'mat';
const M = require(path.join(JS, 'proj_materials.js'));
M.setModelGuidForTest('doc-A');

function count(a){ return SENT.filter(function(x){ return x[0] === a; }).length; }
function last(a){ const h = SENT.filter(function(x){ return x[0] === a; }); return h.length ? h[h.length - 1][1] : null; }
function statusText(){ return DOC.getElementById('status').textContent; }
function priceInput(){ return DOC.getElementById('nxm_price'); }

// --- katalog (tvar full_catalog_payload) --------------------------------------
const FRESH = { state: 'fresh', checked_at: '2026-09-18T08:00:00Z', age_days: 12 };
const S25 = { material_id: 'S25', decor: 'H1180', decor_name: 'Dub Halifax prírodný', type: 'DTDL', thickness: 25,
              grain: 'length', price_per_m2: 179.9 / 5.796, code: '310418', supplier: 'Drevocentrum',
              sheet_size: [2800, 2070], group_id: 'G', structure: 'ST37', row_rev: 'r25',
              product_url: 'https://shop.example.sk/dtdl-25', product_link: true,
              price_check_method: 'manual', price_checked_at: FRESH.checked_at, price_check: FRESH,
              price_display: { plate: 179.9, m2: 31.04, area: 5.796 } };
const GLASS = { material_id: 'SK4', decor: 'SKLO', type: 'SKLO', thickness: 4, price_per_m2: 95.5, group_id: 'GS',
                row_rev: 'rsk', product_link: false, price_check: { state: 'never', checked_at: null, age_days: null },
                price_display: { plate: null, m2: 95.5, area: null } };
const E08 = { abs_id: 'E08', decor: 'H1180', decor_name: 'Dub Halifax prírodný', thickness: 0.8, width: 43,
              price_per_bm: 0.125, code: 'ABS-08', group_id: 'G', structure: 'ST37', row_rev: 're',
              product_link: false, price_check: { state: 'stale', checked_at: '2026-08-16T08:00:00Z', age_days: 45 },
              price_check_method: 'manual', price_checked_at: '2026-08-16T08:00:00Z', price_display: { bm: 0.125 } };
const S18D = { material_id: 'S18', decor: 'H1180', type: 'DTDL', thickness: 18, price_per_m2: 20,
               demos_url: 'https://www.demos-trade.sk/h1180-18', price_checked_at: '2026-09-01T10:00:00Z',
               group_id: 'G', structure: 'ST37', row_rev: 'r18', price_display: { plate: null, m2: 20, area: null } };
function catalog(sheets, edges, extra){
  return Object.assign({ materials: { sheets: [] }, catalog: { sheets: sheets, edges: edges || [] }, protected_ids: [],
    catalog_rev: 'CR' + Math.random(), catalog_schema: 12, catalog_state: 'ok', stale_days: 30 }, extra || {});
}
M.mdSetCatalog(catalog([S25, GLASS, S18D], [E08]));

// --- R1 -------------------------------------------------------------------------
eq(M.MD_CLIENT_SCHEMA, 12, 'klient hlasi schemu 12 (price_check_method)');

// --- O5: texty a ikona ------------------------------------------------------------
(function(){
  eq(M.mdAgeText(0), 'dnes');
  eq(M.mdAgeText(1), 'pred 1 dňom');
  eq(M.mdAgeText(12), 'pred 12 dňami');
  eq(M.mdManualTip(S25), 'Cena ručne overená 18.9.2026 (pred 12 dňami)\nOveriť cenu — otvorí obchod a formulár');
  eq(M.mdManualTip(Object.assign({}, S25, { price_check: { state: 'fresh', checked_at: '2026-09-30T08:00:00Z', age_days: 0 } })).split('\n')[0],
     'Cena ručne overená 30.9.2026 (dnes)');
  eq(M.mdManualTip(Object.assign({}, S25, { price_check: { state: 'fresh', checked_at: '2026-09-29T08:00:00Z', age_days: 1 } })).split('\n')[0],
     'Cena ručne overená 29.9.2026 (pred 1 dňom)');
  eq(M.mdManualTip(E08), 'Ručne overená 16.8.2026 — pred 45 dňami, na kontrolu\nOveriť cenu — bez odkazu otvorí len formulár');
  eq(M.mdManualTip(GLASS).split('\n')[0], 'Cena nebola nikdy ručne overená — na kontrolu');
  const noPrice = Object.assign({}, GLASS); delete noPrice.price_per_m2;
  eq(M.mdManualTip(noPrice).split('\n')[0], 'Cena chýba a nebola nikdy overená — na kontrolu');
  const fresh = M.mdCheckBtn('sheet', 'S25', S25);
  ok(/class="mduni mdchk"/.test(fresh) && !/is-pending/.test(fresh), 'cerstva = siva');
  ok(/aria-label="Overiť cenu · DTDL 25"/.test(fresh));
  ok(/#i-clipboard-check/.test(fresh));
  ok(/mdchk is-pending/.test(M.mdCheckBtn('edge', 'E08', E08)), 'stara = jantar');
  ok(/mdchk is-pending/.test(M.mdCheckBtn('sheet', 'SK4', GLASS)), 'nikdy = jantar');
  eq(M.mdCheckBtn('sheet', 'S18', S18D), '', 'Demos riadok ikonu overenia nema');
  eq(M.mdCheckBtn('sheet', 'X', { material_id: 'X' }), '', 'bez price_check (UNI/duplak) nic');
  // pozicia 3 slotu v riadku
  const h = M.mdSectionRows({ sheets: [S25, S18D], edges: [E08] });
  const rows = h.split('<div class="mdvrow"').slice(1);
  // title tooltipu nesie novy riadok — [\s\S], nie bodka
  const slot = rows[0].match(/<span class="mdslot">([\s\S]*?)<\/span><span class="mdvact">/)[1];
  const parts = slot.match(/<i class="mdgap"><\/i>|<button[^>]*>[\s\S]*?<\/button>/g);
  eq(parts.length, 3, 'slot drzi 3 pozicie');
  ok(/mdchk/.test(parts[2]), 'overenie je na 3. pozicii');
  ok(/mdprod/.test(parts[1]), 'odkaz na 2. pozicii');
  ok(/<i class="mdgap"><\/i><\/span>/.test(rows[1].match(/<span class="mdslot">[\s\S]*?<\/span><span class="mdvact">/)[0]), 'Demos riadok: 3. pozicia prazdna');
  // R21 bunka: zobrazena €/m² s bodkou, data-orig = zobrazeny text
  ok(rows[0].indexOf('value="31.04"') >= 0 && rows[0].indexOf('data-orig="31.04"') >= 0, 'bunka €/m² na 2 desatinne');
  ok(rows[2].indexOf('value="0.125"') >= 0, 'ABS €/bm presne (nezaokruhluje sa)');
  // read-only katalog: ikona vypnuta cez aria-disabled (UI_DIZAJN, D-78), klik povie dovod
  M.mdSetCatalog(catalog([S25], [E08], { catalog_state: 'read_only' }));
  const ro = M.mdCheckBtn('sheet', 'S25', S25);
  ok(/aria-disabled="true"/.test(ro) && !/ disabled/.test(ro), 'read-only = aria-disabled, nie HTML disabled');
  ok(ro.indexOf('Katalóg je len na čítanie') >= 0, 'dovod v tooltipe');
  const prepRo = SENT.filter(function(x){ return x[0] === 'mat_manual_prepare'; }).length;
  M.mdManualRequest('sheet', 'S25', null);
  eq(SENT.filter(function(x){ return x[0] === 'mat_manual_prepare'; }).length, prepRo, 'read-only nic neposle');
  eq(DOC.getElementById('status').textContent, 'Katalóg je len na čítanie — úpravy sú vypnuté.');
  M.mdSetCatalog(catalog([S25, GLASS, S18D], [E08]));
})();

// --- R21 / R22: formular variantu a editor --------------------------------------
(function(){
  eq(M.mdM2Shown(S25, '.'), '31.04');
  eq(M.mdM2Shown(S25, ','), '31,04');
  eq(M.mdM2Shown({ price_per_m2: 12.5 }, '.'), '12.5', 'bez price_display povodna hodnota');
  eq(M.mdEditSheetRow(S25).price_per_m2, '31,04', 'editor „Upraviť…" ukazuje zobrazenu €/m² s ciarkou');
  M.mdOpenSheetForm('S25');
  eq(DOC.getElementById('ms_price').value, '31.04', 'pole Cena formulara variantu na 2 desatinne');
  eq(DOC.getElementById('ms_product_hint').textContent,
     'Otvorí sa vo webovom prehliadači. Cena ručne overená 18.9.2026 — zmena odkazu, ceny, kódu, dodávateľa alebo formátu overenie zruší.');
  eq(DOC.getElementById('ms_demos_hint').style.display, 'none', 'rucny datum sa neukazuje ako datum Demosu');
  M.mdOpenEdgeForm('E08');
  eq(DOC.getElementById('me_product_hint').textContent,
     'Otvorí sa vo webovom prehliadači. Cena ručne overená 16.8.2026 — zmena odkazu, ceny, kódu alebo dodávateľa overenie zruší.');
  M.mdOpenSheetForm('SK4');
  eq(DOC.getElementById('ms_product_hint').textContent, 'Otvorí sa vo webovom prehliadači. Cena zatiaľ nebola ručne overená.');
  M.mdOpenSheetForm('S18');
  ok(DOC.getElementById('ms_product_hint').textContent.indexOf('Položka je viazaná na Demos') === 0, 'Demos: zamok, nie veta R22');
  eq(M.mdManualFormText('sheet', null), '', 'novy zaznam bez vety');
})();

// --- R20: ciste funkcie ------------------------------------------------------------
(function(){
  eq(M.mdManualInit('sheet', S25), { mode: 'plate', text: '179,90', touched: false, src: null }, 'doska s formatom = za platnu');
  eq(M.mdManualInit('sheet', GLASS), { mode: 'm2', text: '95,50', touched: false, src: null }, 'bez formatu = za m² (O3)');
  eq(M.mdManualInit('edge', E08), { mode: 'bm', text: '0,125', touched: false, src: null }, 'ABS presne');
  eq(M.mdManualCalc(S25, 'plate', '179,90'), { t: '→ 31,04 €/m² (2800 × 2070)', warn: false });
  eq(M.mdManualCalc(S25, 'm2', '31,04'), { t: '= 179,91 € za platňu (2800 × 2070)', warn: false }, 'nahlad prepoctu napisaneho cisla');
  eq(M.mdManualCalc(GLASS, 'm2', '95,5').t, 'bez prepočtu — formát nie je v katalógu');
  ok(M.mdManualCalc(GLASS, 'plate', '1').warn, 'za platnu bez formatu = varovanie');
  eq(M.mdManualCalc(E08, 'bm', '1').t, '');
  eq(M.mdManualDiff(S25, 'plate', '179,90'), { t: 'bez zmeny (179,90 € za platňu) — stačí potvrdiť', cls: 'same' });
  eq(M.mdManualDiff(S25, 'plate', '182,20'), { t: '+2,30 € (+1,3 %) oproti katalógu (179,90 € za platňu)', cls: 'chg' });
  eq(M.mdManualDiff(S25, 'plate', '170').t, '−9,90 € (−5,5 %) oproti katalógu (179,90 € za platňu)');
  eq(M.mdManualDiff(E08, 'bm', '0,13').cls, 'chg', 'ABS 0,125 vs 0,13 = zmena');
  eq(M.mdManualDiff(E08, 'bm', '0,125').cls, 'same');
  eq(M.mdManualDiff({ price_display: { plate: null, m2: null, area: 5.796 } }, 'plate', '1').t, 'v katalógu zatiaľ bez ceny');
  eq(M.mdManualNote(S25, '179,90'), 'Posledné ručné potvrdenie: 18.9.2026. Potvrdená cena platí v celom katalógu.');
  eq(M.mdManualNote(GLASS, '0'), 'Cena zatiaľ nebola ručne potvrdená. Potvrdená cena platí v celom katalógu. 0 € — materiál sa do rozpočtu započíta nulou (napr. ho dodá zákazník).');
  eq(M.mdManualCheck(S25, 'plate', ''), { field: 'price', msg: 'Vlož nezápornú cenu s DPH; prázdna cena sa nedá potvrdiť.' });
  eq(M.mdManualCheck(S25, 'plate', 'abc').field, 'price');
  eq(M.mdManualCheck(S25, 'plate', '-1').field, 'price');
  eq(M.mdManualCheck(S25, 'plate', '0'), null, '0 € je platna (O4)');
  ok(/bez formátu/.test(M.mdManualCheck(GLASS, 'plate', '10').msg), 'za platnu bez formatu = chyba navrchu');
  eq(M.mdManualSub('sheet', S25), 'H1180 DTDL 25 mm · Dub Halifax prírodný');
  eq(M.mdManualSub('edge', E08), 'ABS H1180 43/0,8 · Dub Halifax prírodný');
  eq(M.mdManualInfo('sheet', S25), 'kód 310418 · formát 2800 × 2070 mm (5,796 m²)');
  eq(M.mdManualInfo('sheet', GLASS), 'kód — · formát nie je v katalógu');
  eq(M.mdManualInfo('edge', E08), 'ABS 43 × 0,8 mm · kód ABS-08');
})();

// --- R20b: prepnutie jednotky (M24) ----------------------------------------------
(function(){
  let st = M.mdManualInit('sheet', S25);
  for (let i = 0; i < 10; i++){
    st = M.mdManualSwitch(S25, st, 'm2');
    eq(st.text, '31,04', 'm² = zobrazena hodnota servera');
    st = M.mdManualSwitch(S25, st, 'plate');
  }
  eq(st, { mode: 'plate', text: '179,90', touched: false, src: null }, '10× tam a spat = ta ista cena, nedotknute');
  eq(M.mdManualValue(st), { basis: 'plate', price: '179,90' });
  st = M.mdManualSwitch(S25, st, 'm2');
  eq(M.mdManualValue(st), { basis: 'm2', price: '31,04' }, 'nedotknute v m² = zobrazena €/m² (server echo)');
  st = M.mdManualTyped(M.mdManualInit('sheet', S25), '185');
  st = M.mdManualSwitch(S25, st, 'm2');
  eq(st.text, '31,92', 'prepocet NAPISANEHO cisla');
  eq(M.mdManualValue(st), { basis: 'plate', price: '185' }, 'odosle sa zamer (napisana platna), nie prepocitany text');
  st = M.mdManualSwitch(S25, st, 'plate');
  eq(st.text, '185', 'navrat vrati presne napisany text');
})();

// --- tok modalu ---------------------------------------------------------------------
function reset(){
  M.mdManualClose(); NXModal.setBusy(false); NXModal.close(); global.studioSec = 'mat';
  M.setModelGuidForTest('doc-A'); M.mdSetCatalog(catalog([S25, GLASS, S18D], [E08])); tick(100);
}
function request(kind, id){ M.mdManualRequest(kind, id, null); return last('mat_manual_prepare'); }
function snap(req, item, more){
  return Object.assign({}, req, { item: item, row_rev: item.row_rev, has_url: item.product_link === true,
    read_only: false, reason: null, stale_days: 30 }, more || {});
}
function ready(req, item, more){ M.MD.manualReady(snap(req, item, more)); }
function result(req, more){
  M.MD.manualResult(Object.assign({}, req, { phase: 'submit', ok: false, status: 'invalid', item: S25, row_rev: 'r25',
    has_url: true, read_only: false, msg: 'Chyba', errors: [{ field: 'price', msg: 'Chyba' }] }, more || {}));
}
function openAck(req, more){ result(req, Object.assign({ phase: 'open', ok: true, status: 'ok', errors: [], opened: true }, more || {})); }

// prepare → ready → open → submit (s odkazom)
reset();
let req = request('sheet', 'S25');
eq(req, { kind: 'sheet', id: 'S25', token: req.token, section: 'mat', model_guid: 'doc-A' }, 'prepare nesie len identitu');
ready(req, S25);
ok(NXModal.isOpen(), 'formular sa otvoril');
eq(NXModal.spec().title, 'Overiť cenu ručne');
eq(NXModal.spec().sub, 'H1180 DTDL 25 mm · Dub Halifax prírodný');
eq(NXModal.spec().okLabel, 'Potvrdiť cenu k dnešku');
eq(NXModal.values(), { price: { basis: 'plate', price: '179,90' } }, 'prefill = zobrazena cena platne');
eq(DOC.activeElement && DOC.activeElement.id, 'nxm_price', 'fokus v poli ceny');
const opens0 = count('mat_manual_open');
tick(20); eq(count('mat_manual_open'), opens0, 'najprv dobehne fokus');
tick(5); eq(count('mat_manual_open'), opens0 + 1, 'po 25 ms sa otvori obchod');
const openReq = last('mat_manual_open');
eq(openReq.row_rev, 'r25'); eq(openReq.kind, 'sheet');
// M18: potvrdenie pred odpovedou o otvoreni sa neodosle
NXModal.submit();
eq(count('mat_manual_confirm'), 0, 'pred ack sa nepotvrdzuje');
ok(DOC.getElementById('nxModalRoot').textContent.indexOf('Počkaj na otvorenie produktu') >= 0);
ok(!NXModal.isBusy(), 'formular ostava ovladatelny');
// M19: cudzi token ack neodblokuje
openAck(Object.assign({}, openReq, { token: 'cudzi' }));
NXModal.submit(); eq(count('mat_manual_confirm'), 0, 'cudzi ack neodblokuje');
openAck(openReq);
NXModal.submit();
eq(count('mat_manual_confirm'), 1, 'po ack sa potvrdzuje');
let save = last('mat_manual_confirm');
eq([save.kind, save.id, save.row_rev, save.basis, save.price, save.section, save.model_guid, save.catalog_schema],
   ['sheet', 'S25', 'r25', 'plate', '179,90', 'mat', 'doc-A', 12]);
ok(!('price_checked_at' in save) && !('price_check_method' in save), 'server-owned polia klient neposiela');
ok(NXModal.isBusy() && NXModal.busyLocked(), 'pocas zapisu zamknute');
NXModal.close(); ok(NXModal.isOpen(), 'po odoslani Zrusit nezrusi zapis');
result(Object.assign({}, save, { token: 'cudzi' }), { ok: true, status: 'ok' });
ok(NXModal.isOpen() && NXModal.isBusy(), 'cudzia odpoved modal nevlastni');
result(save, { ok: true, status: 'ok', msg: 'Cena potvrdená k 30.9.2026: 179,90 € za platňu = 31,04 €/m².' });
ok(!NXModal.isOpen(), 'uspech zatvori formular');
eq(statusText(), 'Cena potvrdená k 30.9.2026: 179,90 € za platňu = 31,04 €/m².');

// M21: neuspesne otvorenie prehliadaca potvrdenie neblokuje
reset(); req = request('sheet', 'S25'); ready(req, S25); tick(25);
openAck(last('mat_manual_open'), { opened: false, msg: 'Obchod sa nepodarilo otvoriť — cenu si over inak a potvrď.' });
ok(NXModal.isOpen(), 'formular ostava');
ok(DOC.getElementById('nxModalRoot').textContent.indexOf('Obchod sa nepodarilo otvoriť') >= 0, 'upozornenie vo formulari');
NXModal.submit();
eq(count('mat_manual_confirm'), 2, 'potvrdit sa da aj bez otvoreneho obchodu (B1)');
result(last('mat_manual_confirm'), { ok: true, status: 'ok' });

// odmietnute otvorenie (zmeneny riadok) formular zavrie
reset(); req = request('sheet', 'S25'); ready(req, S25); tick(25);
result(last('mat_manual_open'), { phase: 'open', ok: false, status: 'conflict', msg: 'Položka sa medzitým zmenila — skontroluj aktuálne údaje.' });
ok(!NXModal.isOpen(), 'zmenena polozka = zatvorit');
eq(statusText(), 'Položka sa medzitým zmenila — skontroluj aktuálne údaje.');

// O9: bez odkazu sa prehliadac neotvara a potvrdit sa da hned; Enter potvrdzuje
reset(); const before = count('mat_manual_open');
req = request('sheet', 'SK4'); ready(req, GLASS); tick(50);
eq(count('mat_manual_open'), before, 'bez odkazu ziadne otvorenie');
ok(DOC.getElementById('nxModalRoot').textContent.indexOf('Bez odkazu — obchod sa neotvorí') >= 0);
priceInput().value = '0';
dispatch(priceInput(), 'input');
ok(DOC.getElementById('nxModalRoot').textContent.indexOf('0 € — materiál sa do rozpočtu započíta nulou') >= 0, 'veta O4 pri 0');
dispatch(priceInput(), 'keydown', { key: 'Enter' });
save = last('mat_manual_confirm');
eq([save.id, save.basis, save.price], ['SK4', 'm2', '0'], 'Enter potvrdi; sklo za m²; 0 € ide');
result(save, { ok: true, status: 'ok' });

// Esc = nic sa nezapise; prazdna cena sa nepotvrdi
reset(); req = request('sheet', 'SK4'); ready(req, GLASS);
const confirms = count('mat_manual_confirm');
priceInput().value = ''; dispatch(priceInput(), 'input');
NXModal.submit(); eq(count('mat_manual_confirm'), confirms, 'prazdna cena sa nepotvrdi');
dispatch(priceInput(), 'keydown', { key: 'Escape' });
ok(!NXModal.isOpen(), 'Esc zavrie');
eq(count('mat_manual_confirm'), confirms, 'Esc nic nezapisal');

// R20b v modali: 10× prepnutie bez pisania → potvrdenie tej istej ceny (M24)
reset(); req = request('sheet', 'S25'); ready(req, S25); tick(25); openAck(last('mat_manual_open'));
for (let i = 0; i < 10; i++){
  dispatch(DOC.querySelector('[data-mdm-mode="m2"]'), 'click');
  eq(priceInput().value, '31,04');
  dispatch(DOC.querySelector('[data-mdm-mode="plate"]'), 'click');
}
eq(priceInput().value, '179,90', 'po 10 prepnutiach ta ista cena platne');
NXModal.submit();
save = last('mat_manual_confirm');
eq([save.basis, save.price], ['plate', '179,90'], 'potvrdenie = bitovo ta ista cena, len datum');
result(save, { ok: true, status: 'ok' });
// napisana cena → prepnutie → potvrdenie posle zamer
reset(); req = request('sheet', 'S25'); ready(req, S25); tick(25); openAck(last('mat_manual_open'));
priceInput().value = '185'; dispatch(priceInput(), 'input');
ok(DOC.getElementById('nxModalRoot').textContent.indexOf('+5,10 €') >= 0, 'zivy rozdiel oproti katalogu');
dispatch(DOC.querySelector('[data-mdm-mode="m2"]'), 'click');
eq(priceInput().value, '31,92');
NXModal.submit();
save = last('mat_manual_confirm');
eq([save.basis, save.price], ['plate', '185'], 'odoslany zamer, nie prepocitany text');
// konflikt → novy formular s cerstvymi udajmi, bez automatickeho potvrdenia
const saved = count('mat_manual_confirm');
const S25b = Object.assign({}, S25, { row_rev: 'r25b', price_display: { plate: 190, m2: 32.78, area: 5.796 } });
result(save, { status: 'conflict', item: S25b, row_rev: 'r25b', msg: 'Položka sa medzitým zmenila — skontroluj aktuálne údaje.' });
ok(NXModal.isOpen(), 'konflikt otvori formular nanovo');
eq(priceInput().value, '190,00', 'cerstva cena');
eq(count('mat_manual_confirm'), saved, 'povodna cena sa sama neposle znova');
tick(25); eq(last('mat_manual_open').row_rev, 'r25b');
openAck(last('mat_manual_open'));
NXModal.submit(); eq(last('mat_manual_confirm').row_rev, 'r25b', 'dalsie potvrdenie nesie novu reviziu');
result(last('mat_manual_confirm'), { ok: true, status: 'ok' });
// chyba servera pri poli ostava vo formulari
reset(); req = request('edge', 'E08'); ready(req, E08);
eq(NXModal.values(), { price: { basis: 'bm', price: '0,125' } }, 'ABS €/bm presne');
NXModal.submit(); save = last('mat_manual_confirm');
eq(save.basis, 'bm');
result(save, { item: E08, status: 'invalid', errors: [{ field: 'price', msg: 'Cena nesmie byť záporná.' }] });
ok(NXModal.isOpen() && !NXModal.isBusy(), 'chyba odomkne formular');
ok(DOC.getElementById('nxModalRoot').textContent.indexOf('Cena nesmie byť záporná.') >= 0);
result(save, { ok: true, status: 'ok' });
NXModal.submit(); result(last('mat_manual_confirm'), { ok: true, status: 'ok' });

// zivotny cyklus: odchod zo sekcie, zmena dokumentu, cudzi token, read-only, Demos
reset(); req = request('sheet', 'S25'); ready(req, Object.assign({}, S25), { token: 'cudzi' });
ok(!NXModal.isOpen(), 'odpoved s cudzim tokenom sa ignoruje');
ready(req, S25); ok(NXModal.isOpen());
M.matCloseModals(); ok(!NXModal.isOpen(), 'odchod zo sekcie formular zavrie');
reset(); req = request('sheet', 'S25'); M.matCloseModals(); ready(req, S25);
ok(!NXModal.isOpen(), 'odchod zahodi aj cakajuci prepare');
reset(); req = request('sheet', 'S25'); ready(req, S25); const openBefore = count('mat_manual_open');
M.mdManualContextChanged('mat', 'doc-B'); tick(25);
ok(!NXModal.isOpen(), 'zmena dokumentu formular zavrie');
eq(count('mat_manual_open'), openBefore, 'a obchod sa uz neotvori');
reset(); req = request('sheet', 'S25'); ready(req, S25, { read_only: true, reason: 'novšia verzia' });
ok(!NXModal.isOpen(), 'read-only = bez formulara');
reset(); req = request('sheet', 'S18'); ready(req, S18D);
ok(!NXModal.isOpen(), 'Demos polozka formular nema');
eq(statusText(), 'Položka je viazaná na Demos — cenu obnovuje Demos.');
reset(); global.studioSec = 'bom'; const prep = count('mat_manual_prepare');
M.mdManualRequest('sheet', 'S25', null); eq(count('mat_manual_prepare'), prep, 'mimo sekcie mat sa nic neposiela');
reset(); req = request('sheet', 'S25'); ready(req, S25); tick(25); openAck(last('mat_manual_open'));
NXModal.submit(); save = last('mat_manual_confirm');
M.mdManualContextChanged('bom', 'doc-A');
NXModal.open({ title: 'Iný formulár', fields: [{ key: 'x', label: 'X' }] });
result(save, { ok: true, status: 'ok' });
eq(NXModal.spec().title, 'Iný formulár', 'neskora odpoved nevlastni cudzi modal');
NXModal.close();

console.log('OK ' + n + ' kontrol (CENY-M1b rucne overenie ceny)');
