// KON-B · K2 — chrbat z dvoch list, panelova polovica.
//   node tests/js/test_konb_listy.js
//
// Co sa tu strazi:
//   1) PARITA Ruby <-> JS: spolocna fixtura `tests/fixtures/konb_cases.json`
//      (zadny doraz R, vnutro R − t, svetla vyska, H, veta odmietnutia list),
//   2) INTEGRACIA formular -> most `currentCarcass` / `pvGeom` -> vypocet nad
//      SKUTOCNE nacitanym core.js + form.js + preview.js: listy BEZ komina,
//      polica a priecka v odhade, cervene pole „Výška líšt" (audit NOTE 4),
//   3) SKRYTE neplatne H neblokuje „Aplikuj" pri inom chrbte ani pri slote
//      a cervena aj tooltip zmiznu (audit FIX 3),
//   4) riadky Výška líšt / Hrúbka chrbta pri kazdom type chrbta, suhrn
//      v hlavicke, tooltip komina, veta pod materialom chrbta,
//   5) RIEDKY CONFIG: skrinka bez kluca nastavi H na 100; vyrazy v poli H.
// Zrkadlo Ruby: tests/pure/test_konb_listy.rb.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const DIR = path.join(ROOT, 'noxun_engine', 'ui', 'js');
const core = require(path.join(DIR, 'core.js'));
const FX = JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'konb_cases.json'), 'utf8'));

