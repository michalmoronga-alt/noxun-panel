// H12c — JS Inspectora a Studia cita TYPY SKRINKY zo servera (package
// `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H12.md`, cast H12c, §15 A1).
//   node tests/js/test_h12c_typy.js
//
// Co sa tu strazi (spravanie pred/po strazi golden `test_h12_golden.js`):
//   T1  register `NXTypes` (core.js): API nad zmluvnou fixturou, neznamy typ =
//       dolna, NEUTRALNY profil pred dorucenim = profil dolnej, zly payload,
//   A1  skripty nacitane PRED dorucenim registra (ako v CEF pred
//       `sketchup.ready()`), potom `NX.init` a prepnutie VSETKYCH typov —
//       Horna, Umyvacka ani Rohova nesmu skoncit ako dolna; pred registrom
//       nebliká zle UI (riadky dolnej),
//   M15 `NX.init` nasadi register PRED oznacenim (`loadSelected`),
//   T2  matica miest, kde sa dve „podlahove" mnoziny lisia (len horna vs
//       horna alebo slot) — nad poliami, ktore golden drzi na nule,
//   R3.4 Studio: veta rozsahu pravidla z pola servera PO RIADKOCH (plny push, „Načítať
//       globálne", lacne echo ju neprepise), slovo typu dlazdice zo servera.
'use strict';
const assert = require('node:assert');
const H = require('./h12_harness.js');

const REG = H.registry();
const INPUTS = ['lower', 'upper', 'dishwasher', 'corner_blind', 'tall', null, undefined, ''];
const KNOWN = ['lower', 'upper', 'dishwasher', 'corner_blind'];

