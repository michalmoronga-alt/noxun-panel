// S1-E — SLOT UMYVACKY v paneli (ciste jadro + mini-DOM,
// `node tests/js/test_s1e_slot.js`). Pokryva to, co v CEF nevidno:
//   1) RAIL: kontext Zony je pri slote ZAMKNUTY a ma vlastny dovod — autoritou
//      je guard v `NXShell.setCtx`, nie CSS (klik, Enter aj Space koncia tam),
//   2) VKLADACIA KARTA: styvrty typ objektu a typovy filter sablon,
//   3) LIMITY per TYP: sirka a vyska slotu maju INE hranice nez korpus; bez
//      nich by panel pustil hodnotu, ktoru server klampne (alebo naopak),
//   4) ZAKLADNE: ktore riadky slot MA a ktore NEMA (mini-DOM nad tymi istymi
//      ID, ake su v panel.html),
//   5) CELA: slot ma jedno pevne celo — „Pridať čelo", krizik a AUTO sa
//      schovaju a vyska ide na citanie,
//   6) NAHLAD: celny rez slotu (telo so zakladnou, celo, jantarove pasmo
//      „výplň" po liniu linky) a jeho zrkadla rozmerov.
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

// ============ 1) RAIL: slot zony NEMA =======================================
const SH = require(path.join(JS, 'shell.js'));
const NXShell = SH.NXShell || SH;

NXShell.track('cab', 'g|cab:CAB-7');
NXShell.setCabType('lower');
eq(NXShell.ctxLockedBy('zony'), '', 'dolna skrinka zony MA');
eq(NXShell.setCtx('zony'), true, 'a da sa do nich prepnut');
eq(NXShell.effectiveCtx(), 'zony', 'kontext drzi');

NXShell.setCabType('dishwasher');
ok(NXShell.ctxLockedBy('zony').length > 0, 'slot ma pre Zony DOVOD, nie len sivu farbu');
eq(NXShell.ctxLockedBy('cela'), '', 'Cela ostavaju aktivne (jedno celo)');
eq(NXShell.ctxLockedBy('kovanie'), '', 'a Kovanie tiez (uchytka)');
eq(NXShell.effectiveCtx(), 'korpus', 'zapamatany zakazany kontext padne na Korpus');
eq(NXShell.setCtx('zony'), false, 'klik do Zon pri slote NEROBI NIC');
eq(NXShell.setCtx('cela'), true, 'Cela sa otvorit daju');
NXShell.setCabType('lower');
eq(NXShell.ctxLockedBy('zony'), '', 'navrat na dolnu skrinku zamok pusti');

// ============ 2) VKLADACIA KARTA ============================================
const NXInsert = require(path.join(JS, 'insert_state.js'));
eq(NXInsert.INSERT_TYPES, ['lower', 'upper', 'dishwasher', 'board'],
   'vkladacia karta ponuka styri typy objektu');
eq(NXInsert.setInsertType('dishwasher'), true, 'prepnutie na Umývačku');
eq(NXInsert.insertType(), 'dishwasher', 'stav drzi novy typ');
eq(NXInsert.state.kind, 'cabinet', 'slot je KORPUSOVY druh, nie doska');

const LIB = [
  { name: 'Dolna klasik', kind: 'cabinet', config: { type: 'lower' } },
  { name: 'Horna klasik', kind: 'cabinet', config: { type: 'upper' } },
  { name: 'Umývačka 60', kind: 'cabinet', config: { type: 'dishwasher', dw_class: 600 } },
  { name: 'Umývačka 45', kind: 'cabinet', config: { type: 'dishwasher', dw_class: 450 } },
  { name: 'Diel', kind: 'board', config: { type: 'board' } }
];
eq(NXInsert.templatesForType(LIB, 'dishwasher').map(t => t.name), ['Umývačka 60', 'Umývačka 45'],
   'typ Umývačka ponuka LEN slotove sablony');
eq(NXInsert.templatesForType(LIB, 'lower').map(t => t.name), ['Dolna klasik'],
   'a dolna skrinka slotove sablony NEVIDI');
