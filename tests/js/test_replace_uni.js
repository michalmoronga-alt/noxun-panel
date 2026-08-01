// Testy V0.6 M-B2: UNI dlazdice + „Nahradit UNI…" (ciste funkcie proj_materials.js)
//   groupCatalogByDecor — agregacia uni/uni_role do skupiny
//   mdBuildSections     — sekcia "Pracovne (UNI)" navrchu v OBOCH rezimoch
//   mdUniTargets        — kandidati ciela (non-UNI skupiny s doskami)
//   mdUniSummaryLines   — riadky rozpisu dopadu
//   mdTileHtml/mdDetailHtml — badge + tlacidlo Nahradit UNI…
'use strict';
const assert = require('assert');
const path = require('path');
const M = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let passed = 0;
function eq(a, b, msg){ assert.deepStrictEqual(a, b, msg); passed += 1; }
function ok(c, msg){ assert.ok(c, msg); passed += 1; }

const CAT = {
  sheets: [
    { material_id: 'UNI_K', decor: 'Korpus UNI', type: 'DTDL', thickness: 18,
      group_id: 'GRP-UK', uni: true, uni_role: 'body', color: [169, 169, 178] },
    { material_id: 'UNI_D', decor: 'Doska UNI', type: 'DTDL', thickness: 18,
      group_id: 'GRP-UD', uni: true, uni_role: 'board', color: [201, 167, 217] },
    { material_id: 'K111_18', decor: 'K111', decor_name: 'Dub', manufacturer: 'Egger',
      type: 'DTDL', thickness: 18, group_id: 'GRP-K111', structure: 'ST9' },
    { material_id: 'K111_186', decor: 'K111', decor_name: 'Dub', manufacturer: 'Egger',
      type: 'DTDL', thickness: 18.6, group_id: 'GRP-K111', structure: 'ST9' }
  ],
  edges: [
    { abs_id: 'ABS_ONLY', decor: 'H555', group_id: 'GRP-H555', thickness: 1.0, width: 23 }
  ]
};

// --- agregacia uni do skupiny ------------------------------------------------
(function(){
  const groups = M.groupCatalogByDecor(CAT, true);
  const uk = groups.find(g => g.gid === 'GRP-UK');
  const k111 = groups.find(g => g.gid === 'GRP-K111');
  ok(uk && uk.uni === true, 'UNI skupina ma flag uni');
  eq(uk.uni_role, 'body', 'uni_role sa prenesie');
  ok(k111 && k111.uni !== true, 'realna skupina uni flag nema');
})();

// --- sekcie: UNI navrchu v oboch rezimoch -------------------------------------
(function(){
  const groups = M.groupCatalogByDecor(CAT, true);
  const man = M.mdBuildSections(groups, {}, 'man', '');
  eq(man[0].title, 'Pracovné (UNI)', 'rezim vyrobca: UNI sekcia prva');
  eq(man[0].kind, 'uni');
  eq(man[0].groups.length, 2);
  ok(man.slice(1).every(s => s.groups.every(g => g.uni !== true)),
     'UNI skupiny nie su v dalsich sekciach');

  const az = M.mdBuildSections(groups, {}, 'az', '');
  eq(az[0].title, 'Pracovné (UNI)', 'rezim A-Z: UNI sekcia prva');
  ok(az[1] && az[1].kind === 'flat', 'za nou plochy zoznam');
  ok(az[1].groups.every(g => g.uni !== true), 'plochy zoznam bez UNI');

  const q = M.mdBuildSections(groups, {}, 'man', 'k111');
  eq(q.length, 1, 'hladanie = jedina sekcia Vysledky');
  eq(q[0].title, 'Výsledky');

  // bez UNI skupin ziadna prazdna sekcia
  const noUni = M.mdBuildSections(groups.filter(g => !g.uni), {}, 'az', '');
  ok(noUni.every(s => s.kind !== 'uni'), 'ziadna prazdna UNI sekcia');
})();

// --- kandidati ciela ----------------------------------------------------------
(function(){
  const t = M.mdUniTargets(CAT, true);
  eq(t.length, 1, 'kandidat je len non-UNI skupina s doskami (edge-only vypadne)');
  eq(t[0].gid, 'GRP-K111');
  eq(M.mdUniTargets(null, true).length, 0, 'prazdny katalog bezpecne');
})();

// --- riadky rozpisu -----------------------------------------------------------
(function(){
  const s = {
    target_label: 'K111 Dub', target_th: 18.6,
    project: ['Korpus', 'Chrbát'],
    adopting_n: 2, recompute_n: 1,
    th_changes: [{ change: '18→18,6', n: 2 }],
    overrides_n: 1,
    boards: [{ bid: 'BRD-001', from: 12, to: 18.6 }, { bid: 'BRD-002', from: 18.6, to: 18.6 }],
    abs: { changed: 3, lost: ['Bok ľavý L1'], lost_n: 2 }
  };
  const lines = M.mdUniSummaryLines(s);
  ok(lines[0].indexOf('Korpus, Chrbát') >= 0, 'predvolby v prvom riadku');
  ok(lines.some(l => l.indexOf('Skrinky: 3') >= 0), 'sucet skriniek');
  ok(lines.some(l => l.indexOf('prevezme hrúbku 18.6 mm') >= 0), 'adopcia hrubky');
  ok(lines.some(l => l.indexOf('BRD-001 (12→18.6 mm)') >= 0), 'doska so zmenou hrubky');
  ok(lines.some(l => l.indexOf('BRD-002') >= 0 && l.indexOf('BRD-002 (') < 0),
     'doska bez zmeny hrubky bez zatvorky');
  ok(lines.some(l => l.indexOf('ABS hrany sa prevedú') >= 0), 'ABS remap riadok');
  ok(lines.some(l => l.indexOf('ABS bez náhrady') >= 0 && l.indexOf('…') >= 0),
     'lost s naznacenim skratenia');
  eq(lines[lines.length - 1], 'Šablóny sa nemenia — sú globálna knižnica, nie projekt.');

  const empty = M.mdUniSummaryLines({});
  eq(empty.length, 1, 'prazdny payload = len sablonovy riadok');
})();

// --- badge + tlacidlo ---------------------------------------------------------
(function(){
  const groups = M.groupCatalogByDecor(CAT, true);
  const uk = groups.find(g => g.gid === 'GRP-UK');
  const k111 = groups.find(g => g.gid === 'GRP-K111');
  ok(M.mdTileHtml(uk, 0).indexOf('mdunib') >= 0, 'UNI dlazdica ma badge');
  ok(M.mdTileHtml(k111, 0).indexOf('mdunib') < 0, 'realna dlazdica badge nema');
  ok(M.mdDetailHtml(uk).indexOf('Nahradiť UNI…') >= 0, 'detail UNI ma tlacidlo');
  ok(M.mdDetailHtml(k111).indexOf('Nahradiť UNI…') < 0, 'realny detail tlacidlo nema');
})();

console.log(JSON.stringify({ passed: passed, failed: 0 }));
