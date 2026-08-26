// PICKER-3 (E) — KONTEXT RADÍ AJ RIADKY, v otvorenej ponuke (DOM, nie grep).
//
// Čisté funkcie (rank, radenie, kurzor, „dotaz menuje hrúbku") overuje
// `test_picker3_kontext.js`. Tu ide o to, čo z nich naozaj vznikne na
// obrazovke a čo Enter NAOZAJ vloží:
//   · v poli pre chrbát (`data-nx-combo-ctx="back"`) idú dosky s 3 mm navrch
//     a kurzor po dopísaní dekoru sadne na ne — dovtedy vyhral riadok DTDL
//     toho istého dekoru a Enter vložil 18 mm chrbát (Štúdio, `md_back`),
//   · platí to AJ vtedy, keď DTDL stojí v sekcii „Použité v projekte", teda
//     nad katalógom — samotné radenie by tam nestačilo,
//   · VÝSLOVNÝ dotaz o hrúbke kontext odstaví (poradie prednosti z PICKER-2),
//   · v poli BEZ kontextovej hrúbky (korpus) sa poradie servera nemení.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// --- minimálny DOM (vzor test_picker2_chips_dom.js) -------------------------
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
global.window = { innerWidth: 1200, innerHeight: 800, document: global.document,
                  addEventListener(){}, removeEventListener(){} };
// „Naposledy použité" číta komponent z localStorage — test si ho vie nastaviť
// (RECENT drží zoznam ID, najnovšie prvé).
let RECENT = null;
// POZOR: komponent číta `localStorage` cez svoj `global` — a tým je v Node
// práve `window` (posledný riadok nx_combo.js), nie `globalThis`. Bez tohto
// riadku by boli „Naposledy použité" vždy prázdne a test by tichlo prešiel
// naprázdno.
global.localStorage = global.window.localStorage = {
  getItem(){ return RECENT ? JSON.stringify(RECENT) : null; },
  setItem(){}, removeItem(){}
};
global.Event = function(type){ this.type = type; };

const NXC = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'nx_combo.js'));

// --- fixtúra: ten istý dekor v DTDL 18/36 a v HDF 3 -------------------------
// Poradie je KATALÓGOVÉ (DTDL prvé) a menovky sú serverové `row_label`
// s rozlíšením typu — presne to, čo `md_back` v Štúdiu dostáva.
const META = {
  dtd18: { decor: 'Dub · DTDL', type: 'DTDL', thickness: 18, key: 'G|Dub|DTDL' },
  dtd36: { decor: 'Dub · DTDL', type: 'DTDL', thickness: 36, key: 'G|Dub|DTDL' },
  hdf3:  { decor: 'Dub · HDF', type: 'HDF', thickness: 3, key: 'G|Dub|HDF' },
  // Dekor, ktorého ČÍSLO obsahuje hrúbku („K018") — v katalógu bežné. Oba
  // riadky preto prejdú dotazom „18" a je vidieť, kto rozhoduje.
  k18: { decor: 'K018 · DTDL', type: 'DTDL', thickness: 18, key: 'G|K018|DTDL' },
  k3:  { decor: 'K018 · HDF', type: 'HDF', thickness: 3, key: 'G|K018|HDF' }
};
NXC.setVariantResolver((kind, value) => (kind === 'abs' ? null : (META[value] || null)));
let USED = [];
NXC.setUsedResolver(() => USED);

function mkSelect(ctx, values){
  const sel = el('select');
  sel.setAttribute('data-nx-combo', 'decor');
  if (ctx) sel.setAttribute('data-nx-combo-ctx', ctx);
  (values || ['dtd18', 'dtd36', 'hdf3']).forEach(function(v){
    const o = el('option');
    o.value = v;
    o.textContent = v;
    sel.appendChild(o);
    sel.options.push(o);
  });
  sel.value = sel.options[0].value;
  sel.selectedIndex = 0;
  body.appendChild(sel);
  NXC.scan(document);
  return sel;
}
function popNode(){ return body.children.filter(c => String(c.className).indexOf('cbpop') > -1).pop(); }
function popHtml(){
  const list = popNode() ? popNode().querySelector('.cblist') : null;
  return list ? list.innerHTML : '';
}
function type(text){
  const inp = popNode().querySelector('input');
  inp.value = text;
  (inp._ls.input || []).forEach(fn => fn());
}
// Enter ide cez pole hľadania — tam je fokus a tam visí `onKey`.
function press(name){
  const ls = (popNode().querySelector('input')._ls.keydown) || [];
  ls.forEach(fn => fn({ key: name, preventDefault(){}, stopPropagation(){} }));
}

const back = mkSelect('back');
const bodySel = mkSelect('body');
const kod = mkSelect('back', ['k18', 'k3']);

