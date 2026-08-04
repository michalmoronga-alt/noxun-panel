// Testy H4 (UI drobnosti) — ciste funkcie proj_materials.js
//   D-82 mdColorEditable / mdGroupSwatch — farba je SKUPINOVA (swatch v hlavicke
//        detailu je vyber farby); UNI a read-only rezim paletu nedostanu.
//   D-83 mdGroupKeyForUni — dlazdica k danemu UNI materialu (skratka z KONTROLY).
'use strict';
const assert = require('assert');
const path = require('path');
const M = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let passed = 0;
function eq(a, b, msg){ assert.deepStrictEqual(a, b, msg); passed += 1; }
function ok(c, msg){ assert.ok(c, msg); passed += 1; }

const CAT = {
  sheets: [
    { material_id: 'UNI_KORPUS_18', decor: 'Korpus UNI', type: 'DTDL', thickness: 18,
      group_id: 'GRP-UK', uni: true, uni_role: 'body', color: [169, 169, 178] },
    { material_id: 'UNI_DOSKA_38', decor: 'Doska UNI', type: 'PD', thickness: 38,
      group_id: 'GRP-UD', uni: true, uni_role: 'board', color: [201, 167, 217] },
    { material_id: 'K111_18', decor: 'K111', decor_name: 'Dub', manufacturer: 'Egger',
      type: 'DTDL', thickness: 18, group_id: 'GRP-K111', structure: 'ST9', color: [200, 30, 40] },
    { material_id: 'K111_36', decor: 'K111', decor_name: 'Dub', manufacturer: 'Egger',
      type: 'DTDL', thickness: 36, group_id: 'GRP-K111', structure: 'ST9', color: [200, 30, 40] }
  ],
  edges: [
    { abs_id: 'ABS_K111_23X10', decor: 'K111', group_id: 'GRP-K111', thickness: 1.0,
      width: 23, structure: 'ST9', color: [200, 30, 40] }
  ]
};

function grp(gid){ return M.groupCatalogByDecor(CAT, true).find(g => g.gid === gid); }

// --- D-82: kto smie menit farbu ----------------------------------------------
(function(){
  const real = grp('GRP-K111');
  const uni = grp('GRP-UK');
  ok(M.mdColorEditable(real, false), 'realny dekor sa da prefarbit');
  ok(!M.mdColorEditable(uni, false), 'UNI ma farbu podla role — chranena');
  ok(!M.mdColorEditable(real, true), 'read-only katalog paletu nedava');
  ok(!M.mdColorEditable(null, false), 'bez skupiny niet co menit');
  ok(!M.mdColorEditable({ decor: '', sheets: [], edges: [] }, false),
     'skupina "(bez dekoru)" nie je skutocny dekor');
})();

// --- D-82: swatch v hlavicke = vyber farby -----------------------------------
(function(){
  const real = grp('GRP-K111');
  const uni = grp('GRP-UK');
  const html = M.mdGroupSwatch(real);
  ok(html.indexOf('mdswpick') >= 0, 'realny dekor ma klikaci swatch');
  ok(html.indexOf('type="color"') >= 0, 'swatch nesie nativnu paletu');
  ok(html.indexOf('#c81e28') >= 0, 'paleta je predvyplnena farbou skupiny');
  ok(html.indexOf('set_decor_color') < 0, 'swatch vola JS wrapper, nie sketchup priamo');
  ok(html.indexOf('mdColorSave') >= 0, 'zmena ide cez mdColorSave');

  const uniHtml = M.mdGroupSwatch(uni);
  ok(uniHtml.indexOf('mdswpick') < 0, 'UNI swatch je len ukazka');
  ok(uniHtml.indexOf('type="color"') < 0, 'UNI paletu nedostane');
})();

// --- D-82: v detaile nie je ziadny variantovy vyber farby --------------------
(function(){
  const detail = M.mdDetailHtml(grp('GRP-K111'));
  ok(detail.indexOf('mdswpick') >= 0, 'skupinova farba je v hlavicke detailu');
  eq((detail.match(/type="color"/g) || []).length, 1,
     'PRESNE jeden vyber farby na skupinu (ziadny per variant)');
})();

// --- D-83: skratka z KONTROLY najde dlazdicu podla uni_id --------------------
(function(){
  eq(M.mdGroupKeyForUni(CAT, true, 'UNI_KORPUS_18'), 'g:GRP-UK', 'UNI korpus -> jeho skupina');
  eq(M.mdGroupKeyForUni(CAT, true, 'UNI_DOSKA_38'), 'g:GRP-UD', 'UNI doska -> jej skupina');
  eq(M.mdGroupKeyForUni(CAT, true, 'K111_18'), null, 'realny material NIE je UNI — ziadna skratka');
  eq(M.mdGroupKeyForUni(CAT, true, 'NEEXISTUJE'), null, 'zmazany material = null (hlaska, nie modal)');
  eq(M.mdGroupKeyForUni(CAT, true, ''), null, 'prazdne id');
  eq(M.mdGroupKeyForUni(CAT, true, null), null, 'chybajuce id');
  eq(M.mdGroupKeyForUni(null, true, 'UNI_KORPUS_18'), null, 'bez katalogu nic nepada');
  // legacy katalog (schema 1) klucuje skupiny textom dekoru
  eq(M.mdGroupKeyForUni(CAT, false, 'UNI_KORPUS_18'), 'd:Korpus UNI', 'legacy kluc = dekor');
})();

console.log(JSON.stringify({ passed: passed, failed: 0 }));
