// D-130b — SKUPINA „SPOLOČNÉ PRE SKRINKU": META, ZAMOK, RESET, N26.
//
// PRECO SU TO TESTY A NIE KLIKANIE:
//   1. META hlavicky je jediny text, z ktoreho Michal cita stav ZBALENEJ
//      skupiny (dekor · medzera · styri okraje). Ked bude klamat, nevsimne si,
//      ze skrinka ide do vyroby s inymi okrajmi, nez si mysli.
//   2. ZAMOK LIMITU je jeden bit v configu (`edge_limit_off`), ktory povoli
//      okraje az ±2000 mm. Po presune do hlavicky uz nema textovy label —
//      stav nesie ikona, `title`, `aria-pressed` a farba. Keby sa niektory
//      z nich rozisiel s premennou, pouzivatel by nevedel, ci je odomknute.
//   3. JEDEN KLIK = jeden krok Späť. Zamok aj reset smu vyvolat PRESNE jeden
//      apply — inak by sa Undo rozpadlo na dva kroky.
//   4. IKONY V <summary> musia zastavit natívny toggle `<details>`, inak by
//      kazdy klik skupinu zbalil.
//   5. N26 (jantarove medzery v nahlade) sa od D-130b viaze na FOKUS/HOVER,
//      nie na otvorenu skupinu — schema zije v skupine, ktora byva otvorena,
//      takze by medzery svietili stale a zvyraznenie by nic neznamenalo.
//
// MUTACIE, ktore sada chyta:
//   M1 preview.js ostane na `fgaps` (N26 mrtve / svieti stale)  -> D)
//   M2 `resetFrontGaps` zmeni predvolby                          -> C)
//   M3 ikona zamku nezastavi propagaciu (skupina sa zbali)       -> E)
'use strict';
global.nxDocGuid = () => ''; // samostatna skupina bez dokumentoveho bridge
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const C = require(path.join(JS, 'core.js'));

// ============ A) META HLAVICKY = CISTA FUNKCIA ==============================
// H6b (O7): „F206 ST9 · medzera 3 · okraje 2 · dole -20" — dekor = prve dve slova
// (celý názov nesie `title`), okraje = spolocna hodnota + vynimky v poradi
// hore/dole/vlavo/vpravo.
const G = (gap, top, bottom, left, right) => ({ gap, top, bottom, left, right });

eq(C.cabfrontMetaText('F206 ST9 Pietra Grigia čierna · DTDL 18 mm', G(3, 2, 2, 2, 2)),
   'F206 ST9 · medzera 3 · okraje 2', 'A (O7): dekor = prve dve slova, vsetky okraje rovnake');
eq(C.cabfrontMetaText('Dub Halifax', G(3, 2, 2, 0, 0)),
   'Dub Halifax · medzera 3 · okraje 2 · vľavo 0 · vpravo 0',
   'A (O7): 2 : 2 — zaklad je PRVA hodnota v poradi hore, dole, vlavo, vpravo (M6)');
eq(C.cabfrontMetaText('Dub', G(3, 2, -20, 2, 2)),
   'Dub · medzera 3 · okraje 2 · dole -20', 'A (O7): jedna vynimka');
eq(C.cabfrontMetaText('Dub', G(3, 2, 2, 2, 5)),
   'Dub · medzera 3 · okraje 2 · vpravo 5', 'A (O7): vynimka na poslednej strane');
eq(C.cabfrontMetaText('Dub', G(3, 3, 2, 2, 2)),
   'Dub · medzera 3 · okraje 2 · hore 3', 'A (O7): vynimka hore, zaklad je najcastejsia hodnota (nie prva)');
eq(C.cabfrontMetaText('Dub', G(3, 2, -20, 0, 1)),
   'Dub · medzera 3 · hore 2 · dole -20 · vľavo 0 · vpravo 1',
   'A (O7): kazda hodnota ina — vsetky strany menom');
eq(C.cabfrontMetaText('Dub', G(2.5, 2.5, 2.5, 2.5, 2.5)),
   'Dub · medzera 2,5 · okraje 2,5', 'A (O7): desatinna ciarka ako v poli');
eq(C.cabfrontMetaText('', G(3, 2, 2, 2, 2)),
   'medzera 3 · okraje 2', 'A (O7): bez dekoru zacina riadok rovno medzerou (ziadna prazdna bodka)');
eq(C.cabfrontMetaText('Dub', G(3, 2, 2, 2, 2)),
   'Dub · medzera 3 · okraje 2', 'A (O7): dekor z jedneho slova');
eq(C.cabfrontMetaText('Dub Halifax', null), '',
   'A: bez oznacenej skrinky je meta PRAZDNA (cisla by patrili minulemu vyberu)');
