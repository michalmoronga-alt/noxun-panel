// KOV-A2b — SMER OTVARANIA (JS zrkadlo): prepinac v raile Inspectora aj v liste
// sekcie Kontrola okna STUDIO + deep-link „klik na RED nalez otvori kartu cela".
//
// JS je LEN zobrazenie: zapnutost aj cisla nesie SERVER, klient si nic
// neprepocitava a nic si nepamata. Navyse tu bezi DOKAZ ZRKADLA: symboly
// nahladu sa porovnavaju s TOU ISTOU tabulkou fixtur
// (tests/fixtures/kova2b_symbols.json), akou je overeny Ruby overlay — ked sa
// model a nahlad rozidu, padnu OBE sady naraz.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function no(cond, msg){ n++; assert.ok(!cond, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const FIX = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'kova2b_symbols.json'), 'utf8'));
const C = require(path.join(JS, 'core.js'));

// ============ 1) SYMBOLY = spolocna tabulka fixtur s RUBY ====================

FIX.wings.forEach(row => {
  eq(C.frontWingSymbols(row.wings_n, row.slots), row.expect, row.case);
});
FIX.types.forEach(row => {
  eq(C.frontTypeSymbol(row.type), row.expect, row.case);
});
ok(FIX.wings.length >= 10, 'tabulka fixtur je podozrivo kratka');

// ============ 2) PREPINAC V LISTE SEKCIE KONTROLA (Studio) ==================

global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const P = require(path.join(JS, 'studio.js'));

const EDGE = { available: true, active: false,
               options: { show_missing: true, show_extra: false, show_taped: false, taped_selected_only: true },
               counts: { missing: 0, extra: 0, taped: 0 } };
function grain(extra){
  return Object.assign({ available: true, active: false, parts: null }, extra || {});
}
function dir(extra){
  return Object.assign({ available: true, active: true, wings: 12, unknown: 0, legacy: 0, marks: 12 },
                       extra || {});
}

(function(){
  const on = P.directionBtnHtml(dir());
  ok(on.indexOf('id="dcBtn"') >= 0, 'prepinac ma stabilne id');
  ok(on.indexOf('dcbtn on') >= 0, 'zapnuty stav je na tlacidle');
  ok(on.indexOf('aria-pressed="true"') >= 0, 'zapnutost vidi aj citacka');
  ok(on.indexOf('Smer otvárania') >= 0, 'nazov tlacidla');
  ok(on.indexOf('#i-direction') >= 0, 'ikona zo spritu — TA ISTA ako v raile');
  no(on.indexOf('data-ec=') >= 0, 'smer otvarania NEMA rozbalovacie okno — nie je co nastavovat');

  const off = P.directionBtnHtml(dir({ active: false, wings: null }));
  ok(off.indexOf('aria-pressed="false"') >= 0, 'vypnuty stav');
  no(off.indexOf('dcbtn on') >= 0, 'vypnute tlacidlo nenesie zapnuty vzhlad');

  eq(P.directionBtnHtml({ available: false }), '', 'stary SketchUp prepinac vobec neukaze');
  eq(P.directionBtnHtml(null), '', 'chybajuci stav = ziadny prepinac');
})();

(function(){
  eq(P.directionCheckText(null), '', 'bez stavu lista o smere mlci');
  eq(P.directionCheckText(dir({ active: false })), '', 'vypnuty prepinac do textu nepridava nic');

  const t = P.directionCheckText(dir());
  ok(t.indexOf('12 krídel') >= 0, 'pocet kridiel zo servera');
  no(t.indexOf('neurčených') >= 0, 'ked netreba, o neurcenych sa nehovori');
  no(t.indexOf('legacy') >= 0, 'ani o legacy');

  const mixed = P.directionCheckText(dir({ wings: 3, unknown: 2, legacy: 4 }));
  ok(mixed.indexOf('3 krídla') >= 0, 'sklonovanie 2-4');
  ok(mixed.indexOf('2 neurčených') >= 0, 'neurcene sa priznaju');
  ok(mixed.indexOf('4 bez smeru (legacy)') >= 0, 'legacy cela sa priznaju (nie su to nalezy)');

  eq(P.directionWingPluralSk(1), 'krídlo', '1');
  eq(P.directionWingPluralSk(2), 'krídla', '2');
  eq(P.directionWingPluralSk(4), 'krídla', '4');
  eq(P.directionWingPluralSk(5), 'krídel', '5');
  eq(P.directionWingPluralSk(0), 'krídel', '0');
})();

