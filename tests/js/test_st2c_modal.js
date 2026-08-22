// ŠT-2c PR 2c-1 — rozšírená zdieľaná kostra modalov (`ui/js/nx_modal.js`)
// + dve opravy našepkávača materiálov (`ui/js/proj_materials.js`).
//
// Preco su to testy a nie klikanie:
//   1. `values()` je KONTRAKT medzi kostrou a serverom. Keby `rows` vratili
//      cokolvek ine nez POLE HASHOV (alebo keby sa ploche polia zmenili
//      z retazcov), server by dostal tvar, ktoremu nerozumie — a padlo by to
//      az pri ZAPISE dekoru, teda po tom, co uz pouzivatel formular vyplnil.
//   2. Repeater prekresluje kontajner pri KAZDOM pridani/odobrani riadku.
//      Keby hodnoty necital z DOM, kazde „+" by ticho zmazalo rozpisane
//      riadky nad sebou.
//   3. Pamat kluc = mode + CIEL. Keby bola kluc len „druh okna", editor
//      dekoru B by sa otvoril s rozpisanymi hodnotami dekoru A a ulozil by
//      ich do NESPRAVNEHO zaznamu.
//   4. Escape nasepkavaca: bez `stopPropagation` na inpute jedno stlacenie
//      zavrie dropdown AJ cely formular (dokumentovy listener D-15 modalu).
//      To sa da overit iba BUBLANIM — preto ma stub skutocne bublanie.
//   5. Scroll VNUTRI karty modalu: `scroll` z vnutorneho kontajnera NEBUBLA,
//      takze bez capture by dropdown ostal visiet nad cudzim riadkom.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

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
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null; },
    setAttribute(k, v){ this.attrs[k] = String(v); },
    removeAttribute(k){ delete this.attrs[k]; },
    hasAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k); },
    appendChild(c){ c.parent = this; this.children.push(c); return c; },
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
    querySelector(sel){ const r = qsa(this, sel); return r.length ? r[0] : null; },
    querySelectorAll(sel){ return qsa(this, sel); },
    closest(sel){
      let cur = this;
      while (cur){ if (matchesAny(cur, sel)) return cur; cur = cur.parent; }
      return null;
    }
  };
  return el;
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

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXModal = require(path.join(JS, 'nx_modal.js'));
const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);

// ===================== 1) NOVE TYPY POLI — cisty markup ======================

(function(){
  const g = NXModal.fieldHtml({ type: 'group', label: 'Identita', hint: 'kód · názov · výrobca' });
  ok(g.indexOf('<div class="mgroup"><h4>Identita</h4>') === 0,
     '`group` je NADPIS sekcie formulara, nie pole');
  ok(g.indexOf('kód · názov · výrobca') > -1, 'a smie niest doplnujuci text');
  ok(g.indexOf('data-nxm=') === -1, 'nadpis nema kluc — nema co odoslat');

  const c = NXModal.fieldHtml({ key: 'grain', label: 'Kresba', type: 'checkbox', value: true });
  ok(c.indexOf('type="checkbox"') > -1 && c.indexOf('data-nxm="grain"') > -1,
     '`checkbox` je normalne pole s klucom');
  ok(c.indexOf(' checked') > -1, 'a zapnuty stav sa vykresli');
  ok(NXModal.fieldHtml({ key: 'grain', label: 'K', type: 'checkbox', value: false })
       .indexOf('checked') === -1, 'vypnuty nie');

  const col = NXModal.fieldHtml({ key: 'rgb', label: 'Farba', type: 'color', value: '#A3B1C2' });
  ok(col.indexOf('class="mswatch" id="nxm_rgb_sw"') > -1, '`color` kresli VZORKU');
  ok(col.indexOf('style="background:#A3B1C2"') > -1, 'vo farbe hodnoty');
  ok(col.indexOf('value="#A3B1C2"') > -1 && col.indexOf('placeholder="#RRGGBB"') > -1,
     'a k nej TEXT — hodnotu musi byt vidno a dat skopirovat');
  ok(NXModal.fieldHtml({ key: 'rgb', label: 'F', type: 'color', value: 'nezmysel' })
       .indexOf('style=') === -1, 'nezmyselna hodnota vzorku nezafarbi');
})();

