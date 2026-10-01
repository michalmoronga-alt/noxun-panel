// H14 — spolocna kostra charakterizacie sekcii Studia (golden `test_h14_golden.js`,
// generator `tests/fixtures/h14_golden/generate.js`). NIE JE to testovacia sada
// (nema prefix `test_`), CI ju samostatne nespusta.
//
// Nacita skripty okna Studio (alebo Inspector) do JEDNEHO `vm` kontextu PRESNE
// v poradi HTML (ako CEF: spolocny globalny priestor) nad povolnym stubom DOM
// (`h12_harness.mkNode`). Navyse oproti H12:
//   * uzly pocitaju ZAPISY `innerHTML` (kolkokrat sa prekreslila navigacia,
//     hlavicka, lista a telo sekcie),
//   * `document.addEventListener` sa ZACHYTAVA (klik, zmena) a da sa vystrelit
//     s cielom, ktoreho `closest` odpoveda len na selektory, ktore uzol ma,
//   * `localStorage` je ZAZNAMOVY stub (citania aj zapisy),
//   * `sketchup` je zaznamovy stub (kazde volanie do Ruby sa zapise do logu),
//   * SPEHY nahradia 24 globalnych haciakov sekcii (+ 3 kotvy) a pri kazdom
//     volani zapisu aj STAV V OKAMIHU VOLANIA: aktivnu sekciu, tri menu listy
//     (VEPO, kontrola hran, stlpce) a identitu dokumentu (`ST.model_guid`).
// Spehy LEN nahradzaju existujuce funkcie — chybajucu nikdy nevytvoria
// (`install` vrati zoznam chybajucich, test ho overi PRED ich instalaciou).
//
// Citacka stavu (`rd`) cita top-level premenne `studio.js`. Ak ich refaktor
// presunie, meni sa CITACKA, nie golden fixtury (package H14 R0.4).
'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const H12 = require('./h12_harness.js');

const ROOT = H12.ROOT;
const UI = H12.UI;
const FIXTURE_SECTIONS = path.join(ROOT, 'tests', 'fixtures', 'h14_studio_sections.json');
const GOLDEN_DIR = path.join(ROOT, 'tests', 'fixtures', 'h14_golden');

// Id sekcii berie harness z NEZAVISLEJ fixtury kontraktu (nie z testovaneho kodu).
function contract(){ return JSON.parse(fs.readFileSync(FIXTURE_SECTIONS, 'utf8')); }
function ids(){ return contract().sections.map(function(s){ return s.id; }); }

// Globalne haciky sekcii, ktore `studio.js` hlada v case volania (S6).
const HOOKS = ['hwProductContextChanged', 'mdManualContextChanged', 'matOnLeaveSection', 'hwOnLeaveSection',
               'apOnLeaveSection', 'ssOnAboutEnter',
               'budRenderTools', 'budRenderBody', 'budRenderOfferTools', 'budRenderOfferBody',
               'matRenderTools', 'matRenderBody', 'hwRenderTools', 'hwRenderBody', 'apRenderTools', 'apRenderBody',
               'rulesRenderTools', 'rulesRenderBody', 'tplRenderTools', 'tplRenderBody',
               'ssRenderTools', 'ssRenderBody', 'npRenderTools', 'npRenderBody'];
const ANCHORS = ['matOpenAnchor', 'budOpenAnchor', 'apOpenAnchor'];
// Ktore haciky lista/telo kresli sekciu z INEHO suboru (variant „modul chyba").
const EXTERNAL = {
  budget: ['budRenderTools', 'budRenderBody'], offer: ['budRenderOfferTools', 'budRenderOfferBody'],
  cut: ['npRenderTools', 'npRenderBody'], mat: ['matRenderTools', 'matRenderBody'],
  hw: ['hwRenderTools', 'hwRenderBody'], appl: ['apRenderTools', 'apRenderBody'],
  rules: ['rulesRenderTools', 'rulesRenderBody'], tpl: ['tplRenderTools', 'tplRenderBody'],
  sup: ['ssRenderTools', 'ssRenderBody'], bset: ['ssRenderTools', 'ssRenderBody'],
  about: ['ssRenderTools', 'ssRenderBody']
};

