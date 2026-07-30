// Testy 2A-3b: JS zrkadlo SCHEMA 2 (core.js) — dependency-free Node
// (node tests/js/test_abs_mirror.js). Pokryva audit F11 (absUsableExists
// zrkadlo hierarchie group -> presna NEPRAZDNA struktura -> universal -> nic,
// nominalna trieda jednotka, rezim VYHRADNE z catalog_schema payloadu) a F12
// (filter Odporucane: presna struktura + universal, cudzia struktura skupiny
// do Ostatne). Dual-mode: pri schema 1 presne dnesna decor logika.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const core = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));
const { groupAbsEdges, groupAbsEdgesV2, groupAbsForSheet, absOptionsHtml, absUsableExists,
  absUsableExistsV2, absUsableForSheet, absMissingLabel, absUnitClass, identityNorm,
  catalogSchemaOf } = core;

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function ids(list){ return list.map(function(e){ return e.id; }); }

// Dosky: so strukturou, bez struktury, hybrid bez group_id (schema 2 medzistav).
const SHEET      = { id: 'S18',  decor: 'K111', thickness: 18.0, group_id: 'GRP-A', structure: 'ST9' };
const SHEET_NOST = { id: 'S18B', decor: 'K111', thickness: 18.0, group_id: 'GRP-A' };
const SHEET_HYB  = { id: 'S18H', decor: 'K111', thickness: 18.0 };
// Pasky skupiny GRP-A: presna struktura 0,8; cudzia struktura 1,0; universal 1,0/43; cudzia skupina.
const EDGES = [
  { id: 'E_ST9_08', label: 'K111 ST9 23/0,8', decor: 'K111', thickness: 0.8, width: 23.0, group_id: 'GRP-A', structure: 'ST9' },
  { id: 'E_MG_10',  label: 'K111 MG 23/1',    decor: 'K111', thickness: 1.0, width: 23.0, group_id: 'GRP-A', structure: 'MG' },
  { id: 'E_UNI_10', label: 'K111 43/1',       decor: 'K111', thickness: 1.0, width: 43.0, group_id: 'GRP-A', universal: true },
  { id: 'E_CUDZI',  label: 'X999 ST9 23/1',   decor: 'X999', thickness: 1.0, width: 23.0, group_id: 'GRP-B', structure: 'ST9' }
];
const EDGES_JSON = JSON.stringify(EDGES);

// --- identityNorm: zrkadlo Ruby identity_norm (trim, kolaps medzier, upcase) ---
eq(identityNorm('  st 9  '), 'ST 9', 'identityNorm trim + upcase');
eq(identityNorm('ST\t 9'), 'ST 9', 'identityNorm kolaps whitespace na jednu medzeru');
eq(identityNorm(null), '', 'identityNorm(nil) = prazdne');
eq(identityNorm('st9') === identityNorm('ST9'), true, 'case-insensitive zhoda');
eq(identityNorm('ST 9') === identityNorm('ST9'), false, 'medzera je rozdiel (ako v Ruby)');

// --- catalogSchemaOf: rezim VYHRADNE z payloadu (F11) ---
eq(catalogSchemaOf({}), 1, 'schema: chybajuca = legacy 1');
eq(catalogSchemaOf(null), 1, 'schema: null payload = 1');
eq(catalogSchemaOf({ catalog_schema: 2 }), 2, 'schema: 2 z payloadu');
eq(catalogSchemaOf({ catalog_schema: '2' }), 2, 'schema: string "2" je 2');
eq(catalogSchemaOf({ catalog_schema: 'x' }), 1, 'schema: nezmysel = 1');

// --- absUnitClass: nominalna trieda jednotka {0,8; 1; 1,2} ---
[0.8, 1.0, 1.2].forEach(function(t){ eq(absUnitClass(t), true, 'jednotka ' + t); });
[0.4, 1.5, 2.0, 3.0].forEach(function(t){ eq(absUnitClass(t), false, 'mimo jednotky ' + t); });

