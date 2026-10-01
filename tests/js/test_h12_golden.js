// H12 · T0 (R0.4) — CHARAKTERIZACNY ODTLACOK JS pred H12c (package
// `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H12.md`, cast H12c).
//   node tests/js/test_h12_golden.js
//
// H12c prepisuje JS Inspectora a Studia z vlastnych zoznamov a porovnani mena
// typu skrinky na register zo servera (`cabinet_types` v `NX.init`, `type_word`
// sablony, `type_scope` pravidla). Tento test zachytil spravanie NEZMENENEHO
// kodu (prvy commit H12c) a po refaktore musi dat BAJTOVO ten isty JSON:
//   * Inspector nad 7 vstupmi (`lower upper dishwasher corner_blind tall`,
//     chybajuci typ, `''`) — vkladacia karta (typ, ponuka sablon, viditelnost
//     riadkov, nohy, navrh ciel, payload vkladu) aj OZNACENA skrinka (cesta
//     `NX.loadSelected` so SUROVYM typom: rail, riadky Zakladnych, karta ciel,
//     limity, validacia, modal „Uložiť ako šablónu", kresba),
//   * ciste funkcie s typom ako parametrom (symbol blendy, hlavicka, komin,
//     listy chrbta, otvor ciel, rohova, zony, nohy),
//   * Studio: slovo typu na dlazdici sablony, veta rozsahu pravidla kovania.
// Skripty bezia v JEDNOM `vm` kontexte v poradi HTML (ako CEF) — `h12_harness.js`.
// Register sa dorucuje TOU ISTOU cestou ako v CEF (`NX.init` s `cabinet_types`);
// stary kod kluc ignoroval, novy z neho cita.
//
// Generovanie (LEN na nezmenenom kode, nikdy pri refaktore):
//   NX_H12_WRITE=1 node tests/js/test_h12_golden.js
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const H = require('./h12_harness.js');

const FIX = path.join(H.ROOT, 'tests', 'fixtures', 'h12_golden', 'js.json');
const PANEL = JSON.parse(fs.readFileSync(path.join(H.ROOT, 'tests', 'fixtures', 'h12_golden', 'panel.json'), 'utf8'));
const SCOPE = JSON.parse(fs.readFileSync(path.join(H.ROOT, 'tests', 'fixtures', 'h12_golden', 'type_scope.json'), 'utf8'));
const REG = H.registry();

const INPUTS = ['lower', 'upper', 'dishwasher', 'corner_blind', 'tall', null, ''];
const KEY = function(t){ return t === null ? '(chyba)' : (t === '' ? "('')" : t); };

// Predvolby `NX.init` = dnesny `Panel.init_defaults` (golden H12b); rohova ma
// v nom stub, tu su jej predvolby vypisane (`CORNER_DEFAULTS` + strana + CR 2).
const DEFAULTS = JSON.parse(JSON.stringify(PANEL.init_defaults));
DEFAULTS.corner_blind = Object.assign({}, DEFAULTS.lower, {
  type: 'corner_blind', width: 1100, corner_side: 'left', corner_door_w: 450,
  corner_cr1: 80, corner_cr2: 80, corner_th2: 18
});

// Kniznica sablon vkladacej karty (vratane legacy zaznamu bez typu a neznameho typu).
const LIB = [
  { name: 'Dolna', kind: 'cabinet', config: { type: 'lower' } },
  { name: 'Bez typu', kind: 'cabinet', config: {} },
  { name: 'Horna', kind: 'cabinet', config: { type: 'upper' } },
  { name: 'Umyvacka 60', kind: 'cabinet', config: { type: 'dishwasher', dw_class: 600 } },
  { name: 'Rohova', kind: 'cabinet', config: { type: 'corner_blind' } },
  { name: 'Vysoka', kind: 'cabinet', config: { type: 'tall' } },
  { name: 'Prazdny typ', kind: 'cabinet', config: { type: '' } },
  { name: 'Doska', kind: 'board', config: { type: 'board' } }
];

// Slovo typu, ake server posiela v zazname sablony (`Panel.template_type_word`:
// `word` z registra, neznamy a chybajuci typ = dolna).
function serverWord(t){
  const hit = REG.find(function(r){ return r.id === t; }) || REG.find(function(r){ return r.id === 'lower'; });
  return hit.word;
}

const DISPLAY_IDS = ['plinthGroup', 'fhRow', 'thicknessRow', 'infAvWidth', 'infIntDepth', 'infAvHeight', 'infArea',
                     'topSetbackRow', 'backSetbackRow'];
const HIDDEN_IDS = ['cornerRow', 'dwClassRow', 'dwBodyRow', 'dwFrontBottomRow', 'infDwBody', 'infDwFront', 'infDwGap',
                    'infDwUnder', 'infDwClass', 'fr_gap', 'fr_gap_bottom', 'infCornerDoor', 'legsRow', 'frontAddTypes',
                    'frontOneDoor', 'cabBackNote', 'qs:details[data-key="zsplit"]'];
