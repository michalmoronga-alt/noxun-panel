// KOV-G1b — EDITOR PRAVIDIEL: nohy podľa ŠÍRKY a prah výšky sokla (rules.js).
//
// Prečo je to test a nie pozretie: tabuľka pásiem vyzerá pri každom pravidle
// rovnako („do X mm → N ks") — PODĽA ČOHO sa meria, v nej nie je vidieť. Kým
// boli pásma len závesové (výška čela), bolo to jedno; od G1b sú pásma aj
// korpusové (šírka), takže bez vety pod tabuľkou by používateľ prestavoval
// nohy podľa výšky. A prah výšky sokla (`floor_height_min`) editor ZÁMERNE
// needituje — o to dôležitejšie je, že ho zber NESMIE stratiť: bez neho by
// príchyt sokla pribudol aj ku klzáku 17 mm, kde žiadna soklová lišta nie je.
//
// ČO SA OVERUJE:
//   G1 popis roly menuje PRAH („na skrinku na nohách so soklom od 55 mm")
//   G2 veta „Pásma podľa šírky korpusu." je LEN pri korpusovom pravidle na
//      šírku — závesy (výška čela) ostávajú bez novej vety
//   G3 pravidlo sa vykreslí ako TABUĽKA pásiem (nie „pravidlo novšej verzie")
//   G4 ROUND-TRIP: `rdCollectRules` zachová `applies_to.floor_height_min`
//      a uloženie ho pošle na server
//
// MUTÁCIE, ktoré sada chytá:
//   M1 `rdWidthHint` prestane pozerať na `input` (veta aj pri závesoch)  -> G2
//   M2 `rdRoleDesc` prah ignoruje (obe pravidlá vyzerajú rovnako)        -> G1
//   M3 zber prepíše `applies_to` (prah sa stratí)                        -> G4
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

// Seedové pravidlá presne v tvare, v akom ich posiela server (po `normalize_rules`).
function legRule(){
  return { rule_id: 'nohy-zakladne', kind: 'bands', output: 'leg', enabled: true,
           input: 'width', applies_to: { role: 'cabinet', support: ['legs', 'plinth'] },
           bands: [{ max: 999, quantity: 4 }, { max: null, quantity: 6 }],
           params_from_context: { height: 'floor_height' } };
}
function clipRule(){
  return { rule_id: 'prichyt-sokla', kind: 'bands', output: 'plinth_clip', enabled: true,
           input: 'width',
           applies_to: { role: 'cabinet', support: ['legs'], floor_height_min: 55 },
           bands: [{ max: 999, quantity: 1 }, { max: null, quantity: 2 }] };
}
function hingeRule(){
  return { rule_id: 'zavesy-podla-vysky', kind: 'bands', output: 'hinge', enabled: true,
           input: 'height', applies_to: { role: 'front_door' },
           bands: [{ max: 849, quantity: 2 }, { max: null, quantity: 7 }] };
}
function show(rules){
  R.RD.init({ version: '0.9.59', source: 'project', cabinets: 1, model_guid: 'G1',
              rules_rev: 'rev1', rules: rules,
              abs: { rows: [], source: '', hint: '' },
              overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } });
}
function box(){ return DOC.getElementById('rulesBox'); }

// ============ G1: popis roly menuje PRAH výšky sokla =========================
eq(R.rdRoleDesc(clipRule()), 'na skrinku na nohách so soklom od 55 mm',
   'G1: pravidlo s prahom povie, OD AKEJ výšky sokla platí');
eq(R.rdRoleDesc(legRule()), 'na skrinku s podstavcom',
   'G1: pravidlo BEZ prahu ostáva presne ako doteraz');
eq(R.rdRoleDesc({ applies_to: { role: 'cabinet', support: ['legs'], floor_height_min: 0 } }),
   'na skrinku s podstavcom',
   'G1: nepoužiteľný prah (0) sa nekreslí — server ho aj tak zahodí');

// ============ G2: veta „Pásma podľa šírky korpusu." ==========================
eq(R.rdWidthHint(legRule()), 'Pásma podľa šírky korpusu.', 'G2: nohy merajú šírku');
eq(R.rdWidthHint(clipRule()), 'Pásma podľa šírky korpusu.', 'G2: príchyt tiež');
eq(R.rdWidthHint(hingeRule()), null,
   'G2: závesy (výška čela) NOVÚ vetu nedostanú — panel je na miesto lakomý');
eq(R.rdWidthHint({ kind: 'fixed', output: 'leg', applies_to: { role: 'cabinet' } }), null,
   'G2: pevný počet žiadnu tabuľku nemá');
eq(R.rdWidthHint({ kind: 'bands', input: 'width', applies_to: { role: 'front_door' } }), null,
   'G2: šírka DIELCA nie je šírka korpusu');
eq(R.rdWidthHint({ kind: 'bands', input: 'height', applies_to: { role: 'cabinet' } }), null,
   'G2: korpusové pásma podľa VÝŠKY vetu o šírke nedostanú (M1)');

// ============ G3: vykreslenie ================================================
show([legRule(), clipRule(), hingeRule()]);
const rules = box().querySelectorAll('.rrule');
eq(rules.length, 3, 'G3: tri pravidlá, tri bloky');
eq(box().querySelectorAll('.rband').length, 6, 'G3: každé pásmo má riadok');
const html = box().innerHTML;
ok(html.indexOf('Pásma podľa šírky korpusu.') >= 0, 'G3: veta sa naozaj vykreslí');
eq(html.split('Pásma podľa šírky korpusu.').length - 1, 2,
   'G3: a to PRÁVE pri dvoch korpusových pravidlách (nie pri závesoch)');
ok(html.indexOf('so soklom od 55 mm') >= 0, 'G3: popis roly s prahom je v hlavičke');
ok(html.indexOf('novšej verzie') < 0, 'G3: žiadne pravidlo nespadlo do „needituje sa"');

// ============ G4: ROUND-TRIP — prah prežije zber aj uloženie =================
const back = R.rdCollectRules();
eq(back[1].applies_to.floor_height_min, 55,
   'G4: prah prežije zber (editor ho needituje, ale stratiť ho NESMIE)');
eq(back[1].bands, [{ max: 999, quantity: 1 }, { max: null, quantity: 2 }],
   'G4: aj pásma sa zbierajú nezmenené');
eq(back[0].params_from_context, { height: 'floor_height' },
   'G4: a `params_from_context` nôh tiež (set podľa nej vyberá kód)');
SENT.length = 0;
R.rdSaveRules();
eq(SENT.length, 1, 'G4: formulár sa dá uložiť');
eq(SENT[0].rules[1].applies_to.floor_height_min, 55,
   'G4: a na server odchádza AJ s prahom');

console.log('KOV-G1b editor nôh: ' + n + ' assertov OK');
