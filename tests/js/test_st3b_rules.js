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
 'rulesBox', 'rdSrcLine', 'alsoGlobal',
 // ŠT-3b-2a: read-only bloky sekcie (ABS pravidlá + jantárové riadky).
 'rdAbsBox', 'rdAbsSrc', 'rdAbsHint', 'rdAbsOvr', 'rdHwOvr'
].forEach(function(id){ ELS[id] = stubEl(id); });
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

// ===================== ŠT-3b-2a: ABS + jantárové riadky =====================
//
// Prečo sú to testy a nie klikanie:
//   1. Klient tu NESMIE prekladať nič vlastné — všetky texty (názvy rolí,
//      popisy, zhrnutia olepu, hláška o skrátenom zozname) skladá server. Vlastná
//      tabuľka v JS by sa časom rozišla so serverovou a používateľ by videl dva
//      rôzne názvy tej istej roly.
//   2. Ručný zásah v Inspectore PRAVIDLÁ NEMENÍ — odtlačok formulára ostáva
//      rovnaký. Keby sa jantárové riadky kreslili len pri zmene pravidiel,
//      nový override by sa v sekcii objavil až po prepnutí sekcie (a vyzeralo by
//      to, že sa nič nestalo). Zároveň sa pri tom NESMIE prekresliť formulár.
//   3. Zoznam môže mať desiatky riadkov a texty v ňom sú z modelu (názvy skriniek
//      píše používateľ) — neescapovaný `<` by rozbil celú sekciu.

// --- 8) čisté funkcie riadkov ------------------------------------------------

