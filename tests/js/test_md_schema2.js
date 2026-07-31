// Testy 2A-4b: okno Materialy na SCHEMA 2 (proj_materials.js) — skupiny cez
// group_id (mdGroupKeyOf + groupCatalogByDecor schema2), sekcie detailu per
// struktura (mdStructureSections), batch 3 buildery (mdBuildEdgeVariants,
// mdParseExtraThs/Abs), banner text a spolocna struktura skupiny.
// Dependency-free Node (node tests/js/test_md_schema2.js).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const M = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- mdGroupKeyOf: group_id kotva v schema2, text dekoru inak ---------------
eq(M.mdGroupKeyOf({ group_id: 'GRP-1', decor: 'K111' }, true), 'g:GRP-1', 'schema2 = group_id kotva');
eq(M.mdGroupKeyOf({ group_id: '  ', decor: 'K111' }, true), 'd:K111', 'prazdny gid = fallback text (hybrid)');
eq(M.mdGroupKeyOf({ group_id: 'GRP-1', decor: 'K111' }, false), 'd:K111', 'legacy rezim group_id ignoruje');
eq(M.mdGroupKeyOf({ decor: '  K111  ' }, false), 'd:K111', 'text dekoru sa trimuje');

// --- groupCatalogByDecor(catalog, true): rovnake cislo dvoch vyrobcov = 2 skupiny
const CAT2 = {
  sheets: [
    { material_id: 'EG_K111_18', group_id: 'GRP-EG', manufacturer: 'Egger', decor: 'K111',
      structure: 'ST9', type: 'DTDL', thickness: 18, color: [1, 2, 3] },
    { material_id: 'KR_K111_18', group_id: 'GRP-KR', manufacturer: 'Kronospan', decor: 'K111',
      structure: 'PW', type: 'DTDL', thickness: 18, color: [4, 5, 6] },
    { material_id: 'EG_U750_18', group_id: 'GRP-U750', manufacturer: 'Egger', decor: 'U750',
      decor_name: 'Taupe šedá', structure: 'ST9', type: 'DTDL', thickness: 18, color: [7, 8, 9],
      sheet_size: [2800, 2070] }
  ],
  edges: [
    { abs_id: 'ABS_EG_K111', group_id: 'GRP-EG', decor: 'K111', structure: 'ST9', thickness: 1, width: 23 },
    { abs_id: 'ABS_U750_UNI', group_id: 'GRP-U750', decor: 'U750', thickness: 1, width: 43, universal: true },
    { abs_id: 'ABS_HYBRID', decor: 'Sirota', thickness: 1 }
  ]
};
const SNAP2 = JSON.stringify(CAT2);
const G2 = M.groupCatalogByDecor(CAT2, true);
eq(JSON.stringify(CAT2), SNAP2, 'groupCatalogByDecor nemutuje vstup');
eq(G2.map(g => g.key), ['g:GRP-EG', 'g:GRP-KR', 'd:Sirota', 'g:GRP-U750'],
  'skupiny podla group_id (K111 2x — cislo abecedne, tie-break vyrobca), hybrid na text');
eq(G2[0].manufacturer, 'Egger', 'vyrobca skupiny z dosky');
eq(G2[1].manufacturer, 'Kronospan', 'druha K111 skupina ma vlastneho vyrobcu');
eq(G2[3].decor_name, 'Taupe šedá', 'decor_name skupiny z prveho zaznamu s nazvom');
eq(G2[0].count, 2, 'pocet variantov skupiny (doska + paska)');
eq(G2[0].usage_key, 'GRP-EG', 'usage_key = group_id (server model_decor_usage kluc)');
eq(G2[2].usage_key, 'Sirota', 'hybrid bez gid = usage_key text dekoru');

// Legacy rezim: presne dnesne spravanie (jedna skupina K111 podla textu).
const G1 = M.groupCatalogByDecor(CAT2, false);
eq(G1.map(g => g.decor), ['K111', 'Sirota', 'U750'], 'legacy zoskupenie podla textu dekoru');
eq(G1[0].sheets.length, 2, 'legacy: obe K111 dosky v jednej skupine');
eq(G1[0].usage_key, 'K111', 'legacy usage_key = text dekoru');

// --- mdBuildSections: pouzite cez usage_key (group_id), fallback decor ------
const secs = M.mdBuildSections(G2, { 'GRP-KR': 4 }, 'man', '');
eq(secs[0].title, 'Použité v projekte', 'pouzita skupina cez group_id kluc');
eq(secs[0].groups.map(g => g.key), ['g:GRP-KR'], 'len skupina s poctom > 0');
const legacySecs = M.mdBuildSections([{ decor: 'X', manufacturer: '', sheets: [], edges: [] }], { X: 2 }, 'man', '');
eq(legacySecs[0].title, 'Použité v projekte', 'stary tvar skupiny (bez usage_key) padne na decor');

// --- mdMatchGroup: + struktura a nazov skupiny ------------------------------
ok(M.mdMatchGroup(G2[0], 'st9'), 'hladanie podla struktury variantu');
ok(M.mdMatchGroup(G2[3], 'taupe'), 'hladanie podla nazvu skupiny (decor_name)');
ok(!M.mdMatchGroup(G2[1], 'st9'), 'PW skupina na ST9 dotaz nematchne');