eq(NXInsert.templateType(LIB[2]), 'dishwasher', 'typ sablony slotu sa NESKLAPA na lower');
NXInsert.setInsertType('lower');

// ============ 3) DOM stuby pre form.js ======================================
const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
const C = require(path.join(JS, 'core.js'));
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = v => String(v);
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: () => {}
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = NXInsert;
// `getType`/`setType` su v CEF GLOBALY z core.js (nie exporty) — v Node ich
// stavia test. form.js aj preview.js sa na ne pytaju cez `typeof`, takze
// stub staci nasadit PRED prvym volanim.
let CAB_TYPE = 'lower';
global.getType = () => CAB_TYPE;
function setType(t){ CAB_TYPE = t; }
const PV = require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
Object.keys(C).forEach(k => { global[k] = C[k]; });
global.frontItems = null;
global.frontSlots = null;
global.frontDrawer = null;
global.frontLift = null;
global.selectedCabId = null;
global.applyTimer = null;
global.newStableId = p => p + (++global.__nxid || (global.__nxid = 1));
global.attachExprField = () => {};
global.nxDimFillRow = () => {};
global.evalDim = v => parseFloat(v);
let FIELDS = {};
global.numv = id => (FIELDS[id] === undefined ? NaN : parseFloat(FIELDS[id]));
global.val = id => (FIELDS[id] === undefined ? '' : String(FIELDS[id]));
// `setNum`/`setVal` su v CEF zapisove cesty do poli — sada P2 #1 overuje
// PRAVE ich ucinok (dosadenie predvolby slotu), takze musia naozaj pisat.
global.setNum = (id, v) => { const e = el(id); if (e && v !== null && v !== undefined) e.value = String(parseFloat(v)); };
global.setVal = (id, v) => { const e = el(id); if (e && v !== null && v !== undefined) e.value = String(v); };
global.setOut = () => {};
global.isExprInput = () => false;
global.isExprStr = () => false;
global.refreshMaterialFilters = () => {};
global.renderPreview = () => {};
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

// ============ 4) LIMITY PER TYP (ciste jadro) ===============================
eq(FM.TYPE_LIMITS.dishwasher.width, [300, 1200], 'slot ma vlastny rozsah sirky');
eq(FM.TYPE_LIMITS.dishwasher.height, [500, 1200], 'a vlastny rozsah vysky linky');
eq(FM.LIMITS.dw_body_height, [700, 1000], 'telo V');
eq(FM.LIMITS.dw_front_bottom, [0, 300], 'sokel slotu');
eq(FM.LIMITS.dw_front_height, [300, 1200], 'vyska cela — presah nad linku je legitimny');

setType('lower');
eq(FM.limitFor('width'), [200, 3000], 'dolna skrinka drzi korpusove hranice');
eq(FM.limitFor('height'), [80, 3000], 'vratane 80 mm korpusu na dorovnanie (S1-E0)');
setType('dishwasher');
eq(FM.limitFor('width'), [300, 1200], 'slot prepne na svoje');
eq(FM.limitFor('height'), [500, 1200], 'aj pri vyske');
eq(FM.limitFor('depth'), [150, 2000], 'hlbka ostava spolocna');
setType('lower');

// ============ 5) ZAKLADNE: ktore riadky slot MA a ktore NEMA ================
// Kostra je PRESNA KOPIA ID z panel.html — test musi prepinat TO ISTE, co
// prepina panel, inak by neoveril nic.
function addRow(id){
  const d = mkEl('div');
  d.id = id;
  DOC.body.appendChild(d);
  return d;
}
['plinthGroup', 'fhRow', 'recessRow', 'twoRailsGroup', 'backThRow'].forEach(addRow);
FM.SLOT_ONLY_ROWS.forEach(addRow);
FM.SLOT_HIDDEN_ROWS.forEach(addRow);
const weightRow = addRow('infWeight');
const weightSpan = mkEl('span');
weightRow.appendChild(weightSpan);

