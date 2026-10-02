// H7b — NÁZOV ZÁKAZKY V HLAVIČKE ŠTÚDIA + `expect` štyroch exportov
// (package `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H7.md` §6 R-B4–R-B8, R-B5b,
// §15–§17; mockup H7 PLATÍ 2.10.2026).
//   node tests/js/test_h7b_hlavicka.js
//
// Preco v `vm` kontexte nad VERNYM mini-DOM (minidom `faithful(true)`):
// v prehliadaci su `studio_sections.js`, `studio.js` a `budget.js` klasicke
// skripty v JEDNOM globalnom scope (budget.js cita `ST`, `nxJobExport`,
// `nxVepoExpect` ako globaly) a editor nazvu stoji na poradi udalosti
// prehliadaca: mousedown → blur pola (commit) → click (export). Stub bez
// fokusu, `replaceChild` a `on<typ>` by presne tieto veci neoveril.
//
//   T-B1  tri podoby hlavicky (+ cakajuci nazov) v 14 sekciach, `#stModel` nie je
//   T-B2  editor: Enter / blur / Enter+blur / Escape / nezmenene / maxlength / iny dokument
//   T-B3  plny push pocas pisania (ten isty dokument: uzol, hodnota, fokus ostanu)
//   T-B4  echo `setVepoBar` obnovi hlavicku a 4 exporty bez straty fokusu a menu VEPO
//   T-B5  4 exporty: bodka len pri „projekt", tooltip = presne serverove meno
//   T-B6  pole Projekt v liste ani CSS nie je, poradie listy R-B7
//   T-B11 jeden klik z otvoreneho editora na kazdy zo 4 exportov: zapis, potom export
//         s `expect`; P0-HF neozbrojeny aj ozbrojeny; `expect` po echu zlyhania
//   T-B12 cakajuci nazov: bodka + „neuložené k súboru", tooltip = `vepo.notice`
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const MD = require('./minidom.js');
const H = require('./h14_harness.js');

const { mkEl, DOC, dispatch } = MD;
const JS_DIR = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const UI_DIR = path.join(__dirname, '..', '..', 'noxun_engine', 'ui');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// ------------------------------------------------------------------ kontext
const SENT = [];
const sketchup = {};
['studio_set_vepo_opts', 'vepo_export', 'hw_csv_export', 'budget_xlsx', 'cp_xlsx',
 'refresh_bom', 'ready', 'nx_select', 'budget_mutate'].forEach(function(k){
  sketchup[k] = function(json){ SENT.push([k, json ? JSON.parse(json) : null]); };
});

const sandbox = {
  console: console, document: DOC, setTimeout: function(){ return 0; }, clearTimeout: function(){},
  localStorage: { getItem(){ return null; }, setItem(){} },
  module: undefined, sketchup: sketchup,
  NXEdgeMenu: { num(v){ return Number(v) || 0; }, menuHtml(){ return ''; },
                selectionHint(){ return ''; }, optionPayload(p){ return p; } }
};
sandbox.window = sandbox;
vm.createContext(sandbox);
// PORADIE presne ako studio.html.
['studio_sections.js', 'studio.js', 'budget.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(JS_DIR, f), 'utf8'), sandbox, { filename: f });
});
const W = sandbox;

function skeleton(){
  DOC.body.children = [];
  DOC.activeElement = null;
  ['studio', 'snav', 'sechead', 'sectools', 'secbody', 'status', 'nxModalRoot'].forEach(function(id){
    const e = mkEl('div');
    e.attrs.id = id;
    DOC.body.appendChild(e);
  });
}
function $(id){ return DOC.getElementById(id); }
function q(sel){ return DOC.querySelector(sel); }

const NAMES = { vepo_dir: 'srv_dir_Q7', hw_csv: 'kovanie_SRV_q7.csv',
                budget_xlsx: 'Rozpocet SRV Q7 - AKT 2.10. 2026.xlsx', offer_xlsx: 'Cenova ponuka SRV Q7 - 2.10.2026.xlsx' };
