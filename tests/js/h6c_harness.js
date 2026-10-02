// H6c — spolocny harness kot nahladu (generator goldenu + test_h6c_koty.js).
// Nacita core.js + preview.js do vm, vykresli 14 pripadov (Korpus, Cela, Zony,
// Kovanie, doska, chladnicka) a vrati <text> prvky aj ich obdlzniky.
//   node tests/fixtures/h6c_koty/generate.js   (golden len nad STARYM kodom)
'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const JS = process.env.H6C_JS_DIR || path.join(ROOT, 'noxun_engine', 'ui', 'js'); // generator goldenu: H6C_JS_DIR = kopia STAREHO kodu
const TYPES = require('./nx_types_fixture.js');

function plain(v){ return (v && typeof v === 'object') ? JSON.parse(JSON.stringify(v)) : v; }

function fakeEl(rect){
  const a = {};
  const cls = new Set();
  return {
    attrs: a, hidden: false, disabled: false, title: '', value: '', innerHTML: '', textContent: '', style: {}, dataset: {},
    rect: rect || null,
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k) ? a[k] : null; },
    setAttribute(k, v){ a[k] = String(v); }, removeAttribute(k){ delete a[k]; },
    getBoundingClientRect(){
      const r = this.rect;
      return r ? { left: 0, top: 0, right: r.w, bottom: r.h, width: r.w, height: r.h } : { left: 0, top: 0, right: 0, bottom: 0, width: 0, height: 0 };
    },
    querySelector(){ return null; }, querySelectorAll(){ return []; }, closest(){ return null; }, addEventListener(){},
    classList: { add(c){ cls.add(c); }, remove(c){ cls.delete(c); }, contains(c){ return cls.has(c); },
                 toggle(c, on){ if (on === undefined ? !cls.has(c) : on) cls.add(c); else cls.delete(c); } }
  };
}

// Kresba servera pre rohovu 1100 x 720 (zhodna s test_rohb2_nahlad.js).
const CP_L = { side: 'left', fits: true, need: 584, door_w: 446,
  parts: [{ role: 'corner_blind_panel', x0: 450, x1: 1082, z0: 118, z1: 702, title: 'b' },
          { role: 'corner_rail', x0: 548, x1: 566, z0: 100, z1: 720, title: 'v' },
          { role: 'cr_front', x0: 452, x1: 530, z0: 102, z1: 718, title: 'c1' },
          { role: 'cr_side', x0: 530, x1: 548, z0: 102, z1: 718, title: 'c2' }],
  dims: [{ x0: 0, x1: 450, label: '450' }, { x0: 450, x1: 530, label: '80' }], stats: { count: 5, area: 0.584 } };
const CP_R = { side: 'right', fits: true, need: 584, door_w: 446,
  parts: [{ role: 'corner_blind_panel', x0: 18, x1: 650, z0: 118, z1: 702, title: 'b' },
          { role: 'corner_rail', x0: 534, x1: 552, z0: 100, z1: 720, title: 'v' },
          { role: 'cr_front', x0: 570, x1: 648, z0: 102, z1: 718, title: 'c1' },
          { role: 'cr_side', x0: 552, x1: 570, z0: 102, z1: 718, title: 'c2' }],
  dims: [{ x0: 650, x1: 1100, label: '450' }, { x0: 570, x1: 650, label: '80' }], stats: { count: 5, area: 0.584 } };
const BEKO = {
  item_id: 'I-1', label: 'Chladnička', state: 'ok',
  box: { x: 20, z: 118, w: 560, h: 1940 },
  bands: [{ z0: 118, z1: 158, size: 40 }, { z0: 158, z1: 787, size: 629 },
          { z0: 787, z1: 858, size: 71 }, { z0: 858, z1: 2058, size: 1200 }],
  split: { state: 'ok', lo: 797, hi: 845, edge: 813, recommended: 821, lo_mm: 679, hi_mm: 727, edge_mm: 695 }
};

const BASE = { thickness: 18, floor_height: 100, fr_gap_left: 2, fr_gap_right: 2, fr_gap: 3, fr_gap_top: 2,
               top_mode: 'full', back_mode: 'overlay', depth: 520 };

