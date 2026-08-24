// PICKER-1 (review #230 P2) — ŽIVOTNÝ CYKLUS vyhľadávača nad PERZISTENTNÝM
// telom sekcie.
//
// Prečo to musí byť DOM test a nie grep: sekcia Materiály si telo drží ako
// JEDEN uzol, ktorý odchod zo sekcie ODPOJÍ a návrat vráti (aj s rozpísaným
// formulárom). Kým bolo odpojené, katalógové echo na pozadí spustilo `scan`,
// ten polia len ODREGISTROVAL — obal aj tlačidlo však ostali v odpojenom
// strome, takže návrat obalil ten istý select DRUHÝKRÁT a používateľ videl
// DVA ovládače (a s každým ďalším echom o jeden viac). Číta sa to len z
// výsledného DOM, nie zo zdrojáku.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// --- minimálny DOM (len to, čo komponent naozaj používa) --------------------
function el(tag){
  const node = {
    tagName: String(tag).toUpperCase(),
    children: [], parentNode: null, _attrs: {}, style: {}, className: '',
    value: '', disabled: false, innerHTML: '', title: '',
    options: [],
    appendChild(c){ if (c.parentNode) c.parentNode.removeChild(c); c.parentNode = node; node.children.push(c); return c; },
    insertBefore(c, ref){
      if (c.parentNode) c.parentNode.removeChild(c);
      const i = node.children.indexOf(ref);
      c.parentNode = node;
      if (i < 0) node.children.push(c); else node.children.splice(i, 0, c);
      return c;
    },
    removeChild(c){
      const i = node.children.indexOf(c);
      if (i >= 0){ node.children.splice(i, 1); c.parentNode = null; }
      return c;
    },
    setAttribute(k, v){ node._attrs[k] = String(v); },
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(node._attrs, k) ? node._attrs[k] : null; },
    removeAttribute(k){ delete node._attrs[k]; },
    hasAttribute(k){ return Object.prototype.hasOwnProperty.call(node._attrs, k); },
    addEventListener(){}, removeEventListener(){},
    getBoundingClientRect(){ return { width: 180, height: 24, top: 10, bottom: 34, left: 10, right: 190 }; },
    querySelector(){ return null; },
    querySelectorAll(sel){ return walk(node).filter(nd => matches(nd, sel)); },
    contains(other){ return walk(node).indexOf(other) >= 0; },
    focus(){}
  };
  return node;
}
function walk(root){
  const out = [];
  (function rec(nd){ (nd.children || []).forEach(c => { out.push(c); rec(c); }); })(root);
  return out;
}
function matches(nd, sel){
  if (sel === 'select[data-nx-combo]') return nd.tagName === 'SELECT' && nd.hasAttribute('data-nx-combo');
  if (sel === '.nxcombo') return String(nd.className || '').indexOf('nxcombo') > -1;
  if (sel === '.cbtrigger') return String(nd.className || '').indexOf('cbtrigger') > -1;
  return false;
}

const body = el('body');
global.document = {
  body,
  createElement: el,
  addEventListener(){}, removeEventListener(){},
  querySelectorAll(sel){ return body.querySelectorAll(sel); },
  querySelector(){ return null; },
  getElementById(){ return null; },
  activeElement: null
};
global.window = { innerWidth: 470, innerHeight: 800, document: global.document,
                  addEventListener(){}, removeEventListener(){} };
// localStorage: komponent si pamätá „naposledy použité" — stačí prázdna pamäť.
global.localStorage = { getItem(){ return null; }, setItem(){}, removeItem(){} };

const NXC = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'nx_combo.js'));

// --- fixtúra: telo sekcie s jednou predvoľbou ------------------------------
const section = el('div');           // perzistentné telo sekcie (MAT_BODY)
const row = el('div');
const sel = el('select');
sel.setAttribute('data-nx-combo', 'decor');
row.appendChild(sel);
section.appendChild(row);
body.appendChild(section);

function triggers(){ return body.querySelectorAll('.cbtrigger').length; }
function wrappers(){ return body.querySelectorAll('.nxcombo').length; }
function detachedTriggers(){ return section.querySelectorAll('.cbtrigger').length; }

// --- 1) prvé pripojenie ----------------------------------------------------
NXC.scan(document);
eq(triggers(), 1, 'po prvom scane je PRÁVE JEDEN ovládač');
eq(wrappers(), 1, 'a jeden obal');

// --- 2) odchod zo sekcie + katalógové echo na pozadí -----------------------
body.removeChild(section);           // presne to robí prepnutie sekcie
NXC.scan(document);                  // echo na pozadí (NX.setMatCatalog)
eq(detachedTriggers(), 0,
   'odpojené pole sa ROZBALÍ — v odpojenom strome neostáva osirelý ovládač');
ok(sel.parentNode === row, 'select je späť na svojom mieste (obal je preč)');
ok(sel.getAttribute('tabindex') === null && sel.getAttribute('aria-hidden') === null,
   'a atribúty, ktoré komponent pridal, sú zrušené');

// --- 3) návrat do sekcie ---------------------------------------------------
body.appendChild(section);
NXC.scan(document);
eq(triggers(), 1, 'po návrate je opäť PRÁVE JEDEN ovládač (nie dva)');
eq(wrappers(), 1, 'a jeden obal');

// --- 4) opakované echá počas neprítomnosti sa nesčítavajú ------------------
body.removeChild(section);
NXC.scan(document);
NXC.scan(document);
NXC.scan(document);
body.appendChild(section);
NXC.scan(document);
eq(triggers(), 1, 'ani po TROCH echách na pozadí nepribudol ďalší ovládač');
eq(wrappers(), 1, 'ani ďalší obal');

// --- 5) opakovaný scan nad PRIPOJENÝM telom nič nezdvojuje -----------------
NXC.scan(document);
NXC.scan(document);
eq(triggers(), 1, 'a scan nad pripojeným telom je idempotentný');

// --- 6) `detach` je aj verejný most pre hostiteľa --------------------------
ok(typeof NXC.detach === 'function', 'komponent ponúka `detach` (hostiteľ vie uzol rozbaliť sám)');
NXC.detach(sel);
eq(triggers(), 0, 'po výslovnom `detach` ovládač zmizne');
NXC.scan(document);
eq(triggers(), 1, 'a ďalší scan ho vytvorí čisto raz');

console.log(`OK test_picker1_combo_dom.js — ${n} kontrol`);