function mkStorage(init){
  const store = Object.assign({}, init || {});
  const log = [];
  return {
    log: log, store: store,
    getItem(k){ log.push('get ' + k); return Object.prototype.hasOwnProperty.call(store, k) ? store[k] : null; },
    setItem(k, v){ log.push('set ' + k + '=' + String(v)); store[k] = String(v); },
    removeItem(k){ log.push('del ' + k); delete store[k]; }
  };
}

function argText(args){
  return Array.prototype.map.call(args, function(a){
    return (a === undefined) ? 'undefined' : JSON.stringify(a);
  }).join(',');
}

// Novy izolovany kontext okna. `opts.page` (predvolene studio.html), `opts.storage`
// (pociatocny obsah localStorage), `opts.files` (vlastny zoznam skriptov).
function load(opts){
  const o = opts || {};
  const W = {};          // pocet zapisov innerHTML podla id uzla
  const LOG = [];        // volania haciakov a Ruby v poradi
  const LISTEN = {};
  const nodes = {};
  function node(id){
    if (!nodes[id]){
      const n = H12.mkNode(id);
      let html = '';
      Object.defineProperty(n, 'innerHTML', {
        get(){ return html; },
        set(v){ html = String(v); W[id] = (W[id] || 0) + 1; },
        enumerable: true, configurable: true
      });
      nodes[id] = n;
    }
    return nodes[id];
  }
  const doc = {
    getElementById: node,
    querySelector(sel){ return node('qs:' + sel); },
    querySelectorAll(){ return []; },
    createElement(tag){ return H12.mkNode('_' + tag); },
    createTextNode(t){ return { textContent: t }; },
    addEventListener(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
    removeEventListener(){},
    activeElement: null
  };
  doc.body = H12.mkNode('body');
  doc.documentElement = H12.mkNode('html');
  const storage = mkStorage(o.storage);
  const sketchup = new Proxy({}, {
    get(t, k){
      if (typeof k !== 'string' || k === 'then' || k === 'toJSON') return undefined;
      return function(){ LOG.push('sketchup.' + k + '(' + argText(arguments) + ')'); };
    }
  });
  const ctx = {
    document: doc, console: console, navigator: { userAgent: 'node' },
    setTimeout(){ return 0; }, clearTimeout(){}, setInterval(){ return 0; }, clearInterval(){},
    requestAnimationFrame(){ return 0; },
    Event: function(t){ this.type = t; }, JSON: JSON, Math: Math,
    addEventListener(){}, removeEventListener(){},
    localStorage: storage, sketchup: sketchup,
    NX_FIT_MIN: { w: 1060, h: 640 }, NX_MAT_SECTION: true, NX_HW_SECTION: true
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  const files = o.files || H12.panelScripts(o.page || 'studio.html');
  files.forEach(function(f){
    vm.runInContext(fs.readFileSync(path.join(UI, 'js', f), 'utf8'), ctx, { filename: f });
  });
  const L = { ctx: ctx, W: W, LOG: LOG, LISTEN: LISTEN, storage: storage, files: files, node: node,
              anchorRet: [] };
  return L;
}

// Citacka stavu `studio.js` (top-level premenne su vo `vm` vlastnosti globalu).
function rd(L, name){ return vm.runInContext(name, L.ctx); }
function wr(L, name, value){ L.ctx.__h14v = value; vm.runInContext(name + ' = __h14v', L.ctx); delete L.ctx.__h14v; }

function stateTag(L){
  const c = L.ctx;
  const st = rd(L, 'ST');
  const m = (rd(L, 'vepoMenuOpen') ? '1' : '0') + (rd(L, 'ecMenuOpen') ? '1' : '0') + (rd(L, 'colMenuOpen') ? '1' : '0');
  return ' @' + c.studioActiveSection() + ' m' + m + ' g' + (st ? st.model_guid : 'null');
}

// Kontrola existencie haciakov PRED instalaciou spehov (R5 f / §15 A5).
function missingHooks(L){
  return HOOKS.concat(ANCHORS).filter(function(n){ return typeof L.ctx[n] !== 'function'; });
}

// Spehy LEN nahradzaju existujuce funkcie; vrati zoznam chybajucich.
function install(L){
  const missing = [];
  HOOKS.concat(ANCHORS).forEach(function(n){
    if (typeof L.ctx[n] !== 'function'){ missing.push(n); return; }
    const isAnchor = ANCHORS.indexOf(n) >= 0;
    L.ctx[n] = function(){
      L.LOG.push(n + '(' + argText(arguments) + ')' + stateTag(L));
      if (isAnchor) return L.anchorRet.length ? L.anchorRet.shift() : true;
      return undefined;
    };
  });
  L.spies = {};
  HOOKS.concat(ANCHORS).forEach(function(n){ L.spies[n] = L.ctx[n]; });
  return missing;
}

function resetCounters(L){
  L.LOG.length = 0;
  Object.keys(L.W).forEach(function(k){ delete L.W[k]; });
}
function writes(L){
  return { snav: L.W.snav || 0, sechead: L.W.sechead || 0, sectools: L.W.sectools || 0, secbody: L.W.secbody || 0 };
}
function menus(L){
  return (rd(L, 'vepoMenuOpen') ? '1' : '0') + (rd(L, 'ecMenuOpen') ? '1' : '0') + (rd(L, 'colMenuOpen') ? '1' : '0');
}
function openMenus(L){ wr(L, 'vepoMenuOpen', true); wr(L, 'ecMenuOpen', true); wr(L, 'colMenuOpen', true); }

// Ciel kliku/zmeny: `closest` odpoveda LEN na selektory, ktore uzol naozaj ma.
// `attrs` = mapa atributov (`data-nav` → 'bom'); selektor `[a]` aj `[a="v"]`.
function target(attrs, extra){
  const a = attrs || {};
  const el = Object.assign({
    id: '', checked: false, value: '', tagName: 'BUTTON',
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k) ? a[k] : null; },
    hasAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k); },
    matches(){ return false; },
    focus(){}, blur(){}
  }, extra || {});
  el.closest = function(sel){
    const m = /^\[([a-z-]+)\]$/.exec(sel);
    if (m && Object.prototype.hasOwnProperty.call(a, m[1])) return el;
    return null;
  };
  return el;
}
function fire(L, type, tgt, extra){
  (L.LISTEN[type] || []).forEach(function(fn){
    fn(Object.assign({ type: type, target: tgt, preventDefault(){}, stopPropagation(){} }, extra || {}));
  });
}

