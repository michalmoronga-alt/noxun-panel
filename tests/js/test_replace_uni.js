// Testy V0.6 M-B2: UNI dlazdice + „Nahradit UNI…" (ciste funkcie proj_materials.js)
//   groupCatalogByDecor — agregacia uni/uni_role do skupiny
//   mdBuildSections     — sekcia "Pracovne (UNI)" navrchu v OBOCH rezimoch
//   mdUniTargets        — kandidati ciela (non-UNI skupiny s doskami)
//   mdUniSummaryLines   — riadky rozpisu dopadu
//   mdTileHtml/mdDetailHtml — badge + tlacidlo Nahradit UNI…
//   GENERACIA RELACIE (R-23.1 review #273) — odpoved servera po zatvoreni
//     modalu (Escape / odchod zo sekcie) uz modal NEVZKRIESI. Je to tichy
//     regres: rozpis dopadu, ktory pouzivatel prave zahodil, by sa mu o chvilu
//     vratil na obrazovku — a nasledne „Nahradit" by prestavalo cely projekt.
'use strict';
const assert = require('assert');
const path = require('path');

// --- DOM stub (vzor tests/js/test_st2a_mat.js) — uzly modalu „Nahradit UNI…".
// Neznamy `id` vracia null presne ako prehliadac (kod s tym pocita).
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], _html: '', _attrs: {} };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; n.children = []; }
  });
  Object.defineProperty(n, 'textContent', { get(){ return n._text || ''; }, set(v){ n._text = v; } });
  n.appendChild = function(c){ n.children.push(c); return c; };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  return n;
}
['mdUniModal', 'mdUniName', 'mdUniGroup', 'mdUniVariant', 'mdUniBody',
 'mdUniStep1', 'mdUniStep2', 'mdUniConfirmBtn', 'mdUniNextBtn'].forEach(function(id){
  ELS[id] = stubEl(id);
});
const SENT = [];   // otazky odoslane serveru
global.window = { sketchup: {
  replace_uni_preview: function(p){ SENT.push('preview:' + p); },
  replace_uni_apply: function(p){ SENT.push('apply:' + p); }
} };
global.sketchup = global.window.sketchup;   // v CEF je to ten isty holy global
global.document = {
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; },
  addEventListener: function(){}
};

// Poradie `<script>` v studio.html: `studio.js` je PRVY a zaklada `window.NX`,
// ktore `proj_materials.js` cita ako holy global (v CEF su to ta ista vec).
require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'studio.js'));
global.NX = global.window.NX;
const M = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let passed = 0;
function eq(a, b, msg){ assert.deepStrictEqual(a, b, msg); passed += 1; }
function ok(c, msg){ assert.ok(c, msg); passed += 1; }

const CAT = {
  sheets: [
    { material_id: 'UNI_K', decor: 'Korpus UNI', type: 'DTDL', thickness: 18,
      group_id: 'GRP-UK', uni: true, uni_role: 'body', color: [169, 169, 178] },
    { material_id: 'UNI_D', decor: 'Doska UNI', type: 'DTDL', thickness: 18,
      group_id: 'GRP-UD', uni: true, uni_role: 'board', color: [201, 167, 217] },
    { material_id: 'K111_18', decor: 'K111', decor_name: 'Dub', manufacturer: 'Egger',
      type: 'DTDL', thickness: 18, group_id: 'GRP-K111', structure: 'ST9' },
    { material_id: 'K111_186', decor: 'K111', decor_name: 'Dub', manufacturer: 'Egger',
      type: 'DTDL', thickness: 18.6, group_id: 'GRP-K111', structure: 'ST9' }
  ],
  edges: [
    { abs_id: 'ABS_ONLY', decor: 'H555', group_id: 'GRP-H555', thickness: 1.0, width: 23 }
  ]
};

// --- agregacia uni do skupiny ------------------------------------------------
(function(){
  const groups = M.groupCatalogByDecor(CAT, true);
  const uk = groups.find(g => g.gid === 'GRP-UK');
  const k111 = groups.find(g => g.gid === 'GRP-K111');
  ok(uk && uk.uni === true, 'UNI skupina ma flag uni');
  eq(uk.uni_role, 'body', 'uni_role sa prenesie');
  ok(k111 && k111.uni !== true, 'realna skupina uni flag nema');
})();