// --- lista: TRI nastroje, stale JEDEN riadok --------------------------------
(function(){
  const bar = P.edgeCheckBarHtml(EDGE, false, grain({ active: true, parts: 4 }), dir());
  ok(bar.indexOf('class="echk"') >= 0, 'zvyraznenie hran ostava tlacidlom s rohom');
  ok(bar.indexOf('id="gcBtn"') >= 0, 'smer kresby je v TEJ ISTEJ liste');
  ok(bar.indexOf('id="dcBtn"') >= 0, 'a smer otvarania tiez');
  eq(bar.split('<span class="ecinfo">').length - 1, 1,
     'stale JEDEN text listy (vertikalny priestor je vzacny)');
  ok(bar.indexOf('12 krídel') >= 0, 'text smeru otvarania je pripojeny k textu listy');

  const without = P.edgeCheckBarHtml(EDGE, false, grain());
  no(without.indexOf('id="dcBtn"') >= 0, 'bez stavu smeru otvarania sa prepinac nekresli');
  ok(without.indexOf('class="echk"') >= 0, 'a zvyraznenie hran tym netrpi');

  const na = P.edgeCheckBarHtml({ available: false }, false, grain(), dir());
  ok(na.indexOf('SketchUp 2023') >= 0, 'stary SketchUp dostane jednu vetu za vsetky tri nastroje');
  no(na.indexOf('id="dcBtn"') >= 0, 'a ziadne mrtve tlacidlo');
})();

// ============ 3) PREPINAC V RAILE INSPECTORA ================================
// Rail dostava PRESNE ten isty serverovy stav ako Studio (jeden zdroj stavu,
// dva vstupne body). `NXShell.directionRail` je cista funkcia.
(function(){
  const NXShell = require(path.join(JS, 'shell.js'));

  const on = NXShell.directionRail(dir());
  eq(on.on, true, 'zapnuty stav prisvieti ikonu raily');
  eq(on.available, true, 'dostupnost je zo servera');
  ok(on.tip.indexOf('ZAPNUTÝ') >= 0, 'bublina povie, ze je prepinac zapnuty');
  ok(on.tip.indexOf('12 krídel') >= 0, 'a nesie ZIVE cislo zo servera');

  const mixed = NXShell.directionRail(dir({ wings: 3, unknown: 2, legacy: 4 }));
  ok(mixed.tip.indexOf('3 krídla') >= 0, 'sklonovanie 2-4 je zhodne so Studiom');
  ok(mixed.tip.indexOf('2 neurčených') >= 0, 'neurcene sa priznaju aj v raile');
  ok(mixed.tip.indexOf('4 bez smeru (legacy)') >= 0, 'legacy tiez');

  const off = NXShell.directionRail(dir({ active: false, wings: null }));
  eq(off.on, false, 'vypnuty stav nesvieti');
  eq(off.tip, 'Smer otvárania čiel v modeli (zapnúť/vypnúť)', 'vypnuta bublina je pokyn, nie stav');

  // Stary SketchUp: tlacidlo NIE JE ticho mrtve — povie preco (vzor D-78).
  const na = NXShell.directionRail({ available: false, active: true });
  eq(na.available, false, 'bez Overlay API je prepinac neaktivny');
  eq(na.on, false, 'nedostupny prepinac NIKDY nesvieti ako zapnuty');
  ok(na.tip.indexOf('SketchUp 2023') >= 0, 'bublina povie dovod');

  eq(NXShell.directionRail(null).on, false, 'bez stavu prepinac nesvieti');
  eq(NXShell.directionRail(null).available, true, 'a ostava klikatelny (server odpovie sam)');

  // Sklonovanie je ZRKADLO Ruby `direction_wing_plural` aj listy Studia.
  [1, 2, 4, 5, 0].forEach(function(v){
    eq(NXShell.directionWingWord(v), P.directionWingPluralSk(v), 'sklonovanie ' + v + ' sedi so Studiom');
  });
})();

