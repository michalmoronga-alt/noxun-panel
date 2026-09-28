// ROH-A1 · K3 — rohová skrinka, panelová polovica (LEN registre typu a rolí).
//   node tests/js/test_roha1_rohova.js
//
// Co sa tu strazi (krizovy audit G1 + C6, package ROH-A1 bod 9):
//   1) `setType('corner_blind')` typ DRZI — neznamy typ by oznacenu rohovu
//      sklopil na dolnu a kazdy zapis by ju poslal spat ako `lower`,
//   2) PARITA registrov: CAB_TYPES / INSERT_TYPES / NX_TYPE_LABEL / TYPE_LIMITS
//      / typ sablony (rohova sablona nepadne do „dolnej"),
//   3) `collectConstruction` polia rohovej NEPOSIELA (bez ovladaca by isli
//      ako null a server by ich prepisal — C6); typ posiela `corner_blind`,
//   4) karta dielca a pravidla poznaju nove roly (nazov, celovy material).
// Zrkadlo Ruby: tests/pure/test_roha1_rohova.rb.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const JS = path.join(ROOT, 'noxun_engine', 'ui', 'js');

let n = 0;
function eq(actual, expected, msg){ n++; assert.deepStrictEqual(actual, expected, msg); }
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- spolocny kontext ako v CEF (skripty zdielaju globaly) -----------------------
function mkCtx(){
  const ctx = { console, setTimeout, clearTimeout, window: {} };
  ctx.document = { getElementById: () => null, querySelectorAll: () => [], querySelector: () => null,
                   addEventListener(){}, body: { appendChild(){} },
                   createElement: () => ({ style: {}, setAttribute(){}, appendChild(){} }) };
  vm.createContext(ctx);
  return ctx;
}
function load(ctx, file){ vm.runInContext(fs.readFileSync(path.join(JS, file), 'utf8'), ctx, { filename: file }); }

// ============ 1) setType drzi rohovu =========================================
const ctx = mkCtx();
load(ctx, 'core.js');
load(ctx, 'form.js');
ctx.syncInsertTypeButtons = function(){};
ctx.setType('corner_blind');
eq(ctx.getType(), 'corner_blind', 'setType drzi rohovu (G1)');
ctx.setType('nieco');
eq(ctx.getType(), 'lower', 'neznamy typ dalej padne na dolnu');
ctx.setType('corner_blind');

// ============ 2) registre =====================================================
const core = require(path.join(JS, 'core.js'));
eq(core.NX_TYPE_LABEL.corner_blind, 'Rohová', 'hlavicka Inspectora');
eq(core.nxCabInfo({ type: 'corner_blind' }).type, 'Rohová', 'badge nad rohovou nehlasi „Dolná"');
const cabTypes = vm.runInContext('CAB_TYPES', ctx);
eq(Array.from(cabTypes), ['lower', 'upper', 'dishwasher', 'corner_blind'], 'CAB_TYPES = Ruby TYPES');
const NXInsert = require(path.join(JS, 'insert_state.js'));
eq(NXInsert.INSERT_TYPES, ['lower', 'upper', 'dishwasher', 'corner_blind', 'board'], 'INSERT_TYPES');
eq(NXInsert.templateType({ config: { type: 'corner_blind' } }), 'corner_blind', 'rohova sablona nie je „dolna"');
const LIB = [{ name: 'Rohova 1100', kind: 'cabinet', config: { type: 'corner_blind' } },
             { name: 'Dolna klasik', kind: 'cabinet', config: { type: 'lower' } }];