eq(C.cabfrontMetaText('Dub Halifax', null, { slot: true }), '', 'A: slot bez skrinky tiez prazdna');
// Slot umyvacky: polia „medzera" a „dole" su skryte (server ich drzi na 0) — v meta nie su.
eq(C.cabfrontMetaText('Dub', G(0, 2, 0, 2, 2), { slot: true }),
   'Dub · okraje 2', 'A (D6): slot — bez medzery a bez okraja dole');
eq(C.cabfrontMetaText('Dub', G(0, 2, 0, 2, 5), { slot: true }),
   'Dub · okraje 2 · vpravo 5', 'A (D6): slot — vynimka vpravo');
eq(C.cabfrontMetaText('H1180 ST37 Dub Halifax prírodný · 18', G(3, 2, 2, 2, 2)),
   'H1180 ST37 · medzera 3 · okraje 2', 'A (M7): ziadna elipsa — prve dve slova');
eq(C.cabfrontDecorShort('Dub 18'), 'Dub 18', 'A: kratky nazov ostava cely');
// P3-2: popis polozky je „<dekor> <struktura> <nazov> · <TYP> <hrubka> mm" - dekor je cast PRED „ · ".
eq(C.cabfrontDecorShort('K009 · DTDL 18 mm'), 'K009', 'A (P3-2): dekor bez struktury a nazvu');
eq(C.cabfrontMetaText('K009 · DTDL 18 mm', G(3, 2, 2, 2, 2)), 'K009 · medzera 3 · okraje 2',
   'A (P3-2): ziadne „K009 · · medzera"');
eq(C.cabfrontDecorShort('K009 Dub Halifax prírodný · DTDL 18 mm'), 'K009 Dub', 'A (P3-2): dve slova pred „ · "');
eq(C.cabfrontDecorShort(' · DTDL 18 mm'), '', 'A (P3-2): popis bez dekoru = ziadny dekor');
eq(C.cabfrontDecorShort('  F206   ST9   Pietra '), 'F206 ST9', 'A: biele znaky sa zlucia');
eq(C.cabfrontDecorShort('   '), '', 'A: prazdny nazov = ziadny dekor');
eq(C.cabfrontDecorShort(null), '', 'A: null = ziadny dekor');
eq(C.frontCountText(1, 0), '1 čelo', 'A: 1 čelo');
eq(C.frontCountText(3, 1), '3 čelá · 1 bez smeru', 'A: 3 čelá, jedno bez smeru');
eq(C.frontCountText(5, 0), '5 čiel', 'A: 5 čiel');
eq(C.frontCountText(0, 0), 'bez čiel', 'A (D6): bez čiel');

// ============ B) DOM: hlavicka, zamok, reset ================================
//
// form.js zije nad globalmi, ktore v paneli zakladaju skripty pred nim.
// V Node ich stavia tento blok — stubuju sa LEN cudzie zavislosti.
const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = C.mmLabel;
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: (node, id) => { const u = node.querySelector('use'); if (u) u.setAttribute('href', '#i-' + id); }
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = require(path.join(JS, 'insert_state.js'));
let renders = 0;
global.renderPreview = () => { renders++; };
const PV = require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
Object.keys(C).forEach(k => { if (global[k] === undefined) global[k] = C[k]; });
global.FRONT_PROFILES = [];
global.frontItems = null;
global.frontSlots = null;
global.frontDrawer = null;
global.frontLift = null;
// Vyber skrinky sa zapina az tam, kde na nom meta zavisi — inak by kazdy
// `onField` naplanoval 400 ms apply do serveroveho mostu, ktory tu nie je.
global.selectedCabId = null;
global.applyTimer = null;
global.newStableId = p => p + (++global.__nxid || (global.__nxid = 1));
global.attachExprField = () => {};
global.nxDimFillRow = () => {};
global.evalDim = v => parseFloat(v);
global.isExprInput = () => false;
global.isExprStr = () => false;
// Gap polia su SKUTOCNE uzly mini-DOM — inak by sa cesta „schema -> config"
// vobec nedala prejst (presne to je jadro D-130b).
global.numv = id => { const e = global.el(id); return e ? parseFloat(e.value) : NaN; };
global.val = id => { const e = global.el(id); return e ? e.value : ''; };
global.setNum = (id, v) => { const e = global.el(id); if (e) e.value = String(v); };
global.setOut = () => {};
// `onField` je vo `form.js` privatna, ale VZDY prejde cez `refreshMaterialFilters`
// — pocitadlo nad nou je teda pocitadlo APPLY ciest (vzor KOV-A2a/D-130a).
let applyCalls = 0;
global.refreshMaterialFilters = () => { applyCalls++; };
global.clearFrontHover = () => {};
global.currentCarcass = () => ({});
global.nxInteriorZ = () => ({ availH: 0 });
global.pvGeom = () => ({ W: 0, H: 0 });
global.computeZones = () => [];
global.pvInsertFronts = () => [];
global.nxDraftStats = () => ({});
global.setCabInfo = () => {};
global.frontHwBadge = () => '';
global.frontHwBuy = () => '';
global.hwAxHtml = require(path.join(JS, 'hardware.js')).hwAxHtml;
const FM = require(path.join(JS, 'form.js'));

