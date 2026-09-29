// NP-2 (blok 2 · Nárezový plán) — Nastavenia rozpočtu: prerez, orez a prídavok
// dupláku (klient) + riadok Kontroly „nastavenia sa nenačítali".
//
// Prečo sú to testy:
//   1. Tri nové riadky stoja PRESNE tam, kde ich ukazuje mockup D (medzi
//      „m² na platňu" a „Zaokrúhlenie"), s tooltipom „?" a desatinnou klávesnicou.
//   2. Klient pole mimo rozsahu ZČERVENÍ a „Uložiť" povie dôvod ľudsky — rozsahy
//      berie zo servera (`scalar_ranges`), server ostáva autoritou.
//   3. Súbor z novšieho pluginu / poškodený súbor = banner hneď po otvorení
//      a „Uložiť" s `aria-disabled` + dôvodom (nie až chyba pri uložení).
//   4. Nález Kontroly o nenačítaných nastaveniach vedie do Nastavení rozpočtu.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// --- DOM stub so stromom (deti, atribúty, triedy) ---------------------------
const ELS = {};
function mkEl(tag, id){
  const n = { tagName: String(tag || 'div').toUpperCase(), id: id || '', style: {}, children: [],
              _html: '', _attrs: {}, _classes: {}, value: '', type: '' };
  Object.defineProperty(n, 'className', {
    get(){ return Object.keys(n._classes).filter(function(k){ return n._classes[k]; }).join(' '); },
    set(v){ n._classes = {}; String(v || '').split(/\s+/).filter(Boolean).forEach(function(c){ n._classes[c] = true; }); }
  });
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = String(v); n.children = []; }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return (n._text || '') + n.children.map(function(c){ return c.textContent; }).join(''); },
    set(v){ n._text = String(v); n.children = []; }
  });
  n.appendChild = function(c){ n.children.push(c); return c; };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.removeAttribute = function(k){ delete n._attrs[k]; };
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  n.classList = {
    toggle: function(c, on){ n._classes[c] = (on === undefined) ? !n._classes[c] : !!on; return n._classes[c]; },
    contains: function(c){ return !!n._classes[c]; }
  };
  return n;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio'].forEach(function(id){ ELS[id] = mkEl('div', id); });

function walk(n, fn){ fn(n); (n.children || []).forEach(function(c){ walk(c, fn); }); }
function findAll(root, pred){ const out = []; walk(root, function(x){ if (pred(x)) out.push(x); }); return out; }

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
const LISTEN = { input: [], click: [], focusin: [] };
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return mkEl(tag); },
  querySelector: function(){ return null; },
  querySelectorAll: function(){ return []; }
};
global.NXIcons = { svg: function(id){ return '<svg class="ic"><use href="#i-' + id + '"/></svg>'; } };

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const T = require(path.join(JS, 'studio_settings.js'));
global.ssRenderBody = T.ssRenderBody;
global.ssRenderTools = T.ssRenderTools;

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const RANGES = { abs_reserve_pct: [0, 100], montaz_m2_per_plate: [0.1, 100], rounding_step: [0.01, 1000],
                 cp_highlight_threshold: [0, 1000000], kerf_mm: [0, 10], trim_mm: [0, 50],
                 dup_allowance_mm: [0, 30], stale_days: [1, 3650] };

function state(over){
  return Object.assign({
    version: '9.9.9', revision: 'r-1',
    supplier: { name: 'Noxun', rates: {}, mode_values: {}, stale_days: 30, rounding_step: 1,
                abs_reserve_pct: 10, montaz_m2_per_plate: 5.8, cp_highlight_threshold: 150,
                kerf_mm: 5, trim_mm: 10, dup_allowance_mm: 10 },
    modes: ['nizky', 'standard', 'vysoky'], rate_keys: [], rate_labels: {}, standard_rows: [],
    path: 'C:\\X\\supplier_settings.json', demos: {}, about: { version: '9.9.9' },
    settings_state: { state: 'ok', reason: '' }, scalar_ranges: RANGES
  }, over || {});
}

// --- 1) tri nové riadky na mieste z mockupu D, tooltip, inputmode ------------