// Pole vysky + jeho label a jednotka (riadok `.rowc` ako v panel.html).
const hRow = mkEl('div');
hRow.className = 'rowc';
DOC.body.appendChild(hRow);
const hLab = mkEl('label');
hLab.setAttribute('for', 'height');
hLab.appendChild(mkEl('svg'));
const hLabSpan = mkEl('span');
hLabSpan.id = 'lblHeight';
hLabSpan.textContent = 'Výška';
hLab.appendChild(hLabSpan);
hRow.appendChild(hLab);
const hInp = mkEl('input');
hInp.id = 'height';
hRow.appendChild(hInp);
const hUnit = mkEl('span');
hUnit.className = 'unit';
hUnit.textContent = 'mm';
hRow.appendChild(hUnit);

const bRow = mkEl('div');
bRow.className = 'rowc';
DOC.body.appendChild(bRow);
const bInp = mkEl('input');
bInp.id = 'dw_body_height';
bRow.appendChild(bInp);
const bUnit = mkEl('span');
bUnit.className = 'unit';
bRow.appendChild(bUnit);


setType('dishwasher');
FM.applyVisibility('dishwasher');
FM.SLOT_ONLY_ROWS.forEach(id => ok(el(id).hidden === false, `slot MA riadok ${id}`));
FM.SLOT_HIDDEN_ROWS.forEach(id => eq(el(id).style.display, 'none', `slot NEMA riadok ${id}`));
eq(el('fhRow').style.display, 'none', 'sokel korpusu slot nema (jeho sokel je pole Sokel slotu)');
eq(el('plinthGroup').style.display, 'none', 'ani soklovu skupinu');
eq(hLabSpan.textContent, 'Výška linky', 'vyska sa pri slote volá „Výška linky“');
ok(hUnit.textContent.indexOf('horná hrana susedov') >= 0, 'a hint to vysvetľuje');
ok(bUnit.textContent.indexOf('700') >= 0 && bUnit.textContent.indexOf('1000') >= 0,
   'rozsah tela je v hinte pola');
eq(weightSpan.textContent, 'Hmotnosť čela', 'slot vyraba jedine celo');

setType('lower');
FM.applyVisibility('lower');
FM.SLOT_ONLY_ROWS.forEach(id => ok(el(id).hidden === true, `dolna skrinka riadok ${id} NEMA`));
FM.SLOT_HIDDEN_ROWS.forEach(id => eq(el(id).style.display, '', `a riadok ${id} zas MA`));
eq(el('fhRow').style.display, '', 'sokel korpusu sa vratil');
eq(hLabSpan.textContent, 'Výška', 'aj povodny popis vysky');
eq(weightSpan.textContent, 'Hmotnosť', 'a popis hmotnosti');

FM.applyVisibility('upper');
eq(el('fhRow').style.display, 'none', 'horna skrinka sokel nema — spravanie sa NEZMENILO');
FM.SLOT_ONLY_ROWS.forEach(id => ok(el(id).hidden === true, `ani horna skrinka riadok ${id} nema`));

// ============ 6) CELA: jedno pevne celo =====================================
const rowsWrap = mkEl('div');
rowsWrap.id = 'frontRows';
DOC.body.appendChild(rowsWrap);
const addTypes = mkEl('span');
addTypes.id = 'frontAddTypes';
const addRowBox = mkEl('div');
addRowBox.className = 'addrow';
addRowBox.appendChild(addTypes);
DOC.body.appendChild(addRowBox);

const frow = mkEl('div');
frow.className = 'frow';
rowsWrap.appendChild(frow);
const fh = mkEl('input');
fh.className = 'fh';
frow.appendChild(fh);
const fauto = mkEl('button');
fauto.className = 'fauto';
frow.appendChild(fauto);
const fdel = mkEl('button');
fdel.className = 'fdel';
frow.appendChild(fdel);

setType('dishwasher');
FM.nxSlotFrontsLock();
eq(addRowBox.style.display, 'none', '„Pridať čelo“ sa pri slote schova');
eq(fh.readOnly, true, 'vyska cela je na CITANIE (meni ju pole Čelo V)');
ok(String(fh.title).indexOf('Čelo V') >= 0, 'a title povie KDE sa meni');
eq(fauto.style.display, 'none', 'chip AUTO nema pri pevnom cele zmysel');
eq(fdel.style.display, 'none', 'ani krizik — slot bez cela neexistuje');

