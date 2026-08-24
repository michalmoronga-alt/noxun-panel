// ŠT-3a-1/3a-2 — sekcia KOVANIE (`hw`) v okne Štúdio (klient).
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
    set(v){
      n._html = v;
      n.children.forEach(function(c){ c.parentNode = null; });
      // Rovnaká vernosť ako pri `textContent`: vyprázdnenie uzla zahodí aj
      // jeho hodnotu (`<select>` bez options nemá čo vybrať).
      if (n.children.length) n.value = '';
      n.children = [];
    }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return n._text || ''; },
    set(v){
      n._text = v;
      n.children.forEach(function(c){ c.parentNode = null; });
      // Vyprázdnenie `<select>` v prehliadači ZAHODÍ aj jeho hodnotu (options
      // zmizli, nie je čo vybrať). Bez tejto vernosti by test na zachovanie
      // rozpísanej kategórie (P1) nič nestrážil — hodnota by „prežila" aj bez
      // `keep` v `mdhRenderEnums`.
      if (n.children.length) n.value = '';
      n.children = [];
      n.clears = (n.clears || 0) + 1;   // ŠT-3a-3: počítadlo prekreslení bloku
    }
  });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  // Obnova fokusu po prekreslení hľadá uzol selektorom — test si ho podstrkuáva.
  n.querySelector = function(sel){ n.lastSel = sel; return n.queryHit || null; };
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
          // DVE hodnoty v každom zozname — s jedinou by sa nedalo rozlíšiť
          // „zachoval pôvodnú" od „nastavil prvú" (review NOTE k #218 P1).
          catalog: { version: '0.7.58', categories: ['závesy', 'výsuvy'],
                     units: ['ks', 'pár'],
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

  // Review #218 P1: neprežiť MUSÍ len uzol, ale aj HODNOTA v ňom. `hwRenderBody`
  // volá `mdhRenderEnums` pri KAŽDOM plnom pushi a ten `<select>` kategórie
  // prestavia — bez zachovania hodnoty by sa rozpísanej novej položke ticho
  // prepla kategória na PRVÚ v zozname a používateľ by to zistil až po uložení.
  eq(ELS.hn_category.children.length, 2, 'select kategórie sa naplnil z katalógu');
  eq(ELS.hn_unit.children.length, 2, 'a select MJ tiež');
  // DRUHÁ hodnota v oboch zoznamoch: keby sa testálo prvou, „zachoval"
  // a „nastavil prvú" by vyzerali rovnako a guard by nestrážil nič.
  ELS.hn_category.value = 'výsuvy';         // používateľ vybral kategóriu
  ELS.hn_unit.value = 'pár';               // a mernú jednotku
  global.NX.setStudio(payload);              // medzitým príde plný push zo servera
  H.hwRenderBody();
  eq(ELS.hn_category.value, 'výsuvy',
     'rozpísaná kategória PREŽILA push (mdhRenderEnums ju nesmie prepnúť na prvú)');
  eq(ELS.hn_unit.value, 'pár',
     'ŠT-3a-3: a MJ tiež — je to údaj, ktorý ide rovno do objednávky');
  ELS.hn_category.value = '';
  ELS.hn_unit.value = '';
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
  // Review P2 #4 + kolo 2 P2-2: náhľad z Demosu NIE JE modál — žije v tele
  // sekcie, ktoré sa pri odchode UCHOVÁ. Nedokončený beh sa zhodiť MUSÍ (inak
  // v ňom navždy visí „Načítavam stránku…", hoci server beh už zrušil), ale
  // DOKONČENÝ náhľad zhodiť NESMIE: serverový proposal (`pid`) žije ďalej
  // a používateľ v ňom môže mať rozpísanú kategóriu a poznámku.
  const leaveFn = fs.readFileSync(path.join(JS, 'hw_catalog.js'), 'utf8')
    .match(/function hwCloseModals\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/MDH_DEMOS && MDH_DEMOS\.status === 'pending'/.test(leaveFn),
     'zhadzuje sa LEN nedokončený beh');
  const guarded = leaveFn.slice(leaveFn.indexOf("=== 'pending'"));
  ok(/MDH_DEMOS = null/.test(guarded) && /mdhRenderDemosPreview\(\)/.test(guarded),
     'reset aj prekreslenie sú POD tou podmienkou, nie pred ňou');
  ok(!/MDH_DEMOS = null/.test(leaveFn.slice(0, leaveFn.indexOf("=== 'pending'"))),
     'a mimo nej sa náhľad nezahadzuje (rozpísané polia by prišli nazmar)');
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

// --- 7) predvoľby projektu sú v sekcii PLNOHODNOTNÉ (ŠT-3a-2) ---------------

(function(){
  // ŠT-3a-2: read-only režim zanikol — tri modelové zápisy sú v `SECTION_ACTIONS`,
  // takže sekcia kreslí rovnaké ovládacie prvky ako kedysi okno.
  const HWS = require(path.join(JS, 'hw_sets.js'));
  eq(typeof HWS.hwsSetProjReadOnly, 'undefined',
     'prepínač read-only režimu už neexistuje');
  eq(typeof HWS.hwsMappingValueText, 'undefined',
     'a ani čítateľný výpis hodnoty bez ovládača (riadok kreslí select)');
  // Čisté funkcie, na ktorých stojí zápis mapovania, musia žiť ďalej.
  eq(typeof HWS.hwsBuildSelector, 'function', 'stavač selektora pásiem žije');
  eq(typeof HWS.hwsProjDraftKeys, 'function',
     'a rozpísané PROJEKTOVÉ pásma sa dajú zahodiť pri prepnutí dokumentu');
  eq(HWS.hwsProjDraftKeys(['hws-map-proj|slide', 'hws-map-global|hinge']),
     ['hws-map-proj|slide'],
     'globálne drafty na modeli nezávisia — tie sa NEZAHADZUJÚ');
})();

// --- 8) zdrojáky: kontrakty, ktoré sa dajú overiť len čítaním ---------------

(function(){
  const src = fs.readFileSync(path.join(JS, 'hw_catalog.js'), 'utf8');
  const sets = fs.readFileSync(path.join(JS, 'hw_sets.js'), 'utf8');
  const studio = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');

  // ŠT-3a-2 (F6): okno zaniklo, takže `ready` už nemá druhého odosielateľa —
  // v Štúdiu ho posiela `studio.js` (`window.onload`) a druhé volanie by
  // prinútilo okno poslať celý payload dvakrát.
  ok(!/^[^/\n]*\bsketchup\.ready\(/m.test(src),
     '`ready` sa z tohto súboru už NEPOSIELA (vzor proj_materials.js po ŠT-2b)');
  ok(!fs.existsSync(path.join(JS, '..', 'hardware_catalog.html')),
     'hardware_catalog.html je zmazaný (dve UI nad jedným katalógom by sa rozišli)');

  ok(studio.indexOf('js/studio.js') < studio.indexOf('js/hw_catalog.js'),
     'hw_catalog.js sa načítava AŽ ZA studio.js (obaľuje jeho NX.setStudio)');
  ok(studio.indexOf('js/hw_sets.js') < studio.indexOf('js/hw_catalog.js'),
     'a hw_sets.js pred ním (detail setu volá jeho funkcie)');
  ok(studio.indexOf('NX_HW_SECTION') < studio.indexOf('js/hw_catalog.js'),
     'príznak sekcie ostáva ako čítateľné prihlásenie sa do režimu sekcie');

  // Modelové zápisy sú v sekcii živé: blok „Predvoľby projektu" kreslí
  // ovládače bez akéhokoľvek režimu a premostenie nemá kam viesť.
  // ŠT-3a-3: telo sa presťahovalo do `hwsRenderProjBody` (obal drží snapshot
  // fokusu), takže kontrolujeme telo — nie obal.
  const projFn = sets.match(/function hwsRenderProjBody\(box\)\{[\s\S]*?\n  \}/)[0];
  ok(!/HWS_PROJ_RO/.test(projFn), 'blok už žiadny read-only režim nepozná');
  ok(/hws-merge-seed/.test(projFn) && /hws-reset-proj/.test(projFn),
     'a kreslí OBE zapisovacie akcie priamo');
  ok(!/hws-open-window/.test(sets), 'premostenie do okna zaniklo spolu s ním');
  ok(!/function hwsSetTab/.test(sets), 'prepínač tabov OKNA tiež');
})();

// --- 9) ŠT-3a-3: JEDEN render setov na push (nie dva) ----------------------

(function(){
  const HWS = require(path.join(JS, 'hw_sets.js'));
  const sets = { sets: [], global_mapping: {}, revision: 'r1', type_options: {},
                 params: [], project: { status: 'missing', mapping: {}, sets: [] },
                 generic_types: [{ key: 'hinge', label: 'Z\u00e1vesy' }],
                 model_guid: 'G1', model_title: 'test' };

  ELS.hwTabSets.clears = 0;
  ELS.hwTabProj.clears = 0;
  HWS.HWSETS.setData(sets);
  eq(ELS.hwTabSets.clears, 0,
     '`setData` NEKRESL\u00cd \u2014 telo sekcie kresl\u00ed `hwRenderBody` hne\u010f za n\u00edm');
  eq(ELS.hwTabProj.clears, 0, 'a predvo\u013eby projektu tie\u017e nie');

  HWS.HWSETS.render();
  eq(ELS.hwTabSets.clears, 1, '`render` prekresl\u00ed zoznam setov PR\u00c1VE RAZ');
  eq(ELS.hwTabProj.clears, 1, 'a predvo\u013eby projektu tie\u017e');

  // `init` (data + render) ost\u00e1va pre ECHO, po ktorom u\u017e \u017eiadny render nepr\u00edde.
  ELS.hwTabSets.clears = 0;
  HWS.HWSETS.init(sets);
  eq(ELS.hwTabSets.clears, 1, '`init` (echo po odmietnutom z\u00e1pise) kresl\u00ed sam');

  // Zdroj\u00e1k: pln\u00fd push MUS\u00cd \u00eds\u0165 cez `setData`, inak sa kresl\u00ed dvakr\u00e1t.
  const src = fs.readFileSync(path.join(JS, 'hw_catalog.js'), 'utf8');
  const applyFn = src.match(/function hwApplyState\(h\)\{[\s\S]*?\n  \}/)[0];
  ok(/HWSETS\.setData\(h\.sets\)/.test(applyFn),
     'pln\u00fd push nastav\u00ed len D\u00c1TA (render rob\u00ed telo sekcie)');
  ok(!/HWSETS\.init\(/.test(applyFn), 'a NEVOL\u00c1 `init` \u2014 to by bol druh\u00fd render');
})();

// --- 10) ŠT-3a-3: kurzor v editore setu prežije prekreslenie -----------------

(function(){
  const HWS = require(path.join(JS, 'hw_sets.js'));
  // \u010cist\u00e1 \u010das\u0165: selektor mus\u00ed by\u0165 JEDNOZNA\u010cN\u00dd \u2014 ch\u00fdbaj\u00faci atrib\u00fat je s\u00fa\u010das\u0165ou
  // identity (`:not([...])`), inak by sa fokus z po\u013ea \u010dlena vr\u00e1til do rovnomenn\u00e9ho
  // po\u013ea v riadku radu NL.
  const selA = HWS.hwsFocusSelector({ field: 'code', at: { 'data-hws-m': '0', 'data-hws-s': null,
                                                           'data-hws-b': null, 'data-hws-sel': null } });
  ok(selA.indexOf('[data-hws-field="code"]') === 0, 'selektor za\u010d\u00edna po\u013eom');
  ok(selA.indexOf('[data-hws-m="0"]') > 0, 'nesie index \u010dlena');
  ok(selA.indexOf(':not([data-hws-s])') > 0, 'a ch\u00fdbaj\u00face atrib\u00faty PRIZN\u00c1VA ako s\u00fa\u010das\u0165 identity');
  ok(HWS.hwsCssEscape('hws-map-proj|hinge').indexOf('\\|') > 0,
     'k\u013e\u00fa\u010d s `|` ide do selektora ESCAPOVAN\u00dd (inak by ho rozbil)');

  // Spr\u00e1vanie: pri prekreslen\u00ed sa fokus vr\u00e1ti do uzla, ktor\u00fd selektor n\u00e1jde.
  const live = stubEl('hwsInput');
  live.setAttribute('data-hws-field', 'code');
  live.setAttribute('data-hws-m', '0');
  live.selectionStart = 2;
  live.selectionEnd = 2;
  const fresh = stubEl('hwsInputFresh');
  ELS.hwTabSets.queryHit = fresh;
  document.activeElement = live;
  HWS.HWSETS.render();
  ok(fresh._focused === true,
     'po prekreslen\u00ed sa fokus vr\u00e1til do rozp\u00edsan\u00e9ho po\u013ea (kurzor nepresko\u010d\u00ed)');
  ok(String(ELS.hwTabSets.lastSel).indexOf('data-hws-m="0"') > 0,
     'a h\u013eadal sa PR\u00c1VE ten uzol, v ktorom pou\u017e\u00edvate\u013e p\u00edsal');
  document.activeElement = null;
  ELS.hwTabSets.queryHit = null;
})();

// --- 11) ŠT-3a-3: filter po založení položky (jedna pravda) ------------------

(function(){
  // Pou\u017e\u00edvate\u013e nap\u00ed\u0161e do h\u013eadania a vyberie kateg\u00f3riu \u2014 cez DELEGOVAN\u00c9
  // listenery, presne ako v prehliada\u010di.
  // Na `document` visia listenery VIACERYCH suborov (studio.js, hw_catalog.js,
  // hw_sets.js) — event dostane KAZDY, presne ako v prehliadaci.
  const fire = function(type, target){ (LISTEN[type] || []).forEach(function(fn){ fn({ target: target }); }); };
  ok((LISTEN.input || []).length > 0 && (LISTEN.change || []).length > 0,
     'delegovan\u00e9 listenery s\u00fa zaregistrovan\u00e9');
  fire('input', { id: 'hwSearch', value: 'blum' });
  fire('change', { id: 'hwCategory', value: 'z\u00e1vesy', tagName: 'SELECT',
                   getAttribute: function(){ return null; }, hasAttribute: function(){ return false; } });
  eq(H.hwToolsState(false).q, 'blum', 'h\u013eadanie \u017eije aj v premennej (li\u0161tu prekresl\u00ed ka\u017ed\u00fd push)');
  eq(H.hwToolsState(false).cat, 'z\u00e1vesy', 'a filter kateg\u00f3rie tie\u017e');

  H.MDH.created();
  eq(H.hwToolsState(false).q, '',
     'zalo\u017eenie polo\u017eky vy\u010dist\u00ed h\u013eadanie aj v PREMENNEJ (nov\u00e1 polo\u017eka mus\u00ed by\u0165 vidie\u0165)');
  eq(H.hwToolsState(false).cat, '', 'a filter kateg\u00f3rie tie\u017e \u2014 jedna pravda s uzlom li\u0161ty');
})();

// --- 12) ŠT-3a-3: zhody Demosu sa dorovnajú pri NÁVRATE do sekcie -----------

(function(){
  const src = fs.readFileSync(path.join(JS, 'hw_catalog.js'), 'utf8');
  const bodyFn = src.match(/function hwRenderBody\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/var entered = node\.parentNode !== box/.test(bodyFn),
     'render tela rozli\u0161uje VSTUP do sekcie od be\u017en\u00e9ho pushu');
  const demosCall = bodyFn.match(/if \(entered[^;]*\) mdhDemosInput\(\);/);
  ok(!!demosCall,
     'zhody \u201ePrida\u0165 z Demosu\u201c sa dorovnaj\u00fa LEN pri n\u00e1vrate do sekcie');
  // Review #219 P2-2: a LEN ked je pole naozaj VIDIET \u2014 dopyt do Demosu za
  // skryte pole (pohlad Sety, zavrety formular novej polozky) by isiel za nic.
  ok(/HW_VIEW !== 'sets'/.test(demosCall[0]), 'v poh\u013eade Sety sa nedopytuje');
  ok(/hwNewFormOpen\(\)/.test(demosCall[0]),
     'ani pri zavretom formul\u00e1ri novej polo\u017eky');
  ok(bodyFn.indexOf(demosCall[0]) > bodyFn.indexOf('MDH_ORDER_PENDING'),
     'a\u017e za vy\u017eiadan\u00edm serverov\u00e9ho poradia \u2014 nie namiesto neho');
  // Naplanovany (debounced) dopyt MUSI zomriet s odchodom \u2014 inak dobehne do
  // opustenej sekcie a najblizsi odchod vypise falosne \u201eZru\u0161en\u00e9\u2026\u201c.
  const leaveFn2 = src.match(/function hwOnLeaveSection\(\)\{[\s\S]*?\n  \}/)[0];
  ok(/clearTimeout\(mdhDemosTimer\)/.test(leaveFn2),
     'odchod zo sekcie ru\u0161\u00ed aj napl\u00e1novan\u00fd dopyt do Demosu');
})();


// --- TEST-1: OREZANÝ zoznam a PRÁVE ZALOŽENÁ položka (DOM, nie grep) --------
// Nález z prvého testu v0.8.0: základný zoznam je serverový search s prázdnym
// dotazom a stropom. Nová položka má `use_count` 0, takže vypadne za strop
// a z UI zmizne BEZ SLOVA — Michal ju po pridaní nenašiel. Overuje sa preto
// SPRÁVANIE renderu: hint o orezaní naozaj pribudne do zoznamu a nový riadok
// je vizuálne odlíšený.
(function(){
  function listNode(){ return ELS.hwList; }
  function texts(node){
    return (node.children || []).map(function(c){ return c._text || ''; }).join(' | ');
  }
  function classes(node){
    return (node.children || []).map(function(c){ return c.className || ''; });
  }

  const items = [];
  for (let i = 1; i <= 3; i++){
    items.push({ item_code: 'OLD' + i, name_sk: 'Stará ' + i, category: 'ZAVES',
                 unit: 'ks', active: true, use_count: 10 });
  }
  items.push({ item_code: 'NOVA001', name_sk: 'Úplne nová', category: 'ZAVES',
               unit: 'ks', active: true, use_count: 0 });
  H.MDH.setItems({ items: items, state: 'ok', categories: ['ZAVES'], units: ['ks'] });

  // (1) Server poslal LEN 3 zo 137 zhôd — orezanie MUSÍ byť vidieť.
  H.MDH.results({ codes: ['OLD1', 'OLD2', 'OLD3'], query: '', total: 137, shown: 3, pin: '' });
  ok(texts(listNode()).indexOf('Zobrazených 3 z 137') > -1,
     'orezaný zoznam sa PRIZNÁ číslom priamo v zozname');
  ok(classes(listNode()).some(function(c){ return c.indexOf('hwcap') > -1; }),
     'a má vlastnú triedu (dá sa odlíšiť od položiek)');

  // (2) Nič sa neorezalo = žiadny šum.
  H.MDH.results({ codes: ['OLD1', 'OLD2', 'OLD3'], query: '', total: 3, shown: 3, pin: '' });
  ok(texts(listNode()).indexOf('Zobrazených') < 0, 'bez orezania sa NIČ nevypisuje');

  // (3) Práve založená položka: server ju dal navrch a klient ju ZVÝRAZNÍ.
  H.MDH.results({ codes: ['NOVA001', 'OLD1', 'OLD2'], query: '', total: 4, shown: 3,
                  pin: 'NOVA001' });
  const cls = classes(listNode());
  ok((cls[0] || '').indexOf('hwnew') > -1, 'prvý riadok (nová položka) je zvýraznený');
  ok(cls.filter(function(c){ return c.indexOf('hwnew') > -1; }).length === 1,
     'a je zvýraznený PRÁVE JEDEN riadok');
  ok(texts(listNode()).indexOf('Zobrazených 3 z 4') > -1,
     'a orezanie sa priznáva aj vtedy, keď je navrchu nová položka');

  // (4) Bez pinu sa nezvýrazňuje nič — zvýraznenie je udalosť, nie stav zoznamu.
  H.MDH.results({ codes: ['NOVA001', 'OLD1'], query: '', total: 2, shown: 2, pin: '' });
  ok(classes(listNode()).every(function(c){ return c.indexOf('hwnew') < 0; }),
     'po ďalšom hľadaní zvýraznenie zhasne');

  // (5) Klient pri hľadaní posiela `pin` serveru — poradie skladá SERVER.
  SENT.length = 0;
  H.MDH.created('NOVA001');
  const search = SENT.filter(function(x){ return x[0] === 'hw_search'; });
  ok(search.length > 0, 'po založení si klient vypýta čerstvý zoznam');
  ok(JSON.parse(search[search.length - 1][1]).pin === 'NOVA001',
     'a povie serveru, ktorú položku má dať navrch (JS si poradie nedopĺňa sám)');

  // (6) review #229 P2: žiadosť je JEDNORAZOVÁ. Bez toho by sa `pin` posielal
  // pri KAŽDOM ďalšom hľadaní a nesúvisiaci dotaz (iný text, iná kategória,
  // prepnuté neaktívne) by novú položku ďalej ťahal navrch a zvýrazňoval —
  // až do znovuotvorenia okna.
  SENT.length = 0;
  // Používateľ prepne filter — cez DELEGOVANÝ listener, presne ako v
  // prehliadači (kategória aj „neaktívne" idú na server HNEĎ, bez debounce).
  const fireChange = function(target){ (LISTEN.change || []).forEach(function(fn){ fn({ target: target }); }); };
  fireChange({ id: 'hwInactive', checked: true, tagName: 'INPUT', type: 'checkbox',
               getAttribute: function(){ return null; }, hasAttribute: function(){ return false; } });
  const second = SENT.filter(function(x){ return x[0] === 'hw_search'; });
  ok(second.length >= 1, 'zmena filtra poslala nové hľadanie');
  eq(JSON.parse(second[second.length - 1][1]).pin, '',
     'ale UŽ BEZ žiadosti o pin — nesúvisiaci dotaz novú položku navrch neťahá (je jednorazová)');

  // (7) a keď server pin nepotvrdí, zvýraznenie zhasne aj v zozname.
  H.MDH.results({ codes: ['NOVA001', 'OLD1'], query: 'nieco ine', total: 2, shown: 2, pin: '' });
  ok(classes(listNode()).every(function(c){ return c.indexOf('hwnew') < 0; }),
     'nesúvisiaci dotaz už nič nezvýrazňuje');
})();

console.log(`OK ${n} kontrol (ŠT-3a sekcia Kovanie)`);