const V = {
  set: { project: 'Kuchyňa Novák', default_project: 'Kuchyna_Novak', merge_18_36: true, source: 'set',
         file: 'Kuchyna_Novak', export_names: NAMES, pending: false, notice: '' },
  set_unsaved: { project: 'Kuchyňa Novák', default_project: 'projekt', merge_18_36: true, source: 'set',
                 file: '', export_names: NAMES, pending: false, notice: '' },
  file: { project: 'Kuchyna_Novak', default_project: 'Kuchyna_Novak', merge_18_36: true, source: 'file',
          file: 'Kuchyna_Novak', export_names: NAMES, pending: false, notice: '' },
  dflt: { project: 'projekt', default_project: 'projekt', merge_18_36: true, source: 'default',
          file: '', export_names: NAMES, pending: false, notice: '' },
  pending: { project: 'Zákazka A', default_project: 'A', merge_18_36: false, source: 'set', file: 'A',
             export_names: NAMES, pending: true, notice: 'SERVEROVA VETA o cakajucom nazve' }
};
function clone(o){ return JSON.parse(JSON.stringify(o)); }
function budgetPayload(miss){
  return { totals: { total: 10, total_novat: 8.13, unknown_count_in_total: miss || 0 }, sections: [], stale: null };
}
function push(vepo, extra){
  W.NX.setStudio(H.payload(Object.assign({ vepo: clone(vepo), budget: budgetPayload(0) }, extra || {})));
}

// Kazdy test: cisty DOM, verny rezim, na konci reset (§16 B8).
function test(name, fn){
  skeleton();
  // Iny dokument = rozpisany editor z predosleho testu sa zahodi (stav okna).
  W.NX.setStudio(H.payload({ model_guid: 'RESET', budget: budgetPayload(0) }));
  SENT.length = 0;
  MD.faithful(true);
  try { fn(); } finally { MD.reset(); }
  ok(!MD.isFaithful(), name + ': verny rezim po teste vypnuty');
}
function go(id){ W.studioGoSection(id); }
function sent(name){ return SENT.filter(function(s){ return s[0] === name; }); }

// ================================================================== T-B1
test('T-B1', function(){
  push(V.set);
  const secs = H.ids();
  eq(secs.length, 14, 'T-B1: 14 sekcii z fixtury kontraktu');
  secs.forEach(function(id){
    go(id);
    const h = $('sechead').innerHTML;
    ok(h.indexOf('<span class="jobhd"><span class="joblbl">Zákazka</span>') > -1, 'T-B1 ' + id + ': hlavicka nesie nazov zakazky');
    ok(h.indexOf('<span class="jobtext">Kuchyňa Novák</span>') > -1, 'T-B1 ' + id + ': zadany nazov');
    ok(h.indexOf('<span class="jobver">· v0.0.0-golden</span>') > -1, 'T-B1 ' + id + ': verzia vpravo');
    ok(h.indexOf('secmodel') < 0 && h.indexOf('stModel') < 0, 'T-B1 ' + id + ': `#stModel` zanikol');
  });
  eq($('stModel'), null, 'T-B1: uzol #stModel v okne nie je');
  go('bom');
  const set = $('sechead').innerHTML;
  ok(set.indexOf('class="jobname src-set" id="jobName"') > -1, 'T-B1: zadany = src-set');
  ok(set.indexOf('jdot') < 0 && set.indexOf('jobsrc') < 0, 'T-B1: zadany bez bodky a bez dovetku');
  ok(set.indexOf('title="Názov zákazky pre VEPO, kovanie, rozpočet aj ponuku. Súbor: Kuchyna_Novak.skp. ' +
                 'Prázdne pole vráti meno súboru. · v0.0.0-golden"') > -1, 'T-B1: tooltip zadaneho (ulozeny)');
  ok(set.indexOf('aria-label="Upraviť názov zákazky — Kuchyňa Novák"') > -1, 'T-B1: aria-label s nazvom');
  ok(set.indexOf('<use href="#i-pencil"/>') > -1, 'T-B1: ceruzka zo spritu');

  push(V.set_unsaved);
  ok($('sechead').innerHTML.indexOf('Model ešte nie je uložený — názov sa pri prvom uložení prenesie na súbor. ' +
     'Prázdne pole vráti „projekt&quot;. · v0.0.0-golden') > -1, 'T-B1: tooltip zadaneho (neulozeny)');

  push(V.file);
  const f = $('sechead').innerHTML;
  ok(f.indexOf('class="jobname src-file"') > -1, 'T-B1: podla suboru = src-file');
  ok(f.indexOf('<span class="jobsrc">podľa súboru</span>') > -1, 'T-B1: sivy dovetok „podľa súboru"');
  ok(f.indexOf('jdot') < 0, 'T-B1 (O3): pri nazve podla suboru bodka NIE JE');
  ok(f.indexOf('title="Názov sa berie z mena súboru Kuchyna_Novak.skp. Klikni a zadaj vlastný — súbor sa nepremenuje.' +
               ' · v0.0.0-golden"') > -1, 'T-B1: tooltip podla suboru');

  push(V.dflt);
  const d = $('sechead').innerHTML;
  ok(d.indexOf('class="jobname src-default"') > -1, 'T-B1: predvoleny = src-default');
  ok(d.indexOf('<i class="jdot" aria-hidden="true"></i><span class="jobtext">projekt</span>') > -1,
     'T-B1 (O3): jantarova bodka pred „projekt"');
  ok(d.indexOf('<span class="jobsrc warn">zadaj názov</span>') > -1, 'T-B1: „zadaj názov"');
  ok(d.indexOf('title="Exporty sa teraz pomenujú „projekt&quot; — model ešte nie je uložený. Klikni a zadaj názov zákazky."') > -1,
     'T-B1: tooltip predvoleneho');
});

