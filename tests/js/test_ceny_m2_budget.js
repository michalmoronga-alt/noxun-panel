// CENY-M2 — Rozpočet: ručné ceny dosiek a ABS + materiál bez formátu podľa m².
//
// Co tato sada strazi (package CENY-M2 §7 bod 4):
//   R14  ikona odkazu pred nazvom (Demos / obchod / chyba — jantar), UNI nic,
//        escapovanie a data-* identita;
//   R15  delegovany klik `mat-link`: Demos -> open_demos_url, obchod ->
//        mat_product_open (URL od klienta nikdy), chyba -> Materialy + formular
//        s kurzorom v poli odkazu; read-only katalog; chybajuci zaznam; ABS;
//   R16  stlpec „Overená" = stav + tlacidlo („ručne 18.9." / „ručne 45 dní" /
//        „neoverená"), plural, is-pending, aria-label;
//   R17  texty O5 — PARITY s `mdManualTip` (proj_materials.js) nad maticou;
//   R18  „Overiť cenu" z Rozpoctu: poziadavka so `section: 'budget'`, formular
//        OSTAVA v Rozpocte, bez odkazu bez `mat_manual_open`, odchod zavrie,
//        cudzi token sa ignoruje;
//   R19  riadok „podľa plochy": „0,90", „m²", bez „(…/m²)";
//   R20  cip „N cien na kontrolu" pri samych rucnych materialoch,
//        „Skontrolovať ceny", `budPrStart` otvori zoznam;
//   R21  zoznam: odkaz + „Overiť cenu", Demos: odkaz + obnovenie;
//   R22  tooltip cipu v Cenovej ponuke; R6 `BUD_PLAN_TIP`.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { mkEl, DOC, dispatch } = require('./minidom.js');

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

// --- budget.js v izolovanom kontexte (vzor test_ceny_kov_budget_manual.js) ----
const bctx = { console: console, document: DOC, setTimeout: setTimeout, clearTimeout: clearTimeout };
bctx.window = bctx;
vm.createContext(bctx);
vm.runInContext(fs.readFileSync(path.join(JS, 'budget.js'), 'utf8'), bctx);
const B = bctx;

// --- R14: ikona odkazu ----------------------------------------------------------
(function(){
  const demos = B.budMatLinkHtml({ material_id: 'H18', nazov: 'H1180 DTDL 18 mm', demos_link: true }, 'sheet');
  ok(demos.includes('data-action="mat-link"') && demos.includes('data-src="demos"'), 'Demos ikona');
  ok(demos.includes('title="Otvoriť produkt (Demos)"') && !demos.includes('is-missing'), 'Demos siva');
  ok(demos.includes('aria-label="Otvoriť produkt · H1180 DTDL 18 mm"'));
  const prod = B.budMatLinkHtml({ material_id: 'S"1', nazov: 'Sklo <x>', product_link: true }, 'sheet');
  ok(prod.includes('data-src="product"') && prod.includes('title="Otvoriť produkt v prehliadači"'), 'obchod');
  ok(prod.includes('data-id="S&quot;1"') && prod.includes('Sklo &lt;x&gt;'), 'escapovanie identity aj nazvu');
  ok(prod.includes('data-kind="sheet"'));
  const miss = B.budMatLinkHtml({ abs_id: 'E43', nazov: 'ABS', product_link: false }, 'edge');
  ok(miss.includes('is-missing') && miss.includes('data-src="missing"') && miss.includes('data-kind="edge"'), 'chyba = jantar');
  ok(miss.includes('title="Chýba odkaz — doplniť odkaz na produkt"'));
  ok(miss.includes('aria-label="Doplniť odkaz na produkt · ABS"'));
  ok(miss.includes('#i-external-link'), 'sprite ikona');
  eq(B.budMatLinkHtml({ material_id: 'UNI', nazov: 'UNI', uni: true }, 'sheet'), '', 'UNI ikonu nema');
  eq(B.budMatLinkHtml({ material_id: 'ZZ', nazov: 'ZZ' }, 'sheet'), '', 'chybajuci zaznam ikonu nema');
})();

