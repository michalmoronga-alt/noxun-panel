// ROH-B1 · K3 — ovládače rohovej a prepínač strany dverí (panel).
//   node tests/js/test_rohb1_ovladace.js
//
// Co sa tu strazi (package ROH-B1 + audit navrhu B1):
//   1) riadok rohovej je viditelny LEN pri rohovej (jeden riadok v #basicCard —
//      oznacena skrinka aj vkladacia karta), prepinac zrkadli stav,
//   2) ZBER poli: dolna, horna a slot neposlu ani jeden kluc navyse (parita
//      payloadu s mainom — doslovny zoznam klucov), rohova posle dverovu cast
//      a CR, STRANU nikdy; zapis zdroja (sablona / predvolby) do poli,
//   3) NAJMENSIA SIRKA = presne `corner_fit_width` (tabulka parity zdielana
//      s tests/pure/test_rohb1_strana.rb, aj desatinne — audit FIX 5), cervena
//      na sirke / dverovej casti / CR 1 + veta; ucinne hrubky z `corner_ctx`
//      preflightu (audit FIX 4: korpus 25 + celovy 19 -> 599),
//   4) PREPINAC na oznacenej rohovej: samostatny callback, neposiela ine polia;
//      klik pocas debounce aj pocas odoslaneho apply caka na potvrdenie
//      (audit FIX 1), pocas prepinania sa auto-apply odklada a korelovana
//      odpoved prevezme cela servera,
//   5) PREPINAC vo vkladacej karte: zrkadli navrh ciel (okraje, panty, strana
//      profilu) na OBE strany sablony s asymetrickymi medzerami (audit FIX 2);
//      vklad nesie zvolenu stranu LEN pri rohovej,
//   6) zmena dverovej casti spusti novy preflight (otvor sa prepocita).
//
// MUTACIE (overene pri davke, report):
//   M5 zber poli rohovej aj pri dolnej (`only` ignorovane) -> „2) parita"
//   M6 prepinac bez `nxCabinetAction` (neposka na apply)   -> „4) debounce"
//   M7 vkladanie bez zrkadla ciel                           -> „5) sablona"
//   M8 minimum z pevnej hrubky korpusu (bez ctx)            -> „3) ctx 599"
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

// Falosny uzol s tym, co form.js pri validacii a viditelnosti cita.
function fakeEl(id){
  const a = {};
  const cls = new Set();
  return {
    id: id, attrs: a, hidden: false, title: '', value: '', innerHTML: '', textContent: '',
    style: {}, dataset: {},
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k) ? a[k] : null; },
    setAttribute(k, v){ a[k] = String(v); },
    querySelector(){ return null; }, querySelectorAll(){ return []; }, closest(){ return null; },
    addEventListener(){}, removeAttribute(k){ delete a[k]; }, hasAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k); },
    classList: { add(c){ cls.add(c); }, remove(c){ cls.delete(c); }, contains(c){ return cls.has(c); },
                 toggle(c, on){ if (on === undefined ? !cls.has(c) : on) cls.add(c); else cls.delete(c); } }
  };
}
// Kontext panela: DOM sa vytvara na vyziadanie (kazde ID = jeden uzol).
function mkCtx(){
  const byId = {};
  const node = id => (byId[id] || (byId[id] = fakeEl(id)));
  const ctx = { console, setTimeout, clearTimeout, window: {}, JSON, Math };
  ctx.document = { getElementById: node, querySelectorAll: () => [], querySelector: () => null,
                   addEventListener(){}, activeElement: null, body: { appendChild(){}, setAttribute(){} },
                   createElement: () => fakeEl('') };
  vm.createContext(ctx);
  ['core.js', 'expr.js', 'insert_state.js', 'form.js'].forEach(function(f){
    vm.runInContext(fs.readFileSync(path.join(JS, f), 'utf8'), ctx, { filename: f });
  });
  ctx.__node = node;
  ctx.__status = [];
  ctx.NX = { setStatus(m, bad){ ctx.__status.push([m, !!bad]); } };
  ctx.nxDocGuid = () => 'G-1';
  ctx.nxDocPayload = (o, g) => JSON.stringify(Object.assign({}, o, { model_guid: g || 'G-1' }));
  ctx.DEFAULTS = {
    lower: { type: 'lower', width: 600, height: 720, depth: 510, thickness: 18, floor_height: 100 },
    corner_blind: { type: 'corner_blind', width: 1100, height: 720, depth: 510, thickness: 18, floor_height: 100,
                    corner_side: 'left', corner_door_w: 450, corner_cr1: 80, corner_cr2: 80, corner_th2: 18 }
  };
  return ctx;
}
function get(ctx, expr){ return vm.runInContext(expr, ctx); }
function setF(ctx, vals){ Object.keys(vals).forEach(k => { ctx.__node(k).value = String(vals[k]); }); }
const BASE = { width: 1100, height: 720, depth: 510, thickness: 18, floor_height: 100, bottom_mode: 'under_sides',
               top_mode: 'full', back_mode: 'overlay', back_thickness: 3, plinth_mode: 'none', plinth_recess: 40,
               rails_orientation: 'flat', rails_top_offset: 0, rail_depth: 100, back_setback: 0,
               top_front_setback: 0, back_rail_height: 100, dw_class: '600', dw_body_height: 820,
               dw_front_bottom: 100, corner_door_w: 450, corner_cr1: 80, corner_cr2: 80 };

