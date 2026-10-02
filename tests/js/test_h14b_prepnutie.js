// H14b — JEDNA cesta prepnutia sekcie Studia, kotvy a kreslenie z registra
// (package `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H14.md`, R1.2a, R3, R5 f, T2, T8).
//   node tests/js/test_h14b_prepnutie.js
//
// Co sa tu dokazuje (golden T0 `test_h14_golden.js` drzi bajtovu zhodu so starym
// kodom; tu su pravidla, ktore z neho samy nevyplyvaju):
//   1. R5 f (vm) — kazdy hacik z registra (`tools`, `body`, `leave`, `enter`,
//      `anchor.fn`) existuje ako funkcia PRED akymkolvek spehom a definuje ho
//      PRAVE subor `module` jeho riadka; ten sa v studio.html nacitava za studio.js,
//   2. R5 f (CommonJS) + T8 — pri `require('./studio.js')` (Node sady) su vlastne
//      haciky Kusovnika, Kontroly a Nakupu v `OWN_HOOKS` a lista aj telo tychto
//      sekcii su BAJTOVO tie iste ako v okne (golden G2) — nie prazdne,
//   3. R1.2a — chybajuci VLASTNY hacik studio.js je chyba programu (vyletí),
//      nie ticha prazdna lista,
//   4. T2 — klik nikdy nespusti kotvu; deep-link do tej istej sekcie len zhasne
//      menu; vstupny hacik „O plugine" prave raz pri vstupe kazdou cestou;
//      nezname id = ZIADNY zapis do okna (§15 A3); platne id aktualnej sekcie =
//      zhasnute menu + jedno prekreslenie.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const H = require('./h14_harness.js');
const H12 = require('./h12_harness.js');

