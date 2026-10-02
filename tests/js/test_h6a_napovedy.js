// H6a (blok 9 HARDENING, D-01) - napovedy do „?", spodok panela, stavova veta.
//   node tests/js/test_h6a_napovedy.js
//
// Co sa tu strazi (package H6, H6a T2-T6):
//   T2 `NXShell.pvHelpText(mode, ctx)` - matica 4 rezimy x 5 kontextov (dielec ma
//      ZONOVY text, neznamy kontext = Korpus), texty doslovne z fixtury
//      `tests/fixtures/h6_texty.json`; `nxShellApply` nasadi `data-tip` na `#pvHelp`,
//   T3 `NX.setStatus`: prazdny / medzerovy / null text stavovu vetu SKRYJE,
//      text ju ukaze (ok/err); Studio ma vlastny `setStatus` (nedotknuty),
//   T4 `aprRowHtml`: prazdne ocakavanie = „?" s vetou servera a ZIADNY `.aptxt`;
//      neprazdne = viditelny `.aptxt` „ocakava ...",
//   T5 `setCabinetMaterials` / `clearCabinetMaterials`: s vyberom je `#cabMatHint`
//      skryty, bez vyberu viditelna STAVOVA veta,
//   T6 `rdGuardHtml`: veta CS-10 je „?" v <summary>, v tele nie je `.hint` okrem
//      stavoveho `.rgbad`.
// MUTACIE (kazda overena rucne - po zanesi chyby do kodu spadne uvedena aserciu):
//   M5 `pvHelpText` pre `part` vrati len gesta           -> T2 „dielec = zonovy text"
//   M3 `NX.setStatus` nenastavuje `hidden`               -> T3 „prazdny text skryje"
//   M8 `aprRowHtml` vynecha „?" pri prazdnom ocakavani   -> T4 „? s vetou servera"
//   M10 `setCabinetMaterials` nenastavi `hidden` na `on` -> T5 „s vyberom skryty"
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const JS = path.join(ROOT, 'noxun_engine', 'ui', 'js');
const FIX = JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'h6_texty.json'), 'utf8'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg + ': cakam ' + JSON.stringify(b) + ', dostal ' + JSON.stringify(a)); }
function ok(c, msg){ n++; assert.ok(c, msg); }
function no(c, msg){ n++; assert.ok(!c, msg); }
function help(id){
  const e = FIX.help.filter(function(x){ return x.id === id; })[0];
  assert.ok(e, 'fixtura nema vetu ' + id);
  return e.text;
}

// Maly falosny uzol: atributy, classList, textContent, hidden.
function fakeEl(attrs){
  const a = Object.assign({}, attrs || {});
  const cls = new Set();
  return {
    attrs: a, hidden: false, disabled: false, title: '', value: '', innerHTML: '', textContent: '', className: '',
    style: {},
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k) ? a[k] : null; },
    setAttribute(k, v){ a[k] = String(v); },
    querySelector(){ return null; }, querySelectorAll(){ return []; },
    classList: { add(c){ cls.add(c); }, remove(c){ cls.delete(c); }, contains(c){ return cls.has(c); },
                 toggle(c, on){ if (on === undefined ? !cls.has(c) : on) cls.add(c); else cls.delete(c); } }
  };
}
function mkCtx(ids){
  const byId = ids || {};
  const ctx = { console, setTimeout, clearTimeout, window: {}, JSON, Math };
  ctx.document = { getElementById: id => byId[id] || null, querySelectorAll: () => [], querySelector: () => null,
                   addEventListener(){}, body: fakeEl(), createElement: () => fakeEl() };
  ctx.el = id => byId[id] || null;
  vm.createContext(ctx);
  return ctx;
}
function load(ctx, file){ vm.runInContext(fs.readFileSync(path.join(JS, file), 'utf8'), ctx, { filename: file }); }

