// ŠT-3a-1 — sekcia KOVANIE (`hw`) v okne Štúdio (klient).
//
// Preco su to testy a nie klikanie:
//   1. „Sekcia si kresli telo SAMA" sa da rozbit jedinym riadkom v `studio.js`
//      — a rozbije sa TICHO: telo sa prekresli spravne, len pouzivatel prave
//      stratil rozpisany formular novej polozky alebo rozpisany editor setu.
//   2. Ten isty subor (`js/hw_catalog.js`) bezi v DVOCH oknach. Kolizia
//      globalneho mena so `studio.js` by prepisala CUDZIU funkciu — a padlo by
//      nieco uplne ine (napr. kusovnik), nie kovanie.
//   3. Lista sekcie sa PREKRESLUJE pri kazdom pushi. Ked si hladanie a filtre
//      nedrzia hodnotu aj v premennych, uzivatelovi zmizne filter pri prvom
//      prepocte kusovnika — a zoznam pod nim ostane zuzeny.
//   4. Blok „Predvoľby projektu" ZAPISUJE DO MODELU. V tejto davke sa jeho
//      ovladace do sekcie nedostali; keby sa tam omylom vratili, sekcia by
//      zapisovala do zakazky cestou, ktoru nikto neotestoval.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_st2a_mat.js) -------------------------------
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
  return n;
}
// Uzly, ktore render sekcie naozaj hlada. `hwList` je tu ZAMERNE: bez neho by
// `mdhRender` hned vypadol a test by tvrdil kontrakt, ktory nic nevykonal.
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio',
 'hwList', 'hwNewForm', 'hwTabItems', 'hwTabSets', 'hwTabProj',
 'hwRoBanner', 'hwRoText', 'hwline', 'hn_category', 'hn_unit', 'hwDelModal'].forEach(function(id){
  ELS[id] = stubEl(id);
});
ELS.hwBodyTpl = stubEl('hwBodyTpl');
ELS.hwBodyTpl.content = stubEl('hwBodyTplContent');

