// S1-E0 — MINIMALNA VYSKA KORPUSU 80 mm, panelova polovica.
//
// Michal (20.9.2026): „nad umyvackou ostava len 80-110 mm, vyplnam to nizkym
// korpusom na dorovnanie — plugin ma pod 200 nepusti."
//
// Co sa tu strazi:
//   1) LIMITS.height = [80,3000]; sirka a hlbka sa NEMENIA (ich cisla su tu
//      zamerne tiez, aby sa „odomknutie" neprelialo na rozmery bez zmyslu).
//   2) validateFields naozaj pusti 80 a odmietne 79 — teda cerveny okraj
//      a zablokovany apply sa riadia zmenenym limitom, nie starou hodnotou.
//   3) KRIZOVA KONTROLA: vyska je CELKOVA vratane sokla, takze dolna skrinka
//      90 mm s predvolenym soklom 100 nema ziadne vnutro. Panel to musi
//      povedat CERVENYM polom a hlaskou — bez toho by apply presiel az
//      k vynimke Ruby `Construction.validate!`.
// Zrkadlo Ruby: tests/pure/test_s1e0_min_vyska.rb (parita cisel) a
// tests/pure/test_construction.rb (to iste pravidlo vnutra na strane planu).
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const dir = path.join(__dirname, '../../noxun_engine/ui/js');
const { evalDim, isExprStr } = require(path.join(dir, 'expr.js'));
const core = require(path.join(dir, 'core.js'));

// --- minimalny DOM: len polia, ktore validacia cita ---------------------------
const fields = {
  width: '600', height: '720', depth: '510', thickness: '18', floor_height: '100',
  plinth_recess: '40', rail_depth: '100', rails_top_offset: '0',
  fr_gap: '3', fr_gap_top: '2', fr_gap_bottom: '2', fr_gap_left: '2', fr_gap_right: '2'
};
const selects = { back_mode: 'overlay', back_thickness: '3', top_mode: 'full', rails_orientation: 'flat' };
const nodes = {};
function node(id){
  if (!nodes[id]){
    const n = { cls: {}, title: '' };
    Object.defineProperty(n, 'value', { get: () => (fields[id] === undefined ? '' : fields[id]) });
    n.classList = { add: c => { n.cls[c] = 1; }, remove: c => { delete n.cls[c]; },
                    contains: c => !!n.cls[c] };
    nodes[id] = n;
  }
  return nodes[id];
}
function num(id){
  if (selects[id] !== undefined) return evalDim(selects[id]);
  return evalDim(fields[id] === undefined ? '' : fields[id]);
}
let cabType = 'lower';
const ctx = {
  el: id => (fields[id] === undefined ? null : node(id)),
  val: id => (selects[id] !== undefined ? selects[id] : fields[id]),
  numv: num, setNum: (id, v) => { fields[id] = String(v); }, setOut: () => {}, onField: () => {},
  evalDim, isExprStr, getType: () => cabType,
  nxInteriorZ: core.nxInteriorZ, nxRailGeom: core.nxRailGeom, nxCarcassDepth: core.nxCarcassDepth,
  NX_MIN_INTERIOR_H: core.NX_MIN_INTERIOR_H,
  document: { activeElement: null }, setTimeout: () => 0, clearTimeout: () => {}, console
};
// DOM most core.js (`currentCarcass`) sa neexportuje — tu je jeho verna kopia
// nad tym istym stubom poli, aby sa testovala LOGIKA form.js, nie citanie DOM.
ctx.currentCarcass = function (over){
  const c = { height: num('height'), thickness: num('thickness'),
              floor_height: cabType === 'upper' ? 0 : num('floor_height'),
              depth: num('depth'), back_mode: selects.back_mode, back_thickness: num('back_thickness'),
              top_mode: selects.top_mode, rails_orientation: selects.rails_orientation,
              rails_top_offset: num('rails_top_offset'), rail_depth: num('rail_depth') };
  if (over){ for (const k in over){ if (Object.hasOwn(over, k)) c[k] = over[k]; } }
  return c;
};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(dir, 'form.js'), 'utf8'), ctx);

