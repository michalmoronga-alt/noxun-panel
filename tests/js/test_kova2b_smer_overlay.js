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
// D-115: spolocna tabulka TVAROV (jednotkovy stvorec) — cita ju Ruby aj JS.
const SHP = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'front_symbol_shapes.json'), 'utf8'));
const C = require(path.join(JS, 'core.js'));

// ============ 1) SYMBOLY = spolocna tabulka fixtur s RUBY ====================

FIX.wings.forEach(row => {
  eq(C.frontWingSymbols(row.wings_n, row.slots), row.expect, row.case);
});
FIX.types.forEach(row => {
  eq(C.frontTypeSymbol(row.type), row.expect, row.case);
});
ok(FIX.wings.length >= 10, 'tabulka fixtur je podozrivo kratka');

// ============ 1b) D-115: TVAR = ta ista fixtura ako v RUBY ==================
// Do D-115 bolo overene len MENO symbolu — a kresby sa naozaj rozisli (Ruby
// kreslilo sipku s hrotom, JS holy chevron). Odteraz obe strany porovnavaju
// svoj tvar s TYM ISTYM suborom, takze rozchod padne naraz.
(function(){
  const TOL = 1e-9;
  const names = Object.keys(SHP.shapes).sort();
  eq(names.length, 6, 'fixtura musi popisat vsetkych 6 useckovych symbolov');
  ok(Math.abs(C.FRONT_SYM_INSET - SHP.corner_inset) < 1e-12,
     'odsadenie rohov je sucastou kontraktu');
  names.forEach(sym => {
    const want = SHP.shapes[sym];
    const got = C.frontSymbolShape(sym);
    ok(got, 'symbol ' + sym + ' tvar nema');
    eq(got.dashed, want.dashed, sym + ': prerusovanie (prerusovana = pohyb, plna = dielec)');
    eq(got.lines.length, want.lines.length, sym + ': pocet usecek');
    want.lines.forEach((ln, i) => ln.forEach((pt, j) => pt.forEach((v, k) => {
      n++;
      assert.ok(Math.abs(got.lines[i][j][k] - v) < TOL,
                sym + ': usecka ' + i + ' bod ' + j + ' suradnica ' + k +
                ' — cakam ' + v + ', dostal ' + got.lines[i][j][k]);
    })));
  });
  eq(C.frontSymbolShape('unknown'), null, '„neurcene" je kruh + otaznik, nie usecky');
  eq(C.frontSymbolShape('nonsense'), null, 'neznamy symbol nekresli nic');
  // PLNA je LEN blenda; zasuvka ma to iste X, ale prerusovane.
  eq(names.filter(s => SHP.shapes[s].dashed === false), ['cross'], 'plny je jedine symbol blendy');
  eq(C.frontSymbolShape('xdash').lines, C.frontSymbolShape('cross').lines,
     'zasuvku od blendy lisi VYHRADNE ciara, nie tvar');
})();

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
const PV = require(path.join(JS, 'preview.js'));
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