let n = 0;
function eq(actual, expected, msg){ n++; assert.deepStrictEqual(actual, expected, msg); }
function close(actual, expected, msg){
  n++;
  assert.ok(Math.abs(actual - expected) < 0.001, `${msg}: cakam ${expected}, dostal ${actual}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) parita so spolocnou fixturou ------------------------------------------
ok(FX.cases.length >= 70, 'fixtura ma maticu aj hranice');
FX.cases.forEach(function(c){
  const cfg = c.cfg, tag = c.case;
  close(core.nxBackStop(cfg), c.back_stop, `${tag}: R`);
  close(core.nxInteriorDepth(cfg), c.interior_depth, `${tag}: vnutro`);
  close(core.nxInteriorZ(cfg).availH, c.avail_h, `${tag}: svetla vyska`);
  close(core.nxBackRailHeight(cfg), c.rail_height, `${tag}: H`);
  eq(core.nxSetbackError(cfg) || null, c.error, `${tag}: veta odmietnutia`);
});
// Prisne citanie (zrkadlo `CabinetBuilder.norm_rail_height` / `Construction.back_rail_height`).
[[150, 150], ['150', 150], ['150oops', 100], ['100-20', 100], [NaN, 100], [Infinity, 100], [-5, 20],
 [0, 20], [400, 300], [null, 100], [undefined, 100], [{}, 100], [12.5, 20]]
  .forEach(function(p){ eq(core.nxBackRailHeight({ back_rail_height: p[0] }), p[1], `H ${String(p[0])}`); });
eq(core.nxBackRails({ type: 'dishwasher', back_mode: 'rails' }), false, 'slot listy nema');
eq(core.nxBackRailsError({ back_mode: 'overlay', back_rail_height: 290, height: 720, thickness: 18, floor_height: 100 }),
   '', 'ine rezimy pravidlo list nemaju');
const fieldsIds = core.CONSTRUCTION_FIELDS.map(f => f.id);
ok(fieldsIds.indexOf('back_rail_height') >= 0, 'CONSTRUCTION_FIELDS pozna H');
eq(core.CONSTRUCTION_FIELDS.find(f => f.id === 'back_rail_height').dflt, 100, 'riedky config -> 100');

// --- mini DOM pre skutocne core.js + form.js + preview.js --------------------------
const nodes = {};
function mkNode(id, value){
  const nd = { id: id, value: value === undefined ? '' : String(value), style: {}, title: '', hidden: false,
               attrs: {}, cls: {}, listeners: {}, textContent: '' };
  nd.classList = { add: c => { nd.cls[c] = 1; }, remove: c => { delete nd.cls[c]; }, contains: c => !!nd.cls[c],
                   toggle: (c, on) => { if (on) nd.cls[c] = 1; else delete nd.cls[c]; } };
  nd.getAttribute = k => (Object.prototype.hasOwnProperty.call(nd.attrs, k) ? nd.attrs[k] : null);
  nd.setAttribute = (k, v) => { nd.attrs[k] = String(v); };
  nd.addEventListener = (t, fn) => { (nd.listeners[t] = nd.listeners[t] || []).push(fn); };
  nd.dispatchEvent = ev => { (nd.listeners[ev.type] || []).forEach(fn => fn(ev)); return true; };
  nd.querySelector = () => null;
  nd.querySelectorAll = () => [];
  nd.closest = () => null;
  nd.insertAdjacentElement = (_pos, h) => { nd.nextElementSibling = h; };
  nodes[id] = nd;
  return nd;
}
function reset(){
  Object.keys(nodes).forEach(k => delete nodes[k]);
  const vals = { width: 600, height: 720, depth: 510, thickness: 18, floor_height: 100,
                 back_mode: 'rails', back_thickness: 3, top_mode: 'full', rails_orientation: 'flat',
                 rails_top_offset: 0, rail_depth: 100, back_setback: 0, top_front_setback: 0,
                 back_rail_height: 100,
                 bottom_mode: 'under_sides', plinth_mode: 'none', plinth_recess: 40,
                 fr_gap: 3, fr_gap_top: 2, fr_gap_bottom: 2, fr_gap_left: 2, fr_gap_right: 2 };
  Object.keys(vals).forEach(k => mkNode(k, vals[k]));
  ['av_width', 'av_depth', 'av_height', 'topSetbackRow', 'backSetbackRow', 'backSetbackTip',
   'topMeta', 'backMeta', 'backThRow', 'backRailRow', 'cabBackNote', 'twoRailsGroup', 'recessRow'].forEach(k => mkNode(k));
}
reset();
let hints = 0;
const doc = { getElementById: id => nodes[id] || null, activeElement: null,
              createElement: () => mkNode('_hint' + (++hints)),
              querySelectorAll: () => [], querySelector: () => null, addEventListener: () => {} };
const ctx = { document: doc, window: {}, console, setTimeout: () => 0, clearTimeout: () => {},
              Event: function(type){ this.type = type; }, navigator: { userAgent: 'node' },
              NXInsert: { state: { kind: 'board', lastMode: '' }, insertType: () => 'lower' } };
ctx.window = ctx;
vm.createContext(ctx);
['expr.js', 'core.js', 'form.js', 'preview.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(DIR, f), 'utf8'), ctx, { filename: f });
});
vm.runInContext("DEFAULTS.lower = { width: 600, height: 720, depth: 510, thickness: 18, floor_height: 100, back_rail_height: 100 };" +
                "DEFAULTS.upper = { width: 600, height: 720, depth: 320, thickness: 18, floor_height: 0, back_rail_height: 100 };" +
                "DEFAULTS.dishwasher = { width: 600, height: 880, depth: 560, thickness: 18, floor_height: 0 };", ctx);
function run(code){ return vm.runInContext(code, ctx); }
function set(id, v){ nodes[id].value = String(v); }
function meta0(c){ return run('setbackMetaTexts(' + JSON.stringify(c, (k, v) => (typeof v === 'number' && isNaN(v) ? '__NaN__' : v)).replace(/"__NaN__"/g, 'NaN') + ')'); }
const SMOKE3 = FX.cases.find(c => c.case === 'smoke 3: H290 v dolnej 720').error;

// --- 2) integracia: listy BEZ komina ---------------------------------------------
eq(run('currentCarcass()').back_rail_height, 100, 'most currentCarcass nesie H z formulara');
run('updateAvailable()');
eq(nodes.av_depth.textContent, '492', 'Vnút. hĺbka 492 pri listach bez komina (smoke 1)');
set('back_setback', 50);
run('updateAvailable()');
eq(nodes.av_depth.textContent, '442', 'komin 50 + listy: vnutro 442 (smoke 6)');
set('back_setback', 0);
// Cervene H: 290 pri dolnej 720 (vnutro 584) — bez komina (audit NOTE 4).
set('back_rail_height', 290);
eq(run('validateFields(true)'), false, 'listy 290 sa neaplikuju');
ok(nodes.back_rail_height.cls.bad === 1, 'pole Výška líšt zocervenie');
eq(nodes.back_rail_height.title, SMOKE3, 'tooltip = veta servera (smoke 3)');
eq(run('nxCabFieldError()'), SMOKE3, 'stavova veta formulara je ta ista');
ok(!nodes.back_setback.cls.bad && nodes.back_setback.title === '', 'pole komina veta list neoznaci');
set('back_rail_height', 282);
eq(run('validateFields(true)'), true, '2 x 282 + 20 = 584 prejde');
ok(!nodes.back_rail_height.cls.bad && nodes.back_rail_height.title === '', 'veta aj cervena zmiznu');
// Odhad vo vkladani: polica a priecka po listy (R − t) aj pri X = Y = 0.
set('back_rail_height', 100);
const g = run('pvSetbackDepths({ W: 600, H: 720, t: 18, D: 510, fh: 100, topMode: "full", backMode: "rails" })');
eq([g.innerD, g.backRailH], [492, 100], 'most pvGeom: vnutro 492 a H 100 bez komina');
eq(g.sideD, undefined, 'X = Y = 0: hlbky korpusu ostavaju dnesne');
const prev = require(path.join(DIR, 'preview.js'));
const zones = [{ leaf: true, shelves: 1, w: 564 }, { split: { count: 2, axis: 'v' }, h: 584 }];
const sR = prev.nxDraftStats(JSON.parse(JSON.stringify(g)), zones, []);
const g0 = { W: 600, H: 720, t: 18, D: 510, fh: 100, topMode: 'full', backMode: 'overlay' };
const s0 = prev.nxDraftStats(g0, zones, []);
eq(sR.count, s0.count + 1, 'listy = 2 dielce namiesto 1 dosky chrbta');
close(sR.area,
      Math.round((2 * 620 * 510 + 600 * 510 + 564 * 510 + 2 * 564 * 100 + 564 * 492 + 584 * 492) / 1000) / 1000,
      'odhad: 2 listy z korpusu, polica a priecka po listy (492)');

// --- 3) skryte neplatne H neblokuje (audit FIX 3) -----------------------------------
[['overlay', 'lower'], ['none', 'lower'], ['rails', 'dishwasher']].forEach(function(p){
  reset();
  run("setType('lower')");
  set('back_rail_height', 999);
  eq(run('validateFields(true)'), false, 'Z líšt + H 999 blokuje');
  ok(nodes.back_rail_height.cls.bad === 1, 'H 999 je cervene');
  set('back_mode', p[0]);
  run("setType('" + p[1] + "')");
  run('toggleBackTh()');
  ok(!nodes.back_rail_height.cls.bad && nodes.back_rail_height.title === '', `${p[0]}/${p[1]}: skrytie zrusi cervenu aj tooltip`);
  eq(run('validateFields(true)'), true, `${p[0]}/${p[1]}: „Aplikuj" nie je blokovane skrytym H`);
  ok(!nodes.back_rail_height.cls.bad, `${p[0]}/${p[1]}: ani po validacii nie je H cervene`);
});
run("setType('lower')");
// Predrecenzia P3: skryte neplatne H sa pri „Aplikuj" NEPOSIELA (server necha
// ulozenu hodnotu skrinky); platne skryte H ide, pri listach ide vzdy.
reset();
set('back_rail_height', 999); set('back_mode', 'overlay');
ok(!('back_rail_height' in run('collectConstruction()')), 'skryte H 999 sa neposiela (nie ticho 300)');
set('back_rail_height', '');
ok(!('back_rail_height' in run('collectConstruction()')), 'skryte prazdne H sa neposiela (nie reset na 100)');
set('back_rail_height', 150);
eq(run('collectConstruction()').back_rail_height, 150, 'skryte platne H ide (pamata sa)');
set('back_mode', 'rails'); set('back_rail_height', 999);
eq(run('collectConstruction()').back_rail_height, 999, 'pri listach ide napisane (validacia ho zastavi)');
// Predrecenzia P3: vyska mimo rozsahu — veta rozsahu, nie veta s orezanou 300.
reset();
set('back_rail_height', 400);
eq(run('validateFields(true)'), false, 'H 400 sa neaplikuje');
eq(nodes.back_rail_height.title, 'Výška líšt musí byť 20 až 300 mm.', 'tooltip = rozsah pola, nie „po 300 mm"');
eq(run('nxCabFieldError()'), 'Výška líšt musí byť 20 až 300 mm.', 'stavova veta tiez');
eq(meta0({ back_mode: 'rails', back_rail_height: 400, back_setback: 0, top_mode: 'full' }).back, 'z líšt',
   'suhrn neukazuje orezane cislo');
