// KON-D — dlaždica šablóny „Chladničková", klientska časť (dependency-free
// Node, `node tests/js/test_kond_chladnickova.js`). Pokrýva:
//   1) Štúdio (sekcia `tpl`): riadok súhrnu konštrukcie („komín vzadu 50") LEN
//      pri neprázdnom súhrne; ostatné dlaždice sa nemenia; veta o vetraní
//      v tooltipe dlaždice popri súhrne kovania,
//   2) vkladanie (Inspector): tooltip `nxTplTitle` nesie súhrn konštrukcie,
//      zachovaný text kovania a vetu o vetraní — dlaždica nenarastie,
//   3) staršia knižnica bez kľúčov (`construction`, `vent_note`) = nič navyše.
// Texty skladá SERVER (`TemplateStore.construction_summary`,
// `ventilation_note`) — klient ich len vypíše.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const dom = require('./minidom.js');

const UI = path.join(__dirname, '..', '..', 'noxun_engine', 'ui');
global.NXInsert = require(path.join(UI, 'js', 'insert_state.js'));
global.esc = function(s){ return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;'); };
global.mmLabel = function(v){ return String(v); };
global.NX = { setStatus: function(){} };
const fm = require(path.join(UI, 'js', 'form.js'));
const studio = require(path.join(UI, 'js', 'templates.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(a, msg){ n++; assert.ok(a, msg); }

function tileNode(markup, selector){
  const wrap = dom.mkEl('div'); wrap.innerHTML = markup;
  return wrap.querySelector(selector);
}

const VENT = 'Vetracie otvory v sokli a hore rieši stolár podľa montážneho listu spotrebiča.';
const HW = 'Kovanie: Závesy: Klasik — zámky sa neprenášajú';
// Tvar zo servera (tile_row aj template_list nesú tie isté odvodené kľúče;
// H12b/H12c: aj slovo typu `type_word` — okno ho už samo neskladá).
const fridge = { name: 'Chladničková', kind: 'cabinet', type_word: 'dolná',
  config: { type: 'lower', width: 600, height: 2100, depth: 560 },
  hardware: { has: false, labels: [] },
  appliance_expects: { has: true, codes: ['fridge'], text: 'očakáva chladničku' },
  construction: { has: true, text: 'komín vzadu 50' }, vent_note: VENT };
const plain = { name: 'Dolna klasik', kind: 'cabinet', type_word: 'dolná', config: { type: 'lower', width: 600, height: 720, depth: 510 },
  hardware: { has: false, labels: [] }, appliance_expects: { has: false, codes: [], text: '' },
  construction: { has: false, text: '' }, vent_note: '' };
const withHw = Object.assign({}, fridge, { name: 'Chladničková s kovaním',
  hardware: { has: true, labels: ['Závesy: Klasik'] } });
const legacy = { name: 'Stará', kind: 'cabinet', type_word: 'dolná', config: { type: 'lower', width: 600 } };

// ============ 1) ŠTÚDIO — riadok súhrnu a tooltip ============================
const t1 = tileNode(studio.tplTileHtml(fridge, 'cabinet', 0), '.stpltile');
const kon = t1.querySelector('.stplkon');
ok(kon, 'Chladničková má riadok súhrnu konštrukcie');
eq(kon.textContent, 'komín vzadu 50', 'text zo servera');
ok(kon.classList.contains('stplmeta'), 'riadok je bežný meta riadok dlaždice (vzor „očakáva chladničku")');
const metas = Array.from(t1.querySelectorAll('.stplmeta'));
eq(metas.map(function(m){ return m.textContent; }),
  ['dolná · 600×2100×560', 'komín vzadu 50', 'očakáva chladničku'], 'poradie riadkov podľa mockupu E2');
eq(t1.getAttribute('title'), VENT, 'veta o vetraní v tooltipe dlaždice');

const t2 = tileNode(studio.tplTileHtml(plain, 'cabinet', 1), '.stpltile');
eq(t2.querySelector('.stplkon'), null, 'bez komína/zapustenia/líšt žiadny riadok — dlaždica sa nemení');
eq(t2.getAttribute('title'), null, 'bez kovania a chladničky ani tooltip');

const t3 = tileNode(studio.tplTileHtml(withHw, 'cabinet', 2), '.stpltile');
eq(t3.getAttribute('title'), HW + '\n' + VENT, 'tooltip: kovanie ostáva, veta o vetraní pribudne');
ok(t3.querySelector('.tplhw').getAttribute('aria-label') === HW, 'ikona kovania nesie LEN súhrn kovania');

const t4 = tileNode(studio.tplTileHtml(legacy, 'cabinet', 3), '.stpltile');
eq(t4.querySelector('.stplkon'), null, 'staršie okno/knižnica bez kľúča = žiadny riadok');
eq(studio.tplTileHtml(plain, 'cabinet', 1).indexOf('stplkon'), -1, 'markup bez súhrnu triedu nemá');

// ============ 2) VKLADANIE — tooltip nxTplTitle ==============================
eq(fm.nxTplTitle(fridge),
  'Chladničková — klik = vybrať · dvojklik = vlož hneď\nkomín vzadu 50\n' + VENT,
  'tooltip vkladania: súhrn konštrukcie + veta o vetraní');
eq(fm.nxTplTitle(withHw).split('\n'),
  ['Chladničková s kovaním — klik = vybrať · dvojklik = vlož hneď', 'komín vzadu 50', HW, VENT],
  'text kovania zachovaný medzi súhrnom a vetou o vetraní');
eq(fm.nxTplTitle(plain), 'Dolna klasik — klik = vybrať · dvojklik = vlož hneď', 'bežná dlaždica bez zmeny');
eq(fm.nxTplTitle(legacy), 'Stará — klik = vybrať · dvojklik = vlož hneď', 'staršia knižnica bez kľúčov');
eq(fm.nxTplTitle(Object.assign({}, plain, { construction: { has: false, text: 'komín vzadu 50' } })),
  'Dolna klasik — klik = vybrať · dvojklik = vlož hneď', 'has: false = nič (klient nič neodvodzuje)');
const ins = tileNode(fm.tplTileHtml(fridge, ''), '.tpltile');
eq(ins.getAttribute('title'), fm.nxTplTitle(fridge), 'dlaždica vkladania nesie tooltip');
eq(ins.querySelector('.tplcaption').textContent, 'Chladničková', 'popisok dlaždice sa nemení (nenarastie)');

console.log(JSON.stringify({ passed: n, failed: 0 }));