(function(){
  const keys = T.SS_SCALARS.map(function(s){ return s[0]; });
  eq(keys, ['abs_reserve_pct', 'montaz_m2_per_plate', 'kerf_mm', 'trim_mm', 'dup_allowance_mm',
            'rounding_step', 'stale_days', 'cp_highlight_threshold'],
     'prerez, orez a prídavok stoja medzi „m² na platňu" a „Zaokrúhlenie" (mockup D)');
  eq(T.SS_SCALARS[2][1], 'Prerez píly (hrúbka kotúča)');
  eq(T.SS_SCALARS[3][1], 'Orez okraja platne');
  eq(T.SS_SCALARS[4][1], 'Prídavok dupláku na stranu');
  ok(/nárezový plán/.test(T.SS_SCALARS[2][3]), 'prerez: tooltip nezamlčí, že ho zatiaľ použije len plán');
  ok(/Pracovná doska .*neorezávajú/.test(T.SS_SCALARS[3][3]), 'orez: PD, kompakt a zástena bez orezu');
  ok(/Kontrola/.test(T.SS_SCALARS[3][3]), 'orez: počíta s ním Kontrola');
  ok(/každú vrstvu/.test(T.SS_SCALARS[4][3]), 'prídavok: každá vrstva dupláku');

  S.setStudioSection('bset');
  T.ssApplyState(state());
  const inputs = findAll(ELS.secbody, function(x){ return x.tagName === 'INPUT'; });
  const scal = inputs.filter(function(i){ return /^scalar:/.test(i.getAttribute('data-ss') || ''); });
  eq(scal.map(function(i){ return i.getAttribute('data-ss'); }),
     keys.map(function(k){ return 'scalar:' + k; }), 'riadky sa vykreslia v tom istom poradí');
  ok(scal.every(function(i){ return i.getAttribute('inputmode') === 'decimal'; }), 'inputmode="decimal"');
  eq(scal[2].value, '5', 'prerez 5 mm z payloadu');
  const tips = findAll(ELS.secbody, function(x){ return x.classList && x.classList.contains('nxtip'); });
  eq(tips.length, 3, 'tooltip „?" majú práve tri nové riadky');
  ok(tips.every(function(t){ return t.tagName === 'BUTTON' && t.type === 'button'; }), 'tooltip je tlačidlo (fokus z klávesnice)');
  ok(tips.every(function(t){ return t.getAttribute('aria-label') === 'Pomoc' && !!t.getAttribute('data-tip'); }),
     'text v data-tip (nie natívny title)');
  ok(/help-circle/.test(tips[0].innerHTML), 'ikona zo spritu, žiadne emoji');
})();

// --- 2) klientska kontrola rozsahu ------------------------------------------

