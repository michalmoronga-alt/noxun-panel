// H4b (blok 9 HARDENING) — texty a vzhľad okna Štúdio: položky triedenia
// D-06 · D-07 · D-08 · D-09 (NIE D-čísla DOGFOODING.md).
//
// Prečo sú to testy a nie klikanie:
//   1. Ponuka „⋯" v lište Materiálov (D-06) je NOVÝ ovládací prvok nad
//      NÚDZOVOU akciou (vrátenie katalógu pred migráciou). Že ju Escape zavrie
//      a NIČ iné (jedno stlačenie = jedna vrstva), že výber položky otvorí
//      TEN ISTÝ potvrdzovací modal a nič nezapíše sám, a že bez zálohy sa
//      „⋯" vôbec nekreslí — to všetko sa rozbije ticho jedným riadkom.
//   2. „Zapísať vybrané" v Aktualizovať z Demosu (CS-11) prišlo o HTML
//      `disabled`. Stráž dvojitého zápisu teraz stojí na `aria-disabled` —
//      keby ju niekto vynechal, druhý klik počas zápisu pošle druhý `demos_apply`.
//   3. Ikony navigácie (D-09) — dve položky s rovnakou ikonou sa v zbalenej
//      navigácii nedajú rozlíšiť; stráži sa to pre všetky budúce sekcie.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// --- mini DOM (vzor tests/js/test_st2a_mat.js) -------------------------------
const ELS = {};
function stubEl(id){
  const el = { id, style: {}, _attrs: {}, _focused: false, _html: '' };
  Object.defineProperty(el, 'innerHTML', {
    get(){ return el._html; }, set(v){ el._html = String(v); }
  });
  el.setAttribute = function(k, v){ el._attrs[k] = String(v); };
  el.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(el._attrs, k) ? el._attrs[k] : null; };
  el.focus = function(){ FOCUS.push(id); el._focused = true; };
  return el;
}
const FOCUS = [];
['sectools', 'mdMoreBtn', 'mdRestoreItem', 'mdMoreWrap', 'mdRestoreModal', 'mddApplyBtn'].forEach(function(id){
  ELS[id] = stubEl(id);
});
ELS.mdRestoreModal.style.display = 'none';
const LISTEN = {};
global.window = { NX_MAT_SECTION: true };
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; },
  querySelectorAll: function(){ return []; }
};
const SENT = [];
global.window.sketchup = global.sketchup = new Proxy({}, {
  get: function(_t, name){ return function(arg){ SENT.push([String(name), arg]); }; }
});

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const UI = path.join(__dirname, '..', '..', 'noxun_engine', 'ui');
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const M = require(path.join(JS, 'proj_materials.js'));
const D = require(path.join(JS, 'demos_diff.js'));

// Cieľ kliku: `closest(sel)` vráti uzol s daným `data-mdmore` alebo obal.
function target(kind){
  return {
    closest: function(sel){
      if (sel === '[data-mdmore]') return kind && kind !== 'wrap' ? { getAttribute: function(){ return kind; } } : null;
      if (sel === '#mdMoreWrap') return kind ? {} : null;
      return null;
    }
  };
}
function keyEv(key){
  const ev = { key: key, _imm: false, _prev: false };
  ev.stopImmediatePropagation = function(){ ev._imm = true; };
  ev.preventDefault = function(){ ev._prev = true; };
  return ev;
}

// ============ 1) D-06: lišta Materiálov a ponuka „⋯" (čisté funkcie) =========