// --- sekcie: UNI navrchu v oboch rezimoch -------------------------------------
(function(){
  const groups = M.groupCatalogByDecor(CAT, true);
  const man = M.mdBuildSections(groups, {}, 'man', '');
  eq(man[0].title, 'Pracovné (UNI)', 'rezim vyrobca: UNI sekcia prva');
  eq(man[0].kind, 'uni');
  eq(man[0].groups.length, 2);
  ok(man.slice(1).every(s => s.groups.every(g => g.uni !== true)),
     'UNI skupiny nie su v dalsich sekciach');

  const az = M.mdBuildSections(groups, {}, 'az', '');
  eq(az[0].title, 'Pracovné (UNI)', 'rezim A-Z: UNI sekcia prva');
  ok(az[1] && az[1].kind === 'flat', 'za nou plochy zoznam');
  ok(az[1].groups.every(g => g.uni !== true), 'plochy zoznam bez UNI');

  const q = M.mdBuildSections(groups, {}, 'man', 'k111');
  eq(q.length, 1, 'hladanie = jedina sekcia Vysledky');
  eq(q[0].title, 'Výsledky');

  // bez UNI skupin ziadna prazdna sekcia
  const noUni = M.mdBuildSections(groups.filter(g => !g.uni), {}, 'az', '');
  ok(noUni.every(s => s.kind !== 'uni'), 'ziadna prazdna UNI sekcia');
})();

// --- kandidati ciela ----------------------------------------------------------
(function(){
  const t = M.mdUniTargets(CAT, true);
  eq(t.length, 1, 'kandidat je len non-UNI skupina s doskami (edge-only vypadne)');
  eq(t[0].gid, 'GRP-K111');
  eq(M.mdUniTargets(null, true).length, 0, 'prazdny katalog bezpecne');
})();

// --- riadky rozpisu -----------------------------------------------------------
(function(){
  const s = {
    target_label: 'K111 Dub', target_th: 18.6,
    project: ['Korpus', 'Chrbát'],
    adopting_n: 2, recompute_n: 1,
    th_changes: [{ change: '18→18,6', n: 2 }],
    overrides_n: 1,
    boards: [{ bid: 'BRD-001', from: 12, to: 18.6 }, { bid: 'BRD-002', from: 18.6, to: 18.6 }],
    abs: { changed: 3, lost: ['Bok ľavý L1'], lost_n: 2 }
  };
  const lines = M.mdUniSummaryLines(s);
  ok(lines[0].indexOf('Korpus, Chrbát') >= 0, 'predvolby v prvom riadku');
  ok(lines.some(l => l.indexOf('Skrinky: 3') >= 0), 'sucet skriniek');
  ok(lines.some(l => l.indexOf('prevezme hrúbku 18.6 mm') >= 0), 'adopcia hrubky');
  ok(lines.some(l => l.indexOf('BRD-001 (12→18.6 mm)') >= 0), 'doska so zmenou hrubky');
  ok(lines.some(l => l.indexOf('BRD-002') >= 0 && l.indexOf('BRD-002 (') < 0),
     'doska bez zmeny hrubky bez zatvorky');
  ok(lines.some(l => l.indexOf('ABS hrany sa prevedú') >= 0), 'ABS remap riadok');
  ok(lines.some(l => l.indexOf('ABS bez náhrady') >= 0 && l.indexOf('…') >= 0),
     'lost s naznacenim skratenia');
  eq(lines[lines.length - 1], 'Šablóny sa nemenia — sú globálna knižnica, nie projekt.');

  const empty = M.mdUniSummaryLines({});
  eq(empty.length, 1, 'prazdny payload = len sablonovy riadok');
})();

// --- badge + tlacidlo ---------------------------------------------------------
(function(){
  const groups = M.groupCatalogByDecor(CAT, true);
  const uk = groups.find(g => g.gid === 'GRP-UK');
  const k111 = groups.find(g => g.gid === 'GRP-K111');
  ok(M.mdTileHtml(uk, 0).indexOf('mdunib') >= 0, 'UNI dlazdica ma badge');
  ok(M.mdTileHtml(k111, 0).indexOf('mdunib') < 0, 'realna dlazdica badge nema');
  ok(M.mdDetailHtml(uk).indexOf('Nahradiť UNI…') >= 0, 'detail UNI ma tlacidlo');
  ok(M.mdDetailHtml(k111).indexOf('Nahradiť UNI…') < 0, 'realny detail tlacidlo nema');
})();

