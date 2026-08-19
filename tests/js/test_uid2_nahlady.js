// UI-D2 — PNG NAHLADY DLAZDIC: ciste jadro (dependency-free Node,
// `node tests/js/test_uid2_nahlady.js`). Pokryva to, co v CEF nevidno:
//   1) dlazdica ma PNG aj SCHEMU v TOM ISTOM boxe — obrazok je v nej od
//      zaciatku (bez src) a len sa odkryva, takze sa vyska nemeni a ziadny
//      uzol sa uprostred dvojkliku neodpaja,
//   2) PULL plan: ziadost na jednu reviziu ide PRESNE RAZ, sablona bez nahladu
//      sa nepyta vobec a ZAPORNA odpoved servera sa cachuje tiez,
//   3) CACHE JE PER REVIZIA — prepisana sablona (nova `rev`) si vypyta novy
//      obrazok a stary sa uz nikdy nenasadi,
//   4) FALLBACK: chybajuci nahlad AJ zlyhane nacitanie (`onerror`) konci pri
//      schematickej kresbe, nikdy pri prazdnom boxe.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const ins = require(path.join(JS, 'insert_state.js'));
// form.js kresli dlazdice cez globalne NXInsert/mmLabel/esc (v paneli su to
// skripty nacitane pred nim) — v Node ich treba postavit PRED require.
global.NXInsert = ins;
global.mmLabel = function (v) {
  const n = parseFloat(v);
  return isNaN(n) ? '' : String(Math.round(n * 100) / 100).replace('.', ',');
};
global.esc = function (s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
};
require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
const fm = require(path.join(JS, 'form.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const TPL = { name: 'Dolná klasik', kind: 'cabinet', config: { type: 'lower' } };
const PNG = 'data:image/png;base64,iVBORw0KGgo=';
const PNG2 = 'data:image/png;base64,iVBORw0KGgoAAA==';

// ============ 1) BOX DLAZDICE: PNG aj schema pohromade ======================
const pic = fm.tplPicHtml(TPL);
ok(pic.indexOf('<img') >= 0, 'box dlazdice ma <img> od zaciatku');
ok(pic.indexOf('src=') < 0, 'ale BEZ src — obrazok sa dosadza az po odpovedi servera');
ok(pic.indexOf('<svg') >= 0, 'schematicka kresba je v TOM ISTOM boxe (fallback)');
ok(pic.indexOf('class="tplpic"') >= 0, 'box ma triedu, ktora drzi vysku');

const withRev = fm.tplTileHtml({ name: 'Dolná klasik', kind: 'cabinet', config: {}, preview_rev: 'ab12' }, '');
ok(withRev.indexOf('data-tpl-rev="ab12"') >= 0, 'dlazdica nesie reviziu nahladu');
ok(withRev.indexOf('data-tpl-kind="cabinet"') >= 0, 'aj druh — pull kanal potrebuje dvojicu');
const noRev = fm.tplTileHtml({ name: 'Bez obrazka', kind: 'cabinet', config: {} }, '');
ok(noRev.indexOf('data-tpl-rev=""') >= 0, 'sablona bez nahladu ma prazdnu reviziu');
ok(noRev.indexOf('<svg') >= 0, 'a kresli schemu');

// ============ 2) PULL PLAN: raz na reviziu =================================
const desc = { kind: 'cabinet', name: 'Dolná klasik', rev: 'r1' };
let cache = {};
let asked = {};

let plan = fm.nxTplPreviewPlan([desc], cache, asked);
eq(plan.ask.length, 1, 'neznamy nahlad si panel vypyta');
eq(plan.apply.length, 0, 'nie je co nasadit');

plan = fm.nxTplPreviewPlan([desc], cache, asked);
eq(plan.ask.length, 0, 'druha prestavba mriezky uz ziadost NEPOSIELA (raz na reviziu)');

// Sablona BEZ nahladu (prazdna rev) sa nepyta vobec.
plan = fm.nxTplPreviewPlan([{ kind: 'cabinet', name: 'Bez obrazka', rev: '' }], cache, asked);
eq(plan.ask.length, 0, 'bez revizie ziadna ziadost');
eq(plan.apply.length, 0, 'bez revizie ziadne nasadenie');

// Poskodeny popis (bez mena) nesmie nic poslat.
plan = fm.nxTplPreviewPlan([{ kind: 'cabinet', name: '', rev: 'r9' }, null], cache, asked);
eq(plan.ask.length, 0, 'popis bez mena sa ticho preskoci');

// ============ 3) ODPOVED SERVERA + CACHE PER REVIZIA =======================
const stored = fm.nxTplPreviewStore(cache, { kind: 'cabinet', name: 'Dolná klasik', rev: 'r1', png: PNG });
eq(stored.png, PNG, 'odpoved sa vrati normalizovana');
eq(cache[fm.tplPrevKey('cabinet', 'Dolná klasik', 'r1')], PNG, 'obrazok je v cache pod klucom revizie');

plan = fm.nxTplPreviewPlan([desc], cache, asked);
eq(plan.ask.length, 0, 'znamy nahlad sa uz nepyta');
eq(plan.apply.length, 1, 'a rovno sa nasadi');
eq(plan.apply[0].png, PNG, 'nasadzuje sa presne to, co prislo zo servera');

// Prepis sablony = INA revizia -> novy pull, stary obrazok sa nenasadi.
const desc2 = { kind: 'cabinet', name: 'Dolná klasik', rev: 'r2' };
plan = fm.nxTplPreviewPlan([desc2], cache, asked);
eq(plan.ask.length, 1, 'nova revizia si vypyta novy obrazok');
eq(plan.apply.length, 0, 'stary obrazok sa na novu reviziu NENASADI');
fm.nxTplPreviewStore(cache, { kind: 'cabinet', name: 'Dolná klasik', rev: 'r2', png: PNG2 });
eq(fm.nxTplPreviewPlan([desc2], cache, asked).apply[0].png, PNG2, 'nasadi sa NOVY obrazok');
eq(cache[fm.tplPrevKey('cabinet', 'Dolná klasik', 'r1')], PNG, 'stara revizia ostava v cache nedotknuta');

// ZAPORNA odpoved (server nahlad nema) sa cachuje TIEZ — inak by sa panel pytal donekonecna.
fm.nxTplPreviewStore(cache, { kind: 'cabinet', name: 'Bez PNG', rev: 'r3', png: null });
eq(cache[fm.tplPrevKey('cabinet', 'Bez PNG', 'r3')], '', 'zaporna odpoved je v cache ako prazdny retazec');
plan = fm.nxTplPreviewPlan([{ kind: 'cabinet', name: 'Bez PNG', rev: 'r3' }], cache, {});
eq(plan.ask.length, 0, 'po zapornej odpovedi sa uz panel NEPYTA (ani s prazdnym `asked`)');
eq(plan.apply.length, 0, 'a nic nenasadzuje — dlazdica ostane na scheme');

// Nepouzitelny payload sa zahodi (nezaburi cache).
eq(fm.nxTplPreviewStore(cache, { kind: 'cabinet', name: '', rev: 'r4', png: PNG }), null, 'payload bez mena');
eq(fm.nxTplPreviewStore(cache, { kind: 'cabinet', name: 'X', rev: '', png: PNG }), null, 'payload bez revizie');
eq(fm.nxTplPreviewStore(cache, null), null, 'prazdny payload');

// Kluc cache je TROJICA — rovnaky nazov v inom druhu je iny nahlad.
ok(fm.tplPrevKey('cabinet', 'Zástena', 'r1') !== fm.tplPrevKey('board', 'Zástena', 'r1'),
   'druh je sucastou kluca cache');

// ============ 4) FALLBACK: onerror vracia SCHEMU ============================
// Minimalna nahrada DOM uzla dlazdice (bez jsdom — testy su bez zavislosti).
function fakeTile(){
  const classes = {};
  const img = {
    attrs: {}, onload: null, onerror: null,
    getAttribute: function (k){ return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null; },
    removeAttribute: function (k){ delete this.attrs[k]; },
    get src(){ return this.attrs.src; },
    set src(v){ this.attrs.src = v; }
  };
  const picNode = {
    classList: { add: function (c){ classes[c] = true; }, remove: function (c){ delete classes[c]; } },
    querySelector: function (sel){ return sel === 'img' ? img : null; }
  };
  return { querySelector: function (sel){ return sel === '.tplpic' ? picNode : null; },
           img: img, classes: classes };
}

let t = fakeTile();
fm.tplBindPreview(t, PNG);
eq(t.img.src, PNG, 'obrazok dostal src');
eq(t.classes.has, undefined, 'kym sa nenacita, box ostava na scheme');
t.img.onload();
eq(t.classes.has, true, 'po nacitani sa obrazok odkryje');

t = fakeTile();
fm.tplBindPreview(t, PNG);
t.img.onerror();
eq(t.classes.has, undefined, 'zlyhane nacitanie NECHA schemu (nikdy prazdny box)');
eq(t.img.getAttribute('src'), null, 'a pokazeny src sa odstrani');

// Opakovane nasadenie TOHO ISTEHO obrazka je no-op (ziadne zbytocne prekreslenie).
t = fakeTile();
fm.tplBindPreview(t, PNG);
t.img.onload();
const before = t.img.onload;
fm.tplBindPreview(t, PNG);
eq(t.img.onload, before, 'rovnaky src druhy raz nic nemeni');

// Dlazdica bez boxu (obranny stav) ani prazdny obrazok nesmu spadnut.
fm.tplBindPreview({ querySelector: function (){ return null; } }, PNG);
fm.tplBindPreview(fakeTile(), '');

console.log(`OK: UI-D2 nahlady sablon — ${n} kontrol`);
