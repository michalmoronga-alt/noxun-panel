// KOV-E2 — EDITOR PRAVIDLA VÝKLOPOV (`lift_class`) v sekcii Pravidlá (rules.js).
//
// E1b vedela pravidlo len prečítať (jedna veta). E2 z neho robí FORMULÁR — a to
// je presne miesto, kde sa dá tíško stratiť dáta: tabuľka Blumu má pásma, ktoré
// sa spojito dotýkajú (`max_exclusive`), a to nie je pole formulára. Keby ho zber
// zahodil, dve pásma ramien by sa začali PREKRÝVAŤ a automat by pri hraničnej
// výške vybral iné ramená — bez jediného slova.
//
// ČO SA OVERUJE:
//   E1 pravidlo sa vykreslí ako EDITOR (nie read-only veta) a súhrn v lište
//      povie, čo blok skrýva (zbalený blok = vertikálny priestor)
//   E2 ROUND-TRIP formulár -> pravidlo: skaláre, tri tabuľky, spôsobilosť
//   E3 `max_exclusive` prežije zber (BEZSTRATOVO, hoci to nie je pole)
//   E4 prázdne pole = kritérium sa NEZAPÍŠE (vzor „prázdne = vypnuté" z F2)
//   E5 pridanie/odobranie riadku nezhodí rozpísané hodnoty INÝCH pravidiel
//   E6 POŠKODENÝ tvar (hash namiesto poľa) sekciu NEZHODÍ (lekcia Codex #330)
//   E7 klientska validácia má nové kritériá E2 (spoločná fixtúra parity)
//
// MUTÁCIE, ktoré sada chytá:
//   M1 `rdCollectLift` zahodí `max_exclusive`     -> E3
//   M2 prázdna rezerva sa pošle ako 0             -> E4
//   M3 zber prepíše tabuľky pravidla vedľa        -> E5
//   M4 `rdLiftHtml` padne nad hashom v `classes`  -> E6
//   M5 spôsobilosť sa zberom stratí               -> E2
//   M6 nekladná hodnota spôsobilosti ide na server -> E2 (server ju zahadzuje)
//   M7 súhrn prestane menovať tabuľky             -> E1
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const md = require(path.join(__dirname, 'minidom.js'));
const { DOC, mkEl } = md;

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

// Seedové pravidlo výklopov (skrátené, ale so VŠETKÝMI tvarmi, ktoré Blum má:
// spojité pásmo mechanizmov aj ramien = `max_exclusive`).
function liftRule(over){
  return Object.assign({
    rule_id: 'vyklopy-aventos', kind: 'lift_class', output: 'lift', enabled: true,
    applies_to: { role: 'flap', flap_dir: 'up' },
    handle_allowance_kg: 0.5, rod_double_from_kb_mm: 1100,
    classes: [{ code: '22K2300', min: 420, max: 1610 },
              { code: '22K2500', min: 930, max: 2800 }],
    mechanisms: [{ code: '22L2200', max: 390, max_exclusive: true },
                 { code: '22L2500', max: 580 }],
    arms: [{ code: '22L3200', kh_min: 300, kh_max: 340, kg_min: 1.5, kg_max: 9,
             max_exclusive: true },
           { code: '22L3800', kh_min: 340, kh_max: 540, kg_min: 2, kg_max: 12.25 }],
    eligibility: { hk_top: { kh_min: 205, kh_max: 600, kb_max: 1800 },
                   hl_top: { kh_min: 300, kh_max: 580, kb_max: 1800, depth_min: 264 } }
  }, over || {});
}
function hingeRule(){
  return { rule_id: 'zavesy-podla-vysky', kind: 'bands', output: 'hinge', enabled: true,
           input: 'height', applies_to: { role: 'front_door' },
           bands: [{ max: 849, quantity: 2 }, { max: null, quantity: 7 }] };
}
function show(rules){
  R.RD.init({ version: '0.9.55', source: 'project', cabinets: 1, model_guid: 'G1',
              rules_rev: 'rev1', rules: rules,
              abs: { rows: [], source: '', hint: '' },
              overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } });
}
function box(){ return DOC.getElementById('rulesBox'); }
function val(sel, v){ const e = box().querySelector(sel); e.value = String(v); return e; }

// ============ E1: editor sa vykreslí a lišta povie, čo skrýva ================
show([liftRule()]);
ok(box().querySelector('.rlift'), 'E1: pravidlo výklopov má EDITOR, nie vetu');
const sum = md.textOf(box().querySelector('.rgsum'));
ok(sum.indexOf('HK 2 triedy') >= 0, 'E1: súhrn menuje tabuľku tried: ' + sum);
ok(sum.indexOf('2 + 2 ramená') >= 0, 'E1: aj mechanizmy a ramená HL: ' + sum);
ok(sum.indexOf('tyč od 1100 mm') >= 0 && sum.indexOf('rezerva 0.5 kg') >= 0,
   'E1: aj skaláre: ' + sum);
