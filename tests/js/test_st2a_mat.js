// ŠT-2a — sekcia MATERIÁLY v okne Štúdio (kanál + skelet).
//
// Preco su to testy a nie klikanie:
//   1. „Sekcia si kresli telo SAMA" (audit #2) sa da rozbit jedinym riadkom
//      v `studio.js` — a rozbije sa TICHO: telo sa prekresli spravne, len
//      pouzivatel prave stratil rozpisany formular „Nový dekor" alebo cenu,
//      ktoru dopisoval. Vsimne si to az vtedy, ked mu to zmizne pod rukami.
//   2. Ten isty subor (`js/proj_materials.js`) bezi v DVOCH oknach. Kolizia
//      globalnych mien so `studio.js` by prepisala CUDZIU funkciu — a padlo by
//      nieco uplne ine (napr. kusovnik), nie materialy.
//   3. Lista sekcie je zoznam ovladacov: chybajuci `disabled` v nudzovom
//      rezime katalogu vyzera ako funkcny gombik, ktory zapis ticho odmietne.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_stale_obnovit.js) --------------------------
// Uzly su primitivne, ale drzia DVE veci, na ktorych stoji cely audit #2:
// `innerHTML = '...'` ODPOJI deti (presne ako v prehliadaci) a `appendChild`
// nastavi `parentNode`. Vdaka tomu vidno, ci telo sekcie prezilo push.
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], parentNode: null, _html: '' };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; n.children.forEach(function(c){ c.parentNode = null; }); n.children = []; }
  });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  n.cloneNode = function(){ return stubEl(id + '-clone'); };
  return n;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio'].forEach(function(id){
  ELS[id] = stubEl(id);
});
// <template> — `content` je fragment, ktory sa klonuje.
ELS.matBodyTpl = stubEl('matBodyTpl');
ELS.matBodyTpl.content = stubEl('matBodyTplContent');