// ============ 5) D-115: KRESBA symbolov v nahlade ===========================
// `drawFrontSymbols` uz nema vlastnu geometriu — len premieta jednotkovy tvar
// na kridlo: u -> x = x0 + u*w, v -> zz = z + v*ph. Overuje sa, ze koncove
// body naozaj sedia v ROHOCH kridla (s odsadenim) a v STREDE protilahlej hrany,
// a ze prerusovanie hovori „pohyb / dielec".
(function(){
  const PAD = 14, H = 2000;
  const rx = x => PAD + x;              // zrkadlo renderPreview
  const ry = z => PAD + (H - z);        // ry PREKLAPA Z (hore = mensie y)
  const INS = C.FRONT_SYM_INSET, FAR = 1 - INS;

  // vsetky <line> ako [x1, y1, x2, y2]; kazdy prvok je jeden SVG element
  function draw(it, cols, z, ph){
    const S = [];
    PV.drawFrontSymbols(S, rx, ry, it, cols, z, ph);
    return S;
  }
  function lines(S){
    return S.filter(s => s.indexOf('<line') === 0).map(s => {
      const m = s.match(/x1="([-\d.]+)" y1="([-\d.]+)" x2="([-\d.]+)" y2="([-\d.]+)"/);
      return m.slice(1, 5).map(Number);
    });
  }
  function pt(x, zz){ return [Number(rx(x).toFixed(6)), Number(ry(zz).toFixed(6))]; }
  function segs(S){
    return lines(S).map(l => [[Number(l[0].toFixed(6)), Number(l[1].toFixed(6))],
                              [Number(l[2].toFixed(6)), Number(l[3].toFixed(6))]])
                   .map(s => JSON.stringify(s)).sort();
  }
  function want(pairs){
    return pairs.map(p => JSON.stringify([pt(p[0], p[1]), pt(p[2], p[3])])).sort();
  }

  // --- jednokridlove dvierka, panty VLAVO: kridlo x 0..400, panel z 0..700 ---
  global.frontSlots = { D1: { wings_n: 1, slots: [{ wing: 'single', state: 'left' }] },
                        D2: { wings_n: 1, slots: [{ wing: 'single', state: 'right' }] },
                        D3: { wings_n: 1, slots: [{ wing: 'single', state: null }] } };
  const COL1 = [{ x: 0, w: 400 }];
  const L = draw({ id: 'D1', type: 'door' }, COL1, 0, 700);
  eq(segs(L), want([[400*INS, 700*INS, 400*FAR, 700*0.5],
                    [400*INS, 700*FAR, 400*FAR, 700*0.5]]),
     'panty VLAVO: ciary z lavych rohov do stredu pravej hrany');
  ok(L.every(s => s.indexOf('stroke-dasharray') >= 0), 'dvierka sa hybu -> PRERUSOVANE');

  const R = draw({ id: 'D2', type: 'door' }, COL1, 0, 700);
  eq(segs(R), want([[400*FAR, 700*INS, 400*INS, 700*0.5],
                    [400*FAR, 700*FAR, 400*INS, 700*0.5]]),
     'panty VPRAVO su presnym zrkadlom');

  eq(draw({ id: 'D3', type: 'door' }, COL1, 0, 700), [], 'LEGACY kridlo sa nekresli VOBEC');
  eq(draw({ id: 'DX', type: 'door' }, COL1, 0, 700), [],
     'v rezime vkladania (bez zaznamu servera) sa JEDNO kridlo nekresli — strana sa NEHADA');

  // --- 2 kridla: KRAJNE odvodene (p1 vlavo, posledne vpravo) ----------------
  const COL2 = [{ x: 0, w: 300 }, { x: 320, w: 300 }];
  const W2 = draw({ id: 'DX', type: 'door' }, COL2, 0, 700);
  eq(segs(W2), want([[300*INS, 700*INS, 300*FAR, 350],
                     [300*INS, 700*FAR, 300*FAR, 350],
                     [320 + 300*FAR, 700*INS, 320 + 300*INS, 350],
                     [320 + 300*FAR, 700*FAR, 320 + 300*INS, 350]]),
     'dvojkridlo da „><" — kazde kridlo z vlastnych rohov');

  // --- 3 kridla: stredne podla slotu (tu „neurcene" = kruh + otaznik) -------
  global.frontSlots.T1 = { wings_n: 3, slots: [{ wing: 'p2', state: 'unset' }] };
  const COL3 = [{ x: 0, w: 200 }, { x: 220, w: 200 }, { x: 440, w: 200 }];
  const W3 = draw({ id: 'T1', type: 'door' }, COL3, 0, 700);
  eq(lines(W3).length, 4, 'krajne kridla kreslia po dvoch ciarach');
  eq(W3.filter(s => s.indexOf('<circle') === 0).length, 1, '„neurcene" ostava KRUH');
  ok(W3.some(s => s.indexOf('>?<') >= 0), 'a otaznik v nom');
  ok(W3.filter(s => s.indexOf('<circle') === 0 || s.indexOf('>?<') >= 0)
      .every(s => s.indexOf('#e65100') >= 0), '„neurcene" je JEDINE v jantari');

  // --- vyklop / sklop: „V" a „Λ" cez cely otvor -----------------------------
  const UP = draw({ id: 'U1', type: 'lift' }, COL1, 0, 700);
  eq(segs(UP), want([[400*INS, 700*FAR, 200, 700*INS], [400*FAR, 700*FAR, 200, 700*INS]]),
     'vyklop (panty hore) = „V" z HORNYCH rohov do stredu dolnej hrany');
  const APEX = pt(200, 700*INS);
  ok(lines(UP).every(l => l[3] > l[1]),
     'vrchol „V" je na obrazovke NIZSIE nez horne rohy (ry preklapa Z)');
  ok(APEX[1] > ry(700*FAR), 'a hlbsie nez horna hrana panelu');

  const DN = draw({ id: 'F1', type: 'fall' }, COL1, 0, 700);
  eq(segs(DN), want([[400*INS, 700*INS, 200, 700*FAR], [400*FAR, 700*INS, 200, 700*FAR]]),
     'sklop (panty dole) = „Λ" z DOLNYCH rohov do stredu hornej hrany');

  // --- zasuvka vs. blenda: to iste X, ine pero ------------------------------
  const DRW = draw({ id: 'S1', type: 'drawer_front' }, COL1, 0, 700);
  const BLD = draw({ id: 'B1', type: 'blind' }, COL1, 0, 700);
  const X = want([[400*INS, 700*INS, 400*FAR, 700*FAR], [400*INS, 700*FAR, 400*FAR, 700*INS]]);
  eq(segs(DRW), X, 'zasuvkove celo = X cez cely panel (D-115: uz nie je bez symbolu)');
  eq(segs(BLD), X, 'blenda ma TO ISTE X');
  ok(DRW.every(s => s.indexOf('stroke-dasharray') >= 0), 'zasuvka sa VYSUVA -> prerusovane');
  ok(BLD.every(s => s.indexOf('stroke-dasharray') < 0), 'blenda sa NEHYBE -> PLNE');
  ok(BLD.every(s => s.indexOf('stroke-width="3"') >= 0), 'a ostava rovnako hruba');

  // --- co sa nekresli -------------------------------------------------------
  eq(draw({ id: 'N1', type: 'none' }, COL1, 0, 700), [], '„Bez čela" nema symbol');
  eq(draw({ id: 'S1', type: 'drawer_front' }, COL1, 0, 0), [], 'nulova vyska panelu');
  eq(draw({ id: 'S1', type: 'drawer_front' }, [], 0, 700), [], 'ziadne kridlo');

  // --- symbol NEPRESAHUJE panel a NEDOTYKA sa jeho obrysu -------------------
  ['left', 'right', 'up', 'down', 'cross', 'xdash'].forEach(sym => {
    C.frontSymbolShape(sym).lines.forEach(ln => ln.forEach(p => {
      n++;
      assert.ok(p[0] >= INS - 1e-12 && p[0] <= FAR + 1e-12 &&
                p[1] >= INS - 1e-12 && p[1] <= FAR + 1e-12,
                sym + ': bod ' + JSON.stringify(p) + ' lezi na obryse panelu (alebo mimo)');
    }));
  });
})();

console.log(`test_kova2b_smer_overlay.js OK (${n} kontrol)`);
