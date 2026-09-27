// KON-A · K1 — komin vzadu a zapusteny strop, panelova polovica.
//   node tests/js/test_kona_komin.js
//
// Co sa tu strazi:
//   1) PARITA Ruby <-> JS: spolocna fixtura `tests/fixtures/kona_cases.json`
//      (zadny doraz R, hlbka bokov, vnutro, flat limit vystuh, veta odmietnutia),
//   2) INTEGRACIA formular -> most `currentCarcass` / `pvGeom` -> vypocet nad
//      SKUTOCNE nacitanym core.js + form.js (audit FIX 2 — parita nad rucne
//      skladanymi objektmi by chybu mosta nezachytila),
//   3) RIEDKY CONFIG (Codex FIX 9): skrinka bez kluca nastavi pole na 0,
//   4) vklad zo sablony prenesie X a Y (CONSTRUCTION_FIELDS),
//   5) VYRAZY (audit FIX 3): `50-20` pri pisani nikdy neodide ako medzistav,
//   6) riadky Strop/Chrbát (skrytie pri „Bez stropu" a pri slote), tooltip
//      volneho kanala, suhrn v zbalenej hlavicke, zrkadlo validacie,
//   7) odhad vo vkladani (`nxDraftStats`) pri komine.
// Zrkadlo Ruby: tests/pure/test_kona_komin.rb.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const DIR = path.join(ROOT, 'noxun_engine', 'ui', 'js');
const core = require(path.join(DIR, 'core.js'));
const FX = JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'kona_cases.json'), 'utf8'));

