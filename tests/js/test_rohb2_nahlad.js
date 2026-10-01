// ROH-B2 · K3 — kresba rohovej zostavy, karta Čelá a drobnosti O12 (panel).
//   node tests/js/test_rohb2_nahlad.js
//
// Co sa tu strazi (package ROH-B2, mockup sekcie C, B · Čelá, O12, A):
//   1) NAHLAD kresli rohovu zostavu PRESNE zo servera (`corner_preview`):
//      blenda tlmena a srafovana, rohova vystuha, CR 1, CR 2 v suradniciach
//      servera, koty 450 / 80 a sirka o riadok nizsie; obe strany; nezmestena
//      zostava cervenou; Korpus kresli aj dvere (bez interakcie); Čelá
//      a Kovanie tlmia dielce korpusu; vkladanie so zostavou (cela zhasnute =
//      bez nej); bez kresby servera ziadna zostava; OSTATNE TYPY sa nepohnu
//      o pixel (parita s kresbou v globali aj bez),
//   2) KARTA ČELÁ rohovej (O10): typ a krídla zamknute s dovodom, panty
//      „Pri boku / Pri rohu" podla strany dveri (hodnoty ostavaju left/right),
//      suhrn riadku „pánty pri rohu"; ostatne typy bez zmeny,
//   3) rad „Pridať čelo" nahradi veta, krizik zamknuty s dovodom, vyska AUTO
//      na citanie; skupina „Delenie zóny" sa pri rohovej nezobrazi,
//   4) O12: „Šírka dverí" zo servera (len oznacena rohova) s preklikom do
//      Čelá → F1; suhrn „dvere vľavo 450" v liste Základné; odhad „≈ Dielcov"
//      + dielce zostavy zo servera; preflight nesie CR a strop (kresba),
//   5) KLAVESA STRANY pri vkladani ide TOU ISTOU funkciou ako prepinac karty
//      (`onCornerSide` — zrkadlo navrhu ciel) a posle ten isty payload ako
//      „Vložiť" na prevesenie ghostu; pasik povie „dvere vľavo / vpravo",
//   6) ikona „Rohová" = schvaleny mockup (O4).
//
// MUTACIE (overene pri davke, report):
//   M1 `renderCabOutline` bez kot rohovej                  -> „1) koty 450 / 80"
//   M2 preflight bez `corner_cr1`                           -> „4) preflight CR"
//   M3 klavesa prepne register priamo (bez `onCornerSide`)  -> „5) ta ista funkcia"
//   M4 karta bez slov „Pri rohu" (opts.corner ignorovane)  -> „2) panty slovami"
//   M5 `nxSlotFrontsLock` bez vetvy rohovej                 -> „3) veta a zamky"
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const JS = path.join(ROOT, 'noxun_engine', 'ui', 'js');

let n = 0;
function plain(v){ return (v && typeof v === 'object') ? JSON.parse(JSON.stringify(v)) : v; }
function eq(actual, expected, msg){ n++; assert.deepStrictEqual(plain(actual), plain(expected), msg); }
function ok(cond, msg){ n++; assert.ok(cond, msg); }
// H12c: po core.js dostane kontext register typov zo servera (v CEF `NX.init`).
const TYPES = require('./nx_types_fixture.js');
function load(ctx, file){
  vm.runInContext(fs.readFileSync(path.join(JS, file), 'utf8'), ctx, { filename: file });
  if (file === 'core.js') TYPES.fill(ctx);
}
function get(ctx, expr){ return vm.runInContext(expr, ctx); }

// Kresba servera (`Panel.corner_preview_json`) pre 1100 × 720, sokel 100,
// D 450, CR 80 / 80, okraje 2 — cisla z headless sondy (test_rohb2_nahlad.rb).
const CP_L = { side: 'left', fits: true, need: 584, door_w: 446,
  parts: [{ role: 'corner_blind_panel', x0: 450, x1: 1082, z0: 118, z1: 702, title: 'Slepá časť — blenda korpusová 632 × 584 (materiál korpusu)' },
          { role: 'corner_rail', x0: 548, x1: 566, z0: 100, z1: 720, title: 'Rohová výstuha — kolmo na čelo, trčí 98 mm pred korpus; spredu len hrana 18 mm' },
          { role: 'cr_front', x0: 452, x1: 530, z0: 102, z1: 718, title: 'CR 1 — lišta v rovine dverí 78 × 616 (materiál čiel)' },
          { role: 'cr_side', x0: 530, x1: 548, z0: 102, z1: 718, title: 'CR 2 — kolmá lišta 96 mm do hĺbky; spredu len hrana 18 mm (materiál čiel)' }],
  dims: [{ x0: 0, x1: 450, label: '450', title: 'Dverová časť' }, { x0: 450, x1: 530, label: '80', title: 'CR 1' }],
  stats: { count: 5, area: 0.584 } };
const CP_R = { side: 'right', fits: true, need: 584, door_w: 446,
  parts: [{ role: 'corner_blind_panel', x0: 18, x1: 650, z0: 118, z1: 702, title: 'b' },
          { role: 'corner_rail', x0: 534, x1: 552, z0: 100, z1: 720, title: 'v' },
          { role: 'cr_front', x0: 570, x1: 648, z0: 102, z1: 718, title: 'c1' },
          { role: 'cr_side', x0: 552, x1: 570, z0: 102, z1: 718, title: 'c2' }],
  dims: [{ x0: 650, x1: 1100, label: '450' }, { x0: 570, x1: 650, label: '80' }], stats: { count: 5, area: 0.584 } };