// ================================================================== T-B12
test('T-B12', function(){
  push(V.pending);
  const h = $('sechead').innerHTML;
  ok(h.indexOf('class="jobname src-set"') > -1, 'T-B12: cakajuci nazov ako zadany (tucne)');
  ok(h.indexOf('<i class="jdot" aria-hidden="true"></i>') > -1, 'T-B12 (Q2): jantarova bodka');
  ok(h.indexOf('<span class="jobsrc warn">neuložené k súboru</span>') > -1, 'T-B12 (Q2): „neuložené k súboru"');
  ok(h.indexOf('title="SERVEROVA VETA o cakajucom nazve"') > -1, 'T-B12: tooltip = serverova `notice`');
  go('bom');
  ok($('vepoBtn').innerHTML.indexOf('xdot') < 0, 'T-B12: exporty pri cakajucom nazve BEZ bodky');
  eq(W.nxJobExport('hw').dot, false, 'T-B12: ani CSV kovania');
  eq(W.nxJobExport('budget').dot || W.nxJobExport('offer').dot, false, 'T-B12: ani XLSX');
});

// ================================================================== T-B5
test('T-B5', function(){
  [['set', false], ['file', false], ['dflt', true], ['pending', false]].forEach(function(c){
    push(V[c[0]]);
    const vepo = W.nxJobExport('vepo');
    const hw = W.nxJobExport('hw');
    const bud = W.nxJobExport('budget');
    const off = W.nxJobExport('offer');
    [vepo, hw, bud, off].forEach(function(j){ eq(j.dot, c[1], 'T-B5 ' + c[0] + ': bodka len pri „projekt"'); });
    // Serverove meno, ktore sa zo slugu odvodit NEDA (velke pismena) — tooltip ho nesie PRESNE.
    ok(vepo.tip.indexOf('Exportuje prírezy (po odpočte ABS) do VEPO CSV — vyberieš priečinok. Vytvorí v ňom priečinok srv_dir_Q7\\') === 0,
       'T-B5 ' + c[0] + ': VEPO tooltip = dnesny text + meno priecinka zo servera');
    ok(hw.tip.indexOf('CSV nákupného zoznamu — počíta sa z čerstvého modelu. Súbor kovanie_SRV_q7.csv') === 0,
       'T-B5 ' + c[0] + ': CSV kovania tooltip');
    ok(bud.tip.indexOf('Interný rozpočet v presnom formáte tvojich hárkov. Súbor Rozpocet SRV Q7 - AKT 2.10. 2026.xlsx') === 0,
       'T-B5 ' + c[0] + ': XLSX rozpoctu tooltip');
    ok(off.tip.indexOf('Zákaznícky dokument: cenová tabuľka + špecifikácia (bez interných pojmov a kódov). Súbor ' +
                       'Cenova ponuka SRV Q7 - 2.10.2026.xlsx') === 0, 'T-B5 ' + c[0] + ': ponuka tooltip');
    [vepo, hw, bud, off].forEach(function(j){
      eq(j.tip.indexOf(' · názov zákazky zadáš hore v hlavičke') > -1, c[1], 'T-B5 ' + c[0] + ': dovetok len pri bodke');
    });
    // Markup v liste: bodka VNUTRI tlacidla, tooltip zo servera.
    go('bom');
    ok($('vepoBtn').getAttribute('title') === vepo.tip, 'T-B5 ' + c[0] + ': #vepoBtn nesie tooltip');
    eq($('vepoBtn').querySelector('.xdot') !== null, c[1], 'T-B5 ' + c[0] + ': bodka #vepoBtn');
    go('buy');
    ok($('hwCsvBtn').getAttribute('title') === hw.tip, 'T-B5 ' + c[0] + ': #hwCsvBtn nesie tooltip');
    eq($('hwCsvBtn').querySelector('.xdot') !== null, c[1], 'T-B5 ' + c[0] + ': bodka #hwCsvBtn');
    const bt = W.budToolsHtml(budgetPayload(0));
    ok(bt.indexOf('data-bud="xlsx" data-bkey="xlsx" title="' + W.bEsc(bud.tip) + '"') > -1,
       'T-B5 ' + c[0] + ': XLSX rozpoctu — tooltip, `data-bkey` bez zmeny');
    eq(bt.indexOf('XLSX rozpočet<i class="xdot" aria-hidden="true"></i></button>') > -1, c[1],
       'T-B5 ' + c[0] + ': bodka XLSX rozpoctu');
    const ot = W.budOfferToolsHtml();
    ok(ot.indexOf('data-bud="cp" data-bkey="cp" title="' + W.bEsc(off.tip) + '"') > -1,
       'T-B5 ' + c[0] + ': ponuka — tooltip, `data-bkey` bez zmeny');
    eq(ot.indexOf('Cenová ponuka (zákazník)<i class="xdot" aria-hidden="true"></i></button>') > -1, c[1],
       'T-B5 ' + c[0] + ': bodka ponuky');
  });
  // Starsi payload bez mien: tooltip = dnesny text (ziadne odvodzovanie zo slugu v JS).
  push({ project: 'X', default_project: 'X', merge_18_36: true });
  eq(W.nxJobExport('vepo').tip, 'Exportuje prírezy (po odpočte ABS) do VEPO CSV — vyberieš priečinok',
     'T-B5: bez `export_names` sa meno NEODVODZUJE');
  // budget.js ma pri chybajucom studio.js ten isty zakladny text (jeden zdroj).
  eq(W.BUD_TIP_XLSX, W.JOB_EXPORTS.budget.base, 'T-B5: zaklad tooltipu XLSX rozpoctu = studio.js');
  eq(W.BUD_TIP_CP, W.JOB_EXPORTS.offer.base, 'T-B5: zaklad tooltipu ponuky = studio.js');
});