// Doslovny zoznam klucov zberu v MAINE (v0.14.2) — parita payloadu.
const MAIN_KEYS = ['type', 'width', 'height', 'depth', 'thickness', 'floor_height', 'bottom_mode', 'top_mode',
  'back_mode', 'back_thickness', 'plinth_mode', 'plinth_recess', 'rails_orientation', 'rails_top_offset',
  'rail_depth', 'back_setback', 'top_front_setback', 'back_rail_height', 'dw_class', 'dw_body_height',
  'dw_front_bottom'];

// ============ 1) VIDITELNOST RIADKU + PREPINAC ================================
{
  const ctx = mkCtx();
  ['lower', 'upper', 'dishwasher', 'corner_blind'].forEach(function(t){
    ctx.setType(t);
    ctx.applyVisibility(t);
    eq(ctx.__node('cornerRow').hidden, t !== 'corner_blind', `riadok rohovej pri type ${t}: ${t === 'corner_blind' ? 'viditeľný' : 'skrytý'}`);
  });
  ctx.nxSetCornerDraft({ type: 'corner_blind', corner_side: 'right' });
  eq([ctx.__node('cornerSideL').getAttribute('aria-pressed'), ctx.__node('cornerSideR').getAttribute('aria-pressed')],
     ['false', 'true'], 'prepínač zrkadlí stranu (aria-pressed)');
  ok(ctx.__node('cornerSideR').classList.contains('on') && !ctx.__node('cornerSideL').classList.contains('on'), '.on nesie len zvolená strana');
  ctx.nxSetCornerDraft({ type: 'lower' });
  eq(ctx.nxCornerSide(), 'left', 'bez registra = predvoľba typu (vľavo)');
}

// ============ 2) ZBER POLI: PARITA S MAINOM ===================================
{
  const ctx = mkCtx();
  setF(ctx, BASE);
  ['lower', 'upper', 'dishwasher'].forEach(function(t){
    ctx.setType(t);
    const keys = Object.keys(ctx.collectConstruction());
    eq(keys, MAIN_KEYS, `${t}: zber = presne kľúče mainu (ani jeden navyše)`);
  });
  ctx.setType('corner_blind');
  const c = ctx.collectConstruction();
  eq(Object.keys(c), MAIN_KEYS.concat(['corner_door_w', 'corner_cr1', 'corner_cr2']), 'rohová: + dverová časť a CR');
  ok(!Object.prototype.hasOwnProperty.call(c, 'corner_side'), 'strana sa zberom NIKDY neposiela');
  setF(ctx, { corner_door_w: '' });
  eq(ctx.collectConstruction().corner_door_w, '', 'prázdne pole = server doplní predvoľbu');
  // Zapis zdroja: sablona prepise polia, chybajuci kluc = dflt (nie hodnota predoslej rohovej).
  setF(ctx, { corner_door_w: 700, corner_cr1: 200, corner_cr2: 150 });
  ctx.writeConstruction({ type: 'corner_blind', corner_door_w: 500, corner_cr1: 120 });
  eq([ctx.__node('corner_door_w').value, ctx.__node('corner_cr1').value, ctx.__node('corner_cr2').value],
     ['500', '120', '80'], 'šablóna 500 / 120 prepíše polia, chýbajúce CR 2 = predvoľba 80');
}