(function(){
  const f = { key: 'sheets', type: 'rows', label: 'Dosky', addLabel: 'Pridať dosku',
              hidden: ['material_id'], min: 1,
              cols: [{ key: 'kod', label: 'Kód', placeholder: 'H3303' },
                     { key: 'hr', label: 'Hrúbka', type: 'select', options: [['18', '18'], ['36', '36']] }],
              empty: 'Zatiaľ žiadna doska.' };
  const h = NXModal.rowsHtml(f, [{ material_id: 'M1', kod: 'H3303', hr: '36' }]);
  ok(h.indexOf('id="nxm_sheets" data-nxm-rows="sheets"') > -1, 'repeater ma svoj kontajner');
  ok(h.indexOf('data-nxm-row="sheets"') > -1, 'a riadok, ktory sa da najst');
  ok(h.indexOf('<input type="hidden" data-nxm-col="material_id" value="M1">') > -1,
     'existujuci riadok nesie SKRYTE id variantu — podla neho server pozna UPRAVU');
  ok(h.indexOf('data-nxm-col="kod" class="mrcell" value="H3303"') > -1, 'viditelne bunky nesu hodnoty');
  ok(h.indexOf('<option value="36" selected>36</option>') > -1, 'aj v rozbalovacich bunkach');
  ok(h.indexOf('data-nxm-act="rowadd"') > -1 && h.indexOf('Pridať dosku') > -1, 'tlacidlo „+"');
  ok(h.indexOf('data-nxm-act="rowdel"') > -1, 'a „−" v riadku');
  ok(h.indexOf('<button type="button" class="mrdel" data-nxm-act="rowdel" disabled') > -1,
     'pri dosiahnutom minime sa posledny riadok odobrat NEDA');
  const empty = NXModal.rowsHtml(f, []);
  ok(empty.indexOf('Zatiaľ žiadna doska.') > -1, 'prazdny repeater povie, ze je prazdny');
  ok(empty.indexOf('data-nxm-row=') === -1, 'a ziadny riadok nekresli');
  // XSS: hodnoty riadkov idu do innerHTML — VZDY escapovane.
  const x = NXModal.rowsHtml({ key: 'r', cols: [{ key: 'a', label: '<b>' }] }, [{ a: '"><img src=x>' }]);
  ok(x.indexOf('<img src=x>') === -1 && x.indexOf('&quot;&gt;&lt;img') > -1,
     'hodnota riadku je escapovana');
})();

// --- sirkove varianty karty --------------------------------------------------
(function(){
  eq(NXModal.cardCls({}), ' sm', 'default ostava uzka karta (spatna kompatibilita draftov)');
  eq(NXModal.cardCls({ small: false }), '', 'stary prepinac `small: false` = stredna karta');
  eq(NXModal.cardCls({ size: 'small' }), ' sm', '`small` je alias `sm`');
  eq(NXModal.cardCls({ size: 'md' }), '', '`md` = 560 px');
  eq(NXModal.cardCls({ size: 'wide' }), ' wide', '`wide` = 640 px pre editor s riadkami');
  ok(NXModal.modalHtml({ title: 'X', size: 'wide' }).indexOf('class="nxmcard wide"') > -1,
     'a karta triedu naozaj dostane');
})();

// ===================== 2) values(): TVAR kontraktu ===========================

const SPEC = {
  title: 'Upraviť dekor', size: 'wide', memoryKey: 'edit:H3303',
  fields: [
    { type: 'group', label: 'Identita' },
    { key: 'kod', label: 'Kód', value: 'H3303' },
    { key: 'struktura', label: 'Štruktúra', type: 'select', value: 'ST9',
      options: [['ST9', 'ST9'], ['ST15', 'ST15']] },
    { key: 'grain', label: 'Kresba', type: 'checkbox', value: true },
    { key: 'rgb', label: 'Farba', type: 'color', value: '#334455' },
    { type: 'group', label: 'Dosky' },
    { key: 'sheets', type: 'rows', label: 'Dosky', hidden: ['material_id', 'row_rev'],
      cols: [{ key: 'kod', label: 'Kód' }, { key: 'cena', label: 'Cena', cls: 'mshort' }],
      value: [{ material_id: 'M1', row_rev: 'r7', kod: 'H3303 ST9', cena: '18,40' }] }
  ]
};