// ================================================================== T-B6
test('T-B6', function(){
  push(V.set);
  go('bom');
  const t = $('sectools').innerHTML;
  ok(t.indexOf('prjInput') < 0 && t.indexOf('prjbox') < 0 && t.indexOf('prjlbl') < 0, 'T-B6 (O2): pole Projekt v liste nie je');
  let last = -1;
  ['class="bomviews"', 'class="searchbox"', 'class="spacer"', 'id="vepoBtn"', 'id="colBtn"', 'id="refreshBtn"'].forEach(function(m){
    const at = t.indexOf(m);
    ok(at > last, 'T-B6 (R-B7): poradie listy — ' + m);
    last = at;
  });
  const html = fs.readFileSync(path.join(UI_DIR, 'studio.html'), 'utf8');
  ok(html.indexOf('.prjbox') < 0 && html.indexOf('.secmodel') < 0, 'T-B6: CSS pola Projekt aj `.secmodel` zanikli');
  ok(html.indexOf('.sechead .jobhd') > -1 && html.indexOf('.sectools .xdot') > -1, 'T-B6: CSS hlavicky a bodky exportu');
});

// ================================================================== T-B2
function openEditor(){
  const btn = $('jobName');
  ok(btn !== null, 'editor: tlacidlo nazvu existuje');
  MD.userClick(btn);
  return $('jobEdit');
}