const TEXT_IDS = ['lblHeight', 'cabBackNote', 'inf_parts', 'inf_area', 'inf_weight'];

function boot(){
  const h = H.load();
  h.ctx.NX.init({ defaults: JSON.parse(JSON.stringify(DEFAULTS)), templates: JSON.parse(JSON.stringify(LIB)),
                  cabinet_types: JSON.parse(JSON.stringify(REG)), version: '0', model_guid: 'g' });
  return h;
}

function rows(h){
  const n = h.node;
  const out = { display: {}, hidden: {}, text: {} };
  DISPLAY_IDS.forEach(function(id){ out.display[id] = n(id).style.display === undefined ? null : n(id).style.display; });
  HIDDEN_IDS.forEach(function(id){ out.hidden[id] = !!n(id).hidden; });
  TEXT_IDS.forEach(function(id){ out.text[id] = String(n(id).textContent || ''); });
  return out;
}

function draft(h){
  const d = h.ctx.nxFrontDraftData();
  delete d.insert_session; // pocitadlo relacie (rastie s kazdym resetom)
  return d;
}

// Modal „Uložiť ako šablónu": select typu (4 volby ako v panel.html) a ocakavania.
function tplModal(h, t){
  const sel = h.node('tplSaveType');
  sel.options = ['lower', 'upper', 'corner_blind', 'dishwasher'].map(function(v){ return { value: v, hidden: false }; });
  h.ctx.nxSyncTplSaveType(t);
  h.ctx.nxSyncTplSaveExpects(t);
  const tip = h.node('tplSaveTypeTip');
  return {
    value: sel.value, disabled: !!sel.disabled, title: sel.title,
    hiddenOptions: sel.options.filter(function(o){ return o.hidden; }).map(function(o){ return o.value; }),
    tipHidden: !!tip.hidden, tip: tip.getAttribute('data-tip'),
    expectsRowHidden: !!h.node('tplSaveExpectsRow').hidden, expectsSlotHidden: !!h.node('tplSaveExpectsSlot').hidden,
    expectsValue: h.ctx.nxTplSaveExpectsValue(t)
  };
}

// Validacia: polia slotu a rohovej s neplatnou hodnotou + sirka 250 (korpus OK, slot nie).
function validation(h){
  const vals = { width: '250', dw_body_height: '5', dw_front_bottom: '900', corner_door_w: '5', corner_cr1: '5', corner_cr2: '5' };
  Object.keys(vals).forEach(function(id){ h.node(id).value = vals[id]; h.node(id).classList.remove('bad'); });
  const ok = h.ctx.validateFields(true);
  const bad = Object.keys(vals).filter(function(id){ return h.node(id).classList.contains('bad'); });
  Object.keys(vals).forEach(function(id){ h.node(id).value = ''; h.node(id).classList.remove('bad'); h.node(id).title = ''; });
  return { ok: ok, bad: bad };
}

function markHeight(h){
  ['height', 'floor_height', 'dw_front_bottom'].forEach(function(id){ h.node(id).title = ''; });
  h.ctx.markHeightError('X');
  return ['height', 'floor_height', 'dw_front_bottom'].filter(function(id){ return h.node(id).title === 'X'; });
}

function common(h, t){
  const c = h.ctx;
  return {
    getType: c.getType(),
    cabInfoType: c.nxCabInfo({ type: t, parts_count: 6, parts_area_m2: 1.5 }).type,
    carcass: (function(){ const k = c.currentCarcass(); return { floor_height: k.floor_height, type: k.type }; })(),
    limits: ['width', 'height', 'depth'].map(function(id){ return c.limitFor(id); }),
    construction: Object.keys(c.collectConstruction()).filter(function(k){ return /^(corner_|dw_)/.test(k); }),
    symbolBlindCur: c.frontTypeSymbol('blind', c.getType()),
    rowLabelBlind: c.frontRowLabel('blind'), rowIconBlind: c.frontRowIcon('blind'),
    cornerSide: c.nxCornerSide(), cornerCardSide: c.nxCornerCardSide(),
    pvSlot: c.pvSlot() !== null, floorH: c.nxCabFloorHeight(), opening: c.pvFrontOpening(600),
    metaDims: c.nxMetaDims(),
    tplModal: tplModal(h, c.getType()),
    validation: validation(h),
    markHeight: markHeight(h),
    draft: draft(h),
    rows: rows(h)
  };
}

function insertCase(t){
  const h = boot();
  const c = h.ctx;
  const out = {
    forType: c.NXInsert.templatesForType(LIB, t).map(function(tp){ return tp.name; }),
    templateType: c.NXInsert.templateType({ config: t === null ? {} : { type: t } })
  };
  c.onInsertType(t);
  out.insertType = c.NXInsert.insertType();
  const p = c.nxInsertPayload();
  out.payload = { type: p.type, corner_side: p.corner_side === undefined ? null : p.corner_side,
                  floor_height: p.floor_height === undefined ? null : p.floor_height,
                  keys: Object.keys(p).filter(function(k){ return /^(corner_|dw_)/.test(k); }) };
  // Nohy vkladacej karty: dotaz na server pyta len typ na podlahe, horna a slot
  // dotaz v lete zneplatnia (generacia) — kluc dotazu a generacia to odlisia.
  out.legs = { key: c.legsLastKey, gen: c.legsGen };
  c.setInsertCabInfo();
  out.common = common(h, t);
  return out;
}