let submitted = null;
(function(){
  NXModal.open(Object.assign({ onSubmit: function(v){ submitted = v; } }, SPEC));
  ok(NXModal.isOpen(), 'modal zije');
  const v = NXModal.values();
  ok(!Object.prototype.hasOwnProperty.call(v, 'undefined') && Object.keys(v).length === 5,
     'nadpisy sekcii v hodnotach NIE SU (5 poli: kod, struktura, grain, rgb, sheets)');
  eq(v.kod, 'H3303', 'ploche textove pole ostava RETAZEC (drafty rozpoctu na tom stoja)');
  eq(v.struktura, 'ST9', 'aj rozbalovacie');
  eq(v.grain, true, '`checkbox` je BOOLEAN');
  eq(v.rgb, '#334455', '`color` je retazec #RRGGBB');
  eq(v.sheets, [{ material_id: 'M1', row_rev: 'r7', kod: 'H3303 ST9', cena: '18,40' }],
     '`rows` je POLE HASHOV — vratane skrytych id/rev, ktore riadok nesie');

  // Fokus NESMIE sadnut do skryteho pola riadku.
  ok(DOC.activeElement && DOC.activeElement.getAttribute('data-nxm') === 'kod',
     'fokus ide do prveho VIDITELNEHO pola (skryte id variantu sa preskakuje)');
})();

// ===================== 3) repeater: pridanie a odobranie =====================

(function(){
  // Do existujuceho riadku sa dopise cena, potom sa prida NOVY riadok.
  const cena = DOC.querySelector('[data-nxm-col="cena"]');
  cena.value = '19,90';
  const add = DOC.querySelector('[data-nxm-act="rowadd"]');
  dispatch(add, 'click');
  let rows = NXModal.values().sheets;
  eq(rows.length, 2, 'klik na „+" prida riadok');
  eq(rows[0].cena, '19,90', 'a rozpisana hodnota nad nim PREZIJE prekreslenie kontajnera');
  eq(rows[0].material_id, 'M1', 'vratane skryteho id variantu');
  eq(rows[1], { kod: '', cena: '' },
     'novy riadok je PRAZDNY a id NEMA — server ho preto zalozi ako novy variant');
  ok(DOC.activeElement && DOC.activeElement.getAttribute('data-nxm-col') === 'kod',
     'fokus sadol do prveho pola prave pridaneho riadku');

  // Vyplnenie druheho riadku a odobranie PRVEHO.
  const cells = DOC.querySelectorAll('[data-nxm-row] [data-nxm-col="kod"]');
  cells[1].value = 'H1180 ST15';
  const dels = DOC.querySelectorAll('[data-nxm-act="rowdel"]');
  dispatch(dels[0], 'click');
  rows = NXModal.values().sheets;
  eq(rows.length, 1, 'klik na „−" riadok odoberie');
  eq(rows[0].kod, 'H1180 ST15', 'a ZOSTANE ten, ktory pouzivatel nechal — nie prvy v poradi');
  eq(Object.prototype.hasOwnProperty.call(rows[0], 'material_id'), false,
     'novy riadok id stale nema (odobranie neprepisalo identitu susedov)');
})();

// ===================== 4) zamok, fokus, Escape — REGRESIA ====================

(function(){
  const btn = DOC.querySelector('[data-nxm-act="submit"]');
  submitted = null;
  dispatch(btn, 'click');
  dispatch(btn, 'click');                    // druhy klik hned za prvym
  ok(NXModal.isBusy(), 'prvy submit modal ZAMKNE');
  ok(btn.hasAttribute('disabled'), 'a potvrdzovacie tlacidlo zosedne');
  ok(submitted !== null && submitted.sheets.length === 1, 'odoslal sa TVAR s riadkami');
  ok(NXModal.isOpen(), 'audit #10: odoslanie modal NEZATVARA');

  // Enter v bunke riadku sa sprava rovnako ako v poli — a zamok drzi aj jeho.
  let calls = 0;
  const spy = NXModal.spec();
  spy.onSubmit = function(){ calls++; };
  dispatch(DOC.querySelector('[data-nxm-col="kod"]'), 'keydown', { key: 'Enter' });
  eq(calls, 0, 'druhe odoslanie sa ZAHADZUJE, kym zamok drzi');
  NXModal.setBusy(false);
  ok(!btn.hasAttribute('disabled'), 'odomknutie tlacidlo ozivi');
  dispatch(DOC.querySelector('[data-nxm-col="kod"]'), 'keydown', { key: 'Enter' });
  eq(calls, 1, 'Enter v bunke opakovatelneho riadku potvrdzuje formular ako kazde ine pole');
  NXModal.setBusy(false);
})();