test('T-B2 Enter', function(){
  push(V.set);
  go('bom');
  const inp = openEditor();
  ok(inp !== null, 'T-B2: klik na nazov otvori pole na mieste');
  eq(inp.value, 'Kuchyňa Novák', 'T-B2: pole nesie zobrazeny nazov');
  eq(inp.getAttribute('maxlength'), '120', 'T-B2: maxlength 120');
  eq(inp.getAttribute('aria-label'), 'Názov zákazky', 'T-B2: aria-label pola');
  eq(inp.getAttribute('title'), 'Enter uloží, Escape zruší, prázdne pole vráti automatický názov', 'T-B2: tooltip pola');
  ok(DOC.activeElement === inp && inp._selected === true, 'T-B2: fokus a oznaceny text');
  ok($('sechead').innerHTML.indexOf('jobsrc') < 0, 'T-B2: dovetok zdroja pocas pisania nie je');
  inp.value = 'Test H7';
  MD.userKey(inp, 'Enter');
  eq(sent('studio_set_vepo_opts').length, 1, 'T-B2: Enter -> PRAVE JEDEN zapis');
  eq(sent('studio_set_vepo_opts')[0][1], { gen: 1, model_guid: 'G1', project: 'Test H7' },
     'T-B2: zapis nesie ZACHYTENY dokument a napisany text');
  eq($('jobEdit'), null, 'T-B2: editor sa hned zavrel');
  ok($('sechead').innerHTML.indexOf('<span class="jobtext">Test H7</span>') > -1,
     'T-B2 (R-B5): hlavicka optimisticky ukazuje odoslany text');
  // Blur po Enter (odpojene pole) nesmie poslat druhy zapis.
  inp.blur();
  eq(sent('studio_set_vepo_opts').length, 1, 'T-B2: Enter + blur = jeden zapis');
});

test('T-B2 blur', function(){
  push(V.set);
  go('bom');
  const inp = openEditor();
  inp.value = 'Kuchyňa Nová';
  MD.userClick($('status'));
  eq(sent('studio_set_vepo_opts').length, 1, 'T-B2: blur (klik mimo) odosle');
  eq(sent('studio_set_vepo_opts')[0][1].project, 'Kuchyňa Nová', 'T-B2: s napisanym textom');
  eq($('jobEdit'), null, 'T-B2: editor zavrety');
});

test('T-B2 Escape', function(){
  push(V.set);
  go('bom');
  let docKeys = 0;
  DOC.addEventListener('keydown', function(){ if (MD.isFaithful()) docKeys++; });
  const inp = openEditor();
  inp.value = 'Zahodene';
  const ev = MD.userKey(inp, 'Escape');
  ok(ev._prevented === true, 'T-B2: Escape — preventDefault');
  eq(docKeys, 0, 'T-B2: Escape NEJDE dalej do dokumentovej retaze (nx_esc, menu VEPO)');
  eq($('jobEdit'), null, 'T-B2: Escape editor zavrie');
  inp.blur();
  eq(sent('studio_set_vepo_opts').length, 0, 'T-B2: Escape (ani nasledny blur) nic neodosle');
  ok($('sechead').innerHTML.indexOf('<span class="jobtext">Kuchyňa Novák</span>') > -1, 'T-B2: hlavicka ostala na povodnom');
});

test('T-B2 nezmenene', function(){
  push(V.set);
  go('bom');
  let inp = openEditor();
  MD.userKey(inp, 'Enter');
  inp = openEditor();
  inp.value = '  Kuchyňa Novák  ';
  MD.userKey(inp, 'Enter');
  eq(sent('studio_set_vepo_opts').length, 0, 'T-B2: nezmeneny nazov (aj s medzerami) nic neodosle');
});

test('T-B2 iny dokument', function(){
  push(V.set);
  go('bom');
  const inp = openEditor();
  inp.value = 'Patri G1';
  push(V.set, { model_guid: 'G2' });
  eq($('jobEdit'), null, 'T-B2/T-B3: push INEHO dokumentu editor zahodi');
  inp.blur();
  eq(sent('studio_set_vepo_opts').length, 0, 'T-B2 (R-02): napisany nazov do cudzieho dokumentu NEODIDE');
});