// ------------------------------------------------------------ pevny payload
const ROWS = [
  { names: ['Bok ľavý'], kde: [{ owner_id: 'CAB-004', quantity: 1 }], material_id: 'M500', role_label: 'Bok ľavý',
    length: 720, width: 560, thickness: 18, quantity: 1, grain_direction: 'length',
    edges: { L1: 'A1', L2: null, W1: 'A1', W2: null }, key: ['k', 'a'] },
  { names: ['Polica'], kde: [{ owner_id: 'CAB-009', quantity: 2 }], material_id: 'M500', role_label: 'Polica',
    length: 560, width: 530, thickness: 18, quantity: 2, grain_direction: 'none', edges: { L1: 'A2' }, key: ['k', 'b'] },
  { names: ['Čelo F1'], kde: [{ owner_id: 'CAB-004', quantity: 1 }], material_id: 'K686', role_label: 'Dvierka',
    length: 355, width: 596, thickness: 18, quantity: 1, grain_direction: 'width', edges: {}, key: ['k', 'c'] }
];
function payload(extra){
  const base = {
    version: '0.0.0-golden', gen: 1, model_title: 'GOLDEN', model_guid: 'G1',
    rows: ROWS,
    sheets: [{ material_id: 'M500', m2: 6.84, quantity: 10 }, { material_id: 'K686', m2: 2.42, quantity: 7 }],
    edging: [{ edge_id: 'A1', bm: 3.2, quantity: 2 }, { edge_id: 'A2', bm: 1.1, quantity: 1 }],
    hardware: [{ key: 'H1', generic_type: 'hinge', label: 'Záves', quantity: 4, params: { angle: '110' },
                 params_label: null, breakdown: [{ owner_id: 'CAB-1', quantity: 4 }] }],
    hardware_sets: { rows: [{ code: '9071193', name_sk: 'Záves Sensys 110°', category: 'ZAVESY', category_label: 'Závesy',
                              quantity: 4, unit: 'ks', price_eur_vat: 3.5, subtotal_eur_vat: 14 }],
                     unmapped: [], summary: { total_eur_vat: 14, unknown_prices: 0 } },
    summary: { quantity: 4, rows: 3, m2_total: 9.26, bm_total: 4.3 },
    sheet_estimate: [{ material_id: 'M500', m2: 6.84, sheet_size: [2800, 2070], count_min: 1.3, count_max: 1.5 }],
    totals: { parts: 4, rows: 3, m2: 9.26, bm: 4.3, materials: 2, edges: 2, plates_min: 1.3, plates_max: 1.5 },
    materials_meta: { M500: { label: 'Biela W1000', color: [246, 246, 243] }, K686: { label: 'K686 Dub', color: [124, 90, 58] } },
    edges_meta: { A1: { label: 'K686 22×1', th: 1.0 }, A2: { label: 'K686 22×2', th: 2.0 } },
    vepo: { project: 'GOLDEN', default_project: 'GOLDEN', merge_18_36: true },
    control: [
      { severity: 'red', category: 'material', owner_id: 'CAB-001', message_sk: 'Materiál mimo katalógu',
        stable_key: 'material|CAB-001|bok_l' },
      { severity: 'orange', category: 'budget', owner_id: null, budget_section: 'services',
        message_sk: 'Rozpočet: montáž bez sadzby', stable_key: 'budget|services|rate' }
    ],
    counts: { red: 2, orange: 3, total: 5, cabinets: 9, clean: 6 },
    budget: null, sheet_layout: null,
    edge_check: { available: true, active: false, options: {}, counts: {} },
    grain_check: null, direction_check: null,
    mat: null, hw: null, appl: { job: { counts: { orange: 5 } } }, rules: null, tpl: null, settings: null,
    open_section: null, anchor: null
  };
  return JSON.parse(JSON.stringify(Object.assign(base, extra || {})));
}