const JS = path.join(H.UI, 'js');
const R = require(path.join(JS, 'studio_sections.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

function hookNames(row){
  return [row.tools, row.body, row.leave, row.enter, row.anchor && row.anchor.fn].filter(Boolean);
}
function calls(L){ return L.LOG.map(function(c){ return c.split(' @')[0]; }); }

// --- 1) R5 f · vm: haciky existuju PRED spehmi a patria suboru `module` -------
(function(){
  const files = H12.panelScripts('studio.html');
  const L = H.load({ files: [] });      // prazdny kontext okna, skripty po jednom
  const owner = {};
  files.forEach(function(f){
    vm.runInContext(fs.readFileSync(path.join(JS, f), 'utf8'), L.ctx, { filename: f });
    Object.getOwnPropertyNames(L.ctx).forEach(function(k){
      if (!owner[k] && typeof L.ctx[k] === 'function') owner[k] = f;
    });
  });
  const reg = L.ctx.NXStudioSections;
  ok(reg && typeof reg.get === 'function', 'register je v okne (window.NXStudioSections)');
  const iStudio = files.indexOf('studio.js');
  let checked = 0;
  reg.ids().forEach(function(id){
    const row = reg.get(id);
    ok(files.indexOf(row.module) >= iStudio, `${id}: modul ${row.module} sa nacitava za studio.js`);
    hookNames(row).forEach(function(name){
      checked++;
      eq(typeof L.ctx[name], 'function', `${id}: hacik ${name} je funkcia okna (pred spehmi)`);
      eq(owner[name], row.module, `${id}: hacik ${name} definuje ${row.module}`);
    });
  });
  ok(checked >= 30, 'kontrola nieco overila (' + checked + ' haciakov)');
})();

// --- 2) R5 f · CommonJS + T8: vlastne haciky studio.js ------------------------
(function(){
  const LISTEN = {};
  const ELS = {};
  ['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel', 'studio'].forEach(function(id){
    ELS[id] = { id: id, innerHTML: '', textContent: '', className: '' };
  });
  global.window = {};
  global.document = {
    activeElement: null,
    addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
    getElementById: function(id){ return ELS[id] || null; }
  };
  const S = require(path.join(JS, 'studio.js'));
  global.NX = global.window.NX;
  ok(Object.isFrozen(S.OWN_HOOKS), 'OWN_HOOKS je zmrazena tabulka');
  R.inModule('studio.js').forEach(function(id){
    hookNames(R.get(id)).forEach(function(name){
      eq(typeof S.OWN_HOOKS[name], 'function', `${id}: vlastny hacik ${name} je v OWN_HOOKS`);
      eq(typeof globalThis[name], 'undefined', `${name} NIE JE globalom Node (preto OWN_HOOKS)`);
    });
  });
  eq(Object.keys(S.OWN_HOOKS).sort(),
     [].concat.apply([], R.inModule('studio.js').map(function(id){ return hookNames(R.get(id)); })).sort(),
     'OWN_HOOKS = presne haciky sekcii, ktore kresli studio.js');

  // H7b (R-B11): fixtura G2 sa neregeneruje — obe strany idu cez TU ISTU
  // normalizaciu styroch fragmentov H7b ako golden (`H.normalizeH7`).
  const golden = H.normalizeH7(JSON.parse(fs.readFileSync(path.join(H.GOLDEN_DIR, 'g2_dispatch.json'), 'utf8')).own,
                               'old').value;
  const normNew = function(v){ return H.normalizeH7(v, 'new').value; };
  const view = function(v){
    const t = { getAttribute: function(k){ return k === 'data-view' ? v : null; } };
    t.closest = function(sel){ return sel === '[data-view]' ? t : null; };
    (LISTEN.click || []).forEach(function(fn){ fn({ type: 'click', target: t, preventDefault(){} }); });
  };
  global.window.NX.setStudio(H.payload());
  ['parts', 'sheets', 'abs'].forEach(function(v){
    global.window.studioGoSection('ctrl');
    view(v);
    global.window.studioGoSection('bom');
    const got = { tools: ELS.sectools.innerHTML, body: ELS.secbody.innerHTML };
    ok(got.tools.length > 0 && got.body.length > 0, `T8 bom:${v}: lista aj telo NIE SU prazdne`);
    eq(normNew(got), golden['bom:' + v], `T8 bom:${v}: Kusovnik v Node = Kusovnik v okne (golden G2)`);
  });
  view('parts');
  ['ctrl', 'buy'].forEach(function(id){
    global.window.studioGoSection('bom');
    global.window.studioGoSection(id);
    const got = { tools: ELS.sectools.innerHTML, body: ELS.secbody.innerHTML };
    ok(got.tools.length > 0 && got.body.length > 0, `T8 ${id}: lista aj telo NIE SU prazdne`);
    eq(normNew(got), golden[id], `T8 ${id}: sekcia v Node = sekcia v okne (golden G2)`);
  });
  delete global.window; delete global.document; delete global.NX;
})();

// --- 3) R1.2a: chybajuci VLASTNY hacik = chyba, nie prazdna lista ------------
(function(){
  const L = H.load({ files: [] });
  const ROW = Object.freeze({ id: 'bom', grp: 'job', ic: 'list', t: 'Kusovník', head: '', module: 'studio.js',
                              data: 'rows', tools: 'bomRenderToolz', body: 'bomRenderBody' });
  L.ctx.NXStudioSections = {
    has: function(id){ return id === 'bom'; }, get: function(id){ return id === 'bom' ? ROW : null; },
    ids: function(){ return ['bom']; }, groups: function(){ return [{ grp: 'job', t: 'ZÁKAZKA', items: [ROW] }]; },
    inModule: function(){ return ['bom']; }, fn: function(){ return null; }, REFRESH_DEFAULT: ''
  };
  vm.runInContext(fs.readFileSync(path.join(JS, 'studio.js'), 'utf8'), L.ctx, { filename: 'studio.js' });
  let err = null;
  try { L.ctx.NX.setStudio(H.payload()); } catch (e){ err = e; }
  ok(err && /bomRenderToolz/.test(String(err.message)),
     'preklep vo vlastnom hacku vyletí s menom hacika (zachyti ho errors.js), nie ticha prazdna lista');
})();

// --- 4) T2: pravidla prechodu ---------------------------------------------------
(function(){
  const L = H.ready();
  const anchors = /OpenAnchor\(/;

  // Klik nikdy nespusti kotvu (kotva patri VYHRADNE deep-linku).
  R.ids().forEach(function(id){
    H.goQuiet(L, id === 'bom' ? 'ctrl' : 'bom');
    H.wr(L, 'bomQ', '');
    L.ctx.studioGoSection(id);
    ok(!L.LOG.some(function(c){ return anchors.test(c); }), `klik do ${id} nespusti ziadnu kotvu`);
  });
  eq(H.rd(L, 'bomQ'), '', 'klik do Kusovnika text hladania nezmeni');
  // Deep-link BEZ kotvy kotvu tiez nespusti.
  H.goQuiet(L, 'bom');
  L.ctx.NX.setStudio(H.payload({ open_section: 'mat' }));
  ok(!L.LOG.some(function(c){ return anchors.test(c); }), 'deep-link bez kotvy kotvu nespusti');

  // Deep-link do TEJ ISTEJ sekcie len zhasne menu (ziadny hacik prechodu).
  R.ids().forEach(function(id){
    H.goQuiet(L, id);
    H.wr(L, 'vepoMenuOpen', true); H.wr(L, 'ecMenuOpen', true); H.wr(L, 'colMenuOpen', true);
    H.resetCounters(L);
    L.ctx.NX.setStudio(H.payload({ open_section: id }));
    const hooks = calls(L).filter(function(c){ return !/Render(Offer)?(Tools|Body)\(/.test(c); });
    eq(hooks, [], `deep-link ${id} -> ${id}: ziadny kontextovy, odchodovy ani vstupny hacik`);
    eq([H.rd(L, 'vepoMenuOpen'), H.rd(L, 'ecMenuOpen'), H.rd(L, 'colMenuOpen')], [false, false, false],
       `deep-link ${id} -> ${id}: menu listy zhasnu`);
    eq(L.ctx.studioActiveSection(), id, `deep-link ${id} -> ${id}: sekcia ostava`);
  });

  // D-52b: vstup do „O plugine" spusti PRAVE JEDEN check — klikom aj deep-linkom.
  const enters = function(){ return L.LOG.filter(function(c){ return /^ssOnAboutEnter\(/.test(c); }).length; };
  H.goQuiet(L, 'bom');
  L.ctx.studioGoSection('about');
  eq(enters(), 1, 'klik bom -> about: jeden vstupny hacik');
  H.resetCounters(L);
  L.ctx.studioGoSection('about');
  eq(enters(), 0, 'klik about -> about: ziadny (znova otvorena sekcia check neopakuje)');
  H.goQuiet(L, 'bset');
  L.ctx.NX.setStudio(H.payload({ open_section: 'about' }));
  eq(enters(), 1, 'deep-link bset -> about: jeden vstupny hacik');
  H.resetCounters(L);
  L.ctx.NX.setStudio(H.payload({ open_section: 'about' }));
  eq(enters(), 0, 'deep-link about -> about: ziadny');
  H.resetCounters(L);
  L.ctx.NX.setStudio(H.payload());
  eq(enters(), 0, 'plny push bez deep-linku (zmena modelu) check nespusta');

  // §15 A3: nezname id = okno sa NEPREKRESLI (render by vzal fokus z pola).
  [['xyz'], [''], [null], [undefined], ['__proto__'], [7]].forEach(function(a){
    H.goQuiet(L, 'bom');
    H.wr(L, 'vepoMenuOpen', true);
    H.resetCounters(L);
    L.ctx.studioGoSection(a[0]);
    eq(H.writes(L), { snav: 0, sechead: 0, sectools: 0, secbody: 0 },
       `klik na nezname id ${String(a[0])}: ziadny zapis do okna`);
    eq(L.LOG, [], `nezname id ${String(a[0])}: ziadny hacik`);
    eq(H.rd(L, 'vepoMenuOpen'), true, `nezname id ${String(a[0])}: otvorene menu ostava (nic sa nestalo)`);
    eq(L.ctx.studioActiveSection(), 'bom', `nezname id ${String(a[0])}: sekcia ostava`);
  });
  // Platne id AKTUALNEJ sekcie: zhasnute menu + JEDNO prekreslenie (ako pred H14b).
  H.goQuiet(L, 'bom');
  H.wr(L, 'vepoMenuOpen', true);
  H.resetCounters(L);
  L.ctx.studioGoSection('bom');
  eq(H.writes(L), { snav: 1, sechead: 1, sectools: 1, secbody: 1 }, 'klik bom -> bom: jedno prekreslenie okna');
  eq(H.rd(L, 'vepoMenuOpen'), false, 'klik bom -> bom: otvorene menu zhasne');
})();

console.log('test_h14b_prepnutie: ' + n + ' kontrol OK');
