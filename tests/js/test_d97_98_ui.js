// Testy UI casti davky D-97 + D-98 (okno Materialy, proj_materials.js).
//   D-97 mdUnknownTypeWarning — nenasilne upozornenie na neznamy typ dosky;
//        zoznam znamych typov je SAMOSTATNE serverove pole known_types
//        (kanonicky register), NIE suggest.types (audit F4).
//   D-98 supplier_decor — "dekor u dodavatela" v hladani a v riadku variantu.
// Dependency-free Node (node tests/js/test_d97_98_ui.js).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const M = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function eq(a, b, msg){ n++; assert.strictEqual(a, b, msg); }

// Kanonicke typy = Materials::SEED_TYPES (TYPE_REGISTRY.keys) — zrkadlo servera.
const KNOWN = ['DTDL', 'MDF', 'HDF', 'PD', 'ZASTENA', 'KOMPAKT'];

// --- D-97: upozornenie na neznamy typ ---------------------------------------
eq(M.mdUnknownTypeWarning('DTDL', KNOWN), null, 'kanonicky typ nevarujeme');
eq(M.mdUnknownTypeWarning('dtdl', KNOWN), null, 'porovnanie je case-insensitive');
eq(M.mdUnknownTypeWarning('  KOMPAKT  ', KNOWN), null, 'trim ako na serveri');
eq(M.mdUnknownTypeWarning('', KNOWN), null, 'prazdne pole riesi validacia povinnosti');
eq(M.mdUnknownTypeWarning('   ', KNOWN), null, 'samé medzery = prazdne');
eq(M.mdUnknownTypeWarning(null, KNOWN), null, 'nil hodnota nevarujeme');

const w = M.mdUnknownTypeWarning('KD', KNOWN);
ok(w, 'neznamy typ „KD" upozornenie dostane');
ok(/Nezn/.test(w), 'text zacina „Neznámy typ": ' + w);
ok(w.indexOf('DTDL') >= 0, 'hlaska ponuka priklady znamych typov: ' + w);

// AUDIT F4 — jadro D-97: aj ked uz „KD" v katalogu existuje (a teda je v
// naseptavaci suggest.types), upozornenie MUSI prist dalej. Preto sa hlaska
// stavia VYHRADNE z known_types (kanonicky register), nikdy z navrhov.
const SUGGEST_WITH_KD = KNOWN.concat(['KD']); // taky zoznam posiela suggest.types
ok(M.mdUnknownTypeWarning('KD', KNOWN),
   'ulozeny preklep ostava neznamy — known_types sa katalogom NEROZSIRUJE');
eq(M.mdUnknownTypeWarning('KD', SUGGEST_WITH_KD), null,
   'kontrola testu: so suggest.types by upozornenie zmizlo (preto sa nepouziva)');

// Bez serverovho zoznamu sa nehada (stary payload / zlyhanie push_state).
eq(M.mdUnknownTypeWarning('KD', []), null, 'prazdny zoznam = ziadne upozornenie');
eq(M.mdUnknownTypeWarning('KD', null), null, 'chybajuci zoznam = ziadne upozornenie');

// --- D-98: hladanie podla dekoru u dodavatela --------------------------------
// Realny pripad: kompaktna doska Egger F8001 zije v skupine dekoru F800.
const G = {
  decor: 'F800 ST9 Mramor kryštálový',
  manufacturer: 'Egger',
  sheets: [{ material_id: 'S1', type: 'KOMPAKT', thickness: 12, code: '514485',
             supplier: 'Demos', supplier_decor: 'F8001', sheet_size: [4100, 650] }],
  edges: []
};
// Pozn.: dotaz prichadza z volajuceho uz zmenseny (vzor test_material_search.js).
ok(M.mdMatchGroup(G, 'f8001'), 'hladanie „F8001" najde skupinu F800 (objednavkove cislo)');
ok(M.mdMatchGroup(G, 'f800'), 'nazov skupiny funguje dalej');
ok(!M.mdMatchGroup(G, 'f9001'), 'cudzie cislo nezhoda');

const G2 = {
  decor: 'U702 Kašmírová', manufacturer: 'Egger',
  sheets: [{ material_id: 'S2', type: 'DTDL', thickness: 18 }], edges: []
};
ok(!M.mdMatchGroup(G2, 'f8001'), 'zaznam bez aliasu sa nepodstrci');

// --- D-98: alias v riadku variantu (detail dekoru) ---------------------------
const lab = M.sheetDimLabel({ type: 'KOMPAKT', thickness: 12, sheet_size: [4100, 650],
                              supplier_decor: 'F8001' });
eq(lab.dim, 'KOMPAKT 12', 'stlpec rozmeru ostava uzky (typ + hrubka)');
eq(lab.sub, '4100×650 · dod. F8001', 'alias ide do sub riadku, nie do noveho stlpca');

const labNone = M.sheetDimLabel({ type: 'KOMPAKT', thickness: 12, sheet_size: [4100, 650] });
eq(labNone.sub, '4100×650', 'bez aliasu sa riadok nemeni');

const labBlank = M.sheetDimLabel({ type: 'DTDL', thickness: 18, supplier_decor: '   ' });
eq(labBlank.sub, '', 'prazdny alias nic nedokresluje');

// zastena: rub aj alias by boli v jednom riadku — alias sa na zastenu nikdy
// neuklada (server ho odmieta), ale render nesmie spadnut ani tak.
const labZ = M.sheetDimLabel({ type: 'ZASTENA', thickness: 9.2, sheet_size: [4100, 640],
                               back_decor: 'K552', back_structure: 'RT' });
eq(labZ.sub, '4100×640 · rub K552 RT', 'rub zasteny ostava nedotknuty');

console.log(JSON.stringify({ passed: n, failed: 0 }));