function leafZones(cols, W, H, t, fh){
  // jednoduchy strom: koren (v-delenie) + listy so zadanymi policami
  const inner = W - 2 * t - (cols.length - 1) * t;
  const sum = cols.reduce((s, c) => s + c.w, 0);
  const out = [{ id: 'Z1', leaf: false, split: { axis: 'v', count: cols.length, sizes: cols.map(c => c.w * inner / sum) },
                 x: t, z: fh + t, w: W - 2 * t, h: H - fh - 2 * t, shelves: 0 }];
  let x = t;
  cols.forEach((c, i) => {
    const w = c.w * inner / sum;
    out.push({ id: 'Z1.' + (i + 1), leaf: true, x: x, z: fh + t, w: w, h: H - fh - 2 * t, shelves: c.shelves || 0 });
    x += w + t;
  });
  return out;
}

const CASES = [
  { id: 'cab_lower', mode: 'cab', type: 'lower', fields: { width: 800, height: 864, depth: 520 } },
  { id: 'cab_upper', mode: 'cab', type: 'upper', fields: { width: 800, height: 720, depth: 350, floor_height: 0 } },
  { id: 'cab_tall', mode: 'cab', type: 'lower', fields: { width: 600, height: 2100, depth: 560 } },
  { id: 'cab_corner_left', mode: 'cab', type: 'corner_blind', fields: { width: 1100, height: 720, depth: 510 },
    cp: CP_L, opening: { x0: 0, w: 450, z0: 100, h: 620 },
    items: [{ id: 'F1', type: 'door', mode: 'auto', z: 102, height: 616, wings_n: 1, profile: 'none', direction: 'right' }] },
  { id: 'cab_corner_right', mode: 'cab', type: 'corner_blind', fields: { width: 1100, height: 720, depth: 510 },
    cp: CP_R, opening: { x0: 650, w: 450, z0: 100, h: 620 },
    items: [{ id: 'F1', type: 'door', mode: 'auto', z: 102, height: 616, wings_n: 1, profile: 'none', direction: 'left' }] },
  { id: 'cab_dishwasher', mode: 'cab', type: 'dishwasher',
    fields: { width: 600, height: 930, depth: 560, dw_class: '600', dw_body_height: 820, dw_front_bottom: 64, floor_height: 0 } },
  { id: 'fronts_lower_drawer', mode: 'fronts', type: 'lower', fields: { width: 800, height: 864, depth: 520 },
    items: [{ id: 'F1', type: 'drawer_front', mode: 'fixed', z: 102, height: 760, wings_n: 1, profile: 'none' }] },
  { id: 'fronts_tall', mode: 'fronts', type: 'lower', fields: { width: 600, height: 2100, depth: 560 },
    items: [{ id: 'F1', type: 'door', mode: 'fixed', z: 102, height: 1400, wings_n: 1, profile: 'none' },
            { id: 'F2', type: 'door', mode: 'auto', z: 1505, height: 593, wings_n: 1, profile: 'none' }] },
  { id: 'fronts_presah', mode: 'fronts', type: 'lower', fields: { width: 800, height: 864, depth: 520 },
    items: [{ id: 'F1', type: 'drawer_front', mode: 'fixed', z: -20, height: 120, wings_n: 1, profile: 'none' },
            { id: 'F3', type: 'none', mode: 'fixed', z: 103, height: 60, wings_n: 1, profile: 'none' },
            { id: 'F2', type: 'door', mode: 'auto', z: 166, height: 696, wings_n: 2, profile: 'none' }] },
  { id: 'zones_4', mode: 'zones', type: 'lower', fields: { width: 800, height: 864, depth: 520 },
    zones: leafZones([{ w: 1, shelves: 2 }, { w: 1, shelves: 1 }, { w: 1, shelves: 0 }, { w: 1, shelves: 3 }], 800, 864, 18, 100) },
  { id: 'hw_lower', mode: 'hw', type: 'lower', fields: { width: 800, height: 864, depth: 520 },
    items: [{ id: 'F1', type: 'drawer_front', mode: 'fixed', z: 102, height: 180, wings_n: 1, profile: 'none' },
            { id: 'F2', type: 'door', mode: 'auto', z: 285, height: 577, wings_n: 2, profile: 'none' }],
    hw: [{ owner_part_key: 'front:F2/wing:left', generic_type: 'hinge', quantity: 2, label: 'Záves' },
         { owner_part_key: 'front:F2/wing:right', generic_type: 'hinge', quantity: 2, label: 'Záves' },
         { owner_part_key: 'front:F1/panel', generic_type: 'slide', quantity: 1, label: 'Výsuv' },
         { owner_part_key: 'cabinet:leg', generic_type: 'leg', quantity: 4, label: 'Nohy' }] },
  { id: 'insert_board', mode: 'insert', type: 'lower', board: true,
    fields: { ib_length: 2600, ib_width: 600, ib_grain: 'length' } },
  { id: 'insert_board_nograin', mode: 'insert', type: 'lower', board: true,
    fields: { ib_length: 800, ib_width: 400, ib_grain: 'none' } },
  { id: 'cab_fridge', mode: 'cab', type: 'lower', fields: { width: 600, height: 2076, depth: 560 }, appl: [BEKO] }
];