// --- absUsableExistsV2: matica zrkadla (F11) ---
eq(absUsableExistsV2(EDGES, SHEET, 18), true, 'V2: presna struktura 0,8/23 pre 18 mm');
eq(absUsableExistsV2([EDGES[1]], SHEET, 18), false, 'V2: LEN cudzia struktura = nepouzitelne');
eq(absUsableExistsV2([EDGES[2]], SHEET, 18), true, 'V2: universal vetva zachranuje');
eq(absUsableExistsV2([EDGES[3]], SHEET, 18), false, 'V2: cudzia skupina nie je kandidat');
eq(absUsableExistsV2([{ id: 'E', decor: 'K111', thickness: 1.0, width: 23.0, group_id: 'GRP-A' }], SHEET_NOST, 18),
  false, 'V2: dve prazdne struktury NIE su zhoda (prazdna = neznama)');
eq(absUsableExistsV2([EDGES[2]], SHEET_NOST, 18), true, 'V2: bezstrukturna doska + universal = ok');
eq(absUsableExistsV2([{ id: 'E15', decor: 'K111', thickness: 1.5, width: 43.0, group_id: 'GRP-A', structure: 'ST9' }], SHEET, 18),
  false, 'V2: 1,5 nie je jednotka (trieda namiesto natvrdo 1,0)');
eq(absUsableExistsV2([{ id: 'E04', decor: 'K111', thickness: 0.4, width: 43.0, group_id: 'GRP-A', structure: 'ST9' }], SHEET, 18),
  false, 'V2: 0,4 sa nikdy neponuka automaticky');
eq(absUsableExistsV2([{ id: 'E12', decor: 'K111', thickness: 1.2, width: 23.0, group_id: 'GRP-A', structure: 'ST9' }], SHEET, 18),
  true, 'V2: trieda jednotka 1,2 staci');
eq(absUsableExistsV2([EDGES[0]], SHEET, 38), false, 'V2: sirkovy check plati (38+2 > 23)');
eq(absUsableExistsV2([EDGES[2]], SHEET, 38), true, 'V2: universal 43-ka sirkovo vyhovuje aj 38 mm');
eq(absUsableExistsV2([{ id: 'EU', decor: 'K111', thickness: 1.0, width: 23.0, group_id: 'GRP-A', universal: true }], SHEET, 38),
  false, 'V2: sirkovy check plati aj v universal vetve');
eq(absUsableExistsV2([{ id: 'EL', decor: 'K111', thickness: 1.0, group_id: 'GRP-A', universal: true }], SHEET, 38),
  true, 'V2: paska bez sirky = univerzalna sirka');
eq(absUsableExistsV2(EDGES, null, 18), true, 'V2: neznamy material sa nevylucuje (modal naprazdno nie)');

// --- absUsableForSheet: dispatcher dual-mode (F11) ---
eq(absUsableForSheet([EDGES[1]], SHEET, 2, 18), false, 'dispatcher schema 2: cudzia struktura nie');
eq(absUsableForSheet([EDGES[1]], SHEET, 1, 18), true, 'dispatcher schema 1: dekor logika (struktura sa nevidi)');
eq(absUsableForSheet([EDGES[0]], SHEET, 1, 18), false, 'dispatcher schema 1: 0,8 nie je 1,0 (dnesok presne)');
eq(absUsableForSheet([EDGES[0]], SHEET, 2, 18), true, 'dispatcher schema 2: 0,8 je jednotka');
eq(absUsableForSheet([EDGES[1]], SHEET_HYB, 2, 18), true, 'hybrid bez group_id = legacy dekor cesta (zrkadlo servera)');
eq(absUsableForSheet(EDGES, null, 2, 18), true, 'neznamy material = true aj v schema 2');