// --- R16 / R17: stav a texty -------------------------------------------------------
const PC_FRESH = { kind: 'sheet', id: 'S25', label: 'H1180 DTDL 25 mm', manual_check: true, state: 'fresh',
                   checked_at: '2026-09-18T08:00:00Z', age_days: 12, product_link: true, price_missing: false };
(function(){
  eq(B.budMatStateText(PC_FRESH), 'ručne 18.9.', 'fresh = den a mesiac bez nul');
  eq(B.budMatStateText({ state: 'stale', age_days: 45 }), 'ručne 45 dní');
  eq(B.budMatStateText({ state: 'stale', age_days: 1 }), 'ručne 1 deň');
  eq(B.budMatStateText({ state: 'stale', age_days: 3 }), 'ručne 3 dni');
  eq(B.budMatStateText({ state: 'manual' }), 'neoverená');
  eq(B.budMatTip(PC_FRESH), 'Cena ručne overená 18.9.2026 (pred 12 dňami)\nOveriť cenu — otvorí obchod a formulár');
  eq(B.budMatTip(Object.assign({}, PC_FRESH, { age_days: 0 })).split('\n')[0], 'Cena ručne overená 18.9.2026 (dnes)');
  eq(B.budMatTip(Object.assign({}, PC_FRESH, { age_days: 1 })).split('\n')[0], 'Cena ručne overená 18.9.2026 (pred 1 dňom)');
  eq(B.budMatTip({ state: 'stale', checked_at: '2026-08-16T08:00:00Z', age_days: 45, product_link: false }),
     'Ručne overená 16.8.2026 — pred 45 dňami, na kontrolu\nOveriť cenu — bez odkazu otvorí len formulár');
  eq(B.budMatTip({ state: 'manual', price_missing: false }).split('\n')[0], 'Cena nebola nikdy ručne overená — na kontrolu');
  eq(B.budMatTip({ state: 'manual', price_missing: true }).split('\n')[0], 'Cena chýba a nebola nikdy overená — na kontrolu');
  const fresh = B.budMatCheckHtml({ nazov: 'H1180 DTDL 25 mm', price_check: PC_FRESH });
  ok(fresh.includes('class="bver"') && !fresh.includes('is-pending'), 'fresh = sive');
  ok(fresh.includes('data-action="mat-manual-check"') && fresh.includes('data-kind="sheet"') && fresh.includes('data-id="S25"'));
  ok(fresh.includes('> ručne 18.9.</button>'), 'text stavu v tlacidle');
  ok(fresh.includes('aria-label="Overiť cenu · H1180 DTDL 25 mm · ručne 18.9."'));
  ok(fresh.includes('#i-clipboard-check'));
  const stale = B.budMatCheckHtml({ nazov: 'X', price_check: { kind: 'edge', id: 'E', state: 'stale', age_days: 45 } });
  ok(stale.includes('bver is-pending') && stale.includes('ručne 45 dní'), 'stara = jantar');
  const never = B.budMatCheckHtml({ nazov: 'X', price_check: { kind: 'sheet', id: 'N', state: 'manual' } });
  ok(never.includes('bver is-pending') && never.includes('neoverená'), 'nikdy = jantar');
  eq(B.budMatCheckHtml({ nazov: 'X' }), '', 'bez price_check nic');
})();