// ============ T2 · pvHelpText ================================================
require('./nx_types_fixture.js');
const NXShell = require(path.join(JS, 'shell.js'));
{
  const Z = help('pv_zony'), C = help('pv_cela'), K = help('pv_znacka'), G = help('pv_gesta');
  const MODES = ['insert', 'cab', 'part', 'board'];
  const CTXS = ['korpus', 'zony', 'cela', 'kovanie', 'neznamy'];
  function expectText(mode, ctx){
    if (mode === 'part') return Z + ' · ' + G;               // dielec: nahlad je zonovy
    if (mode === 'cab' && ctx === 'zony') return Z + ' · ' + G;
    if (mode === 'cab' && ctx === 'cela') return C + ' · ' + G;
    if (mode === 'cab' && ctx === 'kovanie') return K + ' · ' + G;
    return G;                                                 // Korpus, vkladanie, doska, neznamy = Korpus
  }
  MODES.forEach(function(m){
    CTXS.forEach(function(c){
      eq(NXShell.pvHelpText(m, c), expectText(m, c), 'pvHelpText(' + m + ', ' + c + ')');
    });
  });
  ok(NXShell.pvHelpText('part', 'korpus').indexOf(Z) === 0, 'dielec = zonovy text (aj ked kontext je Korpus)');
  no(NXShell.pvHelpText('cab', 'korpus').indexOf('Klik na') >= 0, 'Korpus nema ziadnu vetu o kliku');
  no(NXShell.pvHelpText('cab', 'zony').indexOf(K) >= 0, 'Zony nemaju vetu o znackach');
  // Bez argumentov cita ZIVY stav (tak ho vola nxShellApply).
  NXShell.track('cab', NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: 'G' }));
  NXShell.setCtx('cela');
  eq(NXShell.pvHelpText(), C + ' · ' + G, 'bez argumentov: zivy stav (Cela)');
  NXShell.setCtx('korpus');
}

// ============ T2b · nxShellApply nasadi data-tip na #pvHelp ===================
{
  const PV = fakeEl({ 'data-tip': 'zaloha' });
  const ctx = mkCtx({ pvHelp: PV });
  ctx.NXTypes = global.NXTypes;
  load(ctx, 'shell.js');
  // Lista sektorov cita polia formulara (iny test) - tu ich nahradi prazdna funkcia.
  ctx.nxSectorMetaApply = function(){};
  const sh = vm.runInContext('NXShell', ctx);
  sh.track('cab', sh.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: 'G' }));
  sh.setCtx('kovanie');
  ctx.nxShellApply();
  eq(PV.getAttribute('data-tip'), help('pv_znacka') + ' · ' + help('pv_gesta'), 'nxShellApply: Kovanie -> veta o znackach');
  sh.setCtx('zony');
  ctx.nxShellApply();
  eq(PV.getAttribute('data-tip'), help('pv_zony') + ' · ' + help('pv_gesta'), 'nxShellApply: Zony -> zonova veta');
  sh.track('part', sh.identityOf('part', { cabinet_id: 'CAB-001', role_key: 'side_left', model_guid: 'G' }));
  ctx.nxShellApply();
  eq(PV.getAttribute('data-tip'), help('pv_zony') + ' · ' + help('pv_gesta'), 'nxShellApply: dielec -> zonova veta');
  sh.track('insert', 'none');
  ctx.nxShellApply();
  eq(PV.getAttribute('data-tip'), help('pv_gesta'), 'nxShellApply: vkladanie -> len gesta');
}

// ============ T3 · NX.setStatus ==============================================
{
  const ST = fakeEl();
  ST.hidden = true;
  const ctx = mkCtx({ status: ST });
  load(ctx, 'bridge.js');
  const NX = ctx.window.NX;
  NX.setStatus('Uložené.', false);
  eq(ST.hidden, false, 'text -> stavova veta viditelna');
  eq(ST.textContent, 'Uložené.', 'text sa zapisal');
  eq(ST.className, 'ok', 'trieda ok');
  NX.setStatus('Chyba v poli.', true);
  eq(ST.className, 'err', 'trieda err');
  eq(ST.hidden, false, 'chyba viditelna');
  [['', 'prazdny'], ['   ', 'medzery'], [null, 'null'], [undefined, 'undefined']].forEach(function(c){
    NX.setStatus('niečo', false);
    NX.setStatus(c[0], false);
    eq(ST.hidden, true, c[1] + ' text stavovu vetu skryje');
  });
  // Studio ma vlastny `setStatus` (O2 plati len pre Inspector): ziadne `hidden` v studio.js.
  const studio = fs.readFileSync(path.join(JS, 'studio.js'), 'utf8');
  const m = studio.match(/setStatus\s*[:=]\s*function[^{]*\{[^}]*\}/);
  no(m && /\.hidden\s*=/.test(m[0]), 'Studio setStatus sa H6a nedotkol');
  const html = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'studio.html'), 'utf8');
  ok(html.indexOf('Pripravené.') >= 0, 'Studio si „Pripravené." ponecháva (F5)');
}

