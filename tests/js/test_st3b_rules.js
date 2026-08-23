// ŠT-3b-1 — sekcia PRAVIDLÁ (`rules`) v okne Štúdio (klient).
//
// Preco su to testy a nie klikanie:
//   1. Subor sa PRESUNUL z okna do Studia a definoval globalne `el`/`esc` —
//      PRESNE tie, co `studio.js`. Kolizia by prepisala CUDZIU funkciu a padlo
//      by nieco uplne ine nez pravidla (napr. kusovnik).
//   2. „Formular prezije push" sa da rozbit jedinym riadkom — a rozbije sa
//      TICHO: obsah sa prekresli spravne, len pouzivatel prave stratil
//      rozeditovane pasma. Vsimne si to az ked mu to zmizne pod rukami.
//   3. Klientska kontrola pred odoslanim (pasmo „vsetko nad", rad dlzok) je
//      jedina vec, ktoru vie povedat BEZ servera — a je to varovanie pred
//      prestavbou VSETKYCH skriniek.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_st3a_hw.js) --------------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], parentNode: null, _html: '', _attrs: {}, value: '' };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; n.children.forEach(function(c){ c.parentNode = null; }); n.children = []; }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return n._text || ''; },
    set(v){ n._text = v; n.children.forEach(function(c){ c.parentNode = null; }); n.children = []; }
  });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  n.cloneNode = function(){ return stubEl(id + '-clone'); };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.focus = function(){ n._focused = true; };
  n.setSelectionRange = function(){};
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  return n;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio',
 'rulesBox', 'rdSrcLine', 'alsoGlobal'].forEach(function(id){ ELS[id] = stubEl(id); });