(function(){
  eq(R.rdOvrHtml(null), '', 'žiadne ručné zásahy = ŽIADNY blok (vertikálny priestor je vzácny)');
  eq(R.rdOvrHtml({ total: 0, groups: [] }), '', 'ani prázdna skupina nič nekreslí');

  const g = { total: 2, title: 'Dielce s ručne nastavenými hranami (2)',
              note: 'Vrátiť na pravidlo pribudne v ďalšej dávke.',
              more_text: '…a ďalších 3 — zoznam je skrátený.',
              groups: [{ owner_id: 'CAB-001', title: 'CAB-001 · Dolná 600',
                         rows: [{ owner_id: 'CAB-001', part_key: 'zone:z1/shelf:1',
                                  label: 'Polica 1', desc: 'ručne nastavené hrany',
                                  value: 'Predná: bez olepu' }] }] };
  const h = R.rdOvrHtml(g);
  ok(/rdovr/.test(h), 'riadok je JANTÁROVÝ (trieda .rdovr)');
  ok(/class="rdchip">override</.test(h), 'a nesie štítok „override"');
  ok(h.indexOf('Dielce s ručne nastavenými hranami (2)') >= 0, 'nadpis skupiny je zo servera');
  ok(h.indexOf('CAB-001 · Dolná 600') >= 0, 'aj nadpis skrinky');
  ok(h.indexOf('…a ďalších 3') >= 0, 'skrátený zoznam sa PRIZNÁ');
  ok(h.indexOf('Vrátiť na pravidlo pribudne') >= 0,
     'a hint priznáva, že akcia „vrátiť na pravidlo" ešte nie je');
  ok(/#i-pencil/.test(h) && !/#i-alert/.test(h),
     'ikona je ceruzka (ručný zásah), NIE výstraha — riadok nehovorí o chybe');
  ok(/#i-eye/.test(h), 'oko je akcia riadku');
  // ŠT-3b-2b: k oku pribudla šípka „vrátiť na pravidlo" — detaily nižšie
  // v sekcii 3b-2b (adresa, obe identity, uzavretá mapa mien callbackov).
  ok(/#i-rotate-ccw/.test(h), 'a vedľa neho šípka „vrátiť na pravidlo"');
  // Argumenty idú do `onclick` cez `JSON.stringify` + escape (vzor `mdWhereEyeHtml`)
  // — v HTML sú preto `&quot;`, nie surové úvodzovky.
  ok(/rdSelectOverride\(&quot;CAB-001&quot;, &quot;zone:z1\/shelf:1&quot;\)/.test(h),
     'oko posiela ADRESU (owner_id, part_key), nie pids z DOM');
})();

(function(){
  // Názov skrinky píše používateľ — do HTML sa nesmie dostať surový.
  const h = R.rdOvrHtml({ total: 1, title: 'T', note: '', more_text: '',
                          groups: [{ owner_id: '<img>', title: '<b>zle</b>',
                                     rows: [{ owner_id: '<img>', part_key: '"x"',
                                              label: '<script>', desc: 'd', value: 'v' }] }] });
  ok(!/<script>/.test(h) && /&lt;script&gt;/.test(h), 'text z modelu je escapovaný');
  ok(!/<b>zle<\/b>/.test(h), 'aj nadpis skupiny');
  ok(/&quot;x&quot;/.test(h) || /\\&quot;x\\&quot;/.test(h), 'a argument v onclick tiež');
})();

(function(){
  const abs = { rows: [{ role: 'shelf', label: 'Polica', desc: 'Predná', value: '1,0 mm' }] };
  const h = R.rdAbsRulesHtml(abs);
  ok(h.indexOf('Polica') >= 0 && h.indexOf('1,0 mm') >= 0, 'pravidlo sa vykreslí textom zo servera');
  ok(!/rdovr/.test(h) && !/rdchip/.test(h), 'pravidlo NIE JE jantárové — jantár patrí override riadku');
  ok(!/#i-eye/.test(h), 'a nemá oko — pravidlo nie je miesto v modeli');
  ok(/Žiadne ABS pravidlá/.test(R.rdAbsRulesHtml({ rows: [] })), 'prázdny prehľad to povie');
})();

// --- 9) push: jantárové riadky sa obnovia, formulár NIE ----------------------

(function(){
  const base = { version: '0.7.63', model_guid: 'G1', source: 'project', cabinets: 2,
                 rules: [{ kind: 'fixed', output: 'leg', enabled: true, quantity: 4,
                           applies_to: { role: 'cabinet' } }],
                 abs: { rows: [{ role: 'shelf', label: 'Polica', desc: 'Predná', value: '1,0 mm' }],
                        source: 'zdroj: globálne predvoľby', hint: 'ABS pravidlá nemajú editor' },
                 overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } };
  ELS.secbody.innerHTML = '';
  R.rdApplyState(base);
  R.rulesRenderBody();
  ok(/Polica/.test(ELS.rdAbsBox.innerHTML), 'ABS pravidlá sa vykreslili do vlastného uzla');
  eq(ELS.rdAbsSrc.textContent, 'zdroj: globálne predvoľby',
     'a skupina ABS má VLASTNÝ riadok zdroja (iný rozsah než kovanie)');
  eq(ELS.rdAbsHint.textContent, 'ABS pravidlá nemajú editor', 'aj vlastný hint');
  eq(ELS.rdAbsOvr.innerHTML, '', 'bez ručných zásahov sa nekreslí nič');

  // Ručný zásah v Inspectore: pravidlá sú TIE ISTÉ (odtlačok sa nemení),
  // ale pribudol override. Musí sa objaviť HNEĎ — a formulár ostať nedotknutý.
  ELS.rulesBox.innerHTML = 'ROZPÍSANÉ';
  const next = JSON.parse(JSON.stringify(base));
  next.overrides.abs = { total: 1, title: 'Dielce s ručne nastavenými hranami (1)',
                         note: '', more_text: '',
                         groups: [{ owner_id: 'CAB-001', title: 'CAB-001',
                                    rows: [{ owner_id: 'CAB-001', part_key: 'p1', label: 'Polica 1',
                                             desc: 'ručne nastavené hrany', value: 'Predná: bez olepu' }] }] };
  R.rdApplyState(next);
  ok(/Polica 1/.test(ELS.rdAbsOvr.innerHTML),
     'nový override sa objaví HNEĎ — aj keď sa pravidlá nezmenili');
  eq(ELS.rulesBox.innerHTML, 'ROZPÍSANÉ',
     'a rozpísaný formulár pravidiel kovania to NEPREKRESLILO');

  // Kovanie má vlastný uzol pod svojou skupinou.
  const hw = JSON.parse(JSON.stringify(next));
  hw.overrides.hardware = { total: 1, title: 'Skrinky s ručne nastaveným kovaním (1)',
                            note: '', more_text: '',
                            groups: [{ owner_id: 'CAB-001', title: 'CAB-001',
                                       rows: [{ owner_id: 'CAB-001', part_key: '', label: 'Nohy',
                                                desc: 'ručne nastavené na skrinke', value: 'počet 6 ks' }] }] };
  R.rdApplyState(hw);
  ok(/Nohy/.test(ELS.rdHwOvr.innerHTML), 'kovanie má vlastný zoznam');
  ok(!/Nohy/.test(ELS.rdAbsOvr.innerHTML), 'a nemieša sa s ABS');

  // Zmena, ktorá príde KÝM je telo odpojené, sa dokreslí pri návrate.
  ELS.secbody.innerHTML = '<div>Kusovník</div>';
  const later = JSON.parse(JSON.stringify(hw));
  later.overrides.abs.groups[0].rows[0].label = 'Polica 9';
  R.rdApplyState(later);
  R.rulesRenderBody();
  ok(/Polica 9/.test(ELS.rdAbsOvr.innerHTML),
     'návrat do sekcie dokreslí aj to, čo prišlo počas odpojenia');
})();

// --- 10) oko: tá istá cesta ako výber v Kusovníku ----------------------------

(function(){
  SENT.length = 0;
  global.ST = null;
  R.rdSelectOverride('CAB-001', 'p1');
  eq(SENT.length, 0, 'bez stavu okna sa NEPOSIELA nič (starý DOM po zatvorení)');
  global.ST = { gen: 7 };
  R.rdSelectOverride('CAB-001', 'p1');
  eq(SENT.length, 1, 'klik posiela práve jednu žiadosť');
  eq(SENT[0][0], 'nx_select', 'a ide TOU ISTOU cestou ako výber v Kusovníku');
  const p = JSON.parse(SENT[0][1]);
  eq(p.gen, 7, 'nesie generáciu okna — starý klik server odmietne');
  eq(p.rule_ref, { owner_id: 'CAB-001', part_key: 'p1' }, 'a adresu overridu');
  ok(!('pids' in p), 'žiadne pids z DOM — rebuild ich mení');
  SENT.length = 0;
  R.rdSelectOverride('CAB-002', '');
  eq(JSON.parse(SENT[0][1]).rule_ref.part_key, '',
     'override kovania na skrinke posiela PRÁZDNY kľúč (server označí korpus)');
})();

// ============ ŠT-3b-2b: „vrátiť na pravidlo" (zápis zo sekcie) =============
//
// Prečo sú to testy a nie klikanie:
//   1. Je to ZÁPIS do modelu spustený z riadku zoznamu. Klik musí niesť OBE
//      identity (generáciu okna aj dokument) — bez nich by kliknutie do starého
//      zoznamu prestavalo skrinku, ktorú používateľ na obrazovke ani nevidí.
//   2. Meno callbacku vyberá KLIENT z uzavretej mapy. Keby ho skladal z dát
//      riadku, payload by rozhodoval, ktorá serverová cesta sa zavolá.
//   3. Riadok musí mať šípku hneď vedľa oka a tooltip, ktorý povie, že to ide
//      vrátiť jedným krokom Späť (potvrdzovací dialóg zámerne nie je).

(function(){
  const g = { total: 1, title: 'T', note: '', more_text: '',
              groups: [{ owner_id: 'CAB-001', title: 'CAB-001',
                         rows: [{ kind: 'abs', owner_id: 'CAB-001', part_key: 'zone:z1/shelf:1',
                                  label: 'Polica 1', desc: 'ručne nastavené hrany',
                                  value: 'Predná: bez olepu' }] }] };
  const h = R.rdOvrHtml(g);
  ok(/#i-rotate-ccw/.test(h), 'jantárový riadok má šípku „vrátiť na pravidlo" (mockup Š17)');
  ok(/title="Vrátiť na pravidlo[^"]*Späť/.test(h),
     'a tooltip hovorí, že jeden krok Späť to vráti (preto sa nepýta potvrdenie)');
  ok(h.indexOf('#i-eye') < h.indexOf('#i-rotate-ccw'),
     'poradie akcií: najprv pozrieť, až potom meniť');
  ok(/rdResetOverride\(&quot;abs&quot;, &quot;CAB-001&quot;, &quot;zone:z1\/shelf:1&quot;/.test(h),
     'klik nesie DRUH riadku a jeho adresu (escapované — texty sú z modelu)');

  const hw = R.rdOvrHtml({ total: 1, title: 'T', note: '', more_text: '',
                           groups: [{ owner_id: 'CAB-002', title: 'CAB-002',
                                      rows: [{ kind: 'hw', owner_id: 'CAB-002', part_key: '',
                                               generic_type: 'hinge', rule_id: 'zavesy-podla-vysky',
                                               label: 'Závesy', desc: 'ručne nastavené',
                                               value: 'počet 6 ks' }] }] });
  ok(/&quot;hinge&quot;, &quot;zavesy-podla-vysky&quot;/.test(hw),
     'kovanie posiela aj TROJICU identity (dve pravidlá s rovnakým výstupom sú samostatné)');
})();

(function(){
  SENT.length = 0;
  global.ST = null;
  R.rdResetOverride('abs', 'CAB-001', 'p1', '', '');
  eq(SENT.length, 0, 'bez stavu okna sa NEZAPISUJE nič');

  global.ST = { gen: 12 };
  R.rdResetOverride('abs', 'CAB-001', 'p1', '', '');
  eq(SENT.length, 1, 'klik posiela práve jednu žiadosť');
  eq(SENT[0][0], 'reset_abs_override', 'ABS riadok volá ABS cestu');
  const p = JSON.parse(SENT[0][1]);
  eq(p.gen, 12, 'nesie generáciu okna — klik zo zastaraného zoznamu server odmietne');
  eq(p.owner_id, 'CAB-001', 'a adresu skrinky');
  eq(p.part_key, 'p1', 'aj dielca');
  ok('model_guid' in p, 'a identitu dokumentu (zápis z iného .skp sa odmietne)');

  SENT.length = 0;
  R.rdResetOverride('hw', 'CAB-002', '', 'hinge', 'zavesy');
  eq(SENT[0][0], 'reset_hw_override', 'riadok kovania volá kovaniu cestu');
  const q = JSON.parse(SENT[0][1]);
  eq([q.generic_type, q.rule_id], ['hinge', 'zavesy'], 's celou trojicou identity');
  eq(q.part_key, '', 'override na skrinke posiela PRÁZDNY kľúč dielca');

  SENT.length = 0;
  R.rdResetOverride('cokolvek_ine', 'CAB-001', 'p1', '', '');
  eq(SENT.length, 0,
     'neznámy druh riadku NEZAVOLÁ nič — meno callbacku vyberá klient z uzavretej mapy, nie payload');
})();

// ---- ŠT-3b-2b, review #222: echo sekcie + klik, ktorý nemá kam ísť --------
//
// 1. Odmietnutý zápis prichádza LACNÝM ECHOM (`RD.setSection`), nie plným
//    pushom okna — ten totiž beží cez zber modelu, ktorý prečísluje ID kópií,
//    takže by odmietnutý klik ZAPÍSAL do modelu. Echo musí sekciu obnoviť
//    rovnako ako plný push (vrátane jantárových riadkov).
// 2. Klik, ktorý sa nemá kam poslať, NESMIE mlčať — riadok by ostal jantárový
//    a používateľ by veril, že sa niečo stalo.

(function(){
  const base = { version: '0.7.64', model_guid: 'G9', source: 'project', cabinets: 1,
                 rules: [{ kind: 'fixed', output: 'leg', enabled: true, quantity: 4,
                           applies_to: { role: 'cabinet' } }],
                 abs: { rows: [{ role: 'shelf', label: 'Polica', desc: 'Predná', value: '1,0 mm' }],
                        source: 'zdroj: globálne predvoľby', hint: 'h' },
                 overrides: { abs: { total: 1, title: 'T', note: '', more_text: '',
                                     groups: [{ owner_id: 'CAB-007', title: 'CAB-007',
                                                rows: [{ kind: 'abs', owner_id: 'CAB-007',
                                                         part_key: 'p1', label: 'Polica 7',
                                                         desc: 'ručne nastavené hrany',
                                                         value: 'Predná: bez olepu' }] }] },
                              hardware: { total: 0, groups: [] } } };
  ELS.secbody.innerHTML = '';
  R.rdApplyState(base);
  R.rulesRenderBody();
  ok(/Polica 7/.test(ELS.rdAbsOvr.innerHTML), 'východiskový stav sekcie je vykreslený');

  // Server odmietol zápis a poslal echo s NEZMENENÝMI pravidlami, ale
  // s obnoveným zoznamom (riadok medzitým zanikol inou cestou).
  const echo = JSON.parse(JSON.stringify(base));
  echo.overrides.abs = { total: 0, groups: [] };
  R.RD.setSection(echo);
  eq(ELS.rdAbsOvr.innerHTML, '',
     'echo obnoví jantárové riadky rovnako ako plný push (bez neho by riadok „visel")');

  // A rozpísaný formulár pravidiel pritom prežije — echo nie je re-render formulára.
  ELS.rulesBox.innerHTML = 'ROZPÍSANÉ';
  R.RD.setSection(echo);
  eq(ELS.rulesBox.innerHTML, 'ROZPÍSANÉ', 'formulár kovania echo NEPREKRESLÍ');
})();

(function(){
  SENT.length = 0;
  ELS.status._text = '';
  global.ST = { gen: 3 };
  R.rdResetOverride('neznamy_druh', 'CAB-001', 'p1', '', '');
  eq(SENT.length, 0, 'neznámy druh riadku nič nepošle');
  ok(/nedá/.test(ELS.status.textContent), 'ale POVIE to — mlčať by znamenalo „asi sa to podarilo"');

  const prevSk = global.window.sketchup;
  global.window.sketchup = undefined;
  global.sketchup = undefined;
  ELS.status._text = '';
  R.rdResetOverride('abs', 'CAB-001', 'p1', '', '');
  ok(/spojenie/.test(ELS.status.textContent), 'a stratený kanál okna tiež');
  global.window.sketchup = prevSk;
  global.sketchup = prevSk;
})();

// ---- ŠT-3b-2c1: parita so serverom + vynútené prekreslenie formulára --------
//
// 1. Kritériá klienta a servera musia byť ROVNAKÉ. Keď sa rozídu, vznikne buď
//    formulár, ktorý sa nedá uložiť a nikto nevie prečo, alebo diera (klient
//    pustí, server odmietne až po prestavbe). Obe strany preto čítajú TEN ISTÝ
//    súbor prípadov — `tests/fixtures/rules_validation_parity.json`.
// 2. `RD.setSection(payload, force)` s `force` je JEDINÁ cesta, kde sa rozpísaný
//    formulár VEDOME zahodí: pravidlá na modeli sa medzitým zmenili, takže
//    hodnoty vo formulári už neplatia a uložiť ich nad cudziu zmenu by bolo
//    horšie než ich stratiť. Bez `force` platí bežný kontrakt (push formulár
//    prežije) — a to je práve to, čo sa tu musí strážiť oboma smermi.

(function(){
  const fx = JSON.parse(fs.readFileSync(
    path.join(__dirname, '..', 'fixtures', 'rules_validation_parity.json'), 'utf8'));
  ok(fx.cases.length >= 10, 'fixtúra má dosť prípadov (inak parita nič nestráži)');
  fx.cases.forEach(function(c){
    const bad = R.rdValidate(c.rules) !== null;
    eq(bad, c.invalid, 'klient: ' + c.name);
  });
})();

(function(){
  // Hláška klienta musí ADRESOVAŤ pravidlo — pri desiatich pravidlách inak
  // používateľ nevie, ktoré opraviť (server hovorí to isté vlastným textom).
  const msg = R.rdValidate([{ rule_id: 'zavesy', output: 'hinge', kind: 'bands', enabled: true,
                              bands: [{ max: 900, quantity: 2 }] }]);
  ok(/Závesy/.test(msg) && /všetko nad/.test(msg), 'klientska hláška menuje pravidlo aj to, čo chýba');
})();

(function(){
  const base = { version: '0.7.65', model_guid: 'G5', source: 'project', cabinets: 2,
                 rules: [{ kind: 'fixed', output: 'leg', enabled: true, quantity: 4,
                           applies_to: { role: 'cabinet' } }],
                 abs: { rows: [], source: '', hint: '' },
                 overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } };
  ELS.secbody.innerHTML = '';
  R.rdApplyState(base);
  R.rulesRenderBody();

  // (a) BEŽNÉ echo (bez `force`) rozpísaný formulár NEPREKRESLÍ.
  ELS.rulesBox.innerHTML = 'ROZPÍSANÉ';
  R.RD.setSection(base, false);
  eq(ELS.rulesBox.innerHTML, 'ROZPÍSANÉ', 'echo bez `force` hodnoty vo formulári nechá');

  // (b) VYNÚTENÉ echo (odmietnutý save — pravidlá na modeli sa zmenili)
  //     formulár prekreslí, aj keď server pošle TIE ISTÉ pravidlá.
  R.RD.setSection(base, true);
  ok(/value="4"/.test(ELS.rulesBox.innerHTML),
     'echo s `force` formulár prekreslí VŽDY — rozpísané hodnoty už neplatia');

  // (c) …a odtlačok sa OMLADÍ: najbližší bežný push s tými istými pravidlami
  //     už formulár prekresliť nesmie (inak by sa strácali hodnoty donekonečna).
  ELS.rulesBox.innerHTML = 'ZNOVA ROZPÍSANÉ';
  R.rdApplyState(base);
  eq(ELS.rulesBox.innerHTML, 'ZNOVA ROZPÍSANÉ', 'odtlačok je omladený — ďalší push je pokojný');

  // (d) Prázdny payload (server zlyhal pri zostavovaní) NESMIE vyprázdniť sekciu
  //     ani vo `force` vetve — inak by zlyhanie servera zmazalo formulár aj
  //     jantárové riadky a vyzeralo by to, že v projekte nič nie je.
  const keep = ELS.rulesBox.innerHTML;
  R.RD.setSection(null, true);
  eq(ELS.rulesBox.innerHTML, keep, 'prázdny payload formulár nezmaže ani vo `force` vetve');
  R.RD.setSection(undefined, false);
  eq(ELS.rulesBox.innerHTML, keep, 'ani v bežnej vetve');
})();

// ---- ŠT-3b-2c2: odtlačok pravidiel (`rules_rev`) na klientovi -------------
//
// Klient odtlačok NIKDY nepočíta — iba ho drží a pri uložení vracia. Vlastný
// výpočet by ani nemohol sedieť (Ruby serializuje `900.0`, JS `900`), takže by
// server odmietal každé uloženie a nikto by nevedel prečo. Testy strážia tri
// veci: že si ho klient uloží, že ho pošle späť, a že mu ho „Načítať globálne"
// NEPREPÍŠE — globálne predvoľby nie sú stav projektu.

(function(){
  const base = { version: '0.7.66', model_guid: 'G7', source: 'project', cabinets: 1,
                 rules_rev: 'abc123def456',
                 rules: [{ kind: 'fixed', output: 'leg', enabled: true, quantity: 4,
                           applies_to: { role: 'cabinet' } }],
                 abs: { rows: [], source: '', hint: '' },
                 overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } };
  ELS.secbody.innerHTML = '';
  R.rdApplyState(base);
  R.rulesRenderBody();

  SENT.length = 0;
  R.rdSaveRules();
  eq(SENT.length, 1, 'uloženie odišlo');
  const p = JSON.parse(SENT[0][1]);
  eq(p.rules_rev, 'abc123def456', 'zápis vracia odtlačok, s ktorým bol formulár naplnený');
  eq(p.model_guid, 'G7', 'a naďalej aj identitu dokumentu (dve nezávislé vrstvy)');

  // Push s NEZMENENÝMI pravidlami, ale novým odtlačkom (server prepočítal) —
  // klient musí prevziať ten nový, inak by ukladal so zastaraným.
  const echo = JSON.parse(JSON.stringify(base));
  echo.rules_rev = 'novy999';
  R.rdApplyState(echo);
  SENT.length = 0;
  R.rdSaveRules();
  eq(JSON.parse(SENT[0][1]).rules_rev, 'novy999',
     'aj „pokojný" push (rovnaké pravidlá) odtlačok obnoví');

  // „Načítať globálne" mení FORMULÁR, nie stav projektu — odtlačok ostáva.
  R.RD.setRules([{ kind: 'fixed', output: 'leg', enabled: true, quantity: 9,
                   applies_to: { role: 'cabinet' } }], 'global');
  SENT.length = 0;
  R.rdSaveRules();
  const after = JSON.parse(SENT[0][1]);
  eq(after.rules_rev, 'novy999',
     '„Načítať globálne" odtlačok NEPREPÍŠE — inak by uloženie po ňom prepísalo cudziu zmenu');
  // (Hodnoty formulára sem nekontrolujeme — `rdCollectRules` ich číta z DOM,
  //  ktorý stub nemodeluje; ide o odtlačok, nie o obsah.)

  // Starší cachovaný DOM: payload bez `rules_rev` nesmie poslať `undefined`.
  const old = JSON.parse(JSON.stringify(base));
  delete old.rules_rev;
  old.rules[0].quantity = 5; // iné pravidlá => `rdApplyState` stav naozaj nasadí
  R.rdApplyState(old);
  SENT.length = 0;
  R.rdSaveRules();
  eq(JSON.parse(SENT[0][1]).rules_rev, '',
     'chýbajúci odtlačok = prázdny reťazec (server ho tolerantne prepustí)');
})();

(function(){
  // Odtlačok sa NIKDY nepočíta v klientovi — strážené na zdrojáku, lebo
  // „počítaj si ho sám" je presne tá oprava, ktorú by niekto v dobrej viere
  // spravil, keby ho v payloade nenašiel.
  const src = fs.readFileSync(path.join(JS, 'rules.js'), 'utf8')
                .split('\n').filter(function(l){ return l.trim().indexOf('//') !== 0; }).join('\n');
  ok(!/sha1|SHA1|digest/i.test(src), 'žiadny vlastný hash na klientovi');
  ok(/rules_rev: d\.rules_rev/.test(src), 'odtlačok prichádza výhradne zo servera');
})();

console.log(`OK ${n} kontrol (ŠT-3b sekcia Pravidlá — 3b-1/2a/2b/2c1/2c2)`);

// --- TEST-1: „Úchytky" — hint PER ROLU --------------------------------------
// Nález z prvého testu v0.8.0: pravidlá pre dvierka a pre zásuvkové čelá mali
// JEDNU spoločnú vysvetlivku („dĺžka rezu = šírka krídla"). Pri zásuvkách to
// klamalo (zásuvka nemá krídlo) a obe pravidlá vyzerali ako duplicita.
(function(){
  const d = R.rdHandleHint('drawer_front');
  const f = R.rdHandleHint('front_door');
  ok(d.indexOf('šírka čela') > -1, 'zásuvkové čelo hovorí o ŠÍRKE ČELA');
  ok(d.indexOf('na čelo') > -1, 'a o kuse na čelo');
  ok(d.indexOf('krídl') < 0, 'a NESPOMÍNA krídlo — zásuvka ho nemá');
  ok(f.indexOf('šírka krídla') > -1, 'dvierka ostávajú pri šírke krídla');
  ok(d !== f, 'obe roly majú RÔZNY text (inak vyzerajú ako duplicita)');
  // Neznáma/chýbajúca rola nesmie spadnúť ani mlčať — padá na text dvierok.
  ok(R.rdHandleHint('').indexOf('šírka krídla') > -1, 'chýbajúca rola má rozumný default');
  ok(R.rdHandleHint(undefined).indexOf('šírka krídla') > -1, 'aj undefined');
  [d, f].forEach(function(t){
    ok(t.indexOf('úchytkovým profilom') > -1, 'obe naďalej hovoria, kedy pravidlo vôbec platí');
  });
})();