setType('lower');
FM.nxSlotFrontsLock();
eq(addRowBox.style.display, '', 'dolna skrinka cela pridavat MOZE');
eq(fh.readOnly, false, 'a vysku menit tiez');
eq(fdel.style.display, '', 'aj mazat');

// ============ 7) NAHLAD: celny rez slotu ====================================
eq(PV.PV_DW_BODY[600], { w: 598, d: 555 }, 'zrkadlo generickeho tela 60 cm');
eq(PV.PV_DW_BODY[450], { w: 448, d: 550 }, 'a 45 cm');
eq(PV.PV_DW_BASE_H, 200, 'zakladna tela');
eq(PV.PV_DW_BASE_SIDE, 20, 'a jej odsadenie do stran');

setType('lower');
eq(PV.pvSlot(), null, 'dolna skrinka slotovy nahlad NEMA');

setType('dishwasher');
FIELDS = { dw_class: '600', dw_body_height: 820, dw_front_bottom: 64, dw_front_height: 776,
           width: 600, height: 930, depth: 560 };
const sl = PV.pvSlot();
eq(sl.cls, 600, 'trieda zo selectu');
eq(sl.bodyW, 598, 'sirka generickeho tela');
near(sl.bodyH, 820, 0.01, 'vyska tela z pola');
near(sl.fb, 64, 0.01, 'sokel');
near(sl.fh, 776, 0.01, 'vyska cela');

FIELDS.dw_class = '450';
eq(PV.pvSlot().bodyW, 448, 'zmena triedy prestavi telo');
FIELDS.dw_class = '999';
eq(PV.pvSlot().cls, 600, 'neznama trieda padne na 600 (ako Ruby normalize)');
FIELDS.dw_class = '600';

// Kresba: PODKLAD (telo + zakladna prerusovane) + DETAIL (celo, jantarove
// pasmo „výplň", koty). PR #381 (P2 #5): su to DVE funkcie — podklad ide do
// KAZDEHO kontextu, detail len do Korpusu a vkladania.
const S = [];
const GEO = { W: 600, H: 930, gapLeft: 2, gapRight: 2 };
PV.drawSlotBase(S, x => x, z => 930 - z, GEO, PV.pvSlot());
PV.drawSlotDetail(S, x => x, z => 930 - z, GEO, PV.pvSlot());
const svg = S.join('');
ok(svg.indexOf('stroke-dasharray') >= 0, 'referencia (telo + zakladna) je PRERUSOVANA');
ok(svg.indexOf('výplň 90 · ručne') >= 0, 'pasmo vyplne nesie svoj popis');
eq((svg.match(/<rect /g) || []).length, 4, 'telo + zakladna + celo + pasmo vyplne');
ok(svg.indexOf('>600<') >= 0, 'kota sirky');
ok(svg.indexOf('>930<') >= 0, 'kota vysky linky');
ok(svg.indexOf('>64<') >= 0, 'kota sokla');

// Celo PRESAHUJUCE liniu: pasmo vyplne uz nevznikne (nie je co vypĺňať).
FIELDS.dw_front_height = 900;
const S2 = [];
PV.drawSlotDetail(S2, x => x, z => 930 - z, GEO, PV.pvSlot());
ok(S2.join('').indexOf('výplň') < 0, 'celo nad linkou = ziadne pasmo vyplne');
FIELDS.dw_front_height = 776;
setType('lower');

// ============ 8) PR #381 — CODEX KOLO 1 (P2) ================================

// --- P2 #3: hlavicka Inspectora pozna slot ---------------------------------
eq(C.NX_TYPE_LABEL.dishwasher, 'Umývačka', 'mapa typ -> popisok pozna slot');
eq(C.nxCabInfo({ type: 'dishwasher' }).type, 'Umývačka', 'badge nad slotom uz nehlasi „Dolná"');
eq(C.nxCabInfo({ type: 'lower' }).type, 'Dolná', 'dolna ostava dolna');
eq(C.nxCabInfo({ type: 'nieco' }).type, 'Dolná', 'neznamy typ padne na dolnu (ako doteraz)');