// ============ 3) NAJMENSIA SIRKA (parita + cervena + veta + ctx) ==============
{
  // Tabulka zdielana s tests/pure/test_rohb1_strana.rb: [D, CR 1, th2, t, minimum].
  const MIN_TABLE = [
    [450, 80, 18, 18, 584], [450, 80, 19, 18, 585],
    [300, 50, 18, 18, 404], [600, 120, 18, 25, 788],
    [800, 250, 18, 18, 1104], [250, 50, 19, 25, 369],
    [450, 80, 19, 25, 599], [450, 80, 18.6, 18, 584.6],
    [450.25, 80.1, 18, 18, 584.35]
  ];
  const core = require(path.join(JS, 'core.js'));
  MIN_TABLE.forEach(function(r){
    ok(Math.abs(core.nxCornerMinWidth(r[0], r[1], r[2], r[3]) - r[4]) < 1e-9, `minimum ${r.join(' / ')}`);
  });
  eq(core.nxCornerFitError(584.6, 450, 80, 18.6, 18), '', 'presne minimum 584,6 prejde (nie až 585 — audit FIX 5)');
  eq(core.nxCornerFitError(580, 450, 80, 18, 18),
     'Rohová zostava sa do šírky 580 mm nezmestí — dverová časť, CR 1, CR 2 a rohová výstuha potrebujú šírku aspoň 584 mm.',
     'veta = Ruby Construction.corner_error');

  const ctx = mkCtx();
  setF(ctx, BASE);
  ctx.setType('corner_blind');
  ctx.nxSetCornerDraft(ctx.DEFAULTS.corner_blind);
  setF(ctx, { width: 580 });
  ok(!ctx.validateFields(true), 'šírka 580 < 584: formulár neplatný (skrinka sa neprestaví)');
  ok(['width', 'corner_door_w', 'corner_cr1'].every(id => ctx.__node(id).classList.contains('bad')),
     'červená na šírke, dverovej časti a CR 1 (mockup O2)');
  ok(ctx.__node('cornerCr1Box').classList.contains('bad'), 'rámik CR 1 nesie červenú');
  ok(ctx.nxCabFieldError().indexOf('aspoň 584 mm') > 0, 'stavová veta s minimom');
  setF(ctx, { width: 584 });
  ok(ctx.validateFields(true), '584 = minimum prejde');
  eq(ctx.nxCabFieldError(), '', 'veta zmizne');
  // Rozsahy poli (len pri rohovej).
  setF(ctx, { width: 1100, corner_door_w: 900 });
  ok(!ctx.validateFields(true) && ctx.__node('corner_door_w').classList.contains('bad'), 'dverová časť 900 mimo 250–800 = červená');
  eq(ctx.nxCabFieldError(), 'Dverová časť 900 mm je mimo rozsahu 250–800 mm.', 'veta rozsahu');
  setF(ctx, { corner_door_w: 450, corner_cr2: 30 });
  ok(!ctx.validateFields(true) && ctx.__node('cornerCr2Box').classList.contains('bad'), 'CR 2 30 < 50 = červený rámik');
  setF(ctx, { corner_cr2: 80 });
  ok(ctx.validateFields(true), 'späť v rozsahu = platné');
  // Pri dolnej sa polia rohovej neposudzuju (su skryte).
  setF(ctx, { corner_door_w: 5000, width: 500 });
  ctx.setType('lower');
  ok(ctx.validateFields(true), 'dolná: skryté polia rohovej neblokujú (ani minimum rohovej)');
  ok(!ctx.__node('corner_door_w').classList.contains('bad') && !ctx.__node('cornerCr1Box').classList.contains('bad'),
     'a nie sú červené');
  // Ucinne hrubky navrhu (audit FIX 4): vkladanie, sablona korpus 25 + celovy 19.
  ctx.setType('corner_blind');
  setF(ctx, { corner_door_w: 450, width: 590, thickness: 18 });
  ok(ctx.validateFields(true), 'bez kontextu (18 / 18) by 590 prešlo');
  vm.runInContext('selectedCabId = null', ctx);
  eq(ctx.nxAdoptCornerCtx({ th2: 19, t: 25 }), true, 'corner_ctx z preflightu zmení hrúbky');
  ok(!ctx.validateFields(true), 's korpusom 25 a CR 2 19 je 590 málo');
  ok(ctx.nxCabFieldError().indexOf('aspoň 599 mm') > 0, 'minimum 450 + 80 + 19 + 2 × 25 = 599');
  eq(ctx.nxAdoptCornerCtx({ th2: 19, t: 25 }), false, 'rovnaký kontext = žiadna zmena');
  // Oznacena skrinka: t zo ZIVEHO pola (server ho vracia rovnako), th2 z payloadu.
  vm.runInContext("selectedCabId = 'CAB-1'", ctx);
  setF(ctx, { thickness: 18 });
  ok(ctx.validateFields(true), 'označená: t = pole 18 → 450 + 80 + 19 + 36 = 585 ≤ 590');
}

