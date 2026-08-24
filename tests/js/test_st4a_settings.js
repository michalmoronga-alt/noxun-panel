// ŠT-4a — sekcie NASTAVENIA (`sup` · `bset` · `about`) v okne Štúdio (klient).
//
// Prečo sú to testy a nie klikanie:
//   1. Plný push chodí pri KAŽDEJ zmene modelu. Rozpísané sadzby ho musia
//      prežiť — inak by zmizli uprostred písania a nikto by nevedel prečo.
//      (V zaniknutom okne push chodil len pri otvorení a po uložení, takže
//      pôvodné „init = reset formulára" by tu ticho zahadzovalo prácu.)
//   2. Do zdieľaných uzlov `#secbody`/`#sectools` smie kresliť LEN otvorená
//      sekcia (lekcia review #225 P1) — inak rozpísaný formulár prepíše
//      napríklad Rozpočet.
//   3. Patch nesie LEN zmenené polia (server nesmie dostať dokument, ktorý
//      klient nevidel) a prázdna REŽIMOVÁ hodnota znamená „zmaž", nie nula.
//   4. „O plugine" je jeden obsah s dvoma vstupmi — markup musí stavať
//      zdieľaný builder, nie kópia v každom okne.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_st3c_tpl.js) -------------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], _html: '', _attrs: {}, value: '', className: '' };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; n.children = []; }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return n._text || ''; },
    set(v){ n._text = v; }
  });
  n.appendChild = function(c){
    n.children.push(c);
    n._html += (c && c.outerText) ? c.outerText : '';
    return c;
  };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  n.classList = { toggle: function(){} };
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
const LISTEN = { input: [], click: [] };
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
global.NX = global.window.NX;
const A = require(path.join(JS, 'about.js'));
const T = require(path.join(JS, 'studio_settings.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const STATE = {
  version: '9.9.9',
  revision: 'r-1',
  supplier: { name: 'Demos', rates: { montaz: 12 }, mode_values: { montaz: { nizky: 9 } },
              stale_days: 30, rounding_step: 5, abs_reserve_pct: 10,
              montaz_m2_per_plate: 3, cp_highlight_threshold: 100 },
  modes: ['nizky', 'standard', 'vysoky'],
  mode_labels: { nizky: 'Nízky', standard: 'Štandard', vysoky: 'Vysoký' },
  rate_keys: ['montaz'],
  rate_labels: { montaz: ['Montáž', '€/m²'] },
  standard_rows: [{ key: 'doprava', name: 'Doprava', rate: 30, kind: 'fix' }],
  path: 'C:\\APPDATA\\NOXUN\\Engine\\supplier_settings.json',
  demos: { crawl_delay_s: 3, stale_days: 30 },
  about: { version: '9.9.9', dir: 'C:\\APPDATA\\NOXUN\\Engine' }
};

// --- 1) patch: LEN zmenené polia --------------------------------------------

(function(){
  const r = T.ssBuildPatch({ 'rate:montaz': '13,5', 'scalar:stale_days': '45' });
  eq(r.errors, [], 'platné hodnoty nemajú chybu');
  eq(r.patch, { rates: { montaz: 13.5 }, stale_days: 45 },
     'patch nesie LEN to, čo používateľ zmenil (server nesmie dostať, čo klient nevidel)');

  const del = T.ssBuildPatch({ 'mode:montaz:vysoky': '' });
  eq(del.patch, { mode_values: { montaz: { vysoky: null } } },
     'prázdna REŽIMOVÁ hodnota = „zmaž, použi základnú sadzbu" (null, NIKDY nula)');

  const bad = T.ssBuildPatch({ 'rate:montaz': 'x' });
  ok(bad.errors.length === 1, 'nečíslo je chyba…');
  eq(bad.patch, {}, '…a NIČ sa neposiela');

  const empty = T.ssBuildPatch({ 'rate:montaz': '' });
  ok(empty.errors.length === 1, 'prázdna SADZBA je chyba (na rozdiel od režimovej)');

  eq(T.ssNumText(0.9), '0,9', 'číslo do formulára s desatinnou čiarkou');
  eq(T.ssNumText(null), '', 'nezadané ostáva PRÁZDNE (nikdy nula)');
  eq(T.ssParse('17,00'), 17, 'čiarka aj desatinné nuly');
})();

// --- 2) kreslenie LEN do otvorenej sekcie ------------------------------------

(function(){
  T.ssApplyState(STATE);

  S.setStudioSection('budget');
  ELS.secbody.innerHTML = 'ROZPÍSANÝ ROZPOČET';
  ELS.sectools.innerHTML = 'LIŠTA ROZPOČTU';
  T.ssApplyState(STATE);
  eq(ELS.secbody.innerHTML, 'ROZPÍSANÝ ROZPOČET',
     'push nastavení NEPREPÍŠE telo cudzej sekcie (zdieľaný uzol)');
  eq(ELS.sectools.innerHTML, 'LIŠTA ROZPOČTU', 'ani jej lištu');
  ok(T.ssActive() === null, 'a sekcia o sebe vie, že otvorená nie je');

  S.setStudioSection('bset');
  ok(T.ssActive() === 'bset', 'v otvorenej sekcii sa kreslí');
  S.setStudioSection('about');
  ok(T.ssActive() === 'about', 'to isté pre „O plugine"');
  S.setStudioSection('bom');
  ok(T.ssActive() === null, 'Kusovník nastaveniam nepatrí');
})();

// --- 3) lišta: ukladá LEN `bset` ---------------------------------------------

(function(){
  const bset = T.ssToolsHtml('bset');
  ok(/data-action="ss-save"/.test(bset), 'Nastavenia rozpočtu majú „Uložiť"');
  ok(/data-action="ss-reload"/.test(bset), 'aj „Načítať nanovo"');
  eq(T.ssToolsHtml('sup'), '', 'Dodávateľ / Demos je ČÍTANIE — prázdna lišta (D-78)');
  eq(T.ssToolsHtml('about'), '', 'a „O plugine" tiež');
})();

// --- 4) odoslanie + ROZPÍSANÉ hodnoty prežijú push ---------------------------

(function(){
  // Rozpísanie sa deje cez delegovaný `input` listener — stub ho zachytil pri
  // načítaní súboru, takže sa dá vyvolať presne to, čo robí písanie do poľa.
  function type(key, value){
    const t = { getAttribute: function(k){ return k === 'data-ss' ? key : null; },
                value: value, classList: { toggle: function(){} } };
    LISTEN.input.forEach(function(fn){ fn({ target: t }); });
  }

  S.setStudioSection('bset');
  T.ssApplyState(STATE);
  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 0, 'bez zmien sa NIČ neposiela (server nedostane prázdny patch)');

  type('rate:montaz', '15');
  // Plný push chodí pri KAŽDEJ zmene modelu — rozpísané ho musí prežiť.
  T.ssApplyState(STATE);
  T.ssApplyState(STATE);
  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 1, 'rozpísaná sadzba PREŽILA dva plné pushe a odoslala sa');
  eq(SENT[0][0], 'ss_save', 'ide to prefixovanou akciou sekcie');
  const p1 = JSON.parse(SENT[0][1]);
  eq(p1.revision, 'r-1', 'so ZNÁMOU baseline revíziou (optimistický zámok)');
  eq(p1.patch, { rates: { montaz: 15 } }, 'a LEN so zmeneným poľom');

  // POTVRDENIE zo servera je JEDINÉ miesto, kde rozpísané zaniká.
  T.SS.saved();
  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 0, 'po potvrdení servera už nie je čo posielať');

  // „Načítať nanovo" zahadzuje rozpísané HNEĎ (je to jeho jediný zmysel).
  type('rate:montaz', '19');
  SENT.length = 0;
  T.ssReload();
  eq(SENT[0][0], 'ss_reload', 'reload ide na server');
  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 0, 'a rozpísané je preč');
})();