// --- P2 #4: scena slotu obsiahne TRCIACE telo -------------------------------
// Telo 598 v slote 300 — presne stav, ktory Kontrola hlasi `dw_body_fit`.
const uzky = PV.nxSlotExtent({ bodyW: 598, bodyH: 820, fb: 64, fh: 776 }, 300);
near(uzky.minX, -149, 0.01, 'telo trci VLAVO (scena ho nesmie orezat)');
near(uzky.maxX, 449, 0.01, 'a VPRAVO');
near(uzky.maxZ, 840, 0.01, 'hore rozhoduje vyssie z tela a horneho okraja cela');
// Telo VYSSIE nez linka — presne stav `dw_height_fit`.
const vysoke = PV.nxSlotExtent({ bodyW: 598, bodyH: 1000, fb: 64, fh: 700 }, 600);
near(vysoke.maxZ, 1000, 0.01, 'telo nad linkou sa do sceny zmesti');
near(vysoke.minX, 0, 0.01, 'telo 598 v slote 600 netrci — scena ostava na obryse slotu');
near(vysoke.maxX, 600, 0.01, 'ani vpravo');
eq(PV.nxSlotExtent(null, 600), null, 'bez slotu ziadny rozsah');

// --- P2 #5: slot ma PODKLAD, nie vlastny CELY nahlad ------------------------
FIELDS = { dw_class: '600', dw_body_height: 820, dw_front_bottom: 64, dw_front_height: 776,
           width: 600, height: 930, depth: 560 };
setType('dishwasher');
const SL = PV.pvSlot();
const G = { W: 600, H: 930, gapLeft: 2, gapRight: 2 };
const B = []; PV.drawSlotBase(B, x => x, z => 930 - z, G, SL);
const D = []; PV.drawSlotDetail(D, x => x, z => 930 - z, G, SL);
const bs = B.join(''), ds = D.join('');
ok(bs.indexOf('stroke-dasharray') >= 0, 'podklad kresli telo a zakladnu PRERUSOVANE');
eq((bs.match(/<rect /g) || []).length, 2, 'podklad = telo + zakladna, nic viac');
ok(bs.indexOf('výplň') < 0, 'podklad pasmo vyplne NEKRESLI');
ok(bs.indexOf('<text') < 0, 'ani koty — tie patria detailu');
ok(ds.indexOf('výplň 90 · ručne') >= 0, 'detail ma pasmo vyplne');
eq((ds.match(/<rect /g) || []).length, 2, 'detail = celo + pasmo vyplne');
ok(ds.indexOf('>930<') >= 0, 'a koty');

// Celý náhľad: v kontexte ČELÁ sa kreslí PODKLAD slotu + ŠTANDARDNÝ renderer
// čiel (kóty výšok, čísla) — do opravy tam `pvSlot()` skončil `return`om.
const svgNode = mkEl('svg');
svgNode.id = 'preview';
DOC.body.appendChild(svgNode);
global.selectedCabId = 'CAB-7';
global.frontItems = [{ id: 'F1', type: 'blind', mode: 'fixed', height: 776, z: 64, wings_n: 1,
                       profile: 'none' }];
global.activeZoneId = null;
global.currentZoneTree = null;
global.hwItems = [];
global.partCard = null;
global.pvUserView = false;
FIELDS.fr_gap_left = 2; FIELDS.fr_gap_right = 2; FIELDS.fr_gap = 3;

global.previewMode = 'fronts';
PV.renderPreview();
const frontsSvg = svgNode.innerHTML;
ok(frontsSvg.indexOf('stroke-dasharray') >= 0, 'Čelá: podklad slotu (telo) sa kreslí');
ok(frontsSvg.indexOf('<text') >= 0, 'Čelá: štandardný renderer čiel kreslí kóty a čísla');
ok(frontsSvg.indexOf('výplň') < 0, 'Čelá: detail Korpusu sa do nich NEPLETIE');