ELS.rulesBodyTpl = stubEl('rulesBodyTpl');
ELS.rulesBodyTpl.content = stubEl('rulesBodyTplContent');

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
const R = require(path.join(JS, 'rules.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

// --- 1) LIŠTA sekcie — čistá funkcia ----------------------------------------

(function(){
  const h = R.rulesToolsHtml({ also_global: false, stale: false });
  ok(/id="rdSaveBtn"/.test(h), 'primárna akcia „Uložiť a prestavať skrinky" je v lište');
  ok(/class="primary" id="rdSaveBtn"/.test(h),
     'a je PRIMÁRNA — je to jediná akcia, ktorá zapisuje do modelu');
  ok(/id="alsoGlobal"/.test(h), 'checkbox „aj ako globálnu predvoľbu" je pri nej');
  ok(/id="rdLoadBtn"/.test(h), '„Načítať globálne" je záložná cesta (ghost)');
  ok(/id="rdSeedBtn"/.test(h), 'a „Doplniť nové predvolené" tiež');
  ok(h.indexOf('id="rdSaveBtn"') < h.indexOf('<span class="spacer">'),
     'akcie sú VĽAVO od rozrážača (vzor lišty Štúdia)');
  ok(/id="refreshBtn"/.test(h), '„Obnoviť" má sekcia tiež');
  // Z OKNA sa nesmelo nič stratiť — okno zaniklo.
  ok(/rdSaveRules\(\)/.test(h) && /rdLoadGlobal\(\)/.test(h) && /rdMergeSeed\(\)/.test(h),
     'všetky tri akcie okna volajú prefixované funkcie (žiadna kolízia so studio.js)');
})();

(function(){
  const on = R.rulesToolsHtml({ also_global: true });
  const off = R.rulesToolsHtml({ also_global: false });
  ok(/id="alsoGlobal" checked/.test(on) || /id="alsoGlobal"\s+checked/.test(on),
     'stav checkboxu chodí ARGUMENTOM — lištu prekresľuje každý push');
  ok(!/checked/.test(off.match(/<input[^>]*id="alsoGlobal"[^>]*>/)[0]),
     'a vypnutý ostáva vypnutý');
})();

(function(){
  const cold = R.rulesToolsHtml({ stale: false });
  const warm = R.rulesToolsHtml({ stale: true });
  ok(cold.indexOf(S.refreshBtnHtml(false, 'Načítať pravidlá z aktuálneho modelu')) >= 0,
     'pokojný stav ide TÝM ISTÝM helperom ako ostatné sekcie');
  ok(/nxstale/.test(warm) && !/nxstale/.test(cold),
     'jantárový stav prichádza ARGUMENTOM zo studio.js (jediná autorita staleFlag)');
})();

// --- 2) klientska kontrola pred odoslaním -----------------------------------

(function(){
  eq(R.rdValidate([]), null, 'prázdny zoznam klient neblokuje (server povie svoje)');
  const okBands = [{ kind: 'bands', output: 'hinge', enabled: true,
                     bands: [{ max: 900, quantity: 2 }, { max: null, quantity: 3 }] }];
  eq(R.rdValidate(okBands), null, 'pásma s „všetko nad" prejdú');
  const noCatch = [{ kind: 'bands', output: 'hinge', enabled: true,
                     bands: [{ max: 900, quantity: 2 }] }];
  ok(/Závesy/.test(R.rdValidate(noCatch)),
     'pásma BEZ „všetko nad" sa odmietnu — a hláška menuje pravidlo rečou stolára');
  ok(/všetko nad/.test(R.rdValidate(noCatch)), 'a povie, čo chýba');
  const offRule = [{ kind: 'bands', output: 'hinge', enabled: false, bands: [] }];
  eq(R.rdValidate(offRule), null, 'VYPNUTÉ pravidlo sa nekontroluje — nič negeneruje');
  const noSeries = [{ kind: 'fit_series', output: 'slide', enabled: true, series: [] }];
  ok(/aspoň jednu dĺžku/.test(R.rdValidate(noSeries)), 'rad dĺžok nesmie byť prázdny');
  eq(R.rdValidate([{ kind: 'fit_series', output: 'slide', enabled: true, series: [400, 450] }]),
     null, 'vyplnený rad prejde');
})();

// --- 3) popisky: reč stolára, nie enum --------------------------------------

(function(){
  eq(R.rdLabel('hinge'), 'Závesy', 'typ kovania sa píše po slovensky');
  eq(R.rdLabel('wall_hanger'), 'Zavesenie na stenu', 'aj ten najnovší');
  eq(R.rdLabel('nieco_nove'), 'nieco_nove', 'neznámy typ sa NEZAMLČÍ — ukáže sa surový');
  eq(R.rdRoleDesc({ applies_to: { role: 'cabinet', cabinet_type: ['upper'] } }),
     'na hornú skrinku', 'cabinet pravidlo vie cieliť podľa typu korpusu');
  eq(R.rdRoleDesc({ applies_to: { role: 'cabinet', support: ['plinth'] } }),
     'na skrinku s podstavcom', 'alebo podľa podopretia (nohy)');
  eq(R.rdRoleDesc({ applies_to: { role: 'front_door' } }), 'na každé krídlo dvierok',
     'a rola dielca má vlastný popis');
})();

// --- 4) push zo servera NESMIE zmazať rozpísaný formulár --------------------

(function(){
  const rules = { version: '0.7.62', model_guid: 'G1', source: 'project', cabinets: 3,
                  rules: [{ kind: 'fixed', output: 'leg', enabled: true, quantity: 4,
                            applies_to: { role: 'cabinet' } }] };
  const payload = {
    version: '0.7.62', gen: 1, model_title: 'test', model_guid: 'G1',
    rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null,
    summary: {}, sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {},
    vepo: {}, control: [], counts: {}, budget: null, mat: null, hw: null,
    rules: rules, open_section: 'rules'
  };
  global.NX.setStudio(payload);
  const body = ELS.secbody;
  body.innerHTML = '';
  R.rulesRenderBody();
  eq(body.children.length, 1, 'telo sekcie sa pripojilo do #secbody');
  const node = body.children[0];
  eq(node.id, 'rulesBody', 'a je to JEDEN uzol sekcie (klon šablóny)');
  ok(/value="4"/.test(ELS.rulesBox.innerHTML), 'formulár sa naplnil pravidlami zo servera');
  ok(/skriniek v modeli: 3/.test(ELS.rdSrcLine.textContent),
     'a meta riadok nesie počet skriniek, ktoré uloženie prestavá');

  // Simulácia „rozpísaného formulára": uzol, ktorý tam nikto iný nedáva.
  const draft = stubEl('draft');
  node.appendChild(draft);
  ELS.rulesBox.innerHTML = 'ROZPÍSANÉ';

  // (a) TEN ISTÝ stav pravidiel = ŽiADEN re-render. Pushov chodí veľa (prepočet
  //     kusovníka, zápis rozpočtu, zmena katalógu) a rozpísané pásma ich musia
  //     prežiť — inak by používateľovi zmizli pod rukami.
  R.rdApplyState(rules);
  eq(ELS.rulesBox.innerHTML, 'ROZPÍSANÉ',
     'push s NEZMENENÝMI pravidlami formulár NEPREKRESLÍ');
  ok(node.children.indexOf(draft) >= 0, 'a rozpísaný obsah v uzle PREŽIL');

  // (b) Zmena pravidiel NA MODELI (vlastné uloženie, Späť, prepnutie dokumentu)
  //     formulár prekresliť MUSÍ — inak by ukazoval, čo už neplatí.
  const changed = JSON.parse(JSON.stringify(rules));
  changed.rules[0].quantity = 6;
  R.rdApplyState(changed);
  ok(ELS.rulesBox.innerHTML !== 'ROZPÍSANÉ',
     'zmena pravidiel na modeli formulár prekreslí');
  ok(/value="6"/.test(ELS.rulesBox.innerHTML), 'a to NOVOU hodnotou');

  // (c) Odchod do inej sekcie telo odpojí, návrat ho vráti AJ S HODNOTAMI.
  //
  // Review #220 P1: prežiť MUSÍ `#rulesBox`, nie len uzol vedľa neho. Ručné
  // hodnoty (počty, hranice pásiem, rad dĺžok) žijú LEN v DOM — do `RD_RULES`
  // sa preberajú až cez `rdSyncFromForm` pri „+ pásmo"/„✕". Keď render beží pri
  // každom pripojení tela, odchod do Kusovníka a návrat ich ticho zahodí.
  ELS.rulesBox.innerHTML = 'ROZPISANE-2';
  body.innerHTML = '<div>Kusovník</div>';
  eq(node.parentNode, null, 'iná sekcia si telo Pravidiel odpojila (vzor prehliadača)');
  R.rulesRenderBody();
  ok(body.children[0] === node, 'návrat do sekcie vráti TEN ISTÝ uzol');
  ok(node.children.indexOf(draft) >= 0, 'aj s rozpísaným obsahom');
  eq(ELS.rulesBox.innerHTML, 'ROZPISANE-2',
     'a HODNOTY vo formulári prežili — návrat do sekcie ho NEPREKRESLIL');

  // Zmena pravidiel, ktorá príde KÝM je telo ODPOJENÉ, sa nesmie stratiť:
  // prekreslenie dobehne pri návrate (inak by sekcia ukazovala, čo už neplatí).
  body.innerHTML = '<div>Kusovník</div>';
  const later = JSON.parse(JSON.stringify(rules));
  later.rules[0].quantity = 8;
  R.rdApplyState(later);
  R.rulesRenderBody();
  ok(/value="8"/.test(ELS.rulesBox.innerHTML),
     'zmena počas odpojenia sa dokreslí až pri návrate do sekcie');
})();

// --- 5) „Načítať globálne" nesmie push potichu prepísať --------------------

(function(){
  // Je to ZÁMERNE zmena formulára, ktorá ešte NEPLATÍ (platí až po Uložiť).
  // Keby si obnovila odtlačok, najbližší push s pravidlami projektu by ju
  // ticho vrátil späť a používateľ by nevedel, čo sa stalo.
  const src = fs.readFileSync(path.join(JS, 'rules.js'), 'utf8');
  const setRules = src.match(/setRules: function\(rules, _source\)\{[\s\S]*?\n    \}/)[0];
  ok(!/RD_SEED\s*=/.test(setRules),
     '„Načítať globálne" NEobnovuje odtlačok — inak by ho najbližší push potichu prepísal');
})();

// --- 6) kolízie globálov ----------------------------------------------------

(function(){
  // Ten istý súbor beží vedľa studio.js, budget.js, proj_materials.js,
  // hw_catalog.js a hw_sets.js. Rovnaké meno na top-level úrovni by ticho
  // prepísalo cudziu funkciu — a padlo by niečo úplne iné než pravidlá.
  const files = ['studio.js', 'budget.js', 'proj_materials.js', 'nx_modal.js',
                 'edge_menu.js', 'demos_diff.js', 'demos_add.js',
                 'hw_catalog.js', 'hw_sets.js', 'rules.js'];
  const names = {};
  files.forEach(function(f){
    const src = fs.readFileSync(path.join(JS, f), 'utf8');
    const set = new Set();
    const re = /^ {0,2}(?:function\s+(\w+)|var\s+(\w+))/gm;
    let m;
    while ((m = re.exec(src)) !== null) set.add(m[1] || m[2]);
    names[f] = set;
  });
  ok(names['rules.js'].size > 15, 'zoznam mien sa naozaj načítal (inak by test nič nestrážil)');
  ok(!names['rules.js'].has('el') && !names['rules.js'].has('esc'),
     'globálne `el`/`esc` sú preč — presne tie mal aj studio.js');
  ok(names['rules.js'].has('rdEl') && names['rules.js'].has('rdEsc'),
     'preto sa helpery volajú rdEl/rdEsc');
  files.forEach(function(a){
    files.forEach(function(b){
      if (a >= b) return;
      const clash = [...names[a]].filter(function(x){ return names[b].has(x); });
      eq(clash, [], `js/${a} a js/${b} nesmú zdieľať globálne meno`);
    });
  });
})();

// --- 7) zdrojáky: kontrakty overiteľné len čítaním --------------------------

(function(){
  const src = fs.readFileSync(path.join(JS, 'rules.js'), 'utf8');
  const studio = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');

  ok(!/^[^/\n]*\bsketchup\.ready\(/m.test(src),
     '`ready` sa z tohto súboru už NEPOSIELA — v Štúdiu ho posiela studio.js');
  ok(!fs.existsSync(path.join(JS, '..', 'rules.html')),
     'rules.html je zmazaný (dve UI nad jednými pravidlami by sa rozišli)');
  ok(studio.indexOf('js/studio.js') < studio.indexOf('js/rules.js'),
     'rules.js sa načítava AŽ ZA studio.js (obaľuje jeho NX.setStudio)');
  ok(studio.indexOf('js/hw_catalog.js') < studio.indexOf('js/rules.js'),
     'a za všetkými predošlými obalmi');

  // Uloženie posiela `model_guid` a SERVER ho reálne overuje (review #220 P2)
  // — druhá vrstva k baseline. Kým ho nečítal, bolo to mŕtve pole a toto
  // tvrdenie klamalo.
  const saveFn = src.match(/function rdSaveRules\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/model_guid: RD_META\.model_guid/.test(saveFn),
     'zápis nesie identitu dokumentu');
  const rb = fs.readFileSync(path.join(JS, '..', 'rules_dialog.rb'), 'utf8');
  const iSave = rb.indexOf('def handle_save');
  const iGuid = rb.indexOf('guid != model_guid(model)');
  ok(iSave >= 0 && iGuid > iSave,
     'a SERVER ho naozaj \u010d\u00edta v `handle_save` \u2014 inak by to bolo m\u0155tve pole');
  ok(/rdValidate\(rules\)/.test(saveFn),
     'a pred odoslaním beží klientska kontrola (prestavba VŠETKÝCH skriniek nie je lacná)');
})();

console.log(`OK ${n} kontrol (ŠT-3b-1 sekcia Pravidlá)`);
