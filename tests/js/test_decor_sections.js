// Testy D-42 PR B: sekcie mriezky dekorov (proj_materials.js mdBuildSections) —
// pas "Pouzite v projekte" (pocet zostupne), sekcie podla vyrobcu (abecedne,
// "Bez vyrobcu" posledna), A-Z rezim, vysledky hladania. Dependency-free Node.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mdBuildSections } = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

function grp(decor, man){ return { decor: decor, manufacturer: man || '', sheets: [], edges: [] }; }
// vstup zrkadli groupCatalogByDecor: abecedne, '' posledny
const GROUPS = [
  grp('H1180 Dub', 'Egger'),
  grp('K009 PW', 'Kronospan'),
  grp('Sirota ABS', ''),          // edge-only dekor bez dosky -> Bez vyrobcu
  grp('U702 ST9', 'Egger'),
  grp('W1000 Biela', 'Egger'),
  grp('', '')                     // legacy (bez dekoru) -> Bez vyrobcu
];
const USED = { 'U702 ST9': 5, 'K009 PW': 2, 'W1000 Biela': 5 };

// --- rezim 'man' bez dotazu: pas Pouzite + vyrobcovia + Bez vyrobcu posledna ---
const secs = mdBuildSections(GROUPS, USED, 'man', '');
eq(secs.map(s => s.title), ['Použité v projekte', 'Egger', 'Kronospan', 'Bez výrobcu'],
  'poradie sekcii: pouzite, vyrobcovia abecedne, Bez vyrobcu posledna');
eq(secs[0].groups.map(g => g.decor), ['U702 ST9', 'W1000 Biela', 'K009 PW'],
  'pouzite: pocet zostupne, pri zhode abecedne');
eq(secs[0].kind, 'used', 'pouzita sekcia ma kind used');
eq(secs[1].groups.map(g => g.decor), ['H1180 Dub', 'U702 ST9', 'W1000 Biela'],
  'Egger sekcia abecedne (dekor z pouzitych sa opakuje aj vo svojej sekcii)');
eq(secs[3].groups.map(g => g.decor), ['Sirota ABS', ''],
  'Bez vyrobcu: edge-only dekor + legacy (bez dekoru)');

// --- bez pouzitych dekorov ziadny pas ---
eq(mdBuildSections(GROUPS, {}, 'man', '').map(s => s.title), ['Egger', 'Kronospan', 'Bez výrobcu'],
  'prazdna mapa pouzitia = ziadny pas');
eq(mdBuildSections(GROUPS, null, 'man', '').length, 3, 'null used nepadne');

// --- rezim 'az': jedina plocha sekcia v poradi vstupu ---
const flat = mdBuildSections(GROUPS, USED, 'az', '');
eq(flat.length, 1, 'A-Z = jedina sekcia');
eq(flat[0].kind, 'flat', 'A-Z kind flat');
eq(flat[0].groups.map(g => g.decor), GROUPS.map(g => g.decor), 'A-Z drzi poradie vstupu');

// --- aktivny dotaz: jedina sekcia Vysledky (pas sa skryva) ---
const q = mdBuildSections(GROUPS.slice(0, 2), USED, 'man', 'dub');
eq(q.map(s => s.title), ['Výsledky'], 'dotaz = sekcia Vysledky bez pasu');
eq(q[0].groups.length, 2, 'dotaz nechava predfiltrovane skupiny');

console.log(JSON.stringify({ passed: n, failed: 0 }));
