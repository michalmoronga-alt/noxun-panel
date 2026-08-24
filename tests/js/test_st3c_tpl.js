// ŠT-3c-1 — sekcia ŠABLÓNY (`tpl`) v okne Štúdio (klient).
//
// Prečo sú to testy a nie klikanie:
//   1. Doskovým šablónam sa akcie „použiť"/„odfotiť" NEZOBRAZUJÚ (nie sú
//      disabled — vôbec tam nie sú). Keby sa tam raz objavili, klik by skončil
//      serverovým odmietnutím a používateľ by nevedel, prečo tlačidlo existuje.
//   2. PNG náhľad sa pýta RAZ na revíziu. Obrázok je radovo väčší než celý
//      zoznam — bez cache by každé prekreslenie sekcie ťahalo stovky kB.
//   3. Mazanie sa potvrdzuje D-15 modálom a text doskovej šablóny musí povedať,
//      že sa už nikdy nevráti (knižnica ju sama nedoplní).
//   4. Mená šablón píše používateľ — neescapovaný `<` by rozbil celú sekciu.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_st3b_rules.js) -----------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], parentNode: null, _html: '', _attrs: {}, value: '' };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; n.children.forEach(function(c){ c.parentNode = null; }); n.children = []; }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return n._text || ''; },
    set(v){ n._text = v; }
  });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  n.cloneNode = function(){ return stubEl(id + '-clone'); };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.querySelector = function(){ return n._img || null; };
  n.querySelectorAll = function(){ return []; };
  return n;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio'].forEach(function(id){ ELS[id] = stubEl(id); });