global.previewMode = 'cab';
PV.renderPreview();
const cabSvg = svgNode.innerHTML;
ok(cabSvg.indexOf('výplň 90 · ručne') >= 0, 'Korpus: detail slotu ostáva');
ok(cabSvg.indexOf('stroke-dasharray') >= 0, 'aj s podkladom');

global.previewMode = 'hw';
PV.renderPreview();
ok(svgNode.innerHTML.indexOf('stroke-dasharray') >= 0, 'Kovanie: podklad slotu tiež');

// Dôsledok #5: ghost vrstva „Zóny" sa nad slotom nesmie ponúkať — slot zóny
// nemá a jeho `zone_tree` je len prázdny kanonický strom. Pred opravou #5 ich
// skryl `return`; teraz by sa nad ním naozaj nakreslili fantómové zóny.
global.currentZoneTree = { id: 'Z1', children: [] };
global.previewMode = 'cab';
eq(PV.pvAvail().zony, false, 'nad slotom je vrstva Zóny NEDOSTUPNÁ');
setType('lower');
eq(PV.pvAvail().zony, true, 'nad dolnou skrinkou ostáva dostupná');
global.currentZoneTree = null;

// --- P2 #1: skryté `dw_*` polia neblokujú inú skrinku -----------------------
// Kostra polí — tie isté ID ako v panel.html.
['width', 'height', 'depth', 'thickness', 'floor_height'].forEach(function(id){
  const i = mkEl('input'); i.id = id; i.value = ''; DOC.body.appendChild(i);
});
['dw_body_height', 'dw_front_bottom', 'dw_front_height'].forEach(function(id){
  if (!el(id)){ const i = mkEl('input'); i.id = id; DOC.body.appendChild(i); }
});
const dwBody = el('dw_body_height');

// Neplatná hodnota zostala po slote v skrytom poli.
dwBody.value = '5000';
setType('dishwasher');
eq(FM.validateFields(true), false, 'pri SLOTE je neplatné Telo V chyba');
ok(el('dw_body_height').classList.contains('bad'), 'a pole je červené');

setType('lower');
eq(FM.validateFields(true), true, 'pri DOLNEJ skrinke to isté pole vloženie NEBLOKUJE');
ok(!el('dw_body_height').classList.contains('bad'), 'a červené už nie je');

// Prepnutie späť na slot dosadí predvoľbu servera do prázdneho/neplatného poľa.
global.DEFAULTS = { dishwasher: { dw_class: 600, dw_body_height: 820, dw_front_bottom: 100,
                                  dw_front_height: 776 } };
dwBody.value = '';
setType('dishwasher');
FM.nxFillSlotFields();
eq(dwBody.value, '820', 'prázdne Telo V dostane predvoľbu typu');
dwBody.value = '5000';
FM.nxFillSlotFields();
eq(dwBody.value, '820', 'aj neplatná hodnota (panel tak ukazuje to, čo server postaví)');
dwBody.value = '900';
FM.nxFillSlotFields();
eq(dwBody.value, '900', 'platnú hodnotu používateľa NEPREPÍŠE');
setType('lower');

// --- P2 #2: modal „Uložiť ako šablónu" ------------------------------------
const tplSel = mkEl('select');
tplSel.id = 'tplSaveType';
['lower', 'upper', 'dishwasher'].forEach(function(v){
  const o = mkEl('option'); o.setAttribute('value', v); tplSel.appendChild(o);
});
DOC.body.appendChild(tplSel);
const tplTip = mkEl('button');
tplTip.id = 'tplSaveTypeTip';
tplTip.hidden = true;
DOC.body.appendChild(tplTip);

FM.nxSyncTplSaveType('dishwasher');
eq(tplSel.value, 'dishwasher', 'pri slote select ukazuje Umývačku');
eq(tplSel.disabled, true, 'a je ZAMKNUTÝ (typ určuje slot)');
eq(tplTip.hidden, false, 'bublina vysvetlí prečo');
FM.nxSyncTplSaveType('lower');
eq(tplSel.value, 'lower', 'pri korpuse sa prepne späť');
eq(tplSel.disabled, false, 'a odomkne');
eq(tplTip.hidden, true, 'bublina zmizne');

console.log(`OK test_s1e_slot.js — ${n} kontrol`);