(function(){
  const closed = M.mdMoreHtml(false);
  ok(/id="mdMoreBtn"/.test(closed) && /aria-haspopup="menu"/.test(closed) && /aria-expanded="false"/.test(closed),
     'spúšťač „⋯" je tlačidlo ponuky (aria-haspopup, aria-expanded=false)');
  ok(/aria-label="Ďalšie akcie katalógu"/.test(closed), 'ikonové tlačidlo má aria-label');
  ok(/#i-more-horizontal/.test(closed), 'ikona more-horizontal zo spritu (nie glyf „⋯")');
  ok(!/role="menu"/.test(closed), 'zatvorená ponuka sa nekreslí');
  const open = M.mdMoreHtml(true);
  ok(/aria-expanded="true"/.test(open) && /role="menu"/.test(open) && /role="menuitem"/.test(open),
     'otvorená ponuka: role menu + menuitem');
  ok(/Vrátiť katalóg pred migráciou…/.test(open) && /#i-rotate-ccw/.test(open),
     'jediná položka „Vrátiť katalóg pred migráciou…" s ikonou rotate-ccw');
  ok(!/onclick=/.test(open), 'žiadny inline handler — klik ide cez delegáciu (data-mdmore)');

  const withBackup = M.matToolsHtml({ ro: false, q: '', mode: 'man', backup: true, stale: false });
  ok(withBackup.indexOf('Obnoviť zálohu') < 0, 'D-06: „Obnoviť zálohu" vedľa „Obnoviť" ZANIKLO');
  ok(withBackup.indexOf('id="refreshBtn"') > -1, 'bežné (zdieľané) „Obnoviť" ostáva');
  ok(withBackup.indexOf('id="mdMoreBtn"') > withBackup.indexOf('id="refreshBtn"'),
     '„⋯" je ZA „Obnoviť" (posledné vpravo)');
  ok(!/role="menu"/.test(withBackup), 'lišta bez otvorenej ponuky nekreslí položky');
  ok(M.matToolsHtml({ ro: false, backup: false }).indexOf('mdMoreBtn') < 0,
     'bez zálohy sa „⋯" nekreslí vôbec (D-78: žiadny prázdny spúšťač)');
  ok(M.matToolsHtml({ ro: true, backup: true }).indexOf('mdMoreBtn') < 0,
     'v núdzovom režime nesie vrátenie banner — „⋯" v lište nie je');
})();

// ============ 2) D-06: otvorenie, klávesnica, Escape, výber ==================

// Stav sekcie: zdravý katalóg SCHEMA 2 s predmigračnou zálohou (ako zo servera).
M.mdSetCatalog({ catalog_schema: 2, pre_schema2_backup: true, catalog: { sheets: [], edges: [] } });

(function(){
  ok(M.mdMoreState() === false, 'na začiatku je ponuka zatvorená');
  // Escape pri ZATVORENEJ ponuke nič nespotrebuje (patrí iným vrstvám).
  const e0 = keyEv('Escape');
  ok(M.mdMoreOnKey(e0) === false && !e0._imm, 'Escape bez otvorenej ponuky sa nespotrebuje');

  FOCUS.length = 0;
  ok(M.mdMoreOnClick(target('toggle')) === true, 'klik na „⋯" je spracovaný');
  ok(M.mdMoreState() === true, 'klik ponuku otvorí');
  ok(/id="mdMoreMenu"/.test(ELS.sectools.innerHTML), 'lišta sa prekreslí s otvorenou ponukou');
  eq(FOCUS, ['mdRestoreItem'], 'otvorenie presunie fokus na položku (klávesnica)');

  const e1 = keyEv('Escape');
  FOCUS.length = 0;
  ok(M.mdMoreOnKey(e1) === true, 'Escape pri otvorenej ponuke je spracovaný');
  ok(M.mdMoreState() === false, 'Escape ponuku zavrie');
  ok(e1._imm && e1._prev, 'a udalosť SPOTREBUJE — jedno stlačenie = jedna vrstva');
  eq(FOCUS, ['mdMoreBtn'], 'fokus sa vráti na „⋯" (nie do prázdna)');
  eq(ELS.mdRestoreModal.style.display, 'none', 'Escape nič neotvoril');

  // klik mimo zatvára
  M.mdMoreOnClick(target('toggle'));
  ok(M.mdMoreState() === true, 'znova otvorené');
  M.mdMoreOnClick(target(null));
  ok(M.mdMoreState() === false, 'klik mimo obalu ponuku zavrie');

  // Tab zatvára (ponuka nesmie visieť za fokusom), udalosť ide ďalej
  M.mdMoreOnClick(target('toggle'));
  const et = keyEv('Tab');
  ok(M.mdMoreOnKey(et) === false && !et._imm, 'Tab sa nespotrebuje');
  ok(M.mdMoreState() === false, 'Tab ponuku zavrie');

  // výber položky: ponuka zavretá, TEN ISTÝ modal otvorený, NIČ neodoslané
  M.mdMoreOnClick(target('toggle'));
  SENT.length = 0;
  M.mdMoreOnClick(target('restore'));
  ok(M.mdMoreState() === false, 'výber položky ponuku zavrie (PRED modalom)');
  eq(ELS.mdRestoreModal.style.display, 'flex', 'výber otvorí existujúce potvrdenie mdRestoreModal');
  eq(SENT.filter(function(s){ return s[0] === 'restore_pre_schema2'; }).length, 0,
     'samotný výber NIČ nezapíše — zapisuje až potvrdenie v modale');
  ELS.mdRestoreModal.style.display = 'none';

  // odchod zo sekcie zhasne ponuku
  M.mdMoreOnClick(target('toggle'));
  M.matOnLeaveSection();
  ok(M.mdMoreState() === false, 'odchod zo sekcie ponuku zhasne');
})();

// ============ 3) CS-11: „Zapísať vybrané" bez HTML disabled ===================

(function(){
  const btn = ELS.mddApplyBtn;
  D.mddSetApply(btn, 'Najprv načítaj a vyber zmeny');
  eq(btn.getAttribute('aria-disabled'), 'true', 'nedostupné = aria-disabled="true"');
  eq(btn.getAttribute('title'), 'Najprv načítaj a vyber zmeny', 'a dôvod v title');
  ok(D.mddApplyBlocked(btn), 'stráž to vidí');
  SENT.length = 0;
  const t = { getAttribute: function(k){ return k === 'data-action' ? 'mdd-apply' : btn.getAttribute(k); } };
  D.mddOnClick(t);
  eq(SENT.length, 0, 'klik na nedostupné „Zapísať vybrané" NIČ neodošle (stráž dvojitého zápisu)');
  D.mddSetApply(btn, null);
  eq(btn.getAttribute('aria-disabled'), 'false', 'dostupné = aria-disabled="false"');
  ok(!D.mddApplyBlocked(btn), 'stráž pustí');

  // Stráž DVOJITÉHO zápisu end-to-end: dostupné tlačidlo → prvý klik pošle
  // `demos_apply` a tlačidlo prejde do „Zapisujem…"; druhý klik počas zápisu
  // nepošle nič (dovtedy to strážil HTML `disabled`).
  global.MD_CATALOG = { sheets: [{ id: 'M1', row_rev: 'rev-1' }], edges: [] };
  global.MD_REV = 'cat-rev';
  global.MD_CLIENT_SCHEMA = 12;
  let m = D.mddApplyEvent(null, { type: 'proposal', session: 1, proposal: {
    record_id: 'M1', kind: 'sheet', status: 'match', url: 'https://x/',
    code: { old: null, 'new': '175718' }, supplier: { old: null, 'new': 'Demos' },
    price: { old: null, 'new': 18.99, unit_src: 'ks', unchanged: false }, warnings: [] } });
  m = D.mddApplyEvent(m, { type: 'complete', session: 1, ok: true, warnings: [] });
  D.mddSetStateForTest(m);
  const cb = { checked: true, getAttribute: function(){ return 'code'; } };
  const row = { getAttribute: function(){ return 'sheet|M1'; },
                querySelectorAll: function(){ return [cb]; } };
  const qsa = global.document.querySelectorAll;
  global.document.querySelectorAll = function(sel){ return sel === '#mddBody .mddrow' ? [row] : []; };
  D.mddSetApply(btn, null);
  SENT.length = 0;
  D.mddOnClick(t);
  eq(SENT.filter(function(s){ return s[0] === 'demos_apply'; }).length, 1, 'prvý klik pošle zápis');
  eq(btn.getAttribute('aria-disabled'), 'true', 'počas zápisu je tlačidlo nedostupné');
  eq(btn.getAttribute('title'), 'Zapisujem…', 'a povie prečo');
  D.mddOnClick(t);
  eq(SENT.filter(function(s){ return s[0] === 'demos_apply'; }).length, 1,
     'druhý klik počas zápisu NEPOŠLE druhý zápis');
  global.document.querySelectorAll = qsa;

  const html = fs.readFileSync(path.join(UI, 'studio.html'), 'utf8');
  const tag = (html.match(/<button[^>]*id="mddApplyBtn"[^>]*>/) || [''])[0];
  ok(tag.length > 0, 'tlačidlo v studio.html existuje');
  ok(!/\sdisabled[\s>]/.test(tag), 'žiadne HTML disabled (UI_DIZAJN §1, vzor D-78)');
  ok(/aria-disabled="true"/.test(tag) && /title="[^"]+"/.test(tag), 'štart: aria-disabled s dôvodom');
  const src = fs.readFileSync(path.join(JS, 'demos_diff.js'), 'utf8');
  ok(src.indexOf('.disabled =') < 0, 'demos_diff.js už nenastavuje HTML disabled');
})();

// ============ 4) D-09: ikony navigácie sú jedinečné ===========================

(function(){
  const ics = [];
  S.NAV.forEach(function(g){ g.items.forEach(function(it){ ics.push(it.ic); }); });
  const dup = ics.filter(function(ic, i){ return ics.indexOf(ic) !== i; });
  eq(dup, [], 'žiadne dve položky navigácie nemajú rovnakú ikonu (zbalená navigácia)');
  const bset = [].concat.apply([], S.NAV.map(function(g){ return g.items; })).find(function(it){ return it.id === 'bset'; });
  eq(bset.ic, 'sliders-horizontal', 'Nastavenia rozpočtu = posuvníky (Q2 variant A)');
  const rules = [].concat.apply([], S.NAV.map(function(g){ return g.items; })).find(function(it){ return it.id === 'rules'; });
  eq(rules.ic, 'settings', 'Pravidlá si nechávajú koleso (zhoda s Inspectorom)');
  const icons = fs.readFileSync(path.join(JS, 'icons.js'), 'utf8');
  ics.forEach(function(ic){
    ok(icons.indexOf("'" + ic + "':") > -1, 'ikona navigácie „' + ic + '" je v spritu icons.js');
  });
  const bud = fs.readFileSync(path.join(JS, 'budget.js'), 'utf8');
  ok(/#i-sliders-horizontal"\/><\/svg> Nastavenia<\/button>/.test(bud),
     'tlačidlo „Nastavenia" v lište Rozpočtu má tú istú ikonu ako navigácia');
})();

// ============ 5) D-08 / predrecenzia P2: stĺpce Kusovníka pri úzkom okne =====
// Pevné rozloženie (`fixed`) LEN pri stĺpcoch, ktorým studio.html dáva šírku.
// Pri najmenšom okne (NX_FIT_MIN 1060 px − navigácia a okraje ≈ 826 px tabuľky)
// musí stĺpcu Dielec ostať aspoň 160 px — inak sa názvy lámu po písmenách.

(function(){
  const cols = function(keys){ return S.COLS.filter(function(c){ return keys.indexOf(c.k) > -1; }); };
  const def = S.COLS.filter(function(c){ return c.on; });
  eq(S.partsTableClass(def), 'bomtab parts fixed', 'predvolené stĺpce = pevné rozloženie');
  eq(S.partsTableClass(cols(['name', 'cab', 'l', 'w', 'th', 'q', 'abs', 'grain'])), 'bomtab parts',
     'so Smerom dekoru = automatické rozloženie (Dielec sa nezje)');
  eq(S.partsTableClass(cols(['name', 'cab', 'l', 'w', 'th', 'q', 'abs', 'role'])), 'bomtab parts', 'tak isto s Rolou');
  eq(S.partsTableClass(cols(['name', 'l', 'w', 'th', 'q'])), 'bomtab parts fixed', 'menej stĺpcov = stále pevné');

  const html = fs.readFileSync(path.join(UI, 'studio.html'), 'utf8');
  const px = {}; let cabPct = null;
  html.replace(/\.bomtab\.parts\.fixed ([^{]+)\{ width: (\d+)(px|%); \}/g, function(_m, sel, n, unit){
    sel.split(',').forEach(function(s){
      const k = (s.match(/\.c-([a-z]+)/) || [])[1];
      if (!k) return;
      if (unit === '%') { if (k === 'cab') cabPct = Number(n); } else px[k] = Number(n);
    });
    return _m;
  });
  ok(cabPct !== null && px.l && px.w && px.th && px.q && px.abs, 'CSS šírky stĺpcov sa dajú prečítať');
  ok(/\.bomtab th\.acth, \.bomtab td\.acth \{ width: 56px;/.test(html), 'stĺpec akcií 56 px');
  const table = 826;
  const used = def.filter(function(c){ return c.k !== 'name' && c.k !== 'cab'; })
    .reduce(function(a, c){ return a + px[c.k]; }, 0) + 56;
  const dielec = table - used - table * cabPct / 100;
  ok(dielec >= 160, 'pri 1060 px okne má Dielec ' + Math.round(dielec) + ' px (≥ 160)');
  ok(!/\.bomtab\.parts \{ table-layout/.test(html), 'pevné rozloženie nie je bezpodmienečné');
  ok(/\.bomtab\.parts\.fixed td \{ white-space: normal; overflow-wrap: anywhere; \}/.test(html),
     'zalamovanie „anywhere" len pri pevnom rozložení (v automatickom by zúžilo Dielec)');
})();

console.log('test_h4b_texty_vzhlad: ' + n + ' asercii OK');