(function(){
  eq(T.ssRangeError('kerf_mm', 10, RANGES), null, 'max prejde');
  eq(T.ssRangeError('kerf_mm', 0, RANGES), null, '0 prejde');
  eq(T.ssRangeError('kerf_mm', 10.01, RANGES), 'Prerez píly (hrúbka kotúča): hodnota mimo rozsahu 0–10 mm');
  eq(T.ssRangeError('trim_mm', -1, RANGES), 'Orez okraja platne: hodnota mimo rozsahu 0–50 mm');
  ok(T.ssRangeError('dup_allowance_mm', Infinity, RANGES) !== null, 'Infinity je mimo rozsahu');
  eq(T.ssRangeError('rounding_step', 0, RANGES), 'Zaokrúhlenie ponuky nahor na: hodnota mimo rozsahu 0,01–1000 €');

  ok(T.ssFieldBad('scalar:kerf_mm', '11', RANGES), 'mimo rozsahu = červené pole');
  ok(!T.ssFieldBad('scalar:kerf_mm', '4,4', RANGES), '4,4 s čiarkou je v poriadku');
  ok(!T.ssFieldBad('scalar:kerf_mm', '4.4', RANGES), 'aj s bodkou');
  ok(T.ssFieldBad('scalar:trim_mm', 'abc', RANGES), 'nečíslo červené (dnešné pravidlo)');
  ok(T.ssFieldBad('rate:olep', 'x', RANGES), 'nečíslo aj v sadzbe');
  ok(!T.ssFieldBad('rate:olep', '99999', RANGES), 'sadzby klient rozsahom nekontroluje (server áno)');

  const good = T.ssBuildPatch({ 'scalar:kerf_mm': '4,4', 'scalar:trim_mm': '0' }, RANGES);
  eq(good.errors, []);
  eq(good.patch, { kerf_mm: 4.4, trim_mm: 0 }, 'desatinná čiarka ide ako číslo, 0 je platná hodnota');
  const bad = T.ssBuildPatch({ 'scalar:kerf_mm': '12', 'scalar:dup_allowance_mm': 'x' }, RANGES);
  eq(bad.patch, {}, 'nič sa neposiela');
  eq(bad.errors, ['Prerez píly (hrúbka kotúča): hodnota mimo rozsahu 0–10 mm',
                  'Prídavok dupláku na stranu: hodnota musí byť číslo'], 'dôvody ľudsky, nie kľúčom');

  // Písanie do poľa: `.bad` pri rozsahu (cez delegovaný input listener).
  S.setStudioSection('bset');
  T.ssApplyState(state());
  const t = mkEl('input');
  t.setAttribute('data-ss', 'scalar:kerf_mm');
  t.value = '15';
  LISTEN.input.forEach(function(fn){ fn({ target: t }); });
  ok(t.classList.contains('bad'), 'pole prerezu 15 mm zčervená hneď pri písaní');
  t.value = '4,4';
  LISTEN.input.forEach(function(fn){ fn({ target: t }); });
  ok(!t.classList.contains('bad'), 'opravená hodnota červeň zruší');
  t.value = '99';
  LISTEN.input.forEach(function(fn){ fn({ target: t }); });
  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 0, 'mimo rozsahu sa na server nič neposiela');
  ok(/Neuložené: Prerez píly/.test(ELS.status.textContent), '„Uložiť" povie dôvod ľudsky');
  // Rozpísaná hodnota mimo rozsahu PREŽIJE push aj s červeňou.
  T.ssApplyState(state());
  const again = findAll(ELS.secbody, function(x){ return x.tagName === 'INPUT' && x.getAttribute('data-ss') === 'scalar:kerf_mm'; })[0];
  eq(again.value, '99');
  ok(again.classList.contains('bad'), 'červeň prežije plný push');
  T.SS.saved();
})();

// --- 3) banner a vypnuté „Uložiť" pri novšom / poškodenom súbore ------------

