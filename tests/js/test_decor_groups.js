// Testy D-41 PR B: zoskupenie katalogu podla dekorov (proj_materials.js
// groupCatalogByDecor + chip labely) — dependency-free Node
// (node tests/js/test_decor_groups.js). Rovnaky vzor ako test_abs_groups.js.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { groupCatalogByDecor, sheetChipLabel, edgeChipLabel } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

const CATALOG = {
  sheets: [
    { material_id: 'U702_36', decor: 'U702 ST9', type: 'DTDL', thickness: 36.0, manufacturer: 'Egger', color: [1, 2, 3] },
    { material_id: 'K009_18', decor: 'K009 PW', type: 'DTDL', thickness: 18.0, manufacturer: 'Kronospan', color: [9, 9, 9] },
    { material_id: 'U702_18', decor: 'U702 ST9', type: 'DTDL', thickness: 18.0, manufacturer: '', color: [4, 5, 6] },
    { material_id: 'U702_MDF_18', decor: 'U702 ST9', type: 'MDF', thickness: 18.0 }
  ],
  edges: [
    { abs_id: 'ABS_U702_43X10', decor: 'U702 ST9', thickness: 1.0, width: 43.0 },
    { abs_id: 'ABS_U702_LEG', decor: 'U702 ST9', thickness: 1.0 },
    { abs_id: 'ABS_U702_22X10', decor: 'U702 ST9', thickness: 1.0, width: 22.0 },
    { abs_id: 'ABS_SIROTA_10', decor: 'Sirota Bez Dosky', thickness: 1.0 },
    { abs_id: 'ABS_BEZ', decor: '', thickness: 1.0 }
  ]
};
const SNAP = JSON.stringify(CATALOG);

const groups = groupCatalogByDecor(CATALOG);

// Zoradenie: dekory abecedne, "(bez dekoru)" skupina POSLEDNA
eq(groups.map(g => g.decor), ['K009 PW', 'Sirota Bez Dosky', 'U702 ST9', ''],
  'skupiny abecedne, bez dekoru na konci');
eq(JSON.stringify(CATALOG), SNAP, 'groupCatalogByDecor nemutuje vstup');

// U702: dosky typ+hrubka vzostupne, vyrobca z prveho sheetu s vyrobcom, farba z prveho sheetu
const u702 = groups.find(g => g.decor === 'U702 ST9');
eq(u702.sheets.map(s => s.material_id), ['U702_18', 'U702_36', 'U702_MDF_18'],
  'dosky: typ abecedne, potom hrubka (DTDL 18, DTDL 36, MDF 18)');
eq(u702.manufacturer, 'Egger', 'vyrobca z prveho zaznamu s vyrobcom');
eq(u702.color, [1, 2, 3], 'farba z prveho sheetu skupiny');

// ABS: hrubka -> sirka vzostupne, legacy bez sirky na konci (zhoda s core.js D-41 sortom)
eq(u702.edges.map(a => a.abs_id), ['ABS_U702_22X10', 'ABS_U702_43X10', 'ABS_U702_LEG'],
  'ABS: sirka vzostupne, legacy bez sirky posledna');

// ABS bez dosky tvori vlastnu skupinu (dekor zije aj bez sheetov)
const sirota = groups.find(g => g.decor === 'Sirota Bez Dosky');
eq(sirota.sheets.length, 0, 'sirota nema dosky');
eq(sirota.edges.length, 1, 'sirota ma pasku');

// Chip labely: doska "TYP hrubka", ABS "sirka/hrubka" alebo legacy "hrubka mm"
eq(sheetChipLabel({ type: 'DTDL', thickness: 18.0 }), 'DTDL 18', 'sheet chip');
eq(sheetChipLabel({ type: 'DTDL', thickness: 38.0 }), 'DTDL 38', 'sheet chip PD');
eq(edgeChipLabel({ width: 22.0, thickness: 1.0 }), '22/1', 'edge chip sirkovy');
eq(edgeChipLabel({ width: 22.5, thickness: 2.0 }), '22.5/2', 'edge chip desatinny');
eq(edgeChipLabel({ thickness: 1.0 }), '1 mm', 'edge chip legacy bez sirky');

console.log(JSON.stringify({ passed: n, failed: 0 }));