// --- R19: riadok materialu a ABS ------------------------------------------------------
(function(){
  B.BUD_VAT = true;
  const budget = { stale: { items: [] } };
  const area = { key: 'material:SK4', material_id: 'SK4', nazov: 'Číre SKLO 4 mm', mj: 'M2', mnozstvo: 0.9, cena_mj: 41.5,
                 spolu: 37.35, price_per_m2: 41.5, qty_basis: 'area', estimate_qty: 1, product_link: false,
                 poznamka: 'formát platne nie je v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)',
                 price_check: { kind: 'sheet', id: 'SK4', state: 'manual', product_link: false, price_missing: false } };
  const h = B.budMaterialRow(area, budget, 1.23);
  ok(h.includes('<td class="bnum">0,90</td>'), 'mnozstvo m² na 2 desatinne');
  ok(h.includes('<td class="bnum">m²</td>') && !h.includes('>M2<'), 'MJ zobrazena m², data ostavaju M2');
  ok(!h.includes('/m²)'), '„€ / MJ" bez zatvorky (…/m²)');
  ok(h.includes('41,50 €') && h.includes('37,35 €'), 'cena za m² a medzisucet');
  ok(h.includes('data-src="missing"') && h.includes('neoverená'), 'ikona odkazu a stav v riadku');
  ok(h.indexOf('data-action="mat-link"') < h.indexOf('Číre SKLO'), 'ikona je PRED nazvom');
  const plate = Object.assign({}, area, { mj: 'PLATŇA', mnozstvo: 1, cena_mj: 180.84, spolu: 180.84, qty_basis: undefined,
                                          price_per_m2: 31.2, demos_link: true, product_link: undefined, price_check: undefined });
  const hp = B.budMaterialRow(plate, budget, 1.23);
  ok(hp.includes('<td class="bnum">1</td>') && hp.includes('>PLATŇA<') && hp.includes('(31,20 €/m²)'), 'platna ako doteraz');
  ok(hp.includes('data-src="demos"') && hp.includes('<span class="bfnt">—</span>'), 'Demos: ikona a dnesna bunka');
  const abs = B.budSimpleRow({ abs_id: 'E43', nazov: 'ABS H1180', mj: 'BM', mnozstvo: 8.8, cena_mj: 0.39, spolu: 3.43,
                               product_link: true, price_check: { kind: 'edge', id: 'E43', state: 'stale', age_days: 45 } }, budget, 1.23);
  ok(abs.includes('data-src="product"') && abs.includes('ručne 45 dní') && abs.includes('data-kind="edge"'), 'ABS riadok');
})();

// --- R20 / R21 / R22: cip, tlacidlo, zoznam, ponuka ------------------------------------
(function(){
  const itMat = { kind: 'sheet', id: 'SK4', label: 'Číre SKLO', manual_check: true, state: 'manual', product_link: false,
                  price_missing: false, demos_url: null };
  const onlyManual = { stale: { stale_days: 30, items: [itMat],
    counts: { stale: 0, manual: 1, manual_hardware: 0, manual_materials: 1, manual_pending: 1, attention: 1 } } };
  eq(B.budStaleLabel(onlyManual.stale), '1 cena na kontrolu', 'cip pocita rucne materialy');
  const btn = B.budPriceBtnHtml(onlyManual, false);
  ok(btn.includes('Skontrolovať ceny') && btn.includes('bstalebtn') && btn.includes('#i-clipboard-check'), 'len rucne = Skontrolovať ceny');
  const demosOld = { stale: { stale_days: 30, items: [{ kind: 'sheet', id: 'H18', label: 'H', state: 'stale', age_days: 40,
    demos_url: 'https://www.demos-trade.sk/p' }], counts: { stale: 1, manual_pending: 0, attention: 1 } } };
  eq(B.budStaleLabel(demosOld.stale), '1 cena staršia ako 30 dní', 'Demos payload bez zmeny');
  ok(B.budPriceBtnHtml(demosOld, false).includes('Prepočítať ceny'));
  // budPrStart pri samych rucnych: otvori zoznam, ziadny Demos beh
  let status = '';
  B.ST = { budget: onlyManual };
  B.NX = { setStatus: function(s){ status = s; } };
  B.BUD_STALE_OPEN = false;
  B.budPrStart();
  eq(B.BUD_STALE_OPEN, true, 'Skontrolovať ceny otvori zoznam');
  eq(B.BUD_PR, null, 'ziadny Demos beh');
  eq(status, 'Vyber položku a klikni na Overiť cenu. Ručné odkazy sa automaticky nesťahujú.');
  // Zoznam (R21)
  const li = B.budStaleActionHtml(itMat);
  ok(li.includes('data-action="mat-link"') && li.includes('data-src="missing"'), 'zoznam: ikona odkazu');
  ok(li.includes('data-action="mat-manual-check"') && li.includes('Overiť cenu') && li.includes('is-pending'), 'zoznam: Overiť cenu');
  ok(!li.includes('over v katalógu ručne') && !li.includes('refresh_one'), 'stara veta zanikla, rucny sa nestahuje');
  const ld = B.budStaleActionHtml(demosOld.stale.items[0]);
  ok(ld.includes('data-src="demos"') && ld.includes('data-bud="refresh_one"') && !ld.includes('mat-manual-check'), 'Demos: ikona + obnovenie');
  B.BUD_STALE_OPEN = true;
  const list = B.budStaleListHtml(onlyManual);
  ok(list.includes('vyžaduje ručné overenie') && list.includes('mat-manual-check'), 'zoznam nesie vek aj akciu');
  // Ponuka (R22)
  const chip = B.budOfferChipHtml({ id: 'stale', text: '1 cena na kontrolu' }, onlyManual, 1.23);
  ok(chip.includes('title="Ceny na kontrolu skontroluješ v Rozpočte — Demos ceny tlačidlom „Prepočítať ceny&quot;, ručné cez „Overiť cenu&quot;."'),
     'tooltip cipu ponuky pri rucnych cenach');
  const chipD = B.budOfferChipHtml({ id: 'stale', text: 'x' }, demosOld, 1.23);
  ok(chipD.includes('title="Staré ceny sa obnovujú v Rozpočte tlačidlom „Prepočítať ceny&quot; — ponuka'), 'Demos tooltip ostava');
  // R6
  // Review #428 P2: veta sľubuje plochu LEN materiálu mimo bežných dosiek (R1, `area_priced_type?`).
  ok(B.BUD_PLAN_TIP.includes('\nSklo, zrkadlo a iný materiál bez formátu platne, ktorý nie je bežná doska, sa počíta podľa ' +
     'skutočnej plochy dielcov — plán ho nemení. Bežná doska bez formátu ostáva na odhade platní.'), 'BUD_PLAN_TIP');
  ok(B.BUD_PLAN_TIP.indexOf('\nMateriál bez formátu platne sa počíta') < 0, 'žiadny sľub plochy pre každý materiál bez formátu');
})();