eq(NXInsert.templatesForType(LIB, 'corner_blind').map(t => t.name), ['Rohova 1100'], 'filter rohovych sablon');
eq(NXInsert.templatesForType(LIB, 'lower').map(t => t.name), ['Dolna klasik'], 'dolna ponuka rohovu nevidi');
const limits = vm.runInContext('TYPE_LIMITS', ctx);
// ROH-B1 (O2 + P3-2): pevne minimum 584 zaniklo — najmensiu sirku pocita
// krizova kontrola z poli rohovej a ucinnych hrubok (test_rohb1_ovladace.js).
ok(!limits.corner_blind, 'TYPE_LIMITS rohovej uz nema pevne minimum (ROH-B1)');
eq(Array.from(vm.runInContext("limitFor('width')", ctx)), [200, 3000], 'limit sirky pri rohovej = korpus (minimum riesi kontrola)');
eq(ctx.nxCornerMinWidth(450, 80, 18, 18), 584, 'minimum predvolieb 450 + 80 + 18 + 2 x 18');
ctx.setType('lower');
eq(Array.from(vm.runInContext("limitFor('width')", ctx)), [200, 3000], 'dolna ma dalej 200');
ctx.setType('corner_blind');
const tplSrc = fs.readFileSync(path.join(JS, 'templates.js'), 'utf8');
ok(tplSrc.indexOf("corner_blind: 'rohová'") >= 0, 'TPL_TYPE_WORDS pozna rohovu');

// ============ 3) collectConstruction: polia rohovej od ROH-B1, strana nikdy =====
const FIELDS = { width: '1100', height: '862', depth: '510', thickness: '18', floor_height: '150',
                 back_mode: 'overlay', back_thickness: '3', top_mode: 'full', bottom_mode: 'under_sides',
                 plinth_mode: 'none', plinth_recess: '40', rail_depth: '100', rails_orientation: 'flat',
                 rails_top_offset: '0', back_setback: '0', top_front_setback: '0', back_rail_height: '100',
                 corner_side: 'right', corner_door_w: '600', corner_cr1: '120', corner_cr2: '90' };
ctx.val = id => (FIELDS[id] === undefined ? '' : FIELDS[id]);
ctx.numv = id => parseFloat(FIELDS[id]);
ctx.evalDim = v => parseFloat(v);
const out = ctx.collectConstruction();
eq(out.type, 'corner_blind', 'apply posiela typ rohovej (poistka servera ho nepotrebuje zahodit)');
ok(!Object.prototype.hasOwnProperty.call(out, 'corner_side'), 'strana sa v apply NEPOSIELA (meni ju len prepinac)');
eq([out.corner_door_w, out.corner_cr1, out.corner_cr2], [600, 120, 90], 'ROH-B1: dverova cast a CR idu z riadku rohovej');
const ids = core.CONSTRUCTION_FIELDS.map(f => f.id);
ok(ids.indexOf('corner_side') < 0, 'CONSTRUCTION_FIELDS nema stranu (prepinac, nie pole)');
['corner_door_w', 'corner_cr1', 'corner_cr2'].forEach(function(k){
  eq(core.CONSTRUCTION_FIELDS.find(f => f.id === k).only, 'corner_blind', `${k} len pri rohovej (C6)`);
});

// ============ 4) karta dielca a pravidla ======================================
const pc = mkCtx();
load(pc, 'part_card.js');
[['corner_blind_panel', 'Blenda korpusová'], ['hinge_rail', 'Výstuha závesov'], ['corner_rail', 'Rohová výstuha'],
 ['cr_front', 'CR lišta 1'], ['cr_side', 'CR lišta 2']].forEach(function(p){
  eq(pc.roleLabel(p[0]), p[1], `roleLabel ${p[0]}`);
});
const pcSrc = fs.readFileSync(path.join(JS, 'part_card.js'), 'utf8');
ok(pcSrc.indexOf("pc.role === 'cr_front' || pc.role === 'cr_side'") >= 0,
   'isFront: CR listy vyberaju z celovych materialov (18,6/19 mm aktivne)');
ok(pcSrc.indexOf("pc.role === 'corner_blind_panel'") < 0, 'blenda korpusova NIE je celo (vzdy korpus)');
const rl = mkCtx();
load(rl, 'rules.js');
['corner_blind_panel', 'hinge_rail', 'corner_rail', 'cr_front', 'cr_side'].forEach(function(r){
  const d = rl.rdRoleDesc({ applies_to: { role: r } });
  ok(d !== r && d.indexOf('na ') === 0, `rdRoleDesc ${r}: „${d}"`);
});

console.log(`test_roha1_rohova.js: ${n} asercii OK`);