// --- mdStructureSections: sekcie per struktura, bez struktury posledna ------
const SECG = {
  sheets: [
    { material_id: 'A', structure: 'ST9' },
    { material_id: 'B', structure: 'PW' },
    { material_id: 'C' }
  ],
  edges: [
    { abs_id: 'E1', structure: 'st9' },       // case-insensitive kluc, title prvy videny tvar
    { abs_id: 'E2', universal: true }          // universal bez struktury -> sekcia bez struktury
  ]
};
const ss = M.mdStructureSections(SECG);
eq(ss.map(s => s.key), ['PW', 'ST9', ''], 'sekcie abecedne, bez struktury posledna');
eq(ss[1].title, 'ST9', 'title = prvy videny tvar');
eq(ss[1].sheets.map(s => s.material_id), ['A'], 'doska v sekcii svojej struktury');
eq(ss[1].edges.map(e => e.abs_id), ['E1'], 'paska so strukturou (case-insensitive) v sekcii');
eq(ss[2].sheets.map(s => s.material_id), ['C'], 'doska bez struktury v poslednej sekcii');
eq(ss[2].edges.map(e => e.abs_id), ['E2'], 'universal paska v sekcii bez struktury');

// --- sheetDimLabel: typ · hrubka + format ako sub ---------------------------
eq(M.sheetDimLabel({ type: 'DTDL', thickness: 18, sheet_size: [2800, 2070] }),
  { dim: 'DTDL 18', sub: '2800×2070' }, 'dim + format');
eq(M.sheetDimLabel({ type: 'DTDL', thickness: 18 }), { dim: 'DTDL 18', sub: '' }, 'bez formatu bez sub');

// --- mdBuildEdgeVariants: struktura + universal per cip ---------------------
const ECHIPS = [
  { key: '23/1', width: '23', thickness: '1', label: '23/1' },
  { key: '43/2', width: '43', thickness: '2', label: '43/2' }
];
eq(M.mdBuildEdgeVariants(ECHIPS, { '23/1': { st: ' PW ', auto: false } }, { '43/2': true }),
  [{ width: '23', thickness: '1', structure: 'PW', universal: false },
   { width: '43', thickness: '2', structure: '', universal: true }],
  'edge_variants: struktura (trim) + vedomy universal priznak');
eq(M.mdBuildEdgeVariants([], {}, {}), [], 'ziadne cipy = prazdne pole');

// --- mdParseExtraThs/Abs: textove vynimky -> strukturovane varianty ---------
eq(M.mdParseExtraThs('', 'PW'), { variants: [], error: null }, 'prazdny text = nic');
eq(M.mdParseExtraThs('18.5, 25', 'PW'),
  { variants: [{ type: '', thickness: '18.5', structure: 'PW' }, { type: '', thickness: '25', structure: 'PW' }], error: null },
  'hrubky preberu SPOLOCNU strukturu');
ok(M.mdParseExtraThs('18,5', 'PW').error !== null, 'desatinna ciarka = jasna chyba (zrkadlo servera)');
ok(M.mdParseExtraThs('abc', '').error !== null, 'necislo = chyba');
ok(M.mdParseExtraThs('-3', '').error !== null, 'zaporna hrubka = chyba');
eq(M.mdParseExtraThs('18,36', 'ST9').variants.length, 2, 'kompaktny zoznam bez medzier je legalny');
eq(M.mdParseExtraAbs('28/2', 'ST9'),
  { variants: [{ width: '28', thickness: '2', structure: 'ST9', universal: false }], error: null },
  'ABS token sirka/hrubka so spolocnou strukturou, universal false');
ok(M.mdParseExtraAbs('28', '').error !== null, 'token bez lomky = chyba');
ok(M.mdParseExtraAbs('22,5/1', '').error !== null, 'desatinna ciarka v tokene = chyba');

// --- mdEdgeBannerText: sklonovanie ------------------------------------------
ok(M.mdEdgeBannerText(1).indexOf('1 páska nemá') === 0, 'jednotne cislo');
ok(M.mdEdgeBannerText(3).indexOf('3 pásky nemajú') === 0, '2-4');
ok(M.mdEdgeBannerText(5).indexOf('5 pások nemá') === 0, '5+');
ok(M.mdEdgeBannerText(3).indexOf('picker ich nevyberie') > 0, 'text vysvetluje dopad');

// --- mdGroupCommonStructure: predvolba "+ variant" --------------------------
eq(M.mdGroupCommonStructure({ sheets: [{ structure: 'PW' }], edges: [{ structure: 'pw' }] }), 'PW',
  'jedina struktura skupiny (case-insensitive) = predvolba');
eq(M.mdGroupCommonStructure({ sheets: [{ structure: 'PW' }], edges: [{ structure: 'ST9' }] }), '',
  'zmiesane struktury = ziadna predvolba');
eq(M.mdGroupCommonStructure({ sheets: [{}], edges: [] }), '', 'bez struktur = prazdne');

console.log(JSON.stringify({ passed: n, failed: 0 }));

// --- GH #93 kolo 5: PD vlastna hrubka s inline formatom ---------------------
eq(M.mdParseExtraThs('20/4100x600', 'PW', 'PD'),
   { variants: [{ type: '', thickness: '20', structure: 'PW', sheet_size: [4100, 600] }], error: null },
   'PD extra hrubka s formatom prejde');
assert(M.mdParseExtraThs('20', '', 'PD').error !== null, 'PD extra hrubka BEZ formatu = chyba s navodom');
assert(M.mdParseExtraThs('20', '', 'PD').error.indexOf('4100x600') !== -1, 'chyba obsahuje priklad');
eq(M.mdParseExtraThs('19', 'ST9', 'DTDL'),
   { variants: [{ type: '', thickness: '19', structure: 'ST9' }], error: null },
   'ne-PD typ format nepotrebuje');
eq(M.mdParseExtraThs('19/2800x2070', '', 'DTDL'),
   { variants: [{ type: '', thickness: '19', structure: '', sheet_size: [2800, 2070] }], error: null },
   'volitelny format aj pri inych typoch');
assert(M.mdParseExtraThs('20/zle', '', 'PD').error !== null, 'pokazeny format = chyba');