// --- proj_materials.js: klik z Rozpoctu (R15, R18) -----------------------------------
['nxModalRoot', 'status'].forEach(function(id){ const e = mkEl('div'); e.id = id; DOC.body.appendChild(e); });
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
const GOTO = [];
global.studioGoSection = function(id){ GOTO.push(id); global.studioSec = id; };
global.studioSec = 'budget';
const M = require(path.join(JS, 'proj_materials.js'));
M.setModelGuidForTest('doc-A');
function count(a){ return SENT.filter(function(x){ return x[0] === a; }).length; }
function last(a){ const h = SENT.filter(function(x){ return x[0] === a; }); return h.length ? h[h.length - 1][1] : null; }
function statusText(){ return DOC.getElementById('status').textContent; }

const GLASS = { material_id: 'SK4', decor: 'SKLO', type: 'SKLO', thickness: 4, price_per_m2: 41.5, group_id: 'GS',
                row_rev: 'rsk', product_link: false, price_check: { state: 'never', checked_at: null, age_days: null },
                price_display: { plate: null, m2: 41.5, area: null } };
const S25 = { material_id: 'S25', decor: 'H1180', type: 'DTDL', thickness: 25, grain: 'length', price_per_m2: 31,
              sheet_size: [2800, 2070], group_id: 'G', structure: 'ST37', row_rev: 'r25', product_url: 'https://shop.example/p',
              product_link: true, price_check: { state: 'fresh', checked_at: '2026-09-18T08:00:00Z', age_days: 12 },
              price_display: { plate: 179.9, m2: 31, area: 5.796 } };
const E43 = { abs_id: 'E43', decor: 'H1180', thickness: 0.8, width: 43, price_per_bm: 0.39, group_id: 'G', structure: 'ST37',
              row_rev: 're', product_link: false, price_check: { state: 'never' }, price_display: { bm: 0.39 } };
