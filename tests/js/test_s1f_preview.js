// S1-F — KONTROLNA GEOMETRIA CHLADNICKY v nahlade (`node tests/js/test_s1f_preview.js`).
//
// CO SA TU OVERUJE:
//   1) SCENA (`nxRefExtent`) obsiahne box niky aj vtedy, ked TRCI z korpusu —
//      presne vtedy Kontrola hlasi „nezmestí sa" a fit ho nesmie orezat,
//   2) BOX + PASMA sa kreslia z PAYLOADU SERVERA a panel si NIC nedopocitava
//      (ziadne 669/71/1200 v JS — cisla prichadzaju hotove),
//   3) PASMO PRIPUSTNEJ HRANY (jantar) + ciara sucasnej hrany; jednostranny
//      rozsah aj stav `clash` maju svoju farbu,
//   4) riadok Spotrebica kresli VERDIKT z payloadu (`sub`, `tone`) — HTML
//      komponent o nike nic nevie.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function near(actual, expected, tol, msg){
  n++;
  assert.ok(Math.abs(actual - expected) <= tol, `${msg}: cakam ${expected} (±${tol}), dostal ${actual}`);
}

// ---- DOM a globaly, ktore preview.js pozna z CEF --------------------------
const { DOC } = require(path.join(__dirname, 'minidom.js'));
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = v => String(v);
global.NXIcons = { svg: (id) => '<svg class="ic"><use href="#i-' + id + '"/></svg>', set: () => {} };
global.getType = () => 'lower';
let FIELDS = {};
global.numv = id => (FIELDS[id] === undefined ? NaN : parseFloat(FIELDS[id]));
global.val = id => (FIELDS[id] === undefined ? '' : String(FIELDS[id]));
const PV = require(path.join(JS, 'preview.js'));

// PAYLOAD SERVERA pre skrinku 600 x 2076 (Beko: box 560 x 1940 na z 118,
// pasma 40 · 629 · 71 · 1200, pasmo hrany 679–727 v nike = 797–845 v korpuse).
const BEKO = {
  item_id: 'I-1', label: 'Chladnička — kontrolná nika', state: 'ok',
  box: { x: 20, z: 118, w: 560, h: 1940 },
  bands: [
    { z0: 118, z1: 158, size: 40 },
    { z0: 158, z1: 787, size: 629 },
    { z0: 787, z1: 858, size: 71 },
    { z0: 858, z1: 2058, size: 1200 }
  ],
  split: { state: 'ok', lo: 797, hi: 845, edge: 813, recommended: 821,
           lo_mm: 679, hi_mm: 727, edge_mm: 695 }
};

// ============ 1) SCENA: box, ktory TRCI, sa nesmie orezat ==================

eq(PV.nxRefExtent(null, [], 600), null, 'bez referencii ziadny rozsah');

const tesne = PV.nxRefExtent(null, [BEKO], 600);
near(tesne.minX, 20 - PV.PV_APPL_GUTTER, 0.01, 'pasmo hrany lezi VLAVO od boxu');
near(tesne.maxX, 600, 0.01, 'box 560 v skrinke 600 vpravo netrci');
near(tesne.minZ, 0, 0.01, 'dole rozhoduje podlaha korpusu');
near(tesne.maxZ, 2058, 0.01, 'hore vrch boxu');

// Box SIRSI nez skrinka (nika 560 v skrinke 500) — zaporne X.
const siroky = PV.nxRefExtent(null, [{ box: { x: -30, z: 118, w: 560, h: 1940 } }], 500);
near(siroky.minX, -30, 0.01, 'zaporne X ostava v scene');
near(siroky.maxX, 530, 0.01, 'a presah vpravo tiez');

// Box VYSSI nez korpus (nizka skrinka) — presah nad obrys.
const vysoky = PV.nxRefExtent(null, [{ box: { x: 20, z: 118, w: 560, h: 2400 } }], 600);
near(vysoky.maxZ, 2518, 0.01, 'box nad korpusom sa do sceny zmesti');

// Telo slotu a box niky sa do sceny prikladaju SPOLU (zovseobecneny extent).
const spolu = PV.nxRefExtent({ bodyW: 598, bodyH: 820, fb: 64, fh: 776 }, [BEKO], 600);
near(spolu.minX, 20 - PV.PV_APPL_GUTTER, 0.01, 'vlavo rozhoduje pasmo hrany');
near(spolu.maxZ, 2058, 0.01, 'hore rozhoduje box niky');

// ============ 2) BOX + PASMA sa kreslia z PAYLOADU =========================

const rx = x => x;
const ry = z => 2076 - z;
let S = [];
PV.drawApplianceRefs(S, rx, ry, { W: 600, H: 2076 }, [BEKO]);
const svg = S.join('');
ok(svg.indexOf('stroke-dasharray') >= 0, 'box je REFERENCIA — prerusovana ciara, nie dielec');
eq((svg.match(/<line /g) || []).length, 4, 'tri hrany pasiem + ciara sucasnej hrany');
ok(svg.indexOf('>629<') >= 0, 'popis pasma je CISLO ZO SERVERA');
ok(svg.indexOf('>1200<') >= 0, 'vratane horneho pasma');
ok(svg.indexOf('>679<') >= 0 && svg.indexOf('>727<') >= 0, 'konce pasma hrany zo servera');
ok(svg.indexOf('hrana 695') >= 0, 'popis sucasnej hrany');
ok(svg.indexOf('#107787') >= 0, 'sediaci box je vo firemnej teal (zrkadlo --nx-select)');
ok(svg.indexOf('#e65100') >= 0, 'pasmo hrany je jantarove (zrkadlo --nx-warn-fg)');