// Pripraveny kontext: nacitany, spehy nainstalovane, prvy payload doruceny.
function ready(opts){
  const L = load(opts);
  const missing = install(L);
  if (missing.length) throw new Error('H14 harness: chybaju haciky ' + missing.join(', '));
  L.ctx.NX.setStudio(payload());
  resetCounters(L);
  return L;
}
// Prepni sekciu NAVIGACIOU a zabudni, co sa pri tom volalo (priprava stavu).
function goQuiet(L, id){ L.ctx.studioGoSection(id); resetCounters(L); }
// Cerstvy payload toho isteho dokumentu bez deep-linku (zhodi `staleFlag`).
function refreshQuiet(L){ L.ctx.NX.setStudio(payload()); resetCounters(L); }

function snapNav(L){
  return { snav: L.node('snav').innerHTML, sechead: L.node('sechead').innerHTML,
           studio: L.node('studio').className };
}

// ================================================================== GOLDEN
function g1(){
  const L = ready();
  const out = {};
  ids().forEach(function(id){ goQuiet(L, id); out[id] = snapNav(L); });
  goQuiet(L, 'bom');
  wr(L, 'navMini', true);
  L.ctx.studioGoSection('ctrl');
  out['mini:ctrl'] = snapNav(L);
  return out;
}

