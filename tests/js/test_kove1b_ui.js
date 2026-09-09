// KOV-E1b — KLIENTSKA ČASŤ: bezstratový transport `lift` (form.js) a pravidlo
// `lift_class` v sekcii Pravidlá LEN NA ČÍTANIE (rules.js).
//
// E1b neprináša žiadny nový ovládač (to je E2) — prináša DVE veci, ktoré sa
// rozbijú TICHO:
//   L1 riadok čela nesie `lift: { system }`. Panel posiela `params.fronts`
//      VCELKU, takže kľúč, ktorý serializér nepozná, pri prvom uložení ZANIKNE
//      a prestavba spadne z HL top na HK — teda iný mechanizmus, iné ramená
//      a iná tyč v objednávke (Astra FIX 10, Codex #331 kolo 2 P1).
//   L2 pravidlo s kindom `lift_class` sa v Pravidlách musí VYKRESLIŤ. Sekcia
//      kreslí formulár podľa kindu; neznámy kind má vetvu „novšia verzia",
//      ale kind, ktorý TÁTO verzia pozná, by tak klamal — a hlavne sa nesmie
//      stratiť pri UKLADANÍ (zber robí kópiu pravidla, nie nový objekt).
//
// MUTÁCIE (každá overená ručne — po zanesení chyby do zdroja test spadne):
//   M1 `lift` vypadne z `FRONT_EXTRA_KEYS`        -> L1 round-trip
//   M2 karta pri zmene typu `lift` zahodí         -> L1 dormant
//   M3 `lift_class` padne do vetvy „novšia verzia" -> L2 súhrn
//   M4 zber pravidlo `lift_class` oreže           -> L2 uloženie
//   M5 rola `flap` sa popíše holým názvom roly    -> L2 podnadpis
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const md = require(path.join(__dirname, 'minidom.js'));
const { mkEl, DOC } = md;
const C = require(path.join(JS, 'core.js'));

// ============ L1: form.js — `lift` prežije riadok, kartu aj zber ============
//
// Harness je ten istý ako v `test_kova2a_karta.js` (stubujú sa LEN cudzie
// závislosti riadku; cesta čiel beží v origináli).
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = v => String(v);
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: (node, id) => { const u = node.querySelector('use'); if (u) u.setAttribute('href', '#i-' + id); }
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = require(path.join(JS, 'insert_state.js'));
require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
Object.keys(C).forEach(k => { global[k] = C[k]; });
global.FRONT_PROFILES = [];
global.frontItems = null;
global.frontSlots = null;
global.frontDrawer = null;
global.selectedCabId = null;
global.applyTimer = null;
global.newStableId = p => p + (++global.__nxid || (global.__nxid = 1));
global.attachExprField = () => {};
global.nxDimFillRow = () => {};
global.evalDim = v => parseFloat(v);
global.numv = () => NaN;
global.val = () => '';
global.setNum = () => {};
global.setOut = () => {};
global.isExprInput = () => false;
global.isExprStr = () => false;
global.refreshMaterialFilters = () => {};
global.renderPreview = () => {};
global.clearFrontHover = () => {};
global.currentCarcass = () => ({});
global.nxInteriorZ = () => ({ availH: 0 });
global.pvGeom = () => ({ W: 0, H: 0 });
global.computeZones = () => [];
global.pvInsertFronts = () => [];
global.nxDraftStats = () => ({});
global.setCabInfo = () => {};
global.frontHwBadge = () => '';
global.frontHwBuy = () => '';
global.hwAxHtml = require(path.join(JS, 'hardware.js')).hwAxHtml;
const FM = require(path.join(JS, 'form.js'));

const rows = mkEl('div');
rows.attrs.id = 'frontRows';
DOC.body.appendChild(rows);
function resetRows(){ rows.children = []; global.frontSlots = null; global.frontDrawer = null; }
function rowOf(fid){ return rows.querySelectorAll('.frow').find(r => r.dataset.frontId === fid); }
function items(){ return FM.collectFronts().items; }
// Dlaždice typu žijú v OTVORENEJ karte — vzor `test_kova2a_karta.js`.
function openCard(fid){
  FM.refreshFrontCards();
  const b = rowOf(fid).querySelector('.ftname');
  if (b.getAttribute('aria-expanded') !== 'true') FM.onFrontCardToggle(b);
}

// --- L1a: systém výklopu prejde riadkom aj zberom ---------------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'lift', lift: { system: 'hl_top' } });
eq(items()[0].lift, { system: 'hl_top' },
   'L1: `lift.system` prežije riadok -> collectFronts (inak Inspector prepíše HL na HK)');
eq(items()[0].type, 'lift', 'a typ ostáva výklop');

// --- L1b: DORMANT — prepnutie typu hodnotu nezahodí ------------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'lift', lift: { system: 'hl_top' },
                 opening_mode: 'tipon' });
openCard('F1');
const tile = rowOf('F1').querySelectorAll('.typetile').find(b => b.dataset.t === 'door');
FM.onFrontTile(tile);
eq(items()[0].type, 'door', 'L1: typ sa prepol na dvierka');
eq(items()[0].lift, { system: 'hl_top' },
   'L1: systém výklopu ostáva DORMANT (návrat na výklop ho obnoví)');
eq(items()[0].opening_mode, 'tipon', 'a ostatné dormant polia sa nezmenili');

// --- L1c: riadok BEZ systému si ho nevymyslí --------------------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'lift' });
eq(items()[0].lift, undefined,
   'L1: klient hodnotu NEDOPĹŇA — predvoľbu určuje server (grandfather `hk_top`)');

