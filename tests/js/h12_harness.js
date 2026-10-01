// H12 — spolocna kostra JS sad typov skrinky (golden `test_h12_golden.js`
// a register `test_h12c_typy.js`). NIE JE to testovacia sada (nema prefix
// `test_`), CI ju samostatne nespusta.
//
// Nacita skripty Inspectora do JEDNEHO `vm` kontextu PRESNE v poradi
// `panel.html` (ako CEF: spolocny globalny priestor, ziadne Node exporty) nad
// povolnym stubom DOM — kazde `getElementById` vrati (a zapamata si) uzol, takze
// funkcie bezia bez rucneho skladania kostry. Stav uzlov je potom odtlacok:
// co funkcia skryla, zamkla alebo prepisala.
'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const UI = path.join(ROOT, 'noxun_engine', 'ui');
const FIXTURE_TYPES = path.join(ROOT, 'tests', 'fixtures', 'h12_cabinet_types.json');

// Skripty mimo testu: chybove hlasenie okna, prisposobenie velkosti, kolieska
// a boot (`window.onload` + `sketchup.ready`) — volanie init robi test sam.
const SKIP = { 'errors.js': 1, 'win_fit.js': 1, 'boot.js': 1 };

// Skripty okna v poradi jeho HTML (`panel.html` = Inspector, `studio.html` = Studio).
function panelScripts(page){
  const html = fs.readFileSync(path.join(UI, page || 'panel.html'), 'utf8');
  const out = [];
  const re = /<script src="js\/([a-z_0-9]+\.js)\?v=[^"]*"><\/script>/g;
  let m;
  while ((m = re.exec(html))) if (!SKIP[m[1]]) out.push(m[1]);
  return out;
}

function mkNode(id){
  const n = {
    id: id, value: '', style: {}, hidden: false, title: '', textContent: '', innerHTML: '',
    disabled: false, readOnly: false, checked: false, attrs: {}, cls: {}, options: [], children: [], dataset: {},
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(n.attrs, k) ? n.attrs[k] : null; },
    setAttribute(k, v){ n.attrs[k] = String(v); },
    removeAttribute(k){ delete n.attrs[k]; },
    hasAttribute(k){ return Object.prototype.hasOwnProperty.call(n.attrs, k); },
    addEventListener(){}, removeEventListener(){}, dispatchEvent(){ return true; },
    querySelector(){ return null; }, querySelectorAll(){ return []; }, closest(){ return null; },
    appendChild(c){ n.children.push(c); return c; }, insertAdjacentElement(){}, insertAdjacentHTML(){},
    focus(){}, blur(){}, select(){}, scrollIntoView(){}, contains(){ return false; },
    getBoundingClientRect(){ return { left: 0, top: 0, width: 0, height: 0, right: 0, bottom: 0 }; },
    parentNode: { replaceChild(){}, removeChild(){}, insertBefore(){}, appendChild(){} }
  };
  n.classList = {
    add(c){ n.cls[c] = 1; }, remove(c){ delete n.cls[c]; }, contains(c){ return !!n.cls[c]; },
    toggle(c, on){ const w = (on === undefined) ? !n.cls[c] : !!on; if (w) n.cls[c] = 1; else delete n.cls[c]; return w; }
  };
  return n;
}

// Novy izolovany kontext so vsetkymi skriptami okna (`opts.page`, predvolene
// Inspector) — register typov este NIE JE doruceny (stav CEF pred `NX.init`).
function load(opts){
  const o = opts || {};
  const nodes = {};
  const doc = {
    getElementById(id){ return nodes[id] || (nodes[id] = mkNode(id)); },
    querySelector(sel){ const k = 'qs:' + sel; return nodes[k] || (nodes[k] = mkNode(k)); },
    querySelectorAll(){ return []; },
    createElement(tag){ return mkNode('_' + tag); },
    createTextNode(t){ return { textContent: t }; },
    addEventListener(){}, removeEventListener(){},
    activeElement: null
  };
  doc.body = mkNode('body');
  doc.documentElement = mkNode('html');
  const ctx = {
    document: doc, console: console, navigator: { userAgent: 'node' },
    setTimeout(){ return 0; }, clearTimeout(){}, setInterval(){ return 0; }, clearInterval(){},
    requestAnimationFrame(){ return 0; },
    Event: function(t){ this.type = t; }, JSON: JSON, Math: Math,
    addEventListener(){}, removeEventListener(){}
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  const files = o.files || panelScripts(o.page);
  files.forEach(function(f){
    vm.runInContext(fs.readFileSync(path.join(UI, 'js', f), 'utf8'), ctx, { filename: f });
  });
  return { ctx: ctx, nodes: nodes, node: function(id){ return doc.getElementById(id); }, files: files };
}

function registry(){ return JSON.parse(fs.readFileSync(FIXTURE_TYPES, 'utf8')); }

module.exports = { load: load, registry: registry, panelScripts: panelScripts, mkNode: mkNode,
                   ROOT: ROOT, UI: UI };