function g2(){
  const L = ready();
  const out = {};
  ids().forEach(function(id){
    refreshQuiet(L);
    if (L.ctx.studioActiveSection() === id) goQuiet(L, 'bom');
    resetCounters(L);
    L.ctx.studioGoSection(id);
    const fresh = L.LOG.slice();
    resetCounters(L);
    L.ctx.NX.markStale();
    const staleTools = L.LOG.slice();
    resetCounters(L);
    L.ctx.renderBody();
    const staleBody = L.LOG.slice();
    out[id] = { fresh: fresh, stale_tools: staleTools, stale_body: staleBody };
  });
  // Kusovnik (3 pohlady), Kontrola a Nakup kresli studio.js sam.
  const own = {};
  refreshQuiet(L);
  ['parts', 'sheets', 'abs'].forEach(function(v){
    goQuiet(L, 'ctrl');
    wr(L, 'bomView', v);
    L.ctx.studioGoSection('bom');
    own['bom:' + v] = { tools: L.node('sectools').innerHTML, body: L.node('secbody').innerHTML };
  });
  wr(L, 'bomView', 'parts');
  ['ctrl', 'buy'].forEach(function(id){
    goQuiet(L, 'bom');
    L.ctx.studioGoSection(id);
    own[id] = { tools: L.node('sectools').innerHTML, body: L.node('secbody').innerHTML };
  });
  goQuiet(L, 'bom');
  L.ctx.NX.markStale();
  own['bom:stale'] = { tools: L.node('sectools').innerHTML };
  // Variant „modul chyba": haciky lista/telo zmazane → nudzovy text, prazdna lista.
  const missing = {};
  Object.keys(EXTERNAL).forEach(function(id){
    refreshQuiet(L);
    goQuiet(L, 'bom');
    const names = EXTERNAL[id];
    names.forEach(function(n){ L.ctx[n] = undefined; });
    L.node('sectools').innerHTML = 'X';
    L.ctx.studioGoSection(id);
    missing[id] = { tools: L.node('sectools').innerHTML, body: L.node('secbody').innerHTML, calls: L.LOG.slice() };
    names.forEach(function(n){ L.ctx[n] = L.spies[n]; });
  });
  return { hooks: out, own: own, missing: missing };
}

function transition(L, kind, from, to){
  goQuiet(L, from);
  openMenus(L);
  resetCounters(L);
  if (kind === 'nav') L.ctx.studioGoSection(to);
  else L.ctx.NX.setStudio(payload({ open_section: to }));
  return { calls: L.LOG.slice(), sec: L.ctx.studioActiveSection(), menus: menus(L), writes: writes(L) };
}

function g3(){
  const L = ready();
  const pairs = {};
  const all = ids();
  ['nav', 'link'].forEach(function(kind){
    all.forEach(function(a){
      all.forEach(function(b){ pairs[kind + ':' + a + '>' + b] = transition(L, kind, a, b); });
      ['xyz', null, '', undefined].forEach(function(bad){
        pairs[kind + ':' + a + '>' + String(bad === '' ? "''" : bad)] = transition(L, kind, a, bad);
      });
    });
  });
  return pairs;
}