eq(box().querySelectorAll('.lcls').length, 2, 'E1: riadok na každú triedu HK');
eq(box().querySelectorAll('.lmech').length, 2, 'E1: aj na každý mechanizmus HL');
eq(box().querySelectorAll('.larm').length, 2, 'E1: aj na každé ramená');
eq(box().querySelectorAll('.lelig').length, 2, 'E1: spôsobilosť má riadok na každý systém');
// Zbalený blok je default — otvorený stav si pamätá modul (nie DOM).
eq(box().querySelector('.rlift').attrs.open, undefined,
   'E1: editor je ZBALENÝ (vertikálny priestor panela je vzácny)');

// ============ E2: ROUND-TRIP formulár -> pravidlo =============================
show([liftRule()]);
const round = R.rdCollectRules()[0];
eq(round.handle_allowance_kg, 0.5, 'E2: rezerva prežije zber');
eq(round.rod_double_from_kb_mm, 1100, 'E2: aj prah druhej tyče');
eq(round.classes, [{ code: '22K2300', min: 420, max: 1610 },
                   { code: '22K2500', min: 930, max: 2800 }], 'E2: tabuľka tried HK');
eq(round.eligibility, { hk_top: { kh_min: 205, kh_max: 600, kb_max: 1800 },
                        hl_top: { kh_min: 300, kh_max: 580, kb_max: 1800, depth_min: 264 } },
   'E2: spôsobilosť oboch systémov (M5)');
eq(R.rdValidate([round]), null, 'E2: a taký tvar klient prijme');

// Zmena hodnoty vo formulári sa naozaj prenesie.
show([liftRule()]);
val('.lallow', '0.75');
val('.lrod', '1200');
val('.lcls .lfcode', '22K9999');
const zmena = R.rdCollectRules()[0];
eq(zmena.handle_allowance_kg, 0.75, 'E2: prepísaná rezerva');
eq(zmena.rod_double_from_kb_mm, 1200, 'E2: prepísaný prah tyče');
eq(zmena.classes[0].code, '22K9999', 'E2: prepísaný kód triedy');

// ============ E3: `max_exclusive` je BEZSTRATOVÝ =============================
show([liftRule()]);
const mx = R.rdCollectRules()[0];
eq(mx.mechanisms[0].max_exclusive, true,
   'E3: spojité pásmo mechanizmu prežije zber (M1 — inak by sa pásma prekryli)');
eq(mx.mechanisms[1].max_exclusive, undefined, 'E3: inkluzívne pásmo si príznak nevymyslí');
eq(mx.arms[0].max_exclusive, true, 'E3: aj pri ramenách');
eq(mx.arms[1].max_exclusive, undefined, 'E3: a len tam, kde naozaj je');

// ============ E4: prázdne pole = kritérium sa NEZAPÍŠE ======================
show([liftRule()]);
val('.lallow', '');
val('.lrod', '');
const prazdne = R.rdCollectRules()[0];
ok(!Object.prototype.hasOwnProperty.call(prazdne, 'handle_allowance_kg'),
   'E4: vyprázdnená rezerva sa NEPOSIELA ako nula (M2)');
ok(!Object.prototype.hasOwnProperty.call(prazdne, 'rod_double_from_kb_mm'),
   'E4: ani prah tyče');
// Nekladná spôsobilosť ide preč rovnako ako na serveri (`normalize_lift_eligibility`).
show([liftRule()]);
val('.lelig[data-sys="hk_top"] .le_kb_max', '0');
const elig = R.rdCollectRules()[0].eligibility;
ok(!Object.prototype.hasOwnProperty.call(elig.hk_top, 'kb_max'),
   'E4: nula v spôsobilosti = kritérium vypnuté (M6)');
eq(elig.hk_top.kh_min, 205, 'E4: ostatné kritériá ostávajú');

// ============ E5: pridanie riadku nezhodí rozpísané hodnoty ==================
show([liftRule(), hingeRule()]);
val('.lallow', '0.9');
box().querySelectorAll('.rrule')[1].querySelector('.bqty').value = '5';
R.rdAddLiftClass(box().querySelector('.rlift .btnrow .ghostbtn'));
const po = R.rdCollectRules();
eq(po[0].handle_allowance_kg, 0.9, 'E5: rozpísaná rezerva prežila pridanie riadku');
eq(po[0].classes.length, 3, 'E5: a riadok naozaj pribudol');
eq(po[0].classes[2], { code: '', min: null, max: null },
   'E5: nový riadok je PRÁZDNY — server aj klient ho zahodia, kým ho nevyplníš');