// ============ L2: rules.js — `lift_class` je čitateľné, nie editovateľné ====
['rulesBox', 'rdSrcLine', 'status', 'secbody', 'sectools'].forEach(function(id){
  const e = mkEl('div');
  e.attrs.id = id;
  DOC.body.appendChild(e);
});
const SENT = [];
const BRIDGE = { save_rules: function(json){ SENT.push(JSON.parse(json)); } };
global.window.sketchup = BRIDGE;
global.sketchup = BRIDGE;
require(path.join(JS, 'studio.js'));
if (global.window.NX && typeof global.NX === 'undefined') global.NX = global.window.NX;
const R = require(path.join(JS, 'rules.js'));

function liftRule(over){
  return Object.assign({
    rule_id: 'vyklopy-aventos', kind: 'lift_class', output: 'lift', enabled: true,
    applies_to: { role: 'flap', flap_dir: 'up' },
    handle_allowance_kg: 0.5, rod_double_from_kb_mm: 1100,
    classes: [{ code: '22K2300', min: 420, max: 1610 }, { code: '22K2500', min: 930, max: 2800 }],
    mechanisms: [{ code: '22L2200', max: 390, max_exclusive: true }],
    arms: [{ code: '22L3200', kh_min: 300, kh_max: 340, kg_min: 1.5, kg_max: 9 }],
    eligibility: { hk_top: { kh_min: 205, kh_max: 600, kb_max: 1800 } }
  }, over || {});
}
function fallRule(){
  return { rule_id: 'zavesy-sklop', kind: 'bands', output: 'hinge', enabled: true,
           input: 'height', applies_to: { role: 'flap', flap_dir: 'down' },
           bands: [{ max: 849, quantity: 2 }, { max: null, quantity: 7 }], finite: true };
}
function show(rules){
  R.RD.init({ version: '0.9.54', source: 'project', cabinets: 1, model_guid: 'G1',
              rules_rev: 'rev1', rules: rules,
              abs: { rows: [], source: '', hint: '' },
              overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } });
}

// --- L2a: pravidlo sa vykreslí a POVIE, čo robí -----------------------------
show([liftRule()]);
const box = DOC.getElementById('rulesBox');
eq(box.querySelectorAll('.rrule').length, 1, 'L2: pravidlo výklopov sa vykreslilo');
const hint = md.textOf(box.querySelector('.hint'));
ok(hint.indexOf('novšej verzie') < 0,
   'L2: kind, ktorý TÁTO verzia pozná, sa netvári ako z budúcnosti: ' + hint);
ok(hint.indexOf('2 tried') >= 0 && hint.indexOf('1 párov ramien') >= 0,
   'L2: súhrn menuje tabuľky: ' + hint);
ok(hint.indexOf('0.5 kg') >= 0 && hint.indexOf('1100 mm') >= 0,
   'L2: aj rezervu na úchytku a prah druhej tyče: ' + hint);
eq(box.querySelectorAll('.rbands').length, 0, 'L2: ale žiadny formulár pásiem (editor je E2)');
eq(md.textOf(box.querySelector('.rid')), 'na každý výklop',
   'L2: podnadpis rozlíši výklop od sklopu (rovnaká rola, iný smer)');

// --- L2b: sklop má vlastný podnadpis ----------------------------------------
show([fallRule()]);
eq(md.textOf(DOC.getElementById('rulesBox').querySelector('.rid')), 'na každý sklop',
   'L2: `zavesy-sklop` sa nepomýli s dvierkami');

// --- L2c: pravidlo bez smeru (staršie/vlastné) sa tiež popíše ---------------
show([liftRule({ applies_to: { role: 'flap' } })]);
eq(md.textOf(DOC.getElementById('rulesBox').querySelector('.rid')), 'na každý výklop aj sklop',
   'L2: bez filtra smeru platí na oboje');

// --- L2d: poškodené/prázdne tabuľky sekciu NEZHODIA -------------------------
show([liftRule({ classes: 'nezmysel', arms: null, handle_allowance_kg: 'x',
                 rod_double_from_kb_mm: null })]);
const bad = md.textOf(DOC.getElementById('rulesBox').querySelector('.hint'));
ok(bad.indexOf('0 tried') >= 0 && bad.indexOf('0 párov ramien') >= 0,
   'L2: poškodený tvar sa prizná ako prázdny, nespadne: ' + bad);
ok(bad.indexOf('rezerva') < 0, 'L2: a nečíselná hodnota sa vôbec nevypíše');
eq(R.rdLiftSummary(null).indexOf('0 tried') >= 0, true, 'L2: ani chýbajúce pravidlo nespadne');

// --- L2e: ULOŽENIE pravidlo NEOREŽE -----------------------------------------
show([liftRule(), fallRule()]);
const collected = R.rdCollectRules();
eq(collected.length, 2, 'L2: zber vracia obe pravidlá');
eq(collected[0].classes.length, 2, 'L2: tabuľka tried prežije zber');
eq(collected[0].eligibility, { hk_top: { kh_min: 205, kh_max: 600, kb_max: 1800 } },
   'L2: aj rozmerová spôsobilosť (klient ju needituje, ale ani nezahadzuje)');
eq(collected[0].applies_to, { role: 'flap', flap_dir: 'up' }, 'L2: a filter smeru');
eq(R.rdValidate(collected), null, 'L2: klientska kontrola výklopové pravidlo neodmieta');

// --- L2f: vypnutie je JEDINÁ vec, ktorú tu ide zmeniť -----------------------
show([liftRule()]);
DOC.querySelector('.rrule .ren').checked = false;
eq(R.rdCollectRules()[0].enabled, false, 'L2: pravidlo sa dá vypnúť aj bez editora');

console.log('KOV-E1b klientska cast: ' + n + ' assertov OK');
