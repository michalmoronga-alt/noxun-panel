global.nxDocGuid = () => ''; // samostatna karta bez dokumentoveho bridge
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
global.frontLift = null;     // KOV-E2: zaznam vyklopu (front_lift) — form.js ho cita
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
// KOV-E2: pôvodná read-only VETA zanikla — jej rolu prevzal SÚHRN v lište
// editora (`.rgsum`). Kritérium ostáva to isté: pravidlo, ktoré sa nedá ani
// prečítať, vyzerá ako chyba, ktorú niekto zabudol zmazať.
const hint = md.textOf(box.querySelector('.rgsum'));
ok(md.textOf(box).indexOf('novšej verzie') < 0,
   'L2: kind, ktorý TÁTO verzia pozná, sa netvári ako z budúcnosti: ' + hint);
ok(hint.indexOf('HK 2 triedy') >= 0 && hint.indexOf('1 rameno') >= 0,
   'L2: súhrn menuje tabuľky: ' + hint);
ok(hint.indexOf('0.5 kg') >= 0 && hint.indexOf('1100 mm') >= 0,
   'L2: aj rezervu na úchytku a prah druhej tyče: ' + hint);
eq(box.querySelectorAll('.rbands').length, 0, 'L2: pásma závesov výklop nemá');
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
const bad = md.textOf(DOC.getElementById('rulesBox').querySelector('.rgsum'));
ok(bad.indexOf('HK 0 tried') >= 0 && bad.indexOf('0 ramien') >= 0,
   'L2: poškodený tvar sa prizná ako prázdny, nespadne: ' + bad);
ok(bad.indexOf('rezerva') < 0, 'L2: a nečíselná hodnota sa vôbec nevypíše');
eq(R.rdLiftSummary(null).indexOf('HK 0 tried') >= 0, true, 'L2: ani chýbajúce pravidlo nespadne');

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

// ============ L3 (Codex #333 kolo 1 P2): klientska VALIDÁCIA výklopu ========
//
// Sekcia ukladá VŠETKY pravidlá naraz, takže pokazené výklopové pravidlo
// (starší/cudzí snapshot) musí zastaviť klient — inak ho pustí a server
// zamietne, pričom read-only tabuľku tu niet ako opraviť. Kritériá sú tie
// isté ako serverové `HardwareRules.lift_problem`; spoločný kontrakt je
// `tests/fixtures/rules_validation_parity.json` (beží v test_st3b_rules).
ok(R.rdValidate([liftRule({ classes: [] })]) !== null, 'L3: prázdne triedy HK klient odmietne');
ok(R.rdValidate([liftRule({ mechanisms: [] })]) !== null, 'L3: prázdne mechanizmy HL');
ok(R.rdValidate([liftRule({ arms: [] })]) !== null, 'L3: prázdne ramená HL');
ok(R.rdValidate([liftRule({ classes: [{ code: '22K2300', min: 1610, max: 420 }] })]) !== null,
   'L3: obrátený rozsah triedy');
ok(R.rdValidate([liftRule({
  arms: [{ code: '22L3200', kh_min: 300, kh_max: 340, kg_min: 1.5, kg_max: 9 },
         { code: '22L3500', kh_min: 360, kh_max: 390, kg_min: 1.75, kg_max: 10 }]
})]) !== null, 'L3: MEDZERA medzi pásmami ramien (výška 340–360 by nedostala nič)');
ok(R.rdValidate([liftRule({ handle_allowance_kg: -0.5 })]) !== null,
   'L3: záporná rezerva na úchytku by vybrala slabší mechanizmus');
ok(R.rdValidate([liftRule({ arms: [{ code: '', kh_min: 300, kh_max: 340, kg_min: 1.5, kg_max: 9 }] })]) !== null,
   'L3: riadok bez kódu server zahodí — klient ho tiež nesmie počítať');
eq(R.rdValidate([liftRule({ enabled: false, classes: [], arms: [], mechanisms: [] })]), null,
   'L3: pokazené pravidlo sa DÁ VYPNÚŤ (vypnuté sa nekontroluje)');
const lmsg = R.rdValidate([liftRule({ classes: [] })]);
ok(/Výklop/.test(lmsg), 'L3: hláška menuje pravidlo: ' + lmsg);

// ============ L4 (Codex #333 kolo 1 P2): karta čela už NEKLAME ==============
//
// Text „mechanizmus sa pridáva ručne — automatika príde s KOV-E" bol pravdivý
// do E1a. Od aktivácie pravidiel by viedol k ručnej položke NAVYŠE, teda
// k dvojitej objednávke.
function infoText(type){
  return C.frontCardModel({ type: type }, { wings: 1, slots: [] }).rows
    .filter(function(r){ return r.kind === 'info'; })
    .map(function(r){ return r.text; }).join(' | ');
}
const liftTxt = infoText('lift');
const fallTxt = infoText('fall');
ok(liftTxt.indexOf('KOV-E') < 0 && liftTxt.indexOf('ručne') < 0,
   'L4: výklop už netvrdí, že sa mechanizmus pridáva ručne: ' + liftTxt);
ok(liftTxt.indexOf('automat') >= 0 && liftTxt.indexOf('hmotnosti') >= 0,
   'L4: povie, podľa čoho automat vyberá: ' + liftTxt);
ok(fallTxt.indexOf('závesy') >= 0 && fallTxt.indexOf('KOV-E') < 0,
   'L4: sklop dostane závesy ako dvierka: ' + fallTxt);
ok(liftTxt.split(' | ').length === 1 && fallTxt.split(' | ').length === 1,
   'L4: jeden riadok (vertikálny priestor panela je vzácny)');

console.log('KOV-E1b klientska cast: ' + n + ' assertov OK');
