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
  dtd18: { decor: 'Dub sonoma', type: 'DTDL', thickness: 18, key: 'G|Dub|DTDL' },
  dtd36: { decor: 'Dub sonoma', type: 'DTDL', thickness: 36, key: 'G|Dub|DTDL' },
  'duplak2:dtd18': { decor: 'Dub sonoma', type: 'DTDL', thickness: 36, duplak: true, key: 'G|Dub|DTDL' },
  hdf3: { decor: 'Dub sonoma', type: 'HDF', thickness: 3, key: 'G|Dub|HDF' }
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
// Duplák nesie HRÚBKU aj slovo (review #231 kolo 2): rodina môže mať ×2 aj
// ×3 (36 aj 54 mm) a dva čipy „duplák" by boli nerozlíšiteľné.
ok(html.indexOf('>36 duplák<') > -1, 'duplák je pomenovaný hrúbkou AJ slovom');
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

// --- 3c) VÝSLOVNÝ dotaz prebije PREDCHÁDZAJÚCI klik na čip -----------------
// Review #231 P2: kto klikne 18 a potom napíše „36", chce 36. Bez toho by
// ponuka ukazovala jedno (zapamätaný čip) a Enter vložil druhé.
(function(){
  sel.value = 'dtd18';
  NXC.open(sel);
  fire('click', { target: chipTarget, preventDefault(){}, stopPropagation(){} }); // klik na 36
  const inp3 = popNode().querySelector('input');
  inp3.value = '18';
  (inp3._ls.input || []).forEach(fn => fn());
  ok(/class="cbchip on"[^>]*>18</.test(popHtml()),
     'dotaz „18" prebil zapamätaný klik na 36');
  fire('click', { target: rowTarget, preventDefault(){}, stopPropagation(){} });
  eq(sel.value, 'dtd18', 'a vložilo sa to, čo ponuka ukazovala');
})();

