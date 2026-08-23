// Testy D-44: format platne pri preset cipoch formulara „+ variant"
// (proj_materials.js) — dependency-free Node (node tests/js/test_decor_formats.js).
// Rovnaky vzor ako test_decor_groups.js. Testuju sa LEN ciste funkcie bez DOM:
// navrh formatu podla typu a zlozenie payloadu sheet_variants z aktivnych cipov.
// ŠT-2c 2c-2b: sada „posledny pouzity" ZANIKLA spolu so zakladanim dekoru
// z tohto formulara — jej testy nahradil guard zaniku na konci suboru.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const MD_PATH = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js');
const { mdFormatHint, mdBuildSheetVariants, mdSheetDim } = require(MD_PATH);

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- mdFormatHint: navrhy stavia SERVER (Materials::TYPE_FORMAT_HINTS), JS ich
//     len hlada podla napisaneho typu (case-insensitive, trim) ---
const HINTS = { DTDL: [2800, 2070], MDF: [2800, 2070], HDF: [2800, 2070], PD: null };
eq(mdFormatHint('DTDL', HINTS), [2800, 2070], 'DTDL ma standardny format');
eq(mdFormatHint('dtdl', HINTS), [2800, 2070], 'typ je case-insensitive (zrkadlo Ruby identity)');
eq(mdFormatHint('  MDF  ', HINTS), [2800, 2070], 'trim okolo napisaneho typu');
eq(mdFormatHint('PD', HINTS), null, 'PD: sirok je vela — vedome zadanie, ziadny navrh');
eq(mdFormatHint('kompakt', HINTS), null, 'neznamy typ = bez navrhu');
eq(mdFormatHint('', HINTS), null, 'prazdny typ = bez navrhu');
eq(mdFormatHint('DTDL', null), null, 'chybajuce hinty (stary payload) = bez navrhu');
eq(mdFormatHint('DTDL', { DTDL: [2800] }), null, 'poskodeny navrh sa ignoruje (ziadny polovicny format)');

// --- mdSheetDim: null = prazdne, NaN = vyplnene ale neplatne (D-19 vzor) ---
eq(mdSheetDim(''), null, 'prazdne pole = ziadny format');
eq(mdSheetDim('  '), null, 'medzery = prazdne');
eq(mdSheetDim('2800'), 2800, 'cele cislo');
eq(mdSheetDim('2050,5'), 2050.5, 'desatinna ciarka aj bodka');
eq(Number.isNaN(mdSheetDim('abc')), true, 'necislo = NaN (nie 0)');
eq(Number.isNaN(mdSheetDim('0')), true, 'nula nie je format');
eq(Number.isNaN(mdSheetDim('-5')), true, 'zaporne nie je format');

// --- mdBuildSheetVariants: aktivne cipy + stav formatov -> payload ---
const CHIPS = [
  { key: '18', type: '', th: '18', label: 'DTDL 18' },
  { key: 'PD 38', type: 'PD', th: '38', label: 'PD 38' }
];

// 2A-4b: builder VZDY nesie structure (batch 3) — bez stavu struktur prazdnu.
// GH #93 P2 (7. kolo): PD cip BEZ formatu je klientska chyba (server by variant
// odmietol az po zavreti formulara a cela davka by sa stratila) — ne-PD cipy
// bez formatu ostavaju legalne.
let out = mdBuildSheetVariants([CHIPS[0]], {});
eq(out.error, null, 'ne-PD cip bez formatu ziadna chyba');
eq(out.variants, [{ type: '', thickness: '18', structure: '' }],
  'bez formatu sa sheet_size vobec neposiela (server ho neulozi)');
out = mdBuildSheetVariants(CHIPS, {});
if (out.error === null) throw new Error('PD cip bez formatu MUSI byt klientska chyba');

out = mdBuildSheetVariants(CHIPS, { '18': { l: '2800', w: '2050' }, 'PD 38': { l: '4100', w: '600' } });
eq(out.variants, [{ type: '', thickness: '18', structure: '', sheet_size: [2800, 2050] },
                  { type: 'PD', thickness: '38', structure: '', sheet_size: [4100, 600] }],
  'format per cip ide do payloadu (MG 2800x2050, PD 4100x600)');

// 2A-4b: struktura per cip (auto zo spolocneho pola / rucny prepis) ide do payloadu.
// (GH #93 kolo 7: PD cip potrebuje format — inak klientska chyba.)
out = mdBuildSheetVariants(CHIPS, { 'PD 38': { l: '4100', w: '600' } },
                           { '18': { st: 'PW', auto: true }, 'PD 38': { st: ' ST9 ', auto: false } });
eq(out.variants, [{ type: '', thickness: '18', structure: 'PW' },
                  { type: 'PD', thickness: '38', structure: 'ST9', sheet_size: [4100, 600] }],
  'structure per cip (trim) ide do payloadu batch 3');

out = mdBuildSheetVariants(CHIPS, { '18': { l: '2800', w: '' } });
eq(out.error !== null, true, 'polovicny format zastavi odoslanie');
eq(out.error.indexOf('DTDL 18') >= 0, true, 'hlaska menuje konkretny cip');

out = mdBuildSheetVariants(CHIPS, { 'PD 38': { l: '4100', w: 'abc' } });
eq(out.error !== null, true, 'neplatne cislo zastavi odoslanie');

out = mdBuildSheetVariants([], { '18': { l: '2800', w: '2070' } });
eq(out, { variants: [], error: null }, 'ziadny aktivny cip = prazdny payload (bez chyby)');

// Stav formatu neaktivneho cipu payload neovplyvni (mdFmt si pamata aj vypnute).
out = mdBuildSheetVariants([CHIPS[0]], { '18': { l: '2800', w: '2050' }, '36': { l: '9', w: '9' } });
eq(out.variants, [{ type: '', thickness: '18', structure: '', sheet_size: [2800, 2050] }],
  'do payloadu ide LEN to, co je zapnute');

// --- ŠT-2c 2c-2b: pamat „poslednej pouzitej sady" ZANIKLA -------------------
// Zakladanie dekoru z batch formulara skoncilo (D-69 editor v rezime create),
// takze localStorage pamat preset cipov uz nema komu sluzit — a hlavne: dve
// pamate rozpisu (localStorage + `NXModal`) by znamenali dve rozpisane verzie
// toho isteho dekoru a ziadnu istotu, ktora sa naozaj odosle.
const MD_SRC = fs.readFileSync(MD_PATH, 'utf8');
ok(MD_SRC.indexOf('nx_decor_last_set') === -1,
  'kluc localStorage je PREC (ziadny mrtvy zapis, ktory nikto necita)');
ok(!/function md(LoadLastSet|StoreLastSet|MigrateLastSet|ManualFormats)\b/.test(MD_SRC),
  'a s nim aj cela obsluha sady');
ok(MD_SRC.indexOf('localStorage.setItem') === -1,
  'sekcia Materialy uz do localStorage nezapisuje NIC');

console.log(JSON.stringify({ passed: n, failed: 0 }));