(function(){
  // Focus trap s NOVYMI poliami: v karte teraz ziju aj skryte polia riadkov
  // a ikony (`<svg><use href="#i-…">`). Ani jedno nesmie byt zastavkou Tabu —
  // inak by cyklus skoncil na kuse ikony a fokus by zmizol.
  NXModal.close();
  NXModal.open(Object.assign({}, SPEC, { memoryKey: 'fokus:test' }));
  ok(DOC.querySelectorAll('.nxmcard [type="hidden"]').length > 0,
     'vychodisko: karta SKUTOCNE obsahuje skryte polia riadkov');
  ok(DOC.querySelectorAll('.nxmcard [href]').length > 0, 'aj ikony s `href`');

  const close = DOC.querySelector('.nxmcard .mx');
  const submit = DOC.querySelector('[data-nxm-act="submit"]');
  DOC.activeElement = submit;
  let ev = dispatch(submit, 'keydown', { key: 'Tab', shiftKey: false });
  ok(ev._prevented, 'Tab z POSLEDNEHO ovladaca karty sa zachyti');
  eq(DOC.activeElement, close, 'a fokus skoci na prvy — krizik, nie na kus ikony za nim');

  ev = dispatch(close, 'keydown', { key: 'Tab', shiftKey: true });
  ok(ev._prevented, 'Shift+Tab z prveho sa zachyti tiez');
  eq(DOC.activeElement, submit,
     'a fokus skoci na POTVRDENIE — teda ani na `<use href>`, ani na skryte id variantu');
  NXModal.close();
})();

// ===================== 5) pamat hodnot v komponente ==========================

(function(){
  // Escape zavrie modal a hodnoty ostanu v pamati POD KLUCOM mode+ciel.
  NXModal.open(SPEC);
  const ev = dispatch(DOC.querySelector('[data-nxm="kod"]'), 'keydown', { key: 'Escape' });
  ok(!NXModal.isOpen(), 'Escape modal zavrel');
  ok(ev._immediate, 'a Escape SPOTREBOVAL (okno za nim ho vidiet nesmie)');
  const mem = NXModal.memory('edit:H3303');
  ok(mem && mem.kod === 'H3303', 'rozpisane hodnoty prezili zatvorenie');
  eq(mem.sheets.length, 1, 'vratane opakovatelnych riadkov');
  eq(NXModal.memory('edit:H1180'), null, 'INY ciel ma vlastnu (prazdnu) pamat');

  // Otvorenie modalu s TYM ISTYM klucom hodnoty PREDVYPLNI — volajuci o pamati
  // vediet nemusi, posiela cistu specifikaciu.
  NXModal.open(SPEC);
  eq(NXModal.values().kod, 'H3303', 'to iste okno sa otvorilo s hodnotami');
  DOC.querySelector('[data-nxm="kod"]').value = 'H3303 UPRAVENY';
  dispatch(DOC.querySelector('[data-nxm="kod"]'), 'keydown', { key: 'Escape' });
  eq(NXModal.memory('edit:H3303').kod, 'H3303 UPRAVENY', 'a zapisala sa novsia verzia');

  // ZMENA CIELA: editor ineho dekoru je CISTY formular a stara rozpisana
  // verzia zanika — inak by sa hodnoty dekoru A ulozili do dekoru B.
  NXModal.open({ title: 'Upraviť dekor', memoryKey: 'edit:H1180',
                 fields: [{ key: 'kod', label: 'Kód', value: 'H1180' }] });
  eq(NXModal.values().kod, 'H1180', 'iny ciel = ziadne cudzie predvyplnenie');
  eq(NXModal.memory('edit:H3303'), null, 'a pamat predchadzajuceho ciela ZANIKLA');
  NXModal.close();
})();

(function(){
  // Rezimy su NEZAVISLE sloty — „Pridať položku" a „Pridať spotrebič"
  // sa nemiesaju (regresia draftov rozpoctu).
  NXModal.open({ title: 'A', memoryKey: 'custom', fields: [{ key: 'popis', label: 'Popis' }] });
  DOC.querySelector('[data-nxm="popis"]').value = 'Likvidácia';
  NXModal.close();
  NXModal.open({ title: 'B', memoryKey: 'appliance', fields: [{ key: 'nazov', label: 'Názov' }] });
  DOC.querySelector('[data-nxm="nazov"]').value = 'Bosch';
  NXModal.close();
  eq(NXModal.memory('custom').popis, 'Likvidácia', 'vlastna polozka si pamata svoje');
  eq(NXModal.memory('appliance').nazov, 'Bosch', 'spotrebic tiez — su to ine rezimy');

  // Uspesny zapis pamat zahadzuje. Dve cesty, obe musia fungovat.
  NXModal.open({ title: 'A', memoryKey: 'custom', fields: [{ key: 'popis', label: 'Popis' }] });
  NXModal.setBusy(true);
  NXModal.setBusy(false, { clear: true });
  NXModal.close();
  eq(NXModal.memory('custom'), null, '`setBusy(false, {clear:true})` = server potvrdil, pamat prec');

  NXModal.open({ title: 'B', memoryKey: 'appliance', fields: [{ key: 'nazov', label: 'Názov' }] });
  NXModal.clearMemory('appliance');
  NXModal.close();
  eq(NXModal.memory('appliance'), null,
     '`clearMemory` pred zatvorenim pamat NEobnovi (inak by ju close() zapisal spat)');

  // Prazdny formular sa nepamata — inak by v pamati zostal balast.
  NXModal.open({ title: 'A', memoryKey: 'custom', fields: [{ key: 'popis', label: 'Popis' }] });
  NXModal.close();
  eq(NXModal.memory('custom'), null, 'zatvorenie prazdneho formulara pamat nezaklada');
})();

