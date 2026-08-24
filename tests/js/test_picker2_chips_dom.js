// PICKER-2 — ČIPY v OTVORENEJ ponuke (DOM, nie grep).
//
// Čisté funkcie (zoskupenie, default, preselekcia z dotazu) overuje
// `test_picker2_chips.js`. Tu ide o to, čo z nich naozaj vznikne na obrazovke
// a čo urobí klik:
//   · čipy sa kreslia LEN pri viacerých hrúbkach a aktívny je ten, ktorý
//     riadok práve vloží,
//   · klik na čip ponuku NEZATVORÍ (je to zúženie výberu, nie výber) a zmení
//     to, čo Enter/klik na riadok vloží,
//   · výsledkom je `material_id` KONKRÉTNEHO variantu — serverová cesta sa
//     nemení (E-03: hrúbku určuje reálny materiál).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// --- minimálny DOM ----------------------------------------------------------
const LISTEN = {};
function el(tag){
  const node = {
    tagName: String(tag).toUpperCase(),
    children: [], parentNode: null, _attrs: {}, style: {}, className: '',
    value: '', disabled: false, innerHTML: '', title: '', selectedIndex: -1, options: [],
    appendChild(c){ if (c.parentNode) c.parentNode.removeChild(c); c.parentNode = node; node.children.push(c); return c; },
    insertBefore(c, ref){
      if (c.parentNode) c.parentNode.removeChild(c);
      const i = node.children.indexOf(ref);
      c.parentNode = node;
      if (i < 0) node.children.push(c); else node.children.splice(i, 0, c);
      return c;
    },
    removeChild(c){ const i = node.children.indexOf(c); if (i >= 0){ node.children.splice(i, 1); c.parentNode = null; } return c; },
    setAttribute(k, v){ node._attrs[k] = String(v); },
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(node._attrs, k) ? node._attrs[k] : null; },
    removeAttribute(k){ delete node._attrs[k]; },
    hasAttribute(k){ return Object.prototype.hasOwnProperty.call(node._attrs, k); },
    _ls: {},
    addEventListener(type, fn){ (node._ls[type] || (node._ls[type] = [])).push(fn); },
    removeEventListener(){},
    getBoundingClientRect(){ return { width: 180, height: 24, top: 10, bottom: 34, left: 10, right: 190 }; },
    getElementsByTagName(t){ return walk(node).filter(x => x.tagName === String(t).toUpperCase()); },
    querySelector(sel){
      const hit = walk(node).filter(x => matches(x, sel))[0];
      if (hit) return hit;
      // Popup si obsah stavia cez `innerHTML` (stub uzly nevytvára), ale
      // komponent na `input` a `.cblist` vešia listenery a píše do nich —
      // preto ich stub vyrobí na požiadanie a zapamätá.
      if (sel === 'input' || sel === '.cblist'){
        node._virt = node._virt || {};
        if (!node._virt[sel]){
          const v = el(sel === 'input' ? 'input' : 'div');
          v.className = (sel === '.cblist') ? 'cblist' : '';
          node._virt[sel] = v;
          node.children.push(v);
          v.parentNode = node;
        }
        return node._virt[sel];
      }
      return null;
    },
    querySelectorAll(sel){ return walk(node).filter(x => matches(x, sel)); },
    contains(other){ return other === node || walk(node).indexOf(other) >= 0; },
    focus(){}, scrollIntoView(){},
    // Potvrdenie voľby ide TOU ISTOU cestou ako natívny výber —
    // `change` (na ňom visia všetky serverové guardy). Test ho počíta.
    dispatchEvent(ev){ node._events = (node._events || []).concat([ev && ev.type]); return true; }
  };
  return node;
}
function walk(root){
  const out = [];
  (function rec(nd){ (nd.children || []).forEach(c => { out.push(c); rec(c); }); })(root);
  return out;
}
function matches(nd, sel){
  const cls = String(nd.className || '');
  if (sel === 'select[data-nx-combo]') return nd.tagName === 'SELECT' && nd.hasAttribute('data-nx-combo');
  if (sel.charAt(0) === '.') return cls.split(/\s+/).indexOf(sel.slice(1)) >= 0;
  return false;
}

const body = el('body');
global.document = {
  body,
  createElement: el,
  addEventListener(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  removeEventListener(){},
  querySelectorAll(sel){ return body.querySelectorAll(sel); },
  querySelector(sel){ return body.querySelector(sel); },
  getElementById(){ return null; },
  activeElement: null
};
global.window = { innerWidth: 470, innerHeight: 800, document: global.document,
                  addEventListener(){}, removeEventListener(){} };
global.localStorage = { getItem(){ return null; }, setItem(){}, removeItem(){} };
global.Event = function(type){ this.type = type; };

const NXC = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'nx_combo.js'));

// --- fixtúra: select s dekorom v 18/36/duplák + HDF 3 -----------------------
const META = {
  dtd18: { decor: 'Dub sonoma', type: 'DTDL', thickness: 18 },
  dtd36: { decor: 'Dub sonoma', type: 'DTDL', thickness: 36 },
  'duplak2:dtd18': { decor: 'Dub sonoma', type: 'DTDL', thickness: 36, duplak: true },
  hdf3: { decor: 'Dub sonoma', type: 'HDF', thickness: 3 }
};
NXC.setVariantResolver((kind, value) => (kind === 'abs' ? null : (META[value] || null)));

