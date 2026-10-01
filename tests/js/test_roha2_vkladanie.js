// ROH-A2 · K3 — vkladanie a náhľad rohovej skrinky (panel).
//   node tests/js/test_roha2_vkladanie.js
//
// Co sa tu strazi (package ROH-A2, bod 1–6):
//   1) typ „Rohová" vo vkladacej karte — stav NXInsert, `aria-pressed` a `.on`
//      tlacidiel, filter sablon podla typu,
//   2) NAHLAD CIEL OD OTVORU: rohova W 1100 kresli dvere 2–448 (vlavo) alebo
//      652–1098 (vpravo) — kota sirky, medzery, ghost aj kovanie od otvoru;
//      rohova bez znameho otvoru cela NEKRESLI (ziadne dvere cez celu sirku),
//   3) PARITA: dolna, horna a slot sa nehnu ani o pixel — serverovy otvor
//      rohovej ignoruju a cisla dolnej sedia s pevnymi hodnotami,
//   4) znacky zavesov podla SMERU (C8): left / right / unset („?") / legacy (nic),
//   5) preflight: pri vkladani rohovej posle stranu a dverovu cast, odpoved
//      AKTUALNEJ revizie ulozi otvor, stara odpoved sa zahodi,
//   6) nahlad noh vo vkladacej karte aj pre rohovu; modal sablony zamkne typ.
// Zrkadlo Ruby: tests/pure/test_roha2_vkladanie.rb.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const JS = path.join(ROOT, 'noxun_engine', 'ui', 'js');

let n = 0;
// Objekty z vm kontextu maju iny prototyp (iny realm) — porovnava sa ich JSON tvar.
function plain(v){ return (v && typeof v === 'object') ? JSON.parse(JSON.stringify(v)) : v; }
function eq(actual, expected, msg){ n++; assert.deepStrictEqual(plain(actual), plain(expected), msg); }
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// Maly falosny uzol: atributy, classList, innerHTML (ziadne parsovanie).
function fakeEl(attrs){
  const a = Object.assign({}, attrs || {});
  const cls = new Set();
  return {
    attrs: a, hidden: false, disabled: false, title: '', value: '', innerHTML: '', textContent: '',
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k) ? a[k] : null; },
    setAttribute(k, v){ a[k] = String(v); },
    classList: { add(c){ cls.add(c); }, remove(c){ cls.delete(c); }, contains(c){ return cls.has(c); },
                 toggle(c, on){ if (on === undefined ? !cls.has(c) : on) cls.add(c); else cls.delete(c); } }
  };
}
function mkCtx(ids){
  const ctx = { console, setTimeout, clearTimeout, window: {}, JSON, Math };
  const byId = ids || {};
  ctx.document = { getElementById: id => byId[id] || null, querySelectorAll: () => [], querySelector: () => null,
                   addEventListener(){}, body: { appendChild(){}, setAttribute(){} },
                   createElement: () => fakeEl() };
  ctx.el = id => byId[id] || null;
  vm.createContext(ctx);
  return ctx;
}
// H12c: po core.js dostane kontext register typov zo servera (v CEF `NX.init`).
const TYPES = require('./nx_types_fixture.js');
function load(ctx, file){
  vm.runInContext(fs.readFileSync(path.join(JS, file), 'utf8'), ctx, { filename: file });
  if (file === 'core.js') TYPES.fill(ctx);
}
function get(ctx, expr){ return vm.runInContext(expr, ctx); }