// --- groupAbsEdgesV2: filter Odporucane (F12) ---
const g2 = groupAbsEdgesV2(EDGES, SHEET, '__inherit__');
eq(ids(g2.recommended), ['E_ST9_08', 'E_UNI_10'], 'F12: presna struktura + universal, zoradene hrubkou');
ok(ids(g2.others).indexOf('E_MG_10') >= 0, 'F12: cudzia struktura TEJ ISTEJ skupiny ide do Ostatne');
ok(ids(g2.others).indexOf('E_CUDZI') >= 0, 'F12: cudzia skupina v Ostatne');
eq(g2.preserve, null, 'inherit nema preserve');
eq(JSON.stringify(EDGES), EDGES_JSON, 'groupAbsEdgesV2 NEmutuje vstupny katalog');
eq(ids(groupAbsEdgesV2(EDGES, SHEET_NOST, '').recommended), ['E_UNI_10'],
  'F12: bezstrukturna doska odporuca LEN universal (prazdna != zhoda)');
eq(groupAbsEdgesV2(EDGES, SHEET, 'ABS_ZMAZANA').preserve, 'ABS_ZMAZANA', 'F12: preserve mimo katalogu');
eq(ids(groupAbsEdgesV2(EDGES, { id: 'S', group_id: 'GRP-A', structure: 'st9' }, '').recommended),
  ['E_ST9_08', 'E_UNI_10'], 'F12: struktura sa porovnava case-insensitive (identityNorm)');

// --- groupAbsForSheet: dispatcher dual-mode (F12) ---
eq(ids(groupAbsForSheet(EDGES, SHEET, 1, '').recommended), ['E_ST9_08', 'E_MG_10', 'E_UNI_10'],
  'dispatcher schema 1: dnesne dekorove skupiny (vsetky K111 pasky)');
eq(ids(groupAbsForSheet(EDGES, SHEET, 2, '').recommended), ['E_ST9_08', 'E_UNI_10'],
  'dispatcher schema 2: strukturny filter');
eq(ids(groupAbsForSheet(EDGES, SHEET_HYB, 2, '').recommended), ['E_ST9_08', 'E_MG_10', 'E_UNI_10'],
  'hybrid bez group_id = dekorove skupiny aj pri schema 2');
eq(groupAbsForSheet(EDGES, null, 2, '').recommended.length, 0,
  'neznamy material = ziadne odporucane (plochy fallback)');

// --- absOptionsHtml nad V2 skupinami: labely selectov sa NEMENIA (2A-4) ---
const html2 = absOptionsHtml('<option value="">Bez ABS</option>', groupAbsForSheet(EDGES, SHEET, 2, ''));
ok(html2.indexOf('<optgroup label="Odporúčané k dekoru">') >= 0, 'HTML: label Odporucane bez zmeny');
ok(html2.indexOf('<optgroup label="Ostatné">') >= 0, 'HTML: label Ostatne bez zmeny');
ok(html2.indexOf('E_MG_10') > html2.indexOf('<optgroup label="Ostatné'), 'HTML: cudzia struktura az v Ostatne');
ok(html2.indexOf('E_ST9_08') < html2.indexOf('<optgroup label="Ostatné'), 'HTML: presna struktura v Odporucane');

// --- absMissingLabel: text modalu podla schemy ---
eq(absMissingLabel(1), '1,0 mm ABS pásku', 'schema 1: presne dnesny text');
ok(absMissingLabel(2).indexOf('jednotkovú') >= 0, 'schema 2: nominalna trieda v texte');
ok(absMissingLabel(2).indexOf('0,8–1,2') >= 0, 'schema 2: rozsah triedy v texte');

// --- dual-mode poistka: stare funkcie sa spravaju presne ako doteraz ---
eq(absUsableExists(EDGES, 'K111', 1.0, 18), true, 'legacy absUsableExists nedotknuty (dekor zhoda 1,0)');
eq(absUsableExists(EDGES, 'K111', 1.0, 45), false, 'legacy: 45+2 > 43 = nepouzitelne');
eq(ids(groupAbsEdges(EDGES, 'K111', '').recommended), ['E_ST9_08', 'E_MG_10', 'E_UNI_10'],
  'legacy groupAbsEdges nedotknuty (dekor text, hrubka/sirka poradie)');

console.log(JSON.stringify({ passed: n, failed: 0 }));