// --- 3d) ČIPY SÚ DOSTUPNÉ Z KLÁVESNICE ------------------------------------
// Fokus zostáva v poli hľadania a Tab ponuku zatvára, takže bez šípok
// vľavo/vpravo by sa človek od klávesnice k hrúbkam nedostal vôbec
// (review #231 P2). Dôkazom je to, čo Enter nakoniec VLOŽÍ.
(function(){
  // Klávesnicu počúva POLE HĽADANIA v ponuke (nie dokument) — tam je fokus.
  function keyer(){
    const ls = (popNode().querySelector('input')._ls.keydown) || [];
    ok(ls.length > 0, 'pole hľadania počúva klávesnicu');
    return function(name){
      ls.forEach(fn => fn({ key: name, preventDefault(){}, stopPropagation(){} }));
    };
  }

  sel.value = 'dtd18';
  NXC.open(sel);
  let key = keyer();
  // Kurzor po otvorení stojí na riadku, ktorý select nesie — netreba naň
  // najprv šípkou dole.
  key('ArrowRight');                // 18 -> 36
  key('Enter');
  eq(sel.value, 'dtd36', 'šípka vpravo prepla hrúbku a Enter vložil práve ju');

  // Na kraji sa NEcykluje — slepým stláčaním sa nedá skončiť na dupláku.
  sel.value = 'dtd18';
  NXC.open(sel);
  key = keyer();
  key('ArrowLeft');
  key('ArrowLeft');
  ok(NXC.isOpen(sel), 'šípky ponuku nezatvárajú');
  key('Enter');
  eq(sel.value, 'dtd18', 'vľavo od najtenšej hrúbky nie je nič — hodnota sa nezmenila');
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

// --- 6) REVIEW #231 KOLO 2: dva dupláky a nedostupný čip -------------------
// Rodina môže mať duplák ×2 aj ×3 (36 aj 54 mm) — dva čipy so slovom
// „duplák" by boli nerozlíšiteľné. A nedostupný variant nesmie byť mŕtve
// tlačidlo: natívny `disabled` ho vyhodí z klávesnice a klik nemá čo povedať
// (vzor D-78 — aria-disabled + dôvod).
(function(){
  const META2 = {
    b18:  { decor: 'Buk', type: 'DTDL', thickness: 18, key: 'G|Buk|DTDL' },
    b36:  { decor: 'Buk', type: 'DTDL', thickness: 36, key: 'G|Buk|DTDL' },
    dup2: { decor: 'Buk', type: 'DTDL', thickness: 36, duplak: true, key: 'G|Buk|DTDL' },
    dup3: { decor: 'Buk', type: 'DTDL', thickness: 54, duplak: true, key: 'G|Buk|DTDL' }
  };
  NXC.setVariantResolver((kind, value) => (kind === 'abs' ? null : (META2[value] || null)));

  const sel2 = el('select');
  sel2.setAttribute('data-nx-combo', 'decor');
  sel2.setAttribute('data-nx-combo-ctx', 'body');
  [['b18', 'Buk 18 mm', false],
   ['b36', 'Buk 36 mm (nekompatibilné)', true],
   ['dup2', 'Buk duplák 36 mm', false],
   ['dup3', 'Buk duplák 54 mm', false]].forEach(function(row){
    const o = el('option');
    o.value = row[0];
    o.textContent = row[1];
    o.disabled = row[2];
    sel2.appendChild(o);
    sel2.options.push(o);
  });
  sel2.value = 'b18';
  sel2.selectedIndex = 0;
  body.appendChild(sel2);
  NXC.scan(document);

  NXC.open(sel2);
  const h = popHtml();
  ok(h.indexOf('>36 duplák<') > -1 && h.indexOf('>54 duplák<') > -1,
     'duplák ×2 aj ×3 sú rozlíšiteľné — čip nesie hrúbku');
  ok(h.indexOf('aria-disabled="true"') > -1, 'nedostupný čip je aria-disabled (D-78)');
  ok(!/class="cbchip[^"]*"[^>]* disabled>/.test(h),
     'a NIE natívne disabled — inak by vypadol z klávesnice');

  // Klik na nedostupný čip: hodnota sa nemení a ponuka povie DÔVOD
  // (text nesie server v labeli varianta).
  const offChip = { closest(s){
    if (s === '.cbchip') return { getAttribute(k){ return k === 'data-chip' ? '1' : '0'; } };
    return null;
  } };
  fire('click', { target: offChip, preventDefault(){}, stopPropagation(){} });
  eq(sel2.value, 'b18', 'nedostupný čip NEPREPÍNA');
  ok(NXC.isOpen(sel2), 'ponuka ostáva otvorená');
  const inp2 = popNode().querySelector('input');
  inp2.value = 'buk';
  (inp2._ls.input || []).forEach(fn => fn());
  // POZOR: dôvod je aj v `title` čipu, takže hľadať ho v celom HTML by
  // „prešlo" aj vtedy, keby klik nepovedal nič — kontroluje sa VÝHRADNE
  // hláškový uzol riadku.
  ok(/<span class="cbchipmsg"[^>]*>[^<]*nekompatibiln/.test(popHtml()),
     'dôvod sa ukáže v riadku a prežije prekreslenie po písmene');

  // Klávesnica nedostupný variant PRESKOČÍ (nezasekne sa na ňom).
  sel2.value = 'b18';
  NXC.open(sel2);
  const ls = (popNode().querySelector('input')._ls.keydown) || [];
  ls.forEach(fn => fn({ key: 'ArrowRight', preventDefault(){}, stopPropagation(){} }));
  ls.forEach(fn => fn({ key: 'Enter', preventDefault(){}, stopPropagation(){} }));
  eq(sel2.value, 'dup2', 'šípka preskočila nedostupnú 36 na najbližší použiteľný variant');
})();

console.log(`OK test_picker2_chips_dom.js — ${n} kontrol`);