function catalog(extra){
  return Object.assign({ materials: { sheets: [] }, catalog: { sheets: [S25, GLASS], edges: [E43] }, protected_ids: [],
    catalog_rev: 'CR' + Math.random(), catalog_schema: 12, catalog_state: 'ok', stale_days: 30 }, extra || {});
}
function reset(){
  M.mdManualClose(); NXModal.setBusy(false); NXModal.close(); global.studioSec = 'budget';
  M.setModelGuidForTest('doc-A'); M.mdSetCatalog(catalog()); tick(100); SENT.length = 0; GOTO.length = 0;
}
function btn(html){
  const host = mkEl('div');
  host.innerHTML = html;
  DOC.body.appendChild(host);
  return host.querySelector('button');
}
function click(html){ dispatch(btn(html), 'click'); }

// R15: ikona odkazu
(function(){
  reset();
  click(B.budMatLinkHtml({ material_id: 'H18', nazov: 'H', demos_link: true }, 'sheet'));
  eq(last('open_demos_url'), { kind: 'sheet', id: 'H18' }, 'Demos ikona -> open_demos_url');
  eq(count('mat_product_open'), 0, 'M13: Demos neide cez mat_product_open');
  click(B.budMatLinkHtml({ material_id: 'S25', nazov: 'S', product_link: true }, 'sheet'));
  eq(last('mat_product_open'), { kind: 'sheet', id: 'S25' }, 'obchod: len kind+id, URL od klienta nie');
  eq(GOTO, [], 'otvorenie odkazu sekciu neprepina');
  // chyba -> Materialy + formular s kurzorom v poli odkazu
  SENT.length = 0;
  click(B.budMatLinkHtml({ material_id: 'SK4', nazov: 'Sklo', product_link: false }, 'sheet'));
  eq(GOTO, ['mat'], 'M14: prepne do Materialov');
  eq(DOC.getElementById('mdSheetForm').style.display, '', 'formular dosky otvoreny');
  eq(DOC.activeElement && DOC.activeElement.id, 'ms_product_url', 'kurzor v poli odkazu');
  eq(SENT.length, 0, 'chybajuci odkaz nic neposiela ani nezapisuje');
  reset();
  click(B.budMatLinkHtml({ abs_id: 'E43', nazov: 'ABS', product_link: false }, 'edge'));
  eq(DOC.getElementById('mdEdgeForm').style.display, '', 'ABS -> formular pasky');
  eq(DOC.activeElement && DOC.activeElement.id, 'me_product_url');
  // chybajuci zaznam a read-only
  reset();
  eq(M.mdProductFromBudget('sheet', 'NEMA'), false);
  eq(statusText(), 'Položka sa v katalógu nenašla — obnov okno.');
  eq(GOTO, [], 'bez zaznamu sa neprepina');
  M.mdSetCatalog(catalog({ catalog_state: 'read_only' }));
  eq(M.mdProductFromBudget('sheet', 'SK4'), false);
  eq(statusText(), 'Katalóg je len na čítanie — úpravy sú vypnuté.');
  eq(GOTO, [], 'read-only sa neprepina');
})();

// Predrecenzia P3: ochranne vetvy `mdBudgetAction` — cudzi druh, prazdne id
// a neznamy zdroj sa NEODOSLU a nic neprepnu (ani formular, ani sekciu).
(function(){
  reset();
  [
    '<button type="button" data-action="mat-link" data-src="product" data-kind="hardware" data-id="K1">x</button>',
    '<button type="button" data-action="mat-link" data-src="product" data-kind="" data-id="S25">x</button>',
    '<button type="button" data-action="mat-link" data-src="product" data-kind="sheet" data-id="">x</button>',
    '<button type="button" data-action="mat-link" data-src="product" data-kind="sheet">x</button>',
    '<button type="button" data-action="mat-link" data-src="iny" data-kind="sheet" data-id="S25">x</button>',
    '<button type="button" data-action="mat-link" data-kind="sheet" data-id="S25">x</button>',
    '<button type="button" data-action="mat-manual-check" data-kind="edgeX" data-id="E43">x</button>',
    '<button type="button" data-action="mat-manual-check" data-kind="sheet" data-id="">x</button>',
    '<button type="button" data-action="mat-iny" data-kind="sheet" data-id="S25">x</button>'
  ].forEach(function(html){
    click(html);
    eq(SENT, [], 'nic sa neodoslalo: ' + html);
    eq(GOTO, [], 'sekcia sa neprepla: ' + html);
    ok(!NXModal.isOpen(), 'formular sa neotvoril: ' + html);
  });
})();