const CP_BAD = Object.assign({}, CP_L, { fits: false, need: 584 });
const CORNER_ITEM = [{ id: 'F1', type: 'door', mode: 'auto', z: 102, height: 616, wings_n: 1, profile: 'none', direction: 'right' }];

// ============ 1) NAHLAD ======================================================
function fakeEl(attrs){
  const a = Object.assign({}, attrs || {});
  const cls = new Set();
  return {
    attrs: a, hidden: false, disabled: false, title: '', value: '', innerHTML: '', textContent: '', style: {}, dataset: {},
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k) ? a[k] : null; },
    setAttribute(k, v){ a[k] = String(v); }, removeAttribute(k){ delete a[k]; },
    querySelector(){ return null; }, querySelectorAll(){ return []; }, closest(){ return null; }, addEventListener(){},
    classList: { add(c){ cls.add(c); }, remove(c){ cls.delete(c); }, contains(c){ return cls.has(c); },
                 toggle(c, on){ if (on === undefined ? !cls.has(c) : on) cls.add(c); else cls.delete(c); } }
  };
}
function previewCtx(){
  const svg = fakeEl();
  const byId = { preview: svg };
  const ctx = { console, setTimeout, clearTimeout, window: {}, JSON, Math };
  ctx.document = { getElementById: id => byId[id] || null, querySelectorAll: () => [], querySelector: () => null,
                   addEventListener(){}, body: { appendChild(){}, setAttribute(){} }, createElement: () => fakeEl() };
  ctx.el = id => byId[id] || null;
  vm.createContext(ctx);
  load(ctx, 'core.js');
  load(ctx, 'preview.js');
  ctx.__svg = svg;
  ctx.__fields = {};
  ctx.numv = id => (ctx.__fields[id] === undefined ? NaN : parseFloat(ctx.__fields[id]));
  ctx.val = id => (ctx.__fields[id] === undefined ? '' : String(ctx.__fields[id]));
  ctx.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  ctx.NXIcons = { svg: id => '<svg><use href="#i-' + id + '"/></svg>', set(){} };
  ctx.clearFrontHover = () => {};
  ctx.computeZones = () => [{ id: 'Z1', leaf: true, x: 18, z: 118, w: 1064, h: 584, shelves: 1 }];
  ctx.fullZoneId = z => 'CAB-1-' + z;
  ctx.PALETTE = ['#aaa'];
  ctx.getInsertKind = () => 'cabinet';
  ctx.selectedCabId = 'CAB-1';
  ctx.hwItems = [];
  ctx.currentZoneTree = { id: 'Z1', shelves: 1, children: [] };
  ctx.collectFronts = () => ({ gap: 3, gap_top: 2, gap_bottom: 2, gap_left: 2, gap_right: 2,
                               items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1' }] });
  return ctx;
}
function render(ctx, type, mode, fields, cp, opening, items, hw){
  vm.runInContext('pvUserView = false; pvView = null; frontDraft = null;', ctx);
  ctx.setType(type);
  ctx.__fields = Object.assign({ width: 1100, height: 720, depth: 510, thickness: 18, floor_height: 100,
                                 fr_gap_left: 2, fr_gap_right: 2, fr_gap: 3, fr_gap_top: 2, top_mode: 'full',
                                 back_mode: 'overlay' }, fields || {});
  ctx.cornerPreview = cp;
  ctx.frontOpening = opening === undefined ? { x0: 0, w: 450, z0: 100, h: 620 } : opening;
  ctx.frontItems = items === undefined ? CORNER_ITEM : items;
  ctx.frontSlots = {};
  ctx.hwItems = hw || [];
  vm.runInContext('previewMode = ' + JSON.stringify(mode), ctx);
  ctx.renderPreview();
  return ctx.__svg.innerHTML;
}
// Dielce zostavy v mm SCENY (pad 14): role -> [x, sirka, atributy skupiny + telo].
function corner(svg){
  const out = {};
  const re = /<g class="pvcorner" data-role="([a-z_]+)"([^>]*)><title>[^<]*<\/title>(<rect x="([-\d.]+)" y="[-\d.]+" width="([-\d.]+)"[^>]*\/>(?:<rect[^>]*\/>)?)<\/g>/g;
  let m;
  while ((m = re.exec(svg))) out[m[1]] = { x: Math.round((parseFloat(m[4]) - 14) * 100) / 100, w: parseFloat(m[5]), g: m[2], body: m[3] };
  return out;
}
{
  const ctx = previewCtx();
  // --- Korpus, dvere vlavo ---
  let s = render(ctx, 'corner_blind', 'cab', {}, CP_L);
  let c = corner(s);
  eq(Object.keys(c), ['corner_blind_panel', 'corner_rail', 'cr_front', 'cr_side'], 'Korpus: blenda, výstuha, CR 1, CR 2 v poradí servera');
  eq([c.corner_blind_panel.x, c.corner_blind_panel.w], [450, 632], 'blenda 450…1082 presne zo servera');
  ok(/fill="url\(#pvCornerHatch\)"/.test(c.corner_blind_panel.body) && /fill-opacity=".35"/.test(c.corner_blind_panel.body),
     'slepá časť = blenda tlmená a šrafovaná');
  ok(s.indexOf('<pattern id="pvCornerHatch"') >= 0, 'vzor šrafovania je v SVG');
  eq([c.corner_rail.x, c.corner_rail.w, c.cr_front.x, c.cr_front.w, c.cr_side.x, c.cr_side.w],
     [548, 18, 452, 78, 530, 18], 'výstuha 18 mm hrana, CR 1 78, CR 2 18 mm hrana — súradnice servera');
  ok(/fill="#e0f2f4"/.test(c.cr_front.body) && /fill="#7fc4cf"/.test(c.cr_side.body), 'CR 1 ako čelo, CR 2 ako hrana (farby čiel)');
  ok(s.indexOf('<title>Slepá časť — blenda korpusová 632 × 584 (materiál korpusu)</title>') >= 0, 'bublina = text servera');
  ok(/<g pointer-events="none"><g class="fgrp" data-front-id="F1">/.test(s), 'Korpus kreslí aj DVERE (O12), bez interakcie');
  ok(/<rect x="16" y="[-\d.]+" width="446" height="616" fill="#e0f2f4"/.test(s), 'dvere 2…448 (otvor + okraje)');
  // Koty: 450 a 80 tesne pod skrinkou (z −26), sirka o riadok nizsie (z −62).
  // ry(z) = 14 + (720 − z) → −26: 760, text 751 · −62: 796, text 787.
  ok(/<text x="239" y="751"[^>]*>450<\/text>/.test(s), 'kóta dverovej časti 450 (stred 0…450) pod skrinkou');
  ok(/<text x="504" y="751"[^>]*>80<\/text>/.test(s), 'kóta CR 1 = 80 (450…530)');
  ok(/<text x="564" y="787"[^>]*>Š 1100 mm<\/text>/.test(s), 'šírka o riadok nižšie');
  ok(!/y="751"[^>]*>Š 1100 mm/.test(s), 'šírka už nie je na mieste kôt rohovej');

  // --- Dvere vpravo: zrkadlo zo servera ---
  s = render(ctx, 'corner_blind', 'cab', {}, CP_R, { x0: 650, w: 450, z0: 100, h: 620 });
  c = corner(s);
  eq([c.corner_blind_panel.x, c.corner_blind_panel.w, c.cr_front.x, c.cr_side.x, c.corner_rail.x], [18, 632, 570, 552, 534],
     'dvere vpravo: celá zostava zrkadlená (súradnice servera)');
  ok(/<text x="889" y="751"[^>]*>450<\/text>/.test(s) && /<text x="624" y="751"[^>]*>80<\/text>/.test(s), 'kóty zrkadlené (650…1100, 570…650)');
  ok(/<rect x="666" y="[-\d.]+" width="446" height="616" fill="#e0f2f4"/.test(s), 'dvere vpravo 652…1098');

  // --- Nezmestena zostava cervenou ---
  c = corner(render(ctx, 'corner_blind', 'cab', {}, CP_BAD));
  ok(/stroke="#e53935"/.test(c.corner_rail.body) && /fill="#fdecea"/.test(c.corner_rail.body), 'nezmestí sa: výstuha červená');
  ok(/stroke="#e53935"/.test(c.cr_front.body) && /stroke="#e53935"/.test(c.cr_side.body), 'aj CR 1 a CR 2');
  ok(!/#e53935/.test(c.corner_blind_panel.body), 'blenda ostáva tlmená (nie je chybou)');
  c = corner(render(ctx, 'corner_blind', 'cab', {}, CP_L));
  ok(!/#e53935/.test(JSON.stringify(c)), 'zmestí sa: žiadna červená');

  // --- Čelá a Kovanie: dielce korpusu tlmene, CR nie ---
  s = render(ctx, 'corner_blind', 'fronts', {}, CP_L);
  c = corner(s);
  ok(/opacity=".55"/.test(c.corner_blind_panel.g) && /opacity=".55"/.test(c.corner_rail.g), 'Čelá: blenda a výstuha tlmené');
  ok(!/opacity/.test(c.cr_front.g) && !/opacity/.test(c.cr_side.g), 'Čelá: CR lišty plné');
  ok(/<g class="fgrp" data-front-id="F1">/.test(s) && !/<g pointer-events="none"><g class="fgrp"/.test(s), 'Čelá: dvere ostávajú klikateľné');
  c = corner(render(ctx, 'corner_blind', 'hw', {}, CP_L));
  eq(Object.keys(c).length, 4, 'Kovanie: zostava ako tlmený podklad');
  ok(/opacity=".55"/.test(c.corner_blind_panel.g), 'Kovanie: blenda tlmená');
  eq(Object.keys(corner(render(ctx, 'corner_blind', 'zones', {}, CP_L))).length, 0, 'Zóny: zostava sa nekreslí (vnútro)');

  // --- Vkladanie: so zostavou, zhasnute cela = vnutro bez nej ---
  s = render(ctx, 'corner_blind', 'insert', {}, CP_L, undefined, null);
  eq(Object.keys(corner(s)).length, 4, 'vkladanie kreslí rohovú tak, ako sa vloží (A6)');
  ok(/y="751"[^>]*>450</.test(s) && /y="787"[^>]*>Š 1100 mm/.test(s), 'vkladanie: tie isté kóty');
  get(ctx, "NXLayers.toggle('insert', 'cela', { zony: true, cela: true })");
  eq(Object.keys(corner(render(ctx, 'corner_blind', 'insert', {}, CP_L, undefined, null))).length, 0,
     'zhasnuté čelá odkryjú vnútro — zostava (blenda pred vnútrom) nie');
  get(ctx, "NXLayers.toggle('insert', 'cela', { zony: true, cela: true })");

  // --- Bez kresby servera: ziadna zostava, dnesne koty ---
  s = render(ctx, 'corner_blind', 'cab', {}, null);
  eq(Object.keys(corner(s)).length, 0, 'bez kresby servera sa zostava nekreslí (nič sa nehádá)');
  ok(/y="751"[^>]*>Š 1100 mm/.test(s), 'a šírka ostáva na svojom mieste');

  // --- PARITA: ostatne typy su pixel po pixeli rovnake (kresba v globali aj bez) ---
  const LOW = [{ id: 'F1', type: 'drawer_front', mode: 'fixed', z: 102, height: 180, wings_n: 1, profile: 'none' },
               { id: 'F2', type: 'door', mode: 'auto', z: 285, height: 433, wings_n: 2, profile: 'none' }];
  const HW = [{ owner_part_key: 'front:F2/wing:left', generic_type: 'hinge', quantity: 2, label: 'Z' },
              { owner_part_key: null, generic_type: 'leg', quantity: 4, label: 'N' }];
  const LOWF = { width: 900, dw_class: 600, dw_body_height: 820, dw_front_bottom: 64 };
  let same = 0;
  ['lower', 'upper', 'dishwasher'].forEach(function(t){
    ['cab', 'fronts', 'hw', 'zones', 'insert'].forEach(function(mode){
      const items = mode === 'insert' ? null : LOW;
      const a = render(ctx, t, mode, LOWF, null, null, items, HW);
      const b = render(ctx, t, mode, LOWF, CP_L, null, items, HW);
      if (a === b && a.length > 0 && a.indexOf('pvcorner') < 0) same++;
    });
  });
  eq(same, 15, 'dolná · horná · slot × 5 projekcií: kresba rohovej ich nezmení ani o pixel');

  // --- Odhad dielcov: + zostava zo servera ---
  eq(ctx.nxCornerStatsAdd({ count: 7, area: 1.2 }, CP_L), { count: 12, area: 1.784 }, 'odhad + 5 dielcov zostavy a ich plocha');
  eq(ctx.nxCornerStatsAdd({ count: 7, area: 1.2 }, null), { count: 7, area: 1.2 }, 'bez kresby odhad bez zmeny');
  ctx.setType('lower');
  ctx.cornerPreview = CP_L;
  eq(ctx.pvCornerPreview(), null, 'dolná kresbu rohovej nikdy nečíta');
}

// ============ 2) KARTA ČELÁ ROHOVEJ (O10) =====================================
{
  const core = require(path.join(JS, 'core.js'));
  // Panty slovami podla strany dveri (hodnoty ostavaju left/right).
  eq([core.frontCornerHingeWord('left', 'right'), core.frontCornerHingeWord('left', 'left'),
      core.frontCornerHingeWord('right', 'left'), core.frontCornerHingeWord('right', 'right')],
     ['pri rohu', 'pri boku', 'pri rohu', 'pri boku'], 'dvere vľavo: pánty vpravo = pri rohu; dvere vpravo: vľavo = pri rohu');
  eq([core.frontCornerHingeWord('left', 'unset'), core.frontCornerHingeWord('left', undefined)], [null, null],
     'neurčené aj legacy = žiadne slovo (nič sa nevymýšľa)');
  const IT = { id: 'F1', type: 'door', wings: '1', direction: 'right' };
  const ENTRY = { wings_n: 1, slots: [{ wing: 'single', part_key: 'front:F1/wing:single', state: 'right' }] };
  const m = core.frontCardModel(IT, ENTRY, null, null, { corner: 'left' });
  eq(m.tiles.map(t => [t.type, !!t.lock]), [['door', false], ['drawer_front', true], ['lift', true], ['fall', true],
     ['blind', true], ['none', true]], 'typ zamknutý: ostatné dlaždice lock');
  const wings = m.rows.find(r => r.key === 'wings');
  eq([wings.options.map(o => o.value), wings.options.map(o => !!o.disabled), wings.active],
     [['1', '2', '3', '4'], [false, true, true, true], '1'], 'krídla: 1 aktívne, 2–4 zamknuté');
  ok(wings.options[1].title.indexOf('jedno krídlo') > 0, 'zamknutá voľba nesie dôvod');
  const dir = m.rows.find(r => r.key === 'direction');
  eq([dir.label, dir.options.map(o => o.label), dir.options.map(o => o.value), dir.active],
     ['Pánty', ['Pri boku', 'Neurčené', 'Pri rohu'], ['left', 'unset', 'right'], 'right'],
     'dvere vľavo: Pri boku / Pri rohu (hodnoty left/right, ikony skutočnej strany)');
  eq(dir.options.map(o => o.icon), ['dir-left', 'dir-unset', 'dir-right'], 'ikona ukazuje skutočnú stranu');
  const mr = core.frontCardModel(Object.assign({}, IT, { direction: 'left' }), ENTRY, null, null, { corner: 'right' });
  eq(mr.rows.find(r => r.key === 'direction').options.map(o => o.label), ['Pri rohu', 'Neurčené', 'Pri boku'],
     'dvere vpravo: ľavá strana = pri rohu');
  // Parita: bez rohovej karta presne ako doteraz.
  const plainM = core.frontCardModel(IT, ENTRY, null, null, {});
  eq(plainM.tiles.some(t => t.lock), false, 'iný typ: žiadna zamknutá dlaždica');
  eq(plainM.rows.find(r => r.key === 'direction').options.map(o => o.label), ['Ľavé', 'Neurčené', 'Pravé'], 'iný typ: Ľavé / Pravé');
  eq(plainM.rows.find(r => r.key === 'wings').options.map(o => o.value), ['auto', '1', '2', '3', '4'], 'iný typ: krídla bez zmeny');
  eq(core.frontCardModel(IT, ENTRY, null, null, { corner: 'hore' }).tiles.some(t => t.lock), false, 'neznáma strana = bežná karta');
  // Suhrn riadku.
  const txt = parts => parts.filter(p => p.text).map(p => p.text);
  eq(txt(core.frontRowSummary(IT, ENTRY, null, [], null, 'left')), ['1 krídlo', 'pánty pri rohu', 'bez úchytky'], 'súhrn: pánty pri rohu');
  eq(txt(core.frontRowSummary(Object.assign({}, IT, { direction: 'left' }), ENTRY, null, [], null, 'left')),
     ['1 krídlo', 'pánty pri boku', 'bez úchytky'], 'súhrn: pánty pri boku');
  eq(txt(core.frontRowSummary(IT, ENTRY, null, [], null)), ['1 krídlo', 'pravé', 'bez úchytky'], 'iný typ: súhrn bez zmeny');
}

// ============ 3) + 4) + 5) FORMULAR ==========================================
function formCtx(){
  const byId = {};
  const node = id => (byId[id] || (byId[id] = Object.assign(fakeEl(), { id: id })));
  const zsplit = fakeEl();
  const ctx = { console, setTimeout, clearTimeout, window: {}, JSON, Math };
  ctx.document = { getElementById: node, querySelectorAll: () => [],
                   querySelector: sel => (sel === 'details[data-key="zsplit"]' ? zsplit : null),
                   addEventListener(){}, activeElement: null, body: { appendChild(){}, setAttribute(){} },
                   createElement: () => fakeEl() };
  vm.createContext(ctx);
  ['core.js', 'expr.js', 'insert_state.js', 'form.js', 'actions.js'].forEach(f => load(ctx, f));
  ctx.__node = node;
  ctx.__zsplit = zsplit;
  ctx.__status = [];
  ctx.NX = { setStatus(m, bad){ ctx.__status.push([m, !!bad]); } };
  ctx.nxDocGuid = () => 'G-1';
  ctx.nxDocPayload = (o, g) => JSON.stringify(Object.assign({}, o, { model_guid: g || 'G-1' }));
  ctx.DEFAULTS = {
    lower: { type: 'lower', width: 600, height: 720, depth: 510, thickness: 18, floor_height: 100 },
    corner_blind: { type: 'corner_blind', width: 1100, height: 720, depth: 510, thickness: 18, floor_height: 100,
                    corner_side: 'left', corner_door_w: 450, corner_cr1: 80, corner_cr2: 80, corner_th2: 18 }
  };
  const BASE = { width: 1100, height: 720, depth: 510, thickness: 18, floor_height: 100, bottom_mode: 'under_sides',
                 top_mode: 'full', back_mode: 'overlay', back_thickness: 3, plinth_mode: 'none', plinth_recess: 40,
                 rails_orientation: 'flat', rails_top_offset: 0, rail_depth: 100, back_setback: 0,
                 top_front_setback: 0, back_rail_height: 100, dw_class: '600', dw_body_height: 820,
                 dw_front_bottom: 64, corner_door_w: 450, corner_cr1: 80, corner_cr2: 80,
                 fr_gap_left: 2, fr_gap_right: 2 };
  Object.keys(BASE).forEach(k => { node(k).value = String(BASE[k]); });
  return ctx;
}
// Riadok cela s poliami, ktore `nxSlotFrontsLock` cita.
function frowFake(){
  const parts = { '.fh': fakeEl(), '.fauto': fakeEl(), '.fdel': fakeEl() };
  const row = fakeEl();
  row.dataset.frontId = 'F1';
  row.querySelector = sel => parts[sel] || null;
  row.__parts = parts;
  return row;
}

// ---- 3) Veta namiesto „Pridať čelo", zamky, delenie zon ----
{
  const ctx = formCtx();
  const addRow = fakeEl(), addl = fakeEl(), row = frowFake();
  addRow.querySelector = sel => (sel === '.addl' ? addl : null);
  ctx.__node('frontAddTypes').closest = sel => (sel === '.addrow' ? addRow : null);
  ctx.__node('frontRows').querySelectorAll = () => [row];
  ctx.setType('corner_blind');
  ctx.nxSlotFrontsLock();
  eq([ctx.__node('frontAddTypes').hidden, addl.hidden, ctx.__node('frontOneDoor').hidden, addRow.style.display],
     [true, true, false, ''], 'rohová: rad „Pridať čelo" nahradí veta (ten istý riadok, nie navyše)');
  eq([row.__parts['.fdel'].getAttribute('aria-disabled'), row.__parts['.fdel'].style.display], ['true', ''],
     'krížik ostáva viditeľný, ale zamknutý (aria-disabled)');
  ok(row.__parts['.fdel'].title.indexOf('jedny dvierka') > 0, 'a povie prečo');
  ok(row.__parts['.fh'].readOnly === true && row.__parts['.fauto'].style.display === 'none', 'výška AUTO na čítanie');
  eq(ctx.delFrontRow(row.__parts['.fdel']), false, 'klik na zamknutý krížik nič nezmaže (žiadny prázdny apply)');
  ctx.setType('lower');
  ctx.nxSlotFrontsLock();
  eq([ctx.__node('frontAddTypes').hidden, addl.hidden, ctx.__node('frontOneDoor').hidden],
     [false, false, true], 'dolná: rad pridávania späť, veta preč');
  eq([row.__parts['.fdel'].getAttribute('aria-disabled'), row.__parts['.fh'].readOnly], [null, false], 'krížik aj výška odomknuté');
  // Delenie zon.
  ctx.applyVisibility('corner_blind');
  eq(ctx.__zsplit.hidden, true, 'rohová: skupina „Delenie zóny" sa nezobrazí');
  ctx.applyVisibility('lower');
  eq(ctx.__zsplit.hidden, false, 'dolná: delenie ostáva');
  ok(/\[data-s4\]\[hidden\] \{ display: none; \}/.test(fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), 'utf8')),
     'CSS: skrytie typom prebije kontextové display:block');
}

// ---- 4) O12: sirka dveri, preflight, kresba z payloadu/preflightu ----
{
  const ctx = formCtx();
  ctx.setType('corner_blind');
  // SKUTOCNE PORADIE `loadSelected` (predrecenzia P3-3): kresba sa prevezme
  // (`nxAdoptCabinetDraft`) SKOR, nez sa zmeni identita (`setSelected`).
  const bridgeSrc = fs.readFileSync(path.join(JS, 'bridge.js'), 'utf8');
  const loadSel = bridgeSrc.slice(bridgeSrc.indexOf('loadSelected: function(c){'));
  ok(loadSel.indexOf('nxAdoptCabinetDraft(c)') > 0 &&
     loadSel.indexOf('nxAdoptCabinetDraft(c)') < loadSel.indexOf('setSelected(c.cabinet_id || null)'),
     'loadSelected: prevzatie kresby PRED zmenou identity (to je poradie, ktoré test prehráva)');
  vm.runInContext('selectedCabId = null', ctx);
  ctx.__node('infCornerDoor').hidden = true;
  ctx.nxAdoptCabinetDraft({ type: 'corner_blind', corner_side: 'left', corner_preview: CP_L, front_opening: { x0: 0, w: 450 } });
  eq(get(ctx, 'cornerPreview'), CP_L, 'payload označenej rohovej = kresba uloženého stavu');
  ctx.setSelected('CAB-1');
  eq([ctx.__node('infCornerDoor').hidden, ctx.__node('inf_corner_door').textContent], [false, '446'],
     'výber rohovej z prázdneho výberu: „Šírka dverí 446" hneď po setSelected (nie až po preflighte)');
  ctx.setSelected(null);
  eq(ctx.__node('infCornerDoor').hidden, true, 'zrušenie výberu riadok schová');
  ctx.setSelected('CAB-1');
  ok(ctx.__node('infCornerDoor').title.indexOf('Čelá → F1') > 0, 'bublina povie, kam klik vedie');
  // Klik: kontext Čelá a karta F1.
  let ctxSwitch = null, refreshed = 0;
  ctx.setViewContext = c => { ctxSwitch = c; };
  const f1 = frowFake();
  ctx.__node('frontRows').querySelectorAll = () => [f1];
  ctx.refreshFrontCards = () => { refreshed++; };
  ctx.onInfoCornerDoor();
  eq([ctxSwitch, get(ctx, 'openFrontCardId'), refreshed], ['cela', 'F1', 1], 'klik = Čelá → karta F1 otvorená');
  // Vkladanie a iny typ: riadok nie je (nemal by kam viest).
  vm.runInContext('selectedCabId = null', ctx);
  ctx.nxCornerInfoSync();
  eq(ctx.__node('infCornerDoor').hidden, true, 'vo vkladaní riadok nie je (kontext Čelá neexistuje)');
  vm.runInContext("selectedCabId = 'CAB-1'", ctx);
  ctx.setType('lower');
  ctx.nxCornerInfoSync();
  eq(ctx.__node('infCornerDoor').hidden, true, 'dolná riadok nemá');
  // Preflight nesie CR a strop LEN pri rohovej (kresba zostavy).
  ctx.collectFronts = () => ({ gap: 3, items: [] });
  vm.runInContext('selectedCabId = null', ctx);
  ctx.setType('corner_blind');
  let d = ctx.nxFrontDraftData();
  eq([d.corner_cr1, d.corner_cr2, d.top_mode, d.rail_depth], [80, 80, 'full', 100], 'rohová: preflight nesie CR 1, CR 2 a strop');
  ctx.__node('corner_cr1').value = '120';
  eq(ctx.nxFrontDraftData().corner_cr1, 120, 'zmena CR 1 = nový preflight (iná signatúra)');
  ctx.setType('lower');
  d = ctx.nxFrontDraftData();
  eq(Object.keys(d).sort(), ['cabinet_id', 'floor_height', 'fronts', 'height', 'insert_session', 'model_guid', 'type', 'width'],
     'dolná: preflight bez jediného kľúča navyše (parita)');
  // Odpoved preflightu prevezme kresbu; zmena identity ju zahodi.
  ctx.setType('corner_blind');
  ['updateFrontDirBadges', 'updateFrontPlaceholders', 'refreshFrontCards', 'renderPreview'].forEach(k => { ctx[k] = () => {}; });
  ctx.sketchup = { front_preflight: () => {} };
  ctx.window.sketchup = ctx.sketchup;
  ctx.nxFrontDraftAsk();
  const req = get(ctx, 'frontDraft').request;
  ctx.nxFrontPreflightResult({ revision: req.revision, model_guid: 'G-1', cabinet_id: '', insert_session: req.insert_session,
                               valid: true, items: [], errors: [], slots: {}, opening: { x0: 650, w: 450 }, corner_preview: CP_R });
  eq(get(ctx, 'cornerPreview'), CP_R, 'preflight aktuálnej revízie = živá kresba');
  ctx.nxFrontPreflightResult({ revision: req.revision, model_guid: 'G-1', cabinet_id: '', insert_session: req.insert_session,
                               valid: true, items: [], errors: [], slots: {}, corner_preview: CP_L });
  eq(get(ctx, 'cornerPreview'), CP_L, 'aj bez otvoru (kresba ide svojím kľúčom)');
  ctx.nxFrontDraftReset();
  eq(get(ctx, 'cornerPreview'), null, 'zmena identity kresbu zahodí (ako otvor)');
  // Odhad pri vkladani: + zostava (funkcie nahladu v tom istom okne).
  load(ctx, 'preview.js');
  ctx.cornerPreview = CP_L;
  ctx.nxDraftStats = () => ({ count: 7, area: 1.2 });
  ctx.pvGeom = () => ({});
  ctx.computeZones = () => [];
  ctx.pvInsertFronts = () => [];
  ctx.mmLabel = v => String(v);
  ctx.setInsertCabInfo();
  eq(ctx.__node('inf_parts').textContent, '≈ 12', 'vkladanie rohovej: ≈ dielcov + 5 zo zostavy (A2 odchýlka 4)');
}

// ---- 4b) Suhrn v liste Zakladne ----
{
  const NXShell = require(path.join(JS, 'shell.js'));
  const base = { w: 1100, h: 720, d: 510, plinth: 100 };
  eq(NXShell.sectorMeta({ mode: 'cab', ctx: 'korpus', dims: Object.assign({}, base, { corner: { side: 'left', door: 450 } }) }).s2,
     '1100 × 720 × 510 · sokel 100 · dvere vľavo 450', 'rohová: „dvere vľavo 450" aj v zbalenom sektore');
  eq(NXShell.sectorMeta({ mode: 'cab', ctx: 'korpus', dims: Object.assign({}, base, { corner: { side: 'right', door: NaN } }) }).s2,
     '1100 × 720 × 510 · sokel 100 · dvere vpravo', 'bez čísla len strana');
  eq(NXShell.sectorMeta({ mode: 'cab', ctx: 'korpus', dims: base }).s2, '1100 × 720 × 510 · sokel 100', 'iný typ: meta bez zmeny');
}

// ---- 5) Klavesa strany pri vkladani = TA ISTA funkcia ako prepinac karty ----
{
  const LEFT_TPL = { gap: 3, gap_top: 5, gap_bottom: 0, gap_left: 0, gap_right: 2,
                     items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1', direction: 'right' }] };
  const ctx = formCtx();
  ctx.setType('corner_blind');
  vm.runInContext('selectedCabId = null', ctx);
  ctx.nxSetCornerDraft({ type: 'corner_blind', corner_side: 'left' });
  let rendered = null;
  ctx.collectFronts = () => JSON.parse(JSON.stringify(rendered || LEFT_TPL));
  ctx.renderFronts = f => { rendered = f; };
  ctx.onField = () => {};
  ctx.validateFields = () => true;
  const SENT = [];
  ctx.sketchup = { ghost_corner_side: j => SENT.push(JSON.parse(j)), insert_cabinet: () => { throw new Error('nie insert'); } };
  ctx.window.sketchup = ctx.sketchup;
  const realSide = ctx.onCornerSide;
  const calls = [];
  ctx.onCornerSide = s => { calls.push(s); realSide(s); };
  eq(ctx.nxGhostCornerSide('left'), true, 'ghost vľavo -> žiadosť odišla');
  eq(calls, ['right'], 'prepína TÁ ISTÁ funkcia ako prepínač karty (onCornerSide)');
  eq(ctx.nxCornerSide(), 'right', 'register karty = vpravo');
  eq([rendered.gap_left, rendered.gap_right, rendered.items[0].direction], [2, 0, 'left'],
     'zrkadlo návrhu čiel: okraj pri rohu ostane pri rohu, pánty pri rohu (audit B1 FIX 2)');
  eq(SENT.length, 1, 'ghost sa prevesí vlastným callbackom (nie „Vložiť")');
  eq([SENT[0].type, SENT[0].corner_side, SENT[0].model_guid, SENT[0].fronts.gap_left, SENT[0].fronts.items[0].direction],
     ['corner_blind', 'right', 'G-1', 2, 'left'], 'payload = vklad z karty s novou stranou a zrkadlenými čelami');
  // Rychle DVOJITE D (predrecenzia P3-2): ghost este nesie staru stranu
  // (prevesenie sa nedokoncilo) a hlasi znova „left" — nova strana sa
  // pocita z KARTY, takze druhe stlacenie vrati vlavo.
  eq(ctx.nxGhostCornerSide('left'), true, 'druhé stlačenie hneď za prvým (ghost ešte hlási vľavo)');
  eq([ctx.nxCornerSide(), SENT[1].corner_side, SENT[1].fronts.gap_left], ['left', 'left', 0],
     'dve stlačenia = späť vľavo s pôvodnými okrajmi (strana z karty, nie z hlásenia ghostu)');
  eq(calls, ['right', 'left'], 'obe stlačenia idú tou istou funkciou karty');
  // Odmietnutia: oznacena skrinka, iny typ, cervene pole — nic sa nemeni ani neposiela.
  vm.runInContext("selectedCabId = 'CAB-1'", ctx);
  eq(ctx.nxGhostCornerSide('left'), false, 'označená skrinka: kláves nič neprepína');
  vm.runInContext('selectedCabId = null', ctx);
  ctx.setType('lower');
  eq(ctx.nxGhostCornerSide('left'), false, 'karta inej skrinky: nič');
  ctx.setType('corner_blind');
  ctx.validateFields = () => false;
  eq(ctx.nxGhostCornerSide('left'), false, 'červené pole: strana sa neprepne');
  eq([ctx.nxCornerSide(), SENT.length], ['left', 2], 'register ani ghost sa nezmenili');
  ok(ctx.__status.slice(-3).every(s => s[1] === true), 'každé odmietnutie povie prečo');
  // Most z Ruby.
  ok(/ghostCornerSide: function\(side\)\{ if \(typeof nxGhostCornerSide === 'function'\) nxGhostCornerSide\(side\); \}/
       .test(fs.readFileSync(path.join(JS, 'bridge.js'), 'utf8')), 'NX.ghostCornerSide volá kartu');
}

// ---- 5b) Pasik ghostu ----
{
  const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
  const BAR = mkEl('div');
  BAR.attrs.id = 'ghostBar';
  BAR.hidden = true;
  BAR.innerHTML = '<span class="gbtxt" id="gbRot">0°</span><span class="gbtxt gbcorner" id="gbCorner"></span>' +
                  '<button class="gbinfo" id="gbInfo"></button>';
  DOC.body.appendChild(BAR);
  const GB = require(path.join(JS, 'ghost_bar.js'));
  const st = o => Object.assign({ active: true, subject: 'cabinet', interaction: 'placement', anchor: 'fl_bottom',
                                  rotation: 0, z_mode: 'locked', lock_z: 0 }, o);
  eq(GB.cornerText(st({ corner_label: 'dvere vľavo' })), 'dvere vľavo', 'text strany skladá server');
  eq([GB.cornerText(st({})), GB.cornerText(st({ subject: 'board', corner_label: 'x' })),
      GB.cornerText(st({ interaction: 'drawing', corner_label: 'x' }))], ['', '', ''], 'iná skrinka, doska ani kreslenie ho nemajú');
  GB.apply(st({ corner_label: 'dvere vpravo' }));
  const seg = DOC.getElementById('gbCorner'), info = DOC.getElementById('gbInfo');
  eq([seg.hidden, seg.textContent], [false, 'dvere vpravo'], 'pásik povie „dvere vpravo"');
  ok(info.getAttribute('title').indexOf('D prepne stranu dverí') >= 0, 'nápoveda pozná klávesu D');
  GB.apply(st({}));
  eq(seg.hidden, true, 'dolná skrinka: segment zmizne');
  ok(info.getAttribute('title').indexOf('D prepne') < 0, 'a nápoveda je dnešná');
}

// ============ 6) IKONA „Rohová" = schvaleny mockup (O4) =======================
{
  const mock = fs.readFileSync(path.join(ROOT, 'SYSTEM', 'archiv', 'bloky', 'ROHOVA', 'MOCKUP_ROHOVA_2026-09-28.html'), 'utf8');
  const want = (mock.match(/<symbol id="i-cab-corner"[^>]*>(.*?)<\/symbol>/) || [])[1];
  const have = (fs.readFileSync(path.join(JS, 'icons.js'), 'utf8').match(/'cab-corner': '([^']*)'/) || [])[1];
  ok(want && have, 'ikona je v mockupe aj v sprite');
  eq(have, want, 'ikona „Rohová" = schválený mockup (skrinka na sokli, dvere s úchytkou, prekrížená slepá časť)');
  const html = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'panel.html'), 'utf8');
  ok(html.indexOf('id="infCornerDoor"') > 0 && html.indexOf('onclick="onInfoCornerDoor()"') > 0, 'panel: riadok Šírka dverí s preklikom');
  ok(html.indexOf('Rohová skrinka má v dverovej časti jedny dvierka.') > 0, 'panel: veta „jedny dvierka" (O10)');
  ok(html.indexOf('id="gbCorner"') > 0, 'panel: segment strany v pásiku');
}

console.log('test_rohb2_nahlad.js: ' + n + ' kontrol OK');