// ============ 1) TYP „Rohová" VO VKLADACEJ KARTE =============================
{
  const BTNS = ['lower', 'upper', 'corner_blind', 'dishwasher', 'board']
    .map(t => fakeEl({ 'data-ins-type': t, 'aria-pressed': 'false' }));
  const ctx = mkCtx();
  ctx.document.querySelectorAll = sel => (sel.indexOf('#insertTypeRow') === 0 ? BTNS : []);
  load(ctx, 'core.js');
  load(ctx, 'insert_state.js');
  load(ctx, 'form.js');
  const NXI = get(ctx, 'NXInsert');
  ok(NXI.setInsertType('corner_blind'), 'klik na Rohová zmeni stav');
  eq(NXI.insertType(), 'corner_blind', 'typ vkladania = rohová');
  eq(NXI.state.kind, 'cabinet', 'rohová je korpus (nie doska)');
  ctx.syncInsertTypeButtons();
  eq(BTNS.map(b => b.getAttribute('aria-pressed')), ['false', 'false', 'true', 'false', 'false'],
     'aria-pressed zrkadli stav (jediné stlačené je Rohová)');
  ok(BTNS[2].classList.contains('on') && !BTNS[0].classList.contains('on'), '.on nesie len Rohová');
  eq(NXI.setInsertType('corner_blind'), false, 'klik na už zvolený typ nič nerobí');
  const LIB = [{ name: 'Rohova 1100 vpravo', kind: 'cabinet', config: { type: 'corner_blind', corner_side: 'right' } },
               { name: 'Dolna klasik', kind: 'cabinet', config: { type: 'lower' } },
               { name: 'Umyvacka 60', kind: 'cabinet', config: { type: 'dishwasher' } }];
  eq(NXI.templatesForType(LIB, 'corner_blind').map(t => t.name), ['Rohova 1100 vpravo'], 'šablóny len rohové');
  eq(NXI.templatesForType(LIB, 'lower').map(t => t.name), ['Dolna klasik'], 'dolná rohovú nevidí');
  NXI.setInsertType('lower');
  ctx.syncInsertTypeButtons();
  eq(BTNS[2].getAttribute('aria-pressed'), 'false', 'návrat na Dolnú Rohovú odznačí');
  // Predvolby: zdroj karty pri rohovej (DEFAULTS zo servera) nesie stranu a
  // dverovu cast — register ich podrzi pre preflight.
  // ROH-B1: dverova cast je POLE formulara; register drzi stranu (prepinac)
  // a ucinnu hrubku CR 2 (minimum sirky).
  eq(ctx.nxCornerDraftOf({ type: 'corner_blind', corner_side: 'left', corner_door_w: 450, corner_cr1: 80, corner_th2: 19 }),
     { corner_side: 'left', corner_th2: 19 }, 'register rohovej = strana + hrúbka CR 2 (nič viac)');
  eq(ctx.nxCornerDraftOf({ type: 'lower', corner_side: 'left' }), null, 'iný typ register nemá');
  eq(ctx.nxCornerDraftOf(null), null, 'bez zdroja nič');
}