// ============ T4 · aprRowHtml: pomocny text vs stav ==========================
{
  const A = require(path.join(JS, 'appliance_row.js'));
  const TXT = help('spotrebic');
  const empty = A.aprRowHtml({ state: 'expects', expects: [], text: TXT, placeholder: 'očakáva: —', options: [] });
  ok(/class="nxtip inl r"/.test(empty), 'T4: prazdne ocakavanie = „?" (nxtip)');
  ok(empty.indexOf('data-tip="' + TXT.replace(/"/g, '&quot;') + '"') >= 0, 'T4: „?" nesie vetu servera doslovne');
  ok(/aria-label="Pomoc"/.test(empty) && /onclick="nxTipStop\(event\)"/.test(empty), 'T4: aria-label a nxTipStop');
  no(empty.indexOf('aptxt') >= 0, 'T4: ziadny `.aptxt` pod riadkom');
  const full = A.aprRowHtml({ state: 'expects', expects: ['oven'], text: 'očakáva rúru', placeholder: 'očakáva: rúra', options: [] });
  ok(full.indexOf('<span class="aptxt soft">očakáva rúru</span>') >= 0, 'T4: s ocakavanim ostava viditelna veta „očakáva rúru"');
  no(full.indexOf('nxtip') >= 0, 'T4: a „?" tam nie je');
}

// ============ T5 · materialy skrinky: pomocna veta preč, stavova ostava =======
{
  const HINT = fakeEl();
  const ids = { cabMatHint: HINT, cab_body: fakeEl(), cab_front: fakeEl(), cab_front_c: fakeEl(), cab_back: fakeEl() };
  const ctx = mkCtx(ids);
  ['setVal', 'nxComboSync', 'updateCabfrontMeta'].forEach(function(k){ ctx[k] = function(){}; });
  load(ctx, 'materials.js');
  const STATUS = 'Označ skrinku pre nastavenie jej materiálov.';
  ctx.setCabinetMaterials({ cabinet_id: 'CAB-001', material_id: 'm1', front_material_id: 'm2', back_material_id: '' });
  eq(HINT.hidden, true, 'T5: s vyberom je veta skryta (pomocna je v „?" listy)');
  ctx.clearCabinetMaterials();
  eq(HINT.hidden, false, 'T5: bez vyberu je viditelna');
  eq(HINT.textContent, STATUS, 'T5: bez vyberu stavova veta');
  ctx.setCabinetMaterials({ cabinet_id: 'CAB-002' });
  eq(HINT.hidden, true, 'T5: znova oznacena skrinka -> skryta');
  ctx.setCabinetMaterials({ cabinet_id: '' });
  eq(HINT.hidden, false, 'T5: prazdny vyber (cabinet_id "") -> viditelna stavova veta');
}

// ============ T6 · Pravidla kovania: CS-10 je „?" v <summary> ================
{
  const md = require(path.join(__dirname, 'minidom.js'));
  global.window.sketchup = { save_rules: function(){} };
  global.sketchup = global.window.sketchup;
  ['rulesBox', 'rdSrcLine', 'status', 'secbody', 'sectools'].forEach(function(id){
    const e = md.mkEl('div'); e.attrs.id = id; md.DOC.body.appendChild(e);
  });
  require(path.join(JS, 'studio.js'));
  if (global.window.NX && typeof global.NX === 'undefined') global.NX = global.window.NX;
  const R = require(path.join(JS, 'rules.js'));
  const rule = { rule_id: 'zavesy-podla-vysky', kind: 'bands', output: 'hinge', enabled: true, input: 'height',
                 applies_to: { role: 'front_door' }, bands: [{ max: 849, quantity: 2 }, { max: null, quantity: 7 }],
                 finite: true };
  const html = R.rdGuardHtml(rule, 0);
  const sum = html.match(/<summary>[\s\S]*?<\/summary>/)[0];
  const TXT = help('cs10');
  ok(sum.indexOf('class="nxtip"') >= 0, 'T6: <summary> ma „?"');
  ok(sum.indexOf('data-tip="' + TXT + '"') >= 0, 'T6: „?" nesie vetu CS-10 doslovne');
  ok(sum.indexOf('onclick="event.preventDefault();event.stopPropagation()"') >= 0, 'T6: klik na „?" blok nezbali');
  ok(sum.indexOf('class="rgsum"') >= 0, 'T6: sumar v liste ostava');
  no(/class="hint"/.test(html), 'T6: v tele bloku nie je `.hint` (zdravy tvar)');
  no(html.indexOf('Platí pre dvierka.') >= html.indexOf('</summary>') && html.indexOf('Platí pre dvierka.') >= 0,
     'T6: veta CS-10 nie je v tele bloku');
  // Stavova veta pokazeneho tvaru OSTAVA viditelna (`.hint.rgbad`).
  const bad = R.rdGuardHtml(Object.assign({}, rule, { weight_bands: { max: 7 } }), 0);
  ok(/class="hint rgbad"/.test(bad), 'T6: `.hint.rgbad` ostava viditelna stavova veta');
  eq((bad.match(/class="hint/g) || []).length, 1, 'T6: a je to jediny `.hint` v bloku');
}

console.log('test_h6a_napovedy.js: ' + n + ' testov OK');