eq(po[1].bands[0].quantity, 5, 'E5: a hodnota SUSEDNÉHO pravidla tiež (M3)');

// Odobranie riadku mieri na správny index.
show([liftRule()]);
R.rdDelLiftClass(box().querySelectorAll('.lcls')[0].querySelector('.bdel'));
eq(R.rdCollectRules()[0].classes.map(c => c.code), ['22K2500'],
   'E5: ✕ zmaže PRÁVE ten riadok, pri ktorom stojí');
show([liftRule()]);
R.rdDelLiftArm(box().querySelectorAll('.larm')[1].querySelector('.bdel'));
eq(R.rdCollectRules()[0].arms.map(a => a.code), ['22L3200'], 'E5: rovnako pri ramenách');
show([liftRule()]);
R.rdDelLiftMech(box().querySelectorAll('.lmech')[0].querySelector('.bdel'));
eq(R.rdCollectRules()[0].mechanisms.map(m => m.code), ['22L2500'], 'E5: aj pri mechanizmoch');

// ============ E6: POŠKODENÝ tvar sekciu NEZHODÍ =============================
// Cudzí alebo ručne pokazený snapshot môže niesť tabuľku ako hash či reťazec.
// Sekcia sa kreslí JEDNÝM `innerHTML`, takže jediný `.forEach` nad hashom by
// zhodil CELÚ sekciu — a s ňou aj možnosť chybu opraviť (lekcia Codex #330).
show([liftRule({ classes: 'nezmysel', arms: null, mechanisms: { a: 1 },
                 eligibility: 'x', handle_allowance_kg: 'y' })]);
ok(box().querySelector('.rlift'), 'E6: editor sa vykreslil aj nad poškodeným tvarom (M4)');
const bad = md.textOf(box().querySelector('.rgsum'));
ok(bad.indexOf('HK 0 tried') >= 0, 'E6: a prizná sa k prázdnym tabuľkám: ' + bad);
eq(box().querySelectorAll('.lcls').length, 0, 'E6: žiadny riadok sa nedomyslel');
const opravene = R.rdCollectRules()[0];
eq(opravene.classes, [], 'E6: zber z neho spraví PRÁZDNE pole — uložením sa nezmysel odpratá');
eq(opravene.eligibility, {}, 'E6: aj spôsobilosť');
ok(R.rdValidate([opravene]) !== null, 'E6: a prázdne tabuľky klient odmietne uložiť');

// ============ E7: klientska VALIDÁCIA (nové kritériá E2) =====================
ok(R.rdLiftProblem(liftRule({ rod_double_from_kb_mm: -1100 })) !== null,
   'E7: záporný prah druhej tyče');
ok(R.rdLiftProblem(liftRule({ classes: [{ code: 'A', min: -1, max: 100 }] })) !== null,
   'E7: záporné LF v triede');
ok(R.rdLiftProblem(liftRule({
  arms: [{ code: 'A', kh_min: 300, kh_max: 340, kg_min: -1, kg_max: 9 }]
})) !== null, 'E7: záporná hmotnosť ramien');
const eligMsg = R.rdLiftProblem(liftRule({
  eligibility: { hk_top: { kh_min: 205, kh_max: 600 }, hl_top: { kh_min: 580, kh_max: 300 } }
}));
ok(eligMsg !== null && eligMsg.indexOf('HL top') >= 0,
   'E7: spôsobilosť s obrátenou výškou menuje SYSTÉM: ' + eligMsg);
eq(R.rdLiftProblem(liftRule({
  eligibility: { hl_top: { kh_min: 300, kh_max: 300 } }
})), null, 'E7: rovnaká hranica je legitímna (jedna povolená výška)');
eq(R.rdLiftProblem(liftRule()), null, 'E7: seedový tvar prejde');

// ULOŽENIE: pokazené pravidlo sa nedostane na server, dobré áno.
show([liftRule()]);
SENT.length = 0;
R.rdSaveRules();
eq(SENT.length, 1, 'E7: platný formulár sa odošle');
eq(SENT[0].rules[0].arms.length, 2, 'E7: aj s tabuľkami');
show([liftRule({ classes: [] })]);
SENT.length = 0;
R.rdSaveRules();
eq(SENT.length, 0, 'E7: pokazený sa NEODOŠLE — používateľ má kde chybu opraviť');

console.log('KOV-E2 editor pravidiel: ' + n + ' assertov OK');