// Dalsie pripady (NIE su v goldene - ide o rozlozenia z review PR #455): tesne susedne kóty
// pri malom okne, vysoka rohova s uzkou dverovou castou a CR 1, platne male/dlhe dosky.
const CP_TALL = { side: 'left', fits: true, need: 584, door_w: 246,
  parts: [{ role: 'corner_blind_panel', x0: 250, x1: 582, z0: 118, z1: 2082, title: 'b' },
          { role: 'corner_rail', x0: 348, x1: 366, z0: 100, z1: 2100, title: 'v' },
          { role: 'cr_front', x0: 252, x1: 300, z0: 102, z1: 2098, title: 'c1' },
          { role: 'cr_side', x0: 300, x1: 318, z0: 102, z1: 2098, title: 'c2' }],
  dims: [{ x0: 0, x1: 250, label: '250' }, { x0: 250, x1: 300, label: '50' }], stats: { count: 5, area: 0.584 } };
const EXTRA_CASES = [
  { id: 'zones_4_tall', mode: 'zones', type: 'lower', fields: { width: 600, height: 2100, depth: 560 },
    zones: leafZones([{ w: 1, shelves: 4 }, { w: 1, shelves: 4 }, { w: 1, shelves: 4 }, { w: 1, shelves: 4 }], 600, 2100, 18, 100) },
  { id: 'zones_8_wide', mode: 'zones', type: 'lower', fields: { width: 800, height: 864, depth: 520 },
    zones: leafZones([1, 2, 3, 4, 5, 6, 7, 8].map(() => ({ w: 1 })), 800, 864, 18, 100) },
  // spodny rad jedna zona na celu sirku (564), horny rad tri stlpce (176): stred „564" a stredneho „176" je na tom istom mieste
  { id: 'zones_overlap_rows', mode: 'zones', type: 'lower', fields: { width: 600, height: 864, depth: 520 },
    zones: [{ id: 'Z1', leaf: false, split: { axis: 'h', count: 2, sizes: [300, 400] }, x: 18, z: 118, w: 564, h: 728, shelves: 0 },
            { id: 'Z1.1', leaf: true, x: 18, z: 118, w: 564, h: 300, shelves: 0 },
            { id: 'Z1.2', leaf: false, split: { axis: 'v', count: 3, sizes: [176, 176, 176] }, x: 18, z: 436, w: 564, h: 410, shelves: 0 },
            { id: 'Z1.2.1', leaf: true, x: 18, z: 436, w: 176, h: 410, shelves: 0 },
            { id: 'Z1.2.2', leaf: true, x: 212, z: 436, w: 176, h: 410, shelves: 0 },
            { id: 'Z1.2.3', leaf: true, x: 406, z: 436, w: 176, h: 410, shelves: 0 }] },
  { id: 'cab_corner_tall', mode: 'cab', type: 'corner_blind', fields: { width: 600, height: 2100, depth: 510 },
    cp: CP_TALL, opening: { x0: 0, w: 250, z0: 100, h: 2000 },
    items: [{ id: 'F1', type: 'door', mode: 'auto', z: 102, height: 1996, wings_n: 1, profile: 'none', direction: 'right' }] },
  { id: 'board_10x10', mode: 'insert', type: 'lower', board: true, fields: { ib_length: 10, ib_width: 10, ib_grain: 'length' } },
  { id: 'board_10x600', mode: 'insert', type: 'lower', board: true, fields: { ib_length: 10, ib_width: 600, ib_grain: 'width' } },
  { id: 'board_2600x10', mode: 'insert', type: 'lower', board: true, fields: { ib_length: 2600, ib_width: 10, ib_grain: 'length' } },
  { id: 'board_10x600_nograin', mode: 'insert', type: 'lower', board: true, fields: { ib_length: 10, ib_width: 600, ib_grain: 'none' } },
  { id: 'board_300x300', mode: 'insert', type: 'lower', board: true, fields: { ib_length: 300, ib_width: 300, ib_grain: 'none' } },
  { id: 'board_2800x2070', mode: 'insert', type: 'lower', board: true, fields: { ib_length: 2800, ib_width: 2070, ib_grain: 'width' } }
];