// ============ 2) + 3) NAHLAD OD OTVORU A PARITA ==============================
function previewCtx(){
  const svg = fakeEl();
  const ctx = mkCtx({ preview: svg });
  load(ctx, 'core.js');
  load(ctx, 'preview.js');
  ctx.__svg = svg;
  ctx.__fields = {};
  ctx.numv = id => (ctx.__fields[id] === undefined ? NaN : parseFloat(ctx.__fields[id]));
  ctx.val = id => (ctx.__fields[id] === undefined ? '' : String(ctx.__fields[id]));
  ctx.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  ctx.NXIcons = { svg: id => '<svg><use href="#i-' + id + '"/></svg>', set(){} };
  ctx.clearFrontHover = () => {};
  ctx.computeZones = () => [{ id: 'Z1', leaf: true, x: 18, z: 168, w: 1064, h: 676, shelves: 1 }];
  ctx.fullZoneId = z => 'CAB-1-' + z;
  ctx.PALETTE = ['#aaa'];
  ctx.getInsertKind = () => 'cabinet';
  ctx.selectedCabId = 'CAB-1';
  ctx.hwItems = [];
  ctx.currentZoneTree = null;
  return ctx;
}
function render(ctx, type, mode, fields, opening, items, slots, hw){
  vm.runInContext('pvUserView = false; pvView = null; frontDraft = null;', ctx);
  ctx.setType(type);
  ctx.__fields = Object.assign({ width: 1100, height: 862, depth: 510, thickness: 18, floor_height: 150,
                                 fr_gap_left: 2, fr_gap_right: 2, fr_gap: 3, fr_gap_top: 5, top_mode: 'full',
                                 back_mode: 'overlay' }, fields || {});
  ctx.frontOpening = opening;
  ctx.frontItems = items;
  ctx.frontSlots = slots || {};
  ctx.hwItems = hw || [];
  vm.runInContext('previewMode = ' + JSON.stringify(mode), ctx);
  ctx.renderPreview();
  return ctx.__svg.innerHTML;
}
// Obdlzniky ciel (vypln dvierok `#e0f2f4`) v mm SCENY (pad 14 odpocitany).
function doorRects(svg){
  const out = [];
  const re = /<rect x="([-\d.]+)" y="[-\d.]+" width="([-\d.]+)" height="[-\d.]+" fill="#e0f2f4"/g;
  let m;
  while ((m = re.exec(svg))) out.push([Math.round((parseFloat(m[1]) - 14) * 100) / 100, parseFloat(m[2])]);
  return out;
}
const CORNER_ITEM = [{ id: 'F1', type: 'door', mode: 'auto', z: 150, height: 707, wings_n: 1, profile: 'none',
                       direction: 'right' }];
{
  const ctx = previewCtx();
  // Ciste jadro otvoru.
  eq(ctx.nxFrontOpeningFor('lower', 900, { x0: 650, w: 450 }), { x0: 0, w: 900 },
     'dolná serverový otvor rohovej IGNORUJE (celá šírka)');
  eq(ctx.nxFrontOpeningFor('corner_blind', 1100, { x0: 650, w: 450, z0: 150, h: 712 }), { x0: 650, w: 450 },
     'rohová kreslí z otvoru servera');
  eq(ctx.nxFrontOpeningFor('corner_blind', 1100, null), null, 'rohová bez otvoru = neznámy (nie celá šírka)');
  eq(ctx.nxFrontOpeningFor('corner_blind', 1100, { x0: 0, w: 0 }), null, 'nulová šírka otvoru sa neberie');

  // Rohova vlavo: dvere 2–448 pri W 1100 (otvor 0/450, medzery 2/2).
  let s = render(ctx, 'corner_blind', 'fronts', {}, { x0: 0, w: 450, z0: 150, h: 712 }, CORNER_ITEM);
  eq(doorRects(s), [[2, 446]], 'rohová vľavo: dvere 2–448 (Čelá)');
  ok(s.indexOf('>446<') >= 0, 'kóta šírky čiel = šírka dverí 446, nie 1096');
  ok(s.indexOf('>1096<') < 0, 'kóta cez celú šírku zmizla');
  // Rohova vpravo: dvere 652–1098.
  s = render(ctx, 'corner_blind', 'fronts', {}, { x0: 650, w: 450, z0: 150, h: 712 }, CORNER_ITEM);
  eq(doorRects(s), [[652, 446]], 'rohová vpravo: dvere 652–1098 (Čelá)');
  ok(/<text x="889"[^>]*>F1 · dvierka/.test(s), 'popis čela v strede DVEROVEJ časti (14 + 650 + 225)');
  // Ziva sirka 1200 vpravo: server posunie otvor na 750 — kresba ide s nim.
  s = render(ctx, 'corner_blind', 'fronts', { width: 1200 }, { x0: 750, w: 450 }, CORNER_ITEM);
  eq(doorRects(s), [[752, 446]], 'živá šírka 1200: dvere 752–1198 (x0 = W − D zo servera)');
  // Vkladanie (draft ciel z karty) — ta ista kresba od otvoru.
  ctx.collectFronts = () => ({ gap: 3, gap_top: 5, gap_bottom: 0, gap_left: 2, gap_right: 2,
                               items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1' }] });
  s = render(ctx, 'corner_blind', 'insert', {}, { x0: 0, w: 450 }, null);
  eq(doorRects(s), [[2, 446]], 'vkladanie rohovej: dvere len v dverovej časti');
  // Otvor este nie je znamy: ZIADNE dvere (nie cez celu sirku) a ziadna veta.
  s = render(ctx, 'corner_blind', 'fronts', {}, null, CORNER_ITEM);
  eq(doorRects(s), [], 'rohová bez otvoru: čelá sa nekreslia');
  ok(s.indexOf('nastav v sekcii') < 0, 'a veta „nastav v sekcii Čelá" neklame');
  s = render(ctx, 'corner_blind', 'insert', {}, null, null);
  eq(doorRects(s), [], 'ani vo vkladaní pred prvým preflightom');
  // Kovanie + ghost vrstvy od otvoru: zaves pri ROHU (dvere vlavo, panty vpravo).
  const HW = [{ owner_part_key: 'front:F1/wing:single', generic_type: 'hinge', quantity: 2, label: 'Závesy' }];
  const SLOT_R = { F1: { wings_n: 1, slots: [{ wing: 'single', part_key: 'front:F1/wing:single', state: 'right' }] } };
  const g = { W: 1100, H: 862, t: 18, fh: 150, gapLeft: 2, gapRight: 2, gap: 3, fx0: 0, fw: 450,
              slots: SLOT_R, fronts: CORNER_ITEM };
  const marks = ctx.nxHwMarks(HW, g);
  eq(marks.length, 2, '2 závesy = 2 značky');
  ok(marks.every(m => m.x === 2 + 446 - 26), 'rohová vľavo: pánty pri rohu (pravá hrana dverí 448 − 26)');
  const gR = Object.assign({}, g, { fx0: 650, slots: { F1: { wings_n: 1, slots: [{ wing: 'single', state: 'left' }] } } });
  ok(ctx.nxHwMarks(HW, gR).every(m => m.x === 652 + 26), 'rohová vpravo, pánty vľavo (pri rohu) = 652 + 26');
  // Pasy medzier (N26) a kota: od otvoru.
  ctx.pvSetGapFocus(true);
  s = render(ctx, 'corner_blind', 'fronts', {}, { x0: 650, w: 450 }, CORNER_ITEM);
  ok(/<rect x="664" y="[-\d.]+" width="450"[^>]*fill="#fff3e0"/.test(s), 'pás medzery = dverová časť (650…1100)');
  ctx.pvSetGapFocus(false);

  // ---------- PARITA: ostatne typy su pixel po pixeli rovnake ---------------
  const LOW_ITEMS = [{ id: 'F1', type: 'drawer_front', mode: 'fixed', z: 102, height: 180, wings_n: 1, profile: 'none' },
                     { id: 'F2', type: 'door', mode: 'auto', z: 285, height: 433, wings_n: 2, profile: 'none' }];
  const HW2 = [{ owner_part_key: 'front:F2/wing:left', generic_type: 'hinge', quantity: 2, label: 'Závesy' },
               { owner_part_key: 'front:F2/wing:right', generic_type: 'hinge', quantity: 2, label: 'Závesy' },
               { owner_part_key: 'front:F1/panel', generic_type: 'slide', quantity: 1, label: 'Výsuv' },
               { owner_part_key: null, generic_type: 'leg', quantity: 4, label: 'Nohy' }];
  const LOWF = { width: 900, height: 720, depth: 560, floor_height: 100, fr_gap_top: 2, dw_class: 600,
                 dw_body_height: 820, dw_front_bottom: 64 };
  let same = 0;
  ['lower', 'upper', 'dishwasher'].forEach(function(t){
    ['cab', 'fronts', 'hw', 'zones', 'insert'].forEach(function(mode){
      const a = render(ctx, t, mode, LOWF, null, mode === 'insert' ? null : LOW_ITEMS, {}, HW2);
      const b = render(ctx, t, mode, LOWF, { x0: 650, w: 450, z0: 150, h: 712 }, mode === 'insert' ? null : LOW_ITEMS, {}, HW2);
      if (a === b && a.length > 0) same++;
    });
  });
  eq(same, 15, 'dolná · horná · slot × 5 projekcií: otvor rohovej kresbu nezmení ani o pixel');
  // Pevne cisla dolnej (900, medzery 2/2): cela 2–898.
  s = render(ctx, 'lower', 'fronts', LOWF, null, LOW_ITEMS);
  eq(doorRects(s), [[2, 446.5], [451.5, 446.5]], 'dolná: dvojkrídlo 2–448,5 / 451,5–898 (dnešné čísla)');
  ok(/<rect x="16" y="[-\d.]+" width="896" height="[-\d.]+" fill="#bfe3e8"/.test(s), 'dolná: zásuvka 2–898');
  ok(s.indexOf('>896<') >= 0, 'dolná: kóta šírky čiel 896');
  const gl = { W: 900, H: 720, t: 18, fh: 100, gapLeft: 2, gapRight: 2, gap: 3, fronts: LOW_ITEMS };
  const ml = ctx.nxHwMarks(HW2, gl).filter(m => m.kind === 'hinge');
  eq(ml.map(m => m.x), [28, 28, 872, 872], 'dolná 2-krídlová: závesy 28 / 872 ako doteraz');
  eq(ctx.nxFrontsExtent(LOW_ITEMS, 900, 720, 2, 2), ctx.nxFrontsExtent(LOW_ITEMS, 900, 720, 2, 2, 0, 900),
     'rozsah čiel bez otvoru = otvor 0…W');
  eq(ctx.nxFrontsExtent(CORNER_ITEM, 1100, 862, 2, 2, 650, 450).maxX, 1100, 'rohová vpravo: rozsah v obryse');
}

// ============ 4) ZNACKY ZAVESOV PODLA SMERU (C8) =============================
{
  const ctx = previewCtx();
  const e = st => ({ wings_n: 1, slots: [{ wing: 'single', state: st }] });
  eq(ctx.nxHingeSide('single', 0, 1, e('left')), 'left', 'smer vľavo = pánty vľavo');
  eq(ctx.nxHingeSide('single', 0, 1, e('right')), 'right', 'smer vpravo = pánty vpravo (predtým vždy vľavo)');
  eq(ctx.nxHingeSide('single', 0, 1, e(vm.runInContext('FRONT_DIR_UNSET', ctx))), 'unknown', 'neurčené = „?"');
  eq(ctx.nxHingeSide('single', 0, 1, e(null)), null, 'legacy (kľúč smeru nie je) = žiadna značka');
  eq(ctx.nxHingeSide('single', 0, 1, null), null, 'bez slotov servera stranu nehádame');
  eq(ctx.nxHingeSide('left', 0, 2, null), 'left', 'ľavé krídlo 2-krídla = odvodené');
  eq(ctx.nxHingeSide('right', 1, 2, null), 'right', 'pravé krídlo 2-krídla = odvodené');
  eq(ctx.nxHingeSide('p1', 0, 3, null), 'left', 'prvé z 3 = vľavo');
  eq(ctx.nxHingeSide('p3', 2, 3, null), 'right', 'posledné z 3 = vpravo');
  eq(ctx.nxHingeSide('p2', 1, 3, { wings_n: 3, slots: [{ wing: 'p2', state: 'right' }] }), 'right',
     'stredné krídlo podľa slotu');
  const HW = [{ owner_part_key: 'front:F1/wing:single', generic_type: 'hinge', quantity: 2, label: 'Závesy' }];
  const g = { W: 600, H: 720, t: 18, fh: 100, gapLeft: 2, gapRight: 2, gap: 3,
              fronts: [{ id: 'F1', type: 'door', z: 102, height: 616, wings_n: 1 }] };
  const at = st => ctx.nxHwMarks(HW, Object.assign({}, g, { slots: { F1: e(st) } }));
  eq(at('left').map(m => m.x), [28, 28], 'dolná, smer vľavo: pánty vľavo');
  eq(at('right').map(m => m.x), [572, 572], 'dolná, smer vpravo: pánty vpravo (oprava C8)');
  const unk = at(vm.runInContext('FRONT_DIR_UNSET', ctx));
  ok(unk.length === 2 && unk.every(m => m.unknown && m.x === 300), 'neurčené: „?" v strede krídla');
  eq(at(null), [], 'legacy: nič sa nekreslí');
  const q = ctx.hwMarkSvg(unk[0], x => x, z => z, false);
  ok(q.indexOf('>?</text>') >= 0 && q.indexOf('#e65100') >= 0, '„?" v jantári (--nx-warn-fg)');
  ok(q.indexOf('data-owner="front:F1/wing:single"') >= 0, 'značka „?" ostáva klikateľná na vlastníka');
}

// ============ 5) PREFLIGHT: STRANA PRI VKLADANI, OTVOR AKTUALNEJ REVIZIE =====
{
  const ctx = mkCtx({ frontRows: fakeEl(), frontDraftMessage: fakeEl() });
  load(ctx, 'core.js');
  load(ctx, 'insert_state.js');
  load(ctx, 'form.js');
  const SENT = [];
  ctx.sketchup = { front_preflight: j => SENT.push(JSON.parse(j)) };
  ctx.window.sketchup = ctx.sketchup;
  ctx.nxDocGuid = () => 'G-1';
  ctx.getInsertKind = () => 'cabinet';
  ctx.selectedCabId = null;
  ctx.DEFAULTS = { corner_blind: { width: 1100, height: 862, floor_height: 150 }, lower: { width: 600, height: 720, floor_height: 100 } };
  let F = { width: '1100', height: '862', floor_height: '150', corner_door_w: '500' };
  ctx.val = id => (F[id] === undefined ? '' : F[id]);
  ctx.numv = id => parseFloat(F[id]);
  ctx.evalDim = v => parseFloat(v);
  ctx.collectFronts = () => ({ gap: 3, gap_top: 5, gap_bottom: 0, gap_left: 2, gap_right: 2,
                               items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1' }] });
  ['updateFrontDirBadges', 'updateFrontPlaceholders', 'refreshFrontCards', 'renderPreview',
   'cancelCabinetEdits'].forEach(k => { ctx[k] = () => {}; });
  ctx.setType('corner_blind');
  ctx.nxSetCornerDraft({ type: 'corner_blind', corner_side: 'right' });
  ctx.nxFrontDraftReset();
  ctx.nxFrontDraftAsk();
  eq(SENT.length, 1, 'preflight sa opýta');
  eq([SENT[0].type, SENT[0].corner_side, SENT[0].corner_door_w], ['corner_blind', 'right', 500],
     'vkladanie rohovej posiela stranu (register) a dverovú časť (pole riadku rohovej)');
  ok(!Object.prototype.hasOwnProperty.call(SENT[0], 'corner_cr1'), 'CR sa na otvor nepýta — neposiela sa');
  eq(get(ctx, 'frontOpening'), null, 'kým server neodpovie, otvor nie je');
  const r1 = SENT[0].revision;
  ctx.nxFrontPreflightResult({ revision: r1, model_guid: 'G-1', cabinet_id: '', insert_session: SENT[0].insert_session,
                               valid: true, items: [], errors: [], slots: {},
                               opening: { x0: 600, w: 500, z0: 150, h: 712 } });
  eq(get(ctx, 'frontOpening'), { x0: 600, w: 500, z0: 150, h: 712 }, 'odpoveď aktuálnej revízie uloží otvor');
  // Ziva sirka: novy dotaz; stara odpoved (revizia r1) sa zahodi.
  F = Object.assign({}, F, { width: '1200' });
  ctx.nxFrontDraftAsk();
  eq(SENT.length, 2, 'zmena šírky = nový preflight');
  ctx.nxFrontPreflightResult({ revision: r1, model_guid: 'G-1', cabinet_id: '', insert_session: SENT[1].insert_session,
                               valid: true, items: [], errors: [], slots: {}, opening: { x0: 999, w: 1 } });
  eq(get(ctx, 'frontOpening').x0, 600, 'stará odpoveď otvor neprepíše');
  ctx.nxFrontPreflightResult({ revision: SENT[1].revision, model_guid: 'G-1', cabinet_id: '',
                               insert_session: SENT[1].insert_session, valid: false, items: [], slots: {},
                               errors: [{ message: 'Medzera dverí pri rohu musí byť 1–20 mm.' }],
                               opening: { x0: 700, w: 500, z0: 150, h: 712 } });
  eq(get(ctx, 'frontOpening').x0, 700, 'aj odmietnutá odpoveď nesie otvor pre živú šírku (W − D)');
  ctx.nxFrontPreflightResult({ revision: SENT[1].revision, model_guid: 'G-1', cabinet_id: '',
                               insert_session: SENT[1].insert_session, valid: false, items: [], slots: {},
                               errors: [{ message: 'x' }] });
  eq(get(ctx, 'frontOpening').x0, 700, 'odpoveď bez otvoru nechá posledný známy');
  ctx.nxFrontDraftReset();
  eq(get(ctx, 'frontOpening'), null, 'nová identita otvor zahodí');
  // Iny typ: polia rohovej v preflighte nie su (signatura dolnej sa nemeni).
  ctx.setType('lower');
  ctx.nxSetCornerDraft({ type: 'lower' });
  ctx.nxFrontDraftAsk();
  const last = SENT[SENT.length - 1];
  eq(Object.keys(last).filter(k => k.indexOf('corner_') === 0), [], 'dolná: žiadne polia rohovej');
  eq(last.type, 'lower');

  // ---------- modal „Uložiť ako šablónu": typ rohovej zamknuty ----------------
  const OPTS = ['lower', 'upper', 'corner_blind', 'dishwasher'].map(v => Object.assign(fakeEl(), { value: v }));
  const SEL = Object.assign(fakeEl(), { options: OPTS });
  const TIP = fakeEl({ 'data-tip': 'slot' });
  TIP.hidden = true;
  const ids = { tplSaveType: SEL, tplSaveTypeTip: TIP };
  ctx.el = id => ids[id] || null;
  ctx.setVal = (id, v) => { if (ids[id]) ids[id].value = String(v); };
  ctx.nxSyncTplSaveType('corner_blind');
  eq([SEL.value, SEL.disabled, TIP.hidden], ['corner_blind', true, false], 'rohová: typ zamknutý + bublina');
  ok(TIP.getAttribute('data-tip').indexOf('Rohová skrinka') === 0, 'bublina hovorí o rohovej, nie o slote');
  eq(OPTS.map(o => o.hidden), [false, false, false, true], 'ponúka sa len Rohová (Umývačka skrytá)');
  ctx.nxSyncTplSaveType('lower');
  eq([SEL.value, SEL.disabled, TIP.hidden], ['lower', false, true], 'dolná: typ voľný');
  eq(OPTS.map(o => o.hidden), [false, false, true, true], 'nad dolnou sa Rohová ani Umývačka neponúka');
  ctx.nxSyncTplSaveType('dishwasher');
  ok(SEL.disabled && TIP.getAttribute('data-tip').indexOf('slot umývačky') > 0, 'slot ostáva zamknutý ako doteraz');
}

// ============ 6) NAHLAD NOH PRE ROHOVU =======================================
{
  const ctx = mkCtx();
  ctx.NXTypes = TYPES.NXTypes; // H12c: register typov (bez core.js v tomto kontexte)
  load(ctx, 'hardware.js');
  let TYPE = 'corner_blind';
  ctx.getType = () => TYPE;
  ctx.selectedCabId = null;
  ctx.NXInsert = { state: { kind: 'cabinet', lastMode: 'insert' } };
  const SHOWN = [];
  ctx.nxLegsSetText = (t) => { SHOWN.push(t); return true; };
  ctx.nxLegsHideRow = () => false;
  eq(['lower', 'corner_blind', 'upper', 'dishwasher'].map(t => ctx.nxLegsTypeHasLegs(t)), [true, true, false, false],
     'nohy vo vkladacej karte: dolná a rohová, nie horná ani slot');
  const gen = get(ctx, 'legsGen');
  ok(ctx.nxLegsInsertResult({ gen: gen, text: '6× noha AXILO H150', tone: 'ok' }),
     'odpoveď servera pre ROHOVÚ riadok naplní (predtým sa zahodila)');
  eq(SHOWN, ['6× noha AXILO H150'], 'text je zo servera');
  TYPE = 'upper';
  eq(ctx.nxLegsInsertResult({ gen: gen, text: '4× noha', tone: 'ok' }), false, 'horná ostáva bez nôh');
}

// ============ 7) PREDRECENZIA: NAPOJENIA (bridge.js · form.js) ===============
// MUTACIE (overene rucne pri oprave, kazda zhodi uvedenu aserciu):
//   M4 zmaz `nxSetCornerDraft(src);` v materializeInsertCabCard
//      -> „sablona pravej rohovej: preflight karty dostane stranu zo sablony"
//   M5 zmaz riadok `frontOpening = … p.front_opening …` v nxAdoptCabinetDraft
//      -> „loadSelected: otvor ulozeneho stavu z payloadu"
//   M6 `!holdDraft &&` z volania nxAdoptCabinetDraft v loadSelected
//      -> „holdDraft: rozpisany navrh sa neprepise"
//   M7 zmaz `nxInsertDraftResume()` v historyRefresh / clearSelected
//      -> „Spat vo vkladani: otvor sa vypyta znova" / „prazdny vyber vkladanie -> vkladanie"
//   M8 `pvHingeSlots` prestane citat `frontSlotsSaved`
//      -> „pocas preflightu kresli z ulozenych slotov (P3)"
function formBridgeCtx(){
  const ctx = mkCtx({ frontRows: fakeEl(), frontDraftMessage: fakeEl() });
  load(ctx, 'core.js');
  load(ctx, 'insert_state.js');
  load(ctx, 'form.js');
  load(ctx, 'bridge.js');
  ctx.__sent = [];
  ctx.sketchup = { front_preflight: j => ctx.__sent.push(JSON.parse(j)) };
  ctx.window.sketchup = ctx.sketchup;
  ctx.nxDocGuid = () => 'G-1';
  ctx.getInsertKind = () => 'cabinet';
  ctx.DEFAULTS = { corner_blind: { type: 'corner_blind', width: 1100, height: 862, floor_height: 150,
                                   corner_side: 'left', corner_door_w: 450, corner_cr1: 80, corner_cr2: 80 } };
  ctx.__f = { width: '1100', height: '862', floor_height: '150' };
  ctx.val = id => (ctx.__f[id] === undefined ? '' : ctx.__f[id]);
  ctx.numv = id => parseFloat(ctx.__f[id]);
  ctx.evalDim = v => parseFloat(v);
  ctx.collectFronts = () => ({ gap: 3, gap_top: 5, gap_bottom: 0, gap_left: 2, gap_right: 2,
                               items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1' }] });
  ctx.__renders = 0;
  ['updateFrontDirBadges', 'updateFrontPlaceholders', 'refreshFrontCards', 'cancelCabinetEdits',
   'setType', 'syncTemplateTiles', 'writeConstruction', 'buildFrontHwBadges', 'closeFrontCard', 'renderFronts',
   'applyInsertLockValues', 'renderInsertLocks', 'applyVisibility', 'refreshMaterialFilters', 'validateFields',
   'updateAvailable', 'refreshZoneUI', 'nxSectorMetaApply', 'nxSetModelGuid', 'cancelBoardEdits',
   'renderBoardCard', 'setSelected', 'setCabInfo', 'setCtxNote', 'setIdbar', 'setUiMode',
   'invalidateFrontPlaceholders', 'fitPreview', 'renderPartCard', 'renderHardware', 'clearCabinetMaterials']
    .forEach(k => { ctx[k] = () => {}; });
  ctx.renderPreview = () => { ctx.__renders++; };
  ctx.insertFrontsOf = () => ({});
  ctx.sanitizeTree = t => t;
  ctx.defaultTree = () => ({ id: 'Z1' });
  ctx.setType('corner_blind');
  vm.runInContext("cabTypeVal = 'corner_blind'", ctx);
  return ctx;
}
function reply(ctx, req, opening){
  ctx.nxFrontPreflightResult({ revision: req.revision, model_guid: 'G-1', cabinet_id: req.cabinet_id,
                               insert_session: req.insert_session, valid: true, items: [], errors: [], slots: {},
                               opening: opening });
}
{
  // --- (M4) sablona pravej rohovej vo vkladacej karte
  const ctx = formBridgeCtx();
  const TPL = { name: 'Rohova P', kind: 'cabinet',
                config: { type: 'corner_blind', corner_side: 'right', corner_door_w: 500, width: 1100 } };
  const NXI = get(ctx, 'NXInsert');
  NXI.state.type = 'corner_blind'; NXI.state.kind = 'cabinet'; NXI.state.template = 'Rohova P';
  ctx.findTemplateFor = () => TPL;
  ctx.materializeInsertCabCard();
  ctx.nxFrontDraftReset();
  ctx.nxFrontDraftAsk();
  const req = ctx.__sent[ctx.__sent.length - 1];
  // ROH-B1: dverova cast ide z POLA (writeConstruction je tu stub — pole
  // drzi predvolbu); strana zo sablony cez register.
  eq([req.corner_side, req.corner_door_w], ['right', 450],
     'šablóna pravej rohovej: preflight karty dostane stranu zo šablóny (M4)');

  // --- (M7) Spat vo vkladani: NX.historyRefresh
  reply(ctx, req, { x0: 600, w: 500, z0: 150, h: 712 });
  eq(get(ctx, 'frontOpening').x0, 600, 'otvor šablóny je známy');
  const before = ctx.__sent.length;
  ctx.window.NX.historyRefresh('G-1');
  eq(ctx.__sent.length, before + 1, 'Späť vo vkladaní: otvor sa vypýta znova (M7)');
  ok(ctx.__renders > 0, 'a náhľad sa prekreslí');
  reply(ctx, ctx.__sent[ctx.__sent.length - 1], { x0: 600, w: 500, z0: 150, h: 712 });
  eq(get(ctx, 'frontOpening').x0, 600, 'po odpovedi sú dvere späť (nie frontsPending)');
  ctx.window.NX.historyRefresh('G-INY');
  eq(get(ctx, 'frontOpening').x0, 600, 'Späť v inom dokumente sa karty nedotkne');

  // --- (M7) prazdny vyber vkladanie -> vkladanie: NX.clearSelected
  const b2 = ctx.__sent.length;
  ctx.window.NX.clearSelected('G-1');
  eq(ctx.__sent.length, b2 + 1, 'prázdny výber vkladanie → vkladanie: preflight znova (M7)');
  reply(ctx, ctx.__sent[ctx.__sent.length - 1], { x0: 600, w: 500, z0: 150, h: 712 });
  eq(get(ctx, 'frontOpening').w, 500, 'otvor obnovený');

  // Oznacena skrinka: resume nic neposiela (otvor prinesie jej loadSelected).
  ctx.selectedCabId = 'CAB-1';
  vm.runInContext("selectedCabId = 'CAB-1'", ctx);
  eq(ctx.nxInsertDraftResume(), false, 'pri označenej skrinke resume nepýta nič');
  vm.runInContext('selectedCabId = null', ctx);
}
{
  // --- (M5) nxAdoptCabinetDraft: payload oznacenej skrinky
  const ctx = formBridgeCtx();
  const SL = { F1: { wings_n: 1, slots: [{ wing: 'single', state: 'left' }] } };
  ctx.nxAdoptCabinetDraft({ type: 'corner_blind', corner_side: 'right', corner_door_w: 450,
                            front_opening: { x0: 650, w: 450, z0: 150, h: 712 }, front_slots: SL });
  eq(get(ctx, 'frontOpening'), { x0: 650, w: 450, z0: 150, h: 712 }, 'loadSelected: otvor uloženého stavu z payloadu (M5)');
  eq(get(ctx, 'frontSlotsSaved'), SL, 'uložené sloty smeru (značky závesov)');
  eq(get(ctx, 'cornerDraft'), { corner_side: 'right' }, 'register rohovej z payloadu (strana; dverová časť je pole)');
  ctx.nxAdoptCabinetDraft({ type: 'lower' });
  eq([get(ctx, 'frontOpening'), get(ctx, 'frontSlotsSaved'), get(ctx, 'cornerDraft')], [null, null, null],
     'payload bez kľúčov = nič (staršie okno, iný typ)');
  // (M6) v loadSelected sa napojenie vola LEN mimo rozpisaneho navrhu.
  const br = fs.readFileSync(path.join(JS, 'bridge.js'), 'utf8');
  const ls = br.slice(br.indexOf('loadSelected: function(c){'), br.indexOf('loadBoard: function(b){'));
  ok(ls.indexOf("if (!holdDraft && typeof nxAdoptCabinetDraft === 'function') nxAdoptCabinetDraft(c);") > 0,
     'holdDraft: rozpísaný návrh sa neprepíše (M6)');
  ok(ls.indexOf('front_opening') < 0, 'loadSelected nemá druhé miesto, ktoré by otvor plnilo');
  ok(ls.indexOf('nxFrontDraftReset()') < ls.indexOf('nxAdoptCabinetDraft(c)'), 'reset identity ide PRED prevzatím payloadu');
}
{
  // --- (P3) znacky zavesov z ULOZENYCH slotov, aj ked preflight bezi
  const ctx = previewCtx();
  const SL = { F1: { wings_n: 1, slots: [{ wing: 'single', state: 'right' }] } };
  ctx.frontSlotsSaved = SL;
  ctx.frontSlots = null;                       // preflight prave bezi
  eq(ctx.pvHingeSlots(), SL, 'počas preflightu kreslí z uložených slotov (P3)');
  ctx.frontSlots = {};                         // neplatny navrh ciel
  eq(ctx.pvHingeSlots(), SL, 'pri neplatnom návrhu tiež');
  ctx.frontSlotsSaved = null;
  ctx.frontSlots = { F2: { wings_n: 1, slots: [] } };
  eq(ctx.pvHingeSlots(), { F2: { wings_n: 1, slots: [] } }, 'bez uložených (vkladanie) sloty preflightu');
}

console.log(`test_roha2_vkladanie.js: ${n} asercii OK`);