// Dokumentova matica (§15 A2): prvy payload / rovnaky dokument / zmena dokumentu
// × bez deep-linku / deep-link do tej istej / do inej sekcie.
function g3docs(){
  const all = ids();
  const out = {};
  all.forEach(function(start, i){
    const other = all[(i + 7) % all.length];
    const opens = { none: null, same: start, other: other };
    Object.keys(opens).forEach(function(ok){
      // Prvy payload: cerstve okno, ST = null.
      const F = load();
      const miss = install(F);
      if (miss.length) throw new Error('H14 harness: chybaju haciky ' + miss.join(', '));
      F.ctx.studioSetSectionForTest(start);
      openMenus(F);
      resetCounters(F);
      F.ctx.NX.setStudio(payload({ open_section: opens[ok] }));
      out['first:' + start + ':' + ok] = { calls: F.LOG.slice(), sec: F.ctx.studioActiveSection(), menus: menus(F),
                                           writes: writes(F) };
    });
  });
  const L = ready();
  all.forEach(function(start, i){
    const other = all[(i + 7) % all.length];
    const opens = { none: null, same: start, other: other };
    [['same', 'G1'], ['other_doc', 'G2']].forEach(function(dv){
      Object.keys(opens).forEach(function(ok){
        refreshQuiet(L);
        goQuiet(L, start);
        openMenus(L);
        resetCounters(L);
        L.ctx.NX.setStudio(payload({ model_guid: dv[1], open_section: opens[ok] }));
        out[dv[0] + ':' + start + ':' + ok] = { calls: L.LOG.slice(), sec: L.ctx.studioActiveSection(), menus: menus(L),
                                                writes: writes(L) };
      });
    });
  });
  return out;
}

function g4(){
  const L = ready();
  const out = {};
  ids().forEach(function(id){
    [true, false].forEach(function(ret){
      refreshQuiet(L);
      goQuiet(L, id === 'bom' ? 'ctrl' : 'bom');
      wr(L, 'bomQ', '');
      L.node('status').textContent = '';
      L.anchorRet = [ret];
      L.ctx.NX.setStudio(payload({ open_section: id, anchor: ' A1 ' }));
      out[id + ':' + ret] = { calls: L.LOG.slice(), bomQ: rd(L, 'bomQ'), status: L.node('status').textContent,
                              statusCls: L.node('status').className, sec: L.ctx.studioActiveSection(),
                              tools: id === 'bom' ? L.node('sectools').innerHTML : null };
      L.anchorRet = [];
    });
  });
  return out;
}

function g5(){
  const L = ready();
  const out = {};
  ids().forEach(function(id){
    goQuiet(L, id === 'bom' ? 'ctrl' : 'bom');
    goQuiet(L, id);
    L.node('status').textContent = '';
    L.ctx.requestRefresh();
    out[id] = { status: L.node('status').textContent, calls: L.LOG.slice() };
  });
  return out;
}

function g6(){
  const P = load({ page: 'panel.html' });
  const S = P.ctx.NXShell;
  const out = {};
  const secs = ids().concat(['xyz', '', null, undefined, 'BOM', ' bom', '__proto__', 0]);
  secs.forEach(function(s){
    [' A ', '', null].forEach(function(a){
      out[String(s === '' ? "''" : s) + '|' + String(a === '' ? "''" : a)] = S.studioOpenLink(s, a);
    });
    out['section:' + String(s === '' ? "''" : s)] = S.studioSection(s);
  });
  return out;
}

function g7(){
  const L = ready();
  const out = {};
  ids().forEach(function(id){ goQuiet(L, id); out[id] = L.ctx.ssActive(); });
  return out;
}

// G8 — navrat do rozpracovanej sekcie (UI20_KONTRAKT §3).
function g8(){
  const out = {};
  ['nav', 'link'].forEach(function(kind){
    const L = ready();
    function go(id){ if (kind === 'nav') L.ctx.studioGoSection(id); else L.ctx.NX.setStudio(payload({ open_section: id })); }
    goQuiet(L, 'bom');
    wr(L, 'bomView', 'sheets');
    wr(L, 'bomQ', 'X');
    wr(L, 'groupClosed', { M500: true });
    rd(L, 'COLS')[1].on = false;
    go('mat');
    go('bom');
    out[kind + ':bom'] = { bomView: rd(L, 'bomView'), bomQ: rd(L, 'bomQ'), groupClosed: rd(L, 'groupClosed'),
                           cols: rd(L, 'COLS').map(function(c){ return c.k + ':' + c.on; }),
                           tools: L.node('sectools').innerHTML, body: L.node('secbody').innerHTML };
    goQuiet(L, 'ctrl');
    wr(L, 'ctrlFilter', 'red');
    go('hw');
    go('ctrl');
    out[kind + ':ctrl'] = { ctrlFilter: rd(L, 'ctrlFilter'), tools: L.node('sectools').innerHTML,
                            body: L.node('secbody').innerHTML };
  });
  return out;
}