function makeCtx(){
  const svg = fakeEl();
  const byId = { preview: svg };
  const ctx = { console, setTimeout, clearTimeout, window: {}, JSON, Math };
  ctx.document = { getElementById: id => byId[id] || null, querySelectorAll: () => [], querySelector: () => null,
                   addEventListener(){}, removeEventListener(){}, body: { appendChild(){}, setAttribute(){} }, createElement: () => fakeEl() };
  ctx.el = id => byId[id] || null;
  vm.createContext(ctx);
  ['core.js', 'preview.js'].forEach(f => {
    vm.runInContext(fs.readFileSync(path.join(JS, f), 'utf8'), ctx, { filename: f });
    if (f === 'core.js') TYPES.fill(ctx);
  });
  ctx.__svg = svg;
  ctx.__fields = {};
  ctx.numv = id => (ctx.__fields[id] === undefined ? NaN : parseFloat(ctx.__fields[id]));
  ctx.val = id => (ctx.__fields[id] === undefined ? '' : String(ctx.__fields[id]));
  ctx.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  ctx.NXIcons = { svg: id => '<svg><use href="#i-' + id + '"/></svg>', set(){} };
  ctx.clearFrontHover = () => {};
  ctx.fullZoneId = z => 'CAB-1-' + z;
  ctx.PALETTE = ['#aaa', '#bbb', '#ccc', '#ddd'];
  ctx.getInsertKind = () => 'cabinet';
  ctx.selectedCabId = 'CAB-1';
  ctx.currentZoneTree = { id: 'Z1', shelves: 0, children: [] };
  ctx.collectFronts = () => ({ gap: 3, gap_top: 2, gap_bottom: 2, gap_left: 2, gap_right: 2,
                               items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1' }] });
  ctx.computeZones = () => [{ id: 'Z1', leaf: true, x: 18, z: 118, w: 764, h: 646, shelves: 1 }];
  ctx.hwItems = [];
  ctx.applPreview = null;
  return ctx;
}

// Vykresli pripad; rect = { w, h } (px elementu #preview) alebo null (Node bez rozmeru).
function renderCase(ctx, c, rect, opts){
  opts = opts || {};
  ctx.__svg.rect = rect || null;
  if (!opts.keepView) vm.runInContext('pvUserView = false; pvView = null; frontDraft = null;', ctx);
  ctx.setType(c.type);
  ctx.__fields = Object.assign({}, BASE, c.fields || {});
  ctx.cornerPreview = c.cp || null;
  ctx.frontOpening = c.opening === undefined ? undefined : c.opening;
  if (c.opening === undefined) vm.runInContext('frontOpening = null', ctx);
  ctx.frontItems = c.items || null;
  ctx.frontSlots = {};
  ctx.hwItems = c.hw || [];
  ctx.applPreview = c.appl || null;
  if (c.zones) ctx.computeZones = () => c.zones;
  ctx.getInsertKind = () => (c.board ? 'board' : 'cabinet');
  vm.runInContext('previewMode = ' + JSON.stringify(c.mode), ctx);
  ctx.renderPreview();
  return ctx.__svg.innerHTML;
}

function unesc(s){ return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&'); }

// <text ...>obsah</text> -> [{ attrs, text }]
function texts(svg){
  const out = [];
  const re = /<text ([^>]*)>([^<]*)<\/text>/g;
  let m;
  while ((m = re.exec(svg))) {
    const attrs = {};
    m[1].replace(/([\w:-]+)="([^"]*)"/g, (_, k, v) => { attrs[k] = v; return ''; });
    out.push({ attrs, text: unesc(m[2]) });
  }
  return out;
}

module.exports = { makeCtx, renderCase, texts, CASES, EXTRA_CASES, CP_L, CP_R, BEKO, fakeEl, plain, ROOT, JS };