function selectedCase(t, i){
  const h = boot();
  const c = h.ctx;
  const cab = Object.assign({}, t === 'corner_blind' ? DEFAULTS.corner_blind
                                : (DEFAULTS[t] || DEFAULTS.lower), {
    cabinet_id: 'CAB-' + i, model_guid: 'g', fronts: { items: [] }, parts_count: 6, parts_area_m2: 1.5,
    corner_side: 'right', corner_th2: 19
  });
  if (t === null) delete cab.type; else cab.type = t;
  c.NX.loadSelected(cab);
  const out = {
    shellType: c.NXShell.cabType(),
    ctxLock: ['korpus', 'zony', 'cela', 'kovanie'].map(function(x){ return c.NXShell.ctxLockedBy(x); })
  };
  c.nxSlotFrontsLock();
  out.fronts = { addTypesHidden: !!h.node('frontAddTypes').hidden, oneDoorHidden: !!h.node('frontOneDoor').hidden };
  out.common = common(h, t);
  return out;
}

// Ciste funkcie s typom ako parametrom (bez stavu panela).
function pureCase(t){
  const c = boot().ctx;
  return {
    symbolBlind: c.frontTypeSymbol('blind', t), symbolLift: c.frontTypeSymbol('lift', t),
    cabInfo: c.nxCabInfo({ type: t }).type,
    setback: c.nxBackSetback({ type: t, back_setback: 50 }),
    rails: c.nxBackRails({ type: t, back_mode: 'rails' }),
    meta: c.setbackMetaTexts({ type: t, back_mode: 'rails', back_setback: 50, top_front_setback: 30 }),
    cornerDraft: c.nxCornerDraftOf({ type: t, corner_side: 'right', corner_th2: 19 }),
    opening: c.nxFrontOpeningFor(t, 600, { x0: 10, w: 400 }),
    ctxLock: ['korpus', 'zony', 'cela', 'kovanie'].map(function(x){ return c.NXShell.ctxLockedBy(x, t); }),
    legs: c.nxLegsTypeHasLegs(t),
    expects: c.nxTplSaveExpectsValue(t),
    templateType: c.NXInsert.templateType({ config: t === null ? {} : { type: t } })
  };
}

function studio(){
  const c = H.load({ page: 'studio.html' }).ctx;
  c.RD.init({ rules: JSON.parse(JSON.stringify(SCOPE.rules)), type_scope: JSON.parse(JSON.stringify(SCOPE.type_scope)) });
  const rules = SCOPE.rules.map(function(r){ return [r.rule_id, c.rdRoleDesc(r)]; });
  const tiles = INPUTS.map(function(t){
    const cfg = t === null ? {} : { type: t };
    const html = c.tplTileHtml({ name: 'S', kind: 'cabinet', config: cfg, type_word: serverWord(t) }, 'cabinet', 0);
    return [KEY(t), (html.match(/class="stplmeta">([^<]*)</) || [])[1] || null];
  });
  const board = c.tplTileHtml({ name: 'D', kind: 'board', config: { type: 'board' } }, 'board', 0);
  tiles.push(['board', (board.match(/class="stplmeta">([^<]*)</) || [])[1] || null]);
  return { rules: rules, tiles: tiles };
}

function snapshot(){
  const out = { inputs: INPUTS.map(KEY), insert: {}, selected: {}, pure: {} };
  INPUTS.forEach(function(t, i){
    out.insert[KEY(t)] = insertCase(t);
    out.selected[KEY(t)] = selectedCase(t, i);
    out.pure[KEY(t)] = pureCase(t);
  });
  out.studio = studio();
  return JSON.stringify(out, null, 1) + '\n';
}

const got = snapshot();
if (process.env.NX_H12_WRITE === '1'){
  fs.writeFileSync(FIX, got, 'utf8');
  console.log('test_h12_golden: fixtura zapisana ' + FIX);
} else {
  const want = fs.readFileSync(FIX, 'utf8').replace(/\r\n/g, '\n');
  if (got !== want){
    const g = JSON.parse(got), w = JSON.parse(want);
    // Presne miesto rozdielu (deepStrictEqual vypise cestu).
    assert.deepStrictEqual(g, w, 'H12 JS golden: spravanie sa zmenilo');
    assert.fail('H12 JS golden: JSON sa lisi formou (poradie klucov)');
  }
  const n = Object.keys(JSON.parse(want).insert).length;
  console.log('test_h12_golden: OK (' + n + ' vstupov × vklad/oznacena/ciste + Studio — bajtovo zhodne)');
}