// G9 — pamat tohto pocitaca (kluce localStorage pred `window.onload`).
function g9(){
  const L = load({ storage: { nx_bom_cols: JSON.stringify({ cab: false, grain: true }),
                              nx_bom_groups: JSON.stringify({ K686: true }), nx_studio_nav: 'mini' } });
  const miss = install(L);
  if (miss.length) throw new Error('H14 harness: chybaju haciky ' + miss.join(', '));
  L.ctx.onload();
  L.ctx.NX.setStudio(payload());
  const out = { after_load: { studio: L.node('studio').className,
                              cols: rd(L, 'COLS').map(function(c){ return c.k + ':' + c.on; }),
                              groupClosed: rd(L, 'groupClosed'), body: L.node('secbody').innerHTML,
                              storage_log: L.storage.log.slice(), calls: L.LOG.slice() } };
  L.storage.log.length = 0;
  resetCounters(L);
  fire(L, 'click', target({ 'data-navmini': '' }));
  out.navmini_click = { storage_log: L.storage.log.slice(), studio: L.node('studio').className, writes: writes(L) };
  L.storage.log.length = 0;
  fire(L, 'change', target({ 'data-col': '6' }, { checked: false }));
  out.col_change = { storage_log: L.storage.log.slice(),
                     cols: rd(L, 'COLS').map(function(c){ return c.k + ':' + c.on; }) };
  return out;
}

// G10 — ovladanie navigacie cez zachyteny listener.
function g10(){
  const L = ready();
  const out = { clicks: {} };
  ids().concat(['xyz']).forEach(function(id){
    goQuiet(L, id === 'bom' ? 'ctrl' : 'bom');
    fire(L, 'click', target({ 'data-nav': id }));
    out.clicks[id] = { sec: L.ctx.studioActiveSection(), writes: writes(L), calls: L.LOG.slice() };
  });
  goQuiet(L, 'bom');
  fire(L, 'click', target({ 'data-navmini': '' }));
  out.navmini = { studio: L.node('studio').className, writes: writes(L) };
  out.buttons = L.node('snav').innerHTML.match(/<button type="button"[^>]*data-nav="[^"]*"[^>]*>/g);
  return out;
}

// Zapis fixtury: kazdy kluc prvej urovne na vlastnom riadku, hodnota kompaktne
// (citatelny diff, polovicna velkost oproti odsadenemu JSON).
function serialize(obj){
  const keys = Object.keys(obj);
  return '{\n' + keys.map(function(k, i){
    return JSON.stringify(k) + ': ' + JSON.stringify(obj[k] === undefined ? null : obj[k]) + (i < keys.length - 1 ? ',' : '');
  }).join('\n') + '\n}\n';
}

function golden(){
  return { g1_nav: g1(), g2_dispatch: g2(), g3_transitions: g3(), g3_documents: g3docs(), g4_anchors: g4(),
           g5_refresh: g5(), g6_inspector: g6(), g7_settings: g7(), g8_return: g8(), g9_prefs: g9(),
           g10_controls: g10() };
}

module.exports = { load: load, install: install, missingHooks: missingHooks, ready: ready, payload: payload,
                   golden: golden, serialize: serialize, contract: contract, ids: ids, target: target, fire: fire, rd: rd, wr: wr,
                   resetCounters: resetCounters, writes: writes, goQuiet: goQuiet,
                   HOOKS: HOOKS, ANCHORS: ANCHORS, ROOT: ROOT, UI: UI, GOLDEN_DIR: GOLDEN_DIR,
                   FIXTURE_SECTIONS: FIXTURE_SECTIONS };