// R18: „Overiť cenu" z Rozpoctu
function snap(req, item, more){
  return Object.assign({}, req, { item: item, row_rev: item.row_rev, has_url: item.product_link === true,
    read_only: false, reason: null, stale_days: 30 }, more || {});
}
(function(){
  reset();
  click(B.budMatCheckHtml({ nazov: 'Sklo', price_check: { kind: 'sheet', id: 'SK4', state: 'manual' } }));
  const req = last('mat_manual_prepare');
  eq(req, { kind: 'sheet', id: 'SK4', token: req.token, section: 'budget', model_guid: 'doc-A' }, 'poziadavka so section budget');
  M.MD.manualReady(Object.assign(snap(req, GLASS), { token: 'cudzi' }));
  ok(!NXModal.isOpen(), 'cudzi token sa ignoruje');
  M.MD.manualReady(snap(req, GLASS));
  ok(NXModal.isOpen(), 'formular sa otvoril v Rozpocte');
  eq(GOTO, [], 'M15: sekcia sa neprepla');
  eq(global.studioSec, 'budget');
  tick(50);
  eq(count('mat_manual_open'), 0, 'M12: bez odkazu sa obchod neotvara, formular ano (O9)');
  // odchod z Rozpoctu formular zavrie
  M.mdManualContextChanged('bom', 'doc-A');
  ok(!NXModal.isOpen(), 'odchod z Rozpoctu zavrie formular');
  // s odkazom: otvori obchod
  reset();
  M.mdManualRequest('sheet', 'S25', null);
  const req2 = last('mat_manual_prepare');
  eq(req2.section, 'budget');
  M.MD.manualReady(snap(req2, S25));
  ok(NXModal.isOpen());
  tick(25);
  eq(last('mat_manual_open') && last('mat_manual_open').section, 'budget', 's odkazom sa otvori obchod (echo sekcie)');
  // zmena dokumentu zavrie
  M.mdManualContextChanged('budget', 'doc-B');
  ok(!NXModal.isOpen(), 'iny dokument zavrie formular');
  // ina sekcia (napr. Kusovnik) poziadavku neposle
  reset();
  global.studioSec = 'bom';
  M.mdManualRequest('sheet', 'SK4', null);
  eq(count('mat_manual_prepare'), 0, 'mimo mat/budget sa formular nepyta');
})();

// R17: parity textov budget.js vs proj_materials.js
(function(){
  const states = [
    { state: 'fresh', checked_at: '2026-09-30T08:00:00Z', age_days: 0 },
    { state: 'fresh', checked_at: '2026-09-29T08:00:00Z', age_days: 1 },
    { state: 'fresh', checked_at: '2026-09-18T08:00:00Z', age_days: 12 },
    { state: 'stale', checked_at: '2026-08-16T08:00:00Z', age_days: 45 },
    { state: 'never', checked_at: null, age_days: null }
  ];
  let pairs = 0;
  states.forEach(function(st){
    [true, false].forEach(function(link){
      [true, false].forEach(function(hasPrice){
        if (st.state !== 'never' && !hasPrice) return; // overena cena ma vzdy cenu
        const rec = { material_id: 'X', price_check: st, product_link: link };
        if (hasPrice) rec.price_per_m2 = 10;
        const pc = { kind: 'sheet', id: 'X', state: st.state === 'never' ? 'manual' : st.state, checked_at: st.checked_at,
                     age_days: st.age_days, product_link: link, price_missing: !hasPrice };
        eq(B.budMatTip(pc), M.mdManualTip(rec), 'parity O5: ' + JSON.stringify(pc));
        pairs++;
      });
    });
  });
  eq(pairs, 12, 'matica parity');
})();

console.log('test_ceny_m2_budget: ' + n + ' OK');