let n = 0;
// `skipFrontDraft` = true: zoznam ciel v tomto stube neexistuje a draft ciel
// nie je predmetom tejto sady.
function valid(){ n++; return ctx.validateFields(true); }
function bad(id){ return node(id).cls.bad === 1; }
function reset(){
  Object.assign(fields, { width: '600', height: '720', depth: '510', thickness: '18', floor_height: '100' });
  Object.assign(selects, { back_mode: 'overlay', back_thickness: '3', top_mode: 'full', rails_orientation: 'flat' });
  cabType = 'lower';
  valid();
}

// --- 1) limity ---------------------------------------------------------------
// `Array.from` je nutne: pole vzniklo VNUTRI vm kontextu, takze nie je
// instanciou Array tohto realmu a deepEqual by ho odmietol aj pri zhode.
assert.deepEqual(Array.from(ctx.LIMITS.height), [80, 3000], 'vyska ide od 80 mm (S1-E0)');
assert.deepEqual(Array.from(ctx.LIMITS.width), [200, 3000], 'sirka sa NEMENI');
assert.deepEqual(Array.from(ctx.LIMITS.depth), [150, 2000], 'hlbka sa NEMENI');
n += 3;

// --- 2) hranica vysky v poli -------------------------------------------------
reset();
fields.floor_height = '0'; // korpus na dorovnanie stoji na umyvacke, nie na zemi
fields.height = '80';
assert.equal(valid(), true, 'vyska 80 je platna');
assert.equal(bad('height'), false, 'a pole nie je cervene');
fields.height = '79';
assert.equal(valid(), false, 'vyska 79 je pod limitom');
assert.equal(bad('height'), true, 'a pole zocervenie');
fields.height = '90';
assert.equal(valid(), true, 'realna vyska korpusu na dorovnanie (90) prejde');
fields.height = '3001';
assert.equal(valid(), false, 'horna hranica 3000 plati dalej');
n += 6;

// --- 3) sirka sa NEODOMKLA ---------------------------------------------------
reset();
fields.width = '199';
assert.equal(valid(), false, 'sirka 199 je dalej chyba');
assert.equal(bad('width'), true, 'a sirka zocervenie');
fields.width = '200';
assert.equal(valid(), true, 'sirka 200 je dalej platna');
n += 3;

// --- 4) krizova kontrola: vyska je CELKOVA vratane sokla ---------------------
reset();
fields.height = '90'; // sokel ostava predvolenych 100 -> vnutro by bolo zaporne
assert.equal(valid(), false, 'nizky korpus s vysokym soklom sa NEAPLIKUJE');
assert.equal(bad('height'), true, 'vyska zocervenie');
assert.equal(bad('floor_height'), true, 'podstavec tiez — chyba je v ich dvojici');
assert.match(node('height').title, /podstavec/i, 'hlaska pomenuje podstavec');
fields.floor_height = '0';
assert.equal(valid(), true, 'po vynulovani sokla je ta ista vyska v poriadku');
assert.equal(node('height').title, '', 'a hlaska zmizne');
assert.equal(bad('height'), false, 'aj cerveny okraj');
n += 7;

// Horna skrinka sokel nema — 80 mm prejde aj s vyplnenym polom sokla.
reset();
cabType = 'upper';
fields.height = '80'; fields.depth = '320'; fields.floor_height = '100';
assert.equal(valid(), true, 'horna skrinka 80 mm sa sokla nedotkne');
n += 1;

// --- 5) dve vystuhy potrebuju rezervu vnutra (D-80) --------------------------
// 80 mm so soklom 25 a vrchom „dve výstuhy": pod vystuhami ostane 19 mm,
// teda pod rezervou MIN_INTERIOR_H (20). Bez tejto vetvy by apply prebehol
// az k Ruby vynimke „Vnútro je príliš nízke na výstuhy".
reset();
fields.floor_height = '25'; fields.height = '80'; selects.top_mode = 'two_rails';
assert.equal(valid(), false, 'nizky korpus s dvoma vystuhami nema rezervu vnutra');
assert.match(node('height').title, /výstuh/i, 'hlaska pomenuje vystuhy');
// ten isty korpus s PLNYM vrchom je v poriadku — chyba je v kombinacii
selects.top_mode = 'full';
assert.equal(valid(), true, 'plny vrch tu istu vysku pusti');
n += 3;

console.log(`S1-E0 (min vyska korpusu 80 mm): ${n} kontrol OK`);