// ================================================================== T-B3
test('T-B3', function(){
  push(V.set);
  go('bom');
  const inp = openEditor();
  inp.value = 'Rozpísané';
  push(V.set); // ten isty dokument (G1)
  ok($('jobEdit') === inp, 'T-B3: plny push toho isteho dokumentu uzol editora NEPREPISE');
  eq(inp.value, 'Rozpísané', 'T-B3: hodnota ostala');
  ok(DOC.activeElement === inp, 'T-B3: fokus ostal');
  go('ctrl'); // deep-link/sekcia pocas pisania: nadpis sa prekresli, editor nie
  ok($('jobEdit') === inp && $('sechead').querySelector('h2').textContent === 'Kontrola',
     'T-B3: prepnutie sekcie prekresli nadpis, editor ostane');
  W.NX.setVepoBar(clone(V.file));
  ok($('jobEdit') === inp && inp.value === 'Rozpísané', 'T-B3: echo pocas pisania pole NEZMENI');
  eq(sent('studio_set_vepo_opts').length, 0, 'T-B3: push ani echo nic neodoslali');
});

// ================================================================== T-B4
test('T-B4', function(){
  push(V.set);
  go('bom');
  MD.userClick(q('[data-vepo]'));
  ok($('vepoMenu').getAttribute('class').indexOf('open') > -1, 'T-B4: menu VEPO otvorene');
  const search = $('bomSearch');
  search.focus();
  const vbtn = $('vepoBtn');
  W.NX.setVepoBar(Object.assign(clone(V.dflt), { merge_18_36: false }));
  ok($('sechead').innerHTML.indexOf('src-default') > -1, 'T-B4: echo prekreslilo hlavicku');
  ok($('vepoBtn') === vbtn, 'T-B4: lista sa NEPREKRESLILA (ten isty uzol tlacidla)');
  ok(vbtn.querySelector('.xdot') !== null, 'T-B4: bodka VEPO pribudla na mieste');
  eq(vbtn.getAttribute('title'), W.nxJobExport('vepo').tip, 'T-B4: tooltip VEPO obnoveny');
  ok(DOC.activeElement === search, 'T-B4: fokus v hladani Kusovnika ostal');
  ok($('vepoMenu').getAttribute('class').indexOf('open') > -1, 'T-B4: menu VEPO ostalo otvorene');
  eq($('mergeChk').checked, false, 'T-B4: #mergeChk podla echa (ako dnes)');
  W.NX.setVepoBar(clone(V.set));
  ok(vbtn.querySelector('.xdot') === null, 'T-B4: bodka zmizla na mieste');
  go('buy');
  W.NX.setVepoBar(clone(V.dflt));
  ok($('hwCsvBtn').querySelector('.xdot') !== null, 'T-B4: echo obnovi aj CSV kovania');
  $('sectools').innerHTML = W.budToolsHtml(budgetPayload(0)) + W.budOfferToolsHtml();
  W.NX.setVepoBar(clone(V.dflt));
  ok(q('[data-bud="xlsx"]').querySelector('.xdot') !== null && q('[data-bud="cp"]').querySelector('.xdot') !== null,
     'T-B4: echo obnovi aj XLSX rozpoctu a ponuku');
  W.NX.setVepoBar(clone(V.set));
  ok(q('[data-bud="xlsx"]').querySelector('.xdot') === null && q('[data-bud="cp"]').querySelector('.xdot') === null,
     'T-B4: a bodky aj zhasne');
});

// ================================================================== T-B11
function exportCall(name){
  const all = sent(name);
  return all.length ? all[all.length - 1][1] : null;
}