// Kostra skupiny `cabfront` — presna kopia z panel.html (test musi klikat do
// TOHO ISTEHO tvaru, inak neoveri nic).
const grp = mkEl('details');
grp.attrs['data-key'] = 'cabfront';
grp.attrs['data-s4'] = 'cela';
grp.open = true;
DOC.body.appendChild(grp);
const summary = mkEl('summary');
grp.appendChild(summary);
const metaNode = mkEl('span'); metaNode.attrs.id = 'cabfrontMeta'; summary.appendChild(metaNode);
function iconBtn(id){
  const b = mkEl('button');
  b.attrs.id = id;
  b.attrs.class = 'ibtn';
  b.innerHTML = '<svg class="ic"><use href="#i-lock"/></svg>';
  summary.appendChild(b);
  return b;
}
const lockBtn = iconBtn('edgeLimitLock');
lockBtn.setAttribute('aria-pressed', 'true');
const resetBtn = iconBtn('frontGapsReset');
const body = mkEl('div'); body.attrs.class = 'body'; grp.appendChild(body);
// Material ciel = uz existujuci select `cab_front_c` (zrkadlo `cab_front`).
const matSel = mkEl('select');
matSel.attrs.id = 'cab_front_c';
['', 'D1', 'D2'].forEach(v => {
  const o = mkEl('option');
  o.attrs.value = v;
  o.textContent = (v === 'D1') ? 'H1180 ST37 Dub Halifax prírodný · 18' : (v === 'D2' ? 'Dub 18' : '');
  matSel.appendChild(o);
});
matSel.value = '';
body.appendChild(matSel);
// Schema: `.gapdiag` s piatimi EXISTUJUCIMI polami.
const diag = mkEl('div');
diag.attrs.class = 'gapdiag';
body.appendChild(diag);
const gapBox = mkEl('div'); gapBox.attrs.class = 'gd-box'; diag.appendChild(gapBox);
const GAP_IDS = ['fr_gap', 'fr_gap_top', 'fr_gap_bottom', 'fr_gap_left', 'fr_gap_right'];
GAP_IDS.forEach(id => {
  const i = mkEl('input');
  i.attrs.id = id;
  i.attrs.class = 'gd';
  i.value = (id === 'fr_gap') ? '3' : '2';
  diag.appendChild(i);
});
const rows = mkEl('div'); rows.attrs.id = 'frontRows'; DOC.body.appendChild(rows);

function gapVals(){ return GAP_IDS.map(id => global.el(id).value); }

// --- B) ZAMOK LIMITU PRESAHOV ----------------------------------------------
eq(FM.collectFronts().edge_limit_off, false, 'B: vychodzi stav = limit ZAMKNUTY');
let before = applyCalls;
FM.toggleEdgeLimit({ preventDefault(){}, stopPropagation(){} });
eq(FM.collectFronts().edge_limit_off, true, 'B: klik odomkol limit (config nesie bit)');
eq(applyCalls - before, 1, 'B: PRESNE jeden apply = jeden krok Späť');
eq(lockBtn.getAttribute('aria-pressed'), 'false', 'B: `aria-pressed` = zamknuty limit, teraz false');
ok(lockBtn.classList.contains('amber'), 'B: odomknuty zamok je JANTAROVY (vidno aj pri zbalenej skupine)');
eq(lockBtn.querySelector('use').getAttribute('href'), '#i-lock-open', 'B: a ikona je otvoreny zamok');
ok(/Odomknuté/.test(lockBtn.getAttribute('title')), 'B: `title` hovori, co klik urobi');
before = applyCalls;
FM.toggleEdgeLimit({ preventDefault(){}, stopPropagation(){} });
eq(FM.collectFronts().edge_limit_off, false, 'B: druhy klik zamkol spat');
eq(applyCalls - before, 1, 'B: zase presne jeden apply');
ok(!lockBtn.classList.contains('amber'), 'B: zamknuty stav uz nie je jantarovy');
eq(lockBtn.querySelector('use').getAttribute('href'), '#i-lock', 'B: a ikona je zavrety zamok');
ok(/±100/.test(lockBtn.getAttribute('title')), 'B: `title` pomenuje platny limit');

// --- C) RESET PREDVOLENYCH MEDZIER (M2) ------------------------------------
GAP_IDS.forEach(id => { global.el(id).value = '77'; });
before = applyCalls;
FM.resetFrontGaps({ preventDefault(){}, stopPropagation(){} });
eq(gapVals(), ['3', '2', '2', '2', '2'],
   'C (M2): predvolby su 3 / 2 / 2 / 2 / 2 — D-130b ich NEMENI');
