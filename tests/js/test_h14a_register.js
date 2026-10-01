// H14a · T1 — register sekcii Studia `ui/js/studio_sections.js` (package
// `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H14.md`, R1, R4.1).
//   node tests/js/test_h14a_register.js
//
// Co sa tu dokazuje:
//   1. register == NEZAVISLA fixtura kontraktu `tests/fixtures/h14_studio_sections.json`
//      (vznikla zo stareho kodu; Ruby strana porovnava SECTIONS s tou istou fixturou),
//      vratane poradia sekcii a skupin,
//   2. API je ciste a odolne: `has`/`get` len pre retazec zo zoznamu (nie null,
//      cislo, '__proto__', 'constructor'), zoznamy su nove polia, riadky zmrazene,
//   3. `fn(meno)` najde len globalnu funkciu v case volania (nie `let`/`const`,
//      nie zdedene meno),
//   4. bez registra sa `studio.js` aj `shell.js` NACITAJU (shim vezme `undefined`)
//      a chyba sa prejavi az pri prvom pouziti (R1.5; poradiu skriptov brani guard R5 e).
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const JS = path.join(ROOT, 'noxun_engine', 'ui', 'js');
const R = require(path.join(JS, 'studio_sections.js'));
const FIX = JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'h14_studio_sections.json'), 'utf8'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) register == fixtura kontraktu ----------------------------------------
const rows = [];
R.groups().forEach(function(g){ g.items.forEach(function(it){ rows.push(JSON.parse(JSON.stringify(it))); }); });
eq(R.ids(), FIX.sections.map(function(s){ return s.id; }), 'poradie sekcii = fixtura (= StudioDialog::SECTIONS)');
eq(rows.map(function(r){ return r.id; }), R.ids(), 'skupiny navigacie idu v poradi sekcii (ziadne preskakovanie)');
eq(rows, FIX.sections, 'riadky registra = fixtura kontraktu (vsetky kluce a hodnoty)');
eq(R.groups().map(function(g){ return { grp: g.grp, t: g.t }; }), FIX.groups, 'skupiny navigacie a ich nadpisy');
eq(R.REFRESH_DEFAULT, FIX.refresh_default, 'predvolena hlaska „Obnoviť"');
FIX.sections.forEach(function(s){ eq(JSON.parse(JSON.stringify(R.get(s.id))), s, 'get(' + s.id + ')'); });

// --- 2) API -------------------------------------------------------------------
[null, undefined, '', 'xyz', 'BOM', ' bom', 0, 1, {}, [], '__proto__', 'constructor', 'toString', 'hasOwnProperty']
  .forEach(function(v){
    eq(R.has(v), false, 'has(' + String(v) + ') nie je sekcia');
    eq(R.get(v), null, 'get(' + String(v) + ') = null');
  });
ok(R.has('bom') && R.has('about'), 'zname id prejdu');
const a = R.ids(); a.push('xyz'); a.length = 1;
eq(R.ids().length, 14, 'ids() vracia NOVE pole — upravou kopie sa register nezmeni');
const g = R.groups(); g[0].items.length = 0;
eq(R.groups()[0].items.length, 6, 'groups() vracia nove polia');
ok(Object.isFrozen(R) && Object.isFrozen(R.get('bom')), 'register aj riadky su zmrazene');
assert.throws(function(){ 'use strict'; R.get('bom').t = 'X'; }, TypeError, 'riadok sa neda prepisat');
n++;
eq(R.get('bom').t, 'Kusovník', 'a po pokuse ostava povodny');
eq(R.inModule('studio_settings.js'), ['sup', 'bset', 'about'], 'sekcie Nastaveni kresli studio_settings.js');
eq(R.inModule('studio.js'), ['bom', 'ctrl', 'buy'], 'Kusovnik, Kontrolu a Nakup kresli studio.js');
eq(R.inModule('budget.js'), ['budget', 'offer'], 'Rozpocet a Ponuku budget.js');
eq(R.inModule('neexistuje.js'), [], 'neznamy subor nekresli nic');
eq(R.groups().map(function(x){ return x.items.map(function(r){ return r.id; }); }),
   [['bom', 'ctrl', 'buy', 'budget', 'offer', 'cut'], ['mat', 'hw', 'appl', 'rules', 'tpl'], ['sup', 'bset', 'about']],
   'zlozenie skupin navigacie');

// --- 3) fn(meno) v case volania ----------------------------------------------
(function(){
  const ctx = { console: console };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path.join(JS, 'studio_sections.js'), 'utf8'), ctx, { filename: 'studio_sections.js' });
  const NS = ctx.NXStudioSections;
  ok(NS && typeof NS.fn === 'function', 'v prehliadaci (vm) je register window.NXStudioSections');
  eq(NS.fn('h14Neskor'), null, 'funkcia, ktora este nie je nacitana, nie je');
  vm.runInContext('function h14Neskor(){ return 7; } let h14Let = function(){}; const h14Const = function(){};' +
                  ' var h14Var = 5;', ctx);
  ok(NS.fn('h14Neskor') && NS.fn('h14Neskor')() === 7, 'globalna funkcia sa najde V CASE VOLANIA (modul nacitany neskor)');
  eq(NS.fn('h14Let'), null, '`let` nie je vlastnost globalu — nenajde sa');
  eq(NS.fn('h14Const'), null, '`const` tiez nie');
  eq(NS.fn('h14Var'), null, 'nefunkcia sa nevrati');
  eq(NS.fn('constructor'), null, 'zdedene meno (Object) sa nenajde');
  eq(NS.fn('toString'), null, 'ani toString');
  eq(NS.fn(null), null, 'null meno = null');
  ctx.h14Neskor = undefined;
  eq(NS.fn('h14Neskor'), null, 'zmazany hacik = null (sekcia ukaze nudzovy text)');
})();

// --- 4) R1.5: bez registra sa skripty nacitaju, chyba az pri pouziti -----------
(function(){
  function bare(){
    const nodes = {};
    const ctx = {
      console: console, navigator: { userAgent: 'node' }, JSON: JSON, Math: Math,
      setTimeout(){ return 0; }, clearTimeout(){},
      addEventListener(){}, removeEventListener(){},
      document: {
        getElementById(id){ return nodes[id] || (nodes[id] = { id: id, innerHTML: '', textContent: '', className: '' }); },
        addEventListener(){}, querySelector(){ return null; }, querySelectorAll(){ return []; }
      }
    };
    ctx.window = ctx;
    vm.createContext(ctx);
    return ctx;
  }
  const c1 = bare();
  vm.runInContext(fs.readFileSync(path.join(JS, 'studio.js'), 'utf8'), c1, { filename: 'studio.js' });
  ok(typeof c1.NX.setStudio === 'function', 'studio.js sa bez registra nacita (shim vezme undefined)');
  let err = null;
  try { c1.NX.setStudio({ gen: 1, model_guid: 'G', model_title: 'T', version: '0', rows: [], counts: {} }); }
  catch (e){ err = e; }
  ok(err && err.name === 'TypeError' && /has|groups|get/.test(String(err.message)),
     'chyba sa prejavi az pri prvom pouziti (zachyti ju errors.js -> js_error)');
  const c2 = bare();
  vm.runInContext(fs.readFileSync(path.join(JS, 'shell.js'), 'utf8'), c2, { filename: 'shell.js' });
  ok(c2.NXShell && typeof c2.NXShell.studioSection === 'function', 'shell.js sa bez registra nacita');
})();

console.log('test_h14a_register: ' + n + ' kontrol OK');