(function(){
  const newer = state({ settings_state: { state: 'newer', reason: 'Nastavenia dodávateľa uložil novší plugin (verzia súboru 3, tento plugin pozná 2) — dajú sa len čítať, zápisy sú vypnuté (aktualizuj plugin).' } });
  eq(T.ssWriteBlock(newer), newer.settings_state.reason);
  eq(T.ssWriteBlock(state()), '', 'ok stav nič neblokuje');
  eq(T.ssWriteBlock(state({ settings_state: { state: 'fallback', reason: 'x' } })), '',
     'nenačítaný súbor zápis neblokuje (prvý zápis ho opraví, revízia chráni cudziu zmenu)');
  ok(T.ssWriteBlock(state({ settings_state: { state: 'degraded', reason: 'poškodené' } })) === 'poškodené');

  const tools = T.ssToolsHtml('bset', false, newer.settings_state.reason);
  ok(/data-action="ss-save" aria-disabled="true"/.test(tools), '„Uložiť" má aria-disabled (nikdy HTML disabled, D-78)');
  ok(!/\sdisabled[\s>]/.test(tools), 'žiadny HTML disabled');
  ok(tools.indexOf('title="Nastavenia dodávateľa uložil novší plugin') >= 0, 'dôvod v title');
  ok(!/aria-disabled/.test(T.ssToolsHtml('bset', false, '')), 'bez bloku je „Uložiť" živé');
  ok(/title="a &quot;b&quot; &lt;c&gt;"/.test(T.ssToolsHtml('bset', false, 'a "b" <c>')), 'dôvod je escapovaný');

  S.setStudioSection('bset');
  T.ssApplyState(newer);
  const ban = findAll(ELS.secbody, function(x){ return x.classList && x.classList.contains('hwbanner'); });
  eq(ban.length, 1, 'banner je v tele hneď po otvorení');
  ok(ban[0].classList.contains('hwbanner-stop'), 'zablokovaný zápis = červený banner');
  ok(/novší plugin/.test(ban[0].textContent) && /Uloženie je vypnuté/.test(ban[0].textContent));
  ok(/aria-disabled="true"/.test(ELS.sectools.innerHTML), 'lišta sekcie má vypnuté „Uložiť"');

  const t = mkEl('input');
  t.setAttribute('data-ss', 'scalar:trim_mm');
  t.value = '12';
  LISTEN.input.forEach(function(fn){ fn({ target: t }); });
  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 0, 'klik na vypnuté „Uložiť" nič neodošle');
  ok(/Neuložené: .*novší plugin/.test(ELS.status.textContent), 'a povie dôvod');
  T.SS.saved();

  T.ssApplyState(state({ settings_state: { state: 'degraded', reason: 'Nastavenia dodávateľa sú poškodené — číta sa záloha' } }));
  ok(/aria-disabled="true"/.test(ELS.sectools.innerHTML), 'poškodený súbor: „Uložiť" vypnuté (zjednotené s newer)');

  // Codex #419 kolo 2: súbor sa nedá ČÍTAŤ (práva, zdieľanie, disk) — zápis by
  // zlyhal tiež, takže „Uložiť" je vypnuté a banner červený.
  const unr = state({ settings_state: { state: 'unreadable', reason: 'Súbor nastavení dodávateľa sa nedá čítať — zápisy sú vypnuté.' } });
  eq(T.ssWriteBlock(unr), unr.settings_state.reason, 'nečitateľný súbor blokuje zápis');
  T.ssApplyState(unr);
  ok(/aria-disabled="true"/.test(ELS.sectools.innerHTML), 'nečitateľný súbor: „Uložiť" vypnuté');
  const ub = findAll(ELS.secbody, function(x){ return x.classList && x.classList.contains('hwbanner'); });
  ok(ub.length === 1 && ub[0].classList.contains('hwbanner-stop'), 'a červený banner s dôvodom');

  T.ssApplyState(state({ settings_state: { state: 'fallback', reason: 'Súbor nastavení dodávateľa sa nepodarilo prečítať' } }));
  const fb = findAll(ELS.secbody, function(x){ return x.classList && x.classList.contains('hwbanner'); });
  eq(fb.length, 1, 'fallback má banner…');
  ok(!fb[0].classList.contains('hwbanner-stop'), '…jantárový (zápis ide)');
  ok(!/aria-disabled/.test(ELS.sectools.innerHTML), 'a „Uložiť" ostáva živé');

  T.ssApplyState(state());
  eq(findAll(ELS.secbody, function(x){ return x.classList && x.classList.contains('hwbanner'); }).length, 0,
     'zdravý súbor banner nemá');
})();

// --- 4) Kontrola: nález o nenačítaných nastaveniach vedie do Nastavení ------

(function(){
  const it = { severity: 'orange', category: 'layout_settings', owner_id: null, part_key: null,
               message_sk: 'Nastavenia prerezu a orezu sa nepodarilo načítať', stable_key: 'layout_settings|seed_fallback' };
  const row = S.ctrlRowHtml(it, 0);
  ok(/Prejde do sekcie Nastavenia rozpočtu/.test(row), 'riadok hovorí, kam vedie');
  ok(/<span class="where">Nastavenia<\/span>/.test(row), 'miesto = Nastavenia (nie „—")');
  ok(/data-act="bset"/.test(row), 'akcia vedie do Nastavení rozpočtu');
  ok(!/data-act="eye"/.test(row), 'žiadne oko — v modeli nie je čo označiť');
  const plain = S.ctrlRowHtml({ severity: 'red', category: 'oversize', owner_id: 'CAB-1', message_sk: 'x', stable_key: 'k' }, 1);
  ok(/data-act="eye"/.test(plain), 'bežný nález oko má ďalej');
})();

console.log(`OK — test_np2_nastavenia.js: ${n} testov preslo`);