eq(meta0({ back_mode: 'rails', back_rail_height: NaN, back_setback: 50, top_mode: 'full' }).back, 'z líšt · komín 50',
   'neplatne H: suhrn bez cisla');
eq(meta0({ back_mode: 'rails', back_setback: 0, top_mode: 'full' }).back, 'z líšt 100', 'chybajuci kluc = 100');
// Rozpisany vyraz vo fokusovanom poli H nie je hodnota — nezocervie.
reset();
set('back_rail_height', '300-2');
doc.activeElement = nodes.back_rail_height;
run('validateFields(true)');
ok(!nodes.back_rail_height.cls.bad && nodes.back_rail_height.title === '', 'rozpisany vyraz pole nezocervie');
doc.activeElement = null;

// --- 4) riadky, suhrn, tooltip, veta pod materialom ------------------------------------
reset();
function rows(bm){
  set('back_mode', bm); run('toggleBackTh()');
  return [nodes.backThRow.style.display, nodes.backRailRow.style.display];
}
eq(rows('overlay'), ['', 'none'], 'naloženy: hrubka ano, vyska list nie');
eq(rows('inset'), ['', 'none'], 'vlozeny');
eq(rows('groove'), ['', 'none'], 'v drazke');
eq(rows('rails'), ['none', ''], 'Z líšt: vyska list NA MIESTE hrubky (A5)');
eq(rows('none'), ['none', 'none'], 'Bez chrbta: obe skryte');
eq(nodes.back_rail_height.value, '100', '... hodnota H sa pamata');
run("setType('dishwasher')"); set('back_mode', 'rails'); run('toggleBackTh()');
eq(nodes.backRailRow.style.display, 'none', 'slot riadok list nema');
run("setType('lower')");
const meta = c => JSON.parse(JSON.stringify(run('setbackMetaTexts(' + JSON.stringify(c) + ')')));
eq(meta({ back_mode: 'rails', back_rail_height: 100, back_setback: 50, top_mode: 'full' }).back, 'z líšt 100 · komín 50', 'suhrn A7');
eq(meta({ back_mode: 'rails', back_rail_height: 150, back_setback: 0, top_mode: 'full' }).back, 'z líšt 150', 'len listy');
eq(meta({ back_mode: 'overlay', back_rail_height: 150, back_setback: 0, top_mode: 'full' }).back, '', 'vyska len pri listach');
eq(meta({ type: 'dishwasher', back_mode: 'rails', back_rail_height: 150, top_mode: 'full' }).back, '', 'slot');
reset();
set('back_rail_height', 120); set('back_setback', 30);
run('updateSetbackMeta()');
eq(nodes.backMeta.textContent, 'z líšt 120 · komín 30', 'hlavicka sa kresli z formulara');
const tip = c => run('backSetbackTipText(' + JSON.stringify(c) + ')');
ok(tip({ back_mode: 'rails', back_thickness: 3, back_setback: 50 }).indexOf('Voľný kanál za chrbtom je teraz 50 mm') > 0,
   'listy: volny kanal = X (zadna plocha list v rovine R)');