// ============ 4) DEEP-LINK: NX.focusFront otvori KARTU cela =================
// Cela cesta nad SKUTOCNYM DOM (mini-DOM): server posle LEN ID cela a klient
// z neho spravi otvorenu kartu prave toho riadku.
const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = v => String(v);
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: (node, id) => { const u = node.querySelector('use'); if (u) u.setAttribute('href', '#i-' + id); }
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = require(path.join(JS, 'insert_state.js'));
require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
Object.keys(C).forEach(k => { global[k] = C[k]; });
global.FRONT_PROFILES = [];
global.frontItems = null;
global.frontSlots = null;
global.selectedCabId = null;
global.applyTimer = null;
global.newStableId = p => p + (++global.__nxid || (global.__nxid = 1));
global.attachExprField = () => {};
global.nxDimFillRow = () => {};
global.evalDim = v => parseFloat(v);
global.numv = () => NaN;
global.val = () => '';
global.setNum = () => {};
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
const FM = require(path.join(JS, 'form.js'));

const rows = mkEl('div');
rows.attrs.id = 'frontRows';
DOC.body.appendChild(rows);
function rowOf(fid){
  return rows.querySelectorAll('.frow').find(r => r.dataset.frontId === fid);
}

[{ id: 'F1', type: 'door', wings: '1' },
 { id: 'F2', type: 'door', wings: '1' },
 { id: 'F3', type: 'drawer_front' }].forEach(it => FM.addFrontRow(it));
global.frontSlots = { F1: { wings_n: 1, slots: [{ wing: 'single', part_key: 'front:F1/wing:single', state: null }] },
                      F2: { wings_n: 1, slots: [{ wing: 'single', part_key: 'front:F2/wing:single', state: 'unset' }] },
                      F3: { wings_n: 1, slots: [] } };
FM.refreshFrontCards();
eq(rows.querySelectorAll('.fcard').length, 0, 'na zaciatku je zbalene vsetko');

ok(FM.nxFocusFront('F2'), 'deep-link na existujuce celo uspeje');
eq(rows.querySelectorAll('.fcard').length, 1, 'otvorena je prave jedna karta');
ok(rowOf('F2').querySelector('.fcard'), 'a je v riadku cela, na ktore ukazoval nalez');
eq(rowOf('F2').querySelector('.ftname').getAttribute('aria-expanded'), 'true', 'stav nesie aria-expanded');

// Druhy nalez presunie kartu — nikdy nie su otvorene dve.
ok(FM.nxFocusFront('F1'), 'deep-link na ine celo');
eq(rows.querySelectorAll('.fcard').length, 1, 'stale najviac jedna karta');
ok(rowOf('F1').querySelector('.fcard'), 'a je pri poslednom cieli');

// Neznama adresa NEROBI NIC — cudzia otvorena karta by klamala.
no(FM.nxFocusFront('F9'), 'celo, ktore v paneli nie je, sa neotvori');
ok(rowOf('F1').querySelector('.fcard'), 'a predchadzajuca karta ostava, ako bola');
no(FM.nxFocusFront(''), 'prazdna adresa');
no(FM.nxFocusFront(null), 'chybajuca adresa');
no(FM.nxFocusFront(undefined), 'ani undefined');

console.log(`test_kova2b_smer_overlay.js OK (${n} kontrol)`);