// --- 1) chrbát: po dopísaní dekoru vyhrá HDF 3, nie DTDL 18 ----------------
(function(){
  USED = [];
  back.value = 'dtd18';
  NXC.open(back);
  type('dub');
  const html = popHtml();
  ok(html.indexOf('Dub · HDF') > -1 && html.indexOf('Dub · DTDL') > -1,
     'obe rodiny sú v ponuke — kontext RADÍ, nefiltruje (18 mm chrbát ostáva voľbou)');
  ok(html.indexOf('Dub · HDF') < html.indexOf('Dub · DTDL'),
     'chrbtová 3 mm stojí NAD DTDL, hoci katalóg ju má nižšie');
  press('Enter');
  eq(back.value, 'hdf3', 'a Enter vložil HDF 3 — to, čo pole sľubuje');
})();

// --- 2) platí to AJ nad sekciou „Použité v projekte" -----------------------
// Sekcie stoja nad katalógom, takže samotné radenie by nestačilo: DTDL by
// bolo prvou položkou zoznamu a Enter by vložil 18 mm chrbát.
(function(){
  USED = ['dtd18'];
  back.value = 'dtd18';
  NXC.open(back);
  type('dub');
  const html = popHtml();
  ok(html.indexOf('Použité v projekte') > -1, 'DTDL naozaj sedí v hornej sekcii');
  ok(html.indexOf('Použité v projekte') < html.indexOf('Dub · HDF'),
     'a stojí NAD katalógom — kurzor teda nemôže ísť len po poradí');
  press('Enter');
  eq(back.value, 'hdf3', 'kurzor aj tak sadol na kontextový riadok');
  USED = [];
})();

// --- 2b) ani sekcia „Naposledy použité" kontext neprebije ----------------
// Tá sekcia si poradie prepisuje podľa ČERSTVOSTI (review #236 kolo 1):
// bez kontextu ako primárneho kritéria by hore stála naposledy použitá
// DTDL 18 a Enter by ju v poli pre chrbát vložil.
(function(){
  USED = [];
  RECENT = ['dtd18', 'hdf3'];   // DTDL použitá NESKÔR než HDF
  back.value = 'dtd18';
  NXC.open(back);
  type('dub');
  const html = popHtml();
  ok(html.indexOf('Naposledy použité') > -1, 'obe rodiny sedia v „Naposledy použité"');
  ok(html.indexOf('Dub · HDF') < html.indexOf('Dub · DTDL'),
     'chrbtová 3 mm je v sekcii hore, hoci DTDL bola použitá naposledy');
  press('Enter');
  eq(back.value, 'hdf3', 'a Enter vložil HDF 3');
  RECENT = null;
})();

// --- 3) VÝSLOVNÝ dotaz o hrúbke kontext odstaví ---------------------------
(function(){
  back.value = 'hdf3';
  NXC.open(back);
  type('18');
  press('Enter');
  eq(back.value, 'dtd18',
     'kto v poli pre chrbát napíše „18", chce 18 — poradie prednosti z PICKER-2 platí');

  back.value = 'hdf3';
  NXC.open(back);
  type('dtd36');
  press('Enter');
  eq(back.value, 'dtd36', 'a dotaz menujúci konkrétny variant tiež vyhrá');
})();

// --- 3b) a platí to aj vtedy, keď dotazu vyhovujú OBA riadky --------------
// Číslo dekoru bežne obsahuje hrúbku („K018"), takže dotaz „18" nájde aj
// chrbtový HDF riadok — a ten po zoradení stojí vyššie. Rozhodnúť teda musí
// KURZOR, nie poradie: kto napísal 18, dostane 18.
(function(){
  USED = [];
  kod.value = 'k3';
  NXC.open(kod);
  type('18');
  const html = popHtml();
  ok(html.indexOf('K018 · HDF') > -1 && html.indexOf('K018 · DTDL') > -1,
     'dotazu „18" vyhovujú OBA riadky (číslo dekoru ho obsahuje)');
  ok(html.indexOf('K018 · HDF') < html.indexOf('K018 · DTDL'),
     'a kontextový HDF riadok stojí vyššie');
  press('Enter');
  eq(kod.value, 'k18', 'Enter aj tak vložil 18 — výslovný dotaz o hrúbke prebíja kontext');
})();

// --- 4) pole BEZ kontextovej hrúbky: poradie servera sa NEMENÍ ------------
(function(){
  USED = [];
  bodySel.value = 'dtd18';
  NXC.open(bodySel);
  type('dub');
  const html = popHtml();
  ok(html.indexOf('Dub · DTDL') < html.indexOf('Dub · HDF'),
     'korpus radenie nemení — katalógové poradie ostáva presne také, aké prišlo');
  press('Enter');
  eq(bodySel.value, 'dtd18', 'a Enter vloží prvý zhodný riadok ako dovtedy');
})();

console.log(`OK test_picker3_kontext_dom.js — ${n} kontrol`);