// --- 5) „O plugine": jeden obsah, dva vstupy ---------------------------------

(function(){
  const html = A.nxAboutHtml({ version: '9.9.9', dir: 'C:\\X\\Y' });
  ok(html.indexOf('V9.9.9') > -1, 'verzia ide zo SERVERA (žiadny hardcode v HTML)');
  ok(html.indexOf('C:\\X\\Y') > -1, 'aj priečinok nastavení');
  ok(html.indexOf('id="cfgVersion"') > -1,
     'uzol verzie si drží meno z kolieska — je to TEN ISTÝ obsah');
  const fallback = A.nxAboutHtml(null);
  ok(fallback.indexOf('%APPDATA%') > -1,
     'bez dát obsah NEZMIZNE — padne na kontraktovú cestu');
  const esc = A.nxAboutHtml({ version: '<img src=x>', dir: '<b>' });
  ok(esc.indexOf('<img src=x>') < 0 && esc.indexOf('&lt;img') > -1, 'hodnoty sú escapované');
})();

// --- 6) kolízie globálov -----------------------------------------------------

(function(){
  const fs = require('node:fs');
  const files = ['studio.js', 'budget.js', 'proj_materials.js', 'nx_modal.js',
                 'edge_menu.js', 'demos_diff.js', 'demos_add.js', 'hw_catalog.js',
                 'hw_sets.js', 'rules.js', 'templates.js', 'studio_settings.js', 'about.js'];
  const names = {};
  files.forEach(function(f){
    const src = fs.readFileSync(path.join(JS, f), 'utf8');
    const set = new Set();
    const re = /^ {0,2}(?:function\s+(\w+)|var\s+(\w+))/gm;
    let m;
    while ((m = re.exec(src)) !== null) set.add(m[1] || m[2]);
    names[f] = set;
  });
  ok(names['studio_settings.js'].size > 12, 'zoznam mien sa naozaj načítal');
  files.forEach(function(a){
    files.forEach(function(b){
      if (a >= b) return;
      const clash = [...names[a]].filter(function(x){ return names[b].has(x); });
      eq(clash, [], `js/${a} a js/${b} nesmú zdieľať globálne meno`);
    });
  });
})();

console.log(`OK ${n} kontrol (ŠT-4a sekcie Nastavenia)`);