eq(applyCalls - before, 1, 'C: reset = PRESNE jeden apply');

// --- C2) META hlavicky z HODNOT --------------------------------------------
global.selectedCabId = 'CAB-001';
FM.updateCabfrontMeta();
eq(metaNode.textContent, 'medzera 3 · okraje 2', 'C2: bez zvoleneho dekoru len medzera a okraje');
ok(!metaNode.hasAttribute('title'), 'C2: bez dekoru nie je ani bublina');
matSel.value = 'D2';
FM.updateCabfrontMeta();
eq(metaNode.textContent, 'Dub 18 · medzera 3 · okraje 2', 'C2: dekor sa cita z TEXTU vybranej option');
eq(metaNode.getAttribute('title'), 'Dub 18', 'C2 (O7): bublina = cely nazov dekoru');
matSel.value = 'D1';
global.el('fr_gap_left').value = '-20';
FM.updateCabfrontMeta();
eq(metaNode.textContent, 'H1180 ST37 · medzera 3 · okraje 2 · vľavo -20', 'C2: dekor = kod + vynimka okraja');
eq(metaNode.getAttribute('title'), 'H1180 ST37 Dub Halifax prírodný · 18',
   'C2 (O7): `title` nesie CELY nazov dekoru (v texte su len dve slova)');
eq(FM.nxCabfrontText(), 'H1180 ST37 · medzera 3 · okraje 2 · vľavo -20',
   'C2: list sektora Čelá berie TEN ISTY text (jeden zdroj)');
global.selectedCabId = null;
FM.updateCabfrontMeta();
eq(metaNode.textContent, '', 'C2: bez oznacenej skrinky je meta prazdna');
ok(!metaNode.hasAttribute('title'), 'C2: a bez skrinky nie je ani bublina');
global.el('fr_gap_left').value = '2';
matSel.value = '';

// --- D) N26: FOKUS / HOVER, NIE OTVORENA SKUPINA (M1) -----------------------
eq(PV.pvGapsHot(), false, 'D: v pokoji medzery nesvietia');
ok(grp.open, 'D (M1): skupina `cabfront` je OTVORENA…');
eq(PV.pvGapsHot(), false, '…a to samo o sebe zvyraznenie NEZAPINA (inak by svietilo stale)');
// Fokus v poli schemy.
dispatch(global.el('fr_gap_top'), 'focusin');
eq(PV.pvGapsHot(), true, 'D: kurzor v poli schemy medzery prisvieti');
dispatch(global.el('fr_gap_top'), 'focusout');
eq(PV.pvGapsHot(), false, 'D: odchod z pola ich zhasne');
// Hover nad schemou — aj nad kresbou obrysu, nielen nad polom.
dispatch(gapBox, 'mouseover');
eq(PV.pvGapsHot(), true, 'D: mys nad schemou ich prisvieti tiez');
dispatch(gapBox, 'mouseout', { relatedTarget: global.el('fr_gap') });
eq(PV.pvGapsHot(), true, 'D: prechod MEDZI uzlami schemy zvyraznenie nezhasne');
dispatch(global.el('fr_gap'), 'mouseout', { relatedTarget: rows });
eq(PV.pvGapsHot(), false, 'D: odchod zo schemy von ho zhasne');
ok(PV.pvInGapDiag(global.el('fr_gap')), 'D: pole schemy patri do `.gapdiag`');
ok(!PV.pvInGapDiag(rows), 'D: zoznam ciel nie');
eq(Object.keys(PV.NX_GAP_FIELDS).sort(), GAP_IDS.slice().sort(),
   'D: zoznam poli schemy sa nerozisiel s panelom');

// --- E) IKONY V <summary> NEZBALIA SKUPINU (M3) -----------------------------
// Mini-DOM natívny toggle `<details>` nesimuluje, preto sa overuje PRIAMO to,
// co ho zastavuje: `preventDefault` + `stopPropagation` na kazdej z ikon.
[['zamok', ev => FM.toggleEdgeLimit(ev)],
 ['reset', ev => FM.resetFrontGaps(ev)],
 ['tooltip', ev => FM.nxTipStop(ev)]].forEach(pair => {
  let prevented = 0, stopped = 0;
  pair[1]({ preventDefault(){ prevented++; }, stopPropagation(){ stopped++; } });
  eq([prevented, stopped], [1, 1], 'E (M3): ' + pair[0] + ' v hlavicke zastavi natívny toggle');
});
ok(grp.open, 'E: skupina po klikoch na ikony ostala otvorena');

console.log('D-130b: meta, zamok, reset, N26 fokus/hover a stop-guardy OK (' + n + ' asercii)');