let n = 0;
function eq(actual, expected, msg){ n++; assert.deepStrictEqual(actual, expected, msg); }
function close(actual, expected, msg){
  n++;
  assert.ok(Math.abs(actual - expected) < 0.001, `${msg}: cakam ${expected}, dostal ${actual}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) parita so spolocnou fixturou ------------------------------------------
ok(FX.cases.length >= 100, 'fixtura ma maticu aj hranice');
FX.cases.forEach(function(c){
  const cfg = c.cfg, tag = c.case;
  close(core.nxBackStop(cfg), c.back_stop, `${tag}: R`);
  close(core.nxSideDepth(cfg), c.side_depth, `${tag}: boky`);
  close(core.nxInteriorDepth(cfg), c.interior_depth, `${tag}: vnutro`);
  close(core.nxRailGeom(cfg).flatLimit, c.flat_limit, `${tag}: flat limit`);
  eq(core.nxSetbackError(cfg) || null, c.error, `${tag}: veta odmietnutia`);
});
// Prisne citanie (zrkadlo `CabinetBuilder.norm_setback` / `Construction.setback_value`).
[[50, 50], ['50', 50], ['50oops', 0], ['50-20', 0], [NaN, 0], [Infinity, 0], [-5, 0], [400, 300], [null, 0], [{}, 0]]
  .forEach(function(p){ eq(core.nxBackSetback({ back_setback: p[0] }), p[1], `X ${String(p[0])}`); });
eq(core.nxBackSetback({ type: 'dishwasher', back_setback: 50 }), 0, 'slot komin nema');

// --- mini DOM pre skutocne core.js + form.js ------------------------------------
const nodes = {};
function mkNode(id, value){
  const n = { id: id, value: value === undefined ? '' : String(value), style: {}, title: '', hidden: false,
              attrs: {}, cls: {}, listeners: {}, textContent: '' };
  n.classList = { add: c => { n.cls[c] = 1; }, remove: c => { delete n.cls[c]; }, contains: c => !!n.cls[c],
                  toggle: (c, on) => { if (on) n.cls[c] = 1; else delete n.cls[c]; } };
  n.getAttribute = k => (Object.prototype.hasOwnProperty.call(n.attrs, k) ? n.attrs[k] : null);
  n.setAttribute = (k, v) => { n.attrs[k] = String(v); };
  n.addEventListener = (t, fn) => { (n.listeners[t] = n.listeners[t] || []).push(fn); };
  n.dispatchEvent = ev => { (n.listeners[ev.type] || []).forEach(fn => fn(ev)); return true; };
  n.querySelector = () => null;
  n.querySelectorAll = () => [];
  n.closest = () => null;
  n.insertAdjacentElement = (_pos, h) => { n.nextElementSibling = h; };
  nodes[id] = n;
  return n;
}
function reset(){
  Object.keys(nodes).forEach(k => delete nodes[k]);
  const vals = { width: 600, height: 720, depth: 510, thickness: 18, floor_height: 100,
                 back_mode: 'overlay', back_thickness: 3, top_mode: 'full', rails_orientation: 'flat',
                 rails_top_offset: 0, rail_depth: 100, back_setback: 0, top_front_setback: 0,
                 bottom_mode: 'under_sides', plinth_mode: 'none', plinth_recess: 40,
                 fr_gap: 3, fr_gap_top: 2, fr_gap_bottom: 2, fr_gap_left: 2, fr_gap_right: 2 };
  Object.keys(vals).forEach(k => mkNode(k, vals[k]));
  ['av_width', 'av_depth', 'av_height', 'topSetbackRow', 'backSetbackRow', 'backSetbackTip',
   'topMeta', 'backMeta', 'backThRow', 'twoRailsGroup', 'recessRow'].forEach(k => mkNode(k));
}
reset();
let hints = 0;
const doc = { getElementById: id => nodes[id] || null, activeElement: null,
              createElement: () => mkNode('_hint' + (++hints)),
              querySelectorAll: () => [], querySelector: () => null, addEventListener: () => {} };
const ctx = { document: doc, window: {}, console, setTimeout: () => 0, clearTimeout: () => {},
              Event: function(type){ this.type = type; }, navigator: { userAgent: 'node' },
              // Vkladacia karta mimo tejto sady (odhad kusov sa tu testuje priamo).
              NXInsert: { state: { kind: 'board', lastMode: '' }, insertType: () => 'lower' } };
ctx.window = ctx;
vm.createContext(ctx);
['expr.js', 'core.js', 'form.js', 'preview.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(DIR, f), 'utf8'), ctx, { filename: f });
});
// Predvolby, ktore do panela posiela server (`CabinetBuilder::LOWER_DEFAULTS`).
vm.runInContext("DEFAULTS.lower = { width: 600, height: 720, depth: 510, thickness: 18, floor_height: 100 };" +
                "DEFAULTS.upper = { width: 600, height: 720, depth: 320, thickness: 18, floor_height: 0 };", ctx);
function run(code){ return vm.runInContext(code, ctx); }
function set(id, v){ nodes[id].value = String(v); }

// --- 2) integracia formular -> most -> vypocet ----------------------------------
// Priklad auditu: d 260, X 50, Y 70, dve vystuhy naplocho -> limit 60 (stary
// most by nechal 100).
set('depth', 260); set('back_setback', 50); set('top_front_setback', 70); set('top_mode', 'two_rails');
const cc = run('currentCarcass()');
eq([cc.back_setback, cc.top_front_setback], [50, 70], 'most currentCarcass nesie X aj Y z formulara');
close(run('nxRailGeom(currentCarcass()).flatLimit'), 60, 'limit flat vystuhy cez most = 60');
close(run('nxRailGeom(currentCarcass()).depth'), 60, 'a pas sa oreze na 60 (Ruby rail_depth_clamped)');
// Smoke 1: dolna 600 x 720 x 510, komin 50 -> „Vnút. hĺbka" 460.
reset();
set('back_setback', 50);
run('updateAvailable()');
eq(nodes.av_depth.textContent, '460', 'Vnút. hĺbka 460 pri komine 50 (A8)');
set('back_setback', 0);
run('updateAvailable()');
eq(nodes.av_depth.textContent, '507', 'bez komina dnesnych 507');
set('back_mode', 'groove'); set('back_setback', 13);
run('updateAvailable()');
eq(nodes.av_depth.textContent, '497', 'drazka + komin 13: vnutro R = 497');

// Zrkadlo validacie: komin 2 pri HDF 3 -> cervene pole + veta servera.
reset();
set('back_setback', 2);
eq(run('validateFields(true)'), false, 'komin 2 pri HDF 3 sa neaplikuje');
ok(nodes.back_setback.cls.bad === 1, 'pole komina zocervenie');
eq(nodes.back_setback.title, FX.cases.find(c => c.case === 'overlay X2 (pod minimom 3)').error,
   'tooltip pola = veta, akou by server odmietol');
eq(run('nxCabFieldError()'), nodes.back_setback.title, 'stavova veta formulara je ta ista');
set('back_setback', 3);
eq(run('validateFields(true)'), true, 'komin 3 prejde');
eq(nodes.back_setback.title, '', 'veta zmizne');
set('back_setback', 0); set('top_front_setback', 0); set('depth', 150);
set('thickness', 50); set('back_thickness', 50); set('top_mode', 'two_rails'); set('rails_orientation', 'upright');
eq(run('validateFields(true)'), true, 'X = Y = 0: ziadne nove odmietnutie ani pri hranicnom configu auditu');
reset();
set('back_setback', '5-3');                // rozpisany vyraz (= 2) vo fokusovanom poli
doc.activeElement = nodes.back_setback;
run('validateFields(true)');
ok(!nodes.back_setback.cls.bad && nodes.back_setback.title === '', 'rozpisany vyraz pole nezocervie (nie je to hodnota)');
doc.activeElement = null;
reset();
set('back_setback', 400);
eq(run('validateFields(true)'), false, 'komin nad 300 je mimo LIMITS');

// --- 3) riedky config ------------------------------------------------------------
reset();
run("writeConstruction({ width: 600, back_setback: 50, top_front_setback: 30 })");
eq([nodes.back_setback.value, nodes.top_front_setback.value], ['50', '30'], 'skrinka s kominom')
run("writeConstruction({ width: 600 })");
eq([nodes.back_setback.value, nodes.top_front_setback.value], ['0', '0'],
   'prepnutie na skrinku BEZ kluca nastavi 0 (nie komin predchadzajucej)');

// --- 4) vklad zo sablony -----------------------------------------------------------
reset();
run("writeConstruction({ width: 600, height: 2100, depth: 560, back_mode: 'none', back_setback: 50 })");
const col = run('collectConstruction()');
eq([col.back_setback, col.top_front_setback], [50, 0], 'sablona s kominom -> payload vkladu nesie X aj Y');

// --- 5) vyrazy -----------------------------------------------------------------------
const boot = fs.readFileSync(path.join(DIR, 'boot.js'), 'utf8');
const exprList = boot.slice(boot.indexOf('function bindExprFields'), boot.indexOf('// E-03'));
ok(exprList.indexOf("'back_setback'") > 0 && exprList.indexOf("'top_front_setback'") > 0,
   'bindExprFields pripaja komin aj zapustenie');
reset();
let applied = 0;
ctx.flushCabinetEditsNow = () => { applied++; };
run('attachExprField(el("back_setback"), { flushFn: flushCabinetEditsNow })');
const xf = nodes.back_setback;
doc.activeElement = xf;
xf.value = '50-2';                         // pisanie s prestavkou — medzistav
ok(run('isExprInput(document.activeElement) && isExprStr(document.activeElement.value)'),
   'rozpisany vyraz je v poli komina rozpoznany (onField ho neodosle)');
eq(run('numv("back_setback")'), 48, '(medzistav by bol 48 — preto sa neposiela)');
xf.value = '50-20';
xf.dispatchEvent({ type: 'keydown', key: 'Enter', preventDefault: () => {} });
eq(xf.value, '30', 'Enter vyhodnoti vyraz na 30');
eq(applied, 1, 'a az potom sa zmena odosle');
xf.value = '40+5';
xf.dispatchEvent({ type: 'blur' });
eq(xf.value, '45', 'opustenie pola vyraz tiez vyhodnoti');
doc.activeElement = null;

// --- 6) riadky, tooltip, suhrn -----------------------------------------------------
reset();
set('top_mode', 'none'); run('toggleTopSetback()');
eq(nodes.topSetbackRow.style.display, 'none', '„Bez stropu": riadok Zapustenie zmizne');
eq(nodes.top_front_setback.value, '0', '... hodnota ostava');
set('top_mode', 'full'); run('toggleTopSetback()');
eq(nodes.topSetbackRow.style.display, '', 'plny strop: riadok je');
set('top_mode', 'two_rails'); run('toggleTopSetback()');
eq(nodes.topSetbackRow.style.display, '', 'dve vystuhy: riadok je');
run('toggleBackSetback()');
eq(nodes.backSetbackRow.style.display, '', 'komin pre kazdy rezim chrbta');
run("setType('dishwasher'); toggleTopSetback(); toggleBackSetback();");
eq([nodes.topSetbackRow.style.display, nodes.backSetbackRow.style.display], ['none', 'none'], 'slot riadky nema');
run("setType('lower')");
const tip = c => run('backSetbackTipText(' + JSON.stringify(c) + ')');
ok(tip({ back_mode: 'overlay', back_thickness: 3, back_setback: 50 }).indexOf('Voľný kanál za chrbtom je teraz 47 mm') > 0,
   'nalozeny HDF 3: kanal X − bt = 47');
ok(tip({ back_mode: 'overlay', back_thickness: 18, back_setback: 50 }).indexOf('teraz 32 mm') > 0, 'pevny 18: 32');
ok(tip({ back_mode: 'groove', back_thickness: 3, back_setback: 50 }).indexOf('teraz 47 mm') > 0, 'drazka: X − bt');
ok(tip({ back_mode: 'inset', back_thickness: 3, back_setback: 50 }).indexOf('teraz 50 mm') > 0, 'vlozeny: X');
ok(tip({ back_mode: 'none', back_thickness: 3, back_setback: 50 }).indexOf('Voľný kanál') < 0, 'bez chrbta kanal neukazuje');
ok(tip({ back_mode: 'groove', back_thickness: 3, back_setback: 0 }).indexOf('najmenej 13 mm (drážka 10 + chrbát 3)') > 0,
   'minimum podla rezimu');
ok(tip({ back_mode: 'overlay', back_thickness: 3, back_setback: 0 }).indexOf('najmenej 3 mm') > 0, 'nalozeny: bt');
ok(tip({ back_mode: 'inset', back_thickness: 3, back_setback: 0 }).indexOf('bez minima') > 0, 'vlozeny: bez minima');
const meta = c => JSON.parse(JSON.stringify(run('setbackMetaTexts(' + JSON.stringify(c) + ')')));
eq(meta({ top_mode: 'full', top_front_setback: 30, back_setback: 50 }), { top: 'zap. 30', back: 'komín 50' }, 'suhrn A7');
eq(meta({ top_mode: 'full', top_front_setback: 0, back_setback: 0 }), { top: '', back: '' }, 'pri predvolbach cista hlavicka');
eq(meta({ top_mode: 'none', top_front_setback: 30, back_setback: 0 }), { top: '', back: '' }, 'bez stropu zapustenie nema zmysel');
eq(meta({ type: 'dishwasher', top_mode: 'full', top_front_setback: 30, back_setback: 50 }), { top: '', back: '' }, 'slot');
reset();
set('back_setback', 50); set('top_front_setback', 30);
run('updateSetbackMeta()');
eq([nodes.topMeta.textContent, nodes.backMeta.textContent], ['zap. 30', 'komín 50'], 'hlavicky sa kreslia z formulara');

// --- 7) odhad vkladania (nxDraftStats) -------------------------------------------------
const prev = require(path.join(DIR, 'preview.js'));
ok(typeof prev.nxDraftStats === 'function', 'nxDraftStats je exportovany');
{
  const g0 = { W: 600, H: 720, t: 18, D: 510, fh: 100, topMode: 'full', backMode: 'overlay' };
  const s0 = prev.nxDraftStats(g0, [], []);
  const g1 = Object.assign({}, g0, { sideD: 510, bottomD: 460, topD: 460, innerD: 460, backW: 564 });
  const s1 = prev.nxDraftStats(g1, [], []);
  close(s1.area, Math.round((2 * 620 * 510 + 600 * 460 + 564 * 460 + 564 * 620) / 1000) / 1000,
        'komin: dno a strop do R, uzsi nalozeny chrbat');
  ok(s1.area < s0.area, 'odhad pri komine mensi nez bez neho');
}
// PR #402 (Codex kolo 1 P2): most pvGeom posiela do odhadu UCINNU (orezanu)
// hlbku pasu vystuh — priklad d 260, X 50, Y 70, pas 100 -> builder stavia 60.
reset();
set('depth', 260); set('back_setback', 50); set('top_front_setback', 70); set('top_mode', 'two_rails');
const gr = run('pvSetbackDepths({ W: 600, H: 720, t: 18, D: 260, fh: 100, topMode: "two_rails", backMode: "overlay", railDepth: 100 })');
eq(gr.railDepth, 60, 'odhad pocita pas 60 mm (ako builder), nie pozadovanych 100');
const sr = prev.nxDraftStats(JSON.parse(JSON.stringify(gr)), [], []);
const sr100 = prev.nxDraftStats(Object.assign(JSON.parse(JSON.stringify(gr)), { railDepth: 100 }), [], []);
close(sr100.area - sr.area, Math.round(2 * 564 * 40 / 1000) / 1000, 'rozdiel plochy = 2 pasy x 564 x 40 mm');
// X = Y = 0: pas 150 by builder orezal na 118,5 (cd/2 − 10), ale odhad sa pri
// nulach NEMENI — ostava pozadovanych 150 ako doteraz. Keby sa orezanie
// presunulo pred skory navrat, dostali by sme 118,5 (delta P3 #1).
set('back_setback', 0); set('top_front_setback', 0); set('rail_depth', 150);
close(run('nxRailGeom(currentCarcass()).depth'), 118.5, '(builder by pri nulach orezal na 118,5)');
const g0r = run('pvSetbackDepths({ W: 600, H: 720, t: 18, D: 260, fh: 100, topMode: "two_rails", backMode: "overlay", railDepth: 150 })');
eq(g0r.railDepth, 150, 'X = Y = 0: odhad sa nemeni (pozadovana hlbka ako doteraz)');
eq(g0r.sideD, undefined, 'X = Y = 0: ziadne nove kluce');
// Vystuhy NA VYSKU s kominom (delta P3 #2): vyska 300, pas 200, komin 50 ->
// builder (Ruby `rail_geometry`) oreze vysku pasu na 162 = h − (s + t) − 20.
reset();
set('height', 300); set('rail_depth', 200); set('back_setback', 50);
set('top_mode', 'two_rails'); set('rails_orientation', 'upright');
const gu = run('pvSetbackDepths({ W: 600, H: 300, t: 18, D: 510, fh: 100, topMode: "two_rails", backMode: "overlay", railDepth: 200 })');
eq(gu.railDepth, 162, 'upright s kominom: odhad pocita orezanu vysku pasu 162 (ako Ruby rail_geometry)');

const prevSrc = fs.readFileSync(path.join(DIR, 'preview.js'), 'utf8');
ok(prevSrc.indexOf('if (!(g.backSetback > 0) && !(g.topFrontSetback > 0)) return g;') > 0,
   'pri X = Y = 0 odhad ostava presne dnesny');

console.log(`test_kona_komin.js: ${n} kontrol OK`);