global.window = { NX_MAT_SECTION: true };
const LISTEN = {};
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; }
};

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;           // poradie <script> v studio.html
const M = require(path.join(JS, 'proj_materials.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

// --- 1) LISTA sekcie (#17) — cista funkcia ----------------------------------

(function(){
  const h = M.matToolsHtml({ ro: false, q: 'halifax', mode: 'man', section: true,
                             backup: false, stale: false });
  ok(/id="mdDemosAddBtn"/.test(h), 'primarna akcia „Pridať z Demosu" je v liste');
  ok(h.indexOf('id="mdDemosAddBtn"') < h.indexOf('id="mdSearch"'),
     'primarna akcia je VLAVO od nastrojov (vzor listy Studia)');
  ok(/id="mdNewDecorBtn"/.test(h), 'zalozna cesta „ručne…" ostava');
  ok(/value="halifax"/.test(h), 'hladanie si nesie dotaz — lista sa prekresluje pri kazdom pushi');
  ok(/id="mdGroupMode"/.test(h) && /value="man"[^>]*selected/.test(h),
     'zoskupenie dlazdic ostava a pamata si vybrany rezim');
  ok(!/id="mdRestoreBtn"/.test(h), 'bez predmigracnej zalohy sa rollback NEUKAZUJE');
  ok(/<span class="spacer">/.test(h), 'lista ma rozrazac — nastroje idu doprava');
})();

(function(){
  const h = M.matToolsHtml({ ro: true, q: '', mode: 'az', section: true, backup: true });
  const add = h.match(/<button[^>]*id="mdDemosAddBtn"[^>]*>/)[0];
  const man = h.match(/<button[^>]*id="mdNewDecorBtn"[^>]*>/)[0];
  ok(/disabled/.test(add) && /disabled/.test(man),
     'nudzovy (read-only) katalog vypina OBE pridavacie cesty — server by ich aj tak odmietol');
  ok(!/id="mdRestoreBtn"/.test(h),
     'v nudzovom rezime nesie rollback BANNER — v liste by bol druhy raz');
  ok(/value="az"[^>]*selected/.test(h), 'rezim A–Z sa pamata');
})();

(function(){
  const h = M.matToolsHtml({ ro: false, q: '', mode: 'man', section: true, backup: true });
  ok(/id="mdRestoreBtn"/.test(h),
     'pri zdravom katalogu so zalohou je rollback dostupny aj bez banneru (GH #93 P2)');
})();

// Premostenie sa PRIZNAVA v tooltipe — tlacidlo nesmie vyzerat, ze robi nieco ine.
(function(){
  const insec = M.matToolsHtml({ section: true });
  const inwin = M.matToolsHtml({ section: false });
  ok(/okne Materiály/.test(insec),
     'v sekcii tooltip prizna, ze Demos beží zatiaľ v okne Materiály (ŠT-2b)');
  ok(!/okne Materiály/.test(inwin), 'v samotnom okne taky tooltip nedava zmysel');
})();

// Jantarove „Obnoviť" je ZDIELANY markup celeho okna — sekcia ho nekresli vlastne.
(function(){
  const cold = M.matToolsHtml({ stale: false });
  const warm = M.matToolsHtml({ stale: true });
  eq(cold.indexOf(S.refreshBtnHtml(false, 'Prepočítať počty „Použité v projekte" z aktuálneho modelu')) >= 0,
     true, 'pokojny stav ide TYM ISTYM helperom ako ostatne sekcie');
  ok(/nxstale/.test(warm) && !/nxstale/.test(cold),
     'jantarovy stav prichadza ARGUMENTOM zo studio.js (jedina autorita staleFlag)');
})();

// --- 2) audit #2: push zo servera NESMIE zmazat telo sekcie -----------------

(function(){
  // Deep-link `open_section: 'mat'` prepne okno do sekcie — presne ako klik
  // v navigacii, len bez DOM eventu.
  const payload = {
    version: '0.7.45', gen: 1, model_title: 'test', model_guid: 'G1',
    rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null,
    summary: {}, sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {},
    vepo: {}, control: [], counts: {}, budget: null,
    mat: { project: {}, cabinets: 3, model_guid: 'G1', used: { K009: 4 },
           catalog: { materials: { sheets: [] }, catalog: { sheets: [], edges: [] },
                      catalog_schema: 9, catalog_rev: 'r1' } },
    open_section: 'mat'
  };
  // Push zo servera. V prehliadaci za nim `studio.js` zavola `matRenderBody()`
  // ako GLOBALNU funkciu — v Node su moduly oddelene, takze delegovanie
  // overuje bod 5 (zdrojak) a telo sa tu vola priamo.
  global.NX.setStudio(payload);
  const body = ELS.secbody;
  body.innerHTML = '';
  M.matRenderBody();
  eq(body.children.length, 1, 'telo sekcie sa pripojilo do #secbody');
  const node = body.children[0];
  eq(node.id, 'matBody', 'a je to JEDEN uzol sekcie (klon sablony), nie znovu poskladany HTML');

  // Simulacia „rozpisaneho formulara": do tela pribudne uzol, ktory tam nikto
  // iny nedava. Keby ho prezil push, prezije ho aj rozpisana bunka ceny.
  const draft = stubEl('draft');
  node.appendChild(draft);

  global.NX.setStudio(payload);
  M.matRenderBody();
  eq(body.children.length, 1, 'po dalsom pushi je telo stale prave jedno');
  ok(body.children[0] === node, 'a je to TEN ISTY uzol — push ho neprekreslil');
  ok(node.children.indexOf(draft) >= 0 && draft.parentNode === node,
     'rozpisany formular v nom PREZIL (audit #2: setStudio ho nesmie zmazat)');

  // Odchod do inej sekcie telo odpoji (ta si `#secbody` prepise), navrat ho
  // ma vratit AJ s rozpracovanym obsahom.
  body.innerHTML = '<div>Kusovník</div>';
  eq(node.parentNode, null, 'ina sekcia si telo Materialov odpojila (vzor prehliadaca)');
  M.matRenderBody();
  ok(body.children[0] === node, 'navrat do sekcie vrati TEN ISTY uzol');
  ok(node.children.indexOf(draft) >= 0, 'aj s rozpisanym formularom');
})();

// --- 3) katalogove echo: BEZ generacie, funguje aj mimo sekcie --------------

(function(){
  ok(typeof global.NX.setMatCatalog === 'function',
     'okno ma prijimac katalogoveho echa (`NX.setMatCatalog`)');
  const before = ELS.secbody.children[0];
  global.NX.setMatCatalog({ materials: { sheets: [] }, catalog: { sheets: [], edges: [] },
                            catalog_schema: 9, catalog_rev: 'r2' });
  ok(ELS.secbody.children[0] === before,
     'echo prekresli obsah, ale telo sekcie NEVYMIENA (rozpisany stav zije dalej)');
})();

// --- 4) kolizie globalov (audit #6) -----------------------------------------

(function(){
  // Ten isty subor bezi vedla `studio.js` a `budget.js`. Rovnake meno na
  // top-level urovni by ticho prepisalo cudziu funkciu — a padlo by nieco
  // uplne ine nez materialy.
  const files = ['studio.js', 'budget.js', 'proj_materials.js', 'nx_modal.js', 'edge_menu.js'];
  const names = {};
  files.forEach(function(f){
    const src = fs.readFileSync(path.join(JS, f), 'utf8');
    const set = new Set();
    const re = /^ {2}(?:function\s+(\w+)|var\s+(\w+))/gm;
    let m;
    while ((m = re.exec(src)) !== null) set.add(m[1] || m[2]);
    names[f] = set;
  });
  const mine = names['proj_materials.js'];
  ok(mine.size > 50, 'zoznam mien sa naozaj nacital (inak by test nic nestrazil)');
  files.forEach(function(f){
    if (f === 'proj_materials.js') return;
    const clash = [...mine].filter(function(x){ return names[f].has(x); });
    eq(clash, [], `js/proj_materials.js nesmie prepisat globaly z ${f}`);
  });
  ok(mine.has('mdEl') && mine.has('mdEsc') && !mine.has('el') && !mine.has('esc'),
     'preto sa helpery volaju mdEl/mdEsc (nie el/esc)');
})();

// --- 5) presun do Studia: ready a poradie skriptov --------------------------

(function(){
  const src = fs.readFileSync(path.join(JS, 'proj_materials.js'), 'utf8');
  // Volanie (nie zmienka v komentari): `sketchup.ready(` na zaciatku vyrazu.
  ok(!/^[^/\n]*\bsketchup\.ready\(/m.test(src),
     'audit #7: `ready` sa uz z tohto suboru NEPOSIELA — v Studiu ho posiela studio.js');
  const html = fs.readFileSync(path.join(JS, '..', 'proj_materials.html'), 'utf8');
  ok(/sketchup\.ready\(/.test(html),
     'okno Materialy si ho posiela z vlastneho HTML (o nic neprislo)');
  const sjs = fs.readFileSync(path.join(JS, 'studio.js'), 'utf8');
  const bodyFn = sjs.match(/function renderBody\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/studioSec === 'mat'/.test(bodyFn) && /matRenderBody\(\)/.test(bodyFn),
     'audit #2: telo sekcie `mat` kresli VYHRADNE matRenderBody — studio.js si ho nekresli sam');
  const toolsFn = sjs.match(/function renderTools\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/studioSec === 'mat'/.test(toolsFn) && /matRenderTools\(staleFlag\)/.test(toolsFn),
     'a listu matRenderTools — s jantarovym priznakom zo `staleFlag` (jedina autorita)');
  const studio = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');
  ok(studio.indexOf('js/studio.js') < studio.indexOf('js/proj_materials.js'),
     'proj_materials.js sa nacitava AZ ZA studio.js (obaluje jeho NX.setStudio)');
  ok(studio.indexOf('js/budget.js') < studio.indexOf('js/proj_materials.js'),
     'a aj za budget.js — kazdy dalsi obal musi vidiet ten predchadzajuci');
  ok(studio.indexOf('NX_MAT_SECTION') < studio.indexOf('js/proj_materials.js'),
     'priznak sekcie musi byt nastaveny PRED nacitanim suboru');
})();

console.log(`OK ${n} kontrol (ŠT-2a sekcia Materiály)`);