const SENT = [];
global.window = {
  sketchup: new Proxy({}, {
    get(_t, name){
      if (typeof name !== 'string') return undefined;
      return function(payload){ SENT.push([name, payload]); };
    },
    has(){ return true; }
  })
};
global.sketchup = global.window.sketchup;
const LISTEN = {};
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; },
  querySelectorAll: function(){ return []; }
};

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;           // poradie <script> v studio.html
const T = require(path.join(JS, 'templates.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const CAB = { name: 'Klasik dolná', kind: 'cabinet', preview_rev: 'r1',
              config: { type: 'lower', width: 600, height: 720, depth: 560 } };
const CAB2 = { name: 'Horná 720', kind: 'cabinet', preview_rev: null,
               config: { type: 'upper', width: 600, height: 720, depth: 320 } };
const BRD = { name: 'Pracovná doska', kind: 'board', preview_rev: null,
              config: { width: 2600, height: 600 } };

// --- 1) dlaždica: akcie podľa druhu -----------------------------------------

(function(){
  const cab = T.tplTileHtml(CAB, 'cabinet');
  ok(/#i-box/.test(cab), 'korpusová šablóna má „použiť na označenú skrinku"');
  ok(/#i-camera/.test(cab), 'a „odfotiť" — ikona CAMERA, nie oko');
  ok(!/#i-eye/.test(cab), 'oko v Štúdiu znamená „označ v modeli" — tu by mýlilo');
  ok(/#i-trash/.test(cab), 'a mazanie');
  ok(cab.indexOf('Klasik dolná') > -1 && cab.indexOf('dolná') > -1, 'názov a typ sú v dlaždici');
  ok(cab.indexOf('600×720×560') > -1, 'aj rozmery, ktoré šablóna postaví');

  const brd = T.tplTileHtml(BRD, 'board');
  ok(/#i-trash/.test(brd), 'doskovú šablónu sa dá zmazať (prvá správa doskových)');
  ok(!/#i-box/.test(brd), 'ale NIE použiť — apply je operácia nad skrinkou');
  ok(!/#i-camera/.test(brd), 'ani odfotiť — dlaždica dosky je schéma, nie skrinka');
  ok(!/disabled/.test(brd), 'a nie sú tam ako mŕtve tlačidlá — vôbec tam nie sú (D-78)');
  ok(brd.indexOf('doska') > -1, 'druh je v dlaždici vidieť');
})();

(function(){
  // Meno šablóny píše používateľ — do HTML sa nesmie dostať surové.
  const h = T.tplTileHtml({ name: '<img src=x onerror=1>', config: {} }, 'cabinet');
  ok(!/<img src=x/.test(h) && /&lt;img/.test(h), 'názov je escapovaný');
  ok(/onclick="tplApply\(&quot;/.test(h), 'aj argument v onclick (JSON + escape)');
})();

// --- 2) telo sekcie: dve skupiny a poctivé prázdno ---------------------------

(function(){
  T.tplApplyState({ version: '0.7.67', cabinet: [CAB, CAB2], board: [BRD] });
  const h = T.tplBodyHtml();
  ok(h.indexOf('Korpusové šablóny') > -1 && h.indexOf('Doskové šablóny') > -1,
     'dve skupiny podľa mockupu');
  ok(h.indexOf('Klasik dolná') > -1 && h.indexOf('Pracovná doska') > -1, 'oba druhy sa zobrazujú');
  ok(h.indexOf('Inspectore') > -1,
     'hint hovorí, KDE sa ukladá nová šablóna (v sekcii to nie je)');
  ok(h.indexOf('Premenovanie') > -1, 'a priznáva, že premenovanie ešte nie je');

  T.tplApplyState({ cabinet: [], board: [] });
  const empty = T.tplBodyHtml();
  ok(empty.indexOf('Žiadne korpusové šablóny') > -1, 'prázdna knižnica to POVIE');
  ok(empty.indexOf('Inspectore') > -1, 'a poradí, kde šablónu vytvoriť');
})();

// --- 3) PNG náhľad: pýta sa RAZ na revíziu ----------------------------------

(function(){
  SENT.length = 0;
  T.tplApplyState({ cabinet: [CAB, CAB2], board: [BRD] });
  T.tplRenderBody();
  const asks = SENT.filter(function(x){ return x[0] === 'tpl_preview'; });
  eq(asks.length, 1, 'PNG sa pýta LEN pre dlaždicu, ktorá náhľad má');
  const p = JSON.parse(asks[0][1]);
  eq([p.kind, p.name, p.rev], ['cabinet', 'Klasik dolná', 'r1'], 'a to identitou + revíziou');

  // Kým odpoveď NEPRIŠLA, druhé vykreslenie sa NESMIE pýtať znova — sekcia sa
  // prekresľuje pri každom pushi Štúdia (prepočet kusovníka, zápis rozpočtu),
  // takže bez tejto poistky by jeden pomalý disk znamenal desiatky dotazov.
  SENT.length = 0;
  T.tplRenderBody();
  eq(SENT.filter(function(x){ return x[0] === 'tpl_preview'; }).length, 0,
     'dotaz na PNG sa neopakuje, kým odpoveď nedorazila');

  // Odpoveď servera sa zacachuje — druhé vykreslenie sa už nepýta.
  T.TPL.setPreview({ kind: 'cabinet', name: 'Klasik dolná', rev: 'r1', png: 'data:image/png;base64,AA' });
  SENT.length = 0;
  T.tplRenderBody();
  eq(SENT.filter(function(x){ return x[0] === 'tpl_preview'; }).length, 0,
     'druhé vykreslenie sa už nepýta (obrázok je radovo väčší než celý zoznam)');

  // Nová revízia (prefotené) = nový dotaz.
  SENT.length = 0;
  T.tplApplyState({ cabinet: [Object.assign({}, CAB, { preview_rev: 'r2' })], board: [] });
  T.tplRenderBody();
  eq(SENT.filter(function(x){ return x[0] === 'tpl_preview'; }).length, 1,
     'zmena revízie si vypýta nový obrázok');
})();

// --- 4) akcie -> server ------------------------------------------------------

(function(){
  SENT.length = 0;
  T.tplApply('Klasik dolná');
  eq(SENT[0][0], 'tpl_apply', 'použitie ide vlastnou akciou sekcie');
  eq(JSON.parse(SENT[0][1]).template, 'Klasik dolná', 'a nesie meno šablóny');

  SENT.length = 0;
  T.tplCapture('Klasik dolná');
  eq(SENT[0][0], 'tpl_capture', 'fotenie tiež');
  eq(JSON.parse(SENT[0][1]).kind, 'cabinet', 'a vždy ako korpusové (server to overí znova)');
})();

// --- 5) mazanie: D-15 potvrdenie, nie tichý zápis ---------------------------

(function(){
  const opened = [];
  global.window.NXModal = {
    open: function(spec){ opened.push(spec); },
    close: function(){}
  };
  SENT.length = 0;
  T.tplDelete('cabinet', 'Klasik dolná');
  eq(SENT.length, 0, 'klik SÁM O SEBE nemaže nič');
  eq(opened.length, 1, 'otvorí sa potvrdenie (D-15 modal)');
  ok(opened[0].danger === true, 'a je DESTRUKTÍVNE (červené, nie zelené)');
  ok(opened[0].sub.indexOf('Klasik dolná') > -1, 'menuje šablónu');

  opened[0].onSubmit({});
  eq(SENT[0][0], 'tpl_delete', 'až potvrdenie pošle mazanie');
  const p = JSON.parse(SENT[0][1]);
  eq([p.kind, p.template], ['cabinet', 'Klasik dolná'], 'so ZDROJOM aj menom');

  // Doskové: text musí povedať, že sa už nikdy nevráti.
  ok(T.tplDeleteNote('board').indexOf('NIKDY') > -1,
     'dosková šablóna sa neobnoví — knižnica ju sama nedoplní');
  ok(T.tplDeleteNote('cabinet').indexOf('NEMENIA') > -1,
     'korpusová: skrinky, ktoré z nej vznikli, sa mazaním nemenia');
  ok(T.tplDeleteSub('board').indexOf('Doskovú') > -1, 'a podtitul menuje druh');
  delete global.window.NXModal;
})();

// --- 6) echo knižnice NESMIE prepísať cudziu sekciu (review #225 P1) --------

(function(){
  // `#secbody` a `#sectools` sú ZDIELANÉ uzly celého okna. Echo prichádza aj
  // vtedy, keď je používateľ inde (uloženie šablóny z Inspectora) — a vtedy
  // nesmie kresliť, inak by dlaždice nahradili rozpísaný formulár Rozpočtu.
  S.setStudioSection('budget');
  ELS.secbody.innerHTML = 'ROZPÍSANÝ ROZPOČET';
  ELS.sectools.innerHTML = 'LIŠTA ROZPOČTU';
  T.TPL.init({ cabinet: [CAB], board: [] });
  eq(ELS.secbody.innerHTML, 'ROZPÍSANÝ ROZPOČET',
     'echo knižnice NEPREPÍŠE telo cudzej sekcie');
  eq(ELS.sectools.innerHTML, 'LIŠTA ROZPOČTU', 'ani jej lištu');
  ok(T.tplBodyHtml().indexOf('Klasik dolná') > -1,
     'ale STAV sa uloží — pri vstupe do sekcie sa vykreslí čerstvý');

  S.setStudioSection('tpl');
  T.TPL.init({ cabinet: [CAB], board: [] });
  ok(ELS.secbody.innerHTML.indexOf('Klasik dolná') > -1,
     'v otvorenej sekcii Šablóny echo kreslí normálne');
  S.setStudioSection('bom');
})();

(function(){
  // Review #225 P2: id dlaždice sa NESMIE robiť „očistením" mena — „Dolná 600"
  // a „Dolné 600" by dali to isté id, náhľad by sa nakreslil na PRVÚ dlaždicu
  // a používateľ by vyberal šablónu podľa cudzej fotky.
  const A = { name: 'Dolná 600', kind: 'cabinet', preview_rev: 'rA', config: { type: 'lower' } };
  const B = { name: 'Dolné 600', kind: 'cabinet', preview_rev: 'rB', config: { type: 'lower' } };
  T.tplApplyState({ cabinet: [A, B], board: [] });
  const h = T.tplBodyHtml();
  const ids = (h.match(/id="tplpic-[^"]+"/g) || []);
  eq(ids.length, 2, 'obe dlaždice majú náhľadový box');
  ok(ids[0] !== ids[1], 'a kolízne mená majú RÔZNE DOM id');
  ok(T.tplDomIdFor('cabinet', 'Dolná 600') !== T.tplDomIdFor('cabinet', 'Dolné 600'),
     'mapa identita → uzol ich rozlíši tiež');
  ok(T.tplDomIdFor('cabinet', 'Neexistuje') === null,
     'a na neznámu šablónu sa náhľad nenakreslí nikam');
})();

// --- 7) lišta a kolízie globálov --------------------------------------------

(function(){
  T.tplApplyState({ cabinet: [CAB, CAB2], board: [BRD] });
  const h = T.tplToolsHtml({ stale: false, info: 'korpusových: 2 · doskových: 1' });
  ok(h.indexOf('korpusových: 2') > -1, 'lišta hovorí, koľko šablón knižnica má');
  ok(/id="refreshBtn"/.test(h), '„Obnoviť" má sekcia tiež');
  ok(!/Uložiť/.test(h), 'ale „Uložiť označený ako šablónu" NIE — ukladá sa v Inspectore');
  const warm = T.tplToolsHtml({ stale: true });
  ok(/nxstale/.test(warm) && !/nxstale/.test(h),
     'jantárový stav prichádza ARGUMENTOM zo studio.js (jediná autorita staleFlag)');
})();

(function(){
  const files = ['studio.js', 'budget.js', 'proj_materials.js', 'nx_modal.js',
                 'edge_menu.js', 'demos_diff.js', 'demos_add.js',
                 'hw_catalog.js', 'hw_sets.js', 'rules.js', 'templates.js'];
  const names = {};
  files.forEach(function(f){
    const src = fs.readFileSync(path.join(JS, f), 'utf8');
    const set = new Set();
    const re = /^ {0,2}(?:function\s+(\w+)|var\s+(\w+))/gm;
    let m;
    while ((m = re.exec(src)) !== null) set.add(m[1] || m[2]);
    names[f] = set;
  });
  ok(names['templates.js'].size > 12, 'zoznam mien sa naozaj načítal (inak by test nič nestrážil)');
  ok(!names['templates.js'].has('el') && !names['templates.js'].has('esc'),
     'globálne `el`/`esc` sú preč — presne tie mal aj studio.js');
  files.forEach(function(a){
    files.forEach(function(b){
      if (a >= b) return;
      const clash = [...names[a]].filter(function(x){ return names[b].has(x); });
      eq(clash, [], `js/${a} a js/${b} nesmú zdieľať globálne meno`);
    });
  });
})();

console.log(`OK ${n} kontrol (ŠT-3c-1 sekcia Šablóny)`);