[['bom', '#vepoBtn', 'vepo_export'], ['buy', '#hwCsvBtn', 'hw_csv_export'],
 ['budget', '[data-bud="xlsx"]', 'budget_xlsx'], ['offer', '[data-bud="cp"]', 'cp_xlsx']].forEach(function(c){
  test('T-B11 ' + c[2], function(){
    push(V.set);
    go(c[0]);
    if (c[0] === 'budget') $('sectools').innerHTML = W.budToolsHtml(budgetPayload(0));
    if (c[0] === 'offer') $('sectools').innerHTML = W.budOfferToolsHtml();
    const inp = openEditor();
    inp.value = 'Nové meno';
    // JEDEN klik na export z otvoreneho editora: mousedown → blur (commit) → click (export).
    MD.userClick(q(c[1]));
    const names = SENT.map(function(s){ return s[0]; });
    eq(names, ['studio_set_vepo_opts', c[2]], 'T-B11 ' + c[2] + ': najprv zapis nazvu, potom export');
    eq(exportCall(c[2]).expect, { project: 'Nové meno', merge: true },
       'T-B11 ' + c[2] + ': export nesie `expect` = napisany text a 18 + 36');
    // Echo zlyhania (zapis sa nepodaril — server vrati povodny nazov).
    W.NX.setVepoBar(clone(V.set));
    if (c[0] === 'budget') $('sectools').innerHTML = W.budToolsHtml(budgetPayload(0));
    if (c[0] === 'offer') $('sectools').innerHTML = W.budOfferToolsHtml();
    MD.userClick(q(c[1]));
    eq(exportCall(c[2]).expect, { project: 'Kuchyňa Novák', merge: true },
       'T-B11 ' + c[2] + ': po echu zlyhania `expect` = ulozeny nazov');
  });
});

test('T-B11 18+36', function(){
  push(V.set);
  go('bom');
  const chk = $('mergeChk');
  chk.checked = false;
  dispatch(chk, 'change');
  eq(sent('studio_set_vepo_opts')[0][1], { gen: 1, model_guid: 'G1', merge: false }, 'T-B11: zapis 18 + 36');
  // `expect` je v PREMENNEJ, nie v DOM: v Nakupe checkbox v liste nie je.
  go('buy');
  ok($('mergeChk') === null, 'T-B11: v Nakupe #mergeChk v DOM nie je');
  MD.userClick($('hwCsvBtn'));
  eq(exportCall('hw_csv_export').expect, { project: 'Kuchyňa Novák', merge: false },
     'T-B11: `expect.merge` z klientskej premennej (nie z DOM)');
});

test('T-B11 P0-HF', function(){
  push(V.set, { budget: budgetPayload(2) });
  go('budget');
  $('sectools').innerHTML = W.budToolsHtml(budgetPayload(2));
  MD.userClick(q('[data-bud="xlsx"]'));
  eq(sent('budget_xlsx').length, 0, 'T-B11 P0-HF: neozbrojeny 1. klik nic neposle (len ozbroji)');
  MD.userClick(q('[data-bud="xlsx"]'));
  eq(exportCall('budget_xlsx'), { gen: 1, confirm_unpriced: 2, expect: { project: 'Kuchyňa Novák', merge: true } },
     'T-B11 P0-HF: 2. klik posle potvrdenie AJ `expect`');
  // Server export pre nesulad odmietol a poslal echo — ozbrojenie sa NERUSI
  // (cisla sa nezmenili), dalsi klik posle `expect` znova.
  W.NX.setVepoBar(clone(V.set));
  eq(W.budArmed('xlsx'), 2, 'T-B11 P0-HF: echo ozbrojenie nezrusi');
  MD.userClick(q('[data-bud="xlsx"]'));
  eq(sent('budget_xlsx').length, 2, 'T-B11 P0-HF: ozbrojeny klik ide hned');
  eq(exportCall('budget_xlsx').expect, { project: 'Kuchyňa Novák', merge: true }, 'T-B11 P0-HF: znova s `expect`');
});

// Relay panela (VEPO, CSV, XLSX) preposiela payload okna CELY — `expect` sa
// cestou nestrati (server ho vyzaduje aj na relay ceste).
(function(){
  const src = fs.readFileSync(path.join(JS_DIR, 'bridge.js'), 'utf8');
  [['studioRelayExport', 'studio_do_export'], ['studioRelayHwCsv', 'studio_do_hw_csv'],
   ['studioRelayBudget', 'studio_do_budget_xlsx'], ['studioRelayCp', 'studio_do_cp_xlsx']].forEach(function(r){
    const body = (src.match(new RegExp(r[0] + ': function\\(p\\)\\{[\\s\\S]*?\\n    \\},')) || [''])[0];
    ok(body.indexOf('sketchup.' + r[1] + '(JSON.stringify(p))') > -1,
       'relay ' + r[0] + ' preposiela CELY payload (vratane `expect`)');
  });
})();

ok(!MD.isFaithful(), 'po sade je verny rezim minidom vypnuty');
console.log('test_h7b_hlavicka: ' + n + ' kontrol OK');
