// Mini-DOM pre JS sady, ktore potrebuju SKUTOCNE parsovanie HTML a BUBLANIE
// udalosti (repeater modalu, Escape nasepkavaca, delegovane kliky). Stubovany
// `querySelector` na to nestaci — vytiahnute zo `test_st2c_modal.js` v ŠT-2c
// 2c-2a, aby ho vedela pouzit aj sada editora dekoru.
//
// NIE JE to testovacia sada (nema prefix `test_`), takze ju CI beh
// `tests/js/test_*.js` nespusta — je to kniznica pre ne.
'use strict';

// ============================== mini-DOM =====================================
// Na rozdiel od starsich sad tento stub HTML naozaj PARSUJE — inak by sa
// repeater (pridanie/odobranie riadku nad realnymi uzlami) overit nedal.
const VOID = { input: 1, br: 1, img: 1, hr: 1, meta: 1, link: 1, use: 1 };

function unesc(s){
  return String(s).replace(/&quot;/g, '"').replace(/&gt;/g, '>')
                  .replace(/&lt;/g, '<').replace(/&amp;/g, '&');
}

function mkText(txt){
  return { tagName: '#text', text: txt, children: [], parent: null, attrs: {} };
}

function mkEl(tag){
  const el = {
    tagName: String(tag).toUpperCase(),
    attrs: {}, children: [], parent: null, style: {},
    value: '', checked: false, _listeners: {},
    get id(){ return this.attrs.id || ''; },
    set id(v){ this.attrs.id = String(v); },
    get className(){ return this.attrs.class || ''; },
    set className(v){ this.attrs.class = String(v); },
    // 1d/R-14: `classList` nad atributom `class` — inline zapis bunky rozpoctu
    // (`budNumericSend`) ho pouziva PRED odoslanim, takze bez neho sa cesta
    // „pole -> server" v mini-DOM vobec nedala prejst. Cita a pise TEN ISTY
    // atribut, aky vidi selektor `.cls` (ziadny druhy stav).
    classList: {
      _list(el){ return String(el.attrs.class || '').split(/\s+/).filter(Boolean); },
      add(c){ const l = this._list(this._el); if (l.indexOf(c) < 0) l.push(c); this._el.attrs.class = l.join(' '); },
      remove(c){ this._el.attrs.class = this._list(this._el).filter(function(x){ return x !== c; }).join(' '); },
      contains(c){ return this._list(this._el).indexOf(c) >= 0; },
      toggle(c, on){ const has = this.contains(c); const want = (on === undefined) ? !has : !!on; if (want) this.add(c); else this.remove(c); return want; }
    },
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null; },
    setAttribute(k, v){ this.attrs[k] = String(v); },
    removeAttribute(k){ delete this.attrs[k]; },
    hasAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k); },
    appendChild(c){ c.parent = this; this.children.push(c); return c; },
    // KOV-A2a: zoznam ciel stavia riadky OBRATENE (`insertBefore(row,
    // wrap.firstChild)`) a karta cela sa vklada pred/za surodencov, takze
    // mini-DOM musi vediet aj vkladat a odpajat, nie len pripajat na koniec.
    get firstChild(){ return this.children.length ? this.children[0] : null; },
    insertBefore(c, ref){
      const i = ref ? this.children.indexOf(ref) : -1;
      c.parent = this;
      if (i < 0) this.children.push(c); else this.children.splice(i, 0, c);
      return c;
    },
    removeChild(c){
      const i = this.children.indexOf(c);
      if (i >= 0){ this.children.splice(i, 1); c.parent = null; }
      return c;
    },
    remove(){ if (this.parent) this.parent.removeChild(this); },
    addEventListener(type, fn){ (this._listeners[type] || (this._listeners[type] = [])).push(fn); },
    focus(){ DOC.activeElement = this; },
    blur(){ if (DOC.activeElement === this) DOC.activeElement = null; },
    scrollIntoView(){},
    setSelectionRange(){},
    cloneNode(){ return mkEl(this.tagName); },
    getBoundingClientRect(){ return { left: 10, top: 20, bottom: 40, right: 110, width: 100, height: 20 }; },
    get innerHTML(){ return this._html || ''; },
    set innerHTML(v){
      this._html = String(v == null ? '' : v);
      this.children = [];
      parseInto(this, this._html);
    },
    get textContent(){ return textOf(this); },
    set textContent(v){
      this.children = [];
      this._html = '';
      if (v !== '') this.appendChild(mkText(String(v)));
    },
    // R-23.1 (review #273 kolo 2): dokumentove poradie uzlov — `nx_esc.js` podla
    // neho vybera, ktory z dvoch otvorenych modalov je NAVRCHU (pri zhodnom
    // z-index kresli prehliadac ako posledny ten, ktory je v HTML nizsie).
    // Vracia bity 4 = FOLLOWING / 2 = PRECEDING, spocitane z poradia pri prechode
    // stromu do hlbky (bity o vnoreni sa nepocitaju — porovnavaju sa surodenci).
    compareDocumentPosition(other){
      const order = [];
      (function walk(n){ order.push(n); (n.children || []).forEach(walk); })(DOC.body);
      const i = order.indexOf(this), j = order.indexOf(other);
      if (i < 0 || j < 0 || i === j) return 0;
      return j > i ? 4 : 2;
    },
    querySelector(sel){ const r = qsa(this, sel); return r.length ? r[0] : null; },
    querySelectorAll(sel){ return qsa(this, sel); },
    closest(sel){
      let cur = this;
      while (cur){ if (matchesAny(cur, sel)) return cur; cur = cur.parent; }
      return null;
    }
  };
  // `classList` je zdielany literal — kazdy uzol potrebuje VLASTNY (inak by
  // pisal do posledne vytvoreneho elementu).
  el.classList = Object.create(el.classList);
  el.classList._el = el;
  // KOV-A2a: `dataset` nad TYM ISTYM atributom, aky vidi selektor `[data-x]`
  // (riadok cela drzi typ, profil aj dormant polia vylucne v datasete). Bez
  // neho sa cesta „dataset -> collectFronts" v mini-DOM vobec neda prejst.
  // Proxy zamerne: `delete el.dataset.x` musi atribut naozaj odstranit —
  // rozdiel medzi „nema kluc" a „ma prazdny" je v KOV-A1 kontrakte zasadny.
  el.dataset = new Proxy({}, {
    get(_t, k){ return typeof k === 'string' ? el.attrs[dataAttr(k)] : undefined; },
    set(_t, k, v){ el.attrs[dataAttr(k)] = String(v); return true; },
    has(_t, k){ return Object.prototype.hasOwnProperty.call(el.attrs, dataAttr(k)); },
    deleteProperty(_t, k){ delete el.attrs[dataAttr(k)]; return true; },
    ownKeys(){
      return Object.keys(el.attrs).filter(function (a){ return a.indexOf('data-') === 0; })
        .map(function (a){ return a.slice(5).replace(/-([a-z])/g, function (_m, c){ return c.toUpperCase(); }); });
    },
    getOwnPropertyDescriptor(_t, k){
      return has(k) ? { configurable: true, enumerable: true, value: el.attrs[dataAttr(k)] } : undefined;
      function has(x){ return Object.prototype.hasOwnProperty.call(el.attrs, dataAttr(x)); }
    }
  });
  return el;
}