// ===================== 6) nasepkavac materialov vs modal =====================
// `proj_materials.js` sa nacitava az teraz — potrebuje hotovy `window`/`document`.
// `NX` je kanal Studia; tu staci prazdny (bez `setStudio` sa nenapaja na push).
global.NX = {};
global.window.NX = global.NX;
const M = require(path.join(JS, 'proj_materials.js'));

(function(){
  const card = mkEl('div');
  card.attrs.class = 'nxmcard';
  const body = mkEl('div');
  body.attrs.class = 'mbody';
  card.appendChild(body);
  const inp = mkEl('input');
  inp.attrs.id = 'nd_kod';
  body.appendChild(inp);
  DOC.body.appendChild(card);

  M.mdSgBind('nd_kod', function(){ return ['H3303 ST9', 'H1180 ST15']; }, null);
  dispatch(inp, 'focus');
  const box = DOC.getElementById('mdSgBox');
  ok(box && box.style.display === '', 'nasepkavac sa otvoril (dva navrhy)');

  // Modal zije POD nim. Escape musi zavriet LEN dropdown.
  NXModal.open({ title: 'Upraviť dekor', memoryKey: 'edit:X',
                 fields: [{ key: 'kod', label: 'Kód' }] });
  const ev = dispatch(inp, 'keydown', { key: 'Escape' });
  eq(box.style.display, 'none', 'audit ŠT-2c #10: Escape zavrel nasepkavac');
  ok(ev._stopped, 'a bublanie ZASTAVIL na inpute');
  ok(NXModal.isOpen(),
     'takze formular pod nim OSTAL otvoreny — jedno stlacenie nesmie zmazat rozpisany dekor');

  // Druhy Escape (dropdown uz zavrety) uz patri modalu — inak by sa okno
  // nedalo zavriet vobec.
  const ev2 = dispatch(inp, 'keydown', { key: 'Escape' });
  ok(!NXModal.isOpen(), 'druhy Escape (bez nasepkavaca) uz zavrie formular');
  ok(ev2._immediate, 'a modal si ho spotreboval');
})();

(function(){
  // Scroll VNUTRI karty modalu: `scroll` z vnutorneho kontajnera NEBUBLA,
  // takze listener MUSI byt v capture faze na window. Bez toho by dropdown
  // ostal visiet na starom mieste — nad cudzim riadkom.
  const inp = DOC.getElementById('nd_kod');
  dispatch(inp, 'focus');
  const box = DOC.getElementById('mdSgBox');
  eq(box.style.display, '', 'nasepkavac je znovu otvoreny');
  const scroller = DOC.querySelector('.mbody');
  fireScroll(scroller);
  eq(box.style.display, 'none',
     'audit ŠT-2c #11/#13: scroll VNUTRI karty modalu nasepkavac zavrel');
})();

// ===================== 7) zdrojove guardy z-vrstiev ==========================
(function(){
  const fs = require('node:fs');
  const css = fs.readFileSync(path.join(JS, '..', 'css', 'panel.css'), 'utf8');
  const html = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');
  ok(css.indexOf('#mdSgBox { position: fixed; z-index: var(--nx-z-suggest, 80)') > -1,
     'audit ŠT-2c #11: `panel.css` nema vlastne cislo vrstvy — cita premennu');
  const scrim = html.match(/--nx-z-scrim:\s*(\d+);\s*--nx-z-suggest:\s*(\d+);/);
  ok(scrim, 'obe vrstvy su definovane na JEDNOM mieste — pri `.nxscrim`');
  ok(Number(scrim[2]) > Number(scrim[1]),
     'a nasepkavac je NAD scrimom (inak by bol v modali viditelny, ale neklikatelny)');
})();

console.log('OK test_st2c_modal.js — ' + n + ' kontrol');