ok(tip({ back_mode: 'rails', back_thickness: 18, back_setback: 0 }).indexOf('bez minima') > 0, 'listy: komin bez minima (M10)');
eq(run("backMaterialNote('rails')"), '(nepoužije sa — chrbát z líšt je z korpusu)', 'veta pod materialom chrbta');
eq(run("backMaterialNote('overlay')"), '', 'pri doske chrbta ziadna veta');
reset();
rows('rails');
ok(!nodes.cabBackNote.hidden && nodes.cabBackNote.textContent.indexOf('z líšt') > 0, 'veta sa ukaze pri listach');
rows('groove');
ok(nodes.cabBackNote.hidden && nodes.cabBackNote.textContent === '', 'a zmizne pri doske chrbta');

// --- 5) riedky config a vyrazy --------------------------------------------------------
reset();
run("writeConstruction({ width: 600, back_mode: 'rails', back_rail_height: 150 })");
eq(nodes.back_rail_height.value, '150', 'skrinka s H 150');
run("writeConstruction({ width: 600, back_mode: 'overlay' })");
eq(nodes.back_rail_height.value, '100', 'skrinka BEZ kluca nastavi 100 (nie H predchadzajucej)');
run("writeConstruction({ width: 600, back_mode: 'rails', back_rail_height: 150 })");
eq(run('collectConstruction()').back_rail_height, 150, 'payload vkladu nesie H');
const boot = fs.readFileSync(path.join(DIR, 'boot.js'), 'utf8');
const exprList = boot.slice(boot.indexOf('function bindExprFields'), boot.indexOf('// E-03'));
ok(exprList.indexOf("'back_rail_height'") > 0, 'bindExprFields pripaja pole H');
let applied = 0;
ctx.flushCabinetEditsNow = () => { applied++; };
run('attachExprField(el("back_rail_height"), { flushFn: flushCabinetEditsNow })');
const hf = nodes.back_rail_height;
doc.activeElement = hf;
hf.value = '200-8';
ok(run('isExprInput(document.activeElement) && isExprStr(document.activeElement.value)'), 'rozpisany vyraz v poli H');
hf.value = '200-80';
hf.dispatchEvent({ type: 'keydown', key: 'Enter', preventDefault: () => {} });
eq(hf.value, '120', 'Enter vyhodnoti vyraz na 120');
eq(applied, 1, 'a az potom sa zmena odosle');
doc.activeElement = null;

console.log(`test_konb_listy.js: ${n} kontrol OK`);
