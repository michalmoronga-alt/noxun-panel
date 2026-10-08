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
// H12c: typy su register servera — v CEF ho plni `NX.init`.
const TYPES = require('./nx_types_fixture.js');
TYPES.fill(ctx);
ctx.syncInsertTypeButtons = function(){};
ctx.setType('corner_blind');
eq(ctx.getType(), 'corner_blind', 'setType drzi rohovu (G1)');
ctx.setType('nieco');
eq(ctx.getType(), 'lower', 'neznamy typ dalej padne na dolnu');
ctx.setType('corner_blind');

// ============ 2) registre =====================================================
// H12c (T4): JS zoznamy typu (CAB_TYPES, INSERT_TYPES, NX_TYPE_LABEL,
// TYPE_LIMITS, TPL_TYPE_WORDS) zanikli — vsetko je register servera.
const core = require(path.join(JS, 'core.js'));
eq(core.NX_TYPE_LABEL, undefined, 'JS mapa popiskov zanikla');
eq(core.NXTypes.label('corner_blind'), 'Rohová', 'hlavicka Inspectora (label registra)');
eq(core.nxCabInfo({ type: 'corner_blind' }).type, 'Rohová', 'badge nad rohovou nehlasi „Dolná"');
eq(vm.runInContext('typeof CAB_TYPES', ctx), 'undefined', 'CAB_TYPES zanikol');
eq(Array.from(vm.runInContext('NXTypes.ids()', ctx)), ['lower', 'upper', 'dishwasher', 'corner_blind'],
   'register v JS = Ruby CabinetTypes::IDS (zmluvna fixtura)');
const NXInsert = require(path.join(JS, 'insert_state.js'));
eq(NXInsert.insertTypes(), ['lower', 'upper', 'dishwasher', 'corner_blind', 'board'], 'typy vkladania = register + doska');
eq(NXInsert.templateType({ config: { type: 'corner_blind' } }), 'corner_blind', 'rohova sablona nie je „dolna"');
const LIB = [{ name: 'Rohova 1100', kind: 'cabinet', config: { type: 'corner_blind' } },
             { name: 'Dolna klasik', kind: 'cabinet', config: { type: 'lower' } }];
eq(NXInsert.templatesForType(LIB, 'corner_blind').map(t => t.name), ['Rohova 1100'], 'filter rohovych sablon');
eq(NXInsert.templatesForType(LIB, 'lower').map(t => t.name), ['Dolna klasik'], 'dolna ponuka rohovu nevidi');
// ROH-B1 (O2 + P3-2): pevne minimum 584 zaniklo — najmensiu sirku pocita
// krizova kontrola z poli rohovej a ucinnych hrubok (test_rohb1_ovladace.js).
eq(vm.runInContext("NXTypes.get('corner_blind').limits", ctx), null, 'rohova nema vlastne rozsahy (ROH-B1)');
eq(Array.from(vm.runInContext("limitFor('width')", ctx)), [50, 3000], 'limit sirky pri rohovej = korpus (minimum riesi kontrola)');
eq(ctx.nxCornerMinWidth(450, 80, 18, 18), 584, 'minimum predvolieb 450 + 80 + 18 + 2 x 18');
ctx.setType('lower');
eq(Array.from(vm.runInContext("limitFor('width')", ctx)), [50, 3000], 'dolna ma korpusove minimum 50');
ctx.setType('corner_blind');
const tplSrc = fs.readFileSync(path.join(JS, 'templates.js'), 'utf8');
ok(tplSrc.indexOf('TPL_TYPE_WORDS') < 0, 'Studio nema vlastnu mapu slov typu (H12c: `type_word` zo servera)');
eq(TYPES.registry().find(r => r.id === 'corner_blind').word, 'rohová', 'slovo rohovej je v registri');

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
  // H12c (T4): `onlyIf` = predikat registra (typ s rohovou zostavou), nie meno typu.
  eq(core.CONSTRUCTION_FIELDS.find(f => f.id === k).onlyIf, 'corner', `${k} len pri rohovej (C6)`);
});

// ============ 4) karta dielca a pravidla ======================================
const pc = mkCtx();
load(pc, 'part_card.js');
// H12d (T4): meno roly sklada SERVER (`PartKeys::ROLE_LABELS` -> `role_label`
// v payloade karty; Ruby golden `roles.json`), karta ho len vypise.
const ROLES_GOLDEN = JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'h12_golden', 'roles.json'), 'utf8'));
[['corner_blind_panel', 'Blenda korpusová'], ['hinge_rail', 'Výstuha závesov'], ['corner_rail', 'Rohová výstuha'],
 ['cr_front', 'CR lišta 1'], ['cr_side', 'CR lišta 2']].forEach(function(p){
  eq(ROLES_GOLDEN.role_label[p[0]], p[1], `server role_label ${p[0]}`);
  eq(pc.pcRoleText({ role: p[0], role_label: ROLES_GOLDEN.role_label[p[0]] }), p[1], `karta vypise role_label ${p[0]}`);
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