// --- GENERACIA RELACIE: odpoved po zatvoreni modal NEVZKRIESI ---------------
// R-23.1 review #273 (P2): `MD.replaceUniOffer` dorazi ASYNCHRONNE a modal si
// otvara sama. Escape (nx_esc.js vola `mdUniClose`) medzi otazkou a odpovedou
// by tak zahodeny rozpis dopadu vratil spat na obrazovku — a co je horsie,
// odpoved na STARU otazku by sa dala potvrdit v novej relacii (nahradenie UNI
// v celom projekte niecim inym, nez co je na obrazovke). Otazka preto nesie
// `gen` a server ho v odpovedi vracia (vzor revizie nahladov sablon).
(function(){
  M.mdSetCatalog({ catalog: CAT, catalog_schema: 2 });
  const uniKey = M.groupCatalogByDecor(CAT, true).find(g => g.gid === 'GRP-UK').key;
  const modal = ELS.mdUniModal;
  const PENDING = { uni_id: 'UNI_K', target_id: 'K111_18' };

  function openAndAsk(){
    ok(M.mdUniOpen(uniKey), 'modal „Nahradit UNI…" sa otvoril');
    ELS.mdUniVariant.value = 'K111_18';
    M.mdUniPreview();
  }
  // Odpoved servera na POSLEDNU odoslanu otazku — `gen` sa vracia z jej payloadu
  // presne tak, ako to robi `handle_replace_uni_preview` v materials_dialog.rb.
  function answer(extra){
    const last = SENT[SENT.length - 1];
    const req = JSON.parse(last.slice(last.indexOf(':') + 1));
    const p = { gen: req.gen, summary: {}, pending: PENDING };
    Object.keys(extra || {}).forEach(function(k){ p[k] = extra[k]; });
    return p;
  }

  // 1) Escape POCAS cakania na `replace_uni_preview`.
  SENT.length = 0;
  openAndAsk();
  eq(SENT.length, 1, 'otazka na server odisla');
  ok(answer().gen != null, 'otazka nesie generaciu relacie');
  const OLD = answer();                  // odpoved, ktora dorazi az po Escape
  M.mdUniClose();                        // presne to, co spravi Escape (nx_esc.js)
  eq(modal.style.display, 'none', 'Escape modal zavrel');
  M.MD.replaceUniOffer(OLD);
  eq(modal.style.display, 'none', 'zahodeny rozpis dopadu sa uz NEVRACIA');
  eq(ELS.mdUniStep2.style.display, 'none', 'a ani krok 2 sa nezobrazi');

  // 2) Bez Escapu ta ista cesta modal normalne ukaze (guard proti prehnanej
  //    obrane — inak by kontrola „ignoruj" utisila cely tok).
  openAndAsk();
  M.MD.replaceUniOffer(answer());
  eq(modal.style.display, '', 'bez Escapu rozpis dopadu modal ukaze');
  eq(ELS.mdUniStep2.style.display, '', 'a prepne ho na krok 2 (rozpis)');

  // 3) DVE otazky za sebou: odpoved na tu PRVU do druhej relacie nepatri.
  //    Toto je to, co lokalny priznak „cakam" sam neustrazi — bez echa `gen`
  //    by sa stary rozpis ukazal ako odpoved na novu otazku.
  M.mdUniClose();
  openAndAsk();
  const FIRST = answer();
  M.mdUniClose();                        // Escape
  openAndAsk();                          // nova relacia, nova otazka
  M.MD.replaceUniOffer(FIRST);
  eq(ELS.mdUniStep2.style.display, 'none', 'oneskorena odpoved na prvu otazku sa ignoruje');
  eq(modal.style.display, '', 'a modal ostava tam, kde pouzivatel je (krok 1)');
  M.MD.replaceUniOffer(answer());
  eq(ELS.mdUniStep2.style.display, '', 'odpoved na AKTUALNU otazku sa ukaze');

  // 3b) Otvorenie BEZ zatvorenia (skratka z KONTROLY vola `mdUniOpen` priamo
  //     nad uz otvorenym modalom) je tiez nova relacia — inak by odpoved na
  //     otazku o STAROM UNI ukazala rozpis pod novym nadpisom.
  M.mdUniClose();
  openAndAsk();
  const BEFORE_SHORTCUT = answer();
  ok(M.mdUniOpen(uniKey), 'skratka otvorila modal nanovo bez zatvorenia');
  M.MD.replaceUniOffer(BEFORE_SHORTCUT);
  eq(ELS.mdUniStep2.style.display, 'none', 'odpoved na otazku predoslej relacie sa ignoruje');

  // 4) APPLY tou istou cestou odpoveda (blokacia / stale rozpis) — a to sa
  //    ukazat MUSI, hoci `mdUniConfirm` modal predtym zavrel.
  M.mdUniClose();
  SENT.length = 0;
  openAndAsk();
  M.MD.replaceUniOffer(answer());
  M.mdUniConfirm();
  eq(SENT.length, 2, 'potvrdenie odoslalo apply');
  eq(modal.style.display, 'none', 'a modal zavrelo hned');
  M.MD.replaceUniOffer(answer({ stale: true }));
  eq(modal.style.display, '', 'stale odpoved z apply sa UKAZE — potvrdzuje sa nanovo');
  M.mdUniClose();
})();

console.log(JSON.stringify({ passed: passed, failed: 0 }));
