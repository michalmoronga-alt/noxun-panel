// UI-C1b — VKLADACIA KARTA: ciste jadro (dependency-free Node,
// `node tests/js/test_uic1b_vkladanie.js`). Pokryva to, co v CEF nevidno:
//   1) draft ciel sablony (nxFrontsResolve) — ZRKADLO Fronts.layout; bez neho
//      by nahlad vkladania nemal co kreslit (`frontItems` je tu null — FIX 11),
//   2) ODHAD kusov a plochy navrhu (nxDraftStats) — server dopocet pre nevlozeny
//      config neexistuje a builder sa kvoli informacnemu stlpcu nespusta,
//   3) projekcia vkladanej DOSKY (nxGrainArrows, pvBoardScene) — N10,
//   4) vrstvy nahladu v rezime 'insert' (NXLayers): Cela su ZAPNUTE defaultne
//      a daju sa zhasnut (kontrakt N9 „vypnutím vidno vnútro"),
//   5) kontrakt HRUBKY doskovej sablony (uniBoardSheetId/boardTemplateMaterialId)
//      — sablona bez materialu sa vklada cez UNI, aby jej hrubka platila,
//   6) schematicke dlazdice (nxTplGlyph/nxTplBadge) — kresba bez jedinej farby.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const ins = require(path.join(JS, 'insert_state.js'));
// form.js kresli dlazdice cez globalne NXInsert/mmLabel (v paneli su to skripty
// nacitane pred nim) — v Node ich treba postavit PRED require.
global.NXInsert = ins;
global.mmLabel = function (v) {
  const n = parseFloat(v);
  if (isNaN(n)) return '';
  const r = Math.round(n * 100) / 100;
  return Math.abs(r - Math.round(r)) < 0.001 ? String(Math.round(r)) : String(r).replace('.', ',');
};
const pv = require(path.join(JS, 'preview.js'));
const bc = require(path.join(JS, 'board_card.js'));
const fm = require(path.join(JS, 'form.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function near(actual, expected, tol, msg){
  n++;
  assert.ok(Math.abs(actual - expected) <= tol,
    `${msg}: cakam ${expected} (±${tol}), dostal ${actual}`);
}

// ============ 1) DRAFT CIEL (zrkadlo Fronts.layout) =========================
const R = pv.nxFrontsResolve;
eq(R(null, 720, 100), [], 'bez configu ziadne cela');
eq(R({ items: [] }, 720, 100), [], 'prazdny zoznam ciel');

// Jedno AUTO celo: vyplni cely otvor mimo okrajov (H - fh - gt - gb).
let one = R({ items: [{ id: 'F1', type: 'door', mode: 'auto' }], gap: 3, gap_top: 2, gap_bottom: 2 },
            720, 100);
eq(one.length, 1, 'jedno celo');
near(one[0].z, 102, 0.01, 'celo zacina na sokli + spodnom okraji');
near(one[0].height, 616, 0.01, 'AUTO vyska = otvor minus okraje');

// Fixne + AUTO: zvysok sa deli medzi AUTO riadky, cela idu ODSPODU s medzerou.
const mix = R({ items: [{ id: 'F1', type: 'drawer_front', mode: 'fixed', height: 140 },
                        { id: 'F2', type: 'door', mode: 'auto' },
                        { id: 'F3', type: 'door', mode: 'auto' }],
                gap: 3, gap_top: 2, gap_bottom: 2 }, 820, 100);
eq(mix.map(function(f){ return f.id; }), ['F1', 'F2', 'F3'], 'poradie ostava datove (F1 dole)');
near(mix[0].z, 102, 0.01, 'prve celo nad soklom');
near(mix[0].height, 140, 0.01, 'fixne celo drzi svoju vysku');
near(mix[1].z, 245, 0.01, 'druhe celo za medzerou');
near(mix[1].height, 285, 0.01, 'zvysok rozdeleny medzi dva AUTO riadky');
near(mix[2].z, 533, 0.01, 'tretie celo nadvazuje');
near(mix[1].height + mix[2].height + 140 + 2 * 3 + 2 + 2, 720, 0.02,
     'sucet vysok + medzier + okrajov = otvor (820 - 100)');

// Prepchata sablona: AUTO riadok dostane nulu, nikdy zaporno (nahlad nesmie padat).
const over = R({ items: [{ id: 'F1', mode: 'fixed', height: 900 }, { id: 'F2', mode: 'auto' }] },
               720, 0);
near(over[1].height, 0, 0.001, 'zaporny zvysok = nulova vyska AUTO cela');

// Legacy zaznam bez `mode` je AUTO; typ chyba -> dvierka (ako Ruby normalize).
const legacy = R({ items: [{ id: 'F1' }] }, 720, 0);
eq(legacy[0].mode, 'auto', 'chybajuci mode = AUTO');
eq(legacy[0].type, 'door', 'chybajuci typ = dvierka');
eq(legacy[0].profile, 'none', 'chybajuci profil = bez profilu');

// ============ 2) ODHAD NAVRHU (Dielcov / Materiál) ==========================
const S = pv.nxDraftStats;
const G0 = { W: 600, H: 720, D: 510, t: 18, fh: 100, gapSides: 2,
             topMode: 'full', backMode: 'overlay', bottomBetween: false, railDepth: 100 };
eq(S({ W: 0, H: 0 }, [], []), { count: 0, area: 0 }, 'bez rozmerov ziadny odhad');
const base = S(G0, [], []);
eq(base.count, 5, 'holy korpus = 2 boky + dno + vrch + chrbat');
near(base.area, 2 * 0.62 * 0.51 + 0.6 * 0.51 + 0.564 * 0.51 + 0.6 * 0.62, 0.01,
     'plocha holeho korpusu (m²)');
eq(S(Object.assign({}, G0, { topMode: 'none', backMode: 'none' }), [], []).count, 3,
  'bez stropu a chrbta ostanu tri dielce');
eq(S(Object.assign({}, G0, { topMode: 'two_rails' }), [], []).count, 6,
  'dve vystuhy = o dielec viac nez plny strop');
// Police a priecky zo stromu zon + cela.
const zones = [{ leaf: false, w: 564, h: 600, split: { axis: 'v', count: 2 } },
               { leaf: true, w: 270, h: 600, shelves: 2 },
               { leaf: true, w: 270, h: 600, shelves: 0 }];
eq(S(G0, zones, []).count, base.count + 1 + 2, 'priecka + dve police');
const withFronts = S(G0, [], [{ type: 'door', height: 600, wings_n: 2 },
                              { type: 'none', height: 100 }]);
eq(withFronts.count, base.count + 2, 'dvojkridlove celo = dva dielce, „bez čela" ziadny');
eq(S(G0, [], [{ type: 'door', height: 600, wings: 'auto' }]).count, base.count + 1,
  'auto kridla pri uzkom otvore = jedno');
eq(S(Object.assign({}, G0, { W: 900 }), [], [{ type: 'door', height: 600, wings: 'auto' }]).count,
  base.count + 2, 'auto kridla nad 600 mm = dve (zrkadlo D-24)');

// ============ 3) PROJEKCIA VKLADANEJ DOSKY (N10) ============================
eq(pv.nxGrainArrows(2600, 600, 'none'), [], 'bez smeru ziadne sipky');
eq(pv.nxGrainArrows(0, 600, 'length'), [], 'bez rozmerov ziadne sipky');
const ah = pv.nxGrainArrows(2600, 600, 'length');
eq(ah.length, 3, 'tri sipky po dlzke');
eq(ah.every(function(a){ return a.y1 === a.y2; }), true, 'po dlzke = vodorovne sipky');
eq(ah.every(function(a){ return a.x2 > a.x1; }), true, 'sipka ukazuje v smere rastucej dlzky');
eq(ah.map(function(a){ return a.y1; }), [150, 300, 450], 'sipky su rozlozene naprieč doskou');
const av = pv.nxGrainArrows(2600, 600, 'width');
eq(av.every(function(a){ return a.x1 === a.x2 && a.y2 > a.y1; }), true, 'po sirke = zvisle sipky');
// Scena musi niest kotu vpravo aj dole — inak by ju fit orezal.
const sc = pv.pvBoardScene(2600, 600);
eq(sc.x < 0 && sc.y < 0, true, 'scena ma padding vlavo a hore');
eq(sc.x + sc.w > 2600 + 26, true, 'vpravo je miesto na kotu sirky');
eq(sc.y + sc.h > 600 + 26, true, 'dole je miesto na kotu dlzky');
eq(pv.pvBoardScene(0, 0).w > 0, true, 'nulove rozmery scenu nezrusia');

// ============ 4) VRSTVY NAHLADU V REZIME 'insert' ===========================
const L = pv.NXLayers;
const AV = { zony: true, cela: true, kovanie: false, olep: false };
L.reset();
eq(L.baseOf('insert'), null, 'vkladanie nema zakladnu vrstvu (kresli sa korpus)');
eq(L.stateOf('insert', 'cela', AV), 'on', 'CELA su pri vkladani zapnute defaultne (N9)');
eq(L.stateOf('insert', 'zony', AV), 'off', 'zony su ghost na vyziadanie');
eq(L.stateOf('insert', 'kovanie', AV), 'disabled', 'navrh kovanie nema — chip je neaktivny');
eq(L.stateOf('insert', 'olep', AV), 'disabled', 'olep patri dielcu');
eq(L.toggle('insert', 'cela', AV), true, 'cela sa daju zhasnut…');
eq(L.stateOf('insert', 'cela', AV), 'off', '…a vtedy vidno vnutro sablony');
eq(L.ghosts('insert', AV), [], 'zhasnute cela sa uz nekreslia');
eq(L.toggle('insert', 'cela', AV), true, 'a znova zapnut');
eq(L.stateOf('insert', 'cela', AV), 'on', 'chip sa vratil do zakladneho stavu');
eq(L.stateOf('insert', 'cela', { cela: false }), 'disabled',
  'sablona bez ciel: chip je neaktivny s vysvetlenim');
L.reset();
eq(L.stateOf('insert', 'cela', AV), 'on', 'nova identita vyberu vracia predvolbu');
eq(L.stateOf('cab', 'cela', AV), 'off', 'ostatne projekcie predvolbu NEMAJU');

// ============ 5) KONTRAKT HRUBKY DOSKOVEJ SABLONY ===========================
// Sablona ma material_id: nil => vklada sa cez UNI (E-03 odomknuta hrubka),
// aby deklarovana hrubka VZDY platila (Codex #174 P2 / core/templates.rb).
const SHEETS = [
  { id: 'K009_18', thickness: 18 },
  { id: 'UNI_KORPUS_18', uni: true, uni_role: 'body', thickness: 18 },
  { id: 'UNI_DOSKA_18', uni: true, uni_role: 'board', thickness: 18 }
];
eq(bc.uniBoardSheetId(SHEETS), 'UNI_DOSKA_18', 'UNI rola „Doska" ma prednost');
eq(bc.uniBoardSheetId([{ id: 'UNI_HDF_3', uni: true, uni_role: 'hdf' }]), 'UNI_HDF_3',
  'bez doskovej roly sa vezme akykolvek UNI');
eq(bc.uniBoardSheetId([{ id: 'K009_18' }]), null, 'katalog bez UNI nema co dosadit');
eq(bc.uniBoardSheetId([]), null, 'prazdny katalog nespadne');
eq(bc.boardTemplateMaterialId(SHEETS, null), 'UNI_DOSKA_18',
  'sablona BEZ materialu (kontrakt) => UNI doskovy');
eq(bc.boardTemplateMaterialId(SHEETS, ''), 'UNI_DOSKA_18', 'prazdny material = to iste');
eq(bc.boardTemplateMaterialId(SHEETS, 'K009_18'), 'K009_18',
  'sablona s realnym materialom si ho ponecha');
eq(bc.boardTemplateMaterialId(SHEETS, 'ZMIZOL'), 'UNI_DOSKA_18',
  'material, ktory uz v katalogu nie je, padne na UNI');

// Plocha dosky v informacnom stlpci.
eq(bc.nxBoardArea(2600, 600), 1.56, 'plocha dosky v m²');
eq(bc.nxBoardArea('800', '600'), 0.48, 'stringy z formulara');
eq(bc.nxBoardArea(0, 600), null, 'nulovy rozmer = ziadna plocha');
eq(bc.nxBoardArea('x', 600), null, 'nezmysel = ziadna plocha');

// ============ 6) SCHEMATICKE DLAZDICE =======================================
const glyph = fm.nxTplGlyph({ kind: 'cabinet', config: { fronts: { items: [{ type: 'door' }, { type: 'door' }] } } });
eq(/#[0-9a-fA-F]{3,8}\b/.test(glyph), false, 'kresba dlazdice nenesie ziadnu farbu (tokeny su v CSS)');
eq((glyph.match(/<path/g) || []).length, 1, 'dve cela = jedna deliaca ciara');
eq((fm.nxTplGlyph({ kind: 'cabinet', config: { fronts: { items: [{ type: 'door', wings: '2' } ] } } })
     .match(/M30 2v36/g) || []).length, 1, 'jedno dvojkridlove celo = zvisla ciara');
eq((fm.nxTplGlyph({ kind: 'cabinet', config: { zone_tree: { shelves: 3 } } }).match(/<path/g) || []).length, 3,
  'bez ciel sa naznacia police zo zon');
eq(fm.nxTplGlyph({ kind: 'cabinet', config: {} }), '<rect x="2" y="2" width="56" height="36"/>',
  'prazdny korpus ostane prazdny');
eq(fm.nxTplGlyph({ kind: 'board', config: { thickness: 18 } }).indexOf('M8 30 52 10') > 0, true,
  'doska ma vlastnu kresbu');
eq(fm.nxTplBadge({ kind: 'board', config: { thickness: 18 } }), '18 mm', 'doskova dlazdica nesie hrubku');
eq(fm.nxTplBadge({ kind: 'board', config: {} }), '', 'bez hrubky ziadny badge');
eq(fm.nxTplBadge({ kind: 'cabinet', config: { thickness: 18 } }), '',
  'korpusova dlazdica hrubku v badge nema (hrubka je vlastnost dosky)');

console.log(JSON.stringify({ passed: n, failed: 0 }));
