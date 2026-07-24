// Testy D-42 PR A: hladanie dekorov v okne Materialy (proj_materials.js
// mdMatchGroup) — nazov / vyrobca / kod / dodavatel variantu. Dependency-free
// Node (node tests/js/test_material_search.js).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mdMatchGroup } = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const G = {
  decor: 'U702 ST9 Kašmírová',
  manufacturer: 'Egger',
  sheets: [{ material_id: 'S1', type: 'DTDL', thickness: 18, code: 'U702 PW', supplier: 'Demos' }],
  edges: [{ abs_id: 'E1', thickness: 1.0, width: 22, code: 'ABS-KAS-22', supplier: 'Kili' }]
};

ok(mdMatchGroup(G, ''), 'prazdny dotaz = vsetko');
ok(mdMatchGroup(G, 'u702'), 'zhoda v nazve (case-insensitive)');
ok(mdMatchGroup(G, 'kašmír'), 'zhoda v casti nazvu');
ok(mdMatchGroup(G, 'egger'), 'zhoda vo vyrobcovi');
ok(mdMatchGroup(G, 'abs-kas'), 'zhoda v kode ABS variantu');
ok(mdMatchGroup(G, 'u702 pw'), 'zhoda v kode dosky');
ok(mdMatchGroup(G, 'demos'), 'zhoda v dodavatelovi dosky');
ok(mdMatchGroup(G, 'kili'), 'zhoda v dodavatelovi ABS');
ok(!mdMatchGroup(G, 'kronospan'), 'nezhoda = false');
ok(!mdMatchGroup(G, 'zzz999'), 'nezhoda v ziadnom poli');

// dekor bez kodov: hlada len nazov/vyrobca
const G2 = { decor: 'Biela', manufacturer: '', sheets: [{ material_id: 'B1', type: 'DTDL', thickness: 18 }], edges: [] };
ok(mdMatchGroup(G2, 'biela'), 'nazov aj bez kodov');
ok(!mdMatchGroup(G2, 'demos'), 'ziadny dodavatel = nezhoda');

console.log(JSON.stringify({ passed: n, failed: 0 }));