// Ziadne cisla z listu v samotnom JS — vsetko prislo payloadom.
const SRC = require('node:fs').readFileSync(path.join(JS, 'preview.js'), 'utf8');
const APPL = SRC.slice(SRC.indexOf('function drawApplianceRefs'));
ok(APPL.indexOf('669') < 0 && APPL.indexOf('679') < 0 && APPL.indexOf('1159') < 0,
   'kresba si zo snapshotu NIC nedopocitava');

// Box, ktory sa nezmesti, sa prekresli jantarom.
let S2 = [];
PV.drawApplianceRefs(S2, rx, ry, { W: 600, H: 2076 },
                     [Object.assign({}, BEKO, { state: 'clash' })]);
const clash = S2.join('');
ok(clash.indexOf('<rect x="20" y="' + (2076 - 2058) + '" width="560" height="1940" fill="#e65100"') >= 0,
   'nezmesti sa = jantarovy box');

// Degenerovany alebo chybajuci box sa NEKRESLI (namiesto padu).
let S3 = [];
PV.drawApplianceRefs(S3, rx, ry, { W: 600, H: 2076 },
                     [null, {}, { box: { x: 0, z: 0, w: 0, h: 100 } }]);
eq(S3.length, 0, 'prazdny payload nic nekresli');

// ============ 3) PASMO HRANY: stavy a jednostranny rozsah ==================

let S4 = [];
PV.drawApplianceSplit(S4, rx, ry,
                      { box: { x: 20, z: 118, w: 560, h: 1940 },
                        split: { state: 'clash', lo: 797, hi: 845, edge: 900,
                                 lo_mm: 679, hi_mm: 727, edge_mm: 782 } },
                      20, 560);
ok(S4.join('').indexOf('hrana 782') >= 0, 'ciara hrany nesie svoje cislo');
eq((S4.join('').match(/stroke="#e65100"/g) || []).length >= 2, true,
   'hrana mimo pasma je jantarova ako pasmo');

let S5 = [];
PV.drawApplianceSplit(S5, rx, ry,
                      { box: { x: 20, z: 118, w: 560, h: 1940 },
                        split: { state: 'ok', lo: 797, hi: null, edge: 813, edge_mm: 695 } },
                      20, 560);
const jedno = S5.join('');
ok(jedno.indexOf('<rect ') >= 0, 'jednostranny rozsah sa kresli po hranu boxu');
ok(jedno.indexOf('>679<') < 0, 'bez oboch koncov sa cisla pasma nepisu');

let S6 = [];
PV.drawApplianceSplit(S6, rx, ry, { box: { x: 20, z: 118, w: 560, h: 1940 } }, 20, 560);
eq(S6.length, 0, 'bez pasma (n/a, unknown, unsatisfiable) sa nekresli nic');

// ============ 4) KONTEXT: box patri LEN do Korpusu =========================

global.applPreview = [BEKO];
global.previewMode = 'cab';
eq(PV.pvApplianceRefs().length, 1, 'kontext Korpus box kresli');
global.previewMode = 'fronts';
eq(PV.pvApplianceRefs().length, 0, 'Cela maju vlastnu projekciu — box tam nepatri');
global.previewMode = 'hw';
eq(PV.pvApplianceRefs().length, 0, 'ani Kovanie');
global.previewMode = 'cab';
global.applPreview = [];
eq(PV.pvApplianceRefs().length, 0, 'prazdny payload = prazdna kresba');

// ============ 5) RIADOK SPOTREBICA kresli verdikt zo servera ===============

const AR = require(path.join(JS, 'appliance_row.js'));
const rowHtml = AR.aprRowHtml({
  state: 'bound', item_id: 'I-1', category: 'fridge', category_label: 'Chladnička',
  text: 'Beko BCNA306E5ZSN', tone: 'warn',
  sub: 'Chladnička · nezmestí sa: výška 1924 < 1940 · hrana čiel 666 mimo 679–727',
  link: true,
  check: { state: 'clash', niche: { axes: { height: 'clash' } } }
});
ok(rowHtml.indexOf('aprow warn') >= 0, 'ORANGE riadok = trieda z payloadu');
ok(rowHtml.indexOf('nezmestí sa: výška 1924 &lt; 1940') >= 0, 'veta verdiktu je zo servera');
ok(rowHtml.indexOf('679–727') >= 0, 'vratane pasma delenia');
const AR_SRC = require('node:fs').readFileSync(path.join(JS, 'appliance_row.js'), 'utf8');
ok(AR_SRC.indexOf('niche') < 0 && AR_SRC.indexOf('door_split') < 0,
   'komponent riadku o nike ani o deleni NIC nevie — kresli `text`/`sub`/`tone`');

console.log(`OK test_s1f_preview.js — ${n} kontrol`);