// ============ 4) PREPINAC NA OZNACENEJ ROHOVEJ ================================
function selCtx(){
  const ctx = mkCtx();
  setF(ctx, BASE);
  ctx.setType('corner_blind');
  vm.runInContext("selectedCabId = 'CAB-1'", ctx);
  ctx.nxSetCornerDraft({ type: 'corner_blind', corner_side: 'left', corner_th2: 18 });
  ctx.__sent = [];
  ctx.sketchup = { corner_side: j => ctx.__sent.push(['corner_side', JSON.parse(j)]),
                   apply_all: j => ctx.__sent.push(['apply_all', JSON.parse(j)]),
                   front_preflight: () => {} };
  ctx.window.sketchup = ctx.sketchup;
  ctx.collectFronts = () => ({ gap_left: 0, gap_right: 2, items: [{ id: 'F1', type: 'door', direction: 'right' }] });
  ctx.nxFrontDraftReady = () => true;
  return ctx;
}
{
  const ctx = selCtx();
  ctx.onCornerSide('left');
  eq(ctx.__sent.length, 0, 'klik na už zvolenú stranu nič neposiela');
  ctx.onCornerSide('right');
  eq(ctx.__sent.length, 1, 'klik na druhú stranu = jeden callback');
  eq(ctx.__sent[0][0], 'corner_side', 'samostatný callback (nie apply)');
  const p = ctx.__sent[0][1];
  eq(Object.keys(p).sort(), ['cabinet_id', 'corner_side', 'model_guid', 'switch_token'], 'payload nenesie žiadne iné polia');
  eq([p.cabinet_id, p.corner_side, p.model_guid], ['CAB-1', 'right', 'G-1'], 'identita skrinky aj dokumentu');
  eq(ctx.nxCornerSide(), 'left', 'prepínač ukáže novú stranu až po pushi servera (autorita je model)');
  // Pocas prepinania: druhy klik aj ina akcia cakaju, edity sa odkladaju.
  ctx.onCornerSide('right');
  eq(ctx.__sent.length, 1, 'druhý klik počas prepínania nič neposiela');
  let ran = false, failed = false;
  eq(ctx.nxCabinetAction(() => { ran = true; }, () => { failed = true; }), false, 'iná akcia počas prepínania čaká');
  ok(!ran && failed, 'a dostane fail');
  vm.runInContext('cabDraftDirty = true', ctx);
  ctx.flushCabinetEdits('CAB-1', 'G-1');
  eq(ctx.__sent.length, 1, 'auto-apply počas prepínania neodíde (odložený)');
  // Push prepnutia prisiel POCAS rozpisanej zmeny: holdDraft nechal stare cela.
  let rendered = null;
  ctx.renderFronts = f => { rendered = f; };
  ctx.renderPreview = () => {};
  const ECHO = { model_guid: 'G-1', cabinet_id: 'CAB-1', type: 'corner_blind', corner_side: 'right', corner_th2: 18,
                 fronts: { gap_left: 2, gap_right: 0, items: [{ id: 'F1', type: 'door', direction: 'left' }] },
                 front_opening: { x0: 650, w: 450, z0: 100, h: 620 }, front_items: [], front_slots: {} };
  ctx.nxRememberCabinetEcho(ECHO);
  ctx.nxCornerSideResult({ switch_token: 'iny', model_guid: 'G-1', cabinet_id: 'CAB-1', ok: true });
  ok(get(ctx, 'cornerSwitch') !== null, 'cudzia odpoveď (iný token) sa ignoruje');
  ctx.nxCornerSideResult({ switch_token: p.switch_token, model_guid: 'G-1', cabinet_id: 'CAB-1', ok: true });
  eq(get(ctx, 'cornerSwitch'), null, 'korelovaná odpoveď prepínanie ukončí');
  eq(rendered, ECHO.fronts, 'čelá sa prevzali zo servera (zrkadlo), nie zo starého formulára');
  eq(ctx.nxCornerSide(), 'right', 'strana z payloadu servera');
  eq(get(ctx, 'frontOpening'), ECHO.front_opening, 'otvor z payloadu servera');
  ok(get(ctx, 'applyTimer') !== null, 'odložený apply sa naplánuje až teraz');
  clearTimeout(get(ctx, 'applyTimer'));
}
{
  // Klik POCAS DEBOUNCE: najprv flush, prepnutie az po potvrdenom apply.
  const ctx = selCtx();
  ctx.validateFields = () => true;
  vm.runInContext('cabDraftDirty = true; applyTimer = setTimeout(function(){}, 99999); applyPendingGuid = "G-1"', ctx);
  ctx.onCornerSide('right');
  eq(ctx.__sent.map(s => s[0]), ['apply_all'], 'klik počas debounce: najprv sa odošle rozpísaná zmena');
  const tok = ctx.__sent[0][1].front_apply_token;
  ctx.nxFrontApplyResult({ front_apply_token: tok, model_guid: 'G-1', cabinet_id: 'CAB-1', ok: true });
  eq(ctx.__sent.map(s => s[0]), ['apply_all', 'corner_side'], 'prepnutie až po potvrdenom apply');
}
{
  // Klik POCAS ODOSLANEHO APPLY: caka na odpoved, pri odmietnuti sa neprepina.
  const ctx = selCtx();
  ctx.validateFields = () => true;
  vm.runInContext('cabDraftDirty = true', ctx);
  ctx.flushCabinetEdits('CAB-1', 'G-1');
  eq(ctx.__sent.map(s => s[0]), ['apply_all'], 'apply odišiel');
  const tok = ctx.__sent[0][1].front_apply_token;
  ctx.onCornerSide('right');
  eq(ctx.__sent.length, 1, 'klik počas odoslaného apply čaká');
  ctx.nxFrontApplyResult({ front_apply_token: tok, model_guid: 'G-1', cabinet_id: 'CAB-1', ok: false });
  eq(ctx.__sent.length, 1, 'odmietnutý apply = prepnutie sa nevykoná');
}
{
  // Zmena identity (ina skrinka, dokument, Spat) prepinanie zahodi.
  const ctx = selCtx();
  ctx.onCornerSide('right');
  ctx.nxFrontDraftReset();
  eq(get(ctx, 'cornerSwitch'), null, 'reset identity zahodí rozbehnuté prepínanie');
}