const SENT = [];   // co klient poslal serveru
global.window = {
  NX_HW_SECTION: true,
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
  querySelector: function(){ return null; }
};

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;           // poradie <script> v studio.html
const H = require(path.join(JS, 'hw_catalog.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

// --- 1) LISTA sekcie — cista funkcia ----------------------------------------

(function(){
  const h = H.hwToolsHtml({ view: 'items', q: 'blum', cat: 'závesy',
                            cats: ['závesy', 'výsuvy'], inactive: false,
                            ro: false, stale: false });
  ok(/data-action="hw-view" data-view="items"/.test(h), 'segment má pohľad Položky');
  ok(/data-action="hw-view" data-view="sets"/.test(h), 'aj Sety (Š16)');
  const itemsBtn = h.match(/<button[^>]*data-view="items"[^>]*>/)[0];
  const setsBtn = h.match(/<button[^>]*data-view="sets"[^>]*>/)[0];
  ok(/class="bomvw on"/.test(itemsBtn) && !/ on"/.test(setsBtn),
     'aktívny pohľad je označený — a práve jeden');
  ok(h.indexOf('data-view="items"') < h.indexOf('data-view="sets"'),
     'poradie pohľadov je Položky · Sety (vzor mockupu)');
  ok(/value="blum"/.test(h), 'hľadanie si nesie dotaz — lišta sa prekresľuje pri každom pushi');
  ok(/<option value="závesy" selected>/.test(h), 'a filter kategórie tiež');
  ok(/id="hwInactive"(?![^>]*checked)/.test(h), 'prepínač „neaktívne" je vypnutý');
  ok(/<span class="spacer">/.test(h), 'lišta má rozrážač — nástroje idú doprava');
  ok(h.indexOf('id="hwNewBtn"') < h.indexOf('id="hwSearch"'),
     'pridávacia akcia je VĽAVO od nástrojov (vzor lišty Štúdia)');
  ok(/class="primary" id="hwNewBtn"/.test(h),
     '„Nová položka" je primárna akcia sekcie — hlavná cesta zakladania');
})();

(function(){
  const h = H.hwToolsHtml({ view: 'items', ro: true, cats: [] });
  const btn = h.match(/<button[^>]*id="hwNewBtn"[^>]*>/)[0];
  ok(/disabled/.test(btn),
     'núdzový (read-only) katalóg vypína pridávanie — server by ho aj tak odmietol');
})();

(function(){
  const h = H.hwToolsHtml({ view: 'sets', cats: [] });
  ok(!/id="hwSearch"/.test(h), 'v pohľade Sety hľadanie položiek nesvieti — nemá čo filtrovať');
  ok(!/id="hwNewBtn"/.test(h), 'ani „Nová položka" (patrí k položkám katalógu)');
  ok(/data-view="sets"/.test(h), 'segment ostáva — je to jediná cesta späť');
  ok(/id="refreshBtn"/.test(h), 'a „Obnoviť" má KAŽDÝ pohľad');
})();

// Jantárové „Obnoviť" je ZDIEĽANÝ markup celého okna — sekcia ho nekreslí vlastné.
(function(){
  const cold = H.hwToolsHtml({ view: 'items', cats: [], stale: false });
  const warm = H.hwToolsHtml({ view: 'items', cats: [], stale: true });
  ok(cold.indexOf(S.refreshBtnHtml(false, 'Načítať čerstvý katalóg kovania a sety')) >= 0,
     'pokojný stav ide TÝM ISTÝM helperom ako ostatné sekcie');
  ok(/nxstale/.test(warm) && !/nxstale/.test(cold),
     'jantárový stav prichádza ARGUMENTOM zo studio.js (jediná autorita staleFlag)');
})();

// --- 2) push zo servera NESMIE zmazať telo sekcie ---------------------------

(function(){
  const payload = {
    version: '0.7.58', gen: 1, model_title: 'test', model_guid: 'G1',
    rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null,
    summary: {}, sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {},
    vepo: {}, control: [], counts: {}, budget: null, mat: null,
    hw: { model_guid: 'G1', sets: null,
          catalog: { version: '0.7.58', categories: ['závesy'], units: ['ks'],
                     items: [{ item_code: 'A1', name_sk: 'Záves', unit: 'ks',
                               price_eur_vat: 1.2, row_rev: 'r1' }],
                     revision: 'c1', state: 'ok', state_reason: '' } },
    open_section: 'hw'
  };
  global.NX.setStudio(payload);
  const body = ELS.secbody;
  body.innerHTML = '';
  H.hwRenderBody();
  eq(body.children.length, 1, 'telo sekcie sa pripojilo do #secbody');
  const node = body.children[0];
  eq(node.id, 'hwBody', 'a je to JEDEN uzol sekcie (klon šablóny), nie znovu poskladaný HTML');

  // Simulácia „rozpísaného formulára": uzol, ktorý tam nikto iný nedáva.
  const draft = stubEl('draft');
  node.appendChild(draft);

  global.NX.setStudio(payload);
  H.hwRenderBody();
  eq(body.children.length, 1, 'po ďalšom pushi je telo stále práve jedno');
  ok(body.children[0] === node, 'a je to TEN ISTÝ uzol — push ho neprekreslil');
  ok(node.children.indexOf(draft) >= 0 && draft.parentNode === node,
     'rozpísaný formulár v ňom PREŽIL (push zo servera ho nesmie zmazať)');

  // Odchod do inej sekcie telo odpojí, návrat ho má vrátiť AJ s obsahom.
  body.innerHTML = '<div>Kusovník</div>';
  eq(node.parentNode, null, 'iná sekcia si telo Kovania odpojila (vzor prehliadača)');
  H.hwRenderBody();
  ok(body.children[0] === node, 'návrat do sekcie vráti TEN ISTÝ uzol');
  ok(node.children.indexOf(draft) >= 0, 'aj s rozpísaným formulárom');
})();

// --- 3) prvý push si vypýta serverové poradie AŽ keď je telo v DOM ----------

(function(){
  const searches = SENT.filter(function(x){ return x[0] === 'hw_search'; });
  ok(searches.length > 0, 'klient si vypýtal serverové poradie (JS si ho NIKDY nedopĺňa)');
  const q = JSON.parse(searches[searches.length - 1][1]);
  ok(Object.prototype.hasOwnProperty.call(q, 'query') &&
     Object.prototype.hasOwnProperty.call(q, 'category') &&
     Object.prototype.hasOwnProperty.call(q, 'include_inactive'),
     'dotaz nesie text, kategóriu aj prepínač neaktívnych');
})();

// --- 4) pohľad Sety schová položky a naopak ---------------------------------

(function(){
  H.hwSetView('sets');
  eq(ELS.hwTabItems.style.display, 'none', 'pohľad Sety schová zoznam položiek');
  eq(ELS.hwTabSets.style.display, '', 'a ukáže sety');
  eq(ELS.hwTabProj.style.display, '',
     'aj blok „Predvoľby projektu" — patrí k setom (mockup ich kreslí ako jeden pohľad)');
  H.hwSetView('items');
  eq(ELS.hwTabItems.style.display, '', 'návrat ukáže položky');
  eq(ELS.hwTabSets.style.display, 'none', 'a sety schová');
  eq(ELS.hwTabProj.style.display, 'none', 'aj predvoľby');
  H.hwSetView('nieco-vymyslene');
  eq(ELS.hwTabItems.style.display, '', 'neznámy pohľad padá na Položky (klient nič nevymýšľa)');
})();

// --- 5) odchod zo sekcie: najprv server, potom modály -----------------------

(function(){
  SENT.length = 0;
  ELS.hwDelModal.style.display = '';
  H.hwOnLeaveSection();
  const idx = SENT.findIndex(function(x){ return x[0] === 'hw_leave'; });
  ok(idx >= 0, 'odchod sa hlási SERVERU (ten ruší bežiaci fetch a povie prečo)');
  eq(ELS.hwDelModal.style.display, 'none', 'a modál potvrdenia mazania sa zavrie');
  // Review P2 #4: náhľad z Demosu NIE JE modál — žije v tele sekcie, ktoré sa
  // pri odchode UCHOVÁ. Bez resetu by v ňom navždy visel stav „Načítavam
  // stránku…", hoci server beh už zrušil.
  const leaveFn = fs.readFileSync(path.join(JS, 'hw_catalog.js'), 'utf8')
    .match(/function hwCloseModals\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/MDH_DEMOS = null/.test(leaveFn), 'odchod zhodí rozbehnutý náhľad z Demosu');
  ok(/mdhRenderDemosPreview\(\)/.test(leaveFn) && /mdhRenderDemosHits\(\[\]\)/.test(leaveFn),
     'a prekreslí obe miesta, kde bol vidieť (náhľad aj zhody hľadania)');
})();

// --- 6) kolízie globálov ----------------------------------------------------

(function(){
  // Ten istý súbor beží vedľa `studio.js`, `budget.js`, `proj_materials.js`
  // a Demos modulov. Rovnaké meno na top-level úrovni by ticho prepísalo cudziu
  // funkciu — a padlo by niečo úplne iné než kovanie.
  const files = ['studio.js', 'budget.js', 'proj_materials.js', 'nx_modal.js',
                 'edge_menu.js', 'demos_diff.js', 'demos_add.js',
                 'hw_catalog.js', 'hw_sets.js'];
  const names = {};
  files.forEach(function(f){
    const src = fs.readFileSync(path.join(JS, f), 'utf8');
    const set = new Set();
    const re = /^ {0,2}(?:function\s+(\w+)|var\s+(\w+))/gm;
    let m;
    while ((m = re.exec(src)) !== null) set.add(m[1] || m[2]);
    names[f] = set;
  });
  ok(names['hw_catalog.js'].size > 20, 'zoznam mien sa naozaj načítal (inak by test nič nestrážil)');
  ok(names['hw_catalog.js'].has('hwEl') && !names['hw_catalog.js'].has('el'),
     'preto sa helpery volajú hwEl/hwEsc (nie el/esc zo studio.js)');
  files.forEach(function(a){
    files.forEach(function(b){
      if (a >= b) return;
      const clash = [...names[a]].filter(function(x){ return names[b].has(x); });
      eq(clash, [], `js/${a} a js/${b} nesmú zdieľať globálne meno`);
    });
  });
})();

// --- 7) read-only predvoľby projektu (modelové zápisy sú v ŠT-3a-2) ---------

(function(){
  // `hw_sets.js` sa v Node načítava samostatne — kontrolujeme jeho ČISTÚ
  // funkciu a to, že read-only režim vôbec existuje a dá sa zapnúť.
  const HWS = require(path.join(JS, 'hw_sets.js'));
  eq(typeof HWS.hwsSetProjReadOnly, 'function',
     'sekcia sa vie prihlásiť do read-only režimu predvolieb projektu');
  const opts = [{ set_id: 's1', name: 'Atira biela' }];
  eq(HWS.hwsMappingValueText(null, opts, []), '— bez setu (ORANGE)',
     'nenamapovaný typ sa prizná ako ORANGE, nie prázdnym riadkom');
  eq(HWS.hwsMappingValueText('s1', opts, []), 'Atira biela', 'namapovaný set ukáže NÁZOV');
  eq(HWS.hwsMappingValueText('s9', opts, []), 's9 (chýba)',
     'set, ktorý knižnica už nemá, sa NEZAMLČÍ — riadok nesmie klamať');
  const sel = { param: 'front_height', bands: [{ min: 100, max: 200, set_id: 's1' }] };
  ok(/100–200 → Atira biela/.test(HWS.hwsMappingValueText(sel, opts, [])),
     'výber podľa parametra sa vypíše ako čitateľný prehľad pásiem');
})();

// --- 8) zdrojáky: kontrakty, ktoré sa dajú overiť len čítaním ---------------

(function(){
  const src = fs.readFileSync(path.join(JS, 'hw_catalog.js'), 'utf8');
  const sets = fs.readFileSync(path.join(JS, 'hw_sets.js'), 'utf8');
  const studio = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');
  const win = fs.readFileSync(path.join(JS, '..', 'hardware_catalog.html'), 'utf8');

  ok(/!window\.NX_HW_SECTION/.test(src),
     '`ready` sa v Štúdiu NEPOSIELA — poslal by celý payload druhýkrát');
  ok(/sketchup\.ready\(/.test(src),
     'ale volanie ostáva — okno „Katalóg kovania" je bez neho prázdne (žije do ŠT-3a-2)');
  ok(win.indexOf('js/hw_catalog.js') > 0 && win.indexOf('js/hw_sets.js') > 0,
     'okno beží na TÝCH ISTÝCH súboroch (žiadna druhá kópia obsahu)');
  ok(!/NX_HW_SECTION/.test(win), 'a príznak sekcie v ňom nie je');

  ok(studio.indexOf('js/studio.js') < studio.indexOf('js/hw_catalog.js'),
     'hw_catalog.js sa načítava AŽ ZA studio.js (obaľuje jeho NX.setStudio)');
  ok(studio.indexOf('js/hw_sets.js') < studio.indexOf('js/hw_catalog.js'),
     'a hw_sets.js pred ním (ten mu zapína read-only režim predvolieb)');
  ok(studio.indexOf('NX_HW_SECTION') < studio.indexOf('js/hw_catalog.js'),
     'príznak sekcie musí byť nastavený PRED načítaním súboru');

  // Modelové zápisy sa do sekcie nedostali ani cez klienta: ich tlačidlá
  // kreslí `hwsRenderProj` LEN mimo read-only režimu.
  const projFn = sets.match(/function hwsRenderProj\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/HWS_PROJ_RO/.test(projFn), 'blok „Predvoľby projektu" pozná read-only režim');
  ok(projFn.indexOf('hws-merge-seed') > projFn.indexOf('HWS_PROJ_RO'),
     'zapisovacie tlačidlá sú za vetvou režimu, nie pred ňou');
  ok(/hws-open-window/.test(sets), 'a namiesto nich je PREMOSTENIE do okna (D-78)');
})();

console.log(`OK ${n} kontrol (ŠT-3a-1 sekcia Kovanie)`);