let n = 0;
// Hodnoty z `vm` kontextu maju cudzi prototyp Array/Object — porovnava sa JSON tvar.
function plain(x){ return x === undefined ? undefined : JSON.parse(JSON.stringify(x)); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(plain(a), plain(b), msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const DEFAULTS = {
  lower: { type: 'lower', width: 600, height: 720, depth: 510, thickness: 18, floor_height: 100 },
  upper: { type: 'upper', width: 600, height: 720, depth: 320, thickness: 18, floor_height: 0 },
  dishwasher: { type: 'dishwasher', width: 600, height: 880, depth: 560, thickness: 18, floor_height: 0,
                dw_class: 600, dw_body_height: 820, dw_front_bottom: 100 },
  corner_blind: { type: 'corner_blind', width: 1100, height: 720, depth: 510, thickness: 18, floor_height: 100,
                  corner_side: 'left', corner_door_w: 450, corner_cr1: 80, corner_cr2: 80, corner_th2: 18 }
};
function initData(extra){
  return Object.assign({ defaults: JSON.parse(JSON.stringify(DEFAULTS)), templates: [],
                         cabinet_types: JSON.parse(JSON.stringify(REG)), version: '0', model_guid: 'g' }, extra || {});
}

// ============ T1) REGISTER nad zmluvnou fixturou ==============================
{
  const T = H.load().ctx.NXTypes;
  // Pred dorucenim: prazdny register, kazdy typ = dolna, NEUTRALNY profil.
  eq(T.ids(), [], 'pred NX.init register nepozna ziaden typ');
  eq(['upper', 'dishwasher', 'corner_blind', 'tall'].map(T.norm), ['lower', 'lower', 'lower', 'lower'],
     'pred NX.init je kazdy typ dolna (dnesne spravanie do initu)');
  const low = REG.find(r => r.id === 'lower');
  // R1.3: neutralny profil = vlastnosti dolnej (bez bliknutia zleho UI).
  ['builder', 'on_floor', 'limits', 'appliance_owner', 'fronts', 'front_opening', 'zones', 'zones_reason',
   'template_type', 'template_lock', 'type_locked', 'assembly'].forEach(function(k){
    eq(T.get('dishwasher')[k], low[k], `neutralny profil ${k} = dolna`);
  });
  eq(Number(T.get('upper').hang_z), 0, 'neutralny profil nevisi');
  eq([T.hangs('upper'), T.onFloor('upper'), T.carcass('dishwasher'), T.corner('corner_blind')],
     [false, true, true, false], 'predikaty pred initom = dolna');
  eq(T.label('upper'), '', 'pred initom ziaden nazov (nic ho este neukazuje)');

  T.set(REG);
  eq(T.ids(), KNOWN, 'poradie = Ruby IDS');
  eq(INPUTS.map(T.known), [true, true, true, true, false, false, false, false], 'known: len retazec z registra');
  eq(INPUTS.map(T.norm), ['lower', 'upper', 'dishwasher', 'corner_blind', 'lower', 'lower', 'lower', 'lower'],
     'norm: neznamy, chybajuci aj prazdny = dolna (Ruby CabinetTypes.norm)');
  eq(T.norm(5), 'lower', 'neretazec = dolna');
  eq(T.norm('constructor'), 'lower', 'meno z prototypu objektu nie je typ');
  eq(KNOWN.map(T.label), ['Dolná', 'Horná', 'Umývačka', 'Rohová'], 'label');
  eq(T.label('tall'), 'Dolná', 'neznamy typ = nazov dolnej');
  // Dve podlahove mnoziny (package §0.4) a ostatne vlastnosti.
  const set = pred => INPUTS.filter(t => pred(t)).map(String);
  eq(set(T.hangs), ['upper'], 'visi LEN horna');
  eq(set(t => !T.onFloor(t)), ['upper', 'dishwasher'], 'nestoji na podlahe: horna a slot');
  eq(set(t => !T.carcass(t)), ['dishwasher'], 'bez korpusu: slot');
  eq(set(T.corner), ['corner_blind'], 'rohova zostava');
  eq(T.idsWhere('template_type', 'locked'), ['dishwasher', 'corner_blind'], 'zamknuty typ sablony');
  eq(T.idsWhere('appliance_owner', 'slot'), ['dishwasher'], 'vlastnik spotrebica');
  ok(T.has('dishwasher', 'fronts', 'slot_fixed') && T.has('corner_blind', 'fronts', 'corner_one_door'), 'pravidlo ciel');
  eq(T.get('dishwasher').limits, { width: [300, 1200], height: [500, 1200] }, 'rozsahy slotu');
  // Zly payload: zaznam bez id, duplicita, nie-pole — register sa nerozbije.
  T.set([{ id: 'upper', label: 'X', hang_z: 1 }, { label: 'bez id' }, null, { id: 'upper', label: 'Y' }, { id: '' }]);
  eq(T.ids(), ['upper'], 'zaznam bez id a duplicita sa zahodia');
  eq(T.label('upper'), 'X', 'prvy vyhrava');
  eq(T.norm('lower'), 'lower', 'FALLBACK ostava aj ked ho register nema');
  eq(T.get('lower').on_floor, true, 'chybajuca dolna = neutralny profil');
  T.set(undefined);
  eq(T.ids(), [], 'payload bez kluca = prazdny register');
  eq(T.FALLBACK, 'lower', 'jedina zostavajuca konstanta typu');
}

// ============ A1) SKRIPTY PRED REGISTROM, POTOM NX.init =======================
{
  const h = H.load();
  const c = h.ctx;
  // Stav CEF po `window.onload`, pred `sketchup.ready()`: vsetko je nacitane,
  // register prazdny. Kazde prepnutie je zatial dolna — a riadky su dolnej
  // (ziadne bliknutie zleho UI: sokel viditelny, riadky slotu a rohovej skryte).
  c.setType('upper');
  eq(c.getType(), 'lower', 'pred registrom horna = dolna');
  eq(c.NXInsert.setInsertType('dishwasher'), false, 'pred registrom slot nezmeni stav (je to dolna)');
  c.applyVisibility('dishwasher');
  eq([h.node('plinthGroup').style.display, h.node('cornerRow').hidden, h.node('dwClassRow').hidden],
     ['', true, true], 'pred registrom ziadne riadky slotu ani rohovej');
  eq(c.NXShell.ctxLockedBy('zony', 'dishwasher'), '', 'pred registrom Zony nezamknute');
  eq(c.NXInsert.insertTypes(), ['board'], 'pred registrom vkladanie pozna len dosku');

  // Dorucenie registra TOU ISTOU cestou ako v CEF.
  c.NX.init(initData());
  eq(c.NXInsert.insertTypes(), KNOWN.concat(['board']), 'po NX.init: vsetky typy + doska (A1 — nic sa nepamata z nacitania)');
  const seen = [];
  ['upper', 'dishwasher', 'corner_blind', 'lower'].forEach(function(t){
    c.onInsertType(t);
    seen.push([c.NXInsert.insertType(), c.getType()]);
  });
  eq(seen, [['upper', 'upper'], ['dishwasher', 'dishwasher'], ['corner_blind', 'corner_blind'], ['lower', 'lower']],
     'vkladacia karta: Horna, Umyvacka, Rohova NESKONCIA ako dolna');
  c.onInsertType('upper');
  eq(h.node('plinthGroup').style.display, 'none', 'horna: sokel skryty');
  c.onInsertType('dishwasher');
  eq([h.node('dwClassRow').hidden, h.node('plinthGroup').style.display], [false, 'none'], 'slot: riadky slotu');
  c.onInsertType('corner_blind');
  eq(h.node('cornerRow').hidden, false, 'rohova: riadok rohovej');
  // Oznacena skrinka (surovy typ z payloadu).
  const picked = KNOWN.map(function(t, i){
    c.NX.loadSelected(Object.assign({}, DEFAULTS[t], { cabinet_id: 'C' + i, model_guid: 'g', fronts: { items: [] } }));
    return [c.getType(), c.NXShell.cabType(), c.NXShell.ctxLockedBy('zony')];
  });
  eq(picked, [['lower', 'lower', ''], ['upper', 'upper', ''], ['dishwasher', 'dishwasher', 'slot umývačky zóny nemá'],
              ['corner_blind', 'corner_blind', '']], 'oznacena skrinka drzi svoj typ (rail aj panel)');
}

// ============ M15) NX.init nasadi register PRED oznacenim ======================
{
  const h = H.load();
  h.ctx.NX.init(initData({ selected: Object.assign({}, DEFAULTS.upper, { cabinet_id: 'C9', model_guid: 'g',
                                                                         fronts: { items: [] } }) }));
  eq(h.ctx.getType(), 'upper', 'skrinka oznacena pri otvoreni panela je horna (nie dolna)');
  eq(h.node('plinthGroup').style.display, 'none', 'a hned bez sokla');
}

// ============ T2) MATICA: dve podlahove mnoziny nad nenulovym soklom ===========
// Golden drzi pole sokla na predvolbe typu (slot 0) — tu je v poli 150, takze
// „len horna" (`hangs`) a „horna alebo slot" (`!onFloor`) sa daju rozlisit.
{
  const h = H.load();
  const c = h.ctx;
  c.NX.init(initData());
  const rows = INPUTS.filter(t => t !== undefined).map(function(t){
    c.setType(t);
    h.node('floor_height').value = '150';
    h.node('height').value = '720';
    return [String(t), c.currentCarcass().floor_height, c.nxFrontDraftData().floor_height, c.nxCabFloorHeight()];
  });
  eq(rows, [
    ['lower', 150, 150, 150], ['upper', 0, 0, 0], ['dishwasher', 150, 0, 0], ['corner_blind', 150, 150, 150],
    ['tall', 150, 150, 150], ['null', 150, 150, 150], ['', 150, 150, 150]
  ], 'currentCarcass: sokel 0 LEN pri hornej; navrh ciel a kresba: 0 aj pri slote');
}

// ============ R3.4) STUDIO: vety a slova zo servera ===========================
{
  const c = H.load({ page: 'studio.html' }).ctx;
  // Predrecenzia P3: dva riadky s ROVNAKYM `rule_id` (a jeden bez id) — veta
  // ide PODLA POZICIE riadku, nie podla id.
  const rules = [{ rule_id: 'a', applies_to: { role: 'cabinet', cabinet_type: ['upper'] } },
                 { rule_id: 'a', applies_to: { role: 'cabinet', cabinet_type: ['lower'] } },
                 { applies_to: { role: 'cabinet', cabinet_type: ['upper'] } }];
  const desc = () => rules.map((_r, i) => c.rdRuleDesc(i));
  c.RD.init({ rules: rules, type_scope: ['na hornú skrinku', null, 'na hornú skrinku'] });
  eq(desc(), ['na hornú skrinku', 'na každú skrinku', 'na hornú skrinku'], 'veta len z pola servera, po riadkoch');
  // „Načítať globálne": server posle pole nad globalnymi pravidlami.
  c.RD.setTypeScope(['na hornú skrinku', 'na spodnú skrinku', null]);
  eq(desc(), ['na hornú skrinku', 'na spodnú skrinku', 'na každú skrinku'],
     'setTypeScope prepise pole; rovnake rule_id nezmiesa vety');
  // Lacne echo s pravidlami, ktorymi bol formular naplneny, pole NEPREPISE
  // (formular moze ukazovat global, ktory este neplati).
  c.RD.setSection({ rules: rules, type_scope: ['na hornú skrinku', null, null] });
  eq(c.rdRuleDesc(1), 'na spodnú skrinku', 'echo nad tymi istymi pravidlami vetu globalu nezhodi');
  // Plne naplnenie formulara (force) pole nahradi.
  c.RD.setSection({ rules: rules, type_scope: [] }, true);
  eq(c.rdRuleDesc(0), 'na každú skrinku', 'force = pole noveho naplnenia');
  c.RD.init({ rules: rules, type_scope: { 0: 'zle' } });
  eq(c.rdRuleDesc(0), 'na každú skrinku', 'zly tvar (nie pole) = ziadna veta (nie vynimka)');
  // Dlazdica sablony: slovo typu zo servera, okno ho neprekladá.
  const meta = tp => (c.tplTileHtml(tp, 'cabinet', 0).match(/class="stplmeta">([^<]*)</) || [])[1];
  eq(meta({ name: 'X', kind: 'cabinet', config: { type: 'upper' }, type_word: 'horná' }), 'horná', 'type_word zo servera');
  eq(meta({ name: 'X', kind: 'cabinet', config: { type: 'upper' } }), '', 'bez slova servera ziadny preklad v okne');
}

console.log(`test_h12c_typy.js: ${n} kontrol OK`);