// ============ 5) PREPINAC VO VKLADACEJ KARTE ==================================
{
  const core = require(path.join(JS, 'core.js'));
  // Sablona LAVEJ rohovej: vonkajsi okraj 0, pri rohu 2, panty pri rohu (vpravo).
  const LEFT_TPL = { gap: 3, gap_top: 5, gap_bottom: 0, gap_left: 0, gap_right: 2,
                     items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1', direction: 'right', profile_edge: 'free' }] };
  const RIGHT_TPL = { gap: 3, gap_top: 5, gap_bottom: 0, gap_left: 2, gap_right: 0,
                      items: [{ id: 'F1', type: 'door', mode: 'auto', wings: '1', direction: 'left' }] };
  eq(core.nxCornerMirrorFronts(LEFT_TPL), Object.assign({}, LEFT_TPL, { gap_left: 2, gap_right: 0,
     items: [Object.assign({}, LEFT_TPL.items[0], { direction: 'left' })] }), 'zrkadlo ľavej šablóny');
  eq(core.nxCornerMirrorFronts(core.nxCornerMirrorFronts(RIGHT_TPL)), RIGHT_TPL, 'dvakrát = identita');
  eq(core.nxCornerMirrorFronts({ items: [{ id: 'F1', direction: 'unset', profile_edge: 'right' }] }).items[0],
     { id: 'F1', direction: 'unset', profile_edge: 'left' }, '`unset` ostáva, strana profilu sa zrkadlí');
  ok(!('direction' in core.nxCornerMirrorFronts({ items: [{ id: 'F1' }] }).items[0]), 'chýbajúci smer ostane chýbať');
  eq(LEFT_TPL.gap_left, 0, 'vstup sa nemení');

  [['right', LEFT_TPL], ['left', RIGHT_TPL]].forEach(function(c){
    const ctx = mkCtx();
    setF(ctx, BASE);
    ctx.setType('corner_blind');
    vm.runInContext('selectedCabId = null', ctx);
    ctx.nxSetCornerDraft({ type: 'corner_blind', corner_side: c[0] === 'right' ? 'left' : 'right' });
    let rendered = null, fields = 0, sent = 0;
    ctx.collectFronts = () => JSON.parse(JSON.stringify(c[1]));
    ctx.renderFronts = f => { rendered = f; };
    ctx.onField = () => { fields++; };
    ctx.sketchup = { corner_side: () => { sent++; } };
    ctx.window.sketchup = ctx.sketchup;
    ctx.onCornerSide(c[0]);
    eq(sent, 0, `vkladanie (${c[0]}): žiadny serverový zápis`);
    eq(ctx.nxCornerSide(), c[0], `vkladanie: register = ${c[0]}`);
    eq(rendered, core.nxCornerMirrorFronts(c[1]), `šablóna s asymetrickými medzerami → zrkadlo návrhu (${c[0]})`);
    eq([rendered.gap_left, rendered.gap_right], [c[1].gap_right, c[1].gap_left], 'okraj pri rohu ostane pri rohu');
    eq(fields, 1, 'preflight a náhľad sa prepočítajú (onField)');
  });

  // Vklad nesie zvolenu stranu LEN pri rohovej (actions.js insertCabinet).
  const ctx = mkCtx();
  vm.runInContext(fs.readFileSync(path.join(JS, 'actions.js'), 'utf8'), ctx, { filename: 'actions.js' });
  setF(ctx, BASE);
  vm.runInContext('selectedCabId = null', ctx);
  const INS = [];
  ctx.sketchup = { insert_cabinet: j => INS.push(JSON.parse(j)) };
  ctx.window.sketchup = ctx.sketchup;
  ctx.collectFronts = () => ({ items: [] });
  ctx.validateFields = () => true;
  ctx.setType('corner_blind');
  ctx.nxSetCornerDraft({ type: 'corner_blind', corner_side: 'right' });
  ctx.insertCabinet();
  eq([INS[0].type, INS[0].corner_side, INS[0].corner_door_w], ['corner_blind', 'right', 450], 'vklad rohovej nesie stranu a polia');
  ctx.setType('lower');
  ctx.insertCabinet();
  ok(!('corner_side' in INS[1]) && !('corner_door_w' in INS[1]), 'vklad dolnej žiadny kľúč rohovej');
  // Neplatny formular: konkretna veta krizovej kontroly.
  ctx.validateFields = () => false;
  ctx.nxCabFieldError = () => 'Rohová zostava sa do šírky 580 mm nezmestí — …';
  ctx.insertCabinet();
  eq(ctx.__status[ctx.__status.length - 1], ['Rohová zostava sa do šírky 580 mm nezmestí — …', true], 'vklad ukáže vetu minima');
}

// ============ 6) ZMENA DVEROVEJ CASTI -> NOVY PREFLIGHT =======================
{
  const ctx = mkCtx();
  setF(ctx, BASE);
  ctx.setType('corner_blind');
  vm.runInContext('selectedCabId = null', ctx);
  ctx.getInsertKind = () => 'cabinet';
  const SENT = [];
  ctx.sketchup = { front_preflight: j => SENT.push(JSON.parse(j)) };
  ctx.window.sketchup = ctx.sketchup;
  ctx.collectFronts = () => ({ gap: 3, gap_top: 5, gap_bottom: 0, gap_left: 2, gap_right: 2, items: [] });
  ['updateFrontDirBadges', 'updateFrontPlaceholders', 'refreshFrontCards', 'renderPreview'].forEach(k => { ctx[k] = () => {}; });
  ctx.nxSetCornerDraft({ type: 'corner_blind', corner_side: 'left' });
  ctx.NXInsert.state.materials = { material_id: 'KORP25', front_material_id: 'CELO19' };
  ctx.nxFrontDraftAsk();
  eq([SENT[0].corner_side, SENT[0].corner_door_w, SENT[0].thickness], ['left', 450, 18], 'preflight: strana, dverová časť, hrúbka');
  eq([SENT[0].material_id, SENT[0].front_material_id], ['KORP25', 'CELO19'], 'vkladanie: materiály návrhu (šablóna) pre corner_ctx');
  ok(!('corner_cr1' in SENT[0]), 'CR sa na otvor nepýta');
  ctx.nxFrontDraftAsk();
  eq(SENT.length, 1, 'bez zmeny žiadny nový dotaz');
  setF(ctx, { corner_door_w: 500 });
  ctx.nxFrontDraftAsk();
  eq([SENT.length, SENT[1].corner_door_w], [2, 500], 'zmena dverovej časti = nový preflight (otvor sa prepočíta)');
  // Odpoved aktualnej revizie: otvor + ucinne hrubky.
  ctx.nxFrontPreflightResult({ revision: SENT[1].revision, model_guid: 'G-1', cabinet_id: '', insert_session: SENT[1].insert_session,
                               valid: true, items: [], errors: [], slots: {}, opening: { x0: 0, w: 500, z0: 100, h: 620 },
                               corner_ctx: { th2: 19, t: 25 } });
  eq(get(ctx, 'frontOpening').w, 500, 'otvor = živá dverová časť');
  eq([get(ctx, 'cornerDraft').corner_th2, get(ctx, 'cornerDraft').corner_t], [19, 25], 'corner_ctx sa prevzal');
  // Oznacena skrinka: materialy navrhu vkladania sa neposielaju.
  vm.runInContext("selectedCabId = 'CAB-1'", ctx);
  ctx.nxFrontDraftAsk();
  ok(!('material_id' in SENT[SENT.length - 1]), 'označená: materiály návrhu sa neposielajú (server číta uložený config)');
  ctx.setType('lower');
  vm.runInContext('frontDraft = null', ctx);
  ctx.nxFrontDraftAsk();
  const lo = SENT[SENT.length - 1];
  ok(!('corner_side' in lo) && !('corner_door_w' in lo) && !('thickness' in lo), 'dolná: preflight bez polí rohovej (parita)');
}

// ============ 7) VYRAZOVE POLIA (predrecenzia P2-1) ============================
{
  // Guard: KAZDE ciselne pole v #basicCard ma vyrazovu podporu (bindExprFields)
  // — inak debounce pri pisani `600+` odosle medzistav (prazdne pole).
  const html = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'panel.html'), 'utf8');
  const card = html.slice(html.indexOf('<fieldset id="basicCard">'), html.indexOf('<!-- ===== S3 · MATERIALY'));
  const ids = [];
  const re = /<input id="([a-zA-Z0-9_]+)"[^>]*type="text"/g;
  let m;
  while ((m = re.exec(card))) ids.push(m[1]);
  // Popover osadenia (D-140) zapisuje LEN tlacidlo „Použiť", nie debounce pola.
  const EXEMPT = ['aprMountVal'];
  const boot = fs.readFileSync(path.join(JS, 'boot.js'), 'utf8');
  const list = boot.slice(boot.indexOf('function bindExprFields'), boot.indexOf('// E-03'));
  ok(ids.indexOf('corner_door_w') >= 0 && ids.length >= 10, `#basicCard má číselné polia (${ids.length})`);
  ids.filter(id => EXEMPT.indexOf(id) < 0).forEach(function(id){
    ok(list.indexOf("'" + id + "'") >= 0, `pole ${id} má výrazovú podporu (bindExprFields)`);
  });
  // Spravanie: rozpisany vyraz v dverovej casti NEODOSLE apply ani sa nenaplanuje.
  const ctx = selCtx();
  ctx.sketchup.front_preflight = () => {};
  const d = ctx.__node('corner_door_w');
  ctx.attachExprField(d, {});
  eq(d.getAttribute('data-expr'), '1', 'pole dverovej časti je výrazové');
  d.value = '600+';
  ctx.document.activeElement = d;
  ctx.onField();
  eq(get(ctx, 'applyTimer'), null, 'rozpísaný výraz „600+" nenaplánuje apply (žiadny medzistav)');
  eq(ctx.__sent.length, 0, 'nič neodišlo');
  ctx.document.activeElement = null;
}

console.log(`test_rohb1_ovladace.js: ${n} asercii OK`);