const sel = el('select');
sel.setAttribute('data-nx-combo', 'decor');
sel.setAttribute('data-nx-combo-ctx', 'body');
['dtd18', 'dtd36', 'duplak2:dtd18', 'hdf3'].forEach(function(v){
  const o = el('option');
  o.value = v;
  o.textContent = v;
  sel.appendChild(o);
  sel.options.push(o);
});
sel.value = 'dtd18';
sel.selectedIndex = 0;
body.appendChild(sel);
NXC.scan(document);

function popHtml(){
  const list = body.querySelector('.cblist');
  return list ? list.innerHTML : '';
}
function popNode(){ return body.children.filter(c => String(c.className).indexOf('cbpop') > -1).pop(); }
// Výber ide MOUSEDOWN-om na popupe (D-67 FIX 4) — blur by ponuku zavrel skôr,
// než klik dopadne. Test ide tou istou cestou ako prehliadač.
function fire(type, ev){
  const pop = popNode();
  const ls = (pop && pop._ls[type === 'click' ? 'mousedown' : type]) || [];
  ls.forEach(fn => fn(ev));
}

// --- 1) čipy sa vykreslia LEN pri viacerých hrúbkach ------------------------
NXC.open(sel);
const html = popHtml();
ok(html.indexOf('cbchips') > -1, 'dekorový riadok má čipy');
// Pozor na `cbchips` (kontajner) — regex musí skončiť na medzere alebo
// úvodzovke, inak počíta aj obal a test „prejde" so zlým číslom.
eq((html.match(/class="cbchip[ "]/g) || []).length, 3,
   'tri varianty (18 · 36 · duplák) = tri čipy');
ok(/class="cbchip on"[^>]*>18</.test(html),
   'aktívny je 18 — korpus predvolí najtenšiu konštrukčnú, NIE duplák');
ok(html.indexOf('>duplák<') > -1, 'duplák je pomenovaný slovom, nie číslom');
const hdfPart = html.slice(html.lastIndexOf('cbopt'));
ok(hdfPart.indexOf('cbchips') < 0, 'HDF riadok (jediná hrúbka) žiadne čipy nemá');

// --- 2) klik na čip: ponuka OSTÁVA, mení sa len to, čo sa vloží ------------
const chipTarget = {
  closest(s){
    if (s === '.cbchip') return { getAttribute(k){ return k === 'data-chip' ? '1' : '0'; } };
    return null;
  }
};
fire('click', { target: chipTarget, preventDefault(){}, stopPropagation(){} });
ok(NXC.isOpen(sel), 'klik na čip ponuku NEZATVORIL (je to zúženie výberu, nie výber)');
eq(sel.value, 'dtd18', 'a hodnotu selectu ešte NEZAPÍSAL — to urobí až Enter/klik na riadok');
// Voľba čipu musí PREŽIŤ prekreslenie — render beží po každom písmene
// v hľadaní a bez toho by sa prepnutá hrúbka ticho vracala na predvolenú.
const inp = popNode().querySelector('input');
inp.value = 'dub';
(inp._ls.input || []).forEach(fn => fn());
ok(/class="cbchip on"[^>]*>36</.test(popHtml()),
   'zvolený čip je 36 aj po prekreslení (písanie v hľadaní ho nezahodí)');

// --- 3) potvrdenie vloží PRÁVE ZVOLENÝ variant ------------------------------
const rowTarget = {
  closest(s){
    if (s === '.cbchip') return null;
    if (s === '.cbopt') return { getAttribute(){ return '0'; } };
    return null;
  }
};
fire('click', { target: rowTarget, preventDefault(){}, stopPropagation(){} });
eq(sel.value, 'dtd36',
   'vložil sa material_id ZVOLENÉHO variantu (36), nie dekor ani prvý v poradí');
ok((sel._events || []).indexOf('change') > -1,
   'a potvrdenie ide cez `change` — tou istou cestou ako natívny výber (serverové guardy)');
ok(!NXC.isOpen(sel), 'a ponuka sa zavrela');

// --- 3b) dotaz „36" preselektuje čip aj v OTVORENEJ ponuke ----------------
// Čistú funkciu overuje test_picker2_chips.js; tu ide o to, že ju render
// naozaj používa — bez toho by človek napísal „36", riadok by sa našiel, ale
// Enter by vložil 18.
(function(){
  sel.value = 'dtd18';
  NXC.open(sel);
  const inp2 = popNode().querySelector('input');
  inp2.value = '36';
  (inp2._ls.input || []).forEach(fn => fn());
  ok(/class="cbchip on"[^>]*>36</.test(popHtml()),
     'dotaz „36" preselektoval čip 36 (nie iba našiel riadok)');
  fire('click', { target: rowTarget, preventDefault(){}, stopPropagation(){} });
  eq(sel.value, 'dtd36', 'a Enter/klik vloží práve tú hrúbku, ktorú človek hľadal');
})();

// --- 4) duplák sa dá vybrať IBA vedomým klikom -----------------------------
sel.value = 'dtd18';
NXC.open(sel);
ok(/class="cbchip on"[^>]*>18</.test(popHtml()),
   'po znovuotvorení je aktívna hodnota, ktorú select NESIE');
const dupChip = {
  closest(s){
    if (s === '.cbchip') return { getAttribute(k){ return k === 'data-chip' ? '2' : '0'; } };
    return null;
  }
};
fire('click', { target: dupChip, preventDefault(){}, stopPropagation(){} });
fire('click', { target: rowTarget, preventDefault(){}, stopPropagation(){} });
eq(sel.value, 'duplak2:dtd18', 'duplák sa vložil až po VEDOMOM kliku na jeho čip');

console.log(`OK test_picker2_chips_dom.js — ${n} kontrol`);