// `frontExtra` -> `data-front-extra` (rovnaky prevod ako v prehliadaci).
function dataAttr(key){
  return 'data-' + String(key).replace(/[A-Z]/g, function (m){ return '-' + m.toLowerCase(); });
}

function textOf(node){
  if (node.tagName === '#text') return node.text;
  return node.children.map(textOf).join('');
}

// --- parser -----------------------------------------------------------------
const TAG_RE = /<\/?([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[a-zA-Z-]+(?:="[^"]*")?)*)\s*(\/?)>|([^<]+)/g;
const ATTR_RE = /([a-zA-Z-]+)(?:="([^"]*)")?/g;

function parseInto(root, html){
  const stack = [root];
  TAG_RE.lastIndex = 0;
  let m;
  while ((m = TAG_RE.exec(html)) !== null){
    const top = stack[stack.length - 1];
    if (m[4] !== undefined){
      if (m[4].trim() !== '') top.appendChild(mkText(unesc(m[4])));
      continue;
    }
    const tag = m[1].toLowerCase();
    if (m[0].charAt(1) === '/'){
      if (stack.length > 1) stack.pop();
      continue;
    }
    const el = mkEl(tag);
    ATTR_RE.lastIndex = 0;
    let a;
    while ((a = ATTR_RE.exec(m[2] || '')) !== null){
      el.attrs[a[1]] = a[2] === undefined ? '' : unesc(a[2]);
    }
    if (el.attrs.value !== undefined) el.value = el.attrs.value;
    if (el.attrs.checked !== undefined) el.checked = true;
    top.appendChild(el);
    if (!VOID[tag] && m[3] !== '/') stack.push(el);
  }
  // <select> nesie hodnotu vybranej moznosti — presne ako v prehliadaci.
  qsa(root, 'select').forEach(function(sel){
    const opts = qsa(sel, 'option');
    let pick = null;
    opts.forEach(function(o){ if (o.hasAttribute('selected') && !pick) pick = o; });
    if (!pick && opts.length) pick = opts[0];
    sel.value = pick ? (pick.attrs.value || '') : '';
  });
}

// --- selektory (podmnozina: tag, #id, .cls, [attr], [attr="v"], potomkovia,
//     zoznam oddeleny ciarkou) — dokumentove poradie sa ZACHOVAVA -------------
const PIECE_RE = /^[a-zA-Z][a-zA-Z0-9-]*|^[#.][\w-]+|^\[[a-zA-Z-]+(?:="[^"]*")?\]/;

function pieceMatch(node, p){
  let m = p.match(/^\[([a-zA-Z-]+)(?:="([^"]*)")?\]$/);
  if (m) return m[2] === undefined ? node.hasAttribute(m[1]) : node.getAttribute(m[1]) === m[2];
  if (p.charAt(0) === '#') return node.attrs.id === p.slice(1);
  if (p.charAt(0) === '.') return String(node.attrs.class || '').split(/\s+/).indexOf(p.slice(1)) >= 0;
  return node.tagName === p.toUpperCase();
}

// Zlozeny selektor (`a[href]`, `input.mrcell`) = VSETKY kusy naraz.
function simpleMatch(node, sel){
  let s = String(sel).trim();
  if (s === '*') return true;
  while (s.length){
    const m = s.match(PIECE_RE);
    if (!m) return false;
    if (!pieceMatch(node, m[0])) return false;
    s = s.slice(m[0].length);
  }
  return true;
}

function matchChain(node, parts){
  if (!simpleMatch(node, parts[parts.length - 1])) return false;
  let i = parts.length - 2, cur = node.parent;
  while (i >= 0 && cur){
    if (simpleMatch(cur, parts[i])) i--;
    cur = cur.parent;
  }
  return i < 0;
}

function groupsOf(sel){
  return String(sel).split(',').map(function(g){
    return g.trim().split(/\s+/).filter(Boolean);
  }).filter(function(g){ return g.length; });
}

function matchesAny(node, sel){
  if (node.tagName === '#text') return false;
  return groupsOf(sel).some(function(g){ return matchChain(node, g); });
}

function qsa(root, sel){
  const groups = groupsOf(sel);
  const out = [];
  (function walk(node){
    node.children.forEach(function(c){
      if (c.tagName === '#text') return;
      if (groups.some(function(g){ return matchChain(c, g); })) out.push(c);
      walk(c);
    });
  })(root);
  return out;
}

// --- document / window ------------------------------------------------------
const DOC_LISTENERS = {};
const WIN_LISTENERS = [];
const DOC = {
  activeElement: null,
  body: mkEl('body'),
  addEventListener(type, fn){ (DOC_LISTENERS[type] || (DOC_LISTENERS[type] = [])).push(fn); },
  createElement(tag){ return mkEl(tag); },
  getElementById(id){
    let hit = null;
    (function walk(node){
      if (hit) return;
      node.children.forEach(function(c){
        if (hit || c.tagName === '#text') return;
        if (c.attrs.id === id){ hit = c; return; }
        walk(c);
      });
    })(DOC.body);
    return hit;
  },
  querySelector(sel){ const r = qsa(DOC.body, sel); return r.length ? r[0] : null; },
  querySelectorAll(sel){ return qsa(DOC.body, sel); }
};

global.document = DOC;
global.window = {
  NX_MAT_SECTION: true,
  addEventListener(type, fn, capture){ WIN_LISTENERS.push({ type: type, fn: fn, capture: !!capture }); },
  document: DOC
};
global.window.window = global.window;

// Bublanie: uzol → predkovia → document. `stopPropagation` bublanie zastavi,
// `stopImmediatePropagation` navyse zahodi aj zvysok poslucháčov toho uzla.
function dispatch(target, type, extra){
  const ev = Object.assign({
    type: type, target: target,
    preventDefault(){ ev._prevented = true; },
    stopPropagation(){ ev._stopped = true; },
    stopImmediatePropagation(){ ev._stopped = true; ev._immediate = true; }
  }, extra || {});
  let cur = target;
  while (cur){
    const list = (cur._listeners && cur._listeners[type]) ? cur._listeners[type].slice() : [];
    for (let i = 0; i < list.length; i++){
      list[i](ev);
      if (ev._immediate) return ev;
    }
    if (ev._stopped) return ev;
    cur = cur.parent;
  }
  const docList = (DOC_LISTENERS[type] || []).slice();
  for (let i = 0; i < docList.length; i++){
    docList[i](ev);
    if (ev._immediate) return ev;
  }
  return ev;
}

function fireScroll(target){
  WIN_LISTENERS.forEach(function(l){
    if (l.type === 'scroll' && l.capture) l.fn({ type: 'scroll', target: target });
  });
}

module.exports = { mkEl: mkEl, DOC: DOC, dispatch: dispatch, fireScroll: fireScroll,
                   qsa: qsa, textOf: textOf };
